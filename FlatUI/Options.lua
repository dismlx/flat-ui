local _, ns = ...

-- Builds the options from ns.PAGES: the first page is the category, the rest are subcategories.

local root
local variables = {}

local function Variable(path)
	return "FLATUI_" .. (path:upper():gsub("%.", "_"))
end

-- The settings that must be on for a control to apply: the chain of settings named by "needs", and the switch of
-- its page's owner. A row that acts at once has no switch.
local function Needed(page, item)
	local list = {}
	local owner = page.owner or page.switch or page.key
	local switch = ns.RowLive(item) and "" or owner
	local path = item.needsPath
	if not path and switch ~= "" and owner ~= "general" and item.key ~= "enabled" then
		path = switch .. ".enabled"
	end
	while path do
		local needed = path
		list[#list + 1] = needed
		path = ns.Needs(needed)
		if not path and switch ~= "" and owner ~= "general" and needed ~= switch .. ".enabled" then
			path = switch .. ".enabled"
		end
	end
	return list
end

local function Proxy(category, item, varType, default, get, set)
	variables[item.path] = Variable(item.path)
	return Settings.RegisterProxySetting(category, variables[item.path], varType, item.label, default, get, set)
end

-- What the game's Defaults button sets. A row the game holds has the value the game has when the button is pressed, so Defaults writes no
-- game setting. The client asks a default given as a function each time (Blizzard_Setting.lua:1-9, 358-359).
local function Initial(item)
	if item.cvar then
		return function()
			local value = ns.Get(item.path)
			if value == nil then
				return item.default
			end
			return value
		end
	end
	return item.default
end

local function AddBool(category, item)
	local setting = Proxy(category, item, Settings.VarType.Boolean, Initial(item),
		function()
			return ns.Get(item.path) == true
		end,
		function(value)
			ns.Set(item.path, value)
		end)
	return Settings.CreateCheckbox(category, setting, item.tip)
end

local function AddNumber(category, item)
	local setting = Proxy(category, item, Settings.VarType.Number, Initial(item),
		function()
			return ns.Get(item.path)
		end,
		function(value)
			ns.Set(item.path, value)
		end)
	local options = Settings.CreateSliderOptions(item.min, item.max, item.step)
	local unit = item.unit or ""
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return ("%d%s"):format(value, unit)
	end)
	return Settings.CreateSlider(category, setting, options, item.tip)
end

-- True while every setting a control needs is on.
local function Open(page, item)
	for _, needed in ipairs(Needed(page, item)) do
		if not ns.NeedMet(item, needed) then
			return false
		end
	end
	return true
end

-- The game leaves a colour swatch usable in a greyed row. A colour picked there is dropped and the swatch
-- put back on the next frame, since the game shows the picked colour once the setter has run. The default
-- is still taken: pressing Defaults sets the colours and the switches in no set order.
local function AddColour(category, item, page)
	local setting = Proxy(category, item, Settings.VarType.String, item.default,
		function()
			return ns.Get(item.path)
		end,
		function(value)
			if value ~= item.default and not Open(page, item) then
				if C_Timer and C_Timer.After then
					C_Timer.After(0, function()
						ns.NotifyOption(item.path)
					end)
				end
				return
			end
			ns.Set(item.path, value)
		end)
	return Settings.CreateColorSwatch(category, setting, item.tip)
end

-- A dropdown holds the position of the choice in its list. The default of a row whose list is made by a function of ns is its first line.
local function AddChoice(category, item)
	local function Index(value)
		for index, choice in ipairs(ns.Choices(item)) do
			if choice[1] == value then
				return index
			end
		end
		return 1
	end
	local setting = Proxy(category, item, Settings.VarType.Number, item.cvar and function()
			return Index(ns.Get(item.path))
		end or (type(item.choices) == "string" and 1 or Index(item.default)),
		function()
			return Index(ns.Get(item.path))
		end,
		function(index)
			local choice = ns.Choices(item)[index]
			if choice then
				ns.Set(item.path, choice[1])
			end
		end)
	-- The game asks for the lines when the dropdown is shown, not when it is registered. A list made by a function of ns, such as the faces the
	-- client loads, is not asked for before that, so a client that is asked at registration gets its first line.
	local registering = type(item.choices) == "string"
	local function Choices()
		local container = Settings.CreateControlTextContainer()
		if registering then
			container:Add(1, item.label)
			return container:GetData()
		end
		for index, choice in ipairs(ns.Choices(item)) do
			container:Add(index, choice[2])
		end
		return container:GetData()
	end
	local created = Settings.CreateDropdown(category, setting, Choices, item.tip)
	registering = false
	return created
end

