local _, ns = ...

ns.SetupDrawings = ns.SetupDrawings or {}

local PAD = 8
local CROP = 0.08
local RED = { 0.851, 0.251, 0.251 }
local BLUE = { 0.302, 0.6, 0.902 }
local PLATE = { 0.06, 0.06, 0.06, 0.85 }
local PLATE_MISSING = { 0.32, 0.08, 0.08, 0.9 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICONS = "Interface\\Icons\\"
local TRACKER_GAP, TRACKER_PAD = 4, 3
local CLASS = {
	WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, MAGE = { 0.41, 0.8, 0.94 }, PRIEST = { 1, 1, 1 },
	DRUID = { 1, 0.49, 0.04 }, ROGUE = { 1, 0.96, 0.41 }, SHAMAN = { 0, 0.44, 0.87 },
}

local U = {}

local function Own(object)
	ns.Own[object] = true
	return object
end

function U.Frame(parent)
	return Own(CreateFrame("Frame", nil, parent))
end

function U.Tex(parent, layer, sub)
	return Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

function U.Str(parent, font, justify)
	local text = Own(parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall"))
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(false)
	text:SetText("")
	return text
end

function U.Show(region, on)
	region:SetShown(on and true or false)
end

function U.At(region, point, relative, relativePoint, x, y)
	region:ClearAllPoints()
	region:SetPoint(point, relative, relativePoint, x or 0, y or 0)
end

function U.Box(parent, x, y, w, h, r, g, b, a, layer, sub)
	local tex = U.Tex(parent, layer or "ARTWORK", sub or 0)
	tex:SetColorTexture(r, g, b, a or 1)
	tex:SetSize(w, h)
	U.At(tex, "TOPLEFT", parent, "TOPLEFT", x, -y)
	return tex
end

function U.Class(class)
	local colour = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class] or nil
	if type(colour) == "table" and type(colour.r) == "number" and not ns.IsSecret(colour.r) and type(colour.g) == "number" and type(colour.b) == "number" then
		return colour.r, colour.g, colour.b
	end
	local sample = CLASS[class] or CLASS.WARRIOR
	return sample[1], sample[2], sample[3]
end

function U.Seconds(left)
	local whole = math.ceil(left)
	if whole >= 3600 then
		return ("%dh"):format(math.ceil(whole / 3600))
	elseif whole >= 60 then
		return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
	end
	return ("%d"):format(whole)
end

local scratch
function U.Width(text, height)
	if not scratch then
		local frame = U.Frame(UIParent)
		frame:Hide()
		scratch = U.Str(frame, "GameFontHighlightSmall", "LEFT")
	end
	scratch:SetTextHeight(height)
	scratch:SetText(text)
	local ok, width = pcall(scratch.GetStringWidth, scratch)
	if ok and not ns.IsSecret(width) and type(width) == "number" then
		return width
	end
	return #text * height * 0.6
end

function U.Sweep(cooldown, elapsed, length)
	if not cooldown then
		return
	end
	local now = type(GetTime) == "function" and GetTime() or 0
	pcall(cooldown.SetCooldown, cooldown, now - elapsed, length)
	if cooldown.Pause then
		pcall(cooldown.Pause, cooldown)
	end
end

function U.NoSweep(cooldown)
	if cooldown then
		pcall(cooldown.Clear, cooldown)
	end
end

function U.Cooldown(frame)
	local ok, cooldown = pcall(CreateFrame, "Cooldown", nil, frame, "CooldownFrameTemplate")
	if not ok or type(cooldown) ~= "table" then
		return nil
	end
	Own(cooldown)
	cooldown:SetAllPoints(frame)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetSwipeColor(0, 0, 0, 0.7)
	return cooldown
end

function U.Finish(s, w, h)
	s.w, s.h = math.max(1, math.ceil(w)), math.max(1, math.ceil(h))
	s.root:SetSize(s.w, s.h)
end

function U.Tick(grow, total)
	local x = PAD + 6
	if grow == "left" then
		return x + total
	elseif grow == "middle" or grow == "center" then
		return x + total / 2
	end
	return x
end

function U.Register(id, spec)
	local drawing = { id = id, parts = {} }
	local built = setmetatable({}, { __mode = "k" })
	function drawing.build(stage)
		local s = built[stage]
		if s then
			return s.root
		end
		s = spec.build(stage)
		built[stage] = s
		if not drawing.filled then
			drawing.filled = true
			for path, region in pairs(s.parts) do
				drawing.parts[path] = region
			end
		end
		s.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
		return s.root
	end
	function drawing.draw(stage)
		drawing.build(stage)
		local s = built[stage]
		spec.draw(s, stage)
		return s.root
	end
	function drawing.extent(stage)
		drawing.build(stage)
		local s = built[stage]
		return s.w or 1, s.h or 1
	end
	function drawing.partsOf(stage)
		drawing.build(stage)
		return built[stage].parts
	end
	ns.SetupDrawings[id] = drawing
	return drawing
end

local function Root(stage)
	local root = U.Frame(stage)
	root:SetSize(1, 1)
	return root
end

local TRACKERS = {
	{ name = "Lightning Shield", icon = ICONS .. "Spell_Nature_LightningShield", count = 2, top = 3, left = 541, length = 600 },
	{ name = "Fortitude", icon = ICONS .. "Spell_Holy_WordFortitude", left = 1500, length = 3600 },
	{ name = "Mana Potion", icon = ICONS .. "INV_Potion_76", count = 4, top = 5 },
}

local DEFENSIVES = {
	{ icon = ICONS .. "Spell_Holy_PowerWordShield", left = 14, name = "Alari", class = "PRIEST" },
	{ icon = ICONS .. "Spell_Holy_SealOfProtection", left = 6, name = "Tomas", class = "PALADIN" },
	{ icon = ICONS .. "Spell_Nature_Regeneration", left = 9, name = "Leaf", class = "DRUID" },
}

local SPELLS = {
	{ "Ability_Kick", nil, nil, nil, "1" }, { "Spell_Frost_IceShock", 12, 30, nil, "2" }, { "Spell_Holy_PowerWordShield", nil, nil, nil, "3" },
	{ "Spell_Arcane_Blink", 14, 15, 2, "4" }, { "Ability_Warrior_ShieldWall", 48, 120, nil, "5" }, { "Spell_Frost_Frost", nil, nil, nil, "Q" },
	{ "Spell_Nature_Bloodlust", nil, nil, nil, "E" }, { "Ability_Rogue_Sprint", 3, 8, nil, "R" }, { "Spell_Holy_SealOfValor", nil, nil, nil, "F" },
	{ "Spell_Shadow_ShadowWard", 20, 60, nil, "G" }, { "Ability_Rogue_Evasion", nil, nil, nil, "Z" }, { "Spell_Holy_DivineIntervention", nil, nil, nil, "X" },
	{ "Ability_Warrior_Charge", 5, 15, nil, "C" }, { "Spell_Holy_Heal", nil, nil, nil, "V" },
}
local TRINKETS = { { "INV_Jewelry_Trinket_05", nil, nil, nil, "T" }, { "INV_Misc_Rune_01", 30, 90, nil, "Y" } }
local NUMBER_FONTS = { small = "NumberFontNormalSmall", normal = "NumberFontNormal", large = "NumberFontNormalLarge", huge = "NumberFontNormalHuge" }

local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

function U.NewCell(parent)
	local cell = { frame = U.Frame(parent), parts = {} }
	local frame = cell.frame
	cell.tex = U.Tex(frame, "ARTWORK", 0)
	cell.tex:SetAllPoints(frame)
	cell.tex:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	cell.sweep = U.Cooldown(frame)
	cell.outline = ns.Outline(frame, frame)
	cell.top = U.Frame(frame)
	cell.top:SetAllPoints(frame)
	cell.top:SetFrameLevel((cell.sweep and cell.sweep:GetFrameLevel() or frame:GetFrameLevel()) + 1)
	cell.count = U.Str(cell.top, "NumberFontNormalSmall", "RIGHT")
	cell.count:SetPoint("BOTTOMRIGHT", cell.top, "BOTTOMRIGHT", -2, 2)
	cell.word = U.Str(cell.top, "GameFontHighlightSmall", "CENTER")
	cell.word:SetText("Missing")
	cell.word:Hide()
	cell.rim = {}
	for index = 1, 4 do
		local edge = U.Tex(cell.top, "OVERLAY", 6)
		edge:SetColorTexture(RED[1], RED[2], RED[3], 1)
		edge:Hide()
		cell.rim[index] = edge
	end
	for _, shape in ipairs({ "bar", "text" }) do
		local part = { body = U.Frame(frame) }
		part.body:SetFrameLevel(frame:GetFrameLevel() + 1)
		part.back = U.Tex(part.body, "BACKGROUND", -7)
		part.back:SetAllPoints(part.body)
		part.back:SetColorTexture(PLATE[1], PLATE[2], PLATE[3], PLATE[4])
		part.host = part.body
		if shape == "bar" then
			part.bar = Own(CreateFrame("StatusBar", nil, part.body))
			part.bar:SetAllPoints(part.body)
			part.bar:SetStatusBarTexture(ns.BarTexture() or WHITE)
			part.bar:SetMinMaxValues(0, 1)
			part.bar:SetValue(0)
			part.host = part.bar
		end
		part.name, part.count, part.time = U.Str(part.host, "GameFontHighlightSmall", "LEFT"), U.Str(part.host, "GameFontHighlightSmall", "RIGHT"),
			U.Str(part.host, "GameFontHighlightSmall", "RIGHT")
		part.body:Hide()
		cell.parts[shape] = part
	end
	return cell
end

function U.FitRim(cell, anchor)
	local rim, thick = cell.rim, 2
	U.At(rim[1], "TOPLEFT", anchor, "TOPLEFT", 0, 0)
	rim[1]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
	rim[1]:SetHeight(thick)
	U.At(rim[2], "BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
	rim[2]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
	rim[2]:SetHeight(thick)
	U.At(rim[3], "TOPLEFT", anchor, "TOPLEFT", 0, -thick)
	rim[3]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, thick)
	rim[3]:SetWidth(thick)
	U.At(rim[4], "TOPRIGHT", anchor, "TOPRIGHT", 0, -thick)
	rim[4]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, thick)
	rim[4]:SetWidth(thick)
