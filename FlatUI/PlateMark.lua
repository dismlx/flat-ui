local _, ns = ...

local KEY = "nameplates"
local PART = "target mark"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local K = { LEVEL = 9200, SAMPLE = 9, RING = 2, GAP = 2, ROOM = 3, SETTLE = 0.05 }
local ARROW, COLUMN = { 11, 9, 7, 5, 3, 1 }, 1
local SHADE = { 0, 0, 0, 0.8 }

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local S = { on = false, shown = nil, made = 0, waited = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
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

local function Usable(frame)
	if not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

local function Bar(unitFrame)
	local container = Usable(unitFrame.HealthBarsContainer)
	return container and Usable(container.healthBar) or nil
end

local function Level(unitFrame)
	return Usable(unitFrame.PlayerLevelDiffFrame)
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("targetMark") == true
end

local function Locked(unitFrame, bar)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame) or ns.MaybeProtected(bar))
end

local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(K.SETTLE, fn)
	else
		fn()
	end
end

local function RingPx()
	local px = Opt("threatRingPx")
	return ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or K.RING
end

local function MarkPx()
	return RingPx() + 1
end

local function Outer()
	local outer = MarkPx()
	if Opt("threat") == true and Opt("threatGlow") ~= "off" then
		local thickness = ns.Get("general.thickness")
		outer = math.max(outer, (ns.Finite(thickness) and thickness or 1) + K.GAP + RingPx())
	end
	return outer
end

function ns.PlateMarkLevel()
	return K.LEVEL + 2
end

function ns.PlateMarkPx()
	if Opt("targetMark") ~= true then
		return nil
	end
	return MarkPx()
end

