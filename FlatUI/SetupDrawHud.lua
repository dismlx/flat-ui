local _, ns = ...

-- The drawings of the setup wizard for the Minimap and HUD pages (steps 28 to 31): mock-minimap, mock-buff-row, mock-xp-micro, mock-objective and
-- mock-loot. Each is { build(stage), draw(stage), parts = { [saved path] = region } }. build makes the frames once, all in ns.Own, and draw reads the
-- settings of the page with ns.Get (the draft while the setup window views one) and puts every part in the look they ask for. The numbers are fixed samples.
-- A part the page leaves to the game is drawn in a plain grey look, the same as the game's art would be without its pictures.
-- The game's own art is not drawn: the minimap is one frame of the game and its terrain is a plain fill (Hud.lua keeps the map's own mask and ring).
-- mock-minimap also draws the lines of text around the map (MapText.lua) with sample values, above or below the map as their rows say.
-- ns.DrawHud gives test mode's stand-ins (TestHud.lua) the painters of an aura icon (DH.Aura, DH.PaintAura) and of a loot roll (DH.Roll, DH.PaintRoll,
-- and DH.RollTime for the seconds left on it).

local GAME = 0.55
local BAR_FILE = "Interface\\TargetingFrame\\UI-StatusBar"
-- The mask Hud.lua already puts on the real map.
local MAP_MASK = "ui-hud-minimap-frame-generic-mask"
local ICONS = { 135940, 135964, 136089, 136243, 134400, 136048 }
-- The border the game gives a debuff of each type before the page paints it (Hud.lua DEBUFF_COLOURS).
local GAME_DEBUFF = { { 0.2, 0.6, 1 }, { 0.6, 0, 1 }, { 0.6, 0.4, 0 }, { 0, 0.6, 0 }, { 0.8, 0, 0 } }
local DEBUFF_ROWS = { "colourMagic", "colourCurse", "colourDisease", "colourPoison", "colourOther" }
local QUALITY = { { 0.12, 1, 0, "Uncommon" }, { 0, 0.44, 0.87, "Rare" }, { 0.64, 0.21, 0.93, "Epic" } }

-- The page and what it leaves to the game --------------------------------------------------------------------

local function Enabled()
	return ns.Get("hud.enabled") == true
end

-- True while a part is on: the page is on and the row is.
local function On(option)
	return Enabled() and ns.Get("hud." .. option) == true
end

-- The value of a row, or nothing while the page is off: the game's own look is wanted then.
local function Val(option)
	if Enabled() then
		return ns.Get("hud." .. option)
	end
	return nil
end

-- The image file a bar texture row names: nothing for the choice of the Flat UI page, false for a solid colour.
local function RowFile(option)
	local id = ns.Get("hud." .. option)
	if id == nil or id == "default" then
		return nil
	end
	return ns.BarFile(id) or false
end

local function Crop()
	return ns.Get("hud.crop") / 100
end

-- Frames, textures and text of the drawings ------------------------------------------------------------------

local function Owned(object)
	ns.Own[object] = true
	return object
end

local function NewFrame(parent, w, h)
	local frame = Owned(CreateFrame("Frame", nil, parent))
	frame:SetSize(w, h)
	return frame
end

local function NewTexture(frame, layer, sub, r, g, b, a)
	local texture = Owned(frame:CreateTexture(nil, layer, nil, sub or 0))
	if r then
		texture:SetColorTexture(r, g, b, a or 1)
	end
	return texture
end

-- A font string at a point of its frame.
local function NewText(frame, template, point, x, y, text, justify)
	local fontString = Owned(frame:CreateFontString(nil, "OVERLAY", template))
	fontString:SetPoint(point, frame, point, x or 0, y or 0)
	fontString:SetJustifyH(justify or "CENTER")
	fontString:SetText(text or "")
	return fontString
end

local function At(object, frame, x, y)
	object:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
end

-- A frame with the page's own border and background, and the grey look the game gives it when the page leaves it alone.
local function NewPlate(parent, w, h)
	local frame = NewFrame(parent, w, h)
	local plate = { frame = frame }
	plate.rim = NewTexture(frame, "BACKGROUND", -6, GAME, GAME, GAME, 1)
	plate.rim:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
	plate.rim:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
	plate.inner = NewTexture(frame, "BACKGROUND", -5, 0.16, 0.16, 0.16, 1)
	plate.inner:SetAllPoints(frame)
	plate.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "hud")
	return plate
end

-- A plate with a status bar over it.
local function NewBar(parent, w, h, value)
	local plate = NewPlate(parent, w, h)
	local bar = Owned(CreateFrame("StatusBar", nil, plate.frame))
	bar:SetAllPoints(plate.frame)
	bar:SetMinMaxValues(0, 100)
	bar:SetStatusBarTexture(BAR_FILE)
	bar:SetValue(value)
	plate.bar = bar
	return plate
end

-- The colours of an outline as the module's own take them: the look rows of the page when they are on, else the general ones.
local function LookOf()
	if ns.Get("hud.lookOwn") == true then
		local r, g, b = ns.Colour("hud.lookBorder")
		local br, bg, bb = ns.Colour("hud.lookBack")
		return r, g, b, br, bg, bb, ns.Get("hud.lookBackAlpha") / 100
	end
	local r, g, b = ns.BorderRGB()
	local br, bg, bb = ns.Colour("general.backdrop")
	return r, g, b, br, bg, bb, ns.Get("general.backdropAlpha") / 100
end

-- Sets what a plate shows: its thin border (edges), its flat background (backdrop), the grey game look (game), and a colour of its own for the border.
-- The colours are set on the outline itself, so a repaint of the outlines from the profile in use leaves the drawing as it is.
local function Style(plate, edges, backdrop, game, colour)
	local outline = plate.outline
	if outline then
		local r, g, b, br, bg, bb, ba = LookOf()
		if colour then
			r, g, b = colour[1], colour[2], colour[3]
		end
		ns.SetOutline(outline, edges, backdrop)
		ns.SetOutlineEdges(outline, edges and (colour ~= nil or not ns.Borderless()))
		ns.SetOutlineColour(outline, r, g, b)
		ns.SetOutlineFill(outline, br, bg, bb, ba)
		ns.SetOutlineThickness(outline, ns.Get("general.thickness"))
	end
	if plate.rim then
		plate.rim:SetShown(game == true)
		plate.inner:SetShown(game == true)
	end
end

-- The image file of the game's own fill of a bar, while the part is off: nothing while it is on, which is the bar texture of the Flat UI page.
local function Chosen(on, game)
	if on then
		return nil
	end
	return ns.BarFile(game)
end

-- The colour of a bar's fill: an image file, nil for the chosen bar texture, false for a solid colour.
local function Fill(bar, r, g, b, file)
	ns.FlatFill(bar, r, g, b, BAR_FILE, nil, file)
end

local function NewGameLabel(root)
	return NewText(root, "GameFontNormalSmall", "BOTTOMRIGHT", -2, 2, "Game look", "RIGHT")
end

