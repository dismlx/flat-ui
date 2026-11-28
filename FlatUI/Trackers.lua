local _, ns = ...

local KEY = "trackers"
local MOVER = "FlatUITrackers"
local CROP = 0.08
local GAP = 4
local PASS = 0.2
local UNKNOWN_ICON = 134400
local RED = { 0.851, 0.251, 0.251 }
local RESOURCE_BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local TOTEMS = { "fire", "earth", "water", "air" }
local NO_POSITION = "Trackers: the personal resource display cannot be used, so the row is beside the character."
local NO_SOUND = "Trackers: the game played no sound, so Sound when it drops is silent."
local SWEEP_REFUSED = "Trackers: the game refused to restart a time sweep, so the sweep shows the last known time."
local K = {
	MAX_TRACKERS = 40, MAX_SPELLS = 40, MAX_NAMES = 8, MAX_CHARS = 40, MAX_ID = 2147483647,
	BESIDE = 150, RIM = 2, QUIET = 2, LATE = 5, STEP = 3, TEST = 5, SOUND_FILE = 567397,
	LOW_MAX = { item = 1000, ammo = 2000, durability = 100 },
	PULSE_LOW = 0.35, PULSE_TIME = 0.6, GREY = 0.6, ID_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789",
	AMBER = { 1, 0.7, 0.2 },
	WHITE_RGB = { 1, 1, 1 },
	SHOWS = { always = true, low = true, combat = true },
	MISSING_LOOKS = { red = true, pulse = true, word = true },
	SHOWN_AS = {
		live = "live charges and time",
		game = "the game's own icon",
		last = "last known charges and time",
		none = "a grey icon, no charges or time known yet",
		drawn = "the game's own timer for a totem it hides",
		hidden = "nothing, the tracker is hidden in fights without the game's icon",
	},
	NO_AURAS = "Trackers: the game gives no buff information, so buff trackers show a grey icon.",
	NO_DEBUFFS = "Trackers: the game gives no information on the target's debuffs, so debuff trackers show a grey icon.",
	DEBUFF_FILTER = "HARMFUL|PLAYER",
	NO_PULSE = "Trackers: the game gave no animation, so the missing icon does not pulse.",
	HIDDEN = { state = "unknown", hidden = true },
	KITS = { spell = 23287, chimes = 316736, bell = 316773, warhorn = 316723, raid = 8959, alarm = 12889, whisper = 37666 },
	ORDER = { "resource", "character", "own" },
	WORDS = { place = "place", show = "show", low = "low", lowtime = "lowTime", missing = "missing", sound = "sound", kit = "kit",
		size = "size", x = "x", y = "y", name = "name", on = "on", shape = "shape", colour = "colour", comes = "comes", stacks = "stacks",
		lowsound = "lowSound" },
	where = {},
	extra = {},
	events = {}, registered = {},
	units = {},
	commands = {},
}
local HELP = {
	"/flatui tracker add Lightning Shield - a buff on you, by name, spell ID or shift-clicked spell",
	"/flatui tracker add debuff Corruption - your own debuff on your target",
	"/flatui tracker add weapon main - the enchant on a weapon: main, off or ranged",
	"/flatui tracker add totem fire - a totem slot: fire, earth, water or air",
	"/flatui tracker add pet - your pet, red when it is gone or dead",
	"/flatui tracker add item Healing Potion - an item in your bags, by name, item ID or shift-clicked item",
	"/flatui tracker add ammo - the ammunition you carry",
	"/flatui tracker add tracking - red when no minimap tracking is on",
	"/flatui tracker add form Bear Form - a stance or form, red when you are in none of them",
	"/flatui tracker add durability - your most worn item, red when one is broken",
	"/flatui tracker add proc Shadow Trance for Shadow Bolt - a proc alert: its buff, then the spell it is for",
	"/flatui tracker class - add the usual trackers of your class",
	"/flatui tracker remove 1 - a number from the list, or a name",
	"/flatui tracker back - puts the tracker you last removed back, with its own settings, until you reload",
	"/flatui tracker list",
	"/flatui tracker export - opens Share, to copy every tracker as text",
	"/flatui tracker import - opens Share, to paste trackers",
	"/flatui tracker set 1 low 2 - one tracker's own value for a setting, or clear to use the page's",
	"/flatui tracker set 1 shape bar - icon, bar or text, and colour 4d99e6 for a bar or text",
	"/flatui tracker set 1 happy on - a pet tracker is low while a hunter's pet is not happy",
	"/flatui tracker set 1 health 40 - a pet tracker shows your pet's health in red under 40%, or clear to use the page's",
	"/flatui tracker proc colour 1 ffd100 - one proc's colour, sound (proc sound 1 bell), time (proc time 1 10) or trigger (proc trigger 1 overlay); proc reset 1 puts them back. A proc of your class also goes by its name",
	"/flatui tracker check - what each tracker shows and why, and what happened in the last fight",
	"/flatui tracker check sound - the game's own sound when a tracked buff ends, until /reload",
	"/flatui tracker test - each look for 3 seconds: fine, low, missing, then the game's own look",
}

local IsSecret = ns.IsSecret

local KINDS = {}

local function Part(name)
	local kind = KINDS[name]
	return kind and type(kind.part) == "string" and kind.part or name
end

local BUFF_SLOT = { unit = "player", filter = "HELPFUL" }
local function SlotSpec(entry)
	if entry.kind == nil or entry.kind == "buff" then
		return BUFF_SLOT
	end
	local kind = KINDS[entry.kind]
	return kind and type(kind.slot) == "table" and kind.slot or nil
end
function ns.TrackerSlotSpec(entry)
	return type(entry) == "table" and SlotSpec(entry) or nil
end

local holders = {}
local records, free, shown = {}, {}, {}
local mem = { kept = {}, lengths = {}, drops = {}, woken = {}, cast = {}, found = {} }
local testing = {}
local fight
local fighting = false
local entered, lastPass = nil, -100
local waiting, edited, layoutQueued = false, false, false
local tracked = 0
local watcher, scratch
local heard, bookIds
local gameSound
local testRun = 0
local Dirty, QueueLayout

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
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

