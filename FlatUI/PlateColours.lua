local _, ns = ...

-- Nameplate health bar colours (Nameplates, Colours and threat) and the mouseover border. The game colours a plate's health bar in
-- CompactUnitFrame_UpdateHealthColor (Shared\CompactUnitFrame.lua:645-700), which it runs on health, threat, name and group events and not on a
-- change of target (Shared\CompactUnitFrame.lua:104-145). This file follows that call and answers in the same call, in this order: the target's
-- colour, a threat colour, a reaction colour. The colour the game set is kept and never compared, and given back when every part is off.
-- A plate's border takes the mouseover colour through ns.PlateBorder, so the target and the focus keep theirs.

local KEY = "nameplates"
local PART, HOVER_PART = "plate colours", "mouseover border"
local HOOK = "CompactUnitFrame_UpdateHealthColor"
-- How often, in seconds, the mouseover is looked at while a plate has the mouseover border.
local EVERY = 0.1

-- recs: per unit frame, the colour the game gave the bar (game) and whether this file has painted over it (painted), and the threat read last
-- (threat: true when read, false when the game withheld or refused it, nil when there is none). hovered: the plate that has the mouseover border.
local recs = setmetatable({}, { __mode = "k" })
local hovered, ticking, missing = nil, false, false

-- True while this file has painted a plate's health bar, so a later colour step skips that plate.
function ns.PlateOverride(frame)
	local rec = recs[frame]
	return rec ~= nil and rec.painted == true
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True for a boolean answer that is not withheld.
local function Is(value, expected)
	return not ns.IsSecret(value) and value == expected
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

-- The health bar the game colours, or nil.
local function Bar(frame)
	local bar = frame.healthBar
	if bar == nil then
		local container = frame.HealthBarsContainer
		bar = container ~= nil and not ns.Forbidden(container) and container.healthBar or nil
	end
	if bar ~= nil and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

-- Whether the rows ask for any colour at all.
local function Asked()
	return Opt("colours") == true or Opt("targetBar") == true or Opt("threat") == true
end

local function TankRole()
	local role = Opt("threatRole")
	if role ~= "auto" then
		return role == "tank"
	end
	return Call(UnitGroupRolesAssigned, "player") == "TANK"
end

-- The colour for the threat the player has on an enemy plate: a tank wants 3, has 2 as changing hands and 0 or 1 as unwanted; any other role
-- wants 0, has 1 and 2 as changing hands and 3 as unwanted. Nothing for a unit the player cannot attack and for an answer that is missing or
-- withheld.
local function ThreatColour(rec, unit)
	if Call(UnitCanAttack, "player", unit) ~= true then
		rec.threat = nil
		return nil
	end
	local ok, situation = pcall(UnitThreatSituation, "player", unit)
	if not ok or ns.IsSecret(situation) or (situation ~= nil and type(situation) ~= "number") then
		rec.threat = false
		return nil
	end
	-- Nil is the game's answer for an enemy the player is not on the threat table of.
	if situation == nil then
		rec.threat = nil
		return nil
	end
	rec.threat = true
	local row
	if TankRole() then
		row = situation >= 3 and "threatGood" or situation == 2 and "threatTransition" or "threatBad"
	else
		row = situation <= 0 and "threatGood" or situation >= 3 and "threatBad" or "threatTransition"
	end
	return ns.Colour(KEY .. "." .. row)
end

-- The colour of the plate's units by reaction. Players keep the game's colour while Players is As the game has it, and when the game withholds
-- whether the unit is a player.
local function ReactionColour(unit)
	if Opt("colourPlayers") ~= "reaction" and Call(UnitIsPlayer, unit) ~= false then
		return nil
	end
	-- The game greys a tapped unit, a dead NPC and a disconnected unit before it asks for the selection colour, so they keep that grey unless
	-- Custom reaction colours gives tapped units their own colour (Shared\CompactUnitFrame.lua:656-658, 675-677).
	if ns.Get("general.reactionOwn") ~= true and Call(UnitIsTapDenied, unit) == true and Call(UnitPlayerControlled, unit) == false then
		return nil
	end
	if Call(UnitIsConnected, unit) == false then
		return nil
	end
	if Call(UnitIsDead, unit) == true and Call(UnitIsPlayer, unit) == false then
		return nil
	end
	return ns.ReactionColour(unit)
end

-- False for a friendly plate while Restyle friendly nameplates is off, as for the rest of the plate's look.
local function Styled(frame)
	return Opt("friendly") == true or not Is(frame.isFriend, true)
end

-- Red, green and blue to paint the plate's health bar, or nil to leave the game's colour.
local function Want(frame, rec)
	if missing or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not ns.IsPlate(frame) or not Styled(frame) then
		return nil
	end
	local unit = frame.unit
	if type(unit) ~= "string" or ns.IsSecret(unit) then
		return nil
	end
	if Opt("targetBar") == true and ns.PlateUnitFrame("target") == frame then
		rec.threat = nil
		return ns.Colour(KEY .. ".targetBarColour")
	end
	if Opt("threat") == true then
		local r, g, b = ThreatColour(rec, unit)
		if r then
			return r, g, b
		end
	else
		rec.threat = nil
	end
	if Opt("colours") == true then
		return ReactionColour(unit)
	end
	return nil
