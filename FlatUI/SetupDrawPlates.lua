local _, ns = ...

-- The nameplate drawings of Flat UI setup: mock-nameplate, mock-nameplate-cast, mock-nameplate-auras, mock-nameplate-marks, mock-nameplate-threat,
-- mock-nameplate-stack and mock-nameplate-walk, the cards of the nameplate stop of setup's walk round the screen, whose draw returns the size of a
-- canvas of its own for the card to fit.
-- A drawing is { build(stage), draw(stage), parts = { [path] = region } }. build makes the frames of the drawing once for a stage, all marked ns.Own, so no
-- module restyles them. draw reads the settings through ns.Get only (the caller runs it inside ns.Viewing, so it draws the draft) and paints every part again.
-- parts maps a saved path to the region that setting changes, for the bracket that follows the row under the mouse; parts.of(stage) gives the parts of one
-- stage, since a drawing is built once for each stage it is shown on.
-- If stage.view is a table, the outlines follow it (ns.SetOutlineView) when the client of this build has that function.
-- What a plate is made of is the game's own layout for the nameplate style and size chosen: the sizes are Camelot's
-- (Blizzard_NamePlates/Camelot/Blizzard_NamePlateConstants.lua:33-60, 62-68), the anchors those of NamePlateUnitFrameMixin:UpdateAnchors
-- (Blizzard_NamePlates/Blizzard_NamePlateUnitFrame.lua:678-890) and of the cast bar (Blizzard_NamePlateCastingBar.lua:26-130). What each row changes is what
-- Nameplates.lua, PlateText.lua, PlateColours.lua, HealthColour.lua, PlateQuest.lua (the quest mark and its kill count of a sample with quest),
-- PlateOverpower.lua (the Overpower icon of a sample with overpower, a hunter's Mongoose Bite, moved by its offsets, whose swipe drains over its 5
-- seconds and starts again) and PlateCombo.lua (the row of combo points of a sample with combo, under the cast bar's room, in a rogue's or a druid's
-- drawing) do to a plate with the same row. The numbers are fixed samples: the game withholds the health, the cast times and the aura times of a
-- unit (UnitDocumentation.lua:1526-1529).
-- A sample's threat (threatGood, threatTransition or threatBad) colours its health bar as PlateColours.lua orders it and, as PlateThreatLook.lua,
-- PlateText.lua and PlateThreatText.lua draw it (P.Threat), gives it the threat ring at Threat ring thickness (flashing as it turns to threatBad), a
-- sample threat value (under the combo points at Below), the threat colour on its name, health text, border and background as their rows ask, the
-- name of the enemy's target and the fade of an enemy held for you or changing hands. Setup's step of nameplate colours and threat draws
-- mock-nameplate-threat: an enemy, an enemy player, the mouseover and low health, and with Threat on nameplates four samples: threat you want
-- (faded), changing hands, threat you do not want (its ring flashes as the drawing opens and as Flash the ring when threat goes wrong turns on) and
-- your target changing hands, which never fades and carries the name of the enemy's target with Only on your target.
-- Test mode's sample plate (TestHud.lua) is P.NewPlate and P.Plate on a frame of its own, which takes the threat states in turn; P.CastProgress,
-- P.Health, P.Combo and P.Threat change only its fills, time, ring, colours, texts, squares and alpha. A stage whose state has still (test mode's,
-- true while Moving is off) pauses the sample's Overpower swipe with it (P.SwipeStill), and a sample with questHave counts that many of 8 kills,
-- pops its count as it goes up, turns it green at 8/8 and fades the mark and its count once that pop settles, as PlateQuest.lua does (P.QuestFade),
-- fading them back in as the count starts again. On that stage the sample moves as a live plate does: its ring eases in and out
-- (ns.PlateRingEase), it eases to each round's opacity over P.EASE_SECONDS (P.Alpha), its newest combo point pops, and its Overpower icon pops in as
-- each round after the first starts and fades over the round's last P.OP_FADE seconds, on its own round clock whatever Time left on the Overpower
-- icon says (P.OverpowerClock); all of it holds still with Moving off, and setup's drawings snap.
-- A threat value at Above stands over the sample's auras, and an Above quest mark and the Overpower icon over it (the mark over the icon too).

local KEY = "nameplates"
local P = {}
ns.SetupDrawings = ns.SetupDrawings or {}

