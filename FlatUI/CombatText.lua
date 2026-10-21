local _, ns = ...

-- Damage and healing numbers over enemies, drawn on a frame of this addon's own from UNIT_COMBAT, so that they are in front
-- of the nameplate and can say what kind of hit it was. The game draws its own numbers under every interface frame and has
-- no setting for the order, so while these show, the game's rows for damage over enemies are written "0". The game's variables
-- for the position, size and motion of its numbers follow the settings. Every variable is remembered in FlatUIDB.cvars before
-- its first write and put back when the page goes off.
-- The same file works out the text for the player's own character from UNIT_COMBAT for "player" (or "vehicle") and hands it to the Incoming
-- scroll area of ScrollText.lua, which also draws your hits in the Outgoing area. The game's own text for the player takes its place from the
-- handle of the movers, which the game gives no setting for, so while Combat text for you is not Off the game's Scrolling Combat Text for
-- Self (enableFloatingCombatText) is written "0" as well.
-- Numbers over friendly units come from the same event, for the party and raid tokens and the pet token and for friendly nameplates. They
-- are drawn over the plate or over the unit's party or raid frame, and while they show the game's healing row is written "0".

local KEY = "combattext"
-- 40 is the game's own height above the enemy, and every 5 points are 0.00375 of WorldTextScreenY_v2: 60 gives 0.015, the value Retail ships (CVars_live.lua:1652).
-- A number in front of a nameplate starts (height - 40) units above the centre of the plate.
local HEIGHT_GAME, HEIGHT_POINTS, HEIGHT_STEP = 40, 5, 0.00375
-- Critical hits higher: Retail's 0.0275 for WorldTextCritScreenY_v2 less its 0.015 (CVars_live.lua:1640 and 1652).
local CRIT_RISE = 0.0125
-- Stands for the client's default string of a variable.
local GAME = {}
-- The height of a message in the game's combat text (CombatTextConstants.lua:6).
local TEXT_HEIGHT = 25
-- A critical or crushing hit settles this much larger than other numbers. With a pop a number starts at its settled height, is at
-- peak times its base height `up` seconds later and is back at its settled height `down` seconds after the start. The game's own
-- critical hit goes from 30 to 60 and back to 30 at the same two times, which is 1.2 and 2.4 times the height of a message
-- (CombatTextConstants.lua:6-10, CombatText.lua:318-326). The game pops no other number: the 1.3 is a choice made by eye.
local POP = { up = 0.05, down = 0.2, peak = 1.3, crit = 1.2, critPeak = 2.4 }
-- The look of a number. A face names the game's font object that holds its file in the language of the client, the file for a client
-- that has no such object, and the name the status uses. Friz Quadrata is the face of the game's own combat text (CombatTextFont,
-- GameFontStyles.xml:150-152); the others are those of GameFonts.xml:486-520 and 594-620. An outline names the game's font object
-- that holds its flags, and the flags for a client that has none (GameFonts.xml:101-103, Fonts.xml:1113-1115). Every look is a font
-- object of the addon's own with its shadow set on the object, which is where the game keeps the shadow of its combat font
-- (Fonts.xml:1063-1068). The raster is the height of the game's combat font (Fonts.xml:1060-1062). last is the game's font object
-- a number is made on when the client will not make a font object at all, and so the font a font string is created with: a font
-- of the game's XML, which every font string may be made on, and not the name of an object this file made, which the client source
-- never does. shows says what that font looks like in the line about a refused font: both have the game's shadow (Fonts.xml:1063-1068,
-- 1113-1121) and the outline one has the thick outline.
local LOOK = { raster = 64, last = { thick = "CombatTextFontOutline", thin = "CombatTextFontOutline", none = "CombatTextFont" },
	shows = { thick = "a thick outline and a shadow", thin = "a thick outline and a shadow", none = "a shadow" },
	faces = { friz = { "CombatTextFont", "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, arial = { "Number12Font", "Fonts\\ARIALN.TTF", "Arial Narrow" },
		skurri = { "NumberFont_Outline_Huge", "Fonts\\skurri.ttf", "Skurri" }, morpheus = { "QuestFont_Super_Huge", "Fonts\\MORPHEUS.ttf", "Morpheus" } },
	outlines = { thick = { "CombatTextFontOutline", "OUTLINE, THICK" }, thin = { "SystemFont_Huge1_Outline", "OUTLINE" }, none = { nil, "" } } }
-- The look in use ({ key, name = the font object, note = the line the status has about it }), and the font object of each look made
-- so far, or false for one the game would not make.
local look, objects = {}, {}
-- The handle of the Incoming scroll area (the player's own text) and the height of the screen the lengths of the scroll areas are given for
-- (CombatText.lua:484, 506-508 of the client). own counts the hit reports for the player and the ones whose handler raised an error, and
-- keeps the last report and the first error.
local OWN = { mover = "FlatUICombatSelf", screen = 768 }
local own = { reports = 0, failed = 0, last = {} }
-- The Classic style, which numbers over enemies and friendly units take from the game's old floating text: seconds a number lives and the
-- share of that time it stays whole before it fades (CombatTextConstants.lua:4-5, CombatText.lua:311-314), one line of stack as a share of
-- the height (26 over 25, CombatText.lua:8, 360), the units a number goes to the side past the stack (CombatText.lua:11,
-- 368), the height the rise distance is given for (the text of 40 units), the share of its size a glancing hit, a word and Immune are
-- drawn at (CombatFeedback.lua:42, 54-60), the game's colours of damage and healing (CombatTextConstants.lua:27-28, 38, 57) and the
-- columns a number starts in, in the order the stack fills them: the middle, then right, then left.
local CLASSIC = { life = 1.9, fadeFrom = 1.3 / 1.9, line = 26 / 25, side = 80, ref = 40, kinds = { glancing = 0.75, word = 0.75, immune = 0.5 },
	game = { physical = { 1, 0.1, 0.1 }, magic = { 0.79, 0.3, 0.85 }, heal = { 0.1, 1, 0.1 } }, columns = { 0, 1, -1 } }
-- Seconds a number lives, and the second it starts to fade.
local LIFE, FADE_FROM = 1.5, 1.0
-- Rise and fall: y = RISE * t - GRAVITY / 2 * t * t, in units above the start.
local RISE, GRAVITY = 100, 160
-- Straight up: units a second.
local CLIMB = 40
-- Where the numbers of one enemy start sideways, in turn, with a spread of Loose (the game staggers by 20, CombatTextConstants.lua:11).
local LANES = { 0, 20, -20, 40, -40 }
-- Rise and fall: the sideways drift of a number, in units a second for each unit of its lane.
local DRIFT = 0.75
-- Spread width: the lanes a number starts in are LANE_PITCH apart and reach LANE_REACH to either side at a width of 100 and a size up to
-- REF_HEIGHT units high (a Size of 160%). Above that height the lanes, the rise, the fall and the climb grow with the height, so a large
-- number moves as far as its own size. ROW_STEP is how many heights a row starts above the one under it. PEAK_GROW is the most a pop adds
-- to the settled height, and RASTER the heights a font object is made at: the second only when a settled critical hit is larger than the
-- first. DRIFT_CAP is the most sideways speed a number has, in units a second. All of these are choices of this file, not the game's.
local LANE_PITCH, LANE_REACH, REF_HEIGHT, ROW_STEP, PEAK_GROW = 20, 40, 40, 1.05, 60
local RASTER = { 64, 128 }
local DRIFT_CAP = 40 * DRIFT
-- Units a critical hit starts higher when Critical hits is Higher.
local CRIT_LIFT = 10
-- Numbers alive at once. The oldest is reused for the next.
local MAX_LIVE, MAX_LIVE_CLASSIC = 40, 60
-- The constants the setup drawing of combat text (SetupDrawChat.lua) places its sample numbers with: the same ones the numbers move with.
ns.CombatShape = { heightGame = HEIGHT_GAME, text = TEXT_HEIGHT, pop = POP, life = LIFE, fade = FADE_FROM, lanes = LANES, critLift = CRIT_LIFT, classic = CLASSIC }
-- Frame strata from the lowest, up to the highest a number is raised to.
local STRATA = { "WORLD", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
-- The strata above a plate whose own strata cannot be read.
local UNKNOWN_STRATA = "HIGH"
-- Colours of a hit by school mask when Colour by school of magic is on (CombatLogColors.lua:16-21, masks in LuaEnum.lua:2538).
local SCHOOLS = { [2] = { 1, 0.9, 0.5 }, [4] = { 1, 0.5, 0 }, [8] = { 0.3, 1, 0.3 }, [16] = { 0.5, 1, 1 }, [32] = { 0.5, 0.5, 1 }, [64] = { 1, 0.5, 1 } }
-- Whose hits. No source of who made a hit is open to addons: UNIT_COMBAT has no field for it (UnitDocumentation.lua:4167-4180) and the combat
-- log is read through C_CombatLogSecure, whose environment is SecureOnly (CombatLogSecureDocumentation.lua:3-6). So a hit counts as yours
-- from signals about you that are plain: a cast of yours or your pet's (UNIT_SPELLCAST_*, plain for the player and their pet,
-- SecretPredicatesDocumentation.lua:110-113), your swing and your shot (PLAYER_ENTER_COMBAT, START_AUTOREPEAT_SPELL, as the game's attack
-- button follows them, ActionButton.lua:1018-1031) and a harmful aura of yours on the enemy (the filter string of CooldownViewerItemData.lua:716-724).
-- The numbers are chosen by eye, not the game's: cast is the seconds after a cast or the start of one that a hit on your target counts, tail
-- the seconds after a channel ends, aura the seconds an answer about the auras of an enemy is kept, offAfter the hit reports in combat with
-- no signal heard that switch the estimate off. The events heard are for the player and the pet (UnitDocumentation.lua:4614, 4628, 4818,
-- 4846) and about the player's own attack (UnitDocumentation.lua:3770, 3814, SpellBookDocumentation.lua:974, 980) and the zone.
-- One hit for each of yours gives each action of yours a slot, and a hit fills one free slot: a successful cast of yours or your pet's a slot
-- on the target plate for cast seconds, each hand a slot that frees swingShare of its speed after it was used (UnitAttackSpeed,
-- UnitDocumentation.lua:682-697), a shot the same by UnitRangedDamage (UnitDocumentation.lua:2962-2974), and each harmful aura of yours,
-- up to auraMax, one non-critical hit in each window of swingShare x tick seconds. On the target plate a swing slot and then an aura slot
-- are tried before the cast slot, which stays for a spell hit that can be critical. extra: seconds after a swing slot in which one more physical hit is an
-- extra attack, when no cast slot is open. swingGap is the speed used when the game withholds it. Like the other numbers
-- they are chosen by eye, not the game's.
-- heard: signals heard. blind: answers the game withheld. left and kept: hits left out and shown. unheard: reports in combat with no signal
-- heard. off: the estimate is off and the game's own numbers show. deaf: no cast event could be registered. last: the last decision, as
-- text. castAt: when the last cast or channel ended. on: the frame that hears the signals is registered.
-- nextSwing: the first rank of Maul, Heroic Strike, Cleave and Raptor Strike. A cast of one of them (by name, so every rank and language) opens
-- a next-swing slot for cast seconds that only the physical hit takes, and a word in the extra seconds after that hit is the swing it replaced.
-- castIcons holds the icon of each cast slot at the same index (false for none), chanIcon the icon of the channel, nextIcon and nextName those of the
-- next-swing ability, healIcon the icon of a helpful cast of yours until healUntil, swingIcon and shotIcon those of a swing and a shot.
local MINE = { cast = 1.5, shots = { [75] = true, [2480] = true, [7918] = true, [2764] = true, [7919] = true, [5019] = true }, tail = 0.5, aura = 0.5, offAfter = 10, swingGap = 1.0, tick = 3.0, swingShare = 0.8, auraMax = 4, extra = 0.4, nextSwing = { 6807, 78, 845, 2973 },
	unitEvents = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" },
	plainEvents = { "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTERING_WORLD" } }
local mine = { castUntil = -1, castAt = 0, on = false, deaf = false, chan = false, swing = false, shoot = false, aura = {}, heard = 0, blind = 0, left = 0, kept = 0,
	unheard = 0, off = false, last = nil, castSlots = {}, castTaken = -1, hand = { main = -math.huge, off = -math.huge }, shotAt = -math.huge, shotEnd = -math.huge, auraSlots = {}, swingAt = -math.huge, extraUsed = false,
	castIcons = {}, healUntil = -1, nextUntil = -1, nextAt = -math.huge, trace = false }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True while Style is Classic.
local function Classic()
	return Opt("style") == "classic"
end

-- True for a value the game wrote that the client has not withheld and that has the type asked for.
local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- True when the player is in a group (IsInGroup, as the raid frame manager asks, Blizzard_CompactRaidFrameManager.lua:123).
local function InGroup()
	if type(IsInGroup) ~= "function" then
		return false
	end
	local ok, grouped = pcall(IsInGroup)
	return ok and Plain(grouped, "boolean") and grouped
end

local function Calls()
	return type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" and type(C_CVar.SetCVar) == "function"
end

-- The value of a variable as text, or nil when the client has no such variable or does not say.
local function Read(name)
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(C_CVar.GetCVar, name)
	if ok and Plain(value, "string") then
		return value
	end
	return nil
end

-- True for two texts that are one number, or the same text.
local function Same(a, b)
	local x, y = tonumber(a), tonumber(b)
	if x and y then
		return math.abs(x - y) < 1e-6
	end
	return a == b
end

-- A number as text with at most five decimals: 0.015, 1.4, -0.03.
local function Text(number)
	local text = (("%.5f"):format(number):gsub("0+$", ""))
	if text:sub(-1) == "." then
		text = text .. "0"
	end
	return text
end

-- What the client gives a variable when nothing has been set: its own answer, or the one in the list the variable is written from.
local function GameDefault(var)
	if type(C_CVar) == "table" and type(C_CVar.GetCVarDefault) == "function" then
		local ok, value = pcall(C_CVar.GetCVarDefault, var.name)
		if ok and Plain(value, "string") and value ~= "" then
			return value
		end
	end
	return var.default
end

-- The variables written so far, by name: { game = the value to put back, wrote = the value last written }. They belong to the
-- install and not to a profile, because the variables do. Nil when there are none and none are to be made.
local function Records(create)
	local db = ns.Account()
	if db == nil then
		return nil
	end
	if type(db.cvars) ~= "table" then
		if not create then
			return nil
		end
		db.cvars = {}
	end
	for name, rec in pairs(db.cvars) do
		if type(rec) ~= "table" or not Plain(rec.game, "string") then
			db.cvars[name] = nil
		end
	end
	return db.cvars
end

-- True once a hit report for an enemy has been shown, or an earlier session left a record of the first switch row.
local proven = false
-- True once a number over a friendly unit has been shown, or an earlier session left a record of the game's healing row.
local friendProven = false
-- What the records said at the first Sync of the session.
local atLogin
-- True while a write refused in combat waits for the end of combat.
local retry = false
local Sync

-- True while the game's own numbers show over enemies because the player is in a party or raid, where other players hit the same enemies.
-- With Where your hits show on Scroll area the numbers over enemies are off, so the game's do not take their place.
local function GroupHand()
	return Opt("source") == "front" and Opt("group") == "game" and InGroup() and Opt("where") ~= "scroll"
end

-- The switch rows are "0" while the numbers in front of nameplates show, or while Where your hits show is Scroll area, which the game's
-- numbers over enemies would repeat. They wait for the first hit report, since the event is proven for the player, vehicle and pet only
-- (PlayerFrame.lua:74, PetFrame.lua:47).
local function Switch()
	if (Opt("source") == "front" or Opt("where") == "scroll") and proven and not (mine.off and Opt("whose") ~= "all") and not GroupHand() then
		return "0"
	end
	return nil
end

-- Where friendly numbers show: off, frames, plates or both.
local function FriendMode()
	if not ns.Enabled(KEY) then
		return "off"
	end
	return Opt("friend")
end

-- The game's healing row (the healing the player does to the target, CVars.lua:733) is "0" while Flat UI draws the healing over friendly
-- units, which waits for the first friendly number like the rows over enemies.
local function FriendHealSwitch()
	if FriendMode() ~= "off" and Opt("friendHeal") == "taken" and friendProven then
		return "0"
	end
	return nil
end

-- Height above the enemy for the game's own numbers: (height - 40) / 5 x 0.00375, plus Retail's step for a critical hit on Higher.
-- A result equal to the game's own value is the client's default string.
local function Height(crit)
	local number = (Opt("height") - HEIGHT_GAME) / HEIGHT_POINTS * HEIGHT_STEP + ((crit and Opt("crit") == "higher") and CRIT_RISE or 0)
	if number == 0 then
		return GAME
	end
	return Text(number)
end

-- Size: 100% is the game's own 1.000000. No file gives a range, so the game may keep another value (the status says so).
-- While Flat UI draws the numbers over enemies (Switch is "0") the game's world text left is what Flat UI does not draw, such as
-- experience, so Size of experience and other gains sets it. Smaller than your text is the share the game gives words on the
-- portrait (CombatFeedback.lua:54).
local GAIN_SMALLER = 0.75
local GAIN_WORDS = { own = "Same as your text", smaller = "Smaller than your text", game = "The game's own size", enemy = "Same as numbers over enemies" }
local function Size()
	local percent = Opt("size")
	if Switch() == "0" then
		local gain = Opt("gainSize")
		if gain == "game" then
			return GAME
		elseif gain == "own" then
			percent = Opt("ownSize")
		elseif gain == "smaller" then
			percent = Opt("ownSize") * GAIN_SMALLER
		end
	end
	if percent == 100 then
		return GAME
	end
	return Text(percent / 100)
end

-- Loose is the game's own 1.0 for the starting place at a Spread width of 100 and that width over 100 above it; Tight is the 0.0 the three Classic clients ship (CVars_classic.lua:1559).
local function Spread()
	if Opt("spread") ~= "loose" then
		return "0.0"
	end
	if Opt("spreadWidth") == 100 then
		return GAME
	end
	return Text(Opt("spreadWidth") / 100)
end

-- Rise and fall is the game's own 0.500000 for gravity, and so is Burst, whose normal hits rise and fall. 0.0 rests on the name of the
-- variable: no list ships it.
local function Movement()
	if Opt("movement") ~= "up" then
		return GAME
	end
	return "0.0"
end

-- The game's own text for the player is off while Combat text for you shows the player's numbers. At login this is written at PLAYER_LOGIN,
-- before the game registers its settings (Blizzard_SettingsRegistrar.lua:11-22) and loads its combat text only for a variable that is on
-- (CombatOverrides.lua:53, Blizzard_Settings.lua:651-663), so the game's text does not load at all. A change during a session goes through
-- the callback the game's text listens to (CombatText.lua:17-28 of the game's).
local function OwnSwitch()
	if Opt("own") ~= "off" then
		return "0"
	end
	return nil
end

local HEAL_VAR = "floatingCombatTextCombatHealing_v2"

-- Each variable: its name, the string of the client's list, and a function that gives the string to write, GAME for the client's
-- default, or nil to leave it alone. keep marks the variable /flatui combat reset leaves as the player has it, since the game's own
-- text for the player is the player's to switch on (CVars.lua:662 lists it, off by default).
local VARS = {
	{ name = "floatingCombatTextCombatDamage_v2", default = "1", value = Switch },
	{ name = "floatingCombatTextCombatLogPeriodicSpells_v2", default = "1", value = Switch },
	{ name = "floatingCombatTextPetMeleeDamage_v2", default = "1", value = Switch },
	{ name = "floatingCombatTextPetSpellDamage_v2", default = "1", value = Switch },
	{ name = "WorldTextScreenY_v2", default = "0.0", value = function() return Height(false) end },
	{ name = "WorldTextCritScreenY_v2", default = "0.0", value = function() return Height(true) end },
	{ name = "WorldTextScale_v2", default = "1.000000", value = Size },
	{ name = "WorldTextStartPosRandomness_v2", default = "1.0", value = Spread },
	{ name = "WorldTextGravity_v2", default = "0.500000", value = Movement },
	{ name = HEAL_VAR, default = "1", value = FriendHealSwitch },
	-- Not first: Sync takes proven from the first row.
	{ name = "enableFloatingCombatText", default = "0", value = OwnSwitch, keep = true },
}

-- The string a variable is to hold, or nil.
local function Wanted(var)
	if not ns.Enabled(KEY) then
		return nil
	end
	local value = var.value()
	if value == GAME then
		return GameDefault(var)
	end
	return value
end

-- Writes a variable and reads it back. A value that did not change was refused, and in combat the write is tried again
-- afterwards. A value that changed to something else than asked was changed by the game. Returns what the game holds now.
local function Write(var, text)
	local before = Read(var.name)
	pcall(C_CVar.SetCVar, var.name, text)
	local kept = Read(var.name)
	if var.note then
		ns.ClearNote(KEY, var.note)
		var.note = nil
	end
	if kept == nil or (Same(kept, before) and not Same(before, text) and var.clamp ~= text) then
		var.note = ("%s: the game refused %s."):format(var.name, text)
		ns.Note(KEY, var.note)
		if InCombatLockdown() and not retry then
			retry = true
			ns.OutOfCombat(function()
				retry = false
				Sync()
			end)
		end
	elseif not Same(kept, text) then
		-- The game answers this text with another value, and does so again for the same text.
		var.clamp = text
		var.note = ("%s: the game keeps %s for %s."):format(var.name, kept, text)
		ns.Note(KEY, var.note)
	else
		var.clamp = nil
	end
	return kept
end

-- How the records and the variables compare at the first Sync of the session.
local function LoginState(store)
	if store == nil or next(store) == nil then
		return "nothing remembered"
	end
	local written, game = false, true
	for name, rec in pairs(store) do
		local current = Read(name)
		if current ~= nil then
			if rec.wrote ~= nil and Same(current, rec.wrote) and not Same(current, rec.game) then
				written = true
			end
			if not Same(current, rec.game) then
				game = false
			end
		end
	end
	if written then
		return "the values written last session"
	end
	return game and "the game's own values" or "other values"
end

-- Makes every variable hold what the settings want, or what it held before the first write when the page is off. Safe to
-- call at any time and any number of times.
function Sync()
	if not Calls() then
		return
	end
	local store = Records(false)
	if not proven then
		proven = store ~= nil and store[VARS[1].name] ~= nil
	end
	friendProven = friendProven or (store ~= nil and store[HEAL_VAR] ~= nil)
	if atLogin == nil then
		atLogin = LoginState(store)
	end
	for _, var in ipairs(VARS) do
		local current = Read(var.name)
		if current ~= nil then
			local wanted = Wanted(var)
			local rec = store and store[var.name]
			local wrote = false
			if wanted ~= nil and Same(current, wanted) then
				if rec and Same(rec.game, wanted) then
					store[var.name] = nil
				elseif rec then
					rec.wrote = current
				end
			elseif wanted ~= nil then
				if not rec then
					-- The value to put back is stored before the game is asked to change it.
					store = Records(true)
					rec = { game = current }
					store[var.name] = rec
				elseif rec.wrote == nil or not Same(current, rec.wrote) then
					-- Someone else set the value since the last write, so that value is the one to put back.
					rec.game = current
				end
				wrote = true
				local kept = Write(var, wanted)
				if kept ~= nil and Same(kept, rec.game) then
					store[var.name] = nil
				elseif kept ~= nil and not Same(kept, current) then
					rec.wrote = kept
				elseif rec.wrote == nil then
					store[var.name] = nil
				end
			elseif rec then
				if rec.wrote ~= nil and Same(current, rec.wrote) and not Same(current, rec.game) then
					wrote = true
					local kept = Write(var, rec.game)
					if kept ~= nil and Same(kept, rec.game) then
						store[var.name] = nil
					end
				else
					store[var.name] = nil
				end
			end
			if not wrote and var.note then
				ns.ClearNote(KEY, var.note)
				var.note = nil
			end
		end
	end
	if store and next(store) == nil then
		ns.Account().cvars = nil
	end
end

-- At logout every written value goes back, and the records stay: the next login writes the wanted values again.
local function Leave()
	if not Calls() then
		return
	end
	for name, rec in pairs(Records(false) or {}) do
		local current = Read(name)
		if current ~= nil and rec.wrote ~= nil and Same(current, rec.wrote) and not Same(current, rec.game) then
			pcall(C_CVar.SetCVar, name, rec.game)
		end
	end
end

-- Numbers in front of nameplates ------------------------------------------------------------------------------------

local host, ticker
-- Numbers not in use, and numbers alive. Each: { text = the font string, plate, unit, start, x, y, lane, movement, height }.
local free, live = {}, {}
-- The place in STRATA of the strata the host frame has.
local hostRank = 0
-- Numbers started for each plate since it got its unit.
local count = setmetatable({}, { __mode = "k" })
local stats = { reports = 0, target = 0, shown = 0, noPlate = 0, friendly = 0, detail = 0, amount = 0, kind = 0, unplaced = 0, unstyled = 0, kept = 0, removed = 0, columns = { [0] = 0, [1] = 0, [-1] = 0 } }
-- The last hit report for a nameplate, as text for /flatui combat.
local last = {}
-- Friendly numbers alive at once, and over one unit; the oldest of that unit goes first.
local FRIEND_MAX, FRIEND_PER_UNIT = 20, 4
-- A report for the same plate or frame with the same event, flag and school within this many seconds is the same hit under a second token.
local FRIEND_SAME = 0.02
-- Seconds a table of group frames is used before it is read again.
local FRAMES_FOR = 1
-- live and shown: friendly numbers on screen and shown. reports: hit reports that came for friendly units, by kind of token (plates, group, pet).
-- same: reports dropped as the same hit under a second token. noAnchor: reports with no plate or frame to draw over. unknown: Target only
-- answers the game withheld. forbidden: friendly plates the game kept from addons. recent: the last report for each anchor.
local friend = { live = 0, shown = 0, reports = 0, plates = 0, group = 0, pet = 0, noAnchor = 0, unknown = 0, same = 0, forbidden = 0,
	last = {}, recent = setmetatable({}, { __mode = "k" }) }
-- The frames of the party, the raid and the pet by unit token, and when they were read.
local frames = { at = 0, byUnit = {} }
local plateStrata, hostStrata
-- The numbers over party, raid and pet frames: their own host and pool, raised from the strata of the frame, so the host of the numbers over
-- enemies and plates keeps its strata.
local fr = { free = {}, rank = 0 }

-- The nameplate of a unit, or nil when there is none, the game withholds it or it is forbidden.
local function Plate(unit)
	if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
		return nil
	end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or ns.Forbidden(plate) then
		return nil
	end
	return plate
end

-- The look of a number ----------------------------------------------------------------------------------------------------------

-- The height font objects are made at: RASTER[1] (64, the game's own, LOOK.raster) while the largest settled height a number can have, a
-- critical hit of the largest of the three sizes, is no more than that, else RASTER[2]. A number is drawn with SetTextHeight on that object, and
-- above its raster the glyphs are scaled up.
local function Raster()
	local largest = math.max(Opt("size") or 0, Opt("friendSize") or 0, Opt("ownSize") or 0)
	if TEXT_HEIGHT * largest / 100 * POP.crit > RASTER[1] then
		return RASTER[2]
	end
	return RASTER[1]
end

-- The key of a look, which is also the end of the name of its font object. Only a look made at the larger raster has it in its key, so every
-- name made at the game's own raster is as it was.
local function LookKey(font, outline, shadow)
	return font .. "_" .. outline .. "_" .. (shadow and "shadow" or "plain") .. (Raster() == RASTER[1] and "" or "_r" .. Raster())
end

-- The file, the height and the flags of a game font object as it answers GetFont, each only when it is plain text or a number. Nothing
-- is written and nothing is made.
local function FromGame(name)
	local ok, file, height, flags = pcall(function()
		return _G[name]:GetFont()
	end)
	if not ok then
		return nil, nil, nil
	end
	return Plain(file, "string") and file ~= "" and file or nil, Plain(height, "number") and height or nil, Plain(flags, "string") and flags or nil
end

-- The file and the flags of a look are the game's own where its font objects give them, in the language of the client. The setup drawing of
-- combat text draws with them too.
function ns.CombatFont(font, outline)
	local face, line = LOOK.faces[font], LOOK.outlines[outline]
	local file = FromGame(face[1])
	local _, _, flags = FromGame(line[1])
	return file or face[2], (flags ~= nil and flags ~= "") and flags or line[2]
end

-- Makes the font object of one look, or nothing when the game will not: an error from CreateFont, SetFont or the shadow, or an object
-- that does not give back the file it was given (SetFont raises for a file the game cannot find, SimpleFontAPIDocumentation.lua:199-211).
-- It gives the name of the object and the object, which is what a font string is given (SetFontObject takes a font object, CombatText.lua:455).
local function MakeObject(font, outline, shadow)
	local file, flags = ns.CombatFont(font, outline)
	local name = "FlatUICombat_" .. LookKey(font, outline, shadow)
	local ok, kept, made = pcall(function()
		local object = CreateFont(name)
		object:SetFont(file, Raster(), flags)
		object:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
		object:SetShadowColor(0, 0, 0, shadow and 1 or 0)
		return (object:GetFont()), object
	end)
	if ok and Plain(kept, "string") and kept ~= "" then
		return name, made
	end
	return nil
end

-- The font object of a look, as its name and the object: made once, and remembered as false when the game would not make it.
local function Object(font, outline, shadow)
	local key = LookKey(font, outline, shadow)
	if objects[key] == nil then
		local name, object = MakeObject(font, outline, shadow)
		objects[key] = name and { name = name, object = object } or false
	end
	return objects[key] or nil
end

-- The look the settings ask for: its key, the name of its font object, the object a font string is given, the outline it was asked for
-- and the line the status has about it. A look the game will not make shows in Friz Quadrata with the same outline and shadow, and when
-- that will not be made either, in the game's own combat font, which has a shadow and, for Thick and Thin, the thick outline; the status
-- has a line that says which, until the look changes.
local function Look()
	local font, outline, shadow = Opt("font"), Opt("outline"), Opt("shadow")
	local key = LookKey(font, outline, shadow)
	if look.key == key then
		return look
	end
	if look.note then
		ns.ClearNote(KEY, look.note)
		look.note = nil
	end
	look.key, look.outline, look.last = key, outline, LOOK.last[outline]
	local made = Object(font, outline, shadow)
	if not made then
		local fallback = Object("friz", outline, shadow)
		made = fallback or { name = LOOK.last[outline], object = _G[LOOK.last[outline]] }
		look.note = ("%s: the game refused the font. Numbers show in %s."):format(LOOK.faces[font][3],
			fallback and LOOK.faces.friz[3] or ("the game's combat font, with " .. LOOK.shows[outline]))
		ns.Note(KEY, look.note)
	end
	look.name, look.object = made.name, made.object
	return look
end

-- The scroll areas make their font strings on this look.
ns.CombatLook = Look

-- Puts the look on a font string: the font object itself, or its name when the client has no object of that name. The height is set
-- again, since a new font object gives the string its own height. A string the game will not give the look to keeps the font it has.
local function Style(item)
	if not pcall(item.text.SetFontObject, item.text, look.object or look.name) then
		stats.unstyled = stats.unstyled + 1
	end
	item.style, item.height = look.key, nil
end

-- The frame all numbers are drawn on, and the frame that moves them.
local function Screen(strata)
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata(strata)
	return frame
end

local function Host()
	if host then
		return
	end
	local frame = Screen("LOW")
	ticker = CreateFrame("Frame")
	hostRank, hostStrata = 3, "LOW"
	host = frame
end

local function RankOf(strata)
	for index, name in ipairs(STRATA) do
		if name == strata then
			return index
		end
	end
	return nil
end

-- The frame the numbers over party, raid and pet frames are drawn on.
local function FrameHost()
	Host()
	if not fr.host then
		fr.host = Screen("LOW")
		fr.rank = 3
	end
end

-- Puts the host of the frame numbers one strata above the frame. It is never lowered. The host of the plate numbers and plateStrata
-- are not touched.
local function RaiseFrame(anchor)
	local ok, strata = pcall(anchor.GetFrameStrata, anchor)
	local index = ok and Plain(strata, "string") and RankOf(strata) or nil
	local rank = RankOf(index and STRATA[math.min(index + 1, #STRATA)] or UNKNOWN_STRATA)
	if rank > fr.rank then
		pcall(fr.host.SetFrameStrata, fr.host, STRATA[rank])
		fr.rank = rank
	end
end

-- Puts the host one strata above the plate. It is never lowered.
local function Raise(plate)
	local ok, strata = pcall(plate.GetFrameStrata, plate)
	local index = ok and Plain(strata, "string") and RankOf(strata) or nil
	plateStrata = index and strata or "unknown"
	local wanted = index and STRATA[math.min(index + 1, #STRATA)] or UNKNOWN_STRATA
	local rank = RankOf(wanted)
	if rank > hostRank then
		pcall(host.SetFrameStrata, host, wanted)
		hostRank, hostStrata = rank, wanted
	end
end

-- The words of a hit ----------------------------------------------------------------------------------------------------

-- The words of the game when the client has none (CombatFeedback.lua:7-17).
local WORDS = { MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", RESIST = "Resist", ABSORB = "Absorb", IMMUNE = "Immune",
	EVADE = "Evade", DEFLECT = "Deflect", REFLECT = "Reflect", INTERRUPT = "Interrupt" }

-- A word in the language of the client, in parentheses unless bare is true or Miss words is Bare word.
local function Word(name, bare)
	local game = WORDS[name] and _G[name]
	local text = Plain(game, "string") and game ~= "" and game or WORDS[name]
	if not text or bare or Opt("missWords") == "bare" then
		return text
	end
	return "(" .. text .. ")"
end

-- Plain text in parentheses by the same rule, for the sample words of the setup drawing.
function ns.CombatParen(text)
	return Opt("missWords") == "bare" and text or "(" .. text .. ")"
end

-- What follows the amount for a kind of hit, in parentheses, or nil for a hit that has none or while Partial effects is not Word after the number
-- (the client's res/GlobalStrings/enUS.lua:22755, 22757, 2550, 89, 18682).
local function Suffix(flag)
	if flag == "EXTRA" then
		-- An extra swing in Outgoing, as over the enemy: the word does not depend on Partial effects.
		return "(Extra attack)"
	elseif Opt("partial") ~= "word" then
		return nil
	elseif flag == "GLANCING" then
		return Plain(TEXT_MODE_A_STRING_RESULT_GLANCING, "string") and TEXT_MODE_A_STRING_RESULT_GLANCING or "(Glancing)"
	elseif flag == "CRUSHING" then
		return Plain(TEXT_MODE_A_STRING_RESULT_CRUSHING, "string") and TEXT_MODE_A_STRING_RESULT_CRUSHING or "(Crushing)"
	elseif flag == "BLOCK_REDUCED" or flag == "BLOCK" then
		return "(" .. Word("BLOCK", true) .. ")"
	elseif flag == "ABSORB" then
		return "(" .. Word("ABSORB", true) .. ")"
	elseif flag == "RESIST" then
		return "(" .. Word("RESIST", true) .. ")"
	end
	return nil
end
ns.CombatSuffix = Suffix

-- Red, green and blue of a damage number: white for physical, as the game colours the numbers of the player frame (CombatFeedback.lua:44-48).
function ns.CombatColour(school, bySchool, palette)
	local physical = ns.IsSecret(school) or type(school) ~= "number" or school == 1
	local colour = not physical and bySchool and SCHOOLS[school]
	if colour then
		return colour[1], colour[2], colour[3]
	end
	if palette == "game" then
		colour = physical and CLASSIC.game.physical or CLASSIC.game.magic
		return colour[1], colour[2], colour[3]
	end
	if physical then
		return 1, 1, 1
	end
	return 1, 1, 0
end

local function Colour(school)
	return ns.CombatColour(school, Opt("school"), Classic() and Opt("classicColour") or nil)
end

-- The share of its size a number is drawn at with Partial effects on Smaller number only (CombatFeedback.lua:42, 54-60): a glancing
-- hit and the words Block, Absorb and Resist at 0.75, Immune at 0.5, everything else whole (nil). name is the word of a word.
local function KindSize(flag, name)
	if Opt("partial") ~= "smaller" then
		return nil
	end
	if name == nil then
		return flag == "GLANCING" and CLASSIC.kinds.glancing or nil
	elseif name == "IMMUNE" then
		return CLASSIC.kinds.immune
	elseif name == "BLOCK" or name == "ABSORB" or name == "RESIST" then
		return CLASSIC.kinds.word
	end
	return nil
end

-- What a hit report for the player's own character shows, in the form Describe gives, with the format of the amount in place of what
-- follows it. level is Combat text for you: take shows the damage and the healing, more adds the words and the gains. The colours are
-- the game's own for damage and healing (CombatTextConstants.lua:28, 38, 57; red for a physical hit or a school that is not known, purple
-- for any other school) and white for a word (:29-37 colour a missed swing red and :39-45 a missed spell white; the report does not say
-- which it was). A gain has the colour of the portrait's (CombatFeedback.lua:78-80): the game's combat text colours it by power
-- (CombatTextUtil.lua:44-49) and the report does not name the power.
-- WOUND with 0 is a word as on the portrait (CombatFeedback.lua:53-64).
local function DescribeOwn(level, event, flag, amount, none, school)
	local more = level == "more"
	if event == "WOUND" then
		if none then
			if not more then
				return nil
			end
			local name = (flag == "ABSORB" or flag == "BLOCK" or flag == "RESIST") and flag or "MISS"
			return "word", Word(name), "%s", false, 1, 1, 1, nil, KindSize(flag, name)
		end
		if Plain(school, "number") and school ~= 1 then
			return "amount", amount, "-%s", flag == "CRITICAL" or flag == "CRUSHING", 0.79, 0.3, 0.85
		end
		return "amount", amount, "-%s", flag == "CRITICAL" or flag == "CRUSHING", 1, 0.1, 0.1
	elseif event == "HEAL" then
		if none then
			return nil
		end
		return "amount", amount, "+%s", flag == "CRITICAL", 0.1, 1, 0.1
	elseif event == "ENERGIZE" then
		if not more or none or (Plain(amount, "number") and amount < 0) then
			return nil
		end
		return "amount", amount, "+%s", flag == "CRITICAL", 0.41, 0.8, 0.94
	elseif more and WORDS[event] then
		return "word", Word(event), "%s", false, 1, 1, 1, nil, KindSize(flag, event)
	end
	return nil
end

-- What a hit report for a friendly unit shows, in the form Describe gives, with the sign as an eighth value and the size as a ninth. A heal shows only with
-- Healing over friendly units on Healing they take from anyone (the game draws the healing the player does). The colours of damage and
-- healing are the settings', with Colour by school of magic over the damage one. A word shows only with Misses and dodges over friendly
-- units. The report has no field for who made the hit, so none of this depends on it (UnitDocumentation.lua:4167-4180).
local function DescribeFriend(event, flag, amount, none, school)
	local crit = flag == "CRITICAL" or flag == "CRUSHING"
	if event == "WOUND" then
		if none then
			if not Opt("friendWords") then
				return nil
			end
			local name = (flag == "ABSORB" or flag == "BLOCK" or flag == "RESIST") and flag or "MISS"
			return "word", Word(name), nil, false, 1, 1, 1, nil, KindSize(flag, name)
		end
		if not Opt("friendDamage") then
			return nil
		end
		local r, g, b
		if Opt("school") then
			r, g, b = Colour(school)
		else
			r, g, b = ns.Colour(KEY .. ".friendDamageColour")
		end
		return "amount", amount, (flag and Suffix(flag)) or nil, crit, r, g, b, Opt("friendSigns") and "-" or nil, KindSize(flag)
	elseif event == "HEAL" then
		if none or Opt("friendHeal") ~= "taken" then
			return nil
		end
		local r, g, b = ns.Colour(KEY .. ".friendHealColour")
		return "amount", amount, nil, flag == "CRITICAL", r, g, b, Opt("friendSigns") and "+" or nil
	elseif WORDS[event] and Opt("friendWords") then
		return "word", Word(event), nil, false, 1, 1, 1, nil, KindSize(flag, event)
	end
	return nil
end

-- What a hit report shows, by the rules of CombatFeedback.lua:34-86: "amount" or "word", the amount or the word, what follows an
-- amount, true for a critical or crushing hit, and the colour. Nothing for a report that shows nothing. event is a plain string.
-- With a level the report is for the player's own character.
local function Describe(event, flag, amount, school, level, friendly)
	if ns.IsSecret(flag) then
		stats.kind = stats.kind + 1
		flag = nil
	elseif type(flag) ~= "string" then
		flag = nil
	end
	local withheld = ns.IsSecret(amount)
	if withheld then
		stats.amount = stats.amount + 1
	elseif type(amount) ~= "number" then
		amount = 0
	end
	local none = not withheld and amount == 0
	if level then
		return DescribeOwn(level, event, flag, amount, none, school)
	end
	if friendly then
		return DescribeFriend(event, flag, amount, none, school)
	end
	if event == "WOUND" then
		if none then
			local name = (flag == "ABSORB" or flag == "BLOCK" or flag == "RESIST") and flag or "MISS"
			return "word", Word(name), nil, false, 1, 1, 1, nil, KindSize(flag, name)
		end
		local r, g, b = Colour(school)
		return "amount", amount, (flag and Suffix(flag)) or nil, flag == "CRITICAL" or flag == "CRUSHING", r, g, b,
			Classic() and Opt("classicSigns") and "-" or nil, KindSize(flag)
	elseif event == "HEAL" then
		if none then
			return nil
		end
		local heal = Classic() and Opt("classicColour") == "game" and CLASSIC.game.heal or { 0, 1, 0 }
		return "amount", amount, nil, flag == "CRITICAL", heal[1], heal[2], heal[3], Classic() and Opt("classicSigns") and "+" or nil
	elseif WORDS[event] then
		return "word", Word(event), nil, false, 1, 1, 1, nil, KindSize(flag, event)
	end
	return nil
end

-- Numbers on screen ---------------------------------------------------------------------------------------------------------

-- The kind of a number: "friend" over a friendly unit, "enemy" over an enemy.
local function KindOf(item)
	return item.friend and "friend" or "enemy"
end

-- Takes number `index` off the screen and back into the pool of its kind.
local function Release(index)
	local item = table.remove(live, index)
	item.text:Hide()
	item.plate, item.unit = nil, nil
	if item.friend then
		friend.live = friend.live - 1
	end
	local pool = item.onFrame and fr.free or free
	pool[#pool + 1] = item
	if #live == 0 then
		ticker:SetScript("OnUpdate", nil)
	end
end

-- Takes every number of one kind off the screen: "enemy" or "friend".
local function ReleaseKind(kind)
	for index = #live, 1, -1 do
		if KindOf(live[index]) == kind then
			Release(index)
		end
	end
end

-- Puts a number that could not be placed back in its pool.
local function Back(item)
	stats.unplaced = stats.unplaced + 1
	item.plate, item.unit = nil, nil
	item.text:Hide()
	local pool = item.onFrame and fr.free or free
	pool[#pool + 1] = item
end

-- A font string for a number: one not in use, or the oldest number of the same kind when that kind is at its limit, or a new one.
-- kind is "friend" over friendly units and nil over enemies. The pool of the enemy and the friendly numbers is shared.
local function Acquire(kind, onFrame)
	local pool = onFrame and fr.free or free
	local shown, limit = #live - friend.live, Classic() and MAX_LIVE_CLASSIC or MAX_LIVE
	if kind == "friend" then
		shown, limit = friend.live, FRIEND_MAX
	end
	if shown >= limit then
		for index, other in ipairs(live) do
			if KindOf(other) == (kind or "enemy") then
				Release(index)
				break
			end
		end
	end
	local item = table.remove(pool)
	if not item then
		-- Made on a font of the game's XML, which every font string may be made on; the look is given just below.
		local text = (onFrame and fr.host or host):CreateFontString(nil, "OVERLAY", LOOK.last[Look().outline])
		ns.Own[text] = true
		item = { text = text, onFrame = onFrame or nil }
	end
	item.friend = kind == "friend" or nil
	if item.style ~= Look().key then
		Style(item)
	end
	return item
end

-- How far a number has moved from its start after t seconds. A critical hit under Classic stays where it starts.
function ns.CombatOffsets(item, t)
	if item.movement == "hold" then
		return 0, 0
	end
	if item.movement == "classic" then
		return 0, item.rise * t / item.life
	end
	-- Burst: a rise of BURST.rise units while it settles, then Rise and fall from there.
	local lift = 0
	if item.movement == "burst" then
		local burst, grow = ns.CombatBurst, item.grow or 1
		if t < burst.settle then
			return 0, grow * burst.rise * t / burst.settle
		end
		t, lift = t - burst.settle, grow * burst.rise
	end
	if item.movement == "fall" or item.movement == "burst" then
		return (item.drift or item.lane * DRIFT) * t, lift + (item.grow or 1) * (RISE * t - GRAVITY / 2 * t * t)
	end
	return 0, CLIMB * (item.grow or 1) * t
end

local Offsets = ns.CombatOffsets

-- How much a number of this base height moves and spreads beyond the numbers of a Size of 160% and under: 1 up to REF_HEIGHT units, then in
-- proportion to the height.
function ns.CombatGrow(base)
	return math.max(1, base / REF_HEIGHT)
end

-- The places a number starts sideways, in the order they are taken, for a Spread width (a percent) and a grow: the lanes reach
-- LANE_REACH * grow * width / 100 to either side, with a pair of lanes more each time the pitch would pass 30, so the pitch stays
-- LANE_PITCH at every width but the narrow ones: 0, p, -p, 2p, -2p and so on, 2k + 1 lanes. A width of 100 and a grow of 1 give LANES.
-- A width of 0 or less gives the one lane in the middle. A list is made once for each width and grow, and a caller does not change it.
local laneLists, laneNone = {}, { 0 }
function ns.CombatLanes(width, grow)
	if not width or width <= 0 then
		return laneNone
	end
	grow = grow or 1
	laneLists[width] = laneLists[width] or {}
	local lanes = laneLists[width][grow]
	if lanes then
		return lanes
	end
	lanes = { 0 }
	local k = math.max(1, math.floor(width / 50))
	local pitch = LANE_REACH * grow * width / 100 / k
	for step = 1, k do
		lanes[#lanes + 1] = pitch * step
		lanes[#lanes + 1] = -pitch * step
	end
	laneLists[width][grow] = lanes
	return lanes
end

-- The sideways speed of a number in a lane: DRIFT for each unit of the lane, no more than DRIFT_CAP a second for each unit of grow.
function ns.CombatDrift(lane, grow)
	local cap = DRIFT_CAP * (grow or 1)
	return math.max(-cap, math.min(cap, lane * DRIFT))
end
local DriftOf = ns.CombatDrift

-- How much of the smaller of two boxes the other covers: 0 for boxes apart, 1 for one inside the other. Each is its centre and its size.
local function Covered(ax, ay, aw, ah, bx, by, bw, bh)
	local across = math.min(ax + aw / 2, bx + bw / 2) - math.max(ax - aw / 2, bx - bw / 2)
	local up = math.min(ay + ah / 2, by + bh / 2) - math.max(ay - ah / 2, by - bh / 2)
	if across <= 0 or up <= 0 then
		return 0
	end
	return across * up / math.min(aw * ah, bw * bh)
end

-- Where a number starts over a plate or frame so that it keeps clear of the numbers still on it. olds are those numbers, each { x, y (where
-- it started), w, h (its size), age (seconds), lane, drift, grow, movement }; spec is { lanes (the list of ns.CombatLanes), turn (the place
-- in that list the number would take in turn), w, h (the size of the new number), rows (the most rows up it may start), y0 (its usual
-- start height), apart (false to keep the turn), grow and movement (how it moves, default 1 and "fall") }. Each old number is placed as
-- it will be at the start, 0.2 and 0.4 seconds on, with ns.CombatOffsets, and so is the new number in each place it could start: the rows
-- from the usual start, each ROW_STEP heights above the one under it, and in each row the lanes from the turn round the list. The cost
-- of a place is the sum, over the three times and every old number, of how much of the smaller of the two the other covers. The first place
-- that costs nothing is taken, else the cheapest, the earlier on a tie. It gives the lane (as a sideways start) and how far up the number
-- starts from y0. Nothing is allocated.
local TIMES = { 0, 0.2, 0.4 }
local CHOOSING = {}
-- The numbers over one plate as ns.CombatChoose is given them: the list and the tables in it, kept so that a hit allocates none.
local scratch = { olds = {}, pool = {} }
function ns.CombatChoose(olds, spec)
	local lanes, turn = spec.lanes, spec.turn
	local grow, movement = spec.grow or 1, spec.movement or "fall"
	if spec.apart == false or #olds == 0 then
		return lanes[turn], 0
	end
	local best, bestLane, bestLift
	local new = CHOOSING
	new.grow, new.movement = grow, movement
	for row = 0, math.max(1, spec.rows or 1) - 1 do
		local lift = row * ROW_STEP * spec.h
		for step = 0, #lanes - 1 do
			local lane = lanes[(turn - 1 + step) % #lanes + 1]
			new.lane, new.drift = lane, DriftOf(lane, grow)
			local cost = 0
			for _, old in ipairs(olds) do
				for _, dt in ipairs(TIMES) do
					local ox, oy = Offsets(old, (old.age or 0) + dt)
					local nx, ny = Offsets(new, dt)
					cost = cost + Covered(old.x + ox, old.y + oy, old.w, old.h, lane + nx, spec.y0 + lift + ny, spec.w, spec.h)
				end
			end
			if not best or cost < best then
				best, bestLane, bestLift = cost, lane, lift
				if cost == 0 then
					return bestLane, bestLift
				end
			end
		end
	end
	return bestLane, bestLift
end

-- The height of a number t seconds into its pop, as the game works it out for a critical hit (CombatText.lua:318-326): from the settled
-- height to the peak and back in whole numbers. The game's clock is the sum of its frame times; this one is GetTime, whose difference
-- can come out a hair under the time, so a hair is added before the number is cut to a whole one. A settled height that is not a whole
-- number is the height at the start and at the end.
function ns.CombatPopHeight(settle, peak, t)
	local height
	local span = peak - settle
	if t >= POP.down then
		height = settle
	elseif t <= POP.up then
		height = settle + math.floor(span * t / POP.up + 1e-6)
	else
		height = settle + math.floor(span * (1 - (t - POP.up) / (POP.down - POP.up)) + 1e-6)
	end
	return height, t < POP.down
end

local function Pop(item, t)
	local height, popping
	if item.burst then
		height, popping = ns.CombatBurstHeight(item.settle, t)
	else
		height, popping = ns.CombatPopHeight(item.settle, item.peak, t)
	end
	if not popping then
		item.pop = nil
	end
	if height ~= item.height then
		item.text:SetTextHeight(height)
		item.height = height
	end
end

-- Puts a number where it is `now`: on its nameplate (or above its party or raid frame), or on the screen once the nameplate has gone.
local function Place(item, now)
	local t = now - item.start
	local dx, dy = Offsets(item, t)
	item.text:ClearAllPoints()
	if item.plate and item.kind == "frame" then
		item.text:SetPoint("BOTTOM", item.plate, "TOP", item.x + dx, item.y + dy)
	elseif item.plate then
		item.text:SetPoint("CENTER", item.plate, "CENTER", item.x + dx, item.y + dy)
	else
		item.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", item.screenX + dx, item.screenY + dy)
	end
	item.text:SetAlpha(t <= item.fade and 1 or math.max(0, 1 - (t - item.fade) / (item.life - item.fade)))
	if item.pop then
		Pop(item, t)
	end
end

local function Step()
	local now = GetTime()
	for index = #live, 1, -1 do
		if now - live[index].start >= live[index].life then
			Release(index)
		elseif not pcall(Place, live[index], now) then
			stats.unplaced = stats.unplaced + 1
			Release(index)
		end
	end
end

local function Tick()
	ns.Try(KEY, Step)
end

-- How far the game's text for the player goes, as a multiple of its 225 units: the height of WorldFrame over 768 (CombatText.lua:484,
-- 506-508), and that height. 1 and nothing when the height cannot be read.
local function WorldScale()
	if not WorldFrame then
		return 1
	end
	local ok, height = pcall(WorldFrame.GetHeight, WorldFrame)
	if ok and Plain(height, "number") and height > 0 then
		return height / OWN.screen, height
	end
	return 1
end

-- How far a scroll area reaches, as a multiple of its length on a screen 768 units high.
function ns.CombatWorldScale()
	return (WorldScale())
end

-- Where a Classic number starts, as a height from the spot: one line (gap) under the lowest of the heights of the numbers still near it,
-- or above the highest with Down. The setup drawing of combat text stacks its sample numbers with this.
function ns.CombatOwnEdge(mode, gap, heights)
	local edge = 0
	for _, at in ipairs(heights) do
		if mode == "down" then
			edge = math.max(edge, at + gap)
		else
			edge = math.min(edge, at - gap)
		end
	end
	return edge
end

-- Where a number over an enemy or a friendly unit starts: the lane in turn from the lanes of the Spread width, and with Keep apart the lane
-- and the row ns.CombatChoose finds among the numbers still over the same plate or frame; the height is the usual start plus the row.
local function LayOut(item, plate, crit, friendly, onFrame)
	local n = (count[plate] or 0) + 1
	count[plate] = n
	local grow = item.grow
	local lanes = ns.CombatLanes(Opt("spread") == "loose" and Opt("spreadWidth") or 0, grow)
	local turn = (n - 1) % #lanes + 1
	local lift = (crit and Opt("crit") == "higher") and CRIT_LIFT or 0
	item.kind = friendly and onFrame and "frame" or "plate"
	local y0
	if friendly and onFrame then
		y0 = Opt("friendHeight") + lift
	else
		y0 = (Opt("height") - HEIGHT_GAME) + lift
	end
	local lane, up = lanes[turn], 0
	if Opt("overlap") == "apart" then
		local olds, pool, k = scratch.olds, scratch.pool, 0
		for _, other in ipairs(live) do
			if other.plate == plate and other.kind == item.kind then
				k = k + 1
				local old = pool[k]
				if not old then
					old = {}
					pool[k] = old
				end
				old.x, old.y, old.w, old.h = other.x, other.y, other.w or 3 * other.settle, other.settle
				old.age = item.start - other.start
				old.lane, old.drift, old.grow, old.movement = other.lane, other.drift, other.grow, other.movement
				olds[k] = old
			end
		end
		for index = #olds, k + 1, -1 do
			olds[index] = nil
		end
		lane, up = ns.CombatChoose(olds, { lanes = lanes, turn = turn, w = item.w, h = item.settle, rows = Opt("rows") or 1, y0 = y0, grow = grow, movement = ns.CombatMove(Opt("movement"), crit and not friendly and Opt("pop") == "pop") })
	end
	item.lane, item.drift = lane, DriftOf(lane, grow)
	item.x = lane
	item.y = y0 + up
end

-- The column a Classic number starts in: the first of CLASSIC.columns (middle, right, left) that has fewer than `lines` numbers in it, else
-- the middle. counts is the number of live Classic numbers over the same plate, by column. The game's own text does the same with its
-- lines: past the limit a message goes to the side (CombatText.lua:364-372).
function ns.CombatClassicColumn(counts, lines)
	for _, column in ipairs(CLASSIC.columns) do
		if (counts[column] or 0) < lines then
			return column
		end
	end
	return CLASSIC.columns[1]
end

-- How far a Classic number already in a column must be pushed up for a new one to start at the spot: one line (CLASSIC.line) of the mean
-- of the two heights, less the height the older one is at above the spot now (`near`). Nothing when it is clear already.
function ns.CombatClassicPush(near, settle, otherSettle)
	return math.max(0, (settle + otherSettle) / 2 * CLASSIC.line - near)
end

-- Where a Classic number starts: its column and its height above the plate, for a number that starts at spec.now, and the numbers over the
-- same plate that are in the way (mates: any numbers with movement classic or hold, and a column, y, settle, start, rise and life, as a
-- number has). spec: the spot (the height of a number that starts clear), settle (its height), base, lines (numbers in a column), tight
-- (one column), down (New numbers start lower), crit (a critical hit starts at the spot, as in CombatText.lua:365-367). With Older numbers
-- move up the numbers of its column are pushed up (their y changes, a held critical hit too); with New numbers start lower it starts a line
-- under the lowest of them, at most `lines` lines under the spot. The setup drawing places its sample numbers with this.
function ns.CombatClassicStart(mates, spec)
	local counts, here = { [0] = 0, [1] = 0, [-1] = 0 }, {}
	for _, other in ipairs(mates) do
		if (other.movement == "classic" or other.movement == "hold") and other.start + other.life > spec.now then
			counts[other.classic] = counts[other.classic] + 1
			here[#here + 1] = other
		end
	end
	local column = spec.tight and 0 or ns.CombatClassicColumn(counts, spec.lines)
	local near = {}
	for _, other in ipairs(here) do
		if other.classic == column then
			local _, moved = Offsets(other, spec.now - other.start)
			near[#near + 1] = { other = other, height = other.y + moved - spec.spot }
		end
	end
	local y = spec.spot
	if spec.down then
		if not spec.crit then
			local heights = {}
			for index, entry in ipairs(near) do
				heights[index] = entry.height
			end
			y = spec.spot + math.max(ns.CombatOwnEdge("up", spec.base * CLASSIC.line, heights), -spec.base * CLASSIC.line * spec.lines)
		end
	else
		local shift = 0
		for _, entry in ipairs(near) do
			shift = math.max(shift, ns.CombatClassicPush(entry.height, spec.settle, entry.other.settle))
		end
		if shift > 0 then
			for _, entry in ipairs(near) do
				entry.other.y = entry.other.y + shift
			end
		end
	end
	return column, y
end

-- Starts a number the Classic way: in a column over the plate (CombatText.lua:355-391 of the client), and moving straight up at a steady speed for
-- `classicTime` percent of the game's 1.9 seconds. A critical hit under Classic stays in place (a held number) when Critical hits stay in
-- place is on, and pops; no other number pops. The height of the spot is the one Fill works out for a Flat UI number.
local function StartClassic(item, plate, crit, friendly, onFrame)
	local lift = (crit and Opt("crit") == "higher") and CRIT_LIFT or 0
	local spot = ((friendly and onFrame) and Opt("friendHeight") or (Opt("height") - HEIGHT_GAME)) + lift
	local grow = ns.CombatGrow(item.base)
	local mates = {}
	for _, other in ipairs(live) do
		if other.plate == plate then
			mates[#mates + 1] = other
		end
	end
	local column, y = ns.CombatClassicStart(mates, { spot = spot, settle = item.settle, base = item.base, lines = Opt("rows") or 4, tight = Opt("spread") ~= "loose",
		down = Opt("classicStack") == "down", crit = crit, now = item.start })
	item.kind = friendly and onFrame and "frame" or "plate"
	item.classic, item.lane = column, 0
	item.x = column * CLASSIC.side * item.base / TEXT_HEIGHT * (Opt("spreadWidth") or 100) / 100
	item.y = y
	item.rise = Opt("classicRise") * grow
	item.life = CLASSIC.life * Opt("classicTime") / 100
	item.fade = item.life * CLASSIC.fadeFrom
	item.movement = (crit and Opt("classicCrit")) and "hold" or "classic"
	item.pop = crit or nil
	stats.columns[column] = stats.columns[column] + 1
end

-- Fills a font string with one number and places it. True when it is placed, false when the number is not shown. An error goes up.
local function Fill(item, plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale)
	local friendly = class == "friend"
	local text = item.text
	if kind == "word" then
		text:SetText(value)
	else
		local shown = value
		if type(BreakUpLargeNumbers) == "function" then
			local ok, broken = pcall(BreakUpLargeNumbers, value)
			if ok and (ns.IsSecret(broken) or broken ~= nil) then
				shown = broken
			end
		end
		if friendly and extra then
			text:SetFormattedText((sign or "") .. "%s %s", shown, extra)
		elseif friendly then
			text:SetFormattedText((sign or "") .. "%s", shown)
		elseif extra then
			text:SetFormattedText((sign or "") .. "%s %s", shown, extra)
		else
			text:SetFormattedText((sign or "") .. "%s", shown)
		end
	end
	local base = TEXT_HEIGHT * Opt(friendly and "friendSize" or "size") / 100
	base = base * (scale or 1)
	local height = base * (crit and POP.crit or 1)
	if item.height ~= height then
		text:SetTextHeight(height)
		item.height = height
	end
	item.base, item.settle, item.peak = base, height, math.min(base * (crit and POP.critPeak or POP.peak), height + PEAK_GROW, RASTER[2])
	item.grow = ns.CombatGrow(base)
	-- The width the game gives the text, or three times its height (four more with a word after it) when it gives none.
	local ok, width = pcall(text.GetStringWidth, text)
	item.estimated = not (ok and Plain(width, "number") and width > 0) or nil
	item.w = not item.estimated and width or (3 + (extra and 4 or 0)) * height
	stats.width, stats.estimated, stats.drawn = item.w, item.estimated, height
	item.pop, item.burst = Opt("pop") == "pop" or nil, nil
	text:SetTextColor(r, g, b)
	item.start = GetTime()
	if not Classic() then
		LayOut(item, plate, crit, friendly, onFrame)
	end
	item.movement = ns.CombatMove(Opt("movement"), crit and not friendly and Opt("pop") == "pop")
	item.life, item.fade = LIFE, FADE_FROM
	if Classic() then
		StartClassic(item, plate, crit, friendly, onFrame)
	elseif item.movement == "burst" then
		-- The slam is the burst's own pop. With Plainly there is no burst: the number starts at its settled size and rises and falls.
		item.life, item.fade, item.pop, item.burst = ns.CombatBurst.life, ns.CombatBurst.fade, true, true
	end
	item.plate, item.unit = plate, unit
	if not pcall(Place, item, item.start) then
		return false
	end
	return true
end

-- Shows one number over a plate or a frame. True when it is on screen. The amount may be a value the game withholds: it is passed on to
-- the font string and never compared, indexed, counted or joined to text. extra is what follows the amount. An error while the font
-- string is filled puts it back in its pool.
local function Spawn(plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale)
	if type(GetTime) ~= "function" then
		return false
	end
	class = class == "friend" and "friend" or nil
	Host()
	if class == "friend" and onFrame then
		FrameHost()
		RaiseFrame(plate)
	else
		Raise(plate)
	end
	if class == "friend" then
		-- Over one unit the oldest friendly numbers go first.
		local over = 0
		for _, other in ipairs(live) do
			if other.friend and other.plate == plate then
				over = over + 1
			end
		end
		while over >= FRIEND_PER_UNIT do
			for index, other in ipairs(live) do
				if other.friend and other.plate == plate then
					Release(index)
					break
				end
			end
			over = over - 1
		end
	end
	local item = Acquire(class, class == "friend" and onFrame or nil)
	local ok, shown = pcall(Fill, item, plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale)
	if not (ok and shown) then
		Back(item)
		return false
	end
	item.text:Show()
	live[#live + 1] = item
	if #live == 1 then
		ticker:SetScript("OnUpdate", Tick)
	end
	if class == "friend" then
		friend.live, friend.shown = friend.live + 1, friend.shown + 1
	else
		stats.shown = stats.shown + 1
	end
	return true
end

-- Events ----------------------------------------------------------------------------------------------------------------------

-- A value of a hit report as text for /flatui combat.
local function Shown(value)
	if ns.IsSecret(value) then
		return "withheld"
	end
	return tostring(value)
end

-- One line of /flatui combat trace: the time and each value as Shown gives it, so a withheld value is never turned readable.
local function Trace(...)
	local parts = { ("Trace %.3f"):format(GetTime()) }
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if ns.IsSecret(value) then
			parts[#parts + 1] = "withheld"
		elseif value == "" then
			parts[#parts + 1] = '""'
		elseif value ~= nil then
			parts[#parts + 1] = tostring(value)
		end
	end
	print(table.concat(parts, " "))
end

-- The last hit report of a kind is kept as its five values in a table that is made once, and is put into text only when /flatui combat asks.
local function Remember(into, unit, event, flag, amount, school)
	into[1], into[2], into[3], into[4], into[5] = unit, event, flag, amount, school
	into.set = true
end

-- A hit report as text for /flatui combat, or nil before there is one.
local function Reported(into)
	if not into.set then
		return nil
	end
	return table.concat({ into[1], Shown(into[2]), Shown(into[3]), Shown(into[4]), "school " .. Shown(into[5]) }, ", ")
end

-- The unit the game's own combat text follows: the vehicle while the player has a vehicle interface, else the player
-- (CombatText.lua:476-480).
local function ActiveUnit()
	local ok, vehicle = pcall(UnitHasVehicleUI, "player")
	if ok and Plain(vehicle, "boolean") and vehicle then
		return "vehicle"
	end
	return "player"
end

-- A hit report for the player's own character. It never sets proven and never writes a variable of the game's.
local function OnOwn(unit, event, flag, amount, school)
	if Opt("own") == "off" then
		return
	end
	own.reports = own.reports + 1
	Remember(own.last, unit, event, flag, amount, school)
	if unit ~= ActiveUnit() then
		return
	end
	if not Plain(event, "string") then
		stats.detail = stats.detail + 1
		return
	end
	local kind, value, format, crit, r, g, b, _, scale = Describe(event, flag, amount, school, Opt("own"))
	if kind then
		-- The first heal after a helpful cast of yours takes its icon.
		local icon
		if kind == "amount" and event == "HEAL" and GetTime() <= mine.healUntil then
			icon = Opt("icons") ~= "off" and mine.healIcon or nil
			mine.healUntil = -1
		end
		ns.ScrollText.Show("inc", kind, value, format, crit, r, g, b, kind == "amount" and KindSize(Plain(flag, "string") and flag or nil) or scale,
			Plain(flag, "string") and flag or nil, nil, icon)
	end
end

-- True for the token of a party or raid member, and not for a pet, a target or the player.
local function Group(unit)
	return unit:find("^party%d$") ~= nil or unit:find("^raid%d+$") ~= nil
end

-- The time as the game gives it, or 0.
local function Now()
	if type(GetTime) == "function" then
		return GetTime()
	end
	return 0
end

-- The frames of the party members, the raid and the pet by unit token, read again after FRAMES_FOR seconds and at once after a change of
-- the roster. The two lists of party frames are the ones the party cooldowns find (PartyCooldowns.lua); a raid frame is CompactRaidFrameN
-- with its unit (UnitFrames.lua:2358-2359).
local function Frames()
	local now = Now()
	if frames.at > 0 and now - frames.at < FRAMES_FOR then
		return frames.byUnit
	end
	local found = {}
	pcall(function()
		for _, getter in ipairs({ ns.PartyMembers, ns.PartyStyleMembers }) do
			if type(getter) == "function" then
				for _, member in ipairs(getter()) do
					if found[member.unit] == nil then
						found[member.unit] = member.frame
					end
				end
			end
		end
		for index = 1, 40 do
			local frame = _G["CompactRaidFrame" .. index]
			if frame ~= nil and not ns.Forbidden(frame) then
				local unit = frame.unit
				local shown = frame:IsShown()
				if Plain(unit, "string") and unit:find("^raid%d+$") and not ns.IsSecret(shown) and shown == true and found[unit] == nil then
					found[unit] = frame
				end
			end
		end
		local pet = _G.PetFrame
		if pet ~= nil and not ns.Forbidden(pet) then
			local shown = pet:IsShown()
			if not ns.IsSecret(shown) and shown == true then
				found.pet = pet
			end
		end
	end)
	frames.byUnit, frames.at = found, now > 0 and now or 1e-9
	return found
end

-- The frame to draw over for a unit token, or nil when there is none or the frame now shows another unit.
local function FrameOfUnit(token)
	local frame = Frames()[token]
	if frame == nil then
		return nil
	end
	if token ~= "pet" then
		local ok, unit, shown = pcall(function()
			return frame.unit, frame.displayedUnit
		end)
		if not (ok and ((Plain(unit, "string") and unit == token) or (Plain(shown, "string") and shown == token))) then
			return nil
		end
	end
	return frame
end

-- The nameplate of the unit a party, raid or pet token names, or nil. A withheld answer is nil, and the frame is used instead
-- (UnitIsUnit is secret only on addon-restricted maps, UnitDocumentation.lua:2410-2414).
local function PlateOfUnitRead(token)
	if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlates) ~= "function" then
		return nil
	end
	local ok, found = pcall(function()
		local plates = C_NamePlate.GetNamePlates()
		if ns.IsSecret(plates) or type(plates) ~= "table" then
			return nil
		end
		for _, plate in ipairs(plates) do
			if not ns.Forbidden(plate) then
				local unit = plate.unitToken
				if Plain(unit, "string") then
					local mine = true
					if token == "pet" then
						local owned = UnitIsOwnerOrControllerOfUnit("player", unit)
						mine = Plain(owned, "boolean") and owned
					end
					if mine then
						local answer = UnitIsUnit(token, unit)
						if Plain(answer, "boolean") and answer then
							return plate
						end
					end
				end
			end
		end
		return nil
	end)
	return ok and found or nil
end

-- The same answer, kept for the length of a frame and dropped when a plate comes or goes: a raid with heals ticking asks it for every report.
local plateOf = { at = nil, by = {} }
local function PlateOfUnit(token)
	local now = Now()
	if plateOf.at ~= now then
		plateOf.at, plateOf.by = now, {}
	end
	local kept = plateOf.by[token]
	if kept ~= nil then
		return kept or nil
	end
	local found = PlateOfUnitRead(token)
	plateOf.by[token] = found or false
	return found
end

-- True when a friendly number may show for a unit token or the plate of a unit: with Friendly units on Target only, only over the
-- target. An answer the game withholds shows the number and is counted.
local function ForTarget(unit, plate)
	if Opt("friendUnits") ~= "target" then
		return true
	end
	if plate then
		return plate == Plate("target")
	end
	local ok, same = pcall(UnitIsUnit, unit, "target")
	if ok and Plain(same, "boolean") then
		return same
	end
	friend.unknown = friend.unknown + 1
	return true
end

-- Shows one number over a friendly unit, over its plate or, when onFrame is true, over its frame. The amount may be withheld: it goes
-- to the font string only.
local function ShowFriend(anchor, onFrame, token, event, flag, amount, school)
	if not Plain(event, "string") then
		stats.detail = stats.detail + 1
		return
	end
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(event, flag, amount, school, nil, true)
	if not kind then
		return
	end
	local comparable = Plain(flag, "string") and Plain(school, "number")
	local now = Now()
	local before = friend.recent[anchor]
	if comparable and before and before.event == event and before.flag == flag and before.school == school and now - before.at < FRIEND_SAME then
		friend.same = friend.same + 1
		return
	end
	if Spawn(anchor, token, kind, value, suffix, crit, r, g, b, "friend", sign, onFrame, scale) then
		friend.recent[anchor] = comparable and { event = event, flag = flag, school = school, at = now } or nil
		if not friendProven then
			-- The game's healing row is switched off only once a friendly number has been shown.
			friendProven = true
			Sync()
		end
	end
end

-- A hit report for a party or raid member or for the pet.
local function OnFriendToken(token, event, flag, amount, school)
	local mode = FriendMode()
	if mode == "off" then
		return
	end
	local pet = token == "pet"
	friend.reports = friend.reports + 1
	Remember(friend.last, token, event, flag, amount, school)
	if pet then
		friend.pet = friend.pet + 1
		if not Opt("friendPet") then
			return
		end
	else
		friend.group = friend.group + 1
	end
	if not ForTarget(token) then
		return
	end
	-- A unit with a nameplate has that plate's own token, which reports it.
	if mode ~= "frames" and PlateOfUnit(token) then
		friend.same = friend.same + 1
		return
	end
	if mode == "plates" then
		return
	end
	local frame = FrameOfUnit(token)
	if not frame then
		friend.noAnchor = friend.noAnchor + 1
		return
	end
	ShowFriend(frame, true, token, event, flag, amount, school)
end

-- A hit report for a friendly nameplate.
local function OnFriendPlate(plate, unit, event, flag, amount, school)
	friend.reports, friend.plates = friend.reports + 1, friend.plates + 1
	Remember(friend.last, unit, event, flag, amount, school)
	if not Opt("friendPet") then
		local ok, owned = pcall(UnitIsOwnerOrControllerOfUnit, "player", unit)
		if ok and Plain(owned, "boolean") and owned then
			return
		end
	end
	if not ForTarget(unit, plate) then
		return
	end
	ShowFriend(plate, false, unit, event, flag, amount, school)
end

-- Whose hits ---------------------------------------------------------------------------------------------------------------

local function Length(list)
	return #list
end

-- The number of harmful auras of yours on the enemy, at most MINE.auraMax, and whether the list was read. The answer is kept for MINE.aura
-- seconds for each unit. A list the game withholds, a count it withholds and a call that fails are none, are not read, and are counted.
local function AuraOfYours(unit)
	local now = GetTime()
	local held = mine.aura[unit]
	if held and now - held.at < MINE.aura then
		return held.number, held.read
	end
	local number, read = 0, false
	local ok, list
	if type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function" then
		ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL|PLAYER", MINE.auraMax)
	end
	if ok and Plain(list, "table") then
		local counted, size = pcall(Length, list)
		if counted and Plain(size, "number") then
			number, read = math.min(size, MINE.auraMax), true
		else
			mine.blind = mine.blind + 1
		end
	else
		mine.blind = mine.blind + 1
	end
	mine.aura[unit] = { at = now, number = number, read = read }
	return number, read
end

-- True only when the aura list was read and holds no aura of yours. An unread list does not open the extra slot.
local function AuraListFree(unit)
	local number, read = AuraOfYours(unit)
	return read and number == 0
end

-- The file of the icon of a spell, or nil when the id is withheld, the game has none or its answer is withheld (SpellDocumentation.lua:595-612).
local function Icon(id)
	if not Plain(id, "number") or type(C_Spell) ~= "table" or type(C_Spell.GetSpellTexture) ~= "function" then
		return nil
	end
	local ok, file = pcall(C_Spell.GetSpellTexture, id)
	if ok and Plain(file, "number") then
		return file
	end
	return nil
end

-- The name of the spell when it is a next melee ability of MINE.nextSwing, else nil. Both names must be plain (SpellDocumentation.lua:516-532).
local function NextSwing(id)
	if not Plain(id, "number") or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if not ok or not Plain(name, "string") then
		return nil
	end
	for _, base in ipairs(MINE.nextSwing) do
		local found, other = pcall(C_Spell.GetSpellName, base)
		if found and Plain(other, "string") and other == name then
			return name
		end
	end
	return nil
end

-- True when the hit counts as yours (see MINE). Every value is tested for being withheld first. The decision is counted and kept as text.
local function Mine(plate, unit, school, flag)
	local now = GetTime()
	local why
	if plate == Plate("target") then
		if mine.chan then
			why = "channel"
		elseif now <= mine.castUntil then
			why = ("cast %.1f s ago"):format(math.max(0, now - mine.castAt))
		elseif mine.shoot then
			why = "shot"
		elseif mine.swing then
			if Plain(school, "number") then
				if school == 1 then
					why = "swing"
				end
			else
				mine.blind = mine.blind + 1
			end
		end
	end
	if not why then
		if Plain(flag, "string") then
			if flag ~= "CRITICAL" and AuraOfYours(unit) > 0 then
				why = "aura"
			end
		else
			mine.blind = mine.blind + 1
		end
	end
	if why then
		mine.kept, mine.last = mine.kept + 1, "yours (" .. why .. ")"
		return true
	end
	mine.left, mine.last = mine.left + 1, "left out (no cast or swing seen)"
	return false
end

-- The seconds between two uses of a weapon: the speed the game gives, or MINE.swingGap when the game withholds it or the call fails, and
-- then it is counted. Returns the main hand and, when asked for hands, the off hand, which is nil when there is none.
local function Speeds(call, hands)
	local ok, main, off = pcall(call, "player")
	if not (ok and Plain(main, "number") and main > 0) then
		mine.blind = mine.blind + 1
		return MINE.swingGap, nil
	end
	if not hands then
		return main, nil
	end
	if ns.IsSecret(off) then
		mine.blind = mine.blind + 1
		return main, nil
	end
	if Plain(off, "number") and off > 0 then
		return main, off
	end
	return main, nil
end

-- Takes the slot of a hand or of the bow when it has been free for MINE.swingShare of its speed. Returns true when it did.
local function TakeWeapon(speed, last, now)
	return now - last >= speed * MINE.swingShare
end

-- Takes a cast slot of yours that has not run out. Returns true when it did, and the icon of the cast (nil for none).
local function TakeCast(now)
	local list, icons = mine.castSlots, mine.castIcons
	while list[1] and list[1] < now do
		table.remove(list, 1)
		table.remove(icons, 1)
	end
	if list[1] then
		mine.castTaken = math.max(mine.castTaken, table.remove(list, 1))
		return true, table.remove(icons, 1) or nil
	end
	return false
end

-- Takes one of the aura slots of an enemy. Returns true when it did, and whether there was a slot to take at all.
local function TakeAura(unit, now)
	local number = AuraOfYours(unit)
	if number == 0 then
		return false, false
	end
	local slots = mine.auraSlots[unit]
	if not slots or TakeWeapon(MINE.tick, slots.at, now) then
		slots = { at = now, used = 0 }
		mine.auraSlots[unit] = slots
	end
	if slots.used < number then
		slots.used = slots.used + 1
		return true, true
	end
	return false, true
end

-- UnitExists lists no secret return (DOC/UnitDocumentation.lua:1192-1204); a withheld answer is still treated as a pet out.
-- True when a pet is out or the game does not say. The extra attack slot is closed then, as a pet's melee looks the same (DOC/UnitDocumentation.lua:4167-4180: UNIT_COMBAT has no source field).
local function PetOut()
	if type(UnitExists) ~= "function" then
		return true
	end
	local ok, there = pcall(UnitExists, "pet")
	return not (ok and Plain(there, "boolean") and not there)
end

-- Takes the slot of a hand for a white hit, then the extra attack slot, which opens for MINE.extra seconds after a hand slot is taken and
-- takes one hit. The extra slot is closed with a pet out, in a group, with Extra attacks Off, while a cast slot is open (an instant strike) and while a harmful aura of yours is on the enemy (a bleed tick looks the same). Returns "swing slot" or "extra slot" when
-- it took one, and true when a hand was busy.
local function TakeSwing(now, unit)
	local main, off = Speeds(UnitAttackSpeed, true)
	if TakeWeapon(main, mine.hand.main, now) then
		mine.hand.main, mine.swingAt, mine.extraUsed = now, now, false
		return "swing slot", false
	elseif off and TakeWeapon(off, mine.hand.off, now) then
		mine.hand.off, mine.swingAt, mine.extraUsed = now, now, false
		return "swing slot", false
	elseif Opt("extra") == "plain" and not mine.extraUsed and now - mine.swingAt <= MINE.extra and not InGroup() and not PetOut() and not (mine.castSlots[1] and mine.castSlots[1] >= now) and AuraListFree(unit) then
		mine.extraUsed = true
		return "extra slot", false
	end
	return nil, true
end

-- True when the hit takes a slot of yours (see MINE), and true again when that slot is the extra attack slot: one hit for each action. A hit with no free slot is left out. On the target plate a
-- physical hit during auto-attack tries a swing slot first and a non-critical hit tries an aura slot next, so that a cast slot stays for the
-- spell hit it was made for, which can be critical. The cast slot is the fallback for every hit. A next melee ability (Maul, Heroic Strike,
-- Cleave, Raptor Strike) opens a next-swing slot that only the physical hit takes, and a word right after that hit (word is true) is the swing it
-- replaced and is left out. Returns true, the slot taken and the icon of the action (nil for none, by Spell icons).
local function MineOne(plate, unit, school, flag, word)
	local now = GetTime()
	local why, taken, swingTried, auraTried, icon
	if plate == Plate("target") then
		-- In this mode castUntil is set only by the end of a channel.
		if mine.chan or now <= mine.castUntil then
			why = "channel"
		elseif word and now - mine.nextAt <= MINE.extra then
			taken, auraTried = true, true
		elseif not word and now <= mine.nextUntil and Plain(school, "number") and school == 1 then
			mine.nextUntil, mine.nextAt = -1, now
			mine.hand.main, mine.swingAt, mine.extraUsed = now, now, true
			why = "next swing"
		else
			if mine.swing and not (mine.shoot or now <= mine.shotEnd) and Plain(school, "number") and school == 1 then
				swingTried = true
				why, taken = TakeSwing(now, unit)
			end
			if not why and Plain(flag, "string") and flag ~= "CRITICAL" then
				auraTried = true
				local got, slot = TakeAura(unit, now)
				if got then
					why = "aura slot"
				elseif slot then
					taken = true
				end
			end
			local cast, castIcon
			if not why then
				cast, castIcon = TakeCast(now)
			end
			if why then
				-- A slot was taken above.
			elseif cast then
				why, icon = "cast slot", castIcon
			else
				taken = taken or now <= mine.castTaken
				if mine.shoot or now <= mine.shotEnd then
					local speed = Speeds(UnitRangedDamage)
					if TakeWeapon(speed, mine.shotAt, now) then
						mine.shotAt, why = now, "shot slot"
						-- A single shot has one hit: its slot closes when it is taken.
						if not mine.shoot then mine.shotEnd = -math.huge end
					else
						taken = true
					end
				elseif mine.swing and not swingTried then
					if Plain(school, "number") then
						if school == 1 then
							why, taken = TakeSwing(now, unit)
						end
					else
						mine.blind = mine.blind + 1
					end
				end
			end
		end
	end
	if not why and not auraTried then
		if Plain(flag, "string") then
			if flag ~= "CRITICAL" then
				local got, slot = TakeAura(unit, now)
				if got then
					why = "aura slot"
				elseif slot then
					taken = true
				end
			end
		else
			mine.blind = mine.blind + 1
		end
	end
	if why then
		mine.kept, mine.last = mine.kept + 1, "yours (" .. why .. ")"
		local mode = Opt("icons")
		if why == "channel" then
			icon = mine.chanIcon
		elseif why == "next swing" then
			icon = mine.nextIcon
		elseif why == "swing slot" or why == "extra slot" then
			mine.swingIcon = mine.swingIcon or Icon(6603)
			icon = mode == "all" and mine.swingIcon or nil
		elseif why == "shot slot" then
			mine.shotIcon = mine.shotIcon or Icon(75)
			icon = mode == "all" and mine.shotIcon or nil
		end
		return true, why, mode ~= "off" and icon or nil
	end
	mine.left = mine.left + 1
	mine.last = taken and "left out (slot taken)" or "left out (no cast or swing seen)"
	return false
end

-- A signal about you. Only the time is kept, and nothing of the payload but the unit, which must be the player or the pet.
local function OnSignal(_, event, unit, _, spellID)
	if event == "PLAYER_ENTERING_WORLD" then
		local was = mine.off
		mine.heard, mine.unheard, mine.off = 0, 0, mine.deaf
		mine.chan, mine.swing, mine.shoot = false, false, false
		mine.castSlots, mine.castTaken, mine.auraSlots = {}, -1, {}
		mine.castIcons, mine.chanIcon, mine.nextIcon, mine.healIcon, mine.swingIcon, mine.shotIcon = {}, nil, nil, nil, nil, nil
		mine.healUntil, mine.nextUntil, mine.nextAt, mine.nextName = -1, -1, -math.huge, nil
		mine.hand, mine.shotAt, mine.shotEnd = { main = -math.huge, off = -math.huge }, -math.huge, -math.huge
		mine.swingAt, mine.extraUsed = -math.huge, false
		if was ~= mine.off then
			pcall(Sync)
		end
		return
	end
	local now = GetTime()
	if event == "PLAYER_ENTER_COMBAT" then
		mine.swing = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		mine.swing = false
	elseif event == "START_AUTOREPEAT_SPELL" then
		mine.shoot = true
		-- Blizzard names Auto Shot for a hunter and the Shoot spell of the weapon for every other class (HostileTargetingActionBar.lua:99-112).
		-- Unseen: a bow, gun or thrown weapon of a non-hunter shows the Shoot icon here, not that weapon's own Shoot.
		local ok, class = false, nil
		if type(UnitClassBase) == "function" then
			ok, class = pcall(UnitClassBase, "player")
		end
		class = ok and class or nil
		mine.shotIcon = Icon(Plain(class, "string") and class ~= "HUNTER" and 5019 or 75)
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		-- The last Auto Shot can hit after the stop, so its slot stays open for MINE.tail.
		mine.shoot, mine.shotEnd = false, now + MINE.tail
	elseif Plain(event, "string") and event:sub(1, 5) == "UNIT_" then
		if not Plain(unit, "string") or (unit ~= "player" and unit ~= "pet") then
			return
		end
		if event == "UNIT_SPELLCAST_CHANNEL_START" then
			mine.chan, mine.chanIcon = true, Icon(spellID)
		elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			mine.chan, mine.castUntil, mine.castAt = false, now + MINE.tail, now
		else
			-- Every hit while you attack opens its window at a start or an end of a cast. One hit for each of yours gives a slot at a cast
			-- that succeeded, and none at a start.
			if Opt("whose") == "one" then
				if event == "UNIT_SPELLCAST_SUCCEEDED" then
					-- Slots run out in the order they were made, so the ones past are dropped here and the list stays short.
					local list, icons = mine.castSlots, mine.castIcons
					while list[1] and list[1] < now do
						table.remove(list, 1)
						table.remove(icons, 1)
					end
					-- A next melee ability of the player opens a next-swing slot and no cast slot.
					local name = unit == "player" and NextSwing(spellID)
					-- A shot opens no cast slot either: it stays white from the shot slot (HostileTargetingActionBar.lua:4-11).
					local shot = unit == "player" and Plain(spellID, "number") and MINE.shots[spellID]
					if shot then
						mine.shotIcon = Icon(spellID)
						-- A single shot, with no auto-repeat on, opens a slot for its one hit.
						if not mine.shoot then
							mine.shotEnd, mine.shotAt = now + MINE.cast, -math.huge
						end
					elseif name then
						mine.nextUntil, mine.nextName, mine.nextIcon = now + MINE.cast, name, Icon(spellID)
					else
						list[#list + 1] = now + MINE.cast
						icons[#icons + 1] = Icon(spellID) or false
					end
					-- A helpful cast of yours gives the next heal on you its icon.
					local helpful = unit == "player" and Plain(spellID, "number") and type(C_Spell) == "table" and type(C_Spell.IsSpellHelpful) == "function"
						and select(2, pcall(C_Spell.IsSpellHelpful, spellID))
					if Plain(helpful, "boolean") and helpful then
						mine.healIcon, mine.healUntil = Icon(spellID), now + MINE.cast
					end
				end
			else
				mine.castUntil, mine.castAt = now + MINE.cast, now
			end
		end
	else
		return
	end
	if mine.trace then
		local name
		if Plain(spellID, "number") and type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
			local ok, got = pcall(C_Spell.GetSpellName, spellID)
			name = ok and Plain(got, "string") and got or nil
		end
		Trace(event, unit, spellID, name)
	end
	mine.heard = mine.heard + 1
	if mine.off then
		-- A signal after all: the estimate works here.
		mine.off, mine.unheard = false, 0
		pcall(Sync)
	end
end

-- The frame that hears the signals is registered while the estimate is in use, and not otherwise. When no call registers a cast event the
-- estimate is off.
local function MineFrame()
	local wanted = ns.Enabled(KEY) and (Opt("source") == "front" or Opt("where") ~= "over") and (Opt("whose") == "mine" or Opt("whose") == "one")
	if wanted and not mine.on then
		local f = mine.frame or CreateFrame("Frame")
		mine.frame = f
		f:SetScript("OnEvent", OnSignal)
		local casts = 0
		for _, event in ipairs(MINE.unitEvents) do
			local done = false
			if f.RegisterUnitEvent then
				local ok, result = pcall(f.RegisterUnitEvent, f, event, "player", "pet")
				-- RegisterUnitEvent has no documented return: only an error or false counts as a refusal.
				done = ok and (ns.IsSecret(result) or result ~= false)
			end
			if not done then
				done = pcall(f.RegisterEvent, f, event)
			end
			casts = casts + (done and 1 or 0)
		end
		for _, event in ipairs(MINE.plainEvents) do
			pcall(f.RegisterEvent, f, event)
		end
		mine.on = true
		mine.deaf = casts == 0
		mine.off = mine.deaf
		if mine.deaf then
			-- The rows were written for the estimate by the Sync before this; they go back to the game's now.
			pcall(Sync)
		end
	elseif not wanted and mine.on then
		for _, list in ipairs({ MINE.unitEvents, MINE.plainEvents }) do
			for _, event in ipairs(list) do
				pcall(mine.frame.UnregisterEvent, mine.frame, event)
			end
		end
		mine.on, mine.deaf = false, false
		mine.chan, mine.swing, mine.shoot = false, false, false
		mine.castSlots, mine.castTaken, mine.auraSlots, mine.castIcons = {}, -1, {}, {}
	end
end

-- True when a hit report for a nameplate or for the target counts under Whose hits and Enemies, then the slot it took ("extra slot" for an extra
-- attack, "next swing" for Maul and the like) and the icon of the action. A plate that Target only leaves out is not judged, so it is not counted
-- as shown. word is true for a report that shows a word, which a next melee ability leaves out. event and amount are for /flatui combat trace.
local function Counts(plate, unit, school, flag, word, event, amount)
	local whose = Opt("whose")
	local keep, why, icon, decision
	if whose == "mine" or whose == "one" then
		-- Reports in combat with no signal of yours heard since login or the last change of zone: the estimate has nothing to go on.
		if mine.heard == 0 and InCombatLockdown() then
			mine.unheard = mine.unheard + 1
			if mine.unheard >= MINE.offAfter and not mine.off then
				mine.off = true
				Sync()
			end
		end
		if not (mine.off or (Opt("units") == "target" and plate ~= Plate("target"))) then
			keep, why, icon = (whose == "one" and MineOne or Mine)(plate, unit, school, flag, word)
			decision = mine.last
		else
			decision = "left out (estimate off or not the target)"
		end
	else
		keep = not (Opt("units") == "target" and plate ~= Plate("target"))
		decision = keep and "shown (everyone's)" or "left out (not the target)"
	end
	if mine.trace then
		Trace(unit, event, flag, amount, "school", school, "->", decision, keep and (icon and "icon" or "no icon") or nil, keep and icon or nil)
	end
	if not keep then
		return false
	end
	return true, why, icon
end

-- The colour of a hit of yours and the name to show after it, by the slot it took. Without Colour by school of magic every hit of a spell or
-- special attack (cast slot, next swing, channel) is yellow, whatever its school, and every swing, extra attack and shot is white. With it, the
-- school gives the colour, except that Physical ability hits Yellow makes a physical hit of a spell or special attack yellow. Without the school
-- colours, Physical ability hits White makes a physical hit of one white. Next melee ability names After the number gives the name.
local function Ability(why, school, r, g, b)
	local spell = why == "cast slot" or why == "next swing" or why == "channel"
	if not (spell or why == "swing slot" or why == "extra slot" or why == "shot slot") then
		return r, g, b
	end
	local physical = ns.IsSecret(school) or type(school) ~= "number" or school == 1
	local name = why == "next swing" and Opt("abilityName") == "after" and Plain(mine.nextName, "string") and mine.nextName or nil
	if Opt("school") then
		if spell and physical and Opt("abilityColour") == "spell" then
			r, g, b = Colour(0)
		end
	elseif spell and not (physical and Opt("abilityColour") == "white") then
		r, g, b = Colour(0)
	else
		r, g, b = Colour(1)
	end
	return r, g, b, name
end

-- The rule of Describe for a word: a report of a word event, or a hit of no amount.
function MINE.IsWord(event, amount)
	return WORDS[event] ~= nil or (event == "WOUND" and not ns.IsSecret(amount) and (type(amount) ~= "number" or amount == 0))
end

-- A hit report for the target with Where your hits show on Scroll area, or on Both while the target has no nameplate: Outgoing takes the
-- reports of the target token and leaves the nameplate tokens alone, so one enemy gives one copy of each report. A hit on an enemy that is
-- not the target scrolls only with Both.
local function OnTarget(unit, event, flag, amount, school)
	if not Plain(event, "string") or event == "HEAL" then
		return
	end
	local ok, attackable = pcall(UnitCanAttack, "player", unit)
	if ok and Plain(attackable, "boolean") and not attackable then
		return
	end
	local counted, why, icon = Counts(Plate("target"), unit, school, flag, MINE.IsWord(event, amount), event, amount)
	if not counted then
		return
	end
	local kind, value, _, crit, r, g, b, _, scale = Describe(event, flag, amount, school)
	local name
	if kind == "amount" then
		r, g, b, name = Ability(why, school, r, g, b)
	end
	if kind and ns.ScrollText.Show("out", kind, value, name and ("%s " .. name:gsub("%%", "%%%%")) or "%s", crit, r, g, b, scale, Plain(flag, "string") and flag or nil, nil, icon) and not proven then
		proven = true
		Sync()
	end
end

-- A hit on an enemy, or on a friendly unit. The game names one unit token for each enemy with a nameplate, so no hit shows twice. The
-- event has no field for who made the hit.
local function OnCombat(unit, event, flag, amount, school)
	-- The player's own character, whatever Numbers over enemies is set to. An error in it is counted and does not stop the numbers
	-- over enemies.
	if Plain(unit, "string") and (unit == "player" or unit == "vehicle") then
		local ok, err = pcall(OnOwn, unit, event, flag, amount, school)
		if not ok then
			own.failed, own.first = own.failed + 1, own.first or tostring(err)
		end
		return
	end
	local enemies = Opt("source") == "front"
	if not enemies and not ns.ScrollText.On("out") and FriendMode() == "off" then
		return
	end
	if ns.IsSecret(unit) then
		stats.detail = stats.detail + 1
		return
	end
	if type(unit) ~= "string" then
		return
	end
	if unit == "target" then
		stats.target = stats.target + 1
		local where = Opt("where")
		if (where == "scroll" or (where == "both" and not Plate("target"))) and ns.ScrollText.On("out") then
			OnTarget(unit, event, flag, amount, school)
		end
	end
	if unit == "pet" or Group(unit) then
		OnFriendToken(unit, event, flag, amount, school)
		return
	end
	if not unit:lower():find("^nameplate") then
		return
	end
	stats.reports = stats.reports + 1
	Remember(last, unit, event, flag, amount, school)
	if not Plain(event, "string") then
		stats.detail = stats.detail + 1
		return
	end
	local plate = Plate(unit)
	if not plate then
		stats.noPlate = stats.noPlate + 1
		return
	end
	local ok, attackable = pcall(UnitCanAttack, "player", unit)
	if ok and Plain(attackable, "boolean") and not attackable then
		stats.friendly = stats.friendly + 1
		local mode = FriendMode()
		if mode == "plates" or mode == "both" then
			OnFriendPlate(plate, unit, event, flag, amount, school)
		end
		return
	end
	-- In a group with the game's own numbers the game draws them. Until a refused write in combat is made, its damage row still holds the
	-- 0 written for Flat UI, the game draws none, and Flat UI shows its numbers. With Scroll area the nameplate reports are left to the target
	-- token (OnTarget), and with Both Outgoing takes a copy of each report the numbers over enemies take.
	local where = Opt("where")
	local over = enemies and where ~= "scroll" and not (GroupHand() and Read(VARS[1].name) ~= "0")
	local out = where == "both" and event ~= "HEAL"
	local counted, why, icon
	if over or out then
		counted, why, icon = Counts(plate, unit, school, flag, MINE.IsWord(event, amount), event, amount)
	end
	if not counted then
		return
	end
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(event, flag, amount, school)
	if not kind then
		return
	end
	local name
	if why == "extra slot" and kind == "amount" then
		-- The number has the colour of a swing, as in OnTarget. The Outgoing copy gets the same word: the flag EXTRA stands for it (ScrollText).
		r, g, b = Ability(why, school, r, g, b)
		suffix, flag = "(Extra attack)", "EXTRA"
	elseif kind == "amount" and event == "WOUND" then
		r, g, b, name = Ability(why, school, r, g, b)
		suffix = suffix or name
	end
	local shown = over and Spawn(plate, unit, kind, value, suffix, crit, r, g, b, nil, sign, nil, scale)
	if out and ns.ScrollText.Show("out", kind, value, name and ("%s " .. name:gsub("%%", "%%%%")) or "%s", crit, r, g, b, scale, Plain(flag, "string") and flag or nil, nil, icon) then
		shown = true
	end
	if shown and not proven then
		-- The game's rows are switched off only once a hit report has been shown.
		proven = true
		Sync()
	end
end

-- A plate that gets a unit starts its numbers again, and shows none from the unit before.
local function OnAdded(unit)
	plateOf.at = nil
	if Plain(unit, "string") then
		local plate = Plate(unit)
		if plate then
			count[plate] = nil
			for index = #live, 1, -1 do
				if live[index].plate == plate then
					Release(index)
				end
			end
		end
	end
end

-- A number whose plate goes stays where it was on screen. One whose place cannot be read goes with the plate.
local function OnRemoved(unit)
	plateOf.at = nil
	if Plain(unit, "string") then
		mine.aura[unit], mine.auraSlots[unit] = nil, nil
	end
	if #live == 0 then
		return
	end
	local now = GetTime()
	for index = #live, 1, -1 do
		local item = live[index]
		if item.plate and item.kind ~= "frame" and (ns.IsSecret(unit) or item.unit == unit) then
			local ok, x, y = pcall(item.text.GetCenter, item.text)
			if ok and Plain(x, "number") and Plain(y, "number") then
				local dx, dy = Offsets(item, now - item.start)
				item.screenX, item.screenY = x - dx, y - dy
				item.plate = nil
				if pcall(Place, item, now) then
					stats.kept = stats.kept + 1
				else
					stats.unplaced = stats.unplaced + 1
					Release(index)
				end
			else
				Release(index)
				stats.removed = stats.removed + 1
			end
		end
	end
end

-- Page, status and commands ------------------------------------------------------------------------------------------------

local function Refresh()
	Sync()
	if not (ns.Enabled(KEY) and Opt("source") == "front") then
		ReleaseKind("enemy")
	end
	if FriendMode() == "off" then
		ReleaseKind("friend")
	end
	for _, area in ipairs({ "out", "inc" }) do
		if not ns.ScrollText.On(area) then
			ns.ScrollText.Clear(area)
		end
	end
	MineFrame()
end

-- A change of the roster or of the pet: the frames are read again, and the numbers over a frame start their lanes again.
local function OnRoster()
	for _, frame in pairs(frames.byUnit) do
		count[frame] = nil
	end
	frames.byUnit, frames.at = {}, 0
	-- Joining or leaving a group hands the numbers over enemies to the game or back.
	if Opt("group") == "game" then
		pcall(Sync)
	end
end

-- A friendly plate the game keeps from addons.
local forbiddenSeen = {}
local function OnForbidden(unit)
	if Plain(unit, "string") then
		if forbiddenSeen[unit] then
			return
		end
		local ok, attackable = pcall(UnitCanAttack, "player", unit)
		if ok and Plain(attackable, "boolean") and attackable then
			return
		end
		forbiddenSeen[unit] = true
	end
	friend.forbidden = friend.forbidden + 1
end

local function OnForbiddenGone(unit)
	if Plain(unit, "string") then
		forbiddenSeen[unit] = nil
	end
end

-- True while the player's own numbers show, which is also when the movers have a handle for where they start.
function ns.CombatOwnShown()
	return ns.Enabled(KEY) and Opt("own") ~= "off"
end

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if Opt("source") == "front" then
		if proven then
			lines[#lines + 1] = ("Numbers in front of nameplates: %d shown."):format(stats.shown)
		else
			lines[#lines + 1] = "Numbers in front of nameplates: waiting for the first hit. The game's numbers show until then."
		end
		local whose = Opt("whose")
		if whose == "mine" or whose == "one" then
			if mine.off then
				lines[#lines + 1] = "Whose hits: none of your casts or swings reached Flat UI here, so the game's own numbers show."
			elseif whose == "one" then
				lines[#lines + 1] = ("Whose hits: one for each of your casts, swings, shots and auras. Left out as not yours: %d."):format(mine.left)
			else
				lines[#lines + 1] = ("Whose hits: every hit while you attack. Left out as not yours: %d."):format(mine.left)
			end
		end
		if GroupHand() and Read(VARS[1].name) ~= "0" then
			lines[#lines + 1] = "Numbers over enemies: in a group, the game's own numbers show."
		end
	end
	for _, line in ipairs(ns.ScrollText.Lines()) do
		lines[#lines + 1] = line
	end
	local mode = FriendMode()
	if mode ~= "off" then
		if friendProven then
			lines[#lines + 1] = ("Numbers over friendly units: %d shown."):format(friend.shown)
		elseif Opt("friendHeal") == "taken" then
			lines[#lines + 1] = "Numbers over friendly units: waiting for the first hit. The game's healing numbers show until then."
		else
			lines[#lines + 1] = "Numbers over friendly units: waiting for the first hit."
		end
		if (mode == "plates" or mode == "both") and Read("nameplateShowFriendlyPlayers") == "0" then
			lines[#lines + 1] = "Friendly Player Nameplates is off in the game's options."
		end
		if friend.forbidden > 0 then
			lines[#lines + 1] = ("Friendly nameplates the game hides from interface mods: %d. %s"):format(friend.forbidden,
				mode == "plates" and "No number shows there." or "Numbers show over party and raid frames there.")
		end
		if friend.group == 0 and stats.reports + own.reports > 0 and InGroup() then
			lines[#lines + 1] = "The game sent no hit reports for party or raid units. /flatui combat has the counts."
		end
		if friend.unknown > 0 then
			lines[#lines + 1] = ("Could not tell whether %d friendly numbers were on your target. They showed anyway."):format(friend.unknown)
		end
		if Opt("friendHeal") == "taken" then
			lines[#lines + 1] = "Shields over friendly units show in the game's own numbers."
		end
	end
	if Opt("own") ~= "off" then
		lines[#lines + 1] = ("Combat text for you: %d shown."):format(ns.ScrollText.Shown("inc"))
		if own.failed > 0 then
			lines[#lines + 1] = ("Hit reports for you that raised an error: %d. The first: %s"):format(own.failed, own.first)
		end
		if Read("enableFloatingCombatText") == "1" then
			lines[#lines + 1] = "Scrolling Combat Text for Self is ticked in the game's options, so your numbers show twice. /reload unticks it."
		end
	end
	if stats.amount > 0 then
		lines[#lines + 1] = ("Hit amounts the game would not tell: %d."):format(stats.amount)
	end
	if stats.kind > 0 then
		lines[#lines + 1] = ("Hit types the game would not tell: %d."):format(stats.kind)
	end
	if stats.unplaced + ns.ScrollText.Unplaced() > 0 then
		lines[#lines + 1] = ("Numbers the game would not position: %d."):format(stats.unplaced + ns.ScrollText.Unplaced())
	end
	if stats.unstyled > 0 then
		lines[#lines + 1] = ("Numbers the game would not set the font on: %d."):format(stats.unstyled)
	end
	return lines
end

local function Report()
	for _, var in ipairs(VARS) do
		local current = Read(var.name)
		if current == nil then
			print(("%s: not in this client"):format(var.name))
		else
			print(("%s: now %s, default %s, wanted %s"):format(var.name, current, GameDefault(var), Wanted(var) or "no change"))
			if var.name == "WorldTextScale_v2" then
				print(("Size of experience and other gains: %s%s."):format(GAIN_WORDS[Opt("gainSize")] or tostring(Opt("gainSize")), Switch() == "0" and "" or ", not in use"))
			end
		end
	end
	print(("classicStyleWorldText: %s"):format(Read("classicStyleWorldText") or "not in this client"))
	print(("At login: %s"):format(atLogin or "nothing remembered"))
	print(("Hit reports: %d for nameplates, %d for target."):format(stats.reports, stats.target))
	print(("Shown: %d. No nameplate: %d. On friendly units: %d. Report unreadable: %d."):format(stats.shown, stats.noPlate, stats.friendly, stats.detail))
	print(("Last hit report: %s"):format(Reported(last) or "none"))
	print(("Your hits: %d shown, %d left out. Casts and swings seen: %d. Auras the game would not tell about: %d. Last hit: %s."):format(mine.kept, mine.left, mine.heard, mine.blind, mine.last or "none"))
	local modes = { off = "Off", frames = "Party and raid frames", plates = "Friendly nameplates", both = "Both" }
	print(("Friendly numbers: %s. Hit reports: %d nameplate, %d party or raid, %d pet. Shown: %d. No frame or nameplate to show on: %d. Repeated reports skipped: %d. Target check failed: %d. Nameplates the game hides from interface mods: %d."):format(
		modes[Opt("friend")] or tostring(Opt("friend")), friend.plates, friend.group, friend.pet, friend.shown, friend.noAnchor, friend.same, friend.unknown, friend.forbidden))
	print(("Last friendly hit report: %s"):format(Reported(friend.last) or "none"))
	print(("Friendly nameplate variables: players %s, pets %s, minions %s, NPCs %s."):format(Read("nameplateShowFriendlyPlayers") or "not known",
		Read("nameplateShowFriendlyPlayerPets") or "not known", Read("nameplateShowFriendlyPlayerMinions") or "not known", Read("nameplateShowFriendlyNpcs") or "not known"))
	if FriendMode() ~= "off" and Opt("friendHeal") == "taken" then
		print(("The game's setting %s goes to 0 with the first friendly number. Changing Where friendly numbers show or Healing over friendly units, turning the page off, logging out and /flatui combat reset put it back."):format(HEAL_VAR))
	end
	print(("Nameplate layer: %s. Numbers layer: %s."):format(plateStrata or "none", hostStrata or "none"))
	if Classic() then
		local seconds = math.floor(CLASSIC.life * Opt("classicTime") / 100 * 100 + 0.5) / 100
		print(("Style: Classic, rise %g, %g s, %s. Started in column: %d middle, %d right, %d left."):format(Opt("classicRise"), seconds,
			Opt("classicStack") == "down" and "new numbers start lower" or "older numbers move up", stats.columns[0], stats.columns[1], stats.columns[-1]))
	end
	print(("Numbers kept after their nameplate went: %d. Removed with it: %d."):format(stats.kept, stats.removed))
	-- The look in use, as the game answers for its font object, and the flags the game's own outlines give.
	local name = Look().name
	local file, height, flags = FromGame(name)
	print(("Font: %s, %s, flags %s."):format(file or "not known", height and ("%g"):format(height) or "not known", flags == nil and "not known" or (flags == "" and "none" or flags)))
	local _, _, thick = FromGame(LOOK.outlines.thick[1])
	local _, _, thin = FromGame(LOOK.outlines.thin[1])
	print(("Outline styles from the game: thick %s, thin %s."):format(
		thick ~= nil and thick ~= "" and ('"%s"'):format(thick) or "none read", thin ~= nil and thin ~= "" and ('"%s"'):format(thin) or "none read"))
	print(("Font size made at: %d."):format(Raster()))
	if stats.width then
		print(("Width of the last number: %g%s. Height drawn: %g."):format(stats.width, stats.estimated and " (3 times its height when the game gave none)" or "", stats.drawn))
	else
		print("Width of the last number: no number drawn yet.")
	end
	print(("Hit reports for you: %d. Shown: %d."):format(own.reports, ns.ScrollText.Shown("inc")))
	print(("Last hit report for you: %s"):format(Reported(own.last) or "none"))
	print(("Hits shown in the Outgoing scroll area: %d."):format(ns.ScrollText.Shown("out")))
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(OWN.mover, "CENTER")
	end
	print(x and ("Start of your text: %g, %g."):format(x, y) or "Start of your text: not known.")
	x, y = nil, nil
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot("FlatUICombatOut", "CENTER")
	end
	print(x and ("Start of your hits: %g, %g."):format(x, y) or "Start of your hits: not known.")
	local scale, world = WorldScale()
	local length = ns.CombatShape.scroll.length
	print(world and ("Game world height is %g: the scroll areas are %g long."):format(world, length * scale)
		or ("Game world height is not known: the scroll areas are %g long."):format(length))
end

-- Four sample numbers over the target's plate, a quarter of a second apart. They are not hit reports: the counters they raise
-- are put back.
-- The fifth value of the first one is true: in the Outgoing scroll area it shows the icon of a swing.
local SAMPLES = { { "WOUND", "", 412, 1, true }, { "WOUND", "GLANCING", 412, 1 }, { "WOUND", "CRITICAL", 824, 1 }, { "DODGE", "", 0, 1 } }

local function Sample(sample)
	local plate = Plate("target")
	if not plate then
		return
	end
	local kinds, amounts, shown = stats.kind, stats.amount, stats.shown
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(sample[1], sample[2], sample[3], sample[4])
	if kind then
		Spawn(plate, false, kind, value, suffix, crit, r, g, b, nil, sign, nil, scale)
	end
	stats.kind, stats.amount, stats.shown = kinds, amounts, shown
end

-- Samples for the player's own text, at the handle: damage, a critical hit, healing, a dodge and a gain. Over the choice Damage and
-- healing you take the last two show nothing. They are not hit reports either.
local OWN_SAMPLES = { { "WOUND", "", 412, 1 }, { "WOUND", "CRITICAL", 824, 4 }, { "HEAL", "", 300, 1 }, { "DODGE", "", 0, 1 }, { "ENERGIZE", "", 20, 1 } }

local function OwnSample(sample)
	local kinds, amounts = stats.kind, stats.amount
	local kind, value, format, crit, r, g, b = Describe(sample[1], sample[2], sample[3], sample[4], Opt("own"))
	if kind then
		ns.ScrollText.Show("inc", kind, value, format, crit, r, g, b, nil, sample[2], true)
	end
	stats.kind, stats.amount = kinds, amounts
end

-- The same four samples in the Outgoing scroll area.
local function OutSample(sample)
	local kinds, amounts = stats.kind, stats.amount
	local kind, value, _, crit, r, g, b, _, scale = Describe(sample[1], sample[2], sample[3], sample[4])
	if kind then
		ns.ScrollText.Show("out", kind, value, "%s", crit, r, g, b, scale, sample[2], true, sample[5] and Opt("icons") ~= "off" and Icon(6603) or nil)
	end
	stats.kind, stats.amount = kinds, amounts
end

-- Shows a list of samples a quarter of a second apart, the first at once.
local function Run(samples, show)
	for index, sample in ipairs(samples) do
		if index > 1 and C_Timer and C_Timer.After then
			C_Timer.After(0.25 * (index - 1), function()
				ns.Try(KEY, show, sample)
			end)
		else
			ns.Try(KEY, show, sample)
		end
	end
end

-- Samples over a friendly unit: damage, a heal, a critical heal and a miss. They are not hit reports either.
local FRIEND_SAMPLES = { { "WOUND", "", 312, 1 }, { "HEAL", "", 180, 1 }, { "HEAL", "CRITICAL", 540, 1 }, { "WOUND", "", 0, 1 } }

-- The plate or frame the friendly samples go over, and true for a frame: the plate of a friendly target, else the frame of the first
-- party member, else the pet's. Nil when there is none.
local function FriendAnchor()
	local mode = FriendMode()
	if mode == "plates" or mode == "both" then
		local plate = Plate("target")
		if plate then
			local ok, attackable = pcall(UnitCanAttack, "player", "target")
			if ok and Plain(attackable, "boolean") and not attackable then
				return plate, false
			end
		end
	end
	if mode == "frames" or mode == "both" then
		local frame = FrameOfUnit("party1") or FrameOfUnit("pet")
		if frame then
			return frame, true
		end
	end
	return nil
end

local function FriendSample(anchor, onFrame)
	return function(sample)
		local kinds, amounts, shown = stats.kind, stats.amount, friend.shown
		local kind, value, suffix, crit, r, g, b, sign, scale = Describe(sample[1], sample[2], sample[3], sample[4], nil, true)
		if kind then
			Spawn(anchor, false, kind, value, suffix, crit, r, g, b, "friend", sign, onFrame, scale)
		end
		stats.kind, stats.amount, friend.shown = kinds, amounts, shown
	end
end

local function Test()
	if not ns.Enabled(KEY) then
		print("Place combat numbers is off.")
		return
	end
	if Opt("own") ~= "off" then
		Run(OWN_SAMPLES, OwnSample)
	else
		print("Combat text for you is off.")
	end
	if ns.ScrollText.On("out") then
		Run(SAMPLES, OutSample)
	end
	if Opt("where") == "scroll" then
		-- No numbers over enemies to sample.
	elseif Opt("source") ~= "front" then
		print("Numbers over enemies is set to As the game has them.")
	elseif not Plate("target") then
		print("Target an enemy with a nameplate to see numbers over it.")
	else
		Run(SAMPLES, Sample)
	end
	if FriendMode() == "off" then
		print("Where friendly numbers show is Off.")
		return
	end
	local anchor, onFrame = FriendAnchor()
	if not anchor then
		print("Target a friendly unit with a nameplate, or join a group, to see numbers over friendly units.")
		return
	end
	if Opt("friendHeal") ~= "taken" then
		print("Healing over friendly units is not Healing they take from anyone: no heal samples.")
	end
	Run(FRIEND_SAMPLES, FriendSample(anchor, onFrame))
end

-- Puts the game's values back: the page goes off, which writes back what was remembered, and every variable that still differs
-- from the client's default is written to it.
local function Reset()
	ns.Set(KEY .. ".enabled", false)
	if ns.NotifyOption then
		ns.NotifyOption(KEY .. ".enabled")
	end
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	local refused = 0
	if Calls() then
		for _, var in ipairs(VARS) do
			local current, default = not var.keep and Read(var.name) or nil, GameDefault(var)
			if current ~= nil and not Same(current, default) then
				local held = Write(var, default)
				if held ~= nil and Same(held, default) then
					print(("%s: %s"):format(var.name, default))
				else
					refused = refused + 1
					-- A value that changed to something else than asked is the game's own; one that did not change was refused.
					if held ~= nil and not Same(held, current) then
						print(("%s: the game keeps %s for %s."):format(var.name, held, default))
					else
						print(("%s: the game refused %s."):format(var.name, default))
					end
				end
			end
		end
	end
	local db = ns.Account()
	if db then
		-- A variable the player owns keeps its record until the game's value is back, so that a write refused now is made later.
		local kept
		for _, var in ipairs(VARS) do
			local rec = var.keep and db.cvars and db.cvars[var.name]
			if rec and not Same(Read(var.name), rec.game) then
				kept = kept or {}
				kept[var.name] = rec
			end
		end
		db.cvars = kept
	end
	local owned = VARS[#VARS]
	if refused > 0 then
		print(("Place combat numbers: off. The game did not take %d of the defaults."):format(refused))
	elseif owned.keep and Calls() and Read(owned.name) ~= nil and not Same(Read(owned.name), GameDefault(owned)) then
		print("Place combat numbers: off. The game's defaults are back, except Scrolling Combat Text for Self, which stays as you have it.")
	else
		print("Place combat numbers: off. The game's defaults are back.")
	end
end

local HELP = {
	"/flatui combat - the game's combat number settings: now, default, wanted",
	"/flatui combat test - sample numbers for you, over your target and over friendly units",
	"/flatui combat reset - the game's defaults, and Place combat numbers off",
	"/flatui combat trace - each hit report and signal of yours in chat, until you type it again",
}

local function Command(rest)
	local word = rest:lower()
	if word == "" then
		Report()
	elseif word == "test" then
		Test()
	elseif word == "reset" then
		Reset()
	elseif word == "trace" then
		mine.trace = not mine.trace
		print(mine.trace and "Combat trace on." or "Combat trace off.")
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

ns.Register(KEY, {
	label = "Combat text",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	events = {
		UNIT_COMBAT = OnCombat,
		NAME_PLATE_UNIT_ADDED = OnAdded,
		NAME_PLATE_UNIT_REMOVED = OnRemoved,
		GROUP_ROSTER_UPDATE = OnRoster,
		UNIT_PET = OnRoster,
		FORBIDDEN_NAME_PLATE_UNIT_ADDED = OnForbidden,
		FORBIDDEN_NAME_PLATE_UNIT_REMOVED = OnForbiddenGone,
		PLAYER_LOGOUT = Leave,
	},
	slash = { combat = Command },
	help = HELP,
	Status = Status,
})

-- A module whose page is off is never started, so a record left by a character whose page was on is put back here.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	if ns.Account() and not ns.Enabled(KEY) then
		pcall(Sync)
	end
end)
