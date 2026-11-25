local _, ns = ...

-- Combat alerts: No target, Low health and Low mana, and +Combat and -Combat in the middle of the screen. The rows are under Your character on
-- the Combat text page (combattext.noTarget and the five rows under it, combattext.lowHealth and lowColour, combattext.combatState and the four
-- rows under it), part "combat alerts" of the module, which stops alone after a few failures. Not a module: CombatText.lua calls
-- ns.CombatCuesRefresh in every refresh of the page, and the events come through the module (ns.AddEvent), so nothing runs while the page is off.
-- No target, Low health and +Combat and -Combat are on by default; nothing is made until a line first shows or Low health and mana warning is on.
-- No target warning: in a fight, from PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED (Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:3885-3895),
-- with no target, a dead one or one the player cannot attack (UnitExists, UnitIsDeadOrGhost and UnitCanAttack, UnitDocumentation.lua:1192-1205, 1931-1944,
-- 763-777), No target shows after a second and stays until a target that can be attacked is taken or the fight ends. With Warn with a friendly
-- target off, a living target that cannot be attacked keeps it away too, and so it does while the player heals: ns.PlayerRole (Core.lua) says
-- healer, from the group role, else the most talent points in a healing tree, else a priest. The role is read only out of a fight (talents may be
-- withheld in one; a withheld answer counts as no healer): at each refresh, as a fight ends, and when the group, its roles or the talents change
-- (GROUP_ROSTER_UPDATE, PLAYER_ROLES_ASSIGNED, PartyInfoDocumentation.lua:680 and 829; PLAYER_TALENT_UPDATE and CHARACTER_POINTS_CHANGED,
-- SpecializationInfoDocumentation.lua:503, PaperDollInfoDocumentation.lua:297). The target is judged again when it changes (PLAYER_TARGET_CHANGED,
-- :3974-3978) and, in a fight, when its health, flags or faction change (UNIT_HEALTH, UNIT_FLAGS and UNIT_FACTION, :4318-4327, 4267-4275 and
-- 4257-4265), which a frame of the addon's own hears for the target alone, and only in a fight. None of these is marked secret, but an answer the
-- game withholds is never compared: the warning stays away until the game says. As it shows, the sound of No target sound (ns.SOUNDS, IconRow.lua)
-- plays, at most every 3 seconds. ns.PlayKit plays no sound within a second of the last it played for any module and keeps none for later
-- (IconRow.lua:12 and 244-249), so a sound it did not play for that is tried again a second later (C_Timer.After, UITimerDocumentation.lua:11-20),
-- for as long as the same No target shows. With Name the key to target an enemy on (the default) and while the player does not heal, No target
-- names the key bound to Target Nearest Enemy, as No target  (Tab) (GetBindingKey of TARGETNEARESTENEMY in the words of GetBindingText), read
-- each time it shows so that a new binding counts; nothing is added with no key bound. A ghost counts as dead, as it does for the game's own Target dead alert and its raid frames
-- (Blizzard_CombatAudioAlerts/Blizzard_CombatAudioAlertManager.lua:661 and 679-681, Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:1097-1098):
-- a party or raid member stays a target on another map too (Blizzard_UnitFrame/Shared/TargetFrame.lua:2-5 and 14), so one who has released
-- can still be the target, and UnitIsDead is false for a ghost (Blizzard_UnitFrame/Mainline/TargetFrame.lua:762-765 tints the two apart).
-- Entering and leaving combat: +Combat as a fight starts and -Combat as it ends, in the words the game's own combat text has for the two
-- (COMBAT_TEXT_ENTERING_COMBAT or ENTERING_COMBAT, and the same for LEAVING_COMBAT: Blizzard_CombatText/Shared/CombatText.lua:99-102 and 284-288),
-- so in the language of the client, for as long as the game shows its own: whole for 1.3 seconds, then fading out until 1.9
-- (CombatTextConstants.lua:4-5). The game shows its own only with Scrolling Combat Text for Self, which Combat text for you turns off. As +Combat
-- or -Combat starts, the sound of Entering combat sound or Leaving combat sound plays (the choices of No target sound, None by default) through
-- ns.PlayKit, so one held back by another module's sound of the second before is not tried again; /flatui status counts those played. With Fight
-- length on -Combat on (the default), -Combat says how long the fight lasted, as -Combat  1:24 (1:02:03 from an hour), from GetTime at
-- PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED; a fight these events did not start here, as after a reload in one, has no length, and /flatui
-- status names the last fight's.
-- Low health and mana warning (on by default): the game's own combat text says Low Health and Low Mana as the player's health or mana falls to
-- 20% (Blizzard_CombatText/Shared/CombatText.lua:61-90, CombatTextConstants.lua:12-13), but only with Scrolling Combat Text for Self, which
-- Combat text for you turns off. Here Low health, and for a mana user Low mana, stand under No target while the share is under 20%, in Low health
-- colour at the size of No target, breathing as it does. The player's health and mana may be withheld in a fight, so they are never compared:
-- each line is on a holder frame of its own whose opacity is UnitHealthPercent or UnitPowerPercent of the player through a step curve, 1 under
-- 20% and 0 from it (C_CurveUtil, as HealthColour.lua's low health border), set at each UNIT_HEALTH, UNIT_MAXHEALTH, UNIT_POWER_UPDATE,
-- UNIT_MAXPOWER and UNIT_DISPLAYPOWER of the player, which a frame of the addon's own hears while the row is on, and at each refresh. Low mana
-- shows only while UnitPowerType is plainly mana (not in a druid's cat or bear form), and both hide while the player is plainly dead or a ghost
-- (PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST). A client that refuses the curve or the call leaves the line off, and /flatui status says so.
-- The two lines are font strings on one frame of the addon's own on UIParent, which takes no mouse, at the spot of Combat text: alerts in the movers:
-- +Combat and -Combat above the middle of the box and No target under it. They are made on the game's combat font (CombatTextFont,
-- Blizzard_Fonts_Shared/Shared/GameFontStyles.xml:150-152), else its large number font (:25), at their own size with a thin outline. A size of
-- 100% is the height of the game's own combat messages, 25 units (CombatTextConstants.lua:6). The fade is stepped by a timer of its own
-- (C_Timer.NewTicker), which runs only while +Combat or -Combat shows. Each line has an animation group of its own (UISharedDocumentation.lua): No
-- target breathes while it shows, its opacity from whole to 0.55 and back every 1.2 seconds (an Alpha animation that bounces), and +Combat and
-- -Combat start a third larger and settle in 0.15 seconds (a Scale animation in Vertex mode, as the scroll areas pop their numbers, ScrollText.lua);
-- a client that will not make them shows the lines still, as before 0.5.35. Nothing shows while the interface is hidden: Alt+Z hides UIParent
-- (Blizzard_FrameXML/Bindings_Camelot.xml:1310-1318), a cinematic is a full screen panel that hides it (Blizzard_UIParentPanelManager/Mainline/
-- UIPanelWindows.lua:42, Shared/UIParentPanelManager.lua:281-283 and 444-446) and a movie hides it (Blizzard_FrameXML/MovieFrame.lua:59-62). Then
-- +Combat and -Combat do not start, a fading one goes, and no sound plays; No target is hidden with UIParent. Nothing of the game is changed.
-- This follows the No Target Indicator and the combat text of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoL/Submodules/GroupTools.lua:913-1064 and Submodules/CombatText.lua:244-256, 431-526): his words, his second of delay and his 3 seconds
-- between sounds, and the colour of No target.
-- While test mode is on (TestMode.lua), +Combat, No target with Low health under it, and -Combat (as -Combat  0:42 while Fight length on
-- -Combat is on) show in turn, two seconds each, while their rows are on, and count in no number of /flatui status (ns.CombatCuesTestStep);
-- +Combat and -Combat play no sound there.
-- Picking a sound in No target sound, Entering combat sound or Leaving combat sound plays it once (ns.CombatCueSoundPicked, the rows' changed
-- handler in Config.lua, so Core.lua calls it for a change made with ns.Set), only while the options window shows (ns.PanelShown) and out of a
-- fight; None plays nothing.