end

function U.Pulse(cell, target, on)
	cell.groups = cell.groups or {}
	local old = cell.pulseTarget
	if old and (old ~= target or not on) then
		local group = cell.groups[old]
		if group then
			pcall(group.Stop, group)
		end
		old:SetAlpha(1)
		cell.pulseTarget = nil
	end
	if not on then
		return
	end
	local group = cell.groups[target]
	if group == nil then
		local ok, made = pcall(function()
			local g = target:CreateAnimationGroup()
			local alpha = g:CreateAnimation("Alpha")
			alpha:SetFromAlpha(1)
			alpha:SetToAlpha(0.35)
			alpha:SetDuration(0.6)
			g:SetLooping("BOUNCE")
			return g
		end)
		group = ok and made or false
		cell.groups[target] = group
	end
	if group and cell.pulseTarget ~= target then
		pcall(group.Play, group)
	end
	target:SetAlpha(0.7)
	cell.pulseTarget = target
end

function U.ApplyCell(cell, spec)
	local shape = (spec.shape == "bar" or spec.shape == "text") and spec.shape or "icon"
	local sample, state = spec.sample, spec.state
	local missing, low = state == "missing", state == "low"
	local count, left = spec.count or sample.count, spec.left or sample.left
	local r, g, b = spec.colour[1], spec.colour[2], spec.colour[3]
	if missing or low then
		r, g, b = RED[1], RED[2], RED[3]
	end
	local name = spec.names and sample.name or ""
	local counted = spec.counts and count and not missing and ("%d"):format(count) or ""
	local timed = spec.numbers and left and not missing and U.Seconds(left) or ""
	local fill = 1
	if missing then
		fill = 0
	elseif spec.fill == "charges" and count and sample.top then
		fill = math.min(1, count / sample.top)
	elseif left and sample.length then
		fill = math.max(0, math.min(1, left / sample.length))
	end
	local frame, part = cell.frame, cell.parts[shape]
	local width, height, anchor
	cell.tex:SetTexture(sample.icon)
	cell.tex:SetDesaturated(missing)
	if missing then
		cell.tex:SetVertexColor(RED[1], RED[2], RED[3])
	else
		cell.tex:SetVertexColor(1, 1, 1)
	end
	ns.SetOutline(cell.outline, spec.border ~= false, spec.border ~= false)
	for key, other in pairs(cell.parts) do
		other.body:SetShown(key == shape)
	end
	U.Show(cell.tex, shape ~= "text")
	if shape == "icon" then
		width, height = spec.size, spec.size
		frame:SetSize(width, height)
		cell.tex:SetAllPoints(frame)
		anchor = cell.top
		cell.count:SetText(counted)
		cell.count:SetTextColor(low and RED[1] or 1, low and RED[2] or 1, low and RED[3] or 1, 1)
		U.At(cell.word, "CENTER", cell.top, "CENTER", 0, 0)
		cell.word:SetTextHeight(math.max(5, math.floor((spec.size - 2) / 4)))
	else
		height = spec.height
		local size = TextHeight(height)
		cell.count:SetText("")
		if shape == "bar" then
			width = spec.width + height
		else
			local wide, shown = 0, 0
			for _, text in ipairs({ name, counted, timed }) do
				if text ~= "" then
					wide, shown = wide + U.Width(text, size), shown + 1
				end
			end
			width = shown == 0 and height or math.ceil(wide + TRACKER_GAP * (shown - 1)) + TRACKER_PAD * 2
		end
		frame:SetSize(width, height)
		local square = shape == "bar" and height or 0
		U.At(cell.tex, "TOPLEFT", frame, "TOPLEFT", 0, 0)
		cell.tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", square, 0)
		U.At(part.body, "TOPLEFT", frame, "TOPLEFT", square, 0)
		part.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		local plate = missing and PLATE_MISSING or PLATE
		part.back:SetColorTexture(plate[1], plate[2], plate[3], plate[4])
		for _, text in ipairs({ part.name, part.count, part.time }) do
			text:SetTextHeight(size)
		end
		part.name:SetText(name)
		part.count:SetText(counted)
		part.time:SetText(timed)
		if shape == "bar" then
			part.bar:SetStatusBarTexture(ns.BarTexture(spec.texture) or WHITE)
			part.bar:SetStatusBarColor(r, g, b, 1)
			part.bar:SetValue(fill)
			for _, text in ipairs({ part.name, part.count, part.time }) do
				text:SetTextColor(1, 1, 1, 1)
			end
			local room = spec.width - TRACKER_PAD * 2 - TRACKER_GAP * 2 - U.Width("20", size) - U.Width("10:00", size)
			part.name:SetWidth(math.max(1, math.floor(room)))
			U.At(part.name, "LEFT", part.host, "LEFT", TRACKER_PAD, 0)
			U.At(part.time, "RIGHT", part.host, "RIGHT", -TRACKER_PAD, 0)
			if timed ~= "" then
				U.At(part.count, "RIGHT", part.time, "LEFT", -TRACKER_GAP, 0)
			else
				U.At(part.count, "RIGHT", part.host, "RIGHT", -TRACKER_PAD, 0)
			end
		else
			local before
			for _, text in ipairs({ part.name, part.count, part.time }) do
				text:SetTextColor(r, g, b, 1)
				text:SetWidth(0)
				if text:GetText() ~= "" then
					if before then
						U.At(text, "LEFT", before, "RIGHT", TRACKER_GAP, 0)
					else
						U.At(text, "LEFT", part.host, "LEFT", TRACKER_PAD, 0)
					end
					before = text
				end
			end
		end
		U.At(cell.word, "CENTER", part.body, "CENTER", 0, 0)
		cell.word:SetTextHeight(size)
		anchor = part.body
	end
	if cell.sweep then
		U.Show(cell.sweep, shape == "icon")
		cell.sweep:SetHideCountdownNumbers(not (spec.numbers and shape == "icon"))
		ns.IconCountdownFont(cell, spec.font, cell.sweep)
		if shape == "icon" and left and sample.length and not missing then
			U.Sweep(cell.sweep, sample.length - left, sample.length)
		else
			U.NoSweep(cell.sweep)
		end
	end
	U.FitRim(cell, anchor)
	for _, edge in ipairs(cell.rim) do
		edge:SetShown(low or missing)
	end
	cell.word:SetShown(missing and spec.missing == "word")
	U.Pulse(cell, shape == "icon" and cell.tex or part.back, missing and spec.missing == "pulse")
	cell.width, cell.height = width, height
	return width, height
end

