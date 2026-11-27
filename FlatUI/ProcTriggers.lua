local _, ns = ...

local KEY = "trackers"
local PART = "proctriggers"
local IsSecret = ns.IsSecret

local K = {
	MAX_ID = 2147483647, SHORTER = 0.6, LOOK = 0.2,
	EVENTS = { "SPELL_UPDATE_USABLE", "ACTION_USABLE_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
		"SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" },
	LOOKS = { SPELL_UPDATE_USABLE = true, ACTION_USABLE_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true, PLAYER_TARGET_CHANGED = true },
	UNITS = { UNIT_POWER_FREQUENT = "player", UNIT_HEALTH = "target" },
	NO_TIME = "%s needs a time above 0 seconds. Set it first with /flatui tracker proc time.",
	NO_SPELL = "%s has no spell it is for.",
	NO_CAST_TIME = "This client does not give a spell's cast time.",
	NO_USABLE = "This client does not say when a spell is usable.",
	INSTANT = "%s is instant already.",
}
local T = { frame = nil, player = false, pending = false, casts = 0, queued = false, late = false, cast = {}, on = {}, rest = {}, last = {}, heard = {},
	ask = {}, units = {} }

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= K.MAX_ID and value == math.floor(value)
end

local function Now()
	local ok, now = pcall(GetTime)
	if ok and Plain(now, "number") then
		return now
	end
	return 0
end

local function Lists(list, id)
	for _, value in ipairs(type(list) == "table" and list or {}) do
		if value == id then
			return true
		end
	end
	return false
end

local function Dirty()
	if type(ns.TrackerDirty) == "function" then
		ns.TrackerDirty()
	end
end

