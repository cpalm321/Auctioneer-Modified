--[[
	Auctioneer - Search UI - Searcher EnchantMats
	Version: 3.4.6985 (SwimmingSeadragon)
	Revision: $Id: SearcherEnchantMats.lua 6985 2023-08-28 00:00:20Z none $
	URL: http://auctioneeraddon.com/

	This is a plugin module for the SearchUI that assists in searching by refined paramaters

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

-- check prerequisites
if not AucAdvanced then return end
if not AucSearchUI then return end


-- Create a new instance of our lib with our parent
local lib, parent, private = AucSearchUI.NewSearcher("EnchantMats")
if not lib then return end
--local print,decode,_,_,replicate,empty,_,_,_,debugPrint,fill = AucAdvanced.GetModuleLocals()
local get, set ,default ,Const, resources = parent.GetSearchLocals()
lib.tabname = "EnchantMats"


-- Enchanting reagents, from Enchantrix EnxConstants.lua
local VOID = 22450
local NEXUS = 20725
local LPRISMATIC = 22449
local LBRILLIANT = 14344
local LRADIANT = 11178
local LGLOWING = 11139
local LGLIMMERING = 11084
local SPRISMATIC = 22448
local SBRILLIANT = 14343
local SRADIANT = 11177
local SGLOWING = 11138
local SGLIMMERING = 10978
local GPLANAR = 22446
local GETERNAL = 16203
local GNETHER = 11175
local GMYSTIC = 11135
local GASTRAL = 11082
local GMAGIC = 10939
local LPLANAR = 22447
local LETERNAL = 16202
local LNETHER = 11174
local LMYSTIC = 11134
local LASTRAL = 10998
local LMAGIC = 10938
local ARCANE = 22445
local ILLUSION = 16204
local DREAM = 11176
local VISION = 11137
local SOUL = 11083
local STRANGE = 10940

local RILLUSION = 156930

local DREAM_SHARD = 34052
local SDREAM_SHARD = 34053
local INFINITE = 34054
local GCOSMIC = 34055
local LCOSMIC = 34056
local ABYSS = 34057

local HEAVENLY_SHARD = 52721
local SHEAVENLY_SHARD = 52720
local HYPNOTIC = 52555
local GCELESTIAL = 52719
local LCELESTIAL = 52718
local MAELSTROM = 52722

local SHA_CRYSTAL = 74248
local SHA_CRYSTAL_FRAGMENT = 105718
local ETHERAL = 74247
local SETHERAL = 74252
local SPIRIT = 74249
local MYSTERIOUS = 74250

local DRAENIC = 109693
local SLUMINOUS = 115502
local LUMINOUS = 111245
local TEMPORAL = 113588
local FRACTEMPORAL = 115504

local ARKHANA	= 124440
local LEYLIGHT_SHARD = 124441
local CHAOS_CRYSTAL = 124442

local GLOOMDUST = 152875
local UMBRASHARD = 152876
local VEILEDCRYSTAL = 152877

local reagentsList
-- Taken from DisenchantReagentList in EnxConstants.lua
-- Used to generate the UI and to initialize other elements
-- Note we only use the Classic tables as AucAdvanced does not support Retail
if resources.Classic == 1 then
	reagentsList = {

			NEXUS,

			LBRILLIANT,
			LRADIANT,
			LGLOWING,
			LGLIMMERING,

			SBRILLIANT,
			SRADIANT,
			SGLOWING,
			SGLIMMERING,

			GETERNAL,
			GNETHER,
			GMYSTIC,
			GASTRAL,
			GMAGIC,

			LETERNAL,
			LNETHER,
			LMYSTIC,
			LASTRAL,
			LMAGIC,

			ILLUSION,
			DREAM,
			VISION,
			SOUL,
			STRANGE,

	}
else -- Wrath Classic
	reagentsList = {

			ABYSS,
			VOID,
			NEXUS,

			DREAM_SHARD,
			LPRISMATIC,
			LBRILLIANT,
			LRADIANT,
			LGLOWING,
			LGLIMMERING,

			SDREAM_SHARD,
			SPRISMATIC,
			SBRILLIANT,
			SRADIANT,
			SGLOWING,
			SGLIMMERING,

			GCOSMIC,
			GPLANAR,
			GETERNAL,
			GNETHER,
			GMYSTIC,
			GASTRAL,
			GMAGIC,

			LCOSMIC,
			LPLANAR,
			LETERNAL,
			LNETHER,
			LMYSTIC,
			LASTRAL,
			LMAGIC,

			INFINITE,
			ARCANE,
			ILLUSION,
			DREAM,
			VISION,
			SOUL,
			STRANGE,

	}
end

-- Provides labels for the Reagent Sliders in the UI
-- Some string are not used, but may become useful in future expansions
local reagentStrings = {

	[MYSTERIOUS] = "Mysterious Essence %s%%",
	[GCELESTIAL] = "Greater Celestial Essence %s%%",
	[GCOSMIC] = "Greater Cosmic Essence %s%%",

	[GPLANAR] = "Greater Planar Essence %s%%",
	[GETERNAL] = "Greater Eternal Essence %s%%",
	[GNETHER] = "Greater Nether Essence %s%%",
	[GMYSTIC] = "Greater Mystic Essence %s%%",
	[GASTRAL] = "Greater Astral Essence %s%%",
	[GMAGIC] = "Greater Magic Essence %s%%",

	[LCELESTIAL] = "Lesser Celestial Essence %s%%",
	[LCOSMIC] = "Lesser Cosmic Essence %s%%",
	[LPLANAR] = "Lesser Planar Essence %s%%",
	[LETERNAL] = "Lesser Eternal Essence %s%%",
	[LNETHER] = "Lesser Nether Essence %s%%",
	[LMYSTIC] = "Lesser Mystic Essence %s%%",
	[LASTRAL] = "Lesser Astral Essence %s%%",
	[LMAGIC] = "Lesser Magic Essence %s%%",

	[GLOOMDUST] = "Gloom Dust %s%%",
	[ARKHANA] = "Arkhana %s%%",
	[DRAENIC] = "Draenic Dust %s%%",
	[SPIRIT] = "Spirit Dust %s%%",
	[HYPNOTIC] = "Hypnotic Dust %s%%",
	[INFINITE] = "Infinite Dust %s%%",
	[ARCANE] = "Arcane Dust %s%%",
	[RILLUSION] = "Rich Illusion Dust %s%%",
	[ILLUSION] = "Illusion Dust %s%%",
	[DREAM] = "Dream Dust %s%%",
	[VISION] = "Vision Dust %s%%",
	[SOUL] = "Soul Dust %s%%",
	[STRANGE] = "Strange Dust %s%%",

	[UMBRASHARD] = "Umbra Shard %s%%",
	[LEYLIGHT_SHARD] = "Leylight Shard %s%%",
	[LUMINOUS] = "Luminous Shard %s%%",
	[ETHERAL] = "Ethereal Shard %s%%",
	[HEAVENLY_SHARD] = "Heavenly Shard %s%%",
	[DREAM_SHARD] = "Dream Shard %s%%",
	[LPRISMATIC] = "Large Prismatic Shard %s%%",
	[LBRILLIANT] = "Large Brilliant Shard %s%%",
	[LRADIANT] = "Large Radiant Shard %s%%",
	[LGLOWING] = "Large Glowing Shard %s%%",
	[LGLIMMERING] = "Large Glimmering Shard %s%%",

	[SLUMINOUS] = "Small Luminous Shard %s%%",
	[SETHERAL] = "Small Ethereal Shard %s%%",
	[SHEAVENLY_SHARD] = "Small Heavenly Shard %s%%",
	[SDREAM_SHARD] = "Small Dream Shard %s%%",
	[SPRISMATIC] = "Small Prismatic Shard %s%%",
	[SBRILLIANT] = "Small Brilliant Shard %s%%",
	[SRADIANT] = "Small Radiant Shard %s%%",
	[SGLOWING] = "Small Glowing Shard %s%%",
	[SGLIMMERING] = "Small Glimmering Shard %s%%",

	[VEILEDCRYSTAL] = "Veiled Crystal %s%%",
	[CHAOS_CRYSTAL] = "Chaos Crystal %s%%",
	[TEMPORAL] = "Temporal Crystal %s%%",
	[FRACTEMPORAL] = "Fractured Temporal Crystal %s%%",
	[SHA_CRYSTAL] = "Sha Crystal %s%%",
	[SHA_CRYSTAL_FRAGMENT] = "Sha Crystal Fragment %s%%",
	[MAELSTROM] = "Maelstrom Crystal %s%%",
	[ABYSS] = "Abyss Crystal %s%%",
	[VOID] = "Void Crystal %s%%",
	[NEXUS] = "Nexus Crystal %s%%",

}

-- Table to check for valid itemIDs; populated below
local validReagents = {}

-- Set our defaults
default("enchantmats.level.custom", false)
default("enchantmats.level.min", 0)
default("enchantmats.level.max", Const.MAXSKILLLEVEL)
default("enchantmats.allow.bid", true)
default("enchantmats.allow.buy", true)
default("enchantmats.maxprice", 10000000)
default("enchantmats.maxprice.enable", false)
default("enchantmats.model", "Enchantrix")

for _, reagent in ipairs(reagentsList) do
	-- Flag reagent as valid
	validReagents[reagent] = true
	-- Set default Slider value
	default("enchantmats.PriceAdjust."..reagent, 100)
end

function private.doValidation()
	if not resources.isEnchantrixLoaded then
		message("EnchantMats Searcher Warning!\nEnchantrix not detected\nThis searcher will not function until Enchantrix is loaded")
	elseif not resources.isValidPriceModel(get("enchantmats.model")) then
		message("EnchantMats Searcher Warning!\nCurrent price model setting ("..get("enchantmats.model")..") is not valid. Select a new price model")
	else
		private.doValidation = nil
	end
end

-- This function is automatically called from AucSearchUI.NotifyCallbacks
function lib.Processor(event, subevent)
	if event == "selecttab" then
		if subevent == lib.tabname and private.doValidation then
			private.doValidation()
		end
	end
end

-- This function is automatically called when we need to create our search parameters
function lib:MakeGuiConfig(gui)
	if private.MakeGuiConfig then private.MakeGuiConfig(gui) end
end

function private.MakeGuiConfig(gui)
	private.MakeGuiConfig = nil -- this function will be garbage collected as no longer needed
	-- Get our tab and populate it with our controls
	local id = gui:AddTab(lib.tabname, "Searchers")
	gui:MakeScrollable(id)

	-- Add the help
	gui:AddSearcher("Enchant Mats", "Search for items which will disenchant for you into given reagents (for levelling)", 100)
	gui:AddHelp(id, "enchantmats searcher",
		"What does this searcher do?",
		"This searcher provides the ability to search for items which will disenchant into the reagents you need to have in order to level your enchanting skill. It is not a searcher meant for profit, but rather least cost for levelling.")

	gui:AddControl(id, "Header",     0,      "EnchantMats search criteria")

	local last = gui:GetLast(id)

	gui:AddControl(id, "Checkbox",          0.42, 1, "enchantmats.allow.bid", "Allow Bids")
	gui:SetLast(id, last)
	gui:AddControl(id, "Checkbox",          0.56, 1, "enchantmats.allow.buy", "Allow Buyouts")
	gui:AddControl(id, "Checkbox",          0.42, 1, "enchantmats.maxprice.enable", "Enable individual maximum price:")
	gui:AddTip(id, "Limit the maximum amount you want to spend with the EnchantMats searcher")
	gui:AddControl(id, "MoneyFramePinned",  0.42, 2, "enchantmats.maxprice", 1, Const.MAXBIDPRICE, "Maximum Price for EnchantMats")

	gui:AddControl(id, "Label",             0.42, 1, nil, "Price Valuation Method:")
	gui:AddControl(id, "Selectbox",         0.42, 1, resources.selectorPriceModelsEnx, "enchantmats.model")
	gui:AddTip(id, "The pricing model that is used to work out the calculated value of items at the Auction House.")

	gui:SetLast(id, last)
	gui:AddControl(id, "Checkbox",          0, 1, "enchantmats.level.custom", "Use custom enchanting skill levels")
	gui:AddControl(id, "Slider",            0, 2, "enchantmats.level.min", 0, Const.MAXSKILLLEVEL, 25, "Minimum skill: %s")
	gui:AddControl(id, "Slider",            0, 2, "enchantmats.level.max", 25, Const.MAXSKILLLEVEL, 25, "Maximum skill: %s")

	-- spacer to allow for all the controls on the right hand side
	gui:AddControl(id, "Note",              0, 0, nil, 40, "")

	-- aka "what percentage of estimated value am I willing to pay for this reagent"?
	gui:AddControl(id, "Subhead",          0,    "Reageant Price Modification")

	for _, reagent in ipairs(reagentsList) do
		local label = reagentStrings[reagent] or "Unknown "..tostring(reagent).." %s%%" -- Just in case of missing string or typo
		gui:AddControl(id, "WideSlider", 0, 1, "enchantmats.PriceAdjust."..reagent, 0, 200, 1, label)
	end
	-- Note: local upvalue tables reagentsList and reagentStrings will be garbage collected along with private.MakeGuiConfig function

end

function lib.Search(item)
	-- Can't do anything without Enchantrix
	if not resources.isEnchantrixLoaded then
		return false, "Enchantrix not detected"
	end

	local itemID = item[Const.ITEMID]

	local bidprice, buyprice = item[Const.PRICE], item[Const.BUYOUT]
	local maxprice = get("enchantmats.maxprice.enable") and get("enchantmats.maxprice")
	if buyprice <= 0 or not get("enchantmats.allow.buy") or (maxprice and buyprice > maxprice) then
		buyprice = nil
	end
	if not get("enchantmats.allow.bid") or (maxprice and bidprice > maxprice) then
		bidprice = nil
	end
	if not (bidprice or buyprice) then
		return false, "Does not meet bid/buy requirements"
	end

	local market
	if validReagents[itemID] then
		-- item itself is a reagent; just use item's value
		market = resources.GetPrice(get("enchantmats.model"), itemID)
		if not market then
			return false, "No price for item"
		end

		-- be safe and handle nil results
		local adjustment = get("enchantmats.PriceAdjust."..itemID) or 0
		market = (market * item[Const.COUNT]) * adjustment / 100
	else -- it's not a reagent, figure out what it DEs into
		local itemQuality = item[Const.QUALITY]
		-- All disenchantable items are "uncommon" quality or higher
		-- so bail on items that are white or gray
		if itemQuality <= 1 then
			return false, "Item quality too low"
		end

		local minskill, maxskill
		if get("enchantmats.level.custom") then
			minskill = get("enchantmats.level.min")
			maxskill = get("enchantmats.level.max")
		else
			minskill = 0
			maxskill = Enchantrix.Util.GetUserEnchantingSkill()
		end

		local skillneeded = Enchantrix.Util.DisenchantSkillRequiredForItemLevel(item[Const.ILEVEL], itemQuality)
		if (skillneeded < minskill) or (skillneeded > maxskill) then
			return false, "Skill not high enough to Disenchant"
		end

		local data = Enchantrix.Storage.GetItemDisenchants(item[Const.LINK])
		if not data then -- Give up if it doesn't disenchant to anything
			return false, "Item not Disenchantable"
		end

		local total = data.total

		if total and total[1] > 0 then
			market = 0
			local totalNumber, totalQuantity = unpack(total)
			local model = get("enchantmats.model")
			local GetPrice = resources.lookupPriceModel[model]
			for result, resData in pairs(data) do
				if result ~= "total" then
					local resNumber, resQuantity = unpack(resData)
					local price = GetPrice(model, result)
					price = (price or 0) * resQuantity / totalNumber

					-- be safe and handle nil results
					local adjustment = get("enchantmats.PriceAdjust."..result) or 0
					market = market + price * adjustment / 100
				end
			end
		end

	end
	if not market or market <= 0 then
		return false, "No Price Found"
	end

	if buyprice and buyprice <= market then
		return "buy", market
	elseif bidprice and bidprice <= market then
		return "bid", market
	end
	return false, "Not enough profit"
end

AucAdvanced.RegisterRevision("$URL: Auc-Advanced/Modules/Auc-Util-SearchUI/SearcherEnchantMats.lua $", "$Rev: 6985 $")
