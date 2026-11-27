local _, ns = ...

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local PART = "threat slipping"
local RINGS = { 0.85, 0.55, 0.33, 0.18, 0.08 }
local GAP_PX, RING_PX = 2, 2
local PULSE = { slipping = 0.75, lost = 0.3 }
local BOB = { slipping = 0.6, lost = 0.3 }
local PULSE_LOW, BOB_PX = 0.25, 3
local FADE_IN, FADE_OUT = 0.15, 0.2
local ARROW, ARROW_ROW, ARROW_GAP, LEVEL = { 14, 11, 8, 5, 2 }, 2, 3, 22
local SHADE = { 0, 0, 0, 0.8 }
local KINDS = { bad = "lost", changing = "slipping" }
local SAMPLE_KINDS = { threatBad = "lost", threatTransition = "slipping" }

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local subscribed = false
local Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Usable(frame)
	if not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

local function Bar(frame)
	local container = Usable(frame.HealthBarsContainer)
	return container and Usable(container.healthBar) or nil
end

local function Level(frame)
	return Usable(frame.PlayerLevelDiffFrame)
end

local function NameOnly(frame)
	local only = frame.showOnlyName
	return not ns.IsSecret(only) and only == true
end

local function Styled(frame)
	local friend = frame.isFriend
	return Opt("friendly") == true or ns.IsSecret(friend) or friend ~= true
end

local function Locked(frame)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(frame))
end

local function Core()
	local PT = ns.PlateThreat
	if type(PT) ~= "table" or type(PT.Active) ~= "function" or type(PT.Get) ~= "function" then
		return nil
	end
	local ok, active = pcall(PT.Active)
	if ok and active == true then
		return PT
	end
	return nil
end

local function StateOf(frame)
	local PT = Core()
	if PT == nil then
		return nil
	end
	local ok, state = pcall(PT.Get, frame)
	if ok and type(state) == "table" then
		return state
	end
	return nil
end

local function Kind(state)
	if type(state) ~= "table" or state.tank ~= true or state.pet == true or state.tapped == true then
		return nil
	end
	return KINDS[state.want]
end

local function Colour(state)
	local PT = ns.PlateThreat
	if type(PT) ~= "table" or type(PT.Colour) ~= "function" then
		return nil
	end
	local ok, r, g, b = pcall(PT.Colour, state)
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

local function On()
	return ns.Enabled(KEY) and Opt("threat") == true and Opt("threatSlipping") == true and not ns.PartStopped(KEY, PART)
end

local function Wanted(frame)
	return On() and ns.IsPlate(frame) and Styled(frame) and not NameOnly(frame)
end

local function Base()
	local thickness = ns.Get("general.thickness")
	local base = (ns.Finite(thickness) and thickness or 1) + GAP_PX
	if Opt("threatGlow") ~= "off" then
		local px = Opt("threatRingPx")
		base = base + (ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or RING_PX)
	end
	return base
end

local function Group(region, looping)
	local group = Own(region:CreateAnimationGroup())
	if looping then
		group:SetLooping(looping)
	end
	return group
end

local function Animate(cue)
	local holder, glow, arrow = cue.holder, cue.glow, cue.arrow
	local come = Group(holder)
	local rise = Own(come:CreateAnimation("Alpha"))
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(FADE_IN)
	local go = Group(holder)
	local fall = Own(go:CreateAnimation("Alpha"))
	fall:SetFromAlpha(1)
	fall:SetToAlpha(0)
	fall:SetDuration(FADE_OUT)
	pcall(go.SetToFinalAlpha, go, true)
	go:SetScript("OnFinished", function()
		if not cue.on then
			holder:Hide()
			if cue.pulse then
				pcall(cue.pulse.Stop, cue.pulse)
			end
			if cue.bob then
				pcall(cue.bob.Stop, cue.bob)
			end
		end
		holder:SetAlpha(1)
	end)
	local pulse = Group(glow, "BOUNCE")
	local fade = Own(pulse:CreateAnimation("Alpha"))
	fade:SetFromAlpha(1)
	fade:SetToAlpha(PULSE_LOW)
	fade:SetDuration(PULSE.slipping)
	pcall(fade.SetSmoothing, fade, "IN_OUT")
	local bob = Group(arrow, "BOUNCE")
	local move = Own(bob:CreateAnimation("Translation"))
	move:SetOffset(0, -BOB_PX)
	move:SetDuration(BOB.slipping)
	pcall(move.SetSmoothing, move, "IN_OUT")
	cue.come, cue.go, cue.pulse, cue.fade, cue.bob, cue.move = come, go, pulse, fade, bob, move
