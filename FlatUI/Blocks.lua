local _, ns = ...

-- The Bar blocks page names up to three of the game's own bars (Class spells, Buffs to apply, Consumables) and hangs each from a side of the
-- Action bar block, or from the bar picked on the page when the Bar block page is off. The game does the casting, the keys, the counts and the
-- cooldowns of these bars; this file only names the bar's box, works out where the bar goes and gives Movers the spot (ns.MoverHold), so it
-- never calls a method of a Blizzard frame. It reads rectangles and sizes only. A bar is held by one owner: the Bar block page comes first.
-- The pet bar can be hung from the same rectangle, above it on the right or the left.
-- All of it is planned out of combat. Action bars 6 to 8 stay where they were put in a fight; the game stacks the pet bar and bars 2 to 5 again
-- at the start and the end of a fight until each has been moved once in Edit Mode.

local KEY = "blocks"
local BARS = ns.BarFrames
local PET, PET_LABEL = "PetActionBar", "Pet bar"
-- The blocks in page order: the choice of the bar, the choice of the position and the name on screen.
local BLOCKS = {
	{ key = "class", name = "Class spells", bar = "classBar", place = "classPlace" },
	{ key = "buffs", name = "Buffs to apply", bar = "buffsBar", place = "buffsPlace" },
	{ key = "consumables", name = "Consumables", bar = "consumablesBar", place = "consumablesPlace" },
}
-- The bar a button belongs to, from the name of the button without its number (ActionBars.lua).
local PREFIXES = { ActionButton = "main", MultiBarBottomLeftButton = "bar2", MultiBarBottomRightButton = "bar3", MultiBarRightButton = "bar4",
	MultiBarLeftButton = "bar5", MultiBar5Button = "bar6", MultiBar6Button = "bar7", MultiBar7Button = "bar8" }
local WATCH_EVERY = 0.5
-- The game stacks the pet bar and bars 2 to 5 itself; the others it leaves where they are put.
local STACKED_TOGGLE = 4

-- queued: a replan is waiting for the next frame. pending: a fight stopped a replan. on: the page has something to place. last: the plan in
-- use. sig: the signature of the last plan made, whether it was used or not. notes: lines for /flatui status from the last plan.
local state = { queued = false, pending = false, on = false, notes = {} }

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

local function GameFrame(name)
	local frame = _G[name]
	if type(frame) == "table" and not ns.IsSecret(frame) and not ns.Forbidden(frame) then
		return frame
	end
	return nil
end

