local _, ns = ...

local KEY, PART = "chat", "gear lines"

local IsSecret, Finite = ns.IsSecret, ns.Finite

local T = {
	OWNER = "gear lines",
	MAX_LINES = 20, CACHE = 64, BARS = 8, MOST = 5, MAX_LEVEL = 60,
	ITEM = 0, USAGE = 43, EQUIP_SLOT = 21,
	RED_LEAST = 0.9, OTHER_MOST = 0.25,
	NO_LINES = { INVTYPE_RELIC = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_TABARD = true, INVTYPE_BODY = true, INVTYPE_NON_EQUIP = true,
		INVTYPE_NON_EQUIP_IGNORE = true },
	LEARNS = {
		WARRIOR = { [2] = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true,
			[13] = true, [15] = true, [16] = true, [18] = true }, [4] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true } },
		PALADIN = { [2] = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
			[4] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true } },
		HUNTER = { [2] = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true,
			[16] = true, [18] = true }, [4] = { [1] = true, [2] = true, [3] = true } },
		ROGUE = { [2] = { [0] = true, [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true, [16] = true, [18] = true },
			[4] = { [1] = true, [2] = true } },
		SHAMAN = { [2] = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
			[4] = { [1] = true, [2] = true, [3] = true, [6] = true } },
		DRUID = { [2] = { [4] = true, [5] = true, [6] = true, [10] = true, [13] = true, [15] = true }, [4] = { [1] = true, [2] = true } },
		PRIEST = { [2] = { [4] = true, [10] = true, [15] = true, [19] = true }, [4] = { [1] = true } },
		MAGE = { [2] = { [7] = true, [10] = true, [15] = true, [19] = true }, [4] = { [1] = true } },
		WARLOCK = { [2] = { [7] = true, [10] = true, [15] = true, [19] = true }, [4] = { [1] = true } },
	},
	SLOT_NAMES = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
		"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" },
	GENERIC = { 6603, 75, 5019 },
	ALWAYS = { [6603] = true },
	CAT_FORM = 1, BEAR_FORMS = { [5] = true, [8] = true },
	SETS = { damage = "a damage dealer", tank = "a tank", healer = "a healer", cat = "Cat Form", bear = "a bear form" },
	ROLES = { damage = true, tank = true, healer = true },
	HEALS = { heal = true, hot = true },
	CAPS = { classic = "9% melee and 16% spells", game = "8% melee and 17% spells" },
	RATINGS = { hit = 10, crit = 14, haste = 10, expertise = 10 },
	WEIGHT_MIN = 0, WEIGHT_MAX = 5, WEIGHT_STEP = 0.5, WEIGHT = 1,
	FIGURES = { { "damage", "Damage" }, { "healing", "Healing" }, { "threat", "Threat" } }, TAKEN = "Damage taken", OVERALL = "Overall",
	SEPARATOR = "  \194\183  ", STILL_PCT = 0.0005,
	ROLE_KIND = { healer = "healing", tank = "threat" },
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, good = { 0.1, 1, 0.1 }, bad = { 1, 0.1, 0.1 },
		dim = { 0.66, 0.68, 0.62 } },
	JOIN = "; ",
	NO_CHANGE = "No change to your chosen spells; armor, avoidance and mana are not counted.",
	OUT_OF_COMBAT = "Gear lines show out of combat.",
	RANDOM = "Random stats not known",
	NOT_YET = "Not wearable yet: ",
	NOT_YET_LEVEL = " (the numbers are for you now, at level %d)",
	LEARN = "an armor or weapon skill you have yet to learn",
	NOT_COUNTED = "Not counted: ",
	MORE = "and %d more: /flatui gear",
	SLOT_NOTE = "Gear comparison: the game did not say which item an item replaces, so Flat UI went by its slot.",
	RATING_NOTE = "Gear comparison: rating sizes are Flat UI's (%d hit, %d crit, %d haste, %d expertise for 1%%), since the game gave no conversion.",
	NO_MODEL = "Gear comparison: Flat UI's spell data is not loaded, so the list cannot change now.",
	NOT_LOADED = "Gear comparison: your settings have not loaded yet.",
	NO_BAR = "Gear comparison: the game has no action bar information, so Add the spells of a bar adds nothing.",
	BAR_HELP = "/flatui gear bar 1 - the spells of action bar 1 to 8",
	FAILED = "Gear comparison: that did not work; the game's error report says why.",
	NO_WINDOW = "Gear comparison: the window is not in this build of Flat UI.",
	RESET_LINE = "Your class's main spells for your role",
	OPEN_LINE = "Open the Gear comparison window",
	WEIGHT_HELP = "/flatui gear weight <spell> <0 to 5> - how much a spell counts in the Overall line, in steps of 0.5",
	HELP = {
		"/flatui gear - the Gear comparison window; /flatui gear <item> compares a shift-clicked item there",
		"/flatui gear add <spell>, remove <spell>, bar 1, reset, list - the spells it compares",
		"/flatui gear weight <spell> <0 to 5> - how much a spell counts in the Overall line",
	},
}

local added = setmetatable({}, { __mode = "k" })
local blocks = { byKey = {}, order = {}, last = {}, lastOrder = {} }
local list = { counter = 0, version = 1 }
local seen = { slots = false, ratings = false }
local asked, patterns, reported = {}, {}, {}

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Whole(value)
	return Finite(value) and value > 0 and value == math.floor(value)
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

local function Index(t, key)
	return t[key]
end

local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil, true
	end
	local ok, value = pcall(Index, t, key)
	if not ok or IsSecret(value) then
		return nil, true
	end
	return value, false
end

local function Call(space, name)
	local fn = Field(space, name)
	return type(fn) == "function" and fn or nil
end

local function EnumValue(group, name, fallback)
	local value = Field(Field(_G.Enum, group), name)
	if Finite(value) then
		return value
	end
	return fallback
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Report(err, where)
	where = where or PART
	if reported[where] then
		return
	end
	reported[where] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, ("Flat UI Chat and tooltips, %s: %s"):format(where, tostring(err)))
	end
end

local function Model()
	local M = ns.SpellModel
	if type(M) == "table" and type(M.Find) == "function" and type(M.ByKey) == "function" and type(M.Highest) == "function" then
		return M
	end
	return nil
end

local function Gear()
	local G = ns.GearModel
	if type(G) == "table" and type(G.Compare) == "function" then
		return G
	end
	return nil
end

local function Avoid(name, ...)
	local A = ns.GearAvoid
	local fn = type(A) == "table" and A[name] or nil
	if type(fn) ~= "function" then
		return nil
	end
	local ok, first, second = pcall(fn, ...)
	if not ok then
		Report(first, "avoidance")
		return nil
	end
	return first, second
end

local function Want(on)
	local M = ns.SpellModel
	if type(M) == "table" and type(M.Want) == "function" then
		local ok, err = pcall(M.Want, T.OWNER, on == true)
		if not ok then
			Report(err, "sync")
		end
	end
end

local function StateOf(M)
	local state = M and type(M.State) == "function" and M.State() or nil
	return Plain(state, "table") and state or {}
end

local function StatsOf(M)
	local stats = M and type(M.Stats) == "function" and M.Stats() or nil
	return Plain(stats, "table") and stats or nil
end

local function Version(M)
	return M and type(M.Version) == "function" and M.Version() or 0
end

local function Class(state)
	local class = state.class
	if not Plain(class, "string") then
		class = Ask(UnitClassBase, "player")
	end
	return Plain(class, "string") and class or nil
end

local function Level(state)
	local level = state.level
	if not Finite(level) then
		level = Ask(UnitLevel, "player")
	end
	return Finite(level) and level or 0
end

