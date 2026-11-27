local _, ns = ...

local KEY = "nameplates"
local PART = "Overpower icon"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local K = {
	RANKS = { WARRIOR = { 7384, 7887, 11584, 11585 }, HUNTER = { 1495, 14269, 14270, 14271 }, ROGUE = { 14251 } },
	ICONS = { WARRIOR = "Interface\\Icons\\Ability_MeleeDamage", HUNTER = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
		ROGUE = "Interface\\Icons\\Ability_Warrior_Challange" },
	NAMES = { WARRIOR = "Overpower", HUNTER = "Mongoose Bite", ROGUE = "Riposte" },
	WINDOW = 5, MATCH = 0.5, LOOK = 0.1, GAP = 2, LEVEL = 20, DIM = 0.45, PULSE_LOW = 0.55, PULSE_SECONDS = 1.2, CROP = 0.08,
	AUTO_ATTACK = 6603, SIZE = 26, POP_FROM = 1.3, POP_IN = 0.12, POP_SCALE = 0.15, FADE_OUT = 0.25,
	RENEW_FROM = 1.15, RENEW_SECONDS = 0.15, SECONDS = 0.45, SECONDS_DIM = 0.7, WHITE = { 1, 1, 1 }, AMBER = { 1, 0.75, 0.2 }, RED = { 1, 0.3, 0.25 },
	ACTIVE = { "UNIT_COMBAT", "SPELL_UPDATE_USABLE", "ACTION_USABLE_CHANGED", "SPELL_UPDATE_COOLDOWN", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
		"NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED" },
	ON_USABLE = { HUNTER = true, ROGUE = true },
	OWN = { HUNTER = "DODGE", ROGUE = "PARRY" },
	OWN_WORDS = { HUNTER = "dodges", ROGUE = "parries" },
}
local RANK = {}

local recs = setmetatable({}, { __mode = "k" })
local guides = setmetatable({}, { __mode = "k" })
local lit
local pending = {}
local S = { frame = nil, on = false, class = nil, rank = nil, texture = nil, state = nil, turned = -math.huge, ready = nil, attacking = false,
	clock = 0, since = nil, dodges = 0, mine = 0, waited = 0 }
local Sync, Draw, Prepare, Look

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Spell(name)
	return type(C_Spell) == "table" and C_Spell[name] or nil
end

local function Now()
	local now = Ask(GetTime)
	return type(now) == "number" and now or 0
end

local function Ranks()
	if S.class == nil then
		local token = Ask(UnitClassBase, "player")
		if type(token) == "string" then
			S.class = K.RANKS[token] and token or false
			for _, id in ipairs(K.RANKS[token] or {}) do
				RANK[id] = true
			end
		end
	end
	return S.class and K.RANKS[S.class] or nil
end

local function KnownRank()
	local ranks = Ranks()
	if ranks == nil then
		return nil
	end
	if S.rank == nil then
		S.rank = false
		local book = type(C_SpellBook) == "table" and C_SpellBook or {}
		for index = #ranks, 1, -1 do
			local id = ranks[index]
			local known = Ask(book.IsSpellKnownOrInSpellBook, id)
			if known == nil then
				known = Ask(book.IsSpellKnown, id)
			end
			if known == true then
				S.rank = id
				break
			end
		end
		local file = S.rank and Ask(Spell("GetSpellTexture"), S.rank)
		S.texture = (type(file) == "number" or type(file) == "string") and file or K.ICONS[S.class]
	end
	return S.rank or nil
end

local function Window()
	local ranks = Ranks()
	local rows = ranks and type(ns.ProcData) == "table" and ns.ProcData[S.class]
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		if type(row) == "table" and type(row.lights) == "table" and row.lights[1] == ranks[1] and type(row.seconds) == "number" and row.seconds > 0 then
			return row.seconds
		end
	end
	return K.WINDOW
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("overpower") == true and Ranks() ~= nil
		and KnownRank() ~= nil
end

