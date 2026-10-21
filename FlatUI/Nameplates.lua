local _, ns = ...

-- The thick dark band around a nameplate's health bar is the bar's background texture, the gold
-- outline is its target marker, and the level box is one piece of art. They are faded and
-- replaced by a backdrop and thin edges. The target and focus are marked by edge colour.
-- Text sizes, the health bar fill and the bar heights are set again on the next frame after the game lays a plate out
-- (UpdateAnchors puts them back): when the plate gets its unit, and after the game's nameplate options change. Class icons are frames of the addon's own beside the health bar. An elite, a rare or a boss
-- has a mark after its level number and a coloured border, and any plate can have a fading row behind its name.

local KEY = "nameplates"
local AURA_OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local AURA_MASK = "UI-HUD-CoolDownManager-Mask"
local AURA_CROP = 0.08
-- The game's own size of the raid marker (Blizzard_NamePlates.xml, RaidTargetFrame).
local MARK_SIZE = 22
-- The regions the switches of the health bar art hide, by the name they have on the health bar, the unit frame or the raid marker frame.
local ART = {
	heal = { "myHealPrediction", "otherHealPrediction" },
	absorb = { "totalAbsorb", "totalAbsorbOverlay", "overAbsorbGlow" },
	healAbsorb = { "myHealAbsorb", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overHealAbsorbGlow" },
	camera = { "behindCameraIcon" },
	marker = { "RaidTargetIcon" },
}
-- Parts other files add to the plates: functions in each list, called with the unit frame and what this file keeps of it (show, layout, leave),
-- or with nothing (refresh).
local EXTRA = { show = {}, layout = {}, leave = {}, refresh = {}, options = {}, status = {} }
-- The look of aura icons when no row changes them.
local STOCK = { key = "stock", crop = AURA_CROP, timers = true, stacks = true, stock = true }
-- Nameplate units between a class icon and what it sits beside.
local GAP = 3
-- Class icon art, in the order it is tried.
local CLASS_ART = { "classicon-%s", "groupfinder-icon-class-%s" }
local PLAIN_FONT, OUTLINED_FONT = "SystemFont_NamePlate", "SystemFont_NamePlate_Outlined"
local BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
local CLASSIC_FILL = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
local NAME_TEXT, HEALTH_TEXTS, LEVEL_TEXT = { "name" }, { "Text", "LeftText", "RightText" }, { "playerLevelDiffText" }
local LEVEL_FONT = "SystemFont_NamePlateLevel"
-- What a plate shows for each kind of unit: the mark after the level, the colour of the border, and for a Rare Elite a
-- second line of another colour inside it.
local KINDS = ns.KINDS
-- The row that colours the border of each kind (the line inside a Rare Elite's border takes the Elite row), and the colour each row has until
-- it is changed. At its default a row gives the colour of KINDS itself, so that nothing is rounded.
local KIND_ROWS = { elite = "eliteColour", rare = "rareColour", rareelite = "rareColour", boss = "bossColour" }
local KIND_DEFAULTS = { eliteColour = "ffffd100", rareColour = "ffc7ccd6", bossColour = "ffff593d" }
-- The thickness in screen pixels of the border of an elite, a rare or a boss, and of the line inside a Rare Elite's.
local KIND_PX, INNER_PX = 2, 1
-- Nameplate units between the level number and its mark.
local MARK_GAP = 1
-- The row behind the name keeps this share of the brightness of the health bar, and is this opaque at its bottom and its top.
local ROW_SHARE, ROW_BOTTOM, ROW_TOP = 0.7, 0.95, 0.05
local ROW_NOTE = "Name row: the game cannot draw a gradient, so no row is shown."

-- known: every nameplate tried. plates: those styled without an error. active: those that have a unit now.
local known = setmetatable({}, { __mode = "k" })
local plates = setmetatable({}, { __mode = "k" })
local active = setmetatable({}, { __mode = "k" })
local auraItems = setmetatable({}, { __mode = "k" })
local auraQueue = {}
local markQueued, scanQueued, aurasQueued, releaseQueued = false, false, false, false
-- What the next MarkTargets looks at: the plates asked for, or every plate when markAll. markedTarget and markedFocus
-- are the plates it took for the target and the focus last time.
local marks, markAll = {}, false
local markedTarget, markedFocus
local aurasStopped = false
-- driverFollowed: true while the game's nameplate driver is followed, false when it cannot be, nil before the first try.
local driverFollowed
-- Class token to its atlas, or false when the client has no art for it.
local classAtlas = {}
local classQueue, classAll, classQueued = {}, false, false
local layoutQueued, sizesQueued = false, false
-- layoutFresh: every request for the queued layout came after the game laid the plates out. optionsPending: the game's options changed since the last layout.
local layoutFresh, optionsPending = true, false
local QueueAuras
-- True while the plates wait for the end of combat to get what a protected frame would not take.
local kindsWaiting = false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- Runs fn on the next frame, or at once when the client has no timer.
local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

local function UnitFrameOf(unit)
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or ns.IsSecret(plate) or plate == nil then
		return nil
	end
	local unitFrame = plate.UnitFrame
	if ns.Forbidden(unitFrame) then
		return nil
	end
	return unitFrame
end

-- The frame itself, or nil when it is missing, withheld or forbidden.
local function Usable(frame)
	if not ns.Forbidden(frame) then
		return frame
	end
end

-- The health bar, the level frame and the cast bar, each tested before anything is read from it.
local function Parts(unitFrame)
	local container, castContainer = Usable(unitFrame.HealthBarsContainer), Usable(unitFrame.CastBarsContainer)
	return container and Usable(container.healthBar), Usable(unitFrame.PlayerLevelDiffFrame), castContainer and Usable(castContainer.castBar)
end

-- An outline for a frame, made the first time it is wanted.
local function Wanted(own, key, frame, wanted)
	if not own[key] and wanted and frame and not ns.Forbidden(frame) then
		own[key] = ns.Outline(frame, frame)
	end
	return own[key]
end

-- True for a value Blizzard's code wrote that the client has not withheld and that has the type asked for.
local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

-- False for a friendly plate while Restyle friendly nameplates is off. isFriend is final only after the unit is set, so a plate whose answer
-- changes is styled again (QueueClass).
local function On(unitFrame)
	if Opt("friendly") then
		return true
	end
	local friend = unitFrame.isFriend
	return not (Plain(friend, "boolean") and friend)
end

local function SetAlpha(region, alpha)
	if region ~= nil and not ns.IsSecret(region) then
		pcall(region.SetAlpha, region, alpha)
	end
end

-- Hides the named regions of owner while `faded` and brings them back after. At the default nothing is called.
local function Fade(own, key, faded, owner, names)
	if owner and (faded or own[key]) then
		for _, name in ipairs(names) do
			ns.SetFaded(owner[name], faded)
		end
		own[key] = faded or nil
	end
end

-- The numbers Blizzard lays nameplates out with, a global table of plain values.
local function Setup()
	local options = NamePlateSetupOptions
	if Plain(options, "table") then
		return options
	end
end

-- A size from that table, when it is a number above zero.
local function Size(options, key)
	local value = options[key]
	if Plain(value, "number") and value > 0 then
		return value
	end
end

local function AnchorStyles()
	local constants = NamePlateConstants
	local styles = Plain(constants, "table") and constants.NAME_ANCHOR_STYLES
	if Plain(styles, "table") then
		return styles
	end
end

-- True when Blizzard puts the unit name inside the health bar.
local function NameInside(options)
	local styles, style = AnchorStyles(), options.unitNameAnchorStyle
	return styles ~= nil and Plain(style, "number") and style == styles.InsideHealthBar
end

-- The font object Blizzard gives the name and the health text, as GetNamePlateFontObject does.
local function BlizzardFont(options)
	local styles, style = AnchorStyles(), options.unitNameAnchorStyle
	local outlinedAbove = options.useOutlinedFontWhenAboveHealthBar
	if styles and Plain(style, "number") and style ~= styles.InsideHealthBar and style ~= styles.CenteredAboveHealthBar
		and not (style == styles.AboveHealthBar and Plain(outlinedAbove, "boolean") and outlinedAbove) then
		return PLAIN_FONT
	end
	return OUTLINED_FONT
end

-- The frame the level box border follows: the level frame's sides and the health bar's top and
-- bottom, since Blizzard's level frame is taller than the bar. It is made once for a plate, and the
-- level frame itself is used when it cannot be made.
local function LevelSpan(own, level, healthBar)
	if own.span == nil then
		own.span = false
		if not ns.Forbidden(healthBar) then
			local span = CreateFrame("Frame", nil, level)
			ns.Own[span] = true
			if pcall(function()
				span:SetPoint("LEFT", level, "LEFT", 0, 0)
				span:SetPoint("RIGHT", level, "RIGHT", 0, 0)
				span:SetPoint("TOP", healthBar, "TOP", 0, 0)
				span:SetPoint("BOTTOM", healthBar, "BOTTOM", 0, 0)
			end) then
				own.span = span
			end
		end
		if not own.span then
			ns.Note(KEY, "Level box: its border could not follow the health bar and follows the default box.")
		end
	end
	return own.span or level
end

-- Applies the current options to one nameplate. Turning a part off puts Blizzard's art back.
local function Apply(unitFrame)
	local own = known[unitFrame] or {}
	known[unitFrame] = own
	local styled = On(unitFrame)
	own.styleOn = styled
	local on = ns.Enabled(KEY) and styled
	local healthBar, level, castBar = Parts(unitFrame)

	-- The replacement is made first, so a failure never leaves a bar with no frame at all.
	local border = on and Opt("health")
	local levelStyle = on and Opt("level") or "default"
	local castBorder = on and Opt("cast")
	ns.SetOutline(Wanted(own, "health", healthBar, border), border, Opt("healthBackdrop"))
	if levelStyle == "box" and not own.level and level and not ns.Forbidden(level) then
		own.level = ns.Outline(level, LevelSpan(own, level, healthBar))
	end
	-- The box follows Health bar background only while Health bar border is on, which is when that switch can be used.
	ns.SetOutline(own.level, levelStyle == "box", not border or Opt("healthBackdrop"))
	ns.SetOutline(Wanted(own, "cast", castBar, castBorder), castBorder, Opt("castBackdrop"))

	if healthBar then
		ns.SetFaded(healthBar.bgTexture, border)
		-- Blizzard's gold outline stays when this addon draws no target border of its own.
		ns.SetFaded(healthBar.selectedBorder, border and Opt("target"))
		-- Reaches past the top and bottom of the bar on every plate that is not the target.
		if border and Opt("dim") then
			SetAlpha(healthBar.deselectedOverlay, Opt("dimAmount") / 100)
		else
			ns.SetFaded(healthBar.deselectedOverlay, border and not Opt("dim"))
		end
		Fade(own, "healFade", on and not Opt("healPrediction"), healthBar, ART.heal)
		Fade(own, "absorbFade", on and not Opt("absorbs"), healthBar, ART.absorb)
		Fade(own, "healAbsorbFade", on and not Opt("healAbsorbs"), healthBar, ART.healAbsorb)
	end
	Fade(own, "cameraFade", on and not Opt("offscreenIcon"), Usable(unitFrame), ART.camera)
	Fade(own, "markerFade", on and not Opt("raidMarker"), Usable(unitFrame.RaidTargetFrame), ART.marker)
	if level then
		ns.SetFaded(level.playerLevelDiffIcon, levelStyle ~= "default")
		-- Blizzard's own target marker on the level box stays with its gold outline.
		ns.SetFaded(level.selectedBorder, levelStyle ~= "default" and border and Opt("target"))
	end
	if castBar then
		ns.SetFaded(castBar.Background, castBorder)
		ns.SetFaded(castBar.Border, castBorder)
	end
	if castBar and ns.CastFill then
		-- A plate Blizzard has taken back has no cast to follow.
		ns.CastFill(KEY, castBar, (active[unitFrame] and on and Opt("castFlat") and not ns.PartStopped(KEY, "cast bar fill")) and true or false)
	end
	if not plates[unitFrame] then
		-- Known and counted once it has been styled without an error.
		plates[unitFrame] = own
		ns.Count(KEY)
	end
end

-- Red, green and blue of the border of a kind, or of the line inside a Rare Elite's border with `inner`.
local function KindColour(kind, inner)
	local look = KINDS[kind]
	local row = inner and "eliteColour" or KIND_ROWS[kind]
	local own = look and (inner and look.inner or look.colour)
	if not (row and own) then
		return nil
	end
	local path = KEY .. "." .. row
	if ns.Get(path) == KIND_DEFAULTS[row] then
		return own[1], own[2], own[3]
	end
	return ns.Colour(path)
end

-- The colour and thickness of the border of one plate: the target and the focus have their own, and so does the kind of
-- unit on every other plate. The health border gets the kind's colour, and a Rare Elite's line inside it shows with it.
local function Mark(unitFrame, mark, target, focus, kinds)
	local own = plates[unitFrame]
	if not own then
		return
	end
	local r, g, b, px
	if mark and unitFrame == target then
		r, g, b = ns.Colour(KEY .. ".targetColour")
		px = Opt("targetThickness")
	elseif mark and unitFrame == focus then
		r, g, b = ns.Colour(KEY .. ".focusColour")
		px = Opt("targetThickness")
	end
	ns.SetOutlineColour(own.level, r, g, b)
	ns.SetOutlineThickness(own.level, px)
	if r == nil and own.base then
		r, g, b, px = own.base[1], own.base[2], own.base[3], own.base[4]
	end
	local look = kinds and own.kind and KINDS[own.kind]
	local inner = false
	if look and r == nil then
		r, g, b = KindColour(own.kind)
		px = KIND_PX
		if look.inner and own.rim then
			-- The line is drawn over the inner pixels of this border.
			px, inner = px + INNER_PX, true
			ns.SetOutlineColour(own.rim, KindColour(own.kind, true))
		end
	end
	ns.SetOutlineColour(own.health, r, g, b)
	ns.SetOutlineThickness(own.health, px)
	ns.SetOutline(own.rim, inner, false)
end

local function Include(set, unitFrame)
	if unitFrame then
		set[unitFrame] = true
	end
end

-- The plate frames themselves are compared, so no unit comparison the client can withhold is needed.
local function MarkTargets()
	local mark = ns.Enabled(KEY) and Opt("health") and Opt("target")
	local kinds = ns.Enabled(KEY) and Opt("health") and Opt("kindBorder")
	local targetOnly = ns.Enabled(KEY) and Opt("aurasWhen") == "target"
	local target, focus = UnitFrameOf("target"), UnitFrameOf("focus")
	local all, asked = markAll, marks
	markAll, marks = false, {}
	-- Blizzard recolours its own markers on the plates that stop or start being the target or the focus, which can bring
	-- them back, and on no others.
	local moved = {}
	if target ~= markedTarget then
		Include(moved, markedTarget)
		Include(moved, target)
	end
	if focus ~= markedFocus then
		Include(moved, markedFocus)
		Include(moved, focus)
	end
	markedTarget, markedFocus = target, focus
	for unitFrame in pairs(moved) do
		if plates[unitFrame] and not ns.Forbidden(unitFrame) then
			ns.Each(KEY, Apply, unitFrame)
			if targetOnly then
				QueueAuras(unitFrame)
			end
		end
		asked[unitFrame] = true
	end
	for unitFrame in pairs(all and plates or asked) do
		Mark(unitFrame, mark, target, focus, kinds)
	end
end

-- Blizzard's nameplate code handles the same events, so mark on the next frame: the plate given, every plate with all,
-- and the plates that stop or start being the target or the focus.
local function QueueMark(unitFrame, all)
	Include(marks, unitFrame)
	markAll = markAll or all == true
	if markQueued then
		return
	end
	markQueued = true
	Soon(function()
		markQueued = false
		if not ns.IsStopped(KEY) then
			ns.Try(KEY, MarkTargets)
		end
	end)
end

local function AuraMask(item)
	local icon = item.Icon
	if icon and not ns.IsSecret(icon) and icon.GetMaskTexture then
		local ok, mask = pcall(icon.GetMaskTexture, icon, 1)
		if ok and not ns.IsSecret(mask) and mask ~= nil then
			return mask
		end
	end
	return ns.RegionWithAtlas(item, AURA_MASK)
end

-- What the rows say of the aura icons: the crop, the colour of the border (none for the general one), and the two switches.
local function AuraLook()
	local look = { crop = Opt("auraCrop") / 100, timers = Opt("auraTimers"), stacks = Opt("auraStacks") }
	if Opt("auraBorderOwn") then
		look.r, look.g, look.b = ns.Colour(KEY .. ".auraBorderColour")
	end
	look.stock = look.timers and look.stacks
	look.key = ("%s:%s:%s:%s:%s:%s"):format(look.crop, tostring(look.timers), tostring(look.stacks), tostring(look.r), tostring(look.g), tostring(look.b))
	return look
end

-- The game sets the countdown numbers of an icon on each refresh of its aura and this runs after, so the numbers stay hidden. What the game
-- had set is given back when they are switched on again.
local function Countdown(item, own, hidden)
	local cooldown = item.Cooldown
	if cooldown == nil or ns.IsSecret(cooldown) or (not hidden and own.hideWas == nil) then
		return
	end
	if hidden then
		local ok, now = pcall(cooldown.GetHideCountdownNumbers, cooldown)
		-- The game's value is recorded on every pass while the numbers are hidden.
		if ok and Plain(now, "boolean") and now == false then
			own.hideWas = false
		elseif own.hideWas == nil then
			own.hideWas = (ok and Plain(now, "boolean") and now) or false
		end
		pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
	else
		pcall(cooldown.SetHideCountdownNumbers, cooldown, own.hideWas)
		own.hideWas = nil
	end
end

-- Aura icons: each has a rounded mask and a thick overlay with no key.
local function StyleAura(item, on, look)
	local own = auraItems[item]
	if not own then
		if not on and look.stock then
			return
		end
		own = { outline = ns.SetOutlineArea(ns.Outline(item, item), KEY), overlay = ns.RegionWithAtlas(item, AURA_OVERLAY), mask = AuraMask(item), sig = false }
		auraItems[item] = own
		if on and not own.overlay then
			ns.Note(KEY, "Aura icons: the default frame was not found and is still shown.")
		end
		if on and not own.mask then
			ns.Note(KEY, "Aura icons: the round mask was not found, so corners stay rounded.")
		end
	end
	if on and not own.outline then
		own.outline = ns.Outline(item, item)
	end
	local sig = on and look.key or false
	if own.sig ~= sig then
		own.sig = sig
		ns.SetOutline(own.outline, on, false)
		ns.SetOutlineColour(own.outline, on and look.r or nil, on and look.g or nil, on and look.b or nil)
		ns.SetFaded(own.overlay, on)
		local icon = item.Icon
		if icon and not ns.IsSecret(icon) then
			if on then
				icon:SetTexCoord(look.crop, 1 - look.crop, look.crop, 1 - look.crop)
			else
				icon:SetTexCoord(0, 1, 0, 1)
			end
			if own.mask then
				pcall(on and icon.RemoveMaskTexture or icon.AddMaskTexture, icon, own.mask)
			end
		end
	end
	Countdown(item, own, not look.timers)
	local counts = item.CountFrame
	if counts ~= nil and not ns.IsSecret(counts) and (not look.stacks or own.stacksFaded) then
		ns.SetFaded(counts.Count, not look.stacks)
		own.stacksFaded = not look.stacks or nil
	end
end

-- The opacity of the icons of one plate: the row's, or none for a plate that is not the target while Show auras says only the target has them.
local function AurasAlpha(unitFrame, aurasFrame, styled)
	local own = known[unitFrame]
	local alpha = 1
	if styled then
		alpha = Opt("auraOpacity") / 100
		if Opt("aurasWhen") == "target" and not (Plain(unitFrame.isTarget, "boolean") and unitFrame.isTarget) then
			alpha = 0
		end
	end
	if own and (own.aurasAlpha or 1) ~= alpha then
		pcall(aurasFrame.SetAlpha, aurasFrame, alpha)
		own.aurasAlpha = alpha ~= 1 and alpha or nil
	end
end

local function StyleAuras(unitFrame)
	local aurasFrame = unitFrame.AurasFrame
	if ns.Forbidden(aurasFrame) then
		return
	end
	local styled = ns.Enabled(KEY) and On(unitFrame)
	AurasAlpha(unitFrame, aurasFrame, styled)
	local pool = aurasFrame.auraItemFramePool
	if ns.IsSecret(pool) or type(pool) ~= "table" or not pool.EnumerateActive then
		return
	end
	local on = styled and Opt("auras")
	local look = styled and AuraLook() or STOCK
	for item in pool:EnumerateActive() do
		if not ns.Forbidden(item) then
			StyleAura(item, on, look)
		end
	end
	-- The loss of control icon is the same kind of icon and is not in the pool.
	local lossOfControl = aurasFrame.LossOfControlFrame
	local item = lossOfControl and not ns.IsSecret(lossOfControl) and lossOfControl.AuraItemFrame
	if item and not ns.Forbidden(item) then
		StyleAura(item, on, look)
	end
end

-- Blizzard lays the icons out on the same events, so look on the next frame.
function QueueAuras(unitFrame)
	if aurasStopped then
		return
	end
	auraQueue[unitFrame] = true
	if aurasQueued then
		return
	end
	aurasQueued = true
	Soon(function()
		aurasQueued = false
		local queue = auraQueue
		auraQueue = {}
		for queuedFrame in pairs(queue) do
			if not aurasStopped and not ns.Forbidden(queuedFrame) then
				local ok, err = pcall(StyleAuras, queuedFrame)
				if not ok then
					-- Aura icons are one part of the module. A failure here leaves the rest running.
					aurasStopped = true
					ns.Note(KEY, "Aura icons: stopped. " .. tostring(err))
				end
			end
		end
	end)
end

-- Bar heights, the health bar fill and text -------------------------------------------------

local Layout, QueueLayout

-- Runs one part of the layout for one plate. A module that is off, or a part that is stopped, runs
-- with `on` false, which puts Blizzard's look back. The plate that stops a part goes back at once,
-- since the failed call may have changed it after Blizzard's layout, and every other plate on the
-- next frame.
local function RunPart(part, fn, unitFrame, own, ...)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, own, false, ...)
	elseif not ns.EachPart(KEY, part, fn, unitFrame, own, ns.Enabled(KEY) and On(unitFrame), ...) and ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, own, false)
		QueueLayout()
	end
