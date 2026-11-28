local _, ns = ...

local KEY = "trackers"
local IsSecret = ns.IsSecret
local MOVER = "FlatUIProcArt"

local K = {
	LONG = 204.8, SHORT = 102.4,
	FADE_IN = 0.2, FADE_OUT = 0.1, PULSE_UP = 1.08, PULSE_DOWN = 0.9259, PULSE_TIME = 0.5,
	SOFT_FADE_IN = 0.4, SOFT_UP = 1.035, SOFT_DOWN = 1 / 1.035, SOFT_TIME = 1,
	SIZE = 150, ALPHA = 40,
	MAX = 3, POOL = 12,
	ARC = "Interface\\AddOns\\FlatUI\\Media\\ProcArc.tga",
	FALLBACK = { 1, 209 / 255, 0 },
	SIDES = {
		LeftRight = { "Left", "Right" }, TopBottom = { "Top", "Bottom" }, LeftRightOutside = { "LeftOutside", "RightOutside" },
	},
	NAMES = {
		Center = "Center", Left = "Left", Right = "Right", Top = "Top", Bottom = "Bottom", TopLeft = "Top left", TopRight = "Top right",
		LeftOutside = "Left outside", RightOutside = "Right outside", LeftRight = "Left and Right", TopBottom = "Top and Bottom",
		LeftRightOutside = "Left and Right outside",
	},
	BY_NUMBER = { [0] = "Center", "Left", "Right", "Top", "Bottom", "TopLeft", "TopRight", "LeftOutside", "RightOutside", "LeftRight", "TopBottom", "LeftRightOutside" },
	MAX_SCALE = 5, MAX_SECONDS = 120, MAX_MOST = 20,
	GHOST = 0.25, STEP = 0.6, LOOP = 3, TICK = 0.1, COUNT = 28, TIME = 26, TIME_LAST = 2, TIME_GROW = 1.15,
	FONT = "NumberFontNormal", FULL_LOW = 0.35,
	BURST_FROM = 1.35, BURST_TIME = 0.25, BURST_FADE = 0.1, BURST_BRIGHT = 2,
	BREATHE_UP = 1.03, BREATHE_LOW = 0.6, BREATHE_TIME = 1, FLICKER_LOW = 0.35, FLICKER_TIME = 0.12, FLICKER_AT = 2,
	MIST_DEEP = 180, MIST_ALPHA = 0.5, MIST_IN = 0.4, MIST_OUT = 0.25, MIST_BLEND = "BLEND",
}

local G = {
	Center = { w = K.LONG, h = K.LONG, point = "CENTER", rel = "CENTER", x = 0, dx = 0, dy = 1 },
	Left = { w = K.SHORT, h = K.LONG, point = "RIGHT", rel = "LEFT", x = 0, dx = -1, dy = 0 },
	LeftOutside = { w = K.SHORT, h = K.LONG, point = "RIGHT", rel = "LEFT", x = -K.SHORT, dx = -1, dy = 0 },
	Right = { w = K.SHORT, h = K.LONG, point = "LEFT", rel = "RIGHT", x = 0, dx = 1, dy = 0, flipH = true },
	RightOutside = { w = K.SHORT, h = K.LONG, point = "LEFT", rel = "RIGHT", x = K.SHORT, dx = 1, dy = 0, flipH = true },
	Top = { w = K.LONG, h = K.SHORT, point = "BOTTOM", rel = "TOP", x = 0, dx = 0, dy = 1 },
	Bottom = { w = K.LONG, h = K.SHORT, point = "TOP", rel = "BOTTOM", x = 0, dx = 0, dy = -1, flipV = true },
	TopRight = { w = K.SHORT, h = K.SHORT, point = "BOTTOMLEFT", rel = "TOPRIGHT", x = 0, dx = 1, dy = 0 },
	TopLeft = { w = K.SHORT, h = K.SHORT, point = "BOTTOMRIGHT", rel = "TOPLEFT", x = 0, dx = -1, dy = 0 },
}

local holder, PlaceHolder, mist
local pool, ups, fading, last = {}, {}, {}, {}
local T = { clock = 0, ticking = false }
local GAME = { recs = {} }

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Setting(name, default)
	local value = ns.Get(KEY .. "." .. name)
	if Plain(value, "number") then
		return value
	end
	return default
end

local function On()
	return ns.Get(KEY .. ".art") == true
end

local function Look()
	return ns.Get(KEY .. ".glowStyle") == "game" and "game" or "soft"
end

local function StacksOn()
	return ns.Get(KEY .. ".artStacks") ~= false
end

local function TimeOn()
	return ns.Get(KEY .. ".artTime") ~= false
end

local function Opacity()
	return Setting("artAlpha", K.ALPHA) / 100
end

local function TextAlpha()
	return math.min(1, 2 * Opacity())
end

local function Now()
	local ok, now = pcall(GetTime)
	return ok and Plain(now, "number") and now or 0
end

local function Big(text, size)
	local ok, file = pcall(text.GetFont, text)
	if not (ok and Plain(file, "string")) then
		file = STANDARD_TEXT_FONT
	end
	pcall(text.SetFont, text, file, math.max(8, math.floor(size + 0.5)), "OUTLINE")
end

function ns.ProcArtOn()
	return On()
end

function ns.ProcArtShown()
	return ns.Enabled(KEY) and On()
end

function ns.ProcArtMoved()
	if holder then
		PlaceHolder()
	end
end

local function Locations(location)
	return K.SIDES[location] or { location }
end

local function OwnLook(look)
	if type(look) ~= "table" then
		return nil
	end
	local made = { add = look.add == true, burst = look.burst == true, breathe = look.breathe == true, mist = look.mist == true }
	local tint = look.tint
	if type(tint) == "table" then
		local colour = {}
		for i = 1, 3 do
			local value = tint[i]
			colour[i] = Plain(value, "number") and math.max(0, math.min(1, value)) or nil
		end
		made.tint = (colour[1] and colour[2] and colour[3]) and colour or nil
	end
	if not (made.add or made.burst or made.breathe or made.mist or made.tint) then
		return nil
	end
	return made
end

