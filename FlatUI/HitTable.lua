local ADDON_NAME, ns = ...

local KEY, PART = "hud", "hit table"
local MOVER = "FlatUIHitTable"
local SANS = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\IBMPlexSans-Regular.ttf"
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local FONT = "GameFontHighlightSmall"
local BASE, PAD_X, PAD_Y, COLUMN_GAP, NAME_GAP, TITLE_GAP = 11, 6, 4, 6, 8, 12
local GAP = 4
local SMALLEST = 1
local PET_BELOW = 42 + 15 - 49
local PET_AURAS = PET_BELOW + 1
local PET_WAIT = 0.3
local SHARE = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local PET_CLASSES = { HUNTER = true, WARLOCK = true }
local COOLDOWN_ROWS = { { "CooldownRow", "cooldowns.place", "FlatUICooldowns" }, { "CooldownRow2", "cooldowns.row2Place", "FlatUICooldowns2" },
	{ "CooldownRow3", "cooldowns.row3Place", "FlatUICooldowns3" }, { "CooldownRow4", "cooldowns.row4Place", "FlatUICooldowns4" } }
local BESIDE = { { "TargetFrame", "target frame" }, { "FocusFrame", "focus frame" } }
local SMALLEST_TEXT, FIT_STEP, MEASURED = 0.5, 0.05, 8
local PER_LEVEL = 5
local DIM, FAINT, PLAIN = { 0.66, 0.68, 0.62 }, { 0.48, 0.50, 0.45 }, { 1, 1, 1 }
local OK, WARN = { 0.49, 0.80, 0.56 }, { 0.90, 0.72, 0.36 }
local COLUMNS = { { "miss", "Miss" }, { "dodge", "Dodge" }, { "parry", "Parry" }, { "glance", "Glance" }, { "block", "Block" }, { "crit", "Crit" },
	{ "hit", "Hit" }, { "cap", "Cap" }, { "resist", "Resist" } }
local WIDEST = "100.0"
local FLOORED = { miss = true, dodge = true, parry = true }
local KIND_WORDS = { boss = "boss", elite = "elite", rare = "rare", rareelite = "rare elite" }
local PLAYER_EVENTS = { "UNIT_STATS", "UNIT_ATTACK", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
	"UNIT_DISPLAYPOWER", "UNIT_THREAT_SITUATION_UPDATE" }
local TARGET_EVENTS = { "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_TARGET", "UNIT_HEALTH", "UNIT_THREAT_LIST_UPDATE" }
local FACING_EVENTS = { UNIT_THREAT_SITUATION_UPDATE = true, UNIT_THREAT_LIST_UPDATE = true, UNIT_TARGET = true }
local EVENTS = { "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "WEAPON_ENCHANT_CHANGED",
	"SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM",
	"PLAYER_TARGET_CHANGED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
	"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED" }
local PLACE_EVENTS = { PLAYER_ENTERING_WORLD = true, UI_SCALE_CHANGED = true, DISPLAY_SIZE_CHANGED = true, EDIT_MODE_LAYOUTS_UPDATED = true }
local ROLE_EVENTS = { "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
	"TRAIT_TREE_CURRENCY_INFO_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED",
	"PLAYER_LEVEL_UP", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }
local ROLE_WORDS = { tank = "a tank", healer = "a healer", damage = "a damage dealer" }
local LINE_WHERE = {
	container = "Hit table: under the player frame.",
	frame = "Hit table: under the player frame.",
	["cast bar"] = "Hit table: under the cast bar, which Edit Mode locks to the player frame.",
	spot = "Hit table: at the spot set with the movers.",
	screen = "Hit table: the player frame cannot be used, so the table is under the middle of the screen.",
}
local LINE_WAITS = "Hit table: a change of place waits for the end of the fight."
local LINE_PET = "Hit table: lowered under the pet frame, or test mode's sample of it, which it would run into."
local LINE_SANS = "Hit table: the game did not load Flat UI Sans, so the table uses the game font."
local LINE_GAP = {
	withheld = "Hit table: the game withholds your %s in a fight and has not given them out of one since you logged in or reloaded, so parts of %s show a dash.",
	refused = "Hit table: the game refused your %s, so parts of %s show a dash.",
	missing = "Hit table: this client gives no %s, so parts of %s show a dash.",
}
local LINE_OLD = "Hit table: the game withholds your stats in a fight, so the numbers are the last it gave out of one%s."
local LINE_OLD_FORM = ", in another stance or form"
local TIP = { title = "Hit table", percent = "Your chances in percent against the enemy the title names. A swing's parts come from one roll and add up to 100; on the other lines Crit is the chance on an attack that lands.",
	cap = "Cap: the most your swings can crit, what misses, dodges, parries, glances and blocks leave; yellow once your crit is past it.",
	none = "A dark dash: the attack cannot have it, as a parry from behind.", unknown = "A light dash: a number the game does not give, as said below." }
