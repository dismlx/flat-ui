local _, ns = ...

-- Lava tick timer (general.lavaTimer on the World and cursor page, In lava zones by default): a bar of the addon's own that times the ticks of
-- lava, so a player who swims or walks in it can be in the air, by a jump, when the next one lands. Lava hits whoever stands or swims in it with
-- fire every 2 seconds, and a timed jump avoids one tick even when the player lands back in it (Wowpedia, "Lava"; player reports of crossing the
-- lava of Molten Core and Blackrock Depths). In cMaNGOS, an emulator and not the game's own code, its first pulse comes 1 second after the player
-- enters the liquid and one every 2 seconds after, and the timer never reaches the client (Player.cpp:164-176, 1164-1176 and 1199-1340,
-- Player.h:411-417), so no call of the game tells the time; MIRROR_TIMER_START covers only fatigue, breath, death and feign death
-- (Blizzard_MirrorTimer/Mainline/MirrorTimer.lua:1-8). The combat log is closed to addons on this client, so its ENVIRONMENTAL_DAMAGE of type LAVA
-- cannot be read either. What can be seen is UNIT_COMBAT for the player (UnitDocumentation.lua:4168-4181): its event, flag and school mask are
-- plain, its amount is withheld and is never read, and it names no source or spell. A tick is a WOUND or IMMUNE on the player of the fire school
-- alone (mask 4), in a lava place or anywhere as the row says, while no Hellfire of the player's own runs (UnitChannelInfo, its spell ID 1949,
-- 11683 or 11684; a channel whose spell the game withholds counts as Hellfire for a warlock). Out of combat (UnitAffectingCombat) or while
-- swimming (IsSwimming) such a hit is a tick at once; in a fight it is one only when it comes 1 to 4 periods after the last tick or the last such
-- hit, give or take 0.25 seconds, so a fire spell off the rhythm never moves the countdown. It cannot tell lava from a fire damage over time that
-- ticks every 2 seconds in a fight, or from a campfire out of one: it is an estimate, and its row and /flatui lava say so.
-- A lava place is a dungeon or raid by its instance ID, the 8th answer of GetInstanceInfo (InstanceDocumentation.lua:103-120): Molten Core 409,
-- Blackrock Depths 230, Blackrock Spire 229 and Ragefire Chasm 389; or a map of the zone, walking up at most six steps from
-- C_Map.GetBestMapForUnit('player') by the parentMapID of C_Map.GetMapInfo (MapDocumentation.lua:49 and 312): Searing Gorge 1427, Burning Steppes
-- 1428 and Un'Goro Crater 1449, which also holds the Blackrock Mountain hub under the first two. These are the classic IDs; names are never read,
-- since the game gives them in the player's language. /flatui lava says the IDs of the place, for a place that turns out to be missing.
-- The timeline: a tick seen at time A puts the k-th next one at A + 2k, and the server judges where the player is by what it last heard, so the
-- danger moment is A + 2k minus the world latency of GetNetStats (its 4th answer, ConnectionDocumentation.lua:40-49), held to 0 to 0.4 seconds. The
-- bar fills from one danger moment to the next; the jump window, Jump lead long, is a band at its right end in the jump colour with a mark at its
-- start, and the fill takes that colour inside it. Crossing into the window cues once a period: the word Jump, a flash if Flash when it is time to
-- jump is on, and the sound of Jump sound on the Gameplay SFX channel (as Cooldowns.lua plays its ready sounds). Around each danger moment (0.1
-- seconds either side) it reads IsFalling('player') each frame (UnitDocumentation.lua:405-418). 0.3 seconds after the tick was due, a tick seen
-- says Hit and starts the timeline again; none while the player was in the air says Dodged (Dodged x2, x3 as the dodges in a row build, and a hit
-- ends the streak); none on the ground says nothing (the player most likely left the lava). The bar fades in over FADE_IN seconds as it shows,
-- and fades out over FADE_OUT 5 seconds after the last tick or dodge, with nothing counted or cued while it fades; a tick then brings it back
-- whole at once. After ten dodges in a row with no tick in between only a tick keeps it. Death, the row going Off and the end of test mode hide it
-- at once. Its fades are the alpha of its own frame (SetAlpha), written only when it changes. Nothing is protected: an addon cannot jump for the
-- player (JumpOrAscendStart is protected), so the bar only cues.
-- The bar is a frame of the addon's own, a child of UIParent in the LOW strata that takes no mouse and hides with the interface, with the outline
-- of the Flat UI page (ns.Outline), a StatusBar in the bar texture of that page over a dim track, and its words in GameFontHighlightSmall. It is
-- made the first time it shows, and it runs OnUpdate only while it shows. /flatui move places it (FlatUILavaTimer in Movers.lua, its middle at the
-- middle of the box, just under the character), with a box while the row is not Off. A frame of the addon's own hears UNIT_COMBAT for the player
-- (RegisterUnitEvent, else every unit and the handler keeps the player's), PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA, ZONE_CHANGED,
-- ZONE_CHANGED_INDOORS and PLAYER_DEAD while the row is not Off, and nothing while it is. Nothing of the game is written. Not a module, as the
-- cursor ring (CursorRing.lua): Core.lua applies the rows at login and when the profile changes, and the rows call ns.LavaChanged themselves;
-- Jump sound calls ns.LavaSoundPicked, which also plays the sound picked once while the options window shows and out of a fight, as the combat
-- sounds do (CombatCues.lua), so it can be chosen by ear. None plays nothing.
-- Test mode (TestMode.lua) cannot run an entry of a file that is no module (TM.Register runs one only while its module is on), so at every On, Off,
-- pause and resume (TM.Watch) the rows are applied again, and while it is on the bar shows a sample at its spot: a tick every 2 seconds, the
-- window, the cue and its flash, a Hit and then Dodged and Dodged x2, frozen while the bar's Moving is off. Its sound plays only when
-- TM.Sound('lava') allows it, the first time after an On. /flatui lava test shows the same sample for 8 seconds, with one sound. A real tick takes
-- over from the sample. /flatui lava says the mode, the place and its IDs, the ticks seen, dodged (with the most in a row) and not seen this
-- session, the last hit on the player, the last gaps between ticks and the latency used; /flatui lava trace prints a line for every UNIT_COMBAT of
-- the player with what the timer made of it, the way to check in lava that this client reports its ticks at all. /flatui status has a line only
-- when the hits could not be heard, or after an error, which stops the timer until /reload.
-- The idea is the timing bar of the Classic WeakAura "Avoid lava damage" (wago.io), which shows when to jump before the tick; none of its code or
-- text is used, and its trigger, the combat log, is not open here.

local MOVER = "FlatUILavaTimer"
-- The box of the handle in Movers.lua: the bar's default size, and where its middle is with no spot saved.
local BOX_W, BOX_H, BOX_X, BOX_Y = 160, 14, 0, -100
local MODES = { zones = true, anywhere = true }
-- The period of lava, the slack of a tick that keeps the rhythm, the wait past a due tick before it counts as not come, the seconds the bar stays
-- after the last tick or dodge, the dodges in a row that keep it, the time either side of a danger moment that the jump is read, and the periods
-- a tick is kept to judge the rhythm by.
local PERIOD, SLACK, GRACE, HIDE, DODGE_MAX, AIR, KEEP = 2, 0.25, 0.3, 5, 10, 0.1, 4
-- The sample ticks once every this many periods and dodges the others.
local SAMPLE_EVERY = 3
-- The highest latency counted, the time of a flash, of a word after a tick, and of /flatui lava test.
local RTT_MAX, FLASH_TIME, SAY_TIME, TEST_TIME = 0.4, 0.3, 0.6, 8
-- The seconds the bar takes to fade in as it shows, and to fade out once you left the lava.
local FADE_IN, FADE_OUT = 0.15, 0.4
-- The fire school (CombatText.lua:98).
local FIRE = 4
local HITS = { WOUND = true, IMMUNE = true }
-- The classic instance and zone map IDs of the places with lava; the names are for /flatui lava only.
local INSTANCES = { [409] = "Molten Core", [230] = "Blackrock Depths", [229] = "Blackrock Spire", [389] = "Ragefire Chasm" }
local MAPS = { [1427] = "Searing Gorge", [1428] = "Burning Steppes", [1449] = "Un'Goro Crater" }
local MAP_STEPS = 6
-- Hellfire's ranks, which burn the warlock with fire every second.
local HELLFIRE = { [1949] = true, [11683] = true, [11684] = true }
local PLACE_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_DEAD" }
-- The choices of Jump sound, as the No target sound's (CombatCues.lua), by their place in ns.SOUNDS (IconRow.lua).
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local SOUND_CHANNEL = "Gameplay SFX"
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local RED, GREEN, TEXT = { 0.95, 0.25, 0.2 }, { 0.2, 0.85, 0.35 }, { 1, 1, 1 }
local GAPS_KEPT = 5
local STEPS_MOST = 50

local IsSecret, Finite = ns.IsSecret, ns.Finite

-- The state. mode: the row's choice in use. lava: this is a lava place; where: what the place was read from. listening: the hearer hears; deaf: the
-- game took no UNIT_COMBAT. live: a real timeline runs; sample: the sample runs; sampleUntil: the end of /flatui lava test; testSound: its one
-- sound is still to play. anchor: the tick the timeline runs from; k: the period counted down; cued: the last period cued; air: the player was in
-- the air at the danger moment of k; pendK and pendAir: the period past its danger moment and not yet judged. lastReal: the last real tick; held: a
-- fire hit in a fight that waits for a second to set the rhythm. lastAlive: the last tick or dodge; streak: the dodges in a row, and best the most
-- of real ones this session; flip: the period of the sample, a tick every SAMPLE_EVERY. rtt: the latency of the timeline. say, sayRGB and sayUntil:
-- the word after a tick. flashAt and flashPeak: the flash. seen, dodged, unseen and gaps: what /flatui lava counts. trace: /flatui lava trace is
-- on. broken: the error that stopped the timer.
local S = { lava = false, where = {}, listening = false, deaf = false, live = false, sample = false, k = 1, cued = 0, air = false, pendAir = false,
	streak = 0, best = 0, rtt = 0, seen = 0, dodged = 0, unseen = 0, gaps = {}, trace = false, flip = 0 }
-- The last UNIT_COMBAT of the player, for /flatui lava.
local LAST = {}
-- The bar: frame, outline, bar, track, band, mark, flash, word and count, once made; placed: the spot it was put at; file: the bar texture on it;
-- width and lead: of the rows; lavaRGB and jumpRGB: the colours; shown: the word, its colour, the count and the band width written last. alpha:
-- the frame's alpha written last; fadeInAt: when it began to fade in; fadeOutAt and fadeFrom: when it began to fade out, and from what alpha.
local U = {}

local Stop

local function Mode()
	local mode = ns.Get("general.lavaTimer")
	return MODES[mode] and mode or nil
end

-- A number row held to its range, else its default.
local function Number(key, fallback, low, high)
	local value = ns.Get("general." .. key)
	if not Finite(value) then
		value = fallback
	end
	return math.max(low, math.min(high, value))
end

-- The first answer of a call of the client when it is plain, else nil.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- True only for a plain true.
local function Yes(fn, ...)
	return Ask(fn, ...) == true
end

-- A value of the game as /flatui lava prints it.
local function Plain(value)
	if IsSecret(value) then
		return "withheld"
	elseif value == nil or value == "" then
		return "none"
	end
	return tostring(value)
end

local function Testing()
	local test = ns.TestMode
	return type(test) == "table" and test.IsOn() == true
end

-- True while a sample shows: test mode is on, or /flatui lava test runs.
local function Sampling(now)
	return Testing() or (S.sampleUntil ~= nil and now < S.sampleUntil)
end

-- False only while test mode is on and its Moving is off, which freezes the sample.
local function Moving()
	local test = ns.TestMode
	return not (Testing() and type(test.Moving) == "function" and test.Moving() == false)
end

-- The world latency in seconds, held to 0 to RTT_MAX.
local function Latency()
	if type(GetNetStats) ~= "function" then
		return 0
	end
	local ok, _, _, _, world = pcall(GetNetStats)
	if not ok or not Finite(world) then
		return 0
	end
	return math.max(0, math.min(RTT_MAX, world / 1000))
end

-- The place: a lava place by its instance ID or the maps it lies in, and the IDs read, for /flatui lava.
local function ReadPlace()
	local where, lava = { chain = {} }, false
	if type(GetInstanceInfo) == "function" then
		local ok, _, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
		if ok and Finite(id) then
			where.instance = id
			if INSTANCES[id] then
				lava, where.name = true, INSTANCES[id]
			end
		end
	end
	local maps = C_Map
	if type(maps) == "table" and not IsSecret(maps) then
		local id = Ask(maps.GetBestMapForUnit, "player")
		for _ = 1, MAP_STEPS do
			if not Finite(id) or id <= 0 then
				break
			end
			where.chain[#where.chain + 1] = id
			if MAPS[id] then
				lava, where.name = true, where.name or MAPS[id]
				break
			end
			local info = Ask(maps.GetMapInfo, id)
			id = type(info) == "table" and info.parentMapID or nil
		end
	end
	S.lava, S.where = lava, where
end

-- True while the player channels Hellfire, which burns the warlock with fire.
local function Hellfire()
	if type(UnitChannelInfo) ~= "function" then
		return false
	end
	local ok, name, _, _, _, _, _, _, spell = pcall(UnitChannelInfo, "player")
	if not ok or (not IsSecret(name) and name == nil) then
		return false
	end
	if Finite(spell) then
		return HELLFIRE[spell] == true
	end
	local _, _, class = pcall(UnitClass, "player")
	return not IsSecret(class) and class == "WARLOCK"
end

-- True for a gap that is one to KEEP periods, give or take SLACK.
local function Fits(gap)
	for k = 1, KEEP do
		if math.abs(gap - k * PERIOD) <= SLACK then
			return true
		end
	end
	return false
end

-- What a hit on the player is: "tick", "held" (a fire hit in a fight off any rhythm, kept to judge the next by) or nil, and why.
local function Judge(action, school, now)
	S.fighting, S.swimming = nil, nil
	if IsSecret(action) or not HITS[action] then
		return nil, "not a hit or immune"
	elseif IsSecret(school) or school ~= FIRE then
		return nil, "not fire alone"
	elseif Mode() == "zones" and not S.lava then
		return nil, "not a lava place"
	elseif Hellfire() then
		return nil, "your Hellfire"
	end
	S.fighting, S.swimming = Yes(UnitAffectingCombat, "player"), Yes(IsSwimming, "player")
	if not S.fighting then
		return "tick", "out of combat"
	elseif S.swimming then
		return "tick", "swimming"
	end
	local recent = S.lastReal ~= nil and now - S.lastReal <= KEEP * PERIOD + SLACK
	if (recent and Fits(now - S.lastReal)) or (S.held and Fits(now - S.held)) then
		return "tick", "in combat, on the rhythm"
	elseif S.live then
		return nil, "in combat, off the rhythm"
	end
	S.held = now
	return "held", "in combat, waits for a second one on the rhythm"
end

-- The look ----------------------------------------------------------------------------------------------------------------------------------------

-- The bar, made the first time it shows.
local function Build()
	if U.frame then
		return U.frame
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:Hide()
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(false)
	frame:SetSize(BOX_W, BOX_H)
	U.outline = ns.Outline(frame, frame, true)
	local bar = CreateFrame("StatusBar", nil, frame)
	ns.Own[bar] = true
	bar:SetAllPoints(frame)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	pcall(bar.EnableMouse, bar, false)
	local track = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	ns.Own[track] = true
	track:SetAllPoints(bar)
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
	-- The jump window at the right end of the track, and the mark where it starts.
	local band = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
	ns.Own[band] = true
	band:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
	band:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	band:SetWidth(1)
	local mark = bar:CreateTexture(nil, "OVERLAY", nil, 1)
	ns.Own[mark] = true
	mark:SetPoint("TOP", band, "TOPLEFT", 0, 0)
	mark:SetPoint("BOTTOM", band, "BOTTOMLEFT", 0, 0)
	mark:SetWidth(2)
	local flash = bar:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[flash] = true
	flash:SetAllPoints(frame)
	flash:SetColorTexture(1, 1, 1, 1)
	pcall(flash.SetBlendMode, flash, "ADD")
	flash:SetAlpha(0)
	local word = ns.OwnText(bar, "OVERLAY", FONT)
	word:SetJustifyH("LEFT")
	word:SetWordWrap(false)
	word:SetPoint("LEFT", bar, "LEFT", 4, 0)
	local count = ns.OwnText(bar, "OVERLAY", FONT)
	count:SetJustifyH("RIGHT")
	count:SetWordWrap(false)
	count:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	U.frame, U.bar, U.band, U.mark, U.flash, U.word, U.count = frame, bar, band, mark, flash, word, count
	U.shown = {}
	return frame
end

-- Puts the middle of the bar at the middle of its handle's box.
local function Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "CENTER")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if U.placed == key then
		return
	end
	U.placed = key
	U.frame:ClearAllPoints()
	if x then
		U.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		U.frame:SetPoint("CENTER", UIParent, "CENTER", BOX_X, BOX_Y)
	end
end

-- The rows on the bar: its size, texture, text height, colours and lead. A texture the game refuses leaves a flat fill.
local function Paint()
	local width, height = Number("lavaWidth", BOX_W, 80, 400), Number("lavaHeight", BOX_H, 8, 30)
	U.frame:SetSize(width, height)
	U.width, U.lead = width, Number("lavaLead", 400, 100, 800) / 1000
	local file = ns.BarTexture() or WHITE
	if U.file ~= file then
		local ok, done = pcall(U.bar.SetStatusBarTexture, U.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(U.bar.SetStatusBarTexture, U.bar, WHITE)
		end
		U.file = file
	end
	local text = math.max(7, math.min(16, height - 2))
	U.word:SetTextHeight(text)
	-- The word stops short of the count at the right end, so "Dodged x3" never runs under it on a narrow bar.
	U.word:SetWidth(math.max(20, width - 36))
	U.count:SetTextHeight(text)
	U.lavaRGB = { ns.Colour("general.lavaColour") }
	U.jumpRGB = { ns.Colour("general.lavaJumpColour") }
	local jump = U.jumpRGB
	U.band:SetColorTexture(jump[1], jump[2], jump[3], 0.35)
	U.mark:SetColorTexture(jump[1], jump[2], jump[3], 1)
	U.shown = {}
	-- Made outside a module's code, the outline follows the Flat UI page.
	ns.SetOutlineArea(U.outline, nil)
	Place()
end

local function Flash(rgb, peak, now)
	U.flash:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
	S.flashAt, S.flashPeak = now, peak
end

local function Say(word, rgb, now)
	S.say, S.sayRGB, S.sayUntil = word, rgb, now + SAY_TIME
end

-- The timeline ------------------------------------------------------------------------------------------------------------------------------------

-- When the server judges period k of the timeline.
local function Danger(k)
	return S.anchor + k * PERIOD - S.rtt
end

local Refresh

-- A tick at time at starts the timeline again: a real one, or one of the sample.
local function Tick(at, sample)
	local now = GetTime()
	if not sample then
		if S.lastReal and at - S.lastReal <= KEEP * PERIOD + SLACK then
			table.insert(S.gaps, 1, at - S.lastReal)
			S.gaps[GAPS_KEPT + 1] = nil
		end
		S.lastReal, S.held, S.seen = at, nil, S.seen + 1
		S.live, S.sample, S.sampleUntil = true, false, nil
		S.rtt = Latency()
	else
		S.rtt = 0
	end
	S.anchor, S.k, S.cued, S.air, S.pendK, S.pendAir = at, 1, 0, false, nil, false
	S.lastAlive, S.streak = now, 0
	Say("Hit", RED, now)
	Flash(RED, 0.3, now)
	if not sample then
		Refresh()
	end
end

-- Period k is past and no tick came: Dodged when the player was in the air, with the dodges in a row from the second ("Dodged x2"), else nothing.
-- The sample ticks every SAMPLE_EVERY periods and dodges the others, so its count shows too.
local function Settle(k, air, now)
	if S.sample then
		S.flip = (S.flip + 1) % SAMPLE_EVERY
		if S.flip == 1 then
			Tick(S.anchor + k * PERIOD, true)
			return
		end
		air = true
	end
	if air then
		S.streak = S.streak + 1
		if not S.sample then
			S.dodged = S.dodged + 1
			S.best = math.max(S.best, S.streak)
		end
		if S.streak <= DODGE_MAX then
			S.lastAlive = now
		end
		Say(S.streak > 1 and ("Dodged x%d"):format(S.streak) or "Dodged", GREEN, now)
		Flash(GREEN, 0.3, now)
	elseif not S.sample then
		S.unseen = S.unseen + 1
	end
end

-- The sound of the sample: in test mode once after each On (TM.Sound), and once in /flatui lava test.
local function SampleSound()
	if Testing() then
		return type(ns.TestMode.Sound) == "function" and ns.TestMode.Sound("lava") == true
	end
	local first = S.testSound == true
	S.testSound = false
	return first
end

-- The cue of a period: the flash and the sound, as the rows say. The word Jump comes from the window itself.
local function Cue(now)
	if ns.Get("general.lavaFlash") == true then
		Flash(U.jumpRGB, 0.6, now)
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[ns.Get("general.lavaSound")] or 0]
	if type(sound) == "table" and type(PlaySound) == "function" and (not S.sample or SampleSound()) then
		pcall(PlaySound, sound[1], SOUND_CHANNEL)
	end
end

-- Moves the timeline on: periods whose danger moment is past wait to be judged, the jump is read around each danger moment, a period is judged
-- GRACE after its tick was due, and the cue fires once a period.
local function Advance(now)
	for _ = 1, STEPS_MOST do
		if now < Danger(S.k) then
			break
		end
		if S.pendK then
			local k, air = S.pendK, S.pendAir
			S.pendK = nil
			Settle(k, air, now)
		end
		if now >= Danger(S.k) then
			S.pendK, S.pendAir, S.air = S.k, S.air, false
			S.k = S.k + 1
		end
	end
	local nearPending = S.pendK ~= nil and now <= Danger(S.pendK) + AIR
	local nearNext = now >= Danger(S.k) - AIR
	if not S.sample and (nearPending or nearNext) and Yes(IsFalling, "player") then
		S.pendAir = S.pendAir or nearPending
		S.air = S.air or nearNext
	end
	if S.pendK and now >= S.anchor + S.pendK * PERIOD + GRACE then
		local k, air = S.pendK, S.pendAir
		S.pendK = nil
		Settle(k, air, now)
	end
	if now >= Danger(S.k) - U.lead and S.cued < S.k then
		S.cued = S.k
		Cue(now)
	end
end

-- Writes a text and its colour only when they changed; key and colourKey name them in U.shown.
local function Write(text, key, colourKey, value, rgb)
	local shown = U.shown
	if shown[key] ~= value then
		shown[key] = value
		text:SetText(value)
	end
	if shown[colourKey] ~= rgb then
		shown[colourKey] = rgb
		text:SetTextColor(rgb[1], rgb[2], rgb[3], 1)
	end
end

-- Draws the period counted down: the fill, the window, the word, the count and the flash.
local function Draw(now)
	local danger = Danger(S.k)
	local start = S.k == 1 and S.anchor or Danger(S.k - 1)
	local span, left = danger - start, danger - now
	U.bar:SetValue(span > 0 and math.max(0, math.min(1, (now - start) / span)) or 1)
	local inside = left <= U.lead
	local rgb = inside and U.jumpRGB or U.lavaRGB
	if U.shown.fill ~= rgb then
		U.shown.fill = rgb
		U.bar:SetStatusBarColor(rgb[1], rgb[2], rgb[3], 1)
	end
	local band = math.max(1, math.floor(U.width * math.min(1, U.lead / math.max(span, 0.01)) + 0.5))
	if U.shown.band ~= band then
		U.shown.band = band
		U.band:SetWidth(band)
	end
	if S.sayUntil and now < S.sayUntil then
		Write(U.word, "word", "wordRGB", S.say, S.sayRGB)
	else
		Write(U.word, "word", "wordRGB", inside and "Jump" or "Lava", inside and U.jumpRGB or TEXT)
	end
	Write(U.count, "count", "countRGB", ("%.1f"):format(math.max(0, left)), TEXT)
	local alpha = 0
	if S.flashAt then
		local part = (now - S.flashAt) / FLASH_TIME
		if part >= 1 or part < 0 then
			S.flashAt = nil
		else
			alpha = S.flashPeak * (1 - part)
		end
	end
	if U.shown.alpha ~= alpha then
		U.shown.alpha = alpha
		U.flash:SetAlpha(alpha)
	end
end

-- The alpha of the bar's own frame, written only when it changes.
local function FrameAlpha(alpha)
	if U.alpha ~= alpha then
		U.alpha = alpha
		U.frame:SetAlpha(alpha)
	end
end

local Run

local function Step(_, elapsed)
	local now = GetTime()
	-- Fading out, the bar keeps what it last drew: no period is counted, cued or sounded any more.
	if U.fadeOutAt then
		local alpha = (U.fadeFrom or 1) * (1 - (now - U.fadeOutAt) / FADE_OUT)
		if not Finite(alpha) or alpha <= 0 then
			Run(false)
		else
			FrameAlpha(math.min(1, alpha))
		end
		return
	end
	if U.fadeInAt then
		local part = (now - U.fadeInAt) / FADE_IN
		if not Finite(part) or part >= 1 or part < 0 then
			U.fadeInAt = nil
			FrameAlpha(1)
		else
			FrameAlpha(1 - (1 - part) * (1 - part))
		end
	end
	if S.sample and not Moving() then
		-- A frozen sample keeps its place in the period.
		S.anchor = S.anchor + (Finite(elapsed) and elapsed or 0)
	end
	if S.live and now - S.lastAlive > HIDE then
		S.live = false
		Refresh(true)
		return
	elseif S.sample and not Sampling(now) then
		S.sample = false
		Refresh(true)
		return
	end
	Advance(now)
	Draw(now)
end

local function SafeStep(frame, elapsed)
	local ok, err = pcall(Step, frame, elapsed)
	if not ok then
		Stop(err)
	end
end

local function StartSample(now)
	S.sample, S.flip, S.rtt = true, 0, 0
	S.anchor, S.k, S.cued, S.air, S.pendK, S.pendAir = now, 1, 0, false, nil, false
	S.say, S.sayUntil, S.flashAt = nil, nil, nil
end

-- Shows the bar, painted and placed, with its step, fading in from hidden over FADE_IN; a bar fading out is whole again at once. Hides it with
-- no step: at once, or with fade over FADE_OUT, which its step runs and then hides it.
function Run(on, fade)
	if on then
		local frame = Build()
		Paint()
		if not frame:IsShown() then
			U.fadeInAt = GetTime()
			FrameAlpha(0)
			frame:SetScript("OnUpdate", SafeStep)
			frame:Show()
		elseif U.fadeOutAt then
			U.fadeInAt = nil
			FrameAlpha(1)
		end
		U.fadeOutAt, U.fadeFrom = nil, nil
	elseif U.frame and U.frame:IsShown() then
		if fade then
			if not U.fadeOutAt then
				U.fadeOutAt, U.fadeFrom, U.fadeInAt = GetTime(), U.alpha or 1, nil
			end
			return
		end
		U.fadeInAt, U.fadeOutAt, U.fadeFrom = nil, nil, nil
		U.frame:Hide()
		U.frame:SetScript("OnUpdate", nil)
	end
end

-- Shows the real timeline, else the sample while one is wanted, else nothing: at once, or with fade (the bar's own end, 5 seconds after the last
-- tick or as /flatui lava test ends) over FADE_OUT. Death, the row going Off and the end of test mode hide it at once.
function Refresh(fade)
	local now = GetTime()
	if S.broken or Mode() == nil then
		S.live, S.sample = false, false
		Run(false)
	elseif S.live then
		S.sample = false
		Run(true)
	elseif Sampling(now) then
		if not S.sample then
			StartSample(now)
		end
		Run(true)
	else
		S.sample = false
		Run(false, fade)
	end
end

-- Hearing --------------------------------------------------------------------------------------------------------------------------------------

local function Trace(action, flag, school, verdict, why, now)
	local yes = { [true] = "yes", [false] = "no" }
	print(("Flat UI lava: %.2f %s, flag %s, school %s; in combat %s, swimming %s, falling %s, lava place %s: %s (%s)."):format(now, Plain(action),
		Plain(flag), Plain(school), S.fighting == nil and "-" or yes[S.fighting], S.swimming == nil and "-" or yes[S.swimming],
		yes[Yes(IsFalling, "player")], yes[S.lava == true], verdict or "ignored", why))
end

-- A UNIT_COMBAT of the player.
local function Heard(action, flag, amount, school)
	local now = GetTime()
	LAST.at, LAST.action, LAST.flag, LAST.school = now, Plain(action), Plain(flag), Plain(school)
	LAST.amount = IsSecret(amount) and "withheld" or "not read"
	local verdict, why = Judge(action, school, now)
	if verdict == "tick" then
		Tick(now, false)
	end
	if S.trace then
		Trace(action, flag, school, verdict, why, now)
	end
end

local function OnEvent(_, event, unit, action, flag, amount, school)
	if event == "UNIT_COMBAT" then
		if not IsSecret(unit) and unit == "player" then
			Heard(action, flag, amount, school)
		end
	elseif event == "PLAYER_DEAD" then
		S.live, S.lastReal, S.held = false, nil, nil
		Refresh()
	else
		ReadPlace()
	end
end

-- The hearer hears while the row is not Off, and nothing while it is. RegisterUnitEvent has no documented return: only an error or false counts as
-- a refusal, as in CombatText.lua.
local function Listen(on)
	if on == S.listening then
		return
	end
	if on and not U.hear then
		local frame = CreateFrame("Frame")
		ns.Own[frame] = true
		frame:SetScript("OnEvent", function(...)
			local ok, err = pcall(OnEvent, ...)
			if not ok then
				Stop(err)
			end
		end)
		U.hear = frame
	end
	local frame = U.hear
	if not frame then
		return
	end
	if on then
		local done = false
		if type(frame.RegisterUnitEvent) == "function" then
			local ok, result = pcall(frame.RegisterUnitEvent, frame, "UNIT_COMBAT", "player")
			done = ok and (IsSecret(result) or result ~= false)
		end
		if not done then
			done = pcall(frame.RegisterEvent, frame, "UNIT_COMBAT")
		end
		S.deaf = not done
		for _, event in ipairs(PLACE_EVENTS) do
			pcall(frame.RegisterEvent, frame, event)
		end
	else
		pcall(frame.UnregisterAllEvents, frame)
		S.deaf = false
	end
	S.listening = on
end

-- An error stops the timer until the next /reload, with a line for /flatui status.
function Stop(err)
	if S.broken then
		return
	end
	S.broken = tostring(err)
	S.live, S.sample = false, false
	pcall(Listen, false)
	U.fadeInAt, U.fadeOutAt = nil, nil
	if U.frame then
		pcall(U.frame.SetScript, U.frame, "OnUpdate", nil)
		pcall(U.frame.Hide, U.frame)
	end
	geterrorhandler()(err)
end

local function Apply()
	if S.broken then
		return
	end
	local mode = Mode()
	Listen(mode ~= nil)
	if mode then
		ReadPlace()
	else
		S.live, S.sampleUntil, S.lastReal, S.held = false, nil, nil, nil
	end
	Refresh()
end

-- A row of the timer changed, the player logged in, the profile changed, or test mode turned on, paused, resumed or ended.
function ns.LavaChanged()
	local ok, err = pcall(Apply)
	if not ok then
		Stop(err)
	end
end

-- Jump sound changed: the rows are applied again, and the sound picked plays once, so it can be chosen by ear, only while the options window shows
-- and out of a fight, as the combat sounds do (CombatCues.lua). None plays nothing.
function ns.LavaSoundPicked(path)
	ns.LavaChanged()
	if type(path) ~= "string" or InCombatLockdown() or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[ns.Get(path)] or 0]
	if type(sound) ~= "table" then
		return
	end
	if type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	elseif type(PlaySound) == "function" then
		pcall(PlaySound, sound[1], SOUND_CHANNEL)
	end
