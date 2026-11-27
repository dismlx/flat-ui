local _, ns = ...

-- Five-second rule (off by default, Player frame page): a thin bright spark that crosses the player's mana bar from left to right over 5 seconds
-- each time the player casts a spell that costs mana. Mana regen in this content follows the five-second rule: Spirit refills mana only once the
-- player has spent none for 5 seconds (StatTipsMore.lua says so in the Spirit tooltip), so the spark reaching the end of the bar is the moment Spirit
-- pays again, and a healer sees at a glance when a pause starts paying off. Nothing of the game shows it.
--
-- A frame of the addon's own hears the player's UNIT_SPELLCAST_SUCCEEDED (RegisterUnitEvent for the player, so no other unit's casts reach Flat UI;
-- UnitDocumentation.lua) while the row is on, and reads only its spell ID (the third answer, a plain number checked with ns.Finite; a withheld one
-- starts nothing). The cost of that spell is the mana entry (type 0) of C_Spell.GetSpellPowerCost (SpellDocumentation.lua:535-549,
-- SpellSharedDocumentation.lua:46-58, no secret tag), read as UnitDruidMana.lua reads the cost of a shift: a cost or a share of base mana above 0
-- starts the sweep, or starts it again from the left. UnitPower is never read, so the rule counts from the cast the game reports, not from the mana
-- it took: a cast made free (Clearcasting) starts it too.
--
-- The spark is on the bar that shows the player's mana: the power bar of the player frame while UnitPowerType says plainly that the power is mana
-- (UnitDocumentation.lua:2859-2878, no secret tag; Enum.PowerType.Mana is 0; a withheld answer keeps the last), the outlined bar of a styled frame,
-- else the game's (ManaBarArea.ManaBar), as UnitDruidMana.lua Anchor finds it, and none while the Power bar row makes that bar transparent on a styled
-- frame; for a druid in Bear or Cat Form it is on the druid mana bar of UnitDruidMana.lua while that shows. The bar is chosen again at each step of
-- the sweep, so a shift into a form, which costs mana, carries the spark over to the druid's bar. Each bar has a frame of the addon's own over it, two
-- levels above, with an invisible spacer from its left edge and the spark on the spacer's right edge (the casting bar's spark,
-- Interface\CastingBar\UI-CastingBar-Spark, as the game's nameplate cast bar has it, Blizzard_NamePlateCastingBar.lua:62, in ADD blend, twice as
-- tall as the bar). As Channel ticks on the player bar does (CastTicks.lua), these are made and anchored once, out of a fight, on a frame the game
-- may protect, and placed again out of a fight only when the bar or its height changed; while the sweep runs only the spacer's width
-- (SetWidth), Show, Hide and SetAlpha change, so it works in a fight too. The width comes from the frame's own GetWidth at each step; one the game
-- withholds hides the spark. The sweep is an OnUpdate of the frame that hears the casts, set as a sweep starts and taken off as it ends. Turning the
-- row on in a fight waits for its end to make the spark, and while the options window is open chat says so once a fight. In test mode
-- (TestMode.lua, TM.Watch) the sweep loops, a second's rest between two, on the bar it would be on, so the row can be seen at work; it stops as test
-- mode ends. The game's player frame is not changed: no field written, no method called.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Five-second rule"
-- The power type of mana (Enum.PowerType.Mana), the seconds of the rule, and the seconds of rest between two sweeps of test mode.
local MANA, RULE, REST = 0, 5, 1
-- The spark: its file, its height against the bar's (at least SPARK_MIN units), its width against its height, its opacity.
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SPARK_TALL, SPARK_MIN, SPARK_WIDE, SPARK_ALPHA = 2, 8, 0.6, 0.9
-- What chat says, once a fight and only while the options window is open, when the spark waits for the end of the fight to be made (Tell).
local TELL_WAITS = "Flat UI: the five-second rule spark shows when the fight ends."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