end

-- Paints one plate, or gives the game's colour back. `fromGame`: the game has just run its own call, so the bar holds its colour and there is
-- nothing to give back.
local function Apply(frame, fromGame)
	local rec = recs[frame]
	if rec == nil then
		if not Asked() then
			return
		end
		rec = {}
		recs[frame] = rec
	end
	local r, g, b = Want(frame, rec)
	local bar = Bar(frame)
	if bar == nil then
		return
	end
	if r ~= nil then
		if fromGame or not rec.painted then
			rec.game = { bar:GetStatusBarColor() }
		end
		rec.painted = true
		bar:SetStatusBarColor(r, g, b)
	elseif rec.painted then
		rec.painted = nil
		local game = rec.game
		if game ~= nil and not fromGame then
			bar:SetStatusBarColor(game[1], game[2], game[3], game[4])
		end
	end
end

-- True while this file paints the plate in a colour of its own (the target's, a threat colour or a reaction colour), which wins over Colour health bars by
-- health left.
function ns.PlateOverride(frame)
	if not Asked() then
		return false
	end
	return Want(frame, recs[frame] or {}) ~= nil
end

-- The same inside the part that stops after repeated failures, whose colours then go back.
local function Run(frame, fromGame)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, PART) then
		pcall(Apply, frame, fromGame)
	elseif not ns.EachPart(KEY, PART, Apply, frame, fromGame) and ns.PartStopped(KEY, PART) then
		ns.EachPlate(Apply, false)
	end
end

local function OnColour(frame)
	if ns.IsPlate(frame) then
		Run(frame, true)
	end
end

-- Follows the game's call, once. A game without it leaves the colours off, with a line for /flatui status.
local function Install()
	if missing or not Asked() then
		return
	end
	if not ns.FollowGlobal(HOOK, OnColour) then
		missing = true
		ns.Note(KEY, "Plate colours: the game's health colour call was not found, so nameplate health bars keep the game's colours.")
	end
end

local function Reapply()
	Install()
	ns.EachPlate(Run, false)
end

-- The mouseover border -------------------------------------------------------------------------------------

local function Unhover()
	local frame = hovered
	hovered = nil
	if frame ~= nil then
		ns.PlateBorder(frame, nil)
	end
end

local Watch

local function Tick()
	ticking = false
	if hovered ~= nil then
		if ns.PlateUnitFrame("mouseover") ~= hovered then
			Unhover()
		else
			Watch()
		end
	end
end

-- Looks at the mouseover on every 0.1 s for as long as a plate has the border, since the game says nothing when the mouse leaves a plate.
function Watch()
	if ticking or hovered == nil or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	ticking = true
	C_Timer.After(EVERY, function()
		pcall(Tick)
	end)
end

local function OnMouseover()
	local frame = nil
	if Opt("hover") == true and ns.Enabled(KEY) and not ns.PartStopped(KEY, HOVER_PART) then
		frame = ns.PlateUnitFrame("mouseover")
	end
	if frame ~= hovered then
		Unhover()
		if frame ~= nil and ns.PlateBorder(frame, ns.Colour(KEY .. ".hoverColour")) then
			hovered = frame
		end
	end
	Watch()
end

local function Mouseover()
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, HOVER_PART) then
		pcall(Unhover)
	elseif not ns.EachPart(KEY, HOVER_PART, OnMouseover) and ns.PartStopped(KEY, HOVER_PART) then
		pcall(Unhover)
	end
end

-- Hooks into the plates ------------------------------------------------------------------------------------

local extra = ns.PlateExtra
extra.show[#extra.show + 1] = function(frame)
	Install()
	Run(frame, false)
end
extra.leave[#extra.leave + 1] = function(frame)
	-- The game takes the plate back and colours it again for the next unit, so what was kept of the old one is dropped.
	recs[frame] = nil
	if frame == hovered then
		pcall(Unhover)
	end
end
extra.refresh[#extra.refresh + 1] = function()
	Reapply()
	-- The border is given again, since its colour may be the row that changed.
	pcall(Unhover)
	Mouseover()
end
extra.status[#extra.status + 1] = function()
	if not ns.Enabled(KEY) or Opt("threat") ~= true or ns.PartStopped(KEY, PART) then
		return nil
	end
	local read, withheld = 0, 0
	ns.EachPlate(function(frame)
		local rec = recs[frame]
		if rec ~= nil and rec.threat == true then
			read = read + 1
		elseif rec ~= nil and rec.threat == false then
			withheld = withheld + 1
		end
	end)
	return ("Nameplate threat: plates read %d, without an answer %d."):format(read, withheld)
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if Opt("targetBar") == true then
		ns.EachPlate(Run, false)
	end
end)
ns.AddEvent(KEY, "PLAYER_ROLES_ASSIGNED", function()
	if Opt("threat") == true then
		ns.EachPlate(Run, false)
	end
end)
ns.AddEvent(KEY, "UPDATE_MOUSEOVER_UNIT", Mouseover)
