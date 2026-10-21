local _, ns = ...

-- The drawings of Flat UI setup: what a choice looks like, drawn on frames of the addon's own from the settings a module would read. They read through
-- ns.Get, so the caller runs a drawing inside ns.Viewing with the draft, and a border, a fill, a colour or a texture in a drawing is the one the
-- addon puts on the game's frames. The numbers are fixed samples: the game withholds a unit's health, power and cast times (UnitDocumentation.lua:1526-1529).
-- A drawing is { frame, regions, draw, parts, mark }: its frame holds its parts, regions lists every texture and text it made, draw paints them all again,
-- and parts says which region a setting changes (hovering the row of the setting marks it). A file of drawings (SetupDraw<Area>.lua) registers
-- ns.SetupDrawings["<id>"] = { build(stage), draw(stage), parts = { [path] = region }, partsOf(stage) }; Adapt makes a drawing of the framework from it.

local kit = ns.PanelKit

local D = { drawings = {}, failed = {} }
ns.SetupDraw = D

local STAGE_W, STAGE_H = 658, 204

-- Colours the drawings use where the game or a setting does not give one.
local REACTION = { hostile = { 0.77, 0.23, 0.23 }, neutral = { 0.88, 0.77, 0.29 }, friendly = { 0.24, 0.77, 0.35 }, tapped = { 0.54, 0.54, 0.54 } }
local POWER = { MANA = { 0.18, 0.44, 0.88 }, RAGE = { 0.82, 0.18, 0.18 }, ENERGY = { 0.88, 0.82, 0.18 }, FOCUS = { 0.88, 0.5, 0.25 }, RUNIC_POWER = { 0.1, 0.8, 0.95 } }
local SAMPLE_HEALTH, SAMPLE_POWER = 0.7, 0.7

-- The name of the player, or the sample name when the client does not say.
local function PlayerName()
	if type(UnitName) == "function" then
		local ok, name = pcall(UnitName, "player")
		if ok and not ns.IsSecret(name) and type(name) == "string" and name ~= "" then
			return name
		end
	end
	return "Brennan"
end

-- A texture or a text of a drawing, kept in the drawing's list.
local function Texture(drawing, parent, layer)
	local texture = kit.Fill(parent, layer)
	drawing.regions[#drawing.regions + 1] = texture
	return texture
end

local function Text(drawing, parent, font, justify, width)
	local text = kit.Label(parent, font or "GameFontHighlightSmall", justify, width)
	drawing.regions[#drawing.regions + 1] = text
	return text
end

-- A bar: a black back and a fill. It is a pair of textures and not a status bar, since nothing here is a unit's. Set it with D.SetBar.
local function NewBar(drawing, parent, width, height)
	local bar = kit.Frame(parent)
	bar:SetSize(width, height)
	local back = Texture(drawing, bar, "BACKGROUND")
	back:SetAllPoints(bar)
	back:SetColorTexture(0, 0, 0, 1)
	local fill = Texture(drawing, bar, "ARTWORK")
	fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	return { frame = bar, fill = fill, width = width }
end

-- Fills a bar to a share of its width in a colour, with the bar texture the settings choose (a solid colour for Flat, else the image file tinted).
function D.SetBar(bar, share, r, g, b)
	local file = ns.BarTexture()
	local fill = bar.fill
	fill:SetWidth(math.max(0.01, bar.width * share))
	if file then
		fill:SetTexture(file)
		fill:SetVertexColor(r, g, b, 1)
		fill:SetTexCoord(0, share, 0, 1)
	else
		fill:SetColorTexture(r, g, b, 1)
		fill:SetVertexColor(1, 1, 1, 1)
		fill:SetTexCoord(0, 1, 0, 1)
	end
end

local function Power(token)
	local r, g, b = ns.PowerColour(token)
	if r then
		return r, g, b
	end
	local sample = POWER[token]
	return sample[1], sample[2], sample[3]
end

-- A panel with the general border and background and a health and a power bar in it. The outline is the one the modules make, and follows the view.
local function Panel(drawing, parent, width)
	local panel = kit.Frame(parent)
	panel:SetSize(width, 82)
	drawing.outline = ns.Outline(panel, panel, false)
	ns.SetOutlineView(drawing.outline, D.view)
	local name = Text(drawing, panel, "GameFontHighlight", "LEFT", width - 24)
	name:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
	local health = NewBar(drawing, panel, width - 24, 14)
	health.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -32)
	local power = NewBar(drawing, panel, width - 24, 8)
	power.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -52)
	local function Draw()
		ns.RepaintOutline(drawing.outline)
		name:SetText(PlayerName())
		D.SetBar(health, SAMPLE_HEALTH, ns.HealthLeftColour(SAMPLE_HEALTH))
		D.SetBar(power, SAMPLE_POWER, Power("MANA"))
	end
	return panel, Draw
