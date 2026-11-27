local _, ns = ...

local KEY = "nameplates"
local RING, BORDER, BACK, FADE = "threat ring", "threat border", "threat background", "threat fade"
local HOOK = "CompactUnitFrame_UpdateCenterStatusIcon"
local RING_PX, GAP_PX = 2, 2
local FLASHES, FLASH_LOW, FLASH_SECONDS, RING_EASE = 2, 0.2, 0.15, 0.15
local BACK_SHARE = 0.3
local HEALTH_HOOK = "CompactUnitFrame_UpdateHealthColor"
local EASE_SECONDS = 0.2

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local followed, missing, subscribed = false, false, false
local easing = setmetatable({}, { __mode = "k" })
local ticker
local RunPart, Wait, OnStatusIcon

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Record(frame)
	local rec = recs[frame]
	if rec == nil then
		rec = {}
		recs[frame] = rec
	end
	return rec
end

local function Usable(frame)
	if not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

local function Bar(frame)
	local container = Usable(frame.HealthBarsContainer)
	return container and Usable(container.healthBar) or nil
end

local function Level(frame)
	return Usable(frame.PlayerLevelDiffFrame)
end

local function Styled(frame)
	local friend = frame.isFriend
	return Opt("friendly") == true or ns.IsSecret(friend) or friend ~= true
end

local function PlateOn(frame)
	return ns.Enabled(KEY) and ns.IsPlate(frame) and Styled(frame)
end

local function Off(part)
	return not ns.Enabled(KEY) or ns.PartStopped(KEY, part)
end

local function NameOnly(frame)
	local only = frame.showOnlyName
	return not ns.IsSecret(only) and only == true
end

local function Core()
	local PT = ns.PlateThreat
	if type(PT) ~= "table" or type(PT.Active) ~= "function" or type(PT.Get) ~= "function" then
		return nil
	end
	local ok, active = pcall(PT.Active)
	if ok and active == true then
		return PT
	end
	return nil
end

local function StateOf(frame)
	local PT = Core()
	if PT == nil then
		return nil
	end
	local read, state = pcall(PT.Get, frame)
	if read and type(state) == "table" then
		return state
	end
	return nil
end

local function StateColour(state)
	if state.tapped == true then
		return ns.Colour("general.reactionTapped")
	end
	local PT = ns.PlateThreat
	if type(PT) ~= "table" or type(PT.Colour) ~= "function" then
		return nil
	end
	local ok, r, g, b = pcall(PT.Colour, state)
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return nil
end

local function Marks()
	return { target = ns.PlateUnitFrame("target"), focus = ns.PlateUnitFrame("focus") }
end

local function RingPx()
	local px = Opt("threatRingPx")
	return ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or RING_PX
end

local function Gap(ring, bar)
	local thickness = ns.Get("general.thickness")
	local base = ring ~= nil and ring.pixels and ring.frame or bar
	return ns.Pixels(base, (ns.Finite(thickness) and thickness or 1) + GAP_PX)
end

