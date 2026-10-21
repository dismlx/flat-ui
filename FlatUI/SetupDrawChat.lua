local _, ns = ...

-- The setup drawings of chat, tooltips and combat text: mock-chat (chat windows and chat text), mock-tooltip and mock-combat-text. Each is a
-- table { build(stage), draw(stage), parts } as the drawing library of the setup wizard takes it. build makes the frames once, all marked
-- ns.Own; draw reads the settings only through ns.Get, so under the draft view of the wizard it draws the draft, and it lays everything
-- out again each time it runs. Sample text and numbers are fixed. The look of a frame, a fill, a face and a colour comes from the same
-- functions the modules paint with (ns.Outline, ns.SetOutlineFill, ns.TipShades, ns.FontFile, ns.OutlineFlags, ns.FlatFill, ns.BarTexture,
-- ns.CombatOffsets, ns.CombatPopHeight, ns.CombatOwnEdge, ns.CombatColour, ns.CombatFont).

ns.SetupDrawings = ns.SetupDrawings or {}

local U = {}

-- Standard class colours, for a client that does not give RAID_CLASS_COLORS.
U.CLASS = { HUNTER = { 0.67, 0.83, 0.45 }, PRIEST = { 1, 1, 1 }, ROGUE = { 1, 0.96, 0.41 }, MAGE = { 0.41, 0.8, 0.94 }, WARRIOR = { 0.78, 0.61, 0.43 } }
-- The colour of a unit's name by reaction: hostile red and friendly green, as the game gives them (GameTooltip.lua:120-167).
U.RED, U.GREEN, U.WHITE = { 0.8, 0.3, 0.22 }, { 0, 0.6, 0.1 }, { 1, 1, 1 }
U.FRIZ, U.GAME_FLAGS = "Fonts\\FRIZQT__.TTF", ""

