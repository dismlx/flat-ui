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
local FADE_IN, FADE_OUT, FADE_BACK = 0.15, 0.2, 0.45
local ARROW, ARROW_ROW, ARROW_GAP, LEVEL = { 14, 11, 8, 5, 2 }, 2, 3, 22
local SHADE = { 0, 0, 0, 0.8 }
local KINDS = { bad = "lost", changing = "slipping" }
local SAMPLE_KINDS = { threatBad = "lost", threatTransition = "slipping" }
local GROW_SECONDS, GROW_MIN, GROW_MAX, GROW_DEFAULT = 0.2, 100, 160, 130
local RISE, TOP_LEVEL = 40, 9000
local SPOT_X = { LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, CENTER = 0.5, TOP = 0.5, BOTTOM = 0.5, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
local SPOT_Y = { BOTTOM = 0, BOTTOMLEFT = 0, BOTTOMRIGHT = 0, CENTER = 0.5, LEFT = 0.5, RIGHT = 0.5, TOP = 1, TOPLEFT = 1, TOPRIGHT = 1 }

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local boxed = setmetatable({}, { __mode = "k" })
local moving = {}
local S = { waited = 0 }
local subscribed = false
local driver
local Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Call(frame, method, ...)
	local fn = type(frame) == "table" and frame[method] or nil
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, frame, ...)
end

local function Read(frame, method)
	local ok, value = Call(frame, method)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
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

local function Allowed(frame)
	local restricted = C_RestrictedActions
	local check = type(restricted) == "table" and restricted.CheckAllowProtectedFunctions or nil
	if type(check) ~= "function" then
		return true
	end
	local ok, allowed = pcall(check, frame, true)
	if ok and not ns.IsSecret(allowed) and type(allowed) == "boolean" then
		return allowed
	end
	return true
end

local function Free(frame)
	return not ns.Forbidden(frame) and not Locked(frame) and Allowed(frame)
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