-- Plate sizes at size 2 (the game's Medium), by nameplate size 1 to 5: horizontal and vertical scale (Camelot constants :62-68).
P.SCALES = { { 0.75, 0.8 }, { 1, 1 }, { 1.25, 1.25 }, { 1.4, 1.4 }, { 1.6, 1.6 } }
-- Per nameplate style: the health bar height and the cast bar height at size 2, whether the name is inside the health bar and whether
-- the spell name is inside the cast bar (Blizzard_NamePlates.lua:354-380, 452-500).
P.STYLES = {
	thin = { health = 13, cast = 6, inside = false, spellInside = false },
	modern = { health = 20, cast = 6, inside = true, spellInside = false },
	block = { health = 20, cast = 16, inside = true, spellInside = true },
	castfocus = { health = 13, cast = 16, inside = false, spellInside = true },
}
-- Plate width, the gap at each side of it, the font heights, the spell icon, the level box width and the gap before it, the aura icon (Camelot constants).
-- The game's level box hangs from the health bar 5 past its end, 3 above it and 2 below it, and the game keeps no room for it in the row
-- (Camelot/Blizzard_NamePlateLevelFrame.xml:5-8, Blizzard_NamePlateUnitFrame.lua:683-708).
P.WIDTH, P.INSET, P.FONT, P.CAST_FONT, P.LEVEL_FONT = 190, 12, 14, 10, 10
P.ICON, P.LEVEL_W, P.LEVEL_GAP, P.LEVEL_ABOVE, P.LEVEL_BELOW, P.AURA = 10, 28, 5, 3, 2, 25
-- The game's icon of an elite, a rare and a rare elite, 20 by 20 at the left end of the bar where the raid marker would be, which an enemy plate
-- shows since 70707 unless the game's Rarity icon option is off (Blizzard_NamePlateClassificationFrame.lua:68-75, 117-127; Blizzard_NamePlates.xml:196-199).
P.RARITY = { elite = "nameplates-icon-elite-gold", boss = "nameplates-icon-elite-gold", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
	rareelite = "nameplates-icon-elite-silver" }
P.RARITY_SIZE, P.RARITY_INDEX = 20, 3
-- The quest mark of PlateQuest.lua: its atlas, else its file, and the units between it and what it stands beside; its sample kill count, the count's
-- size as a share of the mark's, and the units between the two.
P.QUEST_ATLAS, P.QUEST_FILE, P.QUEST_GAP = "QuestNormal", "Interface\\GossipFrame\\AvailableQuestIcon", 2
P.QUEST_COUNT, P.QUEST_COUNT_SIZE, P.QUEST_COUNT_GAP = "3/8", 0.8, 1
-- The pop of a kill count that goes up, as PlateQuest.lua's: from P.QUEST_POP of its size back to whole over P.QUEST_POP_SECONDS, white until it ends.
P.QUEST_POP, P.QUEST_POP_SECONDS = 1.6, 0.3
-- The count's colour once the objective is done, and the seconds the mark and its count fade in as they come and out once done (after the pop), as
-- PlateQuest.lua's K.GREEN, K.FADE_IN and K.FADE_OUT.
P.QUEST_GREEN, P.QUEST_FADE_IN, P.QUEST_FADE_OUT = { 0.3, 0.9, 0.35 }, 0.15, 0.3
-- The threat of test mode's sample plate: the sample value of each state, the units between the value and what it sits beside (PlateThreatText.lua's
-- GAP), and the ring's thickness when Threat ring thickness cannot be read and its gap past the border in pixels (PlateThreatLook.lua's RING_PX and
-- GAP_PX).
P.THREAT_VALUES = { threatGood = "40%", threatTransition = "92%", threatBad = "110%" }
P.THREAT_GAP, P.RING_PX, P.RING_GAP = 4, 2, 2
-- The name of the enemy's target on the sample (PlateThreatText.lua's TargetPart): a warrior who holds it, and you while it attacks you; the share of
-- the threat colour the background takes (PlateThreatLook.lua's BACK_SHARE).
P.THREAT_HOLDER, P.THREAT_HOLDER_CLASS, P.BACK_SHARE = "Gorvak", "WARRIOR", 0.3
-- The Overpower icon of PlateOverpower.lua: the spell of each class that has one (Overpower for a warrior, Mongoose Bite for a hunter), its file
-- when the client gives none and its name, the crop of each edge, the units over the name and its window in seconds; its pop as a round starts (a
-- fade in over P.OP_POP_IN seconds and a shrink from P.OP_POP_FROM of its size over P.OP_POP_SCALE) and its fade over the round's last P.OP_FADE
-- seconds, as PlateOverpower.lua's.
P.OP_SPELLS = { WARRIOR = 7384, HUNTER = 1495 }
P.OP_FILES = { WARRIOR = "Interface\\Icons\\Ability_MeleeDamage", HUNTER = "Interface\\Icons\\Ability_Hunter_SwiftStrike" }
P.OP_NAMES = { WARRIOR = "Overpower", HUNTER = "Mongoose Bite" }
P.OP_CROP, P.OP_GAP, P.OP_WINDOW = 0.08, 2, 5
P.OP_POP_FROM, P.OP_POP_IN, P.OP_POP_SCALE, P.OP_FADE = 1.3, 0.12, 0.15, 0.25
-- Test mode's sample eases to a new opacity over P.EASE_SECONDS, as a live plate's fade (PlateThreatLook.lua's EASE_SECONDS).
P.EASE_SECONDS = 0.2
-- The row of combo points of PlateCombo.lua: the squares, each square and the units between two, the units under the cast bar, the opacity of a
-- square not lit, and the pop of the newest point (from P.COMBO_POP_FROM of its size back to whole over P.COMBO_POP_SECONDS).
P.COMBO_MAX, P.COMBO_SIZE, P.COMBO_SPACE, P.COMBO_DROP, P.COMBO_DIM = 5, 7, 3, 2, 0.25
P.COMBO_POP_FROM, P.COMBO_POP_SECONDS = 1.4, 0.15
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

-- The font string at `base` height times `percent`, in the outline of a row (game draws the game's thin outline) and a colour, in the face of Text font.
function P.Text(text, base, percent, outline, colour, face)
	text:SetFont(face or P.Face(), base, outline == "game" and "OUTLINE" or ns.OUTLINE_FLAGS[outline])
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

-- Short numbers as the game writes them, from a plain sample, or in full with Number style.
function P.Abbreviate(number)
	if ns.Get("unitframes.numberStyle") == "full" and type(BreakUpLargeNumbers) == "function" then
		local ok, text = pcall(BreakUpLargeNumbers, math.floor(number + 0.5))
		if ok and type(text) == "string" then
			return text
		end
	end
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
	o.nameShow, o.nameSize, o.nameOutline, o.nameColour = Row("nameShow", true), Row("nameSize", 100), Row("nameOutline", "game"), Row("nameColour", "game")
	o.nameCustom = Rgb(KEY .. ".nameCustomColour")
	o.nameRow = styled and Get("nameRow") == true
	o.textShow, o.textSize, o.textOutline = Row("healthText", true), Row("healthTextSize", 100), Row("healthTextOutline", "game")
	o.face = styled and Get("textFace") ~= "default" and ns.FontFile(Get("textFace")) or nil
	o.textColour = (styled and Get("healthTextColour") ~= "ffffffff") and Rgb(KEY .. ".healthTextColour") or { 1, 1, 1 }
	o.textFormat = Row("healthFormat", "game")
	o.level, o.levelSize = Row("level", "default"), Row("levelSize", 100)
	-- The square box and its gap apply to Thin border and Text only (Hidden keeps the game's layout), as LevelBox of Nameplates.lua does.
	o.levelSquare = o.level ~= "default" and o.level ~= "hidden" and Get("levelShape") == "square"
	o.levelGap = Get("levelGap")
	o.kindMark = styled and Get("kindMark") == true
	o.targetOn = o.border and Get("target") == true
	o.kindBorder = o.border and Get("kindBorder") == true
	o.hover = styled and Get("hover") == true
	o.cast, o.castBackdrop = styled and Get("cast") == true, styled and Get("castBackdrop") == true
	o.castFlat, o.castTexture = styled and Get("castFlat") == true, Get("castTexture")
	o.castHeight, o.castTextSize, o.castIconSize = Row("castHeight", 100), Row("castTextSize", 100), Row("castIconSize", 100)
	o.castOutline = Row("castTextOutline", "game")
	o.castColour = (styled and Get("castTextColour") ~= "ffffffff") and Rgb(KEY .. ".castTextColour") or { 1, 1, 1 }
	o.spark, o.shield, o.castTime = Row("castSpark", true), Row("castShield", true), styled and Get("castTime") == true
	o.auras = styled and Get("auras") == true
	o.auraCrop, o.timers, o.stacks = Get("auraCrop") / 100, Row("auraTimers", true), Row("auraStacks", true)
	o.auraColour = (styled and Get("auraBorderOwn") == true) and Rgb(KEY .. ".auraBorderColour") or nil
	o.auraAlpha = Row("auraOpacity", 100) / 100
	o.classOn = styled
	o.classBorder = Get("classBorder") == true
	o.classRound = Get("classShape") == "round"
	o.classFit, o.classGap = Get("classFit"), Get("classGap")
	o.marker = Row("raidMarker", true)
	o.markerSize = Row("raidMarkerSize", 22)
	o.markerX, o.markerY = Row("raidMarkerX", 0), Row("raidMarkerY", 0)
	-- No mark while the marks are left to Questie (PlateQuest.lua's ns.PlateQuestYields), as in the game.
	o.quest = Get("enabled") == true and Get("questMark") == true and not (type(ns.PlateQuestYields) == "function" and ns.PlateQuestYields())
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
	-- A sample in a threat state (spec.threat: threatGood, threatTransition or threatBad) takes its colour while Threat on nameplates and Colour
	-- health bars by threat are on, after the target's colour and before a reaction colour, as PlateColours.lua orders them.
	if spec.threat and Get("threat") == true and Get("threatBar") == true then
		return Rgb(KEY .. "." .. spec.threat)
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

-- The pop of the sample kill count (P.QuestMark), a Scale animation of the font string from its middle that gives it its gold back as it ends (its
-- green while its count is done, p.questDone); nil when the client will not make it.
function P.CountPop(p, text)
	local ok, group = pcall(function()
		local modes = Enum and Enum.FontStringScaleAnimationMode
		pcall(text.SetScaleAnimationMode, text, modes and modes.Vertex or 1)
		local made = text:CreateAnimationGroup()
		ns.Own[made] = true
		local grow = made:CreateAnimation("Scale")
		ns.Own[grow] = true
		grow:SetScaleFrom(P.QUEST_POP, P.QUEST_POP)
		grow:SetScaleTo(1, 1)
		grow:SetDuration(P.QUEST_POP_SECONDS)
		grow:SetOrigin("CENTER", 0, 0)
		pcall(grow.SetSmoothing, grow, "OUT")
		local function Done()
			local colour = p.questDone and P.QUEST_GREEN or P.GOLD
			text:SetTextColor(colour[1], colour[2], colour[3], 1)
		end
		made:SetScript("OnFinished", Done)
		made:SetScript("OnStop", Done)
		return made
	end)
	return ok and type(group) == "table" and group or nil
end

-- The pop of a combo point of the sample (P.Combo), a Scale animation of its square from its middle, as PlateCombo.lua's; nil when the client will
-- not make it.
function P.ComboPop(texture)
	local ok, group = pcall(function()
		local made = texture:CreateAnimationGroup()
		ns.Own[made] = true
		local shrink = made:CreateAnimation("Scale")
		ns.Own[shrink] = true
		shrink:SetScaleFrom(P.COMBO_POP_FROM, P.COMBO_POP_FROM)
		shrink:SetScaleTo(1, 1)
		shrink:SetDuration(P.COMBO_POP_SECONDS)
		shrink:SetOrigin("CENTER", 0, 0)
		pcall(shrink.SetSmoothing, shrink, "OUT")
		return made
	end)
	return ok and type(group) == "table" and group or nil
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
	p.rarity = Tex(p.f, "OVERLAY", 3)
	p.quest = Tex(p.f, "OVERLAY", 4)
	p.questCount = Txt(p.f, "OVERLAY")
	p.questPop = P.CountPop(p, p.questCount)
	-- The threat ring round the bar, and the threat value.
	p.ring = Frame(p.f)
	p.ringOutline = P.Outline(S, p.ring, p.ring)
	ns.KeepOutline(p.ringOutline)
	ns.SetOutline(p.ringOutline, false, false)
	p.ringFlash = type(ns.PlateRingFlash) == "function" and ns.PlateRingFlash(p.ring) or nil
	-- The ring's ease in and out, as a live ring's (ns.PlateRingEase); the outline goes once the ease out ends.
	if type(ns.PlateRingEase) == "function" then
		p.ringIn, p.ringOut = ns.PlateRingEase(p.ring, function()
			if not p.ringShown then
				P.RingGone(p)
			end
		end)
	end
	p.tvalue = Txt(p.f, "OVERLAY")
	p.ttarget = Txt(p.f, "OVERLAY")
	p.ttarget:Hide()
	-- The Overpower icon, its border and its swipe, a Cooldown frame of the drawing's own set up as PlateOverpower.lua's MakeSwipe sets its own.
	p.opFrame = Frame(p.f)
	p.op = Tex(p.opFrame, "ARTWORK", 0)
	p.op:SetAllPoints(p.opFrame)
	p.op:SetTexCoord(P.OP_CROP, 1 - P.OP_CROP, P.OP_CROP, 1 - P.OP_CROP)
	p.opOutline = P.Outline(S, p.opFrame, p.opFrame)
	local made, swipe = pcall(CreateFrame, "Cooldown", nil, p.opFrame, "CooldownFrameTemplate")
	if made and type(swipe) == "table" then
		ns.Own[swipe] = true
		swipe:SetAllPoints(p.opFrame)
		pcall(swipe.SetReverse, swipe, true)
		pcall(swipe.SetDrawEdge, swipe, false)
		pcall(swipe.SetDrawBling, swipe, false)
		pcall(swipe.SetHideCountdownNumbers, swipe, true)
		swipe:SetScript("OnCooldownDone", function()
			-- A swipe cleared on purpose (its row off, the icon hidden) ends no round.
			if not p.opSwiping then
				return
			end
			p.opSwiping = nil
			-- A round that ends while the stage holds still starts again once it moves.
			if P.Still(p) then
				p.opDone = true
				return
			end
			P.OverpowerSwipe(p, true)
		end)
		p.opSwipe = swipe
	end
	if type(S.still) == "function" then
		-- A stage that can hold still (test mode's Moving off, S.still) pauses the swipe with it and lets it run on where it stopped, fades the icon
		-- over each round's last P.OP_FADE seconds and starts the next round as one ends while no swipe runs (Time left on the Overpower icon off,
		-- or a client without Cooldown frames); the frame's OnUpdate runs only while the icon shows.
		p.opFrame:SetScript("OnUpdate", function()
			P.SwipeStill(p)
			P.OverpowerFade(p)
			P.OverpowerClock(p)
		end)
		P.OverpowerMotion(p)
		-- Test mode's sample eases to a new opacity (P.Alpha), one step a frame while it is on its way, and its quest mark fades in and out.
		p.alphaStep = function(_, elapsed)
			P.AlphaStep(p, elapsed)
		end
		P.QuestFades(p)
	end
	p.opFrame:Hide()
	-- The row of combo points under the cast bar (PlateCombo.lua's): its squares, each in Flat UI's thin border and with its pop.
	p.combo = Frame(p.f)
	p.comboSquares = {}
	for index = 1, P.COMBO_MAX do
		local square = Tex(p.combo, "ARTWORK", 0)
		square:SetSize(P.COMBO_SIZE, P.COMBO_SIZE)
		square:SetPoint("LEFT", p.combo, "LEFT", (index - 1) * (P.COMBO_SIZE + P.COMBO_SPACE), 0)
		p.comboSquares[index] = { texture = square, outline = P.Outline(S, p.combo, square), pop = P.ComboPop(square) }
	end
	p.combo:Hide()
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
	m.NH = P.FONT * v * o.nameSize / 100
	m.sp = P.SPACING * v
	m.healthY = 0
	if spec.cast or spec.reserve then
		m.CB = style.cast * v * o.castHeight / 100
		m.CI = P.ICON * v * o.castIconSize / 100
		m.CC = m.CB + (style.spellInside and 0 or P.ICON * v)
		m.healthY = m.CC + P.SPACING * v
	end
	-- The level box, from its bottom left corner: the game's past the end of the full row, or the square of Flat UI at the end of a shorter bar.
	m.LW, m.LH = P.LEVEL_W * v, m.HH + P.LEVEL_ABOVE + P.LEVEL_BELOW
	m.HW = m.BW
	m.LX, m.LY = m.BW + P.LEVEL_GAP, m.healthY - P.LEVEL_BELOW
	m.levelOut = true
	if o.levelSquare then
		m.LW, m.LH = m.HH, m.HH
		m.HW = m.BW - (m.LW + o.levelGap)
		m.LX, m.LY = m.BW - m.LW, m.healthY
		m.levelOut = false
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
	elseif format == "curmax" then
		return formats.curmax:format(value, P.Abbreviate(10000))
	elseif format == "both" then
		return formats.both:format(value, share * 100)
	elseif format == "missing" then
		return missing
	end
	return formats.percent:format(share * 100)
end

-- The colour of the name by the rows: the game's, white, the class of a player (the reaction colour of any other unit), by reaction, or the custom one.
function P.NameColour(spec, o)
	local mode = o.nameColour
	if mode == "white" then
		return { 1, 1, 1 }
	elseif mode == "custom" then
		return o.nameCustom
	elseif mode == "class" and spec.player then
		local _, token = P.Player()
		local colour = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[token]
		if type(colour) == "table" then
			return { colour.r, colour.g, colour.b }
		end
	elseif mode == "reaction" or mode == "class" then
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
	-- A sample in a threat state (test mode's) takes the threat colour with Threat colour on the health bar border, after the target, the focus and
	-- the mouseover and before the kind of unit, KIND_PX thick, as Nameplates.lua's Mark orders ns.PlateThreatBorder.
	if r == nil and spec.threat and P.THREAT_VALUES[spec.threat] and o.styled and Get("threat") == true and Get("threatBorder") == true then
		r, g, b = ns.Colour(KEY .. "." .. spec.threat)
		px = P.KIND_PX
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
	P.Put(p, p.lvl, "BOTTOMLEFT", m.LX, m.LY, m.LW, m.LH)
	local style = o.level
	if style == "hidden" then
		ns.SetOutline(p.lvlOutline, false, false)
		p.lvlArt:Hide()
		p.lvlText:SetText("")
		p.mark:Hide()
		return
	end
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
	P.Text(p.lvlText, P.LEVEL_FONT * m.v, o.levelSize, "game", P.LEVEL_COLOUR)
	p.lvlText:SetText(spec.level and tostring(spec.level) or "")
	local look = o.kindMark and spec.kind and ns.KINDS[spec.kind]
	if look and look.mark then
		p.mark:ClearAllPoints()
		p.mark:SetPoint("LEFT", p.lvlText, "RIGHT", 1, 0)
		P.Text(p.mark, P.LEVEL_FONT * m.v, o.levelSize, "game", look.colour)
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
		-- The game's level box hangs past the row, so the icon goes after it while it shows, as PlaceIcon of Nameplates.lua does.
		local edge = (m.levelOut and o.level ~= "hidden") and m.LX + m.LW or m.BW
		P.Put(p, p.iconFrame, "LEFT", edge + x + gap, m.center + y, size, size)
	end
	p.iconFrame:Show()
	ns.SetOutline(p.iconOutline, o.classBorder, o.classBorder)
	ns.SetOutlineRound(p.iconOutline, p.iconArt, o.classRound)
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

-- True when the game shows its icon of an elite or a rare on an enemy plate: its option table asks for it (true since 70707 on this game,
-- Camelot/Blizzard_NamePlateFrameOptionsOverrides.lua) and the Rarity icon bit of the nameplateInfoDisplay CVar is on.
function P.RarityShown()
	local options = NamePlateEnemyFrameOptions
	if type(options) ~= "table" or ns.IsSecret(options) then
		return false
	end
	local wanted = options.showClassificationIndicator
	if ns.IsSecret(wanted) or wanted ~= true then
		return false
	end
	local read = C_CVar and C_CVar.GetCVarBitfield or GetCVarBitfield
	if type(read) ~= "function" then
		return true
	end
	local index = P.RARITY_INDEX
	if type(Enum) == "table" and type(Enum.NamePlateInfoDisplay) == "table" and type(Enum.NamePlateInfoDisplay.RarityIcon) == "number" then
		index = Enum.NamePlateInfoDisplay.RarityIcon
	end
	local ok, on = pcall(read, "nameplateInfoDisplay", index)
	if not ok or ns.IsSecret(on) then
		return true
	end
	return on ~= false
end

-- The game's icon of an elite or a rare at the left end of an enemy plate, where the raid marker hangs (Flat UI's offsets of the marker move
-- it too). A unit with a raid marker shows the marker instead (Blizzard_NamePlateClassificationFrame.lua:95-98).
function P.Rarity(p, spec, o, m)
	local atlas = not spec.friendly and spec.kind and not (spec.marker and o.marker) and P.RARITY[spec.kind]
	if not (atlas and P.RarityShown()) then
		p.rarity:Hide()
		return
	end
	P.Put(p, p.rarity, "RIGHT", o.markerX - m.iconShift, m.center + o.markerY, P.RARITY_SIZE, P.RARITY_SIZE)
	if P.AtlasExists(atlas) then
		P.SetAtlas(p.rarity, atlas)
		p.rarity:SetVertexColor(1, 1, 1, 1)
	else
		local colour = (spec.kind == "rare" or spec.kind == "rareelite") and P.SILVER or P.GOLD
		p.rarity:SetColorTexture(colour[1], colour[2], colour[3], 1)
	end
	p.rarity:Show()
end

-- The left end of what hangs left of the bar: the raid marker or the game's elite or rare icon, else the place of the hidden marker, which still
-- carries Flat UI's offsets of the marker (the game keeps no room for a hidden one, Blizzard_NamePlates.xml:186-199).
function P.LeftEdge(p, o, m)
	local edge = o.markerX - m.iconShift
	if p.marker:IsShown() then
		return edge - o.markerSize
	elseif p.rarity:IsShown() then
		return edge - P.RARITY_SIZE
	end
	return edge
end

-- The quest mark of an enemy a quest needs (spec.quest), where PlateQuest.lua puts it: Left past the threat value on the left, else past the raid
-- marker or the game's elite or rare icon (at the marker's height); Right past the threat value on the right, else past the level box while it shows;
-- Above over the Overpower icon while it shows, else over a threat value above the sample, else over the sample's auras, else over the name (over the
-- bar while the name is inside it); then moved by Quest mark horizontal and vertical offset. With Kill count beside the quest mark a sample count
-- sits beside it, left of it at Left and right of it at Right and Above; test mode's sample counts up with its threat rounds to 8/8 and pops as
-- it goes up (not as it drops back), turns green at 8/8, and its mark and count fade out once that pop settles and fade back in as the next round
-- starts again at 3/8 (P.QuestFade); setup's drawings and a still stage show it whole.
function P.QuestMark(p, spec, o, m)
	if not (spec.quest and o.quest and not spec.friendly and not spec.player) then
		p.quest:Hide()
		p.questCount:Hide()
		P.QuestRest(p)
		p.questHave, p.questDone = nil, nil
		return
	end
	local size, place, gap = Get("questMarkSize"), Get("questMarkPlace"), P.QUEST_GAP
	if P.AtlasExists(P.QUEST_ATLAS) then
		P.SetAtlas(p.quest, P.QUEST_ATLAS)
	else
		p.quest:SetTexture(P.QUEST_FILE)
	end
	local side = p.tvalue:IsShown() and p.tvalueSide or nil
	local point, x, y
	if place == "right" then
		point, x, y = "LEFT", (m.levelOut and o.level ~= "hidden") and m.LX + m.LW or m.BW, m.center
		if side == "right" then
			x, y = p.tvalueR, p.tvalueY
		end
		-- The name of the enemy's target sits after the value on the right, so the mark goes past it.
		if p.ttarget:IsShown() and ns.Finite(p.ttargetR) then
			x, y = p.ttargetR, m.center
		end
		x = x + gap
	elseif place == "above" then
		-- Over the sample's auras while it has them (m.top), as the live mark stands over the debuff row, and over the value or the icon there.
		local top, middle = m.top, m.BW / 2
		if p.opFrame:IsShown() and ns.Finite(p.opT) then
			top, middle = p.opT, ns.Finite(p.opX) and p.opX or middle
		elseif side == "above" and ns.Finite(p.tvalueT) then
			top = p.tvalueT
		end
		point, x, y = "BOTTOM", middle, top + gap
	else
		point, x, y = "RIGHT", P.LeftEdge(p, o, m), m.center + o.markerY
		if side == "left" then
			x, y = p.tvalueL, p.tvalueY
		end
		x = x - gap
	end
	local ox, oy = Get("questMarkX"), Get("questMarkY")
	x, y = x + (ns.Finite(ox) and ox or 0), y + (ns.Finite(oy) and oy or 0)
	P.Put(p, p.quest, point, x, y, size, size)
	p.quest:Show()
	-- Test mode's sample counts up with its threat rounds (spec.questHave); setup's drawings keep the fixed count.
	local have = spec.questHave
	P.QuestFade(p, have)
	local count = p.questCount
	if Get("questMarkCount") ~= true then
		count:Hide()
		p.questHave = have
		return
	end
	local height = math.max(6, size * P.QUEST_COUNT_SIZE)
	P.Text(count, height, 100, "game", p.questDone and P.QUEST_GREEN or P.GOLD, o.face)
	count:SetText(ns.Finite(have) and ("%d/8"):format(have) or P.QUEST_COUNT)
	local width = count:GetStringWidth()
	width = (ns.Finite(width) and width or height * 2) + 1
	local middle = y + size * (0.5 - P.AY[point])
	if point == "RIGHT" then
		P.Put(p, count, "RIGHT", x - size - P.QUEST_COUNT_GAP, middle, width, height)
	else
		P.Put(p, count, "LEFT", x + size * (1 - P.AX[point]) + P.QUEST_COUNT_GAP, middle, width, height)
	end
	count:Show()
	-- A count that went up pops, white until it settles, as a live one does as a kill counts; one that drops back to the start does not.
	local pop = p.questPop
	if pop and ns.Finite(have) and ns.Finite(p.questHave) and have > p.questHave then
		pcall(pop.Stop, pop)
		count:SetTextColor(1, 1, 1, 1)
		pcall(pop.Play, pop)
	end
	p.questHave = have
end

-- The row of combo points of a sample on a rogue's or a druid's target (spec.combo, lit of P.COMBO_MAX), where PlateCombo.lua puts it while Combo
-- points on your target's nameplate is on: centred just under the cast bar (the bottom of the sample, where the game keeps the cast bar's room),
-- lit squares in Combo point colour and the rest in it at P.COMBO_DIM, each in its thin border. p.comboB is the row's bottom, which a threat value
-- at Below hangs under. Test mode's sample pops the newest point as its count goes up; setup's drawings and a still stage do not.
function P.Combo(p, spec, o, m)
	local count = spec.combo
	p.comboB = nil
	if not (ns.Finite(count) and count > 0 and o.styled and not spec.friendly and Get("comboPoints") == true) then
		p.combo:Hide()
		for _, square in ipairs(p.comboSquares) do
			if square.pop then
				pcall(square.pop.Stop, square.pop)
			end
		end
		p.comboHave = nil
		return
	end
	count = math.min(P.COMBO_MAX, math.floor(count))
	local width = P.COMBO_MAX * P.COMBO_SIZE + (P.COMBO_MAX - 1) * P.COMBO_SPACE
	P.Put(p, p.combo, "TOP", m.BW / 2, -P.COMBO_DROP, width, P.COMBO_SIZE)
	p.comboB = -P.COMBO_DROP - P.COMBO_SIZE
	local r, g, b = ns.Colour(KEY .. ".comboColour")
	for index, square in ipairs(p.comboSquares) do
		square.texture:SetColorTexture(r, g, b, 1)
		square.texture:SetAlpha(index <= count and 1 or P.COMBO_DIM)
		ns.SetOutline(square.outline, true, false)
	end
	p.combo:SetFrameLevel(p.f:GetFrameLevel() + 5)
	p.combo:Show()
	local newest = p.comboSquares[count]
	if ns.Finite(p.comboHave) and count > p.comboHave and newest and newest.pop and not P.Snaps(p) then
		pcall(newest.pop.Stop, newest.pop)
		pcall(newest.pop.Play, newest.pop)
	end
	p.comboHave = count
end

-- The fades of test mode's sample quest mark and its count, as PlateQuest.lua's: in over P.QUEST_FADE_IN as the mark comes back, and out over
-- P.QUEST_FADE_OUT once a finished count's pop has settled (a start delay of P.QUEST_POP_SECONDS), keeping its end. Alpha animations of the mark's
-- texture and of the count's font string; none on a client without them, nor on setup's drawings, whose stage has no still.
function P.QuestFades(p)
	local ins, outs = {}, {}
	local ok = pcall(function()
		for _, region in ipairs({ p.quest, p.questCount }) do
			local fadeIn = region:CreateAnimationGroup()
			ns.Own[fadeIn] = true
			local appear = fadeIn:CreateAnimation("Alpha")
			ns.Own[appear] = true
			appear:SetFromAlpha(0)
			appear:SetToAlpha(1)
			appear:SetDuration(P.QUEST_FADE_IN)
			local fadeOut = region:CreateAnimationGroup()
			ns.Own[fadeOut] = true
			local away = fadeOut:CreateAnimation("Alpha")
			ns.Own[away] = true
			away:SetFromAlpha(1)
			away:SetToAlpha(0)
			away:SetDuration(P.QUEST_FADE_OUT)
			away:SetStartDelay(P.QUEST_POP_SECONDS)
			pcall(fadeOut.SetToFinalAlpha, fadeOut, true)
			ins[#ins + 1], outs[#outs + 1] = fadeIn, fadeOut
		end
	end)
	if ok then
		p.questIns, p.questOuts = ins, outs
	end
end

-- The mark and its count whole: their fades stop. A mark that is hidden, and a stage that snaps (setup's drawings, test mode's with Moving off).
function P.QuestRest(p)
	for _, list in ipairs({ p.questIns or {}, p.questOuts or {} }) do
		for _, group in ipairs(list) do
			pcall(group.Stop, group)
		end
	end
	p.quest:SetAlpha(1)
	p.questCount:SetAlpha(1)
	p.questFaded = nil
end

-- The sample's count reaching 8/8 (have, of 8) turns it done (p.questDone, green): the mark and its count fade out once its pop settles; a count that
-- drops back from it fades them in again. On a stage that snaps they stay whole.
function P.QuestFade(p, have)
	local done = ns.Finite(have) and have >= 8
	local was = p.questDone
	p.questDone = done
	if not p.questOuts or P.Snaps(p) then
		P.QuestRest(p)
		return
	end
	if done and not was and ns.Finite(p.questHave) then
		for _, group in ipairs(p.questIns) do
			pcall(group.Stop, group)
		end
		for _, group in ipairs(p.questOuts) do
			pcall(group.Stop, group)
			pcall(group.Play, group)
		end
		p.questFaded = true
	elseif not done and was then
		local faded = p.questFaded
		P.QuestRest(p)
		if faded then
			for _, group in ipairs(p.questIns) do
				pcall(group.Play, group)
			end
		end
	end
end

-- The threat of test mode's sample plate (spec.threat), as a live plate has it: the ring in the threat colour round the bar (and Flat UI's square
-- level box at its end) while Threat glow asks for one (When the enemy needs you: changing hands and threat you do not want; Every threat state:
-- all three), the sample value of the state while Threat value is not Off, at Threat value position and its offsets, in Threat value size of the
-- health text, Threat value outline and the threat colour or Threat value colour, laid out as PlateThreatText.lua's PlaceValue lays it out, and the
-- fade of Fade enemies held for you (Opacity of enemies held for you on threat you want, Opacity of enemies changing hands on threat changing
-- hands), which never fades the target or the focus. A plate with no threat has none of them and keeps its own alpha.
function P.Threat(p, spec, o, m)
	local threat = spec.threat
	local on = threat ~= nil and P.THREAT_VALUES[threat] ~= nil and o.styled and Get("threat") == true
	local glow = on and Get("threatGlow") or "off"
	if glow == "all" or (glow == "needs" and threat ~= "threatGood") then
		-- The general border thickness and RING_GAP more, in screen pixels as the live ring has it (PlateThreatLook.lua's Gap).
		local thickness = ns.Get("general.thickness")
		local d = ns.Pixels(p.ring, (ns.Finite(thickness) and thickness or 1) + P.RING_GAP)
		local right = o.levelSquare and p.lvl or p.bar
		p.ring:ClearAllPoints()
		p.ring:SetPoint("LEFT", p.bar, "LEFT", -d, 0)
		p.ring:SetPoint("TOP", p.bar, "TOP", 0, d)
		p.ring:SetPoint("BOTTOM", p.bar, "BOTTOM", 0, -d)
		p.ring:SetPoint("RIGHT", right, "RIGHT", d, 0)
		local r, g, b = ns.Colour(KEY .. "." .. threat)
		-- Threat ring thickness, as the live ring has it; its edges lie outside the ring's frame, so it grows outward.
		local px = Get("threatRingPx")
		ns.SetOutlineThickness(p.ringOutline, ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or P.RING_PX)
		ns.SetOutlineColour(p.ringOutline, r, g, b)
		ns.SetOutline(p.ringOutline, true, false)
		p.ring:Show()
		local first = not p.ringShown
		p.ringShown = true
		-- A sample that has just turned to threat you do not want flashes its ring, with Flash the ring when threat goes wrong, and so does one
		-- that has it as that row turns on (setup's drawing of the threat rows shows the flash then); a ring that comes otherwise eases in.
		local flash, flashed = p.ringFlash, false
		local flashOn = Get("threatFlash") == true
		if flashOn and p.flashWas == false then
			p.lastThreat = nil
		end
		p.flashWas = flashOn
		if flash and threat == "threatBad" and p.lastThreat ~= "threatBad" and flashOn then
			P.RingStill(p)
			pcall(flash.Stop, flash)
			flashed = pcall(flash.Play, flash)
		end
		if first and not flashed then
			P.RingIn(p)
		end
	else
		if p.ringFlash then
			pcall(p.ringFlash.Stop, p.ringFlash)
		end
		-- A ring that goes eases out, and its outline goes once that ends; a repaint leaves an ease out on its way.
		local was = p.ringShown
		p.ringShown = nil
		if not (was and P.RingOut(p)) and not P.Playing(p.ringOut) then
			P.RingGone(p)
		end
	end
	p.lastThreat = threat
	P.ThreatLooks(p, spec, o, on)
	local text = p.tvalue
	local mode = on and Get("threatValue") or "off"
	p.tvalueSide = nil
	if mode == "off" or mode == nil then
		text:Hide()
	else
		local colour = Get("threatValueColour") == true and Rgb(KEY .. "." .. threat) or Rgb(KEY .. ".threatValueCustom")
		local percent = Get("threatValueSize")
		P.Text(text, P.FONT * m.v, percent, Get("threatValueOutline"), colour, o.face)
		text:SetText(P.THREAT_VALUES[threat])
		local width = text:GetStringWidth()
		local height = P.FONT * m.v * (ns.Finite(percent) and percent or 100) / 100
		width = ns.Finite(width) and width or height * 2
		local place, x, y = Get("threatValuePlace"), Get("threatValueX"), Get("threatValueY")
		x, y = ns.Finite(x) and x or 0, ns.Finite(y) and y or 0
		local gap = P.THREAT_GAP
		if place == "right" then
			local edge = ((m.levelOut and o.level ~= "hidden") and m.LX + m.LW or m.BW) + gap + x
			P.Put(p, text, "LEFT", edge, m.center + y, width, height)
			p.tvalueL, p.tvalueR, p.tvalueY = edge, edge + width, m.center + y
		elseif place == "above" then
			-- Over the sample's auras (m.top), as the live value stands over the debuff row; p.tvalueT is its top, which an Above quest mark and the
			-- Overpower icon stand over.
			P.Put(p, text, "BOTTOM", m.BW / 2 + x, m.top + gap + y, width, height)
			p.tvalueT = m.top + gap + y + height
		elseif place == "below" then
			-- Under the row of combo points while it shows (P.Combo), else under the cast bar, as the live value hangs.
			local under = ns.Finite(p.comboB) and p.comboB or 0
			P.Put(p, text, "TOP", m.BW / 2 + x, under + y - gap, width, height)
		else
			place = "left"
			local edge = P.LeftEdge(p, o, m) - gap + x
			P.Put(p, text, "RIGHT", edge, m.center + y, width, height)
			p.tvalueL, p.tvalueR, p.tvalueY = edge - width, edge, m.center + y
		end
		p.tvalueSide = place
		text:Show()
	end
	P.ThreatTarget(p, spec, o, m, on)
	local alpha = spec.alpha or 1
	if on and Get("threatFade") == true and not (spec.target or spec.focus) then
		local row = threat == "threatGood" and "threatFadeAlpha" or threat == "threatTransition" and "threatFadeChanging" or nil
		local share = row and Get(row)
		if ns.Finite(share) and share < 100 then
			alpha = alpha * math.max(share, 0) / 100
		end
	end
	P.Alpha(p, alpha)
end

-- True while an animation group plays.
function P.Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

-- True while the sample's motion holds still or its stage has none: setup's drawings, and test mode's while Moving is off.
function P.Snaps(p)
	return not p.alphaStep or P.Still(p)
end

-- The ring's ease in and out (ns.PlateRingEase), as a live ring comes and goes; setup's drawings and a still stage show and hide it at once.
-- P.RingOut is true when the ease out plays, and the outline then goes as it ends (P.RingGone).
function P.RingStill(p)
	for _, group in ipairs({ p.ringIn or false, p.ringOut or false }) do
		if group then
			pcall(group.Stop, group)
		end
	end
end

function P.RingIn(p)
	P.RingStill(p)
	if p.ringIn and not P.Snaps(p) then
		pcall(p.ringIn.Play, p.ringIn)
	end
end

function P.RingOut(p)
	if p.ringIn then
		pcall(p.ringIn.Stop, p.ringIn)
	end
	return p.ringOut ~= nil and not P.Snaps(p) and pcall(p.ringOut.Play, p.ringOut)
end

function P.RingGone(p)
	if p.ringOut and not p.ringShown then
		pcall(p.ringOut.Stop, p.ringOut)
	end
	ns.SetOutline(p.ringOutline, false, false)
	p.ring:Hide()
end

-- The sample's opacity: at once on setup's drawings and while test mode's stage holds still, else it eases there over P.EASE_SECONDS on an OnUpdate
-- of the plate's frame that runs only while it is on its way (P.AlphaStep), as a live plate's threat fade does.
function P.Alpha(p, alpha)
	local now = p.f:GetAlpha()
	if P.Snaps(p) or not p.f:IsVisible() or not ns.Finite(now) or math.abs(now - alpha) < 0.001 then
		p.alphaGoal = nil
		if p.alphaStep then
			p.f:SetScript("OnUpdate", nil)
		end
		p.f:SetAlpha(alpha)
		return
	end
	if p.alphaGoal ~= alpha then
		p.alphaGoal = alpha
		p.f:SetScript("OnUpdate", p.alphaStep)
	end
end

function P.AlphaStep(p, elapsed)
	local goal, now = p.alphaGoal, p.f:GetAlpha()
	local step = (ns.Finite(elapsed) and elapsed or 0) / P.EASE_SECONDS
	if goal == nil or not ns.Finite(now) or P.Still(p) or math.abs(goal - now) <= step then
		p.alphaGoal = nil
		p.f:SetScript("OnUpdate", nil)
		if goal ~= nil then
			p.f:SetAlpha(goal)
		end
		return
	end
	p.f:SetAlpha(now + (goal > now and step or -step))
end

-- The rest of the threat look of the sample, from its state while the threat is on (on), else the look without threat: the name in the threat colour
-- with Threat colour on the name and the health text with it with Health text in the name's colour (PlateText.lua's ThreatColour), the border with
-- Threat colour on the health bar border (P.Border), and a dark shade of the threat colour behind the bar with Health bar background in the threat
-- colour while threat colours the bar and Health bar background is on, and not on a target that keeps the target's colour (PlateThreatLook.lua's
-- Back). Only colours and the fill: P.Plate laid them out.
function P.ThreatLooks(p, spec, o, on)
	local r, g, b
	if on then
		r, g, b = ns.Colour(KEY .. "." .. spec.threat)
	end
	-- Through ns.TextStyle at the size P.Text gave them, which keeps the colour it last set.
	local named = on and Get("threatName") == true
	local name = named and { r, g, b } or P.NameColour(spec, o)
	ns.TextStyle(p.name, { percent = o.nameSize, r = name[1], g = name[2], b = name[3] })
	local text = (named and Get("threatHealthText") == true) and { r, g, b } or o.textColour
	ns.TextStyle(p.htext, { percent = o.textSize, r = text[1], g = text[2], b = text[3] })
	P.Border(p, spec, o)
	local back = on and o.backdrop and Get("threatBackground") == true and Get("threatBar") == true
		and not (Get("targetBar") == true and spec.target)
	if back then
		local share = P.BACK_SHARE
		ns.SetOutlineFill(p.outline, r * share, g * share, b * share, ns.OutlineBackdropAlpha(p.outline))
	else
		ns.SetOutlineFill(p.outline, nil, nil, nil, nil)
	end
end

-- The name of the enemy's target right of the sample (PlateThreatText.lua's TargetPart) while Name of the enemy's target is on, and only on your
-- target with Only on your target: a warrior who holds it in the warrior colour, and your own name in your class colour while it attacks you, hidden
-- then with Not when it attacks you. In brackets, in the health text's font at Threat value size, after the value on the right, else after the end
-- of the bar or the level box. p.ttargetR is its right end, which a quest mark on the right goes past.
function P.ThreatTarget(p, spec, o, m, on)
	local text = p.ttarget
	local mine = spec.threat == "threatBad"
	if not (on and Get("aggroTarget") == true and not (Get("aggroTargetOnly") == true and not spec.target)
		and not (mine and Get("aggroTargetNotMe") == true)) then
		text:Hide()
		p.ttargetR = nil
		return
	end
	local name, class = P.THREAT_HOLDER, P.THREAT_HOLDER_CLASS
	if mine then
		name, class = P.Player()
	end
	local colour = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class]
	colour = type(colour) == "table" and { colour.r, colour.g, colour.b } or { 1, 1, 1 }
	local percent = Get("threatValueSize")
	P.Text(text, P.FONT * m.v, percent, "game", colour, o.face)
	text:SetText(("[%s]"):format(name))
	local width = text:GetStringWidth()
	local height = P.FONT * m.v * (ns.Finite(percent) and percent or 100) / 100
	width = ns.Finite(width) and width or height * 4
	local edge = (m.levelOut and o.level ~= "hidden") and m.LX + m.LW or m.BW
	if p.tvalue:IsShown() and p.tvalueSide == "right" and ns.Finite(p.tvalueR) then
		edge = p.tvalueR
	end
	edge = edge + P.THREAT_GAP
	P.Put(p, text, "LEFT", edge, m.center, width, height)
	p.ttargetR = edge + width
	text:Show()
end

-- The class whose spell the Overpower icon shows: the player's when it has one (a hunter's Mongoose Bite), else the warrior's Overpower.
function P.OverpowerClass()
	local _, class = P.Player()
	return P.OP_SPELLS[class] and class or "WARRIOR"
