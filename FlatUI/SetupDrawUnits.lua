local ADDON_NAME, ns = ...

local KEY = "unitframes"
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local ROW = { height = 17, small = 13, accent = 3, strong = 0.95, pad = 4, gap = 1, wordGap = 2, levelRoom = 20, flagRoom = 24, timerRoom = 24,
	sizes = { smaller = 0.85, larger = 1.2 } }
local NAMEH = 11
local RADIUS = { slight = 1, soft = 2 }
local SHAPE = { [0] = MEDIA .. "Round0.tga", MEDIA .. "Round1.tga", MEDIA .. "Round2.tga" }
local LINE = { MEDIA .. "Outline1.tga", MEDIA .. "Outline2.tga" }
local SLICE = 4
local DARK = 0.10
local SHADOW = { file = MEDIA .. "Shadow.tga", out = 8, alpha = 0.55 }
local GROUND = { 0.32, 0.27, 0.20 }
local LIFT = 0.08
local CAP = { flat = 0.45, gradient = 0.75 }
local INSET = 0.1464
local CROP = 0.08
local GAME = { player = { size = 60, gap = 3, top = 24 }, target = { size = 58, gap = 1, top = 25 }, focus = { size = 58, gap = 1, top = 25 },
	small = { size = 37, gap = 2 }, partypet = { size = 18, gap = 2 } }
local REST = { WARRIOR = { "RAGE", 0 }, ROGUE = { "ENERGY", 1 } }
local FLAGS = { none = "", thin = "OUTLINE", thick = "OUTLINE, THICK" }
local CLASS = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 },
	PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 } }
local HOSTILE, FRIENDLY = { 0.80, 0.20, 0.20 }, { 0.18, 0.78, 0.24 }
local COMBAT, THREAT, GOLD = { 0.90, 0.15, 0.15 }, { 1, 0.2, 0.1 }, { 1, 0.82, 0 }
local TYPE = { magic = { 0.2, 0.6, 1 }, poison = { 0, 0.6, 0.1 }, curse = { 0.6, 0, 1 }, disease = { 0.6, 0.4, 0 }, none = { 0.8, 0, 0 },
	steal = { 0.2, 0.6, 1 } }
local HEALTH, POWER = { cur = 7000, max = 10000, pct = 70, miss = 3000 }, { cur = 4200, max = 6000, pct = 70, miss = 1800 }
local FRACTION = 0.7
local SIZE = { large = { bar = 124, health = 20, power = 10 }, small = { bar = 76, health = 12, power = 6 }, boss = { bar = 110, health = 14, power = 7 },
	pet2 = { bar = 60, health = 10, power = 0 } }
local ART = { leader = { "UI-HUD-UnitFrame-Player-Group-LeaderIcon", 1, 0.82, 0 }, attack = { "UI-HUD-UnitFrame-Player-CombatIcon", 0.9, 0.2, 0.2 },
	tank = { "roleicon-tiny-tank", 0.3, 0.5, 0.9 }, healer = { "roleicon-tiny-healer", 0.3, 0.8, 0.3 }, damage = { "roleicon-tiny-dps", 0.8, 0.3, 0.3 },
	pvp = { "UI-HUD-UnitFrame-Player-PVP-FFAIcon", 0.7, 0.7, 0.7 }, happy = { "UI-PetHappiness", 0.3, 0.8, 0.3 },
	rest = { "UI-HUD-UnitFrame-Player-Rest-Flipbook", 1, 0.9, 0.4 }, rez = { "RaidFrame-Icon-Rez", 0.4, 0.9, 0.4 } }
local REZ = { size = 20, bar = 14, inset = 1 }
local MARKER = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local ICON = 14
local AURA_FILE = 135940

local KIND = {
	player = { group = "large", pic = true, on = "player", sw = "portraitPlayer", pick = "playerPicture", name = "playerName", level = "playerLevel",
		by = "playerHealthBy", ht = "player", pt = "player", power = "playerPowerBar" },
	target = { group = "large", pic = true, side = "right", on = "target", sw = "portraitTarget", pick = "targetPicture", name = "targetName", level = "targetLevel",
		by = "targetHealthBy", ht = "target", pt = "target", power = "targetPowerBar", ranked = true },
	focus = { group = "large", pic = true, side = "right", on = "focus", sw = "portraitFocus", pick = "focusPicture", name = "focusName", level = "focusLevel",
		by = "focusHealthBy", ht = "focus", pt = "focus", power = "focusPowerBar", ranked = true },
	pet = { group = "small", pic = true, on = "pet", sw = "portraitPet", pick = "petPicture", name = "petName", by = "petHealthBy", ht = "pet", pt = "pet",
		power = "petPowerBar" },
	tot = { group = "small", pic = true, on = "tot", sw = "portraitTot", pick = "totPicture", name = "totName", by = "totHealthBy", ht = "tot", bare = true,
		power = "totPowerBar" },
	party = { group = "small", pic = true, on = "party", sw = "portraitParty", pick = "partyPicture", name = "partyName", by = "partyHealthBy", ht = "party",
		pt = "party", power = "partyPowerBar" },
	partypet = { group = "pet2", pic = true, on = "partypet", sw = "portraitPartypet", pick = "partypetPicture", name = "partyName", ht = "party" },
	boss = { group = "boss", on = "boss", name = "bossName", level = "bossLevel", by = "bossHealthBy", ht = "boss", pt = "boss", power = "bossPowerBar" },
}
local LARGE = { player = true, target = true, focus = true }
local LOW = { player = true, pet = true, party = true, partypet = true, raid = true }
local ENEMY_LOW = { target = true, focus = true, boss = true, tot = true }

local function Get(key)
	return ns.Get(KEY .. "." .. key)
end

local ROLES_LEFT_OUT = { support = { damage = true }, healer = { tank = true, damage = true } }

local function RoleShown(role)
	local out = ROLES_LEFT_OUT[Get("roleIconRoles")]
	return not (out and out[role])
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