local LINE_ASSUMED = "Hit table: the game gave no weapon skill for your %s, so it counts %d, the most for your level."
local LINE_UNKNOWN = "Hit table: your target's level shows as ??, so it counts as level %d."
local LINE_PLAYER = "Hit table: against a player, dodge, parry and block start at 5%, since the game does not give theirs."
local LINE_NO_RANGED = "Hit table: no ranged line, since you wear no bow, gun, crossbow, thrown weapon or wand."
local LINE_RANGED_UNKNOWN = "Hit table: no ranged line, since the game did not say what your ranged slot holds."
local LINE_EMPTY = "Hit table: hidden, with no line to show."
local LINE_NO_LEVEL = "Hit table: hidden, since the game does not give your level."
local LINE_FACING = "Hit table: the game did not say whether your target attacks you, so the table counts you behind it."
local LINE_OFF_CRIT = "Hit table: the game gives one crit chance, your main hand's, so crit talents for one kind of weapon may make your off hand's crit differ."
local LINE_RESIST = "Hit table: Resist is the share of a spell's damage resisted on average, with your Spell Piercing %d. The enemy's own resistances are not known and count as none, so below 0 it is the damage a creature takes more from your piercing (Spell Vulnerability); against a player piercing does nothing below 0. Piercing of one school, as Fire Piercing, counts only in the gear comparison and the Expected line of a spell's tooltip, not here."
local LINE_RESIST_LEVEL = "Hit table: Resist counts %s%% for the levels the enemy is above you, Classic's rule and an estimate on WoW: Forever; piercing does not lower it. A spell with an effect beyond its damage, as a slow, takes no such share but pays for the levels with its higher miss, and the gear comparison leaves the share out."
local LINE_FIT = "Hit table: the text is %d%% of Text size, so the table ends before the %s. /flatui move places it elsewhere."
local LINE_ROLE = "Hit table: %s, since you count as %s."
local LINE_ROLE_BY = "Hit table: %s, since you count as %s (%s)."

local IsSecret, Finite = ns.IsSecret, ns.Finite

local S = { heads = {}, rows = {}, widths = {}, measures = {}, measured = 0, units = {}, alone = {}, hearing = false, fighting = false, dirty = false,
	later = false, recheck = false, stepped = false, petWaits = false, kept = {} }
local Update, Later, Off, Dirty, Apply, Explain

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

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

local function Choice()
	local value = Opt("hitTable")
	if value == true or value == "on" then
		return "on"
	elseif value == false or value == "off" then
		return "off"
	end
	return "role"
end

local function WorkOutRole()
	local role, by
	if type(ns.PlayerRole) == "function" then
		local _
		role, _, by = ns.PlayerRole()
	end
	S.role = (role == "tank" or role == "healer") and role or "damage"
	S.by = type(by) == "string" and by or nil
end

local function Shows()
	local choice = Choice()
	if choice == "role" then
		if S.role == nil then
			WorkOutRole()
		end
		return S.role ~= "healer"
	end
	return choice == "on"
end

local function Wanted()
	return ns.Enabled(KEY) and Shows() and not ns.PartStopped(KEY, PART)
end

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

local function InFight()
	local value = Ask(UnitAffectingCombat, "player")
	if type(value) == "boolean" then
		return value
	end
	return Ask(InCombatLockdown) == true
end

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

local function Laid(region)
	if region == nil or IsSecret(region) or type(region) ~= "table" then
		return false
	end
	local ok, left = pcall(function()
		return region:GetLeft()
	end)
	return ok and Finite(left)
end

local function Shown(region)
	if region == nil or IsSecret(region) or type(region) ~= "table" then
		return false
	end
	local ok, shown = pcall(function()
		return region:IsShown()
	end)
	return ok and not IsSecret(shown) and shown == true
end

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

local function Record()
	local X = ns.UnitFrameExtra
	if type(X) ~= "table" or type(X.known) ~= "function" then
		return nil, X
	end
	return X.known(_G.PlayerFrame), X
end

