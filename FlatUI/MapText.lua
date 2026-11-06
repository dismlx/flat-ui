local _, ns = ...

-- Text around the minimap: small lines of the addon's own above or below the map, each with its rows on the Minimap tab (hud.mapCoords and the
-- rows after it), part "map text" of the hud module, which stops alone after a few failures. The lines are font strings on a frame of the
-- addon's own, a child of the minimap the size of the map that takes no mouse, so they move, scale and hide with the map. The frame is made out
-- of combat, or on a minimap the game does not protect, and only while a line has something the client can give; the text, its colour and its
-- place are set at any time. Nothing of the game's is written: of the minimap only its level and whether it is protected are read, and its
-- OnShow is followed with HookScript, which writes nothing on the frame.
--   Coordinates: the player's place on the map of the zone, from C_Map.GetBestMapForUnit("player") and C_Map.GetPlayerMapPosition(map,
--     "player"), whose x and y are read as fields (the game's own line calls GetXY of that table: Mainline/Minimap.lua:1434-1457). Neither is
--     secret on Forever, only their arguments are guarded (MapDocumentation.lua:49-63, 437-452), and the position is nil where the game
--     withholds it. Nothing shows in an instance (IsInInstance). 0 to 2 decimals.
--   Durability: the lowest share of the current to the most durability of the equipped items (GetInventoryItemDurability, slots 1 to 19),
--     white, yellow at 50% or less and red at 20% or less, in the colours of the game's damaged and broken items (INVENTORY_ALERT_COLORS,
--     Blizzard_DurabilityFrame/DurabilityFrame.lua:14-16). It is read on the game's durability and equipment events and a second after a
--     death or a release, never on a timer, and not at all where the game rule RepairArmorDisabled is on (DurabilityFrame.lua:51-55).
--   Frame rate and latency: GetFramerate, and the home and world latency of GetNetStats.
--   Time: local time (date, as GameTime_GetLocalTime) or realm time (GetGameTime), 12 or 24 hours, in the game's own formats when it has
--     them (Blizzard_FrameXMLUtil/GameTimeUtil.lua:9-33).
-- The coordinates, the frame rate and the time are read by one ticker (C_Timer.NewTicker): every 0.2 seconds while coordinates are wanted, every
-- second otherwise. It runs only while one of them can be shown and the frame is on the screen: it stops when the frame hides with the map, and
-- the map showing again starts it. A line whose value the game withholds is hidden, and the lines of its place close up; /flatui status says why.
-- The game's own coordinates under the map (Mainline/Minimap.xml:287-301, shown while its minimapShowPlayerCoords variable is on, Options,
-- Interface, Coordinates) are left alone: the lines below the map start under them while that variable is on. MapButtons.lua leaves room under
-- the map for the lines below it (ns.MapTextBelow).
-- These follow the minimap stats of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission.

local KEY, PART = "hud", "map text"
-- The lines, from the map outwards: the row of each, the row of its place, and how often the ticker reads it (none: on events only).
local LINES = {
	{ id = "coords", option = "mapCoords", place = "mapCoordsPlace", every = 0.2, label = "Coordinates" },
	{ id = "durability", option = "mapDurability", place = "mapDurabilityPlace", label = "Durability" },
	{ id = "perf", option = "mapPerf", place = "mapPerfPlace", every = 1, label = "Frame rate and latency" },
	{ id = "clock", option = "mapClock", place = "mapClockPlace", every = 1, label = "Time" },
}
-- Between the map and the first line, between two lines, and from the map to the first line below while the game's own coordinates show there
-- (its line ends 18 under the map: Mainline/Minimap.xml:287-291). LINE is the height of a line when the client does not say it.
local GAP, SPACING, UNDER_GAME, LINE = 4, 2, 21, 10
-- The frame of the lines is this many levels over the map, over the ring of the game's minimap.
local RAISE = 5
local WHITE, YELLOW, RED = { 1, 1, 1 }, { 1, 0.82, 0.18 }, { 0.93, 0.07, 0.07 }
-- The equipped slots (INVSLOT_FIRST_EQUIPPED to INVSLOT_LAST_EQUIPPED).
local FIRST_SLOT, LAST_SLOT = 1, 19
-- The seconds between two reads of the lines that change once a second or less.
local SLOW = 1