local function Factor(kind)
	if kind == nil or Opt("threatSlipGrow") ~= true then
		return 1
	end
	local percent = Opt("threatSlipScale")
	percent = ns.Finite(percent) and math.max(GROW_MIN, math.min(GROW_MAX, percent)) or GROW_DEFAULT
	local full = percent / 100
	if kind == "lost" then
		return full
	end
	return 1 + (full - 1) / 2
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
	local back = Group(holder)
	local dim = Own(back:CreateAnimation("Alpha"))
	dim:SetFromAlpha(1)
	dim:SetToAlpha(0)
	dim:SetDuration(FADE_BACK)
	pcall(dim.SetSmoothing, dim, "OUT")
	pcall(back.SetToFinalAlpha, back, true)
	back:SetScript("OnFinished", function()
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
		arrow:SetAlpha(1)
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
	cue.come, cue.go, cue.back, cue.pulse, cue.fade, cue.bob, cue.move = come, go, back, pulse, fade, bob, move
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

local function Lines(cue)
	local glow = cue.glow
	local unit, base, spread = ns.Pixels(glow, 1), cue.base or Base(), cue.spread or 1
	local ex, ey = 0, 0
	if spread > 1 then
		local ok, w, h = Call(glow, "GetSize")
		if ok and ns.Finite(w) and ns.Finite(h) and unit > 0 then
			ex = math.floor(w * (spread - 1) / 2 / unit + 0.5) * unit
			ey = math.floor(h * (spread - 1) / 2 / unit + 0.5) * unit
		end
	end
	for index, ring in ipairs(cue.rings) do
		local d = (base + index - 1) * unit
		local x, y = d + ex, d + ey
		Line(ring[1], glow, "TOPLEFT", "TOPRIGHT", -x, y, x, y, nil, unit)
		Line(ring[2], glow, "BOTTOMLEFT", "BOTTOMRIGHT", -x, -y, x, -y, nil, unit)
		Line(ring[3], glow, "TOPLEFT", "BOTTOMLEFT", -x, y - unit, -x, -y + unit, unit)
		Line(ring[4], glow, "TOPRIGHT", "BOTTOMRIGHT", x, y - unit, x, -y + unit, unit)
	end
	cue.unit = unit
end

local function Ring(cue, bar, right)
	local glow = cue.glow
	glow:ClearAllPoints()
	glow:SetPoint("LEFT", bar, "LEFT", 0, 0)
	glow:SetPoint("TOP", bar, "TOP", 0, 0)
	glow:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	glow:SetPoint("RIGHT", right or bar, "RIGHT", 0, 0)
	cue.base, cue.bar, cue.right = Base(), bar, right or bar
	Lines(cue)
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

local function Calm(cue)
	local back = cue.back
	local playing = back ~= nil and back:IsPlaying()
	if playing then
		pcall(back.Stop, back)
	end
	cue.arrow:SetAlpha(1)
	return playing
end

local function Show(cue, snap, still)
	cue.still = still
	if not cue.on then
		cue.on = true
		Calm(cue)
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
		local going = cue.go and cue.go:IsPlaying()
		if snap and (Calm(cue) or going) then
			if cue.go then
				pcall(cue.go.Stop, cue.go)
			end
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
	if type(ns.PlateQuestAbove) == "function" then
		local ok, mark = pcall(ns.PlateQuestAbove, frame)
		if ok and type(mark) == "table" then
			return mark
		end
	end
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
	if name and (type(ns.PlateNameShown) ~= "function" or ns.PlateNameShown(frame) ~= false) then
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
	S.waited = S.waited + 1
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
	local level = Read(frame, "GetFrameLevel")
	if ns.Finite(level) and Call(cue.holder, "SetFrameLevel", level + LEVEL) then
		cue.level = level + LEVEL
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

local function Now()
	return type(GetTime) == "function" and GetTime() or nil
end

local function Channel()
	return { now = 1, from = 1, to = 1, start = 0 }
end

local function Aim(channel, to, snap)
	if snap then
		channel.now, channel.from, channel.to = to, to, to
	elseif channel.to ~= to then
		channel.from, channel.to, channel.start = channel.now, to, Now()
	end
end

local function Ease(channel, now)
	if channel.now == channel.to then
		return true
	end
	local share = ns.Finite(now) and ns.Finite(channel.start) and (now - channel.start) / GROW_SECONDS or 1
	if share >= 1 then
		channel.now = channel.to
		return true
	end
	share = math.max(0, share)
	channel.now = channel.from + (channel.to - channel.from) * share * share * (3 - 2 * share)
	return false
end

local function Points(frame)
	local ok, count = Call(frame, "GetNumPoints")
	if not ok or not ns.Finite(count) or count < 1 then
		return nil
	end
	local list = {}
	for index = 1, count do
		local read, point, relative, relativePoint, x, y = Call(frame, "GetPoint", index)
		if not read or ns.IsSecret(point) or type(point) ~= "string" or ns.IsSecret(relative) or ns.IsSecret(relativePoint)
			or type(relativePoint) ~= "string" or not ns.Finite(x) or not ns.Finite(y) then
			return nil
		end
		list[index] = { point, relative, relativePoint, x, y }
	end
	return list
end

local function Same(a, b)
	return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
		and math.abs(a[4] - b[4]) < 0.01 and math.abs(a[5] - b[5]) < 0.01
end

local function Fills(points)
	local relative, seen = points[1][2], {}
	if relative == nil then
		return nil
	end
	for _, point in ipairs(points) do
		if point[2] ~= relative or point[3] ~= point[1] or point[4] ~= 0 or point[5] ~= 0 then
			return nil
		end
		seen[point[1]] = true
	end
	if (seen.TOPLEFT and seen.BOTTOMRIGHT) or (seen.TOPRIGHT and seen.BOTTOMLEFT) then
		return relative
	end
	return nil
end

local function Anchor(frame, points)
	for _, point in ipairs(points) do
		Call(frame, "SetPoint", point[1], point[2], point[3], point[4], point[5])
	end
end

local function Ours(frame, base)
	local points = Points(frame)
	return points ~= nil and #points == 1 and Same(points[1], base.set)
end

local function Capture(frame)
	local scale, level = Read(frame, "GetScale"), Read(frame, "GetFrameLevel")
	local points = Points(frame)
	local relative = points and Fills(points) or nil
	if not (ns.Finite(scale) and scale > 0 and ns.Finite(level) and relative) or ns.Forbidden(relative) then
		return nil
	end
	local ok, w, h = Call(frame, "GetSize")
	if not ok or not ns.Finite(w) or not ns.Finite(h) or w <= 0 or h <= 0 then
		return nil
	end
	return { scale = scale, level = level, using = Read(frame, "IsUsingParentLevel") == true, points = points, rel = relative, w = w, h = h, at = 1 }
end

local function Top(frame)
	local top = 0
	ns.EachPlate(function(other)
		if other ~= frame then
			local rec = recs[other]
			local lifted = rec and rec.grow and rec.grow.base
			local level = lifted and lifted.raised and lifted.level or Read(other, "GetFrameLevel")
			if ns.Finite(level) and level > top then
				top = level
			end
		end
	end)
	return top
end

local function Later(frame, rec)
	if rec == nil or rec.later or not InCombatLockdown() then
		return
	end
	rec.later = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.later = nil
		if recs[frame] == rec and not ns.Forbidden(frame) then
			Draw(frame, StateOf(frame))
		end
	end)
