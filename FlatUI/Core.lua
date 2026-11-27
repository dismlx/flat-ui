local ADDON_NAME, ns = ...

local MODULE_ORDER = { "nameplates", "combattext", "actionbars", "resource", "ownbuffs", "swing", "castbars", "cooldowns", "trackers", "defensives", "absorbs", "partycd", "enemycd", "windows", "bags", "unitframes", "hud", "chat", "trinkets", "movers", "barblock", "blocks", "tooltip", "errands", "datapanels", "threat", "pulse", "healermana", "consumables", "consumebar", "mount", "grouptools", "pingbar", "fonts", "fade", "hide" }
local LEGACY_MODULES = { "nameplates", "actionbars", "resource", "swing", "castbars" }
local MAX_FAILURES = 5
local MAX_PART_FAILURES = 3
local MAX_BLOCKED = 5
local SETTINGS_VERSION = 2
local DEFAULT = "Default"
local MAX_NAME = 32
local RESET_SETTINGS = { "unitframes.squarePortrait", "unitframes.badges", "unitframes.strip", "unitframes.elite", "unitframes.status", "unitframes.lossFlash" }
local SETTLE = 0.2
local READERS = {
	["castbars.castColour"] = "hud", ["castbars.channelColour"] = "hud", ["castbars.craftColour"] = "hud",
	["windows.accent"] = { "chat", "bags" }, ["windows.panel"] = { "chat", "bags" }, ["windows.opacity"] = { "chat", "bags" },
	["windows.crop"] = { "chat", "bags" },
	["errands.sellTwelve"] = "bags",
	["barblock.background"] = "actionbars",
	["trackers.ammoMin"] = "datapanels", ["trackers.thrownMin"] = "datapanels",
	["cooldowns.place"] = "trackers", ["cooldowns.size"] = "trackers", ["cooldowns.spacing"] = "trackers", ["cooldowns.perRow"] = "trackers",
	["cooldowns.rows"] = "trackers",
	["defensives.own"] = "ownbuffs", ["defensives.enabled"] = "ownbuffs", ["defensives.place"] = "ownbuffs",
	["unitframes.numberStyle"] = "nameplates",
	["nameplates.threatRole"] = { "hud", "chat" },
	["hud.hitTableRules"] = "chat",
	["unitframes.lookOwn"] = "unitframes", ["unitframes.lookBorder"] = "unitframes", ["unitframes.lookBack"] = "unitframes",
	["unitframes.lookBackAlpha"] = "unitframes",
}

local db
local charDB
local current = DEFAULT
local profile
local values
local viewing
local characterKey
local defs = {}
local modules = {}
local status = {}
local outlines = setmetatable({}, { __mode = "k" })
local running
local AREAS = { nameplates = true, actionbars = true, unitframes = true, hud = true, chat = true }
local PREFIXES = { look = true, tip = true }
local SUFFIXES = { Own = true, Border = true, Back = true, BackAlpha = true }
local own = setmetatable({}, { __mode = "k" })
local afterCombat = {}
local blocked = {}
local blockedTotal, blockedLast = 0, nil
local loggedIn = false
local resizePending = false
local resetNotice = false
local settleCount = 0
local screenHeight

ns.MODULE_ORDER = MODULE_ORDER
ns.modules = modules
ns.Own = own

local function Define()
	for path in pairs(defs) do
		defs[path] = nil
	end
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			if item.key then
				local owner = item.page or page.owner or page.key
				item.path = owner .. "." .. item.key
				item.needsPath = item.needs and (owner .. "." .. item.needs) or nil
				defs[item.path] = item
			end
		end
	end
end
Define()

local function Unsaved(def)
	return def.live == true or def.cvar ~= nil or def.get ~= nil or def.set ~= nil
end
ns.RowUnsaved = Unsaved

function ns.RowLive(item)
	return item.live == true or item.cvar ~= nil
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end
ns.IsSecret = IsSecret

local function Finite(value)
	return not IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
ns.Finite = Finite

local function Forbidden(frame)
	if frame == nil or IsSecret(frame) or type(frame) ~= "table" then
		return true
	end
	local ok, usable = pcall(function()
		local forbidden = frame:IsForbidden()
		return not IsSecret(forbidden) and forbidden == false
	end)
	return not (ok and usable)
end
ns.Forbidden = Forbidden

local GOLD, SILVER, RED = { 1, 0.82, 0 }, { 0.78, 0.80, 0.84 }, { 1, 0.35, 0.24 }
ns.KINDS = {
	elite = { word = "Elite", mark = "+", colour = GOLD },
	rare = { word = "Rare", mark = "R", colour = SILVER },
	rareelite = { word = "Rare Elite", mark = "R+", colour = SILVER, inner = GOLD },
	boss = { word = "Boss", colour = RED },
}

local function Ask(fn, ...)
	if type(fn) == "function" then
		local ok, answer = pcall(fn, ...)
		if ok and not IsSecret(answer) then
			return answer
		end
	end
end

function ns.UnitKind(unit)
	if IsSecret(unit) or type(unit) ~= "string" then
		return nil
	end
	local class = Ask(UnitClassification, unit)
	if type(class) ~= "string" then
		return nil
	end
	if Ask(UnitIsBossMob, unit) == true or class == "worldboss" then
		return "boss"
	end
	if class == "elite" or class == "rare" or class == "rareelite" then
		return class
	end
	return nil
end

local ROLE_TREES = {
	WARRIOR = { "damage", "damage", "tank" }, PALADIN = { "healer", "tank", "damage" }, PRIEST = { "healer", "healer", "damage" },
	SHAMAN = { "damage", "damage", "healer" }, DRUID = { "damage", "damage", "healer" }, HUNTER = { "damage", "damage", "damage" },
	ROGUE = { "damage", "damage", "damage" }, MAGE = { "damage", "damage", "damage" }, WARLOCK = { "damage", "damage", "damage" },
}
local ROLE_GIVEN = { TANK = "tank", HEALER = "healer", DAMAGER = "damage" }

local function IsText(value)
	return not IsSecret(value) and type(value) == "string"
end

local function Index(t, key)
	return t[key]
end

local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Api(space, name)
	local fn = Field(_G[space], name)
	return type(fn) == "function" and fn or nil
end

local unstaged = {}

local function MostPoints(count)
	local config = Ask(Api("C_ClassTalents", "GetActiveConfigID"))
	if not Finite(config) then
		local group = Ask(Api("C_SpecializationInfo", "GetActiveSpecGroup"))
		config = Finite(group) and Ask(Api("C_SpecializationInfo", "GetCombatConfigIDForSpecGroup"), group) or nil
	end
	if not Finite(config) then
		return nil
	end
	if Ask(Api("C_Traits", "ConfigHasStagedChanges"), config) == true then
		local found = unstaged[config]
		if found then
			return found[1], found[2]
		end
		return nil
	end
	local tree = Field(Field(Ask(Api("C_Traits", "GetConfigInfo"), config), "treeIDs"), 1)
	if not Finite(tree) then
		return nil
	end
	local shown = Ask(Api("C_Traits", "GetGroupDisplayInfoByTreeID"), tree)
	if Field(shown, count + 1) ~= nil then
		return nil
	end
	local ids, names = {}, {}
	for place = 1, count do
		local info = Field(shown, place)
		local id, name = Field(info, "groupID"), Field(info, "displayName")
		if not (Finite(id) and IsText(name)) then
			return nil
		end
		ids[place], names[place] = id, name
	end
	local spent = {}
	local entries = Ask(Api("C_Traits", "GetGroupCurrencyInfo"), config, ids)
	for place = 1, count do
		local entry = Field(entries, place)
		local id = Field(entry, "traitNodeGroupID")
		local points = Field(Field(Field(entry, "currencyInfos"), 1), "spent")
		if Finite(id) and Finite(points) then
			spent[id] = points
		end
	end
	local best, most = nil, 0
	for place = 1, count do
		local points = spent[ids[place]]
		if points and points > most then
			best, most = place, points
		end
	end
	local name = best and names[best] or nil
	unstaged[config] = { best, name }
	return best, name
end

