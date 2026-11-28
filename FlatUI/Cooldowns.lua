local _, ns = ...

local KEY = "cooldowns"
local PART = "cooldown manager icons"
local MOVER = "FlatUICooldowns"
local MAX_SPELLS = 40
local MAX_ID = 2147483647
local CROP = 0.08
local INSET = 2
local GAP = 4
local SCREEN_Y = -160
local RECHECK = 0.2
local SWEEP = 1
local UNKNOWN_ICON = 134400
local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
local RESOURCE_BARS = { "AlternatePowerBar", "PowerBar", "HealthBarsContainer" }
local ITEM_OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local ITEM_MASK = "UI-HUD-CoolDownManager-Mask"
local SQUARE_SWEEP = "Interface\\ChatFrame\\ChatFrameBackground"
local ROUND_SWEEP = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local NO_POSITION = "Cooldown icons: the personal resource display cannot be used, so the row is in the middle of the screen."
local NO_SWEEP = "Cooldown icons: the game hides cooldown times and has no other way to draw them, so icons dim without a sweep."
local SWEEP_REFUSED = "Cooldown icons: the game refused to draw cooldown sweeps, so icons dim without a sweep."
local NO_COOLDOWNS = "Cooldown icons: the game has no spell cooldown information, so the row shows no cooldowns."
local NO_SOUND = "Cooldown icons: the game played no sound, so the ready sound is silent."
local RAID_WARNING = 8959
local READY_CHANNEL = "Gameplay SFX"
local NO_BOOK = "Cooldown icons: the game has no spell book information, so Add a spell lists nothing."
local NO_BINDS = "Cooldown icons: the game has no action bar key information, so Keybind on icons shows no keys."
local NO_TRINKETS = "Cooldown icons: the game has no equipment information, so Equipped trinkets shows nothing."
local NO_ITEM_SWEEP = "Cooldown icons: the game hides trinket cooldowns, so trinket icons show no sweep."
local NO_COUNT_FONT = "Cooldown icons: the game refused the font of the icon text, so Charge count size and Keybind size are not applied."
local NO_NUMBERS_FONT = "Cooldown icons: the game refused the countdown font, so Countdown number size is not applied."
local NO_GAME_FONT = "Cooldown icons: the game's countdown font could not be read, so Countdown number size keeps the last size chosen until /reload."
local NUMBER_FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }
local KEYBIND_FONT = "NumberFontNormalSmallGray"
local BIND_PART, FLASH_PART, TRINKET_PART, FONT_PART = "keybinds", "ready flash", "trinkets", "countdown size"
local FLASH_FROM, FLASH_TIME = 0.6, 0.4
local TRINKET_SLOTS = { 13, 14 }
local RANGE_EVERY = 0.2
local ITEM_PART, TINT_PART = "potions and healthstones", "range and power"
local CONSUMABLE = 0
local SOUND_WORDS = { "spell", "chimes", "bell", "warhorn", "raid", "alarm", "whisper" }
local SOUND_INDEX = {}
for index, word in ipairs(SOUND_WORDS) do
	SOUND_INDEX[word] = index
end
local SOUND_ROW, SOUND_NONE, SOUND_BACK = 1, 2, -1
local NO_RANGE = "Cooldown icons: the game withholds the range, so those icons are not tinted red."
local NO_POWER = "Cooldown icons: the game withholds whether there is power for a spell, so those icons are not tinted blue."
local NO_COUNT = "Cooldown icons: the game gave no item count, so potion and healthstone icons show no count."
local NO_KIND_SWEEP = "Cooldown icons: the game hides item cooldowns, so potion and healthstone icons show no sweep."
local BAR_SLOTS = { { 1, "ACTIONBUTTON" }, { 13, "ACTIONBUTTON" }, { 73, "ACTIONBUTTON" }, { 85, "ACTIONBUTTON" }, { 97, "ACTIONBUTTON" },
	{ 109, "ACTIONBUTTON" }, { 121, "ACTIONBUTTON" }, { 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" }, { 49, "MULTIACTIONBAR2BUTTON" },
	{ 61, "MULTIACTIONBAR1BUTTON" }, { 145, "MULTIACTIONBAR5BUTTON" }, { 157, "MULTIACTIONBAR6BUTTON" }, { 169, "MULTIACTIONBAR7BUTTON" } }

local CD = {
	MAX_OWN_ITEMS = 12, MAX_BAG_LINES = 100,
	GCD = 2,
	GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17, 18 },
	SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrists",
		[10] = "Hands", [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back", [16] = "Main hand", [17] = "Off hand",
		[18] = "Ranged" },
	SLOT_BY_NAME = {},
	SLOT_LINE = 1000, ITEM_LINE = 2000,
	IMPORT_FIRST = { false, 61, 49, 25, 37, 145, 157, 169 },
	MAX_PAGE = 15,
	CORNERS = { br = { "BOTTOMRIGHT", -2, 2 }, bl = { "BOTTOMLEFT", 2, 2 }, tl = { "TOPLEFT", 2, -2 }, tr = { "TOPRIGHT", -2, -2 } },
	NUMBER_PLACES = { middle = { "CENTER", 0 }, top = { "TOP", -2 }, bottom = { "BOTTOM", 2 } },
	WHITE = "ffffffff",
	OWN_PART = "items", TIP_PART = "icon tooltips", NUMBERS_PART = "countdown look",
	NO_ITEM_SPELL = "Cooldown icons: the game does not say which items have a use, so On-use gear in other slots and Add an item show nothing.",
	NO_BAR = "Cooldown icons: the game has no action bar information, so Add the spells of a bar adds nothing.",
	NO_MOUSE = "Cooldown icons: the game refused the mouse on the icons, so Tooltips on icons may show none.",
	NO_EDGE = "Cooldown icons: the game refused the colour of the edge line, so Edge colour is not applied.",
	NO_COUNTDOWN_LOOK = "Cooldown icons: the game refused the countdown's colour, place or tenths, so Countdown colour, Countdown place or Tenths below is not applied.",
	ITEM_HELP = "/flatui cooldown add item 6948 - an item ID, a name or a shift-clicked item; /flatui cooldown remove item 6948 takes it off",
	IMPORT_HELP = "/flatui cooldown import 1 - the spells with a cooldown on action bar 1 to 8",
	MAX_ROWS = 4, ROW_KEYS = { show = "Show", place = "Place", x = "X", y = "Y", size = "Size", grow = "Grow" },
	MOVERS = { MOVER, "FlatUICooldowns2", "FlatUICooldowns3", "FlatUICooldowns4" },
	UNIT_FRAMES = {
		player = { frame = "PlayerFrame", note = "Cooldown icons: the player frame cannot be used, so a row is in the middle of the screen." },
		target = { frame = "TargetFrame", note = "Cooldown icons: the target frame cannot be used, so a row is in the middle of the screen." },
	},
}
for slot, name in pairs(CD.SLOT_NAMES) do
	CD.SLOT_BY_NAME[name:lower()] = slot
end

local HELP = {
	"/flatui cooldown add 2094 - a spell ID, a name or a shift-clicked spell",
	"/flatui cooldown remove 2094",
	"/flatui cooldown list",
}

local IsSecret = ns.IsSecret

local holder
local icons, shown = {}, {}
local items = setmetatable({}, { __mode = "k" })
local layoutQueued, sweepQueued = false, false
local sinceRecheck, sinceSweep = 0, 0
local fighting = false
local away = false
local rangeTicker
local colourObjects, colourCount = {}, 0
local soundFor
local consumable = {}
local Own = { uses = {}, stacks = {}, loading = {} }
local Tip, Bar, Looks, Counts = {}, {}, {}, {}
local R = { pools = { icons }, shownOf = { {} }, holders = {}, hidden = {} }
ns.CooldownShared = R

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

