local _, ns = ...

-- Proc triggers for a proc whose buff the game hides in a fight: your cast of the proc's spell (cast), a cast that has become instant or much
-- shorter (casttime) and an ability that has become usable (usable). Each is registered with ns.ProcTrigger (Procs.lua) and is read only while the
-- buff cannot be read, except usable, which says Either and is read also while the buff can be read and is missing: Overpower made usable by a
-- dodge, Revenge by a block, dodge or parry and Execute by a target at low health have no buff an addon can read (the game marks theirs not to be
-- shown), and C_Spell.IsSpellUsable is plain in fights (SpellDocumentation.lua:980-995) while the target's health is not. The frame of this file
-- hears the player's casts (UNIT_SPELLCAST_SUCCEEDED, which is withheld for some spells), a ping of UNIT_AURA that is never read,
-- SPELL_UPDATE_USABLE and ACTION_USABLE_CHANGED, the player's power, stance or form, the target and the target's health, and it is made when the
-- first proc with one of these triggers is in the list (the procs of the list and those of your class, ns.ProcEntries). C_Spell GetSpellInfo
-- gives castTime in milliseconds (Blizzard_CombatAudioAlertManager.lua:1150). Every value from the game is tested with ns.IsSecret before it is
-- compared, indexed or kept.

local KEY = "trackers"
local PART = "proctriggers"
local IsSecret = ns.IsSecret

-- SHORTER: a cast time this share of the one at rest or less is clearly shorter. LOOK: the second look after an event, in seconds.
-- EVENTS: the events of the frame that have no unit. LOOKS: those of them that only ask for a look. UNITS: the events heard for one unit, by
-- the unit.
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
-- What is known: the frame and whether it hears the player alone, the casts heard, and by entry id the cast that started an alert, the alert a
-- cast time or a usable spell started, the cast time at rest, the last state of a usable spell and the rank it asks about. queued and late are
-- the looks waiting. units: by event of K.UNITS, true when it is heard for its unit alone.
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

-- The procs watched, in list order and then those of your class (ns.ProcEntries, Procs.lua), of one trigger or of all.
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

-- The name of a spell, or nil.
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

-- The cast time of a spell in milliseconds with what is on the player now, or nil when the game gives none.
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

-- Whether the player knows a spell: true or false, nil when the game cannot say.
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

-- The rank of a usable proc's spell that is asked about: the highest the player knows (lights go from the lowest rank up), else the first. Kept
-- for the entry's list of lights until the spells change.
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

-- The icon of a spell, or nil.
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

-- Whether a spell is usable and whether power alone stops it: true or false, then true or false; nil when the game does not say.
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

-- The first spell the proc is for, its name, or the name of the proc.
local function LightName(entry)
	local light = entry.lights and entry.lights[1]
	return (Whole(light) and SpellName(light)) or entry.name or "This proc"
end

-- An alert that starts: its time when it has one.
local function Begin(entry)
	local since, time = Now(), entry.time
	local state = { since = since }
	if Plain(time, "number") and time > 0 then
		state.expires, state.length = since + time, time
	end
	return state
end

-- The reading of an alert: fine with its end while it is up, missing when it is down.
local function Reading(state)
	if not state then
		return { state = "missing", hidden = false }
	end
	if state.expires and Now() >= state.expires then
		return { state = "missing", hidden = false }
	end
	return { state = "fine", hidden = false, expires = state.expires, length = state.length }
end

-- Casts ---------------------------------------------------------------------------------------------------------------------------------

-- A cast of the player's: the proc's own spell starts the alert of a cast trigger, a spell it is for ends it, by its ID or by its name.
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

-- Looking ---------------------------------------------------------------------------------------------------------------------------

-- The cast time at rest of each cast time trigger, out of combat and with the buff off (a buff that makes the cast instant is not at rest).
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

-- A cast time that has become instant, or clearly shorter for an entry of kind shorter, starts the alert; the time at rest again ends it.
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

-- The highest rank known of a spell that was not usable and is: the alert starts, whether it was blocked or short of power (rage, energy or
-- mana for an ability the proc made usable, or the combo point of Overpower, which the game may count as power). Blocked again (the proc used or
-- gone, the wrong stance, a target above the health it needs): it ends. Short of power, it stays as it is: up while the proc lasts, down while it
-- does not. An alert whose time is out is over, so the next proc starts one again. The first answer after login starts nothing.
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

-- After an event: one look at once and one 0.2 seconds later, each asked for once however many events come.
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

-- The frame ---------------------------------------------------------------------------------------------------------------------------

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
		-- Heard for every unit when the game would not take the unit: only the one asked for is looked at.
		local unit = ...
		if not T.units[event] and (IsSecret(unit) or unit ~= K.UNITS[event]) then
			return
		end
		Schedule()
	elseif K.LOOKS[event] then
		Schedule()
	else
		-- A new rank is asked about once the spells change.
		if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
			T.ask = {}
		end
		Rest()
		Schedule()
	end
end

-- True when the event is registered for the unit alone (the player when none is given).
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

-- An entry with one of these triggers is in the list: the frame is made, out of combat.
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

-- The check ----------------------------------------------------------------------------------------------------------------------

local function Noticed(entry)
	return ("Your casts noticed: %d, %d for this proc."):format(T.casts, T.heard[entry.id] or 0)
end

local function Time(entry)
	local seconds = Plain(entry.time, "number") and entry.time or 0
	return seconds > 0 and ("Time: %s seconds."):format(tostring(seconds)) or "Time: none, so a cast does not start an alert."
end

-- The triggers -------------------------------------------------------------------------------------------------------------------------

ns.ProcTrigger("cast", {
	Text = "your cast", Label = "your cast", Seen = Seen,
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
	Text = "cast time", Label = "cast time", Seen = Seen,
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
	Text = "usable", Label = "usable", Seen = Seen, Either = true,
	-- Up with the icon of the spell it is for, the rank asked about.
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
