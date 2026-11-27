local _, ns = ...

local X = ns.UnitFrameExtra
local PART, LOW = "health curve", "low health border"
local EVERY = 0.1
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TELL_LOW = "Flat UI: the low health border shows when the fight ends."
local weak = { __mode = "k" }

local state = { probed = false, works = false, why = nil, steps = {} }
local bars, painted = setmetatable({}, weak), setmetatable({}, weak)
local plates = setmetatable({}, weak)
local resource = {}
local installed, missing = false, false

local function Get(path)
	return ns.Get(path)
end

local function Colour(path)
	local r, g, b = ns.Colour(path)
	return CreateColor(r, g, b, 1)
end

local function Curve()
	local key = table.concat({ Get("general.healthLow"), Get("general.healthHalf"), Get("general.healthFull") }, ":")
	if state.curve == nil or state.curveKey ~= key then
		local curve = C_CurveUtil.CreateColorCurve()
		curve:AddPoint(0, Colour("general.healthLow"))
		curve:AddPoint(0.5, Colour("general.healthHalf"))
		curve:AddPoint(1, Colour("general.healthFull"))
		state.curve, state.curveKey = curve, key
	end
	return state.curve
end

function ns.HealthLeftColour(fraction)
	local share = math.max(0, math.min(1, fraction))
	local from, to, at = "general.healthLow", "general.healthHalf", share * 2
	if share > 0.5 then
		from, to, at = "general.healthHalf", "general.healthFull", (share - 0.5) * 2
	end
	local r1, g1, b1 = ns.Colour(from)
	local r2, g2, b2 = ns.Colour(to)
	return r1 + (r2 - r1) * at, g1 + (g2 - g1) * at, b1 + (b2 - b1) * at
end

local function Step(at)
	local curve = state.steps[at]
	if curve == nil then
		curve = C_CurveUtil.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		curve:AddPoint(0, 1)
		curve:AddPoint(at / 100, 0)
		state.steps[at] = curve
	end
	return curve
end

local function Tint(bar, unit)
	local colour = UnitHealthPercent(unit, true, Curve())
	bar:SetStatusBarColor(colour:GetRGB())
end

local function Probe(again)
	if state.works or (state.probed and not again) then
		return state.works
	end
	state.probed = true
	local ok, err = pcall(function()
		if state.hidden == nil then
			state.hidden = CreateFrame("StatusBar")
			ns.Own[state.hidden] = true
			state.hidden:Hide()
		end
		if not state.textured then
			state.hidden:SetStatusBarTexture(WHITE)
			state.textured = true
		end
		Tint(state.hidden, "player")
	end)
	state.works, state.why = ok, not ok and tostring(err) or nil
	return ok
end

local function Switches()
	return (ns.Enabled("unitframes") and (Get("unitframes.healthByLeft") == true or Get("unitframes.lowHealth") == true))
		or (Get("resource.healthByLeft") == true and ns.Enabled("resource"))
		or (ns.Enabled("nameplates") and (Get("nameplates.healthByLeft") == true or Get("nameplates.lowHealth") == true))
end

local function FrameOn(rec)
	return rec.kind ~= "raid" and Get("unitframes.healthByLeft") == true and Get("unitframes.flat") == true and ns.Enabled("unitframes")
		and not ns.PartStopped("unitframes", PART) and Probe(false)
end

function ns.HealthLeftFrameOn(rec)
	return FrameOn(rec)
end

local driver, clock = nil, 0
local Tick

local function Drive()
	if driver == nil then
		driver = CreateFrame("Frame")
		ns.Own[driver] = true
		driver:SetScript("OnUpdate", Tick)
	end
	driver:Show()
end

local function Sync()
	if driver ~= nil then
		if Switches() or resource.painted then
			driver:Show()
		else
			driver:Hide()
		end
	end
end

function X.leftFile()
	local file = X.fillFile("health")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

function X.healthLeft(rec, entry)
	local bar = entry.bar
	if FrameOn(rec) then
		bars[bar], painted[bar] = rec, true
		Drive()
		return true
	end
	if painted[bar] then
		painted[bar], bars[bar] = nil, nil
		ns.RestoreFill(bar)
	end
	return false
end

local function RefreshFrames()
	local module = ns.modules and ns.modules.unitframes
	if module ~= nil and type(module.Refresh) == "function" then
		pcall(module.Refresh)
	end
end

local function PaintFrame(bar, rec)
	if not (FrameOn(rec) and rec.made and X.active(rec)) then
		return
	end
	local unit = X.unitOf(rec)
	if type(unit) ~= "string" or ns.IsSecret(unit) then
		return
	end
	local ok, exists = pcall(UnitExists, unit)
	if ok and exists == true and not ns.IsSecret(exists) then
		Tint(bar, unit)
	end