-- frame: the frame of the lines; text[id]: the font string of a line; shown[id]: its text while it shows; colour[id]: its colour; why[id]: why a
-- wanted line is hidden, for /flatui status; ticker, step, slow: the ticker, its step and the time since the slow lines were read; sig: the
-- layout last made; game: the game's own coordinates show under the map; below: the room the lines take under the map; queued, waiting,
-- hooked: a pass waits for the next frame, a make for the end of a fight, the map's OnShow is followed.
local S = { text = {}, shown = {}, colour = {}, why = {}, below = 0 }

-- The first value of a call that may be missing, raise or be withheld; nil then.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

-- A field of a table the game gave, or nil when the read raises or the value is withheld.
local function Field(t, key)
	if t == nil or ns.IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Wanted(line)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt(line.option) == true
end

-- The map calls of the client, or nil on a client without them.
local function MapCalls()
	local api = _G.C_Map
	if type(api) ~= "table" or ns.IsSecret(api) or type(api.GetBestMapForUnit) ~= "function" or type(api.GetPlayerMapPosition) ~= "function" then
		return nil
	end
	return api
end

-- True inside a dungeon, a raid, a battleground or an arena. An answer the game withholds counts as outside: the position is asked for then.
local function InInstance()
	return Ask(_G.IsInInstance) == true
end

local function LocalTime()
	return Opt("mapClockTime") ~= "realm"
end

-- True when the client has the calls of a line.
local function Available(line)
	if line.id == "coords" then
		return MapCalls() ~= nil
	elseif line.id == "durability" then
		return type(_G.GetInventoryItemDurability) == "function"
	elseif line.id == "perf" then
		return type(_G.GetFramerate) == "function" or type(_G.GetNetStats) == "function"
	elseif LocalTime() then
		return type(_G.date) == "function"
	end
	return type(_G.GetGameTime) == "function"
end

-- True when the ticker has a line to read: wanted, with the client's calls, and for the coordinates outside an instance.
local function Live(line)
	return line.every ~= nil and Wanted(line) and Available(line) and not (line.id == "coords" and InInstance())
end

-- The readers: the text of a line and its colour, or nil and why it is hidden. A client without the calls of a line has no line and no reason.

local function Coords()
	local api = MapCalls()
	if not api then
		return nil
	end
	if InInstance() then
		return nil, "hidden in an instance"
	end
	local map = Ask(api.GetBestMapForUnit, "player")
	local position = ns.Finite(map) and map > 0 and Ask(api.GetPlayerMapPosition, map, "player") or nil
	local x, y = Field(position, "x"), Field(position, "y")
	if not (ns.Finite(x) and ns.Finite(y)) or (x == 0 and y == 0) then
		return nil, "hidden, the game gives no position here"
	end
	local decimals = tonumber(Opt("mapCoordsDecimals")) or 1
	decimals = math.max(0, math.min(2, math.floor(decimals)))
	return ("%." .. decimals .. "f, %." .. decimals .. "f"):format(x * 100, y * 100)
end

-- True where the game rule that keeps gear from wearing out is on.
local function NoWear()
	local rules = _G.C_GameRules
	local rule = Field(Field(_G.Enum, "GameRule"), "RepairArmorDisabled")
	if type(rules) ~= "table" or ns.IsSecret(rules) or rule == nil then
		return false
	end
	return Ask(rules.IsGameRuleActive, rule) == true
end

local function Durability()
	local read = _G.GetInventoryItemDurability
	if type(read) ~= "function" then
		return nil
	end
	if NoWear() then
		return nil, "hidden, gear does not wear out here"
	end
	local lowest
	for slot = FIRST_SLOT, LAST_SLOT do
		local ok, now, most = pcall(read, slot)
		if ok and ns.Finite(now) and ns.Finite(most) and most > 0 then
			local share = math.max(0, math.min(100, math.floor(now / most * 100)))
			lowest = lowest and math.min(lowest, share) or share
		end
	end
	if not lowest then
		return nil, "hidden, nothing you wear has durability"
	end
	local word = _G.DURABILITY
	if ns.IsSecret(word) or type(word) ~= "string" or word == "" then
		word = "Durability"
	end
	return ("%s %d%%"):format(word, lowest), (lowest <= 20 and RED) or (lowest <= 50 and YELLOW) or WHITE
end

