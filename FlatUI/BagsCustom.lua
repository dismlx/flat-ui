local _, ns = ...

local KEY = "bags"
local B = ns.Bags
local Custom = B.Custom

local PART, PREFIX, MOST, LONGEST = "custom", "custom", 20, 24
local RULE_LETTERS, RULE_SHOWN = 80, 40
local SLOT, PLUS_LONG, PLUS_THICK = 37, 13, 2
local LIT, LIT_HOVER, HOVER = 0.14, 0.3, 0.12
local DIM = { 0.66, 0.68, 0.62 }
local PLUS, PLUS_ALPHA, PLUS_DIM = { 0.85, 0.85, 0.85 }, 0.85, 0.3
local RED = { 1, 0.35, 0.24 }
local DROP_CLICK = 0.3
local FLASH_WAIT, FLASH_FADE, SAY_HOLD, SAY_FADE, ARRIVE_WAIT = 1.5, 0.6, 1.5, 0.5, 5
local FLASH_LEVEL, FLASH_ALPHA, SAY_PAD, SAY_GAP = 40, 0.3, 4, 6
local CELL_LEVEL = 2
local FIGHT_LINE = "Flat UI: Bags: an item is put in a section out of combat only."
local FIGHT_TIP = "Items are put in a section out of combat only."
local BAG_IDS = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [-1] = true }
local LAST_WORN, FIRST_BAG, LAST_BAG = 19, 0, 4
local CONTAINER, QUIVER = 1, 11
local BOX_W, BOX_H, FIELD_H, BUTTON_W, BUTTON_H = 260, 112, 20, 64, 18
local STATUS_NAMES = 5
local ADD_WORD, ADDED_WORD = "New section", "Added"
local SAY = {
	most = "You have 20 sections of your own, the most Flat UI keeps. Delete one first.",
	saved = "Sections can be made once your saved settings have loaded.",
	empty = "Type a name for the section.",
	bar = "A name cannot have a | in it.",
	long = "A name has 24 letters at most.",
	builtin = "%s is one of Flat UI's own sections. Choose another name.",
	taken = "You have a section called %s already.",
	gone = "That section is not there any more.",
	fight = "sections are named out of a fight.",
	deleted = "%s is deleted. Right-click + New section to bring it back.",
	deletedOne = "%s is deleted. Its item goes back to its own section. Right-click + New section to bring it back.",
	deletedMany = "%s is deleted. Its %d items go back to their own sections. Right-click + New section to bring it back.",
	back = "%s is back.",
	backOne = "%s is back with its item.",
	backMany = "%s is back with its %d items.",
	backSome = "%s is back with %d of its %d items; the others are placed in another section now.",
	noBack = "No deleted section to bring back.",
	backFull = "You have 20 sections of your own, the most Flat UI keeps. Delete one first to bring %s back.",
	bagBar = "Put a bag in with the Bag slots row of the bag window.",
	noRoom = "Your bags have no free slot for %s.",
	notPut = "The game did not put %s in your bags.",
	nowhere = "%s is not in your bags. Put it there first, then drop it here.",
	asks = "The game asks before it buys %s. Buy it into your bags first, then drop it here.",
	buyFirst = "Buy %s into your bags first, then drop it here.",
	full = "You have 20 sections, the most. Delete one to make another.",
	newBuy = "Buy %s into your bags first, then drop it on New section.",
	newNowhere = "%s is not in your bags. Put it there first, then drop it on New section.",
}
local NOTES = { make = "Enter makes it, Escape cancels.", rename = "Enter renames it, Escape cancels." }
local TIPS = {
	idle = "Drop an item here, or click here with one on your cursor, to keep it in %s. An item from your bank or one you wear goes into a free "
		.. "slot of your bags first, and a merchant's item is bought into one.",
	idleJunk = "Drop an item here, or click here with one on your cursor, to sell it at merchants from now on.",
	idleKeep = "Drop an item of your bags here, or click here with one on your cursor, to pin the slot it came from to it.",
	full = " Your bags are full: only an item already in them can be kept here.",
	noRoom = "Your bags have no free slot for it. Make room first.",
	bagBar = "A bag goes in with the Bag slots row of the bag window.",
	keepOutside = "Only an item of your bags can be pinned.",
	move = "%s to move it into your bags and keep it in %s.",
	buy = "%s to buy it into a free slot of your bags and keep it in %s.",
	asks = "The game asks before it buys this item. Buy it into your bags first.",
	buyFirst = "Buy it into your bags first, then drop it here.",
	nowhere = "This item is not in your bags. Put it there first.",
	junk = "%s to sell it at merchants from now on.",
	keep = "%s to pin the slot it came from to it.",
	kept = "%s to keep it in %s.",
	drop = "Drop it here",
	letGo = "Let go here",
	refused = "This section does not take that item.",
	addHolding = "Drop the item here to make a new section for it and name it.",
	addBuy = "Buy it into your bags first, then drop it here to make a section for it.",
	add = "Click to make a section of your own and name it, then drop items on its title or its + slot. Right-click for your sections.",
	addFull = " You have 20, the most Flat UI keeps.",
}
local FLASH = { junk = "On your sell list", keep = "Pinned", moved = "Moved in: %s", kept = "Kept: %s", made = "Made", renamed = "Renamed",
	bought = "Bought: %s", back = "Back", rule = "Search kept" }
local COLOURS = {
	{ "plain", "Plain" },
	{ "red", "Red", 0.93, 0.38, 0.33 },
	{ "orange", "Orange", 0.96, 0.6, 0.26 },
	{ "gold", "Gold", 1, 0.82, 0.2 },
	{ "green", "Green", 0.45, 0.82, 0.38 },
	{ "teal", "Teal", 0.3, 0.8, 0.74 },
	{ "blue", "Blue", 0.42, 0.62, 1 },
	{ "purple", "Purple", 0.72, 0.5, 0.96 },
}
local COLOUR_OF = {}
for _, colour in ipairs(COLOURS) do
	COLOUR_OF[colour[1]] = colour
end
local DELETE_HEX = "|cffff5a3d"

local function Fn(tbl, name)
	local fn = type(tbl) == "table" and tbl[name] or nil
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Call(tbl, name, ...)
	local fn = Fn(tbl, name)
	if fn then
		return fn(...)
	end
	return nil
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Now()
	local ok, now = pcall(GetTime)
	return ok and ns.Finite(now) and now or 0
end

local function Say(text)
	print("Flat UI: " .. text)
end

local function Whole(value)
	if ns.Finite(value) and value == math.floor(value) then
		return value
	end
	return nil
end

local function Plain(text)
	return (tostring(text):gsub("|", "||"))
end

local function Fighting()
	local errands = ns.Errands
	local fighting = type(errands) == "table" and errands.Fighting or nil
	if type(fighting) ~= "function" then
		local ok, lockdown = pcall(InCombatLockdown)
		return not ok or ns.IsSecret(lockdown) or lockdown == true
	end
	local ok, fight = pcall(fighting)
	return not ok or fight == true
end

local function Request(flag)
	Call(B, "Request", flag)
end

local function Part(fn, ...)
	local part = Fn(B, "Part")
	if part then
		return part(PART, fn, ...)
	end
	return pcall(fn, ...)
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Container(name)
	return type(C_Container) == "table" and C_Container[name] or nil
end

local function Item(name)
	return type(C_Item) == "table" and C_Item[name] or nil
end

local function Number(frame, method, ...)
	local fn = type(frame) == "table" and frame[method] or nil
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, frame, ...)
	if ok and ns.Finite(value) then
		return value
	end
	return nil
end

local function Colour(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and ns.Finite(cr) and ns.Finite(cg) and ns.Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Accent()
	return Colour("windows.accent", 0.85, 0.85, 0.85)
end

local function Opacity()
	local value = Call(B, "Look", "opacity")
	if not ns.Finite(value) then
		value = ns.Get("windows.opacity")
	end
	return ns.Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

local function TextWidth(text)
	return Number(text, "GetUnboundedStringWidth") or Number(text, "GetStringWidth") or 0
end

local function Untip(frame)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, frame)
	if ok and owned == true then
		tip:Hide()
	end
