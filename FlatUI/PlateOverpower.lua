local _, ns = ...

-- Overpower over the enemy that dodged you, a part of Nameplates.lua (ns.PlateExtra), for a warrior who knows Overpower: when an enemy dodges an
-- attack of yours, Overpower's own icon (C_Spell.GetSpellTexture, SpellDocumentation.lua:595) shows above that enemy's name, centred, with Flat UI's
-- thin border (ns.Outline) at Overpower icon size. It glows, with the calm proc glow of the action buttons (ns.ProcGlowSoft, ProcGlow.lua; a calm
-- pulse of the icon of this file's own on a client that refuses it), while Overpower can be used now: C_Spell.IsSpellUsable of the highest rank you
-- know says yes (SpellDocumentation.lua:980-995, plain in fights) and its cooldown is off or is the global cooldown alone. The cooldown is read as
-- Interrupt.lua reads it: GetSpellCooldown never withholds isEnabled, isActive and isOnGCD (SpellSharedDocumentation.lua:19-31), isOnGCD is believed
-- only inside SPELL_UPDATE_COOLDOWN (:30), so only that event turns Overpower to not ready, and a look every LOOK seconds while the icon shows turns
-- it ready again, since no event comes when a cooldown runs out. While Overpower cannot be used now (the wrong stance, too little rage, its
-- cooldown) the icon is grey, dim and still. It goes when you cast Overpower (UNIT_SPELLCAST_SUCCEEDED for the player with one of its ranks,
-- UnitDocumentation.lua:4845; for a cast whose spell the game withholds, the start of Overpower's own cooldown, a cooldown that was ready and now
-- runs with isOnGCD a plain false, read in SPELL_UPDATE_COOLDOWN), when its window ends, when the enemy dies (UnitIsDead,
-- UnitDocumentation.lua:1916-1929) and when its plate goes (NAME_PLATE_UNIT_REMOVED, NamePlateManagerDocumentation.lua:139; the leave hook of
-- Nameplates.lua). One enemy shows it at a time, as a dodge gives the warrior one Overpower: a later dodge of yours moves it.
-- The window is the time of Overpower's row in ProcData.lua (5 seconds, the time of its hidden buff 1289681 in the DB2 tables of build 1.60.1, which
-- that file was written from), and 5 seconds when the row is missing: the game's UI source and API documentation name no time for it. A dodge
-- renews it, as a new dodge renews Overpower's. With Time left on the Overpower icon (on by default) a dark swipe drains clockwise over the icon
-- for the window: a Cooldown frame of Flat UI's own (CooldownFrameTemplate, reversed, no edge, no bling, no countdown numbers) over the icon, given
-- the dodge's time and the window (SetCooldown, not protected on a frame of the addon's own, so a renewed window starts it again in a fight too)
-- and cleared when the icon goes.
-- Which enemy dodged you. UNIT_COMBAT names the unit that dodged and the action ("DODGE", a plain string; only the amount is withheld,
-- UnitDocumentation.lua:4169-4180) but no source, and the combat log is not open to addons on this client (CombatLogGetCurrentEventInfo is not in
-- its list of calls, wowless data/products/wowf/apis.yaml; CombatText.lua's Whose hits says the same). So a dodge heard for a nameplate unit, the
-- target or the focus (on the plate C_NamePlate.GetNamePlateForUnit gives for it, NamePlateDocumentation.lua:11) of an enemy you can attack
-- (UnitCanAttack, UnitDocumentation.lua:763) counts as yours when:
--   1. the enemy is your target and you are in melee with it: your auto attack is on (PLAYER_ENTER_COMBAT and PLAYER_LEAVE_COMBAT,
--      UnitDocumentation.lua:3768, 3812, and C_Spell.IsCurrentSpell of Auto Attack when the part starts, SpellDocumentation.lua:741) and the game
--      does not say Overpower is out of range of it (C_Spell.IsSpellInRange, SpellDocumentation.lua:948-963; no answer counts as in range); or
--   2. Overpower turns usable within MATCH seconds of the dodge, before or after it (SPELL_UPDATE_USABLE, SpellBookDocumentation.lua:949, and
--      ACTION_USABLE_CHANGED, ActionBarFrameDocumentation.lua:1049, read as ProcTriggers.lua reads Overpower: not usable before, usable now).
--      With several enemies dodging within that time the turn goes to your target's dodge first, else to the latest one, and one turn names one dodge.
-- A dodge of an attack of someone else on your target while you are in melee with it also counts (the game does not say whose it was), and a dodge
-- in a stance where Overpower cannot be used, or with too little rage for it, is known by the first rule alone, since Overpower does not turn
-- usable then.
-- Combat: the icon is a frame of Flat UI's own, a child of the plate's unit frame so it moves, fades and hides with the plate, made, sized and
-- anchored only out of combat on a plate the game may protect (ns.MaybeProtected, Movers.lua), as the threat ring is (PlateThreatLook.lua): its
-- frame is made on each enemy plate as the plate shows while the row is on, so the first dodge of a fight has it. In a fight only its alpha, its
-- texture, its grey, the swipe's SetCooldown and Clear and the glow's Play and Stop change, which are not protected. A plate first seen in a fight gets its icon when the fight ends;
-- /flatui status counts those. Nothing of the game is written: every call on the game only reads.

local KEY = "nameplates"
local PART = "Overpower icon"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

-- RANKS: Overpower's ranks, the lowest first (ProcData.lua's WARRIOR row). WINDOW: the window when that row gives none. MATCH: the seconds between a
-- dodge and Overpower turning usable that tie them. LOOK: the seconds between two looks while the icon shows. GAP: nameplate units between the icon
-- and the name. LEVEL: frame levels above the plate's unit frame, over its auras. DIM: the opacity of a grey icon. PULSE_LOW and PULSE_SECONDS: the
-- pulse of this file's own, from full to PULSE_LOW and back, PULSE_SECONDS each way. CROP: the share of each edge of the icon cut off, as the
-- aura icons of the plates have it. ICON: Overpower's icon file, for a client that does not give it.
local K = {
	RANKS = { 7384, 7887, 11584, 11585 },
	WINDOW = 5, MATCH = 0.5, LOOK = 0.1, GAP = 2, LEVEL = 20, DIM = 0.45, PULSE_LOW = 0.55, PULSE_SECONDS = 1.2, CROP = 0.08,
	AUTO_ATTACK = 6603, SIZE = 26, ICON = "Interface\\Icons\\Ability_MeleeDamage",
	ACTIVE = { "UNIT_COMBAT", "SPELL_UPDATE_USABLE", "ACTION_USABLE_CHANGED", "SPELL_UPDATE_COOLDOWN", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
		"NAME_PLATE_UNIT_REMOVED" },
}
local RANK = {}
for _, id in ipairs(K.RANKS) do
	RANK[id] = true
