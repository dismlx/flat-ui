local _, ns = ...

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local PART = "nameplate threat"
local AGGRO, HEALTH = "CompactUnitFrame_UpdateAggroHighlight", "CompactUnitFrame_UpdateHealthColor"
local KIND_ROWS = { tapped = "threatTapped", neutral = "threatNeutral", boss = "threatBoss", elite = "threatElite", normal = "threatNormal", minor = "threatMinor" }
local COLOUR_ROWS = { good = "threatGood", changing = "threatTransition", bad = "threatBad", offtank = "threatTankColour" }
local DAMAGE_ROWS = { good = "threatDamageGood", changing = "threatDamageTransition", bad = "threatDamageBad" }
local ELITE = { worldboss = true, rareelite = true, elite = true, rare = true }
local MINOR = { minus = true, trivial = true }
local INSTANCES = { party = true, raid = true, scenario = true }
local WANT = {
	[true] = { high = "good", medium = "changing", low = "bad", offtank = "offtank" },
	[false] = { low = "good", medium = "changing", high = "bad", offtank = "offtank" },
}
local FURY = { 25780, 20468, 20469, 20470, 407627 }
local DEFENSIVE, BEAR, DIRE_BEAR = 18, 5, 8
local HELP = { "/flatui role [tank|damage|auto|toggle] - the role nameplate threat reads you as, or set it" }
local MISSING = "Nameplate threat: the game's threat update was not found, so the glow, the fade and the threat value follow the health colour."

local PT = {}
ns.PlateThreat = PT

local recs = setmetatable({}, { __mode = "k" })
local telling = setmetatable({}, { __mode = "k" })
local changeFns, updateFns = {}, {}
local followed, inColour, seen = nil, 0, false
local role = { tank = false }
local class, fury = nil, false
local group = { tanks = {}, others = {} }
local listener, hearing = nil, false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
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

local function Count(fn, most)
	local value = Call(fn)
	if ns.Finite(value) and value > 0 then
		return math.min(math.floor(value), most)
	end
	return 0
end

local function Assigned(assignment, unit)
	if type(GetPartyAssignment) ~= "function" then
		return false
	end
	local ok, yes = pcall(GetPartyAssignment, assignment, unit)
	return ok and not ns.IsSecret(yes) and yes ~= nil and yes ~= false
end

local function Styled(unitFrame)
	if Opt("friendly") == true then
		return true
	end
	local friend = unitFrame.isFriend
	return ns.IsSecret(friend) or friend ~= true
end

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

local function Holds(value)
	return value == 2 or value == 3
end

local function PetOut()
	return Call(UnitExists, "pet") == true
end

local function InInstance()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not ns.IsSecret(inside) and inside == true and not ns.IsSecret(kind) and type(kind) == "string" and INSTANCES[kind] == true
end

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

local function Class()
	if class == nil then
		local value = Call(UnitClassBase, "player")
		class = type(value) == "string" and value or false
	end
	return class
end

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

local function Auto()
	local given = Call(UnitGroupRolesAssigned, "player")
	if given == "TANK" then
		return true, "your group role"
	elseif given == "HEALER" or given == "DAMAGER" then
		return false, "your group role"
	elseif Assigned("MAINTANK", "player") then
		return true, "Main Tank"
	elseif Call(UnitHasEffectivelyTankAura, "player") == true then
		return true, "a tank aura"
	end
	local kind = Class()
	if kind == "WARRIOR" and Form() == DEFENSIVE then
		return true, "Defensive Stance"
	elseif kind == "DRUID" and InBearForm() then
		return true, "Bear Form"
	elseif kind == "PALADIN" and fury then
		return true, "Righteous Fury"
	end
	return false, "no tank stance or form"
end

local function WorkOut()
	local choice = Opt("threatRole")
	local tank, reason
	if choice == "tank" or choice == "damage" then
		tank, reason = choice == "tank", "your choice"
	else
		tank, reason = Auto()
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

function PT.Active()
	return ns.Enabled(KEY) and Opt("threat") == true and not ns.PartStopped(KEY, PART)
end

local function Ask(unitFrame, rec)
	local unit = unitFrame.unit
	if ns.IsSecret(unit) or type(unit) ~= "string" or not Styled(unitFrame) then
		return nil, nil
	end
	if Call(UnitCanAttack, "player", unit) ~= true or Call(UnitIsPlayer, unit) == true then
		return nil, nil
	end
	if Opt("threatInstances") == true and not InInstance() then
		return nil, nil
	end
	local status, answer = Threat(UnitThreatSituation, "player", unit)
	local pet = false
	if status == nil then
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

function PT.OnChange(fn)
	return Listen(changeFns, fn)
end

function PT.OnUpdate(fn)
	return Listen(updateFns, fn)
end

function PT.Colour(state)
	if type(state) ~= "table" then
		return nil
	end
	local row = COLOUR_ROWS[state.want]
	if state.tank ~= true and Opt("threatSameColours") == false then
		row = DAMAGE_ROWS[state.want] or row
	end
	if row == nil then
		return nil
	end
	return ns.Colour(KEY .. "." .. row)
end

function PT.Role()
	if not PT.Active() then
		if Opt("threatRole") == "auto" then
			ReadFury()
		end
		WorkOut()
	elseif role.reason == nil then
		WorkOut()
	end
	return role.tank and "tank" or "damage", role.reason
end

function PT.AutoRole()
	if not PT.Active() then
		ReadFury()
	end
	local tank, reason = Auto()
	return tank and "tank" or "damage", reason
end

function PT.Seen()
	return seen
end

function PT.InColourCall()
	return inColour > 0
end

local function Pass(unitFrame)
	PT.Read(unitFrame)
	Update(unitFrame)
end

local function PassAll()
	ns.EachPlate(Pass)
end

local function OnAggro(frame)
	if not ns.IsPlate(frame) or not PT.Active() then
		return
	end
	Pass(frame)
end

local function OnHealthColour(frame)
	if not ns.IsPlate(frame) or not PT.Active() then
		return
	end
	inColour = inColour + 1
	pcall(PT.Read, frame)
	inColour = inColour - 1
	Update(frame)
end

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

EXTRA.show[#EXTRA.show + 1] = function(unitFrame)
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
ns.AddEvent(KEY, "UNIT_AURA", function()
	if PT.Active() and Automatic() and Class() == "PALADIN" then
		ReadFury()
		if WorkOut() then
			PassAll()
		end
	end
end, PlayerUnit)
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
	local marked = now == "tank" and Opt("threatSlipping") == true and PT.Active() and ", so enemies you are losing are marked" or ""
	print(("Flat UI: nameplate threat reads you as %s (%s)%s."):format(now == "tank" and "a tank" or "damage or healer", reason, marked))
	if not PT.Active() then
		print("Flat UI: no nameplate shows threat while Restyle nameplates or Threat on nameplates is off.")
	end
end, HELP)
