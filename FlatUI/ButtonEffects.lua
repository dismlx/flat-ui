local _, ns = ...

local KEY = "actionbars"
local PATH = KEY .. "."
local NO_ASSIST = "Rotation helper highlight: the game has no rotation helper."
local NO_EXTRA = "Extra button artwork: the game has no extra action button."
local REFUSED = "Proc glow: the game refused the change."
local STOPPED = "Glows and animations: the last change failed with an error."
local WEAK = { __mode = "k" }

local shown = setmetatable({}, WEAK)
local marked = setmetatable({}, WEAK)
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

local function Plainly(button)
	local manager = _G.ActionButtonSpellAlertManager
	if not Plain(manager, "table") or not Plain(manager.activeAlerts, "table") or not Plain(manager.SpellAlertType, "table") then
		return true
	end
	return manager.activeAlerts[button] == manager.SpellAlertType.Default
end

local procOn = setmetatable({}, WEAK)
local listenedOwn = false
local GLOW = { button = nil, ends = 0, held = false, left = nil, token = 0, TIME = 3 }
local Ask

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
	if GLOW.button == button and (GLOW.held or GetTime() < GLOW.ends) then
		return true
	end
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

local CAST = { frames = setmetatable({}, WEAK), lit = {}, aimed = {}, pending = false, FADE = 0.2, ALPHA = 0.4, FLASH = 0.7, AIM_LOW = 0.15, AIM_HIGH = 0.5,
	AIM_TIME = 0.5, sample = { aim = 0 }, SAMPLE_TIME = 2,
	AIM_FALLBACK = -1, steady = {}, steadyQueued = false }

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

local function Visible(button)
	local ok, shown = pcall(button.IsVisible, button)
	return ok and not ns.IsSecret(shown) and shown == true
end

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

local function FillColour(channel)
	if ns.Enabled("castbars") and ns.Get("castbars.flat") == true and ns.Get("castbars.playerClass") == true then
		local r, g, b = ns.ClassColour()
		if r then
			return r, g, b
		end
	end
	return ns.Colour(channel and "castbars.channelColour" or "castbars.castColour")
end

local function AimLight(buttons, spellID)
	AimClear()
	if not (On() and Opt("aimAnim")) then
		return
	end
	CAST.aimSpell = spellID
	local r, g, b = FillColour(false)
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

local function AimStart(spellID)
	AimLight(CastButtons(spellID), spellID)
end

local function Yes(value)
	return Plain(value, "boolean") and value == true
end

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

local function SteadySoon()
	if CAST.steadyQueued or not (C_Timer and C_Timer.After) then
		return
	end
	CAST.steadyQueued = true
	C_Timer.After(0, function()
		CAST.steadyQueued = false
		if type(ns.OwnOn) == "function" and ns.OwnOn() and not pcall(AimCheck) then
			pcall(AimClear)
		end
	end)
end

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
	local r, g, b = FillColour(channel)
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

local AIM_OWN = { UNIT_SPELLCAST_SENT = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true }
local AIM_ANY = { UNIT_SPELLCAST_RETICLE_CLEAR = true, UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }

local function CastEvent(event, ...)
	if event == "CURRENT_SPELL_CAST_CHANGED" then
		AimSoon()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_UPDATE_STATE" then
		SteadySoon()
		return
	end
	local unit = ...
	if unit ~= "player" then
		return
	end
	local spellID
	if event == "UNIT_SPELLCAST_SENT" then
		spellID = select(4, ...)
	else
		spellID = select(3, ...)
	end
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
		AimSoon()
	end
	if event == "UNIT_SPELLCAST_RETICLE_CLEAR" or event == "UNIT_SPELLCAST_SENT" or not Plain(spellID, "number") then
		return
	end
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		CastStart(spellID, event == "UNIT_SPELLCAST_CHANNEL_START")
		return
	end
	local mine = CAST.spell ~= nil and spellID == CAST.spell
	if event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		if mine and not CAST.landed then
			CastTimes()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
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
		CastClear()
	end
end

local function SampleCast(button, force)
	local made = CAST.frames[button]
	if not made or not Opt("castAnim") or (CAST.spell ~= nil and CAST.spell ~= 0) or (CAST.spell == 0 and not force) then
		return
	end
	CastClear()
	local now = GetTime()
	CAST.lit, CAST.start, CAST.finish, CAST.channel, CAST.spell = { button }, now, now + CAST.SAMPLE_TIME, false, 0
	local r, g, b = FillColour(false)
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

local function SampleAimFor(seconds)
	local sample = CAST.sample
	sample.aim = sample.aim + 1
	sample.aimArmed = GetTime()
	sample.aimEnds = sample.aimArmed + seconds
	local token = sample.aim
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds, function()
			if CAST.aimSpell == 0 and sample.aim == token then
				AimClear()
			end
		end)
	end
end

local function SampleAim(button, force)
	local made = CAST.frames[button]
	if not (made and made.pulse) or not Opt("aimAnim") or (CAST.aimSpell ~= nil and CAST.aimSpell ~= 0) or (CAST.aimSpell == 0 and not force) then
		return
	end
	AimLight({ button }, 0)
	SampleAimFor(CAST.SAMPLE_TIME)
end

local SAMPLE_HELD = 0.6

local function GlowEndsIn(seconds)
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds + 0.05, function()
			if GLOW.button and not GLOW.held and GetTime() >= GLOW.ends then
				GLOW.button = nil
				Ask()
			end
		end)
	end
end

