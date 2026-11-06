local _, ns = ...

-- Maximum camera distance (general.cameraZoom on the Flat UI page). The game's own Max Camera Distance slider stops at 2.0 on WoW: Forever
-- (Blizzard_SettingsDefinitions_Frame/Camelot/ControlsOverrides.lua:5-14: 1.0 to 2.0 in steps of 0.1), while the variable behind it,
-- cameraDistanceMaxZoomFactor, takes 2.6. The row holds no value of its own, like the rows that show a game setting: it reads the variable and is
-- ticked while it is 2.6 or more, so it is the same in every profile, and a change made with the game's slider shows at once. It is not one of the
-- rows with cvar in Config.lua, which hold the variable itself; this one holds a choice of two values. Ticked, it keeps the text the variable had in
-- FlatUIDB.cameraGame, then writes 2.6, out of combat; a value of 2.6 or more is never lowered, and a write the game does not keep whole is undone.
-- Unticked while the variable is still 2.6 or more, it writes back the kept text, or the client's default when it kept none, and forgets it; a value
-- the game or the player lowered meanwhile is left as it is. C_CVar.GetCVar, GetCVarDefault and SetCVar take a name and plain text
-- (CVarDocumentation.lua:20-33, 66-80, 131-148).
-- This follows the maximum camera zoom of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Settings/Camera.lua:1-29).

local CVAR = "cameraDistanceMaxZoomFactor"
-- The factor the row writes, and how far below it a value read back may be and still count as it.
local TOP, TOP_TEXT, SLACK = 2.6, "2.6", 1e-4
local LABEL = "Maximum camera distance"

-- The value waiting for the end of a fight, or nil.
local pending = nil
-- How the last change made in this session ended: nil, "ok" or "kept".
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

-- The number in a text of the variable, or nil.
local function Factor(text)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

local function AtTop(number)
	return number ~= nil and number >= TOP - SLACK
end

-- Writes the text and gives the number the variable holds after it, or nil when the client cannot be asked.
local function Write(text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return nil
	end
	pcall(cvar.SetCVar, CVAR, text)
	return Factor(Text())
end

-- The client's default when it is below the top, else nil.
local function Default()
	local cvar = Calls()
	if not cvar or type(cvar.GetCVarDefault) ~= "function" then
		return nil
	end
	local ok, text = pcall(cvar.GetCVarDefault, CVAR)
	if ok and not ns.IsSecret(text) and Factor(text) ~= nil and not AtTop(Factor(text)) then
		return text
	end
	return nil
end

local function Kept()
	print(("Flat UI: the game kept %s %s."):format(LABEL, AtTop(Factor(Text())) and "on" or "off"))
end

local function Apply(on)
	local before = Text()
	local now = Factor(before)
	if now == nil then
		return
	end
	local db = ns.Account()
	if type(db) ~= "table" then
		return
	end
	if on then
		if AtTop(now) then
			result = "ok"
			return
		end
		-- What the game had is kept before the write.
		db.cameraGame = before
		local after = Write(TOP_TEXT)
		if AtTop(after) then
			result = "ok"
			return
		end
		db.cameraGame = nil
		if after ~= nil and after ~= now then
			Write(before)
		end
		result = "kept"
		Kept()
		return
	end
	local game = db.cameraGame
	db.cameraGame = nil
	result = nil
	if not AtTop(now) then
		return
	end
	local back = (Factor(game) ~= nil and not AtTop(Factor(game))) and game or Default()
	if back == nil then
		return
	end
	if AtTop(Write(back)) then
		result = "kept"
		Kept()
	end
end

-- The row's value: true while the variable is at the top, nil when it cannot be read (the row then shows its default, off).
function ns.CameraZoomGet()
	local number = Factor(Text())
	if number == nil then
		return nil
	end
	return AtTop(number)
end

-- The row was changed. Nothing is written in combat: the last choice made in a fight is written when it ends.
function ns.CameraZoomSet(_, value)
	local on = value == true
	if InCombatLockdown() then
		local queued = pending ~= nil
		pending = on
		if not queued then
			ns.OutOfCombat(function()
				local wanted = pending
				pending = nil
				if wanted ~= nil then
					Apply(wanted)
				end
			end)
		end
		return
	end
	pending = nil
	Apply(on)
end

-- The line of /flatui status, or nil when there is nothing to say: the client has no such variable, or the row is off and nothing waits.
function ns.CameraZoomStatus()
	local number = Factor(Text())
	if number == nil then
		return nil
	end
	if pending ~= nil then
		return LABEL .. ": waiting for combat to end."
	end
	if result == "kept" then
		return ("%s: the game kept %s."):format(LABEL, AtTop(number) and "on" or "off")
	end
	if AtTop(number) then
		return LABEL .. ": on."
	end
	return nil
end
