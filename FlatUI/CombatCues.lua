local _, ns = ...

local KEY, PART = "combattext", "combat alerts"
local LIFE, FADE_FROM, STEP, DELAY, SOUND_GAP, HEIGHT = 1.9, 1.3, 0.05, 1, 3, 25
local BREATHE_TO, BREATHE_TIME, POP_FROM, POP_TIME = 0.55, 0.6, 1.3, 0.15
local WARN_FADE = 0.25
local MOVER, WIDTH, TALL, GAP, X, Y = "FlatUICombatCues", 200, 170, 2, 0, 100
local WORDS = { enter = { "COMBAT_TEXT_ENTERING_COMBAT", "ENTERING_COMBAT", "+Combat" }, leave = { "COMBAT_TEXT_LEAVING_COMBAT", "LEAVING_COMBAT", "-Combat" },
	health = { "COMBAT_TEXT_HEALTH_LOW", "HEALTH_LOW", "Low health" }, mana = { "COMBAT_TEXT_MANA_LOW", "MANA_LOW", "Low mana" } }
local NO_TARGET = "No target"
local LOOKS = { enter = { "combatEnterColour", "combatStateSize" }, leave = { "combatLeaveColour", "combatStateSize" }, warn = { "noTargetColour", "noTargetSize" },
	low = { "lowColour", "noTargetSize" }, mana = { "lowManaColour", "noTargetSize" } }