local function Form(state)
	local form = state.form
	if not Finite(form) then
		form = Ask(GetShapeshiftFormID)
	end
	return Finite(form) and form or 0
end

local function Role(state)
	local role = state.role
	if Plain(role, "string") and T.ROLES[role] then
		return role
	end
	if type(ns.PlayerRole) == "function" then
		local ok, answer = pcall(ns.PlayerRole)
		if ok and Plain(answer, "string") and T.ROLES[answer] then
			return answer
		end
	end
	return "damage"
end

local function Fighting(stats)
	return Ask(InCombatLockdown) == true or (stats ~= nil and stats.old == true)
end

local function SpellName(id)
	local name = Ask(Call(C_Spell, "GetSpellName"), id)
	if Plain(name, "string") and name ~= "" then
		return name
	end
	return nil
end

local function RankText(id)
	local text = Ask(Call(C_Spell, "GetSpellSubtext"), id)
	if Plain(text, "string") and text ~= "" then
		return text
	end
	return nil
end

local function Title(key)
	if type(key) ~= "string" then
		return "?"
	end
	return (key:gsub("(%a)([%w']*)", function(first, rest)
		return first:upper() .. rest
	end))
end

local function NameOf(entry, id)
	return (Whole(id) and SpellName(id)) or Title(type(entry) == "table" and entry.key or nil)
end

local function RankId(entry, index)
	local ranks = type(entry) == "table" and entry.ranks or nil
	local rank = type(ranks) == "table" and ranks[index] or nil
	return type(rank) == "table" and Whole(rank[1]) and rank[1] or nil
end

local function Known(id)
	if T.ALWAYS[id] then
		return true
	end
	local known = ns.SpellKnown
	if type(known) ~= "function" then
		return true
	end
	return known(id) == true
end

local function Highest(M, entry)
	if type(entry) ~= "table" or type(entry.ranks) ~= "table" then
		return nil
	end
	local index, id = M.Highest(entry)
	if Finite(index) and entry.ranks[index] ~= nil then
		return index, Whole(id) and id or RankId(entry, index)
	end
	for at = #entry.ranks, 1, -1 do
		local rank = RankId(entry, at)
		if rank and T.ALWAYS[rank] then
			return at, rank
		end
	end
	return nil
end

local function KnownRank(M, entry, id)
	if Known(id) then
		return true
	end
	local _, top = Highest(M, entry)
	return top ~= nil and top == id
end

local function WeightOf(value)
	if Finite(value) and value >= T.WEIGHT_MIN and value <= T.WEIGHT_MAX then
		return value
	end
	return nil
end

local function WeightText(weight)
	return (("%.1f"):format(weight):gsub("%.0$", ""))
end

local function Line(entry, index, id, kept, known, weight)
	return { entry = entry, rank = index, id = id, name = NameOf(entry, id), kept = kept == true, known = known == true, key = entry.key,
		weight = WeightOf(weight) or T.WEIGHT }
end

local function Comparable(entry)
	return type(entry) == "table" and type(entry.cmp) == "string" and entry.pet ~= true and type(entry.ranks) == "table" and entry.ranks[1] ~= nil
		and type(entry.key) == "string"
end

local function SetOf(class, role, form)
	local D = ns.SpellData
	local all = type(D) == "table" and D.DEFAULTS or nil
	local sets = type(all) == "table" and class and all[class] or nil
	if type(sets) ~= "table" then
		return nil, role
	end
	if class == "DRUID" then
		if form == T.CAT_FORM and type(sets.cat) == "table" then
			return sets.cat, "cat"
		elseif T.BEAR_FORMS[form] then
			if type(sets.bear) == "table" then
				return sets.bear, "bear"
			elseif type(sets.tank) == "table" then
				return sets.tank, "bear"
			end
		end
	end
	if type(sets[role]) == "table" then
		return sets[role], role
	elseif type(sets.damage) == "table" then
		return sets.damage, "damage"
	end
	return nil, role
end

