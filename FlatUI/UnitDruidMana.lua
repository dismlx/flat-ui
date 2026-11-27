local _, ns = ...

-- Druid mana in forms (on by default, Player frame page): a thin bar of Flat UI's own with a druid's mana under the power bar of the player frame,
-- while the druid is in Bear, Dire Bear or Cat Form. A druid in those forms sees no mana on Forever. The game's alternate power bar loads there
-- (Blizzard_UnitFrame/Blizzard_UnitFrame.toc:90-93 has no ExcludeLoadGameType camelot, unlike the class bars at 75-78, 86-89 and 94-97, and
-- Camelot/PlayerFrame.lua:58 and 99 ask for it), but its pairs give a druid mana only beside Lunar Power, which Forever's druids do not have
-- (Mainline/AlternatePowerBar.lua:2-5, 17-26). In Aquatic, Travel and Moonkin Form the power stays mana and the frame's own bar shows it, so the
-- bar shows only while UnitPowerType says plainly that the power is not mana (UnitDocumentation.lua:2859-2878, no secret tag; Enum.PowerType.Mana
-- is 0, PowerTypeConstantsDocumentation.lua:25), and a withheld answer keeps what shows. It is made for a druid alone (UnitClass plainly DRUID).
-- The bar: a StatusBar Mana bar height screen pixels high (4 at first, 2 to 12, laid out again out of combat), in the fill of the frame's power bar (Power bar texture, else the bar texture of the Flat UI page; a white
-- image for a solid fill) and the colour of mana (ns.PowerColour, with Muted colours as the frame's bars have it), with Flat UI's outline in the
-- look of the Unit frames page, both with the corners of Corners (a rounded line and background, and a mask of the radius on the fill; UnitFrames.lua,
-- X.ownCorners), changed with the row. A status bar with a texture takes withheld values and one without refuses them (HealthColour.lua, Probe), so it
-- always has one. It is fed UnitPowerMax and UnitPower of mana unread (SecretWhenUnitPowerMaxRestricted and SecretWhenUnitPowerRestricted,
-- UnitDocumentation.lua:2732-2734 and 2801-2803), which SetMinMaxValues and SetValue take (SimpleStatusBarAPIDocumentation.lua:229-237,
-- 355-363). It hangs under the power bar (ManaBarArea.ManaBar, 124 by 10 at TOPLEFT 87,-61 of the frame, Camelot/PlayerFrame.lua:91-96) as wide
-- as it. With Frame style Separate parts, or on a player frame Flat UI does not style, it hangs as far under it as the power bar hangs under the
-- health bar there: the two borders, at least 1 unit (Gap, UnitFrameCells.lua), so wherever Flat UI or the game puts the power bar the three bars
-- look alike; with the Power bar row off, whose bar is then transparent, it hangs that far under the health bar. In one frame
-- (ns.UnitFrameExtra.joined, UnitFrames.lua) it hangs under the whole frame, outside it: the frame's margin (a border thickness and Space between
-- parts), its border, the space and the bar's own border, so three thicknesses and twice the space in pixels; with the Power bar row off the frame
-- ends at the health bar, and the bar hangs from that. Its frame is a frame of the addon's own on the frame that
-- holds the bars (PlayerFrameContentMain), so it fades with the content of the frame, which Fading fades (Fade.lua:70), and stays when Power bar
-- makes the power bar transparent (UnitParts.lua, Power). It is made and laid out out of
-- combat, on a frame the game protects; it is no protected frame itself, so it shows and hides in a fight. While the options window is open, chat says
-- once a fight that the bar changes when the fight ends, as the row is turned on or Mana bar height changed in one. It hears UNIT_POWER_UPDATE and
-- UNIT_MAXPOWER of mana and UNIT_DISPLAYPOWER for the player on a frame of its own (RegisterUnitEvent, as UnitGroupMarks.lua hears the auras of
-- one member, so no other unit's power reaches Flat UI; UnitDocumentation.lua:4234-4243, 4406-4416, 4551-4561), and UPDATE_SHAPESHIFT_FORM
-- (SpellBookDocumentation.lua:989-994), only while it is wanted. The value glides to each new one (the interpolation ExponentialEaseOut of SetValue, never
-- withheld) where the client has it, but is set at once as the bar shows, or as it stops being the sample of test mode, since the mana it last had is
-- stale by then (nothing feeds a hidden bar). It fades in over 0.15 seconds as it shows and out over 0.2 as the druid shifts to a form with mana, with
-- Alpha animations of its own frame; the row going off, or the sample of test mode going, hides it at once. In test mode (TestMode.lua, TM.Watch) it
-- shows for a druid in any form, at 60% in caster form, and is painted again as the rows change; the real rule comes back as test mode ends. The
-- game's player frame is not changed: no field written, no method called.
-- Mana text (Percent by default; Current or None): a font string of the addon's own just right of the bar, on its frame, so it fades in and out with
-- it, in the face, outline and colour of the bar text rows of the Unit frames page (X.ownSpec, UnitText.lua) at Power text size (85% at first) of the
-- game's small font, as the player frame's power text has it (UnitFrames.lua ApplyText), and under Smaller, lighter bar text at 85% of that with no
-- outline unless Bar text outline gives one. Each feed
-- writes it unread: UnitPowerPercent of mana through the curve CurveConstants.ScaleTo100 (UnitDocumentation.lua:2838-2856, as UnitText.lua writes a
-- power percent) to SetFormattedText, or UnitPower of mana through AbbreviateNumbers (or BreakUpLargeNumbers with Number style Full) to SetText, both
-- of which take withheld values. The sample of test mode reads 60%, or 3.6K with Current.
-- Mark the cost of a shift (on by default): a thin white line of one screen pixel across the bar at the mana a cast of the form the druid is in costs
-- (Cat Form for a cat, Bear or Dire Bear Form for a bear), so fill past it means a powershift is affordable. The form is GetShapeshiftForm, its spell
-- the fourth answer of GetShapeshiftFormInfo (Blizzard_ActionBar/Shared/StanceBar.lua:70), its cost the mana entry (type 0) of
-- C_Spell.GetSpellPowerCost (SpellDocumentation.lua:535-549, SpellSharedDocumentation.lua:46-58, no secret tag), against UnitPowerMax of mana. The
-- line is placed only from plain numbers, a cost above 0 and below the most; where the game withholds one in a fight the line keeps its place while
-- the form is the same, hides for another form, and is placed again once the fight is over. It is placed again on a change of form, of the most mana
-- and of the layout. The sample of test mode in caster form has it at 35%.
-- This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLResourceBars/Init.lua:19, resourceBarsDruidFixedMana, a
-- Forever and TBC option whose bar is not in the package; EnhanceQoLUnitFrames/UF_Helper.lua:1773-1823, a druid's second power is mana, shown
-- while the main power is not): the mana of a druid in forms, here a bar under the game's player frame.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Druid mana"
-- The power type of mana (Enum.PowerType.Mana) and its token, the height of the bar in screen pixels where Mana bar height has none, and the fill of a
-- solid bar.
local MANA, TOKEN, HEIGHT_PX = 0, "MANA", 4
-- The units between the bar and its text, the size of the text against the game's small font where Power text size has none, and the mana the sample
-- of test mode shows with Current (its 60%).
local TEXT_GAP, TEXT_PERCENT, SAMPLE_MANA = 4, 85, 3600
-- Where the sample of test mode marks the cost of a shift, as a share of the bar, and the opacity of the line.
local SAMPLE_SHIFT, TICK_ALPHA = 0.35, 0.9
-- The seconds of the fade as the bar shows and as it goes.
local FADE_IN, FADE_OUT = 0.15, 0.2
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- The blue of a mana bar whose colour the game does not give (UnitFrames.lua, COLOUR.mana).
local BLUE = { 0, 0, 1 }
-- The events of the player's power, heard for the player alone, and the change of form.
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local EVENTS = { "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" }
local LINE_SHOWN = "Unit frames: Druid mana: shown under the player frame while your power is not mana."
local LINE_WAITS = "Unit frames: Druid mana: the bar waits for the end of the fight."
-- What chat says, once a fight and only while the options window is open, when the bar waits for the end of the fight to be made or hung again (Tell).
local TELL_WAITS = "Flat UI: the druid mana bar changes when the fight ends."
local LINE_REFUSED = "Unit frames: Druid mana: the game refused the texture of the bar, so it does not show."

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True for a druid: UnitClass gives the class file plainly (UnitDocumentation.lua:911-928).
local function Druid()
	if type(UnitClass) ~= "function" then
		return false
	end
	local ok, _, class = pcall(UnitClass, "player")
	return ok and not IsSecret(class) and class == "DRUID"