end

local function Lift(frame, grow)
	local base = grow.base
	local want = math.min(math.max(grow.top or 0, base.level) + RISE, TOP_LEVEL)
	if want <= base.level or (base.raised and base.raised >= want) then
		return
	end
	if base.using and not base.unparented and Call(frame, "SetUsingParentLevel", false) then
		base.unparented = true
	end
	if Call(frame, "SetFrameLevel", want) then
		base.raised = want
	end
end

local function Settle(frame, grow)
	local base = grow.base
	grow.base = nil
	Aim(grow.plate, 1, true)
	if base == nil then
		return
	end
	Call(frame, "SetScale", base.scale)
	if base.moved and Ours(frame, base) then
		Call(frame, "ClearAllPoints")
		Anchor(frame, base.points)
	end
	if (base.raised or base.unparented) and not (base.unparented and Call(frame, "SetUsingParentLevel", true)) then
		Call(frame, "SetFrameLevel", base.level)
	end
end

local function Hold(frame, grow)
	local base = grow.base
	if base == nil then
		return
	end
	if not Free(frame) then
		Aim(grow.plate, base.at, true)
		Later(frame, recs[frame])
		return
	end
	local share = grow.plate.now
	if (base.moved and not Ours(frame, base)) or (share <= 1 and grow.plate.to <= 1) then
		Settle(frame, grow)
		return
	end
	if not base.moved then
		base.moved, base.set = true, { "CENTER", base.rel, "CENTER", 0, 0 }
		Call(frame, "ClearAllPoints")
		if not Call(frame, "SetPoint", "CENTER", base.rel, "CENTER", 0, 0) then
			Anchor(frame, base.points)
			base.moved = false
			Settle(frame, grow)
			return
		end
	end
	local w, h = base.w, base.h
	local parent = Read(frame, "GetParent")
	if parent ~= nil and parent == base.rel then
		local ok, pw, ph = Call(base.rel, "GetSize")
		if ok and ns.Finite(pw) and ns.Finite(ph) and pw > 0 and ph > 0 then
			w, h = pw / base.scale, ph / base.scale
		end
	end
	Call(frame, "SetSize", w, h)
	if Call(frame, "SetScale", base.scale * share) then
		base.at = share
	end
end

local function Spread(cue, share)
	cue.spread = share
	if cue.arrowAt ~= share and not Locked(cue.arrow) and Call(cue.arrow, "SetScale", share) then
		cue.arrowAt = share
	end
	if cue.bar then
		Lines(cue)
	end
end

