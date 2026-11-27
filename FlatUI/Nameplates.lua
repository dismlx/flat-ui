local _, ns = ...

local KEY = "nameplates"
local AURA_OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local AURA_MASK = "UI-HUD-CoolDownManager-Mask"
local AURA_CROP = 0.08
local MARK_SIZE = 22
local ART = {
	heal = { "myHealPrediction", "otherHealPrediction" },
	absorb = { "totalAbsorb", "totalAbsorbOverlay", "overAbsorbGlow" },
	healAbsorb = { "myHealAbsorb", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overHealAbsorbGlow" },
	camera = { "behindCameraIcon" },
	marker = { "RaidTargetIcon" },
}
local EXTRA = { show = {}, layout = {}, leave = {}, refresh = {}, options = {}, status = {} }
local STOCK = { key = "stock", crop = AURA_CROP, timers = true, stacks = true, stock = true }
local GAP = 3
local CLASS_ART = { "classicon-%s", "groupfinder-icon-class-%s" }
local PLAIN_FONT, OUTLINED_FONT = "SystemFont_NamePlate", "SystemFont_NamePlate_Outlined"
local BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
local CLASSIC_FILL = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
local NAME_TEXT, HEALTH_TEXTS, LEVEL_TEXT = { "name" }, { "Text", "LeftText", "RightText" }, { "playerLevelDiffText" }
local LEVEL_FONT = "SystemFont_NamePlateLevel"
local KINDS = ns.KINDS
local KIND_ROWS = { elite = "eliteColour", rare = "rareColour", rareelite = "rareColour", boss = "bossColour" }
local KIND_DEFAULTS = { eliteColour = "ffffd100", rareColour = "ffc7ccd6", bossColour = "ffff593d" }
local KIND_PX, INNER_PX = 2, 1
local MARK_GAP = 1
local ROW_SHARE, ROW_BOTTOM, ROW_TOP = 0.7, 0.95, 0.05
local ROW_NOTE = "Name row: the game cannot draw a gradient, so no row is shown."

local known = setmetatable({}, { __mode = "k" })
local plates = setmetatable({}, { __mode = "k" })
local active = setmetatable({}, { __mode = "k" })
local auraItems = setmetatable({}, { __mode = "k" })
local auraQueue = {}
local markQueued, scanQueued, aurasQueued, releaseQueued = false, false, false, false
local marks, markAll = {}, false
local markedTarget, markedFocus
local aurasStopped = false
local driverFollowed
local classAtlas = {}
local classQueue, classAll, classQueued = {}, false, false
local layoutQueued, sizesQueued = false, false
local TELL = { rows = { "enabled", "friendly", "healthHeight", "castHeight", "barWidth", "level", "levelShape", "levelGap", "levelSize", "raidMarker", "raidMarkerSize",
	"raidMarkerX", "raidMarkerY", "classEnemy", "classFriendly", "classPosition", "classFit", "classSize", "classGap" }, last = nil, refreshing = false,
	told = false, gameTold = false }
local layoutFresh, optionsPending = true, false
local QueueAuras
local EASE = { want = setmetatable({}, { __mode = "k" }), plates = {}, regions = {}, driver = nil, SECONDS = 0.15 }
local kindsWaiting = false

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

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

local function Usable(frame)
	if not ns.Forbidden(frame) then
		return frame
	end
end

local function Parts(unitFrame)
	local container, castContainer = Usable(unitFrame.HealthBarsContainer), Usable(unitFrame.CastBarsContainer)
	return container and Usable(container.healthBar), Usable(unitFrame.PlayerLevelDiffFrame), castContainer and Usable(castContainer.castBar)
end

local function Wanted(own, key, frame, wanted)
	if not own[key] and wanted and frame and not ns.Forbidden(frame) then
		own[key] = ns.Outline(frame, frame)
	end
	return own[key]
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

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

local function Fade(own, key, faded, owner, names)
	if owner and (faded or own[key]) then
		for _, name in ipairs(names) do
			ns.SetFaded(owner[name], faded)
		end
		own[key] = faded or nil
	end
end

local function Setup()
	local options = NamePlateSetupOptions
	if Plain(options, "table") then
		return options
	end
end

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

local function NameInside(options)
	local styles, style = AnchorStyles(), options.unitNameAnchorStyle
	return styles ~= nil and Plain(style, "number") and style == styles.InsideHealthBar
end

local function BlizzardFont(options)
	local styles, style = AnchorStyles(), options.unitNameAnchorStyle
	local outlinedAbove = options.useOutlinedFontWhenAboveHealthBar
	if styles and Plain(style, "number") and style ~= styles.InsideHealthBar and style ~= styles.CenteredAboveHealthBar
		and not (style == styles.AboveHealthBar and Plain(outlinedAbove, "boolean") and outlinedAbove) then
		return PLAIN_FONT
	end
	return OUTLINED_FONT
end

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

local function Apply(unitFrame)
	local own = known[unitFrame] or {}
	known[unitFrame] = own
	local styled = On(unitFrame)
	own.styleOn = styled
	local on = ns.Enabled(KEY) and styled
	local healthBar, level, castBar = Parts(unitFrame)

	local border = on and Opt("health")
	local levelStyle = on and Opt("level") or "default"
	local castBorder = on and Opt("cast")
	ns.SetOutline(Wanted(own, "health", healthBar, border), border, Opt("healthBackdrop"))
	if levelStyle == "box" and not own.level and level and not ns.Forbidden(level) then
		own.level = ns.Outline(level, LevelSpan(own, level, healthBar))
	end
	ns.SetOutline(own.level, levelStyle == "box", not border or Opt("healthBackdrop"))
	ns.SetOutline(Wanted(own, "cast", castBar, castBorder), castBorder, Opt("castBackdrop"))

	if healthBar then
		ns.SetFaded(healthBar.bgTexture, border)
		ns.SetFaded(healthBar.selectedBorder, border and Opt("target"))
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
		if levelStyle == "hidden" or own.levelFade then
			ns.SetFaded(level, levelStyle == "hidden")
			own.levelFade = levelStyle == "hidden" or nil
		end
		ns.SetFaded(level.playerLevelDiffIcon, levelStyle ~= "default")
		ns.SetFaded(level.selectedBorder, levelStyle ~= "default" and border and Opt("target"))
	end
	if castBar then
		ns.SetFaded(castBar.Background, castBorder)
		ns.SetFaded(castBar.Border, castBorder)
	end
	if castBar and ns.CastFill then
		ns.CastFill(KEY, castBar, (active[unitFrame] and on and Opt("castFlat") and not ns.PartStopped(KEY, "cast bar fill")) and true or false)
	end
	if not plates[unitFrame] then
		plates[unitFrame] = own
		ns.Count(KEY)
	end
end

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
	if r == nil and own.threat then
		r, g, b, px = own.threat[1], own.threat[2], own.threat[3], own.threat[4] or KIND_PX
	end
	local look = kinds and own.kind and KINDS[own.kind]
	local inner = false
	if look and r == nil then
		r, g, b = KindColour(own.kind)
		px = KIND_PX
		if look.inner and own.rim then
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

local function MarkTargets()
	local mark = ns.Enabled(KEY) and Opt("health") and Opt("target")
	local kinds = ns.Enabled(KEY) and Opt("health") and Opt("kindBorder")
	local targetOnly = ns.Enabled(KEY) and Opt("aurasWhen") ~= "always"
	local target, focus = UnitFrameOf("target"), UnitFrameOf("focus")
	local all, asked = markAll, marks
	markAll, marks = false, {}
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
				EASE.want[unitFrame] = true
				QueueAuras(unitFrame)
			end
		end
		asked[unitFrame] = true
	end
	for unitFrame in pairs(all and plates or asked) do
		Mark(unitFrame, mark, target, focus, kinds)
	end
end

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

local function AuraLook()
	local look = { crop = Opt("auraCrop") / 100, timers = Opt("auraTimers"), stacks = Opt("auraStacks") }
	if Opt("auraBorderOwn") then
		look.r, look.g, look.b = ns.Colour(KEY .. ".auraBorderColour")
	end
	look.stock = look.timers and look.stacks
	look.key = ("%s:%s:%s:%s:%s:%s"):format(look.crop, tostring(look.timers), tostring(look.stacks), tostring(look.r), tostring(look.g), tostring(look.b))
	return look
end

local function Countdown(item, own, hidden)
	local cooldown = item.Cooldown
	if cooldown == nil or ns.IsSecret(cooldown) or (not hidden and own.hideWas == nil) then
		return
	end
	if hidden then
		local ok, now = pcall(cooldown.GetHideCountdownNumbers, cooldown)
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

local function EaseList(list, now)
	local left = false
	for key, rec in pairs(list) do
		local share = ns.Finite(now) and math.min(1, math.max(0, (now - rec.start) / EASE.SECONDS)) or 1
		local alpha = rec.from + (rec.to - rec.from) * share
		rec.now = alpha
		if ns.Forbidden(rec.frame) or not pcall(rec.frame.SetAlpha, rec.frame, alpha) or share >= 1 then
			list[key] = nil
		else
			left = true
		end
	end
	return left
end

local function EaseStep()
	local now = type(GetTime) == "function" and GetTime() or nil
	local left = EaseList(EASE.plates, now)
	left = EaseList(EASE.regions, now) or left
	if not left and EASE.driver then
		EASE.driver:SetScript("OnUpdate", nil)
	end
end

local function EaseClock()
	if EASE.driver == nil then
		local ok, frame = pcall(CreateFrame, "Frame")
		EASE.driver = ok and type(frame) == "table" and frame or false
		if EASE.driver then
			ns.Own[frame] = true
		end
	end
	local now = type(GetTime) == "function" and GetTime() or nil
	if not EASE.driver or not ns.Finite(now) then
		return nil
	end
	return now
end

local function EaseAuras(unitFrame, aurasFrame, from, to)
	local now = EaseClock()
	if now == nil then
		return false
	end
	local rec = EASE.plates[unitFrame]
	if rec and rec.frame == aurasFrame and ns.Finite(rec.now) then
		from = rec.now
	end
	EASE.plates[unitFrame] = { frame = aurasFrame, from = from, to = to, start = now, now = from }
	EASE.driver:SetScript("OnUpdate", EaseStep)
	return true
end

local function EaseDone(unitFrame)
	for frame, rec in pairs(EASE.plates) do
		if unitFrame == nil or frame == unitFrame then
			EASE.plates[frame] = nil
			if not ns.Forbidden(rec.frame) then
				pcall(rec.frame.SetAlpha, rec.frame, rec.to)
			end
		end
	end
	for region, rec in pairs(EASE.regions) do
		if unitFrame == nil or rec.owner == unitFrame then
			EASE.regions[region] = nil
			if not ns.Forbidden(rec.frame) then
				pcall(rec.frame.SetAlpha, rec.frame, rec.to)
			end
		end
	end
	if unitFrame == nil then
		EASE.want = setmetatable({}, { __mode = "k" })
	else
		EASE.want[unitFrame] = nil
	end
end

function ns.PlateEase(unitFrame, region, to, instant)
	if region == nil or ns.IsSecret(region) or ns.Forbidden(region) or not ns.Finite(to) then
		return false, false
	end
	local rec = EASE.regions[region]
	if rec and rec.to == to then
		return true, true
	end
	local now = not instant and EaseClock() or nil
	if now == nil then
		EASE.regions[region] = nil
		return instant == true and pcall(region.SetAlpha, region, to), false
	end
	local from = rec and ns.Finite(rec.now) and rec.now or nil
	if from == nil then
		local ok, alpha = pcall(region.GetAlpha, region)
		from = ok and ns.Finite(alpha) and alpha or 1 - to
	end
	if math.abs(from - to) < 0.01 then
		EASE.regions[region] = nil
		return pcall(region.SetAlpha, region, to), false
	end
	EASE.regions[region] = { owner = unitFrame, frame = region, from = from, to = to, start = now, now = from }
	EASE.driver:SetScript("OnUpdate", EaseStep)
	return true, true
end

local function AurasAlpha(unitFrame, aurasFrame, styled)
	local own = known[unitFrame]
	local ease = EASE.want[unitFrame]
	EASE.want[unitFrame] = nil
	local alpha = 1
	if styled then
		alpha = Opt("auraOpacity") / 100
		local when = Opt("aurasWhen")
		if when == "target" and UnitFrameOf("target") ~= unitFrame then
			alpha = 0
		elseif when == "focus" and UnitFrameOf("target") ~= unitFrame and UnitFrameOf("focus") ~= unitFrame then
			alpha = 0
		end
	end
	if own and (own.aurasAlpha or 1) ~= alpha then
		local from = own.aurasAlpha or 1
		own.aurasAlpha = alpha ~= 1 and alpha or nil
		if not (ease and styled and EaseAuras(unitFrame, aurasFrame, from, alpha)) then
			EASE.plates[unitFrame] = nil
			pcall(aurasFrame.SetAlpha, aurasFrame, alpha)
		end
	end
end

local function StyleAuras(unitFrame)
	local aurasFrame = unitFrame.AurasFrame
	if ns.Forbidden(aurasFrame) then
		EASE.want[unitFrame] = nil
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
	local lossOfControl = aurasFrame.LossOfControlFrame
	local item = lossOfControl and not ns.IsSecret(lossOfControl) and lossOfControl.AuraItemFrame
	if item and not ns.Forbidden(item) then
		StyleAura(item, on, look)
	end
end

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
					aurasStopped = true
					ns.Note(KEY, "Aura icons: stopped. " .. tostring(err))
				end
			end
		end
	end)
