local _, ns = ...

local BAR = {
	{ game = "MainActionBar", twin = "ActionButton", cmd = "ACTIONBUTTON", base = 0 },
	{ game = "MultiBarBottomLeft", twin = "MultiBarBottomLeftButton", cmd = "MULTIACTIONBAR1BUTTON", base = 60 },
	{ game = "MultiBarBottomRight", twin = "MultiBarBottomRightButton", cmd = "MULTIACTIONBAR2BUTTON", base = 48 },
	{ game = "MultiBarRight", twin = "MultiBarRightButton", cmd = "MULTIACTIONBAR3BUTTON", base = 24 },
	{ game = "MultiBarLeft", twin = "MultiBarLeftButton", cmd = "MULTIACTIONBAR4BUTTON", base = 36 },
	{ game = "MultiBar5", twin = "MultiBar5Button", cmd = "MULTIACTIONBAR5BUTTON", base = 144 },
	{ game = "MultiBar6", twin = "MultiBar6Button", cmd = "MULTIACTIONBAR6BUTTON", base = 156 },
	{ game = "MultiBar7", twin = "MultiBar7Button", cmd = "MULTIACTIONBAR7BUTTON", base = 168 },
}

local S = {
	built = false, pending = false, busy = false, error = nil, header = nil,
	bars = {}, buttons = {}, grid = {}, watchers = {}, parked = false,
	info = setmetatable({}, { __mode = "k" }),
	flag = {}, clock = 0, putBack = 0,
	chunk = {},
	slots = {},
	slotListeners = {}, builtListeners = {},
	editWas = false,
	rect = {}, rectClock = 0,
	kbWant = false, kbHeld = false, kbTold = false, fight = false, kbOwner = {},
	emptySet = {}, emptyBusy = false, emptyOn = false,
}
local F = {}

local PAGE = [=[
local page = HasVehicleActionBar() and GetVehicleBarIndex() or HasOverrideActionBar() and GetOverrideBarIndex() or HasTempShapeshiftActionBar() and GetTempShapeshiftBarIndex() or (HasBonusActionBar() and GetActionBarPage() == 1) and GetBonusBarIndex() or GetActionBarPage()
bar:SetAttribute("flatui-page", page)
local routed = 0
for i = 1, 12 do
	local b = bar:GetFrameRef("b" .. i)
	local slot = (page - 1) * 12 + i
	if b:GetAttribute("action") ~= slot then
		b:SetAttribute("action", slot)
	end
	local flyout = GetActionInfo(slot) == "flyout"
	for _, key in ipairs(newtable(GetBindingKey("ACTIONBUTTON" .. i))) do
		if flyout then
			bar:SetBindingClick(true, key, "FlatUIBar1Button" .. i, "LeftButton")
			routed = routed + 1
		else
			bar:ClearBinding(key)
		end
	end
end
bar:SetAttribute("flatui-routed", routed)
]=]
local PAGE_STATE = "local bar = self\n" .. PAGE
local PAGE_EXEC = "local bar = self:GetFrameRef('bar1')\n" .. PAGE

local PAGE_VALUE = "[vehicleui] v; [overridebar] o; [possessbar] p; [shapeshift] s; [bonusbar:5,bar:1] b5; [bonusbar:4,bar:1] b4; [bonusbar:3,bar:1] b3; "
	.. "[bonusbar:2,bar:1] b2; [bonusbar:1,bar:1] b1; [bar:6] 6; [bar:5] 5; [bar:4] 4; [bar:3] 3; [bar:2] 2; 1"

local ROUTE = [=[
for n = 2, 8 do
	local cmd = select(n - 1, %s)
	local bar = self:GetFrameRef("bar" .. n)
	local routed = 0
	for i = 1, 12 do
		local slot = bar:GetFrameRef("b" .. i):GetAttribute("action")
		local flyout = GetActionInfo(slot) == "flyout"
		for _, key in ipairs(newtable(GetBindingKey(cmd .. i))) do
			if flyout then
				bar:SetBindingClick(true, key, "FlatUIBar" .. n .. "Button" .. i, "LeftButton")
				routed = routed + 1
			else
				bar:ClearBinding(key)
			end
		end
	end
	bar:SetAttribute("flatui-routed", routed)
end
]=]

local CREATE = [=[
for n = 1, 8 do
	local base = select(n, %s)
	for i = 1, 12 do
		local b = self:GetFrameRef("b" .. n .. "_" .. i)
		b:SetAttribute("type", "none")
		b:SetAttribute("checkselfcast", true)
		b:SetAttribute("checkfocuscast", true)
		b:SetAttribute("checkmouseovercast", true)
		b:SetAttribute("useOnKeyDown", false)
		b:SetAttribute("flyoutDirection", "UP")
		b:SetAttribute("action", base + i)
		b:SetAttribute("type", "action")
	end
end
]=]

local ON_SHOW = [=[
local bar = self:GetFrameRef("bar")
bar:SetAttribute("flatui-game", true)
if bar:GetAttribute("flatui-pb") or bar:GetAttribute("flatui-kb") or bar:GetAttribute("flatui-empty") then
	bar:Hide()
else
	bar:Show()
end
]=]
local ON_HIDE = [=[
local bar = self:GetFrameRef("bar")
bar:SetAttribute("flatui-game", false)
bar:Hide()
]=]
local ON_PETBATTLE = [=[
local pb = tonumber(newstate) == 1
self:SetAttribute("flatui-pb", pb)
if self:GetAttribute("flatui-game") and not pb and not self:GetAttribute("flatui-kb") and not self:GetAttribute("flatui-empty") then
	self:Show()
else
	self:Hide()
end
]=]

local DRAG_START = [=[
if control:GetAttribute("flatui-locked") and not IsModifiedClick("PICKUPACTION") then
	return false
end
return "action", self:GetAttribute("action")
]=]
local DRAG_RECEIVE = [=[
return "action", self:GetAttribute("action")
]=]