local KEY, PART = "combattext", "combat alerts"
-- The seconds +Combat and -Combat show and the second they start to fade (CombatTextConstants.lua:4-5), the step of the fade, the seconds a target
-- is missing before No target shows and the least seconds between two of its sounds (GroupTools.lua:1018 and 1043-1047 of EnhanceQoL), and the
-- height of a size of 100% (CombatTextConstants.lua:6).
local LIFE, FADE_FROM, STEP, DELAY, SOUND_GAP, HEIGHT = 1.9, 1.3, 0.05, 1, 3, 25
-- The breath of No target: the opacity it dims to and the seconds each way. The pop of +Combat and -Combat: the scale it starts at and the seconds it
-- takes to settle.
local BREATHE_TO, BREATHE_TIME, POP_FROM, POP_TIME = 0.55, 0.6, 1.3, 0.15
-- The box of the movers (Movers.lua): its name and size, the units between its middle and each line, and where it is from the middle of the
-- screen when the movers give no spot.
local MOVER, WIDTH, TALL, GAP, X, Y = "FlatUICombatCues", 200, 60, 2, 0, 100
-- The words of each line: the game's own names for them, in the order its combat text tries them, then the words when the client has neither.
-- Low health and Low mana take the words of the game's own HEALTH_LOW and MANA_LOW messages, in the order it tries them
-- (Blizzard_CombatText/Shared/CombatText.lua:284-288).
local WORDS = { enter = { "COMBAT_TEXT_ENTERING_COMBAT", "ENTERING_COMBAT", "+Combat" }, leave = { "COMBAT_TEXT_LEAVING_COMBAT", "LEAVING_COMBAT", "-Combat" },
	health = { "COMBAT_TEXT_HEALTH_LOW", "HEALTH_LOW", "Low health" }, mana = { "COMBAT_TEXT_MANA_LOW", "MANA_LOW", "Low mana" } }
local NO_TARGET = "No target"
-- The rows of each line's colour and size. Low health and Low mana are the size of No target.
local LOOKS = { enter = { "combatEnterColour", "combatStateSize" }, leave = { "combatLeaveColour", "combatStateSize" }, warn = { "noTargetColour", "noTargetSize" },
	low = { "lowColour", "noTargetSize" } }
