local _, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Pet target frame"
local MOVER = "FlatUIPetTarget"
local UNIT = "pettarget"
local BOX_W, BOX_H, BOX_X, BOX_Y = 120, 20, -246, 238
local HEIGHT, INSET, TICK, FADE_IN = 20, 4, 0.2, 0.15
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MARKER = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local LINE_BROKEN = "Unit frames: Pet target frame: the game did not make the frame, so it does not show until /reload."
local LINE_NO_WATCH = "Unit frames: Pet target frame: this client has no unit watch, so the frame does not show."
local LINE_WAITS = "Unit frames: Pet target frame: a change waits for the end of the fight."
local TELL_WAITS = "Flat UI: the pet target frame changes when the fight ends."
local GREY = 0.5
local HOSTILE = { 1, 0, 0 }
local SAMPLE = { name = "Training Dummy", share = 65 }

local IsSecret = ns.IsSecret

local P = { button = nil, broken = false, watched = false, later = false }
local S = {}

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, value = pcall(InCombatLockdown)
	return not ok or IsSecret(value) or value == true
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Wanted()
	return ns.Enabled(KEY) and Opt("petTarget") == true and not ns.PartStopped(KEY, PART)
end

local function Shown()
	if not P.button then
		return false
	end
	local ok, shown = pcall(P.button.IsShown, P.button)
	return ok and not IsSecret(shown) and shown == true
end

local function LeftOn()
	return Opt("healthByLeft") == true and Opt("flat") == true and type(ns.HealthLeftTint) == "function"
end

local function File()
	local file = X.fillFile("health")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

local function Yes(ok, value)
	return ok and not IsSecret(value) and value == true
end

local function Format()
	return type(X.formats) == "table" and X.formats.pct or "%.0f%%"
end

local function Glide(bar, value)
	local list = type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return pcall(bar.SetValue, bar, value)
end

local function Percent(pct)
	pct:SetFormattedText(Format(), UnitHealthPercent(UNIT, true, CurveConstants.ScaleTo100))
end

local function Cell(icon, index)
	if type(icon.SetSpriteSheetCell) == "function" then
		return (pcall(icon.SetSpriteSheetCell, icon, index, 4, 4))
	elseif ns.Finite(index) then
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		return (pcall(icon.SetTexCoord, icon, column / 4, (column + 1) / 4, row / 4, (row + 1) / 4))
	end
	return false
end

local function Marker(t, sample)
	local icon = t.marker
	if icon == nil then
		return
	end
	local shown = false
	if Opt("raidMarker") == true then
		if sample then
			shown = Cell(icon, 8)
		elseif type(GetRaidTargetIndex) == "function" then
			local ok, index = pcall(GetRaidTargetIndex, UNIT)
			if ok and (IsSecret(index) or (ns.Finite(index) and index >= 1 and index <= 8 and index == math.floor(index))) then
				shown = Cell(icon, index)
			end
		end
	end
	icon:SetShown(shown)
end

local function Warn(t, sample)
	local warn = t.warn
	if warn == nil then
		return
	end
	if Opt("petTargetWarn") == true then
		if sample then
			warn:SetAlpha(1)
			return
		end
		local ok, same = pcall(UnitIsUnit, UNIT, "target")
		if ok and (IsSecret(same) or type(same) == "boolean") and type(warn.SetAlphaFromBoolean) == "function"
			and pcall(warn.SetAlphaFromBoolean, warn, same, 0, 1) then
			return
		end
	end
	warn:SetAlpha(0)
end

