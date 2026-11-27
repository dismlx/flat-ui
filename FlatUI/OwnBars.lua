local _, ns = ...

-- Flat UI's own action buttons, piece B: eight bars of twelve secure buttons, the paging of the main bar, the parking of the game's bars, the layout
-- copied from the game's bars and the keys that open flyouts. The design is research/own-buttons/design.md (sections 2 to 5, 7 and 10).
--
-- A Flat UI button is a CheckButton of ActionButtonTemplate, SecureActionButtonTemplate. It runs the template's OnLoad and nothing of the game's
-- button code. This file writes no field on a button, a bar or a watcher: what it keeps is in tables, and every attribute is set by secure code (a
-- header's Execute, a state driver, a handle). The game's bars stay shown and laid out at alpha 0 with the mouse off, so every key still reaches
-- the game's own buttons, which keep their page from the game's own controller. Nothing is hooked, nothing of the game's is hidden, moved,
-- reparented or given an attribute. All of it runs only while Action buttons (actionbars.own) is Flat UI's.
-- The layout follows the game's bars: at login, on an Edit Mode or UI scale change, and every half second out of combat when the rectangle of a
-- game bar moved since the last layout, as /flatui move, the bar block (ns.OwnRelayout) and a tab dragged in /flatui move place a bar with a
-- snippet that fires no event.
-- Page arrows on the main bar (actionbars.pageArrows, on by default): the game's page number and arrows sit at alpha 0 with the parked main bar, so
-- Flat UI's bar 1 has its own beside it, where the game puts them (MainActionBar.xml:93-140): two secure buttons of the game's paging action
-- (type actionbar, action increment or decrement, SECURE_ACTIONS.actionbar in SecureTemplates.lua:322-339), which page the bar in a fight too, and
-- between them the page number (C_ActionBar.GetActionBarPage, as MainActionBar.lua:11 and 57 write it), a font string of Flat UI's own set again
-- as the page changes, which pops (its holder scales from 140% back to full over 0.25 s, in a fight too) at each change after the first, while an
-- arrow's tooltip that is up is drawn again with the new page. They are children of FlatUIBar1, so they move, hide and fade with it; they take the
-- place and size of the game's own, read at each layout, and show while the row is on and the game's page number is shown, which Edit Mode's
-- Hide bar scrolling turns off (EditModeSystemTemplates.lua:1129-1130), read only. They are placed and shown out of combat, the buttons by the
-- header. They page on the left button only, play the game's scroll click as they page (SOUNDKIT.U_CHAT_SCROLL_BUTTON, as
-- MainActionBar.lua:164-182), and say in a tooltip which way they page, the page you are on and the key of that command (NEXTACTIONPAGE,
-- PREVIOUSACTIONPAGE, short as the hotkeys are with Hotkey text at Short): hooks of Flat UI's own buttons (HookScript), which only play the sound
-- and draw the tooltip. The page number is a third secure button of the same action (FlatUIBar1PageNumber, action 1) under the number, so a left
-- click on it goes back to page 1, in a fight too, with the same click sound unless it was on page 1 already, and its tooltip says the page and,
-- past page 1, "Click: back to page 1". A change of profile reaches the row through ActionBars.lua's Refresh (ns.OwnPagerChanged); the mouse over a
-- shown arrow or the number counts as over the main bar for Fading and the bar block (ns.OwnPagerOver).
-- Quick Keybind Mode (the game's Key Bindings) works on the game's own buttons: while it is open the game's eight bars are given back where they
-- are (alpha 1, the mouse on) and Flat UI's are hidden, out of combat; as it closes, or just before a fight starts, the game's bars are parked
-- again and Flat UI's shown. A mode opened in a fight waits for its end. A fight that starts while the mode is open says so in one chat line: Flat
-- UI's buttons are back for the fight and the game's show again when it ends, or, when the lockdown came first, that the game's stay for the fight.

-- Flat UI bar n: the game bar and its buttons, the key command of the buttons, the slot before the first one.
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

-- What the state of this file is, in tables so that no function holds many upvalues.
local S = {
	built = false, pending = false, busy = false, error = nil, header = nil,
	bars = {}, buttons = {}, grid = {}, watchers = {}, parked = false,
	-- bar and index by button
	info = setmetatable({}, { __mode = "k" }),
	flag = {}, clock = 0, putBack = 0,
	-- what was last laid out, by bar
	chunk = {},
	-- the twelve slots of the main bar last seen by the watch
	slots = {},
	slotListeners = {}, builtListeners = {},
	editWas = false,
	-- the game bars' rectangles at the last layout, and the time since they were last compared
	rect = {}, rectClock = 0,
	-- Quick Keybind Mode: open (kbWant), the game's bars given back for it (kbHeld), the line printed for this opening (kbTold), between
	-- PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED (fight), and the owner of its two callbacks
	kbWant = false, kbHeld = false, kbTold = false, fight = false, kbOwner = {},
}
local F = {}

-- The restricted code. PAGE runs with `bar` as the main bar's handle: the page the game's own controller computes (ActionBarController.lua:159-171),
-- the slot of each button, and the keys of the slots that hold a flyout sent to Flat UI's button, as a click (the others cleared).
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

-- The value of the page driver only has to change when the page does: a bonus bar counts only on page 1, as the game's formula does.
local PAGE_VALUE = "[vehicleui] v; [overridebar] o; [possessbar] p; [shapeshift] s; [bonusbar:5,bar:1] b5; [bonusbar:4,bar:1] b4; [bonusbar:3,bar:1] b3; "
	.. "[bonusbar:2,bar:1] b2; [bonusbar:1,bar:1] b1; [bar:6] 6; [bar:5] 5; [bar:4] 4; [bar:3] 3; [bar:2] 2; 1"

-- Bars 2 to 8 have fixed slots: the keys of their flyout slots, run out of combat.
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

-- The create snippet: type first goes to a value that is not an action, so that a popup field the template's OnLoad wrote under the caller's
-- taint is cleared by secure code (UpdateFlyout, ActionButton.lua:1672-1710); then the rest, then the action, then the type.
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

-- A Flat UI bar is shown exactly while its game bar is: the watcher under the game bar's first button container sets flatui-game, a pet battle sets
-- flatui-pb.
local ON_SHOW = [=[
local bar = self:GetFrameRef("bar")
bar:SetAttribute("flatui-game", true)
if bar:GetAttribute("flatui-pb") or bar:GetAttribute("flatui-kb") then
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
if self:GetAttribute("flatui-game") and not pb and not self:GetAttribute("flatui-kb") then
	self:Show()
else
	self:Hide()
end
]=]

-- A drag starts only unlocked or with the pickup key, and picks up the button's slot. A drop puts down on it (SecureHandlers.lua:128-161).
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

-- The page arrows of the main bar: the game's paging action on a click (SECURE_ACTIONS.actionbar), on the button's release as Flat UI's buttons. The
-- page number under the text takes the same action with a page number, 1 (SecureTemplates.lua:329-330, C_ActionBar.SetActionBarPage).
local PAGER_WIRE = [=[
for _, dir in ipairs(newtable("Up", "Down", "Number")) do
	local b = self:GetFrameRef("page" .. dir)
	if b then
		b:SetAttribute("useOnKeyDown", false)
		if dir == "Number" then
			b:SetAttribute("action", 1)
		else
			b:SetAttribute("action", dir == "Up" and "increment" or "decrement")
		end
		b:SetAttribute("type", "actionbar")
	end
end
]=]
-- The two arrows and the number: where the game's are, else the place of its XML from the bar's bottom left (the group's bottom right 4 left of
-- and 9 up from it, the arrows 10 over and under its middle), and the game's atlases.
local PAGER = {
	{ dir = "Up", key = "UpButton", x = -12.5, y = 36, w = 17, h = 14, atlas = "ui-hud-actionbar-pageuparrow" },
	{ dir = "Down", key = "DownButton", x = -12.5, y = 16, w = 17, h = 14, atlas = "ui-hud-actionbar-pagedownarrow" },
	{ key = "Text", x = -13.5, y = 26, w = 17, h = 10 },
}

-- The reverse of PARK, through the same handles.
local UNPARK = [=[
for n = 1, 8 do
	self:GetFrameRef("game" .. n):SetAlpha(1)
	for i = 1, 12 do
		self:GetFrameRef("t" .. n .. "_" .. i):EnableMouse(true)
	end
end
self:GetFrameRef("game1"):EnableMouse(true)
]=]

-- Quick Keybind Mode: the game's bars back (UNPARK) and Flat UI's hidden, with flatui-kb set so that neither a watcher nor the pet battle driver shows
-- one again; KB_OFF parks the game's bars again and shows each Flat UI bar whose game bar shows outside a pet battle, as ON_SHOW does.
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
	if bar:GetAttribute("flatui-game") and not bar:GetAttribute("flatui-pb") then
		bar:Show()
	end
end
]=]

