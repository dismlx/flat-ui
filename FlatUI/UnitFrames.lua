local ADDON_NAME, ns = ...

-- Player, target, focus, pet, target of target, party, party pet, boss and raid frames. The frame art of each is one atlas
-- that cannot be thinned, so it is made transparent and a thin border with a dark background is drawn around the health
-- bar and the power bar. The unit buttons and their bars are protected: art, fills and colours change at
-- any time, and borders are made and anchored out of combat. What the art said is kept as the colour of a
-- border: resting and combat on the picture of the player, an attacking pet on the picture of the pet, the kind of a target or focus
-- (elite, rare, rare elite or boss) on the picture of a target, threat on the health bar, and target as well on a raid frame. A portrait is drawn
-- again as a square picture of the addon's own with a thin border beside the bars, and the portrait of the game is hidden. The picture is a frame
-- with one anchor on a region of the game and a size set from numbers, the rectangles of the game's bars when the client gives them and fixed
-- numbers when it does not, and its texture has no mask at any corner setting. The player, target, focus and boss frames get a name row of the
-- addon's own above the health bar (the pet, target of target, party and party pet frames get a lower one), with the name of the unit (the game's text when the client withholds it), the level copied from the
-- game's text and a colour that fades upward; the round level plate and the art behind the name are made transparent. What a target or focus
-- is (an elite, a rare, a rare elite or a boss, read from its classification) is the colour of the border of its picture, and the name row can
-- have a mark after the level, a word after the name and a line under it in that colour. The round PvP plate of the game is the one region this
-- module anchors: it sits on a corner of the picture with the icon and the timer of the player following it, or the flag is a word in the name
-- row, or both. Corners can be rounded with sliced textures of the addon's own. Totem buttons and the debuff icons of the target of target,
-- party and pet frames are made square with a thin border. The aura icons of the target and focus frames are made in a part of the game that
-- addon code may not reach, and are styled only if the game hands them over; the buffs and debuffs of raid frames are drawn there too.

local KEY = "unitframes"

-- What the files after this one use of it. after: the functions they run after the work of one step on a frame, each { part, fn }, in the order they
-- were added. before: the same for the work that comes first (the layout, which sizes the picture from the bars). The internals they use are fields of this table, set at the end of this file, so that this file keeps no more locals than it has.
-- switches: the setting that turns the picture of each kind of frame on.
ns.UnitFrameExtra = { after = { apply = {}, layout = {}, picture = {}, tint = {}, rowText = {}, colour = {}, raid = {}, final = {}, refresh = {} },
	before = { layout = {} },
	switches = { player = "portraitPlayer", target = "portraitTarget", focus = "portraitFocus", pet = "portraitPet", tot = "portraitTot", party = "portraitParty",
		partypet = "portraitPartypet" } }

local KINDS = { "player", "target", "focus", "pet", "tot", "party", "partypet", "boss", "raid" }
-- What the chat line and /flatui status call a kind of frame, a part that stops alone when its code keeps failing.
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
-- The names of the raid frames and the party frames in raid style.
local RAID_NAMES = { "^CompactPartyFrameMember%d$", "^CompactPartyFramePet%d$", "^CompactRaidGroup%dMember%d$", "^CompactRaidFrame%d+$" }
-- The functions in which the game shows and colours the outlines of a raid frame and sets its background colour.
local RAID_UPDATES = { "CompactUnitFrame_UpdateSelectionHighlight", "CompactUnitFrame_UpdateAggroHighlight", "CompactUnitFrame_UpdateHealthColor",
	"CompactUnitFrame_UpdatePowerColor" }
-- The target of target frame. debuffs: the debuff icons it has. every: the game draws its portrait every frame, so its picture is drawn again this
-- often, in seconds.
local TOT = { debuffs = 4, every = 0.2 }

-- Colours of the addon's own. warning: for a glow that is lit but whose colour the game withholds. mana: for a power bar whose type the game has not
-- set yet. stealable: the border of a buff that can be stolen, the colour of a magic debuff. pet: the game's tint for the health bar of a party pet,
-- which does not lock its colour. level: for a level the game cannot tell, when the game draws no number and the client does not name it.
local COLOUR = { warning = { 1, 0.3, 0.1 }, mana = { 0, 0, 1 }, stealable = { 0.2, 0.6, 1 }, pet = { 0, 1, 0 }, level = { 1, 0.1, 0.1 } }
-- The share of an aura icon or a portrait cut off at each edge.
local CROP = 0.08
-- Where the game lays out the bars of a target in its standard layout, which the picture keeps when a minus mob moves them (Mainline\TargetFrame.lua:
-- 432-434, TargetFrame.xml:213-217): the right edge of the slot of the health bar from the left of the frame, its top above the middle of the frame,
-- and the bottom of the power bar below it.
local STANDARD = { x = 149, top = 10, bottom = -21 }
-- The thickness in screen pixels of the border an elite or rare picture gets, so that it is seen, and of the line inside a Rare Elite's.
local RIM_PX, INNER_PX = 2, 1
-- The corner radius in units of each choice of the Corners setting, and the pixels of the corner textures that keep their size.
local ROUND = { slight = 1, soft = 2 }
local SLICE = 4
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
-- Per radius: the rounded rectangle for fills and masks, and the line around it. Radius 0 is the crisp square that cuts a bar to its slot.
local CORNERS = {
	[0] = { fill = MEDIA .. "Round0.tga" },
	[1] = { fill = MEDIA .. "Round1.tga", line = MEDIA .. "Outline1.tga" },
	[2] = { fill = MEDIA .. "Round2.tga", line = MEDIA .. "Outline2.tga" },
}
-- The frames with the large name row, whose text sizes and picture rows are those of the player.
local LARGE = { player = true, target = true, focus = true }
-- The frames whose unit can be an elite, a rare or a boss, and what is shown for each of them (Core.lua).
local RANKED = { target = true, focus = true }
local RANKS = ns.KINDS
-- The part that shows the mark, the word and the line of a unit's kind, so that a failure there does not stop the frame.
local KIND_PART = "Elite and Rare"
-- The name row. height: in units. accent: the width of the mark at the left end of a dark row. bright: the share of its brightness the colour of the
-- row keeps, so the yellow name reads on it. strong: the opacity of that colour at the bottom of the row. pad: in units, from the edge of the row to
-- its first text. gap: between the mark after the level and the level. wordGap: between the word of a kind and the text inside it. levelRoom: for
-- the level. flagRoom and timerRoom: for the PvP word, and for the time left on the player's flag beside it. The mark and the word of a kind keep
-- no room: they are texts of the addon's own that hang from the edge, and take no width while they have no text. sizes: the share of the name's
-- size that Level size gives the level and its mark. kinds: the frames that get a row. small: the height of the row on a small or boss frame.
local ROW = { sizes = { smaller = 0.85, larger = 1.2 }, height = 17, accent = 3, bright = 0.7, strong = 0.95, pad = 4, gap = 1, wordGap = 2, levelRoom = 20, flagRoom = 24, timerRoom = 24, small = 13,
	kinds = { player = true, target = true, focus = true, boss = true, pet = true, tot = true, party = true, partypet = true } }
-- Where the game keeps the font strings of a bar, on the bar and on its container.
local TEXT_KEYS = { "TextString", "HealthBarText", "ManaBarText", "CenterText", "LeftText", "RightText" }
-- The words on the bars of the pet frame are globals.
local PET_TEXTS = {
	health = { "PetFrameHealthBarText", "PetFrameHealthBarTextLeft", "PetFrameHealthBarTextRight" },
	power = { "PetFrameManaBarText", "PetFrameManaBarTextLeft", "PetFrameManaBarTextRight" },
}
-- The font the name row starts with, until it has the font of the game's name.
local ROW_FONT = "GameFontNormalSmall"
-- The line of /flatui status for a picture that could not be drawn.
-- The unit of a frame when the game does not say which.
local TOKENS = { player = "player", target = "target", focus = "focus", pet = "pet" }
-- Units from the top of the health slot (large frames) or of the name text (small frames) to the bottom of the power bar, for a frame whose
-- rectangles the client does not give (Mainline\PlayerFrame.xml:123-126 and 252-258, PetFrame.xml:73-78, 84-88 and 133-137,
-- TargetFrame.xml:439-451 and 486-489, PartyFrameTemplates.xml:9-51, 118-121 and 241-244).
local SPAN = { player = 31, target = 31, focus = 31, pet = 30, tot = 30, party = 31, partypet = 22 }
-- The PvP flag. half: half the height of the round plate in its own units, for a client that does not give its size. home: where the XML anchors
-- the plate in its frame, the point of the plate, the point of the frame and the offsets (Mainline\PlayerFrame.xml:91-93, TargetFrame.xml:259-262).
-- corner: the point of the picture the plate is centred on at each choice of the Icon corner setting, and the signs of its offsets, which keep it inside.
local FLAG = { half = 13,
	home = { player = { "TOP", "TOPLEFT", 20, -50 }, target = { "TOP", "TOPRIGHT", -23, -50 }, focus = { "TOP", "TOPRIGHT", -23, -50 } },
	corner = { tl = { "TOPLEFT", 1, -1 }, tr = { "TOPRIGHT", -1, -1 }, bl = { "BOTTOMLEFT", 1, 1 }, br = { "BOTTOMRIGHT", -1, 1 } } }
-- /flatui status. names: how it calls the frames it reports on. none: what a frame with no unit says in place of its lines. The functions that write
-- the lines of a frame are fields of this table.
local STATUS = { names = { player = "Player", target = "Target", pet = "Pet", tot = "Target of target", boss = "Boss 1", party = "Party 1" },
	none = { target = "no target", pet = "no pet", tot = "no unit", boss = "no unit" },
	notDrawn = "Unit frames: a portrait could not be drawn on one frame, which keeps the game's portrait.",
	-- The number of frames whose picture could not be drawn.
	undrawn = 0 }

