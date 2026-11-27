local _, ns = ...

local KEY = "nameplates"
local EXTRA = ns.PlateExtra
if type(EXTRA) ~= "table" then
	return
end

local PART = "threat slipping"
local RINGS = { 0.85, 0.55, 0.33, 0.18, 0.08 }
local GAP_PX, RING_PX = 2, 2
local PULSE = { slipping = 0.75, lost = 0.3 }
local BOB = { slipping = 0.6, lost = 0.3 }
local PULSE_LOW, BOB_PX = 0.25, 3
local FADE_IN, FADE_OUT, FADE_BACK = 0.15, 0.2, 0.45
local ARROW, ARROW_ROW, ARROW_GAP, LEVEL = { 14, 11, 8, 5, 2 }, 2, 3, 22
local SHADE = { 0, 0, 0, 0.8 }
local KINDS = { bad = "lost", changing = "slipping" }
local SAMPLE_KINDS = { threatBad = "lost", threatTransition = "slipping" }
local GROW_SECONDS, GROW_MIN, GROW_MAX, GROW_DEFAULT = 0.2, 100, 200, 150
local LOOK_SECONDS, SLIP_DEFAULT, SLIP_MIN, PULL_SHARE = 0.2, 80, 50, 110
local COPY_LEVEL, SAMPLE_RISE = 8000, 40
local NAME_GAP, MARK_GAP, MARK_SHARE, FONT_PX = 2, 2, 1.5, 12
local FONT, WHITE = "SystemFont_NamePlate", "Interface\\Buttons\\WHITE8X8"
local RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local JUSTIFY = { LEFT = true, CENTER = true, RIGHT = true }

local recs = setmetatable({}, { __mode = "k" })
local owns = setmetatable({}, { __mode = "k" })
local moving = {}
local S = { waited = 0, watch = false, wait = 0, running = false }
local driver
local Draw

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Call(frame, method, ...)
	local fn = type(frame) == "table" and frame[method] or nil
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, frame, ...)
end

local function Read(frame, method)
	local ok, value = Call(frame, method)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Own(object)
	ns.Own[object] = true
	return object
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

local function NameOnly(frame)
	local only = frame.showOnlyName
	return not ns.IsSecret(only) and only == true
end

local function Styled(frame)
	local friend = frame.isFriend
	return Opt("friendly") == true or ns.IsSecret(friend) or friend ~= true
end

local function Locked(frame)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(frame))
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
	local ok, state = pcall(PT.Get, frame)
	if ok and type(state) == "table" then
		return state
	end
	return nil
end

local function Kind(state)
	if type(state) ~= "table" or state.tank ~= true or state.pet == true or state.tapped == true then
		return nil
	end
	return KINDS[state.want]
end

local function Eligible(state)
	return type(state) == "table" and state.tank == true and state.pet ~= true and state.tapped ~= true and state.want ~= "offtank"
end

local function Colour(state)
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

local function On()
	return ns.Enabled(KEY) and Opt("threat") == true and Opt("threatSlipping") == true and not ns.PartStopped(KEY, PART)
end

local function Wanted(frame)
	return On() and ns.IsPlate(frame) and Styled(frame) and not NameOnly(frame)
end

local function Base()
	local thickness = ns.Get("general.thickness")
	local base = (ns.Finite(thickness) and thickness or 1) + GAP_PX
	if Opt("threatGlow") ~= "off" then
		local px = Opt("threatRingPx")
		base = base + (ns.Finite(px) and px >= 1 and math.floor(px + 0.5) or RING_PX)
	end
	return base
end

local function Full()
	local percent = Opt("threatSlipScale")
	percent = ns.Finite(percent) and math.max(GROW_MIN, math.min(GROW_MAX, percent)) or GROW_DEFAULT
	return percent / 100
end

local function SlipAt()
	local value = ns.Get("threat.slipAt")
	return ns.Finite(value) and math.max(SLIP_MIN, math.min(100, value)) or SLIP_DEFAULT
end

local function Group(region, looping)
	local group = Own(region:CreateAnimationGroup())
	if looping then
		group:SetLooping(looping)
	end
	return group
end

local function Playing(group)
	if not group then
		return false
	end
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

local function Animate(cue)
	local holder, glow, arrow = cue.holder, cue.glow, cue.arrow
	local come = Group(holder)
	local rise = Own(come:CreateAnimation("Alpha"))
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(FADE_IN)
	local go = Group(holder)
	local fall = Own(go:CreateAnimation("Alpha"))
	fall:SetFromAlpha(1)
	fall:SetToAlpha(0)
	fall:SetDuration(FADE_OUT)
	pcall(go.SetToFinalAlpha, go, true)
	go:SetScript("OnFinished", function()
		if not cue.on then
			holder:Hide()
			if cue.pulse then
				pcall(cue.pulse.Stop, cue.pulse)
			end
			if cue.bob then
				pcall(cue.bob.Stop, cue.bob)
			end
		end
		holder:SetAlpha(1)
	end)
	local back = Group(holder)
	local dim = Own(back:CreateAnimation("Alpha"))
	dim:SetFromAlpha(1)
	dim:SetToAlpha(0)
	dim:SetDuration(FADE_BACK)
	pcall(dim.SetSmoothing, dim, "OUT")
	pcall(back.SetToFinalAlpha, back, true)
	back:SetScript("OnFinished", function()
		if not cue.on then
			holder:Hide()
			if cue.pulse then
				pcall(cue.pulse.Stop, cue.pulse)
			end
			if cue.bob then
				pcall(cue.bob.Stop, cue.bob)
			end
		end
		holder:SetAlpha(1)
		arrow:SetAlpha(1)
	end)
	local pulse = Group(glow, "BOUNCE")
	local fade = Own(pulse:CreateAnimation("Alpha"))
	fade:SetFromAlpha(1)
	fade:SetToAlpha(PULSE_LOW)
	fade:SetDuration(PULSE.slipping)
	pcall(fade.SetSmoothing, fade, "IN_OUT")
	local bob = Group(arrow, "BOUNCE")
	local move = Own(bob:CreateAnimation("Translation"))
	move:SetOffset(0, -BOB_PX)
	move:SetDuration(BOB.slipping)
	pcall(move.SetSmoothing, move, "IN_OUT")
	cue.come, cue.go, cue.back, cue.pulse, cue.fade, cue.bob, cue.move = come, go, back, pulse, fade, bob, move
