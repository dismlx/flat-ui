local _, ns = ...

-- Cast time: the seconds left of a cast, at the right end of the target bar, the focus bar and the cast bar of each nameplate (Cast time on target
-- and focus bars, and Cast time on the Cast bar tab of Nameplates), and of the player's two bars and the pet's (Cast time on your bars, off by default, which also hides
-- the game's own time of Edit Mode's Show Cast Time, its CastTimeText, with SetAlpha only, put back when the row goes off; the game shows and hides
-- that text with SetShown, Shared/CastingBarFrame.lua:840-850). One font string of the addon's own sits inside each bar, at RIGHT -4; a nameplate
-- bar has a second one just past its right end (LEFT of the bar's RIGHT, +2), written instead while the game shows the name of the cast's target
-- there (its CastTargetNameText shown and UnitShouldDisplaySpellTargetName true, UnitDocumentation.lua:3116-3130, a plain answer;
-- Blizzard_NamePlateCastingBar.lua:87-88 anchors that name RIGHT, -4 on the bar), so the two never overlap; both are made out of combat. At each
-- start the font strings take the face, size and flags of the bar's own spell name (GetFont of its Text, then SetFont): on a nameplate the size,
-- outline and face PlateText.lua gave it (Spell name size and outline, Text font), on the other bars the size and outline of CastBarSize.lua.
-- A frame of the addon's own looks at the bars every 0.1 s, only while a row is on, and watches the plain fields the
-- game keeps on a cast bar: casting and channeling (Shared\CastingBarFrame.lua:231-232, 412-417). When a cast starts it asks for the duration object
-- of the unit, UnitCastingDuration or UnitChannelDuration (UnitDocumentation.lua:811, 854), and writes the time in one of two ways, each in a pcall.
-- First as the game does it for aura timers: a duration text binding with a seconds formatter on the font string (Blizzard_CustomAuraButton.lua:178-213,
-- 609-613; DurationUtilDocumentation.lua:21, StringUtilDocumentation.lua:31). If any of those calls raises, then by the poll: SetFormattedText of the
-- remaining duration on each look (LuaDurationObjectAPIDocumentation.lua:271, SimpleFontStringAPIDocumentation.lua:539-548, which accepts a withheld text).
-- The client may refuse both for units other than the player and the pet. When both ways fail on three casts the part stops for the session, the text
-- stays empty and /flatui status says so. A row at its default makes no call. The font strings of the target, focus, player and pet bars are made
-- ahead, out of a fight, at every refresh of the cast bars while their row is on (ns.CastTimeSync), and one a fight kept from being made is made as
-- it ends (ns.OutOfCombat), so the first cast in a fight shows its seconds also on a bar the game protects then (Edit Mode's Lock to player frame);
-- /flatui status counts the casts that showed none for want of it, as after a reload in a fight.
-- Pushback on your bar (on by default, Text and icon tab of Cast bars): two more font strings of the addon's own on each of the player's two cast
-- bars, in the font of the bar's spell name and red (1, 0.3, 0.3), made ahead out of a fight as the time is: one just past the right end (LEFT of
-- the bar's RIGHT, +4) and one just past the game's own time (LEFT of its CastTimeText's RIGHT, +4; that text sits at LEFT of the bar's RIGHT, +10,
-- Mainline/CastingBarFrame.xml:319-323, so the two would overlap). Each write takes the second while the game shows its time (Edit Mode's Show Cast
-- Time, CastTimeText shown, a plain answer) and Flat UI does not fade it (Cast time on your bars off), so the bar reads "1.3  +0.5"; else the first,
-- and hides the other. While the row and the page are on, a frame of the file's own hears the player's UNIT_SPELLCAST_START, _CHANNEL_START,
-- _DELAYED, _CHANNEL_UPDATE, _STOP, _CHANNEL_STOP, _INTERRUPTED and _FAILED (RegisterUnitEvent; the events the game's bar hears,
-- Shared/CastingBarFrame.lua:231-242). At a start it keeps the end of the cast (UnitCastingInfo, else UnitChannelInfo, in milliseconds: plain for
-- the player and tested with ns.Finite all the same) and its castGUID (a plain string, else none); at each delay or channel update it adds how far
-- the end moved, so a cast pushed back twice by half a second reads +1.0 and a channel cut short -0.8 (%+.1f), hidden while the total is under
-- 0.05 either way. A stop or an interrupt empties it when its castGUID is the one kept, or once the player no longer casts or channels: one of
-- another cast (a queued one, a key pressed during the cast) leaves it, as the game's bar ignores a stop whose castID is not its cast
-- (Shared/CastingBarFrame.lua:448, 530). A channel's stop empties it at once, and a failed cast once the player no longer casts or channels (a
-- second cast tried during one fails and leaves it). Only SetText, SetFont, Show and Hide reach it in a fight. /flatui status names the last
-- pushback shown.
local OWN_ROW, MINE_ROW, PLATE_ROW, PUSH_ROW = "castbars.ownTime", "castbars.playerTime", "nameplates.castTime", "castbars.pushback"
local EVERY = 0.1
local FAILED_CASTS = 3
local weak = { __mode = "k" }
-- The bars that show the time of the player's target and focus, each with the unit it follows, and the player's and the pet's own.
local OWN = { { "TargetFrameSpellBar", "target" }, { "FocusFrameSpellBar", "focus" } }
local MINE = { { "PlayerCastingBarFrame", "player" }, { "OverlayPlayerCastingBarFrame", "player" }, { "PetCastingBarFrame", "pet" } }

-- failed: casts both ways failed on. worked: a time was written once. stopped: the part is off for the session, with the reason. missed: the
-- casts that showed no time, as their bar's font string could not be made yet in a fight.
local state = { failed = 0, worked = false, stopped = false, why = nil, missed = 0 }
-- recs: per cast bar, its record: fs (the font string inside the bar), out (a nameplate bar's one past its end), write (the one the cast writes),
-- font (the font last copied from the spell name). byFrame: per nameplate unit frame, the record of its cast bar. faded: the player's and the pet's
-- bars whose own CastTimeText Flat UI faded.
local recs, byFrame, faded = setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak)
local driver, clock = nil, 0
local Tick

local function Get(path)
	return ns.Get(path)
end

local function OwnOn()
	return Get(OWN_ROW) == true and ns.Enabled("castbars")
end

local function MineOn()
	return Get(MINE_ROW) == true and ns.Enabled("castbars")
end

local function PlateRow()
	return Get(PLATE_ROW) == true and ns.Enabled("nameplates")
end

-- True for a plain true: a field the game keeps and does not withhold.
local function Flag(value)
	return not ns.IsSecret(value) and value == true
end

-- The bar -------------------------------------------------------------------------------------------------

-- The font strings of a bar, made once, outside combat when the bar may be protected: one inside its right end and, on a nameplate bar, one past
-- it. Nil while they cannot be made.
local function Text(rec)
	if rec.fs ~= nil then
		return rec.fs
	end
	local bar = rec.bar
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		-- Made as the fight ends, once however many casts asked.
		if not rec.queued then
			rec.queued = true
			ns.OutOfCombat(function()
				rec.queued = nil
				pcall(Text, rec)
			end)
		end
		return nil
	end
	local fs = ns.OwnText(bar, "OVERLAY", "GameFontHighlightSmall")
	if fs == nil then
		return nil
	end
	fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	fs:SetJustifyH("RIGHT")
	fs:SetText("")
	if rec.frame ~= nil then
		local out = ns.OwnText(bar, "OVERLAY", "GameFontHighlightSmall")
		if out ~= nil then
			out:SetPoint("LEFT", bar, "RIGHT", 2, 0)
			out:SetJustifyH("LEFT")
			out:SetText("")
			rec.out = out
		end
	end
	rec.fs = fs
	return fs
end

-- The face, size and flags of the bar's own spell name on the time, copied when they changed.
local function Restyle(rec)
	local name = rec.bar.Text
	if ns.IsSecret(name) or type(name) ~= "table" or type(name.GetFont) ~= "function" then
		return
	end
	local ok, file, size, flags = pcall(name.GetFont, name)
	if not ok or ns.IsSecret(file) or ns.IsSecret(size) or ns.IsSecret(flags) or type(file) ~= "string" or not ns.Finite(size) or size <= 0 then
		return
	end
	flags = type(flags) == "string" and flags or ""
	local key = ("%s|%s|%s"):format(file, size, flags)
	if rec.font == key then
		return
	end
	local set = pcall(rec.fs.SetFont, rec.fs, file, size, flags)
	if rec.out ~= nil then
		set = pcall(rec.out.SetFont, rec.out, file, size, flags) and set
	end
	rec.font = set and key or nil
end

-- The font string a cast on a nameplate bar writes: the one past the bar's end while the game shows the name of the cast's target at that end.
local function Spot(rec, unit)
	if rec.out == nil then
		return rec.fs
	end
	local name = rec.bar.CastTargetNameText
	if ns.IsSecret(name) or type(name) ~= "table" or ns.Forbidden(name) then
		return rec.fs
	end
	local ok, shown = pcall(name.IsShown, name)
	if not ok or ns.IsSecret(shown) or shown ~= true then
		return rec.fs
	end
	local asked, named = pcall(UnitShouldDisplaySpellTargetName, unit)
	if asked and not ns.IsSecret(named) and named == true then
		return rec.out
	end
	return rec.fs
end

-- The first way: the game's own duration text binding on the font string.
local function Bind(rec, fs, duration)
	local binding = rec.binding
	if binding == nil then
		binding = C_DurationUtil.CreateDurationTextBinding()
		binding:SetFormatter(C_StringUtil.CreateSecondsFormatter())
		rec.binding = binding
	end
	if rec.bound ~= fs then
		binding:SetFontString(fs)
		rec.bound = fs
	end
	binding:SetDuration(duration)
	binding:SetEnabled(true)
end

-- The second way: the remaining seconds, written on each look.
local function Write(rec)
	rec.write:SetFormattedText("%.1f", rec.duration:GetRemainingDuration())
end

-- Empties the font strings and lets go of the cast.
local function Finish(rec)
	if rec.mode == "binding" and rec.binding ~= nil then
		pcall(rec.binding.SetEnabled, rec.binding, false)
	end
	if rec.fs ~= nil then
		pcall(rec.fs.SetText, rec.fs, "")
	end
	if rec.out ~= nil then
		pcall(rec.out.SetText, rec.out, "")
	end
	rec.active, rec.mode, rec.duration, rec.id, rec.chan = false, nil, nil, nil, nil
end

local function StopAll()
	for _, rec in pairs(recs) do
		pcall(Finish, rec)
	end
end

-- A cast both ways failed on. The third one stops the part.
local function Fail(why)
	state.failed = state.failed + 1
	state.why = tostring(why)
	if state.failed >= FAILED_CASTS and not state.stopped then
		state.stopped = true
		StopAll()
		print("Flat UI: Cast time stopped. /flatui status shows why.")
	end
end

-- A cast has started on a bar: its duration, then the first way, then the second.
local function Start(rec, casting, id, unit)
	local fs = Text(rec)
	if fs == nil then
		-- Counted once a cast, by its ID.
		local key = id or true
		if rec.missed ~= key then
			rec.missed, state.missed = key, state.missed + 1
		end
		return
	end
	local ok, duration = pcall(casting and UnitCastingDuration or UnitChannelDuration, unit)
	if not ok then
		rec.gaveUp = { chan = not casting, id = id }
		Fail(duration)
		return
	end
	if not duration then
		return
	end
	pcall(Restyle, rec)
	local spotted, spot = pcall(Spot, rec, unit)
	fs = spotted and spot or rec.fs
	local other = fs == rec.fs and rec.out or rec.fs
	if other ~= nil then
		pcall(other.SetText, other, "")
	end
	rec.duration, rec.id, rec.chan, rec.write = duration, id, not casting, fs
	local bound, err = pcall(Bind, rec, fs, duration)
	if bound then
		rec.mode, rec.active = "binding", true
		state.worked = true
		return
	end
	local wrote, err2 = pcall(Write, rec)
	if wrote then
		rec.mode, rec.active = "poll", true
		state.worked = true
		return
	end
	rec.duration = nil
	rec.gaveUp = { chan = not casting, id = id }
	Fail(err2 or err)
end

-- The unit of a nameplate unit frame, or nil.
local function PlateUnit(frame)
	local unit = frame.unit
	if type(unit) == "string" and not ns.IsSecret(unit) then
		return unit
	end
	return nil
end

-- False for a friendly plate while Restyle friendly nameplates is off, as for the rest of the plate's look.
local function Styled(frame)
	local friend = frame.isFriend
	return Get("nameplates.friendly") == true or ns.IsSecret(friend) or friend ~= true
end

-- One look at one bar.
local function Look(rec, wanted, unit)
	local bar = rec.bar
	local casting, channeling = Flag(bar.casting), Flag(bar.channeling)
	if not (wanted and unit ~= nil and (casting or channeling)) or state.stopped then
		if rec.active then
			Finish(rec)
		end
		rec.gaveUp, rec.missed = nil, nil
		return
	end
	local id = bar.castID
	if ns.IsSecret(id) then
		id = nil
	end
	if rec.active and (rec.chan ~= not casting or (id ~= nil and rec.id ~= nil and id ~= rec.id)) then
		Finish(rec)
	end
	-- A cast both ways failed on is not tried again; the next one is.
	if rec.gaveUp ~= nil and (rec.gaveUp.chan ~= not casting or (id ~= nil and rec.gaveUp.id ~= id)) then
		rec.gaveUp = nil
	end
	if rec.gaveUp ~= nil then
		return
	end
	if not rec.active then
		Start(rec, casting, id, unit)
	elseif rec.mode == "poll" then
		local ok, err = pcall(Write, rec)
		if not ok then
			Finish(rec)
			rec.gaveUp = { chan = not casting, id = id }
			Fail(err)
		end
	end
end

local function Record(bar, frame)
	local rec = recs[bar]
	if rec == nil then
		rec = { bar = bar }
		recs[bar] = rec
	end
	rec.frame = frame
	if frame ~= nil then
		byFrame[frame] = rec
	end
	return rec
end

local function PlateBar(frame)
	local container = frame.CastBarsContainer
	local bar = container ~= nil and not ns.IsSecret(container) and not ns.Forbidden(container) and container.castBar or nil
	if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

local function LookPlate(frame, wanted)
	local bar = PlateBar(frame)
	if bar ~= nil and (wanted or recs[bar] ~= nil) then
		Look(Record(bar, frame), wanted and Styled(frame), wanted and PlateUnit(frame) or nil)
	end
end

-- One look at each bar of a list whose row is `on`, and at those of a list whose row went off while they showed a time.
local function LookList(list, on)
	for _, entry in ipairs(list) do
		local bar = _G[entry[1]]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) and (on or recs[bar] ~= nil) then
			Look(Record(bar, nil), on, entry[2])
		end
	end
