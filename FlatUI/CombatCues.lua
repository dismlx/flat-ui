local _, ns = ...

-- Combat alerts: No target and +Combat and -Combat in the middle of the screen. The rows are under Your character on the Combat text page
-- (combattext.noTarget and the four rows under it, combattext.combatState and the three under it), part "combat alerts" of the module, which
-- stops alone after a few failures. Not a module: CombatText.lua calls ns.CombatCuesRefresh in every refresh of the page, and the events come
-- through the module (ns.AddEvent), so nothing runs while the page is off. Both rows are off by default and nothing is made until a line first shows.
-- No target warning: in a fight, from PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED (Blizzard_APIDocumentationGenerated/UnitDocumentation.lua:3885-3895),
-- with no target, a dead one or one the player cannot attack (UnitExists, UnitIsDead and UnitCanAttack, UnitDocumentation.lua:1192-1205, 1916-1929,
-- 763-777), No target shows after a second and stays until a target that can be attacked is taken or the fight ends. With Warn with a friendly
-- target off, a living target that cannot be attacked keeps it away too. The target is judged again when it changes (PLAYER_TARGET_CHANGED,
-- :3974-3978) and, in a fight, when its health, flags or faction change (UNIT_HEALTH, UNIT_FLAGS and UNIT_FACTION, :4318-4327, 4267-4275 and
-- 4257-4265), which a frame of the addon's own hears for the target alone, and only in a fight. None of these is marked secret, but an answer the
-- game withholds is never compared: the warning stays away until the game says. As it shows, the sound of No target sound (ns.SOUNDS, IconRow.lua)
-- plays, at most every 3 seconds.
-- Entering and leaving combat: +Combat as a fight starts and -Combat as it ends, in the words the game's own combat text has for the two
-- (COMBAT_TEXT_ENTERING_COMBAT or ENTERING_COMBAT, and the same for LEAVING_COMBAT: Blizzard_CombatText/Shared/CombatText.lua:99-102 and 284-288),
-- so in the language of the client, for as long as the game shows its own: whole for 1.3 seconds, then fading out until 1.9
-- (CombatTextConstants.lua:4-5). The game shows its own only with Scrolling Combat Text for Self, which Combat text for you turns off.
-- The two lines are font strings on one frame of the addon's own on UIParent, which takes no mouse, at the spot of Combat text: alerts in the movers:
-- +Combat and -Combat above the middle of the box and No target under it. They are made on the game's combat font (CombatTextFont,
-- Blizzard_Fonts_Shared/Shared/GameFontStyles.xml:150-152), else its large number font (:25), at their own size with a thin outline. A size of
-- 100% is the height of the game's own combat messages, 25 units (CombatTextConstants.lua:6). The fade is stepped by a timer of its own
-- (C_Timer.NewTicker), which runs only while +Combat or -Combat shows. Nothing shows while the interface is hidden: Alt+Z hides UIParent
-- (Blizzard_FrameXML/Bindings_Camelot.xml:1310-1318), a cinematic is a full screen panel that hides it (Blizzard_UIParentPanelManager/Mainline/
-- UIPanelWindows.lua:42, Shared/UIParentPanelManager.lua:281-283 and 444-446) and a movie hides it (Blizzard_FrameXML/MovieFrame.lua:59-62). Then
-- +Combat and -Combat do not start, a fading one goes, and no sound plays; No target is hidden with UIParent. Nothing of the game is changed.
-- This follows the No Target Indicator and the combat text of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission
-- (EnhanceQoL/Submodules/GroupTools.lua:913-1064 and Submodules/CombatText.lua:244-256, 431-526): his words, his second of delay and his 3 seconds
-- between sounds, and the colour of No target.

local KEY, PART = "combattext", "combat alerts"
-- The seconds +Combat and -Combat show and the second they start to fade (CombatTextConstants.lua:4-5), the step of the fade, the seconds a target
-- is missing before No target shows and the least seconds between two of its sounds (GroupTools.lua:1018 and 1043-1047 of EnhanceQoL), and the
-- height of a size of 100% (CombatTextConstants.lua:6).
local LIFE, FADE_FROM, STEP, DELAY, SOUND_GAP, HEIGHT = 1.9, 1.3, 0.05, 1, 3, 25
-- The box of the movers (Movers.lua): its name and size, the units between its middle and each line, and where it is from the middle of the
-- screen when the movers give no spot.
local MOVER, WIDTH, TALL, GAP, X, Y = "FlatUICombatCues", 200, 60, 2, 0, 100
-- The words of each line: the game's own names for them, in the order its combat text tries them, then the words when the client has neither.
local WORDS = { enter = { "COMBAT_TEXT_ENTERING_COMBAT", "ENTERING_COMBAT", "+Combat" }, leave = { "COMBAT_TEXT_LEAVING_COMBAT", "LEAVING_COMBAT", "-Combat" } }
local NO_TARGET = "No target"
-- The rows of each line's colour and size.
local LOOKS = { enter = { "combatEnterColour", "combatStateSize" }, leave = { "combatLeaveColour", "combatStateSize" }, warn = { "noTargetColour", "noTargetSize" } }
-- The places of the No target sound choices in ns.SOUNDS (IconRow.lua), as EnemyCooldowns.lua has them.
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
-- The events of the target heard in a fight.
local TARGET_EVENTS = { "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_FACTION" }

