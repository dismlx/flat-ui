local _, ns = ...

-- Compare items only while holding Shift (chat.compareShift on the Tooltips page of Chat and tooltips, on by default). The game shows the items the
-- player wears beside the tooltip of an item when TooltipUtil.ShouldDoItemComparison says so: always while its variable alwaysCompareItems is on,
-- else only while the modified click COMPAREITEMS is held, Shift (Blizzard_SharedXMLGame/Tooltip/TooltipUtil.lua:4-6,
-- Blizzard_FrameXML/Bindings_Camelot.xml:1546). Every tooltip that compares asks it as it is filled (TooltipDataRules.lua:168-175), and the bag
-- slots and ItemRefTooltip ask it again on each refresh (Mainline/ContainerFrame.lua:1752, Mainline/ItemRef.lua:356), so the comparison comes and
-- goes with Shift. On WoW: Forever the variable is on by default and kept for the account (wowless, data/products/wowf/cvars.yaml), and the
-- game's options have no row for it: only a toggle in the gamepad menus of the bags and the Character window writes it
-- (Mainline/ContainerFrame.lua:743-755, Camelot/PaperDollFrame.lua:1777-1787).
-- While the row and Chat and tooltips are on, Flat UI writes 0, out of combat: at login and when the row, the switch or the profile changes.
-- The text the variable had before the first write is kept in FlatUIDB.compareGame and written back when the row, the switch or the module goes
-- off while the variable is still 0; a value set meanwhile some other way is left as it is. Nothing of the game's tooltips is touched.
-- C_CVar.GetCVar and SetCVar take a name and plain text (CVarDocumentation.lua:20-33, 131-148).

local KEY = "chat"
local CVAR = "alwaysCompareItems"
-- The text of the variable while the game compares only with Shift held.
local OFF = "0"

-- A write waits for combat to end.
local queued = false
-- How the last write ended while the row was on: nil when nothing was asked, "ok" or "refused".
local result = nil

local function Calls()
	local cvar = _G.C_CVar
	if type(cvar) == "table" and not ns.IsSecret(cvar) then
		return cvar
	end
	return nil
end

-- The text of the variable, or nil when the client has no such variable or withholds it.
local function Text()
	local cvar = Calls()
	if not cvar or type(cvar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(cvar.GetCVar, CVAR)
	if ok and not ns.IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

-- Writes the text and says whether the variable holds it after.
local function Write(text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return false
	end
	pcall(cvar.SetCVar, CVAR, text)
	return Text() == text
end

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(KEY .. ".compareShift") == true
end

local function Apply()
	queued = false
	local now, db = Text(), ns.Account()
	if now == nil or type(db) ~= "table" then
		return
	end
	if Wanted() then
		if now == OFF then
			result = "ok"
			return
		end
		-- What the game had before the first write, kept for the account like the variable itself.
		if db.compareGame == nil then
			db.compareGame = now
		end
		if Write(OFF) then
			result = "ok"
			return
		end
		-- The game kept its value: nothing of Flat UI's stands, so there is nothing to put back.
		db.compareGame = nil
		result = "refused"
		return
	end
	result = nil
	local game = db.compareGame
	if type(game) ~= "string" then
		-- Nothing was written by this addon, so the game's value stays.
		return
	end
	db.compareGame = nil
	if now == OFF and game ~= OFF then
		Write(game)
	end
end

-- Chat.lua calls this at the start of each refresh, and Core.lua at every login, whatever the switch of Chat and tooltips: the variable is the
-- account's, so a character whose profile has the row or the module off gets the game's value back. Nothing is written in combat.
function ns.ItemCompareSync()
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(Apply)
end

ns.AddStatus(KEY, function()
	if not Wanted() or Text() == nil then
		return {}
	end
	if queued then
		return { "Compare items: only while holding Shift. Waiting for combat to end." }
	elseif result == "refused" then
		return { "Compare items: the game kept comparing without Shift." }
	end
	return { "Compare items: only while holding Shift." }
end)