-- A dropdown that acts: choosing a line calls a function of ns with that line's id, and the
-- dropdown goes back to its first line. The game builds the lines each time the menu opens.
-- Only a line chosen in the open menu acts; the arrows and the d-pad of a gamepad pick a line
-- without opening it. A game that cannot say when the menu opens counts every pick.
local function AddList(category, item)
	local open = true
	local setting = Proxy(category, item, Settings.VarType.Number, item.default,
		function()
			return item.default
		end,
		function(value)
			local pick = ns[item.pick]
			if not open or value == item.default or type(pick) ~= "function" then
				return
			end
			local _, message = pick(value)
			if type(message) == "string" then
				print(message)
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					ns.NotifyOption(item.path)
				end)
			end
		end)
	local function Lines()
		local container = Settings.CreateControlTextContainer()
		container:Add(item.default, item.none)
		local rows = type(ns[item.items]) == "function" and ns[item.items]() or {}
		for _, row in ipairs(rows) do
			container:Add(row[1], row[2])
		end
		return container:GetData()
	end
	local initializer = Settings.CreateDropdown(category, setting, Lines, item.tip)
	if type(initializer) == "table" then
		open = false
		-- The dropdown control calls these when its menu opens and closes.
		initializer.OnShow = function()
			open = true
		end
		initializer.OnHide = function()
			open = false
		end
		-- The arrows beside a dropdown pick the line after the selected one, which here acts.
		if type(initializer.data) == "table" then
			initializer.data.forceSteppersHidden = true
		end
	end
	return initializer
end

local ADD = { bool = AddBool, number = AddNumber, colour = AddColour, choice = AddChoice, list = AddList }

-- A control is greyed out while a setting it depends on is off. The game checks this when it builds
-- the control, and again whenever one of those settings changes.
local function Depend(initializer, page, item)
	if type(initializer) ~= "table" or type(initializer.AddModifyPredicate) ~= "function" then
		return
	end
	for _, needed in ipairs(Needed(page, item)) do
		initializer:AddModifyPredicate(function()
			return ns.NeedMet(item, needed)
		end)
		if type(initializer.AddEvaluateStateCVar) == "function" then
			initializer:AddEvaluateStateCVar(Variable(needed))
		end
	end
end

local function BuildPage(category, page)
	for _, item in ipairs(page) do
		if item.section then
			if CreateSettingsListSectionHeaderInitializer and Settings.RegisterInitializer then
				pcall(function()
					Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(item.section))
				end)
			end
		elseif item.kind == "entries" then
			-- The tracker editor is a block of the window's own.
		elseif ns.RowShown(item.path) then
			-- One control the client cannot build does not cost the rest of the page.
			local ok, initializer = pcall(ADD[item.kind], category, item, page)
			if ok then
				pcall(Depend, initializer, page, item)
			else
				geterrorhandler()(initializer)
			end
		end
	end
end

-- One category with a button that opens Flat UI's own window, in place of the settings: every setting made here sits in the game's settings
-- registry, which a click on an action button walks (ActionButton.lua:1409), so a registry with none of Flat UI's settings in it leaves the
-- click nothing of this addon's to read (EllesmereUI registers one canvas category the same way, EllesmereUI.lua:4366-4367).
local function RegisterCanvas()
	local frame = CreateFrame("Frame")
	ns.Own[frame] = true
	local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
	text:SetText("The settings are in Flat UI's own window. /flatui opens it.")
	local button = CreateFrame("Frame", nil, frame)
	ns.Own[button] = true
	button:SetSize(160, 24)
	button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
	button:EnableMouse(true)
	local outline = ns.Outline(button, button, true)
	ns.KeepOutline(outline)
	ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText("Open Flat UI")
	button:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" and type(ns.OpenPanel) == "function" then
			local ok, err = pcall(ns.OpenPanel)
			if not ok then
				geterrorhandler()(err)
			end
		end
	end)
	root = Settings.RegisterCanvasLayoutCategory(frame, "Flat UI")
	Settings.RegisterAddOnCategory(root)
end

function ns.RegisterOptions()
	if root then
		return
	end
	if ns.HandsOff() then
		if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
			RegisterCanvas()
		end
		return
	end
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then
		return
	end
	for index, page in ipairs(ns.PAGES) do
		if index == 1 then
			root = Settings.RegisterVerticalLayoutCategory(page.label)
			BuildPage(root, page)
		elseif Settings.RegisterVerticalLayoutSubcategory and ns.PageHasRows(page) then
			local ok, category = pcall(Settings.RegisterVerticalLayoutSubcategory, root, page.label)
			if ok and category then
				BuildPage(category, page)
			end
		end
	end
	Settings.RegisterAddOnCategory(root)
end

-- A value changed outside the panel shows in the open panel.
function ns.NotifyOption(path)
	if root and variables[path] and Settings.NotifyUpdate then
		pcall(Settings.NotifyUpdate, variables[path])
	end
end

-- Returns true when the options opened, and "combat" as the second value when a fight is why they did not.
function ns.OpenOptions()
	if not root then
		return false
	end
	if InCombatLockdown() then
		return false, "combat"
	end
	local ok = pcall(Settings.OpenToCategory, root:GetID())
	return ok and SettingsPanel ~= nil and SettingsPanel:IsShown()
end

-- /flatui status names the settings this addon put in the game's settings registry.
ns.ClickPathReporter(function()
	local count = 0
	for _ in pairs(variables) do
		count = count + 1
	end
	if count > 0 and ns.Get("general.handsOff") == false then
		return ("Click path: %d Flat UI settings are in the game's settings registry."):format(count)
	end
	return nil
end)
