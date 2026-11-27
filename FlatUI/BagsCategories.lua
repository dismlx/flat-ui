local _, ns = ...

-- Bags: the sections of the category view and the rules that file each item in one, the record of new items, the junk test, and the
-- placement of items by hand with drops on Junk. Bags.lua makes ns.Bags with B.Categories and B.Categories.New; this file only adds their
-- fields. It makes no frame and owns no event: BagsData.lua hears BAG_UPDATE_DELAYED and BAG_NEW_ITEMS_UPDATED and hands New.Seen the slots that
-- changed, or whose new flag is set, before it asks for a redraw, and the window's layout (BagsLayout.lua) asks Of, Compare, Label, Hidden,
-- HiddenKeys and HiddenSign when it lays a window out; BagsOrder.lua asks Hideable, Exists, GroupRow, GroupBase, SetHidden and ShowAll for a title's
-- menu, the Deleted button after the last section and the rows Delete a section and Deleted sections, and Placeable, PlacedCount, PutBack,
-- LastPutBack, Unput and PlaceAll for the lines of a title's menu that put back, bring back and place items.
--
-- An item lands in the first section whose rule it meets: New items, then Junk, then Keep in place, then the section the player placed it in by
-- hand, then Equipment sets, Quest items, Equipment, Consumables, Trade goods, Reagents, Recipes, Ammunition, Bags and quivers, Keys and Other.
-- Free slots holds the empty slots. The rules read the class, subclass and equip slot the game gives at once (C_Item.GetItemInfoInstant,
-- ItemDocumentation.lua:659-679, which never waits for the server), as BagsData keeps them on each record or through B.Data.Info, and compare
-- them with the numbers of Forever's Enum.ItemClass and Enum.ItemMiscellaneousSubclass (wowless, data/products/wowf/enums.yaml:4630-4651 and
-- 5009-5016). An item in an equipment set (the record's set, from C_Container.GetContainerItemEquipmentSetInfo) and a quest item (class 12, or the
-- record's quest and questStart, from C_Container.GetContainerItemQuestInfo, ContainerDocumentation.lua:281-295) are read by BagsData.
--
-- Groups (GROUPS): three rows of the Bags page show a family of sections as one section or apart, and their default, One section, keeps it one.
-- Equipment (bags.gear): Weapons, armour and jewellery splits it in three, by equip slot as before (shields, off-hands and relics with the weapons,
-- shirts and tabards with the armour); Each kind in Weapons (every weapon slot, ranged, thrown and wands), Shields and off-hands (INVTYPE_SHIELD,
-- INVTYPE_HOLDABLE), Armour (head, shoulders, chest and robe, waist, legs, feet, wrists, hands and back), Rings, Necklaces, Trinkets, Relics,
-- Shirts and tabards, and Equipment for what is left. Consumables (bags.consumables): Food, potions and the rest splits it in Food and drink
-- (Enum.ItemConsumableSubclass Fooddrink 5, wowless, data/products/wowf/enums.yaml:4694-4711), Potions and elixirs (Potion 1, Elixir 2,
-- Flasksphials 3) and Consumables; Each kind in Food and drink, Potions (named so then), Elixirs and flasks, Scrolls (4), Bandages (7),
-- Enhancements (Itemenhancement 6 and ItemenhancementTemporary 15: oils, stones, kits and the like), Explosives and devices (Device 14, and the
-- Explosives and Devices of Trade goods, which this game files as trade goods: at Each kind Consumables takes them ahead of Trade goods' rule) and
-- Consumables for the rest. Trade goods (bags.tradeGoods): Each kind splits it in Cloth, Leather, Metal and stone, Herbs, Elemental, Enchanting,
-- Meat, Parts (with the explosives and devices while Consumables is not at Each kind) and Trade goods for the rest (gems, item enhancements,
-- profession items and the trade goods of no kind above). Forever's enums list no subclasses of Trade goods (enums.yaml has none, and the game's
-- auction house asks the server for them, C_AuctionHouse.GetAuctionItemSubClasses, Camelot/Blizzard_AuctionData.lua:183-186), so those are the
-- client's own numbers for class 7: Parts 1, Explosives 2, Devices 3, Cloth 5, Leather 6, Metal & Stone 7, Meat 8, Herb 9, Elemental 10, Other 11,
-- Enchanting 12. Fit gives the section a key of a group stands for under its row's choice, so a placement by hand in a section the choice does not
-- show goes to the one that holds its kind there (Rings to Jewellery, Jewellery at Each kind to the ring's own section, and every one to the group's
-- base at One section), and Of files an item in the sections the rows show.
--
-- Hidden sections: the player may hide any section of Flat UI's own but New items, Free slots and Other, which the player's words call deleting
-- (Delete this section in a title's right-click menu and the row Delete a section, which also deletes a split group's every kind at once; the
-- row Deleted sections and Deleted (3) after the last section bring one back, BagsOrder.lua), in both windows and for every character, a set of
-- keys for the whole account in FlatUIDB.bags.hidden, { [key] = true }, beside the order and the folds, read with a type test at each use; an
-- empty set is not kept. A hidden section is passed by as if it were not there: its items go to the
-- next rule that takes them, a hidden kind of a split group to the section that holds the group's rest under its row's choice while that shows
-- (Potions to Consumables, Rings to Equipment, Weapons to Armour at Weapons, armour and jewellery), and Other at worst; the explosives and devices
-- of Trade goods, which Consumables only claims, go on to Trade goods' rule then. Junk hidden changes only where junk shows (IsJunk, the sell list,
-- Sell junk and the junk coin stay, and a drop takes no item off the sell list), and Keep in place hidden leaves the pins as they are, their items
-- filed by kind, and a drop on another section unpins no slot (B.Pins.Left). A placement by hand in a hidden section is kept but skipped, and
-- counts again once it shows. Keys of the set that are no such section are skipped, so a section that is gone, or one of a choice not in use, errs
-- nowhere.
--
-- The sections are shown in an order of their own (LIST), which is
-- not the order their rules are tried in: New items first, Keep in place next, Junk and Free slots last, and each section of a group where its group
-- stands, after the group's base; the player may move every section but New items and Free slots (BagsOrder.lua), which changes the order they are
-- shown in and never where an item is filed. Sections the player makes and names (B.Custom, BagsCustom.lua) hold only the items placed in them by
-- hand, and come right after Keep in place in the built-in order (BagsOrder.lua).
--
-- Keep in place holds the items of this character's bags (a live record of bags 0 to 5) that sit in the slot the player pinned for them
-- (B.Pins.Of, BagsPins.lua). It comes after Junk, so the Junk section and Sell junk always agree; pinning takes an item off the sell list and puts a
-- grey one on the keep list, so a pinned item is not junk. It takes no placement by hand: pins are per character and per slot, in
-- FlatUICharDB.bagPins, and a drop on its title pins the slot the item came from (BagsLayout.lua hands that drop to BagsPins.lua).
--
-- New items: an item is new when the game's own flag is set (C_NewItems.IsNewItem, NewItemsDocumentation.lua:15-28) at the scan in which its
-- slot changed, or when BagsData hears that the game set new flags (BAG_NEW_ITEMS_UPDATED), which it may do after that scan. It is then kept by
-- its GUID (the record's guid, which BagsData reads with C_Item.GetItemGUID) for the session, so pointing at it, which takes the game's flag off
-- (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:1735-1738), leaves it in New items. While the bank is open, in Flat UI's bank window or the
-- game's (B.Bank.Visiting), nothing becomes new: what comes out of the bank is not loot, and it keeps the game's flag after the visit, so an item
-- flagged then is noted and stays out of New items until the flags come off. When the bag window closes, every item New items showed during that
-- opening leaves; a click on its title and a clean up take every one out at once. The close takes the game's flags off, and so does putting New
-- items away by its title or by a clean up (Bags.ClearNew, Bags.lua), so the next change of a slot does not bring its item back. With New items
-- at the top off, nothing is kept as new.
--
-- Junk is Errands' own test, so the Junk section, the junk coin and Sell junk agree on what is junk. A live slot of the bags is junk when Errands
-- would sell it (ns.ErrandsJunk: the sale test of ErrandsMerchant.lua:178-203, with the bags the game's menu leaves out of junk selling,
-- :167-176), asked whatever its lock (its third argument): an item the game holds for a moment, in the trade window, on a mail not sent yet or on
-- the cursor, keeps its coin and its place in Junk, while Sell junk counts and sells only the unlocked ones. The keyring never is: Errands walks
-- bags 0 to NUM_TOTAL_EQUIPPED_BAG_SLOTS only (:113-120). The bank and every item of another character, which nothing can sell from where they
-- are, take the list part of that test (ns.ErrandsJunkRule, :189-192): on the sell list, or grey and not on the keep list, and never an item with
-- no value or a quest item. Junk is tried right after New items, so a new junk item stays in New items with its coin until the bags close, and
-- nothing Sell junk sells is filed anywhere else.
--
-- Placement by hand: an item dropped on the title of a section stays in that section, by item ID, for the whole account, in FlatUIDB.bags.placed
-- (at most MOST_PLACED items). A drop reads the cursor (GetCursorInfo, and C_Cursor.GetCursorItem for the slot the item came from,
-- CursorDocumentation.lua:11-19, read from the fields of its ItemLocation, Blizzard_ObjectAPI/Mainline/ItemLocation.lua:35-44) and gives the
-- item back to its slot with ClearCursor. Dropped on Junk, the item goes on Errands' sell list; an item of Junk dropped on another section comes
-- off the sell list, and a grey one goes on the keep list (ns.ErrandsJunkMark), as /flatui sell and /flatui keep put them there and take them off
-- (ErrandsMerchant.lua:824-848): a placement of Flat UI's own in or out of Junk would make the section and the selling disagree. While Junk is
-- hidden no drop changes the lists, since its items show in other sections then (DropOn). Whether a dropped item is of Junk is the test of its
-- slot for a slot of the bags (Categories.IsJunk), so a grey item of a bag left out of junk selling, which is not in Junk, goes on no list; for
-- the bank, and an item whose slot the game does not say, it is the two lists (ns.ErrandsJunkRule). An item the game gives no value, or no sell
-- price (C_Item.GetItemInfo, ItemDocumentation.lua:626-657), and a quest item cannot go in Junk, since Errands never sells them. Dropped on the
-- section it reaches by itself, an item loses its placement. An item whose slot the game does not say is judged by its ID alone, with its quality
-- from C_Item.GetItemQualityByID. New items and Free slots take no drop, and no drop is taken in a fight (InCombatLockdown and
-- UnitAffectingCombat, through Errands.Fighting): the item only goes back. The lines said in chat name an item as Errands does, by
-- C_Item.GetItemNameByID and its ID. The row Items placed by hand lists the placements and takes one off, or, from its first line while two or
-- more are placed, every one; with none it says how to place an item.
-- Sections the player makes and names (keys custom1, custom2 and on, in FlatUIDB.bags.custom; B.Custom.Is, BagsCustom.lua) take placements too,
-- within the same MOST_PLACED; a placement in a section that is not there is skipped, and deleting a section of the player's own takes its
-- placements away. Categories.File is the same drop without the cursor, which BagsCustom calls for an item it put in a free slot of the bags and
-- for the item a new section is made for; Categories.Takes makes its tests without writing, so BagsCustom moves no item a section would refuse,
-- and says the same line, or, asked quietly while the cursor holds an item, gives the sentence a tooltip shows, so a + slot, a catcher or a title
-- that would refuse it stays unlit. Categories.Label names a section of the player's own by its name, so the windows, the rows and the search's
-- section words use it. Categories.PlacedCount and PutBack count and take away the placements of one section as the windows show it (a section
-- title's menu, BagsOrder.lua), and Categories.PlacedKey gives the section an item is placed in, which its tooltip in Flat UI's windows names
-- (BagsTooltip.lua) and the search's #placed finds (BagsSearch.lua). A put back asks nothing, so the placements the last one took away (PutBack, or
-- the first line of the row while two or more are placed) are kept in this file (lastBack, never saved) until the next put back or a reload:
-- Categories.Unput brings each back in the section it was saved in, but not one placed elsewhere since and none past MOST_PLACED, from the line
-- of that section title's menu and the first line of the row; an item the row puts back on its own leaves that record. Categories.PlaceAll places
-- many items at once, as many drops on a title would, with no cursor and no change to the sell or keep list: the line of a section title's menu
-- that places there every item the search finds; it is refused in a fight, as a drop is, and stops at MOST_PLACED with one line.
--
-- Inside a section, equipment sorts by the place of its slot in the Character window (Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:779-873),
-- then by item level (ns.Items.LevelOf, Items.lua:425-438), quality and name; everything else by class, subclass, quality, name and count. An item
-- whose name has not loaded sorts by its item ID after the named ones, and the last key is the bag and slot, so equal items never swap.

local KEY = "bags"
local B = ns.Bags
local Categories = B.Categories
local New = B.Categories.New
local Errands = ns.Errands
local Custom = B.Custom

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

-- The sections in the order they are shown; each: the label a section has while its group's row is at Each kind, where it holds less.
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
-- The rules after New items, Junk and placement, in the order they are tried; Other takes the rest.
local PRIORITY = { "set", "quest", "gear", "consumable", "trade", "reagent", "recipe", "ammo", "bag", "key" }
-- The sections the player cannot hide: the two shelves, and Other, which takes what no other section does.
local UNHIDEABLE = { new = true, free = true, other = true }
-- The three groups a row of the Sections part shows as one section or apart (see the top of the file). row: the row of the Bags page. base: the
-- section that is the group as One section, and its rest while it is split. each: the sections Each kind adds to the rest. kind: for the older
-- split of Equipment and Consumables, the section each kind goes to. slots, subs: a record's kind, by its equip slot first, else by its class and
-- subclass (any: every subclass), else the rest. claims: the kind of another class the group takes at Each kind, ahead of that class's own rule.
-- The slots are the equip slots of C_Item.GetItemInfoInstant (Camelot/PaperDollFrame.xml:779-873 names their places); the subclasses those of
-- Enum.ItemConsumableSubclass (enums.yaml:4694-4711), and for Trade goods, which Forever's enums do not list, the client's own (see the top).
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
		-- Potion 1, Elixir 2, Flasksphials 3, Scroll 4, Fooddrink 5, Itemenhancement 6, Bandage 7, Device 14, ItemenhancementTemporary 15; the
		-- Explosives 2 and Devices 3 of Trade goods.
		subs = { [CONSUMABLE] = { [1] = "potion", [2] = "elixir", [3] = "elixir", [4] = "scroll", [5] = "food", [6] = "enhance", [7] = "bandage",
			[14] = "explosive", [15] = "enhance" }, [TRADEGOODS] = { [2] = "explosive", [3] = "explosive" } },
		claims = "explosive" },
	-- Parts 1, Explosives 2, Devices 3, Cloth 5, Leather 6, Metal & Stone 7, Meat 8, Herb 9, Elemental 10, Enchanting 12; the rest (Trade Goods 0,
	-- Other 11, gems, item enhancements and profession items) stays in Trade goods.
	{ row = "tradeGoods", base = "trade", each = { "cloth", "leather", "metal", "herb", "elemental", "enchanting", "meat", "parts" },
		subs = { [TRADEGOODS] = { [1] = "parts", [2] = "parts", [3] = "parts", [5] = "cloth", [6] = "leather", [7] = "metal", [8] = "meat",
			[9] = "herb", [10] = "elemental", [12] = "enchanting" } } },
}
-- Per group, the section each of its keys goes to under each choice that splits it (to.kind, to.each; One section sends all to base), and per key
-- its group.
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
-- The place of each equip slot in the Character window, head to ranged (Camelot/PaperDollFrame.xml:779-873); a weapon for either hand goes with
-- the main hand, and anything else after the ranged slot.
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
	-- New items follows the game's flag and Free slots is empty space, so neither can hold an item by its ID; Junk is Errands' lists, and Keep in
	-- place this character's pinned slots.
	if section.key ~= "new" and section.key ~= "junk" and section.key ~= "free" and section.key ~= "keep" then
		PLACEABLE[section.key] = true
	end
