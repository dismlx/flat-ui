local _, ns = ...

-- The model of the gear comparison, part of Chat and tooltips with no switch of its own (as SpellModel.lua and ChatTips.lua are): which worn items
-- an item would replace, what wearing it changes in the player's stats, and the expected damage, healing and threat of each chosen spell or auto
-- attack now and with it, worked out per cast and per second, deterministic, with no roll and no simulation. GearLines.lua writes its answers in item
-- tooltips and GearWindow.lua in the Gear comparison window. Nothing is drawn, written on a frame or hooked here; no frame is made and no event is
-- heard. The player's state and stats are SpellModel.lua's (ns.SpellModel: M.State, M.Stats, M.Version, M.Mark, M.AfterRead, M.Highest,
-- M.Multiplier), the attack table is the hit table's (ns.HitTableCalc: C.Inputs, C.Table, C.Target, C.LineOf, C.Skill), the spells' values are
-- SpellData.lua's (ns.SpellData), the chosen spells GearLines.lua's (ns.GearChosen, ns.GearListVersion) and the role Core.lua's (ns.PlayerRole), each
-- looked up when asked, never while the files load.
--
-- What it asks the game, in this order. Each call is under pcall and each answer passes ns.IsSecret or ns.Finite before it is compared, added, joined
-- or used as a key; a call that raises or a secret answer is withheld, and is told apart from none, as HitTableCalc.lua's Call does
-- (HitTableCalc.lua:70-81). In a fight (InCombatLockdown) nothing is worked out and the last answer for an item stays (for the last K.CACHE items).
-- The hit table's inputs are read by C.Inputs right after each plain read of the stats, inside it (M.AfterRead), with every kind of attack, so a
-- paladin's judgement gets a Ranged line although the hit table gives a paladin melee and spells (HitTableCalc.lua:55-58), and with the ranged line
-- of no ranged weapon while the ranged slot holds none (GetInventoryItemID, C.LineOf: a paladin's libram is no ranged weapon,
-- HitTableCalc.lua:509-523). With no read since this file registered, a read is asked for (M.Mark, M.Stats), and with still none C.Inputs reads them
-- here, only while the game gives stats plain (C_Secrets.ShouldUnitStatsBeSecret, SecretPredicateAPIDocumentation.lua:388-396). Against, Where you
-- stand and Hit cap against a boss come from the rows of the Spells and gear tab (chat.gearAgainst, chat.gearFacing, chat.gearRules, and the hit
-- table's hud.hitTableRules) and the player's level (S.state, else UnitLevel), and the target of the table is the one those rows name, worked out
-- again each time (C.Target), so a row changed since the read counts at once.
-- An item: its kind (C_Item.GetItemInfoInstant, ItemDocumentation.lua:659-679), its name and quality (C_Item.GetItemInfo, :626-657, which gives
-- nothing until the client has the item, so the game is asked to load it, C_Item.RequestLoadItemDataByID, :1710-1718, as BagsData.lua:1649 does,
-- and the next build has the lines), its quality's colour for the header (C_Item.GetItemQualityColor, :921-936), its stats by the game's keys
-- (C_Item.GetItemStats, :1004-1018, with the full link, which holds a random suffix's bonus list) and its tooltip lines (the build's own data.lines,
-- else C_TooltipInfo.GetHyperlink, or for a worn item C_TooltipInfo.GetInventoryItem, TooltipInfoDocumentation.lua:337-354, 389-405). Item answers
-- carry no secret mark; they pass ns.IsSecret all the same. Which worn items it replaces: the game's own choice first
-- (C_TooltipComparison.GetItemComparisonInfo, TooltipComparisonDocumentation.lua:42-57, 78-101, with { guid } or { hyperlink } as the game builds its
-- comparison item, TooltipComparisonManager.lua:11-21; not protected, unlike CompareItem at :10-22, and untested from addon code, so under pcall and
-- out of combat), each worn item's slot from its GUID (C_Item.GetItemLocation, ItemDocumentation.lua:786-799, its equipmentSlotIndex as
-- ChatTips.lua:134-157 reads it, else C_Item.GetItemLinkByGUID, :771-784, held against the worn links); then the slots its inventory type can take,
-- and the uniqueness of rings, trinkets and a dual wielder's one-handers (C_Item.GetItemUniquenessByID, :1055-1072, and the item's Unique and
-- Unique-Equipped lines). Ammunition is compared only while the game uses it (C_PaperDollInfo.AmmoNeeded, PaperDollInfoDocumentation.lua:11-18,
-- the game-wide flag) and the player does (UnitUsesAmmo("player"), UnitDocumentation.lua:3359-3372, as Camelot/PaperDollFrame.lua:1517 shows the
-- slot; a nil answer hides nothing), and only ammunition the worn ranged weapon fires: arrows from a bow or crossbow, bullets from a gun (the
-- subclasses of C_Item.GetItemInfoInstant, TrackerKinds.lua's rule). The ammunition's damage counts with the ranged weapon it fits, in every shot;
-- a compared ranged weapon the worn ammunition does not fit counts it as a stand-in for ammunition of its kind, an estimate, and a thrown weapon or
-- a wand counts none.
-- A rating becomes percent with the client's own conversion (GetCombatRatingBonusForCombatRatingValue, PlayerScriptDocumentation.lua:335-349, which
-- has no secret mark), else with the fixed sizes of D.MODEL.ratings. A spell's cast time is the castTime of C_Spell.GetSpellInfo
-- (SpellDocumentation.lua:416-430, 1183-1195), as ProcTriggers.lua:119 reads it. A crit damage talent that is an aura (Shadowform in D.CRIT) is read
-- with C_UnitAuras.GetPlayerAuraBySpellID (UnitAuraDocumentation.lua:397-412), which answers nothing for an aura the game withholds
-- (RequiresNonSecretAura, SecretPredicatesDocumentation.lua:28-31): no aura found is off only while C_Secrets.ShouldSpellAuraBeSecret
-- (SecretPredicateAPIDocumentation.lua:139-153) answers a plain false, or the client has no such call out of combat; else the last plain answer
-- stands, and with none the aura is unknown, an estimate. The item lines are read with the client's own strings
-- (GlobalStrings enUS.lua, the English below standing in only for a client without them): the weapon's damage in its six forms, DAMAGE_TEMPLATE
-- "%s - %s Damage" (:5687), DAMAGE_TEMPLATE_WITH_SCHOOL (:5688), SINGLE_DAMAGE_TEMPLATE "%s Damage" (:19328), SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL
-- (:19329), and a second school's PLUS_DAMAGE_TEMPLATE "+ %s - %s Damage" (:16592) and PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL "+%s - %s %s Damage" (:16593),
-- whose mean adds to the weapon's, since it comes with every swing; its speed after SPEED (:20628); a shield's SHIELD_BLOCK_TEMPLATE "%s Block"
-- (:19208), which is not in its stats; ammunition's AMMO_DAMAGE_TEMPLATE "Adds %s damage per second" (:873); numbers with LARGE_NUMBER_SEPERATOR
-- (:13363) and DECIMAL_SEPERATOR (:5741); the lines no stat counts, after ITEM_SPELL_TRIGGER_ONEQUIP, ONPROC and ONUSE (:13051-13053) and a set's
-- ITEM_SET_NAME (:13038); ITEM_RANDOM_ENCHANT (:13012) for a suffix not rolled yet; ITEM_CLASSES_ALLOWED and ITEM_RACES_ALLOWED (:12687, :13011), the
-- red lines that are no "not yet"; ITEM_UNIQUE and ITEM_UNIQUE_EQUIPPABLE (:13060-13061); and the "Equip:" sentence of each stat, the
-- TOOLTIP_ITEM_STAT_* string D.STATS names (:22999-23158).
--
-- The model (the design's 2.5). A stat change is new minus old per key of C_Item.GetItemStats, each key turned into what it changes by D.STATS:
-- Strength, Agility and Intellect by the rates SpellModel.lua read with the stats while the game gave them plain (per[stat]: the conversion calls are
-- SecretWhenUnitStatsRestricted, PlayerScriptDocumentation.lua:221-235, 388-400, 908-920, 1096-1108, so none is asked here), spell power to every
-- school and healing, attack power to melee and ranged attack power (an inference: the modern engine's stat feeds both), ratings to percent, weapon
-- skill to its skill line, "+N Weapon Damage" to each weapon hit of the Physical school, block value to the shield's block with a point for each 20
-- Strength (BLOCK_VALUE_PER_STRENGTH, Camelot/PaperDollFrameStats.lua:2, 313); a creature type's bonus and spell penetration are only named. A spell
-- is E = H x (B + c x f x SP) x (1 + C x (m - 1)) on the line of the attack table its data gives it (roll), H and C that line's chances to land and
-- to crit, m 1.5 on the Spell line and 2.0 on the others (STAT_CRIT_BONUS, GlobalStrings enUS.lua:22332) raised by a crit damage talent, 1 + (m - 1)
-- x (1 + t); a periodic part the same over its ticks, which crit on Forever. A swing is (weapon mean + attack power / 14 x its own speed + flat) x
-- pct (ATTACK_POWER_MAGIC_NUMBER, Camelot/PaperDollFrameStats.lua:11; flat and pct UnitDamage's, backed out as the sheet backs them out,
-- Camelot/PaperDollFrame.lua:913-914), on the Swing line with glancing blows; a strike adds its bonus, takes the weapon multiple and the normalized
-- speed where its data says so (and its dagger multiple, dg, with a dagger in the main hand), and rolls the Special line; one that cannot be dodged,
-- parried or blocked (nd) only misses, one that cannot miss (nm) never does, and one that needs a dagger in the main hand or a shield (needs) deals
-- nothing without it, as a strike whose hand holds no weapon. A druid's strike of a form (spd cat or bear) takes that form's paw in any form. A part
-- with free counts that share of itself, against an enemy that is not stunned (Judgement of Command's half), an estimate. Threat is damage x T x G +
-- the landed share x (F + A x attack power) x G, G the multipliers SpellModel.lua finds in force (M.Multiplier); a threat the data marks unknown has
-- no figure. Haste: a new weapon swings at its own speed x (hasted now / own now) x (1 + h) / (1 + h'), h and h' the haste of the rating worn now and
-- with the item. The absolute numbers are before armor, resistances, and talents and buffs the stats do not show; the percent cancels them. A figure
-- is an estimate when a value it is built from is (design 3.5): a damage or healing figure by its parts, the model and its line of the attack table;
-- a threat figure by the threat's own values and multipliers too, and by the damage it multiplies.
--
-- G.Compare's answer, as GearLines.lua and GearWindow.lua read it (design 4.3). Its candidates come in the order the game names them, then by slot,
-- each { slots, label, empty, game, offEmpty, mean, header, notCounted, vs, noChange, rows }: slots the INVSLOT numbers the item would take, label
-- their words ("Finger 1", "both hands"), empty and game as G.Candidates gives them, offEmpty a one-hander over a worn two-hander, whose off hand
-- is left empty. A row is { line, figure, now, with, estimate, basis, perSecond, why }: with is the player with the item in that slot and now the
-- player without it, which for an item to wear is with what the slot holds now and for a worn item (G.Compare(slot), the Character window) with
-- that slot empty, so with - now is what the item gives in both; perSecond says the figure is a second (dps, a second, or the threat of what rides
-- on the swings). why, each notCounted and vs, notYet and random are the player's words (random may be true), and quiet marks a why no line
-- should show. Every option a caller passes is read: listVersion, mode, data, guid, most, role, against, facing, rules, lowRank and inputs; any
-- other is ignored. S.stats.per[stat].crit and .spellCrit are percent a point, as SpellModel.lua keeps them.

local G = {}
ns.GearModel = G

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- Constants ---------------------------------------------------------------------------------------------------------------------------------------

local K = {
	-- The worn slots the comparison works with (Blizzard_FrameXMLBase/Constants.lua:135-154).
	AMMO = 0, MAIN = 16, OFF = 17, RANGED = 18, LAST = 19,
	-- The slots' names in the lines, English as all of Flat UI's lines are (ChatTips.lua:177-190).
	LABEL = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
		"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" },
	BOTH = "both hands",
	-- What an item can replace, by its itemEquipLoc (Enum.InventoryType, ItemConstantsDocumentation.lua:182-224): one slot, the pair of rings or of
	-- trinkets, both hands for a two-hander, the hand a one-hander takes, the off hand, the ammunition.
	EQUIP = {
		INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7,
		INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_CLOAK = 15, INVTYPE_WEAPONMAINHAND = 16, INVTYPE_RANGED = 18,
		INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_FINGER = "pair", INVTYPE_TRINKET = "pair", INVTYPE_2HWEAPON = "two",
		INVTYPE_WEAPON = "one", INVTYPE_WEAPONOFFHAND = "offweapon", INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off", INVTYPE_AMMO = "ammo",
	},
	PAIR = { INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 } },
	-- No lines: a relic's bonuses are spells, and a shirt, a tabard, a bag or a quiver gives the spells nothing.
	NONE = { INVTYPE_RELIC = true, INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true },
	TWO_HAND = "INVTYPE_2HWEAPON", SHIELD = "INVTYPE_SHIELD",
	-- Enum.ItemClass.Weapon and Enum.ItemWeaponSubclass.Dagger (ItemConstantsDocumentation.lua), for a client without Enum.
	WEAPON = 2, DAGGER = 15,
	-- The ammunition each ranged weapon fires, by Enum.ItemWeaponSubclass (Bows 2 and Crossbow 18 arrows, Guns 3 bullets,
	-- ItemConstantsDocumentation.lua:627-643) and the Projectile subclasses the game documents no enum of (Arrow 2, Bullet 3, as TrackerKinds.lua's
	-- I.ARROWS and I.BULLETS); a thrown weapon and a wand fire none.
	FIRES = { [2] = 2, [18] = 2, [3] = 3 },
	-- The ranged skill lines (bows, guns, thrown weapons, crossbows, wands) and the line of an empty hand, as HitTableCalc.lua:36-41 has them.
	RANGED_LINES = { [45] = true, [46] = true, [176] = true, [226] = true, [228] = true }, UNARMED = 162,
	-- GetShapeshiftFormID of Cat Form, Bear Form and Dire Bear Form, the forms of D.RULES' cat and bear rules: their swing is the form's, and the paw
	-- is the weapon's damage a second times it (wowsims/forever, MIT: sim/druid/forms.go:85-113), at least 1.
	FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }, PAW_LEAST = 1,
	-- An empty main hand swings at 2.0 sec with no weapon damage. No source gives Forever's unarmed swing (wowsims/forever's unarmed weapon is a
	-- placeholder, sim/core/attack.go:35-44), so a line that needs it is an estimate.
	UNARMED_SPEED = 2.0,
	-- What a rating goes to, by its index (CR_HIT_MELEE 6 ... CR_EXPERTISE 24, Camelot/PaperDollFrame.lua:4-27), and the size of D.MODEL.ratings that
	-- stands in for it when the client has no conversion.
	HIT = { [6] = "melee", [7] = "ranged", [8] = "spell" }, CRIT = { [9] = "melee", [10] = "ranged", [11] = "spell" },
	HASTE = { melee = 18, ranged = 19, spell = 20 }, EXPERTISE = 24,
	SIZE = { [6] = "hit", [7] = "hit", [8] = "hit", [9] = "crit", [10] = "crit", [11] = "crit", [18] = "haste", [19] = "haste", [20] = "haste",
		[24] = "expertise" },
	STRENGTH_BLOCK = 20,
	-- The primary stats, and those whose change needs the client's rates: Strength (attack power, block value), Agility (attack power, ranged attack
	-- power, crit), Intellect (spell crit). Stamina and Spirit change none of the lines.
	STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }, RATED = { [1] = true, [2] = true, [4] = true },
	-- Seal of Righteousness' hit: its value / 100 x the weapon's speed x 1.2 with a two-hander, 0.85 with a one-hander from 2.0 sec up and 0.2 less a
	-- second under it (wowsims/forever, MIT: docs/evidence/EV-0059). Seal of Command procs 7 times a minute on white hits that land
	-- (sim/paladin/seal_of_command.go:81); no other proc's rate is known (Holy Shield's comes with blocks), so another is a cast of one proc.
	SEAL = { two = 1.2, one = 0.85, at = 2.0, step = 0.2 }, PPM = { ["seal of command"] = 7 },
	-- The comparison kinds whose figure rides on the swings or shots (damage and threat a second): a proc only with its rate (PPM). The heals, and
	-- those whose second is one of the effect.
	PER_SECOND = { auto = true, shot = true, wand = true, seal = true, proc = true },
	HEALS = { heal = true, hot = true }, LASTING = { dot = true, hot = true, channel = true },
	-- The hit table read with every kind of attack (C.Inputs' spec.kinds), so a line added later never waits for the next read.
	KINDS = { melee = true, ranged = true, spell = true },
	-- Against's first choice is a boss at this level (the row's own words, "A boss at level 60, else an enemy of your level").
	MAX_LEVEL = 60,
	-- Items cached, the length a line of an item is cut to in a "Not counted" note, the lines of a tooltip read at most, and a change under which a
	-- line counts as none (2.3).
	CACHE = 64, SHORT = 60, LINES = 60, NONE_UNDER = 0.05,
	-- Tooltip data line types (TooltipInfoSharedDocumentation.lua:27-86): UsageRequirement, ItemSpellTriggerOnUse, OnEquip, OnProc. A red line is
	-- read as ItemMarks.lua reads one (ItemMarks.lua:52-54, 201-207).
	USAGE = 43, ON_USE = 44, ON_EQUIP = 45, ON_PROC = 46, RED_LEAST = 0.9, OTHER_MOST = 0.25,
	MODES = { cast = true, second = true, threat = true },
	UNITS = { tooltip = "a cast", cast = "a cast", second = "a second", threat = "threat a cast" },
	-- The client's strings this file reads (GlobalStrings enUS.lua, lines in the header), in English for a client that has none of them.
	STRINGS = {
		DAMAGE_TEMPLATE = "%s - %s Damage", DAMAGE_TEMPLATE_WITH_SCHOOL = "%s - %s %s Damage", SINGLE_DAMAGE_TEMPLATE = "%s Damage",
		SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL = "%s %s Damage", PLUS_DAMAGE_TEMPLATE = "+ %s - %s Damage",
		PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL = "+%s - %s %s Damage", SPEED = "Speed", SHIELD_BLOCK_TEMPLATE = "%s Block",
		AMMO_DAMAGE_TEMPLATE = "Adds %s damage per second", LARGE_NUMBER_SEPERATOR = ",", DECIMAL_SEPERATOR = ".",
		ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:", ITEM_SPELL_TRIGGER_ONPROC = "Chance on hit:", ITEM_SPELL_TRIGGER_ONUSE = "Use:",
		ITEM_SET_NAME = "%s (%d/%d)", ITEM_RANDOM_ENCHANT = "<Random additional stats>", ITEM_CLASSES_ALLOWED = "Classes: %s",
		ITEM_RACES_ALLOWED = "Races: %s", ITEM_UNIQUE = "Unique", ITEM_UNIQUE_EQUIPPABLE = "Unique-Equipped",
	},
	-- The tables of S.stats a copy changes.
	STATS_TABLES = { "sp", "crit", "haste", "rating", "stat", "dmg", "rdmg", "speed" },
	-- Why there are no lines, or a line has no figure (G.Expect), in words GearLines.lua and GearWindow.lua can show.
	WHY = {
		data = "The gear comparison has no spell data.", item = "No item to compare.", worn = "This item is not worn.",
		none = "Not compared: it gives your spells nothing the comparison counts.", loading = "The game has not loaded this item yet.",
		twoHand = "Needs a one-hand weapon; not compared.", dual = "An off-hand weapon needs you to dual wield; not compared.",
		ammo = "The game does not use ammunition for you; not compared.", unique = "You wear as many of its kind as the game allows; not compared.",
		fires = "You wear no ranged weapon that fires this ammunition; not compared.",
		weapon = "Flat UI could not read this weapon's damage and speed.", combat = "Gear lines show out of combat.",
		stats = "The game has not given your stats yet.", empty = "That slot is empty.",
		notCompared = "Flat UI cannot work this spell out.", pet = "An item does not change your pet's spells.",
		rank = "Flat UI's data has no rank of this spell.", inputs = "Flat UI has not read your hit table yet.",
		withheld = "The game withheld part of your hit table.",
	},
}