local function Box(region, anchor, x, y, width, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
	region:SetSize(math.max(width, 0), math.max(height, 0))
end

local function Over(region, anchor, inset)
	inset = inset or 0
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
	region:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
end

local function Stretch(region, anchor, from, to, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", anchor, "TOPLEFT", from, 0)
	region:SetSize(math.max(to - from, 0), height)
end

local function Solid(texture, r, g, b, a)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:SetColorTexture(Clamp(r), Clamp(g), Clamp(b), Clamp(a or 1))
end

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

local function Slice(texture)
	if type(texture.SetTextureSliceMargins) == "function" and type(texture.SetTextureSliceMode) == "function" then
		local modes = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.UITextureSliceMode
		local mode = type(modes) == "table" and modes.Stretched or 0
		pcall(texture.SetTextureSliceMargins, texture, SLICE, SLICE, SLICE, SLICE)
		pcall(texture.SetTextureSliceMode, texture, mode)
	end
end

local function Shaped(texture, radius, r, g, b, a)
	texture:SetTexture(SHAPE[radius or 0])
	Slice(texture)
	texture:SetVertexColor(Clamp(r), Clamp(g), Clamp(b), Clamp(a or 1))
end

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

local function FileOf(role)
	local file = FillFile(role)
	if file == nil then
		file = ns.BarTexture()
	end
	return file or nil
end

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
		return numbers.miss >= 1 and (formats.miss or "-%s"):format(Num(numbers.miss)) or nil
	end
	return nil
end

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

local function Says(mode, numbers)
	if mode == "game" then
		return GameWords(numbers)
	elseif mode ~= "hide" then
		return Words(mode, numbers)
	end
	return nil
end

local function Numbers(max, share)
	local cur = math.floor(max * share + 0.5)
	return { cur = cur, max = max, pct = math.floor(share * 100 + 0.5), miss = max - cur }
end

local function Plate()
	if Get("lookOwn") == true then
		local r, g, b = ns.Colour(KEY .. ".lookBack")
		return r, g, b, (tonumber(Get("lookBackAlpha")) or 100) / 100
	end
	local r, g, b = ns.Colour("general.backdrop")
	return r, g, b, (tonumber(ns.Get("general.backdropAlpha")) or 100) / 100
end

local function Trough()
	local r, g, b = Plate()
	local shade = (0.30 * r + 0.59 * g + 0.11 * b) >= 0.5 and 0 or 1
	return { shade, shade, shade, LIFT }
end

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

local LOW_BEAT = { low = 0.35, time = 0.45 }
local function MakeLow(root, bar, levels)
	local frame = Above(Frame(root), root, levels)
	frame:SetAllPoints(bar)
	frame:Hide()
	local outline = ns.Outline(frame, frame)
	if outline == nil then
		return nil
	end
	ns.SetOutlineArea(outline, KEY)
	local okGroup, group = pcall(frame.CreateAnimationGroup, frame)
	local made = okGroup and group ~= nil and pcall(group.SetLooping, group, "REPEAT")
	for order, alphas in ipairs({ { 1, LOW_BEAT.low }, { LOW_BEAT.low, 1 } }) do
		local okFade, fade = false, nil
		if made then
			okFade, fade = pcall(group.CreateAnimation, group, "Alpha")
		end
		made = okFade and fade ~= nil and pcall(fade.SetFromAlpha, fade, alphas[1]) and pcall(fade.SetToAlpha, fade, alphas[2])
			and pcall(fade.SetDuration, fade, LOW_BEAT.time) and pcall(fade.SetOrder, fade, order)
	end
	return { frame = frame, outline = outline, beat = made and group or nil }
end

local function LowShown(on, g, s, hp)
	local limit = (ENEMY_LOW[s.kind] and s.react == HOSTILE) and g.lowTargetAt or g.lowHealthAt
	return on and g.lowHealth and not s.dead and not s.offline and hp * 100 < limit
end

local function LowKind(kind, g)
	return LOW[kind] == true or (g.lowTarget == true and ENEMY_LOW[kind] == true)
end

local function PaintLow(low, shown, radius, t, pulse)
	if low == nil then
		return
	end
	low.frame:SetShown(shown and true or false)
	local beat = low.beat
	if beat ~= nil then
		if shown and pulse then
			local ok, playing = pcall(beat.IsPlaying, beat)
			if not (ok and playing == true) and not pcall(beat.Play, beat, false, GetTime() % (2 * LOW_BEAT.time)) then
				pcall(beat.Play, beat)
			end
		elseif low.beating ~= false then
			pcall(beat.Stop, beat)
			low.frame:SetAlpha(1)
		end
		low.beating = shown and pulse and true or false
	end
	if not shown then
		return
	end
	local r, g, b = ns.Colour(KEY .. ".lowHealthColour")
	ns.SetOutline(low.outline, true, false)
	ns.SetOutlineColour(low.outline, r, g, b)
	ns.SetOutlineEdges(low.outline, true)
	ns.SetOutlineThickness(low.outline, ns.Get("general.thickness"))
	Round(low.outline, radius, t)
end

local function LowRadius(outline, radius)
	local rim = rims[outline]
	return radius ~= nil and rim ~= nil and rim.line:IsShown() and radius or nil
end

local DISPEL = { px = 2, icon = 12, atlas = "RaidFrame-Icon-Debuff" }
local TYPE_WORD = { magic = "Magic", curse = "Curse", disease = "Disease", poison = "Poison" }
local HOT_CORNERS = { tl = { "TOPLEFT", 1, -1 }, tr = { "TOPRIGHT", -1, -1 }, bl = { "BOTTOMLEFT", 1, 1 }, br = { "BOTTOMRIGHT", -1, 1 } }
local HOT_FADED = 0.5

local function MakeMarks(root)
	local m = { rim = Above(Frame(root), root, 5), frame = Above(Frame(root), root, 6), edges = {}, squares = {} }
	for index = 1, 4 do
		m.edges[index] = Tex(m.rim, "OVERLAY", 5)
		m.squares[index] = { back = Tex(m.frame, "OVERLAY", 4), fill = Tex(m.frame, "OVERLAY", 5) }
	end
	m.type = Tex(m.rim, "OVERLAY", 7)
	local X = ns.UnitFrameExtra
	if type(X) == "table" and type(X.blink) == "function" then
		local ok, flash = pcall(X.blink, m.rim)
		m.flash = ok and flash or nil
	end
	if m.flash then
		m.rim:SetScript("OnShow", function()
			if m.flashWas then
				pcall(m.flash.Stop, m.flash)
				pcall(m.flash.Play, m.flash)
			end
		end)
	end
	return m
end

local function PaintMarks(m, bar, root, on, dispel, typeIcon, hots, party)
	m.frame:SetAllPoints(root)
	m.rim:SetAllPoints(root)
	local colour = on and dispel and Get("dispelBorder") == true and TYPE[dispel] or nil
	local flashing = colour ~= nil and Get("dispelFlash") == true
	if m.flash and flashing and m.flashWas ~= true then
		pcall(m.flash.Stop, m.flash)
		pcall(m.flash.Play, m.flash)
	elseif m.flash and not flashing and m.flashWas then
		pcall(m.flash.Stop, m.flash)
		pcall(m.rim.SetAlpha, m.rim, 1)
	end
	m.flashWas = flashing
	local t = ns.Pixels(root, DISPEL.px)
	for _, edge in ipairs(m.edges) do
		edge:ClearAllPoints()
		edge:SetShown(colour ~= nil)
		if colour then
			Solid(edge, colour[1], colour[2], colour[3], 1)
		end
	end
	local top, bottom, left, right = m.edges[1], m.edges[2], m.edges[3], m.edges[4]
	top:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
	top:SetHeight(t)
	bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(t)
	left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -t)
	left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, t)
	left:SetWidth(t)
	right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -t)
	right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, t)
	right:SetWidth(t)
	local word = colour and typeIcon and TYPE_WORD[dispel] or nil
	m.type:SetShown(word ~= nil)
	if word then
		m.type:ClearAllPoints()
		m.type:SetSize(DISPEL.icon, DISPEL.icon)
		m.type:SetPoint("RIGHT", bar, "RIGHT", -1 - t, 0)
		m.type:SetTexCoord(0, 1, 0, 1)
		if HasAtlas(DISPEL.atlas .. word) then
			m.type:SetVertexColor(1, 1, 1, 1)
			m.type:SetAtlas(DISPEL.atlas .. word)
		else
			Solid(m.type, colour[1], colour[2], colour[3], 1)
		end
	end
	local lit = on and hots and Get("hotSquares") == true
	local corner = HOT_CORNERS[Get("hotCorner")] or HOT_CORNERS.tr
	local size, px = tonumber(Get("hotSize")) or 6, ns.Pixels(root, 1)
	local inset = px * (DISPEL.px + 1)
	if party then
		local ok, tall = pcall(bar.GetHeight, bar)
		if ok and ns.Finite(tall) and tall > 0 then
			size = math.max(2, math.min(size, tall - inset - px))
		end
	end
	local from = (typeIcon and corner[2] < 0) and (1 + t + DISPEL.icon + px) or inset
	local last = lit and Get("hotFade") == true and #hots or nil
	for index, square in ipairs(m.squares) do
		local c = lit and hots[index] or nil
		square.back:SetShown(c ~= nil)
		square.fill:SetShown(c ~= nil)
		local alpha = index == last and HOT_FADED or 1
		square.back:SetAlpha(alpha)
		square.fill:SetAlpha(alpha)
		if c then
			square.back:ClearAllPoints()
			square.back:SetPoint(corner[1], bar, corner[1], corner[2] * (from + (index - 1) * (size + px)), corner[3] * inset)
			square.back:SetSize(size, size)
			Solid(square.back, 0, 0, 0, 1)
			square.fill:ClearAllPoints()
			square.fill:SetPoint("TOPLEFT", square.back, "TOPLEFT", px, -px)
			square.fill:SetPoint("BOTTOMRIGHT", square.back, "BOTTOMRIGHT", -px, px)
			Solid(square.fill, c[1], c[2], c[3], 1)
		end
	end
end

local PET_TARGET = { height = 20, inset = 4, gap = 22, name = "Training Dummy", share = 0.65, marker = 8, hostile = { 1, 0, 0 } }

local function MakePetTarget(root)
	local p = { frame = Above(Frame(root), root, 2) }
	p.outline = ns.Outline(p.frame, p.frame)
	ns.SetOutlineArea(p.outline, KEY)
	p.fill = Tex(p.frame, "ARTWORK", 0)
	p.top = Above(Frame(p.frame), root, 4)
	p.top:SetAllPoints(p.frame)
	p.name, p.pct = Text(p.top, "GameFontHighlightSmall"), Text(p.top, "GameFontHighlightSmall")
	p.name:SetJustifyH("LEFT")
	p.pct:SetJustifyH("RIGHT")
	p.marker = Tex(p.top, "OVERLAY", 3)
	p.warn = Above(Frame(root), root, 4)
	p.warn:SetAllPoints(p.frame)
	p.warnOutline = ns.Outline(p.warn, p.warn)
	if p.warnOutline then
		ns.SetOutlineArea(p.warnOutline, KEY)
	end
	p.frame:Hide()
	p.warn:Hide()
	return p