local function Cover(frame, rec, grow)
	local cue = rec.cue
	local level = cue and Read(frame, "GetFrameLevel") or nil
	if not ns.Finite(level) then
		return
	end
	local want = level + LEVEL
	if grow.top and (grow.cue.to > 1 or grow.cue.now > 1) then
		want = math.max(want, math.min(grow.top + RISE + LEVEL, TOP_LEVEL))
	end
	if cue.level ~= want and not Locked(cue.holder) and Call(cue.holder, "SetFrameLevel", want) then
		cue.level = want
	end
end

local function ApplyPlate(grow)
	local frame = grow.owner
	if ns.Forbidden(frame) then
		return
	end
	Hold(frame, grow)
	local rec = recs[frame]
	if rec and rec.cue then
		Spread(rec.cue, grow.cue.now)
		Cover(frame, rec, grow)
	end
end

local function Step(grow, now)
	local plate = Ease(grow.plate, now)
	local cue = Ease(grow.cue, now)
	local ok, err = pcall(grow.Apply, grow)
	if not ok then
		ns.Note(KEY, "Nameplates: enlarging enemies you are losing failed. " .. tostring(err))
		return true
	end
	if plate and cue then
		if grow.again then
			grow.again = nil
			return false
		end
		return true
	end
	return false
end

local function Tick()
	local now, left = Now(), false
	for grow in pairs(moving) do
		if Step(grow, now) then
			moving[grow] = nil
		else
			left = true
		end
	end
	if not left and driver then
		driver:SetScript("OnUpdate", nil)
	end
end

local function Driver()
	if driver == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		driver = ok and type(frame) == "table" and Own(frame) or false
	end
	return driver or nil
end

local function Push(grow)
	if Step(grow, Now()) then
		moving[grow] = nil
		return
	end
	local frame = Driver()
	if frame then
		moving[grow] = true
		frame:SetScript("OnUpdate", Tick)
		return
	end
	moving[grow] = nil
	Aim(grow.plate, grow.plate.to, true)
	Aim(grow.cue, grow.cue.to, true)
	grow.again = nil
	pcall(grow.Apply, grow)
end

local function Grow(frame, rec, kind, snap)
	local goal = Factor(kind)
	local grow = rec.grow
	if grow == nil then
		if goal == 1 then
			return
		end
		grow = { owner = frame, plate = Channel(), cue = Channel(), Apply = ApplyPlate }
		rec.grow = grow
	end
	grow.goal = goal
	local free = Free(frame)
	local base = grow.base
	if free and base and base.moved and not Ours(frame, base) then
		Settle(frame, grow)
		base = nil
	end
	if free and base == nil and goal > 1 then
		base = Capture(frame)
		grow.base = base
	end
	if goal > 1 then
		grow.top = Top(frame)
	end
	if base and free then
		Aim(grow.plate, goal, snap)
		Aim(grow.cue, 1, snap)
		if goal > 1 then
			Lift(frame, grow)
		end
	elseif base then
		Aim(grow.plate, base.at, true)
		Aim(grow.cue, math.max(1, goal / base.at), snap)
		Later(frame, rec)
	else
		Aim(grow.plate, 1, true)
		Aim(grow.cue, goal, snap)
		if goal > 1 then
			Later(frame, rec)
		end
	end
	Push(grow)
end

local function Work(frame, state, snap)
	local rec = recs[frame]
	local wanted = Wanted(frame)
	local kind = wanted and Kind(state) or nil
	local r, g, b
	if kind then
		r, g, b = Colour(state)
	end
	if r == nil then
		if rec then
			if rec.cue then
				Hide(rec.cue, snap)
			end
			Grow(frame, rec, nil, snap or not wanted)
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
		Grow(frame, rec, nil, true)
		return
	end
	Paint(cue, kind, r, g, b)
	Show(cue, snap, false)
	Grow(frame, rec, kind, snap)
end

local function HideAll(snap)
	for frame, rec in pairs(recs) do
		if rec.cue then
			pcall(Hide, rec.cue, snap)
		end
		if rec.grow then
			pcall(Grow, frame, rec, nil, true)
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