end

-- True while the bar is wanted: the module on, the row on, the part not stopped, and the player a druid.
local function Wanted()
	return ns.Enabled(KEY) and Opt("druidMana") == true and not ns.PartStopped(KEY, PART) and Druid()
end

-- The fill of the bar: the texture of the frame's power bar, a white image for a solid fill.
local function File()
	local file = X.fillFile("power")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

-- The frame the bar hangs from: the outlined power bar of a styled frame, else the game's power bar. On a styled frame with the Power bar row off
-- the power bar is transparent with no border (UnitParts.lua, Power), and in one frame the frame ends at the health bar (FRAME.powerOn in
-- UnitFrames.lua), so in either Frame style the bar hangs from the health bar, the usual gap under it, and not under an invisible bar.
local function Anchor(rec, joined)
	local power = rec.byRole and rec.byRole.power
	local health = rec.byRole and rec.byRole.health
	if health ~= nil and (joined or X.active(rec) == true) and (power == nil or Opt("playerPowerBar") == false) then
		return health.target
	end
	return power and power.target or rec.parts.power
end

-- The fades of the bar's frame: an Alpha animation from 0 to 1, and one from 1 to 0 that hides the frame as it ends and puts its opacity back, as the
-- Healer mana list has them (HealerMana.lua Fades). Nil for each where the client makes none.
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

