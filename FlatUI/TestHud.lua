local _, ns = ...

-- Test mode's stand-ins for the bars, auras, rolls, the timer bars and the sample plate (spec section 1.3, Part C), and the cursor ring's samples. Each stand-in is
-- a frame of Flat UI's own that TestMode.lua makes, places and shows (TM.StandIn): at the place, scale, strata and level of a game frame that is
-- hidden now, while test mode is on, its module is on and the real frame does not show. It is painted from the rows by the painters the setup
-- drawings share (ns.DrawCasts of SetupDrawCasts.lua, ns.DrawHud of SetupDrawHud.lua, ns.SetupDrawPlates of SetupDrawPlates.lua), and its moving
-- parts change in Animate, while it shows and the bar's Moving is on: fills, text and alpha only. The numbers are fixed samples.
--   Cast bars: the player's at PlayerCastingBarFrame, wherever Edit Mode or Lock to player frame put it, while the player casts nothing: a cast that
--   fills over 2.5 seconds and holds half a second, a channel that drains (with the marks of its 5 ticks while Channel ticks on the player bar is
--   on), then an interrupted cast that flashes, in the colours of the Flat UI page, with its seconds while Cast time on your bars is on and a sample
--   pushback over the second half of the cast and of the channel while Pushback on your bar is on.
--   The target's, the focus's and the pet's at TargetFrameSpellBar, FocusFrameSpellBar and PetCastingBarFrame, and the first boss's at
--   Boss1TargetFrameSpellBar, each only while the stand-in of its unit shows (TM.Shown of "target", "focus", "pet" and "boss", TestUnits.lua): an enemy
--   cast, the target's and the focus's in the colour of the player's interrupt while Interrupt readiness on enemy casts and Flat fill are on (the
--   target's ready, the focus's ready but out of range), then one that cannot be interrupted, a little later than the player's, each with "> You"
--   past its end while Target of enemy casts is on. Each bar takes the size of the game's frame. The boss bar keeps the game's look, as Bars.lua
--   styles no boss bar, and hangs on the unit frames' module, whose boss stand-in it follows.
--   Swing timers: at SwingTimerMainHandFrame for every class, SwingTimerOffHandFrame for a warrior and a rogue with an off-hand weapon,
--   SwingTimerRangedFrame for a hunter with a ranged weapon (UnitAttackSpeed, as the game's HasOffHandWeapon and HasRangedWeapon), while the game's
--   timer is hidden and would show in play: Enable Swing Timer (the variable showSwingTimer) on and the frame's Edit Mode Visibility not Hidden
--   (its visibility field, read with rawget; Blizzard_SwingTimer.lua:241-263): a swing of 2.6 seconds that loops, the main hand of a warrior, druid
--   or hunter in Queued ability colour over the second half of each swing while Queued next melee ability is on.
--   Debuffs and buffs: three icons each, from the top right corner of DebuffFrame while the player has no harmful aura and of BuffFrame while the
--   player has no helpful aura at all (C_UnitAuras.GetAuraSlots, read out of combat only, when its answer is plain), only while the game shows that
--   frame (its Edit Mode Visibility, Blizzard_BuffFrame/BuffFrame.lua:380-411) and not while Edit Mode is open, where it shows its example auras: a
--   magic, a curse and a poison debuff in the colours of their types, and times that count down and loop in the time format of Minimap and HUD
--   (AuraTime.lua).
--   Loot rolls: two rolls at the box Loot rolls of /flatui move, where the game's rolls show (ns.MoverSpot: the saved spot, else where the game
--   stacks them), up or down as Rolls stack says once a spot is saved, the game's 100 apart (Hud.lua, ROLL), while none of GroupLootFrame1 to 4
--   shows; their timers drain over 10 seconds and loop, with the seconds of a 60 second roll counting down over them, red under 10, while Seconds
--   left on rolls is on. They stand in for UIParent, so their place is the box's.
--   Timer bars: a breath timer at the top of MirrorTimerContainer, where the game's first timer shows, while none of its timers shows (Edit Mode's
--   empty bars count as shown): it drains over 30 seconds and loops, with "Breath" centred under it and the time left at its right ("0:30"), red
--   under 10, as Hud.lua draws the real one with Breath and fatigue timers and Seconds on the timers on, or in the game's look while the first is
--   off (ns.DrawHud.Mirror, SetupDrawHud.lua).
--   The sample nameplate: an enemy plate with its cast bar, auras and quest mark with its kill count (while Quest mark on enemies you need for a
--   quest is on and the marks are not left to Questie), and for a warrior the Overpower icon with its swipe over the auras, at the middle of the
--   screen, 160 units up, with a dim Sample nameplate under it, as plates have no place of their own. Its cast fills, and it takes the threat states
--   in turn every 3 seconds (You want, Changing hands, You do not want) while Threat on nameplates is on: its health bar in the threat colour while
--   Colour health bars by threat is on, the threat ring as Threat glow asks (flashing as it reaches You do not want, with Flash the ring when threat
--   goes wrong), a sample threat value (40%, 92%, 110%) at Threat value position, size, offsets, outline and colour, the name and the health text in
--   the threat colour, the threat colour on the border and the background as their rows ask, the name of the enemy's target right of the bar ([Gorvak]
--   in the warrior colour, and you on You do not want unless Not when it attacks you), and the fade of Fade enemies held for you
--   (SetupDrawPlates.lua's P.Threat); the quest mark moves past a value and the enemy's target on its side, and its kill count goes up with each
--   threat round (3/8 to 7/8), popping as it does. While Moving is off the Overpower swipe holds still with the rest (the stage's still).
-- The cursor ring is no module, so it cannot register with test mode (TM.Register runs an entry only while its module is on): at every On, Off,
-- pause and resume (TM.Watch) the ring applies its rows again (ns.CursorRingChanged, which reads TM.IsOn: In combat only reads as shown while it
-- is on), and while test mode is on and Moving a frame of this file gives the ring a sample cast and global cooldown every 3 seconds
-- (ns.CursorRingSample); that frame runs nothing while test mode is off.
-- Nothing of the game is written or called: the stand-ins read only what TestMode.lua reads, the auras' slots, the swing timers' variable, weapon
-- speeds and visibility field, and whether Edit Mode is open (ns.EditModeOpen).

local TM = ns.TestMode
if type(TM) ~= "table" then
	return
end

-- The cast bars: their stand-in, game frame, module, place on the Cast bars page (opt), the stand-in of their unit, how much later their round
-- starts, and their spell names by state. kick: the interrupt colour an enemy bar shows, ready on the target's and out of range on the focus's (the
-- setup picture shows on cooldown); the boss bar keeps the game's look, which takes none. aim: the sample name of the cast's target past the end of
-- the target's and the focus's bars while Target of enemy casts is on (CastTime.lua).
local CASTS = {
	{ id = "castPlayer", game = "PlayerCastingBarFrame", module = "castbars", opt = "player", label = "Cast bar", offset = 0, ticks = 5,
		names = { channel = "Drain Life" } },
	{ id = "castTarget", game = "TargetFrameSpellBar", module = "castbars", opt = "target", label = "Target cast bar", unit = "target", offset = 0.8,
		small = true, kick = "ready", aim = "> You", names = { cast = "Fireball", shield = "Polymorph" } },
	{ id = "castFocus", game = "FocusFrameSpellBar", module = "castbars", opt = "focus", label = "Focus cast bar", unit = "focus", offset = 1.6,
		small = true, kick = "far", aim = "> You", names = { cast = "Frostbolt", shield = "Fear" } },
	{ id = "castPet", game = "PetCastingBarFrame", module = "castbars", opt = "pet", label = "Pet cast bar", unit = "pet", offset = 2.4,
		round = "pet", names = { cast = "Firebolt" } },
	{ id = "castBoss", game = "Boss1TargetFrameSpellBar", module = "unitframes", opt = "boss", label = "Boss cast bar", unit = "boss", offset = 1.2,
		small = true, names = { cast = "Shadow Bolt Volley", shield = "Enrage" } },
}
-- A round of each kind of bar: the state, the seconds it runs and the seconds it holds at its end. The pet's casts are the player's own, so they
-- are neither shielded nor interrupted.
local ROUNDS = {
	player = { { "cast", 2.5, 0.5 }, { "channel", 2.5, 0.5 }, { "interrupted", 1, 0 } },
	enemy = { { "cast", 2.5, 0.5 }, { "shield", 2.5, 0.5 } },
	pet = { { "cast", 2, 0.5 } },
}
-- The swing timers: the stand-in, the game's frame, the hand, the classes that see it (every class when nil) and how much later it starts.
local SWINGS = {
	{ id = "swingMain", game = "SwingTimerMainHandFrame", hand = "main", label = "Main hand swing timer", offset = 0 },
	{ id = "swingOff", game = "SwingTimerOffHandFrame", hand = "off", label = "Off hand swing timer", offset = 0.9, classes = { WARRIOR = true, ROGUE = true } },
	{ id = "swingRanged", game = "SwingTimerRangedFrame", hand = "ranged", label = "Ranged swing timer", offset = 0.4, classes = { HUNTER = true } },
}
local SWING_PERIOD = 2.6
-- The auras: the game's aura button is 30 across with its time under it (Blizzard_BuffFrame/BuffFrameTemplates.xml:4-16); the gap between two.
local AURA_SIZE, AURA_GAP, AURA_TALL = 30, 5, 42
local DEBUFFS = {
	{ icon = "Interface\\Icons\\Spell_Frost_FrostNova", kind = 1, seconds = 18 },
	{ icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", kind = 2, seconds = 45 },
	{ icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", kind = 4, seconds = 130 },
}
local BUFFS = { { kind = nil, seconds = 25 }, { kind = nil, seconds = 290 }, { kind = nil, seconds = 1700 } }
-- The game's colour of an aura's time (GameFontNormalSmall), which Duration colour White replaces.
local AURA_GOLD = { 1, 0.82, 0 }
-- The rolls: the box of /flatui move, the game's room for each roll (GroupLootFrame.lua:15, Hud.lua's ROLL.step), its width (GroupLootFrame.xml:292),
-- the seconds its timer runs, and the items, those of mock-loot.
local ROLL_BOX, ROLL_STEP, ROLL_W, ROLL_TIME = "FlatUILootRolls", 100, 277, 10
local ROLL_ITEMS = { { icon = 2, name = "Sturdy Shield", quality = 2 }, { icon = 3, name = "Royal Crown", quality = 3 } }
-- Timer bars: the seconds of the sample breath timer, which drains and loops.
local MIRROR_TIME = 30
-- The sample plate: how far above the middle of the screen, its cast's round, the seconds of each threat colour and the colours in turn.
local PLATE_UP, PLATE_ROUND, PLATE_CAST, THREAT_EVERY = 160, 3, 2.5, 3
local THREAT = { "threatGood", "threatTransition", "threatBad" }
local DIM = { 0.66, 0.68, 0.62 }

local function Class()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, class = pcall(UnitClass, "player")
	if ok and not ns.IsSecret(class) and type(class) == "string" then
		return class
	end
	return nil
end

-- Where a bar is in its round at `now`: its state, the share of the bar filled, the seconds left, the seconds into the state and the seconds the
-- state runs (the whole cast, for Total cast time too).
local function Phase(round, offset, now)
	local total = 0
	for _, step in ipairs(round) do
		total = total + step[2] + step[3]
	end
	local t = (now + offset) % total
	for _, step in ipairs(round) do
		local length = step[2] + step[3]
		if t < length then
			local run = math.min(1, t / step[2])
			local state = step[1]
			if state == "channel" then
				return state, 1 - run, step[2] * (1 - run), t, step[2]
			elseif state == "interrupted" then
				return state, 1, 0, t, step[2]
			end
			return state, run, step[2] * (1 - run), t, step[2]
		end
		t = t - length
	end
	return round[1][1], 0, round[1][2], 0, round[1][2]
end

local function Now()
	local ok, now = pcall(GetTime)
	return ok and ns.Finite(now) and now or 0
end

local function EditMode()
	return type(ns.EditModeOpen) == "function" and ns.EditModeOpen() == true
end

-- Cast bars -----------------------------------------------------------------------------------------------------------------------------------

local function CastName(spec, state)
	if state == "interrupted" then
		return type(_G.INTERRUPTED) == "string" and _G.INTERRUPTED or "Interrupted"
	end
	return spec.names[state]
end

local function CastStandIn(spec)
	local round = ROUNDS[spec.round or (spec.opt == "player" and "player" or "enemy")]
	local function Shows(holder, state, part, left, into, total)
		ns.DrawCasts.CastProgress(holder.row, state, part, left, holder.row.state ~= state and CastName(spec, state) or nil, total)
		holder.row.bar:SetAlpha(state == "interrupted" and (0.45 + 0.55 * math.abs(math.cos(into * 6))) or 1)
	end
	TM.StandIn({
		id = spec.id,
		module = spec.module,
		game = spec.game,
		label = spec.label,
		fit = true,
		gate = spec.unit and function()
			return TM.Shown(spec.unit)
		end or nil,
		Build = function(holder)
			holder.row = ns.DrawCasts.Cast(holder, { opt = spec.opt, small = spec.small, shield = true, time = "",
				name = spec.opt == "player" and "Shadow Bolt" or spec.names.cast, rank = spec.opt == "player" and "Rank 3" or nil,
				ticks = spec.ticks, aim = spec.aim })
			holder.row.bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		end,
		Paint = function(holder, w, h)
			local state, part, left, into, total = Phase(round, spec.offset, Now())
			ns.DrawCasts.PaintCast(holder.row, spec.opt, state, part, w, h, CastName(spec, state), spec.kick)
			Shows(holder, state, part, left, into, total)
		end,
		Animate = function(holder, _, now)
			Shows(holder, Phase(round, spec.offset, now))
		end,
	})
end

-- Swing timers ----------------------------------------------------------------------------------------------------------------------------------

-- Whether the game would show a swing timer of this hand in play: Enable Swing Timer on, its Edit Mode Visibility (Always 0, In combat 1, Hidden 2,
-- EditModeManagerConstantsDocumentation.lua:718-727) not Hidden, and a weapon of the hand (the attack speeds of UnitAttackSpeed, as
-- Blizzard_SwingTimer.lua:172-190). What the game will not say plainly lets the stand-in show.
local function SwingPlays(spec)
	local api = C_CVar
	if type(api) == "table" and type(api.GetCVarBool) == "function" then
		local ok, on = pcall(api.GetCVarBool, "showSwingTimer")
		if ok and not ns.IsSecret(on) and on == false then
			return false
		end
	end
	local frame = rawget(_G, spec.game)
	local visibility = type(frame) == "table" and not ns.Forbidden(frame) and rawget(frame, "visibility") or nil
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.EditModeSwingTimerVisibility
	local hidden = type(enum) == "table" and ns.Finite(enum.Hidden) and enum.Hidden or 2
	if not ns.IsSecret(visibility) and visibility == hidden then
		return false
	end
	if spec.hand == "main" or type(UnitAttackSpeed) ~= "function" then
		return true
	end
	local ok, _, off, ranged = pcall(UnitAttackSpeed, "player")
	local speed = spec.hand == "off" and off or ranged
	if not ok or ns.IsSecret(speed) then
		return true
	end
	return ns.Finite(speed) and speed > 0
end

local function SwingStandIn(spec)
	local function Shows(holder, now)
		local run = ((now + spec.offset) / SWING_PERIOD) % 1
		ns.DrawCasts.SwingProgress(holder.row, run, SWING_PERIOD * (1 - run))
	end
	TM.StandIn({
		id = spec.id,
		module = "swing",
		game = spec.game,
		label = spec.label,
		fit = true,
		gate = function()
			if spec.classes then
				local class = Class()
				if class == nil or spec.classes[class] ~= true then
					return false
				end
			end
			return SwingPlays(spec)
		end,
		Build = function(holder)
			holder.row = ns.DrawCasts.Swing(holder, spec.hand, SWING_PERIOD)
			holder.row.timer:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		end,
		Paint = function(holder, w)
			ns.DrawCasts.PaintSwing(holder.row, w)
			Shows(holder, Now())
		end,
		Animate = function(holder, _, now)
			Shows(holder, now)
		end,
	})
end

-- Debuffs and buffs -----------------------------------------------------------------------------------------------------------------------------

-- True while the player has an aura of the filter, and while the game will not say plainly (in a fight, which pauses test mode anyway), so that no
-- stand-in covers a real aura.
local function HasAura(filter)
	local api = C_UnitAuras
	if type(api) ~= "table" or ns.IsSecret(api) or type(api.GetAuraSlots) ~= "function" or InCombatLockdown() then
		return true
	end
	local ok, _, first = pcall(api.GetAuraSlots, "player", filter, 1)
	if not ok or ns.IsSecret(first) then
		return true
	end
	return first ~= nil
end

-- The time of an aura as the game writes it (SecondsToTimeAbbrev), without the space between number and unit at Duration format Tight, where the
-- locale's form has none (AuraTime.lua, Tight).
local function AuraTime(seconds)
	local fn = _G.SecondsToTimeAbbrev
	if type(fn) ~= "function" then
		return ("%d"):format(seconds)
	end
	local ok, form, number = pcall(fn, seconds)
	if not ok or type(form) ~= "string" then
		return ("%d"):format(seconds)
	end
	local cooldown = _G.COOLDOWN_DURATION_MIN
	if ns.Get("hud.enabled") == true and ns.Get("hud.durationFormat") == "tight" and type(cooldown) == "string" and not cooldown:find("%%d%s") then
		form = form:gsub("(%%d)%s+", "%1")
	end
	local done, text = pcall(string.format, form, number)
	return done and text or ""
end

local function AuraStandIn(id, game, label, list, filter)
	local function Times(holder, now)
		for index, aura in ipairs(list) do
			local left = math.ceil(aura.seconds - (now % aura.seconds))
			local cell = holder.cells[index]
			if cell.left ~= left then
				cell.left = left
				cell.time:SetText(AuraTime(left))
			end
		end
	end
	TM.StandIn({
		id = id,
		module = "hud",
		game = game,
		label = label,
		corner = "TOPRIGHT",
		-- Only into a frame the game shows (its Edit Mode Visibility), and not over Edit Mode's example auras.
		gate = function()
			local frame = rawget(_G, game)
			return type(frame) == "table" and not ns.Forbidden(frame) and ns.MoverShown(frame) == true
		end,
		real = function()
			return EditMode() or HasAura(filter)
		end,
		Build = function(holder)
			local DH = ns.DrawHud
			holder.cells = {}
			local width = #list * AURA_SIZE + (#list - 1) * AURA_GAP
			for index, aura in ipairs(list) do
				-- From the right, as the game lays its auras out.
				local x = width - index * AURA_SIZE - (index - 1) * AURA_GAP
				holder.cells[index] = DH.Aura(holder, x, 0, AURA_SIZE, aura.icon or DH.ICONS[index], aura.kind and DH.DebuffColour(aura.kind) or nil)
			end
		end,
		Paint = function(holder)
			local colour = ns.Get("hud.durationColour")
			local white = ns.Get("hud.enabled") == true and (colour == "white" or colour == "warn")
			for index, aura in ipairs(list) do
				local cell = holder.cells[index]
				ns.DrawHud.PaintAura(cell, aura.kind)
				if white then
					cell.time:SetTextColor(1, 1, 1)
				else
					cell.time:SetTextColor(AURA_GOLD[1], AURA_GOLD[2], AURA_GOLD[3])
				end
				cell.left = nil
			end
			Times(holder, Now())
			return #list * AURA_SIZE + (#list - 1) * AURA_GAP, AURA_TALL
		end,
		Animate = function(holder, _, now)
			Times(holder, now)
		end,
	})
end

-- Loot rolls ------------------------------------------------------------------------------------------------------------------------------------

local function RollShown()
	for index = 1, 4 do
		local frame = _G["GroupLootFrame" .. index]
		if type(frame) == "table" and type(ns.MoverShown) == "function" and ns.MoverShown(frame) == true then
			return true
		end
	end
	return false
end

local function RollTimers(holder, now)
	for index, roll in ipairs(holder.rolls) do
		local run = ((now + (index - 1) * 3) % ROLL_TIME) / ROLL_TIME
		roll.timer:SetValue(100 * (1 - run))
		-- The seconds of a 60 second roll, so the loop shows the count and its red end.
		ns.DrawHud.RollTime(roll, math.max(1, math.ceil(60 * (1 - run))))
	end
end

TM.StandIn({
	id = "loot",
	module = "hud",
	game = "UIParent",
	label = "Loot rolls",
	corner = "BOTTOMLEFT",
	real = RollShown,
	Build = function(holder)
		local DH = ns.DrawHud
		holder.rolls = {}
		for index, item in ipairs(ROLL_ITEMS) do
			holder.rolls[index] = DH.Roll(holder, DH.ICONS[item.icon], item.name, DH.QUALITY[item.quality], ROLL_W)
		end
	end,
	Paint = function(holder)
		-- Down from the top of the box only once a spot is saved: until then the game stacks its rolls up (Hud.lua, ROLL.Place).
		local down = ns.Get("hud.lootRollsGrow") == "down" and type(ns.MoverSaved) == "function" and ns.MoverSaved(ROLL_BOX) == true
		local x, y
		if type(ns.MoverSpot) == "function" then
			x, y = ns.MoverSpot(ROLL_BOX, down and "TOP" or "BOTTOM")
		end
		for index, roll in ipairs(holder.rolls) do
			local frame = roll.roll.frame
			frame:ClearAllPoints()
			if ns.Finite(x) and ns.Finite(y) then
				if down then
					frame:SetPoint("TOP", holder, "BOTTOMLEFT", x, y - ROLL_STEP * (index - 1))
				else
					frame:SetPoint("BOTTOM", holder, "BOTTOMLEFT", x, y + ROLL_STEP * (index - 1))
				end
				ns.DrawHud.PaintRoll(roll)
				frame:Show()
			else
				frame:Hide()
			end
		end
		RollTimers(holder, Now())
		return 1, 1
	end,
	Animate = function(holder, _, now)
		RollTimers(holder, now)
	end,
})

-- Timer bars -------------------------------------------------------------------------------------------------------------------------------------

-- True while one of the game's breath, fatigue or feign death timers shows (MirrorTimerContainer.mirrorTimers, MirrorTimer.xml), Edit Mode's empty
-- bars too; also while the timers cannot be read, so no sample stands over a real one.
local function MirrorShown()
	local container = _G.MirrorTimerContainer
	if type(container) ~= "table" or ns.IsSecret(container) or ns.Forbidden(container) or type(ns.MoverShown) ~= "function" then
		return true
	end
	local timers = container.mirrorTimers
	if type(timers) ~= "table" or ns.IsSecret(timers) then
		return true
	end
	for _, timer in pairs(timers) do
		if type(timer) == "table" and not ns.IsSecret(timer) and ns.MoverShown(timer) == true then
			return true
		end
	end
	return false
end

TM.StandIn({
	id = "mirror",
	module = "hud",
	game = "MirrorTimerContainer",
	label = "Timer bars",
	corner = "TOP",
	real = MirrorShown,
	Build = function(holder)
		holder.mirror = ns.DrawHud.Mirror(holder)
		holder.mirror.frame:SetPoint("TOP", holder, "TOP", 0, 0)
	end,
	Paint = function(holder)
		ns.DrawHud.PaintMirror(holder.mirror)
		ns.DrawHud.MirrorTime(holder.mirror, MIRROR_TIME - Now() % MIRROR_TIME, MIRROR_TIME)
		return 206, 32
	end,
	Animate = function(holder, _, now)
		ns.DrawHud.MirrorTime(holder.mirror, MIRROR_TIME - now % MIRROR_TIME, MIRROR_TIME)
	end,
})

-- The sample nameplate --------------------------------------------------------------------------------------------------------------------------

local function PlateMoves(holder, now)
	local P, p, spec = ns.SetupDrawPlates, holder.plate, holder.spec
	local t = now % PLATE_ROUND
	local run = math.min(1, t / PLATE_CAST)
	P.CastProgress(p, run, PLATE_CAST * (1 - run))
	local threat = THREAT[math.floor(now / THREAT_EVERY) % #THREAT + 1]
	if spec.threat ~= threat then
		spec.threat = threat
		spec.questHave = 3 + math.floor(now / THREAT_EVERY) % 5
		P.Health(p, spec)
		-- The ring, the value and the fade of the new state, and the quest mark again past a value of another width.
		if p.o and p.m then
			P.Threat(p, spec, p.o, p.m)
			P.QuestMark(p, spec, p.o, p.m)
		end
	end
end

TM.StandIn({
	id = "plate",
	module = "nameplates",
	game = "UIParent",
	label = "Sample nameplate",
	corner = "CENTER",
	real = function()
		return false
	end,
	Build = function(holder)
		local P = ns.SetupDrawPlates
		-- still: the sample's Overpower swipe holds still with the rest while Moving is off.
		holder.state = { stage = holder, plates = {}, parts = {}, outlines = {}, still = function() return not TM.Moving() end }
		holder.plate = P.NewPlate(holder.state, holder)
		holder.caption = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
		if holder.caption then
			holder.caption:SetText("Sample nameplate")
			holder.caption:SetTextColor(DIM[1], DIM[2], DIM[3])
		end
		-- A warrior's sample also dodged them, so it carries the Overpower icon.
		holder.spec = { name = "Defias Pillager", level = 18, health = 0.7, auras = { count = 3 }, quest = true, overpower = Class() == "WARRIOR",
			cast = { name = "Shadow Bolt", share = 0, left = PLATE_CAST } }
	end,
	Paint = function(holder)
		local P, p, spec = ns.SetupDrawPlates, holder.plate, holder.spec
		local now = Now()
		local run = math.min(1, (now % PLATE_ROUND) / PLATE_CAST)
		spec.cast.share, spec.cast.left = run, PLATE_CAST * (1 - run)
		spec.threat = THREAT[math.floor(now / THREAT_EVERY) % #THREAT + 1]
		spec.questHave = 3 + math.floor(now / THREAT_EVERY) % 5
		local box = P.Plate(p, spec, P.Sets())
		p.f:ClearAllPoints()
		p.f:SetPoint("BOTTOM", holder, "CENTER", 0, PLATE_UP)
		if holder.caption then
			holder.caption:ClearAllPoints()
			holder.caption:SetPoint("TOP", p.f, "BOTTOM", 0, (box and ns.Finite(box.b) and box.b or 0) - 4)
		end
		return 1, 1
	end,
	Animate = function(holder, _, now)
		PlateMoves(holder, now)
	end,
})

for _, spec in ipairs(CASTS) do
	CastStandIn(spec)
end
for _, spec in ipairs(SWINGS) do
	SwingStandIn(spec)
end
AuraStandIn("debuffs", "DebuffFrame", "Debuffs", DEBUFFS, "HARMFUL")
AuraStandIn("buffs", "BuffFrame", "Buffs", BUFFS, "HELPFUL")

-- The cursor ring ---------------------------------------------------------------------------------------------------------------------------------

local RING_EVERY = 3
local ring = { next = 0 }
local watcher = CreateFrame("Frame")
ns.Own[watcher] = true

local function RingSample(_, elapsed)
	if not (TM.IsOn() and TM.Moving()) or type(ns.CursorRingSample) ~= "function" then
		return
	end
	ring.next = ring.next - (elapsed or 0)
	if ring.next <= 0 then
		ring.next = RING_EVERY
		pcall(ns.CursorRingSample)
	end
end

if type(TM.Watch) == "function" then
	TM.Watch(function(on)
		ring.next = 0
		if type(ns.CursorRingChanged) == "function" then
			pcall(ns.CursorRingChanged)
		end
		watcher:SetScript("OnUpdate", on and RingSample or nil)
	end)
end