-- Per frame: { kind, frame, parts, made, refused, queued, bars, byRole, unmasked, pic, row, glowAtlas, radius, bands, rank }
local records = setmetatable({}, { __mode = "k" })
-- The threat glow, the power bar and the health bar of a party pet, to find its record from a hook on a global function.
local byFlash = setmetatable({}, { __mode = "k" })
local byPower = setmetatable({}, { __mode = "k" })
local byHealth = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
-- Per totem button: { outline, border, icon, mask, unmasked }. Per aura icon: { outline, icon, border, stealable, on }.
local totems = setmetatable({}, { __mode = "k" })
local auras = setmetatable({}, { __mode = "k" })
-- The aura icon of each border the game colours by debuff type, and the icons that wait for the end of combat.
local byBorder = setmetatable({}, { __mode = "k" })
local waiting = setmetatable({}, { __mode = "k" })

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The height of the name row of a frame: the large height on the player, target and focus frames, else the small one.
function ROW.of(rec)
	return (LARGE[rec.kind] and ROW.height) or ROW.small
end

-- Where the level shows: "end" of the name row, "before" the name, "portrait" or "hidden".
-- A frame with no picture has nothing to put a level on, so "portrait" shows the level at the end there.
function ROW.at(rec)
	local at = Opt("levelPosition")
	if at == "portrait" and rec ~= nil and rec.pic == nil then
		return "end"
	end
	return at
end

-- The frames that have a picture row, a level row and a health colour row of their own on their page.
ns.UnitFrameExtra.per = { picture = { player = true, target = true, focus = true, pet = true, tot = true, party = true, partypet = true },
	level = { player = true, target = true, focus = true, boss = true },
	health = { player = true, target = true, focus = true, pet = true, tot = true, party = true, boss = true } }

-- The style of the picture of a frame, whether it has no picture, and whether it shows the game's portrait: the row of the frame over what Square
-- portraits and Portrait style say. Auto is what those two say. Square picture, 3D head and Class icon draw the picture even where its switch is off.
function ns.UnitFrameExtra.pictureMode(rec)
	local style = Opt("portraitStyle")
	local switch = ns.UnitFrameExtra.switches[rec.kind]
	local none = style == "none" or (switch ~= nil and Opt(switch) == false)
	local pick = ns.UnitFrameExtra.per.picture[rec.kind] and Opt(rec.kind .. "Picture") or "auto"
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

-- Whether the level of a frame shows: its row, or True for a frame that has none.
function ns.UnitFrameExtra.levelWanted(rec)
	return not ns.UnitFrameExtra.per.level[rec.kind] or Opt(rec.kind .. "Level") ~= false
end

-- What the health bar of a frame is coloured by, class or reaction, or nil for the Health colour.
function ns.UnitFrameExtra.healthBy(rec)
	local by = ns.UnitFrameExtra.per.health[rec.kind] and Opt(rec.kind .. "HealthBy") or nil
	return (by == "class" or by == "reaction") and by or nil
end

-- The image file for the fill of a bar of a role, health or power: the texture of its row, false for a solid fill, or nil while the row follows the
-- Flat UI page and the soft shade look.
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

-- True when the fill of a bar of a role is an image file and not a solid colour.
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

-- A text the client has not withheld and that says something.
local function Plain(text)
	return not ns.IsSecret(text) and type(text) == "string" and text ~= ""
end

-- The frame or region at the end of a chain of keys, or nil when a link is missing or withheld.
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

-- The values that are not nil.
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

-- Where each frame keeps its parts. owner: what the picture of the portrait is made on. art: the frame
-- art, whose alpha the game never sets. flash: the threat glow. status: the glow the game colours for resting
-- and combat, or for an attacking pet. rest: the resting animation of the player. boss: the dragon around the portrait of an elite
-- or rare target. debuff: the glow the game colours for the top debuff of a party member. level, pvp and
-- strip: the round level plate, the round PvP plate and the strip behind the name, drawn on the frame badges; nameText and levelText:
-- the name and the level number, drawn there too; high: the skull that stands in for a level the game cannot tell. pvp is the round plate of the
-- PvP flag, pvpIcon the faction or free-for-all art on it, pvpTimer the timer text of the player's flag, and pvpHome the frame the XML anchors the
-- plate to. content: the frames the game draws its content on, which the name row is above. healthBox: the slot of a health bar that is larger
-- than its slot, cutHealth: the fill is cut to that slot. textBox: the container that holds the words of the health bar. select: the target outline of a raid frame. loss: the bar that
-- fills red behind the health bar for the health just lost. clip: the side on which the power bar is wider than the health bar, under
-- the portrait. side: the side of the bars the picture is on. standard: the layout the picture keeps when the bars move.
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
		-- The game sizes the slot of the health bar for a minus target and leaves the bar as it is: the slot is outlined, and the fill is cut to it.
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
		-- The target frame without its portrait. The game sizes the slot of the health bar and not the bar itself, so the
		-- health fill keeps its mask.
		local container = Path(frame, "TargetFrameContainer")
		local main = Path(frame, "TargetFrameContent", "TargetFrameContentMain")
		local box, power = Path(main, "HealthBarsContainer"), Path(main, "ManaBar")
		return {
			owner = container, art = List(Path(container, "FrameTexture")), flash = Path(container, "Flash"),
			content = List(container, Path(frame, "TargetFrameContent"), main),
			health = Path(box, "HealthBar"), healthBox = box, power = power, powerMask = Path(power, "ManaBarMask"),
			badges = main, level = Path(main, "LevelBackgroundCircle"), levelText = Path(main, "LevelText"), strip = Path(main, "ReputationColor"),
			nameText = Path(main, "Name"), high = Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "HighLevelTexture"),
		}
	elseif kind == "pet" then
		-- The pet frame names its regions and bars as globals.
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
		-- The border is the background showing through the gap around the health bar. The highlights say target and threat.
		return {
			owner = frame, art = List(Path(frame, "background"), Path(frame, "selectionHighlight"), Path(frame, "aggroHighlight")),
			select = Path(frame, "selectionHighlight"), flash = Path(frame, "aggroHighlight"), health = Path(frame, "healthBar"), power = Path(frame, "powerBar"),
		}
	end
	-- Target of target.
	return {
		owner = frame, portrait = Path(frame, "Portrait"), portraitMask = Path(frame, "PortraitMask"), art = List(Path(frame, "FrameTexture")), clip = "left", side = "left", nameText = Path(frame, "Name"),
		health = Path(frame, "HealthBar"), healthMask = Path(frame, "HealthBar", "HealthBarMask"),
		power = Path(frame, "ManaBar"), powerMask = Path(frame, "ManaBar", "ManaBarMask"),
	}
end

-- The record of a frame, made the first time its health bar is found.
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

-- A kind of frame that stopped on errors counts as off.
local function Active(rec)
	return ns.Enabled(KEY) and Opt(rec.kind) == true and not ns.PartStopped(KEY, LABELS[rec.kind])
end

-- Runs the work of one part. A part that stopped on errors runs only to give back what it had styled, and the failure that
-- stops it has every part look again for that. A part stops only after three frames fail, so every failure goes on the
-- status as well.
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

-- State read from the game's art ------------------------------------------------------------------------------

local function IsLit(region)
	local ok, shown = pcall(region.IsShown, region)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- The colour of a glow the game is showing, or nil while it is hidden.
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

-- The game sets the alpha of the player's status glow and the colour of the pet's attack glow every frame while they are
-- shown, so neither can be hidden by its alpha. While the frame shows the square picture, the glow has no texture, and its atlas
-- goes back when it does not. The game draws the atlas of the player's glow again with each swap of the frame art, and the
-- atlas that is kept is the one it drew last.
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

-- Corners ------------------------------------------------------------------------------------------------------

-- What a call on a region answers, or nil when it raises or the client withholds the first answer.
local function Ask(region, method, ...)
	local ok, a, b, c, d = pcall(function(...)
		return region[method](region, ...)
	end, ...)
	if ok and not ns.IsSecret(a) then
		return a, b, c, d
	end
	return nil
end

-- Set when the client lacks or refuses the calls that slice a texture: the corners stay square.
local noSlice = false
-- Per texture that has margins set.
local sliced = setmetatable({}, { __mode = "k" })
-- Per outline with rounded corners: { line, mask, radius, masked, t }
local rims = setmetatable({}, { __mode = "k" })

-- The corner radius in units, or nil for square corners.
local function Radius()
	return not noSlice and ROUND[Opt("corners")] or nil
end

-- Keeps the corners of a texture at their size and stretches only the middle. False when the client lacks either call or refuses it.
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

-- Draws a rounded rectangle of the radius on a texture, or its line, or the crisp square for a radius of nil. A mask clamps to black.
local function Shape(texture, radius, line, mask)
	local file = CORNERS[radius or 0][line and "line" or "fill"]
	local wrap = mask and "CLAMPTOBLACKADDITIVE" or nil
	return pcall(texture.SetTexture, texture, file, wrap, wrap) and Slice(texture)
end

-- Takes the margins off a texture that has them, before it is given a solid colour again.
local function Unslice(texture)
	if sliced[texture] then
		sliced[texture] = nil
		if type(texture.ClearTextureSlice) == "function" then
			pcall(texture.ClearTextureSlice, texture)
		end
	end
end

-- Puts the rounded line of an outline in place of its straight edges, at the colour and in the state of the outline. The straight edges are
-- transparent while the corners are rounded and the line has its points, and the line is not drawn in the plain colour while the border is off.
local function Rim(outline)
	local rim = rims[outline]
	if rim == nil then
		return
	end
	local radius = rim.radius
	-- A round outline is a ring, so the rounded line is not drawn while it is round.
	local shown = radius ~= nil and not outline.roundOn and outline.shown and not (ns.Get("general.borderless") == true and outline.r == nil)
	rim.line:SetShown(shown)
	if shown then
		local r, g, b = outline.r, outline.g, outline.b
		if r == nil then
			r, g, b = ns.BorderRGB()
		end
		rim.line:SetVertexColor(r, g, b, 1)
		local t = outline.px or ns.Get("general.thickness")
		if not outline.pixels then
			t = ns.Pixels(outline.anchor, t)
		end
		if rim.t ~= t and InCombatLockdown() then
			-- The line is anchored after combat, and the straight edges stay until then.
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

-- Rounds the corners of an outline: a line of the radius around it, and a mask of the radius on its background. False when the client refuses.
local function Round(outline, radius)
	local rim = rims[outline]
	if rim == nil then
		rim = { line = outline.top:GetParent():CreateTexture(nil, "OVERLAY", nil, 7) }
		ns.Own[rim.line] = true
		-- A frame that draws over what the picture shows (a 3D head) takes the line.
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

