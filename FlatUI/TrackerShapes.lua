local _, ns = ...

-- The Bar and Text shapes of a tracker. Trackers.lua draws the icon; this file makes the parts of the other two shapes on a tracker's
-- record, says how wide and tall each shape is, and draws a look in them. A bar is a flat status bar with the name on its left and the
-- charges and the time left on its right, beside a square that keeps the icon and its sweep. Text is the name, the charges and the time left
-- on a dark plate. The parts are made once per record, out of combat, and hidden when the record has another shape. A part the game refuses
-- leaves the tracker an icon. Everything drawn here is a texture, text, colour or bar value call, which the game allows in combat, and every
-- number handed to a bar is a plain number made by the addon.

local KEY = "trackers"
local IsSecret = ns.IsSecret

-- PLATE: the dark plate behind a bar or text, and MISSING the same plate when the buff is gone.
-- WHITE: the image the fill of a bar is made from while no bar texture is chosen.
-- FONT: the font object of every string. PAD: units inside a plate, GAP: units between two strings.
-- TICK: seconds between two redraws of a time left, MAX_TEXT: the widest text a tracker is measured for.
-- REFUSED: the line a refused part leaves in the status.
local K = {
	PLATE = { 0.06, 0.06, 0.06, 0.85 }, MISSING = { 0.32, 0.08, 0.08, 0.9 },
	RED = { 0.851, 0.251, 0.251 }, GREY = { 0.6, 0.6, 0.6 }, BLUE = { 0.302, 0.6, 0.902 },
	WHITE = "Interface\\Buttons\\WHITE8X8", FONT = "GameFontHighlightSmall",
	PAD = 3, GAP = 4, TICK = 0.25, SAMPLE_COUNT = "20", SAMPLE_TIME = "10:00",
	REFUSED = {
		bar = "Trackers: the game refused a bar, so a tracker set to Bar is drawn as an icon.",
		text = "Trackers: the game refused a text plate, so a tracker set to Text is drawn as an icon.",
	},
}

local Shapes = {}
ns.TrackerShapes = Shapes

-- The text of the strings is as high as the bar allows.
local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

local function Height(entry)
	local height = ns.Get(KEY .. ".barHeight")
	return type(height) == "number" and height or 14
end

local scratch
-- The width of a text in the font the strings use, measured on a string that is never shown.
local function Width(text, height)
	if not scratch then
		local frame = CreateFrame("Frame", nil, UIParent)
		ns.Own[frame] = true
		frame:Hide()
		scratch = frame:CreateFontString(nil, "OVERLAY", K.FONT)
		ns.Own[scratch] = true
	end
	scratch:SetTextHeight(height)
	scratch:SetText(text)
	local ok, width = pcall(scratch.GetStringWidth, scratch)
	if ok and not IsSecret(width) and type(width) == "number" then
		return width
	end
	return #text * height * 0.6
end

-- Red, green and blue of a tracker's colour: its own, else the page's.
local function Colour(entry)
	local hex = ns.TrackerValue(entry, "colour")
	if type(hex) == "string" and #hex == 8 then
		local r, g, b = tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
		if r and g and b then
			return r / 255, g / 255, b / 255
		end
	end
	return K.BLUE[1], K.BLUE[2], K.BLUE[3]
end

-- "1:05" for a minute and more, "45" under it, "2h" for hours.
local function Seconds(left)
	local whole = math.ceil(left)
	if whole >= 3600 then
		return ("%dh"):format(math.ceil(whole / 3600))
	elseif whole >= 60 then
		return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
	end
	return ("%d"):format(whole)
end

-- Making the parts ------------------------------------------------------------------------------------------

local function String(host, justify)
	local text = host:CreateFontString(nil, "OVERLAY", K.FONT)
	ns.Own[text] = true
	text:SetJustifyH(justify)
	text:SetWordWrap(false)
	text:SetText("")
	return text
end

