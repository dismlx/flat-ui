local _, ns = ...

-- The spell model of Chat and tooltips (design 4.2, 4.3 and 4.5): what the spell lines (SpellLines.lua), the gear comparison (GearModel.lua and
-- GearLines.lua) and the Gear comparison window (GearWindow.lua) know of the spells and of the player, through ns.SpellModel. It writes nothing on
-- a tooltip or on any frame of the game and draws nothing: it keeps the lookups of the spell data, reads the player's state and stats, hears the
-- events that change them, checks once a session whether the game's spell texts count spell power, and words the power, threat and rule lines
-- as texts SpellLines.lua adds. It adds to the chat module and has no switch of its own, as ChatTips.lua has none (ChatTips.lua:7); its readers ask
-- only while their rows and the module are on. Its reads and its events run as part "your stats" of the chat module, inside
-- ns.EachPart("chat", "your stats", fn, n) keyed by the number n of the read (design 4.4; Core.lua:2188-2224), so three that fail stop the part
-- alone with a line for /flatui status, and its first error goes once to the game's error handler (geterrorhandler), as Bags' parts report theirs
-- (BagsLayout.lua:152-163).
--
-- The data (design 3.2, 3.3). ns.SpellData (SpellData.lua) holds one constructor a class and D.CLASS.ALL (Attack and the shots). The first lookup
-- runs the player's class's constructor and ALL once, never at load, and walks them and D.RULES into the lookups: a rank's spell ID to its entry
-- and place, a key to its entry, a rule by the spells of its tooltip and by its talent, the class's rules and the auras and talents they read.
-- The other classes' tables are never built, and a spell of another class is not found, so the player's numbers never show on an enemy's spell
-- in a death recap (design 6.20). The class is UnitClassBase's (UnitDocumentation.lua:930-945). A known rank is ns.SpellKnown's (Cooldowns.lua),
-- else C_SpellBook.IsSpellKnownOrInSpellBook or IsSpellKnown, as Cooldowns.lua:314-325 asks.
--
-- S.state is read at any time, fights included: none of it is secret (design 4.7), and each part is read on its own marks and keeps its last plain
-- answer.
-- - The gear, after a gear event (design 2.5). A weapon's damage and speed, a shield's block and the ammunition's damage a second are not item
--   stats (research_gear_items.md §1.5), so they come from the lines the game gives for a worn item (C_TooltipInfo.GetInventoryItem,
--   TooltipInfoDocumentation.lua:389-405), matched with patterns built from the client's own strings and separators (LARGE_NUMBER_SEPERATOR,
--   DECIMAL_SEPERATOR, DAMAGE_TEMPLATE, DAMAGE_TEMPLATE_WITH_SCHOOL, SINGLE_DAMAGE_TEMPLATE, SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL,
--   PLUS_DAMAGE_TEMPLATE, PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL, SHIELD_BLOCK_TEMPLATE, AMMO_DAMAGE_TEMPLATE and SPEED: KD GlobalStrings/enUS.lua:13363,
--   5741, 5687-5688, 19328-19329, 16592-16593, 19208, 873, 20628), so they read right in every language; the second school's damage adds to the
--   weapon's. Its class, subclass and inventory type are C_Item.GetItemInfoInstant's (ItemDocumentation.lua:659-679; the ammunition's subclass, arrow
--   or bullet, is kept as ammoKind, for GearModel.lua to tell whether the ranged weapon fires it) and its skill line the hit
--   table's (ns.HitTableCalc.LineOf, HitTableCalc.lua). The lines of an item the client has not loaded (C_Item.IsItemDataCachedByID) are asked
--   for (C_Item.RequestLoadItemDataByID) and read again after GET_ITEM_INFO_RECEIVED. Item calls are never secret (research_gear_items.md §1.7).
-- - Righteous Fury 25780, the one aura of the rules on Forever, read here (design 4.3), not from nameplate threat, whose list is Threat Plates'
--   (PlateThreat.lua:52-53): C_UnitAuras.GetPlayerAuraBySpellID (UnitAuraDocumentation.lua:397-412) answers nothing for an aura the game
--   withholds, so a plain aura sets the flag and none found clears it only out of combat (InCombatLockdown), the rule PlateThreat.lua:219-243
--   follows.
-- - The level (UnitLevel, UnitDocumentation.lua:2474-2487), the class, and the form: GetShapeshiftFormID has no documentation, so its answer must
--   be a plain number, as PlateThreat.lua:198-208 reads it; none is 0.
-- - The role: the first answer of ns.PlayerRole (Core.lua:554-590), which only reads.
-- - The ranks of the talents of D.RULES and D.CRIT (design 3.4, 4.3). The set in use is C_ClassTalents.GetActiveConfigID
--   (ClassTalentsDocumentation.lua:73-80), else the set of the active group of dual spec (C_SpecializationInfo.GetActiveSpecGroup and
--   GetCombatConfigIDForSpecGroup, SpecializationInfoDocumentation.lua:41-55, 90-103), as MostPoints finds it (Core.lua:498-552). Each talent
--   carries its trait node and definition: the node's C_Traits.GetNodeInfo (SharedTraitsDocumentation.lua:370-385, TraitNodeInfo :1093-1127) must
--   hold an entry whose C_Traits.GetEntryInfo (:264-279, :1048-1060) has that definition, and the rank is the node's activeRank while that entry is
--   its active one. A node that does not answer so (the tree changed since the data, design 6.25) makes this file walk the tree once a session:
--   C_Traits.GetConfigInfo(config).treeIDs[1] (:201-215, :1013-1023), C_Traits.GetTreeNodes (:586-600), each node's entries and
--   C_Traits.GetDefinitionInfo (:248-262, :1034-1046) for their spell; S.state.treeWalked then says so. While C_Traits.ConfigHasStagedChanges
--   (:107-120) says a pick waits unapplied in the talent window, the ranks found before stay, as MostPoints keeps them (Core.lua:507-514).
-- - The gear's links and the rest: every slot, ammunition 0 to tabard 19 (GetInventoryItemLink, as Items.lua:322-329 reads it), the permanent
--   enchant of each link, the temporary enchant of each weapon (C_PaperDollInfo.GetTemporaryEnchantmentInfo, PaperDollInfoDocumentation.lua:226-241,
--   read as ChatTips.lua:134-157 reads it) and so Rockbiter Weapon (its enchants are D.ROCKBITER, design 6.17), whether the off hand holds a shield
--   (C_PaperDollInfo.OffhandHasShield, :267-273) and whether the player dual wields (IsDualWielding, PlayerScriptDocumentation.lua:1297-1304).
--
-- S.stats is read only while C_Secrets.ShouldUnitStatsBeSecret() is false (SecretPredicateAPIDocumentation.lua:388-396), since every stat call is
-- SecretWhenUnitStatsRestricted (design 4.7), with the time of the read (GetTime). As HitTableCalc.lua counts them (:69-81), a call that raises or
-- an answer the game withholds is withheld and keeps the whole old S.stats, never a mix of two reads; a missing call or a nil answer is none (an
-- off hand, a ranged weapon or a shield the player does not have). The calls, as the sheet reads them (research_tooltips.md §3.1, PlayerScript-
-- and UnitDocumentation.lua): GetSpellBonusDamage for schools 2 to 7 (its nil is 0), GetSpellBonusHealing, UnitAttackPower and
-- UnitRangedAttackPower (base and both buffs), GetShieldBlock, GetCritChance, GetRangedCritChance, GetSpellCritChance, GetMeleeHaste,
-- GetRangedHaste (with the quiver's), UnitSpellHaste, GetCombatRating of the three haste ratings, UnitStat's effective five, UnitAttackSpeed,
-- UnitDamage and UnitRangedDamage; then, for strength, agility and intellect, the gain a point of GetAttackPowerForStat,
-- GetRangedAttackPowerForStat, GetCritChanceFromStat and GetSpellCritChanceFromStat at the total and ten points above it (design 2.5). So
-- S.stats.per[stat] = { ap, rap, crit, spellCrit } holds attack power and ranged attack power a point, and crit and spell crit in percent a
-- point: the crit calls give fractions, which the sheet shows times 100 (Camelot/PaperDollFrameStats.lua:277, 318), and they are kept times 100,
-- the unit of S.stats.crit; GearModel.lua reads them as that. PLAYER_REGEN_DISABLED makes S.stats old until the next plain read, and so does a
-- withheld read in a fight, so stats read plain at the start of a fight turn old once the game withholds them. Right after
-- each plain read the functions of M.AfterRead run in the same frame (GearModel.lua reads the hit table's inputs).
--
-- The text check (design 4.3, 6.1), once a session, out of combat with the stats plain (InCombatLockdown), on an English client (GetLocale,
-- LocaleDocumentation.lua:49-56), with a probe rank of D.PROBES known whose spell power part is at least 10: the first "N to M" of
-- C_Spell.GetSpellDescription (SpellDocumentation.lua:345-360; empty while the spell is not loaded, then asked again after SPELL_TEXT_UPDATE) is
-- held against the probe's base without and with the player's spell power, and C_Spell.GetSpellName (:518-533) and C_Spell.GetSpellSubtext
-- (:578-593) name the probe for /flatui status.
--
-- The events (design 4.5) are heard by a frame of this file's own (CreateFrame, no name, in ns.Own; SetScript OnEvent), registered
-- (RegisterUnitEvent for the player where the client can, else RegisterEvent, as HitTable.lua:1062-1078 does) only while M.Want has an owner and
-- taken back with UnregisterAllEvents. An event only marks what it changes, and nothing is read until a reader asks, but for these:
-- UPDATE_SHAPESHIFT_FORM reads the state at once, as a stance taken in a fight changes the multipliers; ADDON_RESTRICTION_STATE_CHANGED reads
-- marked stats at once, as it comes before a restriction becomes active, while IsAddOnRestrictionActive is false, the last moment stats are plain
-- (research_tooltips.md §2.2); PLAYER_REGEN_DISABLED makes the stats old; SPELL_TEXT_UPDATE runs the text check again while its probe's text was
-- empty; GET_ITEM_INFO_RECEIVED marks the gear for a worn item that waited, whose lines are read again (M.Version changes only if they then say
-- something else: no reader keeps an answer for an item the client had not loaded, so nothing else waits for the event). The events: the
-- player's UNIT_STATS, UNIT_ATTACK_POWER, UNIT_RANGED_ATTACK_POWER, UNIT_DAMAGE, UNIT_ATTACK_SPEED, UNIT_RANGEDDAMAGE,
-- UNIT_SPELL_HASTE, UNIT_AURA and UNIT_INVENTORY_CHANGED; COMBAT_RATING_UPDATE, SPELL_POWER_CHANGED, PLAYER_DAMAGE_DONE_MODS,
-- SKILL_LINES_CHANGED, PLAYER_EQUIPMENT_CHANGED, WEAPON_ENCHANT_CHANGED, TRAIT_CONFIG_UPDATED, PLAYER_TALENT_UPDATE, CHARACTER_POINTS_CHANGED,
-- ACTIVE_COMBAT_CONFIG_CHANGED, TRAIT_CONFIG_LIST_UPDATED, ACTIVE_TALENT_GROUP_CHANGED, PLAYER_ROLES_ASSIGNED, GROUP_ROSTER_UPDATE,
-- TRAIT_TREE_CURRENCY_INFO_UPDATED, PLAYER_LEVEL_UP, UPDATE_SHAPESHIFT_FORM, PLAYER_ENTERING_WORLD, SPELLS_CHANGED, SPELL_TEXT_UPDATE,
-- ADDON_RESTRICTION_STATE_CHANGED, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED and GET_ITEM_INFO_RECEIVED (each in events.yaml of the client).
--
-- The lines (design 1.2-1.4) are texts and colours' names only, in blocks each with its title (Spell power, Total, Threat), which SpellLines.lua
-- shows as the block's header where more than one line follows: the share of a power part in words with what it adds with the player's stats,
-- the total of one cast (0.5.20: what it does now with the player's stats, base and bonus together) and its rates (the expected value with crits
-- and misses from GearModel.lua's G.Expect, looked up when asked; a second of cast time, from the castTime of C_Spell.GetSpellInfo,
-- SpellDocumentation.lua:416-430, else the rank's, the global cooldown at least; and a point of mana, from C_Spell.GetSpellPowerCost,
-- :535-549), the threat block with its multipliers (the rules of design 2.5, G), and the lines of a stance, form, aura or talent tooltip. Amounts
-- are worded with the rounding of design 1.2, and the gear comparison's with that of design 2.3 (M.Fmt, which GearLines.lua, GearAvoid.lua and
-- GearWindow.lua use too, with its one style of every line: M.Fmt.Style, whose header, good and bad colours are the game's NORMAL_FONT_COLOR,
-- GREEN_FONT_COLOR and RED_FONT_COLOR, read once as this file loads, Blizzard_SharedXMLBase/Color.lua:82-86), thousands broken by the game's
-- BreakUpLargeNumbers under pcall (as CombatText.lua:1445-1446), and a spell's name in a dim line is the game's (C_Spell.GetSpellName).

local KEY, PART = "chat", "your stats"
local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The constants of the file, in one table so its functions stay under the client's count of upvalues (Lua 5.1: 60 a function), as Cooldowns.lua
-- keeps its own (Cooldowns.lua:108-109).
local K = {
	-- Every equipment slot, ammunition (0) to tabard (19), and the three weapons: main hand, off hand and ranged (INVSLOT_AMMO to INVSLOT_TABARD,
	-- Blizzard_FrameXMLBase/Constants.lua:135-155). The game keeps temporary enchants on the first two (PaperDollInfoDocumentation.lua:226-241).
	FIRST_SLOT = 0, LAST_SLOT = 19, AMMO = 0, MAIN = 16, OFF = 17, RANGED = 18, WEAPON_SLOTS = { 16, 17, 18 }, TEMP_SLOTS = { 16, 17 },
	-- Enum.ItemClass.Weapon and Enum.ItemWeaponSubclass.Dagger (ItemConstantsDocumentation.lua:269-298, 640), and the inventory type of a two-hand
	-- weapon (research_gear_items.md §3.1).
	WEAPON = 2, DAGGER = 15, TWO_HAND = "INVTYPE_2HWEAPON",
	-- The spell schools GetSpellBonusDamage counts, holy to arcane, as the sheet reads them (Camelot/PaperDollFrame.lua:1072-1107), and Holy.
	SCHOOLS = { 2, 3, 4, 5, 6, 7 }, HOLY = 2,
	-- UnitStat's five stats, and the primary ones whose points the comparison turns into attack power and crit (strength, agility, intellect:
	-- LE_UNIT_STAT_*), read at the total and this many points above it (design 2.5).
	STATS = 5, RATE_STATS = { 1, 2, 4 }, STEP = 10,
	-- The haste ratings, melee, ranged and spell (CR_HASTE_MELEE to CR_HASTE_SPELL, Camelot/PaperDollFrame.lua:21-23).
	HASTE = { 18, 19, 20 },
	-- Forms by GetShapeshiftFormID: Cat Form 1, Bear Form 5 and Dire Bear Form 8, Forever's DRUID_BEAR_FORM (Blizzard_FrameXMLBase/Camelot/
	-- Constants.lua:14; PlateThreat.lua:56; research_threat_tanks.md §3). In one a weapon ability swings at the form's speed (design 2.5).
	CAT = 1, BEARS = { [5] = true, [8] = true },
	-- Righteous Fury's aura, the only one on Forever: 20468-20470 are the talent and 407627 is Season of Discovery's (design 4.3).
	FURY = 25780,
	-- The most lines of an item read, entries of a talent node, and nodes of a tree walked.
	MAX_LINES = 60, MAX_ENTRIES = 8, MAX_NODES = 1000,
	-- While no reader wants the events, a value read stands for this many seconds before it is read again.
	STALE = 1,
	-- The calls of the spell book a known spell is asked with when ns.SpellKnown (Cooldowns.lua) is not there, as Cooldowns.lua:314-325 asks.
	KNOWN_CALLS = { "IsSpellKnownOrInSpellBook", "IsSpellKnown" },
	-- The text check (design 4.3, 6.1): the languages whose texts it reads, how near a candidate the text's mean must be and how far from both of
	-- the other side, and the least spell power part that tells the two apart.
	ENGLISH = { enUS = true, enGB = true }, NEAR = 1, FAR = 5, ENOUGH = 10,
	-- What a share counts for a weapon ability that the data leaves out, the model's own values (SpellData.lua, D.MODEL; design 3.2).
	MODEL = { apPerDps = 14, healThreat = 0.5, offHand = 0.5, gcd = 1.5, norm = { one = 2.4, dagger = 1.7, two = 3.3, ranged = 2.8 },
		form = { cat = 1.0, bear = 2.5 }, downrank = { grace = 17, step = 0.05 } },
	SCHOOL_NAMES = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" },
	-- The order of the bases, the worst last: client data, measured, estimate (design 3.5).
	BASIS = { c = 1, m = 2, e = 3 },
	-- What a word without digits matches in a line the game writes (a school's name), and the words a spell's name keeps small.
	WORD = "(%D-)", SMALL = { of = true, the = true, ["and"] = true, a = true, ["in"] = true },
	-- A note after a share shorter than this stays on its line; a longer one gets a dim line of its own that wraps (design 1.2).
	NOTE_WIDTH = 50,
	-- The first half of the dim line of a part the game's text counts otherwise (design 1.3: Seal of Righteousness).
	OTHERWISE = "The game's text shows a range for any weapon",
	-- The comparison kinds that deal damage (SpellData.lua, cmp), and the threat kinds the multipliers in force change (design 2.5: Fade's
	-- temporary amount takes none; a power gain is threat a point of rage, which no multiplier of the spell changes, and its note in the data
	-- says which rage a stance or form changes, research_threat_rest.md §1, research_threat_tanks.md §2).
	DAMAGE_KINDS = { spell = true, dot = true, channel = true, strike = true, apstrike = true, finisher = true, auto = true, shot = true, wand = true,
		seal = true, proc = true },
	TAKES_G = { mult = true, bonus = true, flat = true, more = true, drop = true, heal = true, caster = true },
	-- The parts of the player marked for the next read (M.Mark), the fields of the gear part, and the fields of S.stats a comparison of two reads
	-- leaves out.
	ALL = { "state", "stats", "talents", "gear", "spells", "role" },
	GEAR = { "links", "enchants", "temp", "weapons", "shield", "shieldBlock", "ammo", "ammoKind", "twoHand", "dual", "rockbiter" },
	SKIP = { time = true, old = true },
	-- The rows of the Spells and gear tab (design 4.9), the hit table's hit cap row its Hit cap against a boss can follow, and Your role of
	-- nameplate threat, which ns.PlayerRole reads: a change of any of them changes M.Version, and of the last the role too.
	ROWS = { "chat.spellPower", "chat.spellStats", "chat.spellLowRank", "chat.spellThreat", "chat.spellWhen", "chat.spellTotal", "chat.spellRates",
		"chat.tipDetail", "chat.gear", "chat.gearWhen", "chat.gearMost", "chat.gearAgainst", "chat.gearFacing", "chat.gearRules", "chat.gearTotals",
		"chat.gearSwing", "hud.hitTableRules", "nameplates.threatRole" },
	ROLE_ROW = "nameplates.threatRole",
	-- The spell totals (Total, chat.spellTotal; its rates, chat.spellRates). The kinds of the data a total is worked out for: the rest (a seal, a
	-- proc, a threat alone) have only the rates line, from GearModel.lua's G.Expect. The kinds that last (their total is over their duration and a
	-- tick) and that heal (their total counts their healing parts, as GearModel.lua's Suits). The ammunition each ranged weapon fires by its
	-- subclass (bow 2 and crossbow 18 arrows, gun 3 bullets), as GearModel.lua's K.FIRES; the paw's least damage and an empty hand's speed, as its
	-- K.PAW_LEAST and K.UNARMED_SPEED. Enum.PowerType.Mana (PowerTypeConstantsDocumentation.lua:25), the one power a figure a point of is given for.
	TOTAL_KINDS = { spell = true, dot = true, channel = true, heal = true, hot = true, strike = true, apstrike = true, finisher = true, auto = true,
		shot = true, wand = true },
	LASTING = { dot = true, hot = true }, HEALS = { heal = true, hot = true }, FIRES = { [2] = 2, [18] = 2, [3] = 3 },
	PAW_LEAST = 1, UNARMED_SPEED = 2.0, MANA = 0, MAX_COSTS = 8,
	-- The unit of a total by the part's per (design 1.2), and of the strikes and swings by kind.
	PER_UNIT = { hit = "a hit", block = "a block", stack = "a stack", proc = "a proc" },
	KIND_UNIT = { strike = "a hit", apstrike = "a hit", finisher = "a hit at 5 points", auto = "a swing", shot = "a shot", wand = "a shot" },
	-- The colours of the style (design of 0.5.20: one style for every line): the game's NORMAL_FONT_COLOR, GREEN_FONT_COLOR and RED_FONT_COLOR from
	-- its colour table (Blizzard_SharedXMLBase/Color.lua:82-86, which makes each a global of r, g and b), else their usual values; the light grey
	-- of a label, the white of a value and the dim of a note (the hit table's DIM, HitTable.lua:79).
	STYLE = { header = { "NORMAL_FONT_COLOR", 1, 0.82, 0 }, good = { "GREEN_FONT_COLOR", 0.1, 1, 0.1 }, bad = { "RED_FONT_COLOR", 1, 0.1, 0.1 } },
	LABEL = { 0.82, 0.82, 0.82 }, VALUE = { 1, 1, 1 }, DIM = { 0.66, 0.68, 0.62 },
	-- The player's own unit events (RegisterUnitEvent), then the others (design 4.5; each in events.yaml of the client).
	PLAYER_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE",
		"UNIT_SPELL_HASTE", "UNIT_AURA", "UNIT_INVENTORY_CHANGED" },
	EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_DAMAGE_DONE_MODS", "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
		"WEAPON_ENCHANT_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED",
		"TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
		"PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "SPELL_TEXT_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" },
}
-- What each event marks for the next read. The talent events and the hit table's ROLE_EVENTS (HitTable.lua:116-118) mark the role, which
-- picks the defaults and the facing of the gear comparison as it picks the hit table's; the player's UNIT_AURA marks it too, for Righteous Fury
-- and the game's tank aura, which ns.PlayerRole reads through nameplate threat (HitTable.lua:112-113). A new item changes the stats as well,
-- whose own events can come after it, and the end of a fight lets an aura found missing be cleared (PlateThreat.lua:219-243).
K.ON = {
	UNIT_STATS = { "stats" }, UNIT_ATTACK_POWER = { "stats" }, UNIT_RANGED_ATTACK_POWER = { "stats" }, UNIT_DAMAGE = { "stats" },
	UNIT_ATTACK_SPEED = { "stats" }, UNIT_RANGEDDAMAGE = { "stats" }, UNIT_SPELL_HASTE = { "stats" }, UNIT_AURA = { "stats", "state", "role" },
	UNIT_INVENTORY_CHANGED = { "gear" }, COMBAT_RATING_UPDATE = { "stats" }, SPELL_POWER_CHANGED = { "stats" },
	PLAYER_DAMAGE_DONE_MODS = { "stats" }, SKILL_LINES_CHANGED = { "stats" }, PLAYER_EQUIPMENT_CHANGED = { "gear", "stats" },
	WEAPON_ENCHANT_CHANGED = { "gear" }, TRAIT_CONFIG_UPDATED = { "talents", "role" }, PLAYER_TALENT_UPDATE = { "talents", "role" },
	CHARACTER_POINTS_CHANGED = { "talents", "role" }, ACTIVE_COMBAT_CONFIG_CHANGED = { "talents", "role" },
	TRAIT_CONFIG_LIST_UPDATED = { "talents", "role" }, ACTIVE_TALENT_GROUP_CHANGED = { "talents", "role" }, PLAYER_ROLES_ASSIGNED = { "role" },
	GROUP_ROSTER_UPDATE = { "role" }, TRAIT_TREE_CURRENCY_INFO_UPDATED = { "role" }, PLAYER_LEVEL_UP = "all", PLAYER_ENTERING_WORLD = "all",
	UPDATE_SHAPESHIFT_FORM = { "state", "stats", "role" }, SPELLS_CHANGED = { "spells" }, PLAYER_REGEN_DISABLED = { "stats" },
	PLAYER_REGEN_ENABLED = { "stats", "state" },
}

