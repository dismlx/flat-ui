local _, ns = ...

local KEY = "barblock"
local WRITER = "buttons"
local SETTING = { Orientation = 0, NumRows = 1, NumIcons = 2, IconSize = 3, IconPadding = 4, AlwaysShowButtons = 9 }
local LINES = {
	refused = "Button size and spacing: Edit Mode did not take it.",
	scale = "Button size and spacing: Edit Mode did not keep them.",
	missing = "Button size and spacing: not available in this build.",
}
local TOLERANCE = 0.01

local state = { off = false, checked = false, waiting = false, wrote = false }

local function Opt(name)
	return ns.Get(KEY .. "." .. name)
end

local function On()
	return ns.Enabled(KEY) and Opt("uniform") == true
end

local function Setting(name)
	local enum = Enum and Enum.EditModeActionBarSetting
	local value = type(enum) == "table" and enum[name]
	if type(value) == "number" then
		return value
	end
	return SETTING[name]
end

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function PerRow()
	local n = tonumber(Opt("perRow"))
	if n == 6 or n == 4 or n == 3 then
		return n
	end
	return 12
end

local function Size()
	return Clamp(math.floor((tonumber(Opt("size")) or 100) / 10 + 0.5) * 10, 50, 200)
end

local function Wanted()
	local size = Size()
	return {
		Orientation = 0,
		NumRows = Clamp(12 / PerRow(), 1, 4),
		NumIcons = Clamp(12, 6, 12),
		IconSize = (size - 50) / 10,
		IconPadding = Clamp(math.floor((tonumber(Opt("spacing")) or 2) + 0.5), 2, 10),
		AlwaysShowButtons = Opt("showEmpty") == false and 0 or 1,
	}
end

local ORDER = { "Orientation", "NumRows", "NumIcons", "IconSize", "IconPadding", "AlwaysShowButtons" }

local function BlockFrames()
	local names = {}
	local bars = ns.BarFrames
	if type(bars) ~= "table" or not ns.BarBlockLists then
		return names
	end
	for _, list in ipairs(ns.BarBlockLists()) do
		for _, id in ipairs(list) do
			local info = bars[id]
			local name = type(info) == "table" and info.frame
			if type(name) == "string" then
				names[#names + 1] = name
			end
		end
	end
	return names
end

local function Rows(layout)
	local rows = {}
	local LS = ns.LayoutSpots
	if type(LS) ~= "table" or type(LS.Entry) ~= "function" then
		return rows
	end
	for _, name in ipairs(BlockFrames()) do
		local frame = _G[name]
		local row = frame ~= nil and LS.Entry(layout, frame) or nil
		if type(row) == "table" then
			rows[#rows + 1] = { name, row }
		end
	end
	return rows
end

local function Find(row, setting)
	if type(row.settings) ~= "table" then
		return nil
	end
	for _, item in ipairs(row.settings) do
		if type(item) == "table" and item.setting == setting then
			return item
		end
	end
	return nil
end

local function WantedFor(layout)
	if state.off or not On() then
		return false
	end
	local want = Wanted()
	for _, pair in ipairs(Rows(layout)) do
		for _, field in ipairs(ORDER) do
			local item = Find(pair[2], Setting(field))
			if not item or item.value ~= want[field] then
				return true
			end
		end
	end
	return false
end

local function WriteTo(layout, note)
	if state.off or not On() then
		return false
	end
	local want = Wanted()
	local changed = false
	for _, pair in ipairs(Rows(layout)) do
		local name, row = pair[1], pair[2]
		if type(row.settings) ~= "table" then
			row.settings = {}
		end
		for _, field in ipairs(ORDER) do
			local setting = Setting(field)
			local item = Find(row, setting)
			if not item or item.value ~= want[field] then
				local before = item and item.value
				if item then
					item.value = want[field]
				else
					row.settings[#row.settings + 1] = { setting = setting, value = want[field] }
				end
				if type(note) == "function" then
					note(name, row, setting, before)
				end
				changed = true
				state.wrote = true
			end
		end
	end
	return changed
end

local function Call(name, ...)
	local LS = ns.LayoutSpots
	if type(LS) == "table" and type(LS[name]) == "function" then
		return LS[name](...)
	end
end

local function Sync()
	if not On() then
		Call("Unwrite", WRITER)
		state.wrote = false
	end
	Call("Recheck")
end

function ns.BarButtonsChanged()
	Sync()
end

local function ScaleCheck()
	local want = Size() / 100
	for _, name in ipairs(BlockFrames()) do
		local container = _G[name .. "ButtonContainer1"]
		if container ~= nil and not ns.IsSecret(container) then
			local ok, scale = pcall(function()
				return container:GetScale()
			end)
			if ok and type(scale) == "number" and not ns.IsSecret(scale) and math.abs(scale - want) > TOLERANCE then
				return false
			end
		end
	end
	return true
end

local function Check()
	if state.checked then
		return
	end
	if InCombatLockdown() then
		state.waiting = true
		return
	end
	state.waiting = false
	state.checked = true
	if not On() then
		Sync()
		return
	end
	if not (ns.LayoutSpots and type(ns.LayoutSpots.AddWriter) == "function") then
		ns.Note(KEY, LINES.missing)
		return
	end
	local kept = Call("WriterState", WRITER)
	if kept == "refused" then
		state.off = true
		ns.Note(KEY, LINES.refused)
		return
	end
	if kept == "pending" then
		return
	end
	local info, entry = Call("Resolve")
	if not info or type(entry) ~= "table" or WantedFor(entry) then
		return
	end
	if not ScaleCheck() then
		state.off = true
		state.wrote = false
		ns.Note(KEY, LINES.scale)
		Call("Unwrite", WRITER)
		Call("Recheck")
	end
end

local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

if ns.LayoutSpots and type(ns.LayoutSpots.AddWriter) == "function" then
	ns.LayoutSpots.AddWriter(WRITER, { label = "Button size and spacing", Wanted = WantedFor, Write = WriteTo })
end

local boot = CreateFrame("Frame")
pcall(boot.RegisterEvent, boot, "PLAYER_ENTERING_WORLD")
pcall(boot.RegisterEvent, boot, "EDIT_MODE_LAYOUTS_UPDATED")
pcall(boot.RegisterEvent, boot, "PLAYER_REGEN_ENABLED")
boot:SetScript("OnEvent", function(_, event)
	if event == "EDIT_MODE_LAYOUTS_UPDATED" or (event == "PLAYER_ENTERING_WORLD" and not On()) then
		Soon(function()
			pcall(Check)
		end)
	elseif state.waiting then
		Soon(function()
			pcall(Check)
		end)
	end
end)
