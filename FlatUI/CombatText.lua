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
-- The combat alerts of the page, No target and +Combat and -Combat, are CombatCues.lua.
-- UNIT_COMBAT names no source and no spell, and this client gives addons no exact source of the player's own hits (see MINE below), so which
-- hits over enemies are yours is judged from plain signals of your own (Whose hits, MINE): every hit on an enemy that you or your pet hold, that
-- nobody else has tapped and that no other member of your group fights is yours, and anywhere else each cast, swing, shot, aura and pet swing of
-- yours and each hit that strikes you under Retaliation lets one hit in; on both, the slot a hit takes names it. A report waits MINE.hold
-- seconds, so a cast, a swing and a hit sent together count in any order. It cannot know whose hit it is when a player outside your group hits
-- an enemy you hold, nor, in a group, a proc that casts nothing.

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
-- Whose hits. No exact source of the player's own hits is open to addons on this client (Interface 16001), checked in the client's lists
-- (wowless data/products/wowf: apis.yaml, events.yaml) and Ketho's dump of it (Resources/GlobalAPI.lua, Events.lua):
--  * the combat log is closed: COMBAT_LOG_EVENT_UNFILTERED is a restricted event (events.yaml), CombatLogGetCurrentEventInfo is in neither
--    list, and its event info is read only through C_CombatLogSecure.GetCurrentEventInfo, which is secure only (apis.yaml secureonly, the
--    environment SecureOnly of CombatLogSecureDocumentation.lua:3-6) and not in Ketho's GlobalAPI.lua;
--  * UNIT_COMBAT gives the unit, the kind of report, its flag and its school mask plainly and the amount withheld, and has no field for the
--    source or the spell (UnitDocumentation.lua:4167-4180);
--  * the game's own floating text (COMBAT_TEXT_UPDATE with C_CombatText.GetCurrentEventInfo, CombatTextDocumentation.lua:21-28, 45-53) is about
--    the active unit, the player or the vehicle, and its returns are withheld; it says nothing of hits the player makes;
--  * the game's damage meter (C_DamageMeter) gives, for each source of a fight, its spells with their spell ID and total
--    (GetCombatSessionSourceFromType, DamageMeterDocumentation.lua:77-95; combatSpells, 183-226), but no single hit, no time of a hit and no
--    target of one, and its event DAMAGE_METER_COMBAT_SESSION_UPDATED names only the kind of meter and the session (133-142). Its calls are
--    SecretWhenInCombat (line 79): withheld while the combat addon restriction is in effect (SecretPredicatesDocumentation.lua:95-98), which is
--    while the player is in a fight (RestrictedActionsConstantsDocumentation.lua:26), and spellID and totalAmount are not NeverSecret (220-221).
--    Addon code cannot compare or subtract a withheld value, so in a fight it cannot see which spell's total grew, and the meter cannot tell
--    the spell of a single hit there. On this client the game withholds stats, cooldowns and debuff types in a fight as well.
--  * Details! on this client (Details_Camelot.toc, Interface 16001) reads that meter and not the combat log (core/parser_nocleu1.lua): in a
--    fight it passes the meter's withheld totals to its bars as they are, and after the fight it copies each spell's total into its own
--    segments. It never sees a single hit, so it never has to say which spell made one: its numbers are the game's own totals for each spell.
-- What Flat UI does: it takes each number, its kind, its school and the enemy it hit from UNIT_COMBAT, which the meter cannot give, and judges
-- whose hit it is and which spell made it from your own casts, swings and auras (the signals below), as nothing on this client names them.
-- Where that cannot tell, as for a swing and a strike that land together while the game withholds their amounts, the hit shows with no spell
-- name or icon rather than a wrong one (MINE.Rival).
-- A hit counts as yours from signals about you that are plain: a cast of yours or your pet's (UNIT_SPELLCAST_*, plain for the player and their
-- pet, SecretPredicatesDocumentation.lua:115-118), each swing and shot of yours (PLAYER_SWING with its length and its hand, SwingTimerDocumentation.lua:43-52),
-- your auto-attack and auto-repeat (PLAYER_ENTER_COMBAT, START_AUTOREPEAT_SPELL, as the game's attack button follows them, ActionButton.lua:1018-1031),
-- a harmful aura of yours on the enemy (the filter string of CooldownViewerItemData.lua:716-724), a hit that strikes you (UNIT_COMBAT for the player),
-- your pet's fight and speed (UnitAffectingCombat, UnitAttackSpeed), and the enemy's threat table and tap: UnitThreatSituation of the player, the pet
-- or an ally against a nameplate is plain (SecretPredicatesDocumentation.lua:160-163, UnitDocumentation.lua:3279-3294), and so is UnitIsTapDenied
-- (UnitDocumentation.lua:2365). The events heard are for the player and the pet (UnitDocumentation.lua:4614, 4628, 4818, 4846) and about the player's
-- own attack (UnitDocumentation.lua:3770, 3814, SpellBookDocumentation.lua:974, 980), the swing and the zone. A gain of an aura is no signal: UNIT_AURA
-- and GetPlayerAuraBySpellID are secret in a fight (UnitAuraDocumentation.lua:395-399, 647-656).
-- Yours (whose "one") judges a report on an enemy in one of two ways. Engaged: an enemy nobody else has tapped that you or your pet hold
-- (UnitThreatSituation 2 or 3 of the player, or of the pet while one is out), or a creature that a slot of yours hit in the last `engaged` seconds
-- while you are on no threat table of it yet (the first hit can come before the threat update), is yours when you are alone, and in a party while
-- no other member or member's pet is on its threat table (no raid is read): every damage hit and miss word on it shows, your pet's too, and the
-- slots below only name it, with nothing counted as left out. On any other enemy, and for a heal on an enemy, the slots decide: each action of yours
-- opens a slot and a hit fills one free slot. A report waits `hold` seconds (Flush), so a cast, a swing and a hit that the game sends in one frame or
-- a few frames apart count in any order, or until its plate goes, as the hit that kills an enemy comes just before. A physical report waits with
-- the first physical report on its enemy that came at most `hold` seconds before it, and they are judged together (Wait).
-- A successful cast of yours or your pet's is looked up by its name in ns.CombatSpells (CombatTextSpells.lua, the classic class abilities cast on
-- an enemy, so every rank and language): a spell that hits (kind hit, both or area) opens a cast slot of its school for cast seconds, or travel
-- seconds when its missile flies, and the slot of an area spell takes up to areaMax hits of its school, on your target and on the enemies around
-- it; the slot of a spell of your pet's takes its hit on the enemy your pet attacks (pettarget), not on yours; a damage-over-time spell (dot or
-- both) is recorded on the plate of your target (your pet's for the pet) with its school, icon and time, for dotKeep seconds or until the list of
-- your auras on that enemy reads none (not in the first travel seconds, while its aura may not be on yet); a channel takes only the hits of its
-- school, on your target, and on every enemy for an area channel (area: Blizzard, Hurricane, Rain of Fire, Volley, Hellfire); a spin (The Ravager's
-- Bladestorm) takes one physical hit on each enemy at each of its ticks, spinSlack seconds either side, and a cast of the spell it casts at a tick
-- (its trigger, 9633 Whirlwind) moves the ticks to it and opens no slot (SpinTick); a sweep (Sweeping Strikes) takes, for its duration and up to its
-- charges, one physical hit on another enemy within swingTake seconds of a melee strike of yours (Struck), and a cast of its name while it lasts
-- starts no other; a counter (Retaliation) takes, for its duration and up to its charges, one physical hit on any enemy from `late` seconds before
-- to swingTake seconds after each physical hit that strikes you (OnStruck), and a cast of its name while it lasts, its counterattack, opens no
-- slot; and a spell that does no damage (none), such as a mark, a curse that only weakens, a shout or a totem, opens nothing.
-- A spell not in the table opens an area slot of any school only when the game plainly says it is harmful (C_Spell.IsSpellHarmful,
-- SpellDocumentation.lua:900-913), and a channel of one takes any hit on your target only then. A hit takes a cast slot whose school shares a bit
-- with its own (bit.band): a slot of unknown school takes any hit, and a hit whose school is withheld takes only such a slot. Of those, a fresh
-- slot goes first, the slot of a spell that does not fly whose hit comes from `late` seconds before its cast to `fresh` seconds after it, so two
-- spells of one school cast close together (Fire Blast while a Fireball flies) each take their own hit; then the oldest.
-- A swing of yours and a physical strike of yours on one enemy within `hold` seconds of each other (a swing in the global cooldown of Hamstring)
-- each fit the other's slot, and the game names neither hit and sends them in either order, so taking them in order gave the swing's hit the
-- strike's name and icon and the strike's hit the swing's. One rule decides them (MINE.Rival): a strike with a weapon part (damage "weapon" in
-- ns.CombatSpells, such as Mortal Strike or Sinister Strike) takes the larger amount and the swing the smaller, and a strike of a fixed damage
-- (damage "flat": Hamstring, Wing Clip, Pummel, Shield Bash, Kick, Gouge and their like) the smaller and the swing the larger. When the amounts
-- are not all plain numbers (from build 70755 the game withholds every amount, and a withheld amount cannot be compared), when two of them are
-- the same, or when the strike is neither, the hits show as yours with no spell name and no icon, in the colour of their school.
-- A swing of yours the game reports (PLAYER_SWING) opens a slot for one physical hit on your target, from `late` seconds before it (the hit may
-- come first) to swingTake seconds after it, and a shot one for cast seconds, as its arrow flies; a main-hand swing within `extra` seconds of the one
-- before is an extra attack. Until the game has reported a melee swing, each hand has a slot that frees swingShare of its speed after it was used
-- (UnitAttackSpeed, UnitDocumentation.lua:682-697), and a shot the same by UnitRangedDamage (UnitDocumentation.lua:2962-2974), which a shot with no
-- reported swing of its own also falls back on. Your pet's melee casts nothing and has no swing event: while it fights (UnitAffectingCombat), a
-- physical hit on the enemy it attacks takes its slot, which frees swingShare of the pet's attack speed after it was used, unless a fresh cast slot
-- fits the hit. Each harmful aura of yours, up to auraMax, takes one hit in each window of swingShare x auraTick seconds (auraTick 2 seconds, so
-- that a damage over time that ticks every 2 seconds loses no tick, where 3 seconds dropped every other one): with damage over time of
-- yours recorded on the enemy, a hit of the school of one of them gets that spell's icon when it is the only one of that school (with no record,
-- such as a spell cast before a reload, any hit). A word that no tick can be (`words`: a miss, dodge, parry, full block, evade, deflect, reflect or
-- interrupt) takes no aura slot. On the target plate a swing slot is tried first. A non-critical hit then tries the cast slot first when a fresh
-- cast slot fits it, or when its school fits an open cast slot and no recorded damage over time, the aura slot first when it is the other way
-- round, and else an aura slot and then the cast slot, which stays for the hit of a spell that flies, which can be critical. A critical hit tries
-- the cast slot first and an aura slot last: a tick can be critical on this client (Forever's row of Rend: "periodic can crit").
-- extra: also the seconds after a swing slot in which one more physical hit is an extra attack, alone with no pet out, when no cast slot is open,
-- no aura of yours is on the enemy, no other player hits it (Crowded, which only this slot asks) and no tick of a spin takes the hit. swingGap is
-- the speed used when the game withholds it.
-- nextSwing: the first rank of Maul, Heroic Strike, Cleave and Raptor Strike. A cast of one of them (by name, so every rank and language) opens its
-- pair (OpenPair) and no cast slot: two physical reports on your target, its hit and the swing it replaced, which the game reports as a hit of 0
-- that cannot be told from the hit and may come first, and for Cleave (targets 2 in ns.CombatSpells) one on another enemy in melee range of you
-- (C_Spell.IsSpellInRange, SpellDocumentation.lua:947-963). The pair is bound to the main-hand swing reported with the cast or after it, and takes
-- reports from `late` seconds before that swing to pairTail after it. With no swing reported yet: a pair cast when the key was pressed (its
-- main-hand swing due more than pairTail later by the swing timer) waits for that swing and takes reports only from swingTake seconds before it is
-- due, so an off-hand swing, a tick or another player's hit in between is not taken for it; any other takes them up to pairTail after the cast, or
-- for cast seconds while the game has reported no melee swing at all. It waits for its swing until the next main-hand swing the swing timer has due
-- and pairTail, at least cast and at most nextMax seconds, so it works whether the game sends the cast when the key is pressed or at the swing. The
-- two reports of a pair judged together are drawn as one number, and the client writes the 0 as nothing (ns.CombatWithheld), its name and icon too.
-- travel (3 seconds: a Firebolt flies 16 yards a second and a Shadow Bolt 20, SpellMisc Speed), areaMax (10 enemies), dotKeep (30 seconds, the
-- length of most classic damage over time) and the other numbers here are chosen by eye, not the game's: cast is the seconds after a cast that its
-- slot is open, fresh the seconds after a cast that its hit is its own, tail the seconds after a channel ends, aura the seconds an answer about the
-- auras of an enemy is kept, offAfter the hit reports in combat with no signal heard that switch the estimate off, engaged the seconds a hit in a
-- slot of yours ties an enemy to you, hold the seconds a report waits, and queueMax the most reports that wait at once.
-- It is still a guess where the slots decide. The game names no spell and no source for a hit, so the match goes by school, kind and time: two
-- spells of yours of one school cast at once, or a hit of another player of the school of a slot of yours, cannot be told apart, and the damage
-- over time of a weapon poison or a proc is not cast, so it is never recorded and borrows the name of a recorded one of its school. Engaged cannot
-- tell a player outside your group who hits an enemy you hold, and in a group a proc that casts nothing (fire or shadow from a weapon, Sword
-- Specialization, a spin the game does not report) only takes a free slot or is left out.
-- heard: signals heard. blind: answers the game withheld. left and kept: hits left out and shown. unheard: reports in combat with no signal
-- heard. off: the estimate is off and the game's own numbers show. deaf: no cast event could be registered. last: the last decision, as
-- text, with the school of the hit and the spell it was matched to. castAt: when the last cast or channel ended. on: the frame that hears
-- the signals is registered. queue: the reports waiting.
-- castSlots holds each open cast slot in the order made: { at = when it closes, from = when it was cast, travel = true for a spell that flies,
-- pet = true for a spell of your pet's, school (nil for any), icon (false for none), area = true for an area spell, left = hits it takes yet,
-- name, damage (the strike's in ns.CombatSpells, none for your pet's) }. dots holds the damage over time recorded on each plate (or token) as
-- { school, icon, name, at }.
-- swings holds each swing and shot the game reported in the last travel seconds as { at, hand (main, off or ranged), extra, left }, due the time
-- the next swing of each hand is due and lastMain the last main-hand swing; swingHeard and rangedHeard are true once a melee swing and a shot
-- were reported, and swingCount counts the reports. pair is the open pair { name, icon (false for none), spell, opened, bound (the time of its
-- swing), due (the time the swing timer has its swing due), waits, close, left, other }, spin the spin { name, icon, start, period, ticks, taken
-- (the enemies hit at each tick) }, sweep the sweep { name, icon, close, left } and counter the counter { name, icon, close, left }, with struckAt
-- the times of the hits that struck you while it lasts; strikeAt is when you last cast a physical strike, petAt when the pet's swing slot was last
-- taken, and hitBy holds when a slot last took a hit on each plate (or token). chanIcon, chanName and chanSchool are those of the channel, chanTakes
-- is true when it does damage and chanArea when it hits every enemy; healIcon is the icon of a helpful cast of yours until healUntil, swingIcon and
-- shotIcon those of a swing and a shot.
local MINE = { cast = 1.5, travel = 3.0, areaMax = 10, dotKeep = 30, shots = { [75] = true, [2480] = true, [7918] = true, [2764] = true, [7919] = true, [5019] = true }, tail = 0.5, aura = 0.5, offAfter = 10, swingGap = 1.0, tick = 3.0, swingShare = 0.8, auraMax = 4, extra = 0.4, nextSwing = { 6807, 78, 845, 2973 },
	late = 0.1, swingTake = 0.3, pairTail = 0.4, nextMax = 5, spinSlack = 0.6, engaged = 10, queueMax = 200, fresh = 0.3, auraTick = 2.0, hold = 0.1,
	words = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, EVADE = true, DEFLECT = true, REFLECT = true, INTERRUPT = true },
	partyTokens = { "party1", "partypet1", "party2", "partypet2", "party3", "partypet3", "party4", "partypet4" },
	unitEvents = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" },
	plainEvents = { "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTERING_WORLD", "PLAYER_SWING" } }
