local _, ns = ...

ns.StatTips = ns.StatTips or {}
ns.StatTips.text = ns.StatTips.text or {}

local IsSecret, Finite = ns.IsSecret, ns.Finite
local TEXT = ns.StatTips.text

local K = {
	STR = 1, AGI = 2, STA = 3, INT = 4, SPI = 5, MANA = 0, ENERGY = 3, SCHOOLS = { 2, 3, 4, 5, 6, 7 },
	STAMINA_BREAK = 20, MANA_PER_INTELLECT = 15, AP_PER_DPS = 14, ARMOR_PER_AGILITY = 2, BLOCK_PER_STRENGTH = 20, RUN = 7,
	IMP = 23, IMP_REGEN = 0.3, PET_REGEN = 0.1,
	CAST = 3,
	NO_MANA = { WARRIOR = true, ROGUE = true }, BLOCKERS = { WARRIOR = true, PALADIN = true, SHAMAN = true },
	RANGED_CLASS = { WARRIOR = true, HUNTER = true, ROGUE = true },
	NAMES = { swing = "Weapon attacks", main = "Main hand swings", off = "Off hand swings", special = "Abilities", ranged = "Ranged",
		spell = "Spells" },
	HEADER = "In plain words", COLUMNS = ns.StatTips.COLUMNS or "Level %d  ·  Boss %d", COLUMN = ns.StatTips.COLUMN or "Level %d",
	BOTH = ns.StatTips.BOTH or "%s  ·  %s", OLD = ns.StatTips.OLD or "From before the fight: the game hides your stats during one.",
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 } },
}

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

local function Number(fn, ...)
	local value = Ask(fn, ...)
	return Finite(value) and value or nil
end

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

