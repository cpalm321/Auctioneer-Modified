--[[
	Auctioneer - Search UI - Searcher General
	Version: 3.4.6985 (SwimmingSeadragon) - MODIFIED V5 (Combined Chest/Robe Slot)
	Revision: $Id: SearcherGeneral.lua 6985 2023-08-28 00:00:20Z none $
	URL: http://auctioneeraddon.com/
    ... (license and notes as before) ...
--]]
if not AucSearchUI then return end
local lib, parent, private = AucSearchUI.NewSearcher("General")
if not lib then return end
-- Revert to original_get, original_set, original_default as we abandoned auto-reset
local get, set, default, Const = AucSearchUI.GetSearchLocals()
lib.tabname = "General"
local aucPrint = AucAdvanced.Print -- Using AucAdvanced.Print for debug, if available

-- Function to get item types for the main "Type" dropdown
function private.getTypes()
	local typetable = private.typetable
	if not typetable then
		typetable = {{-1, "All"}}
		private.typetable = typetable
		local classIDs, classNames = Const.AC_ClassIDList, Const.AC_ClassNameList
		for index, classID in ipairs(classIDs) do
			tinsert(typetable, {classID, classNames[index]})
		end
	end
	return typetable
end

-- Function to get item subtypes, dependent on the selected "Type"
function private.getSubTypes()
	local subtypetable
	local classID = get("general.type")
	if classID == private.lastsubtypeclass then subtypetable = private.subtypetable end
	if not subtypetable then
		subtypetable = {{-1, "All"}}
		private.subtypetable = subtypetable
		private.lastsubtypeclass = classID
		local subClassIDs, subClassNames = Const.AC_SubClassIDLists[classID], Const.AC_SubClassNameLists[classID]
		if subClassIDs then
			for index, subClassID_val in ipairs(subClassIDs) do
				tinsert(subtypetable, {subClassID_val, subClassNames[index]})
			end
		end
	end
	return subtypetable
end

function private.getQuality()
	return {
			{-1, "All"}, {0, "Poor"}, {1, "Common"}, {2, "Uncommon"},
			{3, "Rare"}, {4, "Epic"}, {5, "Legendary"}, {6, "Artifact"},
		}
end

function private.getTimeLeft()
    if AucAdvanced.Classic == 1 then
        return {
            {0, "Any"}, {1, "< 30 min"}, {2, "30 min - 2 hrs"}, {3, "2 hrs - 8 hrs"}, {4, "8 hrs - 24 hrs"},
        }
    else
        return {
            {0, "Any"}, {1, "< 30 min"}, {2, "30 min - 2 hrs"}, {3, "2 hrs - 12 hrs"}, {4, "12 hrs - 48 hrs"},
        }
    end
end

function private.getArmorTypesForFilter()
    local armorTypes = {{-1, "Any"}}
    local armorClassID = LE_ITEM_CLASS_ARMOR
    if armorClassID and Const.AC_SubClassIDLists and Const.AC_SubClassIDLists[armorClassID] then
        local subClassIDs, subClassNames = Const.AC_SubClassIDLists[armorClassID], Const.AC_SubClassNameLists[armorClassID]
        for i, subClassID_val in ipairs(subClassIDs) do
            local subClassName = subClassNames[i]
            if subClassName == GetItemSubClassInfo(armorClassID, 1) or -- Cloth
               subClassName == GetItemSubClassInfo(armorClassID, 2) or -- Leather
               subClassName == GetItemSubClassInfo(armorClassID, 3) or -- Mail
               subClassName == GetItemSubClassInfo(armorClassID, 4) then -- Plate
                 tinsert(armorTypes, {subClassID_val, subClassName})
            end
        end
    end
    return armorTypes
end

