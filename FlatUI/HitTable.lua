local ADDON_NAME, ns = ...

-- Hit table (hud.hitTable, on the Hit table tab of Minimap and buffs, off by default): a small table of Flat UI's own under the player frame with the
-- player's chances against the target, worked out again as stats, gear, weapon skill, buffs, form and the target change; HitTableCalc.lua has the
-- numbers and their sources. Part "hit table" of the hud module, which stops alone after a few faults: Hud.lua calls ns.HitTableRefresh in every
-- refresh of the page, and everything else here runs inside ns.EachPart.
--
-- The table: a title with the enemy as counted and where the player stands, the weapon skill at its right, a heading, and a line for each attack
-- (Swing, or Main and Off while dual wielding; Special; Ranged; Spell) with a column for each part of the roll that applies to a line shown: Miss,
-- Dodge, Parry, Glance, Block, Crit, Hit, and Cap, the crit cap of a swing. A crit above the cap turns the crit and the cap yellow; a miss, dodge or
-- parry down to its floor turns green. A part that does not apply is -, one the game withheld or refused is ?, and /flatui status says which.
--
-- The frame is a frame of its own on UIParent, in the LOW strata of the player frame (Mainline/PlayerFrame.xml:13), with no mouse and no name, in a
-- flat background with a thin border of the hud page's look (ns.Outline, made inside ns.EachPart). With no spot saved in the movers it hangs from a
-- rail, a second frame of its own with two points: its top left corner on the left edge Flat UI draws for the player frame (the body of One frame,
-- else Flat UI's picture, else the game's portrait, PlayerFrame.xml:23-30, else the health bar) and its bottom right corner on the frame the game
-- hangs the pet frame and the totems in, PlayerBottomManagedFrameContainer (PlayerFrame.xml:477-484, Shared/PlayerFrameTemplates.xml:4-31), or on the
-- player's cast bar while Edit Mode locks it to the player frame (Shared/PlayerFrame.lua:18-48). The table's top left corner is the rail's bottom left
-- one, a gap lower. So its left edge is the portrait's in either Frame style, and the game lowers it as a pet frame, totems or the locked cast bar come,
-- in a fight too, with no call from Flat UI. The gap also clears the lowest line Flat UI draws on the player frame (the borders of its power bar,
-- health bar and picture, the body of One frame, the druid's mana bar of UnitDruidMana.lua) while the container is at its smallest, so it holds with
-- a pet or without one. Points are set out of combat only, as Flat UI hangs every frame of its own from the player frame (Core.lua); a change asked
-- for in a fight waits once for its end (ns.OutOfCombat). /flatui move places it (FlatUIHitTable in Movers.lua, with the table as its box), and a
-- spot saved there wins.
--
-- What it hears: a frame of its own registers the events that change the numbers only while the table is wanted, the unit events for the player
-- and the target alone (RegisterUnitEvent), as the character sheet registers its own (Camelot/PaperDollFrame.lua:314-351). An event only marks the
-- table, and one OnUpdate on the next frame works it out once for a burst, as the sheet batches its events (Camelot/PaperDollFrame.lua:392-395). The
-- cast bar's lock is followed with hooksecurefunc (ns.FollowGlobal, as CastBarSize.lua follows it), and a refresh of the unit frames places the table
-- again (ns.UnitFrameExtra.after.refresh). Nothing of the game's is written: its frames are read and anchored to, never changed.

local KEY, PART = "hud", "hit table"
local MOVER = "FlatUIHitTable"
local SANS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\IBMPlexSans-Regular.ttf"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local FONT = "GameFontHighlightSmall"
-- The text is 11 px at 100%. Units inside the edge across and down, between two columns, after the names of the lines, and between the title and the
-- weapon skill.
local BASE, PAD_X, PAD_Y, COLUMN_GAP, NAME_GAP, TITLE_GAP = 11, 6, 4, 6, 8, 12
-- Units between what hangs under the player frame and the table's border, as Cooldown icons keeps under the frame it hangs from (Cooldowns.lua:41).
local GAP = 4
-- The height of the container the game hangs the pet frame in while it holds nothing (minimumHeight, Shared/PlayerFrameTemplates.xml:16).
local SMALLEST = 1
-- Points of weapon skill a level, for the status line of a skill the game did not give (HitTableCalc.lua counts the same).
local PER_LEVEL = 5
-- The colours of the windows' text and states (PanelLook.lua:27-31), as Threat list and Data panels have them.
local DIM, FAINT, PLAIN = { 0.66, 0.68, 0.62 }, { 0.48, 0.50, 0.45 }, { 1, 1, 1 }
local OK, WARN = { 0.49, 0.80, 0.56 }, { 0.90, 0.72, 0.36 }
-- The columns, in the order of the roll.
local COLUMNS = { { "miss", "Miss" }, { "dodge", "Dodge" }, { "parry", "Parry" }, { "glance", "Glance" }, { "block", "Block" }, { "crit", "Crit" },
	{ "hit", "Hit" }, { "cap", "Cap" } }
-- The widest number a cell shows, which sets the width of a column.
local WIDEST = "100.0"
-- The parts whose floor is good news: no miss (1 for spells under Classic rules), no dodge, no parry.
local FLOORED = { miss = true, dodge = true, parry = true }
-- The word of a kind of enemy in the title (ns.UnitKind).
local KIND_WORDS = { boss = "boss", elite = "elite", rare = "rare", rareelite = "rare elite" }
-- The events: the player's alone, the target's alone, and the others (UNIT_LEVEL is heard for both units). Each is in events.yaml of the client and
-- in the sheet's list or the target frame's.
local PLAYER_EVENTS = { "UNIT_STATS", "UNIT_ATTACK", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
	"UNIT_DISPLAYPOWER" }
local TARGET_EVENTS = { "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_TARGET", "UNIT_HEALTH" }
local EVENTS = { "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED",
	"SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM",
	"PLAYER_TARGET_CHANGED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
	"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED" }
-- The events after which the table is placed again: a new world, the screen, the scale or Edit Mode's layout changed.
local PLACE_EVENTS = { PLAYER_ENTERING_WORLD = true, UI_SCALE_CHANGED = true, DISPLAY_SIZE_CHANGED = true, EDIT_MODE_LAYOUTS_UPDATED = true }
-- The lines of /flatui status.
local LINE_WHERE = {
	container = "Hit table: under the player frame.",
	frame = "Hit table: under the player frame.",
	["cast bar"] = "Hit table: under the cast bar, which Edit Mode locks to the player frame.",
	spot = "Hit table: at the spot set with the movers.",
	screen = "Hit table: the player frame cannot be used, so the table is under the middle of the screen.",
}
local LINE_WAITS = "Hit table: a change of place waits for the end of the fight."
local LINE_SANS = "Hit table: the game did not load Flat UI Sans, so the table uses the game font."
local LINE_GAP = {
	withheld = "Hit table: the game withheld your %s, so parts of %s show ?.",
	refused = "Hit table: the game refused your %s, so parts of %s show ?.",
	missing = "Hit table: this client gives no %s, so parts of %s show ?.",
}
local LINE_ASSUMED = "Hit table: the game gave no weapon skill for your %s, so it counts %d, the most for your level."
local LINE_UNKNOWN = "Hit table: your target's level shows as ??, so it counts as level %d."
local LINE_PLAYER = "Hit table: against a player, dodge, parry and block start at 5%, since the game does not give theirs."
local LINE_NO_RANGED = "Hit table: no ranged line, since you wear no bow, gun, crossbow, thrown weapon or wand."
local LINE_RANGED_UNKNOWN = "Hit table: no ranged line, since the game did not say what your ranged slot holds."
local LINE_EMPTY = "Hit table: hidden, with no line to show."
local LINE_NO_LEVEL = "Hit table: hidden, since the game does not give your level."

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- frame: the table; rail: the frame it hangs from under the player frame; outline: its background and border; title and note: the first line, the
-- enemy and the weapon skill; heads: the headings; rows: the lines, each { label, cells }; probe: a text never drawn that measures widths. A text
-- is { fs, text, colour, font }: the font string and what was last written to it. fontKey, file, size: the font in use; widths: widths measured
-- with it, by text. ear: the frame that hears the events, hearing: it does, units: the units each unit event counts for, alone: the unit events
-- the client registered for those units alone, dirty: the table waits for the next frame. fighting: between PLAYER_REGEN_DISABLED and
-- PLAYER_REGEN_ENABLED. dead: the target was dead at the last look. read: the last numbers (HitTableCalc.lua). laid: the key of the layout.
-- placed, edge, anchor: where the table was put; where: what /flatui status says of it; later: a place waits for the end of the fight. hooked: the
-- cast bar's lock is followed. sansRefused: the game refused Flat UI Sans.
local S = { heads = {}, rows = {}, widths = {}, units = {}, alone = {}, hearing = false, fighting = false, dirty = false, later = false }
local Update, Later, Off

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- True while the table is wanted: the page on, the row on, the part not stopped.
local function Wanted()
	return ns.Enabled(KEY) and Opt("hitTable") == true and not ns.PartStopped(KEY, PART)
end

-- Runs fn as this part: a fault is counted by ns.EachPart, and three stop the part alone (each call is a new table, so each fault counts); the
-- table then hides at once and hears nothing more, as MapText.lua puts its text away.
local function Call(_, fn, ...)
	fn(...)
end

local function Safe(fn, ...)
	if ns.EachPart(KEY, PART, Call, {}, fn, ...) then
		return true
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Off)
	end
	return false
