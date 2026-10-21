local _, ns = ...

-- Setup drawings for the windows steps: mock-window (Window look and controls, Window backdrops), mock-window-set (Which windows) and mock-bag-slots (Bags and
-- items). Each is { build(stage), draw(stage), parts }. build makes the frames of one drawing on a stage once, all marked ns.Own so that no module restyles them;
-- draw reads only ns.Get and paints the frames again, so run under the draft view it draws the draft. parts maps a saved path to the region of the drawing it
-- changes, for the mark on a hovered row. A frame the windows module would style is drawn in one of two looks: flat (an ns.Outline with the fill the module gives
-- it, FUI/Windows.lua Fill 484-494) or the game's, which is what stays when a switch is off (Windows.lua IsOn 513-516). The game's look is the atlas of the part when
-- C_Texture.GetAtlasInfo answers, else a plain grey, with one Game look label at the corner of the drawing (design.md 4.4).
-- The numbers are fixed samples, drawn at 80 percent of the real size.

local KEY = "windows"
local Own = ns.Own

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True when the module would restyle a frame: the page is on, the window's switch is on when it has one, and the part's own row is on.
local function Live(group, option)
	return Opt("enabled") == true and (group == nil or Opt(group) == true) and (option == nil or Opt(option) == true)
end

local EDGE, GREY = { 0.62, 0.62, 0.62 }, { 0.3, 0.3, 0.3 }
local GOLD, WHITE = { 1, 0.82, 0 }, { 1, 1, 1 }
local HOVER = { 1, 1, 1, 0.3 }
local ICONS = { 134400, 135940, 135964, 136089 }

-- Frames and regions --------------------------------------------------------------------------------------------------

local function Frame(parent, width, height)
	local frame = CreateFrame("Frame", nil, parent)
	Own[frame] = true
	if width then
		frame:SetSize(width, height)
	end
	return frame
end

local function Tex(parent, layer, sub)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	Own[texture] = true
	return texture
end

local function Text(parent, font, justify, width)
	local text = ns.OwnText(parent, "OVERLAY", font or "GameFontHighlightSmall")
	if not text then
		error("no text", 0)
	end
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(false)
	if width then
		text:SetWidth(width)
	end
	return text
end

local function Put(region, point, relative, relativePoint, x, y)
	region:ClearAllPoints()
	region:SetPoint(point, relative, relativePoint or point, x or 0, y or 0)
end

-- A texture over a rectangle of its parent.
local function Patch(parent, layer, sub, x, y, width, height)
	local texture = Tex(parent, layer, sub)
	texture:SetSize(width, height)
	Put(texture, "TOPLEFT", parent, "TOPLEFT", x, -y)
	return texture
end

local function Paint(texture, colour, alpha)
	texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or colour[4] or 1)
end

-- A text at a place on its parent, in a colour.
local function Label(parent, x, y, width, font, justify, colour)
	local text = Text(parent, font, justify, width)
	Put(text, "TOPLEFT", parent, "TOPLEFT", x, -y)
	if colour then
		text:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
	return text
end

-- Plates -----------------------------------------------------------------------------------------------------------

-- The colour and opacity a kind of fill has in the module: the window colour at the Window opacity, a solid window colour for a menu or list that lies over other
-- windows, or the button and slot colour.
local function FillOf(kind)
	if kind == "panel" then
		local r, g, b = ns.Colour(KEY .. ".panel")
		return r, g, b, 1
	end
	local r, g, b = ns.Colour("general.backdrop")
	return r, g, b, kind == "solid" and 0.95 or Opt("opacity") / 100
end

-- A frame with both looks: an outline for the flat one, two textures for the game's.
local function Plate(parent, x, y, width, height, fill, bare)
	local frame = Frame(parent, width, height)
	Put(frame, "TOPLEFT", parent, "TOPLEFT", x, -y)
	local plate = { frame = frame, fill = fill, bare = bare }
	plate.edge = Tex(frame, "BACKGROUND", -6)
	plate.edge:SetAllPoints(frame)
	plate.body = Tex(frame, "BACKGROUND", -5)
	Put(plate.body, "TOPLEFT", frame, "TOPLEFT", 2, -2)
	plate.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	plate.outline = ns.Outline(frame, frame)
	if not plate.outline then
		error("no outline", 0)
	end
	return plate
end

-- True while a drawing has a part in the game's look; the Game look label shows then.
local gameShown = false

local function AtlasAnswers(atlas)
	local api = _G.C_Texture
	if not atlas or type(api) ~= "table" or ns.IsSecret(api) or type(api.GetAtlasInfo) ~= "function" then
		return false
	end
	local ok, info = pcall(api.GetAtlasInfo, atlas)
	return ok and type(info) == "table" and not ns.IsSecret(info)
end

