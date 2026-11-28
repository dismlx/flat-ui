local _, ns = ...

local KEY = "trackers"
local PART = "procs"
local IsSecret = ns.IsSecret

local K = {
	MAX_SPELLS = 40, MAX_TIME = 120, SIZE = 48, MAX_ID = 2147483647, AGAIN = 3,
	KITS = { spell = 23287, chimes = 316736, bell = 316773, warhorn = 316723, raid = 8959, alarm = 12889, whisper = 37666 },
	FALL = 23287,
	NO_SOUND = "Trackers: the game played no sound, so proc alerts are silent.",
	COUNT = { SPELL_ACTIVATION_OVERLAY_SHOW = "show", SPELL_ACTIVATION_OVERLAY_HIDE = "hide", SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = "glowShow",
		SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = "glowHide" },
	USAGE = "Usage: /flatui tracker proc colour 1 ffd100, proc sound 1 bell, proc time 1 10, proc trigger 1 aura or proc reset 1. A proc of your class goes by its name or its number in Remove a proc, as proc colour Execute ff3030.",
	AUTO_KINDS = { proc = true, reactive = true }, AUTO_LINE = 1000,
}
local A = { list = {}, byId = {}, stale = true }
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

local function Procs()
	local found = {}
	for number, entry in ipairs(ns.TrackerEntries()) do
		if entry.kind == "proc" then
			found[#found + 1] = { number, entry }
		end
	end
	return found
end

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

local function ProcList()
	local ok, _, class = pcall(UnitClass, "player")
	if not ok or IsSecret(class) or type(class) ~= "string" then
		return {}
	end
	local data = type(ns.ProcData) == "table" and ns.ProcData[class]
	return type(data) == "table" and data or {}
end

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

local function LookSet(make)
	local saved = ns.Character()
	if type(saved) ~= "table" then
		return {}
	end
	if type(saved.procLooks) ~= "table" then
		if not make then
			return {}
		end
		saved.procLooks = {}
	end
	return saved.procLooks
end

local function Off(entry)
	return entry.auto == true and (ns.Get(KEY .. ".procAuto") == false or OffSet(false)[entry.name] == true)
end

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

local function KitOf(entry)
	local own = entry.sound
	if own == false then
		return nil
	elseif Plain(own, "number") then
		return own
	end
	return K.KITS[ns.Get(KEY .. ".procSound")]
end

local function Most(row)
	local most = row and row.most
	return Whole(most) and most > 1 and most or nil
end

local function ArtData(entry)
	local signal = P.signalled[entry.id]
	local row = RowOf(entry)
	local own = row and type(row.art) == "table" and row.art.look or nil
	if signal then
		local tinted = type(own) == "table" and type(own.tint) == "table"
		return { file = signal.file, location = signal.location, scale = signal.scale or 1, r = not tinted and signal.r or nil,
			g = not tinted and signal.g or nil, b = not tinted and signal.b or nil, most = Most(row), look = own }
	end
	if row and row.noArt == true then
		return false
	end
	local art = row and row.art
	if type(art) == "table" then
		return { file = art.file, location = art.location, scale = art.scale or 1, alpha = art.alpha, r = art.r, g = art.g, b = art.b,
			turn = art.turn, pulse = art.pulse, seconds = art.seconds, most = Most(row), look = own }
	end
	return nil
end

local function ShowArt(entry, again)
	local art = ArtData(entry)
	if art ~= false then
		Call(ns.ProcArtShow, entry, art, again)
	end
end

ns.ProcArtData = ArtData

if type(ns.TrackerSlotParts) == "table" then
	ns.TrackerSlotParts.proc = function(...)
		local make = ns.ProcArtParts
		if type(make) ~= "function" then
			error("no art to draw", 0)
		end
		return make(...)
	end
end

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
	local id, now = entry.id, Now()
	local ended = P.stopped[id]
	local previewed = P.preview ~= nil and P.preview.entry == entry
	if previewed then
		P.preview = nil
	end
	local again = (P.up[id] ~= nil and not previewed) or (ended ~= nil and now >= ended and now - ended <= K.AGAIN)
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

local function Gone(id)
	local entry = P.up[id]
	if entry then
		Stop(entry)
	end
	P.since[id], P.signalled[id], P.glow[id], P.ended[id], P.stopped[id] = nil, nil, nil, nil, nil
	Call(ns.ProcArtDrop, id)
	for _, def in pairs(P.triggers) do
		if type(def.Forget) == "function" then
			pcall(def.Forget, id)
		end
	end
end

local function Changed(entry, before, after)
	local was = before == "fine" or before == "low"
	local now = after == "fine" or after == "low"
	if now and not was then
		Start(entry)
	elseif was and not now then
		Stop(entry)
	end
end

local function Number(value)
	return Plain(value, "number") and value or 0
end

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

local function ByUse(entry, row)
	row = row or RowOf(entry)
	return row ~= nil and ((row.watch == "usable" and entry.trigger == "usable") or #row.buffs == 0)
end

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
	local most = (entry.trigger == nil or entry.trigger == "aura") and Most(RowOf(entry)) or nil
	if Off(entry) then
		P.ended[id], P.since[id] = nil, nil
		if most then
			Call(ns.ProcArtStacks, entry, 0, most, false)
		end
		return { state = "missing", hidden = false }
	end
	local reading = Raw(entry)
	if reading.state == "low" then
		reading.state = "fine"
	end
	if most then
		local count = reading.state == "fine" and math.max(1, Number(reading.count)) or 0
		Call(ns.ProcArtStacks, entry, count, most, reading.state == "unknown")
		if count > 0 and count < most then
			P.ended[id], P.since[id] = nil, nil
			return { state = "missing", hidden = false, icon = reading.icon, count = count }
		end
	end
	if reading.state == "fine" then
		local time = Number(entry.time)
		if P.ended[id] then
			return { state = "missing", hidden = false, icon = reading.icon }
		end
		P.since[id] = P.since[id] or now
		if time > 0 then
			if most and Plain(reading.expires, "number") and reading.expires > P.since[id] + time then
				P.since[id] = reading.expires - time
			end
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

local function Hide(_, reading, how)
	return how == "none" or how == "game" or (how == "live" and reading.state == "missing")
end

local function Wanted(entry, state, how)
	if not (how == "game" or state == "fine" or state == "low") then
		return 0
	end
	return 1
end

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

local function Touch(entry)
	local trigger = P.triggers[entry.trigger]
	if trigger and type(trigger.Seen) == "function" then
		pcall(trigger.Seen, entry)
	end
end

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

local function Fields(name, buffs, lights, seconds, trigger, kind2)
	local time = Plain(seconds, "number") and seconds > 0 and seconds <= K.MAX_TIME and seconds or nil
	return { name = name, names = { name }, spells = buffs, lights = lights, trigger = P.triggers[trigger] and trigger or "aura", kind2 = kind2 == "shorter" and kind2 or nil,
		time = time, size = K.SIZE, show = "always" }
end

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

local function Automatic(row)
	if row.auto ~= nil then
		return row.auto == true
	end
	return K.AUTO_KINDS[row.kind] == true
end

local function Ranks(lights)
	local own = {}
	for _, id in ipairs(lights) do
		if Known(id) then
			own[#own + 1] = id
		end
	end
	return #own > 0 and own or nil
end

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
				if row.glow == false then
					entry.glow = false
				else
					entry.glow = nil
				end
				local look = LookSet(false)[row.name]
				look = type(look) == "table" and look or {}
				entry.colour = Plain(look.colour, "string") and look.colour or nil
				if look.sound == false or Plain(look.sound, "number") then
					entry.sound = look.sound
				else
					entry.sound = nil
				end
				if Plain(look.time, "number") and look.time >= 0 and look.time <= K.MAX_TIME then
					entry.time = look.time > 0 and look.time or nil
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

local function Ids()
	local ids = {}
	for index, entry in ipairs(A.list) do
		ids[index] = entry.id
	end
	return table.concat(ids, "|")
end

function ns.ProcAutoEntries(saved)
	if A.stale then
		Build()
	end
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

function ns.ProcAutoBuild()
	Build()
	Call(ns.ProcGlowPrepare, All())
end

function ns.ProcShowsStacks(spellID)
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or ns.Get(KEY .. ".art") ~= true or ns.Get(KEY .. ".artStacks") == false then
		return false
	end
	for _, entry in ipairs(All()) do
		if entry.on ~= false and not Off(entry) and (entry.trigger == nil or entry.trigger == "aura") and Lists(entry.spells, spellID) and Most(RowOf(entry)) then
			return true
		end
	end
	return false
end

local function World()
	Overlayed()
	local before = Ids()
	Build()
	if Ids() ~= before then
		ns.TrackerLayout()
	end
end

local function Line(name)
	for number, row in ipairs(ProcList()) do
		if row.name == name then
			return number, row
		end
	end
	return nil
end

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

function ns.ProcRemove(position)
	if Whole(position) and position > K.AUTO_LINE then
		local row = ProcList()[position - K.AUTO_LINE]
		if not row then
			return false, ("No proc numbered %s."):format(tostring(position))
		end
		OffSet(true)[row.name] = true
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
	local reading = Raw(entry)
	local state = reading.state
	if state == "fine" or state == "low" then
		local most, count = Most(RowOf(entry)), math.max(1, Number(reading.count))
		if most and count < most then
			return ("no, %d of %d stacks"):format(count, most)
		end
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

P.PREVIEW = 4

local function First()
	for _, list in ipairs({ ns.ProcAutoEntries(), All() }) do
		for _, entry in ipairs(list) do
			if entry.on ~= false and not Off(entry) then
				return entry
			end
		end
	end
	return nil
end

local function PreviewEnd()
	local preview = P.preview
	if not preview then
		return
	end
	P.preview = nil
	local entry = preview.entry
	if P.up[entry.id] == entry and P.held ~= entry then
		local stopped = P.stopped[entry.id]
		Stop(entry)
		P.stopped[entry.id] = stopped
	end
end

function ns.ProcPreview()
	if InCombatLockdown() or not ns.Enabled(KEY) or ns.TestMode.IsOn() or type(ns.PanelShown) ~= "function" or ns.PanelShown() ~= true then
		return
	end
	local entry = First()
	if P.preview and P.preview.entry ~= entry then
		PreviewEnd()
	end
	if not entry then
		return
	end
	if P.up[entry.id] ~= nil and not P.preview then
		ShowArt(entry, true)
		Call(ns.ProcGlowStart, entry, true)
		return
	end
	local again = P.preview ~= nil and P.up[entry.id] == entry
	P.preview = P.preview or { entry = entry, token = 0, since = Now() }
	local preview = P.preview
	preview.token = preview.token + 1
	P.up[entry.id] = entry
	ShowArt(entry, again)
	Call(ns.ProcGlowStart, entry, again)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		local token = preview.token
		C_Timer.After(P.PREVIEW, function()
			if P.preview == preview and preview.token == token then
				PreviewEnd()
			end
		end)
	end
end

function ns.ProcPreviewing()
	return P.preview ~= nil and not (ns.TestMode and ns.TestMode.IsOn())
end

function ns.ProcColourChanged()
	ns.RefreshModule(KEY)
	ns.ProcPreview()
end

P.fight = CreateFrame("Frame")
ns.Own[P.fight] = true
pcall(P.fight.RegisterEvent, P.fight, "PLAYER_REGEN_DISABLED")
P.fight:SetScript("OnEvent", function()
	local ok, err = pcall(PreviewEnd)
	if not ok then
		geterrorhandler()(err)
	end
end)

local function Test(entry, on)
	if on then
		PreviewEnd()
	end
	P.before = P.before or {}
	if not on then
		Stop(entry)
		if P.held == entry and ns.TestMode.IsOn() then
			P.up[entry.id] = entry
			ShowArt(entry, true)
			Call(ns.ProcGlowStart, entry, true)
		elseif P.before[entry.id] then
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

P.TEST_SOUND = "procs"

local function Pick()
	if InCombatLockdown() or not ns.Enabled(KEY) or not ns.TestMode.IsOn() then
		return nil
	end
	return First()
end

local function Hold(entry)
	P.before = P.before or {}
	if P.before[entry.id] == nil then
		P.before[entry.id] = P.up[entry.id] ~= nil
	end
	P.held, P.heldSince = entry, Now()
	P.up[entry.id] = entry
	if ns.TestMode.Sound(P.TEST_SOUND) then
		Sound(entry, true)
	end
	ShowArt(entry)
	Call(ns.ProcGlowStart, entry)
end

local function Release()
	local entry = P.held
	if entry then
		P.held = nil
		Test(entry, false)
	end
end

function ns.ProcHeld(entry)
	return entry ~= nil and P.held == entry
end

function ns.ProcEnds(entry)
	if type(entry) ~= "table" or entry.id == nil then
		return nil
	end
	local time = Number(entry.time)
	if time <= 0 then
		return nil
	end
	local now = Now()
	local since = P.up[entry.id] == entry and P.since[entry.id]
	if Plain(since, "number") and not P.ended[entry.id] and since + time > now then
		return since + time
	end
	local preview = P.preview
	local start = (preview ~= nil and preview.entry == entry and preview.since) or (P.held == entry and P.heldSince) or nil
	if Plain(start, "number") then
		return now + time - (now - start) % time
	end
	return nil
end

function ns.ProcSampleSince(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local preview = P.preview
	if preview ~= nil and preview.entry == entry and Plain(preview.since, "number") then
		return preview.since, false
	end
	if P.held == entry and Plain(P.heldSince, "number") and not ns.ProcReal(entry) then
		return P.heldSince, true
	end
	return nil
end

function ns.ProcReal(entry)
	if type(entry) ~= "table" or entry.id == nil or P.up[entry.id] ~= entry or P.ended[entry.id] then
		return false
	end
	local since = P.since[entry.id]
	if not Plain(since, "number") then
		return false
	end
	local time = Number(entry.time)
	return time <= 0 or since + time > Now()
end

local function HeldStart()
	PreviewEnd()
	local entry = Pick()
	if entry then
		Hold(entry)
	end
end

local function HeldChanged(path)
	if path ~= "*" and not (type(path) == "string" and path:find("^" .. KEY .. "%.")) then
		return
	end
	local entry = Pick()
	if entry ~= P.held then
		Release()
		if entry then
			Hold(entry)
		end
	elseif entry then
		ShowArt(entry, true)
	end
	ns.TrackerDirty()
end

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
	for _, entry in ipairs(ns.ProcAutoEntries()) do
		local number = Line(entry.name)
		if number and ((text:find("^%d+$") and K.AUTO_LINE + number == tonumber(text)) or entry.name:lower() == wanted) then
			return entry, K.AUTO_LINE + number, true
		end
	end
	return nil
end

local function Restyled(auto)
	if auto then
		Build()
	end
	ns.TrackerDirty()
	for _, name in ipairs({ "ProcArtChanged", "ProcGlowChanged" }) do
		if type(ns[name]) == "function" then
			pcall(ns[name])
		end
	end
end

local function Keep(entry, field, value)
	local look = LookSet(true)[entry.name] or {}
	LookSet(true)[entry.name] = look
	look[field] = value
end

local function SoundWord(value)
	local word = value:lower()
	if word == "none" or word == "off" then
		return false, "none"
	end
	local kit = K.KITS[word]
	return kit, kit and word or nil
end

local function Word(text)
	local word = text:match("^(%S+)")
	if not word then
		return K.USAGE
	end
	word = word:lower()
	local proc, value
	if word == "reset" then
		proc, value = text:match("^%S+%s+(.-)%s*$"), ""
	else
		proc, value = text:match("^%S+%s+(.-)%s+(%S+)%s*$")
	end
	if not proc or proc == "" then
		return K.USAGE
	end
	local entry, number, auto = Find(proc)
	if not entry then
		return ('No proc found for "%s".'):format(proc)
	end
	local label = auto and ("%s (of your class)"):format(entry.name) or ("Proc %d"):format(number)
	if word == "reset" then
		if auto then
			LookSet(true)[entry.name] = nil
		else
			local row = RowOf(entry)
			local seconds = row and row.seconds
			entry.colour, entry.sound = nil, nil
			entry.time = (Plain(seconds, "number") and seconds > 0 and seconds <= K.MAX_TIME) and seconds or nil
		end
		Restyled(auto)
		return ("%s: colour, sound and time are as the page has them."):format(label)
	elseif word == "sound" then
		local kit, name = SoundWord(value)
		if kit == nil then
			return ('%s: "%s" is not a sound. Use none, spell, chimes, bell, warhorn, raid, alarm or whisper.'):format(label, value)
		end
		if auto then
			Keep(entry, "sound", kit)
		end
		entry.sound = kit
		Restyled(auto)
		if kit ~= false then
			Sound(entry, true)
		end
		return ("%s: sound is %s."):format(label, name)
	end
	if auto and word == "trigger" then
		return ("%s: add it with Add a proc to give it a trigger of its own."):format(label)
	end
	if word == "colour" then
		local hex = value:lower():gsub("^#", "")
		if #hex == 6 then
			hex = "ff" .. hex
		end
		if not (#hex == 8 and hex:find("^%x+$")) then
			return ("%s: %s is not a colour. Six or eight digits, such as ffd100."):format(label, value)
		end
		if auto then
			Keep(entry, "colour", hex)
		end
		entry.colour = hex
		Restyled(auto)
		return ("%s: colour is %s."):format(label, hex:sub(3))
	elseif word == "time" then
		local seconds = tonumber(value)
		if not (seconds and seconds >= 0 and seconds <= K.MAX_TIME) then
			return ("%s: time is 0 to %d seconds."):format(label, K.MAX_TIME)
		end
		if auto then
			Keep(entry, "time", seconds)
			entry.time = seconds > 0 and seconds or nil
		else
			entry.time = seconds
		end
		Restyled(auto)
		return seconds == 0 and ("%s: no time limit."):format(label) or ("%s: time is %s seconds."):format(label, tostring(seconds))
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

ns.TestMode.Register("procs", {
	module = KEY,
	label = "Proc alerts",
	Start = HeldStart,
	Stop = Release,
	Changed = HeldChanged,
})

ns.TrackerWord("proc", function(text)
	local ok, line = pcall(Word, text)
	return ok and line or K.USAGE
end)

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("proc", {
		Read = Read, Clean = Clean, Add = Add, Lines = Lines, Hide = Hide, Wanted = Wanted, Changed = Changed, Gone = Gone, Cast = Cast, Event = Event,
		Test = Test, Rim = ns.ProcColour, World = World, Label = function(entry) return entry.name end,
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
