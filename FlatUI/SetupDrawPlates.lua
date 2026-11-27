local _, ns = ...

local KEY = "nameplates"
local P = {}
ns.SetupDrawings = ns.SetupDrawings or {}

P.SCALES = { { 0.75, 0.8 }, { 1, 1 }, { 1.25, 1.25 }, { 1.4, 1.4 }, { 1.6, 1.6 } }
P.STYLES = {
	thin = { health = 13, cast = 6, inside = false, spellInside = false },
	modern = { health = 20, cast = 6, inside = true, spellInside = false },
	block = { health = 20, cast = 16, inside = true, spellInside = true },
	castfocus = { health = 13, cast = 16, inside = false, spellInside = true },
}
P.WIDTH, P.INSET, P.FONT, P.CAST_FONT, P.LEVEL_FONT = 190, 12, 14, 10, 10
P.ICON, P.LEVEL_W, P.LEVEL_GAP, P.LEVEL_ABOVE, P.LEVEL_BELOW, P.AURA = 10, 28, 5, 3, 2, 25
P.RARITY = { elite = "nameplates-icon-elite-gold", boss = "nameplates-icon-elite-gold", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
	rareelite = "nameplates-icon-elite-silver" }
P.RARITY_SIZE, P.RARITY_INDEX = 20, 3
P.QUEST_ATLAS, P.QUEST_FILE, P.QUEST_GAP = "QuestNormal", "Interface\\GossipFrame\\AvailableQuestIcon", 2
P.QUEST_COUNT, P.QUEST_COUNT_SIZE, P.QUEST_COUNT_GAP = "3/8", 0.8, 1
P.QUEST_POP, P.QUEST_POP_SECONDS = 1.6, 0.3
P.QUEST_GREEN, P.QUEST_FADE_IN, P.QUEST_FADE_OUT = { 0.3, 0.9, 0.35 }, 0.15, 0.3
P.THREAT_VALUES = { threatGood = "40%", threatTransition = "92%", threatBad = "110%", threatTank = "60%" }
P.THREAT_GAP, P.RING_PX, P.RING_GAP = 4, 2, 2
P.THREAT_HOLDER, P.THREAT_HOLDER_CLASS, P.BACK_SHARE = "Gorvak", "WARRIOR", 0.3
P.OP_SPELLS = { WARRIOR = 7384, HUNTER = 1495, ROGUE = 14251 }
P.OP_FILES = { WARRIOR = "Interface\\Icons\\Ability_MeleeDamage", HUNTER = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
	ROGUE = "Interface\\Icons\\Ability_Warrior_Challange" }
P.OP_NAMES = { WARRIOR = "Overpower", HUNTER = "Mongoose Bite", ROGUE = "Riposte" }
P.OP_TARGET = { HUNTER = true, ROGUE = true }
P.OP_CROP, P.OP_GAP, P.OP_WINDOW = 0.08, 2, 5
P.OP_POP_FROM, P.OP_POP_IN, P.OP_POP_SCALE, P.OP_FADE = 1.3, 0.12, 0.15, 0.25
P.OP_WHITE, P.OP_AMBER, P.OP_RED = { 1, 1, 1 }, { 1, 0.75, 0.2 }, { 1, 0.3, 0.25 }
P.EASE_SECONDS = 0.2
P.COMBO_MAX, P.COMBO_SIZE, P.COMBO_SPACE, P.COMBO_DROP, P.COMBO_DIM = 5, 7, 3, 2, 0.25
P.COMBO_POP_FROM, P.COMBO_POP_SECONDS = 1.4, 0.15
P.COMBO_BREATHE_LOW, P.COMBO_BREATHE_SECONDS = 0.55, 0.9
P.SPACING = 2
P.GAP, P.KIND_PX = 3, 2
P.FLASH_GROW = 2
P.HOSTILE, P.FRIENDLY, P.LEVEL_COLOUR = { 0.77, 0.23, 0.23 }, { 0.24, 0.77, 0.35 }, { 1, 0.82, 0 }
P.SHARE, P.DIM = 0.7, 0.5
P.GOLD, P.SILVER = { 1, 0.82, 0 }, { 0.78, 0.8, 0.84 }
P.ATLAS = { bar = "UI-HUD-CoolDownManager-Bar", level = "ui-hud-nameplates-levelindicator", cast = "ui-castingbar-filling-standard", pip = "ui-castingbar-pip",
	shield = "nameplates-InterruptShield" }