end

local Layout, QueueLayout

local function RunPart(part, fn, unitFrame, own, ...)
	if ns.IsStopped(KEY) or ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, own, false, ...)
	elseif not ns.EachPart(KEY, part, fn, unitFrame, own, ns.Enabled(KEY) and On(unitFrame), ...) and ns.PartStopped(KEY, part) then
		pcall(fn, unitFrame, own, false)
		QueueLayout()
	end
end

local function QueueSizes(what)
	local height = what == "Bar height"
	if not InCombatLockdown() then
		ns.Note(KEY, height and "Bar height: the game does not allow nameplate bars to be resized." or (what .. ": the game does not allow this on nameplates."))
		return
	end
	ns.Note(KEY, height and "Bar height: nameplates that appear in combat get their height when combat ends." or (what .. ": nameplates that appear in combat get it when combat ends."))
	if TELL.refreshing and not TELL.told and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
		TELL.told = true
		print("Flat UI: nameplates take their new size when the fight ends.")
	end
	if not sizesQueued then
		sizesQueued = true
		ns.OutOfCombat(function()
			sizesQueued, TELL.told = false, false
			for unitFrame, own in pairs(plates) do
				if not ns.Forbidden(unitFrame) then
					pcall(Layout, unitFrame, own, false)
				end
			end
		end)
	end
