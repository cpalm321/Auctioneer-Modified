--[[
	Auctioneer
	Version: <%version%> (<%codename%>)
	Revision: $Id$
	URL: http://auctioneeraddon.com/

	This is an addon for World of Warcraft that adds statistical history to the auction data that is collected
	when the auction is scanned, so that you can easily determine what price
	you will be able to sell an item for at auction or at a vendor whenever you
	mouse-over an item in the game

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

	CoreManifest is the first Auctioneer file to be loaded

	CoreManifest will:
		Set up the AucAdvanced global table and its basic framework
		Load external libraries
		Set up basic debugging and logging functions
		Perform startup checks

	About the ABORTLOAD flag
		CoreManifest, and certain other Core modules, will set the ABORTLOAD flag
		if they detect a critical problem during loading.

		The ABORTLOAD flag will block the loading or activation of certain key functions
		of Auctioneer, but allows most other Core components to install regardless.
		This should, in most cases, avoid large (and confusing) error cascades.
]]

AucAdvanced = {
	Modules = {Filter={}, Match={}, Stat={}, Util={}},
	Data = {},
	Libraries = {},
	Debug = {},
	API = {},
	Buy = {},
	Config = {},
	Post = {},
	Resources = {Active=false}, -- 'Active' should never be nil
	Scan = {},
	Settings = {},
}
-- Note: Due to the way AucAdvanced.Const is constructed it is installed in CoreConst.lua
local lib = AucAdvanced

-- Manifest Constants
local DEV_VERSION = "9.1.DEV"
local MINIMUM_TOC = 11300
local MINIMUM_CLIENT = "1.13.0"
local API_CHANGED = 80300
local API_CHANGED_MESSAGE = "This version of Auctioneer will not work with World of Warcraft Retail client version 8.3.0 or later."
-- MINIMUM_BUILD is optional, and should only be used where TOC is not sufficient; otherwise it should be set to nil
local MINIMUM_BUILD = nil


-- Core File checking system: used to detect critical files that fail to load (i.e. due to lua errors while loading) - including this file!
-- Place AucAdvanced.CoreFileCheckIn(filename) at the start of the file, after checking for AucAdvanced, but before any checks for ABORTLOAD
-- Place AucAdvanced.CoreFileCheckOut(filename) at the very end of the file, preferably the last line of code
-- CoreMain will call CoreFileCheckOut() with no filename to finalize the check-in/out process, just before "gameactive"
local pendingCoreFile
lib.CoreFileCheckIn = function(filename)
	if pendingCoreFile then
		if not lib.ABORTLOAD then
			lib.ABORTLOAD = "Core file failed to load correctly: "..pendingCoreFile
		end
	end
	pendingCoreFile = filename
end
lib.CoreFileCheckOut = function(filename)
	if pendingCoreFile ~= filename then -- something went wrong
		if not lib.ABORTLOAD then
			lib.ABORTLOAD = "Core file failed to load correctly: "..(pendingCoreFile or filename or "Unknown")
		end
	end
	pendingCoreFile = nil
	if not filename then -- final check, functions not needed after this
		lib.CoreFileCheckIn = nil
		lib.CoreFileCheckOut = nil
	end
end
lib.CoreFileCheckIn("CoreManifest") -- check CoreManifest in as early as possible

-- Version checking
lib.Version="<%version%>";
if lib.Version:byte(1) == 60 then -- 60 = '<'
	lib.Version = DEV_VERSION
end
local major, minor, release, revision = strsplit(".", lib.Version)
lib.MajorVersion = major
lib.MinorVersion = minor
lib.RelVersion = release
lib.Revision = revision

-- Single instance of a 'no operation' dummy function
lib.NOPFUNCTION = function() end
-- Dummy function that returns the first parameter
lib.RETFUNCTION = function(x) return x end

-- Check TOC version meets minimum requirements
local _,build,_,tocVersion = GetBuildInfo()
if tocVersion >= API_CHANGED then
	-- This version of AucAdvanced doesn't support any known Retail client
	message(API_CHANGED_MESSAGE)
	lib.ABORTLOAD = "Incorrect WoW client version"
elseif tocVersion < MINIMUM_TOC or (MINIMUM_BUILD and tonumber(build) < MINIMUM_BUILD) then
	message("Auctioneer requires Classic game client version "..MINIMUM_CLIENT.." or higher.")
	lib.ABORTLOAD = "Incorrect WoW client version"
else
	-- Should be a Classic client
	local classicnum = floor(tocVersion / 10000)
	if classicnum > 0 then
		lib.Classic = classicnum
	else
		-- Should not really be possible...
		message("Auctioneer could not determine game client version")
		lib.ABORTLOAD = "Incorrect WoW client version"
	end
end

-- Check that Stubby exists
if not Stubby then
	-- Can only occur if the Stubby AddOn has loaded, but failed to create the Stubby global table
	-- Assume Stubby has already thrown an error in this case.
	if not lib.ABORTLOAD then lib.ABORTLOAD = "Missing library: Stubby" end