function U.Look()
	local read = ns.Get
	local hex = read("trackers.colour")
	local colour = BLUE
	if type(hex) == "string" and #hex == 8 and hex:find("^%x+$") then
		colour = { tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255 }
	end
	return { shape = read("trackers.shape"), size = read("trackers.size"), width = read("trackers.barWidth"), height = read("trackers.barHeight"),
		fill = read("trackers.barFill"), colour = colour, counts = read("trackers.counts") == true, names = read("trackers.names") == true,
		numbers = read("trackers.numbers") == true, font = read("trackers.numbersFont"), missing = read("trackers.missing"),
		border = read("trackers.iconBorder") ~= false, texture = read("trackers.barTexture") }
end

function U.Spec(look, sample, state, extra)
	local spec = { sample = sample, state = state }
	for key, value in pairs(look) do
		spec[key] = value
	end
	for key, value in pairs(extra or {}) do
		spec[key] = value
	end
	return spec
end

function U.NewDefensives(parent)
	local part = { frame = U.Frame(parent), icons = {} }
	local frame = part.frame
	part.label = U.Str(frame, "GameFontNormalSmall", "LEFT")
	part.label:SetText("Defensives on you")
	part.row = U.Frame(frame)
	for index = 1, #DEFENSIVES do
		local icon = { frame = U.Frame(part.row) }
		icon.tex = U.Tex(icon.frame, "ARTWORK", 0)
		icon.tex:SetAllPoints(icon.frame)
		icon.tex:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		icon.outline = ns.Outline(icon.frame, icon.frame)
		icon.top = U.Frame(icon.frame)
		icon.top:SetAllPoints(icon.frame)
		icon.top:SetFrameLevel(icon.frame:GetFrameLevel() + 2)
		icon.time = U.Str(icon.top, "NumberFontNormal", "CENTER")
		icon.time:SetPoint("CENTER", icon.top, "CENTER", 0, 0)
		icon.name = U.Str(icon.top, "GameFontNormalSmall", "CENTER")
		part.icons[index] = icon
	end
	part.player = U.Frame(frame)
	part.player:SetSize(150, 26)
	part.playerOutline = ns.Outline(part.player, part.player)
	part.playerFill = U.Tex(part.player, "ARTWORK", 0)
	part.playerFill:SetAllPoints(part.player)
	part.playerFill:SetColorTexture(0.12, 0.12, 0.12, 0.9)
	part.playerLabel = U.Str(part.player, "GameFontHighlightSmall", "CENTER")
	part.playerLabel:SetPoint("CENTER", part.player, "CENTER", 0, 0)
	part.playerLabel:SetText("Player frame")
	part.resource = U.Frame(frame)
	part.resource:SetSize(150, 21)
	part.health = U.Box(part.resource, 0, 0, 150, 12, 0.2, 0.78, 0.3, 1)
	part.power = U.Box(part.resource, 0, 12, 150, 9, 0.2, 0.45, 0.9, 1)
	part.resourceLabel = U.Str(part.resource, "GameFontHighlightSmall", "CENTER")
	part.resourceLabel:SetPoint("CENTER", part.resource, "CENTER", 0, 0)
	part.resourceLabel:SetText("Personal resource display")
	part.own = U.Frame(frame)
	part.ownEdges = {}
	for index = 1, 4 do
		part.ownEdges[index] = U.Tex(part.own, "OVERLAY", 0)
		part.ownEdges[index]:SetColorTexture(0.7, 0.7, 0.7, 1)
	end
	part.ownLabel = U.Str(part.own, "GameFontHighlightSmall", "CENTER")
	part.ownLabel:SetPoint("CENTER", part.own, "CENTER", 0, 0)
	part.ownLabel:SetText("Own position")
	return part
end

function U.DrawDefensives(part, root, x, top)
	local read = ns.Get
	local place, caster = read("defensives.place"), read("defensives.caster") == true
	local size, spacing, room = read("defensives.size"), read("defensives.spacing"), 16
	U.At(part.frame, "TOPLEFT", root, "TOPLEFT", x, -top)
	part.label:SetWidth(200)
	U.At(part.label, "TOPLEFT", part.frame, "TOPLEFT", 0, 0)
	local rowWidth = #DEFENSIVES * size + (#DEFENSIVES - 1) * spacing
	part.row:SetSize(rowWidth, size + room)
	U.At(part.row, "TOPLEFT", part.frame, "TOPLEFT", 0, -16)
	for index, sample in ipairs(DEFENSIVES) do
		local icon = part.icons[index]
		icon.frame:SetSize(size, size)
		U.At(icon.frame, "TOPLEFT", part.row, "TOPLEFT", (index - 1) * (size + spacing), 0)
		icon.tex:SetTexture(sample.icon)
		icon.time:SetText(U.Seconds(sample.left))
		icon.name:SetText(sample.name)
		icon.name:SetTextColor(U.Class(sample.class))
		U.At(icon.name, "TOP", icon.frame, "BOTTOM", 0, -1)
		U.Show(icon.name, caster)
	end
	local below = 16 + size + room + 4
	local anchored = place == "player" or place == "resource" or place == "own"
	U.Show(part.row, anchored)
	U.Show(part.player, place == "player")
	U.Show(part.resource, place == "resource")
	U.Show(part.own, place == "own")
	if place == "player" then
		U.At(part.player, "TOPLEFT", part.frame, "TOPLEFT", 0, -below)
	elseif place == "resource" then
		U.At(part.resource, "TOPLEFT", part.frame, "TOPLEFT", 0, -below)
	elseif place == "own" then
		part.own:SetSize(rowWidth, 22)
		U.At(part.own, "TOPLEFT", part.frame, "TOPLEFT", 0, -below)
		local w, h = rowWidth, 22
		local edges = part.ownEdges
		edges[1]:SetSize(w, 1)
		U.At(edges[1], "TOPLEFT", part.own, "TOPLEFT", 0, 0)
		edges[2]:SetSize(w, 1)
		U.At(edges[2], "BOTTOMLEFT", part.own, "BOTTOMLEFT", 0, 0)
		edges[3]:SetSize(1, h)
		U.At(edges[3], "TOPLEFT", part.own, "TOPLEFT", 0, 0)
		edges[4]:SetSize(1, h)
		U.At(edges[4], "TOPRIGHT", part.own, "TOPRIGHT", 0, 0)
	end
	local border = ns.Get("defensives.iconBorder") ~= false
	for _, icon in ipairs(part.icons) do
		ns.SetOutline(icon.outline, border, border)
	end
	local stub = place == "resource" and 21 or place == "own" and 22 or place == "player" and 26 or 0
	part.frame:SetSize(math.max(rowWidth, 150), anchored and (below + stub) or 16)
	return anchored and (below + stub) or 16
end

local SHAPES = { "icon", "bar", "text" }
local SHAPE_LABELS = { icon = "Icon", bar = "Bar", text = "Text" }

local function BuildTracker(stage)
	local s = { root = Root(stage), parts = {}, shapes = {}, cells = {}, captions = {} }
	local root = s.root
	s.trackers = U.Frame(root)
	s.trackerLabel = U.Str(s.trackers, "GameFontNormalSmall", "LEFT")
	s.trackerLabel:SetText("Trackers")
	s.shapeRow = U.Frame(s.trackers)
	for index, shape in ipairs(SHAPES) do
		s.shapes[index] = U.NewCell(s.shapeRow)
		s.captions[index] = U.Str(s.shapeRow, "GameFontHighlightSmall", "CENTER")
		s.captions[index]:SetText(SHAPE_LABELS[shape])
	end
	s.mark = U.Tex(s.shapeRow, "OVERLAY", 0)
	s.row = U.Frame(s.trackers)
	s.tick = U.Tex(s.trackers, "ARTWORK", 0)
	s.tick:SetColorTexture(0.55, 0.55, 0.55, 0.8)
	for index = 1, #TRACKERS do
		s.cells[index] = U.NewCell(s.row)
	end
	s.defensives = U.NewDefensives(root)
	local icon, bar = s.shapes[1], s.shapes[2]
	local map = {
		["trackers.enabled"] = s.trackers, ["trackers.shape"] = s.mark, ["trackers.size"] = icon.frame, ["trackers.barWidth"] = bar.frame,
		["trackers.barHeight"] = bar.frame, ["trackers.barFill"] = bar.parts.bar.body, ["trackers.colour"] = bar.parts.bar.body,
		["trackers.counts"] = icon.count, ["trackers.names"] = bar.parts.bar.name, ["trackers.numbers"] = icon.frame, ["trackers.numbersFont"] = icon.frame,
		["trackers.grow"] = s.row, ["defensives.size"] = s.defensives.row, ["defensives.spacing"] = s.defensives.row,
		["trackers.spacing"] = s.row, ["defensives.enabled"] = s.defensives.frame, ["defensives.place"] = s.defensives.frame,
		["defensives.caster"] = s.defensives.row, ["defensives.iconBorder"] = s.defensives.row, ["trackers.iconBorder"] = icon.frame,
		["trackers.barTexture"] = bar.parts.bar.body,
	}
	for path, region in pairs(map) do
		s.parts[path] = region
	end
	return s