-- MODIFIED: getItemSlots to combine Chest and Robe
function private.getItemSlots()
    local slots = {{-1, "All Slots"}}
    local slotOrder = {
        -- invTypeString, localizedNameOverride (optional)
        {invTypeString = "INVTYPE_HEAD"},
        {invTypeString = "INVTYPE_NECK"},
        {invTypeString = "INVTYPE_SHOULDER"},
        {invTypeString = "INVTYPE_CLOAK"},
        {invTypeString = "INVTYPE_CHEST", localizedName = _G.INVTYPE_CHEST .. " / " .. _G.INVTYPE_ROBE}, -- Combined label
        -- INVTYPE_ROBE is intentionally omitted here as it's covered by INVTYPE_CHEST entry
        {invTypeString = "INVTYPE_BODY"}, -- Shirt
        {invTypeString = "INVTYPE_TABARD"},
        {invTypeString = "INVTYPE_WRIST"},
        {invTypeString = "INVTYPE_HAND"},
        {invTypeString = "INVTYPE_WAIST"},
        {invTypeString = "INVTYPE_LEGS"},
        {invTypeString = "INVTYPE_FEET"},
        {invTypeString = "INVTYPE_FINGER"},
        {invTypeString = "INVTYPE_TRINKET"},
        {invTypeString = "INVTYPE_WEAPONMAINHAND"},
        {invTypeString = "INVTYPE_WEAPONOFFHAND"},
        {invTypeString = "INVTYPE_2HWEAPON"},
        {invTypeString = "INVTYPE_WEAPON"}, -- General weapon
        {invTypeString = "INVTYPE_SHIELD"},
        {invTypeString = "INVTYPE_RANGED"},
        {invTypeString = "INVTYPE_THROWN"},
        {invTypeString = "INVTYPE_HOLDABLE"}
    }
    local addedSlotsByCode = {} -- To avoid duplicates if multiple INVTYPE strings map to same code or for our combined logic
    for _, slotData in ipairs(slotOrder) do
        local invTypeStr = slotData.invTypeString
        local numericCode = Const.EquipEncode[invTypeStr]
        local displayName = slotData.localizedName or _G[invTypeStr] -- Use override or default localized name

        if numericCode and displayName and not addedSlotsByCode[numericCode] then
            tinsert(slots, {numericCode, displayName})
            addedSlotsByCode[numericCode] = true
        end
    end
    return slots
end

-- Set our defaults
default("general.name", "")
default("general.name.exact", false)
default("general.name.regexp", false)
default("general.name.invert", false)
default("general.type", -1)
default("general.subtype", -1)
default("general.quality", -1)
default("general.timeleft", 0)
default("general.ilevel.min", 0)
default("general.ilevel.max", Const.MAXITEMLEVEL)
default("general.ulevel.min", 0)
default("general.ulevel.max", Const.MAXUSERLEVEL)
default("general.seller", "")
default("general.seller.exact", false)
default("general.seller.regexp", false)
default("general.seller.invert", false)
default("general.minbid", 0)
default("general.minbuy", 0)
default("general.maxbid", Const.MAXBIDPRICE)
default("general.maxbuy", Const.MAXBIDPRICE)
default("general.armortype1", -1)
default("general.itemslot", -1)
-- ... (previous defaults) ...
default("general.itemslot", -1)
default("general.showstats.enable", false)
default("general.scanstats.enable", false)

local function resetGeneralSearchCriteria(currentGui) -- Added currentGui parameter
    set("general.type", -1)
    set("general.subtype", -1)
    set("general.armortype1", -1)
    set("general.quality", -1)
    set("general.timeleft", 0)
    set("general.itemslot", -1)
    set("general.name", "")
    set("general.seller", "")
    set("general.name.exact", false)
    set("general.name.regexp", false)
    set("general.name.invert", false)
    set("general.seller.exact", false)
    set("general.seller.regexp", false)
    set("general.seller.invert", false)
    set("general.ilevel.min", 0)
    set("general.ilevel.max", Const.MAXITEMLEVEL)
    set("general.ulevel.min", 0)
    set("general.ulevel.max", Const.MAXUSERLEVEL)
    set("general.showstats.enable", false)

    -- Now use the passed 'currentGui' to refresh the UI
    if currentGui and currentGui.Refresh then
        currentGui:Refresh() -- Call Refresh on the passed GUI object
    else
        if aucPrint then
            aucPrint("Note: GUI refresh method not found after resetting search criteria.")
        else
            print("Note: GUI refresh method not found after resetting search criteria.")
        end
    end
end

