local _, ns = ...

local KEY = "threat"
local GLIDE, SLIDE = 0.2, 0.25
local FLASH_IN, FLASH_OUT, FLASH_ALPHA = 0.06, 0.32, 0.55
local SHEEN_W, SHEEN_ALPHA, SHEEN_RUN, SHEEN_REST = 34, 0.2, 1.1, 2.6
local NAME_LIGHT = 0.45
local CLOSE = 0.1
local IsSecret = ns.IsSecret

local L = { glides = {}, slides = {}, last = setmetatable({}, { __mode = "k" }), scope = setmetatable({}, { __mode = "k" }) }
ns.ThreatLook = L

local driver

local function Own(object)
	ns.Own[object] = true
	return object
end

function L.On()
	return ns.Get(KEY .. ".animate") ~= false
end

local function Ease(t)
	local left = 1 - t
	return 1 - left * left * left
end

local function Busy()
	return next(L.glides) ~= nil or next(L.slides) ~= nil
end

local function Put(row, parent, offset)
	return pcall(row.bar.SetPoint, row.bar, "TOPLEFT", parent, "TOPLEFT", row.x, row.y + offset)
end

local function Step(elapsed)
	local dt = ns.Finite(elapsed) and elapsed > 0 and elapsed or 0
	for row, glide in pairs(L.glides) do
		glide.t = glide.t + dt / GLIDE
		local value = glide.to
		if glide.t < 1 then
			value = glide.from + (glide.to - glide.from) * Ease(glide.t)
		else
			L.glides[row] = nil
		end
		row.shownValue = value
		pcall(row.bar.SetValue, row.bar, value)
	end
	for row, slide in pairs(L.slides) do
		slide.t = slide.t + dt / SLIDE
		local offset = 0
		if slide.t < 1 then
			offset = slide.dy * (1 - Ease(slide.t))
		else
			L.slides[row] = nil
		end
		Put(row, slide.parent, offset)
	end
	if not Busy() and driver then
		driver:SetScript("OnUpdate", nil)
	end
end

function L.Settle()
	for row, glide in pairs(L.glides) do
		row.shownValue = glide.to
		pcall(row.bar.SetValue, row.bar, glide.to)
	end
	for row, slide in pairs(L.slides) do
		Put(row, slide.parent, 0)
	end
	L.glides, L.slides = {}, {}
	if driver then
		driver:SetScript("OnUpdate", nil)
	end
end

local function Run()
	if not driver then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return false
		end
		driver = Own(frame)
	end
	driver:SetScript("OnUpdate", function(_, elapsed)
		if not ns.Try(KEY, Step, elapsed) then
			pcall(L.Settle)
		end
	end)
	return true
end

function L.Value(row, value, jump)
	if type(row) ~= "table" or type(row.bar) ~= "table" then
		return false
	end
	if IsSecret(value) or not ns.Finite(value) then
		L.glides[row], row.shownValue = nil, nil
		return false
	end
	local from = row.shownValue
	if jump or from == nil or not L.On() or math.abs(value - from) < CLOSE or not Run() then
		L.glides[row] = nil
		row.shownValue = value
		return (pcall(row.bar.SetValue, row.bar, value))
	end
	local glide = L.glides[row]
	if glide and glide.to == value then
		return true
	end
	L.glides[row] = { from = from, to = value, t = 0 }
	return true
end

local function Gradient(texture, from, to)
	texture:SetColorTexture(1, 1, 1, 1)
	if type(CreateColor) ~= "function" or type(texture.SetGradient) ~= "function" then
		return false
	end
	return (pcall(texture.SetGradient, texture, "HORIZONTAL", CreateColor(1, 1, 1, from), CreateColor(1, 1, 1, to)))
end

