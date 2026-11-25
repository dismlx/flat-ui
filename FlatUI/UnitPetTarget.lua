local _, ns = ...

-- Pet target frame (off by default, Pet frame page): a small frame of Flat UI's own for what the pet attacks, the unit pettarget, which the game has
-- no frame for (Blizzard_UnitFrame has frames for the target of the target and of the focus, none for pettarget). It is a secure button of the
-- addon's own (SecureActionButtonTemplate) with no global name: a left click targets the unit (type1 target and unit pettarget, which the template
-- reads, Blizzard_FrameXML/SecureTemplates.lua:201-212 and 506-519, as SecureUnitButton_OnLoad sets up the game's own unit frames, :828-839). It
-- takes the release of the mouse button (RegisterForClicks AnyUp) with useOnKeyDown false, as the secure buttons of Reload.lua do: the game gives an
-- addon's button no isKeyPress or isSecureAction (SecureTemplates.xml:6-8), so while ActionButtonUseKeyDown is on, as it is by default, the button
-- would act on the press, which it does not hear, and the release would do nothing (SecureTemplates.lua:792-826). The game shows it only while
-- pettarget exists: RegisterUnitWatch hands it to the game's secure state driver, which shows and hides it in a fight too, at once, then every 0.2
-- seconds and at once again when a pet or a target changes (Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua:38-44, 56-63, 73-90, 119-139,
-- 166-170, 182-196), so no code of Flat UI's shows or hides it while it is watched. A secure button is protected, and setting or taking away the
-- watch writes an attribute of the game's protected state driver (:38-49, 178): the button is made, sized, placed and given attributes, and watched
-- or no longer watched, only out of combat, and a change asked for in a fight, a login in one included, waits for its end (ns.OutOfCombat). Off, the
-- watch is taken away (UnregisterUnitWatch, :47-49) and the button hidden, out of combat.
-- A right click opens the unit's menu (type2 togglemenu, which the game's secure code opens, SecureTemplates.lua:269-321, so Set Focus in it works): the
-- target menu, with Set Focus and the raid markers, while the unit is also your target, a player's menu for a player, and none for another creature,
-- for which the game names no menu (:288-310). Under the mouse it shows the unit's tooltip as the game's unit frames do (Mainline/UnitFrame.lua:
-- 387-410): GameTooltip at its default anchor, set again every 0.2 seconds through UpdateTooltip, a field of this button of the addon's own, and
-- hidden as the mouse leaves while the button still owns it.
-- Its children: a health bar in the reaction colour of Flat UI's unit frames (ns.ReactionColour; the Health colour of the Unit frames page when the
-- game withholds it, as UnitFrameLooks.lua falls back), full and grey with Dead at its right end while the unit is plainly dead, as the raid cells
-- draw a dead member, the name on it, the health in percent at its right end, and Flat UI's outline around it in the look of the Unit frames page.
-- The outline and the fill take the corners of Corners (UnitFrames.lua Round and Shape: a rounded line and background, and a mask of the radius on
-- the fill), out of combat. The raid marker of the unit sits just left of the frame while Raid marker on target, focus, boss and pet target frames
-- is on (the index of GetRaidTargetIndex goes unread to SetSpriteSheetCell, as UnitGroupMarks.lua has it, and the icon shows only when the client
-- took it), drawn again on RAID_TARGET_UPDATE. While the mouse is over the button and Highlight under the mouse is on, a white layer of its own over
-- the bar brightens it by the amount the unit frames use (UnitFrameLooks.lua, X.hoverAlpha), in the shape of the corners; the button is the addon's
-- own, so its OnEnter and OnLeave show and hide it. The name takes the face, size and outline of the name rows and the percent the face, outline and
-- colour of the bar text rows of the Unit frames page (UnitText.lua, X.ownSpec).
-- Border while it is not your target (on by default): a frame of its own over the bar, with edges of its own just outside the frame (and the rounded
-- line of Corners in their place while the corners are rounded) in Not your target colour (amber), shows while the pet's target is not your target,
-- you having none included, and hides once you are both on the same unit, also in a fight: the answer of UnitIsUnit(pettarget, target), which the game
-- may withhold, goes unread to SetAlphaFromBoolean, on each write of the frame and on PLAYER_TARGET_CHANGED. The sample of test mode shows it.
-- UnitHealth is always withheld and UnitHealthMax, UnitHealthPercent and UnitName may be (UnitDocumentation.lua:1472-1475, 1506-1529, 2489-2491): they
-- go unread to SetMinMaxValues, SetValue, SetFormattedText and SetText, which take them (SimpleStatusBarAPIDocumentation.lua:229-237, 355-363;
-- SimpleFontStringAPIDocumentation.lua:664-673), on a bar with a texture, which a bar needs to take them (HealthColour.lua, Probe). The value glides to
-- each new one (the interpolation ExponentialEaseOut of SetValue, never withheld, SimpleStatusBarConstantsDocumentation.lua:27-28) where the client has
-- it, but is set at once for a new unit and after a dead one, so the bar never slides from the last unit's health. They are written at once when the
-- frame shows, when the pet changes its target (UNIT_TARGET for pet) and when the player's pet changes (UNIT_PET for player; UnitDocumentation.lua:
-- 4448-4457, 4868-4877), and gliding on a step of 0.2 seconds while it shows, since the game sends no health event for pettarget; the step stops when
-- the frame hides. As the game shows the button, its bar and words fade in over 0.15 seconds (an Alpha animation of the bar of the addon's own, which
-- plays in a fight too); the game still shows and hides the button itself at once.
-- Test mode (TestMode.lua, TM.Register): a sample of the frame, a plain frame of the addon's own on UIParent that takes no mouse, with the same children,
-- painted and placed as the button is and filled with fixed values (Training Dummy at 65% in the hostile colour, with a Skull), shows while test mode is on, the row is
-- on and the game does not show the button; the button wins as soon as the game shows it. Nothing of it touches the secure button.
-- /flatui move places it (FlatUIPetTarget in Movers.lua: the frame's top left corner is the top left corner of the box, which is as wide as the frame,
-- ns.PetTargetWidth, and takes a new Pet target width at once while the boxes are open). With no spot saved the box is right of the pet frame where
-- the game's default layout puts it, its left edge fixed and a wider frame growing to the right (ns.PetTargetStart); a saved spot keeps its bottom
-- middle, as every box does. Nothing of the game is changed and none of the game's frames is touched; the button reads and writes nothing of the
-- click path of the game's action buttons (TaintScan.lua).
-- This follows EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Core/SharedAnchors.lua:124-128, the pet target anchor
-- on Forever; EnhanceQoLUnitFrames/UF_Helper.lua:320-328, the colours of a unit that is no player for pettarget on Forever;
-- UF_StandaloneCastbar.lua:57-60, its anchor for a cast bar): a pet target frame in the reaction colour. Its frame code is not in the package, and
-- its cast bar is left out.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Pet target frame"
local MOVER = "FlatUIPetTarget"
local UNIT = "pettarget"
-- The box of the handle in Movers.lua: the frame at the default width, its bottom middle this far from the bottom middle of the screen, right of
-- the bars of the pet frame in the game's default layout: the player frame, 232 by 100, has its bottom right corner 300 left of and 250 above the
-- bottom middle of the screen (Blizzard_EditMode/Mainline/EditModePresetLayouts.lua:249-260, Blizzard_UnitFrame/Mainline/PlayerFrame.xml:13-14),
-- and the pet frame, 120 by 49, lies in the container under it, 160 wide with its top 30 right of and 25 above the frame's bottom middle
-- (PlayerFrame.xml:477-484, Shared/PlayerFrameTemplates.xml:4-10, PetFrame.xml:11-16), its bars 11 and 7 tall (Camelot/PetFrame.lua:14-22,
-- Mainline/PetFrame.xml:133-134).
local BOX_W, BOX_H, BOX_X, BOX_Y = 120, 20, -246, 238
-- The height of the frame, the room between its edge and the name, the step while it shows, the seconds of the fade of its bar as it shows, and the
-- font of the name.
local HEIGHT, INSET, TICK, FADE_IN = 20, 4, 0.2, 0.15
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MARKER = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local LINE_BROKEN = "Unit frames: Pet target frame: the game did not make the frame, so it does not show until /reload."
local LINE_NO_WATCH = "Unit frames: Pet target frame: this client has no unit watch, so the frame does not show."
local LINE_WAITS = "Unit frames: Pet target frame: a change waits for the end of the fight."
-- The grey of a dead unit's bar, the hostile colour of the sample while the Colours page has no reaction colours of its own (the game's, UnitSelectionColor),
-- and the sample of test mode: its name and how full its bar is, in percent.
local GREY = 0.5
local HOSTILE = { 1, 0, 0 }
local SAMPLE = { name = "Training Dummy", share = 65 }

