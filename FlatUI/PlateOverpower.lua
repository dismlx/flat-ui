local _, ns = ...

-- Overpower over the enemy that dodged you, a part of Nameplates.lua (ns.PlateExtra), for a warrior who knows Overpower: when an enemy dodges an
-- attack of yours, Overpower's own icon (C_Spell.GetSpellTexture, SpellDocumentation.lua:595) shows above that enemy's name, centred, with Flat UI's
-- thin border (ns.Outline) at Overpower icon size: over the row of the enemy's debuffs while the game shows it (the icon stands on a guide frame of
-- Flat UI's own whose top is the row's top, so it rises as the row wraps to a second line, in a fight too, and shows the debuffs under it), else
-- over the name, and over the bar while the name is inside it. A row whose icons Nameplates.lua fades to nothing (Show auras Only on the target,
-- on another plate; ns.PlateAurasSeen) counts as hidden, and the guides stand anew as the target changes. With Threat value position at Above the
-- icon stands over the threat value, which stands on the guide (ns.PlateOverpowerPlace places it again as the value moves). ns.PlateDebuffTop
-- gives the same guide to PlateQuest.lua's mark and PlateThreatText.lua's value at Above, and ns.PlateOverpowerIcon the icon to that mark, which
-- stands over it while it shows (the mark is placed again as the icon pops in and once it has gone).
-- It glows, with the calm proc glow of the action buttons (ns.ProcGlowSoft, ProcGlow.lua; a calm pulse of the icon of this file's own on a client
-- that refuses it), while Overpower can be used now: C_Spell.IsSpellUsable of the highest rank you know says yes (SpellDocumentation.lua:980-995, plain in fights) and its cooldown is off or is the global cooldown alone. The cooldown is read as
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
-- renews it, as a new dodge renews Overpower's. The icon pops in as it lights (a quick fade in and a shrink from 130% of its size), gives a smaller
-- pop (from 115% over 0.15 seconds) each time a dodge renews its window, and, when its window runs out, fades away over a quarter of a second; any
-- other end hides it at once. With Time left on the Overpower icon (on by default) a
-- dark swipe drains clockwise over the icon for the window: a Cooldown frame of Flat UI's own (CooldownFrameTemplate, reversed, no edge, no
-- bling, no countdown numbers) over the icon, given the dodge's time and the window (SetCooldown, not protected on a frame of the addon's own, so a renewed window starts it again in a fight too)
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
-- texture, its grey, the swipe's SetCooldown and Clear, the glow's Play and Stop and its pop and fade change, which are not protected. A plate
-- first seen in a fight gets its icon when the fight ends; /flatui status counts those. Nothing of the game is written: every call on the game only reads.

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
-- aura icons of the plates have it. ICON: Overpower's icon file, for a client that does not give it. POP_FROM, POP_IN and POP_SCALE: the pop as the
-- icon lights (a fade in over POP_IN seconds and a shrink from POP_FROM of its size over POP_SCALE); RENEW_FROM and RENEW_SECONDS: the smaller pop
-- as a new dodge renews the window (from RENEW_FROM of its size back to whole); FADE_OUT: the seconds it fades as its window runs out.
local K = {
	RANKS = { 7384, 7887, 11584, 11585 },
	WINDOW = 5, MATCH = 0.5, LOOK = 0.1, GAP = 2, LEVEL = 20, DIM = 0.45, PULSE_LOW = 0.55, PULSE_SECONDS = 1.2, CROP = 0.08,
	AUTO_ATTACK = 6603, SIZE = 26, ICON = "Interface\\Icons\\Ability_MeleeDamage", POP_FROM = 1.3, POP_IN = 0.12, POP_SCALE = 0.15, FADE_OUT = 0.25,
	RENEW_FROM = 1.15, RENEW_SECONDS = 0.15,
	ACTIVE = { "UNIT_COMBAT", "SPELL_UPDATE_USABLE", "ACTION_USABLE_CHANGED", "SPELL_UPDATE_COOLDOWN", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
		"NAME_PLATE_UNIT_REMOVED" },
}
local RANK = {}
for _, id in ipairs(K.RANKS) do
	RANK[id] = true
end