local PARK = [=[
for n = 1, 8 do
	self:GetFrameRef("game" .. n):SetAlpha(0)
	for i = 1, 12 do
		self:GetFrameRef("t" .. n .. "_" .. i):EnableMouse(false)
	end
end
self:GetFrameRef("game1"):EnableMouse(false)
]=]

local PAGER_WIRE = [=[
for _, dir in ipairs(newtable("Up", "Down", "Number", "WheelUp", "WheelDown")) do
	local b = self:GetFrameRef("page" .. dir)
	if b then
		b:SetAttribute("useOnKeyDown", dir == "WheelUp" or dir == "WheelDown")
		if dir == "Number" then
			b:SetAttribute("action", 1)
		else
			b:SetAttribute("action", (dir == "Up" or dir == "WheelUp") and "increment" or "decrement")
		end
		b:SetAttribute("type", "actionbar")
	end
end
]=]
local PAGER_WHEEL_ON = [=[
self:SetBindingClick(true, "MOUSEWHEELUP", "FlatUIBar1PageWheelUp", "LeftButton")
self:SetBindingClick(true, "MOUSEWHEELDOWN", "FlatUIBar1PageWheelDown", "LeftButton")
]=]
local PAGER_WHEEL_OFF = [=[
self:ClearBindings()
]=]
local PAGER = {
	{ dir = "Up", key = "UpButton", x = -12.5, y = 36, w = 17, h = 14, atlas = "ui-hud-actionbar-pageuparrow" },
	{ dir = "Down", key = "DownButton", x = -12.5, y = 16, w = 17, h = 14, atlas = "ui-hud-actionbar-pagedownarrow" },
	{ key = "Text", x = -13.5, y = 26, w = 17, h = 10 },
}

local UNPARK = [=[
for n = 1, 8 do
	self:GetFrameRef("game" .. n):SetAlpha(1)
	for i = 1, 12 do
		self:GetFrameRef("t" .. n .. "_" .. i):EnableMouse(true)
	end
end
self:GetFrameRef("game1"):EnableMouse(true)
]=]

local KB_ON = UNPARK .. [=[
for n = 1, 8 do
	local bar = self:GetFrameRef("bar" .. n)
	bar:SetAttribute("flatui-kb", true)
	bar:Hide()
end
]=]
local KB_OFF = PARK .. [=[
for n = 1, 8 do
	local bar = self:GetFrameRef("bar" .. n)
	bar:SetAttribute("flatui-kb", false)
	if bar:GetAttribute("flatui-game") and not bar:GetAttribute("flatui-pb") and not bar:GetAttribute("flatui-empty") then
		bar:Show()
	end
end
]=]

local EMPTY = [=[
do
	local bar = self:GetFrameRef("bar%d")
	bar:SetAttribute("flatui-empty", %s)
	if bar:GetAttribute("flatui-game") and not bar:GetAttribute("flatui-pb") and not bar:GetAttribute("flatui-kb") and not bar:GetAttribute("flatui-empty") then
		bar:Show()
	else
		bar:Hide()
	end
end
]=]

local function Guard(what, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		S.error = S.error or (what .. ": " .. tostring(err))
		geterrorhandler()(err)
	end
	return ok
end

function F.Mode()
	return ns.Get("actionbars.own") == "flat"
end

local function Run(text)
	return S.header:Execute(text)
end

local function Pager()
	local pager = _G.MainActionBar and _G.MainActionBar.ActionBarPageNumber
	return pager and pager.UpButton, pager and pager.DownButton
end

local function Atlas(button, which, atlas)
	local set = button["Set" .. which .. "Atlas"]
	if type(set) == "function" and pcall(set, button, atlas) then
		return
	end
	local texture = button:CreateTexture()
	if pcall(texture.SetAtlas, texture, atlas) then
		button["Set" .. which .. "Texture"](button, texture)
	end
end

function F.Page()
	local get = C_ActionBar and C_ActionBar.GetActionBarPage or _G.GetActionBarPage
	if type(get) ~= "function" then
		return nil
	end
	local ok, page = pcall(get)
	return ok and ns.Finite(page) and page or nil
end

function F.PagerTip(button)
	local tip = GameTooltip
	local pager = S.pager
	if tip == nil or not pager then
		return
	end
	local page = F.Page()
	if rawequal(button, pager.Number) then
		tip:SetOwner(button, "ANCHOR_RIGHT")
		tip:SetText(page and ("Page %d"):format(page) or "Page", 1, 1, 1)
		if page ~= 1 then
			tip:AddLine("Click: back to page 1", 0.8, 0.8, 0.8)
		end
		tip:AddLine("Wheel: change page", 0.8, 0.8, 0.8)
		tip:Show()
		return
	end
	local up = rawequal(button, pager.Up)
	tip:SetOwner(button, "ANCHOR_RIGHT")
	tip:SetText(up and "Next page" or "Previous page", 1, 1, 1)
	if page then
		tip:AddLine(("Page %d"):format(page), 1, 0.82, 0)
	end
	local keys = {}
	if type(GetBindingKey) == "function" and type(GetBindingText) == "function" then
		local short = ns.Enabled("actionbars") and ns.Get("actionbars.hotkeyText") == "short" and type(ns.HotkeyText) == "function"
		local found = { pcall(GetBindingKey, up and "NEXTACTIONPAGE" or "PREVIOUSACTIONPAGE") }
		for index = 2, found[1] == true and math.min(#found, 3) or 1 do
			local key = found[index]
			if type(key) == "string" and not ns.IsSecret(key) and key ~= "" then
				local okText, text = pcall(GetBindingText, key, 1)
				if okText and type(text) == "string" and not ns.IsSecret(text) then
					keys[#keys + 1] = short and ns.HotkeyText(text) or text
				end
			end
		end
	end
	if #keys > 0 then
		tip:AddLine("Key: " .. table.concat(keys, ", "), 0.8, 0.8, 0.8)
	end
	tip:AddLine("Wheel: change page", 0.8, 0.8, 0.8)
	tip:Show()
end

function F.NumberLook(over, down)
	local pager = S.pager
	local text, holder = pager and pager.text, pager and pager.holder
	if not (text and holder) then
		return
	end
	pager.over, pager.down = over == true, over == true and down == true
	local lit = pager.over and F.Page() ~= 1
	if lit then
		text:SetTextColor(1, 1, 1)
	else
		local gold = NORMAL_FONT_COLOR
		local r, g, b = 1, 0.82, 0
		if type(gold) == "table" and ns.Finite(gold.r) and ns.Finite(gold.g) and ns.Finite(gold.b) then
			r, g, b = gold.r, gold.g, gold.b
		end
		text:SetTextColor(r, g, b)
	end
	if lit and not pager.square then
		local square = holder:CreateTexture(nil, "BACKGROUND")
		ns.Own[square] = true
		square:SetAllPoints(holder)
		square:SetColorTexture(1, 1, 1, 0.08)
		pager.square = square
	end
	if pager.square then
		pager.square:SetShown(lit)
	end
	text:ClearAllPoints()
	if lit and pager.down then
		text:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -1)
		text:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, -1)
	else
		text:SetAllPoints(holder)
	end
end

function F.HookNumber(number)
	local pager = S.pager
	if pager.numberHooked then
		return
	end
	pager.numberHooked = true
	number:HookScript("OnEnter", function()
		pcall(F.NumberLook, true, false)
	end)
	number:HookScript("OnLeave", function()
		pcall(F.NumberLook, false, false)
	end)
	number:HookScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			pcall(F.NumberLook, true, true)
		end
	end)
	number:HookScript("OnMouseUp", function()
		pcall(F.NumberLook, pager.over, false)
	end)
