local ADDON_NAME, ns = ...

-- The icons and the power bars of the unit frames that each have a switch: the leader, role, PvP and raid marker icons, the dead text, the combat icon and
-- the pet's happiness face, and the power bar of each frame. Each is a region or a bar the game shows, hides and draws again and never fades, so off is a
-- change of its opacity to 0, and on gives it the opacity it had before. Nothing is called for a region that is not switched off and was not made
-- transparent here. This file adds its work after the steps of UnitFrames.lua through ns.UnitFrameExtra: a part that stops on errors counts as off here,
-- and every function can run twice with the same result. The PvP icon is the one switch that goes through the PvP flag of UnitFrames.lua (pvpMode), which
-- sets the opacity of the game's plate and icon itself. A power bar also goes when its unit has no power (Hide empty power bar).

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local MARKS, POWER = "Frame icons", "Power bars"

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The opacity a region had before it was made transparent, per part and region, and the parts the game refused a change for.
local kept = { [MARKS] = setmetatable({}, { __mode = "k" }), [POWER] = setmetatable({}, { __mode = "k" }) }
local refused = {}

-- True while a part is off: stopped after errors, or refused by the game.
local function Off(part)
	return refused[part] == true or ns.PartStopped(KEY, part)
end

-- Gives back what a part made transparent.
local function Release(part)
	local list = kept[part]
	if list == nil then
		return
	end
	for region, alpha in pairs(list) do
		list[region] = nil
		pcall(region.SetAlpha, region, alpha)
	end
end

-- The game refused a change of opacity: the part gives back what it changed, stays off, and says so.
local function Refuse(part, what)
	if refused[part] then
		return
	end
	refused[part] = true
	Release(part)
	ns.Note(KEY, ("Unit frames: %s stopped. The game refused a change of opacity on %s."):format(part, what))
end

-- Makes a region transparent for a part, or gives it the opacity it had. UnitExtras.lua uses it for its parts too.
function X.fade(part, region, hide)
	if region == nil or ns.IsSecret(region) or (hide and refused[part]) then
		return
	end
	local list = kept[part]
	if list == nil then
		list = setmetatable({}, { __mode = "k" })
		kept[part] = list
	end
	if hide then
		if list[region] == nil then
			local ok, alpha = pcall(region.GetAlpha, region)
			list[region] = ok and X.number(alpha) and alpha or 1
		end
		if not pcall(region.SetAlpha, region, 0) then
			Refuse(part, "a region of a frame")
		end
	elseif list[region] ~= nil then
		local alpha = list[region]
		list[region] = nil
		pcall(region.SetAlpha, region, alpha)
	end
end
X.off = Off
X.release = Release

local Fade = X.fade

-- Icons ------------------------------------------------------------------------------------------------------

-- The frame the game draws the icons of a frame on: the contextual frame of the player, target, focus and boss frames, the overlay of a party member.
local function Contextual(rec)
	local kind, frame = rec.kind, rec.frame
	if kind == "player" then
		return X.path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
	elseif kind == "target" or kind == "focus" or kind == "boss" then
		return X.path(frame, "TargetFrameContent", "TargetFrameContentContextual")
	elseif kind == "party" then
		return X.path(frame, "PartyMemberOverlay")
	end
	return nil
end

-- Per row: the regions it switches, given to emit. The party frame's PvP icon is the PvP flag's own.
local ROWS = {
	{ opt = "leaderIcon", find = function(rec, c, emit)
		emit(X.path(c, "LeaderIcon"))
		emit(X.path(c, "GuideIcon"))
	end },
	{ opt = "roleIcon", find = function(rec, c, emit)
		if rec.kind == "party" then
			emit(X.path(c, "RoleIcon"))
		end
	end },
	{ opt = "pvpIcon", find = function(rec, c, emit)
		if rec.kind ~= "party" then
			emit(X.path(c, "PVPIcon"))
			emit(X.path(c, "PrestigePortrait"))
			emit(X.path(c, "PrestigeBadge"))
		end
	end },
	{ opt = "raidMarker", find = function(rec, c, emit)
		if rec.kind == "target" or rec.kind == "focus" or rec.kind == "boss" then
			emit(X.path(c, "RaidTargetIcon"))
		end
	end },
	-- The dead and unconscious texts are on the container of the health bar, or on the health bar of the target of target frame.
	{ opt = "deadText", find = function(rec, c, emit)
		if rec.kind == "target" or rec.kind == "focus" or rec.kind == "boss" or rec.kind == "tot" then
			local parts = rec.parts
			for _, holder in ipairs({ parts.textBox or false, parts.healthBox or false, parts.health or false }) do
				if holder then
					emit(X.path(holder, "DeadText"))
					emit(X.path(holder, "UnconsciousText"))
				end
			end
		end
	end },
	{ opt = "combatIcon", find = function(rec, c, emit)
		if rec.kind == "player" then
			emit(X.path(c, "AttackIcon"))
		end
	end },
	{ opt = "petHappiness", find = function(rec, c, emit)
		if rec.kind == "pet" then
			emit(X.path(_G, "PetFrameHappiness"))
		end
	end },
}

