--[[
	Auctioneer - AutoMagic Utility module
	Version: <%version%> (<%codename%>)
	Revision: $Id$
	URL: http://auctioneeraddon.com/

	AutoMagic is an Auctioneer module which automates mundane tasks for you.

	License:
		This program is free software; you can redistribute it and/or
		modify it under the terms of the GNU General Public License
		as published by the Free Software Foundation; either version 2
		of the License, or (at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program(see GPL.txt); if not, write to the Free Software
		Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

	Note:
		This AddOn's source code is specifically designed to work with
		World of Warcraft's interpreted AddOn system.
		You have an implicit license to use this AddOn with these facilities
		since that is its designated purpose as per:
		http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
--]]
if not AucAdvanced then return end

--Set up our module with AADV
local libName, libType = "AutoMagic", "Util"
local lib,parent,private = AucAdvanced.NewModule(libType, libName)
if not lib then return end
local aucPrint,decode,_,_,replicate,empty,get,set,default,debugPrint,fill,_TRANS = AucAdvanced.GetModuleLocals()

-- Locals to handle C_Container namespace in newer build of clients; expect these to be merged to all clients eventually ### hybrid
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
-- Special handling for C_Container.GetContainerItemInfo, which now returns a table instead of multiple return values
-- We only return up to the 6th return value; all returns might not be used
local GetContainerItemInfoSpecial = GetContainerItemInfo
if C_Container and C_Container.GetContainerItemInfo then
	GetContainerItemInfoSpecial = function(bag, slot)
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then
			return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.isReadable, info.hasLoot
		end
	end
end


--Start Module Code
local amBTMRule, itemName, itemID, _
function lib.GetName()
	return libName
end
local autosellframe = CreateFrame("Frame", "autosellframe", UIParent, "BackdropTemplate"); autosellframe:Hide()
local autoselldata = {}
local autosell = {}
local GetPrice = function() return 0,0 end --fake getPrice when Appraiser is not available
if AucAdvanced.Modules.Util.Appraiser then
	GetPrice = AucAdvanced.Modules.Util.Appraiser.GetPrice
end
lib.autoSellList = {} -- default empty table in case of no saved data

lib.Processors = {}

function lib.Processors.config(callbackType, ...)
	lib.SetupConfigGui(...) --Called when you should build your Configator tab.
end

function lib.Processors.configchanged(callbackType, ...)
	if (get("util.automagic.autosellgui")) then
		lib.autoSellGUI()
		set("util.automagic.autosellgui", false) -- Resetting our toggle switch
	end
end

function lib.OnLoad()
	lib.slidebar()

	-- Read saved variables
	lib.autoSellList = get("util.automagic.autoSellList") or lib.autoSellList -- will default to empty table if no saved variables
	for id, name in pairs(lib.autoSellList) do
		lib.ClientItemCacheRefresh("item:"..id)
	end

	-- Sets defaults
	--aucPrint("AucAdvanced: {{"..libType..":"..libName.."}} loaded!")

	default("util.automagic.autovendor", false) -- DO NOT SET TRUE ALL AUTOMAGIC OPTIONS SHOULD BE TURNED ON MANUALLY BY END USER!!!!!!!
	default("util.automagic.autostopafter12", true) --stops autovendor after 12 items are sold. Want it to be on
	default("util.automagic.autosellgrey", false)
	default("util.automagic.autocloseenable", false) -- Enables auto close of vendor window after autosale completion
	default("util.automagic.showmailgui", false)
	default("util.automagic.autosellgui", false) -- Acts as a button and reverts to false anyway
	default("util.automagic.chatspam", true) --Supposed to default on has to be unchecked if you don't want the chat text.
	default("util.automagic.ammailguix", 100) --Used for storing mailgui location
	default("util.automagic.ammailguiy", 100) --Used for storing mailgui location
	--default("util.automagic.uierrormsg", 0) --Keeps track of ui error msg's -- ### this is not used anywhere
	default("util.automagic.overidebtmmail", false) -- Item AI for mail rule instead of BTM rule.


	default("util.automagic.displaybeginerTooltips", true)

	--create mail frames
	lib.makeMailGUI()
end

	-- define what event fires what function
function lib.onEventDo(this, event)
	if event == 'MERCHANT_SHOW' 		then lib.merchantShow() 				end
	if event == 'MERCHANT_CLOSED' 	then lib.merchantClosed()				end
	if event == 'MAIL_SHOW' 			then lib.mailShow() 					end
	if event == 'MAIL_CLOSED' 		then lib.mailClosed() 					end
	--if event == 'UI_ERROR_MESSAGE'	then set("util.automagic.uierrormsg", 1) 	end -- ### this is not used
	if event == 'BAG_UPDATE'  then if lib.confirmsellui:IsVisible()  then lib.vendorAction() end	end --bags changed make sure vendor items are in order
end

--This will be used to sort our list's rather than the default scrollsheet method.
function lib.CustomSort(data, sort, width, column, dir)
		assert(column <= width)
		assert(dir == -1 or dir == 1)
		table.sort(sort, function(a,b)
			local aPos = (a-1)*width+column
			local bPos = (b-1)*width+column
			local dataA, dataB = data[aPos], data[bPos]
			local colorA, nameA = string.match(dataA, "^|cff(%x+)|Hitem.+|h%[(.*)%]|h|r")
			local colorB, nameB = string.match(dataB, "^|cff(%x+)|Hitem.+|h%[(.*)%]|h|r")
			if colorA and nameA and colorB and nameB then --hyperlink check
				dataA = colorA..nameA
				dataB = colorB..nameB
			end
			if dir < 0 then
				return (dataA > dataB) or (dataA == dataB and a > b)
			end
				return (dataA < dataB) or (dataA == dataB and a < b)
		end)
end

function lib.SetupConfigGui(gui)
	local id = gui:AddTab(libName)
	gui:MakeScrollable(id)
	--stores our ID id we use this to open the config button to correct frame
	private.gui = gui
	private.guiID = id


		gui:AddHelp(id, "what is AutoMagic?",
			_TRANS('AAMU_Help_WhatAutoMagic'), --"What is AutoMagic?"
			_TRANS('AAMU_Help_WhatAutoMagicAnswer')) --"AutoMagic is a work-in-progress. Its goal is to automate tasks that auctioneers run into that can be a pain to do, as long as it is within the bounds set by Blizzard. \n\nAutoMagic currently will auto-sell any item bought via SearchUI for vendors, any item that is grey (if enabled) or any item on the auto-sell list. If enabled, when you open a merchant window you will see a listing of the items to sell."
		gui:AddHelp(id, "AAMU: vendor options",
			_TRANS('AAMU_Help_VendorOptions'), --"AAMU: Vendor Options"
			_TRANS('AAMU_Help_VendorOptionsAnswer')) --"AutoMagic will sell items bought for vendoring to the vendor automatically. It also has the option of auto-selling all grey items or items on the custom sell list."
		gui:AddHelp(id, "what is Mail GUI?",
			_TRANS('AAMU_Help_WhatMailGUI'), --"What is the Mail GUI?"
			_TRANS('AAMU_Help_WhatMailGUIAnswer')) --"This displays a window when the mailbox is opened that allows for the auto-loading of items into the send mail window based on purchase reasons from SearchUI. It can also use the ItemSuggest module reasons instead of the provided SearchUI reasons. Very handy for mass mailing items bought for a profession that another character has."


		gui:AddControl(id, "Header",     0,    libName.._TRANS('AAMU_Interface_GeneralOptions')) --" General Options"
		gui:AddControl(id, "Checkbox",		0, 1, "util.automagic.displaybeginerTooltips", _TRANS('AAMU_Interface_BeginnerTooltip')) --"Enable AutoMagic beginner tooltips"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_BeginnerTooltip')) --'Display the beginner tooltips on mouseover.'

		gui:AddControl(id, "Checkbox",		0, 1, 	"util.automagic.chatspam", _TRANS('AAMU_Interface_Chatspam')) --"Enable AutoMagic chat spam"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_Chatspam')) --'Display chat messages from AutoMagic.'

		gui:AddControl(id, "Note",       0, 1, nil, nil, " ")

		gui:AddControl(id, "Header",     0,    _TRANS('AAMU_Interface_VendorOptions')) --" Vendor Options"
		gui:AddControl(id, "Checkbox",		0, 1, 	"util.automagic.autovendor", _TRANS('AAMU_Interface_Vendoring')) --"Enable AutoMagic vendoring (W A R N I N G: READ HELP!) "
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_Vendoring')) --'Enable the auto-vendor options.'

		gui:AddControl(id, "Checkbox",		0, 4, "util.automagic.autostopafter12", _TRANS('AAMU_Interface_AutoStop12')) --"Pause after selling 12 items."
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoStop12')) --'This allows you to buy back an accidental sale, since the server saves the last 12 sales to the vendor'

		gui:AddControl(id, "Subhead",     0,   "Which categories will be vendored?")

		gui:AddControl(id, "Checkbox",		0, 4, 	"util.automagic.autosellgrey", _TRANS('AAMU_Interface_AutoSellGrey')) --"Auto-sell grey items quality items"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellGrey')) --'Auto-sell grey level items at the vendor.'
		gui:AddControl(id, "Checkbox",		0, 6, 	"util.automagic.autosellgreynoprompt", _TRANS('AAMU_Interface_AutoNoPrompt')) --"...without confirmation prompt"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellGreyNoPrompt')) --'No confirmation window will be shown for vendoring grey (trash) items.'

		gui:AddControl(id, "Checkbox",		0, 4, 	"util.automagic.autosellreason", _TRANS('AAMU_Interface_AutoSellReason')) --"Auto-sell items purchased using the vendor searcher"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellReason')) --'Auto-sell items purchased using the vendor searcher'
		gui:AddControl(id, "Checkbox",		0, 6, 	"util.automagic.autosellreasonnoprompt", _TRANS('AAMU_Interface_AutoNoPrompt')) --"...without confirmation prompt"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellReasonNoPrompt')) --'No confirmation window will be shown for items with a purchased for vendor reason tag'

		gui:AddControl(id, "Checkbox",		0, 4, "util.automagic.vendorunusablebop", _TRANS('AAMU_Interface_AutoSellBOP')) --"Auto-sell unusable soulbound gear"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellBOP')) --'Auto-sell unusable soulbound gear'
		gui:AddControl(id, "Checkbox",		0, 6, 	"util.automagic.autosellbopnoprompt", _TRANS('AAMU_Interface_AutoNoPrompt')) --"...without confirmation prompt"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellBOPNoPrompt')) --'No confirmation window will be shown for selling soulbound items the players class cannot equip.'

		gui:AddControl(id, "Checkbox",		0, 4, 	"util.automagic.autoselllist", _TRANS('AAMU_Interface_AutoSellListItems')) --"Auto-sell items on the always vendor list"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellListItems')) --'Auto-sell items on the always vendor list.'
		gui:AddControl(id, "Checkbox",		0, 6, 	"util.automagic.autoselllistnoprompt", _TRANS('AAMU_Interface_AutoNoPrompt')) --"...without confirmation prompt"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellListNoPrompt')) --'No confirmation window will be shown for items on the always vendor list'

		--gui:AddControl(id, "Checkbox",		0, 1, 	"util.automagic.autoclosemerchant", "Auto Merchant Window Close(Power user feature READ HELP)")
		gui:AddControl(id, "Note",       0, 1, nil, nil, " ")
		gui:AddControl(id, "Button",     0, 1, "util.automagic.autosellgui", _TRANS('AAMU_Interface_AutoSellList')) --"Auto-Sell List"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_AutoSellList')) --'Check the box to view the Auto-Sell configuration GUI.'


		gui:AddControl(id, "Button",    0, 1, function() lib.CustomMailerFrame:Show() end, _TRANS('AAMU_Interface_MailButtons')) --
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_MailButtons')) --'Check the box to view the Auto-Sell configuration GUI.'


		gui:AddControl(id, "Header",     0,    _TRANS('AAMU_Interface_GUIOptions')) --" GUI options"
		gui:AddControl(id, "Checkbox",		0, 1, 	"util.automagic.showmailgui", _TRANS('AAMU_Interface_MailGUI')) --"Enable Mail GUI for additional mail features"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_MailGUI')) --'Display the auto-mail window at the mail box.')

		gui:AddControl(id, "Checkbox",		0, 1, 	"util.automagic.overidebtmmail", _TRANS('AAMU_Interface_OverrideSUIMail')) --"Use ItemSuggest values instead of SearchUI's reasons for Mail Loader"
		gui:AddTip(id, _TRANS('AAMU_HelpTooltip_OverrideSUIMail')) --"Use the ItemSuggest reasons instead of the SearchUI 'Purchased for' reasons when sorting mail."
end

--Beginner Tooltips script display for all UI elements
function lib.buttonTooltips(self, text)
	if get("util.automagic.displaybeginerTooltips") and text and self then
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(text)
	end
end

function lib.merchantShow()
	private.eventframe:RegisterEvent("BAG_UPDATE")
	if (get("util.automagic.autovendor")) then
		--first lib.vendorAction call will sell all grays, bypassing promopt. Run lib.vendorAction to add anything remaining to the prompt window
		if (get("util.automagic.autosellgreynoprompt") or get("util.automagic.autoselllistnoprompt")
				or (get("util.automagic.vendorunusablebop") and get("util.automagic.autosellbopnoprompt"))
				or (get("util.automagic.autosellreason") and get("util.automagic.autosellreasonnoprompt"))) then
			lib.vendorAction(true)
		end
		lib.vendorAction()

--~ 		A better option is to auto close vendor when user hits confirm button window
--~ 		if (get("util.automagic.autoclosemerchant")) then
--~ 			if (get("util.automagic.chatspam")) then
--~ 				aucPrint("AutoMagic has closed the merchant window for you, to disable you must change this options in the settings.")
--~ 			end
--~ 			CloseMerchant()
--~ 		end
	end
end


function lib.merchantClosed()
	private.eventframe:UnregisterEvent("BAG_UPDATE")
	if lib.confirmsellui:IsVisible() then lib.confirmsellui:Hide() end
end

function lib.mailShow()
	if (get("util.automagic.showmailgui")) then
		lib.mailGUI()
	end
end

function lib.mailClosed() --Fires on mail box closed event & hides mailgui
	local x, y = lib.ammailgui:GetCenter()
	if x and y then
		-- round x, y to 1dp; the values returned by GetCenter vary in the very low order digits, even if frame hasn't moved
		set("util.automagic.ammailguix", floor(x * 10) / 10)
		set("util.automagic.ammailguiy", floor(y * 10) / 10)
	end
	lib.ammailgui:Hide()
end

function lib.mailGUI() --Function is called from lib.mailShow()
	lib.ammailgui:Show()
end

function lib.autoSellGUI()
	if (autosellframe:IsVisible()) then autosellframe:Hide() return end
	autosellframe:Show()
	lib.populateDataSheet()
end

function lib.closeAutoSellGUI()
	autosellframe:Hide()
end

--Slidebar
function lib.autosellslidebar(_, button)
	if (button == "LeftButton") then
		lib.autoSellGUI()
	else
	--if we rightclick open the configuration window for the whole addon
		if private.gui and private.gui:IsShown() then
			AucAdvanced.Settings.Hide()
		else
			AucAdvanced.Settings.Show()
			private.gui:ActivateTab(private.guiID)
		end
	end
end

local sideIcon
function lib.slidebar()
	if LibStub then
		--Need to figure out if we're embedded first
		local embedded = false
		for _, module in ipairs(AucAdvanced.EmbeddedModules) do
			if module == "Auc-Util-AutoMagic"  then
				embedded = true
			end
		end
		local sideIcon, sideIconE
		if embedded then
			sideIcon = "Interface\\AddOns\\Auc-Advanced\\Modules\\Auc-Util-AutoMagic\\Images\\amagicIcon"
			sideIconE = "Interface\\AddOns\\Auc-Advanced\\Modules\\Auc-Util-AutoMagic\\Images\\amagicIconE"
		else
			sideIcon =  "Interface\\AddOns\\Auc-Util-AutoMagic\\Images\\amagicIcon"
			sideIconE = "Interface\\AddOns\\Auc-Util-AutoMagic\\Images\\amagicIconE"
		end

		local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1", true)
		if LibDataBroker then
			private.LDBButton = LibDataBroker:NewDataObject("Auc-Util-AutoMagic", {
						type = "launcher",
						icon = sideIcon,
						OnClick = function(self, button) lib.autosellslidebar(self, button) end,
					})

			function private.LDBButton:OnTooltipShow()
				self:AddLine("AutoMagic: Auto-Sell Config",  1,1,0.5, 1)
				self:AddLine("|cff1fb3ff".."Left-Click|r to open the 'Auto-Sell' list.",  1,1,0.5, 1)
				self:AddLine("|cff1fb3ff".."Right-Click|r to edit the configuration.",  1,1,0.5, 1)
			end
			--we use a slight hack to LDB to animate our icon on Enter as well as tooltip display. The Tooltip will be hidden by slidebar but will show for other addons
			function private.LDBButton:OnEnter()
				if self.icon and type(self.icon) == "table" then
					self.icon:SetTexture(sideIconE)
				end

				GameTooltip:SetOwner(self, "ANCHOR_NONE")
				GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
				GameTooltip:ClearLines()
				private.LDBButton.OnTooltipShow(GameTooltip)
				GameTooltip:Show()
			end

			function private.LDBButton:OnLeave()
				if self.icon and type(self.icon) == "table" then
					self.icon:SetTexture(sideIcon)
				end
				GameTooltip:Hide()
			end
		end
	end
end

local myworkingtable = {}
function lib.setWorkingItem(link)
	if link == nil then return end
	local linkType, id, _, _, _, _ = decode(link)
	if linkType ~= "item" then return end
	local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(link)
	autosellframe.workingname:SetText(name)
	if not texture then
		autosellframe.slot:ClearNormalTexture()
	else
		autosellframe.slot:SetNormalTexture(texture)
	end
	myworkingtable = {}
	for k, n in pairs(myworkingtable) do
		myworkingtable[k] = nil
	end
	myworkingtable[id] = name
end

function autosellframe.removeitemfromlist()
	for k, n in pairs(myworkingtable) do
		lib.autoSellList[k] = nil
		myworkingtable[k] = nil
	end
	set("util.automagic.autoSellList", lib.autoSellList)--Store the changed sell list across sessions
	myworkingtable = {}
	lib.populateDataSheet()
	autosellframe.ClearIcon()
end

function autosellframe.additemtolist()
	for k, n in pairs(myworkingtable) do
		lib.autoSellList[k] = n
		myworkingtable[k] = nil
	end
	set("util.automagic.autoSellList", lib.autoSellList)--Store the changed sell list across sessions
	myworkingtable = {}
	lib.populateDataSheet()
	autosellframe.ClearIcon()
end

function autosellframe.ClearIcon()
	autosellframe.workingname:SetText("Item Name")
	autosellframe.slot:ClearNormalTexture()
end


function lib.autoSellIconDrag()
	local objtype, _, link = GetCursorInfo()
	ClearCursor()
	if objtype == "item" then
		lib.setWorkingItem(link)
	else
		autosellframe.ClearIcon()
	end
end


function lib.ClickLinkHook(_, link, button)
	if link and autosellframe:IsShown() and link:find("Hitem:") then
		if (button == "LeftButton") then
		lib.setWorkingItem(link)
		end
	end
end
hooksecurefunc("ChatFrame_OnHyperlinkShow", lib.ClickLinkHook)


local autoselldata = {}; local bagcontents = {}; local bagcontentsnodups = {}
function lib.populateDataSheet()
	for k, v in pairs(autoselldata) do autoselldata[k] = nil; end --Reset table to ensure fresh data.

	for id, name in pairs(lib.autoSellList) do
		if (id == nil) then return end
		local _, itemLink, _, _, _, _, _, _, _, _ = GetItemInfo(id)
		local abid, abuy, vendor
		if itemLink then
			abid,abuy = GetPrice(itemLink, nil, true)
			vendor = GetSellValue and GetSellValue(id) or 0
		else
			itemLink = "|cffff0000"..name.."|r" -- item name in red
			lib.ClientItemCacheRefresh("item:"..id)
			abid, abuy, vendor = 0, 0, 0
		end
		table.insert(autoselldata,{
			itemLink, --link form for mouseover tooltips to work
			vendor,
			tonumber(abuy) or tonumber(abid),
		})
	end
		autosellframe.resultlist.sheet:SetData(autoselldata, style) --Set the GUI scrollsheet

	for k, v in pairs(bagcontents) do bagcontents[k] = nil; end  --Reset table to ensure fresh data.
	for bag=0,4 do
		for slot=1,GetContainerNumSlots(bag) do
			if (GetContainerItemLink(bag,slot)) then
				local itemLink = GetContainerItemLink(bag,slot)
				if (itemLink == nil) then return end
				local linkType, itemID, _, _, _, _ = decode(itemLink)
				if linkType == "item" then
					local btmRule = "~"
					if BtmScan then
						local _,itemCount = GetContainerItemInfoSpecial(bag,slot)
						local reason, bids
						local id, suffix, enchant, seed = BtmScan.BreakLink(itemLink)
						local sig = ("%d:%d:%d"):format(id, suffix, enchant)
						local bidlist = BtmScan.Settings.GetSetting("bid.list")

						if (bidlist) then
							bids = bidlist[sig..":"..seed.."x"..itemCount]
							if(bids and bids[1]) then
								btmRule = bids[1]
							end
						end
					end
					bagcontents[itemID] = btmRule
				end
			end
		end
	end
	for k, v in pairs(bagcontentsnodups) do bagcontentsnodups[k] = nil; end --Reset 'data' table to ensure fresh data.
	for id, btmRule in pairs(bagcontents) do
		if (id == nil) then return end
		local _, itemLink, _, _, _, _, _, _, _, _ = GetItemInfo(id)
		local abid,abuy = GetPrice(itemLink, nil, true)
		table.insert(bagcontentsnodups,{
		itemLink, -- link form for mouseover tooltips to work
		btmRule, --btm rule
		tonumber(abuy) or tonumber(abid),
		})
	end
	autosellframe.baglist.sheet:SetData(bagcontentsnodups, style) --Set the GUI scrollsheet
end

function autosell.OnBagListEnter(button, row, index)
	if autosellframe.baglist.sheet.rows[row][index]:IsShown()then --Hide tooltip for hidden cells
		local link = autosellframe.baglist.sheet.rows[row][index]:GetText()
		if link and link:find("|Hitem:%d") then
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			AucAdvanced.ShowItemLink(GameTooltip, link, 1)
		end
	end
end

function autosell.OnEnter(button, row, index)
	if autosellframe.resultlist.sheet.rows[row][index]:IsShown()then --Hide tooltip for hidden cells
		local link = autosellframe.resultlist.sheet.rows[row][index]:GetText()
		if link and link:find("|Hitem:%d") then
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			AucAdvanced.ShowItemLink(GameTooltip, link, 1)
		end
	end
end

function autosell.OnLeave(button, row, index)
	GameTooltip:Hide()
end

function autosell.OnClickAutoSellSheet(button, row, index)
	for index = 1, 3 do
		local link = autosellframe.resultlist.sheet.rows[row][index]:GetText()
		if link and link:find("|Hitem:%d") then
			lib.setWorkingItem(link)
			return
		end
	end
	lib.populateDataSheet()
end

function autosell.OnClickBagSheet(button, row, index)
	for index = 1, 3 do
		local link = autosellframe.baglist.sheet.rows[row][index]:GetText()
		if link and link:find("|Hitem:%d") then
			lib.setWorkingItem(link)
			return
		end
	end
	lib.populateDataSheet()
end

function lib.makeautosellgui()
	autosellframe:SetFrameStrata("HIGH")
	autosellframe:SetBackdrop({
		bgFile = "Interface/Tooltips/ChatBubble-Background",
		edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	})
	autosellframe:SetBackdropColor(0,0,0, 1)
	autosellframe:Hide()

	autosellframe:SetPoint("CENTER", UIParent, "CENTER")
	autosellframe:SetWidth(640)
	autosellframe:SetHeight(450)

	autosellframe:SetMovable(true)
	autosellframe:EnableMouse(true)
	autosellframe.Drag = CreateFrame("Button", nil, autosellframe)
	autosellframe.Drag:SetPoint("TOPLEFT", autosellframe, "TOPLEFT", 10,-5)
	autosellframe.Drag:SetPoint("TOPRIGHT", autosellframe, "TOPRIGHT", -10,-5)
	autosellframe.Drag:SetHeight(6)
	autosellframe.Drag:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")

	autosellframe.Drag:SetScript("OnMouseDown", function() autosellframe:StartMoving() end)
	autosellframe.Drag:SetScript("OnMouseUp", function() autosellframe:StopMovingOrSizing() end)

	autosellframe.DragBottom = CreateFrame("Button",nil, autosellframe)
	autosellframe.DragBottom:SetPoint("BOTTOMLEFT", autosellframe, "BOTTOMLEFT", 10,5)
	autosellframe.DragBottom:SetPoint("BOTTOMRIGHT", autosellframe, "BOTTOMRIGHT", -10,5)
	autosellframe.DragBottom:SetHeight(6)
	autosellframe.DragBottom:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")

	autosellframe.DragBottom:SetScript("OnMouseDown", function() autosellframe:StartMoving() end)
	autosellframe.DragBottom:SetScript("OnMouseUp", function() autosellframe:StopMovingOrSizing() end)

	local	autoselltitle = autosellframe:CreateFontString(asuftitle, "OVERLAY", "GameFontNormalLarge")
	autoselltitle:SetText("AutoMagic: Auto Sell Config")
	autoselltitle:SetJustifyH("CENTER")
	autoselltitle:SetWidth(300)
	autoselltitle:SetHeight(10)
	autoselltitle:SetPoint("TOPLEFT",  autosellframe, "TOPLEFT", 0, -17)
	autosellframe.autoselltitle = aautoselltitle

	--Close Button
	autosellframe.closeButton = CreateFrame("Button", nil, autosellframe, "UIPanelButtonTemplate")
	autosellframe.closeButton:SetSize(90,21)
	autosellframe.closeButton:SetPoint("BOTTOMRIGHT", autosellframe, "BOTTOMRIGHT", -530, 10)
	autosellframe.closeButton:SetText(("Close"))
	autosellframe.closeButton:SetScript("OnClick",  lib.closeAutoSellGUI)

	local SelectBox = LibStub:GetLibrary("SelectBox")
	local ScrollSheet = LibStub:GetLibrary("ScrollSheet")


	autosellframe.slot = CreateFrame("Button", "AutoSellFrameSlot", autosellframe, "PopupButtonTemplate")
	autosellframe.slot:SetPoint("TOPLEFT", autosellframe, "TOPLEFT", 23, -50)
	autosellframe.slot:SetWidth(38)
	autosellframe.slot:SetHeight(38)
	autosellframe.slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square.blp")
	autosellframe.slot:SetScript("OnClick", lib.autoSellIconDrag)
	autosellframe.slot:SetScript("OnReceiveDrag", lib.autoSellIconDrag)

	autosellframe.slot.help = autosellframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autosellframe.slot.help:SetPoint("LEFT", autosellframe.slot, "RIGHT", 2, 7)
	autosellframe.slot.help:SetText(("Drop item into box")) --"Drop item into box to search."
	autosellframe.slot.help:SetWidth(100)

	autosellframe.workingname = autosellframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autosellframe.workingname:SetPoint("TOPLEFT", autosellframe, "TOPLEFT", 15, -100)
	autosellframe.workingname:SetText((""))
	autosellframe.workingname:SetWidth(90)

	--Add Item to list button
	autosellframe.additem = CreateFrame("Button", nil, autosellframe, "UIPanelButtonTemplate")
	autosellframe.additem:SetSize(90, 21)
	autosellframe.additem:SetPoint("TOPLEFT", autosellframe, "TOPLEFT", 10, -150)
	autosellframe.additem:SetText(('Add Item'))
	autosellframe.additem:SetScript("OnClick", autosellframe.additemtolist)

	autosellframe.additem.help = autosellframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autosellframe.additem.help:SetPoint("TOPLEFT", autosellframe.additem, "TOPRIGHT", 1, 1)
	autosellframe.additem.help:SetText(("(to Auto Sell list)"))
	autosellframe.additem.help:SetWidth(90)

	--Remove Item from list button
	autosellframe.removeitem = CreateFrame("Button", nil, autosellframe, "UIPanelButtonTemplate")
	autosellframe.removeitem:SetSize(90, 21)
	autosellframe.removeitem:SetPoint("TOPLEFT", autosellframe.additem, "BOTTOMLEFT", 0, -20)
	autosellframe.removeitem:SetText(('Remove Item'))
	autosellframe.removeitem:SetScript("OnClick", autosellframe.removeitemfromlist)

	autosellframe.removeitem.help = autosellframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autosellframe.removeitem.help:SetPoint("TOPLEFT", autosellframe.removeitem, "TOPRIGHT", 1, 1)
	autosellframe.removeitem.help:SetText(("(from Auto Sell list)"))
	autosellframe.removeitem.help:SetWidth(90)

	--Create the autosell list results frame
	autosellframe.resultlist = CreateFrame("Frame", nil, autosellframe, "BackdropTemplate")
	autosellframe.resultlist:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})

	autosellframe.resultlist:SetBackdropColor(0, 0, 0.0, 0.5)
	autosellframe.resultlist:SetPoint("TOPLEFT", autosellframe, "BOTTOMLEFT", 270, 250)
	autosellframe.resultlist:SetPoint("TOPRIGHT", autosellframe, "TOPLEFT",630, 0)
	autosellframe.resultlist:SetPoint("BOTTOM", autosellframe, "BOTTOM", 0, 10)

	autosellframe.resultlist.sheet = ScrollSheet:Create(autosellframe.resultlist, {
		{ ('Auto Selling:'), "TOOLTIP", 170 },
		{ "Vendor", "COIN", 70 },
		{ "Appraiser", "COIN", 70 },
	}, autosell.OnEnter, autosell.OnLeave, autosell.OnClickAutoSellSheet)
	--use our custom sort method not scrollsheets
	autosellframe.resultlist.sheet.CustomSort = lib.CustomSort
	--Create the bag contents frame
	autosellframe.baglist = CreateFrame("Frame", nil, autosellframe, "BackdropTemplate")
	autosellframe.baglist:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})

	autosellframe.baglist:SetBackdropColor(0, 0, 0.0, 0.5)

	autosellframe.baglist:SetPoint("TOPLEFT", autosellframe, "BOTTOMLEFT", 270, 445)
	autosellframe.baglist:SetPoint("TOPRIGHT", autosellframe, "TOPLEFT", 630, 0)
	autosellframe.baglist:SetPoint("BOTTOM", autosellframe, "BOTTOM", 0, 250)

	autosellframe.bagList = CreateFrame("Button", nil, autosellframe, "UIPanelButtonTemplate")
	autosellframe.bagList:SetSize(90,21)
	autosellframe.bagList:SetPoint("TOPRIGHT", autosellframe.baglist, "BOTTOMRIGHT", -530, -50)
	autosellframe.bagList:SetText(("Re-Scan Bags"))
	autosellframe.bagList:SetScript("OnClick", lib.populateDataSheet)

	autosellframe.baglist.sheet = ScrollSheet:Create(autosellframe.baglist, {
		{ ('Bag Contents:'), "TOOLTIP", 170 },
		{ ('BTM Rule'), "TEXT", 70 },
		{ "Appraiser", "COIN", 70 },
	}, autosell.OnBagListEnter, autosell.OnLeave, autosell.OnClickBagSheet)
	--use our custom sort method not scrollsheets
	autosellframe.baglist.sheet.CustomSort = lib.CustomSort