end

-- A size or place could not be set. In combat every plate is laid out again when combat ends. what is the name of the setting on the page.
local function QueueSizes(what)
	local height = what == "Bar height"
	if not InCombatLockdown() then
		ns.Note(KEY, height and "Bar height: the game does not allow nameplate bars to be resized." or (what .. ": the game does not allow this on nameplates."))
		return
	end
	ns.Note(KEY, height and "Bar height: nameplates that appear in combat get their height when combat ends." or (what .. ": nameplates that appear in combat get it when combat ends."))
	if not sizesQueued then
		sizesQueued = true
		ns.OutOfCombat(function()
			sizesQueued = false
			for unitFrame, own in pairs(plates) do
				if not ns.Forbidden(unitFrame) then
					pcall(Layout, unitFrame, own, false)
				end
			end
		end)
	end
end

-- Whether the game lets addon code set the size of a Blizzard frame now.
local function Resizable(frame)
	local check = C_RestrictedActions and C_RestrictedActions.CheckAllowProtectedFunctions
	if check then
		local ok, allowed = pcall(check, frame, true)
		if ok and Plain(allowed, "boolean") then
			return allowed
		end
	end
	return not InCombatLockdown()
end

local function CanResize(what, ...)
	for i = 1, select("#", ...) do
		if not Resizable((select(i, ...))) then
			QueueSizes(what)
			return false
		end
	end
	return true
