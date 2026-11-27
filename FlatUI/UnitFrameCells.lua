local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART, BARS = "Raid cells", "Player bars"
local THIN, GAME = 4, 8
local GREY = 0.5

local function On(rec)
	return rec.kind == "raid" and X.opt("raidCells") == true and not ns.PartStopped(KEY, PART)
end

local function Corner(bar)
	local ok, count = pcall(bar.GetNumPoints, bar)
	if not ok or not X.number(count) then
		return nil
	end
	for index = 1, count do
		local fine, point, relative, relativePoint, x, y = pcall(bar.GetPoint, bar, index)
		if fine and point == "BOTTOMRIGHT" and X.number(x) and X.number(y) and not ns.IsSecret(relative) then
			return relative, relativePoint, x, y
		end
	end
	return nil
end

local Place
function Place(rec, on)
	if rec.kind ~= "raid" then
		return
	end
	local power, health = rec.parts.power, rec.parts.health
	if power == nil or health == nil then
		return
	end
	local ok, shown = pcall(power.IsShown, power)
	shown = ok and shown == true
	local want = shown and (on and On(rec) and THIN or rec.cellThin and GAME) or nil
	if want == nil then
		rec.cellThin = nil
		return
	end
	local relative, relativePoint, x, y = Corner(health)
	if relative ~= nil and y == 1 + want then
		rec.cellThin = want == THIN or nil
		return
	end
	if InCombatLockdown() then
		rec.cellThin = relative ~= nil and y == 1 + THIN or nil
		if not rec.cellQueued then
			rec.cellQueued = true
			ns.OutOfCombat(function()
				rec.cellQueued = nil
				X.run(PART, Place, rec, X.active(rec))
			end)
		end
		return
	end
	if relative == nil then
		relative, relativePoint, x = rec.frame, "BOTTOMRIGHT", -1
	end
	if pcall(health.SetPoint, health, "BOTTOMRIGHT", relative, relativePoint, x, 1 + want) then
		rec.cellThin = want == THIN or nil
	end
end

local function Home(bar)
	local ok, count = pcall(bar.GetNumPoints, bar)
	if not ok or not X.number(count) then
		return nil
	end
	for index = 1, count do
		local fine, point, relative, relativePoint, x, y = pcall(bar.GetPoint, bar, index)
		if fine and point == "TOPLEFT" and X.number(x) and X.number(y) and not ns.IsSecret(relative) and not ns.IsSecret(relativePoint) then
			return relative, relativePoint, x, y
		end
	end
	return nil
end

local function Gap(power)
	local thickness = ns.Get("general.thickness")
	if X.opt("frameStyle") == "one" then
		return ns.Pixels(power, thickness + (tonumber(X.opt("powerSpace")) or 0))
	end
	return math.max(1, ns.Pixels(power, 2 * thickness))
end

local function Overlap(health, power)
	local ok, _, bottom = pcall(health.GetRect, health)
	local fine, _, low, _, height = pcall(power.GetRect, power)
	if ok and fine and X.number(bottom) and X.number(low) and X.number(height) then
		return math.floor((bottom - (low + height)) * 10 + 0.5) / 10
	end
	return nil
end

local function Hang(rec)
	if rec.kind ~= "player" then
		return
	end
	local power, health = rec.parts.power, rec.parts.health
	if power == nil or health == nil or ns.Forbidden(power) or ns.Forbidden(health) then
		return
	end
	local want = X.active(rec) and not ns.PartStopped(KEY, BARS)
	local relative, relativePoint, x, y = Home(power)
	local mine = relative == health
	if relative ~= nil and not mine then
		rec.barHome = { relative, relativePoint, x, y }
		rec.barGame = Overlap(health, power)
	end
	local gap = -Gap(power)
	if want and mine and relativePoint == "BOTTOMLEFT" and x == 0 and math.abs(y - gap) < 0.001 then
		rec.barHung = true
		return
	end
	if not want and not rec.barHung then
		return
	end
	if not want and not mine then
		rec.barHung = nil
		return
	end
	if InCombatLockdown() then
		if not rec.barQueued then
			rec.barQueued = true
			ns.OutOfCombat(function()
				rec.barQueued = nil
				X.run(BARS, Hang, rec)
			end)
		end
		return
	end
	if want then
		rec.barHung = ns.SecurePoint(power, "TOPLEFT", health, "BOTTOMLEFT", 0, gap) or nil
	elseif rec.barHome == nil or ns.SecurePoint(power, "TOPLEFT", rec.barHome[1], rec.barHome[2], rec.barHome[3], rec.barHome[4]) then
		rec.barHung = nil
	end
end

function ns.PlayerBarStatus()
	for _, rec in pairs(X.records) do
		if rec.kind == "player" and rec.made then
			if rec.barQueued then
				return "Player bars: waiting for the end of combat"
			elseif not rec.barHung then
				return "Player bars: the game's layout"
			end
			local gap = Gap(rec.parts.power)
			local text = ("Player bars: %s apart"):format(math.abs(gap - 1) < 0.05 and "1 unit" or ("%.1f units"):format(gap))
			if rec.barGame ~= nil and rec.barGame < 0 then
				text = text .. (". The game's layout had them overlapping by %.1f units"):format(-rec.barGame)
			elseif rec.barGame ~= nil and rec.barGame < 1 then
				text = text .. (". The game's layout had them %.1f units apart"):format(rec.barGame)
			end
			return text
		end
	end
	return nil
end

local function Grey(rec, on)
	if not on or not On(rec) or rec.parts.health == nil then
		return
	end
	local unit = rec.frame.unit
	if unit == nil or ns.IsSecret(unit) or type(unit) ~= "string" or unit == "" or type(UnitIsConnected) ~= "function" or type(UnitIsDead) ~= "function" then
		return
	end
	local ok, connected = pcall(UnitIsConnected, unit)
	local fine, dead = pcall(UnitIsDead, unit)
	if ok and fine and not ns.IsSecret(connected) and not ns.IsSecret(dead) and (connected == false or dead == true) then
		pcall(rec.parts.health.SetStatusBarColor, rec.parts.health, GREY, GREY, GREY)
	end
end

function ns.RaidCellStatus()
	local made, moved, waiting = 0, 0, 0
	for _, rec in pairs(X.records) do
		if rec.kind == "raid" and rec.made then
			made = made + 1
			moved = moved + (rec.cellThin and 1 or 0)
			waiting = waiting + (rec.cellQueued and 1 or 0)
		end
	end
	if made == 0 then
		return nil
	end
	if X.opt("raidCells") ~= true then
		return "Raid cells: off"
	end
	return ("Raid cells: thin power bar on %d of %d frames%s"):format(moved, made, waiting > 0 and (", waiting for combat on " .. waiting) or "")
end

table.insert(X.after.apply, { part = PART, fn = Place })
table.insert(X.after.raid, { part = PART, fn = Place })
table.insert(X.after.colour, { part = PART, fn = Grey })
table.insert(X.after.apply, { part = BARS, fn = Hang })
table.insert(X.before.layout, { part = BARS, fn = Hang })
