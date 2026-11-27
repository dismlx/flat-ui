local _, ns = ...

local KEY = "nameplates"
local SPREAD = { overlap = 70, edge = 90, full = 110, motion = 0.018, near = 0.0005, motionDefault = 0.025 }
local MOTION = { cvar = "nameplateMotionSpeed", kind = "number", label = "Nameplate motion speed" }

local function Def(key)
	local def = type(ns.Def) == "function" and ns.Def(KEY .. "." .. key) or nil
	return type(def) == "table" and def or nil
end

local function Flag(value)
	return not ns.IsSecret(value) and value == true
end

local function Open(cvar)
	local api = C_CVar
	if type(api) ~= "table" or type(api.GetCVar) ~= "function" or type(cvar) ~= "string" then
		return false
	end
	local ok, text = pcall(api.GetCVar, cvar)
	if not ok or ns.IsSecret(text) or type(text) ~= "string" then
		return false
	end
	if type(api.GetCVarInfo) ~= "function" then
		return true
	end
	local read, _, _, _, _, locked, _, readOnly = pcall(api.GetCVarInfo, cvar)
	return not read or not (Flag(locked) or Flag(readOnly))
end

local function GameDefault(cvar)
	local api = C_CVar
	if type(api) == "table" and type(api.GetCVarDefault) == "function" then
		local ok, text = pcall(api.GetCVarDefault, cvar)
		local number = ok and not ns.IsSecret(text) and tonumber(text) or nil
		if ns.Finite(number) then
			return number
		end
	end
	return SPREAD.motionDefault
end

local function Near(value, goal, within)
	return ns.Finite(value) and math.abs(value - goal) < within
end

local function Motion(slow)
	if not Open(MOTION.cvar) then
		return
	end
	local now = ns.CVarGet(MOTION)
	if slow then
		if not Near(now, SPREAD.motion, SPREAD.near) then
			ns.CVarSet(MOTION, SPREAD.motion, true)
		end
	elseif Near(now, SPREAD.motion, SPREAD.near) then
		ns.CVarSet(MOTION, GameDefault(MOTION.cvar), true)
	end
end

local function Overlap(value)
	local overlap = Def("overlapV")
	if overlap == nil or overlap.hidden or not Open(overlap.cvar) then
		return
	end
	local now = ns.CVarGet(overlap)
	if value == "slight" then
		if not Near(now, SPREAD.overlap, 0.5) then
			ns.CVarSet(overlap, SPREAD.overlap)
		end
	elseif value == "stack" and ns.Finite(now) and now < SPREAD.edge then
		ns.CVarSet(overlap, SPREAD.full)
	end
end

function ns.PlateSpreadGet()
	local enemies = Def("stackEnemies")
	if enemies == nil or type(ns.PlateStackGet) ~= "function" then
		return nil
	end
	local on = ns.PlateStackGet(enemies)
	if on == nil then
		return nil
	elseif on ~= true then
		return "off"
	end
	local overlap = Def("overlapV")
	local now = overlap and ns.CVarGet(overlap) or nil
	if ns.Finite(now) and now < SPREAD.edge then
		return "slight"
	end
	return "stack"
end

function ns.PlateSpreadSet(_, value)
	local enemies = Def("stackEnemies")
	if enemies == nil or type(ns.PlateStackSet) ~= "function" or (value ~= "off" and value ~= "slight" and value ~= "stack") then
		return
	end
	ns.PlateStackSet(enemies, value ~= "off")
	ns.OutOfCombat(function()
		Overlap(value)
		Motion(value == "slight")
	end)
end

function ns.PlateSpreadView(stacked, overlap)
	local shown = ns.Get(KEY .. ".spread")
	local live = ns.PlateSpreadGet()
	if shown == nil or live == nil or shown == live then
		return nil
	end
	if shown == "off" then
		return false, overlap
	elseif shown == "slight" then
		return true, SPREAD.overlap
	end
	return true, (ns.Finite(overlap) and overlap >= SPREAD.edge) and overlap or SPREAD.full
end

do
	local spread, enemies, overlap = Def("spread"), Def("stackEnemies"), Def("overlapV")
	if spread and (enemies == nil or enemies.hidden or overlap == nil or overlap.hidden) then
		spread.hidden = true
	end
end
