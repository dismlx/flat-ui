local _, ns = ...

local OWN_ROW, MINE_ROW, PLATE_ROW, PUSH_ROW = "castbars.ownTime", "castbars.playerTime", "nameplates.castTime", "castbars.pushback"
local TOTAL_ROW, AIM_ROW = "castbars.timeTotal", "castbars.castTarget"
local EVERY = 0.1
local FAILED_CASTS = 3
local weak = { __mode = "k" }
local OWN = { { "TargetFrameSpellBar", "target" }, { "FocusFrameSpellBar", "focus" } }
local MINE = { { "PlayerCastingBarFrame", "player" }, { "OverlayPlayerCastingBarFrame", "player" }, { "PetCastingBarFrame", "pet" } }

local state = { failed = 0, worked = false, stopped = false, why = nil, missed = 0, noTotal = false, aimed = 0, aimClass = 0 }
local recs, byFrame, faded = setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak)
local aims, aimQueued = setmetatable({}, weak), setmetatable({}, weak)
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

local function AimOn()
	return Get(AIM_ROW) == true and ns.Enabled("castbars")
end

local function Flag(value)
	return not ns.IsSecret(value) and value == true
end

local function Text(rec)
	if rec.fs ~= nil then
		return rec.fs
	end
	local bar = rec.bar
	if InCombatLockdown() and ns.MaybeProtected(bar) then
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

local function WriteTotal(rec)
	local duration = rec.duration
	rec.write:SetFormattedText("%.1f / %.1f", duration:GetRemainingDuration(), duration:GetTotalDuration())
end

local function Write(rec)
	if rec.total then
		if pcall(WriteTotal, rec) then
			return
		end
		rec.total, state.noTotal = false, true
	end
	rec.write:SetFormattedText("%.1f", rec.duration:GetRemainingDuration())
end

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

local function Fail(why)
	state.failed = state.failed + 1
	state.why = tostring(why)
	if state.failed >= FAILED_CASTS and not state.stopped then
		state.stopped = true
		StopAll()
		print("Flat UI: Cast time stopped. /flatui status shows why.")
	end
end

local function Start(rec, casting, id, unit)
	local fs = Text(rec)
	if fs == nil then
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
	rec.total = rec.frame == nil and Get(TOTAL_ROW) == true
	local bound, err = false, nil
	if not rec.total then
		bound, err = pcall(Bind, rec, fs, duration)
	end
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

local function PlateUnit(frame)
	local unit = frame.unit
	if type(unit) == "string" and not ns.IsSecret(unit) then
		return unit
	end
	return nil
end

local function Styled(frame)
	local friend = frame.isFriend
	return Get("nameplates.friendly") == true or ns.IsSecret(friend) or friend ~= true
end

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

local function LookList(list, on)
	for _, entry in ipairs(list) do
		local bar = _G[entry[1]]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) and (on or recs[bar] ~= nil) then
			Look(Record(bar, nil), on, entry[2])
		end
	end
end

local function AimPlace(bar, aim)
	local icon = bar.Icon
	local right = ns.Enabled("castbars") and Get("castbars.iconPos") == "right" and not ns.Forbidden(icon)
	local place = right and "icon" or "bar"
	if aim.place == place then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		if not aim.queued then
			aim.queued = true
			ns.OutOfCombat(function()
				aim.queued = nil
				pcall(AimPlace, bar, aim)
			end)
		end
		return
	end
	local fs = aim.fs
	fs:ClearAllPoints()
	if not (right and pcall(fs.SetPoint, fs, "LEFT", icon, "RIGHT", 4, 0)) then
		fs:SetPoint("LEFT", bar, "RIGHT", 4, 0)
		place = "bar"
	end
	aim.place = place
end

local function MakeAim(bar)
	local aim = aims[bar]
	if aim ~= nil then
		return aim or nil
	end
	if InCombatLockdown() and ns.MaybeProtected(bar) then
		if not aimQueued[bar] then
			aimQueued[bar] = true
			ns.OutOfCombat(function()
				aimQueued[bar] = nil
				pcall(MakeAim, bar)
			end)
		end
		return nil
	end
	local fs = ns.OwnText(bar, "OVERLAY", "GameFontHighlightSmall")
	if fs == nil then
		aims[bar] = false
		return nil
	end
	fs:SetJustifyH("LEFT")
	fs:SetText("")
	fs:Hide()
	aim = { fs = fs, shown = false }
	aims[bar] = aim
	AimPlace(bar, aim)
	return aim
