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
--   the sizes and the place of the spell name of CastBarSize.lua:92-150, the rank after the spell name of CastRank.lua, and the tick marks of a
--   channel on the player bar of CastTicks.lua (the last row, Drain Life with 5 ticks), dim where the channel has passed them.
--   resource display: ApplyResourceBar, JoinBar, ApplyResourceFill, ApplyResourceText (Bars.lua:78-165), the custom colours (Bars.lua:195-250).
--   swing timers: ApplySwingTimer, ApplySwingFill, ApplySwingText, ApplySwingRange, ApplySwingReverse, ApplySwingIdle (Bars.lua:335-530), and the
--   Queued ability colour of Q over the first main hand timer in the second half of each of its swings.
-- Sizes and places of the game's own parts come from the client's interface source:
--   Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml:198-204, 241-252, 313-318, 326-331 (player and pet bar: plate 12 below the bar, shield 29 by 33 at
--   -27, 4, icon 16 by 16 at -5, spell name at the top -10, spark 8 by 20), CastingBarFrame.xml:399-452 (small bar: icon 20 by 20 at -2, -5, spark 6 by 16,
--   spell name at the top -8), Blizzard_UnitFrame/Mainline/TargetFrame.xml:543-548 (target bar 150 by 10);
--   Blizzard_SwingTimer/Blizzard_SwingTimer.xml:12-56 (the bar sits 5 and 4 inside its frame, the name shadow is 171 wide, the labels 10 from each end),
--   Blizzard_SwingTimer.lua:265-276, 340-377, 425-448 (the fill grows from 0 to 1, the pip is at its end, the time left has one decimal, the dimmed
--   timer and red text out of range).
-- The client has no personal resource display source in the public mirror, so the size and the colours of the game's own look of those bars are
-- fixed samples here.
-- A part left to the game is its atlas when C_Texture answers for the atlas, else plain grey; while a shown part is grey the drawing shows a Game look
-- label at the bottom right (drawing.gameLook(stage) says whether). Besides the shared functions the brief names, the drawing calls their companions
-- ns.OwnText, ns.SetOutline, ns.SetOutlineColour, ns.Pixels and ns.IsSecret.
-- Fixed samples: the part of each bar that is filled, the sample numbers, the latency zone (5 percent of the player bar), the swing times.
-- ns.DrawCasts gives test mode's stand-ins (TestHud.lua) the same painters for one bar: DC.Cast and DC.PaintCast for a cast bar in a state (cast,
-- channel, interrupted or shield, the interrupted one in Interrupted colour or the game's interrupted fill) at a share of its run, DC.Swing and
-- DC.PaintSwing for a swing timer, and DC.CastProgress and DC.SwingProgress for the parts that move.

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

-- Whether the client has an atlas, asked the way Core.lua asks for a class icon, once for each atlas: the client's atlases do not change in a session,
-- and test mode's stand-ins ask on every frame they move (TestHud.lua).
local atlasKnown = {}
local function AtlasExists(name)
	if name == nil then
		return false
	elseif atlasKnown[name] ~= nil then
		return atlasKnown[name]
	end
	local api, exists = C_Texture, false
	if type(api) == "table" and not ns.IsSecret(api) then
		if type(api.GetAtlasExists) == "function" then
			local ok, answer = pcall(api.GetAtlasExists, name)
			exists = ok and not ns.IsSecret(answer) and answer == true
		elseif type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			exists = ok and info ~= nil
		end
	end
	atlasKnown[name] = exists
	return exists
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
	{ opt = "player", label = "Player", name = "Shadow Bolt", rank = "Rank 3", state = "cast", part = 0.6, game = { 208, 11 }, time = "1.0" },
	{ opt = "pet", label = "Pet", name = "Firebolt", state = "cast", part = 0.45, game = { 195, 13 }, time = "1.4" },
	{ opt = "target", label = "Target", name = "Fireball", state = "cast", part = 0.6, game = { 150, 10 }, small = true, time = "1.2" },
	{ opt = "focus", label = "Focus", name = "Arcane Missiles", state = "channel", part = 0.4, game = { 150, 10 }, small = true, time = "1.8" },
	{ opt = "target", label = "Target, uninterruptible", name = "Polymorph", state = "shield", part = 0.7, game = { 150, 10 }, small = true, time = "0.9",
		shield = true },
	{ opt = "player", label = "Player, channel", name = "Drain Life", state = "channel", part = 0.55, game = { 208, 11 }, ticks = 5, time = "2.7" },
}
-- The game's size of each bar (the rows above, and the boss bars of TargetFrame.xml:543-548, small bars as the target's).
local CAST_GAME = { player = { 208, 11 }, pet = { 195, 13 }, target = { 150, 10 }, focus = { 150, 10 }, boss = { 150, 10 } }
local CAST_COLOURS = { cast = "castbars.castColour", channel = "castbars.channelColour", shield = "castbars.shieldColour",
	interrupted = "castbars.interruptedColour" }