end

local function StepFrames()
	for bar, rec in pairs(bars) do
		if not ns.Forbidden(bar) then
			ns.EachPart("unitframes", PART, PaintFrame, bar, rec)
		end
	end
	if ns.PartStopped("unitframes", PART) and next(painted) ~= nil then
		RefreshFrames()
	end
end

local LOW_FRAMES = "Low health border"
local LOW_KINDS = { player = true, pet = true, party = true, partypet = true, raid = true }
local ENEMY_KINDS = { target = true, focus = true, boss = true, tot = true }
local PULSE = { low = 0.35, time = 0.45 }
local RADIUS = { slight = 1, soft = 2 }
local lows = setmetatable({}, weak)

local function Yes(ok, value)
	return ok and not ns.IsSecret(value) and value == true
end

local function Takes(rec)
	return LOW_KINDS[rec.kind] == true or (ENEMY_KINDS[rec.kind] == true and Get("unitframes.lowHealthTarget") == true)
end

local function LowOn(rec)
	return Takes(rec) and rec.made == true and Get("unitframes.lowHealth") == true and X.active(rec)
		and not ns.PartStopped("unitframes", LOW_FRAMES) and Probe(false)
end

local function MakeLow(rec)
	local entry = rec.byRole.health
	local box = entry and entry.target
	if box == nil or ns.Forbidden(box) then
		return nil
	end
	local under = entry.outline and entry.outline.holder or box
	local ok, level = pcall(under.GetFrameLevel, under)
	local holder = X.frame(box, ok and X.number(level) and level + 1 or nil)
	holder:SetAllPoints(box)
	holder:Hide()
	local pulse = X.frame(holder)
	pulse:SetAllPoints(holder)
	local outline = ns.Outline(pulse, pulse)
	if outline == nil then
		return nil
	end
	ns.SetOutline(outline, true, false)
	local line = pulse:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[line] = true
	line:Hide()
	local beat = nil
	if type(pulse.CreateAnimationGroup) == "function" then
		local okGroup, group = pcall(pulse.CreateAnimationGroup, pulse)
		local made = okGroup and group ~= nil and pcall(group.SetLooping, group, "REPEAT")
		for order, alphas in ipairs({ { 1, PULSE.low }, { PULSE.low, 1 } }) do
			local okFade, fade = false, nil
			if made then
				okFade, fade = pcall(group.CreateAnimation, group, "Alpha")
			end
			made = okFade and fade ~= nil and pcall(fade.SetFromAlpha, fade, alphas[1]) and pcall(fade.SetToAlpha, fade, alphas[2])
				and pcall(fade.SetDuration, fade, PULSE.time) and pcall(fade.SetOrder, fade, order)
		end
		if made then
			beat = group
		end
	end
	local low = { holder = holder, pulse = pulse, beat = beat, outline = outline, line = line }
	rec.lowHealth = low
	lows[rec] = true
	return low
end

local function Rounded(rec, low)
	local entry = rec.byRole.health
	local rim = entry and type(X.rimLine) == "function" and X.rimLine(entry.outline) or nil
	local radius = nil
	if rim ~= nil and Yes(pcall(rim.IsShown, rim)) then
		radius = RADIUS[Get("unitframes.corners")]
	end
	if radius ~= low.radius then
		low.radius = radius
		low.rounded = radius ~= nil and type(X.shape) == "function" and X.shape(low.line, radius, true) == true
		if low.rounded and low.rim ~= rim then
			low.line:ClearAllPoints()
			low.line:SetAllPoints(rim)
			low.rim = rim
		end
	end
	return low.rounded == true
end

local function Beat(low, on)
	local beat = low.beat
	if beat == nil then
		return
	end
	if on then
		local okSeen, seen = pcall(low.holder.IsVisible, low.holder)
		on = not (okSeen and not ns.IsSecret(seen) and seen == false)
	end
	if on then
		if not Yes(pcall(beat.IsPlaying, beat)) then
			local now = type(GetTime) == "function" and GetTime() or nil
			if not (ns.Finite(now) and pcall(beat.Play, beat, false, now % (2 * PULSE.time))) then
				pcall(beat.Play, beat)
			end
		end
	elseif low.beating ~= false then
		pcall(beat.Stop, beat)
		low.pulse:SetAlpha(1)
	end
	low.beating = on and true or false
end