-- Builds the parts of a shape into part; raises when the game refuses one.
local function Build(record, shape, part)
	local frame = record.frame
	local body = CreateFrame("Frame", nil, frame)
	ns.Own[body] = true
	part.body = body
	body:SetFrameLevel(frame:GetFrameLevel() + 1)
	part.back = body:CreateTexture(nil, "BACKGROUND", nil, -7)
	ns.Own[part.back] = true
	part.back:SetAllPoints(body)
	part.back:SetColorTexture(K.PLATE[1], K.PLATE[2], K.PLATE[3], K.PLATE[4])
	part.plate = K.PLATE
	local host = body
	if shape == "bar" then
		local bar = CreateFrame("StatusBar", nil, body)
		ns.Own[bar] = true
		part.bar = bar
		bar:SetAllPoints(body)
		local ok, done = pcall(bar.SetStatusBarTexture, bar, ns.BarTexture() or K.WHITE)
		if not ok or (not IsSecret(done) and done == false) then
			error("the bar texture was refused", 0)
		end
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		-- The count, the word and the red edge of the record are drawn above the bar.
		record.top:SetFrameLevel(bar:GetFrameLevel() + 1)
		host = bar
	end
	part.host = host
	part.name, part.count, part.time = String(host, "LEFT"), String(host, "RIGHT"), String(host, "RIGHT")
	if shape == "bar" then
		for _, text in ipairs({ part.name, part.count, part.time }) do
			text:SetTextColor(1, 1, 1, 1)
		end
	end
end

-- Shows the parts of the shape the record now has and hides the others.
local function Switch(record, shape)
	for name, part in pairs(record.parts) do
		part.body:SetShown(name == shape)
	end
	record.texture:SetShown(shape ~= "text")
	if shape == "text" and record.start ~= nil then
		record.cooldown:Clear()
		record.start, record.length = nil, nil
	end
	record.shape = shape
end

-- The shape the record is drawn in: the one asked for, or the icon when the game refused a part.
function Shapes.Make(record, shape)
	if shape ~= "bar" and shape ~= "text" then
		shape = "icon"
	end
	if shape ~= "icon" and not record.parts[shape] and not record.refused[shape] then
		local part = {}
		if pcall(Build, record, shape, part) then
			record.parts[shape] = part
		else
			if part.body then
				part.body:Hide()
			end
			record.refused[shape] = true
			ns.Note(KEY, K.REFUSED[shape])
		end
	end
	if shape ~= "icon" and not record.parts[shape] then
		shape = "icon"
	end
	if record.shape ~= shape then
		Switch(record, shape)
	end
	return shape
end

-- Size ---------------------------------------------------------------------------------------------------------

-- How wide and tall a tracker is in a shape. An icon is its size, a bar is the bar's width beside a square of its height, and text is
-- the width of the strings it shows, each measured at its widest, on a plate of the bar's height.
function Shapes.Size(entry, shape)
	local value = ns.TrackerValue
	shape = shape or value(entry, "shape")
	if shape == "bar" then
		local height = Height(entry)
		return ns.Get(KEY .. ".barWidth") + height, height
	elseif shape == "text" then
		local height = Height(entry)
		local size, wide, shown = TextHeight(height), 0, 0
		local function Add(text)
			wide, shown = wide + Width(text, size), shown + 1
		end
		if ns.Get(KEY .. ".names") then
			Add(ns.TrackerLabel(entry))
		end
		if value(entry, "counts") and entry.charged then
			Add(K.SAMPLE_COUNT)
		end
		if value(entry, "numbers") then
			Add(K.SAMPLE_TIME)
		end
		if shown == 0 then
			return height, height
		end
		return math.ceil(wide + K.GAP * (shown - 1)) + K.PAD * 2, height
	end
	local size = value(entry, "size")
	return size, size
end

-- Fitting ---------------------------------------------------------------------------------------------------------

