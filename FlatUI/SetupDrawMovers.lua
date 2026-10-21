local _, ns = ...

-- Setup drawing for the Movers, Tooltip, Trackers and Cooldown icons position steps: mock-screen.
-- A screen outline in the proportions of the game's screen with frames at their places, the handles of the movers, the middle line, the Tooltip
-- and the two rows of icons, and beside it the Movers panel. The settings come from ns.Get only, so the same code draws the draft under the
-- setup view. Positions of the addon's own frames come from ns.MoverSpot (Movers.lua:570), the places of the game's frames are the defaults.
--
-- Contract: ns.SetupDrawings["mock-screen"] = { build(stage), draw(stage), parts = { [path] = region } }.
-- build(stage) makes the frames once for a stage and returns their root frame, its width and its height; draw(stage) places them from the
-- settings and returns the same width and height. stage.focus (or the id in stage.step) picks what is drawn: "movers", "tooltip", "trackers"
-- or "cooldowns". With neither, everything is drawn.

ns.SetupDrawings = ns.SetupDrawings or {}

-- The drawing fits an area of AREA_W by SCREEN_H: the screen box has the real proportions of UIParent, as wide as the area leaves beside the panel.
local SCREEN_H, AREA_W, PANEL_W, PANEL_GAP, PANEL_MIN_H = 204, 658, 270, 12, 112
local SCREEN_W_MAX = AREA_W - PANEL_GAP - PANEL_W
-- The tooltip's own spot and the game's place for it (Movers.lua:121): the middle of its handle is where the game puts the box.
local TOOLTIP, TRACKERS, COOLDOWNS = "FlatUITooltip", "FlatUITrackers", "FlatUICooldowns"
local TIP_GAME_X, TIP_GAME_Y = -9, 85
-- Trackers.lua:22 and :45 (GAP, BESIDE), Cooldowns.lua:22 (SCREEN_Y), Movers.lua:81 (a handle snaps within 8 units of the middle, so the sample drag is closer than that).
local GAP, BESIDE, SCREEN_Y = 4, 150, -160
local SQUARE, MIN_ICON = 9, 8
-- The sample the drawing holds: a drag that has come within SNAP of the middle (UI units), a cursor (fractions of the screen) and a tooltip box (pixels).
local DRAG_OFFSET, TIP_PX_W, TIP_PX_H, CURSOR_X, CURSOR_Y = 7, 40, 22, 0.60, 0.42
local SAMPLE_ICONS = 3

local GOLD = { 1, 0.82, 0 }
local LOOKS = {
	game = { { 0.45, 0.45, 0.45 }, { 0.12, 0.12, 0.12, 0.9 }, 1 },
	handle = { GOLD, { 0.1, 0.35, 0.6, 0.25 }, 2 },
	grey = { { 0.6, 0.6, 0.6 }, { 0.3, 0.3, 0.3, 0.25 }, 2 },
}

-- The frames drawn at the game's places, as fractions of the screen from its bottom left: left, bottom, width, height.
local FRAMES = {
	{ key = "player", label = "Player", rect = { 0.02, 0.86, 0.18, 0.10 } },
	{ key = "target", label = "Target", rect = { 0.22, 0.86, 0.18, 0.10 } },
	{ key = "pet", label = "Pet", rect = { 0.02, 0.74, 0.14, 0.08 }, grey = true },
	{ key = "minimap", label = "Minimap", rect = { 0.85, 0.72, 0.13, 0.24 } },
	{ key = "chat", label = "Chat", rect = { 0.02, 0.04, 0.24, 0.25 } },
	{ key = "bar", label = "Action bar", rect = { 0.32, 0.03, 0.36, 0.09 } },
}
local TICKED = { player = true, bar = true }

local states = setmetatable({}, { __mode = "k" })

local function Number(value)
	return type(value) == "number" and not ns.IsSecret(value) and value == value and value > -math.huge and value < math.huge
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Frame(parent, level)
	local frame = Own(CreateFrame("Frame", nil, parent))
	if level then
		frame:SetFrameLevel(parent:GetFrameLevel() + level)
	end
	return frame
end