-- Setup -----------------------------------------------------------------------------------------------------------------------------------------

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

-- A state of the button in one of the game's atlases, else a texture of the atlas.
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

-- The page the main bar shows now, or nil.
function F.Page()
	local get = C_ActionBar and C_ActionBar.GetActionBarPage or _G.GetActionBarPage
	if type(get) ~= "function" then
		return nil
	end
	local ok, page = pcall(get)
	return ok and ns.Finite(page) and page or nil
end

-- The tooltip of a page arrow: which way it pages, the page shown now and the key of that command. The page number's says the page and, past page
-- 1, that a click goes back to it.
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
	tip:Show()
end

-- The hooks of a page arrow or the page number, once: the game's scroll click after a click that paged (the number's on a page past 1 only,
-- read before the click), and the tooltip.
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

-- The page arrows and the page number of bar 1, hidden until the layout places them.
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
			F.HookPager(button)
			S.header:SetFrameRef("page" .. def.dir, button)
		end
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
	-- The page number takes a click: a secure button of the paging action under the number's holder, which takes no mouse, so the number stays on top.
	local name = "FlatUIBar1PageNumber"
	local number = _G[name] or CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
	number:RegisterForClicks("LeftButtonUp")
	number:SetFrameLevel(bar:GetFrameLevel() + 9)
	number:Hide()
	pager.Number = number
	F.HookPager(number)
	S.header:SetFrameRef("pageNumber", number)