-- The rounded line of an outline, or nil while its corners are square.
function ns.UnitFrameExtra.rimLine(outline)
	local rim = outline ~= nil and rims[outline]
	return rim and rim.line or nil
end

-- Gives an outline its straight edges and its square background again.
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

-- Shows or hides an outline, with or without its background, and its rounded line with it.
local function ShowOutline(outline, shown, backdropOn)
	ns.SetOutline(outline, shown, backdropOn)
	Rim(outline)
end

-- The colour of an outline for a state, or the general border colour for none.
local function ColourOutline(outline, r, g, b)
	ns.SetOutlineColour(outline, r, g, b)
	Rim(outline)
end

-- The pictures -------------------------------------------------------------------------------------------------

-- The unit a frame shows: its own when the game says which, else the usual one for its kind. Party members and their pets
-- are numbered by the game's layout.
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

-- The class icon the game put on its portrait in place of the face, or nil.
local function IconOf(portrait)
	local ok, atlas = pcall(portrait.GetAtlas, portrait)
	if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
		return atlas
	end
	return nil
end

-- The atlas of the class icon of a unit that is a player, or nil for any other unit and while the client withholds its class (UnitClass is withheld
-- when unit identity is restricted; UnitIsPlayer is not).
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

-- Draws what the game draws on its portrait into the picture: the face of the unit cut square, or the class icon whole. Portrait style Class icon
-- draws the class icon of a player and the face of any other unit. False when it could not be drawn.
local function Draw(rec)
	local texture = rec.pic.texture
	local unit = UnitOf(rec)
	local atlas, class = IconOf(rec.parts.portrait), nil
	if rec.pic.style == "icon" then
		class = ClassAtlas(unit)
		atlas = class or atlas
	end
	rec.pic.icon = atlas ~= nil
	-- Only a class icon of a player can be round; a face and the icon of the game stay square.
	rec.pic.class = class ~= nil or nil
	if atlas ~= nil then
		-- The atlas gives the box of the icon in its sheet; a coordinate set after it would show the whole sheet.
		return pcall(texture.SetTexCoord, texture, 0, 1, 0, 1) and pcall(texture.SetAtlas, texture, atlas, false, nil, true)
	end
	return unit ~= nil and type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, texture, unit, true)
		and pcall(texture.SetTexCoord, texture, CROP, 1 - CROP, CROP, 1 - CROP)
end

-- True while the frame shows its picture and not the portrait of the game.
local function Squared(rec, on)
	return on and Opt("squarePortrait") and rec.pic ~= nil and not rec.pic.failed
end

-- Says that the picture of a frame could not be drawn, or that it can be again.
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

-- The game tints the portrait of a unit that is dead, a ghost, low on health or tapped, and desaturates it when the unit is
-- offline. The picture takes the same tint and the same desaturation.
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

-- True when the client says a frame has no width or no height, and a picture on it would draw nothing.
local function NoArea(frame)
	local width, height = Ask(frame, "GetWidth"), Ask(frame, "GetHeight")
	return (Number(width) and width <= 0) or (Number(height) and height <= 0)
end

-- Takes a mask off a texture, or puts it back. rec.unmasked says whether the mask is off now.
local function Unmask(rec, key, texture, mask, off)
	if texture == nil or mask == nil or (rec.unmasked[key] or false) == off then
		return
	end
	local method = off and texture.RemoveMaskTexture or texture.AddMaskTexture
	if type(method) == "function" and pcall(method, texture, mask) then
		rec.unmasked[key] = off
	end
end

-- The game's portraits get a circle mask from its XML (client/ui/Interface/AddOns/Blizzard_UnitFrame/Mainline/PlayerFrame.xml:32-40,
-- TargetFrame.xml:67-70, 421-424, PetFrame.xml:30-33, PartyFrameTemplates.xml:19-22, 92-95). SetPortraitTexture masks the image itself unless
-- disableMasking is passed (Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:572-581), and the game passes it only for the player frame
-- (UnitFrame.lua:195, PlayerFrame.xml:19), so on the other frames the image is round without the mask too. This is a guard: it takes the mask
-- off the portrait of the game while the picture shows, once, and nothing in Blizzard_UnitFrame calls AddMaskTexture to put it back. The cause of
-- round corners on a portrait that shows through is not seen in the source. The mask goes back on when the game's portrait is the one shown.
-- `Mask.inPass` is true while a hook of the game runs: a write waits for the next frame then, and only a read is done in the hook.
local Mask = { inPass = false }

-- True when the mask is on the texture, false when it is not, nil when the client does not say.
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

-- Takes the mask off the portrait of the game once, and again only when the game has put it back. off: the picture shows.
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

-- Draws the picture, and the portrait of the game is hidden while it shows: the game writes its alpha, and a hidden region keeps
-- the place its marks are anchored to. A picture that is shown is drawn again only when asked: the game draws its portrait once
-- for each new unit. A portrait the addon cannot draw stays as it is, and so does a portrait whose picture has no size.
local function ApplyPicture(rec, on, redraw)
	local pic = rec.pic
	if pic == nil then
		return
	end
	local square = on and Opt("squarePortrait") and true or false
	-- No picture at all: the style None, or the switch of this kind of frame is off. The game's portrait stays hidden and the space stays empty.
	local style, none, game = ns.UnitFrameExtra.pictureMode(rec)
	none, game = square and none, square and game
	if pic.style ~= style then
		pic.style, redraw = style, true
	end
	local sized = pic.side ~= nil and not NoArea(pic.frame)
	local drawn = square and not none and not game
	local shown = drawn and sized and ((pic.drawn and not redraw) or Draw(rec) == true)
	-- The game's portrait shown in place of the picture counts as no picture for what is drawn on the picture.
	pic.none = (none or game) or nil
	pic.game = game or nil
	pic.noSize = drawn and not sized
	pic.drawn = shown
	Undrawn(rec, drawn and not shown)
	ns.SetHidden(rec.parts.portrait, shown or none)
	Mask.sync(rec, shown or none or false)
	local round = shown and pic.class and Opt("classShape") == "round" or false
	ns.SetOutlineRound(pic.outline, pic.texture, round, pic.fadeTex)
	if round and not pic.outline.round and not ns.roundMissing and InCombatLockdown() and not pic.roundQueued then
		-- The first round picture is made after combat, and the rounded line is drawn again then.
		pic.roundQueued = true
		ns.OutOfCombat(function()
			pic.roundQueued = nil
			pcall(Refresh)
		end)
	end
	ShowOutline(pic.outline, shown, true)
	pic.texture:SetShown(shown)
	if shown then
		Tint(rec)
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.picture) do
		Run(hook.part, hook.fn, rec, on, shown)
	end
end

-- Borders -----------------------------------------------------------------------------------------------------

-- False when the game refused to anchor a region or a frame, which raises no error.
local function Placed(region)
	local ok, points = pcall(region.GetNumPoints, region)
	return not ok or ns.IsSecret(points) or type(points) ~= "number" or points > 0
end

-- A frame of the addon's own on a frame of the game, in the level given or the one above its parent.
local function Frame(parent, level)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	if level ~= nil then
		frame:SetFrameLevel(level)
	end
	return frame
end

-- A hidden texture of the addon's own on a frame, on all its points unless it is placed after.
local function Layer(frame, layer, sublevel, partial)
	local texture = frame:CreateTexture(nil, layer, nil, sublevel)
	ns.Own[texture] = true
	if not partial then
		texture:SetAllPoints(frame)
	end
	texture:Hide()
	return texture
end

-- The picture of a portrait: a frame beside the bars, on the frame the portrait is on, in its level. The level number, the marks
-- and the icons are on frames above that level, so they are drawn over the picture. The border of an elite or rare picture is a
-- second one, thicker, so that no border is laid out when the target changes in combat. The line inside a Rare Elite's is a third, one
-- pixel thick, around a frame inside the picture that Layout places, and drawn on the frame of the picture so that it is over its texture.
-- Every outline made is added to `made` as it is made.
local function Picture(parts, made)
	local level = parts.owner:GetFrameLevel()
	level = Number(level) and level or nil
	local frame = Frame(parts.owner, level)
	local pic = { frame = frame, texture = Layer(frame, "ARTWORK", 0) }
	-- The texture that fades the top of the picture into the background: on the picture frame, above the picture, below its edges and inner line and below the marks of the game.
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

-- The level of the name row: above the frames the game draws its content on, so that the row covers what the game draws in that row.
local function RowLevel(parts)
	local top
	for _, frame in ipairs(parts.content or {}) do
		local ok, level = pcall(frame.GetFrameLevel, frame)
		if ok and Number(level) and (top == nil or level > top) then
			top = level
		end
	end
	return top and top + 1 or nil
end

-- The name row: a frame of the addon's own over the name art of the game, with the name and the level as text of its own, a mark after
-- the level, a word of the kind, a word for the PvP flag, and a line along its bottom edge. Layout anchors them for the level position. At the end
-- of the row, from the outer end inward they are the mark, the level, the word of the kind, the PvP word and the name. On a target or focus the
-- mark is a constant text of the addon's own, and the level and the word of the kind hang from it; the PvP word and the name hang from the word of
-- the kind. A unit with no kind leaves both empty, so the texts inside them move out to the edge without anything being anchored again. The level
-- of the player is anchored to the row. Before the name, the level is at the left end, the mark hangs from it and the name from the mark.
local function NameRow(rec)
	local frame = Frame(rec.frame, RowLevel(rec.parts))
	local row = { frame = frame, base = Layer(frame, "BACKGROUND", -8), grad = Layer(frame, "BACKGROUND", 0), fill = Layer(frame, "BACKGROUND", 0),
		mark = Layer(frame, "ARTWORK", 0, true), line = Layer(frame, "ARTWORK", 1, true) }
	row.mark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	row.mark:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	row.mark:SetWidth(ROW.accent)
	row.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	row.line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	-- Snapping moves a thin line by a pixel as its frame moves, as it would an edge of an outline.
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
	-- Layout places the texts, for the level position.
	row.kindMark:SetJustifyH("RIGHT")
	row.level:SetJustifyH("RIGHT")
	row.kindWord:SetJustifyH("RIGHT")
	row.flag:SetJustifyH("RIGHT")
	row.flag:SetTextColor(1, 1, 1, 1)
	row.flag:Hide()
	row.name:SetJustifyH("LEFT")
	return row
end

