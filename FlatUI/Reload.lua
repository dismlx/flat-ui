local _, ns = ...

-- Reloads the interface. If the game blocks ReloadUI from add-on code, the first press says so and the
-- button gets a secure button on top that runs the game's own /reload on the next press.

local secure = false
local buttons = {}
local built = {}
local overlays = {}
-- What a button does before the game's own reload runs, by button.
local befores = {}
local watcher

-- A secure child makes every frame above it protected, so a secure button over Reload would stop the options window from being shown,
-- hidden or moved in combat. The buttons leave the window before combat locks and come back when it ends.
local function Detach()
	for _, overlay in pairs(overlays) do
		pcall(function()
			overlay:Hide()
			overlay:ClearAllPoints()
			overlay:SetParent(UIParent)
		end)
	end
end

local function Attach()
	for button, overlay in pairs(overlays) do
		pcall(function()
			overlay:SetParent(button)
			overlay:SetAllPoints(button)
			overlay:Show()
		end)
	end
end

local function Watch()
	if watcher then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	watcher = frame
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			Detach()
		else
			Attach()
		end
	end)
end

-- True when a secure button is on a reload button. The account record only decides whether to make one.
local function IsSecure()
	return next(overlays) ~= nil
end

-- True on WoW: Forever, whose interface number is 16000 to 19999 (EllesmereUI/EllesmereUI_ClientGate.lua:22-33). The client blocks ReloadUI from addon
-- code there (EllesmereUI/EllesmereUI_Popups.lua:458-465), and a blocked call is blamed on the addon. The button is secure from the first press and
-- ReloadUI is never called.
local function Forever()
	if type(GetBuildInfo) ~= "function" then
		return false
	end
	local ok, interface = pcall(function()
		return select(4, GetBuildInfo())
	end)
	return ok and type(interface) == "number" and interface >= 16000 and interface < 20000
end

function ns.ReloadIsForever()
	return Forever()
end

local function Wanted()
	if secure or Forever() then
		return true
	end
	local record = ns.Account()
	return record ~= nil and record.reloadSecure == true
end

-- A secure button over the button, made out of combat. The hover scripts of the button still run.
local function Cover(button)
	if built[button] then
		return
	end
	built[button] = true
	ns.OutOfCombat(function()
		local ok, overlay = pcall(CreateFrame, "Button", nil, button, "SecureActionButtonTemplate")
		if not ok or type(overlay) ~= "table" then
			built[button] = nil
			return
		end
		local done = pcall(function()
			ns.Own[overlay] = true
			overlay:SetAllPoints(button)
			overlay:RegisterForClicks("LeftButtonUp")
			overlay:SetAttribute("type", "macro")
			overlay:SetAttribute("macrotext", "/reload")
			-- The game runs a click on the key press by default (ActionButtonUseKeyDown); the button listens for the release.
			overlay:SetAttribute("useOnKeyDown", false)
			overlay:SetScript("PreClick", function()
				if befores[button] then
					pcall(befores[button])
				end
			end)
			overlay:SetScript("OnEnter", function(_, ...)
				local script = button:GetScript("OnEnter")
				if script then
					script(button, ...)
				end
			end)
			overlay:SetScript("OnLeave", function(_, ...)
				local script = button:GetScript("OnLeave")
				if script then
					script(button, ...)
				end
			end)
		end)
		if not done then
			overlay:Hide()
			built[button] = nil
			return
		end
		overlays[button] = overlay
		Watch()
	end)
end

