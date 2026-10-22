local _, ns = ...

-- A row of flat square icons for the buffs on the player that the player picks: one icon for each, with
-- its charges, a sweep and countdown, a red rim when it is low, a red icon when it is missing, and a
-- sound when it drops. In fights the game withholds aura values from addons, so a buff is checked only
-- while C_Secrets says its values are open. While they are not, the icon shows the game's own drawing
-- of the buff where ns.TrackerSlots has one, else what was known last. Nothing runs every frame: an
-- event marks the trackers dirty and one pass follows at most every 0.2 seconds, and a moment known
-- ahead (a buff turning low by its time) is one timer. Frames are made and laid out out of combat; a
-- pass is texture, text, alpha, Cooldown and animation calls, which are allowed in combat. Every value
-- from the game is tested with ns.IsSecret before it is compared, indexed, joined or kept, and a
-- withheld value is only ever handed on to a widget call that takes it. The test file reads this file
-- and TrackerSlots.lua as text and fails on a comparison of such a value that has no IsSecret before it.
-- What was known last is all there is to show while the values are withheld: a buff that was missing then
-- is drawn as missing only when the player can cast it, since only the player's own cast can end that.

local KEY = "trackers"
-- The name of the row among the saved spots of the movers.
local MOVER = "FlatUITrackers"
local CROP = 0.08
-- Units between the personal resource display and the row. The space between two icons is the Spacing setting.
local GAP = 4
-- Seconds between two passes.
local PASS = 0.2
local UNKNOWN_ICON = 134400
-- ffd94040, the colour of a low or missing buff.
local RED = { 0.851, 0.251, 0.251 }
-- The bars of the personal resource display, highest first.
local RESOURCE_BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local TOTEMS = { "fire", "earth", "water", "air" }
local NO_POSITION = "Trackers: the personal resource display cannot be used, so the row is beside the character."
local NO_SOUND = "Trackers: the game played no sound, so Sound when it drops is silent."
local SWEEP_REFUSED = "Trackers: the game refused to restart a time sweep, so the sweep shows the last known time."
-- The rest of the constants, in one table so the file stays under the limit of locals.
--   MAX_*: the most trackers, spells, names per tracker, characters of a name and the largest spell ID.
--   BESIDE: units from the middle of the screen to the left edge of the row beside the character.
--   RIM: the rim inside an icon, in screen pixels.
--   QUIET, LATE, STEP, TEST: seconds with no sound after login, before the second look of the probes, for each look of the test, and for a kind's own test.
--   SOUND_FILE: the file of sound kit 8959 in this build's SoundKitEntry table.
--   PULSE_LOW, PULSE_TIME: the lowest alpha of the pulse and its length in seconds.
--   SHOWN_AS: what each way of drawing says in the check.
--   HIDDEN: a reading for a buff the game is hiding, for drawing it at once.
local K = {
	MAX_TRACKERS = 40, MAX_SPELLS = 40, MAX_NAMES = 8, MAX_CHARS = 40, MAX_ID = 2147483647,
	BESIDE = 150, RIM = 2, QUIET = 2, LATE = 5, STEP = 3, TEST = 5, SOUND_FILE = 567397,
	-- LOW_MAX: the largest Low at of a tracker's own, by kind; 20 for the kinds that are not here.
	LOW_MAX = { item = 1000, ammo = 2000 },
	PULSE_LOW = 0.35, PULSE_TIME = 0.6, GREY = 0.6, ID_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789",
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
	-- The filter of the player's own debuffs on the target, for the reading and for the game's own icon.
	DEBUFF_FILTER = "HARMFUL|PLAYER",
	NO_PULSE = "Trackers: the game gave no animation, so the missing icon does not pulse.",
	HIDDEN = { state = "unknown", hidden = true },
	-- KITS: the sound kits a tracker can play, by their saved word: 8959 RAID_WARNING, 12889 ALARM_CLOCK_WARNING_3,
	-- 37666 UI_RAID_BOSS_WHISPER_WARNING.
	KITS = { spell = 23287, chimes = 316736, bell = 316773, warhorn = 316723, raid = 8959, alarm = 12889, whisper = 37666 },
	-- The places a row can be at, in the order they are laid out.
	ORDER = { "resource", "character", "own" },
	-- The words of /flatui tracker set, and the saved key each one stands for.
	WORDS = { place = "place", show = "show", low = "low", lowtime = "lowTime", missing = "missing", sound = "sound", kit = "kit",
		size = "size", x = "x", y = "y", name = "name", on = "on", shape = "shape", colour = "colour" },
	-- Where each place put its row at the last layout, in words.
	where = {},
	-- The rows other files add to the Tracker page's editor, each { key, kind }, in the order they were added.
	extra = {},
	-- The events the kinds of tracker listen for, by name, and which of them the watcher has registered.
	events = {}, registered = {},
	-- The unit an event of a kind is heard for, when it is not the player.
	units = {},
	-- The words of /flatui tracker that a kind of tracker adds, by word: ns.TrackerWord(word, fn).
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
	"/flatui tracker add proc Shadow Trance for Shadow Bolt - a proc alert: its buff, then the spell it is for",
	"/flatui tracker class - add the usual trackers of your class",
	"/flatui tracker remove 1 - a number from the list, or a name",
	"/flatui tracker list",
	"/flatui tracker export - opens Share, to copy every tracker as text",
	"/flatui tracker import - opens Share, to paste trackers",
	"/flatui tracker set 1 low 2 - one tracker's own value for a setting, or clear to use the page's",
	"/flatui tracker set 1 shape bar - icon, bar or text, and colour 4d99e6 for a bar or text",
	"/flatui tracker set 1 happy on - a pet tracker is low while a hunter's pet is not happy",
	"/flatui tracker proc colour 1 ffd100 - one proc's colour, time (proc time 1 10) or trigger (proc trigger 1 overlay)",
	"/flatui tracker check - what each tracker shows and why, and what happened in the last fight",
	"/flatui tracker check sound - the game's own sound when a tracked buff ends, until /reload",
	"/flatui tracker test - each look for 3 seconds: fine, low, missing, then the game's own look",
}

local IsSecret = ns.IsSecret

-- The kinds of tracker that are not a buff, by name: ns.TrackerKind(name, spec) stores a spec { Read, events, Clean, Add, Label, Icon,
-- Lines, what, hiddenAble }. A buff is the kind of an entry with no spec here.
local KINDS = {}