-- Draws a plate flat, or in the game's look: the atlas of the part when the client answers for it, else a plain grey.
local function Look(plate, flat, atlas)
	if flat then
		if plate.bare then
			ns.SetOutline(plate.outline, false, false)
		else
			local r, g, b, a = FillOf(plate.fill)
			ns.SetOutlineFill(plate.outline, r, g, b, a)
			ns.SetOutline(plate.outline, true, true)
		end
		plate.edge:Hide()
		plate.body:Hide()
	else
		gameShown = true
		ns.SetOutline(plate.outline, false, false)
		if AtlasAnswers(atlas) then
			plate.body:SetAtlas(atlas)
			plate.edge:Hide()
		else
			Paint(plate.edge, EDGE)
			Paint(plate.body, GREY)
			plate.edge:Show()
		end
		plate.body:Show()
	end
end

-- Glyphs: a chevron, a cross or a tick of two lines, as the module draws them (Windows.lua SHAPES 396-403, Glyph 413-425).
local SHAPES = {
	x = { { -1, 1, 1, -1 }, { -1, -1, 1, 1 } },
	up = { { -1, -0.5, 0, 0.5 }, { 0, 0.5, 1, -0.5 } },
	down = { { -1, 0.5, 0, -0.5 }, { 0, -0.5, 1, 0.5 } },
	tick = { { -1, 0, -0.35, -0.7 }, { -0.35, -0.7, 1, 0.8 } },
	eye = { { -1, 0, 0, 0.7 }, { 0, 0.7, 1, 0 } },
}

local function Glyph(parent, target, size, x, y)
	local glyph = { lines = {}, size = size, target = target, x = x or 0, y = y or 0 }
	for index = 1, 2 do
		local line = parent:CreateLine(nil, "OVERLAY", nil, 2)
		Own[line] = true
		line:SetThickness(1.5)
		glyph.lines[index] = line
	end
	return glyph
end

local function Shape(glyph, shape, colour, alpha, shown, size)
	local half = (size or glyph.size) / 2
	for index, line in ipairs(glyph.lines) do
		local s = SHAPES[shape][index]
		line:SetStartPoint("CENTER", glyph.target, glyph.x + s[1] * half, glyph.y + s[2] * half)
		line:SetEndPoint("CENTER", glyph.target, glyph.x + s[3] * half, glyph.y + s[4] * half)
		line:SetColorTexture(colour[1], colour[2], colour[3], alpha)
		line:SetShown(shown)
	end
end

-- The title of a window: size and colour from the rows when the module restyles the window, else the game's.
local function Title(text, flat)
	local spec = {}
	if flat then
		spec.percent = Opt("titleSize")
		if Opt("titleOwn") == true then
			spec.r, spec.g, spec.b = ns.Colour(KEY .. ".titleColour")
			spec.a = 1
		end
	end
	ns.TextStyle(text, spec)
end

-- The colour of an item quality, the game's when it answers (Items.lua LevelColour 232-252).
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 } }

local function QualityColour(quality)
	local manager = _G.ColorManager
	if type(manager) == "table" and not ns.IsSecret(manager) and type(manager.GetColorDataForBagItemQuality) == "function" then
		local ok, colour = pcall(manager.GetColorDataForBagItemQuality, quality)
		if ok and type(colour) == "table" and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
			return colour.r, colour.g, colour.b
		end
	end
	local sample = QUALITY[quality]
	return sample[1], sample[2], sample[3]
end

local function Crop(texture, fraction)
	texture:SetTexCoord(fraction, 1 - fraction, fraction, 1 - fraction)
end

-- The two notes at the foot of a drawing: the size it is shown at, and Game look while any part is left to the game.
local function Notes(S, root)
	S.size = Label(root, 0, 0, 200, nil, "RIGHT", { 0.7, 0.7, 0.7 })
	Put(S.size, "TOPRIGHT", root, "BOTTOMRIGHT", 0, -4)
	S.size:SetText("Shown at 80% size.")
	S.game = Label(root, 0, 0, 200, nil, "LEFT", { 0.7, 0.7, 0.7 })
	Put(S.game, "TOPLEFT", root, "BOTTOMLEFT", 0, -4)
	S.game:SetText("Game look")
end

local function Begin()
	gameShown = false
end

local function Finish(S)
	S.game:SetShown(gameShown)
end

local function Register(id, drawing)
	ns.SetupDrawings = ns.SetupDrawings or {}
	ns.SetupDrawings[id] = drawing
end

-- mock-window -----------------------------------------------------------------------------------------------------------

-- The icon side of a side tab for each size, as drawn here: the module's 42, 36 and 30 and the game's 50 (Windows.lua TAB_ICONS 786), at 0.8 like the rest of the drawing.
local TAB_SIDE = { game = 40, large = 34, medium = 29, small = 24 }
local TAB_GAME_W, TAB_GAME_H = 44, 48
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

local function BuildChrome(S, win)
	local frame = win.frame
	S.title = Label(frame, 0, 0, 200, "GameFontNormal", "CENTER")
	Put(S.title, "TOP", frame, "TOP", 0, -8)
	S.title:SetText("Mail")
	-- The game's round picture at the top left.
	local portrait = Frame(frame, 30, 30)
	Put(portrait, "TOPLEFT", frame, "TOPLEFT", 6, -6)
	local picture = Tex(portrait, "ARTWORK", 0)
	picture:SetAllPoints(portrait)
	Paint(picture, { 0.4, 0.4, 0.4 })
	if type(SetPortraitTexture) == "function" then
		pcall(SetPortraitTexture, picture, "player")
	end
	S.portrait = portrait
	-- Close button.
	S.close = Plate(frame, 272, 6, 18, 18, "panel", true)
	S.closeGlyph = Glyph(S.close.frame, S.close.frame, 10)