end

-- True for a section that holds items placed by hand: one of PLACEABLE, or a section the player made (B.Custom.Is, BagsCustom.lua, looked up when
-- called).
local function Placeable(key)
	if PLACEABLE[key] then
		return true
	end
	local is = Custom.Is
	return type(key) == "string" and type(is) == "function" and is(key) == true
end

-- The same for BagsOrder.lua, which offers a title's menu line that places the items the search finds there only on such a section.
function Categories.Placeable(key)
	return Placeable(key) == true
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

-- Groups ---------------------------------------------------------------------------------------------------------------------------------

-- The choice of a group's row that splits it ("kind", "each"), or "one".
local function Mode(group)
	local value = Opt(group.row)
	if type(value) == "string" and group.to[value] then
		return value
	end
	return "one"
end

-- The kind of a record within its group: the section of its equip slot (slots), else of its class and subclass (subs), else the group's rest.
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

-- True for a record of another class the group takes at Each kind (claims: the explosives and devices of Trade goods with Consumables at Each kind).
local function Claims(group, record)
	return group.claims ~= nil and Mode(group) == "each" and KindOf(group, record) == group.claims
end

-- True when the group's row shows the section key now (its base alone at One section), hidden or not.
local function Shows(group, key)
	local to = group.to[Mode(group)]
	if not to then
		return key == group.base
	end
	return to[key] == key