end

-- Both bars are a percent of the height Blizzard gives them. At 100 nothing is called, and a height
-- set earlier goes back to Blizzard's. Blizzard's code reads no height back, and only UpdateAnchors
-- (the health bar) and ApplyFrameOptions (the cast bar) set one.
local function Heights(unitFrame, own, on, fresh)
	local options = Setup()
	if not options then
		return
	end
	-- The Classic style draws the bars inside border art of a fixed size.
	local classic = (Plain(options.useClassicHealthBar, "boolean") and options.useClassicHealthBar)
		or (Plain(options.useClassicCastBar, "boolean") and options.useClassicCastBar)
	local container, base = unitFrame.HealthBarsContainer, Size(options, "healthBarHeight")
	if base and not ns.Forbidden(container) then
		local pct = on and not classic and Opt("healthHeight") or 100
		if pct ~= 100 then
			if CanResize("Bar height", container) then
				container:SetHeight(base * pct / 100)
				own.height = true
			end
		elseif own.height then
			if fresh then
				-- UpdateAnchors has just set Blizzard's height.
				own.height = nil
			elseif CanResize("Bar height", container) then
				container:SetHeight(base)
				own.height = nil
			end
		end
	end
	local castContainer = unitFrame.CastBarsContainer
	local castBar = not ns.Forbidden(castContainer) and castContainer.castBar
	local castBase = Size(options, "castBarHeight")
	-- Blizzard's own sum: the icon and the spell name sit below the bar unless the name is inside it.
	local inside = options.spellNameInsideCastBar
	local extra = Plain(inside, "boolean") and (inside and 0 or Size(options, "castIconHeight"))
	if castBase and extra and not ns.Forbidden(castBar) then
		local pct = on and not classic and Opt("castHeight") or 100
		if pct ~= 100 then
			if CanResize("Bar height", castContainer, castBar) then
				-- Marked first, so a failure between the two calls still leaves a restore to do.
				own.castHeight = true
				castContainer:SetHeight(castBase * pct / 100 + extra)
				castBar:SetHeight(castBase * pct / 100)
			end
		elseif own.castHeight and CanResize("Bar height", castContainer, castBar) then
			-- A bare UpdateAnchors does not set the cast heights, so this is done on every pass.
			castContainer:SetHeight(castBase + extra)
			castBar:SetHeight(castBase)
			own.castHeight = nil
		end
	end
