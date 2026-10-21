local _, ns = ...

-- Glows and animations on action buttons (the page Glows and animations under Action bars). The game's proc glow stays, becomes a coloured
-- border (ns.SetButtonMark, source "alert", drawn by ActionBars.lua) or goes; the rotation helper highlight, the cast fill animation and the
-- interrupt flash can be switched off; the extra button's artwork can go. Nothing is hooked on a button. The two calls of the spell alert manager
-- (a plain table, ActionButtonSpellAlerts.lua:117-135) only record the button, and everything is done in a pass one frame later, also after
-- the events and the callbacks of the assisted combat manager (ActionButtonSpellAlerts.lua:110-111). Only alpha is set, so a pass in a fight
-- touches no protected part. This file is not a module.

local KEY = "actionbars"
local PATH = KEY .. "."
local NO_ASSIST = "Rotation helper highlight: the game has no rotation helper."
local NO_EXTRA = "Extra button artwork: the game has no extra action button."
local REFUSED = "Proc glow: the game refused the change."
local STOPPED = "Glows and animations: the last change failed with an error."
local WEAK = { __mode = "k" }

-- shown[button] = true while the game's alert is up on it
local shown = setmetatable({}, WEAK)
-- marked[button] = true while this file's alert mark is set on it
local marked = setmetatable({}, WEAK)
-- cut[region] = true while this file holds the region at alpha 0
local cut = setmetatable({}, WEAK)
local hooked, waiting, refused, listened = false, false, false, false
local owner = {}

local function Plain(value, kind)
	return type(value) == kind and not ns.IsSecret(value)
end

local function Opt(name)
	return ns.Get(PATH .. name)
end

local function On()
	return ns.Enabled(KEY)
end

-- A region faded, and put back only when this file faded it: the game's own alpha is never set.
local function Fade(region, hide)
	if not Plain(region, "table") then
		return
	end
	if hide then
		cut[region] = true
		ns.SetFaded(region, true)
	elseif cut[region] then
		cut[region] = nil
		ns.SetFaded(region, false)
	end
end

-- The game's alert frame on a button. False when the game refuses the change.
local function Alert(button, mode)
	local alert = button.SpellActivationAlert
	if not Plain(alert, "table") then
		return true
	end
	if mode == "game" then
		if cut[alert] then
			cut[alert] = nil
			pcall(alert.SetAlpha, alert, 1)
		end
		return true
	end
	cut[alert] = true
	return (pcall(alert.SetAlpha, alert, 0))
end

-- True while the game's alert on the button is the plain proc glow. A rotation alert goes on the assistant's own frame, which is not cut.
local function Plainly(button)
	local manager = _G.ActionButtonSpellAlertManager
	if not Plain(manager, "table") or not Plain(manager.activeAlerts, "table") or not Plain(manager.SpellAlertType, "table") then
		return true
	end
	return manager.activeAlerts[button] == manager.SpellAlertType.Default
end

-- One of Flat UI's own buttons (OwnBars.lua) has no alert frame of the game's. OwnPaint.lua says when the spell of its slot starts or stops
-- glowing (ns.OnOwnProc), and the proc row decides what that shows: the game's glow drawn by ProcGlow.lua's frame, the coloured border, or nothing.
-- The rotation helper highlight, the cast fill animation and the interrupt flash are not drawn on these buttons.
local procOn = setmetatable({}, WEAK)
local listenedOwn = false

local function Attach(ask)
	if not listenedOwn and type(ns.OnOwnProc) == "function" then
		listenedOwn = pcall(ns.OnOwnProc, function(button, glowing)
			if Plain(button, "table") then
				procOn[button] = glowing == true
				ask()
			end
		end)
	end
end

local function OwnButtons()
	if type(ns.OwnButtons) ~= "function" then
		return {}
	end
	local ok, list = pcall(ns.OwnButtons)
	return ok and type(list) == "table" and list or {}
end

local function Glowing(button)
	if procOn[button] ~= nil then
		return procOn[button]
	end
	if type(ns.OwnState) == "function" then
		local ok, st = pcall(ns.OwnState, button)
		return ok and type(st) == "table" and st.proc == true
	end
	return false
end

local function OwnProc(button, mode)
	local glowing = Glowing(button)
	if type(ns.ProcGlowOwn) == "function" then
		ns.ProcGlowOwn(button, mode == "game" and glowing)
	end
	if mode == "border" and glowing then
		local r, g, b = ns.Colour(PATH .. "procColour")
		marked[button] = true
		if type(ns.SetButtonMark) == "function" then
			ns.SetButtonMark(button, "alert", r, g, b)
		end
	elseif marked[button] then
		marked[button] = nil
		if type(ns.SetButtonMark) == "function" then
			ns.SetButtonMark(button, "alert", nil)
		end
	end
end

local function Mark(button, mode)
	if mode == "border" and shown[button] and Plainly(button) then
		local r, g, b = ns.Colour(PATH .. "procColour")
		marked[button] = true
		if type(ns.SetButtonMark) == "function" then
			ns.SetButtonMark(button, "alert", r, g, b)
		end
	elseif marked[button] then
		marked[button] = nil
		if type(ns.SetButtonMark) == "function" then
			ns.SetButtonMark(button, "alert", nil)
		end
	end