function lib:MakeGuiConfig(gui)
	local id = gui:AddTab(lib.tabname, "Searchers")
	gui:AddSearcher("General", "Search for items by general properties such as name, level etc", 100)
	gui:AddHelp(id, "general searcher",
		"What does this searcher do?",
		"This searcher provides the ability to search for specific items by name, level, type, subtype (incl. armor), an optional additional armor type, item slot, seller, price, timeleft and other similar generals.")

	gui:MakeScrollable(id)
	gui:AddControl(id, "Header",     0,       "Search criteria")
	local last = gui:GetLast(id) -- 'last' is the Header control
	
	gui:SetControlWidth(0.35)
	local nameEdit = gui:AddControl(id, "Text",       0,    1, "general.name", "Item name")
	nameEdit:SetScript("OnTextChanged", function(selfBox) set("general.name", selfBox:GetText()) end)
	
	frame = gui.tabs[id].content
	private.frame = frame
	
	frame.resetSearchCriteria = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.resetSearchCriteria:SetSize(90, 21)
	frame.resetSearchCriteria:SetPoint("LEFT", frame, "CENTER", 110, 80)
	frame.resetSearchCriteria:SetText(('Reset Search'))
	frame.resetSearchCriteria:SetScript("OnClick", function()
        -- Check if the function exists (good practice)
        if type(resetGeneralSearchCriteria) == "function" then
            -- Call the function and pass the 'gui' object from MakeGuiConfig's scope
            resetGeneralSearchCriteria(gui)

            if aucPrint then
                aucPrint("General search criteria have been reset.")
            else
                print("General search criteria have been reset.") -- Fallback print
            end
        else
            if aucPrint then
                aucPrint("Error: resetGeneralSearchCriteria function is not defined.")
            else
                print("Error: resetGeneralSearchCriteria function is not defined.") -- Fallback print
            end
        end
    end)
	
	gui:AddControl(id, "Checkbox",   0, 0, "general.showstats.enable", "Show Stats Columns")
	gui:AddTip(id, "If checked, item stats (like DPS, Stamina, Agility, etc.) will be populated in their respective columns in the search results. This might slightly impact search performance.")
	
	gui:AddControl(id, "Checkbox",   0, 1, "general.scanstats.enable", "Scan Tooltips for Stats")
	gui:AddTip(id, "If checked, performs a background scan of item tooltips to build a robust stat database. Results appear on subsequent searches. Requires 'Show Stats Columns' to be enabled.")


	local cont = gui:GetLast(id) -- 'cont' is now nameEdit
	gui:SetLast(id, last)        -- Anchor for checkboxes is Header
	gui:AddControl(id, "Checkbox",   0.11, 0, "general.name.exact", "Exact")
	gui:SetLast(id, last)
	gui:AddControl(id, "Checkbox",   0.21, 0, "general.name.regexp", "Lua Pattern")
	gui:SetLast(id, last)
	gui:AddControl(id, "Checkbox",   0.35, 0, "general.name.invert", "Invert")
	gui:SetLast(id, last)
	
	-- Original anchor setup for the next block (Type/SubType/etc.)
	gui:SetLast(id, cont) -- 'cont' (nameEdit) is the anchor
	last = cont           -- 'last' is now also nameEdit
	
	-- Type, SubType (These are the first two "columns")
	gui:AddControl(id, "Note",       0.0, 1, 100, 14, "Type:")       -- yOffset 1 from 'last' (nameEdit)
	gui:AddControl(id, "Selectbox",  0.0, 1, private.getTypes, "general.type") -- yOffset 1 from previous Note
	gui:SetLast(id, last) -- Reset anchor to 'last' (nameEdit) for SubType column
	gui:AddControl(id, "Note",       0.3, 1, 100, 14, "SubType:")    -- yOffset 1 from 'last', xOffset 0.3
	gui:AddControl(id, "Selectbox",  0.3, 1, private.getSubTypes, "general.subtype") -- yOffset 1 from previous Note

    -- (Opt.) Armor - This will now appear after the DPS checkbox.
    -- It should start on a new line. We'll use its original xOffset of 0.6
    -- relative to the original 'last' (nameEdit) to try and keep its horizontal position,
    -- but ensure it's vertically after the DPS checkbox.
    local anchorAfterDPSCheckboxLine = gui:GetLast(id) -- Anchor is now the Tip for DPS checkbox

    gui:SetLast(id, last) -- Reset horizontal anchor context to 'last' (nameEdit)
                          -- This is for the xOffset 0.6 to be meaningful in its original context.
                          -- The control will naturally flow below previously added content.
    gui:AddControl(id, "Note",       0.6, 1, 100, 14, "(Opt.) Armor:") -- yOffset 1 from 'last' (nameEdit), xOffset 0.6
                                                                      -- This will place it on a new line if its natural flow dictates it.
    gui:AddControl(id, "Selectbox",  0.6, 1, private.getArmorTypesForFilter, "general.armortype1")


	-- Quality, TimeLeft, Item Slot
	last = gui:GetLast(id) -- Update 'last' to the end of the (Opt.) Armor controls
	gui:AddControl(id, "Note",       0.0, 1, 100, 14, "Quality:")
	gui:AddControl(id, "Selectbox",  0.0, 1, private.getQuality(), "general.quality")
	gui:SetLast(id, last)
	gui:AddControl(id, "Note",       0.3, 1, 100, 14, "TimeLeft:")
	gui:AddControl(id, "Selectbox",  0.3, 1, private.getTimeLeft(), "general.timeleft")
    gui:SetLast(id, last)
    gui:AddControl(id, "Note",       0.6, 1, 100, 14, "Item Slot:")
    gui:AddControl(id, "Selectbox",  0.6, 1, private.getItemSlots, "general.itemslot")

	-- Item Level and User Level sliders
	last = gui:GetLast(id)
	gui:SetControlWidth(0.37)
	gui:AddControl(id, "NumeriSlider",     0,    1, "general.ilevel.min", 0, Const.MAXITEMLEVEL, 1, "Min item level")
	gui:SetControlWidth(0.37)
	gui:AddControl(id, "NumeriSlider",     0,    1, "general.ilevel.max", 0, Const.MAXITEMLEVEL, 1, "Max item level")
	cont = gui:GetLast(id)

	gui:SetLast(id, last)
	gui:SetControlWidth(0.17)
	gui:AddControl(id, "NumeriSlider",     0.6, 0, "general.ulevel.min", 0, Const.MAXUSERLEVEL, 1, "Min user level")
	gui:SetControlWidth(0.17)
	gui:AddControl(id, "NumeriSlider",     0.6, 0, "general.ulevel.max", 0, Const.MAXUSERLEVEL, 1, "Max user level")

	gui:SetLast(id, cont)
	last = cont -- 'last' is now end of ilevel sliders line, used as anchor for Seller Name block

	-- Seller Name
	gui:SetControlWidth(0.35)
	local sellerEdit = gui:AddControl(id, "Text",       0,    1, "general.seller", "Seller name")
    sellerEdit:SetScript("OnTextChanged", function(selfBox) set("general.seller", selfBox:GetText()) end)
	local sellerNameRowStartAnchor = last -- This is the anchor before sellerEdit, for the seller checkboxes
	cont = gui:GetLast(id)                -- cont is now sellerEdit

	gui:SetLast(id, sellerNameRowStartAnchor)
	gui:AddControl(id, "Checkbox",   0.13, 0, "general.seller.exact", "Exact")
	gui:SetLast(id, sellerNameRowStartAnchor)
	gui:AddControl(id, "Checkbox",   0.23, 0, "general.seller.regexp", "Lua Pattern")
	gui:SetLast(id, sellerNameRowStartAnchor)
	gui:AddControl(id, "Checkbox",   0.37, 0, "general.seller.invert", "Invert")

	gui:SetLast(id, cont) -- Anchor for MoneyFrames is 'cont' (sellerEdit)
    last = cont

	-- Money Frames
	gui:AddControl(id, "MoneyFramePinned", 0, 1, "general.minbid", 0, Const.MAXBIDPRICE, "Minimum Bid")
	gui:SetLast(id, last) -- 'last' is sellerEdit
	gui:AddControl(id, "MoneyFramePinned", 0.5, 1, "general.minbuy", 0, Const.MAXBIDPRICE, "Minimum Buyout")
	
    last = gui:GetLast(id) -- 'last' is end of first money row
	gui:AddControl(id, "MoneyFramePinned", 0, 1, "general.maxbid", 0, Const.MAXBIDPRICE, "Maximum Bid")
	gui:SetLast(id, last)
	gui:AddControl(id, "MoneyFramePinned", 0.5, 1, "general.maxbuy", 0, Const.MAXBIDPRICE, "Maximum Buyout")
	
    -- Ensure the layout correctly finishes
    last = gui:GetLast(id)
    gui:SetLast(id, last)
