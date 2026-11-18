local _, ns = ...

-- The stub of the spell data (design 3.2a): one entry of each comparison kind, in the shape tools/dev/make_spelltips.py writes, so the other parts
-- build against the real field names before the data is made. make_spelltips.py replaces this file; its --check refuses a field this stub lacks.
-- Values are WoW: Forever's own (client build 1.60.1.70938, hotfix push 114122, as captured by wowsims/forever, MIT), for a few ranks only.

local D = {}
ns.SpellData = D

D.BUILD, D.HOTFIX, D.FALLBACK = "1.60.1.70938", 114122, "1.60.1.70888"

D.MODEL = {
	crit = { spell = 1.5, special = 2.0, ranged = 2.0, swing = 2.0 },
	apPerDps = 14, gcd = 1.5, offHand = 0.5, healThreat = 0.5,
	norm = { one = 2.4, dagger = 1.7, two = 3.3, ranged = 2.8 }, form = { cat = 1.0, bear = 2.5 },
	glance = { lowA = 1.3, lowB = 0.05, lowMax = 0.91, highA = 1.2, highB = 0.03, highMin = 0.2, highMax = 0.99 },
	ratings = { hit = 10, crit = 14, haste = 10, expertise = 10 },
	downrank = { grace = 17, step = 0.05 },
}
D.SCHOOL_NAMES = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }

-- One constructor a class; SpellModel.lua runs the player's class and ALL once, on first use.
D.CLASS = {}

D.CLASS.ALL = function()
	return {
		{ key = "attack", school = 1, cmp = "auto", roll = "swing", parts = { { "wpn", 1, spd = "actual", h = "both", b = "c" } },
			ranks = { { 6603, 1 } } },
		{ key = "shoot", school = 1, cmp = "wand", roll = "spell", parts = { { "wpn", 1, spd = "actual", b = "c" } },
			ranks = { { 5019, 1 } } },
	}
end

D.CLASS.MAGE = function()
	return {
		{ key = "frostbolt", school = 5, cmp = "spell", roll = "spell",
			parts = { { "sp", 0.814, b = "c" } },
			ranks = {
				{ 116, 4, c = { 0.407 }, ct = 1500, du = 5000, bm = { 19 }, bl = { 0.2 }, mx = { 8 } },
				{ 25304, 60, ct = 3000, du = 9000, bm = { 475 }, bl = { 3.2 }, mx = { 64 } },
			} },
		{ key = "arcane missiles", school = 7, cmp = "channel", roll = "spell",
			parts = { { "sp", 1.43, n = 5, p = 1, per = "missile", b = "c" } },
			ranks = { { 25345, 56, ct = -1, du = 5000, bm = { 1045 }, bl = { 5 }, lv = { 60 }, mx = { 64 } } } },
	}
end

D.CLASS.WARLOCK = function()
	return {
		{ key = "corruption", school = 6, cmp = "dot", roll = "spell",
			parts = { { "sp", 1.2, n = 6, p = 3, b = "c" } },
			ranks = { { 25311, 60, ct = 2000, du = 18000, bm = { 438 } } } },
	}
end

D.CLASS.PRIEST = function()
	return {
		{ key = "greater heal", school = 2, cmp = "heal", roll = "spell",
			parts = { { "heal", 0.857, b = "c" } },
			ranks = { { 25314, 60, ct = 3000, bm = { 1960 }, bl = { 8.1 }, mx = { 65 } } },
			threat = { k = "heal", v = 0.5, b = "m", split = true } },
		{ key = "renew", school = 2, cmp = "hot", roll = "spell",
			parts = { { "heal", 1.0, n = 5, p = 3, b = "c" } },
			ranks = { { 25315, 60, ct = 0, du = 15000, bm = { 830 } } },
			threat = { k = "heal", v = 0.5, b = "m", split = true } },
	}
end

D.CLASS.WARRIOR = function()
	return {
		{ key = "mortal strike", school = 1, cmp = "strike", roll = "special",
			parts = { { "wpn", 1, spd = "norm", h = "main", b = "c" } },
			ranks = { { 21553, 60, bm = { 160 } } } },
		{ key = "heroic strike", school = 1, cmp = "strike", roll = "special", nx = true,
			parts = { { "wpn", 1, spd = "actual", h = "main", b = "c" } },
			ranks = { { 25286, 60, bm = { 157 } } },
			threat = { k = "bonus", v = { 150 }, b = "e" } },
		{ key = "bloodthirst", school = 1, cmp = "apstrike", roll = "special",
			parts = { { "ap", 0.45, b = "c" } },
			ranks = { { 23894, 60, bm = { 48 } } } },
		{ key = "revenge", school = 1, cmp = "apstrike", roll = "special",
			parts = { { "ap", 0.25, g = true, fs = { 18, 0.225 }, b = "m" } },
			ranks = { { 25288, 60, bm = { 153 } } },
			threat = { k = "mult", v = 2.25, b = "e" } },
		{ key = "sunder armor", school = 1, cmp = "threat", roll = "special",
			parts = {},
			ranks = { { 7386, 10 }, { 7405, 22 }, { 8380, 34 }, { 11596, 46 }, { 11597, 58 } },
			threat = { k = "flat", v = { 34, 75, 117, 158, 206 }, b = "mcmcc", ap = 0.05, apb = "m" } },
	}