-- Remembers a reload button, and covers it when ReloadUI is known to be blocked.
function ns.SecureReload(button, before)
	if type(button) ~= "table" then
		return
	end
	if type(before) == "function" then
		befores[button] = before
	end
	local known = false
	for _, other in ipairs(buttons) do
		known = known or rawequal(other, button)
	end
	if not known then
		buttons[#buttons + 1] = button
	end
	if Wanted() then
		Cover(button)
	end
end

function ns.ReloadIsSecure()
	return IsSecure()
end

-- The press of a reload button. A blocked call raises no error: the game fires ADDON_ACTION_FORBIDDEN as the call is made, and Core
-- counts it.
function ns.Reload()
	if IsSecure() or type(ReloadUI) ~= "function" then
		return
	end
	-- Here the secure button does the reload. A press that reaches this function means it is not on the button (in a fight, or the client would
	-- not make it): the call is not made.
	if Forever() then
		print("Reload is blocked for add-ons here. Type /reload.")
		return
	end
	local before = ns.BlockedTotal()
	pcall(ReloadUI)
	if ns.BlockedTotal() > before then
		secure = true
		local record = ns.Account()
		if record then
			record.reloadSecure = true
		end
		print("Reload is blocked for add-ons here. Press Reload again.")
		for _, button in ipairs(buttons) do
			Cover(button)
		end
	end
end

-- Taint log reminder -----------------------------------------------------------------------------------------------------------------
-- While taintLog is on, Flat UI leaves out the looks that follow game frames (ns.HookMethod). The box says so once a session and offers
-- to turn the variable off and reload. The approach is EllesmereUI's reminder (EllesmereUI.lua:4172-4215: once a session, Ignore holds it
-- until the next reload, plain C_CVar.SetCVar as the fix) and its secure /reload click with the work done after the click
-- (EllesmereUI_Popups.lua:488 and 725-800). Nothing is saved: the flag lives until the reload.

local taint = { wanted = false, shown = false, ignored = false, suspended = false }
local taintBox, taintOverlay, taintWatcher

local function TaintShade(delta)
	local r, g, b = ns.Colour("general.backdrop")
	return math.min(1, math.max(0, r + delta)), math.min(1, math.max(0, g + delta)), math.min(1, math.max(0, b + delta))
end

-- The box is protected while the secure button is on it, so the button leaves before combat locks and comes back when it ends.
local function TaintDetach()
	if taintOverlay then
		pcall(function()
			taintOverlay:Hide()
			taintOverlay:ClearAllPoints()
			taintOverlay:SetParent(UIParent)
		end)
	end
end

local function TaintAttach()
	if taintOverlay and taintOverlay.flatButton then
		pcall(function()
			taintOverlay:SetParent(taintOverlay.flatButton)
			taintOverlay:SetAllPoints(taintOverlay.flatButton)
			taintOverlay:Show()
		end)
	end
end

-- Without the secure button the click only turns the variable off and says what to type.
local function TaintTurnOff()
	pcall(C_CVar.SetCVar, "taintLog", "0")
end

local function TaintButton(parent, text, width)
	local button = CreateFrame("Frame", nil, parent)
	ns.Own[button] = true
	button:SetSize(width, 24)
	local outline = ns.Outline(button, button, true)
	local label = ns.OwnText(button, "OVERLAY", "GameFontHighlight")
	if label then
		label:SetPoint("CENTER", button, "CENTER", 0, 0)
		label:SetText(text)
	end
	local function Paint(hover)
		local r, g, b = TaintShade(hover and 0.17 or 0.09)
		ns.SetOutlineFill(outline, r, g, b, 1)
	end
	Paint(false)
	button:EnableMouse(true)
	button:SetScript("OnEnter", function()
		Paint(true)
	end)
	button:SetScript("OnLeave", function()
		Paint(false)
	end)
	return button
end

