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
-- Camelot/PaperDollFrameStats.lua:51-54; UnitDefense on a client that has that name instead); the chances to dodge, parry and block against an
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
-- no secret mark) with CR_DEFENSE_SKILL 2, CR_DODGE 3, CR_PARRY 4 and CR_BLOCK 5 (Camelot/PaperDollFrame.lua:5-8); a point of defense also adds
-- 0.04% to dodge, parry and block (STAT_PER_DEFENSE, Camelot/PaperDollFrameStats.lua:348, 364, and the same string); agility adds dodge by the point
-- read above and 2 armor a point (ARMOR_PER_AGILITY, :6); the item's armor (RESISTANCE0_NAME, which holds its bonus armor too) adds armor. The block
-- value with the item is GearModel.lua's (G.With, for the spell rows that count it): the shield's own block, a block value stat and a point a 20
-- Strength (BLOCK_VALUE_PER_STRENGTH, :2, 313); its state says whether a shield is worn with the item. A shield put on where none is worn turns block
-- on at Classic's 5% plus 0.04% a point of defense over the cap plus its block rating (~); one taken off turns it off, and the block value with it.
-- Where the client gives no conversion, that stat is named as not counted. Armor takes off what C_PaperDollInfo.GetArmorEffectiveness(armor,
-- attacker level) gives, the client's own formula (PaperDollInfoDocumentation.lua:56-70, which marks no secret answer; the sheet's
-- PaperDollFrame_GetArmorReduction, Camelot/PaperDollFrame.lua:2392-2393), asked at compare time with the snapshot's plain armor; with no answer, an
-- item that changes armor names it as not counted. A worn item (the Character window) is the table with it against the table with its slot empty
-- (G.Without), so the change is what it gives. A total that rests on an estimate is marked ~, its change is not: the change of a row the roll does not
-- cut is the client's own sum.
--
-- A.Compare(link or slot, opts) gives { header, attacker, boss, now, candidates = { { label, slots, empty, offEmpty, game, notCounted, rows = { {
-- key, label, now, with, nowEstimate, withEstimate, estimate, better } } } }, notCounted, why, quiet, old }, kept by the link (or the slot and the
-- link worn there), M.Version(), the snapshot's version and the attacker's level, 64 at most and the oldest first out; in a fight, the last result
-- for the item, marked old. opts: data (the post call's, for its lines and guid) and guid. A.Now() gives the table now, A.Wanted() whether avoidance
-- shows (Avoidance, chat.gearAvoid, at Always, or at For tanks, its first choice, while ns.PlayerRole's first answer is tank), A.TipLines and
-- A.Window the lines of GearLines.lua and the view of GearWindow.lua, and A.Stamp a text that changes with what they are built from.

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
	-- The gear lines' colours (GearLines.lua): the grey of a header and white, and the gain and loss of Flat UI's combat numbers
	-- (CombatText.lua:889-894).
	GREY = { 0.8, 0.8, 0.8 }, WHITE = { 1, 1, 1 }, GAIN = { 0.1, 1, 0.1 }, LOSS = { 1, 0.1, 0.1 },
	-- The dim of the lines of what is not counted, the hit table's (HitTable.lua:79), as GearLines.lua has it.
	DIM = { 0.66, 0.68, 0.62 },
}

-- The words, English as all of Flat UI's lines are.
local T = {
	HEADER = "Avoidance against %s (level %d):",
	GIVES = "What it gives your avoidance against %s (level %d):",
	BOSS = "a boss",
	LEVEL = "an enemy of your level",
	CRIT = "Critical hits %s (%s; immune at %d defense)",
	CRIT_IMMUNE = "Critical hits %s (immune from %d defense)",
	CRUSH = "Crushing blows %s (%s; gone at 100%% avoided or blocked)",
	ARMOR_LESS = "Armor: %s less damage (%s)",
	ARMOR_MORE = "Armor: %s more damage (%s)",
	VALUE = "Block value %s (%s)",
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
	COMBAT = "Gear lines show out of combat.",
	EMPTY = "That slot is empty.",
	HEAD = "An enemy's swing",
	FOOT_AGAINST = "Against %s (level %d), in front of it: one roll of miss, dodge, parry, block, crit and crushing blow of its melee swing.",
	FOOT_BOSS = "a boss three levels above you",
	FOOT_SHEET = "Your defense, dodge, parry, block, armor and block value as your character sheet gives them, ratings as the game converts them.",
	FOOT_LEFT = "Not counted: talents and buffs your stats do not show, spells, and ranged attacks.",
	FOOT_ESTIMATE = "~ marks an estimate: Classic's rules where the game's data does not show them.",
	NOT_COUNTED = "Not counted: ",
	STATUS = "Avoidance against %s: missed %s, dodged %s, parried %s, blocked %s, crit %s, crushing %s.",
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
	if not answers then
		return why == "missing" and nil or false
	end
	return Num(answers[at])
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
	if type(G) == "table" and type(G.Candidates) == "function" and type(G.With) == "function" and type(G.Without) == "function" then
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

-- The percent a rating gives the player, with its sign (GetCombatRatingBonusForCombatRatingValue; for defense, points), or nil with no conversion.
local function Rating(rating, amount)
	local sign, value = amount < 0 and -1 or 1, math.abs(amount)
	local answers = Call(Global("GetCombatRatingBonusForCombatRatingValue"), rating, value)
	local got = answers and Num(answers[1])
	return got and sign * got or nil
end

-- The stats of an item by the game's keys (C_Item.GetItemStats), each a plain number; empty for none.
local function ItemStats(link)
	local out = {}
	local answers = link and Call(Api("C_Item", "GetItemStats"), link)
	local got = answers and Table(answers[1])
	if got then
		for key, value in pairs(got) do
			if Text(key) and Finite(value) then
				out[key] = value
			end
		end
	end
	return out
end

-- The item's stats less those of the items worn in the slots (link nil: the slots emptied).
local function Delta(link, slots, state)
	local delta = ItemStats(link)
	for _, slot in ipairs(slots) do
		for key, value in pairs(ItemStats(LinkAt(state, slot))) do
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
	for key, amount in pairs(delta) do
		local def = Table(defs[key])
		local kind = def and def[1]
		if amount ~= 0 and kind == "avoid" and Num(def[2]) then
			ratings[def[2]] = (ratings[def[2]] or 0) + amount
		elseif amount ~= 0 and kind == "armor" then
			armor = armor + amount
		elseif amount ~= 0 and kind == "stat" and def[2] == 2 then
			agility = agility + amount
		end
	end
	local pct = {}
	for rating, amount in pairs(ratings) do
		if amount ~= 0 then
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

-- The table of a slot with a stat change (Apply, then Work); armor is named as not counted where it changes and the client gave no reduction.
local function Changed(s, delta, state2, stats2, notes, attacker)
	local w = Apply(s, delta, state2, stats2, notes)
	local t = Work(w, attacker)
	if not t.armor and w.armor ~= s.armor then
		AddOnce(notes, T.NO_ARMOR)
	end
	return t
end

local function Header(boss, attacker, gives)
	return (gives and T.GIVES or T.HEADER):format(boss and T.BOSS or T.LEVEL, attacker)
end

-- An item to wear: each slot G.Candidates gives, the table with the item there. False when nothing should be kept (the item not loaded).
local function Instead(result, link, opts, state, stats, s, now)
	local G = Gear()
	local data = Table(opts.data)
	local lines = Table(Field(data, "lines"))
	local list, why, quiet = G.Candidates(link, Text(Field(data, "guid")) or Text(opts.guid), lines)
	if not Table(list) then
		result.why, result.quiet = Text(why), quiet == true
		return true
	end
	for _, c in ipairs(list) do
		local state2, stats2, info = G.With(state, stats, link, c, lines)
		if not state2 then
			result.candidates = {}
			result.why, result.quiet = Text(Field(info, "why")), Field(info, "quiet") == true
			return false
		end
		local notes = {}
		local with = Changed(s, Delta(link, c.slots, state), state2, stats2, notes, result.attacker)
		result.candidates[#result.candidates + 1] = { label = c.label, slots = c.slots, empty = c.empty, offEmpty = c.offEmpty, game = c.game,
			notCounted = notes, rows = Rows(now, with) }
		for _, text in ipairs(notes) do
			AddOnce(result.notCounted, text)
		end
	end
	result.header = Header(result.boss, result.attacker, false)
	return true
end

-- A worn item: the table with its slot empty against the table now, so the change is what it gives.
local function Gives(result, slot, state, stats, s, now)
	local G = Gear()
	if not LinkAt(state, slot) then
		result.why, result.quiet = T.EMPTY, true
		return true
	end
	local state2, stats2, info = G.Without(state, stats, slot)
	if not state2 then
		result.why, result.quiet = Text(Field(info, "why")), true
		return false
	end
	local notes = {}
	local without = Changed(s, Delta(nil, { slot }, state), state2, stats2, notes, result.attacker)
	result.candidates[1] = { label = K.SLOTS[slot], slots = { slot }, empty = false, game = true, notCounted = notes, rows = Rows(without, now) }
	for _, text in ipairs(notes) do
		AddOnce(result.notCounted, text)
	end
	result.header = Header(result.boss, result.attacker, true)
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
	-- A worn item is kept by its slot and the link worn there, so a fight never shows what another item in that slot gave.
	local subject = slot and ("slot " .. slot .. " " .. (LinkAt(state, slot) or "")) or link
	local stats = Table(Ask(M.Stats))
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
	local key = table.concat({ subject, tostring(Ask(M.Version)), held.version, attacker }, "|")
	if held.cache[key] then
		return held.cache[key]
	end
	result.attacker, result.boss = attacker, boss
	local now = Work(s, attacker)
	result.now = now
	local keep
	if slot then
		keep = Gives(result, slot, state, stats, s, now)
	else
		keep = Instead(result, link, opts, state, stats, s, now)
	end
	if keep then
		Remember(key, result)
		held.last[subject] = result
	end
	return result
end

-- The table now against the enemy Against names: { attacker, boss, table, rows (as A.Compare's, with nil), old }, or nil and why.
function A.Now()
	local s = Snapshot()
	if not s then
		return nil, T.NO_STATS
	elseif not (s.defense and s.level) then
		return nil, T.NO_DEFENSE
	end
	local attacker, boss = Attacker(s.level)
	local key = held.version .. "|" .. attacker
	if not (held.now and held.nowKey == key) then
		local now = Work(s, attacker)
		held.now, held.nowKey = { attacker = attacker, boss = boss, table = now, rows = Rows(now, nil) }, key
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

-- A text that changes with what the lines and the view are built from: the snapshot, whether avoidance shows and Against.
function A.Stamp()
	return table.concat({ held.version, A.Wanted() and "on" or "off", tostring(ns.Get("chat.gearAgainst")) }, "|")
end

-- Text -------------------------------------------------------------------------------------------------------------------------------------------

local function Hex(colour)
	return ("|cff%02x%02x%02x"):format(math.floor(colour[1] * 255 + 0.5), math.floor(colour[2] * 255 + 0.5), math.floor(colour[3] * 255 + 0.5))
end

local GAIN, LOSS = Hex(K.GAIN), Hex(K.LOSS)

-- A row's value: two decimals for the table, one for armor's share, whole for block value; "-" for none, "none" for a block value with no shield.
local function Value(row, value, signed)
	if not Finite(value) then
		return row.key == "blockValue" and T.NONE or "-"
	elseif row.key == "blockValue" then
		return (signed and "%+d" or "%d"):format(math.floor(value + 0.5))
	elseif row.key == "armor" then
		return (signed and "%+.1f%%" or "%.1f%%"):format(value)
	end
	return (signed and "%+.2f%%" or "%.2f%%"):format(value)
end

local function Still(row)
	return row.key == "armor" and K.STILL_ARMOR or row.key == "blockValue" and K.STILL_VALUE or K.STILL
end

-- The change of a row (a block value or armor share none is 0), and its tone: "gain" when better for the player, "loss" when worse, else "none".
local function Change(row, with)
	local now = Num(row.now)
	with = Num(with)
	if now == nil and with == nil then
		return nil, "none"
	end
	local delta = (with or 0) - (now or 0)
	if math.abs(delta) < Still(row) then
		return delta, "none"
	end
	return delta, ((delta > 0) == (row.better == true)) and "gain" or "loss"
end

-- A part of a tooltip line in the colour of its direction.
local function Coloured(text, tone)
	return (tone == "gain" and GAIN or LOSS) .. text .. "|r"
end

-- A row's value now or with the item, ~ first when it rests on an estimate (header); a change is never marked, since the change of a row the roll does
-- not cut is the client's own sum.
local function Total(row, now)
	if now then
		return (row.nowEstimate and "~" or "") .. Value(row, row.now)
	end
	return (row.withEstimate and "~" or "") .. Value(row, row.with)
end

local function ByKey(rows)
	local out = {}
	for _, row in ipairs(rows) do
		out[row.key] = row
	end
	return out
end

-- The lines of a candidate that change (design of this file: the avoided rows on one line, crit, crushing, armor and block value).
local function Lines(rows, attacker)
	local by, lines = ByKey(rows), {}
	local parts = {}
	for _, key in ipairs(K.AVOIDED) do
		local row = by[key]
		local delta, tone = Change(row, row.with)
		if tone ~= "none" then
			parts[#parts + 1] = Coloured(("%s %s (%s)"):format(row.label, Value(row, delta, true), Total(row)), tone)
		end
	end
	if #parts > 0 then
		lines[#lines + 1] = { text = table.concat(parts, "   "), colour = K.WHITE, wrap = true }
	end
	local crit = by.crit
	local delta, tone = Change(crit, crit.with)
	if tone ~= "none" then
		local immuneAt, text = math.floor(attacker * K.PER_LEVEL + K.CRIT / K.PER_SKILL + 0.5), nil
		if (Num(crit.with) or 0) <= 0 then
			text = T.CRIT_IMMUNE:format(Value(crit, delta, true), immuneAt)
		else
			text = T.CRIT:format(Value(crit, delta, true), Total(crit), immuneAt)
		end
		lines[#lines + 1] = { text = Coloured(text, tone), colour = K.WHITE, wrap = true }
	end
	local crush = by.crush
	delta, tone = Change(crush, crush.with)
	if tone ~= "none" then
		lines[#lines + 1] = { text = Coloured(T.CRUSH:format(Value(crush, delta, true), Total(crush)), tone), colour = K.WHITE, wrap = true }
	end
	parts = {}
	local armor = by.armor
	delta, tone = Change(armor, armor.with)
	if tone ~= "none" then
		local size = ("%.1f%%"):format(math.abs(delta))
		parts[#parts + 1] = Coloured((delta > 0 and T.ARMOR_LESS or T.ARMOR_MORE):format(size, Value(armor, armor.with)), tone)
	end
	local value = by.blockValue
	delta, tone = Change(value, value.with)
	if tone ~= "none" then
		parts[#parts + 1] = Coloured(T.VALUE:format(Value(value, delta, true), Value(value, value.with)), tone)
	end
	if #parts > 0 then
		lines[#lines + 1] = { text = table.concat(parts, "   "), colour = K.WHITE, wrap = true }
	end
	return lines
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

-- The lines of the item tooltip block (GearLines.lua), for the candidate whose slots the spell rows show, else the first: the header, the lines that
-- change and the dim lines of what is not counted, as entries GearLines.lua adds ({ text, colour, wrap }), and the words of the spell rows' "no
-- change" line while avoidance shows. Nil while avoidance does not show or has nothing to say.
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
	local lines = Lines(chosen.rows, result.attacker)
	if #lines == 0 then
		return {}, T.NO_CHANGE_ALL
	end
	table.insert(lines, 1, { text = result.header, colour = K.GREY, wrap = true })
	for _, text in ipairs(chosen.notCounted or {}) do
		lines[#lines + 1] = { text = T.NOT_COUNTED .. text, colour = K.DIM, wrap = true }
	end
	return lines, T.NO_CHANGE
end

-- The window -------------------------------------------------------------------------------------------------------------------------------------

-- A row of the window: its texts and tones by column (name, now, with, change1, change2).
local function WindowRow(rows, withs)
	local first = rows[1]
	local texts, tones = { name = first.label, now = Total(first, true) }, {}
	if withs then
		texts.with = Total(first)
		for index, with in ipairs(withs) do
			local delta, tone = Change(rows[index], with)
			local column = "change" .. index
			texts[column] = delta and Value(first, delta, true) or "-"
			tones[column] = tone
		end
	end
	return { texts = texts, tones = tones }
end

-- The Avoidance view of the Gear comparison window (GearWindow.lua): { layout, cands, rows = { { texts, tones } }, heads, foot, notes, why }, with an
-- item the table in each slot it can take (the first two), else the table now.
function A.Window(link)
	local view = { layout = "none", cands = {}, rows = {}, notes = {}, heads = { name = T.HEAD }, foot = {} }
	local now, why = A.Now()
	local attacker, boss = now and now.attacker, now and now.boss
	if link then
		local result = A.Compare(link, {})
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
		for index, row in ipairs(view.cands[1].rows) do
			local rows, withs = {}, {}
			for which, c in ipairs(view.cands) do
				rows[which], withs[which] = c.rows[index], c.rows[index].with
			end
			view.rows[#view.rows + 1] = WindowRow(rows, withs)
		end
	elseif now then
		for _, row in ipairs(now.rows) do
			view.rows[#view.rows + 1] = WindowRow({ row }, nil)
		end
	else
		view.why = view.why or why
	end
	if attacker then
		view.foot[1] = T.FOOT_AGAINST:format(boss and T.FOOT_BOSS or T.LEVEL, attacker)
	end
	view.foot[#view.foot + 1] = T.FOOT_SHEET
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
	local t = now.table
	local line = T.STATUS:format(now.boss and T.BOSS or T.LEVEL, Short(t.missed), Short(t.dodged), Short(t.parried), Short(t.blocked), Short(t.crit),
		Short(t.crush))
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