end

local function BuildControls(S, win)
	local frame = win.frame
	-- Text box and dropdown.
	S.edit = Plate(frame, 12, 46, 150, 20, "panel")
	S.editText = Label(S.edit.frame, 6, 4, 130, nil, "LEFT", WHITE)
	S.editText:SetText("Priestly")
	S.drop = Plate(frame, 12, 72, 150, 20, "panel")
	S.dropText = Label(S.drop.frame, 6, 4, 110, nil, "LEFT", WHITE)
	S.dropText:SetText("All")
	S.dropArrow = Glyph(S.drop.frame, S.drop.frame, 8, 62, 0)
	S.dropBox = Patch(S.drop.frame, "ARTWORK", 1, 130, 2, 18, 16)
	-- Check box.
	S.check = Plate(frame, 12, 100, 16, 16, "panel")
	S.tick = Patch(S.check.frame, "OVERLAY", 1, 4, 4, 8, 8)
	S.checkText = Label(frame, 34, 102, 100, nil, "LEFT", WHITE)
	S.checkText:SetText("Auto")
	-- Progress bar.
	S.bar = Plate(frame, 12, 124, 150, 14, "window")
	S.barFill = Patch(S.bar.frame, "ARTWORK", 0, 0, 0, 96, 14)
	Paint(S.barFill, { 0.15, 0.6, 0.25 })
	-- Buttons, the first with the pointer over it.
	S.accept = Plate(frame, 12, 146, 70, 20, "panel")
	S.acceptText = Label(S.accept.frame, 0, 4, 70, nil, "CENTER", WHITE)
	S.acceptText:SetText("Accept")
	S.acceptHover = Patch(S.accept.frame, "OVERLAY", 1, 0, 0, 70, 20)
	S.cancel = Plate(frame, 92, 146, 70, 20, "panel")
	S.cancelText = Label(S.cancel.frame, 0, 4, 70, nil, "CENTER", WHITE)
	S.cancelText:SetText("Cancel")
	-- Two item slots with a picture each.
	S.slots = {}
	for index = 1, 2 do
		local slot = Plate(frame, 176 + (index - 1) * 36, 46, 30, 30, "panel")
		slot.icon = Patch(slot.frame, "ARTWORK", 0, 1, 1, 28, 28)
		slot.icon:SetTexture(ICONS[index + 1])
		S.slots[index] = slot
	end
	-- Scroll bar.
	local scroll = Frame(frame, 14, 106)
	Put(scroll, "TOPLEFT", frame, "TOPLEFT", 264, -44)
	S.scroll = scroll
	S.track = Patch(scroll, "BACKGROUND", 0, 0, 14, 14, 78)
	S.thumb = Patch(scroll, "ARTWORK", 0, 0, 22, 14, 30)
	S.arrowTop = Patch(scroll, "ARTWORK", 1, 0, 0, 14, 14)
	S.arrowBottom = Patch(scroll, "ARTWORK", 1, 0, 92, 14, 14)
	S.up = Glyph(scroll, scroll, 6, 0, 46)
	S.down = Glyph(scroll, scroll, 6, 0, -46)
end

local function BuildTabs(S, win)
	local frame = win.frame
	S.tabs = {}
	for index, name in ipairs({ "Inbox", "Send", "Log" }) do
		local tab = Plate(frame, 8 + (index - 1) * 66, 176, 62, 18, "panel")
		tab.text = Label(tab.frame, 0, 3, 62, nil, "CENTER", WHITE)
		tab.text:SetText(name)
		S.tabs[index] = tab
	end
	S.tabHover = Patch(S.tabs[2].frame, "OVERLAY", 1, 0, 0, 62, 18)
	S.side = {}
	for index = 1, 3 do
		local tab = Plate(frame, 298, 24, TAB_GAME_W, TAB_GAME_H, "panel")
		tab.icon = Tex(tab.frame, "ARTWORK", 0)
		tab.icon:SetTexture(ICONS[index])
		tab.selected = Tex(tab.frame, "OVERLAY", 1)
		tab.selected:SetAllPoints(tab.frame)
		tab.corners = {}
		for corner = 1, 4 do
			tab.corners[corner] = Tex(tab.frame, "OVERLAY", 2)
			tab.corners[corner]:SetSize(3, 3)
		end
		S.side[index] = tab
	end
end