local function Picture(rec, X)
	local pic = type(rec.pic) == "table" and rec.pic or nil
	if pic and pic.drawn == true and type(X.active) == "function" and X.active(rec) == true and Laid(pic.frame) then
		return pic.frame
	end
	return nil
end

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
		local picture = Picture(rec, X)
		if picture then
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

local function OwnSpot(name)
	return type(ns.MoverSaved) == "function" and ns.MoverSaved(name) == true
end

local function Lowest(border)
	local low
	local function Take(region)
		local bottom = Edge(region, "GetBottom")
		if bottom then
			low = math.min(low or bottom - border, bottom - border)
		end
	end
	local rec, X = Record()
	if rec then
		if type(X.active) == "function" and X.active(rec) == true then
			if type(X.joined) == "function" and X.joined(rec) == true and type(X.body) == "function" then
				Take(X.body(rec))
			else
				local roles = type(rec.byRole) == "table" and rec.byRole or {}
				Take(type(roles.power) == "table" and roles.power.target or nil)
				Take(type(roles.health) == "table" and roles.health.target or nil)
				Take(Picture(rec, X))
			end
		end
		local mana = rec.druidMana
		if type(mana) == "table" and mana.holder ~= nil and ns.Enabled("unitframes") and ns.Get("unitframes.druidMana") == true then
			Take(mana.holder)
		end
	end
	for _, row in ipairs(COOLDOWN_ROWS) do
		local icons = ns[row[1]]
		if type(icons) == "function" and ns.Get(row[2]) == "player" and not OwnSpot(row[3]) then
			local ok, list = pcall(icons)
			if ok and type(list) == "table" then
				for _, icon in ipairs(list) do
					Take(icon)
				end
			end
		end
	end
	return low
end

local function PetAuras()
	local pet = _G.PetFrame
	if ns.Forbidden(pet) then
		return 0
	end
	local ok, _, class = pcall(UnitClass, "player")
	if not (ok and not IsSecret(class) and type(class) == "string" and PET_CLASSES[class]) and not Shown(pet) then
		return 0
	end
	return PET_AURAS * Scale(pet)
end

local function PetRect()
	local pet = _G.PetFrame
	if ns.Forbidden(pet) then
		return nil
	end
	local mode = ns.TestMode
	if not Shown(pet) and not (type(mode) == "table" and type(mode.Shown) == "function" and mode.Shown("pet") == true) then
		return nil
	end
	local left, right, top, bottom = Edge(pet, "GetLeft"), Edge(pet, "GetRight"), Edge(pet, "GetTop"), Edge(pet, "GetBottom")
	if not (left and right and top and bottom) then
		return nil
	end
	return left, right, top, bottom - PET_BELOW * Scale(pet)
end

local function Border()
	if Opt("hitTableBack") == false then
		return 0
	end
	local frame = S.frame
	return (tonumber(ns.Get("general.thickness")) or 1) * ns.Pixels(frame, 1) * Scale(frame)
end

local function PetStep(left, right, top, height)
	local petLeft, petRight, petTop, petLow = PetRect()
	if not petLeft or left >= petRight or right <= petLeft or top <= petLow or top - height >= petTop then
		return 0
	end
	return top - petLow + GAP * Scale(S.frame)
end

local function TextBelow(bar)
	if not (ns.Enabled("castbars") and not ns.PartStopped("castbars", "size") and ns.Get("castbars.playerSize") == true
		and ns.Get("castbars.playerText") == "below") then
		return 0
	end
	local text, height = Path(bar, "Text"), nil
	if text ~= nil then
		local ok, _, size = pcall(function()
			return text:GetFont()
		end)
		height = ok and Finite(size) and size > 0 and size or nil
	end
	return math.max(0, (height or BASE) - 1) * Scale(bar)
end

local function Offset(anchor, kind)
	local frame = S.frame
	local scale = Scale(frame)
	local pixel = ns.Pixels(frame, 1) * scale
	local thickness = tonumber(ns.Get("general.thickness")) or 1
	local below = 0
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
		below = math.max(0, bottom - low)
	end
	if kind == "container" then
		below = math.max(below, PetAuras())
	elseif kind == "cast bar" then
		below = math.max(below, TextBelow(anchor))
	end
	return (GAP * scale + (Opt("hitTableBack") ~= false and thickness * pixel or 0) + below) / scale
end

local function SetRoom(room, by)
	if room ~= S.room or by ~= S.roomBy then
		S.room, S.roomBy = room, by
		Dirty()
	end
end