P.RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
P.SPELLS = { 135940, 135964, 136089, 136096, 135987 }
P.AX = { LEFT = 0, TOPLEFT = 0, BOTTOMLEFT = 0, CENTER = 0.5, TOP = 0.5, BOTTOM = 0.5, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
P.AY = { BOTTOM = 0, BOTTOMLEFT = 0, BOTTOMRIGHT = 0, CENTER = 0.5, LEFT = 0.5, RIGHT = 0.5, TOP = 1, TOPLEFT = 1, TOPRIGHT = 1 }
P.CANVAS_W, P.CANVAS_H, P.MARGIN = 658, 204, 10
P.states = setmetatable({}, { __mode = "k" })

local function Get(key)
	return ns.Get(KEY .. "." .. key)
end

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

function P.Text(text, base, percent, outline, colour, face)
	text:SetFont(face or P.Face(), base, outline == "game" and "OUTLINE" or ns.OUTLINE_FLAGS[outline])
	ns.TextStyle(text, { percent = percent, r = colour[1], g = colour[2], b = colour[3] })
end

local function Rgb(path)
	local r, g, b = ns.Colour(path)
	return { r, g, b }
end

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

function P.Reaction(friend)
	if ns.Get("general.reactionOwn") == true then
		return Rgb(friend and "general.reactionFriendly" or "general.reactionHostile")
	end
	return friend and P.FRIENDLY or P.HOSTILE
end

function P.Damage()
	local choice = Get("threatRole")
	if choice == "tank" or choice == "damage" then
		return choice == "damage"
	end
	local threat = ns.PlateThreat
	local ask = type(threat) == "table" and (type(threat.AutoRole) == "function" and threat.AutoRole or threat.Role) or nil
	if type(ask) == "function" then
		local ok, kind = pcall(ask)
		return not (ok and kind == "tank")
	end
	return true
end

P.DAMAGE_ROWS = { threatGood = "threatDamageGood", threatTransition = "threatDamageTransition", threatBad = "threatDamageBad" }
function P.ThreatRow(threat)
	if threat == "threatTank" then
		return "threatTankColour"
	end
	local row = P.DAMAGE_ROWS[threat]
	if row and Get("threatSameColours") == false and P.Damage() then
		return row
	end
	return threat
end

function P.FadeRow(threat)
	if threat == "threatGood" or threat == "threatTank" then
		if Get("threatFadeSame") == false and P.Damage() then
			return "threatFadeDamage"
		end
		return "threatFadeAlpha"
	elseif threat == "threatTransition" then
		return "threatFadeChanging"
	end
	return nil
end

function P.BarColour(spec, o)
	local gameColour = spec.friendly and P.FRIENDLY or P.HOSTILE
	if spec.player and Get(spec.friendly and "classColoursFriendly" or "classColoursEnemy") == true then
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
	if spec.threat and Get("threat") == true and Get("threatBar") == true then
		return Rgb(KEY .. "." .. P.ThreatRow(spec.threat))
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
	p.lowLine = Tex(p.bar, "ARTWORK", 5)
	p.outline = P.Outline(S, p.bar, p.bar)
	p.edges = { Tex(p.bar, "OVERLAY", 5), Tex(p.bar, "OVERLAY", 5), Tex(p.bar, "OVERLAY", 5), Tex(p.bar, "OVERLAY", 5) }
	p.lowFrame = Frame(p.bar)
	p.lowFrame:SetAllPoints(p.bar)
	p.low = P.Outline(S, p.lowFrame, p.lowFrame)
	ns.SetOutline(p.low, true, false)
	p.row = Tex(p.f, "BACKGROUND", -6)
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
	p.ring = Frame(p.f)
	p.ringOutline = P.Outline(S, p.ring, p.ring)
	ns.KeepOutline(p.ringOutline)
	ns.SetOutline(p.ringOutline, false, false)
	p.ringFlash = type(ns.PlateRingFlash) == "function" and ns.PlateRingFlash(p.ring) or nil
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
			if not p.opSwiping then
				return
			end
			p.opSwiping = nil
			if P.Still(p) then
				p.opDone = true
				return
			end
			P.OverpowerSwipe(p, true)
		end)
		p.opSwipe = swipe
	end
	p.opSecsFrame = Frame(p.opFrame)
	p.opSecsFrame:SetAllPoints(p.opFrame)
	p.opSecs = Txt(p.opSecsFrame, "OVERLAY")
	p.opSecs:SetPoint("CENTER", p.opSecsFrame, "CENTER", 0, 0)
	p.opSecs:SetText("")
	if type(S.still) == "function" then
		p.opFrame:SetScript("OnUpdate", function()
			P.SwipeStill(p)
			P.OverpowerFade(p)
			P.OverpowerClock(p)
			P.OverpowerSeconds(p)
		end)
		P.OverpowerMotion(p)
		p.alphaStep = function(_, elapsed)
			P.AlphaStep(p, elapsed)
		end
		P.QuestFades(p)
	end
	p.opFrame:Hide()
	p.combo = Frame(p.f)
	p.comboSquares = {}
	for index = 1, P.COMBO_MAX do
		local square = Tex(p.combo, "ARTWORK", 0)
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