-- Starts a drawing: its frames are made once for a stage and kept; parts are filled by build.
local function Start(drawing, stage, w, h)
	local old = drawing.state
	if old and old.stage == stage then
		return nil
	end
	if old then
		-- One instance per drawing: the same frames move to the new stage.
		old.stage = stage
		old.root:SetParent(stage)
		old.root:ClearAllPoints()
		old.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
		return nil
	end
	for key in pairs(drawing.parts) do
		drawing.parts[key] = nil
	end
	local root = NewFrame(stage, w, h)
	root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	drawing.state = { stage = stage, root = root }
	drawing.width, drawing.height = w, h
	return drawing.state
end

local function Ready(drawing, stage)
	if not (drawing.state and drawing.state.stage == stage) then
		drawing.build(stage)
	end
	return drawing.state
end

-- Minimap -------------------------------------------------------------------------------------------------------

local Minimap = { parts = {} }
-- The lines of text around the map, from the map outwards, as MapText.lua stacks them: the row of each and of its place. GAP is between the map and
-- the first line, SPACING between two lines, LINE the height of a line when the client does not say it (MapText.lua).
local MAP_LINES = {
	{ id = "coords", option = "mapCoords", place = "mapCoordsPlace" },
	{ id = "durability", option = "mapDurability", place = "mapDurabilityPlace" },
	{ id = "perf", option = "mapPerf", place = "mapPerfPlace" },
	{ id = "clock", option = "mapClock", place = "mapClockPlace" },
}
local MAP_TEXT = { gap = 4, spacing = 2, line = 10 }

local function MapDisc(parent, layer, sub, r, g, b)
	local texture = NewTexture(parent, layer, sub, r, g, b, 1)
	local mask
	if type(parent.CreateMaskTexture) == "function" then
		mask = Owned(parent:CreateMaskTexture())
		mask:SetAtlas(MAP_MASK)
		mask:SetAllPoints(texture)
		texture:AddMaskTexture(mask)
	end
	return texture, mask
end

function Minimap.build(stage)
	local s = Start(Minimap, stage, 300, 236)
	if not s then
		return Minimap.state.root
	end
	local root, parts = s.root, Minimap.parts
	-- The map: 140 units across, a plain dark fill with the player's arrow.
	local map = NewFrame(root, 140, 140)
	At(map, root, 80, 34)
	s.map = map
	s.ringTexture = MapDisc(map, "BACKGROUND", -8, 0.42, 0.42, 0.42)
	s.ringTexture:SetPoint("TOPLEFT", map, "TOPLEFT", -10, 10)
	s.ringTexture:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 10, -10)
	s.north = NewText(map, "GameFontNormalSmall", "TOP", 0, 9, "N")
	s.disc = MapDisc(map, "BACKGROUND", -7, 0, 0, 0)
	s.fill, s.fillMask = MapDisc(map, "BACKGROUND", -6, 0.1, 0.16, 0.12)
	s.squared = false
	s.fill:SetAllPoints(map)
	s.arrow = NewTexture(map, "ARTWORK", 0, 1, 1, 1, 1)
	s.arrow:SetSize(6, 6)
	s.arrow:SetPoint("CENTER", map, "CENTER", 0, 0)
	s.edge = { outline = ns.SetOutlineArea(ns.Outline(map, map), "hud") }
	-- The zone name over the map and the tracking button beside it.
	s.header = NewPlate(root, 140, 20)
	At(s.header.frame, root, 80, 8)
	s.zone = NewText(s.header.frame, "GameFontNormalSmall", "CENTER", 0, 0, "Elwynn Forest")
	s.tracking = NewPlate(root, 20, 20)
	At(s.tracking.frame, root, 54, 8)
	s.glyph = NewTexture(s.tracking.frame, "ARTWORK", 0, 0.85, 0.8, 0.5, 1)
	s.glyph:SetSize(8, 8)
	s.glyph:SetPoint("CENTER", s.tracking.frame, "CENTER", 0, 0)
	-- The day and night medallion on the corner of the map.
	s.diel = NewPlate(root, 22, 22)
	At(s.diel.frame, root, 222, 30)
	s.sun = NewTexture(s.diel.frame, "ARTWORK", 0, 1, 0.8, 0.2, 1)
	s.sun:SetSize(12, 12)
	s.sun:SetPoint("CENTER", s.diel.frame, "CENTER", 0, 0)
	-- Mail, calendar, clock and the addon list button.
	s.mail = NewFrame(root, 18, 12)
	At(s.mail, root, 54, 80)
	NewTexture(s.mail, "ARTWORK", 0, 0.85, 0.8, 0.6, 1):SetAllPoints(s.mail)
	local flap = NewTexture(s.mail, "OVERLAY", 0, 0.3, 0.25, 0.15, 1)
	flap:SetPoint("TOPLEFT", s.mail, "TOPLEFT", 0, -4)
	flap:SetPoint("TOPRIGHT", s.mail, "TOPRIGHT", 0, -4)
	flap:SetHeight(1)
	s.calendar = NewFrame(root, 22, 22)
	At(s.calendar, root, 226, 8)
	NewTexture(s.calendar, "ARTWORK", 0, 0.9, 0.88, 0.8, 1):SetAllPoints(s.calendar)
	local day = NewText(s.calendar, "GameFontHighlightSmall", "CENTER", 0, 0, "12")
	day:SetTextColor(0.1, 0.1, 0.1, 1)
	-- The game's clock on the foot of the map, so the lines under the map start where MapText.lua puts them.
	s.clock = NewFrame(root, 56, 16)
	At(s.clock, root, 122, 162)
	NewTexture(s.clock, "BACKGROUND", 0, 0.05, 0.05, 0.05, 0.7):SetAllPoints(s.clock)
	NewText(s.clock, "GameFontHighlightSmall", "CENTER", 0, 0, "7:42")
	s.addons = NewFrame(root, 18, 18)
	At(s.addons, root, 228, 104)
	NewTexture(s.addons, "BACKGROUND", 0, 0.2, 0.2, 0.2, 1):SetAllPoints(s.addons)
	for index = 0, 2 do
		local dot = NewTexture(s.addons, "ARTWORK", 0, 0.8, 0.8, 0.8, 1)
		dot:SetSize(3, 3)
		dot:SetPoint("LEFT", s.addons, "LEFT", 3 + index * 5, 0)
	end
	-- The lines of text around the map (MapText.lua), placed by Minimap.draw.
	s.lines = {}
	for _, line in ipairs(MAP_LINES) do
		s.lines[line.id] = NewText(root, "GameFontHighlightSmall", "TOP", 0, 0, "")
	end
	s.label = NewGameLabel(root)
	parts["hud.enabled"] = root
	for _, path in ipairs({ "hud.lookOwn", "hud.lookBorder", "hud.lookBack", "hud.lookBackAlpha" }) do
		parts[path] = s.header.frame
	end
	for _, path in ipairs({ "hud.mapCoords", "hud.mapCoordsPlace", "hud.mapCoordsDecimals", "hud.mapTextSize" }) do
		parts[path] = s.lines.coords
	end
	parts["hud.mapDurability"], parts["hud.mapDurabilityPlace"] = s.lines.durability, s.lines.durability
	parts["hud.mapDurabilityWhen"] = s.lines.durability
	for _, path in ipairs({ "hud.mapPerf", "hud.mapPerfPlace", "hud.mapPerfShow", "hud.mapLatency", "hud.mapPerfColour" }) do
		parts[path] = s.lines.perf
	end
	for _, path in ipairs({ "hud.mapClock", "hud.mapClockPlace", "hud.mapClockTime", "hud.mapClockHours" }) do
		parts[path] = s.lines.clock
	end
	parts["hud.minimapArt"], parts["hud.minimapBorder"], parts["hud.shape"] = map, map, map
	parts["hud.dayNight"] = s.diel.frame
	parts["hud.zoneText"], parts["hud.zoneSize"] = s.zone, s.zone
	parts["hud.btnTracking"], parts["hud.btnMail"], parts["hud.btnCalendar"] = s.tracking.frame, s.mail, s.calendar
	parts["hud.btnClock"], parts["hud.btnAddons"] = s.clock, s.addons
	return root
