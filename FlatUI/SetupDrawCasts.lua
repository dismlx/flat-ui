local _, ns = ...

ns.SetupDrawings = ns.SetupDrawings or {}

local DISPLAY_WIDTH = 200

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SPELL_ICON = "Interface\\Icons\\Spell_Shadow_ShadowBolt"
local SAMPLE_CLASS = { 0.78, 0.61, 0.43 }
local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }
local GREY = { 0.72, 0.72, 0.72 }

local function G(path)
	return ns.Get(path)
end

local function Max(a, b)
	return a > b and a or b
end

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
	GameTexture(inst, art.back, kind.back, { 0.15, 0.15, 0.15, 0.9 })
	GameTexture(inst, art.border, atlasFrame and kind.frame or nil)
	for _, texture in ipairs(art.edges) do
		GameTexture(inst, texture, nil, { 0.6, 0.6, 0.6, 1 })
		texture:SetShown(shown and not atlasFrame)
	end
	art.back:SetShown(shown)
	art.border:SetShown(shown and atlasFrame and true or false)
end

local function Look(text, percent, r, g, b, outline)
	if text then
		ns.TextStyle(text, { percent = percent, r = r, g = g, b = b, flags = outline and ns.OutlineFlags(outline) or nil })
	end
end

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

local CAST_ROWS = {
	{ opt = "player", label = "Player", name = "Shadow Bolt", rank = "Rank 3", state = "cast", part = 0.6, game = { 208, 11 }, time = "1.0", total = "2.5",
		push = "+0.4" },
	{ opt = "pet", label = "Pet", name = "Firebolt", state = "cast", part = 0.45, game = { 195, 13 }, time = "1.4", total = "2.0" },
	{ opt = "target", label = "Target", name = "Fireball", state = "cast", part = 0.6, game = { 150, 10 }, small = true, time = "1.2", total = "3.5",
		kick = "ready", aim = "> Jon", aimClass = "WARRIOR" },
	{ opt = "focus", label = "Focus", name = "Arcane Missiles", state = "channel", part = 0.4, game = { 150, 10 }, small = true, time = "1.8",
		total = "5.0", kick = "cooling" },
	{ opt = "target", label = "Target, out of range", name = "Frostbolt", state = "cast", part = 0.35, game = { 150, 10 }, small = true, time = "2.1",
		total = "3.0", kick = "far" },
	{ opt = "target", label = "Target, uninterruptible", name = "Polymorph", state = "shield", part = 0.7, game = { 150, 10 }, small = true, time = "0.9",
		total = "1.5", shield = true },
	{ opt = "player", label = "Player, channel", name = "Drain Life", state = "channel", part = 0.55, game = { 208, 11 }, ticks = 5, time = "2.7",
		total = "5.0" },
}
local CAST_GAME = { player = { 208, 11 }, pet = { 195, 13 }, target = { 150, 10 }, focus = { 150, 10 }, boss = { 150, 10 } }
local CAST_COLOURS = { cast = "castbars.castColour", channel = "castbars.channelColour", shield = "castbars.shieldColour",
	interrupted = "castbars.interruptedColour" }
local CAST_ATLAS = { cast = "ui-castingbar-filling-standard", channel = "ui-castingbar-filling-channel", shield = "ui-castingbar-uninterruptable",
	interrupted = "ui-castingbar-interrupted" }
local CAST_ART = { frame = "ui-castingbar-frame", back = "ui-castingbar-background", inset = { -1, 2, 1, -2 } }
local GAME_PLATE, GAME_SHIELD, GAME_PIP = "ui-castingbar-textbox", "ui-castingbar-shield", "ui-castingbar-pip"
local CAST_TEXT_WIDTH = 185
local CAST_LEFT, CAST_LABEL_GAP = 44, 30

