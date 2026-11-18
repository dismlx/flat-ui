local _, ns = ...

-- Bags data: what the bag and bank windows of Bags show, and the record the account keeps of each character's bags, bank, worn items and gold, so
-- that the bank and the other characters can be shown away from the banker and counted in item tooltips. Bags.lua is the module and makes ns.Bags
-- with every sub-table; this file only adds the fields of ns.Bags.Data, and two functions of ns for the row Forget a character. It hears its events
-- on the module (ns.AddEvent, Core.lua:2093-2141), and each handler runs as the part cache of the module (B.Part, a fresh key per call as
-- Errands.Run does, Errands.lua:212-227), so a failure counts against this part alone. Nothing else tells the windows that the bags changed, so
-- cache is one of the parts Bags cannot do without (Bags.lua): when it stops, both windows hide and the game's bags come back. The tooltip index
-- alone (below) is built as the part tooltips, the part of BagsTooltip.lua that it serves. It touches no frame, the game's or its own: it reads the
-- game, writes FlatUIDB.bags, and looks up the other parts of Bags and the functions of Core.lua when it calls them, never at load.
--
-- The record. FlatUIDB.bags is account data outside every profile, made only while the module is on, as FlatUIDB.datapanels is
-- (DataPanels.lua:193-212). v is its layout, 1; a store of another layout starts its characters again and keeps placed, the hand placements of
-- BagsCategories.lua. chars holds each character by "Name - Realm" (ns.CharacterKey, Core.lua:2704-2707): realm (GetNormalizedRealmName,
-- PlayerScriptDocumentation.lua:651-658), class (UnitClassBase, UnitDocumentation.lua:930-946), faction (UnitFactionGroup, :1207-1222), level
-- (UnitLevel, :2474-2487), money (GetMoney, PlayerScriptDocumentation.lua:642-649), seen and bankSeen (time() of the last write of the bags or the
-- gold, and of the bank), bags (containers 0 to 5, and -1 while the game shows the keyring), bank (the bought tabs, 6 to 14), bagItems (the item ID
-- of the bag in bag slots 1 to 5), bankItems (of the bag in bank bag slots 2 to 9) and worn (the item IDs in inventory slots 1 to 19,
-- GetInventoryItemID, in the client's apis.yaml with no documentation). A container is { n = its slots, f = the family of its bag when not 0,
-- [slot] = text } with every empty slot absent, and a text is Flat UI's own: <itemID>[*<count>][#<quality>][~<flags>][@<item>]. The count is
-- written only above 1; the flags are b bound, q quest item, s starts a quest, e in an equipment set and n no value; the item is fields 1 to 8 of
-- the link (ID, enchant, four gems, suffix, unique ID), written only when one of 2 to 8 is not empty or 0 and read back with a sign allowed, since a
-- random suffix is negative. A text that would pass 80 characters keeps no item fields. Nothing secret is written: every answer goes through
-- ns.IsSecret or ns.Finite first and a withheld one counts as none. A character that is not a table, a key that is not a string and a text that
-- does not parse are skipped when read, never raised.
--
-- When it is written, by the events this file owns, in this order (the module hears them only while it is on, Core.lua:3504-3512):
-- PLAYER_ENTERING_WORLD (SystemDocumentation.lua:136), the module's Start (ns.AddStart, Core.lua:2186-2199), and B.Data.Resume, which Bags.lua
-- calls when the page comes on again after Start (Core then runs Refresh and not Start, Core.lua:2278-2287, and the module heard nothing while the
-- page was off): the keyring test and the kinds of the bags are read again, and the realm, class, faction, level, gold, worn items and bag items
-- written; a full scan of the bags, and of the bank's tabs while the bank is open, then waits for the next BAG_UPDATE_DELAYED, and runs FULL_WAIT
-- seconds later when none comes. After B.Data.Resume that scan is followed by a read of the quest marks and the set of every slot (Remark, below):
-- the scan reads them only for a slot whose item changed, and the events that tell of them went unheard while the page was off too.
-- BAG_UPDATE (ContainerDocumentation.lua:661) only marks its container. BAG_UPDATE_DELAYED (:677, one after a batch of changes) scans the
-- marked containers, and every bag when the last full scan is SWEEP seconds old, which also catches up a change no BAG_UPDATE marked (the bank is
-- read in full at each open instead). A slot counts as changed when its item, link, count, lock or quality changed, and its text is written when
-- its item, link, count, quality or binding changed. Bags is then told, in this order: B.Categories.New.Seen(changed) with the changed slots of the
-- bags, B.Request("items", "bags", changed) and the footer of the bags, and while the bank is open (or in the grace after its close, below)
-- B.Request("items", "bank", changed) and the footer of the bank, and B.Request("layout", "bank") when a bank bag slot changed what the tabs are
-- or, while the bank is open, a tab's size changed (a tab just bought, whose slots the client may give only after the layout that read it).
-- BAG_CONTAINER_UPDATE (:623, a bag put in or taken out) reads the keyring test, the kinds and the bag items again, flags a full scan, and calls
-- B.Buttons.Prepare with the bags' containers and B.Request("layout", "bags"); while the bank is open it reads the bank's tabs again too and asks
-- B.Request("layout", "bank"). BAG_NEW_ITEMS_UPDATED (:629; the game's bag windows draw again on it, Mainline/ContainerFrame.lua:611-612) comes
-- when new flags were set or taken off, and the game may set an item's flag after the BAG_UPDATE_DELAYED that brought it: on the next frame, once
-- for a run of them, the slots of my bags whose flag is set (C_NewItems.IsNewItem, NewItemsDocumentation.lua:15-28) go to
-- B.Categories.New.Seen and B.Request("items", "bags", ...), except during a sort hold of the bags (B.Sorting of Bags.lua), whose moves bring
-- nothing new. QUEST_ACCEPTED (QuestLogDocumentation.lua:1312) and UNIT_QUEST_LOG_CHANGED for the player
-- (UnitDocumentation.lua:4565), on which the game draws its quest marks again
-- (Mainline/ContainerFrame.lua:613-619), read the quest info of my slots again, at most once a second; EQUIPMENT_SETS_CHANGED
-- (EquipmentManagerDocumentation.lua:308) reads the set of each slot again; a change of either is written and asks B.Request("items").
-- GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT (ItemDocumentation.lua:1815, 1857) fill in the records that waited for an item's name, and for
-- an item B.Data.Want asked for call B.Request("items") and B.Request("search"). PLAYER_MONEY (CurrencyInfoDocumentation.lua:637) writes the gold,
-- and PLAYER_LOGOUT (SystemDocumentation.lua:159), heard only while the page is on, writes the gold, the worn items and the bag items once more as
-- a last refresh, which also catches a change whose event failed or that came while this part was stopped (what changed while the page was off was
-- read again by B.Data.Resume when it came back on, and nothing is written while it stays off); both ask B.Request("footer", "bags").
-- PLAYER_LEVEL_UP (UnitDocumentation.lua:3832) writes the level from its own value, which UnitLevel may not count yet; PLAYER_EQUIPMENT_CHANGED
-- (PaperDollInfoDocumentation.lua:386) writes the worn item of its slot. The other parts are told only while Bags is in use (B.On: on, not
-- stopped and not stood down for another bag addon or the gamepad interface); the record is kept all the same.
--
-- The bank is read only while it is open, as the game reads it only while its panel shows (Mainline/BankFrameTemplates.lua:622-630): BagsBank.lua
-- calls B.Data.BankScan at the open, B.Data.BankTabs when the tabs or the bank's bag slots change (it reads them again, has every tab scanned at
-- the next BAG_UPDATE_DELAYED, and says whether they changed, which needs a new layout of the bank window), and B.Data.BankClosed at the close,
-- which ends the live reading and dates the snapshot (bankSeen), except for a close the module did not hear (Bank.Settle, when the page comes up),
-- whose snapshot keeps the date of its last write. A move sent just before a close may be answered after it, so for GRACE seconds after a close
-- it heard the tabs a BAG_UPDATE marks are still read at BAG_UPDATE_DELAYED, slot by slot against what the visit read; a tab the client then gives
-- no slots, or no item at all where the visit read some, is no answer and keeps its snapshot, since the client may drop the bank's items at the
-- close. The bought tabs are C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character) (BankDocumentation.lua:256-269): tab 6 is the
-- bank's own slots and tab 5 + n the bag in bank bag slot n, the item at (Enum.BagIndex.Characterbanktab, n) (C_Container.GetContainerItemID,
-- ContainerDocumentation.lua:175-190; Camelot/BankFrame.lua:136-191, 312-319). The items in a tab change with BAG_UPDATE of the tab
-- (Mainline/BankFrameTemplates.lua:791-795) and are written as they change, so a visit that ends in a disconnect is kept. A tab the game gives no
-- slots while its bag slot holds a bag, or the first tab with none, has not been answered yet, and its snapshot stays. A bank left open while the
-- page was off ends once the game says the player no longer deals with a banker (C_PlayerInteractionManager.IsInteractingWithNpcOfType with
-- Banker, CharacterBanker and AccountBanker, apis.yaml and enums.yaml of the client).
--
-- Reading the game. A slot of mine is C_Container.GetContainerItemInfo (ContainerDocumentation.lua:192-207, its fields :766-783); its quest marks
-- GetContainerItemQuestInfo (:281-295, :817-825), read as the game draws "!" for a quest not taken yet and a border for a quest item
-- (Mainline/ContainerFrame.lua:1866-1876), with an item of class 12 a quest item too; its set GetContainerItemEquipmentSetInfo (:158-173); and its
-- GUID C_Item.GetItemGUID (ItemDocumentation.lua:501-514) on an ItemLocation from the game's own constructor (ItemLocation:CreateFromBagAndSlot,
-- Blizzard_ObjectAPI/Mainline/ItemLocation.lua:9-13), for the New items record of BagsCategories.lua. Sizes are GetContainerNumSlots (:313-326);
-- the family of a bag is the second answer of GetContainerNumFreeSlots (:297-311; 0 is a normal bag, and no family bit is named in this file,
-- since the client adds new ones); the bag in bag slot 1 to 5 is ContainerIDToInventoryID (:20-34) and GetInventoryItemID. The keyring counts
-- only while C_ActionBar.ShouldShowKeyring() (ActionBarFrameDocumentation.lua:987-995), the game's own test (Mainline/ContainerFrame.lua:10-12).
--
-- What it answers. B.Data.Item gives the record of a slot: live for this character's bags, and for its bank while the bank is open, else decoded
-- from the record, with the icon from C_Item.GetItemIconByID (ItemDocumentation.lua:611-624), the quality from GetItemQualityByID (:906-919) when
-- the text has none, and the link "item:" and the item fields or the ID. A record's name is the text of a link where there is one, which holds the
-- random suffix of an item ("of the Monkey") that its own name leaves out, so a search and the order of a section treat a live item and a kept one
-- alike: for a live slot its hyperlink, else its itemName, else GetItemNameByID (:846-859); for a kept text with item fields the whole link the
-- client makes of them (the second answer of C_Item.GetItemInfo, :626-657), asked only once C_Item.IsItemDataCachedByID (:1520-1533) says the
-- client has the item, else GetItemNameByID. A live record is kept per slot while its item, link, count, quality and binding stay, its lock read
-- anew at each call; a decoded one while something holds it.
-- B.Data.Info is C_Item.GetItemInfoInstant (:659-679), kept per item ID. B.Data.Want asks C_Item.RequestLoadItemDataByID (:1710-1718) once a
-- session for an item a window shows with no name; the record decoder, the picker's counts and the tooltip index never ask. The kind of a bag is
-- its item's class and subclass from the instant info, named by C_Item.GetItemSubClassInfo (:1020-1036); the backpack, the keyring and the bank's
-- own slots take the game's words (BACKPACK_TOOLTIP and KEYRING, Mainline/ContainerFrame.lua:2072, 2077; BANK, Mainline/BankFrameTemplates.lua:41),
-- and bag 5 is the reagent bag. B.Data.Characters lists every character kept, and this one with the game's answers. A character is near when its
-- realm is this one's or one the client names as connected (C_AutoComplete.GetAutoCompleteRealms, AutoCompleteDocumentation.lua:26-33), or, kept
-- with no realm, when its key ends in this character's realm. The tooltip index of B.Data.Counts holds the bags, bank and worn items of the near
-- characters other than this one by item ID. It is built the first time a tooltip asks, INDEX_STEP slots a frame (C_Timer.After), each step as the
-- part tooltips (so an index that keeps failing stops the counts alone), and kept for the session, since the others do not change while this one
-- plays; Forget, or connected realms the client names later, have it built again.
--
-- Forget a character (ns.BagsCharacterLines and ns.BagsCharacterForget, a list row as Forget a character's gold is, DataStreams.lua:239-257, its
-- ids numbers as the game's options need, Options.lua:165-195) takes a character out of the record; this character is then not written again
-- until it logs in again. /flatui status (ns.AddStatus, Core.lua:2143-2165) says how many characters and items are kept and how old this
-- character's bank is, and warns above MANY characters.

local KEY = "bags"
local PART = "cache"
-- The part of Counts in tooltips (BagsTooltip.lua), which builds the tooltip index.
local TIPS = "tooltips"
local B = ns.Bags
-- Bags.lua makes ns.Bags and its sub-tables before this file loads; without them there is nothing to fill.
if type(B) ~= "table" or type(B.Data) ~= "table" then
	return
end
local Data = B.Data

-- The layout of FlatUIDB.bags.
local LAYOUT = 1
-- Containers (Enum.BagIndex in the client's enums.yaml): the keyring, the backpack, the reagent bag, the first and last tab of the character bank,
-- and the holder of the bank's bag slots, whose slot n holds the bag of tab TAB_OF_SLOT + n (Camelot/BankFrame.lua:312-319).
local KEYRING, BACKPACK, REAGENT = -1, 0, 5
local FIRST_TAB, LAST_TAB, BANK_BAGS, TAB_OF_SLOT = 6, 14, -2, 5
local LAST_WORN = 19
-- A text of a slot keeps no item fields when it would be longer than this.
local MAX_TEXT = 80
-- The fields of a link kept: ID, enchant, four gems, suffix and unique ID.
local ITEM_FIELDS = 8
-- No container holds more slots; a size above it is bad data.
local MAX_SLOTS = 255
-- Slots of the record read into the tooltip index in one frame.
local INDEX_STEP = 2000
-- Seconds: quest marks are read at most this often; a flagged full scan runs this long after its flag when no BAG_UPDATE_DELAYED comes; every
-- bag is scanned again when the last full scan is this old; the client is asked again for connected realms it did not name.
local QUEST_EVERY, FULL_WAIT, SWEEP, REALMS_AGAIN = 1, 2, 60, 60
-- Seconds the bank's tabs are still read after a close, for a move the server answers after it.
local GRACE = 2
local DAY = 86400
-- /flatui status warns above this many characters kept.
local MANY = 40
-- Enum.ItemClass.Questitem.
local QUEST_CLASS = 12
local SECTIONS = { "bags", "bagItems", "bank", "bankItems", "worn" }
local WINDOWS = { "bags", "bank" }
-- Enum.BankType.Character, and Enum.PlayerInteractionType Banker, CharacterBanker and AccountBanker, in the client's enums.yaml, for a client
-- whose Enum does not say.
local CHARACTER_BANK = 0
local BANKERS = { { "Banker", 8 }, { "CharacterBanker", 67 }, { "AccountBanker", 68 } }
local REAGENT_WORD, BAG_WORD, BAGS_WORD = "Reagent bag", "Bag", "Bags"
local EMPTY = {}
local WEAK_VALUES, WEAK_KEYS = { __mode = "v" }, { __mode = "k" }

-- What the last scan read of each container of mine, to tell which slots changed: last[bag] = { n = slots, [slot] = { id, link, count, quality,
-- locked, bound, noValue, class, quest, start, set } }. Made afresh each session, and for the bank at each visit.
local last = {}
-- dirty[container] from BAG_UPDATE until the next scan.
local dirty = {}
-- A full scan of the bags or of the bank's tabs waits for the next BAG_UPDATE_DELAYED; fullTimer while the fallback wait runs; sweptAt is when
-- (GetTime) the last full scan of the bags ran. The first scan of a session is a full one.
local full, bankFull, fullTimer, sweptAt = true, false, false, nil
-- The bank is open, from B.Data.BankScan to B.Data.BankClosed, and liveTabs are its bought tabs; tabsSign is those tabs and the bags in them as
-- last read ("6,7:4500,8:0"), to tell whether they changed.
local bankLive, liveTabs, tabsSign = false, {}, nil
-- The bank closed a moment ago (B.Data.BankClosed): { tabs = the visit's bought tabs } until GRACE seconds after the close, else nil. What the
-- visit read of those tabs (last) and their marks (dirty) are kept meanwhile.
local grace
-- Whether the game shows the keyring (nil until asked), the kinds of my containers, and the live records of my slots: live[bag][slot].
local keyring
local kinds, live = {}, {}
-- Records decoded from the record, decoded[key][bag][slot], while something holds them, and the text each came from.
local decoded = {}
local textOf = setmetatable({}, WEAK_KEYS)
-- Instant info per item ID; items asked to load once a session and those still pending; records that wait for an item's name or quality.
local infos, asked, pending, waiting = {}, {}, {}, {}
-- The tooltip index: index[itemID][key] = { bags, bank, worn }, who[key] = { class, name, realm }, and whether it was built before the client named
-- connected realms. building is the index being built; generation tells the steps of an index that was dropped.
local index, who, builtWithout, building
local generation = 0
-- My realm without spaces, the set of connected realms once the client names any, and when it was last asked.
local myRealm, connected, realmsAt
-- Quest marks: when they were last read, and whether a read waits. remarkAll: B.Data.Resume ran, and the next full scan reads the quest marks and
-- the set of every slot again.
local questAt, questQueued = nil, false
local remarkAll = false
-- Forget a character took this one out: nothing of it is written again this session.
local muted = false

-- Helpers ----------------------------------------------------------------------------------------------------------------------------------------

-- ns.IsSecret and ns.Finite of Core.lua, looked up when called.
local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

-- A function of the client: a global (space nil), or a field of one of its namespaces such as C_Container; nil when this client has none.
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

-- The first answer of a call: nil when the client lacks the call, when it raises, or when it withholds the answer.
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

-- The first two answers, each nil when withheld.
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

-- A whole number the client gave (an ID, a count, a container), or nil.
local function Whole(value)
	if Finite(value) and value % 1 == 0 then
		return value
	end
	return nil
end

-- A whole number that is not negative, or nil.
local function Count(value)
	value = Whole(value)
	if value ~= nil and value >= 0 then
		return value
	end
	return nil
end

-- A text that is not empty, or nil.
local function Text(value)
	if IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

-- True only for a plain true.
local function Flag(value)
	return not IsSecret(value) and value == true
end

-- An icon: a file ID or a path, or nil.
local function Icon(value)
	if Finite(value) and value > 0 then
		return value
	end
	return Text(value)
end

-- A container this file reads (the keyring, the backpack, the four bags, the reagent bag, the tabs of the character bank), or nil.
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

-- The containers a character carries: the keyring, the backpack, the bags and the reagent bag.
local function Held(bag)
	return bag == KEYRING or (bag >= BACKPACK and bag <= REAGENT)
end

local function IsTab(bag)
	return bag >= FIRST_TAB and bag <= LAST_TAB
end

-- "Name - Realm" of this character, or nil when the client does not say.
local function Me()
	local key = ns.CharacterKey()
	if IsSecret(key) or type(key) ~= "string" or key == "" then
		return nil
	end
	return key
end

-- The time of day in seconds (time()), and the client's clock (GetTime) for waits.
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

-- Runs fn after the given seconds (C_Timer.After), or at once on a client with no timer.
local function After(seconds, fn)
	local timer = Client("C_Timer", "After")
	if not (timer and pcall(timer, seconds, fn)) then
		fn()
	end
end

-- The module is on and has not stopped: only then is the record written.
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

-- Bags shows its windows (B.On: on, not stopped and not stood down for another bag addon or the gamepad interface). Only then are the other parts
-- told of a change; while it is stood down the record is still kept.
local function Active()
	local on = B.On
	if type(on) ~= "function" then
		return false
	end
	local ok, yes = pcall(on)
	return ok and yes == true
end

-- Runs fn as the part cache of the module: B.Part, a fresh key per call, so each failure counts and a part that keeps failing stops alone.
local function Part(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(PART, fn, ...)
	end
	return ns.EachPart(KEY, PART, function(_, ...)
		return fn(...)
	end, {}, ...)
end

-- Runs fn as the part tooltips of the module, the part of Counts in tooltips that the tooltip index serves: an index that keeps failing stops the
-- counts alone, and the windows, which cannot do without this file's part cache, go on.
local function TipsPart(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(TIPS, fn, ...)
	end
	return ns.EachPart(KEY, TIPS, function(_, ...)
		return fn(...)
	end, {}, ...)
end

-- B.Request(flag, which, changed) of Bags.lua, looked up when it is called: the shown windows draw again on the next frame, once.
local function Request(flag, which, changed)
	local request = B.Request
	if type(request) == "function" then
		request(flag, which, changed)
	end
end

-- A word of the game's global strings, or the English one when the client has none.
local function Word(name, english)
	local word = _G[name]
	if IsSecret(word) or type(word) ~= "string" or word == "" then
		return english
	end
	return word
end

-- A value of the game's Enum (Enum.BankType.Character and so on), or the fallback when the client's Enum does not have it.
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

-- Items ------------------------------------------------------------------------------------------------------------------------------------------

-- { class, subclass, equipLoc, itype, isubtype, icon } of an item ID from C_Item.GetItemInfoInstant, which answers at once and never waits for the
-- server; kept per ID. Nil for an item the client does not know, asked again next time.
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

-- The item's name, quality and icon from what the client has loaded; nil until it has.
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

-- The name in the text of a link, "[Name]", which holds the random suffix of the item ("of the Monkey"), without the markup of an atlas the game
-- may put in it (|A...|a, Blizzard_SharedXMLBase/TextureUtil.lua:289-311).
local function LinkName(link)
	local name = link and link:match("|h%[(.-)%]|h")
	if not name then
		return nil
	end
	return Text((name:gsub("%s*|A.-|a", "")))
end

-- The texts of slots ---------------------------------------------------------------------------------------------------------------------------

-- Fields 1 to 8 of the item part of a link, or nil when 2 to 8 are all empty or 0, or when the link does not hold them as numbers. A field keeps
-- its sign: a random suffix is negative.
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

-- The text of a slot from what a scan read of it.
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

-- The item ID, count, quality (nil when not kept), flags and item fields (nil when not kept) of a text, or nil for a text that does not parse.
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

-- The record ---------------------------------------------------------------------------------------------------------------------------------------

-- FlatUIDB.bags, or nil before the saved variables load. Made, or started again for another layout, only with create, which only the writes of
-- this file ask for while the module is on; without it nil when there is none.
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

-- A character kept, or nil.
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

-- Who this character is, and its gold. A value the client withholds keeps the one written before.
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

-- This character's record: read with create false, and made with its tables with create true, which gives nil while nothing may be written.
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

-- The container table of a character's bag or tab, or nil.
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

-- Kinds of bag ---------------------------------------------------------------------------------------------------------------------------------

-- The item ID of the bag that makes a container of mine: the bag in bag slot 1 to 5, or the bag in the bank bag slot of a tab after the first.
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

-- kind = { id = the bag's item ID, label, family, class, subclass, key, name }. key groups free slots: "bag" for normal bags (family 0), "reagent",
-- "keyring", and one key per class and subclass of special bag (or per family when the item is not known). name is the bag item's name, when loaded.
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

-- The kind of a container of mine, read once and again after BAG_CONTAINER_UPDATE or a change of the bank's tabs.
local function LiveKind(bag)
	local kind = kinds[bag]
	if not kind then
		local _, family = Ask2(Client("C_Container", "GetContainerNumFreeSlots"), bag)
		kind = MakeKind(bag, LiveBagItem(bag), family)
		kinds[bag] = kind
	end
	return kind
end

-- The kind of a kept container, from the kept bag item and family.
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

-- Reading a slot -------------------------------------------------------------------------------------------------------------------------------

-- id, link, count, quality, locked, bound, noValue, icon, name and readable of a slot of mine; nothing for an empty slot.
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
		Icon(info.iconFileID), Text(info.itemName), Flag(info.isReadable)
end

-- quest: a quest item, an item that starts a quest, or an item of class 12; start: it starts a quest the player has not taken.
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

-- The GUID of the item in a slot of mine.
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

-- Records --------------------------------------------------------------------------------------------------------------------------------------

local function DropLive(bag, slot)
	local byBag = live[bag]
	if byBag then
		byBag[slot] = nil
	end
end

-- A decoded record that lacks its name or quality waits for its item to load.
local function Wait(rec)
	local list = waiting[rec.id]
	if not list then
		list = setmetatable({}, WEAK_KEYS)
		waiting[rec.id] = list
	end
	list[rec] = true
end

-- The name of a kept item as a live slot of it is named: the text of the whole link the client makes of the kept item fields (the second answer
-- of C_Item.GetItemInfo), which holds a random suffix that GetItemNameByID leaves out. It is asked only once C_Item.IsItemDataCachedByID says the
-- client has the item, so no decoded record asks for a load. Nil for a record that keeps no item fields.
local function KeptName(rec)
	if rec.link == "item:" .. rec.id or Ask(Client("C_Item", "IsItemDataCachedByID"), rec.id) ~= true then
		return nil
	end
	local _, link = Ask2(Client("C_Item", "GetItemInfo"), rec.link)
	return LinkName(Text(link))
end

-- Fills what the client has loaded since a decoded record was made.
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

-- The record of a slot of mine as the game has it now. It is kept while its item, link, count, quality and binding stay; its lock is read anew.
-- Its name is the text of its link before the slot's own itemName, so a random suffix is named as a kept record of the item names it (KeptName).
local function LiveRecord(key, bag, slot)
	local id, link, count, quality, locked, bound, noValue, icon, name, readable = ReadSlot(bag, slot)
	local byBag = live[bag]
	if not id then
		if byBag then
			byBag[slot] = nil
		end
		return nil
	end
	local rec = byBag and byBag[slot]
	if rec and rec.key == key and rec.id == id and rec.link == link and rec.count == count and rec.quality == quality and rec.bound == bound then
		rec.locked = locked
		-- A name the client loaded since (B.Data.Want, then B.Request("items")).
		if rec.name == nil then
			rec.name = LinkName(link) or name or ItemName(id)
		end
		return rec
	end
	rec = { key = key, bag = bag, slot = slot, live = true, id = id, count = count, quality = quality, link = link, icon = icon,
		name = LinkName(link) or name or ItemName(id), bound = bound, noValue = noValue, locked = locked, readable = readable }
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

-- The record of a kept slot, decoded from its text.
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

-- Scans ------------------------------------------------------------------------------------------------------------------------------------------

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

-- Reads one container of mine slot by slot. A slot whose item, link, count, lock or quality changed goes into changed[bag]; the text of a slot whose
-- item, link, count, quality or binding changed is written into into[bag] (my bags or bank in the record), and every text when the container is
-- read for the first time this session or its table is new. guard: a size of 0 is no answer, and the container is left as it was. True when the
-- size read differs from the last one this session read of the container (none read yet counts as 0 slots), so a tab whose slots the client
-- gives only after a layout read it as none is laid out again (Delayed).
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
		local id, link, count, quality, locked, bound, noValue = ReadSlot(bag, slot)
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
				or state.locked ~= locked
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
			state.locked = locked
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

-- Forgets what this session read of a container, and its kept table.
local function DropContainer(bag, into)
	last[bag], live[bag], kinds[bag] = nil, nil, nil
	if into then
		into[bag] = nil
	end
end

-- My bags, the marked ones or all; the keyring only while the game shows it.
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

-- The bought tabs of the bank, read while it is open. True when the client answered with a list, and then true again when the tabs or the bags in
-- the bank's bag slots differ from the last read.
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

-- The bags in the bank's bag slots, and no kept tab the bank no longer has.
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

-- The bank's tabs, the marked ones or all. The first tab, or a tab whose bag slot holds a bag, with no slots has not been answered yet. True when
-- the size of a tab changed (Scan): a tab just bought, or one whose slots the client gave only after the bank window was laid out.
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

-- Whether a tab of the visit still answers after the bank closed: the client gives it the slots the visit read, and an item in one of them unless the
-- visit read none there. The client may drop the bank's items at the close, so a tab with other slots, or with no item at all where the visit read
-- some, is no answer, and its snapshot stays.
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

-- The grace after a close: the tabs of the visit that a BAG_UPDATE marked since are read once more, slot by slot against what the visit read of them
-- (last, kept until the grace ends), for a move the server answered after the close.
local function GraceScan(record, changed)
	local into = record and record.bank
	for _, tab in ipairs(grace.tabs) do
		if dirty[tab] and Answers(tab) then
			Scan(tab, into, changed, true)
		end
	end
end

-- The player still deals with a banker. Only a plain no for each kind of banker, from a client that has the call, says the bank closed.
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

-- What a visit read of the bank's tabs is forgotten, and the grace after its close ends.
local function DropTabs()
	grace = nil
	for tab = FIRST_TAB, LAST_TAB do
		last[tab], live[tab], dirty[tab], kinds[tab] = nil, nil, nil, nil
	end
end

-- The bank is no longer read: what this visit read of it is forgotten, and its windows show the record.
local function EndBank()
	bankLive, bankFull, tabsSign = false, false, nil
	DropTabs()
end

-- Whether the bank is read live. A bank left open while the page was off, whose close the module never heard, ends here before anything of it
-- is read or written again, so a tab the game no longer answers for never wipes its snapshot.
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

-- Writes the text of a slot again after its quest marks or set changed.
local function Rewrite(record, bag, slot, state)
	local slots = record and SlotsOf(record, bag)
	if slots then
		slots[slot] = Encode(state)
	end
end

-- Realms ---------------------------------------------------------------------------------------------------------------------------------------

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

-- The realms the client names as connected to this one, a set; asked again a while later while it names none.
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

-- A character on this realm or a connected one: the only ones whose items can reach this character.
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

-- The tooltip index ----------------------------------------------------------------------------------------------------------------------------

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

-- Reads up to INDEX_STEP kept slots into the index being built, and the next ones on the next frame, each step as the part tooltips (TipsPart).
-- job.failed stays true when a step raises, or does not run because that part stopped.
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

-- Starts the index of the near characters other than this one; an account with no more than INDEX_STEP kept slots has it at once.
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

-- What the windows and tooltips ask ------------------------------------------------------------------------------------------------------------

-- { key, name, realm, class, faction, level, money, seen, bankSeen, me, near } of a character; realm is the realm in its key, as the game names it.
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

-- Every character kept, and this one, as its game answers, whether kept or not. This realm comes first with this character at its head, then the
-- connected realms and then the others, each realm by name and its characters by name.
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

-- The containers a window shows, in order: "bags" is 0 to 5, and -1 while the keyring shows (for another character, while it was kept); "bank" is
-- the bought tabs, live while my bank is open and else the kept ones. key nil is this character.
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

-- The slots of a container and its kind: live for my bags, and my tabs while the bank is open; else as kept (0 when nothing is kept).
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

-- The record of a slot, or nil for an empty slot: live for my bags, and my tabs while the bank is open; else decoded from the record.
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

-- The free slots of a live container, and the first one.
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

-- The free slots of a kept container, and the first one.
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

-- The free slots of a window, one row per kind of bag in the order the kinds first come: { kind, label, free, total, bag, slot }, bag and slot
-- being the first free slot of that kind. Normal bags are one row, labelled Bags, or Bank in the bank.
function Data.Free(key, which)
	local me = Me()
	if key == me then
		key = nil
	end
	local rows, groups = {}, {}
	for _, bag in ipairs(Data.Containers(which, key)) do
		local size, kind = Data.Size(key, bag)
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
					group = { kind = { key = "bag", family = 0, label = label }, label = label, free = 0, total = 0 }
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
	return rows
end

-- A character's gold in copper: mine as the game says, else as kept; nil when unknown.
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

-- Asks the game once a session to load an item a window shows with no name, and notes it as pending until ITEM_DATA_LOAD_RESULT or
-- GET_ITEM_INFO_RECEIVED.
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

-- { { key, class, bags, bank, worn, name, realm } ... } of the near characters other than this one that carry an item, the most first. Nothing
-- while the index is being built.
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

-- The bank opened (BagsBank.lua, at BANKFRAME_OPENED, as this part): it is read live from now on and its tabs are read at once, since the windows
-- ask for them; what is left of a visit before, its grace included, is forgotten first. Every tab is written now and scanned again at the next
-- BAG_UPDATE_DELAYED, in case the game had not given them all yet.
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

-- The bank closed (BagsBank.lua, once a visit): it is no longer read live, so its windows show the record, and the snapshot is dated. A move sent
-- just before the close may be answered after it, so for GRACE seconds the tabs a BAG_UPDATE marks are still read at BAG_UPDATE_DELAYED (Delayed,
-- GraceScan) against what the visit read of them, which is forgotten when the grace ends (DropTabs). late: a close the module did not hear
-- (Bank.Settle, when the page comes up): nothing of the bank is read again, and the snapshot keeps the date of its last write, which is no later
-- than what it holds.
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

-- The bank's tabs or its bag slots changed (BagsBank.lua, at PLAYERBANKSLOTS_CHANGED and BANK_TABS_CHANGED): the bought tabs and the bags in the
-- bank's bag slots are read again, and every tab is scanned at the next BAG_UPDATE_DELAYED, which tells the bank window the slots that changed and
-- marks the time of a change for a sort hold; a scan here would take those changes in unseen. True when the bought tabs or the bags in them
-- changed, so the bank window needs a new layout.
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

-- Takes a character out of the record. This character is then not written again until its next login; a window that showed the character
-- shows this one again.
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

-- The other parts, by name ---------------------------------------------------------------------------------------------------------------------

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

-- Events -----------------------------------------------------------------------------------------------------------------------------------------

-- After B.Data.Resume: the quest marks and the set of every slot of mine read again (below, with Remark).
local RemarkAll

-- BAG_UPDATE_DELAYED: scans the marked containers (all of them after a flag, or when the last full scan is SWEEP seconds old), and in the grace
-- after a close the marked tabs of the visit, writes the record, and tells New items and the windows what changed; while the bank is open, a
-- change of the tabs or of a tab's size lays the bank window out afresh.
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
	-- The bank is read in full at each open, so the sweep leaves it alone.
	if BankOpen() then
		if dirty[BANK_BAGS] then
			-- A bag went in or out of a bank bag slot: when the tabs or the bags in them changed since the last read, the bank window needs a new
			-- layout, also when the client named the bag only after PLAYERBANKSLOTS_CHANGED.
			local answered, moved = ReadTabs()
			if answered and record then
				WriteBank(record)
			end
			tabsMoved = moved == true
			bankFull = true
		end
		local tabs = bankFull
		bankFull = false
		-- A tab whose size changed needs a new layout as well: the layout read each tab's size once, and the client may give the slots of a tab
		-- (one just bought with the Buy button of BagsBank.lua) only after that.
		if ScanBank(record, bank, tabs) then
			tabsMoved = true
		end
		if record and next(bank) ~= nil then
			record.bankSeen = Now() or record.bankSeen
		end
	elseif grace then
		-- The bank closed a moment ago: a move answered after the close is written to the tab it went in or came out of too.
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
		-- Once every slot is read after B.Data.Resume, also while Bags stands down (Remark asks the windows only while it is in use).
		remarkAll = false
		RemarkAll()
	end
	if not Active() then
		return
	end
	if next(bags) ~= nil then
		Part(NewSeen, bags)
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

-- A full scan of the bags waits for the next BAG_UPDATE_DELAYED, or runs FULL_WAIT seconds from now when none has come by then.
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

-- The module's Start, PLAYER_ENTERING_WORLD and B.Data.Resume: who this character is, its gold, worn items and bags, then a full scan of the bags,
-- and of the bank's tabs while the bank is open.
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

-- BAG_CONTAINER_UPDATE: a bag went in or out of a bag slot, or of a bank bag slot.
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

-- BAG_NEW_ITEMS_UPDATED waits for the next frame, once for a run of them.
local newQueued = false

-- The game set or took off new flags, and it may set one after the BAG_UPDATE_DELAYED that brought the item: every slot of my bags whose flag is
-- set (C_NewItems.IsNewItem) goes to New items (B.Categories.New.Seen, which leaves out what came out of the bank) and is drawn again. Nothing
-- during a sort hold of the bags (B.Sorting), whose moves bring nothing new.
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

-- Reads one mark of every slot of mine again (my bags, and my tabs while the bank is open), writes the slots whose mark changed, and has the
-- windows draw them.
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

-- QUEST_ACCEPTED and UNIT_QUEST_LOG_CHANGED for the player: the quest marks, at most once every QUEST_EVERY seconds.
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

-- The full scan after B.Data.Resume read every slot: QUEST_ACCEPTED, UNIT_QUEST_LOG_CHANGED and EQUIPMENT_SETS_CHANGED went unheard while the page
-- was off, and the scan reads quest marks and sets only for a slot whose item changed, so both are read again for every slot of mine.
RemarkAll = function()
	questAt = Clock()
	Remark(QuestMarks)
	Remark(SetMarks)
end

-- GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT: the records that waited for this item take its name; an item a window asked for has the
-- windows draw and match again.
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

-- PLAYER_LOGOUT, heard only while the page is on: who this character is and its gold, and its worn items and bag items once more, a last refresh
-- that also catches a change whose event failed, or one that came while this part was stopped. What changed while the page was off was read again
-- by B.Data.Resume when it came back on, and nothing is written while it stays off.
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

-- The row Forget a character, and /flatui status -------------------------------------------------------------------------------------------------

-- The local noon of the day a time() falls on, by the calendar of this computer (date and time), or nil.
local function Noon(stamp)
	local parts = Ask(Client(nil, "date"), "*t", stamp)
	if type(parts) ~= "table" then
		return nil
	end
	return Count(Ask(Client(nil, "time"), { year = parts.year, month = parts.month, day = parts.day, hour = 12 }))
end

-- Today, yesterday or how many days ago a time() was, in days of the calendar counted from noon to noon, so a change of the clock between them
-- counts no day; the bag and bank windows (BagsWindow.lua) and the tooltips of their slots (BagsItems.lua) count the same way.
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

-- The characters kept, by key: { key, record }.
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

-- How many characters and slots with an item are kept.
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

-- Hearing -------------------------------------------------------------------------------------------------------------------------------------------

-- Each handler runs as the part cache: a failure is counted against this part, never the module.
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

-- The module's Start, at login or when the page is first turned on: the same work as a loading screen.
ns.AddStart(KEY, function()
	Part(Started)
end)

-- The page came on again after the module's Start (Bags.lua's Refresh, since Core runs Refresh and not Start then, Core.lua:2278-2287): the module
-- heard none of its events while the page was off, so the work of Start runs again and its full scan catches up the items that changed meanwhile;
-- after that scan the quest marks and the set of every slot are read again too (remarkAll, Delayed and RemarkAll), which no slot-by-slot change
-- shows. They are not read here, before the scan: a slot whose item changed would be written with the marks of its new item and the rest of the
-- old one.
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
