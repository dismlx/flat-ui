local _, ns = ...

-- Proc alerts: the kind of tracker called proc. A proc shows nothing until the buff of the proc is up, then its icon with the time left, a
-- sound once, and it ends when the buff ends, when the spell it is for is cast or when its time is up. A proc that starts again within 3 seconds
-- of its end (a reactive ability after each dodge, Execute as rage refills) is the same alert going on: no sound, and its art and glow carry on
-- without fading in or bursting again (Start). Where the game hides the buff in a fight, the game's own icon for the buff (TrackerSlots.lua)
-- shows the proc. The game's overlay events and IsSpellOverlayed are a second
-- way to know that a proc is up, for the trigger overlay: SpellActivationOverlay.lua loads only for the game types cata, mists and mainline
-- (Blizzard_FrameXML.toc:109-110), so on this client no event is expected, and the check says how many came. The art and the glow of a
-- proc are other files that provide ns.ProcArtShow, ns.ProcArtHide, ns.ProcGlowStart and ns.ProcGlowStop; each is called here only when it
-- is there. Every value from the game is tested with ns.IsSecret before it is compared, indexed or kept.
-- Procs of your class (on by default): every row of the class data that is automatic (ProcData.lua) and has a spell you know is a proc too,
-- without being added. These are not saved: ns.ProcAutoEntries gives them to the trackers that are on (Trackers.lua), each with the id "auto:"
-- and its name, one table kept for good so what the trackers know of it stays. One added by hand takes its place, with its own colour, time
-- and sound, and Remove a proc turns one off for the character (FlatUICharDB.procsOff, by name) until Bring back a proc.

local KEY = "trackers"
local PART = "procs"
local IsSecret = ns.IsSecret

-- MAX_SPELLS, MAX_TIME, SIZE: the most spell IDs in a list of an entry, the most seconds of a proc's time and its icon size.
-- KITS: the sound choices of the page by their saved word, the sound kit each stands for. The first five are the kits of ns.SOUNDS in
--   IconRow.lua; alarm is ALARM_CLOCK_WARNING_3 and whisper UI_RAID_BOSS_WHISPER_WARNING (SoundKitConstants.lua:95, 136).
-- FALL: the kit the game's own overlay plays (SpellActivationOverlay.lua:134), tried when the game refuses a kit.
-- COUNT: the counter of each event of the game's overlay. AGAIN: the seconds after the end of an alert within which the same proc starting again
-- carries it on (Start).
local K = {
	MAX_SPELLS = 40, MAX_TIME = 120, SIZE = 48, MAX_ID = 2147483647, AGAIN = 3,
	KITS = { spell = 23287, chimes = 316736, bell = 316773, warhorn = 316723, raid = 8959, alarm = 12889, whisper = 37666 },
	FALL = 23287,
	NO_SOUND = "Trackers: the game played no sound, so proc alerts are silent.",
	COUNT = { SPELL_ACTIVATION_OVERLAY_SHOW = "show", SPELL_ACTIVATION_OVERLAY_HIDE = "hide", SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = "glowShow",
		SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = "glowHide" },
	USAGE = "Usage: /flatui tracker proc colour 1 ffd100, proc time 1 10 or proc trigger 1 aura.",
	-- AUTO_KINDS: the kinds of the class data that are automatic when a row does not say. AUTO_LINE: the lines of Remove a proc for the automatic
	-- procs start above it, clear of the numbers of the list of trackers.
	AUTO_KINDS = { proc = true, reactive = true }, AUTO_LINE = 1000,
}
-- The automatic procs: the list built last, every entry ever built by its id, and whether the list is built again when next asked.
local A = { list = {}, byId = {}, stale = true }
-- What is known of each proc, by the id of its entry: the entry while its alert is up, the moment the alert started, the overlay signal and the
-- glow signal, an alert ended by a cast or by its time until the buff is gone, the last sound in words and the moment the alert last ended
-- (stopped). seen counts the events heard. triggers are the ways a proc is known to be up, by name.
local P = { up = {}, since = {}, signalled = {}, glow = {}, ended = {}, played = {}, stopped = {}, triggers = {},
	seen = { show = 0, hide = 0, glowShow = 0, glowHide = 0 } }

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

-- The first answer of a game call, or nil when the call is missing, fails or is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

local function Call(fn, ...)
	if type(fn) == "function" then
		ns.EachPart(KEY, PART, fn, ...)
	end
end

-- The same IDs in the same order.
local function Same(old, new)
	if type(old) ~= "table" or #old ~= #new then
		return false
	end
	for index, value in ipairs(new) do
		if old[index] ~= value then
			return false
		end
	end
	return true
end

local function Lists(list, id)
	for _, value in ipairs(type(list) == "table" and list or {}) do
		if value == id then
			return true
		end
	end
	return false
end