end

-- recs[unitFrame]: holder (the icon's frame), icon (its texture), outline, swipe (its Cooldown frame, false when the client gave none), at (the dodge
-- the swipe runs from), glow (the soft look of ProcGlow.lua) or pulse (this file's own), to and size (what it was anchored to and sized at), file
-- (the texture it shows), shown, usable (the look it shows), glowing, waiting (for the end of a fight). Kept when the plate leaves, so a plate's
-- icon is made once.
local recs = setmetatable({}, { __mode = "k" })
-- lit: the plate that shows the icon, { unitFrame, unit (its nameplate token), expires }. pending: dodges not yet known to be yours, { unitFrame,
-- unit, at, target }.
local lit
local pending = {}
-- S: frame (the file's own, false when it could not be made), on (the events are heard), warrior (true or false once the game said), rank (the rank
-- known, false for none, nil before it is asked), texture, state (the last usable state: usable, power or blocked), turned (when Overpower last turned
-- usable), ready (its cooldown is off or the global cooldown, nil when not known), attacking (auto attack on), clock (since the last look), and the
-- counts for /flatui status.
local S = { frame = nil, on = false, warrior = nil, rank = nil, texture = nil, state = nil, turned = -math.huge, ready = nil, attacking = false,
	clock = 0, dodges = 0, mine = 0, waited = 0 }
local Sync, Draw, Prepare, Look

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Spell(name)
	return type(C_Spell) == "table" and C_Spell[name] or nil
end

local function Now()
	local now = Ask(GetTime)
	return type(now) == "number" and now or 0
end

-- The player's class, read once a plain answer comes (UnitClassBase, plain for the player).
local function Warrior()
	if S.warrior == nil then
		local token = Ask(UnitClassBase, "player")
		if type(token) == "string" then
			S.warrior = token == "WARRIOR"
		end
	end
	return S.warrior == true
end

-- The highest rank of Overpower the player knows, or nil; asked again when the spells change.
local function KnownRank()
	if S.rank == nil then
		S.rank = false
		local book = type(C_SpellBook) == "table" and C_SpellBook or {}
		for index = #K.RANKS, 1, -1 do
			local id = K.RANKS[index]
			local known = Ask(book.IsSpellKnownOrInSpellBook, id)
			if known == nil then
				known = Ask(book.IsSpellKnown, id)
			end
			if known == true then
				S.rank = id
				break
			end
		end
		local file = S.rank and Ask(Spell("GetSpellTexture"), S.rank)
		S.texture = (type(file) == "number" or type(file) == "string") and file or K.ICON
	end
	return S.rank or nil
end

-- The time of Overpower's window: its row in ProcData.lua, else WINDOW.
local function Window()
	local rows = type(ns.ProcData) == "table" and ns.ProcData.WARRIOR
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		if type(row) == "table" and type(row.lights) == "table" and row.lights[1] == K.RANKS[1] and type(row.seconds) == "number" and row.seconds > 0 then
			return row.seconds
		end
	end
	return K.WINDOW
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and Opt("overpower") == true and Warrior()
		and KnownRank() ~= nil
end

-- Overpower now: "usable", "power" (only rage is short) or "blocked", or nil when the game does not say.
local function UsableState()
	local rank = KnownRank()
	local call = Spell("IsSpellUsable")
	if not rank or type(call) ~= "function" then
		return nil
	end
	local ok, usable, power = pcall(call, rank)
	if not ok or not Plain(usable, "boolean") or ns.IsSecret(power) then
		return nil
	end
	return usable and "usable" or (power == true and "power" or "blocked")
end

-- True while Overpower's cooldown is off or is the global cooldown alone, false while it runs or is held, nil when the game gives no plain answer.
-- The second answer is true only while its own cooldown plainly runs: active, and isOnGCD a plain false (isOnGCD may be nil,
-- SpellSharedDocumentation.lua:30, and a global cooldown read as nil is no cast of Overpower).
local function Fresh()
	local rank = KnownRank()
	local info = rank and Ask(Spell("GetSpellCooldown"), rank)
	if type(info) ~= "table" then
		return nil
	end
	local enabled, active, gcd = info.isEnabled, info.isActive, info.isOnGCD
	if ns.IsSecret(enabled) or ns.IsSecret(active) or ns.IsSecret(gcd) then
		return nil
	end
	if enabled == false then
		return false
	end
	return active ~= true or gcd == true, active == true and gcd == false
end

-- The icon's frame ------------------------------------------------------------------------------------------------------------------------------

-- SetPoint and ClearAllPoints are protected (SimpleScriptRegionResizingAPIDocumentation.lua:22-30, 135-139): on a plate that may be protected nothing
-- is made, sized or anchored in a fight. Movers.lua has ns.MaybeProtected; before it loads every frame counts as protected.
local function Locked(unitFrame)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(unitFrame))
end