end

-- The icon of that spell (C_Spell.GetSpellTexture), else its file, asked once for each class.
function P.OverpowerIcon()
	local class = P.OverpowerClass()
	P.opIcons = P.opIcons or {}
	if P.opIcons[class] == nil then
		P.opIcons[class] = P.OP_FILES[class]
		local spell = C_Spell
		if type(spell) == "table" and type(spell.GetSpellTexture) == "function" then
			local ok, icon = pcall(spell.GetSpellTexture, P.OP_SPELLS[class])
			if ok and not ns.IsSecret(icon) and (type(icon) == "number" or (type(icon) == "string" and icon ~= "")) then
				P.opIcons[class] = icon
			end
		end
	end
	return P.opIcons[class]
end

-- True while the stage of a plate holds still (test mode's Moving off: S.still), when it has a say.
function P.Still(p)
	local still = p.S and p.S.still
	if type(still) ~= "function" then
		return false
	end
	local ok, answer = pcall(still)
	return ok and answer == true
end

-- The pop of test mode's sample icon as a round starts (an Alpha animation from nothing and a Scale animation from P.OP_POP_FROM to whole, from its
-- middle) and its fade over a round's last P.OP_FADE seconds (an Alpha animation to nothing that keeps its end), as PlateOverpower.lua's MakeMotion
-- makes them; nil on a client without them.
function P.OverpowerMotion(p)
	local frame = p.opFrame
	local ok, pop, fade = pcall(function()
		local popGroup = frame:CreateAnimationGroup()
		ns.Own[popGroup] = true
		local appear = popGroup:CreateAnimation("Alpha")
		ns.Own[appear] = true
		appear:SetFromAlpha(0)
		appear:SetToAlpha(1)
		appear:SetDuration(P.OP_POP_IN)
		local shrink = popGroup:CreateAnimation("Scale")
		ns.Own[shrink] = true
		shrink:SetScaleFrom(P.OP_POP_FROM, P.OP_POP_FROM)
		shrink:SetScaleTo(1, 1)
		shrink:SetDuration(P.OP_POP_SCALE)
		shrink:SetOrigin("CENTER", 0, 0)
		pcall(shrink.SetSmoothing, shrink, "OUT")
		local fadeGroup = frame:CreateAnimationGroup()
		ns.Own[fadeGroup] = true
		local away = fadeGroup:CreateAnimation("Alpha")
		ns.Own[away] = true
		away:SetFromAlpha(1)
		away:SetToAlpha(0)
		away:SetDuration(P.OP_FADE)
		pcall(fadeGroup.SetToFinalAlpha, fadeGroup, true)
		return popGroup, fadeGroup
	end)
	if ok and type(pop) == "table" and type(fade) == "table" then
		p.opPop, p.opFade = pop, fade
	end