end

-- The width of a plate as the game gives it: its own base width when it has one, else the width of the style times the horizontal scale.
local function PlateWidth(options)
	local driver, constants = NamePlateDriverFrame, NamePlateConstants
	local base = Plain(driver, "table") and driver.baseNamePlateWidth
	if Plain(base, "number") and base > 0 then
		return base
	end
	local width, scale = Plain(constants, "table") and constants.NAME_PLATE_WIDTH, options.horizontalScale
	if Plain(width, "number") and Plain(scale, "number") then
		return width * scale
	end
end

-- Both bars are a percent of the width Blizzard gives them: the cast bars container is drawn narrower from both sides, and the health bar,
-- the name, the level box and the icons hang from it. UpdateAnchors sets the two anchors, so a width set earlier is set again after it.
local function Widths(unitFrame, own, on, fresh)
	local options = Setup()
	local container, inset = unitFrame.CastBarsContainer, options and Size(options, "insetWidth")
	if not inset or ns.Forbidden(container) then
		return
	end
	-- The Classic style draws the bars inside border art of a fixed size.
	local health, cast = options.useClassicHealthBar, options.useClassicCastBar
	local classic = (Plain(health, "boolean") and health) or (Plain(cast, "boolean") and cast)
	local pct = on and not classic and Opt("barWidth") or 100
	if pct ~= 100 then
		local width = PlateWidth(options)
		if width and CanResize("Bar width", container) then
			local edge = inset + (100 - pct) / 200 * (width - 2 * inset)
			own.width = true
			container:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOMLEFT", edge, 0)
			container:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -edge, 0)
		end
	elseif own.width then
		if fresh == true then
			own.width = nil
		elseif CanResize("Bar width", container) then
			container:SetPoint("BOTTOMLEFT", unitFrame, "BOTTOMLEFT", inset, 0)
			container:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -inset, 0)
			own.width = nil
		end
	end
end

-- The anchor the game gave a frame: point, frame, point of that frame and the two offsets, or false.
local function Anchor(frame)
	local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
	if ok and Plain(point, "string") and relative ~= nil and not ns.Forbidden(relative) and Plain(relativePoint, "string")
		and Plain(x, "number") and Plain(y, "number") then
		return { point, relative, relativePoint, x, y }
	end
	return false
end

-- The height of the health bar as Heights sets it, from the numbers the game lays plates out with (no frame size is read, since it can be
-- withheld), and whether the Classic style is on.
local function BarHeight(options, on)
	local base = Size(options, "healthBarHeight")
	if base then
		local classic = (Plain(options.useClassicHealthBar, "boolean") and options.useClassicHealthBar)
			or (Plain(options.useClassicCastBar, "boolean") and options.useClassicCastBar)
		return base * ((on and not classic) and Opt("healthHeight") or 100) / 100, classic
	end
end

-- The room a shown class icon takes on a side of the bar: its size and its gap. The icon is above the name in name-only mode.
local function ClassRoom(own, side)
	if own.classShown and own.iconSide == side then
		return own.iconSize + own.iconGap
	end
	return 0
end

-- The level box as a square the height of the health bar, beside the bar. UpdateAnchors keeps room for the box at its width plus the
-- offset of its anchor, so with the size and the anchor set here the right end of the plate's guide is the right end of the box. The
-- game's size, offset 5, health bar end and aura offsets go back when the part turns off (Blizzard_NamePlateUnitFrame.lua:239, 683-715, 872-878).
local LEVEL_KEPT = "Level box: the game keeps its own box width."
local function LevelBox(unitFrame, own, on, fresh)
	local options = Setup()
	local level, container, cast = Usable(unitFrame.PlayerLevelDiffFrame), Usable(unitFrame.HealthBarsContainer), Usable(unitFrame.CastBarsContainer)
	if not (options and level and container and cast) then
		return
	end
	local h, classic = BarHeight(options, on)
	local ok, shown = pcall(level.IsShown, level)
	shown = ok and Plain(shown, "boolean") and shown
	local want = on and h and not classic and Opt("level") ~= "default" and Opt("levelShape") == "square" and shown
	if not want then
		own.levelKept = nil
	end
	if (not want or own.levelKept) and not own.levelBox then
		return
	end
	local auras = Usable(unitFrame.AurasFrame)
	local control, lost = Usable(auras and auras.CrowdControlListFrame), Usable(auras and auras.LossOfControlFrame)
	local skull = level.highLevelTexture
	if ns.IsSecret(skull) or type(skull) ~= "table" then
		skull = nil
	end
	local spacing = Plain(options.castBarToHealthBarSpacing, "number") and options.castBarToHealthBarSpacing
	if not spacing or not CanResize("Level box", level, container, control or level, lost or level) then
		return
	end
	if want then
		local gap = Opt("levelGap")
		-- Marked first, so a failure between the calls still leaves a restore to do.
		own.levelBox = true
		level:SetSize(h, h)
		level:SetPoint("LEFT", container, "RIGHT", gap, 0)
		if skull then
			skull:SetSize(h, h)
		end
		container:SetPoint("BOTTOMRIGHT", cast, "TOPRIGHT", -(h + gap), spacing)
		local aura = 5 + h + gap + ClassRoom(own, "right")
		if control then
			control:SetPoint("LEFT", container, "RIGHT", aura, 0)
		end
		if lost then
			lost:SetPoint("LEFT", container, "RIGHT", aura, 0)
		end
		local read, width = pcall(level.GetWidth, level)
		if read and Plain(width, "number") and math.abs(width - h) > 0.5 then
			-- The game keeps its width: its own layout goes back and later passes leave it.
			own.levelKept = true
			ns.Note(KEY, LEVEL_KEPT)
		else
			ns.ClearNote(KEY, LEVEL_KEPT)
			return
		end
	end
	local width, height = Size(options, "playerLevelDiffWidth"), Size(options, "playerLevelDiffHeight")
	if width and height then
		level:SetSize(width, height)
		level:SetPoint("LEFT", container, "RIGHT", 5, 0)
		if skull then
			skull:SetSize(height, height)
		end
		-- A hidden level frame takes no room.
		local room = shown and width + 5 or 0
		container:SetPoint("BOTTOMRIGHT", cast, "TOPRIGHT", -room, spacing)
		if control then
			control:SetPoint("LEFT", container, "RIGHT", 5 + room, 0)
		end
		if lost then
			lost:SetPoint("LEFT", container, "RIGHT", 5 + room, 0)
		end
	end
	own.levelBox = nil