local function Taken(state, previous)
	return type(previous) == "table" and previous.tank == true and previous.want == "bad" and previous.pet ~= true and previous.tapped ~= true
		and type(state) == "table" and state.tank == true and state.want == "good"
end

local function Back(frame, state)
	local rec = recs[frame]
	local cue = rec and rec.cue
	if cue == nil or cue.on or cue.back == nil or cue.bar == nil then
		return
	end
	local r, g, b = Colour(state)
	if r == nil then
		return
	end
	if cue.go then
		pcall(cue.go.Stop, cue.go)
	end
	Paint(cue, "back", r, g, b)
	Moving(cue, false)
	cue.arrow:SetAlpha(0)
	cue.holder:SetAlpha(1)
	cue.holder:Show()
	pcall(cue.back.Stop, cue.back)
	pcall(cue.back.Play, cue.back)
end

local function OnChange(frame, state, previous)
	if type(state) ~= "table" then
		state = nil
	end
	local rec = recs[frame]
	if state == nil and rec == nil then
		return
	end
	local was = rec ~= nil and rec.cue ~= nil and rec.cue.on == true
	Draw(frame, state)
	if was and Opt("threatSlipBack") == true and Taken(state, previous) and Wanted(frame) then
		ns.EachPart(KEY, PART, Back, frame, state)
	end
end

function ns.PlateSlipPlace(frame)
	local rec = frame ~= nil and not ns.IsSecret(frame) and recs[frame] or nil
	if rec and rec.cue and rec.cue.on and not ns.Forbidden(frame) then
		ns.EachPart(KEY, PART, Place, frame, rec, rec.cue)
	end
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
		if rec.grow then
			pcall(Grow, frame, rec, nil, true)
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
		if not seen[frame] then
			if rec.cue then
				pcall(Hide, rec.cue, true)
			end
			if rec.grow then
				pcall(Grow, frame, rec, nil, true)
			end
		end
	end
end