local function BuildLists(S, root)
	-- A right-click menu, a name completion list and a toast.
	S.menu = Plate(root, 346, 0, 100, 58, "solid")
	S.menuLines = {}
	for index, name in ipairs({ "Whisper", "Invite", "Ignore" }) do
		S.menuLines[index] = Label(S.menu.frame, 8, 6 + (index - 1) * 16, 84, nil, "LEFT", WHITE)
		S.menuLines[index]:SetText(name)
	end
	S.menuHover = Patch(S.menu.frame, "OVERLAY", 1, 3, 20, 94, 16)
	S.names = Plate(root, 454, 0, 96, 58, "solid")
	S.nameLines = {}
	for index, name in ipairs({ "Priest", "Priestly", "Priestess" }) do
		S.nameLines[index] = Label(S.names.frame, 8, 6 + (index - 1) * 16, 80, nil, "LEFT", WHITE)
		S.nameLines[index]:SetText(name)
	end
	S.toast = Plate(root, 558, 0, 100, 40, "solid")
	S.toastHead = Label(S.toast.frame, 8, 6, 84, nil, "LEFT", GOLD)
	S.toastHead:SetText("Battle.net")
	S.toastBody = Label(S.toast.frame, 8, 21, 84, nil, "LEFT", WHITE)
	S.toastBody:SetText("Mara is online")
	-- A list with a header and two lines, the second with the pointer over it.
	S.header = Plate(root, 346, 66, 312, 16, "panel")
	S.headerText = {}
	for index, spot in ipairs({ { 8, "Name" }, { 170, "Level" }, { 230, "Zone" } }) do
		S.headerText[index] = Label(S.header.frame, spot[1], 2, 70, nil, "LEFT", WHITE)
		S.headerText[index]:SetText(spot[2])
	end
	S.lines = {}
	for index, row in ipairs({ { "Brennan", "60", "Stormwind" }, { "Mara", "58", "Ironforge" } }) do
		local line = { frame = Frame(root, 312, 14), cells = {} }
		Put(line.frame, "TOPLEFT", root, "TOPLEFT", 346, -(84 + (index - 1) * 14))
		line.stripe = Tex(line.frame, "BACKGROUND", -4)
		line.stripe:SetAllPoints(line.frame)
		line.tint = Tex(line.frame, "OVERLAY", 1)
		line.tint:SetAllPoints(line.frame)
		for cell, spot in ipairs({ 8, 170, 230 }) do
			line.cells[cell] = Label(line.frame, spot, 1, 120, nil, "LEFT", WHITE)
			line.cells[cell]:SetText(row[cell])
		end
		S.lines[index] = line
	end
end

local function BuildArt(S, root)
	local names = { "Race background", "Talent backdrop", "Eye", "Role buttons" }
	S.tiles = {}
	for index, name in ipairs(names) do
		local tile = Plate(root, 346 + (index - 1) * 80, 122, 72, 76, "panel")
		tile.art = Patch(tile.frame, "ARTWORK", 0, 3, 3, 66, 54)
		tile.caption = Label(tile.frame, 0, 62, 72, nil, "CENTER", WHITE)
		tile.caption:SetText(name)
		S.tiles[index] = tile
	end
	local eye = S.tiles[3]
	eye.pupil = Patch(eye.frame, "OVERLAY", 1, 32, 26, 8, 8)
	eye.glyph = Glyph(eye.frame, eye.frame, 36, 0, 8)
	eye.glyph2 = Glyph(eye.frame, eye.frame, 36, 0, 8)
	local role = S.tiles[4]
	role.plates, role.icons = {}, {}
	for index = 1, 3 do
		role.plates[index] = Patch(role.frame, "ARTWORK", 1, 4 + (index - 1) * 21, 18, 20, 20)
		role.icons[index] = Patch(role.frame, "OVERLAY", 1, 8 + (index - 1) * 21, 22, 12, 12)
		Paint(role.icons[index], { 0.78, 0.78, 0.78 })
	end
end

local ROLE_ART = { { 0.4, 0.4, 0.4 }, { 0.5, 0.5, 0.5 }, { 0.6, 0.6, 0.6 } }

local function BuildWindow(stage)
	local S = { parts = {} }
	local root = Frame(stage, 658, 204)
	Put(root, "CENTER", stage, "CENTER", 0, 0)
	S.root = root
	Notes(S, root)
	local win = Plate(root, 0, 0, 296, 176, "window")
	S.win = win
	BuildChrome(S, win)
	BuildControls(S, win)
	BuildTabs(S, win)
	BuildLists(S, root)
	BuildArt(S, root)
	local parts = S.parts
	parts["windows.enabled"], parts["windows.opacity"] = root, win.frame
	parts["windows.panel"], parts["windows.buttons"], parts["windows.accent"] = S.accept.frame, S.accept.frame, S.accept.frame
	parts["windows.crop"], parts["windows.portrait"] = S.slots[1].icon, S.portrait
	parts["windows.tabs"], parts["windows.scroll"], parts["windows.checks"] = S.tabs[1].frame, S.scroll, S.check.frame
	parts["windows.sideTabs"], parts["windows.squareTabs"], parts["windows.sideTabSize"] = S.side[1].frame, S.side[1].frame, S.side[1].frame
	parts["windows.inputs"], parts["windows.bars"] = S.edit.frame, S.bar.frame
	parts["windows.popupMenus"], parts["windows.nameList"], parts["windows.toasts"] = S.menu.frame, S.names.frame, S.toast.frame
	parts["windows.rows"] = S.header.frame
	parts["windows.titleSize"], parts["windows.titleOwn"], parts["windows.titleColour"] = S.title, S.title, S.title
	parts["windows.raceArt"], parts["windows.bookArt"] = S.tiles[1].frame, S.tiles[2].frame
	parts["windows.eye"], parts["windows.roleArt"] = S.tiles[3].frame, S.tiles[4].frame
	return S
