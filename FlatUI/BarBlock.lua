local _, ns = ...

local KEY = "barblock"
local MOVERS = { "FlatUIBarBlock", "FlatUIBarBlock2", "FlatUIBarBlock3" }
local SUFFIX = { "", "2", "3" }
local BESIDE = 12
local BARS = {
	main = { frame = "MainActionBar", label = "Main action bar" },
	bar2 = { frame = "MultiBarBottomLeft", label = "Action bar 2", toggle = 1 },
	bar3 = { frame = "MultiBarBottomRight", label = "Action bar 3", toggle = 2 },
	bar4 = { frame = "MultiBarRight", label = "Action bar 4", toggle = 3 },
	bar5 = { frame = "MultiBarLeft", label = "Action bar 5", toggle = 4 },
	bar6 = { frame = "MultiBar5", label = "Action bar 6", toggle = 5 },
	bar7 = { frame = "MultiBar6", label = "Action bar 7", toggle = 6 },
	bar8 = { frame = "MultiBar7", label = "Action bar 8", toggle = 7 },
}
ns.BarFrames = BARS
local FULL_WIDTH, FULL_HEIGHT, BUTTON_GAP, MAX_GAP = 562, 45, 2, 40
local MICRO_GAP_X, MICRO_GAP_Y, BOTTOM_Y = 4.5, 4, 6
local TOLERANCE = 0.5
local WATCH_EVERY = 0.5
local XP2, XP1, STANCE, PET, POSSESS, LEAVE, TOTEM = "SecondaryStatusTrackingBarContainer", "MainStatusTrackingBarContainer", "StanceBar", "PetActionBar",
	"PossessActionBar", "MainMenuBarVehicleLeaveButton", "MultiCastActionBarFrame"
local XPOWN = "FlatUIXpBar"
local TOTEM_FLYOUT, TOTEM_ARROW = "MultiCastFlyoutFrame", "MultiCastFlyoutFrameOpenButton"
local AROUND = { XP2, XP1, STANCE, PET, POSSESS, TOTEM }
local AROUND_OWN = { XPOWN, STANCE, PET, POSSESS, TOTEM }
local FACT_FRAMES = { XP2, XP1, STANCE, PET, POSSESS, LEAVE, TOTEM }
local AROUND_SET = {}
for _, name in ipairs(AROUND) do
	AROUND_SET[name] = true
end
AROUND_SET[XPOWN] = true
local XP_SPACER = -1

local LOOK = { every = 0.1, weak = { __mode = "k" } }
local state = { queued = false, pending = false, seen = {}, fight = {}, orig = setmetatable({}, LOOK.weak), sent = setmetatable({}, LOOK.weak),
	value = setmetatable({}, LOOK.weak), easing = false }
local blocks = { {}, {}, {} }
local GRIP = { width = 40, height = 16, inset = 2, slack = 6, line = 2, strata = "DIALOG", tabs = {}, shown = false, boxes = {} }

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

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function GameFrame(name)
	local frame = _G[name]
	if type(frame) == "table" and not ns.IsSecret(frame) and not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

local function ScreenWidth()
	local ok, width = pcall(UIParent.GetSize, UIParent)
	if ok and Number(width) and width > 0 then
		return width
	end
	return nil
end

