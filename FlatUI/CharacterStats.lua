local _, ns = ...

-- Stats at a glance: a strip of Flat UI's own under the Character window, on its character page, with the few numbers that matter most for the
-- player's role, each in a tile of its own: a dim name, the number, and under it what the number means against a boss (capped, how far from the
-- cap, what armor takes off), coloured green where a cap is reached, gold where it is close and red where it is far. Pointing at a tile shows a
-- tooltip with the parts of the number and what counts in it. The game's stats pane lists every number in long groups and the player has to know
-- which matter and where their caps are; the strip shows those first and says where the caps are. The owner asked for it ("more user friendly for
-- at-a-glance information"), and for thorns in it.
--
-- The tiles, by role (ns.PlayerRole's first answer, Core.lua, as the hit table shows by it) and by the kinds of attack of the class and form
-- (ns.HitTableCalc.Kinds, the hit table's By your class and form): a tank has Armor, Defense, Avoidance, Block value (with a shield), Hit and
-- Thorns; a healer Healing, Spell crit, Mana regen and Thorns; a damage dealer the tiles of each kind of attack: Attack power, Crit and Hit for
-- melee, the same for ranged, Spell power, Spell crit, Spell hit and Spell Piercing for spells, with Mana regen for a mana user; Item level leads
-- every set while the client has the call. At Everything (windows.glanceShow) every tile with a number shows, whatever the role.
--
-- The reads are the character sheet's own calls (SpellModel.lua's header lists them, as research_tooltips.md §3.1 does): UnitAttackPower and
-- UnitRangedAttackPower (base plus both buffs), GetCritChance, GetRangedCritChance, GetSpellCritChance and GetSpellBonusDamage for each school,
-- GetSpellBonusHealing, GetManaRegen, UnitArmor's effective armor, UnitDefenseSkill (UnitDefense where the client has that name), GetDodgeChance,
-- GetParryChance, GetBlockChance, GetShieldBlock and C_PaperDollInfo.OffhandHasShield, as GearAvoid.lua reads them, and GetAverageItemLevel.
-- Hit, the misses against a boss and Spell Piercing are the hit table's (ns.HitTableCalc.Inputs and Table against a boss three levels above,
-- from behind, with the rules of Hit cap against a boss, hud.hitTableRules), so the strip and the hit table always agree. Armor's share is
-- C_PaperDollInfo.GetArmorEffectiveness against the same boss, as GearAvoid.lua asks it. Defense, Avoidance and crushing blows follow the rules
-- GearAvoid.lua's header sets out: a boss's skill is 5 a level, its crit 5% + (its skill - defense) x 0.04%, its miss 5% - the same, its dodge,
-- parry and block 0.04% less for each point of its skill over 5 a level of the player's (Classic's, an estimate: marked ~), and a crushing blow
-- comes on what the roll of miss, dodge, parry, block and crit leaves of 100% (so a tank whose roll fills it is uncrushable).
--
-- Every stat call is SecretWhenUnitStatsRestricted. While C_Secrets.ShouldUnitStatsBeSecret answers true nothing is read and the last plain
-- numbers stay, and the header says they are from before; a call that raises or gives a secret value leaves its tile at ?, never a mix of a
-- secret and a number. A call the client lacks leaves its tile out.
--
-- Thorns: the damage an enemy takes each time it hits the player, in total, with each source in the tooltip. Two kinds of source count. The
-- player's buffs (C_UnitAuras.GetUnitAuras, as Absorbs.lua reads them): Thorns and Retribution Aura by their spell IDs, every rank, with the
-- amount of the aura's first value (points[1], which holds what talents add) or else the rank's own from the client's data (damage shield auras,
-- aura 15, tools/dev/spelltips/client_spells.json); on an English client also any other buff whose tooltip (C_TooltipInfo.GetUnitBuffByAuraInstanceID)
-- says it deals damage to attackers, as Fire Shield's does. And on an English client the Equip lines of worn gear (C_TooltipInfo.GetInventoryItem,
-- as SpellModel.lua reads the lines of a worn item) that say the same ("When struck in combat inflicts 3 Nature damage to the attacker."). A
-- withheld buff list keeps the last thorns read.
--
-- It is part "stats at a glance" of the windows module, not a module: Windows.lua calls ns.CharacterStats.Apply whenever it applies its settings,
-- as it calls ns.CharacterDurability.Apply. Its frame is made once, on the character page (PaperDollFrame), so it shows only with that page,
-- out of a fight when the game protects the page, as CharacterDurability.lua makes its frame. It reads while it shows: when it is shown, and
-- after the events that change a stat, which its own frame hears only while it shows (RegisterUnitEvent for the player, else RegisterEvent;
-- UnregisterAllEvents as it hides), at most every STEP seconds on its OnUpdate; and when its width changes, as the window's stats pane opens or
-- closes, so the tiles take the room there is: as many columns of at least TILE_W as fit, at most MOST_COLS. Nothing of the game's is written, hooked or read while the
-- window is closed.

local KEY, PART, ROW, SHOW = "windows", "stats at a glance", "windows.glance", "windows.glanceShow"
local IsSecret, Finite = ns.IsSecret, ns.Finite

local function Usable(value)
	return value ~= nil and not IsSecret(value) and type(value) == "table"
end

