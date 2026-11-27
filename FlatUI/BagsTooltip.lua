local _, ns = ...

local B = ns.Bags
if type(B) ~= "table" or type(B.Tips) ~= "table" then
	return
end
local Tips = B.Tips

local KEY = "bags"
local PART = "tooltips"
local ITEM = 0
local MOST = 8
local DIM = { 0.8, 0.8, 0.8 }
local PLAIN = { 1, 1, 1 }
local WHY = { 0.66, 0.68, 0.62 }
local PLACED_LINE = "Placed by hand in %s"
local PINNED_LINE = "Pinned to this slot. Ctrl+right-click unpins it."

local built = setmetatable({}, { __mode = "k" })
local marked = setmetatable({}, { __mode = "k" })
local names = {}
local started, broken = false, false

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function On()
	local on = B.On
	if type(on) ~= "function" then
		return false
	end
	local ok, yes = pcall(on)
	return ok and yes == true
end

local function Wanted()
	local opt = B.Opt
	return type(opt) == "function" and opt("altCounts") == true
end

local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return part(PART, fn, ...)
end

local function Ours(tooltip)
	if tooltip == nil or ns.IsSecret(tooltip) then
		return false
	end
	return (rawequal(tooltip, GameTooltip) or rawequal(tooltip, ItemRefTooltip)) and not ns.Forbidden(tooltip)
end

local function Of(entry, name, place)
	local value = entry[name]
	if value == nil then
		value = entry[place]
	end
	return value
end

local function Whole(value)
	if ns.Finite(value) and value > 0 then
		return math.floor(value)
	end
	return 0
end

local function Realm(key)
	if type(key) ~= "string" then
		return nil
	end
	local cut = key:find(" - ", 1, true)
	return cut and key:sub(cut + 3) or nil
end

