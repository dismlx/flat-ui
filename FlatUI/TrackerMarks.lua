local _, ns = ...

-- Marks on action buttons: a tracker that is low or missing puts a red border on the button that casts its spell or uses its item.
-- Trackers.lua calls ns.TrackerMarkStep after it draws a tracker and ns.TrackerMarkSweep once per pass. The borders are drawn by
-- ns.SetButtonMark in ActionBars.lua, which is only texture calls. This file makes no frame and is not a module.

local KEY = "trackers"
local RED = { 0.851, 0.251, 0.251 }
local MAX_IDS = 40

-- marked[entry.id] = { entry = entry, set = { [button] = true } }
local marked = {}

local function Plain(value, kind)
	return type(value) == kind and not ns.IsSecret(value)
end

-- The spell IDs and the item IDs that fix a tracker: what its kind lists, and the spells in entry.apply.
local function Fixes(entry)
	local spells, items = {}, {}
	local function Add(list, source)
		if type(source) ~= "table" then
			return
		end
		for index = 1, math.min(#source, MAX_IDS) do
			local id = source[index]
			if Plain(id, "number") and id > 0 then
				list[#list + 1] = id
			end
		end
	end
	if entry.kind == "item" then
		Add(items, entry.items)
	else
		Add(spells, entry.spells)
	end
	Add(spells, entry.apply)
	if entry.kind == "pet" then
		Add(spells, entry.summon)
	end
	return spells, items
end

-- The restyled buttons that hold one of the tracker's fixes, as a set.
local function Holders(entry)
	local set, spells, items = {}, Fixes(entry)
	local seen = {}
	for _, id in ipairs(spells) do
		local ok, name = false, nil
		if C_Spell and C_Spell.GetSpellName then
			ok, name = pcall(C_Spell.GetSpellName, id)
		end
		if ok and Plain(name, "string") and not seen[name] then
			seen[name] = true
			for _, button in ipairs(ns.ButtonsFor("spell", name:lower())) do
				set[button] = true
			end
		end
	end
	for _, id in ipairs(items) do
		for _, button in ipairs(ns.ButtonsFor("item", id)) do
			set[button] = true
		end
	end
	return set
end

local function Count(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end

-- Marks the buttons of the set and takes the mark from the ones that held it before.
local function Apply(record, set)
	for button in pairs(record.set) do
		if not set[button] then
			ns.SetButtonMark(button, "missing", nil)
		end
	end
	for button in pairs(set) do
		ns.SetButtonMark(button, "missing", RED[1], RED[2], RED[3])
	end
	record.set = set
end

local function Clear(id)
	local record = marked[id]
	if record then
		marked[id] = nil
		Apply(record, {})
	end
end

-- Only a state the addon read itself, drawn live, marks a button: never the game's own icon, the last known state or an unknown one.
local function Wants(entry, reading, how)
	if not (ns.Enabled(KEY) and entry.on ~= false and ns.TrackerValue(entry, "mark") == true and how == "live") then
		return false
	end
	local state = reading and reading.state
	return Plain(state, "string") and (state == "low" or state == "missing")
end

function ns.TrackerMarkStep(entry, reading, how)
	if type(ns.SetButtonMark) ~= "function" then
		return
	end
	if not Wants(entry, reading, how) then
		Clear(entry.id)
		return
	end
	local record = marked[entry.id]
	if not record then
		record = { set = {} }
		marked[entry.id] = record
	end
	record.entry = entry
	Apply(record, Holders(entry))
end

-- Takes the marks of every tracker that is not in the list, which is the trackers that are on, or of all when there is none.
function ns.TrackerMarkSweep(entries)
	local on = {}
	for _, entry in ipairs(ns.Enabled(KEY) and entries or {}) do
		on[entry.id] = true
	end
	for id in pairs(marked) do
		if not on[id] then
			Clear(id)
		end
	end
end

-- A line for /flatui tracker check.
function ns.TrackerMarkLine(entry)
	if ns.TrackerValue(entry, "mark") ~= true then
		return "Marks: off."
	end
	if not ns.Enabled("actionbars") then
		return "Marks: Restyle action bars is off."
	end
	local record = marked[entry.id]
	local set = record and record.set
	if not set then
		set = {}
		for button in pairs(Holders(entry)) do
			if ns.ButtonIsOn(button) then
				set[button] = true
			end
		end
	end
	local n = Count(set)
	if n == 0 then
		return "Marks: no button holds it."
	end
	return ("Marks: %d %s."):format(n, n == 1 and "button" or "buttons")
end

-- The buttons hold something else: the buttons of every marked tracker are found again.
if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		for _, record in pairs(marked) do
			Apply(record, Holders(record.entry))
		end
	end)
end

-- The row on a tracker's page of its own.
if type(ns.TrackerEditorRow) == "function" then
	ns.TrackerEditorRow("mark", "bool")
end