local function Perf()
	local rate, net = _G.GetFramerate, _G.GetNetStats
	if type(rate) ~= "function" and type(net) ~= "function" then
		return nil
	end
	local parts = {}
	local fps = Ask(rate)
	if ns.Finite(fps) and fps >= 0 then
		parts[#parts + 1] = ("%d fps"):format(math.floor(fps + 0.5))
	end
	if type(net) == "function" then
		local ok, _, _, home, world = pcall(net)
		if ok and ns.Finite(home) and ns.Finite(world) and home >= 0 and world >= 0 then
			parts[#parts + 1] = ("%d / %d ms"):format(math.floor(home + 0.5), math.floor(world + 0.5))
		end
	end
	if #parts == 0 then
		return nil, "hidden, the game does not say them"
	end
	return table.concat(parts, "   ")
end

-- A time in a format of the game's when it has one that works, else in plain digits.
local function Formatted(pattern, fallback, ...)
	if not ns.IsSecret(pattern) and type(pattern) == "string" then
		local ok, text = pcall(string.format, pattern, ...)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return fallback:format(...)
end

local function Clock()
	local hour, minute
	if LocalTime() then
		local now = _G.date
		if type(now) ~= "function" then
			return nil
		end
		local ok, parts = pcall(now, "*t")
		if ok then
			hour, minute = Field(parts, "hour"), Field(parts, "min")
		end
	else
		local realm = _G.GetGameTime
		if type(realm) ~= "function" then
			return nil
		end
		local ok, h, m = pcall(realm)
		if ok then
			hour, minute = h, m
		end
	end
	if not (ns.Finite(hour) and ns.Finite(minute)) then
		return nil, "hidden, the game does not say the time"
	end
	hour, minute = math.floor(hour) % 24, math.floor(minute) % 60
	if Opt("mapClockHours") ~= "12" then
		return Formatted(_G.TIMEMANAGER_TICKER_24HOUR, "%02d:%02d", hour, minute)
	end
	local shown = hour % 12
	shown = shown == 0 and 12 or shown
	if hour < 12 then
		return Formatted(_G.TIME_TWELVEHOURAM, "%d:%02d AM", shown, minute)
	end
	return Formatted(_G.TIME_TWELVEHOURPM, "%d:%02d PM", shown, minute)
end

local READ = { coords = Coords, durability = Durability, perf = Perf, clock = Clock }

-- Drawing ---------------------------------------------------------------------------------------------------------------------------------

local Queue

-- MapButtons.lua puts its row of addon buttons under the lines below the map.
local function SetBelow(room)
	if room == S.below then
		return
	end
	S.below = room
	if ns.MapButtonsChanged and ns.Get("hud.addonButtons") == "bar" then
		pcall(ns.MapButtonsChanged)
	end
end

local function StopTicker()
	if S.ticker and S.ticker.Cancel then
		pcall(S.ticker.Cancel, S.ticker)
	end
	S.ticker, S.step = nil, nil
end

-- The game's own coordinates show under the map while its variable is on.
local function GameCoords()
	local cvar = _G.C_CVar
	if type(cvar) ~= "table" or ns.IsSecret(cvar) then
		return false
	end
	return Ask(cvar.GetCVar, "minimapShowPlayerCoords") == "1"
end

-- Makes the frame of the lines on the map, once. False while it cannot be made now: in a fight on a map the game may protect, the make waits
-- for the end of the fight.
local function Make(map)
	if S.frame then
		return true
	end
	if InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(map)) then
		if not S.waiting then
			S.waiting = true
			ns.OutOfCombat(function()
				S.waiting = false
				Queue()
			end)
		end
		return false
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, map)
	if not ok or type(frame) ~= "table" then
		return false
	end
	ns.Own[frame] = true
	frame:SetAllPoints(map)
	local level = Ask(map.GetFrameLevel, map)
	if ns.Finite(level) then
		frame:SetFrameLevel(level + RAISE)
	end
	-- The frame hides with the map, and the ticker stops with it.
	frame:SetScript("OnHide", StopTicker)
	S.frame = frame
	if not S.hooked and type(map.HookScript) == "function" then
		S.hooked = true
		pcall(map.HookScript, map, "OnShow", function()
			Queue()
		end)
	end
	return true
end

local function Hide(line)
	local text = S.text[line.id]
	if text and S.shown[line.id] then
		text:Hide()
	end
	S.shown[line.id] = nil
end