end

local function AimFont(bar, aim)
	local name = bar.Text
	if ns.IsSecret(name) or type(name) ~= "table" or type(name.GetFont) ~= "function" then
		return
	end
	local ok, file, size, flags = pcall(name.GetFont, name)
	if not ok or ns.IsSecret(file) or ns.IsSecret(size) or ns.IsSecret(flags) or type(file) ~= "string" or not ns.Finite(size) or size <= 0 then
		return
	end
	flags = type(flags) == "string" and flags or ""
	local key = ("%s|%s|%s"):format(file, size, flags)
	if aim.font ~= key and pcall(aim.fs.SetFont, aim.fs, file, size, flags) then
		aim.font = key
	end
end

local function AimHide(aim)
	if aim and aim.shown then
		pcall(aim.fs.SetText, aim.fs, "")
		pcall(aim.fs.Hide, aim.fs)
		aim.shown = false
	end
end

local function AimWrite(fs, unit)
	fs:SetFormattedText("> %s", UnitSpellTargetName(unit))
end

local function AimColour(fs, unit)
	local colour = C_ClassColor.GetClassColor(UnitSpellTargetClass(unit))
	fs:SetTextColor(colour.r, colour.g, colour.b)
end

local function Hostile(unit)
	local ok, hostile = pcall(UnitCanAttack, "player", unit)
	return ok and not ns.IsSecret(hostile) and hostile == true
end

local function AimLook(bar, unit, on)
	local aim = aims[bar]
	local casts = Flag(bar.casting) or Flag(bar.channeling)
	if not casts and aim and aim.shown and on and Hostile(unit) then
		local ok, shown = pcall(bar.IsShown, bar)
		if ok and Flag(shown) then
			return
		end
	end
	if not (on and casts and Hostile(unit)) then
		AimHide(aim)
		return
	end
	aim = aim or MakeAim(bar)
	if not aim then
		return
	end
	local asked, named = pcall(UnitShouldDisplaySpellTargetName, unit)
	if not (asked and not ns.IsSecret(named) and named == true) then
		AimHide(aim)
		return
	end
	if not aim.shown then
		AimFont(bar, aim)
	end
	if not pcall(AimWrite, aim.fs, unit) then
		AimHide(aim)
		return
	end
	local classed = pcall(AimColour, aim.fs, unit)
	if not classed then
		pcall(aim.fs.SetTextColor, aim.fs, 1, 1, 1)
	end
	if not aim.shown then
		aim.fs:Show()
		aim.shown = true
		state.aimed = state.aimed + 1
		if classed then
			state.aimClass = state.aimClass + 1
		end
	end
end

local function LookAims(on)
	for _, entry in ipairs(OWN) do
		local bar = _G[entry[1]]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) and (on or aims[bar]) then
			AimLook(bar, entry[2], on)
		end
	end
end