local function Sheen(bar)
	local ok, made = pcall(function()
		local clip = Own(CreateFrame("Frame", nil, bar))
		pcall(clip.SetClipsChildren, clip, true)
		clip:SetAllPoints(bar)
		local band = Own(CreateFrame("Frame", nil, clip))
		band:SetPoint("TOPRIGHT", clip, "TOPLEFT", 0, 0)
		band:SetPoint("BOTTOMRIGHT", clip, "BOTTOMLEFT", 0, 0)
		band:SetWidth(SHEEN_W)
		local left = Own(band:CreateTexture(nil, "OVERLAY", nil, 5))
		left:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMRIGHT", band, "BOTTOM", 0, 0)
		local right = Own(band:CreateTexture(nil, "OVERLAY", nil, 5))
		right:SetPoint("TOPRIGHT", band, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMLEFT", band, "BOTTOM", 0, 0)
		if not (Gradient(left, 0, SHEEN_ALPHA) and Gradient(right, SHEEN_ALPHA, 0)) then
			left:SetColorTexture(1, 1, 1, SHEEN_ALPHA / 2)
			right:SetColorTexture(1, 1, 1, SHEEN_ALPHA / 2)
		end
		pcall(left.SetBlendMode, left, "ADD")
		pcall(right.SetBlendMode, right, "ADD")
		local group = Own(band:CreateAnimationGroup())
		group:SetLooping("REPEAT")
		local move = Own(group:CreateAnimation("Translation"))
		move:SetOffset(200, 0)
		move:SetDuration(SHEEN_RUN)
		pcall(move.SetSmoothing, move, "IN_OUT")
		pcall(move.SetEndDelay, move, SHEEN_REST)
		clip:Hide()
		return { clip = clip, band = band, group = group, move = move }
	end)
	return ok and type(made) == "table" and made or nil
end

local function Flash(texture)
	local ok, group = pcall(function()
		local made = Own(texture:CreateAnimationGroup())
		local rise = Own(made:CreateAnimation("Alpha"))
		rise:SetFromAlpha(0)
		rise:SetToAlpha(FLASH_ALPHA)
		rise:SetDuration(FLASH_IN)
		rise:SetOrder(1)
		local fall = Own(made:CreateAnimation("Alpha"))
		fall:SetFromAlpha(FLASH_ALPHA)
		fall:SetToAlpha(0)
		fall:SetDuration(FLASH_OUT)
		fall:SetOrder(2)
		made:SetScript("OnFinished", function()
			texture:Hide()
		end)
		return made
	end)
	return ok and type(group) == "table" and group or nil
end

function L.Dress(row)
	if type(row) ~= "table" or type(row.bar) ~= "table" or row.dressed then
		return
	end
	row.dressed = true
	local bar = row.bar
	local flash = Own(bar:CreateTexture(nil, "OVERLAY", nil, 6))
	flash:SetAllPoints(bar)
	flash:SetColorTexture(1, 1, 1, 1)
	pcall(flash.SetBlendMode, flash, "ADD")
	flash:SetAlpha(0)
	flash:Hide()
	row.flash, row.flashes = flash, Flash(flash)
	row.sheen = Sheen(bar)
	if row.name then
		pcall(row.name.SetShadowColor, row.name, 0, 0, 0, 1)
		pcall(row.name.SetShadowOffset, row.name, 1, -1)
	end
end

function L.Flash(row, r, g, b)
	local flash, group = row and row.flash, row and row.flashes
	if not flash or not group then
		return
	end
	flash:SetVertexColor(r or 1, g or 1, b or 1, 1)
	pcall(group.Stop, group)
	flash:SetAlpha(0)
	flash:Show()
	if not pcall(group.Play, group) then
		flash:Hide()
	end
end

function L.Sheen(row, on)
	local sheen = row and row.sheen
	if not sheen then
		return
	end
	if not (on and L.On() and row.bar:IsShown()) then
		if sheen.on then
			sheen.on = nil
			pcall(sheen.group.Stop, sheen.group)
			sheen.clip:Hide()
		end
		return
	end
	local width = ns.Finite(row.width) and row.width or 180
	if sheen.width ~= width then
		sheen.width = width
		pcall(sheen.move.SetOffset, sheen.move, width + SHEEN_W, 0)
		if sheen.on then
			pcall(sheen.group.Stop, sheen.group)
			pcall(sheen.group.Play, sheen.group)
		end
	end
	if sheen.on then
		return
	end
	sheen.on = true
	local clip = sheen.clip
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", row.bar, "TOPLEFT", 0, 0)
	local ok, fill = pcall(row.bar.GetStatusBarTexture, row.bar)
	if not (ok and type(fill) == "table" and not IsSecret(fill) and pcall(clip.SetPoint, clip, "BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)) then
		clip:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 0, 0)
	end
	clip:Show()
	pcall(sheen.group.Play, sheen.group)
end

function L.Name(row, r, g, b)
	local text = row and row.name
	if not text then
		return
	end
	if L.On() and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		local k = NAME_LIGHT
		text:SetTextColor(r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k, 1)
	else
		text:SetTextColor(1, 1, 1, 1)
	end
end

function L.Halt(row)
	if type(row) ~= "table" then
		return
	end
	L.glides[row] = nil
	local slide = L.slides[row]
	if slide then
		L.slides[row] = nil
		Put(row, slide.parent, 0)
	end
	L.Sheen(row, false)
end

function L.Laid(rows, n, x, top, step, width)
	for index = 1, n do
		local row = rows[index]
		if row then
			L.slides[row] = nil
			row.x, row.y, row.step, row.width = x, -(top + (index - 1) * step), step, width
		end
	end
end

local function Slide(row, parent, dy)
	if not ns.Finite(dy) or dy == 0 or not ns.Finite(row.x) or not ns.Finite(row.y) or not Run() then
		return
	end
	L.slides[row] = { dy = dy, t = 0, parent = parent }
	Put(row, parent, dy)
end

function L.Order(rows, n, scope, parent, keys)
	local last = L.last[rows]
	local fresh = last == nil or L.scope[rows] ~= scope or parent == nil or not parent:IsShown()
	local animate = L.On()
	local now = {}
	for index = 1, n do
		local row = rows[index]
		local key = keys and keys[index] or (row and row.who)
		if row and key ~= nil then
			now[key] = index
			local was = not fresh and last[key] or nil
			if was and was ~= index and animate then
				Slide(row, parent, (index - was) * (ns.Finite(row.step) and row.step or 0))
				if was > index then
					L.Flash(row)
				end
			end
		end
		if row then
			L.Sheen(row, index == 1)
		end
	end
	for index = n + 1, #rows do
		L.Halt(rows[index])
	end
	L.last[rows], L.scope[rows] = now, scope
end

function L.Forget(rows)
	L.last[rows], L.scope[rows] = nil, nil
	for _, row in ipairs(rows) do
		L.Halt(row)
	end
end
