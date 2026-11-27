local _, ns = ...

local KEY = "bags"
local B = ns.Bags
local Categories = B.Categories
local New = B.Categories.New
local Errands = ns.Errands
local Custom = B.Custom

local CONSUMABLE, CONTAINER, WEAPON, GEM, ARMOR, REAGENT, PROJECTILE, TRADEGOODS = 0, 1, 2, 3, 4, 5, 6, 7
local ITEM_ENHANCEMENT, RECIPE, QUIVER, QUESTITEM, KEYS, MISCELLANEOUS, PROFESSION = 8, 9, 11, 12, 13, 15, 19
local MISC_REAGENT = 1
local KEYRING = -1
local BAGS = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [KEYRING] = true }
local MOST_PLACED = 2000
local LAST, KEYRING_PLACE, NO_BAG = 1000, 100, 200

local SECTIONS = {
	{ key = "new", label = "New items" },
	{ key = "keep", label = "Keep in place" },
	{ key = "set", label = "Equipment sets" },
	{ key = "gear", label = "Equipment" },
	{ key = "weapon", label = "Weapons" },
	{ key = "shield", label = "Shields and off-hands" },
	{ key = "armour", label = "Armour" },
	{ key = "jewel", label = "Jewellery" },
	{ key = "ring", label = "Rings" },
	{ key = "neck", label = "Necklaces" },
	{ key = "trinket", label = "Trinkets" },
	{ key = "relic", label = "Relics" },
	{ key = "shirt", label = "Shirts and tabards" },
	{ key = "consumable", label = "Consumables" },
	{ key = "food", label = "Food and drink" },
	{ key = "potion", label = "Potions and elixirs", each = "Potions" },
	{ key = "elixir", label = "Elixirs and flasks" },
	{ key = "scroll", label = "Scrolls" },
	{ key = "bandage", label = "Bandages" },
	{ key = "enhance", label = "Enhancements" },
	{ key = "explosive", label = "Explosives and devices" },
	{ key = "quest", label = "Quest items" },
	{ key = "trade", label = "Trade goods" },
	{ key = "cloth", label = "Cloth" },
	{ key = "leather", label = "Leather" },
	{ key = "metal", label = "Metal and stone" },
	{ key = "herb", label = "Herbs" },
	{ key = "elemental", label = "Elemental" },
	{ key = "enchanting", label = "Enchanting" },
	{ key = "meat", label = "Meat" },
	{ key = "parts", label = "Parts" },
	{ key = "reagent", label = "Reagents" },
	{ key = "recipe", label = "Recipes" },
	{ key = "ammo", label = "Ammunition" },
	{ key = "bag", label = "Bags and quivers" },
	{ key = "key", label = "Keys" },
	{ key = "other", label = "Other" },
	{ key = "junk", label = "Junk" },
	{ key = "free", label = "Free slots" },
}
local PRIORITY = { "set", "quest", "gear", "consumable", "trade", "reagent", "recipe", "ammo", "bag", "key" }
local UNHIDEABLE = { new = true, free = true, other = true }
local GROUPS = {
	{ row = "gear", base = "gear", each = { "weapon", "shield", "armour", "ring", "neck", "trinket", "relic", "shirt" },
		kind = { gear = "armour", weapon = "weapon", shield = "weapon", relic = "weapon", armour = "armour", shirt = "armour", jewel = "jewel",
			ring = "jewel", neck = "jewel", trinket = "jewel" },
		slots = { INVTYPE_WEAPON = "weapon", INVTYPE_2HWEAPON = "weapon", INVTYPE_WEAPONMAINHAND = "weapon", INVTYPE_WEAPONOFFHAND = "weapon",
			INVTYPE_RANGED = "weapon", INVTYPE_RANGEDRIGHT = "weapon", INVTYPE_THROWN = "weapon", INVTYPE_SHIELD = "shield",
			INVTYPE_HOLDABLE = "shield", INVTYPE_HEAD = "armour", INVTYPE_SHOULDER = "armour", INVTYPE_CHEST = "armour", INVTYPE_ROBE = "armour",
			INVTYPE_WAIST = "armour", INVTYPE_LEGS = "armour", INVTYPE_FEET = "armour", INVTYPE_WRIST = "armour", INVTYPE_HAND = "armour",
			INVTYPE_CLOAK = "armour", INVTYPE_FINGER = "ring", INVTYPE_NECK = "neck", INVTYPE_TRINKET = "trinket", INVTYPE_RELIC = "relic",
			INVTYPE_BODY = "shirt", INVTYPE_TABARD = "shirt" },
		subs = { [WEAPON] = { any = "weapon" } } },
	{ row = "consumables", base = "consumable", each = { "food", "potion", "elixir", "scroll", "bandage", "enhance", "explosive" },
		kind = { consumable = "consumable", food = "food", potion = "potion", elixir = "potion", scroll = "consumable", bandage = "consumable",
			enhance = "consumable", explosive = "consumable" },
		subs = { [CONSUMABLE] = { [1] = "potion", [2] = "elixir", [3] = "elixir", [4] = "scroll", [5] = "food", [6] = "enhance", [7] = "bandage",
			[14] = "explosive", [15] = "enhance" }, [TRADEGOODS] = { [2] = "explosive", [3] = "explosive" } },
		claims = "explosive" },
	{ row = "tradeGoods", base = "trade", each = { "cloth", "leather", "metal", "herb", "elemental", "enchanting", "meat", "parts" },
		subs = { [TRADEGOODS] = { [1] = "parts", [2] = "parts", [3] = "parts", [5] = "cloth", [6] = "leather", [7] = "metal", [8] = "meat",
			[9] = "herb", [10] = "elemental", [12] = "enchanting" } } },
}
local GROUP_OF = {}
for _, group in ipairs(GROUPS) do
	local each = { [group.base] = group.base }
	for _, key in ipairs(group.each) do
		each[key] = key
	end
	group.to = { each = each, kind = group.kind }
	for key in pairs(each) do
		GROUP_OF[key] = group
	end
	for key in pairs(group.kind or {}) do
		GROUP_OF[key] = group
	end
