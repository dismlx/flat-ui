local _, ns = ...

-- Gear lines, the part "gear lines" of Chat and tooltips (design 2.1 to 2.4 and 2.6, the contracts of 4.3 and the post call of 4.4; the Spells
-- and gear tab): inside the game's build of an item tooltip, what wearing the item changes for the spells the player chose, against what the
-- player wears in its slot, and on the Character window what a worn item gives them; the list of those spells for this character, the list rows
-- that change it, /flatui gear and its lines of /flatui status. The numbers are GearModel.lua's (ns.GearModel: G.Compare and G.Figure), worked out
-- from the state and stats SpellModel.lua reads (ns.SpellModel); this file reads no stat and works out no number. It adds to the chat module and
-- has no switch of its own, as ChatTips.lua (ChatTips.lua:7): Chat.lua's post call of the game's tooltip data (TooltipDataProcessor.AddTooltipPostCall
-- for every kind, Chat.lua:1169-1200) calls ns.GearTipLines after ns.SpellTipLines and before its own ID and count lines, and the end of Chat.lua's
-- Refresh calls ns.GearLinesSync. The game runs the post calls once it has added its own lines and before it shows the tooltip
-- (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:281-300), so the tooltip takes the size of the new lines.
--
-- What the post call reads, in its order, each test cheaper than the next (design 4.4). The tooltip: GameTooltip or ItemRefTooltip
-- (Blizzard_GameTooltip/Mainline/GameTooltip.xml:249; Blizzard_UIPanels_Game/Mainline/ItemRef.xml:5), compared with rawequal as BagsTooltip.lua:77-82
-- does, one addons may touch (ns.Forbidden, IsForbidden) and not one inside another (its IsEmbedded, GameTooltip.xml:90), so the comparison tooltips
-- ShoppingTooltip1 and 2, which show the worn items, get nothing. The kind of the data: data.type, Enum.TooltipDataType.Item
-- (TooltipInfoSharedDocumentation.lua:96). The key of Show gear lines: Always, or Shift, Ctrl or Alt held (IsShiftKeyDown, IsControlKeyDown,
-- IsAltKeyDown), or With the game's comparison by the game's own test: on GameTooltip its supportsItemComparison (GameTooltip.xml:251) and either
-- the compareItem of the info the game is building (its processingInfo, TooltipDataHandler.lua:222, 281) or TooltipUtil.ShouldDoItemComparison.
-- The test is alwaysCompareItems (C_CVar.GetCVarBool) while the tooltip's suppressAutomaticCompareItem is not true, or the modified click
-- COMPAREITEMS held (IsModifiedClick; Shift by default, Blizzard_FrameXML/Bindings_Camelot.xml:1546) (Blizzard_SharedXMLGame/Tooltip/
-- TooltipUtil.lua:3-6; TooltipDataRules.lua:168-176); with Compare items only while holding Shift on, which writes alwaysCompareItems 0
-- (ItemCompare.lua:3-14), that is while Shift is held. A worn item shows its lines at this choice while Shift is held. ItemRefTooltip shows them at
-- every choice: the game builds it only for a plain click on a link, a modified one going to HandleModifiedItemClick (SetItemRef,
-- Blizzard_UIPanels_Game/Mainline/ItemRef.lua:17-26), and builds it again only when its data changes (TOOLTIP_DATA_UPDATE, GameTooltip.lua:964-976),
-- never as a key goes down: its OnUpdate shows the worn items beside it with no new build (ItemRef.lua:351-366), so lines that waited for a key or
-- for the comparison would never come there. Then the item: worn when the game gives its data.guid a place
-- in an equipment slot (C_Item.GetItemLocation and the field equipmentSlotIndex, ItemDocumentation.lua:786-799, read as ChatTips.lua:134-157
-- reads it); its link is data.hyperlink, else C_Item.GetItemLinkByGUID(data.guid) (:771-784), as the game finds the item a tooltip shows
-- (TooltipUtil.lua:8-22), else the link of data.id from C_Item.GetItemInfo (:626-657), which carries no random suffix; the game is asked once for an
-- item the client has not loaded (C_Item.RequestLoadItemDataByID, :1710-1718, as BagsData.lua:1649 asks), and the next build has the lines. Its
-- kind is the itemEquipLoc of C_Item.GetItemInfoInstant (:659-680): an item with none gets nothing, nor a relic, bag, quiver, tabard or shirt,
-- whose worth is not in the model (design 2.4); its classID and subclassID (the same call) name its armour or weapon type. Then the lines of the
-- build itself, read fresh each time with the tests of ItemMarks.lua:213-224: an EquipSlot line (Enum.TooltipDataLineType,
-- TooltipInfoSharedDocumentation.lua:55) whose isValidInvSlot is false, or whose isValidItemType is false for a type the player's class never
-- learns, or that is red where the game gives neither field, or a red UsageRequirement line (:77) that says Classes: or Races:
-- (ITEM_CLASSES_ALLOWED and ITEM_RACES_ALLOWED, GlobalStrings/enUS.lua:12687 and 13011), is an item the player can never wear: no lines. The game
-- also gives isValidItemType false, the type in red, for a type the class learns in time and has not learned (T.LEARNS, the client's own table of
-- them: mail for a hunter or a shaman and plate for a warrior or a paladin from level 40, polearms from 20, the weapon masters' other skills, a
-- shaman's two-hand axes and maces through a talent). That, and any other red requirement (a level, a skill, a reputation), is one the player
-- cannot wear yet: the lines show, and end with "Not wearable yet:" and the game's own red requirement line, else the type's red text (design
-- 2.2), so a level 58 player sees what a level 60 reward will do and a level 38 hunter what a mail chest will. A red
-- is the game's RED_FONT_COLOR or near it (ItemMarks.lua:53-54). ItemMarks' own answer (ns.ItemMarks.Unusable) is not used: it is kept by item ID
-- and goes old only through events of the windows module and Bags (ItemMarks.lua:9-19). The Gear comparison window, which has no build of the game's
-- to read, asks the same test of the lines C_TooltipInfo.GetHyperlink gives for its item (ns.GearWearable, TooltipInfoDocumentation.lua:337-354, as
-- GearModel.lua reads them). C_Item.IsItemDataCachedByID (ItemDocumentation.lua:1520-1533) says whether the client has the item. Every field of the
-- data and of the tooltip is read under pcall and through ns.IsSecret, and every call under pcall.
--
-- The block: G.Compare(link, lines, opts), or G.Compare(slot, lines, opts) for a worn item (what it gives: now against that slot empty), with the
-- lines of ns.GearChosen the player knows now and opts.mode "tooltip" and opts.listVersion ns.GearListVersion() (design 4.3); a row's change is with
-- - now, what the item gives, and its label, slots, empty, offEmpty and perSecond are read as GearModel.lua's header says. Of the slots it gives
-- (rings, trinkets, a dual wielder's one-hand weapon) the tooltip shows the one with the larger mean of the shown lines' percent changes, each
-- weighted by its line's weight, the first the game names on a tie (design 2.4). Written with AddLine and AddDoubleLine, the only writes on a
-- Blizzard frame here, in the one style of SpellModel.lua's M.Fmt.Style (0.5.20): a gold header (the game's NORMAL_FONT_COLOR) that wraps (AddLine's
-- fifth argument), naming what the item replaces, the worn item's name in its quality colour (its link's own colour), and the unit of the plain
-- numbers ("Instead of Band of X (Finger 1), a cast:"); while Overall totals is Weighted (chat.gearTotals), the Overall line: a figure the chosen
-- spells have, each the weighted mean of its rows' percent changes (GearModel.lua's G.Totals, with the lines and their weights), and Damage taken
-- while avoidance shows (GearAvoid.lua's taken of the candidate for the same slots, which A.Compare's candidates carry, else A.Totals), each green
-- when better and red when worse, "Overall Damage +2.4% · Threat +1.1% · Damage taken -2.1%", none when no figure changes; a line per spell
-- (AddDoubleLine), its name light grey (0.82) and the change green for a gain, red for a loss (GREEN_FONT_COLOR, RED_FONT_COLOR) and white for none,
-- with ~ before an estimate; at most Spells in an item tooltip of them; then the block's notes, dim (HitTable.lua:79) and wrapped: "and 2 more:
-- /flatui gear" past the rows shown, never "and 1 more", or the note in place of them when none changes by 0.05% or more, "Not wearable yet:" with
-- the game's requirement, and what is not counted (design 2.3, 2.6), in Compact (chat.tipDetail) joined into one line with "; " between them and in
-- Full each its own. Each block is kept by the item's link (by its slot and link for a worn one), M.Version(), ns.GearListVersion(), A.Stamp and
-- Overall totals, at most 64 and the oldest first out (design 4.6), and all are dropped at each refresh of the module, where a row may have changed.
-- A block is added once for each build of a tooltip, as Chat.lua adds its own lines (Chat.lua:795-806): the game fetches new data for each build and
-- may run the post calls more than once for one, so the same data with the lines of the first call still there is the same build (NumLines). Each
-- AddLine and AddDoubleLine is under pcall, and one the game refuses stops the adding for that build. In a fight, where the game withholds the stats
-- (design 4.7), a block worked out before it shows, else one dim line (InCombatLockdown, and SpellModel's old stats). A reason G.Compare gives shows
-- as one light grey line ("Needs a one-hand weapon; not compared."), but one it marks quiet (ammunition the game does not use for the player, an
-- off-hand weapon for one who does not dual wield) shows nothing. The numbers are rounded as design 2.3 says by SpellModel's M.Fmt, as the window
-- rounds them: a change a cast whole from 100 up and to a tenth below, a second to a tenth and " dps" (Change), the percent to a tenth with its sign,
-- (0%) under 0.05 (Percent), and none while the figure now is 0.
-- While avoidance shows (Avoidance, chat.gearAvoid; GearAvoid.lua's A.Wanted), the block goes on after the spell block with GearAvoid.lua's lines
-- for the slot they show (A.TipLines: its own block in the same style; { text, colour, wrap } a line alone and { key, left, right, leftColour,
-- colour } a figure), Damage taken among them only while the Overall line does not say it, so it shows once, and the note in place of spell rows
-- that do not change says what it counts; the block's key holds A.Stamp, which changes with what those lines are built from. GearAvoid.lua is
-- asked under pcall, so a fault there goes to the error handler once and the spell rows show without it.
-- The post call runs in two steps, each inside ns.EachPart (Core.lua:2193-2224), which counts a failure once for each first argument and stops a
-- part at the third (Core.lua:260, 2203, 2210-2219): the tests and the link keyed by the data of the build, which is new for each build, and the
-- work keyed by the item's link, so three items that fail stop the gear lines with their note for /flatui status, and a test that fails on every
-- build stops them after three builds (design 4.4). The first error also goes once to geterrorhandler(), as Bags' parts report theirs
-- (Bags.lua:356-373).
--
-- The list: FlatUICharDB.gearSpells (ns.Character, Core.lua:2650-2652), as { { key = "frostbolt" }, { key = "heal", id = 6064, weight = 2 } }: the
-- key of an entry of ns.SpellData (SpellData.lua), only for a kept rank its spell ID, and only where it is not 1 its weight in the Overall line (0
-- to 5 in steps of 0.5, 0 leaving the line out of the totals; ns.GearSetWeight, which the window calls, and /flatui gear weight; a line of the
-- defaults weighted gets its saved entry, the defaults becoming the list); nil until the player first changes it, and nil again after Back
-- to your class's spells (design 4.3). At most 20 lines; a change is saved at once, also in a fight, as Cooldowns' are (Cooldowns.lua:2353). A
-- line with no ID follows the highest rank the player knows (SpellModel's M.Highest, by the ranks of its entry, as Cooldowns and Pulse count the
-- ranks of a spell as one, Cooldowns.lua:2301-2302, Pulse.lua:11-13); a kept rank is known when ns.SpellKnown (Cooldowns.lua:314-325) says so, or
-- when it is the rank M.Highest gives. Attack is known to every character whatever the spell book says, and a judgement, which no spell book holds,
-- takes the rank M.Highest gives it through its seal. While the list is nil the defaults of the data are used (D.DEFAULTS by class and role,
-- design 2.1): the role SpellModel read (ns.PlayerRole's first answer, Core.lua:561-590), and a druid's form (GetShapeshiftFormID: Cat Form 1, the
-- bear forms 5 and 8, PlateThreat.lua:54-56) picks its cat or bear set whatever the role. Every entry of them is "if known", and a set holds 2.1's
-- conditions in the one form tools/dev/make_spelltips.py writes: a key; a list of keys, the first of them known (Greater Heal, else Heal, else
-- Lesser Heal); or { key, key ..., needs = key, ["else"] = { key ... } }, each of its keys while needs is known, else each of else (the seal and
-- judgement of Command with Seal of Command known, else those of Righteousness). ns.GearListVersion() changes
-- with each change of what the list gives: the lines, their ranks, whether they are known, their weights, and
-- the defaults it follows (the role, the form). The names are the game's (C_Spell.GetSpellName), with the rank of a kept line
-- (C_Spell.GetSpellSubtext, as Cooldowns.lua:2271-2284 tells ranks apart), and a name typed after /flatui gear add is found in the data, else by
-- C_Spell.GetSpellInfo (as Cooldowns.lua:362-375 resolves one).
-- The rows (Config.lua, the Spells and gear tab; the panel prints a pick's message, Panel.lua:762-791): Add a spell lists the spell book walked as
-- Cooldowns' Add a spell walks it (ns.SpellBookList, Cooldowns.lua:2287-2336), only the spells Flat UI can work out (an entry with cmp) at the
-- highest rank known, with Attack, Auto Shot and Shoot added when the player has them; Remove a spell lists the lines, "(weight 2)" after one whose
-- weight is not 1 and "(not known)" after one the character lost; Add the spells of a bar takes each entry once with the rank on the bar
-- (ns.BarSpells, as Cooldowns' import reads a bar, Cooldowns.lua:2587-2654); Back to your class's spells drops the list; Gear comparison window calls
-- ns.GearWindowShow of GearWindow.lua when it is there, which opens the window or raises an open one, as Reset windows is a list row
-- (Movers.lua:4556-4570). Each pick answers (done, message), as ns.CooldownAdd does (Cooldowns.lua:2354-2370), and never raises: an error goes once
-- to geterrorhandler(). /flatui gear (ns.AddSlash, Core.lua:2358-2373; design 4.11) opens the window (ns.GearWindowToggle, ns.GearWindowShow) and
-- changes the list and its weights, and prints with print(). /flatui status (ns.AddStatus, Core.lua:2334-2354; design 4.12) says, while Your spells
-- in item tooltips is on and this part runs or the window is open (ns.GearWindowOpen, GearWindow.lua), which spells are compared, against what, and,
-- once seen, that the slot table stood in for the game's choice or Flat UI's rating sizes for the game's conversion: of
-- GetCombatRatingBonusForCombatRatingValue, C_TooltipComparison.GetItemComparisonInfo and GetActionInfo (Add the spells of a bar) it only looks
-- whether the client has them, and a candidate of G.Compare whose game is false, or its sizes, the fixed sizes having stood in.
-- UnitClassBase, UnitLevel, GetShapeshiftFormID and ns.PlayerRole are asked only
-- when SpellModel's state lacks the class, level, form or role, and GetTime keeps one reading of the list for one frame.
-- This file registers no event: SpellModel.lua listens for the player's state and stats on a frame of its own while an owner wants them
-- (M.Want("gear lines", on) from ns.GearLinesSync, design 4.5), and a block the client had not loaded is never kept, so the next build has it.

local KEY, PART = "chat", "gear lines"

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The constants of the file, in one table so its functions stay under the client's count of upvalues (as Cooldowns.lua keeps CD,
-- Cooldowns.lua:108-109).
local T = {
	-- The owner this file names when it asks SpellModel.lua for its events (M.Want, design 4.3).
	OWNER = "gear lines",
	-- The most lines a list holds; the most blocks kept (design 4.6); the action bars of Add the spells of a bar (Cooldowns.lua:127); Spells in an
	-- item tooltip when the row does not say (design 4.9); the level a boss is three levels above at Against's first choice (design 2.5).
	MAX_LINES = 20, CACHE = 64, BARS = 8, MOST = 5, MAX_LEVEL = 60,
	-- Enum.TooltipDataType.Item, and Enum.TooltipDataLineType.UsageRequirement and EquipSlot, for a client whose Enum does not say
	-- (TooltipInfoSharedDocumentation.lua:96, 77, 55).
	ITEM = 0, USAGE = 43, EQUIP_SLOT = 21,
	-- The game's red for a requirement not met is 1, 0.125, 0.125 (RED_FONT_COLOR); any colour this close counts (ItemMarks.lua:53-54).
	RED_LEAST = 0.9, OTHER_MOST = 0.25,
	-- Kinds of item that get no lines: relics, whose bonuses are spells, bags, quivers, tabards and shirts (design 2.4), and the kinds of an item
	-- that cannot be worn.
	NO_LINES = { INVTYPE_RELIC = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_TABARD = true, INVTYPE_BODY = true, INVTYPE_NON_EQUIP = true,
		INVTYPE_NON_EQUIP_IGNORE = true },
	-- The armour and weapon types each class can wear once it has learned them, as the client's SkillRaceClassInfo and SkillLineAbility give them
	-- for each class (build 1.60.1.70888, as GrunzForever exports them; both tables agree): mail from level 40 for a hunter and a shaman, plate from
	-- 40 for a warrior and a paladin, polearms from 20, a shaman's two-hand axes and maces through a talent (not trainable), the rest from the
	-- weapon masters. By the item's classID (Enum.ItemClass: Weapon 2, Armor 4) and subclassID (Enum.ItemWeaponSubclass: Axe1H 0, Axe2H 1, Bows 2,
	-- Guns 3, Mace1H 4, Mace2H 5, Polearm 6, Sword1H 7, Sword2H 8, Staff 10, Unarmed 13, Dagger 15, Thrown 16, Crossbow 18, Wand 19;
	-- Enum.ItemArmorSubclass: Cloth 1, Leather 2, Mail 3, Plate 4, Shield 6). A type in red that is here is one the player has not learned yet; any
	-- other, one the class never learns (Wearable).
	LEARNS = {
		WARRIOR = { [2] = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true,
			[13] = true, [15] = true, [16] = true, [18] = true }, [4] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true } },
		PALADIN = { [2] = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
			[4] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true } },
		HUNTER = { [2] = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true,
			[16] = true, [18] = true }, [4] = { [1] = true, [2] = true, [3] = true } },
		ROGUE = { [2] = { [0] = true, [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true, [16] = true, [18] = true },
			[4] = { [1] = true, [2] = true } },
		SHAMAN = { [2] = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
			[4] = { [1] = true, [2] = true, [3] = true, [6] = true } },
		DRUID = { [2] = { [4] = true, [5] = true, [6] = true, [10] = true, [13] = true, [15] = true }, [4] = { [1] = true, [2] = true } },
		PRIEST = { [2] = { [4] = true, [10] = true, [15] = true, [19] = true }, [4] = { [1] = true } },
		MAGE = { [2] = { [7] = true, [10] = true, [15] = true, [19] = true }, [4] = { [1] = true } },
		WARLOCK = { [2] = { [7] = true, [10] = true, [15] = true, [19] = true }, [4] = { [1] = true } },
	},
	-- The worn slots by number (INVSLOT_AMMO 0 to INVSLOT_TABARD 19, Blizzard_FrameXMLBase/Constants.lua:135-154), in the words of G.Compare's labels
	-- (GearModel.lua, K.LABEL) and the window's, for a header whose slot G.Compare gave no label.
	SLOT_NAMES = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
		"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" },
	-- Attack (the auto attack of both hands), Auto Shot and Shoot with a wand, which Add a spell lists when the player has them (design 2.1).
	GENERIC = { 6603, 75, 5019 },
	-- Attack is known to every character, whatever the spell book says of it.
	ALWAYS = { [6603] = true },
	-- A druid's forms by GetShapeshiftFormID: Cat Form 1 (Blizzard_FrameXMLBase/Constants.lua:327), Bear Form 5 and Dire Bear Form 8
	-- (PlateThreat.lua:54-56).
	CAT_FORM = 1, BEAR_FORMS = { [5] = true, [8] = true },
	-- What a set of the defaults is for, as /flatui status and the list say it.
	SETS = { damage = "a damage dealer", tank = "a tank", healer = "a healer", cat = "Cat Form", bear = "a bear form" },
	ROLES = { damage = true, tank = true, healer = true },
	-- The comparison kinds (design 3.2) that heal: their second is healing a second.
	HEALS = { heal = true, hot = true },
	-- The hit cap against a boss of each choice (chat.gearRules, hud.hitTableRules; Config.lua:1959-1961).
	CAPS = { classic = "9% melee and 16% spells", game = "8% melee and 17% spells" },
	-- The fixed rating sizes for 1% when the data does not give them (design 2.5, SpellData.lua's D.MODEL.ratings).
	RATINGS = { hit = 10, crit = 14, haste = 10, expertise = 10 },
	-- A line's weight in the Overall line (ns.GearSetWeight): 0 (left out) to 5, in steps of 0.5, 1 when none is saved.
	WEIGHT_MIN = 0, WEIGHT_MAX = 5, WEIGHT_STEP = 0.5, WEIGHT = 1,
	-- The figures of the Overall line in their order (GearModel.lua's G.Totals), the word each shows as, and the least share a figure must change
	-- by to show other than 0% (as M.Fmt.Percent rounds).
	FIGURES = { { "damage", "Damage" }, { "healing", "Healing" }, { "threat", "Threat" } }, TAKEN = "Damage taken", OVERALL = "Overall",
	SEPARATOR = "  \194\183  ", STILL_PCT = 0.0005,
	-- The colours of the style while SpellModel.lua's (M.Fmt.Style) cannot be read: the gold header (the game's NORMAL_FONT_COLOR), a figure's
	-- light grey label and white value, a change better or worse (GREEN_FONT_COLOR, RED_FONT_COLOR) and a dim note.
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, good = { 0.1, 1, 0.1 }, bad = { 1, 0.1, 0.1 },
		dim = { 0.66, 0.68, 0.62 } },
	-- The notes of a block in Compact are joined into one dim line with this between them (chat.tipDetail).
	JOIN = "; ",
	NO_CHANGE = "No change to your chosen spells; stamina, armor, avoidance and mana are not counted.",
	OUT_OF_COMBAT = "Gear lines show out of combat.",
	RANDOM = "Random stats not known",
	NOT_YET = "Not wearable yet: ",
	-- What a type the player has yet to learn needs, when its line gives no text of the type.
	LEARN = "an armor or weapon skill you have yet to learn",
	NOT_COUNTED = "Not counted: ",
	MORE = "and %d more: /flatui gear",
	SLOT_NOTE = "Gear comparison: the game did not say which item an item replaces, so Flat UI went by its slot.",
	RATING_NOTE = "Gear comparison: rating sizes are Flat UI's (%d hit, %d crit, %d haste, %d expertise for 1%%), since the game gave no conversion.",
	NO_MODEL = "Gear comparison: Flat UI's spell data is not loaded, so the list cannot change now.",
	NOT_LOADED = "Gear comparison: your settings have not loaded yet.",
	NO_BAR = "Gear comparison: the game has no action bar information, so Add the spells of a bar adds nothing.",
	BAR_HELP = "/flatui gear bar 1 - the spells of action bar 1 to 8",
	FAILED = "Gear comparison: that did not work; the game's error report says why.",
	NO_WINDOW = "Gear comparison: the window is not in this build of Flat UI.",
	RESET_LINE = "Your class's main spells for your role",
	OPEN_LINE = "Open the Gear comparison window",
	WEIGHT_HELP = "/flatui gear weight <spell> <0 to 5> - how much a spell counts in the Overall line, in steps of 0.5",
	HELP = {
		"/flatui gear - the Gear comparison window; /flatui gear <item> compares a shift-clicked item there",
		"/flatui gear add <spell>, remove <spell>, bar 1, reset, list - the spells it compares",
		"/flatui gear weight <spell> <0 to 5> - how much a spell counts in the Overall line",
	},
}