local function GlowLight(button, keep)
	local now = GetTime()
	if keep and GLOW.button == button and (GLOW.held or now < GLOW.ends) then
		return
	end
	GLOW.button, GLOW.ends = button, now + GLOW.TIME
	if CAST.sample.heldAt then
		GLOW.held, GLOW.left = true, GLOW.TIME
	else
		GLOW.held, GLOW.left = false, nil
		GlowEndsIn(GLOW.TIME)
	end
	Ask()
end

local function GlowSample(button, keep, after)
	GLOW.token = GLOW.token + 1
	if not (after and after > 0 and C_Timer and C_Timer.After) then
		GlowLight(button, keep)
		return
	end
	local token = GLOW.token
	C_Timer.After(after, function()
		if GLOW.token == token and not InCombatLockdown() and On() then
			GlowLight(button, keep)
		end
	end)
end

local function GlowOff()
	GLOW.token = GLOW.token + 1
	if GLOW.button then
		GLOW.button, GLOW.held, GLOW.left = nil, false, nil
		Ask()
	end
end

local function SampleFreeze()
	local sample, now = CAST.sample, GetTime()
	local was = sample.heldAt
	sample.heldAt = now
	if GLOW.button and not GLOW.held then
		GLOW.held, GLOW.left = true, math.max(0, GLOW.ends - now)
	end
	if CAST.spell == 0 then
		CAST.start, CAST.landed = now - CAST.SAMPLE_TIME * SAMPLE_HELD, nil
		CAST.finish = CAST.start + CAST.SAMPLE_TIME
		CastStep()
		if CAST.driver then
			CAST.driver:Hide()
		end
	end
	if CAST.aimSpell == 0 then
		if was == nil or (sample.aimArmed or 0) >= was then
			sample.aimLeft = math.max(0, (sample.aimEnds or now) - now)
		end
		sample.aim = sample.aim + 1
		for _, button in ipairs(CAST.aimed) do
			local made = CAST.frames[button]
			if made and made.pulse then
				made.pulse:Stop()
				made.aim:SetAlpha(CAST.AIM_HIGH)
			end
		end
	end
end

local function SampleThaw()
	local sample = CAST.sample
	if not sample.heldAt then
		return
	end
	local gap = GetTime() - sample.heldAt
	sample.heldAt = nil
	if GLOW.button and GLOW.held then
		GLOW.held, GLOW.ends = false, GetTime() + (GLOW.left or GLOW.TIME)
		GlowEndsIn(GLOW.left or GLOW.TIME)
		GLOW.left = nil
	end
	if CAST.spell == 0 then
		CAST.start, CAST.finish = CAST.start + gap, CAST.finish + gap
		CastDriver():Show()
	end
	if CAST.aimSpell == 0 then
		for _, button in ipairs(CAST.aimed) do
			local made = CAST.frames[button]
			if made and made.pulse then
				made.aim:SetAlpha(CAST.AIM_LOW)
				made.pulse:Play()
			end
		end
		SampleAimFor(sample.aimLeft or CAST.SAMPLE_TIME)
	end
end

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
	if Plain(spec.glow, "table") then
		GlowSample(spec.glow, not force, spec.interrupt == spec.glow and CAST.FLASH or nil)
	end
	if CAST.sample.heldAt then
		SampleFreeze()
	end
end

function ns.ButtonEffectsSampleHold(held)
	if held then
		SampleFreeze()
	else
		SampleThaw()
	end
end

function ns.ButtonEffectsSampleLook()
	local r, g, b = FillColour(false)
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

function ns.ButtonEffectsPreviewing()
	local mode = ns.TestMode
	if mode and mode.IsOn() then
		return false
	end
	if CAST.spell == 0 or CAST.aimSpell == 0 then
		return true
	end
	local made = CAST.sample.flashed and CAST.frames[CAST.sample.flashed]
	if made and made.group:IsPlaying() then
		return true
	end
	return GLOW.button ~= nil and (GLOW.held or GetTime() < GLOW.ends)
end

function ns.ButtonEffectsSampleOff()
	CAST.sample.heldAt = nil
	GlowOff()
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

local function Hook()
	if ns.HandsOff() and not ns.Enabled("actionbars") then
		return
	end
	Attach(Ask)
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

local casts = CreateFrame("Frame")
ns.Own[casts] = true
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_RETICLE_TARGET", "UNIT_SPELLCAST_RETICLE_CLEAR", "UNIT_SPELLCAST_SENT" }) do
	pcall(casts.RegisterUnitEvent, casts, event, "player")
end
pcall(casts.RegisterEvent, casts, "CURRENT_SPELL_CAST_CHANGED")
pcall(casts.RegisterEvent, casts, "PLAYER_ENTERING_WORLD")
pcall(casts.RegisterEvent, casts, "ACTIONBAR_UPDATE_STATE")
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

local PREVIEW = { [PATH .. "castAnim"] = "cast", [PATH .. "interruptAnim"] = "interrupt", [PATH .. "aimAnim"] = "aim", [PATH .. "proc"] = "glow",
	[PATH .. "procColour"] = "glow" }

function ns.ButtonEffectsChanged(path)
	Hook()
	Ask()
	local kind = PREVIEW[path]
	local mode = ns.TestMode
	local wanted = kind == "glow" and Opt("proc") ~= "off" or kind ~= "glow" and kind ~= nil and Opt(kind .. "Anim") == true
	if not wanted or InCombatLockdown() or (mode and mode.IsOn()) or type(ns.PanelShown) ~= "function"
		or not ns.PanelShown() or type(ns.ButtonSamples) ~= "function" then
		return
	end
	local first = ns.ButtonSamples()[1]
	if first then
		ns.ButtonEffectsSample({ [kind] = first }, kind == "glow" or nil)
	end
end

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