-- The name of the part of the module that a kind of tracker isolates itself in: the kind's own word, or its part.
local function Part(name)
	local kind = KINDS[name]
	return kind and type(kind.part) == "string" and kind.part or name
end

-- The unit and the aura filter the game's own icon of a tracker is made for, or nil when the tracker has no icon of the game's: a buff on
-- the player, or the slot a kind of tracker names. An entry with no kind is a buff.
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

-- The frames the rows hang from, by place. The holder of the page's place is "page", so it stays the same frame when the page's place
-- changes; a tracker with a place of its own has the holder of that place.
local holders = {}
-- The record of each tracker on screen, by the id of its entry, the records waiting for the next tracker
-- and the records in row order. The waiting records are in a list for each pool: the unit and the filter of the slot an entry has, or "none" for a
-- kind with no slot. A frame keeps its aura container for good, and the container's unit is fixed when it is made.
local records, free, shown = {}, {}, {}
-- What is known of each tracker, by the id of its entry: the last reading that was not unknown, the length
-- of the last buff that had one, the moment a drop was first seen, the moment a timer was set for, the
-- spell ID of the last own cast and the spell IDs found by name.
local mem = { kept = {}, lengths = {}, drops = {}, woken = {}, cast = {}, found = {} }
-- Trackers the test is drawing.
local testing = {}
-- The record of the last fight, and whether the player is in one.
local fight
local fighting = false
local entered, lastPass = nil, -100
local waiting, edited, layoutQueued = false, false, false
-- How many trackers are on, as the last layout counted them: with none, an event asks for nothing.
local tracked = 0
local watcher, scratch
-- Which units the watcher hears, "the player" or "all units", and the IDs of the spells the player can
-- cast as the last walk of the spell book found them, nil before a walk.
local heard, bookIds
-- The ids of the game's sound for a buff ending, "refused" or nil.
local gameSound
local testRun = 0
local Dirty, QueueLayout

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
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

-- A field of a table or frame, or nil when it is missing, cannot be read or is withheld.
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

-- "1 charge", "3 charges".
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

-- Runs a call of ns.TrackerSlots, the game's own icon, bar or text, when it has the table and the call.
-- The game's own icons are for the entries that have a slot spec, the buffs and the kinds that name one: a call about the entry of another kind
-- gives nothing, and Sync is given those entries alone.
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

-- The list --------------------------------------------------------------------------------------

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