end

local function ItemName(id)
	local name = Ask(Item("GetItemNameByID"), id)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return ("item %d"):format(id)
end

local function Bags(make)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	local bags = db.bags
	if type(bags) ~= "table" then
		if not make then
			return nil
		end
		bags = {}
		db.bags = bags
	end
	return bags
end

local function KeyNumber(key)
	if type(key) ~= "string" or ns.IsSecret(key) then
		return nil
	end
	local digits = key:match("^" .. PREFIX .. "(%d+)$")
	return digits and tonumber(digits) or nil
end

local revision, cache = 0, nil
local NO_RULES = {}

local function Changed()
	revision = revision + 1
end

local function CleanRule(text)
	if type(text) ~= "string" or ns.IsSecret(text) then
		return nil
	end
	text = text:match("^%s*(.-)%s*$") or ""
	if text == "" or #text > RULE_LETTERS then
		return nil
	end
	return text
end

local function Read()
	local bags = Bags(false)
	local list = bags and bags.custom
	if type(list) ~= "table" then
		list = nil
	end
	local size = list and #list or 0
	if cache and cache.revision == revision and cache.list == list and cache.size == size then
		return cache
	end
	local keys, names, entries, rules = {}, {}, {}, {}
	for _, entry in ipairs(list or {}) do
		if type(entry) == "table" then
			local key, name = entry.key, entry.name
			if KeyNumber(key) and names[key] == nil and type(name) == "string" and not ns.IsSecret(name) and name ~= "" then
				keys[#keys + 1] = key
				names[key] = name
				entries[key] = entry
				rules[key] = CleanRule(entry.rule)
			end
		end
	end
	cache = { revision = revision, list = list, size = size, keys = keys, names = names, entries = entries, rules = rules,
		ruled = next(rules) ~= nil }
	return cache
end

function Custom.Keys()
	local keys = {}
	for index, key in ipairs(Read().keys) do
		keys[index] = key
	end
	return keys
end

function Custom.Is(key)
	return type(key) == "string" and Read().names[key] ~= nil
end

function Custom.Name(key)
	if type(key) ~= "string" then
		return nil
	end
	return Read().names[key]
end

function Custom.Rule(key)
	if type(key) ~= "string" then
		return nil
	end
	return Read().rules[key]
end

local function Counts()
	local counts = {}
	local names = Read().names
	local bags = Bags(false)
	local placed = bags and bags.placed
	for id, key in pairs(type(placed) == "table" and placed or {}) do
		if Whole(id) and type(key) == "string" and names[key] then
			counts[key] = (counts[key] or 0) + 1
		end
	end
	return counts
end

function Custom.Count(key)
	return Counts()[key] or 0
end

local function Sorted()
	local data = Read()
	local keys = {}
	for index, key in ipairs(data.keys) do
		keys[index] = key
	end
	local okRanks, ranks = pcall(Call, B.Order, "Ranks")
	ranks = okRanks and type(ranks) == "table" and ranks or {}
	local names = data.names
	table.sort(keys, function(a, b)
		local ra, rb = ranks[a] or math.huge, ranks[b] or math.huge
		if ra ~= rb then
			return ra < rb
		end
		local na, nb = names[a]:lower(), names[b]:lower()
		if na ~= nb then
			return na < nb
		end
		return a < b
	end)
	return keys, names
end

local ruleKeys = { at = nil, revision = nil, keys = NO_RULES }

function Custom.RuleKeys()
	local data = Read()
	if not data.ruled then
		return NO_RULES
	end
	local now = Now()
	if ruleKeys.revision == revision and ruleKeys.data == data and ruleKeys.at == now then
		return ruleKeys.keys
	end
	local keys = {}
	for _, key in ipairs((Sorted())) do
		if data.rules[key] then
			keys[#keys + 1] = key
		end
	end
	ruleKeys.at, ruleKeys.revision, ruleKeys.data, ruleKeys.keys = now, revision, data, keys
	return keys
end

local function SetRule(key, text)
	local entry = type(key) == "string" and Read().entries[key] or nil
	if not entry then
		return false
	end
	text = CleanRule(text)
	if entry.rule ~= text then
		entry.rule = text
		Changed()
		Request("layout")
	end
	return true
end

local function BuiltIn(lower)
	if lower == ADDED_WORD:lower() or lower == ADD_WORD:lower() then
		return true
	end
	local list = B.Categories and B.Categories.LIST
	for _, entry in ipairs(type(list) == "table" and list or {}) do
		if type(entry) == "table" and ((type(entry.label) == "string" and entry.label:lower() == lower)
			or (type(entry.each) == "string" and entry.each:lower() == lower)) then
			return true
		end
	end
	return false
end

local function Check(name, except)
	if type(name) ~= "string" or ns.IsSecret(name) then
		return nil, SAY.empty
	end
	local clean = (name:gsub("%s+", " ")):match("^%s*(.-)%s*$") or ""
	if clean == "" then
		return nil, SAY.empty
	end
	if clean:find("|", 1, true) then
		return nil, SAY.bar
	end
	if #(clean:gsub("[\128-\191]", "")) > LONGEST then
		return nil, SAY.long
	end
	local lower = clean:lower()
	if BuiltIn(lower) then
		return nil, SAY.builtin:format(clean)
	end
	local data = Read()
	for _, key in ipairs(data.keys) do
		if key ~= except and data.names[key]:lower() == lower then
			return nil, SAY.taken:format(Plain(data.names[key]))
		end
	end
	return clean
end

local function Forget(bags, gone)
	local count = 0
	local placed = bags.placed
	if type(placed) == "table" then
		for id, key in pairs(placed) do
			if gone(key) then
				placed[id] = nil
				count = count + 1
			end
		end
	end
	local folded = bags.folded
	if type(folded) == "table" then
		for key in pairs(folded) do
			if gone(key) then
				folded[key] = nil
			end
		end
		if next(folded) == nil then
			bags.folded = nil
		end
	end
	local order = bags.order
	if type(order) == "table" then
		for index = #order, 1, -1 do
			if gone(order[index]) then
				table.remove(order, index)
			end
		end
		if #order == 0 then
			bags.order = nil
		end
	end
	return count
end

function Custom.Make(name)
	if #Read().keys >= MOST then
		return nil, SAY.most
	end
	local bags = Bags(true)
	if not bags then
		return nil, SAY.saved
	end
	local clean, why = Check(name)
	if not clean then
		return nil, why
	end
	local number = math.max(Whole(bags.customNext) or 1, 1)
	local function Above(key)
		local saved = KeyNumber(key)
		if saved and saved >= number then
			number = saved + 1
		end
	end
	for _, entry in ipairs(type(bags.custom) == "table" and bags.custom or {}) do
		if type(entry) == "table" then
			Above(entry.key)
		end
	end
	for _, key in pairs(type(bags.placed) == "table" and bags.placed or {}) do
		Above(key)
	end
	for key in pairs(type(bags.folded) == "table" and bags.folded or {}) do
		Above(key)
	end
	for _, key in ipairs(type(bags.order) == "table" and bags.order or {}) do
		Above(key)
	end
	if type(bags.custom) ~= "table" then
		bags.custom = {}
	end
	local key = PREFIX .. number
	bags.custom[#bags.custom + 1] = { key = key, name = clean }
	bags.customNext = number + 1
	Changed()
	Request("layout")
	return key
end

function Custom.Rename(key, name)
	local entry = type(key) == "string" and Read().entries[key] or nil
	if not entry then
		return false, SAY.gone
	end
	local clean, why = Check(name, key)
	if not clean then
		return false, why
	end
	if entry.name ~= clean then
		entry.name = clean
		Changed()
		Request("layout")
	end
	return true
end

local lastGone = nil

local function Remember(bags, key, name)
	local gone = { key = key, name = name, ids = {} }
	for index, entry in ipairs(bags.custom) do
		if type(entry) == "table" and entry.key == key then
			gone.index = gone.index or index
			gone.colour = gone.colour or (type(entry.colour) == "string" and COLOUR_OF[entry.colour] and entry.colour or nil)
			gone.rule = gone.rule or CleanRule(entry.rule)
		end
	end
	for id, placedKey in pairs(type(bags.placed) == "table" and bags.placed or {}) do
		if placedKey == key and Whole(id) then
			gone.ids[#gone.ids + 1] = id
		end
	end
	gone.folded = type(bags.folded) == "table" and bags.folded[key] == true
	for index, orderKey in ipairs(type(bags.order) == "table" and bags.order or {}) do
		if orderKey == key then
			gone.order = index
			break
		end
	end
	return gone
end

function Custom.Delete(key)
	local data = Read()
	local name = type(key) == "string" and data.names[key] or nil
	local bags = Bags(false)
	if not name or not bags or type(bags.custom) ~= "table" then
		return false, "Flat UI: " .. SAY.gone
	end
	lastGone = Remember(bags, key, name)
	local list = bags.custom
	for index = #list, 1, -1 do
		local entry = list[index]
		if type(entry) == "table" and entry.key == key then
			table.remove(list, index)
		end
	end
	if #list == 0 then
		bags.custom = nil
	end
	local count = Forget(bags, function(value)
		return value == key
	end)
	Changed()
	if Custom.Asking(key) then
		Custom.Close()
	end
	Request("layout")
	local text
	if count == 1 then
		text = SAY.deletedOne:format(Plain(name))
	elseif count > 1 then
		text = SAY.deletedMany:format(Plain(name), count)
	else
		text = SAY.deleted:format(Plain(name))
	end
	return true, "Flat UI: " .. text
end

function Custom.Gone()
	if not lastGone then
		return nil
	end
	return lastGone.name, #lastGone.ids
end

function Custom.Restore(which)
	local gone = lastGone
	if not gone then
		return false, "Flat UI: " .. SAY.noBack
	end
	if #Read().keys >= MOST then
		return false, "Flat UI: " .. SAY.backFull:format(Plain(gone.name))
	end
	local bags = Bags(true)
	if not bags then
		return false, "Flat UI: " .. SAY.saved
	end
	local clean, why = Check(gone.name)
	if not clean then
		return false, "Flat UI: " .. why
	end
	if Read().names[gone.key] then
		return false, "Flat UI: " .. SAY.gone
	end
	if type(bags.custom) ~= "table" then
		bags.custom = {}
	end
	local list = bags.custom
	table.insert(list, math.min(gone.index or (#list + 1), #list + 1), { key = gone.key, name = clean, colour = gone.colour, rule = gone.rule })
	local number = KeyNumber(gone.key)
	if number and (Whole(bags.customNext) or 1) <= number then
		bags.customNext = number + 1
	end
	Changed()
	lastGone = nil
	local back = 0
	for _, id in ipairs(gone.ids) do
		local placed = bags.placed
		if (type(placed) ~= "table" or placed[id] == nil) and Call(B.Categories, "Place", id, gone.key) == true then
			back = back + 1
		end
	end
	if gone.folded then
		if type(bags.folded) ~= "table" then
			bags.folded = {}
		end
		bags.folded[gone.key] = true
	end
	local order = bags.order
	if gone.order and type(order) == "table" and #order > 0 then
		table.insert(order, math.min(gone.order, #order + 1), gone.key)
	end
	Request("layout")
	Custom.Took(which or "bags", gone.key, nil, nil, FLASH.back)
	local name, count = Plain(clean), #gone.ids
	local text
	if back < count then
		text = SAY.backSome:format(name, back, count)
	elseif count == 1 then
		text = SAY.backOne:format(name)
	elseif count > 1 then
		text = SAY.backMany:format(name, count)
	else
		text = SAY.back:format(name)
	end
	return true, "Flat UI: " .. text
end

local ownKeys = nil

local function OwnKey(key)
	if not ownKeys then
		local list = B.Categories and B.Categories.LIST
		if type(list) ~= "table" then
			return false
		end
		ownKeys = {}
		for _, entry in ipairs(list) do
			local listKey = type(entry) == "table" and entry.key or nil
			if type(listKey) == "string" and listKey ~= "new" and listKey ~= "free" then
				ownKeys[listKey] = true
			end
		end
	end
	return type(key) == "string" and ownKeys[key] == true
end

local function ColourId(key)
	local entry = type(key) == "string" and Read().entries[key] or nil
	local id
	if entry then
		id = entry.colour
	elseif OwnKey(key) then
		local bags = Bags(false)
		local colours = bags and bags.colours
		id = type(colours) == "table" and colours[key] or nil
	end
	if type(id) == "string" and COLOUR_OF[id] then
		return id
	end
	return "plain"
end

function Custom.Colour(key)
	local colour = COLOUR_OF[ColourId(key)]
	if colour and colour[3] then
		return colour[3], colour[4], colour[5]
	end
	return nil
end

local function SetColour(key, id)
	if not COLOUR_OF[id] then
		return
	end
	local value = id ~= "plain" and id or nil
	local entry = type(key) == "string" and Read().entries[key] or nil
	if entry then
		if entry.colour ~= value then
			entry.colour = value
			Changed()
			Request("layout")
		end
		return
	end
	if not OwnKey(key) or ColourId(key) == id then
		return
	end
	local bags = Bags(value ~= nil)
	if not bags then
		return
	end
	if value then
		if type(bags.colours) ~= "table" then
			bags.colours = {}
		end
		bags.colours[key] = value
	elseif type(bags.colours) == "table" then
		bags.colours[key] = nil
		if next(bags.colours) == nil then
			bags.colours = nil
		end
	end
	Request("layout")
end

function Custom.Sweep()
	local bags = Bags(false)
	if not bags then
		return
	end
	local names = Read().names
	Forget(bags, function(key)
		return KeyNumber(key) ~= nil and names[key] == nil
	end)
end

local box

local function Focused()
	local ok, focus = pcall(box.edit.HasFocus, box.edit)
	return ok and not ns.IsSecret(focus) and focus == true
end

local function PaintBox()
	if not box then
		return
	end
	local r, g, b = Colour("general.backdrop", 0.05, 0.05, 0.05)
	ns.SetOutlineFill(box.outline, r, g, b, Opacity())
	ns.SetOutline(box.outline, true, true)
	local pr, pg, pb = Colour("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = Accent()
	ns.SetOutlineFill(box.field, pr, pg, pb, 1)
	if Focused() then
		ns.SetOutlineColour(box.field, ar, ag, ab)
	else
		ns.SetOutlineColour(box.field, nil, nil, nil)
	end
	for _, plate in ipairs(box.plates) do
		ns.SetOutlineFill(plate.outline, pr, pg, pb, 1)
		ns.SetOutline(plate.outline, true, true)
		plate.hover:SetColorTexture(ar, ag, ab, 0.25)
	end
end

local function Note(refusal)
	local opts = box.opts
	if refusal then
		box.note:SetText(refusal)
		box.note:SetTextColor(RED[1], RED[2], RED[3], 1)
	else
		box.note:SetText(NOTES[opts and opts.mode == "rename" and "rename" or "make"])
		box.note:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
end

local function Select()
	pcall(box.edit.SetFocus, box.edit)
	pcall(box.edit.HighlightText, box.edit)
end

function Custom.Asking(key)
	return box ~= nil and box.opts ~= nil and box.opts.key == key and box.frame:IsShown()
end

function Custom.Close()
	if box and box.frame:IsShown() then
		box.frame:Hide()
	end
end

local function Commit()
	local opts = box and box.opts
	if not opts then
		Custom.Close()
		return
	end
	if Fighting() then
		Custom.Close()
		Say(SAY.fight)
		return
	end
	local text = box.edit:GetText()
	local which = opts.which or "bags"
	if opts.mode == "rename" then
		local done, why = Custom.Rename(opts.key, text)
		if not done then
			Note(why)
			Select()
			return
		end
		Custom.Close()
		Custom.Took(which, opts.key, nil, nil, FLASH.renamed)
		return
	end
	local key, why = Custom.Make(text)
	if not key then
		Note(why)
		Select()
		return
	end
	local item = opts.item
	Custom.Close()
	if type(item) == "table" and Whole(item.id) then
		if Call(B.Categories, "File", item.id, key, item.link, item.bag, item.slot) == true then
			Call(B, "Part", "pins", Call, B.Pins, "Left", item.id, item.bag, item.slot)
			Custom.Took(which, key, item.id)
		end
	else
		Custom.Took(which, key, nil)
	end
end

local function Plate(parent, onClick)
	local button = Own(CreateFrame("Button", nil, parent))
	button:SetSize(BUTTON_W, BUTTON_H)
	button:RegisterForClicks("LeftButtonUp")
	local plate = { button = button }
	plate.outline = ns.SetOutlineArea(ns.Outline(button, button), KEY)
	plate.hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	plate.hover:SetAllPoints(button)
	plate.label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	plate.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	plate.label:SetWordWrap(false)
	button:SetScript("OnClick", function()
		Part(onClick)
	end)
	return plate
end

local function BuildBox()
	if box then
		return box
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetSize(BOX_W, BOX_H)
	frame:SetFrameStrata("DIALOG")
	pcall(frame.SetClampedToScreen, frame, true)
	frame:EnableMouse(true)
	frame:Hide()
	box = { frame = frame, plates = {} }
	box.outline = ns.SetOutlineArea(ns.Outline(frame, frame, true), KEY)
	box.title = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	box.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
	box.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
	box.title:SetJustifyH("LEFT")
	box.title:SetWordWrap(false)
	local edit = Own(CreateFrame("EditBox", nil, frame))
	edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -26)
	edit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -26)
	edit:SetHeight(FIELD_H)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetTextInsets(6, 6, 0, 0)
	pcall(edit.SetMaxLetters, edit, LONGEST)
	box.edit = edit
	box.field = ns.SetOutlineArea(ns.Outline(edit, edit, true), KEY)
	box.note = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	box.note:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -52)
	box.note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -52)
	box.note:SetJustifyH("LEFT")
	box.make = Plate(frame, Commit)
	box.make.button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
	box.cancel = Plate(frame, Custom.Close)
	box.cancel.button:SetPoint("RIGHT", box.make.button, "LEFT", -6, 0)
	box.cancel.label:SetText("Cancel")
	box.plates = { box.make, box.cancel }
	edit:SetScript("OnEnterPressed", function()
		Part(Commit)
	end)
	edit:SetScript("OnEscapePressed", function()
		Part(Custom.Close)
	end)
	edit:SetScript("OnTextChanged", function(_, typed)
		if typed and box.opts then
			Part(Note)
		end
	end)
	edit:SetScript("OnEditFocusGained", function()
		Part(PaintBox)
	end)
	edit:SetScript("OnEditFocusLost", function()
		Part(PaintBox)
	end)
	frame:SetScript("OnMouseDown", function()
		pcall(edit.SetFocus, edit)
	end)
	frame:SetScript("OnEvent", function()
		Part(Custom.Close)
	end)
	frame:SetScript("OnHide", function()
		if frame:IsShown() then
			frame:Hide()
		end
		pcall(edit.ClearFocus, edit)
		pcall(frame.UnregisterEvent, frame, "PLAYER_REGEN_DISABLED")
		box.opts = nil
	end)
	return box
end

local function PlaceBox(anchor)
	local frame = box.frame
	frame:ClearAllPoints()
	local x, y
	if type(anchor) == "table" and not ns.Forbidden(anchor) then
		local okShown, shown = pcall(anchor.IsVisible, anchor)
		local left, top = Number(anchor, "GetLeft"), Number(anchor, "GetTop")
		local scale, ui = Number(anchor, "GetEffectiveScale"), Number(UIParent, "GetEffectiveScale")
		if okShown and shown == true and left and top and scale and ui and scale > 0 and ui > 0 then
			x, y = left * scale / ui, top * scale / ui
		end
	end
	if x then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y + 4)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end

local function Suggest(id)
	local candidates = {}
	local instant = Item("GetItemInfoInstant")
	if type(instant) == "function" then
		local ok, _, itemType, itemSubType = pcall(instant, id)
		if ok then
			candidates[1], candidates[2] = itemSubType, itemType
		end
	end
	local name = Ask(Item("GetItemNameByID"), id)
	candidates[#candidates + 1] = name
	for index = 1, 3 do
		local candidate = candidates[index]
		if not ns.IsSecret(candidate) and type(candidate) == "string" and candidate ~= "" then
			local clean = Check(candidate)
			if clean and not BuiltIn(clean:lower() .. "s") then
				return clean
			end
		end
	end
	return nil
end

function Custom.Ask(opts)
	opts = type(opts) == "table" and opts or {}
	if Fighting() then
		Say(SAY.fight)
		return false
	end
	local mode = opts.mode == "rename" and "rename" or "make"
	if mode == "make" and #Read().keys >= MOST then
		Say(SAY.most)
		return false
	end
	if type(ns.Account()) ~= "table" then
		Say(SAY.saved)
		return false
	end
	local current
	if mode == "rename" then
		current = Custom.Name(opts.key)
		if not current then
			Say(SAY.gone)
			return false
		end
	end
	BuildBox()
	Custom.Close()
	local item = type(opts.item) == "table" and Whole(opts.item.id) and opts.item or nil
	box.opts = { mode = mode, key = opts.key, item = item, which = opts.which }
	if mode == "rename" then
		box.title:SetText("Rename " .. Plain(current))
		box.make.label:SetText("Rename")
	else
		box.title:SetText(item and ("New section for " .. Plain(ItemName(item.id))) or ADD_WORD)
		box.make.label:SetText("Make")
	end
	Note()
	box.edit:SetText(current or (item and Suggest(item.id)) or "")
	PlaceBox(opts.anchor)
	box.frame:Show()
	pcall(box.frame.RegisterEvent, box.frame, "PLAYER_REGEN_DISABLED")
	Select()
	PaintBox()
	if not Focused() then
		Custom.Close()
		return false
	end
	return true
end

local pools = setmetatable({}, { __mode = "k" })

local function Announce(_, text)
	if type(text) == "string" then
		print(text)
	end
end

local function DeleteText(words, count)
	if count == 1 then
		words = words .. " (1 item goes back)"
	elseif count > 1 then
		words = ("%s (%d items go back)"):format(words, count)
	end
	return DELETE_HEX .. words .. "|r"
end

local function RestoreText()
	local name, count = Custom.Gone()
	if not name then
		return nil
	end
	if count == 1 then
		return ("Bring back %s (1 item)"):format(Plain(name))
	elseif count > 1 then
		return ("Bring back %s (%d items)"):format(Plain(name), count)
	end
	return "Bring back " .. Plain(name)
end

local function Shorten(text, most)
	if #text > most then
		return (text:sub(1, most - 3):gsub("|+$", "")) .. "..."
	end
	return text
end

local function RuleLines(items, which, key)
	local rule = Custom.Rule(key)
	local typed = Call(B.Search, "Active") == true and CleanRule(Call(B.Search, "Text")) or nil
	if typed and typed ~= rule then
		items[#items + 1] = { text = "Keep what the search finds here", part = PART, pick = function()
			if SetRule(key, typed) then
				Say(("%s keeps what %s finds."):format(Plain(Custom.Name(key) or key), typed))
				Custom.Took(which, key, nil, nil, FLASH.rule)
			end
		end }
	end
	if rule then
		items[#items + 1] = { text = ("Stop keeping what \"%s\" finds"):format(Shorten(rule, RULE_SHOWN)), part = PART, pick = function()
			if SetRule(key, nil) then
				Say(("%s no longer keeps what %s finds."):format(Plain(Custom.Name(key) or key), rule))
			end
		end }
		items[#items + 1] = { text = "Search for it", part = PART, pick = function()
			Call(B.Search, "SetText", rule)
		end }
	end
end

function Custom.MenuLines(st, sec, anchor)
	local items = {}
	if type(st) ~= "table" or type(sec) ~= "table" then
		return items
	end
	local which, key = st.which, sec.key
	local mine = Custom.Is(key)
	if mine then
		items[#items + 1] = { text = "Rename", part = PART, pick = function()
			Custom.Ask({ mode = "rename", key = key, anchor = anchor, which = which })
		end }
	end
	if mine or OwnKey(key) then
		local current = ColourId(key)
		local lines, shown = {}, COLOUR_OF[current][2]
		for _, colour in ipairs(COLOURS) do
			local id = colour[1]
			local text = colour[2]
			if colour[3] then
				text = ("|cff%02x%02x%02x%s|r"):format(math.floor(colour[3] * 255 + 0.5), math.floor(colour[4] * 255 + 0.5),
					math.floor(colour[5] * 255 + 0.5), text)
			end
			if id == current then
				shown = text
			end
			lines[#lines + 1] = { text = text, tick = current == id, part = PART, pick = function()
				SetColour(key, id)
			end }
		end
		local title = ("Colour of %s"):format(Plain(sec.label or Custom.Name(key) or key))
		items[#items + 1] = { text = "Colour: " .. shown, part = PART, pick = function()
			Call(B.Layout, "Menu", anchor, title, lines, which)
		end }
	end
	if mine then
		RuleLines(items, which, key)
		items[#items + 1] = { text = DeleteText("Delete this section", Custom.Count(key)), part = PART, pick = function()
			Announce(Custom.Delete(key))
		end }
	end
	if which == "bags" and st.mine then
		items[#items + 1] = { text = ADD_WORD, part = PART, pick = function()
			Custom.Ask({ mode = "make", anchor = anchor, which = which })
		end }
	end
	return items
end

local function YourLines(st, anchor)
	local which = st.which
	local items = {}
	local restore = RestoreText()
	if restore then
		items[1] = { text = restore, part = PART, pick = function()
			Announce(Custom.Restore(which))
		end }
	end
	items[#items + 1] = { text = ADD_WORD, part = PART, pick = function()
		Custom.Ask({ mode = "make", anchor = anchor, which = which })
	end }
	local keys, names = Sorted()
	if #keys == 0 then
		items[#items + 1] = { text = "No section of your own yet", header = true }
	end
	local counts = Counts()
	for _, key in ipairs(keys) do
		local count = counts[key] or 0
		items[#items + 1] = { text = Plain(names[key]), right = count > 0 and tostring(count) or nil, header = true }
		items[#items + 1] = { text = "Rename", part = PART, pick = function()
			Custom.Ask({ mode = "rename", key = key, anchor = anchor, which = which })
		end }
		items[#items + 1] = { text = DeleteText("Delete", count), part = PART, pick = function()
			Announce(Custom.Delete(key))
		end }
	end
	return items
end

function Custom.AddClick(st, mouse, anchor)
	if type(st) ~= "table" then
		return
	end
	if mouse == "RightButton" then
		Call(B.Layout, "Menu", anchor, "Your sections", YourLines(st, anchor), st.which)
	elseif mouse == "LeftButton" then
		Custom.Ask({ mode = "make", anchor = anchor, which = st.which })
	end
end

function Custom.AddTip(st)
	if type(st) == "table" and st.holding then
		local pool = pools[st]
		local held = pool and pool.held or nil
		if held and held.merchant then
			return TIPS.addBuy, true
		elseif held and held.nowhere then
			return TIPS.nowhere, true
		elseif held and held.bagBar then
			return TIPS.bagBar, true
		elseif #Read().keys >= MOST then
			return SAY.full, true
		end
		return TIPS.addHolding
	end
	if #Read().keys >= MOST then
		return TIPS.add .. TIPS.addFull
	end
	return TIPS.add
end

local function Outside(bag, worn)
	if worn ~= nil then
		return true
	end
	if bag ~= nil then
		return not BAG_IDS[bag]
	end
	return false
end

local function Link(link)
	if type(link) == "string" and not ns.IsSecret(link) and link ~= "" then
		return link
	end
	return nil
end

local function Asks()
	local merchant = MerchantFrame
	if type(merchant) ~= "table" or ns.Forbidden(merchant) then
		return true
	end
	local ok, extended, high = pcall(function()
		return merchant.extendedCost, merchant.highPrice
	end)
	return not ok or extended ~= nil or high ~= nil
end

local function MerchantItem(index)
	index = Whole(index)
	local id = index and Whole(Ask(GetMerchantItemID, index))
	if not id or id <= 0 then
		return nil
	end
	return { id = id, link = Link(Ask(GetMerchantItemLink, index)), merchant = index, outside = true, bagBar = false }
end

local function Cursor()
	local ok, kind, id, link = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) then
		return nil
	end
	if kind == "merchant" then
		return MerchantItem(id)
	end
	if kind ~= "item" then
		return nil
	end
	id = Whole(id)
	if not id or id <= 0 then
		return nil
	end
	local held = { id = id, link = Link(link) }
	local getItem = type(C_Cursor) == "table" and C_Cursor.GetCursorItem or nil
	if type(getItem) == "function" then
		local okItem, location = pcall(getItem)
		if okItem and not ns.IsSecret(location) then
			local okSlot, bag, slot, worn = false, nil, nil, nil
			if type(location) == "table" then
				okSlot, bag, slot, worn = pcall(function()
					return location.bagID, location.slotIndex, location.equipmentSlotIndex
				end)
			end
			if okSlot then
				held.bag, held.slot, held.worn = Whole(bag), Whole(slot), Whole(worn)
			end
			held.nowhere = (location == nil or okSlot) and held.bag == nil and held.worn == nil or nil
		end
	end
	held.outside = Outside(held.bag, held.worn)
	held.bagBar = held.worn ~= nil and held.worn > LAST_WORN
	return held
end

local function HasItem()
	local ok, kind = pcall(GetCursorInfo)
	return ok and not ns.IsSecret(kind) and (kind == "item" or kind == "merchant")
end

local function CursorHeld()
	local ok, held = pcall(CursorHasItem)
	if ok and (ns.IsSecret(held) or held == true) then
		return true
	end
	local okKind, kind = pcall(GetCursorInfo)
	return okKind and (ns.IsSecret(kind) or kind ~= nil)
end

local function Clear()
	if type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
end

local function Fits(id, family)
	if not Whole(family) or family == 0 then
		return false
	end
	local instant = Item("GetItemInfoInstant")
	if type(instant) == "function" then
		local ok, _, _, _, _, _, class = pcall(instant, id)
		if not ok or ns.IsSecret(class) or class == CONTAINER or class == QUIVER then
			return false
		end
	end
	local itemFamily = Whole(Ask(Item("GetItemFamily"), id))
	return itemFamily ~= nil and type(bit) == "table" and type(bit.band) == "function" and bit.band(itemFamily, family) ~= 0
end

local function FreeFor(id)
	local numSlots, numFree, itemOf = Container("GetContainerNumSlots"), Container("GetContainerNumFreeSlots"), Container("GetContainerItemID")
	if type(numSlots) ~= "function" or type(numFree) ~= "function" or type(itemOf) ~= "function" then
		return nil
	end
	local pinned = Fn(B.Pins, "Get")
	local spareBag, spareSlot, ownBag, ownSlot
	for bag = FIRST_BAG, LAST_BAG do
		local okFree, _, family = pcall(numFree, bag)
		family = okFree and Whole(family) or nil
		local general = family == 0
		if general or (family ~= nil and bag > 0 and Fits(id, family)) then
			for slot = 1, Whole(Ask(numSlots, bag)) or 0 do
				local okItem, inSlot = pcall(itemOf, bag, slot)
				if okItem and not ns.IsSecret(inSlot) and inSlot == nil then
					local pin = nil
					if pinned then
						local okPin, pinId = pcall(pinned, bag, slot)
						pin = okPin and Whole(pinId) or nil
					end
					if pin == nil and general then
						return bag, slot
					elseif pin == nil and not spareBag then
						spareBag, spareSlot = bag, slot
					elseif pin == id and not ownBag then
						ownBag, ownSlot = bag, slot
					end
				end
			end
		end
	end
	if spareBag then
		return spareBag, spareSlot
	end
	return ownBag, ownSlot
end

local function ReadHeld()
	local held = Cursor()
	if held and held.outside and not held.bagBar then
		held.fits = FreeFor(held.id) ~= nil
	end
	if held and held.merchant then
		held.asks = Asks()
	end
	if held then
		held.takes = {}
	end
	return held
end

local function Shown(st, pool)
	if st.holding then
		return pool.held
	end
	return nil
end

local function Stopped()
	local stopped = ns.PartStopped
	if type(stopped) ~= "function" then
		return false
	end
	local ok, yes = pcall(stopped, KEY, PART)
	return ok and yes == true
end

local function Taken(sec, held)
	if Fighting() then
		return false, FIGHT_TIP
	end
	if sec.key == "keep" then
		return true
	end
	local takes = held.takes
	if type(takes) ~= "table" then
		takes = {}
		held.takes = takes
	end
	local answer = takes[sec.key]
	if answer == nil then
		local ok, yes, why = pcall(Call, B.Categories, "Takes", held.id, sec.key, held.link, held.bag, held.slot, true)
		if ok and yes == false then
			answer = { false, type(why) == "string" and why or nil }
		else
			answer = { true }
		end
		takes[sec.key] = answer
	end
	return answer[1], answer[2]
end

local function Moves(st, held)
	return held.outside and st.which == "bags" and st.mine == true and st.live == true
end

local function Accepts(st, sec, held)
	if not held or held.nowhere then
		return false
	end
	if held.outside and sec.key == "keep" then
		return false
	end
	if Moves(st, held) then
		if held.bagBar or held.asks or held.fits ~= true then
			return false
		end
	elseif held.merchant then
		return false
	end
	return (Taken(sec, held))
end

local function Room(st)
	local free = st.free
	return type(free) == "table" and ns.Finite(free.count) and free.count > 0
end

local function Recent(target)
	local dropped = target.dropped
	return dropped ~= nil and Now() - dropped < DROP_CLICK
end

local function Drop(target)
	local st, sec = target.st, target.sec
	if not (st and sec) then
		return
	end
	local held = Cursor()
	if not held then
		return
	end
	target.dropped = Now()
	if Fighting() then
		Clear()
		print(FIGHT_LINE)
		return
	end
	local name = Plain(ItemName(held.id))
	if held.nowhere then
		Clear()
		Say(SAY.nowhere:format(name))
		return
	end
	if held.merchant and (sec.key == "keep" or not Moves(st, held)) then
		Clear()
		Say(SAY.buyFirst:format(name))
		return
	end
	if Moves(st, held) and sec.key ~= "keep" then
		if held.bagBar then
			Clear()
			Say(SAY.bagBar)
			return
		end
		if held.merchant and Asks() then
			Clear()
			Say(SAY.asks:format(name))
			return
		end
		local toBag, toSlot = FreeFor(held.id)
		local pickup = Container("PickupContainerItem")
		if not toBag or type(pickup) ~= "function" then
			Clear()
			Say(SAY.noRoom:format(name))
			return
		end
		if Call(B.Categories, "Takes", held.id, sec.key, held.link, held.bag, held.slot) ~= true then
			Clear()
			return
		end
		pcall(pickup, toBag, toSlot)
		if CursorHeld() then
			Clear()
			Say(SAY.notPut:format(name))
			return
		end
		if Call(B.Categories, "File", held.id, sec.key, held.link, toBag, toSlot) == true then
			Call(B, "Part", "pins", Call, B.Pins, "Left", held.id, toBag, toSlot)
			Custom.Arriving(st.which, toBag, toSlot, held.id)
			Custom.Took(st.which, sec.key, held.id, true, held.merchant and sec.key ~= "junk" and FLASH.bought:format(name) or nil)
		end
		return
	end
	if Call(B.Layout, "Take", st, sec) == true then
		Custom.Took(st.which, sec.key, held.id)
	end
end

function Custom.DropOn(st, sec)
	if type(st) ~= "table" or type(sec) ~= "table" or not Cursor() then
		return false
	end
	Drop({ st = st, sec = sec })
	return true
end

function Custom.DropNew(st, anchor)
	if type(st) ~= "table" then
		return
	end
	if Fighting() then
		Clear()
		print(FIGHT_LINE)
		return
	end
	local held = Cursor()
	Clear()
	if not held then
		return
	end
	local name = Plain(ItemName(held.id))
	if held.merchant then
		Say(SAY.newBuy:format(name))
		return
	elseif held.nowhere then
		Say(SAY.newNowhere:format(name))
		return
	elseif held.bagBar then
		Say(SAY.bagBar)
		return
	end
	Custom.Ask({ mode = "make", item = { id = held.id, link = held.link, bag = held.bag, slot = held.slot }, anchor = anchor, which = st.which })
end

local byWhich = {}
local arrivals = {}
local waiting = nil

local function Pool(st)
	local pool = pools[st]
	if not pool then
		pool = { st = st, cells = {}, catchers = {}, cellsUsed = 0, catchersUsed = 0 }
		pools[st] = pool
	end
	return pool
end

function Custom.Accepts(st, sec)
	if type(st) ~= "table" or type(sec) ~= "table" or Stopped() then
		return nil
	end
	local pool = pools[st]
	local held = pool and Shown(st, pool) or nil
	if not held then
		return nil
	end
	if sec.add then
		return not (held.merchant or held.nowhere or held.bagBar or Fighting()) and #Read().keys < MOST
	end
	return Accepts(st, sec, held) == true
end

local function Paint(cell)
	local st, sec, pool = cell.st, cell.sec, cell.pool
	if not (st and sec) then
		return
	end
	local ar, ag, ab = Accent()
	local pr, pg, pb = Colour("windows.panel", 0.12, 0.12, 0.12)
	ns.SetOutlineFill(cell.outline, pr, pg, pb, 1)
	local held = Shown(st, pool)
	if held and Accepts(st, sec, held) then
		ns.SetOutlineColour(cell.outline, ar, ag, ab)
		for _, line in ipairs(cell.lines) do
			line:SetColorTexture(ar, ag, ab, 1)
		end
		cell.light:SetColorTexture(ar, ag, ab, cell.over and LIT_HOVER or LIT)
		cell.light:Show()
		return
	end
	ns.SetOutlineColour(cell.outline, nil, nil, nil)
	local alpha = Room(st) and PLUS_ALPHA or PLUS_DIM
	local cr, cg, cb = Custom.Colour(sec.key)
	if not cr then
		cr, cg, cb = PLUS[1], PLUS[2], PLUS[3]
	end
	for _, line in ipairs(cell.lines) do
		line:SetColorTexture(cr, cg, cb, alpha)
	end
	if cell.over and not held then
		cell.light:SetColorTexture(1, 1, 1, HOVER)
		cell.light:Show()
	else
		cell.light:Hide()
	end
end

local function HeldLine(st, sec, held, verb)
	local label = Plain(sec.label or sec.key)
	if held.nowhere then
		return TIPS.nowhere, true
	elseif held.outside and sec.key == "keep" then
		return TIPS.keepOutside, true
	elseif Moves(st, held) and held.bagBar then
		return TIPS.bagBar, true
	elseif held.merchant and not Moves(st, held) then
		return TIPS.buyFirst, true
	elseif held.merchant and held.asks then
		return TIPS.asks, true
	elseif Moves(st, held) and not held.fits then
		return TIPS.noRoom, true
	end
	local takes, why = Taken(sec, held)
	if not takes then
		return why or TIPS.refused, true
	end
	if Moves(st, held) then
		return (held.merchant and TIPS.buy or TIPS.move):format(verb, label), false
	elseif sec.key == "junk" then
		return TIPS.junk:format(verb), false
	elseif sec.key == "keep" then
		return TIPS.keep:format(verb), false
	end
	return TIPS.kept:format(verb, label), false
end

function Custom.HeldLine(st, sec)
	if type(st) ~= "table" or type(sec) ~= "table" or Stopped() then
		return nil
	end
	local pool = pools[st]
	local held = pool and Shown(st, pool) or nil
	if not held then
		return nil
	end
	return HeldLine(st, sec, held, TIPS.drop)
end

local function Tip(target)
	local tip = GameTooltip
	local st, sec = target.st, target.sec
	if not (st and sec) or type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local label = Plain(sec.label or sec.key)
	local held = Shown(st, target.pool)
	local line, refused
	if held then
		line, refused = HeldLine(st, sec, held, target.catcher and TIPS.letGo or TIPS.drop)
	elseif target.catcher then
		return
	elseif sec.key == "junk" then
		line = TIPS.idleJunk
	elseif sec.key == "keep" then
		line = TIPS.idleKeep
	else
		line = TIPS.idle:format(label) .. (Room(st) and "" or TIPS.full)
	end
	tip:SetOwner(target.frame, "ANCHOR_TOP")
	tip:SetText(label, 1, 1, 1)
	local colour = refused and RED or DIM
	tip:AddLine(line, colour[1], colour[2], colour[3], true)
	tip:Show()
end

local function Enter(target)
	local st = target.st
	if not st then
		return
	end
	target.over = true
	local pool = target.pool
	if st.holding then
		pool.held = ReadHeld()
	end
	if target.catcher then
		if st.holding and Accepts(st, target.sec, pool.held) then
			local r, g, b = Accent()
			target.light:SetColorTexture(r, g, b, LIT)
			target.light:Show()
		else
			target.light:Hide()
		end
		if st.holding then
			Tip(target)
		end
		return
	end
	Paint(target)
	Tip(target)
end

local function Leave(target)
	target.over = false
	if target.catcher then
		target.light:Hide()
	else
		Paint(target)
	end
	Untip(target.frame)
end

local function Cell(pool, index)
	local cell = pool.cells[index]
	if cell then
		return cell
	end
	local button = Own(CreateFrame("Button", nil, pool.st.content))
	button:SetSize(SLOT, SLOT)
	button:RegisterForClicks("LeftButtonUp")
	cell = { frame = button, pool = pool, lines = {} }
	cell.outline = ns.SetOutlineArea(ns.Outline(button, button), KEY)
	for _, size in ipairs({ { PLUS_LONG, PLUS_THICK }, { PLUS_THICK, PLUS_LONG } }) do
		local line = Own(button:CreateTexture(nil, "ARTWORK"))
		line:SetSize(size[1], size[2])
		line:SetPoint("CENTER", button, "CENTER", 0, 0)
		cell.lines[#cell.lines + 1] = line
	end
	cell.light = Own(button:CreateTexture(nil, "OVERLAY"))
	cell.light:SetAllPoints(button)
	cell.light:Hide()
	button:SetScript("OnReceiveDrag", function()
		Part(Drop, cell)
	end)
	button:SetScript("OnClick", function()
		if HasItem() and not Recent(cell) then
			Part(Drop, cell)
		end
	end)
	button:SetScript("OnEnter", function()
		Part(Enter, cell)
	end)
	button:SetScript("OnLeave", function()
		Part(Leave, cell)
	end)
	pool.cells[index] = cell
	return cell
end

local function Catcher(pool, index)
	local catcher = pool.catchers[index]
	if catcher then
		return catcher
	end
	local frame = Own(CreateFrame("Frame", nil, pool.st.content))
	frame:EnableMouse(false)
	catcher = { frame = frame, pool = pool, catcher = true }
	catcher.light = Own(frame:CreateTexture(nil, "BACKGROUND"))
	catcher.light:SetAllPoints(frame)
	catcher.light:Hide()
	frame:SetScript("OnReceiveDrag", function()
		Part(Drop, catcher)
	end)
	frame:SetScript("OnMouseUp", function(_, mouse)
		if mouse == "LeftButton" and HasItem() and not Recent(catcher) then
			Part(Drop, catcher)
		end
	end)
	frame:SetScript("OnEnter", function()
		Part(Enter, catcher)
	end)
	frame:SetScript("OnLeave", function()
		Part(Leave, catcher)
	end)
	pool.catchers[index] = catcher
	return catcher
end

local function Retire(target)
	target.sec, target.over = nil, false
	Untip(target.frame)
	if target.catcher then
		target.frame:EnableMouse(false)
		target.light:Hide()
	end
	target.frame:Hide()
end

local function StopFlash(pool)
	local flash = pool.flash
	if flash then
		flash.started, flash.key = nil, nil
		flash.frame:Hide()
	end
end

local function Tick(pool)
	local flash = pool.flash
	if not (flash and flash.started) then
		return
	end
	local age = Now() - flash.started
	local light = FLASH_ALPHA * (1 - age / FLASH_FADE)
	local words = age <= SAY_HOLD and 1 or (1 - (age - SAY_HOLD) / SAY_FADE)
	if light <= 0 and words <= 0 then
		StopFlash(pool)
		return
	end
	flash.fill:SetColorTexture(flash.r, flash.g, flash.b, math.max(0, light))
	flash.tag:SetAlpha(math.max(0, words))
end

local function FlashFrame(pool)
	if pool.flash then
		return pool.flash
	end
	local frame = Own(CreateFrame("Frame", nil, pool.st.content))
	frame:EnableMouse(false)
	frame:Hide()
	local flash = { frame = frame }
	flash.fill = Own(frame:CreateTexture(nil, "ARTWORK"))
	flash.fill:SetAllPoints(frame)
	local tag = Own(CreateFrame("Frame", nil, frame))
	tag:EnableMouse(false)
	flash.tag = tag
	flash.outline = ns.SetOutlineArea(ns.Outline(tag, tag, true), KEY)
	flash.say = ns.OwnText(tag, "OVERLAY", "GameFontNormalSmall")
	flash.say:SetPoint("LEFT", tag, "LEFT", SAY_PAD, 0)
	flash.say:SetPoint("RIGHT", tag, "RIGHT", -SAY_PAD, 0)
	flash.say:SetJustifyH("LEFT")
	flash.say:SetWordWrap(false)
	frame:SetScript("OnUpdate", function()
		Part(Tick, pool)
	end)
	pool.flash = flash
	return flash
end

local function TitleLeft(st, title)
	local ok, point, relative, relativePoint, x = pcall(title.frame.GetPoint, title.frame, 1)
	if not ok or ns.IsSecret(point) or ns.IsSecret(relativePoint) or not ns.Finite(x) then
		return nil
	end
	if point == "TOPLEFT" and relativePoint == "TOPLEFT" and relative == st.content then
		return x
	end
	return nil
end

local function Anchor(pool, title, ah)
	local flash, st = pool.flash, pool.st
	local frame, tag, say = flash.frame, flash.tag, flash.say
	local width = Number(title.frame, "GetWidth") or 0
	local height = Number(title.frame, "GetHeight") or 16
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", title.frame, "TOPLEFT", -2, 2)
	frame:SetSize(math.max(1, width + 4), math.max(1, height + (ah or 0) + 4))
	flash.placed = true
	if not flash.text then
		tag:Hide()
		return
	end
	local okFont, file, size, flags = pcall(title.text.GetFont, title.text)
	if okFont and type(file) == "string" and not ns.IsSecret(file) and ns.Finite(size) then
		pcall(say.SetFont, say, file, size, type(flags) == "string" and not ns.IsSecret(flags) and flags or "")
	end
	say:SetText(flash.text)
	say:SetTextColor(flash.r, flash.g, flash.b, 1)
	local textEnd = math.min(TextWidth(title.text), width) + SAY_GAP
	local tagW = math.ceil(TextWidth(say)) + 2 * SAY_PAD
	local left = TitleLeft(st, title)
	local inside = left and ns.Finite(st.width) and st.width - left or nil
	local x, y = textEnd, 0
	if inside then
		tagW = math.min(tagW, st.width)
		if textEnd + tagW > inside then
			x = math.max(-left, math.min(ah and 0 or textEnd, inside - tagW))
			y = ah and -height or 0
		end
	end
	tag:ClearAllPoints()
	tag:SetPoint("TOPLEFT", title.frame, "TOPLEFT", x, y)
	tag:SetSize(math.max(1, tagW), math.max(1, height))
	tag:Show()
end

local function StartFlash(pool, title, ah, key, text)
	local flash = FlashFrame(pool)
	flash.key, flash.text, flash.started = key, text, Now()
	flash.r, flash.g, flash.b = Accent()
	local level = (Number(pool.st.content, "GetFrameLevel") or 0) + FLASH_LEVEL
	flash.frame:SetFrameLevel(level)
	flash.tag:SetFrameLevel(level + 1)
	flash.fill:SetColorTexture(flash.r, flash.g, flash.b, FLASH_ALPHA)
	local pr, pg, pb = Colour("windows.panel", 0.12, 0.12, 0.12)
	ns.SetOutlineFill(flash.outline, pr, pg, pb, 1)
	ns.SetOutlineColour(flash.outline, flash.r, flash.g, flash.b)
	ns.SetOutline(flash.outline, true, true)
	flash.tag:SetAlpha(1)
	Anchor(pool, title, ah)
	flash.frame:Show()
end

function Custom.Took(which, key, id, moved, text)
	if type(key) ~= "string" then
		return
	end
	if not text then
		if key == "junk" then
			text = FLASH.junk
		elseif key == "keep" then
			text = FLASH.keep
		elseif not Whole(id) then
			text = FLASH.made
		else
			text = (moved and FLASH.moved or FLASH.kept):format(Plain(ItemName(id)))
		end
	end
	waiting = { which = which or "bags", key = key, at = Now(), text = text }
end

function Custom.Arriving(which, bag, slot, id)
	arrivals[#arrivals + 1] = { which = which, bag = bag, slot = slot, id = id, at = Now() }
end

local function Landed(st)
	if #arrivals == 0 or type(st) ~= "table" then
		return false
	end
	local read = Fn(B.Data, "Item")
	local now, arrived = Now(), false
	for index = #arrivals, 1, -1 do
		local arrival = arrivals[index]
		if now - arrival.at > ARRIVE_WAIT then
			table.remove(arrivals, index)
		elseif arrival.which == st.which and read then
			local okRecord, record = pcall(read, st.key, arrival.bag, arrival.slot)
			if okRecord and type(record) == "table" and Whole(record.id) == arrival.id then
				table.remove(arrivals, index)
				arrived = true
			end
		end
	end
	return arrived
end

function Custom.Begin(st)
	if type(st) ~= "table" or not st.content then
		return
	end
	local pool = Pool(st)
	pool.cellsUsed, pool.catchersUsed = 0, 0
	if pool.flash then
		pool.flash.placed = false
	end
	byWhich[st.which] = st
	local builds = Call(B.Layout, "Builds", st.which)
	if builds ~= pool.builds then
		pool.builds = builds
		Landed(st)
	end
	if st.holding then
		pool.held = pool.held or ReadHeld()
	else
		pool.held = nil
	end
	if waiting and Now() - waiting.at > FLASH_WAIT then
		waiting = nil
	end
end

function Custom.Place(st, sec, title, px, py, ax, ay, aw, ah)
	if type(st) ~= "table" or type(sec) ~= "table" or not st.content then
		return
	end
	local pool = Pool(st)
	local level = Number(st.content, "GetFrameLevel") or 0
	if ns.Finite(px) and ns.Finite(py) then
		pool.cellsUsed = pool.cellsUsed + 1
		local cell = Cell(pool, pool.cellsUsed)
		cell.st, cell.sec = st, sec
		local frame = cell.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", st.content, "TOPLEFT", px, py)
		frame:SetFrameLevel(level + CELL_LEVEL)
		Paint(cell)
		frame:Show()
	end
	if ns.Finite(ax) and ns.Finite(ay) and ns.Finite(aw) and ns.Finite(ah) and aw > 0 and ah > 0 then
		pool.catchersUsed = pool.catchersUsed + 1
		local catcher = Catcher(pool, pool.catchersUsed)
		catcher.st, catcher.sec = st, sec
		local frame = catcher.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", st.content, "TOPLEFT", ax, ay)
		frame:SetSize(aw, ah)
		frame:SetFrameLevel(level)
		frame:EnableMouse(st.holding == true)
		if not st.holding then
			catcher.light:Hide()
		end
		frame:Show()
	else
		ah = nil
	end
	if type(title) ~= "table" or type(title.frame) ~= "table" then
		return
	end
	if waiting and waiting.which == st.which and waiting.key == sec.key then
		local drop = waiting
		waiting = nil
		if Now() - drop.at <= FLASH_WAIT then
			StartFlash(pool, title, ah, sec.key, drop.text)
		end
	elseif pool.flash and pool.flash.started and pool.flash.key == sec.key then
		Anchor(pool, title, ah)
	end
end

function Custom.Done(st)
	local pool = type(st) == "table" and pools[st] or nil
	if not pool then
		return
	end
	for index = pool.cellsUsed + 1, #pool.cells do
		if pool.cells[index].frame:IsShown() then
			Retire(pool.cells[index])
		end
	end
	for index = pool.catchersUsed + 1, #pool.catchers do
		if pool.catchers[index].frame:IsShown() then
			Retire(pool.catchers[index])
		end
	end
	if pool.flash and pool.flash.started and not pool.flash.placed then
		StopFlash(pool)
	end
end

function Custom.Holding(st)
	local pool = type(st) == "table" and pools[st] or nil
	if not pool then
		return
	end
	pool.held = st.holding and ReadHeld() or nil
	for index = 1, pool.cellsUsed do
		Paint(pool.cells[index])
	end
	for index = 1, pool.catchersUsed do
		local catcher = pool.catchers[index]
		catcher.frame:EnableMouse(st.holding == true)
		if not st.holding then
			catcher.light:Hide()
			Untip(catcher.frame)
		end
	end
end

function Custom.Arrived(st, changed, held)
	return Landed(st) and not held
end

function Custom.Closed(which)
	local st = byWhich[which]
	local pool = st and pools[st]
	if pool then
		for _, cell in ipairs(pool.cells) do
			Retire(cell)
		end
		for _, catcher in ipairs(pool.catchers) do
			Retire(catcher)
		end
		pool.cellsUsed, pool.catchersUsed, pool.held = 0, 0, nil
		StopFlash(pool)
	end
	if waiting and waiting.which == which then
		waiting = nil
	end
	for index = #arrivals, 1, -1 do
		if arrivals[index].which == which then
			table.remove(arrivals, index)
		end
	end
	if box and box.opts and box.opts.which == which then
		Custom.Close()
	end
end

function ns.BagsCustomLines()
	local lines = {}
	local keys, names = Sorted()
	if #keys < MOST then
		lines[1] = { "new", "Make a new section" }
	else
		lines[1] = { "full", SAY.full }
	end
	local restore = RestoreText()
	if restore then
		lines[2] = { "restore", restore }
	end
	local counts = Counts()
	for _, key in ipairs(keys) do
		local name, count = Plain(names[key]), counts[key] or 0
		lines[#lines + 1] = { "rename:" .. key, "Rename " .. name }
		lines[#lines + 1] = { "delete:" .. key, ("Delete %s%s"):format(name, count > 0 and (" (%d placed)"):format(count) or "") }
	end
	return lines
end

function ns.BagsCustomPick(id)
	if id == "new" then
		if Fighting() then
			return false, "Flat UI: " .. SAY.fight
		end
		Custom.Ask({ mode = "make" })
		return true
	elseif id == "full" then
		return false, "Flat UI: " .. SAY.full
	elseif id == "restore" then
		return Custom.Restore(nil)
	end
	local key = type(id) == "string" and id:match("^rename:(.+)$") or nil
	if key then
		Custom.Ask({ mode = "rename", key = key })
		return true
	end
	key = type(id) == "string" and id:match("^delete:(.+)$") or nil
	if key then
		return Custom.Delete(key)
	end
	return false
end

ns.AddStatus(KEY, function()
	local keys, names = Sorted()
	if #keys == 0 then
		return {}
	end
	local shown = {}
	for index = 1, math.min(#keys, STATUS_NAMES) do
		shown[index] = Plain(names[keys[index]])
	end
	local list = table.concat(shown, ", ")
	if #keys > STATUS_NAMES then
		list = ("%s and %d more"):format(list, #keys - STATUS_NAMES)
	end
	local placed = 0
	for _, count in pairs(Counts()) do
		placed = placed + count
	end
	return { ("Bags: %d %s of your own (%s), %d %s placed in them."):format(#keys, #keys == 1 and "section" or "sections", list, placed,
		placed == 1 and "item" or "items") }
end)

ns.AddStart(KEY, function()
	Part(Custom.Sweep)
end)