local function Fill(jump)
	local bar, name, pct = P.bar, P.name, P.pct
	if not bar then
		return
	end
	local dead = Yes(pcall(UnitIsDead, UNIT))
	if dead then
		pcall(bar.SetMinMaxValues, bar, 0, 1)
		pcall(bar.SetValue, bar, 1)
	else
		local okMost, most = pcall(UnitHealthMax, UNIT)
		if okMost then
			pcall(bar.SetMinMaxValues, bar, 0, most)
		end
		local ok, health = pcall(UnitHealth, UNIT)
		if ok and (jump == true or P.dead) then
			pcall(bar.SetValue, bar, health)
		elseif ok then
			Glide(bar, health)
		end
	end
	P.dead = dead or nil
	local okName, text = pcall(UnitName, UNIT)
	if okName and (IsSecret(text) or type(text) == "string") then
		name:SetText(text)
	else
		name:SetText("")
	end
	if dead then
		pct:SetText(DEAD or "Dead")
	elseif not pcall(Percent, pct) then
		pct:SetText("")
	end
	if dead or not (LeftOn() and ns.HealthLeftTint(bar, UNIT)) then
		local r, g, b = GREY, GREY, GREY
		if not dead then
			r, g, b = ns.ReactionColour(UNIT)
			if r == nil then
				r, g, b = ns.Colour(KEY .. ".healthColour")
			end
			if type(X.mute) == "function" then
				r, g, b = X.mute(r, g, b)
			end
		end
		pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
	end
	Marker(P)
	Warn(P)
end

local function Step()
	if Shown() then
		Fill()
	end
end

local function Tick(on)
	if on and not P.ticker then
		local token = {}
		P.ticker = token
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, TICK, function()
				X.run(PART, Step)
			end)
			token.handle = ok and ticker or nil
		end
		if not token.handle then
			local function Again()
				if P.ticker == token then
					X.run(PART, Step)
					if P.ticker == token and not After(TICK, Again) then
						P.ticker = nil
					end
				end
			end
			if not After(TICK, Again) then
				P.ticker = nil
			end
		end
	elseif not on and P.ticker then
		local handle = P.ticker.handle
		P.ticker = nil
		if handle and type(handle.Cancel) == "function" then
			pcall(handle.Cancel, handle)
		end
	end
end

local function FadeIn(t)
	for _, group in ipairs(t.fades or {}) do
		pcall(group.Stop, group)
		pcall(group.Play, group)
	end
end

local function OnShow()
	X.run(PART, Fill, true)
	FadeIn(P)
	Tick(true)
	X.run(PART, P.SampleOn)
end

local function Halt(group)
	if group ~= nil and group:IsPlaying() then
		pcall(group.Stop, group)
	end
end

local function Unlit(now)
	local lit = P.lit
	if lit == nil then
		return
	end
	Halt(P.litIn)
	local out = P.litOut
	if not now and out ~= nil and lit:IsShown() and (out:IsPlaying() or pcall(out.Play, out)) then
		return
	end
	Halt(out)
	lit:Hide()
	lit:SetAlpha(1)
end

local function OnHide()
	Unlit(true)
	Tick(false)
	X.run(PART, P.SampleOn)
end

local function Tooltip(self)
	if type(GameTooltip_SetDefaultAnchor) ~= "function" or type(GameTooltip) ~= "table" then
		return
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(UNIT)
	GameTooltip:Show()
	self.UpdateTooltip = Tooltip
end

local function OnEnter(self)
	local lit = P.lit
	if lit and Opt("hoverHighlight") == true and not ns.PartStopped(KEY, "Mouse highlight") then
		Halt(P.litOut)
		lit:SetAlpha(1)
		lit:Show()
		if P.litIn ~= nil then
			pcall(P.litIn.Play, P.litIn)
		end
	elseif lit then
		Unlit(true)
	end
	if not pcall(Tooltip, self) then
		self.UpdateTooltip = nil
	end
end

local function OnLeave(self)
	Unlit(false)
	self.UpdateTooltip = nil
	if type(GameTooltip) == "table" then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, self)
		if Yes(ok, owned) then
			pcall(GameTooltip.Hide, GameTooltip)
		end
	end
end

local function FadeOf(region)
	local okGroup, group = pcall(region.CreateAnimationGroup, region)
	local okFade, fade = false, nil
	if okGroup and group ~= nil then
		okFade, fade = pcall(group.CreateAnimation, group, "Alpha")
	end
	if okFade and fade ~= nil and pcall(fade.SetFromAlpha, fade, 0) and pcall(fade.SetToAlpha, fade, 1) and pcall(fade.SetDuration, fade, FADE_IN) then
		return group
	end
	return nil
