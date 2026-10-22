local _, ns = ...

-- Setup drawings of steps 23 to 27: mock-cast-bar (cast bar look, size, text and icon), mock-resource (personal resource display) and mock-swing
-- (swing timers). Each is { build(stage), draw(stage), parts = { [path] = region } } as research/flatui-wizard/design.md 4.2 says. build makes the
-- frames once per stage, draw reads the settings only through ns.Get and sets what they decide, so under a draft view it draws the draft.
-- A drawing has the real size in interface units: the first child of the stage is its root, anchored at the middle of the stage, and
-- drawing.size(stage) gives its width and height for the window to scale. drawing.outlines lists the outlines it made.
--
-- What each look is built from, so it matches what the module paints (Bars.lua):
--   cast bars: the border and background of ApplyCastBar (Bars.lua:597-622), the plate behind the spell name, the spark, the shield, the icon and
--   the spell name of ApplyCastParts and ns.CastText (Bars.lua:707-816), the cover colour of CastColour (956-972), the marks of Marks (1020-1088),
--   the sizes and the place of the spell name of CastBarSize.lua:92-150.
--   resource display: ApplyResourceBar, JoinBar, ApplyResourceFill, ApplyResourceText (Bars.lua:78-165), the custom colours (Bars.lua:195-250).
--   swing timers: ApplySwingTimer, ApplySwingFill, ApplySwingText, ApplySwingRange, ApplySwingReverse, ApplySwingIdle (Bars.lua:335-530).
-- Sizes and places of the game's own parts come from the client's interface source:
--   Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml:198-204, 241-252, 313-318, 326-331 (player and pet bar: plate 12 below the bar, shield 29 by 33 at
--   -27, 4, icon 16 by 16 at -5, spell name at the top -10, spark 8 by 20), CastingBarFrame.xml:399-452 (small bar: icon 20 by 20 at -2, -5, spark 6 by 16,
--   spell name at the top -8), Blizzard_UnitFrame/Mainline/TargetFrame.xml:543-548 (target bar 150 by 10);
--   Blizzard_SwingTimer/Blizzard_SwingTimer.xml:12-56 (the bar sits 5 and 4 inside its frame, the name shadow is 171 wide, the labels 10 from each end),
--   Blizzard_SwingTimer.lua:258-267, 336-372, 415-432 (the fill grows from 0 to 1, the pip is at its end, the time left has one decimal, the dimmed
--   timer and red text out of range).
-- The client has no personal resource display source in the public mirror, so the size and the colours of the game's own look of those bars are
-- fixed samples here.
-- A part left to the game is its atlas when C_Texture answers for the atlas, else plain grey; while a shown part is grey the drawing shows a Game look
-- label at the bottom right (drawing.gameLook(stage) says whether). Besides the shared functions the brief names, the drawing calls their companions
-- ns.OwnText, ns.SetOutline, ns.SetOutlineColour, ns.Pixels and ns.IsSecret.
-- Fixed samples: the part of each bar that is filled, the sample numbers, the latency zone (5 percent of the player bar), the swing times.

ns.SetupDrawings = ns.SetupDrawings or {}

-- The width of the personal resource display at Bar width 100 (Blizzard_PersonalResourceDisplay.xml:41): the width of a matched cast bar and swing timer.
local DISPLAY_WIDTH = 200

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SPELL_ICON = "Interface\\Icons\\Spell_Shadow_ShadowBolt"
-- Class colour when the client does not answer for the player: a warrior.
local SAMPLE_CLASS = { 0.78, 0.61, 0.43 }
local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }
local GREY = { 0.72, 0.72, 0.72 }

local function G(path)
	return ns.Get(path)
end

local function Max(a, b)
	return a > b and a or b
end

-- Frames and regions of the drawing are the addon's own, so no module restyles them.
local function NewFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	return frame
end

local function NewTexture(parent, layer, sublevel)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
	ns.Own[texture] = true
	return texture
end

local function NewText(parent, fontObject)
	return ns.OwnText(parent, "OVERLAY", fontObject or "GameFontHighlightSmall")
end

-- The player's class colour, or a fixed one when the client does not say.
local function ClassRGB()
	local r, g, b = ns.ClassColour()
	if r then
		return r, g, b
	end
	return SAMPLE_CLASS[1], SAMPLE_CLASS[2], SAMPLE_CLASS[3]
end

local function Place(region, point, relativeTo, relativePoint, x, y)
	region:ClearAllPoints()
	region:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
end

-- A colour or an image file in a colour as the fill of a bar that is cut at `part` of its width, the way a status bar cuts its texture.
-- reverse puts it at the right end.
local function FillBar(fill, bar, width, part, reverse, file, r, g, b, atlas)
	local w = width * part
	fill:ClearAllPoints()
	if reverse then
		fill:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
		fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	else
		fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	end
	fill:SetWidth(Max(w, 0.01))
	fill:SetShown(w > 0)
	if atlas then
		fill:SetAtlas(atlas)
		fill:SetVertexColor(1, 1, 1, 1)
	elseif file then
		fill:SetTexture(file)
		fill:SetTexCoord(reverse and 1 - part or 0, reverse and 1 or part, 0, 1)
		fill:SetVertexColor(r, g, b, 1)
	else
		fill:SetVertexColor(1, 1, 1, 1)
		fill:SetColorTexture(r, g, b, 1)
	end
end