end

-- The window is titled Mail, so it is restyled only while the group of vendor, mail, quest, trade and trainer windows is on (Windows.lua IsOn 513-516).
local function Mail(option)
	return Live("npc", option)
end

local function DrawChrome(S)
	local window = Mail()
	Look(S.win, window)
	Title(S.title, window)
	S.portrait:SetShown(not window or Opt("portrait") == true)
	local buttons = Mail("buttons")
	Look(S.close, buttons, "RedButton-Exit")
	Shape(S.closeGlyph, "x", WHITE, buttons and 0.6 or 1, true, buttons and 10 or 8)
end

local function DrawControls(S)
	local flat = Mail("inputs")
	Look(S.edit, flat)
	Look(S.drop, flat)
	S.dropBox:SetShown(not flat)
	gameShown = gameShown or not flat
	Paint(S.dropBox, EDGE)
	Shape(S.dropArrow, "down", WHITE, 0.8, true)
	flat = Mail("checks")
	Look(S.check, flat)
	Paint(S.tick, GOLD, flat and 0.8 or 1)
	flat = Mail("bars")
	Look(S.bar, flat, "common-stat-bar-BG")
	flat = Mail("buttons")
	Look(S.accept, flat)
	Look(S.cancel, flat)
	S.acceptText:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
	S.cancelText:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 1)
	local r, g, b = ns.Colour(KEY .. ".accent")
	S.acceptHover:SetColorTexture(r, g, b, 0.25)
	S.acceptHover:SetShown(flat)
	-- Item slots.
	flat = Mail("slots")
	local crop = flat and Opt("crop") / 100 or 0
	for _, slot in ipairs(S.slots) do
		Look(slot, flat)
		Crop(slot.icon, crop)
	end
	-- Scroll bar.
	flat = Mail("scroll")
	if flat then
		Paint(S.track, { 0, 0, 0 }, 0.3)
		S.thumb:SetColorTexture(r, g, b, 0.25)
	else
		Paint(S.track, GREY)
		Paint(S.thumb, EDGE)
		gameShown = true
	end
	for _, arrow in ipairs({ S.arrowTop, S.arrowBottom }) do
		Paint(arrow, EDGE)
		arrow:SetShown(not flat)
	end
	Shape(S.up, "up", WHITE, flat and 0.6 or 1, true)
	Shape(S.down, "down", WHITE, flat and 0.6 or 1, true)
end

local function DrawTabs(S)
	local flat = Mail("tabs")
	for index, tab in ipairs(S.tabs) do
		Look(tab, flat)
		local colour = index == 1 and GOLD or { 0.7, 0.7, 0.7 }
		tab.text:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
	local r, g, b = ns.Colour(KEY .. ".accent")
	S.tabHover:SetColorTexture(r, g, b, 0.25)
	S.tabHover:SetShown(flat)
	-- Side tabs: a flat box round the icon at the chosen size, or the game's larger tab.
	flat = Mail("sideTabs")
	local square = flat and Opt("squareTabs") == true
	local side = TAB_SIDE[Opt("sideTabSize")] or TAB_SIDE.game
	local width, height = side, side
	if not flat then
		width, height = TAB_GAME_W, TAB_GAME_H
	end
	local top = 8
	for index, tab in ipairs(S.side) do
		tab.frame:SetSize(width, height)
		Put(tab.frame, "TOPLEFT", S.win.frame, "TOPLEFT", 298, -top)
		top = top + height + 4
		Look(tab, flat)
		tab.icon:ClearAllPoints()
		if flat then
			tab.icon:SetAllPoints(tab.frame)
		else
			tab.icon:SetPoint("TOPLEFT", tab.frame, "TOPLEFT", 1, -3)
			tab.icon:SetPoint("BOTTOMRIGHT", tab.frame, "BOTTOMRIGHT", -1, 3)
		end
		Crop(tab.icon, square and Opt("crop") / 100 or 0)
		tab.selected:SetColorTexture(1, 1, 1, index == 1 and flat and HOVER[4] or 0)
		local cr, cg, cb = ns.Colour("general.backdrop")
		for corner, piece in ipairs(tab.corners) do
			local point = CORNERS[corner]
			Put(piece, point, tab.frame, point, 0, 0)
			piece:SetColorTexture(cr, cg, cb, 1)
			piece:SetShown(flat and not square)
		end
	end
end

local function DrawLists(S)
	local flat = Live("popupMenus")
	Look(S.menu, flat)
	local r, g, b = ns.Colour(KEY .. ".accent")
	S.menuHover:SetColorTexture(r, g, b, 0.25)
	S.menuHover:SetShown(flat)
	Look(S.names, Live("nameList"))
	Look(S.toast, Live("toasts"))
	flat = Live(nil, "rows")
	Look(S.header, flat)
	for index, line in ipairs(S.lines) do
		if flat then
			line.tint:SetColorTexture(r, g, b, index == 2 and 0.25 or 0)
			line.stripe:SetColorTexture(0, 0, 0, 0)
			if index == 1 then
				line.tint:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
			end
		else
			line.tint:SetColorTexture(0, 0, 0, 0)
			Paint(line.stripe, index == 1 and { 0.34, 0.34, 0.34 } or { 0.24, 0.24, 0.24 })
		end
	end