local function Field(object, key)
	local ok, value = pcall(function()
		return object[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= K.MAX_ID and value == math.floor(value)
end

local function Positive(value)
	if Plain(value, "number") and value > 0 then
		return value
	end
	return nil
end

local function SpellName(spellID)
	local name = Ask(C_Spell and C_Spell.GetSpellName, spellID)
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

local function SpellIcon(spellID)
	local file = Ask(C_Spell and C_Spell.GetSpellTexture, spellID)
	if Plain(file, "number") or Plain(file, "string") then
		return file
	end
	return UNKNOWN_ICON
end

local function Plural(number, noun)
	return ("%d %s%s"):format(number, noun, number == 1 and "" or "s")
end

local function Now()
	local ok, now = pcall(GetTime)
	if ok and Plain(now, "number") then
		return now
	end
	return 0
end

local function Slot(name, ...)
	local slots = ns.TrackerSlots
	local call = type(slots) == "table" and slots[name]
	if type(call) ~= "function" then
		return nil
	end
	local first = ...
	if IsSecret(first) then
		return call(...)
	end
	if name == "Sync" and type(first) == "table" then
		local buffs = {}
		for _, entry in ipairs(first) do
			if SlotSpec(entry) ~= nil then
				buffs[#buffs + 1] = entry
			end
		end
		return call(buffs)
	elseif type(first) == "table" and first.kind ~= nil and SlotSpec(first) == nil then
		return nil
	end
	return call(...)
end

local function Chars(text)
	return #(text:gsub("[\128-\191]", ""))
end

local function CleanText(text)
	if Plain(text, "string") then
		local length = Chars(text)
		if length >= 1 and length <= K.MAX_CHARS then
			return text
		end
	end
	return nil
end

local OWN = {
	show = function(value)
		return K.SHOWS[value] == true
	end,
	low = function(value, entry)
		local top = entry and K.LOW_MAX[entry.kind] or 20
		return Plain(value, "number") and value >= 0 and value <= top and value == math.floor(value)
	end,
	lowTime = function(value)
		return Plain(value, "number") and value >= 0 and value <= 1800 and value % 5 == 0
	end,
	missing = function(value)
		return K.MISSING_LOOKS[value] == true
	end,
	sound = function(value)
		return type(value) == "boolean"
	end,
	comes = function(value)
		return type(value) == "boolean"
	end,
	stacks = function(value)
		return type(value) == "boolean"
	end,
	lowSound = function(value)
		return type(value) == "boolean"
	end,
	size = function(value)
		return Plain(value, "number") and value >= 16 and value <= 64 and value % 2 == 0
	end,
	place = function(value)
		return value == "resource" or value == "character" or value == "own"
	end,
	x = function(value)
		return Plain(value, "number") and value >= -800 and value <= 800 and value == math.floor(value)
	end,
	y = function(value)
		return Plain(value, "number") and value >= -800 and value <= 800 and value == math.floor(value)
	end,
	kit = function(value)
		return K.KITS[value] ~= nil
	end,
	mark = function(value)
		return type(value) == "boolean"
	end,
	shape = function(value)
		return value == "icon" or value == "bar" or value == "text"
	end,
	colour = function(value)
		return Plain(value, "string") and #value == 8 and value:find("^%x+$") ~= nil
	end,
}

local function Valid(key, value, entry)
	local kind = entry and KINDS[entry.kind]
	local own = kind and type(kind.own) == "table" and kind.own[key]
	if type(own) == "function" then
		return own(value, entry)
	end
	return OWN[key](value, entry)
end

local function NewId(taken)
	local id
	repeat
		id = ""
		for _ = 1, 6 do
			local at = math.random(1, #K.ID_CHARS)
			id = id .. K.ID_CHARS:sub(at, at)
		end
	until not taken[id]
	return id
end

local function SameList(old, clean)
	if type(old) ~= "table" or #old ~= #clean then
		return false
	end
	for index, value in ipairs(clean) do
		if old[index] ~= value then
			return false
		end
	end
	for key in pairs(old) do
		if clean[key] == nil then
			return false
		end
	end
	return true
end

local function CleanCommon(entry, taken)
	local id = entry.id
	if not (type(id) == "string" and #id == 6 and id:find("^[a-z0-9]+$") and not taken[id]) then
		id = NewId(taken)
	end
	taken[id] = true
	entry.id = id
	if entry.charged ~= true then
		entry.charged = nil
	end
	if entry.chargesField ~= true then
		entry.chargesField = nil
	end
	if not Whole(entry.seen) then
		entry.seen = nil
	end
	if not (Whole(entry.top) and entry.top <= 20) then
		entry.top = nil
	end
	if entry.on ~= false then
		entry.on = nil
	end
	for key in pairs(OWN) do
		if entry[key] ~= nil and not Valid(key, entry[key], entry) then
			entry[key] = nil
		end
	end
end

local function CleanSpells(entry)
	local spells, seenSpell = {}, {}
	if type(entry.spells) == "table" then
		for _, id in ipairs(entry.spells) do
			if Whole(id) and not seenSpell[id] and #spells < K.MAX_SPELLS then
				seenSpell[id] = true
				spells[#spells + 1] = id
			end
		end
	end
	local name = CleanText(entry.name)
	if not name and #spells == 0 then
		return false
	end
	local names, seenName = {}, {}
	if type(entry.names) == "table" then
		for _, text in ipairs(entry.names) do
			if CleanText(text) and not seenName[text] and #names < K.MAX_NAMES then
				seenName[text] = true
				names[#names + 1] = text
			end
		end
	end
	if #names == 0 and name then
		names[1] = name
	end
	if not SameList(entry.spells, spells) then
		entry.spells = spells
	end
	if not SameList(entry.names, names) then
		entry.names = names
	end
	entry.name = name
	return true
end
ns.TrackerCleanSpells = CleanSpells

local function CleanBuff(entry, taken, kind)
	if not CleanSpells(entry) then
		return false
	end
	entry.kind = kind or "buff"
	if taken then
		CleanCommon(entry, taken)
	end
	return true
end
ns.TrackerCleanBuff = CleanBuff

local function List()
	local saved = ns.Character()
	if not saved then
		return {}
	end
	local old = saved.trackers
	local list, taken, dropped = {}, {}, false
	if type(old) == "table" then
		for _, entry in ipairs(old) do
			if type(entry) == "table" and entry.kind ~= nil and entry.kind ~= "buff" and not KINDS[entry.kind] and type(entry.id) == "string" then
				taken[entry.id] = true
			end
		end
		for _, entry in ipairs(old) do
			local kind = type(entry) == "table" and KINDS[entry.kind]
			if #list >= K.MAX_TRACKERS or type(entry) ~= "table" then
				dropped = true
			elseif kind then
				if Ask(kind.Clean, entry) == true then
					CleanCommon(entry, taken)
					list[#list + 1] = entry
				else
					dropped = true
				end
			elseif entry.kind ~= nil and entry.kind ~= "buff" then
				list[#list + 1] = entry
			elseif CleanBuff(entry, taken) then
				list[#list + 1] = entry
			else
				dropped = true
			end
		end
		if not dropped and SameList(old, list) then
			return old
		end
	end
	saved.trackers = list
	return list
end

local function Entries()
	local entries = {}
	for _, entry in ipairs(List()) do
		if entry.kind == "buff" or KINDS[entry.kind] then
			entries[#entries + 1] = entry
		end
	end
	return entries
end

local function Buffs()
	local buffs = {}
	for _, entry in ipairs(Entries()) do
		if entry.kind == "buff" then
			buffs[#buffs + 1] = entry
		end
	end
	return buffs
end

function K.Auto(entries)
	if type(ns.ProcAutoEntries) ~= "function" then
		return {}
	end
	local ok, auto = pcall(ns.ProcAutoEntries, entries)
	return ok and type(auto) == "table" and auto or {}
end

local function OnEntries()
	local on, entries = {}, Entries()
	for _, entry in ipairs(entries) do
		if entry.on ~= false then
			on[#on + 1] = entry
		end
	end
	for _, entry in ipairs(K.Auto(entries)) do
		on[#on + 1] = entry
	end
	return on
end

local function Value(entry, key)
	local own = entry[key]
	if own ~= nil then
		return own
	end
	return ns.Get(KEY .. "." .. key)
end
ns.TrackerValue = Value
ns.TrackerKits = K.KITS

K.LONG, K.LASTING, K.TIMED, K.inside, K.gap = 600, { buff = true, weapon = true, group = true },
	{ buff = true, debuff = true, weapon = true, totem = true, group = true }, nil, {}

function K.Inside()
	if K.inside == nil or not ns.Enabled(KEY) then
		local ok, inside, kind = pcall(IsInInstance)
		K.inside = ok and not IsSecret(inside) and inside == true and not IsSecret(kind) and (kind == "party" or kind == "raid") and kind or false
	end
	return K.inside
end

function K.LowTime(entry, length)
	local own = Value(entry, "lowTime")
	own = Plain(own, "number") and own or 0
	local deep = Opt("lowTimeInstance")
	if not (Plain(deep, "number") and deep > own and K.LASTING[entry.kind]) then
		return own
	end
	length = length or mem.lengths[entry.id]
	if not (Plain(length, "number") and length >= K.LONG) then
		return own
	end
	local inside = K.Inside()
	if not inside then
		return own
	end
	return deep, inside == "raid" and "raid" or "dungeon"
end
ns.TrackerLowTime = K.LowTime

local function Label(entry)
	local kind = KINDS[entry.kind]
	local text = kind and Ask(kind.Label, entry)
	if Plain(text, "string") and text ~= "" then
		return text
	end
	if entry.name then
		return entry.name
	end
	local first = entry.spells and entry.spells[1]
	return first and SpellName(first) or ("Spell " .. tostring(first))
end
ns.TrackerLabel = Label

local function EntryIcon(entry)
	local id = entry.seen or (entry.spells and entry.spells[1])
	if id then
		return SpellIcon(id)
	end
	local kind = KINDS[entry.kind]
	local icon = kind and Ask(kind.Icon, entry)
	return (Plain(icon, "number") or Plain(icon, "string")) and icon or UNKNOWN_ICON
end

local function Forget(id)
	for _, memory in pairs(mem) do
		memory[id] = nil
	end
end

local function Parse(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

local function ClassInfo()
	if type(UnitClass) ~= "function" then
		return nil, nil
	end
	local ok, name, token = pcall(UnitClass, "player")
	if not ok then
		return nil, nil
	end
	return Plain(name, "string") and name ~= "" and name or nil, Plain(token, "string") and token ~= "" and token or nil
end

local function ClassList()
	local _, token = ClassInfo()
	local lists = ns.ClassTrackers
	if type(lists) == "table" and token and type(lists[token]) == "table" then
		return lists[token]
	end
	return {}
end

local function ClassIds(name)
	local wanted, ids = name:lower(), {}
	for _, row in ipairs(ClassList()) do
		if row.kind == "buff" then
			for _, id in ipairs(row.spells or {}) do
				local known = SpellName(id)
				if known and known:lower() == wanted then
					ids[#ids + 1] = id
				end
			end
		end
	end
	return #ids > 0 and ids or nil
end

local function Resolve(text)
	text = text:match("^%s*(.-)%s*$")
	local id = Parse(text)
	if not id and text ~= "" then
		local info = Ask(C_Spell and C_Spell.GetSpellInfo, text)
		if type(info) == "table" then
			id = info.spellID
		end
	end
	if not id and text ~= "" then
		for _, listed in ipairs(ClassIds(text) or {}) do
			if SpellName(listed) then
				id = listed
				break
			end
		end
	end
	if Whole(id) and SpellName(id) then
		return id
	end
	return nil
end

ns.TrackerResolve = Resolve

local function SpellBook()
	local book = C_SpellBook
	if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
		and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType then
		return book
	end
	return nil
end

local function WalkBook(book, visit)
	local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
	local lines = Ask(book.GetNumSpellBookSkillLines)
	for line = 1, Plain(lines, "number") and lines or 0 do
		local skill = Ask(book.GetSpellBookSkillLineInfo, line)
		if type(skill) == "table" and skill.shouldHide ~= true and skill.offSpecID == nil
			and Plain(skill.itemIndexOffset, "number") and Plain(skill.numSpellBookItems, "number") then
			for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
				local item = Ask(book.GetSpellBookItemInfo, slot, bank)
				if type(item) == "table" and item.itemType == spellType and item.isPassive ~= true and item.isOffSpec ~= true then
					local id = item.spellID or item.actionID
					if Whole(id) then
						visit(slot, id, item, bank)
					end
				end
			end
		end
	end
end

local function Castable(entry)
	if bookIds == nil then
		local book, ids = SpellBook(), {}
		if book then
			WalkBook(book, function(_, id)
				ids[id] = true
			end)
		end
		if next(ids) == nil then
			return false
		end
		bookIds = ids
	end
	for _, id in ipairs(entry.spells) do
		if bookIds[id] then
			return true
		end
	end
	return false
end

local function Lists(entry, spellID, name)
	for _, id in ipairs(entry.spells) do
		if id == spellID then
			return true
		end
	end
	for _, text in ipairs(entry.names) do
		if text == name then
			return true
		end
	end
	return entry.name == name
end

local function Learn(entry, spellID, byName)
	for _, id in ipairs(entry.spells) do
		if id == spellID then
			return false
		end
	end
	if #entry.spells >= K.MAX_SPELLS then
		return false
	end
	entry.spells[#entry.spells + 1] = spellID
	edited = true
	if byName then
		local ids = mem.found[entry.id] or {}
		ids[#ids + 1] = spellID
		mem.found[entry.id] = ids
	end
	return true
end

local function KnowsAny(ids)
	local book = C_SpellBook
	for _, id in ipairs(ids or {}) do
		for _, call in ipairs({ "IsSpellKnownOrInSpellBook", "IsSpellKnown" }) do
			if book and Ask(book[call], id) == true then
				return true
			end
		end
	end
	return Castable({ spells = ids or {} })
end

local function CarriesAny(ids)
	for _, id in ipairs(ids or {}) do
		local count = Ask(type(C_Item) == "table" and C_Item.GetItemCount, id, false, true)
		if Plain(count, "number") and count > 0 then
			return true
		end
	end
	return false
end

local function CopyEntry(row, id)
	local entry = { id = id }
	for key, value in pairs(row) do
		if type(value) == "table" then
			local copy = {}
			for index, item in ipairs(value) do
				copy[index] = item
			end
			value = copy
		end
		entry[key] = value
	end
	return entry
end

local function FirstOf(row)
	return (row.spells or row.items or row.apply or row.summon or {})[1]
end

local function OnList(list, row)
	local first = FirstOf(row)
	for _, entry in ipairs(list) do
		if entry.name == row.name or (entry.kind == row.kind and (row.kind == "ammo" or (row.slot ~= nil and entry.slot == row.slot))) then
			return true
		end
		if entry.kind == row.kind and first ~= nil then
			for _, key in ipairs({ "spells", "items" }) do
				for _, id in ipairs(type(entry[key]) == "table" and entry[key] or {}) do
					if id == first then
						return true
					end
				end
			end
		end
	end
	return false
end

local function Missing(row)
	if row.kind == "item" then
		if not CarriesAny(row.items) then
			return "no item in the bags"
		end
	elseif row.kind == "buff" or row.kind == "form" or row.kind == "totem" then
		if not KnowsAny(row.spells) then
			return row.kind == "totem" and "no totem known" or "no spell known"
		end
	end
	return nil
end

function ns.TrackerClassCandidates()
	local rows = {}
	local list = ClassList()
	if #list > 0 then
		rows[1] = { 1, "All" }
	end
	for index, row in ipairs(list) do
		rows[#rows + 1] = { index + 1, row.name }
	end
	return rows
end

function ns.TrackerAddClass(pick)
	local data = ClassList()
	local wanted = {}
	for index, row in ipairs(data) do
		if pick == 1 or pick == index + 1 then
			wanted[#wanted + 1] = row
		end
	end
	if #wanted == 0 then
		return false, "No class trackers."
	end
	local list = List()
	local taken = {}
	for _, other in ipairs(list) do
		if type(other.id) == "string" then
			taken[other.id] = true
		end
	end
	local added, skipped, have, full = 0, {}, {}, false
	for _, row in ipairs(wanted) do
		local why = Missing(row)
		if OnList(list, row) then
			have[#have + 1] = row.name
		elseif #list >= K.MAX_TRACKERS then
			full = true
			break
		elseif why then
			skipped[#skipped + 1] = ("%s, %s."):format(row.name, why)
		else
			local entry = CopyEntry(row, NewId(taken))
			taken[entry.id] = true
			list[#list + 1] = entry
			added = added + 1
		end
	end
	local parts = { added > 0 and ("Added %s."):format(Plural(added, "tracker")) or "No trackers added." }
	if #skipped > 0 then
		parts[#parts + 1] = "Skipped: " .. table.concat(skipped, " ")
	end
	if #have > 0 then
		parts[#parts + 1] = "Already tracked: " .. table.concat(have, ", ") .. "."
	end
	if full then
		parts[#parts + 1] = ("%d trackers is the most."):format(K.MAX_TRACKERS)
	end
	if added > 0 then
		QueueLayout()
		K.RowPreview()
	end
	return added > 0, table.concat(parts, " ")
end

function ns.TrackerAddBuff(spellID)
	local name = Whole(spellID) and SpellName(spellID)
	if not name then
		return false, ('No spell found for "%s".'):format(tostring(spellID))
	end
	for _, entry in ipairs(Buffs()) do
		if Lists(entry, spellID, name) then
			return false, ("%s is already tracked."):format(name)
		end
	end
	local list = List()
	if #list >= K.MAX_TRACKERS then
		return false, ("%d trackers is the most."):format(K.MAX_TRACKERS)
	end
	local taken = {}
	for _, other in ipairs(list) do
		if type(other.id) == "string" then
			taken[other.id] = true
		end
	end
	local entry = { id = NewId(taken), kind = "buff", name = name, names = { name }, spells = { spellID } }
	local book = SpellBook()
	if book then
		WalkBook(book, function(_, id)
			if SpellName(id) == name then
				Learn(entry, id, false)
			end
		end)
	end
	for _, id in ipairs(ClassIds(name) or {}) do
		Learn(entry, id, false)
	end
	list[#list + 1] = entry
	edited = false
	QueueLayout()
	K.RowPreview()
	return true, ("Added %s."):format(name)
end

function ns.TrackerRankIDs(spellID)
	local ids, name = { spellID }, Whole(spellID) and SpellName(spellID)
	local book = SpellBook()
	if book and name then
		WalkBook(book, function(_, id)
			if id ~= spellID and SpellName(id) == name and #ids < K.MAX_SPELLS then
				ids[#ids + 1] = id
			end
		end)
	end
	return ids
end

function ns.TrackerAddKind(kind, argument)
	local spec = KINDS[kind]
	if not spec or type(spec.Add) ~= "function" then
		return false, ('No kind of tracker called "%s".'):format(tostring(kind))
	end
	local ok, fields, message = pcall(spec.Add, argument, Entries())
	if not ok then
		return false, "Not added."
	elseif type(fields) ~= "table" then
		return false, Plain(message, "string") and message or "Not added."
	end
	local list = List()
	if #list + 1 > K.MAX_TRACKERS then
		return false, ("%d trackers is the most."):format(K.MAX_TRACKERS)
	end
	local taken = {}
	for _, other in ipairs(list) do
		if type(other.id) == "string" then
			taken[other.id] = true
		end
	end
	fields.id, fields.kind = NewId(taken), kind
	list[#list + 1] = fields
	QueueLayout()
	K.RowPreview()
	return true, Plain(message, "string") and message or "Added."
end

function ns.TrackerBuffCandidates()
	local rows = {}
	local book = SpellBook()
	if not book then
		return rows
	end
	local named = {}
	for _, entry in ipairs(Buffs()) do
		for _, text in ipairs(entry.names) do
			named[text] = true
		end
		if entry.name then
			named[entry.name] = true
		end
	end
	local helpful = C_Spell and C_Spell.IsSpellHelpful
	WalkBook(book, function(slot, id, item, bank)
		if Ask(book.IsSpellBookItemLowRank, slot, bank) == true then
			return
		end
		local label = SpellName(id) or (Plain(item.name, "string") and item.name ~= "" and item.name or nil)
		if label and not named[label] and (type(helpful) ~= "function" or Ask(helpful, id) == true) then
			named[label] = true
			rows[#rows + 1] = { id, label }
		end
	end)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	return rows
end

function ns.TrackerDebuffCandidates()
	local rows, named, book = {}, {}, SpellBook()
	if not book then
		return rows
	end
	for _, entry in ipairs(Entries()) do
		for _, text in ipairs(entry.kind == "debuff" and entry.names or {}) do
			named[text] = true
		end
	end
	WalkBook(book, function(slot, id, _, bank)
		local label = SpellName(id)
		if not label or named[label] or Ask(book.IsSpellBookItemLowRank, slot, bank) == true then
			return
		end
		if Ask(C_Spell and C_Spell.IsSpellHarmful, id) == true then
			named[label] = true
			rows[#rows + 1] = { id, label }
		end
	end)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	return rows
end

function ns.TrackerRanks(name)
	local ids, book = {}, SpellBook()
	if book then
		WalkBook(book, function(_, id)
			if SpellName(id) == name then
				ids[#ids + 1] = id
			end
		end)
	end
	return ids
end

function ns.TrackerUnkeep(id)
	mem.kept[id], mem.drops[id] = nil, nil
end

function ns.TrackerPicked()
	local rows = {}
	for position, entry in ipairs(Entries()) do
		rows[#rows + 1] = { position, Label(entry) }
	end
	return rows
end

function ns.TrackerRemove(position)
	local entry = Whole(position) and Entries()[position]
	if not entry then
		return false, ("No tracker numbered %s."):format(tostring(position))
	end
	local list = List()
	for index, other in ipairs(list) do
		if other == entry then
			table.remove(list, index)
			table.insert(K.removed, 1, { entry = entry, index = index })
			K.removed[K.REMOVED_MOST + 1] = nil
			break
		end
	end
	QueueLayout()
	K.RowPreview()
	return true, ("Removed %s. Bring back a tracker puts it back until you reload."):format(Label(entry))
end

K.removed, K.REMOVED_MOST = {}, 5

function ns.TrackerRemovedLines()
	local rows = {}
	for index, removed in ipairs(K.removed) do
		rows[#rows + 1] = { index, Label(removed.entry) }
	end
	return rows
end

function ns.TrackerBringBack(index)
	local removed = Whole(index) and K.removed[index]
	if not removed then
		return false, #K.removed == 0 and "No tracker was removed since you logged in or reloaded." or ("No removed tracker numbered %s."):format(tostring(index))
	end
	local entry, list = removed.entry, List()
	local label = Label(entry)
	if #list >= K.MAX_TRACKERS then
		return false, ("%d trackers is the most."):format(K.MAX_TRACKERS)
	end
	local taken = {}
	for _, other in ipairs(list) do
		if type(other.id) == "string" then
			taken[other.id] = true
		end
		if other.kind == entry.kind and Label(other) == label then
			return false, ("%s is already tracked."):format(label)
		end
	end
	if type(entry.id) ~= "string" or taken[entry.id] then
		entry.id = NewId(taken)
	end
	table.remove(K.removed, index)
	table.insert(list, math.min(removed.index, #list + 1), entry)
	QueueLayout()
	K.RowPreview()
	return true, ("%s is back."):format(label)
end

ns.TrackerOwnKeys = OWN
function ns.TrackerLayout()
	QueueLayout()
end

local function PageRow(key)
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			if item.path == KEY .. "." .. key then
				return item
			end
		end
	end
end

local function Shown(key, value)
	local row = PageRow(key)
	if type(value) == "boolean" then
		return value and "on" or "off"
	end
	if row and row.kind == "choice" then
		for _, choice in ipairs(row.choices) do
			if choice[1] == value then
				return choice[2]
			end
		end
	end
	return tostring(value)
end

local function Typed(key, text)
	local row = PageRow(key)
	local lower = text:lower()
	if key == "name" then
		return CleanText(text)
	elseif key == "on" or (row and row.kind == "bool") then
		if lower == "on" or lower == "true" or lower == "yes" then
			return true
		elseif lower == "off" or lower == "false" or lower == "no" then
			return false
		end
	elseif row and row.kind == "number" then
		return tonumber(text)
	elseif row and row.kind == "colour" then
		local hex = lower:gsub("^#", "")
		if #hex == 6 then
			hex = "ff" .. hex
		end
		return hex
	elseif row and row.kind == "choice" then
		for _, choice in ipairs(row.choices) do
			if lower == choice[1] or lower == choice[2]:lower() then
				return choice[1]
			end
		end
	end
	return nil
end

function ns.TrackerSet(index, word, text)
	local entry = Whole(index) and Entries()[index]
	if not entry then
		return false, ("No tracker numbered %s."):format(tostring(index))
	end
	word = Plain(word, "string") and word:lower() or ""
	text = Plain(text, "string") and text:match("^%s*(.-)%s*$") or ""
	local function Done(message, look)
		edited = true
		QueueLayout()
		Dirty()
		K.OwnPreview(entry, look)
		return true, message
	end
	if word == "clear" and text == "" then
		for key in pairs(OWN) do
			entry[key] = nil
		end
		entry.happy, entry.health = nil, nil
		return Done(("Tracker %d: every setting follows the pages."):format(index), "shape")
	end
	if word == "clear" then
		word, text = text:lower(), "clear"
	end
	if word == "happy" then
		local value = text:lower()
		if entry.kind ~= "pet" then
			return false, ("Tracker %d: happy is a setting of the pet tracker."):format(index)
		elseif value == "on" or value == "yes" or value == "true" then
			entry.happy = true
			return Done(("Tracker %d: happy is on."):format(index))
		elseif value == "off" or value == "no" or value == "false" or value == "clear" then
			entry.happy = nil
			return Done(("Tracker %d: happy is off."):format(index))
		end
		return false, ('Tracker %d: "%s" is not a value for happy.'):format(index, text)
	end
	if word == "health" then
		local value = tonumber((text:gsub("%%$", "")))
		if entry.kind ~= "pet" then
			return false, ("Tracker %d: health is a setting of the pet tracker."):format(index)
		elseif text:lower() == "clear" then
			entry.health = nil
			return Done(("Tracker %d: health follows the page."):format(index))
		elseif value and value >= 0 and value <= 90 and value == math.floor(value) then
			entry.health = value
			return Done(("Tracker %d: health is %d%%."):format(index, value))
		end
		return false, ('Tracker %d: "%s" is not a value for health, which is 0 to 90.'):format(index, text)
	end
	local key = K.WORDS[word]
	if not key then
		local words = {}
		for name in pairs(K.WORDS) do
			words[#words + 1] = name
		end
		table.sort(words)
		return false, ('"%s" is not a setting. Settings: %s.'):format(word, table.concat(words, ", "))
	end
	if text:lower() == "clear" then
		entry[key] = nil
		return Done(("Tracker %d: %s follows the page."):format(index, word), key)
	end
	local value = Typed(key, text)
	local valid = key == "name" and value ~= nil or key == "on" and type(value) == "boolean" or (OWN[key] and Valid(key, value, entry))
	if not valid then
		return false, ('Tracker %d: "%s" is not a value for %s.'):format(index, text, word)
	end
	if key == "on" and value == true then
		value = nil
	end
	entry[key] = value
	if key == "kit" then
		K.KitWarn(value, entry)
	end
	return Done(("Tracker %d: %s is %s."):format(index, word, text), key)
end

function ns.TrackerEditorRow(key, kind)
	if not (Plain(key, "string") and Plain(kind, "string")) then
		return false
	end
	for _, row in ipairs(K.extra) do
		if row.key == key then
			return true
		end
	end
	K.extra[#K.extra + 1] = { key = key, kind = kind }
	return true
end

function ns.TrackerEditorRows()
	return K.extra
end

function ns.TrackerEditorLines()
	local lines = {}
	for index, entry in ipairs(Entries()) do
		local label = Label(entry)
		lines[index] = { id = entry.id, text = index .. ". " .. label, name = label, lowMax = K.LOW_MAX[entry.kind] or 20, kind = entry.kind }
	end
	return lines
end

function ns.TrackerOwn(index, key)
	local entry = Whole(index) and Entries()[index]
	if entry and Plain(key, "string") then
		return entry[key]
	end
	return nil
end

function ns.TrackerSetOwn(index, key, value)
	local entry = Whole(index) and Entries()[index]
	if not entry then
		return false, ("No tracker numbered %s."):format(tostring(index))
	end
	local function Done()
		edited = true
		QueueLayout()
		Dirty()
		K.OwnPreview(entry, key)
		return true
	end
	if key == "name" then
		local text = Plain(value, "string") and value:match("^%s*(.-)%s*$") or nil
		if text == nil or text == "" then
			if entry.kind == "buff" and #entry.spells == 0 then
				return false, "A tracker with no spell IDs keeps its name."
			end
			entry.name = nil
			return Done()
		end
		if not CleanText(text) then
			return false, ("A name is 1 to %d characters."):format(K.MAX_CHARS)
		end
		entry.name = text
		return Done()
	elseif key == "on" then
		if type(value) ~= "boolean" then
			return false, "On is on or off."
		end
		if value then
			entry.on = nil
		else
			entry.on = false
		end
		return Done()
	elseif key == "spells" then
		if entry.kind ~= "buff" then
			return false, "Spell IDs are for buff trackers."
		end
		local ids, seen = {}, {}
		local text = Plain(value, "string") and value:gsub("|c%x+|Hspell:(%d+)[^|]*|h%[.-%]|h|r", "%1") or nil
		if not text then
			return false, "Spell IDs are numbers separated by commas."
		end
		for token in text:gmatch("[^,%s]+") do
			local id = Parse(token)
			if not id then
				return false, "Spell IDs are numbers separated by commas."
			end
			if not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
		if #ids > K.MAX_SPELLS then
			return false, ("%d spell IDs is the most."):format(K.MAX_SPELLS)
		end
		if #ids == 0 and not entry.name then
			return false, "A tracker needs a spell ID or a name."
		end
		entry.spells = ids
		return Done()
	end
	local judge = OWN[key]
	if not judge then
		return false, ("%s is not a setting of a tracker."):format(tostring(key))
	end
	if value ~= nil and not judge(value, entry) then
		return false, "That value is not allowed for this tracker."
	end
	entry[key] = value
	if key == "kit" and value ~= nil then
		K.KitWarn(value, entry)
	end

	return Done()
end

function ns.TrackerClear(index)
	return ns.TrackerSet(index, "clear", "")
end

function ns.TrackerMove(index, delta)
	local entries = Entries()
	local entry = Whole(index) and entries[index]
	if not entry then
		return false, ("No tracker numbered %s."):format(tostring(index))
	end
	local other = (delta == -1 or delta == 1) and entries[index + delta]
	if not other then
		return false, delta == -1 and "It is the first tracker." or "It is the last tracker."
	end
	local list, at, to = List()
	for position, listed in ipairs(list) do
		if listed == entry then
			at = position
		elseif listed == other then
			to = position
		end
	end
	if not (at and to) then
		return false, ("No tracker numbered %s."):format(tostring(index))
	end
	list[at], list[to] = other, entry
	edited = true
	QueueLayout()
	Dirty()
	K.RowPreview()
	return true
end

local function AurasOpen()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) == "function" then
		local ok, answer = pcall(call)
		return ok and not IsSecret(answer) and answer == false
	end
	return not InCombatLockdown()
end

local function IsHidden(entry)
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldSpellAuraBeSecret
	if type(call) ~= "function" then
		return InCombatLockdown() and true or false
	end
	if #entry.spells == 0 then
		return not AurasOpen()
	end
	for _, id in ipairs(entry.spells) do
		local ok, answer = pcall(call, id)
		if not ok or IsSecret(answer) or answer ~= false then
			return true
		end
	end
	return false
end

local function Answer(ok, found)
	if not ok or IsSecret(found) then
		return false
	end
	if found == nil then
		return nil
	end
	return type(found) == "table" and found or false
end

local function Wake(entry, at)
	if mem.woken[entry.id] == at or not (C_Timer and C_Timer.After) then
		return
	end
	mem.woken[entry.id] = at
	C_Timer.After(math.max(0, at - Now()) + 0.05, function()
		if ns.Enabled(KEY) then
			Dirty()
		end
	end)
end

ns.TrackerWake = Wake

function ns.TrackerBuffOn(ids)
	local units = C_UnitAuras
	if type(units) ~= "table" or type(units.GetPlayerAuraBySpellID) ~= "function" or type(ids) ~= "table" or IsHidden({ spells = ids }) then
		return nil
	end
	local failed = false
	for _, id in ipairs(ids) do
		local found = Answer(pcall(units.GetPlayerAuraBySpellID, id))
		if found == false then
			failed = true
		elseif found then
			return true
		end
	end
	if failed then
		return nil
	end
	return false
end

local function Settle(entry, aura, auraID, failed)
	if not aura then
		return { state = failed and "unknown" or "missing", hidden = false }
	end
	local applications, chargesField = Field(aura, "applications"), Field(aura, "charges")
	local stacks = Plain(applications, "number") and applications or nil
	local charges = Plain(chargesField, "number") and chargesField or nil
	local count = Positive(stacks) or Positive(charges)
	local expires, length = Positive(Field(aura, "expirationTime")), Positive(Field(aura, "duration"))
	local icon = Field(aura, "icon")
	if not (Plain(icon, "number") or Plain(icon, "string")) then
		icon = auraID and SpellIcon(auraID) or EntryIcon(entry)
	end
	if auraID and entry.seen ~= auraID then
		entry.seen = auraID
		edited = true
	end
	if count and count > 1 and not entry.charged then
		entry.charged = true
		edited = true
		if Value(entry, "shape") == "text" then
			QueueLayout()
		end
	end
	if count and (entry.chargesField == true) ~= (Positive(stacks) == nil) then
		entry.chargesField = Positive(stacks) == nil or nil
		edited = true
	end
	local state = "fine"
	local low, lowTime = Value(entry, "low"), K.LowTime(entry, length)
	if entry.charged and low > 0 and count and count <= low then
		state = "low"
	elseif lowTime > 0 and expires then
		if expires - Now() <= lowTime then
			state = "low"
		else
			Wake(entry, expires - lowTime)
		end
	end
	return { state = state, hidden = false, count = count, stacks = stacks, charges = charges, expires = expires, length = length,
		icon = icon, id = auraID }
end

function ns.AuraReading(entry)
	local units = C_UnitAuras
	if type(units) ~= "table" or type(units.GetPlayerAuraBySpellID) ~= "function" then
		ns.Note(KEY, K.NO_AURAS)
		return { state = "unknown", hidden = false }
	end
	if IsHidden(entry) then
		return { state = "unknown", hidden = true }
	end
	local aura, auraID, failed = nil, nil, false
	for _, id in ipairs(entry.spells) do
		local found = Answer(pcall(units.GetPlayerAuraBySpellID, id))
		if found == false then
			failed = true
		elseif found then
			aura, auraID = found, id
			break
		end
	end
	if not aura and not failed and #entry.names > 0 and type(units.GetAuraDataBySpellName) == "function" and AurasOpen() then
		for _, name in ipairs(entry.names) do
			local found = Answer(pcall(units.GetAuraDataBySpellName, "player", name, "HELPFUL"))
			if found == false then
				failed = true
			elseif found then
				aura = found
				local spellID = Field(found, "spellId")
				if Whole(spellID) then
					auraID = spellID
					Learn(entry, spellID, true)
				end
				break
			end
		end
	end
	return Settle(entry, aura, auraID, failed)
end

function ns.TrackerTarget()
	local exists = Ask(UnitExists, "target")
	if exists == nil then
		return nil
	elseif exists ~= true then
		return "none"
	end
	local attack, dead = Ask(UnitCanAttack, "player", "target"), Ask(UnitIsDeadOrGhost, "target")
	if attack == nil or dead == nil then
		return nil
	end
	return (attack == true and dead ~= true) and "attackable" or "none"
end

function K.DebuffByName(entry)
	for _, name in ipairs(entry.names) do
		local found = Answer(pcall(C_UnitAuras.GetAuraDataBySpellName, "target", name, K.DEBUFF_FILTER))
		if found == false then
			return nil, nil, true
		elseif found then
			local spellID = Field(found, "spellId")
			if Whole(spellID) then
				Learn(entry, spellID, true)
				return found, spellID, false
			end
			return found, nil, false
		end
	end
	return nil, nil, false
end

function ns.DebuffReading(entry)
	local units, target = C_UnitAuras, ns.TrackerTarget()
	if target == "none" then
		return { state = "unknown", hidden = false, absent = true }
	elseif type(units) ~= "table" or type(units.GetUnitAuras) ~= "function" then
		ns.Note(KEY, K.NO_DEBUFFS)
		return { state = "unknown", hidden = false }
	elseif target == nil then
		return { state = "unknown", hidden = false }
	elseif IsHidden(entry) then
		return { state = "unknown", hidden = true }
	end
	local aura, auraID, failed = nil, nil, false
	local unread = false
	local list = Answer(pcall(units.GetUnitAuras, "target", K.DEBUFF_FILTER))
	if list == false then
		failed = true
	elseif list then
		local listed = {}
		for _, id in ipairs(entry.spells) do
			listed[id] = true
		end
		for _, found in ipairs(list) do
			local spellID = Field(found, "spellId")
			if Whole(spellID) and listed[spellID] then
				aura, auraID = found, spellID
				break
			elseif not Whole(spellID) then
				unread = true
			end
		end
	end
	failed = failed or (aura == nil and unread)
	local named = false
	if aura == nil and not failed and #entry.names > 0 and type(units.GetAuraDataBySpellName) == "function" and AurasOpen() then
		aura, auraID, failed = K.DebuffByName(entry)
		named = aura ~= nil
	end
	local reading = Settle(entry, aura, auraID, failed)
	reading.found = aura == nil and "nothing" or (named and "name" or "id")
	local source = aura and Field(aura, "sourceUnit")
	reading.source = Plain(source, "string") and source or nil
	return reading
end

local function Read(entry)
	local kind = KINDS[entry.kind]
	if not kind then
		return ns.AuraReading(entry)
	end
	local reading
	ns.EachPart(KEY, Part(entry.kind), function(own)
		reading = kind.Read(own)
	end, entry)
	if type(reading) ~= "table" or type(reading.state) ~= "string" then
		return { state = "unknown", hidden = false }
	end
	if reading.count and not entry.charged then
		entry.charged = true
		local text = Value(entry, "shape") == "text"
		if text then
			QueueLayout()
		end
	end
	return reading
end

local function HolderFor(place, make)
	local key = place == Opt("place") and "page" or place
	local holder = holders[key]
	if not holder and make then
		holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:SetSize(1, 1)
		holders[key] = holder
	end
	return holder
end

local function Acquire(parent)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	local texture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[texture] = true
	texture:SetAllPoints(frame)
	texture:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetSwipeColor(0, 0, 0, 0.7)
	local top = CreateFrame("Frame", nil, frame)
	ns.Own[top] = true
	top:SetAllPoints(frame)
	top:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	ns.Own[count] = true
	count:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
	local word = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ns.Own[word] = true
	word:SetPoint("CENTER", top, "CENTER", 0, 0)
	word:SetText("Missing")
	word:SetShown(false)
	local rim = {}
	for index = 1, 4 do
		local edge = top:CreateTexture(nil, "OVERLAY", nil, 6)
		ns.Own[edge] = true
		if edge.SetSnapToPixelGrid then
			pcall(edge.SetSnapToPixelGrid, edge, false)
		end
		edge:SetColorTexture(RED[1], RED[2], RED[3], 1)
		edge:SetShown(false)
		rim[index] = edge
	end
	local record = { frame = frame, parent = parent, texture = texture, cooldown = cooldown, top = top, count = count, word = word, rim = rim,
		outline = ns.Outline(frame, frame), shape = "icon", parts = {}, refused = {}, groups = {}, tint = "red" }
	pcall(frame.SetMouseClickEnabled, frame, false)
	pcall(frame.SetMouseMotionEnabled, frame, false)
	record.motion = false
	frame:SetScript("OnEnter", function()
		K.TipEnter(record)
	end)
	frame:SetScript("OnLeave", function()
		K.TipLeave(record)
	end)
	record.fade = K.MakeFade(frame)
	return record
end

local function Fit(record, entry)
	local anchor, size, wordHeight = ns.TrackerShapes.Fit(record, entry)
	record.word:SetTextHeight(wordHeight)
	local top, rim = record.top, record.rim
	local thick = ns.Pixels(top, K.RIM)
	rim[1]:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	rim[1]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
	rim[1]:SetHeight(thick)
	rim[2]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
	rim[2]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
	rim[2]:SetHeight(thick)
	rim[3]:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -thick)
	rim[3]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, thick)
	rim[3]:SetWidth(thick)
	rim[4]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, -thick)
	rim[4]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, thick)
	rim[4]:SetWidth(thick)
end

local function MakePulse(texture)
	local ok, group = pcall(function()
		local made = texture:CreateAnimationGroup()
		local alpha = made:CreateAnimation("Alpha")
		alpha:SetFromAlpha(1)
		alpha:SetToAlpha(K.PULSE_LOW)
		alpha:SetDuration(K.PULSE_TIME)
		made:SetLooping("BOUNCE")
		return made
	end)
	return ok and group or false
end

K.FADE_IN, K.FADE_OUT = 0.2, 0.25
function K.MakeFade(frame)
	local ok, fade = pcall(function()
		local group = frame:CreateAnimationGroup()
		local alpha = group:CreateAnimation("Alpha")
		local made = { group = group, alpha = alpha }
		group:SetScript("OnFinished", function()
			made.running = false
		end)
		return made
	end)
	return ok and fade or false
end

function K.StopFade(record)
	local fade = record.fade
	if fade and fade.running then
		fade.running = false
		pcall(fade.group.Stop, fade.group)
	end
end

function K.SetAlpha(record, alpha)
	K.StopFade(record)
	record.frame:SetAlpha(alpha)
end

function K.Fade(record, alpha)
	local fade = record.fade
	if not fade then
		record.frame:SetAlpha(alpha)
		return
	end
	local from = alpha == 1 and 0 or 1
	local ok = pcall(function()
		fade.group:Stop()
		fade.alpha:SetFromAlpha(from)
		fade.alpha:SetToAlpha(alpha)
		fade.alpha:SetDuration(alpha == 1 and K.FADE_IN or K.FADE_OUT)
		record.frame:SetAlpha(alpha)
		fade.group:Play()
	end)
	fade.running = ok
	if not ok then
		record.fade = false
		record.frame:SetAlpha(alpha)
	end
end

local function Pulse(record, on)
	local target = ns.TrackerShapes.PulseTarget(record) or record.texture
	if record.pulsing and record.pulseTarget ~= target then
		record.pulsing = false
		pcall(record.groups[record.pulseTarget].Stop, record.groups[record.pulseTarget])
	end
	if on and record.groups[target] == nil then
		record.groups[target] = MakePulse(target)
	end
	local group = record.groups[target]
	if not group then
		if on then
			ns.Note(KEY, K.NO_PULSE)
		end
		return
	end
	if on and not record.pulsing then
		record.pulsing = true
		record.pulseTarget = target
		pcall(group.Play, group)
	elseif not on and record.pulsing then
		record.pulsing = false
		pcall(group.Stop, group)
	end
end

local function How(entry, reading)
	local kind = KINDS[entry.kind]
	if reading.absent == true then
		return "live"
	end
	if reading.state ~= "unknown" or (kind and kind.hiddenAble == false) then
		return "live"
	end
	local drawn = records[entry.id]
	if Slot("Live", entry) == true and Opt("gameIcon") ~= false and drawn and drawn.shape == Value(entry, "shape") then
		return "game"
	end
	if kind and kind.noLast == true then
		return "none"
	end
	if Opt("without") == "hidden" and fighting then
		return "hidden"
	end
	local kept = mem.kept[entry.id]
	if kept and not (kept.expires and Now() >= kept.expires) and (kept.state ~= "missing" or Castable(entry)) then
		return "last"
	end
	return "none"
end

local function Fill(entry, reading)
	local top = reading.top or entry.top
	local kind = KINDS[entry.kind]
	local charges = not (kind and type(kind.Count) == "function")
	if charges and Value(entry, "barFill") == "charges" and entry.charged and reading.count and top and top >= 1 then
		return math.min(1, reading.count / top), top
	end
	if reading.expires and reading.length then
		return math.max(0, math.min(1, (reading.expires - Now()) / reading.length))
	end
	return 1
end

function K.KindCount(kind, entry, reading, how)
	if not (kind and type(kind.Count) == "function" and Value(entry, "counts")) then
		return nil
	end
	local ok, text = pcall(kind.Count, entry, reading, how)
	return ok and Plain(text, "string") and text ~= "" and text or nil
end

local function Looks(entry, reading, how)
	local look = { sweep = "clear", name = Opt("names") and Label(entry) or nil }
	if how == "hidden" then
		return { hidden = true, sweep = "keep" }
	end
	local kind = KINDS[entry.kind]
	if kind and type(kind.Hide) == "function" then
		local ok, hide = pcall(kind.Hide, entry, reading, how)
		if ok and not IsSecret(hide) and hide == true then
			return { none = true, sweep = "clear", icon = EntryIcon(entry), fill = 0 }
		end
	end
	if how == "none" or (how == "live" and reading.state == "unknown") then
		look.icon, look.desaturated, look.grey = EntryIcon(entry), true, true
		look.fill = 0
		return look
	end
	local state = reading.state
	if how == "last" then
		reading = mem.kept[entry.id]
		state = reading.state
		look.sweep = "keep"
	elseif how == "game" then
		state = "missing"
	end
	if state == "missing" then
		look.icon, look.desaturated, look.red = EntryIcon(entry), true, true
		look.fill = 0
		look.rim = true
		look.pulse = Value(entry, "missing") == "pulse"
		look.word = Value(entry, "missing") == "word"
		look.count = K.KindCount(kind, entry, reading, how)
		look.countRed = look.count ~= nil
		return look
	end
	look.icon = reading.icon or EntryIcon(entry)
	look.rim = state == "low"
	look.countRed = state == "low"
	look.amber = state == "low"
	if kind and type(kind.Rim) == "function" then
		local ok, r, g, b = pcall(kind.Rim, entry, reading, how)
		if ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number") then
			look.rim, look.rimColour = true, { r, g, b }
		end
	end
	if how ~= "last" then
		look.fill, look.top = Fill(entry, reading)
	end
	if entry.charged and Value(entry, "counts") then
		if how == "last" then
			look.count = "?"
		elseif reading.count then
			look.count = ("%d"):format(reading.count)
		end
	end
	look.count = K.KindCount(kind, entry, reading, how) or look.count
	if how ~= "last" and reading.expires and reading.length then
		look.sweep, look.start, look.length = "set", reading.expires - reading.length, reading.length
	end
	if how ~= "last" and reading.expires then
		look.left = math.max(0, reading.expires - Now())
	end
	return look
end

local function Sweep(record, look)
	local cooldown = record.cooldown
	if look.sweep == "keep" then
		return
	elseif look.sweep == "set" then
		if record.start ~= look.start or record.length ~= look.length then
			if pcall(cooldown.SetCooldown, cooldown, look.start, look.length) then
				record.start, record.length = look.start, look.length
			else
				cooldown:Clear()
				record.start, record.length = nil, nil
				ns.Note(KEY, SWEEP_REFUSED)
			end
		end
	elseif record.start ~= nil then
		cooldown:Clear()
		record.start, record.length = nil, nil
	end
end

local function Apply(record, entry, look)
	local shape = record.shape
	local texture = record.texture
	if record.file ~= look.icon then
		texture:SetTexture(look.icon)
		record.file = look.icon
	end
	texture:SetDesaturated(look.desaturated and true or false)
	if (record.faded == true) ~= (look.none == true) then
		texture:SetAlpha(look.none and 0 or 1)
		record.faded = look.none == true
	end
	if look.red then
		texture:SetVertexColor(RED[1], RED[2], RED[3])
	elseif look.grey then
		texture:SetVertexColor(K.GREY, K.GREY, K.GREY)
	else
		texture:SetVertexColor(1, 1, 1)
	end
	local border = Opt("iconBorder") ~= false
	ns.SetOutline(record.outline, border, border)
	record.count:SetText(shape == "icon" and look.count or "")
	if look.countRed then
		local colour = look.amber and K.AMBER or RED
		record.count:SetTextColor(colour[1], colour[2], colour[3])
	else
		record.count:SetTextColor(1, 1, 1)
	end
	if record.cooldown.SetHideCountdownNumbers then
		record.cooldown:SetHideCountdownNumbers(not (Value(entry, "numbers") and shape == "icon"))
	end
	ns.IconCountdownFont(record, Opt("numbersFont"))
	local numbers = look.amber and "amber" or "white"
	if record.cdTint ~= numbers or record.cdTintFont ~= record.cdFont then
		local read, text = pcall(record.cooldown.GetCountdownFontString, record.cooldown)
		if read and not IsSecret(text) and type(text) == "table" then
			local colour = look.amber and K.AMBER or K.WHITE_RGB
			text:SetTextColor(colour[1], colour[2], colour[3])
			record.cdTint, record.cdTintFont = numbers, record.cdFont
		end
	end
	Sweep(record, look)
	local tint = look.rimColour and (look.rimColour[1] .. "," .. look.rimColour[2] .. "," .. look.rimColour[3]) or (look.amber and "amber" or "red")
	if record.tint ~= tint then
		local colour = look.rimColour or (look.amber and K.AMBER or RED)
		for _, edge in ipairs(record.rim) do
			edge:SetColorTexture(colour[1], colour[2], colour[3], 1)
		end
		record.tint = tint
	end
	for _, edge in ipairs(record.rim) do
		edge:SetShown(look.rim and true or false)
	end
	record.word:SetShown(look.word and true or false)
	Pulse(record, look.pulse)
	if shape ~= "icon" then
		ns.TrackerShapes.Apply(record, entry, look)
		if look.left then
			ns.TrackerShapes.Tick(Dirty)
		end
	end
end

local function Wanted(entry, state, how)
	local ok, dead = pcall(UnitIsDeadOrGhost, "player")
	if ok and not IsSecret(dead) and dead == true then
		return 0
	end
	local kind = KINDS[entry.kind]
	if kind and type(kind.Wanted) == "function" then
		local ok, alpha = pcall(kind.Wanted, entry, state, how, fighting)
		if ok and not IsSecret(alpha) and (alpha == 0 or alpha == 1) then
			return alpha
		end
	end
	if K.readyUntil and how == "live" and (state == "low" or state == "missing") and Now() < K.readyUntil then
		return 1
	end
	local show = Value(entry, "show")
	if show == "low" then
		if (Opt("mounted") and (Ask(IsMounted) == true or Ask(UnitOnTaxi, "player") == true)) or (Opt("resting") and Ask(IsResting) == true)
			or (Opt("combatHide") and fighting) or (Opt("outside") and not K.Inside()) then
			return 0
		end
		if how ~= "live" or state == "low" or state == "missing" then
			return 1
		end
		return 0, state == "fine" and "fine" or nil
	elseif show == "combat" then
		return fighting and 1 or 0
	end
	return 1
end

local function Drawn(entry, reading)
	local kind, record = KINDS[entry.kind], records[entry.id]
	if not record or not kind or type(kind.Hidden) ~= "function" then
		return nil
	end
	if reading.hidden == true and record.how ~= "drawn" then
		local bare = { icon = EntryIcon(entry), sweep = "clear", fill = 0 }
		if Opt("names") then
			bare.name = Label(entry)
		end
		Apply(record, entry, bare)
	end
	local drawn = false
	ns.EachPart(KEY, Part(entry.kind), function()
		drawn = kind.Hidden(entry, record, reading) == true
	end)
	return drawn and "drawn" or nil
end

local function Draw(entry, reading)
	if testing[entry.id] then
		return
	end
	if K.held and K.HeldDraw(entry) then
		return
	end
	local how = Drawn(entry, reading) or How(entry, reading)
	local record = records[entry.id]
	if record then
		record.how = how
		record.sample = nil
		local alpha, reason = 0, nil
		if how == "hidden" then
			Pulse(record, false)
		else
			Apply(record, entry, Looks(entry, reading, how))
			alpha, reason = Wanted(entry, reading.state, how)
		end
		if alpha == 0 and record.alpha == 1 and how ~= "hidden" and record.fixedUntil then
			if Now() < record.fixedUntil then
				alpha = 1
			else
				record.fixedUntil = nil
			end
		end
		local faded = false
		if record.alpha ~= alpha then
			if record.alpha == nil or record.curved or how == "game" then
				K.SetAlpha(record, alpha)
			else
				K.Fade(record, alpha)
				faded = true
			end
			record.alpha = alpha
		elseif how == "game" then
			K.StopFade(record)
		end
		local kind, curved = KINDS[entry.kind], false
		if kind and type(kind.Over) == "function" then
			ns.EachPart(KEY, Part(entry.kind), function()
				curved = kind.Over(entry, record, how, reason) == true
			end)
		end
		if curved then
			K.StopFade(record)
		end
		if record.curved and not curved then
			record.curved = nil
			K.SetAlpha(record, record.alpha)
		end
		K.Packed(record, faded)
	end
	Slot("Show", entry, how == "game", record and record.alpha)
	if record then
		K.Mouse(record, entry)
	end
	if ns.TrackerMarkStep then
		ns.TrackerMarkStep(entry, reading, how)
	end
	if ns.TrackerClickStep then
		ns.TrackerClickStep(entry, reading, how, record, fighting)
	end
end

local function Open()
	return fight ~= nil and fight.length == nil
end

local function StartFight()
	if not Open() then
		fight = { start = Now(), passes = 0, auras = 0, casts = 0, trackers = {} }
	end
	return fight
end

local function EndFight()
	if Open() then
		fight.length = Now() - fight.start
	end
end

local function Info(entry)
	local info = fight.trackers[entry.id]
	if not info then
		info = { casts = 0, hidden = false }
		fight.trackers[entry.id] = info
	end
	return info
end

local function Brief(err)
	if type(err) == "string" then
		return err:sub(1, 60)
	end
	return "an error"
end

local function Question(entry)
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetPlayerAuraBySpellID
	local id = entry.spells and entry.spells[1]
	if type(call) ~= "function" or not id then
		return "no answer"
	end
	local ok, answer = pcall(call, id)
	if not ok then
		return Brief(answer)
	elseif IsSecret(answer) then
		return "a hidden answer"
	elseif answer == nil then
		return "no answer"
	end
	return "an open answer"
end

local function Kind(ok, answer)
	if not ok then
		return "refused"
	elseif IsSecret(answer) then
		return "hidden"
	end
	return "open"
end

local function Accepted(fn)
	return pcall(fn) and "accepted" or "refused"
end

local function MakeScratch()
	if scratch then
		return
	end
	scratch = {}
	local holder = HolderFor(Opt("place"), true)
	for key, args in pairs({ frame = { "Frame" }, bar = { "StatusBar" }, cooldown = { "Cooldown", nil, holder, "CooldownFrameTemplate" } }) do
		local ok, made = pcall(CreateFrame, args[1], nil, holder, args[4])
		if ok and type(made) == "table" then
			ns.Own[made] = true
			made:SetAlpha(0)
			made:SetSize(1, 1)
			scratch[key] = made
		end
	end
end

local function TenSeconds()
	local ok, duration = pcall(function()
		local made = C_DurationUtil.CreateDuration()
		made:SetTimeFromEnd(Now() + 10, 10)
		return made
	end)
	return ok and duration or nil
end

local PREDICATES = {
	{ "auras", "auras", "ShouldAurasBeSecret" },
	{ "cooldowns", "cooldowns", "ShouldCooldownsBeSecret" },
	{ "own", "own casts", "ShouldUnitSpellCastBeSecret", "player" },
	{ "group", "group casts", "ShouldUnitSpellCastBeSecret", "party1" },
}

local function Word(call, ...)
	if type(call) ~= "function" then
		return "not known"
	end
	local ok, answer = pcall(call, ...)
	if not ok then
		return "refused"
	elseif IsSecret(answer) then
		return "hidden answer"
	elseif answer == true then
		return "yes"
	elseif answer == false then
		return "no"
	end
	return "refused"
end

local function Predicates(entry)
	local secrets = type(C_Secrets) == "table" and C_Secrets or {}
	local id = type(entry) == "table" and entry.spells[1] or nil
	local answers = {}
	for _, row in ipairs(PREDICATES) do
		if row[4] == nil then
			answers[row[1]] = Word(secrets[row[3]])
		else
			answers[row[1]] = id and Word(secrets[row[3]], row[4], id) or "not known"
		end
	end
	answers.spell = id and Word(secrets.ShouldSpellAuraBeSecret, id) or "not known"
	answers.level = "not known"
	local levels = Enum and Enum.SecrecyLevel
	if id and type(secrets.GetSpellAuraSecrecy) == "function" and type(levels) == "table" then
		local ok, level = pcall(secrets.GetSpellAuraSecrecy, id)
		if not ok then
			answers.level = "refused"
		elseif IsSecret(level) then
			answers.level = "hidden answer"
		elseif level == levels.NeverSecret then
			answers.level = "never hidden"
		elseif level == levels.ContextuallySecret then
			answers.level = "hidden only in fights"
		elseif level == levels.AlwaysSecret then
			answers.level = "always hidden"
		end
	end
	return answers
end

local function PredicateText(answers)
	local list = {}
	for _, row in ipairs(PREDICATES) do
		list[#list + 1] = row[2] .. " " .. answers[row[1]]
	end
	return table.concat(list, ", ")
end

local function TotemProbe()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldTotemSlotBeSecret
	local slots, details = {}, "open"
	for slot = 1, #TOTEMS do
		local ok, answer = pcall(call, slot)
		slots[slot] = Kind(ok, answer)
		if slots[slot] == "open" and not IsSecret(answer) and answer ~= false then
			slots[slot] = answer == true and "hidden" or "refused"
		end
		local named, have = pcall(GetTotemInfo, slot)
		local word = Kind(named, have)
		if word == "refused" or (word == "hidden" and details == "open") then
			details = word
		end
	end
	return slots, details
end

local function WeaponProbe()
	local call = type(C_Item) == "table" and C_Item.GetWeaponEnchantInfo
	local slots, names, list = {}, {}, {}
	for name, value in pairs(type(Enum) == "table" and type(Enum.WeaponSlot) == "table" and Enum.WeaponSlot or {}) do
		slots[#slots + 1] = { name = (name:gsub("(%l)(%u)", "%1 %2")):lower(), slot = value }
	end
	table.sort(slots, function(left, right)
		return left.slot < right.slot
	end)
	for name, value in pairs(type(Enum) == "table" and type(Enum.ItemEnchantType) == "table" and Enum.ItemEnchantType or {}) do
		names[value] = name
	end
	for _, hand in ipairs(slots) do
		local row = { name = hand.name, word = "open", entries = {} }
		local ok, enchants = pcall(call, hand.slot)
		if not ok or (not IsSecret(enchants) and type(enchants) ~= "table") then
			row.word = "refused"
		elseif IsSecret(enchants) then
			row.word = "hidden"
		else
			for _, enchant in pairs(enchants) do
				if IsSecret(enchant) then
					row.word = "hidden"
				elseif type(enchant) ~= "table" then
					row.word = "refused"
				else
					local hasOk, has = pcall(function() return enchant.hasEnchant end)
					local kindOk, kind = pcall(function() return enchant.enchantType end)
					local plain = hasOk and kindOk and not IsSecret(has) and not IsSecret(kind)
					if not plain then
						row.word = "hidden"
					end
					row.entries[#row.entries + 1] = { plain = plain, hasEnchant = plain and has == true, type = plain and type(kind) == "number" and kind or nil,
						name = plain and names[kind] or nil }
				end
			end
		end
		list[#list + 1] = row
	end
	return list
end

local function WeaponText(list)
	if #list == 0 then
		return "refused"
	end
	local parts = {}
	for _, row in ipairs(list) do
		local word = row.word
		if word == "open" then
			local counts, order = {}, {}
			for _, enchant in ipairs(row.entries) do
				if enchant.hasEnchant then
					local name = enchant.name or "other"
					if not counts[name] then
						counts[name] = 0
						order[#order + 1] = name
					end
					counts[name] = counts[name] + 1
				end
			end
			for index, name in ipairs(order) do
				order[index] = name .. " " .. counts[name]
			end
			word = #order > 0 and table.concat(order, " and ") or "none"
		end
		parts[#parts + 1] = row.name .. " " .. word
	end
	return table.concat(parts, ", ")
end

local function Probes()
	local found = {}
	found.totems, found.details = TotemProbe()
	found.weapon = WeaponProbe()
	found.predicates = Predicates(Buffs()[1])
	found.pet = Kind(pcall(UnitExists, "pet"))
	found.bar, found.icon, found.sweep, found.move = "refused", "refused", "refused", "refused"
	local cooldown, bar = scratch and scratch.cooldown, scratch and scratch.bar
	local duration = TenSeconds()
	if bar then
		local own = Accepted(function()
			bar:SetTimerDuration(GetTotemDuration(1))
		end)
		local made = duration and Accepted(function()
			bar:SetTimerDuration(duration)
		end)
		found.bar = own == "accepted" and made == "accepted" and "accepted" or "refused"
	end
	if cooldown then
		local own = Accepted(function()
			cooldown:SetCooldownFromDurationObject(GetTotemDuration(1))
		end)
		local made = duration and Accepted(function()
			cooldown:SetCooldownFromDurationObject(duration)
		end)
		found.icon = own == "accepted" and made == "accepted" and "accepted" or "refused"
		found.sweep = Accepted(function()
			cooldown:SetCooldown(Now(), 10)
		end)
		pcall(cooldown.Clear, cooldown)
	end
	if scratch and scratch.frame then
		found.move = Accepted(function()
			scratch.frame:ClearAllPoints()
			scratch.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end)
	end
	fight.probes = found
	Slot("Probe")
end

local function Quiet(at)
	return entered ~= nil and at >= entered and at - entered < K.QUIET
end

local function Ding(kit, fall, note)
	local ok, played = pcall(PlaySound, kit or K.KITS.raid)
	if ok and (IsSecret(played) or played ~= false) then
		return true
	end
	if fall and fall ~= kit then
		ok, played = pcall(PlaySound, fall)
		if ok and (IsSecret(played) or played ~= false) then
			return true
		end
	end
	ns.Note(KEY, note or NO_SOUND)
	return false
end
ns.TrackerPlay = Ding
ns.TrackerQuiet = function()
	return Quiet(Now())
end

local function GameSound()
	local call = ns.TrackerGameSound and ns.TrackerGameSound.Sync
	if type(call) == "function" then
		call(ns.Enabled(KEY) and Entries() or {})
	end
end

local function GameTaken(entry, trigger)
	local call = ns.TrackerGameSound and ns.TrackerGameSound.Taken
	return type(call) == "function" and call(entry, trigger) == true
end

function K.Came(entry, old, reading, pending)
	local id = entry.id
	local gap = K.gap[id]
	K.gap[id] = nil
	if gap or not old or (entry.kind ~= "buff" and entry.kind ~= "debuff") or reading.state == "missing" then
		return
	end
	local row, trigger
	if old.state == "missing" then
		if pending then
			return
		end
		row, trigger = "comes", "Added"
	elseif Plain(reading.count, "number") and Plain(old.count, "number") and reading.count > old.count then
		row, trigger = "stacks", "ApplicationsIncreased"
	else
		return
	end
	if Value(entry, row) == true and not Quiet(Now()) and not GameTaken(entry, trigger) then
		Ding(K.KITS[Value(entry, "kit")] or K.KITS.raid)
	end
end

K.FIXED = 0.6
function K.Fixed(entry)
	local record = records[entry.id]
	if not record or record.alpha ~= 1 or record.how ~= "live" or K.held or testing[entry.id] then
		return
	end
	local fix = record.fix
	if not fix then
		fix = record.top:CreateTexture(nil, "OVERLAY", nil, 6)
		ns.Own[fix] = true
		local green = K.TIP.fine
		fix:SetColorTexture(green[1], green[2], green[3], 0.6)
		fix:Hide()
		record.fix = fix
		local ok, group = pcall(function()
			local made = fix:CreateAnimationGroup()
			local alpha = made:CreateAnimation("Alpha")
			alpha:SetFromAlpha(1)
			alpha:SetToAlpha(0)
			alpha:SetDuration(K.FIXED)
			pcall(made.SetToFinalAlpha, made, true)
			made:SetScript("OnFinished", function()
				fix:Hide()
				fix:SetAlpha(1)
			end)
			return made
		end)
		record.fixGroup = ok and group or false
	end
	fix:ClearAllPoints()
	fix:SetAllPoints(record.frame)
	local group = record.fixGroup
	if group then
		pcall(group.Stop, group)
	end
	fix:SetAlpha(1)
	fix:Show()
	if not (group and pcall(group.Play, group)) then
		C_Timer.After(K.FIXED, function()
			if not (record.fixedUntil and Now() < record.fixedUntil) then
				fix:Hide()
			end
		end)
	end
	record.fixedUntil = Now() + K.FIXED
	C_Timer.After(K.FIXED + 0.02, Dirty)
end

local function Track(entry, reading)
	local id, state = entry.id, reading.state
	if state == "unknown" then
		mem.drops[id] = nil
		K.gap[id] = true
		return
	end
	local old, pending = mem.kept[id], mem.drops[id]
	local before = old and old.state
	mem.kept[id] = reading
	if reading.length then
		mem.lengths[id] = reading.length
	end
	if reading.count and reading.count > (entry.top or 0) then
		entry.top = math.min(20, math.max(1, math.floor(reading.count)))
	end
	K.Came(entry, old, reading, pending)
	local kind = KINDS[entry.kind]
	if before == "fine" and state == "low" and Value(entry, "lowSound") == true and not Quiet(Now()) and not (kind and kind.noDrop == true) then
		Ding(K.KITS[Value(entry, "kit")] or K.KITS.raid)
	end
	if (before == "missing" or before == "low") and state == "fine" and not Quiet(Now()) then
		K.Fixed(entry)
	end
	if kind and before ~= state and type(kind.Changed) == "function" then
		ns.EachPart(KEY, Part(entry.kind), kind.Changed, entry, before, state)
	end
	if state ~= "missing" or (kind and kind.noDrop == true) then
		mem.drops[id] = nil
		return
	end
	local now, first = Now(), mem.drops[id]
	if first then
		if now - first >= PASS - 0.01 then
			mem.drops[id] = nil
			if Value(entry, "sound") and not Quiet(now) and not GameTaken(entry) then
				Ding(K.KITS[Value(entry, "kit")] or K.KITS.raid)
			end
		end
	elseif (before == "fine" or before == "low") and Value(entry, "sound") and not Quiet(now) then
		mem.drops[id] = now
		if C_Timer and C_Timer.After then
			C_Timer.After(PASS, Dirty)
		end
	end
end

local function Update(entry, first)
	local reading = Read(entry)
	if Open() then
		local info = Info(entry)
		info.hidden = info.hidden or reading.hidden == true
		if first then
			info.asked = reading.hidden and not KINDS[entry.kind] and Question(entry) or "not asked"
		end
	end
	Track(entry, reading)
	Draw(entry, reading)
end

local function Resync()
	if edited then
		edited = false
		Slot("Sync", OnEntries())
		GameSound()
	end
end

local function Pass()
	lastPass = Now()
	local entries = OnEntries()
	if ns.TrackerMarkSweep then
		ns.TrackerMarkSweep(entries)
	end
	if ns.TrackerClickSweep then
		ns.TrackerClickSweep(entries)
	end
	if #entries == 0 then
		return
	end
	local first = false
	if Open() then
		fight.passes = fight.passes + 1
		first = fight.passes == 1
		local late = not fight.late and lastPass - fight.start >= K.LATE
		if first or late then
			fight.late = fight.late or late
			ns.Each(KEY, Probes)
		end
	end
	for _, entry in ipairs(entries) do
		ns.Each(KEY, Update, entry, first)
	end
	Resync()
end

local function TimedPass()
	waiting = false
	if ns.Enabled(KEY) then
		ns.Try(KEY, Pass)
	end
end

function Dirty()
	if waiting or tracked == 0 then
		return
	end
	waiting = true
	if C_Timer and C_Timer.After then
		C_Timer.After(math.max(0, PASS - (Now() - lastPass)), TimedPass)
	else
		TimedPass()
	end
end

local function Restart(entry)
	local record, id = records[entry.id], entry.id
	if not record or (record.how ~= "last" and record.how ~= "none") then
		return
	end
	local old = mem.kept[id]
	local length = old and old.length or mem.lengths[id]
	local start = Now()
	local reading = { state = "fine", hidden = false, icon = old and old.icon, id = old and old.id }
	if not length then
		mem.kept[id] = reading
		Sweep(record, { sweep = "clear" })
		Dirty()
		return
	end
	reading.expires, reading.length = start + length, length
	mem.kept[id] = reading
	local cooldown = record.cooldown
	if pcall(cooldown.SetCooldown, cooldown, start, length) then
		record.start, record.length = start, length
	else
		ns.Note(KEY, SWEEP_REFUSED)
	end
	Dirty()
end

local function OwnCast(spellID)
	local name = SpellName(spellID)
	for kindName, kind in pairs(KINDS) do
		if type(kind.Cast) == "function" then
			ns.EachPart(KEY, Part(kindName), kind.Cast, spellID)
		end
	end
	for _, entry in ipairs(Buffs()) do
		if Lists(entry, spellID, name or "") then
			Learn(entry, spellID, false)
			mem.cast[entry.id] = spellID
			if Open() then
				local info = Info(entry)
				info.casts = info.casts + 1
			end
			Restart(entry)
		end
	end
	Resync()
end

ns.TrackerEntries = Entries
function ns.TrackerSound(entry)
	if Value(entry, "sound") and not Quiet(Now()) and not GameTaken(entry) then
		Ding(K.KITS[Value(entry, "kit")] or K.KITS.raid)
	end
end

local function Noticed(event, ...)
	local unit = ...
	local others = heard == "all units"
	if event == "UNIT_AURA" then
		if not IsSecret(unit) and unit ~= "player" and not (unit == "target" and K.target) then
			return
		end
		if Open() and (IsSecret(unit) or unit == "player") then
			fight.auras = fight.auras + 1
			fight.unitPlain = fight.unitPlain ~= false and not IsSecret(unit)
		end
		Dirty()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, spellID = ...
		if others and (IsSecret(unit) or unit ~= "player") then
			return
		end
		if Open() then
			fight.casts = fight.casts + 1
			fight.castPlain = fight.castPlain ~= false and not IsSecret(spellID)
		end
		if Whole(spellID) then
			OwnCast(spellID)
		end
	elseif K.events[event] then
		if event:sub(1, 5) == "UNIT_" and not IsSecret(unit) and unit ~= (K.units[event] or "player") then
			return
		end
		for name, kind in pairs(KINDS) do
			if type(kind.Event) == "function" then
				ns.EachPart(KEY, Part(name), kind.Event, event, ...)
			end
		end
		Dirty()
	end
end

local function Listen(frame, event, unit, ...)
	if frame.RegisterUnitEvent then
		local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, unit or "player", ...)
		if ok and (IsSecret(registered) or registered ~= false) then
			return true
		end
	end
	pcall(frame.RegisterEvent, frame, event)
	return false
end

local function Subscribe(event)
	if not watcher or K.registered[event] then
		return
	end
	K.registered[event] = true
	if event == "UNIT_INVENTORY_CHANGED" or K.units[event] then
		Listen(watcher, event, K.units[event])
	else
		pcall(watcher.RegisterEvent, watcher, event)
	end
end

local function Watch()
	if watcher then
		return
	end
	watcher = CreateFrame("Frame")
	ns.Own[watcher] = true
	fighting = InCombatLockdown() and true or false
	local aura = Listen(watcher, "UNIT_AURA", "player", "target")
	local cast = Listen(watcher, "UNIT_SPELLCAST_SUCCEEDED")
	heard = aura and cast and "the player" or "all units"
	for event in pairs(K.events) do
		Subscribe(event)
	end
	watcher:SetScript("OnEvent", function(_, event, ...)
		if ns.Enabled(KEY) then
			ns.Try(KEY, Noticed, event, ...)
		end
	end)
end

function ns.TrackerKind(name, spec)
	if type(name) ~= "string" or name == "buff" or type(spec) ~= "table" or type(spec.Read) ~= "function" or type(spec.Clean) ~= "function" then
		return false
	end
	if spec.slot ~= nil and not (type(spec.slot) == "table" and type(spec.slot.unit) == "string" and type(spec.slot.filter) == "string") then
		spec.slot = nil
	end
	KINDS[name] = spec
	for event, unit in pairs(type(spec.unitEvents) == "table" and spec.unitEvents or {}) do
		if type(event) == "string" and type(unit) == "string" then
			K.units[event] = unit
		end
	end
	for _, event in ipairs(type(spec.events) == "table" and spec.events or {}) do
		if type(event) == "string" then
			K.events[event] = true
			Subscribe(event)
		end
	end
	if watcher then
		QueueLayout()
	end
	return true
end

function ns.TrackerWord(word, fn)
	if type(word) == "string" and type(fn) == "function" and word ~= "" then
		K.commands[word:lower()] = fn
		return true
	end
	return false
end

local function Counted(kind)
	local types = Enum and Enum.AddOnRestrictionType
	if type(types) ~= "table" or kind == nil then
		return false
	end
	return kind == types.Combat or kind == types.Encounter or kind == types.ChallengeMode or kind == types.PvPMatch
end

local function NeverHidden(entry)
	local kind = KINDS[entry.kind]
	if kind and entry.kind ~= "debuff" then
		return kind.hiddenAble == false
	end
	local call = type(C_Secrets) == "table" and C_Secrets.GetSpellAuraSecrecy
	local never = Enum and Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret
	if type(call) ~= "function" or never == nil or #entry.spells == 0 then
		return false
	end
	for _, id in ipairs(entry.spells) do
		local ok, level = pcall(call, id)
		if not ok or IsSecret(level) or level ~= never then
			return false
		end
	end
	return true
end

local function Warn()
	local current = StartFight()
	local count = 0
	for _, entry in ipairs(Entries()) do
		local reading = K.HIDDEN
		if entry.kind == "buff" then
			reading = ns.AuraReading(entry)
		elseif entry.kind == "debuff" then
			reading = ns.DebuffReading(entry)
		end
		if reading.state ~= "unknown" then
			mem.kept[entry.id] = reading
			if reading.length then
				mem.lengths[entry.id] = reading.length
			end
			count = count + 1
		end
	end
	if not current.warned then
		current.warned, current.kept = true, count
	end
	for _, entry in ipairs(OnEntries()) do
		if not NeverHidden(entry) then
			ns.Each(KEY, Draw, entry, K.HIDDEN)
		end
	end
	Resync()
	Dirty()
end

local function Restriction(kind, state)
	local states = Enum and Enum.AddOnRestrictionState
	if IsSecret(kind) or IsSecret(state) or not Counted(kind) or type(states) ~= "table" then
		return
	end
	if state == states.Activating then
		Warn()
	elseif state == states.Inactive then
		Dirty()
		Slot("Flush")
	end
end

local function FightStarts()
	fighting = true
	K.ReminderOff()
	if K.held and K.held.preview then
		K.held = nil
	end
	if next(testing) then
		K.TestCut()
	end
	StartFight()
	Pass()
end

local function FightEnds()
	fighting = false
	EndFight()
	Dirty()
	Slot("Flush")
end

local function World()
	for name, kind in pairs(KINDS) do
		if type(kind.World) == "function" then
			ns.EachPart(KEY, Part(name), kind.World)
		end
	end
end

local function SpellsChanged()
	bookIds = nil
	World()
	QueueLayout()
end

local function Entered()
	entered = Now()
	K.inside = nil
	World()
	Dirty()
	Slot("Flush")
	GameSound()
end

local function HighestBar(display)
	for _, key in ipairs(RESOURCE_BARS) do
		local bar = Field(display, key)
		if not ns.Forbidden(bar) and Ask(bar.IsShown, bar) == true then
			return bar
		end
	end
	return display
end

local function LowestBar(display)
	for index = #RESOURCE_BARS, 1, -1 do
		local bar = Field(display, RESOURCE_BARS[index])
		if not ns.Forbidden(bar) and Ask(bar.IsShown, bar) == true then
			return bar
		end
	end
	return display
end

local function CooldownsBelow()
	if type(ns.CooldownRow) ~= "function" then
		return nil
	end
	local frames, holder = ns.CooldownRow()
	if not holder or #frames == 0 or ns.Get("cooldowns.place") ~= "resource" or ns.MoverSpot("FlatUICooldowns", "CENTER")
		or Ask(holder.IsShown, holder) ~= true then
		return nil
	end
	local size, perRow = ns.Get("cooldowns.size"), ns.Get("cooldowns.perRow")
	if not (Plain(size, "number") and Plain(perRow, "number") and perRow >= 1) then
		return nil
	end
	local rows = math.ceil(#frames / perRow)
	return holder, ns.Get("cooldowns.rows") == "up" and 0 or ((rows - 1) * (size + (ns.Get("cooldowns.spacing") or 0)) + size)
end

local function Place(place, holder, total, tallest, grow)
	local x, y = Opt("x"), Opt("y")
	local refused = false
	if place == "resource" then
		local anchored = false
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			local side = Opt("side") == "below" and "below" or "above"
			local charges = type(ns.ChargesHolder) == "function" and ns.ChargesHolder(side) or nil
			local over = charges or (type(ns.OwnBuffsHolder) == "function" and ns.OwnBuffsHolder(side) or nil)
			local named = charges and "the Charges row" or "the Your buffs row"
			if Opt("side") == "below" then
				local row, depth = CooldownsBelow()
				if row then
					holder:SetPoint("CENTER", row, "CENTER", x, y - depth - GAP - tallest / 2)
					K.where[place] = "below the Cooldown icons row"
				elseif over then
					holder:SetPoint("CENTER", over, "BOTTOM", x, y - GAP - tallest / 2)
					K.where[place] = "below " .. named
				else
					holder:SetPoint("CENTER", LowestBar(display), "BOTTOM", x, y - GAP - tallest / 2)
					K.where[place] = "below the personal resource display"
				end
			elseif over then
				holder:SetPoint("CENTER", over, "TOP", x, y + GAP + tallest / 2)
				K.where[place] = "above " .. named
			else
				holder:SetPoint("CENTER", HighestBar(display), "TOP", x, y + GAP + tallest / 2)
				K.where[place] = "above the personal resource display"
			end
			local ok, left = pcall(holder.GetLeft, holder)
			anchored = not ok or IsSecret(left) or left ~= nil
		end
		if anchored then
			return false
		end
		refused = true
	end
	local spotX, spotY
	if place == "own" then
		spotX, spotY = ns.MoverSpot(MOVER, "CENTER")
	end
	if spotX then
		holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", spotX + x, spotY + y)
		K.where[place] = "at the spot saved with the movers"
	else
		holder:SetPoint("CENTER", UIParent, "CENTER", K.BESIDE + (grow == "right" and 0 or grow == "left" and total or total / 2) + x, y)
		K.where[place] = refused and "beside the character, the personal resource display cannot be used" or "beside the character"
	end
	return refused
end

local function Assign(entry, parent)
	local record = records[entry.id]
	if not record then
		local spec = ns.TrackerSlotSpec(entry)
		local pool = spec and (spec.unit .. "|" .. spec.filter) or "none"
		record = table.remove(free[pool] or {}) or Acquire(parent)
		record.pool = pool
		record.entryId = entry.id
		records[entry.id] = record
		ns.Count(KEY)
	end
	return record
end

local function Gone(id)
	for name, kind in pairs(KINDS) do
		if type(kind.Gone) == "function" then
			ns.EachPart(KEY, Part(name), kind.Gone, id)
		end
	end
end

local function Release(wanted)
	for id, record in pairs(records) do
		if not wanted[id] then
			Gone(id)
			records[id] = nil
			ns.Count(KEY, -1)
			Pulse(record, false)
			if record.hid and record.hid.Leave then
				pcall(record.hid.Leave)
			end
			record.how, record.sample = nil, nil
			record.cdTint = nil
			record.alpha = nil
			record.seen, record.leaving = nil, nil
			K.StopFade(record)
			record.fixedUntil = nil
			if record.fix then
				if record.fixGroup then
					pcall(record.fixGroup.Stop, record.fixGroup)
				end
				record.fix:Hide()
			end
			if record.motion then
				record.motion = not pcall(record.frame.SetMouseMotionEnabled, record.frame, false)
			end
			K.TipLeave(record)
			record.frame:Hide()
			free[record.pool] = free[record.pool] or {}
			table.insert(free[record.pool], record)
			Forget(id)
		end
	end
end

local function HideHolders()
	for _, holder in pairs(holders) do
		holder:Hide()
	end
end

function K.EndKinds()
	for id in pairs(records) do
		Gone(id)
	end
	for _, list in ipairs({ Entries(), K.Auto() }) do
		for _, entry in ipairs(list) do
			local kind = KINDS[entry.kind]
			if kind and type(kind.Gone) == "function" then
				mem.kept[entry.id] = nil
			end
		end
	end
end

function K.Seen(record)
	if record.curved or record.how == "game" then
		return true
	end
	return record.alpha ~= 0 and record.faded ~= true and record.how ~= "hidden"
end

function K.Arrange(place)
	local row = K.rows and K.rows[place]
	if not row or InCombatLockdown() then
		return
	end
	local spacing, grow = Opt("spacing"), Opt("grow")
	local list, total = row.sized, row.total
	local wait = 0
	if Opt("pack") == true then
		local now, first, after, last = Now(), {}, {}, {}
		total = 0
		for _, item in ipairs(row.sized) do
			local record = item[2]
			local seen = K.Seen(record)
			record.seen = seen
			if record.auto then
				last[#last + 1] = item
			elseif seen or (record.leaving and record.leaving > now) then
				first[#first + 1] = item
				total = total + item[3]
				if not seen then
					wait = math.max(wait, record.leaving - now)
				end
			else
				after[#after + 1] = item
			end
		end
		total = total + spacing * math.max(0, #first - 1)
		for _, group in ipairs({ after, last }) do
			for _, item in ipairs(group) do
				first[#first + 1] = item
			end
		end
		list = first
	end
	local holder, widest, depth = row.holder, row.widest, row.depth
	local x = grow == "right" and 0 or grow == "left" and 0 or -total / 2
	local y = grow == "down" and depth / 2 or -depth / 2
	for _, item in ipairs(list) do
		local entry, record, width, height = item[1], item[2], item[3], item[4]
		local frame = record.frame
		frame:ClearAllPoints()
		if grow == "left" then
			x = x - width
		end
		local ownX, ownY = Value(entry, "x") - Opt("x"), Value(entry, "y") - Opt("y")
		if grow == "down" then
			frame:SetPoint("TOPLEFT", holder, "CENTER", -widest / 2 + ownX, y + ownY)
			y = y - height - spacing
		elseif grow == "up" then
			frame:SetPoint("BOTTOMLEFT", holder, "CENTER", -widest / 2 + ownX, y + ownY)
			y = y + height + spacing
		else
			frame:SetPoint("LEFT", holder, "CENTER", x + ownX, ownY)
		end
		x = grow == "left" and x - spacing or x + width + spacing
	end
	if wait > 0 then
		K.QueueArrange(place, wait + 0.05)
	end
end

K.arranging = {}
function K.QueueArrange(place, delay)
	local key = place .. (delay > 0 and "+" or "")
	if K.arranging[key] or not (C_Timer and C_Timer.After) then
		return
	end
	K.arranging[key] = true
	C_Timer.After(delay, function()
		ns.OutOfCombat(function()
			K.arranging[key] = nil
			if ns.Enabled(KEY) and Opt("pack") == true then
				K.Arrange(place)
			end
		end)
	end)
end

function K.Packed(record, faded)
	if Opt("pack") ~= true or record.auto or not record.place then
		return
	end
	local seen = K.Seen(record)
	if record.seen == seen then
		return
	end
	record.seen = seen
	record.leaving = (not seen and faded) and (Now() + K.FADE_OUT) or nil
	K.QueueArrange(record.place, record.leaving and K.FADE_OUT + 0.05 or 0)
end

local function Layout()
	K.rows = {}
	if not ns.Enabled(KEY) then
		tracked = 0
		ns.ClearNote(KEY, NO_POSITION)
		HideHolders()
		K.EndKinds()
		shown = {}
		if type(ns.ChargesRecheck) == "function" then
			ns.ChargesRecheck()
		end
		return
	end
	if type(ns.ProcAutoBuild) == "function" then
		ns.EachPart(KEY, "procs", ns.ProcAutoBuild)
	end
	if type(ns.ChargesRecheck) == "function" then
		ns.ChargesRecheck()
	end
	local entries, wanted = OnEntries(), {}
	tracked = #entries
	K.target = false
	for _, entry in ipairs(entries) do
		wanted[entry.id] = true
		local spec = ns.TrackerSlotSpec(entry)
		K.target = K.target or (spec ~= nil and spec.unit == "target")
	end
	Release(wanted)
	if #entries == 0 then
		ns.ClearNote(KEY, NO_POSITION)
		HideHolders()
		shown = {}
		return
	end
	HolderFor(Opt("place"), true)
	MakeScratch()
	local groups = { resource = {}, character = {}, own = {} }
	for round = 1, 2 do
		for _, entry in ipairs(entries) do
			local kind = KINDS[entry.kind]
			if (round == 2) == (kind ~= nil and kind.last == true) then
				local group = groups[Value(entry, "place")] or groups.resource
				group[#group + 1] = entry
			end
		end
	end
	local spacing, grow = Opt("spacing"), Opt("grow")
	local refused = false
	shown = {}
	K.where = {}
	K.rows = {}
	for _, place in ipairs(K.ORDER) do
		local group, holder = groups[place], HolderFor(place, #groups[place] > 0)
		if #group == 0 then
			if holder then
				holder:Hide()
			end
		else
			holder:Show()
			local sized, total, tallest, counted = {}, 0, 0, 0
			for _, entry in ipairs(group) do
				local record = Assign(entry, holder)
				local width, height = ns.TrackerShapes.Size(entry, ns.TrackerShapes.Make(record, Value(entry, "shape")))
				sized[#sized + 1] = { entry, record, width, height }
				record.auto = entry.auto == true or nil
				if not record.auto then
					total, counted = total + width, counted + 1
				end
				tallest = math.max(tallest, height)
			end
			total = total + spacing * math.max(0, counted - 1)
			local column = grow == "down" or grow == "up"
			local widest, depth = 0, 0
			if column then
				for _, item in ipairs(sized) do
					if not item[2].auto then
						widest, depth = math.max(widest, item[3]), depth + item[4]
					end
				end
				depth = depth + spacing * math.max(0, counted - 1)
			end
			if Place(place, holder, column and widest or total, column and depth or tallest, column and "center" or grow) then
				refused = true
			end
			K.rows[place] = { sized = sized, holder = holder, total = total, widest = widest, depth = depth }
			for _, item in ipairs(sized) do
				local entry, record, width, height = item[1], item[2], item[3], item[4]
				local frame = record.frame
				if record.parent ~= holder then
					frame:SetParent(holder)
					record.parent = holder
				end
				record.place = place
				frame:SetSize(width, height)
				frame:Show()
				Fit(record, entry)
				shown[#shown + 1] = record
			end
			K.Arrange(place)
		end
	end
	if refused then
		ns.Note(KEY, NO_POSITION)
	else
		ns.ClearNote(KEY, NO_POSITION)
	end
	edited = false
	Slot("Sync", entries)
	Pass()
end

function ns.TrackerDirty()
	Dirty()
end

function QueueLayout()
	GameSound()
	if type(ns.OwnBuffsTrackers) == "function" then
		pcall(ns.OwnBuffsTrackers)
	end
	if layoutQueued then
		return
	end
	layoutQueued = true
	ns.OutOfCombat(function()
		layoutQueued = false
		if ns.IsStopped(KEY) then
			pcall(Layout)
		else
			ns.Try(KEY, Layout)
		end
	end)
end

function ns.TrackerPlaceAgain()
	QueueLayout()
end

function ns.TrackerSpellIDs()
	local ids = {}
	for _, entry in ipairs(OnEntries()) do
		if entry.kind == "buff" and type(entry.spells) == "table" then
			for _, id in ipairs(entry.spells) do
				if Plain(id, "number") then
					ids[id] = true
				end
			end
		end
	end
	return ids
end

function ns.TrackerRow()
	local frames = {}
	if not ns.Enabled(KEY) then
		return frames
	end
	local place = Opt("place")
	for _, record in ipairs(shown) do
		if record.place == "own" then
			place = "own"
		end
	end
	local holder = HolderFor(place)
	if not holder then
		return frames
	end
	for _, record in ipairs(shown) do
		if record.place == place and not record.auto then
			frames[#frames + 1] = record.frame
		end
	end
	return frames, holder
end

function ns.TrackersMoved()
	if ns.MoverSpot(MOVER, "CENTER") and Opt("place") ~= "own" then
		ns.Set(KEY .. ".place", "own")
	end
	QueueLayout()
end

function ns.TrackerFrame(entry)
	local record = type(entry) == "table" and records[entry.id]
	return record and record.frame or nil
end

K.TIP = { fine = { 0.3, 0.85, 0.4 }, low = K.AMBER, missing = RED, dim = { 0.7, 0.7, 0.7 } }
K.TIP_FINE = { form = "In one of them", tracking = "On", durability = "Fine", pet = "Out" }
K.TIP_MISSING = { item = "None in your bags", ammo = "None left", durability = "An item is broken", pet = "Gone or dead",
	tracking = "No tracking on", form = "In none of them", totem = "Not down", debuff = "Not on your target", weapon = "No enchant on it" }

function K.TipRule(entry)
	if not K.TIMED[entry.kind] then
		return nil
	end
	local parts = {}
	local charges = entry.charged and Value(entry, "low") or 0
	if Plain(charges, "number") and charges > 0 then
		parts[#parts + 1] = ("at %s or fewer"):format(Plural(math.floor(charges), entry.kind == "debuff" and "stack" or "charge"))
	end
	local seconds, where = K.LowTime(entry)
	if Plain(seconds, "number") and seconds > 0 then
		parts[#parts + 1] = ("under %d:%02d left%s"):format(math.floor(seconds / 60), math.floor(seconds % 60), where and (" (earlier in a %s)"):format(where) or "")
	end
	return #parts > 0 and ("Low " .. table.concat(parts, " or ")) or nil
end

function K.EntryById(id)
	if id == nil then
		return nil
	end
	local entries = Entries()
	for _, list in ipairs({ entries, K.Auto(entries) }) do
		for _, entry in ipairs(list) do
			if entry.id == id then
				return entry
			end
		end
	end
	return nil
end

function K.Visible(record, entry)
	if record.how == "hidden" or record.alpha ~= 1 or record.faded == true then
		return false
	end
	if record.how == "game" then
		entry = entry or K.EntryById(record.entryId)
		return not (entry and Slot("Hid", entry) == true)
	end
	return true
end

function K.Mouse(record, entry)
	local tips = Opt("tooltips")
	local want = tips ~= "off" and not (tips ~= "on" and fighting) and K.Visible(record, entry)
	if record.motion ~= want and pcall(record.frame.SetMouseMotionEnabled, record.frame, want) then
		record.motion = want
	end
end

function K.TipTime(reading)
	local expires = reading.expires
	if not (Plain(expires, "number") and ns.Finite(expires)) then
		return nil
	end
	local seconds = math.max(0, expires - Now())
	return ("%d:%02d left"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

function K.TipCount(entry, reading)
	local count = reading.count
	if not (Plain(count, "number") and ns.Finite(count)) or entry.kind == "group" then
		return nil
	end
	count = math.floor(count)
	if entry.kind == "item" then
		return ("%d in your bags"):format(count)
	elseif entry.kind == "ammo" then
		return ("%d left"):format(count)
	elseif entry.kind == "durability" then
		return ("most worn item at %d%%"):format(count)
	end
	return Plural(count, entry.kind == "debuff" and "stack" or "charge")
end

function K.TipState(entry, record)
	local reading, prefix = Read(entry), ""
	local how = record and record.how
	if reading.state == "unknown" then
		local kept = mem.kept[entry.id]
		if how == "last" and kept then
			reading, prefix = kept, "Last known: "
		elseif how == "game" then
			return ("The game hides it in a fight: its own %s shows it."):format(record.shape ~= "icon" and record.shape or "icon"), K.TIP.dim
		elseif how == "drawn" then
			return "The game hides it in a fight: its own timer shows it.", K.TIP.dim
		else
			return reading.hidden and "Not known: the game hides it in a fight." or "Not known yet.", K.TIP.dim
		end
	end
	local text, colour, state = K.TipWords(entry, reading)
	return prefix .. text, colour, state
end

function K.TipWords(entry, reading)
	local state, words = reading.state, {}
	if state == "missing" then
		words[1] = K.TIP_MISSING[entry.kind] or "Missing"
	else
		words[1] = state == "low" and "Low" or K.TIP_FINE[entry.kind] or "Up"
		words[#words + 1] = K.TipTime(reading)
		words[#words + 1] = K.TipCount(entry, reading)
	end
	return table.concat(words, ", "), K.TIP[state] or K.TIP.dim, K.TIP[state] and state or nil
end

function K.TipLines(entry, tip, noClick)
	tip:SetText(Label(entry), 1, 1, 1)
	local dim = K.TIP.dim
	local kind = KINDS[entry.kind]
	local what = kind and kind.what or "buff on you"
	tip:AddLine((what:gsub("^%l", string.upper)), dim[1], dim[2], dim[3])
	if K.SampleTip(entry, tip) then
		return
	end
	local text, colour, state = K.TipState(entry, records[entry.id])
	tip:AddLine(text, colour[1], colour[2], colour[3], true)
	local rule = K.TipRule(entry)
	if rule then
		tip:AddLine(rule, dim[1], dim[2], dim[3], true)
	end
	if kind and type(kind.Tip) == "function" then
		local ok, extra = pcall(kind.Tip, entry)
		for _, line in ipairs(ok and type(extra) == "table" and extra or {}) do
			if Plain(line, "string") then
				tip:AddLine(line, dim[1], dim[2], dim[3], true)
			end
		end
	end
	if not noClick and (state == "low" or state == "missing") and type(ns.TrackerClickCovers) == "function" then
		local covers, why = ns.TrackerClickCovers(entry)
		if covers then
			tip:AddLine("Out of combat, a click fixes it.", dim[1], dim[2], dim[3], true)
		elseif Plain(why, "string") then
			tip:AddLine(("A click %s."):format(why), dim[1], dim[2], dim[3], true)
		end
	end
end
function K.SampleTip(entry, tip)
	local record = records[entry.id]
	local sample, dim = record and record.sample, K.TIP.dim
	local held = K.held and not InCombatLockdown() and K.held or nil
	if not (sample and (held or testing[entry.id])) then
		return false
	end
	if sample.game then
		tip:AddLine("Sample: the game's own icon, as in a fight.", dim[1], dim[2], dim[3], true)
	else
		local text, colour = K.TipWords(entry, sample)
		tip:AddLine("Sample: " .. text, colour[1], colour[2], colour[3], true)
	end
	local source = testing[entry.id] and "The test of /flatui tracker test."
		or (held.preview and "A preview of the look you are setting." or "Test mode: fine, low and missing in turn.")
	tip:AddLine(source, dim[1], dim[2], dim[3], true)
	return true
end

function ns.TrackerTipLines(entry, tip, noClick)
	if type(entry) == "table" and type(tip) == "table" then
		K.TipLines(entry, tip, noClick)
	end
end

function K.TipShow(record)
	local tip, tips = GameTooltip, Opt("tooltips")
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return false
	end
	local entry = K.EntryById(record.entryId)
	local wanted = entry ~= nil and tips ~= "off" and not (tips ~= "on" and (fighting or InCombatLockdown())) and K.Visible(record, entry)
		and ns.Enabled(KEY)
	if not wanted then
		K.TipHide(record)
		return false
	end
	return pcall(function()
		tip:SetOwner(record.frame, "ANCHOR_TOP")
		K.TipLines(entry, tip)
		tip:Show()
	end)
end

function K.TipHide(record)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, record.frame)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

function K.TipEnter(record)
	if K.tipTicker then
		K.tipTicker:Cancel()
		K.tipTicker = nil
	end
	if not K.TipShow(record) or not (C_Timer and C_Timer.NewTicker) then
		return
	end
	K.tipRecord = record
	K.tipTicker = C_Timer.NewTicker(1, function()
		local tip = GameTooltip
		local ok, owned = pcall(tip.IsOwned, tip, record.frame)
		if not (ok and not IsSecret(owned) and owned == true and K.TipShow(record)) then
			K.TipLeave(record)
		end
	end)
end

function K.TipLeave(record)
	if K.tipRecord == record and K.tipTicker then
		K.tipTicker:Cancel()
		K.tipTicker, K.tipRecord = nil, nil
	end
	K.TipHide(record)
end

local function YesNo(name)
	local call = type(C_Secrets) == "table" and C_Secrets[name]
	if type(call) == "function" then
		local ok, answer = pcall(call)
		if ok and not IsSecret(answer) and type(answer) == "boolean" then
			return answer and "yes" or "no"
		end
	end
	return "not known"
end

local function Number(value)
	return value ~= nil and ("%d"):format(value) or "none"
end

local function NowText(reading, entry)
	local state = reading.state
	if state == "missing" then
		return "missing"
	elseif state == "unknown" then
		return reading.hidden and "not known, the game is hiding it" or "not known, the game gave no answer"
	end
	local charges = "no charges"
	if entry.kind == "group" and Plain(reading.count, "number") and Plain(reading.total, "number") then
		charges = ("%d of %d lack it"):format(reading.count, reading.total)
	elseif reading.count then
		charges = ("%s (stacks %s, charges field %s)"):format(Plural(reading.count, "charge"), Number(reading.stacks), Number(reading.charges))
	end
	local left = "no time limit"
	if reading.expires then
		local seconds = math.max(0, reading.expires - Now())
		left = ("%d:%02d left"):format(math.floor(seconds / 60), math.floor(seconds % 60))
	end
	return ("on, %s, %s"):format(charges, left)
end

local function WhyText(entry)
	local call = type(C_Secrets) == "table" and C_Secrets.GetSpellAuraSecrecy
	local levels = Enum and Enum.SecrecyLevel
	local id = entry.spells[1]
	if type(call) == "function" and type(levels) == "table" and id then
		local ok, level = pcall(call, id)
		if ok and not IsSecret(level) then
			if level == levels.ContextuallySecret then
				return "the game hides this buff only in fights."
			elseif level == levels.NeverSecret then
				return "the game never hides this buff."
			elseif level == levels.AlwaysSecret then
				return "the game always hides this buff."
			end
		end
	end
	return "the game does not say."
end

local function Join(ids)
	if type(ids) ~= "table" or #ids == 0 then
		return "none"
	end
	return table.concat(ids, ", ")
end

local function Own(entry)
	local list = {}
	for key in pairs(OWN) do
		if entry[key] ~= nil then
			list[#list + 1] = key .. " " .. Shown(key, entry[key])
		end
	end
	table.sort(list)
	return table.concat(list, ", ")
end

local function EntryLines(index, entry)
	local lines = {}
	local reading = Read(entry)
	local kind = KINDS[entry.kind]
	lines[1] = ("%s. %s, %s%s"):format(Plain(index, "number") and ("%d"):format(index) or "Class", Label(entry), kind and kind.what or "buff on you",
		entry.on == false and ", off" or "")
	lines[2] = "   Now: " .. NowText(reading, entry) .. "."
	local how = (records[entry.id] and records[entry.id].how == "drawn") and "drawn" or How(entry, reading)
	local shownAs = K.SHOWN_AS[how]
	if how == "live" and reading.state == "unknown" then
		shownAs = K.SHOWN_AS.none
	end
	if (how == "live" and reading.state == "missing") or (how == "last" and mem.kept[entry.id].state == "missing") then
		shownAs = "the red missing icon"
	end
	local drawn = records[entry.id]
	local word = drawn and drawn.shape or "icon"
	if word ~= "icon" then
		shownAs = (shownAs:gsub("the red missing icon", "the red missing " .. word):gsub("a grey icon,", (word == "text" and "grey text," or "a grey " .. word .. ",")):gsub("the game's own icon", "the game's own " .. word))
	end
	if kind and type(kind.Hide) == "function" and how ~= "game" then
		local ok, hide = pcall(kind.Hide, entry, reading, how)
		if ok and not IsSecret(hide) and hide == true then
			shownAs = "nothing"
		end
	end
	if entry.on == false or not ns.Enabled(KEY) then
		shownAs = "nothing, the tracker is off"
	end
	lines[3] = "   Shown as: " .. shownAs .. "."
	if not kind then
		lines[4] = "   Why: " .. WhyText(entry)
		lines[5] = ("   Spell IDs: %s. Last seen on you: %s. Last cast: %s. Found by name: %s."):format(Join(entry.spells),
			entry.seen or "none", mem.cast[entry.id] or "none", Join(mem.found[entry.id]))
	end
	local info = fight and fight.trackers[entry.id]
	if info then
		lines[#lines + 1] = ("   In the last fight: the game hid it: %s. Asked once: %s. Your casts noticed: %d, spell %s."):format(
			info.hidden and "yes" or "no", info.asked or "not asked", info.casts, fight.castPlain ~= false and "known" or "not known")
	end
	for _, line in ipairs(Slot("Lines", entry) or {}) do
		lines[#lines + 1] = "   " .. line
	end
	if kind and type(kind.Lines) == "function" then
		local ok, extra = pcall(kind.Lines, entry)
		for _, line in ipairs(ok and type(extra) == "table" and extra or {}) do
			lines[#lines + 1] = "   " .. tostring(line)
		end
	end
	local lowTime, here = K.LowTime(entry)
	if lowTime > 0 and K.TIMED[entry.kind] then
		lines[#lines + 1] = ("   Low at %d s here%s."):format(lowTime, here and (": " .. here) or "")
	end
	local place = Value(entry, "place")
	lines[#lines + 1] = ("   Place: %s, %s."):format(Shown("place", place), K.where[place] or "not laid out yet")
	local record, shape = records[entry.id], Value(entry, "shape")
	if record and record.refused[shape] then
		lines[#lines + 1] = ("   Shape: %s refused, drawn as an icon."):format(shape)
	elseif shape ~= "icon" and kind then
		lines[#lines + 1] = ("   Shape: %s."):format(shape)
	elseif shape ~= "icon" then
		if Opt("gameIcon") ~= false and Slot("Live", entry) == true then
			lines[#lines + 1] = ("   Shape: %s. In fights where the game hides the buff, the game draws its own %s."):format(shape, shape)
		else
			lines[#lines + 1] = ("   Shape: %s. In fights where the game hides the buff, %s."):format(shape, Opt("without") == "hidden" and "it is hidden" or "it keeps its last fill and name")
		end
	else
		lines[#lines + 1] = "   Shape: icon."
	end
	if ns.TrackerMarkLine then
		lines[#lines + 1] = "   " .. ns.TrackerMarkLine(entry)
	end
	local click = ns.TrackerClickLine and ns.TrackerClickLine(entry)
	if Plain(click, "string") then
		lines[#lines + 1] = "   " .. click
	end
	local own = Own(entry)
	if own ~= "" then
		lines[#lines + 1] = "   Own settings: " .. own .. "."
	end
	return lines
end

local function FightText()
	local lines = { "Last fight: none yet." }
	if fight then
		local length = fight.length or (Now() - fight.start)
		local unit = fight.unitPlain == nil and "" or (fight.unitPlain and ", unit named" or ", unit hidden")
		lines[1] = ("Last fight: %d s. Warning before it: %s. Buff changes noticed: %d%s."):format(length,
			fight.warned and "seen" or "not seen", fight.auras, unit)
	end
	if heard then
		lines[#lines + 1] = ("   Buff and cast events from: %s."):format(heard)
	end
	if not fight then
		return lines
	end
	if fight.warned then
		lines[#lines + 1] = ("   Kept at the warning: %s."):format(Plural(fight.kept or 0, "reading"))
	end
	local found = fight.probes
	if found then
		lines[#lines + 1] = ("   Hidden in the last fight: %s."):format(PredicateText(found.predicates))
		lines[#lines + 1] = ("   First tracker's buff in the last fight: hidden %s, level %s."):format(found.predicates.spell, found.predicates.level)
		local totems = {}
		for slot, name in ipairs(TOTEMS) do
			totems[slot] = name .. " " .. found.totems[slot]
		end
		lines[#lines + 1] = ("   Totems: %s. Totem details: %s."):format(table.concat(totems, ", "), found.details)
		lines[#lines + 1] = ("   Weapon enchant: %s. Pet: %s."):format(WeaponText(found.weapon), found.pet)
		lines[#lines + 1] = ("   Timer on a bar: %s. Timer on an icon: %s. Sweep restart: %s. Moving an icon: %s."):format(found.bar,
			found.icon, found.sweep, found.move)
	end
	for _, line in ipairs(Slot("FightLines") or {}) do
		lines[#lines + 1] = "   " .. line
	end
	return lines
end

local function SoundText()
	local own = ns.TrackerGameSound and ns.TrackerGameSound.Lines
	local lines = type(own) == "function" and own() or {}
	if gameSound == nil and #lines > 0 then
		return table.concat(lines, " ")
	end
	if gameSound == "refused" then
		return "Game's sound for a buff ending: refused by the game."
	elseif type(gameSound) == "table" then
		return ("Game's sound for a buff ending: on for %s."):format(Plural(#gameSound, "spell ID"))
	end
	return "Game's sound for a buff ending: off. /flatui tracker check sound turns it on."
end

local function Check(number)
	local entries = Entries()
	print(("Trackers: %d. The game has hidden values: %s."):format(#entries, YesNo("HasSecretRestrictions")))
	print(("Hidden now: %s."):format(PredicateText(Predicates(Buffs()[1]))))
	for index, entry in ipairs(entries) do
		if number == nil or number == index then
			for _, line in ipairs(EntryLines(index, entry)) do
				print(line)
			end
		end
	end
	local auto = ns.Enabled(KEY) and K.Auto(entries) or {}
	if number == nil and #auto > 0 then
		print(("Procs of your class: %d, shown without being added."):format(#auto))
		for _, entry in ipairs(auto) do
			for _, line in ipairs(EntryLines(nil, entry)) do
				print(line)
			end
		end
	end
	for _, line in ipairs(FightText()) do
		print(line)
	end
	print(SoundText())
end

local function CheckSound()
	if type(gameSound) == "table" then
		local call = type(C_UnitAuras) == "table" and C_UnitAuras.RemoveAuraSound
		for _, id in ipairs(gameSound) do
			pcall(call, id)
		end
		gameSound = nil
		print("Game's sound for a buff ending: off.")
		return
	end
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.AddAuraSound
	local trigger = Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Removed
	local ids, wanted = {}, 0
	for _, entry in ipairs(Buffs()) do
		for _, spellID in ipairs(entry.spells) do
			wanted = wanted + 1
			local ok, registered = pcall(call, trigger, { unitToken = "player", spellID = spellID, soundFileID = K.SOUND_FILE,
				outputChannel = "Master", throttleSeconds = 1 })
			if ok and Plain(registered, "number") then
				ids[#ids + 1] = registered
			end
		end
	end
	if wanted == 0 then
		print("No trackers.")
	elseif #ids == 0 then
		gameSound = "refused"
		print("The game refused its sound for a buff ending.")
	else
		gameSound = ids
		print(("Game's sound for a buff ending: on for %s, until /reload."):format(Plural(#ids, "spell ID")))
	end
end

local function SecretAuras()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	local ok, answer = pcall(call)
	return ok and not IsSecret(answer) and answer == true
end

local function Bare(entry)
	local record = records[entry.id]
	if record then
		Apply(record, entry, { icon = nil, sweep = "clear" })
		record.sample = { game = true }
		K.SetAlpha(record, 1)
		record.alpha = 1
		K.Mouse(record, entry)
		K.Packed(record, false)
	end
end

local function Paint(entry, state, length)
	local record = records[entry.id]
	if record then
		length = length or 600
		local reading = { state = state, hidden = false, expires = Now() + length, length = length, icon = EntryIcon(entry), count = entry.charged and 3 or nil }
		Apply(record, entry, Looks(entry, reading, "live"))
		record.sample = reading
		K.SetAlpha(record, 1)
		record.alpha = 1
		K.Mouse(record, entry)
		K.Packed(record, false)
	end
end

K.HELD_STATES, K.HELD_LENGTH, K.HELD_LOW, K.HELD_COUNT, K.HELD_LOW_COUNT = { "fine", "low", "missing" }, 600, 20, 20, 2

function K.HeldDraw(entry)
	local held, record = K.held, records[entry.id]
	if not held or not record or InCombatLockdown() or (held.only and held.only ~= entry.id) then
		return false
	end
	local kind = KINDS[entry.kind]
	local own = kind ~= nil and type(kind.Test) == "function"
	if own and not held.preview and not (type(ns.ProcHeld) == "function" and ns.ProcHeld(entry) == true) then
		return false
	end
	local state = own and "fine" or K.HELD_STATES[held.step] or "fine"
	local low = state == "low"
	local reading = { state = state, hidden = false, expires = held.at + (low and K.HELD_LOW or K.HELD_LENGTH), length = K.HELD_LENGTH,
		icon = EntryIcon(entry), count = entry.charged and state ~= "missing" and (low and K.HELD_LOW_COUNT or K.HELD_COUNT) or nil }
	record.how = "live"
	Apply(record, entry, Looks(entry, reading, "live"))
	record.sample = reading
	record.curved = nil
	if record.alpha ~= 1 then
		K.SetAlpha(record, 1)
		record.alpha = 1
	end
	K.Packed(record, false)
	K.Mouse(record)
	Slot("Show", entry, false, 1)
	return true
end

function K.HeldPaint()
	for _, entry in ipairs(OnEntries()) do
		if not testing[entry.id] then
			K.HeldDraw(entry)
		end
	end
end

function K.HeldStart()
	K.held = { step = 1, at = Now() }
end

K.PREVIEW = 4
K.OWN_LOOK = { shape = true, size = true, colour = true, x = true, y = true, place = true, missing = true, on = true }

function K.CanPreview()
	return not InCombatLockdown() and not (ns.TestMode and ns.TestMode.IsOn()) and ns.Enabled(KEY) and next(testing) == nil
		and not (K.held and not K.held.preview) and C_Timer ~= nil and C_Timer.After ~= nil
end

function K.Preview(only, step)
	local held = { step = step or 1, at = Now(), preview = true, only = only }
	K.held = held
	K.HeldPaint()
	C_Timer.After(K.PREVIEW, function()
		if K.held == held then
			K.held = nil
			Dirty()
		end
	end)
end

function K.OwnPreview(entry, key)
	if key and K.OWN_LOOK[key] and entry.on ~= false and K.CanPreview() then
		K.Preview(entry.id, key == "missing" and 3 or 1)
	end
end

function K.RowPreview(only)
	if K.CanPreview() then
		K.Preview(only, 1)
	end
end
ns.TrackerPreviewRow = K.RowPreview

function K.HeldStop()
	K.held = nil
end

function K.HeldStep()
	local held = K.held
	if held then
		held.step = held.step % #K.HELD_STATES + 1
		held.at = Now()
		K.HeldPaint()
	end
end

local function Staged(entries, run)
	local steps = {
		function()
			for _, entry in ipairs(entries) do
				Paint(entry, "fine")
			end
		end,
		function()
			for _, entry in ipairs(entries) do
				Paint(entry, "low")
			end
		end,
		function()
			for _, entry in ipairs(entries) do
				Paint(entry, "missing")
			end
			local word, heard = "Sound: played.", {}
			for _, entry in ipairs(entries) do
				local kit = K.KITS[Value(entry, "kit")] or K.KITS.raid
				if not heard[kit] then
					heard[kit] = true
					local ok, played = pcall(PlaySound, kit)
					if not ok or (not IsSecret(played) and played == false) then
						word = "Sound: failed."
					elseif not IsSecret(played) and played == nil and word == "Sound: played." then
						word = "Sound: no answer from the game."
					end
				end
			end
			print(word)
		end,
	}
	if type(ns.TrackerSlots) == "table" then
		steps[#steps + 1] = function()
			for _, entry in ipairs(entries) do
				if records[entry.id] then
					Bare(entry)
					Slot("Show", entry, true)
				end
			end
		end
		steps[#steps + 1] = function()
			for _, entry in ipairs(entries) do
				local reading = Read(entry)
				if reading.state ~= "missing" and reading.state ~= "unknown" and reading.count then
					Slot("LowTest", entry, reading.count)
				end
			end
		end
	end
	steps[#steps + 1] = function()
		for _, entry in ipairs(entries) do
			Slot("LowTest", entry, nil)
			Slot("Show", entry, false)
			testing[entry.id] = nil
		end
		Dirty()
	end
	local function Run(index)
		if run ~= testRun then
			return
		end
		steps[index]()
		if index < #steps then
			if C_Timer and C_Timer.After then
				C_Timer.After(K.STEP, function()
					Run(index + 1)
				end)
			else
				Run(index + 1)
			end
		end
	end
	Run(1)
end

local function KindTest(entries, run)
	for _, entry in ipairs(entries) do
		local kind = KINDS[entry.kind]
		Paint(entry, "fine", K.TEST)
		local ok, line = pcall(kind.Test, entry, true)
		if ok and Plain(line, "string") then
			print(line)
		end
	end
	local function Over()
		if run ~= testRun then
			return
		end
		for _, entry in ipairs(entries) do
			pcall(KINDS[entry.kind].Test, entry, false)
			testing[entry.id] = nil
		end
		Dirty()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(K.TEST, Over)
	else
		Over()
	end
end

function K.TestCut()
	testRun = testRun + 1
	local cut = testing
	testing = {}
	for _, entry in pairs(cut) do
		Slot("LowTest", entry, nil)
		local kind = KINDS[entry.kind]
		if kind and type(kind.Test) == "function" then
			pcall(kind.Test, entry, false)
		end
	end
	print("Trackers: the pull ended the test.")
	ns.OutOfCombat(function()
		for _, entry in pairs(cut) do
			if not testing[entry.id] then
				Slot("LowTest", entry, nil)
				Slot("Show", entry, false)
			end
		end
		Dirty()
	end)
end

local function Test(number)
	if InCombatLockdown() or SecretAuras() then
		print("The test runs out of combat.")
		return
	end
	local entries, kinds = {}, {}
	for index, entry in ipairs(Entries()) do
		if (number == nil or number == index) and records[entry.id] then
			local kind = KINDS[entry.kind]
			local group = (kind ~= nil and type(kind.Test) == "function") and kinds or entries
			group[#group + 1] = entry
		end
	end
	for _, entry in ipairs(number == nil and K.Auto() or {}) do
		local kind = KINDS[entry.kind]
		if records[entry.id] and kind ~= nil and type(kind.Test) == "function" then
			kinds[#kinds + 1] = entry
		end
	end
	if #entries == 0 and #kinds == 0 then
		print(number and ("No tracker numbered %d."):format(number) or "No trackers.")
		return
	end
	testRun = testRun + 1
	for _, old in pairs(testing) do
		Slot("LowTest", old, nil)
		local kind = KINDS[old.kind]
		if kind and type(kind.Test) == "function" then
			pcall(kind.Test, old, false)
		end
	end
	testing = {}
	for _, group in ipairs({ entries, kinds }) do
		for _, entry in ipairs(group) do
			testing[entry.id] = entry
		end
	end
	Dirty()
	if #entries > 0 then
		print("Test: fine, low, missing, then the game's own look. 3 seconds each.")
		Staged(entries, testRun)
	end
	if #kinds > 0 then
		print(("Test: the icon and the sound of each proc. %d seconds."):format(K.TEST))
		KindTest(kinds, testRun)
	end
end

local function Find(text)
	local entries = Entries()
	if text:find("^%d+$") then
		return entries[tonumber(text)], tonumber(text)
	end
	local wanted = text:lower()
	for index, entry in ipairs(entries) do
		if Label(entry):lower() == wanted then
			return entry, index
		end
		for _, name in ipairs(entry.names or {}) do
			if name:lower() == wanted then
				return entry, index
			end
		end
	end
	return nil
end

local function Slash(rest)
	local word, text = rest:match("^(%S*)%s*(.-)$")
	word = word:lower()
	if word == "add" and text ~= "" then
		local first, argument = text:match("^(%S+)%s*(.-)$")
		if KINDS[first:lower()] then
			print((select(2, ns.TrackerAddKind(first:lower(), argument))))
			return
		end
		local id = Resolve(text)
		if not id then
			print(('No spell found for "%s".'):format(text))
			return
		end
		print((select(2, ns.TrackerAddBuff(id))))
	elseif word == "class" then
		print((select(2, ns.TrackerAddClass(1))))
	elseif word == "remove" and text ~= "" then
		local _, position = Find(text)
		if not position then
			print(('No tracker found for "%s".'):format(text))
			return
		end
		print((select(2, ns.TrackerRemove(position))))
	elseif word == "back" then
		print((select(2, ns.TrackerBringBack(1))))
	elseif word == "list" then
		local entries = Entries()
		if #entries == 0 then
			print("No trackers.")
		end
		for index, entry in ipairs(entries) do
			local count = 0
			for key in pairs(OWN) do
				count = count + (entry[key] ~= nil and 1 or 0)
			end
			local kind = KINDS[entry.kind]
			print(("%d. %s, %s%s%s"):format(index, Label(entry), kind and kind.what or "buff on you", entry.on == false and ", off" or "",
				count > 0 and (", place %s, %s"):format(Shown("place", Value(entry, "place")), Plural(count, "own setting")) or ""))
		end
	elseif word == "export" and ns.TrackerExport then
		if text == "" and ns.OpenPanelShare then
			ns.OpenPanelShare()
			return
		end
		if text ~= "" and not tonumber(text) then
			print(('No tracker numbered %s.'):format(text))
			return
		end
		for _, line in ipairs((select(2, ns.TrackerExport(tonumber(text))))) do
			print(line)
		end
	elseif word == "import" and ns.TrackerImport then
		if text == "" and ns.OpenPanelShare then
			ns.OpenPanelShare()
			return
		end
		print((select(2, ns.TrackerImport(text))))
	elseif word == "set" then
		local number, setting, value = text:match("^(%d+)%s+(%S+)%s*(.-)$")
		if not number then
			for _, line in ipairs(HELP) do
				print(line)
			end
			return
		end
		print((select(2, ns.TrackerSet(tonumber(number), setting, value))))
	elseif word == "check" then
		if text:lower() == "sound" then
			CheckSound()
		else
			Check(tonumber(text))
		end
	elseif word == "test" then
		Test(tonumber(text))
	elseif K.commands[word] then
		local ok, line = pcall(K.commands[word], text)
		if ok and Plain(line, "string") then
			print(line)
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

local function ClassLabel()
	local row = PageRow("addClass")
	if row then
		row.label = ("Add %s trackers"):format((ClassInfo()) or "class")
	end
end

ClassLabel()

local function Refresh()
	ClassLabel()
	K.inside = nil
	if ns.Enabled(KEY) then
		Watch()
		if fighting and not InCombatLockdown() then
			fighting = false
			EndFight()
		end
	end
	if not ns.Enabled(KEY) then
		HideHolders()
		K.EndKinds()
		if ns.TrackerMarkSweep then
			ns.TrackerMarkSweep()
		end
		if ns.TrackerClickSweep then
			ns.OutOfCombat(function()
				ns.TrackerClickSweep()
			end)
		end
	else
		for _, record in ipairs(shown) do
			record.parent:Show()
		end
	end
	QueueLayout()
	Dirty()
	GameSound()
end

K.KIT_NAMES = { spell = "Spell alert", chimes = "Chimes", bell = "Bell", warhorn = "Warhorn" }
K.KIT_WARN = "Trackers: %s plays for a buff between fights only. In a fight the game plays only Raid warning, Alarm or Whisper warning."

function K.KitWarn(word, entry)
	local name, fights = K.KIT_NAMES[word], ns.TrackerKitInFights
	if not name or type(fights) ~= "function" or fights(word) then
		return
	end
	if entry and not (entry.kind == nil or entry.kind == "buff" or entry.kind == "debuff") then
		return
	end
	for _, row in ipairs({ "sound", "comes", "stacks" }) do
		local on
		if entry then
			on = Value(entry, row)
		else
			on = Opt(row)
		end
		if on == true then
			print(K.KIT_WARN:format(name))
			return
		end
	end
end

function ns.TrackerKitChanged()
	ns.Try(KEY, Refresh)
	if not InCombatLockdown() and type(ns.PlayKit) == "function" then
		ns.PlayKit(K.KITS[Opt("kit")] or K.KITS.raid, KEY)
	end
	K.KitWarn(Opt("kit"))
end

function ns.TrackerLookChanged(path)
	ns.Try(KEY, Refresh)
	if K.CanPreview() then
		K.Preview(nil, path == KEY .. ".missing" and 3 or 1)
	end
end

K.READY, K.LINE_GAP, K.COUNT_MOST, K.PLAYER_COUNTDOWN = 12, 15, 30, 2
K.READY_MOST, K.COUNT_GUESS, K.NAMES_MOST = 60, 10, 3

function ns.TrackerReminding()
	return K.readyUntil ~= nil and not fighting and Now() < K.readyUntil
end

function K.Named(entry, state, kept)
	local label = Label(entry)
	if entry.kind == "group" and state == "missing" and Plain(kept.count, "number") and Plain(kept.total, "number") and kept.total > 0 then
		local who = type(ns.TrackerGroupWho) == "function" and ns.TrackerGroupWho(entry, K.NAMES_MOST, kept.count) or nil
		return ("%s is missing on %d of %d%s"):format(label, kept.count, kept.total, Plain(who, "string") and (" (%s)"):format(who) or "")
	elseif entry.kind == "durability" then
		if state == "missing" then
			return label .. " is broken"
		elseif Plain(kept.count, "number") then
			return ("%s is low (%d%%)"):format(label, kept.count)
		end
	end
	return label .. (state == "missing" and " is missing" or " is low")
end

function K.ReadyLine(words)
	if not K.readyUntil or fighting or InCombatLockdown() or Now() >= K.readyUntil or not ns.Enabled(KEY) then
		return
	end
	local missing, low = {}, {}
	for _, entry in ipairs(Entries()) do
		local kind, kept = KINDS[entry.kind], mem.kept[entry.id]
		local state = entry.on ~= false and not (kind and kind.noDrop == true) and kept and Plain(kept.state, "string") and kept.state or nil
		if state == "low" or state == "missing" then
			local hidden = false
			if kind and type(kind.Wanted) == "function" then
				local ok, alpha = pcall(kind.Wanted, entry, state, "live", fighting)
				hidden = ok and not IsSecret(alpha) and alpha == 0
			end
			if not hidden then
				local list = state == "missing" and missing or low
				list[#list + 1] = K.Named(entry, state, kept)
			end
		end
	end
	for _, text in ipairs(low) do
		missing[#missing + 1] = text
	end
	if #missing > 0 then
		local last = table.remove(missing)
		local text = #missing > 0 and (table.concat(missing, ", ") .. " and " .. last) or last
		K.lineAt = Now()
		print(("Flat UI: %s, %s."):format(words, text))
	end
end

function K.Reminder(why, length, words)
	local now = Now()
	K.reminders = K.reminders or {}
	K.reminders[why] = now + length
	K.serial = (K.serial or 0) + 1
	K.serials = K.serials or {}
	K.serials[why] = K.serial
	K.ReminderEnds()
	Dirty()
	if C_Timer and C_Timer.After then
		local stamp = K.serial
		if words then
			C_Timer.After(PASS + 0.15, function()
				if K.reminders and K.reminders[why] and K.serials[why] == stamp then
					ns.Try(KEY, K.ReadyLine, words)
				end
			end)
		end
		C_Timer.After(length + 0.05, Dirty)
	end
end

function K.ReminderEnds()
	local most, now = nil, Now()
	for why, ends in pairs(K.reminders or {}) do
		if ends <= now then
			K.reminders[why] = nil
		elseif not most or ends > most then
			most = ends
		end
	end
	K.readyUntil = most
end

function K.ReminderOff(why)
	if why then
		if K.reminders then
			K.reminders[why] = nil
		end
	else
		K.reminders = nil
	end
	K.ReminderEnds()
end

function K.ReadyCheck(left)
	if not Opt("readyCheck") or InCombatLockdown() or not ns.Enabled(KEY) then
		return
	end
	local length = (not IsSecret(left) and ns.Finite(left)) and math.max(K.READY, math.min(left, K.READY_MOST)) or K.READY
	K.readyStart = Now()
	K.Reminder("ready", length, "for the ready check")
end

function K.ReadyDone()
	local ends = K.reminders and K.reminders.ready
	if not ends then
		return
	end
	local now = Now()
	local stop = math.max((K.readyStart or now) + K.READY, now)
	if stop >= ends then
		return
	end
	K.reminders.ready = stop
	K.ReminderEnds()
	Dirty()
	if C_Timer and C_Timer.After then
		C_Timer.After(stop - now + 0.05, Dirty)
	end
end

function K.PlayerType()
	local enums = type(Enum) == "table" and not IsSecret(Enum) and Enum.StartTimerType or nil
	local value = type(enums) == "table" and enums.PlayerCountdown or nil
	return (not IsSecret(value) and ns.Finite(value)) and value or K.PLAYER_COUNTDOWN
end

function K.PlayerCountdown(kind)
	if IsSecret(kind) or not ns.Finite(kind) then
		return false
	end
	return kind == K.PlayerType()
end

function K.PullWords(who)
	local name = Plain(who, "string") and who:match("^[^%-]+") or nil
	local mine = Ask(UnitName, "player")
	if name and name ~= "" and not (Plain(mine, "string") and mine == name) then
		return ("before %s's pull"):format(name)
	end
	return "before the pull"
end

function K.Countdown(kind, remaining, who)
	if not Opt("readyCheck") or InCombatLockdown() or fighting or not ns.Enabled(KEY) or not K.PlayerCountdown(kind) then
		return
	end
	if IsSecret(remaining) or not ns.Finite(remaining) then
		remaining = K.COUNT_GUESS
	elseif remaining <= 0 then
		return
	end
	local recent = K.lineAt and Now() - K.lineAt < K.LINE_GAP
	K.Reminder("countdown", math.min(remaining, K.COUNT_MOST) + 2, not recent and K.PullWords(who) or nil)
end

function K.CountdownStop(kind)
	if K.PlayerCountdown(kind) and K.reminders and K.reminders.countdown then
		K.ReminderOff("countdown")
		Dirty()
	end
end

ns.Register(KEY, {
	label = "Trackers",
	Start = Refresh,
	Refresh = Refresh,
	Resized = QueueLayout,
	events = {
		ADDON_RESTRICTION_STATE_CHANGED = Restriction,
		PLAYER_REGEN_DISABLED = FightStarts,
		PLAYER_REGEN_ENABLED = FightEnds,
		PLAYER_ENTERING_WORLD = Entered,
		PLAYER_DEAD = Dirty,
		PLAYER_ALIVE = Dirty,
		PLAYER_UNGHOST = Dirty,
		PLAYER_MOUNT_DISPLAY_CHANGED = Dirty,
		PLAYER_CONTROL_LOST = Dirty,
		PLAYER_CONTROL_GAINED = Dirty,
		PLAYER_UPDATE_RESTING = Dirty,
		SPELLS_CHANGED = SpellsChanged,
		READY_CHECK = function(_, left)
			ns.Try(KEY, K.ReadyCheck, left)
		end,
		READY_CHECK_FINISHED = function()
			ns.Try(KEY, K.ReadyDone)
		end,
		START_TIMER = function(kind, remaining)
			ns.Try(KEY, K.Countdown, kind, remaining)
		end,
		STOP_TIMER_OF_TYPE = function(kind)
			ns.Try(KEY, K.CountdownStop, kind)
		end,
		START_PLAYER_COUNTDOWN = function(_, remaining, _, _, who)
			ns.Try(KEY, K.Countdown, K.PlayerType(), remaining, who)
		end,
		CANCEL_PLAYER_COUNTDOWN = function()
			ns.Try(KEY, K.CountdownStop, K.PlayerType())
		end,
	},
	slash = { tracker = Slash },
	help = HELP,
	counted = "shown",
})

ns.TestMode.Register(KEY, {
	module = KEY,
	label = "Trackers",
	refresh = true,
	Start = K.HeldStart,
	Stop = K.HeldStop,
	every = 4,
	Tick = K.HeldStep,
})