local function UsableState()
	local rank = KnownRank()
	local call = Spell("IsSpellUsable")
	if not rank or type(call) ~= "function" then
		return nil
	end
	local ok, usable, power = pcall(call, rank)
	if not ok or not Plain(usable, "boolean") or ns.IsSecret(power) then
		return nil
	end
	return usable and "usable" or (power == true and "power" or "blocked")
end

local function Fresh()
	local rank = KnownRank()
	local info = rank and Ask(Spell("GetSpellCooldown"), rank)
	if type(info) ~= "table" then
		return nil
	end
	local enabled, active, gcd = info.isEnabled, info.isActive, info.isOnGCD
	if ns.IsSecret(enabled) or ns.IsSecret(active) or ns.IsSecret(gcd) then
		return nil
	end
	if enabled == false then
		return false
	end
	return active ~= true or gcd == true, active == true and gcd == false
end

local function Locked(unitFrame)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame))
end

local function Region(owner, key)
	local region = owner[key]
	if ns.IsSecret(region) or type(region) ~= "table" or ns.Forbidden(region) then
		return nil
	end
	return region
end

local function NameInside()
	local options, constants = NamePlateSetupOptions, NamePlateConstants
	local styles = Plain(constants, "table") and constants.NAME_ANCHOR_STYLES
	local style = Plain(options, "table") and options.unitNameAnchorStyle
	return Plain(styles, "table") and Plain(style, "number") and style == styles.InsideHealthBar
end

local function AnchorOf(unitFrame)
	local name, bars = Region(unitFrame, "name"), Region(unitFrame, "HealthBarsContainer")
	local only = unitFrame.showOnlyName
	if (Plain(only, "boolean") and only) or not NameInside() then
		return name or bars
	end
	return bars or name
end

local function Seen(unitFrame)
	if type(ns.PlateAurasSeen) ~= "function" then
		return true
	end
	local ok, seen = pcall(ns.PlateAurasSeen, unitFrame)
	return not ok or seen ~= false
end

local function DebuffRow(unitFrame)
	local auras = Region(unitFrame, "AurasFrame")
	local list = auras and Region(auras, "DebuffListFrame")
	if list and Ask(auras.IsShown, auras) == true and Ask(list.IsShown, list) == true and Seen(unitFrame) then
		return list
	end
	return nil
end

local function Guide(unitFrame)
	local guide = guides[unitFrame]
	local top, bottom = DebuffRow(unitFrame), Region(unitFrame, "HealthBarsContainer")
	if not (top and bottom) then
		top = AnchorOf(unitFrame)
		bottom = top
	end
	if top == nil then
		return guide and guide.frame or nil, false
	end
	if guide and guide.top == top and guide.bottom == bottom then
		return guide.frame, false
	end
	if Locked(unitFrame) then
		return guide and guide.frame or nil, true
	end
	if guide == nil then
		local frame = CreateFrame("Frame", nil, unitFrame)
		ns.Own[frame] = true
		guide = { frame = frame }
		guides[unitFrame] = guide
	end
	local frame = guide.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 0, 0)
	guide.top, guide.bottom = top, bottom
	return frame, false
end

local function Wait(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		rec = {}
		recs[unitFrame] = rec
	end
	if rec.waiting then
		return
	end
	rec.waiting = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.waiting = nil
		if S.on and recs[unitFrame] == rec and not ns.Forbidden(unitFrame) then
			ns.EachPart(KEY, PART, Prepare, unitFrame)
			if lit and lit.unitFrame == unitFrame then
				ns.EachPart(KEY, PART, Draw)
			end
		end
	end)
end

local function MakeGlow(rec)
	local ok, look = pcall(ns.ProcGlowSoft, rec.holder, rec.holder)
	if ok and type(look) == "table" and type(look.frame) == "table" and type(look.pulse) == "table" then
		rec.glow = look
		return
	end
	local group = rec.icon:CreateAnimationGroup()
	ns.Own[group] = true
	local fade = group:CreateAnimation("Alpha")
	ns.Own[fade] = true
	fade:SetFromAlpha(1)
	fade:SetToAlpha(K.PULSE_LOW)
	fade:SetDuration(K.PULSE_SECONDS)
	fade:SetSmoothing("IN_OUT")
	group:SetLooping("BOUNCE")
	rec.pulse = group
