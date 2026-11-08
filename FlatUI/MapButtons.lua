local _, ns = ...

-- The round buttons that addons put on the minimap with LibDBIcon (frames named LibDBIcon10_<addon>, children of Minimap). The library treats the map as
-- square and puts them on its edge, so on a round map they hang over it. Not a module. The library's code is not in client/: unseen.
-- Only ClearAllPoints and SetPoint on frames that are not protected. No mouse, no script of another addon, nothing written to any addon's saved data.
-- This file writes no alpha: Fading (Fade.lua) fades the buttons with its Minimap buttons row, from the list ns.MapAddonButtons gives, whatever
-- Addon buttons says, and puts each one's alpha back. A secret answer from a size, a centre, a point or a child list stops the pass and the buttons
-- stay (SimpleFrameAPIDocumentation.lua:323-335, SimpleScriptRegionAPIDocumentation.lua:145-149, SimpleScriptRegionResizingAPIDocumentation.lua:65-75).
-- bar: the row starts below the coordinate text of the map (Blizzard_Minimap/Mainline/Minimap.xml:287-291), or below the lines of MapText.lua
-- under the map when they reach further (ns.MapTextBelow).
-- Leave in place (hud.addonButtonsKeep): a list of the buttons found, by the name after the prefix, with a tick on those left where their addon puts
-- them; a pick ticks or unticks one. The names are kept for the account in FlatUIDB.mapButtons.keep. A ticked button is left out of the column or
-- row and gets back at once the points it had before this file moved it, wherever its addon has put it since; an unticked one is placed again.
-- /flatui status says how many are left in place. This follows the Button Sink exclusion list of EnhanceQoL by Philipp Barth (R41Z0R), adapted with
-- his permission (EnhanceQoL/Settings/MapNavigation.lua:3273-3328, EnhanceQoL/EnhanceQoL.lua:5844-5895).

local PREFIX = "LibDBIcon10_"
local GAP = 2
-- Between the map and the column; the room under the map for the coordinate text.
local MARGIN, TEXT = 3, 24
-- The list of buttons Fading asks for at each of its steps is looked for again after this many seconds, so a button made later joins within it.
local LOOK_AGAIN = 1
-- The tick before a button left in place: the game's own check mark, as its dressing room writes it (Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua:678).
local TICK = "|A:common-icon-checkmark:14:14|a "
-- The most names kept, and the longest.
local MOST_KEPT, LONGEST = 200, 120

local weak = { __mode = "k" }
-- Per button: the points it had before this file moved it.
local recorded = setmetatable({}, weak)
-- found: the last list for Fading and when it was made. ids and names: the number of each name in the list row, the same for the whole session.
local state = { ticker = nil, found = nil, foundAt = nil, ids = {}, names = {} }

local function Num(value)
	return type(value) == "number" and not ns.IsSecret(value) and value == value
end

-- The answer of a call that may be missing, raise or be withheld: nil, or up to five values.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if not ok or ns.IsSecret(a) or ns.IsSecret(b) or ns.IsSecret(c) or ns.IsSecret(d) or ns.IsSecret(e) then
		return nil
	end
	return a, b, c, d, e
end

local function Mode()
	if not ns.Enabled("hud") then
		return "leave"
	end
	return ns.Get("hud.addonButtons") or "leave"
end

local function Map()
	local map = Minimap
	if type(map) ~= "table" or ns.IsSecret(map) or ns.Forbidden(map) then
		return nil
	end
	return map
end

-- The names the account keeps in place, without the prefix: a map of name to true. With make, the table is made when there is none; without, nil then.
local function KeptNames(make)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	local saved = db.mapButtons
	if type(saved) ~= "table" then
		if not make then
			return nil
		end
		saved = {}
		db.mapButtons = saved
	end
	if type(saved.keep) ~= "table" then
		if not make then
			return nil
		end
		saved.keep = {}
	end
	return saved.keep
end