end

local function Build(parent)
	local holder = Own(CreateFrame("Frame", nil, parent))
	holder:SetAllPoints(parent)
	holder:Hide()
	local glow = Own(CreateFrame("Frame", nil, holder))
	local arrow = Own(CreateFrame("Frame", nil, holder))
	local cue = { holder = holder, glow = glow, arrow = arrow, rings = {}, shape = {}, shade = {} }
	for index = 1, #RINGS do
		local ring = {}
		for side = 1, 4 do
			ring[side] = Own(glow:CreateTexture(nil, "ARTWORK"))
		end
		cue.rings[index] = ring
	end
	cue.width, cue.height = ARROW[1] + 1, #ARROW * ARROW_ROW + 1
	arrow:SetSize(cue.width, cue.height)
	for index, width in ipairs(ARROW) do
		local y = -(index - 1) * ARROW_ROW
		local shade = Own(arrow:CreateTexture(nil, "BORDER"))
		shade:SetColorTexture(SHADE[1], SHADE[2], SHADE[3], SHADE[4])
		shade:SetSize(width, ARROW_ROW)
		shade:SetPoint("TOP", arrow, "TOP", 1, y - 1)
		local piece = Own(arrow:CreateTexture(nil, "ARTWORK"))
		piece:SetSize(width, ARROW_ROW)
		piece:SetPoint("TOP", arrow, "TOP", 0, y)
		cue.shade[index], cue.shape[index] = shade, piece
	end
	pcall(Animate, cue)
	return cue
end

local function Line(line, glow, a, b, ax, ay, bx, by, w, h)
	line:ClearAllPoints()
	line:SetPoint(a, glow, a, ax, ay)
	line:SetPoint(b, glow, b, bx, by)
	if w then
		line:SetWidth(w)
	else
		line:SetHeight(h)
	end
end

local function Ring(cue, bar, right)
	local glow = cue.glow
	glow:ClearAllPoints()
	glow:SetPoint("LEFT", bar, "LEFT", 0, 0)
	glow:SetPoint("TOP", bar, "TOP", 0, 0)
	glow:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	glow:SetPoint("RIGHT", right or bar, "RIGHT", 0, 0)
	local unit, base = ns.Pixels(glow, 1), Base()
	for index, ring in ipairs(cue.rings) do
		local d = (base + index - 1) * unit
		Line(ring[1], glow, "TOPLEFT", "TOPRIGHT", -d, d, d, d, nil, unit)
		Line(ring[2], glow, "BOTTOMLEFT", "BOTTOMRIGHT", -d, -d, d, -d, nil, unit)
		Line(ring[3], glow, "TOPLEFT", "BOTTOMLEFT", -d, d - unit, -d, -d + unit, unit)
		Line(ring[4], glow, "TOPRIGHT", "BOTTOMRIGHT", d, d - unit, d, -d + unit, unit)
	end
	cue.unit, cue.base, cue.bar, cue.right = unit, base, bar, right or bar
end

local function Paint(cue, kind, r, g, b)
	if cue.r ~= r or cue.g ~= g or cue.b ~= b then
		cue.r, cue.g, cue.b = r, g, b
		for index, ring in ipairs(cue.rings) do
			for _, line in ipairs(ring) do
				line:SetColorTexture(r, g, b, RINGS[index])
			end
		end
		for _, piece in ipairs(cue.shape) do
			piece:SetColorTexture(r, g, b, 1)
		end
	end
	if cue.kind ~= kind then
		cue.kind = kind
		if cue.fade then
			pcall(cue.pulse.Stop, cue.pulse)
			pcall(cue.fade.SetDuration, cue.fade, PULSE[kind] or PULSE.slipping)
		end
		if cue.move then
			pcall(cue.bob.Stop, cue.bob)
			pcall(cue.move.SetDuration, cue.move, BOB[kind] or BOB.slipping)
		end
		cue.moving = nil
	end
end

local function Moving(cue, on)
	on = on and true or false
	if cue.moving == on then
		return
	end
	cue.moving = on
	for _, group in ipairs({ cue.pulse or false, cue.bob or false }) do
		if group then
			if on then
				pcall(group.Play, group)
			else
				pcall(group.Stop, group)
			end
		end
	end
end