-- The own values an entry may hold, and what each may be. A kind of tracker may give its own test of a value in its spec, own = { key = fn }.
local OWN = {
	show = function(value)
		return K.SHOWS[value] == true
	end,
	low = function(value, entry)
		local top = entry and K.LOW_MAX[entry.kind] or 20
		return Plain(value, "number") and value >= 0 and value <= top and value == math.floor(value)
	end,
	lowTime = function(value)
		return Plain(value, "number") and value >= 0 and value <= 300 and value % 5 == 0
	end,
	missing = function(value)
		return K.MISSING_LOOKS[value] == true
	end,
	sound = function(value)
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

-- True when the list holds exactly the values of the clean list.
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

-- Cleans the fields every kind of entry has: the id, which is new when it is not six characters, not unique or not there, the
-- switch, the count fields and the own values.
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
	-- Set while the count of the buff is in its charges field, which the game's own icon does not show.
	if entry.chargesField ~= true then
		entry.chargesField = nil
	end
	if not Whole(entry.seen) then
		entry.seen = nil
	end
	-- The most charges seen, the full length of a bar filled by charges.
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

-- Cleans the spells and the names of an entry that has an aura to find, in place. False when it has nothing to go by and is dropped. The
-- kinds that are read like a buff clean with it too (ns.TrackerCleanSpells).
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

-- Cleans a buff entry in place. False when it has nothing to go by and is dropped. A kind of tracker that is a buff with more to it cleans its
-- spells and names with this and names its own kind; with no list of taken IDs the common fields are left to the list, which cleans them after.
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

-- The saved entries of this character: tables of the kind buff and of the kinds that are registered cleaned, entries of any other
-- kind kept as they are, at most 40 in all. Written back only when an entry was dropped.
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

-- The trackers of every kind this build knows, in list order. An entry of a kind no build here knows stays in the saved list and is
-- not a tracker.
local function Entries()
	local entries = {}
	for _, entry in ipairs(List()) do
		if entry.kind == "buff" or KINDS[entry.kind] then
			entries[#entries + 1] = entry
		end
	end
	return entries
end

-- The buff trackers alone, for what only a buff has: spells, names, an aura.
local function Buffs()
	local buffs = {}
	for _, entry in ipairs(Entries()) do
		if entry.kind == "buff" then
			buffs[#buffs + 1] = entry
		end
	end
	return buffs
end

-- The trackers that are on, in list order.
local function OnEntries()
	local on = {}
	for _, entry in ipairs(Entries()) do
		if entry.on ~= false then
			on[#on + 1] = entry
		end
	end
	return on
end

-- The tracker's own value of a setting, else the page's.
local function Value(entry, key)
	local own = entry[key]
	if own ~= nil then
		return own
	end
	return ns.Get(KEY .. "." .. key)
end
ns.TrackerValue = Value
ns.TrackerKits = K.KITS

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

-- The icon of a tracker with nothing on screen to take it from.
local function EntryIcon(entry)
	local id = entry.seen or (entry.spells and entry.spells[1])
	if id then
		return SpellIcon(id)
	end
	local kind = KINDS[entry.kind]
	local icon = kind and Ask(kind.Icon, entry)
	return (Plain(icon, "number") or Plain(icon, "string")) and icon or UNKNOWN_ICON
end

-- Forgets what was known of a tracker that is no longer on.
local function Forget(id)
	for _, memory in pairs(mem) do
		memory[id] = nil
	end
end

-- Adding and removing ---------------------------------------------------------------------------

-- A spell ID or a spell link, without asking the game whether the spell exists.
local function Parse(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

-- The game's name for the player's class and the class token (UnitClass, UnitDocumentation.lua:911-928), each nil when the game gives none or
-- withholds it.
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

-- The starting trackers of the character's class, in the order of the data: the class token picks the list, no token gives none.
local function ClassList()
	local _, token = ClassInfo()
	local lists = ns.ClassTrackers
	if type(lists) == "table" and token and type(lists[token]) == "table" then
		return lists[token]
	end
	return {}
end

-- The IDs of the class data that are this spell by its own name, for every rank of a spell the game was asked about by name.
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
		-- A name the game does not answer for, as the class data lists it: the first rank it has.
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

-- The spell book, or nil when the game lacks a call the walk through it needs.
local function SpellBook()
	local book = C_SpellBook
	if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
		and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType then
		return book
	end
	return nil
end

-- Calls visit(slot, spellID, item, bank) for each spell of the player that the book lists.
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

-- True when the player can cast a spell the tracker lists, as the last walk of the spell book found it. The walk is
-- made again after SPELLS_CHANGED, and a walk that finds no spell is not kept. A game with no spell book to walk
-- cannot say, which counts as no.
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

-- Adds an ID to a tracker's spells and asks for the new list to be passed on. False when it is there
-- already or the list is full.
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

-- Class starting lists (ClassData.lua) ----------------------------------------------------------

-- True when the character knows one of the spells: the game's two known tests first, then the spell book walk.
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

-- True when the bags hold one of the items.
local function CarriesAny(ids)
	for _, id in ipairs(ids or {}) do
		local count = Ask(type(C_Item) == "table" and C_Item.GetItemCount, id, false, true)
		if Plain(count, "number") and count > 0 then
			return true
		end
	end
	return false
end

-- A copy of a data entry, with its own lists, for the saved list.
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

-- The first ID a data entry has to go by: a spell, an item, else nothing.
local function FirstOf(row)
	return (row.spells or row.items or row.apply or row.summon or {})[1]
end

-- True when a tracker on the list is this entry already: the same name, the same slot of a weapon or totem, the same single kind, or
-- the first spell or item of the entry in a tracker of its kind.
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

-- Why an entry is not added, or nil: a buff, a form and a totem need a spell the character knows, an item the bags. A weapon enchant, the
-- pet and the ammunition are added for every character of the class.
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

-- The lines of Add <class> trackers: All is 1 (the line Choose one has the value 0), then each starting tracker of the class by its place
-- in the data and one.
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

-- Adds the starting trackers of the class: all of them for 1, else the one the line names (its place in the data and one). Only what the
-- character knows or carries is added,
-- a tracker already on the list is left as it is, and the list stops at 40. Works in combat, like the other adds.
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
	end
	return added > 0, table.concat(parts, " ")
end

-- All four work in combat and with the page off, since they change what is saved and nothing on screen.
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
		-- Every rank of the spell has its own ID, and the buff may come from any of them.
		WalkBook(book, function(_, id)
			if SpellName(id) == name then
				Learn(entry, id, false)
			end
		end)
	end
	-- The ranks the class data lists for this buff, which the spell book walk does not find when a rank is not learned yet.
	for _, id in ipairs(ClassIds(name) or {}) do
		Learn(entry, id, false)
	end
	list[#list + 1] = entry
	edited = false
	QueueLayout()
	return true, ("Added %s."):format(name)
end

-- The IDs of a spell and of every rank of it that the spell book lists, by the spell's name, the spell's own ID first.
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

-- Adds a tracker of a kind that is registered. The kind's Add is given what was picked and the trackers there are, and gives the entry's
-- own fields and a message, or nil and the message that says why not. Works in combat, like the other adds.
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
	return true, Plain(message, "string") and message or "Added."
end

-- The known spells of the book that are helpful, highest rank only, that no tracker has by name, by name.
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

-- The known spells of the book that are harmful, highest rank only, that no debuff tracker has by name, by name: the lines of the Add a debuff on
-- the target row.
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

-- The IDs of every rank of a spell that the book lists by its name, for a tracker whose aura may come from any of them.
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

-- Forgets the reading kept for a tracker, when what it was a reading of is gone: a debuff on a target that is not the target now.
function ns.TrackerUnkeep(id)
	mem.kept[id], mem.drops[id] = nil, nil
end

-- The trackers in list order, so opening the list also shows what is tracked.
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
			break
		end
	end
	QueueLayout()
	return true, ("Removed %s."):format(Label(entry))
end

-- What TrackerShare.lua needs: the own keys of an entry, and the layout asked for again after trackers are added.
ns.TrackerOwnKeys = OWN
function ns.TrackerLayout()
	QueueLayout()
end

-- The row of the page for a saved key of a tracker, for the kind of value and the choices it has.
local function PageRow(key)
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			if item.path == KEY .. "." .. key then
				return item
			end
		end
	end
end

-- A saved value as the page shows it: the name of a choice, on or off, or the number.
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

-- A value typed for a tracker, as the value it is saved as: a number, on or off, or the saved word of a choice, given by the word or
-- by the name the page shows. Nil when the text is none of them.
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

-- Gives a tracker a value of its own for a setting, or takes it back with the text clear; with the text clear and no setting, takes back
-- every own value. The word is a key of K.WORDS. Works in combat: the row is laid out when combat ends.
function ns.TrackerSet(index, word, text)
	local entry = Whole(index) and Entries()[index]
	if not entry then
		return false, ("No tracker numbered %s."):format(tostring(index))
	end
	word = Plain(word, "string") and word:lower() or ""
	text = Plain(text, "string") and text:match("^%s*(.-)%s*$") or ""
	local function Done(message)
		edited = true
		QueueLayout()
		Dirty()
		return true, message
	end
	if word == "clear" and text == "" then
		for key in pairs(OWN) do
			entry[key] = nil
		end
		entry.happy = nil
		return Done(("Tracker %d: every setting follows the pages."):format(index))
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
		return Done(("Tracker %d: %s follows the page."):format(index, word))
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
	return Done(("Tracker %d: %s is %s."):format(index, word, text))
end

-- The editor on the Tracker page -----------------------------------------------------------------

-- Adds a row to the editor of the Tracker page, after the rows of its template: key is the saved key of the tracker's own value and kind is
-- bool, number, choice, colour or text. The row takes its label and choices from the Trackers page row with the same key.
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

-- The trackers as the editor lists them: the id, the line of the list, the name and the largest Low at.
function ns.TrackerEditorLines()
	local lines = {}
	for index, entry in ipairs(Entries()) do
		local label = Label(entry)
		lines[index] = { id = entry.id, text = index .. ". " .. label, name = label, lowMax = K.LOW_MAX[entry.kind] or 20, kind = entry.kind }
	end
	return lines
end

-- The tracker's own value of a key, or nil when it has none.
function ns.TrackerOwn(index, key)
	local entry = Whole(index) and Entries()[index]
	if entry and Plain(key, "string") then
		return entry[key]
	end
	return nil
end

-- Gives a tracker its own value for a key, or takes it back with nil. The keys are name, on, spells and the keys of OWN. Returns true, or false
-- and a sentence. Works in combat: the row is laid out when combat ends.
function ns.TrackerSetOwn(index, key, value)
	local entry = Whole(index) and Entries()[index]
	if not entry then
		return false, ("No tracker numbered %s."):format(tostring(index))
	end
	local function Done()
		edited = true
		QueueLayout()
		Dirty()
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

	return Done()
end

-- Takes back every own value of a tracker. The name, the spells and the switch stay.
function ns.TrackerClear(index)
	return ns.TrackerSet(index, "clear", "")
end

-- Moves a tracker up (delta -1) or down (1) the list, past the next one that is a tracker here.
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
	return true
end

-- The buff check ----------------------------------------------------------------------------------

-- True only when the game plainly says that aura queries by name are open.
local function AurasOpen()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) == "function" then
		local ok, answer = pcall(call)
		return ok and not IsSecret(answer) and answer == false
	end
	return not InCombatLockdown()
end

-- True when the game would hand back withheld values for a listed ID. Without the call, in a fight. A tracker
-- with a name and no ID has nothing to ask about, so it is hidden whenever buffs are hidden at all.
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

-- The aura a call gave: the table, nil for none, and false when the call failed or gave nothing usable.
local function Answer(ok, found)
	if not ok or IsSecret(found) then
		return false
	end
	if found == nil then
		return nil
	end
	return type(found) == "table" and found or false
end

-- Asks for a time to be looked at again: a buff turning low by its time is the one moment known ahead.
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

-- Whether a buff of the list is on the player: true, false, or nil when the game hides the answer or gives none. For a kind whose check
-- depends on a buff, such as the buffs that excuse a missing pet.
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

-- The reading of the aura that was found, or of none: missing, and unknown when a call failed. The guards of every field are here, for a buff
-- on the player and a debuff on the target alike.
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
		-- A text tracker is as wide as the strings it shows, and now has a count.
		if Value(entry, "shape") == "text" then
			QueueLayout()
		end
	end
	-- The game's own icon writes the stacks field alone. A count that is in the charges field is not shown there.
	if count and (entry.chargesField == true) ~= (Positive(stacks) == nil) then
		entry.chargesField = Positive(stacks) == nil or nil
		edited = true
	end
	local state = "fine"
	local low, lowTime = Value(entry, "low"), Value(entry, "lowTime")
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

-- What one tracker's buff is now: { state = "fine" | "low" | "missing" | "unknown", hidden, count,
-- stacks, charges, expires, length, icon, id }. An unknown reading says nothing about the buff.
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
	-- Another rank of the buff has an ID the tracker does not list yet.
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

-- What the target is to the player, from plain answers alone: "attackable"; "none" when nothing is targeted, it cannot be attacked or it is dead;
-- nil when the game withholds an answer or gives none.
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

-- Another rank of a debuff has an ID the tracker does not list yet: the aura found by name on the target, its ID, and whether a call failed.
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

-- What the player's own debuff on the target is now, as a buff on the player is read. With no target to attack the reading is unknown and absent,
-- and the tracker is not wanted.
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
	-- An element whose ID is withheld may be the debuff: with no match the reading is not a plain "missing".
	failed = failed or (aura == nil and unread)
	local named = false
	if aura == nil and not failed and #entry.names > 0 and type(units.GetAuraDataBySpellName) == "function" and AurasOpen() then
		aura, auraID, failed = K.DebuffByName(entry)
		named = aura ~= nil
	end
	local reading = Settle(entry, aura, auraID, failed)
	-- How the debuff was found and whose it is, for the check.
	reading.found = aura == nil and "nothing" or (named and "name" or "id")
	local source = aura and Field(aura, "sourceUnit")
	reading.source = Plain(source, "string") and source or nil
	return reading
end

-- What one tracker shows of its own kind: a buff goes to ns.AuraReading, any other kind to its own Read. The table is the same for every
-- kind. A kind that raises is switched off alone, with a line in the status, and its trackers are unknown.
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
	-- A tracker that has a count shows it from the first time one was seen; a text tracker is as wide as the strings it shows.
	if reading.count and not entry.charged then
		entry.charged = true
		local text = Value(entry, "shape") == "text"
		if text then
			QueueLayout()
		end
	end
	return reading
end

-- Frames ------------------------------------------------------------------------------------------

-- The holder of a place: the one that is made, or nil when none was and make is not set.
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
	-- A plain square sweep: the template's has no file, and no edge line or flash is drawn.
	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetSwipeColor(0, 0, 0, 0.7)
	-- The count, the word and the rim sit on a frame above the sweep.
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
	-- shape is the way the record is drawn, parts the bar and the text made for it so far and refused the shapes the game refused.
	return { frame = frame, parent = parent, texture = texture, cooldown = cooldown, top = top, count = count, word = word, rim = rim,
		outline = ns.Outline(frame, frame), shape = "icon", parts = {}, refused = {}, groups = {}, tint = "red" }
end

-- The word fits inside the icon, and the rim is two screen pixels just inside its edges. For a bar or text the rim and the word are on the
-- bar or the plate.
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

-- The pulse of the missing icon is an animation the game plays. False when the game gives none.
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

-- The pulse plays on the icon, or on the plate of a bar or text. A pulse on the other one stops.
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

-- Drawing -----------------------------------------------------------------------------------------

-- How a tracker is shown: "live" from a reading, else "game" when ns.TrackerSlots draws the buff, else "hidden" when the page says a tracker
-- without the game's icon is hidden, else "last" from
-- the last reading that had a value, else "none". A buff that was missing at that reading is "last" only when the
-- player can cast it: nothing but the player's own cast tells that it is back, and a missing look that can never
-- end is worse than a grey icon. A kind with noLast has no last reading to show: it goes from "live" or "game" straight to "none".
local function How(entry, reading)
	local kind = KINDS[entry.kind]
	-- A debuff with no target to attack has nothing for the game's own icon to show either.
	if reading.absent == true then
		return "live"
	end
	if reading.state ~= "unknown" or (kind and kind.hiddenAble == false) then
		return "live"
	end
	-- The game's own icon, bar or text is drawn over the whole frame of a tracker, in the shape of the tracker.
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

-- How full a bar is, 0 to 1: charges over the most charges seen when the bar is filled by charges and the tracker has them, else the
-- time left over the length, else full.
local function Fill(entry, reading)
	local top = reading.top or entry.top
	if Value(entry, "barFill") == "charges" and entry.charged and reading.count and top and top >= 1 then
		return math.min(1, reading.count / top)
	end
	if reading.expires and reading.length then
		return math.max(0, math.min(1, (reading.expires - Now()) / reading.length))
	end
	return 1
end

-- What the frame of a tracker shows: icon, tint, count, sweep, rim, word and pulse, and for a bar or text the name, the fill and the
-- seconds left. A fill of nil keeps the fill drawn last.
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
		return look
	end
	look.icon = reading.icon or EntryIcon(entry)
	look.rim = state == "low"
	look.countRed = state == "low"
	-- A kind may tint the rim of a tracker that is up: its colour, in place of the red of a low one.
	if kind and type(kind.Rim) == "function" then
		local ok, r, g, b = pcall(kind.Rim, entry, reading, how)
		if ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number") then
			look.rim, look.rimColour = true, { r, g, b }
		end
	end
	if how ~= "last" then
		look.fill = Fill(entry, reading)
	end
	if entry.charged and Value(entry, "counts") then
		if how == "last" then
			look.count = "?"
		elseif reading.count then
			look.count = ("%d"):format(reading.count)
		end
	end
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
	-- A tracker a kind draws nothing for has a clear icon.
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
	-- A bar or text has its own count and time left, and no countdown of the sweep.
	record.count:SetText(shape == "icon" and look.count or "")
	if look.countRed then
		record.count:SetTextColor(RED[1], RED[2], RED[3])
	else
		record.count:SetTextColor(1, 1, 1)
	end
	if record.cooldown.SetHideCountdownNumbers then
		record.cooldown:SetHideCountdownNumbers(not (Value(entry, "numbers") and shape == "icon"))
	end
	ns.IconCountdownFont(record, Opt("numbersFont"))
	Sweep(record, look)
	-- The rim is red, or the colour a kind asked for; the colour is set again only when it changes.
	local tint = look.rimColour and (look.rimColour[1] .. "," .. look.rimColour[2] .. "," .. look.rimColour[3]) or "red"
	if record.tint ~= tint then
		local colour = look.rimColour or RED
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

-- 1 when the tracker is wanted on screen now, else 0.
local function Wanted(entry, state, how)
	local ok, dead = pcall(UnitIsDeadOrGhost, "player")
	if ok and not IsSecret(dead) and dead == true then
		return 0
	end
	local kind = KINDS[entry.kind]
	if kind and type(kind.Wanted) == "function" then
		local ok, alpha = pcall(kind.Wanted, entry, state, how)
		if ok and not IsSecret(alpha) and (alpha == 0 or alpha == 1) then
			return alpha
		end
	end
	local show = Value(entry, "show")
	if show == "low" then
		-- Trackers that show only when low or missing are hidden on a mount and in a city or an inn, as the two rows say.
		if (Opt("mounted") and Ask(IsMounted) == true) or (Opt("resting") and Ask(IsResting) == true) then
			return 0
		end
		return (how ~= "live" or state == "low" or state == "missing") and 1 or 0
	elseif show == "combat" then
		return fighting and 1 or 0
	end
	return 1
end

-- A kind whose reading can be hidden draws that reading itself when it has a Hidden(entry, record, reading) that gives true: "drawn" then,
-- else nil and the tracker is shown by How. The kind is asked on every look, so that it can take its parts away when the reading is not
-- hidden any more. The record is first drawn bare, once, so that the kind's parts are the only thing on it.
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

-- Allowed in combat: only texture, text, alpha, Cooldown and animation calls.
local function Draw(entry, reading)
	if testing[entry.id] then
		return
	end
	local how = Drawn(entry, reading) or How(entry, reading)
	local record = records[entry.id]
	if record then
		record.how = how
		local alpha = 0
		if how == "hidden" then
			Pulse(record, false)
		else
			Apply(record, entry, Looks(entry, reading, how))
			alpha = Wanted(entry, reading.state, how)
		end
		if record.alpha ~= alpha then
			record.frame:SetAlpha(alpha)
			record.alpha = alpha
		end
	end
	Slot("Show", entry, how == "game", record and record.alpha)
	-- A border on the action button that fixes a low or missing tracker (TrackerMarks.lua).
	if ns.TrackerMarkStep then
		ns.TrackerMarkStep(entry, reading, how)
	end
end

-- The fight and the probes -----------------------------------------------------------------------

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

-- A short form of an error text.
local function Brief(err)
	if type(err) == "string" then
		return err:sub(1, 60)
	end
	return "an error"
end

-- The one question about a hidden buff: only the kind of answer is kept.
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

-- Whether a call raised, gave a withheld answer or gave a plain one: a word, never the answer.
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

-- The scratch frames the probes try the timer, sweep and move calls on, made out of combat.
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

-- A duration of 10 seconds from now, or nil.
local function TenSeconds()
	local ok, duration = pcall(function()
		local made = C_DurationUtil.CreateDuration()
		made:SetTimeFromEnd(Now() + 10, 10)
		return made
	end)
	return ok and duration or nil
end

-- The questions the game answers about what it hides now: the word in the check, the C_Secrets function and, for a cast, the unit.
local PREDICATES = {
	{ "auras", "auras", "ShouldAurasBeSecret" },
	{ "cooldowns", "cooldowns", "ShouldCooldownsBeSecret" },
	{ "own", "own casts", "ShouldUnitSpellCastBeSecret", "player" },
	{ "group", "group casts", "ShouldUnitSpellCastBeSecret", "party1" },
}

-- What one call answered, as a word: yes, no, refused (it raised or gave no boolean), hidden answer (withheld, never made readable) or
-- not known (the client has no such call).
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

-- The answers for one tracker: each question of PREDICATES by its key, and for the first listed spell of the tracker whether the game hides
-- its buff (spell) and what level it gives it (level). A question about a cast needs a spell, so it is not known without one.
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

-- "auras yes, cooldowns no, own casts no, group casts no".
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

-- Each weapon slot of the game's Enum.WeaponSlot, as the game's own buff frame loops over them (BuffFrame.lua:763-766): { name, word,
-- entries }. The word is open, hidden or refused, and each entry of an open slot is { hasEnchant, type, name, plain } from
-- C_Item.GetWeaponEnchantInfo (ItemDocumentation.lua:1141-1154), the name being the game's own for Enum.ItemEnchantType.
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

-- "main hand Imbue 1, off hand none, ranged none": the enchants that are on, by the game's name for their type.
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

-- The calls the game's own icons and the later kinds of tracker depend on, tried once on the first pass of a fight and again 5
-- seconds into it. Each result is a word and the later one replaces the earlier.
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

-- The sound, the pass and the keeping --------------------------------------------------------------

-- True within 2 seconds after the player entered the world, when nothing is played.
local function Quiet(at)
	return entered ~= nil and at >= entered and at - entered < K.QUIET
end

-- Plays a sound kit, the tracker kit when none is given. With a second kit, a kit the game refuses is tried once as that one. A refusal of
-- both is one note, and false.
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

-- Asks the game's own sound for an aura ending (TrackerSound.lua) to match the trackers: none while the page is off.
local function GameSound()
	local call = ns.TrackerGameSound and ns.TrackerGameSound.Sync
	if type(call) == "function" then
		call(ns.Enabled(KEY) and Entries() or {})
	end
end

-- True when the game plays the tracker's drop sound itself, so its own is skipped.
local function GameTaken(entry)
	local call = ns.TrackerGameSound and ns.TrackerGameSound.Taken
	return type(call) == "function" and call(entry) == true
end

-- Keeps a reading and plays the sound for a drop: a tracker that goes from fine or low to missing, and
-- is still missing at the next pass 0.2 seconds later, outside the first 2 seconds after login.
local function Track(entry, reading)
	local id, state = entry.id, reading.state
	if state == "unknown" then
		mem.drops[id] = nil
		return
	end
	local before = mem.kept[id] and mem.kept[id].state
	mem.kept[id] = reading
	if reading.length then
		mem.lengths[id] = reading.length
	end
	if reading.count and reading.count > (entry.top or 0) then
		entry.top = math.min(20, math.max(1, math.floor(reading.count)))
	end
	-- A kind is told of a change of the state it has shown, once, and does its own sounds: it has no sound for a drop when it says noDrop.
	local kind = KINDS[entry.kind]
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

-- Tells ns.TrackerSlots about a new ID, a first charge count or a first sighting.
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

-- One pass per 0.2 seconds at most, and none without an event.
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

-- Your own cast ----------------------------------------------------------------------------------

-- A tracker shown as last known or as nothing known has its sweep started again by the cast of its buff, and is
-- a buff that is on from then, with no end time when no length was ever known.
local function Restart(entry)
	local record, id = records[entry.id], entry.id
	if not record or (record.how ~= "last" and record.how ~= "none") then
		return
	end
	local old = mem.kept[id]
	local length = old and old.length or mem.lengths[id]
	local start = Now()
	local reading = { state = "fine", hidden = false, icon = old and old.icon, id = old and old.id }
	-- With no length ever known there is no sweep to start again, and one that is still drawn is cleared.
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

-- The watcher -------------------------------------------------------------------------------------

-- The trackers of every kind, and the sound of one of them, for a kind that sounds without a drop of its own reading.
ns.TrackerEntries = Entries
function ns.TrackerSound(entry)
	if Value(entry, "sound") and not Quiet(Now()) and not GameTaken(entry) then
		Ding(K.KITS[Value(entry, "kit")] or K.KITS.raid)
	end
end

-- A watcher that hears every unit passes on the events of the player alone. A unit that is withheld cannot be told,
-- so an aura change of it still asks for a pass and a cast of it is dropped.
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
		-- An event of a kind: a unit event of another unit says nothing about the player, or the unit the kind asked for.
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

-- True when the event is registered for the player alone, or for the units given (RegisterUnitEvent takes several in one call, as
-- CooldownViewer.lua:1736 registers UNIT_AURA for the player and the target).
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

-- Registers an event of a kind on the watcher, once. UNIT_INVENTORY_CHANGED is heard for the player alone, the others have no unit.
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

-- Registers a kind of tracker that is not a buff, and the events it listens for on the watcher of the trackers. The spec is
-- { Read(entry) -> reading, Clean(entry) -> true when the entry is valid, events = { name, ... }, Add(argument, entries) -> fields, message,
-- Label(entry), Icon(entry), Lines(entry) -> { text }, what = the words after the name in the list, hiddenAble = false for a kind the game never
-- hides, unitEvents = { EVENT = unit } for an event heard for a unit that is not the player, Event(event, ...) and Cast(spellID) called for each
-- event of the kind and each cast of the player, Hidden(entry, record, reading) -> true when the kind drew a hidden reading itself, and the
-- hooks of a kind that has more to show: slot = { unit, filter } for the game's own icon of the kind, noLast (no last reading is shown: "none"
-- in its place), noDrop (no sound for a drop), last (laid out after the other trackers), Hide(entry, reading, how) -> true to draw nothing,
-- Wanted(entry, state, how) -> 0 or 1 ahead of the rules of Show, Rim(entry, reading, how) -> red, green, blue for the rim of a tracker that is
-- up, Changed(entry, before, after) after a change of the state that was kept, Gone(id) when a tracker is no longer on, World() when the
-- player enters the world or the spells change, Test(entry, on) -> a line, for a test of 5 seconds instead of the three looks, own = { key = fn }
-- for the kind's own test of an own value, and part = the name of the part of the module the kind's calls are isolated in }. A reading is
-- { state = "fine" | "low" | "missing" | "unknown", hidden, count, expires, length, icon, id }.
function ns.TrackerKind(name, spec)
	if type(name) ~= "string" or name == "buff" or type(spec) ~= "table" or type(spec.Read) ~= "function" or type(spec.Clean) ~= "function" then
		return false
	end
	-- A slot is { unit, filter }, both words, or none.
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

-- Adds a word to /flatui tracker: fn(text) is given what follows the word and gives the line to print. A kind of tracker adds its own.
function ns.TrackerWord(word, fn)
	if type(word) == "string" and type(fn) == "function" and word ~= "" then
		K.commands[word:lower()] = fn
		return true
	end
	return false
end

-- True for the restrictions that hide aura values.
local function Counted(kind)
	local types = Enum and Enum.AddOnRestrictionType
	if type(types) ~= "table" or kind == nil then
		return false
	end
	return kind == types.Combat or kind == types.Encounter or kind == types.ChallengeMode or kind == types.PvPMatch
end

-- True when every listed ID is flagged as never hidden. A game that cannot say counts as hiding.
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

-- The game says a restriction is about to start, and enforces it only once this event is handled: the
-- last plain reading is taken at once, and every buff that will be hidden is drawn as hidden.
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
	StartFight()
	Pass()
end

local function FightEnds()
	fighting = false
	EndFight()
	Dirty()
	Slot("Flush")
end

-- Tells the kinds that have a World() that the player entered the world or that the spells changed.
local function World()
	for name, kind in pairs(KINDS) do
		if type(kind.World) == "function" then
			ns.EachPart(KEY, Part(name), kind.World)
		end
	end
end

-- New spells change what the player can cast, and the row may need a new layout for them.
local function SpellsChanged()
	bookIds = nil
	World()
	QueueLayout()
end

local function Entered()
	entered = Now()
	World()
	Dirty()
	Slot("Flush")
	GameSound()
end

-- Layout ------------------------------------------------------------------------------------------

-- The highest bar of the personal resource display that is shown. The display is as high as its bars.
local function HighestBar(display)
	for _, key in ipairs(RESOURCE_BARS) do
		local bar = Field(display, key)
		if not ns.Forbidden(bar) and Ask(bar.IsShown, bar) == true then
			return bar
		end
	end
	return display
end

-- The lowest bar of the personal resource display that is shown, for a row under it. Cooldowns.lua has the same walk.
local function LowestBar(display)
	for index = #RESOURCE_BARS, 1, -1 do
		local bar = Field(display, RESOURCE_BARS[index])
		if not ns.Forbidden(bar) and Ask(bar.IsShown, bar) == true then
			return bar
		end
	end
	return display
end

-- The Cooldown icons row when it hangs from the personal resource display and has icons: its holder and how far its icons reach below
-- the holder. Nothing when it is elsewhere, so a row below the display goes straight under the bars.
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

-- The middle of a holder is the middle of its row. The row is 4 units above the display, or below it, 150 units right of the middle of
-- the screen, or at the spot the movers saved, with the offsets added. True when the display was wanted and cannot be used.
local function Place(place, holder, total, tallest, grow)
	local x, y = Opt("x"), Opt("y")
	local refused = false
	if place == "resource" then
		local anchored = false
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			local over = type(ns.OwnBuffsHolder) == "function" and ns.OwnBuffsHolder(Opt("side") == "below" and "below" or "above") or nil
			if Opt("side") == "below" then
				local row, depth = CooldownsBelow()
				if row then
					holder:SetPoint("CENTER", row, "CENTER", x, y - depth - GAP - tallest / 2)
					K.where[place] = "below the Cooldown icons row"
				elseif over then
					holder:SetPoint("CENTER", over, "BOTTOM", x, y - GAP - tallest / 2)
					K.where[place] = "below the Your buffs row"
				else
					holder:SetPoint("CENTER", LowestBar(display), "BOTTOM", x, y - GAP - tallest / 2)
					K.where[place] = "below the personal resource display"
				end
			elseif over then
				holder:SetPoint("CENTER", over, "TOP", x, y + GAP + tallest / 2)
				K.where[place] = "above the Your buffs row"
			else
				holder:SetPoint("CENTER", HighestBar(display), "TOP", x, y + GAP + tallest / 2)
				K.where[place] = "above the personal resource display"
			end
			-- A frame anchored to one that has no position has no rectangle either. A client that cannot
			-- say is taken to have one.
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

-- The record of a tracker, from the free list when a removed tracker left one. /flatui status counts the records
-- in use.
local function Assign(entry, parent)
	local record = records[entry.id]
	if not record then
		local spec = ns.TrackerSlotSpec(entry)
		local pool = spec and (spec.unit .. "|" .. spec.filter) or "none"
		record = table.remove(free[pool] or {}) or Acquire(parent)
		record.pool = pool
		records[entry.id] = record
		ns.Count(KEY)
	end
	return record
end

-- Tells every kind that has a Gone(id) that a tracker is no longer on, so that it can end what it started for it.
local function Gone(id)
	for name, kind in pairs(KINDS) do
		if type(kind.Gone) == "function" then
			ns.EachPart(KEY, Part(name), kind.Gone, id)
		end
	end
end

-- The records of trackers that are no longer on wait for the next tracker.
local function Release(wanted)
	for id, record in pairs(records) do
		if not wanted[id] then
			Gone(id)
			records[id] = nil
			ns.Count(KEY, -1)
			Pulse(record, false)
			-- The parts a kind drew over the record go with the tracker, and the record is drawn afresh by the next one.
			if record.hid and record.hid.Leave then
				pcall(record.hid.Leave)
			end
			record.how = nil
			record.frame:Hide()
			free[record.pool] = free[record.pool] or {}
			table.insert(free[record.pool], record)
			Forget(id)
		end
	end
end

-- Hides every holder, for a page that is off or no tracker on.
local function HideHolders()
	for _, holder in pairs(holders) do
		holder:Hide()
	end
end

-- Runs out of combat. The trackers are grouped by their place, and each group is one row hung from the holder of its place.
local function Layout()
	if not ns.Enabled(KEY) then
		tracked = 0
		ns.ClearNote(KEY, NO_POSITION)
		HideHolders()
		for id in pairs(records) do
			Gone(id)
		end
		-- A kind that ended what it had up for a tracker shows it again from the start when the page comes back.
		for _, entry in ipairs(Entries()) do
			local kind = KINDS[entry.kind]
			if kind and type(kind.Gone) == "function" then
				mem.kept[entry.id] = nil
			end
		end
		shown = {}
		return
	end
	local entries, wanted = OnEntries(), {}
	tracked = #entries
	-- The aura events of the target are listened to while a tracker reads it.
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
	-- The kinds that say last (a proc, which is nothing on screen while it is down) go after the others in their row, in list order.
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
	for _, place in ipairs(K.ORDER) do
		local group, holder = groups[place], HolderFor(place, #groups[place] > 0)
		if #group == 0 then
			if holder then
				holder:Hide()
			end
		else
			holder:Show()
			-- Each tracker has a record and a shape, and so a width and a height: the total of the widths and the tallest height place the row.
			local sized, total, tallest = {}, spacing * (#group - 1), 0
			for _, entry in ipairs(group) do
				local record = Assign(entry, holder)
				local width, height = ns.TrackerShapes.Size(entry, ns.TrackerShapes.Make(record, Value(entry, "shape")))
				sized[#sized + 1] = { entry, record, width, height }
				total, tallest = total + width, math.max(tallest, height)
			end
			if Place(place, holder, total, tallest, grow) then
				refused = true
			end
			local x = grow == "right" and 0 or grow == "left" and 0 or -total / 2
			for _, item in ipairs(sized) do
				local entry, record, width, height = item[1], item[2], item[3], item[4]
				local frame = record.frame
				if record.parent ~= holder then
					frame:SetParent(holder)
					record.parent = holder
				end
				record.place = place
				frame:SetSize(width, height)
				frame:ClearAllPoints()
				if grow == "left" then
					x = x - width
				end
				-- An own X or Y offset replaces the page's: the holder is placed at the page's.
				frame:SetPoint("LEFT", holder, "CENTER", x + Value(entry, "x") - Opt("x"), Value(entry, "y") - Opt("y"))
				frame:Show()
				Fit(record, entry)
				x = grow == "left" and x - spacing or x + width + spacing
				shown[#shown + 1] = record
			end
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

-- Asks for a pass, for a kind that learns of a change by a call of its own.
function ns.TrackerDirty()
	Dirty()
end

-- One layout at a time, when combat allows.
function QueueLayout()
	-- Every change of the list or of a tracker asks for a layout, and the game's own sounds follow the same changes.
	GameSound()
	-- Your buffs leaves out the buffs of the trackers that are on, when it is set to.
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

-- A new layout, for Your buffs when the row it hangs from starts or stops being above or under the bars.
function ns.TrackerPlaceAgain()
	QueueLayout()
end

-- The spell IDs of the buff trackers that are on, as a map, for Your buffs.
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

-- The frames of the trackers on the row and the frame they hang from, for the handle of the movers.
-- Nothing while the page is off.
function ns.TrackerRow()
	local frames = {}
	if not ns.Enabled(KEY) then
		return frames
	end
	-- The row at its own position when a tracker has one, else the row of the page's place.
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
		if record.place == place then
			frames[#frames + 1] = record.frame
		end
	end
	return frames, holder
end

-- The movers set or put back the spot of the row. A spot saved for the row is the Own position.
function ns.TrackersMoved()
	if ns.MoverSpot(MOVER, "CENTER") and Opt("place") ~= "own" then
		ns.Set(KEY .. ".place", "own")
	end
	QueueLayout()
end

-- The frame of a tracker, or nil when it has none.
function ns.TrackerFrame(entry)
	local record = type(entry) == "table" and records[entry.id]
	return record and record.frame or nil
end

-- The check -------------------------------------------------------------------------------------

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

local function NowText(reading)
	local state = reading.state
	if state == "missing" then
		return "missing"
	elseif state == "unknown" then
		return reading.hidden and "not known, the game is hiding it" or "not known, the game gave no answer"
	end
	local charges = "no charges"
	if reading.count then
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

-- The own values of a tracker as text, sorted by key: "low 2, place own".
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
	lines[1] = ("%d. %s, %s%s"):format(index, Label(entry), kind and kind.what or "buff on you", entry.on == false and ", off" or "")
	lines[2] = "   Now: " .. NowText(reading) .. "."
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
	-- A kind that draws nothing for a reading says so: a proc that is not up, or whose icon is the game's.
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
	local place = Value(entry, "place")
	lines[#lines + 1] = ("   Place: %s, %s."):format(Shown("place", place), K.where[place] or "not laid out yet")
	-- The shape the tracker is drawn in, and what the game refused of it.
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
	for _, line in ipairs(FightText()) do
		print(line)
	end
	print(SoundText())
end

-- The game plays a sound of its own for each listed ID when its buff ends, until /reload.
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

-- The test -----------------------------------------------------------------------------------------

local function SecretAuras()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	local ok, answer = pcall(call)
	return ok and not IsSecret(answer) and answer == true
end

-- A look for the test: the icon of the game's own drawing alone leaves the frame bare.
local function Bare(entry)
	local record = records[entry.id]
	if record then
		Apply(record, entry, { icon = nil, sweep = "clear" })
		record.frame:SetAlpha(1)
		record.alpha = 1
	end
end

local function Paint(entry, state, length)
	local record = records[entry.id]
	if record then
		length = length or 600
		local reading = { state = state, hidden = false, expires = Now() + length, length = length, icon = EntryIcon(entry), count = entry.charged and 3 or nil }
		Apply(record, entry, Looks(entry, reading, "live"))
		record.frame:SetAlpha(1)
		record.alpha = 1
	end
end

-- Draws each look for 3 seconds and puts the real state back.
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
			-- PlaySound may give no answer at all, which says nothing about whether the sound played.
			-- Each kit the trackers use plays once.
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

-- A kind with a Test(entry, on) is shown for K.TEST seconds with its icon up, Test(entry, true) at the start and Test(entry, false) at the end;
-- it gives the line to print when it has one.
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
	if #entries == 0 and #kinds == 0 then
		print(number and ("No tracker numbered %d."):format(number) or "No trackers.")
		return
	end
	testRun = testRun + 1
	-- A test still running stops, and its trackers go back to their own thresholds and their real look.
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

-- The commands -----------------------------------------------------------------------------------

-- A tracker by its number in the list or by its name.
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

-- The label of the row Add class trackers has the name of the class, which the page table cannot know when it loads: the game's own name
-- for the player's class, else the word class.
local function ClassLabel()
	local row = PageRow("addClass")
	if row then
		row.label = ("Add %s trackers"):format((ClassInfo()) or "class")
	end
end

ClassLabel()

local function Refresh()
	ClassLabel()
	if ns.Enabled(KEY) then
		Watch()
	end
	if not ns.Enabled(KEY) then
		HideHolders()
		if ns.TrackerMarkSweep then
			ns.TrackerMarkSweep()
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
		PLAYER_UPDATE_RESTING = Dirty,
		SPELLS_CHANGED = SpellsChanged,
	},
	slash = { tracker = Slash },
	help = HELP,
	counted = "shown",
})
