local ADDON_NAME, ns = ...

-- The cell of a raid frame, and of a party frame in raid style: a thin power bar under the health bar, and a grey health bar for a unit that is dead or offline.
-- It also hangs the power bar of the player frame from the bottom of the health bar, in a secure snippet.
-- The border of the power bar, its flat fill and the switch of the look are in UnitFrames.lua, which outlines the game's power bar like any other bar. This
-- file adds its work after the steps of that file through ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run
-- twice with the same result. It never writes a field of the game's frame; it only moves the bottom edge of the health bar, which leaves the rest of the
-- cell to the power bar (the game anchors the power bar under the health bar and to the bottom of the frame).

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART, BARS = "Raid cells", "Player bars"
-- The height of the power bar in units, and the height the game gives it (CompactUnitFrame.lua:1904-1908).
local THIN, GAME = 4, 8
-- The grey the game gives the health bar of an offline unit and of a dead unit that is not a player (CompactUnitFrame.lua:656-658).
local GREY = 0.5

local function On(rec)
	return rec.kind == "raid" and X.opt("raidCells") == true and not ns.PartStopped(KEY, PART)
end

-- The BOTTOMRIGHT point of the health bar: its relative frame and point and its two offsets, or nil.
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

-- Puts the bottom edge of the health bar 1 unit plus the height the power bar takes above the bottom of the cell. Waits for the end of combat, when the
-- frame is protected, and leaves the bars as the game laid them until then.
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
		-- No bar to make room for: the game's own anchors are right, and the next set-up writes them again.
		rec.cellThin = nil
		return
	end
	local relative, relativePoint, x, y = Corner(health)
	if relative ~= nil and y == 1 + want then
		rec.cellThin = want == THIN or nil
		return
	end
	if InCombatLockdown() then
		-- What the bars are now, for the status and for putting the game's anchors back when the look goes in combat.
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

-- The TOPLEFT point of the player's power bar: its relative frame and point and its two offsets, or nil.
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

-- The space between the two bars in units: the two edges of the borders (each ns.Pixels(bar, thickness) outside its bar), and at least the game's own
-- 1 unit (Mainline/PlayerFrame.lua:707-727). At about 2 pixels per unit and a border of 1 pixel this is that 1 unit.
local function Gap(power)
	local thickness = ns.Get("general.thickness")
	return math.max(1, ns.Pixels(power, 2 * thickness))
end

-- How far the bottom of the health bar is below the top of the power bar, in tenths of a unit, or nil.
local function Overlap(health, power)
	local ok, _, bottom = pcall(health.GetRect, health)
	local fine, _, low, _, height = pcall(power.GetRect, power)
	if ok and fine and X.number(bottom) and X.number(low) and X.number(height) then
		return math.floor((bottom - (low + height)) * 10 + 0.5) / 10
	end
	return nil
end

-- Hangs the power bar of the player frame from the bottom of the health bar while the look is on, and gives the game's point back when it is off. Both
-- bars are protected, so the point is written in a secure snippet and never in combat. The game writes the point again with each art
-- (Mainline/PlayerFrame.lua:621, 727), and this runs after that and before the picture is sized from the bars: the point it finds that is not its own is
-- the game's, kept for giving back.
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
		-- The game laid the bar out again since: its point is already back.
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

-- The line of /flatui status about the player's bars: the gap, and the overlap the game's own layout had.
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

-- Grey for a unit that is offline or dead, the dead player too. The game's own colour comes back with its next update of the colour.
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

-- The line of /flatui status: the frames whose health bar was moved, and the ones that wait for the end of combat.
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