local function Region(owner, key)
	local region = owner[key]
	if ns.IsSecret(region) or type(region) ~= "table" or ns.Forbidden(region) then
		return nil
	end
	return region
end

-- True when the game puts the name inside the health bar (as Nameplates.lua's NameInside reads it).
local function NameInside()
	local options, constants = NamePlateSetupOptions, NamePlateConstants
	local styles = Plain(constants, "table") and constants.NAME_ANCHOR_STYLES
	local style = Plain(options, "table") and options.unitNameAnchorStyle
	return Plain(styles, "table") and Plain(style, "number") and style == styles.InsideHealthBar
end

-- What the icon stands on: the name, or the top of the health bars while the name is inside the bar.
local function AnchorOf(unitFrame)
	local name, bars = Region(unitFrame, "name"), Region(unitFrame, "HealthBarsContainer")
	local only = unitFrame.showOnlyName
	if (Plain(only, "boolean") and only) or not NameInside() then
		return name or bars
	end
	return bars or name
end

local function Wait(unitFrame)
	local rec = recs[unitFrame]
	if rec == nil then
		rec = {}
		recs[unitFrame] = rec
	end
	if rec.waiting then
		return
	end
	rec.waiting = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.waiting = nil
		if S.on and recs[unitFrame] == rec and not ns.Forbidden(unitFrame) then
			ns.EachPart(KEY, PART, Prepare, unitFrame)
			if lit and lit.unitFrame == unitFrame then
				ns.EachPart(KEY, PART, Draw)
			end
		end
	end)
