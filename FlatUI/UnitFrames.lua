local ADDON_NAME, ns = ...

local KEY = "unitframes"

ns.UnitFrameExtra = { after = { apply = {}, layout = {}, picture = {}, tint = {}, rowText = {}, colour = {}, raid = {}, final = {}, refresh = {} },
	before = { layout = {} },
	switches = { player = "portraitPlayer", target = "portraitTarget", focus = "portraitFocus", pet = "portraitPet", tot = "portraitTot", party = "portraitParty",
		partypet = "portraitPartypet" } }

local KINDS = { "player", "target", "focus", "pet", "tot", "party", "partypet", "boss", "raid" }
local LABELS = { player = "player frame", target = "target frame", focus = "focus frame", pet = "pet frame", tot = "target of target frame",
	party = "party frames", partypet = "party pet frames", boss = "boss frames", raid = "raid frames" }
local TOTEMS, AURAS = "totem buttons", "aura icons"
local ROOTS = {
	player = { "PlayerFrame" },
	target = { "TargetFrame" },
	focus = { "FocusFrame" },
	pet = { "PetFrame" },
	tot = { "TargetFrameToT", "FocusFrameToT" },
	boss = { "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame" },
}
local RAID_NAMES = { "^CompactPartyFrameMember%d$", "^CompactPartyFramePet%d$", "^CompactRaidGroup%dMember%d$", "^CompactRaidFrame%d+$" }
local RAID_UPDATES = { "CompactUnitFrame_UpdateSelectionHighlight", "CompactUnitFrame_UpdateAggroHighlight", "CompactUnitFrame_UpdateHealthColor",
	"CompactUnitFrame_UpdatePowerColor" }
local TOT = { debuffs = 4, every = 0.2 }

local COLOUR = { warning = { 1, 0.3, 0.1 }, mana = { 0, 0, 1 }, stealable = { 0.2, 0.6, 1 }, pet = { 0, 1, 0 }, level = { 1, 0.1, 0.1 } }
local CROP = 0.08
local STANDARD = { x = 147, top = 6, bottom = -20, slotBottom = -9 }
local RIM_PX, INNER_PX = 2, 1
local ROUND = { slight = 1, soft = 2 }
local SLICE = 4
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local CORNERS = {
	[0] = { fill = MEDIA .. "Round0.tga" },
	[1] = { fill = MEDIA .. "Round1.tga", line = MEDIA .. "Outline1.tga" },
	[2] = { fill = MEDIA .. "Round2.tga", line = MEDIA .. "Outline2.tga" },
}
local LARGE = { player = true, target = true, focus = true }
local RANKED = { target = true, focus = true }
local RANKS = ns.KINDS
local KIND_PART = "Elite and Rare"
local ROW = { sizes = { smaller = 0.85, larger = 1.2 }, height = 17, accent = 3, bright = 0.7, strong = 0.95, pad = 4, gap = 1, wordGap = 2, levelRoom = 20, flagRoom = 24, timerRoom = 24, small = 13,
	kinds = { player = true, target = true, focus = true, boss = true, pet = true, tot = true, party = true, partypet = true } }
local TEXT_KEYS = { "TextString", "HealthBarText", "ManaBarText", "CenterText", "LeftText", "RightText" }
local PET_TEXTS = {
	health = { "PetFrameHealthBarText", "PetFrameHealthBarTextLeft", "PetFrameHealthBarTextRight" },
	power = { "PetFrameManaBarText", "PetFrameManaBarTextLeft", "PetFrameManaBarTextRight" },
}
local ROW_FONT = "GameFontNormalSmall"
local TOKENS = { player = "player", target = "target", focus = "focus", pet = "pet" }
local SPAN = { player = 31, target = 26, focus = 26, pet = 30.5, tot = 30.5, party = 31, partypet = 22, petBar = 5 }
local FLAG = { half = 13,
	home = { player = { "TOP", "TOPLEFT", 22, -65 }, target = { "TOP", "TOPRIGHT", -24, -65 }, focus = { "TOP", "TOPRIGHT", -24, -65 } },
	plateHome = { player = { "TOP", "TOPLEFT", 20, -50 }, target = { "TOP", "TOPRIGHT", -23, -50 }, focus = { "TOP", "TOPRIGHT", -23, -50 } },
	corner = { tl = { "TOPLEFT", 1, -1 }, tr = { "TOPRIGHT", -1, -1 }, bl = { "BOTTOMLEFT", 1, 1 }, br = { "BOTTOMRIGHT", -1, 1 } } }
local STATUS = { names = { player = "Player", target = "Target", pet = "Pet", tot = "Target of target", boss = "Boss 1", party = "Party 1" },
	none = { target = "no target", pet = "no pet", tot = "no unit", boss = "no unit" },
	notDrawn = "Unit frames: a portrait could not be drawn on one frame, which keeps the game's portrait.",
	undrawn = 0 }
local FRAME = { POWER = { player = "playerPowerBar", target = "targetPowerBar", focus = "focusPowerBar", pet = "petPowerBar", tot = "totPowerBar",
	party = "partyPowerBar", boss = "bossPowerBar" }, INSET = 0.1464, CAP = { flat = 0.45, gradient = 0.75 },
	TELL = "Flat UI: unit frames take their new layout when the fight ends.",
	OPTS = { "portraitSize", "frameStyle", "powerSpace", "nameRoom", "powerWidth", "smallTextSize", "levelPosition", "pvpFlag", "pvpTimer", "strip", "smallRow" } }

local records = setmetatable({}, { __mode = "k" })
local byFlash = setmetatable({}, { __mode = "k" })
local byPower = setmetatable({}, { __mode = "k" })
local byHealth = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local totems = setmetatable({}, { __mode = "k" })
local auras = setmetatable({}, { __mode = "k" })
local byBorder = setmetatable({}, { __mode = "k" })
local waiting = setmetatable({}, { __mode = "k" })

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

function ROW.of(rec)
	if ROW.none(rec) then
		return 0
	end
	return (LARGE[rec.kind] and ROW.height) or ROW.small
end

function ROW.at(rec)
	local at = Opt("levelPosition")
	if at == "portrait" and rec ~= nil and (rec.pic == nil or rec.pic.none) then
		return "end"
	end
	return at
end

ns.UnitFrameExtra.per = { picture = { player = true, target = true, focus = true, pet = true, tot = true, party = true, partypet = true },
	level = { player = true, target = true, focus = true, boss = true },
	health = { player = true, target = true, focus = true, pet = true, tot = true, party = true, boss = true } }

function ns.UnitFrameExtra.pictureMode(rec)
	local style = Opt("portraitStyle")
	local switch = ns.UnitFrameExtra.switches[rec.kind]
	local none = style == "none" or (switch ~= nil and Opt(switch) == false)
	local pick = ns.UnitFrameExtra.per.picture[rec.kind] and Opt(rec.kind .. "Picture") or "auto"
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

function ns.UnitFrameExtra.levelWanted(rec)
	return not ns.UnitFrameExtra.per.level[rec.kind] or Opt(rec.kind .. "Level") ~= false
end

function ns.UnitFrameExtra.healthBy(rec)
	local by = ns.UnitFrameExtra.per.health[rec.kind] and Opt(rec.kind .. "HealthBy") or nil
	return (by == "class" or by == "reaction") and by or nil
end

function ns.UnitFrameExtra.fillFile(role)
	local pick = Opt(role .. "Texture")
	if pick ~= nil and pick ~= "default" then
		if pick == "flat" then
			return false
		end
		return ns.BarFile(pick)
	end
	return Opt("lookSoftShade") and ns.BarFile("soft") or nil
end

function ns.UnitFrameExtra.fillImage(role)
	local file = ns.UnitFrameExtra.fillFile(role)
	if file == nil then
		return ns.BarTexture() ~= nil
	end
	return file ~= false
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Plain(text)
	return not ns.IsSecret(text) and type(text) == "string" and text ~= ""
end

local function Path(root, ...)
	local value = root
	for index = 1, select("#", ...) do
		if value == nil or ns.IsSecret(value) or type(value) ~= "table" then
			return nil
		end
		value = value[(select(index, ...))]
	end
	if value == nil or ns.IsSecret(value) or type(value) ~= "table" then
		return nil
	end
	return value
end

local function List(...)
	local list = {}
	for index = 1, select("#", ...) do
		local value = (select(index, ...))
		if value ~= nil then
			list[#list + 1] = value
		end
	end
	return list
end

local function Describe(kind, frame)
	if kind == "player" then
		local container, content = Path(frame, "PlayerFrameContainer"), Path(frame, "PlayerFrameContent")
		local main = Path(content, "PlayerFrameContentMain")
		local box, power = Path(main, "HealthBarsContainer"), Path(main, "ManaBarArea", "ManaBar")
		return {
			owner = container, portrait = Path(container, "PlayerPortrait"), portraitMask = Path(container, "PlayerPortraitMask"), side = "left", content = List(container, content, main, Path(content, "PlayerFrameContentContextual")),
			art = List(Path(container, "FrameTexture"), Path(container, "VehicleFrameTexture"), Path(container, "AlternatePowerFrameTexture"),
				Path(content, "PlayerFrameContentContextual", "PlayerPortraitCornerIcon")),
			flash = Path(container, "FrameFlash"), status = Path(main, "StatusTexture"),
			rest = Path(content, "PlayerFrameContentContextual", "PlayerRestLoop", "RestTexture"),
			health = Path(box, "HealthBar"), healthMask = Path(box, "HealthBarMask"), textBox = box, power = power, powerMask = Path(power, "ManaBarMask"),
			badges = main, level = Path(main, "LevelBackgroundCircle"), pvp = Path(main, "PvpBackgroundCircle"), levelText = Path(_G, "PlayerLevelText"),
			nameText = Path(_G, "PlayerName"), loss = Path(box, "PlayerFrameHealthBarAnimatedLoss"),
			pvpIcon = Path(main, "PvpBackgroundIcon"), pvpTimer = Path(_G, "PlayerPVPTimerText"), pvpHome = main,
		}
	elseif kind == "target" or kind == "focus" then
		local container = Path(frame, "TargetFrameContainer")
		local content = Path(frame, "TargetFrameContent")
		local main = Path(content, "TargetFrameContentMain")
		local box, power = Path(main, "HealthBarsContainer"), Path(main, "ManaBar")
		return {
			owner = container, portrait = Path(container, "Portrait"), portraitMask = Path(container, "PortraitMask"), art = List(Path(container, "FrameTexture")), side = "right", standard = STANDARD,
			content = List(container, content, main, Path(content, "TargetFrameContentContextual")),
			boss = Path(container, "BossPortraitFrameTexture"), flash = Path(container, "Flash"), clip = "right",
			health = Path(box, "HealthBar"), healthBox = box, cutHealth = true, healthMask = Path(box, "HealthBarMask"), textBox = box, power = power,
			powerMask = Path(power, "ManaBarMask"),
			badges = main, level = Path(main, "LevelBackgroundCircle"), levelText = Path(main, "LevelText"), strip = Path(main, "ReputationColor"),
			nameText = Path(main, "Name"), high = Path(content, "TargetFrameContentContextual", "HighLevelTexture"),
			pvp = Path(content, "TargetFrameContentContextual", "PvpBackgroundCircle"),
			pvpIcon = Path(content, "TargetFrameContentContextual", "PvpBackgroundIcon"), pvpHome = Path(content, "TargetFrameContentContextual"),
		}
	elseif kind == "boss" then
		local container = Path(frame, "TargetFrameContainer")
		local main = Path(frame, "TargetFrameContent", "TargetFrameContentMain")
		local box, power = Path(main, "HealthBarsContainer"), Path(main, "ManaBar")
		return {
			owner = container, art = List(Path(container, "FrameTexture")), flash = Path(container, "Flash"), clip = "right",
			content = List(container, Path(frame, "TargetFrameContent"), main),
			health = Path(box, "HealthBar"), healthBox = box, power = power, powerMask = Path(power, "ManaBarMask"),
			badges = main, level = Path(main, "LevelBackgroundCircle"), levelText = Path(main, "LevelText"), strip = Path(main, "ReputationColor"),
			nameText = Path(main, "Name"), high = Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "HighLevelTexture"),
		}
	elseif kind == "pet" then
		return {
			owner = frame, portrait = Path(frame, "Portrait"), portraitMask = Path(frame, "PortraitMask"), art = List(Path(_G, "PetFrameTexture")), flash = Path(_G, "PetFrameFlash"),
			status = Path(_G, "PetAttackModeTexture"), clip = "left", side = "left", nameText = Path(_G, "PetName"), named = PET_TEXTS,
			health = Path(_G, "PetFrameHealthBar"), healthMask = Path(_G, "PetFrameHealthBarMask"),
			power = Path(_G, "PetFrameManaBar"), powerMask = Path(_G, "PetFrameManaBarMask"),
		}
	elseif kind == "party" then
		return {
			owner = frame, portrait = Path(frame, "Portrait"), portraitMask = Path(frame, "PortraitMask"), art = List(Path(frame, "Texture"), Path(frame, "VehicleTexture")), flash = Path(frame, "Flash"), clip = "left",
			side = "left", nameText = Path(frame, "Name"), debuff = Path(frame, "PartyMemberOverlay", "Status"), textBox = Path(frame, "HealthBarContainer"),
			pvpIcon = Path(frame, "PartyMemberOverlay", "PVPIcon"),
			health = Path(frame, "HealthBarContainer", "HealthBar"), healthMask = Path(frame, "HealthBarContainer", "HealthBarMask"),
			power = Path(frame, "ManaBar"), powerMask = Path(frame, "ManaBar", "ManaBarMask"),
		}
	elseif kind == "partypet" then
		return {
			owner = frame, portrait = Path(frame, "Portrait"), portraitMask = Path(frame, "PortraitMask"), art = List(Path(frame, "Texture")), flash = Path(frame, "Flash"), side = "left", nameText = Path(frame, "Name"),
			health = Path(frame, "HealthBar"),
		}
	elseif kind == "raid" then
		return {
			owner = frame, art = List(Path(frame, "background"), Path(frame, "selectionHighlight"), Path(frame, "aggroHighlight")),
			select = Path(frame, "selectionHighlight"), flash = Path(frame, "aggroHighlight"), health = Path(frame, "healthBar"), power = Path(frame, "powerBar"),
		}
	end
	return {
		owner = frame, portrait = Path(frame, "Portrait"), portraitMask = Path(frame, "PortraitMask"), art = List(Path(frame, "FrameTexture")), clip = "left", side = "left", nameText = Path(frame, "Name"),
		health = Path(frame, "HealthBar"), healthMask = Path(frame, "HealthBar", "HealthBarMask"),
		power = Path(frame, "ManaBar"), powerMask = Path(frame, "ManaBar", "ManaBarMask"),
	}
end

local function Record(kind, frame)
	local rec = records[frame]
	if rec == nil then
		local parts = Describe(kind, frame)
		if parts.health == nil then
			return nil
		end
		rec = { kind = kind, frame = frame, parts = parts, bars = {}, byRole = {}, unmasked = {}, bands = {}, lines = {}, retries = 0 }
		records[frame] = rec
		if parts.flash ~= nil then
			byFlash[parts.flash] = rec
		end
		if parts.power ~= nil then
			byPower[parts.power] = rec
		end
		if kind == "partypet" then
			byHealth[parts.health] = rec
		end
	end
	return rec
end

local function Known(frame)
	if frame == nil or ns.IsSecret(frame) then
		return nil
	end
	return records[frame]
end

local function Active(rec)
	return ns.Enabled(KEY) and Opt(rec.kind) == true and not ns.PartStopped(KEY, LABELS[rec.kind])
end

local Refresh
local Apply
local looking = false
local function Run(part, fn, ...)
	if ns.PartStopped(KEY, part) then
		pcall(fn, ...)
		return
	end
	local ok, err = ns.EachPart(KEY, part, fn, ...)
	if ok then
		return
	end
	if err then
		ns.Note(KEY, part .. ": " .. err)
	end
	if ns.PartStopped(KEY, part) and not looking then
		looking = true
		pcall(Refresh)
		looking = false
	end
end

