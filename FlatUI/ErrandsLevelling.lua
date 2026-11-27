local _, ns = ...

local E = ns.Errands
local part = E.Part({ label = "Levelling" })

local BURST = 0.5
local TOP = 8
local MOST_FACTIONS = 400
local LEVEL_WAIT, LOGIN_WAIT = 2, 8
local TOLD_QUIET = 10
local WAY_WAIT, WAIT_STEP, WAIT_TRIES = 3, 0.5, 120
local WAY, WAY_KEY = "/way", "FLATUIWAY"
local TYPE_RANK = { [3] = 1, [2] = 2, [5] = 3, [6] = 4, [4] = 5 }
local MICRO = 5
local MOST_MAPS, MOST_NAMES = 5000, 4
local WORLD_TYPES = { [0] = true, [1] = true }
local WHY = { top = "you are exalted with it", inactive = "it is inactive", header = "it is a heading" }

local rep = { seen = {}, token = 0, ready = false, switches = 0 }
local talents = { token = 0 }
local way = { claimed = false, waited = false, token = 0 }

local function Tell(text)
	print("Flat UI: " .. text)
end

local function Field(t, key)
	if type(t) ~= "table" or ns.IsSecret(t) then
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

local function Rep()
	local R = C_Reputation
	if type(R) == "table" and not ns.IsSecret(R) then
		return R
	end
	return nil
end

local function Faction(data)
	local id, name = Field(data, "factionID"), Field(data, "name")
	if not ns.Finite(id) or id <= 0 or type(name) ~= "string" or name == "" then
		return nil
	end
	return {
		factionID = id, name = name, reaction = Field(data, "reaction"), currentReactionThreshold = Field(data, "currentReactionThreshold"),
		nextReactionThreshold = Field(data, "nextReactionThreshold"), currentStanding = Field(data, "currentStanding"),
		isHeader = Field(data, "isHeader") == true, isHeaderWithRep = Field(data, "isHeaderWithRep") == true,
		atWarWith = Field(data, "atWarWith") == true, isWatched = Field(data, "isWatched") == true,
	}
end

local function Classic(fn, arg, byID)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, name, _, reaction, low, high, value, war, _, header, _, hasRep, watched, _, id = pcall(fn, arg)
	if not ok then
		return nil
	end
	local function plain(v)
		if ns.IsSecret(v) then
			return nil
		end
		return v
	end
	return Faction({ factionID = plain(id) or byID, name = plain(name), reaction = plain(reaction), currentReactionThreshold = plain(low),
		nextReactionThreshold = plain(high), currentStanding = plain(value), isHeader = plain(header), isHeaderWithRep = plain(hasRep),
		atWarWith = plain(war), isWatched = plain(watched) })
end

local function Data(id)
	local R = Rep()
	if R and type(R.GetFactionDataByID) == "function" then
		return Faction((E.Ask(R.GetFactionDataByID, id)))
	end
	return Classic(_G.GetFactionInfoByID, id, id)
end

local function ByID()
	local R = Rep()
	return (R ~= nil and type(R.GetFactionDataByID) == "function") or type(_G.GetFactionInfoByID) == "function"
end

local function Inactive(create)
	if type(FlatUICharDB) ~= "table" then
		return nil
	end
	local kept = FlatUICharDB.errandsRepInactive
	if type(kept) ~= "table" then
		if not create then
			return nil
		end
		kept = {}
		FlatUICharDB.errandsRepInactive = kept
	end
	return kept
end