end
local SLOT_ORDER = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_BODY = 6,
	INVTYPE_TABARD = 7, INVTYPE_WRIST = 8, INVTYPE_HAND = 9, INVTYPE_WAIST = 10, INVTYPE_LEGS = 11, INVTYPE_FEET = 12, INVTYPE_FINGER = 13,
	INVTYPE_TRINKET = 14, INVTYPE_WEAPON = 15, INVTYPE_2HWEAPON = 15, INVTYPE_WEAPONMAINHAND = 15, INVTYPE_WEAPONOFFHAND = 16,
	INVTYPE_SHIELD = 16, INVTYPE_HOLDABLE = 16, INVTYPE_RANGED = 17, INVTYPE_RANGEDRIGHT = 17, INVTYPE_THROWN = 17, INVTYPE_RELIC = 17,
}
local SLOT_LAST = 18

local LABELS, EACH_LABELS, PLACEABLE, HIDEABLE = {}, {}, {}, {}
for _, section in ipairs(SECTIONS) do
	LABELS[section.key] = section.label
	EACH_LABELS[section.key] = section.each
	HIDEABLE[section.key] = not UNHIDEABLE[section.key] or nil
	if section.key ~= "new" and section.key ~= "junk" and section.key ~= "free" and section.key ~= "keep" then
		PLACEABLE[section.key] = true
	end
end

local function Placeable(key)
	if PLACEABLE[key] then
		return true
	end
	local is = Custom.Is
	return type(key) == "string" and type(is) == "function" and is(key) == true
end

function Categories.Placeable(key)
	return Placeable(key) == true
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Text(value)
	if value ~= nil and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function Whole(value)
	if ns.Finite(value) and value == math.floor(value) then
		return value
	end
	return nil
end

local function Empty(list)
	for key in pairs(list) do
		list[key] = nil
	end
end

local function Say(text)
	print("Flat UI: " .. text)
end

local function Request(flag)
	local request = B.Request
	if type(request) == "function" then
		request(flag)
	end
end

local instant = {}

local function Instant(id)
	id = Whole(id)
	if not id then
		return nil
	end
	local info = B.Data.Info
	info = type(info) == "function" and info(id) or nil
	if type(info) == "table" and ns.Finite(info.class) then
		return info
	end
	local known = instant[id]
	if known == nil then
		known = false
		if type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function" then
			local ok, _, itype, isubtype, equipLoc, _, class, subclass = pcall(C_Item.GetItemInfoInstant, id)
			if ok and ns.Finite(class) then
				known = { class = class, subclass = ns.Finite(subclass) and subclass or nil, equipLoc = Text(equipLoc), itype = Text(itype),
					isubtype = Text(isubtype) }
			end
		end
		instant[id] = known
	end
	return known or nil
end

local function Kind(record)
	local class, subclass, slot, itype, isubtype = record.class, record.subclass, record.equipLoc, record.itype, record.isubtype
	if not ns.Finite(class) or Text(itype) == nil then
		local info = Instant(record.id)
		if info then
			if not ns.Finite(class) then
				class, subclass, slot = info.class, info.subclass, info.equipLoc
			end
			if Text(itype) == nil then
				itype, isubtype = info.itype, info.isubtype
			end
		end
	end
	if not ns.Finite(class) then
		return nil, nil, nil, Text(itype), Text(isubtype)
	end
	return class, ns.Finite(subclass) and subclass or nil, Text(slot), Text(itype), Text(isubtype)