end

local function MakeSwipe(rec)
	local ok, swipe = pcall(CreateFrame, "Cooldown", nil, rec.holder, "CooldownFrameTemplate")
	if not ok or type(swipe) ~= "table" then
		rec.swipe = false
		return
	end
	ns.Own[swipe] = true
	swipe:SetAllPoints(rec.icon)
	pcall(swipe.SetReverse, swipe, true)
	pcall(swipe.SetDrawEdge, swipe, false)
	pcall(swipe.SetDrawBling, swipe, false)
	pcall(swipe.SetHideCountdownNumbers, swipe, true)
	local level = Ask(rec.holder.GetFrameLevel, rec.holder)
	if type(level) == "number" then
		pcall(swipe.SetFrameLevel, swipe, level + 1)
	end
	rec.swipe = swipe
end

local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

local function QuestPlace(unitFrame)
	if unitFrame ~= nil and type(ns.PlateQuestPlace) == "function" then
		pcall(ns.PlateQuestPlace, unitFrame)
	end
	if unitFrame ~= nil and type(ns.PlateSlipPlace) == "function" then
		pcall(ns.PlateSlipPlace, unitFrame)
	end
end

local function ClearSeconds(rec)
	if rec.secs and rec.secsShown ~= "" then
		rec.secsShown = ""
		rec.secs:SetText("")
	end
end

local function MakeMotion(rec)
	local holder = rec.holder
	local ok, pop, fadeOut, renew = pcall(function()
		local popGroup = holder:CreateAnimationGroup()
		ns.Own[popGroup] = true
		local appear = popGroup:CreateAnimation("Alpha")
		ns.Own[appear] = true
		appear:SetFromAlpha(0)
		appear:SetToAlpha(1)
		appear:SetDuration(K.POP_IN)
		local shrink = popGroup:CreateAnimation("Scale")
		ns.Own[shrink] = true
		shrink:SetScaleFrom(K.POP_FROM, K.POP_FROM)
		shrink:SetScaleTo(1, 1)
		shrink:SetDuration(K.POP_SCALE)
		shrink:SetOrigin("CENTER", 0, 0)
		pcall(shrink.SetSmoothing, shrink, "OUT")
		local fadeGroup = holder:CreateAnimationGroup()
		ns.Own[fadeGroup] = true
		local away = fadeGroup:CreateAnimation("Alpha")
		ns.Own[away] = true
		away:SetFromAlpha(1)
		away:SetToAlpha(0)
		away:SetDuration(K.FADE_OUT)
		pcall(fadeGroup.SetToFinalAlpha, fadeGroup, true)
		fadeGroup:SetScript("OnFinished", function()
			if not rec.shown then
				holder:SetAlpha(0)
				ClearSeconds(rec)
				QuestPlace(rec.owner)
			end
		end)
		local renewGroup = holder:CreateAnimationGroup()
		ns.Own[renewGroup] = true
		local swell = renewGroup:CreateAnimation("Scale")
		ns.Own[swell] = true
		swell:SetScaleFrom(K.RENEW_FROM, K.RENEW_FROM)
		swell:SetScaleTo(1, 1)
		swell:SetDuration(K.RENEW_SECONDS)
		swell:SetOrigin("CENTER", 0, 0)
		pcall(swell.SetSmoothing, swell, "OUT")
		return popGroup, fadeGroup, renewGroup
	end)
	if ok and type(pop) == "table" and type(fadeOut) == "table" then
		rec.pop, rec.fadeOut = pop, fadeOut
		rec.renew = type(renew) == "table" and renew or nil
	end
end

local function Pop(rec)
	if rec.fadeOut then
		pcall(rec.fadeOut.Stop, rec.fadeOut)
	end
	if rec.renew then
		pcall(rec.renew.Stop, rec.renew)
	end
	rec.holder:SetAlpha(1)
	if rec.pop then
		pcall(rec.pop.Stop, rec.pop)
		pcall(rec.pop.Play, rec.pop)
	end