end

-- Whether the player is in a fight now, for a first look; a withheld answer counts as out of combat, as for the Threat list (Threat.lua).
local function InFight()
	local value = Ask(UnitAffectingCombat, "player")
	if type(value) == "boolean" then
		return value
	end
	return Ask(InCombatLockdown) == true
end

-- The player frame ----------------------------------------------------------------------------------------------------------------------------------

-- A field of a frame of the game, read without writing it, or nil (as UnitFrames.lua reads its parts).
local function Path(root, ...)
	local node = root
	for index = 1, select("#", ...) do
		if node == nil or IsSecret(node) or type(node) ~= "table" then
			return nil
		end
		local key = select(index, ...)
		local ok, child = pcall(function()
			return node[key]
		end)
		node = ok and not IsSecret(child) and child or nil
	end
	return node
end

-- True for a region whose left edge the client gives now, so a point set on it holds.
local function Laid(region)
	if region == nil or IsSecret(region) or type(region) ~= "table" then
		return false
	end
	local ok, left = pcall(function()
		return region:GetLeft()
	end)
	return ok and Finite(left)
end

-- True while a region is shown, by its own flag.
local function Shown(region)
	if region == nil or IsSecret(region) or type(region) ~= "table" then
		return false
	end
	local ok, shown = pcall(function()
		return region:IsShown()
	end)
	return ok and not IsSecret(shown) and shown == true