end

-- SEARCH LOGIC FUNCTIONS

function private.LevelSearch(levelType, itemLevel)
	local min = get("general."..levelType..".min")
	local max = get("general."..levelType..".max")
	if itemLevel < min then private.debug = levelType.." too low"; return false end
	if itemLevel > max then private.debug = levelType.." too high"; return false end
	return true
end

function private.NameSearch(nametype,itemName)
	local name = get("general."..nametype)
	if not name or name == "" then return true end
	name = name:lower(); itemName = itemName:lower()
	local nameExact = get("general."..nametype..".exact")
	local nameRegexp = get("general."..nametype..".regexp")
	local nameInvert = get("general."..nametype..".invert")
	if nameExact and not nameRegexp then
		if name == itemName and not nameInvert then return true
		elseif name ~= itemName and nameInvert then return true end
		private.debug = nametype.." not exact"; return false
	end
	local plain, text = nil, name
	if not nameRegexp then plain = 1 elseif nameExact then text = "^"..name.."$" end
	local matches = itemName:find(text, 1, plain)
	if matches and not nameInvert then return true
	elseif not matches and nameInvert then return true end
	private.debug = nametype.." no match"; return false
end

function private.TypeSearch(itemClassID, itemSubClassID)
    local searchType = get("general.type")
    local searchSubType = get("general.subtype")
    local searchArmorType1 = get("general.armortype1")

    if searchType ~= -1 and searchType ~= itemClassID then
        private.debug = "Wrong Type"; return false
    end

    if itemClassID == LE_ITEM_CLASS_ARMOR then
        local subTypeIsArmorFilter = (searchSubType ~= -1)
        local armorType1IsFilter = (searchArmorType1 ~= -1)

        if not subTypeIsArmorFilter and not armorType1IsFilter then return true end

        local itemMatchesSubType = (searchSubType == -1 or itemSubClassID == searchSubType)
        local itemMatchesArmorType1 = (searchArmorType1 == -1 or itemSubClassID == searchArmorType1)

        if subTypeIsArmorFilter and not armorType1IsFilter then
            if itemMatchesSubType then return true end
            private.debug = "Wrong Armor SubType (Main)"; return false
        end
        if not subTypeIsArmorFilter and armorType1IsFilter then
            if itemMatchesArmorType1 then return true end
            private.debug = "Wrong Armor SubType (Optional)"; return false
        end
        if subTypeIsArmorFilter and armorType1IsFilter then
            if itemMatchesSubType or itemMatchesArmorType1 then return true end
            private.debug = "Wrong Armor SubType (Neither)"; return false
        end
        return true
    elseif searchSubType ~= -1 and searchSubType ~= itemSubClassID then
        private.debug = "Wrong Subtype (Non-Armor)"; return false
    end
    return true