local M = {}
ns.SpellModel = M

-- state and stats: S.state and S.stats of design 4.3. marks: the parts of the player to read before the next answer (M.Mark). version: what
-- M.Version gives; rows: the rows of K.ROWS at its last ask. owners: who wants the events
-- (M.Want); hearing: the frame hears them; frame: that frame; units and alone: the unit events it hears and those the client registered for
-- the player alone, as HitTable.lua keeps them. count: the number of the last read, the key of ns.EachPart; reported: its first error went to
-- the error handler. reading: a read runs, so an M.AfterRead function that asks again gets what is there. fresh: when everything was last
-- marked while nothing hears. after: the functions of M.AfterRead, and failed: those whose error went to the handler. highest and before:
-- M.Highest's answers now and before the last SPELLS_CHANGED. parsed: what the lines of each worn item said, by slot, kept by link. check: the
-- text check (M.TextCheck). unstaged: the ranks found for each set of talents while no pick waited; nodes: those the walk of the tree found;
-- walked: the tree was walked. lookups: the lookups of the data; patterns: the patterns of the item lines.
local S = {
	state = {}, stats = nil,
	marks = { state = true, stats = true, talents = true, gear = true, spells = true, role = true },
	version = 1, rows = {}, owners = {}, hearing = false, frame = nil, units = {}, alone = {},
	count = 0, reported = false, reading = false, fresh = nil, after = {}, failed = {}, highest = {}, before = nil, parsed = {},
	check = { done = false, result = nil, name = nil, rank = nil, waiting = nil },
	unstaged = {}, nodes = nil, walked = false, lookups = nil, patterns = nil,
}
S.state.version = S.version
-- Hears the events or stops (the events, below).
local Hear

-- Reading the game -------------------------------------------------------------------------------------------------------------------------------

-- The first answer of a call of the game, or nil when the client lacks the call, it raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- t[key], for pcall.
local function Index(t, key)
	return t[key]
end

-- A field of a table the game gave, or nil when the table or the field is withheld, or reading it raises.
local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- A function of one of the game's tables (C_Traits and the others), or nil when the client has none.
local function Api(space, name)
	local fn = Field(_G[space], name)
	return type(fn) == "function" and fn or nil
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Finite(value) and value >= 0 and value == math.floor(value)
end

-- The answers of a pcall, all plain: true and the answers; false when the call raised or the game withheld one of them.
local function Plainly(ok, ...)
	if not ok then
		return false
	end
	for index = 1, select("#", ...) do
		if IsSecret((select(index, ...))) then
			return false
		end
	end
	return true, ...
end

-- The answers of a stat call: true and the answers; true and none for a client without the call; false when the call raises or the game
-- withholds an answer. As HitTableCalc.lua's Call counts them (HitTableCalc.lua:69-81), a raise or a secret is withheld, and a missing call or a
-- nil answer is none (design 4.3).
local function Read(fn, ...)
	if type(fn) ~= "function" then
		return true
	end
	return Plainly(pcall(fn, ...))
end

-- Base plus the positive and negative buffs, as the sheet adds attack power (Camelot/PaperDollFrameStats.lua:389, 417), or nil without a base.
local function Sum(base, plus, minus)
	if not Finite(base) then
		return nil
	end
	return base + (Finite(plus) and plus or 0) + (Finite(minus) and minus or 0)
end

local function Positive(value)
	return Finite(value) and value > 0 and value or nil
end

-- Two plain values, tables of them compared field by field, are the same; the fields of skip are left out.
local function Same(a, b, skip)
	if a == b then
		return true
	elseif type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if not (skip and skip[key]) and not Same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if not (skip and skip[key]) and a[key] == nil then
			return false
		end
	end
	return true
end

-- The worse of two bases (design 3.5).
local function Worse(a, b)
	if (K.BASIS[b] or 0) > (K.BASIS[a] or 0) then
		return b
	end
	return a
end

-- True when value is the number set or one of the list set.
local function InSet(set, value)
	if value == nil then
		return false
	elseif type(set) == "table" then
		for _, item in ipairs(set) do
			if item == value then
				return true
			end
		end
		return false
	end
	return set == value
end

-- True when two numbers or lists of numbers share one.
local function Overlap(a, b)
	for _, value in ipairs(type(a) == "table" and a or { a }) do
		if InSet(b, value) then
			return true
		end
	end
	return false
end

-- A value of the data given once or by rank.
local function ValueAt(value, index)
	if type(value) == "table" then
		return value[index]
	end
	return value
end

-- The number a rank gives a part (its list by part), or nil where it gives none.
local function PartValue(list, index)
	local value = type(list) == "table" and list[index] or nil
	return Finite(value) and value or nil
end

-- The letter of a basis given once or a letter a rank (design 3.2: "mmmmmeeee").
local function BasisAt(basis, index)
	if type(basis) ~= "string" or basis == "" then
		return "c"
	elseif #basis == 1 then
		return basis
	end
	local letter = basis:sub(index, index)
	return letter ~= "" and letter or basis:sub(-1)
end

-- A value of the model's constants (SpellData.lua, D.MODEL), the file's own where the data has none.
local function ModelOf(group, field)
	local data = ns.SpellData
	local model = type(data) == "table" and type(data.MODEL) == "table" and data.MODEL or nil
	local value = model and model[group]
	if field then
		value = type(value) == "table" and value[field] or nil
		if not Finite(value) then
			value = K.MODEL[group][field]
		end
	elseif not Finite(value) then
		value = K.MODEL[group]
	end
	return value
end

local function SchoolNames()
	local data = ns.SpellData
	return type(data) == "table" and type(data.SCHOOL_NAMES) == "table" and data.SCHOOL_NAMES or K.SCHOOL_NAMES
end

-- The part ---------------------------------------------------------------------------------------------------------------------------------------

-- An error of a read, once to the game's error handler, as Bags' parts report theirs (BagsLayout.lua:152-163).
local function Report(err)
	if S.reported or err == nil then
		return
	end
	S.reported = true
	local handler = Ask(geterrorhandler)
	if type(handler) == "function" then
		pcall(handler, err)
	end
end

-- True when the chat module is registered, so its parts can run through ns.EachPart.
local function Registered()
	return type(ns.modules) == "table" and type(ns.modules[KEY]) == "table" and type(ns.EachPart) == "function"
end

-- True once the part has stopped after its failures: then nothing is read, nothing is heard, and the last answers stand.
local function Stopped()
	if not Registered() or type(ns.PartStopped) ~= "function" then
		return false
	end
	local ok, stopped = pcall(ns.PartStopped, KEY, PART)
	return ok and stopped == true
end

-- Runs a read or an event of this file as part "your stats" of the chat module (design 4.4), keyed by the number of the read, so three reads
-- that fail stop the part alone, with its note for /flatui status (Core.lua:2188-2224). fn gets that number first.
local function Run(fn, ...)
	S.count = S.count + 1
	if Registered() then
		local called, ok, err = pcall(ns.EachPart, KEY, PART, fn, S.count, ...)
		if not called then
			Report(ok)
			return false
		elseif not ok then
			Report(err)
			if Hear and Stopped() then
				Hear(false)
			end
		end
		return ok == true
	end
	local ok, err = pcall(fn, S.count, ...)
	if not ok then
		Report(err)
	end
	return ok
end

-- A value read differs from the last read: every cache keyed by M.Version is old.
local function Bump()
	S.version = S.version + 1
	S.state.version = S.version
end

local function MarkAll()
	for _, what in ipairs(K.ALL) do
		S.marks[what] = true
	end
end

-- While no reader wants the events, nothing marks a change, so what was read stands for K.STALE seconds.
local function Freshen()
	if S.hearing then
		return
	end
	local now = Ask(GetTime)
	if not Finite(now) or S.fresh == nil or now - S.fresh >= K.STALE then
		S.fresh = now
		MarkAll()
	end
end

-- The lookups ------------------------------------------------------------------------------------------------------------------------------------