end

local Ask

local function Run()
	waiting = false
	Attach(Ask)
	local on = On()
	local mode = on and hooked and Opt("proc") or "game"
	if refused and mode ~= "game" then
		mode = "game"
	end
	local assistOff, castOff, interruptOff = on and not Opt("assist"), on and not Opt("castAnim"), on and not Opt("interruptAnim")
	local sawAssist = false
	local ownMode = on and Opt("proc") or "game"
	for _, button in ipairs(OwnButtons()) do
		OwnProc(button, ownMode)
	end
	for _, button in ipairs(ns.ActionButtons()) do
		if not (type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button)) then
			if not Alert(button, mode) then
				refused = true
				mode = "game"
				ns.Note(KEY, REFUSED)
				Alert(button, "game")
			end
			Mark(button, mode)
			if button.AssistedCombatRotationFrame ~= nil or button.AssistedCombatHighlightFrame ~= nil then
				sawAssist = true
			end
			Fade(button.AssistedCombatRotationFrame, assistOff)
			Fade(button.AssistedCombatHighlightFrame, assistOff)
			Fade(button.SpellCastAnimFrame, castOff)
			Fade(button.InterruptDisplay, interruptOff)
		end
	end
	if assistOff and not sawAssist and (_G.C_AssistedCombat == nil or _G.AssistedCombatManager == nil) then
		ns.Note(KEY, NO_ASSIST)
	else
		ns.ClearNote(KEY, NO_ASSIST)
	end
	local extra = _G.ExtraActionButton1
	local artOff = on and not Opt("abilityArt")
	if Plain(extra, "table") then
		Fade(extra.style, artOff)
	end
	local zone = _G.ZoneAbilityFrame
	if Plain(zone, "table") then
		Fade(zone.Style, artOff)
	end
	if artOff and not Plain(extra, "table") then
		ns.Note(KEY, NO_EXTRA)
	else
		ns.ClearNote(KEY, NO_EXTRA)
	end
end

local function Pass()
	if pcall(Run) then
		ns.ClearNote(KEY, STOPPED)
	else
		waiting = false
		ns.Note(KEY, STOPPED)
	end
end

-- One pass a frame later, however many calls ask.
function Ask()
	if waiting then
		return
	end
	waiting = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Pass)
	else
		Pass()
	end
end

local function Shown(_, button)
	if Plain(button, "table") then
		shown[button] = true
		Ask()
	end
end

local function Hidden(_, button)
	if Plain(button, "table") then
		shown[button] = nil
		Ask()
	end
end

-- Made once, and only when the manager is a plain table with both calls. The bodies record the button and ask, nothing more.
local function Hook()
	-- Nothing is hooked or registered in the game's action button code while Restyle action bars is off and Flat UI leaves the game's bars alone.
	if ns.HandsOff() and not ns.Enabled("actionbars") then
		return
	end
	Attach(Ask)
	-- Only Flat UI's own buttons are styled: the game's alert manager has nothing to say about them.
	if type(ns.OwnLookOnly) == "function" and ns.OwnLookOnly() then
		return
	end
	if not hooked and type(hooksecurefunc) == "function" and Plain(ActionButtonSpellAlertManager, "table") then
		local manager = ActionButtonSpellAlertManager
		if type(manager.ShowAlert) == "function" and type(manager.HideAlert) == "function" then
			local one = pcall(hooksecurefunc, manager, "ShowAlert", Shown)
			local two = pcall(hooksecurefunc, manager, "HideAlert", Hidden)
			hooked = one and two
		end
	end
	if not listened and type(EventRegistry) == "table" and not ns.IsSecret(EventRegistry) and type(EventRegistry.RegisterCallback) == "function" then
		listened = true
		pcall(EventRegistry.RegisterCallback, EventRegistry, "AssistedCombatManager.RotationSpellsUpdated", Ask, owner)
		pcall(EventRegistry.RegisterCallback, EventRegistry, "AssistedCombatManager.OnSetUseAssistedHighlight", Ask, owner)
		pcall(EventRegistry.RegisterCallback, EventRegistry, "AssistedCombatManager.OnAssistedHighlightSpellChange", Ask, owner)
	end
end

local frame = CreateFrame("Frame")
ns.Own[frame] = true
pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
pcall(frame.RegisterEvent, frame, "ACTIONBAR_SLOT_CHANGED")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_START", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_INTERRUPTED", "player")
frame:SetScript("OnEvent", function()
	Hook()
	Ask()
end)

-- The rows of the Glows and animations page call this.
function ns.ButtonEffectsChanged()
	Hook()
	Ask()
end

-- The buttons hold something else: Flat UI's buttons made after login, or the game's styled after them, are looked at again.
if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(function()
		if type(ns.OwnOn) == "function" and ns.OwnOn() then
			Hook()
			Ask()
		elseif type(ns.OwnWanted) ~= "function" or not ns.OwnWanted() then
			Hook()
		end
	end)
end