end

local function Build(parent)
	local holder = Own(CreateFrame("Frame", nil, parent))
	holder:SetAllPoints(parent)
	holder:Hide()
	local glow = Own(CreateFrame("Frame", nil, holder))
	local arrow = Own(CreateFrame("Frame", nil, holder))
	local cue = { holder = holder, glow = glow, arrow = arrow, rings = {}, shape = {}, shade = {} }
	for index = 1, #RINGS do
		local ring = {}
		for side = 1, 4 do
			ring[side] = Own(glow:CreateTexture(nil, "ARTWORK"))
		end
		cue.rings[index] = ring
	end
	cue.width, cue.height = ARROW[1] + 1, #ARROW * ARROW_ROW + 1
	arrow:SetSize(cue.width, cue.height)
	for index, width in ipairs(ARROW) do
		local y = -(index - 1) * ARROW_ROW
		local shade = Own(arrow:CreateTexture(nil, "BORDER"))
		shade:SetColorTexture(SHADE[1], SHADE[2], SHADE[3], SHADE[4])
		shade:SetSize(width, ARROW_ROW)
		shade:SetPoint("TOP", arrow, "TOP", 1, y - 1)
		local piece = Own(arrow:CreateTexture(nil, "ARTWORK"))
		piece:SetSize(width, ARROW_ROW)
		piece:SetPoint("TOP", arrow, "TOP", 0, y)
		cue.shade[index], cue.shape[index] = shade, piece
	end
	pcall(Animate, cue)
	return cue
end

local function Line(line, glow, a, b, ax, ay, bx, by, w, h)
	line:ClearAllPoints()
	line:SetPoint(a, glow, a, ax, ay)
	line:SetPoint(b, glow, b, bx, by)
	if w then
		line:SetWidth(w)
	else
		line:SetHeight(h)
	end
end

local function Lines(cue)
	local glow = cue.glow
	local unit, base = ns.Pixels(glow, 1), cue.base or Base()
	for index, ring in ipairs(cue.rings) do
		local d = (base + index - 1) * unit
		Line(ring[1], glow, "TOPLEFT", "TOPRIGHT", -d, d, d, d, nil, unit)
		Line(ring[2], glow, "BOTTOMLEFT", "BOTTOMRIGHT", -d, -d, d, -d, nil, unit)
		Line(ring[3], glow, "TOPLEFT", "BOTTOMLEFT", -d, d - unit, -d, -d + unit, unit)
		Line(ring[4], glow, "TOPRIGHT", "BOTTOMRIGHT", d, d - unit, d, -d + unit, unit)
	end
	cue.unit = unit
end

local function Ring(cue, bar, right)
	local glow = cue.glow
	glow:ClearAllPoints()
	glow:SetPoint("LEFT", bar, "LEFT", 0, 0)
	glow:SetPoint("TOP", bar, "TOP", 0, 0)
	glow:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
	glow:SetPoint("RIGHT", right or bar, "RIGHT", 0, 0)
	cue.base, cue.bar, cue.right = Base(), bar, right or bar
	Lines(cue)
end

local function Paint(cue, kind, r, g, b)
	if cue.r ~= r or cue.g ~= g or cue.b ~= b then
		cue.r, cue.g, cue.b = r, g, b
		for index, ring in ipairs(cue.rings) do
			for _, line in ipairs(ring) do
				line:SetColorTexture(r, g, b, RINGS[index])
			end
		end
		for _, piece in ipairs(cue.shape) do
			piece:SetColorTexture(r, g, b, 1)
		end
	end
	if cue.kind ~= kind then
		cue.kind = kind
		if cue.fade then
			pcall(cue.pulse.Stop, cue.pulse)
			pcall(cue.fade.SetDuration, cue.fade, PULSE[kind] or PULSE.slipping)
		end
		if cue.move then
			pcall(cue.bob.Stop, cue.bob)
			pcall(cue.move.SetDuration, cue.move, BOB[kind] or BOB.slipping)
		end
		cue.moving = nil
	end
end

local function Moving(cue, on)
	on = on and true or false
	if cue.moving == on then
		return
	end
	cue.moving = on
	for _, group in ipairs({ cue.pulse or false, cue.bob or false }) do
		if group then
			if on then
				pcall(group.Play, group)
			else
				pcall(group.Stop, group)
			end
		end
	end
end

local function Calm(cue)
	local back = cue.back
	local playing = back ~= nil and back:IsPlaying()
	if playing then
		pcall(back.Stop, back)
	end
	cue.arrow:SetAlpha(1)
	return playing
end

local function Show(cue, snap, still)
	cue.still = still
	if not cue.on then
		cue.on = true
		Calm(cue)
		if cue.go then
			pcall(cue.go.Stop, cue.go)
		end
		cue.holder:SetAlpha(1)
		cue.holder:Show()
		if cue.come and not snap and not still then
			pcall(cue.come.Stop, cue.come)
			pcall(cue.come.Play, cue.come)
		end
	end
	Moving(cue, not still)
end

local function Hide(cue, snap)
	if not cue.on then
		local going = cue.go and cue.go:IsPlaying()
		if snap and (Calm(cue) or going) then
			if cue.go then
				pcall(cue.go.Stop, cue.go)
			end
			cue.holder:Hide()
			cue.holder:SetAlpha(1)
			Moving(cue, false)
		end
		return
	end
	cue.on = false
	if cue.come then
		pcall(cue.come.Stop, cue.come)
	end
	if not snap and cue.go and pcall(cue.go.Play, cue.go) then
		cue.moving = nil
		return
	end
	cue.holder:Hide()
	cue.holder:SetAlpha(1)
	Moving(cue, false)