local function Normalise(data)
	data = type(data) == "table" and data or {}
	local file, location, scale = data.file, data.location, data.scale
	local alpha, turn, seconds = data.alpha, data.turn, data.seconds
	alpha = Plain(alpha, "number") and math.max(0, math.min(1, alpha)) or 1
	turn = (turn == 1 or turn == -1) and turn or nil
	seconds = Plain(seconds, "number") and seconds > 0 and math.min(seconds, K.MAX_SECONDS) or nil
	if Plain(location, "number") then
		location = K.BY_NUMBER[location]
	end
	if not (Plain(location, "string") and (G[location] or K.SIDES[location])) then
		location = "LeftRight"
	end
	local arc = not ((Plain(file, "number") and file > 0) or (Plain(file, "string") and file ~= ""))
	if arc then
		file, location = K.ARC, "LeftRight"
	end
	if not (Plain(scale, "number") and scale > 0) then
		scale = 1
	end
	scale = math.min(scale, K.MAX_SCALE)
	local colour = {}
	for i, name in ipairs({ "r", "g", "b" }) do
		local value = data[name]
		colour[i] = Plain(value, "number") and math.max(0, math.min(1, value)) or nil
	end
	if not (colour[1] and colour[2] and colour[3]) then
		colour = nil
	end
	if arc then
		alpha, turn = 1, nil
	end
	local most = data.most
	most = Plain(most, "number") and most >= 2 and math.min(math.floor(most), K.MAX_MOST) or nil
	return { file = file, location = location, scale = scale, colour = colour, arc = arc, alpha = alpha, turn = turn, pulse = data.pulse ~= false,
		seconds = seconds, most = most, look = OwnLook(data.look) }
end

local function ProcRgb(entry)
	if type(ns.ProcColour) == "function" then
		local ok, r, g, b = pcall(ns.ProcColour, entry)
		if ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number") then
			return r, g, b
		end
	end
	return nil
end

local function PageColour()
	local path = KEY .. ".procColour"
	local def = ns.Def(path)
	return ns.IsSet(path) and not (type(def) == "table" and ns.Get(path) == def.default)
end

local function Tint(art)
	local tint = not art.colour and art.look and art.look.tint
	return tint or nil
end

local function ColourOf(entry, art)
	local own = type(entry) == "table" and entry.colour
	if (Plain(own, "string") or art.arc) and ProcRgb(entry) then
		return ProcRgb(entry)
	end
	if art.colour then
		return art.colour[1], art.colour[2], art.colour[3]
	end
	local tint = Tint(art)
	if tint then
		if PageColour() and ProcRgb(entry) then
			return ProcRgb(entry)
		end
		return tint[1], tint[2], tint[3]
	end
	if art.arc then
		return K.FALLBACK[1], K.FALLBACK[2], K.FALLBACK[3]
	end
	return 1, 1, 1
end

local function TextColour(entry, art)
	local own = type(entry) == "table" and entry.colour
	if not Plain(own, "string") and not art.arc and art.colour then
		return art.colour[1], art.colour[2], art.colour[3]
	end
	if not Plain(own, "string") and not art.arc and Tint(art) then
		return ColourOf(entry, art)
	end
	local r, g, b = ProcRgb(entry)
	if r then
		return r, g, b
	end
	return K.FALLBACK[1], K.FALLBACK[2], K.FALLBACK[3]
end

local function Corners(texture, g, turn)
	local left, right = g.flipH and 1 or 0, g.flipH and 0 or 1
	local top, bottom = g.flipV and 1 or 0, g.flipV and 0 or 1
	if turn == 1 then
		texture:SetTexCoord(left, bottom, right, bottom, left, top, right, top)
	elseif turn == -1 then
		texture:SetTexCoord(right, top, left, top, right, bottom, left, bottom)
	else
		texture:SetTexCoord(left, right, top, bottom)
	end
end