end

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

local function Heights(unitFrame, own, on, fresh)
	local options = Setup()
	if not options then
		return
	end
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
	local inside = options.spellNameInsideCastBar
	local extra = Plain(inside, "boolean") and (inside and 0 or Size(options, "castIconHeight"))
	if castBase and extra and not ns.Forbidden(castBar) then
		local pct = on and not classic and Opt("castHeight") or 100
		if pct ~= 100 then
			if CanResize("Bar height", castContainer, castBar) then
				own.castHeight = true
				castContainer:SetHeight(castBase * pct / 100 + extra)
				castBar:SetHeight(castBase * pct / 100)
			end
		elseif own.castHeight and CanResize("Bar height", castContainer, castBar) then
			castContainer:SetHeight(castBase + extra)
			castBar:SetHeight(castBase)
			own.castHeight = nil
		end
	end
end

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

local function Widths(unitFrame, own, on, fresh)
	local options = Setup()
	local container, inset = unitFrame.CastBarsContainer, options and Size(options, "insetWidth")
	if not inset or ns.Forbidden(container) then
		return
	end
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

local function Anchor(frame)
	local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
	if ok and Plain(point, "string") and relative ~= nil and not ns.Forbidden(relative) and Plain(relativePoint, "string")
		and Plain(x, "number") and Plain(y, "number") then
		return { point, relative, relativePoint, x, y }
	end
	return false