local LOW_AT, MANA = 0.2, 0
local LOW_SAMPLE = { health = "  15%", mana = "  12%" }
local LOW_KINDS = { "health", "mana" }
local LOW_UNIT_EVENTS = { UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health", UNIT_POWER_UPDATE = "mana", UNIT_MAXPOWER = "mana", UNIT_DISPLAYPOWER = "mana" }
local LOW_EVENTS = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local AGAIN = 1
local TARGET_EVENTS = { "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_FACTION" }

local S = { fighting = false, warned = false, listening = false, blind = false, healer = false, flashes = 0, warnings = 0, withheld = 0, silent = 0,
	stateSounds = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function On()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART)
end

local function WarnWanted()
	return On() and Opt("noTarget") == true
end

local function FlashWanted()
	return On() and Opt("combatState") == true
end

local function LowWanted()
	return On() and Opt("lowHealth") == true
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

local function Now()
	local now = Ask(GetTime)
	return ns.Finite(now) and now or nil
end

local function InFight()
	local fight = Ask(UnitAffectingCombat, "player")
	if type(fight) == "boolean" then
		return fight
	end
	return Ask(InCombatLockdown) == true
end

local function InterfaceShown()
	if UIParent == nil or ns.Forbidden(UIParent) then
		return false
	end
	return Ask(UIParent.IsShown, UIParent) == true
end

local function Global(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function Words(kind)
	local words = WORDS[kind]
	return Global(words[1]) or Global(words[2]) or words[3]
end

function ns.CombatCueWords(kind)
	if WORDS[kind] then
		return Words(kind)
	end
	return nil
end

local function Template()
	local ok, font = pcall(function()
		return _G.CombatTextFont
	end)
	if ok and not ns.IsSecret(font) and type(font) == "table" then
		return "CombatTextFont"
	end
	return "NumberFontNormalHuge"
end

local function Breathe(line)
	local ok, group = pcall(function()
		local made = line:CreateAnimationGroup()
		made:SetLooping("BOUNCE")
		local fade = made:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(BREATHE_TO)
		fade:SetDuration(BREATHE_TIME)
		pcall(fade.SetSmoothing, fade, "IN_OUT")
		return made
	end)
	return ok and not ns.IsSecret(group) and type(group) == "table" and group or nil
end

local function Pop(line)
	local ok, group = pcall(function()
		line:SetScaleAnimationMode(Enum and Enum.FontStringScaleAnimationMode and Enum.FontStringScaleAnimationMode.Vertex or 1)
		local made = line:CreateAnimationGroup()
		local scale = made:CreateAnimation("Scale")
		scale:SetScaleFrom(POP_FROM, POP_FROM)
		scale:SetScaleTo(1, 1)
		scale:SetDuration(POP_TIME)
		scale:SetOrigin("CENTER", 0, 0)
		return made
	end)
	return ok and not ns.IsSecret(group) and type(group) == "table" and group or nil
end

local function Animate(group, play)
	if group then
		pcall(group.Stop, group)
		if play then
			pcall(group.Play, group)
		end
	end
end

local function Make()
	if S.frame then
		return true
	elseif S.unmade or type(CreateFrame) ~= "function" or UIParent == nil then
		return false
	end
	local made, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not made or ns.IsSecret(frame) or type(frame) ~= "table" then
		S.unmade = true
		return false
	end
	ns.Own[frame] = true
	pcall(frame.SetSize, frame, WIDTH, TALL)
	pcall(frame.SetFrameStrata, frame, "HIGH")
	pcall(frame.EnableMouse, frame, false)
	local template = Template()
	local flash, warn = ns.OwnText(frame, "OVERLAY", template), ns.OwnText(frame, "OVERLAY", template)
	if not (flash and warn) then
		pcall(frame.Hide, frame)
		S.unmade = true
		return false
	end
	pcall(flash.SetPoint, flash, "BOTTOM", frame, "CENTER", 0, GAP)
	pcall(warn.SetPoint, warn, "TOP", frame, "CENTER", 0, -GAP)
	for _, line in ipairs({ flash, warn }) do
		pcall(line.SetJustifyH, line, "CENTER")
		pcall(line.Hide, line)
	end
	local read, file = pcall(flash.GetFont, flash)
	if read and not ns.IsSecret(file) and type(file) == "string" and file ~= "" then
		S.file = file
	end
	S.frame, S.flash, S.warn = frame, flash, warn
	S.breathe, S.pop = Breathe(warn), Pop(flash)
	return true
end

local function Place()
	local frame = S.frame
	if not frame then
		return
	end
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "CENTER")
	end
	frame:ClearAllPoints()
	if ns.Finite(x) and ns.Finite(y) then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", X, Y)
	end
end

local function Look(line, kind)
	local rows = LOOKS[kind]
	local height = HEIGHT * (Opt(rows[2]) or 100) / 100
	local set, result = false, nil
	if S.file then
		set, result = pcall(line.SetFont, line, S.file, height, "OUTLINE")
	end
	if not set or result == false then
		pcall(line.SetTextHeight, line, height)
	end
	pcall(line.SetTextColor, line, ns.Colour(KEY .. "." .. rows[1]))
end

local function Shown()
	if S.frame then
		pcall(S.frame.SetShown, S.frame, S.flashAt ~= nil or S.warned or S.fading == true or (S.low ~= nil and LowWanted()))
	end
end

local function StopTicker()
	local token = S.ticker
	S.ticker = nil
	if token and token.handle and type(token.handle.Cancel) == "function" then
		pcall(token.handle.Cancel, token.handle)
	end
end

local function EndFlash()
	StopTicker()
	S.flashAt, S.flashKind = nil, nil
	Animate(S.pop, false)
	if S.flash then
		pcall(S.flash.Hide, S.flash)
		pcall(S.flash.SetAlpha, S.flash, 1)
	end
	Shown()
end

local function Step()
	local now, at = Now(), S.flashAt
	if not (S.flash and at and now) or now < at or now - at >= LIFE or not InterfaceShown() then
		EndFlash()
		return
	end
	local t = now - at
	local alpha = t <= FADE_FROM and 1 or math.max(0, math.min(1, 1 - (t - FADE_FROM) / (LIFE - FADE_FROM)))
	S.flash:SetAlpha(alpha)
end

local Run

local function StartTicker()
	if S.ticker then
		return
	end
	local token = {}
	S.ticker = token
	if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
		local ok, handle = pcall(C_Timer.NewTicker, STEP, function()
			if S.ticker == token then
				Run(Step)
			end
		end)
		token.handle = ok and not ns.IsSecret(handle) and handle or nil
	end
	if token.handle then
		return
	end
	local function Later(fn)
		return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, STEP, fn)
	end
	local function Again()
		if S.ticker == token then
			Run(Step)
			if S.ticker == token and not Later(Again) then
				S.ticker = nil
			end
		end
	end
	if not Later(Again) then
		S.ticker = nil
	end