end

-- The icon's pop and fade stop, and it shows whole: a round that starts, the swipe going off, the stage holding still.
function P.OverpowerRest(p)
	for _, group in ipairs({ p.opPop or false, p.opFade or false }) do
		if group then
			pcall(group.Stop, group)
		end
	end
	p.opFrame:SetAlpha(1)
end

-- The fade over the round's last P.OP_FADE seconds, once a round, from the Overpower frame's OnUpdate; not while the stage holds still. p.opEnds is
-- when the round's swipe ends, moved on by the time the stage held still, as the swipe's own end is.
function P.OverpowerFade(p)
	local fade, ends = p.opFade, p.opEnds
	if not (fade and ns.Finite(ends)) or p.opFaded or P.Still(p) then
		return
	end
	local now = type(GetTime) == "function" and GetTime() or 0
	if now >= ends - P.OP_FADE then
		p.opFaded = true
		pcall(fade.Play, fade)
	end
end

-- The swipe pauses as the stage holds still and runs on where it stopped as it moves again; a round that ended while still starts the next one.
-- The icon's pop and fade stop as it holds still, and the fade plays again as the round nears its end after; the round's end moves on by the time
-- held, with or without a swipe. From the Overpower frame's OnUpdate, which runs only while the icon shows.
function P.SwipeStill(p)
	local swipe = p.opSwipe
	local still = P.Still(p)
	if still == (p.opStill == true) then
		return
	end
	p.opStill = still
	local now = type(GetTime) == "function" and GetTime() or 0
	if still then
		p.opHeld = now
		if p.opPop or p.opFade then
			P.OverpowerRest(p)
			p.opFaded = nil
		end
		if swipe and swipe.Pause then
			pcall(swipe.Pause, swipe)
		end
		return
	end
	if ns.Finite(p.opEnds) and ns.Finite(p.opHeld) then
		p.opEnds = p.opEnds + (now - p.opHeld)
	end
	p.opHeld = nil
	if swipe and swipe.Resume then
		pcall(swipe.Resume, swipe)
	end
	if p.opDone then
		p.opDone = nil
		P.OverpowerSwipe(p, true)
	end