end

local DRUID_MANA = { share = 0.6, mana = 3600, gap = 4, percent = 85, height = 4, shift = 0.35, form = { "ENERGY", 1 } }

local function MakeDruidMana(root)
	local d = { frame = Above(Frame(root), root, 2) }
	d.outline = ns.Outline(d.frame, d.frame)
	ns.SetOutlineArea(d.outline, KEY)
	d.fill = Tex(d.frame, "ARTWORK", 0)
	d.tick = Tex(d.frame, "OVERLAY", 7)
	d.text = Text(d.frame, "GameFontHighlightSmall")
	d.text:SetJustifyH("LEFT")
	d.frame:Hide()
	return d
end

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

local SAMPLE_HOTS = { { 0.3, 0.9, 0.35 }, { 0.75, 0.3, 1 } }

local function SampleHots(class)
	local X = ns.UnitFrameExtra
	local colours = type(X) == "table" and type(X.hotColours) == "function" and X.hotColours(class) or nil
	if type(colours) ~= "table" or #colours == 0 then
		return SAMPLE_HOTS
	end
	while #colours > 4 do
		colours[#colours] = nil
	end
	return colours
end
local PARTY = { { "Mara", "PALADIN", "tank" }, { "Bex", "MAGE", "healer" }, { "Cole", "HUNTER", "damage" }, { "Dru", "DRUID", "damage" }, { "Fay", "ROGUE", "damage" } }
local PETS = { "Cat", "Boar", "Owl", "Wolf", "Bear" }

local function Sample(id)
	local BEAST = "Interface\\Icons\\Ability_Hunter_Pet_"
	local name, level, class = Me()
	if id == "player" then
		return { kind = "player", cap = "Player", name = name, level = level, class = class, player = true, react = FRIENDLY, lcol = GOLD, state = COMBAT, leader = true,
			flag = "PvP", timer = "3:05", own = true }
	elseif id == "target" then
		return { kind = "target", cap = "Target", name = "Defias Pillager", level = 18, react = HOSTILE, lcol = { 1, 0.5, 0.25 }, rank = "elite", marker = 8,
			face = "MAGE", auras = { { "buff", "none", true }, { "buff", "none" }, { "debuff", "magic" }, { "debuff", "poison" } }, low = 0.15 }
	elseif id == "focus" then
		return { kind = "focus", cap = "Focus", name = "Gruff Swiftbite", level = 18, react = HOSTILE, lcol = { 0.25, 0.75, 0.25 }, rank = "rare",
			face = BEAST .. "Wolf" }
	elseif id == "pet" then
		return { kind = "pet", cap = "Pet", name = "Wolf", level = 20, class = class, react = FRIENDLY, state = COMBAT, happy = true, face = BEAST .. "Wolf",
			auras = { { "debuff", "curse", false, 3, "12" } } }
	elseif id == "tot" then
		return { kind = "tot", cap = "Target of target", name = "Defias Pillager Captain", level = 18, react = HOSTILE, face = "WARRIOR",
			auras = { { "debuff", "magic" } } }
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
			debuff = number == 1 and TYPE.magic or nil, low = number == 1 and 0.15 or nil, dispel = number == 1 and "magic" or nil, marker = number == 1 and 1 or nil,
			hots = number == 2 and SampleHots(class) or nil, dead = number == 5 or nil, rez = number == 5 or nil, afk = number == 4 or nil }
	end
	number = tonumber(id:match("^partypet(%d)$"))
	if number then
		return { kind = "partypet", cap = number == 1 and "Party pet" or nil, name = PETS[number], level = 19, react = FRIENDLY, owner = PARTY[number][2],
			face = BEAST .. PETS[number] }
	end
end

local E = {}

function E.make(stage, id, given)
	local sample = given or Sample(id)
	local k = KIND[sample.kind]
	local o = { id = id, k = k, s = sample, draw = E.draw, cut = {} }
	local root = Frame(stage)
	o.root = root
	o.shadow = Tex(root, "BACKGROUND", -8)
	o.plate = Tex(root, "BACKGROUND", -7)
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
	if LOW[sample.kind] or ENEMY_LOW[sample.kind] then
		o.low = MakeLow(root, o.health, 4)
	end
	if sample.kind == "party" then
		o.marks = MakeMarks(root)
	end
	if sample.kind == "pet" and given == nil then
		o.petTarget = MakePetTarget(root)
	end
	if sample.kind == "player" and given == nil then
		o.druid = MakeDruidMana(root)
	end
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
	o.rez = sample.kind == "party" and Tex(top, "OVERLAY", 3) or nil
	o.afk = sample.kind == "party" and Text(top) or nil
	o.rule = sample.kind == "player" and given == nil and Tex(top, "OVERLAY", 4) or nil
	o.tick = sample.kind == "player" and given == nil and Tex(top, "OVERLAY", 4) or nil
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
	o.parts = { root = root, body = o.box, pic = o.pic, health = o.health, power = o.power, row = row, name = o.name, level = o.level, healthText = o.healthText,
		powerText = o.powerText, pred = o.pred, shield = o.shield, absorb = o.absorb, kmark = o.kmark, kword = o.kword, kline = o.rLine, plate = o.plateIcon,
		flag = o.flag, leader = o.leader, role = o.role, marker = o.marker, attack = o.attack, happy = o.happy, dead = o.deadText, rez = o.rez, afk = o.afk, aura = o.auras[1] and o.auras[1].frame,
		count = o.auras[1] and o.auras[1].count, time = o.auras[1] and o.auras[1].time, picLevel = o.picLevel, timer = o.pvpTimer, shadow = o.shadow,
		petTarget = o.petTarget and o.petTarget.frame }
	if o.druid then
		o.parts.druid = sample.class == "DRUID" and o.druid.frame or o.power
	end
	return o
end

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

local function ByUnit(o, mode, health)
	local s = o.s
	if mode == "reaction" or not (s.player or (health and s.kind == "pet")) then
		return s.react[1], s.react[2], s.react[3]
	end
	return ClassRgb(s.class)
end

local function PictureMode(k)
	local style = Get("portraitStyle")
	local none = style == "none" or (k.sw ~= nil and Get(k.sw) == false)
	local pick = k.pick and Get(k.pick) or "auto"
	if pick == "square" or pick == "game" then
		return "picture", false
	elseif pick == "class" then
		return "icon", false
	elseif pick == "head" then
		return "head", false
	elseif pick == "none" then
		return style, true
	end
	return style, none
end

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
	g.lowHealth, g.lowHealthAt = Get("lowHealth") == true, tonumber(Get("lowHealthAt")) or 20
	g.lowTarget, g.lowHealthPulse = Get("lowHealthTarget") == true, Get("lowHealthPulse") == true
	g.lowTargetAt = tonumber(Get("lowHealthTargetAt")) or 20
	g.joined = Get("frameStyle") == "one"
	g.space = ns.Pixels(root, tonumber(Get("powerSpace")) or 2)
	g.gap = g.t + g.space
	return g