end

local function Length(seconds)
	local whole = math.floor(seconds + 0.5)
	local hours, minutes, rest = math.floor(whole / 3600), math.floor(whole % 3600 / 60), whole % 60
	if hours > 0 then
		return ("%d:%02d:%02d"):format(hours, minutes, rest)
	end
	return ("%d:%02d"):format(minutes, rest)
end

local function FlashText(kind)
	local extra = kind == "leave" and Opt("combatLength") == true and S.flashExtra or nil
	return extra and (Words(kind) .. "  " .. extra) or Words(kind)
end

local function Flash(kind, quiet, extra)
	if not FlashWanted() or not InterfaceShown() then
		return
	end
	local now = Now()
	if not now or not Make() then
		return
	end
	local line = S.flash
	S.flashExtra = extra
	line:SetText(FlashText(kind))
	Look(line, kind)
	line:SetAlpha(1)
	line:Show()
	Animate(S.pop, true)
	S.flashAt, S.flashKind = now, kind
	S.flashes = S.flashes + 1
	Place()
	Shown()
	StartTicker()
	local sound = not quiet and ns.SOUNDS and ns.SOUNDS[KITS[Opt(kind == "enter" and "combatEnterSound" or "combatLeaveSound")] or 0]
	if sound and ns.PlayKit(sound[1]) then
		S.stateSounds = S.stateSounds + 1
	end
end

local function WarnFade()
	if S.warnFade == nil and S.warn then
		local line = S.warn
		local ok, group = pcall(function()
			local made = line:CreateAnimationGroup()
			local fade = made:CreateAnimation("Alpha")
			fade:SetFromAlpha(1)
			fade:SetToAlpha(0)
			fade:SetDuration(WARN_FADE)
			made:SetToFinalAlpha(true)
			made:SetScript("OnFinished", function()
				S.fading = nil
				pcall(line.Hide, line)
				pcall(line.SetAlpha, line, 1)
				Shown()
			end)
			return made
		end)
		S.warnFade = ok and not ns.IsSecret(group) and type(group) == "table" and group or false
	end
	return S.warnFade or nil
end

local function StopFade(hide)
	if not S.fading then
		return
	end
	S.fading = nil
	Animate(S.warnFade or nil, false)
	if hide and S.warn then
		pcall(S.warn.Hide, S.warn)
	end
	if S.warn then
		pcall(S.warn.SetAlpha, S.warn, 1)
	end
	Shown()
end

local function HideWarning(quick)
	S.missingAt, S.waiting = nil, nil
	if quick then
		StopFade(true)
	end
	if S.warned then
		S.warned = false
		Animate(S.breathe, false)
		if S.warn then
			local fade = not quick and InterfaceShown() and WarnFade()
			if fade and pcall(fade.Play, fade) then
				S.fading = true
			else
				pcall(S.warn.Hide, S.warn)
				pcall(S.warn.SetAlpha, S.warn, 1)
			end
		end
		Shown()
	end
end

local function Sound()
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[Opt("noTargetSound")] or 0]
	local now = Now()
	if not sound or not now or (S.soundAt and now >= S.soundAt and now - S.soundAt < SOUND_GAP) or not InterfaceShown() then
		return
	end
	if ns.PlayKit(sound[1]) then
		S.soundAt, S.silent = now, 0
	elseif not (ns.IconRow and ns.IconRow.sound == "throttled") then
		S.silent = S.silent + 1
	elseif type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		local shown = S.warnings
		pcall(C_Timer.After, AGAIN, function()
			if S.warned and S.warnings == shown then
				Run(Sound)
			end
		end)
	end
end

