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
	MAX_SCALE = 5, MAX_SECONDS = 120,
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

local holder, PlaceHolder
local pool, ups, fading, last = {}, {}, {}, {}

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
	return { file = file, location = location, scale = scale, colour = colour, arc = arc, alpha = alpha, turn = turn, pulse = data.pulse ~= false,
		seconds = seconds }
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

local function ColourOf(entry, art)
	local own = type(entry) == "table" and entry.colour
	if (Plain(own, "string") or art.arc) and ProcRgb(entry) then
		return ProcRgb(entry)
	end
	if art.colour then
		return art.colour[1], art.colour[2], art.colour[3]
	end
	if art.arc then
		return K.FALLBACK[1], K.FALLBACK[2], K.FALLBACK[3]
	end
	return 1, 1, 1
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
	for _, set in pairs(piece.looks) do
		set.fadeIn:Stop()
		set.pulse:Stop()
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

local function FadeIn(piece, seconds, pulse)
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
			pulse:Play()
		end
	end)
	return group
end

local function UseLook(piece, look)
	piece.look = look
	for name, set in pairs(piece.looks) do
		if name ~= look then
			set.fadeIn:Stop()
			set.pulse:Stop()
		end
	end
	piece.animIn, piece.pulse = piece.looks[look].fadeIn, piece.looks[look].pulse
end

local function MakePiece()
	local piece = CreateFrame("Frame", nil, holder)
	ns.Own[piece] = true
	piece:Hide()
	piece.tex = piece:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[piece.tex] = true
	piece.tex:SetAllPoints(piece)
	piece.looks = {}
	for look, steps in pairs({ game = { K.FADE_IN, K.PULSE_UP, K.PULSE_DOWN, K.PULSE_TIME },
		soft = { K.SOFT_FADE_IN, K.SOFT_UP, K.SOFT_DOWN, K.SOFT_TIME } }) do
		local pulse = Pulse(piece, steps[2], steps[3], steps[4])
		piece.looks[look] = { pulse = pulse, fadeIn = FadeIn(piece, steps[1], pulse) }
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
	Corners(piece.tex, g, art.turn)
	piece.tex:SetAlpha(art.alpha)
end

local function GameIcon(entry)
	local slots = ns.TrackerSlots
	local call = type(slots) == "table" and slots.InUse
	return type(call) == "function" and call(entry) == true
end

local function Layout(rec, again)
	local r, g, b = ColourOf(rec.entry, rec.art)
	local game = GameIcon(rec.entry)
	rec.drew = true
	local wanted = Locations(rec.art.location)
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
			piece.pulses = rec.art.pulse
			local look = Look()
			if piece.look ~= look then
				local moving = piece.animIn:IsPlaying() or piece.pulse:IsPlaying()
				UseLook(piece, look)
				if moving and not piece.fresh then
					piece:SetAlpha(1)
					if piece.pulses then
						piece.pulse:Play()
					end
				end
			end
			if not piece.pulses and piece.pulse:IsPlaying() then
				piece.pulse:Stop()
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
	holder:SetAlpha(Setting("artAlpha", K.ALPHA) / 100)
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
	table.remove(ups, index)
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
end

function ns.ProcArtChanged()
	if holder then
		if not On() then
			ns.ProcArtReset()
		else
			PlaceHolder()
			for _, rec in ipairs(ups) do
				Layout(rec)
			end
		end
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

local function Key(entry, art, slot)
	local r, g, b = ColourOf(entry, art)
	return table.concat({ On() and "on" or "off", Setting("artSize", K.SIZE), Setting("artAlpha", K.ALPHA), Setting("artY", 0), r, g, b, slot,
		tostring(art.file), art.location }, "|")
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
		local alpha = On() and Setting("artAlpha", K.ALPHA) / 100 or 0
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
	local seen = type(entry) == "table" and (last[entry.id or entry] or last[entry])
	if not seen then
		return "Art: not drawn yet"
	end
	return ("Art: file %s, %s, drew %s. A file that does not draw is a green block: look at /flatui tracker test."):format(
		tostring(seen.arc and "arc" or seen.file), K.NAMES[seen.location] or seen.location, seen.drew and "yes" or "no")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	ns.OutOfCombat(Build)
end)
