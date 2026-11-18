-- Provisions' panel (/prov, /provisions, and an entry in the game's Settings, AddOns list): a row per kind with its
-- icon (drag it, or click it, to pick up the kind's macro and put it on an action bar), the item it uses now and
-- how many the bags hold, a check box to turn the kind on or off, and the options. Movable; Escape closes it; it
-- closes when a fight starts and opens only out of one.

local _, ns = ...

local INFO, KINDS = ns.INFO, ns.KINDS
local ICON = 134400
local ROW = 44
local WIDTH = 470

local panel, rows, optionWidgets
local refreshing = false

local function Try(fn, ...)
	if type(fn) == "function" then
		return pcall(fn, ...)
	end
	return false
end

local function Make(kind, parent, template)
	local ok, f = pcall(CreateFrame, kind, nil, parent, template)
	if ok and f then
		return f
	end
	return CreateFrame(kind, nil, parent)
end

local function Text(parent, font, size)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	if size then
		local path, _, flags = fs:GetFont()
		if path then
			pcall(fs.SetFont, fs, path, size, flags)
		end
	end
	fs:SetJustifyH("LEFT")
	return fs
end

local function Check(parent, label, onClick)
	local c = Make("CheckButton", parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	if label then
		c.label = Text(parent, "GameFontHighlight")
		c.label:SetPoint("LEFT", c, "RIGHT", 4, 0)
		c.label:SetText(label)
	end
	c:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)
	return c
end

-- An item's name; one the game has not loaded yet is asked for once (GET_ITEM_INFO_RECEIVED then refreshes the
-- panel), so a load that fails cannot start a loop of asks and refreshes.
local asked = {}
local function ItemName(id)
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, id)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
		if C_Item.RequestLoadItemDataByID and not asked[id] then
			asked[id] = true
			pcall(C_Item.RequestLoadItemDataByID, id)
		end
	end
	return "item " .. id
end

local function ItemIcon(id)
	if id and C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if ok and icon then
			return icon
		end
	end
	return ICON
end

-- The choices of the Buff Food button: Auto, Any, then each stat that some buff food gives.
local function BuffChoices()
	local present = {}
	for _, rec in pairs(ns.ITEMS or {}) do
		if rec.buff then
			for key in pairs(rec.buff) do
				present[key] = true
			end
		end
	end
	local list = { "auto", "any" }
	for _, s in ipairs(ns.STATS) do
		if present[s.key] then
			table.insert(list, s.key)
		end
	end
	return list
end

local function ChoiceName(key)
	if key == "auto" then
		return "Auto (for your class)"
	elseif key == "any" then
		return "Any (the strongest)"
	end
	return ns.STAT[key] and ns.STAT[key].name or key
end

local function Changed()
	if ns.Schedule then
		ns.Schedule(0)
	end
end

local function PickUp(kind)
	if ns.InCombat() then
		return
	end
	local index = ns.MacroIndex(kind)
	if index then
		Try(PickupMacro, index)
	elseif ns.KindOn(kind) then
		ns.Say("the " .. INFO[kind].label .. " macro is not there yet (see the line under it).")
	else
		ns.Say("turn " .. INFO[kind].label .. " on first.")
	end
end

local function MakeRow(kind, index)
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(WIDTH - 24, ROW)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -40 - (index - 1) * ROW)

	row.check = Check(row, nil, function(on)
		ns.cdb.kinds[kind] = on
		Changed()
	end)
	row.check:SetPoint("LEFT", row, "LEFT", 0, 0)

	local icon = CreateFrame("Button", nil, row)
	icon:SetSize(36, 36)
	icon:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.tex:SetAllPoints()
	icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:RegisterForDrag("LeftButton")
	icon:SetScript("OnDragStart", function()
		PickUp(kind)
	end)
	icon:SetScript("OnClick", function()
		PickUp(kind)
	end)
	icon.count = Text(icon, "NumberFontNormal")
	icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
	icon.count:SetJustifyH("RIGHT")
	row.icon = icon

	row.title = Text(row, "GameFontNormal")
	row.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
	row.title:SetWidth(WIDTH - 110)
	row.title:SetWordWrap(false)

	row.line = Text(row, "GameFontHighlightSmall")
	row.line:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
	row.line:SetWidth(WIDTH - 110)
	row.line:SetWordWrap(true)
	if row.line.SetMaxLines then
		pcall(row.line.SetMaxLines, row.line, 2)
	end
	return row
end