end

-- The game's picture shows when the window is left to the game or the row asks for it (Windows.lua Kind fades 690-700).
local function ArtShown(group, option)
	return not Live(group) or Opt(option) == true
end

local function DrawArt(S)
	local window = Live()
	for _, tile in ipairs(S.tiles) do
		Look(tile, window)
	end
	local race, book, eye, role = ArtShown("character", "raceArt"), ArtShown("spells", "bookArt"), ArtShown("groupfinder", "eye"), ArtShown("groupfinder", "roleArt")
	S.tiles[1].art:SetShown(race)
	Paint(S.tiles[1].art, { 0.42, 0.42, 0.42 })
	S.tiles[2].art:SetShown(book)
	Paint(S.tiles[2].art, { 0.36, 0.36, 0.36 })
	local tile = S.tiles[3]
	tile.art:SetShown(false)
	tile.pupil:SetShown(eye)
	Paint(tile.pupil, GOLD)
	Shape(tile.glyph, "eye", GOLD, 1, eye)
	Shape(tile.glyph2, "eye", GOLD, 1, eye, -36)
	tile = S.tiles[4]
	tile.art:SetShown(false)
	for index = 1, 3 do
		Paint(tile.plates[index], ROLE_ART[index])
		tile.plates[index]:SetShown(role)
	end
end

local window = { state = setmetatable({}, { __mode = "k" }), parts = {} }

function window.build(stage)
	local S = BuildWindow(stage)
	window.state[stage] = S
	window.parts = S.parts
end

function window.draw(stage)
	local S = window.state[stage]
	if not S then
		return
	end
	Begin()
	-- Window size (Positions page) sets the size of the windows the add-on moves; the drawing follows it.
	local percent = ns.Get("movers.windowSize")
	percent = type(percent) == "number" and percent > 0 and percent or 100
	S.win.frame:SetScale(percent / 100)
	S.size:SetText(("Shown at %d%% size."):format(math.floor(80 * percent / 100 + 0.5)))
	DrawChrome(S)
	DrawControls(S)
	DrawTabs(S)
	DrawLists(S)
	DrawArt(S)
	Finish(S)
end

Register("mock-window", window)

-- mock-window-set -----------------------------------------------------------------------------------------------------

-- Each kind of window by the saved key of its switch, and the name under it.
local SET = {
	{ "character", "Character" }, { "groupfinder", "Looking For Group" }, { "social", "Friends" }, { "npc", "Vendor and mail" },
	{ "bags", "Bags and bank" }, { "spells", "Spellbook" }, { "menus", "Game menu" }, { "auction", "Auction house" },
	{ "guild", "Guild" }, { "inspect", "Inspect" }, { "macros", "Macros" }, { "maps", "World map" }, { "more", "Collections" },
}

local function BuildSet(stage)
	local S = { parts = {}, minis = {} }
	local root = Frame(stage, 658, 204)
	Put(root, "CENTER", stage, "CENTER", 0, 0)
	S.root = root
	Notes(S, root)
	S.parts["windows.enabled"] = root
	for index, entry in ipairs(SET) do
		local column, row = (index - 1) % 7, math.floor((index - 1) / 7)
		local mini = { key = entry[1] }
		mini.win = Plate(root, column * 94, row * 100, 86, 64, "window")
		local frame = mini.win.frame
		mini.bar = Patch(frame, "ARTWORK", 0, 8, 8, 40, 4)
		mini.slots = { Plate(frame, 8, 22, 16, 16, "panel"), Plate(frame, 28, 22, 16, 16, "panel") }
		mini.button = Plate(frame, 8, 44, 44, 14, "panel")
		mini.check = Glyph(frame, frame, 9, 31, 20)
		mini.caption = Label(root, column * 94, row * 100 + 68, 86, nil, "CENTER", WHITE)
		mini.caption:SetText(entry[2])
		S.minis[index] = mini
		S.parts["windows." .. entry[1]] = frame
	end
	return S
end

local set = { state = setmetatable({}, { __mode = "k" }), parts = {} }

function set.build(stage)
	local S = BuildSet(stage)
	set.state[stage] = S
	set.parts = S.parts
end

function set.draw(stage)
	local S = set.state[stage]
	if not S then
		return
	end
	Begin()
	for _, mini in ipairs(S.minis) do
		local flat = Live(mini.key)
		Look(mini.win, flat)
		Paint(mini.bar, flat and { 0.85, 0.85, 0.85 } or EDGE)
		for _, slot in ipairs(mini.slots) do
			Look(slot, flat)
		end
		Look(mini.button, flat)
		Shape(mini.check, "tick", { 0.4, 0.85, 0.4 }, 1, flat)
	end
	Finish(S)
end

Register("mock-window-set", set)

-- mock-bag-slots -------------------------------------------------------------------------------------------------------------

