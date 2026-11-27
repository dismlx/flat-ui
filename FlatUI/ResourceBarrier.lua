local _, ns = ...

local KEY = "resource"
local PART = "Absorb shields"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SAMPLE, SAMPLE_AMOUNT = 0.35, 1525
local SWEEP, REST, BAND, BAND_PX, SHEEN_ALPHA = 2.4, 2.6, 0.22, 12, 0.3
local SHINE_ALPHA, FLASH, FLASH_ALPHA, FADE = 0.22, 0.45, 0.6, 0.3
local EDGE_PX, TEXT_GAP, RING_ALPHA, LIGHTER, ALPHA = 2, 3, 0.9, 0.5, 60
local AGAIN, POLL = 0.3, 0.5
local UNIT_EVENTS = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED" }
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }
local LATER = { UNIT_AURA = true, UNIT_SPELLCAST_SUCCEEDED = true }
local TEXTS = { "RightText", "TextString", "LeftText" }
local LINE_NO_BAR = "Personal resource display: the health bar was not found, so no absorb shield shows on it."
local LINE_WAITS = "Personal resource display: the absorb shield on the health bar comes when the fight ends."
local LINE_TRACKED = "Personal resource display: this client gives no absorb total, so the absorb shield shows the shields of the Absorb shields page."
local LINE_TRACKED_OFF = "Personal resource display: this client gives no absorb total and the Absorb shields page is off, so no absorb shield shows."

local IsSecret, Finite = ns.IsSecret, ns.Finite
local B = { loose = {}, acc = 0, plain = false, up = false }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function NewFrame(parent, kind)
	return Own(CreateFrame(kind or "Frame", nil, parent))
end

local function NewTexture(owner, layer, sub)
	return Own(owner:CreateTexture(nil, layer, nil, sub or 0))
end

local function NewBar(parent)
	local bar = NewFrame(parent, "StatusBar")
	bar:SetStatusBarTexture(WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local ok, fill = pcall(bar.GetStatusBarTexture, bar)
	if ok and type(fill) == "table" then
		Own(fill)
		return bar, fill
	end
	return bar, nil
end

local function NewClip(parent)
	local frame = NewFrame(parent)
	pcall(frame.SetClipsChildren, frame, true)
	return frame
end

local function Gradient(texture, orientation, from, to)
	texture:SetColorTexture(1, 1, 1, 1)
	local done = type(CreateColor) == "function" and type(texture.SetGradient) == "function"
		and pcall(texture.SetGradient, texture, orientation, CreateColor(1, 1, 1, from), CreateColor(1, 1, 1, to))
	if not done then
		texture:SetColorTexture(1, 1, 1, (from + to) / 2)
	end
end

local function Glide(bar, value, glide)
	local list = glide and type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return (pcall(bar.SetValue, bar, value))
end

local function Fill(bar, most, value, glide)
	if pcall(bar.SetMinMaxValues, bar, 0, most) and Glide(bar, value, glide) then
		return true
	end
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return false
end

local function Halt(group)
	if group then
		pcall(group.Stop, group)
	end
end

local function Playing(group)
	local ok, playing = pcall(group.IsPlaying, group)
	return ok and playing == true
end

local function Guard(fn, ...)
	if not ns.EachPart(KEY, PART, fn, ...) and ns.PartStopped(KEY, PART) then
		pcall(B.Off)
	end
end

function B.Mode()
	local mode = Opt("barrier")
	if mode == "barrier" or mode == "fill" then
		return mode
	end
	return nil
end

function B.Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and B.Mode() ~= nil
end

function B.HealthBar()
	local display = rawget(_G, "PersonalResourceDisplayFrame")
	if display == nil or ns.Forbidden(display) then
		return nil
	end
	local container = display.HealthBarsContainer
	local bar = container ~= nil and not ns.Forbidden(container) and container.healthBar or nil
	if bar ~= nil and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

function B.Band(clip)
	local frame = NewFrame(clip)
	local rise, fall = NewTexture(frame, "OVERLAY", 1), NewTexture(frame, "OVERLAY", 1)
	rise:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	rise:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 0, 0)
	fall:SetPoint("TOPLEFT", frame, "TOP", 0, 0)
	fall:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	Gradient(rise, "HORIZONTAL", 0, SHEEN_ALPHA)
	Gradient(fall, "HORIZONTAL", SHEEN_ALPHA, 0)
	pcall(rise.SetBlendMode, rise, "ADD")
	pcall(fall.SetBlendMode, fall, "ADD")
	local ok, group, move = pcall(function()
		local made = frame:CreateAnimationGroup()
		local step = made:CreateAnimation("Translation")
		step:SetDuration(SWEEP)
		step:SetStartDelay(REST)
		pcall(step.SetSmoothing, step, "IN_OUT")
		made:SetLooping("REPEAT")
		return made, step
	end)
	frame:Hide()
	return { frame = frame, group = ok and group or nil, move = ok and move or nil }
