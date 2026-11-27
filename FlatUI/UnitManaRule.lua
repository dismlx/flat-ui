local _, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Five-second rule"
local MANA, RULE, REST = 0, 5, 1
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SPARK_TALL, SPARK_MIN, SPARK_WIDE, SPARK_ALPHA = 2, 8, 0.6, 0.9
local FLARE_SCALE, FLARE_TIME = 1.6, 0.3
local TELL_WAITS = "Flat UI: the five-second rule spark shows when the fight ends."
local TICK_PART = "Energy tick"
local ENERGY, TICK, ON_BEAT, RISE, MISSES, FRESH = 3, 2, 0.25, 15, 3, 0.5
local TELL_TICK = "Flat UI: the energy tick spark shows when the fight ends."
local TICK_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER" }

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local S = { ear = nil, hearing = false, rec = nil, start = nil, sample = nil, kind = nil, flared = nil }
local E = { ear = nil, hearing = false, rec = nil, anchor = nil, last = nil, misses = 0, sample = nil, phase = nil, driving = false, flaredAt = nil }
local costly = {}

local function Wanted()
	return ns.Enabled(KEY) and Opt("manaRule") == true and not ns.PartStopped(KEY, PART)
end

local function Testing()
	return ns.TestMode ~= nil and ns.TestMode.IsOn() == true
end

local function Now()
	local ok, now = pcall(GetTime)
	if ok and ns.Finite(now) then
		return now
	end
	return nil
end

local function PowerBar(rec)
	if X.active(rec) == true and Opt("playerPowerBar") == false then
		return nil
	end
	local power = rec.byRole and rec.byRole.power
	return power and power.target or rec.parts.power
end

local function Spark(holder)
	local spark = Own(holder:CreateTexture(nil, "OVERLAY", nil, 7))
	spark:SetTexture(SPARK)
	pcall(spark.SetBlendMode, spark, "ADD")
	spark:SetAlpha(SPARK_ALPHA)
	spark:Hide()
	return spark
end

local function MakeSet(parent, still)
	local holder = X.frame(parent)
	local spacer = Own(holder:CreateTexture(nil, "OVERLAY", nil, 6))
	spacer:SetColorTexture(0, 0, 0, 0)
	spacer:SetWidth(0.01)
	local spark = Spark(holder)
	spark:SetPoint("CENTER", spacer, "RIGHT", 0, 0)
	local burst = spark
	if still then
		burst = Spark(holder)
		burst:SetPoint("CENTER", holder, "RIGHT", 0, 0)
	end
	local ok, flare = pcall(function()
		local group = burst:CreateAnimationGroup()
		Own(group)
		local grow = group:CreateAnimation("Scale")
		grow:SetScaleFrom(1, 1)
		grow:SetScaleTo(FLARE_SCALE, FLARE_SCALE)
		grow:SetOrigin("CENTER", 0, 0)
		grow:SetDuration(FLARE_TIME)
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(SPARK_ALPHA)
		fade:SetToAlpha(0)
		fade:SetDuration(FLARE_TIME)
		pcall(group.SetToFinalAlpha, group, true)
		group:SetScript("OnFinished", function()
			burst:Hide()
			burst:SetAlpha(SPARK_ALPHA)
		end)
		return group
	end)
	return { holder = holder, spacer = spacer, spark = spark, burst = burst, flare = ok and flare or nil }
end

local function PlaceSet(set, over)
	local ok, tall = pcall(over.GetHeight, over)
	tall = ok and ns.Finite(tall) and tall > 0 and tall or 10
	local key = ("%.2f"):format(tall)
	if set.over == over and set.key == key then
		return
	end
	local holder = set.holder
	holder:ClearAllPoints()
	holder:SetAllPoints(over)
	local okLevel, level = pcall(over.GetFrameLevel, over)
	if okLevel and X.number(level) then
		pcall(holder.SetFrameLevel, holder, level + 2)
	end
	set.spacer:ClearAllPoints()
	set.spacer:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	set.spacer:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	local high = math.max(SPARK_MIN, tall * SPARK_TALL)
	set.spark:SetSize(high * SPARK_WIDE, high)
	set.burst:SetSize(high * SPARK_WIDE, high)
	set.over, set.key = over, key
end