local function Items(item, known, out)
	if type(item) == "string" then
		if known(item) then
			out[#out + 1] = item
		end
		return
	elseif type(item) ~= "table" then
		return
	end
	if item.needs ~= nil then
		local group = item
		if not known(item.needs) then
			group = item["else"]
		end
		for _, key in ipairs(type(group) == "table" and group or {}) do
			if type(key) == "string" and known(key) then
				out[#out + 1] = key
			end
		end
		return
	end
	for _, key in ipairs(item) do
		if type(key) == "string" and known(key) then
			out[#out + 1] = key
			return
		end
	end
end

local function DefaultLines(M, state)
	local class, role = Class(state), Role(state)
	local set, name = SetOf(class, role, Form(state))
	if not set then
		return {}, name, true
	end
	local function KnownKey(key)
		local entry = type(key) == "string" and M.ByKey(key) or nil
		return Comparable(entry) and Highest(M, entry) ~= nil
	end
	local keys = {}
	for _, item in ipairs(set) do
		Items(item, KnownKey, keys)
	end
	local lines, taken = {}, {}
	for _, key in ipairs(keys) do
		if not taken[key] and #lines < T.MAX_LINES then
			taken[key] = true
			local entry = M.ByKey(key)
			local index, id = Highest(M, entry)
			if index and id then
				lines[#lines + 1] = Line(entry, index, id, false, true)
			end
		end
	end
	return lines, name, false
end

local function Saved()
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local old = char.gearSpells
	if old == nil then
		return nil
	elseif type(old) ~= "table" then
		char.gearSpells = nil
		return nil
	end
	local clean, twice = {}, {}
	for _, line in ipairs(old) do
		local key = type(line) == "table" and line.key or nil
		local id = type(line) == "table" and line.id or nil
		if type(key) == "string" and key ~= "" and (id == nil or Whole(id)) and #clean < T.MAX_LINES then
			local mark = key .. "#" .. tostring(id)
			if not twice[mark] then
				twice[mark] = true
				if line.weight ~= nil and not WeightOf(line.weight) then
					line = { key = key, id = id }
				end
				clean[#clean + 1] = line
			end
		end
	end
	local same = #clean == #old
	for key in pairs(old) do
		same = same and clean[key] ~= nil and rawequal(clean[key], old[key])
	end
	if same then
		return old
	end
	char.gearSpells = clean
	return clean
end

local function SavedLine(M, item)
	if item.id ~= nil then
		local entry, index = M.Find(item.id)
		if not Comparable(entry) or not Finite(index) then
			return nil
		end
		return Line(entry, index, item.id, true, KnownRank(M, entry, item.id), item.weight)
	end
	local entry = M.ByKey(item.key)
	if not Comparable(entry) then
		return nil
	end
	local index, id = Highest(M, entry)
	if index and id then
		return Line(entry, index, id, false, true, item.weight)
	end
	local top = #entry.ranks
	local topId = RankId(entry, top)
	return topId and Line(entry, top, topId, false, false, item.weight) or nil
end

local function Resolve()
	local M = Model()
	local now = Ask(GetTime)
	local memoKey = Finite(now) and (tostring(now) .. "|" .. list.counter .. "|" .. tostring(M and Version(M))) or nil
	if memoKey and list.memoKey == memoKey and list.memo then
		return list.memo, list.memoInfo
	end
	local lines, info = {}, { defaults = false }
	local saved = Saved()
	if M then
		local state = StateOf(M)
		info.role, info.class = Role(state), Class(state)
		if saved == nil then
			info.defaults = true
			lines, info.set, info.noSet = DefaultLines(M, state)
		else
			for _, item in ipairs(saved) do
				local line = SavedLine(M, item)
				if line then
					lines[#lines + 1] = line
				end
			end
		end
	else
		info.defaults = saved == nil
	end
	local parts = { info.defaults and ("d" .. tostring(info.set)) or "c" }
	for _, line in ipairs(lines) do
		parts[#parts + 1] = ("%s;%s;%s%s;%s"):format(line.key, tostring(line.id), line.kept and "k" or "f", line.known and "y" or "n",
			tostring(line.weight))
	end
	local signature = table.concat(parts, ",")
	if signature ~= list.signature then
		list.signature = signature
		list.version = list.version + 1
	end
	list.memo, list.memoInfo, list.memoKey = lines, info, memoKey
	return lines, info
end

function ns.GearChosen()
	local ok, lines, info = pcall(Resolve)
	if not ok then
		Report(lines, "list")
		return {}, { defaults = false }
	end
	local copy = {}
	for index, line in ipairs(lines) do
		copy[index] = line
	end
	return copy, info
end

function ns.GearListVersion()
	local ok, err = pcall(Resolve)
	if not ok then
		Report(err, "list")
	end
	return list.version
end

local function Forget()
	blocks.byKey, blocks.order, blocks.last, blocks.lastOrder = {}, {}, {}, {}
	list.memo, list.memoInfo, list.memoKey = nil, nil, nil
end

local function Changed()
	list.counter = list.counter + 1
	Forget()
end

local function Editable()
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local saved = Saved()
	if saved then
		return saved
	end
	local made = {}
	for _, line in ipairs((Resolve())) do
		made[#made + 1] = { key = line.key }
	end
	char.gearSpells = made
	return made
end

local function Label(line)
	local text = line.name or "?"
	if line.kept then
		local rank = RankText(line.id)
		if rank then
			text = text .. " (" .. rank .. ")"
		end
	end
	if Finite(line.weight) and line.weight ~= T.WEIGHT then
		text = text .. " (weight " .. WeightText(line.weight) .. ")"
	end
	if not line.known then
		text = text .. " (not known)"
	end
	return text
end

local function Who(info)
	if info and info.defaults then
		return "your class's spells for " .. (T.SETS[info.set] or T.SETS.damage)
	end
	return "your choice"
end

local function Names(lines)
	local names = {}
	for _, line in ipairs(lines) do
		names[#names + 1] = line.name
	end
	return #names > 0 and table.concat(names, ", ") or "none known yet"
end

local function Entries()
	local M = Model()
	local rows = {}
	local saved = Saved()
	if saved == nil then
		for _, line in ipairs((Resolve())) do
			rows[#rows + 1] = { line.id, Label(line), line }
		end
		return rows
	end
	for index, item in ipairs(saved) do
		local line = M and SavedLine(M, item) or nil
		if line then
			rows[#rows + 1] = { line.id, Label(line), line }
		elseif item.id ~= nil then
			rows[#rows + 1] = { item.id, (SpellName(item.id) or ("Spell " .. item.id)) .. " (not in the comparison)" }
		else
			rows[#rows + 1] = { -index, Title(item.key) .. " (not in the comparison)" }
		end
	end
	return rows
end

local function ByLabel(a, b)
	local first, second = a[2]:lower(), b[2]:lower()
	if first ~= second then
		return first < second
	end
	return a[1] < b[1]
end

local function Candidates()
	local M = Model()
	if not M then
		return {}
	end
	local followed, standing = {}, {}
	for _, line in ipairs((Resolve())) do
		if not line.kept then
			followed[line.key] = true
		end
		if line.known then
			standing[line.id] = true
		end
	end
	local rows, taken = {}, {}
	local function Keep(id)
		if not Whole(id) or standing[id] then
			return false
		end
		local entry = M.Find(id)
		if not Comparable(entry) or followed[entry.key] or taken[entry.key] then
			return false
		end
		local _, top = Highest(M, entry)
		if top ~= nil and top ~= id then
			return false
		end
		taken[entry.key] = true
		return true
	end
	local book = ns.SpellBookList
	if type(book) == "function" then
		local listed = book(function(id)
			return Keep(id)
		end)
		for _, row in ipairs(type(listed) == "table" and listed or {}) do
			if type(row) == "table" and Whole(row[1]) and Plain(row[2], "string") then
				rows[#rows + 1] = { row[1], row[2] }
			end
		end
	end
	for _, id in ipairs(T.GENERIC) do
		if Known(id) and Keep(id) then
			rows[#rows + 1] = { id, NameOf(M.Find(id), id) }
		end
	end
	table.sort(rows, ByLabel)
	return rows
end

local function AddLine(id, keep)
	local M = Model()
	if not M then
		return false, T.NO_MODEL, "bad"
	end
	if not Whole(id) then
		return false, ('Gear comparison: no spell found for "%s".'):format(tostring(id)), "bad"
	end
	local entry = M.Find(id)
	local name = SpellName(id) or ("Spell " .. id)
	if type(entry) ~= "table" then
		return false, ("Gear comparison: %s is not in Flat UI's spell data for your class."):format(name), "bad"
	elseif not Comparable(entry) then
		return false, ("Gear comparison: Flat UI cannot work out %s."):format(name), "bad"
	end
	local _, top = Highest(M, entry)
	if keep == nil then
		keep = top ~= nil and top ~= id
	end
	local stands = keep and id or top
	local lines = Resolve()
	for _, line in ipairs(lines) do
		if line.key == entry.key and ((keep and line.kept and line.id == id) or (not keep and not line.kept)
			or (line.known and stands ~= nil and line.id == stands)) then
			return false, ("Gear comparison: %s is chosen already."):format(Label(line)), "had"
		end
	end
	local saved = Saved()
	if #(saved or lines) >= T.MAX_LINES then
		return false, ("Gear comparison: %d spells is the most."):format(T.MAX_LINES), "full"
	end
	local edit = Editable()
	if not edit then
		return false, T.NOT_LOADED, "bad"
	end
	edit[#edit + 1] = keep and { key = entry.key, id = id } or { key = entry.key }
	Changed()
	local rank = keep and RankText(id) or nil
	return true, ("Gear comparison: added %s%s."):format(name, rank and (" (" .. rank .. ")") or "")
end

local function Which(M, lines, id)
	for index, line in ipairs(lines) do
		if line.kept and line.id == id then
			return index
		end
	end
	local entry = M and M.Find(id) or nil
	if type(entry) == "table" then
		for index, line in ipairs(lines) do
			if not line.kept and line.key == entry.key then
				return index
			end
		end
	end
	return nil
end

local function SavedAt(M, saved, id)
	if id < 0 then
		local item = saved[-id]
		if type(item) == "table" and item.id == nil then
			return -id, Title(item.key)
		end
		return nil
	end
	local name = SpellName(id) or ("Spell " .. id)
	for index, item in ipairs(saved) do
		if item.id == id then
			return index, name
		end
	end
	local entry = M and M.Find(id) or nil
	if type(entry) == "table" then
		for index, item in ipairs(saved) do
			if item.id == nil and item.key == entry.key then
				return index, name
			end
		end
	end
	return nil, name
end

local function RemoveLine(id)
	if not Finite(id) or id ~= math.floor(id) or id == 0 then
		return false, ('Gear comparison: no spell found for "%s".'):format(tostring(id))
	end
	local M = Model()
	local saved = Saved()
	if saved == nil then
		local lines = Resolve()
		local at = id > 0 and Which(M, lines, id) or nil
		local char = ns.Character()
		if not at then
			return false, ("Gear comparison: %s is not chosen."):format(SpellName(id) or tostring(id))
		elseif type(char) ~= "table" then
			return false, T.NOT_LOADED
		end
		local made = {}
		for index, line in ipairs(lines) do
			if index ~= at then
				made[#made + 1] = { key = line.key }
			end
		end
		char.gearSpells = made
		Changed()
		return true, ("Gear comparison: removed %s."):format(lines[at].name)
	end
	local at, name = SavedAt(M, saved, id)
	if not at then
		return false, ("Gear comparison: %s is not chosen."):format(name or tostring(id))
	end
	table.remove(saved, at)
	Changed()
	return true, ("Gear comparison: removed %s."):format(name)
end

local function SetWeight(id, weight)
	if not Finite(id) or id ~= math.floor(id) or id == 0 then
		return false, ('Gear comparison: no spell found for "%s".'):format(tostring(id))
	elseif not Finite(weight) or weight < T.WEIGHT_MIN or weight > T.WEIGHT_MAX then
		return false, T.WEIGHT_HELP
	end
	weight = math.floor(weight / T.WEIGHT_STEP + 0.5) * T.WEIGHT_STEP
	local M = Model()
	local saved, at, name = Saved(), nil, nil
	if saved == nil then
		local lines = Resolve()
		at = id > 0 and Which(M, lines, id) or nil
		name = at and lines[at].name or SpellName(id)
	else
		at, name = SavedAt(M, saved, id)
	end
	if not at then
		return false, ("Gear comparison: %s is not chosen."):format(name or tostring(id))
	end
	local now = saved and WeightOf(saved[at].weight) or T.WEIGHT
	if now == weight then
		return false, ("Gear comparison: %s weighs %s already."):format(name, WeightText(weight))
	end
	local edit = Editable()
	if not edit or type(edit[at]) ~= "table" then
		return false, T.NOT_LOADED
	end
	edit[at].weight = weight ~= T.WEIGHT and weight or nil
	Changed()
	if weight == 0 then
		return true, ("Gear comparison: %s is left out of the Overall line (weight 0)."):format(name)
	end
	return true, ("Gear comparison: %s weighs %s in the Overall line."):format(name, WeightText(weight))
end

local function BarAdd(bar)
	if not (Whole(bar) and bar <= T.BARS) then
		return false, T.BAR_HELP
	end
	local M = Model()
	if not M then
		return false, T.NO_MODEL
	end
	if type(GetActionInfo) ~= "function" then
		return false, T.NO_BAR
	end
	local read = ns.BarSpells
	local ids, others
	if type(read) == "function" then
		ids, others = read(bar)
	end
	if type(ids) ~= "table" then
		return false, T.NO_BAR
	end
	local count, left, had, full = 0, Finite(others) and others >= 0 and math.floor(others) or 0, 0, false
	local taken = {}
	for _, id in ipairs(ids) do
		local entry = Whole(id) and M.Find(id) or nil
		if not Comparable(entry) then
			left = left + 1
		elseif not taken[entry.key] then
			taken[entry.key] = true
			local done, _, why = AddLine(id, true)
			if done then
				count = count + 1
			elseif why == "had" then
				had = had + 1
			else
				full = full or why == "full"
				left = left + 1
			end
		end
	end
	if count + left + had == 0 then
		return true, ("Gear comparison: action bar %d has nothing to add."):format(bar)
	end
	local said = ("Gear comparison: action bar %d: %d added, %d left out."):format(bar, count, left)
	if had > 0 then
		said = said .. (" %d %s chosen already."):format(had, had == 1 and "was" or "were")
	end
	if full then
		said = said .. (" %d spells is the most."):format(T.MAX_LINES)
	end
	return true, said
end

local function Reset(id)
	if id ~= 1 then
		return false, nil
	end
	local char = ns.Character()
	if type(char) ~= "table" then
		return false, T.NOT_LOADED
	end
	if char.gearSpells == nil then
		local _, info = Resolve()
		return false, ("Gear comparison: %s are in use already."):format(Who(info))
	end
	char.gearSpells = nil
	Changed()
	local lines, info = Resolve()
	return true, ("Gear comparison: back to %s: %s."):format(Who(info), Names(lines))
end

local function Open(id)
	local show = ns.GearWindowShow
	if id ~= 1 or type(show) ~= "function" then
		return false, nil
	end
	local said = show()
	return true, Plain(said, "string") and said or nil
end

local function Rows(ok, rows)
	if ok and type(rows) == "table" then
		return rows
	end
	if not ok then
		Report(rows, "list")
	end
	return {}
end

local function Answer(ok, done, message, ...)
	if ok then
		return done, message, ...
	end
	Report(done, "list")
	return false, T.FAILED
end

function ns.GearCandidates()
	return Rows(pcall(Candidates))
end

function ns.GearPicked()
	return Rows(pcall(function()
		local rows = {}
		for _, row in ipairs(Entries()) do
			rows[#rows + 1] = { row[1], row[2] }
		end
		return rows
	end))
end

function ns.GearAdd(id)
	return Answer(pcall(AddLine, id))
end

function ns.GearRemove(id)
	return Answer(pcall(RemoveLine, id))
end

function ns.GearSetWeight(id, weight)
	return Answer(pcall(SetWeight, id, weight))
end

function ns.GearBarLines()
	local rows = {}
	for bar = 1, T.BARS do
		rows[bar] = { bar, ("Action bar %d"):format(bar) }
	end
	return rows
end

function ns.GearBarPick(bar)
	return Answer(pcall(BarAdd, bar))
end

function ns.GearResetLines()
	return { { 1, T.RESET_LINE } }
end

function ns.GearResetPick(id)
	return Answer(pcall(Reset, id))
end

function ns.GearOpenLines()
	return { { 1, T.OPEN_LINE } }
end

function ns.GearOpenPick(id)
	return Answer(pcall(Open, id))
end

local function Ours(tooltip)
	if tooltip == nil or IsSecret(tooltip) or not (rawequal(tooltip, _G.GameTooltip) or rawequal(tooltip, _G.ItemRefTooltip)) or ns.Forbidden(tooltip) then
		return false
	end
	local embedded, withheld = Field(tooltip, "IsEmbedded")
	return not withheld and embedded ~= true
end

local function IsItem(data)
	if not Plain(data, "table") then
		return false
	end
	local kind = Field(data, "type")
	return Finite(kind) and kind == EnumValue("TooltipDataType", "Item", T.ITEM)
end

local function KeyHeld(choice)
	local down
	if choice == "always" then
		return true
	elseif choice == "shift" then
		down = IsShiftKeyDown
	elseif choice == "ctrl" then
		down = IsControlKeyDown
	elseif choice == "alt" then
		down = IsAltKeyDown
	else
		return false
	end
	return Ask(down) == true
end

local function Comparing(tooltip)
	if rawequal(tooltip, _G.GameTooltip) then
		if Field(tooltip, "supportsItemComparison") ~= true then
			return false
		end
		if Field(Field(tooltip, "processingInfo"), "compareItem") == true then
			return true
		end
	end
	local suppressed, withheld = Field(tooltip, "suppressAutomaticCompareItem")
	if not withheld and suppressed ~= true and Ask(Call(C_CVar, "GetCVarBool"), "alwaysCompareItems") == true then
		return true
	end
	return Ask(IsModifiedClick, "COMPAREITEMS") == true
end

local function WornSlot(guid)
	local location = Ask(Call(C_Item, "GetItemLocation"), guid)
	local slot = Field(location, "equipmentSlotIndex")
	if Finite(slot) and slot >= 0 and slot <= 19 and slot == math.floor(slot) then
		return slot
	end
	return nil
end

local function Load(id)
	if asked[id] then
		return
	end
	asked[id] = true
	Ask(Call(C_Item, "RequestLoadItemDataByID"), id)
end

local function ItemLink(data, id, guid)
	local link = Field(data, "hyperlink")
	if Plain(link, "string") and link:find("item:", 1, true) then
		return link
	end
	if guid then
		link = Ask(Call(C_Item, "GetItemLinkByGUID"), guid)
		if Plain(link, "string") and link ~= "" then
			return link
		end
	end
	local info = id and Call(C_Item, "GetItemInfo") or nil
	if info then
		local ok, name, base = pcall(info, id)
		if ok and Plain(base, "string") and base ~= "" then
			return base
		elseif ok and name == nil then
			Load(id)
		end
	end
	return nil
end

function ns.GearLinesFor(loc)
	return Plain(loc, "string") and loc ~= "" and not T.NO_LINES[loc]
end

local function EquipLoc(link)
	local instant = Call(C_Item, "GetItemInfoInstant")
	if not instant then
		return nil
	end
	local ok, _, _, _, loc, _, itemClass, subclass = pcall(instant, link)
	if not ok or not Plain(loc, "string") or loc == "" or T.NO_LINES[loc] then
		return nil
	end
	return loc, Finite(itemClass) and itemClass or nil, Finite(subclass) and subclass or nil
end

local function Loaded(id)
	if Ask(Call(C_Item, "IsItemDataCachedByID"), id) == false then
		Load(id)
		return false
	end
	return true
end

local function Red(colour)
	if not Plain(colour, "table") then
		return false
	end
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	return Finite(r) and Finite(g) and Finite(b) and r >= T.RED_LEAST and g <= T.OTHER_MOST and b <= T.OTHER_MOST
end

local function Escape(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function PatternOf(name, fallback)
	local pattern = patterns[name]
	if pattern then
		return pattern
	end
	local format = _G[name]
	if not Plain(format, "string") or format == "" then
		format = fallback
	end
	local before, after = format:match("^(.-)%%s(.*)$")
	if before then
		pattern = "^" .. Escape(before) .. ".+" .. Escape(after) .. "$"
	else
		pattern = "^" .. Escape(format)
	end
	patterns[name] = pattern
	return pattern
end

local function Learns(itemClass, subclass)
	if not (Finite(itemClass) and Finite(subclass)) then
		return false
	end
	local M = ns.SpellModel
	local class = Class(StateOf(type(M) == "table" and M or nil))
	local types = class and T.LEARNS[class]
	local kinds = types and types[itemClass]
	return type(kinds) == "table" and kinds[subclass] == true
end

local function TypeText(line)
	local text = Field(line, "rightText")
	if Plain(text, "string") and text ~= "" then
		return text
	end
	return T.LEARN
end

local function Wearable(data, itemClass, subclass)
	local lines = Field(data, "lines")
	if not Plain(lines, "table") then
		return false, nil
	end
	local usage = EnumValue("TooltipDataLineType", "UsageRequirement", T.USAGE)
	local slotLine = EnumValue("TooltipDataLineType", "EquipSlot", T.EQUIP_SLOT)
	local classes = PatternOf("ITEM_CLASSES_ALLOWED", "Classes: %s")
	local races = PatternOf("ITEM_RACES_ALLOWED", "Races: %s")
	local later, learn
	for _, line in ipairs(lines) do
		local kind = Plain(line, "table") and Field(line, "type") or nil
		if Finite(kind) and kind == slotLine then
			local itemType, typeWithheld = Field(line, "isValidItemType")
			local invSlot, slotWithheld = Field(line, "isValidInvSlot")
			if itemType == nil and invSlot == nil and not typeWithheld and not slotWithheld then
				if Red(Field(line, "leftColor")) then
					invSlot = false
				elseif Red(Field(line, "rightColor")) then
					itemType = false
				end
			end
			if invSlot == false then
				return true, nil
			elseif itemType == false then
				if not Learns(itemClass, subclass) then
					return true, nil
				end
				learn = learn or TypeText(line)
			end
		elseif Finite(kind) and kind == usage and Red(Field(line, "leftColor")) then
			local text = Field(line, "leftText")
			if Plain(text, "string") and text ~= "" then
				if text:find(classes) or text:find(races) then
					return true, nil
				end
				later = later or text
			end
		end
	end
	return false, later or learn
end

function ns.GearWearable(link)
	if not Plain(link, "string") or link == "" then
		return false, nil
	end
	local _, itemClass, subclass = EquipLoc(link)
	local data = Ask(Call(_G.C_TooltipInfo, "GetHyperlink"), link)
	return Wearable(data, itemClass, subclass)
end

local function Store(bucket, order, key, value)
	if bucket[key] == nil then
		order[#order + 1] = key
	end
	bucket[key] = value
	while #order > T.CACHE do
		bucket[table.remove(order, 1)] = nil
	end
end

local function Seen(result)
	if not seen.ratings and (type(_G.GetCombatRatingBonusForCombatRatingValue) ~= "function" or (type(result) == "table" and result.sizes == true)) then
		seen.ratings = true
	end
	if seen.slots then
		return
	end
	if not Call(C_TooltipComparison, "GetItemComparisonInfo") then
		seen.slots = true
		return
	end
	local candidates = type(result) == "table" and result.candidates or nil
	for _, candidate in ipairs(type(candidates) == "table" and candidates or {}) do
		if type(candidate) == "table" and candidate.game == false then
			seen.slots = true
		end
	end
end

local function RowsOf(candidate)
	local rows = {}
	for _, row in ipairs(type(candidate.rows) == "table" and candidate.rows or {}) do
		if type(row) == "table" and type(row.line) == "table" and Finite(row.now) and Finite(row.with) then
			rows[#rows + 1] = row
		end
	end
	return rows
end

local function Share(row)
	if row.now == 0 then
		return nil
	end
	return (row.with - row.now) / math.abs(row.now) * 100
end

local function Rank(candidate, role, shown)
	local G = Gear()
	local ok, totals = pcall(G and G.Totals, candidate, nil, { limit = shown })
	if not ok or type(totals) ~= "table" then
		return 0
	end
	local total = totals[T.ROLE_KIND[role] or "damage"] or totals.damage or totals.healing or totals.threat
	return type(total) == "table" and Finite(total.pct) and total.pct or 0
end

local function Moves(row)
	local share = Share(row)
	if share then
		return math.abs(share) >= 0.05
	end
	return math.abs(row.with - row.now) >= 0.05
end

local function FigureOf(row, role)
	if Plain(row.figure, "string") then
		return row.figure
	end
	local G = Gear()
	local figure = G and type(G.Figure) == "function" and G.Figure(row.line, role, "tooltip") or nil
	return type(figure) == "string" and figure or "cast"
end

local function KindOf(line)
	local entry = line.entry
	return type(entry) == "table" and entry.cmp or nil
end

local function Fmt(name)
	local M = ns.SpellModel
	local fmt = type(M) == "table" and type(M.Fmt) == "table" and M.Fmt or nil
	local fn = fmt and fmt[name]
	return type(fn) == "function" and fn or nil
end

local function Colours()
	local M = ns.SpellModel
	local fmt = type(M) == "table" and type(M.Fmt) == "table" and M.Fmt or nil
	local style = fmt and type(fmt.Style) == "table" and fmt.Style or nil
	if not style then
		return T.STYLE
	end
	for name in pairs(T.STYLE) do
		if type(style[name]) ~= "table" then
			return T.STYLE
		end
	end
	return style
end

local function Paint(text, colour)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, Finite(value) and value or 1)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(colour[1]), Byte(colour[2]), Byte(colour[3])) .. text .. "|r"
end

local function Amount(change, perSecond)
	local fn = Fmt("Change")
	if fn then
		return fn(change, perSecond)
	end
	return ("%+.1f"):format(change)
end

local function Signed(fraction)
	local fn = Fmt("Percent")
	return fn and fn(fraction) or ("%+.1f%%"):format(fraction * 100)
end

local function Percent(row)
	local share = Share(row)
	if not share then
		return nil
	end
	return "(" .. Signed(share / 100) .. ")"
end

local function LeftName(M, line)
	local name = Plain(line.name, "string") and line.name or NameOf(line.entry, line.id)
	if line.kept and Whole(line.id) then
		local _, top = Highest(M, line.entry)
		local rank = top ~= line.id and RankText(line.id) or nil
		if rank then
			name = name .. " (" .. rank .. ")"
		end
	end
	return name
end

local function RowLine(M, row, role, style)
	local figure = FigureOf(row, role)
	local kind = KindOf(row.line)
	local perSecond = row.perSecond == true
	local change = row.with - row.now
	local unit = ""
	if figure == "dps" or (figure == "second" and not T.HEALS[kind]) then
		unit = " a second"
	elseif figure == "second" then
		unit = " healing a second"
	elseif figure == "threat" then
		unit = perSecond and " threat a second" or " threat"
	end
	local percent = Percent(row)
	local right = (row.estimate == true and "~" or "") .. Amount(change, perSecond) .. unit .. (percent and (" " .. percent) or "")
	local colour = math.abs(change) < 0.05 and style.value or (change > 0 and style.good or style.bad)
	return { left = LeftName(M, row.line), right = right, leftColour = style.label, colour = colour }
end

local function ItemName(link)
	if not Plain(link, "string") then
		return nil
	end
	local name = link:match("|h%[(.-)%]|h")
	if not name or name == "" then
		return nil
	end
	local colour = link:match("^(|c[^|]+)|H")
	return colour and (colour .. name .. "|r") or name
end

local function SlotWords(slots)
	if type(slots) ~= "table" or slots[1] == nil then
		return "slot"
	elseif #slots == 2 and ((slots[1] == 16 and slots[2] == 17) or (slots[1] == 17 and slots[2] == 16)) then
		return "both hands"
	end
	local names = {}
	for _, slot in ipairs(slots) do
		names[#names + 1] = T.SLOT_NAMES[slot] or tostring(slot)
	end
	return table.concat(names, " and ")
end

local function Header(M, candidate, slot, unit)
	local ending = unit and (", " .. unit .. ":") or ":"
	if slot then
		return "What it gives your spells" .. ending
	end
	local label = candidate.label
	local slots = type(candidate.slots) == "table" and candidate.slots or {}
	local where = type(label) == "string" and label ~= "" and label or SlotWords(slots)
	local links = StateOf(M).links
	local names = {}
	if candidate.empty ~= true and type(links) == "table" then
		for _, at in ipairs(slots) do
			local name = Finite(at) and ItemName(links[at]) or nil
			if name then
				names[#names + 1] = name
			end
		end
	end
	if #names == 0 then
		if #slots > 1 then
			return "In your empty hands" .. ending
		end
		return ("In your empty %s slot"):format(where) .. ending
	elseif candidate.offEmpty == true then
		return ("Instead of %s, off hand empty"):format(table.concat(names, " and ")) .. ending
	end
	return ("Instead of %s (%s)"):format(table.concat(names, " and "), where) .. ending
end

local function Mine(result, shown, field)
	local list = type(result[field]) == "table" and result[field] or {}
	local own, others = {}, {}
	for _, text in ipairs(type(shown) == "table" and type(shown[field]) == "table" and shown[field] or {}) do
		own[text] = true
	end
	for _, candidate in ipairs(type(result.candidates) == "table" and result.candidates or {}) do
		if candidate ~= shown and type(candidate) == "table" and type(candidate[field]) == "table" then
			for _, text in ipairs(candidate[field]) do
				others[text] = not own[text] or nil
			end
		end
	end
	local out = {}
	for _, text in ipairs(list) do
		if type(text) == "string" and text ~= "" and not others[text] then
			out[#out + 1] = text
		end
	end
	return out
end

local function Tail(result, shown)
	local tail = {}
	for _, text in ipairs(Mine(result, shown, "skills")) do
		tail[#tail + 1] = text
	end
	for _, text in ipairs(Mine(result, shown, "notCounted")) do
		if not text:lower():find("not counted", 1, true) then
			text = T.NOT_COUNTED .. text
		end
		tail[#tail + 1] = text
	end
	for _, text in ipairs(Mine(result, shown, "vs")) do
		tail[#tail + 1] = text
	end
	local random = result.random
	if random == true or (type(random) == "string" and random ~= "") then
		tail[#tail + 1] = random == true and T.RANDOM or random
	end
	return tail
end

local function Build(M, result, slot, info)
	local candidates = type(result) == "table" and result.candidates or nil
	if type(candidates) ~= "table" then
		return nil
	end
	local most = Opt("gearMost")
	most = Finite(most) and most >= 1 and math.floor(most) or T.MOST
	local best, bestRows, bestShown, bestMean
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" then
			local rows = RowsOf(candidate)
			local shown = #rows <= most + 1 and #rows or most
			local mean = Rank(candidate, info.role, shown)
			if #rows > 0 and (best == nil or mean > bestMean + 1e-9) then
				best, bestRows, bestShown, bestMean = candidate, rows, shown, mean
			end
		end
	end
	if not best then
		return nil
	end
	local still = true
	for _, row in ipairs(bestRows) do
		if Moves(row) then
			still = false
			break
		end
	end
	local unit
	for index = 1, still and 0 or bestShown do
		if bestRows[index].perSecond ~= true then
			unit = "a cast"
			break
		end
	end
	local style = Colours()
	local head = { { text = Header(M, best, slot, unit), colour = style.header, wrap = true } }
	local notes = {}
	if still then
		notes[1] = T.NO_CHANGE
	else
		for index = 1, bestShown do
			head[#head + 1] = RowLine(M, bestRows[index], info.role, style)
		end
		if #bestRows > bestShown then
			notes[1] = T.MORE:format(#bestRows - bestShown)
		end
	end
	return { head = head, notes = notes, tail = Tail(result, best), avoid = {}, slots = best.slots, still = still, candidate = best }
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

local function Taken(subject, slots, opts)
	if Avoid("Wanted") ~= true then
		return nil
	end
	local result = Avoid("Compare", subject, opts)
	local candidates = type(result) == "table" and result.candidates or nil
	if type(candidates) ~= "table" then
		return nil
	end
	local chosen = candidates[1]
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "table" and SameSlots(candidate.slots, slots) then
			chosen = candidate
			break
		end
	end
	if type(chosen) ~= "table" then
		return nil
	end
	local taken = chosen.taken
	if type(taken) ~= "table" then
		local totals = Avoid("Totals", chosen)
		taken = type(totals) == "table" and totals.taken or nil
	end
	if type(taken) == "table" and Finite(taken.pct) then
		return taken
	end
	return nil
end

local function OverallFigure(word, pct, estimate, lowerBetter, style)
	local colour, moves = style.value, math.abs(pct) >= T.STILL_PCT
	if moves then
		colour = ((pct > 0) ~= (lowerBetter == true)) and style.good or style.bad
	end
	return Paint(word, style.label) .. " " .. Paint((estimate and moves and "~" or "") .. Signed(pct), colour), moves
end

local function Overall(candidate, lines, opts, taken, style)
	local G = Gear()
	local parts, moved = {}, false
	if type(G.Totals) == "function" then
		local ok, totals = pcall(G.Totals, candidate, lines, opts)
		if not ok then
			Report(totals, "totals")
		elseif type(totals) == "table" then
			for _, figure in ipairs(T.FIGURES) do
				local total = (figure[1] ~= "threat" or opts.role == "tank") and totals[figure[1]] or nil
				if type(total) == "table" and Finite(total.pct) and not (Finite(total.n) and total.n <= 0) then
					local text, moves = OverallFigure(figure[2], total.pct, total.estimate == true, false, style)
					parts[#parts + 1], moved = text, moved or moves
				end
			end
		end
	end
	if taken then
		local text, moves = OverallFigure(T.TAKEN, taken.pct, taken.estimate == true, true, style)
		parts[#parts + 1], moved = text, moved or moves
	end
	if not moved then
		return nil
	end
	return { left = T.OVERALL, right = table.concat(parts, Paint(T.SEPARATOR, style.dim)), leftColour = style.label, colour = style.value }
end

local function BlockFor(key, data, link, slot, guid)
	local M, G = Model(), Gear()
	if not (M and G) then
		return nil
	end
	StateOf(M)
	local stats = StatsOf(M)
	local lines, info = Resolve()
	local known = {}
	for _, line in ipairs(lines) do
		if line.known then
			known[#known + 1] = line
		end
	end
	if #known == 0 then
		return nil
	end
	local totals = Opt("gearTotals") ~= "off"
	local ok, rotation = false, nil
	if type(G.Rotation) == "function" then
		ok, rotation = pcall(G.Rotation, info.role)
	end
	rotation = ok and type(rotation) == "table" and rotation.id or ""
	local cacheKey = table.concat({ key, tostring(Version(M)), list.version, tostring(Avoid("Stamp")), tostring(totals), tostring(rotation) }, "|")
	local kept = blocks.byKey[cacheKey]
	if kept then
		return kept
	end
	local opts = { mode = "tooltip", listVersion = list.version, role = info.role, guid = guid, data = data, against = Opt("gearAgainst"),
		facing = Opt("gearFacing"), rules = Opt("gearRules"), lowRank = Opt("spellLowRank") ~= false }
	local result = G.Compare(slot or link, known, opts)
	Seen(result)
	local block = Build(M, result, slot, info)
	local style = Colours()
	if block then
		local overall, taken = nil, nil
		if totals then
			taken = Taken(slot or link, block.slots, opts)
			overall = Overall(block.candidate, known, opts, taken, style)
			if overall then
				table.insert(block.head, 2, overall)
			end
		end
		local more, words = Avoid("TipLines", slot or link, block.slots, opts)
		if type(more) == "table" then
			if block.still and type(words) == "string" then
				block.notes[1] = words
			end
			local header, rest = nil, {}
			for _, entry in ipairs(more) do
				if type(entry) == "table" and not (overall and taken and entry.key == "taken") then
					if entry.header == true then
						header = entry
					else
						rest[#rest + 1] = entry
					end
				end
			end
			if header and #rest > 1 then
				block.avoid[1] = header
			end
			for _, entry in ipairs(rest) do
				block.avoid[#block.avoid + 1] = entry
			end
		end
		block.candidate = nil
		Store(blocks.byKey, blocks.order, cacheKey, block)
		Store(blocks.last, blocks.lastOrder, key, block)
		return block
	end
	if Fighting(stats) then
		return blocks.last[key] or { head = {}, notes = { T.OUT_OF_COMBAT }, tail = {}, avoid = {} }
	end
	if type(result) ~= "table" or result.quiet == true then
		return nil
	end
	local reason = result.why
	if type(reason) == "string" and reason ~= "" then
		return { head = { { text = reason, colour = style.label, wrap = true } }, notes = {}, tail = {}, avoid = {} }
	end
	return nil
end

local function Put(tooltip, entry, style)
	if entry.right ~= nil then
		local left = type(entry.leftColour) == "table" and entry.leftColour or style.label
		local right = (type(entry.rightColour) == "table" and entry.rightColour) or (type(entry.colour) == "table" and entry.colour) or style.value
		return (pcall(tooltip.AddDoubleLine, tooltip, tostring(entry.left or ""), tostring(entry.right), left[1], left[2], left[3], right[1], right[2],
			right[3]))
	end
	local colour = (type(entry.colour) == "table" and entry.colour) or (entry.dim == true and style.dim) or style.label
	return (pcall(tooltip.AddLine, tooltip, tostring(entry.text or entry.left or ""), colour[1], colour[2], colour[3], entry.wrap ~= false))
end

local function Add(tooltip, data, block, later)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local record = added[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local style = Colours()
	local count, going = 0, true
	local function One(entry)
		if going then
			going = Put(tooltip, entry, style)
			if going then
				count = count + 1
			end
		end
	end
	for _, entry in ipairs(block.head) do
		One(entry)
	end
	local notes = {}
	for _, text in ipairs(block.notes or {}) do
		notes[#notes + 1] = text
	end
	if later then
		local level = Ask(UnitLevel, "player")
		notes[#notes + 1] = T.NOT_YET .. later .. (Finite(level) and T.NOT_YET_LEVEL:format(level) or "")
	end
	for _, text in ipairs(block.tail or {}) do
		notes[#notes + 1] = text
	end
	if Opt("tipDetail") == "full" then
		for _, text in ipairs(notes) do
			One({ text = text, colour = style.dim, wrap = true })
		end
	elseif #notes > 0 then
		for index, text in ipairs(notes) do
			notes[index] = text:sub(-3) == "..." and text or (text:gsub("%.$", ""))
		end
		One({ text = table.concat(notes, T.JOIN), colour = style.dim, wrap = true })
	end
	for _, entry in ipairs(block.avoid or {}) do
		One(entry)
	end
	added[tooltip] = { data = data, lines = shown + count }
end

local function Run(fn, key, ...)
	local ok, err = ns.EachPart(KEY, PART, fn, key, ...)
	if not ok and err ~= nil then
		Report(err)
		if ns.PartStopped(KEY, PART) then
			Want(false)
		end
	end
	return ok
end

local function Work(key, tooltip, data, link, slot, later, guid)
	local block = BlockFor(key, data, link, slot, guid)
	if block then
		Add(tooltip, data, block, later)
	end
end

local function Find(data, tooltip)
	if not Ours(tooltip) or not IsItem(data) then
		return
	end
	local when = Opt("gearWhen")
	local game, shift = false, false
	if rawequal(tooltip, _G.ItemRefTooltip) then
		game, shift = true, true
	elseif when == "compare" then
		game = Comparing(tooltip)
		shift = KeyHeld("shift")
		if not (game or shift) then
			return
		end
	elseif not KeyHeld(when) then
		return
	end
	local id = Field(data, "id")
	id = Whole(id) and id or nil
	local guid = Field(data, "guid")
	guid = Plain(guid, "string") and guid ~= "" and guid or nil
	local slot = guid and WornSlot(guid) or nil
	if when == "compare" and not ((slot and shift) or (not slot and game)) then
		return
	end
	local link = ItemLink(data, id, guid)
	local loc, itemClass, subclass
	if link then
		loc, itemClass, subclass = EquipLoc(link)
	end
	if not loc then
		return
	end
	local never, later = Wearable(data, itemClass, subclass)
	if never or (id and not Loaded(id)) then
		return
	end
	Run(Work, slot and ("slot " .. slot .. " " .. link) or link, tooltip, data, link, slot, later, guid)
end

local function Wanted()
	return ns.Enabled(KEY) and Opt("gear") == true and not ns.PartStopped(KEY, PART)
end

function ns.GearTipLines(tooltip, data)
	if Wanted() then
		Run(Find, data, tooltip)
	end
end

function ns.GearLinesSync()
	Forget()
	Want(Wanted())
end

local function SpellFrom(text)
	local id = tonumber(text:match("|Hspell:(%d+)") or text:match("^spell:(%d+)") or text:match("^(%d+)$") or "")
	if Whole(id) then
		return id, true
	end
	local M = Model()
	local entry = M and M.ByKey(text:lower()) or nil
	if Comparable(entry) then
		local _, top = Highest(M, entry)
		return top or RankId(entry, #entry.ranks), false
	end
	local info = Ask(Call(C_Spell, "GetSpellInfo"), text)
	local found = Field(info, "spellID")
	if Whole(found) then
		return found, text:find("%(") ~= nil
	end
	return nil
end

local function AddNamed(text)
	local id, keep = SpellFrom(text)
	if not id then
		return false, ('Gear comparison: no spell found for "%s".'):format(text)
	end
	return AddLine(id, keep)
end

local function RemoveNamed(text)
	local M = Model()
	local entry = M and M.ByKey(text:lower()) or nil
	if type(entry) == "table" then
		local first
		for _, row in ipairs(Entries()) do
			local line = row[3]
			if line and line.key == entry.key then
				if not line.kept then
					return RemoveLine(row[1])
				end
				first = first or row[1]
			end
		end
		if first then
			return RemoveLine(first)
		end
	end
	local id = SpellFrom(text)
	if not id then
		return false, ('Gear comparison: no spell found for "%s".'):format(text)
	end
	return RemoveLine(id)
end

local function WeightNamed(text)
	local typed, value = text:match("^(.-)%s+([%d%.]+)$")
	value = tonumber(value or "")
	if not typed or typed == "" or not value then
		return false, T.WEIGHT_HELP
	end
	local M = Model()
	local entry = M and M.ByKey(typed:lower()) or nil
	if type(entry) == "table" then
		local first
		for _, row in ipairs(Entries()) do
			local line = row[3]
			if line and line.key == entry.key then
				if not line.kept then
					return SetWeight(row[1], value)
				end
				first = first or row[1]
			end
		end
		if first then
			return SetWeight(first, value)
		end
	end
	local id = SpellFrom(typed)
	if not id then
		return false, ('Gear comparison: no spell found for "%s".'):format(typed)
	end
	return SetWeight(id, value)
end

local function PrintList()
	local _, info = Resolve()
	local rows = Entries()
	if #rows == 0 then
		if info.defaults and info.noSet then
			print("Gear comparison: Flat UI has no spells of its own for your class; /flatui gear add <spell> adds one.")
		elseif info.defaults then
			print(("Gear comparison: none of %s is known yet."):format(Who(info)))
		else
			print("Gear comparison: no spells chosen; /flatui gear add <spell> adds one, /flatui gear reset gives your class's.")
		end
		return
	end
	print(("Gear comparison, %s:"):format(Who(info)))
	for index, row in ipairs(rows) do
		local line = row[3]
		if line then
			local rank = RankText(line.id)
			local weight = Finite(line.weight) and line.weight ~= T.WEIGHT and (", weight " .. WeightText(line.weight)) or ""
			print(("%d. %s%s (%d)%s%s%s"):format(index, line.name, rank and (", " .. rank) or "", line.id, line.kept and ", rank kept" or "",
				weight, line.known and "" or ", not known"))
		else
			print(("%d. %s"):format(index, row[2]))
		end
	end
end

local function Say(ok, done, message)
	if not ok then
		Report(done, "list")
		print(T.FAILED)
	elseif type(message) == "string" then
		print(message)
	end
end

local function Window(fn, ...)
	local said = fn(...)
	return true, Plain(said, "string") and said or nil
end

local function Slash(rest)
	local typed = (Plain(rest, "string") and rest or ""):match("^%s*(.-)%s*$")
	local word, text = typed:match("^(%S*)%s*(.-)$")
	word = word:lower()
	if typed:find("|Hitem:", 1, true) or typed:match("^[Ii]tem:%d+") then
		local show = ns.GearWindowShow
		if type(show) ~= "function" then
			print(T.NO_WINDOW)
			return
		end
		local link = typed:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or typed:match("(|Hitem:.-|h.-|h)") or typed:match("^([Ii]tem:[%d:%-]+)") or typed
		Say(pcall(Window, show, link))
	elseif typed == "" then
		local toggle = ns.GearWindowToggle
		if type(toggle) ~= "function" then
			Say(pcall(PrintList))
			return
		end
		Say(pcall(Window, toggle))
	elseif word == "add" and text ~= "" then
		Say(pcall(AddNamed, text))
	elseif word == "remove" and text ~= "" then
		Say(pcall(RemoveNamed, text))
	elseif word == "weight" then
		Say(pcall(WeightNamed, text))
	elseif word == "bar" then
		Say(pcall(BarAdd, tonumber(text:match("^(%d+)$") or "")))
	elseif word == "reset" then
		Say(pcall(Reset, 1))
	elseif word == "list" then
		Say(pcall(PrintList))
	else
		for _, line in ipairs(T.HELP) do
			print(line)
		end
	end
end

ns.AddSlash(KEY, "gear", Slash, T.HELP)

local function ListStatus()
	local lines, info = Resolve()
	local known, unknown = {}, {}
	for _, line in ipairs(lines) do
		if line.known then
			known[#known + 1] = line.name
		else
			unknown[#unknown + 1] = line.name
		end
	end
	if #known == 0 and #unknown == 0 then
		if info.defaults and info.noSet then
			return "Gear comparison: Flat UI has no spells of its own for your class; /flatui gear add <spell> adds one."
		elseif info.defaults then
			return ("Gear comparison: none of %s is known yet."):format(Who(info))
		end
		return "Gear comparison: no spells chosen; /flatui gear add <spell> adds one."
	end
	if #known == 0 then
		return ("Gear comparison: none of %s is known now: %s."):format(Who(info), table.concat(unknown, ", "))
	end
	local text = ("Gear comparison: %s (%s)"):format(table.concat(known, ", "), Who(info))
	if #unknown > 0 then
		text = text .. "; not known now: " .. table.concat(unknown, ", ")
	end
	return text .. "."
end

local function AgainstStatus()
	local M = Model()
	local state = M and StateOf(M) or {}
	local against, facing, rules = Opt("gearAgainst") or "auto", Opt("gearFacing") or "role", Opt("gearRules") or "hittable"
	local boss = against == "boss" or (against == "auto" and Level(state) >= T.MAX_LEVEL)
	local front = facing == "front" or (facing == "role" and Role(state) == "tank")
	local where = front and "in front" or "from behind"
	if not boss then
		return ("Gear comparison: against an enemy of your level, %s."):format(where)
	end
	local from = ""
	if rules == "hittable" then
		rules, from = ns.Get("hud.hitTableRules"), " (as on the Hit table page)"
	end
	return ("Gear comparison: against a boss three levels above you, %s, with a hit cap of %s%s."):format(where, T.CAPS[rules] or T.CAPS.classic, from)
end

local function RatingNote()
	local D = ns.SpellData
	local model = type(D) == "table" and type(D.MODEL) == "table" and D.MODEL or nil
	local sizes = model and type(model.ratings) == "table" and model.ratings or T.RATINGS
	local function Size(name)
		return Finite(sizes[name]) and sizes[name] or T.RATINGS[name]
	end
	return T.RATING_NOTE:format(Size("hit"), Size("crit"), Size("haste"), Size("expertise"))
end

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) then
		return {}
	end
	local open = ns.GearWindowOpen
	local window = false
	if type(open) == "function" then
		local ok, shown = pcall(open)
		window = ok and shown == true
	end
	if not window and (Opt("gear") ~= true or ns.PartStopped(KEY, PART)) then
		return {}
	end
	local lines = { ListStatus(), AgainstStatus() }
	if seen.slots then
		lines[#lines + 1] = T.SLOT_NOTE
	end
	if seen.ratings then
		lines[#lines + 1] = RatingNote()
	end
	return lines
end)