-- frame, flash and warn: the frame and its two lines, once made; file: the font file of the lines; unmade: the game would not make them.
-- flashAt and flashKind: when +Combat or -Combat started, and which. ticker: the token of the fade timer. fighting: between PLAYER_REGEN_DISABLED
-- and PLAYER_REGEN_ENABLED. missingAt: since when the target is missing; waiting: the token of the timer that judges again when the second is up.
-- warned: No target shows. soundAt: when its sound last played. listener and listening: the frame that hears the target, and whether it does.
-- flashes, warnings, withheld and silent: what /flatui status counts. blind: the last judgement had an answer the game withheld.
local S = { fighting = false, warned = false, listening = false, blind = false, flashes = 0, warnings = 0, withheld = 0, silent = 0 }

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

-- The frame shows while one of its lines does.
local function Shown()
	if S.frame then
		pcall(S.frame.SetShown, S.frame, S.flashAt ~= nil or S.warned)
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

-- +Combat or -Combat for a moment.
local function Flash(kind)
	if not FlashWanted() or not InterfaceShown() then
		return
	end
	local now = Now()
	if not now or not Make() then
		return
	end
	local line = S.flash
	line:SetText(Words(kind))
	Look(line, kind)
	line:SetAlpha(1)
	line:Show()
	S.flashAt, S.flashKind = now, kind
	S.flashes = S.flashes + 1
	Place()
	Shown()
	StartTicker()
end

local function HideWarning()
	S.missingAt, S.waiting = nil, nil
	if S.warned then
		S.warned = false
		if S.warn then
			pcall(S.warn.Hide, S.warn)
		end
		Shown()
	end
end

-- The sound of No target sound, at most every SOUND_GAP seconds, and none while the interface is hidden. A sound the game does not play is
-- counted for the status; one that waits for another sound of the addon's (ns.PlayKit plays one a second) is not.
local function Sound()
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[Opt("noTargetSound")] or 0]
	local now = Now()
	if not sound or not now or (S.soundAt and now >= S.soundAt and now - S.soundAt < SOUND_GAP) or not InterfaceShown() then
		return
	end
	if ns.PlayKit(sound[1]) then
		S.soundAt = now
	elseif not (ns.IconRow and ns.IconRow.sound == "throttled") then
		S.silent = S.silent + 1
	end
end

local function ShowWarning()
	if S.warned or not Make() then
		return
	end
	local line = S.warn
	line:SetText(NO_TARGET)
	Look(line, "warn")
	line:Show()
	S.warned = true
	S.warnings = S.warnings + 1
	Place()
	Shown()
	Sound()
end

-- True when the player has nothing to fight: no target, a dead one, or one that cannot be attacked while Warn with a friendly target is on. Nil
-- while the game withholds an answer.
local function Missing()
	local exists = Ask(UnitExists, "target")
	if type(exists) ~= "boolean" then
		return nil
	elseif not exists then
		return true
	end
	local dead = Ask(UnitIsDead, "target")
	if type(dead) ~= "boolean" then
		return nil
	elseif dead then
		return true
	end
	local attack = Ask(UnitCanAttack, "player", "target")
	if type(attack) ~= "boolean" then
		return nil
	end
	return not attack and Opt("noTargetFriendly") == true
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
	Judge()
end

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	S.fighting = true
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
	if FlashWanted() or S.warned or S.listening or S.waiting then
		Run(function()
			Listen(false)
			Judge()
			Flash("leave")
		end)
	end
end)

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	if S.fighting and WarnWanted() then
		Run(Judge)
	end
end)

ns.AddStatus(KEY, function()
	local lines = {}
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) or not (Opt("noTarget") or Opt("combatState")) then
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
	end
	if Opt("combatState") then
		lines[#lines + 1] = ("Entering and leaving combat: %d shown."):format(S.flashes)
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

-- True while one of the alerts is on, which is when the movers have a handle for where they show.
function ns.CombatCuesShown()
	return ns.Enabled(KEY) and (Opt("noTarget") == true or Opt("combatState") == true)
end

-- The movers set or put back the spot.
function ns.CombatCuesMoved()
	if S.frame then
		Run(Place)
	end
end