end

-- The section a key of a group stands for under its row's choice: the base at One section; else the key itself where the choice shows it, a kind
-- the choice folds into another that one (Rings into Jewellery), and the base, reached by the rules or placed by hand where the choice does not show
-- it, the section of the record's own kind (KindOf). A kind the choice has not (Jewellery at Each kind) goes by the record's kind too. placed: an
-- item placed by hand in key, which keeps a base the choice shows (a potion dropped on Consumables stays there). A key of no group stays.
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

-- Hidden sections -----------------------------------------------------------------------------------------------------------------------

-- FlatUIDB.bags.hidden, { [key] = true }, or nil while none is hidden or the saved variables have not loaded.
local function HiddenSet()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local hidden = type(bags) == "table" and bags.hidden or nil
	if type(hidden) == "table" and next(hidden) ~= nil then
		return hidden
	end
	return nil
end

-- True for a section of Flat UI's own the player hid. A key of the set that is no such section (an old key, a section of the player's own, New
-- items, Free slots, Other) counts for nothing.
local function Hidden(key)
	if type(key) ~= "string" or not HIDEABLE[key] then
		return false
	end
	local hidden = HiddenSet()
	return hidden ~= nil and hidden[key] == true
end
Categories.Hidden = Hidden

-- True for a section the player may hide: every one of Flat UI's own but New items, Free slots and Other.
function Categories.Hideable(key)
	return type(key) == "string" and HIDEABLE[key] == true