end

-- An edge of a frame in units of scale 1, its own units times its effective scale, so frames of any scale compare; nil when it cannot be read.
local function Edge(frame, method)
	if frame == nil or IsSecret(frame) or type(frame) ~= "table" then
		return nil
	end
	local ok, value, scale = pcall(function()
		return frame[method](frame), frame:GetEffectiveScale()
	end)
	if ok and Finite(value) and Finite(scale) and scale > 0 then
		return value * scale
	end
	return nil
end

local function Scale(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	return ok and Finite(scale) and scale > 0 and scale or 1
end

-- Flat UI's record of the player frame (UnitFrames.lua, which makes it whatever the Player frame row says), and the table of its helpers.
local function Record()
	local X = ns.UnitFrameExtra
	if type(X) ~= "table" or type(X.known) ~= "function" then
		return nil, X
	end
	return X.known(_G.PlayerFrame), X
end

-- The region whose left edge the table starts at: the body of One frame (UnitFrames.lua, FRAME.place), else Flat UI's picture while it shows, else
-- the game's portrait while it shows, else the health bar, else the player frame. Each has its own border outside it, as the table has.
local function LeftEdge()
	local frame = _G.PlayerFrame
	local rec, X = Record()
	if rec then
		if type(X.joined) == "function" and X.joined(rec) == true and type(X.body) == "function" then
			local body = X.body(rec)
			if Laid(body) then
				return body
			end
		end
		local picture = type(rec.pic) == "table" and rec.pic.frame or nil
		if Shown(picture) and Laid(picture) then
			return picture
		end
	end
	local portrait = Path(frame, "PlayerFrameContainer", "PlayerPortrait")
	if Shown(portrait) and Laid(portrait) then
		return portrait
	end
	local health = rec and type(rec.parts) == "table" and rec.parts.health
		or Path(frame, "PlayerFrameContent", "PlayerFrameContentMain", "HealthBarsContainer", "HealthBar")
	if Laid(health) then
		return health
	end
	return Laid(frame) and frame or nil
end

-- The frame the table hangs under, and its name for /flatui status: the player's cast bar while Edit Mode locks it to the player frame, which the
-- game reads from attachedToPlayerFrame (Shared/PlayerFrame.lua:43, 58, 65-69; read only, as CastBarSize.lua reads it), else the container of the
-- pet frame and the totems, else the player frame.
local function Anchor()
	local bar = _G.PlayerCastingBarFrame
	if not ns.Forbidden(bar) then
		local ok, attached = pcall(function()
			return bar.attachedToPlayerFrame
		end)
		if ok and not IsSecret(attached) and attached == true then
			return bar, "cast bar"
		end
	end
	local box = _G.PlayerBottomManagedFrameContainer
	if not ns.Forbidden(box) then
		return box, "container"
	end
	local frame = _G.PlayerFrame
	if not ns.Forbidden(frame) then
		return frame, "frame"
	end
	return nil
end

-- The lowest line Flat UI draws on the player frame, in units of scale 1, border is the width of one border there: under the body of One frame,
-- else under the power bar, the health bar and the picture while Flat UI styles the frame, and under the druid's mana bar, whose holder keeps its
-- place in every form (UnitDruidMana.lua). Nil while Flat UI draws nothing there.
local function Lowest(border)
	local rec, X = Record()
	if not rec then
		return nil
	end
	local low
	local function Take(region)
		local bottom = Edge(region, "GetBottom")
		if bottom then
			low = math.min(low or bottom - border, bottom - border)
		end
	end
	if type(X.active) == "function" and X.active(rec) == true then
		if type(X.joined) == "function" and X.joined(rec) == true and type(X.body) == "function" then
			Take(X.body(rec))
		else
			local roles = type(rec.byRole) == "table" and rec.byRole or {}
			Take(type(roles.power) == "table" and roles.power.target or nil)
			Take(type(roles.health) == "table" and roles.health.target or nil)
			local picture = type(rec.pic) == "table" and rec.pic.frame or nil
			if Shown(picture) then
				Take(picture)
			end
		end
	end
	local mana = rec.druidMana
	if type(mana) == "table" and mana.holder ~= nil and ns.Enabled("unitframes") and ns.Get("unitframes.druidMana") == true then
		Take(mana.holder)
	end
	return low
end

-- How far under the anchor's bottom the table's top is, in its own units: GAP and its own border, and as much more as Flat UI's player frame reaches
-- under the anchor while the container is at its smallest. The game lowers the container's bottom as a pet frame comes, and the locked cast bar with
-- it while the container shows (Shared/PlayerFrame.lua:24-27), so the anchor's bottom at the smallest is its bottom now raised by what the container
-- holds; the table then clears Flat UI's frame with a pet or without one.
local function Offset(anchor, kind)
	local frame = S.frame
	local scale = Scale(frame)
	local pixel = ns.Pixels(frame, 1) * scale
	local thickness = tonumber(ns.Get("general.thickness")) or 1
	local offset = GAP * scale + (Opt("hitTableBack") ~= false and thickness * pixel or 0)
	local bottom, low = Edge(anchor, "GetBottom"), Lowest(thickness * pixel)
	if bottom and low then
		local box = _G.PlayerBottomManagedFrameContainer
		if kind == "container" or (kind == "cast bar" and Shown(box)) then
			local ok, height, boxScale = pcall(function()
				return box:GetHeight(), box:GetEffectiveScale()
			end)
			if ok and Finite(height) and Finite(boxScale) and height > SMALLEST then
				bottom = bottom + (height - SMALLEST) * boxScale
			end
		end
		offset = offset + math.max(0, bottom - low)
	end
	return offset / scale
end

-- Places the table, out of combat: at the spot saved in the movers, by the point it was saved by (as Data panels reads it, DataPanels.lua), else
-- under the player frame from the rail, else under the middle of the screen when the player frame cannot be used. A place already taken is not set
-- again.
local function Place()
	local frame = S.frame
	if not frame then
		return
	end
	if InCombatLockdown() then
		Later()
		return
	end
	local spots = type(ns.Spots) == "function" and ns.Spots() or nil
	local entry = type(spots) == "table" and type(ns.CleanSpot) == "function" and ns.CleanSpot(spots[MOVER]) or nil
	local point = entry and entry.point or "TOPLEFT"
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, point)
	end
	if x then
		local key = ("spot:%s:%.2f:%.2f"):format(point, x, y)
		if S.placed ~= key then
			frame:ClearAllPoints()
			frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
			S.placed, S.edge, S.anchor = key, nil, nil
		end
		S.where = "spot"
		return
	end
	local anchor, kind = Anchor()
	local edge = anchor and LeftEdge() or nil
	if anchor and edge then
		local offset = Offset(anchor, kind)
		local key = ("%s:%.2f"):format(kind, offset)
		if S.placed == key and S.edge == edge and S.anchor == anchor then
			S.where = kind
			return
		end
		local rail = S.rail
		local ok = pcall(function()
			rail:ClearAllPoints()
			rail:SetPoint("TOPLEFT", edge, "TOPLEFT", 0, 0)
			rail:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", rail, "BOTTOMLEFT", 0, -offset)
		end)
		if ok then
			S.placed, S.edge, S.anchor, S.where = key, edge, anchor, kind
			return
		end
	end
	if S.placed ~= "screen" then
		frame:ClearAllPoints()
		frame:SetPoint("TOP", UIParent, "CENTER", 0, -150)
		S.placed, S.edge, S.anchor = "screen", nil, nil
	end
	S.where = "screen"
