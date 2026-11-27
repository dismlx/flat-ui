local _, ns = ...

local CVAR = "cameraDistanceMaxZoomFactor"
local TOP, TOP_TEXT, SLACK = 2.6, "2.6", 1e-4
local LABEL = "Maximum camera distance"

local ZOOM_OUT = 50

local pending = nil
local result = nil

local function Calls()
	local cvar = _G.C_CVar
	if type(cvar) == "table" and not ns.IsSecret(cvar) then
		return cvar
	end
	return nil
end

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

local function Factor(text)
	local number = type(text) == "string" and tonumber(text) or nil
	return ns.Finite(number) and number or nil
end

local function AtTop(number)
	return number ~= nil and number >= TOP - SLACK
end

local function Write(text)
	local cvar = Calls()
	if not cvar or type(cvar.SetCVar) ~= "function" then
		return nil
	end
	pcall(cvar.SetCVar, CVAR, text)
	return Factor(Text())
end

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

function ns.CameraZoomGet()
	local number = Factor(Text())
	if number == nil then
		return nil
	end
	if pending ~= nil then
		return pending
	end
	return AtTop(number)
end

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
	local below = on and not AtTop(Factor(Text()))
	Apply(on)
	if below and result == "ok" and AtTop(Factor(Text())) and type(_G.CameraZoomOut) == "function" then
		pcall(_G.CameraZoomOut, ZOOM_OUT)
	end
end

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