end

-- Size and place of the raid marker. The game sets its anchor in UpdateAnchors, above the name in name-only mode, and that one is not moved.
-- The offsets are added to the game's own anchor, which is read after every UpdateAnchors.
local function Marker(unitFrame, own, on, fresh)
	local frame = unitFrame.RaidTargetFrame
	if ns.Forbidden(frame) then
		return
	end
	local size = on and Opt("raidMarkerSize") or MARK_SIZE
	local x, y = on and Opt("raidMarkerX") or 0, on and Opt("raidMarkerY") or 0
	-- A class icon on the left takes the slot beside the bar, so the marker moves out past it.
	x = x - ClassRoom(own, "left")
	if Plain(unitFrame.showOnlyName, "boolean") and unitFrame.showOnlyName then
		x, y = 0, 0
	end
	-- The game never sets the size after the plate is made, so a size is set when it differs from the one set last.
	if size ~= (own.markSized or MARK_SIZE) and CanResize("Raid marker", frame) then
		own.markSized = size ~= MARK_SIZE and size or nil
		frame:SetSize(size, size)
	end
	local want = (x ~= 0 or y ~= 0) and (x .. "," .. y) or nil
	-- UpdateAnchors has just reset the anchor, so an offset set earlier is gone.
	if fresh then
		own.markMoved = nil
	elseif own.markMoved then
		-- A pass Flat UI did not see (name-only mode on) can have moved the game's anchor: the marker is then not where it was put.
		local now, base = Anchor(frame), own.markBase
		local at = own.markAt
		-- A change of the game's Debuff padding re-anchors the marker at the same point, so the offset is compared too.
		if not (now and base and at and now[1] == base[1] and now[2] == base[2]
			and math.abs(now[4] - at[1]) < 0.01 and math.abs(now[5] - at[2]) < 0.01) then
			own.markMoved = nil
		end
	end
	if own.markMoved ~= want then
		if not own.markMoved then
			own.markBase = Anchor(frame)
		end
		local base = own.markBase
		if base and CanResize("Raid marker", frame) then
			own.markMoved = want
			own.markAt = { base[4] + x, base[5] + y }
			frame:SetPoint(base[1], base[2], base[3], base[4] + x, base[5] + y)
		end
	end
end

-- The health bar fill is a plain white texture or the image file of the chosen bar texture, and the bar
-- takes the colour Blizzard gives it.
local function Fill(unitFrame, own, on, fresh)
	local healthBar = Parts(unitFrame)
	local fill = not ns.Forbidden(healthBar) and healthBar.barTexture
	if ns.IsSecret(fill) or not fill then
		return
	end
	if on and Opt("healthFlat") then
		-- Blizzard's colour is taken first and given back after. It is never looked at.
		local r, g, b, a = healthBar:GetStatusBarColor()
		-- Marked before the first change, so a failure after it still leaves a restore to do.
		own.flat = true
		local texture = ns.BarTexture(Opt("healthTexture"))
		if texture then
			fill:SetTexture(texture)
		else
			fill:SetColorTexture(1, 1, 1, 1)
		end
		healthBar:SetStatusBarColor(r, g, b, a)
	elseif own.flat then
		own.flat = nil
		if not fresh then
			-- The line UpdateAnchors uses, under the condition it uses.
			local options = Setup()
			if options and Plain(options.useClassicHealthBar, "boolean") and options.useClassicHealthBar then
				fill:SetTexture(CLASSIC_FILL)
			else
				fill:SetAtlas(BAR_ATLAS, true)
			end
		end
	end
end