end

local function ClearSwipe(rec)
	if rec.swipe and rec.at ~= nil then
		rec.at = nil
		pcall(rec.swipe.Clear, rec.swipe)
	end
end

local function SecondsFont(rec)
	local text = rec.secs
	local face = Opt("textFace")
	local file = face ~= "default" and type(ns.FontFile) == "function" and ns.FontFile(face) or nil
	if not Plain(file, "string") then
		file = rec.secsBase
	end
	if not (text and Plain(file, "string")) then
		return
	end
	local px = math.max(6, math.floor((rec.size or K.SIZE) * K.SECONDS + 0.5))
	local key = file .. "|" .. px
	if rec.secsFont ~= key and pcall(text.SetFont, text, file, px, "OUTLINE") then
		rec.secsFont = key
	end
end

local function MakeSeconds(rec)
	local ok, frame = pcall(CreateFrame, "Frame", nil, rec.holder)
	if not ok or type(frame) ~= "table" then
		return
	end
	ns.Own[frame] = true
	frame:SetAllPoints(rec.holder)
	local level = Ask(rec.holder.GetFrameLevel, rec.holder)
	if type(level) == "number" then
		pcall(frame.SetFrameLevel, frame, level + 3)
	end
	local text = type(ns.OwnText) == "function" and ns.OwnText(frame, "OVERLAY", "SystemFont_NamePlate") or nil
	if not text then
		return
	end
	local got, file = pcall(text.GetFont, text)
	rec.secsBase = got and Plain(file, "string") and file or nil
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	text:SetTextColor(K.WHITE[1], K.WHITE[2], K.WHITE[3], 1)
	text:SetText("")
	rec.secs, rec.secsShown, rec.secsTint = text, "", K.WHITE
end

local function Seconds(rec)
	local text = rec.secs
	if not text then
		return
	end
	local shown, tint = "", nil
	if lit and Opt("overpowerSeconds") == true then
		local left = lit.expires - Now()
		if left > 0 then
			local whole = math.ceil(left)
			shown = tostring(whole)
			tint = (whole <= 1 and K.RED) or (whole <= 2 and K.AMBER) or K.WHITE
		end
	end
	if tint and tint ~= rec.secsTint then
		rec.secsTint = tint
		text:SetTextColor(tint[1], tint[2], tint[3], 1)
	end
	if shown ~= rec.secsShown then
		rec.secsShown = shown
		if shown ~= "" then
			SecondsFont(rec)
		end
		text:SetText(shown)
	end
end

local function Make(unitFrame)
	local rec = recs[unitFrame]
	if rec and rec.holder then
		return rec
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return nil
	end
	rec = rec or {}
	recs[unitFrame] = rec
	rec.owner = unitFrame
	local holder = CreateFrame("Frame", nil, unitFrame)
	ns.Own[holder] = true
	holder:SetSize(K.SIZE, K.SIZE)
	holder:SetAlpha(0)
	local icon = holder:CreateTexture(nil, "ARTWORK")
	ns.Own[icon] = true
	icon:SetAllPoints(holder)
	icon:SetTexCoord(K.CROP, 1 - K.CROP, K.CROP, 1 - K.CROP)
	rec.holder, rec.icon = holder, icon
	MakeSwipe(rec)
	rec.outline = ns.Outline(holder, holder)
	ns.SetOutline(rec.outline, true, true)
	local edges, level = rec.outline and rec.outline.holder, Ask(holder.GetFrameLevel, holder)
	if rec.swipe and type(edges) == "table" and type(level) == "number" then
		pcall(edges.SetFrameLevel, edges, level + 2)
	end
	MakeSeconds(rec)
	MakeGlow(rec)
	MakeMotion(rec)
	return rec
end

local function AboveValue(unitFrame)
	if type(ns.PlateThreatTexts) ~= "function" then
		return nil
	end
	local ok, value, side = pcall(ns.PlateThreatTexts, unitFrame)
	return ok and type(value) == "table" and side == "above" and Ask(value.IsShown, value) == true and value or nil