local function Sets(rec)
	local m = rec.manaRule
	if m == nil then
		m = {}
		rec.manaRule = m
	end
	local fight, waits = InCombatLockdown(), false
	local over, parent = PowerBar(rec), rec.parts.badges or rec.parts.owner
	if over ~= nil and parent ~= nil and not ns.Forbidden(over) and not ns.Forbidden(parent) then
		if fight then
			waits = m.power == nil or m.power.over ~= over
		else
			m.power = m.power or MakeSet(parent)
			PlaceSet(m.power, over)
		end
	end
	local d = rec.druidMana
	if d ~= nil and d.holder ~= nil and d.bar ~= nil then
		if fight then
			waits = waits or m.druid == nil
		else
			m.druid = m.druid or MakeSet(d.holder)
			PlaceSet(m.druid, d.bar)
		end
	end
	return waits
end

local function PowerKind()
	local ok, kind = pcall(UnitPowerType, "player")
	if ok and ns.Finite(kind) then
		S.kind = kind
	end
	return S.kind
end

local function Pick(rec)
	local m = rec.manaRule
	if m == nil then
		return nil
	end
	if PowerKind() == MANA then
		return PowerBar(rec) ~= nil and m.power or nil
	end
	local d = rec.druidMana
	return d ~= nil and d.shown == true and m.druid or nil
end

local function Flaring(set)
	return set.flare ~= nil and set.flare:IsPlaying()
end

local function Quench(set)
	if Flaring(set) then
		pcall(set.flare.Stop, set.flare)
	end
	set.spark:SetAlpha(SPARK_ALPHA)
end

local function HideAll(rec, keepFlare)
	local m = rec and rec.manaRule
	if m == nil then
		return
	end
	for _, set in pairs(m) do
		if not (keepFlare and Flaring(set)) then
			Quench(set)
			set.spark:Hide()
		end
	end
end

local function Stop(keepFlare)
	S.start, S.sample, S.flared = nil, nil, nil
	if S.ear then
		S.ear:SetScript("OnUpdate", nil)
	end
	HideAll(S.rec, keepFlare)
end

local function Flare(rec)
	local set = Pick(rec)
	if set == nil or set.flare == nil or not set.spark:IsShown() then
		return
	end
	local ok, width = pcall(set.holder.GetWidth, set.holder)
	if ok and ns.Finite(width) and width > 0 then
		set.spacer:SetWidth(width)
	end
	Quench(set)
	if not pcall(set.flare.Play, set.flare) then
		set.spark:Hide()
	end
end

local function Sweep()
	local rec, now = S.rec, Now()
	if rec == nil or S.start == nil or now == nil then
		Stop()
		return
	end
	local gone = now - S.start
	if gone >= RULE then
		if not S.flared then
			S.flared = true
			Flare(rec)
		end
		if not (S.sample and Testing()) then
			Stop(true)
			return
		elseif gone < RULE + REST then
			HideAll(rec, true)
			return
		end
		S.start, gone, S.flared = now, 0, nil
		HideAll(rec)
	end
	local set = Pick(rec)
	for _, other in pairs(rec.manaRule) do
		if other ~= set then
			other.spark:Hide()
		end
	end
	if set == nil then
		return
	end
	local ok, width = pcall(set.holder.GetWidth, set.holder)
	if not ok or not ns.Finite(width) or width <= 0 then
		set.spark:Hide()
		return
	end
	set.spacer:SetWidth(math.max(0.01, width * gone / RULE))
	set.spark:Show()
end

local function OnUpdate()
	X.run(PART, Sweep)
end

local function Start(rec, sample)
	if S.ear == nil or rec.manaRule == nil then
		return
	end
	S.rec, S.start, S.sample, S.flared = rec, Now(), sample or nil, nil
	for _, set in pairs(rec.manaRule) do
		Quench(set)
	end
	S.ear:SetScript("OnUpdate", OnUpdate)
	Sweep()
end

local function CostsMana(spellID)
	local spells = C_Spell
	if type(spells) ~= "table" or type(spells.GetSpellPowerCost) ~= "function" then
		return costly[spellID] == true
	end
	local ok, costs = pcall(spells.GetSpellPowerCost, spellID)
	if not ok or IsSecret(costs) or type(costs) ~= "table" then
		return costly[spellID] == true
	end
	local paid, plain = false, true
	local read = pcall(function()
		for _, entry in ipairs(costs) do
			local kind = not IsSecret(entry) and type(entry) == "table" and entry.type or nil
			if IsSecret(kind) or kind == nil then
				plain = false
				break
			elseif ns.Finite(kind) and kind == MANA then
				local cost, share = entry.cost, entry.costPercent
				if IsSecret(cost) or IsSecret(share) then
					plain = false
					break
				end
				paid = (ns.Finite(cost) and cost > 0) or (ns.Finite(share) and share > 0)
				break
			end
		end
	end)
	if not (read and plain) then
		return costly[spellID] == true
	end
	costly[spellID] = paid
	return paid