-- The bars picked, in page order. A bar already taken by an earlier block has `twin`, the block that keeps it.
local function Picks()
	local picks, claimed = {}, {}
	if not ns.Enabled(KEY) then
		return picks
	end
	for _, block in ipairs(BLOCKS) do
		local id = Opt(block.bar)
		local bar = id ~= "main" and BARS[id] or nil
		if bar then
			local twin = claimed[bar.frame]
			claimed[bar.frame] = claimed[bar.frame] or block
			picks[#picks + 1] = { block = block, id = id, bar = bar, twin = twin }
		end
	end
	return picks
end

-- The name of the block a bar is in, nil for a bar that is in none.
function ns.BlockLabel(name)
	if type(name) ~= "string" then
		return nil
	end
	for _, pick in ipairs(Picks()) do
		if pick.bar.frame == name and not pick.twin then
			return pick.block.name
		end
	end
	return nil
end

-- The key of the block an action button is in (class, buffs or consumables), nil for a button in none. A button or its name.
function ns.BlockOf(button)
	local name = button
	if type(button) == "table" and not ns.IsSecret(button) then
		local ok, got = pcall(button.GetName, button)
		name = ok and got or nil
	end
	if type(name) ~= "string" or ns.IsSecret(name) then
		return nil
	end
	local id = PREFIXES[name:match("^(.-)%d+$") or ""]
	if not id then
		return nil
	end
	for _, pick in ipairs(Picks()) do
		if pick.id == id and not pick.twin then
			return pick.block.key
		end
	end
	return nil
end

-- True only when the game says the bar is switched off in its options.
local function IsOff(bar)
	if not bar.toggle or type(GetActionBarToggles) ~= "function" then
		return false
	end
	local ok, value = pcall(function()
		return select(bar.toggle, GetActionBarToggles())
	end)
	return ok and not ns.IsSecret(value) and value == false
end

-- Whether the Bar block page has the bar in a row.
local function InMainBlock(id)
	if not ns.Enabled("barblock") then
		return false
	end
	for index = 1, 6 do
		if ns.Get("barblock.slot" .. index) == id then
			return true
		end
	end
	return false
end

-- Whether the Bar block page places the pet bar over the block.
local function MainOwnsPet()
	return ns.Enabled("barblock") and ns.Get("barblock.others") == "above" and ns.MainBlock() ~= nil
end

-- The bars to place, block bars in page order and then the pet bar: frame, name of the bar, position and the bar's entry. `lines` collects what
-- /flatui status says about a bar that is left out.
local function Requests(lines)
	local list = {}
	-- With no Action bar block to hang from, the bar picked on the page is the reference and is not placed itself.
	local from = ns.MainBlock() == nil and (BARS[Opt("from")] or BARS.main).frame or nil
	for _, pick in ipairs(Picks()) do
		local bar, name = pick.bar, pick.block.name
		if pick.twin then
			lines[#lines + 1] = ("%s: %s is already used by %s."):format(name, bar.label, pick.twin.name)
		elseif bar.frame == from then
			-- Left where it is, without a line.
		elseif InMainBlock(pick.id) then
			lines[#lines + 1] = ("%s is already in the Action bar block."):format(bar.label)
		elseif IsOff(bar) then
			lines[#lines + 1] = ("%s: %s is off in the game's options."):format(name, bar.label)
		else
			local place = Opt(pick.block.place)
			if place ~= "free" then
				list[#list + 1] = { frame = bar.frame, label = bar.label, place = place, bar = bar, name = name }
			end
		end
	end
	local pet = Opt("petPlace")
	if ns.Enabled(KEY) and pet ~= "game" then
		if MainOwnsPet() then
			lines[#lines + 1] = "Pet bar: placed by the Bar block page."
		else
			list[#list + 1] = { frame = PET, label = PET_LABEL, place = pet, name = PET_LABEL }
		end
	end
	return list
end

-- The rectangle the blocks hang from: the Action bar block, else the bar picked on the page. Nothing, and the name of the bar, when it has no
-- size now or is hidden.
local function Reference()
	local left, bottom, width, height, over = ns.MainBlock()
	if left then
		return { left = left, bottom = bottom, right = left + width, top = bottom + height, above = ns.Get("barblock.others") == "above" and over or nil }
	end
	local bar = BARS[Opt("from")] or BARS.main
	local frame = GameFrame(bar.frame)
	if frame and ns.MoverShown(frame) ~= false then
		local l, b, w, h = ns.MoverRect(frame)
		if l and w > 0 and h > 0 then
			return { left = l, bottom = b, right = l + w, top = b + h, frame = bar.frame }
		end
	end
	return nil, bar.label
end

-- The bottom left of a bar of size w by h at a position, with `used` already taken outward at that position.
-- Shared with the setup drawing of the Class, buffs and consumables bars (SetupDrawBars.lua), which must place bars the same way.
function ns.BlockWhere(ref, place, w, h, gap, used)
	local x, y
	if place == "aboveLeft" or place == "aboveRight" then
		x = place == "aboveLeft" and ref.left or ref.right - w
		y = (ref.above or ref.top) + gap + used
	elseif place == "belowLeft" or place == "belowRight" then
		x = place == "belowLeft" and ref.left or ref.right - w
		y = ref.bottom - gap - used - h
	elseif place == "leftBottom" or place == "leftTop" then
		x = ref.left - gap - used - w
		y = place == "leftBottom" and ref.bottom or ref.top - h
	else
		x = ref.right + gap + used
		y = place == "rightBottom" and ref.bottom or ref.top - h
	end
	return x, y
end
local Where = ns.BlockWhere

-- The spots of the bars to place, as a plan: spots, signature and the lines for the status. A plan with no `ready` has nothing to hand over,
-- because the rectangle the bars hang from cannot be read.
local function Plan()
	local lines = {}
	local list = Requests(lines)
	local plan = { spots = {}, lines = lines, list = list, ready = true }
	local parts = { ("%.1f"):format(Opt("gap")) }
	for _, line in ipairs(lines) do
		parts[#parts + 1] = line
	end
	if #list == 0 then
		plan.sig = table.concat(parts, ";")
		return plan
	end
	local ref, missing = Reference()
	if not ref then
		plan.ready = false
		lines[#lines + 1] = ("%s has no size yet."):format(missing)
		parts[#parts + 1] = "noref:" .. missing
		plan.sig = table.concat(parts, ";")
		return plan
	end
	parts[#parts + 1] = ("ref:%.1f,%.1f,%.1f,%.1f,%.1f"):format(ref.left, ref.bottom, ref.right, ref.top, ref.above or ref.top)
	local gap, used = Opt("gap"), {}
	for _, item in ipairs(list) do
		local frame = GameFrame(item.frame)
		local left, bottom, width, height
		if frame then
			left, bottom, width, height = ns.MoverRect(frame)
		end
		if left and width > 0 and height > 0 then
			local taken = used[item.place] or 0
			local x, y = Where(ref, item.place, width, height, gap, taken)
			local vertical = item.place:find("above", 1, true) or item.place:find("below", 1, true)
			used[item.place] = taken + (vertical and height or width) + gap
			plan.spots[item.frame] = { point = "BOTTOMLEFT", x = x, y = y }
			parts[#parts + 1] = ("%s:%s:%.1f:%.1f:%.1f:%.1f"):format(item.frame, item.place, width, height, x, y)
		else
			lines[#lines + 1] = ("%s has no size yet."):format(item.label)
			parts[#parts + 1] = "nosize:" .. item.frame
		end
	end
	plan.sig = table.concat(parts, ";")
	return plan
end

local function Release()
	state.pending, state.on = false, false
	if state.last then
		state.last = nil
		ns.MoverHold(KEY, nil)
	end
	state.sig, state.notes = nil, {}
	if state.watch then
		state.watch:Hide()
	end
end

local function Replan()
	-- Nothing is held while Flat UI leaves the game's action bars alone.
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
	local plan = Plan()
	state.notes = plan.lines
	state.sig = plan.sig
	if not plan.ready then
		return
	end
	if next(plan.spots) == nil then
		if state.last then
			state.last = nil
			ns.MoverHold(KEY, nil)
		end
		return
	end
	if state.last and state.last.sig == plan.sig then
		return
	end
	state.last = plan
	ns.MoverHold(KEY, plan.spots)
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

-- A bar that is laid out later, a bar turned on in the game's options or a block that moved changes the plan.
local function Watch(_, elapsed)
	state.clock = (state.clock or 0) + elapsed
	if state.clock < WATCH_EVERY then
		return
	end
	state.clock = 0
	if not InCombatLockdown() and not state.queued and Plan().sig ~= state.sig then
		Queue()
	end
end

-- Whether the page has a bar to name or place.
local function Wanted()
	if not ns.Enabled(KEY) then
		return false
	end
	return #Picks() > 0 or Opt("petPlace") ~= "game"
end

local function Refresh()
	if not Wanted() then
		Release()
		return
	end
	state.on = true
	if not state.watch then
		state.watch = CreateFrame("Frame")
		ns.Own[state.watch] = true
		state.watch:SetScript("OnUpdate", Watch)
	end
	state.watch:Show()
	Queue()
	if ns.MoverRelabel then
		ns.MoverRelabel()
	end
end

-- The Action bar block changed or went: the blocks hang from it.
function ns.BlocksReplan()
	if state.on then
		Queue()
	end
end

local PLACES = { free = "where its handle is", aboveLeft = "above, left", aboveRight = "above, right", belowLeft = "below, left", belowRight = "below, right",
	leftBottom = "left, bottom", leftTop = "left, top", rightBottom = "right, bottom", rightTop = "right, top" }

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if ns.HandsOff() then
		lines[#lines + 1] = "Bar blocks: not applied while Leave the game's action bars alone is on."
		return lines
	end
	local plan = Plan()
	for _, line in ipairs(plan.lines) do
		lines[#lines + 1] = line
	end
	if #plan.list == 0 then
		return lines
	end
	local movers, systems, keep = ns.MoverHoldGates()
	if not movers then
		lines[#lines + 1] = "Bar blocks: Movers are off, so the bars are not placed."
	end
	if not systems then
		lines[#lines + 1] = "Bar blocks: Move the game's own frames is off, so the bars are not placed."
	end
	if not keep then
		lines[#lines + 1] = "Bar blocks: Keep moved frames in place is off, so the game puts the bars back."
	end
	for _, item in ipairs(plan.list) do
		local info = ns.MoverHeld(item.frame)
		if info.state == "refused" then
			lines[#lines + 1] = ("%s is placed by the game, so it is left where the game puts it."):format(item.label)
		elseif movers and systems and keep and info.held and info.default == true and (item.frame == PET or item.bar.toggle <= STACKED_TOGGLE) then
			lines[#lines + 1] = ("%s: the game still stacks it and moves it in combat. In Edit Mode press an arrow key once on it and save to keep it."):format(item.label)
		end
	end
	return lines
end

-- /flatui blocks: each block, its bar and its position, one line each.
local function List()
	local picked = {}
	for _, pick in ipairs(Picks()) do
		if not pick.twin then
			picked[pick.block.key] = pick
		end
	end
	for _, block in ipairs(BLOCKS) do
		local pick = picked[block.key]
		if pick then
			print(("%s: %s, %s"):format(block.name, pick.bar.label, PLACES[Opt(block.place)] or "where its handle is"))
		else
			print(("%s: no bar"):format(block.name))
		end
	end
	print(("%s: %s"):format(PET_LABEL, Opt("petPlace") == "game" and "where the game puts it" or PLACES[Opt("petPlace")] or "where the game puts it"))
end

ns.Register(KEY, {
	label = "Bar blocks",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Resized = Refresh,
	Status = Status,
	slash = { blocks = List },
	help = { "/flatui blocks - the bars used as blocks" },
	events = {
		PLAYER_ENTERING_WORLD = Queue,
		EDIT_MODE_LAYOUTS_UPDATED = Queue,
		PLAYER_SPECIALIZATION_CHANGED = Queue,
		PLAYER_REGEN_ENABLED = function()
			if state.pending then
				Queue()
			end
		end,
	},
})
