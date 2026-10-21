local _, ns = ...

-- The Bar block page lines the action bars up in one block. This module works out one rectangle for each bar and gives Movers the spot of
-- each (ns.MoverHold); Movers places the bar exactly as it places a bar with a saved spot, so this file calls no method of a Blizzard
-- frame to place one, except SetAlpha for the fade below. It reads rectangles and sizes only. The module owns one frame of its own, sized to the whole block, which is the one box of
-- /flatui move (Action bar block) and has a spot of its own saved in the profile.
-- With Stance, pet and experience bars on Above the block, the frames the game hangs from the main bar get spots over the block too: the
-- experience bars, then the stance bar on the left and the pet bar on the right, then the possess bar. The Leave vehicle button hangs from the
-- main bar in the game (VehicleLeaveButton.xml:4), which Movers leaves to the game, so it is not placed here; /flatui block facts still lists it.
-- All of it is planned out of combat. A bar the game does not stack (Action bars 6 to 8) and a bar the player has placed in Edit Mode stay
-- where the block put them in a fight; the others are put back by the game's stack until the fight ends.
-- Background panel: a frame of the module's own behind the rectangle of the block, in the general colours. Fade the block: the alpha of each
-- held frame (SetAlpha, which the game allows in a fight) goes to the faded value except in a fight, under the mouse, with something on the
-- cursor or with the spell flyout open (the flyout is attached to its button, Flyout.lua:218, so the fade goes to full while it is open). The alpha a frame had is read once and put back when the fade goes off or the block stops.

local KEY = "barblock"
local MOVER = "FlatUIBarBlock"
-- The bars a row can hold: the choice, the frame, the name on the page and the place of the bar in GetActionBarToggles (bars 2 to 8).
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
-- Blocks.lua names the same bars.
ns.BarFrames = BARS
-- A bar with no measure is taken to be as big as a full bar of 12 buttons. The gap between buttons is 2 where it cannot be measured, and a
-- measured gap past 40 is not one.
local FULL_WIDTH, FULL_HEIGHT, BUTTON_GAP, MAX_GAP = 562, 45, 2, 40
-- Edit Mode puts the main bar at the left of the micro menu (EditModePresetLayoutConstants.lua).
local MICRO_GAP_X, MICRO_GAP_Y, BOTTOM_Y = 4.5, 4, 6
local TOLERANCE = 0.5
local WATCH_EVERY = 0.5
-- The frames the game hangs from the main bar and the block places, bottom to top: the two experience bars, the stance and pet bars and the
-- possess bar. EditModeManager.lua puts the second status bar under the first; the game's gap between the two is -1, not the gap of the rest.
local XP2, XP1, STANCE, PET, POSSESS, LEAVE = "SecondaryStatusTrackingBarContainer", "MainStatusTrackingBarContainer", "StanceBar", "PetActionBar",
	"PossessActionBar", "MainMenuBarVehicleLeaveButton"
local XPOWN = "FlatUIXpBar"
local AROUND = { XP2, XP1, STANCE, PET, POSSESS }
-- With Flat UI's own experience bar (XpBar.lua) the one bar takes the place of the two containers.
local AROUND_OWN = { XPOWN, STANCE, PET, POSSESS }
-- The frames /flatui block facts lists, the Leave vehicle button too.
local FACT_FRAMES = { XP2, XP1, STANCE, PET, POSSESS, LEAVE }
local AROUND_SET = {}
for _, name in ipairs(AROUND) do
	AROUND_SET[name] = true
end
AROUND_SET[XPOWN] = true
local XP_SPACER = -1 -- EditModePresetLayoutConstants.lua:32 (Camelot)

-- last: the plan in use. queued: a replan is waiting for the next frame. pending: a fight stopped a replan. waiting: the label of the bar
-- the first spot waits for. noToggles: the game does not say which bars are on. default: the spot was put back, so the block goes to its
-- default place. holder: the box. watch: the frame that looks at the sizes of the bars. seen: the last size of each frame hung from the main
-- bar, by name, for when it is hidden. fight: what the bars were doing at the start and the end of the last fight, for /flatui block facts.
-- panel: the background frame. fader: the frame that decides full or faded. orig: the alpha each faded frame had. sent: the last alpha written.
local LOOK = { every = 0.1, weak = { __mode = "k" } }
local state = { queued = false, pending = false, default = false, seen = {}, fight = {}, orig = setmetatable({}, LOOK.weak), sent = setmetatable({}, LOOK.weak) }

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

