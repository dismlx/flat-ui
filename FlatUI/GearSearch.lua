local _, ns = ...

-- The item finder (spec 0.5.20, item 6): the part "item finder" of Chat and tooltips, a panel of Flat UI's own, FlatUIGearSearch, docked to the right
-- of the Gear comparison window (FlatUIGear, GearWindow.lua): its top left corner 4 px right of the window's top right corner, or, while the screen
-- has no room for it there and has room on the other side, its top right corner 4 px left of the window's top left corner (the window's and the
-- screen's edges, GetLeft, GetRight and GetWidth of the window and UIParent, WL/uiobjects.yaml), and kept on the screen (SetClampedToScreen), so a
-- window sized to the screen or one low on it leaves the finder in sight. It is made on UIParent and hangs from the window by its anchor, so it
-- moves with it, and lies one strata above the window's (Strata and levels, below); it shows only while the window does:
-- when the window hides it closes the finder (GearWindow.lua's Hiding, ns.GearSearchToggle), and the finder closes at its next look once the window
-- is not shown, so the next opening of the window starts without it until Find (the button on the window's title bar, ns.GearSearchToggle) or the
-- list row Item finder (chat.gearFind: ns.GearFindLines and ns.GearFindPick) opens it again.
-- Moved and minimized (the owner: "when i use the movers function the search panel needs to be able to be minimized and moved"; 0.5.21: "the
-- search tool isnt movable in mover panel its still in the way"): the finder has an entry of its own in the movers (Movers.lua: FlatUIGearSearch,
-- Item finder), a plain one like the others: its box is at the profile's spot when one is saved, else where the finder starts, docked at the
-- window's edge as above (ns.GearSearchStart), and it is there only while the finder shows (ns.GearSearchShown), so a closed finder is never in
-- the way; opening the finder while the movers are open shows its box (ns.MoverKit.ShowHandle). A drop of its box saves its spot as for any frame,
-- and so does a drag of its title bar out of a fight (SetMovable, StartMoving, StopMovingOrSizing and SetUserPlaced, WL/uiobjects.yaml:4797, 4813,
-- 4778, as the window's title bar drags the window; SetDontSavePosition, :4605): where it is let go goes to the movers (ns.MoverKit.Commit). The
-- finder then hangs from that spot (ns.MoverSaved and ns.MoverSpot, told by ns.GearSearchMoved), not at the window's edge, until Dock (a button
-- on its title bar while it has a spot), a right-click on the title or a reset of its box forgets the spot as the movers forget one
-- (ns.MoverKit.Restore, so their Undo and Reset all know it) and docks it again. While its box or its title bar is dragged nothing draws its box
-- again. Minimize, left of the cross, folds it to its title bar, with the search box on the bar while it leaves the box room enough there, and
-- back; Enter in the box opens it again with the results. That is kept for the character in FlatUICharDB.gearFinder (ns.Character): min
-- (minimized), and w and h, the size of its box in the movers, which takes the title bar's height while it is minimized. While the movers are
-- open (ns.MoverKit.IsOpen) the finder is in the MEDIUM strata, under their boxes (HIGH), so it covers none of them, and Minimize is above them,
-- so the finder can be minimized out of their way.
-- Strata and levels (0.5.23, the owner: "the search function cant be clicked into in the default flatui user interface"): the finder lies one
-- strata above the window's (GetFrameStrata, SetFrameStrata, WL/uiobjects.yaml:4217, 4653: HIGH over MEDIUM, FULLSCREEN over DIALOG), as the
-- Compare gear button lies over the Character window (GearButton.lua), at a level of its own (L.LEVEL, SetFrameLevel, :4646), under that button's
-- (20) so the button stays on its title bar where the two meet, and it is not toplevel; in the window's strata only while the movers are open
-- (above) and while the options window (HIGH, Panel.lua:2654) shows over a window in MEDIUM, so it stays under that with its window. Its search
-- box and level fields lie L.ABOVE levels over it and Minimize two, set again at each look whenever one is not there (D.Levels): the game sets the
-- levels of a frame's children again when the frame's level changes (Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:817). Before, the
-- finder was toplevel in the window's strata with its search box set once two levels over the title bar. The game raises a toplevel window above
-- every frame of its strata when it is clicked, and the panel manager raises its left panel each time it lays the panels out
-- (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:615-647); the finder, made later and raised only by a click on itself, opened
-- under such a window. By default it docks on one: with UIParent 1365 wide (the game's UI scale 1 on a 16:9 screen) the window, at 680 and 460
-- wide, leaves no room on its right (1488), so the finder hangs on its left, on the Character window (16 to 647), whose paper doll, stats pane,
-- title bar (510) and the movers' title strip (Movers.lua:3385-3394) then lay over the search box and took its clicks, each raising the Character
-- window again.
-- Opening the finder opens the window first (ns.GearWindowShow, looked up when called); a window that waits for the end of a fight (GearWindow.lua
-- makes its frame out of combat only) has the finder wait for it too (ns.OutOfCombat). Every frame here is a plain frame of Flat UI's own with
-- nothing protected, so it is made, sized, filled, shown and placed in a fight too; only a drag of its title bar waits for the end of one.
-- What it finds (ns.GearSearchFind): the generated item index (ItemIndex.lua, ns.ItemIndex: one string of records for each inventory type, parsed
-- the first time a search needs that type, then kept for the session with an index by item ID), the player's bags and bank, and the other
-- characters' bags and bank, as Bags keeps them (ns.Bags.Data: B.Data.Characters, Containers, Size and Item, BagsData.lua:1432-1547), looked up
-- when called: without Bags' data those two sources find nothing and the status line says so. Another character's bound items are left out, since
-- they cannot come to this one. An item found in the bags or with another character is not listed again from the index. A record of the bags takes
-- the required level, item level and allowed classes of the index's record of the same item; an item the index does not have takes them from
-- C_Item.GetItemInfo (WL/apis.yaml:16525), and one the client has not loaded is asked for once (C_Item.RequestLoadItemDataByID, :17160), the search
-- running again every half second while one waits, a dozen times at most. The inventory type of a kept item is its equip location from the instant
-- info (Bags' Data.Info, C_Item.GetItemInfoInstant, :16569) by the client's INVTYPE names (Enum.InventoryType, WL/enums.yaml:4567-4603), else
-- C_Item.GetItemInventoryTypeByID (:16616).
-- The search box: the words in any order, case-insensitive, each found in the item's name; a pasted item link or "item:ID" finds that item alone,
-- whatever the filters, also one the index does not have (from the client). Filters: Slot (the item's inventory type: Main hand is a main-hand
-- weapon and One-hand a weapon of either hand, as the game's tooltips name them; Ranged a bow, gun or crossbow, Wand a wand), Armor (the armor
-- subclass) and Weapon type (the weapon subclass, by the client's names, C_Item.GetItemSubClassInfo, :16785), which exclude each other; required
-- level from and to, the upper bound at first the player's level + 5 with Level filter: Near your level (chat.gearFindLevel), none with Any, until
-- the player types one; quality from (Common at first); and Only what you can wear (chat.gearFindUsable at first): the item's allowed classes and
-- the class's armor and weapon skills, from the client's SkillRaceClassInfo (the GrunzForever export of build 1.60.1.70888, the same data as
-- ItemIndex.lua): the class masks of each skill line, plate and mail from level 40 for the classes that learn them then, polearms from 20; an item
-- counts once the player's level or its own required level reaches that level. The class is UnitClassBase's second answer (:42298) and the level
-- UnitLevel's (:43168). Results: sorted by item level, then required level, quality and name, 50 to a page, in rows of an icon (the instant info's,
-- cut by Icon crop), the name in its quality colour (ColorManager.GetColorDataForItemQuality, Blizzard_Colors/Mainline/ColorManager.lua:52-60, else
-- C_Item.GetItemQualityColor, :16726), the slot and type, where it is, the required level (in the bad colour above the player's level) and the item
-- level; the wheel scrolls a page and the arrows turn it.
-- Best for me works the Overall change out for the page shown only, a few items at a look, out of combat: for each item, once the client has it
-- (asked once, given up after six seconds), G.Compare (GearModel.lua) with the chosen lines the player knows (ns.GearChosen, GearLines.lua) and the
-- options the item tooltips pass, then G.Totals of each candidate slot, and the best slot's figure of the player's role (ns.PlayerRole): healing for
-- a healer, threat for a tank, damage for the others, else the first figure there is. The page is then sorted by it, the figure on each row in the
-- good or bad colour of the tooltips (SpellModel.lua's M.Fmt.Style, else the game's GREEN_FONT_COLOR and RED_FONT_COLOR), "~" before an estimate.
-- It is worked out again when SpellModel's version or the list's changes.
-- Clicks on a row: a click compares the item in the window (ns.GearWindowShow), a right-click compares the window's item against it
-- (ns.GearWindowAgainst), a modified click as the player bound them (IsModifiedClick, :39964): CHATLINK (Shift) puts the whole link in the chat line
-- (ChatFrameUtil.InsertLink, Blizzard_ChatFrameBase/Mainline/ChatFrameUtilOverrides.lua:14), DRESSUP (Ctrl) tries it on (DressUpItemLink,
-- Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua:10), out of a fight, as Bags links an item (BagsItems.lua:1278-1293). A link the client has not
-- loaded yet is asked for, and the player is told to click again.
-- The menus of the filters are frames of Flat UI's own on the finder in the FULLSCREEN_DIALOG strata; one closes when a line is picked, when its
-- button is pressed again, when the finder hides, and at a press anywhere else: GLOBAL_MOUSE_DOWN (WL/events.yaml:5249), heard on a frame of its
-- own only while a menu is open. Tooltips are GameTooltip, never in a fight, as the window's are: SetOwner, SetHyperlink for a row (whose build the
-- item tooltips of GearLines.lua add to), SetText and AddLine, Show, and Hide only while a frame of the finder owns it (IsOwned). The boxes are
-- EditBoxes of Flat UI's own, read with GetText and written with SetText, which give the keyboard back on Enter, Escape and when they hide
-- (ClearFocus). A fight is InCombatLockdown's answer (:39650), a withheld one counting as a fight; time is GetTime's (:39050).
-- The look is the window's, the Windows page's: the Background colour at Window opacity with a thin border (ns.Outline), boxes and buttons in Button
-- and slot colour, the light under the cursor and what is chosen in the Highlight colour. It registers no event but GLOBAL_MOUSE_DOWN while a menu is
-- open, and looks on the OnUpdate of its own frame while it shows: whether the part may run and the window shows, the window's height (the finder is
-- as tall as the window, at least MIN_HEIGHT), its strata and place, typing that settled, items that loaded and Best for me's next items.
-- Everything runs as the part "item finder" of the chat module (ns.EachPart, Core.lua:2197-2228), each run with a count of its own, so three faults
-- stop the finder alone with a line for /flatui status; the first fault of each kind also goes to the game's error handler. It writes no saved
-- variable but FlatUICharDB.gearFinder (above) and its spot in the movers: the search is kept for the session.

local KEY, PART = "chat", "item finder"
-- The finder's name, and the window it docks to (GearWindow.lua's NAME).
local NAME, PARENT = "FlatUIGearSearch", "FlatUIGear"
-- Units: width, the least height, padding, the title bar and its cross, the gap between two controls and to the window, a field, a row of results and
-- its icon, a check box, a line of a menu, the results a page, the room of the level boxes and of a filter button, and the two right columns; the
-- least width of the search box on the title bar of a minimized finder, the width of Dock, and the frame level that puts Minimize above the boxes
-- of the movers (their levels go up to 501, Movers.lua:56, 1973-1979); the finder's own level, whose frames reach it + 4, under the Compare gear
-- button's (GearButton.lua's LEVEL, 20), and how many levels over it its boxes lie: over the title bar and the body (+ 1) and their buttons (+ 2).
local L = { WIDTH = 344, MIN_HEIGHT = 540, PAD = 8, BAR = 26, CLOSE = 18, GAP = 6, DOCK = 4, FIELD = 20, ROW = 30, ICON = 24, CHECK = 12,
	MENU_LINE = 16, PER_PAGE = 50, LEVEL_BOX = 34, ARROW = 20, BEST = 84, RIGHT = 54, CHANGE = 60, FOOT = 26, LINE = 12, MIN_BOX = 90, DOCK_W = 44,
	LIFT = 600, LEVEL = 10, ABOVE = 3 }
L.INNER = L.WIDTH - 2 * L.PAD
L.HALF = (L.INNER - L.GAP) / 2
-- Seconds: between two looks, typing that settles before a search, between two searches while an item loads (and how many), how long Best for me
-- waits for an item to load, and how many items it works out at a look.
local LOOK, SETTLE, WAIT, TRIES, LOAD, STEP = 0.1, 0.25, 0.5, 12, 6, 3
local FONT, TITLE_FONT = "GameFontHighlightSmall", "GameFontHighlight"
-- The text-dim of the windows (PanelLook.lua:27-28), white, and the good and bad colours when SpellModel's style does not answer (the game's
-- GREEN_FONT_COLOR and RED_FONT_COLOR, else Flat UI's combat numbers', CombatText.lua:889-894).
local DIM, PLAIN = { 0.66, 0.68, 0.62 }, { 1, 1, 1 }
local GOOD, BAD = { 0.1, 1, 0.1 }, { 1, 0.1, 0.1 }
local SEPARATOR = 0.07

-- Inventory types (Enum.InventoryType, WL/enums.yaml:4567-4603) by the client's equip location names, and the words of each a player can wear.
local EQUIP = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14,
	INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21,
	INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_RELIC = 28 }
