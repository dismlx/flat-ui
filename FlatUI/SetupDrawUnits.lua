local ADDON_NAME, ns = ...

-- The drawings of the unit frame steps of the setup (steps 13 to 22): mock-unit-frame, mock-unit-frames, mock-party-frames and mock-raid-cells, and mock-player,
-- the player's frame alone for the frame style cards. A drawing is { build(stage), draw(stage), parts = { [path] = region } }. build makes the frames once on the
-- stage, all of them in ns.Own so that no module restyles them. draw reads settings only through ns.Get and lays out and paints the same frames, so under the draft
-- view of the setup it draws the draft. Nothing here calls a module or the draft layer. Every number shown is fixed (health 7,000 of 10,000, mana 4,200 of 6,000),
-- since the real ones are secret values (AO/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:1526-1529); the player's power is that of their class at rest,
-- so a warrior's rage shows empty and a rogue's energy full. The bars, picture, name row, level, text and icons follow UnitFrames.lua, UnitFrameLevel.lua,
-- UnitFrameLooks.lua, UnitFramePortrait.lua, UnitFrameCells.lua, UnitText.lua, UnitParts.lua and UnitExtras.lua, which style the game's frames; the layout is this
-- file's own, since a module can style only the game's frames.
-- With Frame style One frame (the default) every unit frame but the raid cells is one body with one background and one border, and the picture, the name row
-- and the bars are cells inside it with no borders of their own, the gap (Border thickness and Space between parts) apart and in from its edge; an empty bar is
-- a lighter strip of the background. Separate parts gives each part its own border and background, as in 0.5.11. Portrait shape Round cuts faces and class
-- icons to a circle, and Game portrait in One frame is the face drawn by Flat UI and cut round; a 3D head stays square. The game's own portrait (Game portrait
-- in Separate parts, Flat UI portraits off, or a frame that is not restyled) is a disc of the game's size at the game's place beside the bars. A frame whose
-- switch is off, and every frame while Restyle unit frames is off, is drawn as the game draws it: a grey plate, the game's portrait and the game's bar file.
-- Each scene stands on a ground of muted earth, so that a see-through background looks as it does in the world.

local KEY = "unitframes"
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

-- The name row numbers of UnitFrames.lua:86-88, and the share of the name's size the level takes at each Level size (ROW.sizes).
local ROW = { height = 17, small = 13, accent = 3, strong = 0.95, pad = 4, gap = 1, wordGap = 2, levelRoom = 20, flagRoom = 24, timerRoom = 24,
	sizes = { smaller = 0.85, larger = 1.2 } }
-- The height of the name above the bars while there is no name row.
local NAMEH = 11
-- The corner radius of each Corners choice (UnitFrames.lua:98) and the sliced files that draw it (UnitFrames.lua:100-104), and the width of their corners.
local RADIUS = { slight = 1, soft = 2 }
local SHAPE = { [0] = MEDIA .. "Round0.tga", MEDIA .. "Round1.tga", MEDIA .. "Round2.tga" }
local LINE = { MEDIA .. "Outline1.tga", MEDIA .. "Outline2.tga" }
local SLICE = 4
-- The grey of a dark health bar (UnitFrameLooks.lua:20) and the shadow behind a frame (UnitFrameLooks.lua:25).
local DARK = 0.10
local SHADOW = { file = MEDIA .. "Shadow.tga", out = 8, alpha = 0.55 }
-- One frame and the pictures. GROUND: the earth colour round each scene, so that a see-through background shows the world behind it (a stand-in). LIFT: the
-- opacity of the white, or black on a light plate, that marks the empty part of a bar on the plate (UnitFrameLooks.lua Trough). CAP: the most lightness a name
-- row keeps, flat and fading, so that the name reads on it (stand-ins, UnitFrames.lua RowColour). INSET: the share of a round picture's side from its box's
-- corner to the circle at 45 degrees, (1 - 1/sqrt 2) / 2, where the level and the PvP plate sit. CROP: the share of a face cut off at each edge (UnitFrames.lua:58).
local GROUND = { 0.32, 0.27, 0.20 }
local LIFT = 0.08
local CAP = { flat = 0.45, gradient = 0.75 }
local INSET = 0.1464
local CROP = 0.08
-- The game's own portrait beside its bars: its size, the units between it and the bars, and on the player, target and focus how far its top is above the top
-- of the health bar. The player's is 60 at 24,-19 and its health bar starts at 87,-43 (Blizzard_UnitFrame/Mainline/PlayerFrame.xml:24-40,
-- Camelot/PlayerFrame.lua:79-84). The target's is 58 at -26,-19 from the top right of a frame 232 by 100, and its health slot ends 147 from the left with its top
-- 6 above the middle (Mainline/TargetFrame.xml:53, 61-73, Camelot/TargetFrame.lua:79-81). The pet's is 37 with its health bar 3 to the right (Mainline/PetFrame.xml:24-28,
-- Camelot/PetFrame.lua:15), a party member's 37 with its health bar 1 to the right and a party pet's 18 (Mainline/PartyFrameTemplates.xml:13-16, 86-90, 138-140):
-- the small frames keep 2. A small frame's portrait is centred on its bars.
local GAME = { player = { size = 60, gap = 3, top = 24 }, target = { size = 58, gap = 1, top = 25 }, focus = { size = 58, gap = 1, top = 25 },
	small = { size = 37, gap = 2 }, partypet = { size = 18, gap = 2 } }
-- The player's power at rest, by class: the power and how full it is. A warrior's rage is empty and a rogue's energy full out of combat; any other class has
-- mana at 70%.
local REST = { WARRIOR = { "RAGE", 0 }, ROGUE = { "ENERGY", 1 } }
-- The flags of each outline choice (UnitText.lua:14).
local FLAGS = { none = "", thin = "OUTLINE", thick = "OUTLINE, THICK" }
-- Samples: the colours of the classes, of a hostile and a friendly unit, and of the states of a picture border.
local CLASS = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 },
	PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 } }
local HOSTILE, FRIENDLY = { 0.80, 0.20, 0.20 }, { 0.18, 0.78, 0.24 }
local COMBAT, THREAT, GOLD = { 0.90, 0.15, 0.15 }, { 1, 0.2, 0.1 }, { 1, 0.82, 0 }
-- The colour of each debuff type, and of a buff that can be stolen (UnitFrames.lua:50).
local TYPE = { magic = { 0.2, 0.6, 1 }, poison = { 0, 0.6, 0.1 }, curse = { 0.6, 0, 1 }, none = { 0.8, 0, 0 }, steal = { 0.2, 0.6, 1 } }
-- The numbers of every frame, and the share of the health bar they fill.
local HEALTH, POWER = { cur = 7000, max = 10000, pct = 70, miss = 3000 }, { cur = 4200, max = 6000, pct = 70, miss = 1800 }
local FRACTION = 0.7
-- The width of the bars, the height of the health bar and of the power bar (0 for none), by the group of a frame.
local SIZE = { large = { bar = 124, health = 20, power = 10 }, small = { bar = 76, health = 12, power = 6 }, boss = { bar = 110, health = 14, power = 7 },
	pet2 = { bar = 60, health = 10, power = 0 } }
-- Icon art of the game by atlas (client/ui/Interface/AddOns/Blizzard_UnitFrame/Mainline/PlayerFrame.xml:327-344, PartyFrameTemplates.xml:302-323, and
-- Blizzard_FrameXML/PetHappiness.lua:23), with the colour of the plain square drawn where the client has no such atlas.
local ART = { leader = { "UI-HUD-UnitFrame-Player-Group-LeaderIcon", 1, 0.82, 0 }, attack = { "UI-HUD-UnitFrame-Player-CombatIcon", 0.9, 0.2, 0.2 },
	tank = { "roleicon-tiny-tank", 0.3, 0.5, 0.9 }, healer = { "roleicon-tiny-healer", 0.3, 0.8, 0.3 }, damage = { "roleicon-tiny-dps", 0.8, 0.3, 0.3 },
	pvp = { "UI-HUD-UnitFrame-Player-PVP-FFAIcon", 0.7, 0.7, 0.7 }, happy = { "UI-PetHappiness", 0.3, 0.8, 0.3 },
	rest = { "UI-HUD-UnitFrame-Player-Rest-Flipbook", 1, 0.9, 0.4 } }
local MARKER = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local ICON = 14
-- The picture of the sample auras and the totem.
local AURA_FILE = 135940

-- What each kind of frame has. group: its sizes. pic: it has a picture. side: "right" for a picture on the right of the bars, as the game has it on the target
-- and focus (UnitFrames.lua Describe), else it is on the left. on: its switch. sw: the switch of its picture. pick: the row of its picture. name, level, by, ht,
-- pt, power: the rows of its name, level, health colour, health text, power text and power bar. ranked: its unit can be an elite or a rare.
local KIND = {
	player = { group = "large", pic = true, on = "player", sw = "portraitPlayer", pick = "playerPicture", name = "playerName", level = "playerLevel",
		by = "playerHealthBy", ht = "player", pt = "player", power = "playerPowerBar" },
	target = { group = "large", pic = true, side = "right", on = "target", sw = "portraitTarget", pick = "targetPicture", name = "targetName", level = "targetLevel",
		by = "targetHealthBy", ht = "target", pt = "target", power = "targetPowerBar", ranked = true },
	focus = { group = "large", pic = true, side = "right", on = "focus", sw = "portraitFocus", pick = "focusPicture", name = "focusName", level = "focusLevel",
		by = "focusHealthBy", ht = "focus", pt = "focus", power = "focusPowerBar", ranked = true },
	pet = { group = "small", pic = true, on = "pet", sw = "portraitPet", pick = "petPicture", name = "petName", by = "petHealthBy", ht = "pet", pt = "pet",
		power = "petPowerBar" },
	tot = { group = "small", pic = true, on = "tot", sw = "portraitTot", pick = "totPicture", name = "totName", by = "totHealthBy", power = "totPowerBar" },
	party = { group = "small", pic = true, on = "party", sw = "portraitParty", pick = "partyPicture", name = "partyName", by = "partyHealthBy", ht = "party",
		pt = "party", power = "partyPowerBar" },
	partypet = { group = "pet2", pic = true, on = "partypet", sw = "portraitPartypet", pick = "partypetPicture", name = "partyName", ht = "party" },
	boss = { group = "boss", on = "boss", name = "bossName", level = "bossLevel", by = "bossHealthBy", ht = "boss", pt = "boss", power = "bossPowerBar" },
}
-- The frames whose text sizes are those of the player (UnitFrames.lua:114).
local LARGE = { player = true, target = true, focus = true }

-- Helpers ---------------------------------------------------------------------------------------------------------------------------------

local function Get(key)
	return ns.Get(KEY .. "." .. key)
end

local function Clamp(value)
	if value ~= value or value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Frame(parent)
	return Own(CreateFrame("Frame", nil, parent))
end

-- A frame of a unit frame `levels` above its root, so that the parts draw in their order whatever order the client gives frames of one level: the body,
-- then the picture and the bars, then the name row, then the icons and texts. Returns the frame.
local function Above(frame, root, levels)
	local ok, level = pcall(root.GetFrameLevel, root)
	if ok and not ns.IsSecret(level) and type(level) == "number" then
		pcall(frame.SetFrameLevel, frame, level + levels)
	end
	return frame
end