end

local function Place(unitFrame, rec)
	local to, stale = Guide(unitFrame)
	to = AboveValue(unitFrame) or to
	local size = Opt("overpowerSize")
	size = type(size) == "number" and size > 0 and size or K.SIZE
	local ox, oy = Opt("overpowerX"), Opt("overpowerY")
	ox, oy = ns.Finite(ox) and ox or 0, ns.Finite(oy) and oy or 0
	if stale then
		Wait(unitFrame)
	end
	if to == nil or (rec.to == to and rec.size == size and rec.ox == ox and rec.oy == oy) then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	holder:SetSize(size, size)
	if rec.to ~= to or rec.ox ~= ox or rec.oy ~= oy then
		holder:ClearAllPoints()
		holder:SetPoint("BOTTOM", to, "TOP", ox, K.GAP + oy)
	end
	local level = Ask(unitFrame.GetFrameLevel, unitFrame)
	if type(level) == "number" then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	rec.to, rec.size, rec.ox, rec.oy = to, size, ox, oy
	if rec.secs then
		SecondsFont(rec)
	end
end

function Prepare(unitFrame)
	if not S.on or ns.Forbidden(unitFrame) then
		return
	end
	local unit = unitFrame.unit
	if Plain(unit, "string") and Ask(UnitCanAttack, "player", unit) == false then
		return
	end
	local rec = Make(unitFrame)
	if rec then
		Place(unitFrame, rec)
	end
end

local function Glow(rec, on)
	if rec.glowing == on then
		return
	end
	rec.glowing = on
	local glow = rec.glow
	if glow then
		if on then
			glow.frame:SetAlpha(1)
			glow.pulse:Play()
		else
			glow.pulse:Stop()
			glow.frame:SetAlpha(0)
		end
	elseif rec.pulse then
		if on then
			rec.pulse:Play()
		else
			rec.pulse:Stop()
		end
	end
end

local function Hide(rec, fade)
	local holder = rec.holder
	local gone = false
	if holder and rec.shown then
		rec.shown, rec.usable = nil, nil
		Glow(rec, false)
		if rec.pop then
			pcall(rec.pop.Stop, rec.pop)
		end
		if rec.renew then
			pcall(rec.renew.Stop, rec.renew)
		end
		if not (fade and rec.fadeOut and pcall(rec.fadeOut.Play, rec.fadeOut)) then
			if rec.fadeOut then
				pcall(rec.fadeOut.Stop, rec.fadeOut)
			end
			holder:SetAlpha(0)
			gone = true
		end
	elseif holder and not fade and rec.fadeOut then
		gone = Playing(rec.fadeOut)
		pcall(rec.fadeOut.Stop, rec.fadeOut)
		holder:SetAlpha(0)
	end
	ClearSwipe(rec)
	if not Playing(rec.fadeOut) then
		ClearSeconds(rec)
	end
	if gone then
		QuestPlace(rec.owner)
	end
end

function Draw()
	if not lit then
		return
	end
	local unitFrame = lit.unitFrame
	local rec = recs[unitFrame]
	if not (rec and rec.holder) then
		rec = Make(unitFrame)
		if not rec then
			return
		end
	end
	Place(unitFrame, rec)
	if rec.to == nil then
		return
	end
	if rec.file ~= S.texture then
		rec.file = S.texture
		rec.icon:SetTexture(S.texture)
	end
	if Opt("overpowerSwipe") ~= true then
		ClearSwipe(rec)
	elseif rec.swipe and rec.at ~= lit.at then
		rec.at = lit.at
		pcall(rec.swipe.SetCooldown, rec.swipe, lit.at, lit.expires - lit.at)
	end
	Seconds(rec)
	local usable = UsableState() == "usable" and S.ready ~= false
	if rec.shown and rec.usable == usable then
		return
	end
	local first = not rec.shown
	rec.shown, rec.usable = true, usable
	rec.icon:SetDesaturated(not usable)
	rec.icon:SetAlpha(usable and 1 or K.DIM)
	if rec.secs then
		rec.secs:SetAlpha(usable and 1 or K.SECONDS_DIM)
	end
	if first then
		Pop(rec)
		QuestPlace(unitFrame)
	else
		rec.holder:SetAlpha(1)
	end
	Glow(rec, usable)