end

local function Step()
	LookList(OWN, OwnOn())
	LookList(MINE, MineOn())
	ns.EachPlate(LookPlate, PlateRow())
end

-- The game's own time on the player's and the pet's bars (Edit Mode's Show Cast Time) is faded while Cast time on your bars is on, and given back
-- its alpha when the row goes off.
local function Fades()
	local on = MineOn()
	for _, entry in ipairs(MINE) do
		local bar = _G[entry[1]]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
			local game = bar.CastTimeText
			if on then
				ns.SetFaded(game, true)
				faded[bar] = true
			elseif faded[bar] then
				ns.SetFaded(game, false)
				faded[bar] = nil
			end
		end
	end
end

local function Wanted()
	if state.stopped then
		return false
	end
	if OwnOn() or MineOn() or PlateRow() then
		return true
	end
	for _, rec in pairs(recs) do
		if rec.active then
			return true
		end
	end
	return false
end

local function Sync()
	if Wanted() then
		if driver == nil then
			driver = CreateFrame("Frame")
			ns.Own[driver] = true
			driver:SetScript("OnUpdate", Tick)
		end
		driver:Show()
	elseif driver ~= nil then
		driver:Hide()
	end
end

function Tick(_, elapsed)
	clock = clock + elapsed
	if clock < EVERY then
		return
	end
	clock = 0
	pcall(Step)
	Sync()
