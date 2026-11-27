local _, ns = ...

local KEY, PART = "chat", "your stats"
local IsSecret, Finite = ns.IsSecret, ns.Finite

local K = {
	FIRST_SLOT = 0, LAST_SLOT = 19, AMMO = 0, MAIN = 16, OFF = 17, RANGED = 18, WEAPON_SLOTS = { 16, 17, 18 }, TEMP_SLOTS = { 16, 17 },
	WEAPON = 2, DAGGER = 15, TWO_HAND = "INVTYPE_2HWEAPON",
	SCHOOLS = { 2, 3, 4, 5, 6, 7 }, HOLY = 2,
	STATS = 5, RATE_STATS = { 1, 2, 4 }, STEP = 10,
	HASTE = { 18, 19, 20 },
	CAT = 1, BEARS = { [5] = true, [8] = true },
	FURY = 25780,
	MAX_LINES = 60, MAX_ENTRIES = 8, MAX_NODES = 1000,
	STALE = 1,
	KNOWN_CALLS = { "IsSpellKnownOrInSpellBook", "IsSpellKnown" },
	ENGLISH = { enUS = true, enGB = true }, NEAR = 1, FAR = 5, ENOUGH = 10,
	MODEL = { apPerDps = 14, healThreat = 0.5, offHand = 0.5, gcd = 1.5, norm = { one = 2.4, dagger = 1.7, two = 3.3, ranged = 2.8 },
		form = { cat = 1.0, bear = 2.5 }, downrank = { grace = 17, step = 0.05 } },
	SCHOOL_NAMES = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" },
	BASIS = { c = 1, m = 2, e = 3 },
	WORD = "(%D-)", SMALL = { of = true, the = true, ["and"] = true, a = true, ["in"] = true },
	NOTE_WIDTH = 50, LINE_WIDTH = 44,
	OTHERWISE = "The game's text shows a range for any weapon",
	DAMAGE_KINDS = { spell = true, dot = true, channel = true, strike = true, apstrike = true, finisher = true, auto = true, shot = true, wand = true,
		seal = true, proc = true },
	TAKES_G = { mult = true, bonus = true, flat = true, more = true, drop = true, heal = true, caster = true },
	ALL = { "state", "stats", "talents", "gear", "spells", "role" },
	GEAR = { "links", "enchants", "temp", "weapons", "shield", "shieldBlock", "ammo", "ammoKind", "twoHand", "dual", "rockbiter" },
	SKIP = { time = true, old = true },
	ROWS = { "chat.spellPower", "chat.spellStats", "chat.spellLowRank", "chat.spellThreat", "chat.spellWhen", "chat.spellTotal", "chat.spellRates",
		"chat.tipDetail", "chat.gear", "chat.gearWhen", "chat.gearMost", "chat.gearAgainst", "chat.gearFacing", "chat.gearRules", "chat.gearTotals",
		"chat.gearSwing", "hud.hitTableRules", "nameplates.threatRole" },
	ROLE_ROW = "nameplates.threatRole",
	TOTAL_KINDS = { spell = true, dot = true, channel = true, heal = true, hot = true, strike = true, apstrike = true, finisher = true, auto = true,
		shot = true, wand = true },
	LASTING = { dot = true, hot = true }, HEALS = { heal = true, hot = true }, FIRES = { [2] = 2, [18] = 2, [3] = 3 },
	PAW_LEAST = 1, UNARMED_SPEED = 2.0, MANA = 0, MAX_COSTS = 8,
	PER_UNIT = { hit = "a hit", block = "a block", stack = "a stack", proc = "a proc" },
	KIND_UNIT = { strike = "a hit", apstrike = "a hit", finisher = "a hit at 5 points", auto = "a swing", shot = "a shot", wand = "a shot" },
	SHORT_UNIT = { strike = "a hit", apstrike = "a hit", finisher = "a hit at 5 points", auto = "a swing", shot = "a shot", wand = "a shot",
		channel = "a channel", seal = "a hit", proc = "a proc" },
	STYLE = { header = { "NORMAL_FONT_COLOR", 1, 0.82, 0 }, good = { "GREEN_FONT_COLOR", 0.1, 1, 0.1 }, bad = { "RED_FONT_COLOR", 1, 0.1, 0.1 } },
	LABEL = { 0.82, 0.82, 0.82 }, VALUE = { 1, 1, 1 }, DIM = { 0.66, 0.68, 0.62 },
	PLAYER_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE",
		"UNIT_SPELL_HASTE", "UNIT_AURA", "UNIT_INVENTORY_CHANGED" },
	EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_DAMAGE_DONE_MODS", "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
		"WEAPON_ENCHANT_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED",
		"TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
		"PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "SPELL_TEXT_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" },
}
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

