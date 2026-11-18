local _, ns = ...

-- The numbers of the hit table (HitTable.lua draws them): the player's chances against the target, worked out from what the game gives, read as
-- the game's own character sheet reads it. Nothing is drawn, hooked or written here and no frame is made; HitTable.lua calls ns.HitTableCalc.Read
-- inside ns.EachPart, so a fault stops the hit table alone.
--
-- What the game gives. The calls Classic addons read weapon skill with (UnitAttackBothHands, UnitRangedAttack, GetSkillLineInfo) are not on Forever,
-- so the skill of a hand is the skill line of the weapon in its slot, found as the character sheet finds it: the item subclass to a line, Unarmed for
-- an empty hand and Feral Combat for a druid in a form (Camelot/PaperDollFrameStats.lua:22-40, 681-698), then rank plus modifier of
-- C_SkillInfo.GetSkillLineInfoByID (Camelot/SkillsFrame.lua:268; SkillInfoDocumentation.lua:74-87, no secret return). Hit is the rating bonus plus
-- the modifier of each kind, crit the sheet's three chances (Camelot/PaperDollFrameStats.lua:524-527, 602-604), expertise the three values of
-- GetExpertise in points of dodge and parry taken off (Camelot/PaperDollFrame.lua:546-574), Spell Piercing (Forever's name of spell penetration,
-- STAT_SPELL_PENETRATION) GetSpellPenetration, one number for every school, as the sheet reads it (Camelot/PaperDollFrame.lua:1119-1136). Each of
-- those is SecretWhenUnitStatsRestricted (PlayerScriptDocumentation.lua): a withheld value is never compared, added or kept, and every part that
-- needs it is unknown (nil), which the table shows as ?. A call that raises counts the same; a client without a modifier, or without
-- GetSpellPenetration, has none of it. The enemy's own resistances are not read: UnitResistance answers for the player and the pet alone, as the game
-- asks it (Camelot/CharacterFrame.lua:1190-1200), so a 0 from it would not tell none from not sent. The target's level, kind and whether it can be
-- attacked carry no secret tag (UnitDocumentation.lua). A level the game shows as ?? (UnitEffectiveLevel 0 or less, Mainline/TargetFrame.lua:297-315)
-- counts as three levels above the player. The game does not say where the player stands: the first choice of Where you stand reads whether the
-- target attacks the player from the player's threat situation on it (C.Front). The client has one melee crit chance, the main hand's: apis.yaml
-- lists GetCritChance, GetRangedCritChance, GetSpellCritChance and GetPetCritChance and nothing for the off hand.
--
-- The rules are those of Classic's attack table, which Forever keeps (Forever hunter wiki, Ranged-Attack-Table.md:11-23), as tests of Classic found
-- them (magey's Classic warrior wiki, Attack-table.md, with the posts of Blizzard it quotes at :22-33). D is five times the target's level and d is D
-- less the weapon skill. A swing is one roll: miss, dodge, parry, glancing blow, block, crit and hit each take their chance in that order from what is
-- left, so the crit cap is what the outcomes before crit leave (:184-347). A special attack, a ranged attack and a spell roll crit again on an attack
-- that lands (Ranged-Attack-Table.md:291-310), so their crit is a chance of its own and their hit is everything that lands. A spell's resist is no
-- part of the roll: it is the share of a spell's damage resisted on average, after the hit and the crit (Resist, below).
--
-- C.Inputs reads the game and C.Table works the table out from what it read, reading nothing, so the gear comparison (GearModel.lua) works it out
-- again with the weapon skill, hit, crit and expertise an item would give, keeping the skill the sheet's crit was read with; it can ask C.Inputs for
-- the kinds its spells roll and for a ranged line with no ranged weapon worn (a paladin's judgements). C.Read is the two in a row. C.LineOf,
-- C.Skill and C.SkillLine give it the skill line of an item, the skill of a line and its rank, modifier and name (the comparison counts every
-- compared hand at the most for the level plus the modifier, while the hit table here counts the player's skill as it is), and C.Target counts
-- against an enemy of the player's level when it asks. C.Resist gives it a resist with other Spell Piercing and levels: at the player's level, with
-- the piercing of a school an item pierces on its own (Fire Piercing...), which GetSpellPenetration does not count.
-- The enemy is the target unless spec.unit names another unit (C.Target, C.Front): HitTableTip.lua works the table out against the unit of an enemy's
-- tooltip, from inputs it kept, with C.Target and C.Table.

local C = {}
ns.HitTableCalc = C

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The combat ratings of hit by kind (Camelot/PaperDollFrame.lua:9-11), kept here: the globals belong to the character sheet's addon.
local CR_HIT = { melee = 6, ranged = 7, spell = 8 }
-- The agility stat (LE_UNIT_STAT_AGILITY), and the equipment slots of the three weapons (Blizzard_FrameXMLBase/Constants.lua:151-153).
local AGILITY = 2
local SLOTS = { main = 16, off = 17, ranged = 18 }
-- Enum.ItemClass.Weapon, and the skill line of each Enum.ItemWeaponSubclass (Camelot/PaperDollFrameStats.lua:22-38).
local WEAPON = 2
local SKILL_OF = { [0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55, [10] = 136, [13] = 162, [15] = 173,
	[16] = 176, [18] = 226, [19] = 228 }
-- The ranged lines, bows, guns, thrown weapons, crossbows and wands (Camelot/SkillsFrame.lua:10-28), and the line of an empty hand and of a druid in a
-- form (Camelot/PaperDollFrameStats.lua:40, 683-690).
local RANGED = { [45] = true, [46] = true, [176] = true, [226] = true, [228] = true }
local UNARMED, FERAL = 162, 3014
-- Points of defense and weapon skill a level (Camelot/PaperDollFrameStats.lua:10), and the levels a ?? target and a boss are above the player.
local PER_LEVEL, ABOVE = 5, 3
-- What dual wielding adds to the miss of a swing: the client's own DUAL_WIELD_HIT_PENALTY (Camelot/PaperDollFrame.lua:311), the flat 19 tests of
-- Classic found (Attack-table.md:63-71).
local DUAL_WIELD = 19
-- The crit from auras an enemy three levels above takes away, about 1.8 (Crit-aura-suppression.md, Attack-table.md:180-182), and the parry it has on
-- top of 5% and 0.1 a point: 14% at 300 skill (Blizzard, Attack-table.md:25; 13.97% tested, :251) and 13.49% tested at 305 (:296).
local AURA_CRIT, BOSS_PARRY = 1.8, 7.5
-- A druid's power in Bear and Cat Form: Rage and Energy (Enum.PowerType 1 and 3).
local FERAL_POWER = { [1] = true, [3] = true }
-- What By your class and form shows for each class; a druid's depends on the form, and a class the game withholds gets melee and spells.
local KITS = {
	WARRIOR = { melee = true }, ROGUE = { melee = true }, HUNTER = { ranged = true }, PALADIN = { melee = true, spell = true },
	SHAMAN = { melee = true, spell = true }, MAGE = { spell = true }, PRIEST = { spell = true }, WARLOCK = { spell = true },
}
-- How much crit past the cap counts as over it.
local OVER = 0.05
-- The lowest threat situation of a unit the enemy attacks: 2 tanking insecurely and 3 securely, as PlateThreat.lua:142-144 and CombatText.lua:2485
-- read UnitThreatSituation (UnitDocumentation.lua:3279-3294).
local TANKING = 2
-- Resistance. A point takes RESIST_AVERAGE / (5 x the caster's level) of a spell's damage on average (ExpectedSpellResistance,
-- Camelot/PaperDollFrameStats.lua:233-235, as Forever's sheet fills SPELL_PENETRATION_TOOLTIP, Camelot/PaperDollFrame.lua:1129-1130), at most 75%
-- (RESIST_CAP, Classic's cap at 5 x the level); a point below 0, where Forever's Spell Piercing may take a creature ("Spell Vulnerability", its
-- SPELL_PENETRATION_TOOLTIP), adds half that to the damage it takes. A creature above the player resists RESIST_LEVEL more a level of its own,
-- which piercing cannot lower: Classic's rule (Wowpedia, Spell penetration: 2% a level, 8 points at 60), an estimate on Forever.
local RESIST_AVERAGE, RESIST_CAP, RESIST_LEVEL = 0.75, 0.75, 0.02
-- Why a value is missing, the worst kept: withheld before refused before a client without the call.
local RANK = { withheld = 3, refused = 2, missing = 1 }

-- Reading the game -------------------------------------------------------------------------------------------------------------------------------

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

-- A plain answer of a call, or nil.
local function Ask(fn, ...)
	local value, why = Call(fn, ...)
	if why then
		return nil
	end
	return value
end

-- Notes what the game did not give, for /flatui status.
local function Gap(read, what, why)
	local had = read.gaps[what]
	if RANK[why] and (had == nil or RANK[why] > RANK[had]) then
		read.gaps[what] = why
	end
end

-- The hit chance of a kind: its rating bonus, nil read as none (Nilable, PlayerScriptDocumentation.lua:319-333), plus its modifier. A client without
-- one of the calls has none of that hit; nil when the game withholds or refuses either.
local function Hit(read, kind, modifier)
	local bonus, why = Call(GetCombatRatingBonus, CR_HIT[kind])
	if why == "withheld" or why == "refused" then
		Gap(read, "hit", why)
		return nil
	end
	local more, whyMore = Call(modifier)
	if whyMore == "withheld" or whyMore == "refused" then
		Gap(read, "hit", whyMore)
		return nil
	end
	return (Finite(bonus) and bonus or 0) + (Finite(more) and more or 0)
end

-- A crit chance of the sheet in percent, or nil when the game withholds, refuses or lacks it.
local function Crit(read, fn)
	local value, why = Call(fn)
	if why or not Finite(value) then
		Gap(read, "crit", why or "refused")
		return nil
	end
	return value
end

-- Spell Piercing (GetSpellPenetration), or nil when the game withholds or refuses it; a client without the call has none.
local function Piercing(read)
	local value, why = Call(GetSpellPenetration)
	if why == "missing" then
		return 0
	elseif why or not Finite(value) then
		Gap(read, "spell piercing", why or "refused")
		return nil
	end
	return value
end

-- The crit agility gives, in percent, as the sheet reads it (Camelot/PaperDollFrameStats.lua:314-318): UnitStat's effective agility to
-- GetCritChanceFromStat, which gives a fraction. Nil when either cannot be read; only the share of crit from auras needs it.
local function AgilityCrit()
	if type(UnitStat) ~= "function" then
		return nil
	end
	local ok, _, agility = pcall(UnitStat, "player", AGILITY)
	if not ok or not Finite(agility) then
		return nil
	end
	local share = Ask(GetCritChanceFromStat, AGILITY, agility)
	return Finite(share) and share * 100 or nil
end

-- Expertise of the main hand, the off hand and the ranged weapon. A client without GetExpertise has none; nil when the game withholds or refuses it.
local function Expertise(read)
	if type(GetExpertise) ~= "function" then
		return 0, 0, 0
	end
	local ok, main, off, ranged = pcall(GetExpertise)
	if not ok then
		Gap(read, "expertise", "refused")
		return nil, nil, nil
	elseif IsSecret(main) or IsSecret(off) or IsSecret(ranged) then
		Gap(read, "expertise", "withheld")
		return nil, nil, nil
	end
	return Finite(main) and main or 0, Finite(off) and off or 0, Finite(ranged) and ranged or 0
end

-- The skill line of an item, an item ID or a link, as the character sheet finds a weapon's (Camelot/PaperDollFrameStats.lua:22-38): the line of
-- its weapon subclass, nil for an item that is no weapon. The second value is true while the game does not say. The gear comparison asks it of the
-- item it compares (C.LineOf).
local function LineOf(item)
	if not (Finite(item) or (not IsSecret(item) and type(item) == "string")) then
		return nil, true
	end
	local api = C_Item
	if type(api) ~= "table" or type(api.GetItemInfoInstant) ~= "function" then
		return nil, true
	end
	-- The sixth and seventh answers are the class and the subclass (ItemDocumentation.lua:659-679, MayReturnNothing for an item not yet known).
	local ok, _, _, _, _, _, classID, subclassID = pcall(api.GetItemInfoInstant, item)
	if not ok or IsSecret(classID) or IsSecret(subclassID) or classID == nil then
		return nil, true
	elseif classID ~= WEAPON then
		return nil
	end
	return SKILL_OF[subclassID]
end
C.LineOf = LineOf

-- The skill line of what a slot holds, as the character sheet finds it (Camelot/PaperDollFrameStats.lua:681-698): Feral Combat for a druid in a form,
-- Unarmed for an empty hand, nil for anything that is not a weapon (and for an empty ranged slot). The second value is true while the game does not say.
local function Line(read, slot)
	if read.feral then
		return FERAL
	end
	local item, why = Call(GetInventoryItemID, "player", slot)
	if why then
		return nil, true
	elseif item == nil then
		return slot ~= SLOTS.ranged and UNARMED or nil
	elseif not Finite(item) then
		return nil, true
	end
	return LineOf(item)
end

-- What the game says of a line: { rank, modifier (race and gear, 0 when none), name (nil when the game gives none) }, or nil when the player has
-- no such line or the game says nothing (GetSkillLineInfoByID is Nilable, SkillInfoDocumentation.lua:74-87, 111-129).
local function SkillLine(line)
	local api = C_SkillInfo
	if line == nil or type(api) ~= "table" or type(api.GetSkillLineInfoByID) ~= "function" then
		return nil
	end
	local ok, rank, modifier, name = pcall(function()
		local info = api.GetSkillLineInfoByID(line)
		if IsSecret(info) or type(info) ~= "table" then
			return nil, nil, nil
		end
		return info.rank, info.modifier, info.name
	end)
	if not (ok and Finite(rank)) then
		return nil
	end
	if IsSecret(name) or type(name) ~= "string" or name == "" then
		name = nil
	end
	return { rank = rank, modifier = Finite(modifier) and modifier or 0, name = name }
end
C.SkillLine = SkillLine

-- The skill of a line, rank plus modifier, or nil when the player has no such line or the game says nothing.
local function Skill(line)
	local got = SkillLine(line)
	return got and got.rank + got.modifier or nil
end
C.Skill = Skill

-- The weapon skill of a melee hand, and its skill line (nil while the game does not say what the hand holds). When the game gives no skill, the most
-- for the player's level stands in, and the hand is named for /flatui status.
local function HandSkill(read, slot, name)
	local line, unknown = Line(read, slot)
	if unknown then
		line = nil
	end
	local skill = line and Skill(line) or nil
	if skill then
		return skill, line
	end
	read.assumed[#read.assumed + 1] = name
	return read.level * PER_LEVEL, line
end

-- The enemy the table is worked out against: level, unknown (shown ??), kind ("boss", "elite"... from ns.UnitKind), player, none (no enemy targeted:
-- one of the player's level), boss (Against a boss), unit (the unit read), and enemy: the unit can be attacked and is alive. against is "boss",
-- "level" (an enemy of the player's level whatever is targeted, for the gear comparison's Against) or anything else for the unit. unit is a unit
-- token, "target" when it is nil or not a plain string, so the hit table, which names none, reads the target as it always did.
function C.Target(against, level, unit)
	if IsSecret(unit) or type(unit) ~= "string" or unit == "" then
		unit = "target"
	end
	local target = { level = level, unit = unit }
	target.enemy = Ask(UnitExists, unit) == true and Ask(UnitCanAttack, "player", unit) == true
		and Ask(UnitIsDeadOrGhost, unit) ~= true
	if against == "boss" then
		target.level, target.kind, target.boss = level + ABOVE, "boss", true
	elseif against == "level" then
		-- A mob of the player's own level, of no kind and no player, whatever the target is.
		target.level = level
	elseif target.enemy then
		local seen = Ask(UnitEffectiveLevel, unit)
		if not Finite(seen) then
			seen = Ask(UnitLevel, unit)
		end
		if Finite(seen) and seen > 0 then
			target.level = math.floor(seen)
		else
			target.level, target.unknown = level + ABOVE, true
		end
		target.kind = ns.UnitKind(unit)
		target.player = Ask(UnitIsPlayer, unit) == true
	else
		target.none = true
	end
	return target
end

-- True while the table counts parries and blocks: In front, or the first choice while the target attacks the player. That is the player's threat
-- situation on the target, UnitThreatSituation("player", "target"), TANKING or more: a query of the player against the target is generally not
-- secret (SecretWhenUnitThreatStateRestricted, SecretPredicatesDocumentation.lua:160-163), in dungeons and raids too. The target's own target
-- (UnitIsUnit("targettarget", "player")) is asked only when that gives no number, as for a player, who has no threat table: on an addon-restricted
-- map every comparison of a compound unit token is withheld (SecretWhenUnitComparisonRestricted, SecretPredicatesDocumentation.lua:120-123;
-- UnitDocumentation.lua:2410-2426), as Forever withholds the enemy's target (PlateThreat.lua:12). A plain answer of no place on the threat table of an
-- enemy that is no player says it does not attack the player. With no answer at all the player counts as behind, and the second value is true, for
-- /flatui status. target: C.Target's answer, whose unit (the target unless spec.unit named another) is the one asked of here.
function C.Front(facing, target)
	if facing == "front" then
		return true, false
	elseif facing ~= "auto" or type(target) ~= "table" or not target.enemy then
		return false, false
	end
	local unit = target.unit
	if IsSecret(unit) or type(unit) ~= "string" or unit == "" then
		unit = "target"
	end
	local status, why = Call(UnitThreatSituation, "player", unit)
	if not why and Finite(status) then
		return status >= TANKING, false
	end
	local same = Ask(UnitIsUnit, unit .. "target", "player")
	if type(same) == "boolean" then
		return same, false
	end
	if not why and status == nil and Ask(UnitIsPlayer, unit) == false then
		return false, false
	end
	return false, true
end

-- The kinds of attack the row Attacks asks for: melee, ranged and spell, each true or nil.
function C.Kinds(choice, class, power)
	if choice == "melee" then
		return { melee = true }
	elseif choice == "ranged" then
		return { ranged = true }
	elseif choice == "spell" then
		return { spell = true }
	elseif choice == "all" then
		return { melee = true, ranged = true, spell = true }
	elseif class == "DRUID" then
		return FERAL_POWER[power] and { melee = true } or { spell = true }
	end
	return KITS[class] or { melee = true, spell = true }
end

-- The table ---------------------------------------------------------------------------------------------------------------------------------------

local function Clamp(value)
	return math.max(0, math.min(100, value))
end

-- Lays outcomes on one roll of 100 in order: each takes its chance from what is left, and what does not fit is pushed off the end. What is left
-- comes back, nil from the first unknown outcome on; an outcome that does not apply (false) takes nothing.
local function Roll(parts, order)
	local left = 100
	for _, key in ipairs(order) do
		local chance = parts[key]
		if chance == nil then
			left = nil
		elseif chance ~= false and left ~= nil then
			chance = math.min(chance, left)
			parts[key] = chance
			left = left - chance
		end
	end
	return left
end

-- What a point of skill difference changes on dodge, parry and block: 0.1 against a mob, 0.04 against a player (Attack-table.md:117-153).
local function Step(ctx)
	return ctx.player and 0.04 or 0.1
end

-- The miss of a weapon after hit. Against a mob 5% and 0.1 a point up to 10 points, 0.2 a point past them, scaled down under level 10
-- (Attack-table.md:45-59); then past 10 points the first (d - 10) x 0.2 of hit counts for nothing with Classic tests (Blizzard's post at :30),
-- and the game's tooltip, which needs 8% against a boss (CR_WARRIOR_HIT_CAP_TOOLTIP), leaves that out. Against a player 5% and 0.04 a point.
-- extra is the dual wield penalty of a swing.
local function Miss(ctx, skill, hit, extra)
	if hit == nil then
		return nil
	end
	local d = ctx.D - skill
	local miss, lost
	if ctx.player then
		miss, lost = 5 + d * 0.04, 0
	elseif d > 10 then
		miss, lost = 5 + d * 0.2, ctx.classic and (d - 10) * 0.2 or 0
	else
		miss, lost = 5 + d * 0.1, 0
	end
	if not ctx.player and ctx.T < 10 then
		miss = miss * ctx.T / 10
	end
	-- The hit lost comes off what gear and talents give; a hit under none, from a debuff, adds to the miss whole.
	local counted = hit > 0 and math.max(0, hit - lost) or hit
	return Clamp(math.max(0, miss) + extra - counted)
end

-- Dodge: 5% and a step a point, less expertise (Attack-table.md:117-137; Forever's expertise takes it off dodge and parry, CR_EXPERTISE_TOOLTIP).
local function Dodge(ctx, skill, expertise)
	if expertise == nil then
		return nil
	end
	return Clamp(5 + (ctx.D - skill) * Step(ctx) - expertise)
end

-- Parry, from the front only: as dodge, and an enemy three or more levels above has BOSS_PARRY more.
local function Parry(ctx, skill, expertise)
	if not ctx.front then
		return false
	elseif expertise == nil then
		return nil
	end
	local parry = 5 + (ctx.D - skill) * Step(ctx)
	if not ctx.player and ctx.T - ctx.L >= ABOVE then
		parry = parry + BOSS_PARRY
	end
	return Clamp(parry - expertise)
end

-- Block, from the front only: as dodge, and a mob never more than 5% (Attack-table.md:139-153). Whether an enemy can block the game does not say.
local function Block(ctx, skill)
	if not ctx.front then
		return false
	end
	local block = 5 + (ctx.D - skill) * Step(ctx)
	if not ctx.player then
		block = math.min(5, block)
	end
	return Clamp(block)
end

-- Glancing blows, on swings against a mob: 10% and 2 a point, with no skill counted past the most for the player's level (Attack-table.md:73-85).
-- The formula, and not GetGlancingBlowChance: Blizzard listed the sheet's glancing chances as wrong during the beta.
local function Glance(ctx, skill)
	if ctx.player then
		return false
	end
	return Clamp(10 + (ctx.D - math.min(ctx.L * PER_LEVEL, skill)) * 2)
end

-- The crit of a weapon against the enemy. The sheet's chance holds 0.04 a point of skill past the most for the player's level, which counts against
-- players only, so it comes off first: of sheetSkill, the skill the sheet's chance was worked out with (the main hand's for GetCritChance, which is
-- the off hand's crit too, and the ranged weapon's for GetRangedCritChance). Against a mob the skill of the hand, counted up to that most, changes
-- crit 0.2 a point under the mob's defense and 0.04 over it, and an enemy three levels above also takes up to AURA_CRIT of the crit that comes from
-- auras: the sheet's crit less what agility gives (Attack-table.md:155-182). Against a player 0.04 a point either way.
local function WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	if crit == nil then
		return nil
	end
	local most = ctx.L * PER_LEVEL
	local sheet = crit - math.max(0, (sheetSkill or skill) - most) * 0.04
	if ctx.player then
		return Clamp(sheet + (skill - ctx.D) * 0.04)
	end
	local rated = math.min(most, skill) - ctx.D
	local chance = sheet + rated * (rated < 0 and 0.2 or 0.04)
	if ctx.T - ctx.L >= ABOVE then
		chance = chance - math.min(AURA_CRIT, math.max(0, sheet - (agility or 0)))
	end
	return Clamp(chance)
end

-- A swing: one roll. The cap is what the outcomes before crit leave; crit above it is pushed off the table, and over says so once more than half
-- of the tenth the table shows is lost, so a rounding of the game's numbers does not count. sheetSkill: the main hand's skill (WeaponCrit).
local function Swing(ctx, id, label, skill, hit, expertise, crit, agility, extra, sheetSkill)
	local parts = { miss = Miss(ctx, skill, hit, extra), dodge = Dodge(ctx, skill, expertise), parry = Parry(ctx, skill, expertise),
		glance = Glance(ctx, skill), block = Block(ctx, skill), resist = false }
	local cap = Roll(parts, { "miss", "dodge", "parry", "glance", "block" })
	local chance = WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	local line = { id = id, label = label, skill = skill, parts = parts, floor = 0, over = false }
	parts.cap = cap
	if cap ~= nil and chance ~= nil then
		line.over = chance > cap + OVER
		parts.crit = math.min(chance, cap)
		parts.hit = cap - parts.crit
	else
		parts.crit = chance
	end
	return line
end

-- A special attack: no glancing and no dual wield penalty, and crit rolled again on an attack that lands. sheetSkill: the main hand's skill
-- (WeaponCrit), which the hit table reads as skill.
local function Special(ctx, skill, hit, expertise, crit, agility, sheetSkill)
	local parts = { miss = Miss(ctx, skill, hit, 0), dodge = Dodge(ctx, skill, expertise), parry = Parry(ctx, skill, expertise), glance = false,
		block = Block(ctx, skill), cap = false, resist = false }
	parts.hit = Roll(parts, { "miss", "dodge", "parry", "block" })
	parts.crit = WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	return { id = "special", label = "Special", skill = skill, parts = parts, floor = 0, over = false }
end

-- A ranged attack: it cannot be dodged, parried or glance, and only blocked from the front (Ranged-Attack-Table.md:5, 254-287); crit rolled again.
-- sheetSkill: the ranged weapon's skill (WeaponCrit), which the hit table reads as skill.
local function Ranged(ctx, skill, hit, crit, agility, sheetSkill)
	local parts = { miss = Miss(ctx, skill, hit, 0), dodge = false, parry = false, glance = false, block = Block(ctx, skill), cap = false,
		resist = false }
	parts.hit = Roll(parts, { "miss", "block" })
	parts.crit = WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	return { id = "ranged", label = "Ranged", skill = skill, parts = parts, floor = 0, over = false }
end

-- The share of a spell's damage the enemy resists on average, in percent, with Spell Piercing pen: above 0 resisted, below 0 the damage a creature
-- takes more. The enemy's own resistances are not known and count as 0, so piercing takes them below 0: against a creature each point adds half
-- of what a point resists (Forever's Spell Vulnerability), against a player nothing. A creature above the player resists RESIST_LEVEL a level more,
-- which piercing does not lower; RESIST_CAP holds what is resisted. That is the share of a spell that does damage alone: a spell with an effect
-- beyond its damage (a slow, a root), which Classic resists whole or not at all, pays for the levels with its higher miss instead, and is resisted
-- whole only by the enemy's own resistance, counted as 0, so it takes the damage piercing adds alone (T = L). Nil when pen is not known. L the
-- player's level, T the enemy's, player: it is a player.
local function Resist(L, T, player, pen)
	if not (Finite(pen) and Finite(L) and L >= 1 and Finite(T)) then
		return nil
	end
	local per, own = RESIST_AVERAGE / (PER_LEVEL * L), -pen
	local resisted = player and 0 or RESIST_LEVEL * math.max(0, T - L)
	resisted = math.min(RESIST_CAP, resisted + per * math.max(0, own))
	local more = (not player and own < 0) and per / 2 * -own or 0
	return (1 - (1 - resisted) * (1 + more)) * 100
end
C.Resist = Resist

-- A spell. The chance to hit by the levels the enemy is above: 96, 95 and 94 up to two, then 11 less a level against a mob and 7 against a player,
-- 97 to 99 under (the game's own spellMissChances, Camelot/PaperDollFrameStats.lua:461, and Allakhazam's Hit Rate). Spell hit adds to it; Classic
-- tests cap it at 99, so 1% always misses, and the game's tooltip, which needs 17% against a boss (CR_DEFAULT_HIT_CAP_TOOLTIP), at 100. The crit is
-- the sheet's: no source found has it change with the enemy's level. The resist (Resist) takes nothing from the roll; the line keeps the piercing
-- it counted (pen) and whether a level of the enemy's counts in it (levelResist, an estimate).
local function Spell(ctx, hit, crit, pen)
	local floor = ctx.classic and 1 or 0
	local parts = { dodge = false, parry = false, glance = false, block = false, cap = false }
	if hit ~= nil then
		local above = ctx.T - ctx.L
		local chance = above <= 2 and math.min(99, 96 - above) or 94 - (above - 2) * (ctx.player and 7 or 11)
		parts.miss = math.max(floor, Clamp(Clamp(100 - chance) - hit))
		parts.hit = 100 - parts.miss
	end
	parts.crit = crit ~= nil and Clamp(crit) or nil
	parts.resist = Resist(ctx.L, ctx.T, ctx.player, pen)
	return { id = "spell", label = "Spell", parts = parts, floor = floor, over = false, pen = parts.resist ~= nil and pen or nil,
		levelResist = not ctx.player and ctx.T > ctx.L }
end

-- The reads and the table ---------------------------------------------------------------------------------------------------------------------------

-- Reads the game for the table: everything C.Table needs, nothing worked out. These are the reads the hit table always made, in the same order.
-- spec = { lines (Attacks), against, facing, kinds, rangedWithout, unit }. spec.unit is the unit the table is against (C.Target), the target when
-- nil. spec.kinds, when given, is the set of kinds to read ({ melee = true, ranged =
-- true, spell = true }) in place of C.Kinds(spec.lines, class, power); spec.rangedWithout reads the ranged kind with no ranged weapon worn: skill
-- level x 5, the ranged hit and the ranged crit (a judgement's line: the client's rows of the damaging judgements roll on the ranged table,
-- DefenseType 3 of SpellCategories, and which weapon skill counts without a ranged weapon no source says). The answer: { gaps, assumed, level,
-- class, power, feral, target, front, facingUnsure, kinds, agility,
-- melee = { expertise, offExpertise, crit, skill, sheetSkill, line, hit, dual, offSkill, offLine, offHit } (nil without melee),
-- ranged = { line, unknown, skill, sheetSkill, hit, crit, noWeapon } (nil without ranged), spell = { hit, crit, pen } (nil without spells; pen
-- the Spell Piercing of every school, GetSpellPenetration) }, with gaps
-- and assumed alone while the player's level cannot be read. sheetSkill is the skill the sheet's crit was read with (WeaponCrit): a caller that
-- changes skill leaves it as it is. The off hand's three are there while the player dual wields (dual); a ranged skill, hit and crit while a ranged
-- weapon is worn or, with noWeapon, while spec.rangedWithout asks for them.
function C.Inputs(spec)
	spec = type(spec) == "table" and spec or {}
	local inputs = { gaps = {}, assumed = {} }
	local level = Ask(UnitLevel, "player")
	if not Finite(level) or level < 1 then
		return inputs
	end
	level = math.floor(level)
	inputs.level = level
	local okClass, _, class = pcall(UnitClass, "player")
	if not okClass or IsSecret(class) then
		class = nil
	end
	local power = Ask(UnitPowerType, "player")
	local form = Ask(GetShapeshiftForm)
	inputs.class, inputs.power = class, power
	inputs.feral = class == "DRUID" and Finite(form) and form ~= 0
	local target = C.Target(spec.against, level, spec.unit)
	inputs.target = target
	inputs.front, inputs.facingUnsure = C.Front(spec.facing, target)
	local kinds = type(spec.kinds) == "table" and spec.kinds or C.Kinds(spec.lines, class, power)
	inputs.kinds = kinds
	inputs.agility = (kinds.melee or kinds.ranged) and AgilityCrit() or nil
	if kinds.melee then
		local melee = {}
		inputs.melee = melee
		melee.expertise, melee.offExpertise = Expertise(inputs)
		melee.crit = Crit(inputs, GetCritChance)
		melee.skill, melee.line = HandSkill(inputs, SLOTS.main, "main hand")
		melee.sheetSkill = melee.skill
		melee.hit = Hit(inputs, "melee", GetHitModifier)
		-- The game's own test of dual wielding (PlayerScriptDocumentation.lua:1297-1304, no secret tag; Camelot/PaperDollFrameStats.lua:469).
		if not inputs.feral and Ask(IsDualWielding) == true then
			melee.dual = true
			melee.offSkill, melee.offLine = HandSkill(inputs, SLOTS.off, "off hand")
			-- Forever has hit for the off hand alone (Dual Wield Specialization, Furious Precision), read as the sheet reads it (:525).
			melee.offHit = Hit(inputs, "melee", type(GetOffhandHitModifier) == "function" and GetOffhandHitModifier or GetHitModifier)
		end
	end
	if kinds.ranged then
		local ranged = {}
		inputs.ranged = ranged
		ranged.line, ranged.unknown = Line(inputs, SLOTS.ranged)
		local worn = not inputs.feral and RANGED[ranged.line]
		if worn or spec.rangedWithout then
			local skill = worn and Skill(ranged.line) or nil
			if not worn then
				ranged.noWeapon, skill = true, level * PER_LEVEL
			elseif not skill then
				inputs.assumed[#inputs.assumed + 1] = "ranged weapon"
				skill = level * PER_LEVEL
			end
			ranged.skill, ranged.sheetSkill = skill, skill
			ranged.hit = Hit(inputs, "ranged", GetRangedHitModifier)
			ranged.crit = Crit(inputs, GetRangedCritChance)
		end
	end
	if kinds.spell then
		local hit = Hit(inputs, "spell", GetSpellHitModifier)
		inputs.spell = { hit = hit, crit = Crit(inputs, GetSpellCritChance), pen = Piercing(inputs) }
	end
	return inputs
end

-- Works the table out from inputs (C.Inputs' answer, or a copy a caller changed), reading nothing, for spec = { special, rules }. The answer holds
-- level, target (C.Target), enemy, front, facingUnsure (the game did not say whether the target attacks the player), lines ({ id, label, skill, parts,
-- floor, over }, in the order shown; the Spell line also pen and levelResist, Spell), gaps (what the game withheld or refused, by name), assumed
-- (the hands whose skill stood in), offCritFromMain (the two hands hold weapons of two skill lines, while the off hand's crit is the main hand's),
-- noRanged (Ranged asked for with no ranged weapon worn) and rangedUnknown (the game did not say what the ranged slot holds); a ranged line asked
-- for with no ranged weapon (noWeapon) is there all the same. A part of a line is a number, false where it does not apply, and nil where the game
-- did not give what it needs; resist, the Spell line's alone, is below 0 for damage taken more. No line at all while the player's level cannot be
-- read. gaps and assumed are copies, so inputs stay as they were for the next table.
function C.Table(spec, inputs)
	spec = type(spec) == "table" and spec or {}
	local read = { gaps = {}, assumed = {}, lines = {} }
	if type(inputs) ~= "table" then
		return read
	end
	for what, why in pairs(type(inputs.gaps) == "table" and inputs.gaps or {}) do
		read.gaps[what] = why
	end
	for index, hand in ipairs(type(inputs.assumed) == "table" and inputs.assumed or {}) do
		read.assumed[index] = hand
	end
	local level, target = inputs.level, inputs.target
	if not Finite(level) or type(target) ~= "table" then
		return read
	end
	read.level, read.feral = level, inputs.feral
	read.target, read.enemy = target, target.enemy
	read.front, read.facingUnsure = inputs.front, inputs.facingUnsure
	local ctx = { L = level, T = target.level, D = target.level * PER_LEVEL, player = target.player == true, front = read.front,
		classic = spec.rules ~= "game" }
	local agility, melee, ranged, spell = inputs.agility, inputs.melee, inputs.ranged, inputs.spell
	if type(melee) == "table" then
		local skill, sheetSkill = melee.skill, melee.sheetSkill
		if melee.dual then
			-- The off hand's crit is the main hand's: a crit talent for one kind of weapon (Axe, Polearm, Dagger and Fist Weapon Specialization) counts
			-- in it only for the main hand's kind, so with two kinds of weapon the Off line's crit may be off by that talent, which /flatui status says.
			read.offCritFromMain = melee.crit ~= nil and melee.line ~= nil and melee.offLine ~= nil and melee.line ~= melee.offLine
			read.lines[#read.lines + 1] = Swing(ctx, "main", "Main", skill, melee.hit, melee.expertise, melee.crit, agility, DUAL_WIELD, sheetSkill)
			read.lines[#read.lines + 1] = Swing(ctx, "off", "Off", melee.offSkill, melee.offHit, melee.offExpertise, melee.crit, agility, DUAL_WIELD,
				sheetSkill)
		else
			read.lines[#read.lines + 1] = Swing(ctx, "swing", "Swing", skill, melee.hit, melee.expertise, melee.crit, agility, 0, sheetSkill)
		end
		if spec.special then
			read.lines[#read.lines + 1] = Special(ctx, skill, melee.hit, melee.expertise, melee.crit, agility, sheetSkill)
		end
	end
	if type(ranged) == "table" then
		if ranged.skill == nil or ranged.noWeapon then
			if ranged.unknown then
				read.rangedUnknown = true
			else
				read.noRanged = true
			end
		end
		if ranged.skill ~= nil then
			read.lines[#read.lines + 1] = Ranged(ctx, ranged.skill, ranged.hit, ranged.crit, agility, ranged.sheetSkill)
		end
	end
	if type(spell) == "table" then
		read.lines[#read.lines + 1] = Spell(ctx, spell.hit, spell.crit, spell.pen)
	end
	return read
end

-- The table for the rows of the hit table, spec = { lines (Attacks), special, against, facing, rules }: the reads of C.Inputs, worked out by C.Table.
function C.Read(spec)
	return C.Table(spec, C.Inputs(spec))
end