local function ScreenSize(frame)
	local ok, w, h = pcall(frame.GetSize, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	if ok and okScale and ns.Finite(w) and ns.Finite(h) and ns.Finite(scale) and scale > 0 then
		return w * scale, h * scale
	end
	return nil
end

local function Sane(ring, bar)
	local rw, rh = ScreenSize(ring.frame)
	local bw, bh = ScreenSize(bar)
	if rw == nil or bw == nil or bw <= 0 or bh <= 0 then
		return true
	end
	return rw <= bw * 3 and rh <= bh * 6
end

local function Anchor(ring, bar, right)
	local d = Gap(ring, bar)
	local holder = ring.frame
	local ok = pcall(function()
		holder:SetPoint("LEFT", bar, "LEFT", -d, 0)
		holder:SetPoint("TOP", bar, "TOP", 0, d)
		holder:SetPoint("BOTTOM", bar, "BOTTOM", 0, -d)
		holder:SetPoint("RIGHT", right, "RIGHT", d, 0)
	end)
	if ok then
		ring.right, ring.d = right, d
	end
end

local function Locked(bar, level)
	return InCombatLockdown() and (ns.MaybeProtected(bar) or (level ~= nil and ns.MaybeProtected(level)))
end

function ns.PlateRingFlash(holder)
	local ok, group = pcall(function()
		local made = holder:CreateAnimationGroup()
		ns.Own[made] = true
		for index = 1, FLASHES * 2 do
			local step = made:CreateAnimation("Alpha")
			ns.Own[step] = true
			local down = index % 2 == 1
			step:SetFromAlpha(down and 1 or FLASH_LOW)
			step:SetToAlpha(down and FLASH_LOW or 1)
			step:SetDuration(FLASH_SECONDS)
			step:SetOrder(index)
		end
		return made
	end)
	return ok and type(group) == "table" and group or nil
end

function ns.PlateRingEase(holder, gone)
	local ok, appear, vanish = pcall(function()
		local come = holder:CreateAnimationGroup()
		ns.Own[come] = true
		local up = come:CreateAnimation("Alpha")
		ns.Own[up] = true
		up:SetFromAlpha(0)
		up:SetToAlpha(1)
		up:SetDuration(RING_EASE)
		local go = holder:CreateAnimationGroup()
		ns.Own[go] = true
		local down = go:CreateAnimation("Alpha")
		ns.Own[down] = true
		down:SetFromAlpha(1)
		down:SetToAlpha(0)
		down:SetDuration(RING_EASE)
		pcall(go.SetToFinalAlpha, go, true)
		go:SetScript("OnFinished", function()
			pcall(gone)
			holder:SetAlpha(1)
		end)
		return come, go
	end)
	if ok and type(appear) == "table" and type(vanish) == "table" then
		return appear, vanish
	end
	return nil, nil
end

local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

local function StopEase(ring)
	if ring.appear then
		pcall(ring.appear.Stop, ring.appear)
	end
	if ring.vanish then
		pcall(ring.vanish.Stop, ring.vanish)
	end
end

local function Make(frame, rec)
	local bar = Bar(frame)
	if bar == nil then
		return nil
	end
	local level = rec.levelBox and Level(frame) or nil
	if Locked(bar, level) then
		Wait(frame, rec)
		return nil
	end
	local holder = CreateFrame("Frame", nil, bar)
	ns.Own[holder] = true
	local ring = { frame = holder, pixels = pcall(holder.SetIgnoreParentScale, holder, true) }
	rec.ring = ring
	Anchor(ring, bar, level or bar)
	local outline = ns.Outline(holder, holder)
	ring.outline = outline
	ring.px = RingPx()
	ns.SetOutlineThickness(outline, ring.px)
	ns.KeepOutline(outline)
	ns.SetOutline(outline, false, false)
	ring.flash = ns.PlateRingFlash(holder)
	ring.appear, ring.vanish = ns.PlateRingEase(holder, function()
		if not ring.shown then
			ns.SetOutline(outline, false, false)
		end
	end)
	return ring
end

local function Place(frame, rec)
	local ring, bar = rec.ring, Bar(frame)
	if ring == nil or bar == nil then
		return
	end
	local px = RingPx()
	if ring.px ~= px then
		if InCombatLockdown() then
			Wait(frame, rec)
		else
			ns.SetOutlineThickness(ring.outline, px)
			ring.px = px
		end
	end
	local right = rec.levelBox and Level(frame) or bar
	if ring.right == right and ring.d ~= nil and math.abs(ring.d - Gap(ring, bar)) < 0.01 and Sane(ring, bar) then
		return
	end
	if InCombatLockdown() then
		Wait(frame, rec)
		return
	end
	Anchor(ring, bar, right)
end

local function HideRing(_, rec, soft)
	local ring = rec.ring
	if ring == nil then
		return
	end
	if ring.shown then
		ring.shown = nil
		if ring.flash then
			pcall(ring.flash.Stop, ring.flash)
		end
		if ring.appear then
			pcall(ring.appear.Stop, ring.appear)
		end
		if soft and ring.vanish and pcall(ring.vanish.Play, ring.vanish) then
			return
		end
		StopEase(ring)
		ns.SetOutline(ring.outline, false, false)
	elseif not soft and Playing(ring.vanish) then
		StopEase(ring)
		ns.SetOutline(ring.outline, false, false)
	end
end

local function Rings(state)
	local mode = Opt("threatGlow")
	return mode == "all" or (mode == "needs" and (state.want == "changing" or state.want == "bad"))
end

local function Flash(ring, rec, want)
	local was = rec.want
	rec.want = want
	if want == "bad" and was ~= "bad" and ring.flash and Opt("threatFlash") == true then
		StopEase(ring)
		pcall(ring.flash.Stop, ring.flash)
		return pcall(ring.flash.Play, ring.flash)
	end
	return false
end

local function Ring(frame, rec, state, place, snap)
	if place then
		Place(frame, rec)
	end
	local r, g, b
	if state ~= nil and not Off(RING) and PlateOn(frame) and not NameOnly(frame) and Rings(state) then
		r, g, b = StateColour(state)
	end
	if r == nil then
		HideRing(frame, rec, not snap)
		rec.want = state ~= nil and state.want or nil
		return
	end
	local ring = rec.ring or Make(frame, rec)
	if ring == nil then
		return
	end
	local bar = Bar(frame)
	if bar ~= nil and not Sane(ring, bar) then
		if not InCombatLockdown() then
			Anchor(ring, bar, rec.levelBox and Level(frame) or bar)
		end
		if not Sane(ring, bar) then
			HideRing(frame, rec)
			if InCombatLockdown() then
				Wait(frame, rec)
			end
			return
		end
	end
	ns.SetOutlineColour(ring.outline, r, g, b)
	local first = not ring.shown
	if first then
		ring.shown = true
		ns.SetOutline(ring.outline, true, false)
	end
	if not Flash(ring, rec, state.want) and first then
		StopEase(ring)
		if ring.appear and not snap then
			pcall(ring.appear.Play, ring.appear)
		end
	end
end

local function Ready(frame, rec)
	if rec.ring == nil and Opt("threatGlow") ~= "off" and Core() ~= nil and not Off(RING) and PlateOn(frame) then
		Make(frame, rec)
	end
	Ring(frame, rec, StateOf(frame), true)
end

function Wait(frame, rec)
	if rec.waiting then
		return
	end
	rec.waiting = true
	ns.OutOfCombat(function()
		rec.waiting = nil
		if recs[frame] == rec and not ns.Forbidden(frame) then
			RunPart(RING, Ready, frame, rec)
		end
	end)
end

local function ClearBorder(frame, rec)
	if rec.border ~= nil then
		rec.border = nil
		ns.PlateThreatBorder(frame, nil)
	end
end

local function Border(frame, rec, state)
	local r, g, b
	if state ~= nil and Opt("threatBorder") == true and not Off(BORDER) and PlateOn(frame) then
		r, g, b = StateColour(state)
	end
	if r == nil then
		ClearBorder(frame, rec)
		return
	end
	local now = rec.border
	if now ~= nil and now[1] == r and now[2] == g and now[3] == b then
		return
	end
	rec.border = ns.PlateThreatBorder(frame, r, g, b) and { r, g, b } or nil
end

local function Painted(frame, state, marks)
	if Opt("threatBar") ~= true or state.tapped == true or ns.PartStopped(KEY, "plate colours") or type(_G[HEALTH_HOOK]) ~= "function" then
		return false
	end
	if Opt("targetBar") == true then
		marks = marks or Marks()
		if frame == marks.target then
			return false
		end
	end
	return true
end

local function ClearBack(_, rec)
	local back = rec.back
	if back ~= nil then
		rec.back = nil
		ns.SetOutlineFill(back.outline, nil, nil, nil, nil)
	end
end

local function Back(frame, rec, state, marks)
	local own = owns[frame]
	local outline = type(own) == "table" and own.health or nil
	local r, g, b
	if state ~= nil and type(outline) == "table" and Opt("threatBackground") == true and not Off(BACK) and PlateOn(frame) and Painted(frame, state, marks) then
		r, g, b = StateColour(state)
	end
	if r == nil then
		ClearBack(frame, rec)
		return
	end
	r, g, b = r * BACK_SHARE, g * BACK_SHARE, b * BACK_SHARE
	local a = ns.OutlineBackdropAlpha(outline)
	local now = rec.back
	if now ~= nil and now.outline == outline and now[1] == r and now[2] == g and now[3] == b and now[4] == a then
		return
	end
	if now ~= nil and now.outline ~= outline then
		ClearBack(frame, rec)
	end
	rec.back = { r, g, b, a, outline = outline }
	ns.SetOutlineFill(outline, r, g, b, a)
end

local function ReadAlpha(frame)
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and ns.Finite(alpha) then
		return alpha
	end
	return 1
end

local function Overwritten(frame, fade)
	local ok, now = pcall(frame.GetAlpha, frame)
	return fade.sent ~= nil and ok and ns.Finite(now) and math.abs(now - fade.sent) > 0.01
end

local function Write(frame, fade, alpha)
	if not pcall(frame.SetAlpha, frame, alpha) then
		error("the game refused the opacity of a nameplate", 0)
	end
	fade.sent = alpha
end

local Tick

local function Release(frame, rec, ease)
	local fade = rec.fade
	if fade == nil then
		return
	end
	if fade.sent == nil or Overwritten(frame, fade) then
		rec.fade, easing[frame] = nil, nil
		return
	end
	if ease then
		fade.back = true
		easing[frame] = rec
		Tick(true)
		return
	end
	rec.fade, easing[frame] = nil, nil
	pcall(frame.SetAlpha, frame, fade.orig)
end

local function Step(frame, rec, elapsed)
	local fade = rec.fade
	if fade == nil or easing[frame] ~= rec or ns.Forbidden(frame) then
		easing[frame] = nil
		return
	end
	if Overwritten(frame, fade) then
		easing[frame] = nil
		if fade.back then
			rec.fade = nil
		end
		return
	end
	local goal = fade.back and fade.orig or fade.goal
	local from = fade.sent or goal
	local step = (ns.Finite(elapsed) and elapsed > 0 and elapsed or 0) / EASE_SECONDS
	local value = goal
	if math.abs(goal - from) > step then
		value = from + (goal > from and step or -step)
	end
	Write(frame, fade, value)
	if value == goal then
		easing[frame] = nil
		if fade.back then
			rec.fade = nil
		end
	end
end

local function Install()
	if followed or missing then
		return
	end
	if ns.FollowGlobal(HOOK, OnStatusIcon) then
		followed = true
	else
		missing = true
	end
end

local function FadeRow(state)
	if state.want == "good" or state.want == "offtank" then
		if state.tank ~= true and Opt("threatFadeSame") == false then
			return "threatFadeDamage"
		end
		return "threatFadeAlpha"
	elseif state.want == "changing" then
		return "threatFadeChanging"
	end
	return nil
end

local function Marked(frame)
	local unit = frame.unit
	if ns.IsSecret(unit) or type(unit) ~= "string" or type(GetRaidTargetIndex) ~= "function" then
		return false
	end
	local ok, index = pcall(GetRaidTargetIndex, unit)
	return ok and (ns.IsSecret(index) or (ns.Finite(index) and index >= 1))
end

local function FadeAlpha(frame, state, marks)
	if state == nil or Opt("threatFade") ~= true or Off(FADE) or not PlateOn(frame) then
		return nil
	end
	local row = FadeRow(state)
	local percent = row and Opt(row)
	if not ns.Finite(percent) or percent >= 100 then
		return nil
	end
	marks = marks or Marks()
	if frame == marks.target or frame == marks.focus then
		return nil
	end
	if Opt("threatMarked") == true and Marked(frame) then
		return nil
	end
	return math.max(percent, 0) / 100
end

local function Fade(frame, rec, state, marks, fromGame, snap)
	local alpha = FadeAlpha(frame, state, marks)
	if alpha == nil then
		Release(frame, rec, not (fromGame or snap))
		return
	end
	Install()
	local fade = rec.fade
	if fade == nil then
		fade = { orig = ReadAlpha(frame) }
		rec.fade = fade
	elseif fromGame then
		fade.orig, fade.sent = ReadAlpha(frame), nil
	end
	fade.goal, fade.back = alpha, nil
	if fade.sent == alpha then
		easing[frame] = nil
		return
	end
	if fromGame or snap then
		easing[frame] = nil
		Write(frame, fade, alpha)
		return
	end
	if fade.sent == nil then
		fade.sent = fade.orig
	end
	easing[frame] = rec
	Tick(true)
end

local function OnTick(_, elapsed)
	for frame, rec in pairs(easing) do
		RunPart(FADE, Step, frame, rec, elapsed)
	end
	if next(easing) == nil then
		Tick(false)
	end
end

function Tick(on)
	if on and ticker == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			for plate, rec in pairs(easing) do
				easing[plate] = nil
				local fade = rec.fade
				if fade then
					pcall(Write, plate, fade, fade.back and fade.orig or fade.goal)
					if fade.back then
						rec.fade = nil
					end
				end
			end
			return
		end
		ns.Own[frame] = true
		ticker = frame
	end
	if ticker then
		ticker:SetScript("OnUpdate", on and OnTick or nil)
	end
end

function OnStatusIcon(frame)
	if frame == nil or ns.IsSecret(frame) then
		return
	end
	local rec = recs[frame]
	if rec ~= nil and rec.fade ~= nil then
		RunPart(FADE, Fade, frame, rec, StateOf(frame), nil, true)
	end
end

local PUT_BACK = { [RING] = HideRing, [BORDER] = ClearBorder, [BACK] = ClearBack, [FADE] = Release }

function RunPart(part, fn, frame, rec, ...)
	local back = PUT_BACK[part]
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(back, frame, rec)
	elseif not ns.EachPart(KEY, part, fn, frame, rec, ...) and ns.PartStopped(KEY, part) then
		for other, kept in pairs(recs) do
			pcall(back, other, kept)
		end
	end
end

local function Draw(frame, rec, state, marks, place, snap)
	RunPart(RING, Ring, frame, rec, state, place, snap)
	RunPart(BORDER, Border, frame, rec, state)
	RunPart(BACK, Back, frame, rec, state, marks)
	RunPart(FADE, Fade, frame, rec, state, marks, false, snap)
end

local function DrawAll(place)
	local marks, seen = Marks(), {}
	ns.EachPlate(function(frame)
		seen[frame] = true
		local state, rec = StateOf(frame), recs[frame]
		if rec ~= nil or state ~= nil then
			Draw(frame, rec or Record(frame), state, marks, place, true)
		end
	end)
	for frame, rec in pairs(recs) do
		if not seen[frame] and not ns.Forbidden(frame) then
			Draw(frame, rec, nil, marks, nil, true)
		end
	end
end

local function FadeAll()
	if Opt("threatFade") ~= true then
		return
	end
	local marks = Marks()
	ns.EachPlate(function(frame)
		local state, rec = StateOf(frame), recs[frame]
		if rec ~= nil or state ~= nil then
			RunPart(FADE, Fade, frame, rec or Record(frame), state, marks)
		end
	end)
end

local function BackAll()
	if Opt("threatBackground") ~= true or Opt("targetBar") ~= true then
		return
	end
	local marks = Marks()
	ns.EachPlate(function(frame)
		local state, rec = StateOf(frame), recs[frame]
		if rec ~= nil or state ~= nil then
			RunPart(BACK, Back, frame, rec or Record(frame), state, marks)
		end
	end)
end

local function OnChange(frame, state)
	if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" or ns.Forbidden(frame) then
		return
	end
	if type(state) ~= "table" then
		state = nil
	end
	local rec = recs[frame]
	if rec == nil and state == nil then
		return
	end
	Draw(frame, rec or Record(frame), state)
end

local function Subscribe()
	if subscribed then
		return
	end
	local PT = ns.PlateThreat
	if type(PT) == "table" and type(PT.OnChange) == "function" then
		subscribed = (pcall(PT.OnChange, OnChange))
	end
end

function ns.PlateRingShown(frame)
	local rec = frame ~= nil and recs[frame] or nil
	return type(rec) == "table" and type(rec.ring) == "table" and rec.ring.shown == true
end

local extra = ns.PlateExtra
extra.layout[#extra.layout + 1] = function(frame, own)
	if type(own) == "table" then
		owns[frame] = own
	end
	local box = type(own) == "table" and own.levelBox == true
	local rec = recs[frame]
	if rec == nil then
		if not box then
			return
		end
		rec = Record(frame)
	end
	rec.levelBox = box
	local state = StateOf(frame)
	if rec.ring ~= nil or state ~= nil then
		RunPart(RING, Ring, frame, rec, state, true)
	end
end
extra.show[#extra.show + 1] = function(frame, own)
	Subscribe()
	if type(own) == "table" then
		owns[frame] = own
	end
	local state, rec = StateOf(frame), recs[frame]
	if rec == nil and state == nil then
		return
	end
	rec = rec or Record(frame)
	if type(own) == "table" then
		rec.levelBox = own.levelBox == true
	end
	Draw(frame, rec, state)
end
extra.leave[#extra.leave + 1] = function(frame)
	local rec = recs[frame]
	if rec ~= nil then
		Draw(frame, rec, nil, nil, nil, true)
	end
end
extra.refresh[#extra.refresh + 1] = function()
	Subscribe()
	DrawAll(true)
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	FadeAll()
	BackAll()
end)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", FadeAll)
ns.AddEvent(KEY, "RAID_TARGET_UPDATE", function()
	if Opt("threatMarked") == true then
		FadeAll()
	end
end)