local castMade = setmetatable({}, { __mode = "k" })
local castDrawing = {}

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
		row.queue = NewTexture(bar, "OVERLAY", 3)
		row.queue:SetColorTexture(1, 1, 1, 1)
		row.queue:Hide()
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
	if spec.small then
		row.kickStrip = NewTexture(bar, "OVERLAY", 3)
		row.kickStrip:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
		row.kickStrip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		row.kickStrip:Hide()
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
	if spec.kick == "cooling" then
		row.kickTime = NewText(bar)
		if row.kickTime then
			row.kickTime:SetPoint("LEFT", bar, "LEFT", 4, 0)
			row.kickTime:SetJustifyH("LEFT")
			row.kickTime:SetText(spec.kickTime or "4")
			row.kickTime:Hide()
		end
	end
	if spec.aim then
		row.aim = NewText(bar)
		if row.aim then
			row.aim:SetJustifyH("LEFT")
			row.aim:SetText(spec.aim)
			row.aim:Hide()
		end
	end
	if spec.opt == "player" then
		row.push = NewText(bar)
		if row.push then
			row.push:SetPoint("LEFT", bar, "RIGHT", 4, 0)
			row.push:SetJustifyH("LEFT")
			row.push:SetText(spec.push or "")
			row.push:Hide()
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
	local p, rows = inst.parts, inst.rows
	for _, row in ipairs(rows) do
		local opt = row.spec.opt
		for _, suffix in ipairs({ "", "Size", "Width", "Height" }) do
			p["castbars." .. opt .. suffix] = p["castbars." .. opt .. suffix] or row.bar
		end
	end
	local player, target, focus = rows[1], rows[3], rows[4]
	local far, shielded = focus, nil
	for _, row in ipairs(rows) do
		if row.spec.kick == "far" then
			far = row
		end
		if row.spec.shield then
			shielded = shielded or row
		end
	end
	p["castbars.enabled"] = inst.root
	p["castbars.playerMatch"] = player.bar
	p["castbars.backdrop"] = player.bar
	p["castbars.textPlate"] = player.plate
	p["castbars.spark"] = player.spark
	p["castbars.shield"] = shielded and shielded.shield or player.spark
	p["castbars.stateBorder"] = player.bar
	p["castbars.latency"], p["castbars.latencyColour"] = player.latency, player.latency
	p["castbars.queue"], p["castbars.queueColour"] = player.queue, player.queue
	for _, row in ipairs(rows) do
		if row.ticks then
			p["castbars.ticks"] = p["castbars.ticks"] or row.bar
			p["castbars.ticksColour"] = p["castbars.ticksColour"] or row.bar
		end
	end
	p["castbars.flat"] = player.fill
	p["castbars.texture"] = player.fill
	p["castbars.playerClass"] = player.fill
	p["castbars.targetOwn"] = target.fill
	p["castbars.targetCast"] = target.fill
	p["castbars.targetChannel"] = focus.fill
	p["castbars.interrupt"], p["castbars.interruptReady"] = target.bar, target.bar
	p["castbars.interruptCooling"], p["castbars.interruptFar"] = focus.bar, far.bar
	p["castbars.interruptStrip"] = target.bar
	p["castbars.playerText"] = player.text
	p["castbars.rank"] = player.text
	for _, path in ipairs({ "textSize", "textOutline", "textShow", "textAlign", "textOwn", "textColour" }) do
		p["castbars." .. path] = player.text
	end
	p["castbars.ownTime"] = target.time
	p["castbars.castTarget"] = target.aim
	p["castbars.kickTime"] = focus.kickTime or focus.bar
	p["castbars.playerTime"] = player.time
	p["castbars.timeTotal"] = target.time
	p["castbars.pushback"], p["castbars.pushbackColour"] = player.push, player.push
	p["castbars.iconPos"] = target.icon
	p["castbars.playerIcon"] = player.icon
	return inst
end

local KICK_COLOURS = { ready = "castbars.interruptReady", cooling = "castbars.interruptCooling", far = "castbars.interruptFar" }
local function CastFillColour(opt, state, kick)
	if kick and (state == "cast" or state == "channel") and G("castbars.interrupt") == true then
		return ns.Colour(KICK_COLOURS[kick] or KICK_COLOURS.ready)
	elseif opt == "player" and (state == "cast" or state == "channel") and G("castbars.playerClass") then
		return ClassRGB()
	elseif (opt == "target" or opt == "focus") and (state == "cast" or state == "channel") and G("castbars.targetOwn") then
		return ns.Colour(state == "cast" and "castbars.targetCast" or "castbars.targetChannel")
	end
	return ns.Colour(CAST_COLOURS[state] or CAST_COLOURS.cast)