local function Tex(frame, layer, sub)
	return Own(frame:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

local function Text(frame, template)
	local text = Own(frame:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall"))
	pcall(text.SetWordWrap, text, false)
	pcall(text.SetMaxLines, text, 1)
	return text
end

-- A region's top left corner at (x, y) below the top left corner of an anchor, and its size.
local function Box(region, anchor, x, y, width, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
	region:SetSize(math.max(width, 0), math.max(height, 0))
end

-- A region on the whole of another, or inside it by an inset.
local function Over(region, anchor, inset)
	inset = inset or 0
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
	region:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
end

-- A texture over a stretch of a bar, from the left edge.
local function Stretch(region, anchor, from, to, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", anchor, "TOPLEFT", from, 0)
	region:SetSize(math.max(to - from, 0), height)
end

local function Solid(texture, r, g, b, a)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:SetColorTexture(Clamp(r), Clamp(g), Clamp(b), Clamp(a or 1))
end

-- A vertical gradient of one colour, as strong as bottom at the bottom and as top at the top; one colour at their mean when the client refuses it. keep: the
-- texture keeps its file, the rounded shape of a name row, and the gradient tints it, as UnitFrames.lua's Gradient does (a colour texture would square it).
local function Gradient(texture, r, g, b, bottom, top, keep)
	local done = type(CreateColor) == "function" and type(texture.SetGradient) == "function" and pcall(function()
		texture:SetVertexColor(1, 1, 1, 1)
		if not keep then
			texture:SetColorTexture(1, 1, 1, 1)
		end
		texture:SetGradient("VERTICAL", CreateColor(Clamp(r), Clamp(g), Clamp(b), Clamp(bottom)), CreateColor(Clamp(r), Clamp(g), Clamp(b), Clamp(top)))
	end)
	if not done and keep then
		texture:SetVertexColor(Clamp(r), Clamp(g), Clamp(b), Clamp((bottom + top) / 2))
	elseif not done then
		Solid(texture, r, g, b, (bottom + top) / 2)
	end
end

-- Keeps the corners of a sliced texture at their size. The client may lack the call or refuse it, and the texture then stretches.
local function Slice(texture)
	if type(texture.SetTextureSliceMargins) == "function" and type(texture.SetTextureSliceMode) == "function" then
		local modes = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.UITextureSliceMode
		local mode = type(modes) == "table" and modes.Stretched or 0
		pcall(texture.SetTextureSliceMargins, texture, SLICE, SLICE, SLICE, SLICE)
		pcall(texture.SetTextureSliceMode, texture, mode)
	end
end

-- The rounded rectangle of a radius, or the crisp square for none, on a texture in a colour.
local function Shaped(texture, radius, r, g, b, a)
	texture:SetTexture(SHAPE[radius or 0])
	Slice(texture)
	texture:SetVertexColor(Clamp(r), Clamp(g), Clamp(b), Clamp(a or 1))
end

-- A fill: an image file in a tint, or one solid colour.
local function Fill(texture, file, r, g, b, a)
	if file then
		texture:SetTexture(file)
		texture:SetVertexColor(Clamp(r), Clamp(g), Clamp(b), Clamp(a or 1))
	else
		Solid(texture, r, g, b, a)
	end
end

local atlases = {}
local function HasAtlas(name)
	if atlases[name] == nil then
		atlases[name] = false
		local api = C_Texture
		if type(api) == "table" and not ns.IsSecret(api) and type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			atlases[name] = ok and info ~= nil and not ns.IsSecret(info)
		end
	end
	return atlases[name]
end

-- The art of an icon: its atlas, or a plain square in its colour when the client has none (the grey version design.md 4.4 names).
local function Art(texture, key)
	local art = ART[key]
	texture:SetTexCoord(0, 1, 0, 1)
	if HasAtlas(art[1]) then
		texture:SetVertexColor(1, 1, 1, 1)
		texture:SetAtlas(art[1])
	else
		Solid(texture, art[2], art[3], art[4], 1)
	end
end

-- An icon of ICON units with its top left corner at (x, y) of the frame's root.
local function Mark(icon, root, x, y)
	icon:ClearAllPoints()
	icon:SetSize(ICON, ICON)
	icon:SetPoint("TOPLEFT", root, "TOPLEFT", x, -y)
	icon:Show()
end

local function Style(text, spec)
	ns.TextStyle(text, spec)
end

local function ClassRgb(token)
	local colour = CLASS[token] or CLASS.SHAMAN
	return colour[1], colour[2], colour[3]
end

-- Muted colours (UnitFrameLooks.lua:76-86), through the module's own function while it is there.
local function Mute(r, g, b)
	local X = ns.UnitFrameExtra
	if type(X) == "table" and type(X.mute) == "function" then
		local ok, mr, mg, mb = pcall(X.mute, r, g, b)
		if ok and mr ~= nil then
			return mr, mg, mb
		end
	end
	return r, g, b
end

-- The colour the curve of the Colours page gives at the health left: three points at 0, a half and 1 (HealthColour.lua:47-56), joined by straight lines.
local function Left(fraction)
	if type(ns.HealthLeftColour) == "function" then
		return ns.HealthLeftColour(fraction)
	end
	local low, half, full = { ns.Colour("general.healthLow") }, { ns.Colour("general.healthHalf") }, { ns.Colour("general.healthFull") }
	local from, to, share = low, half, fraction * 2
	if fraction > 0.5 then
		from, to, share = half, full, (fraction - 0.5) * 2
	end
	return from[1] + (to[1] - from[1]) * share, from[2] + (to[2] - from[2]) * share, from[3] + (to[3] - from[3]) * share
end

-- The image file of the fill of a bar of a role: false for a solid fill, nil for the texture of the Flat UI page and the soft shade look (UnitFrames.lua:187-197).
local function FillFile(role)
	local pick = Get(role .. "Texture")
	if pick ~= nil and pick ~= "default" then
		if pick == "flat" then
			return false
		end
		return ns.BarFile(pick)
	end
	return Get("lookSoftShade") and ns.BarFile("soft") or nil
end

-- The file a fill draws with, or nil for a solid colour.
local function FileOf(role)
	local file = FillFile(role)
	if file == nil then
		file = ns.BarTexture()
	end
	return file or nil
end

-- A number as the game writes it: AbbreviateNumbers (7K) or, with Number style Full, BreakUpLargeNumbers (7,000), both plain functions of a plain number
-- (UnitText.lua:313). The hand-written forms are for a client without them.
local function Commas(value)
	local text = tostring(value)
	while true do
		local done, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = done
		if count == 0 then
			return text
		end
	end
end

local function Short(value, call)
	local ok, text = pcall(call or Commas, value)
	if ok and type(text) == "string" then
		return text
	end
	return Commas(value)
end

local function Num(value)
	if Get("numberStyle") == "full" then
		return Short(value, BreakUpLargeNumbers)
	end
	if type(AbbreviateNumbers) == "function" then
		local ok, text = pcall(AbbreviateNumbers, value)
		if ok and type(text) == "string" then
			return text
		end
	end
	if value >= 1000 then
		local whole = value / 1000
		return (whole == math.floor(whole) and ("%dK"):format(whole) or ("%.1fK"):format(whole))
	end
	return tostring(value)
end

-- The words of a format on a bar, in the formats of UnitText.lua (X.formats, used by the module's own Write).
local function Words(mode, numbers)
	local formats = ns.UnitFrameExtra.formats
	if mode == "cur" then
		return Num(numbers.cur)
	elseif mode == "curmax" then
		return formats.curmax:format(Num(numbers.cur), Num(numbers.max))
	elseif mode == "pct" then
		return formats.pct:format(numbers.pct)
	elseif mode == "curpct" then
		return formats.curpct:format(Num(numbers.cur), numbers.pct)
	elseif mode == "miss" then
		return Num(numbers.miss)
	end
	return nil
end

-- The game's own words on a bar: none unless Status text is on (statusText is "0" by default, CVars.lua:1553), then the numbers, the percentage or both by
-- statusTextDisplay (Blizzard_TextStatusBar/TextStatusBar.lua:115-122, 143-190). Unit frames abbreviate the numbers (UnitFrame.lua:59,63).
local function Cvar(name)
	local get = type(C_CVar) == "table" and C_CVar.GetCVar or GetCVar
	if type(get) ~= "function" then
		return nil
	end
	local ok, value = pcall(get, name)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function GameWords(numbers)
	if Cvar("statusText") ~= "1" then
		return nil
	end
	local mode = Cvar("statusTextDisplay") or "NONE"
	local function big(value)
		if type(AbbreviateLargeNumbers) == "function" then
			local ok, text = pcall(AbbreviateLargeNumbers, value)
			if ok and type(text) == "string" then
				return text
			end
		end
		return value >= 1000 and (("%.1fK"):format(value / 1000):gsub("%.0K", "K")) or tostring(value)
	end
	local percent = math.ceil(numbers.cur / numbers.max * 100) .. "%"
	if mode == "PERCENT" then
		return percent
	elseif mode == "BOTH" then
		return "(" .. percent .. ") " .. big(numbers.cur) .. " / " .. big(numbers.max)
	end
	return big(numbers.cur) .. " / " .. big(numbers.max)
end

-- Outlines --------------------------------------------------------------------------------------------------------------------------------

-- The background of unit frames, red, green, blue and opacity: the Unit frames page's own with Own border and background on, else the Flat UI page's
-- (UnitFrames.lua FRAME.back). It is the plate of One frame and the fill of an outline that has none of its own, and it colours the dark name row, the player's
-- row base and the fade at the top of a picture.
local function Plate()
	if Get("lookOwn") == true then
		local r, g, b = ns.Colour(KEY .. ".lookBack")
		return r, g, b, (tonumber(Get("lookBackAlpha")) or 100) / 100
	end
	local r, g, b = ns.Colour("general.backdrop")
	return r, g, b, (tonumber(ns.Get("general.backdropAlpha")) or 100) / 100
end

-- The empty part of a bar in One frame, on the plate (UnitFrameLooks.lua Trough): white at LIFT, so that an empty bar still reads as a bar, or black at LIFT on
-- a light plate, one whose lightness (0.30 red + 0.59 green + 0.11 blue) is a half or more. { r, g, b, a } for EdgePaint.
local function Trough()
	local r, g, b = Plate()
	local shade = (0.30 * r + 0.59 * g + 0.11 * b) >= 0.5 and 0 or 1
	return { shade, shade, shade, LIFT }
end

-- The outline of a frame in the border and background the Unit frames page asks for: its own border and background with Own border and background on, else
-- the Flat UI page's. colour: the colour of a state (threat, resting, combat, kind), which keeps the edges with Borderless on. fill: { r, g, b, a } of a fill of
-- its own, the colour of what a dark health bar hides (opaque) or the trough of an empty bar. bars: Border off hides the edges, coloured or not. Every part is set
-- from ns.Get, so the same call draws the draft.
local function EdgePaint(outline, shown, back, colour, fill, bars)
	if outline == nil then
		return
	end
	ns.SetOutline(outline, shown and true or false, back and true or false)
	local own = Get("lookOwn") == true
	local r, g, b
	if colour then
		r, g, b = colour[1], colour[2], colour[3]
	elseif own then
		r, g, b = ns.Colour(KEY .. ".lookBorder")
	else
		r, g, b = ns.BorderRGB()
	end
	ns.SetOutlineColour(outline, r, g, b)
	ns.SetOutlineEdges(outline, (colour ~= nil or ns.Get("general.borderless") ~= true) and not (bars and Get("barBorder") == false))
	if fill then
		ns.SetOutlineFill(outline, fill[1], fill[2], fill[3], fill[4] or 1)
	else
		ns.SetOutlineFill(outline, Plate())
	end
	ns.SetOutlineThickness(outline, ns.Get("general.thickness"))
end

local rims = setmetatable({}, { __mode = "k" })

-- Rounds the corners of an outline as UnitFrames.lua:533-556 does: a rounded line over the straight edges, which turn transparent, and a mask of the radius on
-- its background. The slicing and the mask are made where the client has them; the line is there either way. radius nil makes the corners square again.
local function Round(outline, radius, t)
	if outline == nil then
		return
	end
	local rim = rims[outline]
	if rim == nil then
		if radius == nil then
			return
		end
		rim = { line = Tex(outline.top:GetParent(), "OVERLAY", 7) }
		rim.line:Hide()
		local parent = outline.backdrop:GetParent()
		if type(parent.CreateMaskTexture) == "function" then
			rim.mask = Own(parent:CreateMaskTexture())
			rim.mask:SetAllPoints(outline.anchor)
			rim.masked = pcall(outline.backdrop.AddMaskTexture, outline.backdrop, rim.mask)
		end
		rims[outline] = rim
	end
	rim.radius = radius
	if rim.mask and radius == nil and rim.masked then
		pcall(outline.backdrop.RemoveMaskTexture, outline.backdrop, rim.mask)
		rim.masked = false
	elseif rim.mask and radius and not rim.masked then
		rim.masked = pcall(outline.backdrop.AddMaskTexture, outline.backdrop, rim.mask)
	end
	if radius then
		rim.line:SetTexture(LINE[radius])
		Slice(rim.line)
		if rim.mask then
			rim.mask:SetTexture(SHAPE[radius], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			Slice(rim.mask)
		end
		rim.line:ClearAllPoints()
		rim.line:SetPoint("TOPLEFT", outline.anchor, "TOPLEFT", -t, t)
		rim.line:SetPoint("BOTTOMRIGHT", outline.anchor, "BOTTOMRIGHT", t, -t)
		rim.line:SetVertexColor(Clamp(outline.r or 0), Clamp(outline.g or 0), Clamp(outline.b or 0), 1)
	end
	rim.line:SetShown(radius ~= nil and outline.shown == true and outline.edgesOff ~= true and outline.bare ~= true)
	for _, edge in ipairs(outline.edges) do
		edge:SetAlpha(radius and 0 or 1)
	end
end

-- The mask that cuts a fill to the corners of its bar, where the client makes masks.
local function CutFill(bar, fill, radius)
	if type(bar.CreateMaskTexture) ~= "function" then
		return
	end
	if bar.cutMask == nil then
		bar.cutMask = Own(bar:CreateMaskTexture())
		Over(bar.cutMask, bar)
	end
	if radius then
		bar.cutMask:SetTexture(SHAPE[radius], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		Slice(bar.cutMask)
	end
	if radius and not bar.cutOn then
		bar.cutOn = pcall(fill.AddMaskTexture, fill, bar.cutMask)
	elseif not radius and bar.cutOn then
		bar.cutOn = not pcall(fill.RemoveMaskTexture, fill, bar.cutMask)
	end
end

-- Samples ---------------------------------------------------------------------------------------------------------------------------------

-- The name, level and class of the player, which are plain values for the player's own unit.
local function Me()
	local name, level, class
	pcall(function()
		local n = UnitName("player")
		if not ns.IsSecret(n) and type(n) == "string" and n ~= "" then
			name = n
		end
		local l = UnitLevel("player")
		if not ns.IsSecret(l) and type(l) == "number" and l > 0 then
			level = l
		end
		local _, token = UnitClass("player")
		if not ns.IsSecret(token) and type(token) == "string" and CLASS[token] then
			class = token
		end
	end)
	return name or "Brennan", level or 20, class or "SHAMAN"
end

-- The party: five fixed names, one per class colour, each with a role.
local PARTY = { { "Mara", "PALADIN", "tank" }, { "Bex", "MAGE", "healer" }, { "Cole", "HUNTER", "damage" }, { "Dru", "DRUID", "damage" }, { "Fay", "ROGUE", "damage" } }
local PETS = { "Cat", "Boar", "Owl", "Wolf", "Bear" }

-- The sample of one frame. player: a player, with a class colour; the others take the colour of their reaction. aura: kind, type, stealable, count, time.
-- threat: the unit has threat. It is on the boss and not on the elite target, since in One frame threat would hide the target's Elite gold.
local function Sample(id)
	local name, level, class = Me()
	if id == "player" then
		return { kind = "player", cap = "Player", name = name, level = level, class = class, player = true, react = FRIENDLY, lcol = GOLD, state = COMBAT, leader = true,
			flag = "PvP", timer = "3:05", own = true }
	elseif id == "target" then
		return { kind = "target", cap = "Target", name = "Defias Pillager", level = 18, react = HOSTILE, lcol = { 1, 0.5, 0.25 }, rank = "elite", marker = 8,
			auras = { { "buff", "none", true }, { "buff", "none" }, { "debuff", "magic" }, { "debuff", "poison" } } }
	elseif id == "focus" then
		return { kind = "focus", cap = "Focus", name = "Gruff Swiftbite", level = 18, react = HOSTILE, lcol = { 0.25, 0.75, 0.25 }, rank = "rare" }
	elseif id == "pet" then
		return { kind = "pet", cap = "Pet", name = "Wolf", level = 20, class = class, react = FRIENDLY, state = COMBAT, happy = true,
			auras = { { "debuff", "curse", false, 3, "12" } } }
	elseif id == "tot" then
		return { kind = "tot", cap = "Target of target", name = "Defias Pillager Captain", level = 18, react = HOSTILE, auras = { { "debuff", "magic" } } }
	elseif id == "boss" then
		return { kind = "boss", cap = "Boss", name = "Hogger", level = "??", react = HOSTILE, lcol = { 1, 0.1, 0.1 }, marker = 1, threat = true }
	elseif id == "boss2" then
		return { kind = "boss", name = "Kobold Digger", level = "??", react = HOSTILE, lcol = { 1, 0.1, 0.1 }, dead = true }
	end
	local number = tonumber(id:match("^party(%d)$"))
	if number then
		local member = PARTY[number]
		local debuffed = number == 1 or number == 3
		return { kind = "party", cap = number == 1 and "Party" or nil, name = member[1], level = 19, class = member[2], player = true, react = FRIENDLY, role = member[3],
			leader = number == 1, number = number, away = number == 4, auras = debuffed and { { "debuff", number == 1 and "magic" or "poison", false, 3, "12" } } or nil,
			debuff = number == 1 and TYPE.magic or nil }
	end
	number = tonumber(id:match("^partypet(%d)$"))
	if number then
		return { kind = "partypet", cap = number == 1 and "Party pet" or nil, name = PETS[number], level = 19, react = FRIENDLY, owner = PARTY[number][2] }
	end
end

-- One frame --------------------------------------------------------------------------------------------------------------------------------

local E = {}

-- Makes the frames of one unit frame on a parent. Nothing is shown or placed until E.draw. The levels above the root are those of the game's frames
-- (UnitFrames.lua FRAME.make): the body 1, the picture, the bars, the rim and the inner line 2, the name row 3, the icons and texts 4.
function E.make(stage, id)
	local sample = Sample(id)
	local k = KIND[sample.kind]
	-- cut: the textures the circle of a round picture cuts now (Cut).
	local o = { id = id, k = k, s = sample, draw = E.draw, cut = {} }
	local root = Frame(stage)
	o.root = root
	o.shadow = Tex(root, "BACKGROUND", -8)
	o.plate = Tex(root, "BACKGROUND", -7)
	-- The body of One frame: its outline's backdrop is the plate behind every part, and its edges, t outside it in whole pixels, the frame's one border.
	-- (o.body is the grey shape of a unit's body on its picture.)
	o.box = Above(Frame(root), root, 1)
	o.boxOutline = ns.Outline(o.box, o.box)
	ns.SetOutlineArea(o.boxOutline, KEY)
	if k.pic then
		local pic = Above(Frame(root), root, 2)
		o.pic = pic
		o.glow = Tex(pic, "BACKGROUND", -6)
		o.ring = Tex(pic, "BACKGROUND", -5)
		o.face = Tex(pic, "ARTWORK", 0)
		o.head = Tex(pic, "ARTWORK", 1)
		o.body = Tex(pic, "ARTWORK", 1)
		o.fade = Tex(pic, "ARTWORK", 5)
		o.outline = ns.Outline(pic, pic, true)
		ns.SetOutlineArea(o.outline, KEY)
		if k.ranked then
			o.rimFrame = Above(Frame(root), root, 2)
			o.rim = ns.Outline(o.rimFrame, o.rimFrame, true)
			ns.SetOutlineArea(o.rim, KEY)
			ns.SetOutlineThickness(o.rim, 2)
			o.innerFrame = Above(Frame(root), root, 2)
			o.inner = ns.Outline(o.innerFrame, o.innerFrame, true)
			ns.SetOutlineArea(o.inner, KEY)
			ns.SetOutlineThickness(o.inner, 1)
		end
	end
	for _, role in ipairs({ "health", "power" }) do
		local bar = Above(Frame(root), root, 2)
		o[role] = bar
		o[role .. "Back"] = Tex(bar, "BACKGROUND", -6)
		o[role .. "Outline"] = ns.Outline(bar, bar)
		ns.SetOutlineArea(o[role .. "Outline"], KEY)
		o[role .. "Fill"] = Tex(bar, "ARTWORK", 0)
		local top = Frame(bar)
		o[role .. "Top"] = top
		o[role .. "Text"] = Text(top, "GameFontHighlightSmall")
	end
	o.pred, o.shield, o.absorb = Tex(o.health, "ARTWORK", 1), Tex(o.health, "ARTWORK", 2), Tex(o.health, "ARTWORK", 3)
	o.deadText = Text(o.healthTop, "GameFontHighlightSmall")
	local row = Above(Frame(root), root, 3)
	o.row = row
	o.rBase, o.rGrad, o.rFill = Tex(row, "BACKGROUND", -8), Tex(row, "BACKGROUND", 0), Tex(row, "BACKGROUND", 0)
	o.rMark, o.rLine = Tex(row, "ARTWORK", 0), Tex(row, "ARTWORK", 1)
	o.name, o.level, o.kmark, o.kword, o.flag = Text(row), Text(row), Text(row), Text(row), Text(row)
	o.kmark:SetJustifyH("RIGHT")
	o.level:SetJustifyH("RIGHT")
	o.kword:SetJustifyH("RIGHT")
	o.flag:SetJustifyH("RIGHT")
	o.name:SetJustifyH("LEFT")
	local top = Above(Frame(root), root, 4)
	o.top = top
	o.picLevel = Text(top)
	o.picLevel:SetJustifyH("RIGHT")
	o.leader, o.attack, o.role, o.plateIcon, o.marker, o.happy = Tex(top, "OVERLAY", 2), Tex(top, "OVERLAY", 2), Tex(top, "OVERLAY", 2), Tex(top, "OVERLAY", 2),
		Tex(top, "OVERLAY", 3), Tex(top, "OVERLAY", 2)
	o.pvpTimer = Text(top)
	o.shade = Tex(top, "OVERLAY", 7)
	o.auras = {}
	for index, aura in ipairs(sample.auras or {}) do
		local icon = ns.IconNew(top)
		if icon then
			icon.ring = Tex(top, "BACKGROUND", -5)
			icon.count, icon.time = Text(top), Text(top)
			icon.count:SetJustifyH("RIGHT")
			icon.time:SetJustifyH("CENTER")
			icon.aura = aura
			o.auras[index] = icon
		end
	end
	-- The regions the rows of the steps mark (design.md 4.3, part marks). body: the frame's box, placed in both styles and shown in One frame.
	o.parts = { root = root, body = o.box, pic = o.pic, health = o.health, power = o.power, row = row, name = o.name, level = o.level, healthText = o.healthText,
		powerText = o.powerText, pred = o.pred, shield = o.shield, absorb = o.absorb, kmark = o.kmark, kword = o.kword, kline = o.rLine, plate = o.plateIcon,
		flag = o.flag, leader = o.leader, role = o.role, marker = o.marker, attack = o.attack, happy = o.happy, dead = o.deadText, aura = o.auras[1] and o.auras[1].frame,
		count = o.auras[1] and o.auras[1].count, time = o.auras[1] and o.auras[1].time, picLevel = o.picLevel, timer = o.pvpTimer, shadow = o.shadow }
	return o
end

-- The colour of a name row and of the border of a picture: the class of a player, the reaction of any other unit, and for the pet and a party pet the class
-- of the owner (UnitFrames.lua:1380-1425, UnitFramePortrait.lua:11-44).
local function UnitColour(o)
	local s = o.s
	if s.kind == "pet" then
		return ClassRgb(s.class)
	elseif s.kind == "partypet" then
		return ClassRgb(s.owner)
	elseif s.player then
		return ClassRgb(s.class)
	end
	return s.react[1], s.react[2], s.react[3]
end

-- The colour a name or a health bar takes with Class or Reaction: the class of a player, the reaction of any other unit; the pet takes the player's class on the health bar only (UnitText.lua:76-92).
local function ByUnit(o, mode, health)
	local s = o.s
	if mode == "reaction" or not (s.player or (health and s.kind == "pet")) then
		return s.react[1], s.react[2], s.react[3]
	end
	return ClassRgb(s.class)
end

-- What the picture of a frame shows: its style, whether it shows nothing, and whether it shows the game's own portrait (UnitFrames.lua:159-173).
local function PictureMode(k)
	local style = Get("portraitStyle")
	local none = style == "none" or (k.sw ~= nil and Get(k.sw) == false)
	local pick = k.pick and Get(k.pick) or "auto"
	if pick == "square" or pick == "class" then
		return pick == "class" and "icon" or "picture", false, false
	elseif pick == "head" then
		return "head", false, false
	elseif pick == "none" then
		return style, true, false
	elseif pick == "game" then
		return style, false, true
	end
	return style, none, false
end

-- The settings every frame of a draw shares.
local function Settings(root)
	local g = { enabled = Get("enabled") == true, square = Get("squarePortrait") == true, strip = Get("strip") == true, smallRow = Get("smallRow") == true,
		portraitSize = Get("portraitSize"), headFraming = Get("headFraming"), portraitBorder = Get("portraitBorder"), classShape = Get("classShape"), portraitFade = Get("portraitFade") == true, stripColour = Get("stripColour"),
		stripFade = Get("stripFade"), stripBrightness = Get("stripBrightness"), flat = Get("flat") == true, healthByLeft = Get("healthByLeft") == true,
		backdrop = Get("backdrop") == true, status = Get("status") == true, threat = Get("threat") == true, healPrediction = Get("healPrediction") == true,
		absorbShield = Get("absorbShield") == true, healAbsorb = Get("healAbsorb") == true, levelPosition = Get("levelPosition"), levelColour = Get("levelColour"), pvpWordColour = Get("pvpWordColour"),
		levelSize = Get("levelSize"), kindMark = Get("kindMark") == true, kindWord = Get("kindWord") == true, kindLine = Get("kindLine") == true,
		nameFace = Get("nameFace"), nameSize = Get("nameSize"), nameOutline = Get("nameOutline"), nameColour = Get("nameColour"),
		healthTextSize = Get("healthTextSize"), powerTextSize = Get("powerTextSize"), smallTextSize = Get("smallTextSize"), barTextFace = Get("barTextFace"),
		barTextOutline = Get("barTextOutline"), barTextOwn = Get("barTextColourOwn") == true, lightText = Get("lookLightText") == true,
		noPowerText = Get("lookNoPowerText") == true, ownTextWhen = Get("ownTextWhen"),
		pvpFlag = Get("pvpFlag"), pvpCorner = Get("pvpCorner"), pvpTimer = Get("pvpTimer") == true, pvpIcon = Get("pvpIcon") == true,
		leaderIcon = Get("leaderIcon") == true, roleIcon = Get("roleIcon") == true, raidMarker = Get("raidMarker") == true, deadText = Get("deadText") == true,
		combatIcon = Get("combatIcon") == true, petHappiness = Get("petHappiness") == true, restAnimation = Get("restAnimation"), auras = Get("auras") == true,
		auraCrop = Get("auraCrop"), auraTypeColours = Get("auraTypeColours") == true, auraCountSize = Get("auraCountSize"),
		auraNumbers = Get("auraNumbers") == true, lookShadow = Get("lookShadow") == true, radius = RADIUS[Get("corners")], fit = { tot = Get("totNameFit"), pet = Get("petNameFit"), party = Get("partyNameFit"), partypet = Get("partyNameFit"), boss = Get("bossNameFit") } }
	g.t = ns.Pixels(root, ns.Get("general.thickness"))
	-- Frame style: One frame unless it says Separate parts (no row yet counts as One frame). The gap of One frame is Border thickness and Space between parts
	-- (2 px while the row is not there), between the parts and round them (UnitFrames.lua FRAME.gap).
	g.joined = Get("frameStyle") ~= "parts"
	g.space = ns.Pixels(root, tonumber(Get("powerSpace")) or 2)
	g.gap = g.t + g.space
	return g
end

-- The geometry of a frame: what is on, and where each part goes, in units from the top left corner of its root (UnitFrames.lua Layout, SideOf, AnchorPicture
-- and FRAME.place).
-- One frame: the picture, the name row and the bars are cells the gap apart and the gap in from the body's edge, and the body keeps a border's width inside the
-- root for its border, as every part does in Separate parts. The row is as wide as the bars, or with As tall as the bars runs on over the picture's column. The
-- picture is a square as tall as the cells beside it, from the row's top (As tall as the frame), the name's (a small frame without a row) or the health bar's to
-- the power bar's bottom; it is on the bars' left, or their right on the target and focus. None leaves no cell. The body wraps the name of a small frame or a
-- boss frame without a row; the player, target and focus keep theirs above it.
-- Separate parts: each part's border is t outside it, the row sits on the health bar's top border band, the power bar is 2t under the health bar and, on
-- every frame but the player's, Space between parts further, and the picture is 3t from the bars, its place kept, empty, with None.
-- The game's own portrait is a disc of the game's size and gap beside the bars (GAME): the bars move right, and everything moves down, until it fits in the root.
local function Layout(o, g)
	local k, s = o.k, o.s
	local size = SIZE[k.group]
	local t = g.t
	local L = { size = size, t = t, large = LARGE[s.kind] == true, boss = k.group == "boss" }
	L.on = g.enabled and Get(k.on) == true
	L.joined = L.on and g.joined
	L.right = k.side == "right"
	L.drawn, L.gameFace = false, false
	if k.pic then
		if not L.on or not g.square then
			L.gameFace = true
		else
			L.style, L.none, L.game = PictureMode(k)
			-- In One frame Game portrait is the face drawn by Flat UI and cut round (UnitFrames.lua ApplyPicture).
			if L.game and L.joined then
				L.style, L.game, L.gameRound = "picture", false, true
			end
			L.drawn, L.gameFace = not L.none and not L.game, L.game
		end
	end
	-- Round: faces and class icons with Portrait shape Round, whatever the unit, and Game portrait in One frame. A 3D head stays square.
	L.round = L.drawn and L.style ~= "head" and (g.classShape == "round" or L.gameRound == true) or false
	L.rowOn = L.on and g.strip and g.square and ((not (k.group == "small" or k.group == "pet2")) or g.smallRow)
	L.rowH = L.rowOn and (L.large and ROW.height or ROW.small) or 0
	L.power = size.power > 0 and (not L.on or k.power == nil or Get(k.power) ~= false)
	L.tall = L.rowOn and g.portraitSize ~= "bars"
	local bar = size.bar
	-- start: where the cells start, the margin round them plus, in One frame, the band of the body's border. seam: from the row, or the name, to the health
	-- bar. drop: from the health bar to the power bar. apart: from the picture to the bars. inside: the picture's top below the row's or the name's.
	local start, seam, nameSeam, drop, apart, inside = t, t, 0, 2 * t, 3 * t, t
	if L.joined then
		start, seam, nameSeam, drop, apart, inside = t + g.gap, g.gap, g.gap, g.gap, g.gap, 0
	elseif L.on and s.kind ~= "player" and g.space > 0 and not ((L.right or L.boss) and Get("powerWidth") == "game") then
		-- Separate parts: Space between parts lowers the power bar by that much more on every frame but the player's, whose bar hangs by the two borders
		-- alone; a power bar of the game's width on the target, focus or boss keeps the game's place (UnitFrames.lua FRAME.partsCut and PowerSpan).
		drop = 2 * t + g.space
	end
	local y = start
	if L.rowOn then
		L.rowTop = y
		y = y + L.rowH + seam
	elseif L.joined and L.large then
		-- The player, target and focus without a name row keep the game's name above the body, which starts at the bars (UnitFrames.lua FRAME.place).
		L.nameTop = 0
		y = NAMEH + start
	else
		L.nameTop = y
		y = y + NAMEH + nameSeam
	end
	L.healthTop = y
	L.healthBottom = y + size.health
	L.powerTop = L.healthBottom + drop
	L.bottom = L.power and (L.powerTop + size.power) or L.healthBottom
	L.picTop = L.healthTop
	if L.tall then
		L.picTop = L.rowTop + inside
	elseif not L.rowOn and not L.large and not L.boss then
		L.picTop = L.nameTop + inside
	end
	L.side = math.max(L.bottom - L.picTop, 4)
	-- The picture's square: a drawn picture, and in Separate parts the empty place of None as well.
	L.cell = (k.pic and not L.gameFace and (L.drawn or not L.joined)) and true or false
	L.barsLeft, L.picLeft = start, start
	if L.cell and L.right then
		L.picLeft = start + bar + apart
	elseif L.cell then
		L.barsLeft = start + L.side + apart
	end
	if L.rowOn and L.joined and L.cell and not L.tall then
		L.rowLeft, L.rowWidth = start, L.side + apart + bar
	elseif L.rowOn and L.joined then
		L.rowLeft, L.rowWidth = L.barsLeft, bar
	elseif L.rowOn then
		L.rowLeft, L.rowWidth = L.barsLeft - t, bar + 2 * t
	end
	L.width = (L.cell and L.side + apart or 0) + bar + 2 * start
	L.height = L.bottom + start
	if L.gameFace then
		local game = GAME[s.kind] or GAME.small
		L.side = game.size
		L.picTop = game.top and (L.healthTop - game.top) or ((L.healthTop + L.bottom - game.size) / 2)
		L.picLeft = L.right and (L.barsLeft + bar + game.gap) or (L.barsLeft - game.gap - game.size)
		local dx, dy = math.max(0, -L.picLeft), math.max(0, -L.picTop)
		for _, key in ipairs({ "barsLeft", "picLeft", "rowLeft" }) do
			L[key] = L[key] and L[key] + dx
		end
		for _, key in ipairs({ "rowTop", "nameTop", "healthTop", "healthBottom", "powerTop", "bottom", "picTop" }) do
			L[key] = L[key] and L[key] + dy
		end
		L.width = math.max(L.width + dx, L.picLeft + L.side)
		L.height = math.max(L.height + dy, L.picTop + L.side)
	end
	-- The body: in One frame the cells' box with the gap round it, the game's portrait outside it; in Separate parts, where nothing is drawn on it, the frame.
	if L.joined then
		local left = math.min(L.barsLeft, L.rowLeft or L.barsLeft, L.cell and L.picLeft or L.barsLeft)
		local right = math.max(L.barsLeft + bar, L.rowLeft and (L.rowLeft + L.rowWidth) or 0, L.cell and (L.picLeft + L.side) or 0)
		local top = L.rowTop or (not L.large and L.nameTop) or L.healthTop
		L.bodyLeft, L.bodyTop = left - g.gap, top - g.gap
		L.bodyWidth, L.bodyHeight = right - left + 2 * g.gap, L.bottom - top + 2 * g.gap
	else
		L.bodyLeft, L.bodyTop, L.bodyWidth, L.bodyHeight = 0, 0, L.width, L.height
	end
	L.radius = L.on and g.radius or nil
	-- Where the level shows: Level position, with On the portrait needing a picture Flat UI draws and a name row; else it is at the end of the row, as the
	-- game frames show it (UnitFrames.lua ROW.at).
	L.levelOn = (L.large or L.boss) and (not L.on or Get(k.level) ~= false)
	L.at = g.levelPosition
	if L.at == "portrait" and not (L.drawn and L.rowOn) then
		L.at = "end"
	end
	if not L.rowOn then
		L.at = "end"
	end
	return L
end

-- The one colour of the border round the body and round a round picture in One frame, the first that applies: threat or a party member's top debuff;
-- resting, combat or an attacking pet; Elite, Rare or Boss; the class or reaction colour of Portrait border Class or reaction colour. Nil leaves the border
-- colour, which Borderless hides. The states and the kinds need Flat UI portraits and a frame with a picture (UnitFrames.lua FRAME.colour); Portrait border
-- needs Flat UI portraits only, so it reaches a boss frame too (UnitFramePortrait.lua Colour).
local function FrameColour(o, g)
	local s, k = o.s, o.k
	local threat = g.threat and (s.threat and THREAT or s.debuff) or nil
	if threat then
		return threat
	end
	local square = g.square and k.pic
	if square and g.status and s.state then
		return s.state
	end
	local look = square and s.rank and Get("elite") == true and ns.KINDS[s.rank] or nil
	if look then
		return look.colour
	end
	if g.square and g.portraitBorder == "class" then
		local r, gr, b = Mute(UnitColour(o))
		return { r, gr, b }
	end
	return nil
end

-- Cuts the grey shapes of a unit and the game's black disc with the circle that cuts the face (ns.SetOutlineRound's artMask), or takes the circle off. The
-- circle is there once the outline has been round; one that waits for the end of combat cuts nothing yet.
local function Cut(o, on)
	local round = o.outline and o.outline.round
	local mask = round and round.artMask
	if mask == nil then
		return
	end
	on = on and o.outline.roundOn == true
	for _, texture in ipairs({ o.head, o.body, o.ring }) do
		if (o.cut[texture] or false) ~= on and pcall(texture[on and "AddMaskTexture" or "RemoveMaskTexture"], texture, mask) then
			o.cut[texture] = on or nil
		end
	end
end

-- The picture: its border, the face, the fade and the rest glow (UnitFrames.lua ApplyPicture, Draw and Colour, UnitFramePortrait.lua).
-- Separate parts: the border takes the colour of a state or a kind, else of the class or reaction, over the picture's own background, and an Elite or Rare
-- picture gets its 2 px rim and a Rare Elite its inner line.
-- One frame: a square picture is a cell with no border and no background of its own; a round one keeps its ring in the one colour of the frame (E.draw), with
-- Border and Portrait border None as for the body. There is no rim or inner line: the mark after the level tells a Rare Elite.
-- The game's own portrait is a black disc with the face over it, both cut round, with no ring line: the game's ring art is faded.
function E.picture(o, g, L)
	local s, pic, t = o.s, o.pic, L.t
	local shown = L.drawn or L.gameFace
	pic:SetShown(shown)
	Box(pic, o.root, L.picLeft, L.picTop, L.side, L.side)
	local look = nil
	if L.joined then
		local ring = L.drawn and L.round
		EdgePaint(o.outline, ring, false, L.colour, nil, true)
		ns.SetOutlineBare(o.outline, ring and L.bare)
		Round(o.outline, nil, t)
	else
		look = L.drawn and s.rank and Get("elite") == true and ns.KINDS[s.rank] or nil
		local colour = nil
		if L.drawn and g.status and s.state then
			colour = s.state
		end
		if look then
			colour = look.colour
		end
		local coloured = colour ~= nil
		if L.drawn and not coloured and g.portraitBorder == "class" then
			local r, gr, b = Mute(UnitColour(o))
			colour = { r, gr, b }
		end
		EdgePaint(o.outline, L.drawn, true, colour)
		ns.SetOutlineBare(o.outline, L.drawn and g.portraitBorder == "none" and not coloured)
		-- A round picture has its ring in place of the rounded corners.
		Round(o.outline, L.drawn and not L.round and L.radius or nil, t)
	end
	if o.rim then
		o.rimFrame:SetShown(look ~= nil)
		Over(o.rimFrame, pic)
		EdgePaint(o.rim, look ~= nil, false, look and look.colour or nil)
		-- EdgePaint gives an outline the general thickness: the rim is 2 px and the inner line 1 px, as on the game's frames (UnitFrames.lua RIM_PX, INNER_PX).
		ns.SetOutlineThickness(o.rim, 2)
		Round(o.rim, look ~= nil and L.radius or nil, t)
		local inner = look ~= nil and look.inner ~= nil
		o.innerFrame:SetShown(inner)
		Over(o.innerFrame, pic, ns.Pixels(o.root, 1))
		EdgePaint(o.inner, inner, false, inner and look.inner or nil)
		ns.SetOutlineThickness(o.inner, 1)
	end
	-- The face fills the square: the player's portrait unmasked, as UnitFrames.lua Draw draws it, a class icon on a player, else a plain silhouette. Under the
	-- game's own portrait is a black disc, as the game draws it.
	o.ring:SetShown(L.gameFace)
	o.face:SetShown(shown)
	Over(o.face, pic)
	if L.gameFace then
		Over(o.ring, pic)
		Solid(o.ring, 0, 0, 0, 1)
	end
	local icon = L.drawn and L.style == "icon" and s.player
	local atlas = icon and ns.ClassAtlas(s.class) or nil
	local plain = false
	o.face:SetTexCoord(0, 1, 0, 1)
	if atlas then
		o.face:SetVertexColor(1, 1, 1, 1)
		o.face:SetAtlas(atlas)
	elseif icon then
		local r, gr, b = ClassRgb(s.class)
		Solid(o.face, r * 0.8, gr * 0.8, b * 0.8, 1)
	elseif s.own and shown and type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, o.face, "player", true) then
		o.face:SetVertexColor(1, 1, 1, 1)
		-- A drawn face loses CROP at each edge, as UnitFrames.lua Draw cuts it; a 3D head is drawn as the face cut tighter, tighter still for the framing Face
		-- and looser for Head and shoulders (stand-ins). The game's own portrait is whole.
		local crop = 0
		if L.drawn then
			crop = L.style == "head" and (({ face = 0.28, shoulders = 0.12 })[g.headFraming] or 0.2) or CROP
		end
		o.face:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	else
		Solid(o.face, 0.29, 0.32, 0.38, 1)
		plain = shown
	end
	-- The circle cuts a round picture, its fade, its grey shapes and the game's black disc.
	local round = L.round or L.gameFace
	ns.SetOutlineRound(o.outline, o.face, round, o.fade)
	Cut(o, round)
	o.head:SetShown(plain)
	o.body:SetShown(plain)
	if plain then
		-- A 3D head fills the picture more with the framing Face and less with Head and shoulders (stand-ins).
		local f = L.style == "head" and ({ face = 1.25, shoulders = 0.8 })[g.headFraming] or 1
		Box(o.head, pic, L.side * (0.5 - 0.17 * f), L.side * (0.33 - 0.17 * f), L.side * 0.34 * f, L.side * 0.34 * f)
		Box(o.body, pic, L.side * (0.5 - 0.34 * f), L.side * (1 - 0.38 * f), L.side * 0.68 * f, L.side * 0.38 * f)
		Solid(o.head, 0, 0, 0, 0.45)
		Solid(o.body, 0, 0, 0, 0.45)
	end
	-- The top of the picture fades into the background, Own background too, beside a name row that fades upward (UnitFramePortrait.lua Fade).
	local fade = L.drawn and L.tall and L.large and L.rowOn and g.portraitFade and g.stripColour == "gradient"
	o.fade:SetShown(fade and true or false)
	if fade then
		Box(o.fade, pic, 0, 0, L.side, math.min(ROW.height, L.side))
		local r, gr, b = Plate()
		Gradient(o.fade, r, gr, b, 0, g.stripFade / 100)
	end
	-- The rest animation of the game's art, around the picture of the player (UnitFrames.lua:2082).
	local rest = s.kind == "player" and L.on and g.restAnimation or "auto"
	local glow = s.kind == "player" and shown and (rest == "show" or (rest == "auto" and not (L.on and g.square and g.status)))
	o.glow:SetShown(glow and true or false)
	if glow then
		o.glow:ClearAllPoints()
		o.glow:SetPoint("TOPLEFT", pic, "TOPLEFT", -4, 4)
		o.glow:SetPoint("BOTTOMRIGHT", pic, "BOTTOMRIGHT", 4, -4)
		if HasAtlas(ART.rest[1]) then
			o.glow:SetVertexColor(1, 1, 1, 0.6)
			o.glow:SetAtlas(ART.rest[1])
		else
			Solid(o.glow, 1, 0.9, 0.4, 0.45)
		end
	end
end

-- The colour of a health fill, and the colour a dark bar hides (UnitFrameLooks.lua:98-134).
local function HealthColour(o, g)
	local k = o.k
	local r, gr, b = ns.Colour(KEY .. ".healthColour")
	local by = k.by and Get(k.by) or nil
	if by ~= "class" and by ~= "reaction" then
		by = nil
	end
	if Get("lookClassHealth") == true or by then
		r, gr, b = ByUnit(o, by, true)
	end
	r, gr, b = Mute(r, gr, b)
	if Get("lookLostColour") == true and g.backdrop then
		return DARK, DARK, DARK, { r, gr, b }
	end
	return r, gr, b, nil
end

-- The bars: borders, backgrounds, fills, the segments on the health bar and the words (UnitFrames.lua:1190-1290, UnitText.lua:313-495). In One frame a bar is a
-- cell with no border: its own background is the trough on the plate, or the colour a dark health bar hides, and its corners stay square.
function E.bars(o, g, L)
	local k, s, t = o.k, o.s, L.t
	local size = L.size
	-- The player's power at rest (REST): its colour, how full it is, and numbers to match. Every other frame shows mana at 70%.
	local token, share, powerNumbers = "MANA", FRACTION, POWER
	local rest = s.kind == "player" and REST[s.class] or nil
	if rest then
		local full = math.floor(rest[2] * 100 + 0.5)
		token, share, powerNumbers = rest[1], rest[2], { cur = full, max = 100, pct = full, miss = 100 - full }
	end
	local trough = L.joined and Trough() or nil
	for _, role in ipairs({ "health", "power" }) do
		local frame, fill = o[role], o[role .. "Fill"]
		local live = role == "health" or L.power
		local height = role == "health" and size.health or size.power
		frame:SetShown(live)
		Box(frame, o.root, L.barsLeft, role == "health" and L.healthTop or L.powerTop, size.bar, height)
		local r, gr, b, lost, file
		if role == "health" then
			r, gr, b = s.react[1], s.react[2], s.react[3]
			file = ns.BarFile("game")
			if L.on and g.flat then
				r, gr, b, lost = HealthColour(o, g)
				file = FileOf("health")
				if g.healthByLeft then
					r, gr, b = Left(FRACTION)
				end
			end
		else
			r, gr, b = ns.PowerColour(token)
			if r == nil then
				r, gr, b = 0, 0, 1
			end
			file = ns.BarFile("game")
			if L.on and g.flat then
				r, gr, b = Mute(r, gr, b)
				file = FileOf("power")
			end
		end
		o[role .. "Back"]:SetShown(live and not L.on)
		if not L.on then
			Over(o[role .. "Back"], frame)
			Solid(o[role .. "Back"], 0, 0, 0, 0.6)
		end
		-- Threat colours the health bar's border in Separate parts; in One frame it colours the frame's border (E.draw).
		local colour = nil
		if role == "health" and L.on and not L.joined and g.threat then
			colour = s.threat and THREAT or s.debuff
		end
		local outline = o[role .. "Outline"]
		EdgePaint(outline, live and L.on, g.backdrop, colour, lost or trough, true)
		if L.joined then
			ns.SetOutlineEdges(outline, false)
		end
		local radius = live and L.on and not L.joined and L.radius or nil
		Round(outline, radius, t)
		local width = size.bar * (s.dead and 0 or (role == "health" and FRACTION or share))
		fill:SetShown(live and width > 0)
		Stretch(fill, frame, 0, width, height)
		Fill(fill, file, r, gr, b, 1)
		CutFill(frame, fill, radius)
	end
	-- Heal prediction, absorb shield and heal absorb on the health bar (UnitExtras.lua:190-216).
	local bar = size.bar
	local segments = { { o.pred, FRACTION, 0.12, g.healPrediction, 0.24, 0.86, 0.39, 0.75 }, { o.shield, FRACTION + 0.12, 0.10, g.absorbShield, 1, 1, 1, 0.6 },
		{ o.absorb, FRACTION - 0.10, 0.10, g.healAbsorb, 0.47, 0.08, 0.08, 0.85 } }
	for _, segment in ipairs(segments) do
		local shown = not s.dead and (not L.on or segment[4])
		segment[1]:SetShown(shown)
		if shown then
			Stretch(segment[1], o.health, bar * segment[2], bar * (segment[2] + segment[3]), size.health)
			Solid(segment[1], segment[5], segment[6], segment[7], segment[8])
		end
	end
	-- The words on each bar: the game's own, or the format of the row; the sizes, the font, the outline and the colour of the Names and numbers step.
	local percent
	if not L.on then
		percent = 100
	elseif not L.large and not L.boss then
		percent = g.smallTextSize
	end
	for _, role in ipairs({ "health", "power" }) do
		local text, frame = o[role .. "Text"], o[role]
		local numbers = role == "health" and HEALTH or powerNumbers
		local row = role == "health" and k.ht or k.pt
		local mode = "game"
		if L.on and row then
			mode = Get(row .. (role == "health" and "HealthText" or "PowerText")) or "game"
		end
		local words
		if mode == "game" then
			words = GameWords(numbers)
		elseif mode ~= "hide" then
			words = Words(mode, numbers)
		end
		-- Show: while the mouse is over the frame. Nothing is over a frame in a drawing.
		if mode ~= "game" and g.ownTextWhen == "hover" then
			words = nil
		end
		if s.dead or (L.on and role == "power" and Get("lookNoPowerText") == true) or not (role == "health" or L.power) then
			words = nil
		end
		text:SetShown(words ~= nil)
		if words then
			text:SetText(words)
			local spec = { percent = percent or (role == "health" and g.healthTextSize or g.powerTextSize) }
			if L.on then
				local light = g.lightText and not L.boss
				if light then
					spec.percent = spec.percent * 0.85
					spec.flags = ""
				end
				spec.face = g.barTextFace ~= "default" and ns.FontFile(g.barTextFace) or nil
				if FLAGS[g.barTextOutline] ~= nil then
					spec.flags = FLAGS[g.barTextOutline]
				end
				if g.barTextOwn then
					spec.r, spec.g, spec.b = ns.Colour(KEY .. ".barTextColour")
				end
			end
			Style(text, spec)
			local at, offset = "CENTER", 0
			if mode ~= "game" and L.on then
				local pos = Get(role .. "TextPos")
				at = pos == "left" and "LEFT" or pos == "right" and "RIGHT" or "CENTER"
				offset = pos == "left" and 3 or pos == "right" and -3 or 0
			end
			text:ClearAllPoints()
			text:SetPoint(at, frame, at, offset, 0)
			text:SetJustifyH(at)
		end
	end
	-- Dead text on the health bar of a dead unit (UnitParts.lua:117-127).
	local dead = s.dead and (not L.on or g.deadText)
	o.deadText:SetShown(dead and true or false)
	if dead then
		o.deadText:SetText("Dead")
		o.deadText:ClearAllPoints()
		o.deadText:SetPoint("CENTER", o.health, "CENTER", 0, 0)
	end
end

-- The name row: its colour, its texts and the kind of the unit (UnitFrames.lua:1380-1700).
function E.row(o, g, L)
	local k, s, t, row = o.k, o.s, L.t, o.row
	local size = L.size
	local rowOn = L.rowOn
	-- The row's corners: those of Corners in Separate parts; in One frame the row is a square cell on the plate.
	local radius = not L.joined and L.radius or nil
	row:SetShown(true)
	local mode = "dark"
	if rowOn then
		-- The colour (UnitFrames.lua RowColour): the class of a player, the owner's class for a pet, the reaction of any other unit, the target, focus and boss
		-- too; muted, at Name background brightness, then, unless the row is dark, scaled down to a lightness of CAP so that the name reads on it.
		local rr, rg, rb = Mute(UnitColour(o))
		local bright = g.stripBrightness / 100
		rr, rg, rb = rr * bright, rg * bright, rb * bright
		mode = g.stripColour
		local cap, light = CAP[mode], 0.30 * rr + 0.59 * rg + 0.11 * rb
		if cap and light > cap then
			rr, rg, rb = rr * cap / light, rg * cap / light, rb * cap / light
		end
		Box(row, o.root, L.rowLeft, L.rowTop, L.rowWidth, L.rowH)
		local top = ROW.strong * (100 - g.stripFade) / 100
		local br, bg, bb, alpha = Plate()
		-- In Separate parts the player's row has an opaque base in the background colour, where the game's band behind the name may show through
		-- (UnitFrames.lua PaintRow); One frame has none.
		local base = s.kind == "player" and not L.joined
		o.rBase:SetShown(base)
		Over(o.rBase, row)
		if radius then
			Shaped(o.rBase, radius, br, bg, bb, 1)
		else
			Solid(o.rBase, br, bg, bb, 1)
		end
		o.rGrad:SetShown(mode == "gradient")
		-- A dark row is the background with a mark of the colour at its left end; in One frame it is the mark alone, on the plate.
		o.rFill:SetShown(mode ~= "gradient" and not (L.joined and mode == "dark"))
		Over(o.rGrad, row)
		Over(o.rFill, row)
		if mode == "gradient" then
			if radius then
				Shaped(o.rGrad, radius, 1, 1, 1, 1)
			end
			Gradient(o.rGrad, rr, rg, rb, ROW.strong, top, radius ~= nil)
		elseif mode == "flat" then
			if radius then
				Shaped(o.rFill, radius, rr, rg, rb, ROW.strong)
			else
				Solid(o.rFill, rr, rg, rb, ROW.strong)
			end
		else
			if radius then
				Shaped(o.rFill, radius, br, bg, bb, alpha)
			else
				Solid(o.rFill, br, bg, bb, alpha)
			end
		end
		o.rMark:SetShown(mode == "dark")
		if mode == "dark" then
			o.rMark:ClearAllPoints()
			o.rMark:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
			o.rMark:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
			o.rMark:SetWidth(ROW.accent)
			Solid(o.rMark, rr, rg, rb, 1)
		end
	else
		Box(row, o.root, L.barsLeft, L.nameTop, size.bar, NAMEH)
		for _, texture in ipairs({ o.rBase, o.rGrad, o.rFill, o.rMark }) do
			texture:Hide()
		end
	end
	-- The colour of the name: the game's, white, the unit's own, or the custom colour (UnitText.lua).
	local nr, ng, nb = GOLD[1], GOLD[2], GOLD[3]
	if L.on and g.nameColour == "white" then
		nr, ng, nb = 1, 1, 1
	elseif L.on and g.nameColour == "custom" then
		nr, ng, nb = ns.Colour(KEY .. ".nameCustom")
	elseif L.on and (g.nameColour == "class" or g.nameColour == "reaction") then
		nr, ng, nb = ByUnit(o, g.nameColour)
	end
	o.name:SetShown(not L.on or Get(k.name) ~= false)
	o.name:SetText(s.name)
	local spec = { percent = 100, r = nr, g = ng, b = nb }
	if L.on then
		spec.face = g.nameFace ~= "default" and ns.FontFile(g.nameFace) or nil
		spec.flags = FLAGS[g.nameOutline]
		spec.percent = g.nameSize
		if not rowOn and not L.large and not L.boss then
			spec.percent = g.smallTextSize * g.nameSize / 100
		end
	end
	Style(o.name, spec)
	-- Long names: a name wider than the row is set smaller, down to 75% (UnitExtras.lua, FitName).
	if rowOn and L.on and g.fit[s.kind] == "shrink" then
		local ok, need = pcall(o.name.GetUnboundedStringWidth or o.name.GetStringWidth, o.name)
		local room = L.rowWidth - 2 * ROW.pad
		if ok and not ns.IsSecret(need) and type(need) == "number" and need > room then
			spec.percent = spec.percent * math.max(0.75, room / need)
			Style(o.name, spec)
		end
	end
	-- The level: in the row at the end or before the name, loose beside the name while there is no row, hidden, or on the picture.
	local rowLevel = L.levelOn and rowOn and (L.at == "end" or L.at == "before")
	o.level:SetShown(rowLevel or (L.levelOn and not rowOn))
	o.level:SetText(tostring(s.level))
	local lcol = s.lcol or GOLD
	local lr, lg, lb = lcol[1], lcol[2], lcol[3]
	if rowOn and g.levelColour == "white" then
		lr, lg, lb = 1, 1, 1
	elseif rowOn and g.levelColour == "name" then
		lr, lg, lb = nr, ng, nb
	end
	L.lr, L.lg, L.lb = lr, lg, lb
	local share = rowOn and ROW.sizes[g.levelSize] or 1
	Style(o.level, { percent = 100 * share, r = lr, g = lg, b = lb })
	-- The mark after the level, the word of the kind and the line under the row (UnitFrames.lua:1577-1600).
	local look = rowOn and s.rank and ns.KINDS[s.rank] or nil
	local mark = look and look.mark and g.kindMark and rowLevel and look.mark or nil
	o.kmark:SetShown(mark ~= nil)
	if mark then
		o.kmark:SetText(mark)
		Style(o.kmark, { percent = 100 * share, r = look.colour[1], g = look.colour[2], b = look.colour[3] })
	else
		o.kmark:SetText("")
	end
	local word = look and g.kindWord and look.word or nil
	o.kword:SetShown(word ~= nil)
	if word then
		o.kword:SetText(word)
		Style(o.kword, { percent = 100, r = look.colour[1], g = look.colour[2], b = look.colour[3] })
	else
		o.kword:SetText("")
	end
	local line = look ~= nil and g.kindLine
	o.rLine:SetShown(line and true or false)
	if line then
		o.rLine:ClearAllPoints()
		o.rLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", radius or 0, 0)
		o.rLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(radius or 0), 0)
		o.rLine:SetHeight(t)
		Solid(o.rLine, look.colour[1], look.colour[2], look.colour[3], 1)
	end
	-- How the PvP flag shows: the plate on a corner of the picture, the word in the name row, both, or neither (UnitFrames.lua:1819-1960, UnitParts.lua:150-161).
	local pvp = nil
	if s.flag and o.pic then
		pvp = "game"
		if L.drawn then
			pvp = g.pvpFlag
			if (pvp == "word" or pvp == "both") and not (L.large and rowOn) then
				pvp = "icon"
			end
		end
		if not g.pvpIcon then
			pvp = (pvp == "both" and "word") or ((pvp == "icon" or pvp == "game") and "off") or pvp
		end
	end
	L.pvp = pvp
	local word2 = pvp == "word" or pvp == "both"
	o.flag:SetShown(word2)
	if word2 then
		o.flag:SetText(s.flag .. ((g.pvpTimer and s.own) and (" " .. s.timer) or ""))
		local fr, fg, fb = 1, 1, 1
		if g.pvpWordColour == "red" then
			fr, fg, fb = 1, 0.1, 0.1
		elseif g.pvpWordColour == "name" then
			fr, fg, fb = nr, ng, nb
		end
		Style(o.flag, { percent = 100, r = fr, g = fg, b = fb })
	end
	-- The anchors of the texts, from the level position (UnitFrames.lua:942-1000).
	local ranked = k.ranked
	local levelRoom = (L.levelOn and L.at == "end" and rowOn) and ROW.levelRoom or 0
	local pvpRoom = (rowOn and (g.pvpFlag == "word" or g.pvpFlag == "both") and L.large) and (ROW.flagRoom + ((s.kind == "player" and g.pvpTimer) and ROW.timerRoom or 0)) or 0
	for _, text in ipairs({ o.level, o.kmark, o.kword, o.flag, o.name }) do
		text:ClearAllPoints()
	end
	if rowOn then
		local at = L.at
		o.level:SetJustifyH(at == "before" and "LEFT" or "RIGHT")
		if at == "before" then
			o.level:SetPoint("LEFT", row, "LEFT", ROW.pad, 0)
			if ranked then
				o.kmark:SetPoint("LEFT", o.level, "RIGHT", ROW.gap, 0)
			end
		elseif at == "end" then
			o.kmark:SetPoint("RIGHT", row, "RIGHT", ROW.gap - ROW.pad, 0)
			if ranked then
				o.level:SetPoint("RIGHT", o.kmark, "LEFT", -ROW.gap, 0)
			else
				o.level:SetPoint("RIGHT", row, "RIGHT", -ROW.pad, 0)
			end
		end
		if at == "before" then
			o.name:SetPoint("LEFT", ranked and o.kmark or o.level, "RIGHT", ROW.wordGap, 0)
		else
			o.name:SetPoint("LEFT", row, "LEFT", ROW.pad, 0)
		end
		if ranked then
			if at == "end" then
				o.kword:SetPoint("RIGHT", o.kmark, "LEFT", ROW.wordGap - ROW.gap - levelRoom, 0)
			else
				o.kword:SetPoint("RIGHT", row, "RIGHT", ROW.wordGap - ROW.pad, 0)
			end
			o.flag:SetPoint("RIGHT", o.kword, "LEFT", -ROW.wordGap, 0)
			o.name:SetPoint("RIGHT", o.kword, "LEFT", -ROW.wordGap - pvpRoom, 0)
		else
			o.flag:SetPoint("RIGHT", row, "RIGHT", -ROW.pad - levelRoom, 0)
			o.name:SetPoint("RIGHT", row, "RIGHT", -ROW.pad - levelRoom - pvpRoom, 0)
		end
	else
		o.name:SetPoint("LEFT", row, "LEFT", 0, 0)
		o.level:SetJustifyH("RIGHT")
		o.level:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		o.flag:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	end
end

-- The icons on and beside the picture, and the level on the picture (UnitParts.lua:95-139, UnitFrameLevel.lua).
function E.icons(o, g, L)
	local s, k, root = o.s, o.k, o.root
	o.top:SetAllPoints(root)
	for _, icon in ipairs({ o.leader, o.attack, o.role, o.plateIcon, o.marker, o.happy }) do
		icon:Hide()
	end
	o.picLevel:Hide()
	o.pvpTimer:Hide()
	o.shade:Hide()
	local function Marker(anchor, point, relative, x, y)
		local index = s.marker - 1
		o.marker:SetTexture(MARKER)
		o.marker:SetVertexColor(1, 1, 1, 1)
		o.marker:SetTexCoord((index % 4) * 0.25, (index % 4) * 0.25 + 0.25, math.floor(index / 4) * 0.25, math.floor(index / 4) * 0.25 + 0.25)
		o.marker:ClearAllPoints()
		o.marker:SetSize(ICON, ICON)
		o.marker:SetPoint(point, anchor, relative, x, y)
		o.marker:Show()
	end
	if o.pic then
		local shown = L.drawn or L.gameFace
		local px, py, side = L.picLeft, L.picTop, L.side
		-- On a round picture the level and the PvP plate move in by INSET of the side on both axes, onto the circle at 45 degrees (UnitFrameLevel.lua
		-- Update, UnitFrames.lua PlacePlate).
		local inset = L.round and INSET * side or 0
		if L.drawn and L.levelOn and L.at == "portrait" and L.rowOn then
			local text = tostring(s.level)
			local look = s.rank and ns.KINDS[s.rank] or nil
			if look and look.mark and g.kindMark then
				text = text .. " " .. look.mark
			end
			o.picLevel:SetText(text)
			o.picLevel:ClearAllPoints()
			o.picLevel:SetPoint("BOTTOMRIGHT", o.pic, "BOTTOMRIGHT", -2 - inset, 2 + inset)
			Style(o.picLevel, { percent = 100, flags = "OUTLINE", r = L.lr, g = L.lg, b = L.lb })
			o.picLevel:Show()
		end
		if shown and s.leader and g.leaderIcon then
			Art(o.leader, "leader")
			Mark(o.leader, root, px - 4, py - 5)
		end
		if shown and s.kind == "player" and s.state and g.combatIcon then
			Art(o.attack, "attack")
			Mark(o.attack, root, px + side - ICON + 4, py - 5)
		end
		if shown and s.role and g.roleIcon then
			Art(o.role, s.role)
			Mark(o.role, root, px - 2, py + side - ICON + 2)
		end
		if shown and (L.pvp == "icon" or L.pvp == "both" or L.pvp == "game") then
			Art(o.plateIcon, "pvp")
			-- The plate's centre is half a plate in from the corner, so that it sits inside the picture, and INSET more on a round one.
			local corner = L.pvp == "game" and "bl" or g.pvpCorner
			local right, low = corner == "tr" or corner == "br", corner == "bl" or corner == "br"
			local cx = px + (right and (side - ICON / 2 - inset) or (ICON / 2 + inset))
			local cy = py + (low and (side - ICON / 2 - inset) or (ICON / 2 + inset))
			Mark(o.plateIcon, root, cx - ICON / 2, cy - ICON / 2)
			local timer = s.own and g.pvpTimer and (L.pvp == "icon" or L.pvp == "game")
			o.pvpTimer:SetShown(timer and true or false)
			if timer then
				o.pvpTimer:SetText(s.timer)
				o.pvpTimer:ClearAllPoints()
				o.pvpTimer:SetPoint("LEFT", o.plateIcon, "RIGHT", 1, 0)
				Style(o.pvpTimer, { percent = 100, r = 1, g = 1, b = 1 })
			end
		end
		if shown and s.marker and g.raidMarker and (s.kind == "target" or s.kind == "focus") then
			Marker(o.pic, "BOTTOM", "TOP", 0, 1)
		end
		if shown and s.happy and g.petHappiness then
			Art(o.happy, "happy")
			Mark(o.happy, root, px + side - ICON + 2, py + side - ICON + 2)
		end
	elseif s.marker and g.raidMarker then
		Marker(o.health, "RIGHT", "LEFT", -2, 0)
	end
	-- A party member out of range is dimmed by a black layer of the frame's own (UnitExtras.lua:28-60).
	local dim = s.away and L.on and Get("partyRangeDim") == true
	o.shade:SetShown(dim and true or false)
	if dim then
		Over(o.shade, root)
		Solid(o.shade, 0, 0, 0, 1 - Get("partyRangeOpacity") / 100)
	end
end

-- The icons of the auras: below the frame, or beside a party frame (UnitFrames.lua:2422-2530).
function E.auras(o, g, L)
	local s, root = o.s, o.root
	local ax, ay = L.barsLeft, L.height + 2
	local bottom, right = L.height, L.width
	for index, icon in ipairs(o.auras) do
		local aura = icon.aura
		local px, py = ax + (index - 1) * (ICON + 2), ay
		if s.kind == "party" then
			px, py = L.width + 2, L.healthTop + (index - 1) * (ICON + 2)
		end
		icon.frame:SetSize(ICON, ICON)
		icon.frame:ClearAllPoints()
		icon.frame:SetPoint("TOPLEFT", root, "TOPLEFT", px, -py)
		icon.frame:Show()
		icon.texture:SetTexture(AURA_FILE)
		local styled = L.on and g.auras
		local crop = styled and g.auraCrop / 100 or 0
		icon.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		local bordering = (aura[3] and TYPE.steal) or (aura[2] ~= "none" and TYPE[aura[2]]) or nil
		EdgePaint(icon.outline, styled, false, styled and g.auraTypeColours and bordering or nil)
		-- The border the game draws on an icon it does not style: a ring in the colour of its type.
		icon.ring:SetShown(not styled)
		if not styled then
			icon.ring:ClearAllPoints()
			icon.ring:SetPoint("TOPLEFT", icon.frame, "TOPLEFT", -2, 2)
			icon.ring:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", 2, -2)
			local c = bordering or { 0.5, 0.5, 0.5 }
			Solid(icon.ring, c[1], c[2], c[3], 1)
		end
		local counted = aura[4] ~= nil
		icon.count:SetShown(counted)
		if counted then
			icon.count:SetText(tostring(aura[4]))
			icon.count:ClearAllPoints()
			icon.count:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", 1, -1)
			Style(icon.count, { percent = L.on and g.auraCountSize or 100, flags = "OUTLINE", r = 1, g = 1, b = 1 })
		end
		local timed = aura[5] ~= nil and L.on and g.auraNumbers
		icon.time:SetShown(timed and true or false)
		if timed then
			icon.time:SetText(aura[5])
			icon.time:ClearAllPoints()
			icon.time:SetPoint("CENTER", icon.frame, "CENTER", 0, 0)
			Style(icon.time, { percent = 100, flags = "OUTLINE", r = 1, g = 1, b = 1 })
		end
		bottom, right = math.max(bottom, py + ICON), math.max(right, px + ICON)
	end
	L.height, L.width = bottom, right
end

-- Draws one frame at the top left corner of its root. Sets o.width and o.height.
function E.draw(o, g)
	local L = Layout(o, g)
	o.root:SetSize(L.width, L.height)
	local k = o.k
	o.plate:SetShown(not L.on)
	if not L.on then
		Box(o.plate, o.root, 0, 0, L.width, L.height)
		Solid(o.plate, 0.13, 0.12, 0.11, 1)
	end
	-- One frame: the one colour of the frame's border (FrameColour), worked out first so that a round picture's ring takes it too, and Portrait border None,
	-- which leaves the plain border off with Flat UI portraits on, a boss frame's too (UnitFramePortrait.lua Colour).
	if L.joined then
		L.colour = FrameColour(o, g)
		L.bare = (g.square and g.portraitBorder == "none" and L.colour == nil) and true or false
	end
	-- The body: in One frame the plate behind every part, at Background, and the frame's one border, with Border, Borderless and the corners. In Separate
	-- parts there is none: it is hidden, so that the options window finds the frame under the pointer, and placed for the mark of its rows.
	Box(o.box, o.root, L.bodyLeft, L.bodyTop, L.bodyWidth, L.bodyHeight)
	o.box:SetShown(L.joined)
	EdgePaint(o.boxOutline, L.joined, g.backdrop, L.colour, nil, true)
	ns.SetOutlineBare(o.boxOutline, L.bare)
	Round(o.boxOutline, L.joined and L.radius or nil, L.t)
	-- The shadow behind a styled frame (UnitFrameLooks.lua Place): round the body in One frame; else from the picture, while it is drawn, on its side, or the
	-- bars, to the bars' other end, and from the name row to the power bar.
	local shadow = L.on and g.lookShadow
	o.shadow:SetShown(shadow and true or false)
	if shadow then
		local left, top, right, bottom = L.bodyLeft, L.bodyTop, L.bodyLeft + L.bodyWidth, L.bodyTop + L.bodyHeight
		if not L.joined then
			left = (L.drawn and not L.right) and L.picLeft or L.barsLeft
			right = (L.drawn and L.right) and (L.picLeft + L.side) or (L.barsLeft + L.size.bar)
			top, bottom = L.rowTop or L.healthTop, L.bottom
		end
		o.shadow:ClearAllPoints()
		o.shadow:SetPoint("TOPLEFT", o.root, "TOPLEFT", left - SHADOW.out, -(top - SHADOW.out))
		o.shadow:SetPoint("BOTTOMRIGHT", o.root, "TOPLEFT", right + SHADOW.out, -(bottom + SHADOW.out))
		o.shadow:SetTexture(SHADOW.file)
		Slice(o.shadow)
		o.shadow:SetVertexColor(0, 0, 0, SHADOW.alpha)
	end
	if o.pic then
		E.picture(o, g, L)
	end
	E.bars(o, g, L)
	E.row(o, g, L)
	E.icons(o, g, L)
	E.auras(o, g, L)
	o.width, o.height = L.width, L.height
	o.root:SetSize(L.width, L.height)
	o.layout = L
	return k
end

-- A totem button -------------------------------------------------------------------------------------------------------------------------

local T = {}

function T.make(stage)
	local o = { id = "totem", draw = T.draw, cap = nil }
	o.root = Frame(stage)
	o.ring = Tex(o.root, "BACKGROUND", -5)
	local icon = ns.IconNew(o.root)
	o.icon = icon
	o.swipe = Tex(o.root, "OVERLAY", 3)
	o.time = Text(o.root)
	o.time:SetJustifyH("CENTER")
	o.sample = { cap = "Totem" }
	o.parts = { root = o.root, swipe = o.swipe, time = o.time, icon = icon and icon.frame }
	return o
end

function T.draw(o, g)
	local on = g.enabled and Get("totem") == true
	local size = 28
	local pad = 3
	o.width, o.height = size + 2 * pad, size + 2 * pad
	o.root:SetSize(o.width, o.height)
	local icon = o.icon
	if icon then
		icon.frame:ClearAllPoints()
		icon.frame:SetSize(size, size)
		icon.frame:SetPoint("TOPLEFT", o.root, "TOPLEFT", pad, -pad)
		icon.frame:Show()
		icon.texture:SetTexture(AURA_FILE)
		local crop = on and 0 or 0.08
		icon.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		EdgePaint(icon.outline, on, g.backdrop)
	end
	o.ring:SetShown(not on)
	if not on then
		Over(o.ring, o.root)
		Solid(o.ring, 0.55, 0.45, 0.25, 1)
	end
	local swipe = not on or Get("totemSwipe") == true
	o.swipe:SetShown(swipe)
	if swipe then
		o.swipe:ClearAllPoints()
		o.swipe:SetPoint("TOPLEFT", o.root, "TOPLEFT", pad, -pad)
		o.swipe:SetSize(size, size * 0.45)
		Solid(o.swipe, 0, 0, 0, 0.6)
	end
	local time = not on or Get("totemTimer") == true
	o.time:SetShown(time)
	if time then
		o.time:SetText("12")
		o.time:ClearAllPoints()
		o.time:SetPoint("CENTER", o.root, "CENTER", 0, 0)
		Style(o.time, { percent = 100, flags = "OUTLINE", r = 1, g = 1, b = 1 })
	end
end

-- A block of raid cells ------------------------------------------------------------------------------------------------------------------

local R = {}
local CELL = { width = 64, height = 32, gap = 3, thin = 4, game = 8 }
local RAID = { { "Aria", "WARRIOR", "tank" }, { "Bex", "MAGE", "damage" }, { "Cole", "HUNTER", "damage" }, { "Dru", "DRUID", "healer" },
	{ "Eli", "PRIEST", "healer" }, { "Fay", "ROGUE", "damage" }, { "Gus", "SHAMAN", "damage" }, { "Hale", "PALADIN", "tank" },
	{ "Ivo", "WARLOCK", "damage" }, { "Jun", "WARRIOR", "damage" } }

function R.make(stage, count, columns)
	local o = { id = "raid", draw = R.draw, cells = {}, columns = columns }
	o.root = Frame(stage)
	o.sample = { cap = "Raid" }
	for index = 1, count do
		local data = RAID[index]
		local cell = { data = data, index = index }
		cell.frame = Frame(o.root)
		cell.plate = Tex(cell.frame, "BACKGROUND", -7)
		cell.hback = Tex(cell.frame, "BACKGROUND", -6)
		cell.health = Frame(cell.frame)
		cell.hOutline = ns.Outline(cell.health, cell.health)
		ns.SetOutlineArea(cell.hOutline, KEY)
		cell.hFill = Tex(cell.health, "ARTWORK", 0)
		cell.power = Frame(cell.frame)
		cell.pOutline = ns.Outline(cell.power, cell.power)
		ns.SetOutlineArea(cell.pOutline, KEY)
		cell.pFill = Tex(cell.power, "ARTWORK", 0)
		cell.top = Frame(cell.frame)
		cell.name = Text(cell.top)
		cell.status = Text(cell.top)
		cell.role = Tex(cell.top, "OVERLAY", 2)
		o.cells[index] = cell
	end
	local first = o.cells[1]
	o.parts = { root = o.root, cell = first and first.frame, health = first and first.health, power = first and first.power, name = first and first.name,
		status = first and first.status, role = first and first.role }
	return o
end

function R.draw(o, g)
	local on = g.enabled and Get("raid") == true
	local cells = on and Get("raidCells") == true
	local t = g.t
	local columns = o.columns
	local rows = math.ceil(#o.cells / columns)
	for index, cell in ipairs(o.cells) do
		local data = cell.data
		local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
		Box(cell.frame, o.root, column * (CELL.width + CELL.gap), row * (CELL.height + CELL.gap), CELL.width, CELL.height)
		local dead, away, threat = index == 7, index == 8, index == 3
		-- The range of the cell: Out of range opacity for a member out of range, the game's own half for every cell while the frames are not styled.
		local alpha = away and (on and Get("raidRangeAlpha") or 50) / 100 or 1
		cell.frame:SetAlpha(alpha)
		local powerHeight = cells and CELL.thin or CELL.game
		local inset = on and t or 2
		local healthHeight = CELL.height - 2 * inset - powerHeight - (cells and 2 * t or 0)
		cell.plate:SetShown(not cells)
		if not cells then
			Over(cell.plate, cell.frame)
			Solid(cell.plate, 0.20, 0.18, 0.15, 1)
		end
		Box(cell.health, cell.frame, inset, inset, CELL.width - 2 * inset, healthHeight)
		Box(cell.power, cell.frame, inset, CELL.height - inset - powerHeight, CELL.width - 2 * inset, powerHeight)
		cell.hback:SetShown(not on)
		if not on then
			Over(cell.hback, cell.health)
			Solid(cell.hback, 0, 0, 0, 0.6)
		end
		-- The health bar: the colour of the class, which the game gives it, in the image of the health row; grey for a unit that is dead with Raid cell look on.
		local r, gr, b = ClassRgb(data[2])
		if cells and dead then
			r, gr, b = 0.5, 0.5, 0.5
		end
		local file = on and g.flat and FileOf("health") or ns.BarFile("game")
		EdgePaint(cell.hOutline, on, g.backdrop, threat and g.threat and on and THREAT or nil, nil, true)
		Round(cell.hOutline, on and g.radius or nil, t)
		Stretch(cell.hFill, cell.health, 0, (CELL.width - 2 * inset) * (dead and 1 or FRACTION), healthHeight)
		Fill(cell.hFill, file, r, gr, b, 1)
		-- The power bar: thin and bordered with Raid cell look on, else the game's.
		local pr, pg, pb = ns.PowerColour("MANA")
		if pr == nil then
			pr, pg, pb = 0, 0, 1
		end
		local pfile = cells and g.flat and FileOf("power") or ns.BarFile("game")
		EdgePaint(cell.pOutline, cells, g.backdrop, nil, nil, true)
		Round(cell.pOutline, cells and g.radius or nil, t)
		Stretch(cell.pFill, cell.power, 0, (CELL.width - 2 * inset) * 0.7, powerHeight)
		Fill(cell.pFill, pfile, Mute(pr, pg, pb))
		-- The name, the role icon and the status text (UnitExtras.lua:159-169).
		cell.top:SetAllPoints(cell.frame)
		local nameOn = not on or Get("raidName") == true
		cell.name:SetShown(nameOn)
		cell.name:SetText(data[1])
		cell.name:ClearAllPoints()
		cell.name:SetPoint("LEFT", cell.frame, "LEFT", 14, 3)
		Style(cell.name, { percent = 100, r = 1, g = 1, b = 1 })
		local roleOn = not on or Get("raidRoleIcon") == true
		cell.role:SetShown(roleOn)
		if roleOn then
			Art(cell.role, data[3])
			cell.role:ClearAllPoints()
			cell.role:SetSize(10, 10)
			cell.role:SetPoint("LEFT", cell.frame, "LEFT", inset + 1, 3)
		end
		local statusOn = dead and (not on or Get("raidStatusText") == true)
		cell.status:SetShown(statusOn and true or false)
		if statusOn then
			cell.status:SetText("Dead")
			cell.status:ClearAllPoints()
			cell.status:SetPoint("CENTER", cell.frame, "CENTER", 0, -4)
			Style(cell.status, { percent = 100, r = 0.8, g = 0.8, b = 0.8 })
		end
	end
	o.width = columns * CELL.width + (columns - 1) * CELL.gap
	o.height = rows * CELL.height + (rows - 1) * CELL.gap
	o.root:SetSize(o.width, o.height)
end

-- Scenes ----------------------------------------------------------------------------------------------------------------------------------

-- The frame a path marks in each drawing: { item, part }. A path whose item the drawing does not have has no mark.
local MARK = {
	enabled = { "player", "root" }, player = { "player", "root" }, target = { "target", "root" }, focus = { "focus", "root" }, pet = { "pet", "root" }, tot = { "tot", "root" },
	party = { "party1", "root" }, partypet = { "partypet1", "root" }, boss = { "boss", "root" }, raid = { "raid", "root" }, totem = { "totem", "root" },
	petSize = { "pet", "root" }, petSizeBasis = { "pet", "root" }, petSizePct = { "pet", "root" }, playerScale = { "player", "root" }, targetScale = { "target", "root" },
	focusScale = { "focus", "root" }, partyScale = { "party1", "root" }, bossScale = { "boss", "root" }, raidScale = { "raid", "root" },
	portraitStyle = { "player", "pic" }, portraitSize = { "player", "pic" }, portraitBorder = { "player", "pic" }, classShape = { "player", "pic" }, portraitFade = { "player", "pic" }, headFraming = { "player", "pic" },
	portraitPlayer = { "player", "pic" }, portraitTarget = { "target", "pic" }, portraitFocus = { "focus", "pic" }, portraitPet = { "pet", "pic" },
	portraitTot = { "tot", "pic" }, portraitParty = { "party1", "pic" }, portraitPartypet = { "partypet1", "pic" }, squarePortrait = { "player", "pic" },
	frameStyle = { "player", "body" }, powerSpace = { "player", "body" }, barBorder = { "player", "body" }, corners = { "player", "body" }, elite = { "target", "pic" },
	backdrop = { "player", "body" }, flat = { "player", "health" }, healthColour = { "player", "health" }, healthTexture = { "player", "health" },
	powerTexture = { "player", "power" }, healthByLeft = { "player", "health" }, status = { "player", "pic" }, threat = { "boss", "health" },
	healPrediction = { "player", "pred" }, absorbShield = { "player", "shield" }, healAbsorb = { "player", "absorb" }, lookOwn = { "player", "health" },
	lookBorder = { "player", "health" }, lookBack = { "player", "health" }, lookBackAlpha = { "player", "health" },
	smallRow = { "pet", "row" }, levelPosition = { "target", "level" }, levelColour = { "player", "level" }, pvpWordColour = { "player", "level" }, levelSize = { "player", "level" },
	raidCells = { "raid", "cell" }, strip = { "player", "row" }, stripColour = { "player", "row" }, stripFade = { "player", "row" }, stripBrightness = { "player", "row" },
	kindMark = { "target", "kmark" }, kindWord = { "target", "kword" }, kindLine = { "target", "kline" },
	nameFace = { "player", "name" }, nameSize = { "player", "name" }, nameOutline = { "player", "name" }, nameColour = { "player", "name" }, nameCustom = { "player", "name" },
	healthTextSize = { "player", "healthText" }, powerTextSize = { "player", "powerText" }, smallTextSize = { "pet", "healthText" }, barTextFace = { "player", "healthText" },
	barTextOutline = { "player", "healthText" }, barTextColourOwn = { "player", "healthText" }, barTextColour = { "player", "healthText" },
	lookClassHealth = { "player", "health" }, lookLostColour = { "player", "health" }, lookMuted = { "player", "health" },
	lookLightText = { "player", "healthText" }, lookNoPowerText = { "player", "powerText" }, lookSoftShade = { "player", "health" }, lookShadow = { "player", "shadow" },
	numberStyle = { "player", "healthText" }, ownTextWhen = { "player", "healthText" }, healthTextPos = { "player", "healthText" }, powerTextPos = { "player", "powerText" },
	auras = { "target", "aura" }, auraCrop = { "target", "aura" }, auraTypeColours = { "target", "aura" }, auraCountSize = { "party1", "count" },
	auraNumbers = { "party1", "time" }, pvpFlag = { "player", "plate" }, pvpCorner = { "player", "plate" }, pvpTimer = { "player", "timer" }, leaderIcon = { "player", "leader" },
	roleIcon = { "party1", "role" }, pvpIcon = { "player", "plate" }, raidMarker = { "target", "marker" }, deadText = { "boss2", "dead" }, totemTimer = { "totem", "time" },
	totemSwipe = { "totem", "swipe" }, combatIcon = { "player", "attack" }, petHappiness = { "pet", "happy" }, restAnimation = { "player", "pic" },
	playerPicture = { "player", "pic" }, playerName = { "player", "name" }, playerLevel = { "player", "level" }, playerHealthBy = { "player", "health" },
	playerHealthText = { "player", "healthText" }, playerPowerText = { "player", "powerText" }, playerPowerBar = { "player", "power" },
	targetPicture = { "target", "pic" }, targetName = { "target", "name" }, targetLevel = { "target", "level" }, targetHealthBy = { "target", "health" },
	targetHealthText = { "target", "healthText" }, targetPowerText = { "target", "powerText" }, targetPowerBar = { "target", "power" },
	focusPicture = { "focus", "pic" }, focusName = { "focus", "name" }, focusLevel = { "focus", "level" }, focusHealthBy = { "focus", "health" },
	focusHealthText = { "focus", "healthText" }, focusPowerText = { "focus", "powerText" }, focusPowerBar = { "focus", "power" },
	petPicture = { "pet", "pic" }, petName = { "pet", "name" }, petNameFit = { "pet", "name" }, petHealthBy = { "pet", "health" }, petHealthText = { "pet", "healthText" },
	petPowerText = { "pet", "powerText" }, petPowerBar = { "pet", "power" },
	totPicture = { "tot", "pic" }, totName = { "tot", "name" }, totNameFit = { "tot", "name" }, totHealthBy = { "tot", "health" }, totPowerBar = { "tot", "power" },
	partyPicture = { "party1", "pic" }, partypetPicture = { "partypet1", "pic" }, partyName = { "party1", "name" }, partyNameFit = { "party1", "name" }, partyHealthBy = { "party1", "health" },
	partyHealthText = { "party1", "healthText" }, partyPowerText = { "party1", "powerText" }, partyPowerBar = { "party1", "power" },
	partyRangeDim = { "party4", "root" }, partyRangeOpacity = { "party4", "root" },
	bossName = { "boss", "name" }, bossNameFit = { "boss", "name" }, bossPowerText = { "boss", "powerText" }, bossLevel = { "boss", "level" }, bossHealthBy = { "boss", "health" }, bossHealthText = { "boss", "healthText" },
	bossPowerBar = { "boss", "power" },
	raidRangeAlpha = { "raid", "cell" }, raidRoleIcon = { "raid", "role" }, raidName = { "raid", "name" }, raidStatusText = { "raid", "status" },
}

-- Builds a scene: the frames of a list of items on a root frame, with a caption under each. make: the function for an item that is not a unit frame.
-- spec.ground = false leaves out the ground, for a stage that has a ground of its own.
local function BuildScene(stage, spec)
	local scene = { root = Frame(stage), items = {}, spec = spec, parts = {} }
	scene.root:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
	-- The ground: GROUND under every frame, 6 units round the scene, so that a see-through background shows the world behind it as in the game.
	scene.ground = Tex(scene.root, "BACKGROUND", -8)
	scene.ground:SetPoint("TOPLEFT", scene.root, "TOPLEFT", -6, 6)
	scene.ground:SetPoint("BOTTOMRIGHT", scene.root, "BOTTOMRIGHT", 6, -6)
	Solid(scene.ground, GROUND[1], GROUND[2], GROUND[3], 1)
	scene.ground:SetShown(spec.ground ~= false)
	for _, id in ipairs(spec.ids) do
		local item
		if id == "totem" then
			item = T.make(scene.root)
		elseif id == "raid" then
			item = R.make(scene.root, spec.raid[1] * spec.raid[2], spec.raid[1])
		else
			item = E.make(scene.root, id)
		end
		local sample = item.s or item.sample
		item.cap = sample and sample.cap and Text(scene.root) or nil
		if item.cap then
			item.cap:SetText(sample.cap)
			item.cap:SetTextColor(0.6, 0.62, 0.66, 1)
		end
		scene.items[#scene.items + 1] = item
		scene.items[id] = item
	end
	scene.label = Text(scene.root)
	scene.label:SetText("Game look")
	scene.label:SetTextColor(0.6, 0.62, 0.66, 1)
	for path, mark in pairs(MARK) do
		local item = scene.items[mark[1]]
		local region = item and item.parts and item.parts[mark[2]]
		if region then
			scene.parts[path] = region
		end
	end
	return scene
end

-- The scale of the frames of a kind, as a share: its Frame scale row, the pet's own size, the target's for the frame of its target.
local function ScaleOf(id, g)
	if id == "player" then
		return Get("playerScale") / 100
	elseif id == "target" or id == "tot" then
		return Get("targetScale") / 100
	elseif id == "focus" then
		return Get("focusScale") / 100
	elseif id == "party1" or id == "partypet1" then
		return Get("partyScale") / 100
	elseif id == "boss" or id == "boss2" then
		return Get("bossScale") / 100
	elseif id == "raid" then
		return Get("raidScale") / 100
	elseif id == "pet" then
		if Get("petSize") ~= true then
			return 1
		end
		local share = Get("petSizePct") / 100
		return Get("petSizeBasis") == "screen" and share or share * Get("playerScale") / 100
	end
	return 1
end

-- Places the items in rows: each row is a list of entries, each entry an id or a stack of ids. scaled: the frames take their scale rows. Returns the width and
-- the height of the scene.
local function Place(scene, rows, scaled, g)
	local gap, rowGap, caption = 18, 6, 12
	local y, width = 0, 0
	for _, row in ipairs(rows) do
		local x, rowHeight = 0, 0
		for _, entry in ipairs(row) do
			local stack = type(entry) == "table" and entry or { entry }
			local entryWidth, entryY = 0, 0
			for _, id in ipairs(stack) do
				local item = scene.items[id]
				local scale = scaled and ScaleOf(id, g) or 1
				item.root:SetScale(scale)
				item.draw(item, g)
				item.root:ClearAllPoints()
				item.root:SetPoint("TOPLEFT", scene.root, "TOPLEFT", x / scale, -(y + entryY) / scale)
				local w, h = item.width * scale, item.height * scale
				if item.cap then
					item.cap:ClearAllPoints()
					item.cap:SetPoint("TOPLEFT", scene.root, "TOPLEFT", x, -(y + entryY + h + 1))
					h = h + caption
				end
				entryWidth = math.max(entryWidth, w)
				entryY = entryY + h + 4
			end
			x = x + entryWidth + gap
			rowHeight = math.max(rowHeight, entryY - 4)
		end
		width = math.max(width, x - gap)
		y = y + rowHeight + rowGap
	end
	return width, y - rowGap
end

-- Flows the items left to right, to a new row when a frame would pass the limit.
local function Flow(scene, ids, limit, g)
	local rows, row, x = {}, {}, 0
	for _, id in ipairs(ids) do
		local item = scene.items[id]
		item.root:SetScale(ScaleOf(id, g))
		item.draw(item, g)
		local w = item.width * ScaleOf(id, g)
		if x > 0 and x + w > limit then
			rows[#rows + 1] = row
			row, x = {}, 0
		end
		row[#row + 1] = id
		x = x + w + 14
	end
	rows[#rows + 1] = row
	return rows
end

local states = setmetatable({}, { __mode = "k" })

local function Register(id, spec)
	local drawing = { parts = {}, size = {} }
	function drawing.build(stage)
		local scene = BuildScene(stage, spec)
		local bag = states[stage]
		if bag == nil then
			bag = {}
			states[stage] = bag
		end
		bag[id] = scene
		if drawing.first == nil then
			-- The marks are those of the first scene built; partsOf gives the marks of any stage.
			drawing.first, drawing.parts = scene, scene.parts
		end
		return scene.root
	end
	function drawing.partsOf(stage)
		local scene = states[stage] and states[stage][id]
		return scene and scene.parts or nil
	end
	-- The frames of a stage by id, each with its root: the options window turns a click on one into the page of that frame.
	function drawing.itemsOf(stage)
		local scene = states[stage] and states[stage][id]
		return scene and scene.items or nil
	end
	function drawing.draw(stage)
		local scene = states[stage] and states[stage][id]
		if scene == nil then
			return nil
		end
		local g = Settings(scene.root)
		local rows = spec.rows
		if spec.flow then
			rows = Flow(scene, spec.ids, spec.flow, g)
		end
		local width, height = Place(scene, rows, spec.scaled, g)
		local anyGame = not g.enabled
		for _, item in ipairs(scene.items) do
			if item.k and not (g.enabled and Get(item.k.on) == true) then
				anyGame = true
			end
		end
		scene.label:SetShown(anyGame)
		if anyGame then
			scene.label:ClearAllPoints()
			scene.label:SetPoint("TOPRIGHT", scene.root, "TOPRIGHT", 0, 0)
		end
		scene.root:SetSize(math.max(width, 1), math.max(height, 1))
		drawing.size[1], drawing.size[2] = width, height
		return width, height
	end
	ns.SetupDrawings = ns.SetupDrawings or {}
	ns.SetupDrawings[id] = drawing
end

-- Player, target and focus above the pet, target of target, a party member and pet, two boss frames and a totem button.
Register("mock-unit-frame", { ids = { "player", "target", "focus", "pet", "tot", "party1", "partypet1", "boss", "boss2", "totem" },
	rows = { { "player", "target", "focus" }, { "pet", "tot", "party1", "partypet1", { "boss", "boss2" }, "totem" } } })
-- Every kind of frame at its own scale, flowing to a new row at the width of the area.
Register("mock-unit-frames", { ids = { "player", "target", "focus", "pet", "tot", "party1", "partypet1", "boss", "raid", "totem" }, raid = { 3, 2 }, flow = 640, scaled = true })
-- Five party members, the pets of two of them under them, and one member out of range.
Register("mock-party-frames", { ids = { "party1", "party2", "party3", "party4", "party5", "partypet1", "partypet2" },
	rows = { { { "party1", "partypet1" }, { "party2", "partypet2" }, "party3", "party4", "party5" } } })
-- A block of raid cells and a boss frame, living and dead.
Register("mock-raid-cells", { ids = { "raid", "boss", "boss2" }, raid = { 5, 2 }, rows = { { "raid", { "boss", "boss2" } } } })
-- The player's frame alone, for the frame style cards of the setup (Config.lua ns.SETUP_FRAME_STYLES).
Register("mock-player", { ids = { "player" }, rows = { { "player" } } })
-- Flat UI setup's stop Your target and party: the target beside four party members, the fourth out of range.
Register("mock-group-frames", { ids = { "target", "party1", "party2", "party3", "party4" }, rows = { { "target", { "party1", "party2", "party3", "party4" } } } })
