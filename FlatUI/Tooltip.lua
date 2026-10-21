local _, ns = ...

-- The tooltip of units, action buttons and the world. The game anchors it to Edit Mode's tooltip box in
-- GameTooltip_SetDefaultAnchor. A hook on that function marks GameTooltip as placed by this module, and
-- a frame of the addon's own places it again each frame at the cursor or at the Tooltip handle of the
-- movers. No method of GameTooltip is hooked: the scripts of GameTooltip are followed with HookScript (OnShow, OnHide), so with Every
-- tooltip a tooltip anchored beside its owner is placed before it is drawn there, and the frame of the addon's own that places the tooltip
-- sees the game fade it (the alpha falls) and hides a tooltip at the cursor at once. SetOwner is never called, and Edit Mode's
-- tooltip box is never touched. An owner is tested with IsForbidden before it is used (EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin.lua:2705-2760).

local KEY = "tooltip"
local MOVER = "FlatUITooltip"
-- Placements that fail this many times in a row stop until the next tooltip.
local MAX_FAILURES = 5
-- The tooltip is placed again at this interval even when nothing changed, in case the game moved it.
local REPLACE_EVERY = 0.25

-- Anchor types that place a tooltip beside its owner. The cursor types, ANCHOR_PRESERVE and
-- ANCHOR_NONE are left to the game.
local BESIDE_OWNER = {
	ANCHOR_TOP = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOM = true, ANCHOR_LEFT = true,
	ANCHOR_TOPRIGHT = true, ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_BOTTOMLEFT = true,
}

local armed, armedOwner, failures = false, nil, 0
-- True once the armed tooltip has been seen shown. A tooltip the game anchors now may be shown a frame later.
local seenShown = false
local lastX, lastY, lastPoint
local sincePlaced = 0
local hooked, scriptsHooked = false, false
-- The highest alpha seen on the armed tooltip: the game fades a tooltip out by lowering it (UnitFrame_OnLeave and the world cursor, GameTooltip:FadeOut).
local topAlpha
-- A fall of alpha this large is a fade.
local FADE_STEP = 0.02
local driver

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True while the Tooltip handle of the movers has an effect: the tooltip is placed here and its position is fixed.
function ns.TooltipSpotUsed()
	return ns.Enabled(KEY) and Opt("mode") == "fixed"
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Disarm()
	armed, armedOwner, failures, lastX, seenShown, topAlpha = false, nil, 0, nil, false, nil
end

-- Notes the alpha of the armed tooltip as the one a fade is measured from.
local function Baseline(tooltip)
	local ok, alpha = pcall(tooltip.GetAlpha, tooltip)
	if ok and Number(alpha) and (topAlpha == nil or alpha > topAlpha) then
		topAlpha = alpha
	end
end

-- Where the chosen point of the tooltip goes, in the units of the tooltip: point, x, y. Nil when a scale, the cursor or the spot cannot be read.
local function Where(tooltip)
	local okScale, scale = pcall(tooltip.GetEffectiveScale, tooltip)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okScale and okBase and Number(scale) and Number(base) and scale > 0 and base > 0) then
		return nil
	end
	local point = Opt("point")
	-- The offsets are for the cursor. The fixed spot is placed with the Tooltip handle.
	local x, y, offsetX, offsetY
	if Opt("mode") == "fixed" then
		-- A handle that was centred is on the middle of the screen, so the tooltip hangs from the middle of its row and is centred at any width.
		point = ns.MoverCentred(MOVER, point) or point
		x, y = ns.MoverSpot(MOVER, point)
		offsetX, offsetY = 0, 0
	elseif type(GetCursorPosition) == "function" then
		local cursorX, cursorY = GetCursorPosition()
		if Number(cursorX) and Number(cursorY) then
			x, y = cursorX / base, cursorY / base
			offsetX, offsetY = Opt("x"), Opt("y")
		end
	end
	if not x then
		return nil
	end
	-- The offsets are in the units of UIParent. SetPoint takes the units of the tooltip.
	local ratio = base / scale
	return point, (x + offsetX) * ratio, (y + offsetY) * ratio
