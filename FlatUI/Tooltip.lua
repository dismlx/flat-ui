local _, ns = ...

local KEY = "tooltip"
local MOVER = "FlatUITooltip"
local MAX_FAILURES = 5
local REPLACE_EVERY = 0.25

local BESIDE_OWNER = {
	ANCHOR_TOP = true, ANCHOR_RIGHT = true, ANCHOR_BOTTOM = true, ANCHOR_LEFT = true,
	ANCHOR_TOPRIGHT = true, ANCHOR_BOTTOMRIGHT = true, ANCHOR_TOPLEFT = true, ANCHOR_BOTTOMLEFT = true,
}

local armed, armedOwner, failures = false, nil, 0
local seenShown = false
local lastX, lastY, lastPoint
local sincePlaced = 0
local hooked, scriptsHooked = false, false
local topAlpha
local FADE_STEP = 0.02
local driver

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

function ns.TooltipSpotUsed()
	return ns.Enabled(KEY) and Opt("mode") == "fixed"
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Disarm()
	armed, armedOwner, failures, lastX, seenShown, topAlpha = false, nil, 0, nil, false, nil
end

local function Baseline(tooltip)
	local ok, alpha = pcall(tooltip.GetAlpha, tooltip)
	if ok and Number(alpha) and (topAlpha == nil or alpha > topAlpha) then
		topAlpha = alpha
	end
end

local function Past(low, high, limit)
	return math.max(0, -low) + math.max(0, high - limit)
end

local function Flip(tooltip, point, x, y, offsetX, offsetY, size)
	local okWidth, width = pcall(tooltip.GetWidth, tooltip)
	local okHeight, height = pcall(tooltip.GetHeight, tooltip)
	local okScreenW, screenW = pcall(UIParent.GetWidth, UIParent)
	local okScreenH, screenH = pcall(UIParent.GetHeight, UIParent)
	if type(point) ~= "string" or not (okWidth and okHeight and okScreenW and okScreenH and Number(width) and Number(height) and Number(screenW)
		and Number(screenH)) then
		return point, offsetX, offsetY
	end
	width, height = width * size, height * size
	local here, there = x + offsetX, x - offsetX
	if point:find("LEFT", 1, true) and Past(there - width, there, screenW) < Past(here, here + width, screenW) then
		point, offsetX = point:gsub("LEFT", "RIGHT"), -offsetX
	elseif point:find("RIGHT", 1, true) and Past(there, there + width, screenW) < Past(here - width, here, screenW) then
		point, offsetX = point:gsub("RIGHT", "LEFT"), -offsetX
	end
	here, there = y + offsetY, y - offsetY
	if point:find("BOTTOM", 1, true) and Past(there - height, there, screenH) < Past(here, here + height, screenH) then
		point, offsetY = point:gsub("BOTTOM", "TOP"), -offsetY
	elseif point:find("TOP", 1, true) and Past(there, there + height, screenH) < Past(here - height, here, screenH) then
		point, offsetY = point:gsub("TOP", "BOTTOM"), -offsetY
	end
	return point, offsetX, offsetY
end

local function Where(tooltip)
	local okScale, scale = pcall(tooltip.GetEffectiveScale, tooltip)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okScale and okBase and Number(scale) and Number(base) and scale > 0 and base > 0) then
		return nil
	end
	local point = Opt("point")
	local x, y, offsetX, offsetY
	if Opt("mode") == "fixed" then
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
	if Opt("mode") == "cursor" then
		point, offsetX, offsetY = Flip(tooltip, point, x, y, offsetX, offsetY, scale / base)
	end
	local ratio = base / scale
	return point, (x + offsetX) * ratio, (y + offsetY) * ratio
end

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

local function Arm(tooltip, parent)
	if tooltip == nil or ns.IsSecret(tooltip) or tooltip ~= GameTooltip then
		return
	end
	Disarm()
	if not ns.Enabled(KEY) or ns.EditModeOpen() or ns.Forbidden(tooltip) or (parent ~= nil and ns.Forbidden(parent)) then
		return
	end
	armed, armedOwner = true, parent
	Baseline(tooltip)
	Place(tooltip)
	Wake()
end

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
	local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
	if okOwner and not ns.IsSecret(owner) and armedOwner ~= nil and owner ~= armedOwner then
		return false
	end
	return true
end

local function ParentOf(frame)
	local ok, parent = pcall(frame.GetParent, frame)
	if ok and parent ~= nil and not ns.IsSecret(parent) and not ns.Forbidden(parent) then
		return parent
	end
	return nil
end

local function PartyAura(owner)
	local row = ParentOf(owner)
	local frame = row and ParentOf(row)
	if frame == nil then
		return false
	end
	if rawequal(frame, _G.PartyMemberBuffTooltip) then
		return true
	end
	local ok, container = pcall(function()
		return frame.AuraFrameContainer
	end)
	if not ok or ns.IsSecret(container) or not rawequal(container, row) then
		return false
	end
	local party, up = _G.PartyFrame, ParentOf(frame)
	return party ~= nil and up ~= nil and (rawequal(up, party) or rawequal(ParentOf(up), party))
end

local function Take(tooltip, anchor, shown)
	if not BESIDE_OWNER[anchor] or ns.EditModeOpen() then
		return
	end
	local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
	if not okOwner or owner == nil or ns.IsSecret(owner) or ns.Forbidden(owner) or PartyAura(owner) then
		return
	end
	if not Where(tooltip) then
		return
	end
	if pcall(tooltip.SetAnchorType, tooltip, "ANCHOR_NONE") then
		armed, armedOwner, lastX, failures, seenShown, topAlpha = true, owner, nil, 0, shown, nil
		Baseline(tooltip)
		Place(tooltip)
	end
end

local function Adopt(tooltip)
	local okShown, shown = pcall(tooltip.IsShown, tooltip)
	local okType, anchor = pcall(tooltip.GetAnchorType, tooltip)
	if not (okShown and okType) or ns.IsSecret(shown) or ns.IsSecret(anchor) or shown ~= true then
		return
	end
	Take(tooltip, anchor, true)
end

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

local function Hidden(tooltip)
	if tooltip == nil or ns.IsSecret(tooltip) or tooltip ~= GameTooltip then
		return
	end
	if armed and seenShown then
		Disarm()
	end
end

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

local function Install()
	if not ns.Enabled(KEY) then
		return
	end
	if not hooked then
		if ns.Forbidden(GameTooltip) or not ns.FollowGlobal("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
			ns.Try(KEY, Arm, tooltip, parent)
		end) then
			return
		end
		hooked = true
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
		WORLD_CURSOR_TOOLTIP_UPDATE = function(anchorType)
			local default = Enum and Enum.WorldCursorAnchorType and Enum.WorldCursorAnchorType.Default
			if armed and (ns.IsSecret(anchorType) or anchorType ~= default) then
				Disarm()
			end
		end,
	},
})