end

-- The movers ------------------------------------------------------------------------------------------------------------------------------------

-- True while the bar has a handle in the movers: while the row is not Off.
function ns.LavaTimerShown()
	return not S.broken and Mode() ~= nil
end

-- The movers set or put back the spot.
function ns.LavaTimerMoved()
	U.placed = nil
	if U.frame and not S.broken then
		local ok, err = pcall(Place)
		if not ok then
			Stop(err)
		end
	end
end

-- Status and commands ---------------------------------------------------------------------------------------------------------------------------

-- The line of /flatui status, only when something is wrong.
function ns.LavaStatus()
	if S.broken then
		return "Lava tick timer: stopped. " .. S.broken
	elseif Mode() and S.deaf then
		return "Lava tick timer: the game would not report the hits on you (UNIT_COMBAT), so the bar never shows."
	end
	return nil
end

local function Report()
	local mode = Mode()
	ReadPlace()
	local where, gaps = S.where, {}
	for index, gap in ipairs(S.gaps) do
		gaps[index] = ("%.2f"):format(gap)
	end
	local lines = {
		("Lava tick timer: %s. It times fire hits on you, an estimate: the game does not tell add-ons that a hit is lava."):format(
			mode == "zones" and "in lava zones" or mode == "anywhere" and "anywhere" or "off"),
		("This place: %s (instance %s, maps %s)."):format(S.lava and ("lava, " .. tostring(where.name)) or "no lava place", Plain(where.instance),
			#where.chain > 0 and table.concat(where.chain, " > ") or "none"),
		("This session: %d ticks seen, %d dodged (at best %d in a row), %d not seen (you most likely left the lava)."):format(S.seen, S.dodged,
			S.best, S.unseen),
		LAST.at and ("Last hit on you: %s, flag %s, school %s, amount %s, %.1f s ago."):format(LAST.action, LAST.flag, LAST.school, LAST.amount,
			GetTime() - LAST.at) or "No hit on you heard yet.",
		#gaps > 0 and ("Last gaps between ticks: %s s."):format(table.concat(gaps, ", ")) or "No gap between two ticks seen yet.",
		("Latency used: %.2f s, the game's world latency, at most %.1f."):format(Latency(), RTT_MAX),
		("/flatui lava test shows a sample for %d seconds. /flatui lava trace prints a line for each hit on you (now %s)."):format(TEST_TIME,
			S.trace and "on" or "off"),
	}
	if S.broken then
		lines[#lines + 1] = "It stopped after an error until /reload: " .. S.broken
	elseif mode and S.deaf then
		lines[#lines + 1] = "The game would not report the hits on you (UNIT_COMBAT), so the bar never shows."
	end
	for _, line in ipairs(lines) do
		print(line)
	end
end

-- /flatui lava, /flatui lava test and /flatui lava trace.
function ns.LavaCommand(rest)
	local word = (rest or ""):lower():match("^%s*(%S*)") or ""
	if word == "test" then
		if S.broken or Mode() == nil then
			print("Lava tick timer: choose In lava zones or Anywhere first, on Helpers > World and cursor.")
			return
		end
		S.sampleUntil, S.testSound = GetTime() + TEST_TIME, true
		ns.LavaChanged()
	elseif word == "trace" then
		S.trace = not S.trace
		print(("Lava tick timer: trace %s.%s"):format(S.trace and "on" or "off",
			S.trace and Mode() == nil and " The row is Off, so no hit is heard." or ""))
	else
		Report()
	end
end

-- Test mode: the rows are applied again at every On, Off, pause and resume; the sample shows while it is on.
if type(ns.TestMode) == "table" and type(ns.TestMode.Watch) == "function" then
	ns.TestMode.Watch(function()
		ns.LavaChanged()
	end)
end