local function WarnText()
	if Opt("noTargetKey") ~= true or S.healer then
		return NO_TARGET
	end
	local key = Ask(GetBindingKey, "TARGETNEARESTENEMY")
	if type(key) ~= "string" or key == "" then
		return NO_TARGET
	end
	local words = Ask(GetBindingText, key)
	return NO_TARGET .. "  (" .. ((type(words) == "string" and words ~= "") and words or key) .. ")"
end

local function ShowWarning()
	if S.warned or not Make() then
		return
	end
	StopFade(false)
	local line = S.warn
	line:SetText(WarnText())
	Look(line, "warn")
	line:Show()
	Animate(S.breathe, true)
	if S.low then
		for _, kind in ipairs(LOW_KINDS) do
			local rec = S.low[kind]
			if rec.on then
				Animate(rec.breathe, true)
			end
		end
	end
	S.warned = true
	S.warnings = S.warnings + 1
	Place()
	Shown()
	Sound()
end

local function LowAt(kind)
	local at = Opt(kind == "mana" and "lowManaAt" or "lowHealthAt")
	if ns.Finite(at) and at > 0 and at <= 100 then
		return at / 100
	end
	return LOW_AT
end

local function LowCurve(kind)
	if S.lowRefused then
		return nil
	end
	local at = LowAt(kind)
	S.lowCurves = S.lowCurves or {}
	local kept = S.lowCurves[kind]
	if kept and kept.at == at then
		return kept.curve
	end
	local ok, curve = pcall(function()
		local made = C_CurveUtil.CreateCurve()
		made:SetType(Enum.LuaCurveType.Step)
		made:AddPoint(0, 1)
		made:AddPoint(at, 0)
		return made
	end)
	if ok and curve ~= nil and not ns.IsSecret(curve) then
		S.lowCurves[kind] = { at = at, curve = curve }
		return curve
	end
	S.lowRefused = true
	return nil
end

local function MakeLow()
	if S.low then
		return true
	elseif S.lowRefused or not Make() then
		return false
	end
	local low = {}
	for _, kind in ipairs(LOW_KINDS) do
		local made, holder = pcall(CreateFrame, "Frame", nil, S.frame)
		local line = made and not ns.IsSecret(holder) and type(holder) == "table" and ns.OwnText(holder, "OVERLAY", Template()) or nil
		if not line then
			S.lowRefused = true
			return false
		end
		ns.Own[holder] = true
		pcall(holder.SetAllPoints, holder, S.frame)
		pcall(holder.EnableMouse, holder, false)
		pcall(holder.Hide, holder)
		pcall(line.SetJustifyH, line, "CENTER")
		low[kind] = { holder = holder, line = line, breathe = Breathe(line) }
	end
	S.low = low
	return true
end

local function LookLow()
	if not S.low then
		return
	end
	local step = HEIGHT * (Opt("noTargetSize") or 100) / 100 + GAP
	local sample = S.lowSampled and Opt("lowShare") == true
	for index, kind in ipairs(LOW_KINDS) do
		local line = S.low[kind].line
		line:SetText(sample and Words(kind) .. LOW_SAMPLE[kind] or Words(kind))
		Look(line, kind == "mana" and "mana" or "low")
		line:ClearAllPoints()
		line:SetPoint("TOP", S.frame, "CENTER", 0, -GAP - step * index)
	end
end

local function LowFade(rec)
	if rec.fade == nil then
		local line, holder = rec.line, rec.holder
		local ok, group = pcall(function()
			local made = line:CreateAnimationGroup()
			local fade = made:CreateAnimation("Alpha")
			fade:SetFromAlpha(1)
			fade:SetToAlpha(0)
			fade:SetDuration(WARN_FADE)
			made:SetToFinalAlpha(true)
			made:SetScript("OnFinished", function()
				rec.fading = nil
				pcall(holder.Hide, holder)
				pcall(line.SetAlpha, line, 1)
			end)
			return made
		end)
		rec.fade = ok and not ns.IsSecret(group) and type(group) == "table" and group or false
	end
	return rec.fade or nil
end

