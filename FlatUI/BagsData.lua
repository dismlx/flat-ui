local _, ns = ...

local KEY = "bags"
local PART = "cache"
local TIPS = "tooltips"
local B = ns.Bags
if type(B) ~= "table" or type(B.Data) ~= "table" then
	return
end
local Data = B.Data

local LAYOUT = 1
local KEYRING, BACKPACK, REAGENT = -1, 0, 5
local FIRST_TAB, LAST_TAB, BANK_BAGS, TAB_OF_SLOT = 6, 14, -2, 5
local LAST_WORN = 19
local MAX_TEXT = 80
local ITEM_FIELDS = 8
local MAX_SLOTS = 255
local INDEX_STEP = 2000
local QUEST_EVERY, FULL_WAIT, SWEEP, REALMS_AGAIN = 1, 2, 60, 60
local GRACE = 2
local DAY = 86400
local MANY = 40
local QUEST_CLASS = 12
local SECTIONS = { "bags", "bagItems", "bank", "bankItems", "worn" }
local WINDOWS = { "bags", "bank" }
local CHARACTER_BANK = 0
local BANKERS = { { "Banker", 8 }, { "CharacterBanker", 67 }, { "AccountBanker", 68 } }
local REAGENT_WORD, BAG_WORD, BAGS_WORD = "Reagent bag", "Bag", "Bags"
local EMPTY = {}
local WEAK_VALUES, WEAK_KEYS = { __mode = "v" }, { __mode = "k" }

local last = {}
local dirty = {}
local full, bankFull, fullTimer, sweptAt = true, false, false, nil
local bankLive, liveTabs, tabsSign = false, {}, nil
local grace
local keyring
local kinds, live = {}, {}
local decoded = {}
local textOf = setmetatable({}, WEAK_KEYS)
local infos, asked, pending, waiting = {}, {}, {}, {}
local index, who, builtWithout, building
local generation = 0
local myRealm, connected, realmsAt
local questAt, questQueued = nil, false
local remarkAll = false
local muted = false

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

local function Client(space, name)
	local holder = _G
	if space ~= nil then
		holder = _G[space]
		if IsSecret(holder) or type(holder) ~= "table" then
			return nil
		end
	end
	local fn = holder[name]
	if IsSecret(fn) or type(fn) ~= "function" then
		return nil
	end
	return fn
end

local function Ask(fn, ...)
	if not fn then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Ask2(fn, ...)
	if not fn then
		return nil, nil
	end
	local ok, first, second = pcall(fn, ...)
	if not ok then
		return nil, nil
	end
	if IsSecret(first) then
		first = nil
	end
	if IsSecret(second) then
		second = nil
	end
	return first, second
end

local function Whole(value)
	if Finite(value) and value % 1 == 0 then
		return value
	end
	return nil
end

local function Count(value)
	value = Whole(value)
	if value ~= nil and value >= 0 then
		return value
	end
	return nil
end

local function Text(value)
	if IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function Flag(value)
	return not IsSecret(value) and value == true
end

local function Icon(value)
	if Finite(value) and value > 0 then
		return value
	end
	return Text(value)
end

local function Container(value)
	value = Whole(value)
	if value ~= nil and value >= KEYRING and value <= LAST_TAB then
		return value
	end
	return nil
end

local function Slot(value)
	value = Whole(value)
	if value ~= nil and value >= 1 and value <= MAX_SLOTS then
		return value
	end
	return nil
end

local function Held(bag)
	return bag == KEYRING or (bag >= BACKPACK and bag <= REAGENT)
end

local function IsTab(bag)
	return bag >= FIRST_TAB and bag <= LAST_TAB
end

local function Me()
	local key = ns.CharacterKey()
	if IsSecret(key) or type(key) ~= "string" or key == "" then
		return nil
	end
	return key
end

local function Now()
	return Count(Ask(Client(nil, "time")))
end

local function Clock()
	local now = Ask(Client(nil, "GetTime"))
	if Finite(now) then
		return now
	end
	return nil
end

local function After(seconds, fn)
	local timer = Client("C_Timer", "After")
	if not (timer and pcall(timer, seconds, fn)) then
		fn()
	end
end

local function Running()
	local ok, on = pcall(ns.Enabled, KEY)
	return ok and on == true
end

local function Stopped()
	local ok, stopped = pcall(ns.PartStopped, KEY, PART)
	return not ok or stopped == true
end

local function Writing()
	return not muted and Running() and not Stopped()
end

local function Active()
	local on = B.On
	if type(on) ~= "function" then
		return false
	end
	local ok, yes = pcall(on)
	return ok and yes == true
end