end

-- True when the rows of the Sections part show the section key now: a section of a group under its row's choice, any other of Flat UI's own always.
function Categories.Exists(key)
	local group = type(key) == "string" and GROUP_OF[key] or nil
	if group then
		return Shows(group, key)
	end
	return type(key) == "string" and LABELS[key] ~= nil
end

-- The hidden sections in the order of SECTIONS; with now, only those the rows show now (Exists), which a hide changes the windows for.
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

-- The hidden sections as one text, for the layout's signature (BagsLayout.lua), so a change of them lays a window out afresh.
function Categories.HiddenSign()
	return table.concat(Categories.HiddenKeys(false), ",")
end

-- Hides the section key, or shows it again with on false; an empty set is not kept. Both windows are laid out again. True when it changed; false for
-- a section that cannot be hidden, or before the saved variables load.
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

-- Shows every hidden section again. True when one was hidden.
function Categories.ShowAll()
	local db = ns.Account()
	if not HiddenSet() or type(db) ~= "table" or type(db.bags) ~= "table" then
		return false
	end
	db.bags.hidden = nil
	Request("layout")
	return true
end

-- The row of the Bags page that shows the group of section key as one section or apart ("gear", "consumables", "tradeGoods"), or nil.
function Categories.GroupRow(key)
	local group = type(key) == "string" and GROUP_OF[key] or nil
	return group and group.row or nil