end

function F.WrapWheel(button)
	local pager = S.pager
	pager.wrapped = pager.wrapped or {}
	if pager.wrapped[button] then
		return
	end
	pager.wrapped[button] = true
	SecureHandlerWrapScript(button, "OnEnter", S.header, PAGER_WHEEL_ON)
	SecureHandlerWrapScript(button, "OnLeave", S.header, PAGER_WHEEL_OFF)
	SecureHandlerWrapScript(button, "OnHide", S.header, PAGER_WHEEL_OFF)
end

function F.HookPager(button)
	local pager = S.pager
	pager.hooked = pager.hooked or {}
	if pager.hooked[button] then
		return
	end
	pager.hooked[button] = true
	button:HookScript("PreClick", function()
		pager.from = F.Page()
	end)
	button:HookScript("PostClick", function(self)
		if rawequal(self, pager.Number) and pager.from == 1 then
			return
		end
		local sound = SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON
		if sound and type(PlaySound) == "function" then
			pcall(PlaySound, sound)
		end
	end)
	button:HookScript("OnEnter", function(self)
		pcall(F.PagerTip, self)
	end)
	button:HookScript("OnLeave", function(self)
		local tip = GameTooltip
		if tip ~= nil then
			local ok, owner = pcall(tip.GetOwner, tip)
			if ok and not ns.IsSecret(owner) and rawequal(owner, self) then
				pcall(tip.Hide, tip)
			end
		end
	end)
end

function F.MakePager()
	local bar = S.bars[1]
	local pager = S.pager or {}
	S.pager = pager
	for _, def in ipairs(PAGER) do
		if def.dir then
			local name = "FlatUIBar1Page" .. def.dir
			local button = _G[name] or CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
			button:RegisterForClicks("LeftButtonUp")
			button:SetSize(def.w, def.h)
			button:SetFrameLevel(bar:GetFrameLevel() + 10)
			Atlas(button, "Normal", def.atlas .. "-up")
			Atlas(button, "Pushed", def.atlas .. "-down")
			Atlas(button, "Highlight", def.atlas .. "-mouseover")
			button:Hide()
			pager[def.dir] = button
			F.WrapWheel(button)
			F.HookPager(button)
			S.header:SetFrameRef("page" .. def.dir, button)
		end
	end
	for _, dir in ipairs({ "WheelUp", "WheelDown" }) do
		local name = "FlatUIBar1Page" .. dir
		local button = _G[name] or CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
		button:RegisterForClicks("AnyDown")
		button:EnableMouse(false)
		button:SetSize(1, 1)
		pager[dir] = button
		F.HookPager(button)
		S.header:SetFrameRef("page" .. dir, button)
	end
	if not pager.holder then
		local holder = CreateFrame("Frame", nil, bar)
		ns.Own[holder] = true
		holder:SetFrameLevel(bar:GetFrameLevel() + 10)
		local text = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetAllPoints(holder)
		text:SetJustifyH("CENTER")
		holder:Hide()
		pager.holder, pager.text = holder, text
	end
	local name = "FlatUIBar1PageNumber"
	local number = _G[name] or CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
	number:RegisterForClicks("LeftButtonUp")
	number:SetFrameLevel(bar:GetFrameLevel() + 9)
	number:Hide()
	pager.Number = number
	F.WrapWheel(number)
	F.HookPager(number)
	F.HookNumber(number)
	S.header:SetFrameRef("pageNumber", number)
end