end

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
			L.style, L.none = PictureMode(k)
			L.drawn = not L.none
		end
	end
	L.round = L.drawn and L.style ~= "head" and g.classShape == "round" or false
	L.nameless = L.joined and s.kind == "partypet"
	L.rowOn = L.on and g.strip and g.square and ((not (k.group == "small" or k.group == "pet2")) or g.smallRow) and not L.nameless
	L.rowH = L.rowOn and (L.large and ROW.height or ROW.small) or 0
	L.power = size.power > 0 and (not L.on or k.power == nil or Get(k.power) ~= false)
	L.tall = L.rowOn and g.portraitSize ~= "bars"
	local bar = size.bar
	local start, seam, nameSeam, drop, apart, inside = t, t, 0, 2 * t, 3 * t, t
	if L.joined then
		start, seam, nameSeam, drop, apart, inside = t + g.gap, g.gap, g.gap, g.gap, g.gap, 0
	elseif L.on and s.kind ~= "player" and g.space > 0 and not ((L.right or L.boss) and Get("powerWidth") == "game") then
		drop = 2 * t + g.space
	end
	local y = start
	if L.rowOn then
		L.rowTop = y
		y = y + L.rowH + seam
	elseif L.joined and L.large then
		L.nameTop = 0
		y = NAMEH + start
	elseif not L.nameless then
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
	elseif not L.rowOn and not L.large and not L.boss and not L.nameless then
		L.picTop = L.nameTop + inside
	end
	L.side = math.max(L.bottom - L.picTop, 4)
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
		Round(o.outline, L.drawn and not L.round and L.radius or nil, t)
	end
	if o.rim then
		local rim = not L.round and look or nil
		o.rimFrame:SetShown(rim ~= nil)
		Over(o.rimFrame, pic)
		EdgePaint(o.rim, rim ~= nil, false, rim and rim.colour or nil)
		ns.SetOutlineThickness(o.rim, 2)
		Round(o.rim, rim ~= nil and L.radius or nil, t)
		local inner = rim ~= nil and rim.inner ~= nil
		o.innerFrame:SetShown(inner)
		Over(o.innerFrame, pic, ns.Pixels(o.root, 1))
		EdgePaint(o.inner, inner, false, inner and rim.inner or nil)
		ns.SetOutlineThickness(o.inner, 1)
	end
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
	elseif (s.own or s.me) and shown and type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, o.face, "player", true) then
		o.face:SetVertexColor(1, 1, 1, 1)
		local crop = 0
		if L.drawn then
			crop = L.style == "head" and (({ face = 0.28, shoulders = 0.12 })[g.headFraming] or 0.2) or CROP
		end
		o.face:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	else
		local face = s.face
		local class = (CLASS[face] and face) or (s.player and s.class) or nil
		local art = class and ns.ClassAtlas(class) or nil
		if art then
			o.face:SetVertexColor(1, 1, 1, 1)
			o.face:SetAtlas(art)
		elseif type(face) == "string" and not CLASS[face] and pcall(o.face.SetTexture, o.face, face) then
			o.face:SetVertexColor(1, 1, 1, 1)
			o.face:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		else
			Solid(o.face, 0.29, 0.32, 0.38, 1)
			plain = shown
		end
	end
	local round = L.round or L.gameFace
	ns.SetOutlineRound(o.outline, o.face, round, o.fade)
	Cut(o, round)
	o.head:SetShown(plain)
	o.body:SetShown(plain)
	if plain then
		local f = L.style == "head" and ({ face = 1.25, shoulders = 0.8 })[g.headFraming] or 1
		Box(o.head, pic, L.side * (0.5 - 0.17 * f), L.side * (0.33 - 0.17 * f), L.side * 0.34 * f, L.side * 0.34 * f)
		Box(o.body, pic, L.side * (0.5 - 0.34 * f), L.side * (1 - 0.38 * f), L.side * 0.68 * f, L.side * 0.38 * f)
		Solid(o.head, 0, 0, 0, 0.45)
		Solid(o.body, 0, 0, 0, 0.45)
	end
	local fade = L.drawn and L.tall and L.large and L.rowOn and g.portraitFade and g.stripColour == "gradient"
	o.fade:SetShown(fade and true or false)
	if fade then
		Box(o.fade, pic, 0, 0, L.side, math.min(ROW.height, L.side))
		local r, gr, b = Plate()
		Gradient(o.fade, r, gr, b, 0, g.stripFade / 100)
	end
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

function E.bars(o, g, L)
	local k, s, t = o.k, o.s, L.t
	local size = L.size
	local given = s.health or (L.on and g.lowHealth and (s.kind ~= "target" or g.lowTarget) and s.low) or nil
	local hp, healthNumbers = given or FRACTION, given and Numbers(HEALTH.max, given) or HEALTH
	local token, share, powerNumbers = s.powerType or "MANA", s.power or FRACTION, s.power and Numbers(POWER.max, s.power) or POWER
	local rest = s.kind == "player" and REST[s.class] or nil
	if s.kind == "player" and L.druid then
		rest = DRUID_MANA.form
	end
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
					r, gr, b = Left(hp)
				end
			end
			if s.offline then
				r, gr, b = 0.5, 0.5, 0.5
			end
			o.healthFile = file
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
		if role == "health" then
			o.lowRadius = LowRadius(outline, radius)
		end
		local part = role == "health" and hp or share
		if s.dead or (s.offline and role == "power") then
			part = 0
		elseif s.offline then
			part = 1
		end
		local width = size.bar * part
		fill:SetShown(live and width > 0)
		Stretch(fill, frame, 0, width, height)
		Fill(fill, file, r, gr, b, 1)
		CutFill(frame, fill, radius)
	end
	PaintLow(o.low, LowKind(s.kind, g) and LowShown(L.on, g, s, hp), o.lowRadius, t, g.lowHealthPulse)
	local bar = size.bar
	local segments = { { o.pred, hp, 0.12, g.healPrediction, 0.24, 0.86, 0.39, 0.75 }, { o.shield, hp + 0.12, 0.10, g.absorbShield, 1, 1, 1, 0.6 },
		{ o.absorb, hp - 0.10, 0.10, g.healAbsorb, 0.47, 0.08, 0.08, 0.85 } }
	o.segments = segments
	for _, segment in ipairs(segments) do
		local shown = not s.dead and not s.offline and (not L.on or segment[4])
		segment[1]:SetShown(shown)
		if shown then
			Stretch(segment[1], o.health, bar * segment[2], bar * (segment[2] + segment[3]), size.health)
			Solid(segment[1], segment[5], segment[6], segment[7], segment[8])
		end
	end
	local percent
	if not L.on then
		percent = 100
	elseif not L.large and not L.boss then
		percent = g.smallTextSize
	end
	for _, role in ipairs({ "health", "power" }) do
		local text, frame = o[role .. "Text"], o[role]
		local numbers = role == "health" and healthNumbers or powerNumbers
		local row = role == "health" and k.ht or k.pt
		local mode = "game"
		if L.on and row then
			mode = Get(row .. (role == "health" and "HealthText" or "PowerText")) or "game"
		end
		local words = Says(mode, numbers)
		if mode == "game" and k.bare then
			words = nil
		end
		local brim = numbers.cur >= numbers.max
		if role == "power" and token == "RAGE" then
			brim = numbers.cur <= 0
		end
		if mode ~= "game" and (g.ownTextWhen == "hover" or (g.ownTextWhen == "notfull" and brim)) then
			words = nil
		end
		if s.dead or s.offline or (L.on and role == "power" and Get("lookNoPowerText") == true) or not (role == "health" or L.power) then
			words = nil
		end
		if role == "health" then
			o.healthMode = words ~= nil and mode or nil
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
	local dead = (s.dead or s.offline) and (not L.on or g.deadText)
	o.deadText:SetShown(dead and true or false)
	if dead then
		o.deadText:SetText(s.offline and "Offline" or "Dead")
		o.deadText:ClearAllPoints()
		o.deadText:SetPoint("CENTER", o.health, "CENTER", 0, 0)
	end
end

function E.row(o, g, L)
	local k, s, t, row = o.k, o.s, L.t, o.row
	local size = L.size
	local rowOn = L.rowOn
	local radius = not L.joined and L.radius or nil
	row:SetShown(not L.nameless)
	local mode = "dark"
	if rowOn then
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
		local base = s.kind == "player" and not L.joined
		o.rBase:SetShown(base)
		Over(o.rBase, row)
		if radius then
			Shaped(o.rBase, radius, br, bg, bb, 1)
		else
			Solid(o.rBase, br, bg, bb, 1)
		end
		o.rGrad:SetShown(mode == "gradient")
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
		if L.nameTop ~= nil then
			Box(row, o.root, L.barsLeft, L.nameTop, size.bar, NAMEH)
		end
		for _, texture in ipairs({ o.rBase, o.rGrad, o.rFill, o.rMark }) do
			texture:Hide()
		end
	end
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
	if rowOn and L.on and g.fit[s.kind] == "shrink" then
		local ok, need = pcall(o.name.GetUnboundedStringWidth or o.name.GetStringWidth, o.name)
		local room = L.rowWidth - 2 * ROW.pad
		if ok and not ns.IsSecret(need) and type(need) == "number" and need > room then
			spec.percent = spec.percent * math.max(0.75, room / need)
			Style(o.name, spec)
		end
	end
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