-- The share of health or mana under which Low health or Low mana shows (CombatTextConstants.lua:12-13), the mana power type
-- (Enum.PowerType.Mana), the two lines in the order they stand under No target, and the player's events that change them: health, mana, the
-- power type (a druid's form) and death.
local LOW_AT, MANA = 0.2, 0
local LOW_KINDS = { "health", "mana" }
local LOW_UNIT_EVENTS = { UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health", UNIT_POWER_UPDATE = "mana", UNIT_MAXPOWER = "mana", UNIT_DISPLAYPOWER = "mana" }
local LOW_EVENTS = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
-- The places of the No target, Entering combat and Leaving combat sound choices in ns.SOUNDS (IconRow.lua), as EnemyCooldowns.lua has them.
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
-- The seconds after a sound in which ns.PlayKit plays no other (IconRow.lua:12): a No target sound it held back is tried again this long after.
local AGAIN = 1
-- The events of the target heard in a fight.
local TARGET_EVENTS = { "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_FACTION" }

-- frame, flash and warn: the frame and its two lines, once made; file: the font file of the lines; unmade: the game would not make them.
-- flashAt and flashKind: when +Combat or -Combat started, and which. ticker: the token of the fade timer. fighting: between PLAYER_REGEN_DISABLED
-- and PLAYER_REGEN_ENABLED. missingAt: since when the target is missing; waiting: the token of the timer that judges again when the second is up.
-- warned: No target shows. soundAt: when its sound last played. listener and listening: the frame that hears the target, and whether it does.
-- flashes, warnings, withheld and stateSounds (the +Combat and -Combat sounds played): what /flatui status counts. silent: the No target sounds
-- the game has not played since it last played one; /flatui status says so while there are any. blind: the last judgement had an answer the game
-- withheld. healer: the player heals (ns.PlayerRole), read out of a fight. breathe and pop: the animation groups of No target and of the flash line.
-- fightAt: GetTime as this fight started; lastFight: the seconds the last fight lasted. low: the Low health and Low mana lines ({ holder, line,
-- breathe, on } by kind), lowCurve their step curve, lowListener and lowListening the frame that hears the player and whether it does, lowSampled:
-- test mode shows Low health; lowRefused and manaRefused: the game refused the curve or the call.
local S = { fighting = false, warned = false, listening = false, blind = false, healer = false, flashes = 0, warnings = 0, withheld = 0, silent = 0,
	stateSounds = 0 }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function On()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART)
end

local function WarnWanted()
	return On() and Opt("noTarget") == true
end

local function FlashWanted()
	return On() and Opt("combatState") == true
end

local function LowWanted()
	return On() and Opt("lowHealth") == true
end

-- The answer of a client call, or nil when the client lacks it, raises or withholds the answer.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not ns.IsSecret(answer) then
		return answer
	end
	return nil
end

local function Now()
	local now = Ask(GetTime)
	return ns.Finite(now) and now or nil
end

-- Whether the player is in a fight now, for a refresh between the events. A withheld answer counts as out of combat.
local function InFight()
	local fight = Ask(UnitAffectingCombat, "player")
	if type(fight) == "boolean" then
		return fight
	end
	return Ask(InCombatLockdown) == true
end

-- True while the interface shows. Only the read-only IsShown of UIParent is called.
local function InterfaceShown()
	if UIParent == nil or ns.Forbidden(UIParent) then
		return false
	end
	return Ask(UIParent.IsShown, UIParent) == true
end

-- A plain text global of the game's, or nil.
local function Global(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and not ns.IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function Words(kind)
	local words = WORDS[kind]
	return Global(words[1]) or Global(words[2]) or words[3]
end

-- The font object the lines are made on: the game's combat font where the client has it, else its large number font.
local function Template()
	local ok, font = pcall(function()
		return _G.CombatTextFont
	end)
	if ok and not ns.IsSecret(font) and type(font) == "table" then
		return "CombatTextFont"
	end
	return "NumberFontNormalHuge"
end

-- The breath of No target: an Alpha animation from whole to BREATHE_TO and back, looping while it plays. Nil when the client will not make it.
local function Breathe(line)
	local ok, group = pcall(function()
		local made = line:CreateAnimationGroup()
		made:SetLooping("BOUNCE")
		local fade = made:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(BREATHE_TO)
		fade:SetDuration(BREATHE_TIME)
		pcall(fade.SetSmoothing, fade, "IN_OUT")
		return made
	end)
	return ok and not ns.IsSecret(group) and type(group) == "table" and group or nil
end

-- The pop of +Combat and -Combat: a Scale animation in Vertex mode (UISharedDocumentation.lua:6-15), from POP_FROM down to whole, grown from the
-- middle of the centred line. Nil when the client will not make it.
local function Pop(line)
	local ok, group = pcall(function()
		line:SetScaleAnimationMode(Enum and Enum.FontStringScaleAnimationMode and Enum.FontStringScaleAnimationMode.Vertex or 1)
		local made = line:CreateAnimationGroup()
		local scale = made:CreateAnimation("Scale")
		scale:SetScaleFrom(POP_FROM, POP_FROM)
		scale:SetScaleTo(1, 1)
		scale:SetDuration(POP_TIME)
		scale:SetOrigin("CENTER", 0, 0)
		return made
	end)
	return ok and not ns.IsSecret(group) and type(group) == "table" and group or nil
end

-- Plays or stops an animation group of the lines, if it was made.
local function Animate(group, play)
	if group then
		pcall(group.Stop, group)
		if play then
			pcall(group.Play, group)
		end
	end
end

-- Makes the frame and its two lines, once. False when the game would not make them: no line shows then, and status says so.
local function Make()
	if S.frame then
		return true
	elseif S.unmade or type(CreateFrame) ~= "function" or UIParent == nil then
		return false
	end
	local made, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not made or ns.IsSecret(frame) or type(frame) ~= "table" then
		S.unmade = true
		return false
	end
	ns.Own[frame] = true
	pcall(frame.SetSize, frame, WIDTH, TALL)
	pcall(frame.SetFrameStrata, frame, "HIGH")
	pcall(frame.EnableMouse, frame, false)
	local template = Template()
	local flash, warn = ns.OwnText(frame, "OVERLAY", template), ns.OwnText(frame, "OVERLAY", template)
	if not (flash and warn) then
		pcall(frame.Hide, frame)
		S.unmade = true
		return false
	end
	pcall(flash.SetPoint, flash, "BOTTOM", frame, "CENTER", 0, GAP)
	pcall(warn.SetPoint, warn, "TOP", frame, "CENTER", 0, -GAP)
	for _, line in ipairs({ flash, warn }) do
		pcall(line.SetJustifyH, line, "CENTER")
		pcall(line.Hide, line)
	end
	-- The file of the font, read once from a line of the addon's own, so that a line is drawn at its size and not scaled up from the font's.
	local read, file = pcall(flash.GetFont, flash)
	if read and not ns.IsSecret(file) and type(file) == "string" and file ~= "" then
		S.file = file
	end
	S.frame, S.flash, S.warn = frame, flash, warn
	S.breathe, S.pop = Breathe(warn), Pop(flash)
	return true
end

-- Hangs the frame at the spot of the movers, read each time, so that a new spot or another size of the screen counts.
local function Place()
	local frame = S.frame
	if not frame then
		return
	end
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "CENTER")
	end
	frame:ClearAllPoints()
	if ns.Finite(x) and ns.Finite(y) then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", X, Y)
	end
end

-- The colour and size of a line, from its rows. A font the game does not set (SetFont raises or says false) is scaled to the height instead.
local function Look(line, kind)
	local rows = LOOKS[kind]
	local height = HEIGHT * (Opt(rows[2]) or 100) / 100
	local set, result = false, nil
	if S.file then
		set, result = pcall(line.SetFont, line, S.file, height, "OUTLINE")
	end
	if not set or result == false then
		pcall(line.SetTextHeight, line, height)
	end
	pcall(line.SetTextColor, line, ns.Colour(KEY .. "." .. rows[1]))
end

-- The frame shows while one of its lines does, and while Low health and mana warning is on: the opacity of each of those lines' holders says
-- whether it shows.
local function Shown()
	if S.frame then
		pcall(S.frame.SetShown, S.frame, S.flashAt ~= nil or S.warned or (S.low ~= nil and LowWanted()))
	end
end

local function StopTicker()
	local token = S.ticker
	S.ticker = nil
	if token and token.handle and type(token.handle.Cancel) == "function" then
		pcall(token.handle.Cancel, token.handle)
	end
end

local function EndFlash()
	StopTicker()
	S.flashAt, S.flashKind = nil, nil
	Animate(S.pop, false)
	if S.flash then
		pcall(S.flash.Hide, S.flash)
		pcall(S.flash.SetAlpha, S.flash, 1)
	end
	Shown()
end

-- One step of the fade: whole until FADE_FROM, then down to nothing at LIFE. It ends with the line, or at once while the interface is hidden.
local function Step()
	local now, at = Now(), S.flashAt
	if not (S.flash and at and now) or now < at or now - at >= LIFE or not InterfaceShown() then
		EndFlash()
		return
	end
	local t = now - at
	local alpha = t <= FADE_FROM and 1 or math.max(0, math.min(1, 1 - (t - FADE_FROM) / (LIFE - FADE_FROM)))
	S.flash:SetAlpha(alpha)
end

local Run

-- Starts the fade timer. A client without NewTicker gets a timer that sets the next while the token is the ticker (DataPanels.lua does the same);
-- with no timer at all the line goes at the next refresh or edge of a fight.
local function StartTicker()
	if S.ticker then
		return
	end
	local token = {}
	S.ticker = token
	if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
		local ok, handle = pcall(C_Timer.NewTicker, STEP, function()
			if S.ticker == token then
				Run(Step)
			end
		end)
		token.handle = ok and not ns.IsSecret(handle) and handle or nil
	end
	if token.handle then
		return
	end
	local function Later(fn)
		return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, STEP, fn)
	end
	local function Again()
		if S.ticker == token then
			Run(Step)
			if S.ticker == token and not Later(Again) then
				S.ticker = nil
			end
		end
	end
	if not Later(Again) then
		S.ticker = nil
	end