local S = {
	state = {}, stats = nil,
	marks = { state = true, stats = true, talents = true, gear = true, spells = true, role = true },
	version = 1, rows = {}, owners = {}, hearing = false, frame = nil, units = {}, alone = {},
	count = 0, reported = false, reading = false, fresh = nil, after = {}, failed = {}, highest = {}, before = nil, parsed = {},
	check = { done = false, result = nil, name = nil, rank = nil, waiting = nil },
	unstaged = {}, nodes = nil, walked = false, lookups = nil, patterns = nil,
}
S.state.version = S.version
local Hear

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

local function Index(t, key)
	return t[key]
end

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
		return true
	end
	return Plainly(pcall(fn, ...))
end

local function Sum(base, plus, minus)
	if not Finite(base) then
		return nil
	end
	return base + (Finite(plus) and plus or 0) + (Finite(minus) and minus or 0)
end

local function Positive(value)
	return Finite(value) and value > 0 and value or nil
end

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

local function Worse(a, b)
	if (K.BASIS[b] or 0) > (K.BASIS[a] or 0) then
		return b
	end
	return a
end

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

local function Overlap(a, b)
	for _, value in ipairs(type(a) == "table" and a or { a }) do
		if InSet(b, value) then
			return true
		end
	end
	return false
end

local function ValueAt(value, index)
	if type(value) == "table" then
		return value[index]
	end
	return value
end

local function PartValue(list, index)
	local value = type(list) == "table" and list[index] or nil
	return Finite(value) and value or nil
end

local function BasisAt(basis, index)
	if type(basis) ~= "string" or basis == "" then
		return "c"
	elseif #basis == 1 then
		return basis
	end
	local letter = basis:sub(index, index)
	return letter ~= "" and letter or basis:sub(-1)
end

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

local function Registered()
	return type(ns.modules) == "table" and type(ns.modules[KEY]) == "table" and type(ns.EachPart) == "function"
end

local function Stopped()
	if not Registered() or type(ns.PartStopped) ~= "function" then
		return false
	end
	local ok, stopped = pcall(ns.PartStopped, KEY, PART)
	return ok and stopped == true
end

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

local function Bump()
	S.version = S.version + 1
	S.state.version = S.version
end

local function MarkAll()
	for _, what in ipairs(K.ALL) do
		S.marks[what] = true
	end
end

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