-- Whether the client has an atlas, asked the way Core.lua asks for a class icon.
local function AtlasExists(name)
	local api = C_Texture
	if type(api) == "table" and not ns.IsSecret(api) then
		if type(api.GetAtlasExists) == "function" then
			local ok, exists = pcall(api.GetAtlasExists, name)
			return ok and not ns.IsSecret(exists) and exists == true
		elseif type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			return ok and info ~= nil
		end
	end
	return false
end

-- A part the game draws: its atlas when the client answers for it, else a plain grey version, which the drawing labels Game look
-- (research/flatui-wizard/design.md 4.4). Returns whether the atlas was used.
local GAME_GREY = { 0.5, 0.5, 0.5, 1 }
local function GameTexture(inst, region, atlas, colour)
	colour = colour or GAME_GREY
	if atlas and AtlasExists(atlas) then
		region:SetAtlas(atlas)
		region:SetVertexColor(1, 1, 1, 1)
		inst.grey[region] = nil
		return true
	end
	region:SetColorTexture(colour[1], colour[2], colour[3], colour[4])
	inst.grey[region] = true
	return false
end

-- The game's own frame art of a bar: a back and a border. kind has the atlas of each and the border's anchors (nil: the whole frame); with no atlas
-- the back is plain grey and the border is four grey edges outside the frame.
local function NewArt(inst, frame, kind)
	local art = { inst = inst, kind = kind or {}, back = NewTexture(frame, "BACKGROUND", -7), border = NewTexture(frame, "BORDER", 1), edges = {} }
	art.back:SetAllPoints(frame)
	local inset = art.kind.inset
	if inset then
		art.border:SetPoint("TOPLEFT", frame, "TOPLEFT", inset[1], inset[2])
		art.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset[3], inset[4])
	else
		art.border:SetAllPoints(frame)
	end
	local top, bottom, left, right = NewTexture(frame, "BORDER", 0), NewTexture(frame, "BORDER", 0), NewTexture(frame, "BORDER", 0), NewTexture(frame, "BORDER", 0)
	local t = 2
	top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -t, 0)
	top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", t, 0)
	top:SetHeight(t)
	bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -t, 0)
	bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", t, 0)
	bottom:SetHeight(t)
	left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
	left:SetWidth(t)
	right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(t)
	art.edges = { top, bottom, left, right }
	return art
end

local function ShowArt(art, shown)
	shown = shown and true or false
	local inst, kind = art.inst, art.kind
	local atlasFrame = kind.frame and AtlasExists(kind.frame)
	-- Painted whether or not it shows, so a hidden bar looks the same as one that never showed.
	GameTexture(inst, art.back, kind.back, { 0.15, 0.15, 0.15, 0.9 })
	GameTexture(inst, art.border, atlasFrame and kind.frame or nil)
	for _, texture in ipairs(art.edges) do
		GameTexture(inst, texture, nil, { 0.6, 0.6, 0.6, 1 })
		texture:SetShown(shown and not atlasFrame)
	end
	art.back:SetShown(shown)
	art.border:SetShown(shown and atlasFrame and true or false)
end

-- Size, shown state and colour of a text. percent is the share of the size the game gave the font; a colour is nil for the game's.
-- outline is the id of a text outline row, or nil for the game's flags.
local function Look(text, percent, r, g, b, outline)
	if text then
		ns.TextStyle(text, { percent = percent, r = r, g = g, b = b, flags = outline and ns.OutlineFlags(outline) or nil })
	end
end

-- The colour of the health left at a fixed share. The curve is the three colours of the Colours page, low at 0, half at 0.5, full at 1
-- (HealthColour.lua:47-56); ns.HealthLeftColour answers when the build has it.
local function HealthLeft(part)
	if ns.HealthLeftColour then
		return ns.HealthLeftColour(part)
	end
	local lo, hi, at
	if part < 0.5 then
		lo, hi, at = "general.healthLow", "general.healthHalf", part / 0.5
	else
		lo, hi, at = "general.healthHalf", "general.healthFull", (part - 0.5) / 0.5
	end
	local r1, g1, b1 = ns.Colour(lo)
	local r2, g2, b2 = ns.Colour(hi)
	return r1 + (r2 - r1) * at, g1 + (g2 - g1) * at, b1 + (b2 - b1) * at
end

-- A drawing keeps one instance per stage.
-- drawing.parts and drawing.outlines stay those of the first stage; tiles and other stages are asked with drawing.partsOf(stage) and outlinesOf(stage).
local function Instance(made, stage, drawing, build)
	local inst = made[stage]
	if not inst then
		inst = build(stage)
		inst.grey = {}
		inst.gameLook = NewText(inst.root, "GameFontNormalSmall")
		if inst.gameLook then
			inst.gameLook:SetPoint("BOTTOMRIGHT", inst.root, "BOTTOMRIGHT", -8, 4)
			inst.gameLook:SetText("Game look")
			inst.gameLook:SetTextColor(GREY[1], GREY[2], GREY[3])
			inst.gameLook:Hide()
		end
		made[stage] = inst
	end
	if drawing.main == nil or drawing.main == stage then
		drawing.main = stage
		drawing.parts, drawing.outlines = inst.parts, inst.outlines
	end
	return inst
end

-- Shows the Game look label while a shown part is grey for want of the game's atlas.
local function ShowGameLook(inst)
	local any = false
	for region in pairs(inst.grey) do
		if region:IsShown() then
			any = true
			break
		end
	end
	if inst.gameLook then
		inst.gameLook:SetShown(any)
	end
	inst.gameLookShown = any
end

