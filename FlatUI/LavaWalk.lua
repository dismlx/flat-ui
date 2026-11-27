local _, ns = ...

local MOVER = "FlatUILavaTimer"
local BOX_W, BOX_H, BOX_X, BOX_Y = 160, 14, 0, -100
local MODES = { zones = true, anywhere = true }
local PERIOD, SLACK, GRACE, HIDE, DODGE_MAX, AIR, KEEP = 2, 0.25, 0.3, 5, 10, 0.1, 4
local SAMPLE_EVERY = 3
local RTT_MAX, FLASH_TIME, SAY_TIME, TEST_TIME, PREVIEW = 0.4, 0.3, 0.6, 8, 4
local FADE_IN, FADE_OUT = 0.15, 0.4
local FIRE = 4
local HITS = { WOUND = true, IMMUNE = true }
local INSTANCES = { [409] = "Molten Core", [230] = "Blackrock Depths", [229] = "Blackrock Spire", [389] = "Ragefire Chasm" }
local MAPS = { [1427] = "Searing Gorge", [1428] = "Burning Steppes", [1449] = "Un'Goro Crater" }
local MAP_STEPS = 6
local HELLFIRE = { [1949] = true, [11683] = true, [11684] = true }
local PLACE_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_DEAD" }
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local SOUND_CHANNEL = "Gameplay SFX"
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TRACK = { 0.2, 0.2, 0.2, 0.5 }
local RED, GREEN, TEXT = { 0.95, 0.25, 0.2 }, { 0.2, 0.85, 0.35 }, { 1, 1, 1 }
local GOLD, RECORD_FROM = { 1, 0.82, 0.25 }, 3
local GAPS_KEPT = 5
local STEPS_MOST = 50

local IsSecret, Finite = ns.IsSecret, ns.Finite

local S = { lava = false, where = {}, listening = false, deaf = false, live = false, sample = false, k = 1, cued = 0, air = false, pendAir = false,
	streak = 0, best = 0, rtt = 0, seen = 0, dodged = 0, unseen = 0, gaps = {}, trace = false, flip = 0 }
local LAST = {}
local U = {}

local Stop

local function Mode()
	local mode = ns.Get("general.lavaTimer")
	return MODES[mode] and mode or nil
end

local function Number(key, fallback, low, high)
	local value = ns.Get("general." .. key)
	if not Finite(value) then
		value = fallback
	end
	return math.max(low, math.min(high, value))
end

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

local function Yes(fn, ...)
	return Ask(fn, ...) == true
end

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

local function Sampling(now)
	return Testing() or (S.sampleUntil ~= nil and now < S.sampleUntil)
end

local function Moving()
	local test = ns.TestMode
	return not (Testing() and type(test.Moving) == "function" and test.Moving() == false)
end

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

local function Fits(gap)
	for k = 1, KEEP do
		if math.abs(gap - k * PERIOD) <= SLACK then
			return true
		end
	end
	return false
end

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
	U.shown, U.strata = {}, "LOW"
	return frame
end

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
	U.word:SetWidth(math.max(20, width - 36))
	U.count:SetTextHeight(text)
	U.lavaRGB = { ns.Colour("general.lavaColour") }
	U.jumpRGB = { ns.Colour("general.lavaJumpColour") }
	local jump = U.jumpRGB
	U.band:SetColorTexture(jump[1], jump[2], jump[3], 0.35)
	U.mark:SetColorTexture(jump[1], jump[2], jump[3], 1)
	U.shown = {}
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

local function Danger(k)
	return S.anchor + k * PERIOD - S.rtt
end

local Refresh

local function Tick(at, sample)
	local now = GetTime()
	if not sample then
		if S.lastReal and at - S.lastReal <= KEEP * PERIOD + SLACK then
			table.insert(S.gaps, 1, at - S.lastReal)
			S.gaps[GAPS_KEPT + 1] = nil
		end
		S.lastReal, S.held, S.seen = at, nil, S.seen + 1
		S.live, S.sample, S.sampleUntil, S.preview = true, false, nil, false
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
		local record = not S.sample and S.streak > S.best and S.streak >= RECORD_FROM
		if not S.sample then
			S.dodged = S.dodged + 1
			S.best = math.max(S.best, S.streak)
		end
		if S.streak <= DODGE_MAX then
			S.lastAlive = now
		end
		if record then
			Say(("Best x%d"):format(S.streak), GOLD, now)
			Flash(GOLD, 0.5, now)
		else
			Say(S.streak > 1 and ("Dodged x%d"):format(S.streak) or "Dodged", GREEN, now)
			Flash(GREEN, 0.3, now)
		end
	elseif not S.sample then
		S.unseen = S.unseen + 1
	end
