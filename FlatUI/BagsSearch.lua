local _, ns = ...

-- Bags: the search. One text serves every window: typing in one box writes the others (SetText on boxes of Flat UI's own; a text written that
-- way is not taken for typing), and Bags.lua clears it when the bag window closes while the bank window is not shown. Nothing is hidden and
-- nothing moves: a record that does not match is drawn dimmed by BagsItems.lua, and the layout does not run. The game's own search, SetItemSearch
-- of C_Container, is never used: it is shared with the game's boxes, which clear it when they hide
-- (Blizzard_UIPanelTemplates/Shared/UIPanelTemplatesShared.lua:1-31), and it does not reach the items of the bank away from the banker or of
-- other characters. Bags.lua makes ns.Bags with B.Search; this file only adds its fields. It owns no event: BagsData.lua asks for the search
-- again (B.Request("search")) when the data of an item arrives.
--
-- The grammar is Flat UI's own. Brackets bind first, then ! (not), then and (a space or &), then | (or). A term is a #keyword, a comparison
-- (q or ilvl, then :, =, <, <=, > or >=, then a value; ilvl also takes a range such as 20-30), or a word: any other run of letters, or "quoted
-- text". Text that does not parse, such as an open bracket while typing, is looked for whole as one word, so typing never fails, and a #word
-- that is no keyword is looked for as a word without its #. The text is compiled once for each change.
--
-- A word is plain text, never a pattern (string.find with plain on), found without regard to case (string.lower, which folds A to Z only) in the
-- item's name (the record's, else C_Item.GetItemNameByID), its type and subtype as C_Item.GetItemInfoInstant gives them in the client's language,
-- the name of its equip slot (the game's global string the slot is named by, INVTYPE_HEAD and the like) and the label of its section, so potion,
-- cloth, mail, head and consumables all find something. The keywords are English: #junk (the junk test of BagsCategories.lua), #new, #quest,
-- #gear, #weapon, #armor or #armour (classes 2 and 4, 2, 4), #consumable and its subclasses #potion, #elixir, #flask, #scroll, #food and
-- #bandage (Enum.ItemClass and Enum.ItemConsumableSubclass, wowless, data/products/wowf/enums.yaml:4630-4651 and 4694-4711), #trade, #reagent,
-- #recipe, #ammo, #bag and #key (the rules of those sections), #boe (ItemMarks' answer, ns.ItemMarks.BoE, ItemMarks.lua:184-191), #bound,
-- #set, #usable and #unusable (ItemMarks' tooltip test, ns.ItemMarks.Unusable, :247-279), and the qualities #poor to #legendary. q takes 0 to 7,
-- the English names or the client's (ITEM_QUALITY0_DESC to ITEM_QUALITY7_DESC, Enum.ItemQuality, enums.yaml:5101-5111); ilvl compares the item
-- level of weapons and armour (ns.Items.LevelOf, Items.lua:425-438), and an item with no level never matches it.
--
-- A record whose name the client has not loaded yet matches nil, unknown, when only its name could decide: it is drawn dimmed until the name
-- comes. The search never asks the server for an item: the name, the binding, the tooltip and the item level are read only once
-- C_Item.IsItemDataCachedByID says the client has the item, since the picker of characters counts matches over items no window shows. #usable
-- and #unusable say what this character can use, so another character's items match neither.
--
-- The box is an EditBox of Flat UI's own (CreateFrame), HEIGHT high, in the look of Windows' text boxes (an outline filled with the Button and slot
-- colour, Windows.lua:1230-1253), with the edge in the Highlight colour while it has the keyboard (HasFocus): GameFontHighlightSmall, a Search
-- hint in the dim text colour (Threat.lua:46), and a cross that clears it, a Button of its own drawn as two lines (CreateLine, as Windows draws
-- its close button, Windows.lua:490-524). The box is written and read with SetText and GetText.
-- Escape and Enter give the keyboard back (ClearFocus), so a second Escape is the game's, and a box that hides gives it back too. Pointing at the
-- box out of a fight (InCombatLockdown and UnitAffectingCombat, through Errands.Fighting) writes the grammar in GameTooltip in plain lines
-- (SetOwner, SetText, AddLine, Show, and Hide while the box owns it, IsOwned); the search itself, typing and the cross work in a fight too.

local KEY = "bags"
local B = ns.Bags
local Search = B.Search
local Categories = B.Categories
local Errands = ns.Errands

local FONT = "GameFontHighlightSmall"
local WIDTH, HEIGHT = 140, 18
-- Room for the text on the left and for the cross on the right, the size of the cross and its lines, and its opacity at rest.
local INSET_LEFT, INSET_RIGHT = 6, 18
local CROSS, CROSS_LINE, CROSS_ALPHA = 7, 1.5, 0.6
local MOST_LETTERS = 80
local HINT = "Search"
-- The text-dim of the windows (PanelLook.lua), as the Threat list uses it.
local DIM = { 0.66, 0.68, 0.62 }

-- Enum.ItemClass and Enum.ItemConsumableSubclass on Forever (enums.yaml:4630-4651, 4694-4711).
local CONSUMABLE, WEAPON, ARMOR = 0, 2, 4
local POTION, ELIXIR, FLASK, SCROLL, FOOD, BANDAGE = 1, 2, 3, 4, 5, 7
-- Enum.ItemQuality (enums.yaml:5101-5111): the English names q takes, and the highest quality it takes.
local QUALITIES = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, artifact = 6, heirloom = 7 }
local MOST_QUALITY = 7