-- The bars of the rows, first row first: none, a bar twice (the first stays), a bar the game's options have off and a bar the client
-- does not have are left out.
local function Slots()
	local rows, seen = {}, {}
	state.noToggles = false
	for index = 1, 6 do
		local id = Opt("slot" .. index)
		local bar = BARS[id]
		if bar and not seen[id] then
			seen[id] = true
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
			local frame = on and GameFrame(bar.frame)
			if frame then
				rows[#rows + 1] = { id = id, bar = bar, frame = frame }
			end
		end
	end
	return rows
end

-- Width and height of a bar in the units of UIParent.
local function Measure(frame)
	local _, _, width, height = ns.MoverRect(frame)
	if width and height and width > 0 and height > 0 then
		return width, height
	end
	return FULL_WIDTH, FULL_HEIGHT
end

-- The space between the buttons of a bar, from the first two button containers: the distance from the first to the second along the bar.
local function Gap(bar)
	if Opt("ownGap") then
		return Opt("barGap")
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

-- The width and height of a frame hung from the main bar, whether it is shown and the frame. A frame that is hidden, or that has no
-- rectangle now, has the last size it had when it was shown, or none.
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
	if not frame then
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

-- The spots of the frames hung from the main bar, in rows above a block whose left edge is `left`, width `width` and top `top`, with `gap`
-- between rows. A hidden frame has its spot too, so it shows in place; only a shown frame gives its row height. The stance bar is on the
-- left and the pet bar on the right, and the pet bar goes on a row of its own above the stance bar when the stance bar is wider than half
-- the block. Returns the spots, the part of the signature, whether the two bars would overlap, and the top of the last shown row.
local function AroundSpots(left, width, top, gap)
	local spots, parts, size = {}, {}, {}
	local own = ns.XpOwn ~= nil and ns.XpOwn()
	for _, name in ipairs(own and AROUND_OWN or AROUND) do
		local w, h, shown, frame = AroundSize(name)
		if frame then
			size[name] = { w = w, h = h, shown = shown }
			parts[#parts + 1] = ("%s:%.1f:%.1f:%d"):format(name, w, h, shown and 1 or 0)
		end
	end
	local stance, pet = size[STANCE], size[PET]
	local stacked = stance ~= nil and stance.w > width / 2
	local overlap = not stacked and stance ~= nil and pet ~= nil and stance.shown and pet.shown and stance.w + pet.w > width
	parts[#parts + 1] = stacked and "stacked" or "side"
	local rows = { { { XP2, "centre" } }, { { XP1, "centre" }, closer = true }, { { STANCE, "left" }, { PET, "right" } }, { { POSSESS, "left" } } }
	local first = 3
	if own then
		rows = { { { XPOWN, "centre" } }, { { STANCE, "left" }, { PET, "right" } }, { { POSSESS, "left" } } }
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

-- The rows and the spot of each bar for a block whose bottom middle is at spotX, spotY (the units of UIParent from the bottom left).
local function Plan(spotX, spotY)
	local rows = Slots()
	if #rows == 0 then
		return nil
	end
	local gap = Gap(rows[1].bar)
	local width, height = 0, 0
	local parts = {}
	for index, row in ipairs(rows) do
		row.width, row.height = Measure(row.frame)
		width = math.max(width, row.width)
		height = height + row.height + (index > 1 and gap or 0)
		parts[#parts + 1] = ("%s:%.1f:%.1f"):format(row.bar.frame, row.width, row.height)
	end
	local left, align, down = spotX - width / 2, Opt("align"), Opt("direction") == "down"
	local spots, used = {}, down and height or 0
	for _, row in ipairs(rows) do
		local bottom
		if down then
			bottom = spotY + used - row.height
			used = bottom - spotY - gap
		else
			bottom = spotY + used
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
	local overlap, aboveTop = false, nil
	if Opt("others") == "above" then
		local around, sig, cursor
		around, sig, overlap, cursor = AroundSpots(left, width, spotY + height, gap)
		aboveTop = cursor
		for name, spot in pairs(around) do
			spots[name] = spot
		end
		parts[#parts + 1] = sig
	end
	return { rows = rows, spots = spots, spotX = spotX, spotY = spotY, width = width, height = height, gap = gap, overlap = overlap, aboveTop = aboveTop,
		sig = table.concat(parts, ";") .. (";%.1f"):format(gap) }
end

-- The bottom middle of the block that leaves the first bar where it is, or puts it at left, bottom.
local function SpotFor(left, bottom)
	local plan = Plan(0, 0)
	local first = plan and plan.spots[plan.rows[1].bar.frame]
	if not first then
		return nil
	end
	return left - first.x, bottom - first.y
end

-- Where the block starts when the profile has no spot and the player has put it back: the main bar at the left of the micro menu, or the
-- bottom middle of the screen.
local function DefaultSpot()
	local plan = Plan(0, 0)
	local micro = GameFrame("MicroMenuContainer")
	if plan and plan.rows[1].id == "main" and micro then
		local left, bottom = ns.MoverRect(micro)
		if left then
			return SpotFor(left - MICRO_GAP_X - plan.rows[1].width, bottom - MICRO_GAP_Y)
		end
	end
	local width = ScreenWidth()
	if width then
		return width / 2, BOTTOM_Y
	end
	return nil
end

-- The spot of the block: the saved one, else the default after a put back, else the first bar where it is now, which is then saved.
local function Spot()
	state.waiting = nil
	local x, y = ns.MoverSpot(MOVER, "BOTTOM")
	if x then
		return x, y
	end
	if state.default then
		return DefaultSpot()
	end
	local rows = Slots()
	local first = rows[1]
	if not first then
		return nil
	end
	local left, bottom = ns.MoverRect(first.frame)
	local width, spots = ScreenWidth(), ns.Spots()
	if not (left and width and spots) then
		state.waiting = first.bar.label
		return nil
	end
	x, y = SpotFor(left, bottom)
	if not x then
		return nil
	end
	spots[MOVER] = ns.CleanSpot({ point = "BOTTOM", x = x - width / 2, y = y, kind = "hud" })
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

-- The frames the block holds, rows first, then the ones hung from the main bar.
local function HeldNames()
	local names = {}
	for _, row in ipairs(state.last and state.last.rows or {}) do
		names[#names + 1] = row.bar.frame
	end
	for _, name in ipairs({ XP2, XP1, XPOWN, STANCE, PET, POSSESS }) do
		if state.last and state.last.spots[name] then
			names[#names + 1] = name
		end
	end
	return names
end

-- The cursor in the units of UIParent, or nothing when the client does not say.
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

-- Whether the cursor is inside the block, the frames hung from its main bar and the padding of the panel.
local function Under()
	local plan, x, y = state.last, Cursor()
	if not (plan and x) then
		return false
	end
	local pad = Opt("background") and Opt("backgroundPad") or 0
	local left, bottom = plan.spotX - plan.width / 2, plan.spotY
	local right, top = left + plan.width, bottom + plan.height
	for name, spot in pairs(plan.spots) do
		local seen = AROUND_SET[name] and state.seen[name]
		local frame = seen and (name == XPOWN and ns.XpBarFrame() or GameFrame(name))
		if frame and ns.MoverShown(frame) ~= false then
			left, bottom = math.min(left, spot.x), math.min(bottom, spot.y)
			right, top = math.max(right, spot.x + seen[1]), math.max(top, spot.y + seen[2])
		end
	end
	return x >= left - pad and x <= right + pad and y >= bottom - pad and y <= top + pad
end

-- Whether the cursor holds a spell, item or macro. A withheld answer counts as holding something.
local function Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and (ns.IsSecret(kind) or kind ~= nil)
end

local function FlyoutOpen()
	local flyout = GameFrame("SpellFlyout")
	if not flyout then
		return false
	end
	local ok, shown = pcall(flyout.IsShown, flyout)
	return ok and not ns.IsSecret(shown) and shown == true
end

local function Full()
	return (Opt("fadeCombat") and InCombatLockdown()) or (Opt("fadeMouse") and Under()) or Holding() or FlyoutOpen()
end

-- The alpha of a frame, or 1 when the client does not say.
local function Original(frame)
	-- A bar the Fading page had faded has the alpha it had before that.
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

-- Writes an alpha on a frame only when it is not the one written last. The alpha the frame had is kept before the first write.
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
	state.orig[frame], state.sent[frame] = nil, nil
	if alpha ~= nil then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

-- Every held frame and the panel to full or faded; a frame that is no longer held gets its own alpha back.
local function Fade()
	local keep = {}
	if state.last then
		local alpha = Full() and 1 or Opt("fadeTo") / 100
		for _, name in ipairs(HeldNames()) do
			local frame = GameFrame(name)
			if frame then
				keep[frame] = true
				Write(frame, alpha)
			end
		end
		if state.panel and state.panelOn then
			keep[state.panel] = true
			Write(state.panel, alpha)
		end
	end
	for frame in pairs(state.orig) do
		if not keep[frame] then
			PutBack(frame)
		end
	end
end

local function FadeTick(_, elapsed)
	state.fadeClock = (state.fadeClock or 0) + elapsed
	if state.fadeClock < LOOK.every then
		return
	end
	state.fadeClock = 0
	ns.Try(KEY, Fade)
end

-- The panel behind the block and the fade, from the plan in use and the options. Each is off with no plan, with the block off and with its
-- own switch off, and the alpha of every frame the fade touched is put back.
local function Look()
	local plan = state.last
	local on = plan ~= nil and ns.Enabled(KEY)
	state.panelOn = on and Opt("background") == true
	if state.panelOn then
		if not state.panel then
			state.panel = CreateFrame("Frame", nil, UIParent)
			ns.Own[state.panel] = true
			state.panel:SetFrameStrata("BACKGROUND")
			ns.Outline(state.panel, state.panel, true)
		end
		local pad = Opt("backgroundPad")
		state.panel:ClearAllPoints()
		state.panel:SetSize(plan.width + 2 * pad, plan.height + 2 * pad)
		state.panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", plan.spotX - plan.width / 2 - pad, plan.spotY - pad)
		state.panel:Show()
	elseif state.panel then
		state.panel:Hide()
	end
	if on and Opt("fade") then
		if not state.fader then
			state.fader = CreateFrame("Frame")
			ns.Own[state.fader] = true
			state.fader:SetScript("OnUpdate", FadeTick)
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

-- The extra blocks hang from the rectangle of the block, so they are told when it changes or goes.
local function Tell()
	if ns.BlocksReplan then
		ns.BlocksReplan()
	end
end

local function Release()
	state.last, state.pending, state.waiting, state.default = nil, false, nil, false
	ns.MoverHold(KEY, nil)
	ns.XpBarBlock(nil)
	if state.holder then
		state.holder:Hide()
	end
	Look()
	Tell()
end

local function Replan()
	-- Nothing is held, panelled or faded while Flat UI leaves the game's action bars alone.
	if not ns.Enabled(KEY) or ns.HandsOff() then
		Release()
		return
	end
	-- Nothing is placed in a fight; the plan is made when it ends.
	if InCombatLockdown() then
		state.pending = true
		return
	end
	state.pending = false
	local x, y = Spot()
	local plan = x and Plan(x, y)
	if not plan then
		state.last = nil
		ns.MoverHold(KEY, nil)
		ns.XpBarBlock(nil)
		if state.holder then
			state.holder:Hide()
		end
		Look()
		Tell()
		return
	end
	if Same(plan, state.last) then
		Look()
		return
	end
	state.last = plan
	if not state.holder then
		state.holder = CreateFrame("Frame", nil, UIParent)
		ns.Own[state.holder] = true
	end
	state.holder:ClearAllPoints()
	state.holder:SetSize(plan.width, plan.height)
	state.holder:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", plan.spotX, plan.spotY)
	state.holder:Show()
	-- Flat UI's own experience bar is not a frame of the game's: its spot goes to XpBar.lua, and the rest are held.
	local held, own = {}, plan.spots[XPOWN]
	for name, spot in pairs(plan.spots) do
		if name ~= XPOWN then
			held[name] = spot
		end
	end
	ns.MoverHold(KEY, held)
	ns.XpBarBlock(own and own.x, own and own.y)
	Look()
	Tell()
end

-- The left, bottom, width and height of the block in the units of UIParent, and the top of the bars the page puts over it. Nothing while the page is off or the block has no row.
function ns.MainBlock()
	local plan = state.last
	if ns.Enabled(KEY) and plan and plan.width > 0 and plan.height > 0 then
		return plan.spotX - plan.width / 2, plan.spotY, plan.width, plan.height, plan.aboveTop or plan.spotY + plan.height
	end
	return nil
end

-- Whether the fade of the block has the frame of this name (a bar of a row or a frame hung from the main bar), for the Fading page, which leaves it to that fade.
function ns.BarBlockFades(name)
	if not (state.last and ns.Enabled(KEY) and Opt("fade")) then
		return false
	end
	for _, held in ipairs(HeldNames()) do
		if held == name then
			return true
		end
	end
	return false
end

-- Every replan runs a frame later, so the rectangles are read after the game's own pass.
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

-- A bar that is laid out later, or turned on in the game's options, changes the plan.
local function Watch(_, elapsed)
	state.clock = (state.clock or 0) + elapsed
	if state.clock < WATCH_EVERY then
		return
	end
	state.clock = 0
	if state.last and not InCombatLockdown() and not state.queued then
		local plan = Plan(0, 0)
		if not plan or plan.sig ~= state.last.sig then
			Queue()
		end
	end
end

local function Refresh()
	if not ns.Enabled(KEY) then
		if state.watch then
			state.watch:Hide()
		end
		Release()
		if ns.BarButtonsChanged then
			ns.BarButtonsChanged()
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
end

-- The frames of the box and the frame they hang from, for the handle of the movers. Nothing while the block is off, the movers do not place
-- the game's own frames or the block has no row.
function ns.BarBlockRow()
	local movers, systems = ns.MoverHoldGates()
	if state.holder and state.last and ns.Enabled(KEY) and movers and systems then
		return { state.holder }, state.holder
	end
	return {}
end

-- The movers set or put back the spot of the block. A spot put back sends the block to its default place.
function ns.BarBlockMoved()
	state.default = ns.MoverSpot(MOVER, "BOTTOM") == nil
	if ns.Enabled(KEY) then
		Queue()
	end
end

-- The name of a held frame on the pages.
local function Label(name)
	return ns.MoverLabel(name) or name
end

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if ns.HandsOff() then
		lines[#lines + 1] = "Action bar block: not applied while Leave the game's action bars alone is on."
		return lines
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
	if state.waiting then
		lines[#lines + 1] = ("Action bar block: waiting for %s."):format(state.waiting)
	end
	if state.noToggles then
		lines[#lines + 1] = "Action bar block: the game does not say which bars are on, so every bar picked is in the block."
	end
	for _, row in ipairs(state.last and state.last.rows or {}) do
		if ns.MoverHeld(row.bar.frame).state == "refused" then
			lines[#lines + 1] = ("%s is placed by the game, so it is left out of the block."):format(row.bar.label)
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
	if state.last and state.last.overlap then
		lines[#lines + 1] = "Stance bar and pet bar overlap: the block is narrower than both."
	end
	return lines
end

-- Yes, no or unknown for a flag the client may not give.
local function Flag(value)
	if type(value) == "boolean" and not ns.IsSecret(value) then
		return value and "yes" or "no"
	end
	return "unknown"
end

-- A plain value as text, or unknown when the client gives none or withholds it.
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

-- The layouts one source reports: how many, the active one, and for a source with names the name and the type of the active one.
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

-- /flatui block facts: what the game says about the bars and the layouts of Edit Mode. It reads and prints; it changes nothing.
local function Facts()
	local first = state.last and state.last.rows[1] and state.last.rows[1].bar.frame or "MainActionBar"
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

-- The first frame after a fight starts or ends: whether the client says the lockdown is on and how many held bars are still at their spot.
local function Record(which)
	Soon(function()
		pcall(function()
			local held, at = 0, 0
			for name, spot in pairs(state.last and state.last.spots or {}) do
				local frame = GameFrame(name)
				if frame and ns.MoverHeld(name).held then
					held = held + 1
					local left, bottom = ns.MoverRect(frame)
					if left and math.abs(left - spot.x) <= TOLERANCE and math.abs(bottom - spot.y) <= TOLERANCE then
						at = at + 1
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
			if state.pending then
				Queue()
			end
		end,
	},
})