local function Marks(rec, on)
	local live = on and not Off(MARKS)
	local c = Contextual(rec)
	for _, row in ipairs(ROWS) do
		local hide = live and Opt(row.opt) == false
		row.find(rec, c, function(region)
			Fade(MARKS, region, hide)
		end)
	end
end

-- How the PvP flag of a frame shows with PvP icon off: the icon goes and the word stays. UnitFrames.lua asks this for every flag it sets.
function X.pvpMode(rec, mode)
	if mode == nil or Opt("pvpIcon") ~= false or Off(MARKS) or not X.active(rec) then
		return mode
	end
	if mode == "both" then
		return "word"
	elseif mode == "icon" or mode == "game" then
		return "off"
	end
	return mode
end

-- Power bars -------------------------------------------------------------------------------------------------

-- The row of each frame's power bar. The party pet frame has no power bar and a raid frame's thin bar has its own look.
local POWER_ROWS = { player = "playerPowerBar", target = "targetPowerBar", focus = "focusPowerBar", pet = "petPowerBar", tot = "totPowerBar",
	party = "partyPowerBar", boss = "bossPowerBar" }

-- True when the unit of a frame has no power at all: a plain maximum of 0. A withheld answer, or no answer, is not empty.
local function Empty(rec)
	local unit = Opt("hideEmptyPower") ~= false and X.unitOf(rec)
	if not unit then
		return false
	end
	local ok, max = pcall(UnitPowerMax, unit)
	return ok and X.number(max) and max == 0
end

-- A power bar that is switched off, or that has nothing to show, is transparent, with its border and background hidden, and the strip stays empty. The
-- game writes opacity only on the fill of the bar, so the opacity of the bar itself is not drawn again.
local function Power(rec, on)
	local row, bar = POWER_ROWS[rec.kind], rec.parts.power
	if row == nil or bar == nil then
		return
	end
	rec.emptyPower = Empty(rec)
	local hide = on and not Off(POWER) and (Opt(row) == false or rec.emptyPower)
	Fade(POWER, bar, hide)
	local entry = rec.byRole.power
	if hide and entry ~= nil then
		X.outline(entry.outline, false, false)
	end
end

-- A frame whose unit gained or lost its power is drawn again.
local function Recheck(rec)
	if rec.made and POWER_ROWS[rec.kind] and X.active(rec) and Empty(rec) ~= (rec.emptyPower == true) then
		X.run(X.labels[rec.kind], X.apply, rec)
	end
end

local wasUnit = X.unitChanged
function X.unitChanged(rec)
	if wasUnit ~= nil then
		wasUnit(rec)
	end
	X.run(POWER, Recheck, rec)
end

local wasUnits = X.unitsChanged
function X.unitsChanged()
	if wasUnits ~= nil then
		wasUnits()
	end
	for _, rec in pairs(X.records) do
		X.run(POWER, Recheck, rec)
	end
end

ns.AddEvent(KEY, "UNIT_MAXPOWER", function(unit)
	for _, rec in pairs(X.records) do
		if ns.IsSecret(unit) or X.unitOf(rec) == unit then
			X.run(POWER, Recheck, rec)
		end
	end
end)

table.insert(X.after.apply, { part = MARKS, fn = Marks })
table.insert(X.after.apply, { part = POWER, fn = Power })
