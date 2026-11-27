local _, ns = ...

local KEY = "trackers"
local IsSecret = ns.IsSecret

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
		PALADIN = {
			{ key = "might", label = "Blessing of Might", cast = 19740, ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 },
				blessing = true },
			{ key = "wisdom", label = "Blessing of Wisdom", cast = 19742, ids = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 },
				blessing = true },
			{ key = "kings", label = "Blessing of Kings", cast = 20217, ids = { 20217, 25898 }, blessing = true },
			{ key = "salvation", label = "Blessing of Salvation", cast = 1038, ids = { 1038, 25895 }, check = true },
			{ key = "light", label = "Blessing of Light", cast = 19977, ids = { 19977, 19978, 19979, 25890 }, blessing = true, check = true },
		},
	},
	PICK = "Group buff: %s",
	MAX_UNITS = 40, MAX_NAMES = 5, MAX_ID = 2147483647, MAX_SPELLS = 40, MAX_NAME = 40, RECHECK = 5,
	NO_AURAS = "Trackers: the game gives no buff information of other units, so group buff trackers show a grey icon.",
}
local S = { read = {}, frame = nil, heard = nil }
local EVENTS = { roster = { "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }, all = { "UNIT_AURA", "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_PHASE" } }

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Plain(value, "number") and value >= 1 and value <= K.MAX_ID and value == math.floor(value)
end

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

local function Knows(ids)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	for _, id in ipairs(ids or {}) do
		if Ask(book.IsSpellKnown, id) == true or Ask(book.IsSpellKnownOrInSpellBook, id) == true then
			return true
		end
	end
	return false
end

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

local function Others(entry)
	local own, others = false, {}
	for _, family in ipairs(Families()) do
		if family.blessing then
			local mine = false
			for _, id in ipairs(family.ids) do
				mine = mine or id == entry.cast
			end
			if mine then
				own = true
			else
				others[#others + 1] = family
			end
		end
	end
	if not own then
		return nil
	end
	local names = {}
	for _, family in ipairs(others) do
		for _, name in ipairs(Names(family.ids)) do
			names[#names + 1] = name
		end
	end
	return names
end

local function Grouped()
	return Ask(IsInGroup) == true
end

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

local function Units()
	local units = {}
	if Ask(IsInRaid) == true then
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

local function Has(entry, unit, others)
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
		for _, name in ipairs(not failed and others or {}) do
			local ok, aura = pcall(auras.GetAuraDataBySpellName, unit, name, "HELPFUL|PLAYER")
			if not ok or IsSecret(aura) then
				failed = true
			elseif type(aura) == "table" then
				return true, nil
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

local function Sight(entry, unit, counts, others)
	if not counts then
		return "out"
	end
	local has, aura = Has(entry, unit, others)
	if has ~= true then
		return tostring(has), has
	end
	local expires, length = Field(aura, "expirationTime"), Field(aura, "duration")
	expires, length = Plain(expires, "number") and expires or nil, Plain(length, "number") and length or nil
	return ("on %s %s"):format(tostring(expires), tostring(length)), true, expires, length
end

local function Scan(entry)
	local read = { missing = 0, total = 0, lacking = {}, seen = {}, entry = entry, others = Others(entry), time = Now(), fresh = true }
	for _, unit in ipairs(Units()) do
		local seen, has, expires, length = Sight(entry, unit, Counts(unit), read.others)
		read.seen[unit] = seen
		if has == false then
			read.missing, read.total = read.missing + 1, read.total + 1
			read.lacking[#read.lacking + 1] = unit
		elseif has == true then
			read.total = read.total + 1
			if expires and expires > 0 and length and length > 0 and (not read.soonest or expires < read.soonest.expires) then
				read.soonest = { unit = unit, expires = expires, length = length }
			end
		end
	end
	return read
end

local function Fresh(entry)
	local read = S.read[entry.id]
	if not (read and read.fresh) then
		read = Scan(entry)
		S.read[entry.id] = read
	end
	return read
end

local function Old()
	for _, read in pairs(S.read) do
		read.fresh = false
	end
end

local function Stale()
	Old()
	if type(ns.TrackerDirty) == "function" then
		ns.TrackerDirty()
	end
end

local function Member(unit)
	return unit == "player" or (unit:find("^party%d+$") ~= nil) or (unit:find("^raid%d+$") ~= nil)
end

local function Changed(unit)
	local now, counts, kept = Now(), nil, false
	for _, read in pairs(S.read) do
		kept = true
		if not read.fresh or now - read.time >= K.RECHECK then
			return true
		end
		local seen = read.seen[unit]
		if seen ~= nil then
			if counts == nil then
				counts = Counts(unit)
			end
			if Sight(read.entry, unit, counts, read.others) ~= seen then
				return true
			end
		end
	end
	return not kept
end

local function OnEvent(_, event, unit)
	if not ns.Enabled(KEY) then
		return
	end
	if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
		Stale()
	elseif InCombatLockdown() or not (IsSecret(unit) or (type(unit) == "string" and Member(unit))) then
		return
	elseif not Open() then
		Old()
	elseif IsSecret(unit) or Changed(unit) then
		Stale()
	end
end

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
		local lowTime = ns.TrackerLowTime(entry, soonest.length)
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

local function Clean(entry)
	if ns.TrackerCleanSpells(entry) ~= true or #entry.spells == 0 then
		return false
	end
	if not Whole(entry.cast) then
		entry.cast = entry.spells[1]
	end
	return true
end

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
	return { name = name, names = names, spells = spells, cast = family.cast }
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

local function Wanted()
	if not Grouped() then
		return 0
	end
	return nil
end

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

local function ClassLabel(unit)
	local label = UnitLabel(unit)
	local class = Ask(UnitClassBase, unit)
	local colours = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS or nil
	local colour = Plain(class, "string") and colours and colours[class] or nil
	if type(colour) ~= "table" then
		return label
	end
	local r, g, b = colour.r, colour.g, colour.b
	if not (ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		return label
	end
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x%s|r"):format(Byte(r), Byte(g), Byte(b), label)
end

local function Who(read)
	local names = {}
	for index, unit in ipairs(read.lacking) do
		if index > K.MAX_NAMES then
			names[#names + 1] = ("%d more"):format(#read.lacking - K.MAX_NAMES)
			break
		end
		names[#names + 1] = ClassLabel(unit)
	end
	return #names > 0 and (" (" .. table.concat(names, ", ") .. ")") or ""
end

local function Lines(entry)
	if not Grouped() then
		return { "Group buff: not in a group, so it is hidden." }
	end
	local read = S.read[entry.id]
	if not read then
		return { "Group buff: not read yet. Other members are read out of combat only." }
	end
	local blessing = Others(entry) and " A member with another of your blessings counts as having it." or ""
	return { ("Group buff: %d of %d lack it%s.%s Other members are read out of combat only."):format(read.missing, read.total, Who(read), blessing) }
end

local function Tip(entry)
	local read = Grouped() and S.read[entry.id]
	if not read then
		return { "Not read yet: the others are read out of combat only." }
	elseif read.missing == 0 then
		return { ("All %d have it."):format(read.total) }
	end
	return { ("%d of %d lack it%s."):format(read.missing, read.total, Who(read)) }
end

local function Gone(id)
	S.read[id] = nil
	for _, entry in ipairs(type(ns.TrackerEntries) == "function" and ns.TrackerEntries() or {}) do
		if entry.kind == "group" and entry.on ~= false and entry.id ~= id and ns.Enabled(KEY) then
			return
		end
	end
	Listen(nil)
end

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
	local lowTime = ns.TrackerLowTime(entry, read.soonest and read.soonest.length)
	local low = read.soonest and Plain(lowTime, "number") and lowTime > 0 and read.soonest.expires - Now() <= lowTime
	if read.missing == 0 and not low then
		return nil
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
		Read = Read, Clean = Clean, Add = Add, Label = Label, Icon = Icon, Lines = Lines, Tip = Tip, Wanted = Wanted, Count = Count, Gone = Gone,
		World = Old, what = "group buff",
	})
end