local function Show(cue, snap, still)
	cue.still = still
	if not cue.on then
		cue.on = true
		if cue.go then
			pcall(cue.go.Stop, cue.go)
		end
		cue.holder:SetAlpha(1)
		cue.holder:Show()
		if cue.come and not snap and not still then
			pcall(cue.come.Stop, cue.come)
			pcall(cue.come.Play, cue.come)
		end
	end
	Moving(cue, not still)
end

local function Hide(cue, snap)
	if not cue.on then
		if snap and cue.go and cue.go:IsPlaying() then
			pcall(cue.go.Stop, cue.go)
			cue.holder:Hide()
			cue.holder:SetAlpha(1)
			Moving(cue, false)
		end
		return
	end
	cue.on = false
	if cue.come then
		pcall(cue.come.Stop, cue.come)
	end
	if not snap and cue.go and pcall(cue.go.Play, cue.go) then
		cue.moving = nil
		return
	end
	cue.holder:Hide()
	cue.holder:SetAlpha(1)
	Moving(cue, false)
end

local function Record(frame)
	local rec = recs[frame]
	if rec == nil then
		rec = {}
		recs[frame] = rec
	end
	return rec
end

local function Above(frame)
	local icon = type(ns.PlateOverpowerIcon) == "function" and select(2, pcall(ns.PlateOverpowerIcon, frame)) or nil
	if type(icon) == "table" then
		return icon
	end
	if type(ns.PlateThreatTexts) == "function" then
		local ok, value, side = pcall(ns.PlateThreatTexts, frame)
		if ok and type(value) == "table" and side == "above" then
			return value
		end
	end
	if type(ns.PlateDebuffTop) == "function" then
		local ok, guide = pcall(ns.PlateDebuffTop, frame)
		if ok and type(guide) == "table" then
			return guide
		end
	end
	local name = Usable(frame.name)
	if name then
		local ok, shown = pcall(name.IsShown, name)
		if ok and shown == true then
			return name
		end
	end
	return Bar(frame)
end

local Prepare

local function Wait(frame, rec)
	if rec.waiting then
		return
	end
	rec.waiting = true
	ns.OutOfCombat(function()
		rec.waiting = nil
		if recs[frame] == rec and not ns.Forbidden(frame) then
			ns.EachPart(KEY, PART, Prepare, frame)
			Draw(frame, StateOf(frame), true)
		end
	end)
end

local function Place(frame, rec, cue)
	local bar = Bar(frame)
	if bar == nil then
		return false
	end
	local own = owns[frame]
	local right = type(own) == "table" and own.levelBox == true and Level(frame) or bar
	local above = Above(frame)
	local unit = ns.Pixels(cue.glow, 1)
	if cue.bar == bar and cue.right == right and cue.base == Base() and cue.unit ~= nil and math.abs(cue.unit - unit) < 0.001 and rec.above == above then
		return true
	end
	if Locked(frame) then
		Wait(frame, rec)
		return cue.bar ~= nil
	end
	Ring(cue, bar, right)
	if above ~= nil then
		cue.arrow:ClearAllPoints()
		cue.arrow:SetPoint("BOTTOM", above, "TOP", 0, ARROW_GAP)
	end
	rec.above = above
	local level = select(2, pcall(frame.GetFrameLevel, frame))
	if ns.Finite(level) then
		pcall(cue.holder.SetFrameLevel, cue.holder, level + LEVEL)
	end
	return true
end

local function Tank()
	local PT = Core()
	if PT == nil or type(PT.Role) ~= "function" then
		return false
	end
	local ok, role = pcall(PT.Role)
	return ok and role == "tank"
end

function Prepare(frame)
	local rec = recs[frame]
	if (rec and rec.cue) or Locked(frame) or not Wanted(frame) or not Tank() then
		return
	end
	local unit = frame.unit
	if ns.IsSecret(unit) or type(unit) ~= "string" then
		return
	end
	local ok, enemy = pcall(UnitCanAttack, "player", unit)
	if not ok or ns.IsSecret(enemy) or enemy ~= true then
		return
	end
	rec = rec or Record(frame)
	local cue = Build(frame)
	rec.cue = cue
	Place(frame, rec, cue)
end