local function Release(piece)
	piece.live = false
	piece.byGame = false
	piece.fill:Hide()
	piece.count:Hide()
	piece.time:Hide()
	for _, group in ipairs(piece.groups) do
		group:Stop()
	end
	piece.animOut:Stop()
	piece:Hide()
	fading[piece] = nil
	pool[#pool + 1] = piece
end

local function Pulse(piece, up, down, seconds)
	local group = piece:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	for order, scale in ipairs({ up, down }) do
		local step = group:CreateAnimation("Scale")
		step:SetScaleFrom(1, 1)
		step:SetScaleTo(scale, scale)
		step:SetDuration(seconds)
		step:SetSmoothing("IN_OUT")
		step:SetOrder(order)
	end
	return group
end

local function FadeIn(piece, seconds)
	local group = piece:CreateAnimationGroup()
	local fadeIn = group:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(seconds)
	group:SetScript("OnPlay", function()
		piece:SetAlpha(0)
	end)
	group:SetScript("OnFinished", function()
		piece:SetAlpha(1)
		if piece.live and piece.pulses then
			piece.pulse:Play()
		end
	end)
	return group
end

local function Burst(piece)
	local group = piece:CreateAnimationGroup()
	local grow = group:CreateAnimation("Scale")
	grow:SetScaleFrom(K.BURST_FROM, K.BURST_FROM)
	grow:SetScaleTo(1, 1)
	grow:SetDuration(K.BURST_TIME)
	grow:SetSmoothing("OUT")
	local show = group:CreateAnimation("Alpha")
	show:SetFromAlpha(0)
	show:SetToAlpha(1)
	show:SetDuration(K.BURST_FADE)
	group:SetScript("OnPlay", function()
		piece.spent = 0
		piece:SetAlpha(0)
	end)
	group:SetScript("OnUpdate", function(_, elapsed)
		piece.spent = (piece.spent or 0) + (Plain(elapsed, "number") and elapsed or 0)
		local left = math.max(0, 1 - piece.spent / K.BURST_TIME)
		piece.tex:SetAlpha(math.min(1, (piece.base or 0) * (1 + (K.BURST_BRIGHT - 1) * left)))
	end)
	group:SetScript("OnStop", function()
		piece.tex:SetAlpha(piece.base or 0)
	end)
	group:SetScript("OnFinished", function()
		piece:SetAlpha(1)
		piece.tex:SetAlpha(piece.base or 0)
		if piece.live and piece.pulses then
			piece.pulse:Play()
		end
	end)
	return group
end

local function Breathe(piece)
	local group = piece:CreateAnimationGroup()
	group:SetLooping("REPEAT")
	for order, step in ipairs({ { 1 / K.BREATHE_UP, 1, K.BREATHE_LOW }, { K.BREATHE_UP, K.BREATHE_LOW, 1 } }) do
		local scale = group:CreateAnimation("Scale")
		scale:SetScaleFrom(1, 1)
		scale:SetScaleTo(step[1], step[1])
		scale:SetDuration(K.BREATHE_TIME)
		scale:SetSmoothing("IN_OUT")
		scale:SetOrder(order)
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(step[2])
		fade:SetToAlpha(step[3])
		fade:SetDuration(K.BREATHE_TIME)
		fade:SetSmoothing("IN_OUT")
		fade:SetOrder(order)
	end
	return group
end

local function Flicker(piece)
	local group = piece:CreateAnimationGroup()
	group:SetLooping("BOUNCE")
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(K.FLICKER_LOW)
	fade:SetDuration(K.FLICKER_TIME)
	fade:SetSmoothing("IN_OUT")
	return group
end

local function LookKey(look, own, flicker)
	own = own or {}
	return look .. (own.burst and "+burst" or "") .. (own.breathe and (flicker and "+flicker" or "+breathe") or "")
end

local function UseLook(piece, look, own, flicker)
	own = own or {}
	piece.look = LookKey(look, own, flicker)
	local set = piece.looks[look]
	local animIn = own.burst and piece.own.burst or set.fadeIn
	local pulse = set.pulse
	if own.breathe then
		pulse = flicker and piece.own.flicker or piece.own.breathe
	end
	for _, group in ipairs(piece.groups) do
		if group ~= animIn and group ~= pulse then
			group:Stop()
		end
	end
	piece.animIn, piece.pulse = animIn, pulse
end

local function MakePiece()
	local piece = CreateFrame("Frame", nil, holder)
	ns.Own[piece] = true
	piece:Hide()
	piece.tex = piece:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[piece.tex] = true
	piece.tex:SetAllPoints(piece)
	piece.fill = piece:CreateTexture(nil, "ARTWORK", nil, 1)
	ns.Own[piece.fill] = true
	piece.fill:Hide()
	for _, name in ipairs({ "count", "time" }) do
		local text = ns.OwnText(piece, "OVERLAY", K.FONT)
		if not text then
			error("no text for the art", 0)
		end
		text:SetWordWrap(false)
		text:SetJustifyH("CENTER")
		text:Hide()
		piece[name] = text
	end
	piece.looks = {}
	for look, steps in pairs({ game = { K.FADE_IN, K.PULSE_UP, K.PULSE_DOWN, K.PULSE_TIME },
		soft = { K.SOFT_FADE_IN, K.SOFT_UP, K.SOFT_DOWN, K.SOFT_TIME } }) do
		local pulse = Pulse(piece, steps[2], steps[3], steps[4])
		piece.looks[look] = { pulse = pulse, fadeIn = FadeIn(piece, steps[1]) }
	end
	piece.own = { burst = Burst(piece), breathe = Breathe(piece), flicker = Flicker(piece) }
	piece.groups = {}
	for _, set in pairs(piece.looks) do
		piece.groups[#piece.groups + 1] = set.fadeIn
		piece.groups[#piece.groups + 1] = set.pulse
	end
	for _, name in ipairs({ "burst", "breathe", "flicker" }) do
		piece.groups[#piece.groups + 1] = piece.own[name]
	end
	piece.animOut = piece:CreateAnimationGroup()
	local fadeOut = piece.animOut:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(K.FADE_OUT)
	piece.animOut:SetScript("OnFinished", function()
		Release(piece)
	end)
	UseLook(piece, Look())
	return piece
end

local function Acquire()
	local piece = table.remove(pool)
	if not piece then
		local ok, made = pcall(MakePiece)
		if not ok then
			return nil
		end
		piece = made
	end
	return piece
end

local function Spot(name, art, slot)
	local g = G[name]
	local size = Setting("artSize", K.SIZE) / 100 * art.scale
	local w, h = g.w * size, g.h * size
	local x, y = g.x, 0
	if slot == 2 then
		x, y = x + g.dx * w, y + g.dy * h
	elseif slot == 3 then
		if g.dy ~= 0 then
			y = y + g.dy * h * 2
		else
			y = y + h
		end
	end
	return g, w, h, x, y
end

local function Place(piece, name, art, slot)
	local g, w, h, x, y = Spot(name, art, slot)
	piece:ClearAllPoints()
	piece:SetPoint(g.point, holder, g.rel, x, y)
	piece:SetSize(w, h)
	piece.g, piece.w, piece.h = g, w, h
	Corners(piece.tex, g, art.turn)
	piece.tex:SetAlpha(art.alpha * Opacity())
end

local function Crop(piece, f)
	local g, fill, w, h = piece.g, piece.fill, piece.w, piece.h
	local left, right = g.flipH and 1 or 0, g.flipH and 0 or 1
	local top, bottom = g.flipV and 1 or 0, g.flipV and 0 or 1
	fill:ClearAllPoints()
	if g.dx == 0 and g.dy < 0 then
		fill:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, 0)
		fill:SetPoint("TOPRIGHT", piece, "TOPRIGHT", 0, 0)
		fill:SetHeight(math.max(0.5, h * f))
		fill:SetTexCoord(left, right, top, top + (bottom - top) * f)
	elseif g.dx == 0 then
		fill:SetPoint("BOTTOMLEFT", piece, "BOTTOMLEFT", 0, 0)
		fill:SetPoint("BOTTOMRIGHT", piece, "BOTTOMRIGHT", 0, 0)
		fill:SetHeight(math.max(0.5, h * f))
		fill:SetTexCoord(left, right, bottom - (bottom - top) * f, bottom)
	elseif g.dx < 0 then
		fill:SetPoint("TOPRIGHT", piece, "TOPRIGHT", 0, 0)
		fill:SetPoint("BOTTOMRIGHT", piece, "BOTTOMRIGHT", 0, 0)
		fill:SetWidth(math.max(0.5, w * f))
		fill:SetTexCoord(right - (right - left) * f, right, top, bottom)
	else
		fill:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, 0)
		fill:SetPoint("BOTTOMLEFT", piece, "BOTTOMLEFT", 0, 0)
		fill:SetWidth(math.max(0.5, w * f))
		fill:SetTexCoord(left, left + (right - left) * f, top, bottom)
	end
end

local function Most(rec)
	return StacksOn() and rec.art.most or nil
end

local function Building(rec)
	local most = Most(rec)
	return most ~= nil and rec.stacks ~= nil and rec.stacks < most
end

local function Scale()
	return Setting("artSize", K.SIZE) / K.SIZE
end

local function Dress(rec, piece, first)
	local art, most = rec.art, Most(rec)
	local base = art.alpha * Opacity()
	local n = most and (rec.stacks or most) or nil
	local building = n ~= nil and n < most
	if building and not art.turn then
		piece.base = base * K.GHOST
		piece.tex:SetAlpha(base * K.GHOST)
		piece.fill:SetTexture(art.file)
		local r, g, b = ColourOf(rec.entry, art)
		piece.fill:SetVertexColor(r, g, b)
		piece.fill:SetAlpha(base)
		Crop(piece, n / most)
		piece.fill:Show()
	else
		piece.fill:Hide()
		piece.base = building and base * (K.GHOST + (1 - K.GHOST) * n / most) or base
		piece.tex:SetAlpha(piece.base)
	end
	local count, time = piece.count, piece.time
	if first and n then
		Big(count, K.COUNT * Scale())
		count:ClearAllPoints()
		count:SetPoint("CENTER", piece, "CENTER", 0, 0)
		if building then
			count:SetTextColor(TextColour(rec.entry, art))
		else
			count:SetTextColor(1, 1, 1)
		end
		count:SetText(("%d"):format(n))
		count:SetAlpha(TextAlpha())
		count:Show()
	else
		count:Hide()
	end
	time:ClearAllPoints()
	if first and n then
		time:SetPoint("TOP", count, "BOTTOM", 0, -2)
	else
		time:SetPoint("CENTER", piece, "CENTER", 0, 0)
	end
	time:SetAlpha(TextAlpha())
	if not first then
		time:Hide()
	end
	rec.timeLeft = nil
end

local function MakeMist()
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata("BACKGROUND")
	local made = { frame = frame, sides = {} }
	for index, point in ipairs({ "LEFT", "RIGHT" }) do
		local side = frame:CreateTexture(nil, "BACKGROUND")
		ns.Own[side] = true
		side:SetPoint("TOP" .. point, frame, "TOP" .. point, 0, 0)
		side:SetPoint("BOTTOM" .. point, frame, "BOTTOM" .. point, 0, 0)
		made.sides[index] = side
	end
	for _, step in ipairs({ { "fadeIn", 0, 1, K.MIST_IN }, { "fadeOut", 1, 0, K.MIST_OUT } }) do
		local group = frame:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(step[2])
		fade:SetToAlpha(step[3])
		fade:SetDuration(step[4])
		made[step[1]] = group
	end
	made.fadeIn:SetScript("OnPlay", function()
		frame:SetAlpha(0)
	end)
	made.fadeIn:SetScript("OnFinished", function()
		frame:SetAlpha(1)
	end)
	made.fadeOut:SetScript("OnFinished", function()
		if made.rec == nil then
			frame:Hide()
		end
	end)
	return made
end

local function PaintMist(r, g, b, art)
	local deep = K.MIST_DEEP * Setting("artSize", K.SIZE) / K.SIZE * art.scale
	local alpha = K.MIST_ALPHA * Opacity() * art.alpha
	local key = table.concat({ r, g, b, deep, alpha }, "|")
	if mist.key == key then
		return true
	end
	local ok = pcall(function()
		local solid, clear = CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0)
		for index, side in ipairs(mist.sides) do
			side:SetWidth(deep)
			side:SetColorTexture(1, 1, 1, 1)
			side:SetBlendMode(K.MIST_BLEND)
			if index == 1 then
				side:SetGradient("HORIZONTAL", solid, clear)
			else
				side:SetGradient("HORIZONTAL", clear, solid)
			end
		end
	end)
	mist.key = ok and key or nil
	return ok
end

local function MistOut(now)
	if not mist then
		return
	end
	mist.rec = nil
	mist.fadeIn:Stop()
	if now or not mist.frame:IsShown() then
		mist.fadeOut:Stop()
		mist.frame:Hide()
	elseif not mist.fadeOut:IsPlaying() then
		mist.fadeOut:Play()
	end
end

local function Mist(rec, r, g, b, wanted)
	if not mist then
		return
	end
	if not (wanted and PaintMist(r, g, b, rec.art)) then
		if mist.rec == rec then
			MistOut()
		end
		return
	end
	if mist.rec ~= rec then
		mist.rec = rec
		mist.fadeOut:Stop()
		mist.frame:Show()
		mist.fadeIn:Play()
	end
end

local function GameIcon(entry)
	local slots = ns.TrackerSlots
	local call = type(slots) == "table" and slots.InUse
	return type(call) == "function" and call(entry) == true
end

local Wake

local function Layout(rec, again)
	local r, g, b = ColourOf(rec.entry, rec.art)
	local game = GameIcon(rec.entry)
	rec.drew = true
	local wanted = Locations(rec.art.location)
	local building = Building(rec)
	local own = rec.art.look
	local moves = not building and own or nil
	local blend = own and own.add and "ADD" or "BLEND"
	for name, piece in pairs(rec.pieces) do
		if name ~= wanted[1] and name ~= wanted[2] then
			rec.pieces[name] = nil
			Release(piece)
		end
	end
	for _, name in ipairs(wanted) do
		local piece = rec.pieces[name]
		if not piece then
			piece = Acquire()
			if not piece then
				rec.drew = false
			else
				rec.pieces[name] = piece
				piece.live = true
				piece.animIn:Stop()
				piece.animOut:Stop()
				piece.pulse:Stop()
				piece:SetAlpha(1)
				fading[piece] = nil
				piece.fresh = true
			end
		end
		if piece then
			Place(piece, name, rec.art, rec.slot)
			local ok = pcall(piece.tex.SetTexture, piece.tex, rec.art.file)
			rec.drew = rec.drew and ok
			piece.tex:SetVertexColor(r, g, b)
			pcall(piece.tex.SetBlendMode, piece.tex, blend)
			pcall(piece.fill.SetBlendMode, piece.fill, blend)
			piece.pulses = rec.art.pulse and not building
			Dress(rec, piece, name == wanted[1])
			local look = Look()
			if piece.look ~= LookKey(look, moves, rec.flicker) then
				local moving = piece.animIn:IsPlaying() or piece.pulse:IsPlaying()
				UseLook(piece, look, moves, rec.flicker)
				if moving and not piece.fresh and not piece.animIn:IsPlaying() then
					piece:SetAlpha(1)
					if piece.pulses then
						piece.pulse:Play()
					end
				end
			end
			if not piece.pulses and piece.pulse:IsPlaying() then
				piece.pulse:Stop()
			elseif piece.pulses and not piece.fresh and piece:IsShown() and not piece.animIn:IsPlaying() and not piece.pulse:IsPlaying() then
				piece.pulse:Play()
			end
			if piece.fresh then
				piece.fresh = false
				piece:Show()
				if again then
					piece:SetAlpha(1)
					if piece.pulses then
						piece.pulse:Play()
					end
				else
					piece.animIn:Play()
				end
			end
			if game and not piece.byGame then
				piece.byGame = true
				piece:Hide()
			elseif not game and piece.byGame then
				piece.byGame = false
				piece:Show()
			end
		end
	end
	rec.first = rec.pieces[wanted[1]]
	Mist(rec, r, g, b, moves ~= nil and moves.mist and next(rec.pieces) ~= nil)
	Wake()
end

local function SampleCount(rec)
	local most = rec.art.most
	if not (most and StacksOn() and Plain(rec.sample, "number")) then
		return nil
	end
	local step = math.floor(math.max(0, Now() - rec.sample) / K.STEP)
	if rec.loops then
		step = step % (most + K.LOOP)
	end
	return math.min(most, step + 1)
end

local function Sample(rec)
	local n = SampleCount(rec)
	if not n then
		return false
	end
	if rec.stacks ~= n then
		rec.stacks = n
		Layout(rec)
	end
	return rec.loops == true or n < rec.art.most
end

local function Clock(rec)
	local text = rec.first and rec.first.time
	if not text then
		return false
	end
	local left
	if TimeOn() and not Building(rec) and type(ns.ProcEnds) == "function" then
		local ok, ends = pcall(ns.ProcEnds, rec.entry)
		if ok and Plain(ends, "number") then
			left = ends - Now()
		end
	end
	if not (left and left > 0) then
		rec.timeLeft = nil
		text:Hide()
		return false
	end
	local n = math.ceil(left)
	if rec.timeLeft ~= n then
		rec.timeLeft = n
		local final = n <= K.TIME_LAST
		Big(text, K.TIME * Scale() * (final and K.TIME_GROW or 1))
		if final then
			text:SetTextColor(1, 1, 1)
		else
			text:SetTextColor(TextColour(rec.entry, rec.art))
		end
		text:SetText(("%d"):format(n))
		text:Show()
	end
	return true
end

local function Flickers(rec)
	local own = rec.art.look
	if not (own and own.breathe) or Building(rec) then
		return false
	end
	local left
	if type(ns.ProcEnds) == "function" then
		local ok, ends = pcall(ns.ProcEnds, rec.entry)
		if ok and Plain(ends, "number") then
			left = ends - Now()
		end
	end
	local up = left ~= nil and left > 0
	local want = up and left <= K.FLICKER_AT
	if want ~= (rec.flicker == true) then
		rec.flicker = want
		Layout(rec)
	end
	return up
end

local function Step()
	local busy = false
	for _, rec in ipairs(ups) do
		local sampled = Sample(rec)
		local timed = Clock(rec)
		local flicker = Flickers(rec)
		busy = busy or sampled or timed or flicker
	end
	return busy
end

local function Tick(_, elapsed)
	T.clock = T.clock - (Plain(elapsed, "number") and elapsed or 0)
	if T.clock > 0 then
		return
	end
	T.clock = K.TICK
	local ok, busy = pcall(Step)
	if not ok or not busy then
		T.ticking = false
		holder:SetScript("OnUpdate", nil)
	end
	if not ok then
		geterrorhandler()(busy)
	end
end

Wake = function()
	if holder and not T.ticking then
		T.ticking, T.clock = true, 0
		holder:SetScript("OnUpdate", Tick)
	end
end

function PlaceHolder()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "CENTER")
	end
	holder:ClearAllPoints()
	if ns.Finite(x) and ns.Finite(y) then
		holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + Setting("artY", 0))
	else
		holder:SetPoint("CENTER", UIParent, "CENTER", 0, Setting("artY", 0))
	end
	holder:SetAlpha(1)