-- Per tooltip: { data, lines } of the build its block went into.
local added = setmetatable({}, { __mode = "k" })
-- The blocks built, by their key, and the order they came in; the last block of each item whatever the versions, for a fight.
local blocks = { byKey = {}, order = {}, last = {}, lastOrder = {} }
-- The list: counter changes with each edit, version is ns.GearListVersion(), signature what the list gave at the last reading; memo holds one
-- reading for one frame (memoKey).
local list = { counter = 0, version = 1 }
-- Seen once: the slot table stood in for the game's choice of slot; the fixed rating sizes for the game's conversion.
local seen = { slots = false, ratings = false }
-- The item IDs the game was asked to load, the patterns of the game's requirement lines, and the errors already reported, by where.
local asked, patterns, reported = {}, {}, {}

-- Helpers -------------------------------------------------------------------------------------------------------------------------------------

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- A whole number above 0, as a spell or item ID is.
local function Whole(value)
	return Finite(value) and value > 0 and value == math.floor(value)
end

-- The first answer of a call of the game, or nil when the call is missing, raises or withholds the answer.
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

-- t[key], for pcall.
local function Index(t, key)
	return t[key]
end

-- A field of a table the game gave, and true as the second answer when the table or the field is withheld or reading it raises; a field that is
-- not there is nil and not withheld.
local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil, true
	end
	local ok, value = pcall(Index, t, key)
	if not ok or IsSecret(value) then
		return nil, true
	end
	return value, false