local function Arrow(holder, side)
	local frame = Own(CreateFrame("Frame", nil, holder))
	frame:SetSize(#ARROW * COLUMN + 1, ARROW[1] + 1)
	local pieces = {}
	for index, height in ipairs(ARROW) do
		local x = (index - 1) * COLUMN
		local shade = Own(frame:CreateTexture(nil, "BORDER"))
		local piece = Own(frame:CreateTexture(nil, "ARTWORK"))
		shade:SetSize(COLUMN, height)
		piece:SetSize(COLUMN, height)
		if side == 1 then
			piece:SetPoint("LEFT", frame, "LEFT", x, 0)
			shade:SetPoint("LEFT", frame, "LEFT", x + 1, -1)
		else
			piece:SetPoint("RIGHT", frame, "RIGHT", -x - 1, 0)
			shade:SetPoint("RIGHT", frame, "RIGHT", -x, -1)
		end
		shade:SetColorTexture(SHADE[1], SHADE[2], SHADE[3], SHADE[4])
		pieces[index] = piece
	end
	return { frame = frame, pieces = pieces, width = #ARROW * COLUMN + 1, height = ARROW[1] + 1 }
end

local function Build(parent, level, outlineOf)
	local holder = Own(CreateFrame("Frame", nil, parent))
	if level then
		pcall(holder.SetFrameLevel, holder, level)
	end
	local box = Own(CreateFrame("Frame", nil, holder))
	local mark = { holder = holder, box = box }
	local outline = outlineOf and outlineOf(box) or ns.SetOutlineArea(ns.Outline(box, box), KEY)
	ns.KeepOutline(outline)
	ns.SetOutline(outline, true, false)
	mark.outline = outline
	mark.arrows = { Arrow(holder, 1), Arrow(holder, 2) }
	return mark
end

local function Paint(mark)
	local r, g, b = ns.Colour(KEY .. ".targetMarkColour")
	ns.SetOutlineColour(mark.outline, r, g, b)
	if mark.r == r and mark.g == g and mark.b == b then
		return
	end
	mark.r, mark.g, mark.b = r, g, b
	for _, arrow in ipairs(mark.arrows) do
		for _, piece in ipairs(arrow.pieces) do
			piece:SetColorTexture(r, g, b, 1)
		end
	end
end

local function Show(mark, on)
	mark.holder:SetAlpha(on and 1 or 0)
	local arrows = on and Opt("targetArrows") == true
	for _, arrow in ipairs(mark.arrows) do
		arrow.frame:SetAlpha(arrows and 1 or 0)
	end
end

local function Span(region)
	local ok, l, b, w, h = Call(region, "GetRect")
	local scale = Read(region, "GetEffectiveScale")
	if not (ok and ns.Finite(l) and ns.Finite(b) and ns.Finite(w) and ns.Finite(h) and ns.Finite(scale) and scale > 0) then
		return nil
	end
	return l * scale, (l + w) * scale, b * scale, (b + h) * scale
end

local function Beside(region, low, high)
	if region == nil or ns.Forbidden(region) or Read(region, "IsVisible") ~= true then
		return nil
	end
	local l, r, b, t = Span(region)
	if l == nil or t <= low or b >= high then
		return nil
	end
	return l, r
end

local function Reach(unitFrame, own, bar, right)
	local l, _, b, t = Span(bar)
	local _, r = Span(right)
	if not (l and r) then
		return 0, 0
	end
	local lo, hi = l, r
	local list = { Level(unitFrame) or false, Usable(unitFrame.RaidTargetFrame) or false }
	if type(own) == "table" and own.classShown == true and type(own.icon) == "table" then
		list[#list + 1] = own.icon
	end
	for _, region in ipairs(list) do
		if region then
			local left, far = Beside(region, b, t)
			if left then
				lo, hi = math.min(lo, left), math.max(hi, far)
			end
		end
	end
	return l - lo, hi - r
end

local function Aim(mark, left, far)
	local first, second = mark.arrows[1].frame, mark.arrows[2].frame
	local scale = Read(first, "GetEffectiveScale")
	if not (ns.Finite(scale) and scale > 0) then
		scale = 1
	end
	local outer, gap = ns.Pixels(first, Outer()), ns.Pixels(first, K.ROOM)
	first:ClearAllPoints()
	first:SetPoint("RIGHT", mark.box, "LEFT", -(math.max(left / scale, outer) + gap), 0)
	second:ClearAllPoints()
	second:SetPoint("LEFT", mark.box, "RIGHT", math.max(far / scale, outer) + gap, 0)
end

local Make

local function Wait(unitFrame, rec)
	if rec.waiting then
		return
	end
	rec.waiting = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.waiting = nil
		if recs[unitFrame] ~= rec or ns.Forbidden(unitFrame) then
			return
		end
		ns.EachPart(KEY, PART, function()
			if S.on then
				Make(unitFrame)
				if S.shown == unitFrame or ns.PlateUnitFrame("target") == unitFrame then
					S.shown = nil
					ns.PlateMarkUpdate()
				end
			end
		end)
	end)
end

local function Place(unitFrame, rec)
	local mark, bar = rec.mark, Bar(unitFrame)
	if not (mark and bar) then
		return
	end
	if Locked(unitFrame, bar) then
		Wait(unitFrame, rec)
		return
	end
	local own = owns[unitFrame]
	local right = type(own) == "table" and own.levelBox == true and Level(unitFrame) or bar
	local box = mark.box
	box:ClearAllPoints()
	box:SetPoint("LEFT", bar, "LEFT", 0, 0)
	box:SetPoint("TOP", bar, "TOP", 0, 0)
	box:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	box:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	ns.SetOutlineThickness(mark.outline, MarkPx())
	Aim(mark, Reach(unitFrame, own, bar, right))
end

function Make(unitFrame)
	local rec = recs[unitFrame]
	if rec and rec.mark then
		return rec
	end
	local bar = Bar(unitFrame)
	if bar == nil then
		return nil
	end
	if rec == nil then
		rec = {}
		recs[unitFrame] = rec
	end
	if Locked(unitFrame, bar) then
		Wait(unitFrame, rec)
		return nil
	end
	local mark = Build(bar, K.LEVEL)
	mark.holder:SetAllPoints(bar)
	Show(mark, false)
	rec.mark = mark
	S.made = S.made + 1
	Place(unitFrame, rec)
	return rec
end

local function Styled(unitFrame)
	local own = owns[unitFrame]
	if type(own) ~= "table" or own.styleOn ~= true then
		return false
	end
	local only = unitFrame.showOnlyName
	return ns.IsSecret(only) or only ~= true
end

local function Hide(unitFrame)
	local rec = unitFrame and recs[unitFrame]
	if rec and rec.mark then
		Show(rec.mark, false)
	end
end

function ns.PlateMarkUpdate()
	local target = S.on and type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame("target") or nil
	if target ~= nil and (ns.Forbidden(target) or not Styled(target)) then
		Hide(target)
		target = nil
	end
	if S.shown ~= target then
		Hide(S.shown)
		S.shown = nil
	end
	if target == nil then
		return
	end
	local fresh = S.shown ~= target
	local rec = Make(target)
	if rec == nil then
		return
	end
	if fresh then
		Place(target, rec)
		Soon(function()
			if S.shown == target and recs[target] == rec and not ns.Forbidden(target) then
				ns.EachPart(KEY, PART, Place, target, rec)
			end
		end)
	end
	Paint(rec.mark)
	Show(rec.mark, true)
	S.shown = target
end

local function Prepare(unitFrame)
	if not S.on or ns.Forbidden(unitFrame) then
		return
	end
	local own = owns[unitFrame]
	if type(own) == "table" and own.styleOn == false then
		return
	end
	Make(unitFrame)
end

local function StandDown()
	for unitFrame, rec in pairs(recs) do
		if rec.mark and not ns.Forbidden(unitFrame) then
			Show(rec.mark, false)
		end
	end
	S.shown = nil
end

local function Sync()
	S.on = Wanted()
	if not S.on then
		StandDown()
		return
	end
	if type(ns.EachPlate) == "function" then
		ns.EachPlate(function(unitFrame)
			ns.EachPart(KEY, PART, Prepare, unitFrame)
		end)
	end
	for unitFrame, rec in pairs(recs) do
		if rec.mark and not ns.Forbidden(unitFrame) then
			Paint(rec.mark)
			ns.EachPart(KEY, PART, Place, unitFrame, rec)
		end
	end
	S.shown = nil
	ns.PlateMarkUpdate()
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	ns.EachPart(KEY, PART, ns.PlateMarkUpdate)
end)
ns.AddEvent(KEY, "RAID_TARGET_UPDATE", function()
	local shown = S.shown
	local rec = shown and recs[shown]
	if rec and not ns.Forbidden(shown) then
		ns.EachPart(KEY, PART, Place, shown, rec)
	end
end)

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	if not S.on then
		return
	end
	ns.EachPart(KEY, PART, Prepare, unitFrame)
	if ns.PlateUnitFrame("target") == unitFrame then
		if S.shown == unitFrame then
			S.shown = nil
		end
		ns.EachPart(KEY, PART, ns.PlateMarkUpdate)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	local rec = recs[unitFrame]
	if S.on and S.shown == unitFrame and rec and rec.mark then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	pcall(Hide, unitFrame)
	if S.shown == unitFrame then
		S.shown = nil
	end
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		pcall(StandDown)
	end
end

EXTRA.status[#EXTRA.status + 1] = function()
	if Opt("targetMark") ~= true then
		return nil
	end
	return ("Target mark: %s, %d plates ready, %d plates waited for the end of a fight for theirs."):format(S.on and "on" or "off", S.made, S.waited)
end

function ns.PlateMarkSample(p, spec, o, m)
	if type(p) ~= "table" or type(spec) ~= "table" or type(o) ~= "table" or type(m) ~= "table" or type(p.f) ~= "table" then
		return
	end
	local mark = p.targetMark
	local on = spec.target == true and o.styled == true and Opt("targetMark") == true
	if not on then
		if mark then
			mark.holder:Hide()
		end
		return
	end
	local P = ns.SetupDrawPlates
	if mark == nil then
		local outlineOf = type(P) == "table" and type(P.Outline) == "function" and function(box)
			return P.Outline(p.S, box, box)
		end or nil
		mark = Build(p.f, p.bar:GetFrameLevel() + K.SAMPLE, outlineOf)
		mark.holder:SetAllPoints(p.f)
		p.targetMark = mark
	end
	pcall(mark.holder.SetFrameLevel, mark.holder, p.bar:GetFrameLevel() + K.SAMPLE)
	local box = mark.box
	box:ClearAllPoints()
	box:SetPoint("LEFT", p.bar, "LEFT", 0, 0)
	box:SetPoint("TOP", p.bar, "TOP", 0, 0)
	box:SetPoint("BOTTOM", p.bar, "BOTTOM", 0, 0)
	box:SetPoint("RIGHT", o.levelSquare and p.lvl or p.bar, "RIGHT", 0, 0)
	ns.SetOutlineThickness(mark.outline, MarkPx())
	Paint(mark)
	mark.holder:SetAlpha(1)
	mark.holder:Show()
	local arrows = Opt("targetArrows") == true
	for _, arrow in ipairs(mark.arrows) do
		arrow.frame:SetAlpha(1)
		arrow.frame:SetShown(arrows)
	end
	if not arrows or type(P) ~= "table" or type(P.Put) ~= "function" then
		return
	end
	local first, second = mark.arrows[1], mark.arrows[2]
	local outer, gap = ns.Pixels(first.frame, Outer()), ns.Pixels(first.frame, K.ROOM)
	local icon = p.iconFrame and p.iconFrame:IsShown()
	local shift = ns.Finite(m.iconShift) and m.iconShift or 0
	local lo = -shift
	if type(P.LeftEdge) == "function" then
		local ok, edge = pcall(P.LeftEdge, p, o, m)
		if ok and ns.Finite(edge) then
			lo = math.min(lo, edge)
		end
	end
	if p.tvalueSide == "left" and ns.Finite(p.tvalueL) then
		lo = math.min(lo, p.tvalueL)
	end
	local right = o.levelSquare and (m.LX + m.LW) or m.BW
	local hi = right
	local level = m.levelOut and o.level ~= "hidden"
	if level then
		hi = math.max(hi, m.LX + m.LW)
	end
	if icon and Opt("classPosition") == "right" then
		local size, x, spacing = Opt("classSize"), Opt("classX"), o.classGap
		if o.classFit == "bar" then
			size = m.HH
		end
		if ns.Finite(size) and ns.Finite(x) and ns.Finite(spacing) then
			hi = math.max(hi, (level and m.LX + m.LW or m.BW) + x + spacing + size)
		end
	end
	if p.tvalueSide == "right" and ns.Finite(p.tvalueR) then
		hi = math.max(hi, p.tvalueR)
	end
	P.Put(p, first.frame, "RIGHT", math.min(lo, -outer) - gap, m.center, first.width, first.height)
	P.Put(p, second.frame, "LEFT", math.max(hi, right + outer) + gap, m.center, second.width, second.height)
end

function ns.PlateMarkShown(p)
	local mark = type(p) == "table" and p.targetMark or nil
	if mark and mark.holder:IsShown() then
		return mark.holder
	end
	return nil
end