end

local function OnUpdate(_, elapsed)
	S.clock = S.clock + (type(elapsed) == "number" and elapsed or 0)
	if S.clock >= K.LOOK then
		S.clock = 0
		ns.EachPart(KEY, PART, Look)
	end
end

local function Ticking(on)
	if S.frame then
		S.clock = 0
		pcall(S.frame.SetScript, S.frame, "OnUpdate", on and OnUpdate or nil)
	end
end

local function Unlight(fade)
	if lit then
		local rec = recs[lit.unitFrame]
		lit = nil
		if rec then
			Hide(rec, fade)
		end
	end
	Ticking(false)
end

local function Light(unitFrame, unit, at)
	if lit and lit.unitFrame ~= unitFrame then
		Unlight()
	end
	local renewed = lit ~= nil and lit.unitFrame == unitFrame and lit.at ~= at
	if not (lit and lit.unitFrame == unitFrame and lit.at == at) then
		S.mine = S.mine + 1
	end
	S.turned = -math.huge
	if S.ready ~= true and Fresh() == true then
		S.ready = true
	end
	lit = { unitFrame = unitFrame, unit = unit, at = at, expires = at + Window() }
	Ticking(true)
	Draw()
	local rec = recs[unitFrame]
	if renewed and rec and rec.shown and rec.renew and not Playing(rec.pop) and not Playing(rec.fadeOut) then
		pcall(rec.renew.Stop, rec.renew)
		pcall(rec.renew.Play, rec.renew)
	end
end

local function Gone(unitFrame)
	if ns.Forbidden(unitFrame) then
		return true
	end
	local unit = unitFrame.unit
	return not ns.IsSecret(unit) and unit == nil
end

function Look()
	if not lit then
		Ticking(false)
		return
	end
	if Gone(lit.unitFrame) or Ask(UnitIsDead, lit.unit) == true then
		Unlight()
		return
	end
	if Now() >= lit.expires then
		Unlight(true)
		return
	end
	if S.ready ~= true and Fresh() == true then
		S.ready = true
	end
	Draw()
end