end

-- Puts the chosen point of the tooltip at the fixed spot, or at the cursor with the offsets.
local function Place(tooltip)
	local point, x, y = Where(tooltip)
	if not point then
		return
	end
	if x == lastX and y == lastY and point == lastPoint then
		return
	end
	if pcall(tooltip.ClearAllPoints, tooltip) and pcall(tooltip.SetPoint, tooltip, point, UIParent, "BOTTOMLEFT", x, y) then
		lastX, lastY, lastPoint, failures = x, y, point, 0
	else
		failures = failures + 1
		if failures >= MAX_FAILURES then
			Disarm()
		end
	end
end

local function Wake()
	if driver and ns.Enabled(KEY) then
		driver:Show()
	end
end

-- Called after the game has anchored the tooltip to Edit Mode's tooltip box.
local function Arm(tooltip, parent)
	if tooltip == nil or ns.IsSecret(tooltip) or tooltip ~= GameTooltip then
		return
	end
	-- Whatever was armed is over, also when this tooltip is left to the game.
	Disarm()
	if not ns.Enabled(KEY) or ns.EditModeOpen() or ns.Forbidden(tooltip) or (parent ~= nil and ns.Forbidden(parent)) then
		return
	end
	armed, armedOwner = true, parent
	Baseline(tooltip)
	Place(tooltip)
	Wake()
end

-- True while the tooltip is still the one that was armed, in the place the game put it.
local function Holds(tooltip)
	if ns.EditModeOpen() then
		return false
	end
	local okShown, shown = pcall(tooltip.IsShown, tooltip)
	if okShown and not ns.IsSecret(shown) then
		if shown == true then
			seenShown = true
		elseif seenShown then
			return false
		end
	end
	local okType, anchor = pcall(tooltip.GetAnchorType, tooltip)
	if okType and not ns.IsSecret(anchor) and anchor ~= "ANCHOR_NONE" then
		return false
	end
	-- An owner that cannot be read keeps the tooltip armed.
	local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
	if okOwner and not ns.IsSecret(owner) and armedOwner ~= nil and owner ~= armedOwner then
		return false
	end
	return true
end

-- Every tooltip: one that the game anchors beside its owner is made a tooltip with no anchor type, and placed.
-- The caller has tested the anchor type with ns.IsSecret. A tooltip not yet shown is not armed as shown.
local function Take(tooltip, anchor, shown)
	if not BESIDE_OWNER[anchor] or ns.EditModeOpen() then
		return
	end
	local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
	if not okOwner or owner == nil or ns.IsSecret(owner) or ns.Forbidden(owner) then
		return
	end
	-- A tooltip that cannot be placed now stays where the game puts it beside its owner.
	if not Where(tooltip) then
		return
	end
	if pcall(tooltip.SetAnchorType, tooltip, "ANCHOR_NONE") then
		armed, armedOwner, lastX, failures, seenShown, topAlpha = true, owner, nil, 0, shown, nil
		Baseline(tooltip)
		Place(tooltip)
	end
end

-- A tooltip that is up and was not taken when it was shown.
local function Adopt(tooltip)
	local okShown, shown = pcall(tooltip.IsShown, tooltip)
	local okType, anchor = pcall(tooltip.GetAnchorType, tooltip)
	if not (okShown and okType) or ns.IsSecret(shown) or ns.IsSecret(anchor) or shown ~= true then
		return
	end
	Take(tooltip, anchor, true)
end

-- The tooltip has been shown (OnShow): one that the game anchors beside its owner is taken before it is drawn there, and one that is armed
-- has been seen shown.
local function Shown(tooltip)
	if tooltip == nil or ns.IsSecret(tooltip) or tooltip ~= GameTooltip or not ns.Enabled(KEY) then
		return
	end
	if armed then
		seenShown = true
		Baseline(tooltip)
	elseif Opt("scope") == "all" then
		Adopt(tooltip)
	end