local function ClassColour(class)
	if type(class) ~= "string" or ns.IsSecret(class) then
		return nil
	end
	local colours = RAID_CLASS_COLORS
	local colour = Usable(colours) and colours[class] or nil
	if not Usable(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

local function Name(key, class, realm)
	local known = names[key]
	if known then
		return known
	end
	local text = key
	local cut = key:find(" - ", 1, true)
	if cut and realm and key:sub(cut + 3) == realm then
		text = key:sub(1, cut - 1)
	end
	local r, g, b = ClassColour(class)
	known = { text = text, r = r or PLAIN[1], g = g or PLAIN[2], b = b or PLAIN[3] }
	names[key] = known
	return known
end

local function Where(bags, bank, worn)
	local parts = {}
	if bags > 0 then
		parts[#parts + 1] = ("%d in bags"):format(bags)
	end
	if bank > 0 then
		parts[#parts + 1] = ("%d in the bank"):format(bank)
	end
	if worn > 0 then
		parts[#parts + 1] = ("%d worn"):format(worn)
	end
	local text = table.concat(parts, ", ")
	if #parts > 1 then
		text = ("%d: %s"):format(bags + bank + worn, text)
	end
	return text
end

local function Lines(id)
	local counts = B.Data.Counts(id)
	if type(counts) ~= "table" then
		return nil
	end
	local me = B.Me()
	local realm = Realm(me)
	local list = {}
	for _, entry in ipairs(counts) do
		if Usable(entry) then
			local key = Of(entry, "key", 1)
			if type(key) == "string" and key ~= me then
				local bags, bank, worn = Whole(Of(entry, "bags", 3)), Whole(Of(entry, "bank", 4)), Whole(Of(entry, "worn", 5))
				local total = bags + bank + worn
				if total > 0 then
					list[#list + 1] = { key = key, class = Of(entry, "class", 2), bags = bags, bank = bank, worn = worn, total = total }
				end
			end
		end
	end
	local own = nil
	local mine = B.Data.Mine
	if type(me) == "string" and type(mine) == "function" then
		local ok, bags, bank, worn = pcall(mine, id)
		bags, bank, worn = ok and Whole(bags) or 0, ok and Whole(bank) or 0, ok and Whole(worn) or 0
		if bank > 0 or worn > 0 then
			own = { bags = bags, bank = bank, worn = worn, total = bags + bank + worn }
		end
	end
	if #list == 0 and not own then
		return nil
	end
	table.sort(list, function(a, b)
		if a.total ~= b.total then
			return a.total > b.total
		end
		return a.key < b.key
	end)
	local lines, sum, rest, others = {}, 0, 0, 0
	if own then
		local okClass, class = pcall(UnitClassBase, "player")
		local name = Name(me, okClass and class or nil, realm)
		lines[1] = { name.text, Where(own.bags, own.bank, own.worn), name.r, name.g, name.b }
	end
	for index, entry in ipairs(list) do
		sum = sum + entry.total
		if index <= MOST then
			local name = Name(entry.key, entry.class, realm)
			lines[#lines + 1] = { name.text, Where(entry.bags, entry.bank, entry.worn), name.r, name.g, name.b }
		else
			rest, others = rest + entry.total, others + 1
		end
	end
	if others > 0 then
		lines[#lines + 1] = { ("and %d more"):format(others), ("%d"):format(rest), DIM[1], DIM[2], DIM[3] }
	end
	if own and #list > 0 then
		lines[#lines + 1] = { "In all", ("%d"):format(sum + own.total), PLAIN[1], PLAIN[2], PLAIN[3] }
	elseif #list > 1 then
		lines[#lines + 1] = { "On your other characters", ("%d"):format(sum), PLAIN[1], PLAIN[2], PLAIN[3] }
	end
	return lines
end

local function Add(tooltip, data)
	local id = data.id
	if not ns.Finite(id) then
		return
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not ns.Finite(shown) then
		return
	end
	local record = built[tooltip]
	if record and record.data == data and shown >= record.lines then
		return
	end
	local lines = Lines(id)
	if not lines then
		return
	end
	for _, line in ipairs(lines) do
		if not pcall(tooltip.AddDoubleLine, tooltip, line[1], line[2], line[3], line[4], line[5], DIM[1], DIM[2], DIM[3]) then
			return
		end
		shown = shown + 1
	end
	built[tooltip] = { data = data, lines = shown }
end

local function Why(owner, id)
	local layout, categories = B.Layout, B.Categories
	local entryOf = Usable(layout) and layout.EntryOf or nil
	if type(entryOf) ~= "function" then
		return nil
	end
	for _, which in ipairs({ "bags", "bank" }) do
		local bag, slot, record, live = entryOf(which, owner)
		if record then
			if record.id ~= id then
				return nil
			end
			local lines = {}
			local placedKey = Usable(categories) and type(categories.PlacedKey) == "function" and categories.PlacedKey(record) or nil
			if type(placedKey) == "string" and type(categories.Of) == "function" and categories.Of(record) == placedKey then
				lines[#lines + 1] = PLACED_LINE:format((tostring(categories.Label(placedKey)):gsub("|", "||")))
			end
			local pins = B.Pins
			if live and Usable(pins) and type(pins.Get) == "function" and pins.Get(bag, slot) == id then
				lines[#lines + 1] = PINNED_LINE
			end
			return #lines > 0 and lines or nil
		end
	end
	return nil
end

local function Placement(tooltip, data)
	local id = data.id
	if not ns.Finite(id) then
		return
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not ns.Finite(shown) then
		return
	end
	local record = marked[tooltip]
	if record and record.data == data and shown >= record.lines then
		return
	end
	local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
	if not okOwner or owner == nil or ns.IsSecret(owner) or type(owner) ~= "table" then
		return
	end
	local lines = Why(owner, id)
	if not lines then
		return
	end
	for _, line in ipairs(lines) do
		if not pcall(tooltip.AddLine, tooltip, line, WHY[1], WHY[2], WHY[3], true) then
			return
		end
		shown = shown + 1
	end
	marked[tooltip] = { data = data, lines = shown }
end

local function Filled(tooltip, data)
	if Ours(tooltip) and Usable(data) and On() then
		Run(Placement, tooltip, data)
		if Wanted() then
			Run(Add, tooltip, data)
		end
	end
end

function Tips.Start()
	if started then
		return not broken
	end
	local processor = TooltipDataProcessor
	if not Usable(processor) or type(processor.AddTooltipPostCall) ~= "function" then
		return false
	end
	local kinds = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.TooltipDataType or nil
	local item = Usable(kinds) and kinds.Item or nil
	if not ns.Finite(item) then
		item = ITEM
	end
	started = true
	broken = not pcall(processor.AddTooltipPostCall, item, Filled)
	return not broken
end

function Tips.Forget()
	names = {}
	built = setmetatable({}, { __mode = "k" })
	marked = setmetatable({}, { __mode = "k" })
end

ns.AddStart(KEY, function()
	Run(Tips.Start)
end)

ns.AddStatus(KEY, function()
	if broken then
		return { "Bags: the game took no post call for item tooltips, so Counts in tooltips shows nothing." }
	end
	return {}
end)
