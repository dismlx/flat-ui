local ADDON_NAME, ns = ...

local L = {}
ns.ChargesLook = L

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local TAU = math.pi * 2

L.GLOW, L.RING = MEDIA .. "Glow.tga", MEDIA .. "Ring.tga"
L.MASK_ATLAS, L.MASK_FILE = "CircleMaskScalable", "Interface\\CharacterFrame\\TempPortraitAlphaMask"
L.MOST = 10
L.BURST, L.FLASH, L.SWELL = 0.35, 0.15, 1.8
L.STEP, L.POP, L.POP_FROM = 0.06, 0.18, 1.45
L.FADE, L.FADE_IN = 0.4, 0.15
L.SPIN = { still = 0, slow = TAU / 14, fast = TAU / 4 }
L.AMBER, L.RED = { 1, 0.7, 0.2 }, { 1, 0.22, 0.18 }
L.LOW, L.CLOCK = 10, 0.1
L.PULSE = 1.4
L.HALO, L.BODY, L.CORE, L.GHOST = 2.4, 1.3, 0.55, 0.95
L.CROP = 0.06

local IsSecret = ns.IsSecret

local function Own(object)
	ns.Own[object] = true
	return object
end
L.Own = Own

local function Opt(key)
	return ns.Get("charges." .. key)
end
L.Opt = Opt

local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end
L.Number = Number