local IsSecret = ns.IsSecret

-- button: the secure button once made (frame: the same), broken: it could not be made and is not tried again. bar, name, pct, outline: its children.
-- watched: the game watches it. width, placed, file: what was last set. later: a change waits for the end of the fight. ticker: the token of the step.
-- S: the sample of test mode, with the same fields.
local P = { button = nil, broken = false, watched = false, later = false }
local S = {}

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True in combat lockdown (RestrictedActionsDocumentation.lua:45-52), when nothing may change on a secure button. A withheld answer counts as a
-- fight.
local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, value = pcall(InCombatLockdown)
	return not ok or IsSecret(value) or value == true
end

-- A timer of the client, false when there is none or it raises.
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

-- The fill of the bar: the texture of the frames' health bars, a white image for a solid fill.
local function File()
	local file = X.fillFile("health")
	if file == nil then
		file = ns.BarTexture()
	end
	return file or WHITE
end

-- What is shown --------------------------------------------------------------------------------------------------------------------------------

-- True when the client says so plainly: a withheld answer is no.
local function Yes(ok, value)
	return ok and not IsSecret(value) and value == true
end

-- The format of the percent, the one the bar texts of the unit frames write (UnitText.lua, X.formats).
local function Format()
	return type(X.formats) == "table" and X.formats.pct or "%.0f%%"
