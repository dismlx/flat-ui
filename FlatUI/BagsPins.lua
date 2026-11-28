local _, ns = ...

local B = ns.Bags
local Pins = B.Pins

local PART = "pins"
local MOST = 100
local FIRST_BAG, LAST_BAG, REAGENT_BAG = 0, 5, 5
local CONTAINER, QUIVER = 1, 11
local PER_STEP, STEP_WAIT, MOST_RUN, CHECK_AFTER, ARRIVAL, FAILS = 4, 1, 10, 1, 0.2, 2
local PENDING = 3
local DISABLE_AUTO_SORT = 1
local MARK_SIZE, MARK_INSET, GHOST_ALPHA, CROP = 7, 2, 0.35, 0.08
local SAY = {
	pinned = "%s is pinned to %s, slot %d: Flat UI puts it back there after a clean up and when it comes back. Ctrl+right-click it again to unpin it.",
	pinnedOff = "%s is pinned to %s, slot %d. Put pinned items back is off, so Flat UI does not move it there. Ctrl+right-click it again to unpin it.",
	unpinned = "%s, slot %d is no longer pinned.",
	full = "%d slots are pinned already. Unpin one with Pinned slots on the Bags page first.",
	saved = "slots can be pinned once your saved settings have loaded.",
	bags = "only a slot of your bags can be pinned, not the keyring or the bank.",
	all = "every pinned slot is unpinned.",
	none = "no slot is pinned. Ctrl+right-click an item in your bags to pin its slot.",
	fight = "pinned items are put back once the fight is over.",
	loot = "Ctrl is your Auto Loot Key, so Ctrl+right-click opens an item that holds loot, as a right-click does, and its pin is left as it was. "
		.. "Drop the item on the title of Keep in place to pin its slot, or on another section to unpin it.",
	lootJunk = "Alt is your Auto Loot Key, so Alt+right-click opens an item that holds loot, as a right-click does. Drop the item on Junk's title "
		.. "to put it on your sell list instead.",
	junkPinned = "%s is pinned to its slot, so it is never sold. Unpin it first (Ctrl+right-click).",
	junkFight = "your sell list changes out of combat only. Try again once the fight is over.",
}

local spots = setmetatable({}, { __mode = "k" })
local marks = setmetatable({}, { __mode = "k" })
local counts = nil
local run = nil
local soon, arrived, afterFight, fightAsked, fightAll, fightOnly = false, nil, false, false, false, nil

local function Say(text)
	print("Flat UI: " .. text)
end

local function Whole(value)
	return ns.Finite(value) and value == math.floor(value)
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Container(name)
	return type(C_Container) == "table" and C_Container[name] or nil
end

local function Item(name)
	return type(C_Item) == "table" and C_Item[name] or nil
end