local mine = { castUntil = -1, castAt = 0, on = false, deaf = false, chan = false, swing = false, shoot = false, aura = {}, heard = 0, blind = 0, left = 0, kept = 0,
	unheard = 0, off = false, last = nil, castSlots = {}, castTaken = -1, hand = { main = -math.huge, off = -math.huge }, shotAt = -math.huge, shotEnd = -math.huge, auraSlots = {}, swingAt = -math.huge, extraUsed = false,
	dots = setmetatable({}, { __mode = "k" }), chanTakes = false, chanArea = false, healUntil = -1, trace = false, crowd = setmetatable({}, { __mode = "k" }),
	swings = {}, swingHeard = false, rangedHeard = false, swingCount = 0, lastMain = -math.huge, due = {}, hitBy = setmetatable({}, { __mode = "k" }), queue = {},
	strikeAt = -math.huge, counter = nil, struckAt = {}, petAt = -math.huge }
-- How long a target counts as hit by others after a physical hit on it was left out: its extra attack slot stays closed meanwhile. In the open
-- world players who are not in your group hit the same enemy, and a swing of theirs right after yours looks like an extra attack.
MINE.crowd = 10

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
-- The variable sizes all of the game's world text: its numbers over enemies and the text it draws near you, such as experience.
-- While Flat UI draws the numbers over enemies (Switch is "0") the world text left is what Flat UI does not draw, so Size of
-- experience and other gains sets it. In a group with the game's own numbers (GroupHand) it sets it as well, so that text keeps its
-- size as you join or leave a party or raid, and the game's numbers over enemies take that size there. Smaller than your text is the
-- share the game gives words on the portrait (CombatFeedback.lua:54).
local GAIN_SMALLER = 0.75
local GAIN_WORDS = { own = "Same as your text", smaller = "Smaller than your text", game = "The game's own size", enemy = "Same as numbers over enemies" }
local function Size()
	local percent = Opt("size")
	if Switch() == "0" or GroupHand() then
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
-- (CombatOverrides.lua:53, Blizzard_Settings.lua:667-679), so the game's text does not load at all. A change during a session goes through
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
-- (the client's res/GlobalStrings/enUS.lua:22755, 22757, 2550, 89, 18682). An extra swing's (Extra attack) is not one: it goes with its number,
-- as a name does (Fill, and Fill in ScrollText.lua).
local function Suffix(flag)
	if Opt("partial") ~= "word" then
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

-- The text of an amount the game withholds, made by the client: its digits with before and after joined to them, or an empty text for a
-- zero amount, so a full absorb or resist draws no number. C_StringUtil.TruncateWhenZero and WrapString take withheld values from addon code
-- (StringUtilDocumentation.lua:188-219). The digits are not grouped: no call that takes a withheld value both groups the digits and leaves
-- zero out. Returns true and the text, or false when the client lacks the calls or refuses them. before and after are plain strings or nil.
function ns.CombatWithheld(value, before, after)
	local util = C_StringUtil
	if type(util) ~= "table" or type(util.TruncateWhenZero) ~= "function" then
		return false
	end
	local ok, digits = pcall(util.TruncateWhenZero, value)
	if not ok or not (ns.IsSecret(digits) or type(digits) == "string") then
		return false
	end
	if before == nil and after == nil then
		return true, digits
	end
	if type(util.WrapString) ~= "function" then
		return false
	end
	local wrapped
	ok, wrapped = pcall(util.WrapString, digits, before, after)
	if not ok or not (ns.IsSecret(wrapped) or type(wrapped) == "string") then
		return false
	end
	return true, wrapped
end

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
-- From build 70755 the game withholds every amount (UnitDocumentation.lua:4178), so a hit of no amount can no longer be told from the
-- amount. A full block still has a flag of its own: CombatFeedback.lua:51-60 shows BLOCK as a word and a partial block is BLOCK_REDUCED, so
-- WOUND with BLOCK is the word. A full absorb or resist shares its flag with a partial one: it goes through the amount, which the client
-- writes as nothing when it is zero (ns.CombatWithheld), and the word of Partial effects stays.
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
	local none = (not withheld and amount == 0) or (withheld and event == "WOUND" and flag == "BLOCK")
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

-- Fills a font string with one number and places it. True when it is placed, false when the number is not shown. An error goes up. name is
-- the name of an ability or (Extra attack), which follows the amount before extra. value2 is the other report of a next melee ability, a
-- withheld amount drawn in the same text.
local function Fill(item, plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale, name, value2)
	local friendly = class == "friend"
	local text = item.text
	if kind == "word" then
		text:SetText(value)
	else
		-- A withheld amount is written by the client with its sign and the name after it, and as nothing when it is zero, so a zero draws no
		-- name or (Extra attack) either; the partial effect stays outside, so a full absorb or resist shows only the word after it. value2 is
		-- written the same way beside it, with a space in front that the client writes only with its digits: of the two reports of a next melee
		-- ability one is the swing it replaced, a zero, which adds nothing, and two that are not zero (another hit took a place) stay two numbers.
		local done, withheld = false, nil
		if ns.IsSecret(value) then
			local after = name and (" " .. name) or nil
			if extra then
				after = (after or "") .. " "
			end
			done, withheld = ns.CombatWithheld(value, sign, after)
			if done then
				local other
				if ns.IsSecret(value2) then
					local joined
					joined, other = ns.CombatWithheld(value2, " " .. (sign or ""), after)
					if not joined then
						other = nil
					end
				end
				text:SetFormattedText("%s%s%s", withheld, other or "", extra or "")
			end
		end
		if not done then
			local shown = value
			if type(BreakUpLargeNumbers) == "function" then
				local ok, broken = pcall(BreakUpLargeNumbers, value)
				if ok and (ns.IsSecret(broken) or broken ~= nil) then
					shown = broken
				end
			end
			text:SetFormattedText((sign or "") .. "%s%s", shown, (name and (" " .. name) or "") .. (extra and (" " .. extra) or ""))
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
	-- The width the game gives the text, or three times its height (four more with a word after it, and half a height for each letter of a
	-- name) when it gives none.
	local ok, width = pcall(text.GetStringWidth, text)
	item.estimated = not (ok and Plain(width, "number") and width > 0) or nil
	item.w = not item.estimated and width or (3 + (extra and 4 or 0) + (name and 0.5 * #name or 0)) * height
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
-- the font string and never compared, indexed, counted or joined to text. extra is what follows the amount, name the name before it and
-- value2 a second withheld amount drawn in the same text (Fill). An error while the font string is filled puts it back in its pool.
local function Spawn(plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale, name, value2)
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
	local ok, shown = pcall(Fill, item, plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale, name, value2)
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

-- The entries of ns.CombatSpells (CombatTextSpells.lua) by the name the client gives the first rank, so that every rank and every language of a
-- spell matches. Made at load from plain names only; when the client gave none then, it is made again at the next cast.
MINE.byName = {}
function MINE.SpellNames()
	if next(MINE.byName) ~= nil or type(ns.CombatSpells) ~= "table" or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return MINE.byName
	end
	for id, entry in pairs(ns.CombatSpells) do
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and Plain(name, "string") and name ~= "" then
			MINE.byName[name] = entry
		end
	end
	return MINE.byName
end
MINE.SpellNames()

-- The entry of a spell in ns.CombatSpells and the spell's name, found by the name (SpellDocumentation.lua:516-532). The entry is nil for a spell
-- not in the table, and both are nil for an id or a name the game withholds.
function MINE.SpellOf(id)
	if not Plain(id, "number") or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return nil, nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if not ok or not Plain(name, "string") then
		return nil, nil
	end
	return MINE.SpellNames()[name], name
end

-- True only when the game plainly says the spell can be cast on an enemy (C_Spell.IsSpellHarmful, SpellDocumentation.lua:900-913).
function MINE.Harmful(id)
	if type(C_Spell) ~= "table" or type(C_Spell.IsSpellHarmful) ~= "function" then
		return false
	end
	local ok, harmful = pcall(C_Spell.IsSpellHarmful, id)
	return ok and Plain(harmful, "boolean") and harmful
end

-- True when a hit of the school mask hit can be one of a spell of the school mask slot: the two masks share a bit. A slot of unknown school (nil)
-- fits any hit, and a hit whose school is withheld fits only such a slot.
function MINE.SchoolFits(slot, hit)
	if slot == nil then
		return true
	end
	if not Plain(hit, "number") then
		return false
	end
	if type(bit) ~= "table" or type(bit.band) ~= "function" then
		return slot == hit
	end
	return bit.band(slot, hit) ~= 0
end

-- The schools of a mask in words (LuaEnum.lua:2538), for the decision text and the trace.
MINE.schoolWords = { { 1, "physical" }, { 2, "holy" }, { 4, "fire" }, { 8, "nature" }, { 16, "frost" }, { 32, "shadow" }, { 64, "arcane" } }
function MINE.SchoolWords(mask)
	if not Plain(mask, "number") then
		return "withheld"
	end
	local words = {}
	for _, pair in ipairs(MINE.schoolWords) do
		if mask == pair[1] then
			return pair[2]
		elseif type(bit) == "table" and type(bit.band) == "function" and bit.band(mask, pair[1]) ~= 0 then
			words[#words + 1] = pair[2]
		end
	end
	return #words > 0 and table.concat(words, " and ") or ("mask " .. tostring(mask))
end

-- The decision as text: "yours" or "left out", the slot or the reason, the spell matched when there is one and the school of the hit, such
-- as "yours (cast slot of Fireball; fire hit)".
function MINE.Decision(head, why, school, spell)
	local hit = Plain(school, "number") and (MINE.SchoolWords(school) .. " hit") or "hit of a withheld school"
	return ("%s (%s%s; %s)"):format(head, why, Plain(spell, "string") and (" of " .. spell) or "", hit)
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

-- Drops the cast slots whose time is past. A slot of a spell that travels lives longer than one of an instant spell, so the list is in the
-- order the slots were made and not in the order they close.
function MINE.DropCasts(now)
	local list = mine.castSlots
	for index = #list, 1, -1 do
		if list[index].at < now then
			table.remove(list, index)
		end
	end
end

-- True while a cast slot of yours is open, whatever its school.
function MINE.CastOpen(now)
	for _, slot in ipairs(mine.castSlots) do
		if slot.at >= now then
			return true
		end
	end
	return false
end

-- The open cast slot a hit of this school can take (SchoolFits) and its place in the list, or nil; nothing is taken. away is true for a hit on
-- another enemy than your target: it fits the slot of an area spell, and the slot of a spell of your pet's when onPet says the hit is on the
-- enemy your pet attacks (pettarget). A hit on your target fits every slot of yours, and a slot of your pet's only with onPet. Of the slots that
-- fit, a fresh one goes first: the slot of a spell that does not fly, whose hit comes from MINE.late seconds before its cast to MINE.fresh after
-- it, so that two spells of one school cast close together each take their own hit. Then the oldest. The third value is true for a fresh slot.
function MINE.CastFor(now, school, away, onPet)
	local found, at
	for index, slot in ipairs(mine.castSlots) do
		if slot.at >= now and MINE.SchoolFits(slot.school, school) and (slot.area or (slot.pet and onPet) or (not slot.pet and not away)) then
			if not slot.travel and now >= slot.from - MINE.late and now <= slot.from + MINE.fresh then
				return slot, index, true
			end
			if not found then
				found, at = slot, index
			end
		end
	end
	return found, at, false
end

-- Opens a cast slot for a spell of yours or your pet's (pet true) that hits: for MINE.cast seconds, or MINE.travel when its missile flies, of the
-- spell's school, taken by one hit or, for an area spell, by up to MINE.areaMax hits. entry is nil for a harmful spell not in the table: an area
-- slot of any school, as such a spell (a bomb, a trinket, a spell of Forever's own) may hit every enemy around. from is the time of the cast, and
-- damage the strike's ("weapon" or "flat", MINE.Rival), none for a spell of your pet's: the pet's Claw shares the druid's name and entry.
function MINE.OpenCast(now, entry, spellID, name, pet)
	local list = mine.castSlots
	local area = entry == nil or entry.kind == "area"
	local travel = entry ~= nil and entry.travel == true
	list[#list + 1] = { at = now + (travel and MINE.travel or MINE.cast), from = now, travel = travel, pet = pet == true, school = entry and entry.school or nil,
		icon = Icon(spellID) or false, area = area, left = area and MINE.areaMax or 1, name = name,
		damage = (entry ~= nil and pet ~= true) and entry.damage or nil }
end

-- Takes the open cast slot of yours a hit of this school can take (CastFor, with away and onPet as there). Returns true when it did, the icon of
-- the cast (nil for none), the name of the spell and the strike's damage (OpenCast). The slot of an area spell stays open until it has taken its
-- hits.
local function TakeCast(now, school, away, onPet)
	MINE.DropCasts(now)
	local slot, index = MINE.CastFor(now, school, away, onPet)
	if not slot then
		return false
	end
	mine.castTaken = math.max(mine.castTaken, slot.at)
	slot.left = slot.left - 1
	if slot.left <= 0 then
		table.remove(mine.castSlots, index)
	end
	return true, slot.icon or nil, slot.name, slot.damage
end

-- Records a damage-over-time spell of yours on the enemy you target, or the pet's target for the pet, under the key MineOne judges its hits
-- by: the plate, or the token when it has none. A new cast of the same spell takes the place of its record.
function MINE.RecordDot(unit, now, entry, spellID, name)
	local token = unit == "pet" and "pettarget" or "target"
	local key = Plate(token) or token
	local list = mine.dots[key]
	if not list then
		list = {}
		mine.dots[key] = list
	end
	for index = #list, 1, -1 do
		if list[index].name == name then
			table.remove(list, index)
		end
	end
	list[#list + 1] = { school = entry.school, icon = Icon(spellID) or false, name = name, at = now }
end

-- The damage over time of yours recorded on an enemy, or nil when there is none. A record goes after MINE.dotKeep seconds, and every record
-- goes once the list of your auras on the unit reads none, except one younger than MINE.travel seconds, whose aura may not be on yet.
function MINE.DotsOn(key, unit, now)
	local list = key ~= nil and mine.dots[key] or nil
	if not list then
		return nil
	end
	for index = #list, 1, -1 do
		if now - list[index].at > MINE.dotKeep then
			table.remove(list, index)
		end
	end
	if list[1] then
		local number, read = AuraOfYours(unit)
		if read and number == 0 then
			for index = #list, 1, -1 do
				if now - list[index].at > MINE.travel then
					table.remove(list, index)
				end
			end
		end
	end
	if not list[1] then
		mine.dots[key] = nil
		return nil
	end
	return list
end

-- How many of the recorded damage-over-time spells a hit of this school can be a tick of, and the one when there is only one.
function MINE.DotFor(list, school)
	local count, found = 0, nil
	if list and Plain(school, "number") then
		for _, dot in ipairs(list) do
			if MINE.SchoolFits(dot.school, school) then
				count, found = count + 1, dot
			end
		end
	end
	return count, count == 1 and found or nil
end

-- Takes one of the aura slots of an enemy. With damage over time of yours recorded on it (key, see DotsOn), a hit of the school of one of
-- them gets its icon and name when it is the only one of that school; a hit of another school takes a slot without them. Returns true when
-- it did, whether there was a slot to take at all, and the icon (nil for none) and name of the recorded spell.
local function TakeAura(unit, now, key, school)
	local dots = MINE.DotsOn(key, unit, now)
	local number = AuraOfYours(unit)
	if number == 0 then
		return false, false
	end
	local dot
	if dots then
		-- A tick of a school none of them has (a poison or a proc of yours, which is never cast and never recorded) still takes a slot, as
		-- before the record, but gets no icon.
		local _
		_, dot = MINE.DotFor(dots, school)
	end
	local slots = mine.auraSlots[unit]
	if not slots or TakeWeapon(MINE.auraTick, slots.at, now) then
		slots = { at = now, used = 0 }
		mine.auraSlots[unit] = slots
	end
	if slots.used < number then
		slots.used = slots.used + 1
		return true, true, dot and dot.icon or nil, dot and dot.name or nil
	end
	return false, true
end

-- UnitExists lists no secret return (DOC/UnitDocumentation.lua:1192-1204); a withheld answer is still treated as a pet out.
-- True when a pet is out or the game does not say. The extra attack slot is closed then, as a pet's melee looks the same (DOC/UnitDocumentation.lua:4167-4180: UNIT_COMBAT has no source field),
-- and Engaged also asks whether the pet holds the enemy.
local function PetOut()
	if type(UnitExists) ~= "function" then
		return true
	end
	local ok, there = pcall(UnitExists, "pet")
	return not (ok and Plain(there, "boolean") and not there)
end

-- True while your pet is out and in a fight, as the game plainly says (UnitExists and UnitAffectingCombat, UnitDocumentation.lua:1192-1204 and 614-626).
function MINE.PetFighting()
	if type(UnitExists) ~= "function" or type(UnitAffectingCombat) ~= "function" then
		return false
	end
	local ok, there = pcall(UnitExists, "pet")
	if not (ok and Plain(there, "boolean") and there) then
		return false
	end
	local fought, fighting = pcall(UnitAffectingCombat, "pet")
	return fought and Plain(fighting, "boolean") and fighting
end

-- The pet's melee, which casts nothing and has no swing event: a physical hit on the enemy your pet attacks takes the pet's slot when it has been
-- free for MINE.swingShare of the pet's attack speed (UnitAttackSpeed of the pet, UnitDocumentation.lua:682-697; MINE.swingGap when withheld),
-- while the pet fights (PetFighting). Returns true when it did.
function MINE.TakePetSwing(now)
	if not MINE.PetFighting() then
		return false
	end
	local speed = MINE.swingGap
	if type(UnitAttackSpeed) == "function" then
		local ok, main = pcall(UnitAttackSpeed, "pet")
		if ok and Plain(main, "number") and main > 0 then
			speed = main
		else
			mine.blind = mine.blind + 1
		end
	end
	if TakeWeapon(speed, mine.petAt, now) then
		mine.petAt = now
		return true
	end
	return false
end

-- The pet's swing slot for a physical hit on the enemy your pet attacks (away for one that is not your target), unless a fresh cast slot fits the
-- hit (CastFor): the hit of a spell cast just then, such as the pet's own Claw, is that spell's. Returns true when it took the slot.
function MINE.PetSwing(now, away)
	MINE.DropCasts(now)
	local slot, _, fresh = MINE.CastFor(now, 1, away, true)
	if slot and fresh then
		return false
	end
	return MINE.TakePetSwing(now)
end

-- True while a physical hit on this target was left out in the last MINE.crowd seconds: someone else is hitting it.
local function Crowded(key, now)
	local at = key ~= nil and mine.crowd[key] or nil
	return at ~= nil and now - at <= MINE.crowd
end

-- True while the extra attack slot takes a hit: for MINE.extra seconds after a swing slot was taken, once, with Extra attacks on, alone with no
-- pet out, while no cast slot is open (an instant strike), no harmful aura of yours is on the enemy (a bleed tick looks the same) and others do
-- not hit it (Crowded). key is the plate, or the unit without one.
function MINE.ExtraOpen(now, unit, key)
	return Opt("extra") == "plain" and not mine.extraUsed and now - mine.swingAt <= MINE.extra and not InGroup() and not PetOut() and not MINE.CastOpen(now)
		and not Crowded(key, now) and AuraListFree(unit)
end

-- Until the game has reported a melee swing: takes the slot of a hand for a white hit. Returns "swing slot" when it took one, and true when
-- both hands were busy. The extra attack slot (ExtraOpen) is MineOne's, after a spin.
local function TakeSwing(now)
	local main, off = Speeds(UnitAttackSpeed, true)
	if TakeWeapon(main, mine.hand.main, now) then
		mine.hand.main, mine.swingAt, mine.extraUsed = now, now, false
		return "swing slot", false
	elseif off and TakeWeapon(off, mine.hand.off, now) then
		mine.hand.off, mine.swingAt, mine.extraUsed = now, now, false
		return "swing slot", false
	end
	return nil, true
end

-- The hand of a swing of PLAYER_SWING (Enum.PlayerSwingType, SwingTimerDocumentation.lua:71-82): "main", "off" or "ranged", or nil.
function MINE.Hand(swingType)
	if not Plain(swingType, "number") then
		return nil
	end
	local types = type(Enum) == "table" and Enum.PlayerSwingType or nil
	if swingType == (types and types.MainHand or 0) then
		return "main"
	elseif swingType == (types and types.OffHand or 1) then
		return "off"
	elseif swingType == (types and types.Ranged or 2) then
		return "ranged"
	end
	return nil
end

-- A swing or a shot of yours the game reported (PLAYER_SWING): a slot for one hit on your target (TakeToken). A main-hand swing within MINE.extra
-- seconds of the one before is an extra attack. The main-hand swing a next melee ability waits for is that ability's own (its pair takes it
-- and no slot is made). The length of the swing gives the time the next swing of that hand is due. False for a swing of no known hand.
function MINE.OnSwing(now, duration, swingType)
	local hand = MINE.Hand(swingType)
	if hand == nil then
		return false
	end
	if Plain(duration, "number") and duration > 0 then
		mine.due[hand] = now + duration
	end
	if hand == "ranged" then
		mine.rangedHeard = true
	else
		mine.swingHeard = true
	end
	mine.swingCount = mine.swingCount + 1
	local extra = false
	if hand == "main" then
		extra = now - mine.lastMain <= MINE.extra
		mine.lastMain = now
		local pair = mine.pair
		if pair and not pair.bound and (pair.left == 2 or (pair.waits and pair.left > 0)) and now <= pair.close then
			pair.bound = now
			return true
		end
	end
	local list = mine.swings
	for index = #list, 1, -1 do
		if now - list[index].at > MINE.travel then
			table.remove(list, index)
		end
	end
	list[#list + 1] = { at = now, hand = hand, extra = extra, left = 1 }
	return true
end

-- Takes the oldest swing of yours (with ranged, the oldest shot) not yet taken whose time fits a hit at `at`: from MINE.late seconds before it,
-- as the hit may come first, to MINE.swingTake seconds after it, or MINE.cast seconds for a shot, whose arrow flies. Returns it, or nil.
function MINE.TakeToken(at, ranged)
	for _, token in ipairs(mine.swings) do
		if token.left > 0 and (token.hand == "ranged") == ranged and at >= token.at - MINE.late and at <= token.at + (ranged and MINE.cast or MINE.swingTake) then
			token.left = 0
			return token
		end
	end
	return nil
end

-- Once the game has reported a melee swing: the slot of a swing of yours (TakeToken). Returns "swing slot", or "extra slot" for a swing right
-- after another of the main hand (with Extra attacks on), and true when no swing of yours fits. The extra attack slot (ExtraOpen) is MineOne's,
-- after a spin.
function MINE.TakeSwingHeard(now)
	local token = MINE.TakeToken(now, false)
	if token then
		if token.extra and Opt("extra") == "plain" then
			mine.extraUsed = true
			return "extra slot", false
		end
		mine.swingAt, mine.extraUsed = now, false
		return "swing slot", false
	end
	return nil, true
end

-- Opens the pair of a next melee ability of yours (see MINE) at its successful cast, with its name, icon and spell: two physical reports on
-- your target and, for an ability that hits more enemies (targets in ns.CombatSpells), one for each of them on another enemy. A main-hand
-- swing reported in this same frame before the cast is the ability's own: its slot goes to the pair, which is bound to it.
function MINE.OpenPair(now, spellID, name)
	local entry = MINE.SpellOf(spellID)
	local close, due = now + MINE.cast, nil
	if mine.swingHeard then
		due = math.max(now, mine.due.main or now)
		close = math.min(now + MINE.nextMax, math.max(now + MINE.cast, due + MINE.pairTail))
	end
	local targets = entry and Plain(entry.targets, "number") and entry.targets or 1
	local pair = { name = name, icon = Icon(spellID) or false, spell = spellID, opened = now, close = close, left = 2, other = math.max(0, targets - 1),
		due = due, waits = due ~= nil and due > now + MINE.pairTail }
	local list = mine.swings
	for index = #list, 1, -1 do
		local token = list[index]
		if token.hand == "main" and token.at == now and token.left > 0 then
			table.remove(list, index)
			pair.bound, pair.waits = now, false
			break
		end
	end
	mine.pair = pair
end

-- True while the pair takes a report of `at`. Bound to its swing: from MINE.late seconds before that swing to MINE.pairTail after it. Not bound and
-- waiting (cast when the key was pressed, its main-hand swing due more than MINE.pairTail later by the swing timer): only around that swing, from
-- MINE.swingTake seconds before it is due until the pair closes, so an off-hand swing, a tick or another player's hit before it is not taken for
-- it. Else from MINE.late seconds before the cast to MINE.pairTail after it once the game has reported a melee swing (the cast came with its
-- swing), and until it closes before any was reported.
function MINE.PairOpen(pair, at)
	if pair == nil then
		return false
	end
	if pair.bound then
		return at >= pair.bound - MINE.late and at <= pair.bound + MINE.pairTail
	end
	if pair.waits then
		return at >= pair.due - MINE.swingTake and at <= pair.close
	end
	if at < pair.opened - MINE.late then
		return false
	end
	if mine.swingHeard then
		return at <= pair.opened + MINE.pairTail
	end
	return at <= pair.close
end

-- Takes a place of the pair for a physical report: on your target one of its two, and on another enemy one of its others, there only in melee
-- range of you when the game says so (C_Spell.IsSpellInRange of the ability on that enemy, SpellDocumentation.lua:947-963; nil, a withheld
-- answer or an error is no answer). Returns the pair, or nil.
function MINE.TakePair(at, onTarget, unit)
	local pair = mine.pair
	if not MINE.PairOpen(pair, at) then
		return nil
	end
	if onTarget then
		if pair.left <= 0 then
			return nil
		end
		pair.left = pair.left - 1
		return pair
	end
	if pair.other <= 0 or not Plain(unit, "string") then
		return nil
	end
	if type(C_Spell) == "table" and type(C_Spell.IsSpellInRange) == "function" then
		local ok, near = pcall(C_Spell.IsSpellInRange, pair.spell, unit)
		if ok and Plain(near, "boolean") and not near then
			return nil
		end
	end
	pair.other = pair.other - 1
	return pair
end

-- Starts a spin of yours (kind spin in ns.CombatSpells, The Ravager's Bladestorm: an aura on you that hits every enemy around you each period
-- seconds, ticks times) at its cast or the start of its channel. A second signal of the same spin within MINE.spinSlack seconds keeps it.
-- trigger is the spell its aura casts at each tick, when the table names one.
function MINE.StartSpin(now, entry, spellID, name)
	local spin = mine.spin
	if spin and spin.name == name and now - spin.start <= MINE.spinSlack then
		return
	end
	mine.spin = { name = name, icon = Icon(spellID) or false, start = now, period = entry.period or MINE.tick, ticks = entry.ticks or 3, taken = {},
		trigger = Plain(entry.trigger, "number") and entry.trigger or nil }
end

-- True for a cast of the spell a spin of yours casts at a tick (trigger, The Ravager's 9633 Whirlwind) within MINE.spinSlack seconds of one of
-- its ticks: the ticks move to it, and its cast opens no area slot, which would let in hits of others for MINE.cast seconds, as the spin takes
-- the hits of that tick. A cast far from every tick is no tick of it and opens its slot as before.
function MINE.SpinTick(now, spellID)
	local spin = mine.spin
	if spin == nil or spin.trigger == nil or not Plain(spellID, "number") or spellID ~= spin.trigger then
		return false
	end
	local t = now - spin.start
	local k = math.floor(t / spin.period + 0.5)
	if k < 1 or k > spin.ticks or math.abs(t - k * spin.period) > MINE.spinSlack then
		return false
	end
	spin.start = now - k * spin.period
	return true
end

-- Takes one physical hit on an enemy (key) at a tick of the spin: within MINE.spinSlack seconds of start + k x period, k from 1 to ticks, once
-- for each enemy and tick. Returns the spin, or nil.
function MINE.TakeSpin(at, key)
	local spin = mine.spin
	if spin == nil or key == nil then
		return nil
	end
	local t = at - spin.start
	if t > spin.ticks * spin.period + MINE.spinSlack then
		mine.spin = nil
		return nil
	end
	local k = math.floor(t / spin.period + 0.5)
	if k < 1 or k > spin.ticks or math.abs(t - k * spin.period) > MINE.spinSlack then
		return nil
	end
	local hit = spin.taken[k]
	if not hit then
		hit = {}
		spin.taken[k] = hit
	end
	if hit[key] then
		return nil
	end
	hit[key] = true
	return spin
end

-- True when a melee strike of yours falls within MINE.swingTake seconds of `at`: a swing the game reported, the swing of a next melee ability (its
-- cast while it does not wait for its swing), a physical strike you cast, or a swing slot taken before any swing was reported.
function MINE.Struck(at)
	local near = MINE.swingTake
	for _, token in ipairs(mine.swings) do
		if token.hand ~= "ranged" and math.abs(token.at - at) <= near then
			return true
		end
	end
	local pair = mine.pair
	local swing = pair and (pair.bound or (not pair.waits and pair.opened)) or nil
	if swing and math.abs(swing - at) <= near then
		return true
	end
	return math.abs(mine.strikeAt - at) <= near or math.abs(mine.swingAt - at) <= near
end

-- Starts a sweep of yours (kind sweep in ns.CombatSpells, Sweeping Strikes: a buff on you whose charges make your melee swings and strikes hit
-- another enemy nearby too) at its cast, for its duration and charges. A cast of the same name while one lasts, such as the strike of a charge
-- if the game reports it, starts none: the buff cannot be cast again before it ends (its cooldown is longer).
function MINE.StartSweep(now, entry, spellID, name)
	local sweep = mine.sweep
	if sweep and now <= sweep.close then
		return
	end
	mine.sweep = { name = name, icon = Icon(spellID) or false, close = now + (entry.duration or MINE.dotKeep), left = entry.charges or 5 }
end

-- Takes a charge of the sweep for a physical hit on an enemy other than your target that comes with a melee strike of yours (Struck). Returns
-- the sweep, or nil. A sweep with no charge left stays until it ends, so that no cast of its name starts it again.
function MINE.TakeSweep(at)
	local sweep = mine.sweep
	if sweep == nil then
		return nil
	end
	if at > sweep.close then
		mine.sweep = nil
		return nil
	end
	if sweep.left <= 0 or not MINE.Struck(at) then
		return nil
	end
	sweep.left = sweep.left - 1
	return sweep
end

-- Starts a counter of yours (kind counter in ns.CombatSpells, Retaliation: a buff on you whose charges strike back at each enemy that hits you in
-- melee, for its duration) at its cast. True while one lasts: a cast of its name then, such as the counterattack itself when the game reports it,
-- starts none and opens no slot, as the counter takes the hits.
function MINE.StartCounter(now, entry, name, spellID)
	local counter = mine.counter
	if counter and now <= counter.close then
		return true
	end
	mine.counter = { name = name, icon = Icon(spellID) or false, close = now + (entry.duration or MINE.dotKeep), left = entry.charges or 30 }
	mine.struckAt = {}
	return false
end

-- A hit that struck you (a WOUND of physical school on the player) while a counter of yours lasts: its counterattack comes at once, so it is a
-- slot for one physical hit (TakeCounter). The times of the last MINE.travel seconds are kept.
function MINE.OnStruck(now)
	local counter = mine.counter
	if counter == nil then
		return
	end
	if now > counter.close then
		mine.counter = nil
		return
	end
	local list = mine.struckAt
	for index = #list, 1, -1 do
		if now - list[index] > MINE.travel then
			table.remove(list, index)
		end
	end
	list[#list + 1] = now
end

-- Takes a charge of the counter for a physical hit on any enemy from MINE.late seconds before a hit that struck you to MINE.swingTake after it,
-- once for each such hit. Returns the counter, or nil.
function MINE.TakeCounter(at)
	local counter = mine.counter
	if counter == nil or counter.left <= 0 then
		return nil
	end
	if at > counter.close + MINE.swingTake then
		mine.counter = nil
		return nil
	end
	for index, struck in ipairs(mine.struckAt) do
		if at >= struck - MINE.late and at <= struck + MINE.swingTake then
			table.remove(mine.struckAt, index)
			counter.left = counter.left - 1
			return counter
		end
	end
	return nil
end

-- The threat situation of `who` on an enemy (UnitThreatSituation, UnitDocumentation.lua:3279-3294): the number and true, nil and true for no
-- place on its threat table, nil and false for an error, a withheld answer or one that is no number.
function MINE.Threat(who, unit)
	if type(UnitThreatSituation) ~= "function" then
		return nil, false
	end
	local ok, status = pcall(UnitThreatSituation, who, unit)
	if not ok or ns.IsSecret(status) then
		return nil, false
	end
	if status == nil then
		return nil, true
	end
	if type(status) ~= "number" then
		return nil, false
	end
	return status, true
end

-- True when someone else of your group may fight the enemy: in a raid always, as no raid is read, and in a party while a member or a member's
-- pet is on its threat table or the game does not say.
function MINE.OthersOn(unit)
	if type(IsInRaid) ~= "function" then
		return true
	end
	local ok, raid = pcall(IsInRaid)
	if not ok or not Plain(raid, "boolean") or raid then
		return true
	end
	for _, token in ipairs(MINE.partyTokens) do
		local status, answered = MINE.Threat(token, unit)
		if not answered or status ~= nil then
			return true
		end
	end
	return false
end

-- True for an enemy only you and your pet fight (see MINE, Engaged), so that every damage hit and miss word on it is yours or your pet's: an
-- enemy that nobody else has tapped (a plain false from UnitIsTapDenied) and that you or your pet hold (UnitThreatSituation 2 or 3 of the player,
-- or of the pet while one is out), or a creature (UnitPlayerControlled plainly false: a player or a player's pet has no threat table to wait for)
-- that a slot of yours hit in the last MINE.engaged seconds while you are on no threat table of it yet; in a group, only while no other member
-- or member's pet is on it (OthersOn).
function MINE.EngagedRead(unit, key, at)
	if not Plain(unit, "string") or type(UnitIsTapDenied) ~= "function" then
		return false
	end
	local ok, denied = pcall(UnitIsTapDenied, unit)
	if not (ok and Plain(denied, "boolean")) or denied then
		return false
	end
	local status, answered = MINE.Threat("player", unit)
	if not answered then
		return false
	end
	local held = status == 2 or status == 3
	if not held and PetOut() then
		local pet = MINE.Threat("pet", unit)
		held = pet == 2 or pet == 3
	end
	if not held and status == nil and type(UnitPlayerControlled) == "function" then
		local hit = key ~= nil and mine.hitBy[key] or nil
		local known, controlled = pcall(UnitPlayerControlled, unit)
		held = hit ~= nil and at - hit <= MINE.engaged and known and Plain(controlled, "boolean") and not controlled
	end
	return held and not (InGroup() and MINE.OthersOn(unit))
end

-- The same answer, kept for each enemy for the length of a frame, as PlateOfUnit keeps its answer: a fight of many hits asks it for every report.
MINE.engagedAt, MINE.engagedBy = nil, {}
function MINE.Engaged(unit, key, at)
	local frame = Now()
	if MINE.engagedAt ~= frame then
		MINE.engagedAt, MINE.engagedBy = frame, {}
	end
	local index = key or unit
	if index == nil then
		return false
	end
	local kept = MINE.engagedBy[index]
	if kept == nil then
		kept = MINE.EngagedRead(unit, key, at)
		MINE.engagedBy[index] = kept
	end
	return kept
end

-- True when the hit takes a slot of yours (see MINE): one hit for each action. Then the slot taken, the icon of the action (nil for none, by Spell
-- icons), the name of the spell matched, for a next melee ability its pair, and for a cast slot the strike's damage (MINE.Rival). On the target plate
-- a channel of its school is tried first, then the pair of a next melee ability, then a swing slot for a physical hit (the game's reported swing, or
-- a free hand before any was reported), then a spin, a counter (Retaliation) and the extra attack slot (ExtraOpen). A non-critical hit then tries the
-- cast slot first when its school fits a fresh cast slot (CastFor) or an open one and no damage over time of yours recorded on the enemy, and else an
-- aura slot first, so that the slot of a spell that flies stays for its hit, which can be critical. A critical hit tries the cast slot, then the
-- shot, then an aura slot, as a tick can be critical on this client. A word a tick cannot be (MINE.words: a miss, dodge, parry, full block, evade,
-- deflect, reflect) takes no aura slot. Each slot and the channel take only a hit of their school (SchoolFits). On another enemy an area channel, a
-- place of Cleave's pair, a spin, a sweep, a counter, an aura slot and the slot of an area spell are tried, the last two in the same order. A
-- physical hit on the enemy your pet attacks also takes the pet's swing slot (TakePetSwing), and the slot of a spell of your pet's fits a hit there
-- (onPet). A hit with no free slot is left out, and a physical one marks its enemy as hit by others for MINE.crowd seconds; with own (an enemy only
-- you and your pet fight, Engaged) it is neither counted nor marked, as it shows anyway. at is the time of the report, which waits MINE.hold seconds
-- (Flush), and event its kind.
local function MineOne(plate, unit, school, flag, own, at, event)
	local now = at or GetTime()
	local why, taken, swingTried, auraTried, icon, spell, pair, damage
	local key = plate or unit
	local onTarget = plate == Plate("target")
	local onPet = plate ~= nil and plate == Plate("pettarget")
	local physical = Plain(school, "number") and school == 1
	local crit = Plain(flag, "string") and flag == "CRITICAL"
	local tickable = not (Plain(event, "string") and MINE.words[event])
	-- A channel takes only a hit of its school, on your target and, for an area channel, on every enemy; one that does no damage takes none.
	-- castUntil is set only by the end of a channel.
	if (mine.chan or now <= mine.castUntil) and mine.chanTakes and (onTarget or mine.chanArea) and MINE.SchoolFits(mine.chanSchool, school) then
		why, spell = "channel", mine.chanName
	elseif physical then
		pair = MINE.TakePair(now, onTarget, unit)
		if pair then
			why, spell = "next swing", pair.name
			-- Before the game has reported a melee swing, the swing the ability replaced is the main hand's, as a white hit's would be.
			if onTarget and not mine.swingHeard then
				mine.hand.main = now
			end
		end
	end
	if not why and onTarget then
		local shooting = mine.shoot or now <= mine.shotEnd
		if physical and not shooting and (mine.swingHeard or mine.swing) then
			swingTried = true
			if mine.swingHeard then
				why, taken = MINE.TakeSwingHeard(now)
			else
				why, taken = TakeSwing(now)
			end
		end
		-- A tick of a spin of yours, a counterattack, and only then the guess of an extra attack right after a swing slot, which a tick on your
		-- target would otherwise take with (Extra attack) after it.
		if not why and physical then
			local spin = MINE.TakeSpin(now, key)
			local counter = not spin and MINE.TakeCounter(now) or nil
			if spin then
				why, spell, icon = "spin", spin.name, spin.icon or nil
			elseif counter then
				why, spell, icon = "counter", counter.name, counter.icon or nil
			elseif swingTried and MINE.ExtraOpen(now, unit, key) then
				mine.extraUsed = true
				why, taken = "extra slot", false
			end
		end
		if not why and physical and onPet and MINE.PetSwing(now, false) then
			why = "pet swing"
		end
		if not why and tickable and Plain(flag, "string") and not crit then
			-- The cast slot first when a fresh one fits, or when only it fits the school of the hit, as a direct hit is no tick of a spell of
			-- another school.
			MINE.DropCasts(now)
			local slot, _, fresh = MINE.CastFor(now, school, false, onPet)
			local castFirst = slot ~= nil and (fresh or MINE.DotFor(MINE.DotsOn(key, unit, now), school) == 0)
			if not castFirst then
				auraTried = true
				local got, held, dotIcon, dotName = TakeAura(unit, now, key, school)
				if got then
					why, icon, spell = "aura slot", dotIcon, dotName
				elseif held then
					taken = true
				end
			end
		end
		local cast, castIcon, castName, castDamage
		if not why then
			cast, castIcon, castName, castDamage = TakeCast(now, school, false, onPet)
		end
		if why then
			-- A slot was taken above.
		elseif cast then
			why, icon, spell, damage = "cast slot", castIcon, castName, castDamage
		else
			taken = taken or now <= mine.castTaken
			if shooting then
				-- A shot the game reported, else the bow's own slot by its speed.
				local token = mine.rangedHeard and MINE.TakeToken(now, true) or nil
				if token or TakeWeapon(Speeds(UnitRangedDamage), mine.shotAt, now) then
					mine.shotAt, why = now, "shot slot"
					-- A single shot has one hit: its slot closes when it is taken.
					if not mine.shoot then mine.shotEnd = -math.huge end
				else
					taken = true
				end
			elseif not swingTried and (mine.swing or mine.swingHeard) and not Plain(school, "number") then
				mine.blind = mine.blind + 1
			end
		end
	end
	-- A spin hits every enemy around you, a sweep and a counter another enemy, and the pet the enemy it attacks.
	if not why and not onTarget and physical then
		local spin = MINE.TakeSpin(now, key)
		local sweep = not spin and MINE.TakeSweep(now) or nil
		local counter = not (spin or sweep) and MINE.TakeCounter(now) or nil
		if spin then
			why, spell, icon = "spin", spin.name, spin.icon or nil
		elseif sweep then
			why, spell, icon = "sweep", sweep.name, sweep.icon or nil
		elseif counter then
			why, spell, icon = "counter", counter.name, counter.icon or nil
		elseif onPet and MINE.PetSwing(now, true) then
			why = "pet swing"
		end
	end
	-- An area spell of yours hits the enemies around your target too, and a spell of your pet's the enemy it attacks: on another enemy its slot
	-- takes a hit of its school before the aura slot when it is fresh, when no damage over time recorded there has that school or when the hit
	-- is critical, and else after it.
	local areaFirst = false
	if not why and not onTarget then
		MINE.DropCasts(now)
		local slot, _, fresh = MINE.CastFor(now, school, true, onPet)
		areaFirst = slot ~= nil and (fresh or crit or MINE.DotFor(MINE.DotsOn(key, unit, now), school) == 0)
		if areaFirst then
			local cast, castIcon, castName, castDamage = TakeCast(now, school, true, onPet)
			if cast then
				why, icon, spell, damage = "cast slot", castIcon, castName, castDamage
			end
		end
	end
	if not why and not auraTried and tickable then
		if Plain(flag, "string") then
			local got, held, dotIcon, dotName = TakeAura(unit, now, key, school)
			if got then
				why, icon, spell = "aura slot", dotIcon, dotName
			elseif held then
				taken = true
			end
		else
			mine.blind = mine.blind + 1
		end
	end
	if not why and not onTarget and not areaFirst then
		local cast, castIcon, castName, castDamage = TakeCast(now, school, true, onPet)
		if cast then
			why, icon, spell, damage = "cast slot", castIcon, castName, castDamage
		end
	end
	if why then
		if key ~= nil then
			mine.hitBy[key] = now
		end
		mine.kept, mine.last = mine.kept + 1, MINE.Decision("yours", why, school, spell)
		local mode = Opt("icons")
		if why == "channel" then
			icon = mine.chanIcon
		elseif why == "next swing" then
			icon = pair.icon or nil
		elseif why == "swing slot" or why == "extra slot" then
			mine.swingIcon = mine.swingIcon or Icon(6603)
			icon = mode == "all" and mine.swingIcon or nil
		elseif why == "shot slot" then
			mine.shotIcon = mine.shotIcon or Icon(75)
			icon = mode == "all" and mine.shotIcon or nil
		end
		return true, why, mode ~= "off" and icon or nil, spell, pair, damage
	end
	if own then
		return false
	end
	mine.left = mine.left + 1
	mine.last = MINE.Decision("left out", taken and "slot taken" or "no cast or swing seen", school)
	if key ~= nil and physical then
		mine.crowd[key] = now
	end
	return false
end

-- A signal about you. Only the time is kept, and nothing of the payload but the unit, which must be the player or the pet, and the spell: its
-- icon, its name and its entry in ns.CombatSpells; of a swing (PLAYER_SWING) its length and its hand.
local function OnSignal(_, event, unit, second, spellID)
	if event == "PLAYER_ENTERING_WORLD" then
		local was = mine.off
		mine.heard, mine.unheard, mine.off = 0, 0, mine.deaf
		mine.chan, mine.swing, mine.shoot = false, false, false
		mine.castSlots, mine.castTaken, mine.auraSlots, mine.dots = {}, -1, {}, setmetatable({}, { __mode = "k" })
		mine.chanIcon, mine.chanName, mine.chanSchool, mine.chanTakes, mine.chanArea = nil, nil, nil, false, false
		mine.healIcon, mine.swingIcon, mine.shotIcon, mine.healUntil = nil, nil, nil, -1
		mine.hand, mine.shotAt, mine.shotEnd = { main = -math.huge, off = -math.huge }, -math.huge, -math.huge
		mine.swingAt, mine.extraUsed = -math.huge, false
		mine.crowd, mine.hitBy = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
		mine.pair, mine.spin, mine.swings, mine.lastMain, mine.due, mine.queue = nil, nil, {}, -math.huge, {}, {}
		mine.sweep, mine.strikeAt, mine.counter, mine.struckAt, mine.petAt = nil, -math.huge, nil, {}, -math.huge
		if was ~= mine.off then
			pcall(Sync)
		end
		return
	end
	local now = GetTime()
	if event == "PLAYER_SWING" then
		-- The payload is the length of the swing and its hand (SwingTimerDocumentation.lua:43-52).
		if not MINE.OnSwing(now, unit, second) then
			return
		end
	elseif event == "PLAYER_ENTER_COMBAT" then
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
			-- The channel takes only the hits of its school (MineOne): any hit for a spell not in ns.CombatSpells that the game plainly calls
			-- harmful, and none for a channel that does no damage (Drain Mana, Mind Control, Seduction) or one the game does not call harmful,
			-- such as Evocation or a bandage. An area channel takes them on every enemy, and the channel of a spin starts the spin.
			local entry, spell = MINE.SpellOf(spellID)
			mine.chan, mine.chanIcon, mine.chanName = true, Icon(spellID), spell
			if entry then
				mine.chanTakes, mine.chanSchool, mine.chanArea = entry.kind == "channel", entry.school, entry.area == true
				if entry.kind == "spin" then
					MINE.StartSpin(now, entry, spellID, spell)
				end
			else
				mine.chanTakes, mine.chanSchool, mine.chanArea = MINE.Harmful(spellID), nil, false
			end
		elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			mine.chan, mine.castUntil, mine.castAt = false, now + MINE.tail, now
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			-- A cast that succeeded gives a slot, and the start of one none. The slots past their time are dropped here, so the list stays short.
			MINE.DropCasts(now)
			-- A next melee ability of the player opens its pair and no cast slot.
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
				MINE.OpenPair(now, spellID, name)
			elseif MINE.SpinTick(now, spellID) then
				-- A tick of a spin of yours: the spin takes its hits, and no cast slot opens.
			else
				-- The spell by its name in ns.CombatSpells: one that hits opens a cast slot of its school, damage over time is recorded on the
				-- enemy, a spin starts, and a channel (set at its start) or a spell that does no damage opens nothing. A spell not in the table
				-- opens an area slot of any school only when the game plainly says it is harmful, so a buff, a heal or a summon opens none.
				local entry, spell = MINE.SpellOf(spellID)
				local kind = entry and entry.kind
				if kind == "hit" or kind == "both" or kind == "area" then
					MINE.OpenCast(now, entry, spellID, spell, unit == "pet")
					-- A physical strike of the player's own, which a sweep follows.
					if unit == "player" and entry.school == 1 and not entry.travel then
						mine.strikeAt = now
					end
				elseif kind == "spin" then
					MINE.StartSpin(now, entry, spellID, spell)
				elseif kind == "sweep" and unit == "player" then
					MINE.StartSweep(now, entry, spellID, spell)
				elseif kind == "counter" and unit == "player" then
					-- Retaliation, and its counterattack when the game reports it: the counter takes the hits (MINE.TakeCounter).
					MINE.StartCounter(now, entry, spell, spellID)
				elseif not entry and MINE.Harmful(spellID) then
					MINE.OpenCast(now, nil, spellID, spell, unit == "pet")
				end
				if kind == "dot" or kind == "both" then
					MINE.RecordDot(unit, now, entry, spellID, spell)
				end
			end
			-- A helpful cast of yours gives the next heal on you its icon.
			local helpful = unit == "player" and Plain(spellID, "number") and type(C_Spell) == "table" and type(C_Spell.IsSpellHelpful) == "function"
				and select(2, pcall(C_Spell.IsSpellHelpful, spellID))
			if Plain(helpful, "boolean") and helpful then
				mine.healIcon, mine.healUntil = Icon(spellID), now + MINE.cast
			end
		end
	else
		return
	end
	if mine.trace then
		if event == "PLAYER_SWING" then
			Trace(event, MINE.Hand(second), Plain(unit, "number") and ("%.2f s"):format(unit) or nil)
		else
			-- The spell, its kind and its school in ns.CombatSpells.
			local entry, name = MINE.SpellOf(spellID)
			Trace(event, unit, spellID, name, entry and ("kind " .. entry.kind) or (name and "not in the table") or nil, entry and MINE.SchoolWords(entry.school) or nil)
		end
	end
	mine.heard = mine.heard + 1
	if mine.off then
		-- A signal after all: the estimate works here.
		mine.off, mine.unheard = false, 0
		pcall(Sync)
	end
end

-- The frame that hears the signals is registered while the estimate is in use, and not otherwise. When no call registers a cast event the
-- estimate is off. Reports that wait are dropped when it goes.
local function MineFrame()
	local wanted = ns.Enabled(KEY) and (Opt("source") == "front" or Opt("where") ~= "over") and Opt("whose") ~= "all"
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
		mine.castSlots, mine.castTaken, mine.auraSlots, mine.dots = {}, -1, {}, setmetatable({}, { __mode = "k" })
		mine.pair, mine.spin, mine.sweep, mine.swings, mine.counter, mine.struckAt = nil, nil, nil, {}, nil, {}
	end
	if not wanted then
		if #mine.queue > 0 then
			mine.queue = {}
		end
		-- Also after an error in a frame that judged the reports, which leaves the frame that runs them on with none waiting.
		if mine.flusher then
			mine.flusher:SetScript("OnUpdate", nil)
		end
	end
end

-- True when a hit report for a nameplate or for the target counts under Whose hits and Enemies, then the slot it took ("extra slot" for an extra
-- attack, "next swing" for Maul and the like), the icon of the action, the name of the spell matched and the pair of a next melee ability. A
-- plate that Target only leaves out is not judged, so it is not counted as shown. Under Yours an enemy only you and your pet fight (Engaged)
-- takes every damage hit and miss word, and a slot only names it. event is the kind of the report (MineOne reads it, and the trace), amount is
-- for /flatui combat trace, and at is the time of the report. Last comes the strike's damage of a cast slot (MINE.Rival).
local function Counts(plate, unit, school, flag, event, amount, at)
	local keep, why, icon, spell, pair, damage, decision
	if Opt("whose") ~= "all" then
		-- Reports in combat with no signal of yours heard since login or the last change of zone: the estimate has nothing to go on.
		if mine.heard == 0 and InCombatLockdown() then
			mine.unheard = mine.unheard + 1
			if mine.unheard >= MINE.offAfter and not mine.off then
				mine.off = true
				Sync()
			end
		end
		if not (mine.off or (Opt("units") == "target" and plate ~= Plate("target"))) then
			local now = at or GetTime()
			-- A heal on an enemy is the enemy's own or another's: the slots decide it.
			local own = event ~= "HEAL" and MINE.Engaged(unit, plate or unit, now)
			keep, why, icon, spell, pair, damage = MineOne(plate, unit, school, flag, own, now, event)
			if own and not keep then
				keep = true
				mine.kept, mine.last = mine.kept + 1, MINE.Decision("yours", "an enemy only you fight", school)
			end
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
	return true, why, icon, spell, pair, damage
end

-- The colour of a hit of yours and the name to show after it, by the slot it took. Without Colour by school of magic every hit of a spell or
-- special attack (cast slot, next swing, channel, spin, sweep, counter) is yellow, whatever its school, and every swing, extra attack, shot and
-- swing of your pet's is white. With it, the school gives the colour, except that Physical ability hits Yellow makes a physical hit of a spell
-- or special attack yellow. Without the school colours, Physical ability hits White makes a physical hit of one white. Next melee ability names
-- After the number gives the name of the ability (spell) to each report of its pair.
local function Ability(why, school, r, g, b, spell)
	local named = why == "cast slot" or why == "next swing" or why == "channel" or why == "spin" or why == "sweep" or why == "counter"
	if not (named or why == "swing slot" or why == "extra slot" or why == "shot slot" or why == "pet swing") then
		return r, g, b
	end
	local physical = ns.IsSecret(school) or type(school) ~= "number" or school == 1
	local name = why == "next swing" and Opt("abilityName") == "after" and Plain(spell, "string") and spell or nil
	if Opt("school") then
		if named and physical and Opt("abilityColour") == "spell" then
			r, g, b = Colour(0)
		end
	elseif named and not (physical and Opt("abilityColour") == "white") then
		r, g, b = Colour(0)
	else
		r, g, b = Colour(1)
	end
	return r, g, b, name
end

-- The rule of Describe for a word: a report of a word event, or a hit of no amount. A withheld amount (every amount from build 70755 on) is a
-- word only for a full block, which has its own flag.
function MINE.IsWord(event, amount, flag)
	if WORDS[event] ~= nil then
		return true
	elseif event ~= "WOUND" then
		return false
	elseif ns.IsSecret(amount) then
		return Plain(flag, "string") and flag == "BLOCK"
	end
	return type(amount) ~= "number" or amount == 0
end

-- True for a flag that adds no word after a number: none, a plain hit or a critical one.
function MINE.Bare(flag)
	if ns.IsSecret(flag) then
		return false
	end
	return flag == nil or flag == "" or flag == "CRITICAL"
end

-- True for two reports of the pair of one next melee ability that are drawn as one number: withheld amounts of WOUND with no word after them,
-- on a client that writes withheld amounts (ns.CombatWithheld).
function MINE.Joinable(a, b)
	local util = C_StringUtil
	return a.event == "WOUND" and b.event == "WOUND" and not a.word and not b.word and ns.IsSecret(a.amount) and ns.IsSecret(b.amount)
		and MINE.Bare(a.flag) and MINE.Bare(b.flag) and type(util) == "table" and type(util.TruncateWhenZero) == "function" and type(util.WrapString) == "function"
end

-- Draws a hit report that counts: { plate, unit, event, flag, amount, school, over (the number over the enemy), out (its copy in the Outgoing
-- scroll area), why, icon, spell }. partner is the other report of the same next melee ability on the same enemy, judged in the same frame: both
-- are withheld amounts, one of them the swing it replaced, a zero, and the two are written as one number.
function MINE.Draw(e, partner)
	-- A plain 0 that the pair of a next melee ability took is the swing it replaced, on a client that does not withhold the amount: it shows
	-- nothing, not Miss.
	if e.why == "next swing" and e.event == "WOUND" and e.word and not ns.IsSecret(e.amount) and MINE.Bare(e.flag) then
		return
	end
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(e.event, e.flag, e.amount, e.school)
	if not kind then
		return
	end
	local value2
	if partner then
		value2 = partner.amount
		crit = crit or (Plain(partner.flag, "string") and partner.flag == "CRITICAL")
	end
	local name, flag, extra = nil, e.flag, false
	if kind == "amount" and e.why == "extra slot" then
		-- The number has the colour of a swing, and (Extra attack) goes with it as a name does, so a zero draws neither. The Outgoing copy gets
		-- the same words from the flag EXTRA (ScrollText).
		r, g, b = Ability(e.why, e.school, r, g, b)
		name, flag, extra = "(Extra attack)", "EXTRA", true
	elseif kind == "amount" and e.event == "WOUND" then
		r, g, b, name = Ability(e.why, e.school, r, g, b, e.spell)
	end
	local shown = e.over and Spawn(e.plate, e.unit, kind, value, suffix, crit, r, g, b, nil, sign, nil, scale, name, value2)
	local format = (name and not extra) and ("%s " .. name:gsub("%%", "%%%%")) or "%s"
	if e.out and ns.ScrollText.Show("out", kind, value, format, crit, r, g, b, scale, Plain(flag, "string") and flag or nil, nil, e.icon, value2) then
		shown = true
	end
	if shown and not proven then
		-- The game's rows are switched off only once a hit report has been shown.
		proven = true
		Sync()
	end
end

-- Reports wait ---------------------------------------------------------------------------------------------------------------------

-- Under Yours a report on an enemy waits MINE.hold seconds before it is judged (see MINE), so that a cast, a swing and a hit the game sends in
-- one frame, or a few frames apart, count in any order, and a physical one waits with the others on its enemy (Wait). The reports judged
-- together are judged in the order they came, a swing and a strike among them are put right (MINE.Rival), and then they are drawn, the two of a
-- pair as one number.
-- The reports for a plate that goes are judged at once, while the game still gives its plate (OnRemoved): the hit that kills an enemy comes
-- just before its plate goes, and would else go with it. A report whose plate took another unit meanwhile goes. At most MINE.queueMax wait:
-- past that every one is judged at once. unit, when given, is the token of the plate that goes.
MINE.decided = {}

function MINE.FlushTick()
	ns.Try(KEY, MINE.Flush)
end

function MINE.Flush(all, unit)
	local decided = MINE.decided
	for index = #decided, 1, -1 do
		decided[index] = nil
	end
	local list = mine.queue
	local now = GetTime()
	for _, e in ipairs(list) do
		e.due = all or now - (e.with and e.with.last or e.at) >= MINE.hold or (unit ~= nil and e.unit == unit)
	end
	local index = 1
	while index <= #list do
		local e = list[index]
		if e.due then
			table.remove(list, index)
			if e.route == "target" or Plate(e.unit) == e.plate then
				local counted, why, icon, spell, pair, damage = Counts(e.plate, e.unit, e.school, e.flag, e.event, e.amount, e.at)
				if counted then
					e.why, e.icon, e.spell, e.pair, e.damage, e.drawn = why, icon, spell, pair, damage, false
					decided[#decided + 1] = e
				end
			end
		else
			index = index + 1
		end
	end
	MINE.Rival(decided)
	for at, e in ipairs(decided) do
		if not e.drawn then
			e.drawn = true
			local partner
			if e.pair then
				for later = at + 1, #decided do
					local other = decided[later]
					if not other.drawn and other.pair == e.pair and other.route == e.route and other.plate == e.plate and MINE.Joinable(e, other) then
						other.drawn, partner = true, other
						break
					end
				end
			end
			MINE.Draw(e, partner)
		end
	end
	for at = #decided, 1, -1 do
		decided[at] = nil
	end
	if #mine.queue == 0 and mine.flusher then
		mine.flusher:SetScript("OnUpdate", nil)
	end
end

-- The rule of a swing and a strike (see MINE): for each physical report judged together that took a cast slot, the reports on its enemy within
-- MINE.hold seconds of it that took a swing of yours. A strike with a weapon part (damage "weapon") takes the largest amount of them and one of
-- a fixed damage (damage "flat") the smallest: when that is a swing's report, the two swap the slot, the name and the icon. When the amounts are
-- not all plain numbers (a withheld amount cannot be compared), when the largest or the smallest is there twice, or when the strike has no
-- damage of the two, each of them shows with no spell name and no icon, in the colour of its school, rather than a wrong one.
function MINE.Rival(decided)
	for _, strike in ipairs(decided) do
		if strike.why == "cast slot" and not strike.ruled and Plain(strike.school, "number") and strike.school == 1 then
			local group = { strike }
			for _, e in ipairs(decided) do
				if (e.why == "swing slot" or e.why == "extra slot") and not e.ruled and e.route == strike.route and e.plate == strike.plate
					and math.abs(e.at - strike.at) <= MINE.hold then
					group[#group + 1] = e
				end
			end
			if #group > 1 then
				local damage, plain, pick, twice = strike.damage, true, nil, false
				for _, e in ipairs(group) do
					e.ruled = true
					plain = plain and not e.word and Plain(e.amount, "number")
				end
				if plain and (damage == "weapon" or damage == "flat") then
					for _, e in ipairs(group) do
						if pick == nil or (damage == "weapon" and e.amount > pick.amount) or (damage == "flat" and e.amount < pick.amount) then
							pick, twice = e, false
						elseif e.amount == pick.amount then
							twice = true
						end
					end
				end
				if pick and not twice then
					strike.why, pick.why = pick.why, strike.why
					strike.icon, pick.icon = pick.icon, strike.icon
					strike.spell, pick.spell = pick.spell, strike.spell
				else
					for _, e in ipairs(group) do
						e.why, e.icon, e.spell = "unnamed", nil, nil
					end
					mine.last = MINE.Decision("yours", "a swing or a strike, not sure which", strike.school)
				end
			end
		end
	end
end

-- A report waits MINE.hold seconds. The frame that judges them runs only while one waits. A physical report waits with the first physical report
-- on its enemy that waits and came at most MINE.hold seconds before it (with, whose last is the last that joined it), and they are judged
-- together once the last has waited MINE.hold seconds, so that a swing and a strike that land together are judged together (MINE.Rival).
function MINE.Wait(e)
	if #mine.queue >= MINE.queueMax then
		MINE.Flush(true)
	end
	local list = mine.queue
	if Plain(e.school, "number") and e.school == 1 then
		e.with, e.last = e, e.at
		for _, other in ipairs(list) do
			if other.with == other and other.route == e.route and other.plate == e.plate and e.at - other.at <= MINE.hold then
				e.with, other.last = other, e.at
				break
			end
		end
	end
	list[#list + 1] = e
	if not mine.flusher then
		mine.flusher = CreateFrame("Frame")
	end
	if #list == 1 then
		mine.flusher:SetScript("OnUpdate", MINE.FlushTick)
	end
end

-- A report judged under Whose hits: it waits under Yours and is judged and drawn at once under Everyone's.
function MINE.Judge(e)
	if Opt("whose") ~= "all" then
		MINE.Wait(e)
		return
	end
	local counted, why, icon, spell, pair = Counts(e.plate, e.unit, e.school, e.flag, e.event, e.amount, e.at)
	if counted then
		e.why, e.icon, e.spell, e.pair = why, icon, spell, pair
		MINE.Draw(e)
	end
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
	MINE.Judge({ route = "target", plate = Plate("target"), unit = unit, event = event, flag = flag, amount = amount, school = school,
		word = MINE.IsWord(event, amount, flag), over = false, out = true, at = Now() })
end

-- A hit on an enemy, or on a friendly unit. The game names one unit token for each enemy with a nameplate, so no hit shows twice. The
-- event has no field for who made the hit.
local function OnCombat(unit, event, flag, amount, school)
	-- The player's own character, whatever Numbers over enemies is set to. An error in it is counted and does not stop the numbers
	-- over enemies.
	if Plain(unit, "string") and (unit == "player" or unit == "vehicle") then
		-- A physical hit that struck you lets a counterattack of yours in (Retaliation, MINE.OnStruck).
		if mine.counter and unit == "player" and Plain(event, "string") and event == "WOUND" and Plain(school, "number") and school == 1 then
			MINE.OnStruck(Now())
		end
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
	if not (over or out) then
		return
	end
	MINE.Judge({ route = "plate", plate = plate, unit = unit, event = event, flag = flag, amount = amount, school = school,
		word = MINE.IsWord(event, amount, flag), over = over, out = out, at = Now() })
end

-- A plate that gets a unit starts its numbers again, and shows none from the unit before, and the damage over time of yours recorded on the
-- unit before goes too, as does the hit of a slot of yours on it, which tied that unit to you.
local function OnAdded(unit)
	plateOf.at = nil
	if Plain(unit, "string") then
		local plate = Plate(unit)
		if plate then
			count[plate], mine.dots[plate], mine.hitBy[plate] = nil, nil, nil
			for index = #live, 1, -1 do
				if live[index].plate == plate then
					Release(index)
				end
			end
		end
	end
end

-- A number whose plate goes stays where it was on screen. One whose place cannot be read goes with the plate. The reports that wait for the
-- plate are drawn first, as the game still gives the plate in this event (Blizzard_NamePlates.lua:177-181 reads it then).
local function OnRemoved(unit)
	plateOf.at = nil
	if Plain(unit, "string") then
		if #mine.queue > 0 then
			MINE.Flush(false, unit)
		end
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
	-- The combat alerts follow their rows, the page and the profile (CombatCues.lua).
	if ns.CombatCuesRefresh ~= nil then
		ns.CombatCuesRefresh()
	end
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
		if Opt("whose") ~= "all" then
			if mine.off then
				lines[#lines + 1] = "Whose hits: none of your casts or swings reached Flat UI here, so the game's own numbers show."
			else
				lines[#lines + 1] = ("Whose hits: yours. Every hit on an enemy only you and your pet fight; elsewhere one for each of your casts, swings, shots, auras and pet swings. Left out as not yours: %d."):format(mine.left)
				if InGroup() and Opt("group") == "flat" then
					lines[#lines + 1] = "Whose hits: in a group, a proc that casts nothing shows only in the game's own numbers (Numbers over enemies in a group)."
				end
			end
		end
		if GroupHand() and Read(VARS[1].name) ~= "0" then
			lines[#lines + 1] = "Numbers over enemies: in a group, the game's own numbers show, at Size of experience and other gains, as the game has one size for both."
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
	-- From build 70755 the game withholds every amount (UnitDocumentation.lua:4178), so a count of them says nothing and has no line here.
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
				print(("Size of experience and other gains: %s%s."):format(GAIN_WORDS[Opt("gainSize")] or tostring(Opt("gainSize")), (Switch() == "0" or GroupHand()) and "" or ", not in use"))
			end
		end
	end
	print(("classicStyleWorldText: %s"):format(Read("classicStyleWorldText") or "not in this client"))
	print(("At login: %s"):format(atLogin or "nothing remembered"))
	print(("Hit reports: %d for nameplates, %d for target."):format(stats.reports, stats.target))
	print(("Shown: %d. No nameplate: %d. On friendly units: %d. Report unreadable: %d."):format(stats.shown, stats.noPlate, stats.friendly, stats.detail))
	print(("Last hit report: %s"):format(Reported(last) or "none"))
	print(("Your hits: %d shown, %d left out. Casts and swings seen: %d. Swings and shots the game reported: %d. Auras the game would not tell about: %d. Last hit: %s."):format(mine.kept, mine.left, mine.heard, mine.swingCount, mine.blind, mine.last or "none"))
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