local function StopLowFade(rec, hide)
	if not rec.fading then
		return
	end
	rec.fading = nil
	Animate(rec.fade or nil, false)
	if hide then
		pcall(rec.holder.Hide, rec.holder)
	end
	pcall(rec.line.SetAlpha, rec.line, 1)
end

local function ShowLow(rec, on, quick)
	quick = quick or S.lowQuick
	if rec.on == on then
		if quick and not on then
			StopLowFade(rec, true)
		end
		return
	end
	rec.on = on
	if on then
		StopLowFade(rec, false)
		pcall(rec.holder.Show, rec.holder)
		Animate(rec.breathe, true)
		if S.warned then
			Animate(S.breathe, true)
		end
		for _, kind in ipairs(LOW_KINDS) do
			local other = S.low and S.low[kind]
			if other and other ~= rec and other.on then
				Animate(other.breathe, true)
			end
		end
		return
	end
	Animate(rec.breathe, false)
	pcall(rec.line.SetAlpha, rec.line, 1)
	local fade = not quick and InterfaceShown() and LowFade(rec)
	if fade and pcall(fade.Play, fade) then
		rec.fading = true
	else
		pcall(rec.holder.Hide, rec.holder)
	end
end

local function HealthAlpha(holder, curve)
	holder:SetAlpha(UnitHealthPercent("player", true, curve))
end

local function ManaAlpha(holder, curve)
	holder:SetAlpha(UnitPowerPercent("player", MANA, false, curve))
end

local function Hundred()
	local ok, curve = pcall(function()
		return CurveConstants.ScaleTo100
	end)
	if ok and curve ~= nil and not ns.IsSecret(curve) then
		return curve
	end
	return nil
end

local function ShareText(line, kind, hundred)
	if kind == "health" then
		line:SetFormattedText("%s  %.0f%%", Words(kind), UnitHealthPercent("player", true, hundred))
	else
		line:SetFormattedText("%s  %.0f%%", Words(kind), UnitPowerPercent("player", MANA, false, hundred))
	end
end

local function PaintShare(rec, kind)
	if Opt("lowShare") ~= true then
		return
	end
	local hundred = Hundred()
	if hundred and pcall(ShareText, rec.line, kind, hundred) then
		S.shared = true
		return
	end
	S.shareRefused = true
	pcall(rec.line.SetText, rec.line, Words(kind))
end

local function PaintLow(kind)
	local rec = S.low and S.low[kind]
	if not rec or S.lowSampled then
		return
	end
	local fight = Opt("lowFight") ~= true or S.fighting
	local curve = LowWanted() and fight and not S.lowRefused and Ask(UnitIsDeadOrGhost, "player") ~= true and LowCurve(kind)
	local on = false
	if curve and kind == "health" then
		on = pcall(HealthAlpha, rec.holder, curve)
		S.lowRefused = not on
		if not on then
			ShowLow(S.low.mana, false)
		end
	elseif curve and not S.manaRefused and Ask(UnitPowerType, "player") == MANA then
		on = pcall(ManaAlpha, rec.holder, curve)
		S.manaRefused = not on
	end
	if on then
		PaintShare(rec, kind)
	end
	ShowLow(rec, on)
end

local function PaintHealth()
	PaintLow("health")
end

local function PaintMana()
	PaintLow("mana")
end

local function PaintBoth()
	PaintLow("health")
	PaintLow("mana")
end

local function OnPlayerEvent(_, event, unit)
	local kind = LOW_UNIT_EVENTS[event]
	if kind == nil then
		Run(PaintBoth)
	elseif not ns.IsSecret(unit) and unit == "player" then
		Run(kind == "health" and PaintHealth or PaintMana)
	end
end