-- recs[unitFrame]: holder (the icon's frame), icon (its texture), outline, swipe (its Cooldown frame, false when the client gave none), at (the dodge
-- the swipe runs from), glow (the soft look of ProcGlow.lua) or pulse (this file's own), to and size (what it was anchored to and sized at), file
-- (the texture it shows), shown, usable (the look it shows), glowing, pop, renew and fadeOut (its animation groups, nil on a client without them),
-- owner (the plate's unit frame), waiting (for the end of a fight). Kept when the plate leaves, so a plate's icon is made once.
local recs = setmetatable({}, { __mode = "k" })
-- guides[unitFrame]: { frame (a frame of Flat UI's own on the plate, the icon's anchor), top and bottom (the regions its corners are on) }. Kept when
-- the plate leaves, as the icons are.
local guides = setmetatable({}, { __mode = "k" })
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

-- False on a plate whose auras Nameplates.lua fades to nothing (Show auras Only on the target, on another plate), as PlateThreatText.lua reads it
-- for the rows beside the bar (ns.PlateAurasSeen); true where that cannot be asked.
local function Seen(unitFrame)
	if type(ns.PlateAurasSeen) ~= "function" then
		return true
	end
	local ok, seen = pcall(ns.PlateAurasSeen, unitFrame)
	return not ok or seen ~= false
end

-- The row of the enemy's debuffs while the game shows it and its icons are seen: the plate's AurasFrame and its DebuffListFrame both shown (the
-- Debuffs bit of the game's aura display options, Blizzard_NamePlateAuras.lua:404-416), on a plate whose auras are not faded (Seen).
local function DebuffRow(unitFrame)
	local auras = Region(unitFrame, "AurasFrame")
	local list = auras and Region(auras, "DebuffListFrame")
	if list and Ask(auras.IsShown, auras) == true and Ask(list.IsShown, list) == true and Seen(unitFrame) then
		return list
	end
	return nil
end

-- The guide of a plate, which the icon and PlateQuest.lua's mark at Above stand on: while the debuff row shows, its top left corner on the row's
-- (the row hangs from the left of the health bars and over the name, Blizzard_NamePlates.xml:219-227 and Blizzard_NamePlateUnitFrame.lua:864-870)
-- and its bottom right on the bars', so its top is the row's top as the row wraps to a second line, in a fight too, and its middle the bars'; else
-- the name's corners (AnchorOf), so it is where the icon stood before. Made and anchored again only out of combat on a plate that may be protected.
-- Returns the frame (nil while none could be made) and true while its anchors wait for the end of a fight.
local function Guide(unitFrame)
	local guide = guides[unitFrame]
	local top, bottom = DebuffRow(unitFrame), Region(unitFrame, "HealthBarsContainer")
	if not (top and bottom) then
		top = AnchorOf(unitFrame)
		bottom = top
	end
	if top == nil then
		return guide and guide.frame or nil, false
	end
	if guide and guide.top == top and guide.bottom == bottom then
		return guide.frame, false
	end
	if Locked(unitFrame) then
		return guide and guide.frame or nil, true
	end
	if guide == nil then
		local frame = CreateFrame("Frame", nil, unitFrame)
		ns.Own[frame] = true
		guide = { frame = frame }
		guides[unitFrame] = guide
	end
	local frame = guide.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 0, 0)
	guide.top, guide.bottom = top, bottom
	return frame, false
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

-- True while an animation group plays.
local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

-- The quest mark of a plate placed again (PlateQuest.lua), as the icon shows or has gone: a mark at Above stands over the icon while it shows.
local function QuestPlace(unitFrame)
	if unitFrame ~= nil and type(ns.PlateQuestPlace) == "function" then
		pcall(ns.PlateQuestPlace, unitFrame)
	end
end

-- The pop as the icon lights (an Alpha animation from nothing and a Scale animation from POP_FROM to whole, from its middle), the smaller pop as a
-- dodge renews the window (a Scale animation from RENEW_FROM to whole, no fade) and the fade as its window runs out (an Alpha animation to nothing
-- that keeps its end; the plate's quest mark drops back once it ends), animation groups of the icon's own frame, not protected, so they play in a
-- fight. Out of combat only, with the icon; a client that refuses them shows and hides the icon at once.
local function MakeMotion(rec)
	local holder = rec.holder
	local ok, pop, fadeOut, renew = pcall(function()
		local popGroup = holder:CreateAnimationGroup()
		ns.Own[popGroup] = true
		local appear = popGroup:CreateAnimation("Alpha")
		ns.Own[appear] = true
		appear:SetFromAlpha(0)
		appear:SetToAlpha(1)
		appear:SetDuration(K.POP_IN)
		local shrink = popGroup:CreateAnimation("Scale")
		ns.Own[shrink] = true
		shrink:SetScaleFrom(K.POP_FROM, K.POP_FROM)
		shrink:SetScaleTo(1, 1)
		shrink:SetDuration(K.POP_SCALE)
		shrink:SetOrigin("CENTER", 0, 0)
		pcall(shrink.SetSmoothing, shrink, "OUT")
		local fadeGroup = holder:CreateAnimationGroup()
		ns.Own[fadeGroup] = true
		local away = fadeGroup:CreateAnimation("Alpha")
		ns.Own[away] = true
		away:SetFromAlpha(1)
		away:SetToAlpha(0)
		away:SetDuration(K.FADE_OUT)
		pcall(fadeGroup.SetToFinalAlpha, fadeGroup, true)
		fadeGroup:SetScript("OnFinished", function()
			if not rec.shown then
				holder:SetAlpha(0)
				QuestPlace(rec.owner)
			end
		end)
		local renewGroup = holder:CreateAnimationGroup()
		ns.Own[renewGroup] = true
		local swell = renewGroup:CreateAnimation("Scale")
		ns.Own[swell] = true
		swell:SetScaleFrom(K.RENEW_FROM, K.RENEW_FROM)
		swell:SetScaleTo(1, 1)
		swell:SetDuration(K.RENEW_SECONDS)
		swell:SetOrigin("CENTER", 0, 0)
		pcall(swell.SetSmoothing, swell, "OUT")
		return popGroup, fadeGroup, renewGroup
	end)
	if ok and type(pop) == "table" and type(fadeOut) == "table" then
		rec.pop, rec.fadeOut = pop, fadeOut
		rec.renew = type(renew) == "table" and renew or nil
	end
end

-- The icon pops in: a fade out still running stops, and the icon shows at once where the pop cannot play.
local function Pop(rec)
	if rec.fadeOut then
		pcall(rec.fadeOut.Stop, rec.fadeOut)
	end
	if rec.renew then
		pcall(rec.renew.Stop, rec.renew)
	end
	rec.holder:SetAlpha(1)
	if rec.pop then
		pcall(rec.pop.Stop, rec.pop)
		pcall(rec.pop.Play, rec.pop)
	end
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
	rec.owner = unitFrame
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
	MakeMotion(rec)
	return rec
end

-- The threat value of a plate while it shows above the plate (PlateThreatText.lua, ns.PlateThreatTexts; it stands on the guide), or nil.
local function AboveValue(unitFrame)
	if type(ns.PlateThreatTexts) ~= "function" then
		return nil
	end
	local ok, value, side = pcall(ns.PlateThreatTexts, unitFrame)
	return ok and type(value) == "table" and side == "above" and Ask(value.IsShown, value) == true and value or nil
end

-- Sizes and anchors the icon on the plate's guide (Guide), or on the threat value while it shows above the plate, when its size or what it stands
-- on changed or it has none yet, out of combat on a plate that may be protected.
local function Place(unitFrame, rec)
	local to, stale = Guide(unitFrame)
	to = AboveValue(unitFrame) or to
	local size = Opt("overpowerSize")
	size = type(size) == "number" and size > 0 and size or K.SIZE
	if stale then
		Wait(unitFrame)
	end
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

-- fade: the window ran out, so the icon fades away (FADE_OUT); every other end (a cast of Overpower, the enemy's death, its plate leaving, a later dodge
-- on another plate, the part going off) hides it at once, which also cuts short a fade still running.
-- An icon gone at once places the plate's quest mark again (a fade does that as it ends, MakeMotion).
local function Hide(rec, fade)
	local holder = rec.holder
	local gone = false
	if holder and rec.shown then
		rec.shown, rec.usable = nil, nil
		Glow(rec, false)
		if rec.pop then
			pcall(rec.pop.Stop, rec.pop)
		end
		if rec.renew then
			pcall(rec.renew.Stop, rec.renew)
		end
		if not (fade and rec.fadeOut and pcall(rec.fadeOut.Play, rec.fadeOut)) then
			if rec.fadeOut then
				pcall(rec.fadeOut.Stop, rec.fadeOut)
			end
			holder:SetAlpha(0)
			gone = true
		end
	elseif holder and not fade and rec.fadeOut then
		gone = Playing(rec.fadeOut)
		pcall(rec.fadeOut.Stop, rec.fadeOut)
		holder:SetAlpha(0)
	end
	ClearSwipe(rec)
	if gone then
		QuestPlace(rec.owner)
	end
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
	local first = not rec.shown
	rec.shown, rec.usable = true, usable
	rec.icon:SetDesaturated(not usable)
	rec.icon:SetAlpha(usable and 1 or K.DIM)
	if first then
		Pop(rec)
		QuestPlace(unitFrame)
	else
		rec.holder:SetAlpha(1)
	end
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

-- fade: the window ran out (Hide).
local function Unlight(fade)
	if lit then
		local rec = recs[lit.unitFrame]
		lit = nil
		if rec then
			Hide(rec, fade)
		end
	end
	Ticking(false)
end

-- The dodge at `at` on a plate was yours: the icon moves there, for the window from that dodge. A later dodge on the plate that already shows it
-- renews the window, and the icon gives a small pop (RENEW_FROM) unless its pop in or its fade still plays.
local function Light(unitFrame, unit, at)
	if lit and lit.unitFrame ~= unitFrame then
		Unlight()
	end
	local renewed = lit ~= nil and lit.unitFrame == unitFrame and lit.at ~= at
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
	local rec = recs[unitFrame]
	if renewed and rec and rec.shown and rec.renew and not Playing(rec.pop) and not Playing(rec.fadeOut) then
		pcall(rec.renew.Stop, rec.renew)
		pcall(rec.renew.Play, rec.renew)
	end
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
	if Gone(lit.unitFrame) or Ask(UnitIsDead, lit.unit) == true then
		Unlight()
		return
	end
	if Now() >= lit.expires then
		Unlight(true)
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
	-- A fade still running on the plate ends now.
	local rec = recs[unitFrame]
	if rec then
		pcall(Hide, rec)
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
-- The guide of a plate for PlateQuest.lua's mark at Above and PlateThreatText.lua's value at Above: its top is the top of the enemy's debuffs
-- while their row shows and is seen, else of the name. Made out of combat when the plate has none; nil while it waits for the end of a fight.
-- Anchored again on each ask where what it spans changed.
function ns.PlateDebuffTop(unitFrame)
	if unitFrame == nil or ns.Forbidden(unitFrame) then
		return nil
	end
	local frame, stale = Guide(unitFrame)
	return frame, stale
end

-- The icon of a plate while it shows or fades, for PlateQuest.lua's mark at Above, which then stands over it; nil otherwise.
function ns.PlateOverpowerIcon(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder and rec.to ~= nil and (rec.shown or Playing(rec.fadeOut)) then
		return rec.holder
	end
	return nil
end

-- The icon of a plate placed again, for PlateThreatText.lua after the threat value took a new anchor: at Above the icon stands over the value.
function ns.PlateOverpowerPlace(unitFrame)
	local rec = unitFrame ~= nil and recs[unitFrame]
	if S.on and rec and rec.holder and not ns.Forbidden(unitFrame) then
		ns.EachPart(KEY, PART, Place, unitFrame, rec)
	end
end

-- The target changed while Show auras is Only on the target: the debuff rows of the old target and the new one faded or came back, so each guide
-- stands on the row or on the name again, and the icon, the quest mark and the threat value at Above with it. Out of combat on a plate that may be
-- protected; a guide that must wait has its plate's icon wait for the end of the fight.
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if Opt("aurasWhen") ~= "target" then
		return
	end
	for unitFrame in pairs(guides) do
		if not ns.Forbidden(unitFrame) then
			local ok, _, stale = pcall(Guide, unitFrame)
			if ok and stale and S.on then
				Wait(unitFrame)
			end
		end
	end
end)

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