-- A frame of the addon's own.
function U.frame(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	ns.Own[f] = true
	if w then
		f:SetSize(w, h)
	end
	return f
end

function U.tex(parent, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	ns.Own[t] = true
	return t
end

-- A font string of the addon's own, left aligned. The size and face are set by U.font.
function U.text(parent)
	local t = ns.OwnText(parent, "OVERLAY", "GameFontHighlightSmall")
	if t then
		t:SetJustifyH("LEFT")
		t:SetWordWrap(false)
	end
	return t
end

function U.at(region, point, relative, relativePoint, x, y)
	region:ClearAllPoints()
	region:SetPoint(point, relative, relativePoint or point, x or 0, y or 0)
end

-- A face, a size, flags and a shadow on a font string, and a colour. A face the client refuses is drawn in Friz Quadrata.
function U.font(fs, file, size, flags, shadow, colour)
	local ok, done = pcall(fs.SetFont, fs, file, size, flags or "")
	if not ok or done == false then
		pcall(fs.SetFont, fs, U.FRIZ, size, flags or "")
	end
	if fs.SetShadowOffset then
		pcall(fs.SetShadowOffset, fs, shadow and 1 or 0, shadow and -1 or 0)
	end
	if fs.SetShadowColor then
		pcall(fs.SetShadowColor, fs, 0, 0, 0, shadow and 1 or 0)
	end
	if colour then
		fs:SetTextColor(colour[1], colour[2], colour[3])
	end
end

-- The plain look the game gives a part this addon leaves alone: a dark fill and thin grey edges, drawn on the frame itself.
function U.art(frame)
	local a = { fill = U.tex(frame, "BACKGROUND", -7), edges = {} }
	a.fill:SetAllPoints(frame)
	for i = 1, 4 do
		local e = U.tex(frame, "BORDER", 0)
		a.edges[i] = e
		if i == 1 then
			e:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			e:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
			e:SetHeight(1)
		elseif i == 2 then
			e:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
			e:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
			e:SetHeight(1)
		elseif i == 3 then
			e:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			e:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
			e:SetWidth(1)
		else
			e:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
			e:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
			e:SetWidth(1)
		end
	end
	return a
end

-- Shows or hides the plain look, with its fill { r, g, b, a } and edge colour { r, g, b }.
function U.artShow(a, shown, fill, edge)
	a.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
	a.fill:SetShown(shown)
	for _, e in ipairs(a.edges) do
		e:SetColorTexture(edge[1], edge[2], edge[3], 1)
		e:SetShown(shown)
	end
end

-- The label under a part drawn as the game's plain plate, so a stand-in is not taken for the real look.
function U.gameLook(parent, point, relative, relativePoint, x, y)
	local t = U.text(parent)
	t:SetText("Game look")
	U.at(t, point, relative, relativePoint, x, y)
	return t
end

function U.gameLookShow(label, shown)
	label:SetShown(shown)
	U.font(label, U.FRIZ, 10, "", true, { 0.6, 0.6, 0.6 })
end

-- An outline of the addon's own on a frame, following the border and background rows of a page. prefix is "look" or "tip".
function U.outlined(frame, area, prefix)
	local o = ns.Outline(frame, frame, nil, prefix)
	return ns.SetOutlineArea(o, area)
end

-- Paints an outline again from the settings in force now. Painting reads the border and background rows only when something about the outline
-- changes, so a change of those rows alone needs this.
function U.repaint(o)
	ns.SetOutlineBare(o, true)
	ns.SetOutlineBare(o, false)
end

-- The name, the class name and the class colour of the player, which the client gives for "player". A client that withholds them gets a mage.
function U.player()
	local name, class = "Priestly", "Mage"
	if type(UnitName) == "function" then
		local ok, value = pcall(UnitName, "player")
		if ok and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
			name = value
		end
	end
	if type(UnitClass) == "function" then
		local ok, value = pcall(UnitClass, "player")
		if ok and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
			class = value
		end
	end
	local r, g, b = ns.ClassColour()
	if not r then
		r, g, b = U.CLASS.MAGE[1], U.CLASS.MAGE[2], U.CLASS.MAGE[3]
	end
	return name, class, { r, g, b }
end

-- The colour of a class by its token.
function U.classColour(token)
	local c = type(RAID_CLASS_COLORS) == "table" and not ns.IsSecret(RAID_CLASS_COLORS) and RAID_CLASS_COLORS[token]
	if type(c) == "table" and not ns.IsSecret(c) and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
		return { c.r, c.g, c.b }
	end
	return U.CLASS[token] or U.WHITE
end

-- Text in a colour, for a name inside a line.
function U.coloured(colour, text)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(colour[1] * 255 + 0.5), math.floor(colour[2] * 255 + 0.5), math.floor(colour[3] * 255 + 0.5), text)
end

-- Chat ----------------------------------------------------------------------------------------------------------------------------

do
	local instances = setmetatable({}, { __mode = "k" })
	-- The game's chat font is Arial Narrow 14 with a shadow (Mainline/Fonts.xml:775-781, Shared/Fonts.xml:1373).
	local GAME_FACE, SIZE = "Fonts\\ARIALN.TTF", 14
	local WIDTH, HEIGHT, TAB, BOX, GAP, LEFT = 360, 112, 22, 26, 2, 40
	-- 3:27:32 in the afternoon, written as each choice of Timestamps writes it (the formats of Config.lua).
	local STAMP = { none = "", hhmm = "03:27 ", hhmmss = "03:27:32 ", hhmmAm = "03:27 PM ", hhmmssAm = "03:27:32 PM ", hhmm24 = "15:27 ", hhmmss24 = "15:27:32 " }
	local PARTY, GUILD, GENERAL = { 0.67, 0.67, 1 }, { 0.25, 1, 0.25 }, { 1, 0.75, 0.75 }
	-- Per line: the channel label, its colour, who speaks and in which class, the message, and whether Per channel colours the name (the
	-- legacy setting of that channel, ChatFrameUtil.lua:891-894).
	local LINES = {
		{ label = "[1. General]", colour = GENERAL, who = "Hunterly", class = "HUNTER", text = "any healer for Deadmines?", legacy = false },
		{ label = "[Party]", colour = PARTY, who = false, class = false, text = "on my way", legacy = true },
		{ label = "[Guild]", colour = GUILD, who = "Rogueish", class = "ROGUE", text = "pulling in two minutes", legacy = true },
		{ colour = { 1, 1, 0 }, text = "You receive loot: Linen Cloth." },
	}
	local TABS = { { "General", 76, true }, { "Combat Log", 88 }, { "Priestly", 68, false, { 1, 0.5, 1 } } }

	local function Build(stage)
		local S = {}
		instances[stage] = S
		S.root = U.frame(stage, 640, 204)
		S.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
		S.window = U.frame(S.root, WIDTH, HEIGHT)
		S.windowOutline = U.outlined(S.window, "chat")
		S.windowArt = U.art(S.window)
		S.lines = {}
		for i = 1, #LINES do
			S.lines[i] = U.text(S.window)
		end
		S.tabs = {}
		for i, def in ipairs(TABS) do
			local tab = { frame = U.frame(S.root, def[2], TAB), selected = def[3] == true, own = def[4] }
			tab.outline = U.outlined(tab.frame, "chat")
			tab.art = U.art(tab.frame)
			tab.label = U.text(tab.frame)
			tab.label:SetPoint("CENTER", tab.frame, "CENTER", 0, 0)
			tab.label:SetText(def[1])
			S.tabs[i] = tab
		end
		S.buttons = U.frame(S.root, 26, 74)
		S.buttonsArt = U.art(S.buttons)
		for i = 1, 3 do
			local square = U.tex(S.buttons, "ARTWORK", 1)
			square:SetSize(14, 14)
			square:SetPoint("TOP", S.buttons, "TOP", 0, -6 - (i - 1) * 22)
			square:SetColorTexture(0.7, 0.7, 0.7, 1)
		end
		S.box = { frame = U.frame(S.root, WIDTH, BOX) }
		S.box.outline = U.outlined(S.box.frame, "chat")
		S.box.art = U.art(S.box.frame)
		S.box.text = U.text(S.box.frame)
		S.box.text:SetPoint("LEFT", S.box.frame, "LEFT", 8, 0)
		S.typing = { frame = U.frame(S.root, 220, BOX) }
		S.typing.outline = U.outlined(S.typing.frame, "chat")
		S.typing.art = U.art(S.typing.frame)
		S.typing.text = U.text(S.typing.frame)
		S.typing.text:SetPoint("LEFT", S.typing.frame, "LEFT", 8, 0)
		S.gameLook = U.gameLook(S.root, "BOTTOMLEFT", S.root, "BOTTOMLEFT", LEFT, 4)
		return S
	end

	local function Draw(stage)
		local S = instances[stage]
		if not S then
			return
		end
		local on = ns.Get("chat.enabled") == true
		local frames, tabsOn, buttonsOn, boxOn = on and ns.Get("chat.frames") == true, on and ns.Get("chat.tabs") == true,
			on and ns.Get("chat.buttons") == true, on and ns.Get("chat.editbox") == true
		local place = on and ns.Get("chat.inputPlace") or "below"
		-- Layout: the input box below the window, or above the tabs.
		local y0 = 20
		local windowY, tabsY, boxY = y0 + BOX + GAP, y0 + BOX + GAP + HEIGHT + GAP, y0
		if place == "above" then
			windowY, tabsY, boxY = y0, y0 + HEIGHT + GAP, y0 + HEIGHT + GAP + TAB + GAP
		end
		U.at(S.window, "BOTTOMLEFT", S.root, "BOTTOMLEFT", LEFT, windowY)
		U.at(S.buttons, "BOTTOMLEFT", S.root, "BOTTOMLEFT", 8, windowY + HEIGHT - 74)
		U.at(S.box.frame, "BOTTOMLEFT", S.root, "BOTTOMLEFT", LEFT, boxY)
		U.at(S.typing.frame, "BOTTOMLEFT", S.root, "BOTTOMLEFT", LEFT + WIDTH + 24, y0 + 60)
		-- The window: the background at the chosen opacity and the thin border, or the game's plain plate.
		local alpha = ns.Get("chat.opacity") / 100
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(S.windowOutline, r, g, b, alpha)
		ns.SetOutlineEdges(S.windowOutline, ns.Get("chat.frameBorder") ~= false)
		ns.SetOutline(S.windowOutline, frames and alpha > 0, frames and alpha > 0)
		U.artShow(S.windowArt, not frames, { 0, 0, 0, 0.4 }, { 0.45, 0.45, 0.45 })
		U.repaint(S.windowOutline)
		-- The tabs.
		local x = LEFT
		for _, tab in ipairs(S.tabs) do
			U.at(tab.frame, "BOTTOMLEFT", S.root, "BOTTOMLEFT", x, tabsY)
			x = x + tab.frame:GetWidth() + GAP
			ns.SetOutline(tab.outline, tabsOn, tabsOn)
			local sr, sg, sb
			if tabsOn and tab.selected then
				sr, sg, sb = ns.Colour("windows.accent")
				if tab.own then
					sr, sg, sb = tab.own[1], tab.own[2], tab.own[3]
				end
			end
			ns.SetOutlineColour(tab.outline, sr, sg, sb)
			U.artShow(tab.art, not tabsOn, { 0.2, 0.2, 0.2, tab.selected and 0.85 or 0.5 }, { 0.2, 0.2, 0.2 })
			U.font(tab.label, U.FRIZ, 12, "", true, tab.own or (tab.selected and U.WHITE or { 0.78, 0.78, 0.78 }))
			U.repaint(tab.outline)
		end
		-- The buttons beside the window: the game's plate behind them unless Chat button background hides it.
		U.artShow(S.buttonsArt, not buttonsOn, { 0.2, 0.2, 0.2, 0.85 }, { 0.45, 0.45, 0.45 })
		-- The input box, idle, and while typing in the party channel.
		S.box.frame:SetAlpha((on and ns.Get("chat.inputIdle") or 35) / 100)
		ns.SetOutline(S.box.outline, boxOn, boxOn)
		ns.SetOutlineColour(S.box.outline, nil, nil, nil)
		U.artShow(S.box.art, not boxOn, { 0.1, 0.1, 0.1, 0.9 }, { 0.45, 0.45, 0.45 })
		U.repaint(S.box.outline)
		local mode = ns.Get("chat.inputFocus")
		local fr, fg, fb
		if boxOn and mode == "accent" then
			fr, fg, fb = ns.Colour("windows.accent")
		elseif boxOn and mode ~= "plain" then
			fr, fg, fb = PARTY[1], PARTY[2], PARTY[3]
		end
		ns.SetOutline(S.typing.outline, boxOn, boxOn)
		ns.SetOutlineColour(S.typing.outline, fr, fg, fb)
		U.artShow(S.typing.art, not boxOn, { 0.1, 0.1, 0.1, 0.9 }, PARTY)
		U.repaint(S.typing.outline)
		U.gameLookShow(S.gameLook, not frames or not tabsOn or not buttonsOn or not boxOn)
		-- The text: the face, the outline and the shadow, which the game's own chat font has when Flat UI leaves it alone.
		local file, flags, shadow = GAME_FACE, U.GAME_FLAGS, true
		if on then
			file = ns.FontFile(ns.Get("chat.font")) or GAME_FACE
			flags = ns.OutlineFlags(ns.Get("chat.outline")) or U.GAME_FLAGS
			shadow = ns.Get("chat.shadow") ~= false
		end
		local stamp = STAMP[ns.Get("chat.timestamps")] or ""
		local colourMode = ns.Get("chat.classColour")
		local name, _, mine = U.player()
		for i, line in ipairs(LINES) do
			local fs = S.lines[i]
			local text = line.text
			if line.label then
				local who = line.who or name
				local byClass = colourMode == "always" or (colourMode == "channel" and line.legacy)
				if byClass then
					who = U.coloured(line.who and U.classColour(line.class) or mine, who)
				end
				text = line.label .. " " .. who .. ": " .. text
			end
			fs:SetText(stamp .. text)
			U.font(fs, file, SIZE, flags, shadow, line.colour)
			U.at(fs, "TOPLEFT", S.window, "TOPLEFT", 8, -8 - (i - 1) * (SIZE + 4))
			fs:SetWidth(WIDTH - 16)
		end
		S.box.text:SetText("Say:")
		U.font(S.box.text, file, SIZE, flags, shadow, U.WHITE)
		S.typing.text:SetText("Party: ready")
		U.font(S.typing.text, file, SIZE, flags, shadow, PARTY)
	end

	local drawing = { draw = Draw, parts = {} }
	drawing.build = function(stage)
		local S = Build(stage)
		local p = drawing.parts
		p.window, p.tabs, p.buttons, p.lines, p.input, p.typing = S.window, S.tabs[1].frame, S.buttons, S.lines[1], S.box.frame, S.typing.frame
		p["chat.frames"], p["chat.opacity"], p["chat.frameBorder"] = S.window, S.window, S.window
		p["chat.lookOwn"], p["chat.lookBorder"], p["chat.lookBack"], p["chat.lookBackAlpha"] = S.window, S.window, S.tabs[1].frame, S.tabs[1].frame
		p["chat.tabs"], p["chat.buttons"] = S.tabs[1].frame, S.buttons
		p["chat.editbox"], p["chat.inputPlace"], p["chat.inputIdle"] = S.box.frame, S.box.frame, S.box.frame
		p["chat.inputFocus"] = S.typing.frame
		p["chat.timestamps"], p["chat.classColour"], p["chat.font"], p["chat.outline"], p["chat.shadow"] = S.lines[1], S.lines[1], S.lines[1], S.lines[1], S.lines[1]
		p["chat.enabled"] = S.root
		return S
	end
	ns.SetupDrawings["mock-chat"] = drawing
end

-- Tooltips ------------------------------------------------------------------------------------------------------------------------

do
	local instances = setmetatable({}, { __mode = "k" })
	-- The sizes of the game's tooltip fonts: the title 14 and the text 12 (Shared/Fonts.xml:1273-1275, 1385-1387).
	local TITLE, TEXT = 14, 12
	local LABEL = 16
	local WIDTH, PAD, GAP, BAR_FILE = 190, 8, 14, "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
	local EPIC = { 0.64, 0.21, 0.93 }
	local GREY, YELLOW = { 0.8, 0.8, 0.8 }, { 1, 0.82, 0 }
	local DEFS

	local function Build(stage)
		local S = { tips = {} }
		instances[stage] = S
		S.root = U.frame(stage, 602, 146)
		S.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
		local name, class, mine = U.player()
		DEFS = {
			{ id = "item", title = "Staff of Jordan", colour = EPIC, lines = { { "Binds when equipped", U.WHITE }, { "Two-Hand Staff", U.WHITE }, { "+12 Intellect", { 0, 1, 0 } } } },
			{ id = "mob", title = "Defias Pillager", colour = U.RED, unit = "mob", health = U.RED, lines = { { "Level 18 Humanoid", YELLOW } } },
			{ id = "player", title = name, colour = U.WHITE, unit = "player", health = U.GREEN, mine = mine, lines = { { "Level 12 " .. class, YELLOW } } },
		}
		for i, def in ipairs(DEFS) do
			local tip = { def = def, frame = U.frame(S.root, WIDTH, 80) }
			tip.outline = U.outlined(tip.frame, "chat", "tip")
			tip.art = U.art(tip.frame)
			tip.title = U.text(tip.frame)
			tip.lines = {}
			for n = 1, 5 do
				tip.lines[n] = U.text(tip.frame)
			end
			if def.unit then
				local bar = CreateFrame("StatusBar", nil, tip.frame)
				ns.Own[bar] = true
				bar:SetStatusBarTexture(BAR_FILE)
				bar:SetMinMaxValues(0, 10000)
				bar:SetValue(7000)
				tip.bar = bar
				tip.barOutline = U.outlined(bar, "chat")
			end
			tip.label = U.gameLook(tip.frame, "TOPLEFT", tip.frame, "BOTTOMLEFT", 0, -2)
			S.tips[i] = tip
		end
		return S
	end

	-- The lines of a tooltip: { text, colour }, with the rare line and the extra lines the settings add.
	local function Lines(def)
		local list = {}
		for _, line in ipairs(def.lines) do
			list[#list + 1] = line
		end
		if def.unit == "mob" and ns.Get("chat.enabled") == true and ns.Get("chat.tooltips") == true and ns.Get("chat.kindWord") then
			list[#list + 1] = { ns.KINDS.rareelite.word, ns.KINDS.rareelite.colour }
		end
		if def.id == "item" and ns.Get("chat.enabled") == true then
			if ns.Get("chat.ids") then
				list[#list + 1] = { "Item ID: 873", GREY }
			end
			if ns.Get("chat.count") then
				list[#list + 1] = { "Count: 3 in bags", GREY }
			end
		end
		return list
	end

	-- The colour of the border a tooltip takes from what it shows, or nothing for the plain border.
	local function Border(def)
		if def.id == "item" then
			return ns.Get("chat.quality") and def.colour or nil
		end
		local mode = ns.Get("chat.unitBorder")
		if def.unit == "mob" then
			if mode ~= "plain" then
				return def.colour
			end
			return ns.Get("chat.kindBorder") and ns.KINDS.rareelite.colour or nil
		end
		if mode == "class" then
			return def.mine
		elseif mode == "reaction" then
			return U.WHITE
		end
		return nil
	end

	local function Draw(stage)
		local S = instances[stage]
		if not S then
			return
		end
		local mod = ns.Get("chat.enabled") == true
		local on = mod and ns.Get("chat.tooltips") == true
		local share = mod and ns.Get("chat.tipScale") / 100 or 1
		local titleSize = TITLE * (mod and ns.Get("chat.tipTitleSize") / 100 or 1) * share
		local textSize = TEXT * (mod and ns.Get("chat.tipTextSize") / 100 or 1) * share
		local width = WIDTH * share * math.max(1, mod and ns.Get("chat.tipTitleSize") / 100 or 1, mod and ns.Get("chat.tipTextSize") / 100 or 1)
		local pad = PAD * share
		local colour = ns.TipColours[ns.Get("chat.tipBackground")] or ns.TipColours.nearblack
		local top, bottom = ns.TipShades(colour, ns.Get("chat.tipShading"))
		local x, high = 0, 0
		for _, tip in ipairs(S.tips) do
			local def = tip.def
			local list = Lines(def)
			local bar = tip.bar
			local barOn = bar and not (mod and ns.Get("chat.barHide") == true)
			local barHeight = (mod and ns.Get("chat.barHeight") or 8) * share
			local height = pad * 2 + titleSize + 4 * share + #list * (textSize + 3 * share) + (barOn and (barHeight + 6 * share) or 0)
			tip.frame:SetSize(width, height)
			U.at(tip.frame, "BOTTOMLEFT", S.root, "BOTTOMLEFT", x, LABEL)
			x = x + width + GAP
			high = math.max(high, height)
			-- The box: the chosen colour, opacity and shading and the thin border, or the game's plain plate.
			ns.SetOutlineFill(tip.outline, colour[1], colour[2], colour[3], ns.Get("chat.tipOpacity") / 100)
			ns.SetOutlineShade(tip.outline, top, bottom)
			local r, g, b
			if on then
				local border = Border(def)
				if border then
					r, g, b = border[1], border[2], border[3]
				end
			end
			ns.SetOutlineColour(tip.outline, r, g, b)
			ns.SetOutline(tip.outline, on, on)
			U.artShow(tip.art, not on, { 0.06, 0.06, 0.12, 0.9 }, { 0.5, 0.5, 0.6 })
			U.repaint(tip.outline)
			U.gameLookShow(tip.label, not on)
			-- The title, in the class colour when the row says so, and the lines.
			local name = def.colour
			if def.unit == "player" then
				name = (mod and ns.Get("chat.nameClass") == true) and def.mine or U.WHITE
			end
			tip.title:SetText(def.title)
			U.font(tip.title, U.FRIZ, titleSize, "", true, name)
			U.at(tip.title, "TOPLEFT", tip.frame, "TOPLEFT", pad, -pad)
			for n, fs in ipairs(tip.lines) do
				local line = list[n]
				fs:SetShown(line ~= nil)
				if line then
					fs:SetText(line[1])
					U.font(fs, U.FRIZ, textSize, "", true, line[2])
					U.at(fs, "TOPLEFT", tip.frame, "TOPLEFT", pad, -(pad + titleSize + 4 * share + (n - 1) * (textSize + 3 * share)))
				end
			end
			-- The health bar of a unit: the game's fill, or the flat one in the chosen texture, with a thin border.
			if bar then
				bar:SetShown(barOn)
				bar:SetSize(width - pad * 2, barHeight)
				U.at(bar, "BOTTOMLEFT", tip.frame, "BOTTOMLEFT", pad, pad)
				local health = mod and ns.Get("chat.health") == true
				if health then
					ns.FlatFill(bar, 1, 1, 1, BAR_FILE, true)
				else
					ns.RestoreFill(bar)
				end
				bar:SetStatusBarColor(def.health[1], def.health[2], def.health[3])
				ns.SetOutline(tip.barOutline, health and barOn, health and barOn)
				U.repaint(tip.barOutline)
			end
		end
		S.root:SetSize(math.max(x - GAP, 1), math.max(high + LABEL, 1))
	end

	local drawing = { draw = Draw, parts = {} }
	drawing.build = function(stage)
		local S = Build(stage)
		local p = drawing.parts
		local item, mob, player = S.tips[1], S.tips[2], S.tips[3]
		p.item, p.unit, p.player = item.frame, mob.frame, player.frame
		for _, key in ipairs({ "enabled", "tooltips", "tipBackground", "tipOpacity", "tipShading", "tipOwn", "tipBorder", "tipScale" }) do
			p["chat." .. key] = key == "tipScale" and S.root or item.frame
		end
		p["chat.quality"] = item.frame
		p["chat.kindWord"], p["chat.kindBorder"], p["chat.unitBorder"] = mob.frame, mob.frame, mob.frame
		p["chat.nameClass"] = player.title
		p["chat.tipTitleSize"], p["chat.tipTextSize"] = item.title, item.lines[1]
		p["chat.health"], p["chat.barHide"], p["chat.barHeight"] = mob.bar, mob.bar, mob.bar
		p["chat.ids"], p["chat.count"] = item.lines[4], item.lines[5]
		return S
	end
	ns.SetupDrawings["mock-tooltip"] = drawing
end

-- Combat text ---------------------------------------------------------------------------------------------------------------------

do
	local instances = setmetatable({}, { __mode = "k" })
	local SHAPE = ns.CombatShape
	local WIDE, HIGH, PLATE_X, PLATE_Y, OWN_X = 560, 204, 150, 44, 440
	-- The age a Burst critical hit is drawn at: 0.03 s, 2.06 times its settled height.
	local BURST_AGE = 0.03
	-- Over an enemy, in the order they appeared: the text, the kind of hit the game reports, the school of magic mask, whether it is a
	-- healing number, and how long ago it showed. The last is a critical hit still in its pop.
	local ENEMY = {
		{ text = "412", school = 1, age = 1.3 },
		{ text = "412", flag = "GLANCING", school = 1, age = 1.05 },
		{ text = "215", heal = true, age = 0.8 },
		{ text = "510", school = 4, age = 0.6 },
		{ text = "Dodge", word = true, age = 0.4 },
		{ text = "824", flag = "CRITICAL", school = 1, crit = true, age = 0.12 },
	}
	-- For the player, as the module's own samples: the report, the text with its sign, whether it is a critical hit, whether it shows
	-- from Damage and healing you take, the colour, and whether it starts a few units to one side.
	local OWN = {
		{ text = "-412", level = "take", colour = { 1, 0.1, 0.1 }, side = true },
		{ text = "-824", level = "take", colour = { 1, 0.1, 0.1 }, crit = true },
		{ text = "+300", level = "take", colour = { 0.1, 1, 0.1 } },
		{ text = "Dodge", level = "more", colour = { 1, 1, 1 }, side = true, word = true },
		{ text = "+20", level = "more", colour = { 0.41, 0.8, 0.94 } },
	}
	-- Where the sample numbers for the player start, and how far the mock Incoming area reaches.
	local OWN_TOP, OWN_LENGTH = 150, 120
	-- Over a friendly unit: the number, what it is, and how long ago it showed. The healing you do shows on the target plate alone.
	local FRIEND = {
		{ text = "350", kind = "damage", age = 1, school = 1 },
		{ text = "520", kind = "heal", age = 0.7 },
		{ text = "60", kind = "damage", pet = true, age = 0.45, school = 4 },
		{ text = "Miss", kind = "word", age = 0.25 },
	}
	local FRIEND_X, FRIEND_FRAME_Y, FRIEND_PLATE_Y = 330, 150, 44

	local function Build(stage)
		local S = { enemy = {}, own = {} }
		instances[stage] = S
		S.root = U.frame(stage, WIDE, HIGH)
		S.root:SetPoint("CENTER", stage, "CENTER", 0, 0)
		S.root:SetClipsChildren(true)
		-- A nameplate: the name and a health bar at 70 percent.
		S.plate = U.frame(S.root, 120, 30)
		S.plate:SetPoint("CENTER", S.root, "BOTTOMLEFT", PLATE_X, PLATE_Y)
		S.plateName = U.text(S.plate)
		S.plateName:SetPoint("TOP", S.plate, "TOP", 0, 0)
		S.plateName:SetText("Defias Pillager")
		U.font(S.plateName, U.FRIZ, 10, "", true, U.WHITE)
		S.bar = U.frame(S.plate, 120, 10)
		S.bar:SetPoint("BOTTOM", S.plate, "BOTTOM", 0, 0)
		S.barOutline = U.outlined(S.bar, "nameplates")
		S.barBack = U.tex(S.bar, "BACKGROUND", -6)
		S.barBack:SetAllPoints(S.bar)
		S.barBack:SetColorTexture(0.06, 0.06, 0.06, 1)
		S.barFill = U.tex(S.bar, "ARTWORK", 0)
		S.barFill:SetPoint("TOPLEFT", S.bar, "TOPLEFT", 0, 0)
		S.barFill:SetPoint("BOTTOMLEFT", S.bar, "BOTTOMLEFT", 0, 0)
		S.barFill:SetWidth(84)
		S.barFill:SetColorTexture(0.8, 0.18, 0.18, 1)
		-- The numbers are on frames of their own, above the plate or under it.
		S.front = U.frame(S.root, 1, 1)
		S.front:SetPoint("BOTTOMLEFT", S.root, "BOTTOMLEFT", 0, 0)
		for i = 1, #ENEMY do
			S.enemy[i] = U.text(S.front)
			S.enemy[i]:SetWordWrap(false)
		end
		for i = 1, #OWN do
			S.own[i] = U.text(S.front)
			S.own[i]:SetWordWrap(false)
		end
		-- Two friendly units, a party frame and a friendly plate, each with its own numbers.
		S.friends = {}
		for index, spec in ipairs({ { "frames", FRIEND_FRAME_Y, 100, 30 }, { "plates", FRIEND_PLATE_Y, 100, 12 } }) do
			local unit = { where = spec[1], frame = U.frame(S.root, spec[3], spec[4]), numbers = {} }
			unit.frame:SetPoint("CENTER", S.root, "BOTTOMLEFT", FRIEND_X, spec[2])
			unit.art = U.art(unit.frame)
			U.artShow(unit.art, true, { 0.06, 0.06, 0.06, 1 }, { 0.3, 0.3, 0.3 })
			for i = 1, #FRIEND do
				unit.numbers[i] = U.text(S.front)
				unit.numbers[i]:SetWordWrap(false)
			end
			S.friends[index] = unit
		end
		return S
	end

	-- The height a sample number settles at, and the height it has this long after it showed.
	local function Height(base, crit, age, pops, burst)
		local settle = base * (crit and SHAPE.pop.crit or 1)
		if burst and crit then
			return (ns.CombatBurstHeight(settle, age))
		end
		if not pops then
			return settle
		end
		return (ns.CombatPopHeight(settle, base * (crit and SHAPE.pop.critPeak or SHAPE.pop.peak), age))
	end

	local function Alpha(age, fade, life)
		if age <= fade then
			return 1
		end
		return math.max(0, 1 - (age - fade) / (life - fade))
	end

	local function Draw(stage)
		local S = instances[stage]
		if not S then
			return
		end
		local font, outline, shadow = ns.Get("combattext.font"), ns.Get("combattext.outline"), ns.Get("combattext.shadow") == true
		local file, flags = ns.CombatFont(font, outline)
		local pops = ns.Get("combattext.pop") == "pop"
		local rise, size = ns.Get("combattext.height") - SHAPE.heightGame, ns.Get("combattext.size") / 100
		local movement, loose, higher = ns.Get("combattext.movement"), ns.Get("combattext.spread") == "loose", ns.Get("combattext.crit") == "higher"
		local word, bySchool = ns.Get("combattext.partial") == "word", ns.Get("combattext.school") == true
		local kinds = ns.Get("combattext.partial") == "smaller"
		-- As the game has them: the enemy numbers are the game's own, in its face and colours. Only the height, size, spread and movement reach
		-- them (CombatText.lua:172-205), so the font, outline, shadow, kind of hit and school colours are for the numbers over you alone.
		local game = ns.Get("combattext.source") == "game"
		local enemyFile, enemyFlags, enemyShadow = file, flags, shadow
		if game then
			enemyFile, enemyFlags = ns.CombatFont("friz", "none")
			enemyShadow, word, bySchool, kinds = true, false, false, false
		end
		-- Classic: the numbers move and stack the way the module's do (the game's own numbers are not Classic). The sample numbers are placed
		-- by ns.CombatClassicStart in the order they appeared, as the module places a number when its hit report comes.
		local chosen = ns.Get("combattext.style") == "classic"
		local classic = chosen and not game
		local cls = SHAPE.classic
		local signs = ns.Get("combattext.classicSigns") == true
		local palette = classic and ns.Get("combattext.classicColour") or nil
		local life = cls.life * (ns.Get("combattext.classicTime") or 100) / 100
		local fade = life * cls.fadeFrom
		local risen = ns.Get("combattext.classicRise") or 100
		S.front:SetFrameLevel(S.plate:GetFrameLevel() + (game and -1 or 3))
		ns.SetOutline(S.barOutline, true, true)
		U.repaint(S.barOutline)
		-- Over the enemy: each number sits on the centre of the plate, a lane to the side, the height above it, and has moved as far as its age.
		-- The lane and the row of each sample are the ones Keep apart gives, the samples taken in the order they appeared with the age each had
		-- when the next one showed.
		local grow = ns.CombatGrow(SHAPE.text * size)
		local lanes = ns.CombatLanes(loose and ns.Get("combattext.spreadWidth") or 0, grow)
		local apart, rows = ns.Get("combattext.overlap") == "apart", ns.Get("combattext.rows")
		local placed = {}
		for i, sample in ipairs(ENEMY) do
			local fs = S.enemy[i]
			local move = ns.CombatMove(movement, sample.crit and not game and not classic and pops)
			-- A Burst critical hit is drawn young enough for the slam to show.
			local age = move == "burst" and BURST_AGE or sample.age
			local settle = Height(SHAPE.text * size, sample.crit, age, false)
			local turn = (i - 1) % #lanes + 1
			local wide = 3 * settle
			local lane, up = lanes[turn], 0
			local item = { lane = lane, drift = ns.CombatDrift(lane, grow), grow = grow, movement = move }
			if apart and not classic then
				fs:SetText(sample.text)
				U.font(fs, enemyFile, settle, enemyFlags, enemyShadow, { 1, 1, 1 })
				local ok, measured = pcall(fs.GetStringWidth, fs)
				wide = ok and type(measured) == "number" and measured > 0 and measured or wide
				local olds = {}
				for j, before in ipairs(placed) do
					olds[j] = { x = before.x, y = before.y, w = before.w, h = before.h, age = ENEMY[j].age - age, lane = before.lane,
						drift = before.drift, grow = grow, movement = ns.CombatMove(movement, ENEMY[j].crit and not game and not classic and pops) }
				end
				lane, up = ns.CombatChoose(olds, { lanes = lanes, turn = turn, w = wide, h = settle, rows = rows, y0 = rise, grow = grow, movement = move })
				item.lane, item.drift = lane, ns.CombatDrift(lane, grow)
			end
			placed[i] = { x = lane, y = rise + up, w = wide, h = settle, lane = item.lane, drift = item.drift }
			local dx, dy = ns.CombatOffsets(item, age)
			local text = sample.text
			if sample.word and not game then
				text = ns.CombatParen(text)
			end
			if word and sample.flag == "GLANCING" then
				text = text .. " (Glancing)"
			end
			if classic and signs and not sample.word then
				text = (sample.heal and "+" or "-") .. text
			end
			local r, g, b = 1, 1, 1
			if sample.heal then
				r, g, b = 0, 1, 0
				if palette == "game" then
					r, g, b = cls.game.heal[1], cls.game.heal[2], cls.game.heal[3]
				end
			elseif sample.school then
				r, g, b = ns.CombatColour(sample.school, bySchool, palette)
			end
			local base = SHAPE.text * size * ((kinds and sample.flag == "GLANCING") and cls.kinds.glancing or 1)
			fs:SetText(text)
			U.font(fs, enemyFile, Height(base, sample.crit, age, classic and sample.crit == true or (not classic and pops and not game), move == "burst"), enemyFlags, enemyShadow, { r, g, b })
			if classic then
				fs:SetAlpha(Alpha(sample.age, fade, life))
				placed[i] = { base = base, settle = base * (sample.crit and SHAPE.pop.crit or 1) }
			else
				fs:SetAlpha(Alpha(age, SHAPE.fade, SHAPE.life))
				U.at(fs, "CENTER", S.plate, "CENTER", lane + dx, math.min(rise + up + ((sample.crit and higher) and SHAPE.critLift or 0) + dy, HIGH - PLATE_Y - settle / 2))
			end
		end
		if classic then
			local lines, holds = ns.Get("combattext.rows") or 4, ns.Get("combattext.classicCrit") == true
			local down, wide = ns.Get("combattext.classicStack") == "down", (ns.Get("combattext.spreadWidth") or 100) / 100
			local mates = {}
			for i, sample in ipairs(ENEMY) do
				local entry = placed[i]
				local spot = rise + ((sample.crit and higher) and SHAPE.critLift or 0)
				local column, y = ns.CombatClassicStart(mates, { spot = spot, settle = entry.settle, base = entry.base, lines = lines, tight = not loose, down = down,
					crit = sample.crit, now = -sample.age })
				mates[#mates + 1] = { movement = (sample.crit and holds) and "hold" or "classic", classic = column, y = y, settle = entry.settle, start = -sample.age,
					life = life, rise = risen * ns.CombatGrow(entry.base), x = column * cls.side * entry.base / SHAPE.text * wide, text = S.enemy[i] }
			end
			for _, mate in ipairs(mates) do
				local _, dy = ns.CombatOffsets(mate, -mate.start)
				U.at(mate.text, "CENTER", S.plate, "CENTER", mate.x, mate.y + dy)
			end
		end
		-- Over friendly units: on the party frame, the friendly plate or both, every unit or the target (the plate) only.
		local where, units = ns.Get("combattext.friend"), ns.Get("combattext.friendUnits")
		local healing, signs, pets, words = ns.Get("combattext.friendHeal"), ns.Get("combattext.friendSigns") == true, ns.Get("combattext.friendPet") == true, ns.Get("combattext.friendWords") == true
		local fsize, lift = ns.Get("combattext.friendSize") / 100, ns.Get("combattext.friendHeight")
		for _, unit in ipairs(S.friends) do
			local unitShown = (where == unit.where or where == "both") and (units == "all" or unit.where == "plates")
			unit.frame:SetShown(true)
			for i, sample in ipairs(FRIEND) do
				local fs = unit.numbers[i]
				local shown = unitShown
				if sample.kind == "damage" then
					shown = shown and ns.Get("combattext.friendDamage") == true and (pets or not sample.pet)
				elseif sample.kind == "heal" then
					shown = shown and healing ~= "off" and (healing == "taken" or unit.where == "plates")
				else
					shown = shown and words
				end
				fs:SetShown(shown)
				if shown then
					local text = sample.kind == "word" and ns.CombatParen(sample.text) or sample.text
					local r, g, b = 1, 1, 1
					if sample.kind == "damage" then
						text = (signs and "-" or "") .. text
						if bySchool then
							r, g, b = ns.CombatColour(sample.school, true)
						else
							r, g, b = ns.Colour("combattext.friendDamageColour")
						end
					elseif sample.kind == "heal" then
						text = (signs and "+" or "") .. (healing == "done" and "280" or text)
						r, g, b = ns.Colour("combattext.friendHealColour")
					end
					fs:SetText(text)
					local dx, dy = ns.CombatOffsets({ lane = 0, movement = ns.CombatMove(movement, false) }, sample.age)
					if chosen then
						dx, dy = ns.CombatOffsets({ movement = "classic", rise = risen * math.max(1, SHAPE.text * fsize / cls.ref), life = life }, sample.age)
					end
					U.font(fs, file, Height(SHAPE.text * fsize, false, sample.age, pops and not chosen), flags, shadow, { r, g, b })
					fs:SetAlpha(chosen and Alpha(sample.age, fade, life) or Alpha(sample.age, SHAPE.fade, SHAPE.life))
					U.at(fs, "CENTER", unit.frame, "CENTER", dx + (i - 2.5) * 14, dy + (unit.where == "frames" and lift or 0))
				end
			end
		end
		-- Over the character: the numbers of the Incoming scroll area, each one line behind the one before when that has not moved a line, or
		-- in a row of its own for Horizontal and Static, and moved by Incoming style.
		local level, style, scroll = ns.Get("combattext.own"), ns.Get("combattext.inStyle"), SHAPE.scroll
		local ownSize = ns.Get("combattext.ownSize") / 100
		local life = style == "static" and scroll.still or scroll.life[ns.Get("combattext.speed")] or scroll.life.normal
		local hold = style == "static" and scroll.stillHold or scroll.hold
		local snapshot = 0.25 * (#OWN - 1) + 0.1
		local lastStart, lastRy
		for i, sample in ipairs(OWN) do
			local fs = S.own[i]
			local shown = level == "more" or (level == "take" and sample.level == "take")
			fs:SetShown(shown)
			local base = SHAPE.text * ownSize
			local line = base * (sample.crit and scroll.crit or 1) * scroll.line
			local start = 0.25 * (i - 1)
			local ry = -(i - 1) * line
			if style == "straight" or style == "arc" then
				local ahead = lastStart and (OWN_LENGTH * (start - lastStart) / life - lastRy) or line
				ry = ahead < line and (line - ahead) or 0
			end
			lastStart, lastRy = start, ry
			if shown then
				local age = snapshot - start
				local u = age / life
				local dx, dy = ns.ScrollPath(style, u, OWN_LENGTH, -1, -1, scroll.arcs[ns.Get("combattext.arcWidth")])
				fs:SetText(sample.word and ns.CombatParen(sample.text) or sample.text)
				U.font(fs, file, Height(base, sample.crit, age, pops), flags, shadow, sample.colour)
				fs:SetAlpha(ns.ScrollAlpha(u, hold))
				U.at(fs, "CENTER", S.root, "BOTTOMLEFT", OWN_X + dx, OWN_TOP + ry + dy)
			end
		end
	end

	local drawing = { draw = Draw, parts = {} }
	drawing.build = function(stage)
		local S = Build(stage)
		local p = drawing.parts
		p.enemy, p.own, p.plate = S.enemy[1], S.own[1], S.plate
		for _, key in ipairs({ "font", "outline", "shadow", "pop", "size", "spread", "movement", "partial", "school", "style", "classicColour", "classicSigns",
			"classicRise", "classicTime", "classicStack" }) do
			p["combattext." .. key] = S.enemy[1]
		end
		p["combattext.height"], p["combattext.crit"], p["combattext.classicCrit"] = S.enemy[6], S.enemy[6], S.enemy[6]
		p["combattext.inStyle"], p["combattext.ownSize"], p["combattext.arcWidth"] = S.own[1], S.own[1], S.own[1]
		p["combattext.missWords"] = S.enemy[5]
		for _, key in ipairs({ "friend", "friendUnits", "friendDamage", "friendHeal", "friendPet", "friendWords", "friendSigns", "friendDamageColour", "friendHealColour", "friendSize", "friendHeight" }) do
			p["combattext." .. key] = S.friends[key == "friendHeight" and 1 or 2].frame
		end
		return S
	end
	ns.SetupDrawings["mock-combat-text"] = drawing
end