end

-- The bars, the header, the buttons and the watchers; the frame refs the snippets walk.
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
		-- The watcher: one frame of 1 x 1 under the container of the game bar's first button. The container is shown whenever the bar is.
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

-- The attributes of the buttons, the watchers' and drivers' snippets, the drag wraps, the paging driver and the pet battle drivers.
function F.Wire()
	local bases = {}
	for n = 1, 8 do
		bases[n] = BAR[n].base
	end
	Run(CREATE:format(table.concat(bases, ", ")))
	-- The snippets are attributes of Flat UI's own bars and watchers, written out of combat with a plain SetAttribute: a handle refuses a name that
	-- starts with an underscore (RestrictedFrames.lua:522-526).
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

-- Layout -----------------------------------------------------------------------------------------------------------------------------------------

-- A game frame's rectangle in the units of Flat UI's bars (those of UIParent), or nil when it has not been laid out.
local function Rect(frame)
	local ok, l, b, w, h = pcall(frame.GetRect, frame)
	if not ok or not (ns.Finite(l) and ns.Finite(b) and ns.Finite(w) and ns.Finite(h)) or w <= 0 or h <= 0 then
		return nil
	end
	local e = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return l * e, b * e, w * e, h * e
end

-- The way a flyout opens: up from a bar in the lower half of the screen, down from the upper half, toward the middle from a vertical bar.
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