local function PartsOf(made, stage, field)
	local inst = made[stage]
	return inst and inst[field] or nil
end

local function SizeOf(made, stage)
	local inst = made[stage]
	if not inst then
		return 0, 0
	end
	return inst.root:GetWidth(), inst.root:GetHeight()
end

-- Cast bars ---------------------------------------------------------------------------------------------------

local CAST_ROWS = {
	{ opt = "player", label = "Player", name = "Shadow Bolt", state = "cast", part = 0.6, game = { 208, 11 } },
	{ opt = "pet", label = "Pet", name = "Firebolt", state = "cast", part = 0.45, game = { 195, 13 } },
	{ opt = "target", label = "Target", name = "Fireball", state = "cast", part = 0.6, game = { 150, 10 }, small = true, time = "1.2" },
	{ opt = "focus", label = "Focus", name = "Arcane Missiles", state = "channel", part = 0.4, game = { 150, 10 }, small = true, time = "1.8" },
	{ opt = "target", label = "Target, uninterruptible", name = "Polymorph", state = "shield", part = 0.7, game = { 150, 10 }, small = true, time = "0.9",
		shield = true },
}
local CAST_COLOURS = { cast = "castbars.castColour", channel = "castbars.channelColour", shield = "castbars.shieldColour" }
-- The atlas of the fill the game draws, by state (CastingBarFrame.xml:189, CastingBarFrame.lua:21-30 for the type names).
local CAST_ATLAS = { cast = "ui-castingbar-filling-standard", channel = "ui-castingbar-filling-channel", shield = "ui-castingbar-uninterruptable" }
-- The border and the back of a cast bar (CastingBarFrame.xml:218-224, 253-258, 409-436) and the plate behind the spell name (xml:198, 403).
local CAST_ART = { frame = "ui-castingbar-frame", back = "ui-castingbar-background", inset = { -1, 2, 1, -2 } }
local GAME_PLATE, GAME_SHIELD, GAME_PIP = "ui-castingbar-textbox", "ui-castingbar-shield", "ui-castingbar-pip"
local CAST_TEXT_WIDTH = 185
local CAST_LEFT, CAST_LABEL_GAP = 44, 30

local castMade = setmetatable({}, { __mode = "k" })
local castDrawing = {}

local function BuildCast(stage)
	local inst = { parts = {}, outlines = {}, rows = {} }
	inst.root = NewFrame(stage)
	inst.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	for index, spec in ipairs(CAST_ROWS) do
		local row = { spec = spec }
		local bar = NewFrame(inst.root)
		row.bar = bar
		row.art = NewArt(inst, bar, CAST_ART)
		row.plate = NewTexture(bar, "BACKGROUND", -6)
		row.plate:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		row.plate:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -12)
		row.fill = NewTexture(bar, "ARTWORK", 0)
		row.spark = NewTexture(bar, "OVERLAY", 2)
		row.icon = NewTexture(bar, "ARTWORK", 3)
		row.icon:SetTexture(SPELL_ICON)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		if spec.opt == "player" then
			row.latency = NewTexture(bar, "ARTWORK", 2)
			row.latency:SetColorTexture(1, 0, 0, 0.6)
		end
		if spec.shield then
			row.shield = NewTexture(bar, "ARTWORK", 4)
			row.shield:SetPoint("TOPLEFT", bar, "TOPLEFT", -27, 4)
			row.shield:SetSize(29, 33)
		end
		row.outline = ns.Outline(bar, bar)
		inst.outlines[#inst.outlines + 1] = row.outline
		row.text = NewText(bar)
		if row.text then
			row.text:SetHeight(16)
			row.text:SetText(spec.name)
		end
		if spec.time then
			row.time = NewText(bar)
			if row.time then
				row.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
				row.time:SetJustifyH("RIGHT")
				row.time:SetText(spec.time)
			end
		end
		row.label = NewText(inst.root, "GameFontNormalSmall")
		if row.label then
			row.label:SetText(spec.label)
			row.label:SetTextColor(GREY[1], GREY[2], GREY[3])
		end
		inst.rows[index] = row
	end
	-- The first row of each place stands for the setting rows of that place.
	local p, rows = inst.parts, inst.rows
	for _, row in ipairs(rows) do
		local opt = row.spec.opt
		for _, suffix in ipairs({ "", "Size", "Width", "Height" }) do
			p["castbars." .. opt .. suffix] = p["castbars." .. opt .. suffix] or row.bar
		end
	end
	local player, target, focus = rows[1], rows[3], rows[4]
	p["castbars.enabled"] = inst.root
	p["castbars.playerMatch"] = player.bar
	p["castbars.backdrop"] = player.bar
	p["castbars.textPlate"] = player.plate
	p["castbars.spark"] = player.spark
	p["castbars.shield"] = rows[5].shield
	p["castbars.stateBorder"] = player.bar
	p["castbars.latency"] = player.latency
	p["castbars.flat"] = player.fill
	p["castbars.texture"] = player.fill
	p["castbars.playerClass"] = player.fill
	p["castbars.targetOwn"] = target.fill
	p["castbars.targetCast"] = target.fill
	p["castbars.targetChannel"] = focus.fill
	p["castbars.playerText"] = player.text
	for _, path in ipairs({ "textSize", "textOutline", "textShow", "textAlign", "textOwn", "textColour" }) do
		p["castbars." .. path] = player.text
	end
	p["castbars.ownTime"] = target.time
	p["castbars.iconPos"] = target.icon
	p["castbars.playerIcon"] = player.icon
	return inst
end

-- The colour of the fill of a state on a place, as CastColour gives it.
local function CastFillColour(opt, state)
	if opt == "player" and (state == "cast" or state == "channel") and G("castbars.playerClass") then
		return ClassRGB()
	elseif (opt == "target" or opt == "focus") and (state == "cast" or state == "channel") and G("castbars.targetOwn") then
		return ns.Colour(state == "cast" and "castbars.targetCast" or "castbars.targetChannel")
	end
	return ns.Colour(CAST_COLOURS[state])
end

-- Where the spell name goes on a bar. The player and pet bars have a name 185 wide at the top, 10 down (CastingBarFrame.xml:313-318); the small bars
-- stretch it across the bar, 8 down (xml:449-455). The player bar with a size of its own puts it below or inside, centred (CastBarSize.lua:60-70).
local function PlaceCastText(text, bar, mode)
	text:ClearAllPoints()
	if mode == "top8" then
		text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -8)
		text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -8)
		return
	end
	text:SetWidth(CAST_TEXT_WIDTH)
	if mode == "inside" then
		text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	elseif mode == "below" then
		text:SetPoint("TOP", bar, "BOTTOM", 0, 1)
	else
		text:SetPoint("TOP", bar, "TOP", 0, -10)
	end