local function Fill(parent, colour, layer)
	local texture = Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, 0))
	texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
	return texture
end

local function Text(parent, template, percent, colour)
	local text = Own(parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall"))
	ns.TextStyle(text, { percent = percent or 100, r = colour and colour[1], g = colour and colour[2], b = colour and colour[3] })
	return text
end

-- A frame with the outline of a tool: a border, a fill and a thickness of its own, which the look settings do not change.
local function Box(parent, level, look)
	local frame = Frame(parent, level)
	local outline = ns.Outline(frame, frame, true)
	ns.KeepOutline(outline)
	local spec = LOOKS[look]
	ns.SetOutlineColour(outline, spec[1][1], spec[1][2], spec[1][3])
	ns.SetOutlineFill(outline, spec[2][1], spec[2][2], spec[2][3], spec[2][4])
	ns.SetOutlineThickness(outline, spec[3])
	return frame, outline
end

local function LookOf(item, look)
	if item.look ~= look then
		item.look = look
		local spec = LOOKS[look]
		ns.SetOutlineColour(item.outline, spec[1][1], spec[1][2], spec[1][3])
		ns.SetOutlineFill(item.outline, spec[2][1], spec[2][2], spec[2][3], spec[2][4])
		ns.SetOutlineThickness(item.outline, spec[3])
	end
end

-- The square of the centre button and of the tick box on a handle (Movers.lua:1980-2035).
local function Square(parent, picture)
	local square = Frame(parent, 2)
	square:SetSize(SQUARE, SQUARE)
	local outline = ns.Outline(square, square, true)
	ns.KeepOutline(outline)
	ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	if picture == "button" then
		local middle = Fill(square, { 1, 1, 1, 0.9 }, "OVERLAY")
		middle:SetSize(2, 6)
		middle:SetPoint("CENTER", square, "CENTER", 0, 0)
		local right = Fill(square, { 1, 1, 1, 0.9 }, "OVERLAY")
		right:SetSize(2, 1)
		right:SetPoint("RIGHT", middle, "LEFT", 0, 1)
		local left = Fill(square, { 1, 1, 1, 0.9 }, "OVERLAY")
		left:SetSize(2, 1)
		left:SetPoint("LEFT", middle, "RIGHT", 0, -1)
	else
		square.mark = Fill(square, GOLD, "OVERLAY")
		square.mark:SetSize(SQUARE - 5, SQUARE - 5)
		square.mark:SetPoint("CENTER", square, "CENTER", 0, 0)
	end
	return square
end

local function Button(parent, label, width)
	local button = Frame(parent, 1)
	button:SetSize(width, 18)
	local outline = ns.Outline(button, button, true)
	ns.KeepOutline(outline)
	ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	local text = Text(button, "GameFontHighlightSmall", 80)
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	text:SetText(label)
	return button
end

-- The size of UIParent, the units ns.MoverSpot answers in (Movers.lua:403-409), and the pixels for each unit that fit the screen box in the area.
local function Geometry()
	local width, height = 1920, 1080
	local ok, wide, high = pcall(UIParent.GetSize, UIParent)
	if ok and Number(wide) and Number(high) and wide > 0 and high > 0 then
		width, height = wide, high
	end
	return width, height, math.min(SCREEN_H / height, SCREEN_W_MAX / width)
end

-- The height of a wrapped text: the client's answer, or a line of 11 pixels for each 5.5 pixels per character where it cannot say.
local function TextHeight(text, string, width)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and Number(height) and height > 0 then
		return height
	end
	return math.ceil(#string * 5.5 / width) * 11
end

local function Place(frame, point, relative, relativePoint, x, y)
	frame:ClearAllPoints()
	frame:SetPoint(point, relative, relativePoint, x, y)
end

-- A frame of `w` by `h` UI units with its bottom left at `l`, `b` from the bottom left of the screen.
local function Rect(S, frame, l, b, w, h)
	frame:SetSize(math.max(1, w * S.k), math.max(1, h * S.k))
	Place(frame, "BOTTOMLEFT", S.screen, "BOTTOMLEFT", l * S.k, b * S.k)
end

-- The frame with its middle at `x`, `y` UI units, `w` by `h` pixels.
local function Centre(S, frame, x, y, w, h)
	frame:SetSize(w, h)
	Place(frame, "CENTER", S.screen, "BOTTOMLEFT", x * S.k, y * S.k)
end

local FOCUS_OF = { movers = "movers", ["tip-place"] = "tooltip", ["tr-look"] = "trackers", ["cd-row"] = "cooldowns" }

local function FocusOf(stage)
	local focus = type(stage) == "table" and (stage.focus or FOCUS_OF[stage.step])
	return FOCUS_OF[focus] or focus or nil
end

local function Shows(focus, what)
	return focus == nil or focus == what
end

-- The screen, the game's frames at their places and the Tooltip handle.
local function BuildScreen(S, root)
	local screen, outline = Box(root, 1, "game")
	ns.SetOutlineColour(outline, 0.7, 0.7, 0.7)
	ns.SetOutlineFill(outline, 0.03, 0.04, 0.06, 1)
	screen:SetSize(SCREEN_W_MAX, SCREEN_H)
	screen:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	S.screen = screen
	S.items = {}
	for _, spec in ipairs(FRAMES) do
		local frame, frameOutline = Box(screen, 2, spec.grey and "grey" or "handle")
		local item = { frame = frame, outline = frameOutline, spec = spec, look = spec.grey and "grey" or "handle" }
		item.label = Text(frame, "GameFontHighlightSmall", 80)
		item.label:SetPoint("CENTER", frame, "CENTER", 0, 0)
		item.label:SetText(spec.label)
		if not spec.grey then
			item.button = Square(frame, "button")
			item.button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
			item.box = Square(frame, "box")
			item.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
		end
		S.items[spec.key] = item
	end
	-- The Tooltip handle of the movers: a box of its own at the spot, with the same button and tick box.
	local tipHandle, tipOutline = Box(screen, 3, "handle")
	S.tipHandle = { frame = tipHandle, outline = tipOutline, look = "handle" }
	S.tipHandle.label = Text(tipHandle, "GameFontHighlightSmall", 80)
	S.tipHandle.label:SetPoint("CENTER", tipHandle, "CENTER", 0, 0)
	S.tipHandle.label:SetText("Tooltip")
	S.tipHandle.button = Square(tipHandle, "button")
	S.tipHandle.button:SetPoint("TOPRIGHT", tipHandle, "TOPRIGHT", -2, -2)
	S.tipHandle.box = Square(tipHandle, "box")
	S.tipHandle.box:SetPoint("TOPLEFT", tipHandle, "TOPLEFT", 2, -2)
end

-- The character and the personal resource display under it, which the two rows of icons hang from.
local function BuildCharacter(S)
	local figure = Frame(S.screen, 3)
	local body = Fill(figure, { 0.5, 0.5, 0.52, 1 })
	body:SetAllPoints(figure)
	local health = Frame(S.screen, 3)
	Fill(health, { 0.2, 0.62, 0.22, 1 }):SetAllPoints(health)
	local power = Frame(S.screen, 3)
	local r, g, b = ns.PowerColour("MANA")
	Fill(power, { r or 0.2, g or 0.4, b or 0.9, 1 }):SetAllPoints(power)
	S.figure, S.health, S.power = figure, health, power
end

-- A row of sample icons on a holder with a small label over it.
local function BuildRow(S, name)
	local holder = Frame(S.screen, 5)
	local row = { holder = holder, icons = {} }
	for index = 1, SAMPLE_ICONS do
		local icon = ns.IconNew(holder)
		if icon then
			ns.IconSample(icon, index, nil, nil, "setup")
			icon.frame:SetFrameLevel(holder:GetFrameLevel() + 1)
		end
		row.icons[index] = icon
	end
	row.label = Text(holder, "GameFontHighlightSmall", 70, { 0.75, 0.75, 0.75 })
	row.label:SetPoint("BOTTOM", holder, "TOP", 0, 1)
	row.label:SetText(name)
	return row
end

-- The mouse cursor: a small cross.
local function Cursor(S)
	local cursor = Frame(S.screen, 7)
	cursor:SetSize(9, 9)
	local across = Fill(cursor, { 1, 1, 1, 1 }, "OVERLAY")
	across:SetSize(9, 1)
	across:SetPoint("CENTER", cursor, "CENTER", 0, 0)
	local down = Fill(cursor, { 1, 1, 1, 1 }, "OVERLAY")
	down:SetSize(1, 9)
	down:SetPoint("CENTER", cursor, "CENTER", 0, 0)
	return cursor
end

local function BuildTooltip(S)
	local tip, outline = Box(S.screen, 6, "game")
	ns.SetOutlineColour(outline, 0.55, 0.55, 0.6)
	ns.SetOutlineFill(outline, 0.05, 0.05, 0.07, 0.96)
	local title = Fill(tip, { 1, 0.82, 0, 1 })
	title:SetPoint("TOPLEFT", tip, "TOPLEFT", 3, -3)
	title:SetSize(18, 2)
	local first = Fill(tip, { 0.7, 0.7, 0.7, 1 })
	first:SetPoint("TOPLEFT", tip, "TOPLEFT", 3, -8)
	first:SetSize(26, 1)
	local second = Fill(tip, { 0.7, 0.7, 0.7, 1 })
	second:SetPoint("TOPLEFT", tip, "TOPLEFT", 3, -12)
	second:SetSize(20, 1)
	S.tip = tip
	S.cursor, S.dragCursor = Cursor(S), Cursor(S)
end

local function BuildLine(S)
	local line = Frame(S.screen, 8)
	line:SetPoint("TOP", S.screen, "TOP", 0, 0)
	line:SetPoint("BOTTOM", S.screen, "BOTTOM", 0, 0)
	line:SetWidth(2)
	Fill(line, GOLD, "OVERLAY"):SetAllPoints(line)
	line.state = Text(line, "GameFontHighlightSmall", 80, GOLD)
	line.state:SetPoint("TOPLEFT", line, "TOPRIGHT", 3, -2)
	S.line = line
end

-- The Movers panel, with the line that says how to centre and the button that centres what is ticked (Movers.lua:3517-3584). The three texts hang
-- from each other as there, and the panel is as tall as they are.
local HINT = "Drag to move. Scroll or Shift and scroll to nudge. Ctrl and scroll to scale. Right-click to reset."
local EVERY_FRAME = "Every frame can be moved here. A grey box moves with the frame it hangs from. A hidden frame the game has not placed yet has no box."
local TEXT_W = PANEL_W - 24

local function BuildPanel(S, root)
	local panel, outline = Box(root, 1, "game")
	panel:SetSize(PANEL_W, PANEL_MIN_H)
	ns.SetOutlineFill(outline, 0.06, 0.06, 0.06, 0.95)
	local title = Text(panel, "GameFontNormalSmall", 120, GOLD)
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
	title:SetText("Movers")
	local hint = Text(panel, "GameFontHighlightSmall", 100)
	hint:SetWidth(TEXT_W)
	hint:SetJustifyH("LEFT")
	hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -28)
	hint:SetText(HINT)
	local every = Text(panel, "GameFontHighlightSmall", 100, { 0.6, 0.6, 0.6 })
	every:SetWidth(TEXT_W)
	every:SetJustifyH("LEFT")
	every:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
	every:SetText(EVERY_FRAME)
	local how = Text(panel, "GameFontHighlightSmall", 100, { 0.6, 0.6, 0.6 })
	how:SetWidth(TEXT_W)
	how:SetJustifyH("LEFT")
	how:SetPoint("TOPLEFT", every, "BOTTOMLEFT", 0, -6)
	-- Four buttons on one row of the 246 pixels of the panel: 12 + 64 + 6 + 52 + 6 + 76 ends at 216, and Done starts at 222.
	local pick = Button(panel, "Pick a frame", 64)
	pick:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 10)
	local reset = Button(panel, "Reset all", 52)
	reset:SetPoint("LEFT", pick, "RIGHT", 6, 0)
	local ticked = Button(panel, "Centre ticked", 76)
	ticked:SetPoint("LEFT", reset, "RIGHT", 6, 0)
	local done = Button(panel, "Done", 36)
	done:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 10)
	S.panel, S.hint, S.every, S.how, S.centreTicked = panel, hint, every, how, ticked