end

-- A function of a namespace of the game, such as C_Item.GetItemInfo, or nil.
local function Call(space, name)
	local fn = Field(space, name)
	return type(fn) == "function" and fn or nil
end

-- A value of the client's Enum, or the fallback when it has none.
local function EnumValue(group, name, fallback)
	local value = Field(Field(_G.Enum, group), name)
	if Finite(value) then
		return value
	end
	return fallback
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- Says an error once for each place it came from, to the game's error handler, as Bags' parts say theirs (Bags.lua:356-373).
local function Report(err, where)
	where = where or PART
	if reported[where] then
		return
	end
	reported[where] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, ("Flat UI Chat and tooltips, %s: %s"):format(where, tostring(err)))
	end
end

-- SpellModel.lua's lookups and state, GearModel.lua's comparison and the spell data, looked up when asked: another part's file may load after this
-- one, or not at all.
local function Model()
	local M = ns.SpellModel
	if type(M) == "table" and type(M.Find) == "function" and type(M.ByKey) == "function" and type(M.Highest) == "function" then
		return M
	end
	return nil
end

local function Gear()
	local G = ns.GearModel
	if type(G) == "table" and type(G.Compare) == "function" then
		return G
	end
	return nil
end

-- A function of GearAvoid.lua (ns.GearAvoid), looked up when called and run under pcall: its fault goes to the error handler once and never stops
-- the gear lines, which show without the avoidance block.
local function Avoid(name, ...)
	local A = ns.GearAvoid
	local fn = type(A) == "table" and A[name] or nil
	if type(fn) ~= "function" then
		return nil
	end
	local ok, first, second = pcall(fn, ...)
	if not ok then
		Report(first, "avoidance")
		return nil
	end
	return first, second
end

-- Asks SpellModel.lua for its events while the gear lines want them. A refusal goes to the error handler, never to the caller.
local function Want(on)
	local M = ns.SpellModel
	if type(M) == "table" and type(M.Want) == "function" then
		local ok, err = pcall(M.Want, T.OWNER, on == true)
		if not ok then
			Report(err, "sync")
		end
	end
end

-- The player's state as SpellModel.lua read it, read first where marked (M.State, design 4.3); always a table.
local function StateOf(M)
	local state = M and type(M.State) == "function" and M.State() or nil
	return Plain(state, "table") and state or {}
end

-- The player's stats (M.Stats), or nil before the first plain read.
local function StatsOf(M)
	local stats = M and type(M.Stats) == "function" and M.Stats() or nil
	return Plain(stats, "table") and stats or nil
end

local function Version(M)
	return M and type(M.Version) == "function" and M.Version() or 0
end

local function Class(state)
	local class = state.class
	if not Plain(class, "string") then
		class = Ask(UnitClassBase, "player")
	end
	return Plain(class, "string") and class or nil
end

local function Level(state)
	local level = state.level
	if not Finite(level) then
		level = Ask(UnitLevel, "player")
	end
	return Finite(level) and level or 0
end

-- The form by GetShapeshiftFormID, 0 for none.
local function Form(state)
	local form = state.form
	if not Finite(form) then
		form = Ask(GetShapeshiftFormID)
	end
	return Finite(form) and form or 0
end

-- "tank", "healer" or "damage": the role SpellModel read, else ns.PlayerRole's first answer (Core.lua:561-590).
local function Role(state)
	local role = state.role
	if Plain(role, "string") and T.ROLES[role] then
		return role
	end
	if type(ns.PlayerRole) == "function" then
		local ok, answer = pcall(ns.PlayerRole)
		if ok and Plain(answer, "string") and T.ROLES[answer] then
			return answer
		end
	end
	return "damage"
end

-- True while a fight keeps the stats from being read: in combat, or the stats SpellModel holds are from before the fight (design 4.7).
local function Fighting(stats)
	return Ask(InCombatLockdown) == true or (stats ~= nil and stats.old == true)
end

-- Names -------------------------------------------------------------------------------------------------------------------------------------

local function SpellName(id)
	local name = Ask(Call(C_Spell, "GetSpellName"), id)
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

-- The rank text the game shows beside a spell's name ("Rank 4"), or nil.
local function RankText(id)
	local text = Ask(Call(C_Spell, "GetSpellSubtext"), id)
	if Plain(text, "string") and text ~= "" then
		return text
	end
	return nil
end

-- A key of the data as a name: each word with a capital, "shadow word: pain" as "Shadow Word: Pain".
local function Title(key)
	if type(key) ~= "string" then
		return "?"
	end
	return (key:gsub("(%a)([%w']*)", function(first, rest)
		return first:upper() .. rest
	end))
end

local function NameOf(entry, id)
	return (Whole(id) and SpellName(id)) or Title(type(entry) == "table" and entry.key or nil)
end

-- The spell ID of a rank of an entry, or nil.
local function RankId(entry, index)
	local ranks = type(entry) == "table" and entry.ranks or nil
	local rank = type(ranks) == "table" and ranks[index] or nil
	return type(rank) == "table" and Whole(rank[1]) and rank[1] or nil
end

-- Known spells and ranks -------------------------------------------------------------------------------------------------------------------

-- Whether the player knows a spell (ns.SpellKnown of Cooldowns.lua, which says yes on a client without a spell book to ask).
local function Known(id)
	if T.ALWAYS[id] then
		return true
	end
	local known = ns.SpellKnown
	if type(known) ~= "function" then
		return true
	end
	return known(id) == true
end

-- The rank index and spell ID of the highest rank of an entry the player knows, or nil: SpellModel's answer (M.Highest, which gives a judgement the
-- rank of its seal), else Attack's one rank, which every character knows.
local function Highest(M, entry)
	if type(entry) ~= "table" or type(entry.ranks) ~= "table" then
		return nil
	end
	local index, id = M.Highest(entry)
	if Finite(index) and entry.ranks[index] ~= nil then
		return index, Whole(id) and id or RankId(entry, index)
	end
	for at = #entry.ranks, 1, -1 do
		local rank = RankId(entry, at)
		if rank and T.ALWAYS[rank] then
			return at, rank
		end
	end
	return nil
end