function E.icons(o, g, L)
	local s, k, root = o.s, o.k, o.root
	o.top:SetAllPoints(root)
	for _, icon in ipairs({ o.leader, o.attack, o.role, o.plateIcon, o.marker, o.happy }) do
		icon:Hide()
	end
	if o.rez then
		o.rez:Hide()
	end
	if o.afk then
		o.afk:Hide()
	end
	o.picLevel:Hide()
	o.pvpTimer:Hide()
	o.shade:Hide()
	local function Marker(anchor, point, relative, x, y, size)
		local index = s.marker - 1
		o.marker:SetTexture(MARKER)
		o.marker:SetVertexColor(1, 1, 1, 1)
		o.marker:SetTexCoord((index % 4) * 0.25, (index % 4) * 0.25 + 0.25, math.floor(index / 4) * 0.25, math.floor(index / 4) * 0.25 + 0.25)
		o.marker:ClearAllPoints()
		o.marker:SetSize(size or ICON, size or ICON)
		o.marker:SetPoint(point, anchor, relative, x, y)
		o.marker:Show()
	end
	if o.pic then
		local shown = L.drawn or L.gameFace
		local square = shown or L.cell
		local px, py, side = L.picLeft, L.picTop, L.side
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
		if shown and s.role and g.roleIcon and RoleShown(s.role) then
			Art(o.role, s.role)
			Mark(o.role, root, px - 2, py + side - ICON + 2)
		end
		if shown and (L.pvp == "icon" or L.pvp == "both" or L.pvp == "game") then
			Art(o.plateIcon, "pvp")
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
		elseif s.marker and s.kind == "party" and L.on and Get("partyFrameMarker") == true then
			Marker(square and o.pic or o.health, "CENTER", "TOP", 0, 0, 16)
		end
		if o.rez and s.rez and L.on and Get("partyRezIcon") == true then
			Art(o.rez, "rez")
			o.rez:ClearAllPoints()
			if square then
				o.rez:SetSize(REZ.size, REZ.size)
				o.rez:SetPoint("CENTER", o.pic, "CENTER", 0, 0)
			else
				o.rez:SetSize(REZ.bar, REZ.bar)
				o.rez:SetPoint("LEFT", o.health, "LEFT", REZ.inset, 0)
			end
			o.rez:Show()
		end
		if o.afk and s.afk and not s.dead and not s.offline and L.on and Get("partyAfk") == true then
			o.afk:SetText("AFK")
			o.afk:ClearAllPoints()
			if square then
				o.afk:SetPoint("BOTTOM", o.pic, "BOTTOM", 0, 2)
			else
				o.afk:SetPoint("LEFT", o.health, "LEFT", 2, 0)
			end
			Style(o.afk, { percent = tonumber(g.smallTextSize) or 100, face = g.barTextFace ~= "default" and ns.FontFile(g.barTextFace) or nil,
				flags = FLAGS[g.barTextOutline] or "OUTLINE", r = 0.8, g = 0.8, b = 0.8 })
			o.afk:Show()
		end
		if shown and s.happy and g.petHappiness then
			Art(o.happy, "happy")
			Mark(o.happy, root, px + side - ICON + 2, py + side - ICON + 2)
		end
	elseif s.marker and g.raidMarker then
		Marker(o.health, "RIGHT", "LEFT", -2, 0)
	end
	local dim = s.away and L.on and Get("partyRangeDim") == true
	o.shade:SetShown(dim and true or false)
	if dim then
		Over(o.shade, root)
		Solid(o.shade, 0, 0, 0, 1 - Get("partyRangeOpacity") / 100)
	end
end

function E.auras(o, g, L)
	local s, root = o.s, o.root
	local ax, ay = L.barsLeft, L.height + 2
	local bottom, right = L.height, L.width
	for index, icon in ipairs(o.auras) do
		local aura = s.auras and s.auras[index]
		if aura == nil then
			icon.frame:Hide()
			icon.ring:Hide()
			icon.count:Hide()
			icon.time:Hide()
		else
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
	end
	L.height, L.width = bottom, right
end

function E.petTarget(o, g, L)
	local p = o.petTarget
	local shown = g.enabled and Get("petTarget") == true
	p.frame:SetShown(shown)
	p.warn:SetShown(shown and Get("petTargetWarn") == true)
	if not shown then
		return nil
	end
	local width = tonumber(Get("petTargetWidth"))
	width = width and width > 0 and width or 120
	local height, radius = PET_TARGET.height, g.radius
	local x = L.width + PET_TARGET.gap
	local y = math.max(0, L.healthTop + (L.size.health - height) / 2)
	Box(p.frame, o.root, x, y, width, height)
	EdgePaint(p.outline, true, g.backdrop, nil, nil, true)
	Round(p.outline, radius, L.t)
	local r, gr, b = PET_TARGET.hostile[1], PET_TARGET.hostile[2], PET_TARGET.hostile[3]
	if ns.Get("general.reactionOwn") == true then
		r, gr, b = ns.Colour("general.reactionHostile")
	end
	r, gr, b = Mute(r, gr, b)
	Stretch(p.fill, p.frame, 0, width * PET_TARGET.share, height)
	Fill(p.fill, FileOf("health"), r, gr, b, 1)
	CutFill(p.frame, p.fill, radius)
	local formats = ns.UnitFrameExtra and ns.UnitFrameExtra.formats
	p.pct:SetText(((formats and formats.pct) or "%.0f%%"):format(PET_TARGET.share * 100))
	p.pct:ClearAllPoints()
	p.pct:SetPoint("RIGHT", p.frame, "RIGHT", -PET_TARGET.inset, 0)
	p.name:SetText(PET_TARGET.name)
	p.name:ClearAllPoints()
	p.name:SetPoint("LEFT", p.frame, "LEFT", PET_TARGET.inset, 0)
	p.name:SetPoint("RIGHT", p.pct, "LEFT", -PET_TARGET.inset, 0)
	local small = tonumber(g.smallTextSize) or 100
	local nameSpec = { percent = g.nameSize * small / 100, flags = FLAGS[g.nameOutline], face = g.nameFace ~= "default" and ns.FontFile(g.nameFace) or nil }
	local pctSpec = { percent = g.lightText and small * 0.85 or small, flags = FLAGS[g.barTextOutline],
		face = g.barTextFace ~= "default" and ns.FontFile(g.barTextFace) or nil }
	if g.lightText and pctSpec.flags == nil then
		pctSpec.flags = ""
	end
	if g.barTextOwn then
		pctSpec.r, pctSpec.g, pctSpec.b = ns.Colour(KEY .. ".barTextColour")
	end
	Style(p.name, nameSpec)
	Style(p.pct, pctSpec)
	p.marker:SetShown(g.raidMarker)
	if g.raidMarker then
		local index = PET_TARGET.marker - 1
		p.marker:SetTexture(MARKER)
		p.marker:SetVertexColor(1, 1, 1, 1)
		p.marker:SetTexCoord((index % 4) * 0.25, (index % 4) * 0.25 + 0.25, math.floor(index / 4) * 0.25, math.floor(index / 4) * 0.25 + 0.25)
		p.marker:ClearAllPoints()
		p.marker:SetSize(height - 2, height - 2)
		p.marker:SetPoint("RIGHT", p.frame, "LEFT", -2, 0)
	end
	if Get("petTargetWarn") == true and p.warnOutline then
		local wr, wg, wb = ns.Colour(KEY .. ".petTargetWarnColour")
		ns.SetOutline(p.warnOutline, true, false)
		ns.SetOutlineColour(p.warnOutline, wr, wg, wb)
		ns.SetOutlineEdges(p.warnOutline, true)
		ns.SetOutlineThickness(p.warnOutline, ns.Get("general.thickness"))
		Round(p.warnOutline, LowRadius(p.outline, radius), L.t)
	end
	return x + width
end

function E.druidMana(o, g, L)
	local d = o.druid
	d.frame:SetShown(L.druid == true)
	if not L.druid then
		return nil
	end
	local t = ns.Get("general.thickness")
	t = ns.Finite(t) and t or 1
	local gap
	if L.joined then
		gap = ns.Pixels(o.root, 3 * t + 2 * (tonumber(Get("powerSpace")) or 0))
	else
		gap = math.max(1, ns.Pixels(o.root, 2 * t))
	end
	local px = tonumber(Get("druidManaHeight"))
	local tall = ns.Pixels(o.root, px and px >= 1 and px or DRUID_MANA.height)
	local top, width, radius = L.bottom + gap, L.size.bar, g.radius
	Box(d.frame, o.root, L.barsLeft, top, width, tall)
	EdgePaint(d.outline, true, g.backdrop, nil, nil, true)
	Round(d.outline, radius, L.t)
	local r, gr, b = ns.PowerColour("MANA")
	if r == nil then
		r, gr, b = 0, 0, 1
	end
	r, gr, b = Mute(r, gr, b)
	Stretch(d.fill, d.frame, 0, width * DRUID_MANA.share, tall)
	Fill(d.fill, FileOf("power"), r, gr, b, 1)
	CutFill(d.frame, d.fill, radius)
	local shift = Get("druidManaShift") == true
	d.tick:SetShown(shift)
	if shift then
		local x = width * DRUID_MANA.shift
		d.tick:ClearAllPoints()
		d.tick:SetPoint("TOP", d.frame, "TOPLEFT", x, 0)
		d.tick:SetPoint("BOTTOM", d.frame, "BOTTOMLEFT", x, 0)
		d.tick:SetWidth(ns.Pixels(o.root, 1))
		Solid(d.tick, 1, 1, 1, 0.9)
	end
	local mode = Get("druidManaText")
	local right = L.barsLeft + width + L.t
	d.text:SetShown(mode == "pct" or mode == "cur")
	if mode == "pct" or mode == "cur" then
		local formats = ns.UnitFrameExtra and ns.UnitFrameExtra.formats
		d.text:SetText(mode == "cur" and Num(DRUID_MANA.mana) or ((formats and formats.pct) or "%.0f%%"):format(DRUID_MANA.share * 100))
		local percent = tonumber(g.powerTextSize) or DRUID_MANA.percent
		local spec = { percent = g.lightText and percent * 0.85 or percent, flags = FLAGS[g.barTextOutline],
			face = g.barTextFace ~= "default" and ns.FontFile(g.barTextFace) or nil }
		if g.lightText and spec.flags == nil then
			spec.flags = ""
		end
		if g.barTextOwn then
			spec.r, spec.g, spec.b = ns.Colour(KEY .. ".barTextColour")
		end
		Style(d.text, spec)
		d.text:ClearAllPoints()
		d.text:SetPoint("LEFT", d.frame, "RIGHT", DRUID_MANA.gap, 0)
		local ok, w = pcall(d.text.GetStringWidth, d.text)
		right = L.barsLeft + width + DRUID_MANA.gap + (ok and ns.Finite(w) and w > 0 and w or 24)
	end
	return top + tall + L.t, right