end

local D = { parts = {} }
ns.SetupDrawings["mock-screen"] = D

-- The part of the drawing that each setting marks, for the stage built or asked for last.
local function Parts(S)
	local parts = D.parts
	parts["movers.snap"] = S.items.bar.frame
	parts["movers.centreWith"] = S.items.bar.button
	parts["movers.centreAll"] = S.items.bar.box
	parts["movers.presetLayout"] = S.items.bar.frame
	parts["movers.middleLine"] = S.line
	for _, key in ipairs({ "enabled", "mode", "point", "x", "y" }) do
		parts["tooltip." .. key] = S.tip
	end
	for _, key in ipairs({ "place", "side", "x", "y" }) do
		parts["trackers." .. key] = S.trackers.holder
	end
	for _, key in ipairs({ "place", "x", "y" }) do
		parts["cooldowns." .. key] = S.cooldowns.holder
	end
end

function D.build(stage)
	local S = states[stage]
	if S then
		Parts(S)
		return S.root, S.width, S.height
	end
	S = { stage = stage }
	states[stage] = S
	local root = Frame(stage)
	root:SetSize(AREA_W, SCREEN_H)
	root:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
	S.root = root
	BuildScreen(S, root)
	BuildCharacter(S)
	S.trackers = BuildRow(S, "Trackers")
	S.cooldowns = BuildRow(S, "Cooldown icons")
	BuildTooltip(S)
	BuildLine(S)
	BuildPanel(S, root)
	Parts(S)
	S.width, S.height = AREA_W, SCREEN_H
	D.draw(stage)
	return root, S.width, S.height