-- The row shows nothing. Its frame stays shown, and its layers and text are shown and hidden, which is allowed in combat.
local function HideRow(row)
	row.paint = nil
	for _, region in ipairs({ row.base, row.grad, row.fill, row.mark, row.line, row.name, row.level, row.kindMark, row.kindWord, row.flag }) do
		region:Hide()
	end
end

-- True while the frame has a name row: the page, the frame, Name row and Square portraits are on, and on a small frame other than a boss frame
-- Name row on small frames too.
local function RowOn(rec)
	if rec.row == nil or not Active(rec) or Opt("strip") ~= true or Opt("squarePortrait") ~= true then
		return false
	end
	return LARGE[rec.kind] or rec.kind == "boss" or Opt("smallRow") == true
end

-- The left, bottom, width and height of a region, or nil when the client withholds or does not say them.
local function RectOf(region)
	local ok, left, bottom, width, height = pcall(region.GetRect, region)
	if ok and Number(left) and Number(bottom) and Number(width) and Number(height) then
		return left, bottom, width, height
	end
	return nil
end

-- The distance from the top of one region of the game to the bottom of another, in the units of a third, or nil when the client gives no rectangle for
-- either. The three scales are used only when the client gives all of them.
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

-- The side of the picture, which is a square beside the bars: from the top of the name row, of the name text or of the health bar to the bottom of
-- the power bar. The rectangles of the game's bars give it, and when the client gives none the numbers of SPAN do; the second answer says which. A
-- target keeps the size the standard layout gives it, so that it does not change when a minus mob moves its bars.
local function SideOf(rec, t, rowOn, tall)
	local parts = rec.parts
	if parts.standard ~= nil then
		return parts.standard.top + (tall and ROW.of(rec) or 0) - parts.standard.bottom, true
	end
	local slot = parts.healthBox or parts.health
	local named = not rowOn and parts.nameText ~= nil and not LARGE[rec.kind]
	local power = rec.byRole.power
	local span = Span(named and parts.nameText or slot, power and power.bar or slot, rec.pic.frame)
	local side = (span or SPAN[rec.kind]) + (tall and ROW.of(rec) or 0) - (named and t or 0)
	if side <= 1 then
		return SPAN[rec.kind], false
	end
	return side, span ~= nil
end

-- One point of the picture, on a region of the game: its top left from the portrait frame for a target, else its top right from the left end of the
-- name row, of the name text or of the health bar. Its border and the border of the bars are one border thickness apart.
local function AnchorPicture(rec, t, rowOn, tall)
	local parts, frame = rec.parts, rec.pic.frame
	if parts.standard ~= nil then
		frame:SetPoint("TOPLEFT", parts.owner, "LEFT", parts.standard.x + 3 * t, parts.standard.top + (tall and ROW.of(rec) or 0))
		return
	end
	local named = not rowOn and parts.nameText ~= nil and not LARGE[rec.kind]
	frame:SetPoint("TOPRIGHT", named and parts.nameText or parts.healthBox or parts.health, "TOPLEFT", -3 * t, tall and ROW.of(rec) or (named and -t or 0))
end

-- The size of the picture is set from numbers and never read back, since a frame has no width until the client has laid it out.
local function SizePicture(rec, t, rowOn, tall)
	local pic = rec.pic
	local side, measured = SideOf(rec, t, rowOn, tall)
	if pic.side == nil or math.abs(pic.side - side) > 0.01 or NoArea(pic.frame) then
		pic.frame:SetSize(side, side)
		pic.side = side
	end
	pic.measured = measured
end

-- The units kept free in the name row from the settings and the frame: for the level, and for the PvP word and the time beside it. The mark and
-- the word of a kind keep none, since the texts inside them hang from them.
local function Rooms(rec, rowOn)
	local flag = Opt("pvpFlag")
	local pvp = rowOn and (flag == "word" or flag == "both") and LARGE[rec.kind] and rec.parts.pvpIcon ~= nil
	local shows = (LARGE[rec.kind] or rec.kind == "boss") and ns.UnitFrameExtra.levelWanted(rec)
	return shows and ROW.at(rec) == "end" and ROW.levelRoom or 0, (pvp and ROW.flagRoom or 0) + (pvp and rec.kind == "player" and Opt("pvpTimer") == true and ROW.timerRoom or 0)
end

-- What decides the anchors of the row and the picture. They are set again only when it changes.
local function LayoutKey(rec)
	local rowOn = RowOn(rec)
	local level, pvp = Rooms(rec, rowOn)
	return table.concat({ tostring(ns.Pixels(rec.frame, ns.Get("general.thickness"))), tostring(rowOn), level, pvp, tostring(Opt("smallTextSize")), tostring(Opt("portraitSize")), tostring(ROW.at(rec)), tostring(Opt("powerWidth")), tostring(Opt("nameRoom")), tostring(Opt("powerSpace")) }, ":")
end

-- Lays out what hangs from the bars: the name row above the health bar, as wide as the border of the bar, and the picture. The anchors are set again
-- only when the border thickness, the name row, the room for the texts or the text size has changed; the size of the picture is worked out each time.
-- At the end of the row, on a target or focus the word of the kind stands the room of the level inside the mark, and the PvP word and the name
-- stand inside the word; on the player they stand that far from the edge. In the other positions no room is kept for the level at the right.
-- rec.pvpRoom says whether the PvP word has its room in the row as laid out. With Name room on Only what the texts need the rooms are not
-- widths: the PvP word hangs from the level, and the name from the PvP word, so each is as wide as its text and the name gets the rest.
local function Layout(rec)
	for _, hook in ipairs(ns.UnitFrameExtra.before.layout) do
		Run(hook.part, hook.fn, rec)
	end
	local row, pic = rec.row, rec.pic
	local t = ns.Pixels(rec.frame, ns.Get("general.thickness"))
	local rowOn = RowOn(rec)
	-- The picture includes the height of the name row unless Portrait size says as tall as the bars.
	local tall = rowOn and Opt("portraitSize") ~= "bars"
	rec.tall = tall
	local level, pvp = Rooms(rec, rowOn)
	local fit = Opt("nameRoom") ~= "fixed"
	local key = LayoutKey(rec)
	local again = rec.laid ~= key
	rec.laid = key
	rec.pvpRoom = pvp > 0
	local power = rec.byRole and rec.byRole.power
	if again and power ~= nil and power.cut ~= nil and power.cut.place ~= nil then
		power.cut.place(Opt("powerWidth") == "game" and "game" or "same")
	end
	if again and row ~= nil then
		local slot = rec.parts.healthBox or rec.parts.health
		row.frame:SetPoint("BOTTOMLEFT", slot, "TOPLEFT", -t, t)
		row.frame:SetPoint("BOTTOMRIGHT", slot, "TOPRIGHT", t, t)
		row.frame:SetHeight(ROW.of(rec))
		row.line:SetHeight(t)
		-- Each text is placed again from nothing, so that a change of the level position leaves no old anchor.
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
				-- An empty word takes no room, so the PvP word hangs from the level as it does on the player.
				row.hangWord = function()
					row.kindWord:ClearAllPoints()
					row.kindWord:SetPoint("RIGHT", row.level, "LEFT", row.wordOn and -ROW.wordGap or 0, 0)
				end
				row.hangWord()
			elseif at == "end" then
				row.kindWord:SetPoint("RIGHT", row.kindMark, "LEFT", ROW.wordGap - ROW.gap - level, 0)
			else
				-- As far from the edge as it is at the end with no room kept for the level, so the name ends where the player's does.
				row.kindWord:SetPoint("RIGHT", row.frame, "RIGHT", ROW.wordGap - ROW.pad, 0)
			end
			row.flag:SetPoint("RIGHT", row.kindWord, "LEFT", -ROW.wordGap, 0)
			if fit and pvp > 0 then
				row.name:SetPoint("RIGHT", row.flag, "LEFT", -ROW.wordGap, 0)
			else
				row.name:SetPoint("RIGHT", row.kindWord, "LEFT", -ROW.wordGap - pvp, 0)
			end
		elseif fit then
			-- The level is the edge when it has a room in the row, and the row is the edge when it has none.
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
			AnchorPicture(rec, t, rowOn, tall)
			if pic.innerFrame ~= nil then
				-- The line inside a Rare Elite's border is the outermost pixel of the picture.
				local inset = ns.Pixels(rec.frame, INNER_PX)
				pic.innerFrame:SetPoint("TOPLEFT", pic.frame, "TOPLEFT", inset, -inset)
				pic.innerFrame:SetPoint("BOTTOMRIGHT", pic.frame, "BOTTOMRIGHT", -inset, inset)
			end
		end
		SizePicture(rec, t, rowOn, tall)
		pic.sized = true
		if pic.noSize and not NoArea(pic.frame) then
			-- The dragon, the resting glow and the colour of the border follow whether the portrait is shown.
			Run(LABELS[rec.kind], Apply, rec)
		end
		if not pic.measured and rec.retries < 3 and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			-- The client works out the rectangles of the bars once they are drawn.
			rec.retries = rec.retries + 1
			C_Timer.After(0, function()
				ns.OutOfCombat(function()
					Run(LABELS[rec.kind], Layout, rec)
				end)
			end)
		end
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.layout) do
		Run(hook.part, hook.fn, rec, t, rowOn)
	end
end

-- A mask of the addon's own that cuts the fill of a bar to a frame, with crisp edges.
local function CutMask(bar, frame)
	local mask = bar:CreateMaskTexture()
	ns.Own[mask] = true
	Shape(mask, nil, false, true)
	mask:SetAllPoints(frame)
	return mask
end

-- A power bar wider than the health bar runs under the portrait, where the frame art of the game hid it. Its visible part is as wide as
-- the health bar: the border and the background are drawn around a frame that spans that part, and a mask of the addon's own cuts the fill
-- to it. A corner takes both its sides from one frame, so the corner that has the edge of the health bar and the other edge of the power bar
-- is taken from a frame that spans from the one bar to the other.
-- Power bar width "same": both sides come from the health slot and the top and bottom from the power bar, whatever width the game gave the bar.
-- "game": one side comes from the game's power bar, the side the game made it wider on. Space between bars lowers the top in "same" and on the left-clipped frames.
local function PowerSpan(parts)
	local bar, slot = parts.power, parts.healthBox or parts.health
	local parent = parts.badges or parts.owner
	local across, side, frame = Frame(parent), Frame(parent), Frame(parent)
	local cut = { across = across, side = side, frame = frame, mask = CutMask(bar, frame), always = true }
	-- Anchors the three frames for a width mode. They are frames of the addon's own, so nothing protected is written.
	function cut.place(mode)
		-- Space between bars: the span starts below the slot by the two borders and the space. None leaves the bar's top as the top.
		local space = tonumber(Opt("powerSpace")) or 0
		local drop = space > 0 and ns.Pixels(bar, 2 * ns.Get("general.thickness") + space) or 0
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
	cut.place(Opt("powerWidth") == "game" and "game" or "same")
	return cut