local function IsLit(region)
	local ok, shown = pcall(region.IsShown, region)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function Lit(region)
	if not IsLit(region) then
		return nil
	end
	local ok, r, g, b = pcall(region.GetVertexColor, region)
	if ok and Number(r) and Number(g) and Number(b) then
		return r, g, b
	end
	return COLOUR.warning[1], COLOUR.warning[2], COLOUR.warning[3]
end

local function ClearGlow(rec, on)
	local glow = rec.parts.status
	if glow == nil then
		return
	end
	if on then
		local ok, atlas = pcall(glow.GetAtlas, glow)
		if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
			rec.glowAtlas = atlas
			pcall(glow.SetTexture, glow, nil)
		end
	elseif rec.glowAtlas ~= nil then
		pcall(glow.SetAtlas, glow, rec.glowAtlas, true)
		rec.glowAtlas = nil
	end
end

local function Ask(region, method, ...)
	local ok, a, b, c, d = pcall(function(...)
		return region[method](region, ...)
	end, ...)
	if ok and not ns.IsSecret(a) then
		return a, b, c, d
	end
	return nil
end

local noSlice = false
local sliced = setmetatable({}, { __mode = "k" })
local rims = setmetatable({}, { __mode = "k" })

local function Radius()
	return not noSlice and ROUND[Opt("corners")] or nil
end

local function Slice(texture)
	if type(texture.SetTextureSliceMargins) ~= "function" or type(texture.SetTextureSliceMode) ~= "function" then
		return false
	end
	local modes = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.UITextureSliceMode
	local mode = type(modes) == "table" and modes.Stretched or 0
	if pcall(texture.SetTextureSliceMargins, texture, SLICE, SLICE, SLICE, SLICE) and pcall(texture.SetTextureSliceMode, texture, mode) then
		sliced[texture] = true
		return true
	end
	return false
end

local function Shape(texture, radius, line, mask)
	local file = CORNERS[radius or 0][line and "line" or "fill"]
	local wrap = mask and "CLAMPTOBLACKADDITIVE" or nil
	return pcall(texture.SetTexture, texture, file, wrap, wrap) and Slice(texture)
end

local function Unslice(texture)
	if sliced[texture] then
		sliced[texture] = nil
		if type(texture.ClearTextureSlice) == "function" then
			pcall(texture.ClearTextureSlice, texture)
		end
	end
end

function FRAME.edge(outline)
	if outline.r ~= nil then
		return outline.r, outline.g, outline.b
	end
	if type(ns.OutlineEdgeRGB) == "function" then
		local r, g, b = ns.OutlineEdgeRGB(outline)
		if r ~= nil then
			return r, g, b
		end
	end
	if Opt("lookOwn") == true and outline.area == KEY then
		return ns.Colour(KEY .. ".lookBorder")
	end
	return ns.BorderRGB()
end

local function Rim(outline)
	local rim = rims[outline]
	if rim == nil then
		return
	end
	local radius = rim.radius
	local shown = radius ~= nil and not outline.roundOn and outline.shown and not outline.edgesOff and not outline.bare
		and not (ns.Get("general.borderless") == true and outline.r == nil)
	rim.line:SetShown(shown)
	if shown then
		local r, g, b = FRAME.edge(outline)
		rim.line:SetVertexColor(r, g, b, 1)
		local t = outline.px or ns.Get("general.thickness")
		if not outline.pixels then
			t = ns.Pixels(outline.anchor, t)
		end
		if rim.t ~= t and InCombatLockdown() then
			if not rim.waiting then
				rim.waiting = true
				ns.OutOfCombat(function()
					rim.waiting = nil
					pcall(Rim, outline)
				end)
			end
		elseif rim.t ~= t then
			rim.t = t
			rim.line:SetPoint("TOPLEFT", outline.anchor, "TOPLEFT", -t, t)
			rim.line:SetPoint("BOTTOMRIGHT", outline.anchor, "BOTTOMRIGHT", t, -t)
		end
	end
	for _, edge in ipairs(outline.edges) do
		pcall(edge.SetAlpha, edge, radius and rim.t ~= nil and 0 or 1)
	end
end

local function Round(outline, radius)
	local rim = rims[outline]
	if rim == nil then
		rim = { line = outline.top:GetParent():CreateTexture(nil, "OVERLAY", nil, 7) }
		ns.Own[rim.line] = true
		if outline.liftTo ~= nil then
			pcall(rim.line.SetParent, rim.line, outline.liftTo)
		end
		rim.line:Hide()
		rim.mask = outline.backdrop:GetParent():CreateMaskTexture()
		ns.Own[rim.mask] = true
		rim.mask:SetAllPoints(outline.anchor)
		rims[outline] = rim
	end
	rim.radius = radius
	if not (Shape(rim.line, radius, true) and Shape(rim.mask, radius, false, true)) then
		return false
	end
	if not rim.masked then
		rim.masked = pcall(outline.backdrop.AddMaskTexture, outline.backdrop, rim.mask)
	end
	Rim(outline)
	return true
end

function ns.UnitFrameExtra.rimLine(outline)
	local rim = outline ~= nil and rims[outline]
	return rim and rim.line or nil
end

local function Unround(outline)
	local rim = rims[outline]
	if rim ~= nil and rim.radius ~= nil then
		rim.radius = nil
		if rim.masked then
			rim.masked = not pcall(outline.backdrop.RemoveMaskTexture, outline.backdrop, rim.mask)
		end
		Rim(outline)
	end
end

local function ShowOutline(outline, shown, backdropOn)
	ns.SetOutline(outline, shown, backdropOn)
	Rim(outline)
end

local function ColourOutline(outline, r, g, b)
	ns.SetOutlineColour(outline, r, g, b)
	Rim(outline)
end

local function UnitOf(rec)
	local unit = rec.frame.unit
	if unit ~= nil and not ns.IsSecret(unit) and type(unit) == "string" and unit ~= "" then
		return unit
	elseif TOKENS[rec.kind] then
		return TOKENS[rec.kind]
	elseif rec.kind == "tot" then
		local ok, name = pcall(rec.frame.GetName, rec.frame)
		return ok and not ns.IsSecret(name) and type(name) == "string" and name:find("^Focus") and "focustarget" or "targettarget"
	end
	local member = rec.frame
	if rec.kind == "partypet" then
		local ok, parent = pcall(member.GetParent, member)
		member = ok and not ns.IsSecret(parent) and parent or nil
	end
	local index = member and member.layoutIndex
	if Number(index) then
		return rec.kind .. index
	end
	return nil
end

local function IconOf(portrait)
	local ok, atlas = pcall(portrait.GetAtlas, portrait)
	if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
		return atlas
	end
	return nil
end

local function ClassAtlas(unit)
	if unit == nil or type(UnitIsPlayer) ~= "function" or type(UnitClass) ~= "function" or type(GetClassAtlas) ~= "function" then
		return nil
	end
	local ok, player = pcall(UnitIsPlayer, unit)
	if not ok or ns.IsSecret(player) or player ~= true then
		return nil
	end
	local found, _, class = pcall(UnitClass, unit)
	if not found or not Plain(class) then
		return nil
	end
	local named, atlas = pcall(GetClassAtlas, class)
	return named and Plain(atlas) and atlas or nil
end

local function Draw(rec)
	local texture = rec.pic.texture
	local unit = UnitOf(rec)
	local atlas, class = IconOf(rec.parts.portrait), nil
	if rec.pic.style == "icon" then
		class = ClassAtlas(unit)
		atlas = class or atlas
	end
	rec.pic.icon = atlas ~= nil
	if atlas ~= nil then
		return pcall(texture.SetTexCoord, texture, 0, 1, 0, 1) and pcall(texture.SetAtlas, texture, atlas, false, nil, true)
	end
	return unit ~= nil and type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, texture, unit, true)
		and pcall(texture.SetTexCoord, texture, CROP, 1 - CROP, CROP, 1 - CROP)
end

local function Squared(rec, on)
	return on and Opt("squarePortrait") and rec.pic ~= nil and not rec.pic.failed
end

local function Undrawn(rec, failed)
	local pic = rec.pic
	if (pic.failed or false) ~= failed then
		pic.failed = failed
		STATUS.undrawn = STATUS.undrawn + (failed and 1 or -1)
		if failed then
			ns.Note(KEY, STATUS.notDrawn)
		elseif STATUS.undrawn == 0 then
			ns.ClearNote(KEY, STATUS.notDrawn)
		end
	end
end

local function Tint(rec)
	local portrait, pic = rec.parts.portrait, rec.pic
	local ok, r, g, b = pcall(portrait.GetVertexColor, portrait)
	if ok and Number(r) and Number(g) and Number(b) and (pic.r ~= r or pic.g ~= g or pic.b ~= b) then
		pic.r, pic.g, pic.b = r, g, b
		pic.texture:SetVertexColor(r, g, b)
	end
	local answered, grey = pcall(portrait.IsDesaturated, portrait)
	if answered and not ns.IsSecret(grey) and type(grey) == "boolean" and pic.grey ~= grey then
		pic.grey = grey
		pic.texture:SetDesaturated(grey)
	end
end

local function NoArea(frame)
	local width, height = Ask(frame, "GetWidth"), Ask(frame, "GetHeight")
	return (Number(width) and width <= 0) or (Number(height) and height <= 0)
end

local function Unmask(rec, key, texture, mask, off)
	if texture == nil or mask == nil or (rec.unmasked[key] or false) == off then
		return
	end
	local method = off and texture.RemoveMaskTexture or texture.AddMaskTexture
	if type(method) == "function" and pcall(method, texture, mask) then
		rec.unmasked[key] = off
	end
end

local Mask = { inPass = false }

function Mask.has(texture, mask)
	local ok, count = pcall(texture.GetNumMaskTextures, texture)
	if not ok or ns.IsSecret(count) or not Number(count) then
		return nil
	end
	for index = 1, count do
		local got, found = pcall(texture.GetMaskTexture, texture, index)
		if got and not ns.IsSecret(found) and rawequal(found, mask) then
			return true
		end
	end
	return false
end

function Mask.sync(rec, off)
	local portrait, mask = rec.parts.portrait, rec.parts.portraitMask
	if portrait == nil or mask == nil or ns.IsSecret(mask) then
		return
	end
	rec.maskOff = off
	if rec.unmasked.portrait and Mask.has(portrait, mask) == true then
		rec.unmasked.portrait = false
	end
	if (rec.unmasked.portrait or false) == off then
		return
	end
	if Mask.inPass then
		Mask.queue(rec)
		return
	end
	Unmask(rec, "portrait", portrait, mask, off)
end

local function ApplyPicture(rec, on, redraw)
	local pic = rec.pic
	if pic == nil then
		return
	end
	local square = on and Opt("squarePortrait") and true or false
	local style, none = ns.UnitFrameExtra.pictureMode(rec)
	none = square and none
	if pic.style ~= style then
		pic.style, redraw = style, true
	end
	local sized = pic.side ~= nil and not NoArea(pic.frame)
	local drawn = square and not none
	local shown = drawn and sized and ((pic.drawn and not redraw) or Draw(rec) == true)
	pic.none = none or nil
	pic.noSize = drawn and not sized
	pic.drawn = shown
	Undrawn(rec, drawn and not shown)
	ns.SetHidden(rec.parts.portrait, shown or none)
	Mask.sync(rec, shown or none or false)
	local round = shown and pic.style ~= "head" and Opt("classShape") == "round" or false
	ns.SetOutlineRound(pic.outline, pic.texture, round, pic.fadeTex)
	local shape = Opt("classShape")
	if round and not pic.outline.round and not ns.roundMissing and InCombatLockdown() then
		if pic.shapeOpt ~= nil and pic.shapeOpt ~= shape then
			ns.UnitFrameExtra.tell(FRAME.TELL)
		end
		if not pic.roundQueued then
			pic.roundQueued = true
			ns.OutOfCombat(function()
				pic.roundQueued = nil
				pcall(Refresh)
			end)
		end
	end
	if not InCombatLockdown() then
		pic.shapeOpt = shape
	end
	pic.round = pic.outline.roundOn == true
	if rec.joined == true then
		ns.SetOutlineEdges(pic.outline, pic.round and Opt("barBorder") ~= false)
		ShowOutline(pic.outline, shown, false)
	else
		ns.SetOutlineEdges(pic.outline, true)
		ShowOutline(pic.outline, shown, true)
	end
	pic.texture:SetShown(shown)
	if shown then
		Tint(rec)
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.picture) do
		Run(hook.part, hook.fn, rec, on, shown)
	end
end

local function Placed(region)
	local ok, points = pcall(region.GetNumPoints, region)
	return not ok or ns.IsSecret(points) or type(points) ~= "number" or points > 0
end

local function Frame(parent, level)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	if level ~= nil then
		frame:SetFrameLevel(level)
	end
	return frame
end

local function Layer(frame, layer, sublevel, partial)
	local texture = frame:CreateTexture(nil, layer, nil, sublevel)
	ns.Own[texture] = true
	if not partial then
		texture:SetAllPoints(frame)
	end
	texture:Hide()
	return texture
end

function FRAME.want(rec)
	return Opt("frameStyle") == "one" and rec.kind ~= "raid" and rec.body ~= nil and Active(rec)
end

function FRAME.gap(rec)
	return ns.Pixels(rec.frame, ns.Get("general.thickness") + (tonumber(Opt("powerSpace")) or 0))
end

function FRAME.powerOn(rec)
	local row = FRAME.POWER[rec.kind]
	return rec.byRole.power ~= nil and (row == nil or Opt(row) ~= false)
end

function FRAME.cell(rec)
	if rec.pic == nil or Opt("squarePortrait") ~= true then
		return false
	end
	local _, none = ns.UnitFrameExtra.pictureMode(rec)
	return not none
end

function FRAME.back()
	if Opt("lookOwn") == true then
		local r, g, b = ns.Colour(KEY .. ".lookBack")
		return r, g, b, (tonumber(Opt("lookBackAlpha")) or 100) / 100
	end
	local r, g, b = ns.Colour("general.backdrop")
	return r, g, b, (tonumber(ns.Get("general.backdropAlpha")) or 100) / 100
end

function FRAME.outlines(rec)
	local pic = rec.pic and rec.pic.outline
	if rec.joined == true and rec.body ~= nil then
		return List(rec.body.outline, pic)
	end
	return List(pic)
end

function FRAME.round(rec)
	return rec.pic ~= nil and rec.pic.round == true
end

function FRAME.inset(rec)
	return FRAME.round(rec) and FRAME.INSET * (rec.pic.side or 0) or 0
end

function FRAME.joined(rec)
	return rec.joined == true and rec.made == true and Active(rec)
end

