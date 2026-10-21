local _, ns = ...

-- The nameplate drawings of Flat UI setup: mock-nameplate, mock-nameplate-cast, mock-nameplate-auras, mock-nameplate-marks and mock-nameplate-stack.
-- A drawing is { build(stage), draw(stage), parts = { [path] = region } }. build makes the frames of the drawing once for a stage, all marked ns.Own, so no
-- module restyles them. draw reads the settings through ns.Get only (the caller runs it inside ns.Viewing, so it draws the draft) and paints every part again.
-- parts maps a saved path to the region that setting changes, for the bracket that follows the row under the mouse; parts.of(stage) gives the parts of one
-- stage, since a drawing is built once for each stage it is shown on.
-- If stage.view is a table, the outlines follow it (ns.SetOutlineView) when the client of this build has that function.
-- What a plate is made of is the game's own layout for the nameplate style and size chosen: the sizes are Camelot's
-- (Blizzard_NamePlates/Camelot/Blizzard_NamePlateConstants.lua:33-60, 62-68), the anchors those of NamePlateUnitFrameMixin:UpdateAnchors
-- (Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua:678-890) and of the cast bar (Blizzard_NamePlateCastingBar.lua:26-130). What each row changes is what
-- Nameplates.lua, PlateText.lua, PlateColours.lua and HealthColour.lua do to a plate with the same row. The numbers are fixed samples: the game withholds the
-- health, the cast times and the aura times of a unit (UnitDocumentation.lua:1526-1529).

local KEY = "nameplates"
local P = {}
ns.SetupDrawings = ns.SetupDrawings or {}

