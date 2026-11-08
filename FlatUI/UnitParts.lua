local ADDON_NAME, ns = ...

-- The icons and the power bars of the unit frames that each have a switch: the leader, role, PvP and raid marker icons, the dead text, the combat icon and
-- the pet's happiness face, the hit numbers of the player and the pet, and the power bar of each frame. Each is a region or a bar the game shows, hides and
-- draws again and never fades, so off is a change of its opacity to 0, and on gives it the opacity it had before. Nothing is called for a region that is not
-- switched off and was not made transparent here. This file adds its work after the steps of UnitFrames.lua through ns.UnitFrameExtra: a part that stops on
-- errors counts as off here, and every function can run twice with the same result. The PvP icon is the one switch that goes through the PvP flag of
-- UnitFrames.lua (pvpMode), which sets the opacity of the game's plate and icon itself. A power bar also goes when its unit has no power (Hide empty power bar).
-- The hit numbers are the damage and heal numbers the game flashes over the player and pet portraits (CombatFeedback_OnCombatEvent, Mainline/
-- CombatFeedback.lua:26-95, called for UNIT_COMBAT by PlayerFrame_OnEvent and PetFrameMixin:OnEvent, Mainline/PlayerFrame.lua:121-124 and PetFrame.lua:111-114).
-- The game sets the opacity of the number itself while it fades (CombatFeedback_OnUpdate, :97-119), so the player's goes with the frame that holds it
-- alone, HitIndicator (Mainline/PlayerFrame.xml:106-116), whose opacity the game never sets. The pet's PetHitIndicator shares its frame with the pet's
-- name (Mainline/PetFrame.xml:63-81), so it is hidden again after each call that shows it (ns.FollowGlobal, as the new item glow of a bag slot is in
-- Items.lua), from the first pass of the module with the numbers off; once they are on, the game shows the next one as before. The hit numbers go with
-- the module's switch, not with the switch of their frame: the game flashes them over its own player and pet frames as well, so they are set after each
-- pass of the module over its frames (after.refresh), whether Flat UI styles those frames or not. This follows EnhanceQoL by Philipp Barth (R41Z0R),
-- adapted with his permission (EnhanceQoLUnitFrames/UnitFrameRuntime.lua:95-103), whose options act on the game's frames: opacity and visibility in place
-- of its Hide of the player's frame and its hook on the Show method of the pet's number.
-- Role icons for leaves the game's role icon of a member at its opacity only for the roles chosen, on the player, party and raid frames (UnitExtras.lua),
-- with the same change of opacity as the switch of the icon. The role is the game's plain answer of UnitGroupRolesAssigned, which is withheld for a unit
-- outside the group (SecretWhenUnitIdentityRestricted, UnitDocumentation.lua:1318-1332): a withheld answer, NONE and no answer keep the icon. The game
-- draws the icon of the player and of a party member from the same role (Mainline/PlayerFrame.lua:428-450, Mainline/PartyMemberFrame.lua:555-571), and on a
-- raid frame it shows a vehicle, a Main Tank or a Main Assist before the role (Shared/UnitFrameUtil.lua:237-276): a raid member in a vehicle or with one of
-- those assignments keeps the icon. The assignment is GetPartyAssignment, asked as the game's group headers ask it (Blizzard_RestrictedAddOnEnvironment/
-- SecureGroupHeaders.lua:306-308); a withheld answer counts as none. The same answers say who is a tank for Threat border on tanks (UnitFrames.lua): a
-- member with the tank role or the Main Tank of a raid. This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoLUnitFrames/UF_GroupFrames.lua:2583-2620, 8773-8831, 8915-8927): its role of a unit, its filter of the roles shown and its raid assignment,
-- on the game's icons. Its three icon styles are left out, as Flat UI keeps the game's art.

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

-- Per row: the regions it switches, given to emit. The party frame's PvP icon is the PvP flag's own. left: true when the region is to go with its row on.
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