local function Match(now)
	local kept, best = {}, nil
	for _, dodge in ipairs(pending) do
		if now - dodge.at <= K.MATCH then
			kept[#kept + 1] = dodge
			if math.abs(dodge.at - S.turned) <= K.MATCH
				and (best == nil or (dodge.target and not best.target) or (dodge.target == best.target and dodge.at >= best.at)) then
				best = dodge
			end
		end
	end
	pending = kept
	if best then
		pending, S.turned = {}, -math.huge
		Light(best.unitFrame, best.unit, best.at)
	end
end

local function Melee(unit)
	return S.attacking and Ask(Spell("IsSpellInRange"), S.rank, unit) ~= false
end

local OnOwnRenew

local function OnCombat(unit, action)
	if not Plain(unit, "string") or not Plain(action, "string") then
		return
	end
	if K.ON_USABLE[S.class] then
		if unit == "player" and action == K.OWN[S.class] then
			OnOwnRenew()
		end
		return
	end
	if action ~= "DODGE" then
		return
	end
	if unit ~= "target" and unit ~= "focus" and not unit:find("^nameplate") then
		return
	end
	local unitFrame = type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame(unit)
	if not unitFrame or ns.Forbidden(unitFrame) then
		return
	end
	local token = unitFrame.unit
	if not Plain(token, "string") then
		token = unit
	end
	if Ask(UnitCanAttack, "player", token) == false then
		return
	end
	if unit:find("^nameplate") then
		S.dodges = S.dodges + 1
	end
	local now = Now()
	local target = unit == "target" or Ask(UnitIsUnit, token, "target") == true
	if target and Melee(token) then
		Light(unitFrame, token, now)
		return
	end
	local found = false
	for _, dodge in ipairs(pending) do
		if dodge.unitFrame == unitFrame then
			dodge.target = target or (dodge.at == now and dodge.target)
			dodge.at, dodge.unit, found = now, token, true
		end
	end
	if not found then
		pending[#pending + 1] = { unitFrame = unitFrame, unit = token, at = now, target = target }
	end
	Match(now)
end

local function TargetPlate()
	local unitFrame = type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame("target") or nil
	if not unitFrame or ns.Forbidden(unitFrame) then
		return nil
	end
	local token = unitFrame.unit
	if not Plain(token, "string") then
		token = "target"
	end
	if Ask(UnitCanAttack, "player", token) ~= true then
		return nil
	end
	return unitFrame, token
end

local function LightTarget()
	local since = S.since
	if since == nil or not (S.state == "usable" or S.state == "power") or Now() >= since + Window() then
		return
	end
	local unitFrame, token = TargetPlate()
	if unitFrame then
		Light(unitFrame, token, since)
	elseif lit then
		Unlight()
	end
end

function OnOwnRenew()
	S.dodges = S.dodges + 1
	S.ownAt = Now()
	if (S.since ~= nil or S.state == "power") and (S.state == "usable" or S.state == "power") then
		S.since = S.ownAt
		LightTarget()
	end
end

local function OnTarget()
	if K.ON_USABLE[S.class] and S.since ~= nil then
		LightTarget()
	end
end

local function OnUsable()
	local state = UsableState()
	if state == nil then
		return
	end
	local before = S.state
	S.state = state
	if K.ON_USABLE[S.class] then
		local now, own = Now(), S.ownAt
		if state == "usable" and before ~= nil and before ~= "usable" and (before ~= "power" or S.since == nil) then
			S.since = (own and now - own >= 0 and now - own < Window()) and own or now
			LightTarget()
		elseif state == "power" and before == "blocked" and own and now - own >= 0 and now - own <= K.MATCH then
			S.since = own
			LightTarget()
		elseif state == "blocked" and before ~= nil and before ~= "blocked" then
			S.since, S.ownAt = nil, nil
			if lit then
				Unlight(true)
			end
		end
		Draw()
		return
	end
	if state == "usable" and before ~= nil and before ~= "usable" then
		local now = Now()
		if lit and now - lit.at <= K.MATCH then
			S.turned = -math.huge
		else
			S.turned = now
			Match(now)
		end
	end
	Draw()
end

local function OnCooldown()
	local before = S.ready
	local fresh, own = Fresh()
	S.ready = fresh
	if before == true and own == true then
		S.since = nil
		if lit then
			Unlight()
			return
		end
	end
	Draw()
end

local function OnCast(unit, _, spellID)
	if Plain(unit, "string") and unit == "player" and Plain(spellID, "number") and RANK[spellID] then
		pending, S.turned, S.since, S.ownAt = {}, -math.huge, nil, nil
		Unlight()
	end
end

local function OnRemoved(unit)
	if not Plain(unit, "string") then
		return
	end
	if lit and lit.unit == unit then
		Unlight()
	end
	local kept = {}
	for _, dodge in ipairs(pending) do
		if dodge.unit ~= unit then
			kept[#kept + 1] = dodge
		end
	end
	pending = kept
end

local function Heard(event, ...)
	if event == "UNIT_COMBAT" then
		OnCombat(...)
	elseif event == "SPELL_UPDATE_USABLE" or event == "ACTION_USABLE_CHANGED" then
		OnUsable()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		OnCooldown()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		OnCast(...)
	elseif event == "PLAYER_ENTER_COMBAT" then
		S.attacking = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		S.attacking = false
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		OnRemoved(...)
	elseif event == "PLAYER_TARGET_CHANGED" then
		OnTarget()
	elseif event == "SPELLS_CHANGED" then
		S.rank, S.texture = nil, nil
		Sync()
	end
end

local function StandDown()
	lit, pending, S.since, S.ownAt = nil, {}, nil, nil
	Ticking(false)
	for _, rec in pairs(recs) do
		pcall(Hide, rec)
	end
end

local function OnEvent(_, event, ...)
	local ok = ns.EachPart(KEY, PART, Heard, event, ...)
	if not ok and ns.PartStopped(KEY, PART) then
		S.on = false
		pcall(StandDown)
	end
end

local function Frame()
	if S.frame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			S.frame = false
			return nil
		end
		ns.Own[frame] = true
		frame:SetScript("OnEvent", OnEvent)
		pcall(frame.RegisterEvent, frame, "SPELLS_CHANGED")
		S.frame = frame
	end
	return S.frame or nil
end

local function Hear(on)
	local frame = Frame()
	if not frame then
		return
	end
	for _, event in ipairs(K.ACTIVE) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	if not on then
		pcall(frame.UnregisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
	elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")) then
		pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
	end
end

function Sync()
	if Ranks() then
		Frame()
	end
	local want = Wanted() and S.frame and true or false
	if want ~= S.on then
		S.on = want
		Hear(want)
		if want then
			S.state, S.ready = UsableState(), Fresh()
			S.attacking = Ask(Spell("IsCurrentSpell"), K.AUTO_ATTACK) == true
			if type(ns.EachPlate) == "function" then
				ns.EachPlate(function(unitFrame)
					ns.EachPart(KEY, PART, Prepare, unitFrame)
				end)
			end
		else
			StandDown()
		end
	end
	if want then
		for unitFrame, rec in pairs(recs) do
			if rec.holder and not ns.Forbidden(unitFrame) then
				ns.EachPart(KEY, PART, Place, unitFrame, rec)
			end
		end
		Draw()
	end
end

EXTRA.show[#EXTRA.show + 1] = function(unitFrame)
	if S.on then
		ns.EachPart(KEY, PART, Prepare, unitFrame)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	if lit and lit.unitFrame == unitFrame then
		Unlight()
	end
	local rec = recs[unitFrame]
	if rec then
		pcall(Hide, rec)
	end
	local kept = {}
	for _, dodge in ipairs(pending) do
		if dodge.unitFrame ~= unitFrame then
			kept[#kept + 1] = dodge
		end
	end
	pending = kept
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		pcall(Hear, false)
		pcall(StandDown)
	end
end
function ns.PlateDebuffTop(unitFrame)
	if unitFrame == nil or ns.Forbidden(unitFrame) then
		return nil
	end
	local frame, stale = Guide(unitFrame)
	return frame, stale
end

function ns.PlateOverpowerIcon(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder and rec.to ~= nil and (rec.shown or Playing(rec.fadeOut)) then
		return rec.holder
	end
	return nil
end

function ns.PlateOverpowerPlace(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder and not ns.Forbidden(unitFrame) then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end

local function GuidesMoved()
	for unitFrame in pairs(guides) do
		if not ns.Forbidden(unitFrame) then
			local ok, _, stale = pcall(Guide, unitFrame)
			if ok and stale and S.on then
				Wait(unitFrame)
			end
		end
	end
end
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if Opt("aurasWhen") ~= "always" then
		GuidesMoved()
	end
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	if Opt("aurasWhen") == "focus" then
		GuidesMoved()
	end
end)

EXTRA.status[#EXTRA.status + 1] = function()
	if Opt("overpower") ~= true or not Ranks() then
		return nil
	end
	local name = K.NAMES[S.class]
	if not KnownRank() then
		return ("%s on enemy nameplates: you do not know %s yet."):format(name, name)
	end
	if K.ON_USABLE[S.class] then
		return ("%s on enemy nameplates: %d of your %s heard, shown over your target %d times, %d plates waited for the end of a fight for their icon.")
			:format(name, S.dodges, K.OWN_WORDS[S.class] or "dodges", S.mine, S.waited)
	end
	return ("%s on enemy nameplates: %d dodges heard, %d yours, %d plates waited for the end of a fight for their icon."):format(name, S.dodges,
		S.mine, S.waited)
end