end

-- Rounds of P.OP_WINDOW seconds: test mode's sample (which has the pop and the fade, p.opPop) runs them on its own clock whatever Time left on the
-- Overpower icon says, as a live icon pops and fades with that row off; setup's drawings run them only for the swipe. While Time left on the
-- Overpower icon is on the swipe drains over each round and starts again with the next; off, it is cleared and only the swipe goes with the row.
-- done: the last round just ended (its swipe, or the clock, P.OverpowerClock), so the next round starts even when the clock still reads the end of
-- the last. While the stage holds still a round that runs is not started again, so a repaint leaves it where it stopped. A hidden icon has no round.
function P.OverpowerSwipe(p, done)
	local swipe = p.opSwipe
	local motion = (p.opPop or p.opFade) and true or false
	local timed = swipe ~= nil and Get("overpowerSwipe") == true
	if not p.opFrame:IsShown() or not (timed or motion) then
		local swiping = p.opSwiping
		p.opRound, p.opSwiping, p.opDone, p.opEnds, p.opFaded = nil, nil, nil, nil, nil
		if swipe and swiping then
			pcall(swipe.Clear, swipe)
		end
		if motion then
			P.OverpowerRest(p)
		end
		return
	end
	if not (p.opRound and P.Still(p)) then
		local now = type(GetTime) == "function" and GetTime() or 0
		local round = now - now % P.OP_WINDOW
		if done and p.opRound and round <= p.opRound then
			round = p.opRound + P.OP_WINDOW
		end
		if p.opRound ~= round then
			-- Test mode's sample pops as each round after the first starts, as a live icon pops as an enemy dodges.
			local later = p.opRound ~= nil
			p.opRound = round
			p.opEnds, p.opFaded, p.opSwiping = round + P.OP_WINDOW, nil, nil
			if motion then
				P.OverpowerRest(p)
				if later and p.opPop and not P.Still(p) then
					pcall(p.opPop.Play, p.opPop)
				end
			end
		end
	end
	-- The swipe follows the row: it starts on the round as the row turns on (or the round starts), and is cleared as the row turns off.
	if timed and not p.opSwiping and p.opRound then
		p.opSwiping = true
		pcall(swipe.SetCooldown, swipe, p.opRound, P.OP_WINDOW)
		if P.Still(p) and swipe.Pause then
			pcall(swipe.Pause, swipe)
		end
	elseif not timed and p.opSwiping then
		p.opSwiping = nil
		pcall(swipe.Clear, swipe)
	end