end

-- MODIFIED: ItemSlotSearch to handle combined Chest/Robe
function private.ItemSlotSearch(itemEquipCode)
    local selectedSlotNumeric = get("general.itemslot") -- Numeric code from Const.EquipEncode
    if selectedSlotNumeric == -1 then return true end -- "All Slots" selected

    if not itemEquipCode then -- Item has no equip slot (e.g., reagent)
        private.debug = "No equip slot data for item"
        return false -- If a specific slot is selected, non-equippable items don't match
    end

    -- Check for the combined Chest/Robe case first
    -- If user selected "Chest / Robe" (which has value Const.EquipEncode.INVTYPE_CHEST)
    if selectedSlotNumeric == Const.EquipEncode.INVTYPE_CHEST then
        if itemEquipCode == Const.EquipEncode.INVTYPE_CHEST or itemEquipCode == Const.EquipEncode.INVTYPE_ROBE then
            return true
        end
    -- Standard direct match for other slots
    elseif itemEquipCode == selectedSlotNumeric then
        return true
    end
    
    -- General "Weapon" slot handling (if user selected generic INVTYPE_WEAPON)
    if selectedSlotNumeric == Const.EquipEncode.INVTYPE_WEAPON then
        if itemEquipCode == Const.EquipEncode.INVTYPE_WEAPONMAINHAND or
           itemEquipCode == Const.EquipEncode.INVTYPE_WEAPONOFFHAND or
           itemEquipCode == Const.EquipEncode.INVTYPE_2HWEAPON then
            return true
        end
    end

    private.debug = "Wrong Item Slot"
    return false