-- The font strings of a frame that exist and have not been withheld.
local function Strings(owner, keys)
	local list = {}
	if not ns.Forbidden(owner) then
		for _, key in ipairs(keys) do
			local fontString = owner[key]
			if not ns.IsSecret(fontString) and fontString ~= nil then
				list[#list + 1] = fontString
			end
		end
	end
	return list
end

-- The font object of a string. Blizzard colours the name again after its own call and the addon
-- does not, so the name's colour is given back after this one.
local function SetFont(fontString, object, keepColour)
	local ok, r, g, b, a
	if keepColour then
		ok, r, g, b, a = pcall(fontString.GetVertexColor, fontString)
	end
	fontString:SetFontObject(object)
	if ok and (ns.IsSecret(a) or a ~= nil) then
		fontString:SetVertexColor(r, g, b, a)
	end
end

-- Size and outline of one group of font strings. `pct` is a percent of Blizzard's size `base`, and
-- `font` the font object Blizzard gives the group (none for the level, which has one). own[key] is
-- "sized" while the addon has changed the height and "plain" once it has changed the font object
-- too, so only what was changed is put back. The name also gets the last line Blizzard runs on it,
-- which makes the scaled text a real font height.
local function SetText(own, key, strings, pct, outlined, base, font)
	local changed = pct ~= 100 or not outlined
	if not base or #strings == 0 or (not changed and not own[key]) then
		return
	end
	if changed then
		-- Marked before the first call, so a failure halfway still leaves a restore to do. "plain"
		-- stays until the end, since it is also what puts the font object back.
		own[key] = (outlined and own[key] ~= "plain") and "sized" or "plain"
	end
	for _, fontString in ipairs(strings) do
		if font and own[key] == "plain" then
			SetFont(fontString, outlined and font or PLAIN_FONT, key == "name")
		end
		fontString:SetTextHeight(changed and base * pct / 100 or base)
		if key == "name" then
			fontString:SetFontHeight(fontString:GetLineHeight())
		end
	end
	own[key] = changed and (outlined and "sized" or "plain") or nil
end

local function Texts(unitFrame, own, on)
	local options = Setup()
	if not options then
		return
	end
	local healthBar, level = Parts(unitFrame)
	local health = Strings(healthBar, HEALTH_TEXTS)
	local font, base = BlizzardFont(options), Size(options, "healthBarFontHeight")
	SetText(own, "name", Strings(unitFrame, NAME_TEXT), on and Opt("nameSize") or 100, not on or Opt("nameOutline"), base, font)
	SetText(own, "healthText", health, on and Opt("healthTextSize") or 100, not on or Opt("healthTextOutline"), base, font)
	SetText(own, "levelText", Strings(level, LEVEL_TEXT), on and Opt("levelSize") or 100, true, Size(options, "levelFontHeight"))
	-- Blizzard shows, hides and empties the health text, and never sets its alpha.
	local hide = on and not Opt("healthText")
	if hide or own.textHidden then
		for _, fontString in ipairs(health) do
			ns.SetFaded(fontString, hide)
		end
		own.textHidden = hide or nil
	end
end

-- Class icons ------------------------------------------------------------------------------

local function AtlasExists(name)
	local api = C_Texture
	if Plain(api, "table") then
		if type(api.GetAtlasExists) == "function" then
			local ok, exists = pcall(api.GetAtlasExists, name)
			return ok and Plain(exists, "boolean") and exists
		elseif type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			return ok and info ~= nil
		end
	end
	return false
end

-- The atlas of a class token, or nil when the client has no art for that class.
local function AtlasFor(token)
	local atlas = classAtlas[token]
	if atlas == nil then
		atlas = false
		for _, pattern in ipairs(CLASS_ART) do
			local name = pattern:format(token:lower())
			if AtlasExists(name) then
				atlas = name
				break
			end
		end
		classAtlas[token] = atlas
		if not atlas then
			ns.Note(KEY, "Class icons: no class art was found for a class, so it has no icon.")
		end
	end
	return atlas or nil
end

-- The frames of a class icon, made the first time one is shown on this plate. The guide is the row
-- that holds the health bar, the gap and the level box, whether or not the level box is shown.
local function Icon(own, unitFrame)
	if own.icon == nil then
		own.icon = false
		local health, cast = unitFrame.HealthBarsContainer, unitFrame.CastBarsContainer
		if not ns.Forbidden(health) and not ns.Forbidden(cast) then
			local guide = CreateFrame("Frame", nil, unitFrame)
			ns.Own[guide] = true
			guide:SetPoint("LEFT", cast, "LEFT", 0, 0)
			guide:SetPoint("RIGHT", cast, "RIGHT", 0, 0)
			guide:SetPoint("TOP", health, "TOP", 0, 0)
			guide:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
			local icon = CreateFrame("Frame", nil, unitFrame)
			ns.Own[icon] = true
			local art = icon:CreateTexture(nil, "ARTWORK", nil, 0)
			ns.Own[art] = true
			art:SetAllPoints(icon)
			art:Hide()
			own.guide, own.art = guide, art
			own.iconOutline = ns.Outline(icon, icon)
			own.icon = icon
		end
	end
	return own.icon or nil
end

local function PlaceIcon(unitFrame, own)
	local position, size, x, y = Opt("classPosition"), Opt("classSize"), Opt("classX"), Opt("classY")
	local gap, fit = Opt("classGap"), Opt("classFit")
	-- The bar and the level box are hidden in name-only mode, and the icon goes above the name.
	local nameOnly = Plain(unitFrame.showOnlyName, "boolean") and unitFrame.showOnlyName
	if nameOnly then
		position = "above"
	end
	-- The name sits above the bar unless Blizzard puts it inside.
	local options, lift = Setup(), 0
	if options and not NameInside(options) then
		local spacing = nameOnly and 2 or Size(options, "healthBarToNameAboveSpacing") or 0
		lift = spacing + (Size(options, "healthBarFontHeight") or 0) * Opt("nameSize") / 100
	end
	local h = fit == "bar" and options and BarHeight(options, true)
	if h then
		size = h
	end
	local place = ("%s:%s:%s:%s:%s:%s:%s"):format(position, size, x, y, lift, fit, gap)
	own.iconSide, own.iconSize, own.iconGap = position, size, gap
	if own.iconPlace == place then
		return
	end
	local icon, guide = own.icon, own.guide
	icon:SetSize(size, size)
	icon:ClearAllPoints()
	if position == "left" then
		icon:SetPoint("RIGHT", guide, "LEFT", x - gap, y)
	elseif position == "right" then
		icon:SetPoint("LEFT", guide, "RIGHT", x + gap, y)
	elseif position == "above" then
		icon:SetPoint("BOTTOM", guide, "TOP", x, y + lift + GAP)
	else
		icon:SetPoint("TOP", unitFrame.CastBarsContainer, "BOTTOM", x, y - GAP)
	end
	own.iconPlace = place
end

local function HideIcon(own)
	if own.classShown then
		own.art:Hide()
		ns.SetOutline(own.iconOutline, false, false)
		own.classShown = nil
	end
end

-- Decides whether a plate shows a class icon. Blizzard's isPlayer and isFriend are final only after
-- a unit has been set, so this is not done when the plate is laid out.
local function SetClassIcon(unitFrame, own, on)
	local unit, isPlayer, isFriend = unitFrame.unit, unitFrame.isPlayer, unitFrame.isFriend
	local widgetsOnly = unitFrame.widgetsOnlyMode
	if not on or not Plain(unit, "string") or not Plain(isPlayer, "boolean") or not isPlayer
		or not Plain(isFriend, "boolean") or ns.IsSecret(widgetsOnly) or widgetsOnly == true
		or not Opt(isFriend and "classFriendly" or "classEnemy") then
		return HideIcon(own)
	end
	local ok, token = pcall(UnitClassBase, unit)
	if not ok or not Plain(token, "string") or token == "" then
		-- No class yet, or the client withholds it.
		return HideIcon(own)
	end
	local atlas = AtlasFor(token)
	local icon = atlas and Icon(own, unitFrame)
	if not icon then
		return HideIcon(own)
	end
	if own.classAtlas ~= atlas then
		own.art:SetAtlas(atlas)
		own.classAtlas = atlas
	end
	PlaceIcon(unitFrame, own)
	own.art:Show()
	local border = Opt("classBorder")
	ns.SetOutline(own.iconOutline, border, border)
	own.classShown = true
end

-- The icon takes room beside the bar and the aura icons, so when it shows or hides the level box and the raid marker are placed again.
local function ClassIcon(unitFrame, own, on)
	local was = own.classShown
	SetClassIcon(unitFrame, own, on)
	if was ~= own.classShown then
		RunPart("level box", LevelBox, unitFrame, own, false)
		RunPart("raid marker", Marker, unitFrame, own, false)
	end
end

-- The class icon's share of the layout: hidden while the plate has no unit, placed again otherwise.
local function IconLayout(unitFrame, own, on)
	if not own.icon then
		return
	end
	local unit = unitFrame.unit
	if not on or (not ns.IsSecret(unit) and unit == nil) then
		HideIcon(own)
	elseif own.classShown then
		PlaceIcon(unitFrame, own)
	end
end

-- Elite, rare and boss -------------------------------------------------------------------------

-- "boss", "rareelite", "rare" or "elite" for the unit of a plate, and nil for any other unit. UnitClassification is the
-- call Blizzard's classification frame makes with the unit of the plate.
local function KindOf(unitFrame)
	return ns.UnitKind(unitFrame.unit)
end

-- True in combat when the frame is protected or cannot be asked: the game takes nothing new on it then, so the plates are laid
-- out again when combat ends.
local function Waiting(frame)
	if InCombatLockdown() then
		local ok, protected = pcall(frame.IsProtected, frame)
		if not ok or ns.IsSecret(protected) or protected then
			if not kindsWaiting then
				kindsWaiting = true
				ns.OutOfCombat(function()
					kindsWaiting = false
					QueueLayout()
				end)
			end
			return true
		end
	end
	return false
end

local function IsShown(region)
	local ok, shown = pcall(region.IsShown, region)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- The height of the level number: Blizzard's level font height at the Level number size.
local function MarkHeight()
	local options = Setup()
	local base = options and Size(options, "levelFontHeight")
	return base and base * Opt("levelSize") / 100
end

-- The mark after the level number. It is a font string on the level frame, so it goes with that frame, and it hangs from the
-- level text, so it moves with it. Blizzard hides the number of a unit whose level shows as a skull or ??, and the mark goes too.
local function KindMark(unitFrame, own, on)
	local _, level = Parts(unitFrame)
	local levelText = Strings(level, LEVEL_TEXT)[1]
	local look = on and Opt("kindMark") and own.kind and KINDS[own.kind]
	local mark = own.mark
	if not (look and look.mark and levelText and IsShown(levelText)) then
		if mark and own.markShown then
			mark:Hide()
			own.markShown = nil
		end
		return
	end
	if not mark then
		if Waiting(level) then
			return
		end
		mark = level:CreateFontString(nil, "OVERLAY")
		ns.Own[mark] = true
		own.mark = mark
	end
	if not own.markAnchored then
		mark:SetFontObject(LEVEL_FONT)
		mark:SetPoint("LEFT", levelText, "RIGHT", MARK_GAP, 0)
		own.markAnchored = true
	end
	local height = MarkHeight()
	if height and own.markHeight ~= height then
		mark:SetTextHeight(height)
		own.markHeight = height
	end
	if own.markKind ~= own.kind then
		mark:SetText(look.mark)
		mark:SetTextColor(look.colour[1], look.colour[2], look.colour[3])
		own.markKind = own.kind
	end
	if not own.markShown then
		mark:Show()
		own.markShown = true
	end
end

-- The gold line inside the silver border of a Rare Elite: a second outline, on a frame of its own that lies over the
-- health bar. Mark colours it and shows it.
local function KindRim(unitFrame, own, on)
	local healthBar = Parts(unitFrame)
	if own.rim or not (on and Opt("health") and Opt("kindBorder") and own.kind == "rareelite" and healthBar) or Waiting(healthBar) then
		return
	end
	local frame = CreateFrame("Frame", nil, healthBar)
	ns.Own[frame] = true
	frame:SetAllPoints(healthBar)
	own.rim = ns.Outline(frame, frame)
	local inner = KINDS.rareelite.inner
	ns.SetOutlineThickness(own.rim, INNER_PX)
	ns.SetOutlineColour(own.rim, inner[1], inner[2], inner[3])
	ns.SetOutline(own.rim, false, false)
	QueueMark(unitFrame)
end

-- The colour of the health bar at the share of its brightness the row keeps, or nil while the game withholds it.
local function RowColour(healthBar)
	local ok, r, g, b = pcall(healthBar.GetStatusBarColor, healthBar)
	if ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number") then
		return r * ROW_SHARE, g * ROW_SHARE, b * ROW_SHARE
	end
end

-- Fills the row from the colour at the bottom to the same colour nearly clear at the top. Blizzard's own nameplate code gives
-- the lower colour first. False when the client cannot do it.
local function FillRow(row, r, g, b)
	return type(row.SetGradient) == "function" and pcall(function()
		row:SetGradient("VERTICAL", CreateColor(r, g, b, ROW_BOTTOM), CreateColor(r, g, b, ROW_TOP))
	end)
end

-- The row behind the name: a texture of the unit frame that is as wide as the health bar and one unit taller than the name
-- text above and below, in the colour the game gave the health bar.
local function NameRow(unitFrame, own, on)
	local healthBar = Parts(unitFrame)
	local name = Strings(unitFrame, NAME_TEXT)[1]
	local r, g, b
	if on and Opt("nameRow") and active[unitFrame] and healthBar and name then
		r, g, b = RowColour(healthBar)
	end
	local row = own.row
	if r == nil then
		if row and own.rowShown then
			row:Hide()
			own.rowShown = nil
		end
		return
	end
	if not row then
		if type(CreateColor) ~= "function" then
			ns.Note(KEY, ROW_NOTE)
			return
		end
		if Waiting(unitFrame) then
			return
		end
		row = unitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
		ns.Own[row] = true
		own.row = row
		row:Hide()
		row:SetPoint("LEFT", healthBar, "LEFT", 0, 0)
		row:SetPoint("RIGHT", healthBar, "RIGHT", 0, 0)
		row:SetPoint("TOP", name, "TOP", 0, 1)
		row:SetPoint("BOTTOM", name, "BOTTOM", 0, -1)
	end
	local colour = ("%.3f,%.3f,%.3f"):format(r, g, b)
	if own.rowColour ~= colour then
		own.rowColour = colour
		own.rowDrawn = FillRow(row, r, g, b)
		if not own.rowDrawn then
			ns.Note(KEY, ROW_NOTE)
		end
	end
	local shown = own.rowDrawn == true
	if shown ~= (own.rowShown == true) then
		row:SetShown(shown)
		own.rowShown = shown or nil
	end
end

local function RunKinds(unitFrame, own)
	RunPart("Elite and Rare mark", KindMark, unitFrame, own)
	RunPart("Elite and Rare border", KindRim, unitFrame, own)
end

-- Reads the kind of unit of a plate again, and shows what depends on the unit. A plate that has lost its unit has none, so
-- its mark, border colour and row go.
local function Reclassify(unitFrame)
	local own = plates[unitFrame]
	if own and not ns.Forbidden(unitFrame) then
		own.kind = active[unitFrame] and KindOf(unitFrame) or nil
		RunKinds(unitFrame, own)
		RunPart("name row", NameRow, unitFrame, own)
		QueueMark(unitFrame)
	end
end

-- Layout and hook -----------------------------------------------------------------------------

-- Calls each function of a list of added parts. One that fails does not stop the others.
local function Extras(list, ...)
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn, ...)
		if not ok then
			ns.Note(KEY, "Nameplates: a part added to the plates failed. " .. tostring(err))
		end
	end
