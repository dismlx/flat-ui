local _, ns = ...

-- Cast time: the seconds left of a cast, at the right end of the target bar, the focus bar and the cast bar of each nameplate. One font string of the
-- addon's own sits inside each bar. A frame of the addon's own looks at the bars every 0.1 s, only while a row is on, and watches the plain fields the
-- game keeps on a cast bar: casting and channeling (Shared\CastingBarFrame.lua:231-232, 412-417). When a cast starts it asks for the duration object
-- of the unit, UnitCastingDuration or UnitChannelDuration (UnitDocumentation.lua:811, 854), and writes the time in one of two ways, each in a pcall.
-- First as the game does it for aura timers: a duration text binding with a seconds formatter on the font string (Blizzard_CustomAuraButton.lua:178-213,
-- 609-613; DurationUtilDocumentation.lua:21, StringUtilDocumentation.lua:31). If any of those calls raises, then by the poll: SetFormattedText of the
-- remaining duration on each look (LuaDurationObjectAPIDocumentation.lua:271, SimpleFontStringAPIDocumentation.lua:539-548, which accepts a withheld text).
-- The client may refuse both for units other than the player and the pet. When both ways fail on three casts the part stops for the session, the text
-- stays empty and /flatui status says so. A row at its default makes no call.

local OWN_ROW, PLATE_ROW = "castbars.ownTime", "nameplates.castTime"
local EVERY = 0.1
local FAILED_CASTS = 3
local weak = { __mode = "k" }
-- The bars that show the time of the player's target and focus, each with the unit it follows.
local OWN = { { "TargetFrameSpellBar", "target" }, { "FocusFrameSpellBar", "focus" } }

-- failed: casts both ways failed on. worked: a time was written once. stopped: the part is off for the session, with the reason.
local state = { failed = 0, worked = false, stopped = false, why = nil }
-- recs: per cast bar, its record. byFrame: per nameplate unit frame, the record of its cast bar.
local recs, byFrame = setmetatable({}, weak), setmetatable({}, weak)
local driver, clock = nil, 0
local Tick

local function Get(path)
	return ns.Get(path)
end

local function OwnOn()
	return Get(OWN_ROW) == true and ns.Enabled("castbars")
end

local function PlateRow()
	return Get(PLATE_ROW) == true and ns.Enabled("nameplates")
end

-- True for a plain true: a field the game keeps and does not withhold.
local function Flag(value)
	return not ns.IsSecret(value) and value == true
end

-- The bar -------------------------------------------------------------------------------------------------

-- The font string of a bar, made once, outside combat when the bar may be protected. Nil while it cannot be made.
local function Text(rec)
	if rec.fs ~= nil then
		return rec.fs
	end
	local bar = rec.bar
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		return nil
	end
	local fs = ns.OwnText(bar, "OVERLAY", "GameFontHighlightSmall")
	if fs == nil then
		return nil
	end
	fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	fs:SetJustifyH("RIGHT")
	fs:SetText("")
	rec.fs = fs
	return fs
end

-- The first way: the game's own duration text binding on the font string.
local function Bind(rec, fs, duration)
	local binding = rec.binding
	if binding == nil then
		binding = C_DurationUtil.CreateDurationTextBinding()
		binding:SetFontString(fs)
		binding:SetFormatter(C_StringUtil.CreateSecondsFormatter())
		rec.binding = binding
	end
	binding:SetDuration(duration)
	binding:SetEnabled(true)
end

-- The second way: the remaining seconds, written on each look.
local function Write(rec)
	rec.fs:SetFormattedText("%.1f", rec.duration:GetRemainingDuration())
end

-- Empties the font string and lets go of the cast.
local function Finish(rec)
	if rec.mode == "binding" and rec.binding ~= nil then
		pcall(rec.binding.SetEnabled, rec.binding, false)
	end
	if rec.fs ~= nil then
		pcall(rec.fs.SetText, rec.fs, "")
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
	rec.duration, rec.id, rec.chan = duration, id, not casting
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
		rec.gaveUp = nil
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

local function Step()
	local own, plates = OwnOn(), PlateRow()
	for _, entry in ipairs(OWN) do
		local bar = _G[entry[1]]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) and (own or recs[bar] ~= nil) then
			Look(Record(bar, nil), own, entry[2])
		end
	end
	ns.EachPlate(LookPlate, plates)
end

local function Wanted()
	if state.stopped then
		return false
	end
	if OwnOn() or PlateRow() then
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

-- Called by Bars.lua at the end of a refresh of the cast bars: the frame starts or stops with the row.
function ns.CastTimeSync()
	Sync()
end

local function StatusLine()
	if state.stopped then
		return "Cast time: refused. " .. tostring(state.why)
	end
	if not (OwnOn() or PlateRow()) then
		return nil
	end
	return state.worked and "Cast time: works" or "Cast time: no cast seen yet"
end

local base = ns.StatusLines
function ns.StatusLines()
	local lines = base()
	local line = StatusLine()
	if line ~= nil then
		lines[#lines + 1] = line
	end
	return lines
end