end

local function Anchors(frame)
	local ok, count = pcall(frame.GetNumPoints, frame)
	if not ok or not Plain(count, "number") or count < 1 then
		return false
	end
	local list = {}
	for index = 1, count do
		local read, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
		if not (read and Plain(point, "string") and relative ~= nil and not ns.Forbidden(relative) and Plain(relativePoint, "string")
			and Plain(x, "number") and Plain(y, "number")) then
			return false
		end
		list[index] = { point, relative, relativePoint, x, y }
	end
	return list
end

local function BarHeight(options, on)
	local base = Size(options, "healthBarHeight")
	if base then
		local classic = (Plain(options.useClassicHealthBar, "boolean") and options.useClassicHealthBar)
			or (Plain(options.useClassicCastBar, "boolean") and options.useClassicCastBar)
		return base * ((on and not classic) and Opt("healthHeight") or 100) / 100, classic
	end
end

local function ClassRoom(own, side)
	if own.classShown and own.iconSide == side then
		return own.iconSize + own.iconGap
	end
	return 0
end

local LEVEL_KEPT = "Level box: the game keeps its own box width."
local function HiddenControl(unitFrame, own, on)
	local options = Setup()
	local level, container = Usable(unitFrame.PlayerLevelDiffFrame), Usable(unitFrame.HealthBarsContainer)
	local auras = Usable(unitFrame.AurasFrame)
	local control, lost = Usable(auras and auras.CrowdControlListFrame), Usable(auras and auras.LossOfControlFrame)
	if not (options and level and container and (control or lost)) then
		return
	end
	local ok, shown = pcall(level.IsShown, level)
	shown = ok and Plain(shown, "boolean") and shown
	local classic, only = options.useClassicHealthBar, unitFrame.showOnlyName
	local want = on and Opt("level") == "hidden" and shown and not (Plain(classic, "boolean") and classic) and not (Plain(only, "boolean") and only)
	if not (want or own.controlMoved) then
		return
	end
	if not CanResize("Level box", control or level, lost or level) then
		return
	end
	if want then
		local room = 5 + ClassRoom(own, "right")
		own.controlMoved = true
		if control then
			control:SetPoint("LEFT", container, "RIGHT", room, 0)
		end
		if lost then
			lost:SetPoint("LEFT", container, "RIGHT", room, 0)
		end
		return
	end
	own.controlMoved = nil
	if own.levelBox then
		return
	end
	local to = shown and level or container
	if control then
		control:SetPoint("LEFT", to, "RIGHT", 5, 0)
	end
	if lost then
		lost:SetPoint("LEFT", to, "RIGHT", 5, 0)
	end