local HELP = {
	"Search",
	"Words look in each item's name, kind and slot, and in the name of its section: potion, cloth, mail, head, junk.",
	"A space or & is and, | is or, ! is not, brackets group, and \"quoted text\" is one word.",
	"#junk  #new  #quest  #boe  #bound  #set  #usable  #unusable",
	"#gear  #weapon  #armour  #consumable  #potion  #elixir  #flask  #food  #bandage  #scroll",
	"#trade  #reagent  #recipe  #ammo  #bag  #key",
	"#poor  #common  #uncommon  #rare  #epic  #legendary",
	"Quality: q:rare, q>=uncommon, q<3. Item level: ilvl:20-30, ilvl>40.",
	"For example: #boe q>=uncommon, !#junk mail, (cloth | leather) #gear.",
	"Items that do not match are dimmed. Enter or Escape leaves the box, and the cross clears it.",
}

-- The shared text, every box made (each with what it drew: { outline, hint, clear, lines, hover }), and whether this file is writing the boxes.
local text = ""
local boxes = setmetatable({}, { __mode = "k" })
local writing = false
-- The text last compiled and what it compiled to (nil for a text with nothing to look for).
local compiled = { text = nil, query = nil }

-- A text the client gave plainly, or nil.
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

-- Runs fn as the search part of the module (ns.EachPart through B.Part), so a part that keeps failing stops alone.
local function Run(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part("search", fn, ...)
	end
	return (pcall(fn, ...))
end

-- What is known of a record ---------------------------------------------------------------------------------------------------------------

-- The record being matched, and what was read of it once in this match: name (its name in lower case, false while the client has not loaded
-- it), label (its section's label in lower case), and cached (whether the client has the item's data).
local current = {}

local function Begin(record)
	current.record = record
	current.name, current.label, current.cached = nil, nil, nil
end

-- The class, subclass, equip slot, type and subtype of the record's item (BagsCategories.lua reads them for its rules).
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

-- Whether the client has the item's data, asked once per match. Nothing is asked of the server.
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

-- The item's name in lower case, or nil while the client has not loaded it.
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

-- The label of the record's section in lower case.
local function Label()
	if current.label == nil then
		local label = Text(Categories.Label(Categories.Of(current.record)))
		current.label = label and label:lower() or false
	end
	return current.label or nil
end

-- The name of an equip slot in the client's language: the global string the game names the slot by. An item that is worn nowhere has none, so a
-- word such as "equip" does not find every one of them.
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

-- Whether a word is found in the record: true, false, or nil when only the name could tell and it has not loaded.
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

-- Keywords -----------------------------------------------------------------------------------------------------------------------------------

-- A keyword of a section: the rule of that section in Categories.LIST.
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

-- Whether this character cannot use the item: true, false, nil while the client has not loaded it, or "none" when nobody can say for this
-- character: another character's item, or a build without ItemMarks' answer. The bank away from the banker is asked with no bag and slot.
local function Unusable(record)
	local marks = ns.ItemMarks
	local answer = type(marks) == "table" and marks.Unusable or nil
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
	poor = OfQuality(0),
	common = OfQuality(1),
	uncommon = OfQuality(2),
	rare = OfQuality(3),
	epic = OfQuality(4),
	legendary = OfQuality(5),
}
KEYWORDS.armour = KEYWORDS.armor