local function Part(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(PART, fn, ...)
	end
	return ns.EachPart(KEY, PART, function(_, ...)
		return fn(...)
	end, {}, ...)
end

local function TipsPart(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(TIPS, fn, ...)
	end
	return ns.EachPart(KEY, TIPS, function(_, ...)
		return fn(...)
	end, {}, ...)
end

local function Request(flag, which, changed)
	local request = B.Request
	if type(request) == "function" then
		request(flag, which, changed)
	end
end

local function Word(name, english)
	local word = _G[name]
	if IsSecret(word) or type(word) ~= "string" or word == "" then
		return english
	end
	return word
end

local function EnumValue(group, name, fallback)
	local enum = _G.Enum
	if IsSecret(enum) or type(enum) ~= "table" then
		return fallback
	end
	local values = enum[group]
	if IsSecret(values) or type(values) ~= "table" then
		return fallback
	end
	local value = Whole(values[name])
	if value == nil then
		return fallback
	end
	return value
end

function Data.Info(id)
	id = Count(id)
	if not id or id == 0 then
		return nil
	end
	local info = infos[id]
	if info then
		return info
	end
	local instant = Client("C_Item", "GetItemInfoInstant")
	if not instant then
		return nil
	end
	local ok, itemID, itype, isubtype, equipLoc, icon, class, subclass = pcall(instant, id)
	if not ok or IsSecret(itemID) or itemID == nil then
		return nil
	end
	info = { class = Count(class), subclass = Count(subclass), equipLoc = Text(equipLoc), itype = Text(itype), isubtype = Text(isubtype),
		icon = Icon(icon) }
	infos[id] = info
	return info
end

local function ItemName(id)
	return Text(Ask(Client("C_Item", "GetItemNameByID"), id))
end

local function QualityOf(id)
	return Count(Ask(Client("C_Item", "GetItemQualityByID"), id))
end

local function IconOf(id)
	return Icon(Ask(Client("C_Item", "GetItemIconByID"), id))
end

local function SubclassName(class, subclass)
	if class == nil or subclass == nil then
		return nil
	end
	return Text(Ask(Client("C_Item", "GetItemSubClassInfo"), class, subclass))
end

local function LinkName(link)
	local name = link and link:match("|h%[(.-)%]|h")
	if not name then
		return nil
	end
	return Text((name:gsub("%s*|A.-|a", "")))
end

local function ItemString(link, id)
	if not link then
		return nil
	end
	local payload = link:match("|Hitem:([^|]*)|h") or link:match("^item:([^|]*)$")
	if not payload then
		return nil
	end
	local fields, count = {}, 0
	for field in (payload .. ":"):gmatch("([^:]*):") do
		if count == ITEM_FIELDS then
			break
		end
		if field ~= "" and not field:match("^%-?%d+$") then
			return nil
		end
		count = count + 1
		fields[count] = field
	end
	if count == 0 or tonumber(fields[1]) ~= id then
		return nil
	end
	for index = 2, count do
		local field = fields[index]
		if field ~= "" and tonumber(field) ~= 0 then
			return table.concat(fields, ":", 1, count)
		end
	end
	return nil
end

local function Encode(state)
	local text = ("%d"):format(state.id)
	if state.count > 1 then
		text = text .. ("*%d"):format(state.count)
	end
	if state.quality then
		text = text .. ("#%d"):format(state.quality)
	end
	local flags = (state.bound and "b" or "") .. (state.quest and "q" or "") .. (state.start and "s" or "") .. (state.set and "e" or "")
		.. (state.noValue and "n" or "")
	if flags ~= "" then
		text = text .. "~" .. flags
	end
	local item = ItemString(state.link, state.id)
	if item and #text + 1 + #item <= MAX_TEXT then
		text = text .. "@" .. item
	end
	return text
end

local function Decode(text)
	if type(text) ~= "string" then
		return nil
	end
	local id, rest = text:match("^(%d+)(.*)$")
	id = tonumber(id)
	if not id or id == 0 then
		return nil
	end
	local count, quality, flags, item = 1, nil, "", nil
	local found = rest:match("^%*(%d+)")
	if found then
		count = tonumber(found)
		rest = rest:sub(#found + 2)
	end
	found = rest:match("^#(%d+)")
	if found then
		quality = tonumber(found)
		rest = rest:sub(#found + 2)
	end
	found = rest:match("^~(%a+)")
	if found then
		flags = found
		rest = rest:sub(#found + 2)
	end
	found = rest:match("^@([%-%d:]+)$")
	if found then
		item = found
		rest = ""
	end
	if rest ~= "" or not count or count < 1 then
		return nil
	end
	return id, count, quality, flags, item
end

local function Has(flags, letter)
	return flags:find(letter, 1, true) ~= nil
end

local function Store(create)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	local store = db.bags
	if type(store) ~= "table" then
		if not create then
			return nil
		end
		store = {}
		db.bags = store
	end
	if store.v ~= LAYOUT or type(store.chars) ~= "table" then
		if not create then
			return nil
		end
		store.v, store.chars = LAYOUT, {}
	end
	return store
end

local function Character(key)
	if type(key) ~= "string" then
		return nil
	end
	local store = Store(false)
	local record = store and store.chars[key]
	if type(record) == "table" then
		return record
	end
	return nil
end

local function Identity(record)
	record.realm = Text(Ask(Client(nil, "GetNormalizedRealmName"))) or record.realm
	record.class = Text(Ask(Client(nil, "UnitClassBase"), "player")) or record.class
	record.faction = Text(Ask(Client(nil, "UnitFactionGroup"), "player")) or record.faction
	local level = Count(Ask(Client(nil, "UnitLevel"), "player"))
	if level and level > 0 then
		record.level = level
	end
	local money = Count(Ask(Client(nil, "GetMoney")))
	if money then
		record.money = money
		record.seen = Now() or record.seen
	end
end

local function Mine(create)
	local key = Me()
	if not key then
		return nil
	end
	if not create then
		return Character(key)
	end
	if not Writing() then
		return nil
	end
	local store = Store(true)
	if not store then
		return nil
	end
	local record = store.chars[key]
	local made = type(record) ~= "table"
	if made then
		record = {}
		store.chars[key] = record
	end
	for _, name in ipairs(SECTIONS) do
		if type(record[name]) ~= "table" then
			record[name] = {}
		end
	end
	if made then
		Identity(record)
	end
	return record
end

local function SlotsOf(record, bag)
	local section = record.bags
	if IsTab(bag) then
		section = record.bank
	end
	if type(section) ~= "table" then
		return nil
	end
	local slots = section[bag]
	if type(slots) == "table" then
		return slots
	end
	return nil
end

local function SizeOf(slots)
	local size = slots and Count(slots.n)
	if size and size <= MAX_SLOTS then
		return size
	end
	return 0
end

local function LiveBagItem(bag)
	local id
	if bag >= 1 and bag <= REAGENT then
		local slot = Count(Ask(Client("C_Container", "ContainerIDToInventoryID"), bag))
		id = slot and Count(Ask(Client(nil, "GetInventoryItemID"), "player", slot))
	elseif bag > FIRST_TAB and bag <= LAST_TAB then
		id = Count(Ask(Client("C_Container", "GetContainerItemID"), BANK_BAGS, bag - TAB_OF_SLOT))
	end
	if id and id > 0 then
		return id
	end
	return nil
end

local function MakeKind(bag, id, family)
	family = Count(family) or 0
	local kind = { id = id, family = family }
	local info = id and Data.Info(id)
	if info then
		kind.class, kind.subclass = info.class, info.subclass
	end
	if id then
		kind.name = ItemName(id)
	end
	if bag == KEYRING then
		kind.key, kind.label = "keyring", Word("KEYRING", "Keyring")
	elseif bag == REAGENT then
		kind.key, kind.label = "reagent", REAGENT_WORD
	elseif family == 0 then
		kind.key = "bag"
		if bag == BACKPACK then
			kind.label = Word("BACKPACK_TOOLTIP", "Backpack")
		elseif bag == FIRST_TAB then
			kind.label = Word("BANK", "Bank")
		else
			kind.label = SubclassName(kind.class, kind.subclass) or BAG_WORD
		end
	else
		if kind.class ~= nil and kind.subclass ~= nil then
			kind.key = ("c%d.%d"):format(kind.class, kind.subclass)
		else
			kind.key = ("f%d"):format(family)
		end
		kind.label = SubclassName(kind.class, kind.subclass) or kind.name or BAG_WORD
	end
	return kind
end

local function LiveKind(bag)
	local kind = kinds[bag]
	if not kind then
		local _, family = Ask2(Client("C_Container", "GetContainerNumFreeSlots"), bag)
		kind = MakeKind(bag, LiveBagItem(bag), family)
		kinds[bag] = kind
	end
	return kind
end

local function StoredKind(record, bag, slots)
	local id
	if record then
		if bag >= 1 and bag <= REAGENT and type(record.bagItems) == "table" then
			id = Count(record.bagItems[bag])
		elseif bag > FIRST_TAB and bag <= LAST_TAB and type(record.bankItems) == "table" then
			id = Count(record.bankItems[bag - TAB_OF_SLOT])
		end
	end
	if id == 0 then
		id = nil
	end
	return MakeKind(bag, id, slots and slots.f)
end

local function ShowsKeyring()
	return Ask(Client("C_ActionBar", "ShouldShowKeyring")) == true
end

local function Keyring()
	if keyring == nil then
		keyring = ShowsKeyring()
	end
	return keyring
end

local function ReadSlot(bag, slot)
	local info = Ask(Client("C_Container", "GetContainerItemInfo"), bag, slot)
	if type(info) ~= "table" then
		return nil
	end
	local id = Count(info.itemID)
	if not id or id == 0 then
		return nil
	end
	local count = Count(info.stackCount)
	if not count or count < 1 then
		count = 1
	end
	return id, Text(info.hyperlink), count, Count(info.quality), Flag(info.isLocked), Flag(info.isBound), Flag(info.hasNoValue),
		Icon(info.iconFileID), Text(info.itemName), Flag(info.isReadable), Flag(info.hasLoot)
end

local function QuestOf(bag, slot, class)
	local quest, start = class == QUEST_CLASS, false
	local info = Ask(Client("C_Container", "GetContainerItemQuestInfo"), bag, slot)
	if type(info) == "table" then
		local questID = Count(info.questID)
		if Flag(info.isQuestItem) or questID then
			quest = true
		end
		if questID and not Flag(info.isActive) then
			start = true
		end
	end
	return quest, start
end

local function InSet(bag, slot)
	return Flag(Ask(Client("C_Container", "GetContainerItemEquipmentSetInfo"), bag, slot))
end

local function GUID(bag, slot)
	local maker = _G.ItemLocation
	if IsSecret(maker) or type(maker) ~= "table" or type(maker.CreateFromBagAndSlot) ~= "function" then
		return nil
	end
	local ok, location = pcall(maker.CreateFromBagAndSlot, maker, bag, slot)
	if not ok or IsSecret(location) or type(location) ~= "table" then
		return nil
	end
	return Text(Ask(Client("C_Item", "GetItemGUID"), location))
end

local function DropLive(bag, slot)
	local byBag = live[bag]
	if byBag then
		byBag[slot] = nil
	end
end

local function Wait(rec)
	local list = waiting[rec.id]
	if not list then
		list = setmetatable({}, WEAK_KEYS)
		waiting[rec.id] = list
	end
	list[rec] = true
end

local function KeptName(rec)
	if rec.link == "item:" .. rec.id or Ask(Client("C_Item", "IsItemDataCachedByID"), rec.id) ~= true then
		return nil
	end
	local _, link = Ask2(Client("C_Item", "GetItemInfo"), rec.link)
	return LinkName(Text(link))
end

local function Fill(rec)
	if rec.name == nil then
		rec.name = KeptName(rec) or ItemName(rec.id)
	end
	if rec.quality == nil then
		rec.quality = QualityOf(rec.id)
	end
	if rec.icon == nil then
		rec.icon = IconOf(rec.id)
	end
	if rec.name == nil or rec.quality == nil then
		Wait(rec)
	end
end

local function TakeInfo(rec)
	local info = Data.Info(rec.id)
	if info then
		rec.class, rec.subclass, rec.equipLoc, rec.itype, rec.isubtype = info.class, info.subclass, info.equipLoc, info.itype, info.isubtype
		if rec.icon == nil then
			rec.icon = info.icon
		end
	end
end

local function LiveRecord(key, bag, slot)
	local id, link, count, quality, locked, bound, noValue, icon, name, readable, loot = ReadSlot(bag, slot)
	local byBag = live[bag]
	if not id then
		if byBag then
			byBag[slot] = nil
		end
		return nil
	end
	local rec = byBag and byBag[slot]
	if rec and rec.key == key and rec.id == id and rec.link == link and rec.count == count and rec.quality == quality and rec.bound == bound then
		rec.locked, rec.loot = locked, loot
		if rec.name == nil then
			rec.name = LinkName(link) or name or ItemName(id)
		end
		return rec
	end
	rec = { key = key, bag = bag, slot = slot, live = true, id = id, count = count, quality = quality, link = link, icon = icon,
		name = LinkName(link) or name or ItemName(id), bound = bound, noValue = noValue, locked = locked, readable = readable, loot = loot }
	TakeInfo(rec)
	local held = last[bag]
	local state = held and held[slot]
	if state and state.id == id and state.link == link then
		rec.quest, rec.questStart, rec.set = state.quest, state.start, state.set
	else
		rec.quest, rec.questStart = QuestOf(bag, slot, rec.class)
		rec.set = InSet(bag, slot)
	end
	rec.guid = GUID(bag, slot)
	if not byBag then
		byBag = {}
		live[bag] = byBag
	end
	byBag[slot] = rec
	return rec
end

local function StoredRecord(key, bag, slot)
	local record = Character(key)
	local slots = record and SlotsOf(record, bag)
	local text = slots and slots[slot]
	if type(text) ~= "string" then
		return nil
	end
	local byKey = decoded[key]
	if not byKey then
		byKey = {}
		decoded[key] = byKey
	end
	local byBag = byKey[bag]
	if not byBag then
		byBag = setmetatable({}, WEAK_VALUES)
		byKey[bag] = byBag
	end
	local rec = byBag[slot]
	if rec and textOf[rec] == text then
		if rec.name == nil or rec.quality == nil or rec.icon == nil then
			Fill(rec)
		end
		return rec
	end
	local id, count, quality, flags, item = Decode(text)
	if not id then
		return nil
	end
	rec = { key = key, bag = bag, slot = slot, live = false, id = id, count = count, quality = quality, link = "item:" .. (item or id),
		bound = Has(flags, "b"), quest = Has(flags, "q"), questStart = Has(flags, "s"), set = Has(flags, "e"), noValue = Has(flags, "n"),
		icon = IconOf(id) }
	TakeInfo(rec)
	if rec.class == QUEST_CLASS then
		rec.quest = true
	end
	Fill(rec)
	textOf[rec] = text
	byBag[slot] = rec
	return rec
end

local function Mark(changed, bag, slot)
	if changed then
		local set = changed[bag]
		if not set then
			set = {}
			changed[bag] = set
		end
		set[slot] = true
	end
end

local function Scan(bag, into, changed, guard)
	local size = Count(Ask(Client("C_Container", "GetContainerNumSlots"), bag))
	if not size or size > MAX_SLOTS or (size == 0 and guard) then
		return false
	end
	local held = last[bag]
	local fresh = held == nil
	if fresh then
		held = { n = 0 }
		last[bag] = held
	end
	local was = held.n
	local slots
	if into then
		slots = into[bag]
		if fresh or type(slots) ~= "table" then
			slots = {}
			into[bag] = slots
			fresh = true
		end
	end
	for slot = 1, size do
		local id, link, count, quality, locked, bound, noValue, _, _, _, loot = ReadSlot(bag, slot)
		local state = held[slot]
		if not id then
			if state then
				held[slot] = nil
				Mark(changed, bag, slot)
				DropLive(bag, slot)
			end
			if slots then
				slots[slot] = nil
			end
		else
			local moved = not state or state.id ~= id or state.link ~= link or state.count ~= count or state.quality ~= quality
				or state.locked ~= locked or state.loot ~= loot
			local differs = not state or state.id ~= id or state.link ~= link or state.count ~= count or state.quality ~= quality
				or state.bound ~= bound
			if differs then
				state = state or {}
				local info = Data.Info(id)
				state.id, state.link, state.count, state.quality, state.bound, state.noValue = id, link, count, quality, bound, noValue
				state.class = info and info.class
				state.quest, state.start = QuestOf(bag, slot, state.class)
				state.set = InSet(bag, slot)
				held[slot] = state
				DropLive(bag, slot)
			end
			state.locked, state.loot = locked, loot
			if moved then
				Mark(changed, bag, slot)
			end
			if slots and (differs or fresh or slots[slot] == nil) then
				slots[slot] = Encode(state)
			end
		end
	end
	for slot = size + 1, held.n do
		if held[slot] then
			held[slot] = nil
			DropLive(bag, slot)
		end
		if slots then
			slots[slot] = nil
		end
	end
	held.n = size
	if slots then
		slots.n = size
		local _, family = Ask2(Client("C_Container", "GetContainerNumFreeSlots"), bag)
		family = Count(family)
		slots.f = family ~= nil and family ~= 0 and family or nil
	end
	return size ~= was
end

local function DropContainer(bag, into)
	last[bag], live[bag], kinds[bag] = nil, nil, nil
	if into then
		into[bag] = nil
	end
end

local function ScanBags(record, changed, all)
	local into = record and record.bags
	for bag = BACKPACK, REAGENT do
		if all or dirty[bag] then
			Scan(bag, into, changed)
		end
	end
	if Keyring() then
		if all or dirty[KEYRING] then
			Scan(KEYRING, into, changed)
		end
	elseif last[KEYRING] or (into and into[KEYRING] ~= nil) then
		DropContainer(KEYRING, into)
	end
end

local function ReadTabs()
	for tab = FIRST_TAB, LAST_TAB do
		kinds[tab] = nil
	end
	local ids = Ask(Client("C_Bank", "FetchPurchasedBankTabIDs"), EnumValue("BankType", "Character", CHARACTER_BANK))
	if type(ids) ~= "table" then
		return false, false
	end
	local list, seen = {}, {}
	for _, value in ipairs(ids) do
		local tab = Whole(value)
		if tab and IsTab(tab) and not seen[tab] then
			seen[tab] = true
			list[#list + 1] = tab
		end
	end
	table.sort(list)
	liveTabs = list
	local parts = {}
	for index, tab in ipairs(list) do
		parts[index] = tab > FIRST_TAB and ("%d:%d"):format(tab, LiveBagItem(tab) or 0) or ("%d"):format(tab)
	end
	local sign = table.concat(parts, ",")
	local moved = sign ~= tabsSign
	tabsSign = sign
	return true, moved
end

local function WriteBank(record)
	local bought = {}
	for _, tab in ipairs(liveTabs) do
		bought[tab] = true
	end
	for tab in pairs(record.bank) do
		if not bought[tab] then
			record.bank[tab] = nil
		end
	end
	local items = {}
	for _, tab in ipairs(liveTabs) do
		if tab > FIRST_TAB then
			items[tab - TAB_OF_SLOT] = LiveBagItem(tab)
		end
	end
	record.bankItems = items
end

local function ScanBank(record, changed, all)
	local into = record and record.bank
	local resized = false
	for _, tab in ipairs(liveTabs) do
		if all or dirty[tab] then
			if Scan(tab, into, changed, tab == FIRST_TAB or LiveBagItem(tab) ~= nil) then
				resized = true
			end
		end
	end
	return resized
end

local function Answers(tab)
	local held = last[tab]
	local size = Count(Ask(Client("C_Container", "GetContainerNumSlots"), tab))
	if not held or not size or size == 0 or size ~= held.n then
		return false
	end
	local had = false
	for slot = 1, held.n do
		if held[slot] then
			had = true
			break
		end
	end
	if not had then
		return true
	end
	for slot = 1, size do
		if ReadSlot(tab, slot) then
			return true
		end
	end
	return false
end

local function GraceScan(record, changed)
	local into = record and record.bank
	for _, tab in ipairs(grace.tabs) do
		if dirty[tab] and Answers(tab) then
			Scan(tab, into, changed, true)
		end
	end
end

local function AtBanker()
	local ask = Client("C_PlayerInteractionManager", "IsInteractingWithNpcOfType")
	if not ask then
		return true
	end
	for _, banker in ipairs(BANKERS) do
		local ok, yes = pcall(ask, EnumValue("PlayerInteractionType", banker[1], banker[2]))
		if not ok or IsSecret(yes) or yes ~= false then
			return true
		end
	end
	return false
end

local function DropTabs()
	grace = nil
	for tab = FIRST_TAB, LAST_TAB do
		last[tab], live[tab], dirty[tab], kinds[tab] = nil, nil, nil, nil
	end
end

local function EndBank()
	bankLive, bankFull, tabsSign = false, false, nil
	DropTabs()
end

local function BankOpen()
	if bankLive and not AtBanker() then
		EndBank()
	end
	return bankLive
end

local function WriteBagItems(record)
	for bag = 1, REAGENT do
		record.bagItems[bag] = LiveBagItem(bag)
	end
end

local function WriteWorn(record)
	for slot = 1, LAST_WORN do
		local id = Count(Ask(Client(nil, "GetInventoryItemID"), "player", slot))
		record.worn[slot] = id ~= nil and id > 0 and id or nil
	end
end

local function Rewrite(record, bag, slot, state)
	local slots = record and SlotsOf(record, bag)
	if slots then
		slots[slot] = Encode(state)
	end
end

local function NameOf(key)
	return key:match("^(.-) %- ") or key
end

local function RealmOf(key)
	return key:match("^.- %- (.+)$")
end

local function MyRealm()
	if myRealm == nil then
		myRealm = Text(Ask(Client(nil, "GetNormalizedRealmName")))
	end
	return myRealm
end

local function Connected()
	if connected then
		return connected
	end
	local now = Clock()
	if realmsAt and now and now - realmsAt < REALMS_AGAIN then
		return EMPTY
	end
	realmsAt = now
	local realms = Ask(Client("C_AutoComplete", "GetAutoCompleteRealms"))
	local set, any = {}, false
	if type(realms) == "table" then
		for _, realm in ipairs(realms) do
			realm = Text(realm)
			if realm then
				set[realm] = true
				any = true
			end
		end
	end
	if any then
		connected = set
	end
	return set
end

local function Near(key, record)
	local realm = Text(record.realm)
	local mine = MyRealm()
	if realm and mine then
		return realm == mine or Connected()[realm] == true
	end
	local me = Me()
	local ours = me and RealmOf(me)
	return ours ~= nil and RealmOf(key) == ours
end

local function DropIndex()
	index, who, builtWithout, building = nil, nil, nil, nil
	generation = generation + 1
end

local function AddCount(target, id, key, where, count)
	local byKey = target[id]
	if not byKey then
		byKey = {}
		target[id] = byKey
	end
	local counts = byKey[key]
	if not counts then
		counts = { bags = 0, bank = 0, worn = 0 }
		byKey[key] = counts
	end
	counts[where] = counts[where] + count
end

local function IndexStep(job)
	if building ~= job or job.generation ~= generation then
		return
	end
	local budget = INDEX_STEP
	while budget > 0 do
		local unit = job.queue[job.at]
		if not unit then
			index, who, builtWithout, building = job.index, job.who, job.without, nil
			job.failed = false
			return
		end
		job.at = job.at + 1
		for slot, value in pairs(unit.list) do
			if type(slot) == "number" then
				if unit.where == "worn" then
					local id = Count(value)
					if id and id > 0 then
						AddCount(job.index, id, unit.key, "worn", 1)
					end
				else
					local id, count = Decode(value)
					if id then
						AddCount(job.index, id, unit.key, unit.where, count)
					end
				end
				budget = budget - 1
			end
		end
	end
	job.failed = false
	After(0, function()
		if building ~= job or job.generation ~= generation then
			return
		end
		job.failed = true
		TipsPart(IndexStep, job)
		if job.failed and building == job then
			building = nil
		end
	end)
end

local function StartIndex()
	local job = { index = {}, who = {}, queue = {}, at = 1, generation = generation }
	local store = Store(false)
	local me = Me()
	for key, record in pairs(store and store.chars or EMPTY) do
		if type(key) == "string" and type(record) == "table" and key ~= me and Near(key, record) then
			job.who[key] = { class = Text(record.class), name = NameOf(key), realm = RealmOf(key) }
			for _, where in ipairs(WINDOWS) do
				local section = record[where]
				if type(section) == "table" then
					for _, slots in pairs(section) do
						if type(slots) == "table" then
							job.queue[#job.queue + 1] = { key = key, where = where, list = slots }
						end
					end
				end
			end
			if type(record.worn) == "table" then
				job.queue[#job.queue + 1] = { key = key, where = "worn", list = record.worn }
			end
		end
	end
	job.without = connected == nil
	building = job
	job.failed = true
	TipsPart(IndexStep, job)
	if job.failed and building == job then
		building = nil
	end
end

local function Entry(key, record, me)
	record = record or EMPTY
	local entry = { key = key, name = NameOf(key), realm = RealmOf(key) or Text(record.realm), class = Text(record.class),
		faction = Text(record.faction), level = Count(record.level), money = Count(record.money), seen = Count(record.seen),
		bankSeen = Count(record.bankSeen), me = key == me }
	if entry.me then
		entry.class = Text(Ask(Client(nil, "UnitClassBase"), "player")) or entry.class
		entry.faction = Text(Ask(Client(nil, "UnitFactionGroup"), "player")) or entry.faction
		local level = Count(Ask(Client(nil, "UnitLevel"), "player"))
		if level and level > 0 then
			entry.level = level
		end
		entry.money = Count(Ask(Client(nil, "GetMoney"))) or entry.money
		entry.seen = Now() or entry.seen
		entry.near = true
	else
		entry.near = Near(key, record)
	end
	return entry
end

function Data.Characters()
	local me = Me()
	local list, listed = {}, false
	local store = Store(false)
	for key, record in pairs(store and store.chars or EMPTY) do
		if type(key) == "string" and type(record) == "table" then
			local entry = Entry(key, record, me)
			list[#list + 1] = entry
			listed = listed or entry.me
		end
	end
	if me and not listed then
		list[#list + 1] = Entry(me, nil, me)
	end
	local ours = me and RealmOf(me)
	local function Rank(entry)
		if ours and entry.realm == ours then
			return 0
		end
		return entry.near and 1 or 2
	end
	table.sort(list, function(a, b)
		local rankA, rankB = Rank(a), Rank(b)
		if rankA ~= rankB then
			return rankA < rankB
		end
		local realmA, realmB = (a.realm or ""):lower(), (b.realm or ""):lower()
		if realmA ~= realmB then
			return realmA < realmB
		end
		if a.me ~= b.me then
			return a.me
		end
		return a.key < b.key
	end)
	return list
end

function Data.Containers(which, key)
	local me = Me()
	local mine = key == nil or key == me
	local list = {}
	if which == "bank" then
		if mine and BankOpen() then
			for _, tab in ipairs(liveTabs) do
				list[#list + 1] = tab
			end
			return list
		end
		local record = Character(key or me)
		local bank = record and record.bank
		if type(bank) == "table" then
			for tab = FIRST_TAB, LAST_TAB do
				if type(bank[tab]) == "table" then
					list[#list + 1] = tab
				end
			end
		end
		return list
	end
	for bag = BACKPACK, REAGENT do
		list[#list + 1] = bag
	end
	if mine then
		if Keyring() then
			list[#list + 1] = KEYRING
		end
	else
		local record = Character(key)
		if record and type(record.bags) == "table" and type(record.bags[KEYRING]) == "table" then
			list[#list + 1] = KEYRING
		end
	end
	return list
end

function Data.Size(key, bag)
	bag = Container(bag)
	if bag == nil then
		return 0, nil
	end
	local me = Me()
	if (key == nil or key == me) and (Held(bag) or bankLive) then
		local size = Count(Ask(Client("C_Container", "GetContainerNumSlots"), bag))
		if not size or size > MAX_SLOTS then
			size = 0
		end
		return size, LiveKind(bag)
	end
	local record = Character(key or me)
	local slots = record and SlotsOf(record, bag)
	return SizeOf(slots), StoredKind(record, bag, slots)
end

function Data.Item(key, bag, slot)
	bag, slot = Container(bag), Slot(slot)
	if bag == nil or slot == nil then
		return nil
	end
	local me = Me()
	if key == nil or key == me then
		if Held(bag) or bankLive then
			return LiveRecord(me, bag, slot)
		end
		key = me
	end
	if type(key) ~= "string" then
		return nil
	end
	return StoredRecord(key, bag, slot)
end

local function LiveFree(bag, size)
	local free = Count((Ask2(Client("C_Container", "GetContainerNumFreeSlots"), bag)))
	if not free or free == 0 then
		return 0, nil
	end
	if free > size then
		free = size
	end
	local itemOf = Client("C_Container", "GetContainerItemID")
	if itemOf then
		for slot = 1, size do
			local ok, id = pcall(itemOf, bag, slot)
			if ok and not IsSecret(id) and id == nil then
				return free, slot
			end
		end
	end
	return free, nil
end

local function StoredFree(slots, size)
	local free, first = 0, nil
	for slot = 1, size do
		if type(slots[slot]) ~= "string" then
			free = free + 1
			first = first or slot
		end
	end
	return free, first
end

function Data.Free(key, which)
	local me = Me()
	if key == me then
		key = nil
	end
	local rows, groups = {}, {}
	for _, bag in ipairs(Data.Containers(which, key)) do
		local size, kind = 0, nil
		if bag ~= KEYRING then
			size, kind = Data.Size(key, bag)
		end
		if size > 0 and kind then
			local free, first = 0, nil
			if key == nil and (Held(bag) or bankLive) then
				free, first = LiveFree(bag, size)
			else
				local record = Character(key or me)
				local slots = record and SlotsOf(record, bag)
				if slots then
					free, first = StoredFree(slots, size)
				end
			end
			local group = groups[kind.key]
			if not group then
				if kind.key == "bag" then
					local label = which == "bank" and Word("BANK", "Bank") or BAGS_WORD
					group = { kind = { key = "bag", family = 0, label = label }, label = label, free = 0, total = 0, general = true }
				else
					group = { kind = kind, label = kind.label, free = 0, total = 0 }
				end
				groups[kind.key] = group
				rows[#rows + 1] = group
			end
			group.total = group.total + size
			group.free = group.free + free
			if first and not group.bag then
				group.bag, group.slot = bag, first
			end
		end
	end
	local general = groups.bag
	if general and rows[1] ~= general then
		for index, row in ipairs(rows) do
			if row == general then
				table.remove(rows, index)
				break
			end
		end
		table.insert(rows, 1, general)
	end
	return rows
end

function Data.Money(key)
	local me = Me()
	if key == nil or key == me then
		local money = Count(Ask(Client(nil, "GetMoney")))
		if money then
			return money
		end
		key = me
	end
	local record = Character(key)
	return record and Count(record.money) or nil
end

function Data.Currencies(key)
	if key == nil then
		key = Me()
	end
	local record = Character(key)
	local kept = record and record.currencies
	if type(kept) ~= "table" then
		return nil
	end
	local list = {}
	for _, entry in ipairs(kept) do
		if type(entry) == "table" then
			local id, icon, count = Count(entry[1]), Icon(entry[2]), Count(entry[3])
			if id and id > 0 and icon and count then
				list[#list + 1] = { id, icon, count }
			end
		end
	end
	return list
end

function Data.KeepCurrencies(list)
	if IsSecret(list) or type(list) ~= "table" then
		return false
	end
	local fresh = {}
	for _, entry in ipairs(list) do
		if not IsSecret(entry) and type(entry) == "table" then
			local id, icon, count = Count(entry[1]), Icon(entry[2]), Count(entry[3])
			if id and id > 0 and icon and count then
				fresh[#fresh + 1] = { id, icon, count }
			end
		end
	end
	local record = Mine(false)
	local kept = record and record.currencies
	if type(kept) == "table" and #kept == #fresh then
		local same = true
		for index, entry in ipairs(fresh) do
			local old = kept[index]
			if type(old) ~= "table" or old[1] ~= entry[1] or old[2] ~= entry[2] or old[3] ~= entry[3] then
				same = false
				break
			end
		end
		if same then
			return false
		end
	end
	record = Mine(true)
	if not record then
		return false
	end
	record.currencies = fresh
	return true
end

local function SessionStart(initial)
	local char = ns.Character()
	local money = Count(Ask(Client(nil, "GetMoney")))
	if type(char) ~= "table" or not money then
		return
	end
	if (not IsSecret(initial) and initial == true) or not Count(char.sessionMoney) then
		char.sessionMoney = money
		char.sessionStartAt = Count(Ask(Client(nil, "time")))
	end
end

function ns.SessionMoney()
	local char = ns.Character()
	local start = type(char) == "table" and Count(char.sessionMoney) or nil
	local money = Count(Ask(Client(nil, "GetMoney")))
	if not (start and money) then
		return nil
	end
	local began, now = Count(char.sessionStartAt), Count(Ask(Client(nil, "time")))
	return money - start, began and now and now >= began and (now - began) or nil
end
Data.SessionMoney = ns.SessionMoney

function ns.SessionRestart()
	local char = ns.Character()
	local money, now = Count(Ask(Client(nil, "GetMoney"))), Count(Ask(Client(nil, "time")))
	if type(char) ~= "table" or not (money and now) then
		return false
	end
	char.sessionMoney, char.sessionStartAt = money, now
	print("Flat UI: the gold count of this session starts again now.")
	local panels = ns.DataPanels
	if type(panels) == "table" and type(panels.Mark) == "function" then
		pcall(panels.Mark, "gold")
	end
	return true
end

do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and type(frame) == "table" then
		ns.Own[frame] = true
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		frame:SetScript("OnEvent", function(_, _, initial)
			local done, err = pcall(SessionStart, initial)
			if not done then
				geterrorhandler()(err)
			end
		end)
	end
end

function Data.Want(id)
	id = Count(id)
	if not id or id == 0 or asked[id] then
		return
	end
	asked[id] = true
	if ItemName(id) then
		return
	end
	pending[id] = true
	Ask(Client("C_Item", "RequestLoadItemDataByID"), id)
end

function Data.Counts(id)
	id = Count(id)
	if not id or id == 0 or Stopped() then
		return {}
	end
	if index and builtWithout then
		Connected()
		if connected then
			DropIndex()
		end
	end
	if not index and not building then
		StartIndex()
	end
	local rows = {}
	local byKey = index and index[id]
	if not byKey then
		return rows
	end
	for key, counts in pairs(byKey) do
		local person = who[key] or EMPTY
		rows[#rows + 1] = { key = key, class = person.class, name = person.name, realm = person.realm, bags = counts.bags, bank = counts.bank,
			worn = counts.worn }
	end
	table.sort(rows, function(a, b)
		local totalA, totalB = a.bags + a.bank + a.worn, b.bags + b.bank + b.worn
		if totalA ~= totalB then
			return totalA > totalB
		end
		return a.key < b.key
	end)
	return rows
end

function Data.Mine(id)
	id = Count(id)
	if not id or id == 0 or Stopped() then
		return 0, 0, 0
	end
	local record = Mine(false)
	if type(record) ~= "table" then
		return 0, 0, 0
	end
	local found = { bags = 0, bank = 0 }
	for _, where in ipairs(WINDOWS) do
		local section = record[where]
		if type(section) == "table" then
			for _, slots in pairs(section) do
				if type(slots) == "table" then
					for slot, value in pairs(slots) do
						if type(slot) == "number" and type(value) == "string" and tonumber(value:match("^(%d+)")) == id then
							local got, count = Decode(value)
							if got == id then
								found[where] = found[where] + count
							end
						end
					end
				end
			end
		end
	end
	local worn = 0
	if type(record.worn) == "table" then
		for slot, value in pairs(record.worn) do
			if type(slot) == "number" and Count(value) == id then
				worn = worn + 1
			end
		end
	end
	return found.bags, found.bank, worn
end

function Data.BankScan()
	EndBank()
	bankLive = true
	local answered = ReadTabs()
	bankFull = true
	Part(function()
		local record = Mine(true)
		if record and answered then
			WriteBank(record)
		end
		ScanBank(record, nil, true)
		if record then
			record.bankSeen = Now() or record.bankSeen
		end
	end)
end

function Data.BankClosed(late)
	if not bankLive then
		return
	end
	if late then
		EndBank()
		return
	end
	bankLive, bankFull, tabsSign = false, false, nil
	for tab = FIRST_TAB, LAST_TAB do
		live[tab], kinds[tab] = nil, nil
	end
	local token = { tabs = liveTabs }
	grace = token
	After(GRACE, function()
		if grace == token then
			DropTabs()
		end
	end)
	Part(function()
		local record = Mine(true)
		if record then
			record.bankSeen = Now() or record.bankSeen
		end
	end)
end

function Data.BankTabs()
	if not BankOpen() then
		return false
	end
	local answered, moved = ReadTabs()
	bankFull = true
	if answered then
		Part(function()
			local record = Mine(true)
			if record then
				WriteBank(record)
				record.bankSeen = Now() or record.bankSeen
			end
		end)
	end
	return moved == true
end

function Data.Forget(key)
	if key == nil then
		key = Me()
	end
	if IsSecret(key) or type(key) ~= "string" then
		return false
	end
	local store = Store(false)
	local had = store ~= nil and store.chars[key] ~= nil
	if store then
		store.chars[key] = nil
	end
	decoded[key] = nil
	if key == Me() then
		muted = true
	end
	DropIndex()
	local tips = B.Tips
	if type(tips) == "table" and type(tips.Forget) == "function" then
		tips.Forget()
	end
	if type(B.Viewing) == "function" and type(B.SetViewing) == "function" then
		for _, which in ipairs(WINDOWS) do
			if B.Viewing(which) == key then
				B.SetViewing(which, nil)
			end
		end
	end
	if Active() then
		Request("layout")
	end
	return had
end

local function NewSeen(changed)
	local categories = B.Categories
	local new = type(categories) == "table" and categories.New
	if type(new) == "table" and type(new.Seen) == "function" then
		new.Seen(changed)
	end
end

local function Prepare()
	local buttons = B.Buttons
	if type(buttons) == "table" and type(buttons.Prepare) == "function" then
		buttons.Prepare(Data.Containers("bags"))
	end
end

local RemarkAll

local function Delayed()
	local record = Mine(true)
	local now = Clock()
	local all = full or (now ~= nil and (sweptAt == nil or now - sweptAt >= SWEEP))
	full = false
	if all then
		sweptAt = now
	end
	local bags, bank = {}, {}
	local tabsMoved = false
	ScanBags(record, bags, all)
	if BankOpen() then
		if dirty[BANK_BAGS] then
			local answered, moved = ReadTabs()
			if answered and record then
				WriteBank(record)
			end
			tabsMoved = moved == true
			bankFull = true
		end
		local tabs = bankFull
		bankFull = false
		if ScanBank(record, bank, tabs) then
			tabsMoved = true
		end
		if record and next(bank) ~= nil then
			record.bankSeen = Now() or record.bankSeen
		end
	elseif grace then
		GraceScan(record, bank)
		if record and next(bank) ~= nil then
			record.bankSeen = Now() or record.bankSeen
		end
	end
	for container in pairs(dirty) do
		dirty[container] = nil
	end
	if record and next(bags) ~= nil then
		record.seen = Now() or record.seen
	end
	if remarkAll and all then
		remarkAll = false
		RemarkAll()
	end
	if not Active() then
		return
	end
	if next(bags) ~= nil then
		Part(NewSeen, bags)
		local scanned = type(B.Pins) == "table" and B.Pins.Scanned or nil
		if type(scanned) == "function" then
			scanned(bags)
		end
		Part(Request, "items", "bags", bags)
		Part(Request, "footer", "bags")
	end
	if next(bank) ~= nil then
		Part(Request, "items", "bank", bank)
		Part(Request, "footer", "bank")
	end
	if tabsMoved then
		Part(Request, "layout", "bank")
	end
end

local function FlagFull()
	full = true
	if fullTimer then
		return
	end
	fullTimer = true
	After(FULL_WAIT, function()
		fullTimer = false
		if full and Running() then
			Part(Delayed)
		end
	end)
end

local function Started()
	keyring = ShowsKeyring()
	for bag in pairs(kinds) do
		kinds[bag] = nil
	end
	local record = Mine(true)
	if record then
		Identity(record)
		WriteWorn(record)
		WriteBagItems(record)
	end
	if bankLive then
		bankFull = true
	end
	FlagFull()
end

local function BagUpdate(bag)
	bag = Whole(bag)
	if bag ~= nil then
		dirty[bag] = true
	end
end

local function ContainerUpdate()
	keyring = ShowsKeyring()
	for bag in pairs(kinds) do
		kinds[bag] = nil
	end
	local record = Mine(true)
	if record then
		WriteBagItems(record)
	end
	local bank = BankOpen()
	if bank then
		if ReadTabs() and record then
			WriteBank(record)
		end
		bankFull = true
	end
	FlagFull()
	if not Active() then
		return
	end
	Part(Prepare)
	Part(Request, "layout", "bags")
	if bank then
		Part(Request, "layout", "bank")
	end
end

local newQueued = false

local function NewFlags()
	local sorting = B.Sorting
	if not Active() or (type(sorting) == "function" and sorting("bags") == true) then
		return
	end
	local isNew, sizeOf = Client("C_NewItems", "IsNewItem"), Client("C_Container", "GetContainerNumSlots")
	if not (isNew and sizeOf) then
		return
	end
	local flagged = {}
	for _, bag in ipairs(Data.Containers("bags")) do
		local size = Count(Ask(sizeOf, bag))
		if size and size <= MAX_SLOTS then
			for slot = 1, size do
				if Ask(isNew, bag, slot) == true then
					Mark(flagged, bag, slot)
				end
			end
		end
	end
	if next(flagged) ~= nil then
		Part(NewSeen, flagged)
		Part(Request, "items", "bags", flagged)
	end
end

local function NewItemsUpdated()
	if newQueued then
		return
	end
	newQueued = true
	After(0, function()
		newQueued = false
		if Running() then
			Part(NewFlags)
		end
	end)
end

local function Remark(read)
	local record = Mine(true)
	local bags, bank = false, false
	for bag, held in pairs(last) do
		local tab = IsTab(bag)
		if not tab or bankLive then
			for slot = 1, held.n do
				local state = held[slot]
				if state and read(bag, slot, state) then
					Rewrite(record, bag, slot, state)
					DropLive(bag, slot)
					if tab then
						bank = true
					else
						bags = true
					end
				end
			end
		end
	end
	if not Active() then
		return
	end
	if bags then
		Part(Request, "items", "bags")
	end
	if bank then
		Part(Request, "items", "bank")
	end
end

local function QuestMarks(bag, slot, state)
	local quest, start = QuestOf(bag, slot, state.class)
	if quest == state.quest and start == state.start then
		return false
	end
	state.quest, state.start = quest, start
	return true
end

local function SetMarks(bag, slot, state)
	local set = InSet(bag, slot)
	if set == state.set then
		return false
	end
	state.set = set
	return true
end

local function QuestNow()
	questAt = Clock()
	Remark(QuestMarks)
end

local function QuestSoon()
	if questQueued then
		return
	end
	local now = Clock()
	local wait = (questAt and now) and (questAt + QUEST_EVERY - now) or 0
	if wait <= 0 then
		QuestNow()
		return
	end
	questQueued = true
	After(wait, function()
		questQueued = false
		if Running() then
			Part(QuestNow)
		end
	end)
end

local function SetsChanged()
	Remark(SetMarks)
end

RemarkAll = function()
	questAt = Clock()
	Remark(QuestMarks)
	Remark(SetMarks)
end

local function Loaded(id, success)
	id = Count(id)
	if not id then
		return
	end
	local wanted = pending[id]
	pending[id] = nil
	local list = waiting[id]
	if list then
		waiting[id] = nil
		for rec in pairs(list) do
			Fill(rec)
		end
	end
	local failed = not IsSecret(success) and success == false
	if wanted and not failed and Active() then
		Part(Request, "items")
		Part(Request, "search")
	end
end

local function MoneyChanged()
	local record = Mine(true)
	local money = record and Count(Ask(Client(nil, "GetMoney")))
	if money then
		record.money = money
		record.seen = Now() or record.seen
	end
	if Active() then
		Part(Request, "footer", "bags")
	end
end

local function LoggingOut()
	local record = Mine(true)
	if record then
		Identity(record)
		WriteWorn(record)
		WriteBagItems(record)
	end
	if Active() then
		Part(Request, "footer", "bags")
	end
end

local function LevelUp(level)
	local record = Mine(true)
	if not record then
		return
	end
	level = Count(level) or Count(Ask(Client(nil, "UnitLevel"), "player"))
	if level and level > 0 then
		record.level = level
	end
end

local function EquipmentChanged(slot)
	slot = Whole(slot)
	if slot == nil or slot < 1 or slot > LAST_WORN then
		return
	end
	local record = Mine(true)
	if record then
		local id = Count(Ask(Client(nil, "GetInventoryItemID"), "player", slot))
		record.worn[slot] = id ~= nil and id > 0 and id or nil
	end
end

local function Noon(stamp)
	local parts = Ask(Client(nil, "date"), "*t", stamp)
	if type(parts) ~= "table" then
		return nil
	end
	return Count(Ask(Client(nil, "time"), { year = parts.year, month = parts.month, day = parts.day, hour = 12 }))
end

local function Age(stamp)
	local now = Now()
	if not stamp or not now then
		return nil
	end
	local today, day = Noon(now), Noon(stamp)
	if not (today and day) then
		return nil
	end
	local days = math.floor((today - day) / DAY + 0.5)
	if days <= 0 then
		return "today"
	elseif days == 1 then
		return "yesterday"
	end
	return ("%d days ago"):format(days)
end

local function Thousands(number)
	local grouped = ("%d"):format(number):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function Kept()
	local list = {}
	local store = Store(false)
	for key, record in pairs(store and store.chars or EMPTY) do
		if type(key) == "string" and type(record) == "table" then
			list[#list + 1] = { key = key, record = record }
		end
	end
	table.sort(list, function(a, b)
		return a.key < b.key
	end)
	return list
end

local function Describe(key, record)
	local text = key
	local level = Count(record.level)
	if level and level > 0 then
		text = ("%s, level %d"):format(text, level)
	end
	local age = Age(Count(record.seen))
	if age then
		text = ("%s, seen %s"):format(text, age)
	end
	return text
end

function ns.BagsCharacterLines()
	local rows = {}
	for position, entry in ipairs(Kept()) do
		rows[#rows + 1] = { position, Describe(entry.key, entry.record) }
	end
	return rows
end

function ns.BagsCharacterForget(position)
	local entry = type(position) == "number" and Kept()[position]
	if not entry then
		return false
	end
	local me = entry.key == Me()
	Data.Forget(entry.key)
	if me then
		return true, ("Flat UI: the bags, bank and gold of %s are forgotten. Bags keeps them again when this character next logs in."):format(entry.key)
	end
	return true, ("Flat UI: the bags, bank and gold of %s are forgotten."):format(entry.key)
end

local function Tally()
	local characters, items = 0, 0
	local store = Store(false)
	for key, record in pairs(store and store.chars or EMPTY) do
		if type(key) == "string" and type(record) == "table" then
			characters = characters + 1
			for _, where in ipairs(WINDOWS) do
				local section = record[where]
				if type(section) == "table" then
					for _, slots in pairs(section) do
						if type(slots) == "table" then
							for slot, text in pairs(slots) do
								if type(slot) == "number" and type(text) == "string" then
									items = items + 1
								end
							end
						end
					end
				end
			end
		end
	end
	return characters, items
end

local function Listen(event, fn, filter)
	ns.AddEvent(KEY, event, function(...)
		Part(fn, ...)
	end, filter)
end

Listen("PLAYER_ENTERING_WORLD", Started)
Listen("BAG_UPDATE", BagUpdate)
Listen("BAG_UPDATE_DELAYED", Delayed)
Listen("BAG_CONTAINER_UPDATE", ContainerUpdate)
Listen("BAG_NEW_ITEMS_UPDATED", NewItemsUpdated)
Listen("QUEST_ACCEPTED", QuestSoon)
Listen("UNIT_QUEST_LOG_CHANGED", QuestSoon, function(unit)
	return not IsSecret(unit) and unit == "player"
end)
Listen("EQUIPMENT_SETS_CHANGED", SetsChanged)
Listen("GET_ITEM_INFO_RECEIVED", Loaded)
Listen("ITEM_DATA_LOAD_RESULT", Loaded)
Listen("PLAYER_MONEY", MoneyChanged)
Listen("PLAYER_LOGOUT", LoggingOut)
Listen("PLAYER_LEVEL_UP", LevelUp)
Listen("PLAYER_EQUIPMENT_CHANGED", EquipmentChanged)

ns.AddStart(KEY, function()
	Part(Started)
end)

function Data.Resume()
	remarkAll = true
	Part(Started)
end

ns.AddStatus(KEY, function()
	if not Running() or Stopped() then
		return {}
	end
	local lines = {}
	local characters, items = Tally()
	if characters > 0 then
		local line = ("Bags: %d %s kept, %s %s"):format(characters, characters == 1 and "character" or "characters", Thousands(items),
			items == 1 and "item" or "items")
		local mine = Mine(false)
		local age = mine and Age(Count(mine.bankSeen))
		if age then
			line = ("%s; your bank as of %s"):format(line, age)
		end
		lines[#lines + 1] = line .. "."
	end
	if characters > MANY then
		lines[#lines + 1] = ("Bags: more than %d characters are kept. Forget a character on the Bags page takes one out."):format(MANY)
	end
	return lines
end)