end

local function Record(frame)
	local rec = recs[frame]
	if rec == nil then
		rec = {}
		recs[frame] = rec
	end
	return rec
end

local function Above(frame)
	if type(ns.PlateQuestAbove) == "function" then
		local ok, mark = pcall(ns.PlateQuestAbove, frame)
		if ok and type(mark) == "table" then
			return mark
		end
	end
	local icon = type(ns.PlateOverpowerIcon) == "function" and select(2, pcall(ns.PlateOverpowerIcon, frame)) or nil
	if type(icon) == "table" then
		return icon
	end
	if type(ns.PlateThreatTexts) == "function" then
		local ok, value, side = pcall(ns.PlateThreatTexts, frame)
		if ok and type(value) == "table" and side == "above" then
			return value
		end
	end
	if type(ns.PlateDebuffTop) == "function" then
		local ok, guide = pcall(ns.PlateDebuffTop, frame)
		if ok and type(guide) == "table" then
			return guide
		end
	end
	local name = Usable(frame.name)
	if name and (type(ns.PlateNameShown) ~= "function" or ns.PlateNameShown(frame) ~= false) then
		local ok, shown = pcall(name.IsShown, name)
		if ok and shown == true then
			return name
		end
	end
	return Bar(frame)
end

local Prepare

local function Wait(frame, rec)
	if rec.waiting then
		return
	end
	rec.waiting = true
	S.waited = S.waited + 1
	ns.OutOfCombat(function()
		rec.waiting = nil
		if recs[frame] == rec and not ns.Forbidden(frame) then
			ns.EachPart(KEY, PART, Prepare, frame)
			Draw(frame, StateOf(frame), true)
		end
	end)
end

local function Place(frame, rec, cue)
	local bar = Bar(frame)
	if bar == nil then
		return false
	end
	local own = owns[frame]
	local right = type(own) == "table" and own.levelBox == true and Level(frame) or bar
	local above = Above(frame)
	local unit = ns.Pixels(cue.glow, 1)
	if cue.bar == bar and cue.right == right and cue.base == Base() and cue.unit ~= nil and math.abs(cue.unit - unit) < 0.001 and rec.above == above then
		return true
	end
	if Locked(frame) then
		Wait(frame, rec)
		return cue.bar ~= nil
	end
	Ring(cue, bar, right)
	if above ~= nil then
		cue.arrow:ClearAllPoints()
		cue.arrow:SetPoint("BOTTOM", above, "TOP", 0, ARROW_GAP)
	end
	rec.above = above
	local level = Read(frame, "GetFrameLevel")
	if ns.Finite(level) and Call(cue.holder, "SetFrameLevel", level + LEVEL) then
		cue.level = level + LEVEL
	end
	return true
end

local function Tank()
	local PT = Core()
	if PT == nil or type(PT.Role) ~= "function" then
		return false
	end
	local ok, role = pcall(PT.Role)
	return ok and role == "tank"
end

function Prepare(frame)
	local rec = recs[frame]
	if (rec and rec.cue) or Locked(frame) or not Wanted(frame) or not Tank() then
		return
	end
	local unit = frame.unit
	if ns.IsSecret(unit) or type(unit) ~= "string" then
		return
	end
	local ok, enemy = pcall(UnitCanAttack, "player", unit)
	if not ok or ns.IsSecret(enemy) or enemy ~= true then
		return
	end
	rec = rec or Record(frame)
	local cue = Build(frame)
	rec.cue = cue
	Place(frame, rec, cue)
end

local function Now()
	return type(GetTime) == "function" and GetTime() or nil
end

local function Channel()
	return { now = 1, from = 1, to = 1, start = 0 }
end

local function Aim(channel, to, snap)
	if snap then
		channel.now, channel.from, channel.to = to, to, to
	elseif channel.to ~= to then
		channel.from, channel.to, channel.start = channel.now, to, Now()
	end
end

local function Ease(channel, now)
	if channel.now == channel.to then
		return true
	end
	local share = ns.Finite(now) and ns.Finite(channel.start) and (now - channel.start) / GROW_SECONDS or 1
	if share >= 1 then
		channel.now = channel.to
		return true
	end
	share = math.max(0, share)
	channel.now = channel.from + (channel.to - channel.from) * share * share * (3 - 2 * share)
	return false
end

local function Members()
	local M = ns.ThreatMobs
	if type(M) ~= "table" or type(M.Members) ~= "function" or type(M.Judge) ~= "function" then
		return nil
	end
	local ok, list = pcall(M.Members)
	if ok and type(list) == "table" and #list > 1 then
		return list
	end
	return nil
end

local function Judge(frame, members)
	local unit = frame.unit
	if members == nil or ns.IsSecret(unit) or type(unit) ~= "string" then
		return nil
	end
	local ok, mob = pcall(ns.ThreatMobs.Judge, unit, members)
	if not ok or type(mob) ~= "table" or not Plain(mob.state, "string") then
		return nil
	end
	local share = mob.share
	if mob.state == "slipping" and ns.Finite(share) then
		local slip = SlipAt()
		return "slipping", math.max(0, math.min(1, (share - slip) / (PULL_SHARE - slip)))
	end
	return mob.state, nil
end

local function Goal(kind, judged, t)
	local full = Full()
	local goal
	if judged == "lost" then
		goal = full
	elseif judged == "slipping" and t then
		goal = 1 + (full - 1) * t
	elseif judged == "held" and kind ~= "lost" then
		goal = kind and 1 or nil
	elseif kind == "lost" then
		goal = full
	elseif kind == "slipping" then
		goal = 1 + (full - 1) / 2
	end
	return goal and math.floor(goal * 100 + 0.5) / 100 or nil
end

local function CopyColour(state, kind, judged)
	if kind then
		local r, g, b = Colour(state)
		if r then
			return r, g, b
		end
	end
	return ns.Colour(KEY .. "." .. (judged == "lost" and "threatBad" or "threatTransition"))
end