end

local function SquareBox(unitFrame, own, on, fresh)
	local options = Setup()
	local level, container, cast = Usable(unitFrame.PlayerLevelDiffFrame), Usable(unitFrame.HealthBarsContainer), Usable(unitFrame.CastBarsContainer)
	if not (options and level and container and cast) then
		return
	end
	local h, classic = BarHeight(options, on)
	local ok, shown = pcall(level.IsShown, level)
	shown = ok and Plain(shown, "boolean") and shown
	local want = on and h and not classic and Opt("level") ~= "default" and Opt("level") ~= "hidden" and Opt("levelShape") == "square" and shown
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
	if not own.levelBox then
		local home = Anchors(level)
		if not home then
			return
		end
		own.levelHome = home
	end
	if want then
		local gap = Opt("levelGap")
		own.levelBox = true
		level:ClearAllPoints()
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
			own.levelKept = true
			ns.Note(KEY, LEVEL_KEPT)
		else
			ns.ClearNote(KEY, LEVEL_KEPT)
			return
		end
	end
	local width, height = Size(options, "playerLevelDiffWidth"), Size(options, "playerLevelDiffHeight")
	local home = own.levelHome
	if width and height and home then
		level:ClearAllPoints()
		for _, p in ipairs(home) do
			level:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
		level:SetSize(width, height)
		if skull then
			skull:SetSize(height, height)
		end
		local room = (shown and home[1][3] == "RIGHT") and width + math.abs(home[1][4]) or 0
		container:SetPoint("BOTTOMRIGHT", cast, "TOPRIGHT", 0 - room, spacing)
		local to = shown and level or container
		if control then
			control:SetPoint("LEFT", to, "RIGHT", 5 + room, 0)
		end
		if lost then
			lost:SetPoint("LEFT", to, "RIGHT", 5 + room, 0)
		end
	end
	own.levelBox = nil
end

local function LevelBox(unitFrame, own, on, fresh)
	SquareBox(unitFrame, own, on, fresh)
	HiddenControl(unitFrame, own, on)
end

local function Marker(unitFrame, own, on, fresh)
	local frame = unitFrame.RaidTargetFrame
	if ns.Forbidden(frame) then
		return
	end
	local size = on and (Opt("raidMarker") and Opt("raidMarkerSize") or 1) or MARK_SIZE
	local x, y = on and Opt("raidMarkerX") or 0, on and Opt("raidMarkerY") or 0
	x = x - ClassRoom(own, "left")
	if Plain(unitFrame.showOnlyName, "boolean") and unitFrame.showOnlyName then
		x, y = 0, 0
	end
	if size ~= (own.markSized or MARK_SIZE) and CanResize("Raid marker", frame) then
		own.markSized = size ~= MARK_SIZE and size or nil
		frame:SetSize(size, size)
	end
	local want = (x ~= 0 or y ~= 0) and (x .. "," .. y) or nil
	if fresh then
		own.markMoved = nil
	elseif own.markMoved then
		local now, base = Anchor(frame), own.markBase
		local at = own.markAt
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
	local at, base = own.markAt, own.markBase
	own.markY = (own.markMoved and at and base) and at[2] - base[5] or 0