end

local function Children(frame, t)
	local bar = CreateFrame("StatusBar", nil, frame)
	ns.Own[bar] = true
	bar:SetAllPoints(frame)
	bar:SetStatusBarTexture(WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local pct = ns.OwnText(bar, "OVERLAY", FONT)
	pct:SetJustifyH("RIGHT")
	pct:SetWordWrap(false)
	pct:SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)
	local name = ns.OwnText(bar, "OVERLAY", FONT)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetPoint("LEFT", bar, "LEFT", INSET, 0)
	name:SetPoint("RIGHT", pct, "LEFT", -INSET, 0)
	t.frame, t.bar, t.name, t.pct, t.file = frame, bar, name, pct, WHITE
	t.fades = {}
	t.fades[#t.fades + 1] = FadeOf(bar)
	local level = frame:GetFrameLevel()
	local skin = X.frame(frame, X.number(level) and level or nil)
	skin:SetAllPoints(frame)
	t.outline = ns.Outline(skin, frame, true)
	t.fades[#t.fades + 1] = FadeOf(skin)
	if type(bar.CreateMaskTexture) == "function" then
		local mask = bar:CreateMaskTexture()
		ns.Own[mask] = true
		mask:SetAllPoints(bar)
		t.mask = mask
	end
	local marker = bar:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[marker] = true
	marker:SetTexture(MARKER)
	marker:SetSize(HEIGHT - 2, HEIGHT - 2)
	marker:SetPoint("RIGHT", frame, "LEFT", -2, 0)
	marker:Hide()
	t.marker = marker
	local lit = bar:CreateTexture(nil, "OVERLAY", nil, 6)
	ns.Own[lit] = true
	lit:SetAllPoints(bar)
	lit:SetTexture(WHITE)
	lit:SetBlendMode("ADD")
	lit:SetVertexColor(1, 1, 1, X.hoverAlpha or 0.12)
	lit:Hide()
	t.lit = lit
	if type(X.hoverFades) == "function" then
		t.litIn, t.litOut = X.hoverFades(lit)
	end
	local warn = X.frame(frame, X.number(level) and level + 2 or nil)
	warn:SetAllPoints(frame)
	warn:SetAlpha(0)
	local inner = X.frame(warn)
	inner:SetAllPoints(warn)
	local edges = ns.Outline(inner, inner)
	if edges ~= nil then
		ns.SetOutlineArea(edges, KEY)
		ns.SetOutline(edges, true, false)
	end
	local line = inner:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[line] = true
	line:Hide()
	t.warn, t.warnOutline, t.warnLine = warn, edges, line
	t.fades[#t.fades + 1] = FadeOf(inner)
end

local function Make()
	if P.button then
		return true
	end
	if P.broken or Fighting() then
		return false
	end
	local made, button = pcall(CreateFrame, "Button", nil, UIParent, "SecureActionButtonTemplate")
	if not made or IsSecret(button) or type(button) ~= "table" then
		P.broken = true
		return false
	end
	ns.Own[button] = true
	local ok = pcall(function()
		button:Hide()
		button:SetFrameStrata("LOW")
		button:SetSize(BOX_W, HEIGHT)
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useOnKeyDown", false)
		button:SetAttribute("type1", "target")
		button:SetAttribute("shift-type1", "focus")
		button:SetAttribute("type2", "togglemenu")
		button:SetAttribute("unit", UNIT)
		Children(button, P)
		button:SetScript("OnShow", OnShow)
		button:SetScript("OnHide", OnHide)
		button:SetScript("OnEnter", OnEnter)
		button:SetScript("OnLeave", OnLeave)
	end)
	if not ok then
		pcall(button.Hide, button)
		P.broken = true
		return false
	end
	P.button = button
	return true
end

local function Corners(t)
	if type(X.ownCorners) ~= "function" then
		return
	end
	local radius, changed = X.ownCorners(t)
	t.radius = radius
	if changed and t.lit then
		if type(X.shape) ~= "function" or not X.shape(t.lit, radius) then
			pcall(t.lit.SetTexture, t.lit, WHITE)
		end
		pcall(t.lit.SetBlendMode, t.lit, "ADD")
		pcall(t.lit.SetVertexColor, t.lit, 1, 1, 1, X.hoverAlpha or 0.12)
	end
end

local function PaintWarn(t)
	local edges, line = t.warnOutline, t.warnLine
	if edges == nil or line == nil then
		return
	end
	local r, g, b = ns.Colour(KEY .. ".petTargetWarnColour")
	ns.SetOutlineColour(edges, r, g, b)
	local rim = t.radius ~= nil and type(X.rimLine) == "function" and X.rimLine(t.outline) or nil
	local round = false
	if rim ~= nil and type(X.shape) == "function" then
		if t.warnRadius ~= t.radius then
			t.warnRadius = t.radius
			t.warnRound = X.shape(line, t.radius, true) == true
		end
		round = t.warnRound == true
		if round and t.warnRim ~= rim then
			line:ClearAllPoints()
			line:SetAllPoints(rim)
			t.warnRim = rim
		end
	end
	ns.SetOutlineEdges(edges, not round)
	line:SetShown(round)
	if round then
		line:SetVertexColor(r, g, b, 1)
	end
end

local function Width()
	local width = Opt("petTargetWidth")
	return ns.Finite(width) and width > 0 and width or BOX_W
end

local function Paint(t)
	local width, resized = Width(), false
	if t.width ~= width and pcall(t.frame.SetSize, t.frame, width, HEIGHT) then
		resized = t.width ~= nil
		t.width = width
	end
	local file = File()
	if t.file ~= file then
		local ok, done = pcall(t.bar.SetStatusBarTexture, t.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(t.bar.SetStatusBarTexture, t.bar, WHITE)
		end
		t.file = file
	end
	Corners(t)
	if t.outline then
		ns.SetOutlineEdges(t.outline, Opt("barBorder") ~= false)
		X.outline(t.outline, true, Opt("backdrop"))
	end
	PaintWarn(t)
	if type(X.ownSpec) == "function" then
		local size = tonumber(Opt("smallTextSize")) or 100
		local light = Opt("lookLightText") == true
		ns.TextStyle(t.name, X.ownSpec("name", { percent = size }))
		local bar = X.ownSpec("bar", { percent = light and size * 0.85 or size })
		if light and bar.flags == nil then
			bar.flags = ""
		end
		ns.TextStyle(t.pct, bar)
	end
	return resized
end

local function Resized()
	P.placed, S.placed = nil, nil
	if type(ns.MoverRelabel) == "function" then
		pcall(ns.MoverRelabel)
	end
end

local function Place(t)
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if t.placed == key then
		return
	end
	local frame = t.frame
	local ok = pcall(function()
		frame:ClearAllPoints()
		if x then
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		else
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOM", BOX_X - BOX_W / 2, BOX_Y + BOX_H)
		end
	end)
	if ok then
		t.placed = key
	end
end

local function Watch()
	if P.watched then
		return true
	end
	if type(RegisterUnitWatch) ~= "function" then
		ns.Note(KEY, LINE_NO_WATCH)
		return false
	end
	if pcall(RegisterUnitWatch, P.button) then
		P.watched = true
	end
	return P.watched
end

local Off

local function Later()
	if P.later then
		return
	end
	P.later = true
	ns.OutOfCombat(function()
		P.later = false
		if ns.IsStopped(KEY) then
			pcall(Off)
		else
			X.run(PART, P.Update)
		end
	end)
end

function Off()
	if not P.button then
		return
	end
	if not P.watched and not Shown() then
		Tick(false)
		return
	end
	if Fighting() then
		X.tell(TELL_WAITS)
		Later()
		return
	end
	if P.watched and type(UnregisterUnitWatch) == "function" and pcall(UnregisterUnitWatch, P.button) then
		P.watched = false
	end
	pcall(P.button.Hide, P.button)
	Tick(false)
end

function P.Update()
	if not Wanted() then
		Off()
		return
	end
	if Fighting() then
		if not P.button or not P.watched or P.width ~= Width() then
			X.tell(TELL_WAITS)
		end
		Later()
		return
	end
	if not Make() then
		return
	end
	if Paint(P) then
		Resized()
	end
	Place(P)
	if Watch() and Shown() then
		Fill()
	end
end

local function SampleMake()
	if S.frame then
		return true
	end
	if S.broken or Fighting() then
		return false
	end
	local ok = pcall(function()
		local frame = CreateFrame("Frame", nil, UIParent)
		ns.Own[frame] = true
		frame:Hide()
		frame:SetFrameStrata("LOW")
		frame:SetSize(BOX_W, HEIGHT)
		Children(frame, S)
	end)
	if not ok or not S.frame then
		S.broken = true
		return false
	end
	return true
end

local function SampleFill()
	local bar = S.bar
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(SAMPLE.share)
	S.name:SetText(SAMPLE.name)
	S.pct:SetFormattedText(Format(), SAMPLE.share)
	local r, g, b = HOSTILE[1], HOSTILE[2], HOSTILE[3]
	if ns.Get("general.reactionOwn") == true then
		r, g, b = ns.Colour("general.reactionHostile")
	end
	if type(X.mute) == "function" then
		r, g, b = X.mute(r, g, b)
	end
	if LeftOn() and type(ns.HealthLeftColour) == "function" then
		r, g, b = ns.HealthLeftColour(SAMPLE.share / 100)
	end
	bar:SetStatusBarColor(r, g, b, 1)
	Marker(S, true)
	Warn(S, true)
end

function P.SampleOn()
	local TM = ns.TestMode
	if not (TM and TM.IsOn() and Wanted() and not Shown()) then
		P.SampleOff()
		return
	end
	if not SampleMake() then
		return
	end
	if Paint(S) then
		Resized()
	end
	Place(S)
	SampleFill()
	S.frame:Show()
end

function P.SampleOff()
	if S.frame then
		S.frame:Hide()
	end
end

function ns.PetTargetShown()
	return ns.Enabled(KEY) and Opt("petTarget") == true
end

function ns.PetTargetWidth()
	return Width()
end

function ns.PetTargetStart(x, y)
	return x + (Width() - BOX_W) / 2, y
end

function ns.PetTargetMoved()
	P.placed, S.placed = nil, nil
	if S.frame and S.frame:IsShown() then
		X.run(PART, Place, S)
	end
	if P.button then
		if Fighting() then
			Later()
		else
			X.run(PART, P.Update)
		end
	end
end

local function Changed(jump)
	if Shown() then
		Fill(jump)
	end
end

ns.AddEvent(KEY, "UNIT_TARGET", function()
	X.run(PART, Changed, true)
end, function(unit)
	return not IsSecret(unit) and unit == "pet"
end)
ns.AddEvent(KEY, "UNIT_PET", function()
	X.run(PART, Changed, true)
end, function(unit)
	return not IsSecret(unit) and unit == "player"
end)
ns.AddEvent(KEY, "RAID_TARGET_UPDATE", function()
	X.run(PART, Changed)
end)
ns.AddEvent(KEY, "PLAYER_TARGET_CHANGED", function()
	X.run(PART, Changed)
end)

ns.AddStatus(KEY, function()
	local lines = {}
	if not Wanted() then
		return lines
	end
	if P.broken then
		lines[#lines + 1] = LINE_BROKEN
	end
	if P.later then
		lines[#lines + 1] = LINE_WAITS
	end
	return lines
end)

table.insert(X.after.refresh, { part = PART, fn = P.Update })

if ns.TestMode then
	ns.TestMode.Register("pettarget", { module = KEY, label = "Pet target", Start = P.SampleOn, Stop = P.SampleOff, Changed = P.SampleOn })
end