local function NaturalHeight()
	local size = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	local lines = type(S.read) == "table" and #S.read.lines or 0
	return 2 * PAD_Y + math.ceil(size + 3) * (2 + math.max(1, lines))
end

local function Room(edge, anchor, offset)
	local scale = Scale(S.frame)
	local left = Edge(edge, "GetLeft")
	if not left then
		SetRoom(nil, nil)
		return
	end
	local limit, by = Edge(UIParent, "GetRight"), "edge of the screen"
	local top, bottom = Edge(_G.PlayerFrame, "GetTop"), Edge(anchor, "GetBottom")
	local lowest = bottom and bottom - (offset + NaturalHeight()) * scale or nil
	for _, entry in ipairs(BESIDE) do
		local other = _G[entry[1]]
		if not ns.Forbidden(other) then
			local otherLeft, otherTop, otherBottom = Edge(other, "GetLeft"), Edge(other, "GetTop"), Edge(other, "GetBottom")
			if otherLeft and otherTop and otherBottom and otherLeft > left + GAP * scale and (top == nil or otherBottom < top)
				and (lowest == nil or otherTop > lowest) and (limit == nil or otherLeft < limit) then
				limit, by = otherLeft, entry[2]
			end
		end
	end
	if limit then
		SetRoom(math.floor(math.max(0, limit - left - GAP * scale) / scale), by)
	else
		SetRoom(nil, nil)
	end
end

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
	local scale, border = Scale(frame), Border()
	local width, height = frame:GetWidth() * scale, frame:GetHeight() * scale
	if x then
		local share = SHARE[point] or SHARE.TOPLEFT
		local left, top = x * scale - width * share[1], y * scale + height * (1 - share[2])
		local step = PetStep(left - border, left + width + border, top + border, height + 2 * border) / scale
		S.stepped = step > 0
		y = y - step
		local key = ("spot:%s:%.2f:%.2f"):format(point, x, y)
		if S.placed ~= key then
			frame:ClearAllPoints()
			frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
			S.placed, S.edge, S.anchor = key, nil, nil
		end
		S.where = "spot"
		SetRoom(nil, nil)
		return
	end
	local anchor, kind = Anchor()
	local edge = anchor and LeftEdge() or nil
	if anchor and edge then
		local offset = Offset(anchor, kind)
		local bottom, left = Edge(anchor, "GetBottom"), Edge(edge, "GetLeft")
		local step = bottom and left and PetStep(left - border, left + width + border, bottom - offset * scale + border, height + 2 * border) / scale or 0
		S.stepped = step > 0
		offset = offset + step
		Room(edge, anchor, offset)
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
	S.where, S.stepped = "screen", false
	SetRoom(nil, nil)
end

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

local function Covers()
	if ns.FontsLatin == nil or ns.FontsLatin() then
		return true
	end
	return Ask(GetLocale) == "ruRU"
end

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

local function Font(fit)
	local size = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	if fit and fit < 1 then
		size = math.max(BASE * SMALLEST_TEXT, size * fit)
	end
	local file = Opt("hitTableFont") == "sans" and Covers() and SANS or nil
	local key = ("%s:%.2f"):format(file or "game", size)
	if S.fontKey == key then
		return
	end
	local widths = S.measures[key]
	if not widths then
		if S.measured >= MEASURED then
			S.measures, S.measured = {}, 0
		end
		widths = {}
		S.measures[key], S.measured = widths, S.measured + 1
	end
	if S.file ~= file then
		S.sansRefused = false
	end
	S.fontKey, S.file, S.size, S.widths = key, file, size, widths
end

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

local function Text(parent, justify)
	local fs = ns.OwnText(parent, "OVERLAY", FONT)
	fs:SetJustifyH(justify)
	fs:SetJustifyV("MIDDLE")
	fs:SetWordWrap(false)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	return { fs = fs }
end

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

local function At(text, point, x, y, width, height)
	local fs = text.fs
	fs:ClearAllPoints()
	fs:SetPoint(point, S.frame, "TOPLEFT", x, y)
	fs:SetSize(width, height)
	fs:Show()
end