end

-- The base of the group of section key ("gear", "consumable", "trade") and true while its row splits it now (any choice but One section); nil for
-- a key of no group. The row Delete a section (BagsOrder.lua) asks it for the line that deletes a whole split group before its kinds.
function Categories.GroupBase(key)
	local group = type(key) == "string" and GROUP_OF[key] or nil
	if not group then
		return nil, false
	end
	return group.base, Mode(group) ~= "one"
end

-- Filing ---------------------------------------------------------------------------------------------------------------------------------

-- The section a record reaches by its own rules, after New items, Junk and placement: the first rule it meets (or its group claims it, Claims),
-- as its group's row shows it (Fit). A hidden section is passed by as if it were not there: a hidden kind of a split group falls to the section
-- that holds the group's rest under its row's choice (to[base]: Equipment at Each kind, Armour at Weapons, armour and jewellery, Consumables at
-- Food, potions and the rest) while that is not hidden too, else the next rule takes the record. Only a record of the group's own class falls
-- back: one the group only claims (the explosives and devices of Trade goods) goes on to its own class's rule, as it would with no such section.
-- Other, which cannot be hidden, takes the rest.
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

-- The sections, in the order they are shown: { key, label, order, test(record) }. A section with no item is not drawn, so every section of a group
-- is listed and Of files an item in the ones its row shows. A test with no record is true for Free slots alone. The base of a group tests the
-- group's whole rule (BagsSearch.lua's #trade reads it); another section of a group whether the group's rule files the record there under the row's
-- choice now, hidden or not.
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
		-- The label at Each kind (Potions), which BagsCustom.lua refuses as the name of a section of the player's own too.
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