end

local function Build()
	if holder then
		return true
	end
	if InCombatLockdown() then
		return false
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok then
		return false
	end
	holder = frame
	ns.Own[holder] = true
	holder:SetSize(K.LONG, K.LONG)
	PlaceHolder()
	holder:Show()
	for _ = 1, K.POOL do
		local made, piece = pcall(MakePiece)
		if made then
			pool[#pool + 1] = piece
		end
	end
	local made, own = pcall(MakeMist)
	mist = made and own or nil
	return true
end

local function SlotFor(rec)
	local taken = {}
	for _, other in ipairs(ups) do
		if other ~= rec then
			for _, name in ipairs(Locations(other.art.location)) do
				for _, mine in ipairs(Locations(rec.art.location)) do
					if name == mine then
						taken[other.slot] = true
					end
				end
			end
		end
	end
	for slot = 1, K.MAX do
		if not taken[slot] then
			return slot
		end
	end
	return K.MAX
end

local function Flush()
	if not Build() then
		return
	end
	for _, rec in ipairs(ups) do
		Layout(rec)
	end
end

local function Find(entry)
	for index, rec in ipairs(ups) do
		if rec.entry == entry or (rec.id ~= nil and rec.id == (type(entry) == "table" and entry.id)) then
			return rec, index
		end
	end
end

function ns.ProcArtShow(entry, data, again)
	if type(entry) ~= "table" or not On() then
		return false
	end
	local art = Normalise(data)
	local rec = Find(entry)
	if rec then
		rec.art = art
		rec.slot = SlotFor(rec)
	else
		if #ups >= K.MAX then
			return false
		end
		rec = { entry = entry, id = entry.id, art = art, pieces = {} }
		ups[#ups + 1] = rec
		rec.slot = SlotFor(rec)
	end
	rec.up, rec.keep = true, nil
	local since, loops
	if type(ns.ProcSampleSince) == "function" then
		since, loops = ns.ProcSampleSince(entry)
	end
	rec.sample, rec.loops = since, loops == true
	if Plain(since, "number") then
		rec.stacks = SampleCount(rec)
	elseif art.most and rec.stacks and rec.stacks < art.most then
		rec.stacks = nil
	end
	last[rec.id or entry] = { file = art.file, location = art.location, arc = art.arc }
	if holder then
		Layout(rec, again == true)
		last[rec.id or entry].drew = rec.drew
	else
		ns.OutOfCombat(function()
			Flush()
			local seen = last[rec.id or entry]
			if seen then
				seen.drew = rec.drew
			end
		end)
	end
	rec.token = (rec.token or 0) + 1
	if art.seconds and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		local token = rec.token
		C_Timer.After(art.seconds, function()
			local found = Find(entry)
			if found == rec and rec.token == token then
				ns.ProcArtHide(entry)
			end
		end)
	end
	return true
end

function ns.ProcArtHide(entry, now)
	local rec, index = Find(entry)
	if not rec then
		return false
	end
	if not now and rec.up and rec.keep and On() and StacksOn() then
		rec.up, rec.stacks, rec.keep, rec.sample = nil, rec.keep, nil, nil
		if holder then
			Layout(rec)
		end
		return true
	end
	table.remove(ups, index)
	if mist and mist.rec == rec then
		MistOut(now)
	end
	for _, piece in pairs(rec.pieces) do
		piece.live = false
		if now or piece.byGame or not piece:IsShown() then
			Release(piece)
		else
			piece.animIn:Stop()
			piece.pulse:Pause()
			fading[piece] = true
			piece.animOut:Play()
		end
	end
	rec.pieces = {}
	return true
end

function ns.ProcArtCounts()
	return #pool, (function()
		local n = 0
		for _ in pairs(fading) do
			n = n + 1
		end
		return n
	end)()
end

function ns.ProcArtReset()
	while #ups > 0 do
		ns.ProcArtHide(ups[1].entry, true)
	end
	for piece in pairs(fading) do
		Release(piece)
	end
	MistOut(true)
	for _, rec in pairs(GAME.recs) do
		if rec then
			pcall(rec.container.SetAlpha, rec.container, 0)
		end
	end
end

function ns.ProcArtChanged()
	if type(ns.ChargesRecheck) == "function" then
		ns.ChargesRecheck()
	end
	if type(ns.TrackerDirty) == "function" then
		ns.TrackerDirty()
	end
	if holder then
		if not On() then
			ns.ProcArtReset()
		else
			PlaceHolder()
			for index = #ups, 1, -1 do
				local rec = ups[index]
				if not rec.up and not StacksOn() then
					ns.ProcArtHide(rec.entry)
				end
			end
			for _, rec in ipairs(ups) do
				Layout(rec)
			end
		end
	end
	if type(GAME.PaintAll) == "function" then
		GAME.PaintAll()
	end
	local slots = ns.TrackerSlots
	if type(slots) == "table" and type(slots.Flush) == "function" then
		slots.Flush()
	end
	if type(ns.ProcPreview) == "function" then
		ns.ProcPreview()
	end
end

local REL = {
	CENTER = { 0, 0 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 }, TOP = { 0, 1 }, BOTTOM = { 0, -1 },
	TOPLEFT = { -1, 1 }, TOPRIGHT = { 1, 1 },
}

local function Lowest(art, placed)
	local taken = {}
	for _, other in ipairs(placed) do
		for _, name in ipairs(Locations(other.art.location)) do
			for _, mine in ipairs(Locations(art.location)) do
				if mine == name then
					taken[other.slot] = other.slot
				end
			end
		end
	end
	for slot = 1, K.MAX do
		if not taken[slot] then
			return slot
		end
	end
	return K.MAX
end

local function FixedSlot(entry, art)
	local list = type(ns.ProcEntries) == "function" and ns.ProcEntries() or {}
	local placed = {}
	for _, other in ipairs(type(list) == "table" and list or {}) do
		if type(other) == "table" then
			if other == entry or (other.id ~= nil and other.id == entry.id) then
				break
			elseif other.kind == "proc" then
				local give = type(ns.ProcArtData) == "function" and ns.ProcArtData
				local ok, data = false, nil
				if give then
					ok, data = pcall(give, other)
				end
				if not (ok and data == false) then
					local theirs = Normalise(ok and data or nil)
					placed[#placed + 1] = { art = theirs, slot = Lowest(theirs, placed) }
				end
			end
		end
	end
	return Lowest(art, placed)
end

local function Ratio(button)
	local ok, mine = pcall(button.GetEffectiveScale, button)
	local fine, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and fine and Plain(mine, "number") and Plain(base, "number") and mine > 0 and base > 0 then
		return mine / base
	end
	return 1
end

local function Taken(entry, art)
	return art.most ~= nil and GAME.Ready(entry)
end

local function Key(entry, art, slot)
	local r, g, b = ColourOf(entry, art)
	return table.concat({ On() and "on" or "off", Setting("artSize", K.SIZE), Setting("artAlpha", K.ALPHA), Setting("artY", 0), r, g, b, slot,
		tostring(art.file), art.location, Taken(entry, art) and "taken" or "own" }, "|")
end

function GAME.Formatter(r, g, b, most)
	local call = type(C_StringUtil) == "table" and C_StringUtil.CreateNumericRuleFormatter or nil
	local ok, formatter = pcall(call)
	if not ok or formatter == nil or IsSecret(formatter) then
		return nil
	end
	local hex = ("|cff%02x%02x%02x%%d|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
	ok = pcall(formatter.AddBreakpoint, formatter, { threshold = 0, format = " " })
	ok = ok and pcall(formatter.AddBreakpoint, formatter, { threshold = 1, format = hex })
	ok = ok and pcall(formatter.AddBreakpoint, formatter, { threshold = most, format = "|cffffffff%d|r" })
	return ok and formatter or nil
end

function GAME.Init(rec, index, kind, button)
	local most = rec.art.most
	pcall(button.SetAllPoints, button)
	pcall(button.EnableMouse, button, false)
	pcall(button.SetHideTooltipInCombat, button, true)
	local part = rec.parts[index] or {}
	rec.parts[index] = part
	local bar = CreateFrame("StatusBar", nil, button)
	ns.Own[bar] = true
	local low = kind == "full" and most - 1 or 0
	bar:SetMinMaxValues(low, most)
	bar:SetValue(low)
	local made = { button = button, bar = bar }
	part[kind] = made
	if kind == "fill" then
		made.ghost = button:CreateTexture(nil, "BACKGROUND", nil, 0)
		ns.Own[made.ghost] = true
		if index == 1 then
			local top = CreateFrame("Frame", nil, button)
			ns.Own[top] = true
			top:SetAllPoints(button)
			top:SetFrameLevel(bar:GetFrameLevel() + 4)
			made.text = ns.OwnText(top, "OVERLAY", K.FONT)
			if made.text then
				made.text:SetWordWrap(false)
				made.text:SetJustifyH("CENTER")
			end
		end
	else
		local group = bar:CreateAnimationGroup()
		local breathe = group:CreateAnimation("Alpha")
		breathe:SetFromAlpha(K.FULL_LOW)
		breathe:SetToAlpha(1)
		breathe:SetDuration(K.PULSE_TIME)
		breathe:SetSmoothing("IN_OUT")
		group:SetLooping("BOUNCE")
		made.pulse = group
		bar:SetScript("OnShow", function()
			group:Play()
		end)
		group:Play()
	end
	made.ok = pcall(button.SetApplicationBar, button, bar, { minApplications = low, maxApplications = most })
end

function GAME.Enable(rec, on)
	if rec.on == on or InCombatLockdown() then
		return
	end
	for _, key in ipairs(rec.slots) do
		pcall(rec.container.SetAuraSlotEnabled, rec.container, key, on)
	end
	rec.on = on
	if not on then
		pcall(rec.container.SetAlpha, rec.container, 0)
	end
end

function GAME.Build(entry)
	local data = type(ns.ProcArtData) == "function" and ns.ProcArtData(entry)
	if type(data) ~= "table" or type(entry.spells) ~= "table" or #entry.spells == 0 then
		return nil
	end
	local art = Normalise(data)
	if not art.most then
		return nil
	end
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not ok or type(container) ~= "table" then
		return nil
	end
	ns.Own[container] = true
	local rec = { entry = entry, art = art, container = container, parts = {}, slots = {}, on = true }
	local set = {}
	for _, id in ipairs(entry.spells) do
		set[id] = true
	end
	local made = pcall(function()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit("player")
		container:SetAllPoints(holder)
		container:SetAlpha(0)
		for index in ipairs(Locations(art.location)) do
			for _, kind in ipairs({ "fill", "full" }) do
				local key = kind .. index
				rec.slots[#rec.slots + 1] = key
				container:AddAuraSlot(key, "HELPFUL", { candidateFilters = { includeSpellIDs = set }, initializeFrame = function(button)
					local fine, err = pcall(GAME.Init, rec, index, kind, button)
					if not fine then
						rec.err = rec.err or err
					end
				end })
			end
		end
	end)
	local first = rec.parts[1] and rec.parts[1].fill
	if not (made and rec.err == nil and first and first.ok) then
		rec.on = nil
		GAME.Enable(rec, false)
		return false
	end
	GAME.Paint(rec)
	return rec
end

function GAME.Bar(bar, geometry, w, h, x, y, file)
	bar:ClearAllPoints()
	bar:SetPoint(geometry.point, holder, geometry.rel, x, y)
	bar:SetSize(w, h)
	bar:SetStatusBarTexture(file)
	bar:SetOrientation(geometry.dx == 0 and "VERTICAL" or "HORIZONTAL")
	bar:SetReverseFill(geometry.dy < 0 or geometry.dx < 0)
end

function GAME.Key(rec)
	local r, g, b = TextColour(rec.entry, rec.art)
	local tr, tg, tb = ColourOf(rec.entry, rec.art)
	return table.concat({ Setting("artSize", K.SIZE), Setting("artAlpha", K.ALPHA), Setting("artY", 0), r, g, b, tr, tg, tb,
		FixedSlot(rec.entry, rec.art) }, "|")
end

function GAME.Paint(rec)
	if InCombatLockdown() then
		rec.dirty = true
		return
	end
	rec.dirty = nil
	local entry, art = rec.entry, rec.art
	local slot = FixedSlot(entry, art)
	local base = art.alpha * Opacity()
	local r, g, b = ColourOf(entry, art)
	for index, name in ipairs(Locations(art.location)) do
		local part = rec.parts[index]
		local geometry, w, h, x, y = Spot(name, art, slot)
		local flat = not (geometry.flipH or geometry.flipV or art.turn)
		local fill, full = part and part.fill, part and part.full
		if fill then
			local ghost = fill.ghost
			ghost:ClearAllPoints()
			ghost:SetPoint(geometry.point, holder, geometry.rel, x, y)
			ghost:SetSize(w, h)
			ghost:SetTexture(art.file)
			Corners(ghost, geometry, art.turn)
			ghost:SetVertexColor(r, g, b, flat and base * K.GHOST or base)
			GAME.Bar(fill.bar, geometry, w, h, x, y, art.file)
			fill.bar:SetStatusBarColor(r, g, b, base)
			fill.bar:SetAlpha(flat and 1 or 0)
		end
		if full then
			GAME.Bar(full.bar, geometry, w, h, x, y, art.file)
			local texture = full.bar:GetStatusBarTexture()
			if texture then
				pcall(texture.SetBlendMode, texture, "ADD")
			end
			full.bar:SetStatusBarColor(r, g, b, (flat and art.pulse) and base or 0)
		end
	end
	local first = rec.parts[1] and rec.parts[1].fill
	if first and first.text then
		local text = first.text
		Big(text, K.COUNT * Scale())
		text:ClearAllPoints()
		text:SetPoint("CENTER", first.bar, "CENTER", 0, 0)
		text:SetAlpha(TextAlpha())
		local tr, tg, tb = TextColour(entry, art)
		local formatter = GAME.Formatter(tr, tg, tb, art.most)
		first.counted = formatter ~= nil and pcall(first.button.SetApplicationCount, first.button, text, { formatter = formatter })
		if not first.counted then
			text:Hide()
		end
	end
	rec.key = GAME.Key(rec)
end

function GAME.Ready(entry)
	local rec = type(entry) == "table" and GAME.recs[entry.id]
	return type(rec) == "table" and rec.on == true and On() and StacksOn() and ns.Enabled(KEY)
end

function GAME.Show(entry, hidden)
	local id = entry.id
	local rec = GAME.recs[id]
	local wanted = On() and StacksOn() and ns.Enabled(KEY)
	if rec == nil and wanted and holder and not InCombatLockdown() then
		GAME.recs[id] = GAME.Build(entry) or false
		rec = GAME.recs[id]
		local slots = ns.TrackerSlots
		if rec and type(slots) == "table" and type(slots.Flush) == "function" then
			slots.Flush()
		end
	end
	if type(rec) ~= "table" then
		return
	end
	if not InCombatLockdown() then
		GAME.Enable(rec, wanted)
		if rec.on and (rec.dirty or rec.key ~= GAME.Key(rec)) then
			GAME.Paint(rec)
		end
	end
	pcall(rec.container.SetAlpha, rec.container, (wanted and rec.on and hidden) and 1 or 0)
end

function GAME.PaintAll()
	for _, rec in pairs(GAME.recs) do
		if rec then
			if not InCombatLockdown() then
				GAME.Enable(rec, On() and StacksOn() and ns.Enabled(KEY))
			end
			if rec.on then
				GAME.Paint(rec)
			else
				pcall(rec.container.SetAlpha, rec.container, 0)
			end
		end
	end
end

function ns.ProcArtStacks(entry, count, most, hidden)
	if type(entry) ~= "table" or entry.id == nil then
		return
	end
	GAME.Show(entry, hidden == true)
	count = Plain(count, "number") and count or 0
	local rec = Find(entry)
	if not (On() and StacksOn()) or hidden == true or count < 1 then
		if rec then
			rec.keep = nil
			if not rec.up then
				ns.ProcArtHide(entry)
			end
		end
		return
	end
	if rec then
		if rec.up then
			rec.keep = count < most and count or nil
			if count >= most and not rec.sample and rec.stacks ~= count then
				rec.stacks = count
				if holder then
					Layout(rec)
				end
			end
		elseif rec.stacks ~= count then
			rec.stacks = count
			if holder then
				Layout(rec)
			end
		end
		return
	end
	if count >= most or #ups >= K.MAX then
		return
	end
	local data = type(ns.ProcArtData) == "function" and ns.ProcArtData(entry)
	if type(data) ~= "table" then
		return
	end
	local art = Normalise(data)
	if not art.most then
		return
	end
	rec = { entry = entry, id = entry.id, art = art, pieces = {}, stacks = count }
	ups[#ups + 1] = rec
	rec.slot = SlotFor(rec)
	if holder then
		Layout(rec)
	else
		ns.OutOfCombat(Flush)
	end
end

function ns.ProcArtDrop(id)
	local rec = GAME.recs[id]
	if type(rec) == "table" then
		pcall(rec.container.SetAlpha, rec.container, 0)
		if InCombatLockdown() then
			ns.OutOfCombat(function()
				GAME.Enable(rec, false)
			end)
		else
			GAME.Enable(rec, false)
		end
	end
	for _, found in ipairs(ups) do
		if found.id == id and not found.up then
			ns.ProcArtHide(found.entry, true)
			break
		end
	end
end

function ns.ProcArtParts(rec, button, entry)
	if type(entry) ~= "table" then
		error("no proc to draw", 0)
	end
	local given = type(ns.ProcArtData) == "function" and ns.ProcArtData
	local data
	if given then
		local ok, got = pcall(given, entry)
		data = ok and got or nil
	end
	if data == false then
		local none = { pieces = {} }
		function none.Pending()
			return false
		end
		function none.Apply() end
		function none.Shown() end
		return none
	end
	local art = Normalise(data)
	local pieces = {}
	for _, name in ipairs(Locations(art.location)) do
		local ok, texture = pcall(button.CreateTexture, button, nil, "ARTWORK", nil, 0)
		if not ok or type(texture) ~= "table" then
			for _, made in pairs(pieces) do
				pcall(made.SetAlpha, made, 0)
			end
			error("the game refused a piece of art", 0)
		end
		ns.Own[texture] = true
		pieces[name] = texture
	end
	local handle = {}
	local function Put()
		local slot = FixedSlot(entry, art)
		local key = Key(entry, art, slot)
		local r, g, b = ColourOf(entry, art)
		local ratio = Ratio(button)
		local alpha = (On() and not Taken(entry, art)) and Setting("artAlpha", K.ALPHA) / 100 or 0
		local height = Setting("artY", 0)
		for name, texture in pairs(pieces) do
			local geometry, w, h, x, y = Spot(name, art, slot)
			local step = REL[geometry.rel] or REL.CENTER
			texture:ClearAllPoints()
			texture:SetPoint(geometry.point, UIParent, "CENTER", (x + step[1] * K.LONG / 2) / ratio, (y + step[2] * K.LONG / 2 + height) / ratio)
			texture:SetSize(w / ratio, h / ratio)
			texture:SetTexture(art.file)
			Corners(texture, geometry, art.turn)
			texture:SetVertexColor(r, g, b)
			pcall(texture.SetBlendMode, texture, art.look and art.look.add and "ADD" or "BLEND")
			texture:SetAlpha(alpha * art.alpha)
		end
		handle.key = key
	end
	Put()
	handle.pieces = pieces
	function handle.Pending()
		return handle.key ~= Key(entry, art, FixedSlot(entry, art))
	end
	function handle.Apply()
		Put()
	end
	function handle.Shown()
		local found = Find(entry)
		if found and holder then
			Layout(found)
		end
	end
	return handle
end

function ns.ProcArtLine(entry)
	if not On() then
		return "Art: off"
	end
	local given = type(ns.ProcArtData) == "function" and ns.ProcArtData
	if given and type(entry) == "table" then
		local ok, data = pcall(given, entry)
		if ok and data == false then
			return "Art: none, the glow on the button alone"
		end
	end
	local stacks = ""
	local data = given and type(entry) == "table" and select(2, pcall(given, entry))
	local most = type(data) == "table" and Normalise(data).most
	if most and StacksOn() then
		local rec = GAME.recs[entry.id]
		stacks = (" Stacks: builds to %d; in fights the game draws them: %s."):format(most,
			rec == nil and "not made yet" or (rec and rec.on and (rec.parts[1].fill.counted and "fill and number" or "fill")) or "refused")
	end
	local seen = type(entry) == "table" and (last[entry.id or entry] or last[entry])
	if not seen then
		return stacks == "" and "Art: not drawn yet" or ("Art: not drawn yet." .. stacks)
	end
	return ("Art: file %s, %s, drew %s. A file that does not draw is a green block: look at /flatui tracker test.%s"):format(
		tostring(seen.arc and "arc" or seen.file), K.NAMES[seen.location] or seen.location, seen.drew and "yes" or "no", stacks)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	ns.OutOfCombat(Build)
end)