end
Categories.Kind = Kind

local function Class(record)
	return (Kind(record))
end

local function Quest(record)
	return record.quest == true or record.questStart == true or Class(record) == QUESTITEM
end

local TESTS = {}

function TESTS.new(record)
	return New.Is(record)
end

function TESTS.junk(record)
	return Categories.IsJunk(record)
end

function TESTS.set(record)
	return record.set == true
end

function TESTS.quest(record)
	return Quest(record)
end

function TESTS.gear(record)
	local class = Class(record)
	return class == WEAPON or class == ARMOR
end

function TESTS.consumable(record)
	return Class(record) == CONSUMABLE
end

function TESTS.trade(record)
	local class = Class(record)
	return class == TRADEGOODS or class == GEM or class == ITEM_ENHANCEMENT or class == PROFESSION
end

function TESTS.reagent(record)
	local class, subclass = Kind(record)
	return class == REAGENT or (class == MISCELLANEOUS and subclass == MISC_REAGENT)
end

function TESTS.recipe(record)
	return Class(record) == RECIPE
end

function TESTS.ammo(record)
	return Class(record) == PROJECTILE
end

function TESTS.bag(record)
	local class = Class(record)
	return class == CONTAINER or class == QUIVER
end

function TESTS.key(record)
	return Class(record) == KEYS or Whole(record.bag) == KEYRING
end

function TESTS.other()
	return true
end

local function Mode(group)
	local value = Opt(group.row)
	if type(value) == "string" and group.to[value] then
		return value
	end
	return "one"
end

local function KindOf(group, record)
	local class, subclass, slot = Kind(record)
	local key = slot and group.slots and group.slots[slot] or nil
	if not key and class then
		local subs = group.subs and group.subs[class]
		if subs then
			key = (subclass and subs[subclass]) or subs.any
		end
	end
	return key or group.base
end

local function Claims(group, record)
	return group.claims ~= nil and Mode(group) == "each" and KindOf(group, record) == group.claims
end

local function Shows(group, key)
	local to = group.to[Mode(group)]
	if not to then
		return key == group.base
	end
	return to[key] == key
end

local function Fit(key, record, placed)
	local group = GROUP_OF[key]
	if not group then
		return key
	end
	local to = group.to[Mode(group)]
	if not to then
		return group.base
	end
	if key ~= group.base or placed then
		local fitted = to[key]
		if fitted == key or (fitted and key ~= group.base) then
			return fitted
		end
	end
	return to[KindOf(group, record)] or group.base
end

local function HiddenSet()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local hidden = type(bags) == "table" and bags.hidden or nil
	if type(hidden) == "table" and next(hidden) ~= nil then
		return hidden
	end
	return nil
end

local function Hidden(key)
	if type(key) ~= "string" or not HIDEABLE[key] then
		return false
	end
	local hidden = HiddenSet()
	return hidden ~= nil and hidden[key] == true
end
Categories.Hidden = Hidden

function Categories.Hideable(key)
	return type(key) == "string" and HIDEABLE[key] == true
end

function Categories.Exists(key)
	local group = type(key) == "string" and GROUP_OF[key] or nil
	if group then
		return Shows(group, key)
	end
	return type(key) == "string" and LABELS[key] ~= nil
end