local KT = { shown = 0, live = 0, refused = false }
local KickTimeOn, LookKicks, KickAhead
do
	local KICK_TIME_ROW, KICK_COLOUR_ROW = "castbars.kickTime", "castbars.interruptCooling"
	local kicks, kickQueued = setmetatable({}, weak), setmetatable({}, weak)

	function ns.KickTimeColour()
		if ns.Enabled("castbars") and Get("castbars.flat") == true then
			if Get("castbars.textOwn") == true then
				local r, g, b = ns.Colour("castbars.textColour")
				if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
					return r, g, b, "own" .. tostring(Get("castbars.textColour"))
				end
			end
			return 1, 1, 1, "flat"
		end
		local r, g, b = ns.Colour(KICK_COLOUR_ROW)
		if not (ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
			r, g, b = 0.85, 0.45, 0.18
		end
		return r, g, b, "cooling" .. tostring(Get(KICK_COLOUR_ROW))
	end

	function KickTimeOn()
		return Get(KICK_TIME_ROW) == true and Get("castbars.interrupt") == true and ns.Enabled("castbars")
	end

	local function MakeKick(bar)
		local kick = kicks[bar]
		if kick ~= nil then
			return kick or nil
		end
		if InCombatLockdown() and ns.MaybeProtected(bar) then
			if not kickQueued[bar] then
				kickQueued[bar] = true
				ns.OutOfCombat(function()
					kickQueued[bar] = nil
					pcall(MakeKick, bar)
				end)
			end
			return nil
		end
		local fs = ns.OwnText(bar, "OVERLAY", "GameFontHighlightSmall")
		if fs == nil then
			kicks[bar] = false
			return nil
		end
		fs:SetPoint("LEFT", bar, "LEFT", 4, 0)
		fs:SetJustifyH("LEFT")
		fs:SetText("")
		fs:Hide()
		kick = { fs = fs, shown = false }
		kicks[bar] = kick
		return kick
	end

	local function KickHide(kick)
		if kick and kick.shown then
			if kick.mode == "binding" and kick.binding ~= nil then
				pcall(kick.binding.SetEnabled, kick.binding, false)
			end
			pcall(kick.fs.SetText, kick.fs, "")
			pcall(kick.fs.Hide, kick.fs)
			kick.shown, kick.id, kick.mode, kick.duration = false, nil, nil, nil
			KT.live = math.max(0, KT.live - 1)
		end
	end

	local function KickColour(kick)
		local r, g, b, key = ns.KickTimeColour()
		if kick.hex == key then
			return
		end
		pcall(kick.fs.SetTextColor, kick.fs, r, g, b)
		kick.hex = key
	end

	local function KickOutline(kick)
		local ok, file, size, flags = pcall(kick.fs.GetFont, kick.fs)
		if not ok or ns.IsSecret(file) or ns.IsSecret(size) or ns.IsSecret(flags) or type(file) ~= "string" or not ns.Finite(size) or size <= 0 then
			return
		end
		flags = type(flags) == "string" and flags or ""
		if not flags:upper():find("OUTLINE", 1, true) then
			pcall(kick.fs.SetFont, kick.fs, file, size, "OUTLINE")
		end
	end

	local function KickBind(kick, duration)
		local binding = kick.binding
		if binding == nil then
			binding = C_DurationUtil.CreateDurationTextBinding()
			binding:SetFormatter(C_StringUtil.CreateSecondsFormatter())
			binding:SetFontString(kick.fs)
			kick.binding = binding
		end
		binding:SetDuration(duration)
		binding:SetEnabled(true)
	end

	local function KickWrite(kick)
		kick.fs:SetFormattedText("%.0f", kick.duration:GetRemainingDuration())
	end

	local function Shielded(bar)
		local shield = bar.BorderShield
		if ns.IsSecret(shield) or type(shield) ~= "table" then
			return false
		end
		local ok, shown = pcall(shield.IsShown, shield)
		return ok and Flag(shown)
	end

	local function KickLook(bar, unit, on)
		local kick = kicks[bar]
		local duration, id = nil, nil
		if on and (Flag(bar.casting) or Flag(bar.channeling)) and type(ns.InterruptReady) == "function"
			and type(ns.InterruptCooldown) == "function" and ns.InterruptReady(unit) == false and not Shielded(bar) then
			duration, id = ns.InterruptCooldown()
		end
		if duration == nil then
			KickHide(kick)
			return
		end
		kick = kick or MakeKick(bar)
		if not kick then
			return
		end
		if not kick.shown or kick.id ~= id then
			if not kick.shown then
				AimFont(bar, kick)
				KickOutline(kick)
			end
			KickColour(kick)
			kick.id, kick.duration = id, duration
			local bound = pcall(KickBind, kick, duration)
			if not bound and kick.binding ~= nil then
				pcall(kick.binding.SetEnabled, kick.binding, false)
			end
			if bound then
				kick.mode = "binding"
			elseif pcall(KickWrite, kick) then
				kick.mode = "poll"
			else
				KT.refused = true
				KickHide(kick)
				return
			end
		elseif kick.mode == "poll" and not pcall(KickWrite, kick) then
			KT.refused = true
			KickHide(kick)
			return
		end
		if not kick.shown then
			kick.fs:Show()
			kick.shown = true
			KT.shown, KT.live = KT.shown + 1, KT.live + 1
		end
	end

	function LookKicks(on)
		for _, entry in ipairs(OWN) do
			local bar = _G[entry[1]]
			if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) and (on or kicks[bar]) then
				KickLook(bar, entry[2], on)
			end
		end
	end

	function KickAhead(make)
		for _, entry in ipairs(OWN) do
			local bar = _G[entry[1]]
			if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
				local kick = kicks[bar]
				if make and kick == nil then
					kick = MakeKick(bar)
				end
				if kick then
					pcall(KickColour, kick)
				end
			end
		end
	end
end

local WatchAgain, Watching