-- Reading the game ---------------------------------------------------------------------------------------------------------------------------------

local function Index(t, key)
	return t[key]
end

-- A field of a table the client or another part gave, or nil when the table or the field is withheld, or reading it raises.
local function Field(t, key)
	if t == nil or IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Num(value)
	if Finite(value) then
		return value
	end
	return nil
end

local function Text(value)
	if not IsSecret(value) and type(value) == "string" then
		return value
	end
	return nil
end

local function Table(value)
	if value ~= nil and not IsSecret(value) and type(value) == "table" then
		return value
	end
	return nil
end

-- The first value of a call, or nil and why: "missing" (no such function), "refused" (it raised) or "withheld" (a secret value).
local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil, "missing"
	end
	local ok, value = pcall(fn, ...)
	if not ok then
		return nil, "refused"
	elseif IsSecret(value) then
		return nil, "withheld"
	end
	return value
end

-- A function of one of the client's tables, or nil when the client has none.
local function Api(space, name)
	local fn = Field(_G[space], name)
	if type(fn) == "function" then
		return fn
	end
	return nil
end

-- The first answer of another part's function, or nil when it is missing or raises.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

-- A value of the client's Enum, or the fallback when it has none.
local function EnumValue(group, name, fallback)
	return Num(Field(Field(_G.Enum, group), name)) or fallback
end

local function InCombat()
	return Call(InCombatLockdown) == true
end

-- True while the game gives the stats plain: C_Secrets.ShouldUnitStatsBeSecret is false, or the client has no such call.
local function StatsPlain()
	local secret, why = Call(Api("C_Secrets", "ShouldUnitStatsBeSecret"))
	if why == "missing" then
		return true
	end
	return secret == false
end

-- The other parts, looked up when asked: another file may load after this one or fail.
local function Model()
	local M = ns.SpellModel
	if type(M) == "table" then
		return M
	end
	return nil
end

local function Data()
	local D = ns.SpellData
	if type(D) == "table" and type(D.MODEL) == "table" then
		return D
	end
	return nil
end

local function Calc()
	local C = ns.HitTableCalc
	if type(C) == "table" and type(C.Inputs) == "function" and type(C.Table) == "function" then
		return C
	end
	return nil
end

local function Copy(t)
	local out = {}
	if type(t) == "table" then
		for key, value in pairs(t) do
			out[key] = value
		end
	end
	return out
end

-- t[index] of a value given by part, or the value itself when it is one number for all parts.
local function Pick(t, index)
	if type(t) == "table" then
		return t[index]
	end
	return t
end