end

-- Pushback ------------------------------------------------------------------------------------------------

-- The player's two bars, the colour of the text, the least total shown, and what each event of the player's cast does.
local PUSH_BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
local PUSH_COLOUR, PUSH_LEAST = { 1, 0.3, 0.3 }, 0.05
local PUSH_EVENTS = { UNIT_SPELLCAST_START = "start", UNIT_SPELLCAST_CHANNEL_START = "start", UNIT_SPELLCAST_DELAYED = "move",
	UNIT_SPELLCAST_CHANNEL_UPDATE = "move", UNIT_SPELLCAST_STOP = "ended", UNIT_SPELLCAST_CHANNEL_STOP = "stop",
	UNIT_SPELLCAST_INTERRUPTED = "ended", UNIT_SPELLCAST_FAILED = "failed" }
-- texts: per bar, its two font strings (near and after). queued: per bar, a make waits for the end of the fight. P: frame (the file's own, false
-- when it could not be made), on (the events are heard), lastEnd and chan (the end in milliseconds of the cast now and whether it is a channel),
-- guid (the castGUID of its start, a plain string, else nil), total (the seconds it moved), last (the last total shown, for /flatui status).
local pushTexts, pushQueued = setmetatable({}, weak), setmetatable({}, weak)
local P = { frame = nil, on = false, lastEnd = nil, chan = nil, guid = nil, total = 0, last = nil }