local function ListenLow(on)
	if on and not S.lowListening then
		if not S.lowListener then
			local made, frame = pcall(CreateFrame, "Frame")
			if not made or ns.IsSecret(frame) or type(frame) ~= "table" then
				return
			end
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnPlayerEvent)
			S.lowListener = frame
		end
		local frame = S.lowListener
		for event in pairs(LOW_UNIT_EVENTS) do
			local done = false
			if frame.RegisterUnitEvent then
				local ok, result = pcall(frame.RegisterUnitEvent, frame, event, "player")
				done = ok and (ns.IsSecret(result) or result ~= false)
			end
			if not done then
				pcall(frame.RegisterEvent, frame, event)
			end
		end
		for _, event in ipairs(LOW_EVENTS) do
			pcall(frame.RegisterEvent, frame, event)
		end
		S.lowListening = true
	elseif not on and S.lowListening then
		pcall(S.lowListener.UnregisterAllEvents, S.lowListener)
		S.lowListening = false
	end
end

local function HideLow()
	ListenLow(false)
	S.lowSampled = nil
	if S.low then
		for _, kind in ipairs(LOW_KINDS) do
			ShowLow(S.low[kind], false, true)
		end
	end
	Shown()
end

local function ApplyLow()
	if LowWanted() and MakeLow() then
		LookLow()
		ListenLow(true)
		PaintBoth()
		Place()
		Shown()
	else
		HideLow()
	end
end

local function ReadRole()
	if Ask(InCombatLockdown) == true or type(ns.PlayerRole) ~= "function" then
		return
	end
	local ok, role = pcall(ns.PlayerRole)
	S.healer = ok and not ns.IsSecret(role) and role == "healer"
end

local function Missing()
	local exists = Ask(UnitExists, "target")
	if type(exists) ~= "boolean" then
		return nil
	elseif not exists then
		return true
	end
	local dead = Ask(UnitIsDeadOrGhost, "target")
	if type(dead) ~= "boolean" then
		return nil
	elseif dead then
		return true
	end
	local attack = Ask(UnitCanAttack, "player", "target")
	if type(attack) ~= "boolean" then
		return nil
	end
	return not attack and Opt("noTargetFriendly") == true and not S.healer
end

local Wait

local function Judge()
	if S.sampled and not S.fighting then
		if WarnWanted() then
			return
		end
		S.sampled = nil
	end
	if not (WarnWanted() and S.fighting) then
		HideWarning()
		return
	end
	local missing = Missing()
	if missing == nil then
		if not S.blind then
			S.blind, S.withheld = true, S.withheld + 1
		end
		HideWarning()
		return
	end
	S.blind = false
	if not missing then
		HideWarning()
		return
	elseif S.warned then
		return
	end
	local now = Now()
	if not now then
		return
	end
	if not S.missingAt or now < S.missingAt then
		S.missingAt = now
	end
	local left = DELAY - (now - S.missingAt)
	if left > 0 then
		Wait(left)
		return
	end
	ShowWarning()
end

Wait = function(left)
	if S.waiting or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	local token = {}
	S.waiting = token
	if not pcall(C_Timer.After, left, function()
		if S.waiting == token then
			S.waiting = nil
			Run(Judge)
		end
	end) then
		S.waiting = nil
	end
end

local function OnTargetEvent(_, _, unit)
	if not ns.IsSecret(unit) and unit == "target" then
		Run(Judge)
	end
end

local function Listen(on)
	if on and not S.listening then
		if not S.listener then
			local made, frame = pcall(CreateFrame, "Frame")
			if not made or ns.IsSecret(frame) or type(frame) ~= "table" then
				return
			end
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnTargetEvent)
			S.listener = frame
		end
		local frame = S.listener
		for _, event in ipairs(TARGET_EVENTS) do
			local done = false
			if frame.RegisterUnitEvent then
				local ok, result = pcall(frame.RegisterUnitEvent, frame, event, "target")
				done = ok and (ns.IsSecret(result) or result ~= false)
			end
			if not done then
				pcall(frame.RegisterEvent, frame, event)
			end
		end
		S.listening = true
	elseif not on and S.listening then
		for _, event in ipairs(TARGET_EVENTS) do
			pcall(S.listener.UnregisterEvent, S.listener, event)
		end
		S.listening = false
	end
end