local function AddOnce(list, text)
	for _, have in ipairs(list) do
		if have == text then
			return
		end
	end
	list[#list + 1] = text
end

-- A number with its sign, whole when it is one.
local function Signed(value)
	if value == math.floor(value) then
		return ("%+d"):format(value)
	end
	return ("%+.1f"):format(value)
end

-- The client's strings ---------------------------------------------------------------------------------------------------------------------------

-- One of the client's strings, or the English of K.STRINGS for a client that has none.
local function Word(name)
	return Text(_G[name]) or K.STRINGS[name]
end

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

local function Escape(text)
	return (text:gsub(MAGIC, "%%%0"))
end

-- A Lua pattern for a format string of the client, matched against a whole line: each %s, %d or %.1f, with its position or without (%1$s), is a
-- capture, %% a percent sign, the rest literal. order holds the format's argument of each capture, so the values come back in the order of the
-- format's own arguments, as a language that puts them in another order writes them.
local function Compile(template)
	local parts, order, count, at, size = { "^" }, {}, 0, 1, #template
	while at <= size do
		local char = template:sub(at, at)
		if char == "%" and template:sub(at + 1, at + 1) == "%" then
			parts[#parts + 1] = "%%"
			at = at + 2
		elseif char == "%" then
			local first, last, position = template:find("^%%(%d+)%$[%-%+ #0]*%d*%.?%d*[sdifgu]", at)
			if not first then
				first, last = template:find("^%%[%-%+ #0]*%d*%.?%d*[sdifgu]", at)
			end
			if not first then
				return nil
			end
			count = count + 1
			order[count] = tonumber(position) or count
			parts[#parts + 1] = "(.-)"
			at = last + 1
		else
			parts[#parts + 1] = char:find(MAGIC) and "%" .. char or char
			at = at + 1
		end
	end
	parts[#parts + 1] = "$"
	return { text = table.concat(parts), order = order }
end

local patterns = {}

local function Pattern(name)
	local found = patterns[name]
	if found == nil then
		local template = Word(name)
		found = template and Compile(template) or false
		patterns[name] = found
	end
	return found or nil
end

-- The values a whole line holds for one of the client's formats, by the format's arguments, or nil when the line is not one of it.
local function Match(name, text)
	local pattern = text and Pattern(name)
	if not pattern then
		return nil
	end
	local found = { text:match(pattern.text) }
	if found[1] == nil then
		return nil
	end
	local values = {}
	for index, position in ipairs(pattern.order) do
		values[position] = found[index]
	end
	return values
end

-- A number of a line, read with the client's thousands and decimal separators, or nil.
local function Number(text)
	if type(text) ~= "string" then
		return nil
	end
	local thousands, decimal = Word("LARGE_NUMBER_SEPERATOR"), Word("DECIMAL_SEPERATOR")
	local plain = text
	if thousands and thousands ~= "" and thousands ~= decimal then
		plain = plain:gsub(Escape(thousands), "")
	end
	if decimal and decimal ~= "" and decimal ~= "." then
		plain = plain:gsub(Escape(decimal), ".")
	end
	plain = plain:match("^%s*([%+%-]?%d*%.?%d+)%s*$")
	return Num(plain and tonumber(plain))
end

local function Starts(text, word)
	return word ~= nil and word ~= "" and text:sub(1, #word) == word
end

-- A line cut to K.SHORT characters, never inside a character of several bytes (a byte from 0x80 to 0xBF goes on with the one before).
local function Short(text)
	if #text <= K.SHORT then
		return text
	end
	local cut = K.SHORT - 3
	while cut > 1 do
		local byte = text:byte(cut + 1)
		if not (byte and byte >= 128 and byte < 192) then
			break
		end
		cut = cut - 1
	end
	return text:sub(1, cut) .. "..."
end

-- Items ---------------------------------------------------------------------------------------------------------------------------------------

-- The ID, inventory type, class and subclass of an item (C_Item.GetItemInfoInstant), or nil.
local function Instant(item)
	local fn = Api("C_Item", "GetItemInfoInstant")
	if not fn or item == nil then
		return nil
	end
	local ok, id, _, _, loc, _, class, subclass = pcall(fn, item)
	if not ok then
		return nil
	end
	return Num(id), Text(loc), Num(class), Num(subclass)
end

-- The name and quality of an item (C_Item.GetItemInfo), nil while the client has not loaded it.
local function NameOf(link)
	local fn = Api("C_Item", "GetItemInfo")
	if not fn or not link then
		return nil
	end
	local ok, name, _, quality = pcall(fn, link)
	if not ok then
		return nil
	end
	return Text(name), Num(quality)
end

local function Byte(value)
	return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

-- An item's name in the colour of its quality (C_Item.GetItemQualityColor), as the header names the worn item, or nil.
local function Coloured(link)
	local name, quality = NameOf(link)
	if not name then
		return nil
	end
	local fn = quality and Api("C_Item", "GetItemQualityColor")
	if fn then
		local ok, r, g, b = pcall(fn, quality)
		if ok and Finite(r) and Finite(g) and Finite(b) then
			return ("|cff%02x%02x%02x%s|r"):format(Byte(r), Byte(g), Byte(b), name)
		end
	end
	return name
end

-- The item ID in a link.
local function LinkID(link)
	local id = link and link:match("item:(%d+)")
	return Num(id and tonumber(id))
end

-- The permanent enchant of a link, its second field (item:id:enchant:...), as SpellModel.lua reads a worn one's, or nil.
local function EnchantOf(link)
	local id = link and tonumber(link:match("item:%-?%d+:(%d+)") or "")
	if Num(id) and id > 0 then
		return id
	end
	return nil
end

local function Into(source, out)
	for key, value in pairs(source) do
		if Text(key) and Finite(value) then
			out[key] = value
		end
	end
end

-- The stats of an item by the game's keys (C_Item.GetItemStats), each a plain number; empty for none. Kept by link once the game has given them.
local statsOf, statsKept = {}, 0

local function ItemStats(link)
	if not link then
		return {}
	end
	local kept = statsOf[link]
	if kept then
		return kept
	end
	local out = {}
	local got = Table(Call(Api("C_Item", "GetItemStats"), link))
	if got then
		pcall(Into, got, out)
		if statsKept >= K.CACHE * 4 then
			statsOf, statsKept = {}, 0
		end
		statsOf[link], statsKept = out, statsKept + 1
	end
	return out
end

-- A line's text with the colour codes taken out, or nil.
local function Clean(value)
	local text = Text(value)
	if not text then
		return nil
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:match("^%s*(.-)%s*$")
	if text == "" then
		return nil
	end
	return text
end

local function Red(colour)
	local r, g, b = Num(Field(colour, "r")), Num(Field(colour, "g")), Num(Field(colour, "b"))
	return r ~= nil and g ~= nil and b ~= nil and r >= K.RED_LEAST and g <= K.OTHER_MOST and b <= K.OTHER_MOST
end

-- The lines of an item's tooltip as plain values { left, right, kind, red }: the build's own (data.lines), else the game's for the link or, for a worn
-- item, for its slot.
local function TipLines(given, link, slot)
	local lines = Table(given)
	if not lines then
		local data
		if slot then
			data = Call(Api("C_TooltipInfo", "GetInventoryItem"), "player", slot)
		elseif link then
			data = Call(Api("C_TooltipInfo", "GetHyperlink"), link)
		end
		lines = Table(Field(data, "lines"))
	end
	local out = {}
	for index = 1, K.LINES do
		local line = Table(Field(lines, index))
		if not line then
			break
		end
		out[#out + 1] = { left = Clean(Field(line, "leftText")), right = Clean(Field(line, "rightText")), kind = Num(Field(line, "type")),
			red = Red(Field(line, "leftColor")) }
	end
	return out
end

-- The two numbers of a damage range in one of the client's formats.
local function Range(name, text)
	local values = Match(name, text)
	local low, high = values and Number(values[1]), values and Number(values[2])
	if low and high then
		return low, high
	end
	return nil
end

local function Single(name, text)
	local values = Match(name, text)
	return values and Number(values[1]) or nil
end

-- What one text of a weapon's lines says: its speed (after SPEED), a second school's range, else its damage range or single damage.
local function ReadDamage(text, found)
	if not text then
		return
	end
	if found.speed == nil then
		local word = Word("SPEED")
		local rest = word and text:match("^" .. Escape(word) .. "%s+(.+)$")
		local speed = rest and Number(rest)
		if speed then
			found.speed = speed
			return
		end
	end
	local low, high = Range("PLUS_DAMAGE_TEMPLATE", text)
	if not low then
		low, high = Range("PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL", text)
	end
	if low then
		if found.plusMin == nil then
			found.plusMin, found.plusMax = low, high
		end
		return
	end
	if found.min ~= nil then
		return
	end
	low, high = Range("DAMAGE_TEMPLATE", text)
	if not low then
		low, high = Range("DAMAGE_TEMPLATE_WITH_SCHOOL", text)
	end
	if not low then
		low = Single("SINGLE_DAMAGE_TEMPLATE", text) or Single("SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL", text)
		high = low
	end
	if low then
		found.min, found.max = low, high
	end
end

-- A weapon as S.state keeps one ({ link, id, min, max, plusMin, plusMax, speed, class, subclass, loc, line, twoHand, dagger }) from the item's lines;
-- with no damage line read, its damage a second (ITEM_MOD_DAMAGE_PER_SECOND_SHORT) times its speed. nil when the lines give no speed.
local function WeaponOf(item)
	local found = {}
	for _, line in ipairs(item.lines) do
		ReadDamage(line.left, found)
		ReadDamage(line.right, found)
	end
	local speed = found.speed
	if not (speed and speed > 0) then
		return nil
	end
	if not found.min then
		local dps = Num(item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT)
		if not dps then
			return nil
		end
		found.min, found.max = dps * speed, dps * speed
	end
	local C = Calc()
	local line = C and Num((Ask(C.LineOf, item.id))) or nil
	return { link = item.link, id = item.id, min = found.min, max = found.max, plusMin = found.plusMin, plusMax = found.plusMax, speed = speed,
		class = item.class, subclass = item.subclass, loc = item.loc, line = line, twoHand = item.loc == K.TWO_HAND,
		dagger = item.subclass == EnumValue("ItemWeaponSubclass", "Dagger", K.DAGGER) }
end

-- The number of the first line in one of the client's formats ("41 Block", "Adds 13.5 damage per second").
local function LineNumber(lines, name)
	for _, line in ipairs(lines) do
		local value = line.left and Single(name, line.left)
		if value then
			return value
		end
	end
	return nil
end

-- An item to compare: { link, id, loc, class, subclass, name, stats, lines, weapon, block, ammo }, or nil, why and whether nothing should show. A
-- worn item (slot) is read for its notes only, so its weapon numbers are not needed.
local function ItemOf(link, given, slot)
	if not link then
		return nil, K.WHY.item, true
	end
	local id, loc, class, subclass = Instant(link)
	if not id then
		return nil, K.WHY.item, true
	end
	local name = NameOf(link)
	if not name then
		Call(Api("C_Item", "RequestLoadItemDataByID"), id)
		return nil, K.WHY.loading, true
	end
	local item = { link = link, id = id, loc = loc, class = class, subclass = subclass, name = name }
	item.stats = ItemStats(link)
	item.lines = TipLines(given, not slot and link or nil, slot)
	if class == EnumValue("ItemClass", "Weapon", K.WEAPON) and not slot then
		item.weapon = WeaponOf(item)
		if not item.weapon then
			return nil, K.WHY.weapon, false
		end
	end
	-- A shield's block and ammunition's damage that its lines do not give stay those worn now, and the note says so (Notes).
	if loc == K.SHIELD and not slot then
		item.block = LineNumber(item.lines, "SHIELD_BLOCK_TEMPLATE")
		item.unread = item.block == nil and "the shield's block (Flat UI could not read it)" or nil
	elseif loc == "INVTYPE_AMMO" and not slot then
		item.ammo = LineNumber(item.lines, "AMMO_DAMAGE_TEMPLATE")
		item.unread = item.ammo == nil and "the ammunition's damage (Flat UI could not read it)" or nil
	end
	return item
end

-- The notes -----------------------------------------------------------------------------------------------------------------------------------

-- A set's name line ("Battlegear of Might (2/8)").
local function SetLine(text)
	local values = Match("ITEM_SET_NAME", text)
	return values ~= nil and Number(values[2]) ~= nil and Number(values[3]) ~= nil
end

-- The "Equip:" sentences an item's stats explain: the TOOLTIP_ITEM_STAT_* string D.STATS names for each stat it has, and the one sentence of healing
-- and damage together (D.STAT_PAIRS).
local function Explaining(stats, D)
	local names = {}
	local defs = Table(D.STATS) or {}
	for key in pairs(stats) do
		local def = Table(defs[key])
		if def and Text(def.t) then
			names[#names + 1] = def.t
		end
	end
	for _, pair in ipairs(Table(D.STAT_PAIRS) or {}) do
		if Text(pair.t) and (stats[pair[1]] ~= nil or stats[pair[2]] ~= nil) then
			names[#names + 1] = pair.t
		end
	end
	return names
end

local function Explained(text, names)
	for _, name in ipairs(names) do
		if Match(name, text) then
			return true
		end
	end
	return false
end

-- What an item's own lines say the model leaves out (the design's 2.6): each "Use:", "Chance on hit:" and set line, and each "Equip:" line no stat
-- of the item explains, cut to K.SHORT characters; whether its random stats are not rolled yet; and the text of its first red requirement that is no
-- class or race (a level, a skill, a reputation: "not wearable yet").
local function Notes(item, info)
	local D = Data()
	if not (D and item) then
		return
	end
	if item.unread then
		AddOnce(info.notCounted, item.unread)
	end
	local names = Explaining(item.stats, D)
	local equip, use, proc = Word("ITEM_SPELL_TRIGGER_ONEQUIP"), Word("ITEM_SPELL_TRIGGER_ONUSE"), Word("ITEM_SPELL_TRIGGER_ONPROC")
	local random = Word("ITEM_RANDOM_ENCHANT")
	for _, line in ipairs(item.lines) do
		local text = line.left
		if text then
			if text == random then
				info.random = true
			elseif line.kind == K.ON_USE or line.kind == K.ON_PROC or Starts(text, use) or Starts(text, proc) or SetLine(text) then
				AddOnce(info.notCounted, Short(text))
			elseif line.kind == K.ON_EQUIP or Starts(text, equip) then
				if not Explained(text, names) then
					AddOnce(info.notCounted, Short(text))
				end
			elseif line.red and line.kind == K.USAGE and info.notYet == nil and not Match("ITEM_CLASSES_ALLOWED", text)
				and not Match("ITEM_RACES_ALLOWED", text) then
				info.notYet = text
			end
		end
	end
end

-- Slots ---------------------------------------------------------------------------------------------------------------------------------------

local function LinkAt(state, slot)
	local links = state.links
	return type(links) == "table" and Text(links[slot]) or nil
end

local function Worn(state, slot)
	local weapons = state.weapons
	local weapon = type(weapons) == "table" and weapons[slot] or nil
	return type(weapon) == "table" and weapon or nil
end

-- The mean of one swing of a hand's weapon before attack power (both damage lines) and its own speed, or nil for a hand with no weapon.
local function WeaponMean(state, slot)
	local weapon = Worn(state, slot)
	if not weapon then
		return nil
	end
	local low, high, speed = Num(weapon.min), Num(weapon.max), Num(weapon.speed)
	if not (low and high and speed and speed > 0) then
		return nil
	end
	local mean = (low + high) / 2
	local plusLow, plusHigh = Num(weapon.plusMin), Num(weapon.plusMax)
	if plusLow and plusHigh then
		mean = mean + (plusLow + plusHigh) / 2
	end
	return mean, speed, weapon
end

local function TwoHandWorn(state)
	local weapon = Worn(state, K.MAIN)
	return state.twoHand == true or (weapon ~= nil and weapon.twoHand == true)
end

-- The ammunition damage a second the ranged weapon of a state fires: the worn ammunition's (S.state.ammo, its kind ammoKind) where it fits, none for a
-- thrown weapon, a wand or no ranged weapon; for a compared bow, crossbow or gun it does not fit (ammoStandIn, Wear) the worn ammunition's damage
-- stands in for ammunition of its kind, and the second answer says it is an estimate. A kind not read counts as fitting.
local function AmmoFor(state)
	local ammo, weapon = Num(state.ammo), Worn(state, K.RANGED)
	if not (ammo and ammo > 0 and weapon) then
		return 0, false
	end
	local sub, kind = Num(weapon.subclass), Num(state.ammoKind)
	if sub == nil or kind == nil or K.FIRES[sub] == kind then
		return ammo, false
	elseif K.FIRES[sub] and state.ammoStandIn then
		return ammo, true
	end
	return 0, false
end

-- The worn slot of a link, or nil.
local function SlotOfLink(state, link)
	for slot = K.AMMO, K.LAST do
		if LinkAt(state, slot) == link then
			return slot
		end
	end
	return nil
end

-- The worn slot of an item the game's comparison names: its GUID's equipment slot, else its link among the worn ones.
local function SlotOfItem(state, item)
	local guid = Text(Field(item, "guid"))
	if guid then
		local location = Call(Api("C_Item", "GetItemLocation"), guid)
		local slot = Num(Field(location, "equipmentSlotIndex"))
		if slot then
			return slot
		end
		local link = Text((Call(Api("C_Item", "GetItemLinkByGUID"), guid)))
		return link and SlotOfLink(state, link) or nil
	end
	local link = Text(Field(item, "hyperlink"))
	return link and SlotOfLink(state, link) or nil
end

-- The worn slots the game would compare an item with (C_TooltipComparison.GetItemComparisonInfo), in its order, out of combat only: its item and,
-- for Single (0) and WithBothHands (1), its additional items; the paired methods (2, 3) pair it with an item of the bags, which is not worn.
local function GameSlots(state, link, guid)
	if InCombat() then
		return nil
	end
	local fn = Api("C_TooltipComparison", "GetItemComparisonInfo")
	if not fn then
		return nil
	end
	local info = Table(Call(fn, guid and { guid = guid } or { hyperlink = link }))
	if not info then
		return nil
	end
	local named, order = {}, {}
	local slot = SlotOfItem(state, Field(info, "item"))
	if slot then
		named[slot], order[1] = true, slot
	end
	local method = Num(Field(info, "method")) or 0
	if method <= 1 then
		local more = Table(Field(info, "additionalItems"))
		for index = 1, 4 do
			local other = Field(more, index)
			if other == nil then
				break
			end
			slot = SlotOfItem(state, other)
			if slot and not named[slot] then
				named[slot], order[#order + 1] = true, slot
			end
		end
	end
	if #order == 0 then
		return nil
	end
	return named, order
end

-- Whether ammunition of a subclass fits the worn ranged weapon (K.FIRES); true while either subclass is unknown.
local function Fits(state, ammoKind)
	local weapon = Worn(state, K.RANGED)
	local kind, sub = Num(ammoKind), weapon and Num(weapon.subclass)
	if weapon and not sub then
		return true
	end
	return kind == nil or (sub ~= nil and K.FIRES[sub] == kind)
end

-- The groups of slots an item's inventory type can take, by the slot table (the design's 2.4), with the case of a one-hander over a worn two-hander
-- (offEmpty); or nil, why and whether nothing should show. sub: the item's subclass, for ammunition the worn ranged weapon must fire.
local function Groups(state, loc, sub)
	local kind = K.EQUIP[loc]
	if type(kind) == "number" then
		return { { kind } }
	elseif kind == "pair" then
		local pair = K.PAIR[loc]
		return { { pair[1] }, { pair[2] } }
	elseif kind == "two" then
		return { { K.MAIN, K.OFF } }
	elseif kind == "one" then
		if TwoHandWorn(state) then
			return { { K.MAIN } }, true
		elseif state.dual == true then
			return { { K.MAIN }, { K.OFF } }
		end
		return { { K.MAIN } }
	elseif kind == "off" or kind == "offweapon" then
		if TwoHandWorn(state) then
			return nil, K.WHY.twoHand, false
		elseif kind == "offweapon" and state.dual ~= true then
			return nil, K.WHY.dual, true
		end
		return { { K.OFF } }
	elseif kind == "ammo" then
		if Call(Api("C_PaperDollInfo", "AmmoNeeded")) ~= true or Call(_G.UnitUsesAmmo, "player") == false then
			return nil, K.WHY.ammo, true
		elseif not Fits(state, sub) then
			return nil, K.WHY.fires, false
		end
		return { { K.AMMO } }
	end
	return nil, K.WHY.worn, true
end

-- Whether an item is worn once only (isUnique, or its Unique or Unique-Equipped line), and its limit category and how many of it can be worn
-- (C_Item.GetItemUniquenessByID).
local function UniqueOf(id, lines)
	local unique, count, category = false, nil, nil
	local fn = Api("C_Item", "GetItemUniquenessByID")
	if fn and id then
		local ok, isUnique, _, limit, categoryID = pcall(fn, id)
		if ok then
			unique = not IsSecret(isUnique) and isUnique == true
			count, category = Num(limit), Num(categoryID)
		end
	end
	if not unique and lines then
		local once, equipped = Word("ITEM_UNIQUE"), Word("ITEM_UNIQUE_EQUIPPABLE")
		for _, line in ipairs(lines) do
			if line.left ~= nil and (line.left == once or line.left == equipped) then
				unique = true
				break
			end
		end
	end
	if category and category <= 0 then
		category = nil
	end
	return unique, count, category
end

-- The groups an item of two possible slots can still take: a unique item worn already only its own slot; with its limit category full, only the
-- slots that hold that category (an empty list when none of them does).
local function KeepUnique(state, id, groups, lines)
	if #groups < 2 or not id then
		return groups
	end
	local unique, count, category = UniqueOf(id, lines)
	if unique then
		for _, group in ipairs(groups) do
			for _, slot in ipairs(group) do
				if LinkID(LinkAt(state, slot)) == id then
					return { group }
				end
			end
		end
	end
	if not (category and count and count > 0) then
		return groups
	end
	local worn, holders = 0, {}
	for slot = 1, K.LAST do
		local other = LinkID(LinkAt(state, slot))
		if other then
			local _, _, otherCategory = UniqueOf(other, nil)
			if otherCategory == category then
				worn, holders[slot] = worn + 1, true
			end
		end
	end
	if worn < count then
		return groups
	end
	local kept = {}
	for _, group in ipairs(groups) do
		for _, slot in ipairs(group) do
			if holders[slot] then
				kept[#kept + 1] = group
				break
			end
		end
	end
	return kept
end

local function Label(slots)
	if #slots > 1 then
		return K.BOTH
	end
	return K.LABEL[slots[1]] or "?"
end

-- The candidates of an item: { slots, label, empty, game, offEmpty } in the order the game names them, then the others in slot order. game is true
-- for a group the game's comparison named (an empty slot counts as named once the game answered at all, since it names worn items only). sub: the
-- item's subclass (Groups).
local function Candidates(state, link, id, loc, lines, guid, sub)
	if not loc or loc == "" then
		return nil, K.WHY.worn, true
	elseif K.NONE[loc] then
		return nil, K.WHY.none, true
	end
	local groups, second, quiet = Groups(state, loc, sub)
	if not groups then
		return nil, second, quiet
	end
	local offEmpty = second == true
	groups = KeepUnique(state, id, groups, lines)
	if #groups == 0 then
		return nil, K.WHY.unique, false
	end
	local named, order = GameSlots(state, link, guid)
	local place = {}
	for index, slot in ipairs(order or {}) do
		place[slot] = index
	end
	local list = {}
	for _, slots in ipairs(groups) do
		local empty, all, first = true, named ~= nil, nil
		for _, slot in ipairs(slots) do
			if LinkAt(state, slot) then
				empty = false
				if not (named and named[slot]) then
					all = false
				end
			end
			first = first or place[slot]
		end
		list[#list + 1] = { slots = slots, label = Label(slots), empty = empty, game = all, offEmpty = offEmpty, rank = first or (100 + slots[1]) }
	end
	table.sort(list, function(a, b)
		return a.rank < b.rank
	end)
	for _, candidate in ipairs(list) do
		candidate.rank = nil
	end
	return list
end

-- The slots an item would replace (the design's 2.4): { { slots = { 11 }, label, empty, game = bool } ... }, or nil, why and whether nothing should
-- show. guid: a bag item's, for the game's own choice. lines: the item's tooltip lines when the caller has them (for its Unique lines).
function G.Candidates(link, guid, lines)
	link = Text(link)
	if not link then
		return nil, K.WHY.item, true
	end
	local M = Model()
	local state = Table(M and Ask(M.State)) or {}
	local id, loc, _, sub = Instant(link)
	-- Only an item of two possible slots needs its lines, for its Unique lines.
	local tipLines
	if loc and (K.PAIR[loc] or loc == "INVTYPE_WEAPON") then
		tipLines = TipLines(lines, link, nil)
	end
	return Candidates(state, link, id, loc, tipLines, Text(guid), sub)
end

-- The change ------------------------------------------------------------------------------------------------------------------------------------

local held = { registered = false, inputs = nil, sizes = false }

-- The percent a rating gives the player (GetCombatRatingBonusForCombatRatingValue), with its sign; with no conversion, the fixed size of the data.
local function RatingPct(rating, amount, size)
	if amount == 0 then
		return 0
	end
	local sign, value = amount < 0 and -1 or 1, math.abs(amount)
	local got = Call(GetCombatRatingBonusForCombatRatingValue, rating, value)
	if Finite(got) then
		return sign * got
	end
	held.sizes = true
	local D = Data()
	local ratings = D and Table(D.MODEL.ratings)
	local fixed = Num(size) or Num(ratings and ratings[K.SIZE[rating]])
	if fixed and fixed > 0 then
		return sign * value / fixed
	end
	return 0
end

-- (1 + h) / (1 + h'): a hasted time with the item over the time now, h the haste the rating worn now gives and h' the haste with the item's change.
local function HasteScale(stats, rating, amount, size)
	if not amount or amount == 0 then
		return 1
	end
	local worn = Num(Field(stats.rating, rating))
	local now = worn and RatingPct(rating, worn, size) or 0
	local with = worn and RatingPct(rating, math.max(0, worn + amount), size) or RatingPct(rating, amount, size)
	local scale = (1 + now / 100) / (1 + with / 100)
	if Finite(scale) and scale > 0 then
		return scale
	end
	return 1
end

local function FormOf(state)
	return K.FORMS[Num(state.form) or 0]
end

-- The speed a hand swings at before haste: the form's in Cat or Bear Form, its weapon's, 2.0 for an empty main hand, nil for no other weapon.
local function OwnSpeed(state, slot)
	local D = Data()
	local form = FormOf(state)
	if slot == K.MAIN and form and D then
		return Num(Field(D.MODEL.form, form)) or K.UNARMED_SPEED
	end
	local _, speed = WeaponMean(state, slot)
	if speed then
		return speed
	elseif slot == K.MAIN then
		return K.UNARMED_SPEED
	end
	return nil
end

-- The factor of an off-hand swing: D.MODEL.offHand (0.5), or while dual wielding the one UnitDamage gives, with its percent and flat bonus backed out
-- first as the sheet backs them out (Camelot/PaperDollFrame.lua:913-914): (off-hand mean / pct - flat) / (off-hand weapon mean + AP / 14 x its
-- speed). Kept with a copy of the stats, since UnitDamage's numbers are those of the weapon worn now.
local function OffFactor(state, stats)
	local D = Data()
	local fallback = D and Num(D.MODEL.offHand) or 0.5
	if state.dual ~= true or not D then
		return fallback
	end
	local mean, speed = WeaponMean(state, K.OFF)
	local damage = Table(stats.dmg) or {}
	local low, high, pct = Num(damage.offMin), Num(damage.offMax), Num(damage.pct)
	if not (mean and low and high and pct and pct > 0) then
		return fallback
	end
	local part = mean + (Num(stats.ap) or 0) / (Num(D.MODEL.apPerDps) or 14) * speed
	if part <= 0 then
		return fallback
	end
	local factor = ((low + high) / 2 / pct - (Num(damage.flat) or 0)) / part
	if Finite(factor) and factor > 0 and factor <= 1.5 then
		return factor
	end
	return fallback
end

local function CopyState(state)
	local copy = Copy(state)
	copy.links, copy.weapons, copy.enchants, copy.temp = Copy(state.links), Copy(state.weapons), Copy(state.enchants), Copy(state.temp)
	return copy
end

-- A copy of S.stats with its own tables, and swap: what the hit table's inputs take from the change (hit, crit and expertise in percent, skill by line),
-- the factor of the cast time (castScale), the off hand's factor of now and the slots the change touches (changed).
local function CopyStats(stats)
	local copy = Copy(stats)
	for _, key in ipairs(K.STATS_TABLES) do
		copy[key] = Copy(stats[key])
	end
	copy.swap = { hit = { melee = 0, ranged = 0, spell = 0 }, crit = { melee = 0, ranged = 0, spell = 0 }, expertise = 0, skill = {}, castScale = 1,
		changed = {} }
	return copy
end

-- The links, permanent enchants, weapons, shield and ammunition with the item in its slots (nil for the slots emptied: G.Without), so a threat
-- enchant (D.RULES' enchant and slot) or item follows what is worn in the copy, as M.Multiplier reads it. Ammunition brings its damage and kind; a
-- ranged weapon marks the worn ammunition a stand-in where it does not fit (AmmoFor).
local function Wear(state, state2, item, slots)
	for _, slot in ipairs(slots) do
		state2.links[slot], state2.weapons[slot], state2.enchants[slot] = nil, nil, nil
	end
	local slot = slots[1]
	if not item then
		if slot == K.MAIN then
			state2.twoHand, state2.dual = false, false
		elseif slot == K.OFF then
			state2.shield, state2.shieldBlock, state2.dual = false, nil, false
		elseif slot == K.AMMO then
			state2.ammo, state2.ammoKind = nil, nil
		end
		return
	end
	state2.links[slot], state2.enchants[slot] = item.link, EnchantOf(item.link)
	if slot == K.AMMO then
		state2.ammo, state2.ammoKind = item.ammo or state.ammo, item.subclass
		return
	end
	if item.weapon then
		state2.weapons[slot] = item.weapon
	end
	if slot == K.RANGED then
		state2.ammoStandIn = true
	end
	if slot == K.MAIN then
		state2.twoHand = item.weapon ~= nil and item.weapon.twoHand == true
		if state2.twoHand then
			state2.shield, state2.shieldBlock, state2.dual = false, nil, false
		else
			state2.dual = state.dual == true
		end
	elseif slot == K.OFF then
		state2.shield = item.loc == K.SHIELD
		state2.shieldBlock = state2.shield and (item.block or state.shieldBlock) or nil
		state2.dual = item.weapon ~= nil
	end
end

-- The change per kind of D.STATS, summed over the keys, with the creature type bonuses and the notes it leaves for info.
local function Sums(delta, info, D)
	local sums = { stat = {}, school = {}, rating = {}, size = {}, skill = {}, ap = 0, rap = 0, sp = 0, spd = 0, heal = 0, wdmg = 0, bv = 0 }
	local defs = Table(D.STATS) or {}
	local keys = {}
	for key in pairs(delta) do
		keys[#keys + 1] = key
	end
	-- One order, so the notes read the same each time.
	table.sort(keys)
	for _, key in ipairs(keys) do
		local amount, def = delta[key], Table(defs[key])
		local kind = def and def[1]
		if amount ~= 0 and kind then
			if kind == "stat" and Num(def[2]) then
				sums.stat[def[2]] = (sums.stat[def[2]] or 0) + amount
			elseif kind == "school" and Num(def[2]) then
				sums.school[def[2]] = (sums.school[def[2]] or 0) + amount
			elseif kind == "rating" and Table(def[2]) then
				for _, rating in ipairs(def[2]) do
					sums.rating[rating], sums.size[rating] = (sums.rating[rating] or 0) + amount, Num(def[3])
				end
			elseif kind == "skill" and Num(def[2]) then
				sums.skill[def[2]] = (sums.skill[def[2]] or 0) + amount
			elseif kind == "vs" and Text(def[2]) then
				AddOnce(info.vs, ("Against %s: %s %s"):format(def[2], Signed(amount), def[3] == "ap" and "attack power" or "spell damage"))
			elseif kind == "note" and Text(def[2]) then
				AddOnce(info.notCounted, ("%s %s"):format(def[2], Signed(amount)))
			elseif sums[kind] ~= nil and type(sums[kind]) == "number" then
				sums[kind] = sums[kind] + amount
			end
		end
	end
	return sums
end

-- Strength, Agility and Intellect by the client's rates read with the stats (per[stat]: attack power a point, and crit in percent a point, the unit
-- of S.stats.crit, as SpellModel.lua keeps them); with none, the stat is named as not counted.
local function Primary(stats, stats2, sums, info)
	local swap = stats2.swap
	for stat = 1, 5 do
		local amount = sums.stat[stat]
		if amount and amount ~= 0 then
			stats2.stat[stat] = (Num(stats2.stat[stat]) or 0) + amount
			if K.RATED[stat] then
				local per = Table(Field(stats.per, stat))
				local ap, rap = per and Num(per.ap), per and Num(per.rap)
				local crit, spellCrit = per and Num(per.crit), per and Num(per.spellCrit)
				if not (ap or rap or crit or spellCrit) then
					AddOnce(info.notCounted, ("%s (your stats were not read yet)"):format(K.STAT_NAMES[stat]))
				else
					stats2.ap = (Num(stats2.ap) or 0) + (ap or 0) * amount
					stats2.rap = (Num(stats2.rap) or 0) + (rap or 0) * amount
					swap.crit.melee = swap.crit.melee + (crit or 0) * amount
					swap.crit.ranged = swap.crit.ranged + (crit or 0) * amount
					swap.crit.spell = swap.crit.spell + (spellCrit or 0) * amount
				end
			end
		end
	end
end

-- Spell power to every school and healing, spell damage to every school, healing, one school's damage, attack power to both attack powers (the
-- modern engine's stat feeds both: an inference), ranged attack power, and "+N Weapon Damage" to each weapon hit of the Physical school.
local function Powers(stats2, sums)
	stats2.ap = (Num(stats2.ap) or 0) + sums.ap
	stats2.rap = (Num(stats2.rap) or 0) + sums.ap + sums.rap
	for school = 2, 7 do
		stats2.sp[school] = (Num(stats2.sp[school]) or 0) + sums.sp + sums.spd + (sums.school[school] or 0)
	end
	stats2.heal = (Num(stats2.heal) or 0) + sums.sp + sums.heal
	if sums.wdmg ~= 0 then
		stats2.dmg.flat = (Num(stats2.dmg.flat) or 0) + sums.wdmg
		stats2.rdmg.flat = (Num(stats2.rdmg.flat) or 0) + sums.wdmg
	end
end

-- Hit, crit and expertise ratings into the change the hit table takes, and the crit of the stats with it.
local function Ratings(stats2, sums)
	local swap = stats2.swap
	for rating, amount in pairs(sums.rating) do
		local pct = RatingPct(rating, amount, sums.size[rating])
		if K.HIT[rating] then
			swap.hit[K.HIT[rating]] = swap.hit[K.HIT[rating]] + pct
		elseif K.CRIT[rating] then
			swap.crit[K.CRIT[rating]] = swap.crit[K.CRIT[rating]] + pct
		elseif rating == K.EXPERTISE then
			swap.expertise = swap.expertise + pct
		end
	end
	for kind, gain in pairs(swap.crit) do
		local now = Num(stats2.crit[kind])
		if now then
			stats2.crit[kind] = now + gain
		end
	end
	for line, gain in pairs(sums.skill) do
		swap.skill[line] = gain
	end
end

-- The hasted speeds with the item: a hand's own speed with the item x (hasted now / own now) x the haste rating's change; a ranged weapon where none
-- is worn now by both of GetRangedHaste's returns, as the sheet takes them (Camelot/PaperDollFrameStats.lua:193-194).
local function Speeds(state, stats, state2, stats2, sums)
	local melee = HasteScale(stats, K.HASTE.melee, sums.rating[K.HASTE.melee], sums.size[K.HASTE.melee])
	local ranged = HasteScale(stats, K.HASTE.ranged, sums.rating[K.HASTE.ranged], sums.size[K.HASTE.ranged])
	stats2.swap.castScale = HasteScale(stats, K.HASTE.spell, sums.rating[K.HASTE.spell], sums.size[K.HASTE.spell])
	local speed = stats2.speed
	local ownNow, hasted = OwnSpeed(state, K.MAIN), Num(Field(stats.speed, "main"))
	local ratio = (hasted and ownNow and ownNow > 0) and hasted / ownNow or 1
	speed.main = OwnSpeed(state2, K.MAIN) * ratio * melee
	local offWith = state2.dual == true and OwnSpeed(state2, K.OFF) or nil
	if offWith then
		local offNow, offHasted = OwnSpeed(state, K.OFF), Num(Field(stats.speed, "off"))
		local offRatio = (state.dual == true and offNow and offHasted) and offHasted / offNow or ratio
		speed.off = offWith * offRatio * melee
	else
		speed.off = nil
	end
	local rangedWith = OwnSpeed(state2, K.RANGED)
	if rangedWith then
		local rangedNow = OwnSpeed(state, K.RANGED)
		local rangedHasted = Num(Field(stats.speed, "ranged")) or Num(Field(stats.rdmg, "speed"))
		if rangedNow and rangedHasted then
			speed.ranged = rangedWith * (rangedHasted / rangedNow) * ranged
		else
			local haste, quiver = Num(Field(stats.haste, "ranged")) or 0, Num(Field(stats.haste, "quiver")) or 0
			speed.ranged = rangedWith / ((1 + haste / 100) * (1 + quiver / 100)) * ranged
		end
	else
		speed.ranged = nil
	end
	stats2.rdmg.speed = speed.ranged
end

-- The block value with the item (the design's 2.5): now less the old shield's block and plus the new one's where the off hand changes, plus the block
-- value stat's change and the change of a point a 20 Strength; with no shield worn now, the new shield's block, a point a 20 Strength and the item's
-- block value. No shield with the item: none.
local function Block(state, stats, state2, stats2, sums, offChanges)
	if state2.shield ~= true then
		stats2.block = nil
		return
	end
	local strength = Num(Field(stats.stat, 1)) or 0
	local with = strength + (sums.stat[1] or 0)
	local fromStrength = math.floor(with / K.STRENGTH_BLOCK) - math.floor(strength / K.STRENGTH_BLOCK)
	local now = Num(stats.block)
	if state.shield == true and now then
		local old, new = Num(state.shieldBlock) or 0, Num(state2.shieldBlock) or 0
		stats2.block = now + (offChanges and new - old or 0) + sums.bv + fromStrength
	else
		stats2.block = (Num(state2.shieldBlock) or 0) + math.floor(with / K.STRENGTH_BLOCK) + sums.bv
	end
end

-- Copies of the state and stats with the item in the slots (nil: the slots emptied), and its stat change applied; info gets the notes of the
-- change (stats with no rate, creature type bonuses, spell penetration).
local function Swap(state, stats, item, slots, info)
	local D = Data()
	local state2, stats2 = CopyState(state), CopyStats(stats)
	stats2.swap.offFactor = OffFactor(state, stats)
	local delta = {}
	for key, value in pairs(item and item.stats or {}) do
		delta[key] = value
	end
	local offChanges = false
	for _, slot in ipairs(slots) do
		offChanges = offChanges or slot == K.OFF
		stats2.swap.changed[slot] = true
		for key, value in pairs(ItemStats(LinkAt(state, slot))) do
			delta[key] = (delta[key] or 0) - value
		end
	end
	Wear(state, state2, item, slots)
	local sums = Sums(delta, info, D)
	Primary(stats, stats2, sums, info)
	Powers(stats2, sums)
	Ratings(stats2, sums)
	Speeds(state, stats, state2, stats2, sums)
	Block(state, stats, state2, stats2, sums, offChanges)
	return state2, stats2
end

local function NewInfo()
	return { notCounted = {}, vs = {} }
end

-- Copies of the state and stats with an item in a candidate's slots (the design's 2.5): state2, stats2 and info { notCounted, vs, random, notYet, why }.
-- lines: the item's tooltip lines, the post call's data.lines, else the game's for the link.
function G.With(state, stats, link, candidate, lines)
	local info = NewInfo()
	state, stats = Table(state) or {}, Table(stats)
	local slots = Table(Field(candidate, "slots"))
	local item, why, quiet = ItemOf(Text(link), lines)
	if not item or not stats or not slots then
		info.why, info.quiet = why or (not stats and K.WHY.stats) or K.WHY.item, quiet
		return nil, nil, info
	end
	Notes(item, info)
	local state2, stats2 = Swap(state, stats, item, slots, info)
	return state2, stats2, info
end

-- Copies of the state and stats with the item in a slot taken off (a two-hander leaves both hands), and info with what its own lines leave out.
function G.Without(state, stats, slot)
	local info = NewInfo()
	state, stats, slot = Table(state) or {}, Table(stats), Num(slot)
	local link = slot and LinkAt(state, slot)
	if not link or not stats then
		info.why, info.quiet = not stats and K.WHY.stats or K.WHY.empty, true
		return nil, nil, info
	end
	local slots = { slot }
	if slot == K.MAIN and TwoHandWorn(state) then
		slots = { K.MAIN, K.OFF }
	end
	local worn = ItemOf(link, nil, slot)
	if worn then
		Notes(worn, info)
	end
	local state2, stats2 = Swap(state, stats, nil, slots, info)
	return state2, stats2, info
end

-- The factor of an off-hand hit the comparison counts (OffFactor), for SpellModel.lua's lines of an off-hand part.
function G.OffFactor(state, stats)
	return OffFactor(Table(state) or {}, Table(stats) or {})
end

-- The hit table's inputs ----------------------------------------------------------------------------------------------------------------------

local function Role(state)
	local role = state and Text(state.role)
	if role then
		return role
	end
	local ok, found = pcall(ns.PlayerRole)
	return ok and Text(found) or "damage"
end

-- Against, Where you stand, the hit cap rule and the low rank rule the comparison counts: from opts, else the rows of the tab, the choices of the rows
-- worked out (auto: a boss at level 60, else an enemy of the player's level; role: in front for a tank; As on the Hit table tab: hud.hitTableRules).
local function Spec(opts, state)
	local level = Num(state.level) or Num((Call(UnitLevel, "player"))) or K.MAX_LEVEL
	local against = opts.against or ns.Get("chat.gearAgainst") or "auto"
	if against == "auto" then
		against = level >= K.MAX_LEVEL and "boss" or "level"
	end
	if against ~= "boss" then
		against = "level"
	end
	local facing = opts.facing or ns.Get("chat.gearFacing") or "role"
	if facing == "role" then
		facing = Role(state) == "tank" and "front" or "behind"
	end
	if facing ~= "front" then
		facing = "behind"
	end
	local rules = opts.rules or ns.Get("chat.gearRules") or "hittable"
	if rules == "hittable" then
		rules = ns.Get("hud.hitTableRules")
	end
	if rules ~= "game" then
		rules = "classic"
	end
	local lowRank = opts.lowRank
	if lowRank == nil then
		lowRank = ns.Get("chat.spellLowRank") ~= false
	end
	return { against = against, facing = facing, rules = rules, lowRank = lowRank == true,
		key = against .. "|" .. facing .. "|" .. rules .. "|" .. tostring(lowRank == true) }
end

-- True while the ranged slot holds a ranged weapon (its skill line one of K.RANGED_LINES), as C.Inputs finds one.
local function RangedWorn(C)
	local id = Num((Call(GetInventoryItemID, "player", K.RANGED)))
	if not id then
		return false
	end
	local line = Num((Ask(C.LineOf, id)))
	return line ~= nil and K.RANGED_LINES[line] == true
end

-- The hit table's inputs read now (C.Inputs), with every kind of attack and, with no ranged weapon worn, the ranged line of none.
local function ReadInputs()
	local C = Calc()
	if not C then
		return
	end
	local level = Num((Call(UnitLevel, "player"))) or K.MAX_LEVEL
	local spec = Spec({}, { level = level })
	local ok, inputs = pcall(C.Inputs, { kinds = K.KINDS, rangedWithout = not RangedWorn(C), against = spec.against, facing = spec.facing })
	if ok and Table(inputs) then
		held.inputs = inputs
	end
end

-- Called by SpellModel.lua right after each plain read of the stats, in the same frame. A fault here must not stop that read, so it is caught and the
-- inputs stay those of the read before.
local function AfterRead()
	pcall(ReadInputs)
end

local function Register()
	if held.registered then
		return true
	end
	local M = Model()
	if not (M and type(M.AfterRead) == "function") then
		return false
	end
	held.registered = pcall(M.AfterRead, AfterRead) == true
	return held.registered
end

-- The hit table inputs read at the last plain read of the stats, or nil. This file is their one owner: it registers with M.AfterRead, here or when
-- the chat module starts, and reads them there.
function G.Inputs()
	Register()
	return held.inputs
end

-- The inputs for a comparison: those of the last read; with none, a read asked for (M.Mark, M.Stats); with still none, read here while the game
-- gives stats plain and out of combat.
local function InputsNow(M)
	Register()
	if held.inputs then
		return held.inputs
	end
	if type(M.Mark) == "function" then
		pcall(M.Mark, "stats")
	end
	Ask(M.Stats)
	if not held.inputs and not InCombat() and StatsPlain() then
		ReadInputs()
	end
	return held.inputs
end

-- The table with an item ---------------------------------------------------------------------------------------------------------------------

-- The inputs with the target and the facing of the rows, and with an item's change (stats.swap): hit, crit and expertise added; for a hand the
-- change touches (swap.changed), the skill of its weapon's line where the line changes (C.Skill, else the most for the level) and the dual wield of
-- the change; the item's weapon skill added to the line it names. A hand the change does not touch keeps what was read, whatever S.state holds for
-- it. sheetSkill stays as read: the sheet's crit was read with it (HitTableCalc.lua:389-404).
local function Adjust(state, stats, inputs, spec, C)
	local copy = Copy(inputs)
	local level = Num(inputs.level) or K.MAX_LEVEL
	local target = Table(Ask(C.Target, spec.against, level))
	copy.target = target or inputs.target
	copy.front, copy.facingUnsure = spec.facing == "front", false
	local swap = Table(stats.swap)
	if not swap then
		return copy
	end
	local most, changed = level * 5, Table(swap.changed) or {}
	local melee = Table(inputs.melee)
	if melee then
		local m = Copy(melee)
		copy.melee = m
		m.hit = Num(m.hit) and m.hit + swap.hit.melee or nil
		m.crit = Num(m.crit) and m.crit + swap.crit.melee or nil
		m.expertise = Num(m.expertise) and m.expertise + swap.expertise or nil
		if not inputs.feral and changed[K.MAIN] then
			local weapon = Worn(state, K.MAIN)
			local line = weapon and Num(weapon.line) or (weapon == nil and K.UNARMED or nil)
			if line and line ~= melee.line then
				m.line, m.skill = line, Num((Ask(C.Skill, line))) or most
			end
		end
		if not inputs.feral and (changed[K.MAIN] or changed[K.OFF]) then
			m.dual = state.dual == true
		end
		m.skill = Num(m.skill) and m.skill + (swap.skill[m.line] or 0) or nil
		if m.dual then
			if not melee.dual then
				-- The off hand's own hit and expertise were not read while one hand swung: the main hand's stand in.
				m.offHit, m.offExpertise, m.offSkill = melee.hit, melee.expertise, most
			end
			local offWeapon = changed[K.OFF] and Worn(state, K.OFF) or nil
			local offLine = offWeapon and Num(offWeapon.line)
			if offLine and (offLine ~= melee.offLine or not melee.dual) then
				m.offLine, m.offSkill = offLine, Num((Ask(C.Skill, offLine))) or most
			end
			m.offSkill = Num(m.offSkill) and m.offSkill + (swap.skill[m.offLine] or 0) or nil
			m.offHit = Num(m.offHit) and m.offHit + swap.hit.melee or nil
			m.offExpertise = Num(m.offExpertise) and m.offExpertise + swap.expertise or nil
		else
			m.offSkill, m.offLine, m.offHit, m.offExpertise = nil, nil, nil, nil
		end
	end
	local ranged = Table(inputs.ranged)
	if ranged then
		local r = Copy(ranged)
		copy.ranged = r
		r.hit = Num(r.hit) and r.hit + swap.hit.ranged or nil
		r.crit = Num(r.crit) and r.crit + swap.crit.ranged or nil
		if not inputs.feral and changed[K.RANGED] then
			local weapon = Worn(state, K.RANGED)
			local line = weapon and Num(weapon.line)
			if line and K.RANGED_LINES[line] then
				if line ~= ranged.line or ranged.noWeapon then
					r.line, r.noWeapon, r.unknown = line, nil, nil
					r.skill = Num((Ask(C.Skill, line))) or most
				end
			elseif weapon == nil and ranged.skill ~= nil then
				r.line, r.noWeapon, r.unknown, r.skill = nil, true, nil, most
			end
		end
		r.skill = Num(r.skill) and r.skill + (swap.skill[r.line] or 0) or nil
	end
	local spell = Table(inputs.spell)
	if spell then
		local s = Copy(spell)
		copy.spell = s
		s.hit = Num(s.hit) and s.hit + swap.hit.spell or nil
		s.crit = Num(s.crit) and s.crit + swap.crit.spell or nil
	end
	return copy
end

-- The table of a state and its stats (C.Table on the adjusted inputs), kept with the stats it was worked out for while the rows, the read, the state
-- and SpellModel.lua's version stay.
local tables = setmetatable({}, { __mode = "k" })

local function TableFor(state, stats, inputs, spec, C, version)
	local key = spec.key .. "|" .. version
	local kept = tables[stats]
	if kept and kept.key == key and kept.inputs == inputs and kept.state == state then
		return kept.read
	end
	local adjusted = Adjust(state, stats, inputs, spec, C)
	local read = Table(Ask(C.Table, { special = true, rules = spec.rules }, adjusted)) or { lines = {}, gaps = {}, assumed = {} }
	tables[stats] = { key = key, inputs = inputs, state = state, read = read }
	return read
end

-- Expected values -------------------------------------------------------------------------------------------------------------------------------

local function FindLine(read, id)
	for _, line in ipairs(Table(read.lines) or {}) do
		if line.id == id then
			return line
		end
	end
	return nil
end

-- A part of a line of the table as a share: false (it does not apply) is none, nil (the game withheld what it needs) stays nil.
local function Share(value)
	if value == false then
		return 0
	end
	local number = Num(value)
	return number and number / 100 or nil
end

-- The basis of a value a damage or healing figure is built from (a part's, design 3.5): an estimate marks it, a measured value makes it "m".
local function Basis(ctx, letter)
	if letter == "e" then
		ctx.estimate = true
	elseif letter == "m" and ctx.basis == "c" then
		ctx.basis = "m"
	end
end

-- The same for a value of the threat alone (its letter by rank, its attack power share, the multipliers): the threat figure's basis.
local function ThreatBasis(ctx, letter)
	if letter == "e" then
		ctx.threatEstimate = true
	elseif letter == "m" and ctx.threatBasis == "c" then
		ctx.threatBasis = "m"
	end
end

-- The worse of two bases, c, then m, then e (design 3.5).
local function Worse(a, b)
	if a == "e" or b == "e" then
		return "e"
	elseif a == "m" or b == "m" then
		return "m"
	end
	return "c"
end

-- A letter of a basis given by rank ("mmmmmeeee"), or the one letter.
local function Letter(b, rank)
	if type(b) == "string" and #b > 1 then
		return b:sub(rank, rank)
	end
	return b
end

-- The last plain answer of each aura AuraUp read, by spell ID.
local auraKept = {}

-- Whether an aura is on the player now. GetPlayerAuraBySpellID answers nothing for an aura the game withholds, so no aura found is off only while
-- C_Secrets.ShouldSpellAuraBeSecret answers a plain false (or the client has no such call and the player is out of combat); else, and for a call
-- that raises or a secret answer, the last plain answer stands, nil (unknown) when there is none. A client with no aura call has none on.
local function AuraUp(spellID)
	local aura, why = Call(Api("C_UnitAuras", "GetPlayerAuraBySpellID"), spellID)
	if why == "missing" then
		return false
	elseif why then
		return auraKept[spellID]
	elseif aura ~= nil then
		auraKept[spellID] = true
		return true
	end
	local secret, asked = Call(Api("C_Secrets", "ShouldSpellAuraBeSecret"), spellID)
	if secret == false or (asked == "missing" and not InCombat()) then
		auraKept[spellID] = false
		return false
	end
	return auraKept[spellID]
end

-- The crit damage talents of the data by spell key (D.CRIT), made once.
local critByKey

local function CritTalents(D)
	if critByKey then
		return critByKey
	end
	critByKey = {}
	for _, talent in ipairs(Table(D.CRIT) or {}) do
		for _, key in ipairs(Table(talent.spells) or {}) do
			local list = critByKey[key] or {}
			list[#list + 1] = talent
			critByKey[key] = list
		end
	end
	return critByKey
end

-- The crit multiplier of a line, m = 1 + (m0 - 1) x (1 + t) (the design's 2.5): m0 by line (D.MODEL.crit), t each crit damage talent of the spell at
-- the rank the player has (S.state.talents) or its aura while it is on.
local function CritMultiplier(ctx, roll)
	local base = Num(Field(ctx.model.crit, roll)) or 2
	local extra = 0
	for _, talent in ipairs(CritTalents(ctx.D)[ctx.entry.key] or {}) do
		local ranks = Table(talent.r) or {}
		local aura = Num(talent.aura)
		if aura then
			local up = AuraUp(aura)
			if up then
				extra = extra + (Num(ranks[1]) or 1)
			elseif up == nil then
				ctx.estimate = true
			end
		else
			local rank = Num(Field(ctx.state.talents, talent.talent))
			if rank and rank >= 1 then
				extra = extra + (Num(ranks[math.floor(rank)]) or 0)
			end
		end
	end
	return 1 + (base - 1) * (1 + extra)
end

-- The landed share of glancing blows' damage, (low + high) / 2 with low = min(0.91, 1.3 - 0.05 d) and high = min(0.99, max(0.2, 1.2 - 0.03 d)), d the
-- enemy's defense less the hand's skill (D.MODEL.glance; magey's Classic warrior wiki, Attack-table.md:87-115). A glancing blow never heals: low is 0
-- at least.
local function Glancing(ctx, line)
	local glance, target = Table(ctx.model.glance) or {}, Table(ctx.read.target)
	local level, skill = target and Num(target.level), Num(line.skill)
	local lowA, lowB, lowMax = Num(glance.lowA), Num(glance.lowB), Num(glance.lowMax)
	local highA, highB, highMin, highMax = Num(glance.highA), Num(glance.highB), Num(glance.highMin), Num(glance.highMax)
	if not (level and skill and lowA and lowB and lowMax and highA and highB and highMin and highMax) then
		return nil
	end
	local d = level * 5 - skill
	local low = math.max(0, math.min(lowMax, lowA - lowB * d))
	local high = math.min(highMax, math.max(highMin, highA - highB * d))
	return (low + high) / 2
end

-- A swing on the Swing, Main or Off line: 1 - miss - dodge - parry + (m - 1) x crit - glance x (1 - g), a blocked swing counted whole (R-model's
-- white swing; WSF's algebra); and the share of swings that land.
local function OnSwing(ctx, line, m)
	local parts = line and Table(line.parts)
	if not parts then
		return nil
	end
	local miss, dodge, parry, glance, crit = Share(parts.miss), Share(parts.dodge), Share(parts.parry), Share(parts.glance), Share(parts.crit)
	if not (miss and dodge and parry and glance and crit) then
		return nil
	end
	local g = 1
	if glance > 0 then
		g = Glancing(ctx, line)
		if not g then
			return nil
		end
	end
	local landed = 1 - miss - dodge - parry
	return landed + (m - 1) * crit - glance * (1 - g), landed
end

-- A cast on the Spell line: the chance to hit times the crits; and the share that lands.
local function OnSpell(line, m)
	local parts = line and Table(line.parts)
	local hit, crit = parts and Share(parts.hit), parts and Share(parts.crit)
	if not (hit and crit) then
		return nil
	end
	return hit * (1 + crit * (m - 1)), hit
end

-- A cast on the Special or Ranged line: an attack that lands unblocked can crit, a blocked one counts whole and cannot crit; one that cannot be blocked
-- (nb: the ranged judgements) counts its block share as hits, one that cannot be dodged, parried or blocked (nd: the row's No Active Defense) only
-- misses, and one that cannot miss (nm) counts its miss share as hits. And the share that lands. entry: the data's entry, or nil.
local function OnWeapon(line, m, entry)
	local parts = line and Table(line.parts)
	if not parts then
		return nil
	end
	local hit, block, crit = Share(parts.hit), Share(parts.block), Share(parts.crit)
	if not (hit and block and crit) then
		return nil
	end
	local nb, nd, nm = entry and entry.nb, entry and entry.nd, entry and entry.nm
	if nd then
		local miss = Share(parts.miss)
		if not miss then
			return nil
		end
		hit, block = 1 - miss, 0
	elseif nb then
		hit, block = hit + block, 0
	end
	if nm and not nd then
		local miss = Share(parts.miss)
		if not miss then
			return nil
		end
		hit = hit + miss
	elseif nm then
		hit = 1
	end
	return hit * (1 + crit * (m - 1)) + block, hit + block
end

-- The share of a cast's amount the entry deals on its line, with crits, and the share that lands: heals do not miss and crit as spells; a Physical
-- spell on the Spell line takes the sheet's spell crit and 1.5, an estimate (no source says which crit it rolls); a Ranged line with no ranged weapon
-- is an estimate too. Such a line is an estimate of the line itself (lineEstimate), which a flat threat's landed share takes as well.
local function LineFactor(ctx)
	local entry = ctx.entry
	if K.HEALS[entry.cmp] then
		local line = FindLine(ctx.read, "spell")
		local crit = line and Share(Field(line.parts, "crit"))
		if not crit then
			return nil
		end
		return 1 + crit * (CritMultiplier(ctx, "spell") - 1), 1
	end
	local roll = entry.roll
	if roll == "spell" then
		if ctx.physical then
			ctx.estimate, ctx.lineEstimate = true, true
		end
		return OnSpell(FindLine(ctx.read, "spell"), CritMultiplier(ctx, "spell"))
	elseif roll == "ranged" then
		if ctx.read.noRanged then
			ctx.estimate, ctx.lineEstimate = true, true
		end
		return OnWeapon(FindLine(ctx.read, "ranged"), CritMultiplier(ctx, "ranged"), entry)
	end
	return OnWeapon(FindLine(ctx.read, "special"), CritMultiplier(ctx, "special"), entry)
end

-- The base of a part at the player's level: its mean at lv and its gain a level up to mx (the data's 3.2), or the value given in its place (a seal's).
local function Base(ctx, index, mean)
	local rank = ctx.rank
	mean = mean or Num(Pick(rank.bm, index))
	if not mean then
		return 0
	end
	local gain = Num(Pick(rank.bl, index))
	if gain and gain ~= 0 then
		local from = Num(Pick(rank.lv, index)) or Num(rank[2]) or ctx.level
		local cap = Num(Pick(rank.mx, index))
		local level = ctx.level
		if cap and cap > 0 then
			level = math.min(level, cap)
		end
		mean = mean + gain * (math.max(from, level) - from)
	end
	return mean
end

-- The low rank factor of spell power: in full for D.MODEL.downrank.grace levels after the rank is learned, then step less a level, while its row is on;
-- an estimate.
local function LowRank(ctx)
	local rule = ctx.model.downrank
	local learned = Num(ctx.rank[2])
	if not (ctx.lowRank and rule and learned) then
		return 1
	end
	local over = ctx.level - learned - (Num(rule.grace) or 0)
	if over <= 0 then
		return 1
	end
	ctx.estimate = true
	return math.max(0, 1 - (Num(rule.step) or 0) * over)
end

-- The spell damage of a school, or 0 (the Physical school has none: S.stats.sp holds schools 2 to 7).
local function SchoolPower(stats, school)
	if not Finite(school) or school < 2 then
		return 0
	end
	return Num(Field(stats.sp, school)) or 0
end

-- The spell power a part counts: healing for a heal part, else its school's spell damage, the lowest of several schools (sch).
local function SpellPower(ctx, part)
	if part[1] == "heal" then
		return Num(ctx.stats.heal) or 0
	end
	local schools = Table(part.sch) or Table(ctx.entry.sch)
	if schools then
		local least
		for _, school in ipairs(schools) do
			local power = SchoolPower(ctx.stats, school)
			least = least and math.min(least, power) or power
		end
		return least or 0
	end
	return SchoolPower(ctx.stats, ctx.entry.school)
end

-- A part that is no weapon damage: its base plus its coefficient times its stat (spell power with the low rank factor, attack power, ranged attack
-- power, block value), a finisher's at 5 combo points; damage to the caster (per "self") counts none. A part with free counts that share of itself
-- against an enemy that is not stunned, an estimate.
local function Amount(ctx, part, index)
	local stat = part[1]
	if part.per == "self" or stat == "wpn" then
		return 0
	end
	Basis(ctx, part.b)
	local coef = Num(Pick(ctx.rank.c, index)) or Num(part[2]) or 0
	local base = Base(ctx, index)
	if part.per == "cp" then
		local points = Table(part.cp)
		base = base + (Num(ctx.rank.cpb) or 0) * 5
		coef = points and Num(points[5]) or coef * 5
	end
	local stats = ctx.stats
	if stat == "sp" or stat == "heal" then
		return base + coef * LowRank(ctx) * SpellPower(ctx, part)
	elseif stat == "ap" then
		return base + coef * (Num(stats.ap) or 0)
	elseif stat == "rap" then
		return base + coef * (Num(stats.rap) or 0)
	elseif stat == "bv" then
		return base + coef * (Num(stats.block) or 0)
	end
	return base
end

local function PartAmount(ctx, part, index)
	local amount = Amount(ctx, part, index)
	local free = Num(part.free)
	if free and amount ~= 0 then
		ctx.estimate = true
		return amount * free
	end
	return amount
end

-- A hand's weapon damage before attack power and its own speed: in Cat or Bear Form, or for a strike of that form (form, a part's spd cat or bear)
-- in any form, the paw, the weapon's damage a second times the form's swing (at least 1); an empty main hand 0 at 2.0 sec, an estimate; nil for an
-- empty off hand or ranged slot.
local function HandMean(ctx, slot, form)
	local mean, speed = WeaponMean(ctx.state, slot)
	form = form or ctx.form
	if slot == K.MAIN and form then
		local swing = Num(Field(ctx.model.form, form)) or 1
		local paw = mean and speed and mean / speed * swing or K.PAW_LEAST
		return math.max(K.PAW_LEAST, paw), swing
	end
	if mean then
		return mean, speed
	elseif slot == K.MAIN then
		ctx.estimate = true
		return 0, K.UNARMED_SPEED
	end
	return nil
end

-- The speed a strike counts attack power at: the weapon's own (actual), normalized by its kind (norm: 1.7 a dagger, 3.3 a two-hander, 2.4 another;
-- nranged 2.8), the form's (cat, bear), and in a form always the form's swing.
local function StrikeSpeed(ctx, part, slot, own)
	if ctx.form then
		return own
	end
	local spd, norm = part.spd or "actual", Table(ctx.model.norm) or {}
	if spd == "norm" then
		local weapon = Worn(ctx.state, slot)
		if weapon and weapon.twoHand then
			return Num(norm.two) or own
		elseif weapon and weapon.dagger then
			return Num(norm.dagger) or own
		end
		return Num(norm.one) or own
	elseif spd == "nranged" then
		return Num(norm.ranged) or own
	elseif spd == "cat" or spd == "bear" then
		return Num(Field(ctx.model.form, spd)) or own
	end
	return own
end

-- One hand's part of a strike: (weapon mean + attack power / 14 x the strike's speed + flat + bonus) x the weapon multiple x pct, flat and pct
-- UnitDamage's (UnitRangedDamage's for the ranged slot), and the Physical school's only (a Holy strike takes neither); the ranged weapon's mean with
-- its ammunition's damage a second x its own speed (AmmoFor), as every shot has it; the off hand's weapon part times its factor; the multiple with a
-- dagger in the main hand where the data gives one (dg). A strike of a form (spd cat or bear) takes that form's paw out of it too. nil for a hand
-- with no weapon.
local function HandStrike(ctx, part, index, slot)
	local form = (part.spd == "cat" or part.spd == "bear") and slot == K.MAIN and part.spd or nil
	local mean, own = HandMean(ctx, slot, form)
	if not own then
		return nil
	end
	local power, damage
	if slot == K.RANGED then
		power, damage = Num(ctx.stats.rap) or 0, Table(ctx.stats.rdmg) or {}
		local ammo, standIn = AmmoFor(ctx.state)
		mean = mean + ammo * own
		if standIn then
			ctx.estimate = true
		end
	else
		power, damage = Num(ctx.stats.ap) or 0, Table(ctx.stats.dmg) or {}
	end
	local flat = ctx.physical and (Num(damage.flat) or 0) or 0
	local pct = ctx.physical and (Num(damage.pct) or 1) or 1
	local weapon = mean + power / ctx.perDps * StrikeSpeed(ctx, part, slot, own)
	if slot == K.OFF then
		weapon = weapon * ctx.offFactor
	end
	local multiple = Num(Pick(ctx.rank.w, index)) or Num(part[2]) or 1
	local main = Worn(ctx.state, K.MAIN)
	if Num(part.dg) and main and main.dagger == true then
		multiple = part.dg
	end
	return (weapon + flat + Base(ctx, index)) * multiple * pct
end

-- A weapon part of its hand (h): main, off, ranged, or both hands while dual wielding; nil for a hand with no weapon. Its basis counts only when
-- it deals something.
local function WeaponPart(ctx, part, index)
	local hand, value = part.h or "main", nil
	if hand == "both" then
		local main = HandStrike(ctx, part, index, K.MAIN)
		local off = main and ctx.state.dual == true and HandStrike(ctx, part, index, K.OFF) or nil
		value = main and main + (off or 0) or nil
	else
		value = HandStrike(ctx, part, index, hand == "off" and K.OFF or hand == "ranged" and K.RANGED or K.MAIN)
	end
	if value ~= nil then
		Basis(ctx, part.b)
	end
	return value
end

-- The cast's seconds for "a second of casting": C_Spell.GetSpellInfo's castTime, else the rank's, scaled by the item's spell haste, the global cooldown
-- at least.
local function CastSeconds(ctx)
	local info = Num(ctx.id) and Table(Call(Api("C_Spell", "GetSpellInfo"), ctx.id))
	local ms = Num(Field(info, "castTime")) or Num(ctx.rank.ct)
	if not ms or ms < 0 then
		ms = 0
	end
	return math.max(ms / 1000 * ctx.castScale, Num(ctx.model.gcd) or 1.5)
end

-- The seconds an effect lasts: the rank's duration, else ticks x seconds a tick.
local function Duration(ctx)
	local du = Num(ctx.rank.du)
	if du and du > 0 then
		return du / 1000
	end
	for index, part in ipairs(Table(ctx.entry.parts) or {}) do
		local ticks, period = Num(Pick(ctx.rank.n, index)) or Num(part.n), Num(part.p)
		if ticks and period and ticks > 0 and period > 0 then
			return ticks * period
		end
	end
	return nil
end

local function Speed(ctx, hand, slot)
	local speed = Num(Field(ctx.stats.speed, hand))
	if speed and speed > 0 then
		return speed
	end
	local _, own = HandMean(ctx, slot)
	return own or K.UNARMED_SPEED
end

local EXPECT = {}

-- Whether a part counts for the entry's kind: a heal or HoT counts its healing parts, any other kind its other parts, so a spell that heals an ally
-- or hurts an enemy (Holy Shock, Penance, Holy Nova) counts what its kind is (design 2.3: a heal's figure is its healing, 2.5: SP is spell healing
-- for a heal); the spell lines show both shares.
local function Suits(entry, part)
	if K.HEALS[entry.cmp] then
		return part[1] == "heal"
	end
	return part[1] ~= "heal"
end

-- True when an entry has a weapon part of a hand other than the off hand. Then its off hand's part adds nothing while no off-hand weapon is worn
-- (Whirlwind, Mutilate), and only a strike of the off hand alone (Shank) needs one.
local function MainWeapon(entry)
	for _, part in ipairs(Table(entry.parts) or {}) do
		if part[1] == "wpn" and part.h ~= "off" then
			return true
		end
	end
	return false
end

-- Whether the state wears what the entry needs (the data's needs): a dagger in the main hand, or a shield; true when it needs nothing.
local function Wears(ctx)
	local needs = ctx.entry.needs
	if needs == "dagger" then
		local main = Worn(ctx.state, K.MAIN)
		return main ~= nil and main.dagger == true
	elseif needs == "shield" then
		return ctx.state.shield == true
	end
	return true
end

-- Spells, heals, their periodic and channelled kinds, weapon and attack power strikes and finishers: the sum of the parts on the entry's line, a cast
-- and a second of casting (of the effect for a DoT, HoT or channel); a next-swing strike a cast only. A strike that needs a weapon its hand lacks, and
-- a spell that needs a dagger or a shield not worn (Wears), deal nothing.
local function Damage(ctx)
	local entry, amount, missing = ctx.entry, 0, not Wears(ctx)
	local spare = MainWeapon(entry)
	for index, part in ipairs(Table(entry.parts) or {}) do
		if not Suits(entry, part) then
			-- Left out: the other half of a spell that heals or hurts.
		elseif part[1] == "wpn" then
			local value = WeaponPart(ctx, part, index)
			if value ~= nil then
				amount = amount + value
			elseif not (part.h == "off" and spare) then
				missing = true
			end
		else
			amount = amount + PartAmount(ctx, part, index) * ctx.pct
		end
	end
	local factor, land = LineFactor(ctx)
	if missing then
		factor, land = 0, land or 0
	elseif not factor then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast, ctx.land = amount * factor, land
	if entry.nx then
		return
	end
	ctx.time = K.LASTING[entry.cmp] and Duration(ctx) or CastSeconds(ctx)
	if ctx.time and ctx.time > 0 then
		ctx.second = ctx.cast / ctx.time
	end
end

EXPECT.spell, EXPECT.dot, EXPECT.channel, EXPECT.heal, EXPECT.hot = Damage, Damage, Damage, Damage, Damage
EXPECT.strike, EXPECT.apstrike, EXPECT.finisher = Damage, Damage, Damage

-- One swing of a hand before the table: (weapon mean + attack power / 14 x its own speed + flat) x pct, the off hand's weapon part times its factor.
local function SwingMean(ctx, slot)
	local mean, own = HandMean(ctx, slot)
	if not own then
		return nil
	end
	local damage = Table(ctx.stats.dmg) or {}
	local weapon = mean + (Num(ctx.stats.ap) or 0) / ctx.perDps * own
	if slot == K.OFF then
		weapon = weapon * ctx.offFactor
	end
	return (weapon + (Num(damage.flat) or 0)) * (Num(damage.pct) or 1)
end

-- Attack: one swing of each hand (a cast) and both hands' damage a second, on the Swing line or the Main and Off lines. Its change is an estimate when
-- the item changes the weapon skill of the main hand: it moves mostly through glancing blows, whose formula Forever has not confirmed against a boss
-- (HitTableCalc.lua:376).
function EXPECT.auto(ctx)
	ctx.perSecond = true
	local main = FindLine(ctx.read, "main")
	local dual = main ~= nil
	main = main or FindLine(ctx.read, "swing")
	local m = CritMultiplier(ctx, "swing")
	local factor = OnSwing(ctx, main, m)
	local swing = SwingMean(ctx, K.MAIN)
	if not (factor and swing) then
		ctx.why = K.WHY.withheld
		return
	end
	local hit = swing * factor
	local cast, second = hit, hit / Speed(ctx, "main", K.MAIN)
	if dual then
		local offFactor, offSwing = OnSwing(ctx, FindLine(ctx.read, "off"), m), SwingMean(ctx, K.OFF)
		if offFactor and offSwing then
			local offHit = offSwing * offFactor
			cast, second = cast + offHit, second + offHit / Speed(ctx, "off", K.OFF)
		end
	end
	ctx.cast, ctx.second = cast, second
	local read = Table(ctx.inputs.melee)
	if ctx.swap and read and Num(main.skill) and main.skill ~= read.skill then
		ctx.estimate = true
	end
end

-- Auto Shot: (weapon mean + ammunition damage a second x speed + ranged attack power / 14 x speed + flat) x pct on the Ranged line, the ammunition
-- the weapon fires (AmmoFor); nothing with no ranged weapon.
function EXPECT.shot(ctx)
	ctx.perSecond = true
	local mean, own = HandMean(ctx, K.RANGED)
	if not own then
		ctx.cast, ctx.second = 0, 0
		return
	end
	local damage = Table(ctx.stats.rdmg) or {}
	local ammo, standIn = AmmoFor(ctx.state)
	if standIn then
		ctx.estimate = true
	end
	local shot = (mean + ammo * own + (Num(ctx.stats.rap) or 0) / ctx.perDps * own + (Num(damage.flat) or 0)) * (Num(damage.pct) or 1)
	local factor = OnWeapon(FindLine(ctx.read, "ranged"), CritMultiplier(ctx, "ranged"), ctx.entry)
	if not factor then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast = shot * factor
	ctx.second = ctx.cast / Speed(ctx, "ranged", K.RANGED)
end

-- Shoot with a wand: the wand's mean on the Spell line, m 1.5, an estimate (WSF models wands as magic).
function EXPECT.wand(ctx)
	ctx.perSecond, ctx.estimate = true, true
	local mean, own = HandMean(ctx, K.RANGED)
	if not own then
		ctx.cast, ctx.second = 0, 0
		return
	end
	local factor = OnSpell(FindLine(ctx.read, "spell"), CritMultiplier(ctx, "spell"))
	if not factor then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast = mean * (Num(Field(ctx.stats.rdmg, "pct")) or 1) * factor
	ctx.second = ctx.cast / Speed(ctx, "ranged", K.RANGED)
end

-- The main hand's swings that land, a second.
local function Landed(ctx)
	local swing = FindLine(ctx.read, "main") or FindLine(ctx.read, "swing")
	local _, landed = OnSwing(ctx, swing, 2)
	return landed
end

-- Seal of Righteousness: a hit on each landed swing of (value / 100 x the weapon's speed x the hand factor) + 0.10, or with a two-hander two (0.12), x
-- Holy spell damage, which cannot miss and can crit on the Special line (R-hyb; wowsims/forever sim/paladin/seal_of_righteousness.go:62-81). The value
-- is the rank's seal value (sv) with its gain a level; an estimate, as the hand factors come from one beta test.
function EXPECT.seal(ctx)
	ctx.perSecond, ctx.estimate = true, true
	local index, part = 1, nil
	for at, each in ipairs(Table(ctx.entry.parts) or {}) do
		if each[1] == "sp" then
			index, part = at, each
			break
		end
	end
	local _, own = HandMean(ctx, K.MAIN)
	local two = TwoHandWorn(ctx.state)
	local seal = K.SEAL
	local hand = two and seal.two or seal.one - seal.step * math.max(0, seal.at - own)
	local share = part and (two and Num(part.two) or Num(part[2])) or 0
	local hit = Base(ctx, index, Num(ctx.rank.sv)) / 100 * own * hand + share * LowRank(ctx) * SchoolPower(ctx.stats, ctx.entry.school)
	local special = FindLine(ctx.read, "special")
	local crit = special and Share(Field(special.parts, "crit"))
	local landed = Landed(ctx)
	if not (crit and landed) then
		ctx.why = K.WHY.withheld
		return
	end
	ctx.cast = hit * (1 + crit * (CritMultiplier(ctx, "special") - 1))
	ctx.second = ctx.cast * landed / Speed(ctx, "main", K.MAIN)
end

-- True for an entry whose figures ride on the swings or shots: Attack, Auto Shot, Shoot, the seals, and a proc with a known rate (K.PPM).
local function OnSwings(entry)
	return K.PER_SECOND[entry.cmp] == true and (entry.cmp ~= "proc" or K.PPM[entry.key] ~= nil)
end

-- A proc: its parts on its line, a cast being one proc (Seal of Command: 0.7 of the weapon hit and 0.203 of Holy spell damage, a Holy strike with no
-- UnitDamage percent or flat bonus; Holy Shield: its spell power part on a block). With a rate (K.PPM) it rides on the landed white swings: a second
-- at its procs a minute, the chance a swing at the weapon's own speed (wowsims/forever sim/paladin/seal_of_command.go:62-81), and its threat a
-- second, an estimate since the rate is the simulator's. With none (Holy Shield, whose procs come with blocks) it has no second, and its threat is
-- that of one proc.
function EXPECT.proc(ctx)
	Damage(ctx)
	ctx.second, ctx.time = nil, nil
	if not OnSwings(ctx.entry) then
		return
	end
	ctx.perSecond, ctx.estimate = true, true
	local rate, landed = K.PPM[ctx.entry.key], Landed(ctx)
	local _, own = HandMean(ctx, K.MAIN)
	if ctx.cast and landed and own then
		ctx.second = ctx.cast * rate / 60 * landed * own / Speed(ctx, "main", K.MAIN)
	end
end

-- A spell that does no damage (Sunder Armor): only its threat, and the share of its casts that land.
function EXPECT.threat(ctx)
	local _, land = LineFactor(ctx)
	if ctx.entry.roll == nil then
		land = 1
	end
	ctx.land = land
	ctx.time = CastSeconds(ctx)
end

-- Threat ---------------------------------------------------------------------------------------------------------------------------------------

-- The multipliers in force for the entry (M.Multiplier): G, with their basis the threat's; 1 without the model.
local function Multiplier(ctx)
	local M = Model()
	if not (M and type(M.Multiplier) == "function") then
		return 1
	end
	local ok, value, _, basis = pcall(M.Multiplier, ctx.entry, ctx.state)
	if not ok or not Finite(value) then
		return 1
	end
	ThreatBasis(ctx, basis)
	return value
end

-- A flat threat of the rank with its gain a level up to the level it stops (pl, mx).
local function ThreatFlat(ctx, spec)
	local rank = ctx.rankIndex
	local value = Num(Pick(spec.v, rank)) or 0
	local gain = Num(Pick(spec.pl, rank))
	if gain and gain ~= 0 then
		local from = Num(ctx.rank[2]) or ctx.level
		local cap = Num(Pick(spec.mx, rank))
		local level = ctx.level
		if cap and cap > 0 then
			level = math.min(level, cap)
		end
		value = value + gain * (math.max(from, level) - from)
	end
	return value
end

local function InForms(form, forms)
	form = Num(form) or 0
	if type(forms) == "number" then
		return forms == form
	end
	for _, each in ipairs(Table(forms) or {}) do
		if each == form then
			return true
		end
	end
	return false
end

-- T (of the damage or healing), F (flat, landed casts) and whether no multiplier applies, by the threat's kind (the data's 3.2); nil for a kind with no
-- amount (taunt, force, wipe, resist, rage) and for a threat not known on Forever (unknown). Heals make 0.5 a point, 0.25 for the paladin's
-- (D.HEAL_THREAT).
local function ThreatParts(ctx, spec)
	local kind, rank = spec and spec.k, ctx.rankIndex
	if spec then
		ThreatBasis(ctx, Letter(spec.b, rank))
	end
	if K.HEALS[ctx.entry.cmp] and (kind == nil or kind == "heal") then
		local paladin = Num(Field(ctx.D.HEAL_THREAT, ctx.entry.key))
		return paladin or (kind == "heal" and Num(Pick(spec.v, rank))) or Num(ctx.model.healThreat) or 0.5, 0
	elseif kind == nil then
		return 1, 0
	elseif kind == "mult" then
		return Num(Pick(spec.v, rank)) or 1, 0
	elseif kind == "bonus" then
		return 1, ThreatFlat(ctx, spec)
	elseif kind == "flat" then
		return 0, ThreatFlat(ctx, spec)
	elseif kind == "more" then
		ctx.threatEstimate = true
		return Num(Pick(spec.v, rank)) or 1, 0
	elseif kind == "drop" then
		return 0, -math.abs(ThreatFlat(ctx, spec))
	elseif kind == "temp" then
		return 0, -math.abs(ThreatFlat(ctx, spec)), true
	elseif kind == "caster" then
		if spec.forms ~= nil and not InForms(ctx.state.form, spec.forms) then
			return 0, 0
		end
		return 0, (Num(Pick(spec.v, rank)) or 2) * ctx.level
	elseif kind == "none" then
		return 0, 0
	end
	return nil
end

-- The threat figure's basis from what it is built from (design 3.5): its own values (ThreatBasis), the damage or healing it multiplies when T is not
-- 0, and the line's landed share for a flat amount.
local function ThreatFlags(ctx, T, flat)
	if T ~= 0 then
		ctx.threatEstimate = ctx.threatEstimate or ctx.estimate
		ThreatBasis(ctx, ctx.basis)
	end
	if flat and ctx.lineEstimate then
		ctx.threatEstimate = true
	end
end

-- threat = damage x T x G + the landed share x (F + A x attack power) x G (the design's 2.5); a swing's or shot's a second (damage a second x T x G);
-- Fade's temporary amount alone, with no G. threatSecond: a second of casting or of the effect.
local function Threat(ctx)
	local spec = Table(ctx.entry.threat)
	local T, F, alone = ThreatParts(ctx, spec)
	if T == nil then
		return
	end
	local G = alone and 1 or Multiplier(ctx)
	if ctx.perSecond then
		if ctx.second then
			ctx.threat = ctx.second * T * G
			ctx.threatSecond = ctx.threat
		end
		ThreatFlags(ctx, T, false)
		return
	end
	local A = spec and Num(spec.ap) or 0
	if A ~= 0 then
		ThreatBasis(ctx, spec.apb)
	end
	-- Feint and Fade change the player's own threat: they land whole.
	local kind = spec and spec.k
	local whole = kind == "drop" or kind == "temp"
	local land = whole and 1 or ctx.land
	ThreatFlags(ctx, T, (F ~= 0 or A ~= 0) and not whole)
	local flat = 0
	if F ~= 0 or A ~= 0 then
		if not land then
			ctx.why = ctx.why or K.WHY.withheld
			return
		end
		flat = land * (F + A * (Num(ctx.stats.ap) or 0))
	end
	ctx.threat = (ctx.cast or 0) * T * G + flat * G
	if ctx.time and ctx.time > 0 and not ctx.entry.nx then
		ctx.threatSecond = ctx.threat / ctx.time
	end
end

-- The rank index and rank of a line: its rank, else its spell ID's, else the highest the player knows (M.Highest), else the last.
local function RankOf(entry, line)
	local ranks = Table(entry.ranks)
	if not ranks then
		return nil
	end
	local index = Num(line.rank)
	if index and Table(ranks[index]) then
		return index, ranks[index]
	end
	local id = Num(line.id)
	if id then
		for at, rank in ipairs(ranks) do
			if rank[1] == id then
				return at, rank
			end
		end
	end
	local M = Model()
	local best = M and Num((Ask(M.Highest, entry)))
	if best and Table(ranks[best]) then
		return best, ranks[best]
	end
	if #ranks > 0 then
		return #ranks, ranks[#ranks]
	end
	return nil
end

-- The expected values of a line (the design's 2.5): { cast, second, threat, threatSecond, basis, why }, for line { entry, rank, id }, with opts
-- { against, facing, rules, lowRank, inputs }: the rows' choices or the tab's rows, and the hit table inputs (when none, G.Inputs(), or a read asked
-- for while there is none yet). stats may be a copy G.With or G.Without made: its change (swap) goes into the hit table. basis and estimate are those
-- of cast and second, threatBasis and threatEstimate those of threat and threatSecond (design 3.5); perSecond says the figures ride on the swings or
-- shots, so threat is a second too. why is the player's words (K.WHY): a spell it cannot work out, a pet's spell, no data, no stats, no rank, no hit
-- table, or a part of the table the game withheld.
function G.Expect(line, state, stats, opts)
	local result = {}
	line = Table(line)
	local entry = line and Table(line.entry)
	local fn = entry and EXPECT[entry.cmp]
	if not fn then
		result.why = K.WHY.notCompared
		return result
	elseif entry.pet then
		result.why = K.WHY.pet
		return result
	end
	local D, C = Data(), Calc()
	stats = Table(stats)
	if not (D and C) then
		result.why = K.WHY.data
		return result
	elseif not stats then
		result.why = K.WHY.stats
		return result
	end
	state, opts = Table(state) or {}, Table(opts) or {}
	local rankIndex, rank = RankOf(entry, line)
	if not rank then
		result.why = K.WHY.rank
		return result
	end
	local M = Model()
	local inputs = Table(opts.inputs) or G.Inputs() or (M and InputsNow(M))
	if not inputs then
		result.why = K.WHY.inputs
		return result
	end
	local spec = Spec(opts, state)
	local swap = Table(stats.swap)
	local version = tostring(M and Ask(M.Version))
	local physical = entry.school == 1
	local damage
	if entry.roll == "ranged" then
		damage = Table(stats.rdmg) or {}
	else
		damage = Table(stats.dmg) or {}
	end
	local ctx = { D = D, model = D.MODEL, entry = entry, rank = rank, rankIndex = rankIndex, id = Num(line.id) or Num(rank[1]),
		level = Num(inputs.level) or Num(state.level) or K.MAX_LEVEL, state = state, stats = stats, swap = swap, inputs = inputs,
		read = TableFor(state, stats, inputs, spec, C, version), lowRank = spec.lowRank, basis = "c", estimate = false, threatBasis = "c",
		threatEstimate = false, lineEstimate = false, form = FormOf(state), physical = physical, pct = physical and (Num(damage.pct) or 1) or 1,
		castScale = swap and Num(swap.castScale) or 1, offFactor = swap and Num(swap.offFactor) or OffFactor(state, stats),
		perDps = Num(D.MODEL.apPerDps) or 14 }
	fn(ctx)
	if not ctx.why then
		Threat(ctx)
	end
	result.cast, result.second, result.threat, result.threatSecond = Num(ctx.cast), Num(ctx.second), Num(ctx.threat), Num(ctx.threatSecond)
	result.basis = ctx.estimate and "e" or ctx.basis
	result.estimate = ctx.estimate == true
	result.threatBasis = ctx.threatEstimate and "e" or ctx.threatBasis
	result.threatEstimate = ctx.threatEstimate == true
	result.perSecond = ctx.perSecond == true
	result.why = ctx.why
	return result
end

-- Which figure a line shows (the design's 2.3): "cast", "second", "threat", "dps" or nil, mode "tooltip" or the window's switch ("cast", "second",
-- "threat"). A tank's line and a line with no damage give "threat" in the tooltip, a line with no damage in every mode; the lines on the swings or
-- shots (Attack, Auto Shot, Shoot, the seals and a proc with its rate) "dps" in the tooltip and "cast" (a swing, shot, hit or proc) or "second" in
-- the window; a next-swing strike nil in "second".
function G.Figure(line, role, mode)
	local entry = Table(Field(line, "entry"))
	local cmp = entry and entry.cmp
	if not (cmp and EXPECT[cmp]) or entry.pet then
		return nil
	elseif cmp == "threat" or mode == "threat" then
		return "threat"
	elseif mode == "second" then
		if entry.nx then
			return nil
		end
		return "second"
	elseif mode == "cast" then
		return "cast"
	elseif role == "tank" then
		return "threat"
	elseif OnSwings(entry) then
		return "dps"
	end
	return "cast"
end

-- The comparison ------------------------------------------------------------------------------------------------------------------------------

local function FigureOf(result, figure)
	if figure == "dps" or figure == "second" then
		return result.second
	elseif figure == "threat" then
		return result.threat
	end
	return result.cast
end

-- The change of a row in percent, or nil when it has no figure now.
local function Change(row)
	if Finite(row.now) and Finite(row.with) and row.now ~= 0 then
		return (row.with - row.now) / math.abs(row.now) * 100
	end
	return nil
end

-- The figures now, kept by line while the version, the rows and the read stay.
local nowKept = { stamp = nil, values = {} }

local function Now(line, state, stats, opts, stamp)
	if nowKept.stamp ~= stamp then
		nowKept.stamp, nowKept.values = stamp, {}
	end
	local key = tostring(line.entry.key) .. "#" .. tostring(line.rank or line.id)
	local value = nowKept.values[key]
	if not value then
		value = G.Expect(line, state, stats, opts)
		nowKept.values[key] = value
	end
	return value
end

-- The rows of a candidate: { line, now, with, figure, estimate, basis, perSecond, why } for each chosen line, with the basis of its figure (the
-- threat's for threat) and whether its figure is a second. reverse: what a worn item gives, now being the slot empty and with as worn, so with - now
-- reads the same way as for an item to wear.
local function Rows(chosen, state, stats, state2, stats2, opts, stamp, mode, role, reverse)
	local rows = {}
	for _, line in ipairs(chosen) do
		local figure = G.Figure(line, role, mode)
		local row = { line = line, figure = figure }
		if figure then
			local worn, other = Now(line, state, stats, opts, stamp), G.Expect(line, state2, stats2, opts)
			if reverse then
				worn, other = other, worn
			end
			row.now, row.with = FigureOf(worn, figure), FigureOf(other, figure)
			if figure == "threat" then
				row.estimate = worn.threatEstimate == true or other.threatEstimate == true
				row.basis = Worse(worn.threatBasis, other.threatBasis)
			else
				row.estimate = worn.estimate == true or other.estimate == true
				row.basis = Worse(worn.basis, other.basis)
			end
			row.perSecond = figure == "dps" or figure == "second" or (figure == "threat" and (worn.perSecond == true or other.perSecond == true))
			row.why = worn.why or other.why
		end
		rows[#rows + 1] = row
	end
	return rows
end

-- The mean of the rows' changes in percent, of the first limit rows with a figure (the tooltip's shown lines), and whether none changes by
-- K.NONE_UNDER percent or more.
local function Mean(rows, limit)
	local sum, count, shown, any, moved = 0, 0, 0, false, false
	for _, row in ipairs(rows) do
		if row.figure then
			shown = shown + 1
			if Finite(row.now) and Finite(row.with) then
				any = true
				local change = Change(row)
				if (change and math.abs(change) >= K.NONE_UNDER) or (row.now == 0 and row.with ~= 0) then
					moved = true
				end
				if change and (not limit or shown <= limit) then
					sum, count = sum + change, count + 1
				end
			end
		end
	end
	return count > 0 and sum / count or nil, any and not moved
end

-- The header of a candidate: "Instead of <worn item> (<slot>), a cast:", its empty slot, or a one-hander over a two-hander's empty off hand.
local function Header(candidate, state, unit)
	local names = {}
	for _, slot in ipairs(candidate.slots) do
		local link = LinkAt(state, slot)
		local name = link and Coloured(link)
		if name then
			names[#names + 1] = name
		end
	end
	if #names == 0 then
		if candidate.label == K.BOTH then
			return ("In your empty hands, %s:"):format(unit)
		end
		return ("In your empty %s slot, %s:"):format(candidate.label, unit)
	elseif candidate.offEmpty then
		return ("Instead of %s, off hand empty, %s:"):format(table.concat(names, " and "), unit)
	end
	return ("Instead of %s (%s), %s:"):format(table.concat(names, " and "), candidate.label, unit)
end

local function Merge(into, from)
	for _, text in ipairs(from) do
		AddOnce(into, text)
	end
end

-- An item to wear: each candidate with its rows, the mean of its changes, its header and notes; the best (the larger mean, a tie to the slot the
-- game names first) gives the result's header, notes and noChange. False when the item is not loaded, so nothing is kept.
local function Instead(result, link, opts, chosen, state, stats, work)
	local data = Table(opts.data)
	local item, why, quiet = ItemOf(link, data and Field(data, "lines"))
	if not item then
		result.why, result.quiet = why, quiet
		return why ~= K.WHY.loading
	end
	Notes(item, result)
	local list
	list, why, quiet = Candidates(state, link, item.id, item.loc, item.lines, Text(Field(data, "guid")) or Text(opts.guid), item.subclass)
	if not list then
		result.why, result.quiet = why, quiet
		return true
	end
	local best, bestMean = nil, nil
	for index, candidate in ipairs(list) do
		local info = NewInfo()
		local state2, stats2 = Swap(state, stats, item, candidate.slots, info)
		candidate.rows = Rows(chosen, state, stats, state2, stats2, work.opts, work.stamp, work.mode, work.role, false)
		candidate.mean, candidate.noChange = Mean(candidate.rows, work.limit)
		candidate.header, candidate.notCounted, candidate.vs = Header(candidate, state, work.unit), info.notCounted, info.vs
		if best == nil or (candidate.mean ~= nil and (bestMean == nil or candidate.mean > bestMean)) then
			best, bestMean = index, candidate.mean
		end
		result.candidates[index] = candidate
	end
	local chosenOne = list[best]
	result.best, result.header, result.noChange = best, chosenOne.header, chosenOne.noChange
	Merge(result.notCounted, chosenOne.notCounted)
	Merge(result.vs, chosenOne.vs)
	return true
end

-- A worn item: what it gives the chosen lines, against its slot empty.
local function WhatItGives(result, slot, chosen, state, stats, work)
	local link = LinkAt(state, slot)
	if not link then
		result.why, result.quiet = K.WHY.empty, true
		return true
	end
	local slots = { slot }
	if slot == K.MAIN and TwoHandWorn(state) then
		slots = { K.MAIN, K.OFF }
	end
	local worn = ItemOf(link, nil, slot)
	if worn then
		Notes(worn, result)
	end
	local state2, stats2 = Swap(state, stats, nil, slots, result)
	local candidate = { slots = slots, label = Label(slots), empty = false, game = true, offEmpty = false }
	candidate.rows = Rows(chosen, state, stats, state2, stats2, work.opts, work.stamp, work.mode, work.role, true)
	candidate.mean, candidate.noChange = Mean(candidate.rows, work.limit)
	candidate.header = ("What it gives your spells, %s:"):format(work.unit)
	result.candidates[1], result.best, result.header, result.noChange = candidate, 1, candidate.header, candidate.noChange
	return true
end

-- The chosen lines: those given, else GearLines.lua's (ns.GearChosen).
local function Chosen(lines)
	lines = Table(lines)
	if not lines and type(ns.GearChosen) == "function" then
		lines = Table(Ask(ns.GearChosen))
	end
	local out = {}
	for _, line in ipairs(lines or {}) do
		if Table(line) and Table(line.entry) then
			out[#out + 1] = line
		end
	end
	return out
end

-- Whether each crit damage aura of the data is on, for the key of the cache: SpellModel.lua's version does not follow them.
local function Auras(D)
	local parts = {}
	for _, talent in ipairs(Table(D.CRIT) or {}) do
		local aura = Num(talent.aura)
		if aura then
			local up = AuraUp(aura)
			parts[#parts + 1] = aura .. (up == true and "+" or up == false and "-" or "?")
		end
	end
	return table.concat(parts, ",")
end

-- The results by key (cache) and the last result of each item and mode for a fight (last), each with its keys in the order kept.
local cache, kept, last, lastKept = {}, {}, {}, {}

-- Keeps a value in a store, K.CACHE at most, the oldest forgotten first.
local function Store(store, order, key, value)
	if store[key] == nil then
		order[#order + 1] = key
		if #order > K.CACHE then
			store[table.remove(order, 1)] = nil
		end
	end
	store[key] = value
end

-- The comparison of an item to wear (a link) or of a worn item (its slot number) for the chosen lines (the design's 2.3, 2.4): { header,
-- candidates = { { label, slots, mean, rows = { { line, now, with, figure, estimate, basis, perSecond, why } } } }, notCounted, vs, random, notYet,
-- noChange, why }, and best (the candidate the tooltip shows), quiet (why is no line to show), sizes (the fixed rating sizes stood in) and old (a
-- result from before the fight); the header of this file says what each holds. lines: the chosen lines (ns.GearChosen() when nil). opts: { listVersion, mode, data (the
-- post call's data, for its lines and guid), guid, most, role, against, facing, rules, lowRank, inputs (the hit table's, else those of the last
-- read) }. Kept by link (or slot and the link worn there), M.Version(), opts.listVersion and opts.mode, with the rows' choices; in a fight and with
-- stats from before it, the last result for the item while it is among the last K.CACHE kept, else why.
function G.Compare(itemOrSlot, lines, opts)
	opts = Table(opts) or {}
	local mode = K.MODES[opts.mode] and opts.mode or "tooltip"
	local result = { candidates = {}, notCounted = {}, vs = {} }
	local M, D, C = Model(), Data(), Calc()
	if not (M and D and C) then
		result.why, result.quiet = K.WHY.data, true
		return result
	end
	Register()
	local slot = Num(itemOrSlot)
	local link = not slot and Text(itemOrSlot) or nil
	if not (slot or link) then
		result.why, result.quiet = K.WHY.item, true
		return result
	end
	local state = Table(Ask(M.State)) or {}
	-- A worn item is kept by its slot and the link worn there, so a fight never shows what another item in that slot gave.
	local subject = slot and ("slot " .. slot .. " " .. (LinkAt(state, slot) or "")) or link
	local stats = Table(Ask(M.Stats))
	local again = subject .. "|" .. mode
	if InCombat() or (stats and stats.old == true) then
		if last[again] then
			local before = Copy(last[again])
			before.old = true
			return before
		end
		result.why = K.WHY.combat
		return result
	elseif not stats then
		result.why = K.WHY.stats
		return result
	end
	local spec = Spec(opts, state)
	local role = Text(opts.role) or Role(state)
	local listVersion = Num(opts.listVersion) or Num(type(ns.GearListVersion) == "function" and Ask(ns.GearListVersion)) or 0
	local key = table.concat({ subject, tostring(Ask(M.Version)), tostring(listVersion), mode, spec.key, role, Auras(D) }, "|")
	if cache[key] then
		return cache[key]
	end
	local inputs = Table(opts.inputs) or InputsNow(M)
	if not inputs then
		result.why = K.WHY.stats
		return result
	end
	local most = Num(opts.most) or Num(ns.Get("chat.gearMost")) or 5
	local work = { mode = mode, role = role, unit = K.UNITS[mode], limit = mode == "tooltip" and most or nil,
		opts = { against = spec.against, facing = spec.facing, rules = spec.rules, lowRank = spec.lowRank, inputs = inputs },
		stamp = table.concat({ tostring(Ask(M.Version)), spec.key, tostring(inputs), tostring(stats), tostring(state) }, "|") }
	local chosen = Chosen(lines)
	local keep
	if slot then
		keep = WhatItGives(result, slot, chosen, state, stats, work)
	else
		keep = Instead(result, link, opts, chosen, state, stats, work)
	end
	result.sizes = held.sizes
	if keep then
		Store(cache, kept, key, result)
		Store(last, lastKept, again, result)
	end
	return result
end

-- The hit table's inputs follow each read of the stats from the start of Chat and tooltips on, so the first tooltip has them.
ns.AddStart("chat", Register)