end

-- The sample text of a line around the map, from its rows: the coordinates by Coordinate decimals; the durability by Durability shows; the frame
-- rate and latency by Show and Latency, each number in its colour while Colour by value is on (ns.PerfColour, MapText.lua); the time, local or
-- the realm's, by Time format.
local function MapLineText(id)
	if id == "coords" then
		local decimals = Val("mapCoordsDecimals")
		return (decimals == "0" and "45, 62") or (decimals == "2" and "45.31, 62.08") or "45.3, 62.1"
	elseif id == "durability" then
		-- Durability shows at 50% or less, or at 20% or less: a worn item in yellow or red, so the picture keeps the line.
		local when = Val("mapDurabilityWhen")
		return (when == "worn" and "|cffffd12eDurability 42%|r") or (when == "low" and "|cffed1212Durability 18%|r") or "Durability 92%"
	elseif id == "perf" then
		local colour = Val("mapPerfColour") == true and type(ns.PerfColour) == "function"
		local function Number(kind, value)
			local code = colour and ns.PerfColour(kind, value) or nil
			return code and (code .. value .. "|r") or tostring(value)
		end
		local show, which, parts = Val("mapPerfShow"), Val("mapLatency"), {}
		if show ~= "ms" then
			parts[#parts + 1] = Number("fps", 60) .. " fps"
		end
		if show ~= "fps" then
			if which == "home" then
				parts[#parts + 1] = Number("ms", 42) .. " ms"
			elseif which == "world" or which == "max" then
				parts[#parts + 1] = Number("ms", 48) .. " ms"
			else
				parts[#parts + 1] = Number("ms", 42) .. " / " .. Number("ms", 48) .. " ms"
			end
		end
		return table.concat(parts, "   ")
	end
	local realm = Val("mapClockTime") == "realm"
	if Val("mapClockHours") == "12" then
		return realm and "3:05 PM" or "2:05 PM"
	end
	return realm and "15:05" or "14:05"
end

-- The map and what sits on it, down by drop units from where it is drawn: the room the lines above the map take, as Hud.lua leaves room for them
-- under the zone name. The zone name, the tracking button and the calendar stay at the top.
local function PlaceMap(s, drop)
	for _, spot in ipairs({ { s.map, 80, 34 }, { s.diel.frame, 222, 30 }, { s.mail, 54, 80 }, { s.clock, 122, 162 }, { s.addons, 228, 104 } }) do
		spot[1]:ClearAllPoints()
		At(spot[1], Minimap.state.root, spot[2], spot[3] + drop)
	end
end

-- The lines of text around the map, as MapText.lua lays them out: each line its rows show, at Text size, stacked out from the map in the order of
-- MAP_LINES, above or below as its place says; the map goes down to make room for those above.
local function MapLines(s)
	local size, above, below = Val("mapTextSize") or 100, {}, {}
	for _, line in ipairs(MAP_LINES) do
		local text = s.lines[line.id]
		local shown = On(line.option)
		text:SetShown(shown)
		if shown then
			text:SetText(MapLineText(line.id))
			ns.TextStyle(text, { percent = size })
			local list = Val(line.place) == "above" and above or below
			list[#list + 1] = text
		end
	end
	local drop = 0
	for index, text in ipairs(above) do
		local ok, height = pcall(text.GetStringHeight, text)
		drop = drop + (index == 1 and MAP_TEXT.gap or MAP_TEXT.spacing) + ((ok and ns.Finite(height) and height > 0) and height or MAP_TEXT.line)
	end
	PlaceMap(s, drop)
	for _, list in ipairs({ above, below }) do
		local up = list == above
		for index, text in ipairs(list) do
			text:ClearAllPoints()
			if up then
				text:SetPoint("BOTTOM", index == 1 and s.map or list[index - 1], "TOP", 0, index == 1 and MAP_TEXT.gap or MAP_TEXT.spacing)
			else
				text:SetPoint("TOP", index == 1 and s.map or list[index - 1], "BOTTOM", 0, -(index == 1 and MAP_TEXT.gap or MAP_TEXT.spacing))
			end
		end
	end
end

function Minimap.draw(stage)
	local s = Ready(Minimap, stage)
	MapLines(s)
	local art, border = On("minimapArt"), On("minimapBorder")
	local square = Val("shape") == "square"
	-- The game's ring and its north pointer come back while the page leaves them; a square map has neither.
	local ring = art or square
	s.ringTexture:SetShown(not ring)
	s.north:SetShown(not ring)
	local thickness = ns.Pixels(s.map, ns.Get("general.thickness"))
	s.disc:SetPoint("TOPLEFT", s.map, "TOPLEFT", -thickness, thickness)
	s.disc:SetPoint("BOTTOMRIGHT", s.map, "BOTTOMRIGHT", thickness, -thickness)
	s.disc:SetColorTexture(ns.BorderRGB())
	s.disc:SetShown(border and not square and not ns.Borderless())
	if s.fillMask and s.squared ~= square then
		s.squared = square
		if square then
			s.fill:RemoveMaskTexture(s.fillMask)
		else
			s.fill:AddMaskTexture(s.fillMask)
		end
	end
	Style(s.edge, border and square, false, false)
	Style(s.header, border, true, not art)
	-- The tracking button keeps the game's plate with Hide minimap ring and header on: since 70425 that plate is the button's StateTexture,
	-- which also draws the glyph (Camelot/MinimapTrackingButton.xml:13-16), and Hud.lua leaves it to the game.
	Style(s.tracking, border, true, true)
	s.tracking.frame:SetShown(Val("btnTracking") ~= false)
	Style(s.diel, false, false, not art)
	s.diel.frame:SetShown(Val("dayNight") ~= false)
	s.zone:SetShown(Val("zoneText") ~= false)
	ns.TextStyle(s.zone, { percent = Val("zoneSize") or 100 })
	s.mail:SetShown(Val("btnMail") ~= false)
	s.calendar:SetShown(Val("btnCalendar") ~= false)
	s.clock:SetShown(Val("btnClock") ~= false)
	s.addons:SetShown(Val("btnAddons") ~= false)
	s.label:SetShown(not Enabled())
end

-- Buffs and debuffs ---------------------------------------------------------------------------------------------

local BuffRow = { parts = {} }
local BUFF_SIZE, BUFF_GAP, BUFF_ROW = 36, 10, 70
local BUFF_TIMES = { "12 s", "1 m", "12 m", "1 h", "30 s", "4 m" }
local DEBUFF_TIMES = { "12 s", "30 s", "2 m", "6 s", "9 s" }

-- An aura icon on `parent` at x, y from its top left, size units across (the drawing's 36 when nil), with its time under it and its count, and the
-- grey border the game gives it.
local function NewAura(parent, x, y, icon, time, count, game, size)
	size = size or BUFF_SIZE
	local holder = NewFrame(parent, size, size)
	At(holder, parent, x, y)
	local cell = { holder = holder, game = game }
	cell.rim = NewTexture(holder, "BACKGROUND", -6, game[1], game[2], game[3], 1)
	cell.rim:SetPoint("TOPLEFT", holder, "TOPLEFT", -2, 2)
	cell.rim:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 2, -2)
	cell.icon = ns.IconNew(holder)
	cell.icon.frame:SetAllPoints(holder)
	ns.IconSet(cell.icon, icon, nil, nil, { numbers = false })
	cell.plate = { outline = cell.icon.outline, rim = cell.rim, inner = cell.rim }
	cell.time = NewText(holder, "NumberFontNormalSmall", "TOP", 0, -size - 2, time)
	cell.count = NewText(holder, "NumberFontNormal", "BOTTOMRIGHT", -1, 1, count, "RIGHT")
	return cell
end

function BuffRow.build(stage)
	local s = Start(BuffRow, stage, 6 * BUFF_SIZE + 5 * BUFF_GAP, 2 * BUFF_ROW - 14)
	if not s then
		return BuffRow.state.root
	end
	local parts = BuffRow.parts
	s.buffs, s.debuffs = {}, {}
	for index = 1, 6 do
		s.buffs[index] = NewAura(s.root, (index - 1) * (BUFF_SIZE + BUFF_GAP), 0, ICONS[index], BUFF_TIMES[index], index == 2 and "3" or "",
			{ 0.5, 0.5, 0.5 })
	end
	for index = 1, 5 do
		s.debuffs[index] = NewAura(s.root, (index - 1) * (BUFF_SIZE + BUFF_GAP), BUFF_ROW, ICONS[7 - index], DEBUFF_TIMES[index], index == 4 and "3" or "",
			GAME_DEBUFF[index])
	end
	s.label = NewGameLabel(s.root)
	parts["hud.auras"], parts["hud.crop"], parts["hud.auraTypes"] = s.buffs[1].holder, s.buffs[1].holder, s.debuffs[1].holder
	for index, row in ipairs(DEBUFF_ROWS) do
		parts["hud." .. row] = s.debuffs[index].holder
	end
	parts["hud.durationSize"], parts["hud.countSize"] = s.buffs[1].time, s.buffs[2].count
	return s.root
end

-- Paints a buff (kind nil) or a debuff of a type, 1 to 4 for magic, curse, disease and poison (DEBUFF_ROWS), else another, from the rows.
local function PaintAura(cell, kind)
	local on = On("auras")
	local crop = on and Crop() or 0
	cell.icon.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	if kind then
		local row = (ns.Get("hud.auraTypes") == true and DEBUFF_ROWS[kind] and kind < 5) and DEBUFF_ROWS[kind] or DEBUFF_ROWS[5]
		local r, g, b = ns.Colour("hud." .. row)
		Style(cell.plate, on, false, not on, { r, g, b })
	else
		Style(cell.plate, on, false, false)
	end
	ns.TextStyle(cell.time, { percent = Val("durationSize") or 100 })
	ns.TextStyle(cell.count, { percent = Val("countSize") or 100 })
end

function BuffRow.draw(stage)
	local s = Ready(BuffRow, stage)
	for _, cell in ipairs(s.buffs) do
		PaintAura(cell, nil)
	end
	for index, cell in ipairs(s.debuffs) do
		PaintAura(cell, index)
	end
	s.label:SetShown(not Enabled())
end

-- Experience bar, bags, micro menu and timers ---------------------------------------------------------------------

local XpMicro = { parts = {} }
local XP_TOTAL, XP_VALUE, REP_VALUE, REP_TOTAL = 10000, 3700, 6000, 12000
-- The rested experience of the sample, which reaches 60% of the bar: 23% of the level.
local XP_RESTED = 2300
-- The quests ready to hand in, and the levelling text by the row Levelling text, for the 6300 to go of the sample.
local QUEST_SAMPLE = 1500
local STATS_SAMPLE = { time = "1h 20m to level", rate = "4,725 an hour", both = "1h 20m to level, 4,725 an hour", kills = "26 kills to level" }

-- A whole number as the game writes large ones (BreakUpLargeNumbers: 3,700), or plain.
local function Grouped(value)
	local ok, text = pcall(_G.BreakUpLargeNumbers, value)
	if ok and type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return tostring(value)
end

-- The text a bar shows by the row Bar text: the game's own text, a percent, the value and the percent, or what is left, with the numbers grouped
-- as XpBar.lua writes them (ns.XpText).
local function XpLine(mode, value, total, name)
	local line = type(ns.XpText) == "function" and ns.XpText(value, total, nil, mode) or nil
	if not line then
		line = ("%s / %s"):format(Grouped(value), Grouped(total))
	end
	return name and (name .. " " .. line) or line
end

-- Nineteen thin lines, enough for the 20 steps a bar can have; PlaceDividers puts the first n - 1 at the steps and hides the rest.
local function NewDividers(plate)
	local list = {}
	for index = 1, 19 do
		local line = NewTexture(plate.bar, "OVERLAY", 3, 0, 0, 0, 0.7)
		line:SetWidth(1)
		list[index] = line
	end
	return list
end

local function PlaceDividers(bar, w, n, shown)
	for index, line in ipairs(bar.lines) do
		if shown and index < n then
			line:ClearAllPoints()
			line:SetPoint("TOP", bar.bar, "TOPLEFT", index * w / n, 0)
			line:SetPoint("BOTTOM", bar.bar, "BOTTOMLEFT", index * w / n, 0)
			line:Show()
		else
			line:ClearAllPoints()
			line:Hide()
		end
	end
end

-- The drawing is 300 pixels for the game's full bar of 1192 units, and 14 pixels for its 17 units of height.
local XP_DRAW = { width = 300, height = 14, units = 17 }

-- Where the words of a bar go by the row Bar text place, relative to the bar.
local function PlaceWords(bar, place)
	bar.words:ClearAllPoints()
	if place == "above" then
		bar.words:SetPoint("BOTTOM", bar.bar, "TOP", 0, 2)
	elseif place == "right" then
		bar.words:SetPoint("LEFT", bar.bar, "RIGHT", 4, 0)
	else
		bar.words:SetPoint("CENTER", bar.bar, "CENTER", 0, 0)
	end
end

function XpMicro.build(stage)
	local s = Start(XpMicro, stage, 640, 150)
	if not s then
		return XpMicro.state.root
	end
	local root, parts = s.root, XpMicro.parts
	s.xp = NewBar(root, 300, 14, 37)
	At(s.xp.frame, root, 0, 8)
	s.xp.words = NewText(s.xp.bar, "GameFontHighlightSmall", "CENTER", 0, 0, "")
	s.xp.lines = NewDividers(s.xp)
	s.rep = NewBar(root, 300, 14, 50)
	At(s.rep.frame, root, 0, 36)
	s.rep.words = NewText(s.rep.bar, "GameFontHighlightSmall", "CENTER", 0, 0, "")
	s.rep.lines = NewDividers(s.rep)
	-- The rested stretch behind the fill of Flat UI's own bar, and the outline of the game's smallest bar, half the width of its full bar.
	s.xp.rested = NewTexture(s.xp.bar, "BACKGROUND", 1, 0, 0.39, 0.88, 0.4)
	-- The stretch of the quests ready to hand in, over the rested one.
	s.xp.quest = NewTexture(s.xp.bar, "BACKGROUND", 2, 0.3, 0.9, 0.3, 0.6)
	s.floor = NewFrame(root, XP_DRAW.width / 2, XP_DRAW.height)
	s.floor.edges = {}
	for index = 1, 4 do
		s.floor.edges[index] = NewTexture(s.floor, "OVERLAY", 1, 1, 1, 1, 0.25)
	end
	s.floor.edges[1]:SetPoint("TOPLEFT", s.floor, "TOPLEFT", 0, 0)
	s.floor.edges[1]:SetPoint("TOPRIGHT", s.floor, "TOPRIGHT", 0, 0)
	s.floor.edges[1]:SetHeight(1)
	s.floor.edges[2]:SetPoint("BOTTOMLEFT", s.floor, "BOTTOMLEFT", 0, 0)
	s.floor.edges[2]:SetPoint("BOTTOMRIGHT", s.floor, "BOTTOMRIGHT", 0, 0)
	s.floor.edges[2]:SetHeight(1)
	s.floor.edges[3]:SetPoint("TOPLEFT", s.floor, "TOPLEFT", 0, 0)
	s.floor.edges[3]:SetPoint("BOTTOMLEFT", s.floor, "BOTTOMLEFT", 0, 0)
	s.floor.edges[3]:SetWidth(1)
	s.floor.edges[4]:SetPoint("TOPRIGHT", s.floor, "TOPRIGHT", 0, 0)
	s.floor.edges[4]:SetPoint("BOTTOMRIGHT", s.floor, "BOTTOMRIGHT", 0, 0)
	s.floor.edges[4]:SetWidth(1)
	-- The tooltip of Flat UI's own bar.
	s.tip = NewPlate(root, 180, 30)
	At(s.tip.frame, root, 60, 32)
	NewText(s.tip.frame, "GameFontHighlightSmall", "TOPLEFT", 6, -5, "Experience: 3,700 / 10,000", "LEFT")
	s.tipRested = NewText(s.tip.frame, "GameFontHighlightSmall", "BOTTOMLEFT", 6, 5, "Rested: 2,300 (23% of the level)", "LEFT")
	s.bags = {}
	for index = 1, 5 do
		local plate = NewPlate(root, 28, 28)
		At(plate.frame, root, (index - 1) * 34, 68)
		plate.icon = NewTexture(plate.frame, "ARTWORK", 0, 1, 1, 1, 1)
		plate.icon:SetTexture(ICONS[index])
		plate.icon:SetAllPoints(plate.frame)
		s.bags[index] = plate
	end
	s.micro = {}
	for index = 1, 8 do
		local plate = NewPlate(root, 22, 30)
		At(plate.frame, root, (index - 1) * 27, 114)
		local glyph = NewTexture(plate.frame, "ARTWORK", 0, 0.5 + 0.06 * index, 0.7, 0.9 - 0.07 * index, 1)
		glyph:SetSize(12, 12)
		glyph:SetPoint("CENTER", plate.frame, "CENTER", 0, 0)
		s.micro[index] = plate
	end
	-- Breath timer, countdown, queue panel, damage meter header and a zone event bar on the right.
	s.mirror = NewBar(root, 220, 14, 70)
	At(s.mirror.frame, root, 340, 8)
	NewText(s.mirror.bar, "GameFontHighlightSmall", "CENTER", 0, 0, "Breath")
	-- The time left at the right, as Hud.lua writes it while Seconds on the timers is on.
	s.mirrorTime = NewText(s.mirror.bar, "GameFontHighlightSmall", "RIGHT", -4, 0, "1:12", "RIGHT")
	s.countdown = NewBar(root, 220, 12, 80)
	At(s.countdown.frame, root, 340, 36)
	NewText(s.countdown.bar, "GameFontHighlightSmall", "CENTER", 0, 0, "Pull in 8")
	s.queue = NewPlate(root, 130, 40)
	At(s.queue.frame, root, 340, 66)
	NewText(s.queue.frame, "GameFontNormalSmall", "TOPLEFT", 6, -6, "Battleground", "LEFT")
	NewText(s.queue.frame, "GameFontHighlightSmall", "BOTTOMLEFT", 6, 6, "In queue 2:10", "LEFT")
	s.meter = NewPlate(root, 140, 18)
	At(s.meter.frame, root, 490, 66)
	NewText(s.meter.frame, "GameFontNormalSmall", "LEFT", 6, 0, "Damage done", "LEFT")
	local body = NewFrame(root, 140, 22)
	At(body, root, 490, 84)
	NewTexture(body, "BACKGROUND", 0, 0.1, 0.1, 0.1, 0.7):SetAllPoints(body)
	NewText(body, "GameFontHighlightSmall", "LEFT", 6, 0, "Player 12.4k", "LEFT")
	s.zoneBar = NewBar(root, 220, 14, 32)
	At(s.zoneBar.frame, root, 340, 118)
	NewText(s.zoneBar.bar, "GameFontHighlightSmall", "CENTER", 0, 0, "320 / 1000")
	s.label = NewGameLabel(root)
	parts["hud.enabled"] = root
	parts["hud.bags"] = s.bags[1].frame
	parts["hud.xpFrame"], parts["hud.xpFill"], parts["hud.xpTexture"] = s.xp.frame, s.xp.bar, s.xp.bar
	parts["hud.xpDividers"], parts["hud.xpBack"] = s.xp.frame, s.xp.frame
	parts["hud.xpOwn"], parts["hud.xpWidth"], parts["hud.xpHeight"], parts["hud.xpShow"] = s.xp.frame, s.xp.frame, s.xp.frame, s.xp.frame
	parts["hud.xpOrder"], parts["hud.xpGap"], parts["hud.xpTicks"], parts["hud.xpTooltip"] = s.xp.frame, s.xp.frame, s.xp.frame, s.tip.frame
	parts["hud.xpColour"], parts["hud.xpRested"], parts["hud.xpRestedColour"] = s.xp.bar, s.xp.bar, s.xp.bar
	parts["hud.xpRepMode"], parts["hud.xpRepColour"] = s.rep.bar, s.rep.bar
	parts["hud.xpTextWhen"], parts["hud.xpTextPlace"] = s.xp.words, s.xp.words
	parts["hud.xpText"], parts["hud.xpTextSize"], parts["hud.xpTextRested"] = s.xp.words, s.xp.words, s.xp.words
	parts["hud.xpQuest"], parts["hud.xpQuestColour"], parts["hud.xpStats"] = s.xp.quest, s.xp.quest, s.xp.words
	parts["hud.micro"] = s.micro[1].frame
	parts["hud.mirror"], parts["hud.countdown"] = s.mirror.frame, s.countdown.frame
	parts["hud.mirrorTime"] = s.mirrorTime
	parts["hud.queue"], parts["hud.meter"], parts["hud.zoneBars"] = s.queue.frame, s.meter.frame, s.zoneBar.frame
	return root
end

-- Flat UI's own bar: the width and height of the rows in the drawing's scale, centred over where the action bar is, the two bars stacked by Top bar.
local function DrawOwn(s, mode, size, file)
	local w = XP_DRAW.width * ns.Get("hud.xpWidth") / 100
	local scale = XP_DRAW.height / XP_DRAW.units
	local h = math.max(2, math.floor(ns.Get("hud.xpHeight") * scale + 0.5))
	local gap = math.floor(ns.Get("hud.xpGap") * scale + 0.5)
	local show, ticks = ns.Get("hud.xpShow"), tonumber(ns.Get("hud.xpTicks")) or 0
	local order = ns.Get("hud.xpOrder") == "rep" and { s.rep, s.xp } or { s.xp, s.rep }
	local x, y = (XP_DRAW.width - w) / 2, 8
	local frameOn = ns.Get("hud.xpFrame") == true
	local place = ns.Get("hud.xpTextPlace")
	for _, bar in ipairs(order) do
		local on = (bar == s.xp and show ~= "rep") or (bar == s.rep and show ~= "xp")
		bar.frame:SetShown(on)
		if on then
			bar.frame:SetSize(w, h)
			bar.frame:ClearAllPoints()
			At(bar.frame, bar.frame:GetParent(), x, y)
			y = y + h + gap
			-- As XpBar.lua draws it: the background by Bar background, the edges by Bar border whatever Borderless says.
			Style(bar, true, ns.Get("hud.xpBack") ~= false, false)
			ns.SetOutlineEdges(bar.outline, frameOn)
			PlaceDividers(bar, w, ticks, ticks > 1)
			PlaceWords(bar, place)
			bar.words:SetShown(mode ~= "hide")
			-- The text shows over the bar on mouse-over only, so a sample of it is faint.
			bar.words:SetAlpha(ns.Get("hud.xpTextWhen") == "hover" and 0.45 or 1)
			ns.TextStyle(bar.words, { percent = size })
		end
	end
	Style(s.tip, true, true, false)
	s.tip.frame:SetShown(ns.Get("hud.xpTooltip") == true)
	local r, g, b = ns.Colour("hud.xpColour")
	Fill(s.xp.bar, r, g, b, file)
	local rr, rg, rb = ns.Colour("hud.xpRestedColour")
	s.tipRested:SetTextColor(rr, rg, rb)
	s.xp.rested:SetColorTexture(rr, rg, rb, 0.4)
	s.xp.rested:ClearAllPoints()
	s.xp.rested:SetPoint("TOPLEFT", s.xp.bar, "TOPLEFT", 0, 0)
	s.xp.rested:SetPoint("BOTTOMLEFT", s.xp.bar, "BOTTOMLEFT", 0, 0)
	s.xp.rested:SetWidth(w * 0.6)
	s.xp.rested:SetShown(ns.Get("hud.xpRested") == true)
	local qr, qg, qb = ns.Colour("hud.xpQuestColour")
	s.xp.quest:SetColorTexture(qr, qg, qb, 0.6)
	s.xp.quest:ClearAllPoints()
	s.xp.quest:SetPoint("TOPLEFT", s.xp.bar, "TOPLEFT", 0, 0)
	s.xp.quest:SetPoint("BOTTOMLEFT", s.xp.bar, "BOTTOMLEFT", 0, 0)
	s.xp.quest:SetWidth(w * (XP_VALUE + QUEST_SAMPLE) / XP_TOTAL)
	s.xp.quest:SetShown(ns.Get("hud.xpQuest") == true)
	local pr, pg, pb = 0, 0.6, 0.1
	if ns.Get("hud.xpRepMode") == "one" then
		pr, pg, pb = ns.Colour("hud.xpRepColour")
	end
	Fill(s.rep.bar, pr, pg, pb, file)
	s.floor:SetSize(XP_DRAW.width / 2, XP_DRAW.height)
	s.floor:ClearAllPoints()
	At(s.floor, s.xp.frame:GetParent(), XP_DRAW.width / 4, 8)
	s.floor:Show()
end

-- The game's own bars, as the page restyles them.
local function DrawGame(s, mode, size, file)
	local frameOn = On("xpFrame")
	local dividers = not On("xpDividers")
	for index, bar in ipairs({ s.xp, s.rep }) do
		bar.frame:SetSize(XP_DRAW.width, XP_DRAW.height)
		bar.frame:ClearAllPoints()
		At(bar.frame, bar.frame:GetParent(), 0, index == 1 and 8 or 36)
		bar.frame:Show()
		Style(bar, frameOn, true, not frameOn)
		PlaceDividers(bar, XP_DRAW.width, 10, dividers)
		PlaceWords(bar, "on")
		bar.words:SetShown(mode ~= "hide")
		bar.words:SetAlpha(1)
		ns.TextStyle(bar.words, { percent = size })
	end
	s.tip.frame:Hide()
	s.xp.rested:Hide()
	s.xp.quest:Hide()
	Fill(s.xp.bar, 0.58, 0, 0.55, file)
	Fill(s.rep.bar, 0, 0.6, 0.1, file)
	s.floor:Hide()
end

function XpMicro.draw(stage)
	local s = Ready(XpMicro, stage)
	local fillOn = On("xpFill")
	local own = Enabled() and ns.Get("hud.xpOwn") == "flat"
	local file
	if own or fillOn then
		file = RowFile("xpTexture")
	else
		file = ns.BarFile("gloss")
	end
	local mode, size = Val("xpText") or "game", Val("xpTextSize") or 100
	if own then
		DrawOwn(s, mode, size, file)
	else
		DrawGame(s, mode, size, file)
	end
	-- On Flat UI's bar the levelling text follows the bar text, or stands alone while Bar text is Hidden.
	local extra = own and STATS_SAMPLE[ns.Get("hud.xpStats")] or nil
	local line = mode ~= "hide" and XpLine(mode, XP_VALUE, XP_TOTAL) or nil
	-- Rested share in the text, on Flat UI's bar: "  +23%" in Rested colour after Percent and Value and percent.
	if line and own and (mode == "percent" or mode == "both") and ns.Get("hud.xpTextRested") == true and ns.Get("hud.xpRested") == true then
		local r, g, b = ns.Colour("hud.xpRestedColour")
		line = ("%s  |cff%02x%02x%02x+%d%%|r"):format(line, math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5),
			math.floor(XP_RESTED * 100 / XP_TOTAL + 0.5))
	end
	s.xp.words:SetText(line and extra and (line .. ", " .. extra) or line or extra or "")
	if extra then
		s.xp.words:Show()
	end
	s.rep.words:SetText(XpLine(mode, REP_VALUE, REP_TOTAL, "Stormwind"))
	local bags, crop = On("bags"), Crop()
	for _, plate in ipairs(s.bags) do
		Style(plate, bags, true, not bags)
		local c = bags and crop or 0
		plate.icon:SetTexCoord(c, 1 - c, c, 1 - c)
	end
	local micro = On("micro")
	for _, plate in ipairs(s.micro) do
		Style(plate, micro, true, not micro)
	end
	local on = On("mirror")
	local r, g, b = ns.Colour("castbars.castColour")
	Style(s.mirror, on, true, not on)
	Fill(s.mirror.bar, r, g, b, Chosen(on, "gloss"))
	s.mirrorTime:SetShown(on and ns.Get("hud.mirrorTime") == true)
	on = On("countdown")
	Style(s.countdown, on, false, not on)
	Fill(s.countdown.bar, 1, 0.82, 0, Chosen(on, "game"))
	on = On("queue")
	Style(s.queue, on, true, not on)
	on = On("meter")
	Style(s.meter, on, true, not on)
	on = On("zoneBars")
	Style(s.zoneBar, on, true, not on)
	-- One fill whatever the row says: Hud.lua only plates the widget and fades its art, so the game keeps the widget's own fill.
	Fill(s.zoneBar.bar, 0.2, 0.4, 0.9, ns.BarFile("gloss"))
	s.label:SetShown(not Enabled())
end

-- Objective tracker -----------------------------------------------------------------------------------------------

local Objective = { parts = {} }

function Objective.build(stage)
	local s = Start(Objective, stage, 280, 150)
	if not s then
		return Objective.state.root
	end
	local root, parts = s.root, Objective.parts
	s.panel = NewPlate(root, 280, 150)
	s.panel.frame:SetAllPoints(root)
	s.header = NewPlate(root, 260, 22)
	At(s.header.frame, root, 10, 8)
	s.title = NewText(s.header.frame, "GameFontNormalSmall", "LEFT", 8, 0, "Quests", "LEFT")
	local quest = NewText(root, "GameFontNormalSmall", "TOPLEFT", 14, -42, "Defias Brotherhood", "LEFT")
	NewText(root, "GameFontHighlightSmall", "TOPLEFT", 20, -60, "6/10 Defias Pillager slain", "LEFT")
	s.bar = NewBar(root, 190, 14, 60)
	At(s.bar.frame, root, 20, 84)
	NewText(s.bar.bar, "GameFontHighlightSmall", "CENTER", 0, 0, "60%")
	s.item = NewPlate(root, 28, 28)
	s.item.frame:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -44)
	s.item.icon = NewTexture(s.item.frame, "ARTWORK", 0, 1, 1, 1, 1)
	s.item.icon:SetTexture(ICONS[4])
	s.item.icon:SetAllPoints(s.item.frame)
	s.item.icon:SetTexCoord(0, 1, 0, 1)
	s.label = NewGameLabel(root)
	parts["hud.enabled"] = root
	parts["hud.trackerHeaders"], parts["hud.trackerHeaderSize"] = s.header.frame, s.title
	parts["hud.trackerBars"], parts["hud.trackerTexture"] = s.bar.frame, s.bar.bar
	parts["hud.trackerItems"], parts["hud.trackerPanel"] = s.item.frame, s.panel.frame
	parts["hud.trackerCombat"] = root
	s.quest = quest
	return root
end

function Objective.draw(stage)
	local s = Ready(Objective, stage)
	-- The game draws no background behind the tracker, so the panel shows only while the page puts one there.
	local panel = On("trackerPanel")
	Style(s.panel, panel, true, false)
	s.panel.frame:SetShown(panel)
	local on = On("trackerHeaders")
	Style(s.header, on, true, not on)
	ns.TextStyle(s.title, { percent = Val("trackerHeaderSize") or 100 })
	on = On("trackerBars")
	Style(s.bar, on, true, not on)
	local file
	if on then
		file = RowFile("trackerTexture")
	else
		file = ns.BarFile("game")
	end
	Fill(s.bar.bar, 0.2, 0.55, 0.9, file)
	on = On("trackerItems")
	Style(s.item, on, true, not on)
	s.root:SetAlpha((Val("trackerCombat") or 100) / 100)
	s.label:SetShown(not Enabled())
end

-- Loot window, rolls and alerts -----------------------------------------------------------------------------------

local Loot = { parts = {} }

local function NewSlot(parent, x, y, size, icon)
	local plate = NewPlate(parent, size, size)
	plate.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	plate.icon = NewTexture(plate.frame, "ARTWORK", 0, 1, 1, 1, 1)
	plate.icon:SetTexture(icon)
	plate.icon:SetAllPoints(plate.frame)
	return plate
end

-- A roll as Hud.lua draws it, w units wide on `parent`, its parts on r: the plate (r.roll), the item (r.rollIcon) and its name in the colour of its
-- quality, the timer (r.timer, filled to 65 of 100), the seconds left over its right end (r.timeText, 39 of a 60 second roll) and the Need, Greed
-- and Pass buttons (r.rollButtons). The caller anchors r.roll.frame.
local function NewRoll(r, parent, icon, name, quality, w)
	r.roll = NewPlate(parent, w, 50)
	r.rollIcon = NewSlot(r.roll.frame, 7, 6, 28, icon)
	local rollName = NewText(r.roll.frame, "GameFontHighlightSmall", "TOPLEFT", 42, -8, name, "LEFT")
	rollName:SetTextColor(quality[1], quality[2], quality[3], 1)
	r.quality = quality
	r.timer = Owned(CreateFrame("StatusBar", nil, r.roll.frame))
	r.timer:SetMinMaxValues(0, 100)
	r.timer:SetStatusBarTexture(BAR_FILE)
	r.timer:SetValue(65)
	NewTexture(r.timer, "BACKGROUND", 0, 0, 0, 0, 1):SetAllPoints(r.timer)
	r.timerEdge = { outline = ns.SetOutlineArea(ns.Outline(r.timer, r.timer), "hud") }
	r.timeText = Owned(r.roll.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
	r.timeText:SetJustifyH("RIGHT")
	r.timeText:SetPoint("BOTTOMRIGHT", r.timer, "TOPRIGHT", 0, 2)
	r.secs = 39
	r.rollButtons = {}
	for index, kind in ipairs({ "need", "greed", "pass" }) do
		local button = NewTexture(r.roll.frame, "ARTWORK", 1)
		button:SetAtlas("lootroll-toast-icon-" .. kind .. "-up")
		r.rollButtons[index] = button
	end
	return r
end

-- The seconds left on a roll and the colour of its timer: the seconds while Loot rolls and Seconds left on rolls are on, and under 10 the seconds and
-- the fill in red, as Hud.lua's ROLL.Red; the fill is gold otherwise. The fill is set again only when its colour or file changes.
local function RollClock(r)
	local shown = On("lootRolls") and ns.Get("hud.lootRollTime") == true
	local red = shown and r.secs < 10
	r.timeText:SetShown(shown)
	r.timeText:SetText(tostring(r.secs))
	if red then
		r.timeText:SetTextColor(1, 0.25, 0.25)
	else
		r.timeText:SetTextColor(1, 1, 1)
	end
	if r.painted ~= red or r.paintedFile ~= r.file then
		r.painted, r.paintedFile = red, r.file
		if red then
			Fill(r.timer, 1, 0.2, 0.2, r.file)
		else
			Fill(r.timer, 1, 0.82, 0, r.file)
		end
	end
end

-- Paints a roll from the rows: the timer across the foot and Need, Greed and Pass in a row at the right while Loot rolls is on, else where the game
-- has them, the timer under the name and the buttons in two rows.
local function PaintRoll(r)
	local on = On("lootRolls")
	local colour = { r.quality[1], r.quality[2], r.quality[3] }
	Style(r.roll, on, true, not on)
	Style(r.rollIcon, on, true, not on, on and colour or nil)
	local crop = on and Crop() or 0
	r.rollIcon.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	Style(r.timerEdge, on, false, false)
	local roll, timer, need, greed, pass = r.roll.frame, r.timer, r.rollButtons[1], r.rollButtons[2], r.rollButtons[3]
	timer:ClearAllPoints()
	for _, button in ipairs(r.rollButtons) do
		button:ClearAllPoints()
	end
	local file, side
	if on then
		timer:SetPoint("BOTTOMLEFT", roll, "BOTTOMLEFT", 7, 5)
		timer:SetPoint("BOTTOMRIGHT", roll, "BOTTOMRIGHT", -7, 5)
		timer:SetHeight(6)
		side = 18
		pass:SetPoint("RIGHT", roll, "RIGHT", -6, 5)
		greed:SetPoint("RIGHT", pass, "LEFT", -2, 0)
		need:SetPoint("RIGHT", greed, "LEFT", -2, 0)
	else
		timer:SetPoint("BOTTOMLEFT", roll, "BOTTOMLEFT", 3, 2)
		timer:SetSize(150, 6)
		side = 20
		need:SetPoint("TOPRIGHT", roll, "TOPRIGHT", -34, -4)
		pass:SetPoint("LEFT", need, "RIGHT", 4, 1)
		greed:SetPoint("TOP", need, "BOTTOM", 0, 3)
		file = ns.BarFile("skills")
	end
	for _, button in ipairs(r.rollButtons) do
		button:SetSize(side, side)
	end
	r.file, r.painted = file, nil
	RollClock(r)
end

function Loot.build(stage)
	local s = Start(Loot, stage, 440, 150)
	if not s then
		return Loot.state.root
	end
	local root, parts = s.root, Loot.parts
	s.window = NewPlate(root, 160, 134)
	At(s.window.frame, root, 0, 8)
	NewText(s.window.frame, "GameFontNormalSmall", "TOP", 0, -6, "Loot")
	s.cards = {}
	for index, quality in ipairs(QUALITY) do
		local card = NewPlate(s.window.frame, 140, 32)
		card.frame:SetPoint("TOPLEFT", s.window.frame, "TOPLEFT", 10, -(24 + (index - 1) * 36))
		card.quality = quality
		card.slot = NewSlot(card.frame, 3, 3, 26, ICONS[index])
		local name = NewText(card.frame, "GameFontHighlightSmall", "TOPLEFT", 36, -4, ({ "Linen Cloak", "Sturdy Shield", "Royal Crown" })[index], "LEFT")
		name:SetTextColor(quality[1], quality[2], quality[3], 1)
		card.words = NewText(card.frame, "GameFontNormalSmall", "BOTTOMLEFT", 36, 4, quality[4], "LEFT")
		s.cards[index] = card
	end
	NewRoll(s, root, ICONS[2], "Sturdy Shield", QUALITY[2], 230)
	At(s.roll.frame, root, 190, 6)
	s.alert = NewPlate(root, 230, 44)
	At(s.alert.frame, root, 190, 70)
	s.alertIcon = NewTexture(s.alert.frame, "ARTWORK", 0, 1, 1, 1, 1)
	s.alertIcon:SetTexture(ICONS[1])
	s.alertIcon:SetSize(30, 30)
	s.alertIcon:SetPoint("TOPLEFT", s.alert.frame, "TOPLEFT", 7, -7)
	NewText(s.alert.frame, "GameFontNormalSmall", "TOPLEFT", 44, -7, "You receive loot", "LEFT")
	NewText(s.alert.frame, "GameFontHighlightSmall", "BOTTOMLEFT", 44, 7, "Linen Cloak", "LEFT")
	s.label = NewGameLabel(root)
	parts["hud.enabled"] = root
	parts["hud.lootWindow"] = s.window.frame
	parts["hud.lootQualityText"] = s.cards[1].words
	parts["hud.lootRolls"] = s.roll.frame
	parts["hud.lootRollTime"] = s.timeText
	parts["hud.alerts"] = s.alert.frame
	return root
end

function Loot.draw(stage)
	local s = Ready(Loot, stage)
	local on = On("lootWindow")
	Style(s.window, on, true, not on)
	local crop = on and Crop() or 0
	local hide = on and ns.Get("hud.lootQualityText") ~= true
	for _, card in ipairs(s.cards) do
		local colour = on and card.quality or nil
		Style(card, on, false, not on, colour)
		Style(card.slot, on, true, not on, colour)
		card.slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		card.words:SetShown(not hide)
	end
	PaintRoll(s)
	on = On("alerts")
	Style(s.alert, on, true, not on)
	s.label:SetShown(not Enabled())
end

ns.SetupDrawings = ns.SetupDrawings or {}
ns.SetupDrawings["mock-minimap"] = Minimap
ns.SetupDrawings["mock-buff-row"] = BuffRow
ns.SetupDrawings["mock-xp-micro"] = XpMicro
ns.SetupDrawings["mock-objective"] = Objective
ns.SetupDrawings["mock-loot"] = Loot

-- The painters of the drawings, for test mode's stand-ins (TestHud.lua): aura icons and loot rolls on frames of the caller's, painted from the rows
-- as mock-buff-row and mock-loot paint theirs.
local DH = { ICONS = ICONS, QUALITY = QUALITY }
ns.DrawHud = DH

-- An aura icon on `parent` at x, y from its top left, size units across, with the texture `icon`. game: the colour of its border in the game's look.
function DH.Aura(parent, x, y, size, icon, game)
	return NewAura(parent, x, y, icon, "", "", game or { 0.5, 0.5, 0.5 }, size)
end

-- The game's border of a debuff of a type, 1 to 5 as DEBUFF_ROWS.
function DH.DebuffColour(kind)
	return GAME_DEBUFF[kind] or GAME_DEBUFF[5]
end

-- Paints an aura: a buff for kind nil, else a debuff of the type kind (1 magic, 2 curse, 3 disease, 4 poison, 5 another).
function DH.PaintAura(cell, kind)
	PaintAura(cell, kind)
end

-- A roll w units wide on `parent`, of the item `icon` named `name` in the colour of a QUALITY.
function DH.Roll(parent, icon, name, quality, w)
	return NewRoll({}, parent, icon, name, quality, w or 230)
end

DH.PaintRoll = PaintRoll

-- The seconds left on a roll of DH.Roll, red with its fill under 10 while Seconds left on rolls is on. Nothing is set while the seconds stay the same.
function DH.RollTime(r, secs)
	if secs ~= r.secs then
		r.secs = secs
		RollClock(r)
	end
end