end

-- Sets the value of a bar, gliding to it where the client has the interpolation, at once where it has not. False when the client refuses the value.
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

-- The cell of a marker on the sheet of the eight icons, 4 by 4 (UnitGroupMarks.lua Cell). True when the icon shows a marker.
local function Cell(icon, index)
	if type(icon.SetSpriteSheetCell) == "function" then
		return (pcall(icon.SetSpriteSheetCell, icon, index, 4, 4))
	elseif ns.Finite(index) then
		local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
		return (pcall(icon.SetTexCoord, icon, column / 4, (column + 1) / 4, row / 4, (row + 1) / 4))
	end
	return false
end

-- The raid marker of the unit, or of the sample (index 8, Skull), while Raid marker on target, focus, boss and pet target frames is on. The index the game
-- withholds goes unread to the icon.
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

-- The border of Border while it is not your target: shown while the pet's target is not your target, or the sample's while the row is on. The
-- answer of UnitIsUnit, which the game may withhold (UnitDocumentation.lua:2410-2425), goes unread to SetAlphaFromBoolean, which takes it
-- (SimpleFrameAPIDocumentation.lua:1145-1155). No answer, or the row off, hides it.
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

-- The health, the percent, the name, the colour and the raid marker of the unit, unread where the game withholds them. A unit that is plainly dead has a
-- full grey bar and says Dead. jump: a new unit, or a bar that just showed, takes its value at once; so does the first living unit after a dead one.
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
	Marker(P)
	Warn(P)