end

-- A place asked for in a fight waits once for its end.
Later = function()
	if S.later then
		return
	end
	S.later = true
	ns.OutOfCombat(function()
		S.later = false
		if S.frame and Wanted() then
			Safe(Place)
		end
	end)
end

-- Text -----------------------------------------------------------------------------------------------------------------------------------------------

-- Flat UI Sans has Latin and Cyrillic letters; any other client takes the game font (DataPanels.lua, Covers).
local function Covers()
	if ns.FontsLatin == nil or ns.FontsLatin() then
		return true
	end
	return Ask(GetLocale) == "ruRU"
end

-- The file of the game's small text, read from its font object.
local function GameFile()
	local object = _G[FONT]
	if type(object) == "table" and not IsSecret(object) then
		local ok, file = pcall(object.GetFont, object)
		if ok and not IsSecret(file) and type(file) == "string" and file ~= "" then
			return file
		end
	end
	return GAME_FONT
end

-- The font of Font and Text size. A change forgets the widths measured with the old one.
local function Font()
	local size = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	local file = Opt("hitTableFont") == "sans" and Covers() and SANS or nil
	local key = ("%s:%.2f"):format(file or "game", size)
	if S.fontKey ~= key then
		S.fontKey, S.file, S.size, S.widths, S.sansRefused = key, file, size, {}, false
	end
