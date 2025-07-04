--[[
	Enchantrix Addon for World of Warcraft(tm).
	Version: <%version%> (<%codename%>)
	Revision: $Id$
	URL: http://enchantrix.org/

	Minimap Icon

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
]]

local settings = Enchantrix.Settings
local constants = Enchantrix.Constants

--[[

Icon on the minimap related bits

]]

local miniIcon = CreateFrame("Button", "EnxMiniMapIcon", Minimap);
Enchantrix.MiniIcon = miniIcon
miniIcon.enxMoving = false

local function mouseDown()
	miniIcon.icon:SetTexCoord(0, 1, 0, 1)
end

local function mouseUp()
	miniIcon.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
end

local function dragStart()
	miniIcon.enxMoving = true
end

local function dragStop()
	miniIcon.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
	miniIcon.enxMoving = false
end

local open2Enchanting, open2Jewelcrafting, checkProfession
-- different versions of open2Enchanting, open2Jewelcrafting and checkProfession depending on client APIs available
if GetProfessions and GetProfessionInfo then
	checkProfession = function(check)
		local prof1, prof2 = GetProfessions()
		local _, _, _, _, _, _, skilline1 = GetProfessionInfo(prof1)
		local _, _, _, _, _, _, skilline2 = GetProfessionInfo(prof2)
		return skilline1 == check or skilline2 == check
	end
else
	checkProfession = function()
		return true
	end
end
if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
	open2Enchanting = function()
		C_TradeSkillUI.OpenTradeSkill(333)
	end
	open2Jewelcrafting = function()
		C_TradeSkillUI.OpenTradeSkill(755)
	end
else
	open2Enchanting = function()
		CastSpellByName(_ENCH("Enchanting"))
	end
	open2Jewelcrafting = function()
		CastSpellByName(_ENCH("Jewelcrafting"))
	end
end

local function click(obj, button)
	if button == "LeftButton" then
		if IsModifierKeyDown() then
			open2Jewelcrafting()
			if not checkProfession(755) then
				Enchantrix.Util.ChatPrint("You do not have Jewelcrafting on this character")
			end
		else
			open2Enchanting()
			if not checkProfession(333) then
				Enchantrix.Util.ChatPrint("You do not have Enchanting on this character")
			end
		end
	elseif button == "RightButton" then
		settings.MakeGuiConfig()
		local gui = settings.Gui
		if gui:IsVisible() then
			gui:Hide()
		else
			gui:Show()
		end
	end
end

local function addtooltiplines(tooltip)
	tooltip:AddLine("Enchantrix",  1,1,0.5, 1)
	tooltip:AddLine(_ENCH("EnxMMTip"),  1,1,0.5, 1)
	tooltip:AddLine("|cff1fb3ff".._ENCH("Click").."|r ".._ENCH("TipOpenEnchant"), 1,1,0.5, 1)
	if not constants.Classic or constants.Classic >= 2 then
		tooltip:AddLine("|cff1fb3ff".._ENCH("ShiftClick").."|r ".._ENCH("TipOpenJewel"), 1,1,0.5, 1)
	end
	tooltip:AddLine("|cff1fb3ff".._ENCH("RightClick").."|r ".._ENCH("TipOpenConfig"), 1,1,0.5, 1)
end

function miniIcon.Reposition(angle)
	if not settings.GetSetting("miniicon.enable") then
		miniIcon:Hide()
		return
	end
	miniIcon:Show()
	if not angle then angle = settings.GetSetting("miniicon.angle") or 0.5
	else settings.SetSetting("miniicon.angle", angle) end
	angle = angle
	local distance = settings.GetSetting("miniicon.distance")

	local width,height = Minimap:GetWidth()/2, Minimap:GetHeight()/2
	width = width+distance
	height = height+distance

	local iconX, iconY
	iconX = width * cos(angle)
	iconY = height * sin(angle)

	miniIcon:ClearAllPoints()
	miniIcon:SetPoint("CENTER", Minimap, "CENTER", iconX, iconY)
end

local function update()
	if miniIcon.enxMoving then
		local curX, curY = GetCursorPosition()
		local miniX, miniY = Minimap:GetCenter()
		miniX = miniX * Minimap:GetEffectiveScale()
		miniY = miniY * Minimap:GetEffectiveScale()

		local relX = miniX - curX
		local relY = miniY - curY
		local angle = math.deg(math.atan2(relY, relX)) + 180

		miniIcon.Reposition(angle)
	end