local function TaintBuild()
	local box = CreateFrame("Frame", "FlatUITaintLog", UIParent)
	ns.Own[box] = true
	box:SetSize(380, 124)
	box:SetFrameStrata("DIALOG")
	box:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	box:EnableMouse(true)
	local outline = ns.Outline(box, box, true)
	local r, g, b = TaintShade(0.06)
	ns.SetOutlineFill(outline, r, g, b, 1)
	local title = ns.OwnText(box, "OVERLAY", "GameFontNormal")
	if title then
		title:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -14)
		title:SetText("Taint log")
	end
	local line = ns.OwnText(box, "OVERLAY", "GameFontHighlight")
	if line then
		line:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -38)
		line:SetWidth(348)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(true)
		line:SetText("taintLog is on. Flat UI leaves out the looks that follow game frames until it is off.")
	end
	local ignore = TaintButton(box, "Ignore", 90)
	ignore:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -16, 14)
	local ignoreDown = false
	ignore:SetScript("OnMouseDown", function(_, button)
		ignoreDown = button == "LeftButton"
	end)
	ignore:SetScript("OnMouseUp", function(_, button)
		local wanted = ignoreDown and button == "LeftButton"
		ignoreDown = false
		if wanted then
			box:Hide()
		end
	end)
	local reload = TaintButton(box, "Turn off and reload", 150)
	reload:SetPoint("RIGHT", ignore, "LEFT", -8, 0)
	local reloadDown = false
	reload:SetScript("OnMouseDown", function(_, button)
		reloadDown = button == "LeftButton"
	end)
	reload:SetScript("OnMouseUp", function(_, button)
		local wanted = reloadDown and button == "LeftButton"
		reloadDown = false
		if wanted then
			TaintTurnOff()
			print("Flat UI: taintLog is off. Type /reload to follow the game frames again.")
			box:Hide()
		end
	end)
	-- The reload is the game's own /reload on a secure button; the CVar is turned off after the click, as in EllesmereUI_Popups.lua:483-486.
	local made, overlay = pcall(CreateFrame, "Button", nil, reload, "SecureActionButtonTemplate")
	if made and type(overlay) == "table" then
		local done = pcall(function()
			ns.Own[overlay] = true
			overlay:SetAllPoints(reload)
			overlay:RegisterForClicks("LeftButtonUp")
			overlay:SetAttribute("type", "macro")
			overlay:SetAttribute("macrotext", "/reload")
			overlay:SetAttribute("useOnKeyDown", false)
			overlay:SetScript("OnEnter", function(_, ...)
				local script = reload:GetScript("OnEnter")
				if script then
					script(reload, ...)
				end
			end)
			overlay:SetScript("OnLeave", function(_, ...)
				local script = reload:GetScript("OnLeave")
				if script then
					script(reload, ...)
				end
			end)
			overlay:HookScript("OnClick", TaintTurnOff)
		end)
		if done then
			overlay.flatButton = reload
			taintOverlay = overlay
		else
			pcall(overlay.Hide, overlay)
		end
	end
	box:SetScript("OnHide", function()
		-- Ignore, Escape and the reload button all end here; only the start of a fight hides it without an answer.
		if not taint.suspended then
			taint.ignored = true
		end
	end)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "FlatUITaintLog")
	end
	return box
end

local function TaintShow()
	if taint.ignored or InCombatLockdown() then
		return
	end
	if not taintBox then
		local ok, box = pcall(TaintBuild)
		if not ok or type(box) ~= "table" then
			return
		end
		taintBox = box
	end
	TaintAttach()
	taintBox:Show()
	taint.shown = true
end

local function TaintWatch()
	if taintWatcher then
		return
	end
	local ok, frame = pcall(CreateFrame, "Frame")
	if not ok or type(frame) ~= "table" then
		return
	end
	taintWatcher = frame
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if not taintBox then
			if event == "PLAYER_REGEN_ENABLED" and taint.wanted then
				TaintShow()
			end
			return
		end
		if event == "PLAYER_REGEN_DISABLED" then
			-- Runs before the lockdown (EllesmereUI_Popups.lua:725-800), so the box can still be hidden.
			taint.suspended = true
			TaintDetach()
			pcall(taintBox.Hide, taintBox)
			taint.suspended = false
		elseif taint.wanted and not taint.ignored then
			TaintShow()
		end
	end)