-- Comparisons --------------------------------------------------------------------------------------------------------------------------------

-- The client's names of the qualities in lower case, read the first time q is given a name.
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

-- The lowest and highest level an ilvl value takes: a number, or with : or = a range a-b (a- while typing is a and above).
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

-- The operator at the start of the rest of a comparison, and the value after it; : is =.
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

-- A comparison from a run of text in lower case, or nil when it is none.
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

-- The item level of a weapon or armour, false for an item with none, or nil while the client has not loaded it.
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

-- Parsing ----------------------------------------------------------------------------------------------------------------------------------

local OPERATORS = { ["("] = true, [")"] = true, ["|"] = true, ["&"] = true, ["!"] = true }
-- A run of text: anything but space, the operators and the quote.
local RUN = '^[^%s%(%)|&!"]+'

-- The tokens of a text: { kind = an operator } or { kind = "text", text, quoted }. Nil for a quote that is not closed.
local function Tokens(source)
	local tokens, at, length = {}, 1, #source
	while at <= length do
		local char = source:sub(at, at)
		if char:find("^%s") then
			at = at + 1
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

-- A recursive descent over the tokens: each step returns its node, or nil when the text does not parse.
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

-- What a text looks for, or nil for a text with nothing in it. A text that does not parse is one word.
local function Compile(source)
	local trimmed = source:match("^%s*(.-)%s*$") or ""
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

-- Matching ---------------------------------------------------------------------------------------------------------------------------------

-- true, false, or nil for unknown: and is false once one term is false, or is true once one term is true; not leaves unknown unknown.
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

-- True while the text looks for something.
function Search.Active()
	return Compiled() ~= nil
end

-- Whether a record matches the text: true, false, or nil while the client has not loaded what would decide it (drawn dimmed until it has).
-- Every record matches while the text is empty, and no record is no match.
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

-- The box ------------------------------------------------------------------------------------------------------------------------------------

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

-- The fill in the Button and slot colour, and the edge in the Highlight colour while the box has the keyboard.
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

-- The hint shows on an empty box without the keyboard, the cross on a box with text.
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

-- Sets the shared text, writes every box that shows another, and asks for the search again in both windows.
function Search.SetText(value)
	value = Text(value) or ""
	if value == text then
		return
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

-- Repaints every box: for a change of the Windows look while a window shows.
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

-- The grammar under the box, out of a fight only, as the tooltips of the bag window keep to.
local function Tip(box)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) or Errands.Fighting() then
		return
	end
	tip:SetOwner(box, "ANCHOR_BOTTOM", 0, -4)
	tip:SetText(HELP[1])
	for index = 2, #HELP do
		tip:AddLine(HELP[index], 1, 1, 1, true)
	end
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

-- The cross that clears the text: a button of the addon's own at the right of the box, drawn as two lines.
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

-- A search box of the addon's own on parent, WIDTH by HEIGHT until the caller sizes and places it. It shows the shared text.
function Search.Box(parent)
	local box = CreateFrame("EditBox", nil, parent)
	ns.Own[box] = true
	box:SetSize(WIDTH, HEIGHT)
	box:SetAutoFocus(false)
	box:SetFontObject(FONT)
	box:SetTextInsets(INSET_LEFT, INSET_RIGHT, 0, 0)
	pcall(box.SetMaxLetters, box, MOST_LETTERS)
	local own = { outline = ns.SetOutlineArea(ns.Outline(box, box, true), KEY), hover = false }
	own.hint = ns.OwnText(box, "ARTWORK", FONT)
	if own.hint then
		own.hint:SetPoint("LEFT", box, "LEFT", INSET_LEFT, 0)
		own.hint:SetText(HINT)
		own.hint:SetTextColor(DIM[1], DIM[2], DIM[3])
	end
	boxes[box] = own
	own.clear = Cross(box, own)
	box:SetScript("OnTextChanged", function(self, typed)
		if typed and not writing then
			Run(Typed, self)
		end
		Refresh(self)
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusGained", function(self)
		Paint(self)
		Refresh(self)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		Paint(self)
		Refresh(self)
	end)
	-- A text written while the box was hidden is shown, and the look read again.
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
	-- A hidden box would keep the keyboard.
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
	writing = true
	pcall(box.SetText, box, text)
	writing = false
	Paint(box)
	Refresh(box)
	return box
end