local function Work(frame, state, snap)
	local rec = recs[frame]
	local kind = Wanted(frame) and Kind(state) or nil
	local r, g, b
	if kind then
		r, g, b = Colour(state)
	end
	if r == nil then
		if rec and rec.cue then
			Hide(rec.cue, snap)
		end
		return
	end
	rec = rec or Record(frame)
	local cue = rec.cue
	if cue == nil then
		if Locked(frame) then
			Wait(frame, rec)
			return
		end
		cue = Build(frame)
		rec.cue = cue
	end
	if not Place(frame, rec, cue) then
		Hide(cue, true)
		return
	end
	Paint(cue, kind, r, g, b)
	Show(cue, snap, false)
end

local function HideAll(snap)
	for _, rec in pairs(recs) do
		if rec.cue then
			pcall(Hide, rec.cue, snap)
		end
	end
end

function Draw(frame, state, snap)
	if frame == nil or ns.IsSecret(frame) or ns.Forbidden(frame) then
		return
	end
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, PART) then
		HideAll(true)
		return
	end
	if not ns.EachPart(KEY, PART, Work, frame, state, snap) and ns.PartStopped(KEY, PART) then
		HideAll(true)
	end
end

local function OnChange(frame, state)
	if type(state) ~= "table" then
		state = nil
	end
	if state == nil and recs[frame] == nil then
		return
	end
	Draw(frame, state)
end

local function Subscribe()
	if subscribed then
		return
	end
	local PT = ns.PlateThreat
	if type(PT) == "table" and type(PT.OnChange) == "function" then
		subscribed = (pcall(PT.OnChange, OnChange))
	end
end

EXTRA.show[#EXTRA.show + 1] = function(frame, own)
	Subscribe()
	if type(own) == "table" then
		owns[frame] = own
	end
	ns.EachPart(KEY, PART, Prepare, frame)
	local state = StateOf(frame)
	if state ~= nil or recs[frame] ~= nil then
		Draw(frame, state, true)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(frame, own)
	if type(own) == "table" then
		owns[frame] = own
	end
	local rec = recs[frame]
	if rec and rec.cue and rec.cue.on then
		rec.above = false
		Draw(frame, StateOf(frame), true)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(frame)
	local rec = recs[frame]
	if rec then
		rec.above = false
		if rec.cue then
			pcall(Hide, rec.cue, true)
		end
	end
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	Subscribe()
	local seen = {}
	ns.EachPlate(function(frame)
		seen[frame] = true
		local rec = recs[frame]
		if rec then
			rec.above = false
		end
		ns.EachPart(KEY, PART, Prepare, frame)
		Draw(frame, StateOf(frame), true)
	end)
	for frame, rec in pairs(recs) do
		if not seen[frame] and rec.cue then
			pcall(Hide, rec.cue, true)
		end
	end
end

function ns.PlateSlipSample(p, spec, o, on)
	if type(p) ~= "table" or type(spec) ~= "table" or type(o) ~= "table" then
		return
	end
	local P = ns.SetupDrawPlates
	local kind = on and Opt("threatSlipping") == true and SAMPLE_KINDS[spec.threat] or nil
	if kind and (type(P) ~= "table" or type(P.Damage) ~= "function" or P.Damage()) then
		kind = nil
	end
	local cue = p.slipCue
	if not kind then
		if cue then
			Hide(cue, true)
		end
		return
	end
	if cue == nil then
		cue = Build(p.f)
		p.slipCue = cue
	end
	Ring(cue, p.bar, o.levelSquare and p.lvl or p.bar)
	local m = p.m
	if type(m) == "table" and ns.Finite(m.top) and ns.Finite(m.BW) then
		local top = m.top
		if p.tvalue and p.tvalue:IsShown() and p.tvalueSide == "above" and ns.Finite(p.tvalueT) then
			top = math.max(top, p.tvalueT)
		end
		if p.opFrame and p.opFrame:IsShown() and ns.Finite(p.opT) then
			top = math.max(top, p.opT)
		end
		P.Put(p, cue.arrow, "BOTTOM", m.BW / 2, top + ARROW_GAP, cue.width, cue.height)
	end
	local r, g, b = ns.Colour(KEY .. "." .. (kind == "lost" and "threatBad" or "threatTransition"))
	Paint(cue, kind, r, g, b)
	pcall(cue.holder.SetFrameLevel, cue.holder, p.f:GetFrameLevel() + 12)
	Show(cue, true, type(P.Still) == "function" and P.Still(p) == true)
end

function ns.PlateSlipShown(p)
	local cue = type(p) == "table" and p.slipCue or nil
	return cue ~= nil and cue.on == true and cue.holder or nil
end