end

-- Test load libraries
local DebugLib, Configator, Babylonian, TipHelper, LibDataBroker
if LibStub then
	DebugLib = LibStub("DebugLib", true)
	Configator = LibStub("Configator", true)
	Babylonian = LibStub("Babylonian", true)
	TipHelper = LibStub("nTipHelper:1", true)
	LibDataBroker = LibStub("LibDataBroker-1.1", true)
else -- missing LibStub - for now we'll assume Stubby has already thrown an error for this
	if not lib.ABORTLOAD then lib.ABORTLOAD = "Missing library: LibStub" end
end
-- Check essential libraries
if not (Configator and Babylonian and TipHelper) then
	if not lib.ABORTLOAD then -- only report error if not already aborting load
		local missing = ""
		if not Configator then
			missing = missing.." Configator"
		end
		if not Babylonian then
			missing = missing.." Babylonian"
		end
		if not TipHelper then
			missing = missing.." Tiphelper"
		end
		lib.ABORTLOAD = "Missing library(s):"..missing
		geterrorhandler()("Auctioneer was unable to load one or more libraries:"..missing)
	end
end

lib.Libraries.DebugLib = DebugLib
lib.Libraries.Configator = Configator
lib.Libraries.Babylonian = Babylonian
lib.Libraries.TipHelper = TipHelper
lib.Libraries.LibDataBroker = LibDataBroker

-- Auctioneer's revision information functions

local versionPrefix = lib.MajorVersion.."."..lib.MinorVersion.."."..lib.RelVersion.."."
lib.moduledetail = {}
lib.revisions = {}
lib.distribution = {--[[<%revisions%>]]} --Currently unused, needs a change in the build script

-- LibRevision removed
lib.RegisterRevision = lib.NOPFUNCTION

function lib.GetCurrentRevision()
	local revNumber = 0
	local revFile
	for file, revision in pairs(lib.revisions) do
		if (revision > revNumber) then
			revNumber = revision
			revFile = file
		end
	end

	return revNumber, revFile
end

function lib.GetRevisionList()
	return lib.revisions
end

function lib.GetDistributionList()
	return lib.distribution
end


-- Auctioneer's debug functions

local addonName = "Auctioneer" -- the addon's name as it will be displayed in the debug messages

if DebugLib then
	-------------------------------------------------------------------------------
	-- Prints the specified message to nLog.
	--
	-- syntax:
	--    errorCode, message = debugPrint([message][, category][, title][, errorCode][, level])
	--
	-- parameters:
	--    message   - (string) the error message
	--                nil, no error message specified
	--    category  - (string) the category of the debug message
	--                nil, no category specified
	--    title     - (string) the title for the debug message
	--                nil, no title specified
	--    errorCode - (number) the error code
	--                nil, no error code specified
	--    level     - (string) nLog message level
	--                         Any nLog.levels string is valid.
	--                nil, no level specified
	--
	-- returns:
	--    errorCode - (number) errorCode, if one is specified
	--                nil, otherwise
	--    message   - (string) message, if one is specified
	--                nil, otherwise
	-------------------------------------------------------------------------------
	function lib.Debug.DebugPrint(message, category, title, errorCode, level)
		return DebugLib.DebugPrint(addonName, message, category, title, errorCode, level)
	end

	-------------------------------------------------------------------------------
	-- Brings the Level parameter into the auctioneer API fold.
	-- Level is a lookup table for validating the 'level' parameter used in DebugPrint
	-- example AucAdvanced.Debug.Level.Critical
	lib.Debug.Level = DebugLib.Level

	-------------------------------------------------------------------------------
	-- Used to make sure that conditions are met within functions.
	-- If test is false, the error message will be written to nLog and the user's
	-- default chat channel.
	--
	-- syntax:
	--    assertion = assert(test, message)
	--
	-- parameters:
	--    test    - (any)     false/nil, if the assertion failed
	--                        anything else, otherwise
	--    message - (string)  the message which will be output to the user
	--
	-- returns:
	--    assertion - (boolean) true, if the test passed
	--                          false, otherwise
	-------------------------------------------------------------------------------
	function lib.Debug.Assert(test, message)
		return DebugLib.Assert(addonName, test, message)
	end


else
	-- DebugLib failed to load. Again this is considered non-essential as it is primarily used for info logging and debugging
	-- DebugPrint is used for logging to nLog - it does nothing if nLog is not installed
	lib.Debug.DebugPrint = lib.NOPFUNCTION
	lib.Debug.Level = {}
	lib.Debug.Assert = assert
	print("Auctioneer Manifest: DebugLib is missing")
end


function lib.ValidateInstall()
	if lib.ABORTLOAD then
		return nil, lib.ABORTLOAD
	end
	-- *ensure* we always return true or false, if not reporting an error
	if lib.Resources.Active then
		return true
	end
	return false
end


lib.RegisterRevision("$URL$", "$Rev$")
lib.CoreFileCheckOut("CoreManifest")