end

-- The glow: the soft look of the action buttons over the icon, else a calm pulse of the icon. Out of combat only.
local function MakeGlow(rec)
	local ok, look = pcall(ns.ProcGlowSoft, rec.holder, rec.holder)
	if ok and type(look) == "table" and type(look.frame) == "table" and type(look.pulse) == "table" then
		rec.glow = look
		return
	end
	local group = rec.icon:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(K.PULSE_LOW)
	fade:SetDuration(K.PULSE_SECONDS)
	fade:SetSmoothing("IN_OUT")
	group:SetLooping("BOUNCE")
	rec.pulse = group
end

-- The swipe of the window's time left: a Cooldown frame of the addon's own over the icon. Out of combat only.
local function MakeSwipe(rec)
	local ok, swipe = pcall(CreateFrame, "Cooldown", nil, rec.holder, "CooldownFrameTemplate")
	if not ok or type(swipe) ~= "table" then
		rec.swipe = false
		return
	end
	ns.Own[swipe] = true
	swipe:SetAllPoints(rec.icon)
	pcall(swipe.SetReverse, swipe, true)
	pcall(swipe.SetDrawEdge, swipe, false)
	pcall(swipe.SetDrawBling, swipe, false)
	pcall(swipe.SetHideCountdownNumbers, swipe, true)
	local level = Ask(rec.holder.GetFrameLevel, rec.holder)
	if type(level) == "number" then
		pcall(swipe.SetFrameLevel, swipe, level + 1)
	end
	rec.swipe = swipe
end

local function ClearSwipe(rec)
	if rec.swipe and rec.at ~= nil then
		rec.at = nil
		pcall(rec.swipe.Clear, rec.swipe)
	end
end

-- The icon of a plate, made the first time the plate needs one; nil while it waits for the end of a fight.
local function Make(unitFrame)
	local rec = recs[unitFrame]
	if rec and rec.holder then
		return rec
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return nil
	end
	rec = rec or {}
	recs[unitFrame] = rec
	local holder = CreateFrame("Frame", nil, unitFrame)
	ns.Own[holder] = true
	holder:SetSize(K.SIZE, K.SIZE)
	holder:SetAlpha(0)
	local icon = holder:CreateTexture(nil, "ARTWORK")
	ns.Own[icon] = true
	icon:SetAllPoints(holder)
	icon:SetTexCoord(K.CROP, 1 - K.CROP, K.CROP, 1 - K.CROP)
	rec.holder, rec.icon = holder, icon
	MakeSwipe(rec)
	rec.outline = ns.Outline(holder, holder)
	ns.SetOutline(rec.outline, true, true)
	-- The thin border stays over the swipe.
	local edges, level = rec.outline and rec.outline.holder, Ask(holder.GetFrameLevel, holder)
	if rec.swipe and type(edges) == "table" and type(level) == "number" then
		pcall(edges.SetFrameLevel, edges, level + 2)
	end
	MakeGlow(rec)
	return rec
end