-- The constants of the file, in one table so its functions stay under the client's count of upvalues.
local K = {
	-- The strip: gap under the window, padding, the header's height, a tile's height and least width, the most columns, and the width taken when
	-- the client gives none (the Character window without its stats pane, 398: GearButton.lua's header).
	GAP = 2, PAD = 6, HEAD = 16, TILE_H = 40, TILE_W = 96, MOST_COLS = 8, WIDTH = 398, TILE_GAP = 4,
	-- The least time between two reads after events.
	STEP = 0.2,
	-- The boss: three levels above; 5 skill a level, 0.04% a point, 5% miss and crit at an even skill (GearAvoid.lua, K).
	BOSS = 3, PER_LEVEL = 5, PER_SKILL = 0.04, MISS = 5, CRIT = 5,
	-- The spell schools, holy to arcane, as SpellModel.lua reads them, and their names.
	SCHOOLS = { 2, 3, 4, 5, 6, 7 },
	SCHOOL_NAMES = { [1] = "Physical", [2] = "Holy", [3] = "Fire", [4] = "Nature", [5] = "Frost", [6] = "Shadow", [7] = "Arcane" },
	-- The worn slots, head to tabard.
	FIRST_SLOT = 1, LAST_SLOT = 19,
	-- Mana, UnitPowerType's 0.
	MANA = 0,
	-- The colours: a tile's name and notes, a number, and green, gold and red for a cap reached, close and far (GearAvoid.lua's STYLE, the game's
	-- NORMAL_FONT_COLOR for gold).
	DIM = { 0.66, 0.68, 0.62 }, WHITE = { 1, 1, 1 }, GOOD = { 0.1, 1, 0.1 }, NEAR = { 1, 0.82, 0 }, FAR = { 1, 0.3, 0.3 },
	-- How close counts as close: within this much of a cap, in percent (hit, avoidance) and in defense points.
	NEAR_PCT = 1, NEAR_DEFENSE = 10, NEAR_CRUSH = 5,
	-- Damage shields by spell ID: the rank's own amount and its school, from the client's data (aura 15, client_spells.json): Thorns 467...9910,
	-- Nature; Retribution Aura 7294...10301, Holy.
	THORNS = {
		[467] = { 3, 4 }, [782] = { 6, 4 }, [1075] = { 9, 4 }, [8914] = { 12, 4 }, [9756] = { 15, 4 }, [9910] = { 18, 4 },
		[7294] = { 5, 2 }, [10298] = { 8, 2 }, [10299] = { 12, 2 }, [10300] = { 16, 2 }, [10301] = { 20, 2 },
	},
	-- The words of a damage shield in an English tooltip: an amount and a school before them.
	THORN_TEXT = { "(%d+) (%a+) damage to the attacker", "(%d+) (%a+) damage to attackers", "(%d+) (%a+) damage to any creature that strikes",
		"(%d+) (%a+) damage to anyone that strikes", "(%d+) (%a+) damage to any enemy that strikes" },
	ENGLISH = { enUS = true, enGB = true },
	MAX_LINES = 40,
	-- The events after which a stat may differ: the player's, and the rest.
	UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "UNIT_ATTACK_SPEED",
		"UNIT_RESISTANCES", "UNIT_AURA", "UNIT_INVENTORY_CHANGED", "UNIT_MAXPOWER", "UNIT_LEVEL" },
	EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "UPDATE_SHAPESHIFT_FORM",
		"PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE" },
	-- The tiles of each role and kind, in order.
	SETS = {
		tank = { "armor", "defense", "avoid", "block", "hit", "thorns" },
		healer = { "heal", "scrit", "mp5", "thorns" },
		melee = { "ap", "crit", "hit" },
		ranged = { "rap", "rcrit", "rhit" },
		spell = { "sp", "scrit", "shit", "pen" },
	},
	ALL = { "ilvl", "armor", "defense", "avoid", "block", "ap", "crit", "hit", "rap", "rcrit", "rhit", "sp", "heal", "scrit", "shit", "pen", "mp5",
		"thorns" },
	ROLE_WORDS = { tank = "Tank", healer = "Healer", damage = "Damage" },
}

local CharacterStats = {}
ns.CharacterStats = CharacterStats

-- The frame and its parts, made once. broken: the game refused one of them, and nothing is tried again. waiting: the making waits for the end of a
-- fight. dirty: an event came since the last read. last: the last plain read, kept while stats are withheld. thorns: the last thorns read.
-- items: the damage shield of each worn item link read (false for none). hearing: the frame hears the events.
local state = { frame = nil, tiles = {}, broken = false, waiting = false, dirty = false, wait = 0, last = nil, thorns = nil, hearing = false,
	items = {} }

-- Reads ---------------------------------------------------------------------------------------------------------------------------------------