local function After(delay, fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(delay, fn)
		return true
	end
	return false
end

local function InCombat()
	local ok, fighting = pcall(InCombatLockdown)
	return not (ok and Plain(fighting, "boolean") and not fighting)
end

local function Procs(trigger)
	local found = {}
	local all = type(ns.ProcEntries) == "function" and ns.ProcEntries() or {}
	for _, entry in ipairs(all) do
		if entry.kind == "proc" and (trigger == nil or entry.trigger == trigger) then
			found[#found + 1] = entry
		end
	end
	return found
end

local function SpellName(spellID)
	local call = type(C_Spell) == "table" and C_Spell.GetSpellName
	if type(call) ~= "function" then
		return nil
	end
	local ok, name = pcall(call, spellID)
	if ok and Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

local function CastTime(spellID)
	local call = type(C_Spell) == "table" and C_Spell.GetSpellInfo
	if type(call) ~= "function" then
		return nil
	end
	local ok, info = pcall(call, spellID)
	if not ok or IsSecret(info) or type(info) ~= "table" then
		return nil
	end
	local time = info.castTime
	if Plain(time, "number") and time >= 0 then
		return time
	end
	return nil
end

local function KnownHere(spellID)
	local book = C_SpellBook
	if type(book) == "table" then
		for _, call in ipairs({ "IsSpellKnownOrInSpellBook", "IsSpellKnown" }) do
			local fn = book[call]
			if type(fn) == "function" then
				local ok, known = pcall(fn, spellID)
				if ok and Plain(known, "boolean") then
					return known
				end
			end
		end
	end
	return nil
end

local function Asked(entry)
	local lights = type(entry.lights) == "table" and entry.lights or {}
	local kept = T.ask[entry.id]
	if kept and kept.list == lights and kept.count == #lights then
		return kept.light
	end
	local light
	for index = #lights, 1, -1 do
		if Whole(lights[index]) and KnownHere(lights[index]) == true then
			light = lights[index]
			break
		end
	end
	light = light or lights[1]
	T.ask[entry.id] = { list = lights, count = #lights, light = light }
	return light
end

local function Texture(spellID)
	local call = type(C_Spell) == "table" and C_Spell.GetSpellTexture
	if type(call) ~= "function" or not Whole(spellID) then
		return nil
	end
	local ok, file = pcall(call, spellID)
	if ok and (Plain(file, "number") or Plain(file, "string")) then
		return file
	end
	return nil
end

local function Usable(spellID)
	local call = type(C_Spell) == "table" and C_Spell.IsSpellUsable
	if type(call) ~= "function" then
		return nil
	end
	local ok, usable, power = pcall(call, spellID)
	if not ok or IsSecret(usable) or IsSecret(power) or type(usable) ~= "boolean" then
		return nil
	end
	return usable, power == true
end

local function Seconds(milliseconds)
	return ("%g"):format(milliseconds / 1000)
end

local function LightName(entry)
	local light = entry.lights and entry.lights[1]
	return (Whole(light) and SpellName(light)) or entry.name or "This proc"
end

local function Begin(entry)
	local since, time = Now(), entry.time
	local state = { since = since }
	if Plain(time, "number") and time > 0 then
		state.expires, state.length = since + time, time
	end
	return state
end

local function Reading(state)
	if not state then
		return { state = "missing", hidden = false }
	end
	if state.expires and Now() >= state.expires then
		return { state = "missing", hidden = false }
	end
	return { state = "fine", hidden = false, expires = state.expires, length = state.length }
end

local function Cast(spellID)
	local name
	for _, entry in ipairs(Procs("cast")) do
		local id = entry.id
		if name == nil then
			name = SpellName(spellID) or false
		end
		local ends = Lists(entry.lights, spellID)
		for _, light in ipairs(not ends and name and entry.lights or {}) do
			ends = ends or SpellName(light) == name
		end
		if ends then
			if T.cast[id] then
				T.cast[id] = nil
				Dirty()
			end
		elseif Lists(entry.spells, spellID) then
			local state = Begin(entry)
			if state.expires then
				T.cast[id] = state
				T.heard[id] = (T.heard[id] or 0) + 1
				After(state.length + 0.05, Dirty)
				Dirty()
			end
		end
	end
end

local function Rest()
	if InCombat() then
		return
	end
	for _, entry in ipairs(Procs("casttime")) do
		local light = entry.lights and entry.lights[1]
		if Whole(light) and ns.TrackerBuffOn(entry.spells) == false then
			local time = CastTime(light)
			if time and time > 0 then
				T.rest[entry.id] = time
			end
		end
	end
end

local function LookTime(entry)
	local id, light, rest = entry.id, entry.lights and entry.lights[1], T.rest[entry.id]
	if not (rest and Whole(light)) then
		return false
	end
	local now = CastTime(light)
	if not now then
		return false
	end
	local fast = now == 0 or (entry.kind2 == "shorter" and now <= K.SHORTER * rest)
	if fast and not T.on[id] then
		T.on[id] = Begin(entry)
		return true
	elseif not fast and T.on[id] then
		T.on[id] = nil
		return true
	end
	return false
end

local function LookUsable(entry)
	local id, light = entry.id, Asked(entry)
	if not Whole(light) then
		return false
	end
	local usable, power = Usable(light)
	if usable == nil then
		return false
	end
	local state = usable and "usable" or (power and "power" or "blocked")
	local before = T.last[id]
	T.last[id] = state
	local on = T.on[id]
	if on and on.expires and Now() >= on.expires then
		T.on[id], on = nil, nil
	end
	if state == "usable" and before ~= nil and before ~= "usable" and not on then
		T.on[id] = Begin(entry)
		return true
	elseif state == "blocked" and on then
		T.on[id] = nil
		return true
	end
	return false
end

local function Look()
	local changed = false
	for _, entry in ipairs(Procs()) do
		if entry.trigger == "casttime" then
			changed = LookTime(entry) or changed
		elseif entry.trigger == "usable" then
			changed = LookUsable(entry) or changed
		end
	end
	if changed then
		Dirty()
	end
end

local function Schedule()
	if not T.queued then
		T.queued = true
		if not After(0, function()
			T.queued = false
			ns.EachPart(KEY, PART, Look)
		end) then
			T.queued = false
			Look()
			return
		end
	end
	if not T.late then
		T.late = true
		if not After(K.LOOK, function()
			T.late = false
			ns.EachPart(KEY, PART, Look)
		end) then
			T.late = false
		end
	end
end

local function Heard(event, ...)
	if event == "UNIT_AURA" then
		Schedule()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if not T.player and (IsSecret(unit) or unit ~= "player") then
			return
		end
		T.casts = T.casts + 1
		if Whole(spellID) then
			Cast(spellID)
		end
		Schedule()
	elseif K.UNITS[event] then
		local unit = ...
		if not T.units[event] and (IsSecret(unit) or unit ~= K.UNITS[event]) then
			return
		end
		Schedule()
	elseif K.LOOKS[event] then
		Schedule()
	else
		if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
			T.ask = {}
		end
		Rest()
		Schedule()
	end
end

local function Listen(frame, event, unit)
	if frame.RegisterUnitEvent then
		local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, unit or "player")
		if ok and (IsSecret(registered) or registered ~= false) then
			return true
		end
	end
	pcall(frame.RegisterEvent, frame, event)
	return false
end

local function Make()
	if T.frame or type(CreateFrame) ~= "function" then
		return
	end
	local frame = CreateFrame("Frame")
	ns.Own[frame] = true
	T.frame = frame
	local aura = Listen(frame, "UNIT_AURA")
	local cast = Listen(frame, "UNIT_SPELLCAST_SUCCEEDED")
	T.player = aura and cast
	for event, unit in pairs(K.UNITS) do
		T.units[event] = Listen(frame, event, unit)
	end
	for _, event in ipairs(K.EVENTS) do
		pcall(frame.RegisterEvent, frame, event)
	end
	frame:SetScript("OnEvent", function(_, event, ...)
		if ns.Enabled(KEY) then
			ns.EachPart(KEY, PART, Heard, event, ...)
		end
	end)
	ns.EachPart(KEY, PART, Rest)
	After(0, function()
		ns.EachPart(KEY, PART, Rest)
		ns.EachPart(KEY, PART, Look)
	end)
end

local function Seen()
	if T.frame or T.pending then
		return
	end
	if InCombat() then
		T.pending = true
		ns.OutOfCombat(function()
			T.pending = false
			Make()
		end)
	else
		Make()
	end
end

local function Noticed(entry)
	return ("Your casts noticed: %d, %d for this proc."):format(T.casts, T.heard[entry.id] or 0)
end

local function Time(entry)
	local seconds = Plain(entry.time, "number") and entry.time or 0
	return seconds > 0 and ("Time: %s seconds."):format(tostring(seconds)) or "Time: none, so a cast does not start an alert."
end

local function Forget(id)
	T.on[id], T.last[id], T.cast[id], T.ask[id] = nil, nil, nil, nil
end

ns.ProcTrigger("cast", {
	Text = "your cast", Label = "your cast", Seen = Seen, Forget = Forget,
	Read = function(entry)
		local state = T.cast[entry.id]
		if state and state.expires and Now() >= state.expires then
			T.cast[entry.id] = nil
			state = nil
		end
		return Reading(state)
	end,
	Valid = function(entry)
		if not (Plain(entry.time, "number") and entry.time > 0) then
			return false, K.NO_TIME:format(entry.name or "This proc")
		end
		return true
	end,
	Lines = function(entry)
		return { Noticed(entry), Time(entry) }
	end,
})

ns.ProcTrigger("casttime", {
	Text = "cast time", Label = "cast time", Seen = Seen, Forget = Forget,
	Read = function(entry)
		if not T.rest[entry.id] then
			return nil
		end
		return Reading(T.on[entry.id])
	end,
	Valid = function(entry)
		local light = entry.lights and entry.lights[1]
		if not Whole(light) then
			return false, K.NO_SPELL:format(entry.name or "This proc")
		end
		if not (type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function") then
			return false, K.NO_CAST_TIME
		end
		local time = T.rest[entry.id]
		if not time and ns.TrackerBuffOn(entry.spells) == false then
			time = CastTime(light)
		end
		if time == 0 then
			return false, K.INSTANT:format(LightName(entry))
		end
		return true
	end,
	Lines = function(entry)
		local light = entry.lights and entry.lights[1]
		local now = Whole(light) and CastTime(light) or nil
		local rest = T.rest[entry.id]
		return { ("Spell it is for: %s, now %s s, at rest %s s."):format(LightName(entry), now and Seconds(now) or "not known", rest and Seconds(rest) or "not known") }
	end,
})

ns.ProcTrigger("usable", {
	Text = "usable", Label = "usable", Seen = Seen, Either = true, Forget = Forget,
	Used = function(entry)
		T.on[entry.id] = nil
	end,
	Read = function(entry)
		if T.last[entry.id] == nil then
			return nil
		end
		local reading = Reading(T.on[entry.id])
		if reading.state == "fine" then
			reading.icon = Texture(Asked(entry))
		end
		return reading
	end,
	Valid = function(entry)
		if not Whole(entry.lights and entry.lights[1]) then
			return false, K.NO_SPELL:format(entry.name or "This proc")
		end
		if not (type(C_Spell) == "table" and type(C_Spell.IsSpellUsable) == "function") then
			return false, K.NO_USABLE
		end
		return true
	end,
	Lines = function(entry)
		local light = Asked(entry)
		local usable, power
		if Whole(light) then
			usable, power = Usable(light)
		end
		local word = usable == nil and "not known" or (usable and "yes" or (power and "no, not enough power" or "no"))
		return { ("Spell it is for: %s, rank asked %s, usable now: %s."):format(LightName(entry), tostring(light), word) }
	end,
})