local function AddTalent(L, spell, node, def)
	if not Whole(spell) or L.seen[spell] then
		return
	end
	L.seen[spell] = true
	L.talentList[#L.talentList + 1] = { spell = spell, node = node, def = def }
end

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

local function Mine(L, keys)
	for _, key in ipairs(type(keys) == "table" and keys or {}) do
		if L.own[key] then
			return true
		end
	end
	return false
end

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

local function Escape(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function Global(name, fallback)
	local value = _G[name]
	if Plain(value, "string") and value ~= "" then
		return value
	end
	return fallback
end

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

local function Instant(link)
	local ok, id, _, _, loc, _, class, subclass = Plainly(pcall(Api("C_Item", "GetItemInfoInstant"), link))
	if not ok then
		return nil
	end
	return Whole(id) and id or nil, Plain(loc, "string") and loc or nil, Finite(class) and class or nil, Finite(subclass) and subclass or nil
end

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

local function EnchantOf(link)
	if not Plain(link, "string") then
		return nil
	end
	local id = tonumber(link:match("item:%-?%d+:(%d+)") or "")
	return Whole(id) and id > 0 and id or nil
end

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

local function ConfigID()
	local config = Ask(Api("C_ClassTalents", "GetActiveConfigID"))
	if not Finite(config) then
		local group = Ask(Api("C_SpecializationInfo", "GetActiveSpecGroup"))
		config = Finite(group) and Ask(Api("C_SpecializationInfo", "GetCombatConfigIDForSpecGroup"), group) or nil
	end
	return Finite(config) and config or nil
end

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

local function ReadTalents()
	local L, st = Lookups(), S.state
	if not L then
		return false
	end
	local talents, config = {}, ConfigID()
	if config and Ask(Api("C_Traits", "ConfigHasStagedChanges"), config) == true then
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

local function Percent100(value)
	return Finite(value) and value * 100 or nil
end

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
	if type(UnitPowerMax) == "function" then
		local okMana, most = pcall(UnitPowerMax, "player", K.MANA)
		t.mana = okMana and Finite(most) and most > 0 and most or nil
	end
	return t
end

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

local function Trim(text)
	text = text:gsub("(%.%d-)0+$", "%1")
	return (text:gsub("%.$", ""))
end

local function Big(whole)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, broken = pcall(BreakUpLargeNumbers, whole)
		if ok and Plain(broken, "string") and broken ~= "" then
			return broken
		end
	end
	return ("%d"):format(whole)
end

local function Pct(x)
	if not Finite(x) then
		return ""
	end
	return Trim(("%.1f"):format(x * 100)) .. "%"
end

local function Mult(x)
	if not Finite(x) then
		return ""
	end
	return "x" .. Trim(("%.2f"):format(x))
end

local function Dec(x)
	if not Finite(x) then
		return ""
	end
	return Trim(("%.2f"):format(x))
end

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

local function Signed(x)
	local text = Num(x)
	if text ~= "" and x > 0 and text ~= "0" then
		text = "+" .. text
	end
	return text
end

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

local function Change(x, second)
	if not Finite(x) then
		return ""
	elseif math.abs(x) < 0.05 then
		return "0"
	end
	return (x > 0 and "+" or "-") .. Figure(math.abs(x), second)
end

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

local function Hex(colour)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, Finite(value) and value or 1)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(colour[1]), Byte(colour[2]), Byte(colour[3]))
end

local function Paint(text, colour)
	return Hex(colour) .. text .. "|r"
end

local function Tone(change, higherBetter, still)
	if not Finite(change) or math.abs(change) <= (Finite(still) and still or 0) then
		return Style.value
	end
	if (change > 0) == (higherBetter ~= false) then
		return Style.good
	end
	return Style.bad
end

local function Sec(ms)
	return Trim(("%.1f"):format(ms / 1000)) .. " sec"
end

local function Toward(x)
	if x >= 0 then
		return math.floor(x)
	end
	return -math.floor(-x)
end

local function Line(left, right, tone, dim, wrap)
	tone, dim, wrap = tone or "plain", dim == true, wrap == true
	return { left, right, tone, dim, wrap, left = left, right = right, tone = tone, dim = dim, wrap = wrap }
end

local function Dim(text)
	return Line(text, nil, "plain", true, true)
end

local function Kept(text)
	return Line(text, nil, "plain", true, false)
end

local function Fit(left, long, short)
	if #left + 2 + #long <= K.LINE_WIDTH then
		return long
	end
	return short
end

local function Factor(name, m, b, background, also)
	return { name, m, b, background, name = name, m = m, b = b, background = background, also = also }
end

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

local function SpellName(entry, row)
	local name = Ask(Api("C_Spell", "GetSpellName"), row[1])
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return TitleCase(entry.key)
end

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

local function FormName(form, full)
	local L = Lookups()
	for _, rule in ipairs(L and L.rules or {}) do
		if rule.form ~= nil and rule.talent == nil and InSet(rule.form, form) and type(rule.name) == "string" then
			return FormRuleName(rule, form, full)
		end
	end
	return nil
end

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

local function OffHand(state, stats)
	local G = ns.GearModel
	local factor = type(G) == "table" and Ask(G.OffFactor, state, stats) or nil
	if Finite(factor) and factor > 0 then
		return factor
	end
	return ModelOf("offHand")
end

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

local function IsHoly(entry)
	return entry.school == K.HOLY or (type(entry.sch) == "table" and InSet(entry.sch, K.HOLY))
end