local function PushOn()
	return Get(PUSH_ROW) == true and ns.Enabled("castbars")
end

local function PlayerBar(name)
	local bar = _G[name]
	if bar == nil or ns.IsSecret(bar) or ns.Forbidden(bar) then
		return nil
	end
	return bar
end

-- The two font strings of a bar, made once out of a fight on a bar the game may protect; a fight that keeps them from being made makes them as it
-- ends. near: just past the bar's right end. after: just past the game's own time (its CastTimeText), nil on a bar without that text.
local function PushText(bar)
	local entry = pushTexts[bar]
	if entry ~= nil then
		return entry or nil
	end
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		if not pushQueued[bar] then
			pushQueued[bar] = true
			ns.OutOfCombat(function()
				pushQueued[bar] = nil
				pcall(PushText, bar)
			end)
		end
		return nil
	end
	local function Make(anchor, x)
		local fs = ns.OwnText(bar, "OVERLAY", "GameFontHighlightSmall")
		if fs == nil then
			return nil
		end
		if not pcall(fs.SetPoint, fs, "LEFT", anchor, "RIGHT", x, 0) then
			pcall(fs.Hide, fs)
			return nil
		end
		fs:SetJustifyH("LEFT")
		fs:SetTextColor(PUSH_COLOUR[1], PUSH_COLOUR[2], PUSH_COLOUR[3])
		fs:SetText("")
		fs:Hide()
		return fs
	end
	local near = Make(bar, 4)
	if near == nil then
		pushTexts[bar] = false
		return nil
	end
	entry = { near = near }
	local game = bar.CastTimeText
	if not ns.IsSecret(game) and type(game) == "table" and not ns.Forbidden(game) then
		entry.after = Make(game, 4)
	end
	pushTexts[bar] = entry
	return entry