-- Each Flat UI bar takes the game bar's rectangle, and each button its container's place and size, copied: a Flat UI button is never anchored to the game.
function F.Layout()
	local run = {}
	for n = 1, 8 do
		local def = BAR[n]
		local bl, bb, bw, bh = Rect(_G[def.game])
		S.rect[n] = bl and { bl, bb, bw, bh } or nil
		if bl then
			local count = Count(n)
			local dir = Direction(bl, bb, bw, bh, count)
			-- The bar's own place goes through the header too (the bar is a handle of a protected frame), relative to its parent, UIParent (a handle takes "$parent", RestrictedFrames.lua:489-491).
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
	end
	-- A page arrow that cannot be placed stays hidden; it never stops the bars (Guard would).
	local ok, err = pcall(F.Pager)
	S.pagerError = not ok and tostring(err) or nil
end

-- The pop of the page number as the page changes: its holder, Flat UI's own frame, scales from POP_FROM back to 1 over POP_TIME, made the first time.
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

-- The page number shown now, set on Flat UI's own font string when it changed; allowed in a fight. A change after the first pops the number
-- (F.PagePop), and a tooltip of a page arrow that is up reads the new page at once.
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

-- Page arrows on the main bar, out of combat: each part of the game's page number at its place beside the game bar, moved by the same offset onto
-- Flat UI's bar 1, shown while the row is on and the game's own is shown.
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
			-- The number at the game's scale (Edit Mode's icon size scales it down, MainActionBar.lua:107-115); offsets are in the holder's own units.
			local scale = h / def.h
			scale = ns.Finite(scale) and scale > 0.2 and scale or 1
			pager.holder:SetScale(scale)
			pager.holder:SetSize(def.w, def.h)
			pager.holder:ClearAllPoints()
			pager.holder:SetPoint("CENTER", S.bars[1], "BOTTOMLEFT", x / scale, y / scale)
			-- Its button, over the number's rectangle in the bar's units.
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
end

-- True when a game bar's rectangle is not the one of the last layout, by more than half a unit on an edge.
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

-- Parking ---------------------------------------------------------------------------------------------------------------------------------------

-- The game's bars stay where they are and shown, at alpha 0 with the mouse off on the bar, the pager buttons and the 96 buttons.
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

-- The game may put an alpha back at once, in a fight too. The mouse is put back out of combat.
function F.UpkeepAlpha()
	-- Quick Keybind Mode has the game's bars shown.
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

-- Flat UI's buttons are not in use this session: what an earlier session of Flat UI's buttons parked is put back, once. The game's own frames start a
-- reload with alpha 1 and the mouse on, so this finds nothing to change unless the setting went back during the session.
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

-- Keys, lock and the build ----------------------------------------------------------------------------------------------------------------------

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

-- locked mirrors lockActionBars for the drag wraps, which run in a fight.
function F.Lock()
	local locked = GetCVarBool("lockActionBars") and true or false
	if S.locked ~= locked then
		S.locked = locked
		Run(("self:SetAttribute('flatui-locked', %s)"):format(tostring(locked)))
	end
end

-- What the snippets of the build write, read back: a snippet that failed inside Execute raises nothing here (SecureHandlers.lua:680-699).
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

-- A build that failed: Flat UI's layer is taken down, out of combat, so that the game's bars are the only ones left. The drivers and the watchers are
-- plain calls on Flat UI's own frames; the header hides each bar and clears the key bindings it routed.
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
	for n = 1, 12 do
		S.slots[n] = S.grid[1][n]:GetAttribute("action")
	end
	for _, fn in ipairs(S.builtListeners) do
		Guard("listener", fn)
	end
end

-- Quick Keybind Mode was seen to open or close (its EventRegistry callbacks and the 0.1 s watch). Only noted here: the bars change in F.Process.
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

-- Out of combat: the game's bars while Quick Keybind Mode is open, Flat UI's again once it has closed.
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

-- Flat UI's bars back and the game's parked again: the mode closed, or a fight is about to start (PLAYER_REGEN_DISABLED comes before the lockdown).
function F.KeybindEnd()
	if S.kbHeld and not InCombatLockdown() then
		S.kbHeld = false
		Run(KB_OFF)
	end
end

-- Runs what an event left to do, when not in combat.
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

