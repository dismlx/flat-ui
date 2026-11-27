local _, ns = ...

local KEY, PART = "hud", "map text"
local LINES = {
	{ id = "coords", option = "mapCoords", place = "mapCoordsPlace", every = 0.2, label = "Coordinates" },
	{ id = "durability", option = "mapDurability", place = "mapDurabilityPlace", label = "Durability" },
	{ id = "perf", option = "mapPerf", place = "mapPerfPlace", every = 1, label = "Frame rate and latency" },
	{ id = "clock", option = "mapClock", place = "mapClockPlace", every = 1, label = "Time" },
}
local GAP, SPACING, UNDER_GAME, LINE = 4, 2, 21, 10
local RAISE = 5
local WHITE, YELLOW, RED = { 1, 1, 1 }, { 1, 0.82, 0.18 }, { 0.93, 0.07, 0.07 }
local FPS_MIDDLING, FPS_POOR, MS_MIDDLING, MS_POOR = 60, 30, 100, 200
local FIRST_SLOT, LAST_SLOT = 1, 19
local SLOW = 1
local STREAMS = { coords = "coords", durability = "durability", perf = "fps" }
local ANCHOR = "ANCHOR_LEFT"
local DIM_RGB = { 0.66, 0.68, 0.62 }
local CLICKS = { coords = true, durability = true, clock = true }
local HOVER_LIGHT, LIGHT_OUT = { 1, 1, 1, 0.07 }, 2
local HINTS = {
	coords = { "Click: world map", "Shift-click: put this in chat" },
	durability = { "Click: character window" },
	clock = { "Click: stopwatch and alarm", "Shift-click: calendar" },
}
local FIGHT_HINTS = {
	coords = { "Click: world map, after the fight", "Shift-click: put this in chat" },
	durability = { "Click: character window, after the fight" },
	clock = { "Click: stopwatch and alarm, after the fight", "Shift-click: calendar, after the fight" },
}
local LATER_STOPWATCH = "Flat UI: the stopwatch opens when the fight ends."
local LATER_CALENDAR = "Flat UI: the calendar opens when the fight ends."
local LATER_CHARACTER = "Flat UI: the character window opens when the fight ends."
local LATER_MAP = "Flat UI: the world map opens when the fight ends."

local S = { text = {}, button = {}, shown = {}, colour = {}, size = {}, why = {}, sampled = {}, below = 0, above = 0 }
local P = { hold = 3, out = 0.5, gap = 6, inset = 4, sample = "Bex" }

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

local function MapCalls()
	local api = _G.C_Map
	if type(api) ~= "table" or ns.IsSecret(api) or type(api.GetBestMapForUnit) ~= "function" or type(api.GetPlayerMapPosition) ~= "function" then
		return nil
	end
	return api
end

local function InInstance()
	return Ask(_G.IsInInstance) == true
end

local function LocalTime()
	return Opt("mapClockTime") ~= "realm"
end

local function Available(line)
	if line.id == "coords" then
		return MapCalls() ~= nil
	elseif line.id == "durability" then
		return type(_G.GetInventoryItemDurability) == "function"
	elseif line.id == "perf" then
		local show = Opt("mapPerfShow")
		return (show ~= "ms" and type(_G.GetFramerate) == "function") or (show ~= "fps" and type(_G.GetNetStats) == "function")
	elseif LocalTime() then
		return type(_G.date) == "function"
	end
	return type(_G.GetGameTime) == "function"
end

local function Live(line)
	return line.every ~= nil and Wanted(line) and Available(line) and not (line.id == "coords" and (S.game or InInstance()))
end

local function Coords()
	local api = MapCalls()
	if not api then
		return nil
	end
	if S.game then
		return nil, "hidden while the game's own coordinates show under the map (the game's Options, Interface, Coordinates)"
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
	local when = Opt("mapDurabilityWhen")
	if (when == "worn" and lowest > 50) or (when == "low" and lowest > 20) then
		return nil
	end
	local word = _G.DURABILITY
	if ns.IsSecret(word) or type(word) ~= "string" or word == "" then
		word = "Durability"
	end
	return ("%s %d%%"):format(word, lowest), (lowest <= 20 and RED) or (lowest <= 50 and YELLOW) or WHITE