-- The label of a section: Flat UI's own (its Each kind label while its group's row is at Each kind), else the name the player gave a section of
-- theirs (B.Custom.Name), else the key.
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

-- Junk -----------------------------------------------------------------------------------------------------------------------------------

-- Whether Sell junk would sell the item, by Errands' own test (see the top of the file). A live slot is asked whatever its lock (the third
-- argument of ns.ErrandsJunk), so an item the game holds for a moment keeps its coin and its section.
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

-- New items ------------------------------------------------------------------------------------------------------------------------------

-- By the key of an item (its GUID, else its bag, slot and ID): true while it is new. The items New items showed since the bag window last
-- opened, which leave it when the window closes. And the items whose game flag was set during a visit to a banker: what came out of the bank
-- keeps that flag after the visit, until the bag window closes, or a sort or a click on the title of New items takes the flags off while New items
-- at the top is on (Bags.lua), and it never becomes new on the flag alone meanwhile.
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

-- changed: { [bag] = { [slot] = true } }: the slots BagsData found changed at BAG_UPDATE_DELAYED, before it asks for the redraw, or the slots whose
-- game flag is set at BAG_NEW_ITEMS_UPDATED (BagsData.lua). A flagged item becomes new, unless the flag was set during a visit to a banker: it is
-- noted as banked then, and stays out.
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

-- The layout calls this for each record it draws in New items. True for a record that is new.
function New.Shown(record)
	if not New.Is(record) then
		return false
	end
	shown[NewKey(record)] = true
	return true
end

-- The bag window closed: what New items showed leaves it. The close took the game's flags off (Bags.HideGameBags), so nothing is banked now.
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

-- Every item leaves New items now: a click on its title, or a clean up. While New items at the top is on, Bags.ClearNew takes the game's flags off
-- before each, so nothing stays banked either; with the row off nothing is kept as new, the flags stay until the bags close, and so does what was
-- banked. The caller asks for the layout.
function New.Clear()
	Empty(fresh)
	Empty(shown)
	if Kept() then
		Empty(banked)
	end
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

-- The section a record was placed in, as its group's row shows it, or nil. A placement that is not a section that holds items is skipped, and so
-- is one in a section the player hid, until it is shown again.
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

-- The placements of the account: a new table { [itemID] = section key } of every valid one.
function Categories.Placed()
	local copy = {}
	for id, key in pairs(Store(false) or {}) do
		if Whole(id) and type(key) == "string" and Placeable(key) then
			copy[id] = key
		end
	end
	return copy
end

