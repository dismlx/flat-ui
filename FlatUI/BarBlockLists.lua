local _, ns = ...

-- The bars of the bar blocks (BarBlock.lua): up to three blocks, each a list of bars in order, first bar first, saved in the profile as text
-- (barblock.bars1 to bars3: the ids main and bar2 to bar8 joined by commas). A bar is in one block only: a bar a list names again, in the same
-- block or in a later one, is left out. Block 1 holds the main bar and action bars 2 to 4 by default; blocks 2 and 3 hold none and are off until
-- they are given a bar. The rows of the Bar block page move a bar up or down in its block, take it out, or add a bar, which leaves the block it
-- was in. Before 0.5.27 the page had six fixed rows (barblock.slot1 to slot6); a profile that saved one of them has their bars moved into
-- block 1 once, as the settings load (Core.lua).
-- At login and when the bars of a block change, out of combat, each of bars 2 to 8 a block holds that the game's options have off is turned on
-- with the game's own setting for that bar (Settings.SetValue of PROXY_SHOW_ACTIONBAR_2 to 8, Blizzard_SettingsDefinitions_Frame/ActionBars.lua:
-- 29-35; the game's own code does the same for bar 2, ActionBarController.lua:98-107), once the game has made its settings (the setting is
-- there, or SETTINGS_LOADED came), so the toggles it reads are the ones the server sent. A client without those settings gets SetActionBarToggles with the other bars as
-- GetActionBarToggles gives them. A bar no block holds is left alone, and nothing is turned off. Nothing is turned on while the game forces the
-- bars (C_GameRules.IsMultiActionBarVisibilityForced).