end

-- Drawings ---------------------------------------------------------------------------------------

-- A panel with a border, a background and a bar.
local function BuildPanel(drawing)
	local panel, draw = Panel(drawing, drawing.frame, 300)
	panel:SetPoint("CENTER", drawing.frame, "CENTER", 0, 0)
	drawing.draw = draw
end

-- The groups of the bars drawing: the title, the rows { label, share, colour function }, the place.
local function Groups()
	local function Cast(label, share, path)
		return { label, share, function() return ns.Colour(path) end }
	end
	local function Reaction(label, key, row)
		return { label, 1, function()
			if ns.Get("general.reactionOwn") == true then
				return ns.Colour("general." .. row)
			end
			local sample = REACTION[key]
			return sample[1], sample[2], sample[3]
		end }
	end
	local function Mana(label, token)
		return { label, SAMPLE_POWER, function() return Power(token) end }
	end
	local function Health(share)
		return { ("%d%%"):format(share * 100), share, function() return ns.HealthLeftColour(share) end }
	end
	return {
		{ "Health", 0, 0, { Health(1), Health(0.7), Health(0.4), Health(0.15) } },
		{ "Cast bar", 330, 0, { Cast("Cast", 0.6, "castbars.castColour"), Cast("Channel", 0.4, "castbars.channelColour"),
			Cast("Locked", 0.6, "castbars.shieldColour"), Cast("Broken", 1, "castbars.interruptedColour"), Cast("Craft", 0.5, "castbars.craftColour") } },
		{ "Reaction", 0, 100, { Reaction("Hostile", "hostile", "reactionHostile"), Reaction("Neutral", "neutral", "reactionNeutral"),
			Reaction("Friendly", "friendly", "reactionFriendly"), Reaction("Tapped", "tapped", "reactionTapped") } },
		{ "Power", 330, 100, { Mana("Mana", "MANA"), Mana("Rage", "RAGE"), Mana("Energy", "ENERGY"), Mana("Focus", "FOCUS"), Mana("Runic", "RUNIC_POWER") } },
	}
end