local function HideAll()
	EndFlash()
	HideWarning(true)
	Listen(false)
	HideLow()
	S.fightAt = nil
end

Run = function(fn)
	if ns.PartStopped(KEY, PART) then
		return
	end
	if not ns.EachPart(KEY, PART, fn, {}) and ns.PartStopped(KEY, PART) then
		pcall(HideAll)
	end
end

local function Apply()
	local flash, warn = FlashWanted(), WarnWanted()
	if flash or warn or LowWanted() then
		S.fighting = InFight()
		if not S.fighting then
			S.fightAt = nil
		end
	end
	if warn then
		ReadRole()
	end
	if not flash then
		EndFlash()
	end
	Listen(warn and S.fighting)
	StopFade(true)
	if S.frame then
		Place()
		if S.flashAt and S.flashKind then
			pcall(S.flash.SetText, S.flash, FlashText(S.flashKind))
			Look(S.flash, S.flashKind)
		end
		if S.warned then
			pcall(S.warn.SetText, S.warn, WarnText())
			Look(S.warn, "warn")
		end
	end
	ApplyLow()
	Judge()
end

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	S.fighting = true
	S.fightAt = Now()
	if LowWanted() then
		Run(PaintBoth)
	end
	if FlashWanted() or WarnWanted() then
		Run(function()
			Flash("enter")
			Listen(WarnWanted())
			Judge()
		end)
	end
end)

ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", function()
	S.fighting = false
	local now, at = Now(), S.fightAt
	S.fightAt = nil
	local length = now and at and now >= at and now - at or nil
	if length then
		S.lastFight = length
	end
	if LowWanted() then
		Run(PaintBoth)
	end
	if WarnWanted() then
		Run(ReadRole)
	end
	if FlashWanted() or S.warned or S.listening or S.waiting then
		Run(function()
			Listen(false)
			Judge()
			Flash("leave", nil, length and Length(length) or nil)
		end)
	end
end)

for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }) do
	ns.AddEvent(KEY, event, function()
		if WarnWanted() then
			Run(ReadRole)
		end
	end)
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if S.fighting and WarnWanted() then
		Run(Judge)
	end
end)

