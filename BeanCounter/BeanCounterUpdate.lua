--[[
	Auctioneer Addon for World of Warcraft(tm).
	Version: <%version%> (<%codename%>)
	Revision: $Id$
	URL: http://auctioneeraddon.com/

	BeanCounterUpdate - Upgrades the Beancounter Database to latest version

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
		since that is it's designated purpose as per:
		http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
]]

local libName = "BeanCounter"
local libType = "Util"
local lib = BeanCounter
local private, print, get, set, _BC = lib.getLocals()
private.update = {}

local function debugPrint(...)
    if get("util.beancounter.debugUpdate") then
        private.debugPrint("BeanCounterUpdate",...)
    end
end

local performedUpdate = false
function private.UpgradeDatabaseVersion()
	--Recreate the itemID array if for some reason user lacks it. Changed locations in version 3.0 database
	if not BeanCounterDBNames then BeanCounterDBNames = {} private.refreshItemIDArray() end
	
	for server, serverData in pairs(BeanCounterDB) do
		for player, playerData in pairs(serverData) do
			private.startPlayerUpgrade(server, player, playerData)
			private.startPlayerMaintenance(server, player)
		end
		--validate the DB for this server after all upgrades have completed
		if performedUpdate then --only if we actually had to update
			private.integrityCheck(true, server)
		end
	end
end