-- Plate sizes at size 2 (the game's Medium), by nameplate size 1 to 5: horizontal and vertical scale (Camelot constants :62-68).
P.SCALES = { { 0.75, 0.8 }, { 1, 1 }, { 1.25, 1.25 }, { 1.4, 1.4 }, { 1.6, 1.6 } }
-- Per nameplate style: the health bar height, the cast bar height and the level box height at size 2, whether the name is inside the health bar and whether
-- the spell name is inside the cast bar (Blizzard_NamePlates.lua:354-380, 452-500).
P.STYLES = {
	thin = { health = 13, cast = 6, level = 16, inside = false, spellInside = false },
	modern = { health = 20, cast = 6, level = 23, inside = true, spellInside = false },
	block = { health = 20, cast = 16, level = 23, inside = true, spellInside = true },
	castfocus = { health = 13, cast = 16, level = 16, inside = false, spellInside = true },
}
-- Plate width, the gap at each side of it, the font heights, the spell icon, the level box width and the gap before it, the aura icon (Camelot constants).
P.WIDTH, P.INSET, P.FONT, P.CAST_FONT, P.LEVEL_FONT = 190, 12, 14, 10, 10
P.ICON, P.LEVEL_W, P.LEVEL_GAP, P.AURA = 10, 28, 5, 25
P.SPACING = 2
-- The gap between a class icon and the row, and the border of an elite, a rare and a boss in screen pixels (Nameplates.lua:30, 46).
P.GAP, P.KIND_PX = 3, 2
-- The colours the game gives a hostile and a friendly unit when no row changes them, the level number, the dimming of a plate that is not the target.
P.HOSTILE, P.FRIENDLY, P.LEVEL_COLOUR = { 0.77, 0.23, 0.23 }, { 0.24, 0.77, 0.35 }, { 1, 0.82, 0 }
P.SHARE, P.DIM = 0.7, 0.5
P.GOLD, P.SILVER = { 1, 0.82, 0 }, { 0.78, 0.8, 0.84 }
-- The atlases of the game's own art, used when the client has them.
P.ATLAS = { bar = "UI-HUD-CoolDownManager-Bar", level = "ui-hud-nameplates-levelindicator", cast = "ui-castingbar-filling-standard", pip = "ui-castingbar-pip",
	shield = "nameplates-InterruptShield" }
P.RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
P.SPELLS = { 135940, 135964, 136089, 136096, 135987 }
P.AX = { LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, CENTER = 0.5, TOP = 0.5, BOTTOM = 0.5, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
P.AY = { BOTTOM = 0, BOTTOMLEFT = 0, BOTTOMRIGHT = 0, CENTER = 0.5, LEFT = 0.5, RIGHT = 0.5, TOP = 1, TOPLEFT = 1, TOPRIGHT = 1 }
-- The canvas every drawing is laid out on, and the room kept round it.
P.CANVAS_W, P.CANVAS_H, P.MARGIN = 658, 204, 10
P.states = setmetatable({}, { __mode = "k" })

local function Get(key)
	return ns.Get(KEY .. "." .. key)
end

-- Frames, textures and texts of a drawing --------------------------------------------------------------------

local function Frame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	return frame
end

local function Tex(parent, layer, sub)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	ns.Own[texture] = true
	return texture
end

local function Txt(parent, layer)
	local text = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlightSmall")
	ns.Own[text] = true
	return text
end

-- An atlas on a texture, with the picture's own corners put back (SetAtlas takes the atlas, whether to use its size, the filter and whether to reset them).
function P.SetAtlas(texture, name)
	texture:SetAtlas(name, false, nil, true)
end

function P.AtlasExists(name)
	local api = C_Texture
	if type(api) == "table" then
		if type(api.GetAtlasExists) == "function" then
			local ok, exists = pcall(api.GetAtlasExists, name)
			return ok and exists == true
		elseif type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			return ok and info ~= nil
		end
	end
	return false
end

-- The file of the plate's font: the one the game gives its nameplate text.
function P.Face()
	if P.face == nil then
		P.face = "Fonts\\FRIZQT__.TTF"
		local object = SystemFont_NamePlate
		if type(object) == "table" and type(object.GetFont) == "function" then
			local ok, file = pcall(object.GetFont, object)
			if ok and type(file) == "string" and file ~= "" then
				P.face = file
			end
		end
	end
	return P.face
end

-- The font string at `base` height times `percent`, with or without an outline, in a colour.
function P.Text(text, base, percent, outlined, colour)
	text:SetFont(P.Face(), base, ns.OutlineFlags(outlined and "outline" or "none"))
	ns.TextStyle(text, { percent = percent, r = colour[1], g = colour[2], b = colour[3] })
end

-- Hex of a row to a colour table.
local function Rgb(path)
	local r, g, b = ns.Colour(path)
	return { r, g, b }
end

-- The name of the player and the token of the class, from plain values for "player" (client.md 1.1), or fixed samples.
function P.Player()
	local name, token = "Brennan", "MAGE"
	if type(UnitName) == "function" then
		local ok, got = pcall(UnitName, "player")
		if ok and not ns.IsSecret(got) and type(got) == "string" and got ~= "" then
			name = got
		end
	end
	if type(UnitClass) == "function" then
		local ok, _, got = pcall(UnitClass, "player")
		if ok and not ns.IsSecret(got) and type(got) == "string" and got ~= "" then
			token = got
		end
	end
	return name, token
end

-- Short numbers as the game writes them, from a plain sample.
function P.Abbreviate(number)
	if type(AbbreviateNumbers) == "function" then
		local ok, text = pcall(AbbreviateNumbers, number)
		if ok and type(text) == "string" then
			return text
		end
	end
	return number >= 1000 and ("%.1fK"):format(number / 1000) or tostring(number)
end

-- The look of a plate from the rows ---------------------------------------------------------------------------

-- What Nameplates.lua, PlateText.lua and the files after it make of each row for one plate. A plate the module leaves as the game draws it (the module
-- off, or a friendly plate with Restyle friendly nameplates off) has the game's own look, which is what a row at its default gives too.
function P.Look(friend)
	local styled = Get("enabled") == true and (not friend or Get("friendly") == true)
	local o = { styled = styled }
	local function Row(key, game)
		if styled then
			return Get(key)
		end
		return game
	end
	o.border = styled and Get("health") == true
	o.backdrop = styled and Get("healthBackdrop") == true
	o.flat = styled and Get("healthFlat") == true
	o.texture = Get("healthTexture")
	o.height, o.width = Row("healthHeight", 100), Row("barWidth", 100)
	o.dim = o.border and Get("dim") == true
	o.dimAmount = Get("dimAmount") / 100
	o.heal, o.absorb, o.healAbsorb = Row("healPrediction", true), Row("absorbs", true), Row("healAbsorbs", true)
	o.nameShow, o.nameSize, o.nameOutline, o.nameColour = Row("nameShow", true), Row("nameSize", 100), Row("nameOutline", true), Row("nameColour", "game")
	o.nameCustom = Rgb(KEY .. ".nameCustomColour")
	o.nameRow = styled and Get("nameRow") == true
	o.textShow, o.textSize, o.textOutline = Row("healthText", true), Row("healthTextSize", 100), Row("healthTextOutline", true)
	o.textColour = (styled and Get("healthTextColour") ~= "ffffffff") and Rgb(KEY .. ".healthTextColour") or { 1, 1, 1 }
	o.textFormat = Row("healthFormat", "game")
	o.level, o.levelSize = Row("level", "default"), Row("levelSize", 100)
	-- The square box and its gap apply to Thin border and Text only, as LevelBox of Nameplates.lua does.
	o.levelSquare = o.level ~= "default" and Get("levelShape") == "square"
	o.levelGap = Get("levelGap")
	o.kindMark = styled and Get("kindMark") == true
	o.targetOn = o.border and Get("target") == true
	o.kindBorder = o.border and Get("kindBorder") == true
	o.hover = styled and Get("hover") == true
	o.cast, o.castBackdrop = styled and Get("cast") == true, styled and Get("castBackdrop") == true
	o.castFlat, o.castTexture = styled and Get("castFlat") == true, Get("castTexture")
	o.castHeight, o.castTextSize, o.castIconSize = Row("castHeight", 100), Row("castTextSize", 100), Row("castIconSize", 100)
	o.castOutline = Row("castTextOutline", true)
	o.castColour = (styled and Get("castTextColour") ~= "ffffffff") and Rgb(KEY .. ".castTextColour") or { 1, 1, 1 }
	o.spark, o.shield, o.castTime = Row("castSpark", true), Row("castShield", true), styled and Get("castTime") == true
	o.auras = styled and Get("auras") == true
	o.auraCrop, o.timers, o.stacks = Get("auraCrop") / 100, Row("auraTimers", true), Row("auraStacks", true)
	o.auraColour = (styled and Get("auraBorderOwn") == true) and Rgb(KEY .. ".auraBorderColour") or nil
	o.auraAlpha = Row("auraOpacity", 100) / 100
	o.classOn = styled
	o.classBorder = Get("classBorder") == true
	o.classFit, o.classGap = Get("classFit"), Get("classGap")
	o.marker = Row("raidMarker", true)
	o.markerSize = Row("raidMarkerSize", 22)
	o.markerX, o.markerY = Row("raidMarkerX", 0), Row("raidMarkerY", 0)
	return o
end

function P.Sets()
	local style, size = Get("style"), Get("size")
	if P.STYLES[style] == nil then
		style = "thin"
	end
	if type(size) ~= "number" or P.SCALES[size] == nil then
		size = 2
	end
	return { style = style, size = size }
end

-- The colour of the border of a kind of unit: the row's, or the game's own colour of the kind while the row is at its default (Nameplates.lua:276-288).
function P.KindColour(kind)
	local look = ns.KINDS[kind]
	local rows = { elite = "eliteColour", rare = "rareColour", rareelite = "rareColour", boss = "bossColour" }
	local defaults = { eliteColour = "ffffd100", rareColour = "ffc7ccd6", bossColour = "ffff593d" }
	local row = rows[kind]
	if not (look and row) then
		return nil
	end
	if Get(row) == defaults[row] then
		return look.colour
	end
	return Rgb(KEY .. "." .. row)
end

-- The colour the game gives a unit's reaction: the Colours page's row with Custom reaction colours, else the game's own colour.
function P.Reaction(friend)
	if ns.Get("general.reactionOwn") == true then
		return Rgb(friend and "general.reactionFriendly" or "general.reactionHostile")
	end
	return friend and P.FRIENDLY or P.HOSTILE
end

-- The colour of a plate's health bar, in the order PlateColours.lua answers: the target's colour, a reaction colour, the colour by health left, the game's.
function P.BarColour(spec, o)
	local gameColour = spec.friendly and P.FRIENDLY or P.HOSTILE
	if spec.player and not spec.friendly then
		local r, g, b = ns.ClassColour()
		if r then
			gameColour = { r, g, b }
		end
	end
	if not o.styled then
		return gameColour
	end
	if Get("targetBar") == true and spec.target then
		return Rgb(KEY .. ".targetBarColour")
	end
	if Get("colours") == true and not (spec.player and Get("colourPlayers") ~= "reaction") then
		return P.Reaction(spec.friendly)
	end
	if Get("healthByLeft") == true and ns.HealthLeftColour then
		local r, g, b = ns.HealthLeftColour(spec.health or P.SHARE)
		return { r, g, b }
	end
	return gameColour
end

-- A plate -----------------------------------------------------------------------------------------------------------

-- An outline of the addon's own frame, for the page of the nameplates and for the view of the stage.
function P.Outline(S, owner, target)
	local outline = ns.SetOutlineArea(ns.Outline(owner, target), KEY)
	if outline then
		S.outlines[#S.outlines + 1] = outline
		if S.view ~= nil and type(ns.SetOutlineView) == "function" then
			ns.SetOutlineView(outline, S.view)
		end
	end
	return outline
end

function P.NewIcon(S, parent)
	local made, icon = pcall(ns.IconNew, parent)
	if not (made and type(icon) == "table") then
		-- A client without cooldown frames: a square icon with a border.
		local frame = Frame(parent)
		local texture = Tex(frame, "ARTWORK", 0)
		texture:SetAllPoints(frame)
		icon = { frame = frame, texture = texture, outline = ns.Outline(frame, frame) }
	end
	ns.SetOutlineArea(icon.outline, KEY)
	S.outlines[#S.outlines + 1] = icon.outline
	if S.view ~= nil and type(ns.SetOutlineView) == "function" then
		ns.SetOutlineView(icon.outline, S.view)
	end
	icon.timer, icon.count = Txt(icon.frame, "OVERLAY"), Txt(icon.frame, "OVERLAY")
	return icon
end

function P.NewPlate(S, parent)
	local p = { S = S }
	p.f = Frame(parent)
	p.bar = Frame(p.f)
	p.band = Tex(p.bar, "BACKGROUND", -8)
	p.fill = Tex(p.bar, "ARTWORK", 0)
	p.heal, p.absorb, p.healAbsorb, p.over = Tex(p.bar, "ARTWORK", 1), Tex(p.bar, "ARTWORK", 2), Tex(p.bar, "ARTWORK", 3), Tex(p.bar, "ARTWORK", 4)
	p.outline = P.Outline(S, p.bar, p.bar)
	p.edges = { Tex(p.bar, "OVERLAY", 5), Tex(p.bar, "OVERLAY", 5), Tex(p.bar, "OVERLAY", 5), Tex(p.bar, "OVERLAY", 5) }
	p.lowFrame = Frame(p.bar)
	p.lowFrame:SetAllPoints(p.bar)
	p.low = P.Outline(S, p.lowFrame, p.lowFrame)
	ns.SetOutline(p.low, true, false)
	p.row = Tex(p.f, "BACKGROUND", -6)
	-- The name is drawn over the health bar when the style puts it inside: its frame is made after the bar, so it is above it.
	p.words = Frame(p.f)
	p.words:SetAllPoints(p.f)
	p.name = Txt(p.words, "OVERLAY")
	p.htext = Txt(p.words, "OVERLAY")
	p.lvl = Frame(p.f)
	p.lvlArt = Tex(p.lvl, "BACKGROUND", 0)
	p.span = Frame(p.lvl)
	p.span:SetPoint("LEFT", p.lvl, "LEFT", 0, 0)
	p.span:SetPoint("RIGHT", p.lvl, "RIGHT", 0, 0)
	p.span:SetPoint("TOP", p.bar, "TOP", 0, 0)
	p.span:SetPoint("BOTTOM", p.bar, "BOTTOM", 0, 0)
	p.lvlOutline = P.Outline(S, p.lvl, p.span)
	p.lvlText, p.mark = Txt(p.lvl, "OVERLAY"), Txt(p.lvl, "OVERLAY")
	p.iconFrame = Frame(p.f)
	p.iconArt = Tex(p.iconFrame, "ARTWORK", 0)
	p.iconArt:SetAllPoints(p.iconFrame)
	p.iconOutline = P.Outline(S, p.iconFrame, p.iconFrame)
	p.marker = Tex(p.f, "OVERLAY", 3)
	p.flag, p.buffA, p.buffB = Tex(p.f, "OVERLAY", 3), Tex(p.f, "OVERLAY", 3), Tex(p.f, "OVERLAY", 3)
	p.cast = Frame(p.f)
	p.cbar = Frame(p.cast)
	p.cfill = Tex(p.cbar, "ARTWORK", 0)
	p.spark = Tex(p.cbar, "OVERLAY", 2)
	p.spark:SetBlendMode("ADD")
	p.cOutline = P.Outline(S, p.cbar, p.cbar)
	p.cicon, p.shield = Tex(p.cast, "ARTWORK", 1), Tex(p.cast, "ARTWORK", 2)
	p.ctext, p.ctime = Txt(p.cbar, "OVERLAY"), Txt(p.cbar, "OVERLAY")
	p.auras = Frame(p.f)
	p.icons = {}
	return p
end

-- Anchors a region by `point` at x, y from the bottom left corner of the plate, gives it a size, and widens the box the plate takes up.
function P.Put(p, region, point, x, y, w, h)
	region:ClearAllPoints()
	region:SetPoint(point, p.f, "BOTTOMLEFT", x, y)
	if w then
		region:SetSize(w, h)
		local left, bottom = x - w * P.AX[point], y - h * P.AY[point]
		local box = p.box
		box.l, box.b = math.min(box.l, left), math.min(box.b, bottom)
		box.r, box.t = math.max(box.r, left + w), math.max(box.t, bottom + h)
	end
end

-- The sizes of the parts of a plate, from the style and size chosen and the rows that change a size.
function P.Measure(o, spec, sets)
	local scale = P.SCALES[sets.size]
	local style = P.STYLES[sets.style]
	local h, v = scale[1], scale[2]
	local m = { h = h, v = v, style = style }
	m.BW = (P.WIDTH - 2 * P.INSET) * h * o.width / 100
	m.HH = style.health * v * o.height / 100
	m.LW, m.LH = P.LEVEL_W * v, style.level * v
	m.HW = m.BW - (m.LW + P.LEVEL_GAP)
	if o.levelSquare then
		m.LW, m.LH = m.HH, m.HH
		m.HW = m.BW - (m.LW + o.levelGap)
	end
	m.NH = P.FONT * v * o.nameSize / 100
	m.sp = P.SPACING * v
	m.healthY = 0
	if spec.cast or spec.reserve then
		m.CB = style.cast * v * o.castHeight / 100
		m.CI = P.ICON * v * o.castIconSize / 100
		m.CC = m.CB + (style.spellInside and 0 or P.ICON * v)
		m.healthY = m.CC + P.SPACING * v
	end
	m.center = m.healthY + m.HH / 2
	m.nameAbove = not style.inside
	m.top = m.healthY + m.HH + (m.nameAbove and (m.sp + m.NH) or 0)
	if spec.auras then
		m.AS = P.AURA * h
		m.auraY = m.top + m.sp
		m.top = m.auraY + m.AS
	end
	return m
end

-- A fill of `share` of a bar's width: the image file of the bar texture tinted, or one colour.
function P.Fill(texture, bar, width, file, share, colour)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	texture:SetWidth(math.max(0.01, width * share))
	if file then
		texture:SetTexture(file)
		texture:SetVertexColor(colour[1], colour[2], colour[3], 1)
		texture:SetTexCoord(0, share, 0, 1)
	else
		texture:SetColorTexture(colour[1], colour[2], colour[3], 1)
		texture:SetVertexColor(1, 1, 1, 1)
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

-- The game's own fill: its atlas tinted, or a plain version when the client has no such art.
function P.GameFill(texture, bar, width, share, colour, atlas)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	texture:SetWidth(math.max(0.01, width * share))
	if P.AtlasExists(atlas) then
		P.SetAtlas(texture, atlas)
		texture:SetVertexColor(colour[1], colour[2], colour[3], 1)
	else
		texture:SetColorTexture(colour[1] * 0.8, colour[2] * 0.8, colour[3] * 0.8, 1)
		texture:SetVertexColor(1, 1, 1, 1)
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

-- A piece of a bar from one share of its width to another, in one colour.
function P.Segment(texture, bar, width, from, to, r, g, b, a)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", bar, "TOPLEFT", width * from, 0)
	texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", width * from, 0)
	texture:SetWidth(math.max(0.01, width * (to - from)))
	texture:SetColorTexture(r, g, b, a)
end

function P.Raid(texture, index)
	local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
	texture:SetTexture(P.RAID)
	texture:SetTexCoord(column * 0.25, column * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

-- The health text, in the format the row says. The game's own is the percent.
function P.HealthText(o, share)
	local formats = ns.PLATE_HEALTH_FORMATS
	local value, missing = P.Abbreviate(10000 * share), P.Abbreviate(10000 * (1 - share))
	local format = o.textFormat
	if format == "value" then
		return value
	elseif format == "both" then
		return formats.both:format(value, share * 100)
	elseif format == "missing" then
		return missing
	end
	return formats.percent:format(share * 100)
end

-- The colour of the name by the rows: the game's, white, by reaction, or the custom one.
function P.NameColour(spec, o)
	local mode = o.nameColour
	if mode == "white" then
		return { 1, 1, 1 }
	elseif mode == "custom" then
		return o.nameCustom
	elseif mode == "reaction" then
		return P.Reaction(spec.friendly)
	end
	return { 1, 1, 1 }
end

-- The border of the health bar: the target's or focus's colour, else the mouseover colour, else the colour of the kind of unit.
function P.Border(p, spec, o)
	local r, g, b, px
	local mark = o.targetOn and (spec.target and "targetColour" or spec.focus and "focusColour")
	if mark then
		r, g, b = ns.Colour(KEY .. "." .. mark)
		px = Get("targetThickness")
	end
	ns.SetOutlineColour(p.lvlOutline, r, g, b)
	ns.SetOutlineThickness(p.lvlOutline, px)
	if r == nil and o.hover and spec.hover then
		r, g, b = ns.Colour(KEY .. ".hoverColour")
	end
	if r == nil and o.kindBorder and spec.kind then
		local colour = P.KindColour(spec.kind)
		if colour then
			r, g, b, px = colour[1], colour[2], colour[3], P.KIND_PX
		end
	end
	ns.SetOutlineColour(p.outline, r, g, b)
	ns.SetOutlineThickness(p.outline, px)
	ns.SetOutline(p.outline, o.border, o.backdrop)
	-- The game's own marker round the bar stays while the border of the rows is not drawn for the target and the focus.
	local game = (spec.target or spec.focus) and not o.targetOn
	local colour = spec.target and { 1, 1, 1 } or { 1, 0.49, 0.04 }
	local bar = p.bar
	for index, edge in ipairs(p.edges) do
		edge:ClearAllPoints()
		if index == 1 then
			edge:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -2, 0)
			edge:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 2, 0)
			edge:SetHeight(2)
		elseif index == 2 then
			edge:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -2, 0)
			edge:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 2, 0)
			edge:SetHeight(2)
		elseif index == 3 then
			edge:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
			edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
			edge:SetWidth(2)
		else
			edge:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
			edge:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
			edge:SetWidth(2)
		end
		edge:SetColorTexture(colour[1], colour[2], colour[3], 1)
		edge:SetShown(game and true or false)
	end
end

-- The level number, its box and the mark after it.
function P.Level(p, spec, o, m)
	P.Put(p, p.lvl, "BOTTOMLEFT", m.BW - m.LW, m.center - m.LH / 2, m.LW, m.LH)
	local style = o.level
	ns.SetOutline(p.lvlOutline, style == "box", not o.border or o.backdrop)
	if style == "default" then
		if P.AtlasExists(P.ATLAS.level) then
			P.SetAtlas(p.lvlArt, P.ATLAS.level)
			p.lvlArt:SetVertexColor(1, 1, 1, 1)
		else
			p.lvlArt:SetColorTexture(0.3, 0.3, 0.3, 1)
		end
		p.lvlArt:ClearAllPoints()
		p.lvlArt:SetAllPoints(p.lvl)
		p.lvlArt:Show()
	else
		p.lvlArt:Hide()
	end
	p.lvlText:ClearAllPoints()
	p.lvlText:SetPoint("CENTER", p.lvl, "CENTER", 0, 0)
	P.Text(p.lvlText, P.LEVEL_FONT * m.v, o.levelSize, true, P.LEVEL_COLOUR)
	p.lvlText:SetText(spec.level and tostring(spec.level) or "")
	local look = o.kindMark and spec.kind and ns.KINDS[spec.kind]
	if look and look.mark then
		p.mark:ClearAllPoints()
		p.mark:SetPoint("LEFT", p.lvlText, "RIGHT", 1, 0)
		P.Text(p.mark, P.LEVEL_FONT * m.v, o.levelSize, true, look.colour)
		p.mark:SetText(look.mark)
		p.mark:Show()
	else
		p.mark:Hide()
	end
end

-- The icon of the class beside the row, where PlaceIcon of Nameplates.lua puts it.
function P.ClassIcon(p, spec, o, m)
	local row = spec.friendly and "classFriendly" or "classEnemy"
	local _, token = P.Player()
	m.iconShift = 0
	if not (o.classOn and spec.player and Get(row) == true) then
		p.iconFrame:Hide()
		ns.SetOutline(p.iconOutline, false, false)
		return
	end
	local size, x, y = Get("classSize"), Get("classX"), Get("classY")
	local position, gap = Get("classPosition"), o.classGap
	if o.classFit == "bar" then
		size = m.HH
	end
	-- A class icon on the left takes the slot beside the bar, and the raid marker and the flag move out past it.
	m.iconShift = position == "left" and size + gap or 0
	local atlas = ns.ClassAtlas(token)
	if atlas then
		P.SetAtlas(p.iconArt, atlas)
		p.iconArt:SetVertexColor(1, 1, 1, 1)
	else
		p.iconArt:SetColorTexture(0.5, 0.5, 0.5, 1)
	end
	local top = m.healthY + m.HH
	if position == "left" then
		P.Put(p, p.iconFrame, "RIGHT", x - gap, m.center + y, size, size)
	elseif position == "above" then
		local lift = m.nameAbove and (m.sp + m.NH) or 0
		P.Put(p, p.iconFrame, "BOTTOM", m.BW / 2 + x, top + y + lift + P.GAP, size, size)
	elseif position == "below" then
		P.Put(p, p.iconFrame, "TOP", m.BW / 2 + x, y - P.GAP, size, size)
	else
		P.Put(p, p.iconFrame, "LEFT", m.BW + x + gap, m.center + y, size, size)
	end
	p.iconFrame:Show()
	ns.SetOutline(p.iconOutline, o.classBorder, o.classBorder)
end

-- The flag and the two buffs the game hangs at the left end of an enemy player: the flag at the left edge of the icon, the buffs
-- after it (Blizzard_NamePlates.xml:196-199, 228-236). The marker never shows on an enemy player.
function P.LeftEnd(p, spec, o, m)
	local shown = spec.leftEnd and true or false
	for _, region in ipairs({ p.flag, p.buffA, p.buffB }) do
		region:SetShown(shown)
	end
	if not shown then
		return
	end
	local edge = -m.iconShift
	P.Put(p, p.flag, "RIGHT", edge, m.center, 20, 20)
	p.flag:SetColorTexture(0.8, 0.2, 0.2, 1)
	P.Put(p, p.buffA, "RIGHT", edge - 25, m.center, 25, 25)
	P.Put(p, p.buffB, "RIGHT", edge - 55, m.center, 25, 25)
	p.buffA:SetColorTexture(0.35, 0.5, 0.8, 1)
	p.buffB:SetColorTexture(0.35, 0.5, 0.8, 1)
end

-- The cast bar under the health bar, the icon, the shield, the spell name, the spark and the time.
function P.Cast(p, spec, o, m)
	local cast = spec.cast
	if not cast then
		p.cast:Hide()
		return
	end
	p.cast:Show()
	local style = m.style
	P.Put(p, p.cast, "BOTTOMLEFT", 0, 0, m.BW, m.CC)
	local barY = style.spellInside and 0 or m.CI
	p.cbar:ClearAllPoints()
	p.cbar:SetPoint("BOTTOMLEFT", p.f, "BOTTOMLEFT", 0, barY)
	p.cbar:SetSize(m.BW, m.CB)
	local box = p.box
	box.t = math.max(box.t, barY + m.CB)
	ns.SetOutline(p.cOutline, o.cast, o.castBackdrop)
	local colour = cast.shield and Rgb("castbars.shieldColour") or Rgb("castbars.castColour")
	if o.castFlat then
		P.Fill(p.cfill, p.cbar, m.BW, ns.BarTexture(o.castTexture), cast.share, colour)
	else
		P.GameFill(p.cfill, p.cbar, m.BW, cast.share, { 1, 0.7, 0 }, P.ATLAS.cast)
	end
	-- The icon, or the shield in its place for a cast that cannot be interrupted.
	local iconX, iconY
	if style.spellInside then
		iconX, iconY = 0, m.CB / 2
	else
		iconX, iconY = 0, m.CI / 2
	end
	p.cicon:ClearAllPoints()
	p.shield:ClearAllPoints()
	if cast.shield then
		p.cicon:Hide()
		p.shield:SetPoint("RIGHT", p.f, "BOTTOMLEFT", iconX + m.CI, iconY)
		p.shield:SetSize(10 * m.v, 12 * m.v)
		if o.shield and P.AtlasExists(P.ATLAS.shield) then
			P.SetAtlas(p.shield, P.ATLAS.shield)
			p.shield:SetVertexColor(1, 1, 1, 1)
			p.shield:Show()
		elseif o.shield then
			p.shield:SetColorTexture(0.7, 0.7, 0.75, 1)
			p.shield:Show()
		else
			p.shield:Hide()
		end
	else
		p.shield:Hide()
		p.cicon:SetPoint("LEFT", p.f, "BOTTOMLEFT", iconX, iconY)
		p.cicon:SetSize(m.CI, m.CI)
		p.cicon:SetTexture(P.SPELLS[1])
		p.cicon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		p.cicon:Show()
	end
	p.ctext:ClearAllPoints()
	p.ctext:SetPoint("LEFT", p.f, "BOTTOMLEFT", iconX + m.CI + 2, iconY)
	P.Text(p.ctext, P.CAST_FONT * m.v, o.castTextSize, o.castOutline, o.castColour)
	p.ctext:SetText(cast.name)
	p.spark:ClearAllPoints()
	p.spark:SetPoint("CENTER", p.cbar, "LEFT", m.BW * cast.share, 0)
	p.spark:SetSize(4, 12)
	if P.AtlasExists(P.ATLAS.pip) then
		P.SetAtlas(p.spark, P.ATLAS.pip)
	else
		p.spark:SetColorTexture(1, 1, 1, 1)
	end
	p.spark:SetShown(o.spark and true or false)
	p.ctime:ClearAllPoints()
	p.ctime:SetPoint("RIGHT", p.cbar, "RIGHT", -4, 0)
	P.Text(p.ctime, P.CAST_FONT * m.v, o.castTextSize, o.castOutline, { 1, 1, 1 })
	p.ctime:SetText(("%.1f"):format(cast.left))
	p.ctime:SetShown(o.castTime and true or false)
end

-- The row of aura icons above the name.
function P.Auras(p, spec, o, m)
	local count = spec.auras and spec.auras.count or 0
	local sizes = spec.auras and m.AS or 0
	p.auras:SetAlpha(o.auraAlpha)
	if count == 0 then
		p.auras:Hide()
		return
	end
	p.auras:Show()
	local gap = 2
	local width = count * sizes + (count - 1) * gap
	P.Put(p, p.auras, "BOTTOM", m.BW / 2, m.auraY, width, sizes)
	for index = 1, count do
		local icon = p.icons[index]
		if icon == nil then
			icon = P.NewIcon(p.S, p.auras)
			p.icons[index] = icon
		end
		icon.frame:ClearAllPoints()
		icon.frame:SetPoint("BOTTOMLEFT", p.auras, "BOTTOMLEFT", (index - 1) * (sizes + gap), 0)
		icon.frame:SetSize(sizes, sizes)
		icon.frame:Show()
		local crop = o.auras and o.auraCrop or 0
		if icon.texture.SetTexture then
			icon.texture:SetTexture(P.SPELLS[(index - 1) % #P.SPELLS + 1])
			icon.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		end
		if icon.cooldown and icon.sweepSet ~= index then
			icon.sweepSet = index
			local now = type(GetTime) == "function" and GetTime() or 0
			pcall(ns.IconSet, icon, nil, now - 18, 30, { numbers = false })
			if icon.cooldown.Pause then
				pcall(icon.cooldown.Pause, icon.cooldown)
			end
		end
		icon.frame:Show()
		-- The icon's border: a thin one when Aura icon border is on, else the game's thick one, which this drawing leaves as a bare icon.
		ns.SetOutline(icon.outline, o.auras, false)
		local colour = o.auras and o.auraColour or nil
		ns.SetOutlineColour(icon.outline, colour and colour[1], colour and colour[2], colour and colour[3])
		icon.timer:ClearAllPoints()
		icon.timer:SetPoint("CENTER", icon.frame, "CENTER", 0, 0)
		P.Text(icon.timer, 12 * m.h, 100, true, { 1, 1, 1 })
		icon.timer:SetText("12")
		icon.timer:SetShown(o.timers and true or false)
		icon.count:ClearAllPoints()
		icon.count:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", -1, 1)
		P.Text(icon.count, 10 * m.h, 100, true, { 1, 1, 1 })
		icon.count:SetText("3")
		icon.count:SetShown(o.stacks and (index == 2 or index == 4) and true or false)
	end
	for index = count + 1, #p.icons do
		p.icons[index].frame:Hide()
	end
end

-- Lays out and paints one plate from its sample and the rows. Returns the box the plate takes up, from its bottom left corner.
function P.Plate(p, spec, sets)
	local o = P.Look(spec.friendly)
	local m = P.Measure(o, spec, sets)
	p.m, p.o = m, o
	p.box = { l = 0, b = 0, r = m.BW, t = m.top }
	p.f:SetSize(m.BW, m.top)
	p.f:SetScale(spec.scale or 1)
	p.f:SetAlpha(spec.alpha or 1)
	local share = spec.health or P.SHARE
	-- The health bar.
	P.Put(p, p.bar, "BOTTOMLEFT", 0, m.healthY, m.HW, m.HH)
	local colour = P.BarColour(spec, o)
	local file = o.flat and ns.BarTexture(o.texture) or nil
	if o.flat then
		P.Fill(p.fill, p.bar, m.HW, file, share, colour)
	else
		P.GameFill(p.fill, p.bar, m.HW, share, colour, P.ATLAS.bar)
	end
	p.band:ClearAllPoints()
	p.band:SetPoint("TOPLEFT", p.bar, "TOPLEFT", -2, 3)
	p.band:SetPoint("BOTTOMRIGHT", p.bar, "BOTTOMRIGHT", 6, -6)
	p.band:SetColorTexture(0, 0, 0, 0.75)
	p.band:SetShown(not o.border)
	P.Segment(p.heal, p.bar, m.HW, share, math.min(1, share + 0.1), 0.2, 0.85, 0.35, 0.8)
	P.Segment(p.absorb, p.bar, m.HW, math.min(1, share + 0.1), math.min(1, share + 0.18), 1, 1, 1, 0.55)
	P.Segment(p.healAbsorb, p.bar, m.HW, math.max(0, share - 0.12), share, 0.1, 0, 0.12, 0.8)
	p.heal:SetShown(o.heal and true or false)
	p.absorb:SetShown(o.absorb and true or false)
	p.healAbsorb:SetShown(o.healAbsorb and true or false)
	-- Every plate that is not the target or the focus is darkened by the game's overlay; Dim other nameplates sets how much.
	local overlay = 1
	if o.border then
		overlay = o.dim and o.dimAmount or 0
	end
	p.over:ClearAllPoints()
	p.over:SetAllPoints(p.bar)
	p.over:SetColorTexture(0, 0, 0, P.DIM * overlay)
	p.over:SetShown(not (spec.target or spec.focus) and overlay > 0)
	-- The low health border takes its alpha from a step: full below the limit, none from it.
	local low = o.styled and Get("lowHealth") == true
	if low then
		ns.SetOutlineColour(p.low, ns.Colour(KEY .. ".lowHealthColour"))
	end
	p.lowFrame:SetAlpha((low and share * 100 < Get("lowHealthAt")) and 1 or 0)
	p.lowFrame:SetShown(low and true or false)
	P.Border(p, spec, o)
	-- The name and the health text.
	p.name:ClearAllPoints()
	if m.nameAbove then
		P.Put(p, p.name, "BOTTOM", m.BW / 2, m.healthY + m.HH + m.sp)
	else
		P.Put(p, p.name, "LEFT", 4, m.center)
	end
	P.Text(p.name, P.FONT * m.v, o.nameSize, o.nameOutline, P.NameColour(spec, o))
	p.name:SetText(spec.name or "")
	p.name:SetShown(o.nameShow and true or false)
	-- The game cuts a name that would run into the health text or past the row.
	p.name:SetWordWrap(false)
	if m.nameAbove then
		p.name:SetWidth(math.max(1, m.BW))
	else
		local used = #P.HealthText(o, share) * P.FONT * m.v * o.textSize / 100 * 0.5
		p.name:SetWidth(math.max(1, m.HW - 12 - (o.textShow and used or 0)))
		p.name:SetJustifyH("LEFT")
	end
	p.htext:ClearAllPoints()
	p.htext:SetPoint("RIGHT", p.bar, "RIGHT", -4, 0)
	P.Text(p.htext, P.FONT * m.v, o.textSize, o.textOutline, o.textColour)
	p.htext:SetText(P.HealthText(o, share))
	p.htext:SetShown(o.textShow and true or false)
	-- The row behind the name, in the colour of the bar, fading upward.
	local nameBottom = m.nameAbove and (m.healthY + m.HH + m.sp) or (m.center - m.NH / 2)
	p.row:ClearAllPoints()
	p.row:SetPoint("BOTTOMLEFT", p.f, "BOTTOMLEFT", 0, nameBottom - 1)
	p.row:SetPoint("TOPRIGHT", p.f, "BOTTOMLEFT", m.HW, nameBottom + m.NH + 1)
	local drawn = false
	if o.nameRow then
		local r, g, b = colour[1] * 0.7, colour[2] * 0.7, colour[3] * 0.7
		drawn = type(CreateColor) == "function" and pcall(function()
			p.row:SetColorTexture(1, 1, 1, 1)
			p.row:SetGradient("VERTICAL", CreateColor(r, g, b, 0.95), CreateColor(r, g, b, 0.05))
		end)
		if not drawn then
			p.row:SetColorTexture(r, g, b, 0.5)
			drawn = true
		end
	end
	p.row:SetShown(drawn)
	P.Level(p, spec, o, m)
	P.ClassIcon(p, spec, o, m)
	-- The raid marker, left of the row.
	if spec.marker and o.marker then
		P.Raid(p.marker, spec.marker)
		P.Put(p, p.marker, "RIGHT", o.markerX - m.iconShift, m.center + o.markerY, o.markerSize, o.markerSize)
		p.marker:Show()
	else
		p.marker:Hide()
	end
	P.LeftEnd(p, spec, o, m)
	P.Cast(p, spec, o, m)
	P.Auras(p, spec, o, m)
	return p.box
end

-- Cells: a plate or a row of chips, with a label --------------------------------------------------------------

-- The three threat colours, as small bars under the border the rows give a health bar.
function P.NewChips(S, parent)
	local chips = { f = Frame(parent), list = {} }
	for index = 1, 3 do
		local chip = { f = Frame(chips.f) }
		chip.fill = Tex(chip.f, "ARTWORK", 0)
		chip.fill:SetAllPoints(chip.f)
		chip.outline = P.Outline(S, chip.f, chip.f)
		chip.text = Txt(chips.f, "OVERLAY")
		chips.list[index] = chip
	end
	return chips
end

function P.Chips(chips)
	local rows = { { "threatGood", "You want" }, { "threatTransition", "Changing hands" }, { "threatBad", "You do not want" } }
	local width, height, gap = 56, 12, 8
	chips.f:SetSize(3 * width + 2 * gap, height + 14)
	for index, chip in ipairs(chips.list) do
		local x = (index - 1) * (width + gap)
		chip.f:ClearAllPoints()
		chip.f:SetPoint("BOTTOMLEFT", chips.f, "BOTTOMLEFT", x, 0)
		chip.f:SetSize(width, height)
		local r, g, b = ns.Colour(KEY .. "." .. rows[index][1])
		chip.fill:SetColorTexture(r, g, b, 1)
		ns.SetOutline(chip.outline, true, true)
		chip.text:ClearAllPoints()
		chip.text:SetPoint("BOTTOMLEFT", chip.f, "TOPLEFT", 0, 2)
		chip.text:SetFont(P.Face(), 10, "")
		chip.text:SetTextColor(0.7, 0.7, 0.7, 1)
		chip.text:SetText(rows[index][2])
	end
	return { l = 0, b = 0, r = 3 * width + 2 * gap, t = height + 14 }
end

function P.NewLabel(parent)
	local label = Txt(parent, "OVERLAY")
	label:SetFont(P.Face(), 11, "")
	return label
end

-- Puts the cells of a drawing in the grid frame. A cell is { id, label, col, show, spec | chips, at = { x, y } }. Columns run top to bottom. Returns the size
-- of the grid before it is scaled to the canvas.
function P.Place(S, cells, sets)
	local columns, layout = {}, {}
	for _, cell in ipairs(cells) do
		local plate = S.plates[cell.id]
		if cell.show == false then
			local frame = plate and (plate.f or plate.chips.f)
			if frame then
				frame:Hide()
				plate.label:Hide()
			end
		else
			if plate == nil then
				plate = cell.chips and { chips = P.NewChips(S, S.grid) } or P.NewPlate(S, S.grid)
				plate.label = P.NewLabel(S.grid)
				S.plates[cell.id] = plate
			end
			local box
			if cell.chips then
				plate.chips.f:Show()
				box = P.Chips(plate.chips)
			else
				plate.f:Show()
				box = P.Plate(plate, cell.spec, sets)
			end
			plate.label:Show()
			plate.label:SetText(cell.label)
			plate.label:SetTextColor(0.7, 0.7, 0.7, 1)
			local entry = { cell = cell, plate = plate, box = box }
			layout[#layout + 1] = entry
			columns[cell.col or 1] = columns[cell.col or 1] or {}
			table.insert(columns[cell.col or 1], entry)
		end
	end
	return columns, layout
end

-- Positions the cells of a stack of columns. Every plate is placed by the bottom left corner of its plate, the label to the left of the box.
function P.Columns(S, columns)
	local LABEL_W, GAP_X, GAP_Y, COL_GAP = 78, 6, 12, 26
	local x, width, height = 0, 0, 0
	local placed = {}
	for index = 1, 2 do
		local list = columns[index]
		if list then
			local colW, y = 0, 0
			for _, entry in ipairs(list) do
				local box = entry.box
				local w, h = box.r - box.l, box.t - box.b
				entry.x, entry.y, entry.w, entry.h = x + LABEL_W + GAP_X - box.l, y + h + box.b, w, h
				colW = math.max(colW, LABEL_W + GAP_X + w)
				y = y + h + GAP_Y
				placed[#placed + 1] = entry
			end
			height = math.max(height, y - GAP_Y)
			x = x + colW + COL_GAP
			width = x - COL_GAP
		end
	end
	for _, entry in ipairs(placed) do
		local frame = entry.plate.f or entry.plate.chips.f
		local label = entry.plate.label
		-- entry.y is the distance from the top of the grid to the bottom of the plate.
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", S.grid, "TOPLEFT", entry.x, -entry.y)
		label:ClearAllPoints()
		label:SetPoint("RIGHT", frame, "BOTTOMLEFT", -GAP_X + (entry.box.l), entry.plate.m and entry.plate.m.center or 6)
		label:SetJustifyH("RIGHT")
	end
	return width, height
end

-- Fits a grid of this size to the canvas: scales it down when it is larger, and says by how much.
function P.Fit(S, width, height)
	local fit = math.min(1, (P.CANVAS_W - 2 * P.MARGIN) / math.max(1, width), (P.CANVAS_H - 2 * P.MARGIN) / math.max(1, height))
	S.grid:SetSize(math.max(1, width), math.max(1, height))
	S.grid:ClearAllPoints()
	S.grid:SetPoint("CENTER", S.root, "CENTER", 0, 0)
	S.grid:SetScale(fit)
	S.fit = fit
end

-- The drawings ------------------------------------------------------------------------------------------------

function P.Build(stage)
	local S = P.states[stage]
	if S then
		return S
	end
	S = { stage = stage, plates = {}, parts = {}, outlines = {}, view = rawget(stage, "view") }
	S.root = Frame(stage)
	S.root:SetSize(P.CANVAS_W, P.CANVAS_H)
	S.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	S.grid = Frame(S.root)
	P.states[stage] = S
	return S
end

-- The scale that fits the canvas to the stage: the canvas itself, or smaller where the stage is.
function P.Canvas(S)
	local width, height = S.stage:GetSize()
	if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		width, height = P.CANVAS_W, P.CANVAS_H
	end
	S.root:SetScale(math.min(1, width / P.CANVAS_W, height / P.CANVAS_H))
end

-- The view the stage names, for the outlines: they are laid out and painted from it where the client of this build has the functions, and from the
-- rows as they are now otherwise.
function P.Follow(S)
	local view = rawget(S.stage, "view")
	if view ~= S.view and type(ns.SetOutlineView) == "function" then
		for _, outline in ipairs(S.outlines) do
			ns.SetOutlineView(outline, view)
		end
	end
	S.view = view
end

function P.Repaint(S)
	if type(ns.RepaintOutline) == "function" then
		for _, outline in ipairs(S.outlines) do
			ns.RepaintOutline(outline)
		end
	end
end

function P.Common(stage, cellsOf, arrange)
	local S = P.Build(stage)
	P.Follow(S)
	P.Canvas(S)
	local sets = P.Sets()
	local cells = cellsOf(S, sets)
	local columns, layout = P.Place(S, cells, sets)
	local width, height
	if arrange then
		width, height = arrange(S, layout)
	else
		width, height = P.Columns(S, columns)
	end
	P.Fit(S, width, height)
	P.Parts(S)
	P.Repaint(S)
	return S
end

-- The names an enemy and a friendly plate carry.
function P.Samples()
	local name = P.Player()
	return { enemy = "Defias Pillager", elite = "Defias Taskmaster", player = "Gorvak", friend = name }
end

function P.Cells(kind)
	return function()
		local names = P.Samples()
		local function Enemy(extra)
			local spec = { name = names.enemy, level = 18, health = P.SHARE }
			for key, value in pairs(extra or {}) do
				spec[key] = value
			end
			return spec
		end
		if kind == "plate" then
			return {
				{ id = "enemy", label = "Enemy", col = 1, spec = Enemy() },
				{ id = "elite", label = "Elite", col = 1, spec = Enemy({ name = names.elite, level = 20, kind = "elite" }) },
				{ id = "player", label = "Enemy player", col = 1, spec = Enemy({ name = names.player, player = true }) },
				{ id = "friend", label = "Friendly", col = 1, spec = { name = names.friend, level = 18, friendly = true, player = true, health = P.SHARE } },
				{ id = "target", label = "Target", col = 2, show = Get("targetBar") == true, spec = Enemy({ target = true }) },
				{ id = "hover", label = "Mouseover", col = 2, show = Get("hover") == true, spec = Enemy({ hover = true }) },
				{ id = "low", label = "Low health", col = 2, show = Get("lowHealth") == true, spec = Enemy({ health = 0.18 }) },
				{ id = "threat", label = "Threat", col = 2, show = Get("threat") == true, chips = true },
			}
		elseif kind == "cast" then
			return {
				{ id = "cast", label = "Casting", col = 1, spec = Enemy({ cast = { name = "Shadow Bolt", share = 0.6, left = 1.2 } }) },
				{ id = "locked", label = "Cannot be interrupted", col = 1,
					spec = Enemy({ cast = { name = "Stoneskin", share = 0.6, left = 1.2, shield = true } }) },
			}
		elseif kind == "auras" then
			return {
				{ id = "auras", label = "Auras", col = 1, spec = Enemy({ auras = { count = 5 } }) },
			}
		elseif kind == "marks" then
			return {
				{ id = "target", label = "Target", col = 1, spec = Enemy({ target = true }) },
				{ id = "focus", label = "Focus", col = 1, spec = Enemy({ focus = true }) },
				{ id = "marked", label = "Raid marker", col = 1, spec = Enemy({ marker = 8 }) },
				{ id = "player", label = "Enemy player", col = 1, spec = Enemy({ name = names.player, player = true, leftEnd = true }) },
				{ id = "friend", label = "Friendly player", col = 2, spec = { name = names.friend, level = 18, friendly = true, player = true, health = P.SHARE, marker = 4 } },
				{ id = "elite", label = "Elite", col = 2, spec = Enemy({ name = names.elite, level = 20, kind = "elite" }) },
				{ id = "rare", label = "Rare", col = 2, spec = Enemy({ name = "Old Blanchy", level = 20, kind = "rare" }) },
				{ id = "boss", label = "Boss", col = 2, spec = Enemy({ name = "Edwin VanCleef", level = 20, kind = "boss" }) },
			}
		end
		-- The stack: the target, a plate near and a plate far, nearly on top of one another.
		local selected, far = Get("selectedScale") / 100, Get("minScale") / 100
		local other = Get("notSelectedAlpha") / 100
		local cast = Get("showCastBars") == true and { name = "Shadow Bolt", share = 0.6, left = 1.2 } or nil
		return {
			{ id = "far", label = "Far", side = "left", spec = Enemy({ name = names.player, player = true, scale = far, alpha = Get("minAlpha") / 100 * other, reserve = true }) },
			{ id = "target", label = "Target", side = "right", spec = Enemy({ target = true, scale = selected, cast = cast, reserve = true }) },
			{ id = "near", label = "Near", side = "right", spec = Enemy({ name = names.elite, level = 20, alpha = other, reserve = true }) },
		}
	end
end

-- The stack: the target at the middle, a far plate beside it at the horizontal step and a near plate above at the vertical step.
function P.Stack(S, layout)
	local by = {}
	for _, entry in ipairs(layout) do
		by[entry.cell.id] = entry
	end
	local target = by.target
	local BW = target.plate.m.BW
	local step = { BW * Get("overlapH") / 100, target.plate.m.top * Get("overlapV") / 100 }
	-- The places of the bottom centre of each plate, in the grid before the scale of each plate.
	local spots = { target = { 0, 0 }, near = { step[1] / 2, step[2] }, far = { -step[1], 0 } }
	local left, right, bottom, top = math.huge, -math.huge, math.huge, -math.huge
	for id, spot in pairs(spots) do
		local entry = by[id]
		local scale = entry.cell.spec.scale or 1
		local box = entry.box
		left = math.min(left, spot[1] + (box.l - BW / 2) * scale)
		right = math.max(right, spot[1] + (box.r - BW / 2) * scale)
		bottom = math.min(bottom, spot[2] + box.b * scale)
		top = math.max(top, spot[2] + box.t * scale)
	end
	local LABEL = 60
	local width, height = right - left + 2 * LABEL, top - bottom
	for id, spot in pairs(spots) do
		local entry = by[id]
		local scale = entry.cell.spec.scale or 1
		local frame, label = entry.plate.f, entry.plate.label
		-- The plate hangs from its own bottom left corner: moved half its width back so that its bottom centre is at the place.
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", S.grid, "BOTTOMLEFT", (spot[1] - left + LABEL - BW / 2 * scale) / scale, (spot[2] - bottom) / scale)
		-- The label hangs from the grid, in the units of the grid, while the plate is in its own scale.
		label:ClearAllPoints()
		local base = (spot[1] - left + LABEL - BW / 2 * scale)
		local middle = spot[2] - bottom + entry.plate.m.center * scale
		if entry.cell.side == "left" then
			label:SetPoint("RIGHT", S.grid, "BOTTOMLEFT", base + (entry.box.l - 4) * scale, middle)
			label:SetJustifyH("RIGHT")
		else
			label:SetPoint("LEFT", S.grid, "BOTTOMLEFT", base + (entry.box.r + 4) * scale, middle)
			label:SetJustifyH("LEFT")
		end
		-- The target is above the others.
		frame:SetFrameLevel(id == "target" and 30 or 10)
	end
	return width, height
end

-- The parts of a stage: the region each saved path changes.
function P.Parts(S)
	local plates = S.plates
	local main = plates.enemy or plates.cast or plates.auras or plates.target
	local parts = {}
	if not main then
		S.parts = parts
		return
	end
	local function Set(paths, region)
		for _, name in ipairs(paths) do
			parts[KEY .. "." .. name] = region
		end
	end
	local plate = plates.enemy or main
	-- A cell switched off again is hidden: a part points at the enemy plate then.
	local function Live(id)
		local cell = plates[id]
		if cell and cell.f and cell.f:IsShown() then
			return cell
		end
		return nil
	end
	Set({ "enabled", "lookOwn", "lookBorder", "lookBack", "lookBackAlpha", "health", "healthBackdrop", "healthFlat", "healthTexture", "healthHeight",
		"barWidth", "colours", "healthByLeft", "style", "size", "showCastBars" }, plate.bar)
	Set({ "friendly" }, (plates.friend or plate).bar)
	Set({ "dim", "dimAmount" }, (plates.near or plate).over)
	Set({ "healPrediction" }, plate.heal)
	Set({ "absorbs" }, plate.absorb)
	Set({ "healAbsorbs" }, plate.healAbsorb)
	Set({ "nameShow", "nameSize", "nameOutline", "nameColour", "nameCustomColour" }, plate.name)
	Set({ "nameRow" }, plate.row)
	Set({ "healthText", "healthTextSize", "healthTextOutline", "healthTextColour", "healthTextWhen", "healthFormat" }, plate.htext)
	Set({ "level", "levelSize", "levelShape", "levelGap" }, plate.lvl)
	Set({ "kindMark" }, (plates.elite or plate).mark)
	Set({ "colourPlayers" }, (plates.player or plate).bar)
	Set({ "targetBar", "targetBarColour", "target", "targetColour", "targetThickness" }, (Live("target") or plate).bar)
	Set({ "focusColour" }, (Live("focus") or Live("target") or plate).bar)
	Set({ "threat", "threatRole", "threatGood", "threatTransition", "threatBad" }, plates.threat and plates.threat.chips.f or plate.bar)
	Set({ "hover", "hoverColour" }, (Live("hover") or plate).bar)
	Set({ "lowHealth", "lowHealthAt", "lowHealthColour" }, (Live("low") or plate).bar)
	Set({ "cast", "castBackdrop", "castFlat", "castTexture", "castHeight" }, plate.cbar)
	Set({ "castTextSize", "castTextOutline", "castTextColour" }, plate.ctext)
	Set({ "castIconSize" }, plate.cicon)
	Set({ "castSpark" }, plate.spark)
	Set({ "castShield" }, (plates.locked or plate).shield)
	Set({ "castTime" }, plate.ctime)
	Set({ "auras", "auraCrop", "auraBorderOwn", "auraBorderColour", "auraTimers", "auraStacks", "auraOpacity", "aurasWhen" }, plate.auras)
	local player = plates.player or plate
	Set({ "classEnemy", "classPosition", "classFit", "classSize", "classGap", "classX", "classY", "classBorder" }, player.iconFrame)
	Set({ "classFriendly" }, (plates.friend or plate).iconFrame)
	Set({ "kindBorder", "eliteColour" }, (plates.elite or plate).bar)
	Set({ "rareColour" }, (plates.rare or plate).bar)
	Set({ "bossColour" }, (plates.boss or plate).bar)
	Set({ "raidMarker", "raidMarkerSize", "raidMarkerX", "raidMarkerY" }, (plates.marked or plate).marker)
	Set({ "overlapH", "overlapV", "selectedScale" }, (Live("target") or plate).f)
	Set({ "minScale", "minAlpha" }, (plates.far or plate).f)
	Set({ "notSelectedAlpha" }, (plates.near or plate).f)
	S.parts = parts
end

-- Makes the table of one drawing from the cells it lays out.
local function Drawing(kind, arrange)
	local cellsOf = P.Cells(kind)
	local drawing = { parts = {} }
	function drawing.build(stage)
		return P.Build(stage)
	end
	function drawing.draw(stage)
		local S = P.Common(stage, cellsOf, arrange)
		drawing.parts = S.parts
		return S
	end
	-- The parts of one stage, and the share of its size the drawing is shown at.
	function drawing.partsOf(stage)
		local S = P.states[stage]
		return S and S.parts or {}
	end
	function drawing.scaleOf(stage)
		local S = P.states[stage]
		return S and S.fit or 1
	end
	return drawing
end

ns.SetupDrawings["mock-nameplate"] = Drawing("plate")
ns.SetupDrawings["mock-nameplate-cast"] = Drawing("cast")
ns.SetupDrawings["mock-nameplate-auras"] = Drawing("auras")
ns.SetupDrawings["mock-nameplate-marks"] = Drawing("marks")
ns.SetupDrawings["mock-nameplate-stack"] = Drawing("stack", P.Stack)
ns.SetupDrawPlates = P