-- The atlas of the fill the game draws, by state (CastingBarFrame.xml:189, CastingBarFrame.lua:21-30 for the type names; the interrupted one as Bars.lua
-- reads it).
local CAST_ATLAS = { cast = "ui-castingbar-filling-standard", channel = "ui-castingbar-filling-channel", shield = "ui-castingbar-uninterruptable",
	interrupted = "ui-castingbar-interrupted" }
-- The border and the back of a cast bar (CastingBarFrame.xml:218-224, 253-258, 409-436) and the plate behind the spell name (xml:198, 403).
local CAST_ART = { frame = "ui-castingbar-frame", back = "ui-castingbar-background", inset = { -1, 2, 1, -2 } }
local GAME_PLATE, GAME_SHIELD, GAME_PIP = "ui-castingbar-textbox", "ui-castingbar-shield", "ui-castingbar-pip"
local CAST_TEXT_WIDTH = 185
local CAST_LEFT, CAST_LABEL_GAP = 44, 30

local castMade = setmetatable({}, { __mode = "k" })
local castDrawing = {}

-- One cast bar on `parent`: its frame, the game's art, the plate behind the spell name, the fill, the spark, the icon, the latency zone of the player
-- bar, the shield of a bar that may show one (spec.shield), the outline, the spell name, the time of a bar with spec.time and the tick marks of a
-- channel of spec.ticks ticks (CastTicks.lua). inst holds the grey parts and the outlines of the drawing it belongs to.
local function NewCastBar(inst, parent, spec)
	local row = { spec = spec, inst = inst }
	local bar = NewFrame(parent)
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
	if spec.ticks then
		row.ticks = {}
		for k = 1, spec.ticks - 1 do
			local mark = NewTexture(bar, "OVERLAY", 1)
			mark:SetColorTexture(1, 1, 1, 0.6)
			mark:Hide()
			row.ticks[k] = mark
		end
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
		row.text:SetText(spec.name or "")
	end
	if spec.time then
		row.time = NewText(bar)
		if row.time then
			row.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
			row.time:SetJustifyH("RIGHT")
			row.time:SetText(spec.time)
		end
	end
	return row
end

local function BuildCast(stage)
	local inst = { parts = {}, outlines = {}, rows = {}, grey = {} }
	inst.root = NewFrame(stage)
	inst.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	for index, spec in ipairs(CAST_ROWS) do
		local row = NewCastBar(inst, inst.root, spec)
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
	for _, row in ipairs(rows) do
		if row.ticks then
			p["castbars.ticks"] = p["castbars.ticks"] or row.bar
		end
	end
	p["castbars.flat"] = player.fill
	p["castbars.texture"] = player.fill
	p["castbars.playerClass"] = player.fill
	p["castbars.targetOwn"] = target.fill
	p["castbars.targetCast"] = target.fill
	p["castbars.targetChannel"] = focus.fill
	p["castbars.playerText"] = player.text
	-- Spell rank on the player bar writes the rank after the name (CastRank.lua).
	p["castbars.rank"] = player.text
	for _, path in ipairs({ "textSize", "textOutline", "textShow", "textAlign", "textOwn", "textColour" }) do
		p["castbars." .. path] = player.text
	end
	p["castbars.ownTime"] = target.time
	p["castbars.playerTime"] = player.time
	p["castbars.iconPos"] = target.icon
	p["castbars.playerIcon"] = player.icon
	return inst