local function PaintLow(rec)
	local low = rec.lowHealth
	if low == nil then
		return
	end
	local unit = LowOn(rec) and X.unitOf(rec) or nil
	local show = type(unit) == "string" and not ns.IsSecret(unit) and Yes(pcall(UnitExists, unit)) and not Yes(pcall(UnitIsDeadOrGhost, unit))
	if show then
		local ok, connected = pcall(UnitIsConnected, unit)
		show = not (ok and not ns.IsSecret(connected) and connected == false)
	end
	if not show then
		Beat(low, false)
		if low.shown then
			low.shown = nil
			low.holder:Hide()
		end
		return
	end
	local r, g, b = ns.Colour("unitframes.lowHealthColour")
	ns.SetOutlineColour(low.outline, r, g, b)
	local round = Rounded(rec, low)
	ns.SetOutlineEdges(low.outline, not round)
	low.line:SetShown(round)
	if round then
		low.line:SetVertexColor(r, g, b, 1)
	end
	local at = Get("unitframes.lowHealthAt")
	if ENEMY_KINDS[rec.kind] and not Yes(pcall(UnitCanAssist, "player", unit)) then
		at = Get("unitframes.lowHealthTargetAt")
	end
	low.holder:SetAlpha(UnitHealthPercent(unit, true, Step(ns.Finite(at) and at or 20)))
	if not low.shown then
		low.shown = true
		low.holder:Show()
	end
	Beat(low, Get("unitframes.lowHealthPulse") == true)
end

local function StepLow()
	for rec in pairs(lows) do
		local low = rec.lowHealth
		if low ~= nil and (low.shown or LowOn(rec)) then
			X.run(LOW_FRAMES, PaintLow, rec)
		end
	end
end

local ApplyLow
function ApplyLow(rec, on)
	if not (LOW_KINDS[rec.kind] or ENEMY_KINDS[rec.kind]) then
		return
	end
	if not (on and LowOn(rec)) then
		PaintLow(rec)
		return
	end
	if rec.lowHealth == nil then
		if InCombatLockdown() then
			X.tell(TELL_LOW)
			if not rec.lowQueued then
				rec.lowQueued = true
				ns.OutOfCombat(function()
					rec.lowQueued = nil
					X.run(LOW_FRAMES, ApplyLow, rec, X.active(rec))
				end)
			end
			return
		end
		if MakeLow(rec) == nil then
			return
		end
	end
	Drive()
	PaintLow(rec)
end

table.insert(X.after.apply, { part = LOW_FRAMES, fn = ApplyLow })
table.insert(X.after.raid, { part = LOW_FRAMES, fn = ApplyLow })

local function ResourceBar()
	local display = PersonalResourceDisplayFrame
	if display == nil or ns.IsSecret(display) or ns.Forbidden(display) then
		return nil
	end
	local container = display.HealthBarsContainer
	local bar = container ~= nil and not ns.Forbidden(container) and container.healthBar or nil
	if bar ~= nil and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

function ns.ResourceHealthLeft()
	return Get("resource.healthByLeft") == true and Get("resource.flat") == true and ns.Enabled("resource") and not ns.PartStopped("resource", PART)
		and Probe(false)
end

local function PaintResource(_)
	local bar = ResourceBar()
	if bar == nil then
		return
	end
	if ns.ResourceHealthLeft() then
		if not resource.painted then
			local r, g, b, a = bar:GetStatusBarColor()
			resource.game = { r, g, b, a }
		end
		resource.painted = true
		Tint(bar, "player")
	elseif resource.painted then
		resource.painted = nil
		local game = resource.game
		if game ~= nil then
			bar:SetStatusBarColor(game[1], game[2], game[3], game[4])
		end
	end
end

local function StepResource()
	if resource.painted or ns.ResourceHealthLeft() then
		if not ns.EachPart("resource", PART, PaintResource, {}) and ns.PartStopped("resource", PART) then
			pcall(PaintResource)
		end
	end
end

function Tick(_, elapsed)
	clock = clock + elapsed
	if clock < EVERY then
		return
	end
	clock = 0
	StepFrames()
	StepLow()
	StepResource()
	Sync()
end

function ns.HealthLeftSync()
	if Get("resource.healthByLeft") == true and ns.Enabled("resource") then
		Probe(true)
		Drive()
	end
	Sync()
end

local function Bar(frame)
	local bar = frame.healthBar
	if bar == nil then
		local container = frame.HealthBarsContainer
		bar = container ~= nil and not ns.Forbidden(container) and container.healthBar or nil
	end
	if bar ~= nil and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

local function Styled(frame)
	local friend = frame.isFriend
	return Get("nameplates.friendly") == true or ns.IsSecret(friend) or friend ~= true
end

local function PlateUnit(frame)
	local unit = frame.unit
	if type(unit) == "string" and not ns.IsSecret(unit) then
		return unit
	end
	return nil
end

local function PlateOn(frame)
	return ns.Enabled("nameplates") and ns.IsPlate(frame) and Styled(frame) and Probe(false)
end