end

-- Makes the borders of a frame, each added to `made` as it is made. False when the game refuses one.
local function Make(rec, made)
	local parts = rec.parts
	local placed = {}
	for _, role in ipairs({ "health", "power" }) do
		local bar = parts[role]
		-- A bar larger than its slot is outlined by the slot.
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
	Layout(rec)
	if rec.pic then
		placed[#placed + 1] = rec.pic.frame
	end
	if rec.row then
		placed[#placed + 1] = rec.row.frame
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

-- Makes the borders of a frame. When the game refuses one or the code raises, every border made is hidden and the frame keeps its art.
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

-- Fills ------------------------------------------------------------------------------------------------------

-- True when the slot of a bar is smaller than the bar, which the health slot of a minus target is: the fill is cut to the slot.
local function Smaller(entry)
	local slot, bar = entry.slot, entry.bar
	if slot == nil then
		return false
	end
	local ok, sw, sh = pcall(slot.GetSize, slot)
	local answered, bw, bh = pcall(bar.GetSize, bar)
	return ok and answered and Number(sw) and Number(sh) and Number(bw) and Number(bh) and (sw < bw - 0.5 or sh < bh - 0.5)
end

-- The mask of the addon's own that cuts a wide power bar to the width of the health bar, or a health bar to a smaller slot, or rounds a
-- fill, is on the fill while the frame is styled and one of those is so. A slot as large as its bar needs no mask.
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

-- The game draws power bars from an atlas and gives them no colour, so the colour of the power type is used.
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

-- Puts the fill of a bar in the state the options ask for. True while the fill is flat.
local function ApplyFill(rec, entry, on)
	local done = false
	if on and Opt("flat") then
		-- The game colours the health bar of a raid frame itself, by class or by state: the fill is white.
		local raid = rec.kind == "raid"
		local r, g, b = 1, 1, 1
		local file = ns.UnitFrameExtra.fillFile(entry.role)
		if not raid and entry.role == "health" then
			if ns.UnitFrameExtra.healthColour then
				r, g, b = ns.UnitFrameExtra.healthColour(rec, entry)
			else
				r, g, b = ns.Colour(KEY .. ".healthColour")
			end
			-- Colour health bars by health left: an image fill in white, which HealthColour.lua tints with the colour of the health left.
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
	-- The region that draws the fill is the same one for good. The mask of the game gives the fill the shape of the slot in the frame art.
	local fill = entry.fill or ns.FillRegion(entry.bar)
	entry.fill = fill
	Unmask(rec, entry.role, fill, entry.mask, done)
	Clip(entry, fill, on)
	return done
end

-- The words on a bar: the font strings the game keeps on the bar, on its container and as globals.
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

-- The size of the words on a bar, in percent of the size the game gives them: the setting for the kind of bar, and the game's own size
-- while the frame is not styled.
local function ApplyText(rec, entry, on)
	local percent = 100
	if on and LARGE[rec.kind] then
		percent = Opt(entry.role .. "TextSize")
	elseif on and rec.kind ~= "boss" and rec.kind ~= "raid" then
		percent = Opt("smallTextSize")
	end
	-- Smaller, lighter bar text: 85% of the size with no outline. No text on the power bar: the words are transparent, and opaque again when the
	-- look goes.
	local light = on and Opt("lookLightText") == true and rec.kind ~= "boss" and rec.kind ~= "raid"
	if light then
		percent = percent * 0.85
	end
	local hide = on and entry.role == "power" and Opt("lookNoPowerText") == true
	-- The font, outline and colour rows of UnitText.lua add to the call; with none set it is the call of the size alone.
	local spec = { percent = percent, flags = light and "" or nil }
	local styled = ns.UnitFrameExtra.barSpec ~= nil and ns.UnitFrameExtra.barSpec(rec, entry, on, spec)
	-- The text of UnitText.lua that takes the place of the game's words is set with the same call.
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

-- The name on a small frame is sized with its bar text: the pet, target of target, party and party pet frames. The game's size while the frame is
-- not styled. The name on a large frame is the game's text under the name row, and is left alone.
local function ApplyNameSize(rec, on)
	if rec.parts.nameText ~= nil and not LARGE[rec.kind] and rec.kind ~= "boss" then
		local spec = { percent = on and Opt("smallTextSize") or 100 }
		local styled = ns.UnitFrameExtra.nameSpec ~= nil and ns.UnitFrameExtra.nameSpec(rec, on, spec)
		if ns.TextStyle(rec.parts.nameText, spec) == false and styled then
			ns.UnitFrameExtra.refused(rec, "names", "name")
		end
	end
end

-- The health bar of a party pet does not lock its colour, so the game tints it green with each health update, and the tint
-- multiplies a flat fill. The tint is white under a solid fill and the health colour under an image, and the game's again when the fill
-- is not flat.
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

-- Colours ----------------------------------------------------------------------------------------------------

-- The red, green and blue of a colour, or nothing for none.
local function Rgb(colour)
	if colour then
		return colour[1], colour[2], colour[3]
	end
end

-- Threat, or the top debuff of a party member, on the health bar border, resting and combat or an attacking pet on the border of
-- the picture, the kind of a target or focus on both borders of the picture, the thicker one shown only then, and a Rare Elite's line inside
-- them. A raid frame that is the target shows it on the health bar border over threat.
local function Colour(rec, on)
	local parts = rec.parts
	local r, g, b
	if on and Opt("threat") and parts.flash ~= nil then
		r, g, b = Lit(parts.flash)
	end
	if r == nil and on and Opt("threat") and parts.debuff ~= nil then
		r, g, b = Lit(parts.debuff)
	end
	if on and parts.select ~= nil then
		local sr, sg, sb = Lit(parts.select)
		if sr ~= nil then
			r, g, b = sr, sg, sb
		end
	end
	if rec.byRole.health then
		ColourOutline(rec.byRole.health.outline, r, g, b)
	end
	local pic = rec.pic
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
		-- Whether a state, a kind or a look gave the picture's border a colour: the files after this one colour it by class or reaction only if not.
		pic.coloured = r ~= nil
		ColourOutline(pic.outline, r, g, b)
		ColourOutline(pic.rim, Rgb(look and look.colour))
		ShowOutline(pic.rim, look ~= nil, false)
		ColourOutline(pic.inner, Rgb(look and look.inner))
		ShowOutline(pic.inner, look ~= nil and look.inner ~= nil, false)
	end
	for _, hook in ipairs(ns.UnitFrameExtra.after.colour) do
		Run(hook.part, hook.fn, rec, on)
	end
end

-- The name row ---------------------------------------------------------------------------------------------------

-- The colour of the name row at part of its brightness: the class colour of the player, of the pet's owner, of a party member or a target of
-- target that is a player, the reaction colour of any other unit, or the colour the game gives the strip behind the name of a target or boss.
-- Nil while the strip is hidden or the client withholds the colour. rec.colourFrom says where the colour came from, for /flatui status.
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
	elseif kind == "tot" then
		local unit = UnitOf(rec)
		local ok, player = pcall(UnitIsPlayer, unit)
		if ok and not ns.IsSecret(player) and player == true then
			r, g, b = ns.ClassColourOf(unit)
			from = "class"
		elseif ok and not ns.IsSecret(player) and player == false then
			r, g, b = ns.ReactionColour(unit)
			from = "reaction"
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
	return r * bright, g * bright, b * bright
end

-- A solid colour on a texture of the row, the rounded rectangle tinted when the corners are rounded.
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

-- A vertical gradient of one colour on a texture, as strong as `bottom` at the bottom and as `top` at the top. False when the client lacks
-- CreateColor or SetGradient, or refuses them.
local function Gradient(texture, radius, r, g, b, bottom, top)
	if type(CreateColor) ~= "function" or type(texture.SetGradient) ~= "function" then
		return false
	end
	Solid(texture, radius, 1, 1, 1, 1)
	return pcall(function()
		texture:SetGradient("VERTICAL", CreateColor(r, g, b, bottom), CreateColor(r, g, b, top))
	end)
end

-- Paints the layers of the row: the colour fading upward, the colour whole, or the general background with a mark of the colour at the left
-- end. A row without a colour is the dark one, without the mark. The base is the opaque background of the player's row while the band
-- of the game may show through.
local function PaintRow(rec)
	local row = rec.row
	local r, g, b = RowColour(rec)
	local mode = r ~= nil and Opt("stripColour") or "dark"
	local top = ROW.strong * (100 - Opt("stripFade")) / 100
	local br, bg, bb = ns.Colour("general.backdrop")
	local alpha = ns.Get("general.backdropAlpha") / 100
	local key = table.concat({ mode, tostring(r), tostring(g), tostring(b), tostring(row.radius), top, br, bg, bb, alpha, tostring(rec.opaque) }, ":")
	if row.paint == key then
		return
	end
	row.paint = key
	local gradient = mode == "gradient" and Gradient(row.grad, row.radius, r, g, b, ROW.strong, top) == true
	if mode == "gradient" and not gradient then
		mode = "flat"
	end
	row.grad:SetShown(gradient)
	row.fill:SetShown(not gradient)
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

-- Copies the text of one of the game's font strings to one of the addon's, without looking at it: a text the client withholds is passed straight on.
-- False when the copy fails or the game's text is missing or empty.
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

-- The name of a unit as the game writes it on a frame: the first name and the surname joined as the game joins them, or the first name alone when
-- the game shows the player's first name only (Camelot\NameUtil.lua:4-12, Mainline\UnitFrame.lua:153-167). Nil when the client withholds the name.
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

-- The PvP word is white or red, or takes the colour the name has now. It runs after the text hooks, which recolour the name (Name colour).
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
	-- The fourth number of SetTextColor is the opacity of the word, which FlagWord sets, so it is passed on as it is and a withheld one waits for FlagWord.
	row.flagColour = { wr, wg, wb }
	local fine, alpha = pcall(row.flag.GetAlpha, row.flag)
	if fine and Number(alpha) then
		row.flag:SetTextColor(wr, wg, wb, alpha)
	end
end

-- The name row has the font of the game's name text, and the name has its colour. The opacity of the game's text is not copied: the game's text is
-- transparent under the row.
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
			-- The level and the mark after it take Level size of the name's size.
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

-- Elite, rare and boss -------------------------------------------------------------------------------------------

-- What the unit of a target or focus frame is: "elite", "rare", "rareelite" or "boss", and nil for any other unit and when the client
-- withholds what it is.
local function ReadRank(rec)
	rec.rank = RANKED[rec.kind] and ns.UnitKind(UnitOf(rec)) or nil
end

-- A text of the name row with its words and colour, or empty and hidden. An empty mark takes no room, which the level hanging from it counts on.
local function Tag(text, word, colour)
	text:SetText(word or "")
	if word then
		text:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
	text:SetShown(word ~= nil)
end

-- The mark after the level, the word of the kind and the line under the row, in the colour of the kind of the unit. They show with the
-- row, and the mark with the level it follows. Only text, colour and visibility change, which is allowed in combat. A part that stopped
-- on errors shows none of them.
local function Kind(rec)
	local row = rec.row
	if row == nil then
		return
	end
	local look = not ns.PartStopped(KEY, KIND_PART) and RowOn(rec) and rec.rank and RANKS[rec.rank] or nil
	if look == nil then
		-- Hidden before any call that can fail, so that a text the client refuses to empty does not leave the word or the line shown.
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

-- The name and the level as the game has them. The name is the unit's name, else the game's name text, else the name the client withholds passed
-- straight on; row.source says which. The level is the game's level text and the colour of that, or "??" for the skull. A copy that fails is the
-- client's own answer for the unit.
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
			-- A boss slot has no unit for a moment as an encounter engages new ones: its row keeps the name it had.
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
		-- The game shows the skull for a level it cannot tell, and the row says so in the colour the game gives such a level.
		shown = true
		local colour = type(QuestDifficultyColors) == "table" and not ns.IsSecret(QuestDifficultyColors) and QuestDifficultyColors.impossible
		local r, g, b = COLOUR.level[1], COLOUR.level[2], COLOUR.level[3]
		if type(colour) == "table" and not ns.IsSecret(colour) and Number(colour.r) and Number(colour.g) and Number(colour.b) then
			r, g, b = colour.r, colour.g, colour.b
		end
		row.level:SetText("??")
		level = { r, g, b }
	end
	-- The colour of the level number comes from here: the game's, white, or the name's.
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
		-- A hidden level takes no room from a name that hangs from it.
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

-- The game's name band on the player is a texture the source does not name, so it is found on the frame: a shown texture of the game
-- that is not one of the parts the module knows, with its middle in the name row, at most 30 units high and at least half as wide
-- as the row. A region whose rectangle the client withholds is left alone.

-- Calls fn with each region of a frame and of the frames under it, skipping what addon code may not touch and what the addon made.
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

-- What the status says a band is: its atlas, its image file, or no name.
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

-- The parts of a frame the module knows, which are not a name band.
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

-- Looks for the name band of the player out of combat, and keeps what it finds with the alpha it had.
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

-- The bands found are transparent while the row shows and have the alpha they had otherwise, and the status names them while they are hidden.
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

-- The name row shows its colour, the name and the level, and the name art of the game is transparent under it: its name text, the strip
-- behind the name of a target, and the level number, the round plate and the skull, in every level position. What the row does not show
-- is as the game draws it.
local function ApplyRow(rec)
	local parts, row = rec.parts, rec.row
	if row == nil then
		return
	end
	local shown = RowOn(rec)
	if shown and rec.kind == "player" and not InCombatLockdown() then
		Sweep(rec)
	end
	rec.opaque = rec.kind == "player" and shown and (not rec.swept or next(rec.bands) == nil)
	ns.SetFaded(parts.nameText, shown)
	ns.SetFaded(parts.strip, shown)
	-- The game's level number, round plate and skull stay hidden in every level position while the row is on.
	local noLevel = rec.made and Active(rec) and not ns.UnitFrameExtra.levelWanted(rec)
	ns.SetFaded(parts.levelText, shown or noLevel)
	ns.SetFaded(parts.level, shown or noLevel)
	ns.SetFaded(parts.high, shown or noLevel)
	Bands(rec, shown)
	if shown then
		PaintRow(rec)
		RowText(rec)
		-- The game's text is transparent under the row, and a name or a level of the row is never.
		pcall(row.name.SetAlpha, row.name, 1)
		pcall(row.level.SetAlpha, row.level, 1)
		row.name:SetShown(not rec.nameHidden)
	else
		row.source = nil
		HideRow(row)
	end
end

-- How the PvP flag of a frame is shown: "icon" has the game's plate and icon on a corner of the picture, "word" has a word in the name row and the
-- game's plate, icon and timer transparent, "both" has the plate and the icon on the picture and the word in the name row, "off" has them all
-- transparent, and "game" leaves them as the game draws them, which is so while the frame shows the portrait of the game. A word needs the name
-- row, and a frame without it shows the icon. Nil for a frame with no flag.
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

-- Moves the round plate of the PvP flag and its icon to a corner of the picture, or back to the places the XML gives them. The plate and the icon
-- are the two regions of the game this module anchors: the icon is anchored to the plate in the XML, and on the target the live client has been seen
-- to keep it at the game's place, so the icon gets its own point on the plate. The timer of the player is anchored to the plate and follows. The game
-- goes on showing, hiding and skinning all three. They sit on protected frames, so they move out of combat. A move the game refuses, which raises
-- nothing, puts both back where the XML has them and says so on the status.
local ApplyFlag
local function PlacePlate(rec, corner)
	local parts, plate = rec.parts, rec.parts.pvp
	if plate == nil or (rec.plateAt or false) == (corner or false) then
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
		local home = FLAG.home[rec.kind]
		if ok and Plain(point) and Plain(relativePoint) and type(relative) == "table" and not ns.IsSecret(relative) and Number(x) and Number(y) then
			rec.plateHome = { point, relative, relativePoint, x, y }
		else
			rec.plateHome = { home[1], parts.pvpHome, home[2], home[3], home[4] }
		end
	end
	local icon = parts.pvpIcon
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
			plate:SetPoint("CENTER", rec.pic.frame, at[1], at[2] * halfWidth, at[3] * halfHeight)
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
		rec.plateAt = corner or false
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

-- The word in the name row: PvP, or FFA for a free-for-all unit, and the time left on the player's own flag after it. It is as visible as the
-- game's icon is shown, which the client may withhold: the alpha is then set from the withheld answer, and nothing is compared.
local function FlagWord(rec, on)
	local row, parts = rec.row, rec.parts
	if row == nil then
		return
	end
	-- A word chosen in combat waits for its room, which is laid out when combat ends.
	if not on or not LARGE[rec.kind] or parts.pvpIcon == nil or not rec.pvpRoom then
		row.flag:Hide()
		row.flagState = nil
		-- A word that is not shown has no text, so with Name room on Only what the texts need it takes no room.
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
	-- With Name room on Only what the texts need an unflagged unit has no word, so the name has the room. A withheld state keeps the word at
	-- alpha 0 or 1 from that state, and keeps its room.
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

-- Puts the PvP flag of a frame in the state the options ask for. With both, the time left on the player's flag is in the word, and the game's
-- timer text beside the plate is transparent.
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

-- The bar the game fills red behind the health bar and shrinks to the new health after damage. Its fill is in the same
-- frame level, draw layer and sublevel as the health fill, and a flat health fill does not cover it: it shows red over
-- the whole bar. It is transparent.
local function ApplyLoss(rec, on)
	ns.SetFaded(rec.parts.loss and ns.FillRegion(rec.parts.loss), on)
end

-- The outlines of a frame: its bars and its picture.
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
	return list
end

-- Rounds the corners of the bars, and the borders of the picture, of a frame, or makes them square again. The picture itself stays square. False
-- when the client refuses the slicing.
local function Reshape(rec, radius)
	local ok = true
	for _, entry in ipairs(rec.bars) do
		if entry.cut == nil and radius then
			entry.cut = { mask = CutMask(entry.bar, entry.target) }
		end
		if entry.cut then
			ok = Shape(entry.cut.mask, radius, false, true) and ok
		end
	end
	for _, outline in ipairs(Outlines(rec)) do
		if radius then
			ok = Round(outline, radius) and ok
		else
			Unround(outline)
		end
	end
	if rec.row then
		rec.row.radius = radius
		rec.row.paint = nil
		-- The line under the row stops where the rounded corners begin.
		rec.row.line:SetPoint("BOTTOMLEFT", rec.row.frame, "BOTTOMLEFT", radius or 0, 0)
		rec.row.line:SetPoint("BOTTOMRIGHT", rec.row.frame, "BOTTOMRIGHT", -(radius or 0), 0)
	end
	return ok
end

-- The corners follow the setting. Nothing is made until they are rounded, and nothing is made or anchored in combat: a change waits for its
-- end. A client that refuses the slicing keeps square corners.
local function Corners(rec, on)
	local radius = on and Radius() or nil
	if radius ~= rec.radius then
		if InCombatLockdown() then
			if not rec.cornersQueued then
				rec.cornersQueued = true
				ns.OutOfCombat(function()
					rec.cornersQueued = nil
					pcall(Refresh)
				end)
			end
			return
		end
		if radius and not Reshape(rec, radius) then
			noSlice = true
			ns.Note(KEY, "Unit frames: the game refused sliced textures, so corners stay square.")
			radius = nil
			Reshape(rec, nil)
		elseif radius == nil then
			Reshape(rec, nil)
		end
		rec.radius = radius
		for _, entry in ipairs(rec.bars) do
			Clip(entry, entry.fill, on)
		end
	end
	for _, outline in ipairs(rec.radius and Outlines(rec) or {}) do
		Rim(outline)
	end
end

-- Applies the options to one frame, and puts Blizzard's look back when they say so. A frame keeps its art until its
-- borders are made, which waits for the end of combat.
function Apply(rec)
	local on = Active(rec)
	if not rec.made then
		if not on or rec.refused then
			return
		end
		if InCombatLockdown() then
			-- Each call the game's hooks make until combat ends would queue another.
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
	local parts = rec.parts
	for _, entry in ipairs(rec.bars) do
		-- The thin power bar of a raid frame has its own switch.
		local live = on and (entry.role ~= "power" or rec.kind ~= "raid" or Opt("raidCells") == true)
		ShowOutline(entry.outline, live, Opt("backdrop"))
		local flat = ApplyFill(rec, entry, live)
		ApplyText(rec, entry, live)
		if rec.kind == "partypet" then
			PetTint(rec, flat)
		end
	end
	ApplyNameSize(rec, on)
	for _, region in ipairs(parts.art) do
		ns.SetFaded(region, on)
	end
	ApplyPicture(rec, on)
	-- The game's dragon and glows were drawn around a round portrait. The two options choose only the colour of the picture's border.
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
	-- The row and the picture are laid out again with the border thickness, which waits for the end of combat.
	if not InCombatLockdown() then
		Layout(rec)
	elseif rec.laid ~= LayoutKey(rec) and not rec.layoutQueued then
		rec.layoutQueued = true
		ns.OutOfCombat(function()
			rec.layoutQueued = nil
			Run(LABELS[rec.kind], Apply, rec)
		end)
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

-- Hooks ------------------------------------------------------------------------------------------------------

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

-- The game sets the text of the name of a unit frame in UnitFrame_Update, and the level of the player in PlayerFrame_UpdateLevel. The name
-- row copies both.
local function OnRowText(rec)
	if rec and rec.made and rec.row and RowOn(rec) then
		Run(LABELS[rec.kind], RowText, rec)
		if not LARGE[rec.kind] then
			-- The unit of a small frame changes without the frame being styled again, and its row is coloured by the unit.
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
		-- The game writes the level text with an opacity of its own, so the text that sits under the level of the row is made transparent again.
		Run(LABELS.player, ApplyRow, rec)
	end
end

-- The game shows, hides and skins the PvP plate and icon of the player in PlayerFrame_UpdatePvPStatus, and its flag changes with these events.
local function OnPlayerPvP()
	local rec = Known(_G.PlayerFrame)
	if rec and rec.made then
		Run(LABELS.player, ApplyFlag, rec)
	end
end

-- The game writes the time left on the player's flag with every tick of the timer. This runs on every frame of the player frame, so the word is
-- made again only when the timer text shown has changed since the last frame.
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

-- The game sets the colour of a threat glow with an alpha of its own each time it updates the glow.
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

-- The game draws a power bar from an atlas again each time it updates the type of power, and the target of target frame
-- does so every frame.
local function OnPowerType(bar)
	if bar == nil or ns.IsSecret(bar) then
		return
	end
	local rec = byPower[bar]
	if rec and rec.made and rec.byRole.power and Active(rec) and Opt("flat") then
		Run(LABELS[rec.kind], ApplyFill, rec, rec.byRole.power, true)
	end
end

-- The game tints the health bar of a party pet green with each health update.
local function OnHealthUpdate(bar)
	if bar == nil or ns.IsSecret(bar) then
		return
	end
	local rec = byHealth[bar]
	if rec and rec.tinted then
		Run(LABELS.partypet, PetTint, rec, true)
	end
end

-- The game draws a portrait with each new unit, each frame set up again and the event of the portrait, with a call the hook
-- on UnitFramePortrait_Update sees. The target of target frame draws its portrait every frame while it is shown.
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

-- The game tints the portrait of a party member as health and connection change, and the picture takes the tint.
local function OnTint(frame)
	local rec = Known(frame)
	if rec and rec.made and rec.pic and Squared(rec, Active(rec)) then
		Run(LABELS[rec.kind], Tint, rec)
		for _, hook in ipairs(ns.UnitFrameExtra.after.tint) do
			Run(hook.part, hook.fn, rec)
		end
	end
end

-- The picture of a target of target waits between draws, and a new target or focus is drawn at once.
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

-- Reads what the unit of a target or focus frame is again, and shows it once the frame has its borders.
local function Reread(rec)
	ReadRank(rec)
	if rec.made and Active(rec) then
		Colour(rec, true)
		Kind(rec)
	end
end

-- The unit of the target or focus frames changed, or every one of them when the client does not say which unit.
local function Reclassify(unit)
	for _, rec in pairs(records) do
		if RANKED[rec.kind] and (unit == nil or ns.IsSecret(unit) or UnitOf(rec) == unit) then
			Run(KIND_PART, Reread, rec)
		end
	end
end

-- A unit that a frame which changes shows: target, focus, their targets, the party and its pets, the bosses.
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

-- The game shows and hides the attack glow of the pet in its own handler of these events, which has run before this one.
local function OnPetAttack()
	local rec = Known(_G.PetFrame)
	if rec and rec.made and Active(rec) then
		Run(LABELS.pet, Colour, rec, true)
	end
end

local function IsIconSetting(name)
	return not ns.IsSecret(name) and (name == "ReplaceMyPlayerPortrait" or name == "ReplaceOtherPlayerPortraits")
end

-- The game draws portraits again when the player changes whether they are class icons, with the function it kept before this
-- addon hooked it, so the hook does not see it.
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
	hooked[name] = true
	hooksecurefunc(_G, name, fn)
end

-- The frames of a kind that exist now. Party members come from a pool and appear when the party frame first shows, and so
-- do their pet frames. Raid frames are made one at a time as the group needs them.
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

-- Totems -----------------------------------------------------------------------------------------------------

-- A totem button has a ring of art around a round icon. The ring is hidden and the icon becomes a square with a thin
-- border. The swipe of the cooldown stays round.
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

-- The buttons are made when a totem is placed, so a button is styled once the game has set it up. Buttons that stopped on errors
-- count as off.
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
	-- The totem timers and swipes of UnitExtras.lua are put right after each pass over the buttons.
	if ns.UnitFrameExtra.afterTotems ~= nil then
		ns.UnitFrameExtra.afterTotems()
	end
end

-- Aura icons -------------------------------------------------------------------------------------------------

-- The border of an icon is the colour the game gives its own border for the type of the debuff, or the colour of a
-- buff that can be stolen.
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

-- The stack number and the countdown number of a debuff icon beside a party frame or under a pet frame. The icons seen are kept so that a changed
-- setting reaches them. At the defaults the game's own text and cooldown are not called.
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
		-- The buttons of the target and focus frames may be protected.
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
		-- The share cut off at each edge: Aura icon crop. The icon is cut again when the setting changes.
		local crop = Opt("auraCrop") / 100
		if rec.crop ~= crop then
			rec.crop = crop
			rec.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		end
		ColourAura(rec)
	end
end

-- The debuff icons of the target of target frames are plain frames with named parts.
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

-- The debuff icons beside a party frame and under a pet frame are buttons from a pool of the frame.
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

-- The icons of a target or focus frame are buttons of the game's protected part, in a container the addon may not
-- read. They are styled where the game hands them over.
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

-- The game sets the colour of a debuff border with an alpha of its own each time it colours the border.
local function OnAuraBorder(region)
	local rec = not ns.IsSecret(region) and byBorder[region]
	if rec and rec.on then
		ns.SetFaded(region, true)
		Run(AURAS, ColourAura, rec)
	end
end

-- The game colours the glow of a party member for the top debuff with an alpha of its own, and shows or hides it, when it draws
-- the debuff icons of a party frame or a pet frame. The glow stays transparent and its colour goes to the border of the health
-- bar, and the icons are styled.
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

-- Frames -----------------------------------------------------------------------------------------------------

-- The game methods that draw a frame again are called from its OnEvent script, its OnShow, the OnValueChanged of its health bar, and Edit Mode.
-- None of them is hooked: hooksecurefunc(frame, "Method", fn) writes a wrapper into the frame's own table, which the game reads again in its
-- secure passes (EllesmereUI/EllesmereUIChat/EllesmereUIChat.lua:4410-4417, 6270-6281). The scripts are followed with HookScript, which writes
-- nothing on the frame, and the work waits one frame, so it never runs inside the game's call (EllesmereUI/EllesmereUIUnitFrames/UnitFrames_Init.lua:509-520).
-- tasks per frame: art (the frame is drawn again), tint (the portrait of a party member), auras, party (the member pool), totems.
local Later = { tasks = {}, queued = false, events = {} }

-- The events of a kind of frame after which the game has called its methods, and what is done about each.
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
	-- TargetFrameMixin:OnEvent calls CheckFaction, CheckLevel, CheckClassification and CheckBattlePet through Update and on its own
	-- (client/ui/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua:143-158, 205-250). Auras again with a new target or focus (:175, :252).
	local TARGET = { "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGETABLE_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
		"UNIT_LEVEL", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED", "GROUP_ROSTER_UPDATE" }
	for _, kind in ipairs({ "target", "focus", "boss" }) do
		Events(kind, "art", TARGET)
	end
	for _, kind in ipairs({ "target", "focus" }) do
		Events(kind, "auras", { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" })
	end
	-- PartyMemberFrameMixin:OnEvent (Mainline/PartyMemberFrame.lua:517-590): UpdateMember draws the art, the auras and the online state;
	-- a lost connection draws the art; the auras have their own event.
	Events("party", "art tint auras", { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UPDATE_ACTIVE_BATTLEFIELD", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_PET" })
	Events("party", "art", { "UNIT_CONNECTION" })
	Events("party", "auras", { "UNIT_AURA", "VARIABLES_LOADED" })
	-- PetFrameMixin:OnEvent (Mainline/PetFrame.lua:76-116) calls Update for these and UpdateAuras for UNIT_AURA.
	Events("pet", "art auras", { "UNIT_PET", "UNIT_EXITED_VEHICLE", "PET_UI_UPDATE" })
	Events("pet", "auras", { "UNIT_AURA" })
	-- What Edit Mode draws again when it opens and closes: SetSmallSize of the focus and boss frames, UpdateAuras of the target and focus frames.
	Later.edit = { target = "auras", focus = "art auras", boss = "art", party = "art tint auras", pet = "art auras" }
	-- The events after which the game redraws the aura icons of the pet frame under a party member.
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

-- The next frame: each frame that was named does its work once, whatever the number of events.
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

-- The portrait of a frame has its mask again after a pass of the game: it is taken off in the next frame.
function Mask.queue(rec)
	Later.add(rec.frame, "mask")
end

-- Follows a script of a frame, once per frame and script. HookScript runs after the game's script and writes nothing on the frame.
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

-- The OnEvent script of a frame the game draws: the events that lead to its methods queue the work.
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
		-- The first boss frame hears this event and draws all of them.
		for _, other in ipairs(FramesOf("boss")) do
			if Known(other) then
				Later.add(other, "art")
			end
		end
	end
end

-- The player frame draws its art again, and with it the pet frame and the totems.
function Later.layout()
	if Known(_G.PetFrame) then
		Later.add(_G.PetFrame, "art auras")
	end
	if not ns.Forbidden(_G.TotemFrame) then
		Later.add(_G.TotemFrame, "totems")
	end
end

-- Edit Mode opening or closing.
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
			-- PartyMemberHealthCheck is called from the OnValueChanged of the health bar (Mainline/PartyFrameTemplates.xml:193).
			if kind == "party" then
				Later.script(rec.parts.health, "OnValueChanged", function()
					Later.add(frame, "tint")
				end)
			elseif kind == "pet" then
				-- PetFrameMixin:OnShow and OnHide draw the frame and call TotemFrame:Update (Mainline/PetFrame.lua:123-133).
				Later.script(frame, "OnShow", function()
					Later.add(frame, "art auras")
					Later.add(_G.TotemFrame, "totems")
				end)
				Later.script(frame, "OnHide", function()
					Later.add(_G.TotemFrame, "totems")
				end)
			end
			-- The game writes the name of a unit in UnitFrame_Update alone (Mainline/UnitFrame.lua:150-166), and the name row follows
			-- that function. The time left on the player's flag is written in PlayerFrame_OnUpdate every frame (Mainline/PlayerFrame.lua:232-238).
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

-- The game puts its masks on the fills of a party member with each set up, which it does on the same frames from the pool.
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

-- Every frame the game sets up is looked at once, and a raid frame is styled.
local function OnRaidSetUp(frame)
	if ns.Enabled(KEY) and not ns.Forbidden(frame) and IsRaidFrame(frame) then
		Run(LABELS.raid, StyleFrame, frame, "raid")
	end
end

-- The game shows the target and threat outlines with an alpha of its own, and sets the background colour of a raid frame.
local function OnRaid(frame)
	local rec = Known(frame)
	if rec and rec.made and Active(rec) then
		for _, region in ipairs(rec.parts.art) do
			ns.SetFaded(region, true)
		end
		Run(LABELS.raid, Colour, rec, true)
		-- The game draws the power bar's fill again with its own colour.
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
	-- These call PetFrame:Update and TotemFrame:Update (Mainline/PlayerFrame.lua:463, 648, 747, 756).
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
	-- The game sets a raid frame up again at the start of each full update, which anchors its bars again.
	HookGlobal("CompactUnitFrame_UpdateAll", function(frame)
		local rec = Known(frame)
		if rec and rec.made and Active(rec) then
			for _, hook in ipairs(ns.UnitFrameExtra.after.raid) do
				Run(hook.part, hook.fn, rec, true)
			end
		end
	end)
	-- The party frame draws its members again in its OnShow (Shared/PartyFrame.lua:34-36), the totem frame in its OnEvent
	-- (Mainline/TotemFrame.lua:13-15), in PetFrame's OnShow and OnHide, and in PlayerFrame_ToPlayerArt (Mainline/PlayerFrame.lua:747).
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
	-- A table of functions the game calls by name: hooking it writes on no frame.
	if type(_G.AuraUtil) == "table" and not ns.IsSecret(_G.AuraUtil) and not hooked.AuraUtil and type(hooksecurefunc) == "function"
		and type(_G.AuraUtil.SetAuraBorderColor) == "function" then
		hooked.AuraUtil = pcall(hooksecurefunc, _G.AuraUtil, "SetAuraBorderColor", OnAuraBorder)
	end
	-- Edit Mode shows and hides its manager frame as it opens and closes (Blizzard_EditMode/Shared/EditModeManager.lua:128-147), and the callbacks
	-- "EditMode.Enter" and "EditMode.Exit" come from the same two scripts.
	local manager = _G.EditModeManagerFrame
	if manager ~= nil and not ns.Forbidden(manager) then
		Later.script(manager, "OnShow", Later.editMode)
		Later.script(manager, "OnHide", Later.editMode)
	end
end

-- /flatui art -------------------------------------------------------------------------------------------------

-- The frames whose texture regions /flatui art lists: the frame, its container and content frames and its bar containers.
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

-- The object at the end of a dotted chain of keys, or nil.
local function Descend(root, dotted)
	local value = root
	for key in dotted:gmatch("[^.]+") do
		value = Path(value, key)
	end
	return value
end

-- A value for a line, or ? when there is none or the client withholds it.
local function Text(value)
	if value == nil or ns.IsSecret(value) or (type(value) ~= "string" and type(value) ~= "number") then
		return "?"
	end
	return tostring(value)
end

-- A length in whole units, and a share to two places, or ? when the client withholds it.
local function Size(value)
	return Number(value) and ("%d"):format(math.floor(value + 0.5)) or "?"
end

local function Share(value)
	return Number(value) and ("%.2f"):format(value) or "?"
end

-- One line for a texture region: where it is drawn, what it draws, how big it is, its colour and its alpha.
local function ArtLine(label, region)
	local layer, sublevel = Ask(region, "GetDrawLayer")
	local atlas = Ask(region, "GetAtlas")
	local what = type(atlas) == "string" and atlas ~= "" and atlas or Ask(region, "GetTexture")
	local width, height = Ask(region, "GetSize")
	local r, g, b, a = Ask(region, "GetVertexColor")
	return ("%s %s:%s %s %sx%s %s,%s,%s,%s alpha %s"):format(label, Text(layer), Text(sublevel), Text(what), Size(width), Size(height),
		Share(r), Share(g), Share(b), Share(a), Share((Ask(region, "GetAlpha"))))
end

-- The shown texture regions of a frame, the addon's own left out.
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

-- Prints the texture regions that are shown on the player and target frames, to name the art a frame draws.
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

-- The line of /flatui status for the square portrait of a frame.
function STATUS.picture(rec, name)
	local pic = rec.pic
	if pic == nil then
		return nil
	end
	local text
	if not (Active(rec) and Opt("squarePortrait") == true) then
		text = "off"
	elseif pic.game then
		text = "off, the game's portrait shown"
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
		text = ("%s, %s, frame level %s%s%s, %s"):format(size, rec.radius and "rounded border" or "square corners", Size(Ask(pic.frame, "GetFrameLevel")),
			pic.measured == false and ", sized from the default layout" or "", Ask(pic.frame, "IsRectValid") == false and ", no place on screen" or "", pic.icon and "class icon" or "face")
	end
	return ("%s portrait: %s"):format(name, text)
end

-- The line of /flatui status that says whether the client withholds the name and the class of the unit of a frame. Nothing is read from the unit.
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

-- The line of /flatui status for the PvP flag of a frame.
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
				text = text .. (at and not ns.IsSecret(relative) and relative == rec.parts.pvp and ", icon on the plate" or ", icon apart from the plate")
			end
		end
	end
	return ("%s PvP flag: %s"):format(name, text)
end

-- The first party frame of the pool that is shown.
function STATUS.firstParty()
	for _, frame in ipairs(FramesOf("party")) do
		if Known(frame) and Ask(frame, "IsShown") ~= false then
			return frame
		end
	end
	return nil
end

-- The line of /flatui status for the colour of a name row, and where it comes from.
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

-- The line of /flatui status for the size of a name row, in units.
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

-- The lines of /flatui status for the player, target, pet, target of target, boss 1 and first party frames: where the name comes from, the portrait,
-- the PvP flag, the size of the pet's name, the size and colour of a small frame's row and the scale of the pet frame. A target, pet, target of
-- target or boss frame that is not shown has one line.
local function StatusLines()
	local lines = {}
	local frames = { _G.PlayerFrame, _G.TargetFrame, _G.PetFrame, _G.TargetFrameToT, _G.Boss1TargetFrame, STATUS.firstParty() }
	-- A frame that does not exist leaves a hole in the list, so it is walked by its place.
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
							-- On a target with no kind these are the widths of texts with no words, which the mark and the word of a kind rely on being 0.
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
	-- An icon already styled takes a changed crop or border colour; in combat the loop is skipped, and a changed crop or colour waits for the next game aura update or the next Refresh.
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

-- What the files after this one use.
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

ns.Register(KEY, {
	label = "Unit frames", Start = Refresh, Refresh = Refresh, Resized = Refresh, Status = StatusLines,
	events = { PET_ATTACK_START = OnPetAttack, PET_ATTACK_STOP = OnPetAttack, CVAR_UPDATE = OnIconSetting,
		-- A new target or focus is read, and the client may not name them yet when the frames are styled at login, so each is read again once the
		-- player is in the world.
		PLAYER_TARGET_CHANGED = function() OnTargetChange(); Reclassify("target") end, PLAYER_FOCUS_CHANGED = function() OnTargetChange(); Reclassify("focus") end,
		UNIT_TARGET = OnTargetChange, UNIT_CLASSIFICATION_CHANGED = Reclassify, PLAYER_ENTERING_WORLD = function() Reclassify() end,
		PVP_TIMER_UPDATE = OnPlayerPvP, PLAYER_PVP_FLAG_CHANGED = OnPlayerPvP,
		-- Edit Mode applies the layout again after a specialization change, which runs SetSmallSize and UpdateAuras of the target and focus frames
		-- (EditModeManager.lua:202-206, EditModeSystemTemplates.lua:1473-1486).
		PLAYER_SPECIALIZATION_CHANGED = function() Later.editMode() end,
		-- The colour of a unit depends on who is in the group and on how the unit stands to the player.
		GROUP_ROSTER_UPDATE = function() ns.UnitFrameExtra.unitsChanged() end, UNIT_FACTION = function() ns.UnitFrameExtra.unitsChanged() end },
	filters = { UNIT_FACTION = IsChangingUnit, CVAR_UPDATE = IsIconSetting, UNIT_TARGET = IsTargetUnit, UNIT_CLASSIFICATION_CHANGED = IsClassifiedUnit },
	slash = { art = PrintArt },
	help = { "/flatui art - the textures shown on the player and target frames" },
})