function F.Make()
	local header = _G.FlatUIOwnHeader or CreateFrame("Frame", "FlatUIOwnHeader", UIParent, "SecureHandlerBaseTemplate")
	S.header = header
	header:Hide()
	for n = 1, 8 do
		local def = BAR[n]
		local game, first = _G[def.game], _G[def.twin .. 1]
		if not (game and first) then
			error("the game's " .. def.game .. " is missing")
		end
		local name = "FlatUIBar" .. n
		local bar = _G[name] or CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
		bar:SetFrameStrata("MEDIUM")
		pcall(function() bar:SetClampedToScreen(true) end)
		S.bars[n] = bar
		S.grid[n] = {}
		header:SetFrameRef("bar" .. n, bar)
		header:SetFrameRef("game" .. n, game)
		for i = 1, 12 do
			local bname = name .. "Button" .. i
			local button = _G[bname] or CreateFrame("CheckButton", bname, bar, "ActionButtonTemplate, SecureActionButtonTemplate")
			button:RegisterForClicks("AnyUp")
			button:RegisterForDrag("LeftButton", "RightButton")
			S.info[button] = { n, i }
			S.buttons[#S.buttons + 1] = button
			S.grid[n][i] = button
			bar:SetFrameRef("b" .. i, button)
			header:SetFrameRef("b" .. n .. "_" .. i, button)
			header:SetFrameRef("t" .. n .. "_" .. i, _G[def.twin .. i])
		end
		local container = first.container or first:GetParent()
		local watcher = CreateFrame("Frame", nil, container, "SecureHandlerShowHideTemplate")
		watcher:SetSize(1, 1)
		watcher:SetPoint("CENTER", container, "CENTER")
		watcher:SetFrameRef("bar", bar)
		S.watchers[n] = watcher
		header:SetFrameRef("w" .. n, watcher)
	end
	F.MakePager()
end

function F.Wire()
	local bases = {}
	for n = 1, 8 do
		bases[n] = BAR[n].base
	end
	Run(CREATE:format(table.concat(bases, ", ")))
	for n = 1, 8 do
		S.watchers[n]:SetAttribute("_onshow", ON_SHOW)
		S.watchers[n]:SetAttribute("_onhide", ON_HIDE)
		S.bars[n]:SetAttribute("_onstate-petbattle", ON_PETBATTLE)
	end
	S.bars[1]:SetAttribute("_onstate-page", PAGE_STATE)
	local text = {}
	for n = 1, 8 do
		text[#text + 1] = ("do local bar = self:GetFrameRef('bar%d') local w = self:GetFrameRef('w%d')\n"
			.. "bar:SetAttribute('flatui-game', w:IsVisible()) bar:SetAttribute('flatui-pb', false) end"):format(n, n)
	end
	Run(table.concat(text, "\n"))
	for n = 1, 8 do
		for i = 1, 12 do
			SecureHandlerWrapScript(S.grid[n][i], "OnDragStart", S.header, DRAG_START)
			SecureHandlerWrapScript(S.grid[n][i], "OnReceiveDrag", S.header, DRAG_RECEIVE)
		end
		RegisterStateDriver(S.bars[n], "petbattle", "[petbattle] 1; 0")
	end
	RegisterStateDriver(S.bars[1], "page", PAGE_VALUE)
	Run(PAGER_WIRE)
end

local function Rect(frame)
	local ok, l, b, w, h = pcall(frame.GetRect, frame)
	if not ok or not (ns.Finite(l) and ns.Finite(b) and ns.Finite(w) and ns.Finite(h)) or w <= 0 or h <= 0 then
		return nil
	end
	local e = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return l * e, b * e, w * e, h * e
end

local function ScreenSize()
	local scale = UIParent:GetEffectiveScale()
	if type(GetPhysicalScreenSize) == "function" and type(scale) == "number" and scale > 0 then
		local ok, pw, ph = pcall(GetPhysicalScreenSize)
		if ok and type(pw) == "number" and type(ph) == "number" and pw > 0 and ph > 0 then
			return pw / scale, ph / scale
		end
	end
	return UIParent:GetWidth(), UIParent:GetHeight()
end

local function Direction(l, b, w, h, count)
	local sw, sh = ScreenSize()
	local cx, cy = l + w / 2, b + h / 2
	if count > 1 and h > w * 1.5 then
		return cx < sw / 2 and "RIGHT" or "LEFT"
	end
	return cy < sh / 2 and "UP" or "DOWN"
end

local function Count(n)
	local def = BAR[n]
	local game = _G[def.game]
	local count = game.numButtonsShowable
	if type(count) ~= "number" then
		count = 0
		for i = 1, 12 do
			local twin = _G[def.twin .. i]
			local container = twin.container or twin:GetParent()
			if container and container:IsShown() then
				count = count + 1
			end
		end
	end
	return math.max(0, math.min(12, count))
end

function F.Layout()
	local run = {}
	for n = 1, 8 do
		local def = BAR[n]
		local bl, bb, bw, bh = Rect(_G[def.game])
		S.rect[n] = bl and { bl, bb, bw, bh } or nil
		if bl then
			local count = Count(n)
			local dir = Direction(bl, bb, bw, bh, count)
			local t = { ("do local bar = self:GetFrameRef('bar%d') local b"):format(n),
				("bar:ClearAllPoints() bar:SetPoint('BOTTOMLEFT', '$parent', 'BOTTOMLEFT', %.3f, %.3f) bar:SetWidth(%.3f) bar:SetHeight(%.3f)"):format(bl, bb, bw, bh) }
			for i = 1, 12 do
				t[#t + 1] = ("b = bar:GetFrameRef('b%d')"):format(i)
				if i <= count then
					local twin = _G[def.twin .. i]
					local cl, cb, cw = Rect(twin.container or twin:GetParent())
					if cl then
						t[#t + 1] = ("b:ClearAllPoints() b:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', %.3f, %.3f) b:SetWidth(%.3f) b:SetHeight(%.3f) b:Show()"):format(cl - bl, cb - bb, cw, cw)
					else
						t[#t + 1] = "b:Show()"
					end
				else
					t[#t + 1] = "b:Hide()"
				end
				t[#t + 1] = ("if b:GetAttribute('flyoutDirection') ~= '%s' then b:SetAttribute('flyoutDirection', '%s') end"):format(dir, dir)
			end
			t[#t + 1] = "end"
			local text = table.concat(t, "\n")
			if S.chunk[n] ~= text then
				S.chunk[n] = text
				run[#run + 1] = text
			end
		end
	end
	if #run > 0 then
		Run(table.concat(run, "\n"))
		S.flag.empty = true
	end
	local ok, err = pcall(F.Pager)
	S.pagerError = not ok and tostring(err) or nil
end

local POP_FROM, POP_TIME = 1.4, 0.25
function F.PagePop(pager)
	if not pager.pop then
		local group = pager.holder:CreateAnimationGroup()
		ns.Own[group] = true
		local scale = group:CreateAnimation("Scale")
		ns.Own[scale] = true
		scale:SetScaleFrom(POP_FROM, POP_FROM)
		scale:SetScaleTo(1, 1)
		scale:SetDuration(POP_TIME)
		scale:SetSmoothing("OUT")
		scale:SetOrigin("CENTER", 0, 0)
		pager.pop = group
	end
	pager.pop:Stop()
	pager.pop:Play()
end

function F.PageText()
	local pager = S.pager
	local get = C_ActionBar and C_ActionBar.GetActionBarPage or _G.GetActionBarPage
	if not (pager and pager.text) or type(get) ~= "function" then
		return
	end
	local ok, page = pcall(get)
	if ok and ns.Finite(page) and page ~= pager.page then
		local known = pager.page ~= nil
		pager.page = page
		pager.text:SetText(page)
		if pager.over then
			pcall(F.NumberLook, true, pager.down)
		end
		if known then
			pcall(F.PagePop, pager)
			local tip = GameTooltip
			local okShown, shown = false, nil
			if tip ~= nil then
				okShown, shown = pcall(tip.IsShown, tip)
			end
			if okShown and not ns.IsSecret(shown) and shown == true then
				local okOwner, owner = pcall(tip.GetOwner, tip)
				if okOwner and not ns.IsSecret(owner) and (rawequal(owner, pager.Up) or rawequal(owner, pager.Down) or rawequal(owner, pager.Number)) then
					pcall(F.PagerTip, owner)
				end
			end
		end
	end
end

function F.Pager()
	local pager = S.pager
	if not pager then
		return
	end
	local base = S.rect[1]
	local game = _G.MainActionBar and _G.MainActionBar.ActionBarPageNumber
	local show = base ~= nil and ns.Get("actionbars.pageArrows") == true
	if show and game then
		local ok, shown = pcall(game.IsShown, game)
		show = ok and not ns.IsSecret(shown) and shown == true
	end
	local t = { "local bar = self:GetFrameRef('bar1') local p" }
	for _, def in ipairs(PAGER) do
		local x, y, w, h = def.x, def.y, def.w, def.h
		local part = show and game and game[def.key]
		if part then
			local l, b, pw, ph = Rect(part)
			if l then
				x, y, w, h = l + pw / 2 - base[1], b + ph / 2 - base[2], pw, ph
			end
		end
		if def.dir then
			t[#t + 1] = ("p = self:GetFrameRef('page%s')"):format(def.dir)
			if show then
				t[#t + 1] = ("p:ClearAllPoints() p:SetPoint('CENTER', bar, 'BOTTOMLEFT', %.3f, %.3f) p:SetWidth(%.3f) p:SetHeight(%.3f) p:Show()"):format(x, y, w, h)
			else
				t[#t + 1] = "p:Hide()"
			end
		elseif show then
			local scale = h / def.h
			scale = ns.Finite(scale) and scale > 0.2 and scale or 1
			pager.holder:SetScale(scale)
			pager.holder:SetSize(def.w, def.h)
			pager.holder:ClearAllPoints()
			pager.holder:SetPoint("CENTER", S.bars[1], "BOTTOMLEFT", x / scale, y / scale)
			t[#t + 1] = ("p = self:GetFrameRef('pageNumber') if p then p:ClearAllPoints() p:SetPoint('CENTER', bar, 'BOTTOMLEFT', %.3f, %.3f) "
				.. "p:SetWidth(%.3f) p:SetHeight(%.3f) p:Show() end"):format(x, y, def.w * scale, h)
		else
			t[#t + 1] = "p = self:GetFrameRef('pageNumber') if p then p:Hide() end"
		end
	end
	local text = table.concat(t, "\n")
	if S.chunk.pager ~= text then
		S.chunk.pager = text
		Run(text)
	end
	pager.holder:SetShown(show)
	if show then
		F.PageText()
	end
	if type(ns.BarBlockPanels) == "function" then
		ns.BarBlockPanels()
	end
end

function F.Moved()
	for n = 1, 8 do
		local was = S.rect[n]
		local l, b, w, h = Rect(_G[BAR[n].game])
		if l and not (was and math.abs(was[1] - l) <= 0.5 and math.abs(was[2] - b) <= 0.5 and math.abs(was[3] - w) <= 0.5
			and math.abs(was[4] - h) <= 0.5) then
			return true
		end
	end
	return false
end

function F.Park()
	Run(PARK)
	for _, button in pairs({ Pager() }) do
		button:EnableMouse(false)
	end
	local leave = _G.MainMenuBarVehicleLeaveButton
	if leave and not leave:IsIgnoringParentAlpha() then
		leave:SetIgnoreParentAlpha(true)
	end
	S.parked = true
end

function F.UpkeepAlpha()
	if S.kbHeld then
		return
	end
	for n = 1, 8 do
		local game = _G[BAR[n].game]
		if game:GetAlpha() ~= 0 then
			game:SetAlpha(0)
			S.putBack = S.putBack + 1
		end
	end
end

function F.Upkeep()
	if S.kbHeld then
		return
	end
	F.UpkeepAlpha()
	local t = {}
	local main = _G.MainActionBar
	if main:IsMouseEnabled() then
		t[#t + 1] = "self:GetFrameRef('game1'):EnableMouse(false)"
	end
	for n = 1, 8 do
		for i = 1, 12 do
			if _G[BAR[n].twin .. i]:IsMouseEnabled() then
				t[#t + 1] = ("self:GetFrameRef('t%d_%d'):EnableMouse(false)"):format(n, i)
			end
		end
	end
	if #t > 0 then
		S.putBack = S.putBack + #t
		Run(table.concat(t, "\n"))
	end
	for _, button in pairs({ Pager() }) do
		if button:IsMouseEnabled() then
			button:EnableMouse(false)
			S.putBack = S.putBack + 1
		end
	end
	local leave = _G.MainMenuBarVehicleLeaveButton
	if leave and not leave:IsIgnoringParentAlpha() then
		leave:SetIgnoreParentAlpha(true)
		S.putBack = S.putBack + 1
	end
end

function F.Revert()
	if InCombatLockdown() then
		S.flag.revert = true
		return
	end
	S.flag.revert = false
	if not S.parked then
		return
	end
	S.parked, S.kbHeld = false, false
	Run(UNPARK)
	for _, button in pairs({ Pager() }) do
		if not button:IsMouseEnabled() then
			button:EnableMouse(true)
		end
	end
	local leave = _G.MainMenuBarVehicleLeaveButton
	if leave and leave:IsIgnoringParentAlpha() then
		leave:SetIgnoreParentAlpha(false)
	end
end

function F.Resync()
	Run(PAGE_EXEC)
end

function F.Keys()
	local cmds = {}
	for n = 2, 8 do
		cmds[#cmds + 1] = ("%q"):format(BAR[n].cmd)
	end
	Run(PAGE_EXEC .. ROUTE:format(table.concat(cmds, ", ")))
end

function F.Lock()
	local locked = GetCVarBool("lockActionBars") and true or false
	if S.locked ~= locked then
		S.locked = locked
		Run(("self:SetAttribute('flatui-locked', %s)"):format(tostring(locked)))
	end
end

function F.Busy(edit)
	if edit then
		return true
	end
	if type(GetCursorInfo) == "function" then
		local ok, kind = pcall(GetCursorInfo)
		if ok and (ns.IsSecret(kind) or kind ~= nil) then
			return true
		end
	end
	local kit = ns.MoverKit
	if type(kit) == "table" and type(kit.IsOpen) == "function" then
		local ok, open = pcall(kit.IsOpen)
		return ok and open == true
	end
	return false
end

function F.Bare(n)
	local has = C_ActionBar and C_ActionBar.HasAction or _G.HasAction
	local count = Count(n)
	if type(has) ~= "function" or count < 1 then
		return false
	end
	for i = 1, count do
		local slot = S.grid[n][i]:GetAttribute("action")
		if type(slot) ~= "number" then
			return false
		end
		local ok, there = pcall(has, slot)
		if not ok or ns.IsSecret(there) or there then
			return false
		end
	end
	return true
end

function F.Empty()
	local on = ns.Get("actionbars.emptyBars") == true and not F.Busy(S.editWas)
	local t = {}
	for n = 2, 8 do
		local hide = on and F.Bare(n) or false
		if (S.emptySet[n] == true) ~= hide then
			S.emptySet[n] = hide
			t[#t + 1] = EMPTY:format(n, tostring(hide))
		end
	end
	if #t > 0 then
		Run(table.concat(t, "\n"))
	end
end

function F.Missing()
	local last = S.grid[8] and S.grid[8][12]
	if not last or last:GetAttribute("type") ~= "action" or last:GetAttribute("action") ~= BAR[8].base + 12 then
		return "FlatUIBar8Button12 has no action"
	end
	if not S.bars[1] or S.bars[1]:GetAttribute("flatui-page") == nil then
		return "FlatUIBar1 has no page"
	end
	if not S.bars[8] or S.bars[8]:GetAttribute("flatui-routed") == nil then
		return "FlatUIBar8 has no key routing"
	end
	if S.header:GetAttribute("flatui-locked") == nil then
		return "the lock state is not set"
	end
	return nil
end

local DOWN = [=[
for n = 1, 8 do
	local bar = self:GetFrameRef("bar" .. n)
	if bar then
		bar:Hide()
		bar:ClearBindings()
	end
end
]=]

function F.Down()
	if InCombatLockdown() then
		return
	end
	for n = 1, 8 do
		local bar, watcher = S.bars[n], S.watchers[n]
		if bar then
			pcall(UnregisterStateDriver, bar, "petbattle")
		end
		if watcher then
			watcher:SetAttribute("_onshow", nil)
			watcher:SetAttribute("_onhide", nil)
		end
	end
	if S.bars[1] then
		pcall(UnregisterStateDriver, S.bars[1], "page")
	end
	if S.header then
		pcall(Run, DOWN)
	end
end

function F.Build()
	if S.built or S.busy or S.error then
		return
	end
	S.busy = true
	local ok = Guard("build", function()
		F.Make()
		F.Wire()
		F.Layout()
		F.Keys()
		F.Lock()
		F.Park()
		local missing = F.Missing()
		if missing then
			error(missing, 0)
		end
	end)
	S.busy = false
	S.pending = false
	if not ok then
		print("Flat UI: Action buttons could not be built. /flatui status shows why.")
		pcall(F.Down)
		if S.parked then
			pcall(F.Revert)
		end
		if type(ns.OwnButtonsChanged) == "function" then
			pcall(ns.OwnButtonsChanged)
		end
		return
	end
	S.built = true
	S.flag.revert = false
	S.flag.empty = true
	for n = 1, 12 do
		S.slots[n] = S.grid[1][n]:GetAttribute("action")
	end
	for _, fn in ipairs(S.builtListeners) do
		Guard("listener", fn)
	end
end

function F.KeybindSeen(open)
	open = open == true
	if open == S.kbWant then
		return
	end
	S.kbWant = open
	if not open then
		S.kbTold = false
	elseif S.built and InCombatLockdown() then
		S.kbTold = true
		print("Flat UI: the game's action buttons show for Quick Keybind Mode when combat ends.")
	end
end

function F.Keybind()
	local want = S.kbWant and S.parked and not S.fight
	if want and not S.kbHeld then
		S.kbHeld = true
		Run(KB_ON)
		if not S.kbTold then
			S.kbTold = true
			print("Flat UI: the game's action buttons show while Quick Keybind Mode is open.")
		end
	elseif not want and S.kbHeld then
		F.KeybindEnd()
	end
end

function F.KeybindEnd()
	if S.kbHeld and not InCombatLockdown() then
		S.kbHeld = false
		Run(KB_OFF)
	end
end

function F.Process()
	if S.busy or S.error or InCombatLockdown() then
		return
	end
	local fl = S.flag
	if not F.Mode() then
		if fl.revert then
			F.Revert()
		end
		return
	end
	if not S.built then
		if S.pending then
			F.Build()
		end
		return
	end
	if fl.upkeep then
		fl.upkeep = false
		F.Upkeep()
	end
	if fl.lock then
		fl.lock = false
		F.Lock()
	end
	if fl.layout then
		fl.layout = false
		F.Layout()
	end
	if fl.empty then
		fl.empty = false
		F.Empty()
	end
	if fl.keys then
		fl.keys, fl.resync = false, false
		F.Keys()
	elseif fl.resync then
		fl.resync = false
		F.Resync()
	end
	if S.kbHeld ~= (S.kbWant and not S.fight) then
		F.Keybind()
	end
end

function F.Watch()
	local manager = _G.EditModeManagerFrame
	local active = false
	if manager and manager.IsEditModeActive then
		local ok, answer = pcall(manager.IsEditModeActive, manager)
		active = ok and answer == true
	end
	if active or S.editWas then
		S.flag.layout = true
	end
	S.editWas = active
	if not S.built then
		return
	end
	local busy, on = F.Busy(active), ns.Get("actionbars.emptyBars") == true
	if busy ~= S.emptyBusy or on ~= S.emptyOn then
		S.emptyBusy, S.emptyOn = busy, on
		S.flag.empty = true
	end
	if type(KeybindFrames_InQuickKeybindMode) == "function" then
		local ok, open = pcall(KeybindFrames_InQuickKeybindMode)
		F.KeybindSeen(ok and not ns.IsSecret(open) and open and true or false)
	end
	S.rectClock = S.rectClock + 0.1
	if S.rectClock >= 0.5 and not InCombatLockdown() then
		S.rectClock = 0
		if F.Moved() then
			S.flag.layout = true
		end
	end
	local changed = false
	for i = 1, 12 do
		local slot = S.grid[1][i]:GetAttribute("action")
		if slot ~= S.slots[i] then
			S.slots[i], changed = slot, true
		end
	end
	if changed then
		F.PageText()
		for _, fn in ipairs(S.slotListeners) do
			Guard("listener", fn)
		end
	end
end

function F.Update(_, elapsed)
	F.Process()
	S.clock = S.clock + (elapsed or 0)
	if S.clock >= 0.1 then
		S.clock = 0
		Guard("watch", F.Watch)
		F.Process()
	end
end

local ALPHA = { UPDATE_BONUS_ACTIONBAR = true, UPDATE_OVERRIDE_ACTIONBAR = true, UPDATE_VEHICLE_ACTIONBAR = true, EDIT_MODE_LAYOUTS_UPDATED = true,
	PLAYER_ENTERING_WORLD = true }
local RESYNC = { ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, UPDATE_VEHICLE_ACTIONBAR = true, UPDATE_OVERRIDE_ACTIONBAR = true,
	UPDATE_SHAPESHIFT_FORM = true, PLAYER_ENTERING_WORLD = true }

function F.Event(event, name)
	local fl = S.flag
	if event == "PLAYER_LOGIN" then
		if not F.Mode() then
			return
		end
		F.Listen()
		S.pending = true
		if InCombatLockdown() then
			print("Flat UI: Action buttons are built when combat ends.")
		else
			F.Build()
		end
		return
	end
	if not F.Mode() then
		if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
			fl.revert = true
			F.Process()
		end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		S.fight = false
		S.pagerTold, S.emptyTold = nil, nil
		if S.built then
			fl.upkeep, fl.lock = true, true
		end
		F.Process()
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		S.fight = true
		local held = S.kbHeld
		F.KeybindEnd()
		if held and not S.kbHeld then
			print("Flat UI: your action buttons are back for the fight; the game's show again for Quick Keybind Mode when it ends.")
		elseif held then
			print("Flat UI: the game's action buttons stay for this fight; Flat UI's come back after it.")
		end
		return
	end
	if not S.built then
		return
	end
	if ALPHA[event] then
		F.UpkeepAlpha()
		fl.upkeep = true
	end
	if RESYNC[event] then
		fl.resync = true
	end
	if event == "ACTIONBAR_PAGE_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
		F.PageText()
	end
	if event == "PLAYER_ENTERING_WORLD" then
		fl.layout, fl.lock, fl.keys, fl.empty = true, true, true, true
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		fl.keys, fl.empty = true, true
	elseif event == "UPDATE_BINDINGS" then
		fl.keys = true
	elseif event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" or event == "CURSOR_CHANGED" then
		S.emptyBusy = F.Busy(S.editWas)
		fl.empty = true
	elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		fl.layout = true
	elseif event == "CVAR_UPDATE" and type(name) == "string" and name:lower() == "lockactionbars" then
		fl.lock = true
	end
end

local frame = CreateFrame("Frame")
local LATER = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS",
	"EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "CURSOR_CHANGED" }
function F.Listen()
	if S.listening then
		return
	end
	S.listening = true
	for _, event in ipairs(LATER) do
		pcall(frame.RegisterEvent, frame, event)
	end
	frame:SetScript("OnUpdate", function(...)
		Guard("update", F.Update, ...)
	end)
	if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
		pcall(EventRegistry.RegisterCallback, EventRegistry, "QuickKeybindFrame.QuickKeybindModeEnabled", function()
			Guard("keybind", F.KeybindSeen, true)
		end, S.kbOwner)
		pcall(EventRegistry.RegisterCallback, EventRegistry, "QuickKeybindFrame.QuickKeybindModeDisabled", function()
			Guard("keybind", F.KeybindSeen, false)
		end, S.kbOwner)
	end
end
pcall(frame.RegisterEvent, frame, "PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
	Guard(event, F.Event, event, ...)
end)

function ns.OwnOn()
	return S.built == true
end

function ns.OwnWanted()
	return F.Mode() and not S.error
end

function ns.OwnButtonsChosen()
	return ns.OwnWanted() == true
end

function ns.OwnMissing()
	return F.Missing()
end

function ns.OwnButtons()
	return S.buttons
end

function ns.OwnBar(button)
	local info = type(button) == "table" and S.info[button]
	if info then
		return info[1], info[2]
	end
end

function ns.OwnBarFrame(n)
	return S.bars[n]
end

function ns.OwnBarOf(name)
	if not S.built then
		return nil
	end
	for n = 1, 8 do
		if BAR[n].game == name then
			return S.bars[n]
		end
	end
	return nil
end

function ns.OwnPagerOver()
	local pager = S.pager
	if not (S.built and pager) then
		return false
	end
	for _, dir in ipairs({ "Up", "Down", "Number" }) do
		local button = pager[dir]
		if button then
			local okShown, shown = pcall(button.IsVisible, button)
			if okShown and not ns.IsSecret(shown) and shown == true then
				local okOver, over = pcall(button.IsMouseOver, button)
				if okOver and (ns.IsSecret(over) or over == true) then
					return true
				end
			end
		end
	end
	return false
end

function ns.OwnPagerRect()
	local pager = S.pager
	if not (S.built and pager and pager.holder) then
		return nil
	end
	local okShown, shown = pcall(pager.holder.IsVisible, pager.holder)
	if not okShown or ns.IsSecret(shown) or shown ~= true then
		return nil
	end
	local left, bottom, right, top
	for _, part in ipairs({ pager.Up, pager.Down, pager.holder }) do
		local l, b, w, h = nil, nil, nil, nil
		if part then
			l, b, w, h = Rect(part)
		end
		if l then
			left, bottom = math.min(left or l, l), math.min(bottom or b, b)
			right, top = math.max(right or (l + w), l + w), math.max(top or (b + h), b + h)
		end
	end
	if left then
		return left, bottom, right, top
	end
	return nil
end

function ns.OwnPagerChanged()
	local want = ns.Get("actionbars.pageArrows") == true
	local was = S.pagerWant
	S.pagerWant = want
	if S.built then
		S.chunk.pager = nil
		S.flag.layout = true
		if was ~= nil and was ~= want and InCombatLockdown() and not S.pagerTold and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
			S.pagerTold = true
			print(want and "Flat UI: the page arrows show when the fight ends." or "Flat UI: the page arrows go when the fight ends.")
		end
	end
end

function ns.OwnEmptyChanged()
	if not S.built then
		return
	end
	S.flag.empty = true
	if InCombatLockdown() and not S.emptyTold and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
		S.emptyTold = true
		print(ns.Get("actionbars.emptyBars") == true and "Flat UI: empty bars hide when the fight ends." or "Flat UI: empty bars show again when the fight ends.")
	end
end

function ns.OwnRelayout()
	if S.built then
		S.flag.layout = true
		S.rectClock = 0.5
	end
end

function ns.OwnSlot(button)
	if type(button) == "table" and S.info[button] then
		return button:GetAttribute("action")
	end
end

function ns.OwnTwin(button)
	local info = type(button) == "table" and S.info[button]
	if info then
		return _G[BAR[info[1]].twin .. info[2]]
	end
end

function ns.OwnCommand(button)
	local info = type(button) == "table" and S.info[button]
	if info then
		return BAR[info[1]].cmd .. info[2]
	end
end

function ns.OnOwnSlots(fn)
	if type(fn) == "function" then
		S.slotListeners[#S.slotListeners + 1] = fn
	end
end

function ns.OnOwnBuilt(fn)
	if type(fn) ~= "function" then
		return
	end
	if S.built then
		Guard("listener", fn)
	else
		S.builtListeners[#S.builtListeners + 1] = fn
	end
end

function ns.OwnPage()
	if not S.built then
		return nil
	end
	local main = _G.MainActionBar
	return S.bars[1]:GetAttribute("flatui-page"), main and main:GetAttribute("actionpage")
end

function ns.OwnStatus(id)
	if id == "buttons" then
		if not F.Mode() then
			return "Action buttons: the game's."
		elseif S.error then
			return "Action buttons: stopped. " .. S.error
		elseif S.built then
			return "Action buttons: Flat UI's, 96 on 8 bars."
		end
		return nil
	elseif id == "waiting" then
		if F.Mode() and S.pending and not S.built and not S.error then
			return "Action buttons: Flat UI's buttons are built when combat ends."
		end
		return nil
	elseif id == "taint" then
		return F.Mode() and S.built and ns.TaintOwnLine and ns.TaintOwnLine() or nil
	end
	if not (S.built and F.Mode()) then
		return nil
	end
	if id == "page" then
		local flat, game = ns.OwnPage()
		local main = _G.MainActionBar
		if flat and game and not InCombatLockdown() and main:IsShown() then
			return ("Main bar page: %d, the game's %d."):format(flat, game) .. (S.pagerError and (" Page arrows: " .. S.pagerError) or "")
		end
	elseif id == "keys" then
		return "Key presses: through the game's buttons."
	elseif id == "flyoutkeys" then
		local count = 0
		for n = 1, 8 do
			count = count + (tonumber(S.bars[n]:GetAttribute("flatui-routed")) or 0)
		end
		if count > 0 then
			return ("Keys on flyout slots: sent to Flat UI's buttons, %d %s."):format(count, count == 1 and "key" or "keys")
		end
	elseif id == "parked" then
		if S.kbHeld then
			return "Game bars 1 to 8: shown for Quick Keybind Mode; Flat UI's come back when it closes."
		end
		local line = "Game bars 1 to 8: hidden."
		if S.putBack > 0 then
			line = line .. (" The game showed them again %d %s this session."):format(S.putBack, S.putBack == 1 and "time" or "times")
		end
		return line
	elseif id == "leave" then
		local leave = _G.MainMenuBarVehicleLeaveButton
		if leave and leave:IsIgnoringParentAlpha() then
			return "Vehicle leave button: shown without the main bar."
		end
	elseif id == "totem" then
		local extra, totem = _G.ExtraActionBarFrame, _G.MultiCastActionBarFrame
		if (extra and extra:IsShown()) or (totem and totem:IsShown()) then
			return "Totem and extra action buttons are the game's. A click on them can still be refused."
		end
	end
end