-- The pet's hit number: hidden after the call that showed it, while the module is on and the numbers are off, whatever the switch of the pet frame.
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
	-- A number that shows as the numbers go off goes at once.
	HidePetNumber(rec)
end

-- After each pass of the module over its frames: the frame of the player's hit number, which holds nothing else, and the pet's number, on the frames
-- the module knows whether it styles them or not.
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

-- Roles ------------------------------------------------------------------------------------------------------

-- The role the group gave a unit, as the game says it plainly: TANK, HEALER or DAMAGER, or nil for NONE, a withheld answer and a client without the call.
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

-- True when the raid gave a unit the assignment, MAINTANK or MAINASSIST: a plain answer that the game's own test (if GetPartyAssignment(...) then)
-- takes as true. The client has the call (apis.yaml) and no documentation of it; a withheld answer counts as none.
function X.assigned(assignment, unit)
	if unit == nil or type(GetPartyAssignment) ~= "function" then
		return false
	end
	local ok, yes = pcall(GetPartyAssignment, assignment, unit)
	return ok and not ns.IsSecret(yes) and yes ~= nil and yes ~= false
end

-- True for a tank of the group: a unit with the tank role, or the Main Tank of a raid. Groups on Forever often have no roles, so the raid's mark is the second
-- source; a unit whose role is withheld or unknown is no tank.
function X.isTank(unit)
	return unit ~= nil and (X.role(unit) == "TANK" or X.assigned("MAINTANK", unit))
end

-- The roles each choice of Role icons for leaves out.
local LEFT_OUT = { support = { DAMAGER = true }, healer = { TANK = true, DAMAGER = true } }

-- True while a unit is in a vehicle with a bar of its own, when the game's raid frame shows the vehicle in place of the role (UnitFrameUtil.lua:259-260).
local function InVehicle(unit)
	if type(UnitInVehicle) ~= "function" or type(UnitHasVehicleUI) ~= "function" then
		return false
	end
	local ok, inside = pcall(UnitInVehicle, unit)
	local fine, bar = pcall(UnitHasVehicleUI, unit)
	return ok and fine and not ns.IsSecret(inside) and not ns.IsSecret(bar) and inside == true and bar == true
end

-- True when the game's role icon of a frame shows a role that Role icons for leaves out. The player's own icon is of the player, as the game draws it
-- (PlayerFrame.lua:435). UnitExtras.lua asks this for the role icon of a raid frame.
function X.roleLeftOut(rec)
	local out = (rec.kind == "player" or rec.kind == "party" or rec.kind == "raid") and LEFT_OUT[Opt("roleIconRoles")] or nil
	local unit = out ~= nil and (rec.kind == "player" and "player" or X.unitOf(rec)) or nil
	local role = unit ~= nil and X.role(unit) or nil
	if role == nil or not out[role] then
		return false
	end
	return rec.kind ~= "raid" or not (X.assigned("MAINTANK", unit) or X.assigned("MAINASSIST", unit) or InVehicle(unit))
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
	-- A new member on a party frame: its role icon follows the member's role.
	if rec.made and rec.kind == "party" then
		X.run(MARKS, Marks, rec, X.active(rec))
	end
end

-- A role, a raid assignment or the group changed: the threat border of the party and raid frames (Threat border on tanks) and the role icons of the player
-- and party frames are drawn again. The game draws the role icon of a raid frame again on both events itself (Shared/CompactUnitFrame.lua:73-74, 89-90), and
-- UnitExtras.lua follows that call; it draws the player's on PLAYER_ROLES_ASSIGNED (Mainline/PlayerFrame.lua:197-198) and a party member's on
-- GROUP_ROSTER_UPDATE (Mainline/PartyMemberFrame.lua:650-653), with no call for a party member's on PLAYER_ROLES_ASSIGNED.
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

-- The line of /flatui status while Threat border on tanks is Not shown: the tanks the party and raid frames on screen know.
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