end

-- The length of a fight in seconds, as 1:24, or 1:02:03 from an hour.
local function Length(seconds)
	local whole = math.floor(seconds + 0.5)
	local hours, minutes, rest = math.floor(whole / 3600), math.floor(whole % 3600 / 60), whole % 60
	if hours > 0 then
		return ("%d:%02d:%02d"):format(hours, minutes, rest)
	end
	return ("%d:%02d"):format(minutes, rest)
end

-- +Combat or -Combat for a moment, with its sound unless quiet (test mode), and extra after the words when given (the fight's length).
local function Flash(kind, quiet, extra)
	if not FlashWanted() or not InterfaceShown() then
		return
	end
	local now = Now()
	if not now or not Make() then
		return
	end
	local line = S.flash
	line:SetText(extra and (Words(kind) .. "  " .. extra) or Words(kind))
	Look(line, kind)
	line:SetAlpha(1)
	line:Show()
	Animate(S.pop, true)
	S.flashAt, S.flashKind = now, kind
	S.flashes = S.flashes + 1
	Place()
	Shown()
	StartTicker()
	local sound = not quiet and ns.SOUNDS and ns.SOUNDS[KITS[Opt(kind == "enter" and "combatEnterSound" or "combatLeaveSound")] or 0]
	if sound and ns.PlayKit(sound[1]) then
		S.stateSounds = S.stateSounds + 1
	end
end

local function HideWarning()
	S.missingAt, S.waiting = nil, nil
	if S.warned then
		S.warned = false
		Animate(S.breathe, false)
		if S.warn then
			pcall(S.warn.Hide, S.warn)
			pcall(S.warn.SetAlpha, S.warn, 1)
		end
		Shown()
	end
end

-- The sound of No target sound, at most every SOUND_GAP seconds, and none while the interface is hidden. A sound the game does not play is counted
-- for the status. One that ns.PlayKit held back, as it played a sound of another module less than a second before, is not: it is tried again AGAIN
-- seconds later while the same No target shows (S.warnings counts each one shown), and S.soundAt is set only when one plays. A sound the game plays
-- clears the count, so the status is about the last try. PlaySound says whether it played (success, Blizzard_APIDocumentationGenerated/
-- SoundDocumentation.lua:52-71), and the player can turn the sound off and on again in a session: the Toggle Sound key turns sound effects off and
-- on (Blizzard_FrameXML/Bindings_Camelot.xml:1301-1303, Blizzard_SharedXML/Mainline/Sound.lua:19-35), which the game's own code counts as muting a
-- PlaySound on the default channel, as ns.PlayKit's is (Blizzard_CustomizationUI/Blizzard_CustomizationAudioInterface.lua:1-3 and 35-44), and
-- Enable Sound turns all sound off and on (Blizzard_SettingsDefinitions_Shared/Audio.lua:496).
local function Sound()
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[Opt("noTargetSound")] or 0]
	local now = Now()
	if not sound or not now or (S.soundAt and now >= S.soundAt and now - S.soundAt < SOUND_GAP) or not InterfaceShown() then
		return
	end
	if ns.PlayKit(sound[1]) then
		S.soundAt, S.silent = now, 0
	elseif not (ns.IconRow and ns.IconRow.sound == "throttled") then
		S.silent = S.silent + 1
	elseif type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		local shown = S.warnings
		pcall(C_Timer.After, AGAIN, function()
			if S.warned and S.warnings == shown then
				Run(Sound)
			end
		end)
	end