end

-- Gives a text the font in use once. A face the game refuses (an answer of false, or an error) leaves the game's font, and /flatui status says so
-- (DataPanels.lua, P.SetFont).
local function Dress(text)
	if text.font == S.fontKey then
		return
	end
	text.font = S.fontKey
	local fs = text.fs
	if S.file then
		local ok, set = pcall(fs.SetFont, fs, S.file, S.size, "")
		if ok and (IsSecret(set) or set ~= false) then
			return
		end
		S.sansRefused = true
	end
	pcall(fs.SetFont, fs, GameFile(), S.size, "")
end

-- A text of the table's own, one line, with the shadow the readouts of the screen have.
local function Text(parent, justify)
	local fs = ns.OwnText(parent, "OVERLAY", FONT)
	fs:SetJustifyH(justify)
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	return { fs = fs }
end

-- Line number index, made the first time the table needs it: its name and a cell for each column.
local function Row(index)
	local row = S.rows[index]
	if not row then
		row = { label = Text(S.frame, "LEFT"), cells = {} }
		for column = 1, #COLUMNS do
			row.cells[column] = Text(S.frame, "RIGHT")
		end
		S.rows[index] = row
	end
	return row
end

-- The width of a text in the font in use, measured once with the probe; a client that gives none gets a guess from its length.
local function Measure(text)
	local width = S.widths[text]
	if width == nil then
		local probe = S.probe
		Dress(probe)
		probe.fs:SetText(text)
		local ok, measured = pcall(probe.fs.GetStringWidth, probe.fs)
		width = ok and Finite(measured) and measured > 0 and measured or S.size * 0.6 * #text
		S.widths[text] = width
	end
	return width
end

-- Writes a text and its colour, each only when it changed.
local function Put(text, value, colour)
	Dress(text)
	if text.text ~= value then
		text.fs:SetText(value)
		text.text = value
	end
	if text.colour ~= colour then
		text.fs:SetTextColor(colour[1], colour[2], colour[3], 1)
		text.colour = colour
	end
end

-- Puts a text at a point of the table's top left corner, as wide and as high as given, and shows it.
local function At(text, point, x, y, width, height)
	local fs = text.fs
	fs:ClearAllPoints()
	fs:SetPoint(point, S.frame, "TOPLEFT", x, y)
	fs:SetSize(width, height)
	fs:Show()
end

-- The table ----------------------------------------------------------------------------------------------------------------------------------------