end

local function Fill(unitFrame, own, on, fresh)
	local healthBar = Parts(unitFrame)
	local fill = not ns.Forbidden(healthBar) and healthBar.barTexture
	if ns.IsSecret(fill) or not fill then
		return
	end
	if on and Opt("healthFlat") then
		local r, g, b, a = healthBar:GetStatusBarColor()
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
			local options = Setup()
			if options and Plain(options.useClassicHealthBar, "boolean") and options.useClassicHealthBar then
				fill:SetTexture(CLASSIC_FILL)
			else
				fill:SetAtlas(BAR_ATLAS, true)
			end
		end
	end
end

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

local function SetText(own, key, strings, pct, outline, base, font, face)
	local outlined = outline == "game"
	local flags = ns.OUTLINE_FLAGS[outline]
	local plain = not outlined or face ~= nil
	local changed = pct ~= 100 or plain
	if not base or #strings == 0 or (not changed and not own[key]) then
		return
	end
	if changed then
		own[key] = (not plain and own[key] ~= "plain") and "sized" or "plain"
	end
	for _, fontString in ipairs(strings) do
		if font and own[key] == "plain" then
			SetFont(fontString, outlined and font or PLAIN_FONT, key == "name")
		end
		if changed and (face or (flags and flags ~= "")) then
			local ok, file, size, current = pcall(fontString.GetFont, fontString)
			if ok and Plain(file, "string") and Plain(size, "number") then
				pcall(fontString.SetFont, fontString, face or file, size, flags or current)
			end
		end
		fontString:SetTextHeight(changed and base * pct / 100 or base)
		if key == "name" then
			fontString:SetFontHeight(fontString:GetLineHeight())
		end
	end
	own[key] = changed and (plain and "plain" or "sized") or nil
end

local function Texts(unitFrame, own, on)
	local options = Setup()
	if not options then
		return
	end
	local healthBar, level = Parts(unitFrame)
	local health = Strings(healthBar, HEALTH_TEXTS)
	local font, base = BlizzardFont(options), Size(options, "healthBarFontHeight")
	local face = on and Opt("textFace") ~= "default" and ns.FontFile(Opt("textFace")) or nil
	SetText(own, "name", Strings(unitFrame, NAME_TEXT), on and Opt("nameSize") or 100, on and Opt("nameOutline") or "game", base, font, face)
	SetText(own, "healthText", health, on and Opt("healthTextSize") or 100, on and Opt("healthTextOutline") or "game", base, font, face)
	SetText(own, "levelText", Strings(level, LEVEL_TEXT), on and Opt("levelSize") or 100, "game", Size(options, "levelFontHeight"))
	local hide = on and not Opt("healthText")
	if hide or own.textHidden then
		for _, fontString in ipairs(health) do
			ns.SetFaded(fontString, hide)
		end
		own.textHidden = hide or nil
	end
end

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
	local gap, fit, round = Opt("classGap"), Opt("classFit"), Opt("classShape") == "round"
	local nameOnly = Plain(unitFrame.showOnlyName, "boolean") and unitFrame.showOnlyName
	if nameOnly then
		position = "above"
	end
	local options, lift = Setup(), 0
	if options and not NameInside(options) then
		local spacing = nameOnly and 2 or Size(options, "healthBarToNameAboveSpacing") or 0
		lift = spacing + (Size(options, "healthBarFontHeight") or 0) * Opt("nameSize") / 100
	end
	local h = fit == "bar" and options and BarHeight(options, true)
	if h then
		size = h
	end
	local icon, guide = own.icon, own.guide
	if round then
		local px = ns.Pixels(icon, 1)
		size = ns.Pixels(icon, math.max(1, math.floor(size / px + 0.5)))
	end
	local edge = "row"
	local level = position == "right" and Usable(unitFrame.PlayerLevelDiffFrame)
	if level and Opt("level") ~= "hidden" then
		local anchor, ok, shown = Anchor(level), pcall(level.IsShown, level)
		if anchor and anchor[3] ~= "RIGHT" and ok and Plain(shown, "boolean") and shown then
			edge = "level"
		end
	end
	local place = ("%s:%s:%s:%s:%s:%s:%s:%s"):format(position, size, x, y, lift, fit, gap, edge)
	own.iconSide, own.iconSize, own.iconGap = position, size, gap
	if own.iconPlace == place then
		return
	end
	if (own.guideEdge or "row") ~= edge then
		guide:SetPoint("RIGHT", edge == "level" and level or unitFrame.CastBarsContainer, "RIGHT", 0, 0)
		own.guideEdge = edge ~= "row" and edge or nil
	end
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
	ns.SetOutlineRound(own.iconOutline, own.art, Opt("classShape") == "round")
	local border = Opt("classBorder")
	ns.SetOutline(own.iconOutline, border, border)
	own.classShown = true
