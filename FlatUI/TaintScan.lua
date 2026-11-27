local _, ns = ...

local KEEP = 3
local STORE, SHOW = 100, 12
local REPEAT_SECONDS = 5
local MIXIN_KEYS = 400
local SETTINGS_KEYS = 5000

local BUTTON_FIELDS = { "popup", "bar", "isExtra", "buttonType", "action", "NewActionTexture", "flashing" }
local BUTTON_METHODS = { "GetID", "CalculateAction", "GetAttribute", "GetButtonState", "SetButtonState", "UpdateState", "UpdateHighlightMark", "Update",
	"UpdateAction", "UpdateFlyout", "UpdatePressAndHoldAction", "OnClick" }
local BAR_FIELDS = { "actionButtons", "shownButtonContainers", "isShownExternal", "showAllButtons", "flyoutDirection" }
local BAR_METHODS = { "GetAttribute", "UpdateShownButtons", "UpdateDividers", "Show", "Hide", "SetShown", "IsShown", "ShowBase", "HideBase", "SetShownBase" }
local GLOBALS = { "ActionButtonDown", "ActionButtonUp", "MultiActionButtonDown", "MultiActionButtonUp", "TryUseActionButton", "GetActionButtonForID",
	"SecureActionButton_OnClick", "SpellFlyout", "OverrideActionBar", "PetBattleFrame", "ACTION_HIGHLIGHT_MARKS", "ON_BAR_HIGHLIGHT_MARKS",
	"MacroFrame_SaveMacro", "ActionBarActionButtonDerivedMixin_OnClick",
	"KeybindFrames_InQuickKeybindMode", "C_ActionBar", "Settings", "IsModifiedClick", "GetCursorInfo",
	"SecureButton_GetModifiedAttribute", "SecureButton_GetModifierPrefix", "SecureButton_GetButtonSuffix", "ATTRIBUTE_NOOP", "SecureButton_GetAttribute",
	"SecureActionButton_ShouldUseOnKeyDown", "GetCVarBool", "securecallfunction", "SaveMacro", "GetActionInfo", "UseAction" }
local TABLE_KEYS = { { "C_ActionBar", { "IsAutoCastPetAction" } }, { "Settings", { "GetValue" } } }
local BUTTON_KEYS = 400
local MIXINS = { "ActionBarActionButtonMixin", "ActionBarActionButtonDerivedMixin", "SecureActionButtonMixin" }
local MIXIN_METHODS = { "OnClick", "CalculateAction", "GetID", "GetAttribute", "GetButtonState", "SetButtonState", "UpdateState", "UpdateHighlightMark",
	"Update", "UpdateAction", "UpdateFlyout", "UpdatePressAndHoldAction", "TriggerSecureClick" }
local BARS = { { "ActionButton", "MainActionBar" }, { "MultiBarBottomLeftButton", "MultiBarBottomLeft" },
	{ "MultiBarBottomRightButton", "MultiBarBottomRight" }, { "MultiBarLeftButton", "MultiBarLeft" }, { "MultiBarRightButton", "MultiBarRight" },
	{ "MultiBar5Button", "MultiBar5" }, { "MultiBar6Button", "MultiBar6" }, { "MultiBar7Button", "MultiBar7" } }

local OWN_FIELDS = { "popup", "bar", "isExtra", "buttonType", "action" }
local OWN_BAR_FIELDS = { "actionButtons", "isShownExternal", "flyoutDirection", "showAllButtons" }

local session = {}

local function Plain(value)
	return not ns.IsSecret(value)
end

local function OwnButtons()
	if type(ns.OwnButtons) ~= "function" then
		return {}
	end
	local ok, list = pcall(ns.OwnButtons)
	return ok and Plain(list) and type(list) == "table" and list or {}
end

local function NameOf(frame)
	local ok, name = pcall(frame.GetName, frame)
	return ok and Plain(name) and type(name) == "string" and name or nil
end

local function ClicksSecurely(button)
	local ok, handler = pcall(button.GetScript, button, "OnClick")
	return ok and handler == _G.SecureActionButton_OnClick
end

local function ChangedBy(owner, key)
	local check = _G.issecurevariable
	if type(check) ~= "function" then
		return nil
	end
	local ok, secure, by = pcall(check, owner, key)
	if ok and Plain(secure) and secure == false then
		return (Plain(by) and type(by) == "string" and by ~= "") and by or "unknown"
	end
	return nil
end

