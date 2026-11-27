local _, ns = ...

local PREFIX = "LibDBIcon10_"
local GAP = 2
local MARGIN, TEXT = 3, 24
local LOOK_AGAIN = 1
local TICK = "|A:common-icon-checkmark:14:14|a "
local MOST_KEPT, LONGEST = 200, 120

local weak = { __mode = "k" }
local recorded = setmetatable({}, weak)
local ROUND_FILES = { [136430] = true, [136467] = true }
local ROUND_PATHS = { "minimap\\minimap-trackingborder", "minimap\\ui-minimap-background" }
local ROUND_ATLAS = "ui-hud-minimap-button"
local INSET = 4
local skinned = setmetatable({}, weak)
local state = { ticker = nil, found = nil, foundAt = nil, ids = {}, names = {} }

local function Num(value)
	return type(value) == "number" and not ns.IsSecret(value) and value == value
end

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

local function Kept(name)
	local keep = KeptNames(false)
	return keep ~= nil and type(name) == "string" and keep[name:sub(#PREFIX + 1)] == true
end

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

local function Now()
	local ok, now = pcall(GetTime)
	return ok and Num(now) and now or nil
end

local function Fresh(map)
	local all = Scan(map)
	if all then
		state.found, state.foundAt = all, Now()
	end
	return all
end

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

local function Flat()
	return Mode() ~= "leave" and ns.Get("hud.addonButtonsFlat") == true
end

local function RoundArt(region)
	if Ask(region.GetObjectType, region) ~= "Texture" then
		return false
	end
	local file = Ask(region.GetTexture, region)
	if type(file) == "number" and ROUND_FILES[file] then
		return true
	elseif type(file) == "string" then
		local path = (file:lower():gsub("/", "\\"))
		for _, known in ipairs(ROUND_PATHS) do
			if path:find(known, 1, true) then
				return true
			end
		end
	end
	local atlas = Ask(region.GetAtlas, region)
	return type(atlas) == "string" and atlas:lower():sub(1, #ROUND_ATLAS) == ROUND_ATLAS
end

local function FadeRegion(rec, region)
	local alpha = Ask(region.GetAlpha, region)
	if Num(alpha) and alpha > 0 then
		if rec.faded[region] == nil then
			rec.faded[region] = alpha
		end
		pcall(region.SetAlpha, region, 0)
	end
end

local function Skin(button)
	local rec = skinned[button]
	local regions = { pcall(button.GetRegions, button) }
	if not regions[1] then
		return
	end
	local round = {}
	for i = 2, #regions do
		local region = regions[i]
		if ns.IsSecret(region) then
			return
		end
		if type(region) == "table" and not ns.Own[region] and RoundArt(region) then
			round[#round + 1] = region
		end
	end
	if rec == nil then
		if #round == 0 or InCombatLockdown() then
			return
		end
		local anchor = CreateFrame("Frame", nil, button)
		ns.Own[anchor] = true
		anchor:SetPoint("TOPLEFT", button, "TOPLEFT", INSET, -INSET)
		anchor:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -INSET, INSET)
		local hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 0)
		ns.Own[hover] = true
		hover:SetAllPoints(anchor)
		hover:SetColorTexture(1, 1, 1, 0.2)
		rec = { faded = setmetatable({}, weak), anchor = anchor, hover = hover, outline = ns.SetOutlineArea(ns.Outline(button, anchor), "hud") }
		skinned[button] = rec
		ns.Count("hud")
	end
	for _, region in ipairs(round) do
		FadeRegion(rec, region)
	end
	local highlight = Ask(button.GetHighlightTexture, button)
	if type(highlight) == "table" and highlight ~= rec.hover and not ns.Own[highlight] then
		FadeRegion(rec, highlight)
	end
	ns.SetOutline(rec.outline, true, true)
	rec.hover:Show()
	rec.on = true
end

local function Unskin(button)
	local rec = skinned[button]
	if rec == nil or not rec.on then
		return
	end
	for region, alpha in pairs(rec.faded) do
		pcall(region.SetAlpha, region, alpha)
		rec.faded[region] = nil
	end
	ns.SetOutline(rec.outline, false, false)
	rec.hover:Hide()
	rec.on = false
end

local function Give(button, points)
	Unskin(button)
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
	local ms, us = Ask(map.GetEffectiveScale, map), UIParent and Ask(UIParent.GetEffectiveScale, UIParent)
	if not (Num(mw) and Num(mh) and Num(mx) and Num(ux) and Num(ms) and Num(us)) then
		return
	end
	local sign = mx * ms > ux * us and -1 or 1
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
			if Flat() then
				pcall(Skin, button)
			else
				pcall(Unskin, button)
			end
		end
	end
end

local function StopTicker()
	if state.ticker and state.ticker.Cancel then
		pcall(state.ticker.Cancel, state.ticker)
	end
	state.ticker = nil
end

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

function ns.MapButtonsChanged()
	Pass()
end

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

local function IdOf(short)
	local id = state.ids[short]
	if id == nil then
		id = #state.names + 1
		state.names[id] = short
		state.ids[short] = id
	end
	return id
end

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