local function Columns(lines, widest)
	local list = {}
	for _, column in ipairs(COLUMNS) do
		local key = column[1]
		for _, line in ipairs(lines) do
			local parts = line.parts
			if parts[key] ~= false or (widest and line.skill and (key == "block" or (key == "parry" and parts.dodge ~= false))) then
				list[#list + 1] = column
				break
			end
		end
	end
	return list
end

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
		text = (target.unknown and "Target level ?? (%d)" or "Target level %d"):format(target.level) .. (kind and (" " .. kind) or "")
	end
	for _, line in ipairs(read.lines) do
		if line.skill then
			return text .. (read.front and ", in front" or ", behind")
		end
	end
	return text
end

local function Note(read)
	local skills = {}
	for _, line in ipairs(read.lines) do
		if line.skill and line.id ~= "special" then
			skills[#skills + 1] = ("%d"):format(math.floor(line.skill + 0.5))
		end
	end
	return #skills > 0 and ("Skill " .. table.concat(skills, " / ")) or ""
end

local function Value(line, key)
	local value = line.parts[key]
	if value == false then
		return "-", FAINT
	elseif value == nil then
		return "-", DIM
	end
	local colour = PLAIN
	if line.over and (key == "crit" or key == "cap") then
		colour = WARN
	elseif FLOORED[key] and value < (key == "miss" and line.floor or 0) + 0.05 then
		colour = OK
	elseif key == "resist" and value <= -0.05 then
		colour = OK
	end
	if math.abs(value) < 0.05 then
		value = 0
	end
	return ("%.1f"):format(value), colour
end

local function Units(units, k)
	return math.max(1, math.floor(units * k + 0.5))
end

local function Geometry(columns, lines, title, note, k)
	local g = { rowHeight = math.ceil(S.size + 3), padX = Units(PAD_X, k), padY = Units(PAD_Y, k), widths = {}, rights = {}, ids = {} }
	local nameWidth = 0
	for _, line in ipairs(lines) do
		nameWidth = math.max(nameWidth, Measure(line.label))
	end
	g.nameWidth = math.ceil(nameWidth)
	local number, gap = Measure(WIDEST), Units(COLUMN_GAP, k)
	local x = g.padX + g.nameWidth + Units(NAME_GAP, k)
	for index, column in ipairs(columns) do
		g.widths[index] = math.ceil(math.max(number, Measure(column[2])))
		x = x + g.widths[index]
		g.rights[index] = x
		x = x + gap
		g.ids[index] = column[1]
	end
	g.noteWidth = note ~= "" and math.ceil(Measure(note)) + 2 or 0
	g.besideNote = g.noteWidth > 0 and g.noteWidth + Units(TITLE_GAP, k) or 0
	g.content = (#columns > 0 and g.rights[#columns] or g.padX + g.nameWidth) + g.padX
	g.width = math.max(g.content, g.padX + math.ceil(Measure(title)) + g.besideNote + g.padX)
	return g
end

local function Fit(lines)
	local room = S.room
	if not room then
		return 1
	end
	local widest = Columns(lines, Opt("hitTableFacing") == "auto")
	Font(1)
	local natural = Geometry(widest, lines, "", "", 1).content
	if natural <= room then
		return 1
	end
	local fit = math.max(FIT_STEP, math.floor(room / natural / FIT_STEP) * FIT_STEP)
	while fit > FIT_STEP do
		Font(fit)
		if S.size <= BASE * SMALLEST_TEXT or Geometry(widest, lines, "", "", fit).content <= room then
			break
		end
		fit = fit - FIT_STEP
	end
	return fit
end

local function Layout(g, lines)
	local names = {}
	for index, line in ipairs(lines) do
		names[index] = line.label
	end
	local width, rowHeight, padX, padY = g.width, g.rowHeight, g.padX, g.padY
	local key = table.concat({ S.fontKey, table.concat(g.ids, ","), table.concat(names, ","), width, g.noteWidth, padX, padY }, ":")
	if S.laid == key then
		return
	end
	At(S.note, "TOPRIGHT", width - padX, -padY, math.max(1, g.noteWidth), rowHeight)
	At(S.title, "TOPLEFT", padX, -padY, math.max(1, width - 2 * padX - g.besideNote), rowHeight)
	local top = -(padY + rowHeight)
	for index, head in ipairs(S.heads) do
		if index <= #g.ids then
			At(head, "TOPRIGHT", g.rights[index], top, g.widths[index], rowHeight)
		else
			head.fs:Hide()
		end
	end
	for index = 1, math.max(#lines, #S.rows) do
		if index <= #lines then
			local row, y = Row(index), top - rowHeight * index
			At(row.label, "TOPLEFT", padX, y, g.nameWidth + 2, rowHeight)
			for column, cell in ipairs(row.cells) do
				if column <= #g.ids then
					At(cell, "TOPRIGHT", g.rights[column], y, g.widths[column], rowHeight)
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
	S.frame:SetSize(width, 2 * padY + rowHeight * (2 + #lines))
	S.laid = key
	if S.where and (S.stepped or PetRect()) then
		Place()
	end
end

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

local function Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
end

local function Allowed()
	local rule = Opt("hitTableShow")
	if rule == "always" or Testing() then
		return true
	elseif rule == "combat" then
		return S.fighting
	end
	return Ask(UnitExists, "target") == true and Ask(UnitCanAttack, "player", "target") == true and not S.dead
end

local FADE = { 0.15, 0.35 }

local function Fades(frame)
	local ok, come, go = pcall(function()
		local fadeIn = frame:CreateAnimationGroup()
		local rise = fadeIn:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(FADE[1])
		local fadeOut = frame:CreateAnimationGroup()
		local fall = fadeOut:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE[2])
		pcall(fadeOut.SetToFinalAlpha, fadeOut, true)
		fadeOut:SetScript("OnFinished", function()
			frame:SetAlpha(0)
		end)
		return fadeIn, fadeOut
	end)
	if ok then
		return come, go
	end
	return nil, nil
end

local function Owned()
	local tip = GameTooltip
	if not S.frame or ns.Forbidden(tip) then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, S.frame)
	return ok and not IsSecret(owned) and owned == true
end

local function Untip()
	if S.tipped and Owned() then
		pcall(GameTooltip.Hide, GameTooltip)
	end
	S.tipped = false
end

local function Bare(text)
	local plain = text:gsub("^Hit table: ", "")
	plain = plain:gsub("^%l", string.upper)
	return plain
end

local function Tip()
	local tip, read = GameTooltip, S.read
	if ns.Forbidden(tip) or S.visible ~= true or type(read) ~= "table" or type(read.lines) ~= "table" then
		return
	end
	local cap, none, unknown = false, false, false
	for _, column in ipairs(Columns(read.lines)) do
		cap = cap or column[1] == "cap"
		for _, line in ipairs(read.lines) do
			local value = line.parts[column[1]]
			none, unknown = none or value == false, unknown or value == nil
		end
	end
	tip:SetOwner(S.frame, "ANCHOR_BOTTOM")
	tip:AddLine(TIP.title, 1, 1, 1)
	tip:AddLine(TIP.percent, DIM[1], DIM[2], DIM[3], true)
	if cap then
		tip:AddLine(TIP.cap, DIM[1], DIM[2], DIM[3], true)
	end
	if none then
		tip:AddLine(TIP.none, DIM[1], DIM[2], DIM[3], true)
	end
	if unknown then
		tip:AddLine(TIP.unknown, DIM[1], DIM[2], DIM[3], true)
	end
	for _, text in ipairs(Explain(read, {})) do
		tip:AddLine(Bare(text), DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
	S.tipped = true
end

local function Guarded(frame)
	if Ask(InCombatLockdown) ~= true then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or IsSecret(protected) or protected == true
end

local function Hover()
	local frame = S.frame
	local want = S.visible == true and Opt("hitTableHover") ~= false
	if frame and S.motion ~= want then
		if Guarded(frame) then
			if not S.hoverWaits then
				S.hoverWaits = true
				ns.OutOfCombat(function()
					S.hoverWaits = false
					Safe(Hover)
				end)
			end
		else
			pcall(frame.SetMouseClickEnabled, frame, false)
			if pcall(frame.SetMouseMotionEnabled, frame, want) then
				S.motion = want
			end
		end
	end
	if not want then
		Untip()
	end
end

local function Visible(on, now)
	local frame, come, go = S.frame, S.fadeIn, S.fadeOut
	local fading = go ~= nil and go:IsPlaying()
	if on then
		if fading then
			pcall(go.Stop, go)
		end
		if S.visible ~= true then
			frame:SetAlpha(1)
			if come and not now and not fading and S.visible == false then
				pcall(come.Play, come)
			end
		end
	else
		if come and come:IsPlaying() then
			pcall(come.Stop, come)
		end
		if now or not go or (S.visible ~= true and not fading) then
			if fading then
				pcall(go.Stop, go)
			end
			frame:SetAlpha(0)
		elseif not fading and not pcall(go.Play, go) then
			frame:SetAlpha(0)
		end
	end
	S.visible = on
	Hover()
end

Update = function(force)
	S.dirty = false
	local calc = ns.HitTableCalc
	if not (S.frame and Wanted()) or type(calc) ~= "table" or type(calc.Read) ~= "function" then
		return
	end
	S.dead = Ask(UnitIsDeadOrGhost, "target") == true
	local allowed = Allowed()
	if not allowed and S.laid and not force then
		if not S.fighting and type(calc.Keep) == "function" then
			calc.Keep(S.kept)
		end
		Visible(false)
		return
	end
	local against = Opt("hitTableAgainst")
	if against == "target" and Testing() and not (Ask(UnitExists, "target") == true and Ask(UnitCanAttack, "player", "target") == true and not S.dead) then
		against = "boss"
	end
	local read = calc.Read({ lines = Opt("hitTableLines"), special = Opt("hitTableSpecial") ~= false, against = against,
		facing = Opt("hitTableFacing"), rules = Opt("hitTableRules") }, S.kept)
	S.read = read
	local lines = read.lines
	local columns, title, note = Columns(lines), Title(read), Note(read)
	local fit = Fit(lines)
	Font(fit)
	local wanted = BASE * (tonumber(Opt("hitTableSize")) or 100) / 100
	S.fit = S.size < wanted - 0.005 and S.size / wanted or nil
	local g = Geometry(columns, lines, title, note, fit)
	if S.room and g.width > S.room then
		g.width = math.max(g.content, S.room)
	end
	Layout(g, lines)
	Fill(columns, lines, title, note)
	Visible(allowed and #lines > 0, force)
	if S.tipped then
		if Owned() then
			Tip()
		else
			S.tipped = false
		end
	end
end

local function Recheck()
	local was = Wanted()
	WorkOutRole()
	if Wanted() ~= was then
		Apply()
	else
		Update()
	end
end

local function Work()
	if S.recheck then
		S.recheck = false
		Recheck()
	else
		Update()
	end
end

local function Tick(ear)
	ear:SetScript("OnUpdate", nil)
	S.dirty = false
	Safe(Work)
end

Dirty = function()
	if S.dirty then
		return
	end
	S.dirty = true
	local ear = S.ear
	if not (ear and pcall(ear.SetScript, ear, "OnUpdate", Tick)) then
		S.dirty = false
		Work()
	end
end

local function PetSoon()
	if S.petWaits then
		return
	end
	S.petWaits = true
	local function Look()
		S.petWaits = false
		if S.frame and Wanted() then
			Safe(Place)
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(PET_WAIT, Look)
	else
		Look()
	end
end

local function OnEvent(event, unit)
	local units = S.units[event]
	if units then
		if not S.alone[event] and not IsSecret(unit) and not (type(unit) == "string" and units[unit]) then
			return
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		S.fighting = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		S.fighting = false
	end
	if event == "UNIT_PET" then
		PetSoon()
		return
	end
	if PLACE_EVENTS[event] then
		S.placed = nil
		Place()
	end
	Dirty()
end

local function FacingChanged()
	local read, calc = S.read, ns.HitTableCalc
	if type(read) ~= "table" or type(calc) ~= "table" or type(calc.Front) ~= "function" then
		return true
	elseif read.target == nil then
		return false
	end
	local ok, front, unsure = pcall(calc.Front, Opt("hitTableFacing"), read.target)
	return not ok or front ~= read.front or (unsure == true) ~= (read.facingUnsure == true)
end

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

local function Ear()
	if S.ear then
		return S.ear
	end
	local ear = CreateFrame("Frame")
	ns.Own[ear] = true
	ear:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_HEALTH" and (Ask(UnitIsDeadOrGhost, "target") == true) == S.dead then
			return
		end
		if FACING_EVENTS[event] and not FacingChanged() then
			return
		end
		Safe(OnEvent, event, ...)
	end)
	S.ear = ear
	return ear
end

local function Hear(on)
	if S.hearing == on or not (on or S.ear) then
		return
	end
	local ear = Ear()
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
	HearUnit(ear, "UNIT_PET", "player")
	for _, event in ipairs(TARGET_EVENTS) do
		HearUnit(ear, event, "target")
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
	S.hearing = true
end

Off = function()
	Hear(false)
	S.dirty, S.read = false, nil
	if S.frame then
		pcall(Untip)
		for _, fade in ipairs({ S.fadeIn, S.fadeOut }) do
			pcall(fade.Stop, fade)
		end
		S.frame:Hide()
		S.visible = nil
	end
end

local function Build()
	if S.frame then
		return
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(false)
	frame:SetScript("OnEnter", function()
		Safe(Tip)
	end)
	frame:SetScript("OnLeave", function()
		pcall(Untip)
	end)
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
	S.fadeIn, S.fadeOut = Fades(frame)
end

local function Moved()
	if S.frame and Wanted() then
		S.placed = nil
		Safe(Place)
	end
end

local function Hook()
	if S.hooked then
		return
	end
	S.hooked = true
	ns.FollowGlobal("PlayerFrame_AttachCastBar", Moved)
	ns.FollowGlobal("PlayerFrame_DetachCastBar", Moved)
end

Apply = function()
	if Choice() == "role" then
		WorkOutRole()
	end
	S.recheck = false
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

function ns.HitTableRefresh()
	if not ns.PartStopped(KEY, PART) then
		Safe(Apply)
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Off)
	end
end

function ns.HitTableRow()
	if S.frame and S.laid and Wanted() then
		return { S.frame }, S.frame
	end
	return {}
end

function ns.HitTableMoved()
	Moved()
end

local function RoleEvent()
	S.recheck = true
	Ear()
	Dirty()
end

local function ByRole()
	return Choice() == "role" and not ns.PartStopped(KEY, PART)
end

local function RoleHeard()
	Safe(RoleEvent)
end

for _, event in ipairs(ROLE_EVENTS) do
	ns.AddEvent(KEY, event, RoleHeard, ByRole)
end
ns.AddEvent(KEY, "UNIT_AURA", RoleHeard, function(unit)
	return not IsSecret(unit) and unit == "player" and ByRole()
end)

local X = ns.UnitFrameExtra
if type(X) == "table" and type(X.after) == "table" and type(X.after.refresh) == "table" then
	table.insert(X.after.refresh, { part = PART, fn = Moved })
end

local function Join(list)
	if #list <= 1 then
		return list[1] or ""
	end
	return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

ns.AddStatus(KEY, function()
	local lines = {}
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Choice() == "role" then
		local state = Shows() and "on" or "off"
		local word = ROLE_WORDS[S.role] or ROLE_WORDS.damage
		lines[#lines + 1] = S.by and LINE_ROLE_BY:format(state, word, S.by) or LINE_ROLE:format(state, word)
	end
	if not Wanted() then
		return lines
	end
	if S.later then
		lines[#lines + 1] = LINE_WAITS
	elseif S.where and LINE_WHERE[S.where] then
		lines[#lines + 1] = LINE_WHERE[S.where]
		if S.stepped then
			lines[#lines + 1] = LINE_PET
		end
	end
	if S.fit and S.room and S.roomBy then
		lines[#lines + 1] = LINE_FIT:format(math.floor(S.fit * 100 + 0.5), S.roomBy)
	end
	if S.sansRefused then
		lines[#lines + 1] = LINE_SANS
	end
	local read = S.read
	if not read then
		return lines
	end
	return Explain(read, lines)
end)

Explain = function(read, lines)
	if not read.level then
		lines[#lines + 1] = LINE_NO_LEVEL
		return lines
	end
	if read.old then
		lines[#lines + 1] = LINE_OLD:format(read.otherForm and LINE_OLD_FORM or "")
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
		for _, what in ipairs({ "hit", "crit", "expertise", "spell piercing" }) do
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
	for _, line in ipairs(read.lines) do
		if line.id == "spell" and line.pen ~= nil then
			lines[#lines + 1] = LINE_RESIST:format(math.floor(line.pen + 0.5))
			local calc = ns.HitTableCalc
			local level = line.levelResist and type(calc) == "table" and type(calc.Resist) == "function"
				and calc.Resist(read.level, read.target.level, false, 0) or nil
			if level then
				lines[#lines + 1] = LINE_RESIST_LEVEL:format((("%.1f"):format(level):gsub("%.0$", "")))
			end
		end
	end
	local target = read.target
	if target and target.unknown then
		lines[#lines + 1] = LINE_UNKNOWN:format(target.level)
	end
	if target and target.player then
		lines[#lines + 1] = LINE_PLAYER
	end
	if read.facingUnsure then
		lines[#lines + 1] = LINE_FACING
	end
	if read.offCritFromMain then
		lines[#lines + 1] = LINE_OFF_CRIT
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
end

if ns.TestMode then
	ns.TestMode.Register("hittable", { module = KEY, label = "Hit table", Start = ns.HitTableRefresh, Stop = ns.HitTableRefresh })
	if type(ns.TestMode.Watch) == "function" then
		ns.TestMode.Watch(function()
			Moved()
		end)
	end
end