end

function B.Glint(clip)
	local glint = NewTexture(clip, "OVERLAY", 2)
	glint:SetAllPoints(clip)
	glint:SetColorTexture(1, 1, 1, 1)
	pcall(glint.SetBlendMode, glint, "ADD")
	glint:Hide()
	local ok, group = pcall(function()
		local made = glint:CreateAnimationGroup()
		local fall = made:CreateAnimation("Alpha")
		fall:SetFromAlpha(FLASH_ALPHA)
		fall:SetToAlpha(0)
		fall:SetDuration(FLASH)
		made:SetScript("OnFinished", function()
			glint:Hide()
		end)
		return made
	end)
	return { texture = glint, group = ok and group or nil }
end

function B.Shine(clip)
	local shine = NewTexture(clip, "ARTWORK", 1)
	shine:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
	shine:SetPoint("BOTTOMRIGHT", clip, "RIGHT", 0, 0)
	Gradient(shine, "VERTICAL", 0, SHINE_ALPHA)
	pcall(shine.SetBlendMode, shine, "ADD")
	return shine
end

function B.Fader(root)
	local ok, group = pcall(function()
		local made = root:CreateAnimationGroup()
		local fall = made:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE)
		pcall(made.SetToFinalAlpha, made, true)
		made:SetScript("OnFinished", function()
			Guard(B.Faded)
		end)
		return made
	end)
	return ok and group or nil
end

function B.Hug(d)
	if d.afterFill then
		d.afterClip:SetPoint("TOPLEFT", d.afterFill, "TOPLEFT", 0, 0)
		d.afterClip:SetPoint("BOTTOMRIGHT", d.afterFill, "BOTTOMRIGHT", 0, 0)
		d.afterEdge:SetPoint("TOPRIGHT", d.afterFill, "TOPRIGHT", 0, 0)
		d.afterEdge:SetPoint("BOTTOMRIGHT", d.afterFill, "BOTTOMRIGHT", 0, 0)
	end
	if d.foldFill then
		d.foldClip:SetPoint("TOPLEFT", d.foldFill, "TOPLEFT", 0, 0)
		d.foldClip:SetPoint("BOTTOMRIGHT", d.foldFill, "BOTTOMRIGHT", 0, 0)
		d.foldEdge:SetPoint("TOPLEFT", d.foldFill, "TOPLEFT", 0, 0)
		d.foldEdge:SetPoint("BOTTOMLEFT", d.foldFill, "BOTTOMLEFT", 0, 0)
	end
end

function B.Build(bar)
	local d = { bar = bar }
	local root = NewFrame(bar)
	root:SetAllPoints(bar)
	local level = bar:GetFrameLevel()
	root:SetFrameLevel((Finite(level) and level or 0) + 3)
	d.root = root
	local clip = NewClip(root)
	clip:SetAllPoints(bar)
	d.after, d.afterFill = NewBar(clip)
	d.afterClip = NewClip(d.after)
	d.afterEdge = NewBar(d.after)
	d.healthClip = NewClip(clip)
	d.fold, d.foldFill = NewBar(d.healthClip)
	d.fold:SetAllPoints(bar)
	d.reverse = pcall(d.fold.SetReverseFill, d.fold, true)
	d.foldClip = NewClip(d.fold)
	d.foldEdge = NewBar(d.fold)
	B.Hug(d)
	d.shines = { B.Shine(d.afterClip), B.Shine(d.foldClip) }
	d.glints = { B.Glint(d.afterClip), B.Glint(d.foldClip) }
	d.bands = { B.Band(d.afterClip), B.Band(d.foldClip) }
	d.ring = NewFrame(root)
	d.ring:SetAllPoints(bar)
	d.ring:SetFrameLevel(root:GetFrameLevel() + 8)
	d.edges = {}
	for index = 1, 4 do
		d.edges[index] = NewBar(d.ring)
	end
	d.marks = { d.afterEdge, d.foldEdge, d.edges[1], d.edges[2], d.edges[3], d.edges[4] }
	d.top = NewFrame(root)
	d.top:SetAllPoints(bar)
	d.top:SetFrameLevel(root:GetFrameLevel() + 9)
	d.text = ns.OwnText(d.top, "OVERLAY", "GameFontHighlightSmall")
	if d.text then
		d.text:SetWordWrap(false)
		d.text:SetJustifyH("LEFT")
	end
	d.fade = B.Fader(root)
	root:SetScript("OnSizeChanged", function()
		Guard(B.Layout)
	end)
	root:Hide()
	root:SetScript("OnShow", function()
		Guard(B.Shown)
	end)
	root:SetScript("OnHide", function()
		ns.EachPart(KEY, PART, B.Hidden)
	end)
	return d