function FRAME.make(rec, made)
	local owner = rec.parts.owner or rec.frame
	local ok, level = pcall(owner.GetFrameLevel, owner)
	local frame = Frame(rec.frame, ok and Number(level) and math.max(0, level - 1) or nil)
	local outline = ns.Outline(frame, frame)
	if outline == nil then
		return nil
	end
	made[#made + 1] = outline
	return { frame = frame, outline = outline }
end

function FRAME.partsCut(bar)
	local space = tonumber(Opt("powerSpace")) or 0
	return Opt("powerWidth") == "game" and "game" or "same", space > 0 and ns.Pixels(bar, 2 * ns.Get("general.thickness") + space) or 0
end

local function Picture(parts, made)
	local level = parts.owner:GetFrameLevel()
	level = Number(level) and level or nil
	local frame = Frame(parts.owner, level)
	local pic = { frame = frame, texture = Layer(frame, "ARTWORK", 0) }
	pic.fadeTex = Layer(frame, "ARTWORK", 7, true)
	pic.fadeTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	pic.fadeTex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	pic.fadeTex:SetHeight(ROW.height)
	pic.outline = ns.Outline(frame, frame, true)
	made[#made + 1] = pic.outline
	if parts.boss ~= nil then
		local rim = Frame(parts.owner, level)
		rim:SetAllPoints(frame)
		pic.rim = ns.Outline(rim, rim, true)
		made[#made + 1] = pic.rim
		ns.SetOutlineThickness(pic.rim, RIM_PX)
		pic.innerFrame = Frame(parts.owner, level)
		pic.inner = ns.Outline(frame, pic.innerFrame, true)
		made[#made + 1] = pic.inner
		ns.SetOutlineThickness(pic.inner, INNER_PX)
	end
	return pic
end

local function RowLevel(rec)
	if rec.kind == "partypet" then
		local ok, level = pcall(rec.frame.GetFrameLevel, rec.frame)
		return ok and Number(level) and level or nil
	end
	local top
	for _, frame in ipairs(rec.parts.content or {}) do
		local ok, level = pcall(frame.GetFrameLevel, frame)
		if ok and Number(level) and (top == nil or level > top) then
			top = level
		end
	end
	return top and top + 1 or nil
end

local function NameRow(rec)
	local frame = Frame(rec.frame, RowLevel(rec))
	local row = { frame = frame, base = Layer(frame, "BACKGROUND", -8), grad = Layer(frame, "BACKGROUND", 0), fill = Layer(frame, "BACKGROUND", 0),
		mark = Layer(frame, "ARTWORK", 0, true), line = Layer(frame, "ARTWORK", 1, true) }
	row.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	row.mark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	row.mark:SetWidth(ROW.accent)
	row.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	row.line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	pcall(row.line.SetSnapToPixelGrid, row.line, false)
	pcall(row.line.SetTexelSnappingBias, row.line, 0)
	row.level = frame:CreateFontString(nil, "OVERLAY", ROW_FONT)
	row.name = frame:CreateFontString(nil, "OVERLAY", ROW_FONT)
	row.kindMark = frame:CreateFontString(nil, "OVERLAY", ROW_FONT)
	row.kindWord = frame:CreateFontString(nil, "OVERLAY", ROW_FONT)
	row.flag = frame:CreateFontString(nil, "OVERLAY", ROW_FONT)
	for _, text in ipairs({ row.name, row.level, row.kindMark, row.kindWord, row.flag }) do
		ns.Own[text] = true
		pcall(text.SetWordWrap, text, false)
		pcall(text.SetMaxLines, text, 1)
	end
	row.kindMark:SetJustifyH("RIGHT")
	row.level:SetJustifyH("RIGHT")
	row.kindWord:SetJustifyH("RIGHT")
	row.flag:SetJustifyH("RIGHT")
	row.flag:SetTextColor(1, 1, 1, 1)
	row.flag:Hide()
	row.name:SetJustifyH("LEFT")
	return row
end

local function HideRow(row)
	row.paint = nil
	for _, region in ipairs({ row.base, row.grad, row.fill, row.mark, row.line, row.name, row.level, row.kindMark, row.kindWord, row.flag }) do
		region:Hide()
	end
end

function ROW.none(rec)
	return rec.kind == "partypet" and rec.joined == true
end

function ROW.named(rec, rowOn)
	return not rowOn and rec.parts.nameText ~= nil and not LARGE[rec.kind] and not ROW.none(rec)
end

local function RowOn(rec)
	if rec.row == nil or not Active(rec) or Opt("strip") ~= true or Opt("squarePortrait") ~= true or ROW.none(rec) then
		return false
	end
	return LARGE[rec.kind] or rec.kind == "boss" or Opt("smallRow") == true
end

local function RectOf(region)
	local ok, left, bottom, width, height = pcall(region.GetRect, region)
	if ok and Number(left) and Number(bottom) and Number(width) and Number(height) then
		return left, bottom, width, height
	end
	return nil
end

local function Span(upper, lower, frame)
	local _, bottom, _, height = RectOf(upper)
	local _, low = RectOf(lower)
	if bottom == nil or low == nil then
		return nil
	end
	local upperScale, lowerScale, scale = Ask(upper, "GetEffectiveScale"), Ask(lower, "GetEffectiveScale"), Ask(frame, "GetEffectiveScale")
	if not (Number(upperScale) and upperScale > 0 and Number(lowerScale) and lowerScale > 0 and Number(scale) and scale > 0) then
		upperScale, lowerScale, scale = 1, 1, 1
	end
	local span = ((bottom + height) * upperScale - low * lowerScale) / scale
	return span > 0 and span or nil
end

local function SideOf(rec, t, rowOn, tall, g)
	local parts = rec.parts
	local row = tall and ROW.of(rec) + (g or 0) or 0
	local power = rec.byRole.power
	if g ~= nil and not FRAME.powerOn(rec) then
		power = nil
	end
	if parts.standard ~= nil then
		local bottom = parts.standard.bottom
		if g ~= nil and power == nil then
			bottom = parts.standard.slotBottom
		end
		return parts.standard.top + row - bottom, true
	end
	local slot = parts.healthBox or parts.health
	local named = ROW.named(rec, rowOn)
	local span = Span(named and parts.nameText or slot, power and power.bar or slot, rec.pic.frame)
	local fallback = SPAN[rec.kind]
	if g ~= nil and rec.kind == "player" then
		fallback = 20 + (power and g + 10 or 0)
	elseif ROW.none(rec) then
		fallback = SPAN.petBar
	end
	local side = (span or fallback) + row - (named and g == nil and t or 0)
	if side <= 1 then
		return fallback, false
	end
	return side, span ~= nil
end

local function AnchorPicture(rec, t, rowOn, tall, g)
	local parts, frame = rec.parts, rec.pic.frame
	local apart = g or 3 * t
	local row = tall and ROW.of(rec) + (g or 0) or 0
	frame:ClearAllPoints()
	if parts.standard ~= nil then
		frame:SetPoint("TOPLEFT", parts.owner, "LEFT", parts.standard.x + apart, parts.standard.top + row)
		return
	end
	local slot = parts.healthBox or parts.health
	local named = ROW.named(rec, rowOn)
	if named and g ~= nil then
		frame:SetPoint("TOP", parts.nameText, "TOP", 0, 0)
		frame:SetPoint("RIGHT", slot, "LEFT", -g, 0)
		return
	end
	frame:SetPoint("TOPRIGHT", named and parts.nameText or slot, "TOPLEFT", -apart, tall and row or (named and -t or 0))
end

local function SizePicture(rec, t, rowOn, tall, g)
	local pic = rec.pic
	local side, measured = SideOf(rec, t, rowOn, tall, g)
	if pic.side == nil or math.abs(pic.side - side) > 0.01 or NoArea(pic.frame) then
		pic.frame:SetSize(side, side)
		pic.side = side
	end
	pic.measured = measured
end

local function Rooms(rec, rowOn)
	local flag = Opt("pvpFlag")
	local pvp = rowOn and (flag == "word" or flag == "both") and LARGE[rec.kind] and rec.parts.pvpIcon ~= nil
	local shows = (LARGE[rec.kind] or rec.kind == "boss") and ns.UnitFrameExtra.levelWanted(rec)
	return shows and ROW.at(rec) == "end" and ROW.levelRoom or 0, (pvp and ROW.flagRoom or 0) + (pvp and rec.kind == "player" and Opt("pvpTimer") == true and ROW.timerRoom or 0)
end

function FRAME.opts()
	local list = { tostring(ns.Get("general.thickness")) }
	for _, key in ipairs(FRAME.OPTS) do
		list[#list + 1] = tostring(Opt(key))
	end
	return table.concat(list, ":")
end

local function LayoutKey(rec)
	local rowOn = RowOn(rec)
	local level, pvp = Rooms(rec, rowOn)
	return table.concat({ tostring(ns.Pixels(rec.frame, ns.Get("general.thickness"))), tostring(rowOn), level, pvp, tostring(Opt("smallTextSize")), tostring(Opt("portraitSize")), tostring(ROW.at(rec)), tostring(Opt("powerWidth")), tostring(Opt("nameRoom")), tostring(Opt("powerSpace")),
		tostring(Opt("frameStyle")), tostring(FRAME.want(rec)), tostring(FRAME.cell(rec)), tostring(FRAME.powerOn(rec)), tostring(FRAME.gap(rec)) }, ":")
end

function FRAME.place(rec, g, rowOn)
	local parts, body = rec.parts, rec.body.frame
	local slot = parts.healthBox or parts.health
	local named = ROW.named(rec, rowOn)
	local top = rowOn and rec.row.frame or (named and parts.nameText) or slot
	local bottom = FRAME.powerOn(rec) and rec.byRole.power.target or slot
	local near = FRAME.cell(rec) and rec.pic.frame or slot
	local right = parts.side == "right"
	body:ClearAllPoints()
	body:SetPoint("LEFT", right and slot or near, "LEFT", -g, 0)
	body:SetPoint("RIGHT", right and near or slot, "RIGHT", g, 0)
	body:SetPoint("TOP", top, "TOP", 0, g)
	body:SetPoint("BOTTOM", bottom, "BOTTOM", 0, -g)
end

local function Layout(rec)
	for _, hook in ipairs(ns.UnitFrameExtra.before.layout) do
		Run(hook.part, hook.fn, rec)
	end
	local row, pic = rec.row, rec.pic
	rec.joined = FRAME.want(rec)
	local t = ns.Pixels(rec.frame, ns.Get("general.thickness"))
	local g = rec.joined and FRAME.gap(rec) or nil
	local rowOn = RowOn(rec)
	local tall = rowOn and Opt("portraitSize") ~= "bars"
	rec.tall = tall
	local level, pvp = Rooms(rec, rowOn)
	local fit = Opt("nameRoom") ~= "fixed"
	local key = LayoutKey(rec)
	local again = rec.laid ~= key
	rec.laid, rec.laidOpts = key, FRAME.opts()
	rec.pvpRoom = pvp > 0
	local power = rec.byRole and rec.byRole.power
	if again and power ~= nil and power.cut ~= nil and power.cut.place ~= nil then
		if g ~= nil then
			power.cut.place("same", math.max(g, 1))
		else
			power.cut.place(FRAME.partsCut(power.bar))
		end
	end
	if again and row ~= nil then
		local slot = rec.parts.healthBox or rec.parts.health
		if g ~= nil then
			local over = not tall and FRAME.cell(rec) and pic.frame or nil
			local right = rec.parts.side == "right"
			row.frame:SetPoint("BOTTOMLEFT", (not right and over) or slot, "TOPLEFT", 0, g)
			row.frame:SetPoint("BOTTOMRIGHT", (right and over) or slot, "TOPRIGHT", 0, g)
		else
			row.frame:SetPoint("BOTTOMLEFT", slot, "TOPLEFT", -t, t)
			row.frame:SetPoint("BOTTOMRIGHT", slot, "TOPRIGHT", t, t)
		end
		row.frame:SetHeight(ROW.of(rec))
		row.line:SetHeight(t)
		local at, ranked = ROW.at(rec), RANKED[rec.kind]
		for _, text in ipairs({ row.level, row.kindMark, row.kindWord, row.flag, row.name }) do
			text:ClearAllPoints()
		end
		row.hangWord = nil
		row.level:SetJustifyH(at == "before" and "LEFT" or "RIGHT")
		if at == "before" then
			row.level:SetPoint("LEFT", row.frame, "LEFT", ROW.pad, 0)
			if ranked then
				row.kindMark:SetPoint("LEFT", row.level, "RIGHT", ROW.gap, 0)
			end
		elseif at == "end" then
			row.kindMark:SetPoint("RIGHT", row.frame, "RIGHT", ROW.gap - ROW.pad, 0)
			if ranked then
				row.level:SetPoint("RIGHT", row.kindMark, "LEFT", -ROW.gap, 0)
			else
				row.level:SetPoint("RIGHT", row.frame, "RIGHT", -ROW.pad, 0)
			end
		end
		row.name:SetPoint("LEFT", at == "before" and (ranked and row.kindMark or row.level) or row.frame, at == "before" and "RIGHT" or "LEFT",
			at == "before" and ROW.wordGap or ROW.pad, 0)
		if ranked then
			if at == "end" and fit and level > 0 then
				row.hangWord = function()
					row.kindWord:ClearAllPoints()
					row.kindWord:SetPoint("RIGHT", row.level, "LEFT", row.wordOn and -ROW.wordGap or 0, 0)
				end
				row.hangWord()
			elseif at == "end" then
				row.kindWord:SetPoint("RIGHT", row.kindMark, "LEFT", ROW.wordGap - ROW.gap - level, 0)
			else
				row.kindWord:SetPoint("RIGHT", row.frame, "RIGHT", ROW.wordGap - ROW.pad, 0)
			end
			row.flag:SetPoint("RIGHT", row.kindWord, "LEFT", -ROW.wordGap, 0)
			if fit and pvp > 0 then
				row.name:SetPoint("RIGHT", row.flag, "LEFT", -ROW.wordGap, 0)
			else
				row.name:SetPoint("RIGHT", row.kindWord, "LEFT", -ROW.wordGap - pvp, 0)
			end
		elseif fit then
			local edge, edgePoint, gap = row.frame, "RIGHT", -ROW.pad
			if level > 0 then
				edge, edgePoint, gap = row.level, "LEFT", -ROW.wordGap
			end
			row.flag:SetPoint("RIGHT", edge, edgePoint, gap, 0)
			if pvp > 0 then
				row.name:SetPoint("RIGHT", row.flag, "LEFT", -ROW.wordGap, 0)
			else
				row.name:SetPoint("RIGHT", edge, edgePoint, gap, 0)
			end
		else
			row.flag:SetPoint("RIGHT", row.frame, "RIGHT", -ROW.pad - level, 0)
			row.name:SetPoint("RIGHT", row.frame, "RIGHT", -ROW.pad - level - pvp, 0)
		end
	end
	if pic ~= nil then
		if again then
			AnchorPicture(rec, t, rowOn, tall, g)
			if pic.innerFrame ~= nil then
				local inset = ns.Pixels(rec.frame, INNER_PX)
				pic.innerFrame:SetPoint("TOPLEFT", pic.frame, "TOPLEFT", inset, -inset)
				pic.innerFrame:SetPoint("BOTTOMRIGHT", pic.frame, "BOTTOMRIGHT", -inset, inset)
			end
		end
		SizePicture(rec, t, rowOn, tall, g)
		pic.sized = true
		if pic.noSize and not NoArea(pic.frame) then
			Run(LABELS[rec.kind], Apply, rec)
		end
		if not pic.measured and rec.retries < 3 and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			rec.retries = rec.retries + 1
			C_Timer.After(0, function()
				ns.OutOfCombat(function()
					Run(LABELS[rec.kind], Layout, rec)
				end)
			end)
		end
	end
	if again and rec.body ~= nil then
		FRAME.place(rec, g or FRAME.gap(rec), rowOn)
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.layout) do
		Run(hook.part, hook.fn, rec, t, rowOn)
	end
end

local function CutMask(bar, frame)
	local mask = bar:CreateMaskTexture()
	ns.Own[mask] = true
	Shape(mask, nil, false, true)
	mask:SetAllPoints(frame)
	return mask
end

local function PowerSpan(parts)
	local bar, slot = parts.power, parts.healthBox or parts.health
	local parent = parts.badges or parts.owner
	local across, side, frame = Frame(parent), Frame(parent), Frame(parent)
	local cut = { across = across, side = side, frame = frame, mask = CutMask(bar, frame), always = true }
	function cut.place(mode, drop)
		local key = mode .. ":" .. tostring(drop)
		if cut.mode == key then
			return
		end
		cut.mode = key
		across:ClearAllPoints()
		side:ClearAllPoints()
		frame:ClearAllPoints()
		if mode == "same" then
			across:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
			if drop > 0 then
				across:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, -drop)
			else
				across:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
			end
			side:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 0, 0)
			side:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
			frame:SetPoint("TOPLEFT", across, "BOTTOMLEFT", 0, 0)
			frame:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 0)
		elseif parts.clip == "right" then
			across:SetPoint("TOPLEFT", slot, "TOPRIGHT", 0, 0)
			across:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
			frame:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
			frame:SetPoint("BOTTOMRIGHT", across, "BOTTOMLEFT", 0, 0)
		else
			across:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
			if drop > 0 then
				across:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, -drop)
			else
				across:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
			end
			frame:SetPoint("TOPLEFT", across, "BOTTOMLEFT", 0, 0)
			frame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		end
	end
	cut.place(FRAME.partsCut(bar))
	return cut
end