end

-- The colour of the fill of a state on a place, as CastColour gives it (Bars.lua): an enemy's cast or channel the player's interrupt is ready for
-- (kick) takes Interrupt ready colour while Interrupt readiness on enemy casts is on, the player bar its class colour with Class colour, the target
-- and focus bars their own colours, else the cast colours of the Flat UI page.
local function CastFillColour(opt, state, kick)
	if kick and (state == "cast" or state == "channel") and G("castbars.interrupt") == true then
		return ns.Colour("castbars.interruptReady")
	elseif opt == "player" and (state == "cast" or state == "channel") and G("castbars.playerClass") then
		return ClassRGB()
	elseif (opt == "target" or opt == "focus") and (state == "cast" or state == "channel") and G("castbars.targetOwn") then
		return ns.Colour(state == "cast" and "castbars.targetCast" or "castbars.targetChannel")
	end
	return ns.Colour(CAST_COLOURS[state] or CAST_COLOURS.cast)
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

-- What the rows of the page say for every bar, read once for a paint. game: the look the game gives a bar Flat UI does not style (the boss bars).
local function CastLook(game)
	local look = { enabled = not game and G("castbars.enabled") == true }
	local enabled = look.enabled
	look.flat = enabled and G("castbars.flat") == true
	look.file = look.flat and ns.BarTexture(G("castbars.texture")) or nil
	if not look.flat then
		look.file = ns.BarFile("game")
	end
	look.percent = enabled and G("castbars.textSize") or 100
	look.outline = enabled and G("castbars.textOutline") or nil
	look.hideName = enabled and not G("castbars.textShow")
	look.justify = JUSTIFY[enabled and G("castbars.textAlign") or "game"] or "CENTER"
	if enabled and G("castbars.textOwn") then
		look.r, look.g, look.b = ns.Colour("castbars.textColour")
	end
	return look
end

-- The width and height of a bar of a place: the game's, the place's own size, or the width of the personal resource display at Bar width 100
-- (Blizzard_PersonalResourceDisplay.xml:41) for the player bar matched to it, whose height stays the game's or the chosen one.
local function CastSize(look, opt, game)
	local w, h = game[1], game[2]
	if look.enabled and G("castbars." .. opt .. "Size") then
		w, h = G("castbars." .. opt .. "Width"), G("castbars." .. opt .. "Height")
	end
	if look.enabled and opt == "player" and G("castbars.playerMatch") == "resource" then
		w = DISPLAY_WIDTH
		h = G("castbars.playerSize") and G("castbars.playerHeight") or h
	end
	return w, h
end

-- The fill of a bar at `part` of its width in the colour of its state, the spark at its end and the shield of a cast that cannot be interrupted.
-- The game's own fill is its atlas, or grey. Returns the colour of the fill.
local function CastFill(row, look, opt, state, part, w, kick)
	local inst, enabled = row.inst, look.enabled
	local r, g, b
	if look.flat then
		r, g, b = CastFillColour(opt, state, kick)
		FillBar(row.fill, row.bar, w, part, false, look.file, r, g, b)
		inst.grey[row.fill] = nil
	else
		local atlas = AtlasExists(CAST_ATLAS[state] or CAST_ATLAS.cast) and CAST_ATLAS[state] or nil
		r, g, b = GREY[1], GREY[2], GREY[3]
		FillBar(row.fill, row.bar, w, part, false, look.file, r, g, b, atlas)
		inst.grey[row.fill] = not atlas or nil
	end
	Place(row.spark, "CENTER", row.bar, "LEFT", w * part, 0)
	if row.shield then
		row.shield:SetShown(state == "shield" and not (enabled and not G("castbars.shield")))
		GameTexture(inst, row.shield, GAME_SHIELD, { 0.62, 0.64, 0.7, 1 })
	end
	return r, g, b