end

local function Code(rgb)
	return ("|cff%02x%02x%02x"):format(math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end
local PERF_CODES = { Code({ 0.1, 1, 0.1 }), Code(YELLOW), Code(RED) }

function ns.PerfColour(kind, value, codes)
	if not ns.Finite(value) then
		return nil
	end
	local level
	if kind == "fps" then
		level = (value < FPS_POOR and 3) or (value < FPS_MIDDLING and 2) or 1
	else
		level = (value > MS_POOR and 3) or (value > MS_MIDDLING and 2) or 1
	end
	return (type(codes) == "table" and codes or PERF_CODES)[level]
end

local function PerfLine(fps, home, world)
	local show = Opt("mapPerfShow")
	local colour = Opt("mapPerfColour") == true
	local function Number(kind, value)
		local whole = math.floor(value + 0.5)
		local code = colour and ns.PerfColour(kind, whole) or nil
		return code and (code .. whole .. "|r") or tostring(whole)
	end
	local parts = {}
	if show ~= "ms" and ns.Finite(fps) and fps >= 0 then
		parts[#parts + 1] = Number("fps", fps) .. " fps"
	end
	if show ~= "fps" then
		local which = Opt("mapLatency")
		if which == "home" and home then
			parts[#parts + 1] = Number("ms", home) .. " ms"
		elseif which == "world" and world then
			parts[#parts + 1] = Number("ms", world) .. " ms"
		elseif which == "max" and home and world then
			parts[#parts + 1] = Number("ms", math.max(home, world)) .. " ms"
		elseif which ~= "home" and which ~= "world" and which ~= "max" and home and world then
			parts[#parts + 1] = Number("ms", home) .. " / " .. Number("ms", world) .. " ms"
		end
	end
	return #parts > 0 and table.concat(parts, "   ") or nil
end

local function Perf()
	local rate, net = _G.GetFramerate, _G.GetNetStats
	local show = Opt("mapPerfShow")
	local wantRate, wantNet = show ~= "ms", show ~= "fps"
	if not ((wantRate and type(rate) == "function") or (wantNet and type(net) == "function")) then
		return nil
	end
	local fps = wantRate and Ask(rate) or nil
	local home, world
	if wantNet and type(net) == "function" then
		local ok, _, _, h, w = pcall(net)
		home = ok and ns.Finite(h) and h >= 0 and h or nil
		world = ok and ns.Finite(w) and w >= 0 and w or nil
	end
	local line = PerfLine(fps, home, world)
	if not line then
		return nil, "hidden, the game does not say them"
	end
	return line
end

local function Formatted(pattern, fallback, ...)
	if not ns.IsSecret(pattern) and type(pattern) == "string" then
		local ok, text = pcall(string.format, pattern, ...)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return fallback:format(...)
end

local function TimeParts(isLocal)
	local hour, minute
	if isLocal then
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
		return false
	end
	return math.floor(hour) % 24, math.floor(minute) % 60
end

local function Stamp(hour, minute)
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

local function Clock()
	local hour, minute = TimeParts(LocalTime())
	if hour == nil then
		return nil
	elseif not hour then
		return nil, "hidden, the game does not say the time"
	end
	return Stamp(hour, minute)
end

local READ = { coords = Coords, durability = Durability, perf = Perf, clock = Clock }
local SAMPLE = { coords = { 45.2, 61.8 }, durability = 42, perf = { 62, 48, 95 }, clock = { 14, 5 } }

local function Sample(line)
	local id, at = line.id, SAMPLE[line.id]
	if id == "coords" then
		local decimals = math.max(0, math.min(2, math.floor(tonumber(Opt("mapCoordsDecimals")) or 1)))
		return ("%." .. decimals .. "f, %." .. decimals .. "f"):format(at[1], at[2])
	elseif id == "durability" then
		local word = _G.DURABILITY
		if ns.IsSecret(word) or type(word) ~= "string" or word == "" then
			word = "Durability"
		end
		return ("%s %d%%"):format(word, at), YELLOW
	elseif id == "perf" then
		return PerfLine(at[1], at[2], at[3])
	end
	return Stamp(at[1], at[2])
end

local function Sampling(line)
	local tm = ns.TestMode
	return tm ~= nil and type(tm.IsOn) == "function" and tm.IsOn() == true and Available(line) and not (line.id == "coords" and S.game)
end

local function Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Owns(button)
	local tip = Tooltip()
	if not (tip and button) then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	return ok and not ns.IsSecret(owned) and owned == true
end

local function SessionTime()
	local seconds = Ask(_G.GetSessionTime)
	if not ns.Finite(seconds) or seconds < 0 then
		return nil
	end
	local panels = ns.DataPanels
	if type(panels) == "table" and type(panels.Time) == "function" then
		local ok, text = pcall(panels.Time, seconds)
		if ok and type(text) == "string" then
			return text
		end
	end
	if seconds >= 3600 then
		return ("%dh %dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
	end
	return ("%dm"):format(math.ceil(seconds / 60))
end

local function ClockTip(button)
	local tip = Tooltip()
	if not tip then
		return
	end
	local function Line(isLocal)
		local hour, minute = TimeParts(isLocal)
		return hour and Stamp(hour, minute) or "Unknown"
	end
	local session = SessionTime()
	pcall(function()
		tip:SetOwner(button, ANCHOR)
		tip:SetText("Time", 1, 1, 1)
		tip:AddDoubleLine("Local time", Line(true), DIM_RGB[1], DIM_RGB[2], DIM_RGB[3], 1, 1, 1)
		tip:AddDoubleLine("Realm time", Line(false), DIM_RGB[1], DIM_RGB[2], DIM_RGB[3], 1, 1, 1)
		if session then
			tip:AddDoubleLine("This session", session, DIM_RGB[1], DIM_RGB[2], DIM_RGB[3], 1, 1, 1)
		end
		for _, hint in ipairs(InCombatLockdown() and FIGHT_HINTS.clock or HINTS.clock) do
			tip:AddLine(hint, DIM_RGB[1], DIM_RGB[2], DIM_RGB[3])
		end
		tip:Show()
	end)
end

local function Tip(_, line, button, fresh)
	if not button or not S.shown[line.id] then
		return
	end
	if S.sampled[line.id] then
		local tip = Tooltip()
		if tip then
			pcall(function()
				tip:SetOwner(button, ANCHOR)
				tip:SetText(line.label, 1, 1, 1)
				tip:AddLine("A sample while test mode is on.", DIM_RGB[1], DIM_RGB[2], DIM_RGB[3])
				tip:Show()
			end)
		end
		return
	end
	if line.id == "clock" then
		ClockTip(button)
		return
	end
	local panels = ns.DataPanels
	if type(panels) == "table" and type(panels.TipAt) == "function" then
		panels.TipAt(button, ANCHOR, STREAMS[line.id], fresh, (InCombatLockdown() and FIGHT_HINTS[line.id]) or HINTS[line.id])
	end
end

local function Retip(line)
	local button = S.button[line.id]
	if S.over == line.id and Owns(button) then
		ns.EachPart(KEY, PART, Tip, {}, line, button, false)
	end
end

local function ChatText(line)
	local shown = S.shown[line.id]
	if line.id ~= "coords" or type(shown) ~= "string" or S.sampled[line.id] then
		return nil
	end
	local zone = Ask(_G.GetZoneText)
	return type(zone) == "string" and zone ~= "" and (zone .. " " .. shown) or shown
end

local function Click(_, line)
	local shift = Ask(_G.IsShiftKeyDown) == true
	if line.id == "coords" and shift then
		local text = ChatText(line)
		if text then
			ns.PutInChat(text)
		end
	elseif line.id == "coords" then
		if type(_G.ToggleWorldMap) == "function" then
			ns.OpenAfterFight(function()
				_G.ToggleWorldMap()
			end, LATER_MAP)
		end
	elseif line.id == "durability" then
		if type(_G.ToggleCharacter) == "function" then
			ns.OpenAfterFight(function()
				_G.ToggleCharacter("PaperDollFrame")
			end, LATER_CHARACTER)
		end
	elseif line.id == "clock" then
		local name = shift and "ToggleCalendar" or "ToggleTimeManager"
		if type(_G[name]) == "function" then
			ns.OpenAfterFight(function()
				_G[name]()
			end, shift and LATER_CALENDAR or LATER_STOPWATCH)
		end
	end
end

local function MakeButton(line, text)
	local map = _G.Minimap
	if InCombatLockdown() and (map == nil or ns.MaybeProtected == nil or ns.MaybeProtected(map)) then
		return nil
	end
	local ok, button = pcall(CreateFrame, "Button", nil, S.frame)
	if not ok or type(button) ~= "table" then
		return nil
	end
	ns.Own[button] = true
	button:SetAllPoints(text)
	button:EnableMouse(true)
	local light
	if CLICKS[line.id] then
		light = S.frame:CreateTexture(nil, "BACKGROUND")
		ns.Own[light] = true
		light:SetPoint("TOPLEFT", text, "TOPLEFT", -LIGHT_OUT, LIGHT_OUT)
		light:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", LIGHT_OUT, -LIGHT_OUT)
		light:SetColorTexture(HOVER_LIGHT[1], HOVER_LIGHT[2], HOVER_LIGHT[3], HOVER_LIGHT[4])
		light:Hide()
	end
	if CLICKS[line.id] then
		button:RegisterForClicks("LeftButtonUp")
		button:SetScript("OnClick", function()
			ns.EachPart(KEY, PART, Click, {}, line)
		end)
	else
		pcall(button.SetMouseClickEnabled, button, false)
	end
	button:SetScript("OnEnter", function(self)
		S.over = line.id
		if light then
			light:Show()
		end
		ns.EachPart(KEY, PART, Tip, {}, line, self, true)
	end)
	button:SetScript("OnLeave", function(self)
		if S.over == line.id then
			S.over = nil
		end
		if light then
			light:Hide()
		end
		if Owns(self) then
			pcall(_G.GameTooltip.Hide, _G.GameTooltip)
		end
	end)
	button:SetScript("OnHide", function(self)
		if S.over == line.id then
			S.over = nil
		end
		if light then
			light:Hide()
		end
		if Owns(self) then
			pcall(_G.GameTooltip.Hide, _G.GameTooltip)
		end
	end)
	button:Hide()
	S.button[line.id] = button
	return button
end

local Queue

local function SetBelow(room)
	if room == S.below then
		return
	end
	S.below = room
	if ns.MapButtonsChanged and ns.Get("hud.addonButtons") == "bar" then
		pcall(ns.MapButtonsChanged)
	end
end

local function SetAbove(room)
	if room == S.above then
		return
	end
	S.above = room
	if ns.MapGapRoom then
		pcall(ns.MapGapRoom)
	end
end

local function StopTicker()
	if S.ticker and S.ticker.Cancel then
		pcall(S.ticker.Cancel, S.ticker)
	end
	S.ticker, S.step = nil, nil
end

local function GameCoords()
	local cvar = _G.C_CVar
	if type(cvar) ~= "table" or ns.IsSecret(cvar) or Ask(cvar.GetCVar, "minimapShowPlayerCoords") ~= "1" then
		return false
	end
	local line = Field(_G.MinimapCluster, "PlayerCoords")
	if type(line) ~= "table" or ns.Forbidden(line) then
		return true
	end
	return Ask(line.IsShown, line) ~= false
end

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
	local text, button = S.text[line.id], S.button[line.id]
	if text and S.shown[line.id] then
		text:Hide()
	end
	if button then
		button:Hide()
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
	local size = tonumber(Opt("mapTextSize")) or 100
	if S.size[line.id] ~= size then
		ns.TextStyle(text, { percent = size })
		S.size[line.id] = size
	end
	colour = colour or WHITE
	if S.colour[line.id] ~= colour then
		text:SetTextColor(colour[1], colour[2], colour[3])
		S.colour[line.id] = colour
	end
	local button = S.button[line.id] or MakeButton(line, text)
	if button then
		button:Show()
	end
	if S.shown[line.id] ~= value then
		if S.shown[line.id] == nil then
			text:Show()
		end
		text:SetText(value)
		S.shown[line.id] = value
		Retip(line)
	end
end

local function Read(line)
	S.why[line.id] = nil
	if not Wanted(line) then
		Hide(line)
		return
	end
	local value, more = READ[line.id]()
	S.sampled[line.id] = nil
	if type(value) ~= "string" and Sampling(line) then
		S.why[line.id] = type(more) == "string" and more or nil
		value, more = Sample(line)
		S.sampled[line.id] = type(value) == "string" or nil
	end
	if type(value) == "string" then
		Show(line, value, type(more) == "table" and more or nil)
	else
		S.why[line.id] = type(more) == "string" and more or S.why[line.id]
		Hide(line)
	end
end

local function Height(text)
	local height = Ask(text.GetStringHeight, text)
	return ns.Finite(height) and height > 0 and height or LINE
end

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

local function Layout()
	local places, sig = {}, { S.game and "game" or "", "size=" .. tostring(Opt("mapTextSize")) }
	local side, near, far = Plate()
	local used, asked
	for _, line in ipairs(LINES) do
		if S.shown[line.id] then
			local place = Opt(line.place) == "above" and "above" or "below"
			if place == "above" then
				asked = (asked and asked + SPACING or GAP) + Height(S.text[line.id])
			end
			if place == "above" and side == "above" then
				used = (used and used + SPACING or GAP) + Height(S.text[line.id])
				if used > near + 0.01 then
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
	SetAbove(asked or 0)
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
	if P.frame and not P.Wanted() then
		P.frame:Hide()
	end
	StopTicker()
	S.sig = nil
	SetBelow(0)
	SetAbove(0)
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

local W = { every = 0.1, up = 6, pad = 6, level = 9500, gap = "    ", size = 100 }

function W.Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt("mapWorldCoords") == true and MapCalls() ~= nil
end

function W.Map()
	local map = _G.WorldMapFrame
	if type(map) ~= "table" or ns.IsSecret(map) or ns.Forbidden(map) then
		return nil
	end
	local container = Field(map, "ScrollContainer")
	local child = type(container) == "table" and not ns.Forbidden(container) and Field(container, "Child") or nil
	if type(child) ~= "table" or ns.Forbidden(child) then
		return nil
	end
	return map, container, child
end

function W.Spot(x, y, format)
	if not (ns.Finite(x) and ns.Finite(y)) or x < 0 or x > 1 or y < 0 or y > 1 then
		return nil
	end
	return format:format(x * 100, y * 100)
end

function W.You(api, map, format)
	if InInstance() then
		return nil
	end
	local ok, id = pcall(rawget, map, "mapID")
	if not ok or not ns.Finite(id) or id <= 0 then
		return nil
	end
	local position = Ask(api.GetPlayerMapPosition, id, "player")
	local x, y = Field(position, "x"), Field(position, "y")
	if x == 0 and y == 0 then
		return nil
	end
	return W.Spot(x, y, format)
end

function W.Cursor(container, child, format)
	if Ask(container.IsMouseOver, container) ~= true then
		return nil
	end
	local ok, cx, cy = pcall(_G.GetCursorPosition)
	if not ok or not (ns.Finite(cx) and ns.Finite(cy)) then
		return nil
	end
	local scale, left, top = Ask(child.GetEffectiveScale, child), Ask(child.GetLeft, child), Ask(child.GetTop, child)
	local width, height = Ask(child.GetWidth, child), Ask(child.GetHeight, child)
	if not (ns.Finite(scale) and ns.Finite(left) and ns.Finite(top) and ns.Finite(width) and ns.Finite(height)) or scale <= 0 or width <= 0
		or height <= 0 then
		return nil
	end
	return W.Spot((cx / scale - left) / width, (top - cy / scale) / height, format)
end

function W.Read()
	local api = MapCalls()
	local map, container, child = W.Map()
	local value
	if api and map then
		local decimals = math.max(0, math.min(2, math.floor(tonumber(Opt("mapCoordsDecimals")) or 1)))
		local format = "%." .. decimals .. "f, %." .. decimals .. "f"
		local you, cursor = W.You(api, map, format), W.Cursor(container, child, format)
		if you and cursor then
			value = "You " .. you .. W.gap .. "Cursor " .. cursor
		else
			value = (you and "You " .. you) or (cursor and "Cursor " .. cursor) or nil
		end
	end
	if value == W.shown then
		return
	end
	W.shown = value
	if not value then
		W.text:Hide()
		ns.SetOutline(W.outline, false, false)
		return
	end
	W.text:SetText(value)
	W.text:Show()
	local width, height = Ask(W.text.GetStringWidth, W.text), Ask(W.text.GetStringHeight, W.text)
	local pad = W.pad * W.size / 100
	W.frame:SetSize((ns.Finite(width) and width or 120) + pad * 2, (ns.Finite(height) and height or LINE) + pad * 2 / 3)
	ns.SetOutline(W.outline, true, true)
end

function W.Step(_, elapsed)
	W.at = (W.at or 0) + (ns.Finite(elapsed) and elapsed or 0)
	if W.at < W.every then
		return
	end
	W.at = 0
	if ns.IsStopped(KEY) or not W.Wanted() then
		W.frame:Hide()
	elseif not ns.EachPart(KEY, PART, W.Read, {}) and ns.PartStopped(KEY, PART) then
		W.frame:Hide()
	end
end

function W.Make()
	if W.frame then
		return true
	end
	local _, container = W.Map()
	if not container or W.broken then
		return false
	end
	if InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(container)) then
		if not W.waiting then
			W.waiting = true
			ns.OutOfCombat(function()
				W.waiting = false
				W.Refresh()
			end)
		end
		return false
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, container)
	if not ok or type(frame) ~= "table" then
		return false
	end
	ns.Own[frame] = true
	frame:SetSize(1, 1)
	frame:SetPoint("BOTTOM", container, "BOTTOM", 0, W.up)
	frame:SetFrameLevel(W.level)
	frame:EnableMouse(false)
	local outline = ns.SetOutlineArea(ns.Outline(frame, frame), KEY)
	ns.SetOutline(outline, false, false)
	local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	if not text then
		frame:Hide()
		W.broken = true
		return false
	end
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	text:Hide()
	W.frame, W.text, W.outline = frame, text, outline
	frame:SetScript("OnUpdate", W.Step)
	frame:SetScript("OnHide", function()
		W.at = W.every
	end)
	return true
end

function W.Refresh()
	if ns.PartStopped(KEY, PART) or ns.IsStopped(KEY) then
		if W.frame then
			W.frame:Hide()
		end
		return
	end
	ns.EachPart(KEY, PART, W.Draw, {})
end

function W.Draw()
	if not W.Wanted() then
		if W.frame then
			W.frame:Hide()
		end
		return
	end
	if W.Make() then
		local size = tonumber(Opt("mapTextSize")) or 100
		if W.size ~= size and ns.TextStyle(W.text, { percent = size }) then
			W.size = size
		end
		W.shown, W.at = false, W.every
		W.frame:Show()
	end
end

function P.Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and Opt("mapPingName") == true
end

function P.Step(frame, elapsed)
	P.at = (P.at or 0) + (ns.Finite(elapsed) and elapsed or 0)
	if not P.Wanted() or ns.IsStopped(KEY) then
		frame:Hide()
		return
	end
	if P.at <= P.hold then
		return
	end
	local fade = (P.at - P.hold) / P.out
	if fade >= 1 then
		frame:Hide()
	else
		frame:SetAlpha(1 - fade)
	end
end

function P.Make(map)
	if P.frame then
		return true
	end
	if P.broken or (InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(map))) then
		return false
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, map)
	if not ok or type(frame) ~= "table" then
		return false
	end
	ns.Own[frame] = true
	frame:SetAllPoints(map)
	frame:EnableMouse(false)
	local level = Ask(map.GetFrameLevel, map)
	if ns.Finite(level) then
		frame:SetFrameLevel(level + RAISE + 1)
	end
	frame:Hide()
	local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	if not text then
		P.broken = true
		return false
	end
	text:SetJustifyH("CENTER")
	P.frame, P.text = frame, text
	frame:SetScript("OnUpdate", P.Step)
	frame:SetScript("OnHide", function(self)
		self:Hide()
	end)
	return true
end

function P.Round()
	return not ns.Enabled(KEY) or ns.PartStopped(KEY, "minimap") or ns.Get(KEY .. ".shape") ~= "square"
end

function P.Place(map, x, y, offsets)
	local text = P.text
	text:ClearAllPoints()
	local width, height = Ask(map.GetWidth, map), Ask(map.GetHeight, map)
	if not (ns.Finite(x) and ns.Finite(y) and ns.Finite(width) and ns.Finite(height) and width > 0 and height > 0) then
		text:SetPoint("TOP", map, "TOP", 0, -P.gap)
		return
	end
	if not offsets and math.abs(x) <= 1 and math.abs(y) <= 1 then
		x, y = x * width, y * height
	end
	local wide, tall = Ask(text.GetStringWidth, text), Ask(text.GetStringHeight, text)
	wide = ns.Finite(wide) and wide or 40
	tall = ns.Finite(tall) and tall or LINE
	if P.Round() then
		local reach = math.max(0, math.min(width, height) / 2 - wide / 2 - P.inset)
		local mid = y + P.gap + tall / 2
		local far = math.sqrt(x * x + mid * mid)
		if far > reach and far > 0 then
			x, mid = x * reach / far, mid * reach / far
		end
		text:SetPoint("BOTTOM", map, "CENTER", x, mid - tall / 2)
		return
	end
	local side = math.max(0, width / 2 - wide / 2 - P.inset)
	local low, high = -height / 2 + P.inset, height / 2 - tall - P.inset
	x = math.max(-side, math.min(side, x))
	y = math.max(low, math.min(math.max(low, high), y + P.gap))
	text:SetPoint("BOTTOM", map, "CENTER", x, y)
end

function P.Show(name, r, g, b, x, y, offsets)
	local map = _G.Minimap
	if map == nil or ns.Forbidden(map) or not P.Wanted() or not P.Make(map) then
		return false
	end
	local size = tonumber(Opt("mapTextSize")) or 100
	if P.size ~= size and ns.TextStyle(P.text, { percent = size, flags = "OUTLINE" }) then
		P.size = size
	end
	P.text:SetText(name)
	P.text:SetTextColor(r or 1, g or 1, b or 1)
	P.Place(map, x, y, offsets)
	P.at = 0
	P.frame:SetAlpha(1)
	P.frame:Show()
	return true
end

function P.Spot(first, second)
	local map = _G.Minimap
	if map ~= nil and not ns.Forbidden(map) and type(map.GetPingPosition) == "function" then
		local ok, x, y = pcall(map.GetPingPosition, map)
		if ok and ns.Finite(x) and ns.Finite(y) then
			return x, y, true
		end
	end
	return first, second, false
end

function P.Ping(_, unit, first, second)
	if not P.Wanted() then
		return
	end
	if ns.IsSecret(unit) then
		P.secret = true
		return
	end
	if type(unit) ~= "string" or unit == "" then
		return
	end
	local okSelf, mine = pcall(UnitIsUnit, unit, "player")
	if not okSelf or ns.IsSecret(mine) then
		mine = unit == "player"
	end
	if mine == true then
		return
	end
	local okName, name = pcall(UnitName, unit)
	if okName and ns.IsSecret(name) then
		P.secret = true
		return
	end
	if not okName or type(name) ~= "string" or name == "" then
		return
	end
	local r, g, b = ns.ClassColourOf(unit)
	local x, y, offsets = P.Spot(first, second)
	P.Show(name, r, g, b, x, y, offsets)
end

function P.Sample()
	local map = _G.Minimap
	local width, height = map and Ask(map.GetWidth, map), map and Ask(map.GetHeight, map)
	local x, y
	if ns.Finite(width) and ns.Finite(height) then
		x, y = (math.random() - 0.5) * width * 0.6, (math.random() - 0.5) * height * 0.6
	end
	local priest = Field(_G.RAID_CLASS_COLORS, "PRIEST")
	local r, g, b = Field(priest, "r"), Field(priest, "g"), Field(priest, "b")
	if not (ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = 1, 1, 1
	end
	P.Show(P.sample, r, g, b, x, y, true)
end

function P.Payload(lead, first, ...)
	if lead > 0 and not ns.IsSecret(first) and (first == nil or type(first) == "table" or first == "MINIMAP_PING") then
		return P.Payload(lead - 1, ...)
	end
	return first, ...
end

function P.Heard(...)
	if ns.IsStopped(KEY) then
		return
	end
	ns.EachPart(KEY, PART, P.Ping, P, ...)
end

function P.Listen()
	local ok, ear = pcall(CreateFrame, "Frame")
	if not ok or type(ear) ~= "table" then
		P.deaf = true
		return
	end
	ns.Own[ear] = true
	P.ear = ear
	if type(ear.RegisterEventCallback) == "function" then
		local took, result = pcall(ear.RegisterEventCallback, ear, "MINIMAP_PING", function(...)
			P.Heard(P.Payload(math.min(select("#", ...), 2), ...))
		end)
		P.callback = took and result ~= false
	end
	if not P.callback then
		ear:SetScript("OnEvent", function(_, _, ...)
			P.Heard(...)
		end)
		local took, result = pcall(ear.RegisterEvent, ear, "MINIMAP_PING")
		P.deaf = not took or result == false
	end
end
P.Listen()

function P.Refresh()
	if not P.Wanted() then
		if P.frame then
			P.frame:Hide()
		end
		return
	end
	local map = _G.Minimap
	if map ~= nil and not ns.Forbidden(map) then
		P.Make(map)
	end
end

local function Draw()
	W.Refresh()
	ns.EachPart(KEY, PART, P.Refresh, {})
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

local function Relevant()
	return S.frame ~= nil or Needed()
end

local function Changed()
	if Relevant() then
		Queue()
	end
end

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
ns.AddEvent(KEY, "ADDON_LOADED", function()
	W.Refresh()
end, function(name)
	return not ns.IsSecret(name) and name == "Blizzard_WorldMap"
end)

if ns.TestMode then
	ns.TestMode.Register("maptext", { module = KEY, label = "Map text", Start = Queue, Stop = Queue })
	ns.TestMode.Register("mapping", { module = KEY, label = "Minimap ping name", every = 5, Start = function()
		ns.EachPart(KEY, PART, P.Sample, {})
	end, Tick = function()
		ns.EachPart(KEY, PART, P.Sample, {})
	end, Stop = function()
		if P.frame then
			P.frame:Hide()
		end
	end })
end

ns.AddStatus(KEY, function()
	local lines = {}
	for _, line in ipairs(LINES) do
		if S.why[line.id] and Wanted(line) then
			lines[#lines + 1] = ("%s: %s."):format(line.label, S.why[line.id])
		end
	end
	if P.Wanted() then
		local events = _G.C_EventUtils
		local valid = type(events) == "table" and not ns.IsSecret(events) and Ask(events.IsEventValid, "MINIMAP_PING")
		if valid == false or P.deaf then
			lines[#lines + 1] = "Ping names: the game gives addons no minimap pings here."
		elseif P.secret then
			lines[#lines + 1] = "Ping names: the game withholds who pinged here."
		elseif P.broken then
			lines[#lines + 1] = "Ping names: the game refused the name's text, so none shows."
		end
	end
	return lines
end)

function ns.MapTextRefresh()
	Draw()
end

function ns.MapTextBelow()
	return S.below
end

function ns.MapTextAbove()
	return S.above
end

function ns.PutInChat(text)
	local util = _G.ChatFrameUtil
	if type(text) ~= "string" or text == "" or type(util) ~= "table" or ns.IsSecret(util) then
		return false
	end
	if type(util.GetActiveWindow) == "function" then
		local ok, box = pcall(util.GetActiveWindow)
		if ok and type(box) == "table" and not ns.IsSecret(box) and not ns.Forbidden(box) and type(box.Insert) == "function"
			and pcall(box.Insert, box, text) then
			pcall(box.SetFocus, box)
			return true
		end
	end
	if type(util.OpenChat) == "function" then
		return (pcall(util.OpenChat, text))
	end
	return false
end

local opening = {}
function ns.OpenAfterFight(open, said)
	if type(open) ~= "function" then
		return false
	end
	if not InCombatLockdown() then
		return (pcall(open))
	end
	if type(said) == "string" and said ~= opening.said then
		print(said)
	end
	opening.open, opening.said = open, said
	if not opening.queued then
		opening.queued = true
		ns.OutOfCombat(function()
			local fn = opening.open
			opening.queued, opening.open, opening.said = false, nil, nil
			if type(fn) == "function" then
				pcall(fn)
			end
		end)
	end
	return false
end