end

function Layout(unitFrame, own, fresh)
	local only = unitFrame.showOnlyName
	own.nameOnly = Plain(only, "boolean") and only or false
	RunPart("bar height", Heights, unitFrame, own, fresh)
	RunPart("bar width", Widths, unitFrame, own, fresh)
	RunPart("bar fill", Fill, unitFrame, own, fresh)
	RunPart("text", Texts, unitFrame, own)
	RunPart("class icons", IconLayout, unitFrame, own)
	RunPart("level box", LevelBox, unitFrame, own, fresh)
	RunPart("raid marker", Marker, unitFrame, own, fresh)
	RunKinds(unitFrame, own)
	RunPart("name row", NameRow, unitFrame, own)
	Extras(EXTRA.layout, unitFrame, own, fresh)
end

-- The game lays every plate out again when its nameplate options change, and UpdateAnchors runs on each plate (NamePlateDriverMixin:
-- UpdateNamePlateOptions, Blizzard_NamePlates.lua:550-628; NamePlateUnitFrameMixin:UpdateAnchors, Blizzard_NamePlateUnitFrame.lua:678).
-- Nothing is hooked on a plate: the driver is followed once, as EllesmereUI does (EllesmereUINameplates/EllesmereUINameplatesFriendly.lua:2097-2118),
-- and the plates are laid out on the next frame, as a CVar change does. A plate that is given its unit is laid out from NAME_PLATE_UNIT_ADDED,
-- and one whose friend or enemy answer changes from the events of QueueClass.
local function OptionsChanged()
	optionsPending = true
	QueueLayout(true)
end

local function FollowDriver()
	if driverFollowed ~= nil then
		return
	end
	local driver = NamePlateDriverFrame
	if driver == nil or ns.IsSecret(driver) then
		driverFollowed = false
		return
	end
	driverFollowed = ns.Follow(driver, "UpdateNamePlateOptions", OptionsChanged) == true
end

-- Without the follow, what the addon changed can be reset.
local function NoteUnhooked(unitFrame, own)
	if driverFollowed == false and (own.height or own.castHeight or own.width or own.markMoved or own.levelBox or own.flat or own.name or own.healthText or own.levelText) then
		ns.Note(KEY, "Nameplates: sizes can go back to the default when the game lays a nameplate out again.")
	end
end

-- Blizzard's own handlers of these events update isFriend and the class, so the icon is decided on
-- the next frame, for one plate or for all of them.
local function QueueClass(unitFrame)
	if unitFrame then
		classQueue[unitFrame] = true
	else
		classAll = true
	end
	if classQueued then
		return
	end
	classQueued = true
	Soon(function()
		classQueued = false
		local queue, all = classQueue, classAll
		classQueue, classAll = {}, false
		for queuedFrame in pairs(all and plates or queue) do
			local own = plates[queuedFrame]
			if own and not ns.Forbidden(queuedFrame) then
				if own.styleOn ~= On(queuedFrame) then
					-- isFriend has settled to the other answer: the plate is styled, or put back, as that answer says.
					ns.Each(KEY, Apply, queuedFrame)
					ns.Each(KEY, Layout, queuedFrame, own, false)
					QueueAuras(queuedFrame)
					QueueMark(queuedFrame)
				end
				RunPart("class icons", ClassIcon, queuedFrame, own)
				-- Blizzard has recoloured the health bar by now.
				RunPart("name row", NameRow, queuedFrame, own)
			end
		end
	end)
end

-- The plate of this unit, or every plate when the client withholds the unit.
local function QueueUnit(unit)
	if ns.IsSecret(unit) or unit == "player" then
		QueueClass()
	else
		local unitFrame = UnitFrameOf(unit)
		if unitFrame then
			QueueClass(unitFrame)
		end
	end
end

-- A nameplate CVar changes sizes through Blizzard's callbacks, so every plate is laid out again on the next frame. fresh is true when the
-- game has just laid the plates out (its options changed), and then what it sets itself needs no restoring.
function QueueLayout(fresh)
	if fresh ~= true then
		layoutFresh = false
	end
	if layoutQueued then
		return
	end
	layoutQueued = true
	Soon(function()
		layoutQueued = false
		local all, options = layoutFresh, optionsPending
		layoutFresh, optionsPending = true, false
		if ns.Enabled(KEY) then
			for unitFrame, own in pairs(plates) do
				if not ns.Forbidden(unitFrame) then
					ns.Each(KEY, Layout, unitFrame, own, all)
				end
			end
			if options then
				Extras(EXTRA.options)
			end
		end
	end)
end

local function Style(unitFrame)
	Apply(unitFrame)
	local own = known[unitFrame]
	if ns.Enabled(KEY) then
		FollowDriver()
	end
	Layout(unitFrame, own, false)
	NoteUnhooked(unitFrame, own)
	RunPart("class icons", ClassIcon, unitFrame, own)
	QueueAuras(unitFrame)
