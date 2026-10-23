local ADDON_NAME, ns = ...

-- The look of the options window: one table of tokens (surfaces, lines, text, accent) that every colour of the window reads, and the eight
-- choices that change it. The choices are held per account in FlatUIDB.panel beside the place of the window, outside every profile, so a
-- profile switch does not reshape the window. Panel.lua draws with these functions and keeps no colour of its own.

local Look = {}
ns.PanelLook = Look

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local FONTS = MEDIA .. "Fonts\\"

local DEFAULTS = { accent = "indigo", accentColour = "ff9a9cf0", tone = "graphite", borders = "none", corners = "square", density = "comfortable", sections = "cards",
	font = "sans", scale = 100, sidebar = "full", grid = "dim", samples = "on", snapFrames = "on" }

-- Tokens ------------------------------------------------------------------------------------------

local TONES = {
	graphite = { window = "171915", sidebar = "141612", card = "1F221C", raised = "272B24", hover = "2F332B", stage = "10120F",
		tooltip = "141612", ["line-faint"] = "2B2F28", line = "353A31", ["line-strong"] = "494F44" },
	ink = { window = "13161B", sidebar = "101216", card = "1B1F26", raised = "222730", hover = "2A303B", stage = "0D0F13",
		tooltip = "101216", ["line-faint"] = "262C37", line = "303745", ["line-strong"] = "424B5B" },
}
-- Follow background colour: each surface is the backdrop colour of the addon plus a grey step.
local FOLLOW = { stage = -0.01, sidebar = 0, tooltip = 0, window = 0.01, card = 0.06, raised = 0.11, hover = 0.15, ["line-faint"] = 0.08, line = 0.12,
	["line-strong"] = 0.19 }
local TEXTS = {
	graphite = { text = "ECEEE6", ["text-dim"] = "A9AE9F", ["text-faint"] = "7A7F72" },
	ink = { text = "E9ECF2", ["text-dim"] = "A3ABBA", ["text-faint"] = "737B8A" },
}
local STATES = { ok = "7CCB8F", warn = "E6B85C", danger = "E5776C" }
local ACCENTS = { indigo = "9A9CF0", sage = "8CC79A", amber = "E6B85C", rose = "E88FA6", ice = "7CC3E6" }
-- Indigo is the one accent with hover and pressed values of its own; the others are made from their colour.
local INDIGO = { hover = "B0B2F5", pressed = "8183DF" }
local ON_ACCENT, ON_DARK = "15172B", "ECEEE6"

-- A number that a drawing of an earlier kind gives (a step of grey above the background) reads as the nearest token.
local STEPS = { { 0, "window" }, { 0.02, "window" }, { 0.04, "card" }, { 0.05, "raised" }, { 0.06, "card" }, { 0.07, "line-faint" },
	{ 0.08, "line-faint" }, { 0.09, "raised" }, { 0.1, "raised" }, { 0.12, "line" }, { 0.16, "hover" }, { 0.17, "hover" }, { 0.3, "line-strong" } }

local parsed = {}
local function Hex(hex)
	local got = parsed[hex]
	if not got then
		got = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
		parsed[hex] = got
	end
	return got[1], got[2], got[3]
end

local function Clamp(value)
	return math.max(0, math.min(1, value))
end

-- The settings -------------------------------------------------------------------------------------

-- The table the account holds for the window: its place and its look. Without create it is nil when there is none yet.
function Look.Store(create)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	if type(db.panel) ~= "table" then
		if not create then
			return nil
		end
		db.panel = {}
	end
	return db.panel
end

-- A setting of the look: what the account holds when it fits the setting, else its default.
function Look.Get(key)
	local store = Look.Store(false)
	local value = ns.Normalised("panel." .. key, store and store[key])
	if value == nil then
		return DEFAULTS[key]
	end
	return value
end

-- The functions the rows of the Options window section name (Config.lua).
function ns.PanelGet(def)
	local store = Look.Store(false)
	return ns.Normalised("panel." .. def.key, store and store[def.key])
end

function ns.PanelSet(def, value)
	local store = Look.Store(true)
	if store then
		store[def.key] = value
	end
end

function ns.PanelLookChanged(path)
	if type(Look.onChange) == "function" then
		Look.onChange(path:match("^panel%.(.+)$"))
	end