-- Places the parts of the record's shape inside its frame. Gives the frame the red edge hugs, the height that edge is drawn for and the
-- height of the word Missing.
function Shapes.Fit(record, entry)
	local shape, frame = record.shape, record.frame
	local texture, cooldown = record.texture, record.cooldown
	local count, word = record.count, record.word
	if shape == "icon" then
		texture:SetAllPoints(frame)
		cooldown:SetAllPoints(frame)
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", record.top, "BOTTOMRIGHT", -2, 2)
		word:ClearAllPoints()
		word:SetPoint("CENTER", record.top, "CENTER", 0, 0)
		local size = ns.TrackerValue(entry, "size")
		return record.top, size, math.max(5, math.floor((size - 2) / 4))
	end
	local part = record.parts[shape]
	local height = Height(entry)
	local square = shape == "bar" and height or 0
	for _, region in ipairs({ texture, cooldown }) do
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", square, 0)
	end
	part.body:ClearAllPoints()
	part.body:SetPoint("TOPLEFT", frame, "TOPLEFT", square, 0)
	part.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	local size = TextHeight(height)
	for _, text in ipairs({ part.name, part.count, part.time }) do
		text:SetTextHeight(size)
	end
	if shape == "bar" then
		-- The name stops before the strings on the right.
		local room = ns.Get(KEY .. ".barWidth") - K.PAD * 2 - K.GAP * 2 - Width(K.SAMPLE_COUNT, size) - Width(K.SAMPLE_TIME, size)
		part.name:SetWidth(math.max(1, math.floor(room)))
	end
	part.row = nil
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", part.body, "BOTTOMRIGHT", -2, 2)
	word:ClearAllPoints()
	word:SetPoint("CENTER", part.body, "CENTER", 0, 0)
	return part.body, height, size
end

-- Drawing ---------------------------------------------------------------------------------------------------------

-- The strings that have text, in a row from one edge: the first at the edge, each next one after it.
local function Row(host, list, point, sign)
	local before
	for _, text in ipairs(list) do
		if text:GetText() ~= "" then
			text:ClearAllPoints()
			if before then
				text:SetPoint(point, before, point == "LEFT" and "RIGHT" or "LEFT", sign * K.GAP, 0)
			else
				text:SetPoint(point, host, point, sign * K.PAD, 0)
			end
			before = text
		end
	end
end

-- The look of a bar or a text tracker: the plate, the fill, the strings and their colour. A look with no fill keeps the fill drawn last.
function Shapes.Apply(record, entry, look)
	local part = record.parts[record.shape]
	if not part then
		return
	end
	local r, g, b = Colour(entry)
	if look.grey then
		r, g, b = K.GREY[1], K.GREY[2], K.GREY[3]
	end
	if look.countRed or look.red then
		r, g, b = K.RED[1], K.RED[2], K.RED[3]
	end
	local plate = look.red and K.MISSING or K.PLATE
	if part.plate ~= plate then
		part.back:SetColorTexture(plate[1], plate[2], plate[3], plate[4])
		part.plate = plate
	end
	local name, count = look.name or "", look.count or ""
	local time = ""
	if look.left and ns.TrackerValue(entry, "numbers") then
		time = Seconds(look.left)
	end
	part.name:SetText(name)
	part.count:SetText(count)
	part.time:SetText(time)
	if part.bar then
		part.bar:SetStatusBarColor(r, g, b, 1)
		if look.fill ~= nil then
			part.bar:SetValue(look.fill)
		end
	else
		for _, text in ipairs({ part.name, part.count, part.time }) do
			text:SetTextColor(r, g, b, 1)
		end
	end
	local row = (name ~= "" and "n" or "-") .. (count ~= "" and "c" or "-") .. (time ~= "" and "t" or "-")
	if part.row ~= row then
		part.row = row
		if part.bar then
			Row(part.host, { part.name }, "LEFT", 1)
			Row(part.host, { part.time, part.count }, "RIGHT", -1)
		else
			Row(part.host, { part.name, part.count, part.time }, "LEFT", 1)
		end
	end
end

-- The texture the pulse of a missing tracker plays on: the plate of a bar or text, nil for an icon.
function Shapes.PulseTarget(record)
	local part = record.parts[record.shape]
	return part and part.back or nil
end

local ticking = false
-- A time left changes between two events: one call to run, K.TICK seconds from now, while any tracker draws one.
function Shapes.Tick(run)
	if ticking or not (C_Timer and C_Timer.After) then
		return
	end
	ticking = true
	C_Timer.After(K.TICK, function()
		ticking = false
		run()
	end)
end