function Categories.HiddenKeys(now)
	local keys = {}
	local hidden = HiddenSet()
	if not hidden then
		return keys
	end
	for _, section in ipairs(SECTIONS) do
		local key = section.key
		if HIDEABLE[key] and hidden[key] == true and (not now or Categories.Exists(key)) then
			keys[#keys + 1] = key
		end
	end
	return keys
end

function Categories.HiddenSign()
	return table.concat(Categories.HiddenKeys(false), ",")
end

function Categories.SetHidden(key, on)
	local db = ns.Account()
	if type(db) ~= "table" or not Categories.Hideable(key) then
		return false
	end
	if on then
		if Hidden(key) then
			return false
		end
		if type(db.bags) ~= "table" then
			db.bags = {}
		end
		if type(db.bags.hidden) ~= "table" then
			db.bags.hidden = {}
		end
		db.bags.hidden[key] = true
	else
		local hidden = HiddenSet()
		if not hidden or hidden[key] == nil then
			return false
		end
		hidden[key] = nil
		if next(hidden) == nil then
			db.bags.hidden = nil
		end
	end
	Request("layout")
	return true
end

function Categories.ShowAll()
	local db = ns.Account()
	if not HiddenSet() or type(db) ~= "table" or type(db.bags) ~= "table" then
		return false
	end
	db.bags.hidden = nil
	Request("layout")
	return true
end

function Categories.GroupRow(key)
	local group = type(key) == "string" and GROUP_OF[key] or nil
	return group and group.row or nil
end

function Categories.GroupBase(key)
	local group = type(key) == "string" and GROUP_OF[key] or nil
	if not group then
		return nil, false
	end
	return group.base, Mode(group) ~= "one"
end

local function Rules(record)
	for _, key in ipairs(PRIORITY) do
		local group = GROUP_OF[key]
		local own = TESTS[key](record) == true
		if own or (group ~= nil and Claims(group, record)) then
			local fitted = Fit(key, record)
			if not Hidden(fitted) then
				return fitted
			end
			local to = own and group and group.to[Mode(group)] or nil
			local rest = to and to[group.base] or nil
			if rest and rest ~= fitted and not Hidden(rest) then
				return rest
			end
		end
	end
	return "other"
end

Categories.LIST = {}
for index, section in ipairs(SECTIONS) do
	local key = section.key
	local group = GROUP_OF[key]
	if group and group.base == key then
		group = nil
	end
	Categories.LIST[index] = {
		key = key,
		label = section.label,
		each = section.each,
		order = index,
		test = function(record)
			if type(record) ~= "table" then
				return key == "free"
			end
			if group then
				return (TESTS[group.base](record) == true or Claims(group, record)) and Fit(group.base, record) == key
			end
			local test = TESTS[key]
			return test ~= nil and test(record) == true
		end,
	}
end

function Categories.Label(key)
	if LABELS[key] then
		local each = EACH_LABELS[key]
		if each and GROUP_OF[key] and Mode(GROUP_OF[key]) == "each" then
			return each
		end
		return LABELS[key]
	end
	local name = type(Custom.Name) == "function" and Custom.Name(key) or nil
	if type(name) == "string" and not ns.IsSecret(name) and name ~= "" then
		return name
	end
	return type(key) == "string" and key or ""
end

function Categories.IsJunk(record)
	if type(record) ~= "table" then
		return false
	end
	local bag, id = Whole(record.bag), Whole(record.id)
	if not bag or not id or bag == KEYRING then
		return false
	end
	if record.live == true and BAGS[bag] then
		local slotTest = ns.ErrandsJunk
		if type(slotTest) == "function" then
			local slot = Whole(record.slot)
			return slot ~= nil and slotTest(bag, slot, true) == true
		end
	end
	local rule = ns.ErrandsJunkRule
	if type(rule) ~= "function" then
		return false
	end
	local quality = ns.Finite(record.quality) and record.quality or nil
	return rule(id, quality, record.noValue == true, Quest(record)) == true
end

local fresh, shown, banked = {}, {}, {}

local function NewKey(record)
	local guid = Text(record.guid)
	if guid then
		return guid
	end
	local bag, slot, id = Whole(record.bag), Whole(record.slot), Whole(record.id)
	if bag and slot and id then
		return ("%d:%d:%d"):format(bag, slot, id)
	end
	return nil
end

local function Kept()
	return Opt("newItems") ~= false
end

local function AtBanker()
	local visiting = B.Bank.Visiting
	return type(visiting) == "function" and visiting() == true
end

local function InBags(record)
	return type(record) == "table" and record.live == true and BAGS[Whole(record.bag)] == true
end

function New.Seen(changed)
	if type(changed) ~= "table" or not Kept() then
		return
	end
	local read = B.Data.Item
	if type(read) ~= "function" or type(C_NewItems) ~= "table" or type(C_NewItems.IsNewItem) ~= "function" then
		return
	end
	local bank = AtBanker()
	local me = ns.CharacterKey()
	for bag, slots in pairs(changed) do
		if BAGS[Whole(bag)] and type(slots) == "table" then
			for slot in pairs(slots) do
				if Whole(slot) then
					local ok, isNew = pcall(C_NewItems.IsNewItem, bag, slot)
					if ok and not ns.IsSecret(isNew) and isNew == true then
						local record = read(me, bag, slot)
						local key = InBags(record) and NewKey(record) or nil
						if key and bank then
							banked[key] = true
						elseif key and not banked[key] then
							fresh[key] = true
						end
					end
				end
			end
		end
	end
end

function New.Is(record)
	if not InBags(record) or not Kept() then
		return false
	end
	local key = NewKey(record)
	return key ~= nil and fresh[key] == true
end

function New.Shown(record)
	if not New.Is(record) then
		return false
	end
	shown[NewKey(record)] = true
	return true
end

function New.Close()
	if Kept() then
		for key in pairs(shown) do
			fresh[key] = nil
		end
	else
		Empty(fresh)
	end
	Empty(shown)
	Empty(banked)
end

function New.Clear()
	Empty(fresh)
	Empty(shown)
	if Kept() then
		Empty(banked)
	end
end

local function Store(make)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	local bags = db.bags
	if type(bags) ~= "table" then
		if not make then
			return nil
		end
		bags = {}
		db.bags = bags
	end
	local placed = bags.placed
	if type(placed) ~= "table" then
		if not make then
			return nil
		end
		placed = {}
		bags.placed = placed
	end
	return placed
end

local function PlacedIn(record)
	local placed, id = Store(false), Whole(record.id)
	if not placed or not id then
		return nil
	end
	local key = placed[id]
	if type(key) ~= "string" or not Placeable(key) then
		return nil
	end
	key = Fit(key, record, true)
	if Hidden(key) then
		return nil
	end
	return key
end

function Categories.Placed()
	local copy = {}
	for id, key in pairs(Store(false) or {}) do
		if Whole(id) and type(key) == "string" and Placeable(key) then
			copy[id] = key
		end
	end
	return copy
end

function Categories.PlacedKey(record)
	if Whole(record) then
		record = { id = record }
	end
	if type(record) ~= "table" then
		return nil
	end
	return PlacedIn(record)
end

local function PlacedHere(key)
	local ids = {}
	if type(key) ~= "string" then
		return ids
	end
	for id, placedKey in pairs(Store(false) or {}) do
		if Whole(id) and type(placedKey) == "string" and Placeable(placedKey) and Fit(placedKey, { id = id }, true) == key then
			ids[#ids + 1] = id
		end
	end
	return ids
end

function Categories.PlacedCount(key)
	return #PlacedHere(key)
end

local lastBack = nil

local function RememberBack(key, placed, ids)
	local back = { key = key, placed = {}, count = 0 }
	for _, id in ipairs(ids) do
		local saved = Whole(id) and placed[id] or nil
		if type(saved) == "string" and Placeable(saved) then
			back.placed[id] = saved
			back.count = back.count + 1
		end
	end
	lastBack = back.count > 0 and back or nil
end

function Categories.PutBack(key)
	local ids = PlacedHere(key)
	local placed = Store(false)
	if not placed or #ids == 0 then
		return 0
	end
	RememberBack(key, placed, ids)
	for _, id in ipairs(ids) do
		placed[id] = nil
	end
	Request("layout")
	return #ids
end

function Categories.LastPutBack()
	if not lastBack then
		return 0, nil
	end
	return lastBack.count, lastBack.key
end

function Categories.Unput()
	local last = lastBack
	if not last then
		return 0, 0, nil
	end
	lastBack = nil
	local back = 0
	for id, saved in pairs(last.placed) do
		local placed = Store(false)
		local now = placed and placed[id] or nil
		if now == saved then
			back = back + 1
		elseif now == nil then
			local done, why = Categories.Place(id, saved)
			if done then
				back = back + 1
			elseif why == "full" then
				Say(("%d items are placed by hand already. Take one off with Items placed by hand on the Bags page first."):format(MOST_PLACED))
				break
			elseif why == "saved" then
				break
			end
		end
	end
	if back > 0 then
		Request("layout")
	end
	return back, last.count, last.key
end

local function Full(placed, id)
	if type(placed) ~= "table" or placed[id] ~= nil then
		return false
	end
	local count = 0
	for _ in pairs(placed) do
		count = count + 1
		if count >= MOST_PLACED then
			return true
		end
	end
	return false
end

function Categories.Place(id, key)
	id = Whole(id)
	if not id or id <= 0 then
		return false, "id"
	end
	if key ~= nil and (type(key) ~= "string" or not Placeable(key)) then
		return false, "key"
	end
	local placed = Store(key ~= nil)
	if not placed then
		return key == nil, key ~= nil and "saved" or nil
	end
	if key == nil then
		placed[id] = nil
		return true
	end
	if Full(placed, id) then
		return false, "full"
	end
	placed[id] = key
	return true
end

local function Named(id)
	local name = type(C_Item) == "table" and Text(Errands.Ask(C_Item.GetItemNameByID, id)) or nil
	if name then
		return ("%s (%d)"):format(name, id)
	end
	return ("item %d"):format(id)
end

local function Price(item)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return nil
	end
	local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, item)
	if not ok or ns.IsSecret(name) or name == nil or not ns.Finite(price) or price < 0 then
		return nil
	end
	return price
end

local function Held()
	if type(GetCursorInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, link = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) or kind ~= "item" then
		return nil
	end
	id = Whole(id)
	if not id or id <= 0 then
		return nil
	end
	local bag, slot
	if type(C_Cursor) == "table" and type(C_Cursor.GetCursorItem) == "function" then
		local okItem, location = pcall(C_Cursor.GetCursorItem)
		if okItem and not ns.IsSecret(location) and type(location) == "table" then
			local okSlot, inBag, inSlot = pcall(function()
				return location.bagID, location.slotIndex
			end)
			if okSlot then
				bag, slot = Whole(inBag), Whole(inSlot)
			end
		end
	end
	return id, Text(link), bag, slot
end

local function Source(id, bag, slot)
	local read = B.Data.Item
	if not bag or not slot or type(read) ~= "function" then
		return nil
	end
	local record = read(ns.CharacterKey(), bag, slot)
	if type(record) == "table" and Whole(record.id) == id then
		return record
	end
	return nil
end

local function Probe(id, record)
	if record then
		return record
	end
	local quality = type(C_Item) == "table" and Errands.Ask(C_Item.GetItemQualityByID, id) or nil
	return { id = id, quality = ns.Finite(quality) and quality or nil }
end

local function Unsellable(record, link)
	return record.noValue == true or Price(link or record.id) == 0 or Quest(record)
end

local function GiveBack()
	if type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
end

local function DropOnJunk(id, record, link)
	if Quest(record) then
		Say(("%s is a quest item, and quest items are never sold."):format(Named(id)))
		return false
	end
	local mark = ns.ErrandsJunkMark
	if type(mark) ~= "function" then
		Say("Junk takes no items: this build of Flat UI cannot write the sell list.")
		return false
	end
	local noValue = Unsellable(record, link)
	if noValue or mark(id, true, noValue) == false then
		Say(("%s cannot be sold, so it does not go in Junk."):format(Named(id)))
		return false
	end
	Categories.Place(id, nil)
	return true
end

local function DroppedJunk(id, record)
	local bag = Whole(record.bag)
	if record.live == true and bag ~= nil and bag ~= KEYRING and BAGS[bag] and Categories.IsJunk(record) == true then
		return true
	end
	local rule = ns.ErrandsJunkRule
	if type(rule) ~= "function" then
		return false
	end
	local quality = ns.Finite(record.quality) and record.quality or nil
	return rule(id, quality, Unsellable(record, Text(record.link)), Quest(record)) == true
end

local function Writes(key, id, record)
	local here = PlacedIn(Whole(record.id) == id and record or { id = id })
	if here ~= nil and here == key then
		return nil
	end
	return key
end

local function Unlist(id, record)
	local mark = ns.ErrandsJunkMark
	if type(mark) == "function" and not Hidden("junk") and DroppedJunk(id, record) then
		return mark(id, false) == true
	end
	return false
end

local function DropOn(key, id, record)
	local unlisted = Unlist(id, record)
	local write = Writes(key, id, record)
	if not write then
		return true
	end
	local done, why = Categories.Place(id, write)
	if not done and why == "full" then
		Say(("%d items are placed by hand already. Take one off with Items placed by hand on the Bags page first."):format(MOST_PLACED))
	end
	return done or unlisted
end

function Categories.File(id, key, link, bag, slot)
	id = Whole(id)
	if not id or id <= 0 then
		return false
	end
	if key ~= "junk" and not Placeable(key) then
		return false
	end
	if Errands.Fighting() then
		Say("Items are not placed in sections in a fight. Try again once it is over.")
		return false
	end
	local record = Probe(id, Source(id, Whole(bag), Whole(slot)))
	local taken
	if key == "junk" then
		taken = DropOnJunk(id, record, Text(link))
	else
		taken = DropOn(key, id, record)
	end
	if taken then
		Request("layout")
	end
	return taken
end

local REFUSALS = {
	fight = { "Items are not placed in sections in a fight. Try again once it is over.", "Items are not placed in sections in a fight." },
	quest = { "%s is a quest item, and quest items are never sold.", "Quest items are never sold." },
	list = { "Junk takes no items: this build of Flat UI cannot write the sell list.", "This build of Flat UI cannot write the sell list." },
	unsold = { "%s cannot be sold, so it does not go in Junk.", "This item cannot be sold, so it does not go in Junk." },
	full = { "%d items are placed by hand already. Take one off with Items placed by hand on the Bags page first.",
		"%d items are placed by hand already. Put some back first." },
}

function Categories.Takes(id, key, link, bag, slot, quiet)
	id = Whole(id)
	if not id or id <= 0 or (key ~= "junk" and not Placeable(key)) then
		return false
	end
	local function Refuse(why, value)
		local lines = REFUSALS[why]
		if quiet then
			return false, value and lines[2]:format(value) or lines[2]
		end
		Say(value and lines[1]:format(value) or lines[1])
		return false
	end
	if Errands.Fighting() then
		return Refuse("fight")
	end
	local record = Probe(id, Source(id, Whole(bag), Whole(slot)))
	if key == "junk" then
		if Quest(record) then
			return Refuse("quest", not quiet and Named(id) or nil)
		elseif type(ns.ErrandsJunkMark) ~= "function" then
			return Refuse("list")
		elseif Unsellable(record, Text(link)) then
			return Refuse("unsold", not quiet and Named(id) or nil)
		end
		return true
	end
	if Writes(key, id, record) and Full(Store(false), id) then
		return Refuse("full", MOST_PLACED)
	end
	return true
end

function Categories.Drop(id, key)
	local held, link, bag, slot = Held()
	if not held then
		return false
	end
	local taken = Categories.File(held, key, link, bag, slot)
	GiveBack()
	return taken
end

function Categories.PlaceAll(key, records)
	if not Placeable(key) or type(records) ~= "table" then
		return 0
	end
	if Errands.Fighting() then
		Say(REFUSALS.fight[1])
		return 0
	end
	local count, seen = 0, {}
	for _, record in ipairs(records) do
		if Whole(record) then
			record = { id = record }
		end
		local id = type(record) == "table" and Whole(record.id) or nil
		if id and id > 0 and not seen[id] then
			seen[id] = true
			local write = Writes(key, id, record)
			local done, why = true, nil
			if write then
				done, why = Categories.Place(id, write)
			end
			if done then
				Unlist(id, record)
				count = count + 1
			elseif why == "full" then
				Say(REFUSALS.full[1]:format(MOST_PLACED))
				break
			elseif why == "saved" then
				break
			end
		end
	end
	if count > 0 then
		Request("layout")
	end
	return count
end

local function JunkShown(record)
	return not Hidden("junk") and Categories.IsJunk(record) == true
end

local function PinShown(record)
	if record.live ~= true or Hidden("keep") then
		return false
	end
	local of = B.Pins and B.Pins.Of
	if type(of) ~= "function" then
		return false
	end
	local ok, pinned = pcall(of, record)
	return ok and pinned == true
end

function Categories.Of(record)
	if type(record) ~= "table" then
		return "free"
	end
	local placed = PlacedIn(record)
	local junk, pinned
	if placed then
		junk = JunkShown(record)
		pinned = not junk and PinShown(record)
		if not junk and not pinned then
			return placed
		end
	end
	if New.Is(record) then
		return "new"
	end
	if junk == nil then
		junk = JunkShown(record)
	end
	if junk then
		return "junk"
	end
	if pinned == nil then
		pinned = PinShown(record)
	end
	if pinned then
		return "keep"
	end
	return Rules(record)
end

local levels = {}

local function Level(record)
	local level = record.level
	if ns.Finite(level) then
		return level
	end
	local link = Text(record.link)
	if not link then
		return nil
	end
	level = levels[link]
	if level == nil then
		local items = ns.Items
		local levelOf = type(items) == "table" and items.LevelOf or nil
		level = type(levelOf) == "function" and levelOf(link) or nil
		if not ns.Finite(level) then
			return nil
		end
		levels[link] = level
	end
	record.level = level
	return level
end

local lowered = {}

local function LowerName(record)
	local name = Text(record.name)
	if not name then
		return nil
	end
	local low = lowered[name]
	if not low then
		low = name:lower()
		lowered[name] = low
	end
	return low
end

local function Quality(record)
	return ns.Finite(record.quality) and record.quality or -1
end

local function NameOrder(a, b)
	local nameA, nameB = LowerName(a), LowerName(b)
	if nameA and nameB then
		if nameA ~= nameB then
			return nameA < nameB and -1 or 1
		end
	elseif nameA then
		return -1
	elseif nameB then
		return 1
	end
	local idA, idB = Whole(a.id) or 0, Whole(b.id) or 0
	if idA ~= idB then
		return idA < idB and -1 or 1
	end
	return 0
end

local function BagOrder(bag)
	bag = Whole(bag)
	if bag == KEYRING then
		return KEYRING_PLACE
	end
	return bag or NO_BAG
end

function Categories.Compare(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return type(a) == "table" and type(b) ~= "table"
	end
	if a == b then
		return false
	end
	local classA, subA, slotA = Kind(a)
	local classB, subB, slotB = Kind(b)
	local gearA = classA == WEAPON or classA == ARMOR
	local gearB = classB == WEAPON or classB == ARMOR
	if gearA ~= gearB then
		return gearA
	end
	if gearA then
		local orderA, orderB = SLOT_ORDER[slotA or ""] or SLOT_LAST, SLOT_ORDER[slotB or ""] or SLOT_LAST
		if orderA ~= orderB then
			return orderA < orderB
		end
		local levelA, levelB = Level(a) or 0, Level(b) or 0
		if levelA ~= levelB then
			return levelA > levelB
		end
	else
		classA, classB = classA or LAST, classB or LAST
		if classA ~= classB then
			return classA < classB
		end
		subA, subB = subA or LAST, subB or LAST
		if subA ~= subB then
			return subA < subB
		end
	end
	local qualityA, qualityB = Quality(a), Quality(b)
	if qualityA ~= qualityB then
		return qualityA > qualityB
	end
	local named = NameOrder(a, b)
	if named ~= 0 then
		return named < 0
	end
	if not gearA then
		local countA = Whole(a.count) or 1
		local countB = Whole(b.count) or 1
		if countA ~= countB then
			return countA > countB
		end
	end
	local bagA, bagB = BagOrder(a.bag), BagOrder(b.bag)
	if bagA ~= bagB then
		return bagA < bagB
	end
	return (Whole(a.slot) or 0) < (Whole(b.slot) or 0)
end

local PLACED_ALL = "Put every item back in its own section"
local PLACED_NONE = "No item is placed by hand. Drop an item from your bags on a section's title to keep it there."
local PLACED_UNDO = {
	all = "Bring back the %d placements you took off",
	one = "Bring back the %d placements you took off %s",
	single = "Bring back the placement you took off",
	singleOne = "Bring back the placement you took off %s",
}
local UNDO_SAY = {
	one = "Flat UI: 1 item is back in the section you placed it in.",
	all = "Flat UI: %d items are back in the sections you placed them in.",
	some = "Flat UI: %d of the %d items are back in the sections you placed them in; the others are placed in another section now.",
	none = "Flat UI: nothing to bring back.",
}

function ns.BagsPlacedLines()
	local lines = {}
	for id, key in pairs(Categories.Placed()) do
		local fitted = Fit(key, { id = id }, true)
		lines[#lines + 1] = { id, ("%s: %s%s"):format(Named(id), Categories.Label(fitted), Hidden(fitted) and " (deleted)" or "") }
	end
	table.sort(lines, function(a, b)
		return a[2] < b[2]
	end)
	if #lines >= 2 then
		table.insert(lines, 1, { "all", PLACED_ALL })
	end
	local count, key = Categories.LastPutBack()
	if count > 0 then
		local text
		if key then
			text = count == 1 and PLACED_UNDO.singleOne:format(Categories.Label(key)) or PLACED_UNDO.one:format(count, Categories.Label(key))
		else
			text = count == 1 and PLACED_UNDO.single or PLACED_UNDO.all:format(count)
		end
		table.insert(lines, 1, { "undo", text })
	end
	if #lines == 0 then
		return { { "none", PLACED_NONE } }
	end
	return lines
end

function ns.BagsPlacedPick(id)
	if id == "all" then
		local placed = Store(false)
		if not placed or next(placed) == nil then
			return false, "Flat UI: no item is placed by hand."
		end
		local ids = {}
		for placedId in pairs(placed) do
			ids[#ids + 1] = placedId
		end
		RememberBack(nil, placed, ids)
		for key in pairs(placed) do
			placed[key] = nil
		end
		Request("layout")
		return true, "Flat UI: every item placed by hand goes back to its own section. The first line of Items placed by hand brings them back."
	elseif id == "undo" then
		local back, total = Categories.Unput()
		if back <= 0 then
			return false, UNDO_SAY.none
		elseif back < total then
			return true, UNDO_SAY.some:format(back, total)
		end
		return true, back == 1 and UNDO_SAY.one or UNDO_SAY.all:format(back)
	elseif id == "none" then
		return false, "Flat UI: no item is placed by hand."
	end
	id = Whole(id)
	local placed = Store(false)
	if not id or not placed or placed[id] == nil then
		return false, "That item is not placed by hand."
	end
	placed[id] = nil
	if lastBack and lastBack.placed[id] ~= nil then
		lastBack.placed[id] = nil
		lastBack.count = lastBack.count - 1
		if lastBack.count <= 0 then
			lastBack = nil
		end
	end
	Request("layout")
	return true, ("Flat UI: %s goes back to its own section."):format(Named(id))
end