end

-- The step of 0.2 seconds while the frame shows. A client without NewTicker gets a timer that sets the next one while the token is the step's, as
-- the Healer mana list has it.
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

-- The bar and its words fade in as the game shows the button: the Alpha animation of the bar of the addon's own (Children), which is no protected
-- frame, so it plays in a fight too.
local function FadeIn(t)
	local group = t.fadeIn
	if group ~= nil then
		pcall(group.Stop, group)
		pcall(group.Play, group)
	end
end

-- The game showed or hid the button. The sample of test mode makes way for it, and comes back after it.
local function OnShow()
	X.run(PART, Fill, true)
	FadeIn(P)
	Tick(true)
	X.run(PART, P.SampleOn)
end

local function OnHide()
	if P.lit then
		P.lit:Hide()
	end
	Tick(false)
	X.run(PART, P.SampleOn)
end

-- The button ------------------------------------------------------------------------------------------------------------------------------------

-- The unit's tooltip, as the game's unit frames give it (Mainline/UnitFrame.lua:387-410): at the default anchor, and set again by the tooltip every 0.2
-- seconds through UpdateTooltip while the mouse stays.
local function Tooltip(self)
	if type(GameTooltip_SetDefaultAnchor) ~= "function" or type(GameTooltip) ~= "table" then
		return
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(UNIT)
	GameTooltip:Show()
	self.UpdateTooltip = Tooltip
end

-- The layer of Highlight under the mouse shows while the mouse is over the button and the row is on.
local function OnEnter(self)
	if P.lit then
		P.lit:SetShown(Opt("hoverHighlight") == true)
	end
	if not pcall(Tooltip, self) then
		self.UpdateTooltip = nil
	end
end

local function OnLeave(self)
	if P.lit then
		P.lit:Hide()
	end
	self.UpdateTooltip = nil
	if type(GameTooltip) == "table" then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, self)
		if Yes(ok, owned) then
			pcall(GameTooltip.Hide, GameTooltip)
		end
	end
end

-- The children of the button or of the sample, on frame, into t: the bar, the percent at its right end, the name left of it, the outline, the mask that
-- cuts the fill to the corners, the raid marker left of the frame and the layer of Highlight under the mouse. Raises when the game refuses one.
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
	-- The fade of the bar and its words as the button shows (FadeIn): from 0 to 1, none where the client makes no animation.
	local okGroup, group = pcall(bar.CreateAnimationGroup, bar)
	local okFade, fade = false, nil
	if okGroup and group ~= nil then
		okFade, fade = pcall(group.CreateAnimation, group, "Alpha")
	end
	if okFade and fade ~= nil and pcall(fade.SetFromAlpha, fade, 0) and pcall(fade.SetToAlpha, fade, 1) and pcall(fade.SetDuration, fade, FADE_IN) then
		t.fadeIn = group
	end
	t.outline = ns.Outline(frame, frame, true)
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
	-- The border of Border while it is not your target: a frame over the bar with edges of its own (no background) just outside the frame, and a
	-- texture for the rounded line of Corners in their place, at alpha 0 until Warn sets it.
	local level = frame:GetFrameLevel()
	local warn = X.frame(frame, X.number(level) and level + 2 or nil)
	warn:SetAllPoints(frame)
	warn:SetAlpha(0)
	local edges = ns.Outline(warn, warn)
	if edges ~= nil then
		ns.SetOutlineArea(edges, KEY)
		ns.SetOutline(edges, true, false)
	end
	local line = warn:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Own[line] = true
	line:Hide()
	t.warn, t.warnOutline, t.warnLine = warn, edges, line
end

-- Made once, out of combat: the button, its bar, the name and the percent on it and the outline. False when the game refuses it, which is not tried again.
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
		-- The game runs a click on the key press by default (ActionButtonUseKeyDown); the button listens for the release.
		button:SetAttribute("useOnKeyDown", false)
		button:SetAttribute("type1", "target")
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

