local _, ns = ...

-- The Bar block page lines the action bars up in up to three blocks, each with its own bars (BarBlockLists.lua: block 1 holds action bars 3
-- and 2, the main bar and action bar 4, top to bottom, by default, blocks 2 and 3 are off until given a bar), stack direction, alignment and
-- gap. This module works out one rectangle for each bar and gives Movers the spot of each (ns.MoverHold); Movers places the bar exactly as it
-- places a bar with a saved spot, so this file calls no method of a Blizzard frame to place one, except SetAlpha for the fade below. It reads
-- rectangles and sizes only. The module owns one frame of its own for each block, sized to the whole block, which is its box in /flatui move
-- (Action bar block, Action bar block 2 and 3) and has a spot of its own saved in the profile. Block 1 starts where the main bar is (its first
-- bar when it holds no main bar): that bar keeps its left, the bottom of the block is that bar's bottom, and the spot is saved the first time.
-- Blocks 2 and 3 with no spot saved stand beside block 1, block 2 on its left and block 3 on its right.
-- In /flatui move each bar of a block has a tab inside the block's box: dragged and let go, it puts the bar at that place of its block, or of
-- the block whose box it is dropped on (Tabs, below).
-- The blocks work whatever Leave the game's action bars alone says: while it is on it guards only the bars no block holds (Movers.lua,
-- hold.Off), and the stance and pet bars and the game's experience bars stay with the game.
-- Flat UI's own experience bar goes under block 1 while the block is on (Experience bar under the bar block, on by default, XpBar.lua,
-- ns.XpUnder): the block keeps its room under its bars, the bar's height and the block's gap between bars, so the bottom of the block is the
-- bottom of the bar, and the bar is exactly as wide as the block (Plan). It follows the block as bars are added or taken out, their size and
-- the stack direction change and the box is moved; the box, the background panel and the fade take it in. This is whatever Stance, pet and
-- experience bars and Leave the game's action bars alone say, since the bar is Flat UI's. A bar that shows nothing keeps no room, and hangs
-- under the block until the next plan.
-- With Stance, pet and experience bars on Above the block, the frames the game hangs from the main bar get spots over block 1 too: the
-- experience bars (Flat UI's while it is not under the block), then the stance bar on the left and the pet bar on the right, then the possess
-- bar, then the totem bar of a character that has one. Since 70425 the game stacks the totem bar last (Camelot/EditModeUtil.lua:21): in its
-- default position it goes over the bars of the stack still in theirs, so once the block's bars are kept in the Edit Mode layout it is 4 over
-- the top of the main bar (EditModeManager.lua:666-668, 692-716), across the next row of the block. The block holds it on a row of its own. The
-- Leave vehicle button hangs from the main bar in the game (VehicleLeaveButton.xml:4), which Movers leaves to the game, so it is not placed
-- here; /flatui block facts still lists it.
-- All of it is planned out of combat. A bar the game does not stack (Action bars 6 to 8) and a bar the player has placed in Edit Mode stay
-- where the block put them in a fight; the others are put back by the game's stack until the fight ends.
-- Background panel: a frame of the module's own behind the rectangle of each block, in the general colours. Fade the block: the alpha of each
-- held frame (SetAlpha, which the game allows in a fight) eases to the faded value over Fade time, once the block has not been wanted for Wait
-- before fading, and back to full in a tenth of a second when it is: in a fight, under the mouse (over its own block), with a target (Full
-- opacity with a target, off by default; UnitExists("target"), a withheld answer counting as a target, read at each pass of the fade),
-- with something on the cursor or with a flyout open: the spell flyout (attached to its button, Flyout.lua:218) or the totem bar's flyout, a
-- child of the totem bar that opens up over the bar, out of the area under the mouse (MultiCastActionBarFrame.xml:106-107,
-- MultiCastActionBarFrame.lua:637-641). The arrow that opens the totem flyout sticks out over the bar too, and counts as under the mouse while
-- the game shows it. The alpha a frame had is read once and put back when the fade goes off or the block stops. With Flat UI's own buttons
-- (OwnBars.lua) the fade writes Flat UI's bar in place of each action bar of a block (ns.OwnBarOf), never the game's bar parked under it, and
-- after a plan tells OwnBars to lay its bars out again (ns.OwnRelayout), as the game's bars it copies have moved.

local KEY = "barblock"
-- The box of each block in /flatui move, and the end of the names of its Stack direction, Line up bars and gap rows (block 1 keeps the names
-- of before 0.5.27).
local MOVERS = { "FlatUIBarBlock", "FlatUIBarBlock2", "FlatUIBarBlock3" }
local SUFFIX = { "", "2", "3" }
-- The space between block 1 and a block 2 or 3 that stands beside it.
local BESIDE = 12
-- The bars a block can hold: the id, the frame, the name on the page and the place of the bar in GetActionBarToggles (bars 2 to 8).
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
-- Blocks.lua and BarBlockLists.lua name the same bars.
ns.BarFrames = BARS
-- A bar with no measure is taken to be as big as a full bar of 12 buttons. The gap between buttons is 2 where it cannot be measured, and a
-- measured gap past 40 is not one.
local FULL_WIDTH, FULL_HEIGHT, BUTTON_GAP, MAX_GAP = 562, 45, 2, 40
-- Edit Mode puts the main bar at the left of the micro menu (EditModePresetLayoutConstants.lua).
local MICRO_GAP_X, MICRO_GAP_Y, BOTTOM_Y = 4.5, 4, 6
local TOLERANCE = 0.5
local WATCH_EVERY = 0.5
-- The frames the game hangs from the main bar and the block places, bottom to top: the two experience bars, the stance and pet bars, the
-- possess bar and the totem bar. EditModeManager.lua puts the second status bar under the first; the game's gap between the two is -1, not the
-- gap of the rest.
local XP2, XP1, STANCE, PET, POSSESS, LEAVE, TOTEM = "SecondaryStatusTrackingBarContainer", "MainStatusTrackingBarContainer", "StanceBar", "PetActionBar",
	"PossessActionBar", "MainMenuBarVehicleLeaveButton", "MultiCastActionBarFrame"
local XPOWN = "FlatUIXpBar"
-- The totem bar's flyout and the arrow that opens it, children of the totem bar (MultiCastActionBarFrame.xml:106-107, 156) that the fade reads
-- and never writes.
local TOTEM_FLYOUT, TOTEM_ARROW = "MultiCastFlyoutFrame", "MultiCastFlyoutFrameOpenButton"
local AROUND = { XP2, XP1, STANCE, PET, POSSESS, TOTEM }
-- With Flat UI's own experience bar (XpBar.lua) the one bar takes the place of the two containers.
local AROUND_OWN = { XPOWN, STANCE, PET, POSSESS, TOTEM }
-- The frames /flatui block facts lists, the Leave vehicle button and the totem bar too.
local FACT_FRAMES = { XP2, XP1, STANCE, PET, POSSESS, LEAVE, TOTEM }
local AROUND_SET = {}
for _, name in ipairs(AROUND) do
	AROUND_SET[name] = true
end
AROUND_SET[XPOWN] = true
local XP_SPACER = -1 -- EditModePresetLayoutConstants.lua:32 (Camelot)

-- queued: a replan is waiting for the next frame. pending: a fight stopped a replan. noToggles: the game does not say which bars are on.
-- watch: the frame that looks at the sizes of the bars. seen: the last size of each frame hung from the main bar, by name, for when it is
-- hidden. fight: what the bars were doing at the start and the end of the last fight, for /flatui block facts. fader: the frame that decides
-- full or faded. orig: the alpha each faded frame had. sent: the last alpha written.
-- Each block of `blocks`: last, the plan in use; waiting, the label of the bar the first spot waits for; default, the spot was put back, so the
-- block goes to its default place; holder, the box; panel, the background frame; panelOn, the panel is shown; idle, the seconds since the fade
-- last had it at full. state.value holds the alpha the fade eases each frame from, and state.easing whether a pass still has one on its way.
local LOOK = { every = 0.1, weak = { __mode = "k" } }
local state = { queued = false, pending = false, seen = {}, fight = {}, orig = setmetatable({}, LOOK.weak), sent = setmetatable({}, LOOK.weak),
	value = setmetatable({}, LOOK.weak), easing = false }
local blocks = { {}, {}, {} }
-- The tabs of /flatui move (Tabs, below): width, height and inset of a tab, how far past a box a drop still counts, the thickness of the drop
-- line, the strata over the boxes. tabs: the tabs made; shown: the handles are open; boxes: the blocks whose box shows; drag: the tab being
-- dragged; mark and line: the drop line.
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

-- The bars of block n, first bar first: a bar the game's options have off and a bar the client does not have are left out.
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

-- The space between the bars of block n: its own gap, or the space between the buttons of its first bar, from the first two button
-- containers: the distance from the first to the second along the bar.
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

-- Whether the character has a totem bar: the game shows the bar while it has an active totem slot and only then, outside Edit Mode
-- (MultiCastActionBarFrame.lua:220, 311, 334). A count the client does not give leaves it to whether the bar is shown.
local function HasTotems(frame)
	local ok, slots = pcall(function()
		return frame.numActiveSlots
	end)
	if ok and Number(slots) then
		return slots > 0
	end
	return ns.MoverShown(frame) == true
end

-- The width and height of a frame hung from the main bar, whether it is shown and the frame. A frame that is hidden, or that has no
-- rectangle now, has the last size it had when it was shown, or none. A character with no totem bar has none to place.
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

-- The spots of the frames hung from the main bar, in rows above a block whose left edge is `left`, width `width` and top `top`, with `gap`
-- between rows. A hidden frame has its spot too, so it shows in place; only a shown frame gives its row height. The stance bar is on the
-- left and the pet bar on the right, and the pet bar goes on a row of its own above the stance bar when the stance bar is wider than half
-- the block. The totem bar is on the left of the last row. Returns the spots, the part of the signature, whether the two bars would overlap,
-- and the top of the last shown row. Flat UI's experience bar under the block (under) has no row here.
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

-- Flat UI's experience bar under block 1 (ns.XpUnder): the room the block keeps for it under its bars, its height and the gap while it shows
-- something, else none, and the part of the signature. Nothing for the other blocks or while the bar is not under the block.
local function UnderRoom(n, gap)
	if n ~= 1 or not (ns.XpUnder ~= nil and ns.XpUnder()) then
		return nil
	end
	local _, height, shown = ns.XpBarSize()
	local room = shown and Number(height) and height > 0 and height + gap or 0
	return room, ("%s:under:%.1f"):format(XPOWN, room)
end

-- The rows and the spot of each bar for block n whose bottom middle is at spotX, spotY (the units of UIParent from the bottom left). Under
-- block 1 Flat UI's experience bar has its room first (UnderRoom), the bars stack over it, and its spot is the top left corner of that room
-- with the width of the block (the bar hangs from it, so one that shows something before the next plan hangs under the block).
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
	-- Only block 1 has the stance, pet and experience bars over it, and none while Flat UI leaves those bars to the game.
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

-- The bar of a block's rows its place starts from: the main bar where the block holds it, else its first bar.
local function AnchorRow(rows)
	for _, row in ipairs(rows) do
		if row.id == "main" then
			return row
		end
	end
	return rows[1]
end

-- The bottom middle of block n that puts the left of that bar at `left` and the bottom of the block at `bottom`: the block stands where the bar
-- is and stacks from there, so a bar the block puts under the main bar (one listed before it, as action bar 4 was by default in 0.5.28) stays
-- on the screen.
local function SpotFor(n, left, bottom)
	local plan = Plan(n, 0, 0)
	local row = plan and AnchorRow(plan.rows)
	local spot = row and plan.spots[row.bar.frame]
	if not spot then
		return nil
	end
	return left - spot.x, bottom
end

-- Where a block starts when the profile has no spot: block 1, after the player has put it back, with the main bar at the left of the micro
-- menu and the bottom of the block at the bottom of the main bar's place there; block 2 on the left of block 1 and block 3 on its right,
-- bottoms level; else the bottom middle of the screen.
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

-- The spot of block n: the saved one, else for blocks 2 and 3 their place beside block 1, else for block 1 the default after a put back, else
-- where its main bar (or first bar) is now, which is then saved.
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

-- The frames a plan holds, rows first, then the ones hung from the main bar.
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

-- The frames every block holds, block 1 first.
local function HeldNames()
	local names = {}
	for _, block in ipairs(blocks) do
		PlanNames(block.last, names)
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

-- Whether a frame of the game's answers true to the read-only IsShown or IsVisible. A missing frame, a failing call and a withheld answer
-- are all false.
local function Answers(name, method)
	local frame = GameFrame(name)
	if not frame then
		return false
	end
	local ok, shown = pcall(frame[method], frame)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- Whether the cursor is inside a block's plan, the frames hung from its main bar and the padding of the panel, or on the arrow that opens the
-- flyout of a totem bar the block holds. The arrow is 18 high on the top of a totem slot that ends 5 under the top of the bar
-- (MultiCastActionBarFrame.xml:3-4, 102, 156-157, 210-214; MultiCastActionBarFrame.lua:819-820), so most of it is over the bar. The game shows
-- it only with the cursor on a totem slot or the summon button (MultiCastActionBarFrame.lua:378-381, 452-455, 604-606, 926-931) and hides it
-- once the cursor is off them and off the arrow (:391-394, 457-460, 803-805, 825-830, 940-943), so a shown arrow is a cursor on the totem bar.
-- It hangs from the slot, a child of the bar (MultiCastActionBarFrame.xml:210), so it is read with IsVisible.
local function Under(plan)
	local x, y = Cursor()
	if not plan then
		return false
	end
	if plan.spots[TOTEM] and Answers(TOTEM_ARROW, "IsVisible") then
		return true
	end
	if not x then
		return false
	end
	local pad = Opt("background") and Opt("backgroundPad") or 0
	local left, bottom = plan.spotX - plan.width / 2, plan.spotY
	local right, top = left + plan.width, bottom + plan.height
	for name, spot in pairs(plan.spots) do
		-- Flat UI's experience bar under the block is in the block's own rectangle.
		local seen = AROUND_SET[name] and not spot.under and state.seen[name]
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

-- Whether a flyout is open: the spell flyout, or the totem bar's. The totem flyout is a child of the totem bar with no ignoreParentAlpha
-- (MultiCastActionBarFrame.xml:101, 106-107), so it is drawn at the bar's alpha, and the game opens it on the top of its totem slot or of
-- the summon button, its buttons stacked up from there (MultiCastActionBarFrame.lua:637-641, 745-755, 780), out of the area under the mouse.
-- It is read with IsVisible: an override bar hides the totem bar (ActionBarController.lua:229-237, MultiCastActionBarFrame.lua:222,
-- 332-343), which has no OnHide to close the flyout (MultiCastActionBarFrame.xml:325-329), so a flyout left open is not drawn until the bar
-- comes back.
local function FlyoutOpen()
	return Answers("SpellFlyout", "IsShown") or Answers(TOTEM_FLYOUT, "IsVisible")
end

local function Full(plan)
	if (Opt("fadeCombat") and InCombatLockdown()) or (Opt("fadeMouse") and Under(plan)) or Holding() or FlyoutOpen() then
		return true
	end
	-- Full opacity with a target: a withheld answer counts as a target, as on the Fading page (Fade.lua, HasTarget).
	if Opt("fadeTarget") and type(UnitExists) == "function" then
		local ok, exists = pcall(UnitExists, "target")
		return ok and (ns.IsSecret(exists) or exists == true)
	end
	return false
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
	state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
	if alpha ~= nil then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

-- The frame the fade writes for a held name: Flat UI's own bar in place of an action bar while Flat UI's buttons are in use, since the game's bar
-- is parked at alpha 0 under it (OwnBars.lua), else the game's frame. A game bar written before Flat UI's buttons were built is let go without a
-- write, so the parked bar keeps its alpha 0.
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

-- One step of a frame toward its alpha: up by `up`, down by `down`, from the alpha it was last given (its own the first time). True while it is
-- not there yet.
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

-- Every held frame and each panel toward full or faded, block by block; a frame that is no longer held gets its own alpha back. A block goes to
-- full at once when it is wanted (in 0.1 s), and to its faded opacity over Fade time once it has not been wanted for Wait before fading. dt is the
-- time since the last pass (0 for a pass of an option change).
local function Fade(dt)
	dt = Number(dt) and dt > 0 and math.min(dt, 1) or 0
	local keep, easing = {}, false
	local delay = (Number(Opt("fadeDelay")) and Opt("fadeDelay") or 500) / 1000
	local up, down = dt / 0.1, dt / math.max(0.1, (Number(Opt("fadeTime")) and Opt("fadeTime") or 300) / 1000)
	for _, block in ipairs(blocks) do
		local plan = block.last
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
			-- Still waiting to fade counts as easing, so the next pass comes on the next frame.
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

-- Every frame while a block eases or waits to fade, else every 0.1 s.
local function FadeTick(_, elapsed)
	state.fadeClock = (state.fadeClock or 0) + (Number(elapsed) and elapsed or 0)
	if not state.easing and state.fadeClock < LOOK.every then
		return
	end
	local dt = state.fadeClock
	state.fadeClock = 0
	ns.Try(KEY, Fade, dt)
end

-- The panel behind a block from its plan and the options: off with no plan, with the page off and with its own switch off.
local function Panel(block, on)
	local plan = block.last
	block.panelOn = on and plan ~= nil and Opt("background") == true
	if block.panelOn then
		if not block.panel then
			block.panel = CreateFrame("Frame", nil, UIParent)
			ns.Own[block.panel] = true
			block.panel:SetFrameStrata("BACKGROUND")
			ns.Outline(block.panel, block.panel, true)
		end
		local pad = Opt("backgroundPad")
		block.panel:ClearAllPoints()
		block.panel:SetSize(plan.width + 2 * pad, plan.height + 2 * pad)
		block.panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", plan.spotX - plan.width / 2 - pad, plan.spotY - pad)
		block.panel:Show()
	elseif block.panel then
		block.panel:Hide()
	end
	return plan ~= nil
end

-- The panels behind the blocks and the fade, from the plans in use and the options. The fade is off with no plan, with the page off and with
-- its own switch off, and the alpha of every frame it touched is put back.
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

-- The extra blocks hang from the rectangle of block 1, so they are told when it changes or goes.
local function Tell()
	if ns.BlocksReplan then
		ns.BlocksReplan()
	end
end

-- A block with no plan: its box goes.
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

-- The spots of every block for Movers; Flat UI's own experience bar is not a frame of the game's: its spot goes to XpBar.lua, and the rest are held.
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
	-- Flat UI's own buttons copy the game bars' places, which a snippet sets with no event: they are laid out again.
	if ns.OwnRelayout then
		ns.OwnRelayout()
	end
end

local function Replan()
	-- The blocks are planned whatever Leave the game's action bars alone says: it guards only the bars no block holds.
	if not ns.Enabled(KEY) then
		Release()
		return
	end
	-- Nothing is placed in a fight; the plan is made when it ends.
	if InCombatLockdown() then
		state.pending = true
		return
	end
	state.pending = false
	local changed = false
	-- Block 1 first: blocks 2 and 3 with no spot of their own stand beside it.
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
		-- The boxes and tabs of /flatui move follow at once.
		if GRIP.shown and ns.MoverRelabel then
			ns.MoverRelabel()
		end
	end
end

-- The left, bottom, width and height of block 1 in the units of UIParent, and the top of the bars the page puts over it. Nothing while the page
-- is off or the block has no row. The Class and item bars page hangs its bars from it.
function ns.MainBlock()
	local plan = blocks[1].last
	if ns.Enabled(KEY) and plan and plan.width > 0 and plan.height > 0 then
		return plan.spotX - plan.width / 2, plan.spotY, plan.width, plan.height, plan.aboveTop or plan.spotY + plan.height
	end
	return nil
end

-- Whether the fade of a block has the frame of this name (a bar of a block or a frame hung from the main bar), for the Fading page, which leaves it to that fade.
function ns.BarBlockFades(name)
	if not (ns.Enabled(KEY) and Opt("fade")) then
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

-- Flat UI's experience bar changed its rows (XpBar.lua): block 1 lays out again, for the room it keeps under its bars.
function ns.BarBlockReplan()
	if ns.Enabled(KEY) then
		Queue()
	end
end

-- A bar that is laid out later, or turned on in the game's options, changes the plan of its block.
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

local function Refresh()
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
	-- At login and when the bars of a block change, a bar a block holds that the game's options have off is turned on (BarBlockLists.lua).
	if ns.BarBlockTurnOn then
		ns.BarBlockTurnOn()
	end
end

-- The frames of the box of each block and the frame they hang from, for the handle of the movers (BarBlockRow, BarBlockRow2, BarBlockRow3).
-- Nothing while the page is off, the movers do not place the game's own frames or the block has no row.
for n, block in ipairs(blocks) do
	ns[n == 1 and "BarBlockRow" or ("BarBlockRow" .. n)] = function()
		local movers, systems = ns.MoverHoldGates()
		if block.holder and block.last and ns.Enabled(KEY) and movers and systems then
			return { block.holder }, block.holder
		end
		return {}
	end
	-- The movers set or put back the spot of the block (BarBlockMoved, BarBlockMoved2, BarBlockMoved3). A spot put back sends block 1 to its
	-- default place, and blocks 2 and 3 beside block 1.
	ns[n == 1 and "BarBlockMoved" or ("BarBlockMoved" .. n)] = function()
		block.default = ns.MoverSpot(MOVERS[n], "BOTTOM") == nil
		if ns.Enabled(KEY) then
			Queue()
		end
	end
end

-- Tabs ---------------------------------------------------------------------------------------------------------------------------------------
-- While the handles of /flatui move are open (Movers.lua calls ns.BarBlockGrips as it lays its boxes out, and as it closes), each bar a block
-- places has a tab of the module's own at the left end of its row, inside the block's box and over it, which says which bar it is. A tab shows
-- while its block's box shows where the block is (not while the box is dragged). Dragging a tab moves it with the cursor and draws a line across
-- the block under the cursor where the bar would go: between two bars, or before the first or after the last, by the middles of the bars and
-- the block's Stack direction. Letting go there puts the bar at that place of the list of that block, its own or another, out of the block it
-- was in (ns.BarBlockPlace, BarBlockLists.lua), and the block lays out again from the list, as after the Bars and Add a bar rows of the page.
-- Escape (MoversMode.lua, ns.BarBlockGripCancel), a drop outside every box, a fight and the handles closing put the tab back and change
-- nothing. Nothing is dragged or dropped in a fight, where the handles close anyway: the block places protected bars.

-- The word on the tab of a bar.
local function GripText(id)
	if id == "main" then
		return "Main"
	end
	return ("Bar %s"):format((tostring(id):gsub("^bar", "")))
end

-- The colours of a tab, from the tokens of the options window (PanelLook.lua): the accent while it is under the cursor or dragged.
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

-- The left mouse button is up: let go away from the tab, which the tab may not hear.
local function Released()
	if type(IsMouseButtonDown) ~= "function" then
		return false
	end
	local ok, down = pcall(IsMouseButtonDown, "LeftButton")
	return ok and not ns.IsSecret(down) and down == false
end

-- The block whose box is under x, y and the place in it there: slot is the bar of its rows the dragged bar goes before, one past the last for
-- after it. Nothing outside every box shown.
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

-- The bottom (top false) or top of a row of a plan.
local function Edge(plan, row, top)
	local y = plan.spots[row.bar.frame].y
	return top and y + row.height or y
end

-- The height of the drop line of a target: halfway between the two bars it goes between, or half a gap past the first or the last.
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

-- Shows the drop line across the block of a target, or hides it with none.
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

-- Makes the tab of a number (below).
local GripMake

-- Puts a tab on each bar the blocks place, at the left end of its row, while the box of its block shows at the block; the others are hidden.
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

-- Ends the drag of a tab: with drop, the bar goes to the place under the cursor when that is in a box. True when a tab was being dragged.
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
	-- The tab goes back to its row, or to the new one once the block is laid out again.
	drag.tab.x = nil
	GripLayout()
	return true
end

-- Each frame of a drag: the tab follows the cursor and the drop line shows where the bar would go. A fight ends the drag with no change.
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
	-- The accent may have changed since the last drag.
	if GRIP.line and ns.PanelLook then
		ns.PanelLook.Solid(GRIP.line, "accent", 1)
	end
	GripPaint(tab, true)
	tab.frame:SetScript("OnUpdate", GripStep)
	GripStep()
end

-- A tab: a frame of the module's own over the boxes of /flatui move, with an outline and the name of its bar. A press picks the block's box.
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

-- Movers.lua: the handles are laid out (open) or closed. Closing ends a drag with no change.
function ns.BarBlockGrips(open)
	GRIP.shown = open == true and ns.Enabled(KEY)
	if not GRIP.shown then
		GripEnd(false)
	end
	if not GRIP.drag then
		GripLayout()
	end
end

-- MoversMode.lua: Escape puts a dragged tab back. True when a tab was being dragged, so Escape does nothing else.
function ns.BarBlockGripCancel()
	return GripEnd(false)
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

-- The first frame after a fight starts or ends: whether the client says the lockdown is on and how many held bars are still at their spot.
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
			if state.pending then
				Queue()
			end
		end,
	},
})