end

function B.Anchor()
	local d = B.d
	local fill = ns.FillRegion(d.bar)
	if fill == d.fill then
		return fill ~= nil
	end
	d.fill = fill
	d.after:ClearAllPoints()
	d.healthClip:ClearAllPoints()
	if fill == nil then
		return false
	end
	d.after:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
	d.after:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
	d.healthClip:SetPoint("TOPLEFT", d.bar, "TOPLEFT", 0, 0)
	d.healthClip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
	return true
end

function B.PlaceRing()
	local d = B.d
	local t = ns.Get("general.thickness")
	local px = ns.Pixels(d.root, Finite(t) and t > 0 and t or 1)
	local top, bottom, left, right = d.edges[1], d.edges[2], d.edges[3], d.edges[4]
	for _, edge in ipairs(d.edges) do
		edge:ClearAllPoints()
	end
	top:SetPoint("BOTTOMLEFT", d.ring, "TOPLEFT", -px, 0)
	top:SetPoint("BOTTOMRIGHT", d.ring, "TOPRIGHT", px, 0)
	top:SetHeight(px)
	bottom:SetPoint("TOPLEFT", d.ring, "BOTTOMLEFT", -px, 0)
	bottom:SetPoint("TOPRIGHT", d.ring, "BOTTOMRIGHT", px, 0)
	bottom:SetHeight(px)
	left:SetPoint("TOPRIGHT", d.ring, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", d.ring, "BOTTOMLEFT", 0, 0)
	left:SetWidth(px)
	right:SetPoint("TOPLEFT", d.ring, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", d.ring, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(px)
end

function B.Layout()
	local d = B.d
	if not d then
		return
	end
	local ok, width = pcall(d.root.GetWidth, d.root)
	if not ok or not Finite(width) or width <= 0 then
		d.width = nil
		B.Sheen()
		return
	end
	local edge = ns.Pixels(d.root, EDGE_PX)
	d.after:SetWidth(width)
	d.afterEdge:SetWidth(edge)
	d.foldEdge:SetWidth(edge)
	local band = math.max(ns.Pixels(d.root, BAND_PX), width * BAND)
	local moved = d.width ~= width or d.band ~= band
	d.width, d.band = width, band
	for _, sheen in ipairs(d.bands) do
		sheen.frame:ClearAllPoints()
		sheen.frame:SetPoint("TOPLEFT", d.root, "TOPLEFT", -band, 0)
		sheen.frame:SetPoint("BOTTOMLEFT", d.root, "BOTTOMLEFT", -band, 0)
		sheen.frame:SetWidth(band)
		if sheen.move then
			pcall(sheen.move.SetOffset, sheen.move, width + band, 0)
		end
		if moved then
			Halt(sheen.group)
		end
	end
	B.PlaceRing()
	B.Sheen()
end

function B.Paint()
	local d = B.d
	local barrier = B.Mode() == "barrier"
	local r, g, b = ns.Colour(KEY .. ".barrierColour")
	local alpha = Opt("barrierAlpha")
	alpha = (Finite(alpha) and alpha or ALPHA) / 100
	d.after:SetStatusBarColor(r, g, b, alpha)
	d.fold:SetStatusBarColor(r, g, b, alpha)
	local er, eg, eb = r + (1 - r) * LIGHTER, g + (1 - g) * LIGHTER, b + (1 - b) * LIGHTER
	d.afterEdge:SetStatusBarColor(er, eg, eb, 1)
	d.foldEdge:SetStatusBarColor(er, eg, eb, 1)
	for _, edge in ipairs(d.edges) do
		edge:SetStatusBarColor(r, g, b, RING_ALPHA)
	end
	d.healthClip:SetShown(barrier and d.reverse == true)
	d.afterEdge:SetShown(barrier)
	for _, shine in ipairs(d.shines) do
		shine:SetShown(barrier)
	end
	d.ring:SetShown(barrier and Opt("barrierOutline") == true)
	if d.text then
		d.text:SetTextColor(r, g, b, 1)
	end
	d.label = nil
	if not barrier then
		B.StopFade()
		for _, glint in ipairs(d.glints) do
			Halt(glint.group)
			glint.texture:Hide()
		end
	end
	B.Layout()
end

function B.Sheen()
	local d = B.d
	if not d then
		return
	end
	local want = B.on == true and B.Mode() == "barrier" and Opt("barrierSheen") == true and B.up == true and d.width ~= nil and d.root:IsVisible()
	local mode = ns.TestMode
	if want and B.sample and type(mode) == "table" and type(mode.Moving) == "function" and not mode.Moving() then
		want = false
	end
	for _, sheen in ipairs(d.bands) do
		if want and sheen.group then
			sheen.frame:Show()
			if not Playing(sheen.group) then
				pcall(sheen.group.Play, sheen.group)
			end
		else
			Halt(sheen.group)
			sheen.frame:Hide()
		end
	end
end

function B.Flash()
	if not B.d.root:IsVisible() then
		return
	end
	for _, glint in ipairs(B.d.glints) do
		if glint.group then
			Halt(glint.group)
			glint.texture:Show()
			if not pcall(glint.group.Play, glint.group) then
				glint.texture:Hide()
			end
		end
	end
end

function B.StopFade()
	local d = B.d
	if B.fading and d and d.fade then
		Halt(d.fade)
	end
	B.fading = false
	if d then
		d.root:SetAlpha(1)
	end
end

function B.Feed(amount, most, plain, glide)
	local d = B.d
	local ok = Fill(d.after, most, amount, glide)
	Fill(d.fold, most, amount, glide)
	local present = amount
	if plain then
		present = amount > 0 and 1 or 0
	end
	for _, mark in ipairs(d.marks) do
		if not pcall(mark.SetValue, mark, present) then
			mark:SetValue(0)
		end
	end
	return ok
end

function B.Faded()
	local d = B.d
	B.fading = false
	if not d then
		return
	end
	B.Feed(0, 1, true)
	B.Write(0, true)
	d.root:SetAlpha(1)
	B.Sheen()
end

function B.Most()
	local ok, most = pcall(UnitHealthMax, "player")
	if ok and (IsSecret(most) or (Finite(most) and most > 0)) then
		return most
	end
	return 1
end

function B.Tracked()
	local total = type(ns.AbsorbTotal) == "function" and ns.AbsorbTotal("player") or 0
	return Finite(total) and math.max(0, total) or 0
end

function B.Read()
	local most = B.Most()
	if B.sample then
		if Finite(most) and most > 1 then
			return most * SAMPLE, true, most
		end
		return SAMPLE, true, 1
	end
	if type(UnitGetTotalAbsorbs) == "function" then
		local ok, total = pcall(UnitGetTotalAbsorbs, "player")
		if ok and IsSecret(total) then
			B.source = "game"
			return total, false, most
		elseif ok and Finite(total) then
			B.source = "game"
			return math.max(0, total), true, most
		end
	end
	B.source = "tracked"
	return B.Tracked(), true, most
end

function B.Number(value)
	if type(BreakUpLargeNumbers) == "function" then
		local ok, text = pcall(BreakUpLargeNumbers, value)
		if ok and not IsSecret(text) and type(text) == "string" then
			return text
		end
	end
	return ("%d"):format(value)
end

function B.Showing(label)
	local ok, shown = pcall(label.IsVisible, label)
	if not ok or IsSecret(shown) or shown ~= true then
		return false
	end
	local okAlpha, alpha = pcall(label.GetAlpha, label)
	if okAlpha and Finite(alpha) and alpha < 0.05 then
		return false
	end
	local okText, words = pcall(label.GetText, label)
	return not (okText and not IsSecret(words) and (words == nil or words == ""))
end

function B.Label()
	local bar = B.d.bar
	for _, name in ipairs(TEXTS) do
		local label = bar[name]
		if type(label) == "table" and not IsSecret(label) and B.Showing(label) then
			return label, name
		end
	end
	return nil
end

function B.Side(label, name)
	local ok, point = pcall(label.GetPoint, label, 1)
	if ok and not IsSecret(point) and type(point) == "string" then
		if point:find("RIGHT", 1, true) then
			return "right"
		elseif point:find("LEFT", 1, true) then
			return "left"
		end
	end
	return name == "LeftText" and "left" or "right"
end

function B.PlaceText()
	local d = B.d
	local label, name = B.Label()
	label = label or false
	if d.label == label then
		return
	end
	d.label = label
	local text, gap = d.text, ns.Pixels(d.root, TEXT_GAP)
	text:ClearAllPoints()
	if not label then
		text:SetPoint("RIGHT", d.root, "RIGHT", -gap, 0)
		text:SetJustifyH("RIGHT")
		return
	end
	if B.Side(label, name) == "right" then
		text:SetPoint("RIGHT", label, "LEFT", -gap, 0)
		text:SetJustifyH("RIGHT")
	else
		text:SetPoint("LEFT", label, "RIGHT", gap, 0)
		text:SetJustifyH("LEFT")
	end
	local ok, file, size, flags = pcall(label.GetFont, label)
	if ok and not (IsSecret(file) or IsSecret(size) or IsSecret(flags)) and type(file) == "string" and Finite(size) and size > 0 then
		pcall(text.SetFont, text, file, size, type(flags) == "string" and flags or "")
	end
end

function B.Write(amount, plain)
	local d = B.d
	local text = d.text
	if text == nil then
		return
	end
	if Opt("barrierText") ~= true then
		d.top:Hide()
		return
	end
	d.top:Show()
	B.PlaceText()
	if plain then
		if B.sample and amount < 1 then
			amount = SAMPLE_AMOUNT
		end
		text:SetText(amount >= 1 and ("+" .. B.Number(math.floor(amount + 0.5))) or "")
		return
	end
	local ok, written = false, nil
	if type(ns.CombatWithheld) == "function" then
		ok, written = ns.CombatWithheld(amount, "+", "")
	end
	if not (ok and pcall(text.SetText, text, written)) then
		text:SetText("")
	end
end

function B.Update(now)
	local d = B.d
	if not (B.on and d) then
		return
	end
	local amount, plain, most = B.Read()
	local was, wasPlain = B.last, B.plain
	local glide = not now and not B.sample and B.up == true and was ~= nil and d.root:IsVisible()
	if glide and plain and wasPlain and Finite(was) and amount > was then
		glide = false
	end
	local barrier = B.Mode() == "barrier"
	if plain and amount <= 0 and (B.fading or (barrier and d.fade and wasPlain and Finite(was) and was > 0 and d.root:IsVisible())) then
		B.last, B.plain, B.up = 0, true, false
		if not B.fading then
			B.fading = true
			if not pcall(d.fade.Play, d.fade) then
				B.Faded()
			end
		elseif not (d.fade and Playing(d.fade)) then
			B.Faded()
		end
		B.Poll(false)
		return
	end
	B.StopFade()
	if not B.Feed(amount, most, plain, glide) and not plain then
		amount, plain = B.Tracked(), true
		B.source = "tracked"
		B.Feed(amount, most, plain)
	end
	B.last, B.plain = amount, plain
	B.up = not plain or amount > 0
	if barrier and plain and wasPlain and Finite(was) and amount > was + 0.5 then
		B.Flash()
	end
	B.Write(amount, plain)
	B.Sheen()
	B.Poll(B.source == "tracked" and plain and amount > 0 and not B.sample)
end

function B.Shown()
	if B.on and B.d then
		B.Layout()
		B.Update(true)
	end
end

function B.Hidden()
	local d = B.d
	if not d then
		return
	end
	for _, sheen in ipairs(d.bands) do
		Halt(sheen.group)
		sheen.frame:Hide()
	end
	for _, glint in ipairs(d.glints) do
		Halt(glint.group)
		glint.texture:Hide()
	end
	if B.fading then
		B.Faded()
	end
end

function B.Tick(_, elapsed)
	B.acc = B.acc + (Finite(elapsed) and elapsed or 0)
	if B.acc >= POLL then
		B.acc = 0
		Guard(B.Update)
	end
end

function B.Poll(on)
	on = on == true
	if (B.polling or false) == on or not B.ear then
		return
	end
	B.polling, B.acc = on, 0
	B.ear:SetScript("OnUpdate", on and B.Tick or nil)
end

function B.Later()
	if B.waiting then
		return
	end
	B.waiting = true
	local ok = type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, AGAIN, function()
		B.waiting = false
		Guard(B.Update)
	end)
	if not ok then
		B.waiting = false
	end
end

function B.OnEvent(_, event, unit)
	if B.loose[event] and (IsSecret(unit) or unit ~= "player") then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		Guard(B.Sync)
		B.Later()
		return
	end
	Guard(B.Update)
	if LATER[event] then
		B.Later()
	end
end

function B.Listen(on)
	local ear = B.ear
	if ear == nil then
		if not on then
			return
		end
		ear = Own(CreateFrame("Frame"))
		ear:SetScript("OnEvent", B.OnEvent)
		B.ear = ear
	end
	if (B.hearing or false) == on then
		return
	end
	B.hearing = on
	pcall(ear.UnregisterAllEvents, ear)
	B.loose = {}
	if not on then
		return
	end
	for _, event in ipairs(UNIT_EVENTS) do
		local ok, done = false, nil
		if type(ear.RegisterUnitEvent) == "function" then
			ok, done = pcall(ear.RegisterUnitEvent, ear, event, "player")
		end
		if not (ok and (IsSecret(done) or done ~= false)) then
			B.loose[event] = pcall(ear.RegisterEvent, ear, event) or nil
		end
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
end

function B.Off()
	B.on = false
	B.Listen(false)
	B.Poll(false)
	local d = B.d
	if d then
		B.StopFade()
		for _, sheen in ipairs(d.bands) do
			Halt(sheen.group)
			sheen.frame:Hide()
		end
		for _, glint in ipairs(d.glints) do
			Halt(glint.group)
			glint.texture:Hide()
		end
		B.Feed(0, 1, true)
		d.root:Hide()
	end
	B.last, B.plain, B.up = nil, false, false
end

function B.Wait()
	if B.queued then
		return
	end
	B.queued = true
	ns.OutOfCombat(function()
		B.queued = false
		Guard(B.Sync)
	end)
end

function B.Sync()
	local bar = B.HealthBar()
	B.found = bar ~= nil
	if not (bar and B.Wanted()) then
		B.Off()
		return
	end
	if B.d == nil or B.d.bar ~= bar then
		B.Off()
		if InCombatLockdown() then
			B.Wait()
			return
		end
		B.d = B.Build(bar)
	end
	if not B.Anchor() then
		B.found = false
		B.Off()
		return
	end
	B.on = true
	B.d.root:Show()
	B.Paint()
	B.Listen(true)
	B.Update(true)
end

function B.Sample(on)
	B.sample = on == true or nil
	B.last, B.plain = on and 0 or nil, on == true
	B.Sync()
end

function ns.ResourceBarrierSync()
	if ns.PartStopped(KEY, PART) then
		pcall(B.Off)
		return
	end
	Guard(B.Sync)
end

function ns.ResourceBarrierChanged()
	ns.ResourceBarrierSync()
end

ns.AddStatus(KEY, function()
	if not B.Wanted() then
		return {}
	end
	if B.queued then
		return { LINE_WAITS }
	end
	if not B.found then
		return { LINE_NO_BAR }
	end
	if B.source == "tracked" and type(UnitGetTotalAbsorbs) ~= "function" then
		return { ns.Enabled("absorbs") and LINE_TRACKED or LINE_TRACKED_OFF }
	end
	return {}
end)

if ns.TestMode and type(ns.TestMode.Register) == "function" then
	ns.TestMode.Register("resourceBarrier", {
		module = KEY,
		label = "Absorb shield on the personal resource display",
		Start = function()
			Guard(B.Sample, true)
		end,
		Stop = function()
			Guard(B.Sample, false)
		end,
		Changed = function()
			ns.ResourceBarrierSync()
		end,
	})
end

ns.ResourceBarrier = B