end

-- No target, with the key bound to Target Nearest Enemy after it while Name the key to target an enemy is on and the player does not heal, read
-- each time so that a new binding counts (GetBindingKey and GetBindingText, the key in the words of the client). Only a plain string is taken.
local function WarnText()
	if Opt("noTargetKey") ~= true or S.healer then
		return NO_TARGET
	end
	local key = Ask(GetBindingKey, "TARGETNEARESTENEMY")
	if type(key) ~= "string" or key == "" then
		return NO_TARGET
	end
	local words = Ask(GetBindingText, key)
	return NO_TARGET .. "  (" .. ((type(words) == "string" and words ~= "") and words or key) .. ")"
end

local function ShowWarning()
	if S.warned or not Make() then
		return
	end
	local line = S.warn
	line:SetText(WarnText())
	Look(line, "warn")
	line:Show()
	Animate(S.breathe, true)
	S.warned = true
	S.warnings = S.warnings + 1
	Place()
	Shown()
	Sound()
end

-- Low health and Low mana --------------------------------------------------------------------------------------------------------------

-- The step curve of both lines: 1 under LOW_AT, 0 from it (C_CurveUtil, as HealthColour.lua makes its low health border's). Made once; a client
-- that will not make it leaves both lines off, and the status says so.
local function LowCurve()
	if S.lowCurve == nil and not S.lowRefused then
		local ok, curve = pcall(function()
			local made = C_CurveUtil.CreateCurve()
			made:SetType(Enum.LuaCurveType.Step)
			made:AddPoint(0, 1)
			made:AddPoint(LOW_AT, 0)
			return made
		end)
		if ok and curve ~= nil and not ns.IsSecret(curve) then
			S.lowCurve = curve
		else
			S.lowRefused = true
		end
	end
	return S.lowCurve
end

-- Makes the two lines under No target, once: each a font string on a holder frame of its own on the frame of the lines, so that the holder's
-- opacity says whether it shows while the line breathes as No target does. False when the game would not make them.
local function MakeLow()
	if S.low then
		return true
	elseif S.lowRefused or not Make() then
		return false
	end
	local low = {}
	for _, kind in ipairs(LOW_KINDS) do
		local made, holder = pcall(CreateFrame, "Frame", nil, S.frame)
		local line = made and not ns.IsSecret(holder) and type(holder) == "table" and ns.OwnText(holder, "OVERLAY", Template()) or nil
		if not line then
			S.lowRefused = true
			return false
		end
		ns.Own[holder] = true
		pcall(holder.SetAllPoints, holder, S.frame)
		pcall(holder.EnableMouse, holder, false)
		pcall(holder.Hide, holder)
		pcall(line.SetJustifyH, line, "CENTER")
		low[kind] = { holder = holder, line = line, breathe = Breathe(line) }
	end
	S.low = low
	return true
end

-- The words, look and spot of the two lines: under the spot of No target, a line of its size apart, read each time so a new size counts.
local function LookLow()
	if not S.low then
		return
	end
	local step = HEIGHT * (Opt("noTargetSize") or 100) / 100 + GAP
	for index, kind in ipairs(LOW_KINDS) do
		local line = S.low[kind].line
		line:SetText(Words(kind))
		Look(line, "low")
		line:ClearAllPoints()
		line:SetPoint("TOP", S.frame, "CENTER", 0, -GAP - step * index)
	end
end

-- Shows or hides one line's holder, its breath playing while it shows.
local function ShowLow(rec, on)
	if rec.on == on then
		return
	end
	rec.on = on
	pcall(rec.holder.SetShown, rec.holder, on)
	Animate(rec.breathe, on)
	if not on then
		pcall(rec.line.SetAlpha, rec.line, 1)
	end
end

-- The share through the curve goes as it is to SetAlpha, withheld or not: health and mana are never compared here.
local function HealthAlpha(holder, curve)
	holder:SetAlpha(UnitHealthPercent("player", true, curve))
end

local function ManaAlpha(holder, curve)
	holder:SetAlpha(UnitPowerPercent("player", MANA, false, curve))
end

-- One line: its holder's opacity from the player's health or mana, the line hidden while the row is off, the player is plainly dead or a ghost, and
-- for mana while the power is not plainly mana. A refusal of the game leaves that line off and is noted for the status.
local function PaintLow(kind)
	local rec = S.low and S.low[kind]
	if not rec or S.lowSampled then
		return
	end
	local curve = LowWanted() and not S.lowRefused and Ask(UnitIsDeadOrGhost, "player") ~= true and LowCurve()
	local on = false
	if curve and kind == "health" then
		on = pcall(HealthAlpha, rec.holder, curve)
		S.lowRefused = not on
		if not on then
			ShowLow(S.low.mana, false)
		end
	elseif curve and not S.manaRefused and Ask(UnitPowerType, "player") == MANA then
		on = pcall(ManaAlpha, rec.holder, curve)
		S.manaRefused = not on
	end
	ShowLow(rec, on)
end

local function PaintHealth()
	PaintLow("health")
end

local function PaintMana()
	PaintLow("mana")
end

local function PaintBoth()
	PaintLow("health")
	PaintLow("mana")
end

local function OnPlayerEvent(_, event, unit)
	local kind = LOW_UNIT_EVENTS[event]
	if kind == nil then
		Run(PaintBoth)
	elseif not ns.IsSecret(unit) and unit == "player" then
		Run(kind == "health" and PaintHealth or PaintMana)
	end
end

-- Hears the player's health, mana, power type and death while the row is on: for the player alone where the client can, else for every unit, and
-- OnPlayerEvent keeps the player's.
local function ListenLow(on)
	if on and not S.lowListening then
		if not S.lowListener then
			local made, frame = pcall(CreateFrame, "Frame")
			if not made or ns.IsSecret(frame) or type(frame) ~= "table" then
				return
			end
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnPlayerEvent)
			S.lowListener = frame
		end
		local frame = S.lowListener
		for event in pairs(LOW_UNIT_EVENTS) do
			local done = false
			if frame.RegisterUnitEvent then
				local ok, result = pcall(frame.RegisterUnitEvent, frame, event, "player")
				done = ok and (ns.IsSecret(result) or result ~= false)
			end
			if not done then
				pcall(frame.RegisterEvent, frame, event)
			end
		end
		for _, event in ipairs(LOW_EVENTS) do
			pcall(frame.RegisterEvent, frame, event)
		end
		S.lowListening = true
	elseif not on and S.lowListening then
		pcall(S.lowListener.UnregisterAllEvents, S.lowListener)
		S.lowListening = false
	end