local function Recheck()
	local list = {}
	for frame, rec in pairs(recs) do
		local grow = rec.grow
		if grow and (grow.base or grow.goal > 1 or grow.cue.now > 1) then
			list[#list + 1] = frame
		end
	end
	for _, frame in ipairs(list) do
		if not ns.Forbidden(frame) then
			Draw(frame, StateOf(frame))
		end
	end
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", Recheck)
ns.AddEvent(KEY, "ADDON_RESTRICTION_STATE_CHANGED", Recheck)

EXTRA.status[#EXTRA.status + 1] = function()
	if not On() or Core() == nil then
		return nil
	end
	if not Tank() then
		return "Mark enemies you are losing: off while you do not count as a tank."
	end
	local lost, slipping, enlarged, instead = 0, 0, 0, 0
	for _, rec in pairs(recs) do
		local cue, grow = rec.cue, rec.grow
		if cue and cue.on then
			if cue.kind == "lost" then
				lost = lost + 1
			elseif cue.kind == "slipping" then
				slipping = slipping + 1
			end
		end
		if grow and grow.base and grow.plate.now > 1 then
			enlarged = enlarged + 1
		end
		if grow and grow.cue.now > 1 then
			instead = instead + 1
		end
	end
	local line = ("Mark enemies you are losing: %d lost and %d slipping marked"):format(lost, slipping)
	if Opt("threatSlipGrow") == true then
		line = line .. (", %d plates enlarged, %d marked larger while the game kept their plate"):format(enlarged, instead)
	end
	return line .. (", %d plates waited for the end of a fight."):format(S.waited)
end

local function ApplySample(grow)
	local p = grow.owner
	local frame = p.f
	local scale, points = Read(frame, "GetScale"), Points(frame)
	local ok, w, h = Call(frame, "GetSize")
	if not (ns.Finite(scale) and scale > 0 and points and #points == 1 and ok and ns.Finite(w) and ns.Finite(h)) then
		return
	end
	if grow.set == nil or math.abs(scale - grow.set) > 0.0001 then
		grow.scale = scale
	end
	if not Same(points[1], grow.spot) then
		grow.anchor = points[1]
	end
	local anchor, share = grow.anchor, grow.plate.now
	local ax, ay = SPOT_X[anchor[1]], SPOT_Y[anchor[1]]
	if ax == nil then
		return
	end
	local dx, dy = (0.5 - ax) * w, (0.5 - ay) * h
	local spot = { anchor[1], anchor[2], anchor[3], (anchor[4] + dx) / share - dx, (anchor[5] + dy) / share - dy }
	grow.set, grow.spot = grow.scale * share, spot
	frame:SetScale(grow.set)
	frame:ClearAllPoints()
	frame:SetPoint(spot[1], spot[2], spot[3], spot[4], spot[5])
	local level = Read(frame, "GetFrameLevel")
	if not ns.Finite(level) then
		return
	end
	if grow.raised == nil or level ~= grow.raised then
		grow.level, grow.raised = level, nil
	end
	if share > 1 or grow.plate.to > 1 then
		local want = math.min(grow.level + RISE, TOP_LEVEL)
		if level ~= want then
			frame:SetFrameLevel(want)
		end
		grow.raised = want
	elseif grow.raised then
		frame:SetFrameLevel(grow.level)
		grow.raised = nil
	end
end

local function Box(p, share)
	local box, m = p.box, p.m
	if type(box) ~= "table" or boxed[box] or type(m) ~= "table" or not ns.Finite(m.BW) or not ns.Finite(m.top) then
		return
	end
	if not (ns.Finite(box.l) and ns.Finite(box.r) and ns.Finite(box.b) and ns.Finite(box.t)) then
		return
	end
	boxed[box] = true
	local cx, cy = m.BW / 2, m.top / 2
	box.l, box.r = cx + (box.l - cx) * share, cx + (box.r - cx) * share
	box.b, box.t = cy + (box.b - cy) * share, cy + (box.t - cy) * share
end

local function SampleGrow(p, kind)
	local goal = Factor(kind)
	local grow = p.slipGrow
	if grow == nil then
		if goal == 1 or type(p.f) ~= "table" then
			return
		end
		grow = { owner = p, plate = Channel(), cue = Channel(), Apply = ApplySample }
		p.slipGrow = grow
	end
	grow.goal = goal
	local P = ns.SetupDrawPlates
	local ok, snaps = false, nil
	if type(P) == "table" and type(P.Snaps) == "function" then
		ok, snaps = pcall(P.Snaps, p)
	end
	Aim(grow.plate, goal, not ok or snaps ~= false)
	grow.again = true
	Push(grow)
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
		SampleGrow(p, nil)
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
	SampleGrow(p, kind)
	pcall(cue.holder.SetFrameLevel, cue.holder, p.f:GetFrameLevel() + 12)
	Show(cue, true, type(P.Still) == "function" and P.Still(p) == true)
end

function ns.PlateSlipShown(p)
	local cue = type(p) == "table" and p.slipCue or nil
	return cue ~= nil and cue.on == true and cue.holder or nil
end

function ns.PlateSlipBox(p)
	local grow = type(p) == "table" and p.slipGrow or nil
	if grow and ns.Finite(grow.goal) and grow.goal > 1 then
		Box(p, grow.goal)
	end
end

function ns.PlateSlipPlaced(p, label, gap)
	local grow = type(p) == "table" and p.slipGrow or nil
	if grow == nil or type(p.f) ~= "table" then
		return
	end
	ApplySample(grow)
	local share, scale, m, box = grow.plate.now, grow.scale, p.m, p.box
	if label == nil or share == 1 or type(m) ~= "table" or type(box) ~= "table" then
		return
	end
	if not (ns.Finite(share) and ns.Finite(scale) and ns.Finite(gap) and ns.Finite(m.BW) and ns.Finite(m.center) and ns.Finite(box.l)) then
		return
	end
	label:ClearAllPoints()
	label:SetPoint("RIGHT", p.f, "BOTTOMLEFT", (box.l + m.BW / 2 * (share - 1)) * scale - gap, m.center * share * scale)
end