function P.AurasSeen(spec, o)
	local when = Get("aurasWhen")
	if not o.styled or (when ~= "target" and when ~= "focus") then
		return true
	end
	return spec.target == true or (when == "focus" and spec.focus == true)
end

function P.HealthSeen(spec, o)
	if not o.textShow then
		return false
	end
	local when = Get("healthTextWhen")
	if not o.styled or (when ~= "target" and when ~= "focus") then
		return true
	end
	return spec.target == true or (when == "focus" and spec.focus == true)
end

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
	if spec.auras and P.AurasSeen(spec, o) then
		local size = Get("auraScale")
		m.AS = P.AURA * h * (ns.Finite(size) and size > 0 and size / 100 or 1)
		m.auraY = m.top + m.sp
		m.top = m.auraY + m.AS
	end
	return m
end

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
		return share >= 1 and "" or missing
	end
	return formats.percent:format(share * 100)
end

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
	if r == nil and spec.threat and P.THREAT_VALUES[spec.threat] and o.styled and Get("threat") == true and Get("threatBorder") == true then
		r, g, b = ns.Colour(KEY .. "." .. P.ThreatRow(spec.threat))
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

function P.TargetFlash(p, spec, o)
	local mark = o.targetOn and (spec.target and "targetColour" or spec.focus and "focusColour") or nil
	local on = mark ~= nil and Get("targetFlash") == true
	local was = p.tflashWas
	p.tflashWas = on
	if not on then
		if p.tflashFrame then
			if p.tflash then
				pcall(p.tflash.Stop, p.tflash)
			end
			p.tflashFrame:SetAlpha(0)
		end
		return
	end
	if p.tflashFrame == nil then
		p.tflashFrame = Frame(p.bar)
		p.tflashFrame:SetAllPoints(p.bar)
		p.tflashFrame:SetFrameLevel(p.bar:GetFrameLevel() + 8)
		p.tflashFrame:SetAlpha(0)
		p.tflashOutline = P.Outline(p.S, p.tflashFrame, p.tflashFrame)
		ns.KeepOutline(p.tflashOutline)
		ns.SetOutline(p.tflashOutline, true, false)
		p.tflash = type(ns.PlateTargetFlash) == "function" and ns.PlateTargetFlash(p.tflashFrame) or nil
	end
	local px = Get("targetThickness")
	px = ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or 1
	ns.SetOutlineThickness(p.tflashOutline, px + P.FLASH_GROW)
	ns.SetOutlineColour(p.tflashOutline, ns.Colour(KEY .. "." .. mark))
	if was ~= true and p.tflash then
		pcall(p.tflash.Stop, p.tflash)
		pcall(p.tflash.Play, p.tflash)
	end
end

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
		local edge = (m.levelOut and o.level ~= "hidden") and m.LX + m.LW or m.BW
		P.Put(p, p.iconFrame, "LEFT", edge + x + gap, m.center + y, size, size)
	end
	p.iconFrame:Show()
	ns.SetOutline(p.iconOutline, o.classBorder, o.classBorder)
	ns.SetOutlineRound(p.iconOutline, p.iconArt, o.classRound)
end

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

function P.LeftEdge(p, o, m)
	local edge = o.markerX - m.iconShift
	if p.marker:IsShown() then
		return edge - o.markerSize
	elseif p.rarity:IsShown() then
		return edge - P.RARITY_SIZE
	end
	return edge
end

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
		if p.ttarget:IsShown() and ns.Finite(p.ttargetR) then
			x, y = p.ttargetR, m.center
		end
		x = x + gap
	elseif place == "above" then
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
	local pop = p.questPop
	if pop and ns.Finite(have) and ns.Finite(p.questHave) and have > p.questHave then
		pcall(pop.Stop, pop)
		count:SetTextColor(1, 1, 1, 1)
		pcall(pop.Play, pop)
	end
	p.questHave = have
end

function P.ComboSize()
	local size, oy = Get("comboSize"), Get("comboY")
	size = ns.Finite(size) and size >= 1 and math.floor(size + 0.5) or P.COMBO_SIZE
	oy = ns.Finite(oy) and math.floor(oy + 0.5) or 0
	return size, math.max(2, math.floor(size * P.COMBO_SPACE / P.COMBO_SIZE + 0.5)), oy
end

function P.ComboBreathe(p, on)
	if p.comboBreathe == nil and on then
		local ok, group = pcall(function()
			local made = p.combo:CreateAnimationGroup()
			ns.Own[made] = true
			local fade = made:CreateAnimation("Alpha")
			ns.Own[fade] = true
			fade:SetFromAlpha(1)
			fade:SetToAlpha(P.COMBO_BREATHE_LOW)
			fade:SetDuration(P.COMBO_BREATHE_SECONDS)
			pcall(fade.SetSmoothing, fade, "IN_OUT")
			made:SetLooping("BOUNCE")
			return made
		end)
		p.comboBreathe = ok and type(group) == "table" and group or false
	end
	local group = p.comboBreathe
	if not group then
		return
	end
	local okPlaying, playing = pcall(group.IsPlaying, group)
	playing = okPlaying and playing == true
	if on and not playing then
		pcall(group.Play, group)
	elseif not on and playing then
		pcall(group.Stop, group)
		p.combo:SetAlpha(1)
	end