local function Step()
	pcall(LookAims, AimOn())
	pcall(LookKicks, KickTimeOn())
	if WatchAgain then
		pcall(WatchAgain)
	end
	LookList(OWN, OwnOn())
	LookList(MINE, MineOn())
	ns.EachPlate(LookPlate, PlateRow())
end

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
	if AimOn() or KickTimeOn() or KT.live > 0 or (Watching and Watching()) then
		return true
	end
	for _, aim in pairs(aims) do
		if aim and aim.shown then
			return true
		end
	end
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

local PUSH_BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
local PUSH_COLOUR, PUSH_LEAST, PUSH_COLOUR_ROW = { 1, 0.3, 0.3 }, 0.05, "castbars.pushbackColour"
local PUSH_POP, PUSH_POP_TIME = 1.3, 0.15
local PUSH_HOLD = 1.5
local PUSH_EVENTS = { UNIT_SPELLCAST_START = "start", UNIT_SPELLCAST_CHANNEL_START = "start", UNIT_SPELLCAST_DELAYED = "move",
	UNIT_SPELLCAST_CHANNEL_UPDATE = "move", UNIT_SPELLCAST_STOP = "ended", UNIT_SPELLCAST_CHANNEL_STOP = "stop",
	UNIT_SPELLCAST_INTERRUPTED = "ended", UNIT_SPELLCAST_FAILED = "failed" }
local pushTexts, pushQueued, pushPops = setmetatable({}, weak), setmetatable({}, weak), setmetatable({}, weak)
local P = { frame = nil, on = false, lastEnd = nil, chan = nil, guid = nil, total = 0, last = nil, hold = nil }

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

local function PushPop(fs)
	local ok, group = pcall(function()
		fs:SetScaleAnimationMode(Enum and Enum.FontStringScaleAnimationMode and Enum.FontStringScaleAnimationMode.Vertex or 1)
		local made = fs:CreateAnimationGroup()
		local scale = made:CreateAnimation("Scale")
		scale:SetScaleFrom(PUSH_POP, PUSH_POP)
		scale:SetScaleTo(1, 1)
		scale:SetDuration(PUSH_POP_TIME)
		scale:SetOrigin("LEFT", 0, 0)
		return made
	end)
	return ok and not ns.IsSecret(group) and type(group) == "table" and group or nil
end

local function PushColour(entry)
	local hex = Get(PUSH_COLOUR_ROW)
	if entry.hex == hex then
		return
	end
	local r, g, b = ns.Colour(PUSH_COLOUR_ROW)
	if not (ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = PUSH_COLOUR[1], PUSH_COLOUR[2], PUSH_COLOUR[3]
	end
	pcall(entry.near.SetTextColor, entry.near, r, g, b)
	if entry.after ~= nil then
		pcall(entry.after.SetTextColor, entry.after, r, g, b)
	end
	entry.hex = hex
end

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
		fs:SetText("")
		fs:Hide()
		pushPops[fs] = PushPop(fs) or false
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
	PushColour(entry)
	pushTexts[bar] = entry
	return entry
end

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

local function PushShow(restyle, grew)
	P.hold = nil
	local shown = math.abs(P.total) >= PUSH_LEAST
	for _, name in ipairs(PUSH_BARS) do
		local bar = PlayerBar(name)
		local entry = bar and PushText(bar)
		if entry then
			if restyle then
				PushFont(bar, entry)
				PushColour(entry)
			end
			local fs, other = PushSpot(bar, entry)
			if other ~= nil then
				other:Hide()
			end
			if shown then
				fs:SetFormattedText("%+.1f", P.total)
			end
			fs:SetShown(shown)
			local pop = pushPops[fs]
			if shown and grew and pop then
				pcall(pop.Stop, pop)
				pcall(pop.Play, pop)
			end
		end
	end
	if shown then
		P.last = P.total
	end
end

local function PushHide()
	for _, entry in pairs(pushTexts) do
		if entry then
			pcall(entry.near.Hide, entry.near)
			if entry.after ~= nil then
				pcall(entry.after.Hide, entry.after)
			end
		end
	end
end

local function PushClear()
	P.lastEnd, P.chan, P.guid, P.total, P.hold = nil, nil, nil, 0, nil
	PushHide()
end

local function PushEnd()
	P.lastEnd, P.chan, P.guid, P.total = nil, nil, nil, 0
	local token = {}
	P.hold = token
	local ok = type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, PUSH_HOLD, function()
		if P.hold == token then
			P.hold = nil
			pcall(PushHide)
		end
	end)
	if not ok then
		P.hold = nil
		PushHide()
	end