-- The section a record is placed in by hand, as the windows show it (the Equipment and Consumables rows, Fit), or nil; a bare item ID is judged
-- by its ID alone. The tooltip of an item in Flat UI's windows says so when the item shows there (BagsTooltip.lua).
function Categories.PlacedKey(record)
	if Whole(record) then
		record = { id = record }
	end
	if type(record) ~= "table" then
		return nil
	end
	return PlacedIn(record)
end

-- The item IDs placed by hand in a section as the windows show it (a placement on Weapons counts for Equipment while the Equipment row shows
-- one section), in a new list.
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

-- How many items are placed by hand in a section, for the line of its title's menu and its tooltip (BagsOrder.lua).
function Categories.PlacedCount(key)
	return #PlacedHere(key)
end

-- The placements the last put back took away, for Unput: { key (the section as the windows showed it, nil for every section, from the row Items
-- placed by hand), placed = { [itemID] = the section key that was saved }, count }. Never saved: it lasts until the next put back or a reload.
local lastBack = nil

-- What a put back takes, read before it.
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

-- Puts every item placed by hand in a section back in its own section, and asks for the layout once: how many went. Unput brings them back.
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

-- How many placements the last put back took away (0 when there is none to bring back), and the section it was of (nil for every section).
function Categories.LastPutBack()
	if not lastBack then
		return 0, nil
	end
	return lastBack.count, lastBack.key
end

-- Brings back the placements the last put back took away, each in the section it was saved in, but not one placed elsewhere since (that keeps its
-- new place) and none past MOST_PLACED (Categories.Place). Asks for the layout once. Returns how many came back, how many were taken, and the
-- section key of the put back (nil for every section).
function Categories.Unput()
	local last = lastBack
	if not last then
		return 0, 0, nil
	end
	lastBack = nil
	local back = 0
	for id, saved in pairs(last.placed) do
		local placed = Store(false)
		if not placed or placed[id] == nil then
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

-- Keeps an item in a section, or takes its placement away with no key. Returns true, or false and why: "id", "key", "saved" (the saved
-- variables are not loaded) or "full" (MOST_PLACED items are placed already).
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

-- Whether a dropped item is an item of Junk, which a drop on another section takes off the lists: for a slot of the bags (not the keyring) the
-- slot's own test (Categories.IsJunk, whatever its lock, so the item held on the cursor is judged as it lies), which leaves a grey item of a bag the
-- game's menu leaves out of junk selling outside Junk; for the bank, or an item whose slot the game does not say, the two lists (ns.ErrandsJunkRule).
local function DroppedJunk(id, record)
	local bag = Whole(record.bag)
	if record.live == true and bag ~= nil and bag ~= KEYRING and BAGS[bag] then
		return Categories.IsJunk(record) == true
	end
	local rule = ns.ErrandsJunkRule
	if type(rule) ~= "function" then
		return false
	end
	local quality = ns.Finite(record.quality) and record.quality or nil
	return rule(id, quality, Unsellable(record, Text(record.link)), Quest(record)) == true
end

-- A drop on another section: an item of Junk leaves the lists first, then the item is kept there, or loses its placement when that is the
-- section it reaches by itself. True when either changed what the window shows. While Junk is hidden its items show in other sections, so a drop
-- between them leaves the lists as they are: hiding Junk changes no selling.
local function DropOn(key, id, record)
	local mark = ns.ErrandsJunkMark
	local unlisted = false
	if type(mark) == "function" and not Hidden("junk") and DroppedJunk(id, record) then
		mark(id, false)
		unlisted = true
	end
	local done, why = Categories.Place(id, key ~= Rules(record) and key or nil)
	if not done and why == "full" then
		Say(("%d items are placed by hand already. Take one off with Items placed by hand on the Bags page first."):format(MOST_PLACED))
	end
	return done or unlisted
end

-- The drop without the cursor: keeps item id in section key as a drop on its title does, but gives nothing back. link, bag, slot: what the caller
-- read of the item and where it lies now (its record is read there, else the item is judged by its ID). BagsCustom.lua calls it for an item it put
-- in a free slot of the bags and for the item a new section is made for. True when taken; the layout is asked for then.
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

