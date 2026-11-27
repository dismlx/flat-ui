local _, ns = ...

local KEY = "nameplates"
local PART = "target mark"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local K = { LEVEL = 9200, MARK = 8100, SAMPLE = 9, COPY = 10, RING = 2, GAP = 2, BAND = 3, ROOM = 3, LOOK = 0.05, COLUMNS = 8, TALL = 2.2, SHORT = 16,
	MOST = 44, WIDE = 0.62, SIZE = 100, SHARP = 1600, STEP = 4, FAINT = 0.05, SLIDE = 8, SLIDE_SECONDS = 0.15, BOB = 2, BOB_SECONDS = 0.55, LOW = 20 }
local GLOW = { 0.62, 0.45, 0.32, 0.21, 0.13, 0.07, 0.03 }
local SHADE = { 0, 0, 0, 0.75 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local owns = setmetatable({}, { __mode = "k" })
local S = { on = false, running = false }
local SLOTS = {
	{ unit = "target", colour = "targetMarkColour", sample = "targetMark", rise = 0, look = 0, styled = false, marked = 0 },
	{ unit = "focus", colour = "focusColour", sample = "focusMark", rise = -5, look = 0, styled = false, marked = 0 },
}
local CURVES = {}
local driver

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

local function Unsnap(texture)
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	return texture
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("targetMark") == true
end

local function RingPx()
	local px = Opt("threatRingPx")
	return ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or K.RING
end

local function Ringed()
	return Opt("threat") == true and Opt("threatGlow") ~= "off"
end

local function Border()
	local thickness = ns.Get("general.thickness")
	return (ns.Finite(thickness) and thickness >= 0 and thickness or 1) + K.GAP
end

local function MarkPx()
	if Ringed() then
		return math.max(K.BAND, Border())
	end
	return math.max(K.BAND, RingPx()) + K.GAP
end

local function GlowFrom(ring)
	if ring then
		return math.max(MarkPx(), Border() + RingPx())
	end
	return MarkPx()
end

local function RingOn(unitFrame)
	if not Ringed() then
		return false
	end
	if type(ns.PlateRingShown) ~= "function" then
		return true
	end
	local ok, shown = pcall(ns.PlateRingShown, unitFrame)
	return not ok or shown == true
end

local function Glowing()
	return Opt("targetMarkGlow") ~= false
end

local function Grain()
	local ok, _, high = pcall(GetPhysicalScreenSize)
	if ok and ns.Finite(high) and high >= K.SHARP then
		return 2
	end
	return 1
end

local function Reach()
	return GlowFrom(Ringed()) + (Glowing() and #GLOW * Grain() or 0)
end

local function Tall(height)
	local percent = Opt("targetArrowSize")
	percent = ns.Finite(percent) and percent > 0 and percent or K.SIZE
	local tall = ns.Finite(height) and height > 0 and height * K.TALL or K.SHORT
	tall = math.min(K.MOST, math.max(K.SHORT, tall)) * percent / 100
	return math.floor(tall * K.STEP + 0.5) / K.STEP
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

local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

local function Motion(arrow)
	local sign = arrow.side == 2 and -1 or 1
	local frame = arrow.frame
	local come = Own(frame:CreateAnimationGroup())
	local out = Own(come:CreateAnimation("Translation"))
	out:SetOffset(-sign * K.SLIDE, 0)
	out:SetDuration(0)
	out:SetOrder(1)
	local slide = Own(come:CreateAnimation("Translation"))
	slide:SetOffset(sign * K.SLIDE, 0)
	slide:SetDuration(K.SLIDE_SECONDS)
	slide:SetOrder(2)
	pcall(slide.SetSmoothing, slide, "OUT")
	local bob = Own(frame:CreateAnimationGroup())
	bob:SetLooping("BOUNCE")
	local push = Own(bob:CreateAnimation("Translation"))
	push:SetOffset(sign * K.BOB, 0)
	push:SetDuration(K.BOB_SECONDS)
	pcall(push.SetSmoothing, push, "IN_OUT")
	come:SetScript("OnFinished", function()
		if arrow.moving then
			pcall(bob.Play, bob)
		end
	end)
	arrow.come, arrow.bob = come, bob
end

local function Arrow(root, side)
	local frame = Own(CreateFrame("Frame", nil, root))
	Call(frame, "EnableMouse", false)
	local arrow = { frame = frame, side = side, pieces = {}, lows = {}, shades = {} }
	arrow.normal, arrow.low = Own(CreateFrame("Frame", nil, frame)), Own(CreateFrame("Frame", nil, frame))
	for _, layer in ipairs({ arrow.normal, arrow.low }) do
		Call(layer, "EnableMouse", false)
		layer:SetAllPoints(frame)
	end
	arrow.low:SetAlpha(0)
	for index = 1, K.COLUMNS + 2 do
		local shade = Unsnap(Own(frame:CreateTexture(nil, "BORDER")))
		shade:SetColorTexture(SHADE[1], SHADE[2], SHADE[3], SHADE[4])
		arrow.shades[index] = shade
		if index <= K.COLUMNS then
			arrow.pieces[index] = Unsnap(Own(arrow.normal:CreateTexture(nil, "ARTWORK")))
			arrow.lows[index] = Unsnap(Own(arrow.low:CreateTexture(nil, "ARTWORK")))
		end
	end
	pcall(Motion, arrow)
	return arrow
end

local function Shape(arrow, wide, tall)
	local frame = arrow.frame
	local px = ns.Pixels(frame, 1)
	local fw, fh = wide + 2 * px, tall + 2 * px
	if arrow.wide == wide and arrow.tall == tall and arrow.px == px then
		return fw, fh
	end
	arrow.wide, arrow.tall, arrow.px = wide, tall, px
	frame:SetSize(fw, fh)
	local count = K.COLUMNS
	local column = wide / count
	local point, sign = "LEFT", 1
	if arrow.side == 2 then
		point, sign = "RIGHT", -1
	end
	local high = tall
	for index = 1, count do
		high = math.max(px, tall * (count - index + 1) / count)
		local x = sign * (px + (index - 1) * column)
		local piece, shade = arrow.pieces[index], arrow.shades[index]
		for _, art in ipairs({ piece, arrow.lows[index] }) do
			art:ClearAllPoints()
			art:SetPoint(point, frame, point, x, 0)
			art:SetSize(column, high)
		end
		shade:ClearAllPoints()
		shade:SetPoint(point, frame, point, x, 0)
		shade:SetSize(column, high + 2 * px)
	end
	local base, tip = arrow.shades[count + 1], arrow.shades[count + 2]
	base:ClearAllPoints()
	base:SetPoint(point, frame, point, 0, 0)
	base:SetSize(px, tall + 2 * px)
	tip:ClearAllPoints()
	tip:SetPoint(point, frame, point, sign * (px + wide), 0)
	tip:SetSize(px, high + 2 * px)
	return fw, fh
end

local function Build(parent, outlineOf)
	local root = Own(CreateFrame("Frame", nil, parent))
	Call(root, "EnableMouse", false)
	local box = Own(CreateFrame("Frame", nil, root))
	Call(box, "EnableMouse", false)
	local mark = { root = root, box = box, rings = {}, at = {} }
	for index = 1, #GLOW do
		local ring = {}
		for side = 1, 4 do
			ring[side] = Unsnap(Own(box:CreateTexture(nil, "BACKGROUND")))
		end
		mark.rings[index] = ring
	end
	local outline = outlineOf and outlineOf(box) or ns.SetOutlineArea(ns.Outline(box, box), KEY)
	ns.KeepOutline(outline)
	ns.SetOutline(outline, true, false)
	if outline and outline.holder then
		Call(outline.holder, "EnableMouse", false)
	end
	mark.outline = outline
	mark.arrows = { Arrow(root, 1), Arrow(root, 2) }
	return mark
end

local function Line(line, box, a, b, ax, ay, bx, by, w, h)
	line:ClearAllPoints()
	line:SetPoint(a, box, a, ax, ay)
	line:SetPoint(b, box, b, bx, by)
	if w then
		line:SetWidth(w)
	else
		line:SetHeight(h)
	end
end

local function Rings(mark, from, unit)
	local box = mark.box
	for index, ring in ipairs(mark.rings) do
		local d = from + index * unit
		Line(ring[1], box, "TOPLEFT", "TOPRIGHT", -d, d, d, d, nil, unit)
		Line(ring[2], box, "BOTTOMLEFT", "BOTTOMRIGHT", -d, -d, d, -d, nil, unit)
		Line(ring[3], box, "TOPLEFT", "BOTTOMLEFT", -d, d - unit, -d, -d + unit, unit)
		Line(ring[4], box, "TOPRIGHT", "BOTTOMRIGHT", d, d - unit, d, -d + unit, unit)
	end
end

local function Colours(mark, r, g, b)
	local lr, lg, lb = ns.Colour(KEY .. ".lowHealthColour")
	if mark.lr ~= lr or mark.lg ~= lg or mark.lb ~= lb then
		mark.lr, mark.lg, mark.lb = lr, lg, lb
		for _, arrow in ipairs(mark.arrows) do
			for _, piece in ipairs(arrow.lows) do
				piece:SetColorTexture(lr, lg, lb, 1)
			end
		end
	end
	if mark.r == r and mark.g == g and mark.b == b then
		return
	end
	mark.r, mark.g, mark.b = r, g, b
	for index, ring in ipairs(mark.rings) do
		for _, line in ipairs(ring) do
			line:SetColorTexture(r, g, b, GLOW[index])
		end
	end
	for _, arrow in ipairs(mark.arrows) do
		for _, piece in ipairs(arrow.pieces) do
			piece:SetColorTexture(r, g, b, 1)
		end
	end
end

local function Look(mark, ring, colour)
	local r, g, b = ns.Colour(KEY .. "." .. (colour or "targetMarkColour"))
	ns.SetOutlineThickness(mark.outline, MarkPx())
	ns.SetOutlineColour(mark.outline, r, g, b)
	Colours(mark, r, g, b)
	local box = mark.box
	local from, unit = ns.Pixels(box, GlowFrom(ring)), ns.Pixels(box, Grain())
	if mark.from ~= from or mark.unit ~= unit then
		mark.from, mark.unit = from, unit
		Rings(mark, from, unit)
	end
	local glow = Glowing()
	if mark.glow ~= glow then
		mark.glow = glow
		for _, ring in ipairs(mark.rings) do
			for _, line in ipairs(ring) do
				line:SetShown(glow)
			end
		end
	end
	local arrows = Opt("targetArrows") == true
	if mark.arrowsOn ~= arrows then
		mark.arrowsOn = arrows
		for _, arrow in ipairs(mark.arrows) do
			arrow.frame:SetShown(arrows)
		end
	end
	mark.outer, mark.gap = ns.Pixels(box, Reach()), ns.Pixels(box, K.ROOM)
end

local function Layer(mark, strata, level)
	if mark.strata == strata and mark.level == level then
		return
	end
	mark.strata, mark.level = strata, level
	local outline = mark.outline
	local first, second = mark.arrows[1], mark.arrows[2]
	local list = { mark.root, mark.box, outline and outline.holder or false, first.frame, second.frame, first.normal, first.low, second.normal, second.low }
	local rise = { 0, 0, 1, 2, 2, 3, 3, 3, 3 }
	for index, region in ipairs(list) do
		if region then
			if strata then
				Call(region, "SetFrameStrata", strata)
			end
			Call(region, "SetFrameLevel", level + rise[index])
		end
	end
end

local function StrataOf(unitFrame)
	local best, rank = nil, 0
	for _, region in ipairs({ unitFrame, Level(unitFrame) or false }) do
		if region then
			local strata = Read(region, "GetFrameStrata")
			local at = type(strata) == "string" and STRATA[strata] or nil
			if at and at > rank then
				best, rank = strata, at
			end
		end
	end
	return best or "HIGH"
end

local function Screen(region)
	local ok, x, y = Call(region, "GetCenter")
	local okSize, w, h = Call(region, "GetSize")
	local scale = Read(region, "GetEffectiveScale")
	if ok and okSize and ns.Finite(x) and ns.Finite(y) and ns.Finite(w) and ns.Finite(h) and ns.Finite(scale) and scale > 0 then
		return x * scale, y * scale, w * scale, h * scale, scale
	end
	return nil
end

local function Span(region)
	if type(region) ~= "table" or ns.Forbidden(region) or Read(region, "IsVisible") ~= true then
		return nil
	end
	local alpha = Read(region, "GetEffectiveAlpha")
	if ns.Finite(alpha) and alpha < K.FAINT then
		return nil
	end
	local x, y, w, h = Screen(region)
	if x == nil or w <= 0 or h <= 0 then
		return nil
	end
	return x - w / 2, x + w / 2, y - h / 2, y + h / 2
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		return nil
	end
	return type(a) == "table" and a or nil, b, type(c) == "table" and c or nil
end

local function Beside(unitFrame, own)
	local list = { Level(unitFrame) or false, Usable(unitFrame.RaidTargetFrame) or false, Usable(unitFrame.ClassificationFrame) or false }
	if type(own) == "table" and own.classShown == true and type(own.icon) == "table" then
		list[#list + 1] = own.icon
	end
	if type(own) == "table" and own.markShown == true and type(own.mark) == "table" then
		list[#list + 1] = own.mark
	end
	list[#list + 1] = Ask(ns.PlateAuraRow, unitFrame, "left") or false
	list[#list + 1] = Ask(ns.PlateAuraRow, unitFrame, "right") or false
	local value, _, target = Ask(ns.PlateThreatTexts, unitFrame)
	local quest, _, count = Ask(ns.PlateQuestBeside, unitFrame)
	list[#list + 1] = value or false
	list[#list + 1] = target or false
	list[#list + 1] = quest or false
	list[#list + 1] = count or false
	return list
end

local function Scan(unitFrame, x, y, w, scale, band)
	local left, right = x - w / 2, x + w / 2
	local lo, hi, edge = left, right, right
	local own = owns[unitFrame]
	if type(own) == "table" and own.levelBox == true then
		local _, far = Span(Level(unitFrame))
		if far and far > edge then
			edge = far
		end
	end
	for _, region in ipairs(Beside(unitFrame, own)) do
		local l, r, b, t = Span(region)
		if l and t > y - band and b < y + band then
			lo, hi = math.min(lo, l), math.max(hi, r)
		end
	end
	return { l = (left - lo) / scale, r = (hi - right) / scale, edge = (edge - right) / scale }
end

local function Styled(unitFrame)
	local own = owns[unitFrame]
	if type(own) ~= "table" or own.styleOn ~= true then
		return false
	end
	local only = unitFrame.showOnlyName
	return ns.IsSecret(only) or only ~= true
end

local function Pin(item, frame, point, x, y)
	if item.x ~= nil and math.abs(item.x - x) < 0.01 and math.abs(item.y - y) < 0.01 then
		return
	end
	item.x, item.y = x, y
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
end

local function Aim(mark, ext, left, right, mid, tall, ratio)
	local first, second = mark.arrows[1], mark.arrows[2]
	local wide = tall * K.WIDE
	Shape(first, wide, tall)
	Shape(second, wide, tall)
	local reachLeft = math.max(ext.l * ratio, mark.outer)
	local reachRight = math.max(ext.r * ratio, ext.edge * ratio + mark.outer)
	Pin(first, first.frame, "RIGHT", left - reachLeft - mark.gap, mid)
	Pin(second, second.frame, "LEFT", right + reachRight + mark.gap, mid)
end

local function Curves()
	local at = Opt("lowHealthAt")
	at = ns.Finite(at) and math.max(0, math.min(100, at)) or K.LOW
	if CURVES.at ~= at then
		CURVES.at, CURVES.low, CURVES.high = at, nil, nil
		pcall(function()
			local low, high = C_CurveUtil.CreateCurve(), C_CurveUtil.CreateCurve()
			low:SetType(Enum.LuaCurveType.Step)
			low:AddPoint(0, 1)
			low:AddPoint(at / 100, 0)
			high:SetType(Enum.LuaCurveType.Step)
			high:AddPoint(0, 0)
			high:AddPoint(at / 100, 1)
			CURVES.low, CURVES.high = low, high
		end)
	end
	return CURVES.low, CURVES.high
end

local function Number(value)
	return ns.IsSecret(value) or type(value) == "number"
end

local function Tone(mark, low, high)
	for _, arrow in ipairs(mark.arrows) do
		pcall(arrow.low.SetAlpha, arrow.low, low)
		pcall(arrow.normal.SetAlpha, arrow.normal, high)
	end
end

local function Low(mark, unit)
	local low, high = 0, 1
	if mark.arrowsOn and Opt("targetArrowsLow") == true then
		local lowCurve, highCurve = Curves()
		if lowCurve and highCurve then
			local okLow, a = pcall(UnitHealthPercent, unit, true, lowCurve)
			local okHigh, b = pcall(UnitHealthPercent, unit, true, highCurve)
			if okLow and okHigh and Number(a) and Number(b) then
				low, high = a, b
			end
		end
	end
	Tone(mark, low, high)
end

local function Move(mark, fresh, still)
	local on = mark.arrowsOn == true and Opt("targetArrowsMove") == true and not still
	for _, arrow in ipairs(mark.arrows) do
		local come, bob = arrow.come, arrow.bob
		if come and bob then
			if not on then
				if arrow.moving then
					arrow.moving = false
					pcall(come.Stop, come)
					pcall(bob.Stop, bob)
				end
			elseif fresh then
				arrow.moving = true
				pcall(bob.Stop, bob)
				pcall(come.Stop, come)
				pcall(come.Play, come)
			elseif not arrow.moving then
				arrow.moving = true
				if not Playing(come) then
					pcall(bob.Play, bob)
				end
			end
		end
	end
end

local function Copied(unitFrame)
	if type(ns.PlateSlipCopy) ~= "function" then
		return nil
	end
	local ok, _, bar, beside = pcall(ns.PlateSlipCopy, unitFrame)
	if ok and type(bar) == "table" and type(beside) == "table" and ns.Finite(beside.l) and ns.Finite(beside.r) then
		return bar, beside
	end
	return nil
end

local function Follow(slot, elapsed)
	local unitFrame, mark = slot.frame, slot.mark
	local root = mark.root
	local copy, beside = Copied(unitFrame)
	local bar = copy or Bar(unitFrame)
	local x, y, w, h, scale = Screen(bar)
	local base = Read(UIParent, "GetEffectiveScale")
	if x == nil or w <= 0 or h <= 0 or not (ns.Finite(base) and base > 0) or Read(bar, "IsVisible") ~= true then
		root:Hide()
		return
	end
	local height = h / base
	local tall = Tall(height)
	slot.look = slot.look - (ns.Finite(elapsed) and elapsed or 0)
	if slot.ext == nil or slot.look <= 0 or slot.copied ~= (copy ~= nil) then
		slot.look = K.LOOK
		slot.copied = copy ~= nil
		slot.styled = Styled(unitFrame)
		if copy == nil then
			slot.ext = Scan(unitFrame, x, y, w, scale, tall * base / 2)
		end
		Layer(mark, StrataOf(unitFrame), K.MARK + slot.rise)
		Look(mark, RingOn(unitFrame), slot.colour)
		Low(mark, slot.unit)
		Move(mark, false)
	end
	if copy ~= nil then
		local ext = slot.copyExt or {}
		ext.l, ext.r, ext.edge = beside.l, beside.r, 0
		slot.copyExt, slot.ext = ext, ext
	end
	if not slot.styled then
		root:Hide()
		return
	end
	local ext, at, ratio = slot.ext, mark.at, scale / base
	local left, right = (x - w / 2) / base, (x + w / 2) / base
	local width = right - left + ext.edge * ratio
	Pin(at, mark.box, "BOTTOMLEFT", left, (y - h / 2) / base)
	if at.w == nil or math.abs(at.w - width) > 0.01 or math.abs(at.h - height) > 0.01 then
		at.w, at.h = width, height
		mark.box:SetSize(width, height)
	end
	if mark.arrowsOn then
		Aim(mark, ext, left, right, y / base, tall, ratio)
	end
	local alpha = Read(bar, "GetEffectiveAlpha")
	alpha = ns.Finite(alpha) and math.max(0, math.min(1, alpha)) or 1
	if at.a == nil or math.abs(at.a - alpha) > 0.01 then
		at.a = alpha
		root:SetAlpha(alpha)
	end
	root:Show()
end

local function Stop()
	if driver and S.running then
		driver:SetScript("OnUpdate", nil)
	end
	S.running = false
end

local function Hide(slot)
	local mark = slot.mark
	if mark then
		mark.root:Hide()
		Move(mark, false, true)
	end
	slot.frame, slot.ext = nil, nil
	for _, other in ipairs(SLOTS) do
		if other.frame ~= nil then
			return
		end
	end
	Stop()
end

local function HideAll()
	for _, slot in ipairs(SLOTS) do
		pcall(Hide, slot)
	end
end

local function Tick(_, elapsed)
	local any = false
	if S.on then
		for _, slot in ipairs(SLOTS) do
			local frame = slot.frame
			if frame ~= nil and slot.mark ~= nil then
				if ns.Forbidden(frame) or not ns.EachPart(KEY, PART, Follow, slot, elapsed) then
					pcall(Hide, slot)
				else
					any = true
				end
			end
		end
	end
	if not any then
		Stop()
	end
end

local function Run()
	if driver == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		driver = ok and type(frame) == "table" and Own(frame) or false
	end
	if driver and not S.running then
		S.running = true
		driver:SetScript("OnUpdate", Tick)
	end
end

local function Mark(slot)
	if slot.mark == nil then
		local mark = Build(UIParent)
		mark.root:SetSize(1, 1)
		mark.root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		mark.root:Hide()
		slot.mark = mark
	end
	return slot.mark
end

local function Want(slot)
	if not S.on or type(ns.PlateUnitFrame) ~= "function" then
		return nil
	end
	local frame = ns.PlateUnitFrame(slot.unit)
	if frame ~= nil and slot.unit == "focus" and (Opt("focusMark") ~= true or frame == ns.PlateUnitFrame("target")) then
		return nil
	end
	return frame
end

local function Update(slot)
	local frame = Want(slot)
	if frame == nil or ns.Forbidden(frame) or not Styled(frame) then
		Hide(slot)
		return
	end
	local mark = Mark(slot)
	local fresh = slot.frame ~= frame
	if fresh then
		slot.marked = slot.marked + 1
	end
	slot.frame, slot.ext, slot.look = frame, nil, 0
	Follow(slot, 0)
	if fresh then
		Move(mark, true)
	end
	Run()
end

local function UpdateAll()
	for _, slot in ipairs(SLOTS) do
		Update(slot)
	end
end

local function Sync()
	S.on = Wanted()
	if not S.on then
		HideAll()
		return
	end
	UpdateAll()
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	ns.EachPart(KEY, PART, UpdateAll)
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", function()
	ns.EachPart(KEY, PART, Update, SLOTS[2])
end)
ns.AddEvent(KEY, "RAID_TARGET_UPDATE", function()
	for _, slot in ipairs(SLOTS) do
		slot.look = 0
	end
end)

EXTRA.show[#EXTRA.show + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	if not S.on then
		return
	end
	for _, slot in ipairs(SLOTS) do
		if slot.frame == unitFrame or ns.PlateUnitFrame(slot.unit) == unitFrame then
			ns.EachPart(KEY, PART, Update, slot)
		end
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame, own)
	if type(own) == "table" then
		owns[unitFrame] = own
	end
	if not S.on then
		return
	end
	for _, slot in ipairs(SLOTS) do
		if slot.frame == unitFrame then
			slot.look = 0
		elseif slot.frame == nil and ns.PlateUnitFrame(slot.unit) == unitFrame then
			ns.EachPart(KEY, PART, Update, slot)
		end
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	for _, slot in ipairs(SLOTS) do
		if slot.frame == unitFrame then
			pcall(Hide, slot)
		end
	end
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		HideAll()
	end
end

EXTRA.status[#EXTRA.status + 1] = function()
	if Opt("targetMark") ~= true then
		return nil
	end
	local target, focus = SLOTS[1], SLOTS[2]
	local now = "off"
	if S.on then
		now = target.frame and "on, following your target's nameplate" or "on, no target nameplate in view"
	end
	local line = ("Target mark: %s, %d targets marked so far"):format(now, target.marked)
	if Opt("focusMark") == true then
		line = line .. (", %d focuses marked"):format(focus.marked)
	end
	return line .. ", in a fight too."
end

local function SampleSpan(p, o, m)
	local P = ns.SetupDrawPlates
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
	local quest = p.quest and p.quest:IsShown()
	if quest and ns.Finite(p.questL) then
		lo = math.min(lo, p.questL)
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
	if p.ttarget and p.ttarget:IsShown() and ns.Finite(p.ttargetR) then
		hi = math.max(hi, p.ttargetR)
	end
	if quest and ns.Finite(p.questR) then
		hi = math.max(hi, p.questR)
	end
	return lo, hi, right
end

local function SampleMark(p, slot, on, spec, o, m)
	local mark = p[slot.sample]
	if not on then
		if mark then
			mark.root:Hide()
			Move(mark, false, true)
		end
		return
	end
	local P = ns.SetupDrawPlates
	if mark == nil then
		local outlineOf = type(P) == "table" and type(P.Outline) == "function" and function(box)
			return P.Outline(p.S, box, box)
		end or nil
		mark = Build(p.f, outlineOf)
		mark.root:SetAllPoints(p.f)
		p[slot.sample] = mark
	end
	local copy = p.slipCopy
	local copied = type(copy) == "table" and copy.on == true and type(copy.beside) == "table" and ns.Finite(copy.goal) and ns.Finite(copy.level)
	local bar = copied and copy.bar or p.bar
	Layer(mark, nil, copied and copy.level + K.COPY or p.bar:GetFrameLevel() + K.SAMPLE)
	local box = mark.box
	box:ClearAllPoints()
	box:SetPoint("LEFT", bar, "LEFT", 0, 0)
	box:SetPoint("TOP", bar, "TOP", 0, 0)
	box:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	box:SetPoint("RIGHT", copied and bar or (o.levelSquare and p.lvl or p.bar), "RIGHT", 0, 0)
	Look(mark, Ringed() and p.ringShown == true, slot.colour)
	mark.root:SetAlpha(1)
	mark.root:Show()
	local share = spec.health or (type(P) == "table" and P.SHARE) or 1
	local at = Opt("lowHealthAt")
	local red = mark.arrowsOn and Opt("targetArrowsLow") == true and ns.Finite(share) and ns.Finite(at) and share * 100 < at
	Tone(mark, red and 1 or 0, red and 0 or 1)
	if not mark.arrowsOn or type(P) ~= "table" or type(P.Put) ~= "function" then
		Move(mark, false, true)
		return
	end
	Move(mark, false, type(P.Still) == "function" and P.Still(p) == true)
	local first, second = mark.arrows[1], mark.arrows[2]
	local lo, hi, left, right, tall
	if copied then
		local f, beside, half = copy.goal, copy.beside, m.HW / 2
		left, right = half - half * f, half + half * f
		lo, hi, tall = left - beside.l * f, right + beside.r * f, Tall(m.HH * f)
	else
		lo, hi, right = SampleSpan(p, o, m)
		left, tall = 0, Tall(m.HH)
	end
	local fw, fh = Shape(first, tall * K.WIDE, tall)
	Shape(second, tall * K.WIDE, tall)
	P.Put(p, first.frame, "RIGHT", math.min(lo, left - mark.outer) - mark.gap, m.center, fw, fh)
	P.Put(p, second.frame, "LEFT", math.max(hi, right + mark.outer) + mark.gap, m.center, fw, fh)
end

function ns.PlateMarkSample(p, spec, o, m)
	if type(p) ~= "table" or type(spec) ~= "table" or type(o) ~= "table" or type(m) ~= "table" or type(p.f) ~= "table" then
		return
	end
	local styled = o.styled == true and Opt("targetMark") == true
	SampleMark(p, SLOTS[1], styled and spec.target == true, spec, o, m)
	SampleMark(p, SLOTS[2], styled and spec.focus == true and spec.target ~= true and Opt("focusMark") == true, spec, o, m)
end

function ns.PlateMarkShown(p, focus)
	local mark = type(p) == "table" and p[focus and "focusMark" or "targetMark"] or nil
	if mark and mark.root:IsShown() then
		return mark.root
	end
	return nil
end