local function Walk()
	local R = Rep()
	local modern = R ~= nil and type(R.GetNumFactions) == "function" and type(R.GetFactionDataByIndex) == "function"
	local count
	if modern then
		count = E.Ask(R.GetNumFactions)
	else
		count = E.Ask(_G.GetNumFactions)
	end
	if not ns.Finite(count) or count < 1 then
		return 0
	end
	count = math.min(math.floor(count), MOST_FACTIONS)
	for index = 1, count do
		local f
		if modern then
			f = Faction((E.Ask(R.GetFactionDataByIndex, index)))
		else
			f = Classic(_G.GetFactionInfo, index)
		end
		if f then
			local entry = rep.seen[f.factionID]
			if not entry then
				entry = { standing = ns.Finite(f.currentStanding) and f.currentStanding or nil }
				rep.seen[f.factionID] = entry
			end
			entry.name = f.name
			local active
			if modern and type(R.IsFactionActive) == "function" then
				active = E.Ask(R.IsFactionActive, index)
			elseif type(_G.IsFactionInactive) == "function" then
				local inactive = E.Ask(_G.IsFactionInactive, index)
				if inactive == true or inactive == false then
					active = not inactive
				end
			end
			if active == true or active == false then
				entry.active = active
				local kept = Inactive(active == false)
				if kept then
					kept[f.factionID] = active == false or nil
				end
			end
		end
	end
	return count
end

local function WatchedID()
	local R = Rep()
	if R and type(R.GetWatchedFactionData) == "function" then
		local f = Faction((E.Ask(R.GetWatchedFactionData)))
		return f and f.factionID or nil
	end
	if type(_G.GetWatchedFactionInfo) == "function" then
		local ok, name, _, _, _, _, id = pcall(_G.GetWatchedFactionInfo)
		if ok and not ns.IsSecret(name) and not ns.IsSecret(id) and type(name) == "string" and name ~= "" and ns.Finite(id) and id > 0 then
			return id
		end
	end
	return nil
end

local function Followed()
	if rep.followed == nil then
		local saved = type(FlatUICharDB) == "table" and FlatUICharDB.errandsRep or nil
		rep.followed = ns.Finite(saved) and saved > 0 and saved or false
	end
	return rep.followed or nil
end

local function Redraw()
	if type(ns.XpBarRedraw) == "function" then
		pcall(ns.XpBarRedraw)
	end
	if type(ns.DataPanelMark) == "function" then
		pcall(ns.DataPanelMark, "rep")
	end
end

local function Follow(id)
	rep.followed = id
	rep.switches = rep.switches + 1
	if type(FlatUICharDB) == "table" then
		FlatUICharDB.errandsRep = id
	end
	Redraw()
end

local function PassOver(id)
	local f = Data(id)
	if not f then
		return "unknown", nil
	elseif f.isHeader and not f.isHeaderWithRep then
		return "header", f.name
	elseif ns.Finite(f.reaction) and f.reaction >= TOP then
		return "top", f.name
	end
	local entry, kept = rep.seen[id], Inactive()
	if (entry and entry.active == false) or ((not entry or entry.active == nil) and kept and kept[id]) then
		return "inactive", f.name
	end
	return nil, f.name
end

local function Decide(token)
	if token ~= rep.token or not rep.burst then
		return
	end
	local burst, order = rep.burst, rep.order
	rep.burst, rep.order = nil, nil
	if not E.On("repFollow") then
		return
	end
	local best, most
	for _, id in ipairs(order) do
		local gain = burst[id]
		if most == nil or gain > most then
			local why, name = PassOver(id)
			if why == nil then
				best, most = id, gain
			elseif name then
				rep.passed = { name = name, why = why }
			end
		end
	end
	if best and best ~= Followed() then
		Follow(best)
	end
end