end

function castDrawing.build(stage)
	Instance(castMade, stage, castDrawing, BuildCast)
end

function castDrawing.draw(stage)
	local inst = Instance(castMade, stage, castDrawing, BuildCast)
	local enabled = G("castbars.enabled") == true
	local flat = enabled and G("castbars.flat") == true
	local file = flat and ns.BarTexture(G("castbars.texture")) or nil
	if not flat then
		file = ns.BarFile("game")
	end
	local percent = enabled and G("castbars.textSize") or 100
	local outline = enabled and G("castbars.textOutline") or nil
	local hideName = enabled and not G("castbars.textShow")
	local justify = JUSTIFY[enabled and G("castbars.textAlign") or "game"] or "CENTER"
	local tr, tg, tb
	if enabled and G("castbars.textOwn") then
		tr, tg, tb = ns.Colour("castbars.textColour")
	end
	local sizes, widest = {}, 0
	for index, row in ipairs(inst.rows) do
		local opt = row.spec.opt
		local w, h = row.spec.game[1], row.spec.game[2]
		if enabled and G("castbars." .. opt .. "Size") then
			w, h = G("castbars." .. opt .. "Width"), G("castbars." .. opt .. "Height")
		end
		-- The width of the personal resource display at Bar width 100 (Blizzard_PersonalResourceDisplay.xml:41); the height stays the game's or the chosen one.
		if enabled and opt == "player" and G("castbars.playerMatch") == "resource" then
			w = DISPLAY_WIDTH
			h = G("castbars.playerSize") and G("castbars.playerHeight") or h
		end
		sizes[index] = { w, h }
		widest = Max(widest, w)
	end
	local y = 10
	local labelX = CAST_LEFT + widest + CAST_LABEL_GAP
	for index, row in ipairs(inst.rows) do
		local spec, bar = row.spec, row.bar
		local opt = spec.opt
		local w, h = sizes[index][1], sizes[index][2]
		local on = enabled and G("castbars." .. opt) == true
		local sizeOn = enabled and G("castbars." .. opt .. "Size") == true
		bar:SetSize(w, h)
		Place(bar, "TOPLEFT", inst.root, "TOPLEFT", CAST_LEFT, -y)
		ns.SetOutline(row.outline, on, G("castbars.backdrop"))
		ShowArt(row.art, not on)
		row.plate:SetShown(not (on and not G("castbars.textPlate")))
		GameTexture(inst, row.plate, GAME_PLATE, { 0.3, 0.3, 0.3, 0.7 })
		-- The fill and its colour; the game's own fill is its atlas, or grey.
		local r, g, b
		if flat then
			r, g, b = CastFillColour(opt, spec.state)
			FillBar(row.fill, bar, w, spec.part, false, file, r, g, b)
			inst.grey[row.fill] = nil
		else
			local atlas = AtlasExists(CAST_ATLAS[spec.state]) and CAST_ATLAS[spec.state] or nil
			r, g, b = GREY[1], GREY[2], GREY[3]
			FillBar(row.fill, bar, w, spec.part, false, file, r, g, b, atlas)
			inst.grey[row.fill] = not atlas or nil
		end
		if flat and G("castbars.stateBorder") then
			ns.SetOutlineColour(row.outline, r, g, b)
		else
			ns.SetOutlineColour(row.outline, nil, nil, nil)
		end
		-- The spark: 8 by 20 on the player and pet bars (higher by 9 than the bar with a size of its own on the player bar), 6 by 16 on the small ones.
		local sparkW, sparkH = 8, 20
		if spec.small then
			sparkW, sparkH = 6, 16
		elseif opt == "player" and sizeOn then
			sparkH = h + 9
		end
		row.spark:SetSize(sparkW, sparkH)
		Place(row.spark, "CENTER", bar, "LEFT", w * spec.part, 0)
		row.spark:SetShown(not (enabled and not G("castbars.spark")))
		GameTexture(inst, row.spark, GAME_PIP, { 0.9, 0.9, 0.9, 0.9 })
		if row.shield then
			row.shield:SetShown(not (enabled and not G("castbars.shield")))
			GameTexture(inst, row.shield, GAME_SHIELD, { 0.62, 0.64, 0.7, 1 })
		end
		if row.latency then
			row.latency:ClearAllPoints()
			row.latency:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
			row.latency:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
			row.latency:SetWidth(Max(w * 0.05, 0.01))
			row.latency:SetShown(flat and G("castbars.latency") == true)
		end
		-- The icon: left of the small bars unless the row says right or hidden; on the player and pet bars only with the row on.
		if spec.small then
			local place = enabled and G("castbars.iconPos") or "game"
			row.icon:SetSize(20, 20)
			if place == "right" then
				Place(row.icon, "LEFT", bar, "RIGHT", 5, 0)
			else
				Place(row.icon, "RIGHT", bar, "LEFT", -2, -5)
			end
			row.icon:SetShown(place ~= "hidden")
		else
			row.icon:SetSize(h, h)
			Place(row.icon, "RIGHT", bar, "LEFT", -5, 0)
			row.icon:SetShown(flat and G("castbars.playerIcon") == true)
		end
		-- The spell name.
		if row.text then
			local mode = "top10"
			if spec.small then
				mode = "top8"
			elseif opt == "player" and sizeOn then
				mode = G("castbars.playerText") == "inside" and "inside" or "below"
			end
			PlaceCastText(row.text, bar, mode)
			row.text:SetJustifyH(justify)
			row.text:SetShown(not hideName)
			Look(row.text, percent, tr, tg, tb, outline)
		end
		if row.time then
			row.time:SetShown(enabled and G("castbars.ownTime") == true)
		end
		if row.label then
			Place(row.label, "LEFT", inst.root, "TOPLEFT", labelX, -(y + h / 2))
		end
		y = y + h + 22
	end
	inst.root:SetSize(labelX + 150, y + 16)
	ShowGameLook(inst)
