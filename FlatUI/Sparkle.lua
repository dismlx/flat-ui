local _, ns = ...

-- Quest item sparkle. On WoW: Forever a quest item in the world gets the game's loot effect, a sparkle, while the game's variable
-- outlineModeShowLootEffectWhenDisabled is 1. The game's options have no row for it on Forever: Blizzard_SettingsDefinitions_Frame/Camelot/
-- InterfaceOverrides.lua:5-6 leaves RegisterOutlineSettings empty, so only /console sets it. While Quest item sparkle is on, Flat UI writes
-- it out of combat: at login, when the row or the profile changes, and a second after the game writes its graphics quality or the variable
-- itself, as a graphics preset puts its own values back. Turned off, the value the game had before the first write is put back. The client
-- applies that at its next start, and an object already in view keeps its look until it appears again.
-- The variable and its behaviour are from players of Forever (Quality-of-Life-Forever pull request 167, ForeverLootSparkles), not from the
-- client's source.

local CVAR = "outlineModeShowLootEffectWhenDisabled"
-- The variables whose change is followed by a write: the graphics quality presets, and the variable itself.
local WATCHED = { graphicsquality = true, raidgraphicsquality = true, [CVAR:lower()] = true }
-- The wait after a watched change, so that a preset has written all of its values first.
local SETTLE = 1

-- A write waits for combat to end.
local pending = false
-- A write waits for SETTLE seconds.
local settling = false
-- How the last write ended while the row was on: nil when nothing was asked, "ok" or "refused".
local result
-- True once the game's own value was put back in this session.
local restored = false

-- The text of the variable, or nil when the client has no such variable or withholds it.
local function Text()
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(C_CVar.GetCVar, CVAR)
	if ok and not ns.IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Wanted()
	return ns.Get("general.questSparkle") == true
end

local function Write(value)
	if type(C_CVar.SetCVar) ~= "function" then
		return false
	end
	pcall(C_CVar.SetCVar, CVAR, value)
	return Text() == value
end

local function Apply()
	pending = false
	local now = Text()
	if now == nil then
		return
	end
	local db = type(FlatUIDB) == "table" and FlatUIDB or nil
	if Wanted() then
		restored = false
		if now == "1" then
			result = "ok"
			return
		end
		-- What the game had before the first write, kept for the account.
		if db and db.sparkleGame == nil then
			db.sparkleGame = now
		end
		result = Write("1") and "ok" or "refused"
		return
	end
	result = nil
	local game = db and db.sparkleGame
	if type(game) ~= "string" then
		-- Nothing was written by this addon, so the game's value stays.
		return
	end
	db.sparkleGame = nil
	if now ~= game and Write(game) then
		restored = true
	end
end

-- Nothing is written in combat.
local function Queue()
	if pending then
		return
	end
	pending = true
	ns.OutOfCombat(Apply)
end

-- The row, a profile switch and the login.
function ns.SparkleChanged()
	Queue()
end

-- A change of a variable (CVAR_UPDATE gives its name and its new text). A watched one is written again a second later.
function ns.SparkleCVar(name)
	if type(name) ~= "string" or ns.IsSecret(name) or not WATCHED[name:lower()] then
		return
	end
	if settling then
		return
	end
	if C_Timer and C_Timer.After then
		settling = true
		C_Timer.After(SETTLE, function()
			settling = false
			Queue()
		end)
	else
		Queue()
	end
end

-- The line of /flatui status, or nil when there is nothing to say: the client has no such variable, or the row is off and nothing was put back.
function ns.SparkleStatus()
	if Text() == nil then
		return nil
	end
	if not Wanted() then
		return restored and "Quest item sparkle: off. The game's own value applies from its next start." or nil
	end
	if pending then
		return "Quest item sparkle: on. Waiting for combat to end."
	end
	if result == "refused" then
		return "Quest item sparkle: on, but the game kept it off."
	end
	return "Quest item sparkle: on."
end