local function Part(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(PART, fn, ...)
	end
	return pcall(fn, ...)
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Now()
	local now = Ask(GetTime)
	return ns.Finite(now) and now or 0
end

local function On()
	return Ask(B.On) == true
end

local function MovesOn()
	return Ask(B.Opt, "pinMoves") ~= false
end

local function Request(flag)
	if type(B.Request) == "function" then
		B.Request(flag, "bags")
	end
end

local function Down(name)
	local fn = _G[name]
	if type(fn) ~= "function" then
		return false
	end
	local ok, down = pcall(fn)
	return ok and (ns.IsSecret(down) or down == true)
end

local function Fighting()
	local ok, lockdown = pcall(InCombatLockdown)
	if not ok or ns.IsSecret(lockdown) or lockdown == true then
		return true
	end
	local okUnit, combat = pcall(UnitAffectingCombat, "player")
	return okUnit and (ns.IsSecret(combat) or combat == true)
end

local function Cursor()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok or kind == nil or ns.IsSecret(kind) then
		return nil
	end
	return kind, not ns.IsSecret(id) and id or nil
end

local function CursorHeld()
	local ok, held = pcall(CursorHasItem)
	return ok and (ns.IsSecret(held) or held == true)
end

local function Clear()
	if type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
end

local function Held()
	local kind, id = Cursor()
	if kind ~= "item" or not Whole(id) then
		return nil
	end
	local location = type(C_Cursor) == "table" and Ask(C_Cursor.GetCursorItem) or nil
	if type(location) ~= "table" then
		return id
	end
	local ok, bag, slot = pcall(function()
		return location.bagID, location.slotIndex
	end)
	if ok and Whole(bag) and Whole(slot) then
		return id, bag, slot
	end
	return id
end

local function Store(make)
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	local pins = char.bagPins
	if type(pins) ~= "table" then
		if not make then
			return nil
		end
		pins = {}
		char.bagPins = pins
	end
	return pins
end

local function SlotKey(bag, slot)
	return bag .. ":" .. slot
end

local function InBags(bag)
	return Whole(bag) and bag >= FIRST_BAG and bag <= LAST_BAG
end

local function Parse(key)
	if type(key) ~= "string" then
		return nil
	end
	local bag, slot = key:match("^(%d+):(%d+)$")
	bag, slot = tonumber(bag), tonumber(slot)
	if InBags(bag) and Whole(slot) and slot >= 1 then
		return bag, slot
	end
	return nil
end

local function List()
	local list = {}
	for key, id in pairs(Store(false) or {}) do
		local bag, slot = Parse(key)
		if bag and Whole(id) and id > 0 then
			list[#list + 1] = { bag = bag, slot = slot, id = id, key = key }
		end
	end
	table.sort(list, function(a, b)
		if a.bag ~= b.bag then
			return a.bag < b.bag
		end
		return a.slot < b.slot
	end)
	return list
end

function Pins.Get(bag, slot)
	if not InBags(bag) or not Whole(slot) then
		return nil
	end
	local store = Store(false)
	local id = store and store[SlotKey(bag, slot)]
	if Whole(id) and id > 0 then
		return id
	end
	return nil
end

function Pins.Of(record)
	if type(record) ~= "table" or record.live ~= true or not Whole(record.id) then
		return false
	end
	if record.key ~= nil and record.key ~= ns.CharacterKey() then
		return false
	end
	return Pins.Get(record.bag, record.slot) == record.id
end

local function Named(id)
	local name = Ask(Item("GetItemNameByID"), id)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return ("Item %d"):format(id)
end

local function BagLabel(bag)
	if bag == 0 then
		local word = _G.BAG_NAME_BACKPACK
		return type(word) == "string" and not ns.IsSecret(word) and word ~= "" and word or "Backpack"
	end
	local name = Ask(Container("GetBagName"), bag)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return ("Bag %d"):format(bag)
end

local function CountOf(id)
	local count = Ask(Item("GetItemCount"), id)
	return Whole(count) and count or 0
end

local function Counts()
	local fresh = {}
	for _, pin in ipairs(List()) do
		if fresh[pin.id] == nil then
			fresh[pin.id] = CountOf(pin.id)
		end
	end
	return fresh
end

local function Changed()
	counts = Counts()
	Request("items")
	Request("layout")
end

local function Pin(bag, slot, id)
	local store = Store(true)
	if not store then
		Say(SAY.saved)
		return false
	end
	local key = SlotKey(bag, slot)
	if store[key] == nil then
		local count = 0
		for _ in pairs(store) do
			count = count + 1
		end
		if count >= MOST then
			Say(SAY.full:format(MOST))
			return false
		end
	end
	store[key] = id
	if type(ns.ErrandsJunkMark) == "function" then
		pcall(ns.ErrandsJunkMark, id, false)
	end
	Say((MovesOn() and SAY.pinned or SAY.pinnedOff):format(Named(id), BagLabel(bag), slot))
	Changed()
	return true
end

local function Unpin(bag, slot, quiet)
	local store = Store(false)
	local key = SlotKey(bag, slot)
	if not store or store[key] == nil then
		return false
	end
	store[key] = nil
	if not quiet then
		Say(SAY.unpinned:format(BagLabel(bag), slot))
	end
	Changed()
	return true
end

local function UnpinAll(quiet)
	local char = ns.Character()
	if type(char) ~= "table" or type(char.bagPins) ~= "table" or next(char.bagPins) == nil then
		return false
	end
	char.bagPins = nil
	if not quiet then
		Say(SAY.all)
	end
	Changed()
	return true
end

function Pins.Toggle(bag, slot)
	if not InBags(bag) or not Whole(slot) then
		return false
	end
	if Pins.Get(bag, slot) ~= nil or (Store(false) or {})[SlotKey(bag, slot)] ~= nil then
		return Unpin(bag, slot, false)
	end
	local id = Ask(Container("GetContainerItemID"), bag, slot)
	if not Whole(id) or id <= 0 then
		return false
	end
	return Pin(bag, slot, id)
end

local function Looted(bag, slot)
	if type(IsModifiedClick) ~= "function" then
		return false
	end
	local ok, on = pcall(IsModifiedClick, "AUTOLOOTTOGGLE")
	if not ok or ns.IsSecret(on) or on ~= true then
		return false
	end
	local data = Ask(Container("GetContainerItemInfo"), bag, slot)
	if type(data) ~= "table" then
		return false
	end
	local okLoot, loot = pcall(function()
		return data.hasLoot
	end)
	return okLoot and (ns.IsSecret(loot) or loot == true)
end

local function Junk(bag, slot)
	local id = Ask(Container("GetContainerItemID"), bag, slot)
	if not Whole(id) or id <= 0 then
		return
	end
	if Fighting() then
		Say(SAY.junkFight)
		return
	end
	local read = B.Data and B.Data.Item
	local okRecord, record = false, nil
	if type(read) == "function" then
		okRecord, record = pcall(read, ns.CharacterKey(), bag, slot)
	end
	if not okRecord or type(record) ~= "table" or record.id ~= id then
		record = { id = id, bag = bag, slot = slot, live = true }
	end
	if Pins.Get(bag, slot) == id then
		Say(SAY.junkPinned:format(Named(id)))
		return
	end
	local categories = B.Categories
	local isJunk = type(categories) == "table" and type(categories.IsJunk) == "function" and categories.IsJunk(record) == true
	if isJunk then
		local mark = ns.ErrandsJunkMark
		if type(mark) == "function" and mark(id, false) then
			Request("items")
			Request("layout")
		end
		return
	end
	local file = type(categories) == "table" and categories.File or nil
	if type(file) == "function" and file(id, "junk", type(record.link) == "string" and not ns.IsSecret(record.link) and record.link or nil, bag, slot)
		== true then
		local took = B.Custom and B.Custom.Took
		if type(took) == "function" then
			B.Part("custom", took, "bags", "junk", id)
		end
	end
end

local function Clicked(button, mouse)
	if mouse ~= "RightButton" then
		return
	end
	local ctrl, shift, alt = Down("IsControlKeyDown"), Down("IsShiftKeyDown"), Down("IsAltKeyDown")
	local pin, junk = ctrl and not shift and not alt, alt and not ctrl and not shift
	if not pin and not junk then
		return
	end
	local spot = spots[button]
	if not spot or Cursor() ~= nil or not On() then
		return
	end
	if Looted(spot.bag, spot.slot) then
		Say(pin and SAY.loot or SAY.lootJunk)
		return
	end
	if pin then
		Pins.Toggle(spot.bag, spot.slot)
	else
		Junk(spot.bag, spot.slot)
	end
end

local function Click(button, mouse)
	if mouse == "RightButton" then
		Part(Clicked, button, mouse)
	end
end

function Pins.Hook(button, bag, slot)
	if spots[button] or not InBags(bag) or not Whole(slot) or type(button) ~= "table" or type(button.HookScript) ~= "function" then
		return
	end
	spots[button] = { bag = bag, slot = slot }
	button:HookScript("OnClick", Click)
end

function Pins.Drop()
	local id, bag, slot = Held()
	if not id then
		return false
	end
	if not InBags(bag) or not Whole(slot) then
		Say(SAY.bags)
		return false
	end
	if Pins.Get(bag, slot) == id then
		return false
	end
	return Pin(bag, slot, id)
end

function Pins.Held()
	return Held()
end

function Pins.Left(id, bag, slot)
	local categories = B.Categories
	if type(categories) == "table" and type(categories.Hidden) == "function" and categories.Hidden("keep") == true then
		return
	end
	if Whole(id) and InBags(bag) and Pins.Get(bag, slot) == id then
		Unpin(bag, slot, false)
	end
end

function Pins.Any()
	return #List() > 0
end

local function Accent()
	local ok, r, g, b = pcall(ns.WindowColour, "windows.accent")
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return 0.85, 0.85, 0.85
end

local function Texture(button, layer, sublevel)
	local ok, texture = pcall(button.CreateTexture, button, nil, layer, nil, sublevel)
	if ok and type(texture) == "table" and not ns.IsSecret(texture) then
		ns.Own[texture] = true
		return texture
	end
	return nil
end

local function Regions(button)
	local made = marks[button]
	if made ~= nil then
		return made or nil
	end
	local edge, fill, ghost = Texture(button, "OVERLAY", 6), Texture(button, "OVERLAY", 7), Texture(button, "BORDER", 2)
	if not (edge and fill and ghost) then
		marks[button] = false
		return nil
	end
	edge:SetSize(MARK_SIZE, MARK_SIZE)
	edge:SetPoint("TOPRIGHT", button, "TOPRIGHT", -MARK_INSET, -MARK_INSET)
	fill:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
	ghost:SetPoint("TOPLEFT", button, "TOPLEFT", MARK_INSET, -MARK_INSET)
	ghost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -MARK_INSET, MARK_INSET)
	ghost:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	ghost:SetDesaturated(true)
	ghost:SetAlpha(GHOST_ALPHA)
	made = { edge = edge, fill = fill, ghost = ghost }
	marks[button] = made
	return made
end

function Pins.Mark(button, kind, bag, slot, record)
	local id = kind == "live" and Pins.Get(bag, slot) or nil
	local made = marks[button]
	if not id then
		if made then
			made.edge:Hide()
			made.fill:Hide()
			made.ghost:Hide()
		end
		return
	end
	made = Regions(button)
	if not made then
		return
	end
	local here = type(record) == "table" and Whole(record.id) and record.id or nil
	local r, g, b = Accent()
	if here == nil or here == id then
		made.edge:SetColorTexture(0, 0, 0, 0.9)
		made.fill:SetColorTexture(r, g, b, 1)
	else
		made.edge:SetColorTexture(r, g, b, 1)
		made.fill:SetColorTexture(0, 0, 0, 0.85)
	end
	made.edge:Show()
	made.fill:Show()
	local icon = here == nil and Ask(Item("GetItemIconByID"), id) or nil
	if icon then
		made.ghost:SetTexture(icon)
		made.ghost:Show()
	else
		made.ghost:Hide()
	end
end

local Start

local function Ignored(bag)
	if bag == 0 then
		return Ask(Container("GetBackpackAutosortDisabled")) == true
	end
	local enum = type(Enum) == "table" and not ns.IsSecret(Enum) and Enum.BagSlotFlags or nil
	local flag = type(enum) == "table" and not ns.IsSecret(enum) and enum.DisableAutoSort or nil
	return Ask(Container("GetBagSlotFlag"), bag, Whole(flag) and flag or DISABLE_AUTO_SORT) == true
end

local function Read()
	local bags = {}
	local info, free = Container("GetContainerItemInfo"), Container("GetContainerNumFreeSlots")
	for bag = FIRST_BAG, LAST_BAG do
		local size = Ask(Container("GetContainerNumSlots"), bag)
		size = Whole(size) and size > 0 and size or 0
		local family = nil
		if type(free) == "function" then
			local ok, _, bagFamily = pcall(free, bag)
			if ok and not ns.IsSecret(bagFamily) then
				family = Whole(bagFamily) and bagFamily or 0
			end
		end
		local slots = {}
		for slot = 1, size do
			local entry = false
			local data = Ask(info, bag, slot)
			if type(data) == "table" then
				local ok, id, count, locked = pcall(function()
					return data.itemID, data.stackCount, data.isLocked
				end)
				if ok and Whole(id) then
					entry = { id = id, count = Whole(count) and count or 1, locked = ns.IsSecret(locked) or locked == true }
				end
			end
			slots[slot] = entry
		end
		bags[bag] = { size = size, family = family, ignored = Ignored(bag), slots = slots }
	end
	return bags
end

local function TakesAny(bag, family)
	return bag ~= REAGENT_BAG and family == 0
end

local function Fits(id, bag, family)
	if TakesAny(bag, family) then
		return true
	end
	if bag == REAGENT_BAG or not Whole(family) or family == 0 then
		return false
	end
	local fn = Item("GetItemInfoInstant")
	if type(fn) == "function" then
		local ok, _, _, _, _, _, class = pcall(fn, id)
		if not ok or ns.IsSecret(class) or class == CONTAINER or class == QUIVER then
			return false
		end
	end
	local itemFamily = Ask(Item("GetItemFamily"), id)
	return Whole(itemFamily) and type(bit) == "table" and bit.band(itemFamily, family) ~= 0
end

local function FreeSlot(bags, pinned, used)
	for bag = FIRST_BAG, LAST_BAG do
		local b = bags[bag]
		if TakesAny(bag, b.family) and not b.ignored then
			for slot = 1, b.size do
				local key = SlotKey(bag, slot)
				if not b.slots[slot] and not pinned[key] and not used[key] then
					return { bag = bag, slot = slot, key = key }
				end
			end
		end
	end
	return nil
end

local function Source(bags, id, met, used)
	local best, most, locked = nil, 0, false
	for bag = FIRST_BAG, LAST_BAG do
		local b = bags[bag]
		for slot = 1, b.size do
			local entry = b.slots[slot]
			local key = SlotKey(bag, slot)
			if entry and entry.id == id and not met[key] and not used[key] then
				if entry.locked then
					locked = true
				elseif entry.count > most then
					best, most = { bag = bag, slot = slot, key = key }, entry.count
				end
			end
		end
	end
	return best, locked
end

local function Settled(bags, key, wait)
	local bag, slot = Parse(key)
	local b = bag and bags[bag]
	local entry = b and b.slots[slot]
	if wait.id then
		return entry and entry.id == wait.id and not entry.locked
	end
	return not (entry and entry.locked)
end

local function Plan(r)
	local bags = Read()
	local pins = List()
	local pinned, met, used = {}, {}, {}
	local moves, waits = {}, false
	local now = Now()
	for key, wait in pairs(r.pending) do
		if Settled(bags, key, wait) or now - wait.at >= PENDING then
			r.pending[key] = nil
		else
			used[key] = true
			waits = true
		end
	end
	for _, pin in ipairs(pins) do
		pinned[pin.key] = pin.id
		local b = bags[pin.bag]
		local entry = b and pin.slot <= b.size and b.slots[pin.slot]
		if entry and entry.id == pin.id then
			met[pin.key] = true
		end
	end
	for _, pin in ipairs(pins) do
		local b = bags[pin.bag]
		if #moves >= PER_STEP then
			waits = true
			break
		end
		if not met[pin.key] and not r.skip[pin.key] and not used[pin.key] and (not r.only or r.only[pin.id]) and b and pin.slot <= b.size then
			local target = b.slots[pin.slot]
			local source, locked = Source(bags, pin.id, met, used)
			if not source then
				waits = waits or locked
			elseif target and target.locked then
				waits = true
			elseif pin.bag ~= REAGENT_BAG and not Fits(pin.id, pin.bag, b.family) then
				r.skip[pin.key] = true
			elseif not target or (not bags[source.bag].ignored and Fits(target.id, source.bag, bags[source.bag].family)) then
				moves[#moves + 1] = { from = source, to = pin, id = pin.id, key = pin.key }
				used[source.key], used[pin.key] = true, true
			else
				local free = FreeSlot(bags, pinned, used)
				if free then
					moves[#moves + 1] = { from = pin, to = free, id = target.id, key = pin.key }
					used[pin.key], used[free.key] = true, true
					waits = true
				else
					r.skip[pin.key] = true
				end
			end
		end
	end
	return moves, waits
end

local function Fail(r, key)
	r.fails[key] = (r.fails[key] or 0) + 1
	if r.fails[key] >= FAILS then
		r.skip[key] = true
	end
end

local function Move(r, move)
	local pick = Container("PickupContainerItem")
	if type(pick) ~= "function" then
		return false
	end
	pcall(pick, move.from.bag, move.from.slot)
	local kind, id = Cursor()
	if kind ~= "item" or id ~= move.id then
		Clear()
		Fail(r, move.key)
		return false
	end
	pcall(pick, move.to.bag, move.to.slot)
	if CursorHeld() then
		Clear()
		Fail(r, move.key)
		return true
	end
	r.moves, r.moved = r.moves + 1, r.moved + 1
	local at = Now()
	r.pending[move.from.key] = { at = at }
	r.pending[move.to.key] = { at = at, id = move.id }
	return true
end

local function Shown(name)
	local frame = _G[name]
	if type(frame) ~= "table" or ns.Forbidden(frame) then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and (ns.IsSecret(shown) or shown == true)
end

local function Busy(r)
	if Cursor() ~= nil then
		return "cursor"
	end
	local ok, targeting = pcall(SpellIsTargeting)
	if not ok or ns.IsSecret(targeting) or targeting == true then
		return "spell"
	end
	if type(ns.ErrandsSelling) == "function" and Ask(ns.ErrandsSelling) == true then
		return "selling"
	end
	if B.Bank and type(B.Bank.Busy) == "function" and Ask(B.Bank.Busy) ~= nil then
		return "bank"
	end
	if Shown("TradeFrame") then
		return "trade"
	end
	if Shown("StackSplitFrame") then
		return "split"
	end
	if type(B.Sorting) == "function" and B.Sorting("bags") then
		local hold = type(B.SortHold) == "function" and B.SortHold("bags") or nil
		if not r.own or (r.hold ~= nil and hold ~= r.hold) then
			return "sorting"
		end
	end
	return nil
end

local function AfterFight(asked, only)
	fightAsked = fightAsked or asked == true
	if type(only) == "table" then
		fightOnly = fightOnly or {}
		for id in pairs(only) do
			fightOnly[id] = true
		end
	else
		fightAll = true
	end
	if afterFight then
		return
	end
	afterFight = true
	local function Again()
		afterFight = false
		local wanted, all, ids = fightAsked, fightAll, fightOnly
		fightAsked, fightAll, fightOnly = false, false, nil
		if wanted or MovesOn() then
			Part(Start, false, nil, false, wanted, not all and ids or nil)
		end
	end
	local ok, lockdown = pcall(InCombatLockdown)
	if ok and lockdown == true and type(ns.OutOfCombat) == "function" then
		ns.OutOfCombat(Again)
	elseif not After(STEP_WAIT, Again) then
		afterFight, fightAsked, fightAll, fightOnly = false, false, false, nil
	end
end

local Step

local function Finish()
	local r = run
	run = nil
	if not r then
		return
	end
	if type(r.done) == "function" then
		pcall(r.done)
	elseif r.moved > 0 then
		Request("layout")
	end
	if r.moved > 0 and not r.check then
		After(CHECK_AFTER, function()
			if not run and (r.asked or MovesOn()) then
				Part(Start, false, nil, true, r.asked, r.only)
			end
		end)
	end
end

local function Later(r, seconds)
	r.token = (r.token or 0) + 1
	local token = r.token
	r.waiting = true
	if not After(seconds, function()
		if run == r and r.token == token then
			Part(Step)
		end
	end) then
		Finish()
	end
end

function Step()
	local r = run
	if not r then
		return
	end
	r.waiting = false
	if not On() or Now() - r.started >= MOST_RUN or r.moves >= r.most then
		return Finish()
	end
	if Fighting() then
		Finish()
		return AfterFight(r.asked, r.only)
	end
	if Busy(r) then
		return Later(r, STEP_WAIT)
	end
	local moves, waits = Plan(r)
	if #moves == 0 then
		if waits then
			return Later(r, STEP_WAIT)
		end
		return Finish()
	end
	for _, move in ipairs(moves) do
		if r.moves >= r.most or not Move(r, move) then
			break
		end
	end
	Later(r, STEP_WAIT)
end

function Start(own, done, check, asked, only, hold)
	if run then
		if done then
			local before = run.done
			run.done = function()
				if type(before) == "function" then
					pcall(before)
				end
				done()
			end
		end
		if own then
			run.own, run.hold = true, hold
		end
		run.asked = run.asked or asked
		if type(only) ~= "table" then
			run.only = nil
		elseif run.only then
			for id in pairs(only) do
				run.only[id] = true
			end
		end
		return true
	end
	local pins = List()
	if #pins == 0 or not On() then
		return false
	end
	run = { started = Now(), moves = 0, moved = 0, most = 2 * #pins + 4, fails = {}, skip = {}, pending = {}, done = done, own = own,
		hold = own and hold or nil, check = check, asked = asked, only = type(only) == "table" and only or nil }
	Step()
	return true
end

function Pins.AfterSort(done, hold)
	if not MovesOn() or #List() == 0 or not On() then
		return false
	end
	if Fighting() then
		AfterFight(false)
		return false
	end
	local going = false
	Part(function()
		going = Start(true, done, false, false, nil, hold) == true
	end)
	return going
end

local function Scanned()
	if run and run.waiting then
		Later(run, 0.1)
	end
	if next(Store(false) or {}) == nil then
		counts = nil
		return
	end
	local before = counts
	counts = Counts()
	if not before or not MovesOn() or (type(B.Sorting) == "function" and B.Sorting("bags")) then
		return
	end
	local rose = nil
	for _, pin in ipairs(List()) do
		local was = before[pin.id]
		if was and (counts[pin.id] or 0) > was and Ask(Container("GetContainerItemID"), pin.bag, pin.slot) ~= pin.id then
			rose = rose or {}
			rose[pin.id] = true
		end
	end
	if not rose then
		return
	end
	if run then
		if run.only then
			for id in pairs(rose) do
				run.only[id] = true
			end
		end
		return
	end
	arrived = arrived or {}
	for id in pairs(rose) do
		arrived[id] = true
	end
	if soon then
		return
	end
	soon = true
	if not After(ARRIVAL, function()
		soon = false
		local only = arrived
		arrived = nil
		if not only then
			return
		end
		if Fighting() then
			AfterFight(false, only)
		else
			Part(Start, false, nil, false, false, only)
		end
	end) then
		soon, arrived = false, nil
	end
end

function Pins.Scanned()
	Part(Scanned)
end

function Pins.Now()
	if #List() == 0 then
		Say(SAY.none)
		return
	end
	if Fighting() then
		Say(SAY.fight)
		AfterFight(true)
		return
	end
	Start(false, nil, false, true)
end

function Pins.MenuLines()
	return {
		{ text = "Put pinned items back now", part = PART, pick = Pins.Now },
		{ text = "Unpin all", part = PART, pick = function()
			UnpinAll(false)
		end },
	}
end

function ns.BagsPinLines()
	local list = List()
	if #list == 0 then
		return { { "none", "No slot is pinned. Ctrl+right-click an item in your bags to pin its slot." } }
	end
	local lines = {}
	if #list >= 2 then
		lines[1] = { "all", "Unpin all" }
	end
	for _, pin in ipairs(list) do
		local size = Ask(Container("GetContainerNumSlots"), pin.bag)
		local gone = Whole(size) and pin.slot > size
		lines[#lines + 1] = { pin.key, ("%s, slot %d: %s%s"):format(BagLabel(pin.bag), pin.slot, Named(pin.id), gone and " (no such slot)" or "") }
	end
	return lines
end

function ns.BagsPinPick(id)
	if id == "all" then
		if UnpinAll(true) then
			return true, "Flat UI: " .. SAY.all
		end
		return false, "Flat UI: " .. SAY.none
	end
	local bag, slot = Parse(id)
	if not bag or not Unpin(bag, slot, true) then
		return false, "Flat UI: " .. SAY.none
	end
	return true, "Flat UI: " .. SAY.unpinned:format(BagLabel(bag), slot)
end
