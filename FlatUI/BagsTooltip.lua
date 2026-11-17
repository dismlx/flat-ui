local _, ns = ...

-- Bags: counts in tooltips (design 1.3 and 3.5; the row Counts in tooltips). An item's tooltip names the player's other characters on this realm and
-- its connected realms who carry it, in their bags, their bank or their worn gear, as Flat UI last saw them. The line for this character stays the
-- job of Chat and tooltips' Item count in bags and bank (Chat.lua:765-799); items on other realms cannot reach this character and are left out.
--
-- The lines are added inside the game's build of an item tooltip, by one post call for the item kind of tooltip data that Tips.Start adds once with
-- TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...) (Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:181-201;
-- enums.yaml:7781). The game runs it after the lines of the item (:292-298) and shows the tooltip after it (:300), so the tooltip takes the size
-- of the new lines, and it runs an addon's post call outside its own security (:181-193, 62-71). A post call cannot be taken back, so it does
-- nothing while Bags is off, stopped or standing down (B.On), while the row is off, and for any tooltip but GameTooltip and ItemRefTooltip
-- (Blizzard_GameTooltip/Mainline/GameTooltip.xml:249; Blizzard_UIPanels_Game/Mainline/ItemRef.xml:5), each compared with rawequal. The item is the
-- ID of the tooltip's data (data.id), used only while it is a plain number.
-- The counts come from Flat UI's own records (B.Data.Counts of BagsData.lua: the bags, bank and worn items of each character as Flat UI last saw
-- them, for the characters of this realm and its connected realms), never from the game, so the lines are the same in a fight. The tooltip only
-- gets lines (AddDoubleLine) and is asked how many it has (NumLines), both widget calls. The lines are added once for each build of a tooltip, as
-- Chat and tooltips adds its own (Chat.lua:787-798): the game fetches new data for each build and may run the post calls more than once for one,
-- so the same data with the lines of the first call still there is the same build.
-- One line for each character, the most first: the name in the colour of its class (RAID_CLASS_COLORS, Blizzard_SharedXML/ClassColors.lua:1),
-- without the realm when it is this character's, and where the items are. At most MOST characters have a line of their own and the rest share
-- one; a total ends the lines when two or more characters carry the item.
-- What another file of Bags uses: Tips.Forget (BagsData's Forget, after a character is forgotten). Tips.Start, which adds the post call, runs only
-- from this file's ns.AddStart line, after the Start of Bags. This file owns no event (design 2.8).

local B = ns.Bags
if type(B) ~= "table" or type(B.Tips) ~= "table" then
	return
end
local Tips = B.Tips

local KEY = "bags"
local PART = "tooltips"
-- Enum.TooltipDataType.Item, for a client whose enumeration does not say (enums.yaml:7781).
local ITEM = 0
-- Characters with a line of their own; the rest share one line.
local MOST = 8
-- The colour of the counts, as Chat and tooltips writes its own extra lines (Chat.lua:793), and of a name whose class is not known.
local DIM = { 0.8, 0.8, 0.8 }
local PLAIN = { 1, 1, 1 }

-- Per tooltip: { data, lines } of the build that has the lines.
local built = setmetatable({}, { __mode = "k" })
-- Per character key: { text, r, g, b }, the name as a line shows it.
local names = {}
-- The post call is added; the game refused it.
local started, broken = false, false

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- True while Bags is on, not stopped and not standing down (B.On, Bags.lua).
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

-- Runs fn as the tooltips part of Bags (B.Part, Bags.lua): a failure stops this part alone.
local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return part(PART, fn, ...)
end

-- GameTooltip or ItemRefTooltip, while addons may touch it.
local function Ours(tooltip)
	if tooltip == nil or ns.IsSecret(tooltip) then
		return false
	end
	return (rawequal(tooltip, GameTooltip) or rawequal(tooltip, ItemRefTooltip)) and not ns.Forbidden(tooltip)
end

-- A field of an entry of B.Data.Counts ({ key, class, bags, bank, worn }), by its name, else by its place in that list.
local function Of(entry, name, place)
	local value = entry[name]
	if value == nil then
		value = entry[place]
	end
	return value
end

-- A count of the records as a whole number, or 0.
local function Whole(value)
	if ns.Finite(value) and value > 0 then
		return math.floor(value)
	end
	return 0
end

-- The realm of a key "Name - Realm" (ns.CharacterKey, Core.lua:2704-2707), or nil.
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

-- How a line names a character: without the realm when it is this character's, in the colour of its class. Kept for the session, until Tips.Forget.
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

-- Where a character's items are: "3 in bags", or "5: 3 in bags, 2 in the bank" when they are in more than one place.
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

-- The lines for an item: { left, right, r, g, b } each, or nil when no other character carries it or the records do not say yet.
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
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a, b)
		if a.total ~= b.total then
			return a.total > b.total
		end
		return a.key < b.key
	end)
	local lines, sum, rest, others = {}, 0, 0, 0
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
	if #list > 1 then
		lines[#lines + 1] = { "On your other characters", ("%d"):format(sum), PLAIN[1], PLAIN[2], PLAIN[3] }
	end
	return lines
end

-- The lines of the counts at the end of a tooltip, once for each build of it.
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

-- The post call, run by the game for every item tooltip it builds.
local function Filled(tooltip, data)
	if Ours(tooltip) and Usable(data) and On() and Wanted() then
		Run(Add, tooltip, data)
	end
end

-- Adds the post call, once for the session; true once it is added. Its one caller is the ns.AddStart line below, which runs it after the Start of
-- Bags and BagsData's step there (Core.lua:2188-2199). An add the game refuses is not tried again (broken), and /flatui status says so.
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

-- Forgets the names kept for the lines and which builds have them: after a character is forgotten (B.Data.Forget), the next build of a tooltip
-- takes its lines afresh.
function Tips.Forget()
	names = {}
	built = setmetatable({}, { __mode = "k" })
end

-- After the Start of Bags (ns.AddStart, Core.lua), which is also what turning the page on runs the first time.
ns.AddStart(KEY, function()
	Run(Tips.Start)
end)

ns.AddStatus(KEY, function()
	if broken then
		return { "Bags: the game took no post call for item tooltips, so Counts in tooltips shows nothing." }
	end
	return {}
end)