end

-- The game's frames at their places, as handles of the movers or as plain frames. The action bar is the frame being dragged: with Snap on it
-- is on the middle of the screen, with Snap off it is DRAG_OFFSET units from it.
local function DrawFrames(S, focus, uw)
	local handles = Shows(focus, "movers")
	local snap = ns.Get("movers.snap") == "middle"
	local button = ns.Get("movers.centreWith") ~= "alt"
	local ticks = ns.Get("movers.centreAll") == "button"
	for _, spec in ipairs(FRAMES) do
		local item = S.items[spec.key]
		local l, b, w, h = spec.rect[1] * uw, spec.rect[2] * S.uh, spec.rect[3] * uw, spec.rect[4] * S.uh
		if spec.key == "bar" then
			l = (uw - w) / 2 + (snap and 0 or DRAG_OFFSET)
		end
		Rect(S, item.frame, l, b, w, h)
		LookOf(item, handles and (spec.grey and "grey" or "handle") or "game")
		item.label:SetShown(handles or spec.key ~= "pet")
		local own = handles and not spec.grey
		if item.button then
			item.button:SetShown(own and button)
			item.box:SetShown(own and ticks)
			item.box.mark:SetShown(TICKED[spec.key] == true)
		end
		item.frame:SetShown(true)
	end