end

-- Both lines hidden and the events no longer heard.
local function HideLow()
	ListenLow(false)
	S.lowSampled = nil
	if S.low then
		for _, kind in ipairs(LOW_KINDS) do
			ShowLow(S.low[kind], false)
		end
	end
	Shown()
end

-- A refresh of the two lines: made, looked and painted while the row is on, else hidden.
local function ApplyLow()
	if LowWanted() and MakeLow() then
		LookLow()
		ListenLow(true)
		PaintBoth()
		Place()
		Shown()
	else
		HideLow()
	end
end

-- Whether the player heals, from ns.PlayerRole, read only out of a fight: in one the last answer stays. A withheld answer counts as no healer.
local function ReadRole()
	if Ask(InCombatLockdown) == true or type(ns.PlayerRole) ~= "function" then
		return
	end
	local ok, role = pcall(ns.PlayerRole)
	S.healer = ok and not ns.IsSecret(role) and role == "healer"
end

-- True when the player has nothing to fight: no target, a dead one or a ghost, or one that cannot be attacked while Warn with a friendly target
-- is on and the player does not heal. Nil while the game withholds an answer.
local function Missing()
	local exists = Ask(UnitExists, "target")
	if type(exists) ~= "boolean" then
		return nil
	elseif not exists then
		return true
	end
	local dead = Ask(UnitIsDeadOrGhost, "target")
	if type(dead) ~= "boolean" then
		return nil
	elseif dead then
		return true
	end
	local attack = Ask(UnitCanAttack, "player", "target")
	if type(attack) ~= "boolean" then
		return nil
	end
	return not attack and Opt("noTargetFriendly") == true and not S.healer