end

-- The tooltip has been hidden (OnHide): an armed tooltip that was shown is over.
local function Hidden(tooltip)
	if tooltip == nil or ns.IsSecret(tooltip) or tooltip ~= GameTooltip then
		return
	end
	if armed and seenShown then
		Disarm()
	end
end

-- True when the alpha of the armed tooltip has fallen: the game fades it out when the mouse leaves its unit.
local function Fading(tooltip)
	local ok, alpha = pcall(tooltip.GetAlpha, tooltip)
	if not ok or not Number(alpha) then
		return false
	end
	if topAlpha == nil or alpha > topAlpha then
		topAlpha = alpha
		return false
	end
	return alpha < topAlpha - FADE_STEP
end

-- The game fades the tooltip out, when the mouse leaves its unit. One at the cursor would stay stuck to it
-- for the whole fade, so it is hidden at once. At the fixed spot the fade stays.
local function Faded(tooltip)
	if tooltip == nil or ns.IsSecret(tooltip) or tooltip ~= GameTooltip or not armed or not ns.Enabled(KEY) or Opt("mode") ~= "cursor" then
		return
	end
	pcall(tooltip.Hide, tooltip)
	Disarm()
end

local function Step(elapsed)
	local tooltip = GameTooltip
	if tooltip == nil or ns.IsSecret(tooltip) then
		return
	end
	if armed and not Holds(tooltip) then
		Disarm()
	end
	if armed and Opt("mode") == "cursor" and Fading(tooltip) then
		Faded(tooltip)
	end
	if armed then
		sincePlaced = sincePlaced + elapsed
		if sincePlaced >= REPLACE_EVERY then
			sincePlaced, lastX = 0, nil
		end
		Place(tooltip)
	elseif Opt("scope") == "all" then
		Adopt(tooltip)
	else
		driver:Hide()
	end
end

-- The hooks are put on the first time the tooltip is placed, and the script hooks the first time it is for every
-- tooltip. A forbidden GameTooltip stays forbidden, so it is tested once here and never in a frame.
local function Install()
	if not ns.Enabled(KEY) then
		return
	end
	if not hooked then
		if type(GameTooltip_SetDefaultAnchor) ~= "function" or type(hooksecurefunc) ~= "function" or ns.Forbidden(GameTooltip) then
			return
		end
		hooked = true
		hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
			ns.Try(KEY, Arm, tooltip, parent)
		end)
		driver = CreateFrame("Frame")
		ns.Own[driver] = true
		driver:SetScript("OnUpdate", function(_, elapsed)
			ns.Try(KEY, Step, elapsed)
		end)
		driver:Hide()
	end
	if not scriptsHooked and Opt("scope") == "all" and type(GameTooltip.HookScript) == "function" then
		scriptsHooked = true
		pcall(GameTooltip.HookScript, GameTooltip, "OnShow", function(tooltip)
			ns.Try(KEY, Shown, tooltip)
		end)
		pcall(GameTooltip.HookScript, GameTooltip, "OnHide", function(tooltip)
			ns.Try(KEY, Hidden, tooltip)
		end)
	end
end

local function Refresh()
	Install()
	lastX = nil
	local wanted = ns.Enabled(KEY)
	if not wanted then
		Disarm()
	end
	if driver then
		driver:SetShown(wanted and (armed or Opt("scope") == "all") or false)
	end
end

ns.Register(KEY, {
	label = "Tooltip",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	events = {
		-- Cursor and nameplate tooltips of the world have UIParent as owner like the default one, so the event tells them apart.
		WORLD_CURSOR_TOOLTIP_UPDATE = function(anchorType)
			local default = Enum and Enum.WorldCursorAnchorType and Enum.WorldCursorAnchorType.Default
			if armed and (ns.IsSecret(anchorType) or anchorType ~= default) then
				Disarm()
			end
		end,
	},
})