end

-- The middle line and what is being dragged: the cursor on the action bar, the line and the word that says why it is shown.
local function DrawLine(S, focus, uw)
	local mode = ns.Get("movers.middleLine")
	local handles = Shows(focus, "movers")
	local on = handles and mode ~= "off"
	S.line:SetShown(on)
	S.line:SetAlpha(ns.Get("movers.snap") == "middle" and 1 or 0.6)
	S.line.state:SetText(mode == "always" and "Handles open" or "Dragging")
	S.dragCursor:SetShown(handles)
	Place(S.dragCursor, "CENTER", S.items.bar.frame, "CENTER", 0, -2)
end

-- The Movers panel: shown with the handles. The line about centring follows Centre a handle with, and the button follows Centre everything.
-- Its height is that of the three texts with the buttons under them.
local function DrawPanel(S, focus)
	local handles = Shows(focus, "movers")
	S.panel:SetShown(handles)
	local how = ns.Get("movers.centreWith")
	local text = "Click the button on a handle to centre it."
	if how == "alt" then
		text = "Alt and click a handle to centre it."
	elseif how == "both" then
		text = "Click the button on a handle, or Alt and click it, to centre it."
	end
	if ns.Get("movers.centreAll") == "button" then
		text = text .. " Tick the box on each handle, then press Centre ticked."
	end
	S.how:SetText(text)
	S.centreTicked:SetShown(ns.Get("movers.centreAll") == "button")
	local height = 28 + TextHeight(S.hint, HINT, TEXT_W) + 8 + TextHeight(S.every, EVERY_FRAME, TEXT_W) + 6 + TextHeight(S.how, text, TEXT_W) + 10 + 18 + 10
	S.panel:SetHeight(math.max(PANEL_MIN_H, math.ceil(height)))
