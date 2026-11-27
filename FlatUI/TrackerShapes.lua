local _, ns = ...

local KEY = "trackers"
local IsSecret = ns.IsSecret

local K = {
	PLATE = { 0.06, 0.06, 0.06, 0.85 }, MISSING = { 0.32, 0.08, 0.08, 0.9 },
	RED = { 0.851, 0.251, 0.251 }, AMBER = { 1, 0.7, 0.2 }, GREY = { 0.6, 0.6, 0.6 }, BLUE = { 0.302, 0.6, 0.902 },
	WHITE = "Interface\\Buttons\\WHITE8X8", FONT = "GameFontHighlightSmall", SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark",
	MOST_MARKS = 10, MARK_ALPHA = 0.9, SPARK_TALL = 2.2, SPARK_WIDE = 0.7,
	PAD = 3, GAP = 4, TICK = 0.25, SAMPLE_COUNT = "20", SAMPLE_TIME = "10:00",
	SAMPLE_GROUP = "40/40",
	REFUSED = {
		bar = "Trackers: the game refused a bar, so a tracker set to Bar is drawn as an icon.",
		text = "Trackers: the game refused a text plate, so a tracker set to Text is drawn as an icon.",
	},
}

local Shapes = {}
ns.TrackerShapes = Shapes

local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

local function Height(entry)
	local height = ns.Get(KEY .. ".barHeight")
	return type(height) == "number" and height or 14
end

local scratch
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

local function Seconds(left)
	local whole = math.ceil(left)
	if whole >= 3600 then
		return ("%dh"):format(math.ceil(whole / 3600))
	elseif whole >= 60 then
		return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
	end
	return ("%d"):format(whole)
end

local function String(host, justify)
	local text = host:CreateFontString(nil, "OVERLAY", K.FONT)
	ns.Own[text] = true
	text:SetJustifyH(justify)
	text:SetWordWrap(false)
	text:SetText("")
	return text
end

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
		part.file = ns.BarTexture(ns.Get(KEY .. ".barTexture")) or K.WHITE
		local ok, done = pcall(bar.SetStatusBarTexture, bar, part.file)
		if not ok or (not IsSecret(done) and done == false) then
			error("the bar texture was refused", 0)
		end
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		record.top:SetFrameLevel(bar:GetFrameLevel() + 1)
		host = bar
		local spark = bar:CreateTexture(nil, "ARTWORK", nil, 7)
		ns.Own[spark] = true
		spark:SetTexture(K.SPARK)
		spark:SetBlendMode("ADD")
		spark:Hide()
		part.spark, part.marks = spark, {}
	end
	part.host = host
	part.name, part.count, part.time = String(host, "LEFT"), String(host, "RIGHT"), String(host, "RIGHT")
	if shape == "bar" then
		for _, text in ipairs({ part.name, part.count, part.time }) do
			text:SetTextColor(1, 1, 1, 1)
		end
	end
end

local function Switch(record, shape)
	for name, part in pairs(record.parts) do
		part.body:SetShown(name == shape)
		part.drawn = nil
	end
	record.texture:SetShown(shape ~= "text")
	if shape == "text" and record.start ~= nil then
		record.cooldown:Clear()
		record.start, record.length = nil, nil
	end
	record.shape = shape
end

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
			Add(entry.kind == "group" and K.SAMPLE_GROUP or K.SAMPLE_COUNT)
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
		local room = ns.Get(KEY .. ".barWidth") - K.PAD * 2 - K.GAP * 2 - Width(entry.kind == "group" and K.SAMPLE_GROUP or K.SAMPLE_COUNT, size)
			- Width(K.SAMPLE_TIME, size)
		part.name:SetWidth(math.max(1, math.floor(room)))
		if part.spark then
			part.spark:SetSize(math.max(6, math.floor(height * K.SPARK_WIDE + 0.5)), math.floor(height * K.SPARK_TALL + 0.5))
		end
		part.marked = nil
	end
	part.row = nil
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", part.body, "BOTTOMRIGHT", -2, 2)
	word:ClearAllPoints()
	word:SetPoint("CENTER", part.body, "CENTER", 0, 0)
	return part.body, height, size
end

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
		local colour = (look.amber and not look.red) and K.AMBER or K.RED
		r, g, b = colour[1], colour[2], colour[3]
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
		local file = ns.BarTexture(ns.Get(KEY .. ".barTexture")) or K.WHITE
		if part.file ~= file then
			part.file = file
			pcall(part.bar.SetStatusBarTexture, part.bar, file)
		end
		part.bar:SetStatusBarColor(r, g, b, 1)
		if look.fill ~= nil then
			Shapes.Glide(part, look.fill)
			Shapes.Marks(part, look.top)
		end
		Shapes.Spark(part, look)
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

function Shapes.Glide(part, fill)
	local list = type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	local smooth = how ~= nil and part.drawn == true and type(part.fill) == "number" and math.abs(fill - part.fill) < 0.5
	if not (smooth and pcall(part.bar.SetValue, part.bar, fill, how)) then
		part.bar:SetValue(fill)
	end
	part.fill, part.drawn = fill, true
end

function Shapes.Spark(part, look)
	local spark = part.spark
	if not spark then
		return
	end
	local fill = part.fill
	local show = type(fill) == "number" and fill > 0.02 and fill < 0.98 and not look.red and not look.none
	if show then
		local texture = part.bar:GetStatusBarTexture()
		if texture and part.sparked ~= texture then
			spark:ClearAllPoints()
			spark:SetPoint("CENTER", texture, "RIGHT", 0, 0)
			part.sparked = texture
		end
		show = part.sparked ~= nil
	end
	spark:SetShown(show)
end

function Shapes.Marks(part, top)
	local marks, width = part.marks, ns.Get(KEY .. ".barWidth")
	if not marks then
		return
	end
	local count = 0
	if not IsSecret(top) and type(top) == "number" and top >= 2 and top <= K.MOST_MARKS and top == math.floor(top) and type(width) == "number" then
		count = top - 1
	end
	local key = count > 0 and (top .. ":" .. width) or ""
	if part.marked == key then
		return
	end
	part.marked = key
	local thick = ns.Pixels(part.bar, 1)
	for index = 1, math.max(count, #marks) do
		local mark = marks[index]
		if index <= count then
			if not mark then
				mark = part.bar:CreateTexture(nil, "ARTWORK", nil, 6)
				ns.Own[mark] = true
				mark:SetColorTexture(K.PLATE[1], K.PLATE[2], K.PLATE[3], K.MARK_ALPHA)
				marks[index] = mark
			end
			local x = math.floor(width * index / top + 0.5)
			mark:ClearAllPoints()
			mark:SetPoint("TOPLEFT", part.bar, "TOPLEFT", x, 0)
			mark:SetPoint("BOTTOMLEFT", part.bar, "BOTTOMLEFT", x, 0)
			mark:SetWidth(thick)
			mark:Show()
		elseif mark then
			mark:Hide()
		end
	end
end

function Shapes.PulseTarget(record)
	local part = record.parts[record.shape]
	return part and part.back or nil
end

local ticking = false
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