local function StrataOf(frame)
	local best, rank = nil, 0
	for _, region in ipairs({ frame, Level(frame) or false }) do
		if region then
			local strata = Read(region, "GetFrameStrata")
			local at = Plain(strata, "string") and STRATA[strata] or nil
			if at and at > rank then
				best, rank = strata, at
			end
		end
	end
	return best or "HIGH"
end

local function Layer(copy, strata, level)
	if copy.strata == strata and copy.level == level then
		return
	end
	copy.strata, copy.level = strata, level
	local cue, outline = copy.cue, copy.outline
	local list = { copy.frame, copy.bar, outline and outline.holder or false, copy.words, cue.holder, cue.glow, cue.arrow }
	local rise = { 0, 1, 2, 3, 5, 6, 6 }
	for index, region in ipairs(list) do
		if region then
			Call(region, "SetFrameStrata", strata)
			Call(region, "SetFrameLevel", level + rise[index])
		end
	end
end

local function NoMouse(frame)
	Call(frame, "EnableMouse", false)
	return frame
end

local function NewCopy(parent, strata, level)
	local frame = NoMouse(Own(CreateFrame("Frame", nil, parent)))
	frame:Hide()
	Call(frame, "SetFrameStrata", strata)
	Call(frame, "SetFrameLevel", level)
	frame:SetSize(1, 1)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	local bar = NoMouse(Own(CreateFrame("StatusBar", nil, frame)))
	bar:SetAllPoints(frame)
	bar:SetStatusBarTexture(WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	local words = NoMouse(Own(CreateFrame("Frame", nil, frame)))
	words:SetAllPoints(frame)
	local copy = { frame = frame, bar = bar, words = words, parent = parent, at = Channel(), w = 1, h = 1, scale = 1, on = false }
	copy.name = ns.OwnText(words, "OVERLAY", FONT)
	if copy.name then
		copy.name:SetWordWrap(false)
	end
	copy.mark = Own(words:CreateTexture(nil, "OVERLAY"))
	copy.mark:SetTexture(RAID)
	copy.mark:Hide()
	local outline = ns.Outline(frame, bar)
	copy.outline = outline and ns.SetOutlineArea(outline, KEY) or nil
	ns.SetOutline(copy.outline, true, true)
	if copy.outline and copy.outline.holder then
		NoMouse(copy.outline.holder)
	end
	copy.cue = Build(frame)
	NoMouse(copy.cue.holder)
	NoMouse(copy.cue.glow)
	NoMouse(copy.cue.arrow)
	Ring(copy.cue, bar, bar)
	Layer(copy, strata, level)
	return copy
end

local function Size(copy, w, h)
	if math.abs(copy.w - w) > 0.01 or math.abs(copy.h - h) > 0.01 then
		copy.w, copy.h = w, h
		copy.frame:SetSize(w, h)
	end
end

local function Cell(texture, index)
	if type(texture.SetSpriteSheetCell) == "function" then
		return (pcall(texture.SetSpriteSheetCell, texture, index, 4, 4))
	end
	if ns.Finite(index) then
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		return (pcall(texture.SetTexCoord, texture, column / 4, (column + 1) / 4, row / 4, (row + 1) / 4))
	end
	return false
end

local function Font(copy, spec)
	local name = copy.name
	local key = spec.file and (spec.file .. "|" .. math.floor(spec.size * 100 + 0.5) .. "|" .. spec.flags) or "game"
	if copy.font == key then
		return
	end
	if spec.file and pcall(name.SetFont, name, spec.file, spec.size, spec.flags) then
		copy.font = key
	elseif copy.font ~= "game" then
		pcall(name.SetFontObject, name, FONT)
		copy.font = "game"
	end
end

local function Words(copy, spec, w, h)
	local name = copy.name
	if name == nil then
		return nil
	end
	if spec == nil then
		name:Hide()
		return nil
	end
	Font(copy, spec)
	name:ClearAllPoints()
	name:SetPoint(spec.point or "BOTTOM", copy.frame, spec.rel or "TOP", spec.x or 0, spec.y or NAME_GAP)
	name:SetWidth(math.max(1, spec.width or w))
	name:SetJustifyH(spec.justify or "CENTER")
	name:SetTextColor(spec.r or 1, spec.g or 1, spec.b or 1, 1)
	if not pcall(name.SetText, name, spec.text) then
		name:SetText("")
	end
	name:Show()
	local bottom = spec.bottom or (h / 2 + NAME_GAP)
	local top = spec.top or (bottom + (spec.size or FONT_PX))
	local half = (spec.width or w) / 2
	return top, spec.left or -half, spec.right or half, bottom >= h / 2 - 1
end

local function Lay(copy, L)
	Size(copy, L.w, L.h)
	local w, h = L.w, L.h
	local left, right, top = -w / 2, w / 2, h / 2
	local nameTop, nameLeft, nameRight, above = Words(copy, L.name, w, h)
	if nameTop then
		top, left, right = math.max(top, nameTop), math.min(left, nameLeft), math.max(right, nameRight)
	end
	local cue = copy.cue
	if cue.base ~= Base() then
		Ring(cue, copy.bar, copy.bar)
	end
	local to = above and copy.name or copy.frame
	if copy.arrowTo ~= to then
		copy.arrowTo = to
		cue.arrow:ClearAllPoints()
		cue.arrow:SetPoint("BOTTOM", to, "TOP", 0, ARROW_GAP)
	end
	top = math.max(top, (above and nameTop or h / 2) + ARROW_GAP + cue.height)
	local mark, spec = copy.mark, L.mark
	if spec and Cell(mark, spec.index) then
		local size = spec.size or h * MARK_SHARE
		local x = spec.x or -MARK_GAP
		mark:ClearAllPoints()
		mark:SetPoint(spec.point or "RIGHT", copy.frame, spec.rel or "LEFT", x, spec.y or 0)
		mark:SetSize(size, size)
		mark:Show()
		left = math.min(left, spec.left or (-w / 2 + x - size))
	else
		mark:Hide()
	end
	copy.ext = { l = left, r = right, b = -h / 2, t = top }
end

local function Tint(copy, r, g, b)
	local file = ns.BarTexture(Opt("healthTexture")) or WHITE
	if copy.file ~= file then
		copy.file, copy.r = file, nil
		copy.bar:SetStatusBarTexture(file)
	end
	if copy.r ~= r or copy.g ~= g or copy.b ~= b then
		copy.r, copy.g, copy.b = r, g, b
		copy.bar:SetStatusBarColor(r, g, b, 1)
	end
end

local function Border(copy)
	local outline = copy.outline
	if outline == nil then
		return
	end
	local owner = copy.live and copy.owner or nil
	local r, g, b, px
	if owner ~= nil and ns.Enabled(KEY) and Opt("health") == true and Opt("target") == true and type(ns.PlateUnitFrame) == "function" then
		if owner == ns.PlateUnitFrame("target") then
			r, g, b = ns.Colour(KEY .. ".targetColour")
		elseif owner == ns.PlateUnitFrame("focus") then
			r, g, b = ns.Colour(KEY .. ".focusColour")
		end
		if r ~= nil then
			px = Opt("targetThickness")
			px = ns.Finite(px) and px or nil
		end
	end
	ns.SetOutlineColour(outline, r, g, b)
	ns.SetOutlineThickness(outline, px)
end

local function Health(copy)
	local unit, bar = copy.unit, copy.bar
	if not (ns.IsSecret(unit) or type(unit) == "string") then
		return
	end
	local ok, most = pcall(UnitHealthMax, unit)
	if ok then
		pcall(bar.SetMinMaxValues, bar, 0, most)
	end
	local okNow, now = pcall(UnitHealth, unit)
	if okNow then
		pcall(bar.SetValue, bar, now)
	end
end

local function Screen(region, scale)
	if region == nil then
		return nil
	end
	local ok, x, y = Call(region, "GetCenter")
	local okSize, w, h = Call(region, "GetSize")
	local own = Read(region, "GetEffectiveScale")
	scale = ns.Finite(own) and own > 0 and own or scale
	if ok and okSize and ns.Finite(x) and ns.Finite(y) and ns.Finite(w) and ns.Finite(h) and ns.Finite(scale) and scale > 0 then
		return x * scale, y * scale, w * scale, h * scale, scale
	end
	return nil
end

local function FontOf(spec, name, scale)
	local ok, file, size, flags = Call(name, "GetFont")
	local plainFlags = not ns.IsSecret(flags) and (flags == nil or type(flags) == "string")
	if ok and Plain(file, "string") and ns.Finite(size) and size > 0 and plainFlags then
		spec.file, spec.size, spec.flags = file, size * scale, flags or ""
	end
	local okColour, r, g, b = Call(name, "GetTextColor")
	if okColour and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		spec.r, spec.g, spec.b = r, g, b
	end
end

local function LiveText(name, unit, bx, by, base, bs)
	local spec = { justify = "CENTER" }
	local x, y, w, h, scale = Screen(name, bs)
	if x then
		spec.point, spec.rel, spec.x, spec.y, spec.width = "CENTER", "CENTER", (x - bx) / base, (y - by) / base, w / base
		spec.bottom, spec.top = spec.y - h / base / 2, spec.y + h / base / 2
		spec.left, spec.right = spec.x - spec.width / 2, spec.x + spec.width / 2
	end
	FontOf(spec, name, (scale or bs) / base)
	local justify = Read(name, "GetJustifyH")
	if Plain(justify, "string") and JUSTIFY[justify] then
		spec.justify = justify
	end
	local ok, text = pcall(UnitName, unit)
	if ok then
		spec.text = text
	end
	return spec
end

local function LiveMark(frame, unit, bx, by, base, bs)
	if Opt("raidMarker") == false then
		return nil
	end
	local ok, index = pcall(GetRaidTargetIndex, unit)
	if not ok or not (ns.IsSecret(index) or (ns.Finite(index) and index >= 1 and index <= 8)) then
		return nil
	end
	local spec = { index = index }
	local holder = Usable(frame.RaidTargetFrame)
	local icon = holder and Usable(holder.RaidTargetIcon)
	local x, y, mw, mh
	if icon and Read(icon, "IsVisible") == true then
		x, y, mw, mh = Screen(icon, bs)
	end
	if x and mw > 0 and mh > 0 then
		local size = math.max(mw, mh) / base
		spec.point, spec.rel, spec.x, spec.y, spec.size = "CENTER", "CENTER", (x - bx) / base, (y - by) / base, size
		spec.left = spec.x - size / 2
	end
	return spec
end

local function LiveLayout(frame)
	local unit = frame.unit
	if not (ns.IsSecret(unit) or type(unit) == "string") then
		return nil
	end
	local bar = Bar(frame)
	local bx, by, bw, bh, bs = Screen(bar)
	local base = Read(UIParent, "GetEffectiveScale")
	if bx == nil or not ns.Finite(base) or base <= 0 or bw <= 0 or bh <= 0 then
		return nil
	end
	local L = { unit = unit, source = bar, w = bw / base, h = bh / base }
	local name = Usable(frame.name)
	if name and Read(name, "IsShown") == true and (type(ns.PlateNameShown) ~= "function" or ns.PlateNameShown(frame) ~= false) then
		L.name = LiveText(name, unit, bx, by, base, bs)
	end
	L.mark = LiveMark(frame, unit, bx, by, base, bs)
	return L
end

local function Follow(copy, f)
	local frame, parent = copy.owner, copy.parent
	if Read(frame, "IsVisible") ~= true or Read(parent, "IsVisible") ~= true then
		return false
	end
	local x, y, w, h = Screen(copy.source)
	local base = Read(parent, "GetEffectiveScale")
	if x == nil or not ns.Finite(base) or base <= 0 or w <= 0 or h <= 0 then
		return false
	end
	Size(copy, w / base, h / base)
	x, y = x / base / f, y / base / f
	if copy.x == nil or math.abs(copy.x - x) > 0.01 or math.abs(copy.y - y) > 0.01 then
		copy.x, copy.y = x, y
		copy.frame:ClearAllPoints()
		copy.frame:SetPoint("CENTER", parent, "BOTTOMLEFT", x, y)
	end
	return true
end

local function Fit(copy)
	local f = copy.at.now
	if not ns.Finite(f) or f <= 0 then
		f = 1
	end
	if copy.live and not Follow(copy, f) then
		return false
	end
	if math.abs(copy.scale - f) > 0.0001 then
		copy.scale = f
		copy.frame:SetScale(f)
		Lines(copy.cue)
	end
	return true
end

local function Gone(copy)
	copy.on, copy.leaving, copy.goal = false, nil, nil
	moving[copy] = nil
	Hide(copy.cue, true)
	copy.frame:Hide()
	Aim(copy.at, 1, true)
end

local function Step(copy, now)
	local eased = Ease(copy.at, now)
	if not Fit(copy) then
		Gone(copy)
		local owner = copy.owner
		if copy.live and owner ~= nil and not ns.Forbidden(owner) then
			Draw(owner, StateOf(owner), true)
		end
		return true
	end
	if copy.live then
		Health(copy)
	end
	if copy.leaving then
		if eased and not Playing(copy.cue.back) then
			Gone(copy)
			return true
		end
		return false
	end
	return eased and not copy.live
end

local function Poll()
	S.watch = false
	if not On() or Opt("threatSlipGrow") ~= true or Core() == nil then
		return
	end
	S.members = Members()
	ns.EachPlate(function(frame)
		local state = StateOf(frame)
		if Eligible(state) then
			Draw(frame, state)
		end
	end)
	S.members = nil
end

local function Tick(_, elapsed)
	if S.watch then
		S.wait = S.wait - (ns.Finite(elapsed) and elapsed or 0)
		if S.wait <= 0 then
			S.wait = LOOK_SECONDS
			Poll()
		end
	end
	local now, list = Now(), {}
	for copy in pairs(moving) do
		list[#list + 1] = copy
	end
	for _, copy in ipairs(list) do
		if moving[copy] then
			local ok, done = pcall(Step, copy, now)
			if not ok then
				ns.Note(KEY, "Nameplates: the magnified plate of an enemy you are losing failed. " .. tostring(done))
				pcall(Gone, copy)
				done = true
			end
			if done then
				moving[copy] = nil
			end
		end
	end
	if next(moving) == nil and not S.watch and driver then
		S.running = false
		driver:SetScript("OnUpdate", nil)
	end
end

local function Run()
	if driver == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		driver = ok and type(frame) == "table" and Own(frame) or false
	end
	if driver and not S.running then
		S.running = true
		driver:SetScript("OnUpdate", Tick)
	end
	return driver ~= false
end

local function Watch()
	if not S.watch then
		S.watch, S.wait = true, LOOK_SECONDS
	end
	Run()
end

local function Push(copy)
	moving[copy] = true
	if Run() then
		return
	end
	moving[copy] = nil
	Aim(copy.at, copy.at.to, true)
	if not Fit(copy) or copy.leaving then
		Gone(copy)
	end
end

local function Leave(copy, snap)
	if not copy.on and not copy.leaving then
		return
	end
	copy.on = false
	Hide(copy.cue, snap)
	if snap or not copy.frame:IsShown() then
		Gone(copy)
		return
	end
	if not copy.leaving then
		copy.leaving = true
		Aim(copy.at, 1, false)
		Push(copy)
	end
end

local function Come(copy, goal, snap)
	if not copy.on and not copy.frame:IsShown() then
		Aim(copy.at, 1, true)
	end
	copy.on, copy.leaving, copy.goal = true, nil, goal
	Aim(copy.at, goal, snap)
	if not Fit(copy) then
		Gone(copy)
		return false
	end
	copy.frame:Show()
	Push(copy)
	return copy.on
end

local function Magnify(frame, rec, state, kind, snap)
	local copy = rec.copy
	local goal, judged
	if Opt("threatSlipGrow") == true and Eligible(state) and Wanted(frame) then
		local t
		judged, t = Judge(frame, S.members or Members())
		goal = Goal(kind, judged, t)
		Watch()
	end
	local layout = goal and LiveLayout(frame) or nil
	if layout == nil then
		if copy then
			Leave(copy, snap or goal ~= nil)
		end
		return false
	end
	if copy == nil then
		copy = NewCopy(UIParent, StrataOf(frame), COPY_LEVEL)
		copy.live, copy.owner = true, frame
		rec.copy = copy
	end
	local swap = rec.cue ~= nil and rec.cue.on == true
	copy.unit, copy.source = layout.unit, layout.source
	Lay(copy, layout)
	Health(copy)
	local r, g, b = CopyColour(state, kind, judged)
	Tint(copy, r, g, b)
	Border(copy)
	if not Come(copy, goal, snap) then
		return false
	end
	if kind then
		Paint(copy.cue, kind, r, g, b)
		Show(copy.cue, snap or swap, false)
		return true
	end
	Hide(copy.cue, snap)
	return false
end

local function Work(frame, state, snap)
	local rec = recs[frame]
	local wanted = Wanted(frame)
	local kind = wanted and Kind(state) or nil
	local r, g, b
	if kind then
		r, g, b = Colour(state)
	end
	if r == nil then
		kind = nil
	end
	if rec == nil and kind == nil and not (wanted and Eligible(state) and Opt("threatSlipGrow") == true) then
		return
	end
	rec = rec or Record(frame)
	local covered = Magnify(frame, rec, state, kind, snap)
	local cue = rec.cue
	if kind == nil or covered then
		if cue then
			Hide(cue, snap or covered)
		end
		return
	end
	if cue == nil then
		if Locked(frame) then
			Wait(frame, rec)
			return
		end
		cue = Build(frame)
		rec.cue = cue
	end
	if not Place(frame, rec, cue) then
		Hide(cue, true)
		return
	end
	Paint(cue, kind, r, g, b)
	Show(cue, snap, false)
end

local function Drop(rec)
	if rec.cue then
		pcall(Hide, rec.cue, true)
	end
	if rec.copy then
		pcall(Leave, rec.copy, true)
	end
end

local function HideAll()
	for _, rec in pairs(recs) do
		Drop(rec)
	end
end

function Draw(frame, state, snap)
	if frame == nil or ns.IsSecret(frame) or ns.Forbidden(frame) then
		return
	end
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, PART) then
		HideAll()
		return
	end
	if not ns.EachPart(KEY, PART, Work, frame, state, snap) and ns.PartStopped(KEY, PART) then
		HideAll()
	end
end

local function Taken(state, previous)
	return type(previous) == "table" and previous.tank == true and previous.want == "bad" and previous.pet ~= true and previous.tapped ~= true
		and type(state) == "table" and state.tank == true and state.want == "good"
end

local function Lit(rec)
	local copy = rec and rec.copy
	return (rec ~= nil and rec.cue ~= nil and rec.cue.on == true) or (copy ~= nil and copy.on and copy.cue.on == true)
end

local function Back(frame, state)
	local rec = recs[frame]
	local copy = rec and rec.copy
	local cue = (copy and copy.frame:IsShown() and copy.cue) or (rec and rec.cue)
	if cue == nil or cue.on or cue.back == nil or cue.bar == nil then
		return
	end
	local r, g, b = Colour(state)
	if r == nil then
		return
	end
	if cue.go then
		pcall(cue.go.Stop, cue.go)
	end
	Paint(cue, "back", r, g, b)
	Moving(cue, false)
	cue.arrow:SetAlpha(0)
	cue.holder:SetAlpha(1)
	cue.holder:Show()
	pcall(cue.back.Stop, cue.back)
	pcall(cue.back.Play, cue.back)
end

local function OnChange(frame, state, previous)
	if type(state) ~= "table" then
		state = nil
	end
	local rec = recs[frame]
	if state == nil and rec == nil then
		return
	end
	local was = Lit(rec)
	Draw(frame, state)
	if was and Opt("threatSlipBack") == true and Taken(state, previous) and Wanted(frame) then
		ns.EachPart(KEY, PART, Back, frame, state)
	end
end

function ns.PlateSlipPlace(frame)
	local rec = frame ~= nil and not ns.IsSecret(frame) and recs[frame] or nil
	if rec and rec.cue and rec.cue.on and not ns.Forbidden(frame) then
		ns.EachPart(KEY, PART, Place, frame, rec, rec.cue)
	end
end

local function Subscribe()
	if S.subscribed then
		return
	end
	local PT = ns.PlateThreat
	if type(PT) == "table" and type(PT.OnChange) == "function" then
		S.subscribed = (pcall(PT.OnChange, OnChange))
	end
end

EXTRA.show[#EXTRA.show + 1] = function(frame, own)
	Subscribe()
	if type(own) == "table" then
		owns[frame] = own
	end
	ns.EachPart(KEY, PART, Prepare, frame)
	local state = StateOf(frame)
	if state ~= nil or recs[frame] ~= nil then
		Draw(frame, state, true)
	end
end
EXTRA.layout[#EXTRA.layout + 1] = function(frame, own)
	if type(own) == "table" then
		owns[frame] = own
	end
	local rec = recs[frame]
	if Lit(rec) or (rec and rec.copy and rec.copy.on) then
		rec.above = false
		Draw(frame, StateOf(frame), true)
	end
end
EXTRA.leave[#EXTRA.leave + 1] = function(frame)
	local rec = recs[frame]
	if rec then
		rec.above = false
		Drop(rec)
	end
end
EXTRA.refresh[#EXTRA.refresh + 1] = function()
	Subscribe()
	local seen = {}
	ns.EachPlate(function(frame)
		seen[frame] = true
		local rec = recs[frame]
		if rec then
			rec.above = false
		end
		ns.EachPart(KEY, PART, Prepare, frame)
		Draw(frame, StateOf(frame), true)
	end)
	for frame, rec in pairs(recs) do
		if not seen[frame] then
			Drop(rec)
		end
	end
end

local function Marked()
	for _, rec in pairs(recs) do
		local copy = rec.copy
		if copy and (copy.on or copy.leaving) then
			pcall(Border, copy)
		end
	end
end

ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", Marked)
ns.AddEvent(KEY, "PLAYER_FOCUS_CHANGED", Marked)

EXTRA.status[#EXTRA.status + 1] = function()
	if not On() or Core() == nil then
		return nil
	end
	if not Tank() then
		return "Mark enemies you are losing: off while you do not count as a tank."
	end
	local lost, slipping, magnified = 0, 0, 0
	for _, rec in pairs(recs) do
		local copy = rec.copy
		local cue = (copy and copy.on and copy.cue.on and copy.cue) or rec.cue
		if cue and cue.on then
			if cue.kind == "lost" then
				lost = lost + 1
			elseif cue.kind == "slipping" then
				slipping = slipping + 1
			end
		end
		if copy and copy.on then
			magnified = magnified + 1
		end
	end
	local line = ("Mark enemies you are losing: %d lost and %d slipping marked"):format(lost, slipping)
	if Opt("threatSlipGrow") == true then
		line = line .. (", %d shown magnified"):format(magnified)
	end
	return line .. (", %d plates waited for the end of a fight."):format(S.waited)
end

local function SampleText(p, spec, m)
	local name = p.name
	if name == nil or Read(name, "IsShown") ~= true then
		return nil
	end
	local text = { justify = "CENTER", text = Plain(spec.name, "string") and spec.name or "" }
	local high = ns.Finite(m.NH) and m.NH or FONT_PX
	if m.nameAbove then
		local width = ns.Finite(m.BW) and m.BW or m.HW
		text.point, text.rel, text.x, text.y, text.width = "BOTTOM", "CENTER", width / 2 - m.HW / 2, m.HH / 2 + m.sp, width
		text.bottom, text.top = text.y, text.y + high
		text.left, text.right = text.x - width / 2, text.x + width / 2
	else
		local width = Read(name, "GetWidth")
		width = ns.Finite(width) and width > 0 and width or math.max(1, m.HW - 12)
		text.point, text.rel, text.x, text.y, text.width, text.justify = "LEFT", "LEFT", 4, 0, width, "LEFT"
		text.bottom, text.top = -high / 2, high / 2
		text.left, text.right = -m.HW / 2 + 4, -m.HW / 2 + 4 + width
	end
	FontOf(text, name, 1)
	return text
end

local function SampleLayout(p, spec, o)
	local m = p.m
	if type(m) ~= "table" or not (ns.Finite(m.HW) and ns.Finite(m.HH) and ns.Finite(m.sp)) or m.HW <= 0 or m.HH <= 0 then
		return nil
	end
	local L = { w = m.HW, h = m.HH, name = SampleText(p, spec, m) }
	if spec.marker and o.marker and p.marker and Read(p.marker, "IsShown") == true then
		local size = ns.Finite(o.markerSize) and o.markerSize or m.HH * MARK_SHARE
		local x = (ns.Finite(o.markerX) and o.markerX or 0) - (ns.Finite(m.iconShift) and m.iconShift or 0)
		L.mark = { point = "RIGHT", rel = "LEFT", x = x, y = ns.Finite(o.markerY) and o.markerY or 0, size = size, index = spec.marker, left = -m.HW / 2 + x - size }
	end
	return L
end

local function SampleCopy(p, spec, o, kind, snap, still)
	local copy = p.slipCopy
	local goal = kind == "lost" and Opt("threatSlipGrow") == true and Full() or nil
	local layout = goal and type(p.f) == "table" and type(p.bar) == "table" and SampleLayout(p, spec, o) or nil
	if layout == nil then
		if copy then
			Leave(copy, snap)
		end
		return false
	end
	local strata = Read(p.f, "GetFrameStrata")
	strata = Plain(strata, "string") and STRATA[strata] and strata or "MEDIUM"
	local level = Read(p.f, "GetFrameLevel")
	level = (ns.Finite(level) and level or 0) + SAMPLE_RISE
	if copy == nil then
		copy = NewCopy(p.f, strata, level)
		copy.frame:ClearAllPoints()
		copy.frame:SetPoint("CENTER", p.bar, "CENTER", 0, 0)
		p.slipCopy = copy
	end
	Layer(copy, strata, level)
	Lay(copy, layout)
	local P = ns.SetupDrawPlates
	local share = spec.health or (type(P) == "table" and P.SHARE) or 1
	copy.bar:SetMinMaxValues(0, 1)
	copy.bar:SetValue(ns.Finite(share) and math.max(0, math.min(1, share)) or 1)
	local r, g, b = ns.Colour(KEY .. ".threatBad")
	Tint(copy, r, g, b)
	if not Come(copy, goal, snap) then
		return false
	end
	Paint(copy.cue, kind, r, g, b)
	Show(copy.cue, true, still)
	return true
end

function ns.PlateSlipSample(p, spec, o, on)
	if type(p) ~= "table" or type(spec) ~= "table" or type(o) ~= "table" then
		return
	end
	local P = ns.SetupDrawPlates
	local kind = on and Opt("threatSlipping") == true and SAMPLE_KINDS[spec.threat] or nil
	if kind and (type(P) ~= "table" or type(P.Damage) ~= "function" or P.Damage()) then
		kind = nil
	end
	local still = type(P) == "table" and type(P.Still) == "function" and P.Still(p) == true
	local ok, snaps = false, nil
	if type(P) == "table" and type(P.Snaps) == "function" then
		ok, snaps = pcall(P.Snaps, p)
	end
	local cue = p.slipCue
	local covered = SampleCopy(p, spec, o, kind, still or not ok or snaps ~= false, still)
	if not kind or covered then
		if cue then
			Hide(cue, true)
		end
		return
	end
	if cue == nil then
		cue = Build(p.f)
		p.slipCue = cue
	end
	Ring(cue, p.bar, o.levelSquare and p.lvl or p.bar)
	local m = p.m
	if type(m) == "table" and ns.Finite(m.top) and ns.Finite(m.BW) then
		local top = m.top
		if p.tvalue and p.tvalue:IsShown() and p.tvalueSide == "above" and ns.Finite(p.tvalueT) then
			top = math.max(top, p.tvalueT)
		end
		if p.opFrame and p.opFrame:IsShown() and ns.Finite(p.opT) then
			top = math.max(top, p.opT)
		end
		P.Put(p, cue.arrow, "BOTTOM", m.BW / 2, top + ARROW_GAP, cue.width, cue.height)
	end
	local r, g, b = ns.Colour(KEY .. "." .. (kind == "lost" and "threatBad" or "threatTransition"))
	Paint(cue, kind, r, g, b)
	pcall(cue.holder.SetFrameLevel, cue.holder, p.f:GetFrameLevel() + 12)
	Show(cue, true, still)
end

function ns.PlateSlipShown(p)
	if type(p) ~= "table" then
		return nil
	end
	local copy = p.slipCopy
	if copy ~= nil and copy.on then
		return copy.frame
	end
	local cue = p.slipCue
	return cue ~= nil and cue.on == true and cue.holder or nil
end

function ns.PlateSlipBox(p)
	local copy = type(p) == "table" and p.slipCopy or nil
	local box, m = copy and p.box, copy and p.m
	if copy == nil or not copy.on or type(box) ~= "table" or type(m) ~= "table" or type(copy.ext) ~= "table" then
		return
	end
	local f, ext = copy.goal, copy.ext
	if not (ns.Finite(f) and ns.Finite(m.HW) and ns.Finite(m.center) and ns.Finite(box.l) and ns.Finite(box.r) and ns.Finite(box.b) and ns.Finite(box.t)) then
		return
	end
	local cx, cy = m.HW / 2, m.center
	box.l, box.r = math.min(box.l, cx + ext.l * f), math.max(box.r, cx + ext.r * f)
	box.b, box.t = math.min(box.b, cy + ext.b * f), math.max(box.t, cy + ext.t * f)
end