end

local Wait

local function Judge()
	if not (WarnWanted() and S.fighting) then
		HideWarning()
		return
	end
	local missing = Missing()
	if missing == nil then
		if not S.blind then
			S.blind, S.withheld = true, S.withheld + 1
		end
		HideWarning()
		return
	end
	S.blind = false
	if not missing then
		HideWarning()
		return
	elseif S.warned then
		return
	end
	local now = Now()
	if not now then
		return
	end
	if not S.missingAt or now < S.missingAt then
		S.missingAt = now
	end
	local left = DELAY - (now - S.missingAt)
	if left > 0 then
		Wait(left)
		return
	end
	ShowWarning()
end

-- Judges again once the second is up. A later judgement that finds a target forgets the wait, and the timer then does nothing.
Wait = function(left)
	if S.waiting or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	local token = {}
	S.waiting = token
	if not pcall(C_Timer.After, left, function()
		if S.waiting == token then
			S.waiting = nil
			Run(Judge)
		end
	end) then
		S.waiting = nil
	end
end

local function OnTargetEvent(_, _, unit)
	if not ns.IsSecret(unit) and unit == "target" then
		Run(Judge)
	end
end

-- Hears the target's health, flags and faction while on: for the target alone where the client can (CombatText.lua does the same for the player),
-- else for every unit, and OnTargetEvent keeps the target's.
local function Listen(on)
	if on and not S.listening then
		if not S.listener then
			local made, frame = pcall(CreateFrame, "Frame")
			if not made or ns.IsSecret(frame) or type(frame) ~= "table" then
				return
			end
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnTargetEvent)
			S.listener = frame
		end
		local frame = S.listener
		for _, event in ipairs(TARGET_EVENTS) do
			local done = false
			if frame.RegisterUnitEvent then
				local ok, result = pcall(frame.RegisterUnitEvent, frame, event, "target")
				-- RegisterUnitEvent has no documented return: only an error or false counts as a refusal.
				done = ok and (ns.IsSecret(result) or result ~= false)
			end
			if not done then
				pcall(frame.RegisterEvent, frame, event)
			end
		end
		S.listening = true
	elseif not on and S.listening then
		for _, event in ipairs(TARGET_EVENTS) do
			pcall(S.listener.UnregisterEvent, S.listener, event)
		end
		S.listening = false
	end
end

local function HideAll()
	EndFlash()
	HideWarning()
	Listen(false)
	HideLow()
	S.fightAt = nil
end

-- Runs the part. Each run has a key of its own, so every failure counts toward stopping the part; a stopped part takes its lines away.
Run = function(fn)
	if ns.PartStopped(KEY, PART) then
		return
	end
	if not ns.EachPart(KEY, PART, fn, {}) and ns.PartStopped(KEY, PART) then
		pcall(HideAll)
	end
end

-- A refresh: a changed row, the page, the profile, the module stopped. Nothing is read of the game while both rows are off.
local function Apply()
	local flash, warn = FlashWanted(), WarnWanted()
	if flash or warn then
		S.fighting = InFight()
		-- A fight the events did not start here (a reload in one) has no known length.
		if not S.fighting then
			S.fightAt = nil
		end
	end
	if warn then
		ReadRole()
	end
	if not flash then
		EndFlash()
	end
	Listen(warn and S.fighting)
	if S.frame then
		Place()
		if S.flashAt and S.flashKind then
			Look(S.flash, S.flashKind)
		end
		if S.warned then
			Look(S.warn, "warn")
		end
	end
	ApplyLow()
	Judge()
end

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	S.fighting = true
	S.fightAt = Now()
	if FlashWanted() or WarnWanted() then
		Run(function()
			Flash("enter")
			Listen(WarnWanted())
			Judge()
		end)
	end
end)

ns.AddEvent(KEY, "PLAYER_REGEN_ENABLED", function()
	S.fighting = false
	local now, at = Now(), S.fightAt
	S.fightAt = nil
	local length = now and at and now >= at and now - at or nil
	if length then
		S.lastFight = length
	end
	if WarnWanted() then
		Run(ReadRole)
	end
	if FlashWanted() or S.warned or S.listening or S.waiting then
		Run(function()
			Listen(false)
			Judge()
			Flash("leave", nil, length and Opt("combatLength") == true and Length(length) or nil)
		end)
	end
end)