end

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
	if row.kickStrip then
		local strip = kick and enabled and not look.flat and G("castbars.interrupt") == true and (state == "cast" or state == "channel") or false
		if strip then
			local kr, kg, kb = ns.Colour(KICK_COLOURS[kick] or KICK_COLOURS.ready)
			row.kickStrip:SetColorTexture(kr, kg, kb, 1)
			local px = G("castbars.interruptStrip")
			row.kickStrip:SetHeight(ns.Pixels(row.bar, ns.Finite(px) and px >= 1 and px or 2))
		end
		row.kickStrip:SetShown(strip)
	end
	return r, g, b
end

local function CastName(row, look, name)
	local spec = row.spec
	if name then
		return name
	end
	return spec.rank and look.enabled and G("castbars.rank") == true and (spec.name .. " (" .. spec.rank .. ")") or spec.name or ""
end

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

local function PaintTicks(row, look, state, w, part)
	local list = row.ticks
	if not list then
		return
	end
	local on = look.enabled and G("castbars.ticks") == true and state == "channel"
	local n = #list + 1
	if on then
		local ok, r, g, b = pcall(ns.Colour, "castbars.ticksColour")
		if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
			r, g, b = 1, 1, 1
		end
		for _, mark in ipairs(list) do
			mark:SetColorTexture(r, g, b, 0.6)
		end
	end
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

local function PlaceLatency(row, look, state, w)
	local latency = row.latency
	if not latency then
		return
	end
	local ok, r, g, b = pcall(ns.Colour, "castbars.latencyColour")
	if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = 1, 0, 0
	end
	latency:SetColorTexture(r, g, b, 0.6)
	local side = state == "channel" and "LEFT" or "RIGHT"
	latency:ClearAllPoints()
	latency:SetPoint("TOP" .. side, row.bar, "TOP" .. side, 0, 0)
	latency:SetPoint("BOTTOM" .. side, row.bar, "BOTTOM" .. side, 0, 0)
	latency:SetWidth(Max(w * 0.05, 0.01))
	latency:SetShown(look.enabled and G("castbars.latency") == true and state ~= "interrupted")
end

local QUEUE_SAMPLE, QUEUE_CAST = 0.4, 2.5
local function PlaceQueue(row, look, state, w)
	local queue = row.queue
	if not queue then
		return
	end
	local ok, r, g, b = pcall(ns.Colour, "castbars.queueColour")
	if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = 1, 1, 1
	end
	queue:SetColorTexture(r, g, b, 1)
	local x = w * (1 - QUEUE_SAMPLE / QUEUE_CAST)
	queue:ClearAllPoints()
	queue:SetPoint("TOP", row.bar, "TOPLEFT", x, 0)
	queue:SetPoint("BOTTOM", row.bar, "BOTTOMLEFT", x, 0)
	queue:SetWidth(ns.Pixels(row.bar, 1))
	queue:SetShown(look.enabled and G("castbars.queue") == true and state == "cast")
end

local function ShowTime(row, look, opt, state)
	if row.time then
		local timeRow = (opt == "player" or opt == "pet") and "castbars.playerTime" or "castbars.ownTime"
		row.time:SetShown(look.enabled and G(timeRow) == true and state ~= "interrupted")
	end
end

local function ShowAim(row, look)
	if row.aim then
		row.aim:SetShown(look.enabled and G("castbars.castTarget") == true)
	end
end

local function AimRGB(spec)
	if spec.aimClass and type(C_ClassColor) == "table" then
		local ok, colour = pcall(C_ClassColor.GetClassColor, spec.aimClass)
		if ok and type(colour) == "table" and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
			return colour.r, colour.g, colour.b
		end
		return SAMPLE_CLASS[1], SAMPLE_CLASS[2], SAMPLE_CLASS[3]
	end
	return ClassRGB()
end

local function KickLook(row, look)
	local r, g, b
	if look.flat then
		if look.r then
			r, g, b = look.r, look.g, look.b
		else
			r, g, b = 1, 1, 1
		end
	else
		r, g, b = ns.Colour("castbars.interruptCooling")
	end
	Look(row.kickTime, look.percent, r, g, b, (look.outline == "thin" or look.outline == "thick") and look.outline or "thin")