end

local MANA_RULE = { share = 0.4, tick = 0.6, file = "Interface\\CastingBar\\UI-CastingBar-Spark", tall = 2, least = 8, wide = 0.6, alpha = 0.9 }

function E.manaRule(o, g, L)
	local bar = nil
	if g.enabled and Get("manaRule") == true then
		if L.druid then
			bar = o.druid.frame
		elseif L.power and REST[o.s.class] == nil then
			bar = o.power
		end
	end
	E.spark(o.rule, bar, L, MANA_RULE.share)
end

function E.energyTick(o, g, L)
	local rest = REST[o.s.class]
	local energy = L.druid or (rest ~= nil and rest[1] == "ENERGY")
	local bar = g.enabled and Get("energyTick") == true and L.power and energy and o.power or nil
	E.spark(o.tick, bar, L, MANA_RULE.tick)
end

function E.spark(spark, bar, L, share)
	spark:SetShown(bar ~= nil)
	if bar == nil then
		return
	end
	local ok, width = pcall(bar.GetWidth, bar)
	local okTall, tall = pcall(bar.GetHeight, bar)
	width = ok and ns.Finite(width) and width or L.size.bar
	tall = okTall and ns.Finite(tall) and tall > 0 and tall or L.size.power
	local high = math.max(MANA_RULE.least, tall * MANA_RULE.tall)
	spark:ClearAllPoints()
	spark:SetPoint("CENTER", bar, "LEFT", width * share, 0)
	spark:SetSize(high * MANA_RULE.wide, high)
	spark:SetTexture(MANA_RULE.file)
	spark:SetVertexColor(1, 1, 1, 1)
	pcall(spark.SetBlendMode, spark, "ADD")
	spark:SetAlpha(MANA_RULE.alpha)
end

function E.draw(o, g)
	local L = Layout(o, g)
	L.druid = o.druid ~= nil and g.enabled and Get("druidMana") == true and o.s.class == "DRUID"
	o.root:SetSize(L.width, L.height)
	local k = o.k
	o.plate:SetShown(not L.on)
	if not L.on then
		Box(o.plate, o.root, 0, 0, L.width, L.height)
		Solid(o.plate, 0.13, 0.12, 0.11, 1)
	end
	if L.joined then
		L.colour = FrameColour(o, g)
		L.bare = (g.square and g.portraitBorder == "none" and L.colour == nil) and true or false
	end
	Box(o.box, o.root, L.bodyLeft, L.bodyTop, L.bodyWidth, L.bodyHeight)
	o.box:SetShown(L.joined)
	EdgePaint(o.boxOutline, L.joined, g.backdrop, L.colour, nil, true)
	ns.SetOutlineBare(o.boxOutline, L.bare)
	Round(o.boxOutline, L.joined and L.radius or nil, L.t)
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
	if o.marks then
		PaintMarks(o.marks, o.health, o.root, L.on, o.s.dispel, Get("dispelIcon") == true, o.s.hots, true)
	end
	o.g = g
	o.width, o.height = L.width, L.height
	o.root:SetSize(L.width, L.height)
	local right = o.petTarget and E.petTarget(o, g, L)
	if right then
		o.width = math.max(o.width, right)
	end
	local bottom, textRight
	if o.druid then
		bottom, textRight = E.druidMana(o, g, L)
	end
	if bottom then
		o.height = math.max(o.height, bottom + L.t)
		o.width = math.max(o.width, textRight)
	end
	if o.rule then
		E.manaRule(o, g, L)
	end
	if o.tick then
		E.energyTick(o, g, L)
	end
	o.layout = L
	return k
end

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

local R = {}
local CELL = { width = 64, height = 32, gap = 3, thin = 4, game = 8 }
local RAID = { { "Aria", "WARRIOR", "tank" }, { "Bex", "MAGE", "damage" }, { "Cole", "HUNTER", "damage" }, { "Dru", "DRUID", "healer" },
	{ "Eli", "PRIEST", "healer" }, { "Fay", "ROGUE", "damage" }, { "Gus", "SHAMAN", "damage" }, { "Hale", "PALADIN", "tank" },
	{ "Ivo", "WARLOCK", "damage" }, { "Jun", "WARRIOR", "damage" } }
local CELL_MARK = { marker = 14, lead = 10, leadIn = 3, leadDown = 16, aura = 11, auraIn = 3, auraUp = 2, auras = 3,
	leader = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", leaderFile = "Interface\\GroupFrame\\UI-Group-LeaderIcon",
	assistant = "Interface\\GroupFrame\\UI-Group-AssistantIcon" }

local SELECT = { 1, 1, 1 }

local function MakeCell(parent, extra)
	local cell = {}
	cell.frame = Frame(parent)
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
	cell.low = MakeLow(cell.frame, cell.health, 3)
	cell.top = Frame(cell.frame)
	cell.name = Text(cell.top)
	cell.status = Text(cell.top)
	cell.afk = Text(cell.top)
	cell.role = Tex(cell.top, "OVERLAY", 2)
	if extra then
		cell.marks = MakeMarks(cell.frame)
		cell.marker, cell.lead, cell.gameType = Tex(cell.marks.frame, "OVERLAY", 7), Tex(cell.marks.frame, "OVERLAY", 6), Tex(cell.marks.frame, "OVERLAY", 6)
		cell.icons = {}
		for index = 1, extra == true and 2 * CELL_MARK.auras or 0 do
			cell.icons[index] = ns.IconNew(cell.marks.frame)
		end
	end
	return cell
end

function R.make(stage, count, columns)
	local o = { id = "raid", draw = R.draw, cells = {}, columns = columns }
	o.root = Frame(stage)
	o.sample = { cap = "Raid" }
	for index = 1, count do
		local data = RAID[index]
		local cell = MakeCell(o.root, "marks")
		cell.data, cell.index = data, index
		cell.sample = { name = data[1], class = data[2], role = data[3], dead = index == 7, away = index == 8, threat = index == 3,
			low = index == 5 and 0.15 or nil, target = index == 3, marker = index == 1 and 8 or nil, leader = index == 1, assist = index == 4,
			afk = index == 5 }
		o.cells[index] = cell
	end
	local first, aimed, away = o.cells[1], o.cells[3], o.cells[5]
	o.parts = { root = o.root, cell = first and first.frame, health = first and first.health, power = first and first.power, name = first and first.name,
		status = first and first.status, role = first and first.role, marker = first and first.marker, lead = first and first.lead,
		target = aimed and aimed.health, afk = away and away.afk }
	return o
end