local function Make(rec, made)
	local parts = rec.parts
	local placed = {}
	for _, role in ipairs({ "health", "power" }) do
		local bar = parts[role]
		local box = role == "health" and parts.healthBox or bar
		if bar ~= nil and not ns.Forbidden(bar) and not ns.Forbidden(box) then
			local target, cut = box, nil
			if role == "power" and parts.clip ~= nil and parts.health ~= nil then
				cut = PowerSpan(parts)
				target = cut.frame
				placed[#placed + 1] = cut.across
				placed[#placed + 1] = target
			elseif role == "health" and parts.cutHealth then
				cut = { mask = CutMask(bar, box) }
			end
			local outline = ns.Outline(box, target)
			if outline then
				made[#made + 1] = outline
				if rec.kind == "partypet" and outline.holder ~= nil then
					local okLevel, level = pcall(rec.frame.GetFrameLevel, rec.frame)
					if okLevel and Number(level) then
						pcall(outline.holder.SetFrameLevel, outline.holder, level)
					end
				end
				local entry = { role = role, bar = bar, mask = parts[role .. "Mask"], outline = outline, cut = cut, target = target,
					slot = role == "health" and parts.cutHealth and box or nil }
				rec.bars[#rec.bars + 1] = entry
				rec.byRole[role] = entry
			end
		end
	end
	if parts.portrait ~= nil and parts.owner ~= nil and not ns.Forbidden(parts.owner) then
		rec.pic = Picture(parts, made)
	end
	if ROW.kinds[rec.kind] and not ns.Forbidden(parts.badges or rec.frame) then
		rec.row = NameRow(rec)
	end
	if rec.kind ~= "raid" and not ns.Forbidden(rec.frame) then
		rec.body = FRAME.make(rec, made)
	end
	Layout(rec)
	if rec.pic then
		placed[#placed + 1] = rec.pic.frame
	end
	if rec.row then
		placed[#placed + 1] = rec.row.frame
	end
	if rec.body then
		placed[#placed + 1] = rec.body.frame
	end
	for _, outline in ipairs(made) do
		placed[#placed + 1] = outline.top
	end
	for _, region in ipairs(placed) do
		if not Placed(region) then
			return false
		end
	end
	return true
end

local function Build(rec)
	local made = {}
	local ok, done = pcall(Make, rec, made)
	if ok and done then
		rec.made = true
		ns.Count(KEY)
		if rec.kind == "raid" then
			ns.Note(KEY, "Unit frames: the buffs and debuffs on raid frames are drawn by the game and keep their default look.")
		end
		return true
	end
	for _, outline in ipairs(made) do
		ns.SetOutline(outline, false, false)
	end
	if rec.row then
		HideRow(rec.row)
	end
	rec.refused = true
	if ok then
		ns.Note(KEY, "Unit frames: the game refused a border on one frame, which keeps its default art.")
	else
		ns.Note(KEY, "Unit frames: a border could not be made on one frame, which keeps its default art. " .. tostring(done))
	end
	return false
end

local function Smaller(entry)
	local slot, bar = entry.slot, entry.bar
	if slot == nil then
		return false
	end
	local ok, sw, sh = pcall(slot.GetSize, slot)
	local answered, bw, bh = pcall(bar.GetSize, bar)
	return ok and answered and Number(sw) and Number(sh) and Number(bw) and Number(bh) and (sw < bw - 0.5 or sh < bh - 0.5)
end

local function Clip(entry, fill, on)
	local cut = entry.cut
	if cut == nil or fill == nil then
		return
	end
	local want = on and (cut.always or Radius() ~= nil or Smaller(entry)) and true or false
	if (cut.on or false) == want then
		return
	end
	local method = want and fill.AddMaskTexture or fill.RemoveMaskTexture
	if type(method) == "function" and pcall(method, fill, cut.mask) then
		cut.on = want
	end
end

local function PowerColour(bar)
	local token, colours = bar.powerToken, PowerBarColor
	if type(token) == "string" and not ns.IsSecret(token) and type(colours) == "table" and not ns.IsSecret(colours) then
		local info = colours[token]
		if type(info) == "table" and not ns.IsSecret(info) and Number(info.r) and Number(info.g) and Number(info.b) then
			return info.r, info.g, info.b
		end
	end
	return COLOUR.mana[1], COLOUR.mana[2], COLOUR.mana[3]
end

local function ApplyFill(rec, entry, on)
	local done = false
	if on and Opt("flat") then
		local raid = rec.kind == "raid"
		local r, g, b = 1, 1, 1
		local file = ns.UnitFrameExtra.fillFile(entry.role)
		if not raid and entry.role == "health" then
			if ns.UnitFrameExtra.healthColour then
				r, g, b = ns.UnitFrameExtra.healthColour(rec, entry)
			else
				r, g, b = ns.Colour(KEY .. ".healthColour")
			end
			if ns.UnitFrameExtra.healthLeft and ns.UnitFrameExtra.healthLeft(rec, entry) then
				r, g, b, file = 1, 1, 1, ns.UnitFrameExtra.leftFile()
			end
		elseif not raid then
			if ns.UnitFrameExtra.powerColour then
				r, g, b = ns.UnitFrameExtra.powerColour(rec, entry, PowerColour(entry.bar))
			else
				r, g, b = PowerColour(entry.bar)
				if r == nil then
					r, g, b = ns.Colour(KEY .. ".powerColour")
				end
			end
		end
		local flat, refused = ns.FlatFill(entry.bar, r, g, b, nil, raid, file)
		if flat == false then
			ns.Note(KEY, refused and "Unit frames: the game refused a flat fill on a bar, which keeps its default fill."
				or "Unit frames: the default fill of a bar could not be read and is still shown.")
		end
		done = flat == true
	elseif ns.RestoreFill(entry.bar) == false then
		ns.Note(KEY, "Unit frames: the game refused to put back the default fill of a bar.")
	end
	local fill = entry.fill or ns.FillRegion(entry.bar)
	entry.fill = fill
	Unmask(rec, entry.role, fill, entry.mask, done)
	Clip(entry, fill, on)
	return done
end

local function Texts(parts, entry)
	local list, seen = {}, {}
	local function add(value)
		if value ~= nil and not seen[value] and type(value.GetFont) == "function" then
			seen[value] = true
			list[#list + 1] = value
		end
	end
	for _, holder in ipairs({ entry.bar, entry.role == "health" and parts.textBox or entry.bar }) do
		for _, key in ipairs(TEXT_KEYS) do
			add(Path(holder, key))
		end
	end
	for _, name in ipairs(parts.named and parts.named[entry.role] or {}) do
		add(Path(_G, name))
	end
	return list
end

local function ApplyText(rec, entry, on)
	local percent = 100
	if on and LARGE[rec.kind] then
		percent = Opt(entry.role .. "TextSize")
	elseif on and rec.kind ~= "boss" and rec.kind ~= "raid" then
		percent = Opt("smallTextSize")
	end
	local light = on and Opt("lookLightText") == true and rec.kind ~= "boss" and rec.kind ~= "raid"
	if light then
		percent = percent * 0.85
	end
	local hide = on and entry.role == "power" and Opt("lookNoPowerText") == true
	local spec = { percent = percent, flags = light and "" or nil }
	local styled = ns.UnitFrameExtra.barSpec ~= nil and ns.UnitFrameExtra.barSpec(rec, entry, on, spec)
	entry.textSpec = spec
	for _, text in ipairs(Texts(rec.parts, entry)) do
		if ns.TextStyle(text, spec) == false and styled then
			ns.UnitFrameExtra.refused(rec, "bars", entry.role)
		end
		if hide then
			ns.SetFaded(text, true)
		elseif entry.textFaded then
			ns.SetFaded(text, false)
		end
	end
	entry.textFaded = hide or nil
end

local function ApplyNameSize(rec, on)
	if rec.parts.nameText ~= nil and not LARGE[rec.kind] and rec.kind ~= "boss" then
		local spec = { percent = on and Opt("smallTextSize") or 100 }
		local styled = ns.UnitFrameExtra.nameSpec ~= nil and ns.UnitFrameExtra.nameSpec(rec, on, spec)
		if ns.TextStyle(rec.parts.nameText, spec) == false and styled then
			ns.UnitFrameExtra.refused(rec, "names", "name")
		end
	end
end

local function PetTint(rec, flat)
	local r, g, b = COLOUR.pet[1], COLOUR.pet[2], COLOUR.pet[3]
	if flat and ns.UnitFrameExtra.fillImage("health") then
		if ns.UnitFrameExtra.healthColour then
			r, g, b = ns.UnitFrameExtra.healthColour(rec, rec.byRole.health)
		else
			r, g, b = ns.Colour(KEY .. ".healthColour")
		end
	elseif flat then
		r, g, b = 1, 1, 1
	elseif not rec.tinted then
		return
	end
	local bar = rec.parts.health
	pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
	rec.tinted = flat or nil
end

local function Rgb(colour)
	if colour then
		return colour[1], colour[2], colour[3]
	end
end

function ns.UnitFrameExtra.calmTank(rec)
	local isTank = ns.UnitFrameExtra.isTank
	return (rec.kind == "party" or rec.kind == "raid") and Opt("threatTanks") == "hidden" and isTank ~= nil and isTank(UnitOf(rec)) == true
end

function FRAME.colour(rec, on, r, g, b)
	local parts, pic = rec.parts, rec.pic
	local square = Squared(rec, on)
	if r == nil and square and parts.status ~= nil and Opt("status") then
		r, g, b = Lit(parts.status)
	end
	local look = r == nil and square and parts.boss ~= nil and Opt("elite") and rec.rank and RANKS[rec.rank] or nil
	if look then
		r, g, b = Rgb(look.colour)
	end
	if rec.byRole.health then
		ColourOutline(rec.byRole.health.outline, nil, nil, nil)
	end
	ColourOutline(rec.body.outline, r, g, b)
	if pic ~= nil then
		pic.coloured = r ~= nil
		ColourOutline(pic.outline, r, g, b)
		ShowOutline(pic.rim, false, false)
		ShowOutline(pic.inner, false, false)
	end
end

local function Colour(rec, on)
	local parts = rec.parts
	local r, g, b
	if on and Opt("threat") and parts.flash ~= nil and not ns.UnitFrameExtra.calmTank(rec) then
		r, g, b = Lit(parts.flash)
	end
	if r == nil and on and Opt("threat") and parts.debuff ~= nil then
		r, g, b = Lit(parts.debuff)
	end
	local aim = Opt("targetBorder")
	if on and parts.select ~= nil and aim ~= "off" then
		local sr, sg, sb = Lit(parts.select)
		if sr ~= nil then
			if aim == "own" then
				sr, sg, sb = ns.Colour(KEY .. ".targetColour")
			end
			r, g, b = sr, sg, sb
		end
	end
	local pic = rec.pic
	if rec.joined == true then
		FRAME.colour(rec, on, r, g, b)
	else
		if rec.byRole.health then
			ColourOutline(rec.byRole.health.outline, r, g, b)
		end
		if pic ~= nil then
			local square = Squared(rec, on)
			r, g, b = nil, nil, nil
			if square and parts.status ~= nil and Opt("status") then
				r, g, b = Lit(parts.status)
			end
			local look = square and not pic.none and parts.boss ~= nil and Opt("elite") and rec.rank and RANKS[rec.rank] or nil
			if look then
				r, g, b = Rgb(look.colour)
			end
			pic.coloured = r ~= nil
			ColourOutline(pic.outline, r, g, b)
			ColourOutline(pic.rim, Rgb(look and look.colour))
			ShowOutline(pic.rim, look ~= nil and not pic.round, false)
			ColourOutline(pic.inner, Rgb(look and look.inner))
			ShowOutline(pic.inner, look ~= nil and look.inner ~= nil and not pic.round, false)
		end
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.colour) do
		Run(hook.part, hook.fn, rec, on)
	end
end

function FRAME.tapped(unit)
	if unit == nil or type(UnitIsTapDenied) ~= "function" or type(UnitPlayerControlled) ~= "function" then
		return false
	end
	local ok, denied = pcall(UnitIsTapDenied, unit)
	if not ok or ns.IsSecret(denied) or denied ~= true then
		return false
	end
	local okControl, controlled = pcall(UnitPlayerControlled, unit)
	return okControl and not ns.IsSecret(controlled) and controlled == false
end

function FRAME.reaction(unit)
	if FRAME.tapped(unit) then
		return ns.Colour("general.reactionTapped")
	end
	return ns.ReactionColour(unit)
end

local function RowColour(rec)
	local r, g, b
	local kind, from = rec.kind, nil
	if kind == "player" or kind == "pet" then
		r, g, b = ns.ClassColour()
		from = "class"
	elseif kind == "party" then
		r, g, b = ns.ClassColourOf(UnitOf(rec))
		from = "class"
	elseif kind == "partypet" then
		local owner = (UnitOf(rec) or ""):match("^partypet(%d+)$")
		r, g, b = ns.ClassColourOf(owner and "party" .. owner or nil)
		from = "class"
	elseif kind == "tot" or kind == "target" or kind == "focus" or kind == "boss" then
		local unit = UnitOf(rec)
		local ok, player = pcall(UnitIsPlayer, unit)
		if ok and not ns.IsSecret(player) and player == true then
			r, g, b = ns.ClassColourOf(unit)
			from = "class"
		elseif ok and not ns.IsSecret(player) and player == false then
			r, g, b = FRAME.reaction(unit)
			from = FRAME.tapped(unit) and "tapped" or "reaction"
		end
	end
	if r == nil and rec.parts.strip ~= nil and IsLit(rec.parts.strip) then
		local ok, sr, sg, sb = pcall(rec.parts.strip.GetVertexColor, rec.parts.strip)
		if ok and Number(sr) and Number(sg) and Number(sb) then
			r, g, b = sr, sg, sb
			from = "the game's colour"
		end
	end
	if r == nil and kind == "boss" then
		r, g, b = ns.ReactionColour(UnitOf(rec))
		from = "reaction"
	end
	rec.colourFrom = r ~= nil and from or nil
	if r == nil then
		return nil
	end
	if ns.UnitFrameExtra.mute then
		r, g, b = ns.UnitFrameExtra.mute(r, g, b)
	end
	local bright = Opt("stripBrightness") / 100
	r, g, b = r * bright, g * bright, b * bright
	local cap = FRAME.CAP[Opt("stripColour")]
	local light = 0.30 * r + 0.59 * g + 0.11 * b
	if cap ~= nil and light > cap then
		local scale = cap / light
		r, g, b = r * scale, g * scale, b * scale
	end
	return r, g, b
end

local function Solid(texture, radius, r, g, b, a)
	if radius then
		Shape(texture, radius)
		texture:SetVertexColor(r, g, b, a)
	else
		Unslice(texture)
		texture:SetVertexColor(1, 1, 1, 1)
		texture:SetColorTexture(r, g, b, a)
	end
end

local function Gradient(texture, radius, r, g, b, bottom, top)
	if type(CreateColor) ~= "function" or type(texture.SetGradient) ~= "function" then
		return false
	end
	Solid(texture, radius, 1, 1, 1, 1)
	return pcall(function()
		texture:SetGradient("VERTICAL", CreateColor(r, g, b, bottom), CreateColor(r, g, b, top))
	end)
end

local function PaintRow(rec)
	local row = rec.row
	local r, g, b = RowColour(rec)
	local mode = r ~= nil and Opt("stripColour") or "dark"
	local top = ROW.strong * (100 - Opt("stripFade")) / 100
	local br, bg, bb, alpha = FRAME.back()
	local key = table.concat({ mode, tostring(r), tostring(g), tostring(b), tostring(row.radius), top, br, bg, bb, alpha, tostring(rec.opaque), tostring(rec.joined) }, ":")
	if row.paint == key then
		return
	end
	row.paint = key
	local gradient = mode == "gradient" and Gradient(row.grad, row.radius, r, g, b, ROW.strong, top) == true
	if mode == "gradient" and not gradient then
		mode = "flat"
	end
	row.grad:SetShown(gradient)
	row.fill:SetShown(not gradient and not (mode == "dark" and rec.joined == true))
	if mode == "flat" then
		Solid(row.fill, row.radius, r, g, b, ROW.strong)
	elseif mode == "dark" then
		Solid(row.fill, row.radius, br, bg, bb, alpha)
	end
	row.mark:SetShown(mode == "dark" and r ~= nil)
	if mode == "dark" and r ~= nil then
		row.mark:SetColorTexture(r, g, b, 1)
	end
	row.base:SetShown(rec.opaque == true)
	if rec.opaque then
		Solid(row.base, row.radius, br, bg, bb, 1)
	end
end

local function CopyText(from, to)
	if from == nil then
		return false
	end
	local ok, text = pcall(from.GetText, from)
	if not ok or not (ns.IsSecret(text) or Plain(text) or Number(text)) then
		return false
	end
	return pcall(to.SetText, to, text) and true or false
end

local function UnitText(unit)
	if unit == nil or type(UnitName) ~= "function" then
		return nil
	end
	local ok, name, surname = pcall(UnitName, unit)
	if not ok or not Plain(name) then
		return nil
	end
	local firstOnly = false
	pcall(function()
		firstOnly = RegionalUniqueNamesEnabled() == true and UnitIsUnit(unit, "player") == true and C_PlayerInfo.ShouldDisplaySurname() == false
	end)
	if firstOnly then
		local fine, first = pcall(function()
			return NameUtil.GetUnitFirstName(unit)
		end)
		return fine and Plain(first) and first or name
	end
	if Plain(surname) then
		local fine, separator = pcall(function()
			return Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
		end)
		return name .. (fine and Plain(separator) and separator or " ") .. surname
	end
	return name
end

function ROW.wordColour(rec)
	local row = rec.row
	local pick, wr, wg, wb = Opt("pvpWordColour"), 1, 1, 1
	if pick == "red" then
		wr, wg, wb = COLOUR.level[1], COLOUR.level[2], COLOUR.level[3]
	elseif pick == "name" then
		local fine, nr, ng, nb = pcall(row.name.GetTextColor, row.name)
		if not (fine and Number(nr) and Number(ng) and Number(nb)) then
			return
		end
		wr, wg, wb = nr, ng, nb
	end
	row.flagColour = { wr, wg, wb }
	local fine, alpha = pcall(row.flag.GetAlpha, row.flag)
	if fine and Number(alpha) then
		row.flag:SetTextColor(wr, wg, wb, alpha)
	end
end

local function CopyFont(rec)
	local row, from = rec.row, rec.parts.nameText
	if from == nil then
		return
	end
	local ok, file, size, flags = pcall(from.GetFont, from)
	if ok and not ns.IsSecret(file) and not ns.IsSecret(size) and not ns.IsSecret(flags) and type(file) == "string" and Number(size) and size > 0
		and (flags == nil or type(flags) == "string") then
		local key = file .. size .. tostring(flags) .. tostring(Opt("levelSize"))
		if row.font ~= key then
			row.font = key
			for _, text in ipairs({ row.name, row.kindWord, row.flag }) do
				pcall(text.SetFont, text, file, size, flags)
			end
			local scaled = math.floor(size * (ROW.sizes[Opt("levelSize")] or 1) * 10 + 0.5) / 10
			for _, text in ipairs({ row.level, row.kindMark }) do
				pcall(text.SetFont, text, file, scaled, flags)
			end
		end
	end
	local answered, r, g, b = pcall(from.GetTextColor, from)
	if answered and Number(r) and Number(g) and Number(b) then
		row.name:SetTextColor(r, g, b, 1)
	end
end

local function ReadRank(rec)
	rec.rank = RANKED[rec.kind] and ns.UnitKind(UnitOf(rec)) or nil
end

local function Tag(text, word, colour)
	text:SetText(word or "")
	if word then
		text:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
	text:SetShown(word ~= nil)
end

local function Kind(rec)
	local row = rec.row
	if row == nil then
		return
	end
	local look = not ns.PartStopped(KEY, KIND_PART) and RowOn(rec) and rec.rank and RANKS[rec.rank] or nil
	if look == nil then
		row.kindMark:Hide()
		row.kindWord:Hide()
		row.line:Hide()
	end
	local colour = look and look.colour
	local mark = look and look.mark ~= nil and Opt("kindMark") == true and row.level:IsShown() and look.mark or nil
	Tag(row.kindMark, mark, colour)
	local word = look and Opt("kindWord") == true and look.word or nil
	Tag(row.kindWord, word, colour)
	if row.wordOn ~= (word ~= nil) then
		row.wordOn = word ~= nil
		if row.hangWord ~= nil then
			row.hangWord()
		end
	end
	local line = look ~= nil and Opt("kindLine") == true
	if line then
		row.line:SetColorTexture(colour[1], colour[2], colour[3], 1)
	end
	row.line:SetShown(line)
end

local function RowText(rec)
	local row, parts = rec.row, rec.parts
	if row == nil then
		return
	end
	CopyFont(rec)
	local unit = UnitOf(rec)
	local name = UnitText(unit)
	if name ~= nil then
		row.name:SetText(name)
		row.source = "unit name"
	elseif CopyText(parts.nameText, row.name) then
		row.source = "copied from the game's text"
	else
		local withheld = false
		if unit ~= nil and type(UnitName) == "function" then
			local ok = pcall(function()
				local value = (UnitName(unit))
				row.name:SetText(value)
				withheld = ns.IsSecret(value)
			end)
			withheld = ok and withheld
		end
		if withheld then
			row.source = "unit name"
		elseif not (rec.kind == "boss" and row.source ~= nil and row.source ~= "empty") then
			row.name:SetText("")
			row.source = "empty"
		end
	end
	local shown, level = false, nil
	local wanted = ns.UnitFrameExtra.levelWanted(rec)
	if not wanted then
		shown = false
	elseif parts.levelText ~= nil and IsLit(parts.levelText) then
		shown = true
		if not CopyText(parts.levelText, row.level) and unit ~= nil and type(UnitEffectiveLevel) == "function" then
			pcall(function()
				row.level:SetText((UnitEffectiveLevel(unit)))
			end)
		end
		local ok, r, g, b = pcall(parts.levelText.GetVertexColor, parts.levelText)
		if ok and Number(r) and Number(g) and Number(b) then
			level = { r, g, b }
		end
	elseif wanted and parts.high ~= nil and IsLit(parts.high) then
		shown = true
		local colour = type(QuestDifficultyColors) == "table" and not ns.IsSecret(QuestDifficultyColors) and QuestDifficultyColors.impossible
		local r, g, b = COLOUR.level[1], COLOUR.level[2], COLOUR.level[3]
		if type(colour) == "table" and not ns.IsSecret(colour) and Number(colour.r) and Number(colour.g) and Number(colour.b) then
			r, g, b = colour.r, colour.g, colour.b
		end
		row.level:SetText("??")
		level = { r, g, b }
	end
	local colour = Opt("levelColour")
	if colour == "white" then
		level = { 1, 1, 1 }
	elseif colour == "name" then
		local ok, r, g, b = pcall(row.name.GetTextColor, row.name)
		if ok and Number(r) and Number(g) and Number(b) then
			level = { r, g, b }
		end
	end
	if level then
		row.level:SetTextColor(level[1], level[2], level[3], 1)
	end
	if not shown then
		pcall(row.level.SetText, row.level, "")
	end
	row.levelOn = shown
	row.level:SetShown(shown and (ROW.at(rec) == "end" or ROW.at(rec) == "before"))
	Run(KIND_PART, Kind, rec)
	for _, hook in ipairs(ns.UnitFrameExtra.after.rowText) do
		Run(hook.part, hook.fn, rec)
	end
	ROW.wordColour(rec)
end

local function Walk(frame, fn, depth)
	if depth > 8 or ns.Forbidden(frame) or ns.Own[frame] then
		return
	end
	local ok, regions = pcall(function()
		return { frame:GetRegions() }
	end)
	for _, region in ipairs(ok and regions or {}) do
		if type(region) == "table" and not ns.IsSecret(region) and not ns.Own[region] then
			fn(region)
		end
	end
	local answered, children = pcall(function()
		return { frame:GetChildren() }
	end)
	for _, child in ipairs(answered and children or {}) do
		Walk(child, fn, depth + 1)
	end
end

local function BandName(region)
	local atlas = Ask(region, "GetAtlas")
	if type(atlas) == "string" and atlas ~= "" then
		return atlas
	end
	local file = Ask(region, "GetTexture")
	if (type(file) == "string" and file ~= "") or Number(file) then
		return tostring(file)
	end
	return "no name"
end

local function KnownParts(rec)
	local known = {}
	for _, value in pairs(rec.parts) do
		known[value] = true
	end
	for _, region in ipairs(rec.parts.art) do
		known[region] = true
	end
	for _, entry in ipairs(rec.bars) do
		known[ns.FillRegion(entry.bar) or entry] = true
		known[Path(entry.bar, "Background") or entry] = true
	end
	return known
end

local function Sweep(rec)
	local _, bottom, width, height = RectOf(rec.row.frame)
	if bottom == nil then
		return
	end
	local known = KnownParts(rec)
	Walk(rec.frame, function(region)
		if known[region] or rec.bands[region] ~= nil then
			return
		end
		local alpha = Ask(region, "GetAlpha")
		if Ask(region, "GetObjectType") ~= "Texture" or Ask(region, "IsShown") ~= true or not Number(alpha) or alpha <= 0 then
			return
		end
		local l, b, w, h = RectOf(region)
		if l ~= nil and h <= 30 and w >= width / 2 and b + h / 2 >= bottom and b + h / 2 <= bottom + height then
			rec.bands[region] = alpha
			rec.lines[("Unit frames: hid the game's name band (%s)."):format(BandName(region))] = true
		end
	end, 0)
	rec.swept = true
end

local function Bands(rec, shown)
	for region, was in pairs(rec.bands) do
		if shown then
			ns.SetFaded(region, true)
		else
			pcall(region.SetAlpha, region, was)
		end
	end
	for line in pairs(rec.lines) do
		if shown then
			ns.Note(KEY, line)
		else
			ns.ClearNote(KEY, line)
		end
	end
end

local function ApplyRow(rec)
	local parts, row = rec.parts, rec.row
	if row == nil then
		return
	end
	local shown = RowOn(rec)
	if shown and rec.kind == "player" and not InCombatLockdown() then
		Sweep(rec)
	end
	rec.opaque = rec.kind == "player" and shown and not rec.joined and (not rec.swept or next(rec.bands) == nil)
	ns.SetFaded(parts.nameText, shown)
	ns.SetFaded(parts.strip, shown)
	local noLevel = rec.made and Active(rec) and not ns.UnitFrameExtra.levelWanted(rec)
	ns.SetFaded(parts.levelText, shown or noLevel)
	ns.SetFaded(parts.level, shown or noLevel)
	ns.SetFaded(parts.high, shown or noLevel)
	Bands(rec, shown)
	if shown then
		PaintRow(rec)
		RowText(rec)
		pcall(row.name.SetAlpha, row.name, 1)
		pcall(row.level.SetAlpha, row.level, 1)
		row.name:SetShown(not rec.nameHidden)
	else
		row.source = nil
		HideRow(row)
	end
end

local function FlagMode(rec)
	local parts = rec.parts
	if parts.pvp == nil and parts.pvpIcon == nil then
		return nil
	end
	local pick = ns.UnitFrameExtra.pvpMode
	if not Squared(rec, Active(rec)) or rec.pic.side == nil or rec.pic.none then
		return pick and pick(rec, "game") or "game"
	end
	local mode = Opt("pvpFlag")
	if (mode == "word" or mode == "both") and not (LARGE[rec.kind] and RowOn(rec)) then
		mode = "icon"
	end
	return pick and pick(rec, mode) or mode
end

local ApplyFlag
local function PlacePlate(rec, corner)
	local parts = rec.parts
	local plate = parts.pvp or (FLAG.home[rec.kind] ~= nil and parts.pvpIcon or nil)
	local inset = corner and FRAME.inset(rec) or 0
	local spot = corner and (inset > 0 and ("%s:round:%.1f"):format(corner, inset) or corner) or false
	if plate == nil or (rec.plateAt or false) == spot then
		return
	end
	if InCombatLockdown() then
		if not rec.plateQueued then
			rec.plateQueued = true
			ns.OutOfCombat(function()
				rec.plateQueued = nil
				Run(LABELS[rec.kind], ApplyFlag, rec)
			end)
		end
		return
	end
	if rec.plateHome == nil then
		local ok, point, relative, relativePoint, x, y = pcall(plate.GetPoint, plate, 1)
		local home = (parts.pvp ~= nil and FLAG.plateHome or FLAG.home)[rec.kind]
		if ok and Plain(point) and Plain(relativePoint) and type(relative) == "table" and not ns.IsSecret(relative) and Number(x) and Number(y) then
			rec.plateHome = { point, relative, relativePoint, x, y }
		else
			rec.plateHome = { home[1], parts.pvpHome, home[2], home[3], home[4] }
		end
	end
	local icon = parts.pvp ~= nil and parts.pvpIcon or nil
	if icon ~= nil and rec.iconHome == nil then
		local ok, point, relative, relativePoint, x, y = pcall(icon.GetPoint, icon, 1)
		if ok and Plain(point) and Plain(relativePoint) and type(relative) == "table" and not ns.IsSecret(relative) and Number(x) and Number(y) then
			rec.iconHome = { point, relative, relativePoint, x, y }
		else
			rec.iconHome = { "CENTER", plate, "CENTER", 0, 0 }
		end
	end
	local home, moved = rec.plateHome, false
	if corner then
		local width, height = Ask(plate, "GetSize")
		local at = FLAG.corner[corner]
		local halfWidth = Number(width) and width > 0 and width / 2 or FLAG.half
		local halfHeight = Number(height) and height > 0 and height / 2 or FLAG.half
		moved = pcall(function()
			plate:ClearAllPoints()
			plate:SetPoint("CENTER", rec.pic.frame, at[1], at[2] * (halfWidth + inset), at[3] * (halfHeight + inset))
			if icon ~= nil then
				icon:ClearAllPoints()
				icon:SetPoint("CENTER", plate, "CENTER", 0, 0)
			end
		end)
	else
		local iconHome = rec.iconHome
		moved = pcall(function()
			plate:ClearAllPoints()
			plate:SetPoint(home[1], home[2], home[3], home[4], home[5])
			if icon ~= nil then
				icon:ClearAllPoints()
				icon:SetPoint(iconHome[1], iconHome[2], iconHome[3], iconHome[4], iconHome[5])
			end
		end)
	end
	if moved and Placed(plate) and (icon == nil or Placed(icon)) then
		rec.plateAt = spot
		rec.plateRefused = nil
	else
		pcall(function()
			plate:ClearAllPoints()
			plate:SetPoint(home[1], home[2], home[3], home[4], home[5])
			if icon ~= nil then
				local iconHome = rec.iconHome
				icon:ClearAllPoints()
				icon:SetPoint(iconHome[1], iconHome[2], iconHome[3], iconHome[4], iconHome[5])
			end
		end)
		rec.plateAt, rec.plateRefused = false, true
		ns.Note(KEY, "Unit frames: the game refused to move a PvP flag, which keeps its own place.")
	end
end

local function FlagWord(rec, on)
	local row, parts = rec.row, rec.parts
	if row == nil then
		return
	end
	if not on or not LARGE[rec.kind] or parts.pvpIcon == nil or not rec.pvpRoom then
		row.flag:Hide()
		row.flagState = nil
		if Opt("nameRoom") ~= "fixed" and row.flagText ~= nil then
			row.flagText = nil
			row.flag:SetText("")
		end
		return
	end
	local word = "PvP"
	pcall(function()
		if UnitIsPVPFreeForAll(UnitOf(rec)) == true then
			word = "FFA"
		end
	end)
	if rec.kind == "player" and Opt("pvpTimer") == true and parts.pvpTimer ~= nil and IsLit(parts.pvpTimer) then
		local left = Ask(parts.pvpTimer, "GetText")
		if Plain(left) then
			word = word .. " " .. left
		end
	end
	local icon = parts.pvpIcon
	local ok, shown = pcall(icon.IsShown, icon)
	if ok and not ns.IsSecret(shown) and shown ~= true and Opt("nameRoom") ~= "fixed" then
		word = ""
	end
	if row.flagText ~= word then
		row.flagText = word
		row.flag:SetText(word)
	end
	row.flag:Show()
	if row.flagColour ~= nil then
		row.flag:SetTextColor(row.flagColour[1], row.flagColour[2], row.flagColour[3], 1)
	end
	if not ok then
		row.flag:SetAlpha(0)
		row.flagState = "withheld by the game"
	elseif ns.IsSecret(shown) then
		row.flagState = "withheld by the game"
		if type(row.flag.SetAlphaFromBoolean) ~= "function" or not pcall(row.flag.SetAlphaFromBoolean, row.flag, shown, 1, 0) then
			row.flag:SetAlpha(0)
		end
	else
		row.flag:SetAlpha(shown == true and 1 or 0)
		row.flagState = shown == true and "shown" or "not flagged"
	end
end

function ApplyFlag(rec)
	local mode = FlagMode(rec)
	if mode == nil then
		return
	end
	local parts = rec.parts
	local icon, word = mode == "icon" or mode == "both", mode == "word" or mode == "both"
	PlacePlate(rec, icon and Opt("pvpCorner") or nil)
	local art = mode == "word" or mode == "off"
	ns.SetFaded(parts.pvp, art)
	ns.SetFaded(parts.pvpIcon, art)
	ns.SetFaded(parts.pvpTimer, art or mode == "both" or (mode == "icon" and Opt("pvpTimer") ~= true))
	FlagWord(rec, word)
	rec.flag = mode
end

local function ApplyLoss(rec, on)
	ns.SetFaded(rec.parts.loss and ns.FillRegion(rec.parts.loss), on)
end

local function Outlines(rec)
	local list = {}
	for _, entry in ipairs(rec.bars) do
		list[#list + 1] = entry.outline
	end
	if rec.pic ~= nil then
		list[#list + 1] = rec.pic.outline
		list[#list + 1] = rec.pic.rim
		list[#list + 1] = rec.pic.inner
	end
	if rec.body ~= nil then
		list[#list + 1] = rec.body.outline
	end
	return list
end

local function Reshape(rec, radius, joined)
	local ok = true
	local cells = not joined and radius or nil
	for _, entry in ipairs(rec.bars) do
		if entry.cut == nil and cells then
			entry.cut = { mask = CutMask(entry.bar, entry.target) }
		end
		if entry.cut then
			ok = Shape(entry.cut.mask, cells, false, true) and ok
		end
	end
	local body = rec.body and rec.body.outline
	for _, outline in ipairs(Outlines(rec)) do
		local shape = cells
		if outline == body then
			shape = joined and radius or nil
		end
		if shape then
			ok = Round(outline, shape) and ok
		else
			Unround(outline)
		end
	end
	if rec.row then
		rec.row.radius = cells
		rec.row.paint = nil
		rec.row.line:SetPoint("BOTTOMLEFT", rec.row.frame, "BOTTOMLEFT", cells or 0, 0)
		rec.row.line:SetPoint("BOTTOMRIGHT", rec.row.frame, "BOTTOMRIGHT", -(cells or 0), 0)
	end
	return ok
end

local function Corners(rec, on)
	local radius = on and Radius() or nil
	local joined = rec.joined == true
	if tostring(radius) .. ":" .. tostring(joined) ~= (rec.cornerKey or "nil:false") then
		if InCombatLockdown() then
			if rec.cornerKey ~= nil then
				ns.UnitFrameExtra.tell(FRAME.TELL)
			end
			if not rec.cornersQueued then
				rec.cornersQueued = true
				ns.OutOfCombat(function()
					rec.cornersQueued = nil
					pcall(Refresh)
				end)
			end
			return
		end
		if radius and not Reshape(rec, radius, joined) then
			noSlice = true
			ns.Note(KEY, "Unit frames: the game refused sliced textures, so corners stay square.")
			radius = nil
			Reshape(rec, nil, joined)
		elseif radius == nil then
			Reshape(rec, nil, joined)
		end
		rec.radius = radius
		rec.cornerKey = tostring(radius) .. ":" .. tostring(joined)
		for _, entry in ipairs(rec.bars) do
			Clip(entry, entry.fill, on)
		end
	end
	for _, outline in ipairs(rec.radius and Outlines(rec) or {}) do
		Rim(outline)
	end
end

function Apply(rec)
	local on = Active(rec)
	if not rec.made then
		if not on or rec.refused then
			return
		end
		if InCombatLockdown() then
			if not rec.queued then
				rec.queued = true
				ns.OutOfCombat(function()
					rec.queued = nil
					Run(LABELS[rec.kind], Apply, rec)
				end)
			end
			return
		end
		if not Build(rec) then
			return
		end
	end
	if not InCombatLockdown() then
		rec.joined = FRAME.want(rec)
	end
	local parts = rec.parts
	for _, entry in ipairs(rec.bars) do
		local live = on and (entry.role ~= "power" or rec.kind ~= "raid" or Opt("raidCells") == true)
		ns.SetOutlineEdges(entry.outline, not rec.joined and Opt("barBorder") ~= false)
		ShowOutline(entry.outline, live, Opt("backdrop"))
		local flat = ApplyFill(rec, entry, live)
		ApplyText(rec, entry, live)
		if rec.kind == "partypet" then
			PetTint(rec, flat)
		end
	end
	if rec.body ~= nil then
		ns.SetOutlineEdges(rec.body.outline, Opt("barBorder") ~= false)
		ShowOutline(rec.body.outline, on and rec.joined == true, Opt("backdrop"))
	end
	ApplyNameSize(rec, on)
	for _, region in ipairs(parts.art) do
		ns.SetFaded(region, on)
	end
	ApplyPicture(rec, on)
	local square = Squared(rec, on)
	ns.SetFaded(parts.boss, square)
	local rest = rec.kind == "player" and on and Opt("restAnimation") or "auto"
	ns.SetFaded(parts.rest, rest == "hide" or (rest == "auto" and square and Opt("status")))
	ns.SetFaded(parts.flash, on)
	ns.SetFaded(parts.debuff, on)
	ApplyLoss(rec, on)
	ClearGlow(rec, square)
	Colour(rec, on)
	Corners(rec, on)
	if not InCombatLockdown() then
		Layout(rec)
	elseif rec.laid ~= LayoutKey(rec) then
		if rec.laidOpts ~= nil and rec.laidOpts ~= FRAME.opts() then
			ns.UnitFrameExtra.tell(FRAME.TELL)
		end
		if not rec.layoutQueued then
			rec.layoutQueued = true
			ns.OutOfCombat(function()
				rec.layoutQueued = nil
				Run(LABELS[rec.kind], Apply, rec)
			end)
		end
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.apply) do
		Run(hook.part, hook.fn, rec, on)
	end
	ApplyRow(rec)
	ApplyFlag(rec)
	for _, hook in ipairs(ns.UnitFrameExtra.after.final) do
		Run(hook.part, hook.fn, rec, on)
	end
end

local function OnFrame(frame)
	local rec = Known(frame)
	if rec then
		Run(LABELS[rec.kind], Apply, rec)
	end
end

local function OnPlayerArt()
	local was = Mask.inPass
	Mask.inPass = true
	OnFrame(_G.PlayerFrame)
	Mask.inPass = was
end

local function OnPlayerStatus()
	local rec = Known(_G.PlayerFrame)
	if rec and rec.made then
		Run(LABELS.player, Colour, rec, Active(rec))
		if rec.row then
			Run(LABELS.player, Bands, rec, RowOn(rec))
		end
	end
end

local function OnRowText(rec)
	if rec and rec.made and rec.row and RowOn(rec) then
		Run(LABELS[rec.kind], RowText, rec)
		if not LARGE[rec.kind] then
			Run(LABELS[rec.kind], PaintRow, rec)
		end
	end
end

local function OnUnitFrame(frame)
	local rec = Known(frame)
	OnRowText(rec)
	if rec then
		ns.UnitFrameExtra.unitChanged(rec)
	end
end

local function OnPlayerLevel()
	local rec = Known(_G.PlayerFrame)
	if rec and rec.made and rec.row and RowOn(rec) then
		Run(LABELS.player, ApplyRow, rec)
	end
end

local function OnPlayerPvP()
	local rec = Known(_G.PlayerFrame)
	if rec and rec.made then
		Run(LABELS.player, ApplyFlag, rec)
	end
end

local function OnPvPTimer()
	local rec = Known(_G.PlayerFrame)
	if rec and rec.made and (rec.flag == "word" or rec.flag == "both") and Opt("pvpTimer") == true then
		local timer = rec.parts.pvpTimer
		local ok, text = pcall(timer.GetText, timer)
		local key = ok and Plain(text) and IsLit(timer) and text or false
		if key ~= rec.timerKey then
			rec.timerKey = key
			Run(LABELS.player, FlagWord, rec, true)
		end
	end
end

local function OnThreat(indicator)
	if indicator == nil or ns.IsSecret(indicator) then
		return
	end
	local rec = byFlash[indicator]
	if rec and rec.made and Active(rec) then
		ns.SetFaded(indicator, true)
		Run(LABELS[rec.kind], Colour, rec, true)
	end
end

local function OnPowerType(bar)
	if bar == nil or ns.IsSecret(bar) then
		return
	end
	local rec = byPower[bar]
	if rec and rec.made and rec.byRole.power and Active(rec) and Opt("flat") then
		Run(LABELS[rec.kind], ApplyFill, rec, rec.byRole.power, true)
	end
end

local function OnHealthUpdate(bar)
	if bar == nil or ns.IsSecret(bar) then
		return
	end
	local rec = byHealth[bar]
	if rec and rec.tinted then
		Run(LABELS.partypet, PetTint, rec, true)
	end
end

local function OnPortrait(frame)
	local rec = Known(frame)
	if rec and rec.made and rec.pic and Active(rec) and Opt("squarePortrait") then
		if rec.kind == "tot" then
			local now = type(GetTime) == "function" and GetTime() or nil
			if Number(now) then
				local last = rec.pic.drawnAt
				if last ~= nil and now >= last and now - last < TOT.every then
					return
				end
				rec.pic.drawnAt = now
			end
		end
		local was = rec.pic.failed
		Mask.inPass = true
		Run(LABELS[rec.kind], ApplyPicture, rec, true, true)
		Mask.inPass = false
		if rec.pic.failed ~= was then
			Run(LABELS[rec.kind], Apply, rec)
		end
	end
end

local function OnTint(frame)
	local rec = Known(frame)
	if rec and rec.made and rec.pic and Squared(rec, Active(rec)) then
		Run(LABELS[rec.kind], Tint, rec)
		for _, hook in ipairs(ns.UnitFrameExtra.after.tint) do
			Run(hook.part, hook.fn, rec)
		end
	end
end

local function OnTargetChange()
	for _, rec in pairs(records) do
		if rec.kind == "tot" and rec.pic then
			rec.pic.drawnAt = nil
		end
	end
	ns.UnitFrameExtra.unitsChanged()
end

local function IsTargetUnit(unit)
	return not ns.IsSecret(unit) and (unit == "target" or unit == "focus")
end

local function Reread(rec)
	ReadRank(rec)
	if rec.made and Active(rec) then
		Colour(rec, true)
		Kind(rec)
	end
end

local function Reclassify(unit)
	for _, rec in pairs(records) do
		if RANKED[rec.kind] and (unit == nil or ns.IsSecret(unit) or UnitOf(rec) == unit) then
			Run(KIND_PART, Reread, rec)
		end
	end
end

local function IsChangingUnit(unit)
	if ns.IsSecret(unit) or type(unit) ~= "string" then
		return true
	end
	return unit == "target" or unit == "focus" or unit == "targettarget" or unit == "focustarget" or unit:match("^party%d$") ~= nil
		or unit:match("^partypet%d$") ~= nil or unit:match("^boss%d$") ~= nil
end

local function IsClassifiedUnit(unit)
	return ns.IsSecret(unit) or unit == "target" or unit == "focus"
end

local function OnPetAttack()
	local rec = Known(_G.PetFrame)
	if rec and rec.made and Active(rec) then
		Run(LABELS.pet, Colour, rec, true)
	end
end

local function IsIconSetting(name)
	return not ns.IsSecret(name) and (name == "ReplaceMyPlayerPortrait" or name == "ReplaceOtherPlayerPortraits")
end

local function OnIconSetting()
	for _, rec in pairs(records) do
		if rec.made and rec.pic and Active(rec) and Opt("squarePortrait") then
			Run(LABELS[rec.kind], ApplyPicture, rec, true, true)
		end
	end
end

local function HookGlobal(name, fn)
	if hooked[name] or type(hooksecurefunc) ~= "function" or type(_G[name]) ~= "function" then
		return
	end
	hooked[name] = ns.FollowGlobal(name, fn) == true
end

local function FramesOf(kind)
	local list = {}
	if kind == "party" or kind == "partypet" then
		local pool = Path(_G.PartyFrame, "PartyMemberFramePool")
		if pool and type(pool.EnumerateActive) == "function" then
			for frame in pool:EnumerateActive() do
				if kind == "party" then
					list[#list + 1] = frame
				elseif not ns.Forbidden(frame) then
					list[#list + 1] = Path(frame, "PetFrame")
				end
			end
		end
		return list
	elseif kind == "raid" then
		local names = {}
		for index = 1, 5 do
			names[#names + 1] = "CompactPartyFrameMember" .. index
			names[#names + 1] = "CompactPartyFramePet" .. index
			for group = 1, 8 do
				names[#names + 1] = ("CompactRaidGroup%dMember%d"):format(group, index)
			end
		end
		local index = 1
		while _G["CompactRaidFrame" .. index] ~= nil do
			names[#names + 1] = "CompactRaidFrame" .. index
			index = index + 1
		end
		for _, name in ipairs(names) do
			list[#list + 1] = _G[name]
		end
		return list
	end
	for _, name in ipairs(ROOTS[kind]) do
		list[#list + 1] = _G[name]
	end
	return list
end

local function StyleTotem(button, on)
	local rec = totems[button]
	if rec == nil then
		if ns.Forbidden(button) then
			return
		end
		local icon = Path(button, "Icon")
		if icon == nil then
			return
		end
		rec = { border = Path(button, "Border"), icon = Path(icon, "Texture"), mask = Path(icon, "TextureMask"), unmasked = {},
			outline = ns.Outline(button, icon) }
		totems[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, Opt("backdrop"))
	ns.SetFaded(rec.border, on)
	Unmask(rec, "icon", rec.icon, rec.mask, on)
end

local function StyleTotems()
	if ns.Enabled(KEY) and Opt("totem") and not ns.PartStopped(KEY, TOTEMS) then
		local pool = not ns.Forbidden(_G.TotemFrame) and _G.TotemFrame.totemPool
		if type(pool) == "table" and not ns.IsSecret(pool) and type(pool.EnumerateActive) == "function" then
			for button in pool:EnumerateActive() do
				Run(TOTEMS, StyleTotem, button, true)
			end
		end
	else
		for button in pairs(totems) do
			Run(TOTEMS, StyleTotem, button, false)
		end
	end
end

local function OnTotems()
	ns.Each(KEY, StyleTotems)
	if ns.UnitFrameExtra.afterTotems ~= nil then
		ns.UnitFrameExtra.afterTotems()
	end
end

local function ColourAura(rec)
	local r, g, b
	if Opt("auraTypeColours") ~= true then
		ns.SetOutlineColour(rec.outline, nil, nil, nil)
		return
	end
	if rec.stealable ~= nil and IsLit(rec.stealable) then
		r, g, b = COLOUR.stealable[1], COLOUR.stealable[2], COLOUR.stealable[3]
	elseif rec.border ~= nil then
		r, g, b = Lit(rec.border)
	end
	ns.SetOutlineColour(rec.outline, r, g, b)
end

ns.UnitFrameExtra.texts = setmetatable({}, { __mode = "k" })

function ns.UnitFrameExtra.auraText(button)
	local count, sweep = Path(button, "Count"), Path(button, "Cooldown")
	local state = ns.UnitFrameExtra.texts[button]
	if state == nil then
		state = { count = count, sweep = sweep }
		ns.UnitFrameExtra.texts[button] = state
	end
	local on = ns.Enabled(KEY) and not ns.PartStopped(KEY, AURAS)
	local percent = on and Opt("auraCountSize") or 100
	if state.count ~= nil and (state.percent or 100) ~= percent then
		if ns.TextStyle(state.count, { percent = percent }) == false then
			ns.Note(KEY, "Unit frames: the game would not give the stack number of a party or pet debuff another size.")
		else
			state.percent = percent
			ns.ClearNote(KEY, "Unit frames: the game would not give the stack number of a party or pet debuff another size.")
		end
	end
	local numbers = on and Opt("auraNumbers") == true
	if state.sweep ~= nil and (numbers or state.numbers) and state.numbers ~= numbers then
		if pcall(state.sweep.SetHideCountdownNumbers, state.sweep, not numbers) then
			state.numbers = numbers or nil
		else
			ns.Note(KEY, "Unit frames: the game would not show the countdown number on a party or pet debuff.")
		end
	end
end

function ns.UnitFrameExtra.auraTexts()
	for button in pairs(ns.UnitFrameExtra.texts) do
		Run(AURAS, ns.UnitFrameExtra.auraText, button)
	end
end

local function StyleAura(button, icon, border, stealable)
	local on = ns.Enabled(KEY) and Opt("auras") and not ns.PartStopped(KEY, AURAS)
	local rec = auras[button]
	if rec == nil then
		if not on or icon == nil or type(icon.SetTexCoord) ~= "function" then
			return
		end
		if InCombatLockdown() then
			if not waiting[button] then
				waiting[button] = true
				ns.OutOfCombat(function()
					waiting[button] = nil
					Run(AURAS, StyleAura, button, icon, border, stealable)
				end)
			end
			return
		end
		rec = { icon = icon, border = border, stealable = stealable, outline = ns.Outline(button, icon) }
		auras[button] = rec
		if border ~= nil then
			byBorder[border] = rec
		end
		ns.Count(KEY)
	end
	if rec.on ~= on then
		rec.on = on
		ns.SetOutline(rec.outline, on, false)
		ns.SetFaded(rec.border, on)
		ns.SetFaded(rec.stealable, on)
		if not on then
			rec.icon:SetTexCoord(0, 1, 0, 1)
			rec.crop = nil
		end
	end
	if on then
		local crop = Opt("auraCrop") / 100
		if rec.crop ~= crop then
			rec.crop = crop
			rec.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		end
		ColourAura(rec)
	end
end

local function StyleToTAuras()
	for _, root in ipairs(ROOTS.tot) do
		for index = 1, TOT.debuffs do
			local name = root .. "Debuff" .. index
			local button = _G[name]
			if not ns.Forbidden(button) then
				Run(AURAS, StyleAura, button, Path(_G, name .. "Icon"), Path(_G, name .. "Border"))
			end
		end
	end
end

local function StyleMemberAuras(rec)
	local pool = Path(rec.frame, "AuraFramePool")
	if pool ~= nil and type(pool.EnumerateActive) == "function" then
		for button in pool:EnumerateActive() do
			if not ns.Forbidden(button) then
				Run(AURAS, StyleAura, button, Path(button, "Icon"), Path(button, "DebuffBorder"))
				Run(AURAS, ns.UnitFrameExtra.auraText, button)
			end
		end
	end
end

local function StyleTargetAuras(frame)
	local container = Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "Auras")
	if container == nil then
		return
	end
	local unreachable = ns.Forbidden(container)
	if not unreachable then
		local ok, buttons = pcall(function()
			return { container:GetChildren() }
		end)
		for _, button in ipairs(ok and buttons or {}) do
			local icon = not ns.Forbidden(button) and Path(button, "Icon")
			if icon then
				Run(AURAS, StyleAura, button, icon, Path(button, "DispelBorder"), Path(button, "StealableBorder"))
			else
				unreachable = true
			end
		end
	end
	if unreachable and ns.Enabled(KEY) and Opt("auras") then
		ns.Note(KEY, "Unit frames: the game blocks addons from the aura icons on the target and focus frames. They keep their default look.")
	end
end

local function OnAuras(frame)
	if ns.Enabled(KEY) and not ns.Forbidden(frame) then
		Run(AURAS, StyleTargetAuras, frame)
	end
end

local function OnAuraBorder(region)
	local rec = not ns.IsSecret(region) and byBorder[region]
	if rec and rec.on then
		ns.SetFaded(region, true)
		Run(AURAS, ColourAura, rec)
	end
end

local function OnMemberAuras(frame)
	local rec = Known(frame)
	if rec then
		if rec.made and Active(rec) and rec.parts.debuff ~= nil then
			ns.SetFaded(rec.parts.debuff, true)
			Run(LABELS[rec.kind], Colour, rec, true)
		end
		Run(AURAS, StyleMemberAuras, rec)
	end
end

local Later = { tasks = {}, queued = false, events = {} }

do
	local function Events(kind, task, list)
		local into = Later.events[kind]
		if into == nil then
			into = {}
			Later.events[kind] = into
		end
		for _, event in ipairs(list) do
			into[event] = into[event] and (into[event] .. " " .. task) or task
		end
	end
	local TARGET = { "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGETABLE_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
		"UNIT_LEVEL", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED", "GROUP_ROSTER_UPDATE" }
	for _, kind in ipairs({ "target", "focus", "boss" }) do
		Events(kind, "art", TARGET)
	end
	for _, kind in ipairs({ "target", "focus" }) do
		Events(kind, "auras", { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" })
	end
	Events("party", "art tint auras", { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UPDATE_ACTIVE_BATTLEFIELD", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_PET" })
	Events("party", "art", { "UNIT_CONNECTION" })
	Events("party", "auras", { "UNIT_AURA", "VARIABLES_LOADED" })
	Events("pet", "art auras", { "UNIT_PET", "UNIT_EXITED_VEHICLE", "PET_UI_UPDATE" })
	Events("pet", "auras", { "UNIT_AURA" })
	Later.edit = { target = "auras", focus = "art auras", boss = "art", party = "art tint auras", pet = "art auras" }
	Later.petEvents = { UNIT_AURA = true, UNIT_PET = true, VARIABLES_LOADED = true, PLAYER_ENTERING_WORLD = true, GROUP_ROSTER_UPDATE = true }
end

local function Settled(frame, wanted)
	if wanted.art then
		OnFrame(frame)
	end
	if wanted.tint then
		OnTint(frame)
	end
	if wanted.mask then
		local rec = Known(frame)
		if rec and rec.made and rec.pic and rec.maskOff ~= nil then
			Run(LABELS[rec.kind], Mask.sync, rec, rec.maskOff)
		end
	end
	if wanted.auras then
		local rec = Known(frame)
		if rec and (rec.kind == "target" or rec.kind == "focus") then
			OnAuras(frame)
		elseif rec then
			OnMemberAuras(frame)
		end
	end
	if wanted.party then
		Later.party()
	end
	if wanted.totems then
		OnTotems()
	end
end

function Later.run()
	local tasks = Later.tasks
	Later.tasks, Later.queued = {}, false
	for frame, wanted in pairs(tasks) do
		local ok, err = pcall(Settled, frame, wanted)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

function Later.add(frame, task)
	if frame == nil or ns.IsSecret(frame) then
		return
	end
	local wanted = Later.tasks[frame]
	if wanted == nil then
		wanted = {}
		Later.tasks[frame] = wanted
	end
	for word in task:gmatch("%a+") do
		wanted[word] = true
	end
	if not Later.queued then
		Later.queued = true
		if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" or not pcall(C_Timer.After, 0, Later.run) then
			Later.run()
		end
	end
end

function Mask.queue(rec)
	Later.add(rec.frame, "mask")
end

function Later.script(frame, script, fn)
	if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" then
		return
	end
	local done = hooked[frame]
	if done == nil then
		done = {}
		hooked[frame] = done
	end
	if done[script] or type(frame.HookScript) ~= "function" then
		return
	end
	done[script] = pcall(frame.HookScript, frame, script, fn)
end

function Later.onEvent(frame, event)
	local rec = Known(frame)
	if rec == nil or type(event) ~= "string" then
		return
	end
	local tasks = Later.events[rec.kind] and Later.events[rec.kind][event]
	if tasks then
		Later.add(frame, tasks)
	end
	if rec.kind == "party" and Later.petEvents[event] then
		local pet = Path(frame, "PetFrame")
		if pet and Known(pet) then
			Later.add(pet, "auras")
		end
	elseif rec.kind == "boss" and event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		for _, other in ipairs(FramesOf("boss")) do
			if Known(other) then
				Later.add(other, "art")
			end
		end
	end
end

function Later.layout()
	if Known(_G.PetFrame) then
		Later.add(_G.PetFrame, "art auras")
	end
	if not ns.Forbidden(_G.TotemFrame) then
		Later.add(_G.TotemFrame, "totems")
	end
end

function Later.editMode()
	for frame, rec in pairs(records) do
		if Later.edit[rec.kind] then
			Later.add(frame, Later.edit[rec.kind])
		end
	end
	if not ns.Forbidden(_G.PartyFrame) then
		Later.add(_G.PartyFrame, "party")
	end
end

local function StyleFrame(frame, kind)
	if not ns.Forbidden(frame) then
		local rec = Record(kind, frame)
		if rec then
			if Later.events[kind] ~= nil then
				Later.script(frame, "OnEvent", Later.onEvent)
			end
			if kind == "party" then
				Later.script(rec.parts.health, "OnValueChanged", function()
					Later.add(frame, "tint")
				end)
			elseif kind == "pet" then
				Later.script(frame, "OnShow", function()
					Later.add(frame, "art auras")
					Later.add(_G.TotemFrame, "totems")
				end)
				Later.script(frame, "OnHide", function()
					Later.add(_G.TotemFrame, "totems")
				end)
			end
			if kind == "player" and rec.parts.pvpTimer ~= nil then
				Later.script(frame, "OnUpdate", OnPvPTimer)
			end
			ReadRank(rec)
			Run(LABELS[kind], Apply, rec)
			if kind == "target" or kind == "focus" then
				Run(AURAS, StyleTargetAuras, frame)
			elseif kind == "party" or kind == "partypet" or kind == "pet" then
				Run(AURAS, StyleMemberAuras, rec)
			end
		end
	end
end

local function Style(kind)
	for _, frame in ipairs(FramesOf(kind)) do
		Run(LABELS[kind], StyleFrame, frame, kind)
	end
end

local function OnParty()
	if ns.Enabled(KEY) then
		for _, frame in ipairs(FramesOf("party")) do
			local rec = Known(frame)
			if rec then
				rec.unmasked = {}
			end
		end
		ns.Each(KEY, Style, "party")
		ns.Each(KEY, Style, "partypet")
	end
end

local function IsRaidFrame(frame)
	local ok, name = pcall(frame.GetName, frame)
	if ok and not ns.IsSecret(name) and type(name) == "string" then
		for _, pattern in ipairs(RAID_NAMES) do
			if name:find(pattern) then
				return true
			end
		end
	end
	return false
end

function ns.UnitFrameExtra.isGroupFrame(frame)
	if ns.Forbidden(frame) then
		return false
	end
	if IsRaidFrame(frame) then
		return true
	end
	for _, kind in ipairs({ "party", "partypet" }) do
		for _, member in ipairs(FramesOf(kind)) do
			if rawequal(member, frame) then
				return true
			end
		end
	end
	return false
end

local function OnRaidSetUp(frame)
	if ns.Enabled(KEY) and not ns.Forbidden(frame) and IsRaidFrame(frame) then
		Run(LABELS.raid, StyleFrame, frame, "raid")
	end
end

local function OnRaid(frame)
	local rec = Known(frame)
	if rec and rec.made and Active(rec) then
		for _, region in ipairs(rec.parts.art) do
			ns.SetFaded(region, true)
		end
		Run(LABELS.raid, Colour, rec, true)
		if rec.byRole.power ~= nil and Opt("raidCells") == true then
			Run(LABELS.raid, ApplyFill, rec, rec.byRole.power, true)
		end
	end
end

local function InstallHooks()
	HookGlobal("PlayerFrame_ToPlayerArt", function()
		OnPlayerArt()
		Later.layout()
	end)
	HookGlobal("PlayerFrame_ToVehicleArt", function()
		OnPlayerArt()
		Later.layout()
	end)
	HookGlobal("PlayerFrame_UpdateArt", Later.layout)
	HookGlobal("PlayerFrame_UpdateStatus", OnPlayerStatus)
	HookGlobal("PlayerFrame_UpdateRolesAssigned", OnPlayerArt)
	HookGlobal("PlayerFrame_UpdateLevel", OnPlayerLevel)
	HookGlobal("PlayerFrame_UpdatePvPStatus", OnPlayerPvP)
	HookGlobal("UnitFrame_Update", OnUnitFrame)
	HookGlobal("UnitFramePortrait_Update", OnPortrait)
	HookGlobal("UnitFrame_UpdateThreatIndicator", OnThreat)
	HookGlobal("UnitFrameManaBar_UpdateType", OnPowerType)
	HookGlobal("UnitFrameHealthBar_Update", OnHealthUpdate)
	HookGlobal("CompactUnitFrame_SetUpFrame", OnRaidSetUp)
	for _, name in ipairs(RAID_UPDATES) do
		HookGlobal(name, OnRaid)
	end
	HookGlobal("CompactUnitFrame_UpdateAll", function(frame)
		local rec = Known(frame)
		if rec and rec.made and Active(rec) then
			for _, hook in ipairs(ns.UnitFrameExtra.after.raid) do
				Run(hook.part, hook.fn, rec, true)
			end
		end
	end)
	Later.party = OnParty
	if not ns.Forbidden(_G.PartyFrame) then
		Later.script(_G.PartyFrame, "OnShow", function()
			Later.add(_G.PartyFrame, "party")
		end)
	end
	if not ns.Forbidden(_G.TotemFrame) then
		Later.script(_G.TotemFrame, "OnEvent", function()
			Later.add(_G.TotemFrame, "totems")
		end)
	end
	if type(_G.AuraUtil) == "table" and not ns.IsSecret(_G.AuraUtil) and not hooked.AuraUtil and type(hooksecurefunc) == "function"
		and type(_G.AuraUtil.SetAuraBorderColor) == "function" then
		hooked.AuraUtil = ns.FollowTable(_G.AuraUtil, "SetAuraBorderColor", OnAuraBorder) == true
	end
	local manager = _G.EditModeManagerFrame
	if manager ~= nil and not ns.Forbidden(manager) then
		Later.script(manager, "OnShow", Later.editMode)
		Later.script(manager, "OnHide", Later.editMode)
	end
end

local ART = {
	{ "PlayerFrame", "PlayerFrameContainer", "PlayerFrameContent", "PlayerFrameContent.PlayerFrameContentMain",
		"PlayerFrameContent.PlayerFrameContentContextual", "PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer",
		"PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar", "PlayerFrameContent.PlayerFrameContentMain.ManaBarArea",
		"PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar" },
	{ "TargetFrame", "TargetFrameContainer", "TargetFrameContent", "TargetFrameContent.TargetFrameContentMain",
		"TargetFrameContent.TargetFrameContentContextual", "TargetFrameContent.TargetFrameContentMain.HealthBarsContainer",
		"TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar", "TargetFrameContent.TargetFrameContentMain.ManaBar" },
}
local ART_LINES = 40

local function Descend(root, dotted)
	local value = root
	for key in dotted:gmatch("[^.]+") do
		value = Path(value, key)
	end
	return value
end

local function Text(value)
	if value == nil or ns.IsSecret(value) or (type(value) ~= "string" and type(value) ~= "number") then
		return "?"
	end
	return tostring(value)
end

local function Size(value)
	return Number(value) and ("%d"):format(math.floor(value + 0.5)) or "?"
end

local function Share(value)
	return Number(value) and ("%.2f"):format(value) or "?"
end

local function ArtLine(label, region)
	local layer, sublevel = Ask(region, "GetDrawLayer")
	local atlas = Ask(region, "GetAtlas")
	local what = type(atlas) == "string" and atlas ~= "" and atlas or Ask(region, "GetTexture")
	local width, height = Ask(region, "GetSize")
	local r, g, b, a = Ask(region, "GetVertexColor")
	return ("%s %s:%s %s %sx%s %s,%s,%s,%s alpha %s"):format(label, Text(layer), Text(sublevel), Text(what), Size(width), Size(height),
		Share(r), Share(g), Share(b), Share(a), Share((Ask(region, "GetAlpha"))))
end

local function ArtOf(frame, label, lines)
	local ok, regions = pcall(function()
		return { frame:GetRegions() }
	end)
	for _, region in ipairs(ok and type(regions) == "table" and not ns.IsSecret(regions) and regions or {}) do
		if type(region) == "table" and not ns.IsSecret(region) and not ns.Own[region] and Ask(region, "GetObjectType") == "Texture"
			and Ask(region, "IsShown") == true then
			lines[#lines + 1] = ArtLine(label, region)
		end
	end
end

local function PrintArt()
	local lines = {}
	for _, entry in ipairs(ART) do
		local root = _G[entry[1]]
		if not ns.Forbidden(root) then
			lines[#lines + 1] = entry[1]
			ArtOf(root, entry[1], lines)
			for index = 2, #entry do
				local frame = Descend(root, entry[index])
				if frame ~= nil and not ns.Forbidden(frame) then
					ArtOf(frame, entry[index]:match("[^.]+$"), lines)
				end
			end
		end
	end
	for index = 1, math.min(#lines, ART_LINES) do
		if index == ART_LINES and #lines > ART_LINES then
			print(("%d more"):format(#lines - ART_LINES + 1))
		else
			print(lines[index])
		end
	end
end

function STATUS.picture(rec, name)
	local pic = rec.pic
	if pic == nil then
		return nil
	end
	local text
	if not (Active(rec) and Opt("squarePortrait") == true) then
		text = "off"
	elseif pic.none then
		text = "off, no portrait"
	elseif pic.noSize then
		text = "no size, the game's portrait shown"
	elseif pic.failed then
		text = "could not be drawn, the game's portrait shown"
	else
		local width, height = Ask(pic.frame, "GetSize")
		local size = Number(width) and Number(height) and ("shown, %s x %s"):format(Size(width), Size(height))
			or ("shown, size not given, set %s x %s"):format(Size(pic.side), Size(pic.side))
		text = ("%s, %s, %s, frame level %s%s%s, %s"):format(size, pic.round and "round" or "square",
			rec.joined and "one frame" or rec.radius and "rounded border" or "square corners", Size(Ask(pic.frame, "GetFrameLevel")),
			pic.measured == false and ", sized from the default layout" or "", Ask(pic.frame, "IsRectValid") == false and ", no place on screen" or "", pic.icon and "class icon" or "face")
	end
	return ("%s portrait: %s"):format(name, text)
end

function STATUS.identity(rec, name)
	local unit = UnitOf(rec)
	if unit == nil or type(C_Secrets) ~= "table" or ns.IsSecret(C_Secrets) or type(C_Secrets.ShouldUnitIdentityBeSecret) ~= "function" then
		return nil
	end
	local ok, withheld = pcall(C_Secrets.ShouldUnitIdentityBeSecret, unit)
	if not ok or ns.IsSecret(withheld) or type(withheld) ~= "boolean" then
		return nil
	end
	return ("%s identity: %s"):format(name, withheld and "withheld" or "not withheld")
end

function STATUS.flag(rec, name)
	local mode = FlagMode(rec)
	local text
	local ok, active = pcall(function()
		return C_GameRules.IsGameRuleActive(Enum.GameRule.UnitFramePvPContextualDisabled)
	end)
	if mode == nil then
		return nil
	elseif type(UnitFrameUtil) ~= "table" or ns.IsSecret(UnitFrameUtil) or type(UnitFrameUtil.UpdateUnitPvPIndicator) ~= "function" then
		text = "the game draws none"
	elseif ok and not ns.IsSecret(active) and active == true then
		text = "turned off by the game's rules"
	elseif mode == "game" then
		text = "as the game draws it"
	elseif mode == "off" then
		text = "off"
	elseif mode == "word" then
		text = "word in the name row, " .. (rec.row.flagState or "not flagged")
	else
		local shape = mode == "both" and "icon on the portrait and word in the name row, " or "icon on the portrait, "
		if rec.plateQueued then
			text = shape .. "waiting for the end of combat"
		elseif rec.plateRefused then
			text = shape .. "the game refused the move"
		else
			local icon = rec.parts.pvpIcon
			local answered, shown = false, nil
			if icon ~= nil then
				answered, shown = pcall(icon.IsShown, icon)
			end
			text = shape .. (answered and not ns.IsSecret(shown) and (shown == true and "shown" or "not flagged") or "withheld by the game")
			if icon ~= nil and rec.plateAt then
				local at, _, relative = pcall(icon.GetPoint, icon, 1)
				local on = at and not ns.IsSecret(relative)
				if rec.parts.pvp ~= nil then
					text = text .. (on and relative == rec.parts.pvp and ", icon on the plate" or ", icon apart from the plate")
				else
					text = text .. (on and relative == rec.pic.frame and ", icon on the picture" or ", icon apart from the picture")
				end
			end
		end
	end
	return ("%s PvP flag: %s"):format(name, text)
end

function STATUS.firstParty()
	for _, frame in ipairs(FramesOf("party")) do
		if Known(frame) and Ask(frame, "IsShown") ~= false then
			return frame
		end
	end
	return nil
end

function STATUS.colour(rec, name)
	if not RowOn(rec) or LARGE[rec.kind] then
		return nil
	end
	local r = RowColour(rec)
	local text = rec.colourFrom
	if r == nil then
		text = "dark"
		if rec.kind == "tot" then
			local ok, player = pcall(UnitIsPlayer, UnitOf(rec))
			if ok and not ns.IsSecret(player) and player == false then
				text = "dark (no reaction colour)"
			elseif UnitOf(rec) ~= nil then
				text = "dark (class withheld)"
			end
		elseif rec.kind == "party" or rec.kind == "partypet" then
			text = "dark (class withheld)"
		end
	end
	return ("%s name row colour: %s"):format(name, text)
end

function STATUS.size(rec, name)
	if not RowOn(rec) then
		return nil
	end
	local width, height = Ask(rec.row.frame, "GetSize")
	if Number(width) and Number(height) then
		return ("%s row: %s x %s"):format(name, Size(width), Size(height))
	end
	return ("%s row: size not given, set %s high"):format(name, Size(ROW.of(rec)))
end

local function StatusLines()
	local lines = {}
	local frames = { _G.PlayerFrame, _G.TargetFrame, _G.PetFrame, _G.TargetFrameToT, _G.Boss1TargetFrame, STATUS.firstParty() }
	for place = 1, 6 do
		local rec = Known(frames[place])
		if rec and rec.made then
			local name = STATUS.names[rec.kind]
			if STATUS.none[rec.kind] and Ask(rec.frame, "IsShown") == false then
				lines[#lines + 1] = ("%s: %s"):format(name, STATUS.none[rec.kind])
			else
				if rec.row ~= nil and (LARGE[rec.kind] or RowOn(rec)) then
					local source = rec.row.source
					local text = not RowOn(rec) and "as the game draws it" or source == "unit name" and "shown, the unit's name"
						or source == "copied from the game's text" and "shown, the game's text" or "empty"
					lines[#lines + 1] = ("%s name: %s"):format(name, text)
					if LARGE[rec.kind] or rec.kind == "boss" then
						local place = ROW.at(rec)
						local where = not RowOn(rec) and "as the game draws it" or place == "before" and "before the name" or place == "portrait" and "on the portrait"
							or place == "hidden" and "hidden" or "end of the name row"
						if rec.kind == "target" and RowOn(rec) then
							local function width(text)
								local ok, value = pcall(text.GetStringWidth, text)
								return ok and Number(value) and ("%g"):format(math.floor(value * 10 + 0.5) / 10) or "not given"
							end
							where = ("%s, mark width %s, word width %s"):format(where, width(rec.row.kindMark), width(rec.row.kindWord))
						end
						lines[#lines + 1] = ("%s level: %s"):format(name, where)
					end
					lines[#lines + 1] = STATUS.size(rec, name)
					lines[#lines + 1] = STATUS.colour(rec, name)
				end
				if rec.kind == "pet" then
					local _, size = Ask(rec.parts.nameText, "GetFont")
					if Number(size) then
						lines[#lines + 1] = ("%s name: size %g, Small frame text size %d%%"):format(name, math.floor(size * 10 + 0.5) / 10, Opt("smallTextSize"))
					end
				end
				lines[#lines + 1] = STATUS.picture(rec, name)
				if LARGE[rec.kind] or rec.kind == "pet" then
					lines[#lines + 1] = STATUS.identity(rec, name)
					lines[#lines + 1] = STATUS.flag(rec, name)
				end
			end
			if rec.kind == "pet" then
				local pet, player = Ask(_G.PetFrame, "GetEffectiveScale"), Ask(_G.PlayerFrame, "GetEffectiveScale")
				if Number(pet) and Number(player) and player > 0 then
					lines[#lines + 1] = ("Pet frame: %d%% of the player frame's scale"):format(math.floor(pet / player * 100 + 0.5))
				end
				local sized = ns.PetFrameSizeStatus and ns.PetFrameSizeStatus()
				if sized then
					lines[#lines + 1] = sized
				end
			end
		end
	end
	local cells = ns.RaidCellStatus and ns.RaidCellStatus()
	if cells then
		lines[#lines + 1] = cells
	end
	cells = ns.PlayerBarStatus and ns.PlayerBarStatus()
	if cells then
		lines[#lines + 1] = cells
	end
	return lines
end

function Refresh()
	InstallHooks()
	for _, kind in ipairs(KINDS) do
		ns.Each(KEY, Style, kind)
	end
	ns.Each(KEY, StyleTotems)
	ns.Each(KEY, StyleToTAuras)
	if not InCombatLockdown() then
		for button, rec in pairs(auras) do
			if rec.on ~= nil then
				Run(AURAS, StyleAura, button, rec.icon, rec.border, rec.stealable)
			end
		end
		ns.UnitFrameExtra.auraTexts()
	end
	if ns.PetFrameSize then
		ns.PetFrameSize()
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.refresh) do
		Run(hook.part, hook.fn)
	end
end

function ns.PortraitStyleChanged(path)
	if path ~= KEY .. ".portraitStyle" then
		return
	end
	for _, kind in ipairs(KINDS) do
		local row = KEY .. "." .. kind .. "Picture"
		if ns.UnitFrameExtra.per.picture[kind] and ns.Get(row) ~= "auto" then
			ns.Set(row, "auto")
			if type(ns.NotifyOption) == "function" then
				ns.NotifyOption(row)
			end
		end
	end
	if ns.Enabled(KEY) then
		ns.Try(KEY, Refresh)
	end
end

ns.UnitFrameExtra.told = {}
function ns.UnitFrameExtra.tell(line)
	local told = ns.UnitFrameExtra.told
	if told[line] or type(ns.PanelShown) ~= "function" or ns.PanelShown() ~= true then
		return
	end
	told[line] = true
	print(line)
	ns.OutOfCombat(function()
		told[line] = nil
	end)
end

function ns.UnitFrameExtra.pop(region, from, duration)
	local ok, group = pcall(function()
		local pop = region:CreateAnimationGroup()
		ns.Own[pop] = true
		local scale = pop:CreateAnimation("Scale")
		scale:SetScaleFrom(from, from)
		scale:SetScaleTo(1, 1)
		scale:SetOrigin("CENTER", 0, 0)
		scale:SetDuration(duration)
		pcall(scale.SetSmoothing, scale, "OUT")
		return pop
	end)
	return ok and group or nil
end

function ns.UnitFrameExtra.popNow(group)
	if group ~= nil then
		pcall(group.Stop, group)
		pcall(group.Play, group)
	end
end

ns.UnitFrameExtra.opt = Opt
ns.UnitFrameExtra.active = Active
ns.UnitFrameExtra.run = Run
ns.UnitFrameExtra.known = Known
ns.UnitFrameExtra.records = records
ns.UnitFrameExtra.labels = LABELS
ns.UnitFrameExtra.unitOf = UnitOf
ns.UnitFrameExtra.number = Number
ns.UnitFrameExtra.plain = Plain
ns.UnitFrameExtra.path = Path
ns.UnitFrameExtra.ask = Ask
ns.UnitFrameExtra.frame = Frame
ns.UnitFrameExtra.layer = Layer
ns.UnitFrameExtra.gradient = Gradient
ns.UnitFrameExtra.solid = Solid
ns.UnitFrameExtra.shape = Shape
ns.UnitFrameExtra.slice = Slice
function ns.UnitFrameExtra.ownCorners(t)
	local radius = Radius()
	local key = tostring(radius)
	local changed = t.corners ~= key
	if changed then
		t.corners = key
		local round = radius ~= nil and t.outline ~= nil and Round(t.outline, radius) == true and t.mask ~= nil and Shape(t.mask, radius, false, true) == true
		if not round and t.outline ~= nil then
			Unround(t.outline)
		end
		t.round = round
	end
	local ok, fill = pcall(t.bar.GetStatusBarTexture, t.bar)
	fill = ok and not ns.IsSecret(fill) and type(fill) == "table" and fill or nil
	if t.cut ~= nil and (t.cut ~= fill or not t.round) then
		pcall(t.cut.RemoveMaskTexture, t.cut, t.mask)
		t.cut = nil
	end
	if t.round and fill ~= nil and t.cut == nil and pcall(fill.AddMaskTexture, fill, t.mask) then
		t.cut = fill
	end
	return t.round and radius or nil, changed
end
ns.UnitFrameExtra.rowOn = RowOn
ns.UnitFrameExtra.barTexts = Texts
ns.UnitFrameExtra.squared = Squared
ns.UnitFrameExtra.row = ROW
ns.UnitFrameExtra.large = LARGE
ns.UnitFrameExtra.kinds = KINDS
ns.UnitFrameExtra.apply = Apply
ns.UnitFrameExtra.layout = Layout
ns.UnitFrameExtra.outline = ShowOutline
ns.UnitFrameExtra.colourOutline = ColourOutline
ns.UnitFrameExtra.colour = Colour
ns.UnitFrameExtra.joined = FRAME.joined
ns.UnitFrameExtra.tapped = FRAME.tapped
ns.UnitFrameExtra.reaction = FRAME.reaction
ns.UnitFrameExtra.body = function(rec)
	return rec.body and rec.body.frame
end
ns.UnitFrameExtra.roundPicture = FRAME.round
ns.UnitFrameExtra.pictureInset = FRAME.inset
ns.UnitFrameExtra.backColour = FRAME.back
ns.UnitFrameExtra.frameOutlines = FRAME.outlines
ns.UnitFrameExtra.bareOutline = function(outline, bare)
	ns.SetOutlineBare(outline, bare)
	Rim(outline)
end

ns.UnitFrameExtra.pieces = function(kind)
	local list = {}
	for _, rec in pairs(records) do
		if rec.kind == kind and rec.made then
			for _, frame in ipairs(List(rec.body and rec.body.frame, rec.row and rec.row.frame, rec.shadowBox)) do
				list[#list + 1] = { frame = frame }
			end
		end
	end
	return list
end

ns.Register(KEY, {
	label = "Unit frames", Start = Refresh, Refresh = Refresh, Resized = Refresh, Status = StatusLines,
	events = { PET_ATTACK_START = OnPetAttack, PET_ATTACK_STOP = OnPetAttack, CVAR_UPDATE = OnIconSetting,
		PLAYER_TARGET_CHANGED = function() OnTargetChange(); Reclassify("target") end, PLAYER_FOCUS_CHANGED = function() OnTargetChange(); Reclassify("focus") end,
		UNIT_TARGET = OnTargetChange, UNIT_CLASSIFICATION_CHANGED = Reclassify, PLAYER_ENTERING_WORLD = function() Reclassify() end,
		PVP_TIMER_UPDATE = OnPlayerPvP, PLAYER_PVP_FLAG_CHANGED = OnPlayerPvP,
		PLAYER_SPECIALIZATION_CHANGED = function() Later.editMode() end,
		GROUP_ROSTER_UPDATE = function() ns.UnitFrameExtra.unitsChanged() end, UNIT_FACTION = function() ns.UnitFrameExtra.unitsChanged() end },
	filters = { UNIT_FACTION = IsChangingUnit, CVAR_UPDATE = IsIconSetting, UNIT_TARGET = IsTargetUnit, UNIT_CLASSIFICATION_CHANGED = IsClassifiedUnit },
	slash = { art = PrintArt },
	help = { "/flatui art - the textures shown on the player and target frames" },
})
