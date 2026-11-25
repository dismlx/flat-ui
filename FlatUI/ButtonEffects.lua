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
-- the spell's name), a macro whose spell it is and an item whose use spell it is (GetActionInfo and C_ActionBar.GetSpell, the game's rule): a flat
-- fill in the cast bar's Cast colour rises from the bottom of the icon over the cast time (UnitCastingInfo, plain for the player) and, in its Channel
-- colour, empties over a channel (UnitChannelInfo). A pushback (UNIT_SPELLCAST_DELAYED, UNIT_SPELLCAST_CHANNEL_UPDATE) reads the times again, so the
-- fill follows the real cast. It fades as the cast lands, and a flash in the cast bar's Interrupted colour (castbars.interruptedColour, read at each
-- interrupt) shows when the cast is interrupted. Aim highlight (on by default): while a spell placed on the ground waits for its spot
-- (UNIT_SPELLCAST_RETICLE_TARGET, as the game's buttons play their reticle, ActionButton.lua:1100-1103), its buttons pulse in the cast bar's Cast
-- colour, 15% to 50% and back every half second, until it is placed or cancelled: RETICLE_CLEAR, the start of any cast or channel, and SENT,
-- SUCCEEDED, FAILED, STOP, INTERRUPTED and CHANNEL_STOP of that spell only (CAST.aimSpell), since the game sends a button only the events of its own
-- spell (ActionButton.lua:320-339, the spell ID the fourth argument of SENT and the third of the others), so an Auto Shot or a wand shot meanwhile
-- leaves the pulse on. Without the reticle event (it is not known that this client sends it) the aim is found another way: at each
-- CURRENT_SPELL_CAST_CHANGED, and a frame later, SpellIsTargeting says whether a spell waits for its spot or for a click on its target, and the
-- buttons whose slot became current with it (IsCurrentAction, not Attack nor a repeating shot, and not the slots current before it, such as a stance
-- or an aura) pulse (aimSpell -1) until it says no; the events that end an aim of a known spell ask it again instead. Only buttons that show light
-- up: one the layout hid keeps its place over empty space. Only heights, alpha, colours, Show, Hide and animations of these frames are set in a fight.
-- Samples (ns.ButtonEffectsSample, out of combat): test mode (ActionBars.lua) plays the cast fill as a 2 s cast that lands, the interrupt flash and a
-- 2 s aim on the first shown buttons of Flat UI's main bar, and a change of Cast fill animation, Interrupt flash or Aim highlight with the options
-- window open plays that one on the first. A sample's spell is 0, which no event of the game's names, so a real cast or aim replaces it at once and
-- the events of other spells leave it alone; a sample never replaces a real cast or aim that shows.

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

-- The cast fill, the interrupt flash and the aim highlight of Flat UI's own buttons. frames[button] = { frame, fill, flash, group, aim, pulse } once
-- made, or false; lit: the buttons of the cast that shows; aimed: the buttons that pulse while a spell waits for its spot; aimSpell: that spell's ID
-- (0 for a sample); spell: the ID of the cast that shows (0 for a sample); start and finish: its times in seconds; channel: it empties; landed: when
-- it landed (the fill fades for FADE seconds). sample: the token of the sample aim (aim) and the button of the interrupt sample (flashed);
-- SAMPLE_TIME: how long the sample cast and the sample aim last.
local CAST = { frames = setmetatable({}, WEAK), lit = {}, aimed = {}, pending = false, FADE = 0.2, ALPHA = 0.4, FLASH = 0.7, AIM_LOW = 0.15, AIM_HIGH = 0.5,
	AIM_TIME = 0.5, sample = { aim = 0 }, SAMPLE_TIME = 2,
	-- AIM_FALLBACK: the aimSpell of an aim found by SpellIsTargeting (AimCheck), whose spell is not known. steady: the slots current while no spell
	-- waits, by slot.
	AIM_FALLBACK = -1, steady = {} }

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
	local aim = made:CreateTexture(nil, "OVERLAY")
	aim:SetAllPoints(made)
	aim:SetColorTexture(1, 1, 1, 1)
	aim:SetAlpha(0)
	local pulse = aim:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local beat = pulse:CreateAnimation("Alpha")
	beat:SetFromAlpha(CAST.AIM_LOW)
	beat:SetToAlpha(CAST.AIM_HIGH)
	beat:SetDuration(CAST.AIM_TIME)
	return { frame = made, fill = fill, flash = flash, group = group, aim = aim, pulse = pulse }
end

-- The frames of Flat UI's buttons that have none, out of combat, while Cast fill animation, Interrupt flash or Aim highlight is on.
local function CastPrepare()
	if CAST.pending or not (On() and (Opt("castAnim") or Opt("interruptAnim") or Opt("aimAnim"))) or not (type(ns.OwnOn) == "function" and ns.OwnOn()) then
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

-- A call of the game's for an action slot, by C_ActionBar first and then the global of the same name, as OwnPaint.lua reads them. Returns the first
-- three answers, nothing when it fails.
local function ActionCall(name, ...)
	local fn = C_ActionBar and C_ActionBar[name]
	if type(fn) ~= "function" then
		fn = _G[name]
	end
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if ok then
		return a, b, c
	end
	return nil
end

-- True when the slot holds a macro whose spell is spellID, or an item whose use spell is (C_ActionBar.GetSpell): the game's rule for its own buttons
-- (Blizzard_ActionBar/Shared/ActionButton.lua:953-963, MatchesActiveButtonSpellID). A macro that uses an item gives the item's ID, never compared.
local function UsesSpell(slot, spellID)
	local kind, id, sub = ActionCall("GetActionInfo", slot)
	if not Plain(kind, "string") then
		return false
	elseif kind == "item" then
		local getSpell = C_ActionBar and C_ActionBar.GetSpell
		if type(getSpell) ~= "function" then
			return false
		end
		local ok, spell = pcall(getSpell, slot)
		id = ok and spell or nil
	elseif kind ~= "macro" or (Plain(sub, "string") and sub == "item") then
		return false
	end
	return Plain(id, "number") and id == spellID
end

-- True while the button is drawn: a button past its bar's Number of icons is hidden by the layout and keeps its last place (OwnBars.lua, F.Layout).
local function Visible(button)
	local ok, shown = pcall(button.IsVisible, button)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- The Flat UI buttons that show and hold a spell: by the slots the game finds for its ID, else by its name (every rank), and the macros and items
-- whose spell it is (UsesSpell).
local function CastButtons(spellID)
	local list, listed, want = {}, {}, nil
	local find = C_ActionBar and C_ActionBar.FindSpellActionButtons
	local ok, slots = false, nil
	if type(find) == "function" then
		ok, slots = pcall(find, spellID)
	end
	if ok and Plain(slots, "table") then
		want = {}
		for _, slot in ipairs(slots) do
			if Plain(slot, "number") then
				want[slot] = true
			end
		end
	else
		local named, name = false, nil
		if C_Spell and type(C_Spell.GetSpellName) == "function" then
			named, name = pcall(C_Spell.GetSpellName, spellID)
		end
		if named and Plain(name, "string") and type(ns.ButtonsFor) == "function" then
			for _, button in ipairs(ns.ButtonsFor("spell", name:lower())) do
				if type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button) and not listed[button] and Visible(button) then
					list[#list + 1] = button
					listed[button] = true
				end
			end
		end
	end
	for _, button in ipairs(OwnButtons()) do
		if not listed[button] and Visible(button) then
			local slot = type(ns.OwnSlot) == "function" and ns.OwnSlot(button)
			if Plain(slot, "number") and ((want and want[slot]) or UsesSpell(slot, spellID)) then
				list[#list + 1] = button
				listed[button] = true
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

-- The aim highlight off on every button that pulses.
local function AimClear()
	for _, button in ipairs(CAST.aimed) do
		local made = CAST.frames[button]
		if made and made.pulse then
			made.pulse:Stop()
			made.aim:SetAlpha(0)
		end
	end
	CAST.aimed, CAST.aimSpell = {}, nil
end

-- The buttons pulse in the Cast colour while spellID waits for its spot (0 for a sample).
local function AimLight(buttons, spellID)
	AimClear()
	if not (On() and Opt("aimAnim")) then
		return
	end
	CAST.aimSpell = spellID
	local r, g, b = ns.Colour("castbars.castColour")
	for _, button in ipairs(buttons) do
		local made = CAST.frames[button]
		if made and made.pulse then
			made.aim:SetColorTexture(r, g, b, 1)
			made.aim:SetAlpha(CAST.AIM_LOW)
			made.pulse:Play()
			CAST.aimed[#CAST.aimed + 1] = button
		end
	end
end

-- A spell placed on the ground waits for its spot: its buttons pulse in the Cast colour until it is placed or cancelled.
local function AimStart(spellID)
	AimLight(CastButtons(spellID), spellID)
end

local function Yes(value)
	return Plain(value, "boolean") and value == true
end

-- The shown Flat UI buttons whose slot is current (IsCurrentAction), as { button, slot }: the game's checked rule (OwnPaint.lua STEP.checked) without
-- Attack and a repeating Auto Shot or wand, which are current while they swing or shoot.
local function CurrentButtons()
	local found = {}
	for _, button in ipairs(OwnButtons()) do
		local slot = type(ns.OwnSlot) == "function" and ns.OwnSlot(button)
		if Plain(slot, "number") and Visible(button) and Yes(ActionCall("IsCurrentAction", slot)) and not Yes(ActionCall("IsAutoRepeatAction", slot))
			and not Yes(ActionCall("IsAttackAction", slot)) then
			found[#found + 1] = { button, slot }
		end
	end
	return found
end

-- True when the buttons of list that have an aim frame are the ones that pulse now.
local function SameAim(list)
	local aimed, count = {}, 0
	for _, button in ipairs(CAST.aimed) do
		aimed[button] = true
	end
	for _, button in ipairs(list) do
		local made = CAST.frames[button]
		if made and made.pulse then
			if not aimed[button] then
				return false
			end
			count = count + 1
		end
	end
	return count == #CAST.aimed
end

-- The aim highlight without the reticle event, for a client that may not send it: while SpellIsTargeting says a spell waits for its spot or for a
-- click on its target, the buttons that became current with it pulse (the current slots of the steady state, a stance, form, aura or queued swing,
-- are left out; all current ones when that leaves none), until it is placed, cast or cancelled. A reticle aim of the game's (a plain spell ID)
-- is left alone, and replaces this one as it comes (AimStart).
local function AimCheck()
	if not (On() and Opt("aimAnim")) or type(SpellIsTargeting) ~= "function" then
		return
	end
	local ok, targeting = pcall(SpellIsTargeting)
	if not ok or not Plain(targeting, "boolean") then
		return
	end
	local current = CurrentButtons()
	if not targeting then
		CAST.steady = {}
		for _, pair in ipairs(current) do
			CAST.steady[pair[2]] = true
		end
		if CAST.aimSpell == CAST.AIM_FALLBACK then
			AimClear()
		end
		return
	end
	if CAST.aimSpell ~= nil and CAST.aimSpell ~= 0 and CAST.aimSpell ~= CAST.AIM_FALLBACK then
		return
	end
	local fresh, all = {}, {}
	for _, pair in ipairs(current) do
		all[#all + 1] = pair[1]
		if not CAST.steady[pair[2]] then
			fresh[#fresh + 1] = pair[1]
		end
	end
	local list = #fresh > 0 and fresh or all
	if #list == 0 then
		if CAST.aimSpell == CAST.AIM_FALLBACK then
			AimClear()
		end
	elseif not (CAST.aimSpell == CAST.AIM_FALLBACK and SameAim(list)) then
		AimLight(list, CAST.AIM_FALLBACK)
	end
end

-- Now, and once more a frame later, when the checked state of the buttons has followed.
local function AimSoon()
	AimCheck()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if type(ns.OwnOn) == "function" and ns.OwnOn() and not pcall(AimCheck) then
				pcall(AimClear)
			end
		end)
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
		-- A sample cast lands by itself at its end.
		if CAST.spell == 0 and now >= CAST.finish then
			CAST.landed = now
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

-- The frame whose OnUpdate draws the fill while a cast shows, made the first time.
local function CastDriver()
	if not CAST.driver then
		CAST.driver = CreateFrame("Frame")
		ns.Own[CAST.driver] = true
		CAST.driver:SetScript("OnUpdate", function()
			if not pcall(CastStep) then
				CastClear()
			end
		end)
	end
	return CAST.driver
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
	local r, g, b = ns.Colour(channel and "castbars.channelColour" or "castbars.castColour")
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
	CastDriver():Show()
	CastStep()
end

-- The times of the cast that shows, read again from the game after a pushback, in milliseconds; left as they were when the game gives none.
local function CastTimes()
	local read = CAST.channel and UnitChannelInfo or UnitCastingInfo
	if type(read) ~= "function" then
		return
	end
	local ok, _, _, _, start, finish = pcall(read, "player")
	if ok and ns.Finite(start) and ns.Finite(finish) and finish > start then
		CAST.start, CAST.finish = start / 1000, finish / 1000
	end
end

-- The events after which the aim highlight of a spell goes, when they are of that spell (AIM_OWN) or of any (AIM_ANY).
local AIM_OWN = { UNIT_SPELLCAST_SENT = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true }
local AIM_ANY = { UNIT_SPELLCAST_RETICLE_CLEAR = true, UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }

local function CastEvent(event, ...)
	-- Not a unit event: its argument is cancelledCast.
	if event == "CURRENT_SPELL_CAST_CHANGED" then
		AimSoon()
		return
	end
	local unit = ...
	if unit ~= "player" then
		return
	end
	-- The spell ID by the game's rule (ActionButton.lua:320-339): the fourth argument of SENT (unit, target, castGUID, spellID), the third of the others.
	local spellID
	if event == "UNIT_SPELLCAST_SENT" then
		spellID = select(4, ...)
	else
		spellID = select(3, ...)
	end
	-- The aim highlight: on while the spot is wanted; off as it is placed or cancelled, as another cast starts, or at an event of the aimed spell
	-- itself (the game's rule, ActionButton.lua:1077-1103): an Auto Shot or a wand shot while aiming leaves it on.
	if event == "UNIT_SPELLCAST_RETICLE_TARGET" then
		if Plain(spellID, "number") then
			AimStart(spellID)
		else
			AimClear()
		end
		return
	elseif #CAST.aimed > 0 and (AIM_ANY[event] or (AIM_OWN[event] and CAST.aimSpell ~= nil and Plain(spellID, "number") and spellID == CAST.aimSpell)) then
		AimClear()
	elseif CAST.aimSpell == CAST.AIM_FALLBACK and AIM_OWN[event] then
		-- The spell of an aim found by SpellIsTargeting is not known: any spell's event asks again, so a placed spell ends it and an Auto Shot leaves it.
		AimSoon()
	end
	if event == "UNIT_SPELLCAST_RETICLE_CLEAR" or event == "UNIT_SPELLCAST_SENT" or not Plain(spellID, "number") then
		return
	end
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		CastStart(spellID, event == "UNIT_SPELLCAST_CHANNEL_START")
		return
	end
	-- An event of another spell (an instant cast meanwhile, a spell the game refused) leaves the fill alone.
	local mine = CAST.spell ~= nil and spellID == CAST.spell
	if event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		-- Pushback: a cast set back, or a channel cut short. The times are read again; the next frame of CastStep draws from them.
		if mine and not CAST.landed then
			CastTimes()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- A channel's SUCCEEDED comes as it starts; a cast lands.
		if mine and not CAST.channel and not CAST.landed then
			CAST.landed = GetTime()
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		if mine then
			CastClear()
		end
		if On() and Opt("interruptAnim") then
			local r, g, b = ns.Colour("castbars.interruptedColour")
			for _, button in ipairs(CastButtons(spellID)) do
				local made = CAST.frames[button]
				if made then
					made.flash:SetColorTexture(r, g, b, 1)
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

-- Samples, out of combat. Without force, a sample that still shows is not started again, so a row changed many times in a row plays it once. A
-- real cast or aim that shows is never replaced.
local function SampleCast(button, force)
	local made = CAST.frames[button]
	if not made or not Opt("castAnim") or (CAST.spell ~= nil and CAST.spell ~= 0) or (CAST.spell == 0 and not force) then
		return
	end
	CastClear()
	local now = GetTime()
	CAST.lit, CAST.start, CAST.finish, CAST.channel, CAST.spell = { button }, now, now + CAST.SAMPLE_TIME, false, 0
	local r, g, b = ns.Colour("castbars.castColour")
	made.fill:SetColorTexture(r, g, b, 1)
	CastDriver():Show()
	CastStep()
end

local function SampleInterrupt(button, force)
	local made = CAST.frames[button]
	if not made or not Opt("interruptAnim") or (made.group:IsPlaying() and not force) then
		return
	end
	local r, g, b = ns.Colour("castbars.interruptedColour")
	made.flash:SetColorTexture(r, g, b, 1)
	made.group:Stop()
	made.group:Play()
	CAST.sample.flashed = button
end

local function SampleAim(button, force)
	local made = CAST.frames[button]
	if not (made and made.pulse) or not Opt("aimAnim") or (CAST.aimSpell ~= nil and CAST.aimSpell ~= 0) or (CAST.aimSpell == 0 and not force) then
		return
	end
	AimLight({ button }, 0)
	CAST.sample.aim = CAST.sample.aim + 1
	local token = CAST.sample.aim
	if C_Timer and C_Timer.After then
		C_Timer.After(CAST.SAMPLE_TIME, function()
			if CAST.aimSpell == 0 and CAST.sample.aim == token then
				AimClear()
			end
		end)
	end
end

-- The samples of the cast fill, the interrupt flash and the aim highlight (test mode and a change of a row, ActionBars.lua): spec.cast fills as a cast
-- of SAMPLE_TIME seconds that lands, spec.interrupt flashes in the Interrupted colour, spec.aim pulses for SAMPLE_TIME seconds, each a Flat UI button
-- or nil and each only while its row is on. Out of combat only.
function ns.ButtonEffectsSample(spec, force)
	if type(spec) ~= "table" or InCombatLockdown() or not On() or not (type(ns.OwnOn) == "function" and ns.OwnOn()) then
		return
	end
	CastPrepare()
	if Plain(spec.cast, "table") then
		SampleCast(spec.cast, force)
	end
	if Plain(spec.interrupt, "table") then
		SampleInterrupt(spec.interrupt, force)
	end
	if Plain(spec.aim, "table") then
		SampleAim(spec.aim, force)
	end
end

-- The cast bar's colours changed while samples show: they take them at once (Flat UI's own textures).
function ns.ButtonEffectsSampleLook()
	local r, g, b = ns.Colour("castbars.castColour")
	if CAST.spell == 0 then
		for _, button in ipairs(CAST.lit) do
			local made = CAST.frames[button]
			if made then
				made.fill:SetColorTexture(r, g, b, 1)
			end
		end
	end
	if CAST.aimSpell == 0 then
		for _, button in ipairs(CAST.aimed) do
			local made = CAST.frames[button]
			if made then
				made.aim:SetColorTexture(r, g, b, 1)
			end
		end
	end
	local made = CAST.sample.flashed and CAST.frames[CAST.sample.flashed]
	if made then
		local ir, ig, ib = ns.Colour("castbars.interruptedColour")
		made.flash:SetColorTexture(ir, ig, ib, 1)
	end
end

-- Test mode ends or pauses: the samples that show go.
function ns.ButtonEffectsSampleOff()
	if CAST.spell == 0 then
		CastClear()
	end
	if CAST.aimSpell == 0 then
		AimClear()
	end
	local made = CAST.sample.flashed and CAST.frames[CAST.sample.flashed]
	if made then
		made.group:Stop()
	end
	CAST.sample.flashed = nil
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
	if not (on and Opt("aimAnim")) then
		AimClear()
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

-- The player's casts, for the cast fill, the interrupt flash and the aim highlight of Flat UI's own buttons.
local casts = CreateFrame("Frame")
ns.Own[casts] = true
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_RETICLE_TARGET", "UNIT_SPELLCAST_RETICLE_CLEAR", "UNIT_SPELLCAST_SENT" }) do
	pcall(casts.RegisterUnitEvent, casts, event, "player")
end
pcall(casts.RegisterEvent, casts, "CURRENT_SPELL_CAST_CHANGED")
casts:SetScript("OnEvent", function(_, event, ...)
	if type(ns.OwnOn) == "function" and ns.OwnOn() then
		if not pcall(CastEvent, event, ...) then
			pcall(CastClear)
			pcall(AimClear)
		end
	end
end)

if type(ns.OnOwnBuilt) == "function" then
	ns.OnOwnBuilt(CastPrepare)
end

-- The rows of the Glows and animations page call this. Cast fill animation, Interrupt flash or Aim highlight turned on plays its sample once on the
-- first shown button of Flat UI's main bar, out of combat while the options window shows and test mode is off (test mode plays them itself).
local PREVIEW = { [PATH .. "castAnim"] = "cast", [PATH .. "interruptAnim"] = "interrupt", [PATH .. "aimAnim"] = "aim" }

function ns.ButtonEffectsChanged(path)
	Hook()
	Ask()
	local kind = PREVIEW[path]
	local mode = ns.TestMode
	if not kind or Opt(kind .. "Anim") ~= true or InCombatLockdown() or (mode and mode.IsOn()) or type(ns.PanelShown) ~= "function"
		or not ns.PanelShown() or type(ns.ButtonSamples) ~= "function" then
		return
	end
	local first = ns.ButtonSamples()[1]
	if first then
		ns.ButtonEffectsSample({ [kind] = first })
	end
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