local function CellMarks(cell, s, width, height, g, on, powerHeight)
	PaintMarks(cell.marks, cell.health, cell.frame, on, s.dispel, false, s.hots)
	local marker = s.marker and on and Get("raidFrameMarker") == true
	cell.marker:SetShown(marker and true or false)
	if marker then
		local index = s.marker - 1
		cell.marker:SetTexture(MARKER)
		cell.marker:SetVertexColor(1, 1, 1, 1)
		cell.marker:SetTexCoord((index % 4) * 0.25, (index % 4) * 0.25 + 0.25, math.floor(index / 4) * 0.25, math.floor(index / 4) * 0.25 + 0.25)
		cell.marker:ClearAllPoints()
		cell.marker:SetSize(CELL_MARK.marker, CELL_MARK.marker)
		cell.marker:SetPoint("TOP", cell.frame, "TOP", 0, -1)
	end
	local lead = (s.leader or s.assist) and on and Get("raidLeaderIcon") == true
	cell.lead:SetShown(lead and true or false)
	if lead then
		cell.lead:SetTexCoord(0, 1, 0, 1)
		cell.lead:SetVertexColor(1, 1, 1, 1)
		if s.leader and HasAtlas(CELL_MARK.leader) then
			cell.lead:SetAtlas(CELL_MARK.leader)
		else
			cell.lead:SetTexture(s.leader and CELL_MARK.leaderFile or CELL_MARK.assistant)
		end
		cell.lead:ClearAllPoints()
		cell.lead:SetSize(CELL_MARK.lead, CELL_MARK.lead)
		cell.lead:SetPoint("TOPRIGHT", cell.frame, "TOPRIGHT", -CELL_MARK.leadIn, -CELL_MARK.leadDown)
	end
	local word = s.dispel and s.gameDispel and TYPE_WORD[s.dispel] or nil
	cell.gameType:SetShown(word ~= nil)
	if word then
		cell.gameType:ClearAllPoints()
		cell.gameType:SetSize(DISPEL.icon, DISPEL.icon)
		cell.gameType:SetPoint("TOPRIGHT", cell.frame, "TOPRIGHT", -3, -2)
		cell.gameType:SetTexCoord(0, 1, 0, 1)
		if HasAtlas(DISPEL.atlas .. word) then
			cell.gameType:SetVertexColor(1, 1, 1, 1)
			cell.gameType:SetAtlas(DISPEL.atlas .. word)
		else
			local c = TYPE[s.dispel]
			Solid(cell.gameType, c[1], c[2], c[3], 1)
		end
	end
	local styled = on and g.auras
	local crop = styled and g.auraCrop / 100 or 0
	local up = CELL_MARK.auraUp + powerHeight
	for index, icon in ipairs(cell.icons or {}) do
		local buff = index > CELL_MARK.auras
		local slot = buff and index - CELL_MARK.auras or index
		local aura = buff and (s.buffs or 0) >= slot or (not buff and s.debuffs and s.debuffs[slot])
		icon.frame:SetShown(aura and true or false)
		if aura then
			local size = CELL_MARK.aura
			local x = CELL_MARK.auraIn + (slot - 1) * size
			icon.frame:ClearAllPoints()
			icon.frame:SetSize(size, size)
			icon.frame:SetPoint(buff and "BOTTOMRIGHT" or "BOTTOMLEFT", cell.frame, buff and "BOTTOMRIGHT" or "BOTTOMLEFT", buff and -x or x, up)
			icon.texture:SetTexture(AURA_FILE)
			icon.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
			local bordering = not buff and TYPE[aura] or nil
			EdgePaint(icon.outline, styled, false, styled and g.auraTypeColours and bordering or nil)
		end
	end
end

local function PaintCell(cell, s, width, height, g)
	local on = g.enabled and Get("raid") == true
	local cells = on and Get("raidCells") == true
	local t = g.t
	local dead, away, threat = s.dead, s.away, s.threat
	local alpha = away and (on and Get("raidRangeAlpha") or 50) / 100 or 1
	cell.frame:SetAlpha(alpha)
	local powerOn = s.powerBar ~= false
	local powerHeight = powerOn and (cells and CELL.thin or CELL.game) or 0
	local inset = on and t or 2
	local healthHeight = height - 2 * inset - powerHeight - ((cells and powerOn) and 2 * t or 0)
	cell.plate:SetShown(not cells)
	if not cells then
		Over(cell.plate, cell.frame)
		Solid(cell.plate, 0.20, 0.18, 0.15, 1)
	end
	Box(cell.health, cell.frame, inset, inset, width - 2 * inset, healthHeight)
	cell.power:SetShown(powerOn)
	Box(cell.power, cell.frame, inset, height - inset - powerHeight, width - 2 * inset, powerHeight)
	cell.hback:SetShown(not on)
	if not on then
		Over(cell.hback, cell.health)
		Solid(cell.hback, 0, 0, 0, 0.6)
	end
	local r, gr, b = ClassRgb(s.class)
	if s.classColour == false then
		r, gr, b = FRIENDLY[1], FRIENDLY[2], FRIENDLY[3]
	end
	if (cells and dead) or s.offline then
		r, gr, b = 0.5, 0.5, 0.5
	end
	local file = on and g.flat and FileOf("health") or ns.BarFile("game")
	local edge = threat and g.threat and on and THREAT or nil
	local aim = s.target and on and Get("targetBorder") or "off"
	if aim == "own" then
		edge = { ns.Colour(KEY .. ".targetColour") }
	elseif aim ~= "off" then
		edge = SELECT
	end
	EdgePaint(cell.hOutline, on, g.backdrop, edge, nil, true)
	Round(cell.hOutline, on and g.radius or nil, t)
	cell.inner = width - 2 * inset
	local hp = s.health or (on and g.lowHealth and s.low) or FRACTION
	if on and g.flat and g.healthByLeft and not dead and not s.offline then
		r, gr, b = Left(hp)
	end
	Stretch(cell.hFill, cell.health, 0, cell.inner * ((dead or s.offline) and 1 or hp), healthHeight)
	Fill(cell.hFill, file, r, gr, b, 1)
	cell.g, cell.s, cell.on, cell.lowRadius = g, s, on, LowRadius(cell.hOutline, on and g.radius or nil)
	PaintLow(cell.low, LowShown(on, g, s, hp), cell.lowRadius, t, g.lowHealthPulse)
	local pr, pg, pb = ns.PowerColour(s.powerType or "MANA")
	if pr == nil then
		pr, pg, pb = 0, 0, 1
	end
	local pfile = cells and g.flat and FileOf("power") or ns.BarFile("game")
	EdgePaint(cell.pOutline, cells and powerOn, g.backdrop, nil, nil, true)
	Round(cell.pOutline, cells and powerOn and g.radius or nil, t)
	Stretch(cell.pFill, cell.power, 0, cell.inner * (s.power or 0.7), powerHeight)
	Fill(cell.pFill, pfile, Mute(pr, pg, pb))
	cell.top:SetAllPoints(cell.frame)
	local nameOn = not on or Get("raidName") == true
	cell.name:SetShown(nameOn)
	cell.name:SetText(s.name)
	cell.name:ClearAllPoints()
	cell.name:SetPoint("LEFT", cell.frame, "LEFT", 14, 3)
	local nameSpec = { percent = 100, r = 1, g = 1, b = 1 }
	local statusSpec = { percent = 100, r = 0.8, g = 0.8, b = 0.8 }
	if on then
		nameSpec.face = g.nameFace ~= "default" and ns.FontFile(g.nameFace) or nil
		nameSpec.flags = FLAGS[g.nameOutline]
		nameSpec.percent = g.nameSize
		if g.nameColour == "custom" then
			nameSpec.r, nameSpec.g, nameSpec.b = ns.Colour(KEY .. ".nameCustom")
		elseif g.nameColour == "class" then
			nameSpec.r, nameSpec.g, nameSpec.b = ClassRgb(s.class)
		elseif g.nameColour == "reaction" then
			nameSpec.r, nameSpec.g, nameSpec.b = FRIENDLY[1], FRIENDLY[2], FRIENDLY[3]
		end
		statusSpec.face = g.barTextFace ~= "default" and ns.FontFile(g.barTextFace) or nil
		statusSpec.flags = FLAGS[g.barTextOutline]
	end
	Style(cell.name, nameSpec)
	local roleOn = (not on or (Get("raidRoleIcon") == true and RoleShown(s.role))) and ART[s.role] ~= nil
	cell.role:SetShown(roleOn)
	if roleOn then
		Art(cell.role, s.role)
		cell.role:ClearAllPoints()
		cell.role:SetSize(10, 10)
		cell.role:SetPoint("LEFT", cell.frame, "LEFT", inset + 1, 3)
	end
	local status = (dead and "Dead") or (s.offline and "Offline") or s.text
	local statusOn = status ~= nil and (not on or Get("raidStatusText") == true)
	cell.status:SetShown(statusOn and true or false)
	if statusOn then
		cell.status:SetText(status)
		cell.status:ClearAllPoints()
		cell.status:SetPoint("CENTER", cell.frame, "CENTER", 0, -4)
		Style(cell.status, statusSpec)
	end
	local afk = s.afk and on and Get("raidAfk") == true and not dead and not s.offline
	cell.afk:SetShown(afk and true or false)
	if afk then
		cell.afk:SetText("AFK")
		cell.afk:ClearAllPoints()
		cell.afk:SetPoint("CENTER", cell.frame, "CENTER", 0, -4)
		Style(cell.afk, { percent = 100, face = statusSpec.face, flags = statusSpec.flags or "OUTLINE", r = 0.8, g = 0.8, b = 0.8 })
	end
	if cell.marks then
		CellMarks(cell, s, width, height, g, on, powerHeight)
	end