end

-- The next round once the round's end has passed while no swipe runs to end it (Time left on the Overpower icon off, or no Cooldown frame), from
-- the Overpower frame's OnUpdate; not while the stage holds still.
function P.OverpowerClock(p)
	if p.opSwiping or not ns.Finite(p.opEnds) or P.Still(p) then
		return
	end
	local now = type(GetTime) == "function" and GetTime() or 0
	if now >= p.opEnds then
		P.OverpowerSwipe(p, true)
	end
end

-- The Overpower icon of a sample that dodged a warrior (spec.overpower; Mongoose Bite's for a hunter), where PlateOverpower.lua puts it: centred over
-- the sample's auras, else over the name (over the bar while the name is inside it), moved by Overpower icon horizontal and vertical offset, at
-- Overpower icon size, in Flat UI's thin border, with its swipe.
function P.Overpower(p, spec, o, m)
	if not (spec.overpower and o.styled and Get("overpower") == true) then
		p.opFrame:Hide()
		p.opT, p.opX = nil, nil
		P.OverpowerSwipe(p)
		return
	end
	local size = Get("overpowerSize")
	size = ns.Finite(size) and size > 0 and size or 34
	-- Over the sample's auras while it has them, else over the name (m.top), as the live icon stands over the debuff row, and over a threat value
	-- above the sample. p.opT is its top, which an Above quest mark stands over.
	local top = m.top
	if p.tvalue:IsShown() and p.tvalueSide == "above" and ns.Finite(p.tvalueT) then
		top = p.tvalueT
	end
	-- Moved by Overpower icon horizontal and vertical offset, and an Above quest mark with it.
	local ox, oy = Get("overpowerX"), Get("overpowerY")
	ox, oy = ns.Finite(ox) and ox or 0, ns.Finite(oy) and oy or 0
	P.Put(p, p.opFrame, "BOTTOM", m.BW / 2 + ox, top + P.OP_GAP + oy, size, size)
	p.opT = top + P.OP_GAP + oy + size
	-- An Above quest mark stands over the icon's middle, where the offset put it.
	p.opX = m.BW / 2 + ox
	p.op:SetTexture(P.OverpowerIcon())
	ns.SetOutline(p.opOutline, true, false)
	p.opFrame:SetFrameLevel(p.f:GetFrameLevel() + 10)
	p.opFrame:Show()
	P.OverpowerSwipe(p)
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
	p.castColour = colour
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
	P.Text(p.ctext, P.CAST_FONT * m.v, o.castTextSize, o.castOutline, o.castColour, o.face)
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
	-- The time takes the spell name's face, size and outline, as CastTime.lua copies them.
	P.Text(p.ctime, P.CAST_FONT * m.v, o.castTextSize, o.castOutline, { 1, 1, 1 }, o.face)
	p.ctime:SetText(("%.1f"):format(cast.left))
	p.ctime:SetShown(o.castTime and true or false)
end

-- The moving parts of a painted plate's cast, for test mode (TestHud.lua): the fill and spark at `share` of the bar and the seconds left. Only fills
-- and text: P.Plate laid it out.
function P.CastProgress(p, share, left)
	local m, o = p.m, p.o
	if not (m and o and p.castColour and p.cast:IsShown()) then
		return
	end
	if o.castFlat then
		P.Fill(p.cfill, p.cbar, m.BW, ns.BarTexture(o.castTexture), share, p.castColour)
	else
		P.GameFill(p.cfill, p.cbar, m.BW, share, { 1, 0.7, 0 }, P.ATLAS.cast)
	end
	p.spark:ClearAllPoints()
	p.spark:SetPoint("CENTER", p.cbar, "LEFT", m.BW * share, 0)
	p.ctime:SetText(("%.1f"):format(math.max(0, left)))
end

-- The health bar of a painted plate filled again in the colour its sample asks for now (a new threat state), for test mode. Only the fill.
function P.Health(p, spec)
	local m, o = p.m, p.o
	if not (m and o) then
		return
	end
	local colour = P.BarColour(spec, o)
	local share = spec.health or P.SHARE
	if o.flat then
		P.Fill(p.fill, p.bar, m.HW, ns.BarTexture(o.texture), share, colour)
	else
		P.GameFill(p.fill, p.bar, m.HW, share, colour, P.ATLAS.bar)
	end
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
		P.Text(icon.timer, 12 * m.h, 100, "game", { 1, 1, 1 })
		icon.timer:SetText("12")
		icon.timer:SetShown(o.timers and true or false)
		icon.count:ClearAllPoints()
		icon.count:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", -1, 1)
		P.Text(icon.count, 10 * m.h, 100, "game", { 1, 1, 1 })
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
	-- Test mode's sample keeps the opacity it has, and P.Threat eases it to the new one.
	if not p.alphaStep then
		p.f:SetAlpha(spec.alpha or 1)
	end
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
	P.Text(p.name, P.FONT * m.v, o.nameSize, o.nameOutline, P.NameColour(spec, o), o.face)
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
	P.Text(p.htext, P.FONT * m.v, o.textSize, o.textOutline, o.textColour, o.face)
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
	P.Rarity(p, spec, o, m)
	-- The row of combo points before the threat value, which hangs under it at Below.
	P.Combo(p, spec, o, m)
	P.Threat(p, spec, o, m)
	-- The Overpower icon before the quest mark, which stands over it at Above.
	P.Overpower(p, spec, o, m)
	P.QuestMark(p, spec, o, m)
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

-- Fits a grid of this size to the canvas, or to a canvas of cw by ch: scales it down when it is larger, and says by how much.
function P.Fit(S, width, height, cw, ch)
	local fit = math.min(1, ((cw or P.CANVAS_W) - 2 * P.MARGIN) / math.max(1, width), ((ch or P.CANVAS_H) - 2 * P.MARGIN) / math.max(1, height))
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

-- Lays out and paints the cells of one drawing on a stage. With canvas, a function of the nameplate style and size that gives a width and a height, the
-- drawing keeps a canvas of that size, which S.width and S.height say, and is not fitted to the stage: whoever shows it scales the stage to that size.
function P.Common(stage, cellsOf, arrange, canvas)
	local S = P.Build(stage)
	P.Follow(S)
	local sets = P.Sets()
	local cw, ch
	if canvas then
		cw, ch = canvas(sets)
		S.root:SetScale(1)
	else
		P.Canvas(S)
	end
	local cells = cellsOf(S, sets)
	local columns, layout = P.Place(S, cells, sets)
	local width, height
	if arrange then
		width, height = arrange(S, layout)
	else
		width, height = P.Columns(S, columns)
	end
	P.Fit(S, width, height, cw, ch)
	S.width, S.height = cw, ch
	P.Parts(S)
	P.Repaint(S)
	return S
end

-- The canvas of the cards of setup's nameplate stop: the label column, and room for its two plates at their largest (Taller, with cast times, in any
-- nameplate style) at the nameplate size chosen. Every card of the stop has the same canvas, so the plates of one card are drawn at the scale of the
-- others' and a smaller plate looks smaller.
function P.WalkCanvas(sets)
	local scale = P.SCALES[sets.size] or P.SCALES[2]
	return 84 + 250 * scale[1], 30 + 130 * scale[2]
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
			local _, class = P.Player()
			return {
				{ id = "target", label = "Target", col = 1, spec = Enemy({ target = true }) },
				{ id = "focus", label = "Focus", col = 1, spec = Enemy({ focus = true }) },
				{ id = "marked", label = "Raid marker", col = 1, spec = Enemy({ marker = 8 }) },
				{ id = "player", label = "Enemy player", col = 1, spec = Enemy({ name = names.player, player = true, leftEnd = true }) },
				{ id = "quest", label = "Quest enemy", col = 1, spec = Enemy({ name = "Kobold Vermin", level = 3, quest = true }) },
				{ id = "friend", label = "Friendly player", col = 2, spec = { name = names.friend, level = 18, friendly = true, player = true, health = P.SHARE, marker = 4 } },
				{ id = "elite", label = "Elite", col = 2, spec = Enemy({ name = names.elite, level = 20, kind = "elite" }) },
				{ id = "rare", label = "Rare", col = 2, spec = Enemy({ name = "Old Blanchy", level = 20, kind = "rare" }) },
				{ id = "boss", label = "Boss", col = 2, spec = Enemy({ name = "Edwin VanCleef", level = 20, kind = "boss" }) },
				-- A warrior's Overpower, or a hunter's Mongoose Bite, over an enemy that dodged them.
				{ id = "overpower", label = P.OP_NAMES[class] or P.OP_NAMES.WARRIOR, col = 2, show = P.OP_SPELLS[class] ~= nil,
					spec = Enemy({ overpower = true }) },
				-- A rogue's or a druid's combo points under their target, 3 of 5, below the room the game keeps for the cast bar.
				{ id = "combo", label = "Combo points", col = 2, show = class == "ROGUE" or class == "DRUID",
					spec = Enemy({ target = true, combo = 3, reserve = true }) },
			}
		elseif kind == "threat" then
			-- Setup's colours and threat: an enemy, an enemy player, the mouseover and low health as the plate drawing has them, and with Threat on
			-- nameplates the threat rows on a sample of each state, as test mode's sample takes them in turn: threat you want (faded), changing hands
			-- (faded by its own opacity), threat you do not want (with the ring, which flashes as the drawing opens), and your target changing hands,
			-- which never fades, takes Colour the target's health bar and shows the name of the enemy's target with Only on your target too.
			local threat = Get("threat") == true
			return {
				{ id = "enemy", label = "Enemy", col = 1, spec = Enemy() },
				{ id = "player", label = "Enemy player", col = 1, spec = Enemy({ name = names.player, player = true }) },
				{ id = "hover", label = "Mouseover", col = 1, show = Get("hover") == true, spec = Enemy({ hover = true }) },
				{ id = "low", label = "Low health", col = 1, show = Get("lowHealth") == true, spec = Enemy({ health = 0.18 }) },
				{ id = "good", label = "You want", col = 2, show = threat, spec = Enemy({ threat = "threatGood" }) },
				{ id = "changing", label = "Changing hands", col = 2, show = threat, spec = Enemy({ threat = "threatTransition" }) },
				{ id = "bad", label = "You do not want", col = 2, show = threat, spec = Enemy({ threat = "threatBad" }) },
				{ id = "target", label = threat and "Your target" or "Target", col = 2, spec = Enemy({ target = true, threat = "threatTransition" }) },
			}
		elseif kind == "walk" then
			-- Flat UI setup's nameplate stop: an enemy casting with auras on it, and one at low health.
			return {
				{ id = "cast", label = "Casting", col = 1, spec = Enemy({ cast = { name = "Shadow Bolt", share = 0.6, left = 1.2 }, auras = { count = 3 } }) },
				{ id = "low", label = "Low health", col = 1, spec = Enemy({ health = 0.18 }) },
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
	local main = plates.enemy or plates.cast or plates.auras or plates.target or plates.changing
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
	Set({ "textFace", "nameShow", "nameSize", "nameOutline", "nameColour", "nameCustomColour" }, plate.name)
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
	Set({ "classEnemy", "classPosition", "classFit", "classSize", "classGap", "classX", "classY", "classBorder", "classShape" }, player.iconFrame)
	Set({ "classFriendly" }, (plates.friend or plate).iconFrame)
	Set({ "kindBorder", "eliteColour" }, (plates.elite or plate).bar)
	Set({ "rareColour" }, (plates.rare or plate).bar)
	Set({ "bossColour" }, (plates.boss or plate).bar)
	Set({ "raidMarker", "raidMarkerSize", "raidMarkerX", "raidMarkerY" }, (plates.marked or plate).marker)
	Set({ "questMark", "questMarkSize", "questMarkPlace", "questMarkX", "questMarkY" }, (Live("quest") or plate).quest)
	Set({ "questMarkCount" }, (Live("quest") or plate).questCount)
	-- Only a warrior's and a hunter's drawing has the Overpower plate, and a rogue's and a druid's the combo points; for anyone else the rows mark
	-- nothing.
	local overpower = Live("overpower")
	Set({ "overpower", "overpowerSize", "overpowerX", "overpowerY", "overpowerSwipe" }, overpower and overpower.opFrame or nil)
	local combo = Live("combo")
	Set({ "comboPoints", "comboColour" }, combo and combo.combo or nil)
	-- The threat drawing: each threat row on the sample it changes.
	local good, changing, bad = Live("good"), Live("changing"), Live("bad")
	if good and changing and bad then
		local target = Live("target") or changing
		Set({ "threatGood" }, good.bar)
		Set({ "threatTransition" }, changing.bar)
		Set({ "threatBad" }, bad.bar)
		Set({ "threatGlow", "threatFlash", "threatRingPx" }, bad.ring:IsShown() and bad.ring or bad.bar)
		Set({ "threatBar", "threatBorder", "threatBackground" }, bad.bar)
		Set({ "threatName" }, bad.name)
		Set({ "threatHealthText" }, bad.htext)
		Set({ "threatValue", "threatValueColour", "threatValueCustom", "threatValueSize", "threatValuePlace", "threatValueX", "threatValueY",
			"threatValueOutline" }, changing.tvalue:IsShown() and changing.tvalue or changing.bar)
		Set({ "aggroTarget", "aggroTargetOnly" }, target.ttarget:IsShown() and target.ttarget or target.bar)
		Set({ "aggroTargetNotMe" }, bad.ttarget:IsShown() and bad.ttarget or bad.bar)
		Set({ "threatFade", "threatFadeAlpha" }, good.f)
		Set({ "threatFadeChanging" }, changing.f)
	end
	Set({ "overlapH", "overlapV", "selectedScale" }, (Live("target") or plate).f)
	Set({ "minScale", "minAlpha" }, (plates.far or plate).f)
	Set({ "notSelectedAlpha" }, (plates.near or plate).f)
	S.parts = parts
end

-- Makes the table of one drawing from the cells it lays out. A drawing with a canvas of its own (P.Common) returns from draw the width and height of
-- that canvas, which the box that shows it fits (SetupDraw.lua, D.PaintIn); the others return their state.
local function Drawing(kind, arrange, canvas)
	local cellsOf = P.Cells(kind)
	local drawing = { parts = {} }
	function drawing.build(stage)
		return P.Build(stage)
	end
	function drawing.draw(stage)
		local S = P.Common(stage, cellsOf, arrange, canvas)
		drawing.parts = S.parts
		if canvas then
			return S.width, S.height
		end
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
ns.SetupDrawings["mock-nameplate-threat"] = Drawing("threat")
ns.SetupDrawings["mock-nameplate-stack"] = Drawing("stack", P.Stack)
ns.SetupDrawings["mock-nameplate-walk"] = Drawing("walk", nil, P.WalkCanvas)
ns.SetupDrawPlates = P