end

-- The face, size and flags of the bar's spell name on its pushback texts.
local function PushFont(bar, entry)
	local name = bar.Text
	if ns.IsSecret(name) or type(name) ~= "table" or type(name.GetFont) ~= "function" then
		return
	end
	local ok, file, size, flags = pcall(name.GetFont, name)
	if ok and not (ns.IsSecret(file) or ns.IsSecret(size) or ns.IsSecret(flags)) and type(file) == "string" and ns.Finite(size) and size > 0 then
		flags = type(flags) == "string" and flags or ""
		pcall(entry.near.SetFont, entry.near, file, size, flags)
		if entry.after ~= nil then
			pcall(entry.after.SetFont, entry.after, file, size, flags)
		end
	end
end

-- The font string a write uses: the one past the game's own time while the game shows it and Flat UI does not fade it (Cast time on your bars
-- off), else the one past the bar's end.
local function PushSpot(bar, entry)
	local after = entry.after
	if after == nil or faded[bar] then
		return entry.near, after
	end
	local game = bar.CastTimeText
	if ns.IsSecret(game) or type(game) ~= "table" or ns.Forbidden(game) then
		return entry.near, after
	end
	local ok, shown = pcall(game.IsShown, game)
	if ok and not ns.IsSecret(shown) and shown == true then
		return after, entry.near
	end
	return entry.near, after
