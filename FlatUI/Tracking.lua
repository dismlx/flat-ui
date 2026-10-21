local _, ns = ...

-- What the game lets an addon see right now, and /flatui check, which prints it. This file is no module of its own and has no
-- events but the ones it asks for (the kind of the last interrupt of the player's own cast, and the answer to the check's test
-- message). Every probe is a call in pcall: a call the client lacks, a call that raises and a withheld answer all give nil. The
-- helpers live in one table, T, so that no function holds many upvalues and the file stays far from the limit of locals.

local T = { neverCache = {} }
ns.Tracking = T

local IsSecret = ns.IsSecret
local KEEP = 10
local PREFIX = "FlatUI"
local WAIT = 1.5
-- The restriction types of the game, by number (RestrictedActionsConstantsDocumentation.lua:26-31).
local RESTRICTIONS = { [0] = "Combat", "Encounter", "Challenge mode", "PvP match", "Map", "Chat" }
local PLACES = { none = "open world", party = "dungeon", raid = "raid", pvp = "battleground", arena = "arena", scenario = "scenario" }
local UNAVAILABLE = "not available"

-- The answer of a game call, or nil with the reason: "missing" when the client lacks the call, "refused" when it raises,
-- "hidden" when the answer is withheld.
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

-- What the game says about one thing it may hide: true, false, or nil when it cannot say.
local function Hides(name, ...)
	local answer = Ask(Secrets(name), ...)
	if answer == true or answer == false then
		return answer
	end
	return nil
end
T.Hides = Hides

-- True when the game says buffs are open to addon code: the answer is plainly false. Without the call, out of combat. Not kept,
-- as TrackerSlots.lua does it.
function T.Open()
	local call = Secrets("ShouldAurasBeSecret")
	if type(call) == "function" then
		local ok, answer = pcall(call)
		return ok and not IsSecret(answer) and answer == false
	end
	return not InCombatLockdown()
end

-- True when buffs can be read, false when they are hidden, nil when the game cannot say.
function ns.AurasReadable()
	local hidden = Hides("ShouldAurasBeSecret")
	if hidden == nil then
		return nil
	end
	return not hidden
end

-- The secrecy level the game gives the casts of a spell, or nil. Enum.SecrecyLevel: 0 never, 1 always, 2 when restricted.
function ns.CastLevel(spellID)
	if not Plain(spellID, "number") then
		return nil
	end
	local level = Ask(Secrets("GetSpellCastSecrecy"), spellID)
	return Plain(level, "number") and level or nil
end

-- True when the casts of a unit can be seen, false when they are hidden, nil when the game cannot say.
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

-- True when addon messages can be sent, false in a chat lockdown, nil when the game cannot say.
function ns.MessagesOpen()
	local info = type(C_ChatInfo) == "table" and C_ChatInfo.InChatMessagingLockdown or nil
	local locked = Ask(info)
	if locked == true or locked == false then
		return not locked
	end
	return nil
end

-- A buff of a unit by spell ID: its table when the call did not raise, the answer is not withheld and the end time and length are
-- plain numbers. Otherwise nil and a reason: "hidden", "refused" or "none".
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

-- The buff IDs that Defensives on you lists: the abilities other players cast on someone (defensives and wards) and Blessing of
-- Freedom. A set, spell ID to true. Nil when the list of abilities is not loaded.
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

-- The listed IDs, in order of their numbers.
function T.ListedIDs()
	local set, ids = T.Listed(), {}
	for id in pairs(set or {}) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

-- The last interrupt of the player's own cast -------------------------------------------------------------------------------

-- "readable" when interruptedBy is a plain name of a unit, "hidden" when it is withheld, "empty" when there is none; nil before any.
T.lastInterrupt = nil
local watcher

-- The class of a player by GUID: its file name, or nil. The game's own cast bar reads the second answer (CastingBarFrame.lua:618-622);
-- the answer is tested for secrecy first.
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

-- The first interrupt of a class that a player casts himself: not a pet's, and with a cooldown.
local function KickOf(class)
	for _, index in ipairs(ns.ABILITIES_BY_CLASS[class] or {}) do
		local a = ns.ABILITIES[index]
		if a.kind == 1 and not a.flags:find("p", 1, true) and not a.flags:find("n", 1, true) then
			return a
		end
	end
	return nil
end

-- A kick that stopped the player's own cast, by a player: starts that player's interrupt timer, and those of the abilities that share
-- its category. A pet or a creature (a GUID that is not a player's) starts nothing. Enemy cooldowns shows the timer.
function T.Interrupted(by)
	if type(ns.ABILITIES) ~= "table" or not ns.Enabled("enemycd") or by:sub(1, 7) ~= "Player-" then
		return
	end
	local class = ClassOf(by)
	local a = class and KickOf(class)
	if a and T.Use(by, class, a, T.Now(), nil) and type(ns.EnemyRender) == "function" then
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

-- Starts listening for the two events, for the player and the pet. A client without RegisterUnitEvent hears every unit and the
-- handler keeps only these two.
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
			-- The payload has the flag complete before interruptedBy (UnitDocumentation.lua:4740-4753).
			local unit, _, _, _, by = ...
			if not IsSecret(unit) and (unit == "player" or unit == "pet") then
				OnInterrupt(by)
			end
		end
	end)
end

-- Timers of other players, and their casts and buffs ----------------------------------------------------------------------------
-- A timer is { start, seconds } in the numbers of GetTime(), kept for one player in his book, by the key of the ability. The book
-- of a player is found by his GUID; for a unit whose GUID the game hides it is found by the unit frame, in a table that forgets a
-- frame the game no longer has. At most 100 players are kept, the oldest dropped first, and the books are cleared on entering or
-- leaving an instance. A use reported twice within a second is one use.

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

-- The book of a player: by GUID (a string) or by unit frame (a table). Made when `make` is true, else nil when there is none.
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

-- Forgets every book: the player left or entered an instance.
function T.Clear()
	T.books, T.order, T.frames = {}, {}, setmetatable({}, { __mode = "k" })
end

-- The timer of an ability of a player: its start and length, or nothing. An ended timer is dropped here.
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

-- An ability of the same class that shares a category with `a`.
local function Mate(a, m)
	return m ~= a and a.cat ~= 0 and (m.cat == a.cat or (a.cat2 ~= nil and m.cat == a.cat2) or (m.cat2 ~= nil and m.cat2 == a.cat))
end

-- Starts the timers of the abilities that share a category with `a`, each with the length of the category, unless one runs longer.
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

-- A use of ability `a` of a player of class `class`, at the time `at`. Starts its timer and those of its category mates and clears
-- the timers it resets. False when it is the same use as the one already kept.
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

-- The abilities that a cast of an unlisted category mate starts, by cast ID.
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

-- A cast of a spell by a player: the ability it is, if it is one in the list, after its timers are started. nil for a spell that is none.
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

-- Every buff ID of the list, as a set.
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

-- True when the game never hides the buff of this spell.
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

-- True when at least one buff of the list is never hidden.
function T.NeverTracked()
	for id in pairs(T.Buffs()) do
		if T.NeverHidden(id) then
			return true
		end
	end
	return false
end

-- The listener frames ---------------------------------------------------------------------------------------------------------------
-- One small frame for each unit token, made when first wanted, hears the cast and the buffs of that unit alone. `key` names the
-- module that wants them. A module sets what it does with them in T.Subscribe: cast(unit, spellID) for a cast whose unit and spell
-- are plain, aura(unit, spellID, start, seconds, source) for each buff of a pass.

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

-- Registers the events the modules want of a unit: the casts, and the buffs unless the game hides them all.
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

-- The units a module hears, as a list.
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
		-- The payload is not read where the event is registered for this unit alone.
		if rec.all and (IsSecret(who) or who ~= rec.unit) then
			return
		end
		T.Queue(rec)
	end
end

-- One pass for each unit in 0.2 seconds, however many events come.
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

-- The buffs of a unit, from one call. While the game hides buffs only a buff it never hides is passed on.
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

-- The two events that keep the listeners right: a restriction that hides buffs starts or ends, and the player enters a place.
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

-- A restriction of the four that hide buffs (Combat, Encounter, Challenge mode, PvP match) starts or ends. While one is on and no
-- buff of the list is never hidden, the buff events are not listened for.
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
end

-- The books are cleared when the player enters or leaves an instance.
function T.OnWorld()
	T.neverCache = {}
	local inside = Ask(IsInInstance)
	if inside ~= nil and inside ~= T.inside then
		T.Clear()
	end
	T.inside = inside
end

-- The check -------------------------------------------------------------------------------------------------------------------

local function Yes(value)
	if value == nil then
		return UNAVAILABLE
	end
	return value and "yes" or "no"
end

-- "readable", "hidden" or "empty" for the first answer of a unit call.
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

-- The restrictions in force, by name.
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

-- How many of the listed buffs the game never hides, from GetSpellAuraSecrecy.
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

-- The listed buffs of a unit: how many were read, or why none was.
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

-- Sends one test message: to the party in a group, else by whisper to the player. Returns the text of the line.
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

-- The test message comes back as CHAT_MSG_ADDON, if the game lets it through. Watches for a short while and says what happened.
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

-- The lines of /flatui check, kept as the last of ten in the account's record. The test message goes out once for each call.
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

-- The lines of the last check, or nil.
function ns.CheckLast()
	local account = ns.Account()
	local list = account and account.checks
	return type(list) == "table" and list[#list] or nil
end
