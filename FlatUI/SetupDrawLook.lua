local _, ns = ...

-- Drawings of the setup steps Scale and Fonts: mock-scale and mock-text. Each is { build(stage), draw(stage), parts = { [path] = region } } (research/flatui-wizard/design.md
-- section 4.2). build makes the frames once, all marked ns.Own so no module restyles them. draw reads only ns.Get, so under the setup draft view it draws the draft.
-- Nothing here reads a live value: health and power are fixed sample numbers (design.md section 4.1).

ns.SetupDrawings = ns.SetupDrawings or {}

local own = ns.Own

local function Plain(value)
	return type(value) == "number" and not ns.IsSecret(value) and value == value and value > 0 and value ~= math.huge and value or nil
end

local function Frame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	own[frame] = true
	return frame
end

local function Texture(parent, layer)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, 0)
	own[texture] = true
	return texture
end

-- A solid colour, or the image file of a bar texture tinted with it. The tint goes back to white before a solid colour, which it would multiply.
local function Paint(texture, file, r, g, b, a)
	texture:SetVertexColor(1, 1, 1, 1)
	if file then
		texture:SetTexture(file)
		texture:SetVertexColor(r, g, b, a or 1)
	else
		texture:SetColorTexture(r, g, b, a or 1)
	end
end

-- mock-scale ---------------------------------------------------------------------------------------------------------------------------------------------------------

-- One frame at the game's scale beside the same frame at the chosen scale. Both are children drawn with SetScale, so their size on the screen is the scale they have
-- against each other: the chosen scale over the game's. The sample frame is 150 by 76 units; a pair that would not fit the area is drawn smaller together.
local BOX_W, BOX_H, AREA_W, AREA_H, GRID = 150, 76, 280, 124, 10

local scale = { parts = {} }

-- The scale the game uses by its own setting: the UI scale it is set to (the uiscale variable), else its default scale for the screen
-- (GetDefaultScale, ScreenDocumentation.lua:10). Flat UI's own scale on UIParent is never read, so a profile that already has a custom scale draws the game's.
-- The scale on UIParent is the last resort, for a client that answers neither.
local function GameScale()
	if type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" then
		local ok, on = pcall(C_CVar.GetCVar, "useUiScale")
		if ok and on == "1" then
			local okScale, value = pcall(C_CVar.GetCVar, "uiscale")
			value = okScale and Plain(tonumber(value))
			if value then
				return value
			end
		end
	end
	if type(GetDefaultScale) == "function" then
		local ok, value = pcall(GetDefaultScale)
		value = ok and Plain(value)
		if value then
			return value
		end
	end
	local ok, current = pcall(UIParent.GetScale, UIParent)
	return ok and Plain(current) or 1
end

-- The scale the draft gives and how: "off", "custom", "pixel", "nofit" when pixel-perfect asks for a scale that is not applied, or "noheight" when the screen height
-- is not known (Scale.lua Wanted and ScaleStatus).
local function ChosenScale(game)
	if not ns.Get("general.scaleOn") then
		return game, "off"
	end
	local below = ns.Get("general.scaleBelow") == true
	if ns.Get("general.pixelPerfect") then
		local wanted, fits = ns.PixelScale()
		if wanted == nil then
			return game, "noheight"
		end
		if fits and (wanted >= 0.65 or below) then
			return wanted, "pixel"
		end
		return game, "nofit"
	end
	if below then
		return ns.Get("general.scaleSmall") / 100, "small"
	end
	return ns.Get("general.scale") / 100, "custom"
end

local function SampleBox(root, name)
	local box = Frame(root)
	box:SetSize(BOX_W, BOX_H)
	scale[name] = box
	box.outline = ns.Outline(box, box)
	local title = ns.OwnText(box, "OVERLAY", "GameFontHighlightSmall")
	title:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
	local number = ns.OwnText(box, "OVERLAY", "GameFontHighlightSmall")
	number:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -8)
	number:SetText("7,000")
	local parts = { title = title }
	for _, key in ipairs({ "health", "power" }) do
		local track = Texture(box, "BACKGROUND")
		track:SetColorTexture(0.05, 0.05, 0.05, 0.9)
		local fill = Texture(box, "ARTWORK")
		parts[key] = { track = track, fill = fill }
	end
	parts.health.track:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -28)
	parts.health.track:SetSize(BOX_W - 16, 12)
	parts.power.track:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -46)
	parts.power.track:SetSize(BOX_W - 16, 8)
	-- Health is 7,000 of 10,000 and power 4,200 of 6,000: both 70 percent.
	for _, key in ipairs({ "health", "power" }) do
		local part = parts[key]
		part.fill:SetPoint("TOPLEFT", part.track, "TOPLEFT", 0, 0)
		part.fill:SetPoint("BOTTOMLEFT", part.track, "BOTTOMLEFT", 0, 0)
		part.fill:SetWidth((BOX_W - 16) * 0.7)
		part.fill:SetTexCoord(0, 0.7, 0, 1)
	end
	box.sample = parts
	return box
end