end

-- Shows the box once a session, out of combat. A call in combat waits for the end of the fight; after Ignore it does nothing until the reload.
function ns.TaintReminder()
	if taint.shown or taint.ignored then
		return
	end
	taint.wanted = true
	TaintWatch()
	TaintShow()
end

-- Reload notice ------------------------------------------------------------------------------------------------------------------------------
-- A change that needs a reload (ns.ReloadLines, Core.lua), made anywhere, shows a small notice of Flat UI's own at the top of the screen: what
-- needs it, Reload, Undo and Later. Its Reload is a reload button like the others (ns.SecureReload): where ReloadUI is blocked, the game's own
-- /reload runs on a secure button, which leaves the notice as a fight starts and comes back after it, so meanwhile the button is dimmed and says so.
-- Undo sets every change it lists back to the value the game runs since login, in the profile in use, with ns.Set, out of combat and while Setup
-- does not have the options window; each goes into Home's record of changes (ns.PanelHome.Noted) and one line in chat says how many. Later hides
-- the notice until the next change that needs a reload; it goes when nothing needs one any more. Undo is dimmed while it would do nothing (in a fight,
-- while Setup has the window). Pointing at the notice, or at any of its buttons, shows GameTooltip with every change, its value now and at login,
-- in the words of the options window (ns.PanelTrust.ValueText). It fades in over 0.2 s each time it shows from hidden (its own alpha). It is in
-- DIALOG strata, over the options window (HIGH), and has an own entry in /flatui move (FlatUIReloadNotice, Movers.lua), at whose spot it stands.
-- It keeps clear of the title bar of the options window while that shows, of the toolbar of /flatui move while that is open and of the test mode
-- bar while that shows (TM.BarRect, TestMode.lua): covering any of them, it takes the nearest place just above or just under one of them that
-- covers none and fits on the screen, else just above the window, or just under it where there is no room above, as before. It is always placed
-- from UIParent, never from those frames, and only while nothing protected hangs from it; an error in the placing leaves it at its start, reported
-- once.

-- width and height of the notice, y: its start under the top of the screen, reload, undo and later: the widths of the buttons, chars: about how
-- many letters of names the line holds before the rest are counted, every: how often a shown notice looks where to stand, in seconds, fade: how
-- long it takes to come in, in seconds, gap: the room it keeps from what it steps clear of.
local NOTICE = { name = "FlatUIReloadNotice", width = 520, height = 52, y = -40, reload = 80, undo = 60, later = 64, chars = 64, every = 0.25,
	fade = 0.2, gap = 6 }
-- frame, text, reload and undo: the parts once built. later: what Later held, the value of each change by its path, or nil. queued: a look on the
-- next frame is asked for. placed: where it stands now. wait: the time to the next look while shown. alpha: how far it has faded in.
local notice = { queued = false, wait = 0, alpha = 1 }
-- The colours of the tooltip's lines: the value, and the line that says what the buttons do.
local VALUE, HINT = { 0.66, 0.68, 0.62 }, { 0.9, 0.72, 0.36 }

local function Finite(value)
	return type(ns.Finite) == "function" and ns.Finite(value)
end