local function Read(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return Plainly(pcall(fn, ...))
end

local function Stat(unit, index)
	local ok, _, value = Read(UnitStat, unit, index)
	return ok and Finite(value) and value or nil
end

local function Power(fn, unit)
	local ok, base, plus, minus = Read(fn, unit)
	if not (ok and Finite(base)) then
		return nil
	end
	return math.max(0, base + (Finite(plus) and plus or 0) + (Finite(minus) and minus or 0))
end

local function StatsPlain()
	local api = C_Secrets
	local fn = type(api) == "table" and api.ShouldUnitStatsBeSecret or nil
	if type(fn) ~= "function" then
		return true
	end
	local ok, secret = pcall(fn)
	return ok and not IsSecret(secret) and secret == false
end

local function ClassOf()
	local ok, _, class = pcall(UnitClass, "player")
	if ok and not IsSecret(class) and type(class) == "string" then
		return class
	end
	return nil
end

local function Stats()
	local M = ns.SpellModel
	if type(M) ~= "table" or type(M.Stats) ~= "function" then
		return nil
	end
	local ok, stats = pcall(M.Stats)
	if ok and type(stats) == "table" and not stats.old and type(stats.per) == "table" then
		return stats
	end
	return nil
end

local function PerPoint(stats, index)
	local per = stats and stats.per[index]
	return type(per) == "table" and per or {}
end

local function Option(path)
	return type(ns.Get) == "function" and Ask(ns.Get, path) or nil
end

local function Trim(text)
	text = text:gsub("(%.%d-)0+$", "%1")
	return (text:gsub("%.$", ""))
end

local function Big(whole)
	local broken = Ask(BreakUpLargeNumbers, whole)
	if not IsSecret(broken) and type(broken) == "string" and broken ~= "" then
		return broken
	end
	return ("%d"):format(whole)
end

local function Num(x)
	if not Finite(x) then
		return "?"
	end
	local size = math.abs(x)
	local text = size >= 100 and Big(math.floor(size + 0.5)) or Trim(("%.1f"):format(size))
	if x < 0 and text ~= "0" then
		text = "-" .. text
	end
	return text
end

local function Pct(x)
	if not Finite(x) then
		return "?"
	elseif math.abs(x) < 0.05 then
		return "0%"
	end
	return Trim(("%.1f"):format(x)) .. "%"
end

local function Secs(x)
	return Trim(("%.2f"):format(x)) .. " sec"
end

local function Span(x)
	local whole = math.floor(x + 0.5)
	if whole < 60 then
		return whole .. " sec"
	end
	local minutes, seconds = math.floor(whole / 60), whole % 60
	if seconds == 0 or minutes >= 10 then
		return minutes .. " min"
	end
	return minutes .. " min " .. seconds .. " sec"
end

local S = { style = K.STYLE, tip = nil, headed = false }

local function Style()
	local M = ns.SpellModel
	local fmt = type(M) == "table" and M.Fmt or nil
	local style = type(fmt) == "table" and fmt.Style or nil
	if type(style) == "table" and type(style.header) == "table" and type(style.label) == "table" and type(style.value) == "table"
		and type(style.dim) == "table" then
		return style
	end
	return K.STYLE
end

local function Head()
	if S.headed then
		return
	end
	S.headed = true
	local c = S.style.header
	S.tip:AddLine(" ")
	S.tip:AddLine(K.HEADER, c[1], c[2], c[3])
end

local function Pair(left, right)
	Head()
	local l, v = S.style.label, S.style.value
	S.tip:AddDoubleLine(left, right, l[1], l[2], l[3], v[1], v[2], v[3])
end

local function Columns(left, t)
	Head()
	local l = S.style.label
	local level = t and t.inputs and t.inputs.level
	local right = ""
	if Finite(level) then
		right = t.bossLevel and K.COLUMNS:format(level, t.bossLevel) or K.COLUMN:format(level)
	end
	S.tip:AddDoubleLine(left, right, l[1], l[2], l[3], l[1], l[2], l[3])
end

local function Note(text)
	Head()
	local d = S.style.dim
	S.tip:AddLine(text, d[1], d[2], d[3], true)
end

local kept = {}

local function Entry(token, read, write, variant)
	TEXT[token] = function(tip, unit)
		if unit ~= "pet" then
			unit = "player"
		end
		local key = token .. " " .. unit
		if variant then
			key = key .. " " .. tostring(variant(unit))
		end
		local data = nil
		if StatsPlain() then
			data = read(unit)
		end
		local old = false
		if data == false then
			kept[key] = nil
			return
		elseif data == nil then
			data, old = kept[key], true
			if data == nil then
				return
			end
		else
			kept[key] = data
		end
		S.style, S.tip, S.headed = Style(), tip, false
		write(data, unit)
		if old and S.headed then
			Note(K.OLD)
		end
	end
end

local function ReadStamina(unit)
	if unit ~= "player" then
		return false
	end
	local stamina, per, most = Stat("player", K.STA), Number(UnitHPPerStamina, "player"), Number(UnitHealthMax, "player")
	if not (stamina and per and most) then
		return nil
	elseif most <= 0 then
		return false
	end
	stamina = math.max(0, stamina)
	local from = math.min(K.STAMINA_BREAK, stamina) + (math.max(K.STAMINA_BREAK, stamina) - K.STAMINA_BREAK) * per
	return { per = per, most = most, from = math.min(from, most) }
end

Entry("HEALTH", ReadStamina, function(d)
	Pair("From your Stamina", Num(d.from) .. " of " .. Num(d.most))
	Pair("Without your Stamina", Num(d.most - d.from))
end)

Entry("STAMINA", ReadStamina, function(d)
	Pair("1 Stamina", "+" .. Num(d.per) .. " health")
	Pair("Your Stamina gives", Pct(d.from / d.most * 100) .. " of your health")
end)

local function PowerType(unit)
	return Number(UnitPowerType, unit)
end

local function PetRegen()
	if ClassOf() ~= "WARLOCK" then
		return false
	end
	local most = Number(UnitPowerMax, "pet", K.MANA)
	if most == nil then
		return nil
	elseif most <= 0 then
		return false
	end
	local intellect = Stat("player", K.INT)
	if not intellect then
		return nil
	end
	local ok, _, family = Read(UnitCreatureFamily, "pet")
	local share = (ok and family == K.IMP) and K.IMP_REGEN or K.PET_REGEN
	return { most = most, per = share, regen = math.floor(math.max(0, intellect) * share) }
end

local function ManaRegen()
	local ok, base, casting = Read(GetManaRegen)
	if ok and Finite(base) and Finite(casting) then
		return math.max(0, base), math.max(0, casting)
	end
	return nil
end

Entry("POWER", function(unit)
	local kind = PowerType(unit)
	if kind == nil then
		return nil
	elseif unit == "pet" then
		if kind ~= K.MANA then
			return false
		end
		return PetRegen()
	elseif kind == K.MANA then
		local most = Number(UnitPowerMax, "player", K.MANA)
		local base = ManaRegen()
		if not (most and base) then
			return nil
		end
		return { mana = true, most = most, base = base }
	elseif kind == K.ENERGY then
		local most = Number(UnitPowerMax, "player", K.ENERGY)
		local ok, regen = Read(GetPowerRegen)
		if not (most and ok and Finite(regen)) then
			return nil
		end
		return { energy = true, most = most, regen = regen }
	end
	return false
end, function(d, unit)
	if unit == "pet" then
		Pair("Back every 5 sec", "+" .. Num(d.regen) .. ", from your Intellect")
		if d.regen > 0 then
			Pair("Empty to full", Span(d.most / d.regen * 5))
		end
	elseif d.mana then
		if d.base > 0 then
			Pair("Empty to full, spending none", Span(d.most / d.base))
		end
		Pair("1 Intellect", "+" .. K.MANA_PER_INTELLECT .. " mana")
		Note("Spirit refills mana only once you have spent none for 5 sec; the Spirit row says how much.")
	elseif d.energy then
		Pair("Back each second", "+" .. Num(d.regen) .. " energy")
		if d.regen > 0 and d.most > 0 then
			Pair("Empty to full", Span(d.most / d.regen))
		end
	end
end, PowerType)

Entry("MANAREGEN", function(unit)
	if unit ~= "pet" then
		return false
	end
	return PetRegen()
end, function(d)
	Pair("1 of your Intellect", "+" .. Trim(("%.1f"):format(d.per)) .. " every 5 sec")
	if d.regen > 0 then
		Pair("Empty to full", Span(d.most / d.regen * 5))
	end
	Note("Like yours, the pet's mana comes back only once it has spent none for 5 sec.")
end)

Entry("MOVESPEED", function(unit)
	local ok, _, run, _, swim = Read(GetUnitSpeed, unit)
	if not (ok and Finite(run) and Finite(swim)) then
		return nil
	end
	return { run = run, swim = unit ~= "pet" and swim or nil }
end, function(d)
	Pair("Running", Trim(("%.1f"):format(d.run)) .. " yards a second")
	if d.swim then
		Pair("Swimming", Trim(("%.1f"):format(d.swim)) .. " yards a second")
	end
	Note("100% is a normal run: " .. K.RUN .. " yards a second.")
end)

Entry("STRENGTH", function(unit)
	if unit ~= "player" then
		return false
	end
	local stats = Stats()
	if not stats then
		return nil
	end
	local per = PerPoint(stats, K.STR)
	local api = C_PaperDollInfo
	local shield = type(api) == "table" and Ask(api.OffhandHasShield) == true
	return { ap = Finite(per.ap) and per.ap or nil, rap = Finite(per.rap) and per.rap or nil, block = shield and K.BLOCKERS[ClassOf() or ""] }
end, function(d)
	if d.ap and d.ap > 0 then
		Pair("Attack power", "+" .. Num(d.ap) .. " a point")
		Pair("1 more melee damage a second takes", Num(K.AP_PER_DPS / d.ap) .. " Strength")
	else
		Pair("Attack power", "none from Strength now")
	end
	if d.rap and d.rap > 0 then
		Pair("Ranged attack power", "+" .. Num(d.rap) .. " a point")
	end
	if d.block then
		Pair("Block value", "+1 for " .. K.BLOCK_PER_STRENGTH .. " Strength")
	end
end)

Entry("AGILITY", function(unit)
	if unit ~= "player" then
		return false
	end
	local stats = Stats()
	if not stats then
		return nil
	end
	local per = PerPoint(stats, K.AGI)
	return { crit = Finite(per.crit) and per.crit or nil, ap = Finite(per.ap) and per.ap or nil, rap = Finite(per.rap) and per.rap or nil,
		mana = not K.NO_MANA[ClassOf() or ""] }
end, function(d)
	if d.crit and d.crit > 0 then
		Pair("1% crit takes", Num(1 / d.crit) .. " Agility")
	end
	if d.ap and d.ap > 0 then
		Pair("Attack power", "+" .. Num(d.ap) .. " a point")
	end
	if d.rap and d.rap > 0 then
		Pair("Ranged attack power", "+" .. Num(d.rap) .. " a point")
	end
	Pair("Armor", "+" .. K.ARMOR_PER_AGILITY .. " a point")
	if d.mana then
		Note("Its crit is for weapon attacks: spells take their crit from Intellect.")
	end
end)

Entry("INTELLECT", function(unit)
	if unit ~= "player" then
		return false
	end
	local class = ClassOf()
	if class == nil then
		return nil
	elseif K.NO_MANA[class] then
		return { none = true }
	end
	local stats = Stats()
	if not stats then
		return nil
	end
	local per = PerPoint(stats, K.INT)
	return { crit = Finite(per.spellCrit) and per.spellCrit or nil }
end, function(d)
	if d.none then
		Note("You have no mana, so in a fight Intellect does nothing for you: it only makes your weapon skills rise faster.")
		return
	end
	Pair("Mana", "+" .. K.MANA_PER_INTELLECT .. " a point")
	if d.crit and d.crit > 0 then
		Pair("1% spell crit takes", Num(1 / d.crit) .. " Intellect")
	end
end)

Entry("SPIRIT", function(unit)
	if unit ~= "player" then
		return false
	end
	local class = ClassOf()
	if class == nil then
		return nil
	elseif K.NO_MANA[class] then
		return { none = true }
	end
	local base, casting = ManaRegen()
	if not base then
		return nil
	end
	return { base = base * 5, casting = casting * 5 }
end, function(d)
	if d.none then
		Note("You have no mana, so Spirit only brings your health back faster out of combat. In a fight it does nothing.")
		return
	end
	Pair("Mana back, spending none", "+" .. Num(d.base) .. " every 5 sec")
	Pair("Mana back while casting", "+" .. Num(d.casting) .. " every 5 sec")
	Note("The five-second rule: Spirit refills mana only once you have spent none for 5 sec. It pays off in pauses between casts and fights; "
		.. "casting without a break you get the second number.")
end)

local function Calc()
	local C = ns.HitTableCalc
	if type(C) == "table" and type(C.Inputs) == "function" and type(C.Table) == "function" and type(C.Target) == "function"
		and type(C.Kinds) == "function" then
		return C
	end
	return nil
end

local function ById(read)
	local lines = {}
	for _, line in ipairs(type(read) == "table" and type(read.lines) == "table" and read.lines or {}) do
		if type(line) == "table" and type(line.id) == "string" then
			lines[line.id] = line
		end
	end
	return lines
end

local function Tables(kinds)
	local C = Calc()
	if not C then
		return false
	end
	if kinds == nil then
		local okKinds, chosen = pcall(C.Kinds, Option("hud.hitTableLines") or "auto", ClassOf(), PowerType("player"))
		kinds = okKinds and type(chosen) == "table" and chosen or { melee = true }
	end
	local ok, inputs = pcall(C.Inputs, { kinds = kinds, against = "level", facing = "behind" })
	if not ok or type(inputs) ~= "table" or not Finite(inputs.level) then
		return nil
	end
	for _, why in pairs(type(inputs.gaps) == "table" and inputs.gaps or {}) do
		if why == "withheld" then
			return nil
		end
	end
	local rules = Option("hud.hitTableRules") == "game" and "game" or "classic"
	local spec = { special = true, rules = rules }
	local function Against(against)
		local copy = {}
		for field, value in pairs(inputs) do
			copy[field] = value
		end
		copy.target, copy.front = C.Target(against, inputs.level), false
		return ById(C.Table(spec, copy))
	end
	local bossLevel = nil
	local avoid = ns.GearAvoid
	if type(avoid) == "table" and type(avoid.Against) == "function" then
		local okAt, at, isBoss = pcall(avoid.Against, inputs.level)
		if okAt and Finite(at) and isBoss == true then
			bossLevel = at
		end
	end
	return { inputs = inputs, level = Against("level"), boss = bossLevel and Against("boss") or nil, bossLevel = bossLevel, rules = rules }
end

local function Join(t, x, y)
	if t.boss then
		return K.BOTH:format(x, y)
	end
	return x
end

local function Both(t, id, part)
	local a, b = t.level[id], t.boss and t.boss[id]
	local x, y = a and a.parts[part], b and b.parts[part]
	if Finite(x) and (Finite(y) or not t.boss) then
		return Join(t, Pct(x), Finite(y) and Pct(y) or nil)
	end
	return nil
end

local function WeaponLine(t)
	if t.level.special then
		return "special"
	end
	return t.level.swing and "swing" or nil
end

local function Ids(...)
	local ids = {}
	for index = 1, select("#", ...) do
		local id = select(index, ...)
		if id then
			ids[#ids + 1] = id
		end
	end
	return ids
end

local function Label(id, dual)
	if id == "special" or id == "swing" then
		return dual and K.NAMES.special or K.NAMES.swing
	end
	return K.NAMES[id]
end

local function HitOf(inputs, id)
	if id == "off" then
		return inputs.melee and inputs.melee.offHit
	elseif id == "ranged" then
		return inputs.ranged and inputs.ranged.hit
	elseif id == "spell" then
		return inputs.spell and inputs.spell.hit
	end
	return inputs.melee and inputs.melee.hit
end

local function Wanted(t, id)
	local hit = HitOf(t.inputs, id)
	local a, b = t.level[id], t.boss and t.boss[id]
	if not (Finite(hit) and a and Finite(a.need) and (not t.boss or (b and Finite(b.need)))) then
		return nil
	end
	return Join(t, Pct(math.max(0, a.need - hit)), b and Pct(math.max(0, b.need - hit)) or nil)
end

Entry("HITCHANCE", function(unit)
	if unit ~= "player" then
		return false
	end
	return Tables()
end, function(t)
	local weapon, dual = WeaponLine(t), t.level.main ~= nil
	local order = dual and Ids("main", "off", weapon, "ranged", "spell") or Ids(weapon, "ranged", "spell")
	local shown = false
	for _, id in ipairs(order) do
		local text = Both(t, id, "miss")
		if text then
			if not shown then
				Columns("Chance to miss", t)
				shown = true
			end
			Pair(Label(id, dual), text)
		end
	end
	if not shown then
		return
	end
	local wanted = false
	for _, id in ipairs(Ids(weapon, "ranged", "spell")) do
		local text = Wanted(t, id)
		if text then
			if not wanted then
				Columns("Hit still wanted", t)
				wanted = true
			end
			Pair(Label(id, dual), text)
		end
	end
	local note = "Each 1% hit takes 1% off your misses until none are left; hit past that does nothing."
	if dual then
		note = note .. " Two weapons make your swings miss more, not your abilities."
	end
	if t.rules == "classic" then
		note = note .. " Counted as tests of Classic found: against a boss the first 1% of hit does nothing, and 1% of spells always miss"
			.. " (Hit cap against a boss, Hit table page)."
	end
	Note(note)
end)

Entry("CRITCHANCE", function(unit)
	if unit ~= "player" then
		return false
	end
	local t = Tables()
	if not t then
		return t
	end
	local agility, intellect = Stat("player", K.AGI), Stat("player", K.INT)
	local fromAgility = agility and Number(GetCritChanceFromStat, K.AGI, agility)
	local fromIntellect = intellect and Number(GetSpellCritChanceFromStat, K.INT, intellect)
	if (agility and not fromAgility and type(GetCritChanceFromStat) == "function")
		or (intellect and not fromIntellect and type(GetSpellCritChanceFromStat) == "function") then
		return nil
	end
	t.agility = fromAgility and fromAgility * 100 or nil
	t.intellect = not K.NO_MANA[ClassOf() or ""] and fromIntellect and fromIntellect * 100 or nil
	return t
end, function(t)
	local shown = false
	local weapon, dual = WeaponLine(t), t.level.main ~= nil
	for _, id in ipairs(Ids(weapon, "ranged", "spell")) do
		local text = Both(t, id, "crit")
		if text then
			if not shown then
				Columns("Chance to crit", t)
				shown = true
			end
			Pair(Label(id, dual), text)
		end
	end
	if t.agility then
		Pair("From Agility", Pct(t.agility))
	end
	if t.intellect then
		Pair("From Intellect, for spells", Pct(t.intellect))
	end
	local swing = t.boss and (t.boss.swing or t.boss.main)
	if swing and swing.over and Finite(swing.parts.cap) then
		Pair("Swings on a boss", "at most " .. Pct(swing.parts.cap) .. " crit")
		Note("A swing is one roll: misses, dodges and glancing blows come first, so crit past what they leave is lost. Abilities, shots and "
			.. "spells roll their crit apart.")
	end
	if weapon and t.boss and t.boss[weapon] then
		Note("A boss is three levels above you: its defense takes crit off your weapon attacks.")
	end
end)

Entry("EXPERTISE", function(unit)
	if unit ~= "player" then
		return false
	end
	return Tables({ melee = true })
end, function(t)
	local dual = t.level.main ~= nil
	local order = dual and { "main", "off" } or { "swing" }
	local shown = false
	for _, id in ipairs(order) do
		local text = Both(t, id, "dodge")
		if text then
			if not shown then
				Columns("Chance to be dodged", t)
				shown = true
			end
			Pair(Label(id, dual), text)
		end
	end
	if not shown then
		return
	end
	local wanted = Both(t, order[1], "dodge")
	if wanted then
		Pair("Expertise still wanted", wanted)
	end
	Note("Each 1% expertise takes 1% off dodges and parries. Only an enemy you face can parry, so from behind dodges are all that count.")
end)

local function ReadWeapon(unit, hand)
	local low, high, ap
	if hand == "ranged" then
		if unit ~= "player" then
			return false
		end
		local ok, speed, least, most = Read(UnitRangedDamage, "player")
		if not ok then
			return nil
		elseif not (Finite(speed) and speed > 0 and Finite(least) and Finite(most)) then
			return false
		end
		low, high, ap = least, most, Power(UnitRangedAttackPower, "player")
	else
		local ok, least, most, offLeast, offMost = Read(UnitDamage, unit)
		if not ok then
			return nil
		end
		if hand == "off" then
			least, most = offLeast, offMost
		end
		if not (Finite(least) and Finite(most)) then
			return false
		end
		low, high, ap = least, most, Power(UnitAttackPower, unit)
	end
	if ap == nil then
		return nil
	end
	local d = { average = (low + high) / 2, ap = ap, hand = hand }
	if unit == "player" and hand ~= "ranged" then
		local t = Tables({ melee = true })
		if t == nil then
			return nil
		elseif t then
			local id = hand == "off" and "off" or (t.level.main and "main" or "swing")
			local glance = Both(t, id, "glance")
			if glance then
				d.glance, d.label, d.table = glance, id == "swing" and "Swings" or K.NAMES[id], t
			end
		end
	end
	return d
end

local function WriteWeapon(d)
	Pair("A hit that lands", Num(d.average) .. " on average")
	if d.hand ~= "off" then
		Pair(d.hand == "ranged" and "Ranged attack power adds" or "Attack power adds", "+" .. Num(d.ap / K.AP_PER_DPS) .. " damage a second")
	end
	if d.glance then
		Columns("Swings that glance", d.table)
		Pair(d.label, d.glance)
		Note("A glancing blow lands for less. Only your swings glance, never your abilities.")
	end
end

Entry("MAINHAND_DAMAGE", function(unit)
	return ReadWeapon(unit, "main")
end, WriteWeapon)

Entry("OFFHAND_DAMAGE", function(unit)
	return ReadWeapon(unit, "off")
end, WriteWeapon)

Entry("RANGED_DAMAGE", function(unit)
	return ReadWeapon(unit, "ranged")
end, WriteWeapon)

local function ReadAttackPower(unit, ranged)
	if unit ~= "player" then
		return false
	end
	local override = Number(GetOverrideAPBySpellPower)
	if override and override > 0 then
		return false
	end
	local total = Power(ranged and UnitRangedAttackPower or UnitAttackPower, "player")
	local strength, agility = Stat("player", K.STR), Stat("player", K.AGI)
	local stats = Stats()
	if not (total and strength and agility and stats) then
		return nil
	end
	local fn = ranged and GetRangedAttackPowerForStat or GetAttackPowerForStat
	if type(fn) ~= "function" then
		return false
	end
	local fromStrength, fromAgility = Number(fn, K.STR, strength), Number(fn, K.AGI, agility)
	if not (fromStrength and fromAgility) then
		return nil
	end
	local field = ranged and "rap" or "ap"
	local strPer, agiPer = PerPoint(stats, K.STR)[field], PerPoint(stats, K.AGI)[field]
	return { total = total, strength = math.max(0, fromStrength), agility = math.max(0, fromAgility),
		strPer = Finite(strPer) and strPer or nil, agiPer = Finite(agiPer) and agiPer or nil }
end

local function WriteAttackPower(d)
	if d.strength > 0 then
		Pair("From Strength", Num(d.strength))
	end
	if d.agility > 0 then
		Pair("From Agility", Num(d.agility))
	end
	local rest = d.total - d.strength - d.agility
	if rest >= 0.5 then
		Pair("From level, gear and buffs", Num(rest))
	end
	local takes = {}
	if d.strPer and d.strPer > 0 then
		takes[#takes + 1] = Num(K.AP_PER_DPS / d.strPer) .. " Strength"
	end
	if d.agiPer and d.agiPer > 0 then
		takes[#takes + 1] = Num(K.AP_PER_DPS / d.agiPer) .. " Agility"
	end
	if #takes > 0 then
		Pair("1 more damage a second takes", table.concat(takes, " or "))
	end
end

Entry("ATTACK_AP", function(unit)
	return ReadAttackPower(unit, false)
end, WriteAttackPower)

Entry("RANGED_ATTACK_AP", function(unit)
	return ReadAttackPower(unit, true)
end, WriteAttackPower)

Entry("HASTE", function(unit)
	local ok, main, off, ranged = Read(UnitAttackSpeed, unit)
	if not ok then
		return nil
	end
	local d = { main = Finite(main) and main > 0 and main or nil, off = Finite(off) and off > 0 and off or nil }
	if unit == "pet" then
		d.melee = Number(GetPetMeleeHaste)
		return d.main and d or false
	end
	local class = ClassOf()
	d.melee = Number(GetMeleeHaste)
	if K.RANGED_CLASS[class or ""] then
		d.ranged = Finite(ranged) and ranged > 0 and ranged or nil
	end
	if not K.NO_MANA[class or ""] then
		d.spell = Number(UnitSpellHaste, "player")
	end
	return d
end, function(d)
	if d.main then
		local text = "every " .. Secs(d.main)
		if d.melee and d.melee > 0 then
			text = text .. ", " .. Secs(d.main * (1 + d.melee / 100)) .. " without haste"
		end
		Pair(d.off and K.NAMES.main or "Swings", text)
	end
	if d.off then
		Pair(K.NAMES.off, "every " .. Secs(d.off))
	end
	if d.ranged then
		Pair("Shots", "every " .. Secs(d.ranged))
	end
	if d.spell and d.spell > 0 then
		Pair("A " .. K.CAST .. " sec cast", "takes " .. Secs(K.CAST / (1 + d.spell / 100)))
	end
	Note("Haste makes you faster, not each hit bigger: 10% haste is 10% more swings or casts in a minute.")
end)

Entry("ARMORPEN", function(unit)
	if unit ~= "player" then
		return false
	end
	local pen = Number(GetArmorPenetration)
	if pen == nil then
		return nil
	end
	return pen ~= 0 and { pen = pen } or false
end, function()
	Note("Armor takes a share off physical damage: your swings, shots and weapon abilities, not spells. Piercing lowers the enemy's armor for "
		.. "those, so it adds more the more armor an enemy wears. The game does not show an enemy's armor, so it gets no number here.")
end)

local function ReadSpellBonus(unit, healing)
	if unit ~= "player" then
		return false
	end
	local most = 0
	if healing then
		local ok, value = Read(GetSpellBonusHealing)
		if not ok then
			return nil
		end
		most = Finite(value) and value or 0
	else
		for _, school in ipairs(K.SCHOOLS) do
			local ok, value = Read(GetSpellBonusDamage, school)
			if not ok then
				return nil
			end
			if Finite(value) and value > most then
				most = value
			end
		end
	end
	return most > 0 and { most = most } or false
end

Entry("SPELLPOWER", function(unit)
	return ReadSpellBonus(unit, false)
end, function()
	Note("Each damage spell gets a share of it, longer casts a bigger share. Point at a spell to see what it adds there (Spell power and attack "
		.. "power lines, on the Spell tooltips page).")
end)

Entry("SPELLHEALING", function(unit)
	return ReadSpellBonus(unit, true)
end, function()
	Note("Each heal gets a share of it, longer casts a bigger share. Point at a heal to see what it adds there (Spell power and attack power lines, "
		.. "on the Spell tooltips page).")
end)

Entry("SPELLPENETRATION", function(unit)
	if unit ~= "player" then
		return false
	end
	local C = ns.HitTableCalc
	local pen, level = Number(GetSpellPenetration), Number(UnitLevel, "player")
	if pen == nil or level == nil then
		return nil
	elseif pen <= 0 or level < 1 or type(C) ~= "table" or type(C.Resist) ~= "function" then
		return false
	end
	level = math.floor(level)
	local ok, resist = pcall(C.Resist, level, level, false, pen)
	if not ok or not Finite(resist) then
		return false
	end
	return { more = -resist }
end, function(d)
	if d.more > 0 then
		Pair("Creature of your level, no resistance", "+" .. Pct(d.more) .. " spell damage")
	end
	Note("Against a creature with resistance, piercing first takes that away, then makes it take more. Against a player it only takes away the "
		.. "resistance they have.")
end)