end

local function SampleSound()
	if Testing() then
		return type(ns.TestMode.Sound) == "function" and ns.TestMode.Sound("lava") == true
	end
	local first = S.testSound == true
	S.testSound = false
	return first
end

local function Cue(now)
	if ns.Get("general.lavaFlash") == true then
		Flash(U.jumpRGB, 0.6, now)
	end
	local sound = ns.SOUNDS and ns.SOUNDS[KITS[ns.Get("general.lavaSound")] or 0]
	if type(sound) == "table" and type(PlaySound) == "function" and (not S.sample or SampleSound()) then
		pcall(PlaySound, sound[1], SOUND_CHANNEL)
	end
end

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

local function FrameAlpha(alpha)
	if U.alpha ~= alpha then
		U.alpha = alpha
		U.frame:SetAlpha(alpha)
	end
end

local Run

local function Step(_, elapsed)
	local now = GetTime()
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
		S.anchor = S.anchor + (Finite(elapsed) and elapsed or 0)
	end
	if S.live and now - S.lastAlive > HIDE then
		S.live = false
		Refresh(true)
		return
	elseif S.sample and not Sampling(now) then
		S.sample, S.preview = false, false
		Refresh(true)
		return
	end
	if S.preview and not (S.sampleUntil ~= nil and now < S.sampleUntil) then
		S.preview = false
		Run(true)
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

function Run(on, fade)
	if on then
		local frame = Build()
		local strata = (S.preview and not S.live) and "DIALOG" or "LOW"
		if U.strata ~= strata then
			U.strata = strata
			frame:SetFrameStrata(strata)
		end
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

function Refresh(fade)
	local now = GetTime()
	if S.broken or Mode() == nil then
		S.live, S.sample, S.preview = false, false, false
		Run(false)
	elseif S.live then
		S.sample, S.preview = false, false
		Run(true)
	elseif Sampling(now) then
		if not S.sample then
			StartSample(now)
		end
		Run(true)
	else
		S.sample, S.preview = false, false
		Run(false, fade)
	end
end

local function Trace(action, flag, school, verdict, why, now)
	local yes = { [true] = "yes", [false] = "no" }
	print(("Flat UI lava: %.2f %s, flag %s, school %s; in combat %s, swimming %s, falling %s, lava place %s: %s (%s)."):format(now, Plain(action),
		Plain(flag), Plain(school), S.fighting == nil and "-" or yes[S.fighting], S.swimming == nil and "-" or yes[S.swimming],
		yes[Yes(IsFalling, "player")], yes[S.lava == true], verdict or "ignored", why))
end

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
		S.live, S.sampleUntil, S.lastReal, S.held, S.preview = false, nil, nil, nil, false
	end
	Refresh()
end

function ns.LavaChanged(path)
	local ok, err = pcall(Apply)
	if not ok then
		Stop(err)
		return
	end
	if type(path) ~= "string" or S.broken or S.live or Mode() == nil or InCombatLockdown()
		or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	ok, err = pcall(function()
		S.sampleUntil, S.preview = math.max(S.sampleUntil or 0, GetTime() + PREVIEW), true
		Refresh()
	end)
	if not ok then
		Stop(err)
	end
end

function ns.LavaSoundPicked(path)
	ns.LavaChanged(path)
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

function ns.LavaTimerWidth()
	return Number("lavaWidth", BOX_W, 80, 400)
end

function ns.LavaTimerHeight()
	return Number("lavaHeight", BOX_H, 8, 30)
end

function ns.LavaTimerShown()
	return not S.broken and Mode() ~= nil
end

function ns.LavaTimerMoved()
	U.placed = nil
	if U.frame and not S.broken then
		local ok, err = pcall(Place)
		if not ok then
			Stop(err)
		end
	end
end

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

function ns.LavaCommand(rest)
	local word = (rest or ""):lower():match("^%s*(%S*)") or ""
	if word == "test" then
		if S.broken or Mode() == nil then
			print("Lava tick timer: choose In lava zones or Anywhere first, on Helpers > World and cursor.")
			return
		end
		S.sampleUntil, S.testSound, S.preview = GetTime() + TEST_TIME, true, false
		ns.LavaChanged()
	elseif word == "trace" then
		S.trace = not S.trace
		print(("Lava tick timer: trace %s.%s"):format(S.trace and "on" or "off",
			S.trace and Mode() == nil and " The row is Off, so no hit is heard." or ""))
	else
		Report()
	end
end

if type(ns.TestMode) == "table" and type(ns.TestMode.Watch) == "function" then
	ns.TestMode.Watch(function()
		ns.LavaChanged()
	end)
end