end

function P.Combo(p, spec, o, m)
	local count = spec.combo
	p.comboB = nil
	if not (ns.Finite(count) and count > 0 and o.styled and not spec.friendly and Get("comboPoints") == true) then
		P.ComboBreathe(p, false)
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
	local size, space, oy = P.ComboSize()
	local width = P.COMBO_MAX * size + (P.COMBO_MAX - 1) * space
	P.Put(p, p.combo, "TOP", m.BW / 2, -P.COMBO_DROP + oy, width, size)
	p.comboB = -P.COMBO_DROP + oy - size
	local full = count >= P.COMBO_MAX and Get("comboFull") == true
	local r, g, b = ns.Colour(KEY .. (full and ".comboFullColour" or ".comboColour"))
	for index, square in ipairs(p.comboSquares) do
		square.texture:SetSize(size, size)
		square.texture:ClearAllPoints()
		square.texture:SetPoint("LEFT", p.combo, "LEFT", (index - 1) * (size + space), 0)
		square.texture:SetColorTexture(r, g, b, 1)
		square.texture:SetAlpha(index <= count and 1 or P.COMBO_DIM)
		ns.SetOutline(square.outline, true, false)
	end
	p.combo:SetFrameLevel(p.f:GetFrameLevel() + 5)
	p.combo:Show()
	P.ComboBreathe(p, full and Get("comboBreathe") == true and not P.Still(p))
	local fullWas = p.comboFullWas
	if count >= P.COMBO_MAX then
		p.comboFullWas = Get("comboFull") == true
	end
	if ns.Finite(p.comboHave) and count > p.comboHave and not P.Snaps(p) or (full and fullWas == false) then
		for index, square in ipairs(p.comboSquares) do
			if square.pop and (index == count or (full and index < count)) then
				pcall(square.pop.Stop, square.pop)
				pcall(square.pop.Play, square.pop)
			end
		end
	end
	p.comboHave = count
end

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

function P.Threat(p, spec, o, m)
	local threat = spec.threat
	local on = threat ~= nil and P.THREAT_VALUES[threat] ~= nil and o.styled and Get("threat") == true
	local glow = on and Get("threatGlow") or "off"
	if glow == "all" or (glow == "needs" and (threat == "threatTransition" or threat == "threatBad")) then
		local thickness = ns.Get("general.thickness")
		local d = ns.Pixels(p.ring, (ns.Finite(thickness) and thickness or 1) + P.RING_GAP)
		local right = o.levelSquare and p.lvl or p.bar
		p.ring:ClearAllPoints()
		p.ring:SetPoint("LEFT", p.bar, "LEFT", -d, 0)
		p.ring:SetPoint("TOP", p.bar, "TOP", 0, d)
		p.ring:SetPoint("BOTTOM", p.bar, "BOTTOM", 0, -d)
		p.ring:SetPoint("RIGHT", right, "RIGHT", d, 0)
		local r, g, b = ns.Colour(KEY .. "." .. P.ThreatRow(threat))
		local px = Get("threatRingPx")
		ns.SetOutlineThickness(p.ringOutline, ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or P.RING_PX)
		ns.SetOutlineColour(p.ringOutline, r, g, b)
		ns.SetOutline(p.ringOutline, true, false)
		p.ring:Show()
		local first = not p.ringShown
		p.ringShown = true
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
		local colour = Get("threatValueColour") == true and Rgb(KEY .. "." .. P.ThreatRow(threat)) or Rgb(KEY .. ".threatValueCustom")
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
			P.Put(p, text, "BOTTOM", m.BW / 2 + x, m.top + gap + y, width, height)
			p.tvalueT = m.top + gap + y + height
		elseif place == "below" then
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
		local row = P.FadeRow(threat)
		local share = row and Get(row)
		if ns.Finite(share) and share < 100 then
			alpha = alpha * math.max(share, 0) / 100
		end
	end
	P.Alpha(p, alpha)
	if type(ns.PlateSlipSample) == "function" then
		pcall(ns.PlateSlipSample, p, spec, o, on)
	end
end

function P.Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

function P.Snaps(p)
	return not p.alphaStep or P.Still(p)
end

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

function P.ThreatLooks(p, spec, o, on)
	local r, g, b
	if on then
		r, g, b = ns.Colour(KEY .. "." .. P.ThreatRow(spec.threat))
	end
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

