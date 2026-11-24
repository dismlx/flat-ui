local _, ns = ...

-- Glows and animations on action buttons (the page Glows and animations under Action bars). The game's proc glow stays, becomes a coloured
-- border (ns.SetButtonMark, source "alert", drawn by ActionBars.lua) or goes; the rotation helper highlight, the cast fill animation and the
-- interrupt flash can be switched off; the extra button's artwork can go. Nothing is hooked on a button. The two calls of the spell alert manager
-- (a plain table, ActionButtonSpellAlerts.lua:117-135) only record the button, and everything is done in a pass one frame later, also after
-- the events and the callbacks of the assisted combat manager (ActionButtonSpellAlerts.lua:110-111). Only alpha is set, so a pass in a fight
-- touches no protected part. This file is not a module.
-- Flat UI's own buttons run none of the game's button code, so the cast fill and the interrupt flash are drawn on them here: one frame of this
-- file's own for each button, a child of its bar over the icon, made out of combat once the buttons are built. The player's casts (UNIT_SPELLCAST_*,
-- RegisterUnitEvent "player"; the spell ID is used only when plain) light the buttons that hold the spell (C_ActionBar.FindSpellActionButtons, else
-- the spell's name): a flat fill in the cast bar colour rises from the bottom of the icon over the cast time (UnitCastingInfo, plain for the player)
-- and empties over a channel (UnitChannelInfo), fades as the cast lands, and a red flash shows when the cast is interrupted. Only heights, alpha,
-- Show, Hide and animations of these frames are set in a fight.

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
-- glowing (ns.OnOwnProc), and the proc row decides what that shows: the game's glow drawn by ProcGlow.lua's frame, in the look Glow style of the
-- Trackers page gives it (soft by default), the coloured border, or nothing.
-- The rotation helper highlight is not drawn on these buttons; the cast fill and the interrupt flash are drawn below (CAST).
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

-- The cast fill and the interrupt flash of Flat UI's own buttons. frames[button] = { frame, fill, flash, group } once made, or false; lit: the buttons
-- of the cast that shows; spell: its spell ID; start and finish: its times in seconds; channel: it empties; landed: when it landed (the fill fades for
-- FADE seconds).
local CAST = { frames = setmetatable({}, WEAK), lit = {}, pending = false, FADE = 0.2, ALPHA = 0.4, FLASH = 0.7 }

local function CastMake(button)
	local icon = button.icon
	if not Plain(icon, "table") then
		return false
	end
	local ok, parent = pcall(button.GetParent, button)
	local made = CreateFrame("Frame", nil, ok and Plain(parent, "table") and parent or UIParent)
	ns.Own[made] = true
	made:SetAllPoints(icon)
	local okLevel, level = pcall(button.GetFrameLevel, button)
	if okLevel and Plain(level, "number") then
		made:SetFrameLevel(level + 2)
	end
	local fill = made:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("BOTTOMLEFT", made, "BOTTOMLEFT", 0, 0)
	fill:SetPoint("BOTTOMRIGHT", made, "BOTTOMRIGHT", 0, 0)
	fill:SetHeight(1)
	fill:SetColorTexture(1, 1, 1, 1)
	fill:Hide()
	local flash = made:CreateTexture(nil, "OVERLAY")
	flash:SetAllPoints(made)
	flash:SetColorTexture(1, 0.1, 0.1, 1)
	flash:SetAlpha(0)
	local group = flash:CreateAnimationGroup()
	local rise = group:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(CAST.FLASH)
	rise:SetDuration(0.1)
	rise:SetOrder(1)
	local fall = group:CreateAnimation("Alpha")
	fall:SetFromAlpha(CAST.FLASH)
	fall:SetToAlpha(0)
	fall:SetDuration(0.4)
	fall:SetOrder(2)
	return { frame = made, fill = fill, flash = flash, group = group }
end

-- The frames of Flat UI's buttons that have none, out of combat, while Cast fill animation or Interrupt flash is on.
local function CastPrepare()
	if CAST.pending or not (On() and (Opt("castAnim") or Opt("interruptAnim"))) or not (type(ns.OwnOn) == "function" and ns.OwnOn()) then
		return
	end
	CAST.pending = true
	ns.OutOfCombat(function()
		CAST.pending = false
		for _, button in ipairs(OwnButtons()) do
			if CAST.frames[button] == nil then
				local ok, made = pcall(CastMake, button)
				CAST.frames[button] = ok and made or false
			end
		end
	end)
end

-- The Flat UI buttons that hold a spell: by the slots the game finds for its ID, else by its name (every rank).
local function CastButtons(spellID)
	local list = {}
	local find = C_ActionBar and C_ActionBar.FindSpellActionButtons
	local ok, slots = false, nil
	if type(find) == "function" then
		ok, slots = pcall(find, spellID)
	end
	if ok and Plain(slots, "table") then
		local want = {}
		for _, slot in ipairs(slots) do
			if Plain(slot, "number") then
				want[slot] = true
			end
		end
		for _, button in ipairs(OwnButtons()) do
			local slot = type(ns.OwnSlot) == "function" and ns.OwnSlot(button)
			if Plain(slot, "number") and want[slot] then
				list[#list + 1] = button
			end
		end
		return list
	end
	local named, name = false, nil
	if C_Spell and type(C_Spell.GetSpellName) == "function" then
		named, name = pcall(C_Spell.GetSpellName, spellID)
	end
	if named and Plain(name, "string") and type(ns.ButtonsFor) == "function" then
		for _, button in ipairs(ns.ButtonsFor("spell", name:lower())) do
			if type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button) then
				list[#list + 1] = button
			end
		end
	end
	return list
end

local function CastClear()
	for _, button in ipairs(CAST.lit) do
		local made = CAST.frames[button]
		if made then
			made.fill:Hide()
		end
	end
	CAST.lit, CAST.landed, CAST.spell = {}, nil, nil
	if CAST.driver then
		CAST.driver:Hide()
	end
end

-- Each frame while a cast shows: the fill's height from the cast's times, or its fade once the cast landed.
local function CastStep()
	local now = GetTime()
	local fade, progress = 1, 1
	if CAST.landed then
		fade = 1 - (now - CAST.landed) / CAST.FADE
		if fade <= 0 then
			CastClear()
			return
		end
	elseif CAST.finish > CAST.start then
		progress = math.min(1, math.max(0, (now - CAST.start) / (CAST.finish - CAST.start)))
		if CAST.channel then
			progress = 1 - progress
		end
	end
	for _, button in ipairs(CAST.lit) do
		local made = CAST.frames[button]
		if made then
			local height = made.frame:GetHeight()
			if ns.Finite(height) and height > 0 then
				made.fill:SetHeight(math.max(0.01, height * progress))
				made.fill:SetAlpha(CAST.ALPHA * fade)
				made.fill:SetShown(progress > 0)
			end
		end
	end
end

-- A cast or a channel of the player started: the times are read from the game, in milliseconds.
local function CastStart(spellID, channel)
	CastClear()
	if not (On() and Opt("castAnim")) then
		return
	end
	local read = channel and UnitChannelInfo or UnitCastingInfo
	if type(read) ~= "function" then
		return
	end
	local ok, _, _, _, start, finish = pcall(read, "player")
	if not (ok and ns.Finite(start) and ns.Finite(finish) and finish > start) then
		return
	end
	CAST.lit, CAST.start, CAST.finish, CAST.channel, CAST.spell = CastButtons(spellID), start / 1000, finish / 1000, channel, spellID
	local r, g, b = ns.Colour("castbars.castColour")
	for _, button in ipairs(CAST.lit) do
		local made = CAST.frames[button]
		if made then
			made.fill:SetColorTexture(r, g, b, 1)
		end
	end
	if #CAST.lit == 0 then
		CAST.spell = nil
		return
	end
	if not CAST.driver then
		CAST.driver = CreateFrame("Frame")
		ns.Own[CAST.driver] = true
		CAST.driver:SetScript("OnUpdate", function()
			if not pcall(CastStep) then
				CastClear()
			end
		end)
	end
	CAST.driver:Show()
	CastStep()
end

local function CastEvent(event, unit, _, spellID)
	if unit ~= "player" or not Plain(spellID, "number") then
		return
	end
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		CastStart(spellID, event == "UNIT_SPELLCAST_CHANNEL_START")
		return
	end
	-- An event of another spell (an instant cast meanwhile, a spell the game refused) leaves the fill alone.
	local mine = CAST.spell ~= nil and spellID == CAST.spell
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- A channel's SUCCEEDED comes as it starts; a cast lands.
		if mine and not CAST.channel and not CAST.landed then
			CAST.landed = GetTime()
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		if mine then
			CastClear()
		end
		if On() and Opt("interruptAnim") then
			for _, button in ipairs(CastButtons(spellID)) do
				local made = CAST.frames[button]
				if made then
					made.group:Stop()
					made.group:Play()
				end
			end
		end
	elseif mine and not CAST.landed then
		-- STOP, CHANNEL_STOP and FAILED end the fill at once, unless the cast landed and the fill fades.
		CastClear()
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
	CastPrepare()
	if not (on and Opt("castAnim")) then
		CastClear()
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

-- The player's casts, for the cast fill and the interrupt flash of Flat UI's own buttons.
local casts = CreateFrame("Frame")
ns.Own[casts] = true
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
	pcall(casts.RegisterUnitEvent, casts, event, "player")
end
casts:SetScript("OnEvent", function(_, event, ...)
	if type(ns.OwnOn) == "function" and ns.OwnOn() then
		if not pcall(CastEvent, event, ...) then
			pcall(CastClear)
		end
	end
end)

if type(ns.OnOwnBuilt) == "function" then
	ns.OnOwnBuilt(CastPrepare)
end

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