end

function R.draw(o, g)
	local columns = o.columns
	local rows = math.ceil(#o.cells / columns)
	for index, cell in ipairs(o.cells) do
		local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
		Box(cell.frame, o.root, column * (CELL.width + CELL.gap), row * (CELL.height + CELL.gap), CELL.width, CELL.height)
		PaintCell(cell, cell.sample, CELL.width, CELL.height, g)
	end
	o.width = columns * CELL.width + (columns - 1) * CELL.gap
	o.height = rows * CELL.height + (rows - 1) * CELL.gap
	o.root:SetSize(o.width, o.height)
end

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
	lowHealth = { "party1", "health" }, lowHealthAt = { "party1", "health" }, lowHealthColour = { "party1", "health" }, hoverHighlight = { "player", "health" },
	druidMana = { "player", "druid" }, druidManaText = { "player", "druid" }, druidManaHeight = { "player", "druid" }, druidManaShift = { "player", "druid" }, manaRule = { "player", "power" },
	energyTick = { "player", "power" },
	petTarget = { "pet", "petTarget" }, petTargetWidth = { "pet", "petTarget" }, petTargetWarn = { "pet", "petTarget" }, petTargetWarnColour = { "pet", "petTarget" },
	lowHealthTarget = { "target", "health" }, lowHealthTargetAt = { "target", "health" }, lowHealthPulse = { "party1", "health" }, dispelBorder = { "party1", "health" }, dispelIcon = { "party1", "health" },
	dispelFlash = { "party1", "health" },
	hotSquares = { "party2", "health" }, hotCorner = { "party2", "health" }, hotSize = { "party2", "health" }, hotFade = { "party2", "health" },
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
	totPicture = { "tot", "pic" }, totName = { "tot", "name" }, totNameFit = { "tot", "name" }, totHealthBy = { "tot", "health" }, totHealthText = { "tot", "healthText" },
	totPowerBar = { "tot", "power" },
	partyPicture = { "party1", "pic" }, partypetPicture = { "partypet1", "pic" }, partyName = { "party1", "name" }, partyNameFit = { "party1", "name" }, partyHealthBy = { "party1", "health" },
	partyHealthText = { "party1", "healthText" }, partyPowerText = { "party1", "powerText" }, partyPowerBar = { "party1", "power" },
	partyRangeDim = { "party4", "root" }, partyRangeOpacity = { "party4", "root" },
	bossName = { "boss", "name" }, bossNameFit = { "boss", "name" }, bossPowerText = { "boss", "powerText" }, bossLevel = { "boss", "level" }, bossHealthBy = { "boss", "health" }, bossHealthText = { "boss", "healthText" },
	bossPowerBar = { "boss", "power" },
	raidRangeAlpha = { "raid", "cell" }, raidRoleIcon = { "raid", "role" }, raidName = { "raid", "name" }, raidStatusText = { "raid", "status" },
	raidFrameMarker = { "raid", "marker" }, raidLeaderIcon = { "raid", "lead" }, targetBorder = { "raid", "target" }, targetColour = { "raid", "target" },
	partyFrameMarker = { "party1", "marker" }, partyRezIcon = { "party5", "rez" }, roleIconRoles = { "party2", "role" }, raidAfk = { "raid", "afk" }, partyAfk = { "party4", "afk" },
}

local function BuildScene(stage, spec)
	local scene = { root = Frame(stage), items = {}, spec = spec, parts = {} }
	scene.root:SetPoint("TOPLEFT", stage, "TOPLEFT", 0, 0)
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
			drawing.first, drawing.parts = scene, scene.parts
		end
		return scene.root
	end
	function drawing.partsOf(stage)
		local scene = states[stage] and states[stage][id]
		return scene and scene.parts or nil
	end
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

Register("mock-unit-frame", { ids = { "player", "target", "focus", "pet", "tot", "party1", "partypet1", "boss", "boss2", "totem" },
	rows = { { "player", "target", "focus" }, { "pet", "tot", "party1", "partypet1", { "boss", "boss2" }, "totem" } } })
Register("mock-unit-frames", { ids = { "player", "target", "focus", "pet", "tot", "party1", "partypet1", "boss", "raid", "totem" }, raid = { 3, 2 }, flow = 640, scaled = true })
Register("mock-party-frames", { ids = { "party1", "party2", "party3", "party4", "party5", "partypet1", "partypet2" },
	rows = { { { "party1", "partypet1" }, { "party2", "partypet2" }, "party3", "party4", "party5" } } })
Register("mock-raid-cells", { ids = { "raid", "boss", "boss2" }, raid = { 5, 2 }, rows = { { "raid", { "boss", "boss2" } } } })
Register("mock-player", { ids = { "player" }, rows = { { "player" } } })
Register("mock-group-frames", { ids = { "target", "party1", "party2", "party3", "party4" }, rows = { { "target", { "party1", "party2", "party3", "party4" } } } })

local GAME_BAR = { party = { 45, 19 }, partypet = { 21.5, 9 }, target = { 21, 44 }, focus = { 21, 44 }, tot = { 44, 17 }, pet = { 45, 17.5 },
	boss = { 61, 46 } }
local SLOTS = { party = 4, target = 4, focus = 4, tot = 2, pet = 2 }

local D = {}
ns.DrawUnits = D

function D.Unit(parent, kind)
	if kind == "totem" then
		return T.make(parent)
	end
	local auras = {}
	for index = 1, SLOTS[kind] or 0 do
		auras[index] = { "buff", "none" }
	end
	return E.make(parent, kind, { kind = kind, name = "", level = 1, react = FRIENDLY, auras = auras })
end

function D.PaintUnit(o, sample, g)
	if o.id == "totem" then
		T.draw(o, g)
		if sample and sample.time and o.time:IsShown() then
			o.time:SetText(sample.time)
		end
		return o.width, o.height
	end
	o.s, o.k = sample, KIND[sample.kind] or o.k
	E.draw(o, g)
	return o.width, o.height
end

function D.Fill(o, hp)
	local L, g, s = o.layout, o.g, o.s
	if not (L and g and s and o.healthFill) or s.dead or s.offline then
		return
	end
	local bar, height = L.size.bar, L.size.health
	local width = bar * hp
	o.healthFill:SetShown(width > 0)
	Stretch(o.healthFill, o.health, 0, width, height)
	if L.on and g.flat and g.healthByLeft then
		local r, gr, b = Left(hp)
		Fill(o.healthFill, o.healthFile, r, gr, b, 1)
	end
	local was = s.health or FRACTION
	for _, segment in ipairs(o.segments or {}) do
		segment[2] = hp + (segment[2] - was)
		if segment[1]:IsShown() then
			Stretch(segment[1], o.health, bar * segment[2], bar * (segment[2] + segment[3]), height)
		end
	end
	s.health = hp
	PaintLow(o.low, LowKind(s.kind, g) and LowShown(L.on, g, s, hp), o.lowRadius, L.t, g.lowHealthPulse)
	if o.healthMode and o.healthText:IsShown() then
		local words = Says(o.healthMode, Numbers(HEALTH.max, hp))
		if words then
			o.healthText:SetText(words)
		end
	end
end

function D.Cell(parent)
	return MakeCell(parent, true)
end
D.PaintCell = PaintCell

function D.FillCell(cell, hp, text)
	if cell.inner then
		Stretch(cell.hFill, cell.health, 0, cell.inner * hp, cell.health:GetHeight())
	end
	if cell.g and cell.s then
		PaintLow(cell.low, LowShown(cell.on, cell.g, cell.s, hp), cell.lowRadius, cell.g.t, cell.g.lowHealthPulse)
	end
	if text and cell.status:IsShown() then
		cell.status:SetText(text)
	end
end

D.Settings = Settings

function D.Offset(o)
	local spot, L = GAME_BAR[o.id], o.layout
	if not (spot and L) then
		return 0, 0
	end
	return spot[1] - L.barsLeft, spot[2] - L.healthTop
end

D.Sample = Sample
D.Me = Me
D.TYPE = TYPE