function L.Mask(owner, texture)
	local ok, mask = pcall(owner.CreateMaskTexture, owner)
	if not ok or type(mask) ~= "table" then
		return nil
	end
	Own(mask)
	mask:SetAllPoints(texture)
	local set, done = pcall(mask.SetAtlas, mask, L.MASK_ATLAS, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	if not set or done == false then
		pcall(mask.SetTexture, mask, L.MASK_FILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	pcall(texture.AddMaskTexture, texture, mask)
	return mask
end

function L.Glow(owner, layer, sub, blend)
	local texture = Own(owner:CreateTexture(nil, layer, nil, sub))
	texture:SetTexture(L.GLOW)
	pcall(texture.SetBlendMode, texture, blend or "ADD")
	return texture
end

function L.Bar(owner, index, level)
	local bar = Own(CreateFrame("StatusBar", nil, owner))
	bar:SetStatusBarTexture(L.GLOW)
	local ok, fill = pcall(bar.GetStatusBarTexture, bar)
	if ok and type(fill) == "table" and not IsSecret(fill) then
		pcall(fill.SetBlendMode, fill, "ADD")
	end
	bar:SetMinMaxValues(index - 1, index)
	bar:SetValue(index - 1)
	bar:SetFrameLevel(owner:GetFrameLevel() + level)
	return bar
end

function L.Text(owner, font)
	local text = ns.OwnText(owner, "OVERLAY", font)
	if text then
		text:SetWordWrap(false)
		text:SetJustifyH("CENTER")
	end
	return text
end

function L.Face(d, owner)
	local face = {}
	face.back = L.Glow(owner, "BACKGROUND", 0)
	face.shade = L.Glow(owner, "BACKGROUND", 1, "BLEND")
	face.shade:SetVertexColor(0, 0, 0, 0.75)
	face.icon = Own(owner:CreateTexture(nil, "ARTWORK", nil, 0))
	face.icon:SetTexCoord(L.CROP, 1 - L.CROP, L.CROP, 1 - L.CROP)
	face.mask = L.Mask(owner, face.icon)
	face.rim = Own(owner:CreateTexture(nil, "OVERLAY", nil, 0))
	face.rim:SetTexture(L.RING)
	face.rim:SetVertexColor(0.04, 0.04, 0.05, 0.9)
	face.sheen = Own(owner:CreateTexture(nil, "OVERLAY", nil, 1))
	face.sheen:SetTexture(L.RING)
	pcall(face.sheen.SetBlendMode, face.sheen, "ADD")
	for _, texture in ipairs({ face.back, face.shade, face.icon, face.rim, face.sheen }) do
		texture:SetPoint("CENTER", d.centre, "CENTER", 0, 0)
	end
	return face
end

function L.PaintFace(face, size, r, g, b)
	face.back:SetSize(size * 1.9, size * 1.9)
	face.back:SetVertexColor(r, g, b, 0.22)
	face.shade:SetSize(size * 1.4, size * 1.4)
	face.icon:SetSize(size, size)
	face.rim:SetSize(size * 1.1, size * 1.1)
	face.sheen:SetSize(size * 1.02, size * 1.02)
	face.sheen:SetVertexColor(r, g, b, 0.45)
end

function L.New(parent)
	local d = { spots = {}, orbs = {}, n = 0, phase = 0, lit = 0, clock = 0 }
	local frame = Own(CreateFrame("Frame", nil, parent))
	frame:SetSize(1, 1)
	frame:SetAlpha(0)
	d.frame = frame
	local centre = Own(CreateFrame("Frame", nil, frame))
	centre:SetSize(1, 1)
	centre:SetPoint("CENTER", frame, "CENTER", 0, 0)
	d.centre = centre
	local own = Own(CreateFrame("Frame", nil, frame))
	own:SetAllPoints(frame)
	d.own = own
	local face = Own(CreateFrame("Frame", nil, own))
	face:SetAllPoints(own)
	face:SetFrameLevel(own:GetFrameLevel() + 1)
	d.face = L.Face(d, face)
	local fx = Own(CreateFrame("Frame", nil, own))
	fx:SetAllPoints(own)
	fx:SetFrameLevel(own:GetFrameLevel() + 6)
	d.fx = fx
	local top = Own(CreateFrame("Frame", nil, own))
	top:SetAllPoints(own)
	top:SetFrameLevel(own:GetFrameLevel() + 8)
	d.number = L.Text(top, "NumberFontNormal")
	if d.number then
		d.number:SetPoint("CENTER", centre, "CENTER", 0, 0)
	end
	d.time = L.Text(top, "NumberFontNormalSmall")
	return d
end

function L.Spot(d, index)
	local spot = d.spots[index]
	if not spot then
		spot = Own(CreateFrame("Frame", nil, d.frame))
		spot:SetSize(1, 1)
		spot:SetPoint("CENTER", d.centre, "CENTER", 0, 0)
		d.spots[index] = spot
	end
	return spot
end

function L.Orb(d, index)
	local orb = d.orbs[index]
	if orb then
		return orb
	end
	local spot = L.Spot(d, index)
	orb = { index = index }
	orb.ghost = Own(d.own:CreateTexture(nil, "BORDER", nil, 0))
	orb.ghost:SetTexture(L.RING)
	pcall(orb.ghost.SetBlendMode, orb.ghost, "ADD")
	orb.ghost:SetPoint("CENTER", spot, "CENTER", 0, 0)
	local frame = Own(CreateFrame("Frame", nil, d.own))
	frame:SetPoint("CENTER", spot, "CENTER", 0, 0)
	frame:SetFrameLevel(d.own:GetFrameLevel() + 3)
	orb.frame = frame
	orb.bars = { L.Bar(frame, index, 0), L.Bar(frame, index, 1), L.Bar(frame, index, 2) }
	for _, bar in ipairs(orb.bars) do
		bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
	end
	orb.burst = L.Glow(d.fx, "ARTWORK", 0)
	orb.burst:SetPoint("CENTER", spot, "CENTER", 0, 0)
	orb.burst:SetAlpha(0)
	orb.flash = L.Glow(d.fx, "ARTWORK", 1)
	orb.flash:SetPoint("CENTER", spot, "CENTER", 0, 0)
	orb.flash:SetVertexColor(1, 1, 1, 1)
	orb.flash:SetAlpha(0)
	d.orbs[index] = orb
	return orb
end

local function Light(value)
	return value + (1 - value) * 0.7
end

function L.TintOrb(orb, r, g, b)
	orb.bars[1]:SetStatusBarColor(r, g, b, 0.3)
	orb.bars[2]:SetStatusBarColor(r, g, b, 1)
	orb.bars[3]:SetStatusBarColor(Light(r), Light(g), Light(b), 0.9)
	orb.tint = nil
end

function L.PaintOrb(d, orb, size, r, g, b)
	orb.frame:SetSize(size, size)
	orb.bars[1]:SetSize(size * L.HALO, size * L.HALO)
	orb.bars[2]:SetSize(size * L.BODY, size * L.BODY)
	orb.bars[3]:SetSize(size * L.CORE, size * L.CORE)
	orb.ghost:SetSize(size * L.GHOST, size * L.GHOST)
	orb.ghost:SetVertexColor(r, g, b, 0.32)
	orb.ghost:SetShown(Opt("ghosts") ~= false and orb.index <= d.n)
	orb.burst:SetSize(size * L.BODY, size * L.BODY)
	orb.burst:SetVertexColor(r, g, b, 1)
	orb.flash:SetSize(size * 1.7, size * 1.7)
	L.TintOrb(orb, r, g, b)
	orb.frame:SetShown(orb.index <= d.n)
end

function L.Geometry(d)
	local style, size, orb, n = d.style, d.size, d.orb, math.max(1, d.n)
	local radius = size / 2 + orb * 0.95
	local edge = orb * 0.75
	d.radius = radius
	if style == "row" then
		local gap = orb * 1.35
		d.gap = gap
		d.rowY = -(size / 2 + orb * 1.05)
		local top, bottom = size / 2 + 2, size / 2 + orb * 1.05 + edge
		d.w = math.max(size + 6, (n - 1) * gap + orb * 1.6)
		d.h = top + bottom
		d.cy = (bottom - top) / 2
	elseif style == "arc" then
		local step = orb * 1.4 / radius
		d.span = math.min((n - 1) * step, math.rad(200))
		local top, bottom = radius + edge, size / 2 + 3
		d.w = 2 * (radius + edge)
		d.h = top + bottom
		d.cy = (bottom - top) / 2
	else
		d.w = 2 * (radius + edge)
		d.h = d.w
		d.cy = 0
	end
end

function L.PlaceSpots(d)
	local n, phase, orb = d.n, d.phase, d.orb
	local sway = d.speed > 0
	for index = 1, n do
		local x, y
		if d.style == "row" then
			x = (index - (n + 1) / 2) * d.gap
			y = d.rowY + (sway and math.sin(phase * 4 + index * 0.9) * orb * 0.15 or 0)
		elseif d.style == "arc" then
			local step = n > 1 and d.span / (n - 1) or 0
			local angle = math.pi / 2 + d.span / 2 - (index - 1) * step
			local r = d.radius + (sway and math.sin(phase * 4 + index * 0.9) * orb * 0.12 or 0)
			x, y = r * math.cos(angle), r * math.sin(angle)
		else
			local angle = math.pi / 2 - phase - (index - 1) * TAU / n
			x, y = d.radius * math.cos(angle), d.radius * math.sin(angle)
		end
		local spot = d.spots[index]
		spot:ClearAllPoints()
		spot:SetPoint("CENTER", d.centre, "CENTER", x, y)
	end
end

function L.Colour(d)
	local by = Opt("colourBy")
	if by == "one" then
		return ns.Colour("charges.colour")
	end
	local rgb = by ~= "class" and d.rgb or nil
	if rgb then
		return rgb[1], rgb[2], rgb[3]
	end
	local r, g, b = ns.ClassColour()
	if r then
		return r, g, b
	end
	return 0.4, 0.7, 1
end

function L.TextLook(d)
	local percent = math.max(80, math.min(150, d.size / 40 * 100))
	if d.time then
		ns.TextStyle(d.time, { percent = percent, flags = "OUTLINE" })
		d.time:ClearAllPoints()
		d.time:SetPoint("TOP", d.frame, "BOTTOM", 0, d.style == "row" and 2 or d.orb * 0.4)
	end
	if d.number then
		ns.TextStyle(d.number, { percent = percent * 1.2, flags = "OUTLINE" })
	end
end

function L.Paint(d, top)
	d.style = Opt("style")
	d.speed = L.SPIN[Opt("spin")] or 0
	d.size = Number("iconSize", 40)
	d.orb = Number("orbSize", 12)
	d.n = math.max(1, math.min(L.MOST, top or d.n or 1))
	L.Geometry(d)
	d.frame:SetSize(d.w, d.h)
	d.centre:ClearAllPoints()
	d.centre:SetPoint("CENTER", d.frame, "CENTER", 0, d.cy)
	local r, g, b = L.Colour(d)
	d.r, d.g, d.b = r, g, b
	L.PaintFace(d.face, d.size, r, g, b)
	for index = 1, L.MOST do
		local orb = index <= d.n and L.Orb(d, index) or d.orbs[index]
		if orb then
			L.PaintOrb(d, orb, d.orb, r, g, b)
		end
	end
	L.PlaceSpots(d)
	L.TextLook(d)
	if d.game then
		d.game.Paint(d)
	end
	d.painted = true
end

function L.SetIcon(d, file)
	if d.file ~= file then
		d.file = file
		d.face.icon:SetTexture(file or 134400)
	end
end

local function Value(orb, value)
	for _, bar in ipairs(orb.bars) do
		if not pcall(bar.SetValue, bar, value) then
			bar:SetValue(orb.index - 1)
		end
	end
end
L.Value = Value

function L.Rest(orb)
	orb.anim = nil
	orb.frame:SetScale(1)
	orb.frame:SetAlpha(1)
	orb.burst:SetAlpha(0)
	orb.flash:SetAlpha(0)
end

function L.Burst(d, orb, now)
	L.Rest(orb)
	Value(orb, orb.index - 1)
	if Opt("burst") ~= false then
		orb.anim = { kind = "burst", start = now, size = d.orb * L.BODY }
		orb.burst:SetSize(d.orb * L.BODY, d.orb * L.BODY)
		orb.burst:SetAlpha(1)
		orb.flash:SetAlpha(1)
		d.busy = true
	end
end

function L.Pop(orb, now, delay)
	L.Rest(orb)
	orb.anim = { kind = "pop", start = now + delay, lit = false }
	orb.frame:SetAlpha(0)
end

function L.Secret(d, value)
	d.lit, d.pulse, d.secret = nil, nil, true
	for index = 1, d.n do
		local orb = d.orbs[index]
		if orb then
			L.Rest(orb)
			Value(orb, value)
			L.TintOrb(orb, d.r, d.g, d.b)
		end
	end
	if d.number then
		d.number:SetText("")
	end
end

function L.Count(d, count, animate, now)
	local was = d.secret and nil or d.lit
	local lit = math.max(0, math.min(count, d.n))
	d.secret = nil
	if animate and was ~= nil and lit < was then
		for index = lit + 1, math.min(was, d.n) do
			L.Burst(d, d.orbs[index], now)
		end
	elseif animate and was ~= nil and lit > was then
		for index = was + 1, lit do
			L.Pop(d.orbs[index], now, (index - was - 1) * L.STEP)
		end
		d.busy = true
	end
	for index = 1, d.n do
		local orb = d.orbs[index]
		if not orb.anim or (orb.anim.kind == "pop" and index > lit) then
			if orb.anim then
				L.Rest(orb)
			end
			Value(orb, index <= lit and index or index - 1)
		end
	end
	d.lit = lit
	local pulse = count == 1 and 1 or nil
	if d.pulse ~= pulse and d.pulse and d.orbs[d.pulse] then
		local orb = d.orbs[d.pulse]
		orb.frame:SetScale(1)
		orb.frame:SetAlpha(1)
		L.TintOrb(orb, d.r, d.g, d.b)
	end
	d.pulse = pulse
	if d.number then
		d.number:SetText(count > L.MOST and tostring(count) or "")
	end
end

local function Ease(t)
	return 1 - (1 - t) * (1 - t)
end

function L.Animate(orb, now)
	local anim = orb.anim
	local t = now - anim.start
	if anim.kind == "burst" then
		local p = math.min(1, t / L.BURST)
		local grow = 1 + (L.SWELL - 1) * Ease(p)
		orb.burst:SetSize(anim.size * grow, anim.size * grow)
		orb.burst:SetAlpha(1 - p)
		orb.flash:SetAlpha(math.max(0, 1 - t / L.FLASH))
		if p >= 1 then
			L.Rest(orb)
			orb.burst:SetSize(anim.size, anim.size)
		end
		return
	end
	if t < 0 then
		return
	end
	if not anim.lit then
		anim.lit = true
		Value(orb, orb.index)
		orb.flash:SetAlpha(0.6)
	end
	local p = math.min(1, t / L.POP)
	orb.frame:SetScale(L.POP_FROM - (L.POP_FROM - 1) * Ease(p))
	orb.frame:SetAlpha(p)
	orb.flash:SetAlpha(0.6 * (1 - p))
	if p >= 1 then
		L.Rest(orb)
	end
end

function L.Pulse(d, now)
	local orb = d.pulse and d.orbs[d.pulse]
	if not orb or orb.anim then
		return
	end
	local wave = 0.5 + 0.5 * math.sin(now * TAU * L.PULSE)
	orb.frame:SetAlpha(0.55 + 0.45 * wave)
	orb.frame:SetScale(1 + 0.16 * wave)
	local colour = d.low and L.RED or L.AMBER
	if orb.tint ~= colour then
		L.TintOrb(orb, colour[1], colour[2], colour[3])
		orb.tint = colour
	end
end

local function Seconds(left)
	if left >= 3600 then
		return ("%dh"):format(math.ceil(left / 3600))
	elseif left >= 60 then
		return ("%dm"):format(math.ceil(left / 60))
	elseif left >= 3 then
		return ("%d"):format(math.floor(left))
	end
	return ("%.1f"):format(math.max(0, left))
end

function L.Clock(d, now)
	local text = d.time
	local expires = d.expires
	if not (ns.Finite(expires) and expires > 0) then
		d.low = false
		if text then
			text:SetText("")
		end
		return nil
	end
	local left = expires - now
	d.low = left <= L.LOW
	if text then
		if Opt("time") ~= false then
			text:SetText(Seconds(left))
			local amber = L.AMBER
			if d.low then
				text:SetTextColor(amber[1], amber[2], amber[3])
			else
				text:SetTextColor(1, 1, 1)
			end
		else
			text:SetText("")
		end
	end
	return left
end

function L.Tick(d, now, elapsed)
	local busy = false
	if d.fading then
		local p = math.min(1, (now - d.fading) / L.FADE)
		d.frame:SetAlpha(1 - p)
		if p >= 1 then
			d.fading = nil
			d.frame:SetAlpha(0)
			d.shown = false
			return false
		end
		busy = true
	elseif d.fadeIn then
		local p = math.min(1, (now - d.fadeIn) / L.FADE_IN)
		d.frame:SetAlpha(p)
		if p >= 1 then
			d.fadeIn = nil
		end
		busy = true
	end
	if d.speed > 0 and d.n > 0 then
		d.phase = (d.phase + d.speed * elapsed) % (TAU * 8)
		L.PlaceSpots(d)
		busy = true
	end
	local animating = false
	for index = 1, d.n do
		local orb = d.orbs[index]
		if orb and orb.anim then
			L.Animate(orb, now)
			animating = animating or orb.anim ~= nil
		end
	end
	d.busy = animating
	if d.pulse then
		L.Pulse(d, now)
		busy = true
	end
	d.clock = d.clock + elapsed
	if d.clock >= L.CLOCK and not d.fading then
		d.clock = 0
		d.left = L.Clock(d, now)
	end
	return busy or animating or d.left ~= nil
end

function L.Show(d, now)
	if not d.shown or d.fading then
		d.fading = nil
		d.shown = true
		d.fadeIn = now
		d.frame:SetAlpha(0)
	end
end

function L.Gone(d, now, animate)
	if not d.shown then
		return
	end
	if animate and not d.fading then
		for index = 1, math.min(d.lit or 0, d.n) do
			L.Burst(d, d.orbs[index], now)
		end
		d.lit = 0
		d.pulse = nil
		d.fading = now
		d.fadeIn = nil
		return
	end
	if not animate then
		d.fading, d.fadeIn, d.shown = nil, nil, false
		d.frame:SetAlpha(0)
	end
end

function L.Still(d)
	for index = 1, d.n do
		local orb = d.orbs[index]
		if orb then
			L.Rest(orb)
		end
	end
	d.busy = false
	if d.pulse and d.orbs[d.pulse] then
		L.TintOrb(d.orbs[d.pulse], d.r, d.g, d.b)
	end
	d.pulse = nil
end