local function ColourPlate(frame, rec, fromGame)
	local bar = Bar(frame)
	if bar == nil then
		return
	end
	local unit = PlateUnit(frame)
	local wanted = unit ~= nil and Get("nameplates.healthByLeft") == true and PlateOn(frame) and not ns.PartStopped("nameplates", PART)
	local overridden = wanted and ns.PlateOverride ~= nil and ns.PlateOverride(frame)
	if wanted and not overridden then
		if fromGame or not rec.painted then
			local r, g, b, a = bar:GetStatusBarColor()
			rec.game = { r, g, b, a }
		end
		rec.painted = true
		Tint(bar, unit)
	elseif rec.painted then
		rec.painted = nil
		local game = rec.game
		if overridden then
			rec.game = nil
		elseif game ~= nil and not fromGame then
			bar:SetStatusBarColor(game[1], game[2], game[3], game[4])
		end
	end
end

local RunPlate

local function BorderPlate(frame, rec)
	local bar = Bar(frame)
	if bar == nil then
		return
	end
	local unit = PlateUnit(frame)
	local want = unit ~= nil and Get("nameplates.lowHealth") == true and PlateOn(frame) and not ns.PartStopped("nameplates", LOW)
	local low = rec.low
	if not want then
		if low ~= nil and low.shown then
			low.shown = nil
			low.holder:Hide()
		end
		return
	end
	if low == nil then
		if InCombatLockdown() and ns.MaybeProtected(bar) then
			X.tell(TELL_LOW)
			ns.OutOfCombat(function()
				if ns.IsPlate(frame) then
					RunPlate(frame, false)
				end
			end)
			return
		end
		local holder = CreateFrame("Frame", nil, bar)
		ns.Own[holder] = true
		holder:SetAllPoints(bar)
		low = { holder = holder, outline = ns.Outline(holder, holder) }
		rec.low = low
		ns.SetOutline(low.outline, true, false)
	end
	ns.SetOutlineColour(low.outline, ns.Colour("nameplates.lowHealthColour"))
	low.holder:SetAlpha(UnitHealthPercent(unit, true, Step(Get("nameplates.lowHealthAt"))))
	if not low.shown then
		low.shown = true
		low.holder:Show()
	end
end

local function Record(frame)
	local rec = plates[frame]
	if rec == nil then
		rec = {}
		plates[frame] = rec
	end
	return rec
end

function RunPlate(frame, fromGame)
	local rec = Record(frame)
	if ns.IsStopped("nameplates") then
		pcall(ColourPlate, frame, rec, fromGame)
		pcall(BorderPlate, frame, rec)
		return
	end
	if not ns.EachPart("nameplates", PART, ColourPlate, frame, rec, fromGame) and ns.PartStopped("nameplates", PART) then
		ns.EachPlate(function(other)
			pcall(ColourPlate, other, Record(other), false)
		end)
	end
	if not ns.EachPart("nameplates", LOW, BorderPlate, frame, rec) and ns.PartStopped("nameplates", LOW) then
		ns.EachPlate(function(other)
			pcall(BorderPlate, other, Record(other))
		end)
	end
end

local function OnHealth(frame)
	if ns.IsPlate(frame) and (plates[frame] ~= nil or Get("nameplates.healthByLeft") == true or Get("nameplates.lowHealth") == true) then
		RunPlate(frame, true)
	end
end

local function Install()
	if installed or missing or not (Get("nameplates.healthByLeft") == true or Get("nameplates.lowHealth") == true) or not Probe(false) then
		return
	end
	if ns.FollowGlobal("CompactUnitFrame_UpdateHealthColor", OnHealth) then
		installed = true
	else
		missing = true
		ns.Note("nameplates", "Health curve: the game's health colour call was not found, so nameplate health bars keep the game's colours.")
	end
end

local extra = ns.PlateExtra
extra.show[#extra.show + 1] = function(frame)
	Install()
	if plates[frame] ~= nil or Get("nameplates.healthByLeft") == true or Get("nameplates.lowHealth") == true then
		RunPlate(frame, false)
	end
end
extra.leave[#extra.leave + 1] = function(frame)
	local rec = plates[frame]
	if rec ~= nil then
		rec.painted, rec.game = nil, nil
		if rec.low ~= nil and rec.low.shown then
			rec.low.shown = nil
			rec.low.holder:Hide()
		end
	end
end
extra.refresh[#extra.refresh + 1] = function()
	if Switches() then
		Probe(true)
	end
	Install()
	if Switches() or next(plates) ~= nil then
		ns.EachPlate(RunPlate, false)
	end
	Sync()
end

local function StatusLine()
	if not Switches() then
		return nil
	end
	if Probe(false) then
		return "Health curve: works"
	end
	return "Health curve: refused. Colouring by health left and Low health border, on unit frames and nameplates, do nothing. " .. tostring(state.why)
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
