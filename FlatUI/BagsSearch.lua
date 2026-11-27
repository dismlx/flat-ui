local _, ns = ...

local KEY = "bags"
local B = ns.Bags
local Search = B.Search
local Categories = B.Categories
local Errands = ns.Errands

local FONT = "GameFontHighlightSmall"
local WIDTH, HEIGHT = 140, 18
local INSET_LEFT, INSET_RIGHT = 6, 18
local CROSS, CROSS_LINE, CROSS_ALPHA = 7, 1.5, 0.6
local MOST_LETTERS = 80
local HINT = "Search"
local DIM = { 0.66, 0.68, 0.62 }
local NONE_RGB, COUNT_GAP = { 1, 0.35, 0.24 }, 4

local CONSUMABLE, WEAPON, ARMOR = 0, 2, 4
local POTION, ELIXIR, FLASK, SCROLL, FOOD, BANDAGE = 1, 2, 3, 4, 5, 7
local QUALITIES = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, artifact = 6, heirloom = 7 }
local MOST_QUALITY = 7
local BAGS = { [-1] = true, [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }

local HELP = {
	"Search",
	"Words look in each item's name, kind and slot, and in the name of its section: potion, cloth, mail, head, consumables.",
	"A space or & is and, | is or, ! is not, brackets group, and \"quoted text\" is one word.",
	"#junk  #new  #quest  #boe  #bound  #set  #usable  #unusable  #learnable",
	"#gear  #weapon  #armour  #consumable  #potion  #elixir  #flask  #food  #bandage  #scroll",
	"#trade  #reagent  #recipe  #ammo  #bag  #key",
	"#poor  #common  #uncommon  #rare  #epic  #legendary",
	"#placed finds what you placed in a section by hand, #pinned what sits in its pinned slot.",
	"Quality: q:rare, q>=uncommon, q<3. Item level: ilvl:20-30, ilvl>40.",
	"tip: looks in each item's tooltip: tip:stamina, tip:\"fire resistance\", tip:agility #boe.",
	"For example: #boe q>=uncommon, !#junk mail, (cloth | leather) #gear.",
	"Items that do not match are dimmed. Enter or Escape leaves the box, and the cross clears it.",
	"Right-click the box for quick searches and your last five searches. Up and Down bring back your last searches.",
	"The bag search key opens the bags with this box ready.",
}
local SHORT = "The cross clears it. Right-click the box for quick searches and your recent ones; Up and Down bring them back."
local QUICK = {
	{ "New items", "#new" },
	{ "Junk", "#junk" },
	{ "Bind on equip", "#boe" },
	{ "Quest items", "#quest" },
	{ "Cannot use", "#unusable" },
	{ "Recipes you can learn", "#learnable" },
	{ "Consumables", "#consumable" },
	{ "Trade goods", "#trade" },
	{ "Placed by hand", "#placed" },
	{ "Green and better", "q>=uncommon" },
	{ "Epic and better", "q>=epic" },
}
local RECENT, RECENT_LETTERS = 5, 40
local QUICK_TERMS = {}
for _, quick in ipairs(QUICK) do
	QUICK_TERMS[quick[2]] = true
end
local KEY_BUTTON = "FlatUIBagSearchButton"
local KEY_BINDING = "CLICK " .. KEY_BUTTON .. ":LeftButton"
local KEY_SAY = {
	off = "Flat UI: Bags is off. Turn on Flat UI bags on the Bags page.",
	down = "Flat UI: Bags is not in use now, so the bag search key does nothing. /flatui status says why.",
	shut = "Flat UI: the game keeps the bags shut here.",
}

_G["BINDING_NAME_" .. KEY_BINDING] = "Flat UI bags: search"

local text = ""
local boxes = setmetatable({}, { __mode = "k" })
local writing = false
local compiled = { text = nil, query = nil }
local tips = { texts = {}, count = 0 }
local TIP_MOST = 3000

local function Text(value)
	if value ~= nil and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function Whole(value)
	if ns.Finite(value) and value == math.floor(value) then
		return value
	end
	return nil
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Run(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part("search", fn, ...)
	end
	return (pcall(fn, ...))
end

local current = {}

local function Begin(record)
	current.record = record
	current.name, current.label, current.cached = nil, nil, nil
end

local function Kind(record)
	local kind = Categories.Kind
	if type(kind) == "function" then
		return kind(record)
	end
	return nil
end

local function Class(record)
	return (Kind(record))
end

local function Cached()
	if current.cached == nil then
		local id, answer = Whole(current.record.id), false
		if id and type(C_Item) == "table" and type(C_Item.IsItemDataCachedByID) == "function" then
			local ok, cached = pcall(C_Item.IsItemDataCachedByID, id)
			answer = ok and not ns.IsSecret(cached) and cached == true
		end
		current.cached = answer
	end
	return current.cached
end

local function Name()
	if current.name == nil then
		local record = current.record
		local name = Text(record.name)
		if not name and Cached() and type(C_Item) == "table" and type(C_Item.GetItemNameByID) == "function" then
			local ok, found = pcall(C_Item.GetItemNameByID, record.id)
			name = ok and Text(found) or nil
		end
		current.name = name and name:lower() or false
	end
	return current.name or nil
end

local function Label()
	if current.label == nil then
		local label = Text(Categories.Label(Categories.Of(current.record)))
		current.label = label and label:lower() or false
	end
	return current.label or nil
end

local function SlotName(slot)
	slot = Text(slot)
	if not slot or slot:sub(1, 8) ~= "INVTYPE_" or slot:find("NON_EQUIP", 1, true) then
		return nil
	end
	return Text(_G[slot])
end

local function Has(value, needle)
	value = Text(value)
	return value ~= nil and value:lower():find(needle, 1, true) ~= nil
end

local function Word(needle)
	local _, _, slot, itype, isubtype = Kind(current.record)
	if Has(itype, needle) or Has(isubtype, needle) or Has(SlotName(slot), needle) then
		return true
	end
	local name = Name()
	if name and name:find(needle, 1, true) then
		return true
	end
	local label = Label()
	if label and label:find(needle, 1, true) then
		return true
	end
	if name == nil then
		return nil
	end
	return false
end

local function Section(key)
	return function(record)
		for _, entry in ipairs(Categories.LIST or {}) do
			if entry.key == key then
				return type(entry.test) == "function" and entry.test(record) == true
			end
		end
		return false
	end
end

local function Consumable(subclass)
	return function(record)
		local class, sub = Kind(record)
		return class == CONSUMABLE and (subclass == nil or sub == subclass)
	end
end

local function OfQuality(quality)
	return function(record)
		return ns.Finite(record.quality) and record.quality == quality
	end
end

local function GameNew(record)
	local bag, slot = Whole(record.bag), Whole(record.slot)
	if record.live ~= true or not bag or not slot or not BAGS[bag] or type(C_NewItems) ~= "table" or type(C_NewItems.IsNewItem) ~= "function" then
		return false
	end
	local ok, isNew = pcall(C_NewItems.IsNewItem, bag, slot)
	return ok and not ns.IsSecret(isNew) and isNew == true
end

local function BoE(record)
	local marks = ns.ItemMarks
	local answer = type(marks) == "table" and marks.BoE or nil
	if type(answer) ~= "function" or record.bound == true then
		return false
	end
	if not Cached() then
		return nil
	end
	return answer(record.id, Text(record.link), false) == true
end

local function Unusable(record, which)
	local marks = ns.ItemMarks
	local answer = type(marks) == "table" and marks[which or "Unusable"] or nil
	if type(answer) ~= "function" then
		return "none"
	end
	local me = ns.CharacterKey()
	local mine = record.live == true or (me ~= nil and Text(record.key) == me)
	if not mine then
		return "none"
	end
	if not Cached() then
		return nil
	end
	local bag, slot
	if record.live == true then
		bag, slot = Whole(record.bag), Whole(record.slot)
	end
	local unusable = answer(record.id, Text(record.link), bag, slot)
	if unusable == nil then
		return nil
	end
	return unusable == true
end

local KEYWORDS = {
	junk = function(record)
		return Categories.IsJunk(record) == true
	end,
	new = function(record)
		if Opt("newItems") == false then
			return GameNew(record)
		end
		return Categories.New.Is(record) == true
	end,
	quest = Section("quest"),
	gear = function(record)
		local class = Class(record)
		return class == WEAPON or class == ARMOR
	end,
	weapon = function(record)
		return Class(record) == WEAPON
	end,
	armor = function(record)
		return Class(record) == ARMOR
	end,
	consumable = Consumable(nil),
	potion = Consumable(POTION),
	elixir = Consumable(ELIXIR),
	flask = Consumable(FLASK),
	scroll = Consumable(SCROLL),
	food = Consumable(FOOD),
	bandage = Consumable(BANDAGE),
	trade = Section("trade"),
	reagent = Section("reagent"),
	recipe = Section("recipe"),
	ammo = Section("ammo"),
	bag = Section("bag"),
	key = Section("key"),
	boe = BoE,
	bound = function(record)
		return record.bound == true
	end,
	set = function(record)
		return record.set == true
	end,
	placed = function(record)
		local placedKey = Categories.PlacedKey
		if type(placedKey) ~= "function" then
			return false
		end
		local ok, key = pcall(placedKey, record)
		return ok and type(key) == "string"
	end,
	pinned = function(record)
		local pins = B.Pins
		local of = type(pins) == "table" and pins.Of or nil
		if record.live ~= true or type(of) ~= "function" then
			return false
		end
		local ok, pinned = pcall(of, record)
		return ok and pinned == true
	end,
	unusable = function(record)
		local answer = Unusable(record)
		if answer == nil then
			return nil
		end
		return answer == true
	end,
	usable = function(record)
		local answer = Unusable(record)
		if answer == nil then
			return nil
		end
		return answer == false
	end,
	learnable = function(record)
		local answer = Unusable(record, "Learnable")
		if answer == nil then
			return nil
		end
		return answer == true
	end,
	poor = OfQuality(0),
	common = OfQuality(1),
	uncommon = OfQuality(2),
	rare = OfQuality(3),
	epic = OfQuality(4),
	legendary = OfQuality(5),
}
KEYWORDS.armour = KEYWORDS.armor

local clientQualities

local function QualityOf(value)
	local number = tonumber(value)
	if number then
		if number >= 0 and number <= MOST_QUALITY and number == math.floor(number) then
			return number
		end
		return nil
	end
	if QUALITIES[value] then
		return QUALITIES[value]
	end
	if not clientQualities then
		clientQualities = {}
		for quality = 0, MOST_QUALITY do
			local name = Text(_G["ITEM_QUALITY" .. quality .. "_DESC"])
			if name then
				clientQualities[name:lower()] = quality
			end
		end
	end
	return clientQualities[value]
end

local function LevelRange(value, cmp)
	local single = tonumber(value)
	if single then
		return single, single
	end
	if cmp ~= "=" then
		return nil
	end
	local from, to = value:match("^([%d%.]+)%-([%d%.]*)$")
	from, to = tonumber(from), tonumber(to)
	if not from then
		return nil
	end
	if not to then
		return from, math.huge
	end
	if to < from then
		from, to = to, from
	end
	return from, to
end

local function Operator(rest)
	local two = rest:sub(1, 2)
	if two == ">=" or two == "<=" then
		return two, rest:sub(3)
	end
	local one = rest:sub(1, 1)
	if one == ">" or one == "<" or one == "=" then
		return one, rest:sub(2)
	elseif one == ":" then
		return "=", rest:sub(2)
	end
	return nil
end

local function Comparison(low)
	local field, rest
	if low:sub(1, 4) == "ilvl" then
		field, rest = "ilvl", low:sub(5)
	elseif low:sub(1, 1) == "q" then
		field, rest = "q", low:sub(2)
	else
		return nil
	end
	local cmp, value = Operator(rest)
	if not cmp or value == "" then
		return nil
	end
	if field == "q" then
		local quality = QualityOf(value)
		if quality == nil then
			return nil
		end
		return { op = "q", cmp = cmp, low = quality, high = quality }
	end
	local from, to = LevelRange(value, cmp)
	if not from then
		return nil
	end
	return { op = "ilvl", cmp = cmp, low = from, high = to }
end

local function Compare(value, cmp, low, high)
	if cmp == "=" then
		return value >= low and value <= high
	elseif cmp == "<" then
		return value < low
	elseif cmp == "<=" then
		return value <= low
	elseif cmp == ">" then
		return value > low
	end
	return value >= low
end

local function Level(record)
	local level = record.level
	if ns.Finite(level) then
		return level
	end
	local class = Class(record)
	if class ~= WEAPON and class ~= ARMOR then
		return false
	end
	if not Cached() then
		return nil
	end
	local items, link = ns.Items, Text(record.link)
	local levelOf = type(items) == "table" and items.LevelOf or nil
	level = link and type(levelOf) == "function" and levelOf(link) or nil
	if not ns.Finite(level) then
		return false
	end
	record.level = level
	return level
end

local function TipText(record)
	if not Cached() then
		return nil
	end
	local link = Text(record.link) or ("item:" .. record.id)
	local known = tips.texts[link]
	if known ~= nil then
		return known
	end
	local api = C_TooltipInfo
	local get = type(api) == "table" and not ns.IsSecret(api) and api.GetHyperlink or nil
	if type(get) ~= "function" then
		return false
	end
	local ok, data = pcall(get, link)
	if not ok or type(data) ~= "table" or ns.IsSecret(data) or type(data.lines) ~= "table" or ns.IsSecret(data.lines) then
		return nil
	end
	local parts = {}
	for _, line in ipairs(data.lines) do
		if type(line) == "table" and not ns.IsSecret(line) then
			parts[#parts + 1] = Text(line.leftText)
			parts[#parts + 1] = Text(line.rightText)
		end
	end
	local found = table.concat(parts, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
	if tips.count >= TIP_MOST then
		tips.texts, tips.count = {}, 0
	end
	tips.texts[link], tips.count = found, tips.count + 1
	return found
end

local OPERATORS = { ["("] = true, [")"] = true, ["|"] = true, ["&"] = true, ["!"] = true }
local RUN = '^[^%s%(%)|&!"]+'

local function Tokens(source)
	local tokens, at, length = {}, 1, #source
	while at <= length do
		local char = source:sub(at, at)
		if char:find("^%s") then
			at = at + 1
		elseif char == "|" then
			local _, last = source:find("^|+", at)
			tokens[#tokens + 1] = { kind = "|" }
			at = last + 1
		elseif OPERATORS[char] then
			tokens[#tokens + 1] = { kind = char }
			at = at + 1
		elseif char == '"' then
			local close = source:find('"', at + 1, true)
			if not close then
				return nil
			end
			tokens[#tokens + 1] = { kind = "text", text = source:sub(at + 1, close - 1), quoted = true }
			at = close + 1
		else
			local _, last = source:find(RUN, at)
			tokens[#tokens + 1] = { kind = "text", text = source:sub(at, last) }
			at = last + 1
		end
	end
	return tokens
end

local function Term(token)
	local low = token.text:lower()
	if token.quoted then
		return { op = "word", text = low }
	end
	if low:sub(1, 4) == "tip:" and #low > 4 then
		return { op = "tip", text = low:sub(5) }
	end
	if low:sub(1, 1) == "#" then
		local name = low:sub(2)
		local test = KEYWORDS[name]
		if test then
			return { op = "key", test = test }
		end
		return { op = "word", text = name }
	end
	return Comparison(low) or { op = "word", text = low }
end

local Either

local function Primary(state)
	local token = state.tokens[state.at]
	if not token then
		return nil
	end
	if token.kind == "(" then
		state.at = state.at + 1
		local node = Either(state)
		local close = state.tokens[state.at]
		if not node or not close or close.kind ~= ")" then
			return nil
		end
		state.at = state.at + 1
		return node
	elseif token.kind == "text" then
		state.at = state.at + 1
		local quoted = state.tokens[state.at]
		if not token.quoted and token.text:lower() == "tip:" and quoted and quoted.kind == "text" and quoted.quoted then
			state.at = state.at + 1
			return { op = "tip", text = quoted.text:lower() }
		end
		return Term(token)
	end
	return nil
end

local function Negated(state)
	local token = state.tokens[state.at]
	if token and token.kind == "!" then
		state.at = state.at + 1
		local node = Negated(state)
		return node and { op = "not", node = node } or nil
	end
	return Primary(state)
end

local function Both(state)
	local first = Negated(state)
	if not first then
		return nil
	end
	local list = { first }
	while true do
		local token = state.tokens[state.at]
		if not token or token.kind == "|" or token.kind == ")" then
			break
		end
		if token.kind == "&" then
			state.at = state.at + 1
		end
		local node = Negated(state)
		if not node then
			return nil
		end
		list[#list + 1] = node
	end
	return #list == 1 and first or { op = "and", list = list }
end

Either = function(state)
	local first = Both(state)
	if not first then
		return nil
	end
	local list = { first }
	while true do
		local token = state.tokens[state.at]
		if not token or token.kind ~= "|" then
			break
		end
		state.at = state.at + 1
		local node = Both(state)
		if not node then
			return nil
		end
		list[#list + 1] = node
	end
	return #list == 1 and first or { op = "or", list = list }
end

local function Compile(source)
	local trimmed = (source:gsub("||", "|")):match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end
	local tokens = Tokens(trimmed)
	if tokens and #tokens > 0 then
		local state = { tokens = tokens, at = 1 }
		local node = Either(state)
		if node and state.at > #tokens then
			return node
		end
	end
	return { op = "word", text = trimmed:lower() }
end

local function Compiled()
	if compiled.text ~= text then
		compiled.text = text
		compiled.query = Compile(text)
	end
	return compiled.query
end

local Eval

local function Test(node, record)
	local op = node.op
	if op == "word" then
		return Word(node.text)
	elseif op == "key" then
		local answer = node.test(record)
		if answer == nil then
			return nil
		end
		return answer == true
	elseif op == "q" then
		local quality = record.quality
		if not ns.Finite(quality) then
			return false
		end
		return Compare(quality, node.cmp, node.low, node.high)
	elseif op == "ilvl" then
		local level = Level(record)
		if level == nil or level == false then
			return level
		end
		return Compare(level, node.cmp, node.low, node.high)
	elseif op == "tip" then
		local found = TipText(record)
		if found == nil or found == false then
			return found
		end
		return found:find(node.text, 1, true) ~= nil
	end
	return false
end

Eval = function(node, record)
	local op = node.op
	if op == "and" then
		local result = true
		for _, child in ipairs(node.list) do
			local answer = Eval(child, record)
			if answer == false then
				return false
			elseif answer == nil then
				result = nil
			end
		end
		return result
	elseif op == "or" then
		local result = false
		for _, child in ipairs(node.list) do
			local answer = Eval(child, record)
			if answer == true then
				return true
			elseif answer == nil then
				result = nil
			end
		end
		return result
	elseif op == "not" then
		local answer = Eval(node.node, record)
		if answer == nil then
			return nil
		end
		return not answer
	end
	return Test(node, record)
end

function Search.Text()
	return text
end

function Search.Active()
	return Compiled() ~= nil
end

function Search.Match(record)
	local query = Compiled()
	if query == nil then
		return true
	end
	if type(record) ~= "table" or not Whole(record.id) then
		return false
	end
	Begin(record)
	local answer = Eval(query, record)
	Begin(nil)
	return answer
end

function Search.Help()
	local lines = {}
	for index, line in ipairs(HELP) do
		lines[index] = line
	end
	return lines
end

local function Focused(box)
	local ok, focus = pcall(box.HasFocus, box)
	return ok and not ns.IsSecret(focus) and focus == true
end

local function PaintCross(own)
	local r, g, b, a = 1, 1, 1, CROSS_ALPHA
	if own.hover then
		r, g, b = ns.Colour("windows.accent")
		a = 1
	end
	for _, line in ipairs(own.lines) do
		line:SetColorTexture(r, g, b, a)
	end
end

local function Paint(box)
	local own = boxes[box]
	if not own then
		return
	end
	local r, g, b = ns.Colour("windows.panel")
	ns.SetOutlineFill(own.outline, r, g, b, 1)
	if Focused(box) then
		local ar, ag, ab = ns.Colour("windows.accent")
		ns.SetOutlineColour(own.outline, ar, ag, ab)
	else
		ns.SetOutlineColour(own.outline, nil, nil, nil)
	end
	PaintCross(own)
end

local function Count(box, own)
	local label = own.count
	if not label then
		return
	end
	local inset = INSET_RIGHT
	if own.matches ~= nil and text ~= "" then
		local colour = own.matches == 0 and NONE_RGB or DIM
		label:SetTextColor(colour[1], colour[2], colour[3])
		label:SetText(tostring(own.matches))
		label:Show()
		local ok, width = pcall(label.GetStringWidth, label)
		inset = INSET_RIGHT + (ok and ns.Finite(width) and math.ceil(width) or 12) + COUNT_GAP
	else
		label:Hide()
	end
	if own.inset ~= inset then
		own.inset = inset
		pcall(box.SetTextInsets, box, INSET_LEFT, inset, 0, 0)
	end
end

local function Refresh(box)
	local own = boxes[box]
	if not own then
		return
	end
	local ok, typed = pcall(box.GetText, box)
	local empty = not ok or type(typed) ~= "string" or typed == ""
	if own.hint then
		own.hint:SetShown(empty and not Focused(box))
	end
	own.clear:SetShown(not empty)
	Count(box, own)
end

local function WriteBoxes()
	for box in pairs(boxes) do
		local ok, typed = pcall(box.GetText, box)
		if not ok or typed ~= text then
			pcall(box.SetText, box, text)
		end
		Refresh(box)
	end
end

local function Recent()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local list = type(bags) == "table" and bags.recent or nil
	if type(list) == "table" and #list > 0 then
		return list
	end
	return nil
end

local function Remember(value)
	value = Text(value)
	local letters = value and value:gsub("%s", "") or ""
	if #letters < 2 or QUICK_TERMS[value] then
		return
	end
	local db = ns.Account()
	if type(db) ~= "table" then
		return
	end
	if type(db.bags) ~= "table" then
		db.bags = {}
	end
	local list = { value }
	for _, kept in ipairs(Recent() or {}) do
		if type(kept) == "string" and kept ~= value and #list < RECENT then
			list[#list + 1] = kept
		end
	end
	db.bags.recent = list
end

function Search.SetText(value)
	value = Text(value) or ""
	if value == text then
		return
	end
	if value == "" then
		Remember(text)
	end
	text = value
	if not writing then
		writing = true
		pcall(WriteBoxes)
		writing = false
	end
	local request = B.Request
	if type(request) == "function" then
		request("search")
	end
end

function Search.SetCount(owner, n)
	n = ns.Finite(n) and n >= 0 and math.floor(n) or nil
	for box, own in pairs(boxes) do
		if own.owner == owner and own.matches ~= n then
			own.matches = n
			Count(box, own)
		end
	end
end

function Search.Paint()
	for box in pairs(boxes) do
		Paint(box)
	end
end

local function Typed(box)
	local ok, typed = pcall(box.GetText, box)
	if ok and type(typed) == "string" then
		Search.SetText(typed)
	end
end

local function KeyLine()
	local window = B.Window
	local name = type(window) == "table" and window.KeyName or nil
	local ok, line = false, nil
	if type(name) == "function" then
		ok, line = pcall(name, "CLICK FlatUIBagSearchButton:LeftButton")
	end
	if not (ok and type(line) == "string") then
		return "Bind a key under Flat UI in Key Bindings."
	end
	return line
end

local function Tip(box)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) or Errands.Fighting() or Focused(box) then
		return
	end
	tip:SetOwner(box, "ANCHOR_BOTTOM", 0, -4)
	if text ~= "" then
		tip:SetText("Searching: " .. text, 1, 1, 1)
		local own = boxes[box]
		local n = own and own.matches or nil
		if n then
			tip:AddLine(n == 1 and "1 item matches" or ("%d items match"):format(n), 1, 1, 1)
		end
		tip:AddLine(SHORT, DIM[1], DIM[2], DIM[3], true)
		tip:AddLine(KeyLine(), DIM[1], DIM[2], DIM[3], true)
		tip:Show()
		return
	end
	tip:SetText(HELP[1])
	for index = 2, #HELP do
		tip:AddLine(HELP[index], 1, 1, 1, true)
	end
	tip:AddLine(KeyLine(), 1, 1, 1, true)
	tip:Show()
end

local function TipAway(box)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, box)
	if ok and not ns.IsSecret(owned) and owned == true then
		tip:Hide()
	end
end

local function Cross(box, own)
	local button = CreateFrame("Button", nil, box)
	ns.Own[button] = true
	button:SetSize(HEIGHT, HEIGHT)
	button:SetPoint("RIGHT", box, "RIGHT", 0, 0)
	own.lines = {}
	local half = CROSS / 2
	for _, ends in ipairs({ { -half, half, half, -half }, { -half, -half, half, half } }) do
		local ok, line = pcall(button.CreateLine, button, nil, "OVERLAY", nil, 2)
		if ok and type(line) == "table" then
			ns.Own[line] = true
			line:SetThickness(CROSS_LINE)
			line:SetStartPoint("CENTER", button, ends[1], ends[2])
			line:SetEndPoint("CENTER", button, ends[3], ends[4])
			own.lines[#own.lines + 1] = line
		end
	end
	button:SetScript("OnEnter", function()
		own.hover = true
		PaintCross(own)
	end)
	button:SetScript("OnLeave", function()
		own.hover = false
		PaintCross(own)
	end)
	button:SetScript("OnHide", function()
		own.hover = false
	end)
	button:SetScript("OnClick", function()
		Run(function()
			Search.SetText("")
			box:ClearFocus()
		end)
	end)
	button:Hide()
	return button
end

local function Quick(box, owner)
	local items = {}
	for _, quick in ipairs(QUICK) do
		local term = quick[2]
		items[#items + 1] = { text = quick[1], right = term, tick = text == term, part = "search", pick = function()
			Search.SetText(term)
			box:ClearFocus()
		end }
	end
	if text ~= "" then
		items[#items + 1] = { text = "Clear", part = "search", pick = function()
			Search.SetText("")
			box:ClearFocus()
		end }
	end
	local recent = Recent()
	if recent then
		items[#items + 1] = { text = "Recent", header = true }
		for _, kept in ipairs(recent) do
			if type(kept) == "string" and kept ~= "" then
				local shown = kept
				if #shown > RECENT_LETTERS then
					shown = shown:sub(1, RECENT_LETTERS - 3):gsub("|+$", "") .. "..."
				end
				items[#items + 1] = { text = shown, tick = text == kept, part = "search", pick = function()
					Search.SetText(kept)
					box:ClearFocus()
				end }
			end
		end
		items[#items + 1] = { text = "Clear recent", part = "search", pick = function()
			local db = ns.Account()
			if type(db) == "table" and type(db.bags) == "table" then
				db.bags.recent = nil
			end
		end }
	end
	local layout = B.Layout
	if type(layout) == "table" and type(layout.Menu) == "function" then
		TipAway(box)
		layout.Menu(box, "Quick searches", items, owner)
	end
end

local function Recall(box, key)
	local own, list = boxes[box], Recent()
	if not (own and list) or (key ~= "UP" and key ~= "DOWN") then
		return
	end
	local at = math.min(own.recall or 0, #list)
	if key == "UP" then
		if at == 0 then
			own.typed = text
		end
		local was = at
		at = at + 1
		while list[at] == text and at < #list do
			at = at + 1
		end
		if list[at] == nil or list[at] == text then
			at = was
		end
	elseif at > 0 then
		at = at - 1
		while at > 0 and list[at] == text do
			at = at - 1
		end
	end
	if at == (own.recall or 0) then
		return
	end
	own.recall = at
	Search.SetText(at == 0 and (own.typed or "") or list[at])
	local ok, typed = pcall(box.GetText, box)
	if ok and type(typed) == "string" then
		pcall(box.SetCursorPosition, box, #typed)
	end
end

function Search.Box(parent, owner)
	local box = CreateFrame("EditBox", nil, parent)
	ns.Own[box] = true
	box:SetSize(WIDTH, HEIGHT)
	box:SetAutoFocus(false)
	box:SetFontObject(FONT)
	box:SetTextInsets(INSET_LEFT, INSET_RIGHT, 0, 0)
	pcall(box.SetMaxLetters, box, MOST_LETTERS)
	local own = { outline = ns.SetOutlineArea(ns.Outline(box, box, true), KEY), hover = false, owner = owner }
	own.hint = ns.OwnText(box, "ARTWORK", FONT)
	if own.hint then
		own.hint:SetPoint("LEFT", box, "LEFT", INSET_LEFT, 0)
		own.hint:SetText(HINT)
		own.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
	end
	own.count = ns.OwnText(box, "ARTWORK", FONT)
	if own.count then
		own.count:SetPoint("RIGHT", box, "RIGHT", -INSET_RIGHT, 0)
		own.count:SetJustifyH("RIGHT")
		own.count:Hide()
	end
	boxes[box] = own
	own.clear = Cross(box, own)
	box:SetScript("OnTextChanged", function(self, typed)
		if typed and not writing then
			own.recall = 0
			TipAway(self)
			Run(Typed, self)
		end
		Refresh(self)
	end)
	box:SetScript("OnArrowPressed", function(self, key)
		Run(Recall, self, key)
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self)
		Run(Remember, text)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusGained", function(self)
		own.recall = 0
		TipAway(self)
		Paint(self)
		Refresh(self)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		Run(Remember, text)
		Paint(self)
		Refresh(self)
	end)
	box:SetScript("OnShow", function(self)
		local ok, typed = pcall(self.GetText, self)
		if not ok or typed ~= text then
			writing = true
			pcall(self.SetText, self, text)
			writing = false
		end
		Paint(self)
		Refresh(self)
	end)
	box:SetScript("OnHide", function(self)
		self:ClearFocus()
		TipAway(self)
	end)
	box:SetScript("OnEnter", function(self)
		Run(Tip, self)
	end)
	box:SetScript("OnLeave", function(self)
		TipAway(self)
	end)
	box:SetScript("OnMouseUp", function(self, mouse)
		if mouse == "RightButton" then
			Run(Quick, self, owner)
		end
	end)
	writing = true
	pcall(box.SetText, box, text)
	writing = false
	Paint(box)
	Refresh(box)
	return box
end

local function KeyPressed()
	local window = B.Window
	if type(B.On) ~= "function" or B.On() ~= true or type(window) ~= "table" or type(window.Focus) ~= "function" then
		print(ns.Enabled(KEY) and KEY_SAY.down or KEY_SAY.off)
		return
	end
	if window.Focus("bags", true) then
		return
	end
	if type(B.Hold) ~= "function" or B.Hold("command", true) ~= true then
		print(KEY_SAY.shut)
		return
	end
	C_Timer.After(0, function()
		Run(window.Focus, "bags")
	end)
end

do
	local ok, button = pcall(CreateFrame, "Button", KEY_BUTTON, UIParent)
	if ok and type(button) == "table" then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			Run(KeyPressed)
		end)
	end
end