end

local function ClassIcon(unitFrame, own, on)
	local was = own.classShown
	SetClassIcon(unitFrame, own, on)
	if was ~= own.classShown then
		RunPart("level box", LevelBox, unitFrame, own, false)
		RunPart("raid marker", Marker, unitFrame, own, false)
		if type(ns.PlateComboPlace) == "function" then
			pcall(ns.PlateComboPlace, unitFrame, own)
		end
	end
end

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

local function KindOf(unitFrame)
	return ns.UnitKind(unitFrame.unit)
end

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

local function MarkHeight()
	local options = Setup()
	local base = options and Size(options, "levelFontHeight")
	return base and base * Opt("levelSize") / 100
end

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

local function RowColour(unitFrame, healthBar)
	local ok, r, g, b = pcall(healthBar.GetStatusBarColor, healthBar)
	if not (ok and Plain(r, "number") and Plain(g, "number") and Plain(b, "number")) then
		local unit = unitFrame.unit
		r, g, b = nil, nil, nil
		if Plain(unit, "string") then
			r, g, b = ns.ReactionColour(unit)
		end
		if r == nil then
			return nil
		end
	end
	return r * ROW_SHARE, g * ROW_SHARE, b * ROW_SHARE
end

local function FillRow(row, r, g, b)
	return type(row.SetGradient) == "function" and pcall(function()
		row:SetGradient("VERTICAL", CreateColor(r, g, b, ROW_BOTTOM), CreateColor(r, g, b, ROW_TOP))
	end)
end

local function NameRow(unitFrame, own, on)
	local healthBar = Parts(unitFrame)
	local name = Strings(unitFrame, NAME_TEXT)[1]
	local r, g, b
	if on and Opt("nameRow") and active[unitFrame] and healthBar and name then
		r, g, b = RowColour(unitFrame, healthBar)
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

local function Reclassify(unitFrame)
	local own = plates[unitFrame]
	if own and not ns.Forbidden(unitFrame) then
		own.kind = active[unitFrame] and KindOf(unitFrame) or nil
		RunKinds(unitFrame, own)
		RunPart("name row", NameRow, unitFrame, own)
		QueueMark(unitFrame)
	end
end

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

local function NoteUnhooked(unitFrame, own)
	if driverFollowed == false and (own.height or own.castHeight or own.width or own.markMoved or own.levelBox or own.flat or own.name or own.healthText or own.levelText) then
		ns.Note(KEY, "Nameplates: sizes can go back to the default when the game lays a nameplate out again.")
	end
end

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
					ns.Each(KEY, Apply, queuedFrame)
					ns.Each(KEY, Layout, queuedFrame, own, false)
					QueueAuras(queuedFrame)
					QueueMark(queuedFrame)
				end
				RunPart("class icons", ClassIcon, queuedFrame, own)
				RunPart("name row", NameRow, queuedFrame, own)
			end
		end
	end)
end

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

local function Show(unitFrame)
	active[unitFrame] = true
	Style(unitFrame)
	Reclassify(unitFrame)
	QueueMark(unitFrame)
	Extras(EXTRA.show, unitFrame, known[unitFrame])
	if not Opt("friendly") then
		QueueClass(unitFrame)
	end
end

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
		EaseDone(unitFrame)
		Extras(EXTRA.leave, unitFrame, known[unitFrame])
	end
end

local function LeaveAll()
	for unitFrame in pairs(active) do
		ns.Each(KEY, Leave, unitFrame)
	end