end

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
			local before = math.abs(P.total)
			P.total = P.total + (endMs - P.lastEnd) / 1000
			PushShow(false, math.abs(P.total) - before >= PUSH_LEAST)
		end
		if endMs then
			P.lastEnd, P.chan = endMs, chan
		end
	elseif what == "ended" then
		local plain = PlainGuid(guid)
		if (plain ~= nil and plain == P.guid) or CastEnd() == nil then
			PushEnd()
		end
	elseif what == "stop" or CastEnd() == nil then
		PushEnd()
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

local K = { frame = nil, on = false, at = nil, played = 0 }
local KickListen
do
	local KICK_ROW, KICK_GAP = "castbars.kickedSound", 1
	local WATCH_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START" }
	local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
	local KICK_EVENTS = { "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP" }
	local WATCH = {
		{ unit = "focus", row = "castbars.focusSound", bar = "FocusFrameSpellBar", label = "Sound when your focus casts" },
		{ unit = "target", row = "castbars.targetSound", bar = "TargetFrameSpellBar", label = "Sound when your target casts" },
	}
	for _, rec in ipairs(WATCH) do
		rec.on, rec.played, rec.byUnit, rec.serial, rec.again = false, 0, false, 0, 0
	end
	K.watch = WATCH

	local function KickOn()
		return ns.Enabled("castbars") and KITS[Get(KICK_ROW)] ~= nil
	end

	local function Kicked(by)
		if ns.IsSecret(by) then
			return true
		end
		if type(by) ~= "string" or by == "" then
			return false
		end
		local ok, mine = pcall(UnitGUID, "player")
		return not (ok and not ns.IsSecret(mine) and mine == by)
	end

	local function KickHeard(by)
		if not Kicked(by) then
			return
		end
		local now = GetTime()
		if K.at and now >= K.at and now - K.at < KICK_GAP then
			return
		end
		local kit = KITS[Get(KICK_ROW)]
		local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
		if sound and type(ns.PlayKit) == "function" then
			K.at = now
			if ns.PlayKit(sound[1], "castbars") then
				K.played = K.played + 1
			end
		end
	end

	local function KickEvent(_, _, unit, _, _, by)
		if K.on and not ns.IsSecret(unit) and unit == "player" then
			pcall(KickHeard, by)
		end
	end

	local function WatchOn(rec)
		return ns.Enabled("castbars") and KITS[Get(rec.row)] ~= nil and Get("castbars.interrupt") == true
	end

	local function SameAsFocus(rec)
		local focus = WATCH[1]
		if rec == focus or not (focus.on and WatchOn(focus)) then
			return false
		end
		local ok, same = pcall(UnitIsUnit, rec.unit, focus.unit)
		return ok and not ns.IsSecret(same) and same == true
	end

	local function WatchLook(rec)
		if not (rec.on and WatchOn(rec)) or type(ns.InterruptReady) ~= "function" or ns.InterruptReady(rec.unit) ~= true or SameAsFocus(rec) then
			return
		end
		local bar = PlayerBar(rec.bar)
		local shield = bar and bar.BorderShield
		if shield ~= nil and not ns.IsSecret(shield) and type(shield) == "table" then
			local ok, shown = pcall(shield.IsShown, shield)
			if ok and Flag(shown) then
				return
			end
		end
		local now = GetTime()
		if rec.at and now >= rec.at and now - rec.at < KICK_GAP then
			return
		end
		local kit = KITS[Get(rec.row)]
		local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
		if sound and type(ns.PlayKit) == "function" then
			rec.at = now
			rec.heard, rec.waitFor = rec.serial, nil
			if ns.PlayKit(sound[1], "castbars") then
				rec.played = rec.played + 1
				return true
			end
		end
	end

	local function WatchEvent(rec, unit)
		if not rec.on then
			return
		end
		if not rec.byUnit and (ns.IsSecret(unit) or unit ~= rec.unit) then
			return
		end
		rec.serial, rec.waitFor = rec.serial + 1, nil
		pcall(C_Timer.After, 0, function()
			pcall(WatchLook, rec)
		end)
	end

	local function WatchCaster(rec)
		local ok, guid = pcall(UnitGUID, rec.unit)
		if ok and not ns.IsSecret(guid) and guid ~= rec.guid then
			rec.guid = guid
			rec.serial, rec.waitFor = rec.serial + 1, nil
		end
	end

	function WatchAgain()
		for _, rec in ipairs(WATCH) do
			if rec.on and WatchOn(rec) then
				local bar = PlayerBar(rec.bar)
				if not (bar and (Flag(bar.casting) or Flag(bar.channeling))) then
					rec.waitFor = nil
				elseif type(ns.InterruptReady) == "function" then
					WatchCaster(rec)
					if rec.heard ~= rec.serial then
						local ready = ns.InterruptReady(rec.unit)
						if ready == false or ready == "far" then
							rec.waitFor = rec.serial
						elseif ready == true and rec.waitFor == rec.serial then
							rec.waitFor = nil
							if WatchLook(rec) then
								rec.again = rec.again + 1
							end
						end
					end
				end
			end
		end
	end

	function Watching()
		for _, rec in ipairs(WATCH) do
			if rec.on then
				return true
			end
		end
		return false
	end

	local function WatchListen(rec)
		local on = WatchOn(rec)
		if on == rec.on then
			return
		end
		if rec.frame == nil then
			local ok, frame = pcall(CreateFrame, "Frame")
			rec.frame = ok and not ns.IsSecret(frame) and type(frame) == "table" and frame or false
			if rec.frame then
				ns.Own[frame] = true
				frame:SetScript("OnEvent", function(_, _, unit)
					WatchEvent(rec, unit)
				end)
			end
		end
		local frame = rec.frame
		if not frame then
			return
		end
		rec.on = on
		local byUnit = true
		for _, event in ipairs(WATCH_EVENTS) do
			if not on then
				pcall(frame.UnregisterEvent, frame, event)
			elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, event, rec.unit)) then
				pcall(frame.RegisterEvent, frame, event)
				byUnit = false
			end
		end
		rec.byUnit = on and byUnit
	end

	local LAND_ROW, LAND_LOOK, LAND_FOR, LAND_FRESH = "castbars.landSound", 0.05, 0.4, 0.1
	local LAND_BARS = { "TargetFrameSpellBar", "FocusFrameSpellBar" }
	local LAND_UNITS, LAND_SELVES = { "target", "focus" }, { "player", "pet" }
	local LAND_STOPS = { UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true }
	local WORD_ROW, WORD_GAP, WORD_RGB = "combattext.kicks", 0.3, { 0.2, 0.85, 0.35 }
	local L = { on = false, played = 0, at = nil, frame = nil, ticker = nil, otherAt = {}, icons = {}, shown = 0 }
	K.land = L

	local function LandSoundOn()
		return ns.Enabled("castbars") and KITS[Get(LAND_ROW)] ~= nil
	end

	local function LandWordOn()
		return Get(WORD_ROW) == true and ns.Enabled("combattext")
	end

	local function LandOn()
		return LandSoundOn() or LandWordOn()
	end

	local function Within(at, span)
		local now = GetTime()
		return at ~= nil and now >= at and now - at < span
	end

	local function LandIcon(spell)
		if ns.IsSecret(spell) or type(spell) ~= "number" or type(C_Spell) ~= "table" or type(C_Spell.GetSpellTexture) ~= "function" then
			return nil
		end
		local icon = L.icons[spell]
		if icon == nil then
			local ok, got = pcall(C_Spell.GetSpellTexture, spell)
			icon = ok and not ns.IsSecret(got) and type(got) == "number" and got or false
			L.icons[spell] = icon
		end
		return icon or nil
	end

	local function LandWordShow()
		local text = ns.ScrollText
		if not (LandWordOn() and type(text) == "table" and type(text.On) == "function" and text.On("out")) or Within(L.wordAt, WORD_GAP) then
			return
		end
		L.wordAt = GetTime()
		local r, g, b = ns.Colour("castbars.interruptReady")
		if not (ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
			r, g, b = WORD_RGB[1], WORD_RGB[2], WORD_RGB[3]
		end
		local word = type(_G.INTERRUPTED) == "string" and _G.INTERRUPTED or "Interrupted"
		local icon = LandIcon(Within(L.spellAt, LAND_FOR) and L.spell or nil)
		if text.Show("out", "word", word, nil, false, r, g, b, nil, nil, false, icon) then
			L.shown = L.shown + 1
		end
	end

	local function LandWord()
		if Within(L.spellAt, LAND_FOR) or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
			LandWordShow()
		elseif not pcall(C_Timer.After, 0, function()
			pcall(LandWordShow)
		end) then
			LandWordShow()
		end
	end

	local function Fresh(bar)
		local anim = bar.HoldFadeOutAnim
		if ns.IsSecret(anim) or type(anim) ~= "table" then
			return false
		end
		local ok, playing = pcall(anim.IsPlaying, anim)
		if not (ok and Flag(playing)) then
			return false
		end
		local read, elapsed = pcall(anim.GetElapsed, anim)
		return read and ns.Finite(elapsed) and elapsed <= LAND_FRESH
	end

	local function LandPlay()
		if LandWordOn() then
			pcall(LandWord)
		end
		local now = GetTime()
		if not LandSoundOn() or (L.at and now >= L.at and now - L.at < KICK_GAP) then
			return
		end
		local kit = KITS[Get(LAND_ROW)]
		local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
		if sound and type(ns.PlayKit) == "function" then
			L.at = now
			if ns.PlayKit(sound[1], "castbars") then
				L.played = L.played + 1
			end
		end
	end

	local function LandLook(snap)
		if not L.on or type(ns.CastBarInterrupted) ~= "function" or Within(L.sureAt, LAND_FOR) then
			return true
		end
		for index, name in ipairs(LAND_BARS) do
			local bar = PlayerBar(name)
			if bar and not Within(L.otherAt[LAND_UNITS[index]], LAND_FOR) and ns.CastBarInterrupted(bar) and (snap[index] or Fresh(bar)) then
				LandPlay()
				return true
			end
		end
		return false
	end

	local function LandStop()
		local ticker = L.ticker
		L.ticker = nil
		if ticker then
			pcall(ticker.Cancel, ticker)
		end
	end

	local function LandHeard(spell)
		if ns.IsSecret(spell) or type(spell) ~= "number" then
			return
		end
		local kick = type(ns.InterruptSpell) == "function" and ns.InterruptSpell(spell) == true
		if kick or not (L.kick and Within(L.spellAt, LAND_FOR)) then
			L.spell, L.spellAt, L.kick = spell, GetTime(), kick
		end
		if not kick or Within(L.sureAt, LAND_FOR) then
			return
		end
		local snap = {}
		for index, name in ipairs(LAND_BARS) do
			local bar = PlayerBar(name)
			snap[index] = bar ~= nil and (Flag(bar.casting) or Flag(bar.channeling))
		end
		LandStop()
		if LandLook(snap) or type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
			return
		end
		local left = math.floor(LAND_FOR / LAND_LOOK + 0.5)
		local ok, ticker = pcall(C_Timer.NewTicker, LAND_LOOK, function()
			left = left - 1
			local looked, done = pcall(LandLook, snap)
			if not looked or done or left <= 0 then
				LandStop()
			end
		end, left)
		L.ticker = ok and ticker or nil
	end

	local function Mine(by)
		for _, token in ipairs(LAND_SELVES) do
			local ok, guid = pcall(UnitGUID, token)
			if ok and not ns.IsSecret(guid) and type(guid) == "string" and guid == by then
				return true
			end
		end
		return false
	end

	local function LandStopped(unit, by)
		if ns.IsSecret(by) or type(by) ~= "string" or by == "" then
			return
		end
		local ok, foe = pcall(UnitCanAttack, "player", unit)
		if not (ok and not ns.IsSecret(foe) and foe == true) then
			return
		end
		if Mine(by) then
			L.sureAt = GetTime()
			LandStop()
			LandPlay()
		else
			L.otherAt[unit] = GetTime()
		end
	end

	local function LandEvent(_, event, unit, _, spell, by)
		if not L.on or ns.IsSecret(unit) or type(unit) ~= "string" then
			return
		end
		if LAND_STOPS[event] then
			pcall(LandStopped, unit, by)
		elseif unit == "player" or unit == "pet" then
			pcall(LandHeard, spell)
		end
	end

	local function LandListen()
		local on = LandOn()
		L.sound, L.word = LandSoundOn(), LandWordOn()
		if on == L.on then
			return
		end
		if L.frame == nil then
			local ok, frame = pcall(CreateFrame, "Frame")
			L.frame = ok and not ns.IsSecret(frame) and type(frame) == "table" and frame or false
			if L.frame then
				ns.Own[frame] = true
				frame:SetScript("OnEvent", LandEvent)
			end
		end
		local frame = L.frame
		if not frame then
			return
		end
		L.on = on
		if not on then
			LandStop()
			pcall(frame.UnregisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
		elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "pet")) then
			pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
		end
		for event in pairs(LAND_STOPS) do
			pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
		end
	end

	function KickListen()
		for _, rec in ipairs(WATCH) do
			pcall(WatchListen, rec)
		end
		pcall(LandListen)
		local on = KickOn()
		if on == K.on then
			return
		end
		if K.frame == nil then
			local ok, frame = pcall(CreateFrame, "Frame")
			K.frame = ok and not ns.IsSecret(frame) and type(frame) == "table" and frame or false
			if K.frame then
				ns.Own[frame] = true
				frame:SetScript("OnEvent", KickEvent)
			end
		end
		local frame = K.frame
		if not frame then
			return
		end
		K.on = on
		for _, event in ipairs(KICK_EVENTS) do
			if not on then
				pcall(frame.UnregisterEvent, frame, event)
			elseif not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, event, "player")) then
				pcall(frame.RegisterEvent, frame, event)
			end
		end
	end

	function ns.CastKickedSample()
		local kit = ns.Enabled("castbars") and KITS[Get(KICK_ROW)]
		local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
		local mode = ns.TestMode
		if sound and type(ns.PlayKit) == "function" and type(mode) == "table" and type(mode.Sound) == "function" and mode.Sound("castkicked") then
			ns.PlayKit(sound[1], "castbars")
		end
	end

	local function Sample(row, id)
		local kit = ns.Enabled("castbars") and KITS[Get(row)]
		local sound = kit and ns.SOUNDS and ns.SOUNDS[kit]
		local mode = ns.TestMode
		if sound and type(ns.PlayKit) == "function" and type(mode) == "table" and type(mode.Sound) == "function" and mode.Sound(id) then
			ns.PlayKit(sound[1], "castbars")
		end
	end

	function ns.CastWatchSample(unit)
		for _, rec in ipairs(WATCH) do
			if rec.unit == unit and WatchOn(rec) then
				Sample(rec.row, "cast" .. unit)
			end
		end
	end

	function ns.CastLandSample()
		Sample(LAND_ROW, "castland")
	end

	function ns.CastKickedSoundPicked(path)
		pcall(KickListen)
		Sync()
		if type(ns.CombatCueSoundPicked) == "function" then
			ns.CombatCueSoundPicked(path)
		end
	end

	function ns.CastLandSync()
		pcall(KickListen)
	end