end

-- The spell name of a bar: `name`, else its own, with the rank after it on the player bar while Spell rank on the player bar is on.
local function CastName(row, look, name)
	local spec = row.spec
	if name then
		return name
	end
	return spec.rank and look.enabled and G("castbars.rank") == true and (spec.name .. " (" .. spec.rank .. ")") or spec.name or ""
end

-- Dims the tick marks a channel at `part` of its width (the share left: the fill ends there) has passed, those right of the end of the fill, as
-- CastTicks.lua dims a mark once its tick has landed; the next one stays bright. On the Drain Life row, at 0.55, the marks at 0.6 and 0.8 are dim.
local function DimTicks(row, part)
	local list = row.ticks
	if not (list and ns.Finite(part)) then
		return
	end
	local n = #list + 1
	for k, mark in ipairs(list) do
		mark:SetAlpha(k / n > part and 0.25 or 1)
	end
end

-- The tick marks of a channel on a bar that has them, at even steps of its width, while Channel ticks on the player bar is on (CastTicks.lua), the
-- ones the channel has passed dimmed.
local function PaintTicks(row, look, state, w, part)
	local list = row.ticks
	if not list then
		return
	end
	local on = look.enabled and G("castbars.ticks") == true and state == "channel"
	local n = #list + 1
	for k, mark in ipairs(list) do
		if on then
			mark:ClearAllPoints()
			mark:SetPoint("TOP", row.bar, "TOPLEFT", w * k / n, 0)
			mark:SetPoint("BOTTOM", row.bar, "BOTTOMLEFT", w * k / n, 0)
			mark:SetWidth(ns.Pixels(row.bar, 1))
		end
		mark:SetShown(on)
	end
	if on then
		DimTicks(row, part)
	end
end

-- The latency zone of the player bar: at the right end of a cast, at the left end of a channel, where it drains to, as Marks of Bars.lua has it;
-- shown with Flat fill and Latency zone on, and not while the cast is interrupted.
local function PlaceLatency(row, look, state, w)
	local latency = row.latency
	if not latency then
		return
	end
	local side = state == "channel" and "LEFT" or "RIGHT"
	latency:ClearAllPoints()
	latency:SetPoint("TOP" .. side, row.bar, "TOP" .. side, 0, 0)
	latency:SetPoint("BOTTOM" .. side, row.bar, "BOTTOM" .. side, 0, 0)
	latency:SetWidth(Max(w * 0.05, 0.01))
	latency:SetShown(look.flat and G("castbars.latency") == true and state ~= "interrupted")
end

-- The time of a bar: the row of Cast time on your bars for the player's and the pet's, Cast time on target and focus bars for the others, and none
-- while the cast is interrupted, as CastTime.lua empties it when the cast ends.
local function ShowTime(row, look, opt, state)
	if row.time then
		local timeRow = (opt == "player" or opt == "pet") and "castbars.playerTime" or "castbars.ownTime"
		row.time:SetShown(look.enabled and G(timeRow) == true and state ~= "interrupted")
	end
end

