local _, ns = ...

local T = { neverCache = {} }
ns.Tracking = T

local IsSecret = ns.IsSecret
local KEEP = 10
local PREFIX = "FlatUI"
local WAIT = 1.5
local RESTRICTIONS = { [0] = "Combat", "Encounter", "Challenge mode", "PvP match", "Map", "Chat" }
local PLACES = { none = "open world", party = "dungeon", raid = "raid", pvp = "battleground", arena = "arena", scenario = "scenario" }
local UNAVAILABLE = "not available"

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil, "missing"
	end
	local ok, answer = pcall(fn, ...)
	if not ok then
		return nil, "refused"
	end
	if IsSecret(answer) then
		return nil, "hidden"
	end
	return answer
end
T.Ask = Ask

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Secrets(name)
	return type(C_Secrets) == "table" and C_Secrets[name] or nil
end

local function Hides(name, ...)
	local answer = Ask(Secrets(name), ...)
	if answer == true or answer == false then
		return answer
	end
	return nil
end
T.Hides = Hides

function T.Open()
	local call = Secrets("ShouldAurasBeSecret")
	if type(call) == "function" then
		local ok, answer = pcall(call)
		return ok and not IsSecret(answer) and answer == false
	end
	return not InCombatLockdown()
end

function ns.AurasReadable()
	local hidden = Hides("ShouldAurasBeSecret")
	if hidden == nil then
		return nil
	end
	return not hidden
end

function ns.CastLevel(spellID)
	if not Plain(spellID, "number") then
		return nil
	end
	local level = Ask(Secrets("GetSpellCastSecrecy"), spellID)
	return Plain(level, "number") and level or nil
end

function ns.CanSeeCasts(unit)
	if not Plain(unit, "string") then
		return nil
	end
	local hidden = Hides("ShouldUnitSpellCastingBeSecret", unit)
	if hidden == nil then
		return nil
	end
	return not hidden
end

function ns.MessagesOpen()
	local info = type(C_ChatInfo) == "table" and C_ChatInfo.InChatMessagingLockdown or nil
	local locked = Ask(info)
	if locked == true or locked == false then
		return not locked
	end
	return nil
end

function ns.UnitBuff(unit, spellID)
	if not (Plain(unit, "string") and Plain(spellID, "number")) then
		return nil, "refused"
	end
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetUnitAuraBySpellID or nil
	if type(call) ~= "function" then
		return nil, "refused"
	end
	local ok, aura = pcall(call, unit, spellID)
	if not ok then
		return nil, "refused"
	end
	if IsSecret(aura) then
		return nil, "hidden"
	end
	if aura == nil then
		return nil, "none"
	end
	if type(aura) ~= "table" then
		return nil, "refused"
	end
	local okFields, expires, length = pcall(function()
		return aura.expirationTime, aura.duration
	end)
	if not okFields or not (ns.Finite(expires) and ns.Finite(length)) then
		return nil, "hidden"
	end
	return aura
end

local listed
function T.Listed()
	if listed then
		return listed
	end
	if type(ns.ABILITIES) ~= "table" then
		return nil
	end
	local set, count = {}, 0
	for _, ability in ipairs(ns.ABILITIES) do
		if (ability.flags:find("o", 1, true) and (ability.kind == 3 or ability.kind == 6)) or ability.key == "PALADIN:Blessing of Freedom" then
			for _, id in ipairs(ability.buffs) do
				if not set[id] then
					set[id], count = true, count + 1
				end
			end
		end
	end
	listed = set
	T.listedCount = count
	return set
end

function T.ListedIDs()
	local set, ids = T.Listed(), {}
	for id in pairs(set or {}) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

T.lastInterrupt = nil
local watcher

local function ClassOf(guid)
	if type(UnitClassFromGUID) ~= "function" then
		return nil
	end
	local ok, name, file = pcall(UnitClassFromGUID, guid)
	if not ok then
		return nil
	end
	local class = Plain(file, "string") and file or (Plain(name, "string") and name:upper() or nil)
	return class and ns.ABILITIES_BY_CLASS and ns.ABILITIES_BY_CLASS[class] and class or nil