end

local function DrawTracker(s, stage)
	local read = ns.Get
	local only = type(stage.section) == "string" and stage.section or nil
	local showTrackers = read("trackers.enabled") == true and only ~= "defensives"
	local showDefensives = read("defensives.enabled") == true and read("defensives.place") ~= "off" and only ~= "trackers"
	U.Show(s.trackers, showTrackers)
	U.Show(s.defensives.frame, showDefensives)
	local left, tall = PAD, 0
	if showTrackers then
		local look = U.Look()
		local spacing, grow = read("trackers.spacing"), read("trackers.grow")
		U.At(s.trackers, "TOPLEFT", s.root, "TOPLEFT", PAD, -PAD)
		s.trackerLabel:SetWidth(200)
		U.At(s.trackerLabel, "TOPLEFT", s.trackers, "TOPLEFT", 0, 0)
		local x, high, chosen = 0, 0, nil
		for index, shape in ipairs(SHAPES) do
			local cell = s.shapes[index]
			local w, h = U.ApplyCell(cell, U.Spec(look, TRACKERS[1], "fine", { shape = shape }))
			high = math.max(high, h)
			cell.x = x
			s.captions[index]:SetWidth(math.max(w, 36))
			x = x + w + 18
		end
		local caption = 14
		for index, shape in ipairs(SHAPES) do
			local cell = s.shapes[index]
			U.At(cell.frame, "TOPLEFT", s.shapeRow, "TOPLEFT", cell.x, -(caption + (high - cell.height) / 2))
			U.At(s.captions[index], "BOTTOM", cell.frame, "TOP", 0, 2 + (high - cell.height) / 2)
			local on = shape == look.shape
			s.captions[index]:SetTextColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6, 1)
			if on then
				chosen = index
			end
		end
		local shapesWidth = x - 18
		s.shapeRow:SetSize(shapesWidth, caption + high)
		U.At(s.shapeRow, "TOPLEFT", s.trackers, "TOPLEFT", 0, -16)
		local r, g, b = ns.Colour("windows.accent")
		s.mark:SetColorTexture(r, g, b, 1)
		local cell = s.shapes[chosen or 1]
		s.mark:SetSize(math.max(cell.width, 36), 2)
		U.At(s.mark, "TOPLEFT", cell.frame, "BOTTOMLEFT", math.min(0, (cell.width - math.max(cell.width, 36)) / 2), -3)
		local sizes, total, tallest = {}, spacing * (#TRACKERS - 1), 0
		for index, sample in ipairs(TRACKERS) do
			local w, h = U.ApplyCell(s.cells[index], U.Spec(look, sample, "fine"))
			sizes[index] = w
			total, tallest = total + w, math.max(tallest, h)
		end
		local at = grow == "left" and total or 0
		for index = 1, #TRACKERS do
			local item = s.cells[index]
			if grow == "left" then
				at = at - sizes[index]
			end
			U.At(item.frame, "LEFT", s.row, "LEFT", 6 + at, 0)
			at = grow == "left" and at - spacing or at + sizes[index] + spacing
		end
		local rowTop = 16 + caption + high + 14
		s.row:SetSize(total + 12, tallest)
		U.At(s.row, "TOPLEFT", s.trackers, "TOPLEFT", 0, -rowTop)
		s.tick:SetSize(1, tallest + 8)
		local tickX = 6 + (grow == "left" and total or grow == "center" and total / 2 or 0)
		U.At(s.tick, "TOPLEFT", s.row, "TOPLEFT", tickX, 4)
		tall = rowTop + tallest + 4
		local wide = math.max(shapesWidth, total + 12)
		s.trackers:SetSize(wide, tall)
		left = left + wide + 30
	end
	local height = tall
	if showDefensives then
		height = math.max(height, U.DrawDefensives(s.defensives, s.root, left, PAD))
		left = left + math.max(150, #DEFENSIVES * (read("defensives.size") + read("defensives.spacing")))
	end
	U.Finish(s, left - 30 * ((showTrackers and not showDefensives) and 1 or 0) + PAD, PAD * 2 + height)
end

U.Register("mock-tracker", { build = BuildTracker, draw = DrawTracker })

local STATES = { "fine", "low", "missing" }
local STATE_LABELS = { fine = "Fine", low = "Low", missing = "Missing" }

local function BuildStates(stage)
	local s = { root = Root(stage), parts = {}, cells = {}, labels = {} }
	for index, state in ipairs(STATES) do
		s.cells[index] = U.NewCell(s.root)
		s.labels[index] = U.Str(s.root, "GameFontNormalSmall", "CENTER")
		s.labels[index]:SetText(STATE_LABELS[state])
	end
	s.parts["trackers.low"] = s.cells[2].frame
	s.parts["trackers.lowTime"] = s.cells[2].frame
	s.parts["trackers.missing"] = s.cells[3].frame
	return s
end

local function DrawStates(s)
	local read = ns.Get
	local look = U.Look()
	local sample = TRACKERS[1]
	local low, lowTime = read("trackers.low"), read("trackers.lowTime")
	local extra = { fine = {}, low = { count = low > 0 and low or sample.count, left = lowTime > 0 and lowTime or sample.left }, missing = {} }
	local sizes, tallest, gap = {}, 0, 28
	local total = gap * (#STATES - 1)
	for index, state in ipairs(STATES) do
		local w, h = U.ApplyCell(s.cells[index], U.Spec(look, sample, state, extra[state]))
		sizes[index] = w
		total, tallest = total + w, math.max(tallest, h)
	end
	local x = PAD
	for index = 1, #STATES do
		local cell = s.cells[index]
		U.At(cell.frame, "TOPLEFT", s.root, "TOPLEFT", x, -(PAD + 18 + (tallest - cell.height) / 2))
		s.labels[index]:SetWidth(math.max(sizes[index], 60))
		U.At(s.labels[index], "BOTTOM", cell.frame, "TOP", 0, 4)
		x = x + sizes[index] + gap
	end
	U.Finish(s, total + 2 * PAD, PAD * 2 + 18 + tallest)
end

U.Register("mock-tracker-states", { build = BuildStates, draw = DrawStates })

local PROC = { long = 204.8, short = 102.4, arc = "Interface\\AddOns\\FlatUI\\Media\\ProcArc.tga", atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",
	scene = 410, height = 204 }

function U.ProcColour()
	local hex = ns.Get("trackers.procColour")
	if type(hex) == "string" and #hex == 8 and hex:find("^%x+$") then
		return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
	end
	return 1, 0.82, 0
end

local function BuildProc(stage)
	local s = { root = Root(stage), parts = {} }
	s.scene = U.Frame(s.root)
	s.scene:SetSize(PROC.scene, PROC.height)
	U.At(s.scene, "TOPLEFT", s.root, "TOPLEFT", PAD, -PAD)
	pcall(s.scene.SetClipsChildren, s.scene, true)
	s.back = U.Tex(s.scene, "BACKGROUND", 0)
	s.back:SetAllPoints(s.scene)
	s.back:SetColorTexture(0.05, 0.05, 0.06, 1)
	s.holder = U.Frame(s.scene)
	s.holder:SetSize(PROC.long, PROC.long)
	s.pieces = {}
	for index, side in ipairs({ "left", "right" }) do
		local piece = U.Frame(s.holder)
		piece.tex = U.Tex(piece, "ARTWORK", 0)
		piece.tex:SetAllPoints(piece)
		piece.tex:SetTexture(PROC.arc)
		if side == "right" then
			piece.tex:SetTexCoord(1, 0, 0, 1)
		end
		s.pieces[index] = piece
	end
	s.character = U.Frame(s.scene)
	s.character:SetSize(56, 84)
	U.At(s.character, "CENTER", s.scene, "CENTER", 0, 0)
	s.characterOutline = ns.Outline(s.character, s.character)
	s.portrait = U.Tex(s.character, "ARTWORK", 0)
	s.portrait:SetAllPoints(s.character)
	s.portrait:SetColorTexture(0.18, 0.18, 0.2, 1)
	if type(SetPortraitTexture) == "function" then
		pcall(SetPortraitTexture, s.portrait, "player")
	end
	s.button = U.Frame(s.root)
	s.button:SetSize(44, 44)
	s.buttonIcon = U.Tex(s.button, "ARTWORK", 0)
	s.buttonIcon:SetAllPoints(s.button)
	s.buttonIcon:SetTexture(ICONS .. "Spell_Nature_LightningShield")
	s.buttonIcon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	s.buttonOutline = ns.Outline(s.button, s.button)
	s.glow = U.Frame(s.button)
	s.glow:SetSize(44 * 1.4, 44 * 1.4)
	U.At(s.glow, "CENTER", s.button, "CENTER", 0, 0)
	s.glowTex = U.Tex(s.glow, "BACKGROUND", 0)
	s.glowTex:SetAllPoints(s.glow)
	s.glowFile = false
	if C_Texture and C_Texture.GetAtlasInfo then
		local asked, info = pcall(C_Texture.GetAtlasInfo, PROC.atlas)
		s.glowFile = asked and info ~= nil
		if s.glowFile and type(info) == "table" then
			s.glowRect = { info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord }
		end
	end
	local made, soft = pcall(ns.ProcGlowSoft, s.button, s.button)
	s.soft = made and type(soft) == "table" and soft or nil
	s.buttonLabel = U.Str(s.root, "GameFontHighlightSmall", "CENTER")
	s.buttonLabel:SetText("Action button")
	s.parts["trackers.art"] = s.pieces[1]
	s.parts["trackers.artSize"] = s.pieces[1]
	s.parts["trackers.artAlpha"] = s.holder
	s.parts["trackers.artY"] = s.holder
	s.parts["trackers.procColour"] = s.pieces[1]
	s.parts["trackers.glow"] = s.glow
	s.parts["trackers.glowStyle"] = s.glow
	return s
end

local function DrawProc(s)
	local read = ns.Get
	local r, g, b = U.ProcColour()
	local art, glow = read("trackers.art") == true, read("trackers.glow") == true
	local scale = read("trackers.artSize") / 100
	U.At(s.holder, "CENTER", s.scene, "CENTER", 0, read("trackers.artY"))
	s.holder:SetAlpha(read("trackers.artAlpha") / 100)
	local w, h = PROC.short * scale, PROC.long * scale
	U.At(s.pieces[1], "RIGHT", s.holder, "LEFT", 0, 0)
	U.At(s.pieces[2], "LEFT", s.holder, "RIGHT", 0, 0)
	for _, piece in ipairs(s.pieces) do
		piece:SetSize(w, h)
		piece.tex:SetVertexColor(r, g, b)
		U.Show(piece, art)
	end
	local x = PAD + PROC.scene + 40
	U.At(s.button, "TOPLEFT", s.root, "TOPLEFT", x, -(PAD + 70))
	s.buttonLabel:SetWidth(120)
	U.At(s.buttonLabel, "TOP", s.button, "BOTTOM", 0, -14)
	U.Show(s.glow, glow)
	local soft = s.soft ~= nil and (read("trackers.glowStyle") ~= "game" or not s.glowFile)
	s.glowTex:SetShown(not soft)
	if s.soft then
		U.Show(s.soft.frame, glow and soft)
		ns.ProcGlowTint(s.soft, r, g, b)
		s.soft.frame:SetAlpha(s.soft.high)
	end
	if s.glowFile then
		pcall(s.glowTex.SetAtlas, s.glowTex, PROC.atlas)
		local rect = s.glowRect
		if rect and type(rect[1]) == "number" and type(rect[2]) == "number" and type(rect[3]) == "number" and type(rect[4]) == "number" then
			s.glowTex:SetTexCoord(rect[1], rect[1] + (rect[2] - rect[1]) * 0.2, rect[3], rect[3] + (rect[4] - rect[3]) / 6)
		else
			s.glowTex:SetTexCoord(0, 0.2, 0, 1 / 6)
		end
		s.glowTex:SetVertexColor(1, 1, 1, 1)
	else
		s.glowTex:SetColorTexture(r, g, b, 0.35)
	end
	if glow then
		ns.SetOutlineColour(s.buttonOutline, r, g, b)
	else
		ns.SetOutlineColour(s.buttonOutline, nil, nil, nil)
	end
	U.Finish(s, x + 44 * 1.4 + 20, PROC.height + 2 * PAD)
end

U.Register("mock-proc", { build = BuildProc, draw = DrawProc })

local MOST_ICONS = #SPELLS + #TRINKETS

function U.NewIcon(parent)
	local icon = ns.IconNew(parent)
	if not icon then
		return nil
	end
	local fs = icon.cooldown.GetCountdownFontString and icon.cooldown:GetCountdownFontString()
	if fs and fs.GetFont then
		local ok, file, size, flags = pcall(fs.GetFont, fs)
		if ok and type(file) == "string" and type(size) == "number" then
			icon.gameFont = { file, size, flags or "" }
		end
	end
	icon.top = U.Frame(icon.frame)
	icon.top:SetAllPoints(icon.frame)
	icon.top:SetFrameLevel(icon.cooldown:GetFrameLevel() + 1)
	icon.count = U.Str(icon.top, "NumberFontNormalSmall", "RIGHT")
	icon.count:SetPoint("BOTTOMRIGHT", icon.top, "BOTTOMRIGHT", -2, 2)
	icon.bind = U.Str(icon.top, "NumberFontNormalSmallGray", "RIGHT")
	icon.bind:SetPoint("TOPRIGHT", icon.top, "TOPRIGHT", -2, -2)
	icon.flashTex = U.Tex(icon.top, "OVERLAY", 0)
	icon.flashTex:SetAllPoints(icon.frame)
	icon.flashTex:SetColorTexture(1, 1, 1, 0.45)
	icon.flashTex:Hide()
	return icon
end

local function BuildCooldowns(stage)
	local s = { root = Root(stage), parts = {}, icons = {} }
	s.holder = U.Frame(s.root)
	s.holder:SetSize(1, 1)
	s.tick = U.Tex(s.root, "ARTWORK", 0)
	s.tick:SetColorTexture(0.55, 0.55, 0.55, 0.8)
	s.hair = U.Tex(s.root, "ARTWORK", 0)
	s.hair:SetColorTexture(0.55, 0.55, 0.55, 0.5)
	for index = 1, MOST_ICONS do
		s.icons[index] = U.NewIcon(s.holder)
	end
	s.manager = U.Frame(s.root)
	s.managerIcon = U.NewIcon(s.manager)
	s.managerGame = U.Frame(s.manager)
	s.managerEdges = {}
	for index = 1, 4 do
		s.managerEdges[index] = U.Tex(s.managerGame, "OVERLAY", 0)
		s.managerEdges[index]:SetColorTexture(0.55, 0.5, 0.4, 1)
	end
	s.managerLabel = U.Str(s.manager, "GameFontHighlightSmall", "CENTER")
	s.managerCaption = U.Str(s.manager, "GameFontNormalSmall", "CENTER")
	s.managerCaption:SetText("Cooldown manager")
	local first = s.icons[1] and s.icons[1].frame or s.holder
	local second = s.icons[2] and s.icons[2].frame or first
	local cooling = { numbers = true, numbersFont = true, sweep = true, sweepAlpha = true, dim = true, dimDesat = true, dimDarkness = true, coolAlpha = true }
	for _, key in ipairs({ "trinkets", "size", "spacing", "perRow", "grow", "rows", "crop", "border", "numbers", "dim", "dimDesat", "dimDarkness", "coolAlpha",
		"readyAlpha", "idleAlpha", "borderState", "readyColour", "coolingColour", "flash", "numbersFont", "sweep", "sweepAlpha", "countSize", "keybind",
		"keybindSize" }) do
		s.parts["cooldowns." .. key] = cooling[key] and second or first
	end
	s.parts["cooldowns.enabled"] = s.holder
	s.parts["cooldowns.manager"] = s.manager
	return s
end

function U.DrawSpell(icon, sample, look, hide)
	if not icon then
		return
	end
	local cooling = sample[2] ~= nil
	local frame, texture, cooldown = icon.frame, icon.texture, icon.cooldown
	frame:SetShown(not hide)
	if hide then
		return
	end
	frame:SetSize(look.size, look.size)
	texture:SetTexture(ICONS .. sample[1])
	local crop = look.crop / 100
	texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	if look.dim then
		local level = cooling and 1 - look.darkness / 100 or 1
		texture:SetDesaturated(cooling and look.desat)
		texture:SetVertexColor(level, level, level)
	else
		texture:SetDesaturated(false)
		texture:SetVertexColor(1, 1, 1)
	end
	frame:SetAlpha(cooling and look.coolAlpha / 100 or look.readyAlpha / 100)
	ns.SetOutline(icon.outline, look.border, look.border)
	if look.border and look.borderState then
		ns.SetOutlineColour(icon.outline, ns.Colour("cooldowns." .. (cooling and "coolingColour" or "readyColour")))
	else
		ns.SetOutlineColour(icon.outline, nil, nil, nil)
	end
	cooldown:SetHideCountdownNumbers(not look.numbers)
	cooldown:SetDrawSwipe(look.sweep)
	cooldown:SetSwipeColor(0, 0, 0, look.sweepAlpha / 100)
	local font = NUMBER_FONTS[look.numbersFont]
	if font and cooldown.SetCountdownFont then
		pcall(cooldown.SetCountdownFont, cooldown, font)
	elseif not font and icon.gameFont and cooldown.GetCountdownFontString then
		local fs = cooldown:GetCountdownFontString()
		if fs and fs.SetFont then
			pcall(fs.SetFont, fs, icon.gameFont[1], icon.gameFont[2], icon.gameFont[3])
		end
	end
	if cooling then
		U.Sweep(cooldown, sample[3] - sample[2], sample[3])
	else
		U.NoSweep(cooldown)
	end
	icon.count:SetText(sample[4] and ("%d"):format(sample[4]) or "")
	ns.TextStyle(icon.count, { percent = look.countSize })
	icon.bind:SetText(look.keybind and sample[5] or "")
	ns.TextStyle(icon.bind, { percent = look.keybindSize })
	icon.flashTex:SetShown(look.flash and sample == look.flashSample)
end

local function DrawCooldowns(s)
	local read = ns.Get
	local on = read("cooldowns.enabled") == true
	local look = { size = read("cooldowns.size"), crop = read("cooldowns.crop"), dim = read("cooldowns.dim") == true, desat = read("cooldowns.dimDesat") == true,
		darkness = read("cooldowns.dimDarkness"), coolAlpha = read("cooldowns.coolAlpha"), readyAlpha = read("cooldowns.readyAlpha"),
		border = read("cooldowns.border") == true, borderState = read("cooldowns.borderState") == true, numbers = read("cooldowns.numbers") == true,
		sweep = read("cooldowns.sweep") == true, sweepAlpha = read("cooldowns.sweepAlpha"), numbersFont = read("cooldowns.numbersFont"),
		countSize = read("cooldowns.countSize"), keybind = read("cooldowns.keybind") == true, keybindSize = read("cooldowns.keybindSize"),
		flash = read("cooldowns.flash") == true, flashSample = SPELLS[7] }
	local size, spacing, perRow = look.size, read("cooldowns.spacing"), read("cooldowns.perRow")
	local grow, above = read("cooldowns.grow"), read("cooldowns.rows") == "up"
	local samples = {}
	for _, sample in ipairs(SPELLS) do
		samples[#samples + 1] = sample
	end
	if read("cooldowns.trinkets") == true then
		for _, sample in ipairs(TRINKETS) do
			samples[#samples + 1] = sample
		end
	end
	local step = size + spacing
	local rows = math.ceil(#samples / perRow)
	local widest = math.min(perRow, #samples) * size + (math.min(perRow, #samples) - 1) * spacing
	local blockHeight = rows * step - spacing
	U.Show(s.holder, on)
	U.Show(s.tick, on)
	U.Show(s.hair, on)
	U.Show(s.manager, on)
	local tickX = U.Tick(grow, widest)
	local hairY = PAD + (above and blockHeight or 0)
	U.At(s.holder, "CENTER", s.root, "TOPLEFT", tickX, -hairY)
	s.tick:SetSize(1, blockHeight + 8)
	U.At(s.tick, "TOPLEFT", s.root, "TOPLEFT", tickX, -(PAD - 4))
	s.hair:SetSize(widest + 12, 1)
	U.At(s.hair, "TOPLEFT", s.root, "TOPLEFT", PAD, -hairY)
	s.holder:SetAlpha(read("cooldowns.idleAlpha") / 100)
	for index = 1, MOST_ICONS do
		local icon, sample = s.icons[index], samples[index]
		U.DrawSpell(icon, sample or SPELLS[1], look, not on or sample == nil)
		if icon and sample then
			local row, column = math.floor((index - 1) / perRow), (index - 1) % perRow
			local inRow = math.min(perRow, #samples - row * perRow)
			local x
			if grow == "right" then
				x = column * step
			elseif grow == "left" then
				x = -size - column * step
			else
				x = -(inRow * size + (inRow - 1) * spacing) / 2 + column * step
			end
			icon.frame:ClearAllPoints()
			if above then
				icon.frame:SetPoint("BOTTOMLEFT", s.holder, "CENTER", x, row * step)
			else
				icon.frame:SetPoint("TOPLEFT", s.holder, "CENTER", x, -row * step)
			end
		end
	end
	local managerOn = read("cooldowns.manager") == true
	local mx = PAD + 6 + widest + 30
	s.manager:SetSize(80, 80)
	U.At(s.manager, "TOPLEFT", s.root, "TOPLEFT", mx, -PAD)
	s.managerCaption:SetWidth(100)
	U.At(s.managerCaption, "TOPLEFT", s.manager, "TOPLEFT", -10, 0)
	if s.managerIcon then
		U.DrawSpell(s.managerIcon, SPELLS[2], look, false)
		s.managerIcon.frame:SetSize(36, 36)
		U.At(s.managerIcon.frame, "TOPLEFT", s.manager, "TOPLEFT", 20, -20)
		s.managerIcon.frame:SetShown(managerOn)
	end
	U.Show(s.managerGame, not managerOn)
	s.managerGame:SetSize(36, 36)
	U.At(s.managerGame, "TOPLEFT", s.manager, "TOPLEFT", 20, -20)
	local edges = s.managerEdges
	for index = 1, 4 do
		local horizontal = index <= 2
		edges[index]:SetSize(horizontal and 36 or 4, horizontal and 4 or 36)
	end
	U.At(edges[1], "TOPLEFT", s.managerGame, "TOPLEFT", 0, 0)
	U.At(edges[2], "BOTTOMLEFT", s.managerGame, "BOTTOMLEFT", 0, 0)
	U.At(edges[3], "TOPLEFT", s.managerGame, "TOPLEFT", 0, 0)
	U.At(edges[4], "TOPRIGHT", s.managerGame, "TOPRIGHT", 0, 0)
	s.managerLabel:SetWidth(100)
	s.managerLabel:SetText(managerOn and "Flat UI" or "Game look")
	U.At(s.managerLabel, "TOPLEFT", s.manager, "TOPLEFT", -10, -60)
	U.Finish(s, on and (mx + 90) or 2 * PAD + 1, on and (2 * PAD + math.max(blockHeight + 8, 80)) or 2 * PAD + 1)
end

U.Register("mock-cooldown-row", { build = BuildCooldowns, draw = DrawCooldowns })

local MEMBERS = {
	{ "Bren", "WARRIOR", { 1, "Ability_Kick" }, { 2, "Ability_Warrior_ShieldWall" }, { 2, "Spell_Nature_Regeneration" }, { 6, "Spell_Shadow_ShadowWard" },
		{ 3, "Spell_Holy_SealOfProtection" }, { 5, "Spell_Holy_SealOfValor" }, { 9, "Ability_Warrior_RallyingCry" } },
	{ "Tomas", "PALADIN", { 1, "Ability_Kick" }, { 2, "Spell_Holy_DivineIntervention" }, { 2, "Ability_Warrior_ShieldWall" }, { 6, "Spell_Holy_SealOfProtection" },
		{ 3, "Spell_Holy_PainSupression" }, { 5, "Spell_Holy_SealOfValor" }, { 9, "Spell_Holy_Heal" } },
	{ "Mira", "MAGE", { 1, "Spell_Frost_IceShock" }, { 2, "Spell_Frost_Frost" }, { 2, "Spell_Arcane_Blink" }, { 6, "Spell_Frost_Frost" },
		{ 3, "Spell_Holy_PowerWordShield" }, { 5, "Spell_Arcane_Blink" }, { 9, "Spell_Nature_Bloodlust" } },
	{ "Alari", "PRIEST", { 1, "Spell_Shadow_ShadowWard" }, { 2, "Spell_Holy_PainSupression" }, { 2, "Spell_Holy_PowerWordShield" }, { 6, "Spell_Holy_DivineIntervention" },
		{ 3, "Spell_Holy_PainSupression" }, { 5, "Spell_Holy_WordFortitude" }, { 9, "Spell_Holy_Heal" } },
	{ "Leaf", "DRUID", { 1, "Ability_Druid_Bash" }, { 2, "Spell_Nature_Regeneration" }, { 2, "Ability_Druid_Bash" }, { 6, "Spell_Nature_LightningShield" },
		{ 3, "Spell_Nature_Regeneration" }, { 5, "Spell_Nature_Bloodlust" }, { 9, "Spell_Nature_Bloodlust" } },
}
local YOU = { "You", "SHAMAN", { 1, "Ability_Kick" }, { 2, "Spell_Nature_LightningShield" }, { 2, "Spell_Holy_SealOfProtection" }, { 6, "Spell_Shadow_ShadowWard" },
	{ 3, "Spell_Holy_PowerWordShield" }, { 5, "Spell_Holy_SealOfValor" }, { 9, "Spell_Nature_Bloodlust" } }
local PARTY_SWITCH = { [1] = { "interrupts", 1 }, [2] = { "defensives", 2 }, [6] = { "defensives", 2 }, [3] = { "externals", 3 }, [5] = { "breaks", 4 }, [9] = { "group", 5 } }
local PARTY_GAP, PARTY_BELOW, PARTY_SPACING = 4, -1, 2
local FRAME_W, FRAME_H, FRAME_STEP = 120, 28, 6

function U.PartyItems(member, count)
	local list = {}
	for index = 3, #member do
		local ability = member[index]
		local switch = PARTY_SWITCH[ability[1]]
		if switch and ns.Get("partycd." .. switch[1]) == true then
			list[#list + 1] = { kind = ability[1], icon = ability[2], rank = switch[2], order = index }
		end
	end
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.order < b.order
	end)
	local items = {}
	for index = 1, math.min(#list, count) do
		items[index] = list[index]
	end
	return items
end

function U.PaintItems(row, items, size, direction)
	local shown = {}
	for index, icon in ipairs(row.icons) do
		local item = items[index]
		if icon and item then
			icon.texture:SetTexture(ICONS .. item.icon)
			local border = ns.Get("partycd.iconBorder") ~= false
			ns.SetOutline(icon.outline, border, border)
			ns.SetOutlineColour(icon.outline, ns.KindColour(item.kind))
			icon.cooldown:SetHideCountdownNumbers(ns.Get("partycd.seconds") ~= true)
			ns.IconCountdownFont(icon, ns.Get("partycd.numbersFont"))
			icon.frame:Show()
			if index % 2 == 0 then
				U.NoSweep(icon.cooldown)
			else
				U.Sweep(icon.cooldown, 8 + index, 60)
			end
			shown[#shown + 1] = icon
		elseif icon then
			icon.frame:Hide()
		end
	end
	local width = ns.IconLayout(shown, row.holder, size, PARTY_SPACING, direction)
	row.holder:SetSize(math.max(width, 1), size)
	return width
end

function U.NewRow(parent, most)
	local row = { holder = U.Frame(parent), icons = {} }
	for _ = 1, most do
		row.icons[#row.icons + 1] = ns.IconNew(row.holder) or nil
	end
	return row
end

local function BuildParty(stage)
	local s = { root = Root(stage), parts = {}, members = {} }
	for index, member in ipairs(MEMBERS) do
		local block = { frame = U.Frame(s.root) }
		block.frame:SetSize(FRAME_W, FRAME_H)
		block.outline = ns.Outline(block.frame, block.frame)
		block.health = U.Tex(block.frame, "ARTWORK", 0)
		block.health:SetPoint("TOPLEFT", block.frame, "TOPLEFT", 0, 0)
		block.health:SetPoint("BOTTOMRIGHT", block.frame, "BOTTOMRIGHT", 0, 0)
		local r, g, b = U.Class(member[2])
		block.health:SetColorTexture(r * 0.45, g * 0.45, b * 0.45, 1)
		block.name = U.Str(block.frame, "GameFontHighlightSmall", "LEFT")
		block.name:SetPoint("LEFT", block.frame, "LEFT", 6, 0)
		block.name:SetText(member[1])
		block.name:SetTextColor(r, g, b, 1)
		block.row = U.NewRow(s.root, 8)
		s.members[index] = block
	end
	s.own = U.NewRow(s.root, 8)
	for _, path in ipairs({ "partycd.enabled", "partycd.side", "partycd.ownRow", "partycd.count", "partycd.size", "partycd.interrupts", "partycd.defensives",
		"partycd.externals", "partycd.breaks", "partycd.group", "partycd.seconds", "partycd.numbersFont", "partycd.iconBorder" }) do
		s.parts[path] = s.members[1].row.holder
	end
	s.parts["partycd.enabled"] = s.root
	return s
end

local function DrawParty(s)
	local read = ns.Get
	local on = read("partycd.enabled") == true
	local side, size, count, own = read("partycd.side"), read("partycd.size"), read("partycd.count"), read("partycd.ownRow") == true
	local rowWidth = count * size + (count - 1) * PARTY_SPACING
	local direction = side == "left" and "left" or "right"
	local left = PAD + (side == "left" and rowWidth + PARTY_GAP or 0)
	local top = PAD + (own and (size + PARTY_SPACING + 2) or 0)
	local step = FRAME_H + FRAME_STEP + (side == "below" and size + 1 or 0)
	for index, block in ipairs(s.members) do
		local frame = block.frame
		U.Show(frame, on)
		U.At(frame, "TOPLEFT", s.root, "TOPLEFT", left, -(top + (index - 1) * step))
		local row = block.row
		local items = on and U.PartyItems(MEMBERS[index], count) or {}
		U.Show(row.holder, on)
		U.PaintItems(row, items, size, direction)
		row.holder:ClearAllPoints()
		if side == "left" then
			row.holder:SetPoint("RIGHT", frame, "LEFT", -PARTY_GAP, 0)
		elseif side == "below" then
			row.holder:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, PARTY_BELOW)
		else
			row.holder:SetPoint("LEFT", frame, "RIGHT", PARTY_GAP, 0)
		end
	end
	local first = s.members[1]
	U.Show(s.own.holder, on and own)
	U.PaintItems(s.own, on and own and U.PartyItems(YOU, count) or {}, size, direction)
	s.own.holder:ClearAllPoints()
	if side == "below" then
		s.own.holder:SetPoint("BOTTOMLEFT", first.frame, "TOPLEFT", 0, PARTY_SPACING)
	elseif side == "left" then
		s.own.holder:SetPoint("BOTTOMRIGHT", first.row.holder, "TOPRIGHT", 0, PARTY_SPACING)
	else
		s.own.holder:SetPoint("BOTTOMLEFT", first.row.holder, "TOPLEFT", 0, PARTY_SPACING)
	end
	local width = left + FRAME_W + (side == "right" and PARTY_GAP + rowWidth or 0) + PAD
	local height = top + #MEMBERS * step - FRAME_STEP + PAD
	U.Finish(s, on and width or 2 * PAD + 1, on and height or 2 * PAD + 1)
end

U.Register("mock-party-cooldowns", { build = BuildParty, draw = DrawParty })

local ENEMY = {
	{ switch = "interrupts", kind = 1, icon = "Ability_Kick", left = 7, length = 24 },
	{ switch = "interrupts", kind = 1, icon = "Spell_Frost_IceShock", ended = true },
	{ switch = "wards", kind = 6, icon = "Spell_Holy_DivineIntervention", left = 12, length = 30 },
	{ switch = "breaks", kind = 5, icon = "Spell_Holy_SealOfValor", left = 30, length = 45 },
	{ switch = "defensives", kind = 2, icon = "Ability_Rogue_Evasion", left = 18, length = 60 },
	{ switch = "mobility", kind = 7, icon = "Ability_Rogue_Sprint", left = 9, length = 15 },
	{ switch = "offensive", kind = 8, icon = "Spell_Nature_Bloodlust", left = 90, length = 180 },
}
local ENEMY_ARENA = { icon = "INV_Jewelry_TrinketPVP_01", left = 60, length = 120 }
local ENEMY_SPACING, ENEMY_BELOW, ENEMY_BAR_UP, ENEMY_PLATE_MOST, ENEMY_BAR_MOST = 2, 1, 4, 4, 8
local PLATE_W, PLATE_H, TARGET_W, TARGET_H = 110, 12, 150, 36
local PLATE_NAME, ENEMY_SIDE = 18, 6

local function BuildEnemy(stage)
	local s = { root = Root(stage), parts = {} }
	s.plate = U.Frame(s.root)
	s.plate:SetSize(PLATE_W, PLATE_H)
	s.plateOutline = ns.SetOutlineArea(ns.Outline(s.plate, s.plate), "nameplates")
	s.plateFill = U.Tex(s.plate, "ARTWORK", 0)
	s.plateFill:SetAllPoints(s.plate)
	s.plateFill:SetColorTexture(0.77, 0.23, 0.23, 1)
	s.plateName = U.Str(s.plate, "GameFontHighlightSmall", "CENTER")
	s.plateName:SetText("Veyra")
	s.plateName:SetTextColor(U.Class("ROGUE"))
	s.plateName:SetWidth(PLATE_W)
	U.At(s.plateName, "BOTTOM", s.plate, "TOP", 0, 3)
	s.plateRow = U.NewRow(s.root, ENEMY_PLATE_MOST)
	s.target = U.Frame(s.root)
	s.target:SetSize(TARGET_W, TARGET_H)
	s.targetOutline = ns.Outline(s.target, s.target)
	s.targetFill = U.Tex(s.target, "ARTWORK", 0)
	s.targetFill:SetAllPoints(s.target)
	s.targetFill:SetColorTexture(0.12, 0.12, 0.12, 0.9)
	s.targetName = U.Str(s.target, "GameFontHighlightSmall", "CENTER")
	s.targetName:SetPoint("CENTER", s.target, "CENTER", 0, 0)
	s.targetName:SetText("Target")
	s.barRow = U.NewRow(s.root, ENEMY_BAR_MOST + 1)
	for index, row in ipairs({ s.plateRow, s.barRow }) do
		for _, icon in ipairs(row.icons) do
			icon.flashTex = U.Tex(icon.frame, "OVERLAY", 0)
			icon.flashTex:SetAllPoints(icon.frame)
			icon.flashTex:SetColorTexture(1, 1, 1, 0.45)
			icon.flashTex:Hide()
		end
	end
	for _, path in ipairs({ "enemycd.interrupts", "enemycd.defensives", "enemycd.breaks", "enemycd.wards", "enemycd.mobility", "enemycd.offensive",
		"enemycd.seconds", "enemycd.numbersFont", "enemycd.kindBorder", "enemycd.size", "enemycd.flash", "enemycd.iconBorder" }) do
		s.parts[path] = s.plateRow.holder
	end
	s.parts["enemycd.enabled"] = s.root
	s.parts["enemycd.place"] = s.barRow.holder
	s.parts["enemycd.platePlace"] = s.plateRow.holder
	s.parts["enemycd.arenaBreak"] = s.barRow.holder
	return s
end

function U.EnemyItems(most)
	local read = ns.Get
	local items = {}
	for _, sample in ipairs(ENEMY) do
		if read("enemycd." .. sample.switch) == true and (not sample.ended or read("enemycd.flash") == true) then
			items[#items + 1] = sample
		end
	end
	if #items > most then
		for index = #items, 1, -1 do
			if items[index].ended then
				table.remove(items, index)
			end
		end
	end
	local cut = {}
	for index = 1, math.min(#items, most) do
		cut[index] = items[index]
	end
	return cut
end

function U.PaintEnemy(row, items, size, direction)
	local read = ns.Get
	local shown = {}
	for index, icon in ipairs(row.icons) do
		local item = items[index]
		if icon and item then
			icon.texture:SetTexture(ICONS .. item.icon)
			local border = read("enemycd.iconBorder") ~= false
			ns.SetOutline(icon.outline, border, border)
			if item.kind and read("enemycd.kindBorder") == true then
				ns.SetOutlineColour(icon.outline, ns.KindColour(item.kind))
			else
				ns.SetOutlineColour(icon.outline, nil, nil, nil)
			end
			icon.cooldown:SetHideCountdownNumbers(read("enemycd.seconds") ~= true)
			ns.IconCountdownFont(icon, read("enemycd.numbersFont"))
			if item.ended then
				U.NoSweep(icon.cooldown)
				icon.texture:SetDesaturated(false)
			else
				U.Sweep(icon.cooldown, item.length - item.left, item.length)
			end
			icon.flashTex:SetShown(item.ended == true and read("enemycd.flash") == true)
			icon.frame:Show()
			shown[#shown + 1] = icon
		elseif icon then
			icon.frame:Hide()
			icon.flashTex:Hide()
		end
	end
	local width = ns.IconLayout(shown, row.holder, size, ENEMY_SPACING, direction or "center")
	row.holder:SetSize(math.max(width, 1), size)
	return width
end

function U.EnemyPlate(platePlace, size)
	local rowW = ENEMY_PLATE_MOST * size + (ENEMY_PLATE_MOST - 1) * ENEMY_SPACING
	if platePlace == "right" or platePlace == "left" then
		local top = math.max(PLATE_NAME, size / 2 - PLATE_H / 2)
		local height = top + math.max(PLATE_H, PLATE_H / 2 + size / 2)
		local width = PLATE_W + ENEMY_SIDE + rowW
		if platePlace == "right" then
			return width, height, 0, top, { "LEFT", "RIGHT", ENEMY_SIDE, 0, "right" }
		end
		return width, height, rowW + ENEMY_SIDE, top, { "RIGHT", "LEFT", -ENEMY_SIDE, 0, "left" }
	end
	local width = math.max(PLATE_W, rowW)
	local left = (width - PLATE_W) / 2
	if platePlace == "above" then
		return width, size + PLATE_NAME + PLATE_H, left, size + PLATE_NAME, { "BOTTOM", "TOP", 0, PLATE_NAME, "center" }
	end
	return width, PLATE_NAME + PLATE_H + ENEMY_BELOW + size, left, PLATE_NAME, { "TOP", "BOTTOM", 0, -ENEMY_BELOW, "center" }
end

local function DrawEnemy(s)
	local read = ns.Get
	local on = read("enemycd.enabled") == true
	local place, size = read("enemycd.place"), read("enemycd.size")
	local plates, bars = on and place ~= "bars", on and place ~= "plates"
	local barRowWidth = (ENEMY_BAR_MOST + 1) * size + ENEMY_BAR_MOST * ENEMY_SPACING
	local plateW, plateH, plateLeft, plateTop, hang = U.EnemyPlate(read("enemycd.platePlace"), size)
	U.Show(s.plate, plates)
	U.Show(s.plateRow.holder, plates)
	U.Show(s.target, bars)
	U.Show(s.barRow.holder, bars)
	U.At(s.plate, "TOPLEFT", s.root, "TOPLEFT", PAD + plateLeft, -(PAD + plateTop))
	local plateItems, barItems = plates and U.EnemyItems(ENEMY_PLATE_MOST) or {}, bars and U.EnemyItems(ENEMY_BAR_MOST) or {}
	U.PaintEnemy(s.plateRow, plateItems, size, hang[5])
	s.plateRow.holder:ClearAllPoints()
	s.plateRow.holder:SetPoint(hang[1], s.plate, hang[2], hang[3], hang[4])
	local barLeft = PAD + (plates and plateW + 40 or 0)
	local barTop = PAD + size + ENEMY_BAR_UP
	U.At(s.target, "TOPLEFT", s.root, "TOPLEFT", barLeft, -barTop)
	if bars and read("enemycd.arenaBreak") == true then
		barItems[#barItems + 1] = ENEMY_ARENA
	end
	U.PaintEnemy(s.barRow, barItems, size)
	s.barRow.holder:ClearAllPoints()
	s.barRow.holder:SetPoint("TOPLEFT", s.target, "TOPLEFT", 0, size + ENEMY_BAR_UP)
	local width = PAD * 2 + (plates and plateW or 0) + (plates and bars and 40 or 0) + (bars and math.max(TARGET_W, barRowWidth) or 0)
	local height = PAD * 2 + math.max(plates and plateH or 0, bars and (size + ENEMY_BAR_UP + TARGET_H) or 0)
	U.Finish(s, on and width or 2 * PAD + 1, on and height or 2 * PAD + 1)
end

U.Register("mock-enemy-cooldowns", { build = BuildEnemy, draw = DrawEnemy })
