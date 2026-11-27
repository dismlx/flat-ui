local _, ns = ...

local root
local variables = {}

local function Variable(path)
	return "FLATUI_" .. (path:upper():gsub("%.", "_"))
end

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

local function Initial(item)
	if item.cvar or item.set == "CameraZoomSet" then
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

local function Open(page, item)
	for _, needed in ipairs(Needed(page, item)) do
		if not ns.NeedMet(item, needed) then
			return false
		end
	end
	return true
end

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

local function AddChoice(category, item)
	local function Index(value)
		for index, choice in ipairs(ns.Choices(item)) do
			if choice[1] == value then
				return index
			end
		end
		return 1
	end
	local registering = type(item.choices) == "string"
	local setting = Proxy(category, item, Settings.VarType.Number, item.cvar and function()
			return Index(ns.Get(item.path))
		end or (type(item.choices) == "string" and function()
			if registering then
				return 1
			end
			return Index(item.default)
		end or Index(item.default)),
		function()
			return Index(ns.Get(item.path))
		end,
		function(index)
			local choice = ns.Choices(item)[index]
			if choice then
				ns.Set(item.path, choice[1])
			end
		end)
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
		initializer.OnShow = function()
			open = true
		end
		initializer.OnHide = function()
			open = false
		end
		if type(initializer.data) == "table" then
			initializer.data.forceSteppersHidden = true
		end
	end
	return initializer
end

local ADD = { bool = AddBool, number = AddNumber, colour = AddColour, choice = AddChoice, list = AddList }

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
		elseif ns.RowShown(item.path) then
			local ok, initializer = pcall(ADD[item.kind], category, item, page)
			if ok then
				pcall(Depend, initializer, page, item)
			else
				geterrorhandler()(initializer)
			end
		end
	end
end

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
	local down = false
	button:SetScript("OnEnter", function()
		ns.SetOutlineFill(outline, 0.26, 0.26, 0.26, 1)
	end)
	button:SetScript("OnLeave", function()
		ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	end)
	button:SetScript("OnMouseDown", function(_, mouseButton)
		down = mouseButton == "LeftButton"
	end)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		local wanted = down and mouseButton == "LeftButton"
		down = false
		local ok, over = pcall(self.IsMouseOver, self)
		if wanted and (not ok or ns.IsSecret(over) or over ~= false) and type(ns.OpenPanel) == "function" then
			local opened, err = pcall(ns.OpenPanel)
			if not opened then
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

function ns.NotifyOption(path)
	if root and variables[path] and Settings.NotifyUpdate then
		pcall(Settings.NotifyUpdate, variables[path])
	end
end

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