end

local function KickOf(class)
	for _, index in ipairs(ns.ABILITIES_BY_CLASS[class] or {}) do
		local a = ns.ABILITIES[index]
		if a.kind == 1 and not a.flags:find("p", 1, true) and not a.flags:find("n", 1, true) then
			return a
		end
	end
	return nil
end

function T.Interrupted(by)
	if type(ns.ABILITIES) ~= "table" or not ns.Enabled("enemycd") or by:sub(1, 7) ~= "Player-" then
		return
	end
	local class = ClassOf(by)
	local a = class and KickOf(class)
	if not a then
		return
	end
	local at = T.Now()
	local started = T.Use(by, class, a, at, nil)
	if type(ns.EnemyKicked) == "function" then
		started = ns.EnemyKicked(by, class, a, at) or started
	end
	if started and type(ns.EnemyRender) == "function" then
		ns.EnemyRender()
	end
end

local function OnInterrupt(by)
	if IsSecret(by) then
		T.lastInterrupt = "hidden"
	elseif type(by) == "string" and by ~= "" then
		T.lastInterrupt = "readable"
		T.Interrupted(by)
	else
		T.lastInterrupt = "empty"
	end
end

function T.Listen()
	if watcher then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	ns.Own[frame] = true
	watcher = frame
	local function Register(event)
		if frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, event, "player", "pet") then
			return
		end
		pcall(frame.RegisterEvent, frame, event)
	end
	Register("UNIT_SPELLCAST_INTERRUPTED")
	Register("UNIT_SPELLCAST_CHANNEL_STOP")
	Register("UNIT_SPELLCAST_EMPOWER_STOP")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			local prefix, _, _, from = ...
			if T.awaiting and not IsSecret(prefix) and prefix == PREFIX and not IsSecret(from) then
				T.came, T.sender = true, from
			end
		elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			local unit, _, _, by = ...
			if not IsSecret(unit) and (unit == "player" or unit == "pet") then
				OnInterrupt(by)
			end
		elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
			local unit, _, _, _, by = ...
			if not IsSecret(unit) and (unit == "player" or unit == "pet") then
				OnInterrupt(by)
			end
		end
	end)
end

local MOST_PLAYERS = 100
local SAME_USE = 1
local AURA_WAIT = 0.2

T.books, T.order, T.frames = {}, {}, setmetatable({}, { __mode = "k" })
T.units, T.subs = {}, {}
T.counts = { castRead = 0, castHidden = 0, auraRead = 0, auraHidden = 0 }
T.enemyCounts = { castRead = 0, castHidden = 0, auraRead = 0, auraHidden = 0 }

function T.Now()
	return type(GetTime) == "function" and GetTime() or 0
end