-- What Categories.Takes says of a refusal: the line in chat, and with quiet the sentence a tooltip shows in its place (BagsCustom.lua).
local REFUSALS = {
	fight = { "Items are not placed in sections in a fight. Try again once it is over.", "Items are not placed in sections in a fight." },
	quest = { "%s is a quest item, and quest items are never sold.", "Quest items are never sold." },
	list = { "Junk takes no items: this build of Flat UI cannot write the sell list.", "This build of Flat UI cannot write the sell list." },
	unsold = { "%s cannot be sold, so it does not go in Junk.", "This item cannot be sold, so it does not go in Junk." },
	full = { "%d items are placed by hand already. Take one off with Items placed by hand on the Bags page first.",
		"%d items are placed by hand already. Put some back first." },
}

-- Whether section key would take item id, changing nothing: the tests Categories.File makes before it writes (Junk takes no quest item and none
-- that cannot be sold; another section no new placement past MOST_PLACED, unless it is the section the item reaches by itself), saying the same
-- line on a refusal. BagsCustom.lua asks it before it moves an item from the bank, worn gear or a merchant into the bags, so a drop refused moves
-- nothing. True when the section would take it. With quiet nothing is said: a refusal gives false and the sentence a tooltip shows (REFUSALS),
-- which BagsCustom.lua asks while the cursor holds an item, so a + slot, a catcher or a title that would refuse it stays unlit.
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
	local placed = Store(false)
	if key ~= Rules(record) and not (placed and placed[id] ~= nil) then
		local count = 0
		for _ in pairs(placed or {}) do
			count = count + 1
		end
		if count >= MOST_PLACED then
			return Refuse("full", MOST_PLACED)
		end
	end
	return true
end

-- A click or drop on the title of a section while the cursor holds an item. id: the item ID the caller read, or nil to read the cursor here;
-- the cursor is what counts. The item always goes back to its slot. True when the drop was taken.
function Categories.Drop(id, key)
	local held, link, bag, slot = Held()
	if not held then
		return false
	end
	local taken = Categories.File(held, key, link, bag, slot)
	GiveBack()
	return taken
end

-- Places every item of records in section key at once, each as a drop on its title places one (a section an item reaches by itself takes its
-- placement away instead), with no cursor and no change to the sell or keep list: the line of a title's menu that places there the items the search
-- finds (BagsOrder.lua), which leaves out the items of New items, Junk and Keep in place. records: the records the window shows, or bare item IDs;
-- each item ID counts once. Refused in a fight, as a drop is, and stops at MOST_PLACED, each with one line in chat. Asks for the layout once.
-- Returns how many were placed.
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
			local done, why = Categories.Place(id, key ~= Rules(record) and key or nil)
			if done then
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

-- Filing and order -----------------------------------------------------------------------------------------------------------------------

-- The section a record is shown in: New items, then Junk, then Keep in place (a record in the slot pinned for it, B.Pins.Of), then its placement,
-- then the built-in rules. No record is a free slot. Junk and Keep in place hidden only change where their items show: the junk test, the sell
-- list and the pins stay as they are.
function Categories.Of(record)
	if type(record) ~= "table" then
		return "free"
	end
	if New.Is(record) then
		return "new"
	end
	if not Hidden("junk") and Categories.IsJunk(record) then
		return "junk"
	end
	if record.live == true and not Hidden("keep") then
		local of = B.Pins and B.Pins.Of
		if type(of) == "function" then
			local ok, pinned = pcall(of, record)
			if ok and pinned == true then
				return "keep"
			end
		end
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

local PLACED_ALL = "Put every item back in its own section"
local PLACED_NONE = "No item is placed by hand. Drop an item from your bags on a section's title to keep it there."
-- The line that brings back what the last put back took away (Categories.Unput), for every section and for one, and what it says.
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

-- Every placement, by the name of its item: { { itemID, "Name (ID): Section" }, ... }, "(deleted)" after a section the player hid, after a line that
-- takes them all off while two or more are placed, as Folded sections and Pinned slots have; with none, one line that says how to place one. While
-- the last put back can be brought back (a section title's menu or the line that takes them all off here), its line comes first.
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

-- Takes one placement off, or every one ("all"), or brings back what the last put back took away ("undo"), with the page on or off; a window that
-- shows is laid out again.
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
	-- Put back on its own, it is not brought back with the last put back.
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