end

-- Where the window was put. The look is kept when the place is forgotten.
function Look.SavePosition(point, relative, x, y)
	local store = Look.Store(true)
	if store then
		store.point, store.relative, store.x, store.y = point, relative, x, y
	end
end

function Look.ClearPosition()
	local store = Look.Store(false)
	if store then
		store.point, store.relative, store.x, store.y = nil, nil, nil, nil
		if next(store) == nil then
			ns.Account().panel = nil
		end
	end
end

local ROWS = { compact = 28, comfortable = 36, roomy = 44 }
function Look.RowHeight()
	return ROWS[Look.Get("density")]
end

-- The width of the sidebar: Icons and names, Names only or Icon rail.
local SIDES = { full = 232, names = 200, rail = 56 }
function Look.SideWidth()
	return SIDES[Look.Get("sidebar")]
end

-- What the account remembers of the window besides its look: the page it was left on, and the groups of the sidebar that are folded.
function Look.Page()
	local store = Look.Store(false)
	return store and type(store.page) == "string" and store.page or nil
end

function Look.SetPage(key)
	local store = Look.Store(true)
	if store and store.page ~= key then
		store.page = key
	end
end

function Look.Folded(id)
	local store = Look.Store(false)
	return store ~= nil and type(store.folded) == "table" and store.folded[id] == true
end

function Look.Fold(id, folded)
	local store = Look.Store(folded)
	if not store then
		return
	end
	if type(store.folded) ~= "table" then
		store.folded = {}
	end
	store.folded[id] = folded or nil
	if next(store.folded) == nil then
		store.folded = nil
	end
end

function Look.Scale()
	return Look.Get("scale") / 100
end

-- Colours -------------------------------------------------------------------------------------------

local classRGB
-- Red, green and blue of an accent: a preset, the class colour (read while the client gives it and then kept) or the custom colour.
local function PresetRGB(id)
	if id == "class" then
		local r, g, b = ns.ClassColour()
		if r then
			classRGB = { r, g, b }
		end
		if classRGB then
			return classRGB[1], classRGB[2], classRGB[3]
		end
		return Hex(ACCENTS.indigo)
	elseif id == "custom" then
		return Hex(Look.Get("accentColour"):sub(3))
	end
	return Hex(ACCENTS[id])
end
Look.PresetRGB = PresetRGB

function Look.AccentRGB()
	return PresetRGB(Look.Get("accent"))
end

local function Accent(token)
	if token == "accent" then
		return Look.AccentRGB()
	end
	local r, g, b = Look.AccentRGB()
	if token == "on-accent" then
		return Hex((0.299 * r + 0.587 * g + 0.114 * b) > 0.45 and ON_ACCENT or ON_DARK)
	end
	if Look.Get("accent") == "indigo" then
		return Hex(token == "accent-hover" and INDIGO.hover or INDIGO.pressed)
	elseif token == "accent-hover" then
		return Clamp(r + (1 - r) * 0.22), Clamp(g + (1 - g) * 0.22), Clamp(b + (1 - b) * 0.22)
	end
	return r * 0.84, g * 0.84, b * 0.84
end

-- Red, green and blue of a token, or of the token a step of grey stands for.
function Look.Colour(spec)
	if type(spec) == "number" then
		local best, name = math.huge, "window"
		for _, step in ipairs(STEPS) do
			if math.abs(step[1] - spec) < best then
				best, name = math.abs(step[1] - spec), step[2]
			end
		end
		spec = name
	end
	if spec == "accent" or spec == "accent-hover" or spec == "accent-pressed" or spec == "on-accent" then
		return Accent(spec)
	end
	if STATES[spec] then
		return Hex(STATES[spec])
	end
	local tone = Look.Get("tone")
	local text = (TEXTS[tone] or TEXTS.graphite)[spec]
	if text then
		return Hex(text)
	end
	if tone == "follow" then
		local r, g, b = ns.Colour("general.backdrop")
		local step = FOLLOW[spec] or 0
		return Clamp(r + step), Clamp(g + step), Clamp(b + step)
	end
	return Hex(TONES[tone][spec] or TONES.graphite.window)
end