-- S: ear (the frame that hears the casts and runs the sweep), hearing (the event is heard), rec (the player frame's record), start (the GetTime the
-- sweep started at, nil while none runs), sample (the sweep is test mode's, which loops) and kind (the last plain power type of the player).
local S = { ear = nil, hearing = false, rec = nil, start = nil, sample = nil, kind = nil }

-- True while the spark is wanted: the module on, the row on and the part not stopped.
local function Wanted()
	return ns.Enabled(KEY) and Opt("manaRule") == true and not ns.PartStopped(KEY, PART)
end

-- True while test mode is on and not paused (TestMode.lua).
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

-- The power bar of the player frame: the outlined bar of a styled frame, else the game's, as UnitDruidMana.lua Anchor finds it; nil while the Power
-- bar row makes it transparent on a styled frame.
local function PowerBar(rec)
	if X.active(rec) == true and Opt("playerPowerBar") == false then
		return nil
	end
	local power = rec.byRole and rec.byRole.power
	return power and power.target or rec.parts.power
end

-- One spark: a frame of the addon's own on parent, an invisible spacer and the spark on the spacer's right edge, made once, out of combat.
local function MakeSet(parent)
	local holder = X.frame(parent)
	local spacer = Own(holder:CreateTexture(nil, "OVERLAY", nil, 6))
	spacer:SetColorTexture(0, 0, 0, 0)
	spacer:SetWidth(0.01)
	local spark = Own(holder:CreateTexture(nil, "OVERLAY", nil, 7))
	spark:SetTexture(SPARK)
	pcall(spark.SetBlendMode, spark, "ADD")
	spark:SetAlpha(SPARK_ALPHA)
	spark:SetPoint("CENTER", spacer, "RIGHT", 0, 0)
	spark:Hide()
	return { holder = holder, spacer = spacer, spark = spark }
end

-- Lays a spark's frame over its bar, two levels above it, the spacer from its left edge and the spark twice its height: out of combat, and again only
-- when the bar or its height changed.
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
	set.over, set.key = over, key
end

-- Makes and places the sparks of the power bar and of the druid's mana bar where they are still missing or their bar moved, out of combat. True when
-- one waits for the end of the fight.
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

-- The plain power type of the player, the last one where the game withholds it.
local function PowerKind()
	local ok, kind = pcall(UnitPowerType, "player")
	if ok and ns.Finite(kind) then
		S.kind = kind
	end
	return S.kind
end

-- The spark the sweep shows now: the power bar's while the power is mana and that bar shows, else the druid's bar's while it shows, else none.
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

local function HideAll(rec)
	local m = rec and rec.manaRule
	if m == nil then
		return
	end
	for _, set in pairs(m) do
		set.spark:Hide()
	end
end

local function Stop()
	S.start, S.sample = nil, nil
	if S.ear then
		S.ear:SetScript("OnUpdate", nil)
	end
	HideAll(S.rec)
end

-- One step of the sweep: the spark at the share of the rule gone, on the bar of the moment; the end hides it, and test mode's starts again after a rest.
local function Sweep()
	local rec, now = S.rec, Now()
	if rec == nil or S.start == nil or now == nil then
		Stop()
		return
	end
	local gone = now - S.start
	if gone >= RULE then
		if not (S.sample and Testing()) then
			Stop()
			return
		elseif gone < RULE + REST then
			HideAll(rec)
			return
		end
		S.start, gone = now, 0
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

-- Starts the sweep from the left, or again from the left while one runs; sample for test mode's, which loops.
local function Start(rec, sample)
	if S.ear == nil or rec.manaRule == nil then
		return
	end
	S.rec, S.start, S.sample = rec, Now(), sample or nil
	S.ear:SetScript("OnUpdate", OnUpdate)
	Sweep()
end

-- True when a spell costs mana: the mana entry (type 0) of its costs, with a cost or a share of base mana above 0, all plain.
local function CostsMana(spellID)
	local spells = C_Spell
	if type(spells) ~= "table" or type(spells.GetSpellPowerCost) ~= "function" then
		return false
	end
	local ok, costs = pcall(spells.GetSpellPowerCost, spellID)
	if not ok or IsSecret(costs) or type(costs) ~= "table" then
		return false
	end
	local paid = false
	pcall(function()
		for _, entry in ipairs(costs) do
			local kind = not IsSecret(entry) and type(entry) == "table" and entry.type or nil
			if ns.Finite(kind) and kind == MANA then
				local cost, share = entry.cost, entry.costPercent
				paid = (ns.Finite(cost) and cost > 0) or (ns.Finite(share) and share > 0)
				break
			end
		end
	end)
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
		-- In test mode the sweep of a real cast goes on looping as the sample.
		Start(rec, Testing())
	end
end

-- The frame of the addon's own that hears the player's casts while the row is on, and nothing when it is not.
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
	-- A client that cannot hear one unit: every unit's casts come, and OnCast keeps the player's.
	if not (ok and (IsSecret(done) or done ~= false)) then
		pcall(ear.RegisterEvent, ear, "UNIT_SPELLCAST_SUCCEEDED")
	end
	S.hearing = true
end

local ManaRule

-- The sparks of the player frame: made and placed out of combat, the casts heard while the row is on, and test mode's sweep looping while it is on.
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
		-- While the options window is open chat says once a fight that the spark waits for its end (X.tell, UnitFrames.lua); a refresh in a fight with
		-- the window closed stays silent.
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

-- The player frame's record is made for the frame whatever its row says, but the steps after a frame's work run only for a frame Flat UI styles,
-- so each Refresh looks at it as well (as UnitDruidMana.lua does), after the druid's bar has had its turn.
local function OnRefresh()
	local rec = X.known(_G.PlayerFrame)
	if rec then
		ManaRule(rec)
	end
end

table.insert(X.after.apply, { part = PART, fn = ManaRule })
table.insert(X.after.refresh, { part = PART, fn = OnRefresh })

-- Test mode turned on or off, paused or resumed: the sample sweep loops, or stops.
if ns.TestMode then
	ns.TestMode.Watch(function()
		local rec = X.known(_G.PlayerFrame)
		if rec then
			X.run(PART, ManaRule, rec)
		end
	end)
end
