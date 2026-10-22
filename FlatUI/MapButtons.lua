local _, ns = ...

-- The round buttons that addons put on the minimap with LibDBIcon (frames named LibDBIcon10_<addon>, children of Minimap). The library treats the map as
-- square and puts them on its edge, so on a round map they hang over it. Not a module. The library's code is not in client/: unseen.
-- Only ClearAllPoints and SetPoint on frames that are not protected. No mouse, no alpha, no script of another addon, nothing written to any addon's
-- saved data. A secret answer from a size, a centre, a point or a child list stops the pass and the buttons stay (SimpleFrameAPIDocumentation.lua:323-335,
-- SimpleScriptRegionAPIDocumentation.lua:145-149, SimpleScriptRegionResizingAPIDocumentation.lua:65-75).
-- bar: the row starts below the coordinate text of the map (Blizzard_Minimap/Mainline/Minimap.xml:425-428).

local PREFIX = "LibDBIcon10_"
local GAP = 2
-- Between the map and the column; the room under the map for the coordinate text.
local MARGIN, TEXT = 3, 24

local weak = { __mode = "k" }
-- Per button: the points it had before this file moved it.
local recorded = setmetatable({}, weak)
local state = { ticker = nil }

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

-- The buttons of the library that this file may place, by name; nil when the list could not be read.
local function Buttons(map)
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
			if type(name) == "string" and name:sub(1, #PREFIX) == PREFIX and Ask(child.IsProtected, child) == false and Ask(child.IsShown, child) == true then
				out[#out + 1] = { name = name, frame = child }
			end
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
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

local function Restore()
	for button, points in pairs(recorded) do
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
end

local function Place(map, buttons, mode)
	local mw, mh = Ask(map.GetWidth, map), Ask(map.GetHeight, map)
	local mx, ux = Ask(map.GetCenter, map), UIParent and Ask(UIParent.GetCenter, UIParent)
	-- A centre is in the scale of its own frame, and the Edit Mode size of the map scales its container (Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua:2495).
	local ms, us = Ask(map.GetEffectiveScale, map), UIParent and Ask(UIParent.GetEffectiveScale, UIParent)
	if not (Num(mw) and Num(mh) and Num(mx) and Num(ux) and Num(ms) and Num(us)) then
		return
	end
	-- The side that faces the screen centre.
	local sign = mx * ms > ux * us and -1 or 1
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
				dy = -(mh / 2 + TEXT + h / 2 + row * (h + GAP))
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

-- The ticker runs only while the map has a button of the library, so a map without one sets no timer. A button made later is found at the next
-- event of an addon loading or of the world, or at the next change of the row.
local function Pass()
	local mode = Mode()
	if mode == "leave" then
		StopTicker()
		Restore()
		return
	end
	local map = Minimap
	if type(map) ~= "table" or ns.IsSecret(map) or ns.Forbidden(map) then
		return
	end
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

local events = CreateFrame("Frame")
ns.Own[events] = true
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", Pass)
