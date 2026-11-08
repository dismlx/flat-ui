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
-- Its children: a health bar in the reaction colour of Flat UI's unit frames (ns.ReactionColour; the Health colour of the Unit frames page when the
-- game withholds it, as UnitFrameLooks.lua falls back), the name on it, and Flat UI's outline around it in the look of the Unit frames page.
-- UnitHealth is always withheld and UnitHealthMax and UnitName may be (UnitDocumentation.lua:1472-1475, 1526-1529, 2489-2491): they go unread to
-- SetMinMaxValues, SetValue and SetText, which take them (SimpleStatusBarAPIDocumentation.lua:229-237, 355-363; SimpleFontStringAPIDocumentation.lua:
-- 664-673), on a bar with a texture, which a bar needs to take them (HealthColour.lua, Probe). They are written when the frame shows, when the pet
-- changes its target (UNIT_TARGET for pet), when the player's pet changes (UNIT_PET for player; UnitDocumentation.lua:4448-4457, 4868-4877), and on
-- a step of 0.2 seconds while it shows, since the game sends no health event for pettarget; the step stops when the frame hides.
-- /flatui move places it (FlatUIPetTarget in Movers.lua: the frame's top left corner is the top left corner of the box). With no spot saved the box
-- is right of the pet frame where the game's default layout puts it. Nothing of the game is changed and none of the game's frames is touched; the
-- button reads and writes nothing of the click path of the game's action buttons (TaintScan.lua).
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
-- The height of the frame, the room between its edge and the name, the step while it shows, and the font of the name.
local HEIGHT, INSET, TICK = 20, 4, 0.2
local FONT = "GameFontHighlightSmall"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local LINE_BROKEN = "Unit frames: Pet target frame: the game did not make the frame, so it does not show until /reload."
local LINE_NO_WATCH = "Unit frames: Pet target frame: this client has no unit watch, so the frame does not show."
local LINE_WAITS = "Unit frames: Pet target frame: a change waits for the end of the fight."

local IsSecret = ns.IsSecret

-- button: the secure button once made, broken: it could not be made and is not tried again. bar, name, outline: its children. watched: the game
-- watches it. width, placed, file: what was last set. later: a change waits for the end of the fight. ticker: the token of the step.
local P = { button = nil, broken = false, watched = false, later = false }

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

-- The health, the name and the colour of the unit, unread where the game withholds them.
local function Fill()
	local bar, name = P.bar, P.name
	if not bar then
		return
	end
	local okMost, most = pcall(UnitHealthMax, UNIT)
	if okMost then
		pcall(bar.SetMinMaxValues, bar, 0, most)
	end
	local ok, health = pcall(UnitHealth, UNIT)
	if ok then
		pcall(bar.SetValue, bar, health)
	end
	local okName, text = pcall(UnitName, UNIT)
	if okName and (IsSecret(text) or type(text) == "string") then
		name:SetText(text)
	else
		name:SetText("")
	end
	local r, g, b = ns.ReactionColour(UNIT)
	if r == nil then
		r, g, b = ns.Colour(KEY .. ".healthColour")
	end
	if type(X.mute) == "function" then
		r, g, b = X.mute(r, g, b)
	end
	pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
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

-- The game showed or hid the button.
local function OnShow()
	X.run(PART, Fill)
	Tick(true)
end

local function OnHide()
	Tick(false)
end

-- The button ------------------------------------------------------------------------------------------------------------------------------------

-- Made once, out of combat: the button, its bar, the name on it and the outline. False when the game refuses it, which is not tried again.
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
		button:SetAttribute("unit", UNIT)
		local bar = CreateFrame("StatusBar", nil, button)
		ns.Own[bar] = true
		bar:SetAllPoints(button)
		bar:SetStatusBarTexture(WHITE)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		local name = ns.OwnText(bar, "OVERLAY", FONT)
		name:SetJustifyH("LEFT")
		name:SetWordWrap(false)
		name:SetPoint("LEFT", bar, "LEFT", INSET, 0)
		name:SetPoint("RIGHT", bar, "RIGHT", -INSET, 0)
		P.bar, P.name, P.file = bar, name, WHITE
		P.outline = ns.Outline(button, button, true)
		button:SetScript("OnShow", OnShow)
		button:SetScript("OnHide", OnHide)
	end)
	if not ok then
		pcall(button.Hide, button)
		P.broken = true
		return false
	end
	P.button = button
	return true
end

-- The width of its row and the look of the Unit frames page.
local function Paint()
	local width = Opt("petTargetWidth")
	width = ns.Finite(width) and width or BOX_W
	if P.width ~= width and pcall(P.button.SetSize, P.button, width, HEIGHT) then
		P.width = width
	end
	local file = File()
	if P.file ~= file then
		local ok, done = pcall(P.bar.SetStatusBarTexture, P.bar, file)
		if not ok or (not IsSecret(done) and done == false) then
			pcall(P.bar.SetStatusBarTexture, P.bar, WHITE)
		end
		P.file = file
	end
	if P.outline then
		ns.SetOutlineEdges(P.outline, Opt("barBorder") ~= false)
		X.outline(P.outline, true, Opt("backdrop"))
	end
end

-- Puts the button at the spot of its handle: its top left corner at the top left corner of the box.
local function Place()
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, "TOPLEFT")
	end
	local key = x and ("%.2f:%.2f"):format(x, y) or "start"
	if P.placed == key then
		return
	end
	local button = P.button
	local ok = pcall(function()
		button:ClearAllPoints()
		if x then
			button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		else
			button:SetPoint("TOPLEFT", UIParent, "BOTTOM", BOX_X - BOX_W / 2, BOX_Y + BOX_H)
		end
	end)
	if ok then
		P.placed = key
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
	Paint()
	Place()
	if Watch() and Shown() then
		Fill()
	end
end

-- The movers ----------------------------------------------------------------------------------------------------------------------------------

-- True while the frame has a handle in the movers: while the row is on.
function ns.PetTargetShown()
	return ns.Enabled(KEY) and Opt("petTarget") == true
end

-- The movers set or put back the spot, which the button takes out of combat.
function ns.PetTargetMoved()
	P.placed = nil
	if P.button then
		if Fighting() then
			Later()
		else
			X.run(PART, P.Update)
		end
	end
end

-- The pet changed its target, or the player's pet changed: the frame, if it shows, is written again.
local function Changed()
	if Shown() then
		Fill()
	end
end

ns.AddEvent(KEY, "UNIT_TARGET", function()
	X.run(PART, Changed)
end, function(unit)
	return not IsSecret(unit) and unit == "pet"
end)
ns.AddEvent(KEY, "UNIT_PET", function()
	X.run(PART, Changed)
end, function(unit)
	return not IsSecret(unit) and unit == "player"
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