end

-- NOTE - this is a duplicate of the slidebar icon code
local function mmButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	addtooltiplines(GameTooltip)
	GameTooltip:Show()
end

local function mmButton_OnLeave(self)
	GameTooltip:Hide()
end


miniIcon:SetToplevel(true)
miniIcon:SetMovable(true)
miniIcon:SetFrameStrata("LOW")
miniIcon:SetWidth(20)
miniIcon:SetHeight(20)
miniIcon:SetPoint("RIGHT", Minimap, "LEFT", 0,0)
miniIcon:Hide()
miniIcon.icon = miniIcon:CreateTexture("", "BACKGROUND")
miniIcon.icon:SetTexture("Interface\\AddOns\\Enchantrix\\Skin\\EnxOrb")
miniIcon.icon:SetTexCoord(0.075, 0.925, 0.075, 0.925)
miniIcon.icon:SetWidth(20)
miniIcon.icon:SetHeight(20)
miniIcon.icon:SetPoint("TOPLEFT", miniIcon, "TOPLEFT", 0,0)
miniIcon.mask = miniIcon:CreateTexture("", "OVERLAY")
miniIcon.mask:SetTexCoord(0.0, 0.6, 0.0, 0.6)
miniIcon.mask:SetTexture("Interface\\Minimap\\Minimap-TrackingBorder")
miniIcon.mask:SetWidth(36)
miniIcon.mask:SetHeight(36)
miniIcon.mask:SetPoint("TOPLEFT", miniIcon, "TOPLEFT", -8,8)

miniIcon:RegisterForClicks("LeftButtonUp","RightButtonUp")
miniIcon:RegisterForDrag("LeftButton")
miniIcon:SetScript("OnMouseDown", mouseDown)
miniIcon:SetScript("OnMouseUp", mouseUp)
miniIcon:SetScript("OnDragStart", dragStart)
miniIcon:SetScript("OnDragStop", dragStop)
miniIcon:SetScript("OnClick", click)
miniIcon:SetScript("OnUpdate", update)
miniIcon:SetScript("OnEnter", mmButton_OnEnter)
miniIcon:SetScript("OnLeave", mmButton_OnLeave)



--[[

nSlideBar related bits

]]

local sideIcon
local SlideBar
if LibStub then
	SlideBar = LibStub:GetLibrary("SlideBar", true)
	local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1", true)
	if LibDataBroker then
		sideIcon = LibDataBroker:NewDataObject("Enchantrix", {
					type = "launcher",
					icon = "Interface\\AddOns\\Enchantrix\\Skin\\EnxOrb",
					OnClick = function(self, button) click(self, button) end,
					})
		function sideIcon:OnTooltipShow()
			addtooltiplines(self)
		end
		function sideIcon:OnEnter()
			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
			GameTooltip:ClearLines()
			sideIcon.OnTooltipShow(GameTooltip)
			GameTooltip:Show()
		end
		function sideIcon:OnLeave()
			GameTooltip:Hide()
		end
	end
end

--[[

AddonCompartment related bits

]]

local function doAddonCompartment()
	if AddonCompartmentFrame and settings.GetSetting("miniicon.addcompartment") then
		local aboutText = "Enchantrix"
		local mouseButtonNote = "\nDisplay information in item tooltips pertaining to disenchanting, prospecting, and milling results."
		AddonCompartmentFrame:RegisterAddon({
			text = aboutText,
			icon = "Interface/AddOns/Enchantrix/Skin/EnxOrb.blp",
			notCheckable = true,
			func = function(button, menuInputData, menu)
				click(button, menuInputData.buttonName)
			end,
			funcOnEnter = function(button)
				MenuUtil.ShowTooltip(button, function(tooltip)
					tooltip:SetText(aboutText .. mouseButtonNote)
				end)
			end,
			funcOnLeave = function(button)
				MenuUtil.HideTooltip(button)
			end,
		})
	end
end

function miniIcon.AddonLoaded()
	miniIcon.Reposition()

	if doAddonCompartment then
		doAddonCompartment()
		-- only call this function once
		doAddonCompartment = nil
	end
end