local _, ns = ...

-- The threat core of the nameplates, a part of Nameplates.lua (ns.PlateExtra): the threat level of each enemy plate, read from the game, kept for
-- the parts that show it (the health bar colour of PlateColours.lua and the other threat parts of the plates) and handed to them through
-- ns.PlateThreat. It does what Threat Plates does on Forever (its ShowFeedback, UpdateThreatStatus and GetPlayerRole: Modules/Threat.lua:111-177,
-- Nameplate.lua:2354-2475), with none of its code, and adds what Forever lets an addon know without a compound unit token.
-- The level is the player's threat situation on the plate's unit, UnitThreatSituation("player", unit) (UnitDocumentation.lua:3279-3294): 0 is low,
-- 1 and 2 are medium and 3 is high, as Threat Plates reads it (Constants.lua:168-173). A query of the player, the pet or an ally against a nameplate is
-- generally not secret (SecretWhenUnitThreatStateRestricted, SecretPredicatesDocumentation.lua:160-163); a withheld answer, a raise or an answer that
-- is no number is no answer and gives no level, and nil says the player is not on the unit's threat table. A tank wants high and a damage dealer or
-- healer low; medium is threat changing hands. A tank whose enemy another tank of the group or the pet holds (a plain 2 or 3 of that unit's own
-- UnitThreatSituation on the plate) has it as held by another tank, where Threat Plates looks at the enemy's target, which Forever withholds
-- (Modules/Threat.lua:131-166, 298-303). An enemy only the pet is on the threat table of is held for the player. With Early warning while tanking, a
-- tank who holds an enemy securely has it as changing hands while UnitThreatLeadSituation (UnitDocumentation.lua:3244-3260) gives yellow or orange,
-- as the game's own plates warn a tank (Shared/CompactUnitFrame.lua:599-623).
-- No player has threat on a plate, nor a unit the player cannot attack; the kind of enemy (tapped, neutral, boss, elite, normal, minor, in Threat
-- Plates' order: Modules/Threat.lua:95-103, Nameplate.lua:497-511 and 557-576) and Only in dungeons and raids decide which others do. The kind is
-- read once for a plate and its unit, and again on UNIT_CLASSIFICATION_CHANGED.
-- The game updates a plate's threat in CompactUnitFrame_UpdateAggroHighlight (Shared/CompactUnitFrame.lua:920-932), which it calls for the plate's own
-- unit on UNIT_THREAT_SITUATION_UPDATE and UNIT_THREAT_LIST_UPDATE (131-143), on GROUP_JOINED and GROUP_LEFT (101-104) and in UpdateAll (454, 474).
-- That call is followed (hooksecurefunc, through ns.FollowGlobal) from the first plate shown with threat on, and every plate is read again when the
-- role changes, the group changes, a fight starts and the rows change; at the end of a fight every plate loses its level, as Threat Plates has it
-- (Modules/Threat.lua:247-253). The other parts hear a change of a plate's level (PT.OnChange), and every update (PT.OnUpdate).
-- The role is worked out on events and not for each plate: the role the group gave, the raid's Main Tank, the game's tank aura, then a warrior's
-- Defensive Stance, a druid's bear form and a paladin's Righteous Fury, as Threat Plates' Classic path has them. Nothing of the game is changed: every
-- call only reads, and a frame of the file's own hears UPDATE_SHAPESHIFT_FORM for a warrior or a druid while the role is automatic.

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local PART = "nameplate threat"
local AGGRO, HEALTH = "CompactUnitFrame_UpdateAggroHighlight", "CompactUnitFrame_UpdateHealthColor"
-- The row of each kind of enemy, and the row of the colour of each want.
local KIND_ROWS = { tapped = "threatTapped", neutral = "threatNeutral", boss = "threatBoss", elite = "threatElite", normal = "threatNormal", minor = "threatMinor" }
local COLOUR_ROWS = { good = "threatGood", changing = "threatTransition", bad = "threatBad", offtank = "threatTankColour" }
-- The classifications of the game counted as elite (Threat Plates puts rares with them, Modules/Threat.lua:32-41) and as minor.
local ELITE = { worldboss = true, rareelite = true, elite = true, rare = true }
local MINOR = { minus = true, trivial = true }
-- The kinds of instance Only in dungeons and raids counts (Threat Plates' PvE instance types, Nameplate.lua:1472-1479).
local INSTANCES = { party = true, raid = true, scenario = true }
-- What a tank and what any other role wants of each level.
local WANT = {
	[true] = { high = "good", medium = "changing", low = "bad", offtank = "offtank" },
	[false] = { low = "good", medium = "changing", high = "bad", offtank = "offtank" },
}
-- Righteous Fury, whose ranks Threat Plates looks for (Nameplate.lua:2421-2427; 407627 is Season of Discovery's).
local FURY = { 25780, 20468, 20469, 20470, 407627 }
-- A warrior's Defensive Stance and a druid's bear forms by GetShapeshiftFormID: Threat Plates' 18 (Nameplate.lua:2367-2369), and 5 or 8, where
-- Forever's own DRUID_BEAR_FORM is 8 (Blizzard_FrameXMLBase/Camelot/Constants.lua:14, loaded for that game only, Blizzard_FrameXMLBase.toc:15-16).
local DEFENSIVE, BEAR, DIRE_BEAR = 18, 5, 8
local HELP = { "/flatui role [tank|damage|auto|toggle] - the role nameplate threat reads you as, or set it" }
local MISSING = "Nameplate threat: the game's threat update was not found, so the glow, the fade and the threat value follow the health colour."

local PT = {}
ns.PlateThreat = PT

-- recs: per unit frame, state (the level kept, or nil), answer (true for a plain answer of the game, false for a refused or withheld one, nil for none)
-- and kind with kindUnit (the kind of the unit the plate had when it was read). telling: plates whose listeners are told now. changeFns and updateFns:
-- the listeners. followed: true while the game's threat update is followed, false when the client has none, nil before the first plate. inColour:
-- above 0 while the follow of the health colour call reads, where that call stands in for the threat update. seen: a plate has had an answer.
local recs = setmetatable({}, { __mode = "k" })
local telling = setmetatable({}, { __mode = "k" })
local changeFns, updateFns = {}, {}
local followed, inColour, seen = nil, 0, false
-- role: tank, its reason and the Your role it was worked out for. class: the player's class once read, false when the game did not say. fury: the
-- Righteous Fury flag. group: the units of the group other than the player whose threat says another tank holds an enemy: tanks by role or by the
-- Main Tank mark, and the other members of a party, who count when the game gives them its tank aura.
local role = { tank = false }
local class, fury = nil, false
local group = { tanks = {}, others = {} }
local listener, hearing = nil, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
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

-- A count the game gives, as a whole number from 0 to most.
local function Count(fn, most)
	local value = Call(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

-- True when the raid gave a unit the assignment: a plain answer the game's own test (if GetPartyAssignment(...) then) takes as true, as
-- UnitParts.lua has it. The client has the call (apis.yaml) and no documentation of it.
local function Assigned(assignment, unit)
	if type(GetPartyAssignment) ~= "function" then
		return false
	end
	local ok, yes = pcall(GetPartyAssignment, assignment, unit)
	return ok and not ns.IsSecret(yes) and yes ~= nil and yes ~= false
end

-- False for a friendly plate while Restyle friendly nameplates is off, which stays as the game draws it, as for the rest of its look (PlateColours.lua).
local function Styled(unitFrame)
	if Opt("friendly") == true then
		return true
	end
	local friend = unitFrame.isFriend
	return ns.IsSecret(friend) or friend ~= true
end

-- The answer of UnitThreatSituation or UnitThreatLeadSituation: a whole number from 0 to 3 and true for a plain one, nil and false when the call raises
-- or the answer is withheld or no number, and nil and nil for nil or a client without the call.
local function Threat(fn, who, unit)
	if type(fn) ~= "function" then
		return nil, nil
	end
	local ok, value = pcall(fn, who, unit)
	if not ok or ns.IsSecret(value) then
		return nil, false
	end
	if value == nil then
		return nil, nil
	end
	if not ns.Finite(value) then
		return nil, false
	end
	return math.max(0, math.min(3, math.floor(value))), true
end

-- True for a situation of 2 or 3: that unit tanks the enemy.
local function Holds(value)
	return value == 2 or value == 3
end

local function PetOut()
	return Call(UnitExists, "pet") == true
end

-- True in a dungeon, a raid or a scenario: IsInInstance (InstanceDocumentation.lua:170-178) plainly says so.
local function InInstance()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not ns.IsSecret(inside) and inside == true and not ns.IsSecret(kind) and type(kind) == "string" and INSTANCES[kind] == true
end

-- The kind of the plate's unit. Tapped by someone else as the game greys it (CompactUnitFrame_IsTapDenied, Shared/CompactUnitFrame.lua:560-562) and
-- neutral (UnitReaction 4, unless the unit is player-controlled, which Threat Plates counts as hostile, Nameplate.lua:505-508) are asked each time; a
-- boss (the skull level, UnitEffectiveLevel -1, as Threat Plates takes it, Nameplate.lua:562-564, or a boss mob, as ns.UnitKind has it), an elite and a
-- minor unit once for the plate and its unit. A classification that is missing, withheld or another word counts as normal.
local function Kind(rec, unit)
	if Call(UnitIsTapDenied, unit) == true and Call(UnitPlayerControlled, unit) ~= true then
		return "tapped"
	end
	if Call(UnitReaction, unit, "player") == 4 and Call(UnitPlayerControlled, unit) ~= true then
		return "neutral"
	end
	if rec.kind == nil or rec.kindUnit ~= unit then
		local level, classification = Call(UnitEffectiveLevel, unit), Call(UnitClassification, unit)
		if level == -1 or Call(UnitIsBossMob, unit) == true then
			rec.kind = "boss"
		elseif type(classification) == "string" and ELITE[classification] then
			rec.kind = "elite"
		elseif type(classification) == "string" and MINOR[classification] then
			rec.kind = "minor"
		else
			rec.kind = "normal"
		end
		rec.kindUnit = unit
	end
	return rec.kind
end

-- Role ------------------------------------------------------------------------------------------------------------------------------------------

-- The player's class, read once: UnitClassBase (UnitDocumentation.lua:930-945), plain for the player.
local function Class()
	if class == nil then
		local value = Call(UnitClassBase, "player")
		class = type(value) == "string" and value or false
	end
	return class
end

-- The form the player is in. GetShapeshiftFormID is in the client with no documentation (apis.yaml), so its answer must be a plain number.
local function Form()
	if type(GetShapeshiftFormID) ~= "function" then
		return nil
	end
	local ok, form = pcall(GetShapeshiftFormID)
	if ok and ns.Finite(form) then
		return form
	end
	return nil
end

local function InBearForm()
	local form = Form()
	if form == nil then
		return false
	end
	local own = DRUID_BEAR_FORM
	return form == BEAR or form == DIRE_BEAR or (ns.Finite(own) and form == own)
end

-- The Righteous Fury flag of a paladin. GetPlayerAuraBySpellID answers nothing for an aura the game withholds and raises nothing
-- (RequiresNonSecretAura, UnitAuraDocumentation.lua:397-411; SecretPredicatesDocumentation.lua:28-31), so a plain aura found sets the flag and none
-- found clears it only out of combat, where no aura is withheld, as Threat Plates does (Nameplate.lua:2434-2445).
local function ReadFury()
	if Class() ~= "PALADIN" then
		fury = false
		return
	end
	local auras = C_UnitAuras
	local get = type(auras) == "table" and not ns.IsSecret(auras) and auras.GetPlayerAuraBySpellID or nil
	if type(get) ~= "function" then
		return
	end
	for _, id in ipairs(FURY) do
		local ok, aura = pcall(get, id)
		if ok and not ns.IsSecret(aura) and type(aura) == "table" then
			fury = true
			return
		end
	end
	local ok, combat = pcall(InCombatLockdown)
	if ok and not ns.IsSecret(combat) and combat == false then
		fury = false
	end
end

-- Works out whether threat reads the player as a tank, and why. Your role decides when it is Tank or Damage or healer. From your role, stance or form
-- takes the role the group gave (UnitGroupRolesAssigned, UnitDocumentation.lua:1318-1332), else the raid's Main Tank, else the game's tank aura
-- (UnitHasEffectivelyTankAura, UnitDocumentation.lua:1365-1379, which the game's PlayerUtil.IsPlayerEffectivelyTank asks first,
-- Blizzard_SharedXML/UnitUtil.lua:109-121; that is a table of the game, so the client's own function is called, as Setup.lua does), else Defensive
-- Stance, a bear form or Righteous Fury by class. Threat Plates reads the aura and the class alone (Nameplate.lua:2397-2418). True when the role changed.
local function WorkOut()
	local choice = Opt("threatRole")
	local tank, reason
	if choice == "tank" or choice == "damage" then
		tank, reason = choice == "tank", "your choice"
	else
		local given = Call(UnitGroupRolesAssigned, "player")
		if given == "TANK" then
			tank, reason = true, "your group role"
		elseif given == "HEALER" or given == "DAMAGER" then
			tank, reason = false, "your group role"
		elseif Assigned("MAINTANK", "player") then
			tank, reason = true, "Main Tank"
		elseif Call(UnitHasEffectivelyTankAura, "player") == true then
			tank, reason = true, "a tank aura"
		else
			local kind = Class()
			if kind == "WARRIOR" and Form() == DEFENSIVE then
				tank, reason = true, "Defensive Stance"
			elseif kind == "DRUID" and InBearForm() then
				tank, reason = true, "Bear Form"
			elseif kind == "PALADIN" and fury then
				tank, reason = true, "Righteous Fury"
			else
				tank, reason = false, "no tank stance or form"
			end
		end
	end
	local changed = role.reason ~= nil and role.tank ~= tank
	role.tank, role.reason, role.choice = tank, reason, choice
	return changed
end

local function IsTank()
	if role.reason == nil then
		WorkOut()
	end
	return role.tank
end

-- The units whose own threat says another tank holds an enemy, made again when the group or its roles change. A tank is a unit with the tank role or
-- the raid's Main Tank, as ns.UnitFrameExtra.isTank has it (UnitParts.lua:234-259). In a raid raid1 to raid40 without the player (UnitIsUnit with the
-- player is comparable, SecretPredicatesDocumentation.lua:10-14); in a party party1 to party4, whose other members count when the game gives them its
-- tank aura, since groups on Forever often have no roles (plain for party members, SecretPredicatesDocumentation.lua:130-133).
local function Roster()
	local tanks, others = {}, {}
	if PT.Active() and Opt("threatTanks") == true then
		local function IsTankUnit(unit)
			return Call(UnitGroupRolesAssigned, unit) == "TANK" or Assigned("MAINTANK", unit)
		end
		if Call(IsInRaid) == true then
			for index = 1, Count(GetNumGroupMembers, 40) do
				local unit = "raid" .. index
				if Call(UnitIsUnit, unit, "player") ~= true and IsTankUnit(unit) then
					tanks[#tanks + 1] = unit
				end
			end
		elseif Call(IsInGroup) == true then
			for index = 1, Count(GetNumSubgroupMembers, 4) do
				local unit = "party" .. index
				if IsTankUnit(unit) then
					tanks[#tanks + 1] = unit
				else
					others[#others + 1] = unit
				end
			end
		end
	end
	group.tanks, group.others = tanks, others
end

-- True when the pet or another tank of the group tanks the enemy. The tank aura of a party member is asked only for one who tanks it.
local function HeldByOther(unit)
	if PetOut() and Holds((Threat(UnitThreatSituation, "pet", unit))) then
		return true
	end
	for _, member in ipairs(group.tanks) do
		if Holds((Threat(UnitThreatSituation, member, unit))) then
			return true
		end
	end
	for _, member in ipairs(group.others) do
		if Holds((Threat(UnitThreatSituation, member, unit))) and Call(UnitHasEffectivelyTankAura, member) == true then
			return true
		end
	end
	return false
end

-- Reading a plate ---------------------------------------------------------------------------------------------------------------------------------

function PT.Active()
	return ns.Enabled(KEY) and Opt("threat") == true and not ns.PartStopped(KEY, PART)
end

-- The state of a plate and the kind of answer the game gave, or nil.
local function Ask(unitFrame, rec)
	local unit = unitFrame.unit
	if ns.IsSecret(unit) or type(unit) ~= "string" or not Styled(unitFrame) then
		return nil, nil
	end
	-- Threat Plates gives no player threat feedback (Modules/Threat.lua:111-114).
	if Call(UnitCanAttack, "player", unit) ~= true or Call(UnitIsPlayer, unit) == true then
		return nil, nil
	end
	if Opt("threatInstances") == true and not InInstance() then
		return nil, nil
	end
	local status, answer = Threat(UnitThreatSituation, "player", unit)
	local pet = false
	if status == nil then
		-- Threat Plates never asks for the pet (Modules/Threat.lua:171): an enemy only the pet is on the table of is held for the player.
		if answer == false or Opt("threatPet") ~= true or not PetOut() or not Holds((Threat(UnitThreatSituation, "pet", unit))) then
			return nil, answer
		end
		pet, answer = true, true
	end
	local kind = Kind(rec, unit)
	if Opt(KIND_ROWS[kind]) ~= true then
		return nil, answer
	end
	local tank = IsTank()
	local level
	if pet then
		level = (tank and Opt("threatTanks") == true) and "offtank" or "low"
	elseif status >= 3 then
		level = "high"
		if tank and Opt("threatLead") == true then
			local lead = Threat(UnitThreatLeadSituation, "player", unit)
			if lead == 1 or lead == 2 then
				level = "medium"
			end
		end
	else
		level = status >= 1 and "medium" or "low"
		if tank and status <= 1 and Opt("threatTanks") == true and HeldByOther(unit) then
			level = "offtank"
		end
	end
	return { want = WANT[tank][level], level = level, tank = tank, tapped = kind == "tapped", pet = pet, kind = kind }, answer
end

local function Same(a, b)
	if a == nil or b == nil then
		return a == b
	end
	return a.want == b.want and a.level == b.level and a.tank == b.tank and a.tapped == b.tapped and a.pet == b.pet and a.kind == b.kind
end

local function Failed(err)
	ns.Note(KEY, "Nameplate threat: a part that follows threat failed. " .. tostring(err))
end

-- Tells the parts that a plate's state changed. While they are told, a Read of that plate answers the state just kept and asks nothing.
local function Tell(unitFrame, state, previous)
	telling[unitFrame] = (telling[unitFrame] or 0) + 1
	for _, fn in ipairs(changeFns) do
		local ok, err = pcall(fn, unitFrame, state, previous)
		if not ok then
			Failed(err)
		end
	end
	local depth = telling[unitFrame] - 1
	telling[unitFrame] = depth > 0 and depth or nil
end

local function Update(unitFrame)
	local rec = recs[unitFrame]
	local state = rec and rec.state or nil
	for _, fn in ipairs(updateFns) do
		local ok, err = pcall(fn, unitFrame, state)
		if not ok then
			Failed(err)
		end
	end
end

local function Keep(unitFrame, rec, state)
	local previous = rec.state
	if Same(previous, state) then
		return
	end
	rec.state = state
	Tell(unitFrame, state, previous)
end

local function Drop(unitFrame, rec)
	rec.answer = nil
	Keep(unitFrame, rec, nil)
end

-- Every kept state goes. The plates are listed first, since a listener may read another plate.
local function DropAll()
	local list = {}
	for unitFrame in pairs(recs) do
		list[#list + 1] = unitFrame
	end
	for _, unitFrame in ipairs(list) do
		local rec = recs[unitFrame]
		if rec ~= nil then
			Drop(unitFrame, rec)
		end
	end
end

local function Work(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		rec = {}
		recs[unitFrame] = rec
	end
	local state, answer = Ask(unitFrame, rec)
	rec.answer = answer
	if answer ~= nil then
		seen = true
	end
	Keep(unitFrame, rec, state)
end

-- Asks the game now, keeps the answer and returns the plate's state, or nil when it shows no threat.
function PT.Read(unitFrame)
	if unitFrame == nil or ns.IsSecret(unitFrame) then
		return nil
	end
	local rec = recs[unitFrame]
	if not PT.Active() or not ns.IsPlate(unitFrame) or ns.Forbidden(unitFrame) then
		if rec ~= nil then
			Drop(unitFrame, rec)
		end
		return nil
	end
	if telling[unitFrame] then
		return rec and rec.state or nil
	end
	if not ns.EachPart(KEY, PART, Work, unitFrame) then
		if ns.PartStopped(KEY, PART) then
			DropAll()
		else
			rec = recs[unitFrame]
			if rec ~= nil then
				Drop(unitFrame, rec)
			end
		end
		return nil
	end
	rec = recs[unitFrame]
	return rec and rec.state or nil
end

-- The state kept from the last Read, without a call to the game.
function PT.Get(unitFrame)
	if unitFrame == nil or ns.IsSecret(unitFrame) then
		return nil
	end
	local rec = recs[unitFrame]
	return rec and rec.state or nil
end

local function Listen(list, fn)
	if type(fn) ~= "function" then
		return false
	end
	for _, known in ipairs(list) do
		if known == fn then
			return true
		end
	end
	list[#list + 1] = fn
	return true
end

-- fn(unitFrame, state, previous) after a plate's state changed, came or went; nil says to put back what is shown on that plate.
function PT.OnChange(fn)
	return Listen(changeFns, fn)
end

-- fn(unitFrame, state) after every threat update of a plate, changed or not, and after each pass over the plates.
function PT.OnUpdate(fn)
	return Listen(updateFns, fn)
end

-- Red, green and blue of the colour row of a state's want.
function PT.Colour(state)
	local row = type(state) == "table" and COLOUR_ROWS[state.want] or nil
	if row == nil then
		return nil
	end
	return ns.Colour(KEY .. "." .. row)
end

-- "tank" or "damage", and why, as a short phrase.
function PT.Role()
	if role.reason == nil then
		WorkOut()
	end
	return role.tank and "tank" or "damage", role.reason
end

-- True once a plate has had an answer of the game this session: threat is in use.
function PT.Seen()
	return seen
end

-- True while the follow of the health colour call reads a plate, in a client without the threat update: the game's colour call is under way.
function PT.InColourCall()
	return inColour > 0
end

-- When it is read --------------------------------------------------------------------------------------------------------------------------------

local function Pass(unitFrame)
	PT.Read(unitFrame)
	Update(unitFrame)
end

local function PassAll()
	ns.EachPlate(Pass)
end

-- Every compact unit frame comes through the follows, the raid frames too.
local function OnAggro(frame)
	if not ns.IsPlate(frame) or not PT.Active() then
		return
	end
	Pass(frame)
end

-- In a client without the threat update the health colour call stands in, which the game also runs on threat events (Shared/CompactUnitFrame.lua:131-140).
local function OnHealthColour(frame)
	if not ns.IsPlate(frame) or not PT.Active() then
		return
	end
	inColour = inColour + 1
	pcall(PT.Read, frame)
	inColour = inColour - 1
	Update(frame)
end

-- Follows the game's threat update the first time a plate shows with threat on. The follow stays: it does nothing while threat is off.
local function Install()
	if followed ~= nil or not PT.Active() then
		return
	end
	if ns.FollowGlobal(AGGRO, OnAggro) == true then
		followed = true
	else
		followed = false
		ns.FollowGlobal(HEALTH, OnHealthColour)
	end
end

-- UPDATE_SHAPESHIFT_FORM (no module hears it) on a frame of the file's own, only for a warrior or a druid while the role is automatic. The game may
-- fire it with no change of form, so only a role that changed reads the plates again.
local function OnForm()
	if PT.Active() and WorkOut() then
		PassAll()
	end
end

local function Hear(on)
	if on == hearing then
		return
	end
	if on and listener == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or ns.IsSecret(frame) or type(frame) ~= "table" then
			return
		end
		ns.Own[frame] = true
		if not pcall(frame.SetScript, frame, "OnEvent", function()
			ns.Try(KEY, OnForm)
		end) then
			return
		end
		listener = frame
	end
	if listener == nil then
		return
	end
	if on then
		hearing = pcall(listener.RegisterEvent, listener, "UPDATE_SHAPESHIFT_FORM") == true
	else
		pcall(listener.UnregisterEvent, listener, "UPDATE_SHAPESHIFT_FORM")
		hearing = false
	end
end

local function Automatic()
	return Opt("threatRole") == "auto"
end

local function GroupChanged()
	if PT.Active() then
		Roster()
		WorkOut()
		PassAll()
	end
end

-- Hooks into the plates ------------------------------------------------------------------------------------------------------------------------------

EXTRA.show[#EXTRA.show + 1] = function(unitFrame)
	-- A plate that gets a unit has its kind read again.
	local rec = recs[unitFrame]
	if rec ~= nil then
		rec.kind, rec.kindUnit = nil, nil
	end
	if not PT.Active() then
		return
	end
	Install()
	if role.choice ~= Opt("threatRole") then
		WorkOut()
	end
	PT.Read(unitFrame)
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if rec ~= nil then
		Drop(unitFrame, rec)
		recs[unitFrame] = nil
	end
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	Roster()
	if not PT.Active() then
		Hear(false)
		DropAll()
		return
	end
	if Automatic() then
		ReadFury()
	end
	WorkOut()
	Hear(Automatic() and (Class() == "WARRIOR" or Class() == "DRUID"))
	PassAll()
end

-- The lines of /flatui status, once a plate has had an answer: the plates with a plain answer now and those with a refused or withheld one, the role
-- and why, and the follow that stands in when the client has no threat update.
local function Said()
	return seen and PT.Active()
end
EXTRA.status[#EXTRA.status + 1] = function()
	if not Said() then
		return nil
	end
	local read, withheld = 0, 0
	ns.EachPlate(function(unitFrame)
		local rec = recs[unitFrame]
		if rec ~= nil and rec.answer == true then
			read = read + 1
		elseif rec ~= nil and rec.answer == false then
			withheld = withheld + 1
		end
	end)
	return ("Nameplate threat: plates read %d, without an answer %d."):format(read, withheld)
end
EXTRA.status[#EXTRA.status + 1] = function()
	if not Said() then
		return nil
	end
	local now, reason = PT.Role()
	return ("Nameplate threat: you count as %s (%s)."):format(now == "tank" and "a tank" or "damage or healer", reason)
end
EXTRA.status[#EXTRA.status + 1] = function()
	if not Said() or followed ~= false then
		return nil
	end
	return MISSING
end

local function PlayerUnit(unit)
	return not ns.IsSecret(unit) and unit == "player"
end

local function PlateUnit(unit)
	return ns.IsSecret(unit) or (type(unit) == "string" and unit:find("^nameplate") ~= nil)
end

ns.AddEvent(KEY, "PLAYER_ROLES_ASSIGNED", GroupChanged)
ns.AddEvent(KEY, "GROUP_ROSTER_UPDATE", GroupChanged)
ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	if PT.Active() then
		WorkOut()
		PassAll()
	end
end)
ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", function()
	if PT.Active() then
		if Automatic() then
			ReadFury()
		end
		WorkOut()
		DropAll()
		ns.EachPlate(Update)
	end
end)
-- Righteous Fury comes and goes with the player's auras; only a paladin's role reads it.
ns.AddEvent(KEY, "UNIT_AURA", function()
	if PT.Active() and Automatic() and Class() == "PALADIN" then
		ReadFury()
		if WorkOut() then
			PassAll()
		end
	end
end, PlayerUnit)
-- The plate of that unit, or every plate when the client withholds which unit it was, has its kind read again.
ns.AddEvent(KEY, "UNIT_CLASSIFICATION_CHANGED", function(unit)
	if not PT.Active() then
		return
	end
	if ns.IsSecret(unit) then
		for _, rec in pairs(recs) do
			rec.kind, rec.kindUnit = nil, nil
		end
		PassAll()
		return
	end
	local unitFrame = ns.PlateUnitFrame(unit)
	local rec = unitFrame and recs[unitFrame]
	if rec then
		rec.kind, rec.kindUnit = nil, nil
		Pass(unitFrame)
	end
end, PlateUnit)

-- /flatui role: the role threat reads the player as, and why; tank, damage or auto sets Your role, and toggle sets the other of tank and damage.
ns.AddSlash(KEY, "role", function(rest)
	local word = type(rest) == "string" and rest:lower():match("^%s*(%S*)") or ""
	if word == "tank" or word == "damage" or word == "auto" then
		ns.Set(KEY .. ".threatRole", word)
	elseif word == "toggle" then
		ns.Set(KEY .. ".threatRole", PT.Role() == "tank" and "damage" or "tank")
	elseif word ~= "" then
		print(HELP[1])
		return
	end
	WorkOut()
	local now, reason = PT.Role()
	print(("Nameplate threat: you count as %s (%s)."):format(now == "tank" and "a tank" or "damage or healer", reason))
	if not PT.Active() then
		print("Nameplate threat: no nameplate shows threat while Restyle nameplates or Threat on nameplates is off.")
	end
end, HELP)