-- Samples: quality 0 to 4, stack count, item level, and the flags j (poor item with a vendor price) and n (new item).
local ITEMS = {
	{ 2, nil, 23 }, { 1, 12 }, { 4, nil, 41 }, { 0, nil, nil, "j" }, { 3, nil, 36 }, { 1, 20 }, { 2, 5 }, { 0, 3, nil, "j" },
	{ 2, nil, 21, "n" }, { 3, nil, 34 }, { 1 }, { 4, nil, 45 }, { 1, 8 }, { 2, nil, 26 }, { 3, 2 }, { 0, nil, nil, "j" },
	{ 2, 18 }, { 1, nil, 12 }, { 3, nil, 38 }, { 2, nil, 22 }, { 4, 1 }, { 1, 6 }, { 2, nil, 25 }, { 3, nil, 33 },
}
local GEAR = { { 3, nil, 36 }, { 4, nil, 44 }, { 2, nil, 24 }, { 3, nil, 35 }, { 2, nil, 22 }, { 4, nil, 43 }, { 1, nil, 12 }, { 3, nil, 37 } }
local MIN_QUALITY = { all = 0, uncommon = 2, rare = 3, epic = 4 }
local HOVERED = 7
local SORT_BARS = { 10, 7, 4 }
local SLOT = 30

