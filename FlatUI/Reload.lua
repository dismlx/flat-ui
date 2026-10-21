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