local function Table(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and Plain(value) and type(value) == "table" then
		return value
	end
	return nil
end

local function Field(owner, key)
	local ok, value = pcall(rawget, owner, key)
	if ok and Plain(value) and type(value) == "table" then
		return value
	end
	return nil
end

local function Keys(owner, limit)
	local keys = {}
	pcall(function()
		for key in pairs(owner) do
			if #keys >= limit then
				break
			end
			if Plain(key) and (type(key) == "string" or type(key) == "number") then
				keys[#keys + 1] = key
			end
		end
	end)
	return keys
end

local function Scan(hovered)
	local result = { tainted = {}, more = 0, buttons = 0, bars = 0, globals = 0, mixins = 0, settings = 0, settingsTainted = 0, keys = 0 }
	local function Add(name, by)
		if #result.tainted < STORE then
			result.tainted[#result.tainted + 1] = { name = name, by = by }
		else
			result.more = result.more + 1
		end
	end
	local function Each(label, owner, keys)
		for _, key in ipairs(keys) do
			local by = ChangedBy(owner, key)
			if by then
				Add(label .. "." .. tostring(key), by)
			end
		end
	end
	local entries = {}
	for _, bar in ipairs(BARS) do
		for index = 1, 12 do
			local name = bar[1] .. index
			local button = Table(name)
			if button then
				entries[#entries + 1] = { name = name, button = button, bar = bar[2] }
			end
		end
	end
	local chosen
	if hovered then
		for _, entry in ipairs(entries) do
			if entry.button == hovered then
				chosen = entry
				break
			end
		end
	end
	local ownBars = {}
	for _, button in ipairs(OwnButtons()) do
		local name = NameOf(button)
		if name then
			local entry = { name = name, button = button, own = true }
			entries[#entries + 1] = entry
			if hovered and button == hovered then
				chosen = entry
			end
		end
	end
	local barsDone = {}
	for _, entry in ipairs(entries) do
		result.buttons = result.buttons + 1
		if entry.own then
			Each(entry.name, entry.button, OWN_FIELDS)
			if not ClicksSecurely(entry.button) then
				Add(entry.name .. ".OnClick", "not SecureActionButton_OnClick")
			end
			local ok, bar = pcall(entry.button.GetParent, entry.button)
			if ok and Plain(bar) and type(bar) == "table" and not ownBars[bar] then
				ownBars[bar] = true
				result.bars = result.bars + 1
				Each(NameOf(bar) or "FlatUIBar", bar, OWN_BAR_FIELDS)
			end
		else
			Each(entry.name, entry.button, BUTTON_FIELDS)
			Each(entry.name, entry.button, BUTTON_METHODS)
			if not barsDone[entry.bar] then
				barsDone[entry.bar] = true
				local bar = Field(entry.button, "bar") or Table(entry.bar)
				if bar then
					result.bars = result.bars + 1
					Each(entry.bar, bar, BAR_FIELDS)
					Each(entry.bar, bar, BAR_METHODS)
				end
			end
		end
	end
	if chosen then
		local listed = {}
		for _, key in ipairs(BUTTON_FIELDS) do
			listed[key] = true
		end
		for _, key in ipairs(BUTTON_METHODS) do
			listed[key] = true
		end
		local keys = {}
		for _, key in ipairs(Keys(chosen.button, BUTTON_KEYS)) do
			if not listed[key] then
				keys[#keys + 1] = key
			end
		end
		result.keys = #keys
		Each(chosen.name, chosen.button, keys)
	end
	result.clicked = chosen and chosen.name or nil
	for _, name in ipairs(GLOBALS) do
		result.globals = result.globals + 1
		local by = ChangedBy(_G, name)
		if by then
			Add(name, by)
		end
	end
	for _, item in ipairs(TABLE_KEYS) do
		local owner = Table(item[1])
		if owner then
			Each(item[1], owner, item[2])
		end
	end
	for _, name in ipairs(MIXINS) do
		local mixin = Table(name)
		if mixin then
			result.mixins = result.mixins + 1
			local keys, seen = {}, {}
			for _, key in ipairs(MIXIN_METHODS) do
				seen[key] = true
				keys[#keys + 1] = key
			end
			for _, key in ipairs(Keys(mixin, MIXIN_KEYS)) do
				if not seen[key] then
					seen[key] = true
					keys[#keys + 1] = key
				end
			end
			Each(name, mixin, keys)
		end
	end
	local panel = Table("SettingsPanel")
	local settings = panel and Field(panel, "settings")
	if settings then
		local by = {}
		for _, key in ipairs(Keys(settings, SETTINGS_KEYS)) do
			result.settings = result.settings + 1
			local name = ChangedBy(settings, key)
			if name then
				result.settingsTainted = result.settingsTainted + 1
				by[name] = true
			end
		end
		if result.settingsTainted > 0 then
			local names = {}
			for name in pairs(by) do
				names[#names + 1] = name
			end
			table.sort(names)
			Add(("SettingsPanel.settings (%d of %d keys)"):format(result.settingsTainted, result.settings), table.concat(names, ", "))
		end
	end
	return result
end

local function Clock(at)
	if type(at) ~= "number" or at <= 0 then
		return "unknown time"
	end
	local ok, text = pcall(function()
		return _G.date("%Y-%m-%d %H:%M:%S", at)
	end)
	return ok and type(text) == "string" and text or tostring(at)
end

local function Format(record, title)
	local lines = { title }
	if #record.tainted == 0 then
		lines[#lines + 1] = "No tainted value found."
	else
		for index, item in ipairs(record.tainted) do
			if index > SHOW then
				lines[#lines + 1] = ("%d more tainted values."):format(#record.tainted - SHOW + (record.more or 0))
				break
			end
			lines[#lines + 1] = ("Tainted: %s by %s"):format(item.name, item.by)
		end
	end
	local function Count(n, one, many)
		return ("%d %s"):format(n, n == 1 and one or many)
	end
	local checked = "Checked: " .. Count(record.buttons or 0, "button", "buttons")
	if record.clicked then
		checked = checked .. (", %s under the cursor with %s"):format(record.clicked, Count(record.keys or 0, "more key", "more keys"))
	end
	checked = checked .. ", " .. Count(record.bars or 0, "bar", "bars") .. ", " .. Count(record.globals or 0, "global", "globals") .. ", "
		.. Count(record.mixins or 0, "mixin", "mixins")
	if (record.settings or 0) > 0 then
		checked = checked .. ", " .. Count(record.settings, "setting", "settings")
	end
	lines[#lines + 1] = checked .. "."
	return lines
end

local function Kept()
	local account = ns.Account()
	if type(account) ~= "table" then
		return session
	end
	if type(account.taintScans) ~= "table" then
		account.taintScans = {}
	end
	return account.taintScans
end

local lastCall, lastAt
local waiting = {}

local function Now()
	local got, now = pcall(function()
		return _G.GetTime()
	end)
	return got and Plain(now) and type(now) == "number" and now or nil
end

local function Hovered()
	if type(_G.GetMouseFoci) ~= "function" then
		return nil
	end
	local ok, foci = pcall(_G.GetMouseFoci)
	local frame = ok and Plain(foci) and type(foci) == "table" and foci[1] or nil
	local names = {}
	for _, bar in ipairs(BARS) do
		for index = 1, 12 do
			local button = Table(bar[1] .. index)
			if button then
				names[button] = true
			end
		end
	end
	for _, button in ipairs(OwnButtons()) do
		names[button] = true
	end
	for _ = 1, 4 do
		if type(frame) ~= "table" or not Plain(frame) then
			return nil
		end
		if names[frame] then
			return frame
		end
		local got, parent = pcall(frame.GetParent, frame)
		frame = got and parent or nil
	end
	return nil
end

local function Keep(event, name, hovered)
	local ok, result = pcall(Scan, hovered)
	if not ok then
		return
	end
	lastCall, lastAt = name, Now()
	local stamp = _G.time
	local got, at = pcall(function()
		return stamp()
	end)
	result.at = got and Plain(at) and type(at) == "number" and at or 0
	result.call = name
	result.kind = event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked"
	local list = Kept()
	list[#list + 1] = result
	while #list > KEEP do
		table.remove(list, 1)
	end
end

function ns.TaintRecord(event, call)
	if type(_G.issecurevariable) ~= "function" then
		return
	end
	local name = tostring(call)
	local now = Now()
	if waiting[name] or (now and lastCall == name and lastAt and now - lastAt < REPEAT_SECONDS) then
		return
	end
	local hovered = Hovered()
	local after = _G.C_Timer and _G.C_Timer.After
	waiting[name] = true
	if type(after) == "function" and pcall(after, 0, function()
		waiting[name] = nil
		Keep(event, name, hovered)
	end) then
		return
	end
	waiting[name] = nil
	Keep(event, name, hovered)
end

function ns.TaintOwnLine()
	if type(_G.issecurevariable) ~= "function" then
		return nil
	end
	for _, button in ipairs(OwnButtons()) do
		local name = NameOf(button)
		if name then
			for _, key in ipairs(OWN_FIELDS) do
				if ChangedBy(button, key) then
					return ("Flat UI's buttons: %s on %s written outside secure code."):format(key, name)
				end
			end
		end
	end
	return nil
end

function ns.TaintLines()
	local lines = {}
	for _, record in ipairs(Kept()) do
		if type(record) == "table" and type(record.tainted) == "table" then
			for _, line in ipairs(Format(record, ("%s %s at %s"):format(tostring(record.call), tostring(record.kind), Clock(record.at)))) do
				lines[#lines + 1] = line
			end
		end
	end
	return lines
end

function ns.TaintCommand()
	if type(_G.issecurevariable) ~= "function" then
		print("Taint scan: this game has no issecurevariable.")
		return
	end
	local ok, result = pcall(Scan, Hovered())
	if not ok then
		print("Taint scan: stopped. " .. tostring(result))
		return
	end
	for _, line in ipairs(Format(result, "Click path now:")) do
		print(line)
	end
end