-- The frame, the bar, its outline and the mask that cuts its fill to the corners, made once out of combat. Nil when the player frame has no bar to hang it from, or when the game refuses the
-- texture the bar needs, which is not tried again.
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
	-- The line of Mark the cost of a shift, over the fill, placed by Mark.
	local tick = bar:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[tick] = true
	tick:SetTexture(WHITE)
	tick:SetVertexColor(1, 1, 1, TICK_ALPHA)
	tick:Hide()
	d.tick = tick
	-- The mana text, on the frame that fades, just right of the bar.
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

-- Where the bar hangs: the bar it hangs from, the gap under it and the height, in the units of the frame, and the key of that layout. Nil when there
-- is no bar to hang from. In one frame the gap clears the frame's margin and border, and the key says so, so a change of Frame style hangs it again.
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

-- True while the bar hangs as the layout says.
local function Placed(rec, d)
	local anchor, _, _, key = Layout(rec, d)
	return anchor == nil or (d.placed == key and d.anchor == anchor)
end

-- Hangs the bar under the power bar, again only when the border thickness, the space, the scale, the frame style or the bar it hangs from changed.
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

-- The Mana text row: "pct", "cur" or nil for none.
local function TextMode()
	local mode = Opt("druidManaText")
	if mode == "pct" or mode == "cur" then
		return mode
	end
	return nil
end

-- A number of mana as the frame's bar text writes one: 12.3k, or 12,345 with Number style Full. The value goes through as it came.
local function Num(value)
	local call = Opt("numberStyle") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or BreakUpLargeNumbers
	if type(call) ~= "function" then
		return value
	end
	return call(value)
end

-- The format of a percent, the one the bar texts write with (UnitText.lua X.formats).
local function PctFormat()
	return type(X.formats) == "table" and X.formats.pct or "%.0f%%"
end