end
lib.makeautosellgui()

-- Client item cache refresh system
-- (Loosely based on similar code in Gatherer)

local tooltip = CreateFrame("GameTooltip")
local eventframe = CreateFrame("Frame") -- used for Events and for timer (via Update)
private.eventframe = eventframe
local timercounter = 0
local refreshlist

eventframe:SetScript("OnEvent", lib.onEventDo)
eventframe:RegisterEvent("MERCHANT_SHOW")
eventframe:RegisterEvent("MERCHANT_CLOSED")
eventframe:RegisterEvent("MAIL_SHOW")
eventframe:RegisterEvent("MAIL_CLOSED")
eventframe:RegisterEvent("UI_ERROR_MESSAGE")

local function timerOnUpdate(self, elapsed)
	timercounter = timercounter - elapsed
	if timercounter <= 0 then
		if not refreshlist then -- this is a double-check - should not occur
			eventframe:SetScript("OnUpdate", nil)
			return
		end
		local link
		repeat -- iterate refreshlist until we find an uncached item
			link = next(refreshlist)
			if not link then -- no more items in list - stop the timer
				refreshlist = nil
				eventframe:SetScript("OnUpdate", nil)
				return
			end
			refreshlist[link] = nil
		until not GetItemInfo(link)
		tooltip:SetHyperlink(link) -- causes client to download item info from server into cache. todo: consider wrapping in pcall?
		timercounter = 5 -- 5 seconds throttle between each server request
	end
end

-- lib.ClientItemCacheRefresh
-- link : must be an item link which would work in both GetItemInfo and GameTooltip:SetHyperlink
-- note: the short form "item:<number>" is permissible
function lib.ClientItemCacheRefresh(link)
	if not refreshlist then
		refreshlist = {}
		timercounter = 0 -- refresh on next update
		eventframe:SetScript("OnUpdate", timerOnUpdate)
	end
	refreshlist[link] = true
end