-- Every 0.1 s: Edit Mode is polled while it is open (and once when it closes), Quick Keybind Mode is polled, the twelve slots of the main bar are
-- compared with the last seen and, every 0.5 s out of combat, the game bars' rectangles with those of the last layout.
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
		if S.built then
			fl.upkeep, fl.lock = true, true
		end
		F.Process()
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		S.fight = true
		local held = S.kbHeld
		F.KeybindEnd()
		-- One chat line says what the fight does to Quick Keybind Mode's buttons; kbTold stays, so the reopening after it says nothing more.
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
		fl.layout, fl.lock, fl.keys = true, true, true
	elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
		fl.keys = true
	elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		fl.layout = true
	elseif event == "CVAR_UPDATE" and type(name) == "string" and name:lower() == "lockactionbars" then
		fl.lock = true
	end
end

-- The events and the frame's script are taken up at login, and only when Flat UI's buttons are on: a session of the game's buttons has one event.
local frame = CreateFrame("Frame")
local LATER = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
	"UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS",
	"EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE" }
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
	-- The game's own callbacks of Quick Keybind Mode (QuickKeybind.lua OnShow and OnHide). They only note it; the watch polls it too.
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

-- Interface for the other files ---------------------------------------------------------------------------------------------------------------

-- True when Flat UI's buttons are built and in use this session.
function ns.OwnOn()
	return S.built == true
end

-- True while Flat UI's buttons are chosen and have not failed to build: built, or still to be built (a login in a fight). The game's buttons of bars 1
-- to 8 are left alone from then on.
function ns.OwnWanted()
	return F.Mode() and not S.error
end

-- The overIf of the rows that apply with the game's buttons only (Hide bar frame, Hide end caps, Hide dividers, Rotation helper highlight): greyed
-- while Flat UI's buttons are chosen (Panel.lua, Over).
function ns.OwnButtonsChosen()
	return ns.OwnWanted() == true
end

-- The first thing a build's snippets did not write, or nil.
function ns.OwnMissing()
	return F.Missing()
end

-- The 96 buttons, in bar then index order (only those built).
function ns.OwnButtons()
	return S.buttons
end

-- Bar number 1 to 8 and index 1 to 12 of a Flat UI button; nil for any other frame.
function ns.OwnBar(button)
	local info = type(button) == "table" and S.info[button]
	if info then
		return info[1], info[2]
	end
end

function ns.OwnBarFrame(n)
	return S.bars[n]
end

-- The Flat UI bar that takes the place of the game bar of this name (MainActionBar, MultiBarBottomLeft and the rest), while Flat UI's buttons are
-- built; nil for any other name.
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

-- True while the mouse is over one of the page arrows or the page number of the main bar that shows: Fading (its Main action bar row) and the bar
-- block's fade count it as over the main bar, since the arrows sit left of the bar's rectangle. A withheld answer counts as over, as Fading's own reads do.
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

-- Page arrows on the main bar changed: the arrows are placed, shown or hidden on the next check out of combat.
function ns.OwnPagerChanged()
	if S.built then
		S.chunk.pager = nil
		S.flag.layout = true
	end
end

-- Lays Flat UI's bars out again on the next check out of combat: the bar block placed the game's bars. The rectangles are compared at the next watch
-- as well, since the block's places are put down a frame later.
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

-- The game button with the same bar and index.
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

-- fn() runs after the main bar's slots changed (a page or a slot change), from the 0.1 s watch.
function ns.OnOwnSlots(fn)
	if type(fn) == "function" then
		S.slotListeners[#S.slotListeners + 1] = fn
	end
end

-- fn() runs once when Flat UI's buttons have been built (at once when they already are).
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

-- The main bar's page as Flat UI computed it, and the game's actionpage.
function ns.OwnPage()
	if not S.built then
		return nil
	end
	local main = _G.MainActionBar
	return S.bars[1]:GetAttribute("flatui-page"), main and main:GetAttribute("actionpage")
end

-- One line for /flatui status, or nil. id is one of the ids of Core.lua's OWN_STATUS: "buttons", "waiting", "page", "keys", "flyoutkeys", "parked",
-- "leave", "taint" or "totem". A build that failed says why in the "buttons" line.
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