-- Changes whenever a colour of the window would: the window repaints when it does.
function Look.Key()
	local r, g, b = Look.AccentRGB()
	return table.concat({ Look.Get("tone"), Look.Get("borders"), Look.Get("corners"), ns.Get("general.backdrop"), ("%.3f %.3f %.3f"):format(r, g, b) }, "|")
end

-- Fills a texture with a token.
function Look.Solid(texture, spec, alpha)
	local r, g, b = Look.Colour(spec)
	texture:SetColorTexture(r, g, b, alpha or 1)
end

-- Borders and corners ----------------------------------------------------------------------------------

local RADIUS = { square = 0, soft = 2, round = 4 }
local SHAPES = { [2] = MEDIA .. "Round2.tga", [4] = MEDIA .. "Round4.tga" }
local SLICE = 4

function Look.Radius()
	return RADIUS[Look.Get("corners")]
end

-- The corners of a fill: one mask texture per outline, in the shape of the radius, with its corners kept at their size. A square corner takes
-- the mask off. The fill itself stays a plain colour, so any repaint of it keeps the corners.
local function Corners(outline, radius)
	local mask = outline.cornerMask
	if radius > 0 and not mask and type(outline.owner.CreateMaskTexture) == "function" then
		local made, new = pcall(outline.owner.CreateMaskTexture, outline.owner)
		if made and type(new) == "table" then
			mask = new
			outline.cornerMask = mask
			mask:SetAllPoints(outline.backdrop)
		end
	end
	if not mask then
		return
	end
	if radius > 0 then
		pcall(mask.SetTexture, mask, SHAPES[radius], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		if type(mask.SetTextureSliceMargins) == "function" and type(mask.SetTextureSliceMode) == "function" then
			local modes = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.UITextureSliceMode
			pcall(mask.SetTextureSliceMargins, mask, SLICE, SLICE, SLICE, SLICE)
			pcall(mask.SetTextureSliceMode, mask, type(modes) == "table" and modes.Stretched or 0)
		end
	end
	if (outline.cornerMasked or false) ~= (radius > 0) then
		outline.cornerMasked = radius > 0 or nil
		pcall(outline.backdrop[radius > 0 and "AddMaskTexture" or "RemoveMaskTexture"], outline.backdrop, mask)
	end
end

-- The fill of an outline in a token, its border and its corners. With Borders None the four edges are not drawn; the edge token "accent" (a
-- field with the cursor) is drawn whatever Borders says. The edge token is the colour of the edges when they are drawn.
function Look.Backing(outline, spec, alpha, edge)
	if not outline then
		return
	end
	local r, g, b = Look.Colour(spec)
	alpha = alpha or 1
	if type(spec) == "number" then
		-- A drawing of setup passes a step of grey and keeps the edges it has.
		ns.SetOutlineFill(outline, r, g, b, alpha)
		return
	end
	local radius = Look.Radius()
	ns.KeepOutline(outline)
	-- Straight edges would stand past a rounded corner, so a hairline is drawn only while the corners are square.
	local drawn = (Look.Get("borders") == "hairline" and radius == 0) or edge == "accent"
	ns.SetOutlineEdges(outline, drawn)
	if drawn then
		ns.SetOutlineColour(outline, Look.Colour(edge or "line"))
	end
	ns.SetOutlineFill(outline, r, g, b, alpha)
	Corners(outline, radius)
end

-- Fonts ----------------------------------------------------------------------------------------------

-- The font objects of the window, one for each size of text, and the game fonts each stands in for.
local OBJECTS = { title = "FlatUIPanelTitle", head = "FlatUIPanelHead", body = "FlatUIPanelBody", small = "FlatUIPanelSmall" }
local ROLES = { GameFontNormalLarge = "title", GameFontNormal = "head", GameFontHighlight = "body", GameFontHighlightSmall = "small" }
local SIZES = { compact = { title = 18, head = 12, body = 12, small = 10 }, comfortable = { title = 20, head = 13, body = 13, small = 11 },
	roomy = { title = 22, head = 14, body = 14, small = 12 } }
local NAMES = { sans = "Flat UI Sans", game = "game font", arial = "Arial Narrow" }
local made, applied = {}, nil

local function GameFile()
	local game = type(_G) == "table" and rawget(_G, "GameFontHighlight")
	if type(game) == "table" and type(game.GetFont) == "function" then
		local ok, file = pcall(game.GetFont, game)
		if ok and not ns.IsSecret(file) and type(file) == "string" and file ~= "" then
			return file
		end
	end
	return "Fonts\\FRIZQT__.TTF"
end

-- True when the client opens the file. FontString:SetFont answers whether the font was set (SimpleFontStringAPIDocumentation.lua:500-515), so a
-- hidden font string is asked once for each file. Font:SetFont documents no answer (SimpleFontAPIDocumentation.lua:199-211).
local probe, loads = nil, {}
local function Loads(file)
	if loads[file] == nil then
		if probe == nil then
			probe = false
			local made, frame = pcall(CreateFrame, "Frame")
			if made and type(frame) == "table" then
				local ok, text = pcall(frame.CreateFontString, frame, nil, "OVERLAY", "GameFontHighlight")
				probe = ok and type(text) == "table" and text or false
			end
		end
		local ok, said = false, nil
		if probe then
			ok, said = pcall(probe.SetFont, probe, file, 12, "")
		end
		loads[file] = ok and said == true
	end
	return loads[file]
end

-- True when the object holds the file. The game font is not asked about: it is what a font that does not load falls back to.
local function SetFile(object, file, size, game)
	if not game and not Loads(file) then
		return false
	end
	local ok = pcall(object.SetFont, object, file, size, "")
	if not ok then
		return false
	end
	local got, loaded = pcall(object.GetFont, object)
	return got and not ns.IsSecret(loaded) and type(loaded) == "string" and loaded ~= ""
end

-- Flat UI Sans and Arial Narrow have Latin and Cyrillic letters. Any other client takes the game font, which has its own letters.
local function Covers()
	return type(GetLocale) ~= "function" or ns.FontsLatin() or GetLocale() == "ruRU"
end

-- Sets the font objects to the face and density chosen. A face that does not load leaves the game font, and the status says so.
function Look.ApplyFonts()
	local face, density = Look.Get("font"), Look.Get("density")
	if applied == face .. density then
		return
	end
	applied = face .. density
	Look.fontFell, Look.fontLocale = false, false
	if face ~= "game" and not Covers() then
		Look.fontLocale = true
		face = "game"
	end
	local game = GameFile()
	local files = { game = { game, game }, arial = { "Fonts\\ARIALN.TTF", "Fonts\\ARIALN.TTF" },
		sans = { FONTS .. "IBMPlexSans-Regular.ttf", FONTS .. "IBMPlexSans-SemiBold.ttf" } }
	for role, name in pairs(OBJECTS) do
		if made[role] == nil then
			local ok, object = false, nil
			if type(CreateFont) == "function" then
				ok, object = pcall(CreateFont, name)
			end
			made[role] = ok and type(object) == "table" and object or false
		end
		local object = made[role]
		if object then
			local size = SIZES[density][role]
			local file = files[face][(role == "title" or role == "head") and 2 or 1]
			if not SetFile(object, file, size, face == "game") then
				Look.fontFell = true
				if not SetFile(object, game, size, true) then
					made[role] = false
				end
			end
		end
	end
	Look.fontTried = true
end

Look.SansFile = FONTS .. "IBMPlexSans-Regular.ttf"

-- The size of small text in the window at the chosen density, for the font samples.
function Look.SampleSize()
	return SIZES[Look.Get("density")].small
end

-- The font object that stands for a game font in the window, or nil to keep the game font.
function Look.Object(gameName)
	local role = ROLES[gameName]
	if not role then
		return nil
	end
	Look.ApplyFonts()
	return made[role] or nil
end

-- What a font string is given: the object of the window, else the name of the game font.
function Look.FontFor(gameName)
	return Look.Object(gameName) or gameName
end

-- The line /flatui status has for the window font, once the window has tried it.
function ns.PanelLookStatus()
	if not Look.fontTried then
		return {}
	end
	local face = Look.Get("font")
	if Look.fontLocale then
		return { ("Window font: game font (%s does not cover this language)"):format(NAMES[face]) }
	end
	if Look.fontFell then
		return { ("Window font: game font (%s did not load)"):format(NAMES[face]) }
	end
	return { "Window font: " .. NAMES[face] }
end