local function NewSlot(parent, sample, index)
	local slot = Plate(parent, 0, 0, SLOT, SLOT, "panel")
	slot.sample = sample
	slot.index = index
	slot.parent = parent
	local frame = slot.frame
	slot.icon = Patch(frame, "ARTWORK", 0, 1, 1, SLOT - 2, SLOT - 2)
	slot.icon:SetTexture(ICONS[(index - 1) % #ICONS + 1])
	slot.dim = Patch(frame, "OVERLAY", 3, 1, 1, SLOT - 2, SLOT - 2)
	Paint(slot.dim, { 0, 0, 0 }, 0.5)
	slot.glow = Patch(frame, "OVERLAY", 2, 0, 0, SLOT, SLOT)
	Paint(slot.glow, { 1, 0.9, 0.3 }, 0.35)
	slot.tint = Patch(frame, "OVERLAY", 1, 0, 0, SLOT, SLOT)
	slot.count = ns.OwnText(frame, "OVERLAY", "NumberFontNormal")
	slot.level = ns.OwnText(frame, "OVERLAY", "NumberFontNormal")
	if not slot.count or not slot.level then
		error("no text", 0)
	end
	slot.count:SetJustifyH("RIGHT")
	Put(slot.count, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	Put(slot.level, "BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
	if sample[2] then
		slot.count:SetText(tostring(sample[2]))
	end
	if sample[3] then
		slot.level:SetText(tostring(sample[3]))
	end
	local ok, file = pcall(slot.level.GetFont, slot.level)
	slot.levelFile = ok and type(file) == "string" and file or nil
	return slot
end

local function NewBagWindow(root, title)
	local win = Plate(root, 0, 0, 100, 100, "window")
	win.title = Label(win.frame, 0, 0, 120, "GameFontNormal", "CENTER")
	Put(win.title, "TOP", win.frame, "TOP", 0, -7)
	win.title:SetText(title)
	win.sort = Plate(win.frame, 0, 0, 16, 16, "panel")
	win.bars = {}
	for index, width in ipairs(SORT_BARS) do
		win.bars[index] = Patch(win.sort.frame, "OVERLAY", 2, 3, 3 + (index - 1) * 4, width, 2)
	end
	return win
end

local function BuildBags(stage)
	local S = { parts = {}, slots = {}, gear = {} }
	local root = Frame(stage, 658, 204)
	Put(root, "CENTER", stage, "CENTER", 0, 0)
	S.root = root
	Notes(S, root)
	S.a = NewBagWindow(root, "Backpack")
	S.b = NewBagWindow(root, "Bag")
	S.char = NewBagWindow(root, "Character")
	S.char.sort.frame:Hide()
	for index, sample in ipairs(ITEMS) do
		S.slots[index] = NewSlot(S.a.frame, sample, index)
	end
	for index, sample in ipairs(GEAR) do
		S.gear[index] = NewSlot(S.char.frame, sample, index)
	end
	local parts = S.parts
	parts["windows.enabled"] = root
	parts["windows.slots"], parts["windows.quality"] = S.slots[1].frame, S.slots[3].frame
	parts["windows.slotTints"], parts["windows.qualityMin"] = S.slots[HOVERED].frame, S.slots[1].frame
	parts["windows.countSize"], parts["windows.ilvlBags"] = S.slots[2].count, S.slots[1].level
	parts["windows.ilvlSize"], parts["windows.ilvlColour"] = S.slots[1].level, S.slots[1].level
	parts["windows.ilvlCharacter"] = S.char.frame
	parts["windows.newGlow"], parts["windows.junkDim"] = S.slots[9].frame, S.slots[4].frame
	parts["windows.combinedBags"], parts["windows.sortButton"] = S.a.frame, S.a.sort.frame
	return S
end

-- One slot in a window at a place: flat or the game's, with the border, glow, dim, count and item level the rows give it.
local function DrawSlot(slot, flat, bag)
	local live = Opt("enabled") == true
	local quality, count, level, flags = slot.sample[1], slot.sample[2], slot.sample[3], slot.sample[4]
	Look(slot, flat)
	Crop(slot.icon, flat and Opt("crop") / 100 or 0)
	local r, g, b
	if flat and Opt("quality") == true and quality >= (MIN_QUALITY[Opt("qualityMin")] or 0) then
		r, g, b = QualityColour(quality)
	end
	ns.SetOutlineColour(slot.outline, r, g, b)
	slot.dim:SetShown(live and bag and Opt("junkDim") == true and flags == "j")
	slot.glow:SetShown(bag and flags == "n" and not (live and not Opt("newGlow")))
	if slot.index == HOVERED and bag then
		if flat and Opt("slotTints") == true then
			slot.tint:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
		else
			slot.tint:SetColorTexture(1, 0.82, 0.1, 0.35)
		end
		slot.tint:Show()
	else
		slot.tint:Hide()
	end
	slot.count:SetShown(count ~= nil)
	ns.TextSize(slot.count, live and Opt("countSize") or 100)
	local want = live and level ~= nil and Opt(bag and "ilvlBags" or "ilvlCharacter") == true
	slot.level:SetShown(want)
	if want then
		if slot.levelFile and slot.levelSize ~= Opt("ilvlSize") then
			pcall(slot.level.SetFont, slot.level, slot.levelFile, Opt("ilvlSize"), "OUTLINE")
			slot.levelSize = Opt("ilvlSize")
		end
		local choice = Opt("ilvlColour")
		local lr, lg, lb = 1, 1, 1
		if choice == "gold" then
			lr, lg, lb = GOLD[1], GOLD[2], GOLD[3]
		elseif choice == "quality" then
			lr, lg, lb = QualityColour(quality)
		end
		slot.level:SetTextColor(lr, lg, lb, 1)
	end
end

local function Place(slot, parent, x, y)
	if slot.parent ~= parent then
		slot.frame:SetParent(parent)
		slot.parent = parent
	end
	Put(slot.frame, "TOPLEFT", parent, "TOPLEFT", x, -y)
end

local function DrawSortButton(win, show, place)
	local flat = Live()
	win.sort.frame:SetShown(show)
	win.sort.frame:ClearAllPoints()
	if place == "slots" then
		win.sort.frame:SetPoint("TOP", win.frame, "BOTTOM", 0, -2)
	else
		win.sort.frame:SetPoint("TOPRIGHT", win.frame, "TOPRIGHT", -30, -3)
	end
	Look(win.sort, flat)
	local r, g, b = ns.Colour(KEY .. ".accent")
	for _, bar in ipairs(win.bars) do
		bar:SetColorTexture(r, g, b, 0.9)
	end
end

local function Size(win, root, x, y, width, height, title)
	win.frame:SetSize(width, height)
	Put(win.frame, "TOPLEFT", root, "TOPLEFT", x, -y)
	win.frame:Show()
	Look(win, Live("bags"))
	Title(win.title, Live("bags"))
	win.title:SetText(title)
end

local bags = { state = setmetatable({}, { __mode = "k" }), parts = {} }

function bags.build(stage)
	local S = BuildBags(stage)
	bags.state[stage] = S
	bags.parts = S.parts
end

function bags.draw(stage)
	local S = bags.state[stage]
	if not S then
		return
	end
	Begin()
	local combined = Opt("combinedBags") == true
	local place = Opt("sortButton")
	local show = Opt("enabled") == true and place ~= "none"
	local flatBag = Live("bags", "slots")
	if combined then
		Size(S.a, S.root, 40, 4, 220, 170, "Backpack")
		S.b.frame:Hide()
		for index, slot in ipairs(S.slots) do
			Place(slot, S.a.frame, 10 + ((index - 1) % 6) * 34, 28 + math.floor((index - 1) / 6) * 34)
		end
		DrawSortButton(S.a, show, place)
		DrawSortButton(S.b, false, place)
	else
		Size(S.a, S.root, 40, 4, 152, 136, "Backpack")
		Size(S.b, S.root, 200, 4, 152, 136, "Bag")
		for index, slot in ipairs(S.slots) do
			local window = index <= 12 and S.a.frame or S.b.frame
			local at = (index - 1) % 12
			Place(slot, window, 10 + (at % 4) * 34, 28 + math.floor(at / 4) * 34)
		end
		DrawSortButton(S.a, show and place == "title", place)
		DrawSortButton(S.b, show, place)
	end
	for _, slot in ipairs(S.slots) do
		DrawSlot(slot, flatBag, true)
	end
	S.char.frame:SetSize(150, 170)
	Put(S.char.frame, "TOPLEFT", S.root, "TOPLEFT", 420, -4)
	Look(S.char, Live("character"))
	Title(S.char.title, Live("character"))
	DrawSortButton(S.char, false, place)
	local flatGear = Live("character", "slots")
	for index, slot in ipairs(S.gear) do
		Place(slot, S.char.frame, index <= 4 and 10 or 110, 28 + ((index - 1) % 4) * 34)
		DrawSlot(slot, flatGear, false)
	end
	Finish(S)
end

Register("mock-bag-slots", bags)