local function Field(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Crop()
	return Opt("crop") / 100
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function IsTrue(value)
	return not IsSecret(value) and value == true
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= MAX_ID and value == math.floor(value)
end

function R.Opt(row, key)
	if row == nil or row == 1 then
		return Opt(key)
	end
	return Opt("row" .. row .. CD.ROW_KEYS[key])
end

function R.RowOn(row)
	return row == 1 or Opt("row" .. row) == true
end

function R.Call(name, ...)
	local fn = R[name]
	if type(fn) == "function" then
		return fn(...)
	end
	return nil
end

local function List()
	local saved = ns.Character()
	if not saved then
		return {}
	end
	local old = saved.cooldowns
	local list, seen = {}, {}
	if type(old) == "table" then
		for _, id in ipairs(old) do
			if Whole(id) and not seen[id] and #list < MAX_SPELLS then
				seen[id] = true
				list[#list + 1] = id
			end
		end
		local same = true
		for key in pairs(old) do
			same = same and list[key] ~= nil and list[key] == old[key]
		end
		if same and #list == #old then
			return old
		end
	end
	saved.cooldowns = list
	return list
end

local function SpellName(spellID)
	local name = Ask(C_Spell and C_Spell.GetSpellName, spellID)
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

local function Name(spellID)
	return SpellName(spellID) or ("Spell " .. spellID)
end

local function PetBank()
	local banks = type(Enum) == "table" and Enum.SpellBookSpellBank or nil
	local value = type(banks) == "table" and banks.Pet or nil
	return Plain(value, "number") and value or 1
end

local function Known(spellID)
	local book = C_SpellBook
	if book then
		for _, call in ipairs({ "IsSpellKnownOrInSpellBook", "IsSpellKnown" }) do
			local known = Ask(book[call], spellID)
			if type(known) == "boolean" then
				return known or Ask(book[call], spellID, PetBank()) == true
			end
		end
	end
	return true
end

function ns.SpellKnown(id)
	return Whole(id) and Known(id)
end

local function HasCooldown(spellID)
	local milliseconds = Ask(GetSpellBaseCooldown, spellID)
	if Plain(milliseconds, "number") then
		return milliseconds > 0
	end
	return true
end

local function SpellBook()
	local book = C_SpellBook
	if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
		and Enum and Enum.SpellBookSpellBank and Enum.SpellBookItemType then
		return book
	end
	return nil
end

local function Spells()
	local spells = {}
	for _, id in ipairs(List()) do
		if Known(id) then
			spells[#spells + 1] = id
		end
	end
	return spells
end

local function Parse(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
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
	if Whole(id) and SpellName(id) then
		return id
	end
	return nil
end

local function Kind(key)
	local list = ns.COOLDOWN_ITEMS
	if type(list) == "table" then
		for index, kind in ipairs(list) do
			if type(kind) == "table" and kind.key == key and type(kind.name) == "string" and type(kind.items) == "table" then
				return kind, index
			end
		end
	end
	return nil
end

local function KindAt(index)
	local list = ns.COOLDOWN_ITEMS
	local kind = type(list) == "table" and Plain(index, "number") and list[index]
	if type(kind) == "table" then
		return Kind(kind.key)
	end
	return nil
end

local function KindNamed(text)
	local wanted = text:match("^%s*(.-)%s*$"):lower()
	for _, kind in ipairs(type(ns.COOLDOWN_ITEMS) == "table" and ns.COOLDOWN_ITEMS or {}) do
		if type(kind) == "table" and type(kind.key) == "string" and type(kind.name) == "string" and (wanted == kind.key or wanted == kind.name:lower()) then
			return Kind(kind.key)
		end
	end
	return nil
end

local function Kinds(make)
	local saved = ns.Character()
	if not saved then
		return {}
	end
	local old = saved.cooldownItems
	if type(old) ~= "table" and not make then
		return {}
	end
	local list, seen = {}, {}
	if type(old) == "table" then
		for _, key in ipairs(old) do
			if type(key) == "string" and not seen[key] and Kind(key) then
				seen[key] = true
				list[#list + 1] = key
			end
		end
		local same = #list == #old
		for key in pairs(old) do
			same = same and list[key] ~= nil and list[key] == old[key]
		end
		if same then
			return old
		end
	end
	saved.cooldownItems = list
	return list
end

local function Consumable(id)
	if consumable[id] then
		return true
	end
	local call = C_Item and C_Item.GetItemInfoInstant
	if type(call) ~= "function" then
		return true
	end
	local ok, answered, _, _, _, _, class = pcall(call, id)
	if not ok or IsSecret(answered) or IsSecret(class) then
		return true
	elseif answered == nil then
		return false
	elseif type(class) ~= "number" then
		return true
	end
	consumable[id] = class == CONSUMABLE or nil
	return class == CONSUMABLE
end

local function Ranks(kind)
	local list = {}
	for _, id in ipairs(kind.items) do
		if Whole(id) and Consumable(id) then
			list[#list + 1] = id
		end
	end
	return list
end

local function TooLow(itemID, level)
	local call = C_Item and C_Item.GetItemInfo
	if level == nil or type(call) ~= "function" then
		return false
	end
	local ok, _, _, _, _, needs = pcall(call, itemID)
	return ok and Plain(needs, "number") and needs > level
end

local function Best(kind, before)
	local ranks = Ranks(kind)
	if #ranks == 0 then
		return nil
	end
	local call = C_Item and C_Item.GetItemCount
	local level = Ask(UnitLevel, "player")
	level = Plain(level, "number") and level or nil
	local known = true
	for index = #ranks, 1, -1 do
		local count = Ask(call, ranks[index], false, true)
		if Plain(count, "number") then
			if count > 0 and not TooLow(ranks[index], level) then
				return ranks[index], count
			end
		else
			known = false
		end
	end
	local shown = ranks[1]
	for _, id in ipairs(ranks) do
		if id == before and not TooLow(id, level) then
			shown = id
		end
	end
	return shown, known and 0 or nil
end

local function ItemIcon(itemID)
	local file = Ask(C_Item and C_Item.GetItemIconByID, itemID)
	if Plain(file, "number") or Plain(file, "string") then
		return file
	end
	return UNKNOWN_ICON
end

function Own.KindOf(itemID)
	for index, kind in ipairs(type(ns.COOLDOWN_ITEMS) == "table" and ns.COOLDOWN_ITEMS or {}) do
		if type(kind) == "table" and type(kind.items) == "table" and Kind(kind.key) == kind then
			for _, id in ipairs(kind.items) do
				if id == itemID then
					return kind, index
				end
			end
		end
	end
	return nil
end

function Own.Load(itemID)
	if not Own.loading[itemID] and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
		Own.loading[itemID] = true
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
end

function Own.Name(itemID)
	local name = Ask(C_Item and C_Item.GetItemNameByID, itemID)
	if Plain(name, "string") and name ~= "" then
		return name
	end
	Own.Load(itemID)
	return ("Item %d"):format(itemID)
end

function Own.HasUse(itemID)
	if Own.uses[itemID] ~= nil then
		return Own.uses[itemID]
	end
	local call = C_Item and C_Item.GetItemSpell
	if type(call) ~= "function" then
		return nil
	end
	local ok, _, spellID = pcall(call, itemID)
	if ok and Whole(spellID) then
		Own.uses[itemID] = true
		return true
	end
	if ok and not IsSecret(spellID) and Ask(C_Item.IsItemDataCachedByID, itemID) == true then
		Own.uses[itemID] = false
		return false
	end
	Own.Load(itemID)
	return nil
end

function Own.Stacks(itemID)
	if Own.stacks[itemID] ~= nil then
		return Own.stacks[itemID]
	end
	local most = Ask(C_Item and C_Item.GetItemMaxStackSizeByID, itemID)
	local spent = Ask(C_Item and C_Item.IsConsumableItem, itemID) == true
	if Plain(most, "number") then
		Own.stacks[itemID] = most > 1 or spent
	end
	return spent or (Plain(most, "number") and most > 1)
end

function Own.List(make)
	local saved = ns.Character()
	if not saved then
		return {}
	end
	local old = saved.cooldownOwnItems
	if type(old) ~= "table" and not make then
		return {}
	end
	local list, seen = {}, {}
	if type(old) == "table" then
		for _, id in ipairs(old) do
			if Whole(id) and not seen[id] and #list < CD.MAX_OWN_ITEMS then
				seen[id] = true
				list[#list + 1] = id
			end
		end
		local same = #list == #old
		for key in pairs(old) do
			same = same and list[key] ~= nil and list[key] == old[key]
		end
		if same then
			return old
		end
	end
	saved.cooldownOwnItems = list
	return list
end

function Own.Bags()
	local rows, seen = {}, {}
	local containers = type(C_Container) == "table" and C_Container or {}
	local bags = Plain(NUM_BAG_SLOTS, "number") and NUM_BAG_SLOTS or 4
	if Plain(NUM_REAGENTBAG_SLOTS, "number") and NUM_REAGENTBAG_SLOTS > 0 then
		bags = bags + NUM_REAGENTBAG_SLOTS
	end
	for bag = 0, bags do
		local slots = Ask(containers.GetContainerNumSlots, bag)
		for slot = 1, Plain(slots, "number") and slots or 0 do
			local info = Ask(containers.GetContainerItemInfo, bag, slot)
			if type(info) == "table" then
				local id, name = Field(info, "itemID"), Field(info, "itemName")
				if Whole(id) and not seen[id] then
					seen[id] = true
					rows[#rows + 1] = { id, Plain(name, "string") and name ~= "" and name or nil }
				end
			end
		end
	end
	return rows
end

function Own.From(text)
	text = text:match("^%s*(.-)%s*$")
	local id = tonumber(text:match("^%d+$") or text:match("|Hitem:(%d+)") or text:match("^[Ii]tem:(%d+)"))
	if Whole(id) then
		return id
	end
	local wanted = text:lower()
	if wanted == "" then
		return nil
	end
	for _, picked in ipairs(Own.List()) do
		if Own.Name(picked):lower() == wanted then
			return picked
		end
	end
	for _, row in ipairs(Own.Bags()) do
		if row[2] and row[2]:lower() == wanted then
			return row[1]
		end
	end
	local known = Ask(C_Item and C_Item.GetItemInfoInstant, text)
	return Whole(known) and known or nil
end

local function SlotKey(slot)
	return "slot:" .. slot
end

local function ItemKey(itemID)
	return "item:" .. itemID
end

local function OwnSound(key)
	local saved = ns.Character()
	local sounds = saved and saved.cooldownSounds
	if key == nil or type(sounds) ~= "table" then
		return nil
	end
	local word = sounds[key]
	if word == "none" or (type(word) == "string" and SOUND_INDEX[word]) then
		return word
	end
	return nil
end

local function SetOwnSound(key, word)
	local saved = ns.Character()
	if not saved or key == nil then
		return
	end
	local sounds = saved.cooldownSounds
	if type(sounds) ~= "table" then
		if word == nil then
			return
		end
		sounds = {}
		saved.cooldownSounds = sounds
	end
	sounds[key] = word
	if next(sounds) == nil then
		saved.cooldownSounds = nil
	end
end

local function SoundName(word)
	if word == "none" then
		return "no sound"
	end
	local sound = ns.SOUNDS and ns.SOUNDS[SOUND_INDEX[word] or 0]
	return type(sound) == "table" and sound[2] or tostring(word)
end

local function Kit(word)
	local sound = ns.SOUNDS and ns.SOUNDS[SOUND_INDEX[word] or 0]
	if type(sound) == "table" and Plain(sound[1], "number") then
		return sound[1]
	end
	local kits = ns.TrackerKits
	return kits and kits[word] or RAID_WARNING
end

local function SoundKey(record)
	if record.spell or record.kind then
		return record.spell or record.kind
	elseif record.slot then
		return SlotKey(record.slot)
	elseif record.own then
		return ItemKey(record.own)
	end
	return nil
end

local function SoundOf(record)
	return OwnSound(SoundKey(record)) or Opt("readySound")
end

local function SoundSaid(name, word)
	if word == nil then
		return ("%s plays the row's sound when ready."):format(name)
	end
	return ("%s plays %s when ready."):format(name, SoundName(word))
end

local function DrawSweep(record, info, cooling, recharging, onGCD)
	local spells, cooldown, spellID = C_Spell, record.cooldown, record.spell
	if info == nil then
		cooldown:Clear()
		return
	end
	local gcd = Opt("gcd") == true
	if spells.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
		local ok, duration
		if recharging and spells.GetSpellChargeDuration then
			ok, duration = pcall(spells.GetSpellChargeDuration, spellID)
		else
			ok, duration = pcall(spells.GetSpellCooldownDuration, spellID, not gcd)
		end
		if ok and duration ~= nil then
			if pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration, true) then
				if cooling or recharging or (gcd and onGCD) then
					cooldown:Show()
				end
			else
				cooldown:Clear()
				ns.Note(KEY, SWEEP_REFUSED)
			end
		else
			cooldown:Clear()
		end
		return
	end
	local start, length, rate = info.startTime, info.duration, info.modRate
	if (cooling or (gcd and onGCD)) and Plain(start, "number") and Plain(length, "number") then
		cooldown:SetCooldown(start, length, Plain(rate, "number") and rate or 1)
	else
		cooldown:Clear()
		if cooling then
			ns.Note(KEY, NO_SWEEP)
		end
	end
end

local function Flash(record)
	local flash = record.flash
	if flash == nil then
		local texture = record.top:CreateTexture(nil, "OVERLAY", nil, 0)
		ns.Own[texture] = true
		texture:SetAllPoints(record.frame)
		texture:SetColorTexture(1, 1, 1, 1)
		texture:Hide()
		local group = texture:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(FLASH_FROM)
		fade:SetToAlpha(0)
		fade:SetDuration(FLASH_TIME)
		group:SetScript("OnFinished", function()
			texture:Hide()
		end)
		flash = { texture = texture, group = group }
		record.flash = flash
	end
	flash.group:Stop()
	flash.texture:Show()
	flash.group:Play()
end

function Looks.PlaceTexts(record)
	local corner = CD.CORNERS[Opt("countCorner")] and Opt("countCorner") or "br"
	if record.corner ~= corner then
		record.corner = corner
		local at = CD.CORNERS[corner]
		record.count:ClearAllPoints()
		record.count:SetPoint(at[1], record.top, at[1], at[2], at[3])
	end
	local bindAt = corner == "tr" and "tl" or "tr"
	if record.bind and record.bindCorner ~= bindAt then
		record.bindCorner = bindAt
		local at = CD.CORNERS[bindAt]
		record.bind:ClearAllPoints()
		record.bind:SetPoint(at[1], record.top, at[1], at[2], at[3])
	end
end

local function TextSizes(record)
	local spec = { percent = Opt("countSize") }
	if Opt("countColour") ~= CD.WHITE then
		spec.r, spec.g, spec.b = ns.Colour(KEY .. ".countColour")
	end
	local count = ns.TextStyle(record.count, spec)
	local key = record.bind == nil or ns.TextStyle(record.bind, { percent = Opt("keybindSize") })
	if count == false or key == false then
		ns.Note(KEY, NO_COUNT_FONT)
	end
	Looks.PlaceTexts(record)
end

local function GameFont(cooldown)
	local fs = Ask(cooldown.GetCountdownFontString, cooldown)
	if fs == nil then
		return false
	end
	local ok, file, size, flags = pcall(fs.GetFont, fs)
	if ok and Plain(file, "string") and Plain(size, "number") and (flags == nil or Plain(flags, "string")) then
		return { file, size, flags or "" }
	end
	return false
end

local function NumbersFont(record)
	local name = NUMBER_FONTS[Opt("numbersFont")]
	local cooldown = record.cooldown
	if name == nil then
		if record.font ~= nil then
			record.font = nil
			local saved = record.gameFont
			local fs = saved and Ask(cooldown.GetCountdownFontString, cooldown)
			if not (fs and pcall(fs.SetFont, fs, saved[1], saved[2], saved[3])) then
				ns.Note(KEY, NO_GAME_FONT)
			end
		end
		return
	end
	if record.font == name then
		return
	end
	if record.gameFont == nil then
		record.gameFont = GameFont(cooldown)
	end
	record.font = name
	if not (cooldown.SetCountdownFont and pcall(cooldown.SetCountdownFont, cooldown, name)) then
		ns.Note(KEY, NO_NUMBERS_FONT)
	end
end

function Looks.Numbers(record)
	local cooldown = record.cooldown
	local colour, place, tenths = Opt("numbersColour"), Opt("numbersPlace"), Opt("tenths")
	place = CD.NUMBER_PLACES[place] and place or "middle"
	local font, refused, fs = tostring(record.font), false, nil
	local function String()
		if fs == nil then
			fs = Ask(cooldown.GetCountdownFontString, cooldown) or false
		end
		return fs or nil
	end
	local colourKey = colour .. "|" .. font
	if record.numbersColour ~= colourKey and not (record.numbersColour == nil and colour == CD.WHITE) then
		record.numbersColour = colourKey
		local text = String()
		local r, g, b = ns.Colour(KEY .. ".numbersColour")
		refused = not (text and pcall(text.SetTextColor, text, r, g, b, 1)) or refused
	end
	local placeKey = place .. "|" .. font
	if record.numbersPlace ~= placeKey and not (record.numbersPlace == nil and place == "middle") then
		record.numbersPlace = placeKey
		local text, at = String(), CD.NUMBER_PLACES[place]
		refused = not (text and pcall(text.ClearAllPoints, text) and pcall(text.SetPoint, text, at[1], cooldown, at[1], 0, at[2])) or refused
	end
	if record.tenths ~= tenths and not (record.tenths == nil and tenths == 0) then
		record.tenths = tenths
		refused = not (cooldown.SetCountdownMillisecondsThreshold and pcall(cooldown.SetCountdownMillisecondsThreshold, cooldown, tenths)) or refused
	end
	if refused then
		ns.Note(KEY, CD.NO_COUNTDOWN_LOOK)
	end
end

function Looks.SwipeKey()
	return Opt("sweepColour") .. ":" .. Opt("sweepAlpha")
end

function Looks.Edge(record)
	local cooldown, edge = record.cooldown, Opt("edge") == true
	if record.edge ~= edge then
		record.edge = edge
		cooldown:SetDrawEdge(edge)
	end
	local colour = Opt("edgeColour")
	if edge and record.edgeColour ~= colour and not (record.edgeColour == nil and colour == CD.WHITE) then
		record.edgeColour = colour
		local r, g, b = ns.Colour(KEY .. ".edgeColour")
		if not (cooldown.SetEdgeColor and pcall(cooldown.SetEdgeColor, cooldown, r, g, b, 1)) then
			ns.Note(KEY, CD.NO_EDGE)
		end
	end
end

local function HasRange(spellID)
	local answer = Ask(C_Spell and C_Spell.SpellHasRange, spellID)
	if type(answer) == "boolean" then
		return answer
	end
	return nil
end

local function ReadTint(record)
	local spells = C_Spell
	local range, power
	if spells and Opt("rangeTint") and record.hasRange ~= false and spells.IsSpellInRange then
		local ok, answer = pcall(spells.IsSpellInRange, record.spell)
		if ok and (IsSecret(answer) or type(answer) == "boolean") then
			range = answer
		end
	end
	if spells and Opt("powerTint") and spells.IsSpellUsable then
		local ok, usable, short = pcall(spells.IsSpellUsable, record.spell)
		if ok and not IsTrue(usable) and (IsSecret(short) or type(short) == "boolean") then
			power = short
		end
	end
	record.range, record.power = range, power
end

local function ColourObject(r, g, b)
	local key = ("%.3f %.3f %.3f"):format(r, g, b)
	local object = colourObjects[key]
	if object == nil and type(CreateColor) == "function" then
		local ok, made = pcall(CreateColor, r, g, b, 1)
		if ok and type(made) == "table" then
			if colourCount >= 64 then
				colourObjects, colourCount = {}, 0
			end
			object = made
			colourObjects[key] = object
			colourCount = colourCount + 1
		end
	end
	return object
end

local function Scaled(path, level)
	local r, g, b = ns.Colour(KEY .. "." .. path)
	return r * level, g * level, b * level
end

local function Paint(record, level)
	local texture = record.texture
	local range, power
	local held = record.held
	if held and not ns.PartStopped(KEY, TINT_PART) then
		local place = record.sample or held.index
		if Opt("rangeTint") and place == 2 then
			range = false
		end
		if Opt("powerTint") and place == 3 then
			power = true
		end
	elseif record.spell and not ns.PartStopped(KEY, TINT_PART) then
		if Opt("rangeTint") then
			range = record.range
		end
		if Opt("powerTint") then
			power = record.power
		end
	end
	local rangeSecret, powerSecret = IsSecret(range), IsSecret(power)
	if not rangeSecret and range == false then
		texture:SetVertexColor(Scaled("rangeColour", level))
		return
	end
	local r, g, b = level, level, level
	if not powerSecret and power == true then
		r, g, b = Scaled("powerColour", level)
	end
	if rangeSecret or powerSecret then
		local value, yes, no = power, nil, nil
		if rangeSecret then
			value, yes, no = range, ColourObject(r, g, b), ColourObject(Scaled("rangeColour", level))
		else
			yes, no = ColourObject(Scaled("powerColour", level)), ColourObject(r, g, b)
		end
		if yes and no and texture.SetVertexColorFromBoolean then
			texture:SetVertexColorFromBoolean(value, yes, no)
			return
		end
		ns.Note(KEY, rangeSecret and NO_RANGE or NO_POWER)
	end
	texture:SetVertexColor(r, g, b)
end

local function Look(record, cooling, secret, active)
	local texture, cooldown, frame = record.texture, record.cooldown, record.frame
	local level = 1
	if Opt("dim") then
		if secret then
			texture:SetDesaturated(Opt("dimDesat") and active)
		else
			level = cooling and 1 - Opt("dimDarkness") / 100 or 1
			texture:SetDesaturated(cooling and Opt("dimDesat"))
		end
	else
		texture:SetDesaturated(false)
	end
	record.level = level
	Paint(record, level)
	local coolAlpha, readyAlpha = Opt("coolAlpha") / 100, Opt("readyAlpha") / 100
	local only = R.Call("ShowOf", record)
	if only == "cooling" then
		readyAlpha = 0
	elseif only == "ready" then
		coolAlpha = 0
	end
	if secret and frame.SetAlphaFromBoolean then
		frame:SetAlphaFromBoolean(active, coolAlpha, readyAlpha)
		record.unseen = false
	else
		frame:SetAlpha(cooling and coolAlpha or readyAlpha)
		record.unseen = (cooling and coolAlpha or readyAlpha) == 0
	end
	local border = Opt("border")
	ns.SetOutline(record.outline, border, border)
	if border and Opt("borderState") and not secret then
		ns.SetOutlineColour(record.outline, ns.Colour(KEY .. (cooling and ".coolingColour" or ".readyColour")))
	else
		ns.SetOutlineColour(record.outline, nil, nil, nil)
	end
	R.Call("Glows", record, only == "border", cooling, secret, active)
	if cooldown.SetHideCountdownNumbers then
		cooldown:SetHideCountdownNumbers(not Opt("numbers"))
	end
	ns.EachPart(KEY, FONT_PART, NumbersFont, record)
	ns.EachPart(KEY, CD.NUMBERS_PART, Looks.Numbers, record)
	local sweep = Opt("sweep")
	if record.sweep ~= sweep then
		record.sweep = sweep
		cooldown:SetDrawSwipe(sweep)
	end
	local swipe = Looks.SwipeKey()
	if record.swipe ~= swipe then
		record.swipe = swipe
		local r, g, b = ns.Colour(KEY .. ".sweepColour")
		cooldown:SetSwipeColor(r, g, b, Opt("sweepAlpha") / 100)
	end
	Looks.Edge(record)
	TextSizes(record)
	if cooling then
		record.readyPlayed = nil
	elseif record.dimmed and Opt("flash") and not record.empty then
		ns.EachPart(KEY, FLASH_PART, Flash, record)
	end
	record.dimmed = cooling
end

local function ItemCooldown(itemID)
	local call = C_Item and C_Item.GetItemCooldown
	if type(call) ~= "function" then
		return nil
	end
	local ok, start, duration = pcall(call, itemID)
	if ok and Plain(start, "number") and Plain(duration, "number") then
		return start, duration
	end
	return nil
end

local function ItemCooling(itemID)
	local start, duration = ItemCooldown(itemID)
	local now = Ask(GetTime)
	if start == nil or not Plain(now, "number") then
		return nil
	end
	return duration > 0 and start + duration > now, start, duration
end

local function ItemSweep(record)
	local cooldown = record.cooldown
	local cooling, start, duration = ItemCooling(record.item)
	if cooling and duration <= CD.GCD then
		if record.dimmed == nil then
			cooldown:Clear()
		end
		return record.dimmed == true
	end
	if cooling then
		cooldown:SetCooldown(start, duration)
	else
		cooldown:Clear()
	end
	return cooling
end

local function UpdateItem(record)
	local cooling = ItemSweep(record)
	if cooling ~= nil then
		ns.ClearNote(KEY, NO_ITEM_SWEEP)
	else
		ns.Note(KEY, type(C_Item) == "table" and C_Item.GetItemCooldown and NO_ITEM_SWEEP or NO_TRINKETS)
	end
	record.count:SetText("")
	Look(record, cooling == true, false, cooling == true)
end

local function UpdateOwn(record)
	local id = record.item
	local count = Ask(C_Item and C_Item.GetItemCount, id, false, true)
	count = Plain(count, "number") and count or nil
	record.empty = count == 0
	local cooling = ItemSweep(record)
	record.count:SetText(count and Own.Stacks(id) and tostring(count) or "")
	Look(record, cooling == true, false, cooling == true)
	if record.empty then
		record.texture:SetDesaturated(true)
	end
end

local function UpdateKind(record)
	local kind = Kind(record.kind)
	local item, count
	if kind then
		item, count = Best(kind, record.item)
	end
	if count == nil then
		ns.Note(KEY, NO_COUNT)
	else
		ns.ClearNote(KEY, NO_COUNT)
	end
	if item and item ~= record.item then
		record.item = item
		record.texture:SetTexture(ItemIcon(item))
	end
	record.empty = count == 0
	local cooldown = record.cooldown
	local cooling, start, duration = ItemCooling(record.item)
	if cooling then
		cooldown:SetCooldown(start, duration)
	else
		cooldown:Clear()
	end
	if cooling == nil then
		ns.Note(KEY, NO_KIND_SWEEP)
	else
		ns.ClearNote(KEY, NO_KIND_SWEEP)
	end
	record.count:SetText(count and tostring(count) or "")
	Look(record, cooling == true, false, cooling == true)
	if record.empty then
		record.texture:SetDesaturated(true)
	end
end

function Counts.Charges(spellID)
	local call = C_Spell and C_Spell.GetSpellCharges
	if type(call) ~= "function" then
		return nil, true
	end
	local ok, charges = pcall(call, spellID)
	if not ok or IsSecret(charges) then
		return nil, false
	end
	return type(charges) == "table" and charges or nil, charges == nil
end

function Counts.Spell(record, hasCharges, none)
	local text = ""
	if hasCharges or (none and Opt("useCount")) then
		local counted, answer = pcall(C_Spell and C_Spell.GetSpellDisplayCount, record.spell)
		if counted and (IsSecret(answer) or type(answer) == "string") then
			text = answer
		end
	end
	record.count:SetText(text)
end

local function Update(record)
	if R.Call("Held", record) then
		return
	end
	if record.kind then
		ns.EachPart(KEY, ITEM_PART, UpdateKind, record)
		return
	end
	if record.own then
		ns.EachPart(KEY, CD.OWN_PART, UpdateOwn, record)
		return
	end
	if record.item then
		ns.EachPart(KEY, TRINKET_PART, UpdateItem, record)
		return
	end
	local spells = C_Spell
	if not (spells and spells.GetSpellCooldown) then
		return
	end
	local spellID, cooldown = record.spell, record.cooldown
	local ok, info = pcall(spells.GetSpellCooldown, spellID)
	if not ok then
		cooldown:Clear()
		error(info, 0)
	end
	if IsSecret(info) or type(info) ~= "table" then
		info = nil
	end
	local active = info and info.isActive
	local secret = IsSecret(active)
	local cooling = not secret and active == true and not IsTrue(info.isOnGCD)
	local onGCD = not secret and active == true and IsTrue(info.isOnGCD)
	local charges, none = Counts.Charges(spellID)
	local maximum = type(charges) == "table" and charges.maxCharges
	local hasCharges = Plain(maximum, "number") and maximum > 1
	DrawSweep(record, info, cooling, hasCharges and not cooling and IsTrue(charges.isActive), onGCD)
	Counts.Spell(record, hasCharges, none)
	if ns.PartStopped(KEY, TINT_PART) then
		record.range, record.power = nil, nil
	else
		ns.EachPart(KEY, TINT_PART, ReadTint, record)
	end
	Look(record, cooling, secret, active)
end

local function Ready(record)
	if R.Call("Testing") then
		return
	end
	local sound = SoundOf(record)
	if not (record.dimmed and not record.readyPlayed and sound ~= "none") then
		return
	end
	if record.item then
		if ItemCooling(record.item) ~= false then
			return
		end
	else
		local info = Ask(C_Spell and C_Spell.GetSpellCooldown, record.spell)
		if type(info) ~= "table" or (IsTrue(info.isActive) and not IsTrue(info.isOnGCD)) then
			return
		end
	end
	record.readyPlayed = true
	if record.empty then
		return
	end
	local ok, played = pcall(PlaySound, Kit(sound), READY_CHANNEL)
	if not ok or (not IsSecret(played) and played == false) then
		ns.Note(KEY, NO_SOUND)
	end
end

local function UpdateAll()
	for _, record in ipairs(shown) do
		ns.Each(KEY, Ready, record)
		ns.Each(KEY, Update, record)
	end
end

local function StillCooling(record)
	if record.item then
		return ItemCooling(record.item) == true
	end
	local info = Ask(C_Spell and C_Spell.GetSpellCooldown, record.spell)
	return type(info) == "table" and IsTrue(info.isActive) and not IsTrue(info.isOnGCD)
end

local function Recheck()
	if R.Call("Testing") then
		return
	end
	for _, record in ipairs(shown) do
		if record.dimmed and not StillCooling(record) then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end
end

local function Tint(record)
	local range, power = record.range, record.power
	ReadTint(record)
	local same = not (IsSecret(range) or IsSecret(power) or IsSecret(record.range) or IsSecret(record.power))
		and range == record.range and power == record.power
	if not same and record.level then
		Paint(record, record.level)
	end
end

local function TintAll()
	for _, record in ipairs(shown) do
		if record.spell then
			ns.EachPart(KEY, TINT_PART, Tint, record)
		end
	end
end

local function RangeStop()
	if rangeTicker and rangeTicker.Cancel then
		pcall(rangeTicker.Cancel, rangeTicker)
	end
	rangeTicker = nil
end

local function RangeWanted()
	if not (holder and ns.Enabled(KEY) and Opt("rangeTint") and not away and C_Spell and C_Spell.IsSpellInRange) or ns.PartStopped(KEY, TINT_PART) then
		return false
	end
	if Ask(holder.IsShown, holder) ~= true or Ask(UnitExists, "target") == false then
		return false
	end
	for _, record in ipairs(shown) do
		if record.spell and record.hasRange ~= false and not R.hidden[record.row or 1] then
			return true
		end
	end
	return false
end

local function RangeWatch()
	if not RangeWanted() then
		RangeStop()
		return
	end
	if rangeTicker or not (C_Timer and C_Timer.NewTicker) then
		return
	end
	local ok, ticker = pcall(C_Timer.NewTicker, RANGE_EVERY, function()
		if not (RangeWanted() and ns.Try(KEY, TintAll)) then
			RangeStop()
		end
	end)
	rangeTicker = ok and ticker or nil
end

local function TargetChanged()
	TintAll()
	RangeWatch()
end

local function ItemMask(item)
	local icon = item.Icon
	if icon and not IsSecret(icon) and icon.GetMaskTexture then
		local mask = Ask(icon.GetMaskTexture, icon, 1)
		if mask ~= nil then
			return mask
		end
	end
	return ns.RegionWithAtlas(item, ITEM_MASK)
end

local function Corners(part, anchor, inset)
	part:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
	part:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
end

local function StyleItem(item, on)
	local icon = item.Icon
	local own = items[item]
	if not own then
		if not on or icon == nil or IsSecret(icon) then
			return
		end
		own = { outline = ns.Outline(item, icon), overlay = ns.RegionWithAtlas(item, ITEM_OVERLAY), mask = ItemMask(item) }
		items[item] = own
		ns.Count(KEY)
		if not own.overlay then
			ns.Note(KEY, "Cooldown manager icons: the default frame was not found and is still shown.")
		end
		if not own.mask then
			ns.Note(KEY, "Cooldown manager icons: the round mask was not found, so corners stay rounded.")
		end
	end
	if own.on == on then
		return
	end
	own.on = on
	ns.SetOutline(own.outline, on, false)
	ns.SetFaded(own.overlay, on)
	Corners(icon, item, on and INSET or 0)
	if on then
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	else
		icon:SetTexCoord(0, 1, 0, 1)
	end
	if own.mask then
		if on then
			pcall(icon.RemoveMaskTexture, icon, own.mask)
		else
			pcall(icon.AddMaskTexture, icon, own.mask)
		end
	end
	local anchor = on and icon or item
	local cooldown, range = item.Cooldown, item.OutOfRange
	if not ns.Forbidden(cooldown) then
		Corners(cooldown, anchor, 0)
		if cooldown.SetSwipeTexture then
			cooldown:SetSwipeTexture(on and SQUARE_SWEEP or ROUND_SWEEP)
		end
	end
	if range and not IsSecret(range) then
		Corners(range, anchor, 0)
	end
end

local function StyleViewer(viewer)
	local pool = viewer.itemFramePool
	if IsSecret(pool) or type(pool) ~= "table" or not pool.EnumerateActive then
		return
	end
	for item in pool:EnumerateActive() do
		local styled = items[item]
		if not ns.Forbidden(item) and not (styled and styled.on) then
			ns.EachPart(KEY, PART, StyleItem, item, true)
		end
	end
end

local function Viewer(name)
	local viewer = _G[name]
	if viewer ~= nil and not ns.Forbidden(viewer) then
		return viewer
	end
	return nil
end

local function HasViewer()
	for _, name in ipairs(VIEWERS) do
		if Viewer(name) then
			return true
		end
	end
	return false
end

local function ViewerShown()
	for _, name in ipairs(VIEWERS) do
		local viewer = Viewer(name)
		if viewer then
			local ok, visible = pcall(viewer.IsShown, viewer)
			if not ok or IsSecret(visible) or visible ~= false then
				return true
			end
		end
	end
	return false
end

local function LookAtManager()
	local on = ns.Enabled(KEY) and Opt("manager") and not ns.PartStopped(KEY, PART)
	if on then
		for _, name in ipairs(VIEWERS) do
			local viewer = Viewer(name)
			if viewer then
				ns.EachPart(KEY, PART, StyleViewer, viewer)
			end
		end
		return
	end
	for item, styled in pairs(items) do
		if styled.on and not ns.Forbidden(item) then
			pcall(StyleItem, item, false)
		end
	end
end

local function QueueSweep()
	if sweepQueued then
		return
	end
	sweepQueued = true
	ns.OutOfCombat(function()
		sweepQueued = false
		if ns.IsStopped(KEY) then
			pcall(LookAtManager)
		else
			ns.Try(KEY, LookAtManager)
		end
	end)
end

local function QueueSweepSoon()
	if next(items) ~= nil or HasViewer() then
		if C_Timer and C_Timer.After then
			C_Timer.After(0, QueueSweep)
		else
			QueueSweep()
		end
	end
end

local function OnUpdate(_, elapsed)
	sinceRecheck = sinceRecheck + elapsed
	sinceSweep = sinceSweep + elapsed
	if sinceRecheck >= RECHECK then
		sinceRecheck = 0
		ns.Try(KEY, Recheck)
	end
	if sinceSweep >= SWEEP then
		sinceSweep = 0
		if ns.Enabled(KEY) and Opt("manager") and ViewerShown() then
			QueueSweep()
		end
	end
end

local function Holder()
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[holder] = true
		holder:SetSize(1, 1)
		holder:SetScript("OnUpdate", OnUpdate)
		R.holders[1] = holder
	end
	return holder
end

function R.Holder(row)
	if row == nil or row == 1 then
		return Holder()
	end
	local made = R.holders[row]
	if not made then
		made = CreateFrame("Frame", nil, UIParent)
		ns.Own[made] = true
		made:SetSize(1, 1)
		R.holders[row] = made
	end
	return made
end

function R.Shown()
	return shown
end

function Tip.Get()
	local tip = GameTooltip
	if type(tip) ~= "table" or IsSecret(tip) or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

function Tip.Owned(tip, frame)
	local ok, owned = pcall(tip.IsOwned, tip, frame)
	return ok and not IsSecret(owned) and owned == true
end

function Tip.BoxReadable()
	local box = GameTooltipDefaultContainer or SharedTooltipDefaultContainer
	if type(box) ~= "table" or IsSecret(box) or type(box.GetPoint) ~= "function" then
		return false
	end
	local ok, point, _, _, x, y = pcall(box.GetPoint, box, 1)
	return ok and Plain(point, "string") and Plain(x, "number") and Plain(y, "number")
end

function Tip.Hide(record)
	local tip = Tip.Get()
	if tip and Tip.Owned(tip, record.frame) then
		pcall(tip.Hide, tip)
	end
end

function Tip.Show(record)
	local mode = Opt("tooltips")
	if mode == "off" or not ns.Enabled(KEY) or (mode == "combat" and (fighting or Ask(InCombatLockdown) == true)) then
		return
	end
	local tip = Tip.Get()
	if not tip or not (record.spell or record.item) or record.unseen or away or R.hidden[record.row or 1] then
		return
	end
	local frame, placed = record.frame, false
	if Ask(GetCVar, "UberTooltips") == "1" and type(GameTooltip_SetDefaultAnchor) == "function" and Tip.BoxReadable() then
		placed = pcall(GameTooltip_SetDefaultAnchor, tip, frame)
	end
	if not placed and not pcall(tip.SetOwner, tip, frame, "ANCHOR_RIGHT") then
		return
	end
	local ok, err
	if record.spell then
		ok, err = pcall(tip.SetSpellByID, tip, record.spell)
	else
		local worn = false
		if record.slot then
			local okWorn, shown = pcall(tip.SetInventoryItem, tip, "player", record.slot)
			worn = okWorn and not IsSecret(shown) and shown == true
		end
		ok = worn
		if not worn then
			ok, err = pcall(tip.SetItemByID, tip, record.item)
		end
	end
	if not ok then
		pcall(tip.Hide, tip)
		error(err, 0)
	end
	pcall(tip.Show, tip)
end

function Tip.Mouse(record)
	if Ask(InCombatLockdown) == true then
		return
	end
	local mode = Opt("tooltips")
	local seen = not away and not R.hidden[record.row or 1] and (Opt("idleAlpha") > 0 or (fighting and mode == "on"))
	local want = mode ~= "off" and seen and not ns.PartStopped(KEY, CD.TIP_PART)
	if record.mouse == want or (record.mouse == nil and not want) then
		return
	end
	local frame = record.frame
	if want and not record.tipScripts then
		record.tipScripts = true
		frame:SetScript("OnEnter", function()
			ns.EachPart(KEY, CD.TIP_PART, Tip.Show, record)
		end)
		frame:SetScript("OnLeave", function()
			Tip.Hide(record)
		end)
		frame:SetScript("OnHide", function()
			Tip.Hide(record)
		end)
	end
	local ok = pcall(frame.SetMouseClickEnabled, frame, false)
	ok = pcall(frame.SetMouseMotionEnabled, frame, want) and ok
	record.mouse = want
	if not ok then
		ns.Note(KEY, CD.NO_MOUSE)
	end
	if not want then
		Tip.Hide(record)
	end
end

function Tip.MouseAll()
	if Ask(InCombatLockdown) == true then
		if not Tip.waiting then
			Tip.waiting = true
			ns.OutOfCombat(function()
				Tip.waiting = false
				Tip.MouseAll()
			end)
		end
		return
	end
	for row = 1, CD.MAX_ROWS do
		for _, record in ipairs(R.pools[row] or {}) do
			ns.Each(KEY, Tip.Mouse, record)
		end
	end
end

function Tip.Leave()
	local all = away or (fighting and Opt("tooltips") == "combat")
	for _, record in ipairs(shown) do
		if record.tipScripts and (all or R.hidden[record.row or 1]) then
			Tip.Hide(record)
		end
	end
end

local function Acquire(index, row)
	row = row or 1
	local pool = R.pools[row]
	if not pool then
		pool = {}
		R.pools[row] = pool
	end
	local record = pool[index]
	if record then
		return record
	end
	local frame = CreateFrame("Frame", nil, R.Holder(row))
	ns.Own[frame] = true
	local texture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[texture] = true
	texture:SetAllPoints(frame)
	local crop = Crop()
	texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	local r, g, b = ns.Colour(KEY .. ".sweepColour")
	cooldown:SetSwipeColor(r, g, b, Opt("sweepAlpha") / 100)
	local top = CreateFrame("Frame", nil, frame)
	ns.Own[top] = true
	top:SetAllPoints(frame)
	top:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	ns.Own[count] = true
	count:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
	record = { frame = frame, texture = texture, cooldown = cooldown, count = count, top = top, outline = ns.Outline(frame, frame),
		sweep = true, swipe = Looks.SwipeKey(), edge = false, corner = "br", row = row }
	cooldown:SetScript("OnCooldownDone", function()
		if ns.Enabled(KEY) then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end)
	pool[index] = record
	ns.Count(KEY)
	return record
end

local function LowestBar(display)
	for _, key in ipairs(RESOURCE_BARS) do
		local bar = Field(display, key)
		if not ns.Forbidden(bar) and Ask(bar.IsShown, bar) == true then
			return bar
		end
	end
	return display
end

local function Anchored(frame)
	local ok, left = pcall(frame.GetLeft, frame)
	return not ok or IsSecret(left) or left ~= nil
end

local function Place(row)
	row = row or 1
	local frame = R.Holder(row)
	local x, y = R.Opt(row, "x"), R.Opt(row, "y")
	local spotX, spotY = ns.MoverSpot(CD.MOVERS[row], "CENTER")
	if spotX then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", spotX, spotY)
		return nil
	end
	local place, anchored, note = R.Opt(row, "place"), false, nil
	if place == "resource" then
		note = NO_POSITION
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			local over = type(ns.ChargesHolder) == "function" and ns.ChargesHolder("below") or nil
			over = over or (type(ns.OwnBuffsHolder) == "function" and ns.OwnBuffsHolder("below") or nil)
			if over then
				frame:SetPoint("CENTER", over, "BOTTOM", x, y - GAP)
			else
				frame:SetPoint("CENTER", LowestBar(display), "BOTTOM", x, y - GAP)
			end
			anchored = Anchored(frame)
		end
	elseif CD.UNIT_FRAMES[place] then
		local info = CD.UNIT_FRAMES[place]
		note = info.note
		local unitFrame = _G[info.frame]
		if unitFrame ~= nil and not ns.Forbidden(unitFrame) then
			local grow = R.Opt(row, "grow")
			local point = grow == "right" and "BOTTOMLEFT" or (grow == "left" and "BOTTOMRIGHT" or "BOTTOM")
			frame:SetPoint("CENTER", unitFrame, point, x, y - GAP)
			anchored = Anchored(frame)
		end
	end
	if not anchored then
		frame:SetPoint("CENTER", UIParent, "CENTER", x, y + SCREEN_Y)
	end
	return not anchored and note or nil
end

local function SpellIcon(spellID)
	local file = Ask(C_Spell and C_Spell.GetSpellTexture, spellID)
	if Plain(file, "number") or Plain(file, "string") then
		return file
	end
	return UNKNOWN_ICON
end

local function CheckGame()
	if not (C_Spell and C_Spell.GetSpellCooldown) then
		ns.Note(KEY, NO_COOLDOWNS)
	end
end

local function Trinkets()
	local list = {}
	local trinkets, gear = Opt("trinkets") == true, Opt("gear") == true
	if not (trinkets or gear) or ns.PartStopped(KEY, TRINKET_PART) then
		return list
	end
	if type(GetInventoryItemID) ~= "function" then
		ns.Note(KEY, NO_TRINKETS)
		return list
	end
	ns.ClearNote(KEY, NO_TRINKETS)
	for _, slot in ipairs(trinkets and TRINKET_SLOTS or {}) do
		local id = Ask(GetInventoryItemID, "player", slot)
		if Whole(id) then
			list[#list + 1] = { item = id, slot = slot }
		end
	end
	if gear and not (C_Item and type(C_Item.GetItemSpell) == "function") then
		ns.Note(KEY, CD.NO_ITEM_SPELL)
	elseif gear then
		ns.ClearNote(KEY, CD.NO_ITEM_SPELL)
		for _, slot in ipairs(CD.GEAR_SLOTS) do
			local id = Ask(GetInventoryItemID, "player", slot)
			if Whole(id) and Own.HasUse(id) then
				list[#list + 1] = { item = id, slot = slot }
			end
		end
	end
	return list
end

local function Idle()
	if holder then
		away = (Opt("mounted") and Ask(IsMounted) == true) or (Opt("resting") and Ask(IsResting) == true)
	end
	local alpha = away and 0 or (not fighting and Opt("idleAlpha") / 100 or 1)
	for row = 1, CD.MAX_ROWS do
		local frame = R.holders[row]
		if frame then
			R.hidden[row] = R.Call("Shows", row) == false
			frame:SetAlpha(R.hidden[row] and 0 or alpha)
		end
	end
	RangeWatch()
	Tip.MouseAll()
	Tip.Leave()
end
R.Idle = Idle

function R.Fighting()
	return fighting
end

local function MainFirstSlot()
	local main = _G.MainActionBar
	local page = main and Ask(main.GetAttribute, main, "actionpage")
	if not Whole(page) and type(ns.OwnPage) == "function" then
		page = Ask(ns.OwnPage)
	end
	if Whole(page) and page >= 1 then
		return (page - 1) * 12 + 1
	end
	return nil
end

local function BindingText(spellID)
	local slots = Ask(C_ActionBar and C_ActionBar.FindSpellActionButtons, spellID)
	if type(slots) ~= "table" then
		return ""
	end
	local first = MainFirstSlot()
	for _, slot in ipairs(slots) do
		for index = 0, #BAR_SLOTS do
			local bar = BAR_SLOTS[index]
			if index == 0 then
				bar = first and { first, "ACTIONBUTTON" } or nil
			elseif first and bar[2] == "ACTIONBUTTON" then
				bar = nil
			end
			if bar and Plain(slot, "number") and slot >= bar[1] and slot < bar[1] + 12 then
				local key = Ask(GetBindingKey, bar[2] .. (slot - bar[1] + 1))
				local text = Plain(key, "string") and Ask(GetBindingText, key, 1)
				if Plain(text, "string") and text ~= "" then
					if ns.Get("actionbars.hotkeyText") == "short" and type(ns.HotkeyText) == "function" then
						local short = ns.HotkeyText(text)
						if Plain(short, "string") and short ~= "" then
							return short
						end
					end
					return text
				end
			end
		end
	end
	return ""
end

local function Keybind(record)
	local sample = record.held ~= nil and record.sample or nil
	if not Opt("keybind") or not (record.spell or sample) then
		if record.bind then
			record.bind:SetText("")
		end
		return
	end
	if not sample and not (C_ActionBar and C_ActionBar.FindSpellActionButtons and GetBindingKey and GetBindingText) then
		ns.Note(KEY, NO_BINDS)
		return
	end
	if record.bind == nil then
		local bind = record.top:CreateFontString(nil, "OVERLAY", KEYBIND_FONT)
		ns.Own[bind] = true
		bind:SetPoint("TOPRIGHT", record.top, "TOPRIGHT", -2, -2)
		record.bind, record.bindCorner = bind, "tr"
	end
	record.bind:SetText(sample and tostring(sample) or BindingText(record.spell))
	TextSizes(record)
end

local function Binds()
	local stopped = ns.PartStopped(KEY, BIND_PART)
	for _, record in ipairs(shown) do
		if not stopped then
			ns.EachPart(KEY, BIND_PART, Keybind, record)
		elseif record.bind then
			pcall(record.bind.SetText, record.bind, "")
		end
	end
end

local BindsSoon
do
	local queued = false
	function BindsSoon()
		if not (C_Timer and C_Timer.After) then
			Binds()
			return
		end
		if queued then
			return
		end
		queued = true
		C_Timer.After(0, function()
			queued = false
			if ns.Enabled(KEY) then
				Binds()
			end
		end)
	end
end

function ns.CooldownBindsChanged()
	if ns.Enabled(KEY) then
		Binds()
	end
end

local function Layout()
	local on = ns.Enabled(KEY)
	local spells = on and Spells() or {}
	local entries = {}
	for _, id in ipairs(spells) do
		entries[#entries + 1] = { spell = id }
	end
	for _, entry in ipairs(on and Trinkets() or {}) do
		entries[#entries + 1] = entry
	end
	local before = {}
	for _, record in ipairs(shown) do
		if record.kind then
			before[record.kind] = record.item
		end
	end
	for _, key in ipairs(on and not ns.PartStopped(KEY, ITEM_PART) and Kinds() or {}) do
		local kind = Kind(key)
		local item = kind and Best(kind, before[key])
		if item then
			entries[#entries + 1] = { kind = key, item = item }
		end
	end
	for _, id in ipairs(on and not ns.PartStopped(KEY, CD.OWN_PART) and Own.List() or {}) do
		entries[#entries + 1] = { item = id, own = id }
	end
	if #entries == 0 and not (on and Opt("manager") and HasViewer()) and not R.Call("Testing") then
		for row = 1, CD.MAX_ROWS do
			if R.holders[row] then
				R.holders[row]:Hide()
			end
			R.shownOf[row] = {}
			for _, record in ipairs(R.pools[row] or {}) do
				record.dimmed, record.readyPlayed = nil, nil
			end
		end
		shown = {}
		R.Notes({})
		RangeWatch()
		R.Call("AfterLayout")
		R.TellHitTable()
		R.TellTrackers()
		return
	end
	Holder():Show()
	if #spells > 0 then
		CheckGame()
	end
	local lists, missing = {}, {}
	for row = 1, CD.MAX_ROWS do
		lists[row] = {}
	end
	for _, entry in ipairs(entries) do
		local row = R.Call("RowOf", entry) or 1
		local list = lists[lists[row] and R.RowOn(row) and row or 1]
		list[#list + 1] = entry
	end
	R.Call("Samples", lists)
	for row = 1, CD.MAX_ROWS do
		if #lists[row] > 0 then
			R.Holder(row):Show()
			local note = Place(row)
			if note then
				missing[note] = true
			end
		elseif row > 1 and R.holders[row] then
			R.holders[row]:Hide()
		end
	end
	R.Notes(missing)
	Idle()
	shown = {}
	local crop = Crop()
	for row = 1, CD.MAX_ROWS do
		R.LayoutRow(row, lists[row], crop)
	end
	UpdateAll()
	Binds()
	RangeWatch()
	R.Call("AfterLayout")
	R.TellHitTable()
	R.TellTrackers()
end

function R.TellHitTable()
	if type(ns.HitTableMoved) == "function" then
		pcall(ns.HitTableMoved)
	end
end

function R.TellTrackers()
	local frames, row = ns.CooldownRow()
	local told = #frames .. (row and row:IsShown() and "+" or "-")
	if R.told ~= told then
		R.told = told
		if type(ns.TrackerPlaceAgain) == "function" then
			pcall(ns.TrackerPlaceAgain)
		end
	end
end

function R.Notes(missing)
	for _, note in ipairs({ NO_POSITION, CD.UNIT_FRAMES.player.note, CD.UNIT_FRAMES.target.note }) do
		if missing[note] then
			ns.Note(KEY, note)
		else
			ns.ClearNote(KEY, note)
		end
	end
end

function R.LayoutRow(row, list, crop)
	local anchor, rowShown = R.holders[row], {}
	local size, spacing, perRow = R.Opt(row, "size"), Opt("spacing"), Opt("perRow")
	local step, grow, above = size + spacing, R.Opt(row, "grow"), Opt("rows") == "up"
	for index, entry in ipairs(list) do
		local record = Acquire(index, row)
		if record.spell ~= entry.spell or record.item ~= entry.item or record.kind ~= entry.kind or record.slot ~= entry.slot or record.own ~= entry.own
			or record.sample ~= entry.sample then
			record.dimmed, record.readyPlayed = nil, nil
		end
		record.spell, record.item, record.kind, record.empty, record.hasRange = entry.spell, entry.item, entry.kind, nil, nil
		record.slot, record.own, record.sample = entry.slot, entry.own, entry.sample
		Tip.Mouse(record)
		if entry.spell then
			record.hasRange = HasRange(entry.spell)
		end
		record.picture = entry.sample and ns.IconSamplePicture(entry.sample) or entry.spell and SpellIcon(entry.spell) or ItemIcon(entry.item)
		record.texture:SetTexture(record.picture)
		record.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		local frame = record.frame
		frame:SetSize(size, size)
		local line, column = math.floor((index - 1) / perRow), (index - 1) % perRow
		local inRow = math.min(perRow, #list - line * perRow)
		local x
		if grow == "right" then
			x = column * step
		elseif grow == "left" then
			x = -size - column * step
		else
			x = -(inRow * size + (inRow - 1) * spacing) / 2 + column * step
		end
		frame:ClearAllPoints()
		if above then
			frame:SetPoint("BOTTOMLEFT", anchor, "CENTER", x, line * step)
		else
			frame:SetPoint("TOPLEFT", anchor, "CENTER", x, -line * step)
		end
		frame:Show()
		R.Call("Decorate", record, size)
		rowShown[#rowShown + 1] = record
		shown[#shown + 1] = record
	end
	local pool = R.pools[row] or {}
	for index = #list + 1, #pool do
		pool[index].frame:Hide()
	end
	R.shownOf[row] = rowShown
end

local function InterruptIcons()
	if type(ns.InterruptIcons) ~= "function" then
		return
	end
	local list = {}
	for _, record in ipairs(shown) do
		if record.spell then
			list[#list + 1] = { frame = record.frame, spell = record.spell, top = record.top }
		end
	end
	ns.InterruptIcons(list)
end

local function QueueLayout()
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
		pcall(InterruptIcons)
	end)
end

function ns.CooldownRow()
	local frames = {}
	if holder and ns.Enabled(KEY) then
		for _, record in ipairs(R.shownOf[1] or {}) do
			frames[#frames + 1] = record.frame
		end
	end
	return frames, holder
end

for row = 2, CD.MAX_ROWS do
	ns["CooldownRow" .. row] = function()
		local frames, anchor = {}, R.holders[row]
		if anchor and ns.Enabled(KEY) and R.RowOn(row) then
			for _, record in ipairs(R.shownOf[row] or {}) do
				frames[#frames + 1] = record.frame
			end
		end
		return frames, anchor
	end
end

function ns.CooldownsMoved()
	QueueLayout()
end

local function Distinguish(rows)
	local seen = {}
	for _, row in ipairs(rows) do
		seen[row[2]] = (seen[row[2]] or 0) + 1
	end
	for _, row in ipairs(rows) do
		if seen[row[2]] > 1 then
			local subtext = Ask(C_Spell and C_Spell.GetSpellSubtext, row[1])
			if Plain(subtext, "string") and subtext ~= "" then
				row[2] = row[2] .. " (" .. subtext .. ")"
			end
		end
	end
end

function ns.SpellBookList(keep)
	local rows = {}
	local book = SpellBook()
	if not book then
		return rows
	end
	local bank, spellType = Enum.SpellBookSpellBank.Player, Enum.SpellBookItemType.Spell
	local listed = {}
	local lines = Ask(book.GetNumSpellBookSkillLines)
	for line = 1, Plain(lines, "number") and lines or 0 do
		local skill = Ask(book.GetSpellBookSkillLineInfo, line)
		if type(skill) == "table" and skill.shouldHide ~= true and skill.offSpecID == nil
			and Plain(skill.itemIndexOffset, "number") and Plain(skill.numSpellBookItems, "number") then
			for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
				local item = Ask(book.GetSpellBookItemInfo, slot, bank)
				if type(item) == "table" and item.itemType == spellType and item.isPassive ~= true and item.isOffSpec ~= true then
					local id = item.spellID or item.actionID
					if Whole(id) and not listed[id] and Ask(book.IsSpellBookItemLowRank, slot, bank) ~= true then
						local label = Plain(item.name, "string") and item.name ~= "" and item.name or Name(id)
						if type(keep) ~= "function" or keep(id, label) then
							listed[id] = true
							rows[#rows + 1] = { id, label }
						end
					end
				end
			end
		end
	end
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	Distinguish(rows)
	return rows
end

function ns.CooldownCandidates()
	if not SpellBook() then
		if ns.Enabled(KEY) then
			ns.Note(KEY, NO_BOOK)
		end
		return {}
	end
	local listed, named = {}, {}
	for _, id in ipairs(List()) do
		listed[id] = true
		if Known(id) then
			named[Name(id)] = true
		end
	end
	return ns.SpellBookList(function(id, label)
		return not listed[id] and not named[label] and HasCooldown(id)
	end)
end

function ns.CooldownPicked()
	local rows = {}
	for _, id in ipairs(List()) do
		rows[#rows + 1] = { id, Name(id) }
	end
	Distinguish(rows)
	for _, row in ipairs(rows) do
		if not Known(row[1]) then
			row[2] = row[2] .. " (not known)"
		end
	end
	return rows
end

function ns.CooldownAdd(spellID)
	if not (Whole(spellID) and SpellName(spellID)) then
		return false, ('No spell found for "%s".'):format(tostring(spellID))
	end
	local list = List()
	for _, id in ipairs(list) do
		if id == spellID then
			return false, ("%s is already picked."):format(Name(spellID))
		end
	end
	if #list >= MAX_SPELLS then
		return false, ("%d spells is the most."):format(MAX_SPELLS)
	end
	list[#list + 1] = spellID
	QueueLayout()
	return true, ("Added %s."):format(Name(spellID))
end

function ns.CooldownRemove(spellID)
	local list = List()
	for index, id in ipairs(list) do
		if id == spellID then
			table.remove(list, index)
			SetOwnSound(id, nil)
			R.Call("Forget", id)
			QueueLayout()
			return true, ("Removed %s."):format(Name(spellID))
		end
	end
	return false, ("%s is not picked."):format(Name(spellID))
end

function R.RowShown(id)
	if not Known(id) then
		return nil
	end
	local row = R.Call("Assigned", id)
	return row and R.RowOn(row) and row or 1
end

function R.RowsOn()
	for row = 2, CD.MAX_ROWS do
		if R.RowOn(row) then
			return true
		end
	end
	return false
end

function ns.CooldownOrderLines()
	local rows, places = {}, {}
	for _, id in ipairs(List()) do
		rows[#rows + 1] = { id, Name(id) }
	end
	Distinguish(rows)
	for _, line in ipairs(rows) do
		local row = R.RowShown(line[1])
		if row == nil then
			line[2] = line[2] .. " (not known)"
		else
			places[row] = (places[row] or 0) + 1
			line[2] = ("%d. %s"):format(places[row], line[2]) .. (row > 1 and (" (row %d)"):format(row) or "")
		end
	end
	return rows
end

function R.Move(spellID, step)
	local list = List()
	local at
	for index, id in ipairs(list) do
		if id == spellID then
			at = index
		end
	end
	if not at then
		return false, ("%s is not picked."):format(Whole(spellID) and Name(spellID) or tostring(spellID))
	end
	local name, mine = Name(spellID), R.RowShown(spellID)
	if mine == nil then
		return false, ("%s is not known yet, so it has no place on the row."):format(name)
	end
	local to = at + step
	while list[to] ~= nil and R.RowShown(list[to]) ~= mine do
		to = to + step
	end
	if list[to] == nil then
		return false, (step < 0 and "%s is first on its row already." or "%s is last on its row already."):format(name)
	end
	table.remove(list, at)
	table.insert(list, to, spellID)
	QueueLayout()
	local place = 0
	for index = 1, to do
		if R.RowShown(list[index]) == mine then
			place = place + 1
		end
	end
	if R.RowsOn() then
		return true, ("%s is now number %d of row %d."):format(name, place, mine)
	end
	return true, ("%s is now number %d of the row."):format(name, place)
end

function ns.CooldownMoveLeft(spellID)
	return R.Move(spellID, -1)
end

function ns.CooldownMoveRight(spellID)
	return R.Move(spellID, 1)
end

function ns.CooldownItemCandidates()
	local rows, picked = {}, {}
	for _, key in ipairs(Kinds()) do
		picked[key] = true
	end
	for index, kind in ipairs(type(ns.COOLDOWN_ITEMS) == "table" and ns.COOLDOWN_ITEMS or {}) do
		if type(kind) == "table" and not picked[kind.key] and Kind(kind.key) == kind then
			rows[#rows + 1] = { index, kind.name }
		end
	end
	return rows
end

function ns.CooldownItemPicked()
	local rows = {}
	for _, key in ipairs(Kinds()) do
		local kind, index = Kind(key)
		rows[#rows + 1] = { index, kind.name }
	end
	return rows
end

function ns.CooldownAddItem(index)
	local kind = KindAt(index)
	if not kind then
		return false, "No such potion or healthstone."
	end
	if #Ranks(kind) == 0 then
		return false, ("%s: this client has none."):format(kind.name)
	end
	local list = Kinds(true)
	for _, key in ipairs(list) do
		if key == kind.key then
			return false, ("%s is already picked."):format(kind.name)
		end
	end
	list[#list + 1] = kind.key
	QueueLayout()
	return true, ("Added %s."):format(kind.name)
end

function ns.CooldownRemoveItem(index)
	local kind = KindAt(index)
	if not kind then
		return false, "No such potion or healthstone."
	end
	local list = Kinds()
	for at, key in ipairs(list) do
		if key == kind.key then
			table.remove(list, at)
			SetOwnSound(key, nil)
			R.Call("Forget", key)
			QueueLayout()
			return true, ("Removed %s."):format(kind.name)
		end
	end
	return false, ("%s is not picked."):format(kind.name)
end

function ns.CooldownOwnItemCandidates()
	local rows, seen = {}, {}
	if not (C_Item and type(C_Item.GetItemSpell) == "function") then
		return rows
	end
	for _, id in ipairs(Own.List()) do
		seen[id] = true
	end
	for _, item in ipairs(Own.Bags()) do
		local id = item[1]
		if not seen[id] then
			seen[id] = true
			if not Own.KindOf(id) and Own.HasUse(id) then
				rows[#rows + 1] = { id, item[2] or Own.Name(id) }
			end
		end
	end
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	while #rows > CD.MAX_BAG_LINES do
		rows[#rows] = nil
	end
	return rows
end

function ns.CooldownOwnItemPicked()
	local rows = {}
	for _, id in ipairs(Own.List()) do
		rows[#rows + 1] = { id, Own.Name(id) }
	end
	return rows
end

function ns.CooldownAddOwnItem(itemID)
	if not Whole(itemID) or (C_Item and type(C_Item.GetItemInfoInstant) == "function" and Ask(C_Item.GetItemInfoInstant, itemID) == nil) then
		return false, ('No item found for "%s".'):format(tostring(itemID))
	end
	local name = Own.Name(itemID)
	local kind = Own.KindOf(itemID)
	if kind then
		return false, ("%s is a rank of %s, which has an icon of its own: /flatui cooldown add %s."):format(name, kind.name, kind.key)
	end
	if Own.HasUse(itemID) == false then
		return false, ("%s has no use."):format(name)
	end
	local list = Own.List(true)
	for _, id in ipairs(list) do
		if id == itemID then
			return false, ("%s is already on the row."):format(name)
		end
	end
	if #list >= CD.MAX_OWN_ITEMS then
		return false, ("%d items is the most."):format(CD.MAX_OWN_ITEMS)
	end
	list[#list + 1] = itemID
	QueueLayout()
	return true, ("Added %s."):format(name)
end

function ns.CooldownRemoveOwnItem(itemID)
	local list = Own.List()
	for at, id in ipairs(list) do
		if id == itemID then
			table.remove(list, at)
			SetOwnSound(ItemKey(id), nil)
			R.Call("Forget", ItemKey(id))
			QueueLayout()
			return true, ("Removed %s."):format(Own.Name(id))
		end
	end
	return false, ("%s is not on the row."):format(Whole(itemID) and Own.Name(itemID) or tostring(itemID))
end

function ns.CooldownImportLines()
	local rows = {}
	for bar = 1, #CD.IMPORT_FIRST do
		rows[bar] = { bar, ("Action bar %d"):format(bar) }
	end
	return rows
end

function Bar.MainPage()
	local bars = type(C_ActionBar) == "table" and C_ActionBar or {}
	local page = Ask(bars.GetActionBarPage)
	if page == 1 and Ask(bars.HasBonusActionBar) == true then
		page = Ask(bars.GetBonusBarIndex)
	end
	if Whole(page) and page <= CD.MAX_PAGE then
		return page
	end
	return 1
end

function Bar.SlotAction(slot)
	local ok, kind, id, sub = pcall(GetActionInfo, slot)
	if not ok or IsSecret(kind) or IsSecret(id) or IsSecret(sub) or kind == nil then
		return nil
	end
	if kind == "macro" then
		if sub == "spell" then
			return "spell", id
		end
		local spell = (sub == nil or sub == "") and Plain(id, "number") and Ask(GetMacroSpell, id) or nil
		if Whole(spell) then
			return "spell", spell
		end
	end
	return kind, id
end

function ns.ActionSpell(slot)
	if not Whole(slot) then
		return nil
	end
	local kind, id = Bar.SlotAction(slot)
	if kind == "spell" and Whole(id) then
		return id
	end
	return nil
end

function ns.BarSpells(bar)
	local spells, others = {}, 0
	if not (Whole(bar) and bar <= #CD.IMPORT_FIRST) or type(GetActionInfo) ~= "function" then
		return spells, others
	end
	local first = bar == 1 and (Bar.MainPage() - 1) * 12 + 1 or CD.IMPORT_FIRST[bar]
	local seen = {}
	for slot = first, first + 11 do
		local kind, id = Bar.SlotAction(slot)
		if kind == "spell" and Whole(id) then
			if not seen[id] then
				seen[id] = true
				spells[#spells + 1] = id
			end
		elseif kind ~= nil then
			others = others + 1
		end
	end
	return spells, others
end

function ns.CooldownImport(bar)
	if not (Whole(bar) and bar <= #CD.IMPORT_FIRST) then
		return false, CD.IMPORT_HELP
	end
	if type(GetActionInfo) ~= "function" then
		ns.Note(KEY, CD.NO_BAR)
		return false, CD.NO_BAR
	end
	local first = bar == 1 and (Bar.MainPage() - 1) * 12 + 1 or CD.IMPORT_FIRST[bar]
	local added, left, had, full = 0, 0, 0, false
	local picked, named, seen, kinds = {}, {}, {}, {}
	for _, id in ipairs(List()) do
		picked[id] = true
		if Known(id) then
			named[Name(id)] = true
		end
	end
	for _, key in ipairs(Kinds()) do
		kinds[key] = true
	end
	for slot = first, first + 11 do
		local kind, id = Bar.SlotAction(slot)
		if kind == "spell" and Whole(id) then
			local name = SpellName(id)
			if seen[id] then
			elseif picked[id] or (name and named[name]) then
				had = had + 1
			elseif name and HasCooldown(id) and ns.CooldownAdd(id) then
				added = added + 1
				picked[id], named[name] = true, true
			else
				full = full or (name ~= nil and HasCooldown(id) and #List() >= MAX_SPELLS)
				left = left + 1
			end
			seen[id] = true
		elseif kind == "item" and Whole(id) then
			local itemKind, index = Own.KindOf(id)
			if itemKind and seen[itemKind.key] then
			elseif itemKind and kinds[itemKind.key] then
				had = had + 1
			elseif itemKind and ns.CooldownAddItem(index) then
				added = added + 1
				kinds[itemKind.key] = true
			else
				left = left + 1
			end
			if itemKind then
				seen[itemKind.key] = true
			end
		elseif kind ~= nil then
			left = left + 1
		end
	end
	if added + left + had == 0 then
		return true, ("Action bar %d has nothing to add."):format(bar)
	end
	local said = ("Action bar %d: %d added, %d left out."):format(bar, added, left)
	if had > 0 then
		said = said .. (" %d %s already on the row."):format(had, had == 1 and "was" or "were")
	end
	if full then
		said = said .. (" %d spells is the most."):format(MAX_SPELLS)
	end
	return true, said
end

function ns.CooldownImportPick(bar)
	return ns.CooldownImport(bar)
end

function R.Entries()
	local rows = {}
	for _, id in ipairs(List()) do
		rows[#rows + 1] = { id, Name(id), id }
	end
	Distinguish(rows)
	for _, entry in ipairs(Trinkets()) do
		rows[#rows + 1] = { -(CD.SLOT_LINE + entry.slot), CD.SLOT_NAMES[entry.slot], SlotKey(entry.slot) }
	end
	for _, key in ipairs(Kinds()) do
		local kind, index = Kind(key)
		rows[#rows + 1] = { -index, kind.name, key }
	end
	for _, id in ipairs(Own.List()) do
		rows[#rows + 1] = { -(CD.ITEM_LINE + id), Own.Name(id), ItemKey(id) }
	end
	return rows
end

local function SoundEntries()
	local rows, chosen = R.Entries(), nil
	for _, row in ipairs(rows) do
		if soundFor ~= nil and row[3] == soundFor then
			chosen = row
		end
	end
	if not chosen then
		soundFor = nil
	end
	return rows, chosen
end

function ns.CooldownSoundLines()
	local rows, chosen = SoundEntries()
	local lines = {}
	if not chosen then
		for _, row in ipairs(rows) do
			local own = OwnSound(row[3])
			lines[#lines + 1] = { row[1], own and ("%s (%s)"):format(row[2], SoundName(own)) or row[2] }
		end
		return lines
	end
	lines[1] = { SOUND_ROW, chosen[2] .. ": the row's sound" }
	lines[2] = { SOUND_NONE, chosen[2] .. ": no sound" }
	for index, word in ipairs(SOUND_WORDS) do
		lines[#lines + 1] = { SOUND_NONE + index, chosen[2] .. ": " .. SoundName(word) }
	end
	lines[#lines + 1] = { SOUND_BACK, "Another icon" }
	return lines
end

function ns.CooldownSoundPick(id)
	local rows, chosen = SoundEntries()
	if not chosen then
		for _, row in ipairs(rows) do
			if row[1] == id then
				soundFor = row[3]
				return true, ("%s: open the list again to choose its sound."):format(row[2])
			end
		end
		return false, "That icon is not on the row."
	end
	soundFor = nil
	local word
	if id == SOUND_NONE then
		word = "none"
	elseif Plain(id, "number") and id > SOUND_NONE and SOUND_WORDS[id - SOUND_NONE] then
		word = SOUND_WORDS[id - SOUND_NONE]
	elseif id ~= SOUND_ROW then
		return true, nil
	end
	SetOwnSound(chosen[3], word)
	return true, SoundSaid(chosen[2], word)
end

local SOUND_HELP = "/flatui cooldown sound 2094 bell - a picked spell, healing, mana or healthstone, a slot such as trinket 1 or feet, or item and an item's"
	.. " name, then row, none, spell, chimes, bell, warhorn, raid, alarm or whisper"

function Own.Named(text)
	local wanted = text:lower()
	for _, id in ipairs(Own.List()) do
		if Own.Name(id):lower() == wanted then
			return id
		end
	end
	return nil
end

local function SoundCommand(text)
	local name, said = text:match("^%s*(.-)%s+(%S+)%s*$")
	said = said and said:lower()
	if not (name and name ~= "" and (said == "row" or said == "none" or SOUND_INDEX[said])) then
		return SOUND_HELP
	end
	local key, kind, slot = nil, KindNamed(name), CD.SLOT_BY_NAME[name:lower()]
	local itemText = name:match("^[Ii][Tt][Ee][Mm]%s+(.+)$") or (name:find("|Hitem:", 1, true) and name) or name:match("^[Ii]tem:%d+$")
	local itemID = itemText and Own.From(itemText) or (not slot and not kind and Own.Named(name)) or nil
	if slot then
		for _, entry in ipairs(Trinkets()) do
			key = entry.slot == slot and SlotKey(slot) or key
		end
		name = CD.SLOT_NAMES[slot]
	elseif kind then
		for _, picked in ipairs(Kinds()) do
			key = picked == kind.key and picked or key
		end
		name = kind.name
	elseif itemText or itemID then
		for _, picked in ipairs(Own.List()) do
			key = picked == itemID and ItemKey(picked) or key
		end
		name = itemID and Own.Name(itemID) or itemText
	else
		local id = Parse(name) or Resolve(name)
		local same = id and SpellName(id)
		for _, picked in ipairs(List()) do
			if picked == id then
				key = picked
				break
			elseif key == nil and same and SpellName(picked) == same then
				key = picked
			end
		end
		name = id and Name(id) or name
	end
	if key == nil then
		return ((slot or itemText or itemID) and "%s is not on the row." or "%s is not picked."):format(name)
	end
	local word = said ~= "row" and said or nil
	SetOwnSound(key, word)
	return SoundSaid(name, word)
end

function Own.Command(word, text)
	if text:match("^%s*$") then
		return CD.ITEM_HELP
	end
	local id = Own.From(text)
	if not id then
		return ('No item found for "%s".'):format(text:match("^%s*(.-)%s*$"))
	end
	local _, message = (word == "add" and ns.CooldownAddOwnItem or ns.CooldownRemoveOwnItem)(id)
	return message
end

local function OwnSaid(key)
	local own = OwnSound(key)
	return (own and (", plays %s"):format(SoundName(own)) or "") .. (R.Call("Said", key) or "")
end

local function Slash(rest)
	local word, text = rest:match("^(%S*)%s*(.-)$")
	word = word:lower()
	local kind, place, itemText
	if (word == "add" or word == "remove") and text ~= "" then
		kind, place = KindNamed(text)
		itemText = text:match("^[Ii][Tt][Ee][Mm]%s+(.-)$") or (text:lower() == "item" and "") or ((text:find("|Hitem:", 1, true) or text:match("^[Ii]tem:%d+$"))
			and text) or nil
	end
	if itemText and not kind then
		print(Own.Command(word, itemText))
	elseif word == "import" then
		local _, message = ns.CooldownImport(tonumber(text:match("^%s*(%d+)%s*$") or ""))
		print(message)
	elseif kind then
		local _, message = (word == "add" and ns.CooldownAddItem or ns.CooldownRemoveItem)(place)
		print(message)
	elseif (word == "add" or word == "remove") and text ~= "" then
		local id = (word == "remove" and Parse(text)) or Resolve(text)
		if not id then
			print(('No spell found for "%s".'):format(text))
			return
		end
		local _, message = (word == "add" and ns.CooldownAdd or ns.CooldownRemove)(id)
		print(message)
	elseif word == "sound" and text ~= "" then
		print(SoundCommand(text))
	elseif word == "list" then
		local list, slots, kinds, own = List(), Trinkets(), Kinds(), Own.List()
		if #list == 0 and #slots == 0 and #kinds == 0 and #own == 0 then
			print("No spells picked.")
		end
		for index, id in ipairs(list) do
			print(("%d. %s (%d)%s%s"):format(index, Name(id), id, Known(id) and "" or ", not known", OwnSaid(id)))
		end
		for index, entry in ipairs(slots) do
			print(("%d. %s: %s (item %d)%s"):format(#list + index, CD.SLOT_NAMES[entry.slot], Own.Name(entry.item), entry.item, OwnSaid(SlotKey(entry.slot))))
		end
		for index, key in ipairs(kinds) do
			print(("%d. %s%s"):format(#list + #slots + index, Kind(key).name, OwnSaid(key)))
		end
		for index, id in ipairs(own) do
			print(("%d. %s (item %d)%s"):format(#list + #slots + #kinds + index, Own.Name(id), id, OwnSaid(ItemKey(id))))
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

local function Refresh()
	local on = ns.Enabled(KEY)
	if holder and not on then
		holder:Hide()
	elseif holder and shown[1] then
		holder:Show()
	end
	for row = 2, CD.MAX_ROWS do
		local frame = R.holders[row]
		if frame and not on then
			frame:Hide()
		elseif frame and (R.shownOf[row] or {})[1] then
			frame:Show()
		end
	end
	fighting = InCombatLockdown() == true
	Idle()
	QueueLayout()
	QueueSweep()
	UpdateAll()
	Binds()
	Tip.MouseAll()
end

local function UpdateItems()
	for _, record in ipairs(shown) do
		if record.item then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end
end

local function KindsChanged()
	for _, record in ipairs(shown) do
		if record.kind then
			ns.Each(KEY, Update, record)
		end
	end
end

function Counts.One(record)
	local charges, none = Counts.Charges(record.spell)
	local maximum = type(charges) == "table" and charges.maxCharges
	Counts.Spell(record, Plain(maximum, "number") and maximum > 1, none)
end

function Counts.All()
	if Opt("useCount") then
		for _, record in ipairs(shown) do
			if record.spell then
				ns.Each(KEY, Counts.One, record)
			end
		end
	end
end

local function BagsChanged()
	KindsChanged()
	for _, record in ipairs(shown) do
		if record.own then
			ns.Each(KEY, Ready, record)
			ns.Each(KEY, Update, record)
		end
	end
	Counts.All()
end

local function ItemLoaded(itemID)
	if not Whole(itemID) then
		return
	end
	Own.stacks[itemID] = nil
	local waited = Own.loading[itemID] and Own.uses[itemID] == nil
	Own.loading[itemID] = nil
	if waited and Opt("gear") then
		QueueLayout()
	end
	for _, record in ipairs(shown) do
		if record.own == itemID then
			record.picture = ItemIcon(itemID)
			record.texture:SetTexture(record.picture)
			ns.Each(KEY, Update, record)
		end
	end
end

local function Changed()
	QueueLayout()
	QueueSweepSoon()
end

R.KEY, R.Get, R.Ask, R.Field, R.Plain, R.Whole, R.IsTrue = KEY, Opt, Ask, Field, Plain, Whole, IsTrue
R.SpellName, R.KeyOf, R.Crop, R.QueueLayout, R.UpdateAll = SpellName, SoundKey, Crop, QueueLayout, UpdateAll
R.NumbersFont, R.Numbers, R.FONT_PART, R.NUMBERS_PART = NumbersFont, Looks.Numbers, FONT_PART, CD.NUMBERS_PART
R.Look = Look

ns.Register(KEY, {
	label = "Cooldowns",
	Start = Refresh,
	Refresh = Refresh,
	Resized = QueueLayout,
	events = {
		SPELL_UPDATE_COOLDOWN = UpdateAll,
		SPELL_UPDATE_CHARGES = UpdateAll,
		BAG_UPDATE_COOLDOWN = UpdateItems,
		PLAYER_EQUIPMENT_CHANGED = QueueLayout,
		UPDATE_BINDINGS = Binds,
		ACTIONBAR_SLOT_CHANGED = Binds,
		UPDATE_BONUS_ACTIONBAR = BindsSoon,
		ACTIONBAR_PAGE_CHANGED = BindsSoon,
		UPDATE_SHAPESHIFT_FORM = BindsSoon,
		PLAYER_REGEN_DISABLED = function()
			fighting = true
			Idle()
		end,
		PLAYER_REGEN_ENABLED = function()
			fighting = false
			Idle()
		end,
		PLAYER_MOUNT_DISPLAY_CHANGED = Idle,
		PLAYER_UPDATE_RESTING = Idle,
		PLAYER_TARGET_CHANGED = TargetChanged,
		SPELL_UPDATE_USABLE = TintAll,
		BAG_UPDATE_DELAYED = BagsChanged,
		SPELL_UPDATE_USES = Counts.All,
		GET_ITEM_INFO_RECEIVED = ItemLoaded,
		PLAYER_LEVEL_CHANGED = KindsChanged,
		SPELLS_CHANGED = Changed,
		PLAYER_TALENT_UPDATE = Changed,
		ACTIVE_TALENT_GROUP_CHANGED = Changed,
		PLAYER_ENTERING_WORLD = Changed,
		COOLDOWN_VIEWER_DATA_LOADED = QueueSweepSoon,
		EDIT_MODE_LAYOUTS_UPDATED = QueueSweepSoon,
	},
	slash = { cooldown = Slash },
	help = HELP,
})