local TYPE_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
	[9] = "Wrist", [10] = "Hands", [11] = "Finger", [12] = "Trinket", [13] = "One-hand", [14] = "Shield", [15] = "Ranged", [16] = "Back",
	[17] = "Two-hand", [19] = "Tabard", [20] = "Chest", [21] = "Main hand", [22] = "Off hand", [23] = "Held in off hand", [25] = "Thrown",
	[26] = "Ranged", [28] = "Relic" }
-- The Slot filter: its key, words, inventory types, and for the ranged types whether a wand (Enum.ItemWeaponSubclass.Wand, 19) is wanted or left out.
local SLOTS = {
	{ "head", "Head", { 1 } }, { "neck", "Neck", { 2 } }, { "shoulder", "Shoulder", { 3 } }, { "back", "Back", { 16 } },
	{ "chest", "Chest", { 5, 20 } }, { "wrist", "Wrist", { 9 } }, { "hands", "Hands", { 10 } }, { "waist", "Waist", { 6 } },
	{ "legs", "Legs", { 7 } }, { "feet", "Feet", { 8 } }, { "finger", "Finger", { 11 } }, { "trinket", "Trinket", { 12 } },
	{ "mainhand", "Main hand", { 21 } }, { "offhand", "Off hand", { 22 } }, { "onehand", "One-hand", { 13 } }, { "twohand", "Two-hand", { 17 } },
	{ "shield", "Shield", { 14 } }, { "holdable", "Held in off hand", { 23 } }, { "ranged", "Ranged", { 15, 26 }, false },
	{ "wand", "Wand", { 26 }, true }, { "thrown", "Thrown", { 25 } }, { "relic", "Relic", { 28 } },
}
-- Enum.ItemClass Weapon and Armor, and the wand's subclass.
local WEAPON, ARMOR, WAND = 2, 4, 19
-- The Armor filter (Enum.ItemArmorSubclass, WL/enums.yaml:4604-4617) and the Weapon type filter (Enum.ItemWeaponSubclass, :5248-5270): the skill
-- lines of Classic, with English words for a client that does not name them.
local ARMORS = { { 1, "Cloth" }, { 2, "Leather" }, { 3, "Mail" }, { 4, "Plate" } }
local WEAPONS = { { 0, "One-Handed Axes" }, { 1, "Two-Handed Axes" }, { 4, "One-Handed Maces" }, { 5, "Two-Handed Maces" },
	{ 7, "One-Handed Swords" }, { 8, "Two-Handed Swords" }, { 6, "Polearms" }, { 10, "Staves" }, { 13, "Fist Weapons" }, { 15, "Daggers" },
	{ 2, "Bows" }, { 3, "Guns" }, { 18, "Crossbows" }, { 16, "Thrown" }, { 19, "Wands" }, { 20, "Fishing Poles" }, { 14, "Miscellaneous" } }