-- Sizes and anchors the icon when its size or what it stands on changed, out of combat on a plate that may be protected.
local function Place(unitFrame, rec)
	local to, size = AnchorOf(unitFrame), Opt("overpowerSize")
	size = type(size) == "number" and size > 0 and size or K.SIZE
	if to == nil or (rec.to == to and rec.size == size) then
		return
	end
	if Locked(unitFrame) then
		Wait(unitFrame)
		return
	end
	local holder = rec.holder
	holder:SetSize(size, size)
	if rec.to ~= to then
		holder:ClearAllPoints()
		holder:SetPoint("BOTTOM", to, "TOP", 0, K.GAP)
	end
	local level = Ask(unitFrame.GetFrameLevel, unitFrame)
	if type(level) == "number" then
		pcall(holder.SetFrameLevel, holder, level + K.LEVEL)
	end
	rec.to, rec.size = to, size
end

-- An enemy plate gets its icon ready, so the first dodge of a fight shows at once. A plate whose side is not known yet gets it too.
function Prepare(unitFrame)
	if not S.on or ns.Forbidden(unitFrame) then
		return
	end
	local unit = unitFrame.unit
	if Plain(unit, "string") and Ask(UnitCanAttack, "player", unit) == false then
		return
	end
	local rec = Make(unitFrame)
	if rec then
		Place(unitFrame, rec)
	end
end

local function Glow(rec, on)
	if rec.glowing == on then
		return
	end
	rec.glowing = on
	local glow = rec.glow
	if glow then
		if on then
			glow.frame:SetAlpha(1)
			glow.pulse:Play()
		else
			glow.pulse:Stop()
			glow.frame:SetAlpha(0)
		end
	elseif rec.pulse then
		if on then
			rec.pulse:Play()
		else
			rec.pulse:Stop()
		end
	end
end

local function Hide(rec)
	if rec.holder and rec.shown then
		rec.shown, rec.usable = nil, nil
		rec.holder:SetAlpha(0)
		Glow(rec, false)
	end
	ClearSwipe(rec)
end

-- Shows the icon on the lit plate: glowing while Overpower can be used now, grey, dim and still while it cannot.
function Draw()
	if not lit then
		return
	end
	local unitFrame = lit.unitFrame
	local rec = recs[unitFrame]
	if not (rec and rec.holder) then
		rec = Make(unitFrame)
		if not rec then
			return
		end
	end
	Place(unitFrame, rec)
	if rec.to == nil then
		return
	end
	if rec.file ~= S.texture then
		rec.file = S.texture
		rec.icon:SetTexture(S.texture)
	end
	-- The swipe runs from the dodge that lit the icon, and again from a dodge that renews it.
	if Opt("overpowerSwipe") ~= true then
		ClearSwipe(rec)
	elseif rec.swipe and rec.at ~= lit.at then
		rec.at = lit.at
		pcall(rec.swipe.SetCooldown, rec.swipe, lit.at, lit.expires - lit.at)
	end
	local usable = UsableState() == "usable" and S.ready ~= false
	if rec.shown and rec.usable == usable then
		return
	end
	rec.shown, rec.usable = true, usable
	rec.icon:SetDesaturated(not usable)
	rec.icon:SetAlpha(usable and 1 or K.DIM)
	rec.holder:SetAlpha(1)
	Glow(rec, usable)
end

-- Lighting and the looks -------------------------------------------------------------------------------------------------------------------

local function OnUpdate(_, elapsed)
	S.clock = S.clock + (type(elapsed) == "number" and elapsed or 0)
	if S.clock >= K.LOOK then
		S.clock = 0
		ns.EachPart(KEY, PART, Look)
	end
end

local function Ticking(on)
	if S.frame then
		S.clock = 0
		pcall(S.frame.SetScript, S.frame, "OnUpdate", on and OnUpdate or nil)
	end
end

local function Unlight()
	if lit then
		local rec = recs[lit.unitFrame]
		lit = nil
		if rec then
			Hide(rec)
		end
	end
	Ticking(false)
end

-- The dodge at `at` on a plate was yours: the icon moves there, for the window from that dodge.
local function Light(unitFrame, unit, at)
	if lit and lit.unitFrame ~= unitFrame then
		Unlight()
	end
	if not (lit and lit.unitFrame == unitFrame and lit.at == at) then
		S.mine = S.mine + 1
	end
	-- A turn of Overpower to usable just before is this dodge's.
	S.turned = -math.huge
	-- A cooldown that ran out while no icon showed was not looked at: it is ready again before the icon is drawn.
	if S.ready ~= true and Fresh() == true then
		S.ready = true
	end
	lit = { unitFrame = unitFrame, unit = unit, at = at, expires = at + Window() }
	Ticking(true)
	Draw()