-- A health bar, a cast bar, the reaction and power colours: every bar of the Look steps on the chosen texture.
local function BuildBars(drawing)
	local groups = Groups()
	local bars = {}
	for _, group in ipairs(groups) do
		local title = Text(drawing, drawing.frame, "GameFontHighlightSmall", "LEFT", 200)
		kit.Dim(title)
		title:SetPoint("TOPLEFT", drawing.frame, "TOPLEFT", group[2], -group[3])
		title:SetText(group[1])
		for index, row in ipairs(group[4]) do
			local label = Text(drawing, drawing.frame, "GameFontHighlightSmall", "LEFT", 60)
			label:SetPoint("TOPLEFT", drawing.frame, "TOPLEFT", group[2], -(group[3] + 4 + index * 14))
			label:SetText(row[1])
			local bar = NewBar(drawing, drawing.frame, 250, 9)
			bar.frame:SetPoint("TOPLEFT", drawing.frame, "TOPLEFT", group[2] + 66, -(group[3] + 6 + index * 14))
			bars[#bars + 1] = { bar = bar, row = row }
		end
	end
	function drawing.draw()
		for _, entry in ipairs(bars) do
			local r, g, b = entry.row[3]()
			D.SetBar(entry.bar, entry.row[2], r, g, b)
		end
	end
end

-- The look of the profile being made: the panel, and three bars beside it.
local function BuildStart(drawing)
	local panel, draw = Panel(drawing, drawing.frame, 280)
	panel:SetPoint("LEFT", drawing.frame, "LEFT", 40, 0)
	local rows = {
		{ "Health", SAMPLE_HEALTH, function() return ns.HealthLeftColour(SAMPLE_HEALTH) end },
		{ "Power", SAMPLE_POWER, function() return Power("MANA") end },
		{ "Cast", 0.6, function() return ns.Colour("castbars.castColour") end },
	}
	local bars = {}
	for index, row in ipairs(rows) do
		local label = Text(drawing, drawing.frame, "GameFontHighlightSmall", "LEFT", 50)
		label:SetPoint("LEFT", drawing.frame, "LEFT", 360, 34 - (index - 1) * 28)
		label:SetText(row[1])
		local bar = NewBar(drawing, drawing.frame, 200, 12)
		bar.frame:SetPoint("LEFT", drawing.frame, "LEFT", 414, 34 - (index - 1) * 28)
		bars[index] = { bar = bar, row = row }
	end
	function drawing.draw()
		draw()
		for _, entry in ipairs(bars) do
			local r, g, b = entry.row[3]()
			D.SetBar(entry.bar, entry.row[2], r, g, b)
		end
	end
end

-- Pictures of a ready-made profile ----------------------------------------------------------------

-- A card is a 336 by 112 scene of one profile: a player frame with a cast bar, a party column, two nameplates, a combat number and two rows of action
-- buttons. D.Card makes it from the settings of the view it is given (ns.Viewing), never from the profile in use, and shows the settings that tell the
-- profiles apart. The caller scales the frame (0.595 on the setup panel). Its outlines are pixels whatever the scale (ns.Outline, not direct).
local CARD_W, CARD_H = 336, 112
local CURRENT, MISSING = "9,360", "2,640"
local FRIENDLY, GREY, PLAIN = REACTION.friendly, { 0.55, 0.55, 0.55 }, { 0.12, 0.12, 0.12 }
local BUTTON_COLOURS = { { 0.75, 0.35, 0.25 }, { 0.3, 0.5, 0.8 }, { 0.35, 0.7, 0.4 }, { 0.8, 0.7, 0.3 }, { 0.6, 0.4, 0.75 }, { 0.3, 0.7, 0.7 } }

-- The text of a health value in one of the formats of the health text rows, for the sample 9,360 of 12,000 (78%).
local function HealthText(style)
	if style == "pct" then
		return "78%"
	elseif style == "curpct" then
		return CURRENT .. " (78%)"
	elseif style == "miss" then
		return MISSING
	elseif style == "curmax" then
		return CURRENT .. " / 12,000"
	elseif style == "cur" or style == "game" then
		return CURRENT
	end
	return ""
end

-- A text in the size a setting gives (a share in percent): the font object nearest to it. The colour is set again, since a font object brings its own.
local function Sized(text, percent)
	local name = percent >= 150 and "GameFontNormalLarge" or percent >= 105 and "GameFontHighlight" or "GameFontHighlightSmall"
	pcall(text.SetFontObject, text, name)
	text:SetTextColor(0.92, 0.92, 0.92)
end

local function Resized(bar, width, height)
	bar.width = width
	bar.frame:SetSize(width, height)
end

function D.Card(parent, view)
	local card = { regions = {}, outlines = {}, view = view, parts = {} }
	local parts = card.parts
	local root = kit.Frame(parent)
	root:SetSize(CARD_W, CARD_H)
	card.frame = root
	local function Put(frame, owner, x, y)
		frame:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -y)
	end
	local function Boxed(width, height, x, y)
		local box = kit.Frame(root)
		box:SetSize(width, height)
		Put(box, root, x, y)
		local outline = ns.Outline(box, box, false)
		ns.SetOutlineView(outline, view)
		card.outlines[#card.outlines + 1] = outline
		return box, outline
	end
	local function Small(owner, justify, width)
		return Text(card, owner, "GameFontHighlightSmall", justify, width)
	end

	local player = Boxed(140, 44, 0, 0)
	local portrait = Texture(card, player, "ARTWORK")
	portrait:SetSize(16, 16)
	portrait:SetPoint("TOPLEFT", player, "TOPLEFT", 4, -4)
	portrait:SetColorTexture(0.45, 0.5, 0.6, 1)
	local name = Small(player, "LEFT", 100)
	local health = NewBar(card, player, 112, 10)
	local healthText = Small(health.frame, "CENTER", 112)
	healthText:SetPoint("CENTER", health.frame, "CENTER", 0, 0)
	local power = NewBar(card, player, 112, 5)
	local defensive = Texture(card, root, "ARTWORK")
	defensive:SetSize(16, 16)
	defensive:SetPoint("TOPLEFT", root, "TOPLEFT", 146, 0)
	defensive:SetColorTexture(0.3, 0.6, 0.9, 1)
	parts.player, parts.health, parts.healthText, parts.defensive, parts.portrait = player, health, healthText, defensive, portrait

	local castIcon = Texture(card, root, "ARTWORK")
	castIcon:SetColorTexture(0.85, 0.65, 0.3, 1)
	local cast = NewBar(card, root, 140, 8)
	local castText = Small(cast.frame, "LEFT", 90)
	castText:SetPoint("LEFT", cast.frame, "LEFT", 2, 0)
	parts.cast, parts.castIcon = cast, castIcon

	local party = {}
	for index = 1, 3 do
		local row = { picture = Texture(card, root, "ARTWORK"), bar = NewBar(card, root, 64, 12) }
		row.picture:SetSize(12, 12)
		row.picture:SetColorTexture(0.45, 0.5, 0.6, 1)
		row.text = Small(row.bar.frame, "CENTER", 64)
		row.text:SetPoint("CENTER", row.bar.frame, "CENTER", 0, 0)
		party[index] = row
	end
	parts.party = party

	local plates = {}
	for index = 1, 2 do
		local plate = { x = index == 1 and 170 or 260 }
		plate.frame = Boxed(76, 8, plate.x, 10)
		plate.bar = NewBar(card, plate.frame, 76, 8)
		plate.bar.frame:SetPoint("TOPLEFT", plate.frame, "TOPLEFT", 0, 0)
		plate.edge = Texture(card, plate.frame, "BACKGROUND")
		plate.edge:SetPoint("TOPLEFT", plate.frame, "TOPLEFT", -1, 1)
		plate.edge:SetPoint("BOTTOMRIGHT", plate.frame, "BOTTOMRIGHT", 1, -1)
		plate.edge:SetColorTexture(0.9, 0.1, 0.1, 1)
		plate.text = Small(plate.bar.frame, "CENTER", 76)
		plate.text:SetPoint("CENTER", plate.bar.frame, "CENTER", 0, 0)
		plate.auras = {}
		for slot = 1, 2 do
			local aura = Texture(card, root, "ARTWORK")
			aura:SetSize(6, 6)
			aura:SetColorTexture(slot == 1 and 0.3 or 0.8, slot == 1 and 0.7 or 0.5, slot == 1 and 0.4 or 0.2, 1)
			plate.auras[slot] = aura
		end
		plates[index] = plate
	end
	local level, levelOutline = Boxed(8, 8, 248, 10)
	local levelText = Small(level, "CENTER", 8)
	levelText:SetPoint("CENTER", level, "CENTER", 0, 0)
	levelText:SetText("60")
	local plateCast = NewBar(card, root, 76, 5)
	local plateCastTime = Small(plateCast.frame, "RIGHT", 40)
	plateCastTime:SetPoint("RIGHT", plateCast.frame, "RIGHT", -1, 0)
	local number = Text(card, root, "GameFontNormal", "LEFT", 80)
	number:SetPoint("TOPLEFT", root, "TOPLEFT", 172, -38)
	number:SetText("1,240")
	parts.plates, parts.plateCast, parts.plateCastTime, parts.number, parts.level = plates, plateCast, plateCastTime, number, level

	local rows = {}
	for index = 1, 2 do
		local row = { buttons = {}, keys = {} }
		row.frame = Boxed(130, 20, 170, index == 1 and 64 or 86)
		for slot = 1, 6 do
			row.buttons[slot] = Texture(card, row.frame, "ARTWORK")
			row.keys[slot] = Small(row.frame, "LEFT", 18)
		end
		row.name = Small(row.frame, "LEFT", 20)
		row.name:SetText("Heal")
		rows[index] = row
	end
	parts.rows = rows

	local function Shown(region, on)
		region:SetShown(on == true)
	end

	function card.draw()
		local get = ns.Get
		-- The player frame.
		local square = get("unitframes.squarePortrait") == true
		local pictured = square and get("unitframes.portraitPlayer") == true and get("unitframes.portraitStyle") ~= "none"
		local left = pictured and 24 or 4
		Shown(portrait, pictured)
		name:SetPoint("TOPLEFT", player, "TOPLEFT", left, -3)
		name:SetText(PlayerName())
		Sized(name, get("unitframes.nameSize"))
		health.frame:SetPoint("TOPLEFT", player, "TOPLEFT", left, -17)
		Resized(health, 136 - left, 10)
		healthText:SetWidth(136 - left)
		healthText:SetText(HealthText(get("unitframes.playerHealthText")))
		Sized(healthText, get("unitframes.healthTextSize"))
		local r, g, b = FRIENDLY[1], FRIENDLY[2], FRIENDLY[3]
		if get("unitframes.flat") == true and get("unitframes.healthByLeft") == true then
			r, g, b = ns.HealthLeftColour(0.78)
		end
		D.SetBar(health, 0.78, r, g, b)
		power.frame:SetPoint("TOPLEFT", player, "TOPLEFT", left, -31)
		Resized(power, 136 - left, 5)
		power.frame:SetShown(get("unitframes.playerPowerBar") == true)
		D.SetBar(power, 0.7, Power("MANA"))
		Shown(defensive, get("defensives.enabled") == true and get("defensives.own") == true)
		-- The player cast bar.
		local custom = get("castbars.playerSize") == true
		local width = (custom and get("castbars.playerWidth") or 208) * 140 / 208
		local height = (custom and get("castbars.playerHeight") or 11) * 140 / 208
		local icon = get("castbars.flat") == true and get("castbars.playerIcon") == true
		castIcon:SetSize(height, height)
		castIcon:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -50)
		Shown(castIcon, icon)
		cast.frame:SetPoint("TOPLEFT", root, "TOPLEFT", icon and height + 1 or 0, -50)
		Resized(cast, icon and width - height - 1 or width, height)
		castText:SetText("Fireball")
		Sized(castText, get("castbars.textSize"))
		D.SetBar(cast, 0.6, ns.Colour("castbars.castColour"))
		-- The party column.
		local on = get("unitframes.party") == true
		local pictureOn = square and get("unitframes.partyPicture") ~= "none"
		local shade = get("unitframes.partyRangeDim") == true and get("unitframes.partyRangeAlpha") / 100 or 1
		for index, row in ipairs(party) do
			local y = 70 + (index - 1) * 14
			row.picture:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
			Shown(row.picture, on and pictureOn)
			row.bar.frame:SetPoint("TOPLEFT", root, "TOPLEFT", pictureOn and 14 or 0, -y)
			row.bar.frame:SetShown(on)
			row.bar.frame:SetAlpha(index == 3 and shade or 1)
			row.picture:SetAlpha(index == 3 and shade or 1)
			row.text:SetText(HealthText(get("unitframes.partyHealthText")))
			Sized(row.text, get("unitframes.healthTextSize"))
			D.SetBar(row.bar, 0.78, r, g, b)
		end
		-- The nameplates: the target first.
		local barWidth, barHeight = 76 * get("nameplates.barWidth") / 100, 8 * get("nameplates.healthHeight") / 100
		local base = get("nameplates.colours") == true and REACTION.hostile or GREY
		local always = get("nameplates.aurasWhen") == "always"
		for index, plate in ipairs(plates) do
			plate.frame:SetSize(barWidth, barHeight)
			Resized(plate.bar, barWidth, barHeight)
			local pr, pg, pb = base[1], base[2], base[3]
			if index == 1 and get("nameplates.targetBar") == true then
				pr, pg, pb = math.min(1, pr + 0.18), math.min(1, pg + 0.18), math.min(1, pb + 0.18)
			elseif index == 2 and get("nameplates.threat") == true then
				pr, pg, pb = 0.95, 0.55, 0.15
			end
			D.SetBar(plate.bar, index == 1 and 0.75 or 0.35, pr, pg, pb)
			Shown(plate.edge, index == 2 and get("nameplates.lowHealth") == true)
			plate.text:SetText(index == 1 and "75%" or "35%")
			Shown(plate.text, get("nameplates.healthText") == true)
			for slot, aura in ipairs(plate.auras) do
				aura:SetPoint("TOPLEFT", root, "TOPLEFT", plate.x + (slot - 1) * 8, -1)
				Shown(aura, index == 1 or always)
			end
		end
		local boxed = get("nameplates.level") == "box"
		-- Thin border and Text only: a square the height of the bar, at the gap chosen.
		local square = get("nameplates.level") ~= "default" and get("nameplates.levelShape") == "square"
		level:SetSize(square and barHeight or 8, square and barHeight or 8)
		level:SetPoint("TOPLEFT", root, "TOPLEFT", 170 + barWidth + (square and get("nameplates.levelGap") or 2), -10)
		ns.SetOutline(levelOutline, boxed, boxed)
		Sized(levelText, get("nameplates.nameSize"))
		plateCast.frame:SetPoint("TOPLEFT", root, "TOPLEFT", 170, -(10 + barHeight + 2))
		Resized(plateCast, barWidth, 5 * get("nameplates.castHeight") / 100)
		D.SetBar(plateCast, 0.5, ns.Colour("castbars.castColour"))
		plateCastTime:SetText("0.8")
		Shown(plateCastTime, get("nameplates.castTime") == true)
		-- The combat number and the action buttons.
		number:SetText("1,240")
		Shown(number, get("combattext.enabled") == true)
		Sized(number, get("combattext.size"))
		local keyShow, nameShow = get("actionbars.hotkeyShow"), get("actionbars.nameShow")
		local side = get("fade.enabled") == true and get("fade.bar2") == true and get("fade.alpha") / 100 or 1
		local size = get("actionbars.square") == true and 20 or 18
		for index, row in ipairs(rows) do
			row.frame:SetAlpha(index == 2 and side or 1)
			local keys = keyShow == "all" or (index == 1 and keyShow == "main") or (index == 2 and keyShow == "side")
			for slot, button in ipairs(row.buttons) do
				local colour = BUTTON_COLOURS[slot]
				local empty = index == 2 and slot > 4
				local mode = get("actionbars.empty")
				button:SetSize(size, size)
				button:SetPoint("TOPLEFT", row.frame, "TOPLEFT", (slot - 1) * 22 + (20 - size) / 2, -(20 - size) / 2)
				if empty then
					button:SetColorTexture(PLAIN[1], PLAIN[2], PLAIN[3], mode == "faint" and 0.4 or 1)
					Shown(button, mode ~= "hidden")
				else
					button:SetColorTexture(colour[1], colour[2], colour[3], 1)
					button:Show()
				end
				local key = row.keys[slot]
				key:SetPoint("TOPLEFT", row.frame, "TOPLEFT", (slot - 1) * 22 + 2, -2)
				key:SetText(tostring(slot))
				Shown(key, keys and not (empty and mode == "hidden"))
				Sized(key, get("actionbars.hotkeySize"))
			end
			row.name:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 1, 1)
			Shown(row.name, nameShow == "all" or (index == 1 and nameShow == "main") or (index == 2 and nameShow == "side"))
			Sized(row.name, get("actionbars.nameSize"))
		end
	end

	-- Paints the card from its own view; a card that fails is reported once and the others still paint.
	function card.Paint()
		local ok, err = ns.Viewing(view, card.draw)
		if ok then
			for _, outline in ipairs(card.outlines) do
				ns.RepaintOutline(outline)
			end
			return true
		end
		if not card.reported then
			card.reported = true
			geterrorhandler()(err)
		end
		return false
	end
	return card
