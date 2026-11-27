local _, ns = ...

local C = {}
ns.HitTableCalc = C

local IsSecret, Finite = ns.IsSecret, ns.Finite

local CR_HIT = { melee = 6, ranged = 7, spell = 8 }
local AGILITY = 2
local SLOTS = { main = 16, off = 17, ranged = 18 }
local WEAPON = 2
local SKILL_OF = { [0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55, [10] = 136, [13] = 162, [15] = 173,
	[16] = 176, [18] = 226, [19] = 228 }
local RANGED = { [45] = true, [46] = true, [176] = true, [226] = true, [228] = true }
local UNARMED, FERAL = 162, 3014
local PER_LEVEL, ABOVE = 5, 3
local DUAL_WIELD = 19
local AURA_CRIT, BOSS_PARRY = 1.8, 7.5
local FERAL_POWER = { [1] = true, [3] = true }
local KITS = {
	WARRIOR = { melee = true }, ROGUE = { melee = true }, HUNTER = { ranged = true }, PALADIN = { melee = true, spell = true },
	SHAMAN = { melee = true, spell = true }, MAGE = { spell = true }, PRIEST = { spell = true }, WARLOCK = { spell = true },
}
local OVER = 0.05
local TANKING = 2
local RESIST_AVERAGE, RESIST_CAP, RESIST_LEVEL = 0.75, 0.75, 0.02
local RANK = { withheld = 3, refused = 2, missing = 1 }

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

local function Ask(fn, ...)
	local value, why = Call(fn, ...)
	if why then
		return nil
	end
	return value
end

local function Gap(read, what, why)
	local had = read.gaps[what]
	if RANK[why] and (had == nil or RANK[why] > RANK[had]) then
		read.gaps[what] = why
	end
end

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

local function Crit(read, fn)
	local value, why = Call(fn)
	if why or not Finite(value) then
		Gap(read, "crit", why or "refused")
		return nil
	end
	return value
end

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

local function LineOf(item)
	if not (Finite(item) or (not IsSecret(item) and type(item) == "string")) then
		return nil, true
	end
	local api = C_Item
	if type(api) ~= "table" or type(api.GetItemInfoInstant) ~= "function" then
		return nil, true
	end
	local ok, _, _, _, _, _, classID, subclassID = pcall(api.GetItemInfoInstant, item)
	if not ok or IsSecret(classID) or IsSecret(subclassID) or classID == nil then
		return nil, true
	elseif classID ~= WEAPON then
		return nil
	end
	return SKILL_OF[subclassID]
end
C.LineOf = LineOf

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

local function Skill(line)
	local got = SkillLine(line)
	return got and got.rank + got.modifier or nil
end
C.Skill = Skill

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

local function Clamp(value)
	return math.max(0, math.min(100, value))
end

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

local function Step(ctx)
	return ctx.player and 0.04 or 0.1
end

local function Before(ctx, skill)
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
	return math.max(0, miss), lost
end

local function Miss(ctx, skill, hit, extra)
	if hit == nil then
		return nil
	end
	local miss, lost = Before(ctx, skill)
	local counted = hit > 0 and math.max(0, hit - lost) or hit
	return Clamp(miss + extra - counted)
end

local function Need(ctx, skill, extra)
	local miss, lost = Before(ctx, skill)
	return miss + extra + lost
end

local function Dodge(ctx, skill, expertise)
	if expertise == nil then
		return nil
	end
	return Clamp(5 + (ctx.D - skill) * Step(ctx) - expertise)
end

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

local function Glance(ctx, skill)
	if ctx.player then
		return false
	end
	return Clamp(10 + (ctx.D - math.min(ctx.L * PER_LEVEL, skill)) * 2)
end

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

local function Swing(ctx, id, label, skill, hit, expertise, crit, agility, extra, sheetSkill)
	local parts = { miss = Miss(ctx, skill, hit, extra), dodge = Dodge(ctx, skill, expertise), parry = Parry(ctx, skill, expertise),
		glance = Glance(ctx, skill), block = Block(ctx, skill), resist = false }
	local cap = Roll(parts, { "miss", "dodge", "parry", "glance", "block" })
	local chance = WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	local line = { id = id, label = label, skill = skill, parts = parts, floor = 0, over = false, need = Need(ctx, skill, extra) }
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

local function Special(ctx, skill, hit, expertise, crit, agility, sheetSkill)
	local parts = { miss = Miss(ctx, skill, hit, 0), dodge = Dodge(ctx, skill, expertise), parry = Parry(ctx, skill, expertise), glance = false,
		block = Block(ctx, skill), cap = false, resist = false }
	parts.hit = Roll(parts, { "miss", "dodge", "parry", "block" })
	parts.crit = WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	return { id = "special", label = "Special", skill = skill, parts = parts, floor = 0, over = false, need = Need(ctx, skill, 0) }
end

local function Ranged(ctx, skill, hit, crit, agility, sheetSkill)
	local parts = { miss = Miss(ctx, skill, hit, 0), dodge = false, parry = false, glance = false, block = Block(ctx, skill), cap = false,
		resist = false }
	parts.hit = Roll(parts, { "miss", "block" })
	parts.crit = WeaponCrit(ctx, skill, crit, agility, sheetSkill)
	return { id = "ranged", label = "Ranged", skill = skill, parts = parts, floor = 0, over = false, need = Need(ctx, skill, 0) }
end

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

local function Spell(ctx, hit, crit, pen)
	local floor = ctx.classic and 1 or 0
	local parts = { dodge = false, parry = false, glance = false, block = false, cap = false }
	local above = ctx.T - ctx.L
	local chance = above <= 2 and math.min(99, 96 - above) or 94 - (above - 2) * (ctx.player and 7 or 11)
	local before = Clamp(100 - chance)
	if hit ~= nil then
		parts.miss = math.max(floor, Clamp(before - hit))
		parts.hit = 100 - parts.miss
	end
	parts.crit = crit ~= nil and Clamp(crit) or nil
	parts.resist = Resist(ctx.L, ctx.T, ctx.player, pen)
	return { id = "spell", label = "Spell", parts = parts, floor = floor, over = false, pen = parts.resist ~= nil and pen or nil,
		levelResist = not ctx.player and ctx.T > ctx.L, need = math.max(0, before - floor) }
end

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
		if not inputs.feral and Ask(IsDualWielding) == true then
			melee.dual = true
			melee.offSkill, melee.offLine = HandSkill(inputs, SLOTS.off, "off hand")
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

function C.Read(spec)
	return C.Table(spec, C.Inputs(spec))
end