function private.startPlayerUpgrade(server, player, playerData)
	if playerData["version"] then
		if playerData["version"] < 2.0 then --Delete and start fresh
			BeanCounterDB[server][player] = nil
			private.initializeDB(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.01 then --removes old "Wealth entry to make room for reason codes
			private.update._2_01(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.02 then --bump version # only, the fix it implemented is merged into later updates
			private.update._2_02(server, player)
			performedUpdate = true
		end
		if  playerData["version"] < 2.03 then--if not upgraded yet then upgrade
			private.update._2_03(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.04 then --bump version # only, the fix it implemented is merged into later updates
			private.update._2_04(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.05 then --bump version # only, the fix it implemented is merged into later updates
			private.update._2_05(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.06 then --bump version # only 2.09 nukes the itemIDArray no need to wast time "updating" it
			private.update._2_06(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.07 then -- removes all 0 entries from stored strings. Makes all database entries same length for easier parsing
			private.update._2_07(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.08 then -- removes all 0 entries from stored strings. Makes all database entries same length for easier parsing
			private.update._2_08(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.09 then -- removes all 0 entries from stored strings. Makes all database entries same length for easier parsing
			private.update._2_09(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.10 then -- remove slash from completedBids/Buys table so its completedBidsBuys
			private.update._2_10(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.11 then -- adds neutral AH DB
			private.update._2_11(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 2.12 then -- corrects nil index bug in 2.11 upgrade
			private.update._2_12(server, player)
			performedUpdate = true
		end
		if playerData["version"] < 3 then -- Moves extra tables (settings, mail,  wealth, version and name array tables into their own DB's leaving only data in the BeanCounterDB table
			private.update._3_00(server, player)
	 		performedUpdate = true
	 	end
	end
	
	--[[Make sure to refrence the new version location for all new updates after _3_00]]
	local version = 999999
	if BeanCounterDBSettings and BeanCounterDBSettings[server] and BeanCounterDBSettings[server][player] then
		version = BeanCounterDBSettings[server][player]["version"] or version
	end
	
	if version < 3.01 then
 		private.update._3_01(server, player) --adds reforged itemstring value if missing
 		performedUpdate = true
	end
	if version < 3.02 then
 		private.update._3_02(server, player) --clear any data from the vendor tables
 		performedUpdate = true
	end
	if version < 3.03 then
 		private.update._3_03(server, player) --Removes the "profile.Default" table
 		performedUpdate = true
	end
	if version < 3.04 then
 		private.update._3_04(server, player) --Clear old tables due to itemString changes
 		performedUpdate = true
	end
	
end

function private.update._2_01(server, player)
	for DB, data in pairs(BeanCounterDB[server][player]) do
		if  DB == "failedBids" or DB == "failedAuctions" or DB == "completedAuctions" or DB == "completedBidsBuyouts" then
			for itemID, value in pairs(data) do
				for itemString, index in pairs(value) do
					for i, item in pairs(index) do
						local reason = item:match(".+;(.-)$")
						if tonumber(reason) or reason == "<nil>" then
							item = item:gsub("(.+);.-$", "%1;", 1)
							BeanCounterDB[server][player][DB][itemID][itemString][i] = item
						end
					end
				end
			end
		end
	end
	BeanCounterDB[server][player]["version"] = 2.01
end

function private.update._2_02(server, player)
	BeanCounterDB[server][player]["version"] = 2.02
end

function private.update._2_03(server, player)
	if BeanCounterDB[server][player]["version"] < 2.03 then
		for DB, data in pairs(BeanCounterDB[server][player]) do
			if  DB == "failedBids" or DB == "failedAuctions" or DB == "completedAuctions" or DB == "completedBidsBuyouts" or DB == "postedAuctions" or DB == "postedBids" then
				for itemID, value in pairs(data) do
					local temp = {}
					for itemString, index in pairs(value) do
						itemString = itemString..":80"
						temp[itemString] = index
					end
					BeanCounterDB[server][player][DB][itemID] = temp
				end
			end
		end
	end
	BeanCounterDB[server][player]["version"] = 2.03
		
	print("WOW version 30000 Update finished")
end

function private.update._2_04(server, player)
	BeanCounterDB[server][player]["version"] = 2.04
end

function private.update._2_05(server, player)
	BeanCounterDB[server][player]["version"] = 2.05
end

function private.update._2_06(server, player) --2.09 nukes the itemIDArray no need to wast time "updating" it
	BeanCounterDB[server][player]["version"] = 2.06
end

local function convert(DB , text)
	if  DB == "failedBids" then
		local money, Time = strsplit(";", text)
		text =  private.packString("", money,"", "", "", "", "", Time, "","")
	elseif DB == "failedAuctions" then
		local stack, buyout, bid, deposit, Time, reason = strsplit(";", text)
		text = private.packString(stack, "", deposit, "", buyout, bid,  "", Time, reason, "")
	elseif DB == "completedAuctions" then
		local stack,  money, deposit, fee, buyout, bid, buyer, Time, reason = strsplit(";", text)
		text = private.packString(stack,  money, deposit , fee, buyout , bid, buyer, Time, reason, "")
	elseif DB == "completedBidsBuyouts" then
		local stack,  money, fee, buyout, bid, buyer, Time, reason = strsplit(";", text)
		text = private.packString(stack,  money, "" , fee, buyout , bid, buyer, Time, reason, "")
	end
	return text
end

function private.update._2_07(server, player)
	for DB, data in pairs(BeanCounterDB[server][player]) do
		if  DB == "failedBids" or DB == "failedAuctions" or DB == "completedAuctions" or DB == "completedBidsBuyouts"  then
			for itemID, value in pairs(data) do
				for itemString, data in pairs(value) do
					for index, text in pairs(data) do
						text = convert(DB , text)
						BeanCounterDB[server][player][DB][itemID][itemString][index] = text
					end
				end
			end
		end
	end
	BeanCounterDB[server][player]["version"] = 2.07
end

--[[moves itemNameArray  to not store full itemlinks but generate when needed
from "10155:1046" = "|cff1eff00|Hitem:10155:0:0:0:0:0:1046:898585428:15|h[Mercurial Greaves of the Whale]|h|r",
to "10155:1046" = "cff1eff00:Mercurial Greaves of the Whale",
reduces saved variable size and slighty increases text string matching speed even with the overhead needed to change it back to an itemlink
]]
function private.update._2_08(server, player)
--just let 2.09 do it. 
	BeanCounterDB[server][player]["version"] = 2.08
end

--Storing the data using a colon caused issues with schematics so store using a ;  instead.
--Easiest to just regenerate the ItemID array
function private.update._2_09(server, player)
	if BeanCounterDB["ItemIDArray"] then
		local _, item = next(BeanCounterDB["ItemIDArray"])
		--if not in new format then upgrade itemID array otherwise leave it alone
		if item and not item:match("c........;.-") then
			debugPrint("UPGRADE itemName", item)
			for itemKey, itemLink in pairs(BeanCounterDB["ItemIDArray"]) do
				local color, name = itemLink:match("|(.-)|.item.*%[(.+)%].*")
				local data = string.join(";", color, name)
				BeanCounterDB["ItemIDArray"][itemKey] = data
			end
		end
	end
	BeanCounterDB[server][player]["version"] = 2.09
end

--removes slash from DB name completedBidsBuyouts
function private.update._2_10(server, player)
	for DB, data in pairs(BeanCounterDB[server][player]) do
		if  DB == "completedBids/Buyouts" then
			BeanCounterDB[server][player]["completedBidsBuyouts"] = data
			BeanCounterDB[server][player]["completedBids/Buyouts"] = nil
		end
	end
	BeanCounterDB[server][player]["version"] = 2.10
end

--Helper function for 2.11 update
local function migrateNeutralData(server, player, key, itemID, itemString, value)
	key = key.."Neutral"
	if not value then return end --Possible nil values could be inserted.
	if BeanCounterDB[server][player][key][itemID] then --if ltemID exists
		if BeanCounterDB[server][player][key][itemID][itemString] then
			table.insert(BeanCounterDB[server][player][key][itemID][itemString], value)
		else
			BeanCounterDB[server][player][key][itemID][itemString] = {value}
		end
	else
		BeanCounterDB[server][player][key][itemID]={[itemString] = {value}}
	end
end

--adds in databases used for neutral AH trx handling, migrates neutral AH data over to these DB
function private.update._2_11(server, player)
	BeanCounterDB[server][player]["completedAuctionsNeutral"] = {}
	BeanCounterDB[server][player]["failedAuctionsNeutral"] = {}

	BeanCounterDB[server][player]["completedBidsBuyoutsNeutral"]  = {}
	BeanCounterDB[server][player]["failedBidsNeutral"]  = {}
		
	for DB, data in pairs(BeanCounterDB[server][player]) do
		if  DB == "failedBids" or DB == "failedAuctions" or DB == "completedAuctions" or DB == "completedBidsBuyouts" then
			for itemID, itemIDData in pairs(data) do
				for itemString, itemStringData in pairs(itemIDData) do
					for i = #itemStringData, 1, -1 do
						local stack, money, deposit , fee, buyout , bid, buyer, Time, reason, location = private.unpackString(itemStringData[i])
						if location and location == "N" then
--~ 							print(player, server, itemString)
							migrateNeutralData(server, player, DB, itemID, itemString, itemStringData[i]) --local help[er function
							--itemStringData[i] = nil --This was a bad idea, left nil holes in my indexed data tables. We correct Nils in upgrade 2.12
							table.remove(itemStringData, i)
						end
					end
				end
			end
		end
	end

	BeanCounterDB[server][player]["version"] = 2.11
end

--correct nil holes in the transaction tables indexes
function private.update._2_12(server, player)
	for DB, data in pairs(BeanCounterDB[server][player]) do
		if  DB == "failedBids" or DB == "failedAuctions" or DB == "completedAuctions" or DB == "completedBidsBuyouts" then
			for itemID, itemIDData in pairs(data) do
				for itemString, itemStringData in pairs(itemIDData) do
					for i = #itemStringData, 1, -1 do
						if not itemStringData[i] then --catch Nil values in indexed tables and remove em'
							table.remove(itemStringData, i)
						end
					end
				end
			end
		end
	end

	BeanCounterDB[server][player]["version"] = 2.12
end

--Moves settings, name array into dedicated saved variables. leaving only transaction data in BeanCounterDB
function private.update._3_00(server, player)
	--move settings table, run once
	if BeanCounterDB.settings then
		BeanCounterDBSettings = BeanCounterDB.settings
		BeanCounterDB.settings = nil
	end
	--move the itemName array, run once
	if BeanCounterDB.ItemIDArray then
		BeanCounterDBNames = BeanCounterDB.ItemIDArray
		BeanCounterDB.ItemIDArray = nil
	end
	--move mail, wealth, faction, version to settings table, run per toon
	for DB, data in pairs(BeanCounterDB[server][player]) do
		--create server, player settings seperate from Global settings
		if not BeanCounterDBSettings[server] then BeanCounterDBSettings[server] = {} end
		if not BeanCounterDBSettings[server][player] then BeanCounterDBSettings[server][player] = {} end
		if DB == "wealth" then
			BeanCounterDBSettings[server][player].wealth = BeanCounterDB[server][player].wealth
			BeanCounterDB[server][player].wealth = nil
		elseif DB == "mailbox" then
			BeanCounterDBSettings[server][player].mailbox = BeanCounterDB[server][player].mailbox
			BeanCounterDB[server][player].mailbox = nil
		elseif DB == "version" then
			BeanCounterDBSettings[server][player].version = BeanCounterDB[server][player].version
			BeanCounterDB[server][player].version = nil
		elseif DB == "faction" then
			BeanCounterDBSettings[server][player].faction = BeanCounterDB[server][player].faction
			BeanCounterDB[server][player].faction = nil
		end
	end
	--new location for version info
	BeanCounterDBSettings[server][player].version = 3
end

--Add new reforged item position on all keys
function private.update._3_01(server, player)
	--[[ disabled: reforge no longer exists
	for DB, data in pairs(BeanCounterDB[server][player]) do
		for itemID, itemIDData in pairs(data) do
			local del = {}
			for itemString, itemStringData in pairs(itemIDData) do
				local _, _, _, reforged = lib.API.decodeLink(itemString)
				if not reforged then
					del[itemString] = itemStringData
				end
			end
			for i,v in pairs(del)do
				itemIDData[i..":0"] = v
				itemIDData[i] = nil
			end
		end
	end
	--]]
	BeanCounterDBSettings[server][player].version = 3.01
end

--remove any entries in the vendor tables, old cruft can cause errors
function private.update._3_02(server, player)
	BeanCounterDB[server][player]["vendorsell"] = {}
	BeanCounterDB[server][player]["vendorbuy"] = {}	
	BeanCounterDBSettings[server][player].version = 3.02
end

--new configuration settings/parser rewrite. Removes the "profile.Default" table, removes "maintenance" table
function private.update._3_03(server, player)
	if BeanCounterDBSettings["profile.Default"] then
		for setting, value in pairs(BeanCounterDBSettings["profile.Default"]) do
			BeanCounterDBSettings[setting] = value
		end
		BeanCounterDBSettings["profile.Default"] = nil
	end
	if BeanCounterDBSettings and BeanCounterDBSettings[server] and BeanCounterDBSettings[server][player] then
		BeanCounterDBSettings[server][player].maintenance = nil
		BeanCounterDBSettings[server][player].version = 3.03
	end	
end

-- nothing pre WoW 7.0 will match due to itemstring changes
function private.update._3_04(server, player)

	-- Nuclear option, because we can't update item strings and still match in 7.0
	BeanCounterDB[server][player]["completedAuctions"] = {}
	BeanCounterDB[server][player]["completedAuctionsNeutral"] = {}
	BeanCounterDB[server][player]["completedBidsBuyouts"] = {}
	BeanCounterDB[server][player]["completedBidsBuyoutsNeutral"] = {}
	BeanCounterDB[server][player]["failedAuctions"] = {}
	BeanCounterDB[server][player]["failedAuctionsNeutral"] = {}
	BeanCounterDB[server][player]["failedBids"] = {}
	BeanCounterDB[server][player]["failedBidsNeutral"] = {}
	BeanCounterDB[server][player]["postedAuctions"] = {}
	BeanCounterDB[server][player]["postedBids"] = {}
	BeanCounterDB[server][player]["vendorbuy"] = {}
	BeanCounterDB[server][player]["vendorsell"] = {}
	
	if BeanCounterDBSettings and BeanCounterDBSettings[server] and BeanCounterDBSettings[server][player] then
		BeanCounterDBSettings[server][player].version = 3.04
	end
end

