local _, ns = ...

-- Bags: the sections of the category view and the rules that file each item in one, the record of new items, the junk test, and the
-- placement of items by hand with drops on Junk. Bags.lua makes ns.Bags with B.Categories and B.Categories.New; this file only adds their
-- fields. It makes no frame and owns no event: BagsData.lua hears BAG_UPDATE_DELAYED and hands New.Seen the slots that changed before it asks
-- for a redraw, and the window's layout (BagsLayout.lua) asks Of, Compare and Label when it lays a window out.
--
-- An item lands in the first section whose rule it meets: New items, then Junk, then the section the player placed it in by hand, then
-- Equipment sets, Quest items, Equipment, Consumables, Trade goods, Reagents, Recipes, Ammunition, Bags and quivers, Keys and Other. Free slots
-- holds the empty slots. The rules read the class, subclass and equip slot the game gives at once (C_Item.GetItemInfoInstant,
-- ItemDocumentation.lua:659-679, which never waits for the server), as BagsData keeps them on each record or through B.Data.Info, and compare
-- them with the numbers of Forever's Enum.ItemClass and Enum.ItemMiscellaneousSubclass (wowless, data/products/wowf/enums.yaml:4630-4651 and
-- 5009-5016). An item in an equipment set (the record's set, from C_Container.GetContainerItemEquipmentSetInfo) and a quest item (class 12, or the
-- record's quest and questStart, from C_Container.GetContainerItemQuestInfo, ContainerDocumentation.lua:281-295) are read by BagsData. With
-- Equipment set to Weapons, armour and jewellery, Equipment is three sections. The sections are shown in an order of their own (LIST), which is
-- not the order their rules are tried in: New items first, Junk and Free slots last.
--
-- New items: an item is new when the game's own flag is set (C_NewItems.IsNewItem, NewItemsDocumentation.lua:15-28) at the scan in which its
-- slot changed. It is then kept by its GUID (the record's guid, which BagsData reads with C_Item.GetItemGUID) for the session, so pointing at it,
-- which takes the game's flag off (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:1735-1738), leaves it in New items. While the bank is open,
-- in Flat UI's bank window or the game's (B.Bank.Visiting), nothing becomes new: what comes out of the bank is not loot. When the bag window closes,
-- every item New items showed during that opening leaves; a click on its title and a clean up take every one out at once. With New items at the
-- top off, nothing is kept as new.
--
-- Junk is Errands' own test, so the Junk section, the junk coin and Sell junk always agree. A live slot of the bags is junk when Errands would
-- sell it (ns.ErrandsJunk: the sale test of ErrandsMerchant.lua:165-190, with the bags the game's menu leaves out of junk selling, :154-163).
-- The keyring never is: Errands walks bags 0 to NUM_TOTAL_EQUIPPED_BAG_SLOTS only (:100-107). The bank and every item of another character,
-- which nothing can sell from where they are, take the list part of that test (ns.ErrandsJunkRule, :176-183): on the sell list, or grey and not
-- on the keep list, and never an item with no value or a quest item. Junk is tried right after New items, so a new junk item stays in New items
-- with its coin until the bags close, and nothing Sell junk sells is filed anywhere else.
--
-- Placement by hand: an item dropped on the title of a section stays in that section, by item ID, for the whole account, in FlatUIDB.bags.placed
-- (at most MOST_PLACED items). A drop reads the cursor (GetCursorInfo, and C_Cursor.GetCursorItem for the slot the item came from,
-- CursorDocumentation.lua:11-19, read from the fields of its ItemLocation, Blizzard_ObjectAPI/Mainline/ItemLocation.lua:35-44) and gives the
-- item back to its slot with ClearCursor. Dropped on Junk, the item goes on Errands' sell list, and a junk item dropped on another section goes
-- on its keep list (ns.ErrandsJunkMark), as /flatui sell and /flatui keep put them there (ErrandsMerchant.lua:758-781): a placement of Flat UI's
-- own in or out of Junk would make the section and the selling disagree. An item the game gives no value, or no sell price (C_Item.GetItemInfo,
-- ItemDocumentation.lua:626-657), and a quest item cannot go in Junk, since Errands never sells them. Dropped on the section it reaches by itself,
-- an item loses its placement. An item whose slot the game does not say is judged by its ID alone, with its quality from
-- C_Item.GetItemQualityByID. New items and Free slots take no drop, and no drop is taken in a fight (InCombatLockdown and UnitAffectingCombat,
-- through Errands.Fighting): the item only goes back. The lines said in chat name an item as Errands does, by C_Item.GetItemNameByID and its ID.
-- The row Items placed by hand lists the placements and takes one off.
--
-- Inside a section, equipment sorts by the place of its slot in the Character window (Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:779-873),
-- then by item level (ns.Items.LevelOf, Items.lua:425-438), quality and name; everything else by class, subclass, quality, name and count. An item
-- whose name has not loaded sorts by its item ID after the named ones, and the last key is the bag and slot, so equal items never swap.

local KEY = "bags"
local B = ns.Bags
local Categories = B.Categories
local New = B.Categories.New
local Errands = ns.Errands

-- Forever's Enum.ItemClass (wowless, data/products/wowf/enums.yaml:4630-4651) and the Reagent subclass of Miscellaneous (:5009-5016).
local CONSUMABLE, CONTAINER, WEAPON, GEM, ARMOR, REAGENT, PROJECTILE, TRADEGOODS = 0, 1, 2, 3, 4, 5, 6, 7
local ITEM_ENHANCEMENT, RECIPE, QUIVER, QUESTITEM, KEYS, MISCELLANEOUS, PROFESSION = 8, 9, 11, 12, 13, 15, 19
local MISC_REAGENT = 1
-- The containers of the bags (Enum.BagIndex, enums.yaml:544-572): the backpack, the four bags, the reagent bag and the keyring.
local KEYRING = -1
local BAGS = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [KEYRING] = true }
-- The most items kept in a section by hand.
local MOST_PLACED = 500
-- Where a class, subclass or slot nobody gave sorts, and where the keyring and an unknown bag sort among the containers.
local LAST, KEYRING_PLACE, NO_BAG = 1000, 100, 200

-- The sections in the order they are shown.
local SECTIONS = {
	{ key = "new", label = "New items" },
	{ key = "set", label = "Equipment sets" },
	{ key = "gear", label = "Equipment" },
	{ key = "weapon", label = "Weapons" },
	{ key = "armour", label = "Armour" },
	{ key = "jewel", label = "Jewellery" },
	{ key = "consumable", label = "Consumables" },
	{ key = "quest", label = "Quest items" },
	{ key = "trade", label = "Trade goods" },
	{ key = "reagent", label = "Reagents" },
	{ key = "recipe", label = "Recipes" },
	{ key = "ammo", label = "Ammunition" },
	{ key = "bag", label = "Bags and quivers" },
	{ key = "key", label = "Keys" },
	{ key = "other", label = "Other" },
	{ key = "junk", label = "Junk" },
	{ key = "free", label = "Free slots" },
}
-- The rules after New items, Junk and placement, in the order they are tried; Other takes the rest.
local PRIORITY = { "set", "quest", "gear", "consumable", "trade", "reagent", "recipe", "ammo", "bag", "key" }
-- The sections of the Equipment family, which the Equipment row shows as one or as three.
local GEAR = { gear = true, weapon = true, armour = true, jewel = true }
-- With Equipment split: the slots that go with the weapons besides class 2, and the jewellery.
local WEAPON_SLOTS = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
	INVTYPE_RELIC = true }
local JEWEL_SLOTS = { INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true }
-- The place of each equip slot in the Character window, head to ranged (Camelot/PaperDollFrame.xml:779-873); a weapon for either hand goes with
-- the main hand, and anything else after the ranged slot.
local SLOT_ORDER = {
	INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_BODY = 6,
	INVTYPE_TABARD = 7, INVTYPE_WRIST = 8, INVTYPE_HAND = 9, INVTYPE_WAIST = 10, INVTYPE_LEGS = 11, INVTYPE_FEET = 12, INVTYPE_FINGER = 13,
	INVTYPE_TRINKET = 14, INVTYPE_WEAPON = 15, INVTYPE_2HWEAPON = 15, INVTYPE_WEAPONMAINHAND = 15, INVTYPE_WEAPONOFFHAND = 16,
	INVTYPE_SHIELD = 16, INVTYPE_HOLDABLE = 16, INVTYPE_RANGED = 17, INVTYPE_RANGEDRIGHT = 17, INVTYPE_THROWN = 17, INVTYPE_RELIC = 17,
}
local SLOT_LAST = 18

local LABELS, PLACEABLE = {}, {}
for _, section in ipairs(SECTIONS) do
	LABELS[section.key] = section.label
	-- New items follows the game's flag and Free slots is empty space, so neither can hold an item by its ID; Junk is Errands' lists.
	if section.key ~= "new" and section.key ~= "junk" and section.key ~= "free" then
		PLACEABLE[section.key] = true
	end
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- A text the client gave plainly, or nil.
local function Text(value)
	if value ~= nil and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

-- A whole number the client gave plainly, or nil.
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

-- A line in the chat frame.
local function Say(text)
	print("Flat UI: " .. text)
end

-- Asks Bags.lua for a pass of the windows on the next frame (flag: "layout" or "search"), for both windows.
local function Request(flag)
	local request = B.Request
	if type(request) == "function" then
		request(flag)
	end
end

-- Kinds of item ---------------------------------------------------------------------------------------------------------------------------

-- What C_Item.GetItemInfoInstant says of an item ID, read here only when BagsData has no answer: { class, subclass, equipLoc, itype,
-- isubtype }, or false for an ID the client does not know. The call never waits for the server, so an answer is kept for the session.
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

-- The class, subclass, equip slot, type and subtype of a record's item: the record's own, else what the game gives for its ID. Each is nil
-- when nobody says. BagsSearch.lua reads the same through Categories.Kind.
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

-- The rule of each section, for a record. LIST hands them out, and Of tries them in the order of PRIORITY.
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

function TESTS.weapon(record)
	local class, _, slot = Kind(record)
	return class == WEAPON or (slot ~= nil and WEAPON_SLOTS[slot] == true)
end

function TESTS.jewel(record)
	local _, _, slot = Kind(record)
	return slot ~= nil and JEWEL_SLOTS[slot] == true
end

function TESTS.armour(record)
	return Class(record) == ARMOR and not TESTS.weapon(record) and not TESTS.jewel(record)
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

-- The section of the Equipment family a record goes to with Equipment split: Weapons, Jewellery, else Armour.
local function Split(record)
	if TESTS.weapon(record) then
		return "weapon"
	elseif TESTS.jewel(record) then
		return "jewel"
	end
	return "armour"
end

-- A section of the Equipment family as the Equipment row shows it: one section, or the record's own of the three. Other sections stay.
local function Fit(key, record)
	if not GEAR[key] then
		return key
	end
	if Opt("gear") ~= "kind" then
		return "gear"
	end
	if key == "gear" then
		return Split(record)
	end
	return key
end

-- The section a record reaches by its own rules, after New items, Junk and placement.
local function Rules(record)
	for _, key in ipairs(PRIORITY) do
		if TESTS[key](record) then
			return Fit(key, record)
		end
	end
	return "other"
end

-- The sections, in the order they are shown: { key, label, order, test(record) }. A section with no item is not drawn, so all four of the
-- Equipment family are listed and Of files an item in the ones the Equipment row shows. A test with no record is true for Free slots alone.
Categories.LIST = {}
for index, section in ipairs(SECTIONS) do
	local key = section.key
	Categories.LIST[index] = {
		key = key,
		label = section.label,
		order = index,
		test = function(record)
			if type(record) ~= "table" then
				return key == "free"
			end
			local test = TESTS[key]
			return test ~= nil and test(record) == true
		end,
	}
end

function Categories.Label(key)
	return LABELS[key] or (type(key) == "string" and key or "")
end

-- Junk -----------------------------------------------------------------------------------------------------------------------------------

-- Whether Sell junk would sell the item, by Errands' own test (see the top of the file).
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
			return slot ~= nil and slotTest(bag, slot) == true
		end
	end
	local rule = ns.ErrandsJunkRule
	if type(rule) ~= "function" then
		return false
	end
	local quality = ns.Finite(record.quality) and record.quality or nil
	return rule(id, quality, record.noValue == true, Quest(record)) == true
end

-- New items ------------------------------------------------------------------------------------------------------------------------------

-- By the key of an item (its GUID, else its bag, slot and ID): true while it is new. And the items New items showed since the bag window last
-- opened, which leave it when the window closes.
local fresh, shown = {}, {}

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

-- With New items at the top off, nothing is kept as new.
local function Kept()
	return Opt("newItems") ~= false
end

-- A visit to a banker is under way (B.Bank.Visiting, BagsBank.lua), with Flat UI's bank window or the game's: what comes out of the bank then is not
-- loot.
local function AtBanker()
	local visiting = B.Bank.Visiting
	return type(visiting) == "function" and visiting() == true
end

-- A live slot of this character's bags: the only items that can be new.
local function InBags(record)
	return type(record) == "table" and record.live == true and BAGS[Whole(record.bag)] == true
end

-- changed: { [bag] = { [slot] = true } }, the slots BagsData found changed at BAG_UPDATE_DELAYED, before it asks for the redraw.
function New.Seen(changed)
	if type(changed) ~= "table" or not Kept() or AtBanker() then
		return
	end
	local read = B.Data.Item
	if type(read) ~= "function" or type(C_NewItems) ~= "table" or type(C_NewItems.IsNewItem) ~= "function" then
		return
	end
	local me = ns.CharacterKey()
	for bag, slots in pairs(changed) do
		if BAGS[Whole(bag)] and type(slots) == "table" then
			for slot in pairs(slots) do
				if Whole(slot) then
					local ok, isNew = pcall(C_NewItems.IsNewItem, bag, slot)
					if ok and not ns.IsSecret(isNew) and isNew == true then
						local record = read(me, bag, slot)
						local key = InBags(record) and NewKey(record) or nil
						if key then
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

-- The layout calls this for each record it draws in New items. True for a record that is new.
function New.Shown(record)
	if not New.Is(record) then
		return false
	end
	shown[NewKey(record)] = true
	return true
end

-- The bag window closed: what New items showed leaves it.
function New.Close()
	if Kept() then
		for key in pairs(shown) do
			fresh[key] = nil
		end
	else
		Empty(fresh)
	end
	Empty(shown)
end

-- Every item leaves New items now: a click on its title, or a clean up. The caller asks for the layout.
function New.Clear()
	Empty(fresh)
	Empty(shown)
end

-- Placement by hand ----------------------------------------------------------------------------------------------------------------------

-- FlatUIDB.bags.placed, { [itemID] = section key }, made when a placement is first written; nil before the saved variables load, or when
-- nothing is placed and make is not set.
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

-- The section a record was placed in, as the Equipment row shows it, or nil. A placement that is not a section that holds items is skipped.
local function PlacedIn(record)
	local placed, id = Store(false), Whole(record.id)
	if not placed or not id then
		return nil
	end
	local key = placed[id]
	if type(key) ~= "string" or not PLACEABLE[key] then
		return nil
	end
	return Fit(key, record)
end

-- The placements of the account: a new table { [itemID] = section key } of every valid one.
function Categories.Placed()
	local copy = {}
	for id, key in pairs(Store(false) or {}) do
		if Whole(id) and type(key) == "string" and PLACEABLE[key] then
			copy[id] = key
		end
	end
	return copy
end

-- Keeps an item in a section, or takes its placement away with no key. Returns true, or false and why: "id", "key", "saved" (the saved
-- variables are not loaded) or "full" (MOST_PLACED items are placed already).
function Categories.Place(id, key)
	id = Whole(id)
	if not id or id <= 0 then
		return false, "id"
	end
	if key ~= nil and (type(key) ~= "string" or not PLACEABLE[key]) then
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
	if placed[id] == nil then
		local count = 0
		for _ in pairs(placed) do
			count = count + 1
		end
		if count >= MOST_PLACED then
			return false, "full"
		end
	end
	placed[id] = key
	return true
end

-- An item by its name and ID, as Errands names the items of its lists, or by its ID while the client has not loaded it.
local function Named(id)
	local name = type(C_Item) == "table" and Text(Errands.Ask(C_Item.GetItemNameByID, id)) or nil
	if name then
		return ("%s (%d)"):format(name, id)
	end
	return ("item %d"):format(id)
end

-- The sell price of an item (the 11th answer of C_Item.GetItemInfo), or nil while the game has not said.
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

-- What the cursor holds: the item ID and link, and the bag and slot it was taken from when the game says, or nil when it holds no item.
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

-- The record of the slot the item on the cursor came from, while that slot still holds it (locked), or nil.
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

-- The record a drop is judged by: the slot's own, else what the item ID alone tells.
local function Probe(id, record)
	if record then
		return record
	end
	local quality = type(C_Item) == "table" and Errands.Ask(C_Item.GetItemQualityByID, id) or nil
	return { id = id, quality = ns.Finite(quality) and quality or nil }
end

-- Whether the item can never be sold: no value, a sell price of 0, or a quest item.
local function Unsellable(record, link)
	return record.noValue == true or Price(link or record.id) == 0 or Quest(record)
end

local function GiveBack()
	if type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
end

-- A drop on Junk: the item goes on the sell list and loses its placement.
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

-- A drop on another section: a junk item leaves the lists first, then the item is kept there, or loses its placement when that is the
-- section it reaches by itself. True when either changed what the window shows.
local function DropOn(key, id, record)
	local rule, mark = ns.ErrandsJunkRule, ns.ErrandsJunkMark
	local unlisted = false
	if type(rule) == "function" and type(mark) == "function" then
		local quality = ns.Finite(record.quality) and record.quality or nil
		if rule(id, quality, Unsellable(record, Text(record.link)), Quest(record)) == true then
			mark(id, false)
			unlisted = true
		end
	end
	local done, why = Categories.Place(id, key ~= Rules(record) and key or nil)
	if not done and why == "full" then
		Say(("%d items are placed by hand already. Take one off with Items placed by hand on the Bags page first."):format(MOST_PLACED))
	end
	return done or unlisted
end

-- A click or drop on the title of a section while the cursor holds an item. id: the item ID the caller read, or nil to read the cursor here;
-- the cursor is what counts. The item always goes back to its slot. True when the drop was taken.
function Categories.Drop(id, key)
	local held, link, bag, slot = Held()
	if not held then
		return false
	end
	id = held
	if key ~= "junk" and not PLACEABLE[key] then
		GiveBack()
		return false
	end
	if Errands.Fighting() then
		GiveBack()
		Say("Items are not placed in sections in a fight. Try again once it is over.")
		return false
	end
	local record = Probe(id, Source(id, bag, slot))
	local taken
	if key == "junk" then
		taken = DropOnJunk(id, record, link)
	else
		taken = DropOn(key, id, record)
	end
	GiveBack()
	if taken then
		Request("layout")
	end
	return taken
end

-- Filing and order -----------------------------------------------------------------------------------------------------------------------

-- The section a record is shown in: New items, then Junk, then its placement, then the built-in rules. No record is a free slot.
function Categories.Of(record)
	if type(record) ~= "table" then
		return "free"
	end
	if New.Is(record) then
		return "new"
	end
	if Categories.IsJunk(record) then
		return "junk"
	end
	return PlacedIn(record) or Rules(record)
end

-- The item level of a gear record (the record's own, else ns.Items.LevelOf by link, kept on the record and per link), or nil.
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

-- Names in lower case, by name, so a sort lowers each once.
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

-- -1, 0 or 1: names first, by name, then the items whose names have not loaded; then by item ID.
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

-- The order inside a section: true when a goes before b (see the top of the file). Gear goes before the rest, so a section that holds both,
-- such as Junk, keeps one order.
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

-- The row Items placed by hand ---------------------------------------------------------------------------------------------------------

-- Every placement, by the name of its item: { { itemID, "Name (ID): Section" }, ... }.
function ns.BagsPlacedLines()
	local lines = {}
	for id, key in pairs(Categories.Placed()) do
		lines[#lines + 1] = { id, ("%s: %s"):format(Named(id), Categories.Label(Fit(key, { id = id }))) }
	end
	table.sort(lines, function(a, b)
		return a[2] < b[2]
	end)
	return lines
end

-- Takes one placement off, with the page on or off; a window that shows is laid out again.
function ns.BagsPlacedPick(id)
	id = Whole(id)
	local placed = Store(false)
	if not id or not placed or placed[id] == nil then
		return false, "That item is not placed by hand."
	end
	placed[id] = nil
	Request("layout")
	return true, ("Flat UI: %s goes back to its own section."):format(Named(id))
end