end

-- The screen box in the proportions of UIParent, the panel beside it and the root frame around both. Sets the size of the root.
local function Layout(S, uw, uh)
	local width, height = uw * S.k, uh * S.k
	S.screen:SetSize(width, height)
	S.panel:ClearAllPoints()
	S.panel:SetPoint("TOPLEFT", S.root, "TOPLEFT", width + PANEL_GAP, 0)
	S.width = width + PANEL_GAP + PANEL_W
	S.height = math.max(height, S.panel:IsShown() and S.panel:GetHeight() or 0)
	S.root:SetSize(S.width, S.height)
end

-- The tooltip: at the game's place while it is not placed, at the sample cursor with the offsets, or hanging from the Tooltip handle.
local function DrawTooltip(S, focus, uw, uh)
	local used = ns.Get("tooltip.enabled") == true
	local fixed = used and ns.Get("tooltip.mode") == "fixed"
	local show = Shows(focus, "tooltip")
	local handle = S.tipHandle
	local point, x, y = ns.Get("tooltip.point"), uw + TIP_GAME_X, TIP_GAME_Y
	if not used then
		point = "BOTTOMRIGHT"
	elseif fixed then
		point = ns.MoverCentred(TOOLTIP, point) or point
		local spotX, spotY = ns.MoverSpot(TOOLTIP, point)
		if spotX then
			x, y = spotX, spotY
		end
	else
		x, y = uw * CURSOR_X + ns.Get("tooltip.x"), uh * CURSOR_Y + ns.Get("tooltip.y")
	end
	S.tip:SetShown(show)
	S.tip:SetSize(TIP_PX_W, TIP_PX_H)
	Place(S.tip, point, S.screen, "BOTTOMLEFT", x * S.k, y * S.k)
	handle.frame:SetShown(show and fixed and focus ~= "trackers" and focus ~= "cooldowns")
	local left, bottom = ns.MoverSpot(TOOLTIP, "BOTTOMLEFT")
	local right, top = ns.MoverSpot(TOOLTIP, "TOPRIGHT")
	if left then
		Rect(S, handle.frame, left, bottom, right - left, top - bottom)
	end
	S.cursor:SetShown(show and used and not fixed)
	Place(S.cursor, "CENTER", S.screen, "BOTTOMLEFT", uw * CURSOR_X * S.k, uh * CURSOR_Y * S.k)
	local button, ticks = ns.Get("movers.centreWith") ~= "alt", ns.Get("movers.centreAll") == "button"
	handle.button:SetShown(button)
	handle.box:SetShown(ticks)
	handle.box.mark:SetShown(false)
end

local function IconSizes(S, size, spacing, count)
	local pixels = math.max(MIN_ICON, size * S.k)
	local gap = spacing * pixels / size
	return pixels, gap, count * pixels + (count - 1) * gap
end

local function LayRow(S, row, x, y, size, spacing)
	local pixels, gap, total = IconSizes(S, size, spacing, SAMPLE_ICONS)
	Centre(S, row.holder, x, y, total, pixels)
	for index, icon in ipairs(row.icons) do
		if icon then
			icon.frame:SetSize(pixels, pixels)
			Place(icon.frame, "LEFT", row.holder, "LEFT", (index - 1) * (pixels + gap), 0)
		end
	end
end