ns.AddStatus(KEY, function()
	local lines = {}
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not (Opt("noTarget") or Opt("combatState") or Opt("lowHealth")) then
		return lines
	end
	if S.unmade then
		lines[1] = "Combat alerts: the game would not make their text, so none shows."
		return lines
	end
	if Opt("noTarget") then
		if S.withheld > 0 then
			lines[#lines + 1] = ("No target warning: %d shown, %d left out while the game withheld your target."):format(S.warnings, S.withheld)
		else
			lines[#lines + 1] = ("No target warning: %d shown."):format(S.warnings)
		end
		if S.silent > 0 and KITS[Opt("noTargetSound")] then
			lines[#lines + 1] = "No target sound: the game played no sound, so the warning is silent."
		end
		if S.healer and Opt("noTargetFriendly") == true then
			lines[#lines + 1] = "No target warning: friendly targets count while you heal."
		end
	end
	if Opt("combatState") then
		local last = S.lastFight and (" Last fight %s."):format(Length(S.lastFight)) or ""
		if KITS[Opt("combatEnterSound")] or KITS[Opt("combatLeaveSound")] then
			lines[#lines + 1] = ("Entering and leaving combat: %d shown, %d sounds played.%s"):format(S.flashes, S.stateSounds, last)
		else
			lines[#lines + 1] = ("Entering and leaving combat: %d shown.%s"):format(S.flashes, last)
		end
	end
	if Opt("lowHealth") then
		if S.lowRefused then
			lines[#lines + 1] = "Low health warning: the game would not give your health through a curve, so neither Low health nor Low mana shows."
		elseif S.manaRefused then
			lines[#lines + 1] = "Low mana warning: the game would not give your mana through a curve, so Low mana does not show."
		end
		if not S.lowRefused then
			lines[#lines + 1] = ("Low health warning: under %d%% health, under %d%% mana%s."):format(math.floor(LowAt("health") * 100 + 0.5),
				math.floor(LowAt("mana") * 100 + 0.5), Opt("lowFight") == true and ", only in a fight" or "")
		end
		if Opt("lowShare") == true and S.shareRefused and not S.shared then
			lines[#lines + 1] = "Share on Low health and Low mana: the game would not give the share as a number, so the lines show their words alone."
		end
	end
	return lines
end)

function ns.CombatCuesRefresh()
	Run(Apply)
	if ns.PartStopped(KEY, PART) or not ns.Enabled(KEY) then
		pcall(HideAll)
	end
end

local function HideSample()
	if S.sampled then
		S.sampled = nil
		if not S.fighting then
			HideWarning(true)
		end
	end
	if S.lowSampled then
		S.lowSampled, S.lowQuick = nil, true
		local ok, err = pcall(PaintBoth)
		S.lowQuick = nil
		if not ok then
			error(err, 0)
		end
	end
end

local function TestStep(quiet)
	if S.fighting then
		return
	end
	Run(function()
		local flashes, warnings = S.flashes, S.warnings
		S.testStep = (S.testStep or -1) + 1
		local phase = S.testStep % 3
		HideSample()
		if phase ~= 1 then
			Flash(phase == 0 and "enter" or "leave", true, phase == 2 and "0:42" or nil)
		elseif InterfaceShown() then
			if WarnWanted() and Make() then
				StopFade(false)
				local line = S.warn
				line:SetText(WarnText())
				Look(line, "warn")
				line:Show()
				Animate(S.breathe, true)
				S.warned, S.sampled = true, true
				Place()
				Shown()
				local mode = ns.TestMode
				if not quiet and mode and mode.Sound("combatcues") then
					Sound()
				end
			end
			if LowWanted() and MakeLow() then
				S.lowSampled = true
				LookLow()
				for _, kind in ipairs(LOW_KINDS) do
					local rec = S.low[kind]
					local shown = kind == "health" or Ask(UnitPowerType, "player") == MANA
					ShowLow(rec, shown)
					if shown then
						pcall(rec.holder.SetAlpha, rec.holder, 1)
					end
				end
				S.lowSampled = true
				Place()
				Shown()
			end
		end
		S.flashes, S.warnings = flashes, warnings
	end)
end

function ns.CombatCuesTestStep()
	S.round = nil
	TestStep(false)
end

function ns.CombatCuesTestEnd()
	S.testStep, S.round = nil, nil
	Run(function()
		HideSample()
		if not S.fighting then
			EndFlash()
		end
	end)
end

function ns.CombatCuesTestRound()
	local mode = ns.TestMode
	if not On() or S.fighting or InFight() or (mode and mode.IsOn()) or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return false
	end
	local token = {}
	S.round, S.testStep = token, nil
	local function At(n)
		if S.round ~= token then
			return
		end
		if n > 3 or S.fighting or (mode and mode.IsOn()) then
			S.round = nil
			if not (mode and mode.IsOn()) then
				ns.CombatCuesTestEnd()
			end
			return
		end
		TestStep(true)
		if not pcall(C_Timer.After, 2, function()
			At(n + 1)
		end) then
			ns.CombatCuesTestEnd()
		end
	end
	At(1)
	return true
end

if ns.TestMode then
	ns.TestMode.Register("combatcues", {
		module = KEY,
		label = "Combat alerts",
		every = 2,
		Start = ns.CombatCuesTestStep,
		Tick = ns.CombatCuesTestStep,
		Stop = ns.CombatCuesTestEnd,
	})
end

function ns.CombatCuesShown()
	return ns.Enabled(KEY) and (Opt("noTarget") == true or Opt("combatState") == true or Opt("lowHealth") == true)
end

function ns.CombatCuesMoved()
	if S.frame then
		Run(Place)
	end
end

function ns.CombatCueSoundPicked(path)
	if type(path) ~= "string" or Ask(InCombatLockdown) == true or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	local kit = KITS[ns.Get(path)]
	local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
	if sound and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	end
end
