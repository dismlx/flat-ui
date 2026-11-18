local _, ns = ...

-- Avoidance in the gear comparison, part of Chat and tooltips with no switch of its own, as GearModel.lua is: how often an enemy's melee swing misses
-- the player, is dodged, parried or blocked, crits or crushes, and what armor and block value take off, now and with an item, for the item tooltips
-- of GearLines.lua and the Avoidance view of GearWindow.lua. The owner asked for it beside the spell rows ("also avoidance"): a tank's gear is mostly
-- defense, dodge, parry, block and armor, which the spell rows pass over. Nothing is drawn, written on a frame or hooked here, no frame is made and
-- no event is heard; it adds one line to /flatui status (ns.AddStatus, Core.lua).
--
-- The snapshot. Every character stat call is SecretWhenUnitStatsRestricted, so the defensive stats are read in the plain moment of SpellModel.lua's
-- read (M.AfterRead: right after each plain read of its stats, in the same frame; it reads only while C_Secrets.ShouldUnitStatsBeSecret() is false,
-- SpellModel.lua:52), each call under pcall, never at compare time. A withheld answer (a call that raises, or a secret value) keeps the whole last
-- snapshot, never a mix of two reads; a missing call or a nil answer is none, as HitTableCalc.lua's Call tells them apart (HitTableCalc.lua:70-81).
-- In a fight the snapshot is the one from before it, as the spell lines say. The reads, as the character sheet makes them: the level (UnitLevel); the
-- defense skill, base plus modifier and at least 0 (UnitDefenseSkill, UnitDocumentation.lua:1069-1084, the sheet's GetEffectiveDefenseSkill,
-- Camelot/PaperDollFrameStats.lua:52-55; UnitDefense on a client that has that name instead); the chances to dodge, parry and block against an
-- attacker of the player's level (GetDodgeChance, GetParryChance and GetBlockChance, PlayerScriptDocumentation.lua:414, 747, 275, as the sheet reads
-- them, Camelot/PaperDollFrame.lua:787-845); the effective armor, UnitArmor's second answer (UnitDocumentation.lua:645, as
-- Camelot/PaperDollFrameStats.lua:486-488 reads it); the block value (GetShieldBlock, PlayerScriptDocumentation.lua:1040), none without a shield
-- (C_PaperDollInfo.OffhandHasShield, PaperDollInfoDocumentation.lua:267-273); strength and agility, UnitStat's effective value that SpellModel read
-- in the same moment (its stats.stat); and the dodge a point of agility gives: GetDodgeChanceFromAttribute (PlayerScriptDocumentation.lua:424-432)
-- answers the dodge all of the effective agility adds, a fraction the sheet shows times 100 (Camelot/PaperDollFrameStats.lua:316), so a point gives
-- that times 100 over the agility.
--
-- The table: one roll of an enemy's melee swing, in this order, each row cut to what is left of 100%: missed, dodged, parried, blocked, critical,
-- crushing, and a normal hit for the rest. The attacker's weapon skill is 5 a level (SKILL_RANKS_PER_SKILL_LEVEL, Camelot/PaperDollFrameStats.lua:10,
-- 56-60) and its level the one Against names (chat.gearAgainst: a boss three levels above the player, an enemy of the player's level, or at its first
-- choice a boss from level 60 on and an enemy of the player's level before, as GearModel.lua's Spec maps it). The client's own sheet holds the rules
-- of three rows (Camelot/PaperDollFrameStats.lua:7-10, 46-82; its defense tooltip, :117-128, no longer shows them, but the functions are there):
-- missed is 5% + (defense - attacker skill) x 0.04% and critical 5% + (attacker skill - defense) x 0.04%, both kept between 0 and 100 (0 is immune:
-- "At 440 Defense, cannot be Critically Hit by Raid Bosses", DEFAULT_STATDEFENSE_TOOLTIP, GlobalStrings enUS.lua:5767); crushing is (attacker skill -
-- defense, at most 5 a level of the player's) x 2% - 15% from 15 skill on ("Creatures 3+ levels above you can land Crushing Blows", the same string),
-- so defense above the cap does not lower it, and defense below it raises it. Those three are not estimates. Two rules are Classic's and not in
-- Forever's client data, so a figure that rests on them is marked ~: an attacker above the player's level is dodged, parried and blocked 0.04% less
-- for each point of its skill above 5 a level of the player's (the sheet gives these chances against an attacker of the player's level only), and the
-- one roll that cuts each row to what is left (the sheet gives each chance alone), so a row cut that way is ~, and the normal hit is ~ whenever a row
-- above it is. Parry and block are 0 where the sheet gives 0 (no weapon, no shield). Crushing blows come from melee mobs; a boss that casts or shoots
-- rolls no such table.
--
-- With an item: the slots GearModel.lua's G.Candidates gives, the choice of slot the spell rows use. The stat change is the item's stats
-- (C_Item.GetItemStats, ItemDocumentation.lua:1004-1018, with the full link) less those of the items it replaces, each key turned into what it
-- changes by the data (SpellData.lua's D.STATS: avoid with its rating index, armor, and Strength and Agility): defense, dodge, parry and block rating
-- into defense points and percent with the client's own conversion, GetCombatRatingBonusForCombatRatingValue (PlayerScriptDocumentation.lua:335-349,
-- no secret mark) with CR_DEFENSE_SKILL 2, CR_DODGE 3, CR_PARRY 4 and CR_BLOCK 5 (Camelot/PaperDollFrame.lua:5-8); a point of defense also adds 0.04%
-- to dodge, parry and block (STAT_PER_DEFENSE, Camelot/PaperDollFrameStats.lua:348, 364, and the same string); agility adds dodge by the point read
-- above and 2 armor a point (ARMOR_PER_AGILITY, :6); the item's armor (RESISTANCE0_NAME, which holds its bonus armor too) adds armor, 2.8 and 4.6
-- times as much in Bear Form and Dire Bear Form, whose spells raise the armor of items by 180% and 360% (K.FORM_ARMOR), as the armor read in the form
-- holds it. The block value with the item is GearModel.lua's (G.With, for the spell rows that count it): the shield's own block, a block value stat
-- and a point a 20 Strength (BLOCK_VALUE_PER_STRENGTH, :2, 313); its state says whether a shield is worn with the item, and its form whether the
-- armor of items counts more. A shield put on where none is worn turns block on at Classic's 5% plus 0.04% a point of defense over the cap plus its
-- block rating (~); one taken off turns it off, and the block value with it. Where the client gives no conversion, that stat is named as not counted.
-- Stats the game refused or withheld for the item or one it replaces are never read as none: the item is not worked out, nor kept, until the game
-- gives them. Armor takes off what C_PaperDollInfo.GetArmorEffectiveness(armor, attacker level) gives, the client's own formula
-- (PaperDollInfoDocumentation.lua:56-70, which marks no secret answer; the sheet's PaperDollFrame_GetArmorReduction,
-- Camelot/PaperDollFrame.lua:2392-2393), asked at compare time with the snapshot's plain armor; with no answer, an item that changes armor names it
-- as not counted. A worn item (the Character window) is the table with it against the table with its slot empty (G.Without), so the change is what it
-- gives. A total that rests on an estimate is marked ~, its change is not: the change of a row the roll does not cut is the client's own sum.
--
-- Against (opts.base, an item link: the window's second item box, GearWindow.lua): each candidate's slot holds that item instead of what is worn,
-- where it goes (GearModel.lua's G.BaseSlots: the candidate's first slot, both hands for a two-hander), so the table with it is the candidate's now
-- and the change is the item instead of it; G.With puts it there as it puts the item. A worn item with Against: the table with that item in its
-- slot against the table now. The header then names it, from its link's own colour and name, else the game's name (C_Item.GetItemInfo,
-- ItemDocumentation.lua:626-657).
--
-- Damage taken (item 3 of the 0.5.20 brief), so one number says what the rows mean together: the expected damage of one enemy swing after the
-- table (missed, dodged and parried 0; blocked 1 - min(1, block value / the enemy's hit); critical 2; crushing 1.5; a normal hit 1), times what
-- armor leaves, as a share of a plain hit; with an item, its change is with / now - 1, negative being better. The enemy's hit before armor that block
-- value is measured against is the row Enemy hit for block value (chat.gearSwing, 1,500), an estimate, so a figure with a block is marked ~; so is
-- one where the game gave no armor reduction (armor then counts none). Crit 2 and crushing 1.5 are the brief's; the game's data does not show them.
--
-- A.Compare(link or slot, opts) gives { header, attacker, boss, now, base, candidates = { { label, slots, empty, offEmpty, game, notCounted, base,
-- baseSlots, taken, avoided, rows = { { key, label, now, with, nowEstimate, withEstimate, estimate, better } } } }, notCounted, why, quiet, old },
-- kept by the link (or the slot and the link worn there), base, M.Version(), the snapshot's version, the attacker's level and the enemy's hit, 64 at
-- most and the oldest first out; in a fight, the last result for the item and base, marked old. opts: data (the post call's, for its lines and guid),
-- guid and base. A.Totals(candidate) gives { taken = { now, with, pct, estimate }, avoided = { now, with } } (a candidate's taken and avoided are
-- these), A.Now() the table now, A.Wanted() whether avoidance shows (Avoidance, chat.gearAvoid, at Always, or at For tanks, its first choice, while
-- ns.PlayerRole's first answer is tank), A.TipLines and A.Window(link, base) the lines of GearLines.lua and the view of GearWindow.lua, and A.Stamp a
-- text that changes with what they are built from. The lines follow the one style of the spell and gear lines (SpellModel.lua's M.Fmt.Style, looked
-- up when they are built): a gold header only where more than one line follows, a double line a figure (the label light grey, the change green or
-- red with its sign, the total white, ~ before an estimate), and the notes dim, joined in one line at Compact (chat.tipDetail) and one a line at
-- Full; the table to two decimals, armor's share and damage taken to one, block value whole with commas.

local A = {}
ns.GearAvoid = A

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The constants of the file, in one table so its functions stay under the client's count of upvalues.
local K = {
	KEY = "chat",
	-- CR_DEFENSE_SKILL, CR_DODGE, CR_PARRY and CR_BLOCK (Camelot/PaperDollFrame.lua:5-8), and the words a stat with no conversion is named by.
	DEFENSE = 2, DODGE = 3, PARRY = 4, BLOCK = 5,
	RATING_NAMES = { [2] = "Defense", [3] = "Dodge", [4] = "Parry", [5] = "Block chance" },
	-- The sheet's rules (header): 5% to miss and to crit at an even skill, 0.04% a point, 5 skill a level, crushing from 15 skill at 2% a point less
	-- 15%, 2 armor a point of agility; and Classic's 5% block of a shield before defense.
	MISS = 5, CRIT = 5, PER_SKILL = 0.04, PER_LEVEL = 5, CRUSH_FROM = 15, CRUSH_PER = 2, CRUSH_LESS = 15, ARMOR_PER_AGILITY = 2, BASE_BLOCK = 5,
	-- Against: a boss three levels above the player, at its first choice from this level on (GearModel.lua, K.MAX_LEVEL).
	BOSS = 3, MAX_LEVEL = 60,
	-- What a point of an item's armor counts in Bear Form and Dire Bear Form (GetShapeshiftFormID 5 and 8, as GearModel.lua's K.FORMS has them):
	-- their spells raise the armor contribution from items by 180% and 360% (5487 and 9634, "Armor contribution from items by $1178s1%" and
	-- "$9635s1%", tools/dev/spelltips/client_spells.json:229, 445, which the game's tooltips of 1.60.1 show as 180% and 360%). UnitArmor's armor of
	-- the snapshot has it already, so an item's armor counts with it too.
	FORM_ARMOR = { [5] = 2.8, [8] = 4.6 },
	-- The results kept; the changes under which a row counts as none, half the last digit each shows (a hundredth of a percent for the table, a
	-- tenth for armor's share, a whole point of block value), so a change that shows as none is none.
	CACHE = 64, STILL = 0.005, STILL_ARMOR = 0.05, STILL_VALUE = 0.5,
	-- The rows, in the order of the roll, then armor and block value: key, the window's words, and whether more is better for the player.
	ROWS = {
		{ "missed", "Missed", true }, { "dodged", "Dodged", true }, { "parried", "Parried", true }, { "blocked", "Blocked", true },
		{ "crit", "Critical hit", false }, { "crush", "Crushing blow", false }, { "hit", "Normal hit", false },
		{ "armor", "Armor reduction", true }, { "blockValue", "Block value", true },
	},
	ROLL = { "missed", "dodged", "parried", "blocked", "crit", "crush" },
	AVOIDED = { "missed", "dodged", "parried", "blocked" },
	-- The reads of the snapshot that answer one number, by the field they fill.
	READS = { { "dodge", "GetDodgeChance" }, { "parry", "GetParryChance" }, { "block", "GetBlockChance" }, { "blockValue", "GetShieldBlock" },
		{ "fromAgility", "GetDodgeChanceFromAttribute" } },
	-- The slots by number (INVSLOT_AMMO to INVSLOT_TABARD), as GearModel.lua's K.LABEL names them.
	SLOTS = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
		"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" },
	-- The one style of the spell and gear lines is SpellModel.lua's (M.Fmt.Style); these stand in for a colour it does not have: the gold of a header
	-- (the client's NORMAL_FONT_COLOR, as ChatConfigFrame.lua:2048 reads it), the light grey of a label, the white of a value, the green and red of
	-- a change for the better and the worse (GREEN_FONT_COLOR, RED_FONT_COLOR), and the dim of a note, the hit table's (HitTable.lua:79).
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, good = { 0.1, 1, 0.1 }, bad = { 1, 0.1, 0.1 },
		dim = { 0.66, 0.68, 0.62 } },
	-- Damage taken (A.Totals): one swing of the table after armor and block value as a share of a plain hit, a crit doing 2 hits and a crushing blow
	-- 1.5 (the 0.5.20 brief); block value measured against an enemy's hit before armor of chat.gearSwing (Enemy hit for block value: 200 to 6,000,
	-- 1,500 when it has none), an estimate. Its change shows to one decimal, so one under half of that is none.
	CRIT_TAKEN = 2, CRUSH_TAKEN = 1.5, SWING = 1500, SWING_LEAST = 200, SWING_MOST = 6000, STILL_TAKEN = 0.05,
	TAKEN_ROWS = { "missed", "dodged", "parried", "blocked", "crit", "crush", "hit" },
}

-- The words, English as all of Flat UI's lines are.
local T = {
	HEADER = "Avoidance against %s (level %d)",
	GIVES = "What it gives your avoidance against %s (level %d)",
	HEADER_BASE = "Avoidance against %s (level %d), instead of %s",
	GIVES_BASE = "What it gives your avoidance against %s (level %d) instead of %s",
	BOSS = "a boss",
	LEVEL = "an enemy of your level",
	TAKEN = "Damage taken",
	OF_A_HIT = "%s of a hit",
	CRIT_AT = "Immune to critical hits at %s defense",
	CRIT_NOW = "Immune to critical hits (from %s defense)",
	CRUSH_STOP = "Crushing blows stop at 100% missed, dodged, parried or blocked",
	TAKEN_NOTE = "Damage taken: one swing after the table and armor as a share of a plain hit, block value against a %s hit (an estimate)",
	THAT_ITEM = "that item",
	BASE_SLOT = "It does not go in the same slot as %s.",
	NONE = "none",
	NO_CHANGE = "No change to your chosen spells; stamina and mana are not counted.",
	NO_CHANGE_ALL = "No change to your chosen spells or your avoidance; stamina and mana are not counted.",
	NO_CONVERSION = "%s rating (the game gave no conversion for it)",
	NO_AGILITY = "Dodge from agility (the game gave none)",
	NO_ARMOR = "Armor (the game gave no armor reduction)",
	NO_MODEL = "The gear comparison has no spell data.",
	NO_ITEM = "No item to compare.",
	NO_STATS = "The game has not given your stats yet.",
	NO_DEFENSE = "The game gave no defense skill, so there is no attack table to work out.",
	WITHHELD = "The game withheld the stats of an item, so its avoidance is not worked out.",
	COMBAT = "Gear lines show out of combat.",
	EMPTY = "That slot is empty.",
	HEAD = "An enemy's swing",
	FOOT_AGAINST = "Against %s (level %d), in front of it: one roll of miss, dodge, parry, block, crit and crushing blow of its melee swing.",
	FOOT_BOSS = "a boss three levels above you",
	FOOT_SHEET = "Your defense, dodge, parry, block, armor and block value as your character sheet gives them, ratings as the game converts them.",
	FOOT_LEFT = "Not counted: talents and buffs your stats do not show, spells, and ranged attacks.",
	FOOT_ESTIMATE = "~ marks an estimate: Classic's rules where the game's data does not show them.",
	NOT_COUNTED = "Not counted: ",
	NOT_COUNTED_TIP = "Not counted in avoidance: ",
	FOOT_TAKEN = "Damage taken: one swing's expected damage after the table, armor and block value as a share of a plain hit (a crit 2, a crushing "
		.. "blow 1.5), block value against an enemy's hit of %s before armor (Enemy hit for block value, an estimate); its change is relative.",
	STATUS = "Avoidance against %s: missed %s, dodged %s, parried %s, blocked %s, crit %s, crushing %s; damage taken %s of a hit.",
	STATUS_OLD = " From before the fight.",
	STATUS_NONE = "Avoidance: your stats were not read yet.",
	STATUS_NO_DEFENSE = "Avoidance: the game gave no defense skill, so there is no attack table to work out.",
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

-- A global function of the client, or one of its tables', or nil when the client has none.
local function Global(name)
	local fn = Field(_G, name)
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Api(space, name)
	local fn = Field(Field(_G, space), name)
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Pack(ok, ...)
	return ok, select("#", ...), { ... }
end

-- The answers of a call of the game as a list, or nil and why: "missing" (no such function), "refused" (it raised) or "withheld" (a secret answer).
local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil, "missing"
	end
	local ok, count, answers = Pack(pcall(fn, ...))
	if not ok then
		return nil, "refused"
	end
	for index = 1, count do
		if IsSecret(answers[index]) then
			return nil, "withheld"
		end
	end
	return answers
end

-- One answer of a call for the snapshot: a number, nil for none (a missing call or no number), or false when the game withheld it.
local function First(fn, at, ...)
	local answers, why = Call(fn, ...)
	if answers then
		return Num(answers[at])
	elseif why == "missing" then
		return nil
	end
	return false
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

local function Model()
	local M = ns.SpellModel
	if type(M) == "table" then
		return M
	end
	return nil
end

local function Gear()
	local G = ns.GearModel
	if type(G) == "table" and type(G.Candidates) == "function" and type(G.With) == "function" and type(G.Without) == "function"
		and type(G.BaseSlots) == "function" then
		return G
	end
	return nil
end

-- A fight, as InCombatLockdown answers; a withheld answer counts as one.
local function InCombat()
	local answers, why = Call(Global("InCombatLockdown"))
	if not answers then
		return why ~= "missing"
	end
	return answers[1] == true
end

local function Copy(t)
	local out = {}
	for key, value in pairs(t) do
		out[key] = value
	end
	return out
end

local function AddOnce(list, text)
	for _, have in ipairs(list) do
		if have == text then
			return
		end
	end
	list[#list + 1] = text
end

local function LinkAt(state, slot)
	return Text(Field(Field(state, "links"), slot))
end

-- The snapshot ----------------------------------------------------------------------------------------------------------------------------------

-- version changes with each snapshot that differs from the last; cache, kept and last hold the results (A.Compare), now the table now (A.Now).
local held = { registered = false, snap = nil, version = 0, cache = {}, kept = {}, last = {}, now = nil, nowKey = nil }

-- The snapshot of the defensive stats (header), or nil when the game withheld one of them. stats: SpellModel's of the same moment.
local function ReadSnapshot(stats)
	local s = {}
	local level = First(Global("UnitLevel"), 1, "player")
	local answers, why = Call(Global("UnitDefenseSkill") or Global("UnitDefense"), "player")
	if level == false or (not answers and why ~= "missing") then
		return nil
	end
	s.level = level
	local base, modifier = answers and Num(answers[1]), answers and Num(answers[2])
	s.defense = base and math.max(0, base + (modifier or 0)) or nil
	for _, read in ipairs(K.READS) do
		local value = First(Global(read[2]), 1)
		if value == false then
			return nil
		end
		s[read[1]] = value
	end
	local armor = First(Global("UnitArmor"), 2, "player")
	if armor == false then
		return nil
	end
	s.armor = armor
	answers = Call(Api("C_PaperDollInfo", "OffhandHasShield"))
	if answers and type(answers[1]) == "boolean" then
		s.shield = answers[1]
	else
		s.shield = (s.block or 0) > 0
	end
	if not s.shield then
		s.block, s.blockValue = 0, nil
	end
	local stat = Field(stats, "stat")
	s.strength, s.agility = Num(Field(stat, 1)), Num(Field(stat, 2))
	if s.fromAgility and s.agility and s.agility > 0 then
		s.perAgility = s.fromAgility * 100 / s.agility
	end
	return s
end

local function Same(a, b)
	if not (a and b) then
		return false
	end
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Called by SpellModel.lua right after each plain read of the stats, in the same frame (M.AfterRead), which catches and reports a fault here.
local function AfterRead(stats)
	local s = ReadSnapshot(stats)
	if s and not Same(held.snap, s) then
		held.snap, held.version = s, held.version + 1
	end
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

-- The snapshot of the last plain read. With none yet (this file registered after SpellModel's last read), SpellModel is asked to read the stats again
-- (M.Mark, M.Stats), which runs AfterRead in that plain moment; the defensive stats are never read at another moment than SpellModel's.
local function Snapshot()
	Register()
	local M = not held.snap and Model() or nil
	if M then
		Ask(M.Mark, "stats")
		Ask(M.Stats)
	end
	return held.snap
end

-- The level of the enemy Against names, and whether it is a boss (header; GearModel.lua's Spec).
local function Attacker(level)
	local against = ns.Get("chat.gearAgainst") or "auto"
	if against == "auto" then
		against = level >= K.MAX_LEVEL and "boss" or "level"
	end
	if against == "boss" then
		return level + K.BOSS, true
	end
	return level, false
end

-- The size of an enemy's hit before armor that block value is measured against (chat.gearSwing, Enemy hit for block value), between its bounds.
local function Swing()
	local value = Num(ns.Get("chat.gearSwing"))
	if value and value >= K.SWING_LEAST then
		return math.min(value, K.SWING_MOST)
	end
	return K.SWING
end

-- The name of the item compared against (Against, opts.base) in its quality's colour, from its link's own colour and name, else the game's name of
-- it (C_Item.GetItemInfo), else words.
local function BaseName(link)
	local colour, name = link:match("^|c(%x%x%x%x%x%x%x%x)"), link:match("|h%[(.-)%]|h")
	if not name then
		local answers = Call(Api("C_Item", "GetItemInfo"), link)
		name = answers and Text(answers[1])
	end
	if not name then
		return T.THAT_ITEM
	end
	return colour and ("|c" .. colour .. name .. "|r") or name
end

-- The table -------------------------------------------------------------------------------------------------------------------------------------

local function Clamp(value)
	return math.max(0, math.min(100, value))
end

-- The share of physical damage armor takes off against an attacker of a level, in percent (C_PaperDollInfo.GetArmorEffectiveness), or nil.
local function ArmorPct(armor, attacker)
	if not armor then
		return nil
	end
	local answers = Call(Api("C_PaperDollInfo", "GetArmorEffectiveness"), math.max(0, armor), attacker)
	local value = answers and Num(answers[1])
	return value and value * 100 or nil
end

-- The table of an enemy of the attacker's level against a snapshot (header): each row in percent, armor's share and the block value, which rows are
-- estimates, and the defense from which the player is immune to its crits.
local function Work(s, attacker)
	local cap, skill = s.level * K.PER_LEVEL, attacker * K.PER_LEVEL
	local diff, fall = skill - s.defense, (skill - cap) * K.PER_SKILL
	local raw = {
		missed = Clamp(K.MISS - diff * K.PER_SKILL),
		dodged = math.max(0, (s.dodge or 0) - fall),
		parried = (s.parry or 0) > 0 and math.max(0, s.parry - fall) or 0,
		blocked = (s.block or 0) > 0 and math.max(0, s.block - fall) or 0,
		crit = Clamp(K.CRIT + diff * K.PER_SKILL),
	}
	local crushing = skill - math.min(s.defense, cap)
	raw.crush = crushing >= K.CRUSH_FROM and Clamp(crushing * K.CRUSH_PER - K.CRUSH_LESS) or 0
	local t = { attacker = attacker, estimate = {}, immuneAt = skill + K.CRIT / K.PER_SKILL }
	local est = t.estimate
	est.dodged = fall ~= 0 and (s.dodge or 0) > 0
	est.parried = fall ~= 0 and (s.parry or 0) > 0
	est.blocked = (fall ~= 0 and (s.block or 0) > 0) or s.guess == true
	local left, any = 100, false
	for _, key in ipairs(K.ROLL) do
		local got = math.min(raw[key], left)
		if got < raw[key] - 1e-9 then
			est[key] = true
		end
		t[key], left = got, left - got
		any = any or est[key] == true
	end
	t.hit, est.hit = left, any
	t.armor = ArmorPct(s.armor, attacker)
	t.blockValue = s.shield and s.blockValue or nil
	return t
end

-- The percent a rating gives the player, with its sign (GetCombatRatingBonusForCombatRatingValue; for defense, points), or nil with no conversion:
-- no call, no number, or none for a rating the item has, which is a client that does not convert that rating, not a stat worth nothing.
local function Rating(rating, amount)
	local sign, value = amount < 0 and -1 or 1, math.abs(amount)
	local answers = Call(Global("GetCombatRatingBonusForCombatRatingValue"), rating, value)
	local got = answers and Num(answers[1])
	return got and got > 0 and sign * got or nil
end

-- The stats of an item by the game's keys (C_Item.GetItemStats), each a plain number: empty for none (no item, no such call, no stats), nil when the
-- game refused or withheld them, which says nothing of the item's stats.
local function ItemStats(link)
	local out = {}
	if not link then
		return out
	end
	local answers, why = Call(Api("C_Item", "GetItemStats"), link)
	if not answers then
		return why == "missing" and out or nil
	end
	local got = Table(answers[1])
	if got then
		for key, value in pairs(got) do
			if Text(key) and Finite(value) then
				out[key] = value
			end
		end
	end
	return out
end

-- The item's stats less those of the items worn in the slots (link nil: the slots emptied), or nil when the game withheld the stats of one of them.
local function Delta(link, slots, state)
	local delta = ItemStats(link)
	for _, slot in ipairs(slots) do
		local worn = ItemStats(LinkAt(state, slot))
		if not (delta and worn) then
			return nil
		end
		for key, value in pairs(worn) do
			delta[key] = (delta[key] or 0) - value
		end
	end
	return delta
end

-- The snapshot with a stat change (header): delta by the game's keys; state2 and stats2 as G.With or G.Without gave them, for the shield and its block
-- value; notes gets the stats the client gave no conversion for.
local function Apply(s, delta, state2, stats2, notes)
	local D = ns.SpellData
	local defs = Table(D and D.STATS) or {}
	local ratings, agility, armor = {}, 0, 0
	local share = K.FORM_ARMOR[Num(Field(state2, "form")) or 0] or 1
	for key, amount in pairs(delta) do
		local def = Table(defs[key])
		local kind = def and def[1]
		if amount ~= 0 and kind == "avoid" and Num(def[2]) then
			ratings[def[2]] = (ratings[def[2]] or 0) + amount
		elseif amount ~= 0 and kind == "armor" then
			armor = armor + amount * share
		elseif amount ~= 0 and kind == "stat" and def[2] == 2 then
			agility = agility + amount
		end
	end
	-- The ratings in the order of their index, so the notes read the same each time.
	local pct = {}
	for rating = K.DEFENSE, K.BLOCK do
		local amount = ratings[rating]
		if amount and amount ~= 0 then
			pct[rating] = Rating(rating, amount)
			if not pct[rating] then
				AddOnce(notes, T.NO_CONVERSION:format(K.RATING_NAMES[rating] or "A"))
			end
		end
	end
	local w = Copy(s)
	local defense = pct[K.DEFENSE] or 0
	local side, dodge = defense * K.PER_SKILL, 0
	w.defense = s.defense + defense
	if agility ~= 0 then
		if s.perAgility then
			dodge = agility * s.perAgility
		else
			AddOnce(notes, T.NO_AGILITY)
		end
		armor = armor + agility * K.ARMOR_PER_AGILITY
	end
	w.dodge = (s.dodge or 0) + side + dodge + (pct[K.DODGE] or 0)
	if (s.parry or 0) > 0 then
		w.parry = s.parry + side + (pct[K.PARRY] or 0)
	end
	w.armor = s.armor and s.armor + armor or nil
	local shield = Field(state2, "shield")
	if type(shield) ~= "boolean" then
		shield = s.shield
	end
	w.shield, w.guess = shield, nil
	if shield and s.shield then
		w.block = (s.block or 0) + side + (pct[K.BLOCK] or 0)
	elseif shield then
		w.block = math.max(0, K.BASE_BLOCK + (w.defense - s.level * K.PER_LEVEL) * K.PER_SKILL + (pct[K.BLOCK] or 0))
		w.guess = true
	else
		w.block = 0
	end
	w.blockValue = shield and Num(Field(stats2, "block")) or nil
	return w
end

-- The rows of a candidate: each now and with (with nil: the table now alone), whether each of the two is an estimate and whether either is, and
-- whether more is better.
local function Rows(now, with)
	local rows = {}
	for _, def in ipairs(K.ROWS) do
		local key = def[1]
		local nowEstimate, withEstimate = now.estimate[key] == true, with ~= nil and with.estimate[key] == true
		rows[#rows + 1] = { key = key, label = def[2], better = def[3], now = now[key], with = with and with[key], nowEstimate = nowEstimate,
			withEstimate = withEstimate, estimate = nowEstimate or withEstimate }
	end
	return rows
end

local function ByKey(rows)
	local out = {}
	for _, row in ipairs(rows) do
		out[row.key] = row
	end
	return out
end

-- One swing's expected damage as a share of a plain hit from one side of the rows ("now" or "with"), and whether it rests on an estimate: a row of the
-- roll that is one, a block (the size of an enemy's hit is chat.gearSwing's), or no armor reduction from the game. Nil when a row of the roll has no
-- figure there.
local function Taken(by, side, swing)
	local at, estimate = {}, false
	for _, key in ipairs(K.TAKEN_ROWS) do
		local row = by[key]
		at[key] = row and Num(row[side])
		if not at[key] then
			return nil
		end
		estimate = estimate or row[side .. "Estimate"] == true
	end
	local share = 0
	if at.blocked > 0 then
		local value = Num(by.blockValue and by.blockValue[side])
		share = value and math.min(1, math.max(0, value) / swing) or 0
		estimate = true
	end
	local armor = Num(by.armor and by.armor[side])
	estimate = estimate or armor == nil
	local hits = at.blocked * (1 - share) + at.crit * K.CRIT_TAKEN + at.crush * K.CRUSH_TAKEN + at.hit
	return hits / 100 * (1 - (armor or 0) / 100), estimate
end

-- What the rows of a candidate (A.Compare's) or of the table now (A.Now's) come to (item 3 of the 0.5.20 brief): { taken = { now, with, pct,
-- estimate, nowEstimate, withEstimate }, avoided = { now, with } }. taken is the expected damage of one enemy swing after the table (missed,
-- dodged and parried 0, blocked 1 - min(1, block value / chat.gearSwing), critical 2, crushing 1.5, a normal hit 1) times what armor leaves, as a
-- share of a plain hit (0.62 is 62%), and pct with / now - 1 as a fraction (negative is better); avoided is the share missed, dodged, parried or
-- blocked, in percent as the rows are. with and pct are nil with no item; an empty table when there are no rows.
function A.Totals(candidate)
	local out = {}
	local rows = Table(Field(candidate, "rows"))
	if not rows then
		return out
	end
	local by, swing = ByKey(rows), Swing()
	local now, nowEstimate = Taken(by, "now", swing)
	local with, withEstimate = Taken(by, "with", swing)
	if now then
		out.taken = { now = now, with = with, nowEstimate = nowEstimate, withEstimate = withEstimate == true,
			estimate = nowEstimate or withEstimate == true }
		if with and now > 0 then
			out.taken.pct = with / now - 1
		end
	end
	local avoided = {}
	for _, side in ipairs({ "now", "with" }) do
		local sum = 0
		for _, key in ipairs(K.AVOIDED) do
			local value = by[key] and Num(by[key][side])
			if not value then
				sum = nil
				break
			end
			sum = sum + value
		end
		avoided[side] = sum
	end
	out.avoided = avoided
	return out
end

-- A candidate with what its rows come to (A.Totals), as A.Compare's candidates carry it.
local function Carry(candidate)
	local totals = A.Totals(candidate)
	candidate.taken, candidate.avoided = totals.taken, totals.avoided
	return candidate
end

-- The table of a slot with a stat change (Apply, then Work); armor is named as not counted where it changes and the client gave no reduction.
local function Changed(s, delta, state2, stats2, notes, attacker)
	local w = Apply(s, delta, state2, stats2, notes)
	local t = Work(w, attacker)
	if not t.armor and w.armor ~= s.armor then
		AddOnce(notes, T.NO_ARMOR)
	end
	return t
end

-- The header of the block: against whom, and with Against the item compared against.
local function Header(boss, attacker, gives, base)
	local who = boss and T.BOSS or T.LEVEL
	if base then
		return (gives and T.GIVES_BASE or T.HEADER_BASE):format(who, attacker, BaseName(base))
	end
	return (gives and T.GIVES or T.HEADER):format(who, attacker)
end

-- The table with the item compared against (Against) in a candidate's slots, the now of that candidate: G.With put it there (its fourth and fifth
-- answers) and info.baseSlots says which slots it took; nil when the game withheld the stats of it or of what it replaces.
local function BaseTable(s, base, state, stateB, statsB, info, notes, attacker)
	local baseSlots = Table(Field(info, "baseSlots"))
	local delta = stateB and baseSlots and Delta(base, baseSlots, state)
	if not delta then
		return nil
	end
	return Changed(s, delta, stateB, statsB, notes, attacker)
end

-- An item to wear: each slot G.Candidates gives, the table with the item there, against the table now or with Against (base) against the table with
-- that item in the candidate's slots (a candidate where it does not go is left out, G.BaseSlots). False when nothing should be kept: no slot to
-- compare with, which may be an item the client has not loaded yet, or an item G.With could not read, so the next ask works it out again.
local function Instead(result, link, opts, state, stats, s, now)
	local G = Gear()
	local data = Table(opts.data)
	local lines = Table(Field(data, "lines"))
	local base = Text(opts.base)
	local list, why, quiet = G.Candidates(link, Text(Field(data, "guid")) or Text(opts.guid), lines)
	if not Table(list) then
		result.why, result.quiet = Text(why), quiet == true
		return false
	end
	for _, c in ipairs(list) do
		if not base or Table(Ask(G.BaseSlots, base, c)) then
			local state2, stats2, info, stateB, statsB = G.With(state, stats, link, c, lines, base and { base = base } or nil)
			local delta = state2 and Delta(link, c.slots, state)
			local notes = {}
			local before = now
			if delta and base then
				before = BaseTable(s, base, state, stateB, statsB, info, notes, result.attacker)
			end
			if not (delta and before) then
				result.candidates = {}
				result.why = state2 and T.WITHHELD or Text(Field(info, "why"))
				result.quiet = not state2 and Field(info, "quiet") == true
				return false
			end
			local with = Changed(s, delta, state2, stats2, notes, result.attacker)
			result.candidates[#result.candidates + 1] = Carry({ label = c.label, slots = c.slots, empty = c.empty, offEmpty = c.offEmpty,
				game = c.game, notCounted = notes, rows = Rows(before, with), base = base, baseSlots = base and Field(info, "baseSlots") or nil })
			for _, text in ipairs(notes) do
				AddOnce(result.notCounted, text)
			end
		end
	end
	if base and #result.candidates == 0 then
		result.why, result.quiet = T.BASE_SLOT:format(BaseName(base)), false
		return true
	end
	result.header = Header(result.boss, result.attacker, false, base)
	return true
end

-- A worn item: the table with its slot empty against the table now, so the change is what it gives; with Against (base), the table with that item
-- in its slot (G.With with it as the item, in the slots G.BaseSlots gives: a two-hander takes both hands) against the table now.
local function Gives(result, slot, state, stats, s, now, base)
	local G = Gear()
	if not LinkAt(state, slot) then
		result.why, result.quiet = T.EMPTY, true
		return true
	end
	local notes, before = {}, nil
	if base then
		local baseSlots = Table(Ask(G.BaseSlots, base, { slots = { slot } }))
		if not baseSlots then
			result.why, result.quiet = T.BASE_SLOT:format(BaseName(base)), false
			return true
		end
		local stateB, statsB, info = G.With(state, stats, base, { slots = baseSlots }, nil)
		local delta = stateB and Delta(base, baseSlots, state)
		if not delta then
			result.why, result.quiet = stateB and T.WITHHELD or Text(Field(info, "why")), false
			return false
		end
		before = Changed(s, delta, stateB, statsB, notes, result.attacker)
	else
		local state2, stats2, info = G.Without(state, stats, slot)
		local delta = state2 and Delta(nil, { slot }, state)
		if not delta then
			result.why, result.quiet = state2 and T.WITHHELD or Text(Field(info, "why")), true
			return false
		end
		before = Changed(s, delta, state2, stats2, notes, result.attacker)
	end
	result.candidates[1] = Carry({ label = K.SLOTS[slot], slots = { slot }, empty = false, game = true, notCounted = notes,
		rows = Rows(before, now), base = base })
	for _, text in ipairs(notes) do
		AddOnce(result.notCounted, text)
	end
	result.header = Header(result.boss, result.attacker, true, base)
	return true
end

-- Keeps a result, K.CACHE at most, the oldest forgotten first.
local function Remember(key, result)
	if held.cache[key] == nil then
		held.kept[#held.kept + 1] = key
		if #held.kept > K.CACHE then
			held.cache[table.remove(held.kept, 1)] = nil
		end
	end
	held.cache[key] = result
end

-- The comparison of an item to wear (its link) or of a worn item (its slot number) for avoidance (header).
function A.Compare(itemOrSlot, opts)
	opts = Table(opts) or {}
	local result = { candidates = {}, notCounted = {} }
	local M = Model()
	if not (M and Gear() and Table(ns.SpellData)) then
		result.why, result.quiet = T.NO_MODEL, true
		return result
	end
	local slot = Num(itemOrSlot)
	local link = not slot and Text(itemOrSlot) or nil
	if not (slot or link) then
		result.why, result.quiet = T.NO_ITEM, true
		return result
	end
	local state = Table(Ask(M.State)) or {}
	-- A worn item is kept by its slot and the link worn there, so a fight never shows what another item in that slot gave; with Against, by the item
	-- compared against too.
	local base = Text(opts.base)
	local subject = (slot and ("slot " .. slot .. " " .. (LinkAt(state, slot) or "")) or link) .. "|" .. (base or "")
	local stats = Table(Ask(M.Stats))
	result.base = base
	local s = Snapshot()
	if InCombat() or (stats and stats.old == true) then
		local before = held.last[subject]
		if before then
			local copy = Copy(before)
			copy.old = true
			return copy
		end
		result.why = T.COMBAT
		return result
	elseif not (stats and s) then
		result.why = T.NO_STATS
		return result
	elseif not (s.defense and s.level) then
		result.why, result.quiet = T.NO_DEFENSE, true
		return result
	end
	local attacker, boss = Attacker(s.level)
	local key = table.concat({ subject, tostring(Ask(M.Version)), held.version, attacker, Swing() }, "|")
	if held.cache[key] then
		return held.cache[key]
	end
	result.attacker, result.boss = attacker, boss
	local now = Work(s, attacker)
	result.now = now
	local keep
	if slot then
		keep = Gives(result, slot, state, stats, s, now, base)
	else
		keep = Instead(result, link, opts, state, stats, s, now)
	end
	if keep then
		Remember(key, result)
		held.last[subject] = result
	end
	return result
end

-- The table now against the enemy Against names: { attacker, boss, table, rows (as A.Compare's, with nil), taken, avoided (A.Totals'), old }, or nil
-- and why.
function A.Now()
	local s = Snapshot()
	if not s then
		return nil, T.NO_STATS
	elseif not (s.defense and s.level) then
		return nil, T.NO_DEFENSE
	end
	local attacker, boss = Attacker(s.level)
	local key = held.version .. "|" .. attacker .. "|" .. Swing()
	if not (held.now and held.nowKey == key) then
		local now = Work(s, attacker)
		held.now, held.nowKey = Carry({ attacker = attacker, boss = boss, table = now, rows = Rows(now, nil) }), key
	end
	local M = Model()
	local stats = M and Table(Ask(M.Stats))
	held.now.old = InCombat() or (stats ~= nil and stats.old == true)
	return held.now
end

-- Whether avoidance shows: Avoidance (chat.gearAvoid) at Always, or at For tanks while ns.PlayerRole's first answer is tank.
function A.Wanted()
	local choice = ns.Get("chat.gearAvoid")
	if choice == "on" then
		return true
	elseif choice == "off" then
		return false
	end
	local ok, role = pcall(ns.PlayerRole)
	return ok and Text(role) == "tank"
end

-- A text that changes with what the lines and the view are built from: the snapshot, whether avoidance shows, Against, the enemy's hit for block
-- value and how much the tooltips say (chat.tipDetail).
function A.Stamp()
	return table.concat({ held.version, A.Wanted() and "on" or "off", tostring(ns.Get("chat.gearAgainst")), Swing(),
		tostring(ns.Get("chat.tipDetail")) }, "|")
end

-- Text -------------------------------------------------------------------------------------------------------------------------------------------

-- A colour of the style as { r, g, b }, from a list or the fields r, g and b (a colour of the client's), or nil.
local function Colour(value)
	local t = Table(value)
	if not t then
		return nil
	end
	local r, g, b = Num(Field(t, 1)) or Num(Field(t, "r")), Num(Field(t, 2)) or Num(Field(t, "g")), Num(Field(t, 3)) or Num(Field(t, "b"))
	if r and g and b then
		return { r, g, b }
	end
	return nil
end

-- The colours of the lines: SpellModel.lua's one style of the spell and gear lines (M.Fmt.Style), looked up when the lines are built; K.STYLE stands
-- in for a colour it does not have.
local function Style()
	local M = Model()
	local style = Table(Field(Table(Field(M, "Fmt")), "Style"))
	local out = {}
	for name, fallback in pairs(K.STYLE) do
		out[name] = Colour(Field(style, name)) or fallback
	end
	return out
end

local function Hex(colour)
	return ("|cff%02x%02x%02x"):format(math.floor(colour[1] * 255 + 0.5), math.floor(colour[2] * 255 + 0.5), math.floor(colour[3] * 255 + 0.5))
end

-- A whole number with its thousands broken by commas, its minus kept.
local function Whole(value)
	local digits = ("%d"):format(math.floor(math.abs(value) + 0.5))
	local broken = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	broken = broken:gsub("^,", "")
	if value < 0 and broken ~= "0" then
		return "-" .. broken
	end
	return broken
end

-- A row's value in the style of the lines: two decimals for the table, one for armor's share and damage taken, whole with commas for block value;
-- a sign on a change only; "-" for none, "none" for a block value with no shield.
local function Value(row, value, signed)
	if not Finite(value) then
		return row.key == "blockValue" and T.NONE or "-"
	elseif row.key == "blockValue" then
		local text = Whole(value)
		if signed and math.floor(value + 0.5) > 0 then
			text = "+" .. text
		end
		return text
	elseif row.key == "armor" or row.key == "taken" then
		return (signed and "%+.1f%%" or "%.1f%%"):format(value)
	end
	return (signed and "%+.2f%%" or "%.2f%%"):format(value)
end

local function Still(row)
	return row.key == "armor" and K.STILL_ARMOR or row.key == "blockValue" and K.STILL_VALUE or row.key == "taken" and K.STILL_TAKEN or K.STILL
end

-- The change of a row (a block value or armor share none is 0; damage taken's relative, in percent of now), and its tone: "gain" when better for
-- the player, "loss" when worse, else "none".
local function Change(row, with)
	local now = Num(row.now)
	with = Num(with)
	local delta
	if row.key == "taken" then
		if not (now and with and now > 0) then
			return nil, "none"
		end
		delta = (with / now - 1) * 100
	elseif now == nil and with == nil then
		return nil, "none"
	else
		delta = (with or 0) - (now or 0)
	end
	if math.abs(delta) < Still(row) then
		return delta, "none"
	end
	return delta, ((delta > 0) == (row.better == true)) and "gain" or "loss"
end

-- A row's value now or with the item, ~ first when it rests on an estimate (header); a change of the table is not marked, since the change of a row
-- the roll does not cut is the client's own sum, but damage taken's is, since an estimate is in both of its sides.
local function Total(row, now)
	if now then
		return (row.nowEstimate and "~" or "") .. Value(row, row.now)
	end
	return (row.withEstimate and "~" or "") .. Value(row, row.with)
end

-- Damage taken (A.Totals) as a row of the lines and the window: in percent of a plain hit, lower being better.
local function TakenRow(taken)
	if not Table(taken) then
		return nil
	end
	local function Share(value)
		return Num(value) and value * 100 or nil
	end
	return { key = "taken", label = T.TAKEN, better = false, now = Share(taken.now), with = Share(taken.with), nowEstimate = taken.nowEstimate == true,
		withEstimate = taken.withEstimate == true, estimate = taken.estimate == true }
end

-- A figure of the tooltip as GearLines.lua adds it with AddDoubleLine: its label left in the style's label colour, its value right in white, the
-- change first in the colour of its direction, its sign saying the same, and the total after it; key is its row's, so GearLines.lua can leave out
-- Damage taken where its Overall line says it already.
local function Double(style, row, delta, tone, total)
	local change = Value(row, delta, true)
	if row.key == "taken" and row.estimate then
		change = "~" .. change
	end
	local right = Hex(tone == "gain" and style.good or style.bad) .. change .. "|r  " .. Hex(style.value) .. "(" .. total .. ")|r"
	return { key = row.key, left = row.label, right = right, colour = style.value, leftColour = style.label, text = row.label .. "  " .. right }
end

-- The figures of a candidate that change, in the order of damage taken, the roll, armor and block value, and the notes of the figures whose
-- meaning wants one (damage taken, critical immunity, crushing blows).
local function Figures(rows, attacker, taken, style)
	local by, figures, notes = ByKey(rows), {}, {}
	local takenRow = TakenRow(taken)
	if takenRow then
		local delta, tone = Change(takenRow, takenRow.with)
		if tone ~= "none" then
			local total = T.OF_A_HIT:format(Total(takenRow))
			figures[#figures + 1] = Double(style, takenRow, delta, tone, total)
			notes[#notes + 1] = T.TAKEN_NOTE:format(Whole(Swing()))
		end
	end
	for _, def in ipairs(K.ROWS) do
		local row = by[def[1]]
		local delta, tone
		if row and row.key ~= "hit" then
			delta, tone = Change(row, row.with)
		end
		if tone == "gain" or tone == "loss" then
			figures[#figures + 1] = Double(style, row, delta, tone, Total(row))
			if row.key == "crit" then
				local immuneAt = Whole(attacker * K.PER_LEVEL + K.CRIT / K.PER_SKILL)
				notes[#notes + 1] = ((Num(row.with) or 0) <= 0 and T.CRIT_NOW or T.CRIT_AT):format(immuneAt)
			elseif row.key == "crush" then
				notes[#notes + 1] = T.CRUSH_STOP
			end
		end
	end
	return figures, notes
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

-- The lines of the item tooltip block (GearLines.lua), for the candidate whose slots the spell rows show, else the first, in the one style of the
-- spell and gear lines (the 0.5.20 brief, item 2): a gold header (against whom) only where more than one line follows; a double line for each
-- figure that changes (damage taken, missed, dodged, parried, blocked, critical, crushing, armor reduction, block value: the label left, the change
-- in green or red and the total in white right, ~ before an estimate); and the notes, dim and wrapped: in Compact (chat.tipDetail) one line of them
-- joined with "; ", in Full one line each. Entries as GearLines.lua adds them: { text, colour, wrap } (header = true on the header, note = true on
-- a note) and { key, left, right, colour, leftColour, text } for a figure (key its row's, colour the right's, text both together for a caller that
-- adds one line). The second answer is the words of the spell rows' "no change" line while avoidance shows. A stat not counted is named also when
-- nothing else changes, so "no change to your avoidance" is said only when all of the item was counted. Nil while avoidance does not show or has
-- nothing to say.
function A.TipLines(subject, slots, opts)
	if not A.Wanted() then
		return nil
	end
	local result = A.Compare(subject, opts)
	local chosen = result.candidates[1]
	for _, c in ipairs(result.candidates) do
		if SameSlots(c.slots, slots) then
			chosen = c
			break
		end
	end
	if not (chosen and result.attacker) then
		return nil
	end
	local style, notCounted = Style(), chosen.notCounted or {}
	local figures, hints = Figures(chosen.rows, result.attacker, chosen.taken, style)
	if #figures == 0 and #notCounted == 0 then
		return {}, T.NO_CHANGE_ALL
	end
	-- What is not counted first, since it says what the figures leave out, then the figures' notes.
	local notes = {}
	if ns.Get("chat.tipDetail") == "full" then
		for _, text in ipairs(notCounted) do
			notes[#notes + 1] = T.NOT_COUNTED_TIP .. text
		end
		for _, text in ipairs(hints) do
			notes[#notes + 1] = text
		end
	else
		local joined = {}
		if #notCounted > 0 then
			joined[1] = T.NOT_COUNTED_TIP .. table.concat(notCounted, ", ")
		end
		for _, text in ipairs(hints) do
			joined[#joined + 1] = text
		end
		if #joined > 0 then
			notes[1] = table.concat(joined, "; ")
		end
	end
	local noteLines = {}
	for _, text in ipairs(notes) do
		noteLines[#noteLines + 1] = { text = text, colour = style.dim, wrap = true, note = true }
	end
	local lines = {}
	if #figures + #noteLines > 1 then
		lines[1] = { text = result.header, colour = style.header, wrap = true, header = true }
	end
	for _, entry in ipairs(figures) do
		lines[#lines + 1] = entry
	end
	for _, entry in ipairs(noteLines) do
		lines[#lines + 1] = entry
	end
	return lines, T.NO_CHANGE
end

-- The window -------------------------------------------------------------------------------------------------------------------------------------

-- A row of the window: its texts and tones by column (name, now, with, change1, change2), from the row of each slot compared (rows), with and the
-- changes only while an item is compared. Each slot's own row gives its change, so a with of none (a block value with the shield taken off) has
-- one too.
local function WindowRow(rows, compared)
	local first = rows[1]
	local texts, tones = { name = first.label, now = Total(first, true) }, {}
	if compared then
		texts.with = Total(first)
		for index, row in ipairs(rows) do
			local delta, tone = Change(row, row.with)
			local column = "change" .. index
			-- A change under the last digit shown is none, never "-0.00%".
			local text = delta and Value(row, tone == "none" and 0 or delta, true) or "-"
			if delta and row.key == "taken" and row.estimate then
				text = "~" .. text
			end
			texts[column], tones[column] = text, tone
		end
	end
	return { texts = texts, tones = tones }
end

-- A candidate's rows for the window: damage taken first (A.Totals), then the table, armor and block value.
local function WindowRows(c)
	local rows, taken = {}, TakenRow(c.taken)
	if taken then
		rows[1] = taken
	end
	for _, row in ipairs(c.rows) do
		rows[#rows + 1] = row
	end
	return rows
end

-- The Avoidance view of the Gear comparison window (GearWindow.lua): { layout, cands, rows = { { texts, tones } }, heads, foot, notes, why, base },
-- with an item the table in each slot it can take (the first two), else the table now; damage taken is the first row. base (Against, an item
-- link): the item set against it in those slots (A.Compare's opts.base), else what is worn.
function A.Window(link, base)
	base = Text(base)
	local view = { layout = "none", cands = {}, rows = {}, notes = {}, heads = { name = T.HEAD }, foot = {}, base = base }
	local now, why = A.Now()
	local attacker, boss = now and now.attacker, now and now.boss
	if link then
		local result = A.Compare(link, { base = base })
		for _, c in ipairs(result.candidates) do
			if #view.cands < 2 then
				view.cands[#view.cands + 1] = c
			end
		end
		view.why = Text(result.why)
		for _, text in ipairs(result.notCounted) do
			view.notes[#view.notes + 1] = T.NOT_COUNTED .. text
		end
		attacker, boss = result.attacker or attacker, result.boss
		if boss == nil and now then
			boss = now.boss
		end
	end
	if #view.cands > 0 then
		view.layout = #view.cands == 2 and "two" or "one"
		-- A row of each slot by its key, so damage taken one slot has and the other lacks shows for neither rather than beside another row.
		local lists = {}
		for which, c in ipairs(view.cands) do
			lists[which] = WindowRows(c)
		end
		for _, first in ipairs(lists[1]) do
			local rows = { first }
			for which = 2, #lists do
				for _, other in ipairs(lists[which]) do
					if other.key == first.key then
						rows[which] = other
						break
					end
				end
			end
			if #rows == #lists then
				view.rows[#view.rows + 1] = WindowRow(rows, true)
			end
		end
	elseif now then
		for _, row in ipairs(WindowRows(now)) do
			view.rows[#view.rows + 1] = WindowRow({ row }, false)
		end
	else
		view.why = view.why or why
	end
	if attacker then
		view.foot[1] = T.FOOT_AGAINST:format(boss and T.FOOT_BOSS or T.LEVEL, attacker)
	end
	view.foot[#view.foot + 1] = T.FOOT_SHEET
	view.foot[#view.foot + 1] = T.FOOT_TAKEN:format(Whole(Swing()))
	view.foot[#view.foot + 1] = T.FOOT_LEFT
	view.foot[#view.foot + 1] = T.FOOT_ESTIMATE
	return view
end

-- /flatui status --------------------------------------------------------------------------------------------------------------------------------

local function Short(value)
	local text = ("%.1f"):format(value)
	return (text:gsub("%.0$", "")) .. "%"
end

-- One line while avoidance shows: the table now against the enemy Against names, from the snapshot, said old in a fight.
local function Status()
	if not (ns.Enabled(K.KEY) and not ns.IsStopped(K.KEY) and A.Wanted()) then
		return {}
	end
	local now, why = A.Now()
	if not now then
		return { why == T.NO_DEFENSE and T.STATUS_NO_DEFENSE or T.STATUS_NONE }
	end
	local t, taken = now.table, now.taken
	local share = taken and Num(taken.now) and Short(taken.now * 100) or "-"
	if taken and taken.estimate then
		share = "~" .. share
	end
	local line = T.STATUS:format(now.boss and T.BOSS or T.LEVEL, Short(t.missed), Short(t.dodged), Short(t.parried), Short(t.blocked), Short(t.crit),
		Short(t.crush), share)
	if now.old then
		line = line .. T.STATUS_OLD
	end
	return { line }
end

if type(ns.AddStatus) == "function" then
	ns.AddStatus(K.KEY, Status)
end

-- The snapshot follows each read of the stats from the start of Chat and tooltips on, so the first tooltip has it.
if type(ns.AddStart) == "function" then
	ns.AddStart(K.KEY, Register)
end