-- The columns that apply to a line shown, in the order of the roll.
local function Columns(lines)
	local list = {}
	for _, column in ipairs(COLUMNS) do
		for _, line in ipairs(lines) do
			if line.parts[column[1]] ~= false then
				list[#list + 1] = column
				break
			end
		end
	end
	return list
end

-- The title: the enemy as counted, and where the player stands while a line of a weapon shows.
local function Title(read)
	local target = read.target
	if not target then
		return ""
	end
	local text
	if target.boss then
		text = ("Boss, level %d"):format(target.level)
	elseif target.none then
		text = ("Level %d, no target"):format(target.level)
	else
		local kind = target.player and "player" or KIND_WORDS[target.kind]
		text = (target.unknown and "Level ?? (%d)" or "Level %d"):format(target.level) .. (kind and (" " .. kind) or "")
	end
	for _, line in ipairs(read.lines) do
		if line.skill then
			return text .. (read.front and ", in front" or ", behind")
		end
	end
	return text
end

-- The weapon skill of the lines of a weapon, a special attack's being the swing's.
local function Note(read)
	local skills = {}
	for _, line in ipairs(read.lines) do
		if line.skill and line.id ~= "special" then
			skills[#skills + 1] = ("%d"):format(math.floor(line.skill + 0.5))
		end
	end
	return #skills > 0 and ("Skill " .. table.concat(skills, " / ")) or ""
end

-- The text and colour of a cell.
local function Value(line, key)
	local value = line.parts[key]
	if value == false then
		return "-", FAINT
	elseif value == nil then
		return "?", DIM
	end
	local colour = PLAIN
	if line.over and (key == "crit" or key == "cap") then
		colour = WARN
	elseif FLOORED[key] and value < (key == "miss" and line.floor or 0) + 0.05 then
		colour = OK
	end
	return ("%.1f"):format(value), colour
end

-- Lays out the title, the headings and the lines, and sizes the table to them: the names of the lines on the left, then each column as wide as its
-- heading or the widest number, its text at its right edge. Laid out again only when the font, the columns, the lines or the width change.
local function Layout(columns, lines, title, note)
	local rowHeight = math.ceil(S.size + 3)
	local nameWidth = 0
	for _, line in ipairs(lines) do
		nameWidth = math.max(nameWidth, Measure(line.label))
	end
	nameWidth = math.ceil(nameWidth)
	local number = Measure(WIDEST)
	local widths, rights, ids = {}, {}, {}
	local x = PAD_X + nameWidth + NAME_GAP
	for index, column in ipairs(columns) do
		widths[index] = math.ceil(math.max(number, Measure(column[2])))
		x = x + widths[index]
		rights[index] = x
		x = x + COLUMN_GAP
		ids[index] = column[1]
	end
	local noteWidth = note ~= "" and math.ceil(Measure(note)) + 2 or 0
	local besideNote = noteWidth > 0 and noteWidth + TITLE_GAP or 0
	local content = (#columns > 0 and rights[#columns] or PAD_X + nameWidth) + PAD_X
	local width = math.max(content, PAD_X + math.ceil(Measure(title)) + besideNote + PAD_X)
	local names = {}
	for index, line in ipairs(lines) do
		names[index] = line.label
	end
	local key = table.concat({ S.fontKey, table.concat(ids, ","), table.concat(names, ","), width, noteWidth }, ":")
	if S.laid == key then
		return
	end
	local frame = S.frame
	At(S.note, "TOPRIGHT", width - PAD_X, -PAD_Y, math.max(1, noteWidth), rowHeight)
	At(S.title, "TOPLEFT", PAD_X, -PAD_Y, math.max(1, width - 2 * PAD_X - besideNote), rowHeight)
	local top = -(PAD_Y + rowHeight)
	for index, head in ipairs(S.heads) do
		if index <= #columns then
			At(head, "TOPRIGHT", rights[index], top, widths[index], rowHeight)
		else
			head.fs:Hide()
		end
	end
	for index = 1, math.max(#lines, #S.rows) do
		if index <= #lines then
			local row, y = Row(index), top - rowHeight * index
			At(row.label, "TOPLEFT", PAD_X, y, nameWidth + 2, rowHeight)
			for column, cell in ipairs(row.cells) do
				if column <= #columns then
					At(cell, "TOPRIGHT", rights[column], y, widths[column], rowHeight)
				else
					cell.fs:Hide()
				end
			end
		else
			local row = S.rows[index]
			row.label.fs:Hide()
			for _, cell in ipairs(row.cells) do
				cell.fs:Hide()
			end
		end
	end
	frame:SetSize(width, 2 * PAD_Y + rowHeight * (2 + #lines))
	S.laid = key
end

-- Writes the title, the headings and the cells.
local function Fill(columns, lines, title, note)
	Put(S.title, title, DIM)
	Put(S.note, note, DIM)
	for index, column in ipairs(columns) do
		Put(S.heads[index], column[2], DIM)
	end
	for index, line in ipairs(lines) do
		local row = S.rows[index]
		Put(row.label, line.label, DIM)
		for column, spec in ipairs(columns) do
			Put(row.cells[column], Value(line, spec[1]))
		end
	end
end

-- True while Show lets the table show: always, in combat, or with an enemy targeted, one that can be attacked and is alive (as the Threat list
-- tells an enemy, Threat.lua, T.Enemy, without leaving out players, since a duel's foe can be attacked).
local function Allowed()
	local rule = Opt("hitTableShow")
	if rule == "always" then
		return true
	elseif rule == "combat" then
		return S.fighting
	end
	return Ask(UnitExists, "target") == true and Ask(UnitCanAttack, "player", "target") == true and not S.dead
end

-- Works the table out and draws it. A rule that hides it sets its opacity to 0 and leaves it laid out, so the movers find its box; while it is
-- hidden so the numbers wait, once it has been laid out, and the next event that shows it works them out. A refresh (force) lays it out all the
-- same, so its box follows a changed row.
Update = function(force)
	S.dirty = false
	local calc = ns.HitTableCalc
	if not (S.frame and Wanted()) or type(calc) ~= "table" or type(calc.Read) ~= "function" then
		return
	end
	S.dead = Ask(UnitIsDeadOrGhost, "target") == true
	local allowed = Allowed()
	if not allowed and S.laid and not force then
		S.frame:SetAlpha(0)
		return
	end
	local read = calc.Read({ lines = Opt("hitTableLines"), special = Opt("hitTableSpecial") ~= false, against = Opt("hitTableAgainst"),
		facing = Opt("hitTableFacing"), rules = Opt("hitTableRules") })
	S.read = read
	Font()
	local lines = read.lines
	local columns, title, note = Columns(lines), Title(read), Note(read)
	Layout(columns, lines, title, note)
	Fill(columns, lines, title, note)
	S.frame:SetAlpha(allowed and #lines > 0 and 1 or 0)
end

-- Events ---------------------------------------------------------------------------------------------------------------------------------------------

-- The OnUpdate of the ear: once, on the frame after the events of a burst.
local function Tick(ear)
	ear:SetScript("OnUpdate", nil)
	S.dirty = false
	Safe(Update)
end

-- Marks the table to be worked out again on the next frame.
local function Dirty()
	if S.dirty then
		return
	end
	S.dirty = true
	local ear = S.ear
	if not (ear and pcall(ear.SetScript, ear, "OnUpdate", Tick)) then
		S.dirty = false
		Update()
	end
end

local function OnEvent(event, unit)
	local units = S.units[event]
	if units then
		-- A unit event registered for its units alone is theirs whatever its token says: the game may withhold the payload, the token with it
		-- (UNIT_AURA, UnitAuraDocumentation.lua:644-655), so it is not read. One heard for every unit, on a client that cannot hear one, counts
		-- for its own units, and when the token is withheld.
		if not S.alone[event] and not IsSecret(unit) and not (type(unit) == "string" and units[unit]) then
			return
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		S.fighting = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		S.fighting = false
	end
	if PLACE_EVENTS[event] then
		S.placed = nil
		Place()
	end
	Dirty()
end

-- Registers a unit event for its units alone where the client can, else for every unit (OnEvent keeps its own), as UnitDruidMana.lua hears the
-- player's power.
local function HearUnit(ear, event, ...)
	local units = {}
	for index = 1, select("#", ...) do
		units[select(index, ...)] = true
	end
	S.units[event] = units
	local ok, done = false, nil
	if type(ear.RegisterUnitEvent) == "function" then
		ok, done = pcall(ear.RegisterUnitEvent, ear, event, ...)
	end
	S.alone[event] = ok and (IsSecret(done) or done ~= false)
	if not S.alone[event] then
		pcall(ear.RegisterEvent, ear, event)
	end
end

-- The frame that hears the events, and only while the table is wanted.
local function Hear(on)
	if S.hearing == on then
		return
	end
	local ear = S.ear
	if not ear then
		if not on then
			return
		end
		ear = CreateFrame("Frame")
		ns.Own[ear] = true
		ear:SetScript("OnEvent", function(_, event, ...)
			-- The target's health comes many times a second in a fight and counts only when the target dies or comes back, so the rest stops
			-- here.
			if event == "UNIT_HEALTH" and (Ask(UnitIsDeadOrGhost, "target") == true) == S.dead then
				return
			end
			Safe(OnEvent, event, ...)
		end)
		S.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	pcall(ear.SetScript, ear, "OnUpdate", nil)
	S.hearing, S.dirty = false, false
	if not on then
		return
	end
	for _, event in ipairs(PLAYER_EVENTS) do
		HearUnit(ear, event, "player")
	end
	HearUnit(ear, "UNIT_LEVEL", "player", "target")
	for _, event in ipairs(TARGET_EVENTS) do
		HearUnit(ear, event, "target")
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
	S.hearing = true
end

-- The part -------------------------------------------------------------------------------------------------------------------------------------------

-- Off, or stopped: the table hides and nothing is heard.
Off = function()
	Hear(false)
	S.dirty, S.read = false, nil
	if S.frame then
		S.frame:Hide()
	end
end

-- The table, the rail and the texts, made the first time the table is wanted.
local function Build()
	if S.frame then
		return
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(false)
	frame:SetSize(1, 1)
	frame:Hide()
	local rail = CreateFrame("Frame", nil, UIParent)
	ns.Own[rail] = true
	local outline = ns.Outline(frame, frame, true)
	local title, note, probe = Text(frame, "LEFT"), Text(frame, "RIGHT"), Text(frame, "LEFT")
	probe.fs:SetAlpha(0)
	local heads = {}
	for index = 1, #COLUMNS do
		heads[index] = Text(frame, "RIGHT")
	end
	S.frame, S.rail, S.outline, S.title, S.note, S.probe, S.heads = frame, rail, outline, title, note, probe, heads
end

-- The cast bar's lock changed, the unit frames were refreshed, or the movers set or put back the spot: the table is placed again, out of combat.
local function Moved()
	if S.frame and Wanted() then
		S.placed = nil
		Safe(Place)
	end
end

-- Follows the two functions in which Edit Mode locks the cast bar to the player frame and frees it (Shared/PlayerFrame.lua:34-63), once.
local function Hook()
	if S.hooked then
		return
	end
	S.hooked = true
	ns.FollowGlobal("PlayerFrame_AttachCastBar", Moved)
	ns.FollowGlobal("PlayerFrame_DetachCastBar", Moved)
end

local function Apply()
	if not Wanted() then
		Off()
		return
	end
	Build()
	Hook()
	Hear(true)
	S.fighting = InFight()
	local back = Opt("hitTableBack") ~= false
	ns.SetOutline(S.outline, back, back)
	S.frame:Show()
	Update(true)
	Place()
end

-- Hud.lua calls this in every refresh of the module: a changed row, the page, the profile, the module stopped. Once the part has stopped on errors,
-- the table hides.
function ns.HitTableRefresh()
	if not ns.PartStopped(KEY, PART) then
		Safe(Apply)
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Off)
	end
end

-- The movers: the table is its handle's box and the frame the handle hangs from, while it is wanted and laid out, also while Show hides it.
function ns.HitTableRow()
	if S.frame and S.laid and Wanted() then
		return { S.frame }, S.frame
	end
	return {}
end

function ns.HitTableMoved()
	Moved()
end

-- A refresh of the unit frames can change what the player frame draws under the bars: the table is placed again after it (the steps after a refresh
-- are run inside the unit frames' own part guard; Moved runs its work in this part's).
local X = ns.UnitFrameExtra
if type(X) == "table" and type(X.after) == "table" and type(X.after.refresh) == "table" then
	table.insert(X.after.refresh, { part = PART, fn = Moved })
end

-- Status ---------------------------------------------------------------------------------------------------------------------------------------------

-- Names as a sentence lists them: a, a and b, a, b and c.
local function Join(list)
	if #list <= 1 then
		return list[1] or ""
	end
	return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

ns.AddStatus(KEY, function()
	local lines = {}
	if not Wanted() then
		return lines
	end
	if S.later then
		lines[#lines + 1] = LINE_WAITS
	elseif S.where and LINE_WHERE[S.where] then
		lines[#lines + 1] = LINE_WHERE[S.where]
	end
	if S.sansRefused then
		lines[#lines + 1] = LINE_SANS
	end
	local read = S.read
	if not read then
		return lines
	end
	if not read.level then
		lines[#lines + 1] = LINE_NO_LEVEL
		return lines
	end
	local unknown = {}
	for _, line in ipairs(read.lines) do
		for _, column in ipairs(COLUMNS) do
			if line.parts[column[1]] == nil then
				unknown[#unknown + 1] = line.label
				break
			end
		end
	end
	for _, why in ipairs({ "withheld", "refused", "missing" }) do
		local names = {}
		for _, what in ipairs({ "hit", "crit", "expertise" }) do
			if read.gaps[what] == why then
				names[#names + 1] = what
			end
		end
		if #names > 0 and #unknown > 0 then
			lines[#lines + 1] = LINE_GAP[why]:format(Join(names), Join(unknown))
		end
	end
	for _, hand in ipairs(read.assumed) do
		lines[#lines + 1] = LINE_ASSUMED:format(hand, read.level * PER_LEVEL)
	end
	local target = read.target
	if target and target.unknown then
		lines[#lines + 1] = LINE_UNKNOWN:format(target.level)
	end
	if target and target.player then
		lines[#lines + 1] = LINE_PLAYER
	end
	if read.noRanged then
		lines[#lines + 1] = LINE_NO_RANGED
	elseif read.rangedUnknown then
		lines[#lines + 1] = LINE_RANGED_UNKNOWN
	end
	if #read.lines == 0 then
		lines[#lines + 1] = LINE_EMPTY
	end
	return lines
end)