end

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
	PlaceQueue(row, look, state, w)
	if spec.small then
		local place = enabled and G("castbars.iconPos") or "game"
		row.icon:SetSize(20, 20)
		if place == "right" then
			Place(row.icon, "LEFT", bar, "RIGHT", 5, 0)
		else
			Place(row.icon, "RIGHT", bar, "LEFT", -2, -5)
		end
		row.icon:SetShown(place ~= "hidden")
		if row.aim then
			if place == "right" then
				Place(row.aim, "LEFT", row.icon, "RIGHT", 4, 0)
			else
				Place(row.aim, "LEFT", bar, "RIGHT", 4, 0)
			end
			row.aim:SetText(spec.aim or "")
			ShowAim(row, look)
			local ar, ag, ab = AimRGB(spec)
			Look(row.aim, look.percent, ar, ag, ab, look.outline)
		end
	else
		row.icon:SetSize(h, h)
		Place(row.icon, "RIGHT", bar, "LEFT", -5, 0)
		row.icon:SetShown(enabled and G("castbars.playerIcon") == true)
	end
	PaintTicks(row, look, state, w, part)
	if row.kickTime then
		row.kickTime:SetShown(enabled and kick == "cooling" and G("castbars.kickTime") == true and G("castbars.interrupt") == true
			and (state == "cast" or state == "channel"))
		KickLook(row, look)
	end
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
	if row.time then
		ShowTime(row, look, opt, state)
		if spec.time ~= nil and spec.time ~= "" then
			row.time:SetText((spec.total and enabled and G("castbars.timeTotal") == true) and (spec.time .. " / " .. spec.total) or spec.time)
		end
		Look(row.time, look.percent, nil, nil, nil, look.outline)
	end
	if row.push then
		row.pushOn = enabled and G("castbars.pushback") == true
		row.push:SetText(spec.push or "")
		row.push:SetShown(row.pushOn and spec.push ~= nil)
		local pr, pg, pb = ns.Colour("castbars.pushbackColour")
		Look(row.push, look.percent, pr, pg, pb, look.outline)
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
		PaintCastBar(row, look, spec.opt, spec.state, spec.part, sizes[index][1], h, nil, spec.kick)
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

local DC = {}
ns.DrawCasts = DC

function DC.Cast(parent, spec)
	return NewCastBar({ grey = {}, outlines = {} }, parent, spec)
end

function DC.PaintCast(row, opt, state, part, w, h, name, kick)
	local look = CastLook(opt == "boss")
	if not (ns.Finite(w) and ns.Finite(h)) then
		w, h = CastSize(look, opt, CAST_GAME[opt] or CAST_GAME.target)
	end
	row.look, row.opt, row.w, row.kick, row.state = look, opt, w, kick, state
	PaintCastBar(row, look, opt, state, part, w, h, name, kick)
	return w, h
end

function DC.CastKick(row, kick, left, state)
	if not row.look then
		return
	end
	row.kick = kick
	local fs = row.kickTime
	if fs then
		local on = row.look.enabled and kick == "cooling" and G("castbars.kickTime") == true and G("castbars.interrupt") == true
			and (state == "cast" or state == "channel") and ns.Finite(left) and left > 0
		if on then
			fs:SetText(("%d"):format(math.ceil(left)))
		end
		fs:SetShown(on)
	end
end

function DC.CastProgress(row, state, part, left, name, total)
	if not row.look then
		return
	end
	CastFill(row, row.look, row.opt, state, part, row.w, row.kick)
	if row.text and (state ~= row.state or name) then
		row.text:SetText(CastName(row, row.look, name))
	end
	if state ~= row.state then
		PaintTicks(row, row.look, state, row.w, part)
		PlaceLatency(row, row.look, state, row.w)
		PlaceQueue(row, row.look, state, row.w)
		ShowTime(row, row.look, row.opt, state)
		ShowAim(row, row.look)
	elseif state == "channel" then
		DimTicks(row, part)
	end
	row.state = state
	if row.time and ns.Finite(left) then
		if ns.Finite(total) and total > 0 and G("castbars.timeTotal") == true then
			row.time:SetText(("%.1f / %.1f"):format(math.max(0, left), total))
		else
			row.time:SetText(("%.1f"):format(math.max(0, left)))
		end
	end
	if row.push then
		local sample = state == "interrupted" and "+0.4"
			or ns.Finite(part) and ((state == "cast" and part >= 0.5 and "+0.4") or (state == "channel" and part <= 0.5 and "-0.8")) or nil
		if sample then
			row.push:SetText(sample)
		end
		row.push:SetShown(row.pushOn == true and sample ~= nil)
	end