function P.Knows(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or {}
	for _, call in ipairs({ book.IsSpellKnownOrInSpellBook, book.IsSpellKnown, IsSpellKnown }) do
		if type(call) == "function" then
			local ok, known = pcall(call, id)
			if ok and not ns.IsSecret(known) and type(known) == "boolean" then
				return known
			end
		end
	end
	return false
end

function P.OverpowerClass()
	local _, class = P.Player()
	return P.OP_SPELLS[class] and class or "WARRIOR"
end

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

function P.Still(p)
	local still = p.S and p.S.still
	if type(still) ~= "function" then
		return false
	end
	local ok, answer = pcall(still)
	return ok and answer == true
end

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

function P.OverpowerRest(p)
	for _, group in ipairs({ p.opPop or false, p.opFade or false }) do
		if group then
			pcall(group.Stop, group)
		end
	end
	p.opFrame:SetAlpha(1)
end

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

function P.OverpowerClock(p)
	if p.opSwiping or not ns.Finite(p.opEnds) or P.Still(p) then
		return
	end
	local now = type(GetTime) == "function" and GetTime() or 0
	if now >= p.opEnds then
		P.OverpowerSwipe(p, true)
	end
end

function P.OverpowerSeconds(p)
	local text = p.opSecs
	if not text then
		return
	end
	local shown, tint = "", P.OP_WHITE
	if p.opFrame:IsShown() and Get("overpowerSeconds") == true then
		shown = "3"
		if p.S and type(p.S.still) == "function" and ns.Finite(p.opEnds) then
			local now = P.Still(p) and ns.Finite(p.opHeld) and p.opHeld or (type(GetTime) == "function" and GetTime() or 0)
			local whole = math.max(1, math.ceil(p.opEnds - now))
			shown = tostring(whole)
			tint = (whole <= 1 and P.OP_RED) or (whole <= 2 and P.OP_AMBER) or P.OP_WHITE
		end
	end
	if p.opSecsTint ~= tint then
		p.opSecsTint = tint
		text:SetTextColor(tint[1], tint[2], tint[3], 1)
	end
	if p.opSecsShown ~= shown then
		p.opSecsShown = shown
		text:SetText(shown)
	end
end

function P.Overpower(p, spec, o, m)
	if not (spec.overpower and o.styled and Get("overpower") == true) then
		p.opFrame:Hide()
		p.opT, p.opX = nil, nil
		P.OverpowerSwipe(p)
		return
	end
	local size = Get("overpowerSize")
	size = ns.Finite(size) and size > 0 and size or 34
	local top = m.top
	if p.tvalue:IsShown() and p.tvalueSide == "above" and ns.Finite(p.tvalueT) then
		top = p.tvalueT
	end
	local ox, oy = Get("overpowerX"), Get("overpowerY")
	ox, oy = ns.Finite(ox) and ox or 0, ns.Finite(oy) and oy or 0
	P.Put(p, p.opFrame, "BOTTOM", m.BW / 2 + ox, top + P.OP_GAP + oy, size, size)
	p.opT = top + P.OP_GAP + oy + size
	p.opX = m.BW / 2 + ox
	p.op:SetTexture(P.OverpowerIcon())
	ns.SetOutline(p.opOutline, true, false)
	p.opFrame:SetFrameLevel(p.f:GetFrameLevel() + 10)
	p.opSecsFrame:SetFrameLevel(p.opFrame:GetFrameLevel() + 3)
	P.Text(p.opSecs, math.max(6, math.floor(size * 0.45 + 0.5)), 100, "game", { 1, 1, 1 })
	p.opSecsTint = nil
	p.opFrame:Show()
	P.OverpowerSwipe(p)
	P.OverpowerSeconds(p)
end

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
	P.Text(p.ctime, P.CAST_FONT * m.v, o.castTextSize, o.castOutline, { 1, 1, 1 }, o.face)
	p.ctime:SetText(("%.1f"):format(cast.left))
	p.ctime:SetShown(o.castTime and true or false)
end

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

function P.Auras(p, spec, o, m)
	local count = spec.auras and m.AS and spec.auras.count or 0
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

function P.Plate(p, spec, sets)
	local o = P.Look(spec.friendly)
	local m = P.Measure(o, spec, sets)
	p.m, p.o = m, o
	p.box = { l = 0, b = 0, r = m.BW, t = m.top }
	p.f:SetSize(m.BW, m.top)
	p.f:SetScale(spec.scale or 1)
	if not p.alphaStep then
		p.f:SetAlpha(spec.alpha or 1)
	end
	local share = spec.health or P.SHARE
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
	local overlay = 1
	if o.border then
		overlay = o.dim and o.dimAmount or 0
	end
	p.over:ClearAllPoints()
	p.over:SetAllPoints(p.bar)
	p.over:SetColorTexture(0, 0, 0, P.DIM * overlay)
	p.over:SetShown(not (spec.target or spec.focus) and overlay > 0)
	local low = o.styled and Get("lowHealth") == true
	if low then
		ns.SetOutlineColour(p.low, ns.Colour(KEY .. ".lowHealthColour"))
	end
	p.lowFrame:SetAlpha((low and share * 100 < Get("lowHealthAt")) and 1 or 0)
	p.lowFrame:SetShown(low and true or false)
	local line = low and not spec.friendly and Get("lowHealthLine") == true
	if line then
		local at, px = Get("lowHealthAt"), ns.Pixels(p.bar, 1)
		local x = math.floor(m.HW * (ns.Finite(at) and at or 20) / 100 / px + 0.5) * px
		p.lowLine:ClearAllPoints()
		p.lowLine:SetPoint("TOPLEFT", p.bar, "TOPLEFT", x, 0)
		p.lowLine:SetPoint("BOTTOMLEFT", p.bar, "BOTTOMLEFT", x, 0)
		p.lowLine:SetWidth(px)
		local r, g, b = ns.Colour(KEY .. ".lowHealthColour")
		p.lowLine:SetColorTexture(r, g, b, 0.7)
	end
	p.lowLine:SetShown(line and true or false)
	P.Border(p, spec, o)
	P.TargetFlash(p, spec, o)
	p.name:ClearAllPoints()
	if m.nameAbove then
		P.Put(p, p.name, "BOTTOM", m.BW / 2, m.healthY + m.HH + m.sp)
	else
		P.Put(p, p.name, "LEFT", 4, m.center)
	end
	P.Text(p.name, P.FONT * m.v, o.nameSize, o.nameOutline, P.NameColour(spec, o), o.face)
	p.name:SetText(spec.name or "")
	p.name:SetShown(o.nameShow and true or false)
	p.name:SetWordWrap(false)
	if m.nameAbove then
		p.name:SetWidth(math.max(1, m.BW))
	else
		local used = #P.HealthText(o, share) * P.FONT * m.v * o.textSize / 100 * 0.5
		p.name:SetWidth(math.max(1, m.HW - 12 - (P.HealthSeen(spec, o) and used or 0)))
		p.name:SetJustifyH("LEFT")
	end
	p.htext:ClearAllPoints()
	p.htext:SetPoint("RIGHT", p.bar, "RIGHT", -4, 0)
	P.Text(p.htext, P.FONT * m.v, o.textSize, o.textOutline, o.textColour, o.face)
	p.htext:SetText(P.HealthText(o, share))
	p.htext:SetShown(P.HealthSeen(spec, o))
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
	if spec.marker and o.marker then
		P.Raid(p.marker, spec.marker)
		P.Put(p, p.marker, "RIGHT", o.markerX - m.iconShift, m.center + o.markerY, o.markerSize, o.markerSize)
		p.marker:Show()
	else
		p.marker:Hide()
	end
	P.LeftEnd(p, spec, o, m)
	P.Rarity(p, spec, o, m)
	P.Combo(p, spec, o, m)
	P.Threat(p, spec, o, m)
	P.Overpower(p, spec, o, m)
	P.QuestMark(p, spec, o, m)
	P.Cast(p, spec, o, m)
	P.Auras(p, spec, o, m)
	if type(ns.PlateSlipBox) == "function" then
		pcall(ns.PlateSlipBox, p)
	end
	return p.box
end

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
		local r, g, b = ns.Colour(KEY .. "." .. P.ThreatRow(rows[index][1]))
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
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", S.grid, "TOPLEFT", entry.x, -entry.y)
		label:ClearAllPoints()
		label:SetPoint("RIGHT", frame, "BOTTOMLEFT", -GAP_X + (entry.box.l), entry.plate.m and entry.plate.m.center or 6)
		label:SetJustifyH("RIGHT")
	end
	return width, height
end

function P.Fit(S, width, height, cw, ch)
	local fit = math.min(1, ((cw or P.CANVAS_W) - 2 * P.MARGIN) / math.max(1, width), ((ch or P.CANVAS_H) - 2 * P.MARGIN) / math.max(1, height))
	S.grid:SetSize(math.max(1, width), math.max(1, height))
	S.grid:ClearAllPoints()
	S.grid:SetPoint("CENTER", S.root, "CENTER", 0, 0)
	S.grid:SetScale(fit)
	S.fit = fit
end

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

function P.Canvas(S)
	local width, height = S.stage:GetSize()
	if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		width, height = P.CANVAS_W, P.CANVAS_H
	end
	S.root:SetScale(math.min(1, width / P.CANVAS_W, height / P.CANVAS_H))
end

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

function P.WalkCanvas(sets)
	local scale = P.SCALES[sets.size] or P.SCALES[2]
	return 84 + 250 * scale[1], 30 + 130 * scale[2]
end

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
				{ id = "target", label = "Target", col = 2, show = Get("targetBar") == true or Get("healthTextWhen") ~= "always",
					spec = Enemy({ target = true }) },
				{ id = "focus", label = "Focus", col = 2, show = Get("healthTextWhen") == "focus", spec = Enemy({ focus = true }) },
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
			local when = Get("aurasWhen")
			return {
				{ id = "auras", label = when ~= "always" and "Other enemy" or "Auras", col = 1, spec = Enemy({ auras = { count = 5 } }) },
				{ id = "auraTarget", label = "Your target", col = 1, show = when ~= "always", spec = Enemy({ target = true, auras = { count = 5 } }) },
				{ id = "auraFocus", label = "Focus", col = 1, show = when == "focus", spec = Enemy({ focus = true, auras = { count = 3 } }) },
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
				{ id = "overpower", label = P.OP_NAMES[class] or P.OP_NAMES.WARRIOR, col = 2,
					show = P.OP_SPELLS[class] ~= nil and (class ~= "ROGUE" or P.Knows(P.OP_SPELLS.ROGUE)),
					spec = Enemy({ overpower = true, target = P.OP_TARGET[class] }) },
				{ id = "combo", label = "Combo points", col = 2, show = class == "ROGUE" or class == "DRUID",
					spec = Enemy({ target = true, combo = 3, reserve = true }) },
				{ id = "comboFull", label = "Full points", col = 2, show = (class == "ROGUE" or class == "DRUID") and Get("comboPoints") == true,
					spec = Enemy({ target = true, combo = P.COMBO_MAX, reserve = true }) },
			}
		elseif kind == "threat" then
			local threat = Get("threat") == true
			return {
				{ id = "enemy", label = "Enemy", col = 1, spec = Enemy() },
				{ id = "player", label = "Enemy player", col = 1, spec = Enemy({ name = names.player, player = true }) },
				{ id = "friend", label = "Friendly player", col = 1, show = Get("classColoursFriendly") == true,
					spec = { name = names.friend, level = 18, friendly = true, player = true, health = P.SHARE } },
				{ id = "hover", label = "Mouseover", col = 1, show = Get("hover") == true, spec = Enemy({ hover = true }) },
				{ id = "low", label = "Low health", col = 1, show = Get("lowHealth") == true, spec = Enemy({ health = 0.18 }) },
				{ id = "good", label = "You want", col = 2, show = threat, spec = Enemy({ threat = "threatGood" }) },
				{ id = "changing", label = "Changing hands", col = 2, show = threat, spec = Enemy({ threat = "threatTransition" }) },
				{ id = "bad", label = "You do not want", col = 2, show = threat, spec = Enemy({ threat = "threatBad" }) },
				{ id = "offtank", label = "Held by another tank", col = 2, show = threat and Get("threatTanks") == true and not P.Damage(),
					spec = Enemy({ threat = "threatTank" }) },
				{ id = "target", label = threat and "Your target" or "Target", col = 2, spec = Enemy({ target = true, threat = "threatTransition" }) },
			}
		elseif kind == "walk" then
			return {
				{ id = "cast", label = "Casting", col = 1, spec = Enemy({ cast = { name = "Shadow Bolt", share = 0.6, left = 1.2 }, auras = { count = 3 } }) },
				{ id = "low", label = "Low health", col = 1, spec = Enemy({ health = 0.18 }) },
			}
		end
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

function P.Stack(S, layout)
	local by = {}
	for _, entry in ipairs(layout) do
		by[entry.cell.id] = entry
	end
	local target = by.target
	local BW = target.plate.m.BW
	local step = { BW * Get("overlapH") / 100, target.plate.m.top * Get("overlapV") / 100 }
	local spots = { target = { 0, 0 }, near = { step[1] / 2, step[2] }, far = { -step[1], 0 } }
	if Get("stackEnemies") ~= true then
		spots.near = { step[1] * 0.25, target.plate.m.top * 0.35 }
	end
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
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", S.grid, "BOTTOMLEFT", (spot[1] - left + LABEL - BW / 2 * scale) / scale, (spot[2] - bottom) / scale)
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
		frame:SetFrameLevel(id == "target" and 30 or 10)
	end
	return width, height
end

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
	Set({ "healthText", "healthTextSize", "healthTextOutline", "healthTextColour", "healthTextWhen", "healthFormat" },
		(Get("healthTextWhen") ~= "always" and Live("target") or plate).htext)
	Set({ "level", "levelSize", "levelShape", "levelGap" }, plate.lvl)
	Set({ "kindMark" }, (plates.elite or plate).mark)
	Set({ "colourPlayers" }, (plates.player or plate).bar)
	Set({ "classColoursEnemy" }, (Live("player") or plate).bar)
	Set({ "classColoursFriendly" }, (Live("friend") or plate).bar)
	Set({ "targetBar", "targetBarColour", "target", "targetColour", "targetThickness", "targetFlash" }, (Live("target") or plate).bar)
	Set({ "focusColour" }, (Live("focus") or Live("target") or plate).bar)
	Set({ "threat", "threatRole", "threatGood", "threatTransition", "threatBad", "threatSameColours", "threatDamageGood", "threatDamageTransition",
		"threatDamageBad" }, plates.threat and plates.threat.chips.f or plate.bar)
	Set({ "hover", "hoverColour" }, (Live("hover") or plate).bar)
	Set({ "lowHealth", "lowHealthAt", "lowHealthColour", "lowHealthLine" }, (Live("low") or plate).bar)
	Set({ "cast", "castBackdrop", "castFlat", "castTexture", "castHeight" }, plate.cbar)
	Set({ "castTextSize", "castTextOutline", "castTextColour" }, plate.ctext)
	Set({ "castIconSize" }, plate.cicon)
	Set({ "castSpark" }, plate.spark)
	Set({ "castShield" }, (plates.locked or plate).shield)
	Set({ "castTime" }, plate.ctime)
	Set({ "auras", "auraCrop", "auraBorderOwn", "auraBorderColour", "auraTimers", "auraStacks", "auraScale", "auraOpacity", "aurasWhen" }, (Live("auraTarget") or plate).auras)
	local player = plates.player or plate
	Set({ "classEnemy", "classPosition", "classFit", "classSize", "classGap", "classX", "classY", "classBorder", "classShape" }, player.iconFrame)
	Set({ "classFriendly" }, (plates.friend or plate).iconFrame)
	Set({ "kindBorder", "eliteColour" }, (plates.elite or plate).bar)
	Set({ "rareColour" }, (plates.rare or plate).bar)
	Set({ "bossColour" }, (plates.boss or plate).bar)
	Set({ "raidMarker", "raidMarkerSize", "raidMarkerX", "raidMarkerY" }, (plates.marked or plate).marker)
	Set({ "questMark", "questMarkSize", "questMarkPlace", "questMarkX", "questMarkY" }, (Live("quest") or plate).quest)
	Set({ "questMarkCount" }, (Live("quest") or plate).questCount)
	local overpower = Live("overpower")
	Set({ "overpower", "overpowerSize", "overpowerX", "overpowerY", "overpowerSwipe", "overpowerSeconds" }, overpower and overpower.opFrame or nil)
	local combo = Live("combo")
	Set({ "comboPoints", "comboColour", "comboFull", "comboFullColour", "comboSize", "comboY" }, combo and combo.combo or nil)
	local full = Live("comboFull")
	Set({ "comboFull", "comboFullColour", "comboBreathe" }, full and full.combo or (combo and combo.combo) or nil)
	local good, changing, bad = Live("good"), Live("changing"), Live("bad")
	if good and changing and bad then
		local target = Live("target") or changing
		Set({ "threatGood", "threatDamageGood", "threatSameColours", "threatRole" }, good.bar)
		Set({ "threatTransition", "threatDamageTransition" }, changing.bar)
		Set({ "threatBad", "threatDamageBad" }, bad.bar)
		Set({ "threatGlow", "threatFlash", "threatRingPx" }, bad.ring:IsShown() and bad.ring or bad.bar)
		Set({ "threatSlipping", "threatSlipGrow", "threatSlipScale" }, type(ns.PlateSlipShown) == "function" and ns.PlateSlipShown(bad) or bad.bar)
		Set({ "threatBar", "threatBorder", "threatBackground" }, bad.bar)
		Set({ "threatName" }, bad.name)
		Set({ "threatHealthText" }, bad.htext)
		Set({ "threatValue", "threatValueColour", "threatValueCustom", "threatValueSize", "threatValuePlace", "threatValueX", "threatValueY",
			"threatValueOutline" }, changing.tvalue:IsShown() and changing.tvalue or changing.bar)
		Set({ "aggroTarget", "aggroTargetOnly" }, target.ttarget:IsShown() and target.ttarget or target.bar)
		Set({ "aggroTargetNotMe" }, bad.ttarget:IsShown() and bad.ttarget or bad.bar)
		Set({ "threatFade", "threatFadeAlpha", "threatFadeSame", "threatFadeDamage" }, good.f)
		Set({ "threatFadeChanging" }, changing.f)
		local offtank = Live("offtank")
		Set({ "threatTanks", "threatTankColour" }, offtank and offtank.bar or good.bar)
	end
	Set({ "overlapH", "overlapV", "selectedScale" }, (Live("target") or plate).f)
	Set({ "stackEnemies", "stackFriends" }, (Live("near") or plate).f)
	Set({ "minScale", "minAlpha" }, (plates.far or plate).f)
	Set({ "notSelectedAlpha" }, (plates.near or plate).f)
	S.parts = parts
end

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
