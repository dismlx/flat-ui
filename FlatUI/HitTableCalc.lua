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
-- GetExpertise in points of dodge and parry taken off (Camelot/PaperDollFrame.lua:546-574). Each of those is SecretWhenUnitStatsRestricted
-- (PlayerScriptDocumentation.lua): a withheld value is never compared, added or kept, and every part that needs it is unknown (nil), which the
-- table shows as ?. A call that raises counts the same; a client without a modifier has none of it. The target's level, kind and whether it can be
-- attacked carry no secret tag (UnitDocumentation.lua). A level the game shows as ?? (UnitEffectiveLevel 0 or less, Mainline/TargetFrame.lua:297-315)
-- counts as three levels above the player.
--
-- The rules are those of Classic's attack table, which Forever keeps (Forever hunter wiki, Ranged-Attack-Table.md:11-23), as tests of Classic found
-- them (magey's Classic warrior wiki, Attack-table.md, with the posts of Blizzard it quotes at :22-33). D is five times the target's level and d is D
-- less the weapon skill. A swing is one roll: miss, dodge, parry, glancing blow, block, crit and hit each take their chance in that order from what is
-- left, so the crit cap is what the outcomes before crit leave (:184-347). A special attack, a ranged attack and a spell roll crit again on an attack
-- that lands (Ranged-Attack-Table.md:291-310), so their crit is a chance of its own and their hit is everything that lands.

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

-- The skill of a line, rank plus modifier, or nil when the player has no such line or the game says nothing.
local function Skill(line)
	local api = C_SkillInfo
	if line == nil or type(api) ~= "table" or type(api.GetSkillLineInfoByID) ~= "function" then
		return nil
	end
	local ok, rank, modifier = pcall(function()
		local info = api.GetSkillLineInfoByID(line)
		if IsSecret(info) or type(info) ~= "table" then
			return nil, nil
		end
		return info.rank, info.modifier
	end)
	if ok and Finite(rank) then
		return rank + (Finite(modifier) and modifier or 0)
	end
	return nil
end

-- The weapon skill of a melee hand. When the game gives none, the most for the player's level stands in, and the hand is named for /flatui status.
local function HandSkill(read, slot, name)
	local line, unknown = Line(read, slot)
	local skill = not unknown and Skill(line) or nil
	if skill then
		return skill
	end
	read.assumed[#read.assumed + 1] = name
	return read.level * PER_LEVEL
end

-- The enemy the table is worked out against: level, unknown (shown ??), kind ("boss", "elite"... from ns.UnitKind), player, none (no enemy targeted:
-- one of the player's level), boss (Against a boss), and enemy: the target can be attacked and is alive.
function C.Target(against, level)
	local target = { level = level }
	target.enemy = Ask(UnitExists, "target") == true and Ask(UnitCanAttack, "player", "target") == true
		and Ask(UnitIsDeadOrGhost, "target") ~= true
	if against == "boss" then
		target.level, target.kind, target.boss = level + ABOVE, "boss", true
	elseif target.enemy then
		local seen = Ask(UnitEffectiveLevel, "target")
		if not Finite(seen) then
			seen = Ask(UnitLevel, "target")
		end
		if Finite(seen) and seen > 0 then
			target.level = math.floor(seen)
		else
			target.level, target.unknown = level + ABOVE, true
		end
		target.kind = ns.UnitKind("target")
		target.player = Ask(UnitIsPlayer, "target") == true
	else
		target.none = true
	end
	return target
end

-- True while the table counts parries and blocks: In front, or the first choice while the target's own target is the player. UnitIsUnit may be
-- withheld (SecretWhenUnitComparisonRestricted, UnitDocumentation.lua:2410-2426), and then the player counts as behind.
function C.Front(facing, enemy)
	if facing == "front" then
		return true
	elseif facing ~= "auto" or not enemy then
		return false
	end
	return Ask(UnitIsUnit, "targettarget", "player") == true
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
-- players only, so it comes off first. Against a mob the skill, counted up to that most, changes crit 0.2 a point under the mob's defense and 0.04
-- over it, and an enemy three levels above also takes up to AURA_CRIT of the crit that comes from auras: the sheet's crit less what agility gives
-- (Attack-table.md:155-182). Against a player 0.04 a point either way.
local function WeaponCrit(ctx, skill, crit, agility)
	if crit == nil then
		return nil
	end
	local most = ctx.L * PER_LEVEL
	local sheet = crit - math.max(0, skill - most) * 0.04
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
-- of the tenth the table shows is lost, so a rounding of the game's numbers does not count.
local function Swing(ctx, id, label, skill, hit, expertise, crit, agility, extra)
	local parts = { miss = Miss(ctx, skill, hit, extra), dodge = Dodge(ctx, skill, expertise), parry = Parry(ctx, skill, expertise),
		glance = Glance(ctx, skill), block = Block(ctx, skill) }
	local cap = Roll(parts, { "miss", "dodge", "parry", "glance", "block" })
	local chance = WeaponCrit(ctx, skill, crit, agility)
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

-- A special attack: no glancing and no dual wield penalty, and crit rolled again on an attack that lands.
local function Special(ctx, skill, hit, expertise, crit, agility)
	local parts = { miss = Miss(ctx, skill, hit, 0), dodge = Dodge(ctx, skill, expertise), parry = Parry(ctx, skill, expertise), glance = false,
		block = Block(ctx, skill), cap = false }
	parts.hit = Roll(parts, { "miss", "dodge", "parry", "block" })
	parts.crit = WeaponCrit(ctx, skill, crit, agility)
	return { id = "special", label = "Special", skill = skill, parts = parts, floor = 0, over = false }
end

-- A ranged attack: it cannot be dodged, parried or glance, and only blocked from the front (Ranged-Attack-Table.md:5, 254-287); crit rolled again.
local function Ranged(ctx, skill, hit, crit, agility)
	local parts = { miss = Miss(ctx, skill, hit, 0), dodge = false, parry = false, glance = false, block = Block(ctx, skill), cap = false }
	parts.hit = Roll(parts, { "miss", "block" })
	parts.crit = WeaponCrit(ctx, skill, crit, agility)
	return { id = "ranged", label = "Ranged", skill = skill, parts = parts, floor = 0, over = false }
end

-- A spell. The chance to hit by the levels the enemy is above: 96, 95 and 94 up to two, then 11 less a level against a mob and 7 against a player,
-- 97 to 99 under (the game's own spellMissChances, Camelot/PaperDollFrameStats.lua:461, and Allakhazam's Hit Rate). Spell hit adds to it; Classic
-- tests cap it at 99, so 1% always misses, and the game's tooltip, which needs 17% against a boss (CR_DEFAULT_HIT_CAP_TOOLTIP), at 100. The crit is
-- the sheet's: no source found has it change with the enemy's level.
local function Spell(ctx, hit, crit)
	local floor = ctx.classic and 1 or 0
	local parts = { dodge = false, parry = false, glance = false, block = false, cap = false }
	if hit ~= nil then
		local above = ctx.T - ctx.L
		local chance = above <= 2 and math.min(99, 96 - above) or 94 - (above - 2) * (ctx.player and 7 or 11)
		parts.miss = math.max(floor, Clamp(Clamp(100 - chance) - hit))
		parts.hit = 100 - parts.miss
	end
	parts.crit = crit ~= nil and Clamp(crit) or nil
	return { id = "spell", label = "Spell", parts = parts, floor = floor, over = false }
end

-- The table for the rows of the hit table: spec = { lines (Attacks), special, against, facing, rules }. The answer holds level, target (C.Target),
-- enemy, front, lines ({ id, label, skill, parts, floor, over }, in the order shown), gaps (what the game withheld or refused, by name), assumed (the
-- hands whose skill stood in), noRanged (Ranged asked for with no ranged weapon worn) and rangedUnknown (the game did not say what the ranged slot
-- holds). A part of a line is a number, false where it does not apply, and nil where the game did not give what it needs. No line at all while the
-- player's level cannot be read.
function C.Read(spec)
	local read = { gaps = {}, assumed = {}, lines = {} }
	local level = Ask(UnitLevel, "player")
	if not Finite(level) or level < 1 then
		return read
	end
	level = math.floor(level)
	read.level = level
	local okClass, _, class = pcall(UnitClass, "player")
	if not okClass or IsSecret(class) then
		class = nil
	end
	local power = Ask(UnitPowerType, "player")
	local form = Ask(GetShapeshiftForm)
	read.feral = class == "DRUID" and Finite(form) and form ~= 0
	local target = C.Target(spec.against, level)
	read.target, read.enemy = target, target.enemy
	read.front = C.Front(spec.facing, target.enemy)
	local ctx = { L = level, T = target.level, D = target.level * PER_LEVEL, player = target.player == true, front = read.front,
		classic = spec.rules ~= "game" }
	local kinds = C.Kinds(spec.lines, class, power)
	local agility = (kinds.melee or kinds.ranged) and AgilityCrit() or nil
	if kinds.melee then
		local expertise, offExpertise = Expertise(read)
		local crit = Crit(read, GetCritChance)
		local skill = HandSkill(read, SLOTS.main, "main hand")
		local hit = Hit(read, "melee", GetHitModifier)
		-- The game's own test of dual wielding (PlayerScriptDocumentation.lua:1297-1304, no secret tag; Camelot/PaperDollFrameStats.lua:469).
		if not read.feral and Ask(IsDualWielding) == true then
			local offSkill = HandSkill(read, SLOTS.off, "off hand")
			-- Forever has hit for the off hand alone (Dual Wield Specialization, Furious Precision), read as the sheet reads it (:525).
			local offHit = Hit(read, "melee", type(GetOffhandHitModifier) == "function" and GetOffhandHitModifier or GetHitModifier)
			read.lines[#read.lines + 1] = Swing(ctx, "main", "Main", skill, hit, expertise, crit, agility, DUAL_WIELD)
			read.lines[#read.lines + 1] = Swing(ctx, "off", "Off", offSkill, offHit, offExpertise, crit, agility, DUAL_WIELD)
		else
			read.lines[#read.lines + 1] = Swing(ctx, "swing", "Swing", skill, hit, expertise, crit, agility, 0)
		end
		if spec.special then
			read.lines[#read.lines + 1] = Special(ctx, skill, hit, expertise, crit, agility)
		end
	end
	if kinds.ranged then
		local line, unknown = Line(read, SLOTS.ranged)
		if not read.feral and RANGED[line] then
			local skill = Skill(line)
			if not skill then
				read.assumed[#read.assumed + 1] = "ranged weapon"
				skill = level * PER_LEVEL
			end
			read.lines[#read.lines + 1] = Ranged(ctx, skill, Hit(read, "ranged", GetRangedHitModifier), Crit(read, GetRangedCritChance), agility)
		elseif unknown then
			read.rangedUnknown = true
		else
			read.noRanged = true
		end
	end
	if kinds.spell then
		read.lines[#read.lines + 1] = Spell(ctx, Hit(read, "spell", GetSpellHitModifier), Crit(read, GetSpellCritChance))
	end
	return read
end