end

local RES_WIDTH, RES_LEFT, RES_TOP = 150, 14, 12
local RES_BARS = {
	{ opt = "health", label = "Health", height = 14 },
	{ opt = "power", label = "Power", height = 11 },
	{ opt = "alt", label = "Alternate power", height = 7 },
}
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

local SWING_FRAME_W, SWING_FRAME_H, SWING_BAR_W, SWING_BAR_H = 190, 22, 180, 14
local SWING_LEFT, SWING_TOP, SWING_GAP, SWING_SHADOW = 14, 10, 6, 171
local GAME_IN, GAME_OUT, GAME_RANGE_ALPHA = { 1, 1, 1 }, { 1, 0.1, 0.1 }, 0.4
local SWING_FILL_ATLAS = { main = "ui-swingtimerbar-filling-mainhand", off = "ui-swingtimerbar-filling-offhand", ranged = "ui-swingtimerbar-filling-ranged" }
local SWING_ART = { frame = "ui-swingtimerbar-frame", back = "ui-swingtimerbar-background" }
local SWING_PIP, SWING_SHADOW_ATLAS = "ui-swingtimerbar-pip", "ui-swingtimerbar-textshadow-left"
local function HandName(hand)
	if hand == "main" then
		return SWING_TIMER_MAIN_HAND or "Main hand"
	elseif hand == "off" then
		return SWING_TIMER_OFF_HAND or "Off hand"
	end
	return SWING_TIMER_RANGED or "Ranged"
end
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

local function NewSwingTimer(inst, parent, spec)
	local row = { spec = spec, inst = inst }
	row.timer = NewFrame(parent)
	row.timer:SetSize(SWING_FRAME_W, SWING_FRAME_H)
	row.art = NewArt(inst, row.timer, SWING_ART)
	row.bar = NewFrame(row.timer)
	row.bar:SetPoint("TOPLEFT", row.timer, "TOPLEFT", 5, -4)
	row.bar:SetPoint("BOTTOMRIGHT", row.timer, "BOTTOMRIGHT", -5, 4)
	row.fill = NewTexture(row.bar, "ARTWORK", 0)
	if spec.hand == "ranged" then
		row.band = NewTexture(row.bar, "ARTWORK", 7)
	end
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

local function SwingProgress(spec, clock)
	if spec.idle then
		return 0, 0
	end
	local run = (spec.part + clock / spec.period) % 1
	return run, spec.period * (1 - run)
end

local function SwingFill(row, look, run, left)
	local spec, colour = row.spec, look.colour[row.spec.hand]
	FillBar(row.fill, row.bar, look.barW or SWING_BAR_W, run, look.reverse, look.file, colour[1], colour[2], colour[3], look.atlas[spec.hand])
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

local function PaintSwingTimer(row, look)
	local inst, spec = row.inst, row.spec
	row.timer:SetSize(look.frameW, SWING_FRAME_H)
	local on = look.enabled and G("swing." .. spec.hand) == true
	local idle = look.idleHide and spec.idle
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

local QUEUE_CLASSES = { WARRIOR = true, DRUID = true, HUNTER = true }
local function Queues()
	if type(UnitClassBase) ~= "function" then
		return false
	end
	local ok, class = pcall(UnitClassBase, "player")
	return ok and not ns.IsSecret(class) and type(class) == "string" and QUEUE_CLASSES[class] == true
end

function DC.Swing(parent, hand, period)
	return NewSwingTimer({ grey = {}, outlines = {} }, parent, { hand = hand, part = 0, period = period or 2.6, queued = hand == "main" and Queues() })
end

function DC.PaintSwing(row, w)
	local look = SwingLook(ns.Finite(w) and w > 0 and w or nil)
	row.look = look
	PaintSwingTimer(row, look)
	SwingFill(row, look, 0, row.spec.period)
	return look.frameW, SWING_FRAME_H
end

function DC.SwingProgress(row, run, left)
	if row.look then
		SwingFill(row, row.look, run, left)
	end
end