-- Every answer of fn(...) in a table, n its count, or nil when the client has no fn, it raises or one answer is secret.
local function Answers(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local function Pack(ok, ...)
		if not ok then
			return nil
		end
		local count = select("#", ...)
		local answers = { n = count, ... }
		for index = 1, count do
			if IsSecret(answers[index]) then
				return nil
			end
		end
		return answers
	end
	return Pack(pcall(fn, ...))
end

-- The first answer of fn(...) when it is a plain finite number, else nil; false when the call raised or withheld it, so ? shows.
local function Number(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local answers = Answers(fn, ...)
	if answers == nil then
		return false
	end
	local value = answers[1]
	return Finite(value) and value or nil
end

local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Api(space, name)
	local fn = Field(_G[space], name)
	return type(fn) == "function" and fn or nil
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- True while the game withholds the player's stats (C_Secrets.ShouldUnitStatsBeSecret), as SpellModel.lua asks it; a withheld answer counts as yes.
local function Withheld()
	local ask = Api("C_Secrets", "ShouldUnitStatsBeSecret")
	if not ask then
		return false
	end
	local ok, yes = pcall(ask)
	return not ok or IsSecret(yes) or yes == true
end

-- Base plus both buffs of an attack power call, nil without the call, false when withheld.
local function Power(fn)
	if type(fn) ~= "function" then
		return nil
	end
	local answers = Answers(fn, "player")
	if answers == nil then
		return false
	end
	local base, plus, minus = answers[1], answers[2], answers[3]
	if not Finite(base) then
		return nil
	end
	return base + (Finite(plus) and plus or 0) + (Finite(minus) and minus or 0), base
end

-- The largest of a call over the spell schools, the school that has it, and whether every school has the same.
local function BestSchool(fn)
	if type(fn) ~= "function" then
		return nil
	end
	local best, at, same, first = nil, nil, true, nil
	for _, school in ipairs(K.SCHOOLS) do
		local value = Number(fn, school)
		if value == false then
			return false
		end
		value = value or 0
		if first == nil then
			first = value
		elseif value ~= first then
			same = false
		end
		if best == nil or value > best then
			best, at = value, school
		end
	end
	return best, at, same
end

-- The hit table against a boss from behind: its inputs and its lines by id, or nil when the hit table cannot read.
local function BossTable(kinds)
	local calc = ns.HitTableCalc
	if type(calc) ~= "table" or type(calc.Inputs) ~= "function" or type(calc.Table) ~= "function" then
		return nil
	end
	local rules = ns.Get("hud.hitTableRules")
	local spec = { against = "boss", facing = "behind", special = true, rules = rules == "game" and "game" or "classic", kinds = kinds }
	local okInputs, inputs = pcall(calc.Inputs, spec)
	if not okInputs or type(inputs) ~= "table" then
		return nil
	end
	local okTable, read = pcall(calc.Table, spec, inputs)
	if not okTable or type(read) ~= "table" then
		return nil
	end
	local lines = {}
	for _, line in ipairs(type(read.lines) == "table" and read.lines or {}) do
		if type(line) == "table" and line.id then
			lines[line.id] = line
		end
	end
	return { inputs = inputs, lines = lines, level = read.target and read.target.level or nil }
end

-- The kinds of attack of the class and form, as the hit table's By your class and form has them.
local function Kinds(class)
	local calc = ns.HitTableCalc
	local power = Number(_G.UnitPowerType, "player")
	if type(calc) == "table" and type(calc.Kinds) == "function" then
		local ok, kinds = pcall(calc.Kinds, "auto", class, power or nil)
		if ok and type(kinds) == "table" then
			return kinds
		end
	end
	return { melee = true }
end

-- The defensive reads, as GearAvoid.lua makes them: defense (base plus modifier), dodge, parry, block chance (none without a shield) and value.
local function Defenses(stats)
	local answers = Answers(_G.UnitDefenseSkill or _G.UnitDefense, "player")
	if answers then
		local base, modifier = answers[1], answers[2]
		stats.defense = Finite(base) and math.max(0, base + (Finite(modifier) and modifier or 0)) or nil
	elseif type(_G.UnitDefenseSkill or _G.UnitDefense) == "function" then
		stats.defense = false
	end
	stats.dodge, stats.parry = Number(_G.GetDodgeChance), Number(_G.GetParryChance)
	stats.blockChance, stats.blockValue = Number(_G.GetBlockChance), Number(_G.GetShieldBlock)
	local shield = Answers(Api("C_PaperDollInfo", "OffhandHasShield"))
	if shield and type(shield[1]) == "boolean" then
		stats.shield = shield[1]
	else
		stats.shield = Finite(stats.blockChance) and stats.blockChance > 0
	end
	if not stats.shield then
		stats.blockChance, stats.blockValue = 0, nil
	end
	local armor = Answers(_G.UnitArmor, "player")
	if armor then
		stats.armor = Finite(armor[2]) and armor[2] or (Finite(armor[1]) and armor[1] or nil)
	elseif type(_G.UnitArmor) == "function" then
		stats.armor = false
	end
end

-- Thorns ----------------------------------------------------------------------------------------------------------------------------------------

local function English()
	local ok, locale = pcall(_G.GetLocale)
	return ok and Plain(locale, "string") and K.ENGLISH[locale] == true
end

-- The amount and school of the first damage shield a tooltip's lines name, or nil. equip: only the lines that start with the game's Equip word.
local function ThornLine(data, equip)
	local lines = Field(data, "lines")
	for index = 1, K.MAX_LINES do
		local line = Field(lines, index)
		if line == nil then
			break
		end
		local text = Field(line, "leftText")
		if Plain(text, "string") and (not equip or text:find("^Equip:")) then
			for _, pattern in ipairs(K.THORN_TEXT) do
				local amount, school = text:match(pattern)
				amount = tonumber(amount)
				if Finite(amount) and amount > 0 then
					return amount, school
				end
			end
		end
	end
	return nil
end

-- The name of a school by its number, for the tooltip.
local function SchoolName(school)
	return K.SCHOOL_NAMES[school] or "?"
end

-- The damage shields on the player now: { total, sources = { { name, amount, school } } }, or nil while the game withholds the buffs.
local function ReadThorns()
	local found = { total = 0, sources = {} }
	local english = English()
	local auras = Answers(Api("C_UnitAuras", "GetUnitAuras"), "player", "HELPFUL")
	local list = auras and auras[1]
	if auras and type(list) == "table" then
		local tip = Api("C_TooltipInfo", "GetUnitBuffByAuraInstanceID")
		for _, aura in ipairs(list) do
			local id, name, points, instance = Field(aura, "spellId"), Field(aura, "name"), Field(aura, "points"), Field(aura, "auraInstanceID")
			local known = Finite(id) and K.THORNS[id] or nil
			local amount, school = nil, nil
			if known then
				local first = Field(points, 1)
				amount = Finite(first) and first > 0 and first or known[1]
				school = SchoolName(known[2])
			elseif english and tip and Finite(instance) then
				local data = Answers(tip, "player", instance)
				if data then
					amount, school = ThornLine(data[1], false)
				end
			end
			if amount then
				found.total = found.total + amount
				found.sources[#found.sources + 1] = { name = Plain(name, "string") and name or "Buff", amount = amount, school = school }
			end
		end
	elseif type(Api("C_UnitAuras", "GetUnitAuras")) == "function" then
		-- The game withholds the buffs: the last read stands for them.
		return nil
	end
	local itemTip = english and Api("C_TooltipInfo", "GetInventoryItem") or nil
	for slot = K.FIRST_SLOT, itemTip and K.LAST_SLOT or 0 do
		local link = Answers(_G.GetInventoryItemLink, "player", slot)
		link = link and Plain(link[1], "string") and link[1] or nil
		local kept = link and state.items[link]
		if link and kept == nil then
			-- Read once a link; an item whose lines the client has not loaded yet is read again next time.
			local data = Answers(itemTip, "player", slot)
			local amount, school = nil, nil
			if data then
				amount, school = ThornLine(data[1], true)
			end
			kept = amount and { amount = amount, school = school } or false
			if amount or (data and Field(data[1], "lines") ~= nil) then
				state.items[link] = kept
			end
		end
		if kept then
			found.total = found.total + kept.amount
			found.sources[#found.sources + 1] = { name = link:match("%[(.-)%]") or "Equipped item", amount = kept.amount, school = kept.school }
		end
	end
	return found
end

-- The read ----------------------------------------------------------------------------------------------------------------------------------------

-- Everything the tiles show, read now: the stats, the role and the hit table against a boss.
local function ReadAll()
	local stats = {}
	stats.level = Number(_G.UnitLevel, "player")
	if not Finite(stats.level) or stats.level < 1 then
		return nil
	end
	stats.level = math.floor(stats.level)
	local class = Answers(_G.UnitClassBase, "player")
	stats.class = class and Plain(class[1], "string") and class[1] or nil
	stats.power = Number(_G.UnitPowerType, "player")
	local okRole, role = pcall(ns.PlayerRole)
	stats.role = okRole and K.ROLE_WORDS[role] and role or "damage"
	stats.kinds = Kinds(stats.class)
	stats.ilvl = nil
	local ilvl = Answers(_G.GetAverageItemLevel)
	if ilvl then
		local equipped = Finite(ilvl[2]) and ilvl[2] or ilvl[1]
		stats.ilvl, stats.ilvlBags = Finite(equipped) and equipped or nil, Finite(ilvl[1]) and ilvl[1] or nil
	end
	stats.ap, stats.apBase = Power(_G.UnitAttackPower)
	stats.rap, stats.rapBase = Power(_G.UnitRangedAttackPower)
	stats.crit, stats.rcrit = Number(_G.GetCritChance), Number(_G.GetRangedCritChance)
	stats.scrit = BestSchool(_G.GetSpellCritChance)
	stats.sp, stats.spSchool, stats.spSame = BestSchool(_G.GetSpellBonusDamage)
	stats.heal = Number(_G.GetSpellBonusHealing)
	local regen = Answers(_G.GetManaRegen)
	if regen then
		stats.regen, stats.regenCasting = Finite(regen[1]) and regen[1] * 5 or nil, Finite(regen[2]) and regen[2] * 5 or nil
	elseif type(_G.GetManaRegen) == "function" then
		stats.regen = false
	end
	Defenses(stats)
	stats.boss = BossTable({ melee = true, ranged = true, spell = true })
	stats.bossLevel = stats.level + K.BOSS
	local armorPct = stats.armor and Answers(Api("C_PaperDollInfo", "GetArmorEffectiveness"), math.max(0, stats.armor), stats.bossLevel)
	stats.armorPct = armorPct and Finite(armorPct[1]) and armorPct[1] * 100 or nil
	return stats
end

-- Formatting -------------------------------------------------------------------------------------------------------------------------------------

-- A whole number with its thousands broken as the game breaks them.
local function Whole(value)
	value = math.floor(value + 0.5)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, text = pcall(BreakUpLargeNumbers, value)
		if ok and Plain(text, "string") then
			return text
		end
	end
	return tostring(value)
end

local function Pct(value, decimals)
	return ("%." .. (decimals or 2) .. "f%%"):format(value)
end

-- The colour of a gap to a cap: none left green, within near gold, else red.
local function CapColour(left, near)
	if left <= 0.005 then
		return K.GOOD
	elseif left <= near then
		return K.NEAR
	end
	return K.FAR
end

-- The tiles ----------------------------------------------------------------------------------------------------------------------------------
-- Each gives, from a read, nil to leave the tile out, or { value, colour, note, noteColour, tip = { lines } }. A value of false (withheld) shows ?.

-- The tile of a number the game withheld (false), or nil for any other.
local function Refused(value)
	if value == false then
		return { value = "?", note = "withheld", tip = { "The game withholds this number now." } }
	end
	return nil
end

-- The miss of a hit table line against a boss, its floor, and whether it is known.
local function BossMiss(stats, id)
	local line = stats.boss and stats.boss.lines[id]
	local parts = line and line.parts
	local miss = parts and parts.miss
	if not Finite(miss) then
		return nil
	end
	return miss, Finite(line.floor) and line.floor or 0
end

-- A hit tile: the hit of a kind, and the miss against a boss of its line, green at the floor.
local function HitTile(stats, kind, lineId, label)
	local inputs = stats.boss and stats.boss.inputs
	local part = inputs and inputs[kind]
	if type(part) ~= "table" then
		return nil
	end
	if kind == "ranged" and (part.skill == nil or part.noWeapon) then
		return nil
	end
	local hit = part.hit
	if hit == nil then
		return { value = "?", note = "withheld", tip = { "The game withholds your hit now." } }
	end
	local miss, floor = BossMiss(stats, lineId)
	local tile = { value = Pct(hit, 1), tip = { ("%s hit from gear, talents and buffs: %s."):format(label, Pct(hit, 1)) } }
	if miss then
		local left = miss - floor
		tile.colour = CapColour(left, K.NEAR_PCT)
		if left <= 0.005 then
			tile.note, tile.noteColour = "capped vs boss", K.GOOD
		else
			tile.note, tile.noteColour = ("boss miss %s"):format(Pct(miss, 1)), tile.colour
		end
		local what = lineId == "special" and "abilities" or (lineId == "spell" and "spells" or "shots")
		if left <= 0.005 then
			tile.tip[#tile.tip + 1] = floor > 0 and ("Against a boss (level %d) your %s miss %s, the least they can: more hit adds nothing."):format(
				stats.bossLevel, what, Pct(floor, 0)) or ("Against a boss (level %d) your %s never miss: more hit adds nothing."):format(stats.bossLevel, what)
		else
			tile.tip[#tile.tip + 1] = ("Against a boss (level %d) your %s miss %s of the time."):format(stats.bossLevel, what, Pct(miss, 1))
		end
		if lineId == "special" then
			local swing = BossMiss(stats, "main") or BossMiss(stats, "swing")
			if swing then
				tile.tip[#tile.tip + 1] = ("Your white swings miss %s, the dual wield penalty included."):format(Pct(swing, 1))
			end
		end
		tile.tip[#tile.tip + 1] = "As the hit table works it out, with the rules of Hit cap against a boss."
	end
	return tile
end

-- Adds the crit of a hit table line against a boss to a crit tile: a weapon's crit falls against an enemy above the player.
local function BossCrit(stats, lineId, tile)
	local line = stats.boss and stats.boss.lines[lineId]
	local crit = line and line.parts and line.parts.crit
	if Finite(crit) then
		tile.note = ("boss %s"):format(Pct(crit, 1))
		tile.tip[#tile.tip + 1] = ("Against a boss (level %d): %s%s, as the hit table works it out."):format(stats.bossLevel, Pct(crit, 1),
			lineId == "spell" and "" or " on an attack that lands")
	end
	return tile
end

local TILES = {}

TILES.ilvl = { label = "Item level", read = function(stats)
	if not Finite(stats.ilvl) then
		return nil
	end
	local tip = { ("Average item level of what you wear: %.1f."):format(stats.ilvl) }
	if Finite(stats.ilvlBags) and stats.ilvlBags > stats.ilvl + 0.05 then
		tip[#tip + 1] = ("With the best of your bags: %.1f."):format(stats.ilvlBags)
	end
	return { value = ("%.1f"):format(stats.ilvl), tip = tip }
end }

TILES.ap = { label = "Attack power", read = function(stats)
	if stats.ap == nil then
		return nil
	end
	local withheld = Refused(stats.ap)
	if withheld then
		return withheld
	end
	return { value = Whole(stats.ap), note = stats.ap ~= stats.apBase and ("base %s"):format(Whole(stats.apBase)) or nil,
		tip = { ("Melee attack power %s: %s base, %+d from buffs."):format(Whole(stats.ap), Whole(stats.apBase), stats.ap - stats.apBase),
			"Every 14 adds 1 damage a second to your weapon." } }
end }

TILES.rap = { label = "Ranged power", read = function(stats)
	if stats.rap == nil or not (stats.kinds.ranged or stats.class == "HUNTER") then
		return nil
	end
	local withheld = Refused(stats.rap)
	if withheld then
		return withheld
	end
	return { value = Whole(stats.rap), note = stats.rap ~= stats.rapBase and ("base %s"):format(Whole(stats.rapBase)) or nil,
		tip = { ("Ranged attack power %s: %s base, %+d from buffs."):format(Whole(stats.rap), Whole(stats.rapBase), stats.rap - stats.rapBase) } }
end }

TILES.crit = { label = "Crit", read = function(stats)
	if stats.crit == nil then
		return nil
	end
	return Refused(stats.crit) or BossCrit(stats, "special", { value = Pct(stats.crit),
		tip = { ("Melee crit chance: %s, as the character sheet shows it."):format(Pct(stats.crit)) } })
end }

TILES.rcrit = { label = "Ranged crit", read = function(stats)
	if stats.rcrit == nil or not (stats.kinds.ranged or stats.class == "HUNTER") then
		return nil
	end
	return Refused(stats.rcrit) or BossCrit(stats, "ranged", { value = Pct(stats.rcrit),
		tip = { ("Ranged crit chance: %s, as the character sheet shows it."):format(Pct(stats.rcrit)) } })
end }

TILES.hit = { label = "Hit", read = function(stats)
	return HitTile(stats, "melee", "special", "Melee")
end }

TILES.rhit = { label = "Ranged hit", read = function(stats)
	if not (stats.kinds.ranged or stats.class == "HUNTER") then
		return nil
	end
	return HitTile(stats, "ranged", "ranged", "Ranged")
end }

TILES.shit = { label = "Spell hit", read = function(stats)
	return HitTile(stats, "spell", "spell", "Spell")
end }

TILES.sp = { label = "Spell power", read = function(stats)
	if stats.sp == nil then
		return nil
	end
	local withheld = Refused(stats.sp)
	if withheld then
		return withheld
	end
	return { value = Whole(stats.sp), note = not stats.spSame and SchoolName(stats.spSchool) or nil,
		tip = { stats.spSame and ("Bonus damage of your spells: %s for every school."):format(Whole(stats.sp))
			or ("Bonus damage of your spells: %s at most, for %s."):format(Whole(stats.sp), SchoolName(stats.spSchool)) } }
end }

TILES.heal = { label = "Healing", read = function(stats)
	if stats.heal == nil then
		return nil
	end
	return Refused(stats.heal) or { value = Whole(stats.heal), tip = { ("Bonus healing of your spells: %s."):format(Whole(stats.heal)) } }
end }

TILES.scrit = { label = "Spell crit", read = function(stats)
	if stats.scrit == nil then
		return nil
	end
	return Refused(stats.scrit) or BossCrit(stats, "spell", { value = Pct(stats.scrit),
		tip = { ("Spell crit chance: %s, of the school with the most."):format(Pct(stats.scrit)) } })
end }

TILES.pen = { label = "Spell Piercing", read = function(stats)
	local spell = stats.boss and stats.boss.inputs and stats.boss.inputs.spell
	local pen = type(spell) == "table" and spell.pen or nil
	if not Finite(pen) or pen <= 0 then
		return nil
	end
	return { value = Whole(pen), tip = { ("Spell Piercing %s: lowers the resistances of the enemies your spells hit."):format(Whole(pen)),
		"Past their resistance a creature takes more: the hit table's Resist column shows how much." } }
end }

TILES.mp5 = { label = "Mana regen", read = function(stats)
	if stats.regen == nil or stats.power ~= K.MANA then
		return nil
	end
	local withheld = Refused(stats.regen)
	if withheld then
		return withheld
	end
	local casting = Finite(stats.regenCasting) and stats.regenCasting or 0
	return { value = ("%s / 5s"):format(Whole(casting)), note = ("%s out of casting"):format(Whole(stats.regen)),
		tip = { ("Mana every 5 seconds while casting: %s."):format(Whole(casting)),
			("Out of the five second rule: %s."):format(Whole(stats.regen)) } }
end }

TILES.armor = { label = "Armor", read = function(stats)
	if stats.armor == nil then
		return nil
	end
	local withheld = Refused(stats.armor)
	if withheld then
		return withheld
	end
	local tile = { value = Whole(stats.armor), tip = { ("Armor %s."):format(Whole(stats.armor)) } }
	if Finite(stats.armorPct) then
		tile.note = ("-%s vs boss"):format(Pct(stats.armorPct, 1))
		tile.tip[#tile.tip + 1] = ("Takes %s off the physical damage of a boss (level %d), at most 75%%."):format(Pct(stats.armorPct, 1), stats.bossLevel)
	end
	return tile
end }

-- The defense a boss can no longer crit: its skill plus 5% / 0.04%.
local function CritImmune(stats)
	return stats.bossLevel * K.PER_LEVEL + K.CRIT / K.PER_SKILL
end

TILES.defense = { label = "Defense", read = function(stats)
	if stats.defense == nil then
		return nil
	end
	local withheld = Refused(stats.defense)
	if withheld then
		return withheld
	end
	local need = CritImmune(stats)
	local left = math.max(0, need - stats.defense)
	local tile = { value = Whole(stats.defense), colour = CapColour(left, K.NEAR_DEFENSE) }
	if left <= 0 then
		tile.note, tile.noteColour = "crit immune", K.GOOD
	else
		tile.note, tile.noteColour = ("%d to crit immune"):format(math.ceil(left)), tile.colour
	end
	tile.tip = { ("Defense %d. At %d a boss (level %d) can no longer crit you."):format(stats.defense, need, stats.bossLevel),
		"Each point also adds 0.04% to the chance it misses, and to your dodge, parry and block." }
	return tile
end }

-- The roll of a boss's melee swing against the player (GearAvoid.lua's rules): missed, dodged, parried, blocked and crit, and the crushing blows
-- that what they leave of 100% has room for. Nil without defense.
local function BossRoll(stats)
	if not Finite(stats.defense) then
		return nil
	end
	local skill = stats.bossLevel * K.PER_LEVEL
	local diff, fall = skill - stats.defense, (skill - stats.level * K.PER_LEVEL) * K.PER_SKILL
	local roll = {
		missed = math.max(0, K.MISS - diff * K.PER_SKILL),
		dodged = Finite(stats.dodge) and math.max(0, stats.dodge - fall) or 0,
		parried = Finite(stats.parry) and stats.parry > 0 and math.max(0, stats.parry - fall) or 0,
		blocked = Finite(stats.blockChance) and stats.blockChance > 0 and math.max(0, stats.blockChance - fall) or 0,
		crit = math.max(0, K.CRIT + diff * K.PER_SKILL),
	}
	roll.avoided = roll.missed + roll.dodged + roll.parried + roll.blocked
	-- Crushing blows: (the boss's skill less the defense, counted up to the cap of the player's level) x 2% - 15%, from 15 points on.
	local over = skill - math.min(stats.defense, stats.level * K.PER_LEVEL)
	roll.crushChance = over >= 15 and over * 2 - 15 or 0
	roll.crush = math.max(0, math.min(roll.crushChance, 100 - roll.avoided - roll.crit))
	return roll
end

TILES.avoid = { label = "Avoidance", read = function(stats)
	local roll = BossRoll(stats)
	if roll == nil then
		return nil
	end
	local tile = { value = "~" .. Pct(roll.avoided, 1) }
	if roll.crush <= 0 then
		tile.note, tile.noteColour, tile.colour = "uncrushable", K.GOOD, K.GOOD
	else
		tile.colour = CapColour(roll.crush, K.NEAR_CRUSH)
		tile.note, tile.noteColour = ("%s crushing"):format(Pct(roll.crush, 1)), tile.colour
	end
	tile.tip = {
		("A boss's (level %d) swing at you, from the front:"):format(stats.bossLevel),
		("Missed %s, dodged %s, parried %s, blocked %s: %s avoided."):format(Pct(roll.missed, 1), Pct(roll.dodged, 1), Pct(roll.parried, 1),
			Pct(roll.blocked, 1), Pct(roll.avoided, 1)),
		("Critical %s, crushing %s."):format(Pct(roll.crit, 1), Pct(roll.crush, 1)),
		"Uncrushable once missed, dodged, parried, blocked and critical fill 100%.",
		"~ Classic's rules: a boss is dodged, parried and blocked 0.6% less than the sheet shows.",
	}
	return tile
end }

TILES.block = { label = "Block value", read = function(stats)
	if not stats.shield or stats.blockValue == nil then
		return nil
	end
	local withheld = Refused(stats.blockValue)
	if withheld then
		return withheld
	end
	return { value = Whole(stats.blockValue), note = Finite(stats.blockChance) and ("%s block"):format(Pct(stats.blockChance, 1)) or nil,
		tip = { ("A blocked hit loses %s damage."):format(Whole(stats.blockValue)),
			Finite(stats.blockChance) and ("Block chance %s, as the character sheet shows it."):format(Pct(stats.blockChance)) or "" } }
end }

TILES.thorns = { label = "Thorns", read = function(stats)
	local thorns = state.thorns
	if thorns == nil then
		return { value = "?", note = "buffs withheld", tip = { "The game withholds your buffs now." } }
	end
	if thorns.total <= 0 then
		return { value = "0", colour = K.DIM, note = "none", tip = { "Damage an enemy takes each time it hits you.",
			"None now: Thorns, Retribution Aura, a fire shield or gear with a damage shield would add it." } }
	end
	-- The note names the one school of every source, else how many schools there are, to fit the tile.
	local schools, count, only = {}, 0, nil
	local tip = { ("Each enemy that hits you takes %s damage:"):format(Whole(thorns.total)) }
	for _, source in ipairs(thorns.sources) do
		tip[#tip + 1] = ("  %s: %s %s"):format(source.name, Whole(source.amount), source.school or "")
		local school = source.school or "?"
		if not schools[school] then
			schools[school], count, only = true, count + 1, school
		end
	end
	tip[#tip + 1] = "A damage shield never crits, and the enemy's resistance to its school can lower it."
	local note = count == 1 and ("%s, per hit"):format(only) or ("per hit, %d schools"):format(count)
	return { value = Whole(thorns.total), colour = K.GOOD, note = note, tip = tip }
end }

-- The ids of the tiles to show, in order, for a read.
local function Chosen(stats)
	local ids, seen = {}, {}
	local function Add(list)
		for _, id in ipairs(list) do
			if not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
	end
	if ns.Get(SHOW) == "all" then
		Add(K.ALL)
		return ids
	end
	Add({ "ilvl" })
	if stats.role == "tank" then
		Add(K.SETS.tank)
	elseif stats.role == "healer" then
		Add(K.SETS.healer)
	else
		for _, kind in ipairs({ "melee", "ranged", "spell" }) do
			if stats.kinds[kind] then
				Add(K.SETS[kind])
			end
		end
		if stats.kinds.spell and stats.power == K.MANA then
			Add({ "mp5" })
		end
		Add({ "thorns" })
	end
	return ids
end

-- The frame -------------------------------------------------------------------------------------------------------------------------------------

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

-- True when the game would refuse a frame made on this one now.
local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or IsSecret(protected) or protected == true
end

local function Paint(text, colour)
	colour = colour or K.WHITE
	pcall(text.SetTextColor, text, colour[1], colour[2], colour[3], 1)
end

-- The tooltip of a tile, while it has one.
local function TileEnter(tile)
	local tip = _G.GameTooltip
	if not Usable(tip) or type(tile.tipLines) ~= "table" then
		return
	end
	pcall(tip.SetOwner, tip, tile, "ANCHOR_BOTTOM")
	pcall(tip.AddLine, tip, tile.label, 1, 0.82, 0)
	for _, line in ipairs(tile.tipLines) do
		if Plain(line, "string") then
			pcall(tip.AddLine, tip, line, 1, 1, 1, true)
		end
	end
	pcall(tip.Show, tip)
end

local function TileLeave(tile)
	local tip = _G.GameTooltip
	if Usable(tip) then
		local ok, owned = pcall(tip.IsOwned, tip, tile)
		if ok and owned == true then
			pcall(tip.Hide, tip)
		end
	end
end

-- A tile: a frame of its own with three texts, made the first time it is needed.
local function Tile(index)
	local tile = state.tiles[index]
	if tile then
		return tile
	end
	local frame = state.frame
	local ok, made = pcall(CreateFrame, "Frame", nil, frame)
	if not ok or not Usable(made) then
		return nil
	end
	ns.Own[made] = true
	made.name = ns.OwnText(made, "OVERLAY", "GameFontHighlightSmall")
	made.value = ns.OwnText(made, "OVERLAY", "GameFontNormal")
	made.note = ns.OwnText(made, "OVERLAY", "GameFontHighlightSmall")
	if not (made.name and made.value and made.note) then
		return nil
	end
	pcall(made.name.SetPoint, made.name, "TOPLEFT", made, "TOPLEFT", 0, 0)
	pcall(made.value.SetPoint, made.value, "TOPLEFT", made.name, "BOTTOMLEFT", 0, -1)
	pcall(made.note.SetPoint, made.note, "TOPLEFT", made.value, "BOTTOMLEFT", 0, -1)
	for _, text in ipairs({ made.name, made.value, made.note }) do
		pcall(text.SetJustifyH, text, "LEFT")
		pcall(text.SetWordWrap, text, false)
	end
	Paint(made.name, K.DIM)
	pcall(made.EnableMouse, made, true)
	pcall(made.SetScript, made, "OnEnter", TileEnter)
	pcall(made.SetScript, made, "OnLeave", TileLeave)
	state.tiles[index] = made
	return made
end

-- The width the strip has, in its own units.
local function Width()
	local frame = state.frame
	local ok, width = pcall(frame.GetWidth, frame)
	if ok and Finite(width) and width > K.TILE_W then
		return width
	end
	return K.WIDTH
end

-- Lays out and fills the tiles of a read.
local function Draw(stats, old)
	local frame = state.frame
	local shown = {}
	for _, id in ipairs(Chosen(stats)) do
		local def = TILES[id]
		local ok, tile = pcall(def.read, stats)
		if ok and type(tile) == "table" then
			tile.label = def.label
			shown[#shown + 1] = tile
		end
	end
	local width = Width()
	local inner = width - 2 * K.PAD
	local cols = math.max(1, math.min(K.MOST_COLS, math.floor((inner + K.TILE_GAP) / (K.TILE_W + K.TILE_GAP)), #shown))
	local tileW = (inner - (cols - 1) * K.TILE_GAP) / cols
	for index, info in ipairs(shown) do
		local tile = Tile(index)
		if tile == nil then
			break
		end
		local row, col = math.floor((index - 1) / cols), (index - 1) % cols
		pcall(tile.ClearAllPoints, tile)
		pcall(tile.SetPoint, tile, "TOPLEFT", frame, "TOPLEFT", K.PAD + col * (tileW + K.TILE_GAP), -(K.PAD + K.HEAD + row * K.TILE_H))
		pcall(tile.SetSize, tile, tileW, K.TILE_H)
		for _, text in ipairs({ tile.name, tile.value, tile.note }) do
			pcall(text.SetWidth, text, tileW)
		end
		pcall(tile.name.SetText, tile.name, info.label)
		pcall(tile.value.SetText, tile.value, info.value)
		Paint(tile.value, info.colour)
		pcall(tile.note.SetText, tile.note, info.note or "")
		Paint(tile.note, info.noteColour or K.DIM)
		tile.label, tile.tipLines = info.label, info.tip
		pcall(tile.Show, tile)
	end
	for index = #shown + 1, #state.tiles do
		pcall(state.tiles[index].Hide, state.tiles[index])
	end
	local rows = math.max(1, math.ceil(#shown / cols))
	pcall(frame.SetHeight, frame, 2 * K.PAD + K.HEAD + rows * K.TILE_H)
	local role = K.ROLE_WORDS[stats.role] or "Damage"
	local head = ns.Get(SHOW) == "all" and "Stats at a glance" or ("Stats at a glance: %s"):format(role)
	pcall(state.head.SetText, state.head, head)
	pcall(state.against.SetText, state.against, old and "before the fight" or ("vs boss, level %d"):format(stats.bossLevel))
end

-- Reads and draws, or keeps the last read while the game withholds the stats.
local function Update()
	if state.frame == nil then
		return
	end
	state.dirty, state.wait = false, K.STEP
	local old = false
	if Withheld() then
		old = true
	else
		local stats = ReadAll()
		if stats then
			state.last = stats
		end
		local thorns = ReadThorns()
		if thorns then
			state.thorns = thorns
		end
	end
	if state.last then
		Draw(state.last, old)
	end
end

local function Marked()
	state.dirty = true
end

-- The events heard while the strip shows.
local function Hear(on)
	local frame = state.frame
	if on == state.hearing then
		return
	end
	state.hearing = on
	if not on then
		pcall(frame.UnregisterAllEvents, frame)
		return
	end
	for _, event in ipairs(K.UNIT_EVENTS) do
		if not (type(frame.RegisterUnitEvent) == "function" and pcall(frame.RegisterUnitEvent, frame, event, "player")) then
			pcall(frame.RegisterEvent, frame, event)
		end
	end
	for _, event in ipairs(K.EVENTS) do
		pcall(frame.RegisterEvent, frame, event)
	end
end

-- The parts of the frame's scripts, each inside ns.EachPart so a fault stops the strip alone.
local function Shown()
	Hear(true)
	Update()
end

local function Hidden()
	Hear(false)
end

local function Stepped(_, elapsed)
	if not state.dirty then
		return
	end
	state.wait = state.wait - (Finite(elapsed) and elapsed or 0)
	if state.wait <= 0 then
		Update()
	end
end

local function Refuse(text)
	state.broken = true
	ns.Note(KEY, text)
end

-- Makes the strip on the character page, under the Character window. True when it is there.
local function Make(page)
	local ok, frame = pcall(CreateFrame, "Frame", nil, page)
	if not ok or not Usable(frame) then
		Refuse("Windows: Stats at a glance stopped, the game refused a frame on the Character window.")
		return false
	end
	ns.Own[frame] = true
	state.frame = frame
	state.head = ns.OwnText(frame, "OVERLAY", "GameFontNormal")
	state.against = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	if state.head == nil or state.against == nil then
		pcall(frame.Hide, frame)
		state.frame = nil
		Refuse("Windows: Stats at a glance stopped, the game refused a text on the Character window.")
		return false
	end
	local window = _G.CharacterFrame
	local placed = false
	if Usable(window) and not ns.Forbidden(window) then
		placed = pcall(frame.SetPoint, frame, "TOPLEFT", window, "BOTTOMLEFT", 0, -K.GAP)
			and pcall(frame.SetPoint, frame, "TOPRIGHT", window, "BOTTOMRIGHT", 0, -K.GAP)
	end
	if not placed then
		pcall(frame.ClearAllPoints, frame)
		pcall(frame.SetPoint, frame, "TOPLEFT", page, "BOTTOMLEFT", 0, -K.GAP)
		pcall(frame.SetWidth, frame, K.WIDTH)
	end
	pcall(frame.SetHeight, frame, 2 * K.PAD + K.HEAD + K.TILE_H)
	ns.SetOutlineArea(ns.Outline(frame, frame), KEY)
	pcall(state.head.SetPoint, state.head, "TOPLEFT", frame, "TOPLEFT", K.PAD, -K.PAD + 1)
	pcall(state.against.SetPoint, state.against, "TOPRIGHT", frame, "TOPRIGHT", -K.PAD, -K.PAD + 1)
	Paint(state.against, K.DIM)
	pcall(frame.SetScript, frame, "OnShow", function()
		ns.EachPart(KEY, PART, Shown)
	end)
	pcall(frame.SetScript, frame, "OnHide", function()
		ns.EachPart(KEY, PART, Hidden)
	end)
	-- An event, or a new width as the stats pane opens or closes, reads and lays out again on the next step.
	pcall(frame.SetScript, frame, "OnEvent", function()
		Marked()
	end)
	pcall(frame.SetScript, frame, "OnSizeChanged", function()
		Marked()
	end)
	pcall(frame.SetScript, frame, "OnUpdate", function(self, elapsed)
		ns.EachPart(KEY, PART, Stepped, self, elapsed)
	end)
	return true
end

local function Applied()
	if not Wanted() then
		if state.frame then
			Hear(false)
			pcall(state.frame.Hide, state.frame)
		end
		return
	end
	if state.frame == nil then
		local page = _G.PaperDollFrame
		if state.broken or not Usable(page) or ns.Forbidden(page) then
			return
		end
		if Blocked(page) then
			if not state.waiting then
				state.waiting = true
				ns.OutOfCombat(function()
					state.waiting = false
					CharacterStats.Apply()
				end)
			end
			return
		end
		if not Make(page) then
			return
		end
	end
	-- Shown while wanted, so it comes with the character page; a strip that shows already (a row changed) reads again now.
	local okShown, shown = pcall(state.frame.IsShown, state.frame)
	if not (okShown and shown == true) then
		pcall(state.frame.Show, state.frame)
		return
	end
	local ok, visible = pcall(state.frame.IsVisible, state.frame)
	if ok and visible == true then
		Hear(true)
		Update()
	end
end

-- Shows the strip while the row is on, or hides it; a change of the rows reads again.
function CharacterStats.Apply()
	if ns.PartStopped(KEY, PART) and state.frame then
		Hear(false)
		pcall(state.frame.Hide, state.frame)
	end
	ns.EachPart(KEY, PART, Applied)
end

-- For /flatui status and the tests: the tiles shown now, as "Name value (note)" lines, and the last thorns read.
function CharacterStats.Lines()
	local lines = {}
	for _, tile in ipairs(state.tiles) do
		local ok, shown = pcall(tile.IsShown, tile)
		if ok and shown == true then
			local value = select(2, pcall(tile.value.GetText, tile.value))
			local note = select(2, pcall(tile.note.GetText, tile.note))
			lines[#lines + 1] = ("%s %s%s"):format(tostring(tile.label), tostring(value),
				Plain(note, "string") and note ~= "" and (" (" .. note .. ")") or "")
		end
	end
	return lines, state.thorns
end

ns.AddStatus(KEY, function()
	if not (state.frame and Wanted()) then
		return {}
	end
	local thorns = state.thorns
	return { ("Stats at a glance: %d tiles, thorns %s"):format(#CharacterStats.Lines(), thorns and Whole(thorns.total) or "?") }
end)