-- Whether the player knows the rank of a kept line: the spell itself, or the rank M.Highest gives (a judgement's, through its seal).
local function KnownRank(M, entry, id)
	if Known(id) then
		return true
	end
	local _, top = Highest(M, entry)
	return top ~= nil and top == id
end

-- A weight as saved: a number from WEIGHT_MIN to WEIGHT_MAX, else nil.
local function WeightOf(value)
	if Finite(value) and value >= T.WEIGHT_MIN and value <= T.WEIGHT_MAX then
		return value
	end
	return nil
end

-- A weight in words: 2, 1.5.
local function WeightText(weight)
	return (("%.1f"):format(weight):gsub("%.0$", ""))
end

-- A line as ns.GearChosen gives it (design 4.3), with its key and its weight in the Overall line (0.5.20: the saved one, else 1).
local function Line(entry, index, id, kept, known, weight)
	return { entry = entry, rank = index, id = id, name = NameOf(entry, id), kept = kept == true, known = known == true, key = entry.key,
		weight = WeightOf(weight) or T.WEIGHT }
end

-- An entry the comparison can work out: one of the data with a comparison kind (cmp, design 3.2) and ranks, not of the player's pet.
local function Comparable(entry)
	return type(entry) == "table" and type(entry.cmp) == "string" and entry.pet ~= true and type(entry.ranks) == "table" and entry.ranks[1] ~= nil
		and type(entry.key) == "string"
end

-- The defaults -----------------------------------------------------------------------------------------------------------------------------

-- The set of D.DEFAULTS for a class, a role and a form, and what it is for: a druid's cat set in Cat Form and its bear set (else its tank set) in a
-- bear form whatever the role (design 2.1), else the role's set, else the damage set.
local function SetOf(class, role, form)
	local D = ns.SpellData
	local all = type(D) == "table" and D.DEFAULTS or nil
	local sets = type(all) == "table" and class and all[class] or nil
	if type(sets) ~= "table" then
		return nil, role
	end
	if class == "DRUID" then
		if form == T.CAT_FORM and type(sets.cat) == "table" then
			return sets.cat, "cat"
		elseif T.BEAR_FORMS[form] then
			if type(sets.bear) == "table" then
				return sets.bear, "bear"
			elseif type(sets.tank) == "table" then
				return sets.tank, "bear"
			end
		end
	end
	if type(sets[role]) == "table" then
		return sets[role], role
	elseif type(sets.damage) == "table" then
		return sets.damage, "damage"
	end
	return nil, role
end

-- Adds to out the keys one item of a set of D.DEFAULTS gives, in the one form tools/dev/make_spelltips.py writes (design 2.1): a key, while known; a
-- list of keys, the first of them known ("Greater Heal, else Heal, else Lesser Heal"); or { key, key ..., needs = key, ["else"] = { key ... } },
-- each of its keys known while needs is known, else each known key of its else. known says whether the player knows a key's spell.
local function Items(item, known, out)
	if type(item) == "string" then
		if known(item) then
			out[#out + 1] = item
		end
		return
	elseif type(item) ~= "table" then
		return
	end
	if item.needs ~= nil then
		local group = item
		if not known(item.needs) then
			group = item["else"]
		end
		for _, key in ipairs(type(group) == "table" and group or {}) do
			if type(key) == "string" and known(key) then
				out[#out + 1] = key
			end
		end
		return
	end
	for _, key in ipairs(item) do
		if type(key) == "string" and known(key) then
			out[#out + 1] = key
			return
		end
	end
end

-- The lines of the defaults for the player's class, role and form, and the set they are: every entry known now, each once, in the set's order.
-- The second answer is the set's name ("damage", "tank", "healer", "cat", "bear"); the third is true when the data has no set for the class.
local function DefaultLines(M, state)
	local class, role = Class(state), Role(state)
	local set, name = SetOf(class, role, Form(state))
	if not set then
		return {}, name, true
	end
	local function KnownKey(key)
		local entry = type(key) == "string" and M.ByKey(key) or nil
		return Comparable(entry) and Highest(M, entry) ~= nil
	end
	local keys = {}
	for _, item in ipairs(set) do
		Items(item, KnownKey, keys)
	end
	local lines, taken = {}, {}
	for _, key in ipairs(keys) do
		if not taken[key] and #lines < T.MAX_LINES then
			taken[key] = true
			local entry = M.ByKey(key)
			local index, id = Highest(M, entry)
			if index and id then
				lines[#lines + 1] = Line(entry, index, id, false, true)
			end
		end
	end
	return lines, name, false
end

-- The saved list --------------------------------------------------------------------------------------------------------------------------

-- The saved lines of this character, or nil while the defaults are followed. A line is { key, id, weight }: the key a text, the id nil or a spell
-- ID, the weight nil (1) or 0 to 5; none twice, at most MAX_LINES. A list that is not so is written back cleaned, as Cooldowns' List does
-- (Cooldowns.lua:264-288): a weight out of range is dropped.
local function Saved()
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local old = char.gearSpells
	if old == nil then
		return nil
	elseif type(old) ~= "table" then
		char.gearSpells = nil
		return nil
	end
	local clean, twice = {}, {}
	for _, line in ipairs(old) do
		local key = type(line) == "table" and line.key or nil
		local id = type(line) == "table" and line.id or nil
		if type(key) == "string" and key ~= "" and (id == nil or Whole(id)) and #clean < T.MAX_LINES then
			local mark = key .. "#" .. tostring(id)
			if not twice[mark] then
				twice[mark] = true
				if line.weight ~= nil and not WeightOf(line.weight) then
					line = { key = key, id = id }
				end
				clean[#clean + 1] = line
			end
		end
	end
	local same = #clean == #old
	for key in pairs(old) do
		same = same and clean[key] ~= nil and rawequal(clean[key], old[key])
	end
	if same then
		return old
	end
	char.gearSpells = clean
	return clean
end

-- A saved line as a line of ns.GearChosen, or nil for one the data does not have or cannot work out.
local function SavedLine(M, item)
	if item.id ~= nil then
		local entry, index = M.Find(item.id)
		if not Comparable(entry) or not Finite(index) then
			return nil
		end
		return Line(entry, index, item.id, true, KnownRank(M, entry, item.id), item.weight)
	end
	local entry = M.ByKey(item.key)
	if not Comparable(entry) then
		return nil
	end
	local index, id = Highest(M, entry)
	if index and id then
		return Line(entry, index, id, false, true, item.weight)
	end
	local top = #entry.ranks
	local topId = RankId(entry, top)
	return topId and Line(entry, top, topId, false, false, item.weight) or nil
end

-- What the list gives now: its lines, and { defaults, set, role, class, noSet }. One reading serves every ask of one frame (GetTime is the time of
-- the frame); an edit of the list or a new M.Version() reads it again. Each reading that gives other lines, ranks or known spells than the last
-- changes ns.GearListVersion().
local function Resolve()
	local M = Model()
	local now = Ask(GetTime)
	local memoKey = Finite(now) and (tostring(now) .. "|" .. list.counter .. "|" .. tostring(M and Version(M))) or nil
	if memoKey and list.memoKey == memoKey and list.memo then
		return list.memo, list.memoInfo
	end
	local lines, info = {}, { defaults = false }
	local saved = Saved()
	if M then
		local state = StateOf(M)
		info.role, info.class = Role(state), Class(state)
		if saved == nil then
			info.defaults = true
			lines, info.set, info.noSet = DefaultLines(M, state)
		else
			for _, item in ipairs(saved) do
				local line = SavedLine(M, item)
				if line then
					lines[#lines + 1] = line
				end
			end
		end
	else
		info.defaults = saved == nil
	end
	local parts = { info.defaults and ("d" .. tostring(info.set)) or "c" }
	for _, line in ipairs(lines) do
		parts[#parts + 1] = ("%s;%s;%s%s;%s"):format(line.key, tostring(line.id), line.kept and "k" or "f", line.known and "y" or "n",
			tostring(line.weight))
	end
	local signature = table.concat(parts, ",")
	if signature ~= list.signature then
		list.signature = signature
		list.version = list.version + 1
	end
	list.memo, list.memoInfo, list.memoKey = lines, info, memoKey
	return lines, info
end

-- The lines of the list (design 4.3): { { entry, rank, id, name, kept, known, key, weight } ... }, the spells the comparison works out, in list
-- order, and what the list is (as Resolve). Never raises.
function ns.GearChosen()
	local ok, lines, info = pcall(Resolve)
	if not ok then
		Report(lines, "list")
		return {}, { defaults = false }
	end
	local copy = {}
	for index, line in ipairs(lines) do
		copy[index] = line
	end
	return copy, info
end

-- A number that changes with each change of what the list gives, the defaults it follows and the weights included (design 4.3).
function ns.GearListVersion()
	local ok, err = pcall(Resolve)
	if not ok then
		Report(err, "list")
	end
	return list.version
end

-- The blocks built for the tooltips, and the reading of the list kept for this frame, are dropped.
local function Forget()
	blocks.byKey, blocks.order, blocks.last, blocks.lastOrder = {}, {}, {}, {}
	list.memo, list.memoInfo, list.memoKey = nil, nil, nil
end

-- The list was edited.
local function Changed()
	list.counter = list.counter + 1
	Forget()
end

-- The saved list to edit: the saved one, or the defaults made the list (each line following its rank) the first time the player changes them.
local function Editable()
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local saved = Saved()
	if saved then
		return saved
	end
	local made = {}
	for _, line in ipairs((Resolve())) do
		made[#made + 1] = { key = line.key }
	end
	char.gearSpells = made
	return made
end

-- What a line is called in the lists: its name, the rank of a kept one, its weight in the Overall line where it is not 1, and "(not known)"
-- after a spell the character does not know now.
local function Label(line)
	local text = line.name or "?"
	if line.kept then
		local rank = RankText(line.id)
		if rank then
			text = text .. " (" .. rank .. ")"
		end
	end
	if Finite(line.weight) and line.weight ~= T.WEIGHT then
		text = text .. " (weight " .. WeightText(line.weight) .. ")"
	end
	if not line.known then
		text = text .. " (not known)"
	end
	return text
end

-- Whom the list is for: the defaults of a set, or the player's own.
local function Who(info)
	if info and info.defaults then
		return "your class's spells for " .. (T.SETS[info.set] or T.SETS.damage)
	end
	return "your choice"
end

local function Names(lines)
	local names = {}
	for _, line in ipairs(lines) do
		names[#names + 1] = line.name
	end
	return #names > 0 and table.concat(names, ", ") or "none known yet"
end

-- The rows of the list as Remove a spell and /flatui gear list give them: { id, label, line } in list order. A line the data does not have, or cannot
-- work out, keeps its row: by its spell ID, or for one that follows a rank by minus its place in the list.
local function Entries()
	local M = Model()
	local rows = {}
	local saved = Saved()
	if saved == nil then
		for _, line in ipairs((Resolve())) do
			rows[#rows + 1] = { line.id, Label(line), line }
		end
		return rows
	end
	for index, item in ipairs(saved) do
		local line = M and SavedLine(M, item) or nil
		if line then
			rows[#rows + 1] = { line.id, Label(line), line }
		elseif item.id ~= nil then
			rows[#rows + 1] = { item.id, (SpellName(item.id) or ("Spell " .. item.id)) .. " (not in the comparison)" }
		else
			rows[#rows + 1] = { -index, Title(item.key) .. " (not in the comparison)" }
		end
	end
	return rows
end

-- The list rows ------------------------------------------------------------------------------------------------------------------------------

local function ByLabel(a, b)
	local first, second = a[2]:lower(), b[2]:lower()
	if first ~= second then
		return first < second
	end
	return a[1] < b[1]
end

-- Add a spell: the player's spells Flat UI can work out, at the highest rank known, that have no line following their rank yet, by name; Attack,
-- Auto Shot and Shoot with them when the player has them.
local function Candidates()
	local M = Model()
	if not M then
		return {}
	end
	-- The spells with a line that follows their ranks, and the ranks a known line stands for now (a kept rank that is the highest).
	local followed, standing = {}, {}
	for _, line in ipairs((Resolve())) do
		if not line.kept then
			followed[line.key] = true
		end
		if line.known then
			standing[line.id] = true
		end
	end
	local rows, taken = {}, {}
	local function Keep(id)
		if not Whole(id) or standing[id] then
			return false
		end
		local entry = M.Find(id)
		if not Comparable(entry) or followed[entry.key] or taken[entry.key] then
			return false
		end
		local _, top = Highest(M, entry)
		if top ~= nil and top ~= id then
			return false
		end
		taken[entry.key] = true
		return true
	end
	local book = ns.SpellBookList
	if type(book) == "function" then
		local listed = book(function(id)
			return Keep(id)
		end)
		for _, row in ipairs(type(listed) == "table" and listed or {}) do
			if type(row) == "table" and Whole(row[1]) and Plain(row[2], "string") then
				rows[#rows + 1] = { row[1], row[2] }
			end
		end
	end
	for _, id in ipairs(T.GENERIC) do
		if Known(id) and Keep(id) then
			rows[#rows + 1] = { id, NameOf(M.Find(id), id) }
		end
	end
	table.sort(rows, ByLabel)
	return rows
end

-- Adds a line for a spell ID. keep true keeps that rank (a bar, an ID, a link); false follows the highest rank of its spell (a name); nil follows
-- when the ID is the highest rank the player knows, or no rank is known, and keeps it otherwise (a line of Add a spell, a spell dropped on the
-- window). A line that stands for what a line of the list stands for now is refused. The third answer says why a refusal was: "had", "full" or
-- "bad".
local function AddLine(id, keep)
	local M = Model()
	if not M then
		return false, T.NO_MODEL, "bad"
	end
	if not Whole(id) then
		return false, ('Gear comparison: no spell found for "%s".'):format(tostring(id)), "bad"
	end
	local entry = M.Find(id)
	local name = SpellName(id) or ("Spell " .. id)
	if type(entry) ~= "table" then
		return false, ("Gear comparison: %s is not in Flat UI's spell data for your class."):format(name), "bad"
	elseif not Comparable(entry) then
		return false, ("Gear comparison: Flat UI cannot work out %s."):format(name), "bad"
	end
	local _, top = Highest(M, entry)
	if keep == nil then
		keep = top ~= nil and top ~= id
	end
	local stands = keep and id or top
	local lines = Resolve()
	for _, line in ipairs(lines) do
		if line.key == entry.key and ((keep and line.kept and line.id == id) or (not keep and not line.kept)
			or (line.known and stands ~= nil and line.id == stands)) then
			return false, ("Gear comparison: %s is chosen already."):format(Label(line)), "had"
		end
	end
	local saved = Saved()
	if #(saved or lines) >= T.MAX_LINES then
		return false, ("Gear comparison: %d spells is the most."):format(T.MAX_LINES), "full"
	end
	local edit = Editable()
	if not edit then
		return false, T.NOT_LOADED, "bad"
	end
	edit[#edit + 1] = keep and { key = entry.key, id = id } or { key = entry.key }
	Changed()
	local rank = keep and RankText(id) or nil
	return true, ("Gear comparison: added %s%s."):format(name, rank and (" (" .. rank .. ")") or "")
end

-- The place of the line a spell ID names among lines: a kept line of that rank, else the line that follows the ranks of its spell.
local function Which(M, lines, id)
	for index, line in ipairs(lines) do
		if line.kept and line.id == id then
			return index
		end
	end
	local entry = M and M.Find(id) or nil
	if type(entry) == "table" then
		for index, line in ipairs(lines) do
			if not line.kept and line.key == entry.key then
				return index
			end
		end
	end
	return nil
end

-- The place of the saved line a spell ID names, and its name: a kept line of that rank, else the line that follows the ranks of its spell; or
-- minus the place of a line the data does not have.
local function SavedAt(M, saved, id)
	if id < 0 then
		local item = saved[-id]
		if type(item) == "table" and item.id == nil then
			return -id, Title(item.key)
		end
		return nil
	end
	local name = SpellName(id) or ("Spell " .. id)
	for index, item in ipairs(saved) do
		if item.id == id then
			return index, name
		end
	end
	local entry = M and M.Find(id) or nil
	if type(entry) == "table" then
		for index, item in ipairs(saved) do
			if item.id == nil and item.key == entry.key then
				return index, name
			end
		end
	end
	return nil, name
end

-- Takes a line off: by the spell ID of its row (Remove a spell, the window), or minus its place for one the data does not have.
local function RemoveLine(id)
	if not Finite(id) or id ~= math.floor(id) or id == 0 then
		return false, ('Gear comparison: no spell found for "%s".'):format(tostring(id))
	end
	local M = Model()
	local saved = Saved()
	if saved == nil then
		-- The defaults: the others become the list.
		local lines = Resolve()
		local at = id > 0 and Which(M, lines, id) or nil
		local char = ns.Character()
		if not at then
			return false, ("Gear comparison: %s is not chosen."):format(SpellName(id) or tostring(id))
		elseif type(char) ~= "table" then
			return false, T.NOT_LOADED
		end
		local made = {}
		for index, line in ipairs(lines) do
			if index ~= at then
				made[#made + 1] = { key = line.key }
			end
		end
		char.gearSpells = made
		Changed()
		return true, ("Gear comparison: removed %s."):format(lines[at].name)
	end
	local at, name = SavedAt(M, saved, id)
	if not at then
		return false, ("Gear comparison: %s is not chosen."):format(name or tostring(id))
	end
	table.remove(saved, at)
	Changed()
	return true, ("Gear comparison: removed %s."):format(name)
end

-- Sets the weight of a line in the Overall line (0.5.20, ns.GearSetWeight): by the spell ID of its row, or minus its place for one the data does
-- not have, as RemoveLine finds it; 0 to 5 in steps of 0.5 (a number between is rounded to the nearest step), 1 by default, 0 leaving the line out
-- of the totals. A line of the defaults gets its saved entry: the defaults become the list, each line following its rank, as a first change does.
local function SetWeight(id, weight)
	if not Finite(id) or id ~= math.floor(id) or id == 0 then
		return false, ('Gear comparison: no spell found for "%s".'):format(tostring(id))
	elseif not Finite(weight) or weight < T.WEIGHT_MIN or weight > T.WEIGHT_MAX then
		return false, T.WEIGHT_HELP
	end
	weight = math.floor(weight / T.WEIGHT_STEP + 0.5) * T.WEIGHT_STEP
	local M = Model()
	local saved, at, name = Saved(), nil, nil
	if saved == nil then
		local lines = Resolve()
		at = id > 0 and Which(M, lines, id) or nil
		name = at and lines[at].name or SpellName(id)
	else
		at, name = SavedAt(M, saved, id)
	end
	if not at then
		return false, ("Gear comparison: %s is not chosen."):format(name or tostring(id))
	end
	local now = saved and WeightOf(saved[at].weight) or T.WEIGHT
	if now == weight then
		return false, ("Gear comparison: %s weighs %s already."):format(name, WeightText(weight))
	end
	local edit = Editable()
	if not edit or type(edit[at]) ~= "table" then
		return false, T.NOT_LOADED
	end
	edit[at].weight = weight ~= T.WEIGHT and weight or nil
	Changed()
	if weight == 0 then
		return true, ("Gear comparison: %s is left out of the Overall line (weight 0)."):format(name)
	end
	return true, ("Gear comparison: %s weighs %s in the Overall line."):format(name, WeightText(weight))
end

-- Add the spells of a bar: each entry Flat UI can work out on that bar, once, with the rank on the bar (design 2.1). The slots that hold anything
-- else are left out.
local function BarAdd(bar)
	if not (Whole(bar) and bar <= T.BARS) then
		return false, T.BAR_HELP
	end
	local M = Model()
	if not M then
		return false, T.NO_MODEL
	end
	-- ns.BarSpells answers an empty bar both for a bar with nothing on it and for a client without GetActionInfo, so the call is looked for first,
	-- as Cooldowns' import does (Cooldowns.lua, ns.CooldownImport).
	if type(GetActionInfo) ~= "function" then
		return false, T.NO_BAR
	end
	local read = ns.BarSpells
	local ids, others
	if type(read) == "function" then
		ids, others = read(bar)
	end
	if type(ids) ~= "table" then
		return false, T.NO_BAR
	end
	local count, left, had, full = 0, Finite(others) and others >= 0 and math.floor(others) or 0, 0, false
	local taken = {}
	for _, id in ipairs(ids) do
		local entry = Whole(id) and M.Find(id) or nil
		if not Comparable(entry) then
			left = left + 1
		elseif not taken[entry.key] then
			-- The same spell twice on the bar, at two ranks, counts once.
			taken[entry.key] = true
			local done, _, why = AddLine(id, true)
			if done then
				count = count + 1
			elseif why == "had" then
				had = had + 1
			else
				full = full or why == "full"
				left = left + 1
			end
		end
	end
	if count + left + had == 0 then
		return true, ("Gear comparison: action bar %d has nothing to add."):format(bar)
	end
	local said = ("Gear comparison: action bar %d: %d added, %d left out."):format(bar, count, left)
	if had > 0 then
		said = said .. (" %d %s chosen already."):format(had, had == 1 and "was" or "were")
	end
	if full then
		said = said .. (" %d spells is the most."):format(T.MAX_LINES)
	end
	return true, said
end

-- Back to your class's spells: the list goes, and the defaults are followed again.
local function Reset(id)
	if id ~= 1 then
		return false, nil
	end
	local char = ns.Character()
	if type(char) ~= "table" then
		return false, T.NOT_LOADED
	end
	if char.gearSpells == nil then
		local _, info = Resolve()
		return false, ("Gear comparison: %s are in use already."):format(Who(info))
	end
	char.gearSpells = nil
	Changed()
	local lines, info = Resolve()
	return true, ("Gear comparison: back to %s: %s."):format(Who(info), Names(lines))
end

-- Gear comparison window: GearWindow.lua's opening, when that file is there (design 6.21: without it the row does nothing). It opens the window, or
-- raises it above the options window and works it out afresh when it is open already, and never closes it, as the line says.
local function Open(id)
	local show = ns.GearWindowShow
	if id ~= 1 or type(show) ~= "function" then
		return false, nil
	end
	local said = show()
	return true, Plain(said, "string") and said or nil
end

-- A list's lines from a call that may fail; an error goes to the error handler once.
local function Rows(ok, rows)
	if ok and type(rows) == "table" then
		return rows
	end
	if not ok then
		Report(rows, "list")
	end
	return {}
end

-- A pick's answer from a call that may fail: (done, message), and (false, a message) for an error, which goes to the error handler once.
local function Answer(ok, done, message, ...)
	if ok then
		return done, message, ...
	end
	Report(done, "list")
	return false, T.FAILED
end

function ns.GearCandidates()
	return Rows(pcall(Candidates))
end

-- The lines of the list, in list order, so opening the list also shows what is chosen.
function ns.GearPicked()
	return Rows(pcall(function()
		local rows = {}
		for _, row in ipairs(Entries()) do
			rows[#rows + 1] = { row[1], row[2] }
		end
		return rows
	end))
end

-- The picks work in combat and with the module off: they change what is saved and nothing on screen.
function ns.GearAdd(id)
	return Answer(pcall(AddLine, id))
end

function ns.GearRemove(id)
	return Answer(pcall(RemoveLine, id))
end

-- The weight of a line in the Overall line (0.5.20): id as ns.GearRemove takes it, weight 0 to 5 in steps of 0.5; answers (done, message).
function ns.GearSetWeight(id, weight)
	return Answer(pcall(SetWeight, id, weight))
end

function ns.GearBarLines()
	local rows = {}
	for bar = 1, T.BARS do
		rows[bar] = { bar, ("Action bar %d"):format(bar) }
	end
	return rows
end

function ns.GearBarPick(bar)
	return Answer(pcall(BarAdd, bar))
end

function ns.GearResetLines()
	return { { 1, T.RESET_LINE } }
end

function ns.GearResetPick(id)
	return Answer(pcall(Reset, id))
end

function ns.GearOpenLines()
	return { { 1, T.OPEN_LINE } }
end

function ns.GearOpenPick(id)
	return Answer(pcall(Open, id))
end

-- The tooltip --------------------------------------------------------------------------------------------------------------------------------

-- GameTooltip or ItemRefTooltip, one addons may touch and not inside another tooltip.
local function Ours(tooltip)
	if tooltip == nil or IsSecret(tooltip) or not (rawequal(tooltip, _G.GameTooltip) or rawequal(tooltip, _G.ItemRefTooltip)) or ns.Forbidden(tooltip) then
		return false
	end
	local embedded, withheld = Field(tooltip, "IsEmbedded")
	return not withheld and embedded ~= true
end

local function IsItem(data)
	if not Plain(data, "table") then
		return false
	end
	local kind = Field(data, "type")
	return Finite(kind) and kind == EnumValue("TooltipDataType", "Item", T.ITEM)
end

-- True while a key lets the lines show: Always, or Shift, Ctrl or Alt held. A key the game does not say is down counts as up.
local function KeyHeld(choice)
	local down
	if choice == "always" then
		return true
	elseif choice == "shift" then
		down = IsShiftKeyDown
	elseif choice == "ctrl" then
		down = IsControlKeyDown
	elseif choice == "alt" then
		down = IsAltKeyDown
	else
		return false
	end
	return Ask(down) == true
end

-- True while the game compares the item of this tooltip with the worn ones, by its own test (TooltipDataRules.lua:168-176, TooltipUtil.lua:3-6).
-- Find asks it of GameTooltip alone (header). A withheld field counts as no.
local function Comparing(tooltip)
	if rawequal(tooltip, _G.GameTooltip) then
		if Field(tooltip, "supportsItemComparison") ~= true then
			return false
		end
		if Field(Field(tooltip, "processingInfo"), "compareItem") == true then
			return true
		end
	end
	local suppressed, withheld = Field(tooltip, "suppressAutomaticCompareItem")
	if not withheld and suppressed ~= true and Ask(Call(C_CVar, "GetCVarBool"), "alwaysCompareItems") == true then
		return true
	end
	return Ask(IsModifiedClick, "COMPAREITEMS") == true
end

-- The equipment slot of a worn item by its GUID, or nil for an item in no slot of the player's.
local function WornSlot(guid)
	local location = Ask(Call(C_Item, "GetItemLocation"), guid)
	local slot = Field(location, "equipmentSlotIndex")
	if Finite(slot) and slot >= 0 and slot <= 19 and slot == math.floor(slot) then
		return slot
	end
	return nil
end

-- Asks the game once for an item the client has not loaded.
local function Load(id)
	if asked[id] then
		return
	end
	asked[id] = true
	Ask(Call(C_Item, "RequestLoadItemDataByID"), id)
end

-- The link of the item of the data: its hyperlink, else the link of its GUID, else the link of its ID, which carries no random suffix (design 4.4).
local function ItemLink(data, id, guid)
	local link = Field(data, "hyperlink")
	if Plain(link, "string") and link:find("item:", 1, true) then
		return link
	end
	if guid then
		link = Ask(Call(C_Item, "GetItemLinkByGUID"), guid)
		if Plain(link, "string") and link ~= "" then
			return link
		end
	end
	local info = id and Call(C_Item, "GetItemInfo") or nil
	if info then
		local ok, name, base = pcall(info, id)
		if ok and Plain(base, "string") and base ~= "" then
			return base
		elseif ok and name == nil then
			Load(id)
		end
	end
	return nil
end

-- The kind an item is worn as (itemEquipLoc), or nil for one that gets no lines.
local function EquipLoc(link)
	local instant = Call(C_Item, "GetItemInfoInstant")
	if not instant then
		return nil
	end
	local ok, _, _, _, loc, _, itemClass, subclass = pcall(instant, link)
	if not ok or not Plain(loc, "string") or loc == "" or T.NO_LINES[loc] then
		return nil
	end
	return loc, Finite(itemClass) and itemClass or nil, Finite(subclass) and subclass or nil
end

-- False when the client has not loaded the item yet; the game is asked for it then.
local function Loaded(id)
	if Ask(Call(C_Item, "IsItemDataCachedByID"), id) == false then
		Load(id)
		return false
	end
	return true
end

local function Red(colour)
	if not Plain(colour, "table") then
		return false
	end
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	return Finite(r) and Finite(g) and Finite(b) and r >= T.RED_LEAST and g <= T.OTHER_MOST and b <= T.OTHER_MOST
end

-- The magic characters of a pattern, escaped.
local function Escape(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- The pattern of a requirement line of the game, as "Classes: %s" (a global string, else the English one): its words with anything in place of %s.
local function PatternOf(name, fallback)
	local pattern = patterns[name]
	if pattern then
		return pattern
	end
	local format = _G[name]
	if not Plain(format, "string") or format == "" then
		format = fallback
	end
	local before, after = format:match("^(.-)%%s(.*)$")
	if before then
		pattern = "^" .. Escape(before) .. ".+" .. Escape(after) .. "$"
	else
		pattern = "^" .. Escape(format)
	end
	patterns[name] = pattern
	return pattern
end

-- True when the player's class learns the item's armour or weapon type in time (T.LEARNS), by the classID and subclassID of the item.
local function Learns(itemClass, subclass)
	if not (Finite(itemClass) and Finite(subclass)) then
		return false
	end
	local M = ns.SpellModel
	local class = Class(StateOf(type(M) == "table" and M or nil))
	local types = class and T.LEARNS[class]
	local kinds = types and types[itemClass]
	return type(kinds) == "table" and kinds[subclass] == true
end

-- The red text of a type the player has yet to learn: the EquipSlot line's type ("Mail"), else T.LEARN.
local function TypeText(line)
	local text = Field(line, "rightText")
	if Plain(text, "string") and text ~= "" then
		return text
	end
	return T.LEARN
end

-- Reads the lines of the build: true when the player can never wear the item (its type, class or race), else false and the text of the first
-- other requirement in red, else of a type the class learns in time and the player has not learned, which the player can meet in time (design
-- 2.2, 6.20). itemClass and subclass are the item's classID and subclassID, or nil.
local function Wearable(data, itemClass, subclass)
	local lines = Field(data, "lines")
	if not Plain(lines, "table") then
		return false, nil
	end
	local usage = EnumValue("TooltipDataLineType", "UsageRequirement", T.USAGE)
	local slotLine = EnumValue("TooltipDataLineType", "EquipSlot", T.EQUIP_SLOT)
	local classes = PatternOf("ITEM_CLASSES_ALLOWED", "Classes: %s")
	local races = PatternOf("ITEM_RACES_ALLOWED", "Races: %s")
	local later, learn
	for _, line in ipairs(lines) do
		local kind = Plain(line, "table") and Field(line, "type") or nil
		if Finite(kind) and kind == slotLine then
			local itemType, typeWithheld = Field(line, "isValidItemType")
			local invSlot, slotWithheld = Field(line, "isValidInvSlot")
			-- Neither field given: a red slot is a slot the player has not, a red type alone a type not learned.
			if itemType == nil and invSlot == nil and not typeWithheld and not slotWithheld then
				if Red(Field(line, "leftColor")) then
					invSlot = false
				elseif Red(Field(line, "rightColor")) then
					itemType = false
				end
			end
			if invSlot == false then
				return true, nil
			elseif itemType == false then
				if not Learns(itemClass, subclass) then
					return true, nil
				end
				learn = learn or TypeText(line)
			end
		elseif Finite(kind) and kind == usage and Red(Field(line, "leftColor")) then
			local text = Field(line, "leftText")
			if Plain(text, "string") and text ~= "" then
				if text:find(classes) or text:find(races) then
					return true, nil
				end
				later = later or text
			end
		end
	end
	return false, later or learn
end

-- The test of Wearable for an item the Gear comparison window shows (GearWindow.lua), which has no build of the game's to read: the lines
-- C_TooltipInfo.GetHyperlink gives for its link (header). True when the player can never wear it, else false and what it needs first, or nil; false
-- and nil for a link the client gives no lines for yet.
function ns.GearWearable(link)
	if not Plain(link, "string") or link == "" then
		return false, nil
	end
	local _, itemClass, subclass = EquipLoc(link)
	local data = Ask(Call(_G.C_TooltipInfo, "GetHyperlink"), link)
	return Wearable(data, itemClass, subclass)
end

-- The block --------------------------------------------------------------------------------------------------------------------------------

-- Keeps a value by its key in a bucket of at most CACHE, the oldest first out.
local function Store(bucket, order, key, value)
	if bucket[key] == nil then
		order[#order + 1] = key
	end
	bucket[key] = value
	while #order > T.CACHE do
		bucket[table.remove(order, 1)] = nil
	end
end

-- Notes what a comparison shows of the game's calls, for /flatui status: the slot table stood in for the game's choice, the fixed sizes for its
-- rating conversion.
local function Seen(result)
	if not seen.ratings and (type(_G.GetCombatRatingBonusForCombatRatingValue) ~= "function" or (type(result) == "table" and result.sizes == true)) then
		seen.ratings = true
	end
	if seen.slots then
		return
	end
	if not Call(C_TooltipComparison, "GetItemComparisonInfo") then
		seen.slots = true
		return
	end
	local candidates = type(result) == "table" and result.candidates or nil
	for _, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
		if type(candidate) == "table" and candidate.game == false then
			seen.slots = true
		end
	end
end

-- The rows of a candidate the tooltip can show: each with its line and a figure now and with the item.
local function RowsOf(candidate)
	local rows = {}
	for _, row in ipairs(type(candidate.rows) == "table" and candidate.rows or {}) do
		if type(row) == "table" and type(row.line) == "table" and Finite(row.now) and Finite(row.with) then
			rows[#rows + 1] = row
		end
	end
	return rows
end

-- The change of a row in percent of its figure now, or nil while that is 0.
local function Share(row)
	if row.now == 0 then
		return nil
	end
	return (row.with - row.now) / math.abs(row.now) * 100
end

-- A line's weight in the Overall line, 1 when it has none.
local function Weight(line)
	return WeightOf(type(line) == "table" and line.weight or nil) or T.WEIGHT
end

-- The mean of the shown rows' percent changes, each weighted by its line's weight (0.5.20), by which the tooltip picks the slot to show (design 2.4).
local function Mean(rows, shown)
	local sum, count = 0, 0
	for index = 1, shown do
		local share, weight = Share(rows[index]), Weight(rows[index].line)
		if share and weight > 0 then
			sum, count = sum + share * weight, count + weight
		end
	end
	return count > 0 and sum / count or 0
end

-- True when a row changes by 0.05% or more (by 0.05 when its figure now is 0).
local function Moves(row)
	local share = Share(row)
	if share then
		return math.abs(share) >= 0.05
	end
	return math.abs(row.with - row.now) >= 0.05
end

-- Which figure a row is (G.Figure, design 4.3): the row's own, else GearModel's answer for the tooltip, else a cast.
local function FigureOf(row, role)
	if Plain(row.figure, "string") then
		return row.figure
	end
	local G = Gear()
	local figure = G and type(G.Figure) == "function" and G.Figure(row.line, role, "tooltip") or nil
	return type(figure) == "string" and figure or "cast"
end

local function KindOf(line)
	local entry = line.entry
	return type(entry) == "table" and entry.cmp or nil
end

-- A function of SpellModel.lua's rounding and style (M.Fmt, design 2.3 and 0.5.20), which the window writes its numbers with too, or nil.
local function Fmt(name)
	local M = ns.SpellModel
	local fmt = type(M) == "table" and type(M.Fmt) == "table" and M.Fmt or nil
	local fn = fmt and fmt[name]
	return type(fn) == "function" and fn or nil
end

-- The colours of the style: SpellModel.lua's M.Fmt.Style, else this file's (T.STYLE), each { r, g, b }.
local function Colours()
	local M = ns.SpellModel
	local fmt = type(M) == "table" and type(M.Fmt) == "table" and M.Fmt or nil
	local style = fmt and type(fmt.Style) == "table" and fmt.Style or nil
	if not style then
		return T.STYLE
	end
	for name in pairs(T.STYLE) do
		if type(style[name]) ~= "table" then
			return T.STYLE
		end
	end
	return style
end

-- Text in a colour of the style inside a line of another colour.
local function Paint(text, colour)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, Finite(value) and value or 1)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(colour[1]), Byte(colour[2]), Byte(colour[3])) .. text .. "|r"
end

-- A change as the tooltip writes it (design 2.3, M.Fmt.Change): whole from 100 up and to a tenth below for a cast, to a tenth for a second, "0"
-- under 0.05.
local function Amount(change, perSecond)
	local fn = Fmt("Change")
	if fn then
		return fn(change, perSecond)
	end
	return ("%+.1f"):format(change)
end

-- A change as a share (a fraction) with its sign, one decimal (M.Fmt.Percent): +1.8%, 0% under 0.05%.
local function Signed(fraction)
	local fn = Fmt("Percent")
	return fn and fn(fraction) or ("%+.1f%%"):format(fraction * 100)
end

-- "(+1.8%)", "(0%)" under 0.05 (M.Fmt.Percent), or nil while the figure now is 0.
local function Percent(row)
	local share = Share(row)
	if not share then
		return nil
	end
	return "(" .. Signed(share / 100) .. ")"
end

-- The name of a row's spell, with the rank after a kept one below the highest the player knows.
local function LeftName(M, line)
	local name = Plain(line.name, "string") and line.name or NameOf(line.entry, line.id)
	if line.kept and Whole(line.id) then
		local _, top = Highest(M, line.entry)
		local rank = top ~= line.id and RankText(line.id) or nil
		if rank then
			name = name .. " (" .. rank .. ")"
		end
	end
	return name
end

-- One line of the block for a row, in the style: the name light grey, the change green for a gain and red for a loss (white for none), ~ before an
-- estimate, the percent after it. A figure that is a second (row.perSecond: dps, or the threat of what rides on the swings) has one decimal and
-- says so.
local function RowLine(M, row, role, style)
	local figure = FigureOf(row, role)
	local kind = KindOf(row.line)
	local perSecond = row.perSecond == true
	local change = row.with - row.now
	local unit = ""
	if figure == "dps" or (figure == "second" and not T.HEALS[kind]) then
		unit = " dps"
	elseif figure == "second" then
		unit = " healing a second"
	elseif figure == "threat" then
		unit = perSecond and " threat a second" or " threat"
	end
	local percent = Percent(row)
	local right = (row.estimate == true and "~" or "") .. Amount(change, perSecond) .. unit .. (percent and (" " .. percent) or "")
	local colour = math.abs(change) < 0.05 and style.value or (change > 0 and style.good or style.bad)
	return { left = LeftName(M, row.line), right = right, leftColour = style.label, colour = colour }
end

-- The name of a worn item in its quality colour, from its link: the colour the link starts with, else the plain name.
local function ItemName(link)
	if not Plain(link, "string") then
		return nil
	end
	local name = link:match("|h%[(.-)%]|h")
	if not name or name == "" then
		return nil
	end
	local colour = link:match("^(|c[^|]+)|H")
	return colour and (colour .. name .. "|r") or name
end

-- The words for slots G.Compare gave no label: one slot's name, "both hands", or the names together.
local function SlotWords(slots)
	if type(slots) ~= "table" or slots[1] == nil then
		return "slot"
	elseif #slots == 2 and ((slots[1] == 16 and slots[2] == 17) or (slots[1] == 17 and slots[2] == 16)) then
		return "both hands"
	end
	local names = {}
	for _, slot in ipairs(slots) do
		names[#names + 1] = T.SLOT_NAMES[slot] or tostring(slot)
	end
	return table.concat(names, " and ")
end

-- The header of the block (design 2.3, 2.4): what the item replaces and the unit of the plain numbers, as GearModel.lua's header of a candidate
-- words it: the slot's words (G.Compare's label) with the worn items' names from SpellModel's state (links), "Instead of X (Finger 1)", "Instead
-- of X, off hand empty" for a one-hander over a worn two-hander (offEmpty), "In your empty Finger 2 slot", "In your empty hands", and for a worn
-- item "What it gives your spells".
local function Header(M, candidate, slot, unit)
	local ending = unit and (", " .. unit .. ":") or ":"
	if slot then
		return "What it gives your spells" .. ending
	end
	local label = candidate.label
	local slots = type(candidate.slots) == "table" and candidate.slots or {}
	local where = type(label) == "string" and label ~= "" and label or SlotWords(slots)
	local links = StateOf(M).links
	local names = {}
	if candidate.empty ~= true and type(links) == "table" then
		for _, at in ipairs(slots) do
			local name = Finite(at) and ItemName(links[at]) or nil
			if name then
				names[#names + 1] = name
			end
		end
	end
	if #names == 0 then
		if #slots > 1 then
			return "In your empty hands" .. ending
		end
		return ("In your empty %s slot"):format(where) .. ending
	elseif candidate.offEmpty == true then
		return ("Instead of %s, off hand empty"):format(table.concat(names, " and ")) .. ending
	end
	return ("Instead of %s (%s)"):format(table.concat(names, " and "), where) .. ending
end

-- The notes of what is not counted (design 2.3, 2.6), as texts: G.Compare's notCounted, each said "Not counted:" unless it says so already, its
-- creature-type bonuses (vs) and a random suffix not rolled yet.
local function Tail(result)
	local tail = {}
	for _, text in ipairs(type(result.notCounted) == "table" and result.notCounted or {}) do
		if type(text) == "string" and text ~= "" then
			if not text:lower():find("not counted", 1, true) then
				text = T.NOT_COUNTED .. text
			end
			tail[#tail + 1] = text
		end
	end
	for _, text in ipairs(type(result.vs) == "table" and result.vs or {}) do
		if type(text) == "string" and text ~= "" then
			tail[#tail + 1] = text
		end
	end
	local random = result.random
	if random == true or (type(random) == "string" and random ~= "") then
		tail[#tail + 1] = random == true and T.RANDOM or random
	end
	return tail
end

-- The block for a comparison G.Compare worked out (0.5.20, the style): { head, notes, tail, avoid, slots, still, candidate }: head the gold
-- header and the rows, notes the block's own dim notes (the rows past those shown, or no change), tail the notes of what is not counted, the
-- "Not wearable yet" note going between them at each build, and avoid GearAvoid.lua's lines (BlockFor). Nil when it gave no slot with a line to
-- show.
local function Build(M, result, slot, info)
	local candidates = type(result) == "table" and result.candidates or nil
	if type(candidates) ~= "table" then
		return nil
	end
	local most = Opt("gearMost")
	most = Finite(most) and most >= 1 and math.floor(most) or T.MOST
	local best, bestRows, bestShown, bestMean
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" then
			local rows = RowsOf(candidate)
			local shown = #rows <= most + 1 and #rows or most
			local mean = Mean(rows, shown)
			if #rows > 0 and (best == nil or mean > bestMean + 1e-9) then
				best, bestRows, bestShown, bestMean = candidate, rows, shown, mean
			end
		end
	end
	if not best then
		return nil
	end
	local still = true
	for _, row in ipairs(bestRows) do
		if Moves(row) then
			still = false
			break
		end
	end
	local unit
	for index = 1, still and 0 or bestShown do
		if bestRows[index].perSecond ~= true then
			unit = "a cast"
			break
		end
	end
	local style = Colours()
	local head = { { text = Header(M, best, slot, unit), colour = style.header, wrap = true } }
	local notes = {}
	if still then
		notes[1] = T.NO_CHANGE
	else
		for index = 1, bestShown do
			head[#head + 1] = RowLine(M, bestRows[index], info.role, style)
		end
		if #bestRows > bestShown then
			notes[1] = T.MORE:format(#bestRows - bestShown)
		end
	end
	return { head = head, notes = notes, tail = Tail(result), avoid = {}, slots = best.slots, still = still, candidate = best }
end

local function SameSlots(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
		return false
	end
	for index, slot in ipairs(a) do
		if b[index] ~= slot then
			return false
		end
	end
	return true
end

-- What the item does to an enemy's swing (0.5.20, Damage taken), while avoidance shows: GearAvoid.lua's taken { now, with, pct, estimate } of the
-- candidate of A.Compare for the slots the spell rows show (else its first), which A.Compare's candidates carry, else A.Totals of it; nil while
-- avoidance does not show or has no figure.
local function Taken(subject, slots, opts)
	if Avoid("Wanted") ~= true then
		return nil
	end
	local result = Avoid("Compare", subject, opts)
	local candidates = type(result) == "table" and result.candidates or nil
	if type(candidates) ~= "table" then
		return nil
	end
	local chosen = candidates[1]
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" and SameSlots(candidate.slots, slots) then
			chosen = candidate
			break
		end
	end
	if type(chosen) ~= "table" then
		return nil
	end
	local taken = chosen.taken
	if type(taken) ~= "table" then
		local totals = Avoid("Totals", chosen)
		taken = type(totals) == "table" and totals.taken or nil
	end
	if type(taken) == "table" and Finite(taken.pct) then
		return taken
	end
	return nil
end

-- One figure of the Overall line: its word and its change as a share in green when better and red when worse (white for none), ~ before an
-- estimate; lower is better for damage taken.
local function OverallFigure(word, pct, estimate, lowerBetter, style)
	local colour = style.value
	if math.abs(pct) >= T.STILL_PCT then
		colour = ((pct > 0) ~= (lowerBetter == true)) and style.good or style.bad
	end
	return Paint(word .. " " .. (estimate and "~" or "") .. Signed(pct), colour), math.abs(pct) >= T.STILL_PCT
end

-- The Overall line of the block (0.5.20, Overall totals at Weighted, chat.gearTotals): a figure the chosen spells have, each the weighted mean of
-- its rows' percent changes (GearModel.lua's G.Totals of the candidate shown, with the lines and their weights), and Damage taken while avoidance
-- shows (Taken): "Overall  Damage +2.4%  ·  Threat +1.1%  ·  Damage taken -2.1%". Nil when there is no figure, or none changes.
local function Overall(candidate, lines, opts, taken, style)
	local G = Gear()
	local parts, moved = {}, false
	if type(G.Totals) == "function" then
		local ok, totals = pcall(G.Totals, candidate, lines, opts)
		if not ok then
			Report(totals, "totals")
		elseif type(totals) == "table" then
			for _, figure in ipairs(T.FIGURES) do
				local total = totals[figure[1]]
				if type(total) == "table" and Finite(total.pct) and not (Finite(total.n) and total.n <= 0) then
					local text, moves = OverallFigure(figure[2], total.pct, total.estimate == true, false, style)
					parts[#parts + 1], moved = text, moved or moves
				end
			end
		end
	end
	if taken then
		local text, moves = OverallFigure(T.TAKEN, taken.pct, taken.estimate == true, true, style)
		parts[#parts + 1], moved = text, moved or moves
	end
	if not moved then
		return nil
	end
	return { left = T.OVERALL, right = table.concat(parts, T.SEPARATOR), leftColour = style.label, colour = style.value }
end

-- The block of an item, from the cache or G.Compare. In a fight with nothing worked out now, the last block of the item, else one dim line;
-- out of one, G.Compare's reason as one line (as "Needs a one-hand weapon; not compared.") unless it is quiet, else nothing.
local function BlockFor(key, data, link, slot, guid)
	local M, G = Model(), Gear()
	if not (M and G) then
		return nil
	end
	StateOf(M)
	local stats = StatsOf(M)
	local lines, info = Resolve()
	local known = {}
	for _, line in ipairs(lines) do
		if line.known then
			known[#known + 1] = line
		end
	end
	if #known == 0 then
		return nil
	end
	local totals = Opt("gearTotals") ~= "off"
	local cacheKey = table.concat({ key, tostring(Version(M)), list.version, tostring(Avoid("Stamp")), tostring(totals) }, "|")
	local kept = blocks.byKey[cacheKey]
	if kept then
		return kept
	end
	local opts = { mode = "tooltip", listVersion = list.version, role = info.role, guid = guid, data = data, against = Opt("gearAgainst"),
		facing = Opt("gearFacing"), rules = Opt("gearRules"), lowRank = Opt("spellLowRank") ~= false }
	local result = G.Compare(slot or link, known, opts)
	Seen(result)
	local block = Build(M, result, slot, info)
	local style = Colours()
	if block then
		local overall, taken = nil, nil
		if totals then
			taken = Taken(slot or link, block.slots, opts)
			overall = Overall(block.candidate, known, opts, taken, style)
			if overall then
				table.insert(block.head, 2, overall)
			end
		end
		-- The avoidance block after the spell block, for the slots its rows show, while it shows (GearAvoid.lua, A.TipLines); with it, the note in
		-- place of spell rows that do not change says what it counts. Damage taken shows once: in the Overall line while that line has it, else
		-- in the avoidance block; the block's header stays only where more than one line still follows it.
		local more, words = Avoid("TipLines", slot or link, block.slots, opts)
		if type(more) == "table" then
			if block.still and type(words) == "string" then
				block.notes[1] = words
			end
			local header, rest = nil, {}
			for _, entry in ipairs(more) do
				if type(entry) == "table" and not (overall and taken and entry.key == "taken") then
					if entry.header == true then
						header = entry
					else
						rest[#rest + 1] = entry
					end
				end
			end
			if header and #rest > 1 then
				block.avoid[1] = header
			end
			for _, entry in ipairs(rest) do
				block.avoid[#block.avoid + 1] = entry
			end
		end
		block.candidate = nil
		Store(blocks.byKey, blocks.order, cacheKey, block)
		Store(blocks.last, blocks.lastOrder, key, block)
		return block
	end
	if Fighting(stats) then
		return blocks.last[key] or { head = {}, notes = { T.OUT_OF_COMBAT }, tail = {}, avoid = {} }
	end
	-- A reason marked quiet is one no line should show (design 2.4: ammunition the game does not use for the player, an off-hand weapon for one who
	-- does not dual wield, an item not loaded).
	if type(result) ~= "table" or result.quiet == true then
		return nil
	end
	local reason = result.why
	if type(reason) == "string" and reason ~= "" then
		return { head = { { text = reason, colour = style.label, wrap = true } }, notes = {}, tail = {}, avoid = {} }
	end
	return nil
end

-- Adds one line of a block in the style; false when the game refused it. A figure ({ left, right }) has its label light grey and its value in
-- its colour (white by default); a line alone ({ text }) its own colour, light grey by default, a note's dim; GearAvoid.lua's lines are read the
-- same way, with leftColour or rightColour where they give one.
local function Put(tooltip, entry, style)
	if entry.right ~= nil then
		local left = type(entry.leftColour) == "table" and entry.leftColour or style.label
		local right = (type(entry.rightColour) == "table" and entry.rightColour) or (type(entry.colour) == "table" and entry.colour) or style.value
		return (pcall(tooltip.AddDoubleLine, tooltip, tostring(entry.left or ""), tostring(entry.right), left[1], left[2], left[3], right[1], right[2],
			right[3]))
	end
	local colour = (type(entry.colour) == "table" and entry.colour) or (entry.dim == true and style.dim) or style.label
	return (pcall(tooltip.AddLine, tooltip, tostring(entry.text or entry.left or ""), colour[1], colour[2], colour[3], entry.wrap ~= false))
end

-- Adds the block once for each build of the tooltip: the same data with the lines of the first call still there is the same build
-- (Chat.lua:795-806). The head, then the block's notes (its own, "Not wearable yet:" with the game's requirement, and what is not counted): in
-- Compact (chat.tipDetail) joined into one dim line, in Full each its own; then GearAvoid.lua's lines. A line the game refuses stops the adding
-- for this build.
local function Add(tooltip, data, block, later)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local record = added[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local style = Colours()
	local count, going = 0, true
	local function One(entry)
		if going then
			going = Put(tooltip, entry, style)
			if going then
				count = count + 1
			end
		end
	end
	for _, entry in ipairs(block.head) do
		One(entry)
	end
	local notes = {}
	for _, text in ipairs(block.notes or {}) do
		notes[#notes + 1] = text
	end
	if later then
		notes[#notes + 1] = T.NOT_YET .. later
	end
	for _, text in ipairs(block.tail or {}) do
		notes[#notes + 1] = text
	end
	if Opt("tipDetail") == "full" then
		for _, text in ipairs(notes) do
			One({ text = text, colour = style.dim, wrap = true })
		end
	elseif #notes > 0 then
		for index, text in ipairs(notes) do
			notes[index] = (text:gsub("%.$", ""))
		end
		One({ text = table.concat(notes, T.JOIN), colour = style.dim, wrap = true })
	end
	for _, entry in ipairs(block.avoid or {}) do
		One(entry)
	end
	added[tooltip] = { data = data, lines = shown + count }
end

-- Runs a step of the post call as the part, keyed by its first argument (design 4.4); the first error goes once to the error handler, and a part
-- that stops wants SpellModel's events no more.
local function Run(fn, key, ...)
	local ok, err = ns.EachPart(KEY, PART, fn, key, ...)
	if not ok and err ~= nil then
		Report(err)
		if ns.PartStopped(KEY, PART) then
			Want(false)
		end
	end
	return ok
end

-- The work of one item, keyed by its link.
local function Work(key, tooltip, data, link, slot, later, guid)
	local block = BlockFor(key, data, link, slot, guid)
	if block then
		Add(tooltip, data, block, later)
	end
end

-- The tests of one build, keyed by its data: the tooltip, the kind of the data, the key, the item and whether the player can wear it (design 4.4).
local function Find(data, tooltip)
	if not Ours(tooltip) or not IsItem(data) then
		return
	end
	local when = Opt("gearWhen")
	local game, shift = false, false
	if rawequal(tooltip, _G.ItemRefTooltip) then
		-- Built for a plain click on a link alone and never again for a key (header): its lines show at every choice.
		game, shift = true, true
	elseif when == "compare" then
		game = Comparing(tooltip)
		shift = KeyHeld("shift")
		if not (game or shift) then
			return
		end
	elseif not KeyHeld(when) then
		return
	end
	local id = Field(data, "id")
	id = Whole(id) and id or nil
	local guid = Field(data, "guid")
	guid = Plain(guid, "string") and guid ~= "" and guid or nil
	local slot = guid and WornSlot(guid) or nil
	-- At the game's comparison a worn item shows its lines while Shift is held, any other while the game compares.
	if when == "compare" and not ((slot and shift) or (not slot and game)) then
		return
	end
	local link = ItemLink(data, id, guid)
	local loc, itemClass, subclass
	if link then
		loc, itemClass, subclass = EquipLoc(link)
	end
	if not loc then
		return
	end
	local never, later = Wearable(data, itemClass, subclass)
	if never or (id and not Loaded(id)) then
		return
	end
	Run(Work, slot and ("slot " .. slot .. " " .. link) or link, tooltip, data, link, slot, later, guid)
end

local function Wanted()
	return ns.Enabled(KEY) and Opt("gear") == true and not ns.PartStopped(KEY, PART)
end

-- Called by Chat.lua's post call for every build of a tooltip (design 4.4). It returns at once unless the module is on and Your spells in item
-- tooltips wants lines.
function ns.GearTipLines(tooltip, data)
	if Wanted() then
		Run(Find, data, tooltip)
	end
end

-- Called at the end of Chat.lua's Refresh: a row may have changed, so the blocks go, and SpellModel's events are wanted while the lines are.
-- Never raises.
function ns.GearLinesSync()
	Forget()
	Want(Wanted())
end

-- /flatui gear -----------------------------------------------------------------------------------------------------------------------------

-- The spell a typed text names, and whether its rank is kept: a spell link or an ID keeps its rank, a name follows the highest rank (design 4.11).
local function SpellFrom(text)
	local id = tonumber(text:match("|Hspell:(%d+)") or text:match("^spell:(%d+)") or text:match("^(%d+)$") or "")
	if Whole(id) then
		return id, true
	end
	local M = Model()
	local entry = M and M.ByKey(text:lower()) or nil
	if Comparable(entry) then
		local _, top = Highest(M, entry)
		return top or RankId(entry, #entry.ranks), false
	end
	local info = Ask(Call(C_Spell, "GetSpellInfo"), text)
	local found = Field(info, "spellID")
	if Whole(found) then
		return found, text:find("%(") ~= nil
	end
	return nil
end

-- /flatui gear add <spell>.
local function AddNamed(text)
	local id, keep = SpellFrom(text)
	if not id then
		return false, ('Gear comparison: no spell found for "%s".'):format(text)
	end
	return AddLine(id, keep)
end

-- /flatui gear remove <name>: the line of the spell of that name, the one that follows its rank first.
local function RemoveNamed(text)
	local M = Model()
	local entry = M and M.ByKey(text:lower()) or nil
	if type(entry) == "table" then
		local first
		for _, row in ipairs(Entries()) do
			local line = row[3]
			if line and line.key == entry.key then
				if not line.kept then
					return RemoveLine(row[1])
				end
				first = first or row[1]
			end
		end
		if first then
			return RemoveLine(first)
		end
	end
	local id = SpellFrom(text)
	if not id then
		return false, ('Gear comparison: no spell found for "%s".'):format(text)
	end
	return RemoveLine(id)
end

-- /flatui gear weight <name> <0 to 5>: the weight of the line of the spell of that name in the Overall line, the one that follows its rank first,
-- as RemoveNamed finds it.
local function WeightNamed(text)
	local typed, value = text:match("^(.-)%s+([%d%.]+)$")
	value = tonumber(value or "")
	if not typed or typed == "" or not value then
		return false, T.WEIGHT_HELP
	end
	local M = Model()
	local entry = M and M.ByKey(typed:lower()) or nil
	if type(entry) == "table" then
		local first
		for _, row in ipairs(Entries()) do
			local line = row[3]
			if line and line.key == entry.key then
				if not line.kept then
					return SetWeight(row[1], value)
				end
				first = first or row[1]
			end
		end
		if first then
			return SetWeight(first, value)
		end
	end
	local id = SpellFrom(typed)
	if not id then
		return false, ('Gear comparison: no spell found for "%s".'):format(typed)
	end
	return SetWeight(id, value)
end

-- /flatui gear list: the lines with their ranks and weights, and whether they are the defaults.
local function PrintList()
	local _, info = Resolve()
	local rows = Entries()
	if #rows == 0 then
		if info.defaults and info.noSet then
			print("Gear comparison: Flat UI has no spells of its own for your class; /flatui gear add <spell> adds one.")
		elseif info.defaults then
			print(("Gear comparison: none of %s is known yet."):format(Who(info)))
		else
			print("Gear comparison: no spells chosen; /flatui gear add <spell> adds one, /flatui gear reset gives your class's.")
		end
		return
	end
	print(("Gear comparison, %s:"):format(Who(info)))
	for index, row in ipairs(rows) do
		local line = row[3]
		if line then
			local rank = RankText(line.id)
			local weight = Finite(line.weight) and line.weight ~= T.WEIGHT and (", weight " .. WeightText(line.weight)) or ""
			print(("%d. %s%s (%d)%s%s%s"):format(index, line.name, rank and (", " .. rank) or "", line.id, line.kept and ", rank kept" or "",
				weight, line.known and "" or ", not known"))
		else
			print(("%d. %s"):format(index, row[2]))
		end
	end
end

-- Prints the message of a change of the list, or of the window.
local function Say(ok, done, message)
	if not ok then
		Report(done, "list")
		print(T.FAILED)
	elseif type(message) == "string" then
		print(message)
	end
end

-- Calls a function of GearWindow.lua (ns.GearWindowShow, ns.GearWindowToggle) and answers as a pick does, with what it said.
local function Window(fn, ...)
	local said = fn(...)
	return true, Plain(said, "string") and said or nil
end

local function Slash(rest)
	local typed = (Plain(rest, "string") and rest or ""):match("^%s*(.-)%s*$")
	local word, text = typed:match("^(%S*)%s*(.-)$")
	word = word:lower()
	-- A shift-clicked item, or item:ID: compared in the window.
	if typed:find("|Hitem:", 1, true) or typed:match("^[Ii]tem:%d+") then
		local show = ns.GearWindowShow
		if type(show) ~= "function" then
			print(T.NO_WINDOW)
			return
		end
		local link = typed:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or typed:match("(|Hitem:.-|h.-|h)") or typed:match("^([Ii]tem:[%d:%-]+)") or typed
		Say(pcall(Window, show, link))
	elseif typed == "" then
		local toggle = ns.GearWindowToggle
		if type(toggle) ~= "function" then
			-- Without the window the command still says what is compared.
			Say(pcall(PrintList))
			return
		end
		Say(pcall(Window, toggle))
	elseif word == "add" and text ~= "" then
		Say(pcall(AddNamed, text))
	elseif word == "remove" and text ~= "" then
		Say(pcall(RemoveNamed, text))
	elseif word == "weight" then
		Say(pcall(WeightNamed, text))
	elseif word == "bar" then
		Say(pcall(BarAdd, tonumber(text:match("^(%d+)$") or "")))
	elseif word == "reset" then
		Say(pcall(Reset, 1))
	elseif word == "list" then
		Say(pcall(PrintList))
	else
		for _, line in ipairs(T.HELP) do
			print(line)
		end
	end
end

ns.AddSlash(KEY, "gear", Slash, T.HELP)

-- /flatui status ---------------------------------------------------------------------------------------------------------------------------

-- Which spells are compared, for whom, and those not known now.
local function ListStatus()
	local lines, info = Resolve()
	local known, unknown = {}, {}
	for _, line in ipairs(lines) do
		if line.known then
			known[#known + 1] = line.name
		else
			unknown[#unknown + 1] = line.name
		end
	end
	if #known == 0 and #unknown == 0 then
		if info.defaults and info.noSet then
			return "Gear comparison: Flat UI has no spells of its own for your class; /flatui gear add <spell> adds one."
		elseif info.defaults then
			return ("Gear comparison: none of %s is known yet."):format(Who(info))
		end
		return "Gear comparison: no spells chosen; /flatui gear add <spell> adds one."
	end
	if #known == 0 then
		return ("Gear comparison: none of %s is known now: %s."):format(Who(info), table.concat(unknown, ", "))
	end
	local text = ("Gear comparison: %s (%s)"):format(table.concat(known, ", "), Who(info))
	if #unknown > 0 then
		text = text .. "; not known now: " .. table.concat(unknown, ", ")
	end
	return text .. "."
end

-- Against what the comparison counts: the enemy, where the player stands, and the hit cap against a boss (design 2.5, 4.9).
local function AgainstStatus()
	local M = Model()
	local state = M and StateOf(M) or {}
	local against, facing, rules = Opt("gearAgainst") or "auto", Opt("gearFacing") or "role", Opt("gearRules") or "hittable"
	local boss = against == "boss" or (against == "auto" and Level(state) >= T.MAX_LEVEL)
	local front = facing == "front" or (facing == "role" and Role(state) == "tank")
	local where = front and "in front" or "from behind"
	if not boss then
		return ("Gear comparison: against an enemy of your level, %s."):format(where)
	end
	local from = ""
	if rules == "hittable" then
		rules, from = ns.Get("hud.hitTableRules"), " (as on the Hit table tab)"
	end
	return ("Gear comparison: against a boss three levels above you, %s, with a hit cap of %s%s."):format(where, T.CAPS[rules] or T.CAPS.classic, from)
end

-- The rating sizes of the data, else the fixed ones of design 2.5.
local function RatingNote()
	local D = ns.SpellData
	local model = type(D) == "table" and type(D.MODEL) == "table" and D.MODEL or nil
	local sizes = model and type(model.ratings) == "table" and model.ratings or T.RATINGS
	local function Size(name)
		return Finite(sizes[name]) and sizes[name] or T.RATINGS[name]
	end
	return T.RATING_NOTE:format(Size("hit"), Size("crit"), Size("haste"), Size("expertise"))
end

-- The lines of /flatui status while the module is on and Your spells in item tooltips is on with this part running, or the window is open
-- (ns.GearWindowOpen; ns.GearWindowShown is the movers' gate, true while the window may show) (design 4.12).
ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) then
		return {}
	end
	local open = ns.GearWindowOpen
	local window = false
	if type(open) == "function" then
		local ok, shown = pcall(open)
		window = ok and shown == true
	end
	if not window and (Opt("gear") ~= true or ns.PartStopped(KEY, PART)) then
		return {}
	end
	local lines = { ListStatus(), AgainstStatus() }
	if seen.slots then
		lines[#lines + 1] = T.SLOT_NOTE
	end
	if seen.ratings then
		lines[#lines + 1] = RatingNote()
	end
	return lines
end)