end

local function OnCast(unit, spellID)
	if not IsSecret(unit) and unit ~= "player" then
		return
	end
	if not ns.Finite(spellID) or not CostsMana(spellID) then
		return
	end
	local rec = X.known(_G.PlayerFrame)
	if rec ~= nil and Wanted() then
		Start(rec, Testing())
	end
end

local function Hear(on)
	if S.hearing == on then
		return
	end
	local ear = S.ear
	if ear == nil then
		if not on then
			return
		end
		ear = Own(CreateFrame("Frame"))
		ear:SetScript("OnEvent", function(_, _, unit, _, spellID)
			X.run(PART, OnCast, unit, spellID)
		end)
		S.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	S.hearing = false
	if not on then
		return
	end
	local ok, done = false, nil
	if type(ear.RegisterUnitEvent) == "function" then
		ok, done = pcall(ear.RegisterUnitEvent, ear, "UNIT_SPELLCAST_SUCCEEDED", "player")
	end
	if not (ok and (IsSecret(done) or done ~= false)) then
		pcall(ear.RegisterEvent, ear, "UNIT_SPELLCAST_SUCCEEDED")
	end
	S.hearing = true
end

local ManaRule

function ManaRule(rec)
	if rec.kind ~= "player" then
		return
	end
	if not Wanted() then
		Hear(false)
		Stop()
		return
	end
	if Sets(rec) then
		X.tell(TELL_WAITS)
		if not rec.manaRuleQueued then
			rec.manaRuleQueued = true
			ns.OutOfCombat(function()
				rec.manaRuleQueued = nil
				X.run(PART, ManaRule, rec)
			end)
		end
	end
	Hear(true)
	S.rec = rec
	if Testing() then
		if not S.sample then
			Start(rec, true)
		end
	elseif S.sample then
		Stop()
	end
end

local function OnRefresh()
	local rec = X.known(_G.PlayerFrame)
	if rec then
		ManaRule(rec)
	end
end

local function TickWanted()
	return ns.Enabled(KEY) and Opt("energyTick") == true and not ns.PartStopped(KEY, TICK_PART)
end

local function Energetic()
	local ok, _, class = pcall(UnitClass, "player")
	return ok and not IsSecret(class) and (class == "ROGUE" or class == "DRUID")
end

local function TickSet(rec)
	local over, parent = PowerBar(rec), rec.parts.badges or rec.parts.owner
	if over == nil or parent == nil or ns.Forbidden(over) or ns.Forbidden(parent) then
		return false
	end
	local set = rec.energyTick
	if InCombatLockdown() then
		return set == nil or set.over ~= over
	end
	if set == nil then
		set = MakeSet(parent, true)
		rec.energyTick = set
	end
	PlaceSet(set, over)
	return false
end

local function TickOn()
	local rec = E.rec
	local set = rec and rec.energyTick
	if set == nil or E.ear == nil or E.anchor == nil or not TickWanted() then
		return nil
	end
	if PowerKind() ~= ENERGY or PowerBar(rec) ~= set.over then
		return nil
	end
	return set
end

local function Burst(set, now)
	E.flaredAt = now
	if set.flare == nil then
		return
	end
	pcall(set.flare.Stop, set.flare)
	set.burst:SetAlpha(SPARK_ALPHA)
	set.burst:Show()
	if not pcall(set.flare.Play, set.flare) then
		set.burst:Hide()
	end
end

local function Unburst(set)
	if set.flare ~= nil then
		pcall(set.flare.Stop, set.flare)
	end
	set.burst:Hide()
	set.burst:SetAlpha(SPARK_ALPHA)
end

local TickDrive

local function TickSweep()
	local set, now = TickOn(), Now()
	if set == nil or now == nil then
		TickDrive()
		return
	end
	local ok, width = pcall(set.holder.GetWidth, set.holder)
	if not ok or not ns.Finite(width) or width <= 0 then
		set.spark:Hide()
		return
	end
	local phase = (now - E.anchor) % TICK
	if E.phase ~= nil and phase < E.phase then
		Burst(set, now)
	end
	E.phase = phase
	set.spacer:SetWidth(math.max(0.01, width * phase / TICK))
	set.spark:Show()
end

local function OnTickUpdate()
	X.run(TICK_PART, TickSweep)
end