end

-- A nameplate that has a unit: styled now, and its border is marked on the next frame. The kind of its unit is read now.
local function Show(unitFrame)
	active[unitFrame] = true
	Style(unitFrame)
	Reclassify(unitFrame)
	QueueMark(unitFrame)
	Extras(EXTRA.show, unitFrame, known[unitFrame])
	if not Opt("friendly") then
		-- isFriend may be set after this event.
		QueueClass(unitFrame)
	end
end

-- Blizzard clears the unit of a plate when it takes the plate back, and the plate has no cast to follow.
local function Leave(unitFrame)
	if ns.Forbidden(unitFrame) then
		active[unitFrame] = nil
		return
	end
	local unit = unitFrame.unit
	if not ns.IsSecret(unit) and unit == nil then
		active[unitFrame] = nil
		local _, _, castBar = Parts(unitFrame)
		if castBar and ns.CastFill then
			ns.CastFill(KEY, castBar, false)
		end
		Reclassify(unitFrame)
		Extras(EXTRA.leave, unitFrame, known[unitFrame])
	end
end

local function LeaveAll()
	for unitFrame in pairs(active) do
		ns.Each(KEY, Leave, unitFrame)
	end
end

-- Blizzard's own handler has already taken the unit frame off the plate the event names, so that plate cannot be found
-- from it. Every plate that has a unit is looked at on the next frame instead.
local function QueueLeave()
	if releaseQueued then
		return
	end
	releaseQueued = true
	Soon(function()
		releaseQueued = false
		if not ns.IsStopped(KEY) then
			LeaveAll()
		end
	end)
end

local function StyleShown()
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then
		return
	end
	local ok, shown = pcall(C_NamePlate.GetNamePlates)
	if not ok or ns.IsSecret(shown) or type(shown) ~= "table" then
		return
	end
	for _, plate in ipairs(shown) do
		if not ns.IsSecret(plate) and type(plate) == "table" then
			local unitFrame = plate.UnitFrame
			if not ns.Forbidden(unitFrame) then
				ns.Each(KEY, Show, unitFrame)
			end
		end
	end
end

-- For a plate that had no unit frame yet when its event arrived.
local function QueueScan()
	if scanQueued then
		return
	end
	scanQueued = true
	Soon(function()
		scanQueued = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, StyleShown)
		end
	end)
end

local function Refresh()
	LeaveAll()
	for unitFrame in pairs(known) do
		if not ns.Forbidden(unitFrame) then
			ns.Each(KEY, Style, unitFrame)
		end
	end
	-- Icons Blizzard has put back in its pool are on no nameplate, and are used again later.
	local aurasOn = ns.Enabled(KEY) and Opt("auras")
	local look = ns.Enabled(KEY) and AuraLook() or STOCK
	for item in pairs(auraItems) do
		if not aurasStopped and not ns.Forbidden(item) then
			pcall(StyleAura, item, aurasOn, look)
		end
	end
	if ns.Enabled(KEY) then
		StyleShown()
	end
	QueueMark(nil, true)
	Extras(EXTRA.refresh)
end

-- What files loaded after this one use: the parts added to the plates, the plates with a unit, the plate frame of a unit, and the colour of
-- the border a plate has when it is neither the target nor the focus (none puts the default back).
-- ns.EachPlate, ns.IsPlate and EXTRA.show and layout also cover friendly plates left as the game draws them, and plates while the page is off.
-- A hook must check own.styleOn and ns.Enabled("nameplates") before it restyles a plate. A colour set through ns.PlateBorder stays on a
-- recycled plate unless the leave hook of the caller clears it.
ns.PlateExtra = EXTRA

function ns.EachPlate(fn, ...)
	for unitFrame in pairs(active) do
		if not ns.Forbidden(unitFrame) then
			pcall(fn, unitFrame, ...)
		end
	end
end

function ns.PlateUnitFrame(unit)
	return UnitFrameOf(unit)
end

function ns.IsPlate(frame)
	return frame ~= nil and not ns.IsSecret(frame) and plates[frame] ~= nil
end

function ns.PlateBorder(unitFrame, r, g, b, px)
	local own = unitFrame ~= nil and not ns.IsSecret(unitFrame) and plates[unitFrame]
	if not own then
		return false
	end
	own.base = type(r) == "number" and type(g) == "number" and type(b) == "number" and { r, g, b, px } or nil
	QueueMark(unitFrame)
	return true
end

-- A nameplate unit, or a unit the client withholds.
local function PlateUnit(unit)
	return ns.IsSecret(unit) or (type(unit) == "string" and unit:find("^nameplate") ~= nil)
end

-- The game says the classification of a unit changed: the plate of that unit is read again, or every plate that has a unit when
-- the client withholds which unit it was.
local function OnClassification(unit)
	if ns.IsSecret(unit) then
		for unitFrame in pairs(active) do
			ns.Each(KEY, Reclassify, unitFrame)
		end
		return
	end
	local unitFrame = UnitFrameOf(unit)
	if unitFrame then
		ns.Each(KEY, Reclassify, unitFrame)
	end
end

-- A change of side can switch a plate to or from name only, and the game lays that plate out again (UpdateShowOnlyName, Blizzard_NamePlateUnitFrame.lua:565-587).
-- The game and Flat UI each get the event and the client does not say which is first, so the answers are compared on the next frame,
-- when the plate's own handler has run.
local nameOnlyQueued = false
local function NameOnlyCompare()
	nameOnlyQueued = false
	for unitFrame, own in pairs(plates) do
		if not ns.Forbidden(unitFrame) then
			local only = unitFrame.showOnlyName
			if Plain(only, "boolean") and only ~= (own.nameOnly == true) then
				QueueLayout()
				return
			end
		end
	end
end

ns.Register(KEY, {
	label = "Nameplates",
	Start = Refresh,
	Refresh = Refresh,
	Status = function()
		local lines = {}
		for _, fn in ipairs(EXTRA.status) do
			local ok, line = pcall(fn)
			if ok and type(line) == "string" then
				lines[#lines + 1] = line
			end
		end
		return lines
	end,
	filters = {
		UNIT_AURA = PlateUnit,
		UNIT_NAME_UPDATE = PlateUnit,
		UNIT_CLASSIFICATION_CHANGED = PlateUnit,
		UNIT_FACTION = function(unit)
			return PlateUnit(unit) or unit == "player"
		end,
		CVAR_UPDATE = function(name)
			return Plain(name, "string") and name:lower():find("^nameplate") ~= nil
		end,
	},
	events = {
		NAME_PLATE_UNIT_ADDED = function(unit)
			local unitFrame = UnitFrameOf(unit)
			if unitFrame then
				-- UpdateAnchors ran when the plate got its unit, so the marker is at the game's place again.
				local own = known[unitFrame]
				if own then
					own.markMoved = nil
				end
				ns.Each(KEY, Show, unitFrame)
			else
				QueueScan()
			end
		end,
		NAME_PLATE_UNIT_REMOVED = QueueLeave,
		UNIT_AURA = function(unit)
			if aurasStopped then
				return
			end
			if ns.IsSecret(unit) then
				-- The client withholds which unit it was: look at every nameplate.
				for unitFrame in pairs(plates) do
					QueueAuras(unitFrame)
				end
				return
			end
			local unitFrame = UnitFrameOf(unit)
			if unitFrame then
				QueueAuras(unitFrame)
			end
		end,
		PLAYER_TARGET_CHANGED = function()
			QueueMark()
		end,
		PLAYER_FOCUS_CHANGED = function()
			QueueMark()
		end,
		UNIT_CLASSIFICATION_CHANGED = OnClassification,
		UNIT_FACTION = function(unit)
			QueueUnit(unit)
			if not nameOnlyQueued then
				nameOnlyQueued = true
				Soon(NameOnlyCompare)
			end
		end,
		UNIT_NAME_UPDATE = QueueUnit,
		GROUP_ROSTER_UPDATE = function()
			QueueClass()
		end,
		ADDON_RESTRICTION_STATE_CHANGED = function()
			QueueClass()
		end,
		CVAR_UPDATE = QueueLayout,
	},
})