-- The corners of Corners on the outline and the fill of the button or the sample (UnitFrames.lua, X.ownCorners), out of combat as Paint is, and the
-- highlight in the same shape (the crisp square while the corners are square).
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

-- The colour of the border of Border while it is not your target, and its edges, or the rounded line of Corners in their place while the frame's own
-- outline draws its rounded line (as HealthColour.lua Rounded has it for the low health border).
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

-- The width of the frame: Pet target width, or the default while the row has no plain number.
local function Width()
	local width = Opt("petTargetWidth")
	return ns.Finite(width) and width > 0 and width or BOX_W
end

-- The width of its row, the look of the Unit frames page, its corners and the text rows, on the button or the sample. True when the width changed.
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
		ns.TextStyle(t.name, X.ownSpec("name", { percent = 100 }))
		ns.TextStyle(t.pct, X.ownSpec("bar", { percent = 100 }))
	end
	return resized
end

-- The open boxes of /flatui move take a new width at once (Movers.lua, BoxSize), and the frame is placed again from the box's new spot.
local function Resized()
	P.placed, S.placed = nil, nil
	if type(ns.MoverRelabel) == "function" then
		pcall(ns.MoverRelabel)
	end
end

-- Puts the button or the sample at the spot of its handle: its top left corner at the top left corner of the box.
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

-- Hands the button to the game's unit watch, which shows it at once if the pet has a target.
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

-- A change asked for in a fight waits for its end, once. A module that stopped in the fight runs nothing more, so its button is put away then.
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

-- Takes the watch away and hides the button, out of combat.
function Off()
	if not P.button then
		return
	end
	if not P.watched and not Shown() then
		Tick(false)
		return
	end
	if Fighting() then
		Later()
		return
	end
	if P.watched and type(UnregisterUnitWatch) == "function" and pcall(UnregisterUnitWatch, P.button) then
		P.watched = false
	end
	pcall(P.button.Hide, P.button)
	Tick(false)
end

-- After each Refresh of the unit frames, and when the spot changed: the button made, sized, placed and watched out of combat, or put away.
function P.Update()
	if not Wanted() then
		Off()
		return
	end
	if Fighting() then
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

-- Test mode -------------------------------------------------------------------------------------------------------------------------------------

-- The sample: a plain frame of the addon's own on UIParent, made once out of combat, that takes no mouse. False when the game refuses it, which is not
-- tried again.
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

-- The fixed values of the sample: its name, 65% and the hostile colour of the unit frames (the Colours page's own while Custom reaction colours is on).
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
	bar:SetStatusBarColor(r, g, b, 1)
	Marker(S, true)
	Warn(S, true)
end

-- Shows the sample, painted, placed and filled, while test mode is on, the row is on and the game does not show the button, and hides it otherwise. Its
-- Start, and each change of a setting while it runs.
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

-- The movers ----------------------------------------------------------------------------------------------------------------------------------

-- True while the frame has a handle in the movers: while the row is on.
function ns.PetTargetShown()
	return ns.Enabled(KEY) and Opt("petTarget") == true
end

-- The width of the box of the handle (widthOf in Movers.lua): the frame's own, Pet target width.
function ns.PetTargetWidth()
	return Width()
end

-- Where the box starts while no spot is saved (start in Movers.lua): its bottom middle moved by half of what the frame is wider than the default, so
-- that its left edge stays where the game's layout leaves room right of the pet frame, and the frame grows to the right.
function ns.PetTargetStart(x, y)
	return x + (Width() - BOX_W) / 2, y
end

-- The movers set or put back the spot, which the button takes out of combat.
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

-- The pet changed its target, or the player's pet changed (jump: a new unit, whose value is set at once), or a raid marker or your target changed:
-- the frame, if it shows, is written again.
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
-- Your target changed: the border of Border while it is not your target follows at once.
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