end

function castDrawing.size(stage)
	return SizeOf(castMade, stage)
end

function castDrawing.partsOf(stage)
	return PartsOf(castMade, stage, "parts")
end

function castDrawing.outlinesOf(stage)
	return PartsOf(castMade, stage, "outlines")
end

function castDrawing.gameLook(stage)
	return castMade[stage] and castMade[stage].gameLookShown or false
end

castDrawing.parts = {}
ns.SetupDrawings["mock-cast-bar"] = castDrawing

-- Personal resource display -----------------------------------------------------------------------------------

local RES_WIDTH, RES_LEFT, RES_TOP = 150, 14, 12
local RES_BARS = {
	{ opt = "health", label = "Health", height = 14 },
	{ opt = "power", label = "Power", height = 11 },
	{ opt = "alt", label = "Alternate power", height = 7 },
}
-- The game's gap between two bars (Bars.lua:98-100 reads it from the bar) and the fixed samples: 70 percent of 10,000 health, 70 percent of 6,000 power.
local RES_GAP, RES_PART = 4, 0.7
local RES_VALUES = { health = "7,000", power = "4,200" }

local resMade = setmetatable({}, { __mode = "k" })
local resDrawing = {}

local function BuildResource(stage)
	local inst = { parts = {}, outlines = {}, bars = {} }
	inst.root = NewFrame(stage)
	inst.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	for index, spec in ipairs(RES_BARS) do
		local bar = { spec = spec }
		bar.frame = NewFrame(inst.root)
		bar.art = NewArt(inst, bar.frame)
		bar.fill = NewTexture(bar.frame, "ARTWORK", 0)
		bar.outline = ns.Outline(bar.frame, bar.frame)
		inst.outlines[#inst.outlines + 1] = bar.outline
		if spec.opt ~= "alt" then
			bar.percent = NewText(bar.frame)
			bar.value = NewText(bar.frame)
			if bar.percent then
				bar.percent:SetPoint("LEFT", bar.frame, "LEFT", 4, 0)
				bar.percent:SetJustifyH("LEFT")
				bar.percent:SetText("70%")
			end
			if bar.value then
				bar.value:SetPoint("RIGHT", bar.frame, "RIGHT", -4, 0)
				bar.value:SetJustifyH("RIGHT")
				bar.value:SetText(RES_VALUES[spec.opt])
			end
		end
		bar.label = NewText(inst.root, "GameFontNormalSmall")
		if bar.label then
			bar.label:SetText(spec.label)
			bar.label:SetTextColor(GREY[1], GREY[2], GREY[3])
		end
		inst.bars[index] = bar
	end
	local health, power, alt = inst.bars[1], inst.bars[2], inst.bars[3]
	local p = inst.parts
	p["resource.enabled"] = inst.root
	p["resource.health"] = health.frame
	p["resource.power"] = power.frame
	p["resource.alt"] = alt.frame
	p["resource.backdrop"] = health.frame
	p["resource.join"] = power.frame
	p["resource.flat"] = health.fill
	p["resource.texture"] = health.fill
	p["resource.healthOwn"] = health.fill
	p["resource.healthColour"] = health.fill
	p["resource.healthByLeft"] = health.fill
	p["resource.powerOwn"] = power.fill
	p["resource.powerColour"] = power.fill
	for _, key in ipairs({ "textSize", "textOutline", "text", "percent", "textOwn", "textColour" }) do
		p["resource." .. key] = health.percent
	end
	p["resource.value"] = health.value
	return inst
end

-- The player's power: its token when the client says, else mana.
local function PowerToken()
	local ok, _, token = pcall(UnitPowerType, "player")
	if ok and type(token) == "string" and not ns.IsSecret(token) then
		return token
	end
	return "MANA"
end

function resDrawing.build(stage)
	Instance(resMade, stage, resDrawing, BuildResource)
end

function resDrawing.draw(stage)
	local inst = Instance(resMade, stage, resDrawing, BuildResource)
	local enabled = G("resource.enabled") == true
	local flat = enabled and G("resource.flat") == true
	local file = flat and ns.BarTexture(G("resource.texture")) or nil
	if not flat then
		file = ns.BarFile("game")
	end
	-- The colours of the health and power fill: the game's, a colour of the row, and the health left over the health colour.
	-- The client has no source for the game's personal resource display, so a colour it does not give is plain grey, labelled Game look.
	local token = PowerToken()
	local pr, pg, pb = ns.PowerColour(token)
	local powerGrey = not pr
	if powerGrey then
		pr, pg, pb = GREY[1], GREY[2], GREY[3]
	end
	local hr, hg, hb = GREY[1], GREY[2], GREY[3]
	local healthGrey = true
	if enabled and G("resource.healthOwn") then
		hr, hg, hb = ns.Colour("resource.healthColour")
		healthGrey = false
	end
	if flat and G("resource.healthByLeft") then
		hr, hg, hb = HealthLeft(RES_PART)
		healthGrey = false
	end
	if enabled and G("resource.powerOwn") then
		pr, pg, pb = ns.Colour("resource.powerColour")
		powerGrey = false
	end
	local percent = enabled and G("resource.textSize") or 100
	local outline = enabled and G("resource.textOutline") or nil
	local showText = not enabled or G("resource.text") == true
	local showPercent = not enabled or (showText and G("resource.percent") == true)
	local showValue = not enabled or (showText and G("resource.value") == true)
	local tr, tg, tb
	if enabled and G("resource.textOwn") then
		tr, tg, tb = ns.Colour("resource.textColour")
	end
	local y = RES_TOP
	local shown = {}
	for index, bar in ipairs(inst.bars) do
		local spec = bar.spec
		local on = enabled and G("resource." .. spec.opt) == true
		shown[index] = on
		-- Two bars share one border only when both have it and Join bars is on: the lower bar sits one border thickness below the upper one
		-- (Bars.lua:114-116), so the upper bar's bottom edge and the lower bar's top edge fill the same strip. Otherwise the game's gap.
		local gap = RES_GAP
		if index > 1 then
			local above = shown[index - 1]
			if enabled and G("resource.join") and on and above then
				gap = ns.Pixels(bar.frame, G("general.thickness"))
			end
			y = y + gap
		end
		bar.frame:SetSize(RES_WIDTH, spec.height)
		Place(bar.frame, "TOPLEFT", inst.root, "TOPLEFT", RES_LEFT, -y)
		ns.SetOutline(bar.outline, on, G("resource.backdrop"))
		ShowArt(bar.art, not on)
		local r, g, b, grey = GREY[1], GREY[2], GREY[3], true
		local part = 1
		if spec.opt == "health" then
			r, g, b, part, grey = hr, hg, hb, RES_PART, healthGrey
		elseif spec.opt == "power" then
			r, g, b, part, grey = pr, pg, pb, RES_PART, powerGrey
		end
		FillBar(bar.fill, bar.frame, RES_WIDTH, part, false, file, r, g, b)
		inst.grey[bar.fill] = grey or nil
		if bar.percent then
			bar.percent:SetShown(showPercent)
			Look(bar.percent, percent, tr, tg, tb, outline)
		end
		if bar.value then
			bar.value:SetShown(showValue)
			Look(bar.value, percent, tr, tg, tb, outline)
		end
		if bar.label then
			Place(bar.label, "LEFT", inst.root, "TOPLEFT", RES_LEFT + RES_WIDTH + 18, -(y + spec.height / 2))
		end
		y = y + spec.height
	end
	inst.root:SetSize(RES_LEFT + RES_WIDTH + 140, y + RES_TOP)
	ShowGameLook(inst)
end

function resDrawing.size(stage)
	return SizeOf(resMade, stage)
end

function resDrawing.partsOf(stage)
	return PartsOf(resMade, stage, "parts")
end

function resDrawing.outlinesOf(stage)
	return PartsOf(resMade, stage, "outlines")
end

function resDrawing.gameLook(stage)
	return resMade[stage] and resMade[stage].gameLookShown or false
end

resDrawing.parts = {}
ns.SetupDrawings["mock-resource"] = resDrawing

-- Swing timers ------------------------------------------------------------------------------------------------

-- A timer is 190 by 22 with its bar 5 and 4 inside, so the bar is 180 by 14 (Blizzard_SwingTimer.xml:21-27).
local SWING_FRAME_W, SWING_FRAME_H, SWING_BAR_W, SWING_BAR_H = 190, 22, 180, 14
local SWING_LEFT, SWING_TOP, SWING_GAP, SWING_SHADOW = 14, 10, 6, 171
-- The game's range colours (Blizzard_SwingTimer.lua:423) and its atlases (Blizzard_SwingTimer.xml:12-56, 62-100).
local GAME_IN, GAME_OUT, GAME_RANGE_ALPHA = { 1, 1, 1 }, { 1, 0.1, 0.1 }, 0.4
local SWING_FILL_ATLAS = { main = "ui-swingtimerbar-filling-mainhand", off = "ui-swingtimerbar-filling-offhand", ranged = "ui-swingtimerbar-filling-ranged" }
local SWING_ART = { frame = "ui-swingtimerbar-frame", back = "ui-swingtimerbar-background" }
local SWING_PIP, SWING_SHADOW_ATLAS = "ui-swingtimerbar-pip", "ui-swingtimerbar-textshadow-left"
-- The names the game gives the hands, in the client's language (Blizzard_SwingTimer.xml:62, 75, 88).
local function HandName(hand)
	if hand == "main" then
		return SWING_TIMER_MAIN_HAND or "Main hand"
	elseif hand == "off" then
		return SWING_TIMER_OFF_HAND or "Off hand"
	end
	return SWING_TIMER_RANGED or "Ranged"
end
-- Fixed samples: how far each timer has run at the start, and how long a swing lasts in seconds.
local SWING_ROWS = {
	{ hand = "main", note = "In range", part = 0.64, period = 2.6 },
	{ hand = "off", note = "In range", part = 0.4, period = 2.6 },
	{ hand = "ranged", note = "In range", part = 0.8, period = 3.2 },
	{ hand = "main", note = "Out of range", part = 0.55, period = 2.6, out = true },
	{ hand = "off", note = "Out of combat", part = 0, period = 2.6, idle = true },
}

local swingMade = setmetatable({}, { __mode = "k" })
local swingDrawing = {}

local function BuildSwing(stage)
	local inst = { parts = {}, outlines = {}, rows = {}, clock = 0, looks = {} }
	inst.root = NewFrame(stage)
	inst.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	for index, spec in ipairs(SWING_ROWS) do
		local row = { spec = spec }
		row.timer = NewFrame(inst.root)
		row.timer:SetSize(SWING_FRAME_W, SWING_FRAME_H)
		row.art = NewArt(inst, row.timer, SWING_ART)
		row.bar = NewFrame(row.timer)
		row.bar:SetPoint("TOPLEFT", row.timer, "TOPLEFT", 5, -4)
		row.bar:SetPoint("BOTTOMRIGHT", row.timer, "BOTTOMRIGHT", -5, 4)
		row.fill = NewTexture(row.bar, "ARTWORK", 0)
		row.shadow = NewTexture(row.bar, "OVERLAY", 0)
		row.shadow:SetPoint("TOPLEFT", row.bar, "TOPLEFT", 0, 0)
		row.shadow:SetPoint("BOTTOMLEFT", row.bar, "BOTTOMLEFT", 0, 0)
		row.shadow:SetWidth(SWING_SHADOW)
		row.pip = NewTexture(row.bar, "OVERLAY", 2)
		row.pip:SetSize(3, SWING_BAR_H + 4)
		row.barOutline = ns.Outline(row.bar, row.bar)
		row.wholeOutline = ns.Outline(row.timer, row.timer)
		inst.outlines[#inst.outlines + 1] = row.barOutline
		inst.outlines[#inst.outlines + 1] = row.wholeOutline
		row.type = NewText(row.bar)
		row.time = NewText(row.bar)
		if row.type then
			row.type:SetPoint("LEFT", row.bar, "LEFT", 10, 0)
			row.type:SetJustifyH("LEFT")
			row.type:SetText(HandName(spec.hand))
		end
		if row.time then
			row.time:SetPoint("RIGHT", row.bar, "RIGHT", -10, 0)
			row.time:SetJustifyH("RIGHT")
		end
		row.note = NewText(inst.root, "GameFontNormalSmall")
		if row.note then
			row.note:SetText(spec.note)
			row.note:SetTextColor(GREY[1], GREY[2], GREY[3])
		end
		inst.rows[index] = row
	end
	local main, off, ranged, out, idle = inst.rows[1], inst.rows[2], inst.rows[3], inst.rows[4], inst.rows[5]
	local p = inst.parts
	p["swing.enabled"] = inst.root
	p["swing.main"] = main.timer
	p["swing.off"] = off.timer
	p["swing.ranged"] = ranged.timer
	p["swing.outline"] = main.timer
	p["swing.width"] = main.timer
	p["swing.backdrop"] = main.timer
	p["swing.flat"] = main.fill
	p["swing.texture"] = main.fill
	p["swing.mainColour"] = main.fill
	p["swing.offColour"] = off.fill
	p["swing.rangedColour"] = ranged.fill
	p["swing.classColour"] = main.fill
	p["swing.spark"] = main.pip
	p["swing.textShadow"] = main.shadow
	p["swing.reverse"] = main.fill
	p["swing.rangeAlpha"] = out.bar
	p["swing.idle"] = idle.timer
	for _, key in ipairs({ "textSize", "textOutline", "name", "textOwn", "textColour" }) do
		p["swing." .. key] = main.type
	end
	p["swing.time"] = main.time
	p["swing.rangeTextColour"] = out.type
	-- The timers move on sample times, only while the drawing is shown.
	inst.root:SetScript("OnUpdate", function(_, elapsed)
		inst.clock = inst.clock + (elapsed or 0)
		if inst.clock > 3600 then
			inst.clock = 0
		end
		if inst.paint then
			inst.paint(inst)
		end
	end)
	return inst
end

-- Where each timer is: the share of its swing run, and the seconds left.
local function SwingProgress(spec, clock)
	if spec.idle then
		return 0, 0
	end
	local run = (spec.part + clock / spec.period) % 1
	return run, spec.period * (1 - run)
end

-- The parts of the timers that move: the fill, the spark at its end and the time left.
local function PaintSwing(inst)
	local look = inst.looks
	if not look.ready then
		return
	end
	for _, row in ipairs(inst.rows) do
		local spec = row.spec
		local run, left = SwingProgress(spec, inst.clock)
		FillBar(row.fill, row.bar, inst.barW or SWING_BAR_W, run, look.reverse, look.file, look.colour[spec.hand][1], look.colour[spec.hand][2], look.colour[spec.hand][3],
			look.atlas[spec.hand])
		-- The pip sits on the fill's end: its side on the fill's side (Bars.lua:507-509).
		local side = look.reverse and "LEFT" or "RIGHT"
		row.pip:ClearAllPoints()
		row.pip:SetPoint(side, row.fill, side, 0, 0)
		row.pip:SetShown(not spec.idle and look.spark)
		if row.time then
			row.time:SetText(("%.1f"):format(left))
		end
	end
end

function swingDrawing.build(stage)
	Instance(swingMade, stage, swingDrawing, BuildSwing)
end

function swingDrawing.draw(stage)
	local inst = Instance(swingMade, stage, swingDrawing, BuildSwing)
	local enabled = G("swing.enabled") == true
	local flat = enabled and G("swing.flat") == true
	local whole = enabled and G("swing.outline") == "frame"
	local idleHide = enabled and G("swing.idle") ~= "show"
	local file = flat and ns.BarTexture(G("swing.texture")) or nil
	if not flat then
		file = ns.BarFile("game")
	end
	local colour = {}
	if flat then
		local cr, cg, cb
		if G("swing.classColour") then
			cr, cg, cb = ClassRGB()
		end
		for _, hand in ipairs({ "main", "off", "ranged" }) do
			if cr then
				colour[hand] = { cr, cg, cb }
			else
				local r, g, b = ns.Colour("swing." .. hand .. "Colour")
				colour[hand] = { r, g, b }
			end
		end
	else
		for _, hand in ipairs({ "main", "off", "ranged" }) do
			colour[hand] = GREY
		end
	end
	local atlas = {}
	if not flat then
		for hand, name in pairs(SWING_FILL_ATLAS) do
			atlas[hand] = AtlasExists(name) and name or nil
		end
	end
	local look = inst.looks
	look.ready, look.file, look.colour, look.atlas = true, file, colour, atlas
	look.reverse = enabled and G("swing.reverse") == true
	look.spark = not (flat and not G("swing.spark"))
	local percent = enabled and G("swing.textSize") or 100
	local outline = enabled and G("swing.textOutline") or nil
	local hideName = enabled and not G("swing.name")
	local hideTime = enabled and not G("swing.time")
	local own = enabled and G("swing.textOwn")
	local rangeAlpha = enabled and G("swing.rangeAlpha") / 100 or GAME_RANGE_ALPHA
	local y = SWING_TOP
	local frameW = enabled and G("swing.width") == "resource" and DISPLAY_WIDTH or SWING_FRAME_W
	inst.barW = frameW - (SWING_FRAME_W - SWING_BAR_W)
	for _, row in ipairs(inst.rows) do
		local spec = row.spec
		row.timer:SetSize(frameW, SWING_FRAME_H)
		local on = enabled and G("swing." .. spec.hand) == true
		local idle = idleHide and spec.idle
		Place(row.timer, "TOPLEFT", inst.root, "TOPLEFT", SWING_LEFT, -y)
		-- The border: around the bar or around the whole timer; the game's own border and background go when it is on.
		ns.SetOutline(row.barOutline, on and not whole, G("swing.backdrop"))
		ns.SetOutline(row.wholeOutline, on and whole and not idle, G("swing.backdrop"))
		ShowArt(row.art, not on)
		inst.grey[row.fill] = (not flat and not atlas[spec.hand]) or nil
		GameTexture(inst, row.pip, SWING_PIP, { 0.9, 0.9, 0.9, 0.95 })
		GameTexture(inst, row.shadow, SWING_SHADOW_ATLAS, { 0, 0, 0, 0.45 })
		row.bar:SetShown(not idle)
		row.bar:SetAlpha(spec.out and rangeAlpha or 1)
		row.shadow:SetShown(not (flat and not G("swing.textShadow")))
		local r, g, b = GAME_IN[1], GAME_IN[2], GAME_IN[3]
		if spec.out then
			r, g, b = GAME_OUT[1], GAME_OUT[2], GAME_OUT[3]
		end
		if own then
			r, g, b = ns.Colour(spec.out and "swing.rangeTextColour" or "swing.textColour")
		end
		if row.type then
			row.type:SetShown(not hideName)
			Look(row.type, percent, r, g, b, outline)
		end
		if row.time then
			row.time:SetShown(not hideTime)
			Look(row.time, percent, r, g, b, outline)
		end
		if row.note then
			Place(row.note, "LEFT", inst.root, "TOPLEFT", SWING_LEFT + frameW + 18, -(y + SWING_FRAME_H / 2))
		end
		y = y + SWING_FRAME_H + SWING_GAP
	end
	inst.paint = PaintSwing
	PaintSwing(inst)
	inst.root:SetSize(SWING_LEFT + frameW + 140, y + SWING_TOP)
	ShowGameLook(inst)
end

function swingDrawing.size(stage)
	return SizeOf(swingMade, stage)
end

function swingDrawing.partsOf(stage)
	return PartsOf(swingMade, stage, "parts")
end

function swingDrawing.outlinesOf(stage)
	return PartsOf(swingMade, stage, "outlines")
end

function swingDrawing.gameLook(stage)
	return swingMade[stage] and swingMade[stage].gameLookShown or false
end

swingDrawing.parts = {}
ns.SetupDrawings["mock-swing"] = swingDrawing