end

-- A view for a card: the values of a profile (a table of saved path to value, or a function that gives it), with no positions.
D.noSpots = {}
function D.CardView(valuesOf)
	return setmetatable({ spots = D.noSpots }, { __index = function(_, path)
		local values = type(valuesOf) == "function" and valuesOf() or valuesOf
		if type(values) == "table" then
			return values[path]
		end
		return nil
	end })
end

-- The values of a ready-made profile as Setup.lua checked them, else as the table has them.
function D.PresetValues(id)
	local setup = ns.Setup
	local list = setup and setup.Presets and setup.Presets() or ns.SETUP_PROFILES or {}
	for _, profile in ipairs(list) do
		if profile.id == id then
			return profile.values
		end
	end
	return nil
end

-- Which tile of mock-profiles has the accent edge and which has the tag, set by Setup before each paint.
D.cardMarks = {}

-- The edge of a tile that is not selected.
D.CARD_EDGE = { 0.4, 0.4, 0.4 }

-- The six cards on the stage, three to a row, each with its name: the drawing of New profile. A click on a tile goes to D.onCard(id). The selected tile
-- has the accent edge and the recommended one the tag.
local function BuildProfiles(drawing)
	drawing.cards, drawing.tiles = {}, {}
	for index, profile in ipairs(ns.SETUP_PROFILES or {}) do
		local tile = kit.Frame(drawing.frame)
		tile:SetSize(212, 98)
		tile:SetPoint("TOPLEFT", drawing.frame, "TOPLEFT", ((index - 1) % 3) * 223, -math.floor((index - 1) / 3) * 106)
		local edge = ns.Outline(tile, tile, true)
		-- One pixel, one grey, whatever look is being drafted.
		ns.SetOutlineThickness(edge, 1)
		kit.Painted(function()
			kit.Backing(edge, 0.05)
		end)
		local card = D.Card(tile, D.CardView(function()
			return D.PresetValues(profile.id)
		end))
		card.frame:SetScale(0.55)
		card.frame:SetPoint("TOP", tile, "TOP", 0, -3)
		local label = Text(drawing, tile, "GameFontNormal", "LEFT", 100)
		label:SetPoint("TOPLEFT", tile, "TOPLEFT", 13, -68)
		label:SetText(profile.label)
		local tag = kit.Accented(Text(drawing, tile, "GameFontHighlightSmall", "RIGHT", 90))
		tag:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -13, -70)
		tag:SetText("Recommended")
		kit.Clickable(tile, function()
			if D.onCard then
				D.onCard(profile.id)
			end
		end)
		drawing.cards[#drawing.cards + 1] = card
		drawing.tiles[#drawing.tiles + 1] = { id = profile.id, frame = tile, edge = edge, tag = tag }
	end
	function drawing.draw()
		local marks = D.cardMarks
		for _, tile in ipairs(drawing.tiles) do
			if marks.selected == tile.id then
				ns.SetOutlineColour(tile.edge, kit.Accent())
			else
				ns.SetOutlineColour(tile.edge, D.CARD_EDGE[1], D.CARD_EDGE[2], D.CARD_EDGE[3])
			end
			tile.tag:SetShown(marks.tag == tile.id)
		end
		for _, card in ipairs(drawing.cards) do
			card.Paint()
		end
	end
end

-- The picture of the profile being made, large: Review and the screen after Finish. It reads the view of the setup window.
local function BuildProfile(drawing)
	local card = D.Card(drawing.frame, D.view)
	card.frame:SetScale(1.8)
	card.frame:SetPoint("CENTER", drawing.frame, "CENTER", 0, 0)
	drawing.card = card
	function drawing.draw()
		card.Paint()
	end
end

local BUILDERS = { ["mock-panel"] = BuildPanel, ["mock-bars"] = BuildBars, ["mock-start"] = BuildStart, ["mock-profiles"] = BuildProfiles, ["mock-profile"] = BuildProfile }

-- Registered drawings ----------------------------------------------------------------------------

ns.SetupDrawings = ns.SetupDrawings or {}

-- Builds a registered drawing on the frame of a drawing of the framework. Every outline it makes follows the draft view (ns.SetOutlineView) and is painted
-- again after each draw (ns.RepaintOutline), so a file of drawings does not have to. A build that fails is reported and the drawing is not shown.
local function Adapt(drawing, registered)
	drawing.outlines = {}
	local made = ns.Outline
	ns.Outline = function(...)
		local outline = made(...)
		if outline and not drawing.outlines[outline] then
			drawing.outlines[outline] = true
			drawing.outlines[#drawing.outlines + 1] = outline
			ns.SetOutlineView(outline, D.view)
		end
		return outline
	end
	local ok, err = pcall(registered.build, drawing.frame)
	ns.Outline = made
	if not ok then
		geterrorhandler()(err)
		return false
	end
	-- A file that keeps one scene per stage gives the marks of this stage (partsOf); the others keep one table.
	local of = registered.partsOf
	drawing.parts = (type(of) == "function" and of(drawing.frame)) or registered.parts or {}
	function drawing.draw()
		registered.draw(drawing.frame)
		for _, outline in ipairs(drawing.outlines) do
			ns.RepaintOutline(outline)
		end
	end
	return true
end

-- The part marks: an accent bracket round the region a setting changes, shown while its row is hovered.
local function Bracket(drawing)
	local mark = kit.Frame(drawing.frame)
	mark:SetAllPoints(drawing.frame)
	mark:SetFrameLevel(drawing.frame:GetFrameLevel() + 30)
	mark.edges = {}
	for index = 1, 4 do
		mark.edges[index] = kit.Fill(mark, "OVERLAY")
	end
	mark:Hide()
	drawing.mark = mark
	return mark
end

-- Marks the region the setting `path` changes in the drawing that is shown, or clears the mark for nil or a setting with no part.
function D.Mark(path)
	local drawing = D.current
	if not drawing then
		return false
	end
	local region = path and drawing.parts and drawing.parts[path]
	if type(region) ~= "table" or type(region.SetPoint) ~= "function" then
		if drawing.mark then
			drawing.mark:Hide()
		end
		return false
	end
	local mark = drawing.mark or Bracket(drawing)
	local top, bottom, left, right = mark.edges[1], mark.edges[2], mark.edges[3], mark.edges[4]
	local r, g, b = kit.Accent()
	for _, edge in ipairs(mark.edges) do
		edge:ClearAllPoints()
		edge:SetColorTexture(r, g, b, 1)
	end
	top:SetPoint("BOTTOMLEFT", region, "TOPLEFT", -3, 1)
	top:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", 3, 1)
	top:SetHeight(2)
	bottom:SetPoint("TOPLEFT", region, "BOTTOMLEFT", -3, -1)
	bottom:SetPoint("TOPRIGHT", region, "BOTTOMRIGHT", 3, -1)
	bottom:SetHeight(2)
	left:SetPoint("TOPRIGHT", region, "TOPLEFT", -1, 3)
	left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", -1, -3)
	left:SetWidth(2)
	right:SetPoint("TOPLEFT", region, "TOPRIGHT", 1, 3)
	right:SetPoint("BOTTOMLEFT", region, "BOTTOMRIGHT", 1, -3)
	right:SetWidth(2)
	mark:Show()
	return true
end

-- The area -------------------------------------------------------------------------------------

-- Makes the frame the drawings sit on, inside `parent`, and keeps the view they read.
function D.Build(parent, view)
	D.view = view
	local stage = kit.Frame(parent)
	stage:SetSize(STAGE_W, STAGE_H)
	stage:SetPoint("CENTER", parent, "CENTER", 0, 0)
	D.stage = stage
	return stage
end

-- Shows one drawing and hides the others; makes it the first time. Returns the drawing, or nil for an id with none.
function D.Show(id)
	local drawing = D.drawings[id]
	local registered = ns.SetupDrawings[id]
	if drawing == nil and (registered or BUILDERS[id]) and D.stage and not D.failed[id] then
		drawing = { id = id, regions = {}, parts = {} }
		drawing.frame = kit.Frame(D.stage)
		drawing.frame:SetAllPoints(D.stage)
		if registered then
			if not Adapt(drawing, registered) then
				drawing.frame:Hide()
				D.failed[id] = true
				drawing = nil
			end
		else
			BUILDERS[id](drawing)
		end
		D.drawings[id] = drawing or nil
	end
	for key, other in pairs(D.drawings) do
		other.frame:SetShown(key == id)
		if other.mark and key ~= id then
			other.mark:Hide()
		end
	end
	D.current = drawing
	return drawing
end

-- Paints the drawing that is shown from what ns.Get says now. The caller has put the view in place with ns.Viewing.
function D.Paint()
	local drawing = D.current
	if drawing and drawing.draw then
		drawing.draw()
	end
end