function scale.build(stage)
	local root = Frame(stage)
	root:SetAllPoints(stage)
	scale.root = root
	SampleBox(root, "game")
	SampleBox(root, "chosen")
	scale.gameLabel = ns.OwnText(root, "OVERLAY", "GameFontHighlightSmall")
	scale.chosenLabel = ns.OwnText(root, "OVERLAY", "GameFontHighlightSmall")
	scale.gameLabel:SetPoint("TOP", scale.game, "BOTTOM", 0, -6)
	scale.chosenLabel:SetPoint("TOP", scale.chosen, "BOTTOM", 0, -6)
	-- Pixel-perfect: a line every ten units, each one unit wide, so the unit itself is visible.
	local grid = Frame(scale.chosen)
	grid:SetAllPoints(scale.chosen)
	scale.grid = grid
	scale.lines = {}
	for step = 1, math.floor(BOX_W / GRID) - 1 do
		local line = Texture(grid, "OVERLAY")
		line:SetColorTexture(1, 1, 1, 0.25)
		line:SetPoint("TOPLEFT", grid, "TOPLEFT", step * GRID, 0)
		line:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", step * GRID, 0)
		line:SetWidth(1)
		scale.lines[#scale.lines + 1] = line
	end
	for step = 1, math.floor(BOX_H / GRID) do
		local line = Texture(grid, "OVERLAY")
		line:SetColorTexture(1, 1, 1, 0.25)
		line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -step * GRID)
		line:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, -step * GRID)
		line:SetHeight(1)
		scale.lines[#scale.lines + 1] = line
	end
	grid:Hide()
	scale.parts["general.scaleOn"] = scale.chosen
	scale.parts["general.scale"] = scale.chosen
	scale.parts["general.pixelPerfect"] = scale.chosen
	scale.parts["general.pixelSize"] = grid
	scale.parts["general.scaleBelow"] = scale.chosen
	scale.parts["general.scaleSmall"] = scale.chosen
	return root
end

-- The border, the background and the bars of one sample frame, from the settings the modules paint with.
local function LookOfBox(box)
	local outline = box.outline
	if outline then
		ns.SetOutlineThickness(outline, ns.Get("general.thickness"))
		ns.SetOutlineColour(outline, ns.BorderRGB())
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(outline, r, g, b, ns.Get("general.backdropAlpha") / 100)
		ns.SetOutlineEdges(outline, not ns.Borderless())
	end
	local file = ns.BarTexture()
	local hr, hg, hb = ns.ClassColour()
	if hr == nil then
		hr, hg, hb = ns.Colour("general.reactionFriendly")
	end
	local pr, pg, pb = ns.PowerColour("MANA")
	if pr == nil then
		pr, pg, pb = 0, 0.4, 1
	end
	Paint(box.sample.health.fill, file, hr, hg, hb)
	Paint(box.sample.power.fill, file, pr, pg, pb)
	local ok, name = pcall(UnitName, "player")
	box.sample.title:SetText(ok and type(name) == "string" and not ns.IsSecret(name) and name or "Player")
end

-- Puts a box at one side of the middle of the area, its bottom edge 36 units up. An offset of a scaled frame is in that frame's units.
local function PlaceBox(box, side, factor)
	box:SetScale(factor)
	box:ClearAllPoints()
	box:SetPoint(side == "left" and "BOTTOMRIGHT" or "BOTTOMLEFT", scale.root, "BOTTOM", (side == "left" and -24 or 24) / factor, 36 / factor)
end

function scale.draw()
	if scale.root == nil then
		return
	end
	local game = GameScale()
	local wanted, mode = ChosenScale(game)
	local ratio = wanted / game
	local fit = math.min(1, AREA_W / (BOX_W * ratio), AREA_H / (BOX_H * ratio))
	PlaceBox(scale.game, "left", fit)
	PlaceBox(scale.chosen, "right", ratio * fit)
	LookOfBox(scale.game)
	LookOfBox(scale.chosen)
	scale.gameLabel:SetText("Game scale")
	if mode == "custom" then
		scale.chosenLabel:SetText(("Custom scale %d%%"):format(ns.Get("general.scale")))
	elseif mode == "small" then
		scale.chosenLabel:SetText(("Small scale %d%%"):format(ns.Get("general.scaleSmall")))
	elseif mode == "pixel" then
		scale.chosenLabel:SetText(("Pixel-perfect, %d px per unit"):format(ns.Get("general.pixelSize")))
	elseif mode == "noheight" then
		scale.chosenLabel:SetText("Screen height is not known. Game scale stays.")
	elseif mode == "nofit" then
		scale.chosenLabel:SetText("Pixel-perfect does not fit this screen. Game scale stays.")
	else
		scale.chosenLabel:SetText("Game scale")
	end
	scale.grid:SetShown(mode == "pixel")
end

ns.SetupDrawings["mock-scale"] = scale

-- mock-text ----------------------------------------------------------------------------------------------------------------------------------------------------------

-- Interface text, a number and a title in the chosen faces, over a plain world-coloured backdrop, and beside it the text of the game's own size setting. Sizes are the
-- game's sample sizes: a title 15, text 12, a number 12 and small print 8 units. The faces of "Game font" are the game's own files for each role (Fonts.lua ROLE).
local LATIN_FACE = { body = "Fonts\\FRIZQT__.TTF", numbers = "Fonts\\ARIALN.TTF", titles = "Fonts\\MORPHEUS.TTF" }
local nativeFace

-- The game's own face for each role. On a client whose language is not Latin its faces are other files and Flat UI changes none of them (Fonts.lua), so the file of
-- GameFontHighlightSmall is read once (a read only) and stands for every role.
local function GameFaces()
	if ns.FontsLatin() then
		return LATIN_FACE
	end
	if nativeFace == nil then
		nativeFace = LATIN_FACE
		local object = GameFontHighlightSmall
		if type(object) == "table" and type(object.GetFont) == "function" then
			local ok, file = pcall(object.GetFont, object)
			if ok and type(file) == "string" and not ns.IsSecret(file) and file ~= "" then
				nativeFace = { body = file, numbers = file, titles = file }
			end
		end
	end
	return nativeFace
end
local LINES = {
	{ key = "title", role = "titles", size = 15, text = "Flat UI options" },
	{ key = "body", role = "body", size = 12, text = "Windows, labels and most game text" },
	{ key = "number", role = "numbers", size = 12, text = "Gold 1,234,567 and 98.6%" },
	{ key = "small", role = "body", size = 8, text = "Small print in a tooltip" },
}

local text = { parts = {}, lines = {} }

function text.build(stage)
	local root = Frame(stage)
	root:SetAllPoints(stage)
	text.root = root
	local sample = Frame(root)
	sample:SetSize(340, 124)
	sample:SetPoint("RIGHT", root, "CENTER", -10, 0)
	local backdrop = Texture(sample, "BACKGROUND")
	backdrop:SetAllPoints(sample)
	backdrop:SetColorTexture(0.35, 0.38, 0.43, 1)
	text.sample = sample
	local previous
	for _, line in ipairs(LINES) do
		local fontString = ns.OwnText(sample, "OVERLAY", "GameFontHighlightSmall")
		if previous then
			fontString:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
		else
			fontString:SetPoint("TOPLEFT", sample, "TOPLEFT", 12, -12)
		end
		fontString:SetText(line.text)
		text.lines[line.key] = fontString
		previous = fontString
	end
	local game = Frame(root)
	game:SetSize(240, 124)
	game:SetPoint("LEFT", root, "CENTER", 10, 0)
	local dark = Texture(game, "BACKGROUND")
	dark:SetAllPoints(game)
	dark:SetColorTexture(0.18, 0.2, 0.24, 1)
	text.game = game
	text.gameLine = ns.OwnText(game, "OVERLAY", "GameFontHighlightSmall")
	text.gameLine:SetPoint("TOPLEFT", game, "TOPLEFT", 12, -12)
	text.gameLine:SetText("Pop-ups and dialogs")
	text.parts["fonts.enabled"] = sample
	text.parts["fonts.body"] = text.lines.body
	text.parts["fonts.numbers"] = text.lines.number
	text.parts["fonts.titles"] = text.lines.title
	text.parts["fonts.outline"] = sample
	text.parts["fonts.shadow"] = sample
	text.parts["fonts.size"] = sample
	text.parts["fonts.minimum"] = text.lines.small
	text.parts["fonts.gameTextSize"] = game
	return root
end

-- Sets the face, the height and the flags of a font string. A face the client refuses is put back to the game's own file for that role.
local function SetFace(fontString, file, size, flags, fallback)
	local ok, result = pcall(fontString.SetFont, fontString, file, size, flags)
	if (not ok or result == false) and file ~= fallback then
		pcall(fontString.SetFont, fontString, fallback, size, flags)
	end
end

local function SetShadow(fontString, on)
	local offset = on and 1 or 0
	pcall(fontString.SetShadowColor, fontString, 0, 0, 0, 1)
	pcall(fontString.SetShadowOffset, fontString, offset, -offset)
end

function text.draw()
	if text.root == nil then
		return
	end
	-- Off puts every font back to the game's: its faces, a size of 100, no smallest size, its outline and its shadow.
	local on = ns.Get("fonts.enabled") == true
	local percent = on and ns.Get("fonts.size") or 100
	local smallest = on and ns.Get("fonts.minimum") or 0
	local flags = on and ns.OutlineFlags(ns.Get("fonts.outline")) or ""
	local shadow = not on or ns.Get("fonts.shadow") ~= false
	local faces = GameFaces()
	local change = on and ns.FontsLatin()
	for _, line in ipairs(LINES) do
		local fontString = text.lines[line.key]
		local fallback = faces[line.role]
		local file = change and ns.FontFile(ns.Get("fonts." .. line.role)) or fallback
		SetFace(fontString, file, math.max(line.size * percent / 100, smallest), flags, fallback)
		SetShadow(fontString, shadow)
	end
	local game = ns.Get("fonts.gameTextSize") / 100
	SetFace(text.gameLine, faces.body, 11 * game, "", faces.body)
	SetShadow(text.gameLine, true)
end

ns.SetupDrawings["mock-text"] = text
