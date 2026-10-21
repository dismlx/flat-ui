local _, ns = ...

-- Proc alerts: the kind of tracker called proc. A proc shows nothing until the buff of the proc is up, then its icon with the time left, a
-- sound once, and it ends when the buff ends, when the spell it is for is cast or when its time is up. Where the game hides the buff in a
-- fight, the game's own icon for the buff (TrackerSlots.lua) shows the proc. The game's overlay events and IsSpellOverlayed are a second
-- way to know that a proc is up, for the trigger overlay: SpellActivationOverlay.lua loads only for the game types cata, mists and mainline
-- (Blizzard_FrameXML.toc:109-110), so on this client no event is expected, and the check says how many came. The art and the glow of a
-- proc are other files that provide ns.ProcArtShow, ns.ProcArtHide, ns.ProcGlowStart and ns.ProcGlowStop; each is called here only when it
-- is there. Every value from the game is tested with ns.IsSecret before it is compared, indexed or kept.

local KEY = "trackers"
local PART = "procs"
local IsSecret = ns.IsSecret

-- MAX_SPELLS, MAX_TIME, SIZE: the most spell IDs in a list of an entry, the most seconds of a proc's time and its icon size.
-- KITS: the sound choices of the page by their saved word, the sound kit each stands for. The first five are the kits of ns.SOUNDS in
--   IconRow.lua; alarm is ALARM_CLOCK_WARNING_3 and whisper UI_RAID_BOSS_WHISPER_WARNING (SoundKitConstants.lua:95, 136).
-- FALL: the kit the game's own overlay plays (SpellActivationOverlay.lua:134), tried when the game refuses a kit.
-- COUNT: the counter of each event of the game's overlay.
local K = {
	MAX_SPELLS = 40, MAX_TIME = 120, SIZE = 48, MAX_ID = 2147483647,
	KITS = { spell = 23287, chimes = 316736, bell = 316773, warhorn = 316723, raid = 8959, alarm = 12889, whisper = 37666 },
	FALL = 23287,
	NO_SOUND = "Trackers: the game played no sound, so proc alerts are silent.",
	COUNT = { SPELL_ACTIVATION_OVERLAY_SHOW = "show", SPELL_ACTIVATION_OVERLAY_HIDE = "hide", SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = "glowShow",
		SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = "glowHide" },
	USAGE = "Usage: /flatui tracker proc colour 1 ffd100, proc time 1 10 or proc trigger 1 aura.",
}
-- What is known of each proc, by the id of its entry: the entry while its alert is up, the moment the alert started, the overlay signal and the
-- glow signal, an alert ended by a cast or by its time until the buff is gone, and the last sound in words. seen counts the events heard.
-- triggers are the ways a proc is known to be up, by name.
local P = { up = {}, since = {}, signalled = {}, glow = {}, ended = {}, played = {}, triggers = {}, seen = { show = 0, hide = 0, glowShow = 0, glowHide = 0 } }

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

-- The class data ------------------------------------------------------------------------------------------------------------------

local function ProcList()
	local ok, _, class = pcall(UnitClass, "player")
	if not ok or IsSecret(class) or type(class) ~= "string" then
		return {}
	end
	local data = type(ns.ProcData) == "table" and ns.ProcData[class]
	return type(data) == "table" and data or {}
end

-- The class data row of a proc tracker, by the IDs of its buff.
local function RowOf(entry)
	for _, row in ipairs(ProcList()) do
		for _, id in ipairs(row.buffs) do
			if Lists(entry.spells, id) then
				return row
			end
		end
	end
	return nil
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

-- The art of an alert: the payload of the game's overlay when it came, else the art of the class data, else nothing.
local function ArtData(entry)
	local signal = P.signalled[entry.id]
	if signal then
		return { file = signal.file, location = signal.location, scale = signal.scale or 1, r = signal.r, g = signal.g, b = signal.b }
	end
	local row = RowOf(entry)
	if row and row.art then
		return { file = row.art.file, location = row.art.location, scale = 1 }
	end
	return nil
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

local function Start(entry)
	local id = entry.id
	P.up[id], P.since[id] = entry, Now()
	Sound(entry, false)
	Call(ns.ProcArtShow, entry, ArtData(entry))
	Call(ns.ProcGlowStart, entry)
end

local function Stop(entry)
	P.up[entry.id] = nil
	Call(ns.ProcArtHide, entry)
	Call(ns.ProcGlowStop, entry)
end

-- The proc is no longer a tracker that is on: removed, switched off, or the page off.
local function Gone(id)
	local entry = P.up[id]
	if entry then
		Stop(entry)
	end
	P.since[id], P.signalled[id], P.glow[id], P.ended[id] = nil, nil, nil, nil
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

-- The reading of the buff, else the reading of the entry's trigger when the buff is hidden.
local function Raw(entry)
	local reading = ns.AuraReading(entry)
	if reading.state == "unknown" then
		local trigger = P.triggers[entry.trigger]
		if trigger and type(trigger.Read) == "function" then
			local ok, got = pcall(trigger.Read, entry)
			if ok and type(got) == "table" and type(got.state) == "string" then
				reading = got
			end
		end
	end
	return reading
end

local function Read(entry)
	local id, now = entry.id, Now()
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

-- The spell a proc is for is cast: the alert ends, and starts again with the next proc.
local function Cast(spellID)
	for _, found in ipairs(Procs()) do
		local entry = found[2]
		if Lists(entry.lights, spellID) and (P.up[entry.id] or P.signalled[entry.id] or P.glow[entry.id]) then
			P.ended[entry.id], P.signalled[entry.id], P.glow[entry.id] = true, nil, nil
			ns.TrackerDirty()
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
	for _, found in ipairs(Procs()) do
		local entry = found[2]
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
	for _, found in ipairs(Procs()) do
		local entry = found[2]
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

-- The proc trackers by their number in the list of trackers.
function ns.ProcPicked()
	local rows = {}
	for _, found in ipairs(Procs()) do
		rows[#rows + 1] = { found[1], ns.TrackerLabel(found[2]) }
	end
	return rows
end

function ns.ProcRemove(position)
	for _, found in ipairs(Procs()) do
		if found[1] == position then
			return ns.TrackerRemove(position)
		end
	end
	return false, ("No proc numbered %s."):format(tostring(position))
end

-- Triggers ---------------------------------------------------------------------------------------------------------------------------

-- Registers a way a proc is known to be up: def.Read(entry) gives a reading or nothing, def.Text the words after the proc's name where it is
-- listed, def.Lines(entry) the lines of the check and def.Valid(entry) true or false and a message, asked when a trigger is chosen.
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
	local level = Level(entry)
	lines[#lines + 1] = "Aura level: " .. level .. "."
	if level ~= "never hidden" then
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
		if P.before[entry.id] then
			P.before[entry.id] = nil
			P.up[entry.id] = entry
			Call(ns.ProcArtShow, entry, ArtData(entry))
			Call(ns.ProcGlowStart, entry)
		end
		return nil
	end
	if P.before[entry.id] == nil then
		P.before[entry.id] = P.up[entry.id] ~= nil
	end
	P.up[entry.id] = entry
	local word = Sound(entry, true)
	Call(ns.ProcArtShow, entry, ArtData(entry))
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
		Test = Test, Rim = ns.ProcColour, World = Overlayed, Label = function(entry) return entry.name end,
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
