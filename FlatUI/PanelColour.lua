local ADDON_NAME, ns = ...

-- The colour picker of the options window: a square for saturation and brightness, a bar for the hue, an optional bar for the opacity, a hex
-- field and the last colours applied. A change shows at once through onChange, Cancel gives the opening colour back and Apply keeps the change
-- and adds it to the recent colours (kept in the account, FlatUIDB.panel.recent). The widgets are the ones of ns.PanelKit.

local Colour = {}
ns.PanelColour = Colour

local kit = ns.PanelKit
local Look = ns.PanelLook

local WIDTH, HEIGHT = 260, 336
local PAD, SQ, BAR, STEP = 14, 180, 16, 8
local RECENT, SWATCH, GAP = 10, 18, 4
local FADE = 0.08
local HEX = "^%x%x%x%x%x%x%x%x$"

local ui
local state

-- Colour maths ------------------------------------------------------------------------------------

-- Hue, saturation and brightness (each 0 to 1) of a colour of red, green and blue (0 to 1).
function Colour.ToHSV(r, g, b)
	local top, low = math.max(r, g, b), math.min(r, g, b)
	local spread, hue = top - low, 0
	if spread > 0 then
		if top == r then
			hue = ((g - b) / spread) % 6
		elseif top == g then
			hue = (b - r) / spread + 2
		else
			hue = (r - g) / spread + 4
		end
		hue = hue / 6
	end
	return hue, top > 0 and spread / top or 0, top
end

function Colour.ToRGB(h, s, v)
	local sector = math.floor(h * 6)
	local f = h * 6 - sector
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	sector = sector % 6
	if sector == 0 then
		return v, t, p
	elseif sector == 1 then
		return q, v, p
	elseif sector == 2 then
		return p, v, t
	elseif sector == 3 then
		return p, q, v
	elseif sector == 4 then
		return t, p, v
	end
	return v, p, q
end

local function Byte(x)
	return math.floor(kit.Clamp(x, 0, 1) * 255 + 0.5)
end

-- Red, green, blue and opacity (0 to 1) of an AARRGGBB value.
local function Split(value)
	return tonumber(value:sub(3, 4), 16) / 255, tonumber(value:sub(5, 6), 16) / 255, tonumber(value:sub(7, 8), 16) / 255, tonumber(value:sub(1, 2), 16) / 255
end

-- Red, green and blue (0 to 1) of a typed hex: six digits or three, with or without the #. Nil for anything else.
function Colour.Parse(text)
	if not kit.IsText(text) then
		return nil
	end
	local digits = text:gsub("[#%s]", "")
	if #digits == 3 then
		digits = digits:gsub(".", "%0%0")
	end
	if #digits ~= 6 or digits:find("%X") then
		return nil
	end
	return Split("ff" .. digits)
end