-- What the line says: how many changes need a reload, and their names, as many as fit, then how many more.
local function NoticeText(lines)
	local names, length = {}, 0
	for _, entry in ipairs(lines) do
		local label = type(entry[1]) == "string" and entry[1] or "a setting"
		if #names > 0 and length + #label > NOTICE.chars then
			break
		end
		names[#names + 1] = label
		length = length + #label + 2
	end
	local list = table.concat(names, ", ")
	if #lines > #names then
		list = ("%s and %d more"):format(list, #lines - #names)
	end
	if #lines == 1 then
		return ("1 change needs a reload: %s."):format(list)
	end
	return ("%d changes need a reload: %s."):format(#lines, list)
end

-- True while a press of Reload needs the secure button (ReloadUI is blocked here) and a fight keeps that button off it.
local function NoticeWaits(fight)
	return fight == true and (Wanted() or IsSecure())
end

-- Reload is dimmed while it waits for the end of a fight, and Undo in a fight and while Setup has the options window, where it does nothing.
local function NoticeDim(fight)
	if notice.reload then
		pcall(notice.reload.SetAlpha, notice.reload, NoticeWaits(fight) and 0.4 or 1)
	end
	if notice.undo then
		local held = fight == true or (type(ns.PanelInMode) == "function" and ns.PanelInMode() == true)
		pcall(notice.undo.SetAlpha, notice.undo, held and 0.4 or 1)
	end
end

-- What the notice keeps clear of, each { left, right, top, bottom, up, down } in the units of UIParent: the band it must not cover, and the top of the
-- notice just above and just under the frame. The title bar of the options window, whose place under it is under the whole window, is window.
local function NoticeBlocks()
	local blocks = {}
	local function Add(left, bottom, width, height, under)
		if Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and width > 0 and height > 0 then
			local top = bottom + height
			blocks[#blocks + 1] = { left, left + width, top, bottom, top + NOTICE.height + NOTICE.gap, (under or bottom) - NOTICE.gap }
			return blocks[#blocks]
		end
		return nil
	end
	local kit = ns.PanelKit
	local window = type(ns.PanelShown) == "function" and ns.PanelShown() and type(kit) == "table" and kit.Window() or nil
	if window then
		local left, bottom, width, height = kit.Rect(window)
		if Finite(bottom) and Finite(height) and height > 0 then
			local title = bottom + height - height * kit.TITLE / kit.HEIGHT
			blocks.window = Add(left, title, width, bottom + height - title, bottom)
		end
	end
	-- The toolbar of /flatui move while it is open and shows (MoversMode.lua, at the top of the screen; MM.State gives its parts).
	local movers, mode = ns.MoverKit, ns.MoversMode
	if type(movers) == "table" and type(movers.IsOpen) == "function" and movers.IsOpen() == true and type(kit) == "table"
		and type(mode) == "table" and type(mode.State) == "function" then
		local _, parts = mode.State()
		local bar = type(parts) == "table" and parts.bar
		local ok, shown = false, false
		if type(bar) == "table" then
			ok, shown = pcall(bar.IsVisible, bar)
		end
		if ok and shown == true then
			Add(kit.Rect(bar))
		end
	end
	-- Only the rectangle: BarRect's fifth return is where the bar stands ("top", "above", "below" or "dragged"), not the place under it.
	local test = ns.TestMode
	if type(test) == "table" and type(test.BarRect) == "function" then
		local left, bottom, width, height = test.BarRect()
		Add(left, bottom, width, height)
	end
	return blocks
end

-- True when a notice with its top left corner at x, y covers a block.
local function NoticeCovers(x, y, blocks)
	for _, block in ipairs(blocks) do
		if y - NOTICE.height < block[3] and y > block[4] and x + NOTICE.width > block[1] and x < block[2] then
			return true
		end
	end
	return false
end

-- The top of the notice nearest to y, just above or just under a block, that covers none of them and fits on the screen, or nil.
local function NoticeNearest(x, y, blocks, screenH)
	local best
	for _, block in ipairs(blocks) do
		for side = 5, 6 do
			local at = block[side]
			if at <= screenH and at - NOTICE.height >= 0 and not NoticeCovers(x, at, blocks)
				and (best == nil or math.abs(at - y) < math.abs(best - y)) then
				best = at
			end
		end
	end
	return best
end

-- The top left corner of the notice in the units of UIParent, or nil for its start at the top of the screen: the spot of its box in /flatui move,
-- but clear of the title bar of the options window, the toolbar of /flatui move and the test mode bar while they show.
local function NoticeSpot()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(NOTICE.name, "TOPLEFT")
	end
	local ok, screenW, screenH = pcall(UIParent.GetSize, UIParent)
	if not (ok and Finite(screenW) and Finite(screenH)) then
		return x, y
	end
	local blocks = NoticeBlocks()
	if #blocks == 0 then
		return x, y
	end
	local fromX, fromY = x, y
	if not (Finite(x) and Finite(y)) then
		x, y = (screenW - NOTICE.width) / 2, screenH + NOTICE.y
	end
	if not NoticeCovers(x, y, blocks) then
		return fromX, fromY
	end
	local best = NoticeNearest(x, y, blocks, screenH)
	if best then
		return x, best
	end
	-- No place is clear of them all: clear of the window's title bar, as before the bars counted.
	local window = blocks.window
	if window and NoticeCovers(x, y, { window }) then
		return x, window[5] <= screenH and window[5] or window[6]
	end
	return x, y
end

local function NoticePlace()
	local frame = notice.frame
	local protected = false
	if InCombatLockdown() then
		local ok, value = pcall(frame.IsProtected, frame)
		protected = not ok or value ~= false
	end
	if protected then
		return
	end
	-- An error in the placing leaves the notice at its start at the top, so it still shows and the OnUpdate below does not repeat the error.
	local ok, x, y = pcall(NoticeSpot)
	if not ok then
		if not notice.failed then
			notice.failed = true
			geterrorhandler()(x)
		end
		x, y = nil, nil
	end
	-- A spot with only one of its two numbers is no spot: the notice stands at its start.
	if not (Finite(x) and Finite(y)) then
		x, y = nil, nil
	end
	local key = x and ("%.1f:%.1f"):format(x, y) or "start"
	if notice.placed == key then
		return
	end
	notice.placed = key
	pcall(function()
		frame:ClearAllPoints()
		if x then
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		else
			frame:SetPoint("TOP", UIParent, "TOP", 0, NOTICE.y)
		end
	end)
end

-- Later: the changes that need a reload now are held, and the notice hides until another comes.
local function NoticeLater()
	notice.later = {}
	for _, entry in ipairs(ns.ReloadLines()) do
		notice.later[entry[3]] = entry[4]
	end
	notice.frame:Hide()
end

-- Reload: the secure button takes the press where it is on the button. A press that reaches this function in a fight, where the reload needs that
-- button, is not made.
local function NoticeReload()
	if NoticeWaits(InCombatLockdown()) then
		print("Flat UI: Reload works here again after the fight. Type /reload to reload now.")
		return
	end
	ns.Reload()
end

-- The words for a value of a row, as the options window says them (ns.PanelTrust.ValueText: On or Off, the text of a choice, a number with its
-- unit), so the notice's list and Home's Recent changes say a value alike.
local function NoticeValue(path, value)
	local trust = ns.PanelTrust
	if type(trust) == "table" and type(trust.ValueText) == "function" then
		local def = type(ns.Def) == "function" and ns.Def(path) or nil
		local ok, text = pcall(trust.ValueText, type(def) == "table" and def or { path = path }, value)
		if ok and type(text) == "string" then
			return text
		end
	end
	if type(value) == "boolean" then
		return value and "On" or "Off"
	end
	return type(value) == "string" and value or "changed"
end

-- The tooltip of the notice and of Undo, under owner: every change that needs a reload, with its value now and at login, and what the buttons do.
local function NoticeTip(owner)
	if ns.Forbidden(GameTooltip) then
		return
	end
	local ok, lines = pcall(ns.ReloadLines)
	if not ok or type(lines) ~= "table" or #lines == 0 then
		return
	end
	notice.tip = owner
	pcall(function()
		GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Needs a reload", 1, 1, 1)
		for _, entry in ipairs(lines) do
			local label = type(entry[1]) == "string" and entry[1] or "a setting"
			GameTooltip:AddDoubleLine(label, ("%s now, %s at login"):format(NoticeValue(entry[3], entry[4]), NoticeValue(entry[3], entry[5])), 1, 1, 1,
				VALUE[1], VALUE[2], VALUE[3])
		end
		GameTooltip:AddLine("Reload applies them. Undo puts them all back as the game runs them, with no reload. Later hides this until your next "
			.. "change that needs a reload.", HINT[1], HINT[2], HINT[3], true)
		GameTooltip:Show()
	end)
end

-- Hides the tooltip while it is the notice's: owner's, or either's when owner is nil (the notice hid under the cursor).
local function NoticeUntip(owner)
	owner = owner or notice.tip
	if not owner or ns.Forbidden(GameTooltip) then
		return
	end
	if notice.tip == owner then
		notice.tip = nil
	end
	local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, owner)
	if ok and owned == true then
		GameTooltip:Hide()
	end
end

-- Undo: every change the notice lists goes back to the value the game runs since login, in the profile in use, so no reload is needed; ns.Set
-- asks the notice to look again, and it goes once nothing needs a reload. Not in a fight, where a module's change could need what is locked, and
-- not while Setup has the options window, whose Finish would write its draft over it.
local function NoticeUndo()
	if InCombatLockdown() then
		print("Flat UI: Undo after the fight.")
		return
	end
	if type(ns.PanelInMode) == "function" and ns.PanelInMode() then
		print("Flat UI: finish or close Setup first.")
		return
	end
	local ok, lines = pcall(ns.ReloadLines)
	if not ok or type(lines) ~= "table" then
		return
	end
	local home, count = ns.PanelHome, 0
	for _, entry in ipairs(lines) do
		local path, now, was = entry[3], entry[4], entry[5]
		if type(path) == "string" and was ~= nil then
			local done, err = pcall(ns.Set, path, was)
			if not done then
				geterrorhandler()(err)
			elseif ns.Get(path) == was then
				count = count + 1
				-- Into Home's record like a change made in the window, so its Undo can make the change again.
				if type(home) == "table" and type(home.Noted) == "function" then
					pcall(home.Noted, type(ns.Def) == "function" and ns.Def(path) or { path = path, label = entry[1] }, now, was)
				end
			end
		end
	end
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	if count == 1 then
		print("Flat UI: put back 1 change, no reload needed.")
	elseif count > 1 then
		print(("Flat UI: put back %d changes, no reload needed."):format(count))
	end
end

local function NoticeBuild()
	local kit = ns.PanelKit
	if type(kit) ~= "table" then
		return nil
	end
	local frame = CreateFrame("Frame", NOTICE.name, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:SetSize(NOTICE.width, NOTICE.height)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	local outline = ns.Outline(frame, frame, true)
	kit.Painted(function()
		kit.Backing(outline, "card", 1, "accent")
	end)
	local later = kit.Button(frame, "Later", NOTICE.later, NoticeLater)
	later:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
	local undo = kit.Button(frame, "Undo", NOTICE.undo, NoticeUndo)
	undo:SetPoint("RIGHT", later, "LEFT", -6, 0)
	local reload = kit.Button(frame, "Reload", NOTICE.reload, NoticeReload, true)
	reload:SetPoint("RIGHT", undo, "LEFT", -6, 0)
	local text = kit.Label(frame, "GameFontHighlight", "LEFT", NOTICE.width - 42 - NOTICE.reload - NOTICE.undo - NOTICE.later, true)
	text:SetPoint("LEFT", frame, "LEFT", 12, 0)
	pcall(text.SetMaxLines, text, 2)
	notice.frame, notice.text, notice.reload, notice.undo = frame, text, reload, undo
	ns.SecureReload(reload)
	-- The list of changes under the notice and under each button, whose hover fill (kit.Button) stays; the tooltip goes with the notice. Reload's
	-- own scripts are wrapped, not hooked: the secure button over it runs them through GetScript (Cover, above), which leaves a hook out.
	frame:SetScript("OnEnter", NoticeTip)
	frame:SetScript("OnLeave", NoticeUntip)
	for _, button in ipairs({ undo, later }) do
		button:HookScript("OnEnter", NoticeTip)
		button:HookScript("OnLeave", NoticeUntip)
	end
	local enter, leave = reload:GetScript("OnEnter"), reload:GetScript("OnLeave")
	reload:SetScript("OnEnter", function(self, ...)
		if enter then
			enter(self, ...)
		end
		NoticeTip(self)
	end)
	reload:SetScript("OnLeave", function(self, ...)
		NoticeUntip(self)
		if leave then
			leave(self, ...)
		end
	end)
	frame:SetScript("OnHide", function()
		NoticeUntip(nil)
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		local step = Finite(elapsed) and elapsed or 0
		if notice.alpha < 1 then
			notice.alpha = math.min(1, notice.alpha + step / NOTICE.fade)
			pcall(frame.SetAlpha, frame, notice.alpha)
		end
		notice.wait = notice.wait - step
		if notice.wait <= 0 then
			notice.wait = NOTICE.every
			NoticePlace()
			-- Setup taking the options window or giving it back, and the lockdown, are followed here.
			NoticeDim(InCombatLockdown())
		end
	end)
	-- The secure button leaves Reload as a fight starts (Detach, above), before the lockdown, so the button is dimmed here as well.
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
	pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		NoticeDim(event == "PLAYER_REGEN_DISABLED")
	end)
	return frame
end

-- Looks at what needs a reload, and shows the notice, says it again, hides it or leaves it hidden after Later.
local function NoticeRefresh()
	notice.queued = false
	local ok, lines = pcall(ns.ReloadLines)
	if not ok or type(lines) ~= "table" then
		lines = {}
	end
	if #lines == 0 then
		notice.later = nil
		if notice.frame then
			pcall(notice.frame.Hide, notice.frame)
		end
		return
	end
	if notice.later then
		-- A change put back is no longer held, so making it again shows the notice; a change Later did not hold, or one with another value, shows it now.
		local now, fresh = {}, false
		for _, entry in ipairs(lines) do
			now[entry[3]] = true
			local held = notice.later[entry[3]]
			fresh = fresh or held == nil or held ~= entry[4]
		end
		for path in pairs(notice.later) do
			if not now[path] then
				notice.later[path] = nil
			end
		end
		if not fresh then
			return
		end
		notice.later = nil
	end
	if not notice.frame then
		local made, frame = pcall(NoticeBuild)
		if not made or type(frame) ~= "table" then
			if not made then
				geterrorhandler()(frame)
			end
			return
		end
	end
	notice.text:SetText(NoticeText(lines))
	NoticeDim(InCombatLockdown())
	notice.wait = 0
	NoticePlace()
	-- From hidden it fades in (OnUpdate, above); shown already, it only says the new line, and an open list says it again.
	if not notice.frame:IsShown() then
		notice.alpha = 0
		pcall(notice.frame.SetAlpha, notice.frame, 0)
	elseif notice.tip then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, notice.tip)
		if ok and owned == true then
			NoticeTip(notice.tip)
		end
	end
	notice.frame:Show()
end

-- A change that may need a reload was made (ns.Set and a profile put in use, Core.lua): the notice looks on the next frame, once for a burst of
-- changes such as Reset page, and outside any drawing of setup.
function ns.ReloadNoticeUpdate()
	if notice.queued then
		return
	end
	notice.queued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, NoticeRefresh)
	else
		NoticeRefresh()
	end
end

-- The movers: the notice has a box whether or not it shows, so it can be placed before it is needed.
function ns.ReloadNoticeShown()
	return true
end

function ns.ReloadNoticeMoved()
	notice.placed = nil
	if notice.frame then
		NoticePlace()
	end
end