-- Paints one bar of a place (opt) in a state at `part` of its width, w by h. kick: an enemy cast the player's interrupt is ready for.
local function PaintCastBar(row, look, opt, state, part, w, h, name, kick)
	local inst, spec, bar = row.inst, row.spec, row.bar
	local enabled, flat = look.enabled, look.flat
	local on = enabled and G("castbars." .. opt) == true
	local sizeOn = enabled and G("castbars." .. opt .. "Size") == true
	bar:SetSize(w, h)
	ns.SetOutline(row.outline, on, G("castbars.backdrop"))
	ShowArt(row.art, not on)
	row.plate:SetShown(not (on and not G("castbars.textPlate")))
	GameTexture(inst, row.plate, GAME_PLATE, { 0.3, 0.3, 0.3, 0.7 })
	local r, g, b = CastFill(row, look, opt, state, part, w, kick)
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
	row.spark:SetShown(not (enabled and not G("castbars.spark")))
	GameTexture(inst, row.spark, GAME_PIP, { 0.9, 0.9, 0.9, 0.9 })
	PlaceLatency(row, look, state, w)
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
		row.icon:SetShown(flat and G("castbars.playerIcon") == true and state ~= "interrupted")
	end
	PaintTicks(row, look, state, w, part)
	-- The spell name.
	if row.text then
		local mode = "top10"
		if spec.small then
			mode = "top8"
		elseif opt == "player" and sizeOn then
			mode = G("castbars.playerText") == "inside" and "inside" or "below"
		end
		PlaceCastText(row.text, bar, mode)
		row.text:SetText(CastName(row, look, name))
		row.text:SetJustifyH(look.justify)
		row.text:SetShown(not look.hideName)
		Look(row.text, look.percent, look.r, look.g, look.b, look.outline)
	end
	-- The time: Cast time on your bars for the player's and the pet's, Cast time on target and focus bars for the small ones, in the spell name's
	-- size and outline (CastTime.lua copies the font of the bar's spell name).
	if row.time then
		ShowTime(row, look, opt, state)
		Look(row.time, look.percent, nil, nil, nil, look.outline)
	end
end

function castDrawing.build(stage)
	Instance(castMade, stage, castDrawing, BuildCast)
end

function castDrawing.draw(stage)
	local inst = Instance(castMade, stage, castDrawing, BuildCast)
	local look = CastLook(false)
	local sizes, widest = {}, 0
	for index, row in ipairs(inst.rows) do
		local w, h = CastSize(look, row.spec.opt, row.spec.game)
		sizes[index] = { w, h }
		widest = Max(widest, w)
	end
	local y = 10
	local labelX = CAST_LEFT + widest + CAST_LABEL_GAP
	for index, row in ipairs(inst.rows) do
		local spec = row.spec
		local h = sizes[index][2]
		Place(row.bar, "TOPLEFT", inst.root, "TOPLEFT", CAST_LEFT, -y)
		PaintCastBar(row, look, spec.opt, spec.state, spec.part, sizes[index][1], h)
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

-- The painters of the drawings, for test mode's stand-ins (TestHud.lua): one cast bar or one swing timer on a frame of the caller's, painted from the
-- rows as the setup drawings paint theirs, at a share of its run (`part`, 0 to 1) and in a state (cast, channel, interrupted or shield).
local DC = {}
ns.DrawCasts = DC

-- A cast bar on `parent`. spec: opt (player, pet, target, focus or boss), small (the small bars), shield (it may show one), time (it has a time text),
-- name (the spell name). The caller anchors row.bar.
function DC.Cast(parent, spec)
	return NewCastBar({ grey = {}, outlines = {} }, parent, spec)
end

-- Paints a bar of `opt` in `state` at `part`, w by h (the size the rows give when nil), with the spell name `name` (else its own) and kick for an
-- enemy cast the player's interrupt is ready for. Returns its width and height.
function DC.PaintCast(row, opt, state, part, w, h, name, kick)
	local look = CastLook(opt == "boss")
	if not (ns.Finite(w) and ns.Finite(h)) then
		w, h = CastSize(look, opt, CAST_GAME[opt] or CAST_GAME.target)
	end
	row.look, row.opt, row.w, row.kick, row.state = look, opt, w, kick, state
	PaintCastBar(row, look, opt, state, part, w, h, name, kick)
	return w, h
end

-- The moving parts of a painted bar: its fill and spark at `part`, its state's colour, the spell name of a new state and the seconds left.
function DC.CastProgress(row, state, part, left, name)
	if not row.look then
		return
	end
	CastFill(row, row.look, row.opt, state, part, row.w, row.kick)
	if row.text and (state ~= row.state or name) then
		row.text:SetText(CastName(row, row.look, name))
	end
	if state ~= row.state then
		-- A new state: the ticks, the side of the latency zone and whether the time shows, as PaintCastBar sets them.
		PaintTicks(row, row.look, state, row.w, part)
		PlaceLatency(row, row.look, state, row.w)
		ShowTime(row, row.look, row.opt, state)
	elseif state == "channel" then
		DimTicks(row, part)
	end
	row.state = state
	if row.time and ns.Finite(left) then
		row.time:SetText(("%.1f"):format(math.max(0, left)))
	end
end

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
	p["resource.healthColour"], p["resource.healthClass"] = health.fill, health.fill
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
	local classed = false
	if enabled and G("resource.healthClass") then
		local cr, cg, cb = ns.ClassColour()
		if cr then
			hr, hg, hb, healthGrey, classed = cr, cg, cb, false, true
		end
	end
	if enabled and G("resource.healthOwn") and not classed then
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
-- The game's range colours (Blizzard_SwingTimer.lua:440-447) and its atlases (Blizzard_SwingTimer.xml:12-56, 62-100).
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
-- Fixed samples: how far each timer has run at the start, and how long a swing lasts in seconds. The first main hand timer has a next melee
-- ability queued over the second half of each swing (QUEUED_FROM of it), which lands with the swing.
local QUEUED_FROM = 0.5
local SWING_ROWS = {
	{ hand = "main", note = "In range", part = 0.64, period = 2.6, queued = true },
	{ hand = "off", note = "In range", part = 0.4, period = 2.6 },
	{ hand = "ranged", note = "In range", part = 0.8, period = 3.2 },
	{ hand = "main", note = "Out of range", part = 0.55, period = 2.6, out = true },
	{ hand = "off", note = "Out of combat", part = 0, period = 2.6, idle = true },
}

local swingMade = setmetatable({}, { __mode = "k" })
local swingDrawing = {}

-- One timer of `spec.hand` on `parent`: its frame with the game's art, the bar inside it with the fill, the Auto Shot window of a ranged one, the
-- shadow of the name, the pip, the two outlines and the name and time texts. inst holds the grey parts and the outlines of its drawing.
local function NewSwingTimer(inst, parent, spec)
	local row = { spec = spec, inst = inst }
	row.timer = NewFrame(parent)
	row.timer:SetSize(SWING_FRAME_W, SWING_FRAME_H)
	row.art = NewArt(inst, row.timer, SWING_ART)
	row.bar = NewFrame(row.timer)
	row.bar:SetPoint("TOPLEFT", row.timer, "TOPLEFT", 5, -4)
	row.bar:SetPoint("BOTTOMRIGHT", row.timer, "BOTTOMRIGHT", -5, 4)
	row.fill = NewTexture(row.bar, "ARTWORK", 0)
	-- The Auto Shot window on the ranged timer: the last half second of its swing, over the fill (Bars.lua, ApplyAutoShot).
	if spec.hand == "ranged" then
		row.band = NewTexture(row.bar, "ARTWORK", 7)
	end
	-- Queued ability colour over the fill of a main hand timer with spec.queued (Bars.lua, Q).
	if spec.queued then
		row.queued = NewTexture(row.bar, "ARTWORK", 6)
		row.queued:SetPoint("TOPLEFT", row.fill, "TOPLEFT", 0, 0)
		row.queued:SetPoint("BOTTOMRIGHT", row.fill, "BOTTOMRIGHT", 0, 0)
		row.queued:Hide()
	end
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
	return row
end

local function BuildSwing(stage)
	local inst = { parts = {}, outlines = {}, rows = {}, clock = 0, looks = {}, grey = {} }
	inst.root = NewFrame(stage)
	inst.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
	for index, spec in ipairs(SWING_ROWS) do
		local row = NewSwingTimer(inst, inst.root, spec)
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
	p["swing.autoShot"] = ranged.band
	p["swing.autoShotColour"] = ranged.band
	p["swing.queued"], p["swing.queuedColour"] = main.queued, main.queued
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

-- The parts of a timer that move: the fill at `run` of the bar, the spark at its end and the seconds left.
local function SwingFill(row, look, run, left)
	local spec, colour = row.spec, look.colour[row.spec.hand]
	FillBar(row.fill, row.bar, look.barW or SWING_BAR_W, run, look.reverse, look.file, colour[1], colour[2], colour[3], look.atlas[spec.hand])
	-- The pip sits on the fill's end: its side on the fill's side (Bars.lua:507-509).
	local side = look.reverse and "LEFT" or "RIGHT"
	row.pip:ClearAllPoints()
	row.pip:SetPoint(side, row.fill, side, 0, 0)
	row.pip:SetShown(not spec.idle and look.spark)
	if row.time then
		row.time:SetText(("%.1f"):format(left))
	end
	if row.queued then
		row.queued:SetShown(look.queued and not spec.idle and run >= QUEUED_FROM)
	end
end

local function PaintSwing(inst)
	local look = inst.looks
	if not look.ready then
		return
	end
	for _, row in ipairs(inst.rows) do
		SwingFill(row, look, SwingProgress(row.spec, inst.clock))
	end
end

-- What the rows of the page say for every timer, read once for a paint. frameW: the width of a timer (the rows' when nil).
local function SwingLook(frameW)
	local enabled = G("swing.enabled") == true
	local flat = enabled and G("swing.flat") == true
	local look = { ready = true, enabled = enabled, flat = flat, whole = enabled and G("swing.outline") == "frame",
		idleHide = enabled and G("swing.idle") ~= "show" }
	look.file = flat and ns.BarTexture(G("swing.texture")) or nil
	if not flat then
		look.file = ns.BarFile("game")
	end
	local colour, cr, cg, cb = {}, nil, nil, nil
	if flat and G("swing.classColour") then
		cr, cg, cb = ClassRGB()
	end
	for _, hand in ipairs({ "main", "off", "ranged" }) do
		if not flat then
			colour[hand] = GREY
		elseif cr then
			colour[hand] = { cr, cg, cb }
		else
			local r, g, b = ns.Colour("swing." .. hand .. "Colour")
			colour[hand] = { r, g, b }
		end
	end
	local atlas = {}
	if not flat then
		for hand, name in pairs(SWING_FILL_ATLAS) do
			atlas[hand] = AtlasExists(name) and name or nil
		end
	end
	look.colour, look.atlas = colour, atlas
	look.reverse = enabled and G("swing.reverse") == true
	look.queued = enabled and G("swing.queued") == true
	look.spark = not (flat and not G("swing.spark"))
	look.percent = enabled and G("swing.textSize") or 100
	look.outline = enabled and G("swing.textOutline") or nil
	look.hideName = enabled and not G("swing.name")
	look.hideTime = enabled and not G("swing.time")
	look.own = enabled and G("swing.textOwn")
	look.rangeAlpha = enabled and G("swing.rangeAlpha") / 100 or GAME_RANGE_ALPHA
	look.frameW = frameW or (enabled and G("swing.width") == "resource" and DISPLAY_WIDTH or SWING_FRAME_W)
	look.barW = look.frameW - (SWING_FRAME_W - SWING_BAR_W)
	return look
end

-- Paints the parts of one timer that the rows set: its size, borders, art, Auto Shot window, shadow and text looks.
local function PaintSwingTimer(row, look)
	local inst, spec = row.inst, row.spec
	row.timer:SetSize(look.frameW, SWING_FRAME_H)
	local on = look.enabled and G("swing." .. spec.hand) == true
	local idle = look.idleHide and spec.idle
	-- The border: around the bar or around the whole timer; the game's own border and background go when it is on.
	ns.SetOutline(row.barOutline, on and not look.whole, G("swing.backdrop"))
	ns.SetOutline(row.wholeOutline, on and look.whole and not idle, G("swing.backdrop"))
	ShowArt(row.art, not on)
	inst.grey[row.fill] = (not look.flat and not look.atlas[spec.hand]) or nil
	GameTexture(inst, row.pip, SWING_PIP, { 0.9, 0.9, 0.9, 0.95 })
	GameTexture(inst, row.shadow, SWING_SHADOW_ATLAS, { 0, 0, 0, 0.45 })
	row.bar:SetShown(not idle)
	row.bar:SetAlpha(spec.out and look.rangeAlpha or 1)
	if row.band then
		local shown = look.enabled and G("swing.autoShot") == true and not idle
		if shown then
			local br, bg, bb = ns.Colour("swing.autoShotColour")
			row.band:SetColorTexture(br, bg, bb, 0.5)
			local side = look.reverse and "LEFT" or "RIGHT"
			row.band:ClearAllPoints()
			row.band:SetPoint("TOP" .. side, row.bar, "TOP" .. side, 0, 0)
			row.band:SetPoint("BOTTOM" .. side, row.bar, "BOTTOM" .. side, 0, 0)
			row.band:SetWidth(look.barW * math.min(1, 0.5 / spec.period))
		end
		row.band:SetShown(shown)
	end
	if row.queued and look.queued then
		-- The swing texture, else the Flat UI page's, else white, in Queued ability colour.
		local file = ns.BarTexture(G("swing.texture"))
		if file then
			row.queued:SetTexture(file)
		else
			row.queued:SetColorTexture(1, 1, 1, 1)
		end
		row.queued:SetVertexColor(ns.Colour("swing.queuedColour"))
	end
	row.shadow:SetShown(not (look.flat and not G("swing.textShadow")))
	local r, g, b = GAME_IN[1], GAME_IN[2], GAME_IN[3]
	if spec.out then
		r, g, b = GAME_OUT[1], GAME_OUT[2], GAME_OUT[3]
	end
	if look.own then
		r, g, b = ns.Colour(spec.out and "swing.rangeTextColour" or "swing.textColour")
	end
	if row.type then
		row.type:SetShown(not look.hideName)
		Look(row.type, look.percent, r, g, b, look.outline)
	end
	if row.time then
		row.time:SetShown(not look.hideTime)
		Look(row.time, look.percent, r, g, b, look.outline)
	end
end

function swingDrawing.build(stage)
	Instance(swingMade, stage, swingDrawing, BuildSwing)
end

function swingDrawing.draw(stage)
	local inst = Instance(swingMade, stage, swingDrawing, BuildSwing)
	local look = SwingLook(nil)
	inst.looks, inst.barW = look, look.barW
	local y = SWING_TOP
	for _, row in ipairs(inst.rows) do
		Place(row.timer, "TOPLEFT", inst.root, "TOPLEFT", SWING_LEFT, -y)
		PaintSwingTimer(row, look)
		if row.note then
			Place(row.note, "LEFT", inst.root, "TOPLEFT", SWING_LEFT + look.frameW + 18, -(y + SWING_FRAME_H / 2))
		end
		y = y + SWING_FRAME_H + SWING_GAP
	end
	inst.paint = PaintSwing
	PaintSwing(inst)
	inst.root:SetSize(SWING_LEFT + look.frameW + 140, y + SWING_TOP)
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

-- A swing timer of `hand` (main, off or ranged) on `parent`, for test mode. period: the seconds of its swing. The caller anchors row.timer.
function DC.Swing(parent, hand, period)
	return NewSwingTimer({ grey = {}, outlines = {} }, parent, { hand = hand, part = 0, period = period or 2.6 })
end

-- Paints a timer from the rows, w wide (the rows' width when nil), and gives its width and height.
function DC.PaintSwing(row, w)
	local look = SwingLook(ns.Finite(w) and w > 0 and w or nil)
	row.look = look
	PaintSwingTimer(row, look)
	SwingFill(row, look, 0, row.spec.period)
	return look.frameW, SWING_FRAME_H
end

-- The moving parts of a painted timer: its fill at `run` of its swing and the seconds left.
function DC.SwingProgress(row, run, left)
	if row.look then
		SwingFill(row, row.look, run, left)
	end
end