function ns.PlayerRole()
	local given = Ask(UnitGroupRolesAssigned, "player")
	if IsText(given) and ROLE_GIVEN[given] then
		return ROLE_GIVEN[given], "Suggested from your group role.", "your group role"
	end
	local threat = ns.PlateThreat
	if type(threat) == "table" and type(threat.Role) == "function" then
		local ok, kind, reason = pcall(threat.Role)
		if ok and IsText(kind) and kind == "tank" and IsText(reason) and reason ~= "your group role" then
			if reason == "your choice" then
				return "tank", "Suggested from your role.", "Your role of nameplate threat"
			end
			return "tank", ("Suggested from %s."):format(reason), reason
		end
	end
	local class = Ask(UnitClassBase, "player")
	class = IsText(class) and class or nil
	local trees = class and ROLE_TREES[class]
	if trees then
		local best, name = MostPoints(#trees)
		if best then
			return trees[best], ("Suggested from your talents: most points in %s."):format(name), ("most points in %s"):format(name)
		end
	end
	if class then
		local word = class:lower()
		return class == "PRIEST" and "healer" or "damage", ("Suggested for a %s."):format(word), ("your class, %s"):format(word)
	end
	return "damage", nil, nil
end

function ns.PlayerTree()
	local class = Ask(UnitClassBase, "player")
	local trees = IsText(class) and ROLE_TREES[class] or nil
	if not trees then
		return nil
	end
	return MostPoints(#trees)
end

function ns.Choices(def)
	local choices = def.choices
	if type(choices) == "string" then
		local call = ns[choices]
		local ok, list = false, nil
		if type(call) == "function" then
			ok, list = pcall(call, def)
		end
		return ok and type(list) == "table" and list or {}
	end
	return choices or {}
end

local function Normalise(def, value)
	if def.kind == "bool" then
		if type(value) == "boolean" then
			return value
		end
	elseif def.kind == "number" then
		if type(value) == "number" then
			local stepped = math.floor((value - def.min) / def.step + 0.5) * def.step + def.min
			return math.max(def.min, math.min(def.max, stepped))
		end
	elseif def.kind == "colour" then
		if type(value) == "string" and value:find("^%x%x%x%x%x%x%x%x$") then
			return value:lower()
		end
	elseif def.kind == "choice" then
		for _, choice in ipairs(ns.Choices(def)) do
			if choice[1] == value then
				return value
			end
		end
	elseif def.kind == "text" then
		if type(value) == "string" and #value <= 200 then
			return value
		end
	end
	return nil
end

local RENAMED = { ["trackers.grow"] = { middle = "center" }, ["partycd.show"] = { used = "cooling" }, ["combattext.whose"] = { mine = "one" } }
for _, path in ipairs({ "fonts.outline", "chat.outline", "actionbars.textOutline" }) do
	RENAMED[path] = { outline = "thin" }
end
RENAMED["hud.hitTableSize"] = "nearest"

local function Renamed(path, value)
	local map = RENAMED[path]
	if map == "nearest" then
		local number, def = tonumber(value), defs[path]
		if number == nil or def == nil or Normalise(def, value) ~= nil then
			return value
		end
		local best, gap = value, nil
		for _, choice in ipairs(ns.Choices(def)) do
			local id = tonumber(choice[1])
			if id and (gap == nil or math.abs(id - number) <= gap) then
				best, gap = choice[1], math.abs(id - number)
			end
		end
		return best
	end
	return map and type(value) == "string" and map[value] or value
end

function ns.Normalised(path, value)
	local def = defs[path]
	if def == nil then
		return nil
	end
	return Normalise(def, Renamed(path, value))
end

function ns.Needs(path)
	local def = defs[path]
	return def and def.needsPath or nil
end

function ns.Def(path)
	return defs[path]
end

function ns.NeedMet(item, path)
	local value = ns.Get(path)
	local row = item
	for _ = 1, 8 do
		if row == nil then
			break
		end
		if row.needsPath == path then
			if row.needsIn ~= nil then
				for _, allowed in ipairs(row.needsIn) do
					if value == allowed then
						return true
					end
				end
				return false
			end
			break
		end
		row = row.needsPath and defs[row.needsPath] or nil
	end
	return value == true
end

function ns.IsSet(path)
	return values ~= nil and values[path] ~= nil
end

local function CVarText(name)
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" or type(name) ~= "string" then
		return nil
	end
	local ok, raw = pcall(C_CVar.GetCVar, name)
	if ok and not IsSecret(raw) and type(raw) == "string" then
		return raw
	end
	return nil
end

function ns.CVarGet(def)
	local raw = CVarText(def.cvar)
	if raw == nil then
		return nil
	end
	if def.kind == "bool" then
		return raw == "1"
	elseif def.kind == "number" then
		local number = tonumber(raw)
		if number == nil then
			return nil
		end
		if number < 0 and def.negative ~= nil then
			return def.negative
		end
		return math.floor(number * (def.scale or 1) * 1e6 + 0.5) / 1e6
	elseif def.kind == "choice" and type(def.values) == "table" then
		for id, text in pairs(def.values) do
			if text == raw then
				return id
			end
		end
	end
	return nil
end

local function CVarWrite(def, value)
	if def.kind == "bool" then
		return value and "1" or "0"
	elseif def.kind == "number" then
		if def.negative ~= nil and value == def.negative then
			return "-1"
		end
		return ("%.6g"):format(value / (def.scale or 1))
	elseif def.kind == "choice" and type(def.values) == "table" then
		return def.values[value]
	end
	return nil
end

local function Same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= 1e-6 * math.max(1, math.abs(b))
	end
	return a == b
end
ns.CVarSame = Same

local refused = {}
function ns.CVarRefused(name)
	return refused[name] == true
end
function ns.CVarMarkRefused(name, state)
	refused[name] = state or nil
end

function ns.CVarShown(def, now)
	if def.kind == "bool" and type(now) == "boolean" then
		return now and "on" or "off"
	elseif def.kind == "choice" and now ~= nil then
		local shown = tostring(now)
		for _, line in ipairs(ns.Choices(def)) do
			if line.id == now and line.text then
				shown = line.text
			end
		end
		return shown
	elseif now ~= nil then
		return "at " .. (type(now) == "number" and ("%.6g"):format(now) or tostring(now)) .. (def.unit or "")
	end
	return "its own value"
end

function ns.CVarSet(def, value, quiet)
	local text = CVarWrite(def, value)
	if text == nil or type(C_CVar) ~= "table" or type(C_CVar.SetCVar) ~= "function" or CVarText(def.cvar) == nil then
		return false
	end
	local kept
	ns.OutOfCombat(function()
		pcall(C_CVar.SetCVar, def.cvar, text)
		local now = ns.CVarGet(def)
		kept = now
		refused[def.cvar] = not Same(now, value) or nil
		if not Same(now, value) and not quiet then
			print(("Flat UI: the game kept %s %s."):format(def.label or def.cvar, ns.CVarShown(def, now)))
		end
	end)
	return true, kept
end

function ns.RowShown(path)
	local def = defs[path]
	if def and def.hidden then
		return false
	end
	if def and def.cvar then
		return CVarText(def.cvar) ~= nil
	end
	return true
end

function ns.PageHasRows(page, panel)
	for _, item in ipairs(page) do
		if (item.key and (item.path == nil or ns.RowShown(item.path))) or (panel == true and item.kind == "entries") then
			return true
		end
	end
	return false
end

local function Routed(def)
	local value
	if def.get then
		local call = ns[def.get]
		if type(call) == "function" then
			local ok, got = pcall(call, def)
			if ok then
				value = got
			end
		end
	elseif def.cvar then
		value = ns.CVarGet(def)
	end
	return value
end

function ns.Get(path)
	local def = defs[path]
	if not def then
		return nil
	end
	if Unsaved(def) then
		local drafted = viewing and viewing[path]
		if drafted ~= nil then
			return drafted
		end
		local value = Routed(def)
		if value == nil then
			return def.default
		end
		return value
	end
	local value = values and values[path]
	if value == nil then
		return def.default
	end
	return value
end

local function ViewDone(was, wasValues, ...)
	viewing, values = was, wasValues
	return ...
end

function ns.Viewing(view, fn, ...)
	local was, wasValues = viewing, values
	viewing, values = view, view
	return ViewDone(was, wasValues, pcall(fn, ...))
end

ns.LiveView = setmetatable({}, { __index = function(_, key)
	if key == "spots" then
		return profile and profile.movers
	end
	return profile and profile.options and profile.options[key]
end })

function ns.Colour(path)
	local hex = ns.Get(path)
	return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
end

function ns.Enabled(key)
	return db ~= nil and ns.Get(key .. ".enabled") == true and not status[key].error
end

function ns.HandsOff()
	return ns.Get("general.handsOff") == true
end

function ns.HandsOffChanged()
	if type(print) == "function" then
		print("Flat UI: Leave the game's action bars alone applies after /reload.")
	end
end

function ns.OwnChanged()
	if type(print) == "function" then
		print("Flat UI: Action buttons applies after /reload.")
	end
end

local clickReporters = {}
function ns.ClickPathReporter(fn)
	clickReporters[#clickReporters + 1] = fn
end

function ns.ClickPathLines()
	local lines = {}
	for _, fn in ipairs(clickReporters) do
		local ok, line = pcall(fn)
		if ok and type(line) == "string" then
			lines[#lines + 1] = line
		end
	end
	return lines
end

local OWN_STATUS = { "buttons", "waiting", "page", "keys", "flyoutkeys", "parked", "leave", "taint", "totem" }
for _, id in ipairs(OWN_STATUS) do
	ns.ClickPathReporter(function()
		local line = ns.OwnStatus and ns.OwnStatus(id)
		if line == nil and id == "buttons" and ns.Get("actionbars.own") == "game" then
			line = "Action buttons: the game's."
		end
		return line
	end)
end

function ns.SetFaded(region, faded)
	if region ~= nil and not IsSecret(region) then
		pcall(region.SetAlpha, region, faded and 0 or 1)
	end
end

function ns.SetHidden(region, hidden)
	if region ~= nil and not IsSecret(region) then
		pcall(region.SetShown, region, not hidden)
	end
end

function ns.RegionWithAtlas(frame, atlas)
	if Forbidden(frame) or not frame.GetRegions then
		return nil
	end
	local wanted = atlas:lower()
	for _, region in ipairs({ frame:GetRegions() }) do
		if not IsSecret(region) and region.GetAtlas then
			local ok, name = pcall(region.GetAtlas, region)
			if ok and not IsSecret(name) and type(name) == "string" and name:lower() == wanted then
				return region
			end
		end
	end
	return nil
end

local fills = setmetatable({}, { __mode = "k" })

local BAR_FILES = {
	soft = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Soft.tga",
	shaded = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Shaded.tga",
	gloss = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Gloss.tga",
	stripes = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Stripes.tga",
	edge = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Edge.tga",
	fade = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fade.tga",
	game = "Interface\\TargetingFrame\\UI-StatusBar",
	skills = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
	targeting = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
}
local BAR_CHOICES = ns.BAR_CHOICES

function ns.BarTexture(id)
	if id == nil or id == "default" then
		id = ns.Get("general.barTexture")
	end
	return BAR_FILES[id]
end

function ns.BarChoices(withDefault)
	local list = {}
	if withDefault == true then
		list[1] = { "default", "Same as the Flat UI page" }
	end
	for _, choice in ipairs(BAR_CHOICES) do
		list[#list + 1] = { choice[1], choice[2] }
	end
	return list
end

function ns.BarChoicesDefault()
	return ns.BarChoices(true)
end

function ns.BarFile(id)
	return BAR_FILES[id]
end

function ns.FillRegion(bar)
	if Forbidden(bar) then
		return nil
	end
	local ok, region = pcall(bar.GetStatusBarTexture, bar)
	if not ok or region == nil or IsSecret(region) or type(region) ~= "table" then
		return nil
	end
	return region
end

local function AtlasOf(region)
	local ok, atlas = pcall(region.GetAtlas, region)
	if not ok or IsSecret(atlas) or (atlas ~= nil and type(atlas) ~= "string") then
		return nil, true
	end
	if atlas == "" then
		atlas = nil
	end
	return atlas, false
end

local function Accepted(ok, done)
	return ok and (IsSecret(done) or done ~= false)
end

local function SetFillTexture(bar, asset)
	return Accepted(pcall(bar.SetStatusBarTexture, bar, asset))
end

local function ImageFill(bar, record, texture, r, g, b, gameColour)
	if not (record.flat and record.texture == texture) then
		if not SetFillTexture(bar, texture) then
			return false, true
		end
		record.flat, record.texture = true, texture
	end
	if not gameColour then
		if not pcall(bar.SetStatusBarColor, bar, r, g, b, 1) then
			ns.RestoreFill(bar)
			return false, true
		end
		record.coloured = true
	end
	record.r, record.g, record.b = r, g, b
	return true
end

function ns.FlatFill(bar, r, g, b, fallbackAtlas, gameColour, file)
	local region = ns.FillRegion(bar)
	if not region then
		return nil
	end
	local record = fills[bar]
	if not record then
		record = {}
		fills[bar] = record
	end
	local atlas, unreadable = AtlasOf(region)
	if record.flat and (atlas or unreadable) then
		record.flat = nil
	end
	if not record.flat then
		record.atlas = atlas or record.atlas or fallbackAtlas
		if not record.atlas then
			return false
		end
	end
	local texture = file
	if texture == nil then
		texture = ns.BarTexture()
	elseif texture == false then
		texture = nil
	end
	if record.flat and record.texture == texture and record.r == r and record.g == g and record.b == b then
		return true
	end
	if texture then
		return ImageFill(bar, record, texture, r, g, b, gameColour)
	end
	if record.coloured then
		if not pcall(bar.SetStatusBarColor, bar, 1, 1, 1, 1) then
			return false, true
		end
		record.coloured = nil
	end
	if not pcall(bar.SetColorFill, bar, r, g, b, 1) then
		return false, true
	end
	record.flat, record.r, record.g, record.b = true, r, g, b
	record.texture = nil
	return true
end

function ns.RestoreFill(bar)
	local record = fills[bar]
	if not (record and record.flat) then
		return true
	end
	if Forbidden(bar) then
		return false
	end
	if not SetFillTexture(bar, record.atlas) then
		return false
	end
	if record.coloured and not pcall(bar.SetStatusBarColor, bar, 1, 1, 1, 1) then
		return false
	end
	record.flat, record.r, record.g, record.b = nil, nil, nil, nil
	record.texture, record.coloured = nil, nil
	return true
end

function ns.ClassColour()
	return ns.ClassColourOf("player")
end

function ns.ClassColourOf(unit)
	if unit == nil or UnitClass == nil or RAID_CLASS_COLORS == nil then
		return nil
	end
	local ok, _, class = pcall(UnitClass, unit)
	if not ok or IsSecret(class) or type(class) ~= "string" then
		return nil
	end
	local colour = RAID_CLASS_COLORS[class]
	if colour == nil or IsSecret(colour) or type(colour) ~= "table" then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return r, g, b
end

local function Plain(value)
	if value == nil or IsSecret(value) then
		return nil
	end
	return value
end

function ns.ReactionColour(unit)
	if unit == nil then
		return nil
	end
	if ns.Get("general.reactionOwn") == true and UnitReaction ~= nil then
		if UnitIsTapDenied ~= nil and UnitPlayerControlled ~= nil then
			local ok, denied = pcall(UnitIsTapDenied, unit)
			if ok and Plain(denied) == true then
				local okControl, controlled = pcall(UnitPlayerControlled, unit)
				if okControl and Plain(controlled) == false then
					return ns.Colour("general.reactionTapped")
				end
			end
		end
		local okReaction, reaction = pcall(UnitReaction, unit, "player")
		reaction = okReaction and Plain(reaction) or nil
		if type(reaction) == "number" and reaction == reaction then
			return ns.Colour(reaction <= 3 and "general.reactionHostile" or reaction == 4 and "general.reactionNeutral" or "general.reactionFriendly")
		end
	end
	if UnitSelectionColor == nil then
		return nil
	end
	local ok, r, g, b = pcall(UnitSelectionColor, unit)
	if not ok or IsSecret(r) or IsSecret(g) or IsSecret(b) then
		return nil
	end
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return r, g, b
end

local POWER_ROWS = { MANA = "powerMana", RAGE = "powerRage", ENERGY = "powerEnergy", FOCUS = "powerFocus", RUNIC_POWER = "powerRunic" }

function ns.PowerColour(token)
	if type(token) ~= "string" or IsSecret(token) then
		return nil
	end
	local row = POWER_ROWS[token]
	if row and ns.Get("general.powerOwn") == true then
		return ns.Colour("general." .. row)
	end
	local colours = PowerBarColor
	local colour = type(colours) == "table" and colours[token] or nil
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if not (Finite(r) and Finite(g) and Finite(b)) then
		return nil
	end
	return r, g, b
end

local CLASS_ART = { "classicon-%s", "groupfinder-icon-class-%s" }
local classAtlas = {}
local noArt = {}

local function AtlasExists(name)
	local api = C_Texture
	if type(api) == "table" and not IsSecret(api) then
		if type(api.GetAtlasExists) == "function" then
			local ok, exists = pcall(api.GetAtlasExists, name)
			return ok and not IsSecret(exists) and exists == true
		elseif type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			return ok and info ~= nil
		end
	end
	return false
end

function ns.ClassAtlas(token)
	if type(token) ~= "string" or IsSecret(token) then
		return nil
	end
	local atlas = classAtlas[token]
	if atlas == nil then
		atlas = false
		for _, pattern in ipairs(CLASS_ART) do
			local name = pattern:format(token:lower())
			if AtlasExists(name) then
				atlas = name
				break
			end
		end
		classAtlas[token] = atlas
		if not atlas then
			noArt[#noArt + 1] = token
		end
	end
	return atlas or nil
end

local FACTION_COLOURS = { Alliance = { 0.29, 0.33, 0.91 }, Horde = { 0.90, 0.05, 0.07 } }

function ns.BorderRGB()
	local mode = ns.Get("general.borderMode")
	if mode == "class" then
		local r, g, b = ns.ClassColour()
		if r then
			return r, g, b
		end
	elseif mode == "faction" and UnitFactionGroup ~= nil then
		local ok, faction = pcall(UnitFactionGroup, "player")
		local colour = ok and not IsSecret(faction) and type(faction) == "string" and FACTION_COLOURS[faction] or nil
		if colour then
			return colour[1], colour[2], colour[3]
		end
	end
	return ns.Colour("general.border")
end

local fonts = setmetatable({}, { __mode = "k" })

function ns.TextStyle(fontString, spec)
	if fontString == nil or IsSecret(fontString) or type(fontString) ~= "table" then
		return nil
	end
	spec = type(spec) == "table" and spec or {}
	local percent, flags, face = spec.percent or 100, spec.flags, spec.face
	local colour = spec.r ~= nil and spec.g ~= nil and spec.b ~= nil
	local shadow = spec.shadow == true
	local record = fonts[fontString]
	if record == nil and percent == 100 and flags == nil and face == nil and not colour and not shadow then
		return true
	end
	local ok, file, size, current = pcall(fontString.GetFont, fontString)
	if not ok or IsSecret(file) or IsSecret(size) or IsSecret(current) or type(file) ~= "string" or type(size) ~= "number" or size <= 0
		or (current ~= nil and type(current) ~= "string") then
		return false
	end
	if record == nil then
		record = {}
		fonts[fontString] = record
	end
	if colour and record.colour == nil then
		local okColour, r, g, b, a = pcall(fontString.GetTextColor, fontString)
		if not okColour or not (Finite(r) and Finite(g) and Finite(b)) then
			return false
		end
		record.colour = { r, g, b, Finite(a) and a or 1 }
	end
	if shadow and record.shadow == nil then
		local okShadow, x, y = pcall(fontString.GetShadowOffset, fontString)
		if not okShadow or not (Finite(x) and Finite(y)) then
			return false
		end
		record.shadow = { x, y }
	end
	local ours = (record.set ~= nil or record.flagsSet ~= nil or record.faceSet ~= nil) and math.abs((record.set or record.size) - size) <= 0.5
		and (record.flagsSet == nil or (current or "") == record.flagsSet) and (record.faceSet == nil or file == record.faceSet)
	if not ours then
		record.file, record.size, record.flags, record.set, record.flagsSet, record.faceSet = file, size, current, nil, nil, nil
	end
	local wanted = record.size * percent / 100
	if not (math.abs((record.set or record.size) - wanted) < 0.01 and record.flagsSet == flags and record.faceSet == face) then
		local okSet, result = pcall(fontString.SetFont, fontString, face or record.file, wanted, flags ~= nil and flags or record.flags)
		if not okSet or (face ~= nil and result == false) then
			return false
		end
		record.set = percent ~= 100 and wanted or nil
		record.flagsSet, record.faceSet = flags, face
	end
	if colour then
		local key = ("%s,%s,%s,%s"):format(spec.r, spec.g, spec.b, spec.a or 1)
		if record.colourSet ~= key then
			if not pcall(fontString.SetTextColor, fontString, spec.r, spec.g, spec.b, spec.a or 1) then
				return false
			end
			record.colourSet = key
		end
	elseif record.colourSet then
		local back = record.colour
		if not pcall(fontString.SetTextColor, fontString, back[1], back[2], back[3], back[4]) then
			return false
		end
		record.colourSet, record.colour = nil, nil
	end
	if shadow then
		if not record.shadowSet then
			if not pcall(fontString.SetShadowOffset, fontString, 0, 0) then
				return false
			end
			record.shadowSet = true
		end
	elseif record.shadowSet then
		local back = record.shadow
		if not pcall(fontString.SetShadowOffset, fontString, back[1], back[2]) then
			return false
		end
		record.shadowSet, record.shadow = nil, nil
	end
	return true
end

function ns.TextSize(fontString, percent, flags)
	return ns.TextStyle(fontString, { percent = percent, flags = flags })
end

local FONT_FACES = { { "friz", "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, { "arial", "Fonts\\ARIALN.TTF", "Arial Narrow" },
	{ "morpheus", "Fonts\\MORPHEUS.TTF", "Morpheus" }, { "skurri", "Fonts\\SKURRI.TTF", "Skurri" } }
local fontsOffered

local function FontsOffered()
	if fontsOffered == nil then
		fontsOffered = {}
		local made, probe = pcall(function()
			local probeFrame = CreateFrame("Frame")
			own[probeFrame] = true
			return probeFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		end)
		if made and type(probe) == "table" then
			own[probe] = true
			for _, face in ipairs(FONT_FACES) do
				local ok, loaded = pcall(probe.SetFont, probe, face[2], 12, "")
				fontsOffered[face[1]] = ok and loaded == true
			end
		end
	end
	return fontsOffered
end

function ns.FontFile(id)
	if not FontsOffered()[id] then
		return nil
	end
	for _, face in ipairs(FONT_FACES) do
		if face[1] == id then
			return face[2]
		end
	end
	return nil
end

function ns.FontChoices()
	local offered = FontsOffered()
	local list = { { "default", "Game font" } }
	for _, face in ipairs(FONT_FACES) do
		if offered[face[1]] then
			list[#list + 1] = { face[1], face[3] }
		end
	end
	return list
end

function ns.OwnText(parent, layer, fontObject)
	if Forbidden(parent) then
		return nil
	end
	local ok, text = pcall(parent.CreateFontString, parent, nil, layer or "OVERLAY", fontObject)
	if not ok or type(text) ~= "table" or IsSecret(text) then
		return nil
	end
	own[text] = true
	return text
end

local followed = setmetatable({}, { __mode = "k" })
local followedGlobal = {}

local function FollowOnce(bucket, key, hook, fn)
	if type(fn) ~= "function" then
		return false
	end
	local entry = bucket[key]
	if entry == nil then
		if type(hooksecurefunc) ~= "function" then
			return false
		end
		entry = { fns = {} }
		local function dispatch(...)
			for _, call in ipairs(entry.fns) do
				local ok, err = pcall(call, ...)
				if not ok then
					geterrorhandler()(err)
				end
			end
		end
		if not pcall(hook, dispatch) then
			return false
		end
		bucket[key] = entry
	end
	for _, existing in ipairs(entry.fns) do
		if existing == fn then
			return true
		end
	end
	entry.fns[#entry.fns + 1] = fn
	return true
end

function ns.TaintLogging()
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" then
		return false
	end
	local ok, value = pcall(C_CVar.GetCVar, "taintLog")
	return ok and not IsSecret(value) and type(value) == "string" and value ~= "0"
end

local skipped, skippedCount = setmetatable({}, { __mode = "k" }), 0

function ns.HookMethod(object, method, fn)
	if ns.TaintLogging() then
		local seen = skipped[object]
		if seen == nil and type(object) == "table" and not IsSecret(object) then
			seen = {}
			skipped[object] = seen
		end
		if seen == nil then
			skippedCount = skippedCount + 1
		elseif not seen[method] then
			seen[method] = true
			skippedCount = skippedCount + 1
		end
		return false
	end
	return (pcall(hooksecurefunc, object, method, fn))
end

function ns.TaintSkipped()
	return skippedCount
end

function ns.Follow(frame, method, fn)
	if Forbidden(frame) or type(method) ~= "string" or type(frame[method]) ~= "function" then
		return nil
	end
	local bucket = followed[frame]
	if bucket == nil then
		bucket = {}
		followed[frame] = bucket
	end
	return FollowOnce(bucket, method, function(dispatch)
		assert(ns.HookMethod(frame, method, dispatch))
	end, fn)
end

function ns.FollowGlobal(name, fn)
	if type(name) ~= "string" or type(_G[name]) ~= "function" then
		return nil
	end
	return FollowOnce(followedGlobal, name, function(dispatch)
		hooksecurefunc(name, dispatch)
	end, fn)
end

function ns.FollowTable(source, method, fn)
	if type(source) ~= "table" or IsSecret(source) or type(method) ~= "string" or type(source[method]) ~= "function" then
		return nil
	end
	local bucket = followed[source]
	if bucket == nil then
		bucket = {}
		followed[source] = bucket
	end
	return FollowOnce(bucket, method, function(dispatch)
		assert(ns.HookMethod(source, method, dispatch))
	end, fn)
end

local function PixelFactor()
	local _, height = GetPhysicalScreenSize()
	if Finite(height) and height > 0 then
		screenHeight = height
	end
	return screenHeight and 768 / screenHeight or 1
end

function ns.Pixels(frame, px)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	if not ok or not Finite(scale) or scale <= 0 then
		scale = 1
	end
	return px * PixelFactor() / scale
end

local function PlaceEdgesNow(outline)
	local t = outline.px or ns.Get("general.thickness")
	if not outline.pixels then
		t = ns.Pixels(outline.anchor, t)
	end
	local anchor, top, bottom, left, right = outline.anchor, outline.top, outline.bottom, outline.left, outline.right
	top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -t, 0)
	top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", t, 0)
	top:SetHeight(t)
	bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -t, 0)
	bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", t, 0)
	bottom:SetHeight(t)
	left:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, 0)
	left:SetWidth(t)
	right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(t)
	local round = outline.round
	if round then
		local to = round.ring or outline.target
		round.disc:SetPoint("TOPLEFT", to, "TOPLEFT", -t, t)
		round.disc:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", t, -t)
	end
end

local function PlaceEdges(outline)
	if outline.view then
		local ok, err = ns.Viewing(outline.view, PlaceEdgesNow, outline)
		if not ok then
			error(err, 0)
		end
	else
		PlaceEdgesNow(outline)
	end
end

local function Resize(outline)
	if outline.pixels then
		outline.holder:SetScale(PixelFactor())
		if outline.round and outline.round.ring then
			outline.round.ring:SetScale(PixelFactor())
		end
	end
	PlaceEdges(outline)
end

function ns.Borderless()
	return ns.Get("general.borderless")
end

local function Gradient(texture, top, bottom, a)
	return pcall(function()
		texture:SetColorTexture(1, 1, 1, 1)
		texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], a), CreateColor(top[1], top[2], top[3], a))
	end)
end

local function PaintBackdrop(outline, r, g, b, a)
	local texture, shade = outline.backdrop, outline.shade
	if shade then
		outline.shadeDrawn = Gradient(texture, shade.top, shade.bottom, a)
		if outline.shadeDrawn then
			outline.graded = true
			return
		end
	elseif outline.graded and Gradient(texture, { r, g, b }, { r, g, b }, a) then
		return
	end
	if outline.graded then
		texture:SetVertexColor(1, 1, 1, 1)
	end
	texture:SetColorTexture(r, g, b, a)
end

local function AreaOf(outline)
	local area = outline.area
	if area and AREAS[area] and ns.Get(area .. "." .. outline.prefix .. "Own") == true then
		return area, outline.prefix
	end
	return nil
end

function ns.OutlineBackdropAlpha(outline)
	local area, prefix = AreaOf(outline)
	local a = area and ns.Get(area .. "." .. prefix .. "BackAlpha") or ns.Get("general.backdropAlpha")
	return (type(a) == "number" and a or 100) / 100
end

local function PaintNow(outline)
	local r, g, b = outline.r, outline.g, outline.b
	local shown = outline.shown
	local area, prefix = AreaOf(outline)
	if r == nil then
		shown = shown and (outline.kept or not ns.Borderless())
		if area then
			r, g, b = ns.Colour(area .. "." .. prefix .. "Border")
		else
			r, g, b = ns.BorderRGB()
		end
	end
	if outline.bare or outline.edgesOff then
		shown = false
	end
	local round, discShown = outline.roundOn, shown
	if round then
		shown = false
		outline.round.disc:SetColorTexture(r, g, b, outline.edgeAlpha or 1)
		outline.round.disc:SetShown(discShown)
	end
	for _, edge in ipairs(outline.edges) do
		edge:SetColorTexture(r, g, b, outline.edgeAlpha or 1)
		edge:SetShown(shown)
	end
	local br, bg, bb, ba
	if outline.fr ~= nil then
		br, bg, bb, ba = outline.fr, outline.fg, outline.fb, outline.fa
	elseif area and ns.Get(area .. "." .. prefix .. "Back") ~= nil then
		br, bg, bb = ns.Colour(area .. "." .. prefix .. "Back")
		ba = outline.backAlpha or ns.Get(area .. "." .. prefix .. "BackAlpha") / 100
	else
		br, bg, bb = ns.Colour("general.backdrop")
		ba = outline.backAlpha or ns.Get("general.backdropAlpha") / 100
	end
	PaintBackdrop(outline, br, bg, bb, ba)
	outline.backdrop:SetShown(outline.shown and outline.backdropOn)
	if round then
		outline.backdrop:Hide()
	end
end

function ns.OutlineEdgeRGB(outline)
	if outline == nil then
		return ns.BorderRGB()
	end
	if outline.r ~= nil then
		return outline.r, outline.g, outline.b
	end
	local area, prefix = AreaOf(outline)
	if area then
		return ns.Colour(area .. "." .. prefix .. "Border")
	end
	return ns.BorderRGB()
end

local function Paint(outline)
	if outline.view then
		local ok, err = ns.Viewing(outline.view, PaintNow, outline)
		if not ok then
			error(err, 0)
		end
	else
		PaintNow(outline)
	end
end

local function Edge(owner)
	local edge = owner:CreateTexture(nil, "OVERLAY", nil, 7)
	own[edge] = true
	if edge.SetSnapToPixelGrid then
		pcall(edge.SetSnapToPixelGrid, edge, false)
	end
	if edge.SetTexelSnappingBias then
		pcall(edge.SetTexelSnappingBias, edge, 0)
	end
	return edge
end

function ns.Outline(owner, target, direct, prefix)
	local outline = outlines[target]
	if outline then
		return outline
	end
	if Forbidden(owner) then
		return nil
	end
	outline = { shown = true, backdropOn = true, area = running, prefix = prefix or "look" }
	outline.owner, outline.target = owner, target
	outline.backdrop = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
	own[outline.backdrop] = true
	outline.backdrop:SetAllPoints(target)
	local edgeOwner = owner
	if direct then
		outline.anchor = target
	else
		local holder = CreateFrame("Frame", nil, owner)
		own[holder] = true
		holder:SetAllPoints(target)
		outline.holder = holder
		outline.pixels = pcall(holder.SetIgnoreParentScale, holder, true)
		edgeOwner = holder
		outline.anchor = holder
	end
	outline.top, outline.bottom = Edge(edgeOwner), Edge(edgeOwner)
	outline.left, outline.right = Edge(edgeOwner), Edge(edgeOwner)
	outline.edges = { outline.top, outline.bottom, outline.left, outline.right }
	Resize(outline)
	Paint(outline)
	outlines[target] = outline
	return outline
end

function ns.SetOutlineView(outline, view)
	if outline and outline.view ~= view then
		outline.view = view
		Resize(outline)
		Paint(outline)
	end
end

function ns.RepaintOutline(outline)
	if outline then
		Resize(outline)
		Paint(outline)
	end
end

function ns.SetOutlineArea(outline, key)
	if outline and outline.area ~= key then
		outline.area = key
		Paint(outline)
	end
	return outline
end

function ns.SetOutline(outline, shown, backdropOn)
	if not outline then
		return
	end
	shown, backdropOn = shown and true or false, backdropOn and true or false
	if outline.shown ~= shown or outline.backdropOn ~= backdropOn then
		outline.shown, outline.backdropOn = shown, backdropOn
		Paint(outline)
	end
end

function ns.SetOutlineBare(outline, bare)
	if outline and (outline.bare or false) ~= (bare or false) then
		outline.bare = bare or nil
		Paint(outline)
	end
end

function ns.SetOutlineEdges(outline, shown)
	if outline and (outline.edgesOff or false) ~= (shown == false) then
		outline.edgesOff = shown == false or nil
		Paint(outline)
	end
end

function ns.SetOutlineAlpha(outline, alpha, backdropAlpha)
	if outline and (outline.edgeAlpha ~= alpha or outline.backAlpha ~= backdropAlpha) then
		outline.edgeAlpha, outline.backAlpha = alpha, backdropAlpha
		Paint(outline)
	end
end

function ns.SetOutlineFill(outline, r, g, b, a)
	if outline and (outline.fr ~= r or outline.fg ~= g or outline.fb ~= b or outline.fa ~= a) then
		outline.fr, outline.fg, outline.fb, outline.fa = r, g, b, a
		Paint(outline)
	end
end

function ns.SetOutlineShade(outline, top, bottom)
	if not outline then
		return nil
	end
	if top == nil then
		if outline.shade then
			outline.shade = nil
			Paint(outline)
		end
		return nil
	end
	outline.shade = { top = top, bottom = bottom }
	Paint(outline)
	return outline.shadeDrawn
end

function ns.SetOutlineColour(outline, r, g, b)
	if outline and (outline.r ~= r or outline.g ~= g or outline.b ~= b) then
		outline.r, outline.g, outline.b = r, g, b
		Paint(outline)
	end
end

function ns.KeepOutline(outline)
	if outline and not outline.kept then
		outline.kept = true
		Paint(outline)
	end
end

function ns.SetOutlineThickness(outline, px)
	if outline and outline.px ~= px then
		outline.px = px
		PlaceEdges(outline)
	end
end

local ROUND_MASK = "CircleMaskScalable"

local function Unsnap(texture)
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	return texture
end

local function CircleMask(owner, to)
	local mask = Unsnap(owner:CreateMaskTexture())
	own[mask] = true
	mask:SetAllPoints(to)
	mask:SetAtlas(ROUND_MASK, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	return mask
end

function ns.SetOutlineRound(outline, art, on, extra)
	if not outline then
		return
	end
	on = on and true or false
	outline.roundWant = on
	local round = outline.round
	if on and not round then
		local owner = outline.owner
		if type(owner.CreateMaskTexture) ~= "function" or not AtlasExists(ROUND_MASK) then
			ns.roundMissing = true
			return
		end
		local fighting = InCombatLockdown()
		if fighting then
			if not outline.roundQueued then
				outline.roundQueued = true
				ns.OutOfCombat(function()
					outline.roundQueued = nil
					ns.SetOutlineRound(outline, art, outline.roundWant, extra)
				end)
			end
			return
		end
		local made, parts = pcall(function()
			local ring
			if outline.holder and outline.pixels then
				ring = CreateFrame("Frame", nil, owner)
				own[ring] = true
				ring:SetIgnoreParentScale(true)
				ring:SetScale(PixelFactor())
				ring:SetAllPoints(outline.target)
				local got, level = pcall(owner.GetFrameLevel, owner)
				ring:SetFrameLevel(got and type(level) == "number" and not ns.IsSecret(level) and math.max(0, level - 1) or 0)
			end
			local host = ring or owner
			local d = Unsnap(host:CreateTexture(nil, "BACKGROUND", nil, -7))
			own[d] = true
			d:Hide()
			local discMask = CircleMask(host, d)
			d:AddMaskTexture(discMask)
			return { disc = d, ring = ring, discMask = discMask, artMask = CircleMask(owner, art) }
		end)
		if not made then
			ns.roundMissing = true
			return
		end
		round = parts
		round.art, round.extra = art, extra
		outline.round = round
		Unsnap(art)
	end
	if round and (outline.roundOn or false) ~= on then
		outline.roundOn = on or nil
		local method = on and "AddMaskTexture" or "RemoveMaskTexture"
		pcall(round.art[method], round.art, round.artMask)
		if round.extra then
			pcall(round.extra[method], round.extra, round.artMask)
		end
		if not on then
			round.disc:Hide()
		end
		PlaceEdges(outline)
		Paint(outline)
	end
end

function ns.OutOfCombat(fn)
	if InCombatLockdown() then
		afterCombat[#afterCombat + 1] = fn
	else
		fn()
	end
end

function ns.ResizeAll()
	if resizePending then
		return
	end
	resizePending = true
	ns.OutOfCombat(function()
		resizePending = false
		for _, outline in pairs(outlines) do
			pcall(Resize, outline)
		end
		for _, key in ipairs(MODULE_ORDER) do
			if modules[key] and modules[key].Resized and status[key].started then
				ns.Try(key, modules[key].Resized)
			end
		end
	end)
end

local function PaintAll()
	for _, outline in pairs(outlines) do
		pcall(Paint, outline)
	end
end

local function Stop(key, err)
	local state = status[key]
	if state.error then
		return
	end
	state.error = tostring(err)
	print(("Flat UI: %s stopped. /flatui status shows why. Type /reload if the look is left half changed."):format(modules[key].label))
	if state.started and modules[key].Refresh then
		state.restoring = true
		pcall(modules[key].Refresh)
		state.restoring = nil
	end
end

local function RunDone(before, ...)
	running = before
	return ...
end

local function Run(key, fn, ...)
	local before = running
	running = key
	return RunDone(before, pcall(fn, ...))
end

function ns.Try(key, fn, ...)
	local state = status[key]
	if state.restoring then
		return (Run(key, fn, ...))
	elseif state.error then
		return false
	end
	local ok, err = Run(key, fn, ...)
	if not ok then
		Stop(key, err)
	end
	return ok
end

function ns.Each(key, fn, ...)
	local state = status[key]
	if state.restoring then
		return (Run(key, fn, ...))
	elseif state.error then
		return false
	end
	local ok, err = Run(key, fn, ...)
	if not ok then
		local id = (...) or fn
		state.failedFrames = state.failedFrames or setmetatable({}, { __mode = "k" })
		if not state.failedFrames[id] then
			state.failedFrames[id] = true
			state.failed = (state.failed or 0) + 1
			state.firstFailure = state.firstFailure or tostring(err)
			if state.failed >= MAX_FAILURES then
				Stop(key, state.firstFailure)
			end
		end
	end
	return ok
end

function ns.EachPart(key, part, fn, ...)
	local state = status[key]
	if state.restoring then
		return (Run(key, fn, ...))
	elseif state.error or (state.partsStopped and state.partsStopped[part]) then
		return false
	end
	local ok, err = Run(key, fn, ...)
	if not ok then
		err = tostring(err)
		local id = (...) or fn
		state.partFailures = state.partFailures or {}
		local record = state.partFailures[part]
		if not record then
			record = { count = 0, frames = setmetatable({}, { __mode = "k" }), first = err }
			state.partFailures[part] = record
		end
		if not record.frames[id] then
			record.frames[id] = true
			record.count = record.count + 1
			if record.count >= MAX_PART_FAILURES then
				state.partsStopped = state.partsStopped or {}
				state.partsStopped[part] = true
				record.note = ("%s: %s stopped. %s"):format(modules[key].label, part, record.first)
				ns.Note(key, record.note)
				print(("Flat UI: %s stopped in %s. /flatui status shows why."):format(part, modules[key].label))
			end
		end
		return false, err
	end
	return true
end

function ns.PartStopped(key, part)
	local stopped = status[key].partsStopped
	return stopped ~= nil and stopped[part] == true
end

function ns.IsStopped(key)
	return status[key].error ~= nil
end

function ns.Count(key, n)
	status[key].count = (status[key].count or 0) + (n or 1)
end

function ns.Note(key, text)
	local state = status[key]
	state.notes = state.notes or {}
	for _, note in ipairs(state.notes) do
		if note == text then
			return
		end
	end
	state.notes[#state.notes + 1] = text
end

function ns.ClearNote(key, text)
	local notes = status[key].notes or {}
	for index = #notes, 1, -1 do
		if notes[index] == text then
			table.remove(notes, index)
		end
	end
end

function ns.Register(key, module)
	modules[key] = module
	status[key] = {}
end

local addedEvents = setmetatable({}, { __mode = "k" })

function ns.AddEvent(key, event, fn, filter)
	local module = modules[key]
	if type(module) ~= "table" or type(event) ~= "string" or type(fn) ~= "function" then
		return false
	end
	module.events = module.events or {}
	module.filters = module.filters or {}
	addedEvents[module] = addedEvents[module] or {}
	local list = addedEvents[module][event]
	if list == nil then
		list = {}
		addedEvents[module][event] = list
		if module.events[event] then
			list[1] = { fn = module.events[event], filter = module.filters[event] }
		end
		module.events[event] = function(...)
			local failed, first = false, nil
			for _, entry in ipairs(list) do
				if not entry.filter or entry.filter(...) then
					local ok, err = pcall(entry.fn, ...)
					if not ok and not failed then
						failed, first = true, err
					end
				end
			end
			if failed then
				error(first, 0)
			end
		end
		module.filters[event] = function(...)
			for _, entry in ipairs(list) do
				if not entry.filter then
					return true
				end
				local ok, pass = pcall(entry.filter, ...)
				if ok and pass then
					return true
				end
			end
			return false
		end
	end
	list[#list + 1] = { fn = fn, filter = filter }
	return true
end

function ns.AddStatus(key, fn)
	local module = modules[key]
	if type(module) ~= "table" or type(fn) ~= "function" then
		return false
	end
	local status = module.Status
	module.Status = function(...)
		local lines = {}
		for _, line in ipairs(type(status) == "function" and status(...) or {}) do
			lines[#lines + 1] = line
		end
		local ok, more = pcall(fn)
		if ok and type(more) == "table" then
			for _, line in ipairs(more) do
				lines[#lines + 1] = line
			end
		end
		return lines
	end
	return true
end

function ns.AddSlash(key, word, fn, help)
	local module = modules[key]
	if type(module) ~= "table" or type(word) ~= "string" or type(fn) ~= "function" then
		return false
	end
	module.slash = module.slash or {}
	if module.slash[word] then
		return false
	end
	module.slash[word] = fn
	module.help = module.help or {}
	for _, line in ipairs(help or {}) do
		module.help[#module.help + 1] = line
	end
	return true
end

function ns.AddStart(key, fn)
	local module = modules[key]
	if type(module) ~= "table" or type(module.Start) ~= "function" or type(fn) ~= "function" then
		return false
	end
	local start = module.Start
	module.Start = function(...)
		start(...)
		fn(...)
	end
	return true
end

function ns.ModuleOn(key)
	local state = type(key) == "string" and status[key] or nil
	return state ~= nil and state.started == true and not state.error and ns.Enabled(key)
end

function ns.RefreshModule(key)
	if ns.ModuleOn(key) and modules[key].Refresh then
		return ns.Try(key, modules[key].Refresh)
	end
	return false
end

local function TestChanged(path)
	local test = ns.TestMode
	if type(test) == "table" and type(test.Changed) == "function" then
		local ok, err = pcall(test.Changed, path)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

local function StartModule(key)
	local module, state = modules[key], status[key]
	if state.started or not ns.Enabled(key) then
		return
	end
	state.started = true
	if module.Start and not ns.Try(key, module.Start) then
		state.startFailed = true
	end
end

local function Rearm(key)
	local state = status[key]
	for _, record in pairs(state.partFailures or {}) do
		if record.note then
			ns.ClearNote(key, record.note)
		end
	end
	state.error, state.failed, state.failedFrames, state.firstFailure = nil, nil, nil, nil
	state.partFailures, state.partsStopped = nil, nil
	if state.startFailed then
		state.started, state.startFailed = nil, nil
	end
end

local function Settle()
	local resized = not (InCombatLockdown() or resizePending)
	ns.ResizeAll()
	for _, key in ipairs(MODULE_ORDER) do
		local module = modules[key]
		if module and status[key].started and module.Refresh and not (resized and module.Resized == module.Refresh) then
			ns.Try(key, module.Refresh)
		end
	end
end

local function Reread(key)
	if loggedIn and modules[key] and status[key].started and modules[key].Refresh then
		ns.Try(key, modules[key].Refresh)
	end
end

local function Changed(path)
	local page = path:match("^(%w+)%.")
	local def = defs[path]
	local prefix, suffix = path:match("^%w+%.(%l+)(%u%a*)$")
	if prefix and PREFIXES[prefix] and SUFFIXES[suffix] and AREAS[page] then
		PaintAll()
	elseif def and def.changed then
		local call = ns[def.changed]
		if type(call) == "function" and loggedIn then
			local ok, err = pcall(call, path)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif page == "general" then
		PaintAll()
		settleCount = settleCount + 1
		local mine = settleCount
		if C_Timer and C_Timer.After then
			C_Timer.After(SETTLE, function()
				if mine == settleCount then
					Settle()
				end
			end)
		else
			Settle()
		end
	elseif modules[page] and loggedIn then
		local state = status[page]
		if path == page .. ".enabled" and ns.Get(path) then
			Rearm(page)
		end
		if not state.started then
			StartModule(page)
		elseif modules[page].Refresh then
			ns.Try(page, modules[page].Refresh)
		end
	end
	local readers = READERS[path]
	if type(readers) == "table" then
		for _, reader in ipairs(readers) do
			Reread(reader)
		end
	elseif readers then
		Reread(readers)
	end
end

function ns.Set(path, value, quiet)
	local def = defs[path]
	if not (db and def) then
		return
	end
	value = Normalise(def, value)
	if value == nil then
		return
	end
	if Unsaved(def) then
		if Same(ns.Get(path), value) then
			return
		end
		if def.set then
			local call = ns[def.set]
			if type(call) == "function" then
				local ok, err = pcall(call, def, value)
				if not ok then
					geterrorhandler()(err)
				end
			end
		elseif def.cvar then
			ns.CVarSet(def, value, quiet)
		end
		ns.settingsStamp = (ns.settingsStamp or 0) + 1
		if def.changed or not ns.RowLive(def) then
			Changed(path)
		end
		TestChanged(path)
		return
	end
	local changed = ns.Get(path) ~= value
	values[path] = value
	if changed then
		ns.settingsStamp = (ns.settingsStamp or 0) + 1
		Changed(path)
		TestChanged(path)
		if def.reload and ns.ReloadNoticeUpdate then
			ns.ReloadNoticeUpdate()
		end
	end
end

local reloadBase

function ns.ReloadStart()
	if reloadBase or not profile then
		return
	end
	reloadBase = {}
	for path, def in pairs(defs) do
		if def.reload and not Unsaved(def) then
			local value = profile.options and profile.options[path]
			if value == nil then
				value = def.default
			end
			reloadBase[path] = value
		end
	end
end

function ns.ReloadLines()
	local lines, seen = {}, {}
	if not (reloadBase and profile) then
		return lines
	end
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			local was = item.path and reloadBase[item.path]
			if was ~= nil and not seen[item.path] then
				seen[item.path] = true
				local now = profile.options and profile.options[item.path]
				if now == nil then
					now = item.default
				end
				local field = item.reload == true and "change" or item.reload
				if (field == "off" and was == true and now == false) or (field == "change" and was ~= now) then
					lines[#lines + 1] = { item.label, field, item.path, now, was }
				end
			end
		end
	end
	return lines
end

local function Version()
	if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
		return nil
	end
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
	if ok and not IsSecret(version) and type(version) == "string" and version ~= "" then
		return version
	end
	return nil
end

function ns.StatusLines()
	local version = Version()
	local lines = { version and ("Flat UI %s"):format(version) or "Flat UI", ("Profile: %s"):format(current),
		("Border thickness: %d px"):format(ns.Get("general.thickness")) }
	if ns.TaintLogging() then
		lines[#lines + 1] = ("taintLog is on: %d game methods not followed. Turn it off and reload to follow them."):format(skippedCount)
	end
	for _, key in ipairs(MODULE_ORDER) do
		local module, state = modules[key], status[key]
		if module then
			local line
			if state.error then
				line = ("%s: stopped. %s"):format(module.label, state.error)
			elseif not ns.Get(key .. ".enabled") then
				line = ("%s: off"):format(module.label)
			elseif not state.started then
				line = ("%s: on, not started"):format(module.label)
			else
				local noun = module.counted == nil and "styled" or module.counted
				line = noun and ("%s: on, %d %s"):format(module.label, state.count or 0, noun) or ("%s: on"):format(module.label)
				if state.failed then
					line = ("%s, %d failed. %s"):format(line, state.failed, state.firstFailure)
				end
			end
			lines[#lines + 1] = line
			for _, note in ipairs(state.notes or {}) do
				lines[#lines + 1] = note
			end
			for _, extra in ipairs(module.Status and module.Status() or {}) do
				lines[#lines + 1] = extra
			end
		end
	end
	local test = ns.TestMode and ns.TestMode.Status()
	if test then
		lines[#lines + 1] = test
	end
	if fontsOffered ~= nil then
		local offered = {}
		for _, face in ipairs(FONT_FACES) do
			if fontsOffered[face[1]] then
				offered[#offered + 1] = face[1]
			end
		end
		lines[#lines + 1] = "Fonts offered: " .. (#offered > 0 and table.concat(offered, ", ") or "none")
	end
	if #noArt > 0 then
		lines[#lines + 1] = "Class icons: no class art for " .. table.concat(noArt, ", ") .. "."
	end
	if ns.roundMissing then
		lines[#lines + 1] = "Round class icons: this client has no circle mask, so they show square."
	end
	local borderMode = ns.Get("general.borderMode")
	if borderMode == "class" or borderMode == "faction" then
		local br, bg, bb = ns.BorderRGB()
		local dr, dg, db = ns.Colour("general.border")
		if br == dr and bg == dg and bb == db then
			lines[#lines + 1] = ("Borders: no %s from the game, Border colour used."):format(borderMode)
		end
	end
	for _, line in ipairs(ns.GameSettingsStatus and ns.GameSettingsStatus() or {}) do
		lines[#lines + 1] = line
	end
	local scale = ns.ScaleStatus and ns.ScaleStatus()
	if scale then
		lines[#lines + 1] = scale
	end
	local sparkle = ns.SparkleStatus and ns.SparkleStatus()
	if sparkle then
		lines[#lines + 1] = sparkle
	end
	local glow = ns.SparkleGlowStatus and ns.SparkleGlowStatus()
	if glow then
		lines[#lines + 1] = glow
	end
	local camera = ns.CameraZoomStatus and ns.CameraZoomStatus()
	if camera then
		lines[#lines + 1] = camera
	end
	local ring = ns.CursorRingStatus and ns.CursorRingStatus()
	if ring then
		lines[#lines + 1] = ring
	end
	local lava = ns.LavaStatus and ns.LavaStatus()
	if lava then
		lines[#lines + 1] = lava
	end
	for _, line in ipairs(ns.SetupStatus and ns.SetupStatus() or {}) do
		lines[#lines + 1] = line
	end
	for _, line in ipairs(ns.PanelLookStatus and ns.PanelLookStatus() or {}) do
		lines[#lines + 1] = line
	end
	if #blocked > 0 then
		lines[#lines + 1] = "Blocked by the game: " .. table.concat(blocked, ", ")
	end
	for _, line in ipairs(ns.ClickPathLines()) do
		lines[#lines + 1] = line
	end
	for _, line in ipairs(ns.TaintLines and ns.TaintLines() or {}) do
		lines[#lines + 1] = line
	end
	if ns.ReloadIsSecure and ns.ReloadIsSecure() then
		lines[#lines + 1] = "Reload: secure button."
	end
	return lines
end

function ns.BlockedTotal()
	return blockedTotal
end

function ns.BlockedLast()
	return blockedLast
end

function ns.Character()
	return charDB
end

function ns.Account()
	return db
end

local function ReadCharacter()
	if type(UnitName) ~= "function" or type(GetRealmName) ~= "function" then
		return nil
	end
	local okName, name = pcall(UnitName, "player")
	local okRealm, realm = pcall(GetRealmName)
	if not (okName and okRealm) or IsSecret(name) or IsSecret(realm) or type(name) ~= "string" or type(realm) ~= "string"
		or name == "" or realm == "" or name == UNKNOWNOBJECT then
		return nil
	end
	return name .. " - " .. realm
end

local function OwnProfile(key)
	local kept = charDB and charDB.profile
	if type(kept) == "string" and db.profiles[kept] ~= nil then
		return kept
	end
	local byKey = key and type(db.profileOf) == "table" and db.profileOf[key]
	if type(byKey) == "string" and db.profiles[byKey] ~= nil then
		return byKey
	end
	return nil
end

local OLD_PLATE_OUTLINES = { "nameplates.nameOutline", "nameplates.healthTextOutline", "nameplates.castTextOutline" }
function ns.MigrateText(old, options)
	for _, path in ipairs(OLD_PLATE_OUTLINES) do
		if type(old[path]) == "boolean" then
			options[path] = old[path] and "game" or "none"
		end
	end
	if type(old["hud.hitTable"]) == "boolean" then
		options["hud.hitTable"] = old["hud.hitTable"] and "on" or "off"
	end
	if old["unitframes.lookWhiteNames"] == true and (options["unitframes.nameColour"] == nil or options["unitframes.nameColour"] == "game") then
		options["unitframes.nameColour"] = "white"
	end
end

local OFF_UNTIL_0527 = { ["consumables.enabled"] = true, ["datapanels.enabled"] = true, ["errands.enabled"] = true, ["fade.enabled"] = true,
	["grouptools.enabled"] = true, ["healermana.enabled"] = true, ["pulse.enabled"] = true, ["threat.enabled"] = true, ["tooltip.enabled"] = true }
local function KeepBagsOff(options)
	if options["bags.enabled"] ~= nil then
		return
	end
	local any = false
	for path, def in pairs(defs) do
		if def.key == "enabled" and def.kind == "bool" and def.default == true and path ~= "bags.enabled" and path ~= "barblock.enabled" and not OFF_UNTIL_0527[path] then
			if options[path] ~= false then
				return
			end
			any = true
		end
	end
	if any then
		options["bags.enabled"] = false
	end
end

local function NormaliseValues(options)
	for path, value in pairs(options) do
		local def = defs[path]
		if def and not Unsaved(def) then
			options[path] = Normalise(def, Renamed(path, value))
		else
			options[path] = nil
		end
	end
end

local function NormaliseSpots(spots)
	for name, entry in pairs(spots) do
		if type(name) ~= "string" or not ns.CleanSpot(entry) then
			spots[name] = nil
		end
	end
end

local function ScreenUnits(width, height, scale)
	local tall = 768 / scale
	return tall * width / height, tall
end

local function UnitsHere(options)
	if type(UIParent) ~= "table" or type(UIParent.GetWidth) ~= "function" or type(UIParent.GetHeight) ~= "function" then
		return nil
	end
	local okWidth, width = pcall(UIParent.GetWidth, UIParent)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if not (okWidth and okHeight and Finite(width) and Finite(height) and width > 0 and height > 0) then
		return nil
	end
	if type(ns.ScaleWanted) == "function" then
		local ok, scale = ns.Viewing(type(options) == "table" and options or {}, ns.ScaleWanted)
		if ok and Finite(scale) and scale > 0 then
			return ScreenUnits(width, height, scale)
		end
	end
	return width, height
end

function ns.FitSpots(spots, screen, options)
	local across, up = 1, 1
	if type(screen) == "table" and Finite(screen.width) and Finite(screen.height) and Finite(screen.scale) and screen.width > 0
		and screen.height > 0 and screen.scale > 0 then
		local hereWidth, hereHeight = UnitsHere(options)
		if hereWidth then
			local thereWidth, thereHeight = ScreenUnits(screen.width, screen.height, screen.scale)
			across, up = hereWidth / thereWidth, hereHeight / thereHeight
		end
	end
	local fitted = {}
	for frameName, spot in pairs(type(spots) == "table" and spots or {}) do
		local copy = {}
		for field, value in pairs(type(spot) == "table" and spot or {}) do
			copy[field] = value
		end
		if type(frameName) == "string" and ns.CleanSpot(copy) then
			copy.x, copy.y = copy.x * across, copy.y * up
			fitted[frameName] = copy
		end
	end
	return fitted
end

local function BaseSpots(options)
	for _, raw in ipairs(type(ns.SETUP_PROFILES) == "table" and ns.SETUP_PROFILES or {}) do
		if type(raw) == "table" and raw.base == true then
			local spots = {}
			for _, spot in ipairs(type(raw.movers) == "table" and raw.movers or {}) do
				if type(spot) == "table" and type(spot.frame) == "string" then
					spots[spot.frame] = { point = spot.point, x = spot.x, y = spot.y, scale = spot.scale, kind = spot.kind, label = spot.label }
				end
			end
			return ns.FitSpots(spots, raw.screen, options)
		end
	end
	return {}
end

local function FromOlder(version)
	local options = type(db.options) == "table" and db.options or {}
	for _, key in ipairs(LEGACY_MODULES) do
		if type(db[key]) == "boolean" then
			options[key .. ".enabled"] = db[key]
		end
		db[key] = nil
	end
	if type(db.thickness) == "number" then
		options["general.thickness"] = db.thickness
	end
	db.thickness = nil
	if version < 1 then
		for _, path in ipairs(RESET_SETTINGS) do
			local def, was = defs[path], options[path]
			if was ~= nil then
				options[path] = nil
				resetNotice = resetNotice or (def ~= nil and was ~= def.default)
			end
		end
	end
	return { options = options, movers = type(db.movers) == "table" and db.movers or {} }
end

local function LoadSettings()
	Define()
	if type(FlatUICharDB) ~= "table" then
		FlatUICharDB = {}
	end
	charDB = FlatUICharDB
	local fresh = type(FlatUIDB) ~= "table" or next(FlatUIDB) == nil
	FlatUIDB = FlatUIDB or {}
	db = FlatUIDB
	local version = tonumber(db.settingsVersion) or 0
	ns.newInstall = fresh
	if type(db.profiles) ~= "table" then
		db.profiles = { [DEFAULT] = FromOlder(version) }
		if fresh then
			db.profiles[DEFAULT].movers = BaseSpots(db.profiles[DEFAULT].options)
		end
	end
	db.options, db.movers = nil, nil
	for name, saved in pairs(db.profiles) do
		if type(name) ~= "string" or type(saved) ~= "table" then
			db.profiles[name] = nil
		else
			saved.options = type(saved.options) == "table" and saved.options or {}
			local old = saved.options["general.scale"]
			if type(old) == "number" and old == old and old < 65 then
				saved.options["general.scaleSmall"] = math.floor(old + 0.5)
				saved.options["general.scale"] = 65
				local wasOn = saved.options["general.scaleOn"]
				saved.options["general.scaleOn"] = false
				if wasOn == true then
					ns.scaleMoved = ns.scaleMoved or {}
					ns.scaleMoved[name] = saved.options["general.scaleSmall"]
				end
			end
			local ct = saved.options
			if ct["combattext.word"] == false and ct["combattext.partial"] == nil then
				ct["combattext.partial"] = "off"
			end
			if ct["combattext.ownMove"] ~= nil and ct["combattext.inStyle"] == nil then
				ct["combattext.inStyle"] = ct["combattext.ownMove"] == "arc" and "arc" or "straight"
			end
			local dimmed = ct["unitframes.partyRangeAlpha"]
			if type(dimmed) == "number" and dimmed == dimmed and ct["unitframes.partyRangeOpacity"] == nil then
				ct["unitframes.partyRangeOpacity"] = 100 - dimmed
			end
			if ns.MigrateSounds then
				ns.MigrateSounds(saved.options, not db.soundsMigrated)
			end
			if ns.MigrateBarBlock then
				ns.MigrateBarBlock(saved.options)
			end
			saved.movers = type(saved.movers) == "table" and saved.movers or {}
			ns.MigrateText(saved.options, saved.options)
			NormaliseValues(saved.options)
			if not db.bagsMigrated then
				KeepBagsOff(saved.options)
			end
			NormaliseSpots(saved.movers)
		end
	end
	for _, draft in pairs(type(db.setup) == "table" and type(db.setup.drafts) == "table" and db.setup.drafts or {}) do
		if ns.MigrateSounds and type(draft) == "table" and type(draft.values) == "table" then
			ns.MigrateSounds(draft.values, not db.soundsMigrated)
		end
	end
	db.soundsMigrated = true
	db.bagsMigrated = true
	if db.profiles[DEFAULT] == nil then
		db.profiles[DEFAULT] = { options = {}, movers = BaseSpots({}) }
	end
	if type(db.profileOf) ~= "table" then
		db.profileOf = {}
	end
	for key, name in pairs(db.profileOf) do
		if type(key) ~= "string" or db.profiles[name] == nil then
			db.profileOf[key] = nil
		end
	end
	if charDB.profile ~= nil and (type(charDB.profile) ~= "string" or db.profiles[charDB.profile] == nil) then
		charDB.profile = nil
	end
	characterKey = ReadCharacter()
	current = OwnProfile(characterKey) or DEFAULT
	profile = db.profiles[current]
	values = profile.options
	if version < SETTINGS_VERSION then
		db.settingsVersion = SETTINGS_VERSION
	end
end

function ns.Spots()
	if viewing then
		return viewing.spots
	end
	return profile and profile.movers
end

function ns.Profile()
	return current
end

function ns.Profiles()
	local names = {}
	for name in pairs(db and db.profiles or { [DEFAULT] = true }) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		local lowerA, lowerB = a:lower(), b:lower()
		if lowerA ~= lowerB then
			return lowerA < lowerB
		end
		return a < b
	end)
	return names
end

local function Find(name)
	if type(name) ~= "string" or IsSecret(name) then
		return nil
	end
	if db.profiles[name] then
		return name
	end
	local lower = name:lower()
	for _, stored in ipairs(ns.Profiles()) do
		if stored:lower() == lower then
			return stored
		end
	end
	return nil
end

local function CleanName(name)
	if type(name) == "string" and not IsSecret(name) then
		name = name:match("^%s*(.-)%s*$")
		local length = #(name:gsub("[\128-\191]", ""))
		if length >= 1 and length <= MAX_NAME and not name:find("[\r\n]") then
			return name
		end
	end
	return nil, ("Use 1 to %d characters on one line."):format(MAX_NAME)
end

function ns.ProfileNameCheck(name)
	local clean, why = CleanName(name)
	if not clean then
		return nil, why
	end
	if db and Find(clean) then
		return nil, "That name is taken."
	end
	return clean
end

function ns.CharacterKey()
	return characterKey or ReadCharacter()
end

local function Refusal()
	if not db then
		return "Profiles are not ready yet."
	end
	return InCombatLockdown() and "Profiles change after combat." or nil
end

local function Apply(wasSpots)
	ns.settingsStamp = (ns.settingsStamp or 0) + 1
	if ns.SpotsChanged then
		ns.SpotsChanged(wasSpots)
	end
	for _, key in ipairs(MODULE_ORDER) do
		if loggedIn and modules[key] and ns.Get(key .. ".enabled") then
			local state = status[key]
			if state.error or state.partsStopped then
				Rearm(key)
			end
			StartModule(key)
		end
	end
	PaintAll()
	Settle()
	if loggedIn and ns.ScaleChanged then
		ns.ScaleChanged("general.scale")
	end
	if loggedIn and ns.SparkleChanged then
		ns.SparkleChanged("general.questSparkle")
	end
	if loggedIn and ns.CursorRingChanged then
		ns.CursorRingChanged("general.cursorRing")
	end
	if loggedIn and ns.LavaChanged then
		ns.LavaChanged("general.lavaTimer")
	end
	if ns.NotifyOption then
		for path in pairs(defs) do
			ns.NotifyOption(path)
		end
	end
	if type(ns.RefreshPanel) == "function" then
		local ok, err = pcall(ns.RefreshPanel)
		if not ok then
			geterrorhandler()(err)
		end
	end
	TestChanged("*")
	if ns.ReloadNoticeUpdate then
		ns.ReloadNoticeUpdate()
	end
end

local function Enter(name)
	local was = profile.movers
	current = name
	profile = db.profiles[name]
	values = profile.options
	characterKey = characterKey or ReadCharacter()
	if characterKey then
		db.profileOf[characterKey] = name
	end
	charDB.profile = name
	Apply(was)
end

local kept = {}

local function Replace(options, movers, what)
	local was = profile.movers
	if what then
		kept.lost = { of = profile, options = profile.options, movers = movers ~= was and was or nil, what = what,
			at = type(date) == "function" and date("%H:%M") or "" }
	end
	profile.options, profile.movers = options, movers
	values = options
	Apply(was)
end

local function CopyOf(source)
	local copy = { options = {}, movers = {} }
	for path, value in pairs(source.options) do
		copy.options[path] = value
	end
	for name, entry in pairs(source.movers) do
		local spot = {}
		for field, value in pairs(entry) do
			spot[field] = value
		end
		copy.movers[name] = spot
	end
	return copy
end

function ns.UseProfile(name)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local found = Find(name)
	if not found then
		return false, "No such profile."
	end
	if found ~= current then
		Enter(found)
	end
	return true, ("Using %s."):format(found)
end

local function PutSpots(made, spots)
	for frameName, spot in pairs(type(spots) == "table" and spots or {}) do
		local copy = {}
		for field, value in pairs(type(spot) == "table" and spot or {}) do
			copy[field] = value
		end
		if type(frameName) == "string" and ns.CleanSpot(copy) then
			made.movers[frameName] = copy
		end
	end
end

function ns.NewProfile(name, copyFrom, picks, spots)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local clean, why = CleanName(name)
	if not clean then
		return false, why
	end
	if Find(clean) then
		return false, "That name is taken."
	end
	local source
	if copyFrom ~= nil then
		source = Find(copyFrom)
		if not source then
			return false, "No such profile."
		end
	end
	local made = source and CopyOf(db.profiles[source]) or { options = {}, movers = {} }
	if type(picks) == "table" then
		for path, value in pairs(picks) do
			local def = defs[path]
			if def and not Unsaved(def) then
				local fitted = Normalise(def, value)
				if fitted ~= nil then
					made.options[path] = fitted
				end
			end
		end
	end
	if source or spots ~= nil then
		PutSpots(made, spots)
	else
		made.movers = BaseSpots(made.options)
	end
	db.profiles[clean] = made
	Enter(clean)
	return true, ("Made %s."):format(clean)
end

function ns.Started()
	return loggedIn
end

function ns.AssignProfile(name, picks, spots)
	if loggedIn or not db or type(name) ~= "string" then
		return false
	end
	characterKey = characterKey or ReadCharacter()
	if not characterKey then
		return false
	end
	local found = Find(name)
	if not found then
		local clean = CleanName(name)
		if not clean then
			return false
		end
		local made = { options = {}, movers = {} }
		if type(picks) == "table" then
			for path, value in pairs(picks) do
				local def = defs[path]
				if def and not Unsaved(def) then
					local fitted = Normalise(def, value)
					if fitted ~= nil then
						made.options[path] = fitted
					end
				end
			end
		end
		if spots ~= nil then
			PutSpots(made, spots)
		else
			made.movers = BaseSpots(made.options)
		end
		db.profiles[clean] = made
		found = clean
	end
	db.profileOf[characterKey] = found
	charDB.profile = found
	current, profile = found, db.profiles[found]
	values = profile.options
	return true
end

function ns.OwnProfile()
	return db and OwnProfile(ns.CharacterKey()) or nil
end

local function LoginProfile()
	characterKey = ReadCharacter() or characterKey
	local own = OwnProfile(characterKey)
	if own then
		charDB.profile = own
		if characterKey then
			db.profileOf[characterKey] = own
		end
	end
	own = own or DEFAULT
	if own ~= current then
		current, profile = own, db.profiles[own]
		values = profile.options
	end
end

function ns.CopyProfile(from)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local source = Find(from)
	if not source then
		return false, "No such profile."
	elseif source == current then
		return false, "That is the profile in use."
	end
	local copy = CopyOf(db.profiles[source])
	Replace(copy.options, copy.movers, ("Copy from %s"):format(source))
	return true, ("Copied %s. Bring back on the Profiles page puts %s back until you reload."):format(source, current)
end

function ns.ChangeProfile(picks)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local copy = CopyOf(profile)
	for path, value in pairs(type(picks) == "table" and picks or {}) do
		local def = defs[path]
		if def and not Unsaved(def) then
			local fitted = Normalise(def, value)
			if fitted ~= nil then
				if fitted == def.default then
					copy.options[path] = nil
				else
					copy.options[path] = fitted
				end
			end
		end
	end
	Replace(copy.options, profile.movers, "setup's Finish")
	return true, ("Saved %s."):format(current)
end

function ns.RenameProfile(from, to)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	if not db then
		return false, "Profiles are not ready yet."
	end
	local found = Find(from)
	if not found then
		return false, "No such profile."
	elseif found == DEFAULT then
		return false, "Default cannot be renamed."
	end
	local clean, why = CleanName(to)
	if not clean then
		return false, why
	end
	local other = Find(clean)
	if other and other ~= found then
		return false, "That name is taken."
	end
	if clean ~= found then
		db.profiles[clean], db.profiles[found] = db.profiles[found], nil
		for key, used in pairs(db.profileOf) do
			if used == found then
				db.profileOf[key] = clean
			end
		end
		if charDB.profile == found then
			charDB.profile = clean
		end
		if current == found then
			current = clean
		end
		if ns.scaleMoved and ns.scaleMoved[found] ~= nil then
			ns.scaleMoved[clean], ns.scaleMoved[found] = ns.scaleMoved[found], nil
		end
		for _, draft in pairs(type(db.setup) == "table" and type(db.setup.drafts) == "table" and db.setup.drafts or {}) do
			if type(draft) == "table" and draft.from == found then
				draft.from = clean
			end
		end
		if ns.ProfileSwitch then
			ns.ProfileSwitch.Renamed(found, clean)
		end
		if ns.PanelHome and ns.PanelHome.Renamed then
			ns.PanelHome.Renamed(found, clean)
		end
		if type(ns.RefreshPanel) == "function" then
			local ok, err = pcall(ns.RefreshPanel)
			if not ok then
				geterrorhandler()(err)
			end
		end
	end
	return true, ("Renamed %s to %s."):format(found, clean)
end

function ns.DeleteProfile(name)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local found = Find(name)
	if not found then
		return false, "No such profile."
	elseif found == DEFAULT then
		return false, "Default cannot be deleted."
	elseif found == current then
		return false, "The profile in use cannot be deleted."
	end
	local users = {}
	for key, used in pairs(db.profileOf) do
		if used == found then
			users[#users + 1] = key
		end
	end
	kept.deleted = { name = found, data = db.profiles[found], users = users, mine = charDB.profile == found,
		rules = ns.ProfileSwitch and ns.ProfileSwitch.RulesOf and ns.ProfileSwitch.RulesOf(found) or nil }
	db.profiles[found] = nil
	if ns.ProfileSwitch then
		ns.ProfileSwitch.Deleted(found)
	end
	for key, used in pairs(db.profileOf) do
		if used == found then
			db.profileOf[key] = nil
		end
	end
	if charDB.profile == found then
		charDB.profile = nil
	end
	return true, ("Deleted %s. Bring back on the Profiles page puts it back until you reload."):format(found)
end

function ns.ResetProfile()
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	Replace({}, {}, "Reset profile")
	return true, ("Reset %s. Bring back on the Profiles page puts it back until you reload."):format(current)
end

local function LostName()
	local lost = kept.lost
	if not (lost and db) then
		return nil
	end
	for name, data in pairs(db.profiles) do
		if data == lost.of then
			return name
		end
	end
	return nil
end

function ns.LostProfile()
	local name = LostName()
	if not name then
		return nil
	end
	local lost = kept.lost
	local settings, spots = 0, nil
	for _ in pairs(lost.options) do
		settings = settings + 1
	end
	if lost.movers then
		spots = 0
		for _ in pairs(lost.movers) do
			spots = spots + 1
		end
	end
	return { name = name, what = lost.what, at = lost.at, settings = settings, spots = spots, inUse = name == current }
end

function ns.BringBackProfile()
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local lost, name = kept.lost, LostName()
	if not name then
		return false, "Nothing to bring back."
	elseif name ~= current then
		return false, ("Switch to %s first."):format(name)
	end
	Replace(lost.options, lost.movers or profile.movers, "you brought it back")
	return true, ("Brought back %s as it was before %s. Bring back again undoes this."):format(name, lost.what)
end

function ns.DeletedProfile()
	local gone = kept.deleted
	if gone and db and not Find(gone.name) then
		return gone.name
	end
	return nil
end

function ns.BringBackDeleted()
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local gone = kept.deleted
	if not gone then
		return false, "Nothing to bring back."
	elseif Find(gone.name) then
		return false, ("A profile named %s is there now. Rename it first."):format(gone.name)
	end
	kept.deleted = nil
	db.profiles[gone.name] = gone.data
	for _, key in ipairs(gone.users) do
		if db.profileOf[key] == nil then
			db.profileOf[key] = gone.name
		end
	end
	if gone.mine and charDB.profile == nil then
		charDB.profile = gone.name
	end
	if gone.rules and ns.ProfileSwitch and ns.ProfileSwitch.Restore then
		ns.ProfileSwitch.Restore(gone.name, gone.rules)
	end
	return true, ("Brought back %s."):format(gone.name)
end

local PREFIX = "FlatUI1:"
local DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VALUE_OF = {}
for index = 1, #DIGITS do
	VALUE_OF[DIGITS:sub(index, index)] = index - 1
end
local CHECK_LENGTH = 6

local function Digit(value)
	return DIGITS:sub(value + 1, value + 1)
end

local function Encode(data)
	local out = {}
	for at = 1, #data, 3 do
		local a, b, c = data:byte(at, at + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = Digit(math.floor(n / 262144)) .. Digit(math.floor(n / 4096) % 64)
		if b then
			chars = chars .. Digit(math.floor(n / 64) % 64)
		end
		if c then
			chars = chars .. Digit(n % 64)
		end
		out[#out + 1] = chars
	end
	return table.concat(out)
end

local function Decode(text)
	if #text % 4 == 1 then
		return nil
	end
	local out = {}
	for at = 1, #text, 4 do
		local group = text:sub(at, at + 3)
		local n = 0
		for index = 1, 4 do
			n = n * 64 + (VALUE_OF[group:sub(index, index)] or 0)
		end
		out[#out + 1] = string.char(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256):sub(1, #group - 1)
	end
	return table.concat(out)
end

local function Check(text)
	local sum = 0
	for index = 1, #text do
		sum = (sum * 65599 + text:byte(index)) % 4294967291
	end
	local chars = {}
	for place = CHECK_LENGTH - 1, 0, -1 do
		chars[#chars + 1] = Digit(math.floor(sum / 64 ^ place) % 64)
	end
	return table.concat(chars)
end

local function Escape(text)
	return (text:gsub("[%%|\r\n]", function(char)
		return ("%%%02X"):format(char:byte())
	end))
end

local function Unescape(text)
	return (text:gsub("%%(%x%x)", function(code)
		return string.char(tonumber(code, 16))
	end))
end

local function Parse(def, text)
	if def.kind == "bool" then
		if text == "1" then
			return true
		elseif text == "0" then
			return false
		end
		return nil
	elseif def.kind == "number" then
		return tonumber(text)
	end
	return text
end

local function HeaderLine()
	local width, height, scale = 0, 0, 0
	if type(GetPhysicalScreenSize) == "function" then
		local ok, w, h = pcall(GetPhysicalScreenSize)
		if ok and type(w) == "number" and type(h) == "number" and not IsSecret(w) and not IsSecret(h) and w > 0 and w < 1e6 and h > 0 and h < 1e6 then
			width, height = math.floor(w + 0.5), math.floor(h + 0.5)
		end
	end
	if type(UIParent) == "table" and type(UIParent.GetScale) == "function" then
		local ok, value = pcall(UIParent.GetScale, UIParent)
		if ok and type(value) == "number" and not IsSecret(value) and value == value and value < 1e6 then
			scale = value
		end
	end
	return table.concat({ "h", Escape(current or ""), Escape(Version() or ""), ("%d"):format(width), ("%d"):format(height), ("%.4g"):format(scale) }, "|")
end

function ns.ExportProfile(opts)
	if not profile then
		return ""
	end
	opts = type(opts) == "table" and opts or nil
	local modules = opts and type(opts.modules) == "table" and opts.modules or nil
	local lines, paths, names = {}, {}, {}
	for path, value in pairs(values) do
		if defs[path] and value ~= defs[path].default and (not modules or modules[path:match("^[^.]*")]) then
			paths[#paths + 1] = path
		end
	end
	local listed = {}
	for _, path in ipairs(paths) do
		listed[path] = true
	end
	if listed["enemycd.sound"] and not listed["enemycd.flash"] and defs["enemycd.flash"] then
		paths[#paths + 1] = "enemycd.flash"
	end
	table.sort(paths)
	for _, path in ipairs(paths) do
		local kind, value = defs[path].kind, values[path]
		if kind == "bool" then
			value = value and "1" or "0"
		elseif kind == "number" then
			value = ("%.17g"):format(value)
		end
		lines[#lines + 1] = table.concat({ "o", Escape(path), Escape(value) }, "|")
	end
	for name in pairs(opts and opts.spots == false and {} or profile.movers) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local spot = profile.movers[name]
		lines[#lines + 1] = table.concat({ "m", Escape(name), spot.point, ("%.17g"):format(spot.x), ("%.17g"):format(spot.y),
			spot.scale and ("%.17g"):format(spot.scale) or "", spot.kind, Escape(spot.label or "") }, "|")
	end
	if opts then
		table.insert(lines, 1, HeaderLine())
	end
	return ns.PackText(PREFIX, lines)
end

function ns.PackText(prefix, lines)
	local body = Encode(table.concat(lines, "\n"))
	return prefix .. body .. Check(body)
end

function ns.UnpackText(prefix, text)
	text = type(text) == "string" and not IsSecret(text) and text:match("^%s*(.-)%s*$") or ""
	if text:sub(1, #prefix) ~= prefix or text:find("[^A-Za-z0-9_%-]", #prefix + 1) then
		return nil, "prefix"
	end
	local rest = text:sub(#prefix + 1)
	local body = rest:sub(1, #rest - CHECK_LENGTH)
	local data = #rest >= CHECK_LENGTH and rest:sub(-CHECK_LENGTH) == Check(body) and Decode(body)
	if not data then
		return nil, "incomplete"
	end
	local lines = {}
	for line in (data .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

local function ReadProfile(text)
	local lines, why = ns.UnpackText(PREFIX, text)
	if not lines then
		return nil, why == "prefix" and "That is not a Flat UI profile." or "The text is incomplete."
	end
	local header, moved
	local options, spots, rawScale, oldWord, oldMove, oldDim, oldText, oldSound = {}, {}, nil, nil, nil, nil, {}, {}
	for _, line in ipairs(lines) do
		local fields = {}
		for field in (line .. "|"):gmatch("([^|]*)|") do
			fields[#fields + 1] = Unescape(field)
		end
		if fields[1] == "o" and (fields[2] == "cooldowns.readySound" or fields[2] == "enemycd.ready" or fields[2] == "enemycd.sound"
			or fields[2] == "enemycd.flash") then
			oldSound[fields[2]] = fields[3] == "1" and true or fields[3] == "0" and false or fields[3]
		end
		local def = fields[1] == "o" and defs[fields[2]]
		if fields[1] == "o" and (fields[3] == "1" or fields[3] == "0") then
			oldText[fields[2]] = fields[3] == "1"
		end
		if def and not Unsaved(def) then
			if fields[2] == "general.scale" then
				rawScale = Parse(def, fields[3])
			end
			options[fields[2]] = Normalise(def, Renamed(fields[2], Parse(def, fields[3])))
		elseif fields[1] == "h" then
			header = { name = fields[2], version = fields[3], width = tonumber(fields[4]) or 0, height = tonumber(fields[5]) or 0, scale = tonumber(fields[6]) or 0 }
		elseif fields[1] == "o" and fields[2] == "combattext.word" then
			oldWord = fields[3]
		elseif fields[1] == "o" and fields[2] == "combattext.ownMove" then
			oldMove = fields[3]
		elseif fields[1] == "o" and fields[2] == "unitframes.partyRangeAlpha" then
			oldDim = tonumber(fields[3])
		elseif fields[1] == "m" and fields[2] ~= "" then
			spots[fields[2]] = ns.CleanSpot({ point = fields[3], x = tonumber(fields[4]), y = tonumber(fields[5]), scale = tonumber(fields[6]),
				kind = fields[7], label = fields[8] ~= "" and fields[8] or nil })
		end
	end
	if ns.MigrateSounds then
		oldSound["trackers.kit"] = options["trackers.kit"]
		ns.MigrateSounds(oldSound, oldSound["enemycd.sound"] ~= nil and oldSound["enemycd.flash"] == nil)
		for _, path in ipairs({ "cooldowns.readySound", "enemycd.flash", "enemycd.sound" }) do
			if oldSound[path] ~= nil and defs[path] then
				options[path] = Normalise(defs[path], oldSound[path])
			end
		end
	end
	if oldWord == "0" and options["combattext.partial"] == nil and defs["combattext.partial"] then
		options["combattext.partial"] = "off"
	end
	if oldMove and options["combattext.inStyle"] == nil and defs["combattext.inStyle"] then
		options["combattext.inStyle"] = oldMove == "arc" and "arc" or "straight"
	end
	if oldDim and oldDim == oldDim and options["unitframes.partyRangeOpacity"] == nil and defs["unitframes.partyRangeOpacity"] then
		options["unitframes.partyRangeOpacity"] = Normalise(defs["unitframes.partyRangeOpacity"], 100 - oldDim)
	end
	ns.MigrateText(oldText, options)
	if type(rawScale) == "number" and rawScale == rawScale and rawScale < 65 and defs["general.scaleSmall"] then
		options["general.scaleSmall"] = Normalise(defs["general.scaleSmall"], math.floor(rawScale + 0.5))
		options["general.scale"] = 65
		if options["general.scaleOn"] == true then
			moved = options["general.scaleSmall"]
		end
		options["general.scaleOn"] = false
	end
	return options, spots, header, moved
end

function ns.ProfilePreview(text)
	local options, spots, header = ReadProfile(text)
	if not options then
		return nil, spots
	end
	local settings, positions = 0, 0
	for _ in pairs(options) do
		settings = settings + 1
	end
	for _ in pairs(spots) do
		positions = positions + 1
	end
	header = header or { name = "", version = "", width = 0, height = 0, scale = 0 }
	return { name = header.name, version = header.version, width = header.width, height = header.height, scale = header.scale, settings = settings,
		spots = positions }
end

function ns.ImportProfile(text, opts)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local options, spots, header, moved = ReadProfile(text)
	if not options then
		return false, spots
	end
	opts = type(opts) == "table" and opts or {}
	if opts.settings == false then
		options = nil
	end
	if opts.spots == false then
		spots = nil
	end
	if spots and opts.fit ~= false and type(header) == "table" and Finite(header.width) and header.width > 0 then
		spots = ns.FitSpots(spots, header, options or (opts.newName ~= nil and {} or CopyOf(profile).options))
	end
	if opts.newName ~= nil then
		local done, message = ns.NewProfile(opts.newName, nil, options or {}, spots)
		if not done then
			return false, message
		end
	else
		local copy = CopyOf(profile)
		Replace(options or copy.options, spots or copy.movers, "Import profile")
	end
	if moved and options then
		ns.scaleMoved = ns.scaleMoved or {}
		ns.scaleMoved[current] = moved
	end
	if opts.newName == nil then
		return true, ("Imported into %s. Bring back on the Profiles page puts back what it had until you reload."):format(current)
	end
	return true, ("Imported into %s."):format(current)
end

local frame = CreateFrame("Frame")
local moduleEvents = {}

local function Listen(event)
	return pcall(frame.RegisterEvent, frame, event)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
Listen("UI_SCALE_CHANGED")
Listen("DISPLAY_SIZE_CHANGED")
Listen("EDIT_MODE_LAYOUTS_UPDATED")
Listen("ADDON_ACTION_BLOCKED")
Listen("ADDON_ACTION_FORBIDDEN")
Listen("CVAR_UPDATE")
local taintNoticed = false

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == ADDON_NAME then
			LoadSettings()
			for key, module in pairs(modules) do
				for name in pairs(module.events or {}) do
					if not moduleEvents[name] then
						moduleEvents[name] = Listen(name) and {} or nil
					end
					if moduleEvents[name] then
						moduleEvents[name][key] = true
					end
				end
			end
			if ns.RegisterOptions then
				local ok, err = pcall(ns.RegisterOptions)
				if not ok then
					geterrorhandler()(err)
				end
			end
			return
		end
	end
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		local addon, call = ...
		if addon == ADDON_NAME then
			blockedTotal = blockedTotal + 1
			blockedLast = tostring(call)
			if #blocked < MAX_BLOCKED then
				blocked[#blocked + 1] = ("%s (%s)"):format(blockedLast, event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked")
			end
			if ns.TaintRecord then
				pcall(ns.TaintRecord, event, call)
			end
		end
		return
	end
	if event == "CVAR_UPDATE" then
		local name, value = ...
		if loggedIn and not taintNoticed and type(name) == "string" and name:lower() == "taintlog" and not IsSecret(value) and type(value) == "string"
			and value ~= "0" then
			taintNoticed = true
			print("Flat UI: taintLog is on. Turn it off with /console taintLog 0, then /reload.")
		end
	end
	if not db then
		return
	end
	if event == "PLAYER_LOGIN" then
		local claimed, why = pcall(LoginProfile)
		if not claimed then
			geterrorhandler()(why)
		end
		if ns.SetupAuto then
			local ok, err = pcall(ns.SetupAuto)
			if not ok then
				geterrorhandler()(err)
			end
		end
		ns.ReloadStart()
		loggedIn = true
		if resetNotice then
			resetNotice = false
			print("Flat UI: Unit frames portrait settings are back at their defaults.")
		end
		for _, key in ipairs(MODULE_ORDER) do
			if modules[key] then
				StartModule(key)
			end
		end
		if ns.TaintReminder and ns.TaintLogging() then
			ns.TaintReminder()
		end
		if ns.SetupLogin then
			local ok, err = pcall(ns.SetupLogin)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if ns.SparkleChanged then
			local ok, err = pcall(ns.SparkleChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if ns.CursorRingChanged then
			local ok, err = pcall(ns.CursorRingChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if ns.LavaChanged then
			local ok, err = pcall(ns.LavaChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if ns.ItemCompareSync then
			local ok, err = pcall(ns.ItemCompareSync)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if ns.QuestPagesSync then
			local ok, err = pcall(ns.QuestPagesSync)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if ns.ErrandsNavigationChanged then
			local ok, err = pcall(ns.ErrandsNavigationChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif event == "CVAR_UPDATE" then
		if loggedIn and ns.SparkleCVar then
			local ok, err = pcall(ns.SparkleCVar, ...)
			if not ok then
				geterrorhandler()(err)
			end
		end
		if loggedIn and ns.ErrandsNavigationCVar then
			local ok, err = pcall(ns.ErrandsNavigationCVar, ...)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		local queued = afterCombat
		afterCombat = {}
		for _, fn in ipairs(queued) do
			local ok, err = pcall(fn)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
		ns.ResizeAll()
	end
	local listeners = moduleEvents[event]
	if listeners then
		for key in pairs(listeners) do
			local filter = modules[key].filters and modules[key].filters[event]
			if status[key].started and ns.Enabled(key) and (not filter or filter(...)) then
				ns.Try(key, modules[key].events[event], ...)
			end
		end
	end
end)

SLASH_FLATUI1 = "/flatui"
SlashCmdList["FLATUI"] = function(msg)
	if not db then
		return
	end
	local typed = (msg or ""):match("^%s*(.-)%s*$")
	local text = typed:lower()
	local test = text:gsub("%s+", " ")
	if (test == "test" or test == "test on" or test == "test off") and ns.TestMode then
		local call = test == "test" and ns.TestMode.Toggle or test == "test on" and ns.TestMode.On or ns.TestMode.Off
		local ok, err = pcall(call, test == "test off" and "toggle" or "slash")
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	local verb, rest = typed:match("^(%S+)%s*(.-)$")
	if verb then
		for _, key in ipairs(MODULE_ORDER) do
			local command = modules[key] and modules[key].slash and modules[key].slash[verb:lower()]
			if command then
				local ok, err = pcall(command, rest)
				if not ok then
					geterrorhandler()(err)
				end
				return
			end
		end
	end
	if verb and verb:lower() == "cvar" and type(ns.CVarCommand) == "function" then
		local ok, err = pcall(ns.CVarCommand, rest)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "lava" and type(ns.LavaCommand) == "function" then
		local ok, err = pcall(ns.LavaCommand, rest)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if text == "taint" and type(ns.TaintCommand) == "function" then
		local ok, err = pcall(ns.TaintCommand)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "setup" and rest == "" and type(ns.OpenSetup) == "function" then
		local ok, err = pcall(ns.OpenSetup)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "welcome" and rest == "" and type(ns.OpenWelcome) == "function" then
		local ok, err = pcall(ns.OpenWelcome)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "profiles" and rest == "" and type(ns.OpenProfiles) == "function" then
		local ok, err = pcall(ns.OpenProfiles)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and (verb:lower() == "new" or verb:lower() == "changes") and type(ns.WhatsNewCommand) == "function" then
		local ok, err = pcall(ns.WhatsNewCommand, rest)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if text == "" and type(ns.OpenPanel) == "function" then
		local ok, err = pcall(ns.OpenPanel)
		if ok then
			return
		end
		geterrorhandler()(err)
	end
	if text == "" or text == "options" then
		local opened, reason = false, nil
		if ns.OpenOptions then
			opened, reason = ns.OpenOptions()
		end
		if reason == "combat" then
			print("Flat UI: options open after combat.")
		elseif not opened then
			for _, line in ipairs(ns.StatusLines()) do
				print(line)
			end
		end
	elseif text == "status" then
		for _, line in ipairs(ns.StatusLines()) do
			print(line)
		end
	elseif text == "profile" then
		local others = {}
		for _, name in ipairs(ns.Profiles()) do
			if name ~= current then
				others[#others + 1] = name
			end
		end
		print(("Flat UI: profile %s. %s"):format(tostring(current), #others > 0 and ("Others: %s."):format(table.concat(others, ", ")) or "No other profiles."))
	elseif verb and verb:lower() == "profile" then
		local function Miss()
			print(("Flat UI: no profile named %s. Profiles: %s."):format(rest, table.concat(ns.Profiles(), ", ")))
		end
		local found = db and InCombatLockdown() and Find(rest)
		if db and InCombatLockdown() and not found then
			Miss()
		elseif found and found ~= current and ns.ProfileSwitch and ns.ProfileSwitch.Keep then
			ns.ProfileSwitch.Keep(found)
			print(("Flat UI: switches to %s when the fight ends."):format(found))
			if type(ns.RefreshPanel) == "function" then
				pcall(ns.RefreshPanel)
			end
		elseif found and found == current and ns.ProfileSwitch and ns.ProfileSwitch.Keep then
			ns.ProfileSwitch.Keep(nil)
			print(("Flat UI: stays on %s."):format(found))
		else
			local done, message = ns.UseProfile(rest)
			if not done and message == "No such profile." then
				Miss()
			else
				print("Flat UI: " .. (tostring(message):gsub("^%u", string.lower)))
			end
		end
	elseif text == "scale off" or text:find("^scale%s+%d+$") then
		local percent = tonumber(text:match("%d+"))
		if percent and (percent < 35 or percent > 115) then
			print("Flat UI: /flatui scale takes 35 to 115.")
			return
		elseif not percent then
			ns.Set("general.scaleOn", false)
		elseif percent >= 65 then
			ns.Set("general.scale", percent)
			ns.Set("general.pixelPerfect", false)
			ns.Set("general.scaleBelow", false)
			ns.Set("general.scaleOn", true)
		else
			ns.Set("general.scaleSmall", percent)
			ns.Set("general.pixelPerfect", false)
			ns.Set("general.scaleBelow", true)
			ns.Set("general.scaleOn", true)
		end
		if type(ns.RefreshPanel) == "function" then
			pcall(ns.RefreshPanel)
		end
		if type(ns.ScaleTell) == "function" then
			ns.ScaleTell()
		end
	elseif text ~= "help" and text ~= "?" and type(ns.OpenPanelSearch) == "function" then
		local ok, err = pcall(ns.OpenPanelSearch, typed)
		if not ok then
			geterrorhandler()(err)
		end
	else
		print("/flatui - the settings window")
		print("/flatui options - the page in the game's options")
		print("/flatui status - what is styled, and any error")
		print("/flatui profile - the profile in use and the others")
		print("/flatui profile Name - switch to a profile; in a fight it switches as the fight ends")
		print("/flatui setup - walk round your screen in six short stops")
		print("/flatui profiles - the ready-made looks; a click puts one in use")
		print("/flatui welcome - the welcome screen")
		print("/flatui new - what changed in this version; /flatui new 0.5.41 shows that version (changes works too)")
		print("/flatui scale 70 - the UI scale in percent, 35 to 115; under 65 uses Small scale")
		print("/flatui scale off - the game's own UI scale")
		print("/flatui <words> - opens the options window and searches for them")
		print("/flatui #changed - every setting you changed")
		print("/flatui test - samples of your hidden frames on screen until you turn it off; test on and test off also work")
		print("/flatui taint - the action button click path, checked for values an add-on changed")
		print("/flatui lava - what the lava tick timer sees; lava test shows a sample, lava trace prints each hit on you")
		print("/flatui cvar - each game setting row: value, default, secure flag")
		print("/flatui cvar check - whether each of those can be changed, out of combat")
		for _, key in ipairs(MODULE_ORDER) do
			for _, line in ipairs(modules[key] and modules[key].help or {}) do
				print(line)
			end
		end
	end
end