-- The group, its roles and the talents say whether the player heals.
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }) do
	ns.AddEvent(KEY, event, function()
		if WarnWanted() then
			Run(ReadRole)
		end
	end)
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if S.fighting and WarnWanted() then
		Run(Judge)
	end
end)

ns.AddStatus(KEY, function()
	local lines = {}
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not (Opt("noTarget") or Opt("combatState") or Opt("lowHealth")) then
		return lines
	end
	if S.unmade then
		lines[1] = "Combat alerts: the game would not make their text, so none shows."
		return lines
	end
	if Opt("noTarget") then
		if S.withheld > 0 then
			lines[#lines + 1] = ("No target warning: %d shown, %d left out while the game withheld your target."):format(S.warnings, S.withheld)
		else
			lines[#lines + 1] = ("No target warning: %d shown."):format(S.warnings)
		end
		if S.silent > 0 and KITS[Opt("noTargetSound")] then
			lines[#lines + 1] = "No target sound: the game played no sound, so the warning is silent."
		end
		if S.healer and Opt("noTargetFriendly") == true then
			lines[#lines + 1] = "No target warning: friendly targets count while you heal."
		end
	end
	if Opt("combatState") then
		local last = S.lastFight and (" Last fight %s."):format(Length(S.lastFight)) or ""
		if KITS[Opt("combatEnterSound")] or KITS[Opt("combatLeaveSound")] then
			lines[#lines + 1] = ("Entering and leaving combat: %d shown, %d sounds played.%s"):format(S.flashes, S.stateSounds, last)
		else
			lines[#lines + 1] = ("Entering and leaving combat: %d shown.%s"):format(S.flashes, last)
		end
	end
	if Opt("lowHealth") then
		if S.lowRefused then
			lines[#lines + 1] = "Low health warning: the game would not give your health through a curve, so neither Low health nor Low mana shows."
		elseif S.manaRefused then
			lines[#lines + 1] = "Low mana warning: the game would not give your mana through a curve, so Low mana does not show."
		end
	end
	return lines
end)

-- CombatText.lua calls this at the end of every refresh of the page.
function ns.CombatCuesRefresh()
	Run(Apply)
	if ns.PartStopped(KEY, PART) or not ns.Enabled(KEY) then
		pcall(HideAll)
	end
end

-- Test mode (TestMode.lua): +Combat, No target and -Combat in turn, two seconds each, so one round every six seconds, each while its row is on and
-- in the look of its rows. Its No target is a sample (S.sampled): it goes at the next step, and its sound plays the first time only (TM.Sound).
-- S.testStep counts the steps. The counts of /flatui status are put back. The fight pauses test mode, and a real fight's lines are left alone.
local function HideSample()
	if S.sampled then
		S.sampled = nil
		if not S.fighting then
			HideWarning()
		end
	end
	if S.lowSampled then
		S.lowSampled = nil
		PaintLow("health")
	end
end

function ns.CombatCuesTestStep()
	if S.fighting then
		return
	end
	Run(function()
		local flashes, warnings = S.flashes, S.warnings
		S.testStep = (S.testStep or -1) + 1
		local phase = S.testStep % 3
		HideSample()
		if phase ~= 1 then
			Flash(phase == 0 and "enter" or "leave", true, phase == 2 and Opt("combatLength") == true and "0:42" or nil)
		elseif InterfaceShown() then
			if WarnWanted() and Make() then
				local line = S.warn
				line:SetText(WarnText())
				Look(line, "warn")
				line:Show()
				Animate(S.breathe, true)
				S.warned, S.sampled = true, true
				Place()
				Shown()
				local mode = ns.TestMode
				if mode and mode.Sound("combatcues") then
					Sound()
				end
			end
			-- Low health, whole, under the sample No target, until the next step paints it again.
			if LowWanted() and MakeLow() then
				local rec = S.low.health
				LookLow()
				ShowLow(rec, true)
				pcall(rec.holder.SetAlpha, rec.holder, 1)
				S.lowSampled = true
				Place()
				Shown()
			end
		end
		S.flashes, S.warnings = flashes, warnings
	end)
end

function ns.CombatCuesTestEnd()
	S.testStep = nil
	Run(function()
		HideSample()
		if not S.fighting then
			EndFlash()
		end
	end)
end

if ns.TestMode then
	ns.TestMode.Register("combatcues", {
		module = KEY,
		label = "Combat alerts",
		every = 2,
		Start = ns.CombatCuesTestStep,
		Tick = ns.CombatCuesTestStep,
		Stop = ns.CombatCuesTestEnd,
	})
end

-- True while one of the alerts is on, which is when the movers have a handle for where they show.
function ns.CombatCuesShown()
	return ns.Enabled(KEY) and (Opt("noTarget") == true or Opt("combatState") == true or Opt("lowHealth") == true)
end

-- The movers set or put back the spot.
function ns.CombatCuesMoved()
	if S.frame then
		Run(Place)
	end
end

-- Picking a sound in the options window plays it once, so it can be chosen by ear: the changed handler of No target sound, Entering combat sound
-- and Leaving combat sound (Config.lua). Only while the options window shows and out of a fight; None plays nothing.
function ns.CombatCueSoundPicked(path)
	if type(path) ~= "string" or Ask(InCombatLockdown) == true or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	local kit = KITS[ns.Get(path)]
	local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
	if sound and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	end
end