-- Where the Cooldown icons row is, as Cooldowns.lua:769-794 places it: at its spot, under the personal resource display, or low on the screen.
local function CooldownSpot(S, uw, uh)
	local x, y = ns.Get("cooldowns.x"), ns.Get("cooldowns.y")
	local spotX, spotY = ns.MoverSpot(COOLDOWNS, "CENTER")
	if spotX then
		return spotX, spotY, true
	end
	if ns.Get("cooldowns.place") == "resource" then
		return uw / 2 + x, S.powerBottom + y - GAP, false
	end
	return uw / 2 + x, uh / 2 + y + SCREEN_Y, false
end

-- Where the Trackers row is, as Trackers.lua:2781-2829 places it.
local function TrackerSpot(S, uw, uh, cooldownX, cooldownY, cooldownSpot)
	local x, y, place = ns.Get("trackers.x"), ns.Get("trackers.y"), ns.Get("trackers.place")
	local size, spacing = ns.Get("trackers.size"), ns.Get("trackers.spacing")
	local total = SAMPLE_ICONS * size + (SAMPLE_ICONS - 1) * spacing
	if place == "resource" then
		if ns.Get("trackers.side") == "below" then
			if ns.Get("cooldowns.enabled") == true and ns.Get("cooldowns.place") == "resource" and not cooldownSpot then
				local cooldownSize = ns.Get("cooldowns.size")
				local depth = ns.Get("cooldowns.rows") == "up" and 0 or cooldownSize
				return cooldownX + x, cooldownY + y - depth - GAP - size / 2
			end
			return uw / 2 + x, S.powerBottom + y - GAP - size / 2
		end
		return uw / 2 + x, S.healthTop + y + GAP + size / 2
	end
	if place == "own" then
		local spotX, spotY = ns.MoverSpot(TRACKERS, "CENTER")
		if spotX then
			return spotX + x, spotY + y
		end
	end
	local grow = ns.Get("trackers.grow")
	return uw / 2 + BESIDE + (grow == "right" and 0 or grow == "left" and total or total / 2) + x, uh / 2 + y
end

local function DrawRows(S, focus, uw, uh)
	local showTrackers, showCooldowns = Shows(focus, "trackers"), Shows(focus, "cooldowns")
	local cooldownX, cooldownY, cooldownSpot = CooldownSpot(S, uw, uh)
	local interplay = focus == "trackers" and ns.Get("trackers.place") == "resource" and ns.Get("trackers.side") == "below"
		and ns.Get("cooldowns.enabled") == true and ns.Get("cooldowns.place") == "resource"
	showCooldowns = showCooldowns or interplay
	S.trackers.holder:SetShown(showTrackers)
	S.cooldowns.holder:SetShown(showCooldowns)
	S.cooldowns.label:SetShown(focus == nil or focus == "cooldowns")
	if showCooldowns then
		LayRow(S, S.cooldowns, cooldownX, cooldownY, ns.Get("cooldowns.size"), ns.Get("cooldowns.spacing"))
	end
	if showTrackers then
		local x, y = TrackerSpot(S, uw, uh, cooldownX, cooldownY, cooldownSpot)
		LayRow(S, S.trackers, x, y, ns.Get("trackers.size"), ns.Get("trackers.spacing"))
	end
	local character = showTrackers or showCooldowns
	S.figure:SetShown(character)
	S.health:SetShown(character)
	S.power:SetShown(character)
end

local function DrawCharacter(S, uw, uh)
	local barW, healthH, powerH = 180, 18, 12
	S.powerBottom = uh * 0.38
	S.healthTop = S.powerBottom + powerH + healthH
	Rect(S, S.power, uw / 2 - barW / 2, S.powerBottom, barW, powerH)
	Rect(S, S.health, uw / 2 - barW / 2, S.powerBottom + powerH, barW, healthH)
	Rect(S, S.figure, uw / 2 - 30, S.healthTop + 8, 60, 150)
end

function D.draw(stage)
	D.build(stage)
	local S = states[stage]
	local uw, uh, k = Geometry()
	S.uh, S.k = uh, k
	local focus = FocusOf(stage)
	DrawCharacter(S, uw, uh)
	DrawFrames(S, focus, uw)
	DrawPanel(S, focus)
	Layout(S, uw, uh)
	DrawTooltip(S, focus, uw, uh)
	DrawRows(S, focus, uw, uh)
	DrawLine(S, focus, uw)
	return S.width, S.height
end