end

local function Gone(unitFrame)
	if ns.Forbidden(unitFrame) then
		return true
	end
	local unit = unitFrame.unit
	return not ns.IsSecret(unit) and unit == nil
end

-- A look while the icon shows: the window, the enemy's death and its plate, and the look Overpower asks for now.
function Look()
	if not lit then
		Ticking(false)
		return
	end
	if Now() >= lit.expires or Gone(lit.unitFrame) or Ask(UnitIsDead, lit.unit) == true then
		Unlight()
		return
	end
	if S.ready ~= true and Fresh() == true then
		S.ready = true
	end
	Draw()
end

-- Ties a turn of Overpower to usable to a dodge within MATCH seconds of it: your target's first, else the latest. Dodges too old to be tied go.
local function Match(now)
	local kept, best = {}, nil
	for _, dodge in ipairs(pending) do
		if now - dodge.at <= K.MATCH then
			kept[#kept + 1] = dodge
			if math.abs(dodge.at - S.turned) <= K.MATCH
				and (best == nil or (dodge.target and not best.target) or (dodge.target == best.target and dodge.at >= best.at)) then
				best = dodge
			end
		end
	end
	pending = kept
	if best then
		pending, S.turned = {}, -math.huge
		Light(best.unitFrame, best.unit, best.at)
	end
end

-- Your auto attack is on and the game does not say Overpower is out of range of the unit.
local function Melee(unit)
	return S.attacking and Ask(Spell("IsSpellInRange"), S.rank, unit) ~= false
end

local function OnCombat(unit, action)
	if not Plain(unit, "string") or not Plain(action, "string") or action ~= "DODGE" then
		return
	end
	if unit ~= "target" and unit ~= "focus" and not unit:find("^nameplate") then
		return
	end
	local unitFrame = type(ns.PlateUnitFrame) == "function" and ns.PlateUnitFrame(unit)
	if not unitFrame or ns.Forbidden(unitFrame) then
		return
	end
	-- The plate's own token: the target and the focus may change before the window ends.
	local token = unitFrame.unit
	if not Plain(token, "string") then
		token = unit
	end
	if Ask(UnitCanAttack, "player", token) == false then
		return
	end
	if unit:find("^nameplate") then
		S.dodges = S.dodges + 1
	end
	local now = Now()
	local target = unit == "target" or Ask(UnitIsUnit, token, "target") == true
	if target and Melee(token) then
		Light(unitFrame, token, now)
		return
	end
	local found = false
	for _, dodge in ipairs(pending) do
		if dodge.unitFrame == unitFrame then
			-- The target's and the plate's report of one dodge come in one frame: either may say it is the target.
			dodge.target = target or (dodge.at == now and dodge.target)
			dodge.at, dodge.unit, found = now, token, true
		end
	end
	if not found then
		pending[#pending + 1] = { unitFrame = unitFrame, unit = token, at = now, target = target }
	end
	Match(now)
end

local function OnUsable()
	local state = UsableState()
	if state == nil then
		return
	end
	local before = S.state
	S.state = state
	if state == "usable" and before ~= nil and before ~= "usable" then
		-- A turn just after a dodge already shown is that dodge's; any other may name a dodge waiting.
		local now = Now()
		if lit and now - lit.at <= K.MATCH then
			S.turned = -math.huge
		else
			S.turned = now
			Match(now)
		end
	end
	Draw()
end

-- Inside the event isOnGCD is believed: Overpower's own cooldown starting while the icon shows (isOnGCD a plain false) is a cast of it the game
-- did not name.
local function OnCooldown()
	local before = S.ready
	local fresh, own = Fresh()
	S.ready = fresh
	if lit and before == true and own == true then
		Unlight()
		return
	end
	Draw()
end

local function OnCast(unit, _, spellID)
	if Plain(unit, "string") and unit == "player" and Plain(spellID, "number") and RANK[spellID] then
		pending, S.turned = {}, -math.huge
		Unlight()
	end
end

local function OnRemoved(unit)
	if not Plain(unit, "string") then
		return
	end
	if lit and lit.unit == unit then
		Unlight()
	end
	local kept = {}
	for _, dodge in ipairs(pending) do
		if dodge.unit ~= unit then
			kept[#kept + 1] = dodge
		end
	end
	pending = kept
end

local function Heard(event, ...)
	if event == "UNIT_COMBAT" then
		OnCombat(...)
	elseif event == "SPELL_UPDATE_USABLE" or event == "ACTION_USABLE_CHANGED" then
		OnUsable()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		OnCooldown()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		OnCast(...)
	elseif event == "PLAYER_ENTER_COMBAT" then
		S.attacking = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		S.attacking = false
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		OnRemoved(...)
	elseif event == "SPELLS_CHANGED" then
		S.rank, S.texture = nil, nil
		Sync()
	end
end

-- Everything hidden and forgotten: the row, the page or the part went off, or Overpower is not known.
local function StandDown()
	lit, pending = nil, {}
	Ticking(false)
	for _, rec in pairs(recs) do
		pcall(Hide, rec)
	end
end

local function OnEvent(_, event, ...)
	local ok = ns.EachPart(KEY, PART, Heard, event, ...)
	if not ok and ns.PartStopped(KEY, PART) then
		S.on = false
		pcall(StandDown)
	end
end

-- The file's own frame, made for a warrior: it hears SPELLS_CHANGED always, the rest while the row is on.
local function Frame()
	if S.frame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			S.frame = false
			return nil
		end
		ns.Own[frame] = true
		frame:SetScript("OnEvent", OnEvent)
		pcall(frame.RegisterEvent, frame, "SPELLS_CHANGED")
		S.frame = frame
	end
	return S.frame or nil
end

local function Hear(on)
	local frame = Frame()
	if not frame then
		return
	end
	for _, event in ipairs(K.ACTIVE) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	if not on then
		pcall(frame.UnregisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
	elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")) then
		pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
	end
end

-- Starts or stops the part as the row, the page, the class and the spells say, and sizes and anchors the icons again.
function Sync()
	if Warrior() then
		Frame()
	end
	local want = Wanted() and S.frame and true or false
	if want ~= S.on then
		S.on = want
		Hear(want)
		if want then
			S.state, S.ready = UsableState(), Fresh()
			S.attacking = Ask(Spell("IsCurrentSpell"), K.AUTO_ATTACK) == true
			if type(ns.EachPlate) == "function" then
				ns.EachPlate(function(unitFrame)
					ns.EachPart(KEY, PART, Prepare, unitFrame)
				end)
			end
		else
			StandDown()
		end
	end
	if want then
		for unitFrame, rec in pairs(recs) do
			if rec.holder and not ns.Forbidden(unitFrame) then
				ns.EachPart(KEY, PART, Place, unitFrame, rec)
			end
		end
		Draw()
	end
end

-- Hooks into the plates ------------------------------------------------------------------------------------------------------------------------

EXTRA.show[#EXTRA.show + 1] = function(unitFrame)
	if S.on then
		ns.EachPart(KEY, PART, Prepare, unitFrame)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(unitFrame)
	local rec = recs[unitFrame]
	if S.on and rec and rec.holder then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(unitFrame)
	if lit and lit.unitFrame == unitFrame then
		Unlight()
	end
	local kept = {}
	for _, dodge in ipairs(pending) do
		if dodge.unitFrame ~= unitFrame then
			kept[#kept + 1] = dodge
		end
	end
	pending = kept
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	local ok = ns.EachPart(KEY, PART, Sync)
	if not ok and (ns.PartStopped(KEY, PART) or not ns.Enabled(KEY)) then
		S.on = false
		pcall(Hear, false)
		pcall(StandDown)
	end
end
EXTRA.status[#EXTRA.status + 1] = function()
	if Opt("overpower") ~= true or not Warrior() then
		return nil
	end
	if not KnownRank() then
		return "Overpower on enemy nameplates: you do not know Overpower yet."
	end
	return ("Overpower on enemy nameplates: %d dodges heard, %d yours, %d plates waited for the end of a fight for their icon."):format(S.dodges,
		S.mine, S.waited)
end