-- The colours applied before, newest first.
function Colour.Recent()
	local store = Look.Store(false)
	local list = {}
	if store and type(store.recent) == "table" then
		for _, value in ipairs(store.recent) do
			if kit.IsText(value) and value:match(HEX) and #list < RECENT then
				list[#list + 1] = value
			end
		end
	end
	return list
end

local function Remember(value)
	local store = Look.Store(true)
	if not store then
		return
	end
	local list = { value }
	for _, old in ipairs(Colour.Recent()) do
		if old ~= value and #list < RECENT then
			list[#list + 1] = old
		end
	end
	store.recent = list
end

local function Value()
	return ("%02x%02x%02x%02x"):format(state.a, state.r, state.g, state.b)
end

-- Drawing ---------------------------------------------------------------------------------------

-- A gradient from the low colour (bottom, or left) to the high one. False when the client has none.
local function Grade(texture, orientation, low, high)
	if type(CreateColor) ~= "function" or type(texture.SetGradient) ~= "function" then
		return false
	end
	return pcall(function()
		texture:SetColorTexture(1, 1, 1, 1)
		texture:SetGradient(orientation, CreateColor(low[1], low[2], low[3], low[4]), CreateColor(high[1], high[2], high[3], high[4]))
	end)
end

-- A check pattern behind an area that shows opacity: a light ground with dark squares on every other cell.
local function Checker(parent, width, height)
	local ground = kit.Fill(parent, "BACKGROUND")
	ground:SetAllPoints(parent)
	local squares = {}
	for row = 0, math.ceil(height / STEP) - 1 do
		for column = 0, math.ceil(width / STEP) - 1 do
			if (row + column) % 2 == 1 then
				local square = kit.Fill(parent, "BACKGROUND")
				square:SetPoint("TOPLEFT", parent, "TOPLEFT", column * STEP, -row * STEP)
				square:SetSize(math.min(STEP, width - column * STEP), math.min(STEP, height - row * STEP))
				squares[#squares + 1] = square
			end
		end
	end
	kit.Painted(function()
		kit.Solid(ground, "text-faint")
		for _, square in ipairs(squares) do
			kit.Solid(square, "line-strong")
		end
	end)
end

-- follow runs on the press and on every frame until the left button is up, while a colour is held.
local function Dragging(frame, follow)
	kit.Drag(frame, function()
		if state then
			follow()
		end
	end)
end

-- Where the cursor is over a frame, left to right and bottom to top, 0 to 1. Nil when the client will not say.
local function Where(frame)
	local x, y = kit.Cursor()
	local left, bottom, width, height = kit.Rect(frame)
	if x and left and width > 0 and height > 0 then
		return kit.Clamp((x - left) / width, 0, 1), kit.Clamp((y - bottom) / height, 0, 1)
	end
	return nil
end

local function Thumb(bar)
	local thumb = kit.Frame(bar)
	thumb:SetSize(BAR + 6, 4)
	thumb:SetFrameLevel(bar:GetFrameLevel() + 2)
	local edge = kit.Fill(thumb, "ARTWORK")
	edge:SetAllPoints(thumb)
	local line = kit.Fill(thumb, "OVERLAY")
	line:SetPoint("TOPLEFT", thumb, "TOPLEFT", 1, -1)
	line:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -1, 1)
	kit.Painted(function()
		kit.Solid(edge, "window")
		kit.Solid(line, "text")
	end)
	return thumb
end

-- What the pieces show for the colour held: the square, both bars, the hex and the new swatch.
local function Paint()
	local r, g, b = state.r / 255, state.g / 255, state.b / 255
	local hr, hg, hb = Colour.ToRGB(state.h, 1, 1)
	ui.base:SetColorTexture(hr, hg, hb, 1)
	ui.ring:ClearAllPoints()
	ui.ring:SetPoint("CENTER", ui.square, "BOTTOMLEFT", state.s * SQ, state.v * SQ)
	ui.hueThumb:ClearAllPoints()
	ui.hueThumb:SetPoint("CENTER", ui.hue, "TOP", 0, -state.h * SQ)
	if state.alpha then
		Grade(ui.fade, "VERTICAL", { r, g, b, 0 }, { r, g, b, 1 })
		ui.alphaThumb:ClearAllPoints()
		ui.alphaThumb:SetPoint("CENTER", ui.alphaBar, "TOP", 0, -(1 - state.a / 255) * SQ)
		ui.alphaText:SetText(("%d%%"):format(math.floor(state.a / 255 * 100 + 0.5)))
	end
	ui.new:SetColorTexture(r, g, b, state.alpha and state.a / 255 or 1)
	ui.hex:SetText(("#%02X%02X%02X"):format(state.r, state.g, state.b))
end

-- The player changes the colour: the pieces follow and the row is told.
local function Changed()
	Paint()
	if state.onChange then
		state.onChange(Value())
	end
end

-- The bytes are the colour. The hue stays when the colour has none (grey, black).
local function FromBytes()
	local h, s, v = Colour.ToHSV(state.r / 255, state.g / 255, state.b / 255)
	if s > 0 and v > 0 then
		state.h = h
	end
	state.s, state.v = s, v
end

local function FromHSV()
	local r, g, b = Colour.ToRGB(state.h, state.s, state.v)
	state.r, state.g, state.b = Byte(r), Byte(g), Byte(b)
end

-- Builds the picker once, hidden, over the window.
local function Build()
	if ui then
		return true
	end
	local window = kit.Window()
	if not window then
		return false
	end
	local base = window:GetFrameLevel()
	ui = {}
	-- A click outside the picker is Cancel.
	local shade = kit.Frame(window)
	shade:SetAllPoints(window)
	shade:SetFrameStrata("FULLSCREEN_DIALOG")
	shade:SetFrameLevel(base + 50)
	shade:EnableMouse(true)
	shade:EnableMouseWheel(true)
	local dim = kit.Fill(shade, "BACKGROUND")
	dim:SetAllPoints(shade)
	kit.Solid(dim, "stage", 0.5)
	shade:SetScript("OnMouseDown", function()
		Colour.Cancel()
	end)
	shade:Hide()
	ui.shade = shade

	local popup = kit.Frame(window)
	popup:SetSize(WIDTH, HEIGHT)
	popup:SetPoint("CENTER", window, "CENTER", 0, 0)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetFrameLevel(base + 55)
	popup:EnableMouse(true)
	local box = ns.Outline(popup, popup, true)
	kit.Painted(function()
		kit.Backing(box, "card", 1, "line-strong")
	end)
	popup:SetScript("OnHide", function()
		if state then
			Colour.Cancel()
		end
	end)
	popup:Hide()
	ui.popup = popup

	-- The square: the hue at full strength, white fading to nothing from left to right, and black rising from the bottom edge to nothing.
	local square = kit.Frame(popup)
	square:SetSize(SQ, SQ)
	square:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -PAD)
	ui.square = square
	ui.base = kit.Fill(square, "BACKGROUND")
	ui.base:SetAllPoints(square)
	local white = kit.Fill(square, "ARTWORK")
	white:SetAllPoints(square)
	local black = kit.Fill(square, "OVERLAY")
	black:SetAllPoints(square)
	if not (Grade(white, "HORIZONTAL", { 1, 1, 1, 1 }, { 1, 1, 1, 0 }) and Grade(black, "VERTICAL", { 0, 0, 0, 1 }, { 0, 0, 0, 0 })) then
		white:Hide()
		black:Hide()
	end
	local ring = kit.Frame(square)
	ring:SetSize(10, 10)
	ring:SetFrameLevel(square:GetFrameLevel() + 2)
	local edges = {}
	for index, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = kit.Fill(ring, "ARTWORK")
		if index <= 2 then
			line:SetPoint(side .. "LEFT", ring, side .. "LEFT", 0, 0)
			line:SetPoint(side .. "RIGHT", ring, side .. "RIGHT", 0, 0)
			line:SetHeight(2)
		else
			line:SetPoint("TOP" .. side, ring, "TOP" .. side, 0, 0)
			line:SetPoint("BOTTOM" .. side, ring, "BOTTOM" .. side, 0, 0)
			line:SetWidth(2)
		end
		edges[index] = line
	end
	kit.Painted(function()
		for _, line in ipairs(edges) do
			kit.Solid(line, "text")
		end
	end)
	ui.ring = ring
	Dragging(square, function()
		local x, y = Where(square)
		if x then
			state.s, state.v = x, y
			FromHSV()
			Changed()
		end
	end)

	-- The hue bar: the six steps of the colour wheel, red at the top and again at the bottom.
	local hue = kit.Frame(popup)
	hue:SetSize(BAR, SQ)
	hue:SetPoint("TOPLEFT", square, "TOPRIGHT", 10, 0)
	ui.hue = hue
	for step = 0, 5 do
		local band = kit.Fill(hue, "ARTWORK")
		band:SetSize(BAR, SQ / 6)
		band:SetPoint("TOPLEFT", hue, "TOPLEFT", 0, -step * SQ / 6)
		local tr, tg, tb = Colour.ToRGB(step / 6, 1, 1)
		local br, bg, bb = Colour.ToRGB((step + 1) / 6, 1, 1)
		if not Grade(band, "VERTICAL", { br, bg, bb, 1 }, { tr, tg, tb, 1 }) then
			band:SetColorTexture(tr, tg, tb, 1)
		end
	end
	ui.hueThumb = Thumb(hue)
	Dragging(hue, function()
		local _, y = Where(hue)
		if y then
			state.h = 1 - y
			FromHSV()
			Changed()
		end
	end)

	-- The opacity bar, over a check pattern: clear at the bottom, full at the top. Only a row that uses the opacity shows it.
	local bar = kit.Frame(popup)
	bar:SetSize(BAR, SQ)
	bar:SetPoint("TOPLEFT", hue, "TOPRIGHT", 10, 0)
	ui.alphaBar = bar
	Checker(bar, BAR, SQ)
	ui.fade = kit.Fill(bar, "ARTWORK")
	ui.fade:SetAllPoints(bar)
	ui.alphaThumb = Thumb(bar)
	Dragging(bar, function()
		local _, y = Where(bar)
		if y then
			state.a = Byte(y)
			Changed()
		end
	end)
	ui.alphaText = kit.Dim(kit.Label(popup, "GameFontHighlightSmall", "CENTER", 44))
	ui.alphaText:SetPoint("TOP", bar, "BOTTOM", 0, -8)

	-- The hex field, and the colour held beside the colour it opened with.
	ui.hex = kit.Field(popup, 96, 7, function()
		if state and not Colour.Hex(ui.hex:GetText()) then
			Paint()
		end
	end)
	ui.hex:SetPoint("TOPLEFT", square, "BOTTOMLEFT", 0, -10)
	ui.hex:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	-- Escape drops what was typed.
	ui.hex:SetScript("OnEscapePressed", function(self)
		if state then
			Paint()
		end
		self:ClearFocus()
	end)
	for index, side in ipairs({ "new", "old" }) do
		local holder = kit.Frame(popup)
		holder:SetSize(40, 24)
		holder:SetPoint("LEFT", ui.hex, "RIGHT", 8 + (index - 1) * 44, 0)
		local edge = kit.Fill(holder, "BACKGROUND")
		edge:SetAllPoints(holder)
		local ground = kit.Fill(holder, "BORDER")
		ground:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
		ground:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
		local fill = kit.Fill(holder, "ARTWORK")
		fill:SetAllPoints(ground)
		kit.Painted(function()
			kit.Solid(edge, "line-strong")
			kit.Solid(ground, "text-faint")
		end)
		ui[side] = fill
	end

	local recent = kit.Dim(kit.Label(popup, "GameFontHighlightSmall", "LEFT", 120))
	recent:SetPoint("TOPLEFT", ui.hex, "BOTTOMLEFT", 0, -10)
	recent:SetText("Recent")
	ui.recent = {}
	for index = 1, RECENT do
		local cell = kit.Frame(popup)
		cell:SetSize(SWATCH, SWATCH)
		cell:SetPoint("TOPLEFT", recent, "BOTTOMLEFT", (index - 1) * (SWATCH + GAP), -4)
		local edge = kit.Fill(cell, "BACKGROUND")
		edge:SetAllPoints(cell)
		local fill = kit.Fill(cell, "ARTWORK")
		fill:SetPoint("TOPLEFT", cell, "TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
		kit.Painted(function()
			kit.Solid(edge, "line-strong")
		end)
		kit.Clickable(cell, function()
			local value = cell.value
			if state and value then
				local cr, cg, cb, ca = Split(value)
				Colour.Pick(cr, cg, cb, ca)
			end
		end)
		cell.fill = fill
		cell:Hide()
		ui.recent[index] = cell
	end

	local apply = kit.Button(popup, "Apply", 88, function()
		Colour.Apply()
	end, true)
	apply:SetHeight(28)
	apply:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -PAD, 12)
	local cancel = kit.Button(popup, "Cancel", 88, function()
		Colour.Cancel()
	end)
	cancel:SetHeight(28)
	cancel:SetPoint("RIGHT", apply, "LEFT", -8, 0)
	ui.apply, ui.cancel = apply, cancel
	return true
end

-- Use -------------------------------------------------------------------------------------------

-- Opens the picker on an AARRGGBB value. onChange(value) runs on every change and again with the opening value on Cancel. With alpha the
-- opacity bar shows and the opacity is part of the change; without it the opacity of the value stays. False when the window is not there.
function Colour.Open(value, alpha, onChange)
	if not kit.IsText(value) or not value:match(HEX) or not Build() then
		return false
	end
	if state then
		Colour.Cancel()
	end
	local r, g, b, a = Split(value)
	state = { old = value, onChange = onChange, alpha = alpha == true, r = Byte(r), g = Byte(g), b = Byte(b), a = Byte(a), h = 0 }
	FromBytes()
	ui.old:SetColorTexture(r, g, b, state.alpha and a or 1)
	ui.alphaBar:SetShown(state.alpha)
	ui.alphaText:SetShown(state.alpha)
	local list = Colour.Recent()
	for index, cell in ipairs(ui.recent) do
		cell.value = list[index]
		if cell.value then
			local cr, cg, cb, ca = Split(cell.value)
			cell.fill:SetColorTexture(cr, cg, cb, state.alpha and ca or 1)
		end
		cell:SetShown(cell.value ~= nil)
	end
	Paint()
	ui.shade:Show()
	ui.popup:SetAlpha(0)
	ui.popup:Show()
	local waited = 0
	ui.popup:SetScript("OnUpdate", function(self, elapsed)
		waited = waited + (type(elapsed) == "number" and elapsed or FADE)
		if waited >= FADE then
			self:SetAlpha(1)
			self:SetScript("OnUpdate", nil)
		else
			self:SetAlpha(waited / FADE)
		end
	end)
	return true
end

function Colour.Shown()
	return state ~= nil
end

-- Sets the colour from red, green, blue (0 to 1) and, when the row uses the opacity, the opacity.
function Colour.Pick(r, g, b, a)
	if not state then
		return
	end
	state.r, state.g, state.b = Byte(r), Byte(g), Byte(b)
	if a and state.alpha then
		state.a = Byte(a)
	end
	FromBytes()
	Changed()
end

-- A typed hex. False (and nothing changes) when it is not a colour.
function Colour.Hex(text)
	local r, g, b = Colour.Parse(text)
	if not state or not r then
		return false
	end
	Colour.Pick(r, g, b)
	return true
end

local function Close()
	local was = state
	state = nil
	ui.popup:SetScript("OnUpdate", nil)
	ui.popup:Hide()
	ui.shade:Hide()
	return was
end

-- Keeps the change and puts the colour among the recent ones.
function Colour.Apply()
	if state and ui.hex:HasFocus() then
		Colour.Hex(ui.hex:GetText())
	end
	local was = state and Close()
	if was then
		local value = ("%02x%02x%02x%02x"):format(was.a, was.r, was.g, was.b)
		if value ~= was.old then
			Remember(value)
		end
	end
end

-- Gives the opening colour back.
function Colour.Cancel()
	local was = state and Close()
	if was and was.onChange then
		was.onChange(was.old)
	end
end

-- The pieces, for the checks.
function Colour.Parts()
	return ui
end