end

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
	local values = {}
	for index, row in ipairs(TELL.rows) do
		values[index] = tostring(Opt(row))
	end
	local sizes = table.concat(values, "|")
	TELL.refreshing = TELL.last ~= nil and sizes ~= TELL.last
	TELL.last = sizes
	EaseDone()
	LeaveAll()
	for unitFrame in pairs(known) do
		if not ns.Forbidden(unitFrame) then
			ns.Each(KEY, Style, unitFrame)
		end
	end
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
	TELL.refreshing = false
	QueueMark(nil, true)
	Extras(EXTRA.refresh)
end

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

function ns.PlateThreatBorder(unitFrame, r, g, b, px)
	local own = unitFrame ~= nil and not ns.IsSecret(unitFrame) and plates[unitFrame]
	if not own then
		return false
	end
	own.threat = type(r) == "number" and type(g) == "number" and type(b) == "number" and { r, g, b, px } or nil
	QueueMark(unitFrame)
	return true
end

local function PlateUnit(unit)
	return ns.IsSecret(unit) or (type(unit) == "string" and unit:find("^nameplate") ~= nil)
end

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

local STACK = { cvar = "nameplateStackingTypes", kinds = { stackEnemies = { "Enemy", 1 }, stackFriends = { "Friendly", 2 } } }

local function StackIndex(def)
	local kind = type(def) == "table" and STACK.kinds[def.key]
	if not kind then
		return nil
	end
	local enum = type(Enum) == "table" and Enum.NamePlateStackType or nil
	local index = Plain(enum, "table") and enum[kind[1]]
	if Plain(index, "number") and index > 0 then
		return index
	end
	return kind[2]
end

function ns.PlateStackGet(def)
	local index, api = StackIndex(def), C_CVar
	if not index or type(api) ~= "table" or type(api.GetCVarBitfield) ~= "function" then
		return nil
	end
	local ok, on = pcall(api.GetCVarBitfield, STACK.cvar, index)
	if ok and Plain(on, "boolean") then
		return on
	end
	return nil
end

function ns.PlateStackSet(def, value)
	local index, api = StackIndex(def), C_CVar
	if not index or type(api) ~= "table" or type(api.SetCVarBitfield) ~= "function" then
		return
	end
	local want = value == true
	ns.OutOfCombat(function()
		pcall(api.SetCVarBitfield, STACK.cvar, index, want)
		local now = ns.PlateStackGet(def)
		if now ~= nil and now ~= want then
			print(("Flat UI: the game kept %s %s."):format(def.label or def.key, ns.CVarShown(def, now)))
		end
	end)
end

function ns.PlateGameChanged()
	if TELL.gameTold or not InCombatLockdown() or type(ns.PanelShown) ~= "function" or ns.PanelShown() ~= true then
		return
	end
	TELL.gameTold = true
	print("Flat UI: nameplate game settings change when the fight ends.")
	ns.OutOfCombat(function()
		TELL.gameTold = false
	end)
end

do
	local api, ok, text = C_CVar, false, nil
	if type(api) == "table" and type(api.GetCVar) == "function" and type(api.GetCVarBitfield) == "function" and type(api.SetCVarBitfield) == "function" then
		ok, text = pcall(api.GetCVar, STACK.cvar)
	end
	if not ok or ns.IsSecret(text) or type(text) ~= "string" then
		for key in pairs(STACK.kinds) do
			local def = type(ns.Def) == "function" and ns.Def(KEY .. "." .. key)
			if type(def) == "table" then
				def.hidden = true
			end
		end
	end
end

do
	local api = C_CVar
	local info = type(api) == "table" and api.GetCVarInfo or nil
	local fight = type(InCombatLockdown) == "function" and InCombatLockdown()
	if type(info) == "function" and type(ns.PAGES) == "table" and type(ns.Def) == "function" then
		for _, page in ipairs(ns.PAGES) do
			if type(page) == "table" and (page.key == KEY or page.owner == KEY) then
				for _, item in ipairs(page) do
					local cvar = type(item) == "table" and item.cvar or nil
					if type(cvar) == "string" and type(item.key) == "string" then
						local ok, _, _, _, _, locked, _, readOnly = pcall(info, cvar)
						local kept = ok and ((Plain(readOnly, "boolean") and readOnly) or (not fight and Plain(locked, "boolean") and locked))
						local def = kept and ns.Def(KEY .. "." .. item.key) or nil
						if type(def) == "table" then
							def.hidden = true
						end
					end
				end
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