-- An entry of the data into the lookups: its key, and the spell ID of each rank with its place. own: the keys of the class's constructor.
local function AddEntry(L, entry, all)
	if type(entry) ~= "table" or type(entry.key) ~= "string" or type(entry.ranks) ~= "table" then
		return
	end
	if L.byKey[entry.key] == nil then
		L.byKey[entry.key] = entry
		L.own[entry.key] = not all or nil
	end
	for index, rank in ipairs(entry.ranks) do
		local id = type(rank) == "table" and rank[1] or nil
		if Whole(id) and L.byId[id] == nil then
			L.byId[id] = { entry, index }
		end
	end
end

-- A talent whose rank is read, once.
local function AddTalent(L, spell, node, def)
	if not Whole(spell) or L.seen[spell] then
		return
	end
	L.seen[spell] = true
	L.talentList[#L.talentList + 1] = { spell = spell, node = node, def = def }
end

-- A rule of the class into the lookups: by the spells of its tooltip, by its talent, and the aura it reads.
local function AddRule(L, rule)
	L.rules[#L.rules + 1] = rule
	for _, tip in ipairs(type(rule.tip) == "table" and rule.tip or { rule.tip }) do
		if Whole(tip) and L.tips[tip] == nil then
			L.tips[tip] = rule
		end
	end
	if Whole(rule.talent) then
		L.talents[rule.talent] = rule
		AddTalent(L, rule.talent, rule.node, rule.def)
	end
	if Whole(rule.aura) then
		L.auras[rule.aura] = true
	end
end

-- True when a list of keys names one of the class's own entries: a crit talent is the class's when one of its spells is.
local function Mine(L, keys)
	for _, key in ipairs(type(keys) == "table" and keys or {}) do
		if L.own[key] then
			return true
		end
	end
	return false
end

-- The lookups of design 3.3, built the first time something asks, by one walk of the player's class's constructor, ALL's and D.RULES: the
-- other classes' tables are never built. Nil while the data or the class is not there yet, so the next ask tries again.
local function Lookups()
	if S.lookups then
		return S.lookups
	end
	local data = ns.SpellData
	local class = Ask(UnitClassBase, "player")
	if type(data) ~= "table" or type(data.CLASS) ~= "table" or not Plain(class, "string") then
		return nil
	end
	local L = { class = class, byId = {}, byKey = {}, own = {}, tips = {}, talents = {}, rules = {}, auras = {}, talentList = {},
		seen = {} }
	for _, name in ipairs({ class, "ALL" }) do
		local make = data.CLASS[name]
		if type(make) == "function" then
			local ok, list = pcall(make)
			if ok and type(list) == "table" then
				for _, entry in ipairs(list) do
					AddEntry(L, entry, name == "ALL")
				end
			end
		end
	end
	-- A rule names the spells of its tooltip itself (tip); the data writes no entry field rule (make_spelltips.py, FIELDS).
	for _, rule in ipairs(type(data.RULES) == "table" and data.RULES or {}) do
		if type(rule) == "table" and (rule.class == nil or rule.class == "ALL" or rule.class == class) then
			AddRule(L, rule)
		end
	end
	for _, crit in ipairs(type(data.CRIT) == "table" and data.CRIT or {}) do
		if type(crit) == "table" and Mine(L, crit.spells) then
			AddTalent(L, crit.talent, crit.node, crit.def)
		end
	end
	S.lookups = L
	return L
end

-- True while the player knows a spell: ns.SpellKnown of Cooldowns.lua, the player's book and the pet's; without it the book's own calls, and a
-- client with neither counts it known, as Cooldowns.lua:314-325 does.
local function Knows(id)
	if type(ns.SpellKnown) == "function" then
		local ok, known = pcall(ns.SpellKnown, id)
		if ok and not IsSecret(known) then
			return known == true
		end
	end
	for _, name in ipairs(K.KNOWN_CALLS) do
		local answer = Ask(Api("C_SpellBook", name), id)
		if type(answer) == "boolean" then
			return answer
		end
	end
	return true
end

-- The lines of worn items -------------------------------------------------------------------------------------------------------------------------

-- The magic characters of a Lua pattern, escaped.
local function Escape(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- A string of the game's, else the English one of this client (KD GlobalStrings/enUS.lua).
local function Global(name, fallback)
	local value = _G[name]
	if Plain(value, "string") and value ~= "" then
		return value
	end
	return fallback
end

-- A pattern for a line the game writes with a template of its strings: each %s or %d, or %1$s and the like, becomes a capture, of a number or, at
-- the arguments words names, of a word without digits; order gives each capture's argument.
local function Template(template, words, number)
	if not Plain(template, "string") or template == "" then
		return nil
	end
	local out, order, place, at, size = { "^" }, {}, 0, 1, #template
	while at <= size do
		local char = template:sub(at, at)
		if char == "%" then
			local digits = template:match("^(%d+)%$[sd]", at + 1)
			local spec = template:sub(at + 1, at + 1)
			if digits then
				local arg = tonumber(digits)
				order[#order + 1] = arg
				out[#out + 1] = words[arg] and K.WORD or number
				at = at + #digits + 3
			elseif spec == "s" or spec == "d" then
				place = place + 1
				order[#order + 1] = place
				out[#out + 1] = words[place] and K.WORD or number
				at = at + 2
			elseif spec == "%" then
				out[#out + 1] = "%%"
				at = at + 2
			else
				out[#out + 1] = "%%"
				at = at + 1
			end
		else
			out[#out + 1] = Escape(char)
			at = at + 1
		end
	end
	out[#out + 1] = "$"
	return { pattern = table.concat(out), order = order }
end

-- The arguments of a line written with a template, by their place in the template, or nil when the line is not one.
local function Match(compiled, text)
	if not compiled or not Plain(text, "string") then
		return nil
	end
	local found = { text:match(compiled.pattern) }
	if found[1] == nil then
		return nil
	end
	local args = {}
	for index, arg in ipairs(compiled.order) do
		args[arg] = found[index]
	end
	return args
end

-- The patterns of the lines of a weapon, a shield and ammunition, from the client's own strings and separators (design 2.5): the four main
-- damage lines in the order that keeps them apart, the second school's two, the shield's block, the ammunition's damage a second, the speed, and
-- the first "N to M" of a spell's text.
local function Patterns()
	if S.patterns then
		return S.patterns
	end
	local thousands = Global("LARGE_NUMBER_SEPERATOR", ",")
	local decimal = Global("DECIMAL_SEPERATOR", ".")
	local number = "([%d" .. Escape(thousands) .. Escape(decimal) .. "]+)"
	local P = { thousands = thousands, decimal = decimal }
	P.damage = {
		Template(Global("DAMAGE_TEMPLATE", "%s - %s Damage"), {}, number),
		Template(Global("DAMAGE_TEMPLATE_WITH_SCHOOL", "%s - %s %s Damage"), { [3] = true }, number),
		Template(Global("SINGLE_DAMAGE_TEMPLATE", "%s Damage"), {}, number),
		Template(Global("SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL", "%s %s Damage"), { [2] = true }, number),
	}
	P.plus = {
		Template(Global("PLUS_DAMAGE_TEMPLATE", "+ %s - %s Damage"), {}, number),
		Template(Global("PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL", "+%s - %s %s Damage"), { [3] = true }, number),
	}
	P.block = Template(Global("SHIELD_BLOCK_TEMPLATE", "%s Block"), {}, number)
	P.ammo = Template(Global("AMMO_DAMAGE_TEMPLATE", "Adds %s damage per second"), {}, number)
	P.speed = "^" .. Escape(Global("SPEED", "Speed")) .. "%s*" .. number .. "$"
	P.range = number .. " to " .. number
	S.patterns = P
	return P
end

-- A number as the game writes it, with its own separators.
local function Number(text)
	local P = Patterns()
	if not Plain(text, "string") then
		return nil
	end
	local plain = text
	if P.thousands ~= P.decimal then
		plain = plain:gsub(Escape(P.thousands), "")
	end
	if P.decimal ~= "." then
		plain = plain:gsub(Escape(P.decimal), ".")
	end
	local value = tonumber(plain)
	return Finite(value) and value or nil
end

-- What the lines of an item say: the damage of its main line, the second school's, its speed, a shield's block, ammunition's damage a second.
local function LinesOf(lines)
	local P = Patterns()
	local info = {}
	for index = 1, K.MAX_LINES do
		local line = Field(lines, index)
		if line == nil then
			break
		end
		local left, right = Field(line, "leftText"), Field(line, "rightText")
		if Plain(left, "string") then
			if info.min == nil then
				for _, compiled in ipairs(P.damage) do
					local args = Match(compiled, left)
					if args then
						info.min = Number(args[1])
						info.max = Number(args[2]) or info.min
						break
					end
				end
			end
			for _, compiled in ipairs(P.plus) do
				local args = Match(compiled, left)
				local low, high = args and Number(args[1]), args and Number(args[2])
				if low and high then
					info.plusMin, info.plusMax = (info.plusMin or 0) + low, (info.plusMax or 0) + high
					break
				end
			end
			local block, ammo = Match(P.block, left), Match(P.ammo, left)
			if block and info.block == nil then
				info.block = Number(block[1])
			end
			if ammo and info.ammo == nil then
				info.ammo = Number(ammo[1])
			end
			if info.speed == nil then
				info.speed = Number(left:match(P.speed))
			end
		end
		if Plain(right, "string") and info.speed == nil then
			info.speed = Number(right:match(P.speed))
		end
	end
	return info
end

-- C_Item.GetItemInfoInstant of a link: the item ID, its inventory type, class and subclass, or nil.
local function Instant(link)
	local ok, id, _, _, loc, _, class, subclass = Plainly(pcall(Api("C_Item", "GetItemInfoInstant"), link))
	if not ok then
		return nil
	end
	return Whole(id) and id or nil, Plain(loc, "string") and loc or nil, Finite(class) and class or nil, Finite(subclass) and subclass or nil
end

-- What the worn item of a slot says, kept by link: read from the lines the game gives for it, and read again once the game has loaded an item it
-- had not (GET_ITEM_INFO_RECEIVED). A weapon also gets its record of S.state.weapons (design 4.3), with its skill line from the hit table
-- (ns.HitTableCalc.LineOf, HitTableCalc.lua) when it has one.
local function Worn(slot, link)
	local kept = S.parsed[slot]
	if kept and kept.link == link and not kept.waiting then
		return kept
	end
	local data = Ask(Api("C_TooltipInfo", "GetInventoryItem"), "player", slot)
	local info = LinesOf(Field(data, "lines"))
	local id, loc, class, subclass = Instant(link)
	info.link, info.id, info.class, info.subclass = link, id, class, subclass
	if id and Ask(Api("C_Item", "IsItemDataCachedByID"), id) == false then
		info.waiting = id
		Ask(Api("C_Item", "RequestLoadItemDataByID"), id)
	end
	if class == K.WEAPON then
		local calc = ns.HitTableCalc
		local line = type(calc) == "table" and id and Ask(calc.LineOf, id) or nil
		info.weapon = { link = link, id = id, min = info.min, max = info.max, plusMin = info.plusMin, plusMax = info.plusMax, speed = info.speed,
			class = class, subclass = subclass, loc = loc, line = Finite(line) and line or nil, twoHand = loc == K.TWO_HAND,
			dagger = subclass == K.DAGGER }
	end
	S.parsed[slot] = info
	return info
end

-- The permanent enchant of an item link, its second field (item:id:enchant:...), or nil.
local function EnchantOf(link)
	if not Plain(link, "string") then
		return nil
	end
	local id = tonumber(link:match("item:%-?%d+:(%d+)") or "")
	return Whole(id) and id > 0 and id or nil
end

-- S.state ----------------------------------------------------------------------------------------------------------------------------------------

-- The auras the class's rules name, Righteous Fury alone on Forever: a plain aura found sets its flag, none found clears it only out of combat,
-- where no aura is withheld (PlateThreat.lua:219-243), and a fight before the first answer leaves it unknown. True when one changed.
local function ReadAuras(st)
	local L = Lookups()
	local get = Api("C_UnitAuras", "GetPlayerAuraBySpellID")
	local fighting = Ask(InCombatLockdown) ~= false
	local was, auras = st.auras or {}, {}
	for id in pairs(L and L.auras or {}) do
		local now = was[id]
		if get then
			local ok, aura = pcall(get, id)
			if ok and not IsSecret(aura) then
				if type(aura) == "table" then
					now = true
				elseif aura == nil and not fighting then
					now = false
				end
			end
		end
		auras[id] = now
	end
	local fury = false
	if L and L.auras[K.FURY] then
		fury = auras[K.FURY]
	end
	local changed = not Same(was, auras) or fury ~= st.fury
	st.auras, st.fury = auras, fury
	return changed
end

-- The level, the class, the form and the auras. GetShapeshiftFormID has no documentation (apis.yaml), so its answer must be a plain number; none
-- is form 0. True when one changed.
local function ReadBasics()
	local st, changed = S.state, false
	local level = Ask(UnitLevel, "player")
	if Finite(level) and level > 0 and level ~= st.level then
		st.level, changed = level, true
	end
	local class = Ask(UnitClassBase, "player")
	if Plain(class, "string") and class ~= st.class then
		st.class, changed = class, true
	end
	if type(GetShapeshiftFormID) == "function" then
		local ok, form = pcall(GetShapeshiftFormID)
		if ok and not IsSecret(form) then
			if form == nil then
				form = 0
			end
			if Finite(form) and form ~= st.form then
				st.form, changed = form, true
			end
		end
	end
	if ReadAuras(st) then
		changed = true
	end
	return changed
end

-- The role: the first answer of ns.PlayerRole (Core.lua), which only reads and drops a withheld answer. True when it changed.
local function ReadRole()
	if type(ns.PlayerRole) ~= "function" then
		return false
	end
	local ok, role = pcall(ns.PlayerRole)
	if ok and Plain(role, "string") and role ~= S.state.role then
		S.state.role = role
		return true
	end
	return false
end

-- The set of talents in use, as MostPoints finds it (Core.lua:498-552), or nil.
local function ConfigID()
	local config = Ask(Api("C_ClassTalents", "GetActiveConfigID"))
	if not Finite(config) then
		local group = Ask(Api("C_SpecializationInfo", "GetActiveSpecGroup"))
		config = Finite(group) and Ask(Api("C_SpecializationInfo", "GetCombatConfigIDForSpecGroup"), group) or nil
	end
	return Finite(config) and config or nil
end

-- The active rank of a talent on its node: the node must hold an entry of the talent's definition, else nil (the tree changed since the data),
-- and the rank counts while that entry is the node's active one.
local function NodeRank(config, node, def)
	if not (Finite(node) and Finite(def)) then
		return nil
	end
	local info = Ask(Api("C_Traits", "GetNodeInfo"), config, node)
	if Field(info, "ID") ~= node then
		return nil
	end
	local entries, getEntry, mine = Field(info, "entryIDs"), Api("C_Traits", "GetEntryInfo"), nil
	for index = 1, K.MAX_ENTRIES do
		local entry = Field(entries, index)
		if entry == nil then
			break
		elseif Finite(entry) and Field(Ask(getEntry, config, entry), "definitionID") == def then
			mine = entry
			break
		end
	end
	if mine == nil then
		return nil
	end
	local active, rank = Field(Field(info, "activeEntry"), "entryID"), Field(info, "activeRank")
	if Finite(active) and active ~= mine then
		return 0
	end
	return Finite(rank) and rank or 0
end

-- The walk of the tree of a set of talents, once a session, for the talents whose node did not answer with their definition: each node's
-- entries to their definition and its spell. Gives { node, def, rank } by the talent's spell, and how many nodes answered: none means the
-- client has not loaded the tree yet, so the walk is not spent.
local function Walk(config, wanted)
	local found, answered = {}, 0
	local tree = Field(Field(Ask(Api("C_Traits", "GetConfigInfo"), config), "treeIDs"), 1)
	local nodes = Finite(tree) and Ask(Api("C_Traits", "GetTreeNodes"), tree) or nil
	local getNode, getEntry, getDef = Api("C_Traits", "GetNodeInfo"), Api("C_Traits", "GetEntryInfo"), Api("C_Traits", "GetDefinitionInfo")
	for index = 1, K.MAX_NODES do
		local node = Field(nodes, index)
		if node == nil then
			break
		end
		local info = Finite(node) and Ask(getNode, config, node) or nil
		if Field(info, "ID") == node then
			answered = answered + 1
		end
		local entries = Field(info, "entryIDs")
		local active, rank = Field(Field(info, "activeEntry"), "entryID"), Field(info, "activeRank")
		for slot = 1, K.MAX_ENTRIES do
			local entry = Field(entries, slot)
			if entry == nil then
				break
			end
			local def = Finite(entry) and Field(Ask(getEntry, config, entry), "definitionID") or nil
			local spell = Finite(def) and Field(Ask(getDef, def), "spellID") or nil
			if Finite(spell) and wanted[spell] and found[spell] == nil then
				local own = not Finite(active) or active == entry
				found[spell] = { node = node, def = def, rank = own and Finite(rank) and rank or 0 }
			end
		end
	end
	return found, answered
end

-- The ranks of the talents of D.RULES and D.CRIT, by talent spell (design 4.3). True when one changed.
local function ReadTalents()
	local L, st = Lookups(), S.state
	if not L then
		return false
	end
	local talents, config = {}, ConfigID()
	if config and Ask(Api("C_Traits", "ConfigHasStagedChanges"), config) == true then
		-- A pick waits unapplied in the talent window: the ranks found before stay, as MostPoints keeps them (Core.lua:507-514).
		local found = S.unstaged[config]
		if not found then
			S.marks.talents = true
			return false
		end
		talents = found
	elseif config then
		local missing, nodes = {}, S.nodes or {}
		for _, talent in ipairs(L.talentList) do
			local moved = nodes[talent.spell]
			local rank = NodeRank(config, moved and moved.node or talent.node, moved and moved.def or talent.def)
			if rank then
				talents[talent.spell] = rank
			else
				missing[talent.spell] = true
			end
		end
		if next(missing) ~= nil and not S.walked then
			local found, answered = Walk(config, missing)
			-- No node answering means the client has not loaded the tree yet: the walk waits for the next talent event.
			if answered > 0 then
				S.walked, S.nodes, st.treeWalked = true, found, true
				for spell, hit in pairs(found) do
					talents[spell] = hit.rank
				end
			end
		end
		S.unstaged[config] = talents
	end
	if Same(st.talents, talents) then
		return false
	end
	st.talents = talents
	return true
end

-- The gear: every slot's link and permanent enchant, the temporary enchants and so Rockbiter Weapon, the weapons, the shield and its block, the
-- ammunition, two hands and dual wielding (design 4.3). A call that raises keeps that slot's last answer. True when something changed.
local function ReadGear()
	local st = S.state
	local links, enchants = {}, {}
	local get = type(GetInventoryItemLink) == "function" and GetInventoryItemLink or nil
	for slot = K.FIRST_SLOT, K.LAST_SLOT do
		local link
		if get then
			local ok, value = pcall(get, "player", slot)
			if not ok or IsSecret(value) then
				link = st.links and st.links[slot]
			elseif type(value) == "string" and value ~= "" then
				link = value
			end
		end
		links[slot], enchants[slot] = link, EnchantOf(link)
	end
	local tempCall = Api("C_PaperDollInfo", "GetTemporaryEnchantmentInfo")
	local temp, tempKnown = {}, tempCall ~= nil
	for _, slot in ipairs(K.TEMP_SLOTS) do
		if tempCall then
			local ok, info = pcall(tempCall, slot)
			if ok and not IsSecret(info) then
				local id = Field(info, "enchantID")
				temp[slot] = Whole(id) and id > 0 and id or nil
			else
				temp[slot] = st.temp and st.temp[slot]
				tempKnown = tempKnown and (slot ~= K.MAIN or st.rockbiter ~= nil)
			end
		end
	end
	local weapons = {}
	for _, slot in ipairs(K.WEAPON_SLOTS) do
		if links[slot] then
			weapons[slot] = Worn(slot, links[slot]).weapon
		end
	end
	-- A client without the call has none; one that raises keeps the last answer.
	local shield, dual = nil, nil
	local shieldCall = Api("C_PaperDollInfo", "OffhandHasShield")
	if shieldCall then
		local ok, value = pcall(shieldCall)
		if ok and not IsSecret(value) and type(value) == "boolean" then
			shield = value
		else
			shield = st.shield
		end
	end
	if type(IsDualWielding) == "function" then
		local ok, value = pcall(IsDualWielding)
		if ok and not IsSecret(value) and type(value) == "boolean" then
			dual = value
		else
			dual = st.dual
		end
	end
	local data = ns.SpellData
	local rockbiter = nil
	if tempKnown then
		rockbiter = temp[K.MAIN] ~= nil and type(data) == "table" and type(data.ROCKBITER) == "table" and data.ROCKBITER[temp[K.MAIN]] == true
	end
	local now = { links = links, enchants = enchants, temp = temp, weapons = weapons, shield = shield,
		shieldBlock = shield and links[K.OFF] and Worn(K.OFF, links[K.OFF]).block or nil,
		ammo = links[K.AMMO] and Worn(K.AMMO, links[K.AMMO]).ammo or nil,
		ammoKind = links[K.AMMO] and Worn(K.AMMO, links[K.AMMO]).subclass or nil,
		twoHand = weapons[K.MAIN] ~= nil and weapons[K.MAIN].twoHand == true, dual = dual, rockbiter = rockbiter }
	for slot in pairs(S.parsed) do
		if not links[slot] then
			S.parsed[slot] = nil
		end
	end
	local changed = false
	for _, field in ipairs(K.GEAR) do
		if not Same(st[field], now[field]) then
			st[field], changed = now[field], true
		end
	end
	return changed
end

-- S.stats ----------------------------------------------------------------------------------------------------------------------------------------

-- The gain a point of a conversion call of the sheet at a stat's total (design 2.5), read only inside the stats read, while the game gives stats
-- plain; nil for a call that is missing, raises or is withheld, which the comparison lists as not counted.
local function Rate(fn, stat, value)
	if type(fn) ~= "function" or not Finite(value) then
		return nil
	end
	local okLow, low = pcall(fn, stat, value)
	local okHigh, high = pcall(fn, stat, value + K.STEP)
	if okLow and okHigh and Finite(low) and Finite(high) then
		return (high - low) / K.STEP
	end
	return nil
end

-- A fraction of the crit calls in percent, the unit of the sheet's crit (Camelot/PaperDollFrameStats.lua:277, 318).
local function Percent100(value)
	return Finite(value) and value * 100 or nil
end

-- The stats, as the sheet reads them (research_tooltips.md §3.1; research_gear_model.md §3.1), or nil when the game withholds them: one withheld
-- value keeps the whole old S.stats, never a mix of two reads, while a value the game gives none of (an off hand, a ranged weapon or a shield the
-- player does not have, GetSpellBonusDamage's nil) is none (design 4.3).
local function ReadStats()
	local secret = Api("C_Secrets", "ShouldUnitStatsBeSecret")
	if secret then
		local ok, yes = pcall(secret)
		if not ok or IsSecret(yes) or yes == true then
			return nil
		end
	end
	local t = { time = Ask(GetTime), old = false, sp = {}, crit = {}, haste = {}, rating = {}, stat = {}, speed = {}, per = {} }
	local ok, a, b, c, d, e, f, g
	for _, school in ipairs(K.SCHOOLS) do
		ok, a = Read(GetSpellBonusDamage, school)
		if not ok then
			return nil
		end
		t.sp[school] = Finite(a) and a or 0
	end
	ok, a = Read(GetSpellBonusHealing)
	if not ok then
		return nil
	end
	t.heal = Finite(a) and a or nil
	ok, a, b, c = Read(UnitAttackPower, "player")
	if not ok then
		return nil
	end
	t.ap = Sum(a, b, c)
	ok, a, b, c = Read(UnitRangedAttackPower, "player")
	if not ok then
		return nil
	end
	t.rap = Sum(a, b, c)
	ok, a = Read(GetShieldBlock)
	if not ok then
		return nil
	end
	t.block = Finite(a) and S.state.shield ~= false and a or nil
	ok, a = Read(GetCritChance)
	if not ok then
		return nil
	end
	t.crit.melee = Finite(a) and a or nil
	ok, a = Read(GetRangedCritChance)
	if not ok then
		return nil
	end
	t.crit.ranged = Finite(a) and a or nil
	ok, a = Read(GetSpellCritChance)
	if not ok then
		return nil
	end
	t.crit.spell = Finite(a) and a or nil
	ok, a = Read(GetMeleeHaste)
	if not ok then
		return nil
	end
	t.haste.melee = Finite(a) and a or nil
	-- The sheet adds the ranged haste and the quiver's (Camelot/PaperDollFrameStats.lua:192-194).
	ok, a, b = Read(GetRangedHaste)
	if not ok then
		return nil
	end
	t.haste.ranged, t.haste.quiver = Finite(a) and a or nil, Finite(b) and b or nil
	ok, a = Read(UnitSpellHaste, "player")
	if not ok then
		return nil
	end
	t.haste.spell = Finite(a) and a or nil
	for _, rating in ipairs(K.HASTE) do
		ok, a = Read(GetCombatRating, rating)
		if not ok then
			return nil
		end
		t.rating[rating] = Finite(a) and a or nil
	end
	for index = 1, K.STATS do
		ok, a, b = Read(UnitStat, "player", index)
		if not ok then
			return nil
		end
		t.stat[index] = Finite(b) and b or nil
	end
	-- The hasted speeds; the off hand and the ranged weapon are nil without one (UnitDocumentation.lua:682-698).
	ok, a, b, c = Read(UnitAttackSpeed, "player")
	if not ok then
		return nil
	end
	t.speed.main, t.speed.off, t.speed.ranged = Positive(a), Positive(b), Positive(c)
	ok, a, b, c, d, e, f, g = Read(UnitDamage, "player")
	if not ok then
		return nil
	end
	if Finite(a) and Finite(b) then
		local off = t.speed.off ~= nil
		t.dmg = { min = a, max = b, offMin = off and Finite(c) and c or nil, offMax = off and Finite(d) and d or nil,
			flat = (Finite(e) and e or 0) + (Finite(f) and f or 0), pct = Finite(g) and g or nil }
	end
	ok, a, b, c, d, e, f = Read(UnitRangedDamage, "player")
	if not ok then
		return nil
	end
	if Positive(a) and Finite(b) and Finite(c) then
		t.rdmg = { speed = a, min = b, max = c, flat = (Finite(d) and d or 0) + (Finite(e) and e or 0), pct = Finite(f) and f or nil }
	end
	for _, index in ipairs(K.RATE_STATS) do
		local value = t.stat[index]
		t.per[index] = { ap = Rate(GetAttackPowerForStat, index, value), rap = Rate(GetRangedAttackPowerForStat, index, value),
			crit = Percent100(Rate(GetCritChanceFromStat, index, value)), spellCrit = Percent100(Rate(GetSpellCritChanceFromStat, index, value)) }
	end
	return t
end

-- The text check -----------------------------------------------------------------------------------------------------------------------------------

-- The share a rank of a spell power part keeps for a low rank (design 6.2): in full for grace levels after the rank's learn level, then step less
-- a level, never below none.
local function LowFactor(row, level)
	local learned, grace, step = row[2], ModelOf("downrank", "grace"), ModelOf("downrank", "step")
	if not (Finite(learned) and Finite(level) and Finite(grace) and Finite(step)) then
		return 1
	end
	local factor = 1 - step * (level - learned - grace)
	if factor > 1 then
		return 1
	elseif factor < 0 then
		return 0
	end
	return factor
end

-- The levels a part's base gains from the level of the row that carries it to the player's, up to its cap (0: none) (design 2.5, B).
local function Levels(row, at, level)
	local from = PartValue(row.lv, at) or row[2]
	if not (Finite(from) and Finite(level)) then
		return 0
	end
	local to = math.max(level, from)
	local cap = PartValue(row.mx, at)
	if cap and cap > 0 and to > cap then
		to = cap
	end
	return math.max(0, to - from)
end

-- The spell damage a part counts: its school's, or the lower of its schools (sch).
local function SchoolPower(entry, part, stats)
	local schools = type(part.sch) == "table" and part.sch or (type(entry.sch) == "table" and entry.sch) or nil
	local sp = type(stats.sp) == "table" and stats.sp or {}
	if schools then
		local low
		for _, school in ipairs(schools) do
			local value = Finite(sp[school]) and sp[school] or 0
			if low == nil or value < low then
				low = value
			end
		end
		return low or 0
	end
	local value = sp[entry.school]
	return Finite(value) and value or 0
end

-- The probe's part: its first spell power or healing part (design 3.1, Probes).
local function ProbePart(entry)
	for index, part in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(part) == "table" and (part[1] == "sp" or part[1] == "heal") then
			return part, index
		end
	end
	return nil
end

local function Within(mean, list)
	for _, value in ipairs(list) do
		if math.abs(mean - value) <= K.NEAR then
			return true
		end
	end
	return false
end

local function Apart(mean, list)
	for _, value in ipairs(list) do
		if math.abs(mean - value) < K.FAR then
			return false
		end
	end
	return true
end

-- The text of one probe of the class against its base without and with the player's spell power (design 4.3, 6.1): once a session, out of combat
-- with the stats plain, on an English client, with a probe rank known whose spell power part is at least K.ENOUGH. The first "N to M" of
-- C_Spell.GetSpellDescription (SpellDocumentation.lua:345-360: empty while the spell is not loaded, then asked again after SPELL_TEXT_UPDATE) gives
-- a mean; within K.NEAR of the base (or the base and its gain by levels) and at least K.FAR from both with spell power it answers "base", and the
-- other way round "with"; else none, and the next session tries again.
local function TextCheck()
	local check, stats = S.check, S.stats
	if check.done or not stats or stats.old or Ask(InCombatLockdown) ~= false then
		return
	end
	local locale = Ask(GetLocale)
	if not (Plain(locale, "string") and K.ENGLISH[locale]) then
		check.done = true
		return
	end
	local L, data = Lookups(), ns.SpellData
	local probes = L and type(data) == "table" and type(data.PROBES) == "table" and data.PROBES[L.class] or nil
	if type(probes) ~= "table" then
		check.done = true
		return
	end
	local level = S.state.level
	for _, id in ipairs(probes) do
		local hit = Whole(id) and L.byId[id] or nil
		local entry, row = hit and hit[1], hit and hit[1].ranks[hit[2]]
		local part, at
		if type(row) == "table" then
			part, at = ProbePart(entry)
		end
		if part and Knows(id) and LowFactor(row, level) >= 1 then
			local coef, power = PartValue(row.c, at) or part[2], nil
			if part[1] == "heal" then
				power = stats.heal
			else
				power = SchoolPower(entry, part, stats)
			end
			local base = PartValue(row.bm, at)
			if Finite(coef) and Finite(power) and base and coef * power >= K.ENOUGH then
				local text = Ask(Api("C_Spell", "GetSpellDescription"), id)
				if Plain(text, "string") then
					if text == "" then
						check.waiting = id
						return
					end
					check.waiting, check.done = nil, true
					local P = Patterns()
					local low, high = text:match(P.range)
					low, high = Number(low), Number(high)
					if low and high then
						local mean, gain = (low + high) / 2, (PartValue(row.bl, at) or 0) * Levels(row, at, level)
						local without, with = { base, base + gain }, { base + coef * power, base + gain + coef * power }
						local answer = (Within(mean, without) and Apart(mean, with) and "base") or (Within(mean, with) and Apart(mean, without) and "with")
							or nil
						if answer then
							check.result, check.name, check.rank = answer, Ask(Api("C_Spell", "GetSpellName"), id), Ask(Api("C_Spell", "GetSpellSubtext"), id)
							Bump()
						end
					end
					return
				end
			end
		end
	end
end

-- The reads -------------------------------------------------------------------------------------------------------------------------------------

-- Reads the marked parts of S.state, each unmarked first, so a part that fails waits for its next event.
local function ReadMarked()
	local marks, changed = S.marks, false
	if marks.state then
		marks.state = false
		changed = ReadBasics() or changed
	end
	if marks.talents then
		marks.talents = false
		changed = ReadTalents() or changed
	end
	if marks.gear then
		marks.gear = false
		changed = ReadGear() or changed
	end
	if marks.role then
		marks.role = false
		changed = ReadRole() or changed
	end
	if changed then
		Bump()
	end
end

-- Reads S.stats while the game gives them plain; withheld, they stay marked for the next ask, and in a fight (InCombatLockdown) the kept ones
-- are old, whatever order the start of the fight and a plain read in it came in. Right after a plain read the functions of M.AfterRead run, in the
-- same frame (GearModel.lua reads the hit table's inputs there), each under pcall so another file's error stops nothing here, and the text check
-- runs while it waits.
local function ReadStatsNow()
	local stats = ReadStats()
	if not stats then
		S.marks.stats = true
		local kept = S.stats
		if kept and not kept.old and Ask(InCombatLockdown) == true then
			kept.old = true
			Bump()
		end
		return
	end
	local old = S.stats
	if old and Same(old, stats, K.SKIP) then
		old.time = stats.time
		if old.old then
			old.old = false
			Bump()
		end
	else
		S.stats = stats
		Bump()
	end
	for _, fn in ipairs(S.after) do
		local ok, err = pcall(fn, S.stats)
		if not ok and not S.failed[fn] then
			S.failed[fn] = true
			local handler = Ask(geterrorhandler)
			if type(handler) == "function" then
				pcall(handler, err)
			end
		end
	end
	TextCheck()
end

-- The marked parts of S.state, then the stats while marked: before the stats, so the functions of M.AfterRead see the state of the same moment.
local function ReadAll()
	local marks = S.marks
	if marks.state or marks.talents or marks.gear or marks.role then
		ReadMarked()
	end
	if marks.stats then
		marks.stats = false
		ReadStatsNow()
	end
end

-- Runs fn while a read runs, so a function that asks again in it gets what is there; an error comes back after the flag is down.
local function Inside(fn)
	if S.reading then
		return
	end
	S.reading = true
	local ok, err = pcall(fn)
	S.reading = false
	if not ok then
		error(err, 0)
	end
end

-- Reads what is marked before an answer: S.state's parts, and with stats S.stats.
local function Refresh(stats)
	if S.reading or Stopped() then
		return
	end
	Freshen()
	local marks = S.marks
	S.reading = true
	if marks.state or marks.talents or marks.gear or marks.role then
		Run(ReadMarked)
	end
	if stats and marks.stats then
		marks.stats = false
		Run(ReadStatsNow)
	end
	S.reading = false
end

-- The events -------------------------------------------------------------------------------------------------------------------------------------

-- An event only marks (design 4.5), but for the form, read at once since a stance taken in a fight changes the multipliers; the restriction
-- event, which comes before a restriction becomes active while IsAddOnRestrictionActive is false (research_tooltips.md §2.2), the last moment
-- stats are plain; the start of a fight, which makes the stats old; a spell text the check waits for; and an item the game loaded.
local function OnEvent(_, event, ...)
	if S.units[event] and not S.alone[event] then
		local unit = ...
		if not IsSecret(unit) and unit ~= "player" then
			return
		end
	end
	local marks = K.ON[event]
	if marks == "all" then
		MarkAll()
	elseif type(marks) == "table" then
		for _, what in ipairs(marks) do
			S.marks[what] = true
		end
	end
	if event == "PLAYER_REGEN_DISABLED" then
		local stats = S.stats
		if stats and not stats.old then
			stats.old = true
			Bump()
		end
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		Inside(ReadMarked)
	elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
		if S.marks.stats then
			Inside(ReadAll)
		end
	elseif event == "SPELL_TEXT_UPDATE" then
		local id = ...
		if Finite(id) and S.check.waiting == id then
			Inside(TextCheck)
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		local id = ...
		for _, info in pairs(S.parsed) do
			if Finite(id) and info.waiting == id then
				S.marks.gear = true
			end
		end
	end
end

-- Registers a unit event for the player alone where the client can, else for every unit, as HitTable.lua hears its own (HitTable.lua:1062-1078).
local function HearUnit(frame, event)
	S.units[event] = true
	local ok, done = false, nil
	if type(frame.RegisterUnitEvent) == "function" then
		ok, done = pcall(frame.RegisterUnitEvent, frame, event, "player")
	end
	S.alone[event] = ok and (IsSecret(done) or done ~= false)
	if not S.alone[event] then
		pcall(frame.RegisterEvent, frame, event)
	end
end

-- The frame of this file hears the events only while a reader wants them (M.Want) and the part runs, as the hit table's does
-- (HitTable.lua:1102-1126); made the first time. Starting to hear marks everything, since nothing was heard before.
Hear = function(on)
	on = on and not Stopped()
	if on == S.hearing then
		return
	end
	local frame = S.frame
	if on and not frame then
		local ok, made = pcall(CreateFrame, "Frame")
		if not ok or type(made) ~= "table" then
			return
		end
		frame = made
		if type(ns.Own) == "table" then
			ns.Own[frame] = true
		end
		frame:SetScript("OnEvent", function(_, event, ...)
			Run(OnEvent, event, ...)
		end)
		S.frame = frame
	end
	if not frame then
		return
	end
	pcall(frame.UnregisterAllEvents, frame)
	S.hearing = false
	if not on then
		return
	end
	for _, event in ipairs(K.PLAYER_EVENTS) do
		HearUnit(frame, event)
	end
	for _, event in ipairs(K.EVENTS) do
		pcall(frame.RegisterEvent, frame, event)
	end
	S.hearing = true
	MarkAll()
end

-- The rounding of design 1.2 ----------------------------------------------------------------------------------------------------------------------

-- A number written with decimals, its trailing zeros and point dropped.
local function Trim(text)
	text = text:gsub("(%.%d-)0+$", "%1")
	return (text:gsub("%.$", ""))
end

-- A whole number with its thousands broken as the game breaks them (BreakUpLargeNumbers, under pcall, as CombatText.lua:1445-1446 calls it).
local function Big(whole)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, broken = pcall(BreakUpLargeNumbers, whole)
		if ok and Plain(broken, "string") and broken ~= "" then
			return broken
		end
	end
	return ("%d"):format(whole)
end

-- A share: x * 100 to one decimal, a trailing .0 dropped: 81.4%, 120%, 5%.
local function Pct(x)
	if not Finite(x) then
		return ""
	end
	return Trim(("%.1f"):format(x * 100)) .. "%"
end

-- A multiplier: x and two decimals at most, trailing zeros dropped: x1.8, x2.16.
local function Mult(x)
	if not Finite(x) then
		return ""
	end
	return "x" .. Trim(("%.2f"):format(x))
end

-- A factor of two decimals at most with no x: 0.35 x healing.
local function Dec(x)
	if not Finite(x) then
		return ""
	end
	return Trim(("%.2f"):format(x))
end

-- An amount: whole from 100 up with its thousands broken, one decimal below with a trailing .0 dropped, its minus kept (the style's numbers, as
-- Figure writes them).
local function Num(x)
	if not Finite(x) then
		return ""
	end
	local size = math.abs(x)
	local text
	if size >= 100 then
		text = Big(math.floor(size + 0.5))
	else
		text = Trim(("%.1f"):format(size))
	end
	if x < 0 and text ~= "0" then
		text = "-" .. text
	end
	return text
end

-- An amount with its sign: +417, +4.5, -52.
local function Signed(x)
	local text = Num(x)
	if text ~= "" and x > 0 and text ~= "0" then
		text = "+" .. text
	end
	return text
end

-- A change as a share, one decimal with its sign, 0% under 0.05% (design 2.3): Percent(0.018) is +1.8%.
local function Percent(x)
	if not Finite(x) then
		return ""
	end
	local value = x * 100
	if math.abs(value) < 0.05 then
		return "0%"
	end
	return (value > 0 and "+" or "-") .. ("%.1f"):format(math.abs(value)) .. "%"
end

-- A figure of the gear comparison, now or with an item (design 2.3), for GearLines.lua and GearWindow.lua alike: a second with one decimal; any
-- other figure whole from 100 up with its thousands broken, one decimal below with a trailing .0 dropped; its minus kept.
local function Figure(x, second)
	if not Finite(x) then
		return ""
	end
	local size, text = math.abs(x), nil
	if second then
		local tenths = math.floor(size * 10 + 0.5)
		text = Big(math.floor(tenths / 10)) .. "." .. (tenths % 10)
	elseif size >= 100 then
		text = Big(math.floor(size + 0.5))
	else
		text = Trim(("%.1f"):format(size))
	end
	if x < 0 and text ~= "0" and text ~= "0.0" then
		text = "-" .. text
	end
	return text
end

-- A change of the gear comparison (design 2.3): a figure with its sign, "0" under 0.05: +16.7, -52, +1.3 (a second).
local function Change(x, second)
	if not Finite(x) then
		return ""
	elseif math.abs(x) < 0.05 then
		return "0"
	end
	return (x > 0 and "+" or "-") .. Figure(math.abs(x), second)
end

-- A share with two decimals, x * 100 with no trailing zeros dropped, so a table's column lines up: 5.20%; with signed, its sign too (a change):
-- +0.52%, -1.04%, and 0.00% under 0.005%.
local function Pct2(x, signed)
	if not Finite(x) then
		return ""
	end
	local value = x * 100
	if math.abs(value) < 0.005 then
		return "0.00%"
	end
	local text = ("%.2f"):format(math.abs(value)) .. "%"
	if value < 0 then
		return "-" .. text
	end
	return (signed and "+" or "") .. text
end

-- The style (one for every line Flat UI adds to a tooltip and for the window): the colours as { r, g, b }, the game's own read once here.
local function StyleColour(spec)
	local colour = _G[spec[1]]
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	if Finite(r) and Finite(g) and Finite(b) then
		return { r, g, b }
	end
	return { spec[2], spec[3], spec[4] }
end

local Style = { header = StyleColour(K.STYLE.header), label = K.LABEL, value = K.VALUE, good = StyleColour(K.STYLE.good),
	bad = StyleColour(K.STYLE.bad), dim = K.DIM }

-- The escape that starts text in a colour of the style: |cffrrggbb.
local function Hex(colour)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, Finite(value) and value or 1)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(colour[1]), Byte(colour[2]), Byte(colour[3]))
end

-- Text in a colour of the style, inside a line of another colour.
local function Paint(text, colour)
	return Hex(colour) .. text .. "|r"
end

-- The colour of a change: good when it is better, bad when worse, the value's colour when it is none (under still, 0 by default); higherBetter
-- false for a change that is better when it falls (damage taken).
local function Tone(change, higherBetter, still)
	if not Finite(change) or math.abs(change) <= (Finite(still) and still or 0) then
		return Style.value
	end
	if (change > 0) == (higherBetter ~= false) then
		return Style.good
	end
	return Style.bad
end

-- Milliseconds as seconds: 6 sec.
local function Sec(ms)
	return Trim(("%.1f"):format(ms / 1000)) .. " sec"
end

-- A threat total rounded toward none, as the game rounds threat after the stance (design 1.2).
local function Toward(x)
	if x >= 0 then
		return math.floor(x)
	end
	return -math.floor(-x)
end

-- The lines -------------------------------------------------------------------------------------------------------------------------------------

-- A line of design 4.3, { left, right, tone, dim, wrap }, by place and by name.
local function Line(left, right, tone, dim, wrap)
	tone, dim, wrap = tone or "plain", dim == true, wrap == true
	return { left, right, tone, dim, wrap, left = left, right = right, tone = tone, dim = dim, wrap = wrap }
end

-- A dim line, which wraps at the tooltip's width instead of widening it (design 1.2).
local function Dim(text)
	return Line(text, nil, "plain", true, true)
end

-- A threat multiplier in force, { name, m, b, background }, by place and by name; also: what it would be in another case.
local function Factor(name, m, b, background, also)
	return { name, m, b, background, name = name, m = m, b = b, background = background, also = also }
end

-- The row of a rank and its place, given its place (M.Find's answer) or the row itself.
local function RankRow(entry, rank)
	if type(rank) == "table" then
		for index, row in ipairs(entry.ranks) do
			if row == rank then
				return row, index
			end
		end
		return rank, 1
	end
	local row = Whole(rank) and entry.ranks[rank] or nil
	if type(row) == "table" then
		return row, rank
	end
	return nil
end

-- A key with its words capitalised but the small ones: seal of righteousness is Seal of Righteousness.
local function TitleCase(key)
	if type(key) ~= "string" then
		return ""
	end
	local words = {}
	for word in key:gmatch("%S+") do
		if #words > 0 and K.SMALL[word] then
			words[#words + 1] = word
		else
			words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2)
		end
	end
	return table.concat(words, " ")
end

-- The spell's name as the game gives it (C_Spell.GetSpellName, SpellDocumentation.lua:518-533), else its key.
local function SpellName(entry, row)
	local name = Ask(Api("C_Spell", "GetSpellName"), row[1])
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return TitleCase(entry.key)
end

-- The name of a rule of a stance or form for the form the player is in: its own, or for a rule of two forms the name of the spell of its tooltip
-- in the same place (Bear Form, Dire Bear Form). In a list of multipliers a stance is its first word (design 1.2: Defensive x1.8).
local function FormRuleName(rule, form, full)
	local name = type(rule.name) == "string" and rule.name or (type(rule.id) == "string" and rule.id) or "?"
	if type(rule.form) == "table" and type(rule.tip) == "table" then
		for index, value in ipairs(rule.form) do
			local spell = value == form and Ask(Api("C_Spell", "GetSpellName"), rule.tip[index]) or nil
			if Plain(spell, "string") and spell ~= "" then
				name = spell
			end
		end
	end
	if not full then
		name = name:gsub(" Stance$", "")
	end
	return name
end

-- The name of a form, from the class's rule of that stance or form, or nil.
local function FormName(form, full)
	local L = Lookups()
	for _, rule in ipairs(L and L.rules or {}) do
		if rule.form ~= nil and rule.talent == nil and InSet(rule.form, form) and type(rule.name) == "string" then
			return FormRuleName(rule, form, full)
		end
	end
	return nil
end

-- The names of the forms of a list: Bear Form or Dire Bear Form.
local function FormNames(forms)
	local words, seen = {}, {}
	for _, form in ipairs(type(forms) == "table" and forms or { forms }) do
		local name = FormName(form, true)
		if name and not seen[name] then
			seen[name] = true
			words[#words + 1] = name
		end
	end
	return #words > 0 and table.concat(words, " or ") or nil
end

-- The share's words of a spell damage part: Frost spell damage, or the lower of Fire and Frost spell damage.
local function SchoolWords(entry, part)
	local names = SchoolNames()
	local schools = type(part.sch) == "table" and part.sch or (type(entry.sch) == "table" and entry.sch) or nil
	if schools then
		local words = {}
		for _, school in ipairs(schools) do
			words[#words + 1] = names[school] or "?"
		end
		return "the lower of " .. table.concat(words, " and ") .. " spell damage"
	end
	local name = names[entry.school]
	return name and (name .. " spell damage") or "spell damage"
end

-- The speed a weapon part's attack power counts at (design 2.5): the form's swing in a form, the normalized speed for "norm" by the weapon
-- worn, the weapon's own speed for "actual"; nil when the weapon was not read.
local function WeaponSpeed(part, state)
	local spd, form = part.spd, state.form
	if spd == "cat" or form == K.CAT then
		return ModelOf("form", "cat")
	elseif spd == "bear" or (form ~= nil and K.BEARS[form]) then
		return ModelOf("form", "bear")
	elseif spd == "nranged" then
		return ModelOf("norm", "ranged")
	end
	local slot = (part.h == "off" and K.OFF) or (part.h == "ranged" and K.RANGED) or K.MAIN
	local weapon = type(state.weapons) == "table" and state.weapons[slot] or nil
	if spd == "norm" then
		if slot == K.RANGED then
			return ModelOf("norm", "ranged")
		elseif not weapon then
			return nil
		elseif weapon.dagger then
			return ModelOf("norm", "dagger")
		elseif weapon.twoHand then
			return ModelOf("norm", "two")
		end
		return ModelOf("norm", "one")
	end
	return weapon and Finite(weapon.speed) and weapon.speed or nil
end

-- The factor of an off-hand hit, as the gear comparison counts it (GearModel.lua's G.OffFactor: D.MODEL.offHand, or while dual wielding the one
-- UnitDamage gives), so an off-hand part's line and the comparison agree.
local function OffHand(state, stats)
	local G = ns.GearModel
	local factor = type(G) == "table" and Ask(G.OffFactor, state, stats) or nil
	if Finite(factor) and factor > 0 then
		return factor
	end
	return ModelOf("offHand")
end

-- The words of the ticks, the targets and the hits a part's share is for (design 1.2), after its share.
local function PerWords(part, ticks)
	local per, words = part.per, ""
	if per == "missile" and ticks then
		words = ", " .. ticks .. " missiles"
	elseif ticks then
		words = ", " .. ticks .. " ticks"
	end
	if per == "target" then
		words = words .. ", each target"
	elseif per == "first" then
		words = words .. ", the first " .. (Finite(part.max) and part.max or "few") .. " enemies"
	elseif per == "jump" and Finite(part.j) then
		words = words .. ", " .. Pct(1 - part.j) .. " less each jump"
	elseif per == "hit" or per == "block" or per == "stack" or per == "proc" then
		words = words .. " a " .. per
	elseif per == "self" then
		words = words .. " to you"
	end
	return words
end

-- The dim line of a part the game's text counts otherwise (design 1.3): its first half for a two-hander, whose share the text counts as the
-- measured one, and the note with a one-hander.
local function Otherwise(part, state)
	if state.twoHand == true and Finite(part.two) then
		return K.OTHERWISE .. "."
	end
	local note = type(part.note) == "string" and part.note ~= "" and part.note or nil
	if not note then
		return K.OTHERWISE .. "."
	end
	local rest, cut = note:gsub("^[Tt]he game's text ", "")
	return K.OTHERWISE .. (cut > 0 and " and " or "; ") .. rest .. "."
end

-- The left text of a power part (its share in words), and what its right text needs: the share its amount counts (at 5 combo points for a
-- finisher), the stat that is a share of (nil without stats), the factor of a low rank, whether the amount is an estimate, and its ticks. A part
-- that gets nothing gives its left text alone, with the ticks and targets it is for. A weapon part counts its dagger multiple (dg) with a dagger in
-- the main hand, and an off-hand one the off-hand factor the comparison counts (OffHand).
local function PartTexts(entry, row, at, part, state, stats, lowRank)
	local stat, coef = part[1], PartValue(row.c, at) or part[2]
	local per, ticks = part.per, PartValue(row.n, at) or part.n
	if not Finite(ticks) or ticks < 2 then
		ticks = nil
	end
	local spell = stat == "sp" or stat == "heal"
	if not Finite(coef) then
		return nil
	elseif coef == 0 or (stat == "wpn" and entry.cmp == "wand") then
		-- A spell that gets nothing (design 1.2: Shoot with a wand, Mana Burn, Fireball's burn, Consecration's flat tick on each target).
		local left = (spell or entry.cmp == "wand") and "No spell power" or "No attack power"
		return left .. PerWords(part, ticks)
	end
	local share, power, head = coef, nil, nil
	if part.o and state.twoHand == true and Finite(part.two) then
		share = part.two
	end
	if stat == "sp" then
		head, power = Pct(share) .. " of " .. SchoolWords(entry, part), stats and SchoolPower(entry, part, stats)
	elseif stat == "heal" then
		head, power = Pct(share) .. " of spell healing", stats and stats.heal
	elseif stat == "ap" or stat == "rap" then
		local what = stat == "ap" and "attack power" or "ranged attack power"
		power = stats and stats[stat]
		local list = per == "cp" and type(part.cp) == "table" and part.cp or nil
		if list and Finite(list[1]) and Finite(list[#list]) then
			head, share = Pct(list[1]) .. " to " .. Pct(list[#list]) .. " of " .. what .. " by combo points", list[#list]
		else
			head = Pct(share) .. " of " .. what .. (per == "cp" and " a combo point" or "")
			share = per == "cp" and share * 5 or share
		end
	elseif stat == "bv" then
		head, power = Dec(share) .. " x block value", stats and stats.block
	elseif stat == "wpn" then
		local multiple, speed = PartValue(row.w, at) or coef, WeaponSpeed(part, state)
		local main = type(state.weapons) == "table" and state.weapons[K.MAIN] or nil
		if Finite(part.dg) and type(main) == "table" and main.dagger == true then
			multiple = part.dg
		end
		if part.h == "off" then
			multiple = multiple * OffHand(state, stats)
		end
		local ranged = part.h == "ranged"
		head, share = Pct(multiple) .. " weapon damage", nil
		if Finite(speed) then
			share = multiple * speed / ModelOf("apPerDps")
			head = head .. ", " .. Pct(share) .. " of " .. (ranged and "ranged attack power" or "attack power")
			power = stats and (ranged and stats.rap or stats.ap)
		end
	else
		return nil
	end
	-- The ticks, the targets and the hits the share is for (design 1.2).
	head = head .. PerWords(part, ticks)
	if part.g and type(part.fs) == "table" and Finite(part.fs[2]) then
		local form = FormName(part.fs[1], true)
		if form then
			head = head .. ", " .. Pct(part.fs[2]) .. " in " .. form
		end
	end
	local factor = 1
	if spell and lowRank and not part.g then
		factor = LowFactor(row, state.level)
		if factor < 1 then
			head = head .. ", at ~" .. Pct(factor) .. " for a low rank"
		end
	end
	local estimate = part.b == "e"
	if estimate then
		head = "~" .. head
	end
	return head, share, power, factor, estimate or factor < 1, ticks
end

-- The power lines of one part (design 1.2): the share in words on the left; on the right "in the game's number" where the game's text counts it,
-- the amount alone where it counts it otherwise, else what it adds with the player's stats on top of the text, or "of which" when the text check
-- found the texts count spell power; nothing without stats or under 1. A note after the share, or under it when long.
local function PartLines(out, entry, row, at, part, state, stats, lowRank)
	local head, share, power, factor, estimate, ticks = PartTexts(entry, row, at, part, state, stats, lowRank)
	if not head then
		return
	end
	if share == nil and power == nil and factor == nil then
		out[#out + 1] = Line(head, nil, "plain")
		return
	end
	local right, tone = nil, "plain"
	local per, spell = part.per, part[1] == "sp" or part[1] == "heal"
	if part.g then
		right = "in the game's number"
	elseif Finite(share) and Finite(power) then
		local amount = power * share * (spell and factor or 1)
		if amount >= 1 then
			tone = stats.old and "old" or "plain"
			if part.o then
				right = Num(amount) .. (per and per ~= "cp" and (" a " .. per) or "")
			else
				right = (spell and S.check.result == "with") and ("of which " .. Num(amount)) or Signed(amount)
				if per == "cp" then
					right = right .. " at 5 points"
				elseif per == "hit" or per == "block" or per == "stack" or per == "proc" then
					right = right .. " a " .. per
				end
				if ticks then
					right = right .. " (" .. Num(amount / ticks) .. (per == "missile" and " a missile)" or " a tick)")
				end
			end
			if estimate then
				right = "~" .. right
			end
		end
	end
	local note = not part.o and type(part.note) == "string" and part.note ~= "" and part.note or nil
	if note and #head + #note + 2 <= K.NOTE_WIDTH then
		head, note = head .. ", " .. note, nil
	end
	out[#out + 1] = Line(head, right, tone)
	if part.o then
		out[#out + 1] = Dim(Otherwise(part, state))
	elseif note then
		out[#out + 1] = Dim(note)
	end
end

-- The threat multipliers ------------------------------------------------------------------------------------------------------------------------

-- True for an entry of the Holy school, or one of whose schools is Holy.
local function IsHoly(entry)
	return entry.school == K.HOLY or (type(entry.sch) == "table" and InSet(entry.sch, K.HOLY))
end

-- True when the worn items hold the item ID.
local function Wears(state, item)
	for _, link in pairs(type(state.links) == "table" and state.links or {}) do
		if Plain(link, "string") and tonumber(link:match("item:(%d+)") or "") == item then
			return true
		end
	end
	return false
end

-- True when the item of a slot, or of any slot without one, holds the permanent enchant.
local function Enchanted(state, enchant, slot)
	local enchants = type(state.enchants) == "table" and state.enchants or {}
	if Whole(slot) then
		return enchants[slot] == enchant
	end
	for _, value in pairs(enchants) do
		if value == enchant then
			return true
		end
	end
	return false
end

-- The multiplier of a rule for an entry in a state, its basis and what it would be in another case, or nil when it does not apply. Its
-- conditions (form, talent, aura, always, shield, two-hander, enchant, item) must all hold, and its filters (schools, spells) match; a rule with
-- neither applies to nothing. A talent takes its rank's value (design 3.4); Spirit Weapons takes its Rockbiter value while the main hand holds
-- Rockbiter Weapon, and names both when the game does not say (design 6.17); Righteous Fury multiplies a Holy spell again (design 6.10).
local function Applies(rule, entry, state)
	local conditions, filters = false, false
	local m, b = rule.m, rule.b or "c"
	if rule.form ~= nil then
		conditions = true
		if not InSet(rule.form, state.form) then
			return nil
		end
	end
	if rule.talent ~= nil then
		conditions = true
		local rank = type(state.talents) == "table" and state.talents[rule.talent] or nil
		if not (Finite(rank) and rank > 0) then
			return nil
		end
		local values = rule.r
		m = type(values) == "table" and (values[rank] or values[#values]) or m
	end
	if rule.aura ~= nil then
		conditions = true
		local on = type(state.auras) == "table" and state.auras[rule.aura] == true or (rule.aura == K.FURY and state.fury == true)
		if not on then
			return nil
		end
	end
	if rule.always then
		conditions = true
	end
	if rule.shield then
		conditions = true
		if state.shield ~= true then
			return nil
		end
	end
	if rule.twoHand then
		conditions = true
		if state.twoHand ~= true then
			return nil
		end
	end
	if rule.enchant ~= nil then
		conditions = true
		if not Enchanted(state, rule.enchant, rule.slot) then
			return nil
		end
	end
	if rule.item ~= nil then
		conditions = true
		if not Wears(state, rule.item) then
			return nil
		end
	end
	if rule.schools ~= nil then
		filters = true
		if not (Overlap(entry.sch, rule.schools) or InSet(rule.schools, entry.school)) then
			return nil
		end
	end
	if rule.spells ~= nil then
		filters = true
		if not InSet(rule.spells, entry.key) then
			return nil
		end
	end
	if not (conditions or filters) then
		return nil
	end
	local also = nil
	if Finite(rule.rockbiter) then
		if state.rockbiter == true then
			m = rule.rockbiter
		elseif state.rockbiter == nil then
			also = Mult(rule.rockbiter) .. " with Rockbiter Weapon"
		end
	end
	if Finite(rule.holy) and IsHoly(entry) then
		m, b = (Finite(m) and m or 1) * rule.holy, Worse(b, rule.holyB or b)
	end
	if not Finite(m) then
		return nil
	end
	return m, b, also
end

-- The name of a rule in a list of multipliers: a talent with its rank of its ranks (Frost Channeling 3/3), a stance by its first word, a rule of
-- two forms by the form the player is in.
local function RuleName(rule, state)
	local name = type(rule.name) == "string" and rule.name or (type(rule.id) == "string" and rule.id) or "?"
	if rule.talent ~= nil then
		local rank = type(state.talents) == "table" and state.talents[rule.talent] or nil
		local most = type(rule.r) == "table" and #rule.r or 0
		if Finite(rank) and most > 1 then
			name = ("%s %d/%d"):format(name, rank, most)
		end
	elseif rule.form ~= nil then
		name = FormRuleName(rule, state.form, false)
	end
	return name
end

-- The threat multipliers in force for an entry (design 2.5, G): their product, the list, and the worst basis. An entry of the player's pet takes
-- none of its owner's. A background multiplier (the rogue's, which always applies, and a threat-lowering stance or form of a damage dealer:
-- design 1.4) is marked so.
local function Factors(entry, state, role)
	local list, G, basis = {}, 1, "c"
	local L = Lookups()
	if entry.pet or not L then
		return G, list, basis
	end
	for _, rule in ipairs(L.rules) do
		local m, b, also = Applies(rule, entry, state)
		if m then
			local background = rule.always == true or (rule.lowers == true and role == "damage")
			list[#list + 1] = Factor(RuleName(rule, state), m, b, background, also)
			G, basis = G * m, Worse(basis, b)
		end
	end
	return G, list, basis
end

-- The threat lines -------------------------------------------------------------------------------------------------------------------------------

-- True for an entry that heals, and for one that deals damage.
local function Heals(entry)
	if entry.cmp == "heal" or entry.cmp == "hot" then
		return true
	end
	for _, part in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(part) == "table" and part[1] == "heal" then
			return true
		end
	end
	return false
end

local function Damages(entry)
	if K.DAMAGE_KINDS[entry.cmp] then
		return true
	end
	for _, part in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(part) == "table" and part[1] ~= "heal" and Finite(part[2]) and part[2] > 0 then
			return true
		end
	end
	return false
end

-- What a fixed amount gains a level of the caster's above the rank's, up to its cap (research_threat_rest.md §1: Feint, Fade, Distracting
-- Shot, pet abilities).
local function Gain(t, index, row, level)
	local gain = Finite(t and ValueAt(t.pl, index)) and ValueAt(t.pl, index) or nil
	local from = row[2]
	if not gain or gain == 0 or not (Finite(level) and Finite(from)) then
		return 0
	end
	local to = level
	local cap = ValueAt(t.mx, index)
	if Finite(cap) and cap > 0 and cap < to then
		to = cap
	end
	return to > from and gain * (to - from) or 0
end

-- The right text of the threat line and its clauses for the dim line, by the kind of the spell's threat (design 1.2): own, its own rule (it
-- shows the block where threat is special); first, the clauses of its own rule; after, those after its note; factors, the multipliers it takes.
local function Threat(kind, t, entry, row, index, state, stats, opts, G, factors, Gb)
	local r = { tone = "plain", own = false, first = {}, after = {}, factors = K.TAKES_G[kind] and factors or {} }
	if not K.TAKES_G[kind] then
		G, Gb = 1, "c"
	end
	local value = t and ValueAt(t.v, index)
	local basis = t and BasisAt(t.b, index) or "c"
	local level = entry.pet and opts.petLevel or state.level
	local raw = Finite(value) and value + Gain(t, index, row, level) or 0
	local duration = Finite(row.du) and row.du > 0 and row.du or nil
	local guess = (basis == "e" or Gb == "e") and "~" or ""
	local ap = t and Finite(t.ap) and t.ap or nil
	local power = ap and stats and Finite(stats.ap) and stats.ap or nil
	if t and t.forms ~= nil and not InSet(t.forms, state.form) then
		r.own, r.factors = true, {}
		r.right = "only in " .. (FormNames(t.forms) or "a form")
		return r
	end
	if kind == "mult" then
		local v = Finite(value) and value or 1
		r.own = t ~= nil and v ~= 1
		r.right = guess .. "damage " .. Mult(v * G)
		if r.own then
			r.first[1] = SpellName(entry, row) .. " " .. (basis == "e" and "~" or "") .. Mult(v)
		end
	elseif kind == "bonus" or kind == "flat" then
		-- The amount of its own, and its share of attack power, multiplied with damage threat (bonus: Heroic Strike, damage x2.16 + ~324) or alone
		-- (flat: Sunder Armor, 552). With no stats the rule stands in the right text, and the dim line names only the multipliers (design 1.3).
		r.own = true
		local rule = Num(raw) .. (ap and (" + " .. Pct(ap) .. " of attack power") or "")
		local times = G ~= 1 and (" " .. Mult(G)) or ""
		local mine = (basis == "e" or (ap and t.apb == "e")) and "~" or ""
		local head = ""
		if kind == "bonus" then
			head = (Gb == "e" and "~" or "") .. "damage" .. times .. " + "
		elseif Gb == "e" then
			mine = "~"
		end
		if ap and not power then
			r.right = head .. mine .. (G ~= 1 and ("(" .. rule .. ")" .. times) or rule)
		else
			r.right = head .. mine .. Num(Toward((raw + (ap and power * ap or 0)) * G))
			if kind == "bonus" then
				r.first[1] = "damage + " .. mine .. rule
			elseif ap or G ~= 1 then
				r.first[1] = rule
			end
			if ap and stats.old then
				r.tone = "old"
			end
		end
	elseif kind == "more" then
		r.own = true
		r.right = guess .. "damage " .. Mult((Finite(value) and value or 1) * G) .. " + ?"
		if duration then
			r.first[1] = "forces attacks " .. Sec(duration)
		end
		r.first[#r.first + 1] = "how much more threat is not known"
	elseif kind == "drop" then
		r.own = true
		r.right = guess .. Num(Toward(-math.abs(raw) * G))
		r.first[1] = Num(-math.abs(raw))
	elseif kind == "temp" then
		r.own = true
		r.right = guess .. Num(Toward(-math.abs(raw))) .. (duration and (" for " .. Sec(duration)) or "")
		r.after[1] = "no talent or stance changes it"
		if duration then
			r.after[2] = "given back after " .. Sec(duration)
		end
	elseif kind == "taunt" then
		r.own = true
		r.right = "taunts: your threat to the top" .. (duration and (", " .. Sec(duration)) or "")
	elseif kind == "force" then
		r.own = true
		r.right = "forces attacks" .. (duration and (" " .. Sec(duration)) or "") .. ", no threat"
	elseif kind == "none" then
		r.own, r.right = true, "none"
	elseif kind == "wipe" then
		r.own, r.right = true, "drops all your threat"
	elseif kind == "resist" then
		r.own, r.right = true, "drops your threat on each enemy that does not resist"
	elseif kind == "heal" then
		-- Heals make half a point a point healed, split between the enemies; a paladin's Holy Light, Flash of Light and Holy Shock a quarter
		-- (D.HEAL_THREAT, design 1.4).
		local data, general = ns.SpellData, ModelOf("healThreat")
		local paladin = type(data) == "table" and type(data.HEAL_THREAT) == "table" and data.HEAL_THREAT[entry.key] or nil
		local v = (Finite(paladin) and paladin) or (Finite(value) and value) or general
		r.own = Finite(paladin) or (t ~= nil and v ~= general)
		r.right = guess .. Dec(v * G) .. " x healing" .. ((t == nil or t.split) and ", split" or "")
		if r.own then
			r.first[1] = SpellName(entry, row) .. " " .. Dec(v)
		end
	elseif kind == "caster" then
		-- Faerie Fire in a bear form: twice the caster's level (research_threat_tanks.md §2, EV-0034).
		r.own = true
		local v, who = Finite(value) and value or 0, entry.pet and "your pet's level" or "your level"
		if Finite(level) then
			r.right = guess .. Num(Toward(v * level * G))
			r.first[1] = Dec(v) .. " x " .. who
		else
			r.right = Dec(v) .. " x " .. who .. (G ~= 1 and (" " .. Mult(G)) or "")
		end
	elseif kind == "rage" then
		-- Rage gained: v is threat a point of rage, split, and no multiplier of the spell changes it; the data's note says which rage a stance
		-- or form changes (research_threat_tanks.md §2: the rage at once is unscaled, the rage over time takes the stance's or form's).
		r.own = true
		r.right = (basis == "e" and "~" or "") .. Num(raw) .. " a point of rage"
	else
		return nil
	end
	if t and t.split == true and kind ~= "heal" then
		r.right = r.right .. ", split"
	end
	return r
end

-- The rules of tooltips ---------------------------------------------------------------------------------------------------------------------------

-- What a rule's multiplier covers: all threat, its schools, or its spells.
local function Scope(rule)
	if type(rule.schools) == "table" then
		local names, words = SchoolNames(), {}
		for _, school in ipairs(rule.schools) do
			words[#words + 1] = names[school] or "?"
		end
		return table.concat(words, " and ")
	elseif type(rule.spells) == "table" then
		local words = {}
		for _, key in ipairs(rule.spells) do
			words[#words + 1] = TitleCase(key)
		end
		return table.concat(words, ", ")
	end
	return "all"
end

-- The talent that needs a shield and shares a stance's form (Defiance and Defensive Stance), whose note says so only while it matters.
local function ShieldTalent(L, rule)
	if rule.form == nil or rule.talent ~= nil then
		return nil
	end
	for _, other in ipairs(L.rules) do
		if other ~= rule and other.talent ~= nil and other.shield and Overlap(other.form, rule.form) then
			return other
		end
	end
	return nil
end

-- The calls --------------------------------------------------------------------------------------------------------------------------------------

-- The entry and the place of a rank by its spell ID; nil for a spell not in the data or of another class (ALL's and the player's pet's count).
function M.Find(spellID)
	if not Whole(spellID) then
		return nil
	end
	local L = Lookups()
	local hit = L and L.byId[spellID]
	if hit then
		return hit[1], hit[2]
	end
	return nil
end

function M.ByKey(key)
	local L = type(key) == "string" and Lookups() or nil
	return L and L.byKey[key] or nil
end

-- The place and the spell ID of the highest rank of an entry the player knows, or nil. A judgement's damage ranks are rows no spell book holds:
-- the game casts the judgement of the seal that is up, at the seal's rank, so a judgement (its field seal, SpellData.lua) takes the rank of the
-- same place as the highest rank of its seal the player knows, for the spell lines, the gear lines and the window alike. Kept until the next
-- SPELLS_CHANGED; a rank learned or lost since changes M.Version.
function M.Highest(entry)
	if type(entry) ~= "table" or type(entry.ranks) ~= "table" then
		return nil
	end
	if S.marks.spells then
		S.marks.spells = false
		S.before, S.highest = S.highest, {}
	end
	local kept = S.highest[entry]
	if kept then
		return kept[1] or nil, kept[2]
	end
	local index, id
	local L = type(entry.seal) == "string" and Lookups() or nil
	local seal = L and L.byKey[entry.seal] or nil
	if type(seal) == "table" and seal ~= entry then
		local place = M.Highest(seal)
		place = Whole(place) and place >= 1 and math.min(place, #entry.ranks) or nil
		local rank = place and entry.ranks[place] or nil
		local spell = type(rank) == "table" and rank[1] or nil
		if Whole(spell) then
			index, id = place, spell
		end
	else
		for place = #entry.ranks, 1, -1 do
			local rank = entry.ranks[place]
			local spell = type(rank) == "table" and rank[1] or nil
			if Whole(spell) and Knows(spell) then
				index, id = place, spell
				break
			end
		end
	end
	S.highest[entry] = { index or false, id }
	local before = S.before and S.before[entry]
	if before and before[1] ~= (index or false) then
		Bump()
	end
	return index, id
end

-- S.state, its marked parts read first; always a table, its fields nil where never read.
function M.State()
	Refresh(false)
	return S.state
end

-- S.stats, read first while marked and plain; nil before the first plain read.
function M.Stats()
	Refresh(true)
	return S.stats
end

-- A number that changes only when a value read differs from the last read (a worn item the game loaded since included), the text check answers,
-- a rank is learned or lost, or a row of the tab changes: the key of every cache (design 4.6).
function M.Version()
	local changed = false
	for index, path in ipairs(K.ROWS) do
		local value = nil
		if type(ns.Get) == "function" then
			value = Ask(ns.Get, path)
		end
		if value ~= S.rows[index] then
			S.rows[index], changed = value, true
			if path == K.ROLE_ROW then
				S.marks.role = true
			end
		end
	end
	if changed then
		Bump()
	end
	Refresh(true)
	return S.version
end

-- The events are heard while any reader ("spell lines", "gear lines", "gear window") wants them.
function M.Want(owner, on)
	if type(owner) ~= "string" then
		return
	end
	S.owners[owner] = on and true or nil
	Hear(next(S.owners) ~= nil)
end

-- Marks a part of the player for the next read: "state", "stats", "talents", "gear", "spells" or "role".
function M.Mark(what)
	if type(what) == "string" and S.marks[what] ~= nil then
		S.marks[what] = true
	end
end

-- fn(stats) runs right after each plain stats read, in the same frame.
function M.AfterRead(fn)
	if type(fn) ~= "function" then
		return
	end
	for _, known in ipairs(S.after) do
		if known == fn then
			return
		end
	end
	S.after[#S.after + 1] = fn
end

-- "base" (the game's texts give base values), "with" (they count spell power) or nil (not checked), and the probe's name and rank.
function M.TextCheck()
	local check = S.check
	if check.result then
		return check.result, check.name, check.rank
	end
	return nil
end

-- The threat multipliers in force for the entry's school and key: G, the factors { { name, m, b, background } ... }, the basis; none for a pet's.
function M.Multiplier(entry, state)
	if type(entry) ~= "table" then
		return 1, {}, "c"
	end
	state = type(state) == "table" and state or S.state
	return Factors(entry, state, state.role)
end

-- True for the off hand's weapon part of a strike that has another weapon part (Whirlwind, Mutilate) while the player does not dual wield: the off
-- hand adds nothing then, as GearModel.lua counts it, so it gets no line.
local function IdleOffHand(entry, part, state)
	if part[1] ~= "wpn" or part.h ~= "off" or state.dual == true then
		return false
	end
	for _, other in ipairs(entry.parts) do
		if type(other) == "table" and other[1] == "wpn" and other.h ~= "off" then
			return true
		end
	end
	return false
end

-- The title of a block of power lines, which shows as its header where it has more than one line (0.5.20): Spell power for parts of spell damage
-- and healing alone, Attack power for parts of attack power, weapon damage and block value alone, else Power.
local function PowerTitle(entry)
	local spell, attack = false, false
	for _, part in ipairs(entry.parts) do
		if type(part) == "table" then
			if part[1] == "sp" or part[1] == "heal" then
				spell = true
			else
				attack = true
			end
		end
	end
	return (spell and not attack and "Spell power") or (attack and not spell and "Attack power") or "Power"
end

-- The power lines of a rank (design 1.2): { { left, right, tone, dim, wrap } ... }, a line a part (but the off hand's of a strike while the player
-- does not dual wield), and its title (out.title, PowerTitle); opts { stats = With your stats, lowRank = Less for low ranks }, both on unless
-- false. tone is "plain", or "old" while the stats are from before a fight now on; an estimate is the ~ in the text.
function M.PowerLines(entry, rank, state, stats, opts)
	local out = {}
	if type(entry) ~= "table" or type(entry.parts) ~= "table" or type(entry.ranks) ~= "table" then
		return out
	end
	out.title = PowerTitle(entry)
	local row, at = RankRow(entry, rank)
	if not row then
		return out
	end
	state = type(state) == "table" and state or S.state
	opts = type(opts) == "table" and opts or {}
	-- A pet's spell counts the pet's own power, which the player's stats are not: its shares show alone.
	if opts.stats == false or type(stats) ~= "table" or entry.pet then
		stats = nil
	end
	for index, part in ipairs(entry.parts) do
		if type(part) == "table" and not IdleOffHand(entry, part, state) then
			PartLines(out, entry, row, index, part, state, stats, opts.lowRank ~= false)
		end
	end
	return out
end

-- The spell totals -----------------------------------------------------------------------------------------------------------------------------

-- The base of a part at the player's level: the rank's mean at lv and its gain a level up to mx (design 3.2), as GearModel.lua's Base counts it.
local function PartBase(row, at, level)
	local base = PartValue(row.bm, at) or 0
	local gain = PartValue(row.bl, at)
	if gain and gain ~= 0 then
		base = base + gain * Levels(row, at, level)
	end
	return base
end

-- The form a weapon part swings in: its strike's own (spd cat or bear), else the player's (Cat Form, a bear form), else none.
local function SwingForm(part, state)
	if part.spd == "cat" or part.spd == "bear" then
		return part.spd
	elseif state.form == K.CAT then
		return "cat"
	elseif state.form ~= nil and K.BEARS[state.form] then
		return "bear"
	end
	return nil
end

-- A hand's weapon damage before attack power and the speed it swings at, as GearModel.lua's HandMean counts them: the mean of the weapon's damage
-- lines (a second school's with it); in a form the main hand is the paw, the weapon's damage a second times the form's swing, at least
-- K.PAW_LEAST; an empty main hand 0 at K.UNARMED_SPEED, an estimate (the third answer). Nil for an empty off hand or ranged slot.
local function HandMean(state, slot, form)
	local weapon = type(state.weapons) == "table" and state.weapons[slot] or nil
	local mean, speed
	if type(weapon) == "table" and Finite(weapon.min) and Finite(weapon.max) and Positive(weapon.speed) then
		mean, speed = (weapon.min + weapon.max) / 2, weapon.speed
		if Finite(weapon.plusMin) and Finite(weapon.plusMax) then
			mean = mean + (weapon.plusMin + weapon.plusMax) / 2
		end
	end
	if slot == K.MAIN and form then
		local swing = ModelOf("form", form)
		return math.max(K.PAW_LEAST, mean and mean / speed * swing or K.PAW_LEAST), swing, false
	elseif mean then
		return mean, speed, false
	elseif slot == K.MAIN then
		return 0, K.UNARMED_SPEED, true
	end
	return nil
end

-- The speed a strike counts attack power at, as GearModel.lua's StrikeSpeed: in a form the hand's own swing; normalized by the weapon's kind (norm),
-- the ranged one (nranged); else the weapon's own speed.
local function StrikeSpeed(part, state, slot, own)
	if SwingForm(part, state) then
		return own
	end
	local weapon = type(state.weapons) == "table" and state.weapons[slot] or nil
	if part.spd == "norm" then
		if type(weapon) == "table" and weapon.twoHand then
			return ModelOf("norm", "two")
		elseif type(weapon) == "table" and weapon.dagger then
			return ModelOf("norm", "dagger")
		end
		return ModelOf("norm", "one")
	elseif part.spd == "nranged" then
		return ModelOf("norm", "ranged")
	end
	return own
end

-- One hand's part of a weapon strike as (base, bonus, estimate): (weapon mean + attack power / 14 x the strike's speed + flat + the part's own base)
-- x the weapon multiple x pct, as GearModel.lua's HandStrike counts it, the attack power share the bonus and the rest the base. flat and pct are
-- UnitDamage's (UnitRangedDamage's for the ranged slot), and the Physical school's only; the ranged weapon's mean takes its ammunition's damage a
-- second x its speed where it fires it (K.FIRES); the off hand's weapon and attack power share take the off-hand factor (OffHand); the multiple is
-- the dagger one with a dagger in the main hand where the data gives one (dg). Nil for a hand with no weapon.
local function HandTotal(entry, row, at, part, state, stats, slot)
	local mean, own, empty = HandMean(state, slot, slot == K.MAIN and SwingForm(part, state) or nil)
	if not mean then
		return nil
	end
	local ranged = slot == K.RANGED
	local damage = ranged and stats.rdmg or stats.dmg
	damage = type(damage) == "table" and damage or {}
	if ranged then
		local sub = state.weapons[slot].subclass
		if Positive(state.ammo) and (sub == nil or state.ammoKind == nil or K.FIRES[sub] == state.ammoKind) then
			mean = mean + state.ammo * own
		end
	end
	local physical = entry.school == 1
	local flat = physical and Finite(damage.flat) and damage.flat or 0
	local pct = physical and Finite(damage.pct) and damage.pct or 1
	local power = ranged and stats.rap or stats.ap
	local bonus = (Finite(power) and power or 0) / ModelOf("apPerDps") * StrikeSpeed(part, state, slot, own)
	local off = slot == K.OFF and OffHand(state, stats) or 1
	local multiple = PartValue(row.w, at) or (Finite(part[2]) and part[2]) or 1
	local main = type(state.weapons) == "table" and state.weapons[K.MAIN] or nil
	if Finite(part.dg) and type(main) == "table" and main.dagger == true then
		multiple = part.dg
	end
	local scale = multiple * pct
	return (mean * off + flat + PartBase(row, at, state.level)) * scale, bonus * off * scale, empty
end

-- A weapon part of its hand (h: main, off, ranged, or both hands, the off hand only while dual wielding), or nil for a hand with no weapon.
local function WeaponTotal(entry, row, at, part, state, stats)
	local hand = part.h or "main"
	if hand ~= "both" then
		return HandTotal(entry, row, at, part, state, stats, (hand == "off" and K.OFF) or (hand == "ranged" and K.RANGED) or K.MAIN)
	end
	local base, bonus, estimate = HandTotal(entry, row, at, part, state, stats, K.MAIN)
	if base and state.dual == true then
		local offBase, offBonus = HandTotal(entry, row, at, part, state, stats, K.OFF)
		if offBase then
			base, bonus = base + offBase, bonus + offBonus
		end
	end
	return base, bonus, estimate
end

-- A part that is no weapon damage as (base, bonus, estimate): its base, and its share of its stat (spell power with the low rank factor while the
-- row is on, as its power line counts it, attack power, ranged attack power, block value), a finisher's at 5 combo points, as GearModel.lua's
-- Amount counts it; a part with free counts that share of itself (against an enemy that is not stunned), an estimate.
local function PartTotal(entry, row, at, part, state, stats, lowRank)
	local stat = part[1]
	local share = PartValue(row.c, at) or (Finite(part[2]) and part[2]) or 0
	local base = PartBase(row, at, state.level)
	if part.per == "cp" then
		base = base + (Finite(row.cpb) and row.cpb or 0) * 5
		local list = type(part.cp) == "table" and part.cp or nil
		share = list and Finite(list[5]) and list[5] or share * 5
	end
	local power = nil
	if stat == "sp" then
		power = SchoolPower(entry, part, stats)
	elseif stat == "heal" then
		power = stats.heal
	elseif stat == "ap" or stat == "rap" then
		power = stats[stat]
	elseif stat == "bv" then
		power = stats.block
	end
	local factor = 1
	if (stat == "sp" or stat == "heal") and lowRank and not part.g then
		factor = LowFactor(row, state.level)
	end
	local bonus = (Finite(power) and power or 0) * share * factor
	local estimate = part.b == "e" or factor < 1
	if Finite(part.free) then
		base, bonus, estimate = base * part.free, bonus * part.free, true
	end
	local damage = entry.roll == "ranged" and stats.rdmg or stats.dmg
	local pct = entry.school == 1 and type(damage) == "table" and Finite(damage.pct) and damage.pct or 1
	return base * pct, bonus * pct, estimate
end

-- The kind a total is worked out as: the entry's comparison kind, else a heal for one with only healing parts, else a spell (a shield's charge).
local function TotalKind(entry)
	if entry.cmp ~= nil then
		return entry.cmp
	end
	for _, part in ipairs(entry.parts) do
		if type(part) == "table" and part[1] ~= "heal" then
			return "spell"
		end
	end
	return "heal"
end

-- Whether the player wears what the entry needs (the data's needs): a dagger in the main hand, or a shield; true when it needs nothing.
local function Equipped(entry, state)
	if entry.needs == "dagger" then
		local main = type(state.weapons) == "table" and state.weapons[K.MAIN] or nil
		return type(main) == "table" and main.dagger == true
	elseif entry.needs == "shield" then
		return state.shield == true
	end
	return true
end

-- The unit of a total: a strike's hit, a swing or a shot by kind; a channel; for parts that all tick, the duration and a tick; for parts that are
-- all a hit, block, stack or proc, that; else a cast; each target for a part on each target.
local function TotalUnit(kind, t, row, state)
	local unit
	if kind == "auto" and state.dual == true then
		unit = "both hands, a swing each"
	elseif K.KIND_UNIT[kind] then
		unit = K.KIND_UNIT[kind]
	elseif kind == "channel" then
		unit = "a channel"
	elseif t.allOver and t.ticks then
		local ms = Finite(row.du) and row.du > 0 and row.du or (Finite(t.period) and t.ticks * t.period * 1000) or nil
		unit = (ms and ("over " .. Sec(ms)) or "over its time") .. ", " .. Num((t.base + t.bonus) / t.ticks) .. " a tick"
	elseif t.per and K.PER_UNIT[t.per] then
		unit = K.PER_UNIT[t.per]
	else
		unit = "a cast"
	end
	if t.each then
		unit = unit .. ", each target"
	end
	return unit
end

-- What one cast does now with the player's stats (0.5.20, Total): { value, base, bonus, unit, estimate }, the sum of the parts its kind counts
-- (a heal's healing parts, any other kind's other parts, as GearModel.lua's Suits; never a part on the caster, nor the off hand of a strike while
-- the player does not dual wield), the base what the spell and the weapon give and the bonus what the player's stats add. Nil for a kind it is
-- not worked out for (a seal, a proc, a threat alone), a strike whose weapon the player lacks, or a spell that needs a dagger or shield not worn.
local function Total(entry, row, at, state, stats, lowRank)
	local kind = TotalKind(entry)
	if not K.TOTAL_KINDS[kind] or not Equipped(entry, state) then
		return nil
	end
	local heal = K.HEALS[kind] == true
	local t = { base = 0, bonus = 0, estimate = false, allOver = true, ticks = nil, period = nil, per = nil, each = false, any = false }
	for index, part in ipairs(entry.parts) do
		if type(part) == "table" and (part[1] == "heal") == heal and part.per ~= "self" and not IdleOffHand(entry, part, state) then
			local base, bonus, estimate
			if kind == "wand" then
				local mean = HandMean(state, K.RANGED)
				local damage = type(stats.rdmg) == "table" and stats.rdmg or {}
				base, bonus, estimate = mean and mean * (Finite(damage.pct) and damage.pct or 1), 0, true
			elseif part[1] == "wpn" then
				base, bonus, estimate = WeaponTotal(entry, row, at, part, state, stats)
			else
				base, bonus, estimate = PartTotal(entry, row, at, part, state, stats, lowRank)
			end
			if base == nil then
				return nil
			end
			t.base, t.bonus, t.any = t.base + base, t.bonus + bonus, true
			t.estimate = t.estimate or estimate == true
			local ticks = PartValue(row.n, at) or part.n
			if Finite(ticks) and ticks >= 2 then
				t.ticks, t.period = ticks, Finite(part.p) and part.p or t.period
			else
				t.allOver = false
			end
			if t.per == nil then
				t.per = part.per or false
			elseif t.per ~= part.per then
				t.per = false
			end
			t.each = t.each or part.per == "target" or part.per == "first"
		end
	end
	if not t.any then
		return nil
	end
	return { value = t.base + t.bonus, base = t.base, bonus = t.bonus, unit = TotalUnit(kind, t, row, state), estimate = t.estimate }
end

-- The seconds of one cast for "a second of casting": a channel's duration, else C_Spell.GetSpellInfo's castTime of the rank (SpellDocumentation.lua:
-- 416-430, as GearModel.lua's CastSeconds reads it), else the rank's; at least the global cooldown, and true as the second answer when the global
-- cooldown is what counts (an instant).
local function CastSeconds(entry, row)
	local gcd = ModelOf("gcd")
	local seconds = nil
	if entry.cmp == "channel" or row.ct == -1 then
		seconds = Finite(row.du) and row.du > 0 and row.du / 1000 or nil
	end
	if not seconds then
		local ms = Field(Ask(Api("C_Spell", "GetSpellInfo"), row[1]), "castTime")
		if not Finite(ms) then
			ms = row.ct
		end
		seconds = Finite(ms) and ms > 0 and ms / 1000 or 0
	end
	if seconds < gcd then
		return gcd, true
	end
	return seconds, false
end

-- The mana one cast of a rank costs (C_Spell.GetSpellPowerCost, SpellDocumentation.lua:535-549: a list of SpellPowerCostInfo,
-- SpellSharedDocumentation.lua:46-59, its type Enum.PowerType), or nil: none for rage, energy or a spell that costs nothing.
local function ManaCost(id)
	local costs = Ask(Api("C_Spell", "GetSpellPowerCost"), id)
	if not Plain(costs, "table") then
		return nil
	end
	for index = 1, K.MAX_COSTS do
		local cost = Field(costs, index)
		if cost == nil then
			break
		end
		local kind, amount = Field(cost, "type"), Field(cost, "cost")
		if kind == K.MANA and Finite(amount) and amount > 0 then
			return amount
		end
	end
	return nil
end

-- The rates line (0.5.20, chat.spellRates): the expected value with crits and misses (GearModel.lua's G.Expect, looked up when asked, its cast),
-- then a second of cast time (the global cooldown for an instant), or for what rides on the swings or shots its own figure a second, and a point of
-- mana, each of the expected value, else of the total; ~ before an estimate. Nil with nothing to say.
local function Rates(entry, at, row, state, stats, total, lowRank)
	local G = ns.GearModel
	local result = nil
	if type(G) == "table" and type(G.Expect) == "function" then
		local ok, value = pcall(G.Expect, { entry = entry, rank = at, id = row[1] }, state, stats, { lowRank = lowRank })
		if ok and type(value) == "table" and value.why == nil and Finite(value.cast) then
			result = value
		end
	end
	local words, figure, guess = {}, nil, ""
	if result then
		figure, guess = result.cast, result.estimate == true and "~" or ""
		words[1] = "Expected " .. guess .. Num(figure) .. " with crits and misses"
	elseif total then
		figure, guess = total.value, total.estimate and "~" or ""
	end
	if not figure or figure <= 0 then
		return nil
	end
	if result and result.perSecond then
		if Finite(result.second) then
			words[#words + 1] = guess .. Num(result.second) .. " a second"
		end
	elseif not entry.nx then
		local seconds, instant = CastSeconds(entry, row)
		words[#words + 1] = guess .. Num(figure / seconds) .. (instant and " a second of the global cooldown" or " a second of casting")
		local mana = ManaCost(row[1])
		if mana then
			words[#words + 1] = guess .. Num(figure / mana) .. " a point of mana"
		end
	end
	if #words == 0 then
		return nil
	end
	words[1] = words[1]:sub(1, 1):upper() .. words[1]:sub(2)
	return table.concat(words, "; ")
end

-- The total block of a rank (0.5.20), titled "Total" (out.title): a line "Total" with what one cast does now with the player's stats, base and
-- bonus together ("973 a cast  (556 + 417)", Total; while chat.spellTotal is on), and one dim line of its rates (Rates; while chat.spellRates is
-- on). opts { total, rates, lowRank }, each on unless false. Nothing without stats (With your stats off) or for a pet's spell, whose power is the
-- pet's own. tone is "old" while the stats are from before a fight now on.
function M.TotalLines(entry, rank, state, stats, opts)
	local out = { title = "Total" }
	if type(entry) ~= "table" or entry.pet or type(entry.parts) ~= "table" or type(entry.ranks) ~= "table" or type(stats) ~= "table" then
		return out
	end
	local row, at = RankRow(entry, rank)
	if not row then
		return out
	end
	state = type(state) == "table" and state or S.state
	opts = type(opts) == "table" and opts or {}
	local lowRank = opts.lowRank ~= false
	local total = Total(entry, row, at, state, stats, lowRank)
	if total and opts.total ~= false then
		local right = (total.estimate and "~" or "") .. Num(total.value) .. " " .. total.unit
		if total.base >= 1 and total.bonus >= 1 then
			right = right .. "  (" .. Num(total.base) .. " + " .. Num(total.bonus) .. ")"
		end
		out[#out + 1] = Line("Total", right, stats.old and "old" or "plain")
	end
	if opts.rates ~= false then
		local text = Rates(entry, at, row, state, stats, total, lowRank)
		if text then
			out[#out + 1] = Dim(text)
		end
	end
	return out
end

-- The threat block of a rank (design 1.2, 1.4; titled "Threat"), or none: a line "Threat" with the value and a dim line naming the spell's own
-- rule and each multiplier in force. opts { mode = "special", "all" or "off", petLevel, role }. Where threat is special or changed the block shows
-- for a rule of the spell's own, a heal whose half a point something changes, or a multiplier the player can change that is not background;
-- background ones are named when something else brings the block.
function M.ThreatLines(entry, rank, state, stats, opts)
	local out = { title = "Threat" }
	if type(entry) ~= "table" or type(entry.ranks) ~= "table" then
		return out
	end
	opts = type(opts) == "table" and opts or {}
	local mode = opts.mode or "special"
	local row, index = RankRow(entry, rank)
	if mode == "off" or not row then
		return out
	end
	state = type(state) == "table" and state or S.state
	if opts.stats == false or type(stats) ~= "table" or entry.pet then
		stats = nil
	end
	-- With no threat of its own a spell makes damage threat, or healing threat when it only heals; a paladin's heal of D.HEAL_THREAT, which can
	-- also deal damage (Holy Shock), shows its heal rule, the one that is special.
	local t = type(entry.threat) == "table" and entry.threat or nil
	local data = ns.SpellData
	local paladin = type(data) == "table" and type(data.HEAL_THREAT) == "table" and Finite(data.HEAL_THREAT[entry.key])
	local kind = t and t.k or (paladin and Heals(entry) and "heal") or (Damages(entry) and "mult") or (Heals(entry) and "heal") or nil
	-- A threat the data marks unknown (not known on Forever: Power Word: Shield, Execute, Whirlwind, the absorbs) gets no line.
	if not kind or kind == "unknown" then
		return out
	end
	local G, factors, Gb = Factors(entry, state, opts.role or state.role)
	local r = Threat(kind, t, entry, row, index, state, stats, opts, G, factors, Gb)
	if not r then
		return out
	end
	local show = mode == "all" or r.own
	for _, factor in ipairs(r.factors) do
		show = show or not factor.background
	end
	if not show then
		return out
	end
	local clauses = {}
	for _, clause in ipairs(r.first) do
		clauses[#clauses + 1] = clause
	end
	if t and type(t.note) == "string" and t.note ~= "" then
		clauses[#clauses + 1] = t.note
	end
	for _, clause in ipairs(r.after) do
		clauses[#clauses + 1] = clause
	end
	local named = {}
	for _, factor in ipairs(r.factors) do
		named[#named + 1] = factor.name .. " " .. (factor.b == "e" and "~" or "") .. Mult(factor.m) .. (factor.also and (", " .. factor.also) or "")
	end
	if #named > 0 then
		clauses[#clauses + 1] = table.concat(named, ", ")
	end
	out[1] = Line("Threat", r.right, r.tone)
	if #clauses > 0 then
		out[2] = Dim(table.concat(clauses, "; "))
	end
	return out
end

-- The lines of a stance, form, aura or talent tooltip (design 1.3; titled "Threat"), from the rule's say and note, or none: say gives its
-- multiplier, as the tip spell's own text says nothing of threat; the note is a dim line, but that of a stance whose talent needs a shield, which
-- shows only while the talent is learned and no shield is worn (Defiance counts only with a shield: x1.8 now). rank is the talent rank of the
-- tooltip's block.
function M.RuleLines(spellID, state, rank)
	local out = { title = "Threat" }
	local L = Whole(spellID) and Lookups() or nil
	local rule = L and (L.tips[spellID] or L.talents[spellID]) or nil
	if not rule then
		return out
	end
	state = type(state) == "table" and state or S.state
	if rule.say then
		local m = rule.m
		if rule.talent ~= nil and type(rule.r) == "table" then
			local own = type(state.talents) == "table" and state.talents[rule.talent] or nil
			local at = (Finite(rank) and rank > 0 and rank) or (Finite(own) and own > 0 and own) or #rule.r
			m = rule.r[at] or rule.r[#rule.r]
		end
		if Finite(m) then
			out[#out + 1] = Line("Threat", Scope(rule) .. " " .. (rule.b == "e" and "~" or "") .. Mult(m), "plain")
		end
	end
	if type(rule.note) == "string" and rule.note ~= "" then
		local talent = ShieldTalent(L, rule)
		if not talent then
			out[#out + 1] = Dim(rule.note)
		else
			local learned = type(state.talents) == "table" and state.talents[talent.talent] or nil
			if Finite(learned) and learned > 0 and state.shield == false and Finite(rule.m) then
				out[#out + 1] = Dim(rule.note .. ": " .. Mult(rule.m) .. " now")
			end
		end
	end
	return out
end

-- The rounding of design 1.2, for every file that words a number of the model, and of design 2.3 for the gear comparison: Percent (a change as a
-- share, "+1.8%"), Figure (a figure now or with an item) and Change (its change, signed), which the item tooltips and the window both use; Pct2 (a
-- share with two decimals, signed on request, for the avoidance table). And the one style of every line Flat UI adds to a tooltip and of the
-- window: Style { header, label, value, good, bad, dim } as { r, g, b } (a block's gold header, a figure's light grey label and white value, a
-- change better or worse, a dim note), Hex and Paint (a colour inside a line), Tone (the colour of a change by its direction). Numbers: thousands
-- broken, whole from 100 up, one decimal below; percents one decimal (the avoidance table two); signs on changes only.
M.Fmt = { Pct = Pct, Mult = Mult, Num = Num, Signed = Signed, Percent = Percent, Figure = Figure, Change = Change, Pct2 = Pct2, Style = Style,
	Hex = Hex, Paint = Paint, Tone = Tone }