local function Refresh()
	if not panel or not panel:IsShown() or refreshing then
		return
	end
	refreshing = true
	for _, kind in ipairs(KINDS) do
		local row = rows[kind]
		local state = ns.states[kind] or {}
		local on = ns.KindOn(kind)
		row.check:SetChecked(on)
		local title = INFO[kind].label .. "  |cff808080(" .. INFO[kind].macro .. ")|r"
		if state.best then
			local count = ns.Count(state.best)
			title = INFO[kind].label .. ":  |cffffffff" .. ItemName(state.best) .. "|r"
			row.icon.count:SetText(count > 0 and count or "")
		else
			title = title .. ":  |cff9d9d9dnone in your bags|r"
			row.icon.count:SetText("")
		end
		row.title:SetText(title)
		row.icon.tex:SetTexture(ItemIcon(state.best))
		row.icon.tex:SetDesaturated(not on)
		row.icon:SetAlpha(on and 1 or 0.5)

		local lines = {}
		if not on then
			table.insert(lines, "Off: no macro; its key binding says so in chat.")
		end
		if state.note then
			table.insert(lines, state.note)
		end
		if kind == "buff" then
			if state.stat then
				table.insert(lines, "Buff: " .. (ns.STAT[state.stat] and ns.STAT[state.stat].name or state.stat))
			end
			local buffLine = ns.BuffLine(state)
			if buffLine then
				table.insert(lines, buffLine)
			end
		elseif kind == "bandage" and on then
			table.insert(lines, ns.Opt("bandageSelf") and "On you." or "On your mouseover or friendly target, else on you.")
		elseif state.rest and #state.rest > 0 then
			table.insert(lines, "Then " .. #state.rest .. " more of the same cooldown if it runs out in a fight.")
		end
		if on and ns.IsFull() and not ns.MacroIndex(kind) then
			table.insert(lines, "|cffff6060Your character's macro list is full.|r")
		end
		row.line:SetText(table.concat(lines, " "))
	end
	optionWidgets.buff:SetText("Buff food: " .. ChoiceName(ns.Opt("buffChoice") or "auto"))
	optionWidgets.bandageSelf:SetChecked(ns.Opt("bandageSelf") and true or false)
	optionWidgets.conjured:SetChecked(ns.Opt("conjuredFirst") and true or false)
	optionWidgets.fallback:SetChecked(ns.Opt("buffFallback") and true or false)
	refreshing = false
end
ns.Refresh = Refresh

function ns.PanelShown()
	return panel and panel:IsShown() or false
end

function ns.HidePanel()
	if panel and panel:IsShown() then
		panel:Hide()
	end
end

local function SavePlace()
	local point, _, relPoint, x, y = panel:GetPoint(1)
	if point and ns.db then
		ns.db.point = { point, relPoint, x, y }
	end
end

function ns.MakePanel()
	if panel then
		return
	end
	panel = Make("Frame", UIParent, "BackdropTemplate")
	panel:Hide()
	panel:SetSize(WIDTH, 40 + #KINDS * ROW + 150)
	panel:SetFrameStrata("DIALOG")
	panel:SetToplevel(true)
	panel:SetClampedToScreen(true)
	if panel.SetBackdrop then
		pcall(panel.SetBackdrop, panel, {
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		pcall(panel.SetBackdropColor, panel, 0.07, 0.07, 0.09, 0.96)
		pcall(panel.SetBackdropBorderColor, panel, 0.32, 0.32, 0.38, 1)
	end
	local place = ns.db and ns.db.point
	if type(place) == "table" and place[1] then
		panel:SetPoint(place[1], UIParent, place[2] or place[1], place[3] or 0, place[4] or 0)
	else
		panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePlace()
	end)
	-- Escape closes it: the panel hears keys while shown and lets every other key through to the game.
	panel:EnableKeyboard(true)
	panel:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" and not ns.InCombat() then
			Try(self.SetPropagateKeyboardInput, self, false)
			self:Hide()
		elseif not ns.InCombat() then
			Try(self.SetPropagateKeyboardInput, self, true)
		end
	end)
	panel:SetScript("OnShow", function(self)
		Try(self.SetPropagateKeyboardInput, self, true)
		Refresh()
	end)

	local title = Text(panel, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12)
	title:SetText("Provisions")
	local sub = Text(panel, "GameFontDisableSmall")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
	sub:SetText("one button per kind, always the best in your bags")

	local close = Make("Button", panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		panel:Hide()
	end)
	if not close:GetNormalTexture() then
		close:SetSize(20, 20)
		local x = Text(close, "GameFontNormal")
		x:SetPoint("CENTER")
		x:SetText("x")
	end

	rows = {}
	for i, kind in ipairs(KINDS) do
		rows[kind] = MakeRow(kind, i)
	end

	local top = -40 - #KINDS * ROW - 8
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(0.32, 0.32, 0.38, 1)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, top)
	line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, top)

	optionWidgets = {}
	local buff = Make("Button", panel, "UIPanelButtonTemplate")
	buff:SetSize(300, 24)
	buff:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, top - 10)
	buff:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	if not buff:GetFontString() then
		buff:SetNormalFontObject("GameFontHighlight")
	end
	buff:SetScript("OnClick", function(_, button)
		local list = BuffChoices()
		local current, at = ns.Opt("buffChoice") or "auto", 1
		for i, key in ipairs(list) do
			if key == current then
				at = i
			end
		end
		at = at + ((button == "RightButton") and -1 or 1)
		if at > #list then
			at = 1
		elseif at < 1 then
			at = #list
		end
		ns.cdb.buffChoice = list[at]
		Changed()
	end)
	local hint = Text(panel, "GameFontDisableSmall")
	hint:SetPoint("LEFT", buff, "RIGHT", 8, 0)
	hint:SetText("click: next, right-click: back")
	optionWidgets.buff = buff

	optionWidgets.bandageSelf = Check(panel, "Bandage only myself (off: mouseover, then target, then me)", function(on)
		ns.cdb.bandageSelf = on
		Changed()
	end)
	optionWidgets.bandageSelf:SetPoint("TOPLEFT", buff, "BOTTOMLEFT", -2, -6)
	optionWidgets.conjured = Check(panel, "Conjured food, water and mana gems first (free; they vanish)", function(on)
		ns.cdb.conjuredFirst = on
		Changed()
	end)
	optionWidgets.conjured:SetPoint("TOPLEFT", optionWidgets.bandageSelf, "BOTTOMLEFT", 0, 0)
	optionWidgets.fallback = Check(panel, "Food and Drink may eat buff food when no plain one is left", function(on)
		ns.cdb.buffFallback = on
		Changed()
	end)
	optionWidgets.fallback:SetPoint("TOPLEFT", optionWidgets.conjured, "BOTTOMLEFT", 0, 0)

	local foot = Text(panel, "GameFontDisableSmall")
	foot:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 14, 12)
	foot:SetWidth(WIDTH - 28)
	foot:SetText("Drag an icon to an action bar, or bind keys in Key Bindings > Provisions. "
		.. "Nothing changes in a fight: the game forbids it.")

	-- The entry in the game's Settings, AddOns list: a page of its own with a button that opens the panel.
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local page = CreateFrame("Frame")
		local head = Text(page, "GameFontNormalLarge")
		head:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
		head:SetText("Provisions")
		local body = Text(page, "GameFontHighlight")
		body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
		body:SetWidth(560)
		body:SetText("One button for each kind of consumable: healing potion, mana potion, healthstone, food, drink, "
			.. "bandage and buff food. Each is a macro of your character (Prov Heal and so on) and a key binding "
			.. "(Key Bindings > Provisions), always on the best item in your bags. Type /prov to open the panel.")
		local open = Make("Button", page, "UIPanelButtonTemplate")
		open:SetSize(160, 26)
		open:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -14)
		open:SetText("Open Provisions")
		open:SetScript("OnClick", function()
			if ns.InCombat() then
				ns.Say("the panel opens out of a fight.")
				return
			end
			panel:Show()
		end)
		local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, "Provisions")
		if ok and category then
			pcall(Settings.RegisterAddOnCategory, category)
		end
	end
end

local function Toggle()
	if not panel then
		ns.MakePanel()
	end
	if not panel then
		return
	end
	if panel:IsShown() then
		panel:Hide()
	elseif ns.InCombat() then
		ns.Say("the panel opens out of a fight.")
	else
		panel:Show()
	end
end

SLASH_PROVISIONS1 = "/prov"
SLASH_PROVISIONS2 = "/provisions"
SlashCmdList.PROVISIONS = function()
	Toggle()
end

-- Key Bindings > Provisions (Bindings.xml).
BINDING_HEADER_PROVISIONS = "Provisions"
for _, kind in ipairs(KINDS) do
	_G["BINDING_NAME_CLICK " .. INFO[kind].button .. ":LeftButton"] = INFO[kind].label
end
