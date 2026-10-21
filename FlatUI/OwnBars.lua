local _, ns = ...

-- Flat UI's own action buttons, piece B: eight bars of twelve secure buttons, the paging of the main bar, the parking of the game's bars, the layout
-- copied from the game's bars and the keys that open flyouts. The design is research/own-buttons/design.md (sections 2 to 5, 7 and 10).
--
-- A Flat UI button is a CheckButton of ActionButtonTemplate, SecureActionButtonTemplate. It runs the template's OnLoad and nothing of the game's
-- button code. This file writes no field on a button, a bar or a watcher: what it keeps is in tables, and every attribute is set by secure code (a
-- header's Execute, a state driver, a handle). The game's bars stay shown and laid out at alpha 0 with the mouse off, so every key still reaches
-- the game's own buttons, which keep their page from the game's own controller. Nothing is hooked, nothing of the game's is hidden, moved,
-- reparented or given an attribute. All of it runs only while Action buttons (actionbars.own) is Flat UI's.

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
if bar:GetAttribute("flatui-pb") then
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
if self:GetAttribute("flatui-game") and not pb then
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
end

-- Layout -----------------------------------------------------------------------------------------------------------------------------------------

-- A game frame's rectangle in the units of Flat UI's bars (those of UIParent), or nil when it has not been laid out.
local function Rect(frame)
	local ok, l, b, w, h = pcall(frame.GetRect, frame)
	if not ok or type(l) ~= "number" or type(w) ~= "number" or w <= 0 or h <= 0 then
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
	for n = 1, 8 do
		local game = _G[BAR[n].game]
		if game:GetAlpha() ~= 0 then
			game:SetAlpha(0)
			S.putBack = S.putBack + 1
		end
	end
end

function F.Upkeep()
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
	S.parked = false
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
end

-- Every 0.1 s: Edit Mode is polled while it is open (and once when it closes), and the twelve slots of the main bar are compared with the last seen.
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
	local changed = false
	for i = 1, 12 do
		local slot = S.grid[1][i]:GetAttribute("action")
		if slot ~= S.slots[i] then
			S.slots[i], changed = slot, true
		end
	end
	if changed then
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
		if S.built then
			fl.upkeep, fl.lock = true, true
		end
		F.Process()
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
local LATER = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
	"UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED",
	"DISPLAY_SIZE_CHANGED", "CVAR_UPDATE" }
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
			return ("Main bar page: %d, the game's %d."):format(flat, game)
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