local function Show(line, value, colour)
	local text = S.text[line.id]
	if not text then
		text = ns.OwnText(S.frame, "OVERLAY", "GameFontHighlightSmall")
		if not text then
			return
		end
		text:SetJustifyH("CENTER")
		text:Hide()
		S.text[line.id] = text
	end
	colour = colour or WHITE
	if S.colour[line.id] ~= colour then
		text:SetTextColor(colour[1], colour[2], colour[3])
		S.colour[line.id] = colour
	end
	if S.shown[line.id] ~= value then
		if S.shown[line.id] == nil then
			text:Show()
		end
		text:SetText(value)
		S.shown[line.id] = value
	end
end

local function Read(line)
	S.why[line.id] = nil
	if not Wanted(line) then
		Hide(line)
		return
	end
	local value, more = READ[line.id]()
	if type(value) == "string" then
		Show(line, value, type(more) == "table" and more or nil)
	else
		S.why[line.id] = type(more) == "string" and more or nil
		Hide(line)
	end
end

-- The height of a line as the client gives it, else LINE.
local function Height(text)
	local height = Ask(text.GetStringHeight, text)
	return ns.Finite(height) and height > 0 and height or LINE
end

-- The plate of the zone name, MinimapCluster.ZoneTextButton, 152 by 23 (Blizzard_Minimap/Mainline/Minimap.xml:24,
-- Camelot/MinimapZoneTextButton.xml:9-12). The game puts it over the map; Edit Mode's Header Underneath puts it under the map
-- (Camelot/Minimap.lua:68-80, Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:1794-1797). Its side of the map and how far its near and
-- its far edge are from that edge of the map, in the units of the frame of the lines; nil while it is beside the map, hidden, or the client
-- does not say where it is. Only region calls of the client are made on it, and nothing is written.
local function Plate()
	local button = Field(_G.MinimapCluster, "ZoneTextButton")
	if ns.Forbidden(button) or Ask(button.IsVisible, button) ~= true then
		return nil
	end
	local top, bottom, scale = Ask(button.GetTop, button), Ask(button.GetBottom, button), Ask(button.GetEffectiveScale, button)
	local frame = S.frame
	local mapTop, mapBottom, own = Ask(frame.GetTop, frame), Ask(frame.GetBottom, frame), Ask(frame.GetEffectiveScale, frame)
	if not (ns.Finite(top) and ns.Finite(bottom) and ns.Finite(scale) and ns.Finite(mapTop) and ns.Finite(mapBottom) and ns.Finite(own))
		or scale <= 0 or own <= 0 then
		return nil
	end
	top, bottom = top * scale / own, bottom * scale / own
	if bottom >= mapTop then
		return "above", bottom - mapTop, top - mapTop
	elseif top <= mapBottom then
		return "below", mapBottom - top, mapBottom - bottom
	end
	return nil
end