end

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

local function AimAhead()
	if AimOn() then
		for _, entry in ipairs(OWN) do
			local bar = PlayerBar(entry[1])
			local aim = bar and MakeAim(bar)
			if aim then
				AimPlace(bar, aim)
			end
		end
	end
end

function ns.CastTimeSync()
	pcall(Fades)
	if not InCombatLockdown() and not state.stopped then
		pcall(MakeAhead)
	end
	if not InCombatLockdown() then
		pcall(AimAhead)
	end
	pcall(KickAhead, KickTimeOn() and not InCombatLockdown())
	pcall(PushListen, PushOn())
	pcall(KickListen)
	for _, entry in pairs(pushTexts) do
		if entry then
			pcall(PushColour, entry)
		end
	end
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
	if state.noTotal and Get(TOTAL_ROW) == true then
		line = line .. ". The game would not give the whole of a cast, so it showed the seconds left alone"
	end
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
	if AimOn() then
		lines[#lines + 1] = ("Target of enemy casts: %d casts named their target, %d in its class colour and %d in white."):format(state.aimed,
			state.aimClass, state.aimed - state.aimClass)
	end
	if KickTimeOn() then
		lines[#lines + 1] = KT.refused and ("Seconds until your interrupt is ready: shown on %d casts; the game would not write them once."):format(KT.shown)
			or ("Seconds until your interrupt is ready: shown on %d casts."):format(KT.shown)
	end
	if PushOn() then
		lines[#lines + 1] = P.last and ("Pushback on your bar: the last shown was %+.1f."):format(P.last) or "Pushback on your bar: no pushback seen yet."
	end
	if K.on then
		lines[#lines + 1] = ("Sound when you are interrupted: %d played."):format(K.played)
	end
	for _, rec in ipairs(K.watch or {}) do
		if rec.on then
			lines[#lines + 1] = ("%s: %d played, %d of them as your interrupt came back during the cast."):format(rec.label, rec.played, rec.again)
		end
	end
	local land = K.land
	if land and land.on and land.sound then
		lines[#lines + 1] = ("Sound when your interrupt lands: %d played."):format(land.played)
	end
	if land and land.on and land.word then
		lines[#lines + 1] = ("Your interrupts in the Outgoing area: %d shown."):format(land.shown)
	end
	return lines
end