end


function private.TimeSearch(iTleft)
	local tleft_filter = get("general.timeleft")
	if tleft_filter == 0 then return true end
	if tleft_filter == iTleft then return true end
	private.debug = "Time left wrong"; return false
end

function private.QualitySearch(iqual)
	local quality = get("general.quality")
	if quality == -1 then return true
	elseif quality == iqual then return true end
	private.debug = "Wrong Quality"; return false
end

function private.PriceSearch(buybid, price)
	local minprice, maxprice
	if buybid == "Bid" then minprice,maxprice = get("general.minbid"),get("general.maxbid")
	else minprice,maxprice = get("general.minbuy"),get("general.maxbuy") end
	if maxprice == 0 or maxprice < minprice then maxprice = nil end
	if price >= minprice and (not maxprice or price <= maxprice) then return true
	elseif price < minprice then private.debug = buybid.." price low"
	else private.debug = buybid.." price high" end
	return false
end

-- MAIN SEARCH FUNCTION --
function lib.Search(item)
	private.debug = ""
    if not item or type(item) ~= "table" then private.debug = "Bad item data"; return false end

	if private.NameSearch("name", item[Const.NAME])
			and private.TypeSearch(item[Const.CLASSID], item[Const.SUBCLASSID])
            and private.ItemSlotSearch(item[Const.IEQUIP])
			and private.TimeSearch(item[Const.TLEFT])
			and private.QualitySearch(item[Const.QUALITY])
			and private.LevelSearch("ilevel", item[Const.ILEVEL])
			and private.LevelSearch("ulevel", item[Const.ULEVEL])
			and private.NameSearch("seller", item[Const.SELLER])
			and private.PriceSearch("Bid", item[Const.PRICE])
			and private.PriceSearch("Buy", item[Const.BUYOUT]) then
		return true
	else
		return false, private.debug
	end
end

function lib.Rescan()
	local searchName, minUseLevel, maxUseLevel, searchQuality, exactMatch, filterData
	local name = get("general.name")
	if name and name ~= "" and not get("general.name.regexp") and not get("general.name.invert") then
		searchName = name
		if get("general.name.exact") and #searchName < 60 then exactMatch = true end
	end
	local minlevel, maxlevel = get("general.ulevel.min"), get("general.ulevel.max")
	if minlevel ~= 0 then minUseLevel = minlevel end
	if maxlevel ~= Const.MAXUSERLEVEL then maxUseLevel = maxlevel end
	local quality = get("general.quality")
	if quality > 0 then searchQuality = quality end
	local classID, subClassID = get("general.type"), get("general.subtype")
	classID, subClassID = tonumber(classID), tonumber(subClassID)
	if classID ~= -1 then
		if subClassID == -1 then subClassID = nil end
		filterData = AucAdvanced.Scan.QueryFilterFromID(classID, subClassID)
	end
	if searchName or filterData then
		AucSearchUI.RescanAuctionHouse(searchName, minUseLevel, maxUseLevel, nil, searchQuality, exactMatch, filterData)
	end
end

AucAdvanced.RegisterRevision("$URL: Auc-Advanced/Modules/Auc-Util-SearchUI/SearcherGeneral.lua $", "$Rev: 6985 $ MODIFIED V5")