-- Puts the lines that show one after another, out from the map on each side, when which lines show, where, or the plate of the zone name has
-- changed. Over the map, where the game puts the plate, the screen ends above it: the lines above that do not fit between the map and the plate
-- go below. Under the map (Header Underneath), a line below that would reach the plate goes on under it.
local function Layout()
	local places, sig = {}, { S.game and "game" or "" }
	local side, near, far = Plate()
	local used
	for _, line in ipairs(LINES) do
		if S.shown[line.id] then
			local place = Opt(line.place) == "above" and "above" or "below"
			if place == "above" and side == "above" then
				used = (used and used + SPACING or GAP) + Height(S.text[line.id])
				if used > near then
					place = "below"
				end
			end
			places[line.id] = place
			sig[#sig + 1] = line.id .. "=" .. place
		end
	end
	if side then
		sig[#sig + 1] = ("plate=%s %d %d"):format(side, math.floor(near + 0.5), math.floor(far + 0.5))
	end
	sig = table.concat(sig, " ")
	if sig == S.sig then
		return
	end
	S.sig = sig
	local last, room = {}, 0
	local first = S.game and UNDER_GAME or GAP
	for _, line in ipairs(LINES) do
		local place, text = places[line.id], S.text[line.id]
		if place and text then
			local before = last[place]
			text:ClearAllPoints()
			if place == "above" then
				if before then
					text:SetPoint("BOTTOM", before, "TOP", 0, SPACING)
				else
					text:SetPoint("BOTTOM", S.frame, "TOP", 0, GAP)
				end
			else
				local at = before and room + SPACING or first
				if side == "below" and at + Height(text) > near and at < far + GAP then
					at = far + GAP
				end
				text:SetPoint("TOP", S.frame, "BOTTOM", 0, -at)
				room = at + Height(text)
			end
			last[place] = text
		end
	end
	SetBelow(room)
end

-- Reads the lines given (all of them without a list) and lays them out.
local function Pass(which)
	for _, line in ipairs(LINES) do
		if not which or which[line.id] then
			Read(line)
		end
	end
	Layout()
end

local function HideAll()
	for _, line in ipairs(LINES) do
		Hide(line)
		S.why[line.id] = nil
	end
	if S.frame then
		S.frame:Hide()
	end
	StopTicker()
	S.sig = nil
	SetBelow(0)
end

local FAST_LINES, SLOW_LINES = { coords = true }, { coords = true, perf = true, clock = true }

local function Step()
	local step = S.step or SLOW
	S.slow = (S.slow or 0) + step
	if S.slow >= SLOW - 1e-6 then
		S.slow = 0
		Pass(SLOW_LINES)
	else
		Pass(FAST_LINES)
	end
end

-- One step of the ticker. Each run has a key of its own, so every failure counts toward stopping the part; a stopped part takes its lines away.
local function Tick()
	if ns.IsStopped(KEY) or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not S.frame then
		StopTicker()
		if ns.PartStopped(KEY, PART) then
			pcall(HideAll)
		end
		return
	end
	if not ns.EachPart(KEY, PART, Step, {}) and ns.PartStopped(KEY, PART) then
		pcall(HideAll)
	end
end

-- Starts the ticker at the step of the quickest line it has to read, or stops it when it has none or the frame is not on the screen.
local function Ticker()
	local step
	for _, line in ipairs(LINES) do
		if Live(line) then
			step = math.min(step or line.every, line.every)
		end
	end
	if not step or not S.frame or Ask(S.frame.IsVisible, S.frame) ~= true then
		StopTicker()
		return
	end
	if S.ticker and S.step == step then
		return
	end
	StopTicker()
	if type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
		return
	end
	local ok, ticker = pcall(C_Timer.NewTicker, step, Tick)
	if ok and type(ticker) == "table" then
		S.ticker, S.step, S.slow = ticker, step, 0
	end
end

-- True while a line is wanted and the client has its calls: only then is the frame made.
local function Needed()
	for _, line in ipairs(LINES) do
		if Wanted(line) and Available(line) then
			return true
		end
	end
	return false
end

local function Update()
	local map = _G.Minimap
	if not Needed() or map == nil or ns.Forbidden(map) then
		HideAll()
		return
	end
	if not Make(map) then
		return
	end
	S.game = GameCoords()
	S.frame:Show()
	Pass()
	Ticker()
end

local function Draw()
	if not ns.PartStopped(KEY, PART) and ns.EachPart(KEY, PART, Update, {}) then
		return
	end
	if ns.PartStopped(KEY, PART) then
		pcall(HideAll)
	end
end

Queue = function()
	if S.queued then
		return
	end
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		Draw()
		return
	end
	S.queued = true
	C_Timer.After(0, function()
		S.queued = false
		if not ns.IsStopped(KEY) then
			Draw()
		end
	end)
end

-- An event is looked at on the next frame, only while a line can show or the frame is there to hide.
local function Relevant()
	return S.frame ~= nil or Needed()
end

local function Changed()
	if Relevant() then
		Queue()
	end
end

-- The game settles the durability of a death or a release a moment after it.
local function Later()
	if Relevant() and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(1, Queue)
	end
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" }) do
	ns.AddEvent(KEY, event, Changed)
end
for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_UNGHOST" }) do
	ns.AddEvent(KEY, event, Later)
end
ns.AddEvent(KEY, "CVAR_UPDATE", Changed, function(name)
	return not ns.IsSecret(name) and name == "minimapShowPlayerCoords"
end)

-- /flatui status says why a wanted line is hidden.
ns.AddStatus(KEY, function()
	local lines = {}
	for _, line in ipairs(LINES) do
		if S.why[line.id] and Wanted(line) then
			lines[#lines + 1] = ("%s: %s."):format(line.label, S.why[line.id])
		end
	end
	return lines
end)

-- Hud.lua calls this at the end of RefreshMinimap: a changed row, the page, the profile, the size of the screen, a new world.
function ns.MapTextRefresh()
	Draw()
end

-- The room the lines below the map take under it, in the units of the map; 0 while none shows.
function ns.MapTextBelow()
	return S.below
end
