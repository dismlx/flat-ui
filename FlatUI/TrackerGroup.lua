local _, ns = ...

-- The group buff tracker: how many members of the player's party or raid lack the player's class buff, shown as missing/total on the icon,
-- and a click on the icon (TrackerClicks.lua) casts the buff on a member who lacks it. This follows the group buff check of the Class Buff
-- Reminder of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLClassBuffReminder/ClassBuffReminder.lua:940-970,
-- 5950-6080 and 7450-7600): a member counts while the unit exists, is connected, is alive and is not one of the game's followers, and, but for
-- the player, is in sight and in the player's phase; it lacks the buff only when the game plainly gives none of the buff's auras on it. In a
-- raid every member counts, but for a shout, which reaches only the player's own party (the party tokens, which name the player's subgroup in a
-- raid) and is cast with no target.
-- The auras of other units are read only out of combat, and only while the game says aura values are open (C_Secrets.ShouldAurasBeSecret,
-- SecretPredicateAPIDocumentation.lua:119-127): C_UnitAuras.GetUnitAuraBySpellID and GetAuraDataBySpellName are SecretWhenUnitAuraRestricted and
-- RequiresNonSecretAura (UnitAuraDocumentation.lua:245-262, 456-473), GetUnitAuraBySpellID gives nothing for a unit out of sight, and UNIT_AURA
-- carries withheld values while auras are restricted (UnitAuraDocumentation.lua:645-655). In a fight the tracker shows what was known last, as
-- a buff does. UnitPhaseReason is SecretWhenUnitIdentityRestricted (UnitDocumentation.lua:2651-2665) and UnitInRange always secret (1700-1715), so
-- range is asked of C_Spell.IsSpellInRange (SpellDocumentation.lua:948-963), which has no withheld answer, and only to choose whom a click casts on.
-- Every answer is still tested with IsSecret before it is compared or kept.

local KEY = "trackers"
local IsSecret = ns.IsSecret

-- FAMILIES: by the class token UnitClass gives, the group buffs of the class: key (the word it is added by), label (its name when the game gives
-- none), cast (the first rank of the spell cast on one member; the click casts it by name, which is its highest rank), ids (every rank of that spell
-- and of the one cast on the whole group or class, all of which count as the buff), party (a shout, for the player's party), lowTime (the
-- tracker's own Low at), check (the buff is offered only while C_Spell.DoesSpellExist, SpellDocumentation.lua:46-60, says its spell exists: the
-- Forever build of EnhanceQoL takes Blessing of Light and Blessing of Salvation out, Core/Cleanup.lua:1236-1244). The IDs are those of
-- ClassData.lua (lines 9, 16, 34-36, 52, 67), from the DB2 tables of build 1.60.1.70245, the Blessing split by its name.
-- PICK: the words of the Add a check line. MAX_UNITS: the largest raid. MAX_NAMES: the members the check names.
local K = {
	FAMILIES = {
		PRIEST = {
			{ key = "fortitude", label = "Power Word: Fortitude", cast = 1243, ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
			{ key = "spirit", label = "Divine Spirit", cast = 14752, ids = { 14752, 14818, 14819, 27841, 27681 } },
			{ key = "shadow", label = "Shadow Protection", cast = 976, ids = { 976, 10957, 10958, 27683 } },
		},
		MAGE = {
			{ key = "intellect", label = "Arcane Intellect", cast = 1459, ids = { 1459, 1460, 1461, 10156, 10157, 23028 } },
		},
		DRUID = {
			{ key = "mark", label = "Mark of the Wild", cast = 1126, ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
		},
		WARRIOR = {
			{ key = "shout", label = "Battle Shout", cast = 6673, ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 }, party = true, lowTime = 15 },
		},
		PALADIN = {
			{ key = "might", label = "Blessing of Might", cast = 19740, ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 } },
			{ key = "wisdom", label = "Blessing of Wisdom", cast = 19742, ids = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 } },
			{ key = "kings", label = "Blessing of Kings", cast = 20217, ids = { 20217, 25898 } },
			{ key = "salvation", label = "Blessing of Salvation", cast = 1038, ids = { 1038, 25895 }, check = true },
			{ key = "light", label = "Blessing of Light", cast = 19977, ids = { 19977, 19978, 19979, 25890 }, check = true },
		},
	},
	PICK = "Group buff: %s",
	MAX_UNITS = 40, MAX_NAMES = 5, MAX_ID = 2147483647, MAX_SPELLS = 40, MAX_NAME = 40,
	NO_AURAS = "Trackers: the game gives no buff information of other units, so group buff trackers show a grey icon.",
}
-- What was read of each tracker, by the id of its entry: { missing, total, lacking = { unit, ... }, soonest = { unit, expires, length }, fresh }.
-- A read is used again until an event of the group says it is old. heard: what the frame hears, nil, "roster" (a group tracker is on: the
-- roster and the end of a fight) or "all" (in a group: the units as well). EVENTS: the events of each.
local S = { read = {}, frame = nil, heard = nil }
local EVENTS = { roster = { "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }, all = { "UNIT_AURA", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_PHASE" } }

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Plain(value, "number") and value >= 1 and value <= K.MAX_ID and value == math.floor(value)
end

-- The first answer of a game call, or nil when the call is missing, raises or is withheld.
local function Ask(call, ...)
	if type(call) ~= "function" then
		return nil
	end
	local ok, answer = pcall(call, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

-- A field of a table, or nil when it cannot be read or is withheld.
local function Field(object, key)
	local ok, value = pcall(function()
		return object[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Now()
	local now = Ask(GetTime)
	return Plain(now, "number") and now or 0
end

local function SpellName(id)
	local name = Ask(type(C_Spell) == "table" and C_Spell.GetSpellName, id)
	return Plain(name, "string") and name ~= "" and name or nil
end

-- True when the player knows a spell of the list: the game's two known tests (SpellBookDocumentation.lua:738-770).
local function Knows(ids)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	for _, id in ipairs(ids or {}) do
		if Ask(book.IsSpellKnown, id) == true or Ask(book.IsSpellKnownOrInSpellBook, id) == true then
			return true
		end
	end
	return false
end

-- The group buffs of the player's class that this game has: a buff marked check only when C_Spell.DoesSpellExist says yes.
local function Families()
	local ok, _, token = pcall(UnitClass, "player")
	local list = ok and Plain(token, "string") and K.FAMILIES[token] or {}
	local found = {}
	for _, family in ipairs(list) do
		if not family.check or Ask(type(C_Spell) == "table" and C_Spell.DoesSpellExist, family.cast) == true then
			found[#found + 1] = family
		end
	end
	return found
end

-- The names of the auras, each once, as the game gives them: the spell cast on one member and the one cast on all.
local function Names(ids)
	local names, seen = {}, {}
	for _, id in ipairs(ids) do
		local name = SpellName(id)
		if name and not seen[name] and #name <= K.MAX_NAME and #names < 8 then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	return names
end

-- The player is in a party or a raid.
local function Grouped()
	return Ask(IsInGroup) == true
end

-- Whether other units' auras may be read now: out of combat, and while the game says aura values are open.
local function Open()
	if InCombatLockdown() then
		return false
	end
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) ~= "function" then
		return true
	end
	local ok, answer = pcall(call)
	return ok and not IsSecret(answer) and answer == false
end

-- The units of the group the buff is for, in the order the game numbers them: the raid, or the player and the party (a shout: always the party,
-- which in a raid is the player's own subgroup).
local function Units(entry)
	local units = {}
	if Ask(IsInRaid) == true and not entry.party then
		local count = Ask(GetNumGroupMembers)
		for index = 1, Plain(count, "number") and math.min(count, K.MAX_UNITS) or 0 do
			units[#units + 1] = "raid" .. index
		end
	else
		units[1] = "player"
		local count = Ask(GetNumSubgroupMembers)
		for index = 1, Plain(count, "number") and math.min(count, 4) or 0 do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end

-- True for a member that counts: there, connected, alive, no follower of the game's; one that is not the player also in sight and in phase. An
-- answer the game withholds is taken as no, but for the phase, which is taken as in phase.
local function Counts(unit)
	if Ask(UnitExists, unit) ~= true or Ask(UnitIsConnected, unit) ~= true or Ask(UnitIsDeadOrGhost, unit) ~= false or Ask(UnitInPartyIsAI, unit) == true then
		return false
	end
	if unit == "player" or Ask(UnitIsUnit, unit, "player") == true then
		return true
	end
	if Ask(UnitIsVisible, unit) ~= true then
		return false
	end
	local ok, reason = pcall(UnitPhaseReason, unit)
	return not ok or IsSecret(reason) or reason == nil
end

-- Whether the unit has one of the buff's auras: true and the aura, false for plainly none, nil when a call failed or was withheld. By ID first,
-- then by name, which finds a rank the list lacks.
local function Has(entry, unit)
	local auras = type(C_UnitAuras) == "table" and C_UnitAuras or {}
	local failed, asked = false, false
	if type(auras.GetUnitAuraBySpellID) == "function" then
		asked = true
		for _, id in ipairs(entry.spells) do
			local ok, aura = pcall(auras.GetUnitAuraBySpellID, unit, id)
			if not ok or IsSecret(aura) then
				failed = true
			elseif type(aura) == "table" then
				return true, aura
			end
		end
	end
	if not failed and type(auras.GetAuraDataBySpellName) == "function" then
		asked = true
		for _, name in ipairs(entry.names) do
			local ok, aura = pcall(auras.GetAuraDataBySpellName, unit, name, "HELPFUL")
			if not ok or IsSecret(aura) then
				failed = true
			elseif type(aura) == "table" then
				return true, aura
			end
		end
	end
	if not asked then
		ns.Note(KEY, K.NO_AURAS)
		return nil
	end
	if failed then
		return nil
	end
	return false
end

-- One look at the group: how many lack the buff of how many that count, who lacks it, and whose buff ends first.
local function Scan(entry)
	local read = { missing = 0, total = 0, lacking = {}, fresh = true }
	for _, unit in ipairs(Units(entry)) do
		if Counts(unit) then
			local has, aura = Has(entry, unit)
			if has == false then
				read.missing, read.total = read.missing + 1, read.total + 1
				read.lacking[#read.lacking + 1] = unit
			elseif has == true then
				read.total = read.total + 1
				local expires, length = Field(aura, "expirationTime"), Field(aura, "duration")
				if Plain(expires, "number") and expires > 0 and Plain(length, "number") and length > 0
					and (not read.soonest or expires < read.soonest.expires) then
					read.soonest = { unit = unit, expires = expires, length = length }
				end
			end
		end
	end
	return read
end

-- The look of the group kept for the tracker, read again when an event made it old.
local function Fresh(entry)
	local read = S.read[entry.id]
	if not (read and read.fresh) then
		read = Scan(entry)
		S.read[entry.id] = read
	end
	return read
end

-- Every look kept is old: the next pass reads the group again. The player entering the world or the spells changing asks for a pass already.
local function Old()
	for _, read in pairs(S.read) do
		read.fresh = false
	end
end

-- Every look kept is old, and the trackers are drawn again.
local function Stale()
	Old()
	if type(ns.TrackerDirty) == "function" then
		ns.TrackerDirty()
	end
end

-- A unit of the group: the player, party1 to party4 and raid1 to raid40, none of their pets.
local function Member(unit)
	return unit == "player" or (unit:find("^party%d+$") ~= nil) or (unit:find("^raid%d+$") ~= nil)
end

local function OnEvent(_, event, unit)
	if not ns.Enabled(KEY) then
		return
	end
	if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
		Stale()
	elseif not InCombatLockdown() and (IsSecret(unit) or (type(unit) == "string" and Member(unit))) then
		-- In a fight nothing is read, and the end of the fight makes every look old.
		Stale()
	end
end

-- The frame hears the roster only while a group tracker is on, and the units only while the player is in a group as well (UNIT_AURA of every
-- unit is many events in a raid). heard is nil, "roster" or "all".
local function Listen(heard)
	if heard == S.heard then
		return
	end
	if not S.frame then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return
		end
		ns.Own[frame] = true
		frame:SetScript("OnEvent", OnEvent)
		S.frame = frame
	end
	local frame = S.frame
	for _, event in ipairs(EVENTS.roster) do
		pcall(heard and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	for _, event in ipairs(EVENTS.all) do
		pcall(heard == "all" and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	S.heard = heard
end

-- The kind --------------------------------------------------------------------------------------------------------------------------------

-- The reading: missing while a member lacks the buff, low while the first one to end has Low at (seconds left) or less, else fine; count is how
-- many lack it and total how many count. Out of a group it is absent and the tracker is not shown; in a fight it is hidden.
local function Read(entry)
	if not Grouped() then
		Listen("roster")
		return { state = "unknown", hidden = false, absent = true }
	end
	Listen("all")
	if not Open() then
		return { state = "unknown", hidden = true }
	end
	local read = Fresh(entry)
	if read.total == 0 then
		return { state = "unknown", hidden = false }
	end
	local icon = Ask(type(C_Spell) == "table" and C_Spell.GetSpellTexture, entry.cast)
	local reading = { state = read.missing > 0 and "missing" or "fine", hidden = false, count = read.missing, total = read.total,
		icon = (Plain(icon, "number") or Plain(icon, "string")) and icon or nil }
	local soonest = read.soonest
	if soonest and reading.state == "fine" then
		reading.expires, reading.length = soonest.expires, soonest.length
		local lowTime = ns.TrackerValue(entry, "lowTime")
		if Plain(lowTime, "number") and lowTime > 0 then
			if soonest.expires - Now() <= lowTime then
				reading.state = "low"
			elseif type(ns.TrackerWake) == "function" then
				ns.TrackerWake(entry, soonest.expires - lowTime)
			end
		end
	end
	return reading
end

-- A group tracker keeps its spells and names as a buff does, the spell it casts and whether it is a shout.
local function Clean(entry)
	if ns.TrackerCleanSpells(entry) ~= true or #entry.spells == 0 then
		return false
	end
	if not Whole(entry.cast) then
		entry.cast = entry.spells[1]
	end
	if entry.party ~= true then
		entry.party = nil
	end
	return true
end

-- The fields of a group tracker for a buff: one of the class, or any spell by name, ID or link with every rank the spell book lists.
local function Fields(family)
	local name = SpellName(family.cast) or family.label
	local names = Names(family.ids)
	if #names == 0 then
		names[1] = name
	end
	local spells = {}
	for _, id in ipairs(family.ids) do
		spells[#spells + 1] = id
	end
	return { name = name, names = names, spells = spells, cast = family.cast, party = family.party or nil, lowTime = family.lowTime }
end

local function Spell(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	if not id then
		local info = Ask(type(C_Spell) == "table" and C_Spell.GetSpellInfo, text)
		id = type(info) == "table" and Field(info, "spellID") or nil
	end
	return Whole(id) and SpellName(id) and id or nil
end

local function Add(argument, entries)
	local text = tostring(argument or ""):match("^%s*(.-)%s*$")
	local families, family = Families(), nil
	if text == "" then
		for _, each in ipairs(families) do
			if not family and Knows(each.ids) then
				family = each
			end
		end
		family = family or families[1]
		if not family then
			return nil, "Your class has no group buff. Name one: /flatui tracker add group and its name."
		end
	else
		local wanted = text:lower()
		for _, each in ipairs(families) do
			if not family and (each.key == wanted or each.label:lower() == wanted or (SpellName(each.cast) or ""):lower() == wanted) then
				family = each
			end
		end
	end
	local fields
	if family then
		fields = Fields(family)
	else
		local id = Spell(text)
		if not id then
			return nil, ('No spell found for "%s".'):format(text)
		end
		local name = SpellName(id)
		local spells, seen = { id }, { [id] = true }
		for _, rank in ipairs(type(ns.TrackerRanks) == "function" and ns.TrackerRanks(name) or {}) do
			if not seen[rank] and #spells < K.MAX_SPELLS then
				seen[rank] = true
				spells[#spells + 1] = rank
			end
		end
		fields = { name = name, names = { name }, spells = spells, cast = id }
	end
	for _, entry in ipairs(entries) do
		if entry.kind == "group" and entry.cast == fields.cast then
			return nil, ("%s is already tracked."):format(fields.name)
		end
	end
	return fields, ("Added %s for the group."):format(fields.name)
end

local function Label(entry)
	return Plain(entry.name, "string") and entry.name ~= "" and entry.name or SpellName(entry.cast) or "Group buff"
end

local function Icon(entry)
	local icon = Ask(type(C_Spell) == "table" and C_Spell.GetSpellTexture, entry.cast)
	return (Plain(icon, "number") or Plain(icon, "string")) and icon or nil
end

-- Hidden out of a group; else the rules of Show.
local function Wanted()
	if not Grouped() then
		return 0
	end
	return nil
end

-- "2/5" on the icon: how many lack the buff of how many count, from a reading made now.
local function Count(_, reading, how)
	if how == "live" and Plain(reading.count, "number") and Plain(reading.total, "number") then
		return ("%d/%d"):format(reading.count, reading.total)
	end
	return nil
end

local function UnitLabel(unit)
	local name = Ask(UnitName, unit)
	return Plain(name, "string") and name ~= "" and name or unit
end

local function Lines(entry)
	if not Grouped() then
		return { "Group buff: not in a group, so it is hidden." }
	end
	local read = S.read[entry.id]
	if not read then
		return { "Group buff: not read yet. Other members are read out of combat only." }
	end
	local names = {}
	for index, unit in ipairs(read.lacking) do
		if index > K.MAX_NAMES then
			names[#names + 1] = ("%d more"):format(#read.lacking - K.MAX_NAMES)
			break
		end
		names[#names + 1] = UnitLabel(unit)
	end
	local who = #names > 0 and (" (" .. table.concat(names, ", ") .. ")") or ""
	return { ("Group buff: %d of %d lack it%s%s. Other members are read out of combat only."):format(read.missing, read.total, who,
		entry.party and ", in your party alone" or "") }
end

-- Forgets what was read of a tracker that is gone, and stops hearing the group when no group tracker is left.
local function Gone(id)
	S.read[id] = nil
	for _, entry in ipairs(type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		if entry.kind == "group" and entry.on ~= false and entry.id ~= id and ns.Enabled(KEY) then
			return
		end
	end
	Listen(nil)
end

-- What a click on the tracker casts and on whom: { type, spell, unit } for the secure button and the words of its tooltip, or nil when nothing is to
-- be done. A member who lacks the buff and is in the spell's range first, then one who lacks it, then, while the tracker is low, the one whose buff
-- ends first. A shout is cast with no target. With now set (the click itself, or the mouse over it) the group is looked at afresh, else the look the
-- tracker was drawn from is taken.
function ns.TrackerGroupChoice(entry, now)
	if type(entry) ~= "table" or entry.kind ~= "group" or not Grouped() or not Open() or not Knows(entry.spells) then
		return nil
	end
	local name = SpellName(entry.cast)
	if not name then
		return nil
	end
	local read
	if now then
		read = Scan(entry)
		S.read[entry.id] = read
	else
		read = Fresh(entry)
	end
	local lowTime = ns.TrackerValue(entry, "lowTime")
	local low = read.soonest and Plain(lowTime, "number") and lowTime > 0 and read.soonest.expires - Now() <= lowTime
	if read.missing == 0 and not low then
		return nil
	end
	if entry.party then
		return { type = "spell", spell = name }, ("casts %s on your party"):format(name)
	end
	local unit
	local range = type(C_Spell) == "table" and C_Spell.IsSpellInRange
	for _, each in ipairs(read.lacking) do
		if not unit and Ask(range, name, each) == true then
			unit = each
		end
	end
	unit = unit or read.lacking[1] or (low and read.soonest.unit) or nil
	if not unit then
		return nil
	end
	return { type = "spell", spell = name, unit = unit }, ("casts %s on %s"):format(name, UnitLabel(unit))
end

-- The lines of Add a check: each group buff of the class that the player knows.
if type(ns.TrackerAddPicks) == "function" then
	ns.TrackerAddPicks(function()
		local rows = {}
		for _, family in ipairs(Families()) do
			if Knows(family.ids) then
				rows[#rows + 1] = { "group", family.key, K.PICK:format(SpellName(family.cast) or family.label) }
			end
		end
		return rows
	end)
end

if type(ns.TrackerKind) == "function" then
	ns.TrackerKind("group", {
		Read = Read, Clean = Clean, Add = Add, Label = Label, Icon = Icon, Lines = Lines, Wanted = Wanted, Count = Count, Gone = Gone,
		World = Old, what = "group buff",
	})
end
