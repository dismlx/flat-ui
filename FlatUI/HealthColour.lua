local _, ns = ...

-- Colour by health left, and the low health border. The colours are three points of a colour curve of the game (C_CurveUtil.CreateColorCurve: 0 is the
-- colour at low health, 0.5 half, 1 full; Blizzard_APIDocumentationGenerated/CurveUtilDocumentation.lua:11, LuaColorCurveObjectAPIDocumentation.lua:11).
-- UnitHealthPercent(unit, usePredicted, curve) answers with the colour the curve gives at the health left (UnitDocumentation.lua:1506-1523), which is
-- withheld for a unit whose health the client withholds. The colour goes straight into SetStatusBarColor, which accepts withheld values
-- (SimpleStatusBarAPIDocumentation.lua:282-285). Nothing here compares, adds or reads such a colour, and none is used as a key.
-- The health bar of a plate takes the low health border's alpha the same way: a step curve of two points (0 is 1, the limit is 0) and SetAlpha.
-- The curve calls were never made by the game's own files (nothing in Blizzard_* calls UnitHealthPercent with a curve), so they are tried first, in a
-- pcall, on a hidden status bar of the addon's own the first time a row asks. A refusal turns every row of this file into no change, and
-- /flatui status says so. A row at its default makes no call at all.
--
-- Unit frames: UnitFrames.lua asks healthLeft while it sets a health fill. The fill is then an image in white (the bar texture of the page, or a white
-- file) and a frame of the addon's own tints it every 0.1 s. Raid frames are left out. The fill record of ns.FlatFill is what puts the colour back.
-- Low health border of unit frames (off by default, All frames: bars and pictures): on the player, pet, party, party pet and raid frames, and with
-- Also on target, focus, boss and target of target frames (off by default) on those and the focus target too, for Execute and Hammer of Wrath and the
-- tank a healer watches on the target of target, a frame of the addon's own over the outlined health bar, one level above Flat UI's own outline of it,
-- holds an inner frame of its own with four edges in the
-- row's colour just outside the bar (and the rounded line in place of them while the bar's own outline is rounded), and takes the alpha of a step
-- curve at its limit every 0.1 s, as a plate's does. With Pulse the low health border on (off by default) the inner frame beats: an Alpha animation of
-- its own, from 1 to 0.35 and back every 0.45 s, plays while the border shows and stops, at full alpha, when it hides or the row goes off; above the
-- limit the curve's alpha of 0 hides it either way. Every beat starts at the place of the clock in one whole beat (a play offset of GetTime), so all
-- the borders on screen dim and brighten together, and a beat on a frame the game hid (IsVisible plainly false) stops until it shows. A beat on a frame
-- above the limit cannot be stopped: its health is withheld (UnitHealth always is), and so is GetAlpha after a withheld SetAlpha
-- (SimpleFrameAPIDocumentation.lua:276-288), so nothing tells it from a frame below; it plays unseen under the curve's alpha of 0. It is made out of
-- combat, on a frame the game protects; in a fight only its alpha, its colour, whether it shows and whether its animation plays change (Play and Stop
-- on a frame of the addon's own that is not protected). One the row asks for in a fight waits for its end, and while the options window is open chat
-- says so once a fight (X.tell), on a nameplate too. It hides while the unit is plainly dead, a ghost or offline, and while the row, the frame or
-- the part is off. The limit is Low health below, but for one of those other frames whose unit you cannot assist (UnitCanAssist, which carries no
-- secret predicate, UnitDocumentation.lua:745-761, and a withheld or missing answer counts as an enemy), which takes Enemies below: an enemy target
-- for Execute at 20% while a friendly one, such as the tank a healer targets, keeps the limit of the group.
-- Nameplates: the game's CompactUnitFrame_UpdateHealthColor runs for each health change (Shared\CompactUnitFrame.lua:725-737, 645), and this file
-- answers it in the same call unless PlateColours.lua paints the plate in a colour of its own (the target, threat or reaction colour).
-- Personal resource display: the same frame tints its health bar, and Bars.lua leaves the health colour to it while the row is on.

local X = ns.UnitFrameExtra
local PART, LOW = "health curve", "low health border"
local EVERY = 0.1
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- What chat says, once a fight and only while the options window is open, when a low health border waits for the end of the fight to be made.
local TELL_LOW = "Flat UI: the low health border shows when the fight ends."
local weak = { __mode = "k" }

-- works: the feature test passed. probed: it has run. curve: the colour curve last made, with the settings it was made from. steps: the step curve of
-- each limit asked for, kept, as the plates and the unit frames each have a limit of their own.
local state = { probed = false, works = false, why = nil, steps = {} }
-- bars: the unit frame health bars asked for, each with its record. painted: the bars the fill of which is this file's.
local bars, painted = setmetatable({}, weak), setmetatable({}, weak)
-- plates: per plate unit frame, the colour the game gave (game), whether this file painted the bar (painted) and the border it made (low).
local plates = setmetatable({}, weak)
-- The health bar of the personal resource display: the game's colour read before the first paint, and whether this file painted.
local resource = {}
local installed, missing = false, false

local function Get(path)
	return ns.Get(path)
end

-- The curve objects ---------------------------------------------------------------------------------------

local function Colour(path)
	local r, g, b = ns.Colour(path)
	return CreateColor(r, g, b, 1)
end

-- The colour curve of the three colours of the Colours page, made again when one of them changes. Raises when the game refuses.
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

-- The colour of a share of health left (0 to 1), as the curve above gives it (low at 0, half at 0.5, full at 1, a straight line between), worked out on a
-- plain number: for a drawing that has no unit to read. Red, green and blue from 0 to 1.
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

-- The step curve of a low health border at a limit in percent: 1 under the limit, 0 from it. One is made for each limit and kept. Raises when the game
-- refuses.
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

-- Tints a status bar in the colour of the health left of a unit. Raises when the game refuses.
local function Tint(bar, unit)
	local colour = UnitHealthPercent(unit, true, Curve())
	bar:SetStatusBarColor(colour:GetRGB())
end

-- The feature test: the player's health through the curve, onto a hidden status bar. It is tried again only when asked to, from a refresh.
-- The colour the curve gives is withheld, and a status bar with no texture refuses a withheld colour ("Object did not allow secret.", seen on
-- build 70790), while one with a texture takes it. Every bar this file tints has a texture, so the hidden bar gets one too.
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

-- The unit frames -----------------------------------------------------------------------------------------

-- True while the health fill of a unit frame is tinted by the health left.
local function FrameOn(rec)
	return rec.kind ~= "raid" and Get("unitframes.healthByLeft") == true and Get("unitframes.flat") == true and ns.Enabled("unitframes")
		and not ns.PartStopped("unitframes", PART) and Probe(false)
end

-- True while the health fill of this unit frame is tinted by the health left (read only, for the mana bar colour).
function ns.HealthLeftFrameOn(rec)
	return FrameOn(rec)
end

local driver, clock = nil, 0
local Tick

-- Makes the frame that tints the bars every 0.1 s, once, and shows it.
local function Drive()
	if driver == nil then
		driver = CreateFrame("Frame")
		ns.Own[driver] = true
		driver:SetScript("OnUpdate", Tick)
	end
	driver:Show()
end

-- Shows the frame while a row asks for it or a bar still has to be given back, and hides it otherwise.
local function Sync()
	if driver ~= nil then
		if Switches() or resource.painted then
			driver:Show()
		else
			driver:Hide()
		end
	end
end

-- The image the fill is made of while it takes the colour: the file of the row, or of the Flat UI page, or a white file.
function X.leftFile()
	local file = X.fillFile("health")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

-- Asked by UnitFrames.lua while it sets the health fill of a frame: true when the fill is tinted by the health left. The first time it is not, after
-- it was, the fill is put back, and the caller sets it again.
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
		-- The part stopped: the fills go back to the colour of the row.
		RefreshFrames()
	end
end

-- The low health border of unit frames --------------------------------------------------------------------

local LOW_FRAMES = "Low health border"
-- The kinds of frame that take it: your own and your pet's, your party's, their pets' and your raid's. The corner radius of each Corners choice
-- (UnitFrames.lua ROUND). The beat of Pulse the low health border: the alpha it dips to and the time of one way.
local LOW_KINDS = { player = true, pet = true, party = true, partypet = true, raid = true }
-- The frames that take it too while Also on target, focus, boss and target of target frames is on: for Execute and Hammer of Wrath, and the tank a
-- healer watches on the target of target. tot is both the target of target and the focus target frame (UnitFrames.lua ROOTS).
local ENEMY_KINDS = { target = true, focus = true, boss = true, tot = true }
local PULSE = { low = 0.35, time = 0.45 }
local RADIUS = { slight = 1, soft = 2 }
-- The records whose frame has a border.
local lows = setmetatable({}, weak)

-- True for a plain true of the client; a withheld answer is no.
local function Yes(ok, value)
	return ok and not ns.IsSecret(value) and value == true
end

-- True for a frame of a kind that takes the border now: your own and your group's always, the target, focus, boss and target of target frames with
-- their row.
local function Takes(rec)
	return LOW_KINDS[rec.kind] == true or (ENEMY_KINDS[rec.kind] == true and Get("unitframes.lowHealthTarget") == true)
end

-- True while a frame takes the border: the row on, the frame styled, the part not stopped and the curves working.
local function LowOn(rec)
	return Takes(rec) and rec.made == true and Get("unitframes.lowHealth") == true and X.active(rec)
		and not ns.PartStopped("unitframes", LOW_FRAMES) and Probe(false)
end

-- The frame over the outlined health bar, one level above the frame that holds Flat UI's outline of it, which takes the step curve's alpha, and inside it
-- the frame that beats (pulse), with an outline of its own (its edges alone, no background), a texture for the rounded line and the animation of Pulse
-- the low health border. Made once, out of combat. Nil when the frame has no outlined health bar.
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
	-- The beat: down to PULSE.low and back up, one Alpha animation each in order, repeated, so that a play offset is a place in one whole beat.
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

-- True while the border draws the rounded line in place of its edges: while the bar's own outline draws its rounded line (Corners, UnitFrames.lua Rim).
-- The line has the file of the radius of Corners and lies over the bar's own line. False while the corners are square or the client refuses the file.
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

-- Plays the beat of a border while `on` and the border can be seen, or stops it with the inner frame at full alpha. A beat starts at the place of the
-- clock in a whole beat (GetTime, two PULSE.time), so every border on screen dims and brightens together, whenever each started; one on a frame the
-- game hid stops, and starts again in step as the frame shows. A withheld answer about being seen keeps the beat.
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

-- The border of one frame: its colour, its edges or its rounded line, its alpha, the step curve at the health left, unread, and its beat. Hidden while the
-- frame does not take it and for a unit that is gone, or plainly dead, a ghost or offline.
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
	-- The limit: Enemies below on a target, focus, boss or target of target you cannot assist, Low health below on any other.
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

-- After each pass of the unit frames over a frame: the border made out of combat the first time the row asks, the driver shown, and the border painted.
local ApplyLow
function ApplyLow(rec, on)
	-- A target, focus, boss or target of target frame goes on while its row is off, so that a border it had hides.
	if not (LOW_KINDS[rec.kind] or ENEMY_KINDS[rec.kind]) then
		return
	end
	if not (on and LowOn(rec)) then
		PaintLow(rec)
		return
	end
	if rec.lowHealth == nil then
		if InCombatLockdown() then
			-- While the options window is open chat says so once a fight (X.tell, UnitFrames.lua).
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

-- The personal resource display ---------------------------------------------------------------------------

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

-- True while the health bar of the personal resource display is tinted by the health left. Bars.lua leaves the health colour alone meanwhile.
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
		-- The one bar has no id of its own, so each look is counted as a frame of its own: three failed looks stop the part.
		if not ns.EachPart("resource", PART, PaintResource, {}) and ns.PartStopped("resource", PART) then
			-- The part stopped: the bar goes back to the colour the game gave it.
			pcall(PaintResource)
		end
	end
end

-- The driver --------------------------------------------------------------------------------------------

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

-- Called by Bars.lua at the end of a refresh of the personal resource display.
function ns.HealthLeftSync()
	if Get("resource.healthByLeft") == true and ns.Enabled("resource") then
		Probe(true)
		Drive()
	end
	Sync()
end

-- The nameplates -----------------------------------------------------------------------------------------

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

-- False for a friendly plate while Restyle friendly nameplates is off, as for the rest of the plate's look.
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

-- Whether this file may touch a plate at all.
local function PlateOn(frame)
	return ns.Enabled("nameplates") and ns.IsPlate(frame) and Styled(frame) and Probe(false)
end

-- The health colour of a plate: tinted by the health left, or the game's colour given back.
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
		-- A colour of PlateColours.lua on the bar stays, and what was kept is no longer the game's.
		if overridden then
			rec.game = nil
		elseif game ~= nil and not fromGame then
			bar:SetStatusBarColor(game[1], game[2], game[3], game[4])
		end
	end
end

local RunPlate

-- The border of a plate under the limit: a frame of the addon's own over the health bar, whose alpha is the step curve at the health left.
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

-- Both parts, each inside its own failure count. A part that stopped gives back what it did to every plate.
function RunPlate(frame, fromGame)
	local rec = Record(frame)
	if ns.IsStopped("nameplates") then
		pcall(ColourPlate, frame, rec, fromGame)
		pcall(BorderPlate, frame, rec)
		return
	end
	if not ns.EachPart("nameplates", PART, ColourPlate, frame, rec, fromGame) and ns.PartStopped("nameplates", PART) then
		-- The part stopped: every plate gets the game's colour back.
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

-- Follows the game's call, once, and only while a row asks. A game without it leaves the plates as they are, with a line for /flatui status.
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
	-- The game takes the plate back and colours it again for the next unit.
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

-- /flatui status ------------------------------------------------------------------------------------------

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