end

-- The end of the player's cast or channel now, in milliseconds, and true for a channel; nil while there is none or it is withheld.
local function CastEnd()
	local ok, name, _, _, _, endMs = pcall(UnitCastingInfo, "player")
	if ok and not ns.IsSecret(name) and type(name) == "string" then
		return ns.Finite(endMs) and endMs or nil, false
	end
	ok, name, _, _, _, endMs = pcall(UnitChannelInfo, "player")
	if ok and not ns.IsSecret(name) and type(name) == "string" then
		return ns.Finite(endMs) and endMs or nil, true
	end
	return nil
end

-- Writes the total on both bars, or hides it while it is under PUSH_LEAST either way. restyle: a new cast, whose font is copied first.
local function PushShow(restyle)
	local shown = math.abs(P.total) >= PUSH_LEAST
	for _, name in ipairs(PUSH_BARS) do
		local bar = PlayerBar(name)
		local entry = bar and PushText(bar)
		if entry then
			if restyle then
				PushFont(bar, entry)
			end
			local fs, other = PushSpot(bar, entry)
			if other ~= nil then
				other:Hide()
			end
			if shown then
				fs:SetFormattedText("%+.1f", P.total)
			end
			fs:SetShown(shown)
		end
	end
	if shown then
		P.last = P.total
	end
end

local function PushClear()
	P.lastEnd, P.chan, P.guid, P.total = nil, nil, nil, 0
	for _, entry in pairs(pushTexts) do
		if entry then
			pcall(entry.near.Hide, entry.near)
			if entry.after ~= nil then
				pcall(entry.after.Hide, entry.after)
			end
		end
	end
end

-- A castGUID that is a plain string, else nil.
local function PlainGuid(guid)
	if ns.IsSecret(guid) or type(guid) ~= "string" then
		return nil
	end
	return guid
end

local function PushHeard(what, guid)
	if what == "start" then
		P.lastEnd, P.chan = CastEnd()
		P.guid = PlainGuid(guid)
		P.total = 0
		PushShow(true)
	elseif what == "move" then
		local endMs, chan = CastEnd()
		if endMs and P.lastEnd and chan == P.chan then
			P.total = P.total + (endMs - P.lastEnd) / 1000
			PushShow(false)
		end
		if endMs then
			P.lastEnd, P.chan = endMs, chan
		end
	elseif what == "ended" then
		-- A stop or an interrupt of another cast (a queued one, a key pressed during the cast) leaves the total of this one, as the game's bar
		-- leaves its cast; one of this cast, or any once the player casts nothing, clears it.
		local plain = PlainGuid(guid)
		if (plain ~= nil and plain == P.guid) or CastEnd() == nil then
			PushClear()
		end
	elseif what == "stop" or CastEnd() == nil then
		-- A channel's stop clears at once. A failed cast clears only once the player casts nothing: a second cast tried during one fails and
		-- leaves it.
		PushClear()
	end