-- True for a button, by its full name, that the account keeps where its addon puts it.
local function Kept(name)
	local keep = KeptNames(false)
	return keep ~= nil and type(name) == "string" and keep[name:sub(#PREFIX + 1)] == true
end

-- Every shown button of the library on the map that is not protected, by name; nil when the list could not be read.
local function Scan(map)
	local list = { pcall(map.GetChildren, map) }
	if not list[1] then
		return nil
	end
	local out = {}
	for i = 2, #list do
		local child = list[i]
		if ns.IsSecret(child) then
			return nil
		end
		if type(child) == "table" and not ns.Forbidden(child) then
			local name = Ask(child.GetName, child)
			if type(name) == "string" and name:sub(1, #PREFIX) == PREFIX and #name > #PREFIX and Ask(child.IsProtected, child) == false
				and Ask(child.IsShown, child) == true then
				out[#out + 1] = { name = name, frame = child }
			end
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- The clock of the client, or nil.
local function Now()
	local ok, now = pcall(GetTime)
	return ok and Num(now) and now or nil
end

-- Scan, kept as the list ns.MapAddonButtons gives Fading.
local function Fresh(map)
	local all = Scan(map)
	if all then
		state.found, state.foundAt = all, Now()
	end
	return all
end

-- The buttons of the library that this file may place: those of Scan that are not kept in place. Nil when the list could not be read.
local function Buttons(map)
	local all = Fresh(map)
	if not all then
		return nil
	end
	local out = {}
	for _, entry in ipairs(all) do
		if not Kept(entry.name) then
			out[#out + 1] = entry
		end
	end
	return out
end

-- Keeps the points a button had before it was moved.
local function Record(button)
	if recorded[button] then
		return true
	end
	local count = Ask(button.GetNumPoints, button)
	if not Num(count) then
		return false
	end
	local points = {}
	for i = 1, count do
		local point, relativeTo, relativePoint, x, y = Ask(button.GetPoint, button, i)
		if type(point) ~= "string" then
			return false
		end
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	recorded[button] = points
	return true
end

local function Put(button, dx, dy, map)
	local point, relativeTo, relativePoint, x, y = Ask(button.GetPoint, button, 1)
	if Ask(button.GetNumPoints, button) == 1 and point == "CENTER" and relativeTo == map and relativePoint == "CENTER" and x == dx and y == dy then
		return
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", map, "CENTER", dx, dy)
end

-- One button gets back the points it had before this file moved it, wherever its addon has put it since.
local function Give(button, points)
	if Ask(button.IsProtected, button) == false then
		pcall(function()
			button:ClearAllPoints()
			for _, p in ipairs(points) do
				button:SetPoint(p[1], p[2], p[3], p[4], p[5])
			end
		end)
	end
	recorded[button] = nil
end

-- Every moved button gets its points back, or with kept only the buttons kept in place.
local function Restore(kept)
	for button, points in pairs(recorded) do
		if not kept or Kept(Ask(button.GetName, button)) then
			Give(button, points)
		end
	end
end

local function Place(map, buttons, mode)
	local mw, mh = Ask(map.GetWidth, map), Ask(map.GetHeight, map)
	local mx, ux = Ask(map.GetCenter, map), UIParent and Ask(UIParent.GetCenter, UIParent)
	-- A centre is in the scale of its own frame, and the Edit Mode size of the map scales its container (Blizzard_Minimap/Mainline/Minimap.lua:418-419).
	local ms, us = Ask(map.GetEffectiveScale, map), UIParent and Ask(UIParent.GetEffectiveScale, UIParent)
	if not (Num(mw) and Num(mh) and Num(mx) and Num(ux) and Num(ms) and Num(us)) then
		return
	end
	-- The side that faces the screen centre.
	local sign = mx * ms > ux * us and -1 or 1
	-- The room under the map: the game's coordinate text, or the lines of MapText.lua when they take more.
	local room = TEXT
	local below = ns.MapTextBelow and ns.MapTextBelow()
	if Num(below) and below + MARGIN > room then
		room = below + MARGIN
	end
	local row, col, used = 0, 0, 0
	for _, entry in ipairs(buttons) do
		local button = entry.frame
		local w, h = Ask(button.GetWidth, button), Ask(button.GetHeight, button)
		if not (Num(w) and Num(h)) then
			return
		end
		if Record(button) then
			local dx, dy
			if mode == "edge" then
				if used > 0 and used + h > mh then
					col, used = col + 1, 0
				end
				dx = sign * (mw / 2 + MARGIN + w / 2 + col * (w + GAP))
				dy = mh / 2 - h / 2 - used
				used = used + h + GAP
			else
				if used > 0 and used + w > mw then
					row, used = row + 1, 0
				end
				dx = -mw / 2 + w / 2 + used
				dy = -(mh / 2 + room + h / 2 + row * (h + GAP))
				used = used + w + GAP
			end
			pcall(Put, button, dx, dy, map)
		end
	end
end

local function StopTicker()
	if state.ticker and state.ticker.Cancel then
		pcall(state.ticker.Cancel, state.ticker)
	end
	state.ticker = nil
end

-- The ticker runs only while the map has a button of the library to place, so a map without one sets no timer. A button made later is found at the
-- next event of an addon loading or of the world, or at the next change of the row.
local function Pass()
	local mode = Mode()
	if mode == "leave" then
		StopTicker()
		Restore()
		return
	end
	local map = Map()
	if map == nil then
		return
	end
	-- A button kept in place since the last pass gets its points back before the others are laid out.
	Restore(true)
	local buttons = Buttons(map)
	if buttons and #buttons == 0 then
		StopTicker()
	elseif state.ticker == nil and C_Timer and C_Timer.NewTicker then
		local ok, ticker = pcall(C_Timer.NewTicker, 1, Pass)
		state.ticker = ok and ticker or nil
	end
	if buttons then
		Place(map, buttons, mode)
	end
end

-- Config changed callback of the row Addon buttons.
function ns.MapButtonsChanged()
	Pass()
end

-- For Fading: every shown, unprotected button of the library on the map, kept in place or not and whatever Addon buttons says, as
-- { name = full name, frame = button }. Looked for again after LOOK_AGAIN seconds; an empty list when the map cannot be read.
function ns.MapAddonButtons()
	local now = Now()
	if state.found and now and state.foundAt and now >= state.foundAt and now - state.foundAt < LOOK_AGAIN then
		return state.found
	end
	local map = Map()
	local all = map and Scan(map) or nil
	state.found, state.foundAt = all or {}, now
	return state.found
end

-- The number of a name in the list row, the same for the whole session, so a pick finds its button however the list has changed since it opened.
local function IdOf(short)
	local id = state.ids[short]
	if id == nil then
		id = #state.names + 1
		state.names[id] = short
		state.ids[short] = id
	end
	return id
end

-- The lines of Leave in place: each button found, by the name after the prefix, with a tick on those left in place.
function ns.MapButtonLines()
	local map = Map()
	local lines = {}
	for _, entry in ipairs(map and Scan(map) or {}) do
		local short = entry.name:sub(#PREFIX + 1)
		if #short <= LONGEST then
			lines[#lines + 1] = { IdOf(short), Kept(entry.name) and (TICK .. short) or short }
		end
	end
	return lines
end

-- A pick of Leave in place: the button is left where its addon puts it, or placed with the others again.
function ns.MapButtonPick(id)
	local short = Num(id) and state.names[id] or nil
	if short == nil then
		return false, "Choose a button."
	end
	local keep = KeptNames(true)
	if keep == nil then
		return false, "Flat UI cannot keep this until the game has loaded its saved settings."
	end
	local said
	if keep[short] == true then
		keep[short] = nil
		said = ("%s goes with the other buttons again."):format(short)
	else
		local count = 0
		for _ in pairs(keep) do
			count = count + 1
		end
		if count >= MOST_KEPT then
			return false, ("%d buttons is the most that can be left in place."):format(MOST_KEPT)
		end
		keep[short] = true
		said = ("%s stays where its addon puts it."):format(short)
	end
	Pass()
	return true, said
end

-- /flatui status: how many of the buttons found are left in place, while the others are placed.
ns.AddStatus("hud", function()
	if Mode() == "leave" or KeptNames(false) == nil then
		return {}
	end
	local map = Map()
	local count = 0
	for _, entry in ipairs(map and Scan(map) or {}) do
		if Kept(entry.name) then
			count = count + 1
		end
	end
	if count == 0 then
		return {}
	end
	if count == 1 then
		return { "Addon buttons: 1 left where its addon puts it." }
	end
	return { ("Addon buttons: %d left where their addons put them."):format(count) }
end)

local events = CreateFrame("Frame")
ns.Own[events] = true
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", Pass)