function TickDrive()
	local set = TickOn()
	if set ~= nil then
		if not E.driving then
			E.driving, E.phase = true, nil
			E.ear:SetScript("OnUpdate", OnTickUpdate)
		end
		TickSweep()
		return
	end
	if E.driving then
		E.driving, E.phase = false, nil
		E.ear:SetScript("OnUpdate", nil)
	end
	local rec = E.rec
	if rec ~= nil and rec.energyTick ~= nil then
		rec.energyTick.spark:Hide()
	end
end

local function TickStop()
	E.last, E.phase, E.misses = nil, nil, 0
	if E.sample then
		E.anchor, E.sample = nil, nil
	end
	E.driving = false
	if E.ear ~= nil then
		E.ear:SetScript("OnUpdate", nil)
	end
	local set = E.rec and E.rec.energyTick
	if set ~= nil then
		set.spark:Hide()
		Unburst(set)
	end
end

local function Energy()
	local ok, value = pcall(UnitPower, "player", ENERGY)
	if ok and ns.Finite(value) then
		return value
	end
	return nil
end

local function Rise(now)
	local anchor = E.anchor
	if anchor == nil or E.sample then
		E.anchor, E.misses, E.sample = now, 0, nil
	else
		local off = (now - anchor) % TICK
		if math.min(off, TICK - off) <= ON_BEAT then
			E.anchor, E.misses = now, 0
		else
			E.misses = E.misses + 1
			if E.misses < MISSES then
				return
			end
			E.anchor, E.misses = now, 0
		end
	end
	E.phase = nil
	TickDrive()
	local set = TickOn()
	if set ~= nil and (E.flaredAt == nil or now - E.flaredAt > FRESH) then
		Burst(set, now)
	end
end

local function OnTickEvent(event, unit)
	if event ~= "PLAYER_ENTERING_WORLD" and unit ~= nil and not IsSecret(unit) and unit ~= "player" then
		return
	end
	if event ~= "UNIT_POWER_FREQUENT" then
		E.last = Energy()
		TickDrive()
		return
	end
	local value = Energy()
	local last = E.last
	E.last = value
	if value == nil or last == nil or value - last < RISE then
		return
	end
	local now = Now()
	if now ~= nil then
		Rise(now)
	end
end

local function TickHear(on)
	if E.hearing == on then
		return
	end
	local ear = E.ear
	if ear == nil then
		if not on then
			return
		end
		ear = Own(CreateFrame("Frame"))
		ear:SetScript("OnEvent", function(_, event, unit)
			X.run(TICK_PART, OnTickEvent, event, unit)
		end)
		E.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	E.hearing = false
	if not on then
		return
	end
	for _, event in ipairs(TICK_EVENTS) do
		local ok, done = false, nil
		if type(ear.RegisterUnitEvent) == "function" then
			ok, done = pcall(ear.RegisterUnitEvent, ear, event, "player")
		end
		if not (ok and (IsSecret(done) or done ~= false)) then
			pcall(ear.RegisterEvent, ear, event)
		end
	end
	pcall(ear.RegisterEvent, ear, "PLAYER_ENTERING_WORLD")
	E.last = Energy()
	E.hearing = true
end

local EnergyTick

function EnergyTick(rec)
	if rec.kind ~= "player" then
		return
	end
	E.rec = rec
	if not TickWanted() or not Energetic() then
		TickHear(false)
		TickStop()
		return
	end
	if TickSet(rec) then
		X.tell(TELL_TICK)
		if not rec.energyTickQueued then
			rec.energyTickQueued = true
			ns.OutOfCombat(function()
				rec.energyTickQueued = nil
				X.run(TICK_PART, EnergyTick, rec)
			end)
		end
	end
	TickHear(true)
	if Testing() then
		if E.anchor == nil then
			E.anchor, E.sample = Now(), true
		end
	elseif E.sample then
		E.anchor, E.sample = nil, nil
	end
	TickDrive()
end

local function OnTickRefresh()
	local rec = X.known(_G.PlayerFrame)
	if rec then
		EnergyTick(rec)
	end
end

table.insert(X.after.apply, { part = PART, fn = ManaRule })
table.insert(X.after.refresh, { part = PART, fn = OnRefresh })
table.insert(X.after.apply, { part = TICK_PART, fn = EnergyTick })
table.insert(X.after.refresh, { part = TICK_PART, fn = OnTickRefresh })

if ns.TestMode then
	ns.TestMode.Watch(function()
		local rec = X.known(_G.PlayerFrame)
		if rec then
			X.run(PART, ManaRule, rec)
			X.run(TICK_PART, EnergyTick, rec)
		end
	end)
end