local function Wears(state, item)
	for _, link in pairs(type(state.links) == "table" and state.links or {}) do
		if Plain(link, "string") and tonumber(link:match("item:(%d+)") or "") == item then
			return true
		end
	end
	return false
end

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

local function RuleName(rule, state)
	local name = type(rule.name) == "string" and rule.name or (type(rule.id) == "string" and rule.id) or "?"
	if rule.talent ~= nil then
		local rank = type(state.talents) == "table" and state.talents[rule.talent] or nil
		local most = type(rule.r) == "table" and #rule.r or 0
		if Finite(rank) and most > 1 then
			name = ("%s %d/%d"):format(name, rank, most)
		end
	elseif rule.form ~= nil then
		name = FormRuleName(rule, state.form, true)
	end
	return name
end

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

local function Threat(kind, t, entry, row, index, state, stats, opts, G, factors, Gb, total)
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
	local hit = total and Finite(total.value) and total.value > 0 and total or nil
	local damage = hit and not hit.heal and hit or nil
	local times = G ~= 1 and (" x " .. (Gb == "e" and "~" or "") .. Dec(G)) or ""
	local word = G ~= 1 and (" " .. Mult(G)) or ""
	if t and t.forms ~= nil and not InSet(t.forms, state.form) then
		r.own, r.factors = true, {}
		r.right = "only in " .. (FormNames(t.forms) or "a form")
		return r
	end
	if kind == "mult" then
		local v = Finite(value) and value or 1
		r.own = t ~= nil and v ~= 1
		if r.own then
			r.ownFactor = SpellName(entry, row) .. " " .. (basis == "e" and "~" or "") .. Mult(v)
		end
		if damage then
			r.right = ((guess ~= "" or damage.estimate) and "~" or "") .. Num(Toward(damage.value * v * G)) .. " " .. damage.short
			r.formula = (v * G ~= 1 or #r.factors > 0) and ("damage x " .. guess .. Dec(v * G)) or "equal to the damage"
			r.tone = damage.old and "old" or "plain"
		else
			r.right = guess .. "damage " .. Mult(v * G)
		end
	elseif kind == "bonus" or kind == "flat" then
		r.own = true
		local mine = (basis == "e" or (ap and t.apb == "e")) and "~" or ""
		local rule = mine .. Num(raw) .. (ap and (" + " .. Pct(ap) .. " of attack power") or "")
		local amount = not (ap and not power) and raw + (ap and power * ap or 0) or nil
		if kind == "bonus" and damage and amount then
			r.right = ((mine ~= "" or Gb == "e" or damage.estimate) and "~" or "") .. Num(Toward((damage.value + amount) * G)) .. " " .. damage.short
			r.formula = G ~= 1 and ("(damage + " .. rule .. ")" .. times) or ("damage + " .. rule)
			r.tone = (damage.old or (ap and stats.old)) and "old" or "plain"
		elseif kind == "bonus" then
			local head = (Gb == "e" and "~" or "") .. "damage" .. word .. " + "
			r.right = head .. (amount and (mine .. Num(Toward(amount * G))) or (G ~= 1 and ("(" .. rule .. ")" .. word) or rule))
			r.tone = amount and ap and stats.old and "old" or "plain"
		elseif amount then
			r.right = ((mine ~= "" or Gb == "e") and "~" or "") .. Num(Toward(amount * G))
			if ap or G ~= 1 then
				r.formula = (ap and G ~= 1) and ("(" .. rule .. ")" .. times) or (rule .. times)
			end
			r.tone = ap and stats.old and "old" or "plain"
		else
			r.right = (Gb == "e" and "~" or "") .. (G ~= 1 and ("(" .. rule .. ")" .. word) or rule)
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
		if G ~= 1 then
			r.formula = Num(-math.abs(raw)) .. times
		end
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
		local data, general = ns.SpellData, ModelOf("healThreat")
		local paladin = type(data) == "table" and type(data.HEAL_THREAT) == "table" and data.HEAL_THREAT[entry.key] or nil
		local v = (Finite(paladin) and paladin) or (Finite(value) and value) or general
		local split = (t == nil or t.split) and ", split" or ""
		local healing = hit and hit.heal and hit or nil
		r.own = Finite(paladin) or (t ~= nil and v ~= general)
		if r.own then
			r.ownFactor = SpellName(entry, row) .. " " .. Dec(v)
		end
		if healing then
			r.right = ((guess ~= "" or healing.estimate) and "~" or "") .. Num(Toward(healing.value * v * G)) .. " " .. healing.short .. split
			r.formula = "healing x " .. guess .. Dec(v * G)
			r.tone = healing.old and "old" or "plain"
		else
			r.right = guess .. Dec(v * G) .. " x healing" .. split
		end
	elseif kind == "caster" then
		r.own = true
		local v, who = Finite(value) and value or 0, entry.pet and "your pet's level" or "your level"
		if Finite(level) then
			r.right = guess .. Num(Toward(v * level * G))
			r.formula = G ~= 1 and ("(" .. Dec(v) .. " x " .. who .. ")" .. times) or (Dec(v) .. " x " .. who)
		else
			r.right = Dec(v) .. " x " .. who .. word
		end
	elseif kind == "rage" then
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

function M.State()
	Refresh(false)
	return S.state
end

function M.Stats()
	Refresh(true)
	return S.stats
end

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

function M.Want(owner, on)
	if type(owner) ~= "string" then
		return
	end
	S.owners[owner] = on and true or nil
	Hear(next(S.owners) ~= nil)
end

function M.Mark(what)
	if type(what) == "string" and S.marks[what] ~= nil then
		S.marks[what] = true
	end
end

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

function M.TextCheck()
	local check = S.check
	if check.result then
		return check.result, check.name, check.rank
	end
	return nil
end

function M.Multiplier(entry, state)
	if type(entry) ~= "table" then
		return 1, {}, "c"
	end
	state = type(state) == "table" and state or S.state
	return Factors(entry, state, state.role)
end

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

local function PartBase(row, at, level)
	local base = PartValue(row.bm, at) or 0
	local gain = PartValue(row.bl, at)
	if gain and gain ~= 0 then
		base = base + gain * Levels(row, at, level)
	end
	return base
end

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

local function Equipped(entry, state)
	if entry.needs == "dagger" then
		local main = type(state.weapons) == "table" and state.weapons[K.MAIN] or nil
		return type(main) == "table" and main.dagger == true
	elseif entry.needs == "shield" then
		return state.shield == true
	end
	return true
end

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

local function Total(entry, row, state, stats, lowRank)
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
				base, bonus, estimate = WeaponTotal(entry, row, index, part, state, stats)
			else
				base, bonus, estimate = PartTotal(entry, row, index, part, state, stats, lowRank)
			end
			if base == nil then
				return nil
			end
			t.base, t.bonus, t.any = t.base + base, t.bonus + bonus, true
			t.estimate = t.estimate or estimate == true
			local ticks = PartValue(row.n, index) or part.n
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
	return { value = t.base + t.bonus, base = t.base, bonus = t.bonus, unit = TotalUnit(kind, t, row, state), estimate = t.estimate, heal = heal }
end

local function ShortUnit(entry, state, total)
	local unit = total and total.unit
	if type(unit) == "string" and unit:find(", each target$") then
		return "a target"
	elseif type(unit) == "string" and not unit:find(",", 1, true) and not unit:find("^over ") then
		return unit
	end
	local kind = TotalKind(entry)
	if kind == "auto" and state.dual == true then
		return "a swing of each hand"
	end
	return K.SHORT_UNIT[kind] or "a cast"
end

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

local function Rates(out, entry, at, row, state, stats, total, lowRank)
	local G = ns.GearModel
	local result = nil
	if type(G) == "table" and type(G.Expect) == "function" then
		local ok, value = pcall(G.Expect, { entry = entry, rank = at, id = row[1] }, state, stats, { lowRank = lowRank })
		if ok and type(value) == "table" and value.why == nil and Finite(value.cast) then
			result = value
		end
	end
	local figure, guess = nil, ""
	if result then
		figure, guess = result.cast, result.estimate == true and "~" or ""
	elseif total then
		figure, guess = total.value, total.estimate and "~" or ""
	end
	if not figure or figure <= 0 then
		return
	end
	if result then
		local with = " with crits and misses"
		if K.HEALS[TotalKind(entry)] then
			with = " with crits"
		elseif entry.roll == "spell" and entry.school ~= 1 and entry.cmp ~= "threat" then
			with = " with crits, misses and Spell Piercing"
		end
		local amount = guess .. Num(figure)
		out[#out + 1] = Line("Expected", Fit("Expected", amount .. " " .. ShortUnit(entry, state, total) .. with, amount .. with), "plain", true)
	end
	if result and result.perSecond then
		if Finite(result.second) then
			out[#out + 1] = Line("Per second", guess .. Num(result.second) .. " at your attack speed", "plain", true)
		end
		return
	elseif entry.nx then
		return
	end
	local seconds, instant = CastSeconds(entry, row)
	out[#out + 1] = Line("Per second", guess .. Num(figure / seconds) .. (instant and " of the global cooldown" or " of cast time"), "plain", true)
	local mana = ManaCost(row[1])
	if mana then
		local right = guess .. Num(figure / mana)
		local full = type(stats) == "table" and stats.mana or nil
		if Finite(full) and full >= mana then
			local casts = math.floor(full / mana)
			right = right .. ", " .. Num(casts) .. (casts == 1 and " cast" or " casts") .. " from full mana"
		end
		out[#out + 1] = Line("Per mana", right, "plain", true)
	end
end

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
	local total = Total(entry, row, state, stats, lowRank)
	if total and opts.total ~= false then
		local right = (total.estimate and "~" or "") .. Num(total.value) .. " " .. total.unit
		if total.base >= 1 and total.bonus >= 1 then
			right = right .. "  (" .. Num(total.base) .. " + " .. Num(total.bonus) .. ")"
		end
		out[#out + 1] = Line("Total", right, stats.old and "old" or "plain")
	end
	if opts.rates ~= false then
		Rates(out, entry, at, row, state, stats, total, lowRank)
	end
	return out
end

local function Made(out, formula, names)
	local list = table.concat(names, ", ")
	if formula and #names > 0 and #formula + 2 + #list <= K.LINE_WIDTH then
		out[#out + 1] = Kept(formula .. ": " .. list)
		return
	elseif formula then
		out[#out + 1] = Kept(formula)
	end
	local line = nil
	for _, name in ipairs(names) do
		if line and #line + 2 + #name <= K.LINE_WIDTH then
			line = line .. ", " .. name
		else
			if line then
				out[#out + 1] = Kept(line)
			end
			line = name
		end
	end
	if line then
		out[#out + 1] = Kept(line)
	end
end

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
	local t = type(entry.threat) == "table" and entry.threat or nil
	local data = ns.SpellData
	local paladin = type(data) == "table" and type(data.HEAL_THREAT) == "table" and Finite(data.HEAL_THREAT[entry.key])
	local kind = t and t.k or (paladin and Heals(entry) and "heal") or (Damages(entry) and "mult") or (Heals(entry) and "heal") or nil
	if not kind or kind == "unknown" then
		return out
	end
	local total = stats and type(entry.parts) == "table" and Total(entry, row, state, stats, opts.lowRank ~= false) or nil
	if total then
		total.short = ShortUnit(entry, state, total)
		total.old = stats.old == true
	end
	local G, factors, Gb = Factors(entry, state, opts.role or state.role)
	local r = Threat(kind, t, entry, row, index, state, stats, opts, G, factors, Gb, total)
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
	local names = {}
	if r.ownFactor and #r.factors > 0 then
		names[1] = r.ownFactor
	end
	for _, factor in ipairs(r.factors) do
		names[#names + 1] = factor.name .. " " .. (factor.b == "e" and "~" or "") .. Mult(factor.m) .. (factor.also and (", " .. factor.also) or "")
	end
	out[1] = Line("Threat", r.right, r.tone)
	Made(out, r.formula, names)
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
	if #clauses > 0 then
		out[#out + 1] = Dim(table.concat(clauses, "; "))
	end
	return out
end

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

M.Fmt = { Pct = Pct, Mult = Mult, Num = Num, Signed = Signed, Percent = Percent, Figure = Figure, Change = Change, Pct2 = Pct2, Style = Style,
	Hex = Hex, Paint = Paint, Tone = Tone }