local ARMOR_WORDS = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [6] = "Shield", [7] = "Libram", [8] = "Idol", [9] = "Totem" }
-- Item qualities (Enum.ItemQuality) the filter offers, from.
local QUALITIES = { { 0, "Poor" }, { 1, "Common" }, { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" }, { 5, "Legendary" } }
-- The sources, their words and the words of where an item is.
local SOURCES = { { "all", "All items" }, { "bags", "Bags and bank" }, { "alts", "Other characters" } }
-- Who may wear what: the class masks (bit 2^(class ID - 1): warrior 1, paladin 2, hunter 4, rogue 8, priest 16, shaman 64, mage 128, warlock 256,
-- druid 1024) of each skill line in SkillRaceClassInfo of the client data, all its rows together, with the level the class learns it at: Plate Mail
-- (293) 3 from 40; Mail (413) 3, and 68 from 40; Leather (414) 1103; Cloth (415) 1503; Shield (433) 67; Axes (44) 79; Two-Handed Axes (172) 71;
-- Bows (45), Guns (46), Crossbows (226) and Thrown (176) 13; Maces (54) 1115; Two-Handed Maces (160) 1091; Polearms (229) 1031 from 20; Swords (43)
-- 399; Two-Handed Swords (55) 7; Staves (136) 1493; Fist Weapons (473) 1101; Daggers (173) 1501; Wands (228) 400; Fishing (356) every class. The
-- relics are the class's own (Libram 2, Idol 1024, Totem 64). An armor subclass not listed (Miscellaneous, Cosmetic) is anyone's; a weapon subclass
-- with no rows is no one's on this client.
local ARMOR_SKILL = { [1] = { { 1503, 0 } }, [2] = { { 1103, 0 } }, [3] = { { 3, 0 }, { 68, 40 } }, [4] = { { 3, 40 } }, [6] = { { 67, 0 } },
	[7] = { { 2, 0 } }, [8] = { { 1024, 0 } }, [9] = { { 64, 0 } } }
local WEAPON_SKILL = { [0] = { { 79, 0 } }, [1] = { { 71, 0 } }, [2] = { { 13, 0 } }, [3] = { { 13, 0 } }, [4] = { { 1115, 0 } },
	[5] = { { 1091, 0 } }, [6] = { { 1031, 20 } }, [7] = { { 399, 0 } }, [8] = { { 7, 0 } }, [9] = {}, [10] = { { 1493, 0 } }, [11] = {}, [12] = {},
	[13] = { { 1101, 0 } }, [14] = { { -1, 0 } }, [15] = { { 1501, 0 } }, [16] = { { 13, 0 } }, [17] = {}, [18] = { { 13, 0 } }, [19] = { { 400, 0 } },
	[20] = { { -1, 0 } } }
-- The fields of a record of the index when it does not say (ItemIndex.lua's FIELDS).
local FIELDS = "id\tname\tclass\tsubclass\treq\tilvl\tquality\tclasses"
-- Best for me: the figures of G.Totals in the order each role looks for them, and their words.
local FIGURES = { healer = { "healing", "damage", "threat" }, tank = { "threat", "damage", "healing" }, damage = { "damage", "threat", "healing" } }
local FIGURE_WORDS = { damage = "Damage", healing = "Healing", threat = "Threat" }
-- The words of the finder. Flat UI's lines are English, as its other extra lines.
local T = {
	TITLE = "Item finder",
	SEARCH = "Search items by name, or paste a link",
	SLOT = "Slot: %s",
	ARMOR = "Armor: %s",
	WEAPON = "Weapon: %s",
	QUALITY = "Quality: %s",
	ANY = "Any",
	FROM = "%s and up",
	LEVEL = "Level",
	TO = "to",
	USABLE = "Only what you can wear",
	BEST = "Best for me",
	COUNT_ONE = "1 item",
	COUNT = "%s items",
	PAGE = "%s, page %d of %d",
	NONE = "No items match. Loosen a filter or the level range.",
	NO_INDEX = "The item index is not loaded: All items finds nothing.",
	NO_BAGS = "Bags keeps no record: your bags and other characters find nothing.",
	WORKING = "Best for me: %d of %d worked out",
	FIGHT = "Best for me waits for the end of the fight.",
	SORTED = "Best for me: sorted by %s for this page",
	NO_FIGURE = "Best for me: no figure for your chosen spells",
	BAGS = "Bags",
	BANK = "Bank",
	REQ = "Req %d",
	ILVL = "ilvl %d",
	ITEM = "item %d",
	HINT = "Click: compare. Right-click: compare against. Shift-click: link. Ctrl-click: try on.",
	ROW_TIP = "Click to compare it in the window, right-click to compare the window's item against it, Shift-click to link it, Ctrl-click to try it on.",
	SLOT_TIP = "The kind of item, as its tooltip names it. Right-click for Any; the mouse wheel steps through them.",
	ARMOR_TIP = "The armor type. Choosing one leaves out weapons, rings and other items of no armor type. Right-click for Any.",
	WEAPON_TIP = "The weapon type. Choosing one leaves out armor. Right-click for Any.",
	QUALITY_TIP = "The least quality shown. Right-click for Poor and up.",
	LEVEL_TIP = "The required level, from and to. Empty is no bound. Level filter on the Spells and gear tab sets the first upper bound: your level + 5, or none.",
	USABLE_TIP = "Leaves out what your class can never wear: its armor and weapon skills, from the game's data, and items for other classes. Plate and mail count from level 40 for the classes that learn them then.",
	SOURCE_TIP = {
		all = "Every weapon and piece of armor of the game, from Flat UI's item index.",
		bags = "What your bags and bank hold, as Bags keeps them. Your bank as you last saw it.",
		alts = "What your other characters' bags and banks hold, as Bags keeps them; items bound to them are left out.",
	},
	BEST_TIP = "Works out the Overall change of each item on this page for you, with the spells you chose for the gear comparison, and sorts the page by it: healing for a healer, threat for a tank, damage for the others. The game is asked to load the items first. Click again to sort by item level.",
	PREV = "The page before",
	NEXT = "The next page",
	NOT_LOADED = "Item finder: the game has not loaded this item yet; click again in a moment.",
	NO_AGAINST = "Item finder: the Gear comparison window cannot compare against an item yet.",
	TRY_FIGHT = "Item finder: trying items on waits for the end of the fight.",
	OPEN_LINE = "Open the item finder",
	AFTER_FIGHT = "Item finder: it opens with the window when the fight ends.",
	OFF = "Item finder: turn on Restyle chat and tooltips on the Chat and tooltips page first.",
	MODULE_STOPPED = "Item finder: Chat and tooltips stopped after an error. /flatui status says why.",
	STOPPED = "Item finder: it stopped after an error. /flatui status says why.",
	BAR_TIP = "Drag the title to move the finder on its own, out of a fight: it then keeps that spot, as a drag of its box in /flatui move does. Right-click the title to dock it at the window's edge again.",
	MINIMIZE = "Minimize",
	RESTORE = "Restore",
	FOLD_TIP = "Folds the finder to its title bar, with the search box where it fits, and back; kept for this character. Enter in the search box opens it again with the results.",
	DOCK = "Dock",
	DOCK_TIP = "Hangs the finder at the window's edge again, where it moves with the window. A right-click on the title does the same.",
	REPORT = "Flat UI, Item finder, %s: %s",
}

local IsSecret = ns.IsSecret

-- The state of the finder. frame: FlatUIGearSearch, made the first time it opens, and outline; bar, title, close; box (the search box) and hint;
-- choices (the filter buttons by kind), from and to (the level boxes), checks (usable and the sources); status, prev, next, best (Best for me's
-- button); list (the frame of the rows) and listTop (its distance from the top), made (every row made) and rows (those the height holds), empty
-- (the line with no results), foot; fields: outlines of the boxes and buttons; owners: frames
-- whose tooltip the finder writes; menu: the open filter menu.
-- query: the search as the controls hold it; results: what it found, sorted; key: the query they were found for; page and offset (the first row
-- shown of the page); waiting and tries: an item of the bags not loaded yet; typedAt: the last key typed; levelTyped: the player typed an upper
-- level; levelRow and usableRow: the rows of the tab as last read. parsed and byId: the index's records by type and by item ID; types: the types it
-- has; icons, subNames, colours: answers kept. requested: items the client was asked to load. best: Best for me's { on, scores, version, started }.
-- runs, faults, elapsed, pending: the part's runs, what went to the error handler, the time since the last look, an opening that waits for a fight.
-- parent: the window; body: the frame of everything under the title bar; close, fold (Minimize, its strokes in foldLines) and dock (Dock), the
-- buttons of the title bar; boxY: where the search box sits under the title bar; boxes: the search box and the level boxes (D.Levels). placed:
-- where the finder hangs now (Place: "right" or "left" of the window, else its spot); min: minimized; moving: its title bar is dragged; strata and
-- lifted: the strata it took and whether Minimize is above the boxes of the movers.
local S = { runs = 0, faults = {}, elapsed = 0, page = 1, offset = 0, results = {}, rows = {}, made = {}, choices = {}, checks = {}, fields = {}, owners = {},
	parsed = {}, byId = {}, icons = {}, subNames = {}, colours = {}, requested = {}, tries = 0,
	query = { text = "", quality = 1, usable = true, sources = { all = true, bags = true, alts = true } },
	best = { on = false, scores = {} } }

local Search, Paint, PaintList, Close
-- The placing and minimizing functions, in a table of their own to keep the file under the client's count of locals.
local D = {}

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Finite(value)
	return ns.Finite(value)
end

-- A plain string with something in it, or nil.
local function Text(value)
	if not IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

-- A plain whole number, or nil.
local function Num(value)
	if Finite(value) then
		return math.floor(value)
	end
	if not IsSecret(value) and type(value) == "string" then
		local number = tonumber(value)
		if Finite(number) then
			return math.floor(number)
		end
	end
	return nil
end

local function Now()
	if type(GetTime) ~= "function" then
		return 0
	end
	local ok, now = pcall(GetTime)
	return ok and Finite(now) and now or 0
end

-- True in a fight: InCombatLockdown's answer, a withheld one counting as a fight.
local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

-- A function of a table, looked up when it is called and never kept: the other parts' files may load after this one or fail.
local function Fn(tbl, name)
	if type(tbl) ~= "table" or IsSecret(tbl) then
		return nil
	end
	local fn = tbl[name]
	if type(fn) == "function" then
		return fn
	end
	return nil
end

-- The part ---------------------------------------------------------------------------------------------------------------------------------------

-- A fault goes to the game's error handler once for each thing that failed.
local function Report(what, err)
	if S.faults[what] then
		return
	end
	S.faults[what] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, T.REPORT:format(tostring(what), tostring(err)))
	end
end

-- The first answer of a function of another part, or nil when it is missing or raises; its fault goes to the error handler once.
local function Ask(tbl, name, ...)
	local fn = Fn(tbl, name)
	if not fn then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok then
		return answer
	end
	Report(name, answer)
	return nil
end

local function Step(_, fn, ...)
	return fn(...)
end

-- Runs fn as the part of the chat module, each run counted by a number of its own (ns.EachPart counts a fault once for each first argument and stops
-- the part at the third, Core.lua:2203-2224). A part that stopped closes the finder.
local function Run(fn, ...)
	S.runs = S.runs + 1
	local ok, err = ns.EachPart(KEY, PART, Step, S.runs, fn, ...)
	if not ok and err ~= nil then
		Report("finder", err)
		if ns.PartStopped(KEY, PART) then
			Close()
		end
	end
	return ok == true
end

-- True while the finder may show: the chat module registered, on and running, and neither this part nor the window's stopped.
local function Allowed()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.Enabled(KEY) and not ns.PartStopped(KEY, PART)
		and not ns.PartStopped(KEY, "gear window")
end

local function Refusal()
	if type(ns.modules) == "table" and ns.modules[KEY] ~= nil then
		if ns.IsStopped(KEY) then
			return T.MODULE_STOPPED
		elseif ns.PartStopped(KEY, PART) or ns.PartStopped(KEY, "gear window") then
			return T.STOPPED
		end
	end
	return T.OFF
end

-- The game -----------------------------------------------------------------------------------------------------------------------------------------

local function Client(space, name)
	if space then
		return Fn(_G[space], name)
	end
	local fn = _G[name]
	return type(fn) == "function" and fn or nil
end

-- The player's level and the bit of their class in a class mask, or nil while the game does not say.
local function PlayerLevel()
	local level = Client(nil, "UnitLevel")
	if level then
		local ok, value = pcall(level, "player")
		if ok and Finite(value) and value > 0 then
			return value
		end
	end
	return nil
end

local function ClassBit()
	local base = Client(nil, "UnitClassBase")
	if base then
		local ok, _, id = pcall(base, "player")
		if ok and Finite(id) and id >= 1 and id <= 30 then
			return 2 ^ (math.floor(id) - 1)
		end
	end
	return nil
end

-- C_Item.GetItemInfo's name, whole link, quality, item level and required level, or nil while the client has not loaded the item.
local function ItemInfo(link)
	local info = Client("C_Item", "GetItemInfo")
	if not info then
		return nil
	end
	local ok, name, whole, quality, ilvl, req = pcall(info, link)
	if not ok or not Text(name) then
		return nil
	end
	return name, Text(whole), Num(quality), Num(ilvl), Num(req)
end

-- Asks the client once a session to load an item.
local function Want(id)
	if not id or S.requested[id] then
		return
	end
	S.requested[id] = true
	local request = Client("C_Item", "RequestLoadItemDataByID")
	if request then
		pcall(request, id)
	end
end

-- The instant info of an item: its equip location, icon, class and subclass, which never wait for a load.
local function Instant(id)
	local instant = Client("C_Item", "GetItemInfoInstant")
	if not instant then
		return nil
	end
	local ok, _, _, _, equip, icon, class, subclass = pcall(instant, id)
	if not ok then
		return nil
	end
	return Text(equip), (not IsSecret(icon) and (Finite(icon) or Text(icon))) and icon or nil, Num(class), Num(subclass)
end

local function Icon(id)
	local icon = S.icons[id]
	if icon == nil then
		local _, answer = Instant(id)
		icon = answer or false
		S.icons[id] = icon
	end
	return icon or nil
end

-- The inventory type of an item: from its equip location, else C_Item.GetItemInventoryTypeByID.
local function InvTypeOf(id, equip)
	local invType = equip and EQUIP[equip] or nil
	if invType then
		return invType
	end
	local byId = Client("C_Item", "GetItemInventoryTypeByID")
	if byId then
		local ok, answer = pcall(byId, id)
		if ok and Finite(answer) then
			return math.floor(answer)
		end
	end
	return nil
end

-- The client's name of a subclass, else the English one.
local function SubName(class, subclass, fallback)
	local key = tostring(class) .. ":" .. tostring(subclass)
	local name = S.subNames[key]
	if name == nil then
		local info = Client("C_Item", "GetItemSubClassInfo")
		if info then
			local ok, answer = pcall(info, class, subclass)
			name = ok and Text(answer) or nil
		end
		name = name or fallback or false
		S.subNames[key] = name
	end
	return name or nil
end

-- Red, green and blue of an item quality: the game's own colour of it, else C_Item.GetItemQualityColor's, else white.
local function QualityColour(quality)
	if not Finite(quality) then
		return PLAIN
	end
	local kept = S.colours[quality]
	if kept then
		return kept
	end
	local colour
	local get = Fn(_G.ColorManager, "GetColorDataForItemQuality")
	if get then
		local ok, data = pcall(get, quality)
		if ok and type(data) == "table" and not IsSecret(data) and Finite(data.r) and Finite(data.g) and Finite(data.b) then
			colour = { data.r, data.g, data.b }
		end
	end
	if not colour then
		local get2 = Client("C_Item", "GetItemQualityColor")
		if get2 then
			local ok, r, g, b = pcall(get2, quality)
			if ok and Finite(r) and Finite(g) and Finite(b) then
				colour = { r, g, b }
			end
		end
	end
	if not colour then
		return PLAIN
	end
	S.colours[quality] = colour
	return colour
end

-- The good and bad colours of the tooltips: SpellModel's style (M.Fmt.Style), else the game's.
local function Tone(which)
	local fmt = type(ns.SpellModel) == "table" and ns.SpellModel.Fmt
	local style = type(fmt) == "table" and fmt.Style
	local colour = type(style) == "table" and style[which]
	if type(colour) == "table" and Finite(colour[1]) and Finite(colour[2]) and Finite(colour[3]) then
		return colour
	end
	local game = _G[which == "good" and "GREEN_FONT_COLOR" or "RED_FONT_COLOR"]
	if type(game) == "table" and not IsSecret(game) and Finite(game.r) and Finite(game.g) and Finite(game.b) then
		return { game.r, game.g, game.b }
	end
	return which == "good" and GOOD or BAD
end

-- A change as a share: SpellModel's M.Fmt.Percent, else one decimal with its sign.
local function Percent(x)
	local fmt = type(ns.SpellModel) == "table" and ns.SpellModel.Fmt
	local percent = Fn(fmt, "Percent")
	if percent then
		local ok, text = pcall(percent, x)
		if ok and Text(text) then
			return text
		end
	end
	local value = x * 100
	if math.abs(value) < 0.05 then
		return "0%"
	end
	return (value > 0 and "+" or "-") .. ("%.1f"):format(math.abs(value)) .. "%"
end

-- A whole number with its thousands broken by commas.
local function Big(n)
	local text = tostring(math.floor(n))
	local head, digits = text:match("^(-?)(%d+)$")
	if not digits then
		return text
	end
	digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return head .. digits
end

-- True while the player pressed the modifier of a kind of click (IsModifiedClick: CHATLINK, DRESSUP).
local function Modified(kind)
	local fn = Client(nil, "IsModifiedClick")
	if not fn then
		return false
	end
	local ok, held = pcall(fn, kind)
	return ok and not IsSecret(held) and held == true
end

-- The index ----------------------------------------------------------------------------------------------------------------------------------------

local function Index()
	local index = ns.ItemIndex
	if type(index) == "table" and not IsSecret(index) and type(index.DATA) == "table" then
		return index
	end
	return nil
end

-- The place of each field of a record, by the index's FIELDS.
local function Positions()
	if S.positions then
		return S.positions
	end
	local index = Index()
	local fields = index and Text(index.FIELDS) or FIELDS
	local at, n = {}, 0
	for name in (fields .. "\t"):gmatch("([^\t]*)\t") do
		n = n + 1
		at[name] = n
	end
	S.positions = at
	return at
end

-- The records of one inventory type, parsed the first time a search needs them: { id, name, lower, invType, class, subclass, req, ilvl, quality,
-- classes, link, source }. A line that does not parse is skipped.
local function Parse(invType)
	local parsed = S.parsed[invType]
	if parsed then
		return parsed
	end
	parsed = {}
	S.parsed[invType] = parsed
	local index = Index()
	local data = index and index.DATA[invType]
	if type(data) ~= "string" or IsSecret(data) then
		return parsed
	end
	local at = Positions()
	local idAt, nameAt, classAt, subAt = at.id or 1, at.name or 2, at.class or 3, at.subclass or 4
	local reqAt, ilvlAt, qualityAt, classesAt = at.req or 5, at.ilvl or 6, at.quality or 7, at.classes or 8
	local fields = {}
	for line in data:gmatch("[^\n]+") do
		local n = 0
		for field in (line .. "\t"):gmatch("([^\t]*)\t") do
			n = n + 1
			fields[n] = field
		end
		local id, name = tonumber(fields[idAt]), fields[nameAt]
		if id and name and name ~= "" then
			local rec = { id = id, name = name, lower = name:lower(), invType = invType, class = tonumber(fields[classAt]),
				subclass = tonumber(fields[subAt]), req = tonumber(fields[reqAt]) or 0, ilvl = tonumber(fields[ilvlAt]) or 0,
				quality = tonumber(fields[qualityAt]), classes = tonumber(fields[classesAt]) or -1, link = "item:" .. id, source = "all" }
			parsed[#parsed + 1] = rec
			S.byId[id] = rec
		end
		for i = n, 1, -1 do
			fields[i] = nil
		end
	end
	return parsed
end

-- Every inventory type the index has, in order.
local function Types()
	if S.types then
		return S.types
	end
	local index = Index()
	local list = {}
	if index then
		for invType, data in pairs(index.DATA) do
			if Finite(invType) and type(data) == "string" then
				list[#list + 1] = invType
			end
		end
	end
	table.sort(list)
	if index then
		S.types = list
	end
	return list
end

-- The index's record of an item, or nil.
local function Known(id, invType)
	if not id then
		return nil
	end
	if S.byId[id] == nil and invType then
		Parse(invType)
	end
	return S.byId[id]
end

-- Matching ---------------------------------------------------------------------------------------------------------------------------------------

-- True when a class mask holds a class's bit; -1 and 0 are any class.
local function Has(mask, bit)
	if not Finite(mask) or mask <= 0 then
		return true
	end
	return math.floor(mask / bit) % 2 == 1
end

-- Whether the player's class can wear an item: its classes, then the armor or weapon skill (ARMOR_SKILL, WEAPON_SKILL) at the higher of the
-- player's level and the item's required level.
local function Usable(rec, ctx)
	local bit = ctx.bit
	if not bit then
		return true
	end
	if not Has(rec.classes, bit) then
		return false
	end
	local skills = (rec.class == ARMOR and ARMOR_SKILL[rec.subclass]) or (rec.class == WEAPON and WEAPON_SKILL[rec.subclass]) or nil
	if skills == nil then
		return rec.class ~= WEAPON
	end
	local level = math.max(ctx.level or 0, rec.req or 0)
	for _, skill in ipairs(skills) do
		if Has(skill[1], bit) and level >= skill[2] then
			return true
		end
	end
	return false
end

-- The Slot filter of a key (or an inventory type), or nil for any.
local function SlotOf(key)
	if Finite(key) then
		return { types = { [key] = true } }
	end
	for _, slot in ipairs(SLOTS) do
		if slot[1] == key then
			local types = {}
			for _, invType in ipairs(slot[3]) do
				types[invType] = true
			end
			return { types = types, list = slot[3], wand = slot[4] }
		end
	end
	return nil
end

-- What a search reads beside the query: its words, an item ID pasted, the slot, the player's class and level, the types to look through.
local function Context(q)
	local ctx = { words = {}, level = PlayerLevel(), bit = ClassBit() }
	local text = q.text or ""
	ctx.id = tonumber(text:match("item:(%d+)") or "")
	if not ctx.id then
		for word in text:lower():gmatch("%S+") do
			ctx.words[#ctx.words + 1] = word
		end
	end
	ctx.slot = SlotOf(q.slot)
	if ctx.id then
		-- A pasted item is looked for in its own type, whatever the Slot filter says.
		local invType = InvTypeOf(ctx.id, (Instant(ctx.id)))
		ctx.types = invType and { invType } or Types()
	elseif ctx.slot and ctx.slot.list then
		ctx.types = ctx.slot.list
	elseif ctx.slot then
		ctx.types = { q.slot }
	else
		ctx.types = Types()
	end
	return ctx
end

-- Whether a record passes the query. An item ID pasted passes alone; a level or quality not known yet passes.
local function Matches(rec, q, ctx)
	if ctx.id then
		return rec.id == ctx.id
	end
	for _, word in ipairs(ctx.words) do
		if not rec.lower:find(word, 1, true) then
			return false
		end
	end
	local slot = ctx.slot
	if slot then
		if not slot.types[rec.invType] then
			return false
		end
		local wand = rec.class == WEAPON and rec.subclass == WAND
		if (slot.wand == true and not wand) or (slot.wand == false and wand) then
			return false
		end
	end
	if q.armor and not (rec.class == ARMOR and rec.subclass == q.armor) then
		return false
	end
	if q.weapon and not (rec.class == WEAPON and rec.subclass == q.weapon) then
		return false
	end
	local req = rec.req
	if req and ((q.minLevel and req < q.minLevel) or (q.maxLevel and req > q.maxLevel)) then
		return false
	end
	if q.quality and rec.quality and rec.quality < q.quality then
		return false
	end
	if q.usable and not Usable(rec, ctx) then
		return false
	end
	return true
end

-- The order of the results: item level, required level and quality, the highest first, then the name, the ID and the source.
local SOURCE_ORDER = { bags = 1, alts = 2, all = 3 }
local function Before(a, b)
	if (a.ilvl or 0) ~= (b.ilvl or 0) then
		return (a.ilvl or 0) > (b.ilvl or 0)
	end
	if (a.req or 0) ~= (b.req or 0) then
		return (a.req or 0) > (b.req or 0)
	end
	if (a.quality or 0) ~= (b.quality or 0) then
		return (a.quality or 0) > (b.quality or 0)
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	if a.id ~= b.id then
		return a.id < b.id
	end
	if a.source ~= b.source then
		return (SOURCE_ORDER[a.source] or 9) < (SOURCE_ORDER[b.source] or 9)
	end
	return (a.where or "") < (b.where or "")
end

-- The sources -------------------------------------------------------------------------------------------------------------------------------------

-- Bags' data (BagsData.lua), or nil when Bags did not load it.
local function BagsData()
	local bags = ns.Bags
	local data = type(bags) == "table" and not IsSecret(bags) and bags.Data or nil
	if type(data) == "table" and Fn(data, "Containers") and Fn(data, "Size") and Fn(data, "Item") then
		return data
	end
	return nil
end

-- A record of Bags (Data.Item) as a result, or nil for one that is no weapon or armor to wear. Its level, item level and classes are the index's
-- record of the item, else the client's; one the client has not loaded waits.
local function Owned(r, source, where)
	local id = Num(r.id)
	if not id then
		return nil
	end
	local class, subclass, equip = Num(r.class), Num(r.subclass), Text(r.equipLoc)
	if class == nil then
		local instantEquip, _, instantClass, instantSub = Instant(id)
		equip, class, subclass = equip or instantEquip, instantClass, instantSub
	end
	if class ~= WEAPON and class ~= ARMOR then
		return nil
	end
	local invType = InvTypeOf(id, equip)
	if not (invType and TYPE_NAMES[invType]) then
		return nil
	end
	local rec = { id = id, invType = invType, class = class, subclass = subclass, source = source, where = where,
		link = Text(r.link) or ("item:" .. id), name = Text(r.name), quality = Num(r.quality) }
	local known = Known(id, invType)
	if known then
		rec.req, rec.ilvl, rec.classes = known.req, known.ilvl, known.classes
		rec.name = rec.name or known.name
		rec.quality = rec.quality or known.quality
	else
		local name, _, quality, ilvl, req = ItemInfo(rec.link)
		if name then
			rec.name, rec.quality, rec.ilvl, rec.req = rec.name or name, rec.quality or quality, ilvl, req
		else
			rec.waiting = true
			Want(id)
		end
	end
	if not rec.name then
		rec.name, rec.waiting = T.ITEM:format(id), true
		Want(id)
	end
	rec.lower = rec.name:lower()
	return rec
end

-- Calls fn with each record of a character's bags or bank (key nil: this character).
local function EachSlot(data, key, which, fn)
	local ok, list = pcall(data.Containers, which, key)
	if not ok or type(list) ~= "table" then
		return
	end
	for _, bag in ipairs(list) do
		local okSize, size = pcall(data.Size, key, bag)
		size = okSize and Num(size) or 0
		for slot = 1, math.min(size, 255) do
			local okItem, r = pcall(data.Item, key, bag, slot)
			if okItem and type(r) == "table" and not IsSecret(r) then
				fn(r)
			end
		end
	end
end

-- The other characters Bags keeps: { key, name } each.
local function Others(data)
	local list = {}
	local characters = Fn(data, "Characters")
	if not characters then
		return list
	end
	local ok, entries = pcall(characters)
	if not ok or type(entries) ~= "table" then
		return list
	end
	for _, entry in ipairs(entries) do
		if type(entry) == "table" and not entry.me and Text(entry.key) then
			list[#list + 1] = { key = entry.key, name = Text(entry.name) or entry.key }
		end
	end
	return list
end

-- An item the index does not have, pasted as a link or item:ID, from the client.
local function FromClient(id, link)
	local equip, _, class, subclass = Instant(id)
	local invType = InvTypeOf(id, equip)
	if not (invType and TYPE_NAMES[invType]) or (class ~= WEAPON and class ~= ARMOR) then
		return nil
	end
	local rec = { id = id, invType = invType, class = class, subclass = subclass, source = "all", link = link or ("item:" .. id), classes = -1 }
	local name, _, quality, ilvl, req = ItemInfo(rec.link)
	if name then
		rec.name, rec.quality, rec.ilvl, rec.req = name, quality, ilvl, req
	else
		rec.name, rec.waiting = T.ITEM:format(id), true
		Want(id)
	end
	rec.lower = rec.name:lower()
	return rec
end

-- The search ---------------------------------------------------------------------------------------------------------------------------------------

-- A query with its fields checked: { text, slot, armor, weapon, minLevel, maxLevel, quality, usable, sources }; sources a set of "all", "bags" and
-- "alts" (all three when none is given).
local ARMOR_KEYS = { cloth = 1, leather = 2, mail = 3, plate = 4 }
local function Normalize(query)
	local q = type(query) == "table" and query or {}
	local out = { text = Text(q.text) or "", usable = q.usable == true }
	out.slot = Text(q.slot) or Num(q.slot)
	out.armor = ARMOR_KEYS[Text(q.armor) and q.armor:lower() or ""] or Num(q.armor)
	out.weapon = Num(q.weapon)
	out.minLevel, out.maxLevel, out.quality = Num(q.minLevel), Num(q.maxLevel), Num(q.quality)
	local sources = {}
	if type(q.sources) == "table" then
		for key, on in pairs(q.sources) do
			if on == true and Text(key) then
				sources[key] = true
			elseif Text(on) then
				sources[on] = true
			end
		end
	else
		sources.all, sources.bags, sources.alts = true, true, true
	end
	out.sources = sources
	return out
end

-- The results of a query, sorted, and whether an item of them waits for the client.
local function Find(query)
	local q = Normalize(query)
	local ctx = Context(q)
	local out, owned, waiting = {}, {}, false
	local function Take(rec)
		if rec and Matches(rec, q, ctx) then
			out[#out + 1] = rec
			owned[rec.id] = true
			waiting = waiting or rec.waiting == true
		end
	end
	local data = (q.sources.bags or q.sources.alts) and BagsData() or nil
	if data and q.sources.bags then
		EachSlot(data, nil, "bags", function(r)
			Take(Owned(r, "bags", T.BAGS))
		end)
		EachSlot(data, nil, "bank", function(r)
			Take(Owned(r, "bags", T.BANK))
		end)
	end
	if data and q.sources.alts then
		for _, other in ipairs(Others(data)) do
			local function Kept(r)
				if r.bound ~= true then
					Take(Owned(r, "alts", other.name))
				end
			end
			EachSlot(data, other.key, "bags", Kept)
			EachSlot(data, other.key, "bank", Kept)
		end
	end
	if q.sources.all then
		for _, invType in ipairs(ctx.types) do
			for _, rec in ipairs(Parse(invType)) do
				if not owned[rec.id] and Matches(rec, q, ctx) then
					out[#out + 1] = rec
				end
			end
		end
	end
	if ctx.id and #out == 0 then
		local text = q.text
		local link = text:match("|H(item:[%-%d:]+)|h") or text:match("(item:[%-%d:]+)")
		local rec = FromClient(ctx.id, link)
		if rec then
			out[1] = rec
			waiting = waiting or rec.waiting == true
		end
	end
	table.sort(out, Before)
	return out, waiting
end

-- The look -----------------------------------------------------------------------------------------------------------------------------------------

local function RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Opacity()
	local value = ns.Get("windows.opacity")
	return Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

local function Crop()
	local value = ns.Get("windows.crop")
	return (Finite(value) and math.max(0, math.min(15, value)) or 8) / 100
end

local function Colour(text, colour)
	text:SetTextColor(colour[1], colour[2], colour[3], 1)
end

local function Label(parent, font)
	local text = ns.OwnText(parent, "OVERLAY", font or FONT)
	if not text then
		error("no font string", 0)
	end
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

local function Texture(parent, layer, sub)
	return Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

-- A stroke between two points, each from an anchor point of the frame, as the window draws its cross (GearWindow.lua, Stroke).
local function Stroke(frame, layer, point, x1, y1, x2, y2)
	local line = Own(frame:CreateLine(nil, layer, nil, 2))
	line:SetThickness(1.5)
	line:SetStartPoint(point, frame, x1, y1)
	line:SetEndPoint(point, frame, x2, y2)
	return line
end

-- An outline of a box or button of the finder, filled in Button and slot colour.
local function Field(frame)
	local outline = ns.SetOutlineArea(ns.Outline(frame, frame, true), "windows")
	S.fields[#S.fields + 1] = outline
	return outline
end

-- Everything the rows of the Windows page and the general backdrop colour decide.
local function PaintLook()
	if not S.frame then
		return
	end
	local r, g, b = RGB("general.backdrop", 0.06, 0.06, 0.06)
	ns.SetOutlineFill(S.outline, r, g, b, Opacity())
	ns.SetOutline(S.outline, true, true)
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	for _, outline in ipairs(S.fields) do
		ns.SetOutlineFill(outline, pr, pg, pb, 1)
		ns.SetOutline(outline, true, true)
	end
	for _, light in ipairs(S.lights) do
		light:SetColorTexture(ar, ag, ab, 0.12)
	end
	for _, check in pairs(S.checks) do
		check.fill:SetColorTexture(ar, ag, ab, 1)
	end
	for _, line in ipairs(S.strokes) do
		line:SetColorTexture(1, 1, 1, 0.6)
	end
	for _, line in ipairs(S.hoverStrokes) do
		line:SetColorTexture(ar, ag, ab, 1)
	end
	S.rule:SetColorTexture(1, 1, 1, SEPARATOR)
	S.barRule:SetColorTexture(1, 1, 1, SEPARATOR)
	local crop = Crop()
	for _, row in ipairs(S.made) do
		row.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	Colour(S.title, PLAIN)
	for _, text in ipairs({ S.hint, S.status, S.empty, S.foot, S.levelLabel, S.toLabel }) do
		Colour(text, DIM)
	end
	if S.best.button then
		local on = S.best.on
		S.best.text:SetTextColor(on and ar or PLAIN[1], on and ag or PLAIN[2], on and ab or PLAIN[3], 1)
	end
end

-- Tooltips -----------------------------------------------------------------------------------------------------------------------------------------

local function Tooltip()
	local tip = GameTooltip
	if type(tip) == "table" and not IsSecret(tip) and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

-- Hides the tooltip only while that frame of the finder owns it.
local function Untip(owner)
	local tip = Tooltip()
	if not tip then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

-- A plain tooltip of a control: a title and a wrapped line, never in a fight.
local function Say(owner, title, line)
	local tip = Tooltip()
	if not tip or Fighting() then
		return
	end
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	tip:SetText(title, PLAIN[1], PLAIN[2], PLAIN[3])
	if line then
		tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

local function Tipped(frame, title, line)
	S.owners[#S.owners + 1] = frame
	frame:SetScript("OnEnter", function(self)
		Run(Say, self, type(title) == "function" and title() or title, line)
	end)
	frame:SetScript("OnLeave", function(self)
		Untip(self)
	end)
end

-- The menu of a filter ------------------------------------------------------------------------------------------------------------------------------

local function CloseMenu()
	local menu = S.menu
	if menu and menu.frame:IsShown() then
		menu.frame:Hide()
	end
end

local function MenuFrame()
	if S.menu then
		return S.menu
	end
	local frame = Own(CreateFrame("Frame", nil, S.frame))
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableMouse(true)
	pcall(frame.SetClampedToScreen, frame, true)
	frame:Hide()
	local menu = { frame = frame, lines = {} }
	menu.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "windows")
	-- A press anywhere but on the menu and the button that opened it closes the menu; heard only while it shows.
	menu.listener = Own(CreateFrame("Frame", nil, frame))
	menu.listener:SetScript("OnEvent", function()
		local over = frame:IsMouseOver() or (menu.owner and menu.owner:IsMouseOver())
		if not over then
			CloseMenu()
		end
	end)
	frame:SetScript("OnShow", function()
		pcall(menu.listener.RegisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	end)
	frame:SetScript("OnHide", function()
		pcall(menu.listener.UnregisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
		menu.owner = nil
	end)
	S.menu = menu
	return menu
end

local function MenuLine(menu, index)
	local line = menu.lines[index]
	if line then
		return line
	end
	local button = Own(CreateFrame("Button", nil, menu.frame))
	button:SetHeight(L.MENU_LINE)
	button:RegisterForClicks("LeftButtonUp")
	line = { button = button }
	line.light = Texture(button, "HIGHLIGHT")
	line.light:SetAllPoints(button)
	line.text = Label(button)
	line.text:SetPoint("LEFT", button, "LEFT", 6, 0)
	line.text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	button:SetScript("OnClick", function()
		local pick, value = menu.pick, line.value
		CloseMenu()
		if pick then
			Run(pick, value)
		end
	end)
	menu.lines[index] = line
	return line
end

-- Opens a menu under a button: items { { value, words, colour } }, the chosen value lit, pick(value) for a line clicked. Pressing the button of the open
-- menu again closes it.
local function OpenMenu(owner, items, chosen, pick)
	local menu = MenuFrame()
	if menu.frame:IsShown() and menu.owner == owner then
		CloseMenu()
		return
	end
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	local r, g, b = RGB("general.backdrop", 0.06, 0.06, 0.06)
	ns.SetOutlineFill(menu.outline, r, g, b, math.max(0.95, Opacity()))
	ns.SetOutline(menu.outline, true, true)
	local width = owner:GetWidth()
	for index, item in ipairs(items) do
		local line = MenuLine(menu, index)
		line.value = item[1]
		line.text:SetText(item[2])
		if item[1] == chosen then
			line.text:SetTextColor(ar, ag, ab, 1)
		else
			Colour(line.text, item[3] or PLAIN)
		end
		line.light:SetColorTexture(ar, ag, ab, 0.14)
		line.button:ClearAllPoints()
		line.button:SetPoint("TOPLEFT", menu.frame, "TOPLEFT", 0, -2 - (index - 1) * L.MENU_LINE)
		line.button:SetPoint("TOPRIGHT", menu.frame, "TOPRIGHT", 0, -2 - (index - 1) * L.MENU_LINE)
		line.button:Show()
	end
	for index = #items + 1, #menu.lines do
		menu.lines[index].button:Hide()
	end
	menu.frame:SetSize(width, #items * L.MENU_LINE + 4)
	menu.frame:ClearAllPoints()
	menu.frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	menu.owner, menu.pick = owner, pick
	menu.frame:Show()
end

-- The filters -------------------------------------------------------------------------------------------------------------------------------------

-- The choices of each filter button: its items for the menu, the query field it sets, and the words of its value.
local function SlotItems()
	local items = { { false, T.ANY } }
	for _, slot in ipairs(SLOTS) do
		items[#items + 1] = { slot[1], slot[2] }
	end
	return items
end

local function ArmorItems()
	local items = { { false, T.ANY } }
	for _, armor in ipairs(ARMORS) do
		items[#items + 1] = { armor[1], SubName(ARMOR, armor[1], armor[2]) }
	end
	return items
end

local function WeaponItems()
	local items = { { false, T.ANY } }
	for _, weapon in ipairs(WEAPONS) do
		items[#items + 1] = { weapon[1], SubName(WEAPON, weapon[1], weapon[2]) }
	end
	return items
end

local function QualityItems()
	local items = {}
	for _, quality in ipairs(QUALITIES) do
		items[#items + 1] = { quality[1], T.FROM:format(quality[2]), QualityColour(quality[1]) }
	end
	return items
end

local KINDS = {
	slot = { items = SlotItems, field = "slot", words = T.SLOT, tip = T.SLOT_TIP, title = "Slot", any = false },
	armor = { items = ArmorItems, field = "armor", words = T.ARMOR, tip = T.ARMOR_TIP, title = "Armor", any = false, clears = "weapon" },
	weapon = { items = WeaponItems, field = "weapon", words = T.WEAPON, tip = T.WEAPON_TIP, title = "Weapon type", any = false, clears = "armor" },
	quality = { items = QualityItems, field = "quality", words = T.QUALITY, tip = T.QUALITY_TIP, title = "Quality", any = 0 },
}

-- The words of a filter's value.
local function ChoiceWords(kind)
	local def = KINDS[kind]
	local value = S.query[def.field]
	for _, item in ipairs(def.items()) do
		if item[1] == value or (value == nil and item[1] == false) then
			return def.words:format(item[2])
		end
	end
	return def.words:format(T.ANY)
end

local function PaintChoices()
	for kind, choice in pairs(S.choices) do
		choice.text:SetText(ChoiceWords(kind))
		Colour(choice.text, PLAIN)
	end
end

-- Sets a filter, false or nil being Any; Armor and Weapon type exclude each other.
local function SetChoice(kind, value)
	local def = KINDS[kind]
	if value == false then
		value = nil
	end
	S.query[def.field] = value
	if value ~= nil and def.clears then
		S.query[def.clears] = nil
	end
	PaintChoices()
	Search(true)
end

-- The next or the one before of a filter's values, for the mouse wheel.
local function StepChoice(kind, delta)
	local def = KINDS[kind]
	local items = def.items()
	local value = S.query[def.field]
	local at = 1
	for index, item in ipairs(items) do
		if item[1] == value or (value == nil and item[1] == false) then
			at = index
		end
	end
	at = math.max(1, math.min(#items, at - delta))
	SetChoice(kind, items[at][1])
end

local function MakeChoice(parent, kind, width)
	local def = KINDS[kind]
	local button = Own(CreateFrame("Button", nil, parent))
	button:SetSize(width, L.FIELD)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:EnableMouseWheel(true)
	Field(button)
	local light = Texture(button, "HIGHLIGHT")
	light:SetAllPoints(button)
	S.lights[#S.lights + 1] = light
	local text = Label(button)
	text:SetPoint("LEFT", button, "LEFT", 6, 0)
	text:SetPoint("RIGHT", button, "RIGHT", -16, 0)
	-- A small v at the right says the button opens a menu.
	S.strokes[#S.strokes + 1] = Stroke(button, "OVERLAY", "RIGHT", -12, 2, -8.5, -1.5)
	S.strokes[#S.strokes + 1] = Stroke(button, "OVERLAY", "RIGHT", -8.5, -1.5, -5, 2)
	button:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then
			CloseMenu()
			Run(SetChoice, kind, def.any)
		else
			local chosen = S.query[def.field]
			if chosen == nil then
				chosen = false
			end
			Run(OpenMenu, self, def.items(), chosen, function(value)
				SetChoice(kind, value)
			end)
		end
	end)
	button:SetScript("OnMouseWheel", function(_, delta)
		CloseMenu()
		Run(StepChoice, kind, delta)
	end)
	Tipped(button, def.title, def.tip)
	S.choices[kind] = { button = button, text = text }
	return button
end

-- A check box of its own: a box, its fill while on, and its words; get() reads it and set(on) writes it.
local function MakeCheck(parent, key, words, tip, get, set)
	local button = Own(CreateFrame("Button", nil, parent))
	button:SetHeight(L.FIELD)
	button:RegisterForClicks("LeftButtonUp")
	local box = Own(CreateFrame("Frame", nil, button))
	box:SetSize(L.CHECK, L.CHECK)
	box:SetPoint("LEFT", button, "LEFT", 0, 0)
	Field(box)
	local fill = Texture(box, "OVERLAY")
	fill:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
	local text = Label(button)
	text:SetPoint("LEFT", box, "RIGHT", 5, 0)
	text:SetText(words)
	Colour(text, PLAIN)
	local check = { button = button, fill = fill, text = text, get = get }
	local width = 0
	local ok, measured = pcall(text.GetUnboundedStringWidth, text)
	if ok and Finite(measured) and measured > 0 then
		width = measured
	else
		width = #words * 6
	end
	button:SetWidth(L.CHECK + 5 + math.ceil(width) + 2)
	button:SetScript("OnClick", function()
		Run(function()
			set(not get())
			fill:SetShown(get())
			Search(true)
		end)
	end)
	Tipped(button, words, tip)
	fill:SetShown(get())
	S.checks[key] = check
	return button
end

local function PaintChecks()
	for _, check in pairs(S.checks) do
		check.fill:SetShown(check.get() == true)
	end
end

-- An EditBox of the finder's own, in the look of a field; it gives the keyboard back on Enter, Escape and when it hides.
local function MakeBox(parent, width, numeric)
	local box = Own(CreateFrame("EditBox", nil, parent))
	box:SetSize(width, L.FIELD)
	box:SetAutoFocus(false)
	box:SetFontObject(FONT)
	box:SetTextInsets(6, 6, 0, 0)
	pcall(box.SetMaxLetters, box, numeric and 2 or 255)
	if numeric then
		pcall(box.SetNumeric, box, true)
		pcall(box.SetJustifyH, box, "CENTER")
	end
	Field(box)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnHide", function(self)
		self:ClearFocus()
	end)
	return box
end

local function BoxText(box)
	local ok, text = pcall(box.GetText, box)
	return ok and Text(text) or ""
end

-- The first upper level: the player's level + 5 with Level filter: Near your level, none with Any.
local function DefaultTo()
	if Opt("gearFindLevel") == "any" then
		return ""
	end
	local level = PlayerLevel()
	return level and tostring(math.floor(level) + 5) or ""
end

-- The rows of the tab the finder starts from: Level filter and Only what you can wear, taken again when the row changes, also over what the player set.
local function TakeRows()
	local levelRow, usableRow = Opt("gearFindLevel"), Opt("gearFindUsable")
	if levelRow ~= S.levelRow then
		S.levelRow, S.levelTyped = levelRow, false
	end
	if usableRow ~= S.usableRow then
		S.usableRow = usableRow
		S.query.usable = usableRow ~= false
	end
	if not S.levelTyped and S.to then
		S.writing = true
		pcall(S.to.SetText, S.to, DefaultTo())
		S.writing = false
	end
end

-- The list of results -----------------------------------------------------------------------------------------------------------------------------

-- The results of the page shown: in Best for me's order once it has worked them out, else in the search's.
local function PageItems()
	local first = (S.page - 1) * L.PER_PAGE + 1
	local items = {}
	for index = first, math.min(#S.results, first + L.PER_PAGE - 1) do
		items[#items + 1] = S.results[index]
	end
	local best = S.best
	if best.on and best.done then
		local order = {}
		for index, rec in ipairs(items) do
			order[rec] = index
		end
		table.sort(items, function(a, b)
			local sa, sb = best.scores[a.link], best.scores[b.link]
			local pa = type(sa) == "table" and sa.pct or nil
			local pb = type(sb) == "table" and sb.pct or nil
			if pa and pb and pa ~= pb then
				return pa > pb
			elseif pa and not pb then
				return true
			elseif pb and not pa then
				return false
			end
			return order[a] < order[b]
		end)
	end
	return items
end

local function Pages()
	return math.max(1, math.ceil(#S.results / L.PER_PAGE))
end

-- The words under an item's name: its slot and type, and where it is when it is not from the index.
local function InfoLine(rec)
	local parts = { TYPE_NAMES[rec.invType] or "" }
	local sub
	if rec.class == WEAPON and rec.subclass then
		local english
		for _, weapon in ipairs(WEAPONS) do
			if weapon[1] == rec.subclass then
				english = weapon[2]
			end
		end
		sub = SubName(WEAPON, rec.subclass, english)
	elseif rec.class == ARMOR and ARMOR_WORDS[rec.subclass] then
		sub = SubName(ARMOR, rec.subclass, ARMOR_WORDS[rec.subclass])
	end
	if sub and sub ~= parts[1] then
		parts[#parts + 1] = sub
	end
	if rec.where then
		parts[#parts + 1] = rec.where
	end
	return table.concat(parts, "  ·  ")
end

local function PaintRow(row, rec)
	row.rec = rec
	if not rec then
		row.button:Hide()
		return
	end
	local icon = Icon(rec.id)
	row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	row.name:SetText(rec.name)
	Colour(row.name, QualityColour(rec.quality))
	row.info:SetText(InfoLine(rec))
	Colour(row.info, DIM)
	row.ilvl:SetText(rec.ilvl and rec.ilvl > 0 and T.ILVL:format(rec.ilvl) or "")
	Colour(row.ilvl, PLAIN)
	local level = PlayerLevel()
	row.req:SetText(rec.req and rec.req > 0 and T.REQ:format(rec.req) or "")
	Colour(row.req, (level and rec.req and rec.req > level) and Tone("bad") or DIM)
	local score = S.best.on and S.best.scores[rec.link] or nil
	if type(score) == "table" then
		row.change:SetText((score.estimate and "~" or "") .. Percent(score.pct))
		Colour(row.change, score.pct > 0.0005 and Tone("good") or score.pct < -0.0005 and Tone("bad") or DIM)
		row.figure:SetText(FIGURE_WORDS[score.figure] or "")
		Colour(row.figure, DIM)
	else
		row.change:SetText("")
		row.figure:SetText("")
	end
	local nameRight = -(L.RIGHT + (S.best.on and L.CHANGE or 0))
	row.name:SetPoint("RIGHT", row.button, "RIGHT", nameRight, 0)
	row.info:SetPoint("RIGHT", row.button, "RIGHT", nameRight, 0)
	row.button:Show()
end

function PaintList()
	if not S.frame then
		return
	end
	local items = PageItems()
	local shown = #S.rows
	S.offset = math.max(0, math.min(S.offset, #items - shown))
	for index, row in ipairs(S.rows) do
		PaintRow(row, items[S.offset + index])
	end
	S.empty:SetShown(#items == 0)
end

-- The status line: the count and the page, else what is missing; Best for me's progress after it.
local function StatusText()
	local count = #S.results
	local words = count == 1 and T.COUNT_ONE or T.COUNT:format(Big(count))
	local pages = Pages()
	local text = pages > 1 and T.PAGE:format(words, S.page, pages) or words
	return text
end

local function Notes()
	local notes = {}
	local sources = S.query.sources
	if sources.all and not Index() then
		notes[#notes + 1] = T.NO_INDEX
	end
	if (sources.bags or sources.alts) and not BagsData() then
		notes[#notes + 1] = T.NO_BAGS
	end
	local best = S.best
	if best.on then
		if Fighting() and not best.done then
			notes[#notes + 1] = T.FIGHT
		elseif not best.done then
			notes[#notes + 1] = T.WORKING:format(best.count or 0, best.total or 0)
		elseif best.figure then
			notes[#notes + 1] = T.SORTED:format((FIGURE_WORDS[best.figure] or best.figure):lower())
		else
			notes[#notes + 1] = T.NO_FIGURE
		end
	end
	return notes
end

function Paint()
	if not S.frame then
		return
	end
	S.status:SetText(StatusText())
	local notes = Notes()
	S.foot:SetText(#notes > 0 and table.concat(notes, " ") or T.HINT)
	local pages = Pages()
	S.prev:SetAlpha(S.page > 1 and 1 or 0.3)
	S.next:SetAlpha(S.page < pages and 1 or 0.3)
	PaintChoices()
	PaintChecks()
	PaintLook()
	PaintList()
end

-- Best for me --------------------------------------------------------------------------------------------------------------------------------------

-- The chosen lines the player knows, as the item tooltips pass them (GearLines.lua:1663-1671).
local function KnownLines()
	local list = Ask(ns, "GearChosen")
	if type(list) ~= "table" or IsSecret(list) then
		return nil
	end
	local known = {}
	for _, line in ipairs(list) do
		if type(line) == "table" and line.known then
			known[#known + 1] = line
		end
	end
	return #known > 0 and known or nil
end

local function Role()
	if type(ns.PlayerRole) == "function" then
		local ok, role = pcall(ns.PlayerRole)
		if ok and Text(role) then
			return role
		end
	end
	return "damage"
end

-- What Best for me's figures were worked out from: SpellModel's version and the list's.
local function Version()
	return tostring(Ask(ns.SpellModel, "Version")) .. "|" .. tostring(Ask(ns, "GearListVersion"))
end

-- The Overall change of an item for the player: the best candidate slot's figure of the role, { pct, figure, estimate }, else false.
local function Score(link, lines, role)
	local gear = ns.GearModel
	local compare, totals = Fn(gear, "Compare"), Fn(gear, "Totals")
	if not (compare and totals and lines) then
		return false
	end
	local opts = { mode = "tooltip", listVersion = Ask(ns, "GearListVersion"), role = role, against = Opt("gearAgainst"),
		facing = Opt("gearFacing"), rules = Opt("gearRules"), lowRank = Opt("spellLowRank") ~= false }
	local ok, result = pcall(compare, link, lines, opts)
	if not ok then
		Report("Compare", result)
		return false
	end
	if type(result) ~= "table" or type(result.candidates) ~= "table" then
		return false
	end
	local best = false
	for _, candidate in ipairs(result.candidates) do
		if type(candidate) == "table" then
			local okTotals, got = pcall(totals, candidate, lines, opts)
			if not okTotals then
				Report("Totals", got)
			elseif type(got) == "table" then
				for _, figure in ipairs(FIGURES[role] or FIGURES.damage) do
					local tot = got[figure]
					if type(tot) == "table" and Finite(tot.pct) then
						if not best or tot.pct > best.pct then
							best = { pct = tot.pct, figure = figure, estimate = tot.estimate == true }
						end
						break
					end
				end
			end
		end
	end
	return best
end

-- Starts Best for me on the page shown: its items are worked out at the next looks.
local function BestStart()
	local best = S.best
	best.on, best.done, best.figure = true, false, nil
	best.started = Now()
	best.version = Version()
	best.count, best.total = 0, 0
end

-- A few items of the page at a look, out of combat: each once the client has it, or false after LOAD seconds; the page is sorted when all are done.
local function BestStep()
	local best = S.best
	if not best.on then
		return
	end
	local version = Version()
	if version ~= best.version then
		best.scores, best.version, best.done, best.started = {}, version, false, Now()
	end
	if best.done then
		return
	end
	-- G.Compare works nothing out in a fight (GearModel.lua's G.Compare): the status line says Best for me waits.
	local fighting = Fighting()
	if fighting ~= best.fighting then
		best.fighting = fighting
		Paint()
	end
	if fighting then
		return
	end
	local lines, role = KnownLines(), Role()
	local items = {}
	local first = (S.page - 1) * L.PER_PAGE + 1
	for index = first, math.min(#S.results, first + L.PER_PAGE - 1) do
		items[#items + 1] = S.results[index]
	end
	local worked, left, count, before = 0, 0, 0, best.count
	local late = Now() - (best.started or 0) > LOAD
	for _, rec in ipairs(items) do
		if best.scores[rec.link] == nil then
			if worked < STEP and ItemInfo(rec.link) then
				best.scores[rec.link] = Score(rec.link, lines, role)
				worked = worked + 1
			elseif late and not ItemInfo(rec.link) then
				best.scores[rec.link] = false
			else
				Want(rec.id)
				left = left + 1
			end
		end
		if best.scores[rec.link] ~= nil then
			count = count + 1
		end
	end
	best.count, best.total = count, #items
	if left == 0 and count == #items then
		best.done = true
		local figures = {}
		for _, rec in ipairs(items) do
			local score = best.scores[rec.link]
			if type(score) == "table" then
				figures[score.figure] = (figures[score.figure] or 0) + 1
			end
		end
		local most = 0
		for figure, n in pairs(figures) do
			if n > most then
				best.figure, most = figure, n
			end
		end
		S.offset = 0
	end
	if worked > 0 or best.done or count ~= before then
		Paint()
	end
end

local function BestToggle()
	if S.best.on then
		S.best.on, S.best.done = false, false
		S.offset = 0
	else
		BestStart()
	end
	Paint()
end

-- Clicks --------------------------------------------------------------------------------------------------------------------------------------------

-- The whole link of an item for the chat line, or nil while the client has not loaded it (asked for).
local function WholeLink(rec)
	if rec.link:find("|H", 1, true) then
		return rec.link
	end
	local _, whole = ItemInfo(rec.link)
	if whole then
		return whole
	end
	Want(rec.id)
	return nil
end

local function LinkInChat(rec)
	local link = WholeLink(rec)
	if not link then
		print(T.NOT_LOADED)
		return
	end
	local insert = Fn(_G.ChatFrameUtil, "InsertLink")
	if insert then
		pcall(insert, link)
	end
end

local function TryOn(rec)
	if Fighting() then
		print(T.TRY_FIGHT)
		return
	end
	local dress = Client(nil, "DressUpItemLink")
	if dress then
		pcall(dress, WholeLink(rec) or rec.link)
	end
end

local function RowClick(row, mouse)
	local rec = row.rec
	if not rec then
		return
	end
	if mouse == "LeftButton" and Modified("CHATLINK") then
		LinkInChat(rec)
	elseif mouse == "LeftButton" and Modified("DRESSUP") then
		TryOn(rec)
	elseif mouse == "RightButton" then
		local against = Fn(ns, "GearWindowAgainst")
		if against then
			local ok, err = pcall(against, rec.link)
			if not ok then
				Report("GearWindowAgainst", err)
			end
		else
			print(T.NO_AGAINST)
		end
	else
		local show = Fn(ns, "GearWindowShow")
		if show then
			local ok, err = pcall(show, rec.link)
			if not ok then
				Report("GearWindowShow", err)
			end
		end
	end
end

-- The item's own tooltip (SetHyperlink, which the item tooltips of GearLines.lua add to) and what a click does, never in a fight.
local function RowTip(row)
	local rec, tip = row.rec, Tooltip()
	if not rec or not tip or Fighting() then
		return
	end
	tip:SetOwner(row.button, "ANCHOR_RIGHT")
	local ok, built = pcall(tip.SetHyperlink, tip, rec.link)
	if not (ok and not IsSecret(built)) then
		tip:SetText(rec.name, PLAIN[1], PLAIN[2], PLAIN[3])
	end
	if rec.where then
		tip:AddLine(rec.where, DIM[1], DIM[2], DIM[3])
	end
	tip:AddLine(T.ROW_TIP, DIM[1], DIM[2], DIM[3], true)
	tip:Show()
end

local function Scroll(delta)
	local items = #PageItems()
	local most = math.max(0, items - #S.rows)
	local offset = math.max(0, math.min(most, S.offset - delta * 2))
	if offset ~= S.offset then
		S.offset = offset
		PaintList()
	end
end

local function Turn(step)
	local page = math.max(1, math.min(Pages(), S.page + step))
	if page ~= S.page then
		S.page, S.offset = page, 0
		if S.best.on then
			BestStart()
		end
		Paint()
	end
end

-- Searching ---------------------------------------------------------------------------------------------------------------------------------------

-- The query as the controls hold it.
local function ReadControls()
	local q = S.query
	q.text = S.box and BoxText(S.box) or q.text
	q.minLevel = S.from and tonumber(BoxText(S.from)) or nil
	q.maxLevel = S.to and tonumber(BoxText(S.to)) or nil
	return q
end

local function QueryKey(q)
	local sources = {}
	for _, source in ipairs(SOURCES) do
		sources[#sources + 1] = q.sources[source[1]] and source[1] or "-"
	end
	return table.concat({ q.text or "", tostring(q.slot), tostring(q.armor), tostring(q.weapon), tostring(q.minLevel), tostring(q.maxLevel),
		tostring(q.quality), tostring(q.usable), table.concat(sources, ",") }, "|")
end

-- Searches again with what the controls hold. A new query starts on its first page; the same one (an item loaded since) keeps the page.
function Search(fresh)
	if not S.frame then
		return
	end
	local q = ReadControls()
	local key = QueryKey(q)
	local results, waiting = Find(q)
	S.results = results
	S.waiting = waiting
	if fresh then
		S.tries = 0
	end
	if key ~= S.key then
		S.key, S.page, S.offset = key, 1, 0
		if S.best.on then
			BestStart()
		end
	else
		S.page = math.min(S.page, Pages())
	end
	S.searchAt = Now()
	Paint()
end

-- The frame ---------------------------------------------------------------------------------------------------------------------------------------

-- The title bar: the title, Dock, Minimize and the cross. A drag of it moves the finder out of a fight (D.DragStart), a right-click docks it (D.Dock).
local function MakeBar(frame)
	local bar = Own(CreateFrame("Frame", nil, frame))
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(L.BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Run(D.DragStart)
	end)
	bar:SetScript("OnDragStop", function()
		Run(D.DragStop)
	end)
	bar:SetScript("OnMouseUp", function(_, mouse)
		if mouse == "RightButton" then
			Run(D.Dock)
		end
	end)
	-- A drag that the finder's hiding cut short ends where it was let go.
	bar:SetScript("OnHide", function()
		if S.moving then
			pcall(D.DragStop)
		end
	end)
	Tipped(bar, T.TITLE, T.BAR_TIP)
	S.bar = bar
	S.title = Label(bar, TITLE_FONT)
	S.title:SetPoint("LEFT", bar, "LEFT", L.PAD, 0)
	S.title:SetText(T.TITLE)
	local close = Own(CreateFrame("Button", nil, bar))
	close:SetSize(L.CLOSE, L.CLOSE)
	close:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	close:RegisterForClicks("LeftButtonUp")
	S.strokes[#S.strokes + 1] = Stroke(close, "OVERLAY", "TOPLEFT", 5, -5, 13, -13)
	S.strokes[#S.strokes + 1] = Stroke(close, "OVERLAY", "TOPLEFT", 5, -13, 13, -5)
	S.hoverStrokes[#S.hoverStrokes + 1] = Stroke(close, "HIGHLIGHT", "TOPLEFT", 5, -5, 13, -13)
	S.hoverStrokes[#S.hoverStrokes + 1] = Stroke(close, "HIGHLIGHT", "TOPLEFT", 5, -13, 13, -5)
	close:SetScript("OnClick", function()
		Close()
	end)
	S.close = close
	S.barRule = Texture(frame, "ARTWORK")
	S.barRule:SetHeight(1)
	S.barRule:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.BAR)
	S.barRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, -L.BAR)
end

local function MakeSearch(frame, y)
	local box = MakeBox(frame, L.INNER, false)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, y)
	S.box = box
	S.hint = Label(box)
	S.hint:SetPoint("LEFT", box, "LEFT", 6, 0)
	S.hint:SetPoint("RIGHT", box, "RIGHT", -6, 0)
	S.hint:SetText(T.SEARCH)
	local function Hint()
		S.hint:SetShown(BoxText(box) == "" and not box:HasFocus())
	end
	box:SetScript("OnTextChanged", function(_, typed)
		Hint()
		if typed then
			S.typedAt = Now()
		end
	end)
	box:SetScript("OnEditFocusGained", Hint)
	box:SetScript("OnEditFocusLost", Hint)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		S.typedAt = nil
		if S.min then
			Run(D.Collapse, false)
		end
		Run(Search, true)
	end)
end

local function MakeFilters(frame, y)
	local slot = MakeChoice(frame, "slot", L.HALF)
	slot:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, y)
	local armor = MakeChoice(frame, "armor", L.HALF)
	armor:SetPoint("TOPLEFT", slot, "TOPRIGHT", L.GAP, 0)
	local weapon = MakeChoice(frame, "weapon", L.HALF)
	weapon:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -L.GAP)
	local quality = MakeChoice(frame, "quality", L.HALF)
	quality:SetPoint("TOPLEFT", weapon, "TOPRIGHT", L.GAP, 0)
	-- Level from and to, and Only what you can wear.
	S.levelLabel = Label(frame)
	S.levelLabel:SetPoint("TOPLEFT", weapon, "BOTTOMLEFT", 0, -L.GAP - 4)
	S.levelLabel:SetText(T.LEVEL)
	local from = MakeBox(frame, L.LEVEL_BOX, true)
	from:SetPoint("TOPLEFT", weapon, "BOTTOMLEFT", 36, -L.GAP)
	S.toLabel = Label(frame)
	S.toLabel:SetPoint("LEFT", from, "RIGHT", 6, 0)
	S.toLabel:SetText(T.TO)
	local to = MakeBox(frame, L.LEVEL_BOX, true)
	to:SetPoint("LEFT", from, "RIGHT", 22, 0)
	S.from, S.to = from, to
	for _, box in ipairs({ from, to }) do
		box:SetScript("OnTextChanged", function(self, typed)
			if typed and not S.writing then
				if self == to then
					S.levelTyped = true
				end
				S.typedAt = Now()
			end
		end)
		Tipped(box, T.LEVEL, T.LEVEL_TIP)
	end
	local usable = MakeCheck(frame, "usable", T.USABLE, T.USABLE_TIP, function()
		return S.query.usable == true
	end, function(on)
		S.query.usable = on
	end)
	usable:SetPoint("TOPLEFT", quality, "BOTTOMLEFT", 0, -L.GAP)
	-- The sources, side by side.
	local left = L.PAD
	for _, source in ipairs(SOURCES) do
		local key = source[1]
		local check = MakeCheck(frame, key, source[2], T.SOURCE_TIP[key], function()
			return S.query.sources[key] == true
		end, function(on)
			S.query.sources[key] = on or nil
		end)
		check:SetPoint("TOPLEFT", frame, "TOPLEFT", left, y - 3 * (L.FIELD + L.GAP))
		left = left + check:GetWidth() + 12
	end
end

-- A small button of text: the arrows and Best for me.
local function MakeTextButton(frame, words, width, tip, click)
	local button = Own(CreateFrame("Button", nil, frame))
	button:SetSize(width, L.FIELD)
	button:RegisterForClicks("LeftButtonUp")
	Field(button)
	local light = Texture(button, "HIGHLIGHT")
	light:SetAllPoints(button)
	S.lights[#S.lights + 1] = light
	local text = Label(button)
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	text:SetText(words)
	Colour(text, PLAIN)
	button:SetScript("OnClick", function()
		Run(click)
	end)
	Tipped(button, words, tip)
	return button, text
end

local function MakeStatus(frame, y)
	local best, bestText = MakeTextButton(frame, T.BEST, L.BEST, T.BEST_TIP, BestToggle)
	best:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, y)
	S.best.button, S.best.text = best, bestText
	local nextPage = MakeTextButton(frame, ">", L.ARROW, T.NEXT, function()
		Turn(1)
	end)
	nextPage:SetPoint("RIGHT", best, "LEFT", -L.GAP, 0)
	local prevPage = MakeTextButton(frame, "<", L.ARROW, T.PREV, function()
		Turn(-1)
	end)
	prevPage:SetPoint("RIGHT", nextPage, "LEFT", -2, 0)
	S.prev, S.next = prevPage, nextPage
	S.status = Label(frame)
	S.status:SetPoint("LEFT", frame, "TOPLEFT", L.PAD, y - L.FIELD / 2)
	S.status:SetPoint("RIGHT", prevPage, "LEFT", -L.GAP, 0)
	S.rule = Texture(frame, "ARTWORK")
	S.rule:SetHeight(1)
	S.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, y - L.FIELD - L.GAP)
	S.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, y - L.FIELD - L.GAP)
end

-- One row of results: a button that takes a click of either side, its light, the icon, name and words, and the right columns.
local function MakeRow(list)
	local button = Own(CreateFrame("Button", nil, list))
	button:SetHeight(L.ROW)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local row = { button = button }
	row.light = Texture(button, "HIGHLIGHT")
	row.light:SetAllPoints(button)
	S.lights[#S.lights + 1] = row.light
	local box = Own(CreateFrame("Frame", nil, button))
	box:SetSize(L.ICON, L.ICON)
	box:SetPoint("LEFT", button, "LEFT", 2, 0)
	Field(box)
	row.icon = Texture(box, "ARTWORK")
	row.icon:SetAllPoints(box)
	local crop = Crop()
	row.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	row.name = Label(button)
	row.name:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 1)
	row.info = Label(button)
	row.info:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, -1)
	row.ilvl = Label(button)
	row.ilvl:SetJustifyH("RIGHT")
	row.ilvl:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -3)
	row.ilvl:SetWidth(L.RIGHT - 4)
	row.req = Label(button)
	row.req:SetJustifyH("RIGHT")
	row.req:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 3)
	row.req:SetWidth(L.RIGHT - 4)
	row.change = Label(button)
	row.change:SetJustifyH("RIGHT")
	row.change:SetPoint("TOPRIGHT", button, "TOPRIGHT", -L.RIGHT, -3)
	row.change:SetWidth(L.CHANGE - 4)
	row.figure = Label(button)
	row.figure:SetJustifyH("RIGHT")
	row.figure:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -L.RIGHT, 3)
	row.figure:SetWidth(L.CHANGE - 4)
	button:SetScript("OnClick", function(_, mouse)
		Run(RowClick, row, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(RowTip, row)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	button:EnableMouseWheel(true)
	button:SetScript("OnMouseWheel", function(_, delta)
		Run(Scroll, delta)
	end)
	S.owners[#S.owners + 1] = button
	return row
end

-- Rows for the height of the list, worked out from the finder's height (the client may not have laid the list out yet): as many as fit, made as
-- needed, kept when the list shrinks (S.made) and placed from the top.
local function LayoutRows()
	local height = (S.height or L.MIN_HEIGHT) - S.listTop - L.PAD - L.FOOT
	local count = math.max(1, math.floor(height / L.ROW))
	S.rows = {}
	for index = 1, math.max(count, #S.made) do
		local row = S.made[index]
		if index <= count then
			if not row then
				row = MakeRow(S.list)
				S.made[index] = row
			end
			row.button:ClearAllPoints()
			row.button:SetPoint("TOPLEFT", S.list, "TOPLEFT", 0, -(index - 1) * L.ROW)
			row.button:SetPoint("TOPRIGHT", S.list, "TOPRIGHT", 0, -(index - 1) * L.ROW)
			S.rows[index] = row
		else
			row.rec = nil
			row.button:Hide()
		end
	end
	PaintList()
end

local function MakeList(frame, y)
	local list = Own(CreateFrame("Frame", nil, frame))
	list:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, y)
	list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.PAD, L.PAD + L.FOOT)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		Run(Scroll, delta)
	end)
	S.list, S.listTop = list, -y
	S.empty = Label(list)
	S.empty:SetPoint("TOPLEFT", list, "TOPLEFT", 2, -6)
	S.empty:SetPoint("TOPRIGHT", list, "TOPRIGHT", -2, -6)
	S.empty:SetWordWrap(true)
	S.empty:SetText(T.NONE)
	S.empty:Hide()
	S.foot = Label(frame)
	S.foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", L.PAD, L.PAD)
	S.foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.PAD, L.PAD)
	S.foot:SetHeight(L.FOOT)
	S.foot:SetWordWrap(true)
	pcall(S.foot.SetMaxLines, S.foot, 2)
	pcall(S.foot.SetJustifyV, S.foot, "BOTTOM")
end

-- The finder's height: the window's, at least MIN_HEIGHT, or its title bar's while it is minimized; its strata, and where it hangs (D.Place).
local function Fit()
	local parent = S.parent
	local ok, height = pcall(parent.GetHeight, parent)
	local want = math.max(L.MIN_HEIGHT, ok and Finite(height) and math.floor(height + 0.5) or 0)
	if want ~= S.height then
		S.height = want
		S.frame:SetHeight(S.min and L.BAR or want)
		LayoutRows()
		D.Keep()
	end
	D.Strata()
	D.Place()
end

-- The looks while the finder shows: whether it may run, its height, typing that settled, items of the bags that loaded and Best for me.
local function Look()
	Fit()
	local now = Now()
	if S.typedAt and now - S.typedAt >= SETTLE then
		S.typedAt = nil
		Search(true)
	elseif S.waiting and S.tries < TRIES and now - (S.searchAt or 0) >= WAIT then
		S.tries = S.tries + 1
		Search(false)
	end
	BestStep()
end

local function Showing()
	TakeRows()
	S.elapsed = 0
	S.placed, S.strata, S.lifted = nil, nil, nil
	Fit()
	D.Handle()
	Search(true)
end

-- Whatever hid the finder: a drag of its title bar ends where it was let go, its box in the movers goes, the menu closes, its tooltips go, and when
-- the window hid it the finder stays closed until it is opened again. Plain code, so it also runs once the part has stopped.
local function Hiding()
	if S.moving then
		pcall(D.DragStop)
	end
	D.Handle()
	CloseMenu()
	for _, owner in ipairs(S.owners) do
		Untip(owner)
	end
	local parent = S.parent
	local ok, shown = pcall(parent.IsShown, parent)
	if not (ok and shown == true) and S.frame:IsShown() then
		pcall(S.frame.Hide, S.frame)
	end
end

-- The frame and everything in it, once, on UIParent beside the window (parent), minimized as the character left it. Everything under the title bar
-- is on the body, which minimizing hides; the search box is on the finder, so it can go on the title bar. Not toplevel, and the levels of its boxes
-- follow its own at each look (D.Strata, D.Levels).
local function Make(parent)
	local frame = Own(CreateFrame("Frame", NAME, UIParent))
	S.parent = parent
	S.lights, S.strokes, S.hoverStrokes = {}, {}, {}
	frame:SetSize(L.WIDTH, L.MIN_HEIGHT)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:EnableMouse(true)
	frame:Hide()
	S.frame = frame
	S.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "windows")
	MakeBar(frame)
	local body = Own(CreateFrame("Frame", nil, frame))
	body:SetAllPoints(frame)
	S.body = body
	local y = -(L.BAR + L.GAP + 2)
	S.boxY = y
	MakeSearch(frame, y)
	y = y - L.FIELD - L.GAP
	MakeFilters(body, y)
	S.boxes = { S.box, S.from, S.to }
	y = y - 4 * (L.FIELD + L.GAP)
	MakeStatus(body, y)
	y = y - L.FIELD - 2 * L.GAP - 1
	MakeList(body, y)
	D.MakeButtons(S.bar)
	frame:SetScript("OnShow", function()
		Run(Showing)
	end)
	frame:SetScript("OnHide", function()
		Hiding()
	end)
	-- It closes once the module or the part is off, and when the window is not shown (it closes the finder as it hides, GearWindow.lua's Hiding).
	frame:SetScript("OnUpdate", function(_, elapsed)
		S.elapsed = S.elapsed + (Finite(elapsed) and elapsed or 0)
		if S.elapsed < LOOK then
			return
		end
		S.elapsed = 0
		local ok, shown = pcall(parent.IsShown, parent)
		if Allowed() and ok and shown == true then
			Run(Look)
		else
			Close()
		end
	end)
	S.height = nil
	TakeRows()
	PaintLook()
	local kept = D.Record()
	D.Collapse(kept ~= nil and kept.min == true)
	D.Place()
end

-- The window the finder docks to: FlatUIGear, a frame of Flat UI's own, or nil before GearWindow.lua made it.
local function Window()
	local frame = _G[PARENT]
	if type(frame) == "table" and not IsSecret(frame) and ns.Own[frame] then
		return frame
	end
	return nil
end

local function WindowShown(frame)
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown == true
end

-- Placing and minimizing ---------------------------------------------------------------------------------------------------------------------------

-- What is kept for the character (FlatUICharDB.gearFinder, ns.Character): w and h, the size of the finder's box in the movers (BoxSize of
-- Movers.lua), and min (minimized). Its spot is the movers' (D.Free); the one 0.5.20 kept here (free, x and y) is dropped. Made when make is true;
-- else nil without.
function D.Record(make)
	local char = type(ns.Character) == "function" and ns.Character() or nil
	if type(char) ~= "table" or IsSecret(char) then
		return nil
	end
	local kept = char.gearFinder
	if type(kept) ~= "table" then
		if not make then
			return nil
		end
		kept = {}
		char.gearFinder = kept
	end
	kept.free, kept.x, kept.y = nil, nil, nil
	return kept
end

-- The handle of the finder in the movers drawn again, so its box has the finder's place and size, or goes while the finder is closed (the gate,
-- ns.GearSearchShown). Not while its title bar is dragged: the drop saves the spot and draws it then. A drag of its box the movers leave alone.
function D.Handle()
	if S.moving then
		return
	end
	local kit = ns.MoverKit
	local show = type(kit) == "table" and kit.ShowHandle or nil
	if type(show) == "function" then
		pcall(show, NAME)
	end
end

-- The size of the box kept for the character: the title bar's height while minimized, else the finder's.
function D.Keep()
	local kept = D.Record(true)
	local height = S.min and L.BAR or (S.height or L.MIN_HEIGHT)
	if kept and (kept.w ~= L.WIDTH or kept.h ~= height) then
		kept.w, kept.h = L.WIDTH, height
		D.Handle()
	end
end

-- The finder's spot in the movers while one is saved (ns.MoverSaved, ns.MoverSpot), else nil: its top left corner, in the units of UIParent from
-- the screen's bottom left.
function D.Free()
	local spot = Fn(ns, "MoverSpot")
	if not spot or Ask(ns, "MoverSaved", NAME) ~= true then
		return nil
	end
	local ok, x, y = pcall(spot, NAME, "TOPLEFT")
	if ok and Finite(x) and Finite(y) then
		return x, y
	end
	return nil
end

-- The width and height of UIParent, or nil.
function D.Screen()
	local okW, width = pcall(UIParent.GetWidth, UIParent)
	local okH, height = pcall(UIParent.GetHeight, UIParent)
	if okW and okH and Finite(width) and Finite(height) and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

-- Left, bottom, width and height of a frame in the units of UIParent (GetRect and GetEffectiveScale), or nil.
function D.Rect(frame)
	local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okScale and okBase and Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and Finite(scale) and Finite(base))
		or base <= 0 then
		return nil
	end
	local k = scale / base
	return left * k, bottom * k, width * k, height * k
end

-- The side of the window the finder hangs on while docked (header): its right while the screen has room for the finder there, else its left while
-- that side has room, else its right, where the clamp to the screen keeps it in sight over the window's edge.
function D.Side(left, right, screen)
	if Finite(left) and Finite(right) and Finite(screen) and right + L.DOCK + L.WIDTH > screen and left - L.DOCK - L.WIDTH >= 0 then
		return "left"
	end
	return "right"
end

-- Where the top left corner of a docked finder is, in the units of UIParent from its bottom left: beside the window while it shows, else beside
-- the window's spot in the movers (ns.MoverSpot and the BoxSize of its entry), on the screen. Nil when neither says.
function D.Hang()
	local left, bottom, width, height
	local window = Window()
	if window and WindowShown(window) then
		left, bottom, width, height = D.Rect(window)
	end
	if not left then
		local kit = ns.MoverKit
		local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[PARENT] or nil
		if not (info and type(kit.BoxSize) == "function" and type(ns.MoverSpot) == "function") then
			return nil
		end
		local ok, x, y = pcall(ns.MoverSpot, PARENT, "TOPLEFT")
		local okSize, w, h = pcall(kit.BoxSize, info)
		if not (ok and okSize and Finite(x) and Finite(y) and Finite(w) and Finite(h)) then
			return nil
		end
		left, bottom, width, height = x, y - h, w, h
	end
	local screen = D.Screen()
	local x = left + width + L.DOCK
	if D.Side(left, left + width, screen) == "left" then
		x = left - L.DOCK - L.WIDTH
	end
	if screen then
		x = math.max(0, math.min(x, screen - L.WIDTH))
	end
	return x, bottom + height
end

-- Hangs the finder from its spot in the movers while one is saved (D.Free), else at the window's edge, where it moves with the window. Not while
-- it is dragged.
function D.Place()
	local frame, window = S.frame, S.parent
	if not frame or S.moving then
		return
	end
	local x, y = D.Free()
	local key
	if x then
		key = ("%.2f:%.2f"):format(x, y)
	else
		local okLeft, left = pcall(window.GetLeft, window)
		local okRight, right = pcall(window.GetRight, window)
		key = D.Side(okLeft and left, okRight and right, (D.Screen()))
	end
	if key == S.placed then
		return
	end
	S.placed = key
	frame:ClearAllPoints()
	if x then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	elseif key == "left" then
		frame:SetPoint("TOPRIGHT", window, "TOPLEFT", -L.DOCK, 0)
	else
		frame:SetPoint("TOPLEFT", window, "TOPRIGHT", L.DOCK, 0)
	end
	D.Bar()
end

-- The strata above each strata a window can have, never above FULLSCREEN, so the finder's menus (FULLSCREEN_DIALOG) stay above it.
D.OVER = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN" }

-- The finder lies one strata above the window's (header, Strata and levels): HIGH over MEDIUM and FULLSCREEN over DIALOG (GearWindow.lua's Raise),
-- at its own level (L.LEVEL), so no window of the window's strata, which the game raises at a click, lies over it. In the window's strata while
-- the options window (HIGH, ns.PanelShown) shows over a window in MEDIUM, under it as its window is; MEDIUM while the movers are open
-- (ns.MoverKit.IsOpen), under their boxes (HIGH, Movers.lua:1984), so it covers none of them; Minimize then sits above them, so the finder can be
-- minimized out of their way. The menu keeps its own strata. Then the levels of its boxes (D.Levels).
function D.Strata()
	local kit = ns.MoverKit
	local open = type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
	local strata = "MEDIUM"
	if not open then
		local window = S.parent
		local ok, answer = pcall(window.GetFrameStrata, window)
		local own = ok and not IsSecret(answer) and type(answer) == "string" and answer or "MEDIUM"
		strata = D.OVER[own] or "FULLSCREEN"
		if own == "MEDIUM" and Ask(ns, "PanelShown") == true then
			strata = own
		end
	end
	if strata ~= S.strata then
		S.strata, S.lifted = strata, nil
		S.frame:SetFrameStrata(strata)
		S.frame:SetFrameLevel(L.LEVEL)
		if S.menu then
			S.menu.frame:SetFrameStrata("FULLSCREEN_DIALOG")
		end
	end
	if open ~= S.lifted then
		S.lifted = open
		S.fold:SetFrameStrata(open and "HIGH" or strata)
	end
	D.Levels()
end

-- A frame of the finder at a level, set only when it is not there.
function D.Level(frame, level)
	local ok, now = pcall(frame.GetFrameLevel, frame)
	if not (ok and now == level) then
		frame:SetFrameLevel(level)
	end
end

-- The levels of the finder's own frames from its level as it is now, at each look: the search box and the level fields L.ABOVE over it, over the
-- title bar and the body (+ 1) and their buttons (+ 2), so the box takes its click on the title bar of a minimized finder too; Minimize one over the
-- title bar, or L.LIFT while it is above the boxes of the movers. The game sets the levels of a frame's children again when the frame's level
-- changes, so a level set once does not last (header).
function D.Levels()
	local ok, level = pcall(S.frame.GetFrameLevel, S.frame)
	if not (ok and Finite(level)) then
		return
	end
	for _, box in ipairs(S.boxes) do
		D.Level(box, level + L.ABOVE)
	end
	D.Level(S.fold, S.lifted and L.LIFT or level + 2)
end

-- The title bar as the finder is: Dock while it hangs from a spot of its own, Minimize's mark (a bar, or a square while minimized), and the search
-- box under the title bar, or on it while minimized where it leaves its least width between the title and the buttons, else hidden.
function D.Bar()
	if not S.fold then
		return
	end
	local free = D.Free() ~= nil
	S.dock:SetShown(free)
	for _, line in ipairs(S.foldLines.full) do
		line:SetShown(not S.min)
	end
	for _, line in ipairs(S.foldLines.min) do
		line:SetShown(S.min == true)
	end
	local box = S.box
	box:ClearAllPoints()
	if not S.min then
		box:SetPoint("TOPLEFT", S.frame, "TOPLEFT", L.PAD, S.boxY)
		box:SetWidth(L.INNER)
		box:Show()
		return
	end
	local ok, words = pcall(S.title.GetStringWidth, S.title)
	local used = L.PAD + (ok and Finite(words) and words or 80) + L.GAP
	local buttons = 4 + 2 * L.CLOSE + 2 + (free and L.GAP + L.DOCK_W or 0) + L.GAP
	if L.WIDTH - used - buttons >= L.MIN_BOX then
		box:SetPoint("LEFT", S.title, "RIGHT", L.GAP, 0)
		box:SetPoint("RIGHT", free and S.dock or S.fold, "LEFT", -L.GAP, 0)
		box:Show()
	else
		box:Hide()
	end
end

-- Minimizes the finder to its title bar, or opens it again; kept for the character, and its box in the movers takes that size.
function D.Collapse(on)
	S.min = on == true
	local kept = D.Record(true)
	if kept then
		kept.min = S.min or nil
	end
	if not S.frame then
		return
	end
	CloseMenu()
	S.body:SetShown(not S.min)
	S.barRule:SetShown(not S.min)
	S.frame:SetHeight(S.min and L.BAR or (S.height or L.MIN_HEIGHT))
	D.Bar()
	D.Keep()
end

-- Docks the finder at the window's edge again: its spot is forgotten as a reset of its box in the movers forgets it (ns.MoverKit.Restore), so
-- their Undo and Reset all know it.
function D.Dock()
	local kit = ns.MoverKit
	if type(kit) == "table" and type(kit.Restore) == "function" then
		kit.Restore(NAME, nil)
	end
	S.placed = nil
	D.Place()
	D.Handle()
end

-- A drag of the title bar, out of a fight (StartMoving, WL/uiobjects.yaml:4797), as the window's title bar drags the window.
function D.DragStart()
	if S.moving or not S.frame or Fighting() then
		return
	end
	CloseMenu()
	Untip(S.bar)
	S.frame:StartMoving()
	S.moving = true
end

-- The finder was let go (StopMovingOrSizing, :4813, with SetUserPlaced, :4778, so the client keeps no place of its own): a box of its size, its
-- top left corner at the finder's, is saved as its spot in the movers (ns.MoverKit.Commit), as a drop of its box saves one, so their Undo and Reset
-- all know it, and the finder hangs from that spot (ns.GearSearchMoved).
function D.DragStop()
	if not S.moving then
		return
	end
	S.moving = false
	local frame = S.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	local left, bottom, width, height = D.Rect(frame)
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	if left and info and type(kit.Commit) == "function" then
		kit.Commit(NAME, info, left, bottom, width, height)
	end
	S.placed = nil
	D.Place()
	D.Handle()
end

-- Dock, Minimize and their place on the title bar, left of the cross; Minimize's marks are a bar and a square, drawn as the cross is.
function D.MakeButtons(bar)
	local fold = Own(CreateFrame("Button", nil, bar))
	fold:SetSize(L.CLOSE, L.CLOSE)
	fold:SetPoint("RIGHT", S.close, "LEFT", -2, 0)
	fold:RegisterForClicks("LeftButtonUp")
	S.fold = fold
	S.foldLines = { full = {}, min = {} }
	local marks = { full = { { 5, -12, 13, -12 } }, min = { { 5, -5, 13, -5 }, { 13, -5, 13, -13 }, { 13, -13, 5, -13 }, { 5, -13, 5, -5 } } }
	for state, lines in pairs(marks) do
		for _, at in ipairs(lines) do
			local line = Stroke(fold, "OVERLAY", "TOPLEFT", at[1], at[2], at[3], at[4])
			local hover = Stroke(fold, "HIGHLIGHT", "TOPLEFT", at[1], at[2], at[3], at[4])
			S.strokes[#S.strokes + 1] = line
			S.hoverStrokes[#S.hoverStrokes + 1] = hover
			table.insert(S.foldLines[state], line)
			table.insert(S.foldLines[state], hover)
		end
	end
	fold:SetScript("OnClick", function()
		Run(D.Collapse, not S.min)
	end)
	Tipped(fold, function()
		return S.min and T.RESTORE or T.MINIMIZE
	end, T.FOLD_TIP)
	local dock = MakeTextButton(bar, T.DOCK, L.DOCK_W, T.DOCK_TIP, D.Dock)
	dock:SetPoint("RIGHT", fold, "LEFT", -L.GAP, 0)
	dock:Hide()
	S.dock = dock
end

-- Opens the finder, the window first. When the window waits for the end of a fight, the finder waits for it too.
local function Open()
	local parent = Window()
	if not (parent and WindowShown(parent)) then
		local show = Fn(ns, "GearWindowShow")
		if show then
			local ok, err = pcall(show)
			if not ok then
				Report("GearWindowShow", err)
			end
		end
		parent = Window()
	end
	if not (parent and WindowShown(parent)) then
		if Fighting() and not S.pending then
			S.pending = true
			print(T.AFTER_FIGHT)
			ns.OutOfCombat(function()
				if S.pending then
					S.pending = false
					local window = Window()
					if Allowed() and window and WindowShown(window) then
						Run(Open)
					end
				end
			end)
		end
		return
	end
	S.pending = false
	if not S.frame then
		Make(parent)
	end
	if S.frame:IsShown() then
		Search(false)
	else
		S.frame:Show()
	end
end

-- Closes the finder. Plain code, so it also works once the part has stopped.
function Close()
	S.pending = false
	CloseMenu()
	if S.frame then
		pcall(S.frame.Hide, S.frame)
	end
end

-- The contract (spec 0.5.20) -----------------------------------------------------------------------------------------------------------------------

-- Opens or closes the finder (the window's Find button). True when it opened, closed or waits for the end of a fight; false, with a line that says
-- why, while Chat and tooltips or the part is off.
function ns.GearSearchToggle()
	if S.pending then
		S.pending = false
		return true
	end
	if ns.GearSearchShown() then
		Close()
		return true
	end
	if not Allowed() then
		print(Refusal())
		return false
	end
	return Run(Open)
end

-- True while the finder shows: the gate of its box in the movers (Movers.lua's entry FlatUIGearSearch), so a closed finder has none.
function ns.GearSearchShown()
	local frame = S.frame
	if not frame then
		return false
	end
	local ok, shown = pcall(frame.IsVisible, frame)
	return ok and shown == true
end

-- Where the finder starts while the movers keep no spot of it (start): the offsets of its top left corner from the screen's, docked beside the
-- window (D.Hang); else the entry's x and y.
function ns.GearSearchStart(x, y)
	local left, top = D.Hang()
	local _, height = D.Screen()
	if not (left and height) then
		return x, y
	end
	return left, top - height
end

-- The movers set or forgot the finder's spot (changed): it hangs from the spot now (D.Free), or at the window's edge again.
function ns.GearSearchMoved()
	S.placed = nil
	if S.frame then
		Run(D.Place)
	end
end

-- The list row Item finder (chat.gearFind): one line, which opens the window and the finder, and a minimized finder again.
function ns.GearFindLines()
	return { { 1, T.OPEN_LINE } }
end

function ns.GearFindPick(id)
	if id ~= 1 then
		return false, nil
	end
	if not Allowed() then
		return false, Refusal()
	end
	if ns.GearSearchShown() then
		local parent = Window()
		local show = Fn(ns, "GearWindowShow")
		if parent and show then
			pcall(show)
		end
		if S.min then
			Run(D.Collapse, false)
		end
		return true, nil
	end
	return Run(Open), nil
end

-- The results of a query { text, slot, armor, weapon, minLevel, maxLevel, quality, usable, sources } (Normalize), sorted by item level: { { id,
-- name, invType, class, subclass, req, ilvl, quality, source, link, where } ... }, source "all" (the index), "bags" (this character's bags and
-- bank) or "alts" (another character's), where the words of that place. The records are the finder's own: read them, do not change them. Empty
-- when the search fails, whose fault goes to the error handler once.
function ns.GearSearchFind(query)
	local ok, results = pcall(Find, query)
	if ok and type(results) == "table" then
		return results
	end
	Report("GearSearchFind", results)
	return {}
end
