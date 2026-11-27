local _, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Druid mana"
local MANA, TOKEN, HEIGHT_PX = 0, "MANA", 4
local TEXT_GAP, TEXT_PERCENT, SAMPLE_MANA = 4, 85, 3600
local SAMPLE_SHIFT, TICK_ALPHA = 0.35, 0.9
local FADE_IN, FADE_OUT = 0.15, 0.2
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLUE = { 0, 0, 1 }
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local EVENTS = { "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }
local LINE_SHOWN = "Unit frames: Druid mana: shown under the player frame while your power is not mana."
local LINE_WAITS = "Unit frames: Druid mana: the bar waits for the end of the fight."
local TELL_WAITS = "Flat UI: the druid mana bar changes when the fight ends."
local LINE_REFUSED = "Unit frames: Druid mana: the game refused the texture of the bar, so it does not show."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Druid()
	if type(UnitClass) ~= "function" then
		return false
	end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and not IsSecret(class) and class == "DRUID"
end

local function Wanted()
	return ns.Enabled(KEY) and Opt("druidMana") == true and not ns.PartStopped(KEY, PART) and Druid()
end

local function File()
	local file = X.fillFile("power")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

local function Anchor(rec, joined)
	local power = rec.byRole and rec.byRole.power
	local health = rec.byRole and rec.byRole.health
	if health ~= nil and (joined or X.active(rec) == true) and (power == nil or Opt("playerPowerBar") == false) then
		return health.target
	end
	return power and power.target or rec.parts.power
end

local function Fades(frame)
	local ok, fadeIn, fadeOut = pcall(function()
		local come = frame:CreateAnimationGroup()
		local rise = come:CreateAnimation("Alpha")
		rise:SetFromAlpha(0)
		rise:SetToAlpha(1)
		rise:SetDuration(FADE_IN)
		local go = frame:CreateAnimationGroup()
		local fall = go:CreateAnimation("Alpha")
		fall:SetFromAlpha(1)
		fall:SetToAlpha(0)
		fall:SetDuration(FADE_OUT)
		pcall(go.SetToFinalAlpha, go, true)
		go:SetScript("OnFinished", function()
			frame:Hide()
			frame:SetAlpha(1)
		end)
		return come, go
	end)
	if ok then
		return fadeIn, fadeOut
	end
	return nil, nil
end

local function Make(rec)
	local parent, anchor = rec.parts.badges or rec.parts.owner, Anchor(rec)
	if parent == nil or anchor == nil or ns.Forbidden(parent) or ns.Forbidden(anchor) then
		return nil
	end
	local holder = X.frame(parent)
	holder:Hide()
	local bar = CreateFrame("StatusBar", nil, holder)
	ns.Own[bar] = true
	bar:SetAllPoints(holder)
	local d = { holder = holder, bar = bar, shown = false, form = false }
	d.fadeIn, d.fadeOut = Fades(holder)
	local ok, done = pcall(bar.SetStatusBarTexture, bar, WHITE)
	if not ok or (not IsSecret(done) and done == false) then
		rec.druidRefused = true
		ns.Note(KEY, LINE_REFUSED)
		return nil
	end
	d.file = WHITE
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	d.outline = ns.Outline(holder, bar)
	local tick = bar:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[tick] = true
	tick:SetTexture(WHITE)
	tick:SetVertexColor(1, 1, 1, TICK_ALPHA)
	tick:Hide()
	d.tick = tick
	d.text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
	if d.text then
		d.text:SetPoint("LEFT", holder, "RIGHT", TEXT_GAP, 0)
		d.text:SetJustifyH("LEFT")
		d.text:Hide()
	end
	if type(bar.CreateMaskTexture) == "function" then
		local okMask, mask = pcall(bar.CreateMaskTexture, bar)
		if okMask and mask ~= nil then
			ns.Own[mask] = true
			mask:SetAllPoints(bar)
			d.mask = mask
		end
	end
	rec.druidMana = d
	return d
end

local function Layout(rec, d)
	local joined = type(X.joined) == "function" and X.joined(rec) == true
	local anchor = Anchor(rec, joined)
	if anchor == nil or ns.Forbidden(anchor) then
		return nil
	end
	local t = ns.Get("general.thickness")
	t = ns.Finite(t) and t or 1
	local gap
	if joined then
		gap = ns.Pixels(d.holder, 3 * t + 2 * (tonumber(Opt("powerSpace")) or 0))
	else
		gap = math.max(1, ns.Pixels(d.holder, 2 * t))
	end
	local px = tonumber(Opt("druidManaHeight"))
	local tall = ns.Pixels(d.holder, px and px >= 1 and px or HEIGHT_PX)
	return anchor, gap, tall, ("%.3f:%.3f"):format(gap, tall) .. (joined and ":body" or "")
end

local function Placed(rec, d)
	local anchor, _, _, key = Layout(rec, d)
	return anchor == nil or (d.placed == key and d.anchor == anchor)
end

local function Place(rec, d)
	local anchor, gap, tall, key = Layout(rec, d)
	if anchor == nil or (d.placed == key and d.anchor == anchor) then
		return
	end
	local holder = d.holder
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
	holder:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
	holder:SetHeight(tall)
	d.placed, d.anchor = key, anchor
end

local function TextMode()
	local mode = Opt("druidManaText")
	if mode == "pct" or mode == "cur" then
		return mode
	end
	return nil
end

local function Num(value)
	local call = Opt("numberStyle") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or BreakUpLargeNumbers
	if type(call) ~= "function" then
		return value
	end
	return call(value)
end

local function PctFormat()
	return type(X.formats) == "table" and X.formats.pct or "%.0f%%"
end

local function Paint(d)
	local file = File()
	if d.file ~= file then
		local ok, done = pcall(d.bar.SetStatusBarTexture, d.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(d.bar.SetStatusBarTexture, d.bar, WHITE)
		end
		d.file = file
	end
	local r, g, b = ns.PowerColour(TOKEN)
	if r == nil then
		r, g, b = BLUE[1], BLUE[2], BLUE[3]
	end
	if type(X.mute) == "function" then
		r, g, b = X.mute(r, g, b)
	end
	pcall(d.bar.SetStatusBarColor, d.bar, r, g, b, 1)
	if type(X.ownCorners) == "function" then
		X.ownCorners(d)
	end
	if d.outline then
		ns.SetOutlineEdges(d.outline, Opt("barBorder") ~= false)
		X.outline(d.outline, true, Opt("backdrop"))
	end
	if d.text then
		local light = Opt("lookLightText") == true
		local percent = tonumber(Opt("powerTextSize")) or TEXT_PERCENT
		local spec = { percent = light and percent * 0.85 or percent }
		if type(X.ownSpec) == "function" then
			spec = X.ownSpec("bar", spec)
		end
		if light and spec.flags == nil then
			spec.flags = ""
		end
		ns.TextStyle(d.text, spec)
		d.text:SetShown(TextMode() ~= nil)
	end
end

local function Plain(ok, value)
	if ok and ns.Finite(value) then
		return value
	end
	return nil
end

local function ShiftCost()
	if type(GetShapeshiftForm) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
		return nil
	end
	local index = Plain(pcall(GetShapeshiftForm))
	if index == nil or index < 1 then
		return nil
	end
	local okInfo, _, _, _, spell = pcall(GetShapeshiftFormInfo, index)
	spell = Plain(okInfo, spell)
	if spell == nil or spell <= 0 then
		return nil
	end
	local spells = C_Spell
	if type(spells) ~= "table" or type(spells.GetSpellPowerCost) ~= "function" then
		return spell
	end
	local okCost, costs = pcall(spells.GetSpellPowerCost, spell)
	local cost = nil
	if okCost and not IsSecret(costs) and type(costs) == "table" then
		pcall(function()
			for _, entry in ipairs(costs) do
				local kind = not IsSecret(entry) and type(entry) == "table" and entry.type or nil
				if ns.Finite(kind) and kind == MANA then
					cost = Plain(true, entry.cost)
					break
				end
			end
		end)
	end
	local most = Plain(pcall(UnitPowerMax, "player", MANA))
	if cost == nil or most == nil or cost <= 0 or cost >= most then
		return spell
	end
	return spell, cost, most
end

local function PlaceTick(d, share)
	local tick = d.tick
	local ok, width = pcall(d.holder.GetWidth, d.holder)
	if share == nil or not ok or not ns.Finite(width) or width <= 0 then
		tick:Hide()
		return
	end
	local x = width * share
	tick:ClearAllPoints()
	tick:SetPoint("TOP", d.bar, "TOPLEFT", x, 0)
	tick:SetPoint("BOTTOM", d.bar, "BOTTOMLEFT", x, 0)
	tick:SetWidth(ns.Pixels(d.holder, 1))
	tick:Show()
end

local function Mark(d)
	if d.tick == nil then
		return
	end
	if Opt("druidManaShift") ~= true then
		d.tickFor, d.tickShare = nil, nil
		PlaceTick(d, nil)
		return
	elseif d.sample then
		PlaceTick(d, SAMPLE_SHIFT)
		return
	end
	local spell, cost, most = ShiftCost()
	if cost ~= nil then
		d.tickFor, d.tickShare = spell, cost / most
	elseif spell == nil or spell ~= d.tickFor then
		d.tickFor, d.tickShare = nil, nil
	end
	PlaceTick(d, d.tickShare)
	if cost == nil and spell ~= nil and InCombatLockdown() and not d.markQueued then
		d.markQueued = true
		ns.OutOfCombat(function()
			d.markQueued = nil
			X.run(PART, Mark, d)
		end)
	end
end

local function Glide(bar, value)
	local list = type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return pcall(bar.SetValue, bar, value)
end

local function Feed(d, jump)
	local okMost, most = pcall(UnitPowerMax, "player", MANA)
	if okMost then
		pcall(d.bar.SetMinMaxValues, d.bar, 0, most)
	end
	local ok, mana = pcall(UnitPower, "player", MANA)
	if ok and jump then
		pcall(d.bar.SetValue, d.bar, mana)
	elseif ok then
		Glide(d.bar, mana)
	end
	local mode, text = TextMode(), d.text
	if text == nil or mode == nil then
		return
	end
	if mode == "pct" then
		pcall(function()
			text:SetFormattedText(PctFormat(), UnitPowerPercent("player", MANA, false, CurveConstants.ScaleTo100))
		end)
	elseif ok then
		pcall(function()
			text:SetText(Num(mana))
		end)
	end
end

local function Testing()
	return ns.TestMode ~= nil and ns.TestMode.IsOn() == true
end

local function InForm(d)
	local ok, kind = pcall(UnitPowerType, "player")
	if ok and ns.Finite(kind) then
		d.form = kind ~= MANA
	end
	return d.form == true
end

local function Showing(d, on, fade)
	local holder, fadeIn, fadeOut = d.holder, d.fadeIn, d.fadeOut
	local fading = fadeOut ~= nil and fadeOut:IsPlaying()
	if on then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
		end
		holder:SetAlpha(1)
		holder:Show()
		if fadeIn then
			pcall(fadeIn.Stop, fadeIn)
			pcall(fadeIn.Play, fadeIn)
		end
		return
	end
	if fadeIn and fadeIn:IsPlaying() then
		pcall(fadeIn.Stop, fadeIn)
	end
	if not (fade and fadeOut and holder:IsShown()) then
		if fading then
			pcall(fadeOut.Stop, fadeOut)
		end
		holder:Hide()
		holder:SetAlpha(1)
	elseif not fading and not pcall(fadeOut.Play, fadeOut) then
		holder:Hide()
	end
end

local function Show(d)
	local form = InForm(d)
	local show = Wanted() and (form or Testing())
	local fresh = not d.shown or d.sample == true
	if d.shown ~= show then
		Showing(d, show, not show and not d.sample and Wanted() and not Testing())
		d.shown = show
	end
	d.sample = show and not form or nil
	if d.sample then
		pcall(d.bar.SetMinMaxValues, d.bar, 0, 1)
		pcall(d.bar.SetValue, d.bar, 0.6)
		if d.text then
			if TextMode() == "cur" then
				pcall(d.text.SetText, d.text, Num(SAMPLE_MANA))
			else
				pcall(d.text.SetFormattedText, d.text, PctFormat(), 60)
			end
		end
	elseif show then
		Feed(d, fresh)
	end
	if show then
		Mark(d)
	end
end

local function OnEvent(d, event, unit, token)
	if event:find("^UNIT_") and not IsSecret(unit) and unit ~= "player" then
		return
	end
	if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		if not IsSecret(token) and token ~= TOKEN then
			return
		end
		if d.shown and not d.sample then
			Feed(d)
			if event == "UNIT_MAXPOWER" then
				Mark(d)
			end
		end
		return
	end
	Show(d)
end

local function Hear(d, on)
	if (d.hearing or false) == on then
		return
	end
	local ear = d.ear
	if ear == nil then
		if not on then
			return
		end
		ear = CreateFrame("Frame")
		ns.Own[ear] = true
		ear:SetScript("OnEvent", function(_, event, ...)
			X.run(PART, OnEvent, d, event, ...)
		end)
		d.ear = ear
	end
	pcall(ear.UnregisterAllEvents, ear)
	d.hearing = false
	if not on then
		return
	end
	for _, event in ipairs(UNIT_EVENTS) do
		local ok, done = false, nil
		if type(ear.RegisterUnitEvent) == "function" then
			ok, done = pcall(ear.RegisterUnitEvent, ear, event, "player")
		end
		if not (ok and (IsSecret(done) or done ~= false)) then
			pcall(ear.RegisterEvent, ear, event)
		end
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
	d.hearing = true
end

local told = false

local function Tell()
	if told or type(ns.PanelShown) ~= "function" or ns.PanelShown() ~= true then
		return
	end
	told = true
	print(TELL_WAITS)
	ns.OutOfCombat(function()
		told = false
	end)
end

local function DruidMana(rec)
	if rec.kind ~= "player" then
		return
	end
	local d = rec.druidMana
	if not Wanted() then
		if d then
			Showing(d, false, false)
			d.shown = false
			Hear(d, false)
		end
		return
	end
	if d == nil then
		if rec.druidRefused then
			return
		end
		if InCombatLockdown() then
			Tell()
			if not rec.druidQueued then
				rec.druidQueued = true
				ns.OutOfCombat(function()
					rec.druidQueued = nil
					X.run(PART, DruidMana, rec)
				end)
			end
			return
		end
		d = Make(rec)
		if d == nil then
			return
		end
	end
	if not InCombatLockdown() then
		Place(rec, d)
	elseif not Placed(rec, d) then
		Tell()
		if not rec.druidPlaceQueued then
			rec.druidPlaceQueued = true
			ns.OutOfCombat(function()
				rec.druidPlaceQueued = nil
				X.run(PART, DruidMana, rec)
			end)
		end
	end
	Paint(d)
	Hear(d, true)
	Show(d)
end

local function OnRefresh()
	local rec = X.known(_G.PlayerFrame)
	if rec then
		DruidMana(rec)
	end
end

ns.AddStatus(KEY, function()
	local rec = X.known(_G.PlayerFrame)
	if not (rec and Wanted()) then
		return {}
	end
	if rec.druidMana == nil then
		return rec.druidQueued and { LINE_WAITS } or {}
	end
	return { LINE_SHOWN }
end)

table.insert(X.after.apply, { part = PART, fn = DruidMana })
table.insert(X.after.refresh, { part = PART, fn = OnRefresh })

if ns.TestMode then
	ns.TestMode.Watch(function()
		local rec = X.known(_G.PlayerFrame)
		if rec then
			X.run(PART, DruidMana, rec)
		end
	end)
end