function T.Book(owner, make)
	if owner == nil or IsSecret(owner) then
		return nil
	end
	local kind = type(owner)
	if kind == "string" then
		local book = T.books[owner]
		if book or not make then
			return book
		end
		book = { timers = {}, seen = {} }
		T.books[owner] = book
		T.order[#T.order + 1] = owner
		while #T.order > MOST_PLAYERS do
			T.books[table.remove(T.order, 1)] = nil
		end
		return book
	elseif kind == "table" then
		local book = T.frames[owner]
		if not book and make then
			book = { timers = {}, seen = {} }
			T.frames[owner] = book
		end
		return book
	end
	return nil
end

function T.Clear()
	T.books, T.order, T.frames = {}, {}, setmetatable({}, { __mode = "k" })
end

function T.Timer(owner, key)
	local book = T.Book(owner)
	local timer = book and book.timers[key]
	if not timer then
		return nil
	end
	if timer.start + timer.seconds <= T.Now() then
		book.timers[key] = nil
		return nil
	end
	return timer.start, timer.seconds
end

function T.Seen(owner, key)
	local book = T.Book(owner)
	return book ~= nil and book.seen[key] == true
end

function T.Drop(owner, key)
	local book = T.Book(owner)
	if book then
		book.timers[key] = nil
	end
end

local function Mate(a, m)
	return m ~= a and a.cat ~= 0 and (m.cat == a.cat or (a.cat2 ~= nil and m.cat == a.cat2) or (m.cat2 ~= nil and m.cat2 == a.cat))
end

function T.Mates(book, class, a, at)
	local seconds = a.catcd
	if a.cat == 0 or type(seconds) ~= "number" then
		return
	end
	for _, group in ipairs({ class, "ALL" }) do
		for _, index in ipairs(ns.ABILITIES_BY_CLASS[group] or {}) do
			local m = ns.ABILITIES[index]
			if Mate(a, m) then
				local timer = book.timers[m.key]
				if not (timer and timer.start + timer.seconds > at + seconds) then
					book.timers[m.key] = { start = at, seconds = seconds }
				end
			end
		end
	end
end

function T.Use(owner, class, a, at, cast)
	local book = T.Book(owner, true)
	if not book or not Plain(at, "number") or type(a) ~= "table" then
		return false
	end
	local old = book.timers[a.key]
	book.seen[a.key] = true
	if old and math.abs(old.start - at) < SAME_USE then
		return false
	end
	local seconds = a.cd
	local via = cast and a.via and a.via[cast]
	if via then
		seconds = via.cd
	end
	book.timers[a.key] = { start = at, seconds = seconds }
	T.Mates(book, class, a, at)
	for _, key in ipairs(a.resets or {}) do
		book.timers[key] = nil
	end
	return true
end

function T.Triggers()
	if not T.triggerMap then
		local map = {}
		for _, a in ipairs(ns.ABILITIES or {}) do
			for _, id in ipairs(a.triggers or {}) do
				map[id] = map[id] or {}
				map[id][#map[id] + 1] = a
			end
		end
		T.triggerMap = map
	end
	return T.triggerMap
end

function T.Cast(owner, class, spellID, at)
	local by = ns.ABILITY_BY_CAST
	if type(by) ~= "table" or not Plain(spellID, "number") then
		return nil
	end
	local found
	for _, group in ipairs({ type(class) == "string" and class or "ALL", "ALL" }) do
		local index = by[group] and by[group][spellID]
		local a = index and ns.ABILITIES[index]
		if a then
			T.Use(owner, class, a, at, spellID)
			found = found or a
		end
	end
	for _, a in ipairs(T.Triggers()[spellID] or {}) do
		if a.class == class and type(a.catcd) == "number" then
			local book = T.Book(owner, true)
			if book and not book.timers[a.key] then
				book.timers[a.key] = { start = at, seconds = a.catcd }
			end
		end
	end
	return found
end

function T.Buffs()
	if not T.buffSet then
		local set = {}
		for _, a in ipairs(ns.ABILITIES or {}) do
			for _, id in ipairs(a.buffs) do
				set[id] = true
			end
		end
		T.buffSet = set
	end
	return T.buffSet
end

function T.NeverHidden(id)
	local cached = T.neverCache[id]
	if cached ~= nil then
		return cached
	end
	local never = type(Enum) == "table" and type(Enum.SecrecyLevel) == "table" and Enum.SecrecyLevel.NeverSecret or nil
	local call = Secrets("GetSpellAuraSecrecy")
	local answer = never ~= nil and type(call) == "function" and Ask(call, id) == never
	T.neverCache[id] = answer
	return answer
end

function T.NeverTracked()
	for id in pairs(T.Buffs()) do
		if T.NeverHidden(id) then
			return true
		end
	end
	return false
end

function T.Subscribe(key, cast, aura)
	T.subs[key] = { cast = cast, aura = aura }
end

local function Register(rec, event, on)
	rec.events = rec.events or {}
	if (rec.events[event] or false) == on then
		return
	end
	local frame = rec.frame
	if on then
		local ok, done = false, nil
		if frame.RegisterUnitEvent then
			ok, done = pcall(frame.RegisterUnitEvent, frame, event, rec.unit)
		end
		if not ok or IsSecret(done) or done == false then
			rec.all = true
			pcall(frame.RegisterEvent, frame, event)
		end
	else
		pcall(frame.UnregisterEvent, frame, event)
	end
	rec.events[event] = on
end

function T.Tune(rec)
	local cast, aura = false, false
	for _, want in pairs(rec.want) do
		cast, aura = cast or want.cast, aura or want.aura
	end
	Register(rec, "UNIT_SPELLCAST_SUCCEEDED", cast)
	Register(rec, "UNIT_AURA", aura and not T.paused)
end

function T.Hear(key, unit, cast, aura)
	if not Plain(unit, "string") or unit == "" then
		return false
	end
	local rec = T.units[unit]
	if not rec then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return false
		end
		ns.Own[frame] = true
		rec = { unit = unit, frame = frame, want = {}, counts = unit:match("^nameplate%d+$") and T.enemyCounts or T.counts }
		T.units[unit] = rec
		frame:SetScript("OnEvent", function(_, event, who, ...)
			T.OnUnitEvent(rec, event, who, ...)
		end)
	end
	rec.want[key] = { cast = cast == true, aura = aura == true }
	T.Control()
	T.Tune(rec)
	return true
end

function T.Deafen(key, unit)
	local rec = T.units[unit]
	if rec then
		rec.want[key] = nil
		T.Tune(rec)
	end
end

function T.DeafenAll(key)
	for _, rec in pairs(T.units) do
		rec.want[key] = nil
		T.Tune(rec)
	end
end

function T.Heard(key)
	local list = {}
	for unit, rec in pairs(T.units) do
		if rec.want[key] then
			list[#list + 1] = unit
		end
	end
	table.sort(list)
	return list
end

function T.OnUnitEvent(rec, event, who, ...)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, spell = ...
		if IsSecret(who) or IsSecret(spell) then
			rec.counts.castHidden = rec.counts.castHidden + 1
			return
		end
		if rec.all and who ~= rec.unit then
			return
		end
		rec.counts.castRead = rec.counts.castRead + 1
		for key, want in pairs(rec.want) do
			local sub = want.cast and T.subs[key]
			if sub and sub.cast then
				sub.cast(rec.unit, spell)
			end
		end
	elseif event == "UNIT_AURA" then
		if rec.all and (IsSecret(who) or who ~= rec.unit) then
			return
		end
		T.Queue(rec)
	end
end

function T.Queue(rec)
	if rec.queued then
		return
	end
	rec.queued = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(AURA_WAIT, function()
			T.Pass(rec)
		end)
	else
		T.Pass(rec)
	end
end

function T.Pass(rec)
	rec.queued = false
	if T.paused or not rec.events or not rec.events.UNIT_AURA then
		return
	end
	local open = T.Open()
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetUnitAuras or nil
	if type(call) ~= "function" or (not open and not T.NeverTracked()) then
		rec.counts.auraHidden = rec.counts.auraHidden + 1
		return
	end
	local ok, list = pcall(call, rec.unit, "HELPFUL")
	if not ok or IsSecret(list) or type(list) ~= "table" then
		rec.counts.auraHidden = rec.counts.auraHidden + 1
		return
	end
	rec.counts.auraRead = rec.counts.auraRead + 1
	local set = T.Buffs()
	for _, aura in ipairs(list) do
		local read, id, expires, length, source = false, nil, nil, nil, nil
		if type(aura) == "table" and not IsSecret(aura) then
			read, id, expires, length, source = pcall(function()
				return aura.spellId, aura.expirationTime, aura.duration, aura.sourceUnit
			end)
		end
		if read and Plain(id, "number") and set[id] and ns.Finite(expires) and ns.Finite(length) and length > 0 and (open or T.NeverHidden(id)) then
			if IsSecret(source) or (source ~= nil and type(source) ~= "string") then
				T.lastCaster, source = "hidden", nil
			elseif source == nil then
				T.lastCaster = "empty"
			else
				T.lastCaster = "readable"
			end
			for key, want in pairs(rec.want) do
				local sub = want.aura and T.subs[key]
				if sub and sub.aura then
					sub.aura(rec.unit, id, expires - length, length, source)
				end
			end
		end
	end
end

function T.Control()
	if T.control then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	ns.Own[frame] = true
	T.control = frame
	T.active = {}
	local call = type(C_RestrictedActions) == "table" and C_RestrictedActions.IsAddOnRestrictionActive or nil
	for kind = 0, 3 do
		T.active[kind] = Ask(call, kind) == true
	end
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "ADDON_RESTRICTION_STATE_CHANGED" then
			T.OnRestriction(...)
		else
			T.OnWorld()
		end
	end)
	pcall(frame.RegisterEvent, frame, "ADDON_RESTRICTION_STATE_CHANGED")
	pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
	T.inside = Ask(IsInInstance)
end

function T.OnRestriction(kind, state)
	if not (Plain(kind, "number") and Plain(state, "number") and kind >= 0 and kind <= 3) then
		return
	end
	T.active[kind] = state ~= 0
	local restricted = false
	for number = 0, 3 do
		restricted = restricted or T.active[number] == true
	end
	local pause = restricted and not T.NeverTracked()
	if pause ~= (T.paused == true) then
		T.paused = pause
		for _, rec in pairs(T.units) do
			T.Tune(rec)
		end
	end
	if not restricted then
		for _, rec in pairs(T.units) do
			if rec.events and rec.events.UNIT_AURA then
				T.Queue(rec)
			end
		end
	end
end

function T.OnWorld()
	T.neverCache = {}
	local inside = Ask(IsInInstance)
	if inside ~= nil and inside ~= T.inside then
		T.Clear()
	end
	T.inside = inside
end

local function Yes(value)
	if value == nil then
		return UNAVAILABLE
	end
	return value and "yes" or "no"
end

local function Kind(fn, unit)
	local answer, why = Ask(fn, unit)
	if why == "hidden" then
		return "hidden"
	elseif why then
		return UNAVAILABLE
	elseif answer == nil or answer == "" then
		return "empty"
	end
	return "readable", answer
end

local function WhoLine(label, unit)
	local guid = Kind(UnitGUID, unit)
	local class, value = Kind(UnitClassBase, unit)
	local name = Kind(UnitName, unit)
	return ("%s: GUID %s, class %s, name %s."):format(label, guid, class == "readable" and tostring(value) or class, name)
end

local function Restrictions()
	local call = type(C_RestrictedActions) == "table" and C_RestrictedActions.IsAddOnRestrictionActive or nil
	if type(call) ~= "function" then
		return UNAVAILABLE
	end
	local on = {}
	for number = 0, 5 do
		local answer = Ask(call, number)
		if answer == true then
			on[#on + 1] = RESTRICTIONS[number]
		end
	end
	return #on > 0 and table.concat(on, ", ") or "none"
end

local function PlaceText()
	if type(IsInInstance) ~= "function" then
		return UNAVAILABLE
	end
	local ok, inside, kind = pcall(IsInInstance)
	if not ok or IsSecret(inside) or inside == nil then
		return UNAVAILABLE
	end
	if IsSecret(kind) or type(kind) ~= "string" then
		return inside and "instance" or "open world"
	end
	return PLACES[kind] or kind
end

local function GroupText()
	local group, raid = Ask(IsInGroup), Ask(IsInRaid)
	if group == nil and raid == nil then
		return UNAVAILABLE
	elseif raid == true then
		return "raid"
	elseif group == true then
		return "party"
	end
	return "not in a group"
end

local function NeverHidden()
	local call = Secrets("GetSpellAuraSecrecy")
	local never = type(Enum) == "table" and type(Enum.SecrecyLevel) == "table" and Enum.SecrecyLevel.NeverSecret or nil
	local ids = T.ListedIDs()
	if type(call) ~= "function" or never == nil or #ids == 0 then
		return UNAVAILABLE
	end
	local count = 0
	for _, id in ipairs(ids) do
		local level = Ask(call, id)
		if level == never then
			count = count + 1
		end
	end
	return ("%d of %d"):format(count, #ids)
end

local function TargetBuffs(unit)
	local exists = Ask(UnitExists, unit)
	if exists == false or (exists == nil and type(UnitExists) == "function") then
		return "no target"
	end
	local read, last = 0, "none"
	for _, id in ipairs(T.ListedIDs()) do
		local aura, why = ns.UnitBuff(unit, id)
		if aura then
			read = read + 1
		elseif why == "hidden" or why == "refused" then
			if read == 0 then
				return why == "hidden" and "hidden" or "refused"
			end
			last = why
		end
	end
	if read > 0 then
		return ("%d read"):format(read)
	end
	return last == "none" and "none found" or last
end

local function ResultName(result)
	local enum = type(Enum) == "table" and Enum.SendAddonMessageResult
	if type(enum) == "table" then
		for name, number in pairs(enum) do
			if number == result then
				return name
			end
		end
	end
	return tostring(result)
end

local function TestMessage()
	local info = type(C_ChatInfo) == "table" and C_ChatInfo or nil
	if not (info and type(info.SendAddonMessage) == "function") then
		return "Test message: " .. UNAVAILABLE .. "."
	end
	if type(info.RegisterAddonMessagePrefix) == "function" then
		pcall(info.RegisterAddonMessagePrefix, PREFIX)
	end
	local grouped = Ask(IsInGroup) == true
	local chatType, target, to = "PARTY", nil, "the party"
	if not grouped then
		local name = Ask(UnitName, "player")
		if not Plain(name, "string") or name == "" then
			return "Test message: not sent, the game gives no name for you."
		end
		chatType, target, to = "WHISPER", name, "yourself"
	end
	local ok, result = pcall(info.SendAddonMessage, PREFIX, "check", chatType, target)
	if not ok or IsSecret(result) then
		return "Test message: refused."
	end
	T.sentTo = target
	return ("Test message: sent to %s, result %s."):format(to, ResultName(result)), result
end

local function WatchReply(record, sent)
	if not sent or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	T.Listen()
	local frame = watcher
	if not frame then
		return
	end
	local mine = {}
	T.awaiting, T.came, T.sender = mine, false, nil
	pcall(frame.RegisterEvent, frame, "CHAT_MSG_ADDON")
	C_Timer.After(WAIT, function()
		if T.awaiting ~= mine then
			return
		end
		T.awaiting = nil
		pcall(frame.UnregisterEvent, frame, "CHAT_MSG_ADDON")
		local name = Ask(UnitName, "player")
		local text
		if T.came then
			local same = Plain(T.sender, "string") and Plain(name, "string") and (T.sender == name or T.sender:match("^([^%-]+)") == name)
			text = "Test message came back: yes, sender name " .. (same and "matches your name." or "differs from your name.")
		else
			text = "Test message came back: no."
		end
		record.lines[#record.lines + 1] = text
		if type(T.OnReply) == "function" then
			pcall(T.OnReply, text)
		end
	end)
end

function ns.CheckLines()
	T.Listen()
	local lines = {}
	local function Add(text)
		lines[#lines + 1] = text
	end
	Add("Place: " .. PlaceText() .. ".")
	Add("Restrictions in force: " .. Restrictions() .. ".")
	Add("Group: " .. GroupText() .. ".")
	local restricted = Hides("HasSecretRestrictions")
	Add("The game withholds values: " .. (restricted == nil and UNAVAILABLE or (restricted and "yes" or "no")) .. ".")
	Add("Buffs hidden: " .. Yes(Hides("ShouldAurasBeSecret")) .. ".")
	Add("Cooldowns hidden: " .. Yes(Hides("ShouldCooldownsBeSecret")) .. ".")
	Add("Casts of the target hidden: " .. Yes(Hides("ShouldUnitSpellCastingBeSecret", "target")) .. ".")
	Add("Names and classes of the target hidden: " .. Yes(Hides("ShouldUnitIdentityBeSecret", "target")) .. ".")
	Add(WhoLine("Target", "target"))
	Add(WhoLine("party1", "party1"))
	Add("Listed buffs the game never hides: " .. NeverHidden() .. ".")
	Add(ns.DefensivesPathText and ns.DefensivesPathText() or "Defensives on you: " .. UNAVAILABLE .. ".")
	Add("A listed buff on you: " .. (ns.DefensivesSeenText and ns.DefensivesSeenText() or "not seen") .. ".")
	Add("Listed buffs of the target: " .. TargetBuffs("target") .. ".")
	Add(("Party casts seen: %d readable, %d hidden."):format(T.counts.castRead, T.counts.castHidden))
	Add(("Party buffs read: %d readable, %d hidden."):format(T.counts.auraRead, T.counts.auraHidden))
	Add(("Enemy casts seen: %d readable, %d hidden."):format(T.enemyCounts.castRead, T.enemyCounts.castHidden))
	Add(("Enemy buffs read: %d readable, %d hidden."):format(T.enemyCounts.auraRead, T.enemyCounts.auraHidden))
	Add("Caster of a party buff: " .. (T.lastCaster or "none seen yet") .. ".")
	local locked = ns.MessagesOpen()
	Add("Addon messages: " .. (locked == nil and UNAVAILABLE or (locked and "allowed" or "blocked by the game")) .. ".")
	local record = { lines = lines }
	local text, result = TestMessage()
	Add(text)
	WatchReply(record, result ~= nil)
	Add("Who interrupted your last cast: " .. (T.lastInterrupt or "no interrupt of your own cast yet") .. ".")
	local first = type(ns.ABILITIES) == "table" and ns.ABILITIES[1] and ns.ABILITIES[1].casts[1] or nil
	local cooldown
	if first then
		cooldown = Hides("ShouldSpellCooldownBeSecret", first)
	end
	Add("Cooldown numbers hidden: " .. Yes(cooldown) .. ".")
	local plates = Ask(C_NamePlate and C_NamePlate.GetNamePlates)
	if type(plates) == "table" then
		local usable, forbidden = 0, 0
		for _, plate in ipairs(plates) do
			if ns.Forbidden(plate) then
				forbidden = forbidden + 1
			else
				usable = usable + 1
			end
		end
		Add(("Nameplates: %d usable, %d forbidden."):format(usable, forbidden))
	else
		Add("Nameplates: " .. UNAVAILABLE .. ".")
	end
	local arena, other = Ask(IsActiveBattlefieldArena), nil
	if type(C_PvP) == "table" then
		other = Ask(C_PvP.IsArena)
	end
	if other == true or arena == nil then
		arena = other
	end
	Add("Arena: " .. Yes(arena) .. ".")
	local breakLine = type(ns.EnemyArenaLine) == "function" and ns.EnemyArenaLine() or nil
	if breakLine then
		Add(breakLine)
	end
	local account = ns.Account()
	if account then
		account.checks = type(account.checks) == "table" and account.checks or {}
		local stamp = type(date) == "function" and Ask(date, "%Y-%m-%d %H:%M") or nil
		record.when = type(stamp) == "string" and stamp or nil
		account.checks[#account.checks + 1] = record
		while #account.checks > KEEP do
			table.remove(account.checks, 1)
		end
	end
	return lines
end

function ns.CheckLast()
	local account = ns.Account()
	local list = account and account.checks
	return type(list) == "table" and list[#list] or nil
end