end

D.CLASS.ROGUE = function()
	return {
		{ key = "eviscerate", school = 1, cmp = "finisher", roll = "special",
			parts = { { "ap", 0.04, per = "cp", b = "e" } },
			ranks = { { 31016, 60, bm = { 108 }, cpb = 170 } } },
	}
end

D.CLASS.HUNTER = function()
	return {
		{ key = "auto shot", school = 1, cmp = "shot", roll = "ranged",
			parts = { { "wpn", 1, spd = "actual", h = "ranged", b = "c" } },
			ranks = { { 75, 1 } } },
	}
end

D.CLASS.PALADIN = function()
	return {
		{ key = "judgement of righteousness", school = 2, cmp = "spell", roll = "ranged", nb = true,
			parts = { { "sp", 0.429, b = "c" } },
			ranks = { { 20286, 58, bm = { 170 }, bl = { 4.1 }, mx = { 64 } } } },
		{ key = "seal of righteousness", school = 2, cmp = "seal", roll = "special",
			parts = { { "sp", 0.10, per = "hit", o = true, two = 0.12, note = "the game's text counts 7.65% for one-handers", b = "m" } },
			ranks = { { 20293, 58, du = 30000, sv = 1786, bl = { 47 }, mx = { 64 } } } },
		{ key = "seal of command", school = 2, cmp = "proc", roll = "special",
			parts = { { "wpn", 0.7, spd = "actual", h = "main", per = "proc", b = "m" }, { "sp", 0.203, per = "proc", b = "m" } },
			ranks = { { 20920, 60, du = 30000 } } },
	}
end

-- Threat multipliers. A talent carries its trait node and definition, read with C_Traits.GetNodeInfo; say: the tip spell's own text says
-- nothing of threat, so its tooltip gets the multiplier; lowers: a threat-lowering stance or form, background for a damage dealer.
D.RULES = {
	{ id = "defensive", class = "WARRIOR", form = 18, m = 1.8, b = "c", name = "Defensive Stance", tip = 71,
		note = "Defiance counts only with a shield" },
	{ id = "battle", class = "WARRIOR", form = 17, m = 0.8, b = "c", name = "Battle Stance", tip = 2457, say = true, lowers = true },
	{ id = "defiance", class = "WARRIOR", talent = 12792, node = 110856, def = 142602, r = { 1.07, 1.13, 1.2 }, form = 18, shield = true, b = "c",
		name = "Defiance" },
	{ id = "fury", class = "PALADIN", aura = 25780, m = 1.33, holy = 1.9, b = "c", holyB = "e", name = "Righteous Fury", tip = 25780,
		note = "Holy ~x2.53: the two multiply" },
	{ id = "rogue", class = "ROGUE", m = 0.71, always = true, b = "c", name = "rogue" },
}
D.HEAL_THREAT = { ["holy light"] = 0.25, ["flash of light"] = 0.25, ["holy shock"] = 0.25 }
D.CRIT = {
	{ talent = 11207, node = 105777, def = 135307, r = { 0.2, 0.4, 0.6, 0.8, 1 }, spells = { "frostbolt" } },
}
-- Every item stat key of the client; t: its "Equip:" sentence, for the 76 that have one. kind none: known, not in the model; note: not in the
-- model, and named when an item has it.
D.STATS = {
	ITEM_MOD_INTELLECT_SHORT = { "stat", 4 },
	ITEM_MOD_SPELL_POWER_SHORT = { "sp", t = "TOOLTIP_ITEM_STAT_SPELL_POWER_INCREASE" },
	ITEM_MOD_HASTE_RATING_SHORT = { "rating", { 18, 19, 20 }, 10, t = "TOOLTIP_ITEM_STAT_HASTE_PCT_INCREASE" },
	ITEM_MOD_MANA_REGENERATION_SHORT = { "none", t = "TOOLTIP_ITEM_STAT_MANA_REGEN_INCREASE" },
	ITEM_MOD_SPELL_PENETRATION_SHORT = { "note", "spell penetration", t = "TOOLTIP_ITEM_STAT_SPELL_PENETRATION_INCREASE" },
}
-- Two stats in one sentence: the line explains both.
D.STAT_PAIRS = { { "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", t = "TOOLTIP_ITEM_STAT_SPELL_HEALING_INCREASE_DAMAGE_INCREASE" } }
D.DEFAULTS = { MAGE = { damage = { "frostbolt", "fireball", "arcane missiles" } } }
-- Ranks whose text starts with the plain amount of the part, for the check of SpellModel.lua whether the game's texts count spell power.
D.PROBES = { MAGE = { 25306 }, PRIEST = { 25314 } }
-- The temporary enchants of Rockbiter Weapon, from its imbue spells (effect 360, misc value).
D.ROCKBITER = { [1] = true, [6] = true, [29] = true, [503] = true, [683] = true, [1663] = true, [1664] = true }