local function Slots(n)
	local rows = {}
	local lists = ns.BarBlockLists and ns.BarBlockLists() or {}
	for _, id in ipairs(lists[n] or {}) do
		local bar = BARS[id]
		if bar then
			local on = true
			if bar.toggle then
				if type(GetActionBarToggles) == "function" then
					local ok, value = pcall(function()
						return select(bar.toggle, GetActionBarToggles())
					end)
					on = not (ok and not ns.IsSecret(value) and value == false)
				else
					state.noToggles = true
				end
			end
			local empty = type(ns.OwnBarEmpty) == "function" and ns.OwnBarEmpty(bar.frame) == true
			local frame = on and not empty and GameFrame(bar.frame)
			if frame then
				rows[#rows + 1] = { id = id, bar = bar, frame = frame }
			end
		end
	end
	return rows
end

local function Measure(frame)
	local _, _, width, height = ns.MoverRect(frame)
	if width and height and width > 0 and height > 0 then
		return width, height
	end
	return FULL_WIDTH, FULL_HEIGHT
end

local function Gap(n, bar)
	if Opt("ownGap" .. SUFFIX[n]) then
		return Opt("barGap" .. SUFFIX[n])
	end
	local first, second = GameFrame(bar.frame .. "ButtonContainer1"), GameFrame(bar.frame .. "ButtonContainer2")
	if first and second then
		local l1, b1, w1, h1 = ns.MoverRect(first)
		local l2, b2, w2, h2 = ns.MoverRect(second)
		if l1 and l2 then
			local gap
			if math.abs(l2 - l1) >= math.abs(b2 - b1) then
				gap = l2 > l1 and l2 - (l1 + w1) or l1 - (l2 + w2)
			else
				gap = b2 < b1 and b1 - (b2 + h2) or b2 - (b1 + h1)
			end
			if gap >= 0 and gap <= MAX_GAP then
				return gap
			end
		end
	end
	return BUTTON_GAP
end

local function HasTotems(frame)
	local ok, slots = pcall(function()
		return frame.numActiveSlots
	end)
	if ok and Number(slots) then
		return slots > 0
	end
	return ns.MoverShown(frame) == true
end

local function AroundSize(name)
	if name == XPOWN then
		local width, height, shown = ns.XpBarSize()
		local frame = ns.XpBarFrame()
		if frame then
			state.seen[name] = { width, height }
		end
		return width, height, shown, frame
	end
	local frame = GameFrame(name)
	if not frame or (name == TOTEM and not HasTotems(frame)) then
		return nil
	end
	local shown = ns.MoverShown(frame)
	local _, _, width, height = ns.MoverRect(frame)
	if shown ~= false and width and height and width > 0 and height > 0 then
		state.seen[name] = { width, height }
	end
	local seen = state.seen[name]
	return seen and seen[1] or 0, seen and seen[2] or 0, shown ~= false and seen ~= nil and (width or 0) > 0, frame
end

local function AroundSpots(left, width, top, gap, under)
	local spots, parts, size = {}, {}, {}
	local own = ns.XpOwn ~= nil and ns.XpOwn()
	for _, name in ipairs(own and AROUND_OWN or AROUND) do
		local w, h, shown, frame
		if not (under and name == XPOWN) then
			w, h, shown, frame = AroundSize(name)
		end
		if frame then
			size[name] = { w = w, h = h, shown = shown }
			parts[#parts + 1] = ("%s:%.1f:%.1f:%d"):format(name, w, h, shown and 1 or 0)
		end
	end
	local stance, pet = size[STANCE], size[PET]
	local stacked = stance ~= nil and stance.w > width / 2
	local overlap = not stacked and stance ~= nil and pet ~= nil and stance.shown and pet.shown and stance.w + pet.w > width
	parts[#parts + 1] = stacked and "stacked" or "side"
	local rows = { { { XP2, "centre" } }, { { XP1, "centre" }, closer = true }, { { STANCE, "left" }, { PET, "right" } }, { { POSSESS, "left" } },
		{ { TOTEM, "left" } } }
	local first = 3
	if own then
		rows = { { { XPOWN, "centre" } }, { { STANCE, "left" }, { PET, "right" } }, { { POSSESS, "left" } }, { { TOTEM, "left" } } }
		first = 2
	end
	if stacked then
		rows[first] = { { STANCE, "left" } }
		table.insert(rows, first + 1, { { PET, "right" } })
	end
	local cursor, any = top, false
	for _, row in ipairs(rows) do
		local height = 0
		for _, item in ipairs(row) do
			local entry = size[item[1]]
			if entry and entry.shown then
				height = math.max(height, entry.h)
			end
		end
		local step = (row.closer and any and height > 0) and XP_SPACER or gap
		local bottom = cursor + step
		for _, item in ipairs(row) do
			local entry = size[item[1]]
			if entry then
				local x = left
				if item[2] == "centre" then
					x = left + (width - entry.w) / 2
				elseif item[2] == "right" then
					x = left + width - entry.w
				end
				spots[item[1]] = { point = "BOTTOMLEFT", x = x, y = bottom }
			end
		end
		if height > 0 then
			cursor = bottom + height
			any = true
		end
	end
	return spots, table.concat(parts, ","), overlap, cursor
end

local function UnderRoom(n, gap)
	if n ~= 1 or not (ns.XpUnder ~= nil and ns.XpUnder()) then
		return nil
	end
	local _, height, shown = ns.XpBarSize()
	local room = shown and Number(height) and height > 0 and height + gap or 0
	return room, ("%s:under:%.1f"):format(XPOWN, room)
end

local function Plan(n, spotX, spotY)
	local rows = Slots(n)
	if #rows == 0 then
		return nil
	end
	local gap = Gap(n, rows[1].bar)
	local width, height = 0, 0
	local parts = {}
	for index, row in ipairs(rows) do
		row.width, row.height = Measure(row.frame)
		width = math.max(width, row.width)
		height = height + row.height + (index > 1 and gap or 0)
		parts[#parts + 1] = ("%s:%.1f:%.1f"):format(row.bar.frame, row.width, row.height)
	end
	local room, underSig = UnderRoom(n, gap)
	local base = spotY + (room or 0)
	local left, align, down = spotX - width / 2, Opt("align" .. SUFFIX[n]), Opt("direction" .. SUFFIX[n]) == "down"
	local spots, used = {}, down and height or 0
	for _, row in ipairs(rows) do
		local bottom
		if down then
			bottom = base + used - row.height
			used = bottom - base - gap
		else
			bottom = base + used
			used = used + row.height + gap
		end
		local x = left
		if align == "center" then
			x = left + (width - row.width) / 2
		elseif align == "right" then
			x = left + width - row.width
		end
		spots[row.bar.frame] = { point = "BOTTOMLEFT", x = x, y = bottom }
	end
	if room then
		spots[XPOWN] = { point = "TOPLEFT", x = left, y = room > 0 and base - gap or spotY - gap, width = width, under = true }
		parts[#parts + 1] = underSig
		height = height + room
	end
	local overlap, aboveTop = false, nil
	if n == 1 and Opt("others") == "above" and not ns.HandsOff() then
		local around, sig, cursor
		around, sig, overlap, cursor = AroundSpots(left, width, spotY + height, gap, room ~= nil)
		aboveTop = cursor
		for name, spot in pairs(around) do
			spots[name] = spot
		end
		parts[#parts + 1] = sig
	end
	return { rows = rows, spots = spots, spotX = spotX, spotY = spotY, width = width, height = height, gap = gap, overlap = overlap, aboveTop = aboveTop,
		sig = table.concat(parts, ";") .. (";%.1f"):format(gap) }
end

local function AnchorRow(rows)
	for _, row in ipairs(rows) do
		if row.id == "main" then
			return row
		end
	end
	return rows[1]
end

local function SpotFor(n, left, bottom)
	local plan = Plan(n, 0, 0)
	local row = plan and AnchorRow(plan.rows)
	local spot = row and plan.spots[row.bar.frame]
	if not spot then
		return nil
	end
	return left - spot.x, bottom
end

local function DefaultSpot(n)
	local plan = Plan(n, 0, 0)
	if not plan then
		return nil
	end
	local one = blocks[1].last
	if n > 1 and one then
		local left = one.spotX - one.width / 2
		if n == 2 then
			return left - BESIDE - plan.width / 2, one.spotY
		end
		return left + one.width + BESIDE + plan.width / 2, one.spotY
	end
	local micro = GameFrame("MicroMenuContainer")
	local main = AnchorRow(plan.rows)
	if n == 1 and main.id == "main" and micro then
		local left, bottom = ns.MoverRect(micro)
		if left then
			return SpotFor(n, left - MICRO_GAP_X - main.width, bottom - MICRO_GAP_Y)
		end
	end
	local width = ScreenWidth()
	if width then
		return width / 2, BOTTOM_Y
	end
	return nil
end

local function Spot(n)
	local block = blocks[n]
	block.waiting = nil
	local x, y = ns.MoverSpot(MOVERS[n], "BOTTOM")
	if x then
		return x, y
	end
	if n > 1 or block.default then
		return DefaultSpot(n)
	end
	local first = AnchorRow(Slots(n))
	if not first then
		return nil
	end
	local left, bottom = ns.MoverRect(first.frame)
	local width, spots = ScreenWidth(), ns.Spots()
	if not (left and width and spots) then
		block.waiting = first.bar.label
		return nil
	end
	x, y = SpotFor(n, left, bottom)
	if not x then
		return nil
	end
	spots[MOVERS[n]] = ns.CleanSpot({ point = "BOTTOM", x = x - width / 2, y = y, kind = "hud" })
	return x, y
end

local function Same(plan, last)
	if not last or plan.width ~= last.width or plan.height ~= last.height or plan.sig ~= last.sig then
		return false
	end
	for name, spot in pairs(plan.spots) do
		local was = last.spots[name]
		if not was or math.abs(was.x - spot.x) > TOLERANCE or math.abs(was.y - spot.y) > TOLERANCE then
			return false
		end
	end
	return math.abs(plan.spotX - last.spotX) <= TOLERANCE and math.abs(plan.spotY - last.spotY) <= TOLERANCE
end

local function PlanNames(plan, names)
	for _, row in ipairs(plan and plan.rows or {}) do
		names[#names + 1] = row.bar.frame
	end
	for _, name in ipairs({ XP2, XP1, XPOWN, STANCE, PET, POSSESS, TOTEM }) do
		if plan and plan.spots[name] then
			names[#names + 1] = name
		end
	end
	return names
end

local function HeldNames()
	local names = {}
	for _, block in ipairs(blocks) do
		PlanNames(block.last, names)
	end
	return names
end

local function Cursor()
	if type(GetCursorPosition) ~= "function" then
		return nil
	end
	local ok, x, y = pcall(GetCursorPosition)
	local okScale, scale = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and okScale and Number(x) and Number(y) and Number(scale) and scale > 0 then
		return x / scale, y / scale
	end
	return nil
end

local function Answers(name, method)
	local frame = GameFrame(name)
	if not frame then
		return false
	end
	local ok, shown = pcall(frame[method], frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function PanelRect(plan)
	local left, bottom = plan.spotX - plan.width / 2, plan.spotY
	local right, top = left + plan.width, bottom + plan.height
	if plan.spots[BARS.main.frame] and type(ns.OwnPagerRect) == "function" then
		local l, b, r, t = ns.OwnPagerRect()
		if ns.Finite(l) and ns.Finite(b) and ns.Finite(r) and ns.Finite(t) then
			left, bottom, right, top = math.min(left, l), math.min(bottom, b), math.max(right, r), math.max(top, t)
		end
	end
	return left, bottom, right, top
end

local function Under(plan)
	local x, y = Cursor()
	if not plan then
		return false
	end
	if plan.spots[TOTEM] and Answers(TOTEM_ARROW, "IsVisible") then
		return true
	end
	if plan.spots[BARS.main.frame] and type(ns.OwnPagerOver) == "function" and ns.OwnPagerOver() then
		return true
	end
	if not x then
		return false
	end
	local pad = Opt("background") and Opt("backgroundPad") or 0
	local left, bottom, right, top = PanelRect(plan)
	for name, spot in pairs(plan.spots) do
		local seen = AROUND_SET[name] and not spot.under and state.seen[name]
		local frame = seen and (name == XPOWN and ns.XpBarFrame() or GameFrame(name))
		if frame and ns.MoverShown(frame) ~= false then
			left, bottom = math.min(left, spot.x), math.min(bottom, spot.y)
			right, top = math.max(right, spot.x + seen[1]), math.max(top, spot.y + seen[2])
		end
	end
	return x >= left - pad and x <= right + pad and y >= bottom - pad and y <= top + pad
end

local function Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and (ns.IsSecret(kind) or kind ~= nil)
end

local function FlyoutOpen()
	return Answers("SpellFlyout", "IsShown") or Answers(TOTEM_FLYOUT, "IsVisible")
end

local CAST_HOLD = 1.5
local function Casting()
	if state.castAt and GetTime() - state.castAt < CAST_HOLD then
		return true
	end
	for _, read in ipairs({ "UnitCastingInfo", "UnitChannelInfo" }) do
		local fn = _G[read]
		if type(fn) == "function" then
			local ok, name = pcall(fn, "player")
			if ok and not ns.IsSecret(name) and type(name) == "string" then
				return true
			end
		end
	end
	return false
end

local function Below(value, most)
	return ns.Finite(value) and ns.Finite(most) and most > 0 and value < most
end

local function Hurt()
	local okDead, dead = pcall(UnitIsDeadOrGhost, "player")
	if not okDead or ns.IsSecret(dead) or dead == true then
		return false
	end
	local okHealth, health = pcall(UnitHealth, "player")
	local okMost, most = pcall(UnitHealthMax, "player")
	if okHealth and okMost and Below(health, most) then
		return true
	end
	local okMana, mana = pcall(UnitPower, "player", 0)
	local okPool, pool = pcall(UnitPowerMax, "player", 0)
	return okMana and okPool and Below(mana, pool)
end

local function MoversOpen()
	local kit = ns.MoverKit
	return type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
end

local PREVIEWS = { "ButtonStatesPreviewing", "ButtonEffectsPreviewing", "ProcPreviewing" }

local function Full(plan)
	if ns.EditModeOpen() or MoversOpen() then
		return true
	end
	for _, name in ipairs(PREVIEWS) do
		local ask = ns[name]
		if type(ask) == "function" and ask() == true then
			return true
		end
	end
	if (Opt("fadeCombat") and InCombatLockdown()) or (Opt("fadeMouse") and Under(plan)) or Holding() or FlyoutOpen() then
		return true
	end
	if Opt("fadeCast") and Casting() then
		return true
	end
	if Opt("fadeProc") == true and type(ns.ProcUpOn) == "function" then
		for _, row in ipairs(plan.rows) do
			if ns.ProcUpOn(row.bar.frame) == true then
				return true
			end
		end
	end
	if type(ns.FadeKeyHeld) == "function" and ns.FadeKeyHeld() == true then
		return true
	end
	if Opt("fadeHurt") == true and Hurt() then
		return true
	end
	if Opt("fadeTarget") and type(UnitExists) == "function" then
		local ok, exists = pcall(UnitExists, "target")
		return ok and (ns.IsSecret(exists) or exists == true)
	end
	return false
end

local function Original(frame)
	local given = ns.FadeGiven and ns.FadeGiven(frame)
	if given ~= nil then
		return given
	end
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and Number(alpha) then
		return alpha
	end
	return 1
end

local function Write(frame, alpha)
	if state.orig[frame] == nil then
		state.orig[frame] = Original(frame)
	end
	if state.sent[frame] ~= alpha then
		state.sent[frame] = alpha
		pcall(frame.SetAlpha, frame, alpha)
	end
end

local function PutBack(frame)
	local alpha = state.orig[frame]
	state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
	if alpha ~= nil then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

local function FadeFrame(name)
	local own = ns.OwnOn and ns.OwnOn() and ns.OwnBarOf and ns.OwnBarOf(name)
	if not own then
		return GameFrame(name)
	end
	local game = GameFrame(name)
	if game and state.orig[game] ~= nil then
		state.orig[game], state.sent[game], state.value[game] = nil, nil, nil
	end
	return own
end

local function Ease(frame, target, up, down)
	local value = state.value[frame]
	if value == nil then
		value = state.sent[frame] or Original(frame)
	end
	if value < target then
		value = math.min(target, value + up)
	elseif value > target then
		value = math.max(target, value - down)
	end
	state.value[frame] = value
	Write(frame, value)
	return value ~= target
end

local function Fades(n)
	local which = Opt("fadeWhich")
	if which == "first" then
		return n == 1
	elseif which == "others" then
		return n > 1
	end
	return true
end

local function Fade(dt)
	dt = Number(dt) and dt > 0 and math.min(dt, 1) or 0
	local keep, easing = {}, false
	local delay = (Number(Opt("fadeDelay")) and Opt("fadeDelay") or 500) / 1000
	local up, down = dt / 0.1, dt / math.max(0.1, (Number(Opt("fadeTime")) and Opt("fadeTime") or 300) / 1000)
	for n, block in ipairs(blocks) do
		local plan = Fades(n) and block.last
		if plan then
			local alpha = 1
			if Full(plan) then
				block.idle = 0
			else
				block.idle = (block.idle or 0) + dt
				if block.idle >= delay then
					alpha = Opt("fadeTo") / 100
				end
			end
			easing = easing or alpha == 1 and block.idle > 0
			for _, name in ipairs(PlanNames(plan, {})) do
				local frame = FadeFrame(name)
				if frame then
					keep[frame] = true
					easing = Ease(frame, alpha, up, down) or easing
				end
			end
			if block.panel and block.panelOn then
				keep[block.panel] = true
				easing = Ease(block.panel, alpha, up, down) or easing
			end
		end
	end
	state.easing = easing
	for frame in pairs(state.orig) do
		if not keep[frame] then
			PutBack(frame)
		end
	end
end

local function FadeTick(_, elapsed)
	state.fadeClock = (state.fadeClock or 0) + (Number(elapsed) and elapsed or 0)
	if not state.easing and state.fadeClock < LOOK.every then
		return
	end
	local dt = state.fadeClock
	state.fadeClock = 0
	ns.Try(KEY, Fade, dt)
end

local function Panel(block, on)
	local plan = block.last
	block.panelOn = on and plan ~= nil and Opt("background") == true
	if block.panelOn then
		if not block.panel then
			block.panel = CreateFrame("Frame", nil, UIParent)
			ns.Own[block.panel] = true
			block.panel:SetFrameStrata("BACKGROUND")
		end
		local outline = ns.Outline(block.panel, block.panel, true)
		if Opt("backgroundOwn") == true then
			local r, g, b = ns.Colour(KEY .. ".backgroundColour")
			local alpha = Opt("backgroundAlpha")
			ns.SetOutlineFill(outline, r, g, b, (ns.Finite(alpha) and alpha or 75) / 100)
		else
			ns.SetOutlineFill(outline, nil)
		end
		local pad = Opt("backgroundPad")
		local left, bottom, right, top = PanelRect(plan)
		block.panel:ClearAllPoints()
		block.panel:SetSize(right - left + 2 * pad, top - bottom + 2 * pad)
		block.panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - pad, bottom - pad)
		block.panel:Show()
	elseif block.panel then
		block.panel:Hide()
	end
	return plan ~= nil
end

function ns.BarBlockPanels()
	if not ns.Enabled(KEY) then
		return
	end
	for _, block in ipairs(blocks) do
		if block.panelOn then
			Panel(block, true)
		end
	end
end

local function Look()
	local on, any = ns.Enabled(KEY), false
	for _, block in ipairs(blocks) do
		any = Panel(block, on) or any
	end
	if on and any and Opt("fade") then
		if not state.fader then
			state.fader = CreateFrame("Frame")
			ns.Own[state.fader] = true
			state.fader:SetScript("OnUpdate", FadeTick)
			for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED" }) do
				pcall(state.fader.RegisterUnitEvent, state.fader, event, "player")
			end
			state.fader:SetScript("OnEvent", function()
				state.castAt = GetTime()
			end)
		end
		state.fader:Show()
		Fade()
	else
		if state.fader then
			state.fader:Hide()
		end
		for frame in pairs(state.orig) do
			PutBack(frame)
		end
	end
end

local function Tell()
	if ns.BlocksReplan then
		ns.BlocksReplan()
	end
end

local function Drop(block)
	block.last = nil
	if block.holder then
		block.holder:Hide()
	end
end

local function Release()
	state.pending = false
	for _, block in ipairs(blocks) do
		block.waiting, block.default = nil, false
		Drop(block)
	end
	ns.MoverHold(KEY, nil)
	ns.XpBarBlock(nil)
	Look()
	Tell()
	if ns.OwnRelayout then
		ns.OwnRelayout()
	end
end

local function Hold()
	local held = {}
	for _, block in ipairs(blocks) do
		for name, spot in pairs(block.last and block.last.spots or {}) do
			if name ~= XPOWN then
				held[name] = spot
			end
		end
	end
	ns.MoverHold(KEY, next(held) ~= nil and held or nil)
	ns.XpBarBlock(blocks[1].last and blocks[1].last.spots[XPOWN])
	if ns.OwnRelayout then
		ns.OwnRelayout()
	end
end

local function Replan()
	if not ns.Enabled(KEY) then
		Release()
		return
	end
	if InCombatLockdown() then
		state.pending = true
		return
	end
	state.pending = false
	local changed = false
	for n, block in ipairs(blocks) do
		local x, y = Spot(n)
		local plan = x and Plan(n, x, y)
		if not plan then
			changed = changed or block.last ~= nil
			Drop(block)
		elseif not Same(plan, block.last) then
			changed = true
			block.last = plan
			if not block.holder then
				block.holder = CreateFrame("Frame", nil, UIParent)
				ns.Own[block.holder] = true
			end
			block.holder:ClearAllPoints()
			block.holder:SetSize(plan.width, plan.height)
			block.holder:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", plan.spotX, plan.spotY)
			block.holder:Show()
		end
	end
	if changed then
		Hold()
	end
	Look()
	if changed then
		Tell()
		if GRIP.shown and ns.MoverRelabel then
			ns.MoverRelabel()
		end
	end
end

function ns.MainBlock()
	local plan = blocks[1].last
	if ns.Enabled(KEY) and plan and plan.width > 0 and plan.height > 0 then
		return plan.spotX - plan.width / 2, plan.spotY, plan.width, plan.height, plan.aboveTop or plan.spotY + plan.height
	end
	return nil
end

function ns.BarBlockFades(name)
	if not (ns.Enabled(KEY) and Opt("fade")) then
		return false
	end
	for n, block in ipairs(blocks) do
		if Fades(n) then
			for _, held in ipairs(PlanNames(block.last, {})) do
				if held == name then
					return true
				end
			end
		end
	end
	return false
end

local function Queue()
	if state.queued then
		return
	end
	state.queued = true
	Soon(function()
		state.queued = false
		ns.Try(KEY, Replan)
	end)
end

function ns.BarBlockReplan()
	if ns.Enabled(KEY) then
		Queue()
	end
end

local function Watch(_, elapsed)
	state.clock = (state.clock or 0) + elapsed
	if state.clock < WATCH_EVERY then
		return
	end
	state.clock = 0
	if InCombatLockdown() or state.queued then
		return
	end
	for n, block in ipairs(blocks) do
		local plan = Plan(n, 0, 0)
		if (plan and plan.sig) ~= (block.last and block.last.sig) then
			Queue()
			return
		end
	end
end

local WAIT_LINE = "Flat UI: the bar block lays out again when the fight ends."
local function Layout()
	local parts = {}
	for n = 1, #blocks do
		local suffix = SUFFIX[n]
		for _, key in ipairs({ "bars" .. n, "direction" .. suffix, "align" .. suffix, "ownGap" .. suffix, "barGap" .. suffix }) do
			parts[#parts + 1] = tostring(Opt(key))
		end
	end
	return table.concat(parts, ";")
end

local function TellWait()
	local layout = Layout()
	local was = state.layout
	state.layout = layout
	if was ~= nil and was ~= layout and InCombatLockdown() and not state.told then
		state.told = true
		print(WAIT_LINE)
	end
end

local function Refresh()
	if ns.Enabled(KEY) then
		TellWait()
	end
	if not ns.Enabled(KEY) then
		if state.watch then
			state.watch:Hide()
		end
		Release()
		if ns.BarButtonsChanged then
			ns.BarButtonsChanged()
		end
		if ns.BarBlockTurnOn then
			ns.BarBlockTurnOn()
		end
		return
	end
	if not state.watch then
		state.watch = CreateFrame("Frame")
		ns.Own[state.watch] = true
		state.watch:SetScript("OnUpdate", Watch)
	end
	state.watch:Show()
	Look()
	Queue()
	if ns.BarButtonsChanged then
		ns.BarButtonsChanged()
	end
	if ns.BarBlockTurnOn then
		ns.BarBlockTurnOn()
	end
end

for n, block in ipairs(blocks) do
	ns[n == 1 and "BarBlockRow" or ("BarBlockRow" .. n)] = function()
		local movers, systems = ns.MoverHoldGates()
		if block.holder and block.last and ns.Enabled(KEY) and movers and systems then
			return { block.holder }, block.holder
		end
		return {}
	end
	ns[n == 1 and "BarBlockMoved" or ("BarBlockMoved" .. n)] = function()
		block.default = ns.MoverSpot(MOVERS[n], "BOTTOM") == nil
		if ns.Enabled(KEY) then
			Queue()
		end
	end
end

local function GripText(id)
	if id == "main" then
		return "Main"
	end
	return ("Bar %s"):format((tostring(id):gsub("^bar", "")))
end

local function GripPaint(tab, hot)
	local look = ns.PanelLook
	if not look then
		return
	end
	local r, g, b = look.Colour(hot and "accent" or "text-dim")
	ns.SetOutlineColour(tab.outline, r, g, b)
	ns.SetOutlineAlpha(tab.outline, 1)
	r, g, b = look.Colour(hot and "accent" or "window")
	ns.SetOutlineFill(tab.outline, r, g, b, hot and 0.6 or 0.9)
	tab.text:SetTextColor(look.Colour("text"))
end

local function Released()
	if type(IsMouseButtonDown) ~= "function" then
		return false
	end
	local ok, down = pcall(IsMouseButtonDown, "LeftButton")
	return ok and not ns.IsSecret(down) and down == false
end

local function GripTarget(x, y)
	if not x then
		return nil
	end
	for n, block in ipairs(blocks) do
		local plan = block.last
		local left = plan and plan.spotX - plan.width / 2
		if GRIP.boxes[n] and plan and x >= left - GRIP.slack and x <= left + plan.width + GRIP.slack and y >= plan.spotY - GRIP.slack
			and y <= plan.spotY + plan.height + GRIP.slack then
			local down = Opt("direction" .. SUFFIX[n]) == "down"
			local slot = #plan.rows + 1
			for index, row in ipairs(plan.rows) do
				local middle = plan.spots[row.bar.frame].y + row.height / 2
				if (down and y > middle) or (not down and y < middle) then
					slot = index
					break
				end
			end
			return { n = n, plan = plan, slot = slot, down = down }
		end
	end
	return nil
end

local function Edge(plan, row, top)
	local y = plan.spots[row.bar.frame].y
	return top and y + row.height or y
end

local function GripLineY(target)
	local plan, rows, slot, down = target.plan, target.plan.rows, target.slot, target.down
	local before, after, half = rows[slot - 1], rows[slot], plan.gap / 2
	if before and after then
		return (Edge(plan, before, not down) + Edge(plan, after, down)) / 2
	elseif after then
		return down and Edge(plan, after, true) + half or Edge(plan, after, false) - half
	end
	return down and Edge(plan, before, false) - half or Edge(plan, before, true) + half
end

local function GripMark(target)
	if not target then
		if GRIP.mark then
			GRIP.mark:Hide()
		end
		return
	end
	if not GRIP.mark then
		GRIP.mark = CreateFrame("Frame", nil, UIParent)
		ns.Own[GRIP.mark] = true
		GRIP.mark:SetFrameStrata(GRIP.strata)
		GRIP.mark:SetFrameLevel(20)
		GRIP.mark:EnableMouse(false)
		GRIP.line = GRIP.mark:CreateTexture(nil, "OVERLAY")
		ns.Own[GRIP.line] = true
		GRIP.line:SetAllPoints(GRIP.mark)
		if ns.PanelLook then
			ns.PanelLook.Solid(GRIP.line, "accent", 1)
		end
	end
	local plan = target.plan
	GRIP.mark:ClearAllPoints()
	GRIP.mark:SetSize(plan.width + 2 * GRIP.slack, GRIP.line)
	GRIP.mark:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", plan.spotX - plan.width / 2 - GRIP.slack, GripLineY(target) - GRIP.line / 2)
	GRIP.mark:Show()
end

local GripMake

local function GripLayout()
	local used, kit = 0, ns.MoverKit
	for n, block in ipairs(blocks) do
		local plan = block.last
		local box = GRIP.shown and plan and kit and kit.handles[MOVERS[n]]
		local at = false
		if box and box:IsShown() then
			local left, bottom = ns.MoverRect(box)
			at = left ~= nil and math.abs(left - (plan.spotX - plan.width / 2)) <= 1 and math.abs(bottom - plan.spotY) <= 1
		end
		GRIP.boxes[n] = at
		for _, row in ipairs(at and plan.rows or {}) do
			local spot = plan.spots[row.bar.frame]
			used = used + 1
			local tab = GRIP.tabs[used] or GripMake(used)
			tab.block, tab.id = n, row.id
			local width, height = math.min(GRIP.width, row.width), math.min(GRIP.height, row.height)
			local x, y = spot.x + GRIP.inset, spot.y + (row.height - height) / 2
			if tab.x ~= x or tab.y ~= y or tab.w ~= width or tab.h ~= height then
				tab.x, tab.y, tab.w, tab.h = x, y, width, height
				tab.frame:ClearAllPoints()
				tab.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
				tab.frame:SetSize(width, height)
			end
			tab.text:SetText(GripText(row.id))
			GripPaint(tab, tab.hover)
			tab.frame:Show()
		end
	end
	for index = used + 1, #GRIP.tabs do
		GRIP.tabs[index].frame:Hide()
	end
end

local function GripEnd(drop)
	local drag = GRIP.drag
	if not drag then
		return false
	end
	GRIP.drag = nil
	drag.tab.frame:SetScript("OnUpdate", nil)
	GripMark(nil)
	local x, y = Cursor()
	local target = drop and not InCombatLockdown() and GripTarget(x or drag.x, y or drag.y)
	if target then
		local rows = target.plan.rows
		local anchor, after = rows[target.slot], false
		if not anchor then
			anchor, after = rows[#rows], true
		end
		ns.BarBlockPlace(drag.tab.id, target.n, anchor and anchor.id, after)
	end
	drag.tab.x = nil
	GripLayout()
	return true
end

local function GripStep()
	local drag = GRIP.drag
	if not drag then
		return
	end
	if InCombatLockdown() or not GRIP.shown then
		GripEnd(false)
		return
	end
	if Released() then
		GripEnd(true)
		return
	end
	local x, y = Cursor()
	if not x then
		return
	end
	drag.x, drag.y = x, y
	drag.tab.frame:ClearAllPoints()
	drag.tab.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - drag.grabX, y - drag.grabY)
	GripMark(GripTarget(x, y))
end

local function GripStart(tab)
	if GRIP.drag or InCombatLockdown() or not GRIP.shown then
		return
	end
	local x, y = Cursor()
	local left, bottom = ns.MoverRect(tab.frame)
	if not (x and left) then
		return
	end
	GRIP.drag = { tab = tab, grabX = x - left, grabY = y - bottom, x = x, y = y }
	if GRIP.line and ns.PanelLook then
		ns.PanelLook.Solid(GRIP.line, "accent", 1)
	end
	GripPaint(tab, true)
	tab.frame:SetScript("OnUpdate", GripStep)
	GripStep()
end

function GripMake(index)
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetFrameStrata(GRIP.strata)
	frame:SetFrameLevel(10)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	local tab = { frame = frame, outline = ns.Outline(frame, frame, true), hover = false }
	ns.SetOutlineThickness(tab.outline, 1)
	tab.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local object = ns.PanelLook and ns.PanelLook.Object("GameFontHighlightSmall")
	if object then
		tab.text:SetFontObject(object)
	end
	tab.text:SetAllPoints(frame)
	frame:SetScript("OnEnter", function()
		tab.hover = true
		GripPaint(tab, true)
	end)
	frame:SetScript("OnLeave", function()
		tab.hover = false
		GripPaint(tab, GRIP.drag ~= nil and GRIP.drag.tab == tab)
	end)
	frame:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and ns.MoversMode and tab.block then
			ns.Try(KEY, ns.MoversMode.Select, MOVERS[tab.block])
		end
	end)
	frame:SetScript("OnDragStart", function()
		ns.Try(KEY, GripStart, tab)
	end)
	frame:SetScript("OnDragStop", function()
		ns.Try(KEY, GripEnd, true)
	end)
	GRIP.tabs[index] = tab
	return tab
end

function ns.BarBlockGrips(open)
	GRIP.shown = open == true and ns.Enabled(KEY)
	if not GRIP.shown then
		GripEnd(false)
	end
	if not GRIP.drag then
		GripLayout()
	end
end

function ns.BarBlockGripCancel()
	return GripEnd(false)
end

local function Label(name)
	return ns.MoverLabel(name) or name
end

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if ns.HandsOff() and Opt("others") == "above" then
		lines[#lines + 1] = "Action bar block: the stance and pet bars and the game's experience bars stay with the game while Leave the game's action bars alone is on."
	end
	local movers, systems, keep = ns.MoverHoldGates()
	if not movers then
		lines[#lines + 1] = "Action bar block: Movers are off, so the bars are not placed."
	end
	if not systems then
		lines[#lines + 1] = "Action bar block: Move the game's own frames is off, so the bars are not placed."
	end
	if not keep then
		lines[#lines + 1] = "Action bar block: Keep moved frames in place is off, so the game puts the bars back."
	end
	if blocks[1].waiting then
		lines[#lines + 1] = ("Action bar block: waiting for %s."):format(blocks[1].waiting)
	end
	if state.noToggles then
		lines[#lines + 1] = "Action bar block: the game does not say which bars are on, so every bar picked is in its block."
	end
	for _, block in ipairs(blocks) do
		for _, row in ipairs(block.last and block.last.rows or {}) do
			if ns.MoverHeld(row.bar.frame).state == "refused" then
				lines[#lines + 1] = ("%s is placed by the game, so it is left out of its block."):format(row.bar.label)
			end
		end
	end
	local stacked = {}
	for _, name in ipairs(HeldNames()) do
		local info = ns.MoverHeld(name)
		if info.held and (info.state == "placed" or info.state == "waiting") and info.default == true then
			stacked[#stacked + 1] = Label(name)
		end
		if AROUND_SET[name] and info.state == "waiting" then
			lines[#lines + 1] = ("Action bar block: %s is not placed yet."):format(Label(name))
		elseif AROUND_SET[name] and info.state == "refused" then
			lines[#lines + 1] = ("Action bar block: %s is placed by the game."):format(Label(name))
		end
	end
	if #stacked > 0 and movers and systems and keep then
		lines[#lines + 1] = ("In a fight the game still stacks: %s. In Edit Mode press an arrow key once on each and save to keep them."):format(table.concat(stacked, ", "))
	end
	if blocks[1].last and blocks[1].last.overlap then
		lines[#lines + 1] = "Stance bar and pet bar overlap: the block is narrower than both."
	end
	return lines
end

local function Flag(value)
	if type(value) == "boolean" and not ns.IsSecret(value) then
		return value and "yes" or "no"
	end
	return "unknown"
end

local function Plain(value)
	if value == nil or ns.IsSecret(value) then
		return "unknown"
	end
	return tostring(value)
end

local function FactBar(name)
	local frame = GameFrame(name)
	if not frame then
		return ("%s: not in the client"):format(Label(name))
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	if not ok then
		protected = nil
	end
	local info = ns.MoverHeld(name)
	local placed = not info.held and "no, not held" or info.state == "placed" and "yes" or info.state or "waiting"
	return ("%s: protected %s, in default position %s, placed %s"):format(Label(name), Flag(protected), Flag(info.default), placed)
end

local function FactLayouts(label, read)
	local ok, info = pcall(read)
	if not (ok and type(info) == "table" and not ns.IsSecret(info) and type(info.layouts) == "table" and not ns.IsSecret(info.layouts)) then
		return label .. ": unknown"
	end
	local active = info.activeLayout
	local picked = Number(active) and info.layouts[active]
	local line = ("%s: %d layouts, active %s"):format(label, #info.layouts, Plain(active))
	if type(picked) == "table" and not ns.IsSecret(picked) then
		line = line .. (", named %s, type %s"):format(Plain(picked.layoutName), Plain(picked.layoutType))
	end
	return line
end

local function FactToggles()
	local letters = {}
	for index = 1, 7 do
		local ok, value = false, nil
		if type(GetActionBarToggles) == "function" then
			ok, value = pcall(function()
				return select(index, GetActionBarToggles())
			end)
		end
		letters[index] = ok and not ns.IsSecret(value) and (value == true and "y" or value == false and "n") or "?"
	end
	return table.concat(letters)
end

local function FactFight(label, record)
	if not record then
		return label .. ": no record yet"
	end
	return ("%s: in a fight on the next frame %s, %d of %d held bars at their spot"):format(label, Flag(record.fight), record.at, record.held)
end

local function Facts()
	local one = blocks[1].last
	local first = one and one.rows[1] and one.rows[1].bar.frame or "MainActionBar"
	print(FactBar(first))
	for _, name in ipairs(FACT_FRAMES) do
		print(FactBar(name))
	end
	print(FactLayouts("C_EditMode.GetLayouts", function()
		return C_EditMode.GetLayouts()
	end))
	print(FactLayouts("EditModeManagerFrame.layoutInfo", function()
		return EditModeManagerFrame.layoutInfo
	end))
	local restricted = C_RestrictedActions and type(C_RestrictedActions.CheckAllowProtectedFunctions) == "function"
	print(("GetActionBarToggles: %s. CheckAllowProtectedFunctions: %s."):format(FactToggles(), restricted and "exists" or "missing"))
	print(FactFight("Start of fight", state.fight.start))
	print(FactFight("End of fight", state.fight.stop))
end

local function Record(which)
	Soon(function()
		pcall(function()
			local held, at = 0, 0
			for _, block in ipairs(blocks) do
				for name, spot in pairs(block.last and block.last.spots or {}) do
					local frame = GameFrame(name)
					if frame and ns.MoverHeld(name).held then
						held = held + 1
						local left, bottom = ns.MoverRect(frame)
						if left and math.abs(left - spot.x) <= TOLERANCE and math.abs(bottom - spot.y) <= TOLERANCE then
							at = at + 1
						end
					end
				end
			end
			state.fight[which] = { fight = InCombatLockdown() == true, held = held, at = at }
		end)
	end)
end

ns.Register(KEY, {
	label = "Bar block",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Resized = Refresh,
	Status = Status,
	slash = { block = function(rest)
		if rest:lower() == "facts" then
			Facts()
		else
			print("/flatui block facts")
		end
	end },
	help = { "/flatui block facts - what the game says about the action bars and Edit Mode layouts" },
	events = {
		PLAYER_REGEN_DISABLED = function()
			Record("start")
		end,
		PLAYER_ENTERING_WORLD = Queue,
		EDIT_MODE_LAYOUTS_UPDATED = Queue,
		PLAYER_SPECIALIZATION_CHANGED = Queue,
		PLAYER_REGEN_ENABLED = function()
			Record("stop")
			state.told = nil
			if state.pending then
				Queue()
			end
		end,
	},
})
