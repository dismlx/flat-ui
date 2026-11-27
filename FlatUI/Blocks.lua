local _, ns = ...

local KEY = "blocks"
local BARS = ns.BarFrames
local PET, PET_LABEL = "PetActionBar", "Pet bar"
local BLOCKS = {
	{ key = "class", name = "Class spells", bar = "classBar", place = "classPlace" },
	{ key = "buffs", name = "Buffs to apply", bar = "buffsBar", place = "buffsPlace" },
	{ key = "consumables", name = "Consumables", bar = "consumablesBar", place = "consumablesPlace" },
}
local PREFIXES = { ActionButton = "main", MultiBarBottomLeftButton = "bar2", MultiBarBottomRightButton = "bar3", MultiBarRightButton = "bar4",
	MultiBarLeftButton = "bar5", MultiBar5Button = "bar6", MultiBar6Button = "bar7", MultiBar7Button = "bar8" }
local WATCH_EVERY = 0.5
local STACKED_TOGGLE = 4

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

local function IsOff(bar)
	if not bar.toggle or type(GetActionBarToggles) ~= "function" then
		return false
	end
	local ok, value = pcall(function()
		return select(bar.toggle, GetActionBarToggles())
	end)
	return ok and not ns.IsSecret(value) and value == false
end

local function InMainBlock(id)
	local bar = BARS[id]
	return bar ~= nil and ns.BarBlockHolds ~= nil and ns.BarBlockHolds(bar.frame) ~= nil
end

local function MainOwnsPet()
	return ns.Enabled("barblock") and ns.Get("barblock.others") == "above" and not ns.HandsOff() and ns.MainBlock() ~= nil
end

local function Requests(lines)
	local list = {}
	local from = ns.MainBlock() == nil and (BARS[Opt("from")] or BARS.main).frame or nil
	for _, pick in ipairs(Picks()) do
		local bar, name = pick.bar, pick.block.name
		if pick.twin then
			lines[#lines + 1] = ("%s: %s is already used by %s."):format(name, bar.label, pick.twin.name)
		elseif bar.frame == from then
		elseif InMainBlock(pick.id) then
			lines[#lines + 1] = ("%s is already in a block of the Bar block page."):format(bar.label)
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
	if not ns.Enabled(KEY) or ns.HandsOff() then
		Release()
		return
	end
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
		lines[#lines + 1] = "Class and item bars: not applied while Leave the game's action bars alone is on."
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
		lines[#lines + 1] = "Class and item bars: Movers are off, so the bars are not placed."
	end
	if not systems then
		lines[#lines + 1] = "Class and item bars: Move the game's own frames is off, so the bars are not placed."
	end
	if not keep then
		lines[#lines + 1] = "Class and item bars: Keep moved frames in place is off, so the game puts the bars back."
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
	label = "Class and item bars",
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
