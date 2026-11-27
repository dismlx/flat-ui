local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local MARKS, POWER = "Frame icons", "Power bars"

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local kept = { [MARKS] = setmetatable({}, { __mode = "k" }), [POWER] = setmetatable({}, { __mode = "k" }) }
local refused = {}

local function Off(part)
	return refused[part] == true or ns.PartStopped(KEY, part)
end

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

local function Refuse(part, what)
	if refused[part] then
		return
	end
	refused[part] = true
	Release(part)
	ns.Note(KEY, ("Unit frames: %s stopped. The game refused a change of opacity on %s."):format(part, what))
end

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

local ROWS = {
	{ opt = "leaderIcon", find = function(rec, c, emit)
		emit(X.path(c, "LeaderIcon"))
		emit(X.path(c, "GuideIcon"))
	end },
	{ opt = "roleIcon", left = function(rec) return X.roleLeftOut(rec) end, find = function(rec, c, emit)
		if rec.kind == "party" or rec.kind == "player" then
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

local followed = false

local function NumbersOff()
	return ns.Enabled(KEY) and not Off(MARKS) and Opt("hitNumbers") == false
end

local function PetNumberOff(rec)
	return rec.kind == "pet" and NumbersOff()
end

local function HidePetNumber(rec)
	if PetNumberOff(rec) then
		ns.SetHidden(X.path(_G, "PetHitIndicator"), true)
	end
end

local function OnFeedback(frame)
	local rec = X.known(frame)
	if rec ~= nil and rec.kind == "pet" then
		X.run(MARKS, HidePetNumber, rec)
	end
end

local function PetNumber(rec)
	if rec.kind ~= "pet" or not PetNumberOff(rec) then
		return
	end
	if not followed then
		followed = ns.FollowGlobal("CombatFeedback_OnCombatEvent", OnFeedback) == true
	end
	HidePetNumber(rec)
end

local function HitNumbers()
	local player, pet = X.known(_G.PlayerFrame), X.known(_G.PetFrame)
	if player ~= nil then
		Fade(MARKS, X.path(player.frame, "PlayerFrameContent", "PlayerFrameContentMain", "HitIndicator"), NumbersOff())
	end
	if pet ~= nil then
		PetNumber(pet)
	end
end

local function Marks(rec, on)
	local live = on and not Off(MARKS)
	local c = Contextual(rec)
	for _, row in ipairs(ROWS) do
		local hide = live and (Opt(row.opt) == false or (row.left ~= nil and row.left(rec) == true))
		row.find(rec, c, function(region)
			Fade(MARKS, region, hide)
		end)
	end
end

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

function X.role(unit)
	if unit == nil or type(UnitGroupRolesAssigned) ~= "function" then
		return nil
	end
	local ok, role = pcall(UnitGroupRolesAssigned, unit)
	if ok and not ns.IsSecret(role) and (role == "TANK" or role == "HEALER" or role == "DAMAGER") then
		return role
	end
	return nil
end

function X.assigned(assignment, unit)
	if unit == nil or type(GetPartyAssignment) ~= "function" then
		return false
	end
	local ok, yes = pcall(GetPartyAssignment, assignment, unit)
	return ok and not ns.IsSecret(yes) and yes ~= nil and yes ~= false
end

function X.isTank(unit)
	return unit ~= nil and (X.role(unit) == "TANK" or X.assigned("MAINTANK", unit))
end

local LEFT_OUT = { support = { DAMAGER = true }, healer = { TANK = true, DAMAGER = true } }

local function InVehicle(unit)
	if type(UnitInVehicle) ~= "function" or type(UnitHasVehicleUI) ~= "function" then
		return false
	end
	local ok, inside = pcall(UnitInVehicle, unit)
	local fine, bar = pcall(UnitHasVehicleUI, unit)
	return ok and fine and not ns.IsSecret(inside) and not ns.IsSecret(bar) and inside == true and bar == true
end

function X.roleLeftOut(rec)
	local out = (rec.kind == "player" or rec.kind == "party" or rec.kind == "raid") and LEFT_OUT[Opt("roleIconRoles")] or nil
	local unit = out ~= nil and (rec.kind == "player" and "player" or X.unitOf(rec)) or nil
	local role = unit ~= nil and X.role(unit) or nil
	if role == nil or not out[role] then
		return false
	end
	return rec.kind ~= "raid" or not (X.assigned("MAINTANK", unit) or X.assigned("MAINASSIST", unit) or InVehicle(unit))
end

local POWER_ROWS = { player = "playerPowerBar", target = "targetPowerBar", focus = "focusPowerBar", pet = "petPowerBar", tot = "totPowerBar",
	party = "partyPowerBar", boss = "bossPowerBar" }

local function Empty(rec)
	local unit = Opt("hideEmptyPower") ~= false and X.unitOf(rec)
	if not unit then
		return false
	end
	local ok, max = pcall(UnitPowerMax, unit)
	return ok and X.number(max) and max == 0
end

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
	if rec.made and rec.kind == "party" then
		X.run(MARKS, Marks, rec, X.active(rec))
	end
end

local function RolesChanged()
	for _, rec in pairs(X.records) do
		if rec.made then
			local on = X.active(rec)
			if on and (rec.kind == "party" or rec.kind == "raid") and X.colour ~= nil then
				X.run(X.labels[rec.kind], X.colour, rec, true)
			end
			if rec.kind == "party" or rec.kind == "player" then
				X.run(MARKS, Marks, rec, on)
			end
		end
	end
end

ns.AddEvent(KEY, "PLAYER_ROLES_ASSIGNED", RolesChanged)
ns.AddEvent(KEY, "GROUP_ROSTER_UPDATE", RolesChanged)

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) or Opt("threat") ~= true or Opt("threatTanks") ~= "hidden" then
		return {}
	end
	local seen, tanks = {}, 0
	for _, rec in pairs(X.records) do
		local unit = rec.made and (rec.kind == "party" or rec.kind == "raid") and X.unitOf(rec) or nil
		if unit ~= nil and not seen[unit] and X.ask(rec.frame, "IsShown") == true and X.isTank(unit) then
			seen[unit] = true
			tanks = tanks + 1
		end
	end
	return { ("Threat border: not on tanks (%s known)"):format(tanks == 0 and "no tank" or tanks == 1 and "1 tank" or (tanks .. " tanks")) }
end)

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
table.insert(X.after.refresh, { part = MARKS, fn = HitNumbers })