end

local function PushEvent(_, event, unit, guid)
	local what = PUSH_EVENTS[event]
	if what and not ns.IsSecret(unit) and unit == "player" and P.on then
		if not pcall(PushHeard, what, guid) then
			pcall(PushClear)
		end
	end
end

-- The events are heard only while the row and the page are on; off empties the text.
local function PushListen(on)
	if on == P.on then
		return
	end
	if P.frame == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		P.frame = ok and not ns.IsSecret(frame) and type(frame) == "table" and frame or false
		if P.frame then
			ns.Own[frame] = true
			frame:SetScript("OnEvent", PushEvent)
		end
	end
	local frame = P.frame
	if not frame then
		return
	end
	P.on = on
	for event in pairs(PUSH_EVENTS) do
		if not on then
			pcall(frame.UnregisterEvent, frame, event)
		elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, event, "player")) then
			pcall(frame.RegisterEvent, frame, event)
		end
	end
	if not on then
		PushClear()
	end
end

-- Hooks ---------------------------------------------------------------------------------------------------

local extra = ns.PlateExtra
extra.show[#extra.show + 1] = function(frame)
	if PlateRow() then
		local bar = PlateBar(frame)
		if bar ~= nil then
			Text(Record(bar, frame))
		end
		Sync()
	end
end
extra.leave[#extra.leave + 1] = function(frame)
	local rec = byFrame[frame]
	if rec ~= nil and rec.active then
		Finish(rec)
	end
end
extra.refresh[#extra.refresh + 1] = Sync

-- The font strings of the bars whose row is on, made ahead out of a fight so that a cast in one shows its time and its pushback.
local function MakeAhead()
	local own, mine = OwnOn(), MineOn()
	for _, list in ipairs({ own and OWN, mine and MINE }) do
		for _, entry in ipairs(list or {}) do
			local bar = PlayerBar(entry[1])
			if bar then
				Text(Record(bar, nil))
			end
		end
	end
	if PushOn() then
		for _, name in ipairs(PUSH_BARS) do
			local bar = PlayerBar(name)
			if bar then
				PushText(bar)
			end
		end
	end
end

-- Called by Bars.lua at the end of a refresh of the cast bars: the frame starts or stops with the rows, the game's own time on the player's and
-- the pet's bars is faded or given back, the font strings are made ahead out of a fight, and the pushback events start or stop with their row.
function ns.CastTimeSync()
	pcall(Fades)
	if not InCombatLockdown() and not state.stopped then
		pcall(MakeAhead)
	end
	pcall(PushListen, PushOn())
	Sync()
end

local function StatusLine()
	if state.stopped then
		return "Cast time: refused. " .. tostring(state.why)
	end
	if not (OwnOn() or MineOn() or PlateRow()) then
		return nil
	end
	local line = state.worked and "Cast time: works" or "Cast time: no cast seen yet"
	if state.missed > 0 then
		line = line .. (". Casts that showed no time, as their bar's text is made out of a fight and none was yet: %d"):format(state.missed)
	end
	return line
end

local base = ns.StatusLines
function ns.StatusLines()
	local lines = base()
	local line = StatusLine()
	if line ~= nil then
		lines[#lines + 1] = line
	end
	if PushOn() then
		lines[#lines + 1] = P.last and ("Pushback on your bar: the last shown was %+.1f."):format(P.last) or "Pushback on your bar: no pushback seen yet."
	end
	return lines
end