-- The fill, the colour of mana, the corners and the outline as the frame's bars have them, and the face of the mana text.
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
		-- Power text size, as the player frame's power text has it, and under Smaller, lighter bar text 85% of it with no outline unless Bar text
		-- outline gives one (UnitFrames.lua ApplyText).
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

-- A plain number of a call, or nil.
local function Plain(ok, value)
	if ok and ns.Finite(value) then
		return value
	end
	return nil
end

-- The spell of the form the druid is in (nil in caster form or where the game does not say), and the mana a cast of it costs and the most mana, both
-- plain, or nil.
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

-- Places the line of Mark the cost of a shift at share of the bar's width, or hides it with no share.
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

-- The line of Mark the cost of a shift: the sample's 35% in test mode in caster form, else the cost of the form the druid is in. Where a number is
-- withheld it keeps its place for the same form and hides for another, and Mark runs again once the fight is over.
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

-- Sets the value of a bar, gliding to it where the client has the interpolation (Enum.StatusBarInterpolation, never withheld), at once where it has not.
local function Glide(bar, value)
	local list = type(Enum) == "table" and Enum.StatusBarInterpolation or nil
	local how = type(list) == "table" and list.ExponentialEaseOut or nil
	if how ~= nil and pcall(bar.SetValue, bar, value, how) then
		return true
	end
	return pcall(bar.SetValue, bar, value)
end

-- The mana and its most, unread, onto the bar: at once with jump (a bar that just showed), else gliding.
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

-- True while test mode is on and not paused (TestMode.lua).
local function Testing()
	return ns.TestMode ~= nil and ns.TestMode.IsOn() == true
end

-- True while the power is plainly not mana. A withheld or missing answer keeps the last one.
local function InForm(d)
	local ok, kind = pcall(UnitPowerType, "player")
	if ok and ns.Finite(kind) then
		d.form = kind ~= MANA
	end
	return d.form == true
end

-- Shows the frame of the bar, fading in, a fade out stopped at once; or hides it, fading out with fade and at once without (or with no fades).
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

-- Shows the bar while the druid's power is not mana, with the mana on it. In test mode it shows in any form, a sample at 60% in caster form (d.sample),
-- so the look rows can be seen on it; the real rule comes back as test mode ends. It fades in as it shows and out as the druid shifts to a form with
-- mana; the row going off and the sample going hide it at once.
local function Show(d)
	local form = InForm(d)
	local show = Wanted() and (form or Testing())
	-- The bar was hidden or showed the sample: the mana on it is not the player's of now.
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
		-- Another power of the player changed: the mana did not.
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

-- The frame of the addon's own that hears the player's power while the bar is wanted, and nothing when it is not.
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
		-- A client that cannot hear one unit: every unit's event comes, and OnEvent keeps the player's.
		if not (ok and (IsSecret(done) or done ~= false)) then
			pcall(ear.RegisterEvent, ear, event)
		end
	end
	for _, event in ipairs(EVENTS) do
		pcall(ear.RegisterEvent, ear, event)
	end
	d.hearing = true
end

-- While the options window is open, chat says once a fight that the bar waits for its end, as Hide.lua and /flatui move say theirs, so Druid mana in
-- forms turned on or a new Mana bar height in a fight does not look broken. A refresh in a fight with the window closed stays silent. The flag goes once
-- the fight is over.
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

-- The bar of the player frame: made for a druid out of combat, laid out out of combat, and shown in any form whose power is not mana.
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
			-- Made on a frame the game protects, which waits for the end of the fight once.
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

-- The player frame's record is made for the frame whatever its row says, but the steps after a frame's work run only for a frame Flat UI styles,
-- so each Refresh looks at it as well: the bar also hangs under the game's own frame.
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

-- Test mode turned on or off, paused or resumed: the bar is shown, or not, by the rule of the moment.
if ns.TestMode then
	ns.TestMode.Watch(function()
		local rec = X.known(_G.PlayerFrame)
		if rec then
			X.run(PART, DruidMana, rec)
		end
	end)
end