-- The proc trackers, in list order, with their numbers in the list of trackers: { number, entry }.
local function Procs()
	local found = {}
	for number, entry in ipairs(ns.TrackerEntries()) do
		if entry.kind == "proc" then
			found[#found + 1] = { number, entry }
		end
	end
	return found
end

-- Every proc that is watched: the proc trackers in list order, then the automatic ones (ns.ProcAutoEntries, below).
local function All()
	local found, saved = {}, ns.TrackerEntries()
	for _, entry in ipairs(saved) do
		if entry.kind == "proc" then
			found[#found + 1] = entry
		end
	end
	for _, entry in ipairs(type(ns.ProcAutoEntries) == "function" and ns.ProcAutoEntries(saved) or {}) do
		found[#found + 1] = entry
	end
	return found
end
ns.ProcEntries = All

-- The class data ------------------------------------------------------------------------------------------------------------------

local function ProcList()
	local ok, _, class = pcall(UnitClass, "player")
	if not ok or IsSecret(class) or type(class) ~= "string" then
		return {}
	end
	local data = type(ns.ProcData) == "table" and ns.ProcData[class]
	return type(data) == "table" and data or {}
end

-- The class data row of a proc tracker, by the IDs of its buff; a row with no buff (Execute) by its name, for an entry with no buff either.
local function RowOf(entry)
	local list = ProcList()
	for _, row in ipairs(list) do
		for _, id in ipairs(row.buffs) do
			if Lists(entry.spells, id) then
				return row
			end
		end
	end
	if type(entry.spells) == "table" and #entry.spells == 0 then
		for _, row in ipairs(list) do
			if #row.buffs == 0 and row.name == entry.name then
				return row
			end
		end
	end
	return nil
end

-- The names of the procs of the class turned off on this character, as a set (FlatUICharDB.procsOff), made when make is set.
local function OffSet(make)
	local saved = ns.Character()
	if type(saved) ~= "table" then
		return {}
	end
	if type(saved.procsOff) ~= "table" then
		if not make then
			return {}
		end
		saved.procsOff = {}
	end
	return saved.procsOff
end

-- True for a proc of your class that is turned off, or for all of them while Procs of your class is off. Until the next layout takes it away
-- (after the fight, in one) it is read as down, so its icon, art and glow go at once.
local function Off(entry)
	return entry.auto == true and (ns.Get(KEY .. ".procAuto") == false or OffSet(false)[entry.name] == true)
end

-- A spell of the player's, or true when the game cannot say.
local function Known(spellID)
	local book = C_SpellBook
	if type(book) == "table" then
		for _, call in ipairs({ "IsSpellKnownOrInSpellBook", "IsSpellKnown" }) do
			local known = Ask(book[call], spellID)
			if type(known) == "boolean" then
				return known
			end
		end
	end
	return true
end

-- The colour of an entry as red, green and blue: its own, else the page's, else ffd100.
local function Rgb(hex)
	if Plain(hex, "string") and #hex == 8 and hex:find("^%x+$") then
		return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
	end
	return nil
end

function ns.ProcColour(entry)
	local r, g, b = Rgb(type(entry) == "table" and entry.colour or nil)
	if r then
		return r, g, b
	end
	r, g, b = Rgb(ns.Get(KEY .. ".procColour"))
	if r then
		return r, g, b
	end
	return 1, 0.82, 0
end

-- The sound kit of an alert: the entry's own (false is none), else the page's Sound.
local function KitOf(entry)
	local own = entry.sound
	if own == false then
		return nil
	elseif Plain(own, "number") then
		return own
	end
	return K.KITS[ns.Get(KEY .. ".procSound")]
end

-- The art of an alert: the payload of the game's overlay when it came, else the art of the class data with its place, size, opacity, colour,
-- turn, pulse and time, else nothing (the plain arc). False for a proc of the class data that has no art, only the glow (noArt).
local function ArtData(entry)
	local signal = P.signalled[entry.id]
	if signal then
		return { file = signal.file, location = signal.location, scale = signal.scale or 1, r = signal.r, g = signal.g, b = signal.b }
	end
	local row = RowOf(entry)
	if row and row.noArt == true then
		return false
	end
	local art = row and row.art
	if type(art) == "table" then
		return { file = art.file, location = art.location, scale = art.scale or 1, alpha = art.alpha, r = art.r, g = art.g, b = art.b,
			turn = art.turn, pulse = art.pulse, seconds = art.seconds }
	end
	return nil
end

-- Shows the art of a proc that is up, unless it has none. again: at once, with no fade-in (Start).
local function ShowArt(entry, again)
	local art = ArtData(entry)
	if art ~= false then
		Call(ns.ProcArtShow, entry, art, again)
	end
end

-- The art of the alert as ProcArt.lua draws it, for the pieces it makes on the game's own icon.
ns.ProcArtData = ArtData

-- The game's own icon of a proc carries the art too (TrackerSlots.lua runs this while it builds the slot). ProcArt.lua is loaded after this file,
-- so the function is looked up when the slot is built.
if type(ns.TrackerSlotParts) == "table" then
	ns.TrackerSlotParts.proc = function(...)
		local make = ns.ProcArtParts
		if type(make) ~= "function" then
			error("no art to draw", 0)
		end
		return make(...)
	end
end

-- Starting and ending an alert -----------------------------------------------------------------------------------------------------

-- The sound once. A refused kit is tried as the sound of the game's own overlay; a refusal of both is one note. The word goes to the check.
local function Sound(entry, always)
	local kit = KitOf(entry)
	if not kit then
		P.played[entry.id] = "none"
		return "none"
	end
	if not always and ns.TrackerQuiet() then
		return nil
	end
	local word = ns.TrackerPlay(kit, K.FALL, K.NO_SOUND) and "played" or "failed"
	P.played[entry.id] = word
	return word
end

-- An alert starts: the sound once, the art and the glow. A proc that starts again within K.AGAIN seconds of the end of its alert, or while it is
-- up, is the same alert going on (Overpower after each dodge, Revenge, Execute as rage refills): no sound, the art is there at
-- once with no fade-in, and the glow carries on without its burst.
local function Start(entry)
	local id, now = entry.id, Now()
	local ended = P.stopped[id]
	local again = P.up[id] ~= nil or (ended ~= nil and now >= ended and now - ended <= K.AGAIN)
	P.up[id], P.since[id] = entry, now
	if not again then
		Sound(entry, false)
	end
	ShowArt(entry, again)
	Call(ns.ProcGlowStart, entry, again)
end

local function Stop(entry)
	P.up[entry.id] = nil
	P.stopped[entry.id] = Now()
	Call(ns.ProcArtHide, entry)
	Call(ns.ProcGlowStop, entry)
end

-- The proc is no longer a tracker that is on: removed, switched off, or the page off. A trigger with a Forget(id) forgets it too, so a proc
-- that comes back (Bring back a proc, Procs of your class on again) is not up from an answer of before.
local function Gone(id)
	local entry = P.up[id]
	if entry then
		Stop(entry)
	end
	P.since[id], P.signalled[id], P.glow[id], P.ended[id], P.stopped[id] = nil, nil, nil, nil, nil
	for _, def in pairs(P.triggers) do
		if type(def.Forget) == "function" then
			pcall(def.Forget, id)
		end
	end
end

-- Called when the state the proc shows changes: fine is up, missing is down. low is fine.
local function Changed(entry, before, after)
	local was = before == "fine" or before == "low"
	local now = after == "fine" or after == "low"
	if now and not was then
		Start(entry)
	elseif was and not now then
		Stop(entry)
	end
end

-- Reading ----------------------------------------------------------------------------------------------------------------------------

local function Number(value)
	return Plain(value, "number") and value or 0
end

-- The overlay trigger: the proc is up while the game's overlay or glow says so and its time is not out. Before the game has sent any
-- event this session the proc is not known; after, with no signal, it is not up.
local function OverlayRead(entry)
	local id = entry.id
	local signal, glow = P.signalled[id], P.glow[id]
	if signal or glow then
		local time = Number(entry.time)
		if time <= 0 then
			return nil
		end
		local started = signal and signal.since or glow
		return { state = "fine", hidden = false, expires = started + time, length = time }
	end
	if P.seen.show + P.seen.hide + P.seen.glowShow + P.seen.glowHide > 0 then
		return { state = "missing", hidden = false }
	end
	return nil
end

-- True for a proc known by its trigger alone: an ability the class data watches by its use (watch usable: Overpower, Revenge, Execute) with the
-- trigger usable, and a proc with no buff. The buff a row names may not be the one that comes and goes (Overpower's, 1289681, is named
-- Bloodthrill like the talent), and a proc with no buff (Execute) has none to look for by name, where an aura of the same name (the one Execute
-- leaves on you for a second after each cast) would be taken for it.
local function ByUse(entry, row)
	row = row or RowOf(entry)
	return row ~= nil and ((row.watch == "usable" and entry.trigger == "usable") or #row.buffs == 0)
end

-- The reading of the buff, else the reading of the entry's trigger when the buff is hidden. A trigger that says Either (usable) is asked also
-- while the buff can be read and is missing: an ability the game makes usable without the buff is up. A proc known by its trigger alone (ByUse)
-- has the trigger's reading, and is down until its first answer.
local function Raw(entry)
	local trigger = P.triggers[entry.trigger]
	if ByUse(entry) then
		if trigger and type(trigger.Read) == "function" then
			local ok, got = pcall(trigger.Read, entry)
			if ok and type(got) == "table" and type(got.state) == "string" then
				return got
			end
		end
		return { state = "missing", hidden = false }
	end
	local reading = ns.AuraReading(entry)
	if reading.state == "fine" or reading.state == "low" then
		return reading
	end
	if not (trigger and type(trigger.Read) == "function") or (reading.state ~= "unknown" and trigger.Either ~= true) then
		return reading
	end
	local ok, got = pcall(trigger.Read, entry)
	if ok and type(got) == "table" and type(got.state) == "string" and (reading.state == "unknown" or got.state == "fine" or got.state == "low") then
		return got
	end
	return reading
end

local function Read(entry)
	local id, now = entry.id, Now()
	if Off(entry) then
		P.ended[id], P.since[id] = nil, nil
		return { state = "missing", hidden = false }
	end
	local reading = Raw(entry)
	if reading.state == "low" then
		reading.state = "fine"
	end
	if reading.state == "fine" then
		local time = Number(entry.time)
		if P.ended[id] then
			return { state = "missing", hidden = false, icon = reading.icon }
		end
		P.since[id] = P.since[id] or now
		if time > 0 then
			local ends = P.since[id] + time
			if now >= ends then
				P.ended[id] = true
				return { state = "missing", hidden = false, icon = reading.icon }
			end
			if reading.expires == nil or ends < reading.expires then
				reading.expires, reading.length = ends, time
			end
			ns.TrackerWake(entry, ends)
		end
	elseif reading.state == "missing" then
		P.ended[id], P.since[id] = nil, nil
	end
	return reading
end

-- Nothing is drawn while the proc is down, or when the game's own icon draws it.
local function Hide(_, reading, how)
	return how == "none" or how == "game" or (how == "live" and reading.state == "missing")
end

local function Wanted(entry, state, how)
	if not (how == "game" or state == "fine" or state == "low") then
		return 0
	end
	return 1
end

-- The spell a proc is for is cast: the alert ends, and starts again with the next proc. One that stays (Execute) lasts while it is usable.
-- A trigger with a Used(entry) hears it, so the next proc starts an alert even within the time of this one (usable: a second dodge).
local function Cast(spellID)
	for _, entry in ipairs(All()) do
		if Lists(entry.lights, spellID) and (P.up[entry.id] or P.signalled[entry.id] or P.glow[entry.id]) then
			local row = RowOf(entry)
			if not (row and row.stay == true) then
				P.ended[entry.id], P.signalled[entry.id], P.glow[entry.id] = true, nil, nil
				local trigger = P.triggers[entry.trigger]
				if trigger and type(trigger.Used) == "function" then
					pcall(trigger.Used, entry)
				end
				ns.TrackerDirty()
			end
		end
	end
end

-- The game's overlay ---------------------------------------------------------------------------------------------------------------

-- The name of a screen location the game gave as a number.
local function Place(number)
	local names = type(Enum) == "table" and type(Enum.ScreenLocationType) == "table" and Enum.ScreenLocationType
	if names and Plain(number, "number") then
		for name, value in pairs(names) do
			if value == number then
				return name
			end
		end
	end
	return nil
end

-- At login and when the spells change (World): a spell the game says is overlaid counts as a glow.
local function Overlayed()
	local call = type(C_SpellActivationOverlay) == "table" and C_SpellActivationOverlay.IsSpellOverlayed
	if type(call) ~= "function" then
		return
	end
	for _, entry in ipairs(All()) do
		for _, id in ipairs(entry.lights or {}) do
			if Ask(call, id) == true then
				P.glow[entry.id] = P.glow[entry.id] or Now()
				break
			end
		end
	end
end

local function Event(event, ...)
	local counter = K.COUNT[event]
	if counter then
		P.seen[counter] = P.seen[counter] + 1
	end
	local spellID, file, place, scale, r, g, b = ...
	if IsSecret(spellID) then
		return
	end
	for _, entry in ipairs(All()) do
		local id = entry.id
		if event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
			if Whole(spellID) and Lists(entry.spells, spellID) then
				P.signalled[id] = { since = Now(), file = Plain(file, "number") and file or nil, location = Place(place),
					scale = Plain(scale, "number") and scale or nil, r = Plain(r, "number") and r or nil, g = Plain(g, "number") and g or nil,
					b = Plain(b, "number") and b or nil }
			end
		elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
			if spellID == nil or Lists(entry.spells, spellID) then
				P.signalled[id] = nil
			end
		elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
			if Whole(spellID) and Lists(entry.lights, spellID) then
				P.glow[id] = Now()
			end
		elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
			if Whole(spellID) and Lists(entry.lights, spellID) then
				P.glow[id] = nil
			end
		end
	end
end

-- Tells the entry's trigger that the entry is there, for a trigger that listens for events of its own: def.Seen(entry).
local function Touch(entry)
	local trigger = P.triggers[entry.trigger]
	if trigger and type(trigger.Seen) == "function" then
		pcall(trigger.Seen, entry)
	end
end

-- Cleaning --------------------------------------------------------------------------------------------------------------------------

-- True when the entry is a proc: a buff by spells and names, the spells it is for, how it is known, its time. A value that is not valid is
-- taken away; an entry with no buff is dropped.
local function Clean(entry)
	if not ns.TrackerCleanBuff(entry, nil, "proc") then
		return false
	end
	local lights, seen = {}, {}
	for _, id in ipairs(type(entry.lights) == "table" and entry.lights or {}) do
		if Whole(id) and not seen[id] and #lights < K.MAX_SPELLS then
			seen[id] = true
			lights[#lights + 1] = id
		end
	end
	if not Same(entry.lights, lights) then
		entry.lights = lights
	end
	if not P.triggers[entry.trigger] then
		entry.trigger = "aura"
	end
	if entry.kind2 ~= "shorter" then
		entry.kind2 = nil
	end
	Touch(entry)
	if not (Plain(entry.time, "number") and entry.time >= 0 and entry.time <= K.MAX_TIME) then
		entry.time = nil
	end
	return true
end

-- Adding -----------------------------------------------------------------------------------------------------------------------------

local function Tracked(entries, name, buffs)
	for _, entry in ipairs(entries) do
		if entry.kind == "proc" then
			if entry.name == name then
				return true
			end
			for _, id in ipairs(buffs) do
				if Lists(entry.spells, id) then
					return true
				end
			end
		end
	end
	return false
end

-- The fields of a new proc: its buff, the spells it is for, the icon size and Show Always, since a proc that is down is not on screen.
local function Fields(name, buffs, lights, seconds, trigger, kind2)
	local time = Plain(seconds, "number") and seconds > 0 and seconds <= K.MAX_TIME and seconds or nil
	return { name = name, names = { name }, spells = buffs, lights = lights, trigger = P.triggers[trigger] and trigger or "aura", kind2 = kind2 == "shorter" and kind2 or nil,
		time = time, size = K.SIZE, show = "always" }
end

-- The message of a trigger that does not fit the entry, or nil when it fits.
local function Refused(entry)
	local trigger = P.triggers[entry.trigger]
	if trigger and type(trigger.Valid) == "function" then
		local ok, valid, message = pcall(trigger.Valid, entry)
		if ok and not IsSecret(valid) and valid == false then
			return Plain(message, "string") and message or ("%s does not fit this proc."):format(entry.trigger)
		end
	end
	return nil
end

-- The IDs of the spells a proc is for that the player knows, at most 40; the first 40 when none is known.
local function KnownLights(lights)
	local own = {}
	for _, id in ipairs(lights) do
		if Known(id) and #own < K.MAX_SPELLS then
			own[#own + 1] = id
		end
	end
	if #own == 0 then
		for _, id in ipairs(lights) do
			if #own < K.MAX_SPELLS then
				own[#own + 1] = id
			end
		end
	end
	return own
end

-- add proc <buff> [for <spell>]: the buff by name or ID, and the spell it is for by name or ID with every rank in the spell book. A table is
-- a row of the class data picked on the page.
local function Add(argument, entries)
	if type(argument) == "table" and type(argument.row) == "table" then
		local row = argument.row
		if Tracked(entries, row.name, row.buffs) then
			return nil, "Already tracked."
		end
		local buffs = {}
		for _, id in ipairs(row.buffs) do
			buffs[#buffs + 1] = id
		end
		local fields = Fields(row.name, buffs, KnownLights(row.lights), row.seconds, row.trigger, row.kind2)
		local why = Refused(fields)
		if why then
			return nil, why
		end
		return fields, ("Added %s."):format(row.name)
	end
	local text = Plain(argument, "string") and argument:match("^%s*(.-)%s*$") or ""
	if text == "" then
		return nil, "Which proc? For example: /flatui tracker add proc Shadow Trance for Shadow Bolt"
	end
	local first, second = text:match("^(.-)%s+[Ff][Oo][Rr]%s+(.+)$")
	first = first or text
	local buff = ns.TrackerResolve(first)
	if not buff then
		return nil, ('No spell found for "%s".'):format(first)
	end
	local lights = {}
	if second then
		local spell = ns.TrackerResolve(second)
		if not spell then
			return nil, ('No spell found for "%s".'):format(second)
		end
		lights = ns.TrackerRankIDs(spell)
	end
	local name = Ask(C_Spell and C_Spell.GetSpellName, buff)
	if not Plain(name, "string") or name == "" then
		return nil, ('No spell found for "%s".'):format(first)
	end
	if Tracked(entries, name, { buff }) then
		return nil, "Already tracked."
	end
	return Fields(name, { buff }, lights, nil), ("Added %s."):format(name)
end

-- The procs of the class that the player can use and that are not tracked, by name: { number in the class list, name }.
function ns.ProcCandidates()
	local rows, entries = {}, ns.TrackerEntries()
	for number, row in ipairs(ProcList()) do
		local known = false
		for _, id in ipairs(row.lights) do
			if Known(id) then
				known = true
				break
			end
		end
		if known and not Tracked(entries, row.name, row.buffs) then
			local trigger = P.triggers[row.trigger]
			local text = trigger and Plain(trigger.Text, "string") and trigger.Text or ""
			rows[#rows + 1] = { number, text == "" and row.name or (row.name .. ", " .. text), row.name }
		end
	end
	table.sort(rows, function(left, right)
		local a, b = left[3]:lower(), right[3]:lower()
		if a ~= b then
			return a < b
		end
		return left[1] < right[1]
	end)
	return rows
end

function ns.ProcAdd(number)
	local row = Whole(number) and ProcList()[number]
	if not row then
		return false, "Not added."
	end
	return ns.TrackerAddKind("proc", { row = row })
end

-- Procs of your class ----------------------------------------------------------------------------------------------------------------

-- True when a row of the class data shows without being added: its own auto, else its kind.
local function Automatic(row)
	if row.auto ~= nil then
		return row.auto == true
	end
	return K.AUTO_KINDS[row.kind] == true
end

-- The IDs of a row's spells that the player knows, or nil when none is. Not saved, so not held to the 40 of an entry of the list: every spell
-- that uses Clearcasting ends its alert.
local function Ranks(lights)
	local own = {}
	for _, id in ipairs(lights) do
		if Known(id) then
			own[#own + 1] = id
		end
	end
	return #own > 0 and own or nil
end

-- Builds the automatic procs again: each automatic row of the class with a spell the player knows that is not turned off, while Procs of your
-- class is on. An entry keeps its table: its buffs follow the row (an ID the trackers found by name since stays), its lights the ranks known
-- now, so a rank learned later is in them, and its trigger, time and glow the row. A trigger that does not fit (Valid) leaves the buff alone.
local function Build()
	A.stale = false
	local list = {}
	if ns.Get(KEY .. ".procAuto") ~= false then
		local off = OffSet(false)
		for _, row in ipairs(ProcList()) do
			local lights = Automatic(row) and off[row.name] ~= true and type(row.lights) == "table" and Ranks(row.lights)
			if lights then
				local id = "auto:" .. row.name
				local entry = A.byId[id]
				if not entry then
					entry = { id = id, kind = "proc", auto = true, name = row.name, names = { row.name }, spells = {}, lights = {}, show = "always" }
					A.byId[id] = entry
				end
				for _, buff in ipairs(row.buffs) do
					if not Lists(entry.spells, buff) and #entry.spells < K.MAX_SPELLS then
						entry.spells[#entry.spells + 1] = buff
					end
				end
				if not Same(entry.lights, lights) then
					entry.lights = lights
				end
				entry.trigger = P.triggers[row.trigger] and row.trigger or "aura"
				entry.kind2 = row.kind2 == "shorter" and "shorter" or nil
				entry.time = Plain(row.seconds, "number") and row.seconds > 0 and row.seconds <= K.MAX_TIME and row.seconds or nil
				-- An if, since an and/or that ends in false or nil always gives nil.
				if row.glow == false then
					entry.glow = false
				else
					entry.glow = nil
				end
				if Refused(entry) then
					entry.trigger = "aura"
				end
				Touch(entry)
				list[#list + 1] = entry
			end
		end
	end
	A.list = list
end

-- The ids of the automatic procs built, as one text.
local function Ids()
	local ids = {}
	for index, entry in ipairs(A.list) do
		ids[index] = entry.id
	end
	return table.concat(ids, "|")
end

-- The automatic procs that no proc of the list tracks (by name or buff), in the order of the class data. saved: the list of trackers, when the
-- caller has it. The list is built again first when something it depends on changed.
function ns.ProcAutoEntries(saved)
	if A.stale then
		Build()
	end
	-- Procs of your class or one of them turned off in a fight: the list stays as it is until the layout after the fight builds it again, and
	-- each one that is off reads as down from now on (Off), so nothing of it is left on screen.
	if #A.list == 0 then
		return {}
	end
	saved = type(saved) == "table" and saved or ns.TrackerEntries()
	local out = {}
	for _, entry in ipairs(A.list) do
		if not Tracked(saved, entry.name, entry.spells) then
			out[#out + 1] = entry
		end
	end
	return out
end

-- Builds the automatic procs again (Trackers.lua runs it at each layout, out of combat), and has the glow frames of their buttons made ahead.
function ns.ProcAutoBuild()
	Build()
	Call(ns.ProcGlowPrepare, All())
end

-- At login and when the spells change: the overlay is asked, and the automatic procs are built again, with a new layout when they changed.
local function World()
	Overlayed()
	local before = Ids()
	Build()
	if Ids() ~= before then
		ns.TrackerLayout()
	end
end

-- The place in the class data of the row with this name, and the row.
local function Line(name)
	for number, row in ipairs(ProcList()) do
		if row.name == name then
			return number, row
		end
	end
	return nil
end

-- The proc trackers by their number in the list of trackers, then the automatic procs by their place in the class data above AUTO_LINE.
function ns.ProcPicked()
	local rows = {}
	for _, found in ipairs(Procs()) do
		rows[#rows + 1] = { found[1], ns.TrackerLabel(found[2]) }
	end
	for _, entry in ipairs(ns.ProcAutoEntries()) do
		local number = not Off(entry) and Line(entry.name)
		if number then
			rows[#rows + 1] = { K.AUTO_LINE + number, ("%s, of your class"):format(entry.name) }
		end
	end
	return rows
end

-- Removes a proc tracker, or turns an automatic proc off for this character. A proc of the class removed from the list is turned off too, so it
-- does not come back on its own; Bring back a proc turns it on again.
function ns.ProcRemove(position)
	if Whole(position) and position > K.AUTO_LINE then
		local row = ProcList()[position - K.AUTO_LINE]
		if not row then
			return false, ("No proc numbered %s."):format(tostring(position))
		end
		OffSet(true)[row.name] = true
		-- An alert that is up ends now, even in a fight, where it reads as down (Off) until the layout after the fight builds the list again
		-- and frees its icon; out of a fight that layout is now.
		Gone("auto:" .. row.name)
		ns.TrackerDirty()
		ns.TrackerLayout()
		return true, ("%s is off for this character. Bring back a proc turns it on again."):format(row.name)
	end
	for _, found in ipairs(Procs()) do
		if found[1] == position then
			local row = RowOf(found[2])
			local kept = row and Automatic(row) and ns.Get(KEY .. ".procAuto") ~= false
			if kept then
				OffSet(true)[row.name] = true
				A.stale = true
			end
			local done, message = ns.TrackerRemove(position)
			if not done and kept then
				OffSet(false)[row.name] = nil
				A.stale = true
			elseif kept then
				message = ("%s It stays off for this character until Bring back a proc."):format(tostring(message))
			end
			return done, message
		end
	end
	return false, ("No proc numbered %s."):format(tostring(position))
end

-- The procs of the class turned off on this character, by their place in the class data: the lines of Bring back a proc.
function ns.ProcTurnedOff()
	local rows, off = {}, OffSet(false)
	for number, row in ipairs(ProcList()) do
		if off[row.name] == true then
			rows[#rows + 1] = { number, row.name }
		end
	end
	return rows
end

function ns.ProcRestore(number)
	local row = Whole(number) and ProcList()[number]
	local off = OffSet(false)
	if not (row and off[row.name] == true) then
		return false, "That proc is not turned off."
	end
	off[row.name] = nil
	A.stale = true
	ns.TrackerLayout()
	if ns.Get(KEY .. ".procAuto") == false then
		return true, ("%s is on again once Procs of your class is on."):format(row.name)
	end
	return true, ("%s is on again."):format(row.name)
end

-- Triggers ---------------------------------------------------------------------------------------------------------------------------

-- Registers a way a proc is known to be up: def.Read(entry) gives a reading or nothing, def.Text the words after the proc's name where it is
-- listed, def.Lines(entry) the lines of the check and def.Valid(entry) true or false and a message, asked when a trigger is chosen. def.Either
-- true: Read is asked also while the buff can be read and is missing (Raw). def.Used(entry): the spell the proc is for was cast and ended the alert.
-- def.Forget(id): the proc is no longer on (Gone).
function ns.ProcTrigger(name, def)
	if type(name) ~= "string" or name == "" or type(def) ~= "table" then
		return false
	end
	P.triggers[name] = def
	return true
end

ns.ProcTrigger("aura", { Text = "", Lines = function() return {} end })
ns.ProcTrigger("overlay", { Text = "the game's overlay", Read = OverlayRead,
	Lines = function(entry)
		local seconds = Number(entry.time)
		return { seconds > 0 and ("Time: %s seconds."):format(tostring(seconds)) or "Time: none, so an overlay signal is not shown." }
	end })

-- The check -----------------------------------------------------------------------------------------------------------------------------

-- How hidden the game keeps the buff: every ID must agree.
local function Level(entry)
	local call = type(C_Secrets) == "table" and C_Secrets.GetSpellAuraSecrecy
	local levels = type(Enum) == "table" and Enum.SecrecyLevel
	if type(call) ~= "function" or type(levels) ~= "table" or #entry.spells == 0 then
		return "not known"
	end
	local found
	for _, id in ipairs(entry.spells) do
		local ok, level = pcall(call, id)
		if not ok or IsSecret(level) then
			return "not known"
		end
		local word
		if level == levels.NeverSecret then
			word = "never hidden"
		elseif level == levels.ContextuallySecret then
			word = "hidden in fights"
		elseif level == levels.AlwaysSecret then
			word = "always hidden"
		else
			return "not known"
		end
		if found and found ~= word then
			return "mixed"
		end
		found = word
	end
	return found
end

local function UpNow(entry)
	local state = Raw(entry).state
	if state == "fine" or state == "low" then
		return P.ended[entry.id] and "no" or "yes"
	elseif state == "missing" then
		return "no"
	end
	return "not known"
end

local function Display()
	local rules = type(C_GameRules) == "table" and C_GameRules.IsPersonalResourceDisplayEnabled
	local answer = Ask(rules)
	if type(answer) == "boolean" then
		return answer and "yes" or "no"
	end
	return "not known"
end

local function Lines(entry)
	local chosen = P.triggers[entry.trigger]
	local label = chosen and Plain(chosen.Label, "string") and chosen.Label or entry.trigger or "aura"
	local lines = { ("Trigger: %s."):format(label) }
	if entry.auto == true then
		lines[#lines + 1] = "Procs of your class: shown without being added. Remove a proc turns it off."
	end
	local level = Level(entry)
	lines[#lines + 1] = "Aura level: " .. level .. "."
	if ByUse(entry) then
		lines[#lines + 1] = "Known by its trigger alone, in fights too."
	elseif level ~= "never hidden" then
		lines[#lines + 1] = "Sound in fights: none while the game hides the buff."
	end
	lines[#lines + 1] = "Up now: " .. UpNow(entry) .. "."
	local seen = P.seen
	lines[#lines + 1] = ("Game signal: seen %d times this session (show %d, hide %d, glow %d)."):format(seen.show + seen.hide + seen.glowShow + seen.glowHide,
		seen.show, seen.hide, seen.glowShow + seen.glowHide)
	lines[#lines + 1] = rawget(_G, "SpellActivationOverlayFrame") == nil and "Overlay frame: the game has none." or "Overlay frame: exists."
	lines[#lines + 1] = "Personal resource display: enabled " .. Display() .. "."
	local played = P.played[entry.id]
	if KitOf(entry) == nil then
		lines[#lines + 1] = "Sound: none."
	else
		lines[#lines + 1] = played and ("Sound: %s."):format(played) or "Sound: not played yet."
	end
	local trigger = P.triggers[entry.trigger]
	if trigger and type(trigger.Lines) == "function" then
		local ok, extra = pcall(trigger.Lines, entry)
		for _, line in ipairs(ok and type(extra) == "table" and extra or {}) do
			lines[#lines + 1] = tostring(line)
		end
	end
	for _, name in ipairs({ "ProcArtLine", "ProcGlowLine" }) do
		local fn = ns[name]
		if type(fn) == "function" then
			local ok, line = pcall(fn, entry)
			if ok and Plain(line, "string") and line ~= "" then
				lines[#lines + 1] = line
			end
		end
	end
	return lines
end

-- The test: the icon is in the row, the sound plays once, and the art and glow start. Test(entry, false) ends them.
local function Test(entry, on)
	P.before = P.before or {}
	if not on then
		Stop(entry)
		-- An alert that was up before the test carries on.
		if P.before[entry.id] then
			P.before[entry.id] = nil
			P.up[entry.id] = entry
			ShowArt(entry, true)
			Call(ns.ProcGlowStart, entry, true)
		end
		return nil
	end
	if P.before[entry.id] == nil then
		P.before[entry.id] = P.up[entry.id] ~= nil
	end
	P.up[entry.id] = entry
	local word = Sound(entry, true)
	ShowArt(entry)
	Call(ns.ProcGlowStart, entry)
	return ("Sound: %s."):format(word or "none")
end

-- Commands ---------------------------------------------------------------------------------------------------------------------------

-- A proc by its number in the list of trackers or by its name.
local function Find(text)
	local wanted = text:lower()
	for _, found in ipairs(Procs()) do
		local entry = found[2]
		if text:find("^%d+$") then
			if found[1] == tonumber(text) then
				return entry, found[1]
			end
		elseif ns.TrackerLabel(entry):lower() == wanted then
			return entry, found[1]
		end
	end
	return nil
end

local function Word(text)
	local word, proc, value = text:match("^(%S+)%s+(%S+)%s*(.-)$")
	if not word then
		return K.USAGE
	end
	word = word:lower()
	local entry, number = Find(proc)
	if not entry then
		return ('No proc found for "%s".'):format(proc)
	end
	if word == "colour" then
		local hex = value:lower():gsub("^#", "")
		if #hex == 6 then
			hex = "ff" .. hex
		end
		if not (#hex == 8 and hex:find("^%x+$")) then
			return ("Proc %d: %s is not a colour. Six or eight digits, such as ffd100."):format(number, value)
		end
		entry.colour = hex
		ns.TrackerDirty()
		return ("Proc %d: colour is %s."):format(number, hex:sub(3))
	elseif word == "time" then
		local seconds = tonumber(value)
		if not (seconds and seconds >= 0 and seconds <= K.MAX_TIME) then
			return ("Proc %d: time is 0 to %d seconds."):format(number, K.MAX_TIME)
		end
		entry.time = seconds
		ns.TrackerDirty()
		return seconds == 0 and ("Proc %d: no time limit."):format(number) or ("Proc %d: time is %s seconds."):format(number, tostring(seconds))
	elseif word == "trigger" then
		local def = P.triggers[value:lower()]
		if not def then
			return ('Proc %d: "%s" is not a trigger.'):format(number, value)
		end
		local was = entry.trigger
		entry.trigger = value:lower()
		local why = Refused(entry)
		if why then
			entry.trigger = was
			return why
		end
		Touch(entry)
		ns.TrackerDirty()
		return ("Proc %d: trigger is %s."):format(number, entry.trigger)
	end
	return K.USAGE
end

ns.TrackerWord("proc", function(text)
	local ok, line = pcall(Word, text)
	return ok and line or K.USAGE
end)

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("proc", {
		Read = Read, Clean = Clean, Add = Add, Lines = Lines, Hide = Hide, Wanted = Wanted, Changed = Changed, Gone = Gone, Cast = Cast, Event = Event,
		Test = Test, Rim = ns.ProcColour, World = World, Label = function(entry) return entry.name end,
		-- A proc with no buff (Execute) has the icon of the spell it is for.
		Icon = function(entry)
			local light = type(entry.lights) == "table" and entry.lights[1]
			local file = Whole(light) and Ask(C_Spell and C_Spell.GetSpellTexture, light)
			return (Plain(file, "number") or Plain(file, "string")) and file or nil
		end,
		events = { "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
			"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" },
		own = {
			sound = function(value)
				if value == false then
					return true
				end
				for _, kit in pairs(K.KITS) do
					if value == kit then
						return true
					end
				end
				return false
			end,
			size = function(value)
				return Plain(value, "number") and value >= 24 and value <= 64 and value % 2 == 0
			end,
		},
		what = "proc alert", part = PART, noLast = true, noDrop = true, last = true,
		slot = { unit = "player", filter = "HELPFUL" },
	})
end