local KEY = "barblock"
local COUNT = 3
local IDS = { "main", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8" }
-- The six rows of before 0.5.27 and the bars they held while no choice was saved.
local OLD = { "main", "bar2", "bar3", "none", "none", "none" }
-- The variable of the game's setting that shows the bar with this place in GetActionBarToggles, plus one (bars 2 to 8).
local SHOW = "PROXY_SHOW_ACTIONBAR_%d"

-- texts: the saved text of each block when the lists were last made. lists: those lists. turn: queued, the turn-on waits for the end of a fight;
-- waiting, it waits for the game's settings; loaded, the game has made them; sig, the bars it last looked at; done, the bars it turned on.
local cache = { texts = {} }
local turn = { queued = false, waiting = false, loaded = false, done = {} }

local function Bars()
	return type(ns.BarFrames) == "table" and ns.BarFrames or {}
end

local function Label(id)
	local bar = Bars()[id]
	return bar and bar.label or tostring(id)
end

-- The bars of a text, in order, with the ones in `seen` left out and added to it.
local function Parse(text, seen)
	local list, bars = {}, Bars()
	if type(text) ~= "string" then
		return list
	end
	for id in text:gmatch("[^,%s]+") do
		if bars[id] and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	return list
end

-- The bars of each block, block 1 first, as the profile in use (or the view of setup) says. The tables are shared: copy before a change.
function ns.BarBlockLists()
	local texts, same = cache.texts, cache.lists ~= nil
	for n = 1, COUNT do
		local text = ns.Get(KEY .. ".bars" .. n)
		if text ~= texts[n] then
			texts[n], same = text, false
		end
	end
	if same then
		return cache.lists
	end
	local lists, seen = {}, {}
	for n = 1, COUNT do
		lists[n] = Parse(texts[n], seen)
	end
	cache.lists = lists
	return lists
end

-- The block (1 to 3) that holds the bar of this frame name, nil for none or while the Bar block page is off.
function ns.BarBlockHolds(name)
	if type(name) ~= "string" or not ns.Enabled(KEY) then
		return nil
	end
	local bars = Bars()
	for n, list in ipairs(ns.BarBlockLists()) do
		for _, id in ipairs(list) do
			if bars[id].frame == name then
				return n
			end
		end
	end
	return nil
end

local function Copy()
	local copy = {}
	for n, list in ipairs(ns.BarBlockLists()) do
		copy[n] = {}
		for index, id in ipairs(list) do
			copy[n][index] = id
		end
	end
	return copy
end

local function Write(n, list)
	ns.Set(KEY .. ".bars" .. n, table.concat(list, ","))
end

-- The lines of a block's Bars row: each bar, numbered from the first, with move up, move down and remove.
local function Lines(n)
	local list, lines = ns.BarBlockLists()[n], {}
	for index, id in ipairs(list) do
		local name = ("%d. %s"):format(index, Label(id))
		if index > 1 then
			lines[#lines + 1] = { "up:" .. id, name .. ": move up" }
		end
		if index < #list then
			lines[#lines + 1] = { "down:" .. id, name .. ": move down" }
		end
		lines[#lines + 1] = { "remove:" .. id, name .. ": remove" }
	end
	if #lines == 0 then
		lines[1] = { "none", n == 1 and "No bars. Add one below." or "No bars, so the block is off. Add one below." }
	end
	return lines
end

local function Pick(n, id)
	local verb, bar = tostring(id):match("^(%a+):(%w+)$")
	local lists = Copy()
	local list, at = lists[n], nil
	for index, each in ipairs(list) do
		if each == bar then
			at = index
		end
	end
	if not at then
		return false, nil
	end
	local text
	if verb == "up" and at > 1 then
		list[at], list[at - 1] = list[at - 1], list[at]
		text = "moved up in"
	elseif verb == "down" and at < #list then
		list[at], list[at + 1] = list[at + 1], list[at]
		text = "moved down in"
	elseif verb == "remove" then
		table.remove(list, at)
		text = "taken out of"
	else
		return false, nil
	end
	Write(n, list)
	return true, ("Flat UI: %s %s block %d."):format(Label(bar), text, n)
end

-- The lines of a block's Add a bar row: every bar not in it, with the block a bar would leave.
local function Free(n)
	local where, lines = {}, {}
	for m, list in ipairs(ns.BarBlockLists()) do
		for _, id in ipairs(list) do
			where[id] = m
		end
	end
	for _, id in ipairs(IDS) do
		local m = where[id]
		if Bars()[id] and m ~= n then
			lines[#lines + 1] = { id, m and ("%s (leaves block %d)"):format(Label(id), m) or Label(id) }
		end
	end
	if #lines == 0 then
		lines[1] = { "none", "Every bar is in this block." }
	end
	return lines
end

local function Add(n, id)
	if not Bars()[id] then
		return false, nil
	end
	local lists = Copy()
	for m = 1, COUNT do
		for index = #lists[m], 1, -1 do
			if lists[m][index] == id then
				if m == n then
					return false, ("Flat UI: %s is in block %d already."):format(Label(id), n)
				end
				table.remove(lists[m], index)
				Write(m, lists[m])
			end
		end
	end
	local list = lists[n]
	list[#list + 1] = id
	Write(n, list)
	return true, ("Flat UI: %s added to block %d."):format(Label(id), n)
end

-- The rows of the page name these: BarBlockLines1, BarBlockPick1, BarBlockFree1, BarBlockAdd1, and the same for blocks 2 and 3.
for n = 1, COUNT do
	ns["BarBlockLines" .. n] = function()
		return Lines(n)
	end
	ns["BarBlockPick" .. n] = function(id)
		return Pick(n, id)
	end
	ns["BarBlockFree" .. n] = function()
		return Free(n)
	end
	ns["BarBlockAdd" .. n] = function(id)
		return Add(n, id)
	end
end

-- The saved options of a profile as they load: the six rows of before 0.5.27 become the list of block 1, once (the old rows are then dropped
-- as no setting of this build). A profile that saved none of them, or already has a list, is left as it is.
function ns.MigrateBarBlock(options)
	if type(options) ~= "table" or options[KEY .. ".bars1"] ~= nil then
		return
	end
	local any = false
	for index = 1, #OLD do
		any = any or options[KEY .. ".slot" .. index] ~= nil
	end
	if not any then
		return
	end
	local list, seen, bars = {}, {}, Bars()
	for index = 1, #OLD do
		local id = options[KEY .. ".slot" .. index]
		if id == nil then
			id = OLD[index]
		end
		if type(id) == "string" and bars[id] and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	options[KEY .. ".bars1"] = table.concat(list, ",")
end

-- Shown (true), hidden (false) or unknown (nil) in the game's options, for a bar's place in GetActionBarToggles.
local function Shown(toggle)
	if type(GetActionBarToggles) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return select(toggle, GetActionBarToggles())
	end)
	if ok and not ns.IsSecret(value) and type(value) == "boolean" then
		return value
	end
	return nil
end

local function Forced()
	local rules = C_GameRules
	if type(rules) ~= "table" or type(rules.IsMultiActionBarVisibilityForced) ~= "function" then
		return false
	end
	local ok, forced = pcall(rules.IsMultiActionBarVisibilityForced)
	return not ok or ns.IsSecret(forced) or forced == true
end

local function Registered(variable)
	if not (type(Settings) == "table" and type(Settings.GetSetting) == "function" and type(Settings.SetValue) == "function") then
		return false
	end
	local ok, setting = pcall(Settings.GetSetting, variable)
	return ok and setting ~= nil
end

local function TurnOn()
	turn.queued = false
	if not ns.Enabled(KEY) or Forced() then
		return
	end
	-- The game's own test of whether its settings are made is whether the setting is there (ActionBarController.lua:103).
	turn.loaded = turn.loaded or Registered(SHOW:format(2))
	if not turn.loaded then
		turn.waiting = true
		return
	end
	local bars, off = Bars(), {}
	for _, list in ipairs(ns.BarBlockLists()) do
		for _, id in ipairs(list) do
			local bar = bars[id]
			if bar.toggle and Shown(bar.toggle) == false then
				off[#off + 1] = bar
			end
		end
	end
	if #off == 0 then
		return
	end
	local names = {}
	if Registered(SHOW:format(off[1].toggle + 1)) then
		for _, bar in ipairs(off) do
			if pcall(Settings.SetValue, SHOW:format(bar.toggle + 1), true) then
				names[#names + 1] = bar.label
			end
		end
	elseif type(SetActionBarToggles) == "function" then
		local values = {}
		for toggle = 1, 7 do
			values[toggle] = Shown(toggle) == true
		end
		for _, bar in ipairs(off) do
			values[bar.toggle] = true
			names[#names + 1] = bar.label
		end
		if not pcall(SetActionBarToggles, unpack(values, 1, 7)) then
			names = {}
		end
	end
	if #names > 0 then
		for _, name in ipairs(names) do
			turn.done[#turn.done + 1] = name
		end
		print(("Flat UI: turned on %s in the game's options for the bar blocks."):format(table.concat(names, ", ")))
	end
end

local function Queue()
	if turn.queued then
		return
	end
	turn.queued = true
	ns.OutOfCombat(function()
		ns.Try(KEY, TurnOn)
	end)
end

-- Called as the Bar block page starts or changes (BarBlock.lua): the bars are looked at once a session and again when the bars of a block change.
function ns.BarBlockTurnOn()
	local parts = {}
	if ns.Enabled(KEY) then
		for n, list in ipairs(ns.BarBlockLists()) do
			parts[n] = table.concat(list, ",")
		end
	end
	local sig = table.concat(parts, ";")
	if sig == turn.sig then
		return
	end
	turn.sig = sig
	if sig ~= "" then
		Queue()
	end
end

local events = CreateFrame("Frame")
ns.Own[events] = true
pcall(events.RegisterEvent, events, "SETTINGS_LOADED")
events:SetScript("OnEvent", function()
	turn.loaded = true
	if turn.waiting then
		turn.waiting = false
		Queue()
	end
end)

-- /flatui status names a bar this file turned on in the game's options in this session: the game's setting was written by Flat UI's code.
ns.ClickPathReporter(function()
	if #turn.done > 0 then
		return "Click path: Flat UI turned on " .. table.concat(turn.done, ", ") .. " in the game's options."
	end
	return nil
end)
