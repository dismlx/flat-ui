local _, ns = ...

local KEY = "barblock"
local COUNT = 3
local IDS = { "main", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8" }
local OLD = { "main", "bar2", "bar3", "none", "none", "none" }
local SHOW = "PROXY_SHOW_ACTIONBAR_%d"

local cache = { texts = {} }
local turn = { queued = false, waiting = false, loaded = false, done = {} }

local function Bars()
	return type(ns.BarFrames) == "table" and ns.BarFrames or {}
end

local function Label(id)
	local bar = Bars()[id]
	return bar and bar.label or tostring(id)
end

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

function ns.BarBlockPlace(id, n, anchor, after)
	if not Bars()[id] or type(n) ~= "number" or n < 1 or n > COUNT or anchor == id then
		return false, nil
	end
	local was, lists = ns.BarBlockLists(), Copy()
	local texts = {}
	for m = 1, COUNT do
		texts[m] = table.concat(was[m], ",")
		for index = #lists[m], 1, -1 do
			if lists[m][index] == id then
				table.remove(lists[m], index)
			end
		end
	end
	local list = lists[n]
	local at = #list + 1
	for index, each in ipairs(list) do
		if each == anchor then
			at = after and index + 1 or index
		end
	end
	table.insert(list, at, id)
	local changed = false
	for m = 1, COUNT do
		if table.concat(lists[m], ",") ~= texts[m] then
			changed = true
		end
	end
	if not changed then
		return false, nil
	end
	for m = 1, COUNT do
		if table.concat(lists[m], ",") ~= texts[m] then
			Write(m, lists[m])
		end
	end
	return true, ("Flat UI: %s is bar %d of block %d."):format(Label(id), at, n)
end

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

ns.ClickPathReporter(function()
	if #turn.done > 0 then
		return "Click path: Flat UI turned on " .. table.concat(turn.done, ", ") .. " in the game's options."
	end
	return nil
end)