local function Gained(id, standing)
	if ns.IsSecret(id) or not ns.Finite(id) or id <= 0 then
		return
	end
	if ns.IsSecret(standing) or not ns.Finite(standing) then
		standing = nil
	end
	local entry = rep.seen[id]
	local before = entry and entry.standing or nil
	if entry then
		entry.standing = standing or entry.standing
	else
		rep.seen[id] = { standing = standing }
	end
	if not E.On("repFollow") then
		return
	end
	local gain = 0
	if before and standing then
		if standing <= before then
			return
		end
		gain = standing - before
	end
	if not rep.burst then
		rep.burst, rep.order = {}, {}
		rep.token = rep.token + 1
		local token = rep.token
		C_Timer.After(BURST, function()
			E.Run(part, Decide, token)
		end)
	end
	if rep.burst[id] == nil then
		rep.order[#rep.order + 1] = id
		rep.burst[id] = 0
	end
	rep.burst[id] = rep.burst[id] + gain
end

local function Look()
	rep.queued = false
	local count = Walk()
	local watched = WatchedID()
	if not rep.ready then
		if count > 0 then
			rep.ready, rep.watched = true, watched
		end
		return
	end
	if watched ~= rep.watched then
		local was = rep.watched
		rep.watched = watched
		if watched and E.On("repFollow") and watched ~= Followed() then
			Follow(watched)
		elseif not watched and was and E.On("repFollow") and was == Followed() then
			Follow(false)
		end
	end
end

local function Changed()
	if rep.queued then
		return
	end
	rep.queued = true
	C_Timer.After(0, function()
		E.Run(part, Look)
	end)
end

function ns.ErrandsRepFollowed()
	if not E.On("repFollow") or ns.PartStopped("errands", part.label) then
		return nil
	end
	local data
	if not E.Run(part, function()
		local id = Followed()
		data = id and Data(id) or nil
	end) then
		return nil
	end
	return data
end

E.Listen(part, "FACTION_STANDING_CHANGED", Gained)
E.Listen(part, "UPDATE_FACTION", Changed)

local function Points()
	local T = C_ClassTalents
	if type(T) == "table" and not ns.IsSecret(T) and type(T.HasUnspentTalentPoints) == "function" then
		local has, class, spec = E.Ask(T.HasUnspentTalentPoints)
		if has == true then
			local n = (ns.Finite(class) and class > 0 and class or 0) + (ns.Finite(spec) and spec > 0 and spec or 0)
			return n > 0 and math.floor(n) or true
		elseif has == false then
			return 0
		end
		return nil
	end
	local n = E.Ask(_G.GetUnspentTalentPoints)
	if ns.Finite(n) then
		return math.max(0, math.floor(n))
	end
	n = E.Ask(_G.UnitCharacterPoints, "player")
	if ns.Finite(n) then
		return math.max(0, math.floor(n))
	end
	return nil
end

local function PointsText(n)
	if n == true then
		return "You have talent points to spend."
	elseif n == 1 then
		return "You have a talent point to spend."
	end
	return ("You have %d talent points to spend."):format(n)
end

local function TalentKey()
	local key = E.Ask(_G.GetBindingKey, "TOGGLETALENTS")
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = E.Ask(_G.GetBindingText, key)
	return type(text) == "string" and text ~= "" and text or key
end

local function Remind(token)
	if token ~= talents.token then
		return
	end
	if not E.On("talentReminder") then
		talents.waiting = nil
		return
	end
	if E.Fighting() then
		talents.waiting = true
		return
	end
	talents.waiting = nil
	local n = Points()
	if n == nil or n == 0 then
		return
	end
	local now = E.Ask(_G.GetTime) or 0
	if talents.told == n and talents.toldAt and now - talents.toldAt < TOLD_QUIET then
		return
	end
	talents.told, talents.toldAt = n, now
	local key = TalentKey()
	Tell(PointsText(n) .. (key and (" Press %s to open your talents."):format(key) or ""))
end

local function Later(seconds)
	talents.token = talents.token + 1
	local token = talents.token
	C_Timer.After(seconds, function()
		E.Run(part, Remind, token)
	end)
end

E.Listen(part, "PLAYER_LEVEL_UP", function()
	if E.On("talentReminder") then
		Later(LEVEL_WAIT)
	end
end)
E.Listen(part, "PLAYER_ENTERING_WORLD", function(initial)
	if not ns.IsSecret(initial) and initial == true and E.On("talentReminder") then
		Later(LOGIN_WAIT)
	end
end)
E.Listen(part, "PLAYER_REGEN_ENABLED", function()
	if talents.waiting then
		Later(1)
	end
end)

local function Map()
	local M = C_Map
	if type(M) == "table" and not ns.IsSecret(M) then
		return M
	end
	return nil
end

local function Track()
	local S = C_SuperTrack
	if type(S) == "table" and not ns.IsSecret(S) and type(S.SetSuperTrackedUserWaypoint) == "function" then
		return S
	end
	return nil
end

local function Pins()
	local M = Map()
	return M ~= nil and type(M.SetUserWaypoint) == "function" and type(M.CanSetUserWaypointOnMap) == "function"
end

local function MapInfo(id)
	local M = Map()
	if not M or not ns.Finite(id) then
		return nil
	end
	local info = E.Ask(M.GetMapInfo, id)
	local name, kind, parent = Field(info, "name"), Field(info, "mapType"), Field(info, "parentMapID")
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return { id = id, name = name, kind = ns.Finite(kind) and kind or nil, parent = ns.Finite(parent) and parent > 0 and parent or nil }
end

local function Here()
	local M = Map()
	local id = M and E.Ask(M.GetBestMapForUnit, "player")
	local info = MapInfo(id)
	local steps = 0
	while info and info.kind == MICRO and info.parent and steps < 5 do
		local up = MapInfo(info.parent)
		if not up then
			break
		end
		info, steps = up, steps + 1
	end
	return info
end

local function Squash(text)
	return (text:lower():gsub("[%s%p]", ""))
end

local function Top(id)
	local top, steps = MapInfo(id), 0
	while top and top.parent and steps < 10 do
		local up = MapInfo(top.parent)
		if not up then
			break
		end
		top, steps = up, steps + 1
	end
	return top
end

local function Index()
	if way.index then
		return way.index
	end
	local M = Map()
	if not M or type(M.GetMapChildrenInfo) ~= "function" then
		return nil
	end
	local top = Top(E.Ask(M.GetBestMapForUnit, "player"))
	if not (top and WORLD_TYPES[top.kind]) then
		top = Top(E.Ask(M.GetFallbackWorldMapID)) or top
	end
	if not top then
		return nil
	end
	local list = E.Ask(M.GetMapChildrenInfo, top.id, nil, true)
	if type(list) ~= "table" then
		return nil
	end
	local index, zones = {}, 0
	for i = 1, MOST_MAPS do
		local child = Field(list, i)
		if child == nil then
			break
		end
		local cid, name, kind = Field(child, "mapID"), Field(child, "name"), Field(child, "mapType")
		if ns.Finite(cid) and type(name) == "string" and name ~= "" and TYPE_RANK[kind] then
			index[#index + 1] = { id = cid, name = name, key = Squash(name), rank = TYPE_RANK[kind] }
			if TYPE_RANK[kind] == 1 then
				zones = zones + 1
			end
		end
	end
	if zones > 0 then
		way.index = index
	end
	return index
end

local function Best(list)
	local M = Map()
	local pick, pickPins
	for _, entry in ipairs(list) do
		local pins = M ~= nil and E.Ask(M.CanSetUserWaypointOnMap, entry.id) == true
		if not pick or (pins and not pickPins) or (pins == pickPins and (entry.rank < pick.rank or (entry.rank == pick.rank and entry.id < pick.id))) then
			pick, pickPins = entry, pins
		end
	end
	return pick and { id = pick.id, name = pick.name } or nil
end

local function Resolve(name)
	local index = Index()
	if not index then
		return nil, nil, "names"
	end
	local key = Squash(name)
	if key == "" then
		return nil, {}
	end
	local exact, starts, names, seen = {}, {}, {}, {}
	for _, entry in ipairs(index) do
		if entry.key == key then
			exact[#exact + 1] = entry
		elseif entry.key:sub(1, #key) == key then
			starts[#starts + 1] = entry
			if not seen[entry.name] then
				seen[entry.name] = true
				names[#names + 1] = entry.name
			end
		end
	end
	if #exact > 0 then
		return Best(exact)
	elseif #names == 1 then
		return Best(starts)
	end
	table.sort(names)
	return nil, names
end

local function Number(token)
	if type(token) ~= "string" or not (token:match("^%d+%.?%d*$") or token:match("^%.%d+$")) then
		return nil
	end
	return tonumber(token)
end

local function Comma(token)
	if type(token) ~= "string" then
		return nil
	end
	local a, b = token:match("^([%d%.]+),([%d%.]+)$")
	if a and Number(a) and Number(b) then
		return a, b, (a:find(".", 1, true) or b:find(".", 1, true)) ~= nil
	end
	return nil
end

local function Parse(msg)
	msg = (type(msg) == "string" and msg or ""):match("^%s*(.-)%s*$")
	if msg == "" then
		return { empty = true }
	end
	local word = msg:lower()
	if word == "clear" or word == "reset" or word == "remove" or word == "off" then
		return { clear = true }
	end
	msg = msg:gsub("(%d)%s*,%s+", "%1 "):gsub("(%d)%s+,(%d)", "%1 %2")
	local tokens = {}
	for token in msg:gmatch("%S+") do
		tokens[#tokens + 1] = token
	end
	local mapID
	local hash = tokens[1] and tokens[1]:match("^#(%d+)$")
	if hash then
		mapID = tonumber(hash)
		table.remove(tokens, 1)
	end
	local at
	for index, token in ipairs(tokens) do
		if Number(token) or Comma(token) then
			at = index
			break
		end
	end
	if not at then
		return nil, "numbers"
	end
	local name = not mapID and at > 1 and table.concat(tokens, " ", 1, at - 1) or nil
	local numbers, i, decimal = {}, at, false
	local function MapFirst()
		return not mapID and not name and numbers[1] ~= nil and numbers[1] > 100 and numbers[1] == math.floor(numbers[1])
	end
	while i <= #tokens and #numbers < (MapFirst() and 3 or 2) do
		local token = tokens[i]
		local a, b, dotted = Comma(token)
		if a then
			local want = (MapFirst() and 3 or 2) - #numbers
			if not dotted and want == 1 then
				numbers[#numbers + 1], decimal = tonumber(a .. "." .. b), true
			elseif not dotted and (decimal or select(3, Comma(tokens[i + 1])) == false or (#b == 1 and Number(tokens[i + 1]))) then
				numbers[#numbers + 1], decimal = tonumber(a .. "." .. b), true
			else
				numbers[#numbers + 1] = tonumber(a)
				numbers[#numbers + 1] = tonumber(b)
			end
		elseif Number(token) then
			numbers[#numbers + 1] = Number(token)
		else
			break
		end
		i = i + 1
	end
	local x, y = numbers[1], numbers[2]
	if MapFirst() and numbers[3] then
		mapID, x, y = numbers[1], numbers[2], numbers[3]
	end
	if not (x and y) then
		return nil, "numbers"
	end
	if x > 100 or y > 100 then
		return nil, "range"
	end
	local note = tokens[i] and table.concat(tokens, " ", i) or nil
	return { mapID = mapID, name = name, x = x, y = y, note = note }
end

local function Command()
	return way.claimed and WAY or "/flatui way"
end

local function Usage()
	local cmd, here = Command(), Here()
	local name, id = here and here.name or "Elwynn Forest", here and here.id or 1429
	return ("%s 45.2 61.8 puts a pin on your map there. %s %s 45 61, %s #%d 45 61 and %s clear work too."):format(cmd, cmd, name, cmd, id, cmd)
end

local function Coord(v)
	return ("%.1f"):format(v)
end

local function Point(id, x, y)
	if type(UiMapPoint) == "table" and not ns.IsSecret(UiMapPoint) and type(UiMapPoint.CreateFromCoordinates) == "function" then
		local point = E.Ask(UiMapPoint.CreateFromCoordinates, id, x, y)
		if type(point) == "table" then
			return point
		end
	end
	if type(CreateVector2D) == "function" then
		local position = E.Ask(CreateVector2D, x, y)
		if type(position) == "table" then
			return { uiMapID = id, position = position }
		end
	end
	return nil
end

local function Where()
	local M = Map()
	local here = Here()
	if here then
		local pos = E.Ask(M.GetPlayerMapPosition, here.id, "player")
		local x, y = Field(pos, "x"), Field(pos, "y")
		if ns.Finite(x) and ns.Finite(y) then
			Tell(("You are at %s %s, %s."):format(here.name, Coord(x * 100), Coord(y * 100)))
		end
	end
	if E.Ask(M.HasUserWaypoint) == true then
		local point = E.Ask(M.GetUserWaypoint)
		local map = MapInfo(Field(point, "uiMapID"))
		local position = Field(point, "position")
		local x, y = Field(position, "x"), Field(position, "y")
		if map and ns.Finite(x) and ns.Finite(y) then
			Tell(("Your waypoint: %s %s, %s."):format(map.name, Coord(x * 100), Coord(y * 100)))
		end
	end
end

local function Drop()
	way.pending = nil
	way.token = way.token + 1
end

local function ClearNow()
	Drop()
	local M = Map()
	E.Call(M.ClearUserWaypoint)
	local S = Track()
	if S then
		E.Call(S.SetSuperTrackedUserWaypoint, false)
	end
	way.last = nil
	Tell("Waypoint cleared.")
end

local function SetNow(map, p, point)
	Drop()
	local ok, set = pcall(Map().SetUserWaypoint, point)
	if not ok or (not ns.IsSecret(set) and set == false) then
		Tell("the game did not take that waypoint.")
		return
	end
	local S = Track()
	if S then
		E.Call(S.SetSuperTrackedUserWaypoint, true)
	end
	way.last = ("%s %s, %s"):format(map.name, Coord(p.x), Coord(p.y))
	Tell(("Waypoint at %s%s."):format(way.last, p.note and (": " .. p.note) or ""))
end

local function LookForMap(token, tries)
	local pending = way.pending
	if token ~= way.token or not pending then
		return
	elseif not E.On("wayCommand") then
		Drop()
		return
	elseif E.Shown(_G.WorldMapFrame) then
		if tries >= WAIT_TRIES then
			Drop()
			Tell(("the map stayed open, so the waypoint you typed was dropped. Close the map and type %s again."):format(Command()))
			return
		end
		C_Timer.After(WAIT_STEP, function()
			E.Run(part, LookForMap, token, tries + 1)
		end)
		return
	end
	if pending.clear then
		ClearNow()
	else
		SetNow(pending.map, pending.p, pending.point)
	end
end

local function Wait(pending)
	Drop()
	way.pending = pending
	local token = way.token
	Tell(pending.clear and "the waypoint comes off as you close the map." or "the waypoint goes on as you close the map.")
	C_Timer.After(WAIT_STEP, function()
		E.Run(part, LookForMap, token, 1)
	end)
end

local function Clear()
	local M = Map()
	local waiting = way.pending
	if E.Ask(M.HasUserWaypoint) == false then
		Drop()
		if waiting and not waiting.clear then
			Tell("the waypoint that waited for the map to close is dropped.")
		else
			Tell("There is no waypoint to clear.")
		end
		return
	end
	if E.Shown(_G.WorldMapFrame) then
		Wait({ clear = true })
		return
	end
	ClearNow()
end

local function List(names)
	local shown = {}
	for index = 1, math.min(#names, MOST_NAMES) do
		shown[index] = names[index]
	end
	if #names > MOST_NAMES then
		shown[#shown + 1] = "more"
	end
	if #shown == 1 then
		return shown[1]
	end
	return table.concat(shown, ", ", 1, #shown - 1) .. " or " .. shown[#shown]
end

local function Way(msg)
	if not ns.Enabled("errands") then
		Tell("Errands is off. Tick Run errands on the Errands page.")
		return
	elseif E.Opt("wayCommand") ~= true then
		Tell("Add the /way command is off on the Quests and levelling tab of the Errands page.")
		return
	elseif not Pins() then
		Tell("this client has no map pins, so there is no waypoint to set.")
		return
	end
	local p, why = Parse(msg)
	if not p then
		Tell(why == "range" and ("%s takes coordinates from 0 to 100, as in %s 45.2 61.8."):format(Command(), Command()) or Usage())
		return
	elseif p.empty then
		Tell(Usage())
		Where()
		return
	elseif p.clear then
		Clear()
		return
	end
	local M = Map()
	local map
	if p.mapID then
		map = MapInfo(p.mapID)
		if not map then
			Tell(("no map has the ID %d."):format(p.mapID))
			return
		end
	elseif p.name then
		local names, problem
		map, names, problem = Resolve(p.name)
		if not map then
			if problem == "names" then
				Tell(("this client cannot find a zone by its name. %s #1429 45 61, with the map ID, works."):format(Command()))
			elseif names and #names > 0 then
				Tell(("%s could be %s. Type more of the name."):format(p.name, List(names)))
			else
				Tell(("no zone is called %s."):format(p.name))
			end
			return
		end
	else
		map = Here()
		if not map then
			Tell(("the game does not say where you are. Give the zone, as in %s Elwynn Forest 45 61."):format(Command()))
			return
		end
	end
	if E.Ask(M.CanSetUserWaypointOnMap, map.id) ~= true then
		Tell(("the game takes no waypoint on %s."):format(map.name))
		return
	end
	local point = Point(map.id, p.x / 100, p.y / 100)
	if not point then
		Tell("this client has no map pins, so there is no waypoint to set.")
		return
	end
	if E.Shown(_G.WorldMapFrame) then
		Wait({ map = map, p = p, point = point })
		return
	end
	SetNow(map, p, point)
end

local function OnWay(msg)
	if not E.Run(part, Way, msg) then
		Tell("/way failed. /flatui status shows why.")
	end
end

local function OtherWay()
	local found
	pcall(function()
		for key, value in pairs(_G) do
			if type(key) == "string" and type(value) == "string" and key:sub(1, 6) == "SLASH_" and key ~= "SLASH_" .. WAY_KEY .. "1"
				and not ns.IsSecret(value) and value:lower():match("^%s*(.-)%s*$") == WAY then
				found = key:match("^SLASH_(.-)%d+$") or key
				return
			end
		end
	end)
	if found then
		return found
	end
	local hash = _G.hash_SlashCmdList
	if type(hash) == "table" and not ns.IsSecret(hash) then
		local ok, fn = pcall(function()
			return hash[WAY:upper()]
		end)
		if ok and fn ~= nil and fn ~= OnWay then
			return "the game's list"
		end
	end
	return nil
end

local function Taken()
	local hash = _G.hash_SlashCmdList
	if type(hash) ~= "table" or ns.IsSecret(hash) then
		return false
	end
	local ok, fn = pcall(function()
		return hash[WAY:upper()]
	end)
	return ok and fn ~= nil and fn ~= OnWay
end

local function Claim()
	way.waited = true
	if way.claimed or not E.On("wayCommand") or not Pins() then
		return
	end
	way.owner = way.owner or OtherWay()
	if way.owner then
		return
	end
	SLASH_FLATUIWAY1 = WAY
	SlashCmdList[WAY_KEY] = OnWay
	way.claimed = true
end

E.slash.way = function(rest)
	OnWay(rest)
end
E.help[#E.help + 1] = "/flatui way 45 61 - put a pin on your map there; a zone name or #map ID may come first, and clear takes it off"
E.help[#E.help + 1] = "/way - the same, while nothing else has taken /way"

function part.Start()
	rep.ready, rep.burst, rep.order = false, nil, nil
	Look()
	Redraw()
	C_Timer.After(WAY_WAIT, function()
		E.Run(part, Claim)
	end)
end

function part.Refresh()
	if not E.On("repFollow") then
		rep.burst, rep.order = nil, nil
		rep.token = rep.token + 1
	end
	if not E.On("talentReminder") then
		talents.token, talents.waiting = talents.token + 1, nil
	end
	if not E.On("wayCommand") and way.pending then
		Drop()
	end
	if way.waited and E.On("wayCommand") then
		Claim()
	end
	Redraw()
end

function part.Status()
	local does = {}
	local follow, remind, command = E.Opt("repFollow") == true, E.Opt("talentReminder") == true, E.Opt("wayCommand") == true
	local shown = follow and Followed() and Data(Followed()) or nil
	if follow then
		does[#does + 1] = shown and ("shows the reputation you gain, now %s"):format(shown.name) or "shows the reputation you gain"
	end
	if remind then
		does[#does + 1] = "reminds you of talent points"
	end
	if command then
		does[#does + 1] = way.claimed and "adds /way" or "has /flatui way"
	end
	if #does == 0 then
		return {}
	end
	local lines = { "Levelling: " .. table.concat(does, ", ") .. "." }
	if follow then
		if rep.passed then
			lines[#lines + 1] = ("Levelling: passed over %s, as %s."):format(rep.passed.name, WHY[rep.passed.why] or "it cannot be shown")
		end
		if not (type(ns.XpOwn) == "function" and ns.XpOwn()) then
			lines[#lines + 1] = "Levelling: Flat UI's experience bar is off, so no bar shows the reputation you gain."
		elseif ns.Get("hud.xpShow") == "xp" then
			lines[#lines + 1] = "Levelling: Bars shown is Experience only, so the reputation bar is hidden."
		end
		local events, valid = C_EventUtils, nil
		if type(events) == "table" and not ns.IsSecret(events) then
			valid = E.Ask(events.IsEventValid, "FACTION_STANDING_CHANGED")
		end
		if valid == false then
			lines[#lines + 1] = "Levelling: this client does not report reputation gains, so the bar shows the faction you watch."
		elseif not ByID() then
			lines[#lines + 1] = "Levelling: this client cannot read a faction by its ID, so the bar shows the faction you watch."
		end
	end
	if remind then
		local n = Points()
		if n == nil then
			lines[#lines + 1] = "Levelling: this client does not say whether you have talent points to spend."
		elseif n ~= 0 then
			lines[#lines + 1] = "Levelling: " .. (PointsText(n):gsub("^You", "you"))
		end
	end
	if command then
		if not Pins() then
			lines[#lines + 1] = "Levelling: this client has no map pins, so /way is not added."
		elseif way.owner then
			lines[#lines + 1] = ("Levelling: another addon has /way (%s), so Flat UI does not add it. /flatui way does the same."):format(way.owner)
		elseif way.claimed and Taken() then
			lines[#lines + 1] = "Levelling: another addon took /way after Flat UI added it. /flatui way still works."
		end
		if way.last then
			lines[#lines + 1] = ("Levelling: last waypoint %s."):format(way.last)
		end
		local pending = way.pending
		if pending and pending.clear then
			lines[#lines + 1] = "Levelling: /way clear waits for the world map to close."
		elseif pending then
			lines[#lines + 1] = ("Levelling: a waypoint at %s %s, %s waits for the world map to close."):format(pending.map.name,
				Coord(pending.p.x), Coord(pending.p.y))
		end
	end
	return lines
end
