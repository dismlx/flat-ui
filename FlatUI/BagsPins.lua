local _, ns = ...

-- Bags: pinned slots and Keep in place. A pin saves one slot of this character's bags for one item: Ctrl+right-click an item in the bag window
-- to pin its slot, and again to unpin it. Keep in place is the section of the items that sit in their pinned slots, so "do not move this" and
-- "this slot is for this item" are one store, one mark and one mover. Bags.lua makes ns.Bags with B.Pins; this file only adds its fields, makes
-- textures of its own on Flat UI's own slot buttons, and owns no event: BagsData.lua tells it of each scan of the bags (Pins.Scanned), Bags.lua
-- hands it the end of a clean up (Pins.AfterSort), and ns.OutOfCombat the end of a fight.
--
-- The store: FlatUICharDB.bagPins (ns.Character), { ["bag:slot"] = itemID }, for this character alone, at most MOST pins, on the backpack, the
-- four bags and the reagent bag (0 to 5); never the keyring, the bank or another character. A pin keeps the real slot, so the window's place
-- follows from it: in Keep in place in the order of the bags, and the slot itself in Bag by bag. The item ID, not the item's GUID, is what is
-- kept, so a new copy of the item looted or bought counts as the item coming back.
--
-- The click: Ctrl+left-click is the dressing room (DRESSUP is CTRL-BUTTON1, Blizzard_FrameXML/Bindings_Camelot.xml:1541; HandleModifiedItemClick,
-- Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:388-390). The game's click of a bag slot (ContainerFrameItemButtonMixin:OnClick,
-- Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:1683-1697) sends any modified click to OnModifiedClick, never to use, sell or deposit, and
-- that (:1781-1815) acts only for EXPANDITEM (SHIFT-BUTTON2), CHATLINK (SHIFT-BUTTON1), DRESSUP (CTRL-BUTTON1), SPLITSTACK and AUTOLOOTTOGGLE
-- (SHIFT) (Bindings_Camelot.xml:1537-1543): the game tells Shift+left from Shift+right there, and Ctrl with the right button meets none of them,
-- so the game does nothing with it. Each live slot button of BagsItems.lua, Flat UI's own frame from the game's template, gets one post-hook of
-- its OnClick when it is made (HookScript), which runs after the game's secure click and changes nothing of it: it acts only for the right
-- button with Ctrl alone held (IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown), an empty cursor (GetCursorInfo) and Bags in use. The bag and
-- slot are the ones the button was made for. An item in an unpinned slot (C_Container.GetContainerItemID) gets its slot pinned; a pinned slot,
-- whatever it holds, is unpinned; an empty slot that is not pinned does nothing. A pin of an item of Junk, or of a grey item, takes it off
-- Errands' sell list and puts a grey one on the keep list (ns.ErrandsJunkMark, as a drop on another section does), so Sell junk never sells a
-- pinned item. A toggle is data alone, so it works in a fight too; one line in chat says what changed.
-- Other ways in and out: an item dropped on the title of Keep in place gets the slot it came from pinned (the cursor's slot, from
-- C_Cursor.GetCursorItem, as BagsCategories reads it); an item from a pinned slot dropped on another section's title unpins that slot
-- (BagsLayout.lua routes both drops here first, out of combat only, and gives the item back itself); the row Pinned slots unpins one slot or all;
-- and the menu of Keep in place's title has Put pinned items back now and Unpin all.
--
-- The mark (Pins.Mark, from B.Buttons.Draw for live slots, in both views): a square at the top right of the slot, a corner the slot does not use,
-- in the Highlight colour of the Windows page. Solid with a dark edge while the slot holds its item; hollow (a dark middle in a coloured edge)
-- while another item is there; and on an empty pinned slot the pinned item's icon (C_Item.GetItemIconByID) faded and grey, with the solid square.
-- In Sections an empty pinned slot keeps a cell in Keep in place, the live empty button, so an item dropped there goes in the slot.
--
-- Putting pinned items back (the mover), while Put pinned items back is on and always out of combat:
-- - after a clean up of the bags: the game's clean up (C_Container.SortBags, BagSort.lua) cannot leave single items alone (its ignore flags work on
--   whole bags), so the items are put back after it. When the sort hold of Bags.lua is due to end it hands over to Pins.AfterSort, and the hold,
--   with the busy sort button and no arrivals on the top shelf, lasts until the mover is done, MOST_RUN seconds at most; the window is laid out
--   once after it. In a fight AfterSort declines, the hold ends as before, and the mover runs once the fight is over.
-- - when a pinned item comes back: after each scan of BAG_UPDATE_DELAYED (Pins.Scanned) the count of each pinned item in the bags is read
--   (C_Item.GetItemCount, bags only), and a count that rose while a pin of that item waits starts the mover ARRIVAL seconds later: loot, a purchase,
--   buyback, mail, the bank, a trade or a quest reward. A move inside the bags changes no count, so the mover never undoes the player's own drag.
--   Scans during the sort hold, and the first scan of a session, only take the counts.
-- - at once from the menu of Keep in place's title, whatever that row says.
-- Each step reads the bags anew (C_Container.GetContainerNumSlots, GetContainerNumFreeSlots for the bag's family, GetContainerItemInfo), so steps
-- that mix with the game's or the player's moves mend themselves. A pin is met while its slot holds its item, whatever the stack. For each pin
-- that is not met, in the order of the bags: the source is the largest unlocked stack of the item that is not a met pin; an empty target gets
-- the move; a target that holds another item gets a swap, which the game makes when the source is put on it, the other item going to the source
-- slot, but only when that item fits the source's bag (a bag of family 0 that is not the reagent bag, or a special bag whose family
-- C_Item.GetItemFamily matches, never a container; C_Item.GetItemInfoInstant); else that item first goes to a free slot of a normal bag that is
-- not pinned, or the pin waits for the next run. Nothing is put on a slot that holds the same item, so stacks never merge, and nothing is split.
-- A move checks that neither slot is locked, picks the source up (C_Container.PickupContainerItem, not protected in the client list,
-- wowless/data/products/wowf/apis.yaml:8767, whose documentation asks only for plain arguments), checks the cursor holds that item (GetCursorInfo)
-- and puts it on the target; an item still on the cursor then goes back (CursorHasItem, ClearCursor) and counts as a failure of its pin. At most
-- PER_STEP moves on different slots go in one step, then the mover waits for the next scan or STEP_WAIT seconds; a run ends when a step finds
-- nothing to do, after 2 moves a pin and 4 more, after MOST_RUN seconds, and a pin that failed FAILS times waits for the next run. One more run
-- looks again CHECK_AFTER seconds after a run that moved something. A step waits while the cursor holds anything, a spell waits for its target
-- (SpellIsTargeting), Sell junk sells (ns.ErrandsSelling), Deposit or Take out run (B.Bank.Busy), the trade window shows (TradeFrame, IsShown) or
-- a sort hold lasts that is not its own; in a fight (InCombatLockdown, UnitAffectingCombat) the run ends and one waits for the fight's end
-- (ns.OutOfCombat). Its work runs as the part pins of the module (B.Part), so a fault stops it alone.
-- Limits: the put back is seen, not instant; the game may still put loot in an empty pinned slot, and the pinned item is swapped in when it next
-- comes or at the next clean up; a pin whose stack a clean up merged into another stays empty; only clean ups through BagSort are followed.

local B = ns.Bags
local Pins = B.Pins

local PART = "pins"
-- The most pins a character keeps; the bags they can be on (Enum.BagIndex: the backpack, the four bags and the reagent bag).
local MOST = 100
local FIRST_BAG, LAST_BAG, REAGENT_BAG = 0, 5, 5
-- Enum.ItemClass Container and Quiver (wowless, data/products/wowf/enums.yaml:4630-4651): never put in a special bag.
local CONTAINER, QUIVER = 1, 11
-- The mover: moves in one step, seconds to wait for a scan, seconds a run lasts at most, seconds to the run that looks again, seconds from an
-- item's arrival to its run, and the failures after which a pin waits for the next run.
local PER_STEP, STEP_WAIT, MOST_RUN, CHECK_AFTER, ARRIVAL, FAILS = 4, 1, 10, 1, 0.2, 2
-- The mark, in the units of the game's item button of 37: the square, its inset from the corner, and the faded icon of an empty pinned slot.
local MARK_SIZE, MARK_INSET, GHOST_ALPHA, CROP = 7, 2, 0.35, 0.08
local SAY = {
	pinned = "%s is pinned to %s, slot %d: Flat UI keeps it there. Ctrl+right-click it again to unpin it.",
	unpinned = "%s, slot %d is no longer pinned.",
	full = "%d slots are pinned already. Unpin one with Pinned slots on the Bags page first.",
	saved = "slots can be pinned once your saved settings have loaded.",
	bags = "only a slot of your bags can be pinned, not the keyring or the bank.",
	all = "every pinned slot is unpinned.",
	none = "no slot is pinned. Ctrl+right-click an item in your bags to pin its slot.",
	fight = "pinned items are put back once the fight is over.",
}

-- Per live button: the bag and slot it was made for. Per button: its mark { edge, fill, ghost }, or false when the game refused one.
local spots = setmetatable({}, { __mode = "k" })
local marks = setmetatable({}, { __mode = "k" })
-- The count of each pinned item in the bags at the last scan, nil before the first.
local counts = nil
-- The run of the mover: { started, moves, moved, most, fails, skip, done, own (the sort hold's own), asked, check, token, waiting }, or nil. An
-- arrival run waits (soon); a run waits for the end of a fight (afterFight), asked by the player (fightAsked).
local run = nil
local soon, afterFight, fightAsked = false, false, false

-- Small helpers -------------------------------------------------------------------------------------------------------------------------------

local function Say(text)
	print("Flat UI: " .. text)
end

local function Whole(value)
	return ns.Finite(value) and value == math.floor(value)
end

-- The first answer of a call of the client, or nil when it is missing, raises or is withheld.
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

-- A key held down, read from the client; a withheld answer counts as held.
local function Down(name)
	local fn = _G[name]
	if type(fn) ~= "function" then
		return false
	end
	local ok, down = pcall(fn)
	return ok and (ns.IsSecret(down) or down == true)
end

-- In a fight: the lockdown, or the player in combat, which can come a moment before it. A withheld answer counts as a fight.
local function Fighting()
	local ok, lockdown = pcall(InCombatLockdown)
	if not ok or ns.IsSecret(lockdown) or lockdown == true then
		return true
	end
	local okUnit, combat = pcall(UnitAffectingCombat, "player")
	return okUnit and (ns.IsSecret(combat) or combat == true)
end

-- The cursor: its kind and ID, or nil when it holds nothing.
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

-- The item on the cursor and the bag and slot it was taken from, when the game says (C_Cursor.GetCursorItem, an ItemLocation).
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

-- The store ------------------------------------------------------------------------------------------------------------------------------------

-- FlatUICharDB.bagPins, made with make; nil before the saved variables load, or when there is none and make is not set.
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

-- Every pin, in the order of the bags: { { bag, slot, id, key }, ... }.
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

-- The item a slot of the bags is pinned for, or nil.
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

-- True for a live record of this character's bags that sits in the slot pinned for its item: B.Categories.Of files it in Keep in place.
function Pins.Of(record)
	if type(record) ~= "table" or record.live ~= true or not Whole(record.id) then
		return false
	end
	if record.key ~= nil and record.key ~= ns.CharacterKey() then
		return false
	end
	return Pins.Get(record.bag, record.slot) == record.id
end

-- Names ----------------------------------------------------------------------------------------------------------------------------------------

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

-- Pinning and unpinning ------------------------------------------------------------------------------------------------------------------------

local function CountOf(id)
	local count = Ask(Item("GetItemCount"), id)
	return Whole(count) and count or 0
end

-- The count in the bags of each pinned item.
local function Counts()
	local fresh = {}
	for _, pin in ipairs(List()) do
		if fresh[pin.id] == nil then
			fresh[pin.id] = CountOf(pin.id)
		end
	end
	return fresh
end

-- The pins changed: the window draws its marks and lays its sections out again, and the counts are taken with no run.
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
	-- Off the sell list, and a grey item on the keep list, so Sell junk never sells a pinned item.
	if type(ns.ErrandsJunkMark) == "function" then
		pcall(ns.ErrandsJunkMark, id, false)
	end
	Say(SAY.pinned:format(Named(id), BagLabel(bag), slot))
	Changed()
	return true
end

-- Unpins a slot; quiet: no line in chat. True when it was pinned.
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

-- Pins a slot that holds an item, or unpins a pinned slot.
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

-- The post-hook of a live slot's OnClick: Ctrl+right-click with nothing else held and an empty cursor.
local function Clicked(button, mouse)
	if mouse ~= "RightButton" or not Down("IsControlKeyDown") or Down("IsShiftKeyDown") or Down("IsAltKeyDown") then
		return
	end
	local spot = spots[button]
	if not spot or Cursor() ~= nil or not On() then
		return
	end
	Pins.Toggle(spot.bag, spot.slot)
end

local function Click(button, mouse)
	if mouse == "RightButton" then
		Part(Clicked, button, mouse)
	end
end

-- BagsItems.lua made the live button of a slot: one post-hook of its OnClick, once.
function Pins.Hook(button, bag, slot)
	if spots[button] or not InBags(bag) or not Whole(slot) or type(button) ~= "table" or type(button.HookScript) ~= "function" then
		return
	end
	spots[button] = { bag = bag, slot = slot }
	button:HookScript("OnClick", Click)
end

-- An item let go or clicked on the title of Keep in place (BagsLayout.lua, out of combat): the slot it came from is pinned. The layout gives the
-- item back. True when a pin was made.
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

-- An item let go on another section's title (BagsLayout.lua): the pinned slot it came from is unpinned.
function Pins.Left()
	local id, bag, slot = Held()
	if id and InBags(bag) and Pins.Get(bag, slot) == id then
		Unpin(bag, slot, false)
	end
end

-- The mark -------------------------------------------------------------------------------------------------------------------------------------

local function Accent()
	local ok, r, g, b = pcall(ns.Colour, "windows.accent")
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

-- The textures of the mark on a button, made the first time it is pinned.
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

-- Draws the mark of a button of B.Buttons.Draw: kind "live" and its bag and slot, and the record it shows (nil for an empty slot).
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

-- The mover ------------------------------------------------------------------------------------------------------------------------------------

local Start

-- The bags as they are now: per bag its size, its family and its slots, each { id, count, locked } or false when empty.
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
		bags[bag] = { size = size, family = family, slots = slots }
	end
	return bags
end

-- Whether a bag takes any item: family 0 and not the reagent bag.
local function TakesAny(bag, family)
	return bag ~= REAGENT_BAG and family == 0
end

-- Whether an item may go in a bag: any item in a normal bag; in a special bag one whose family matches, never a container; never the reagent bag,
-- whose rule the client does not give.
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

-- A free slot of a normal bag that no pin holds and this step does not use, or nil.
local function FreeSlot(bags, pinned, used)
	for bag = FIRST_BAG, LAST_BAG do
		local b = bags[bag]
		if TakesAny(bag, b.family) then
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

-- The source for a pin: the largest unlocked stack of its item that is not a met pin and not used in this step; and whether one is locked.
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

-- The moves of one step: { { from, to, id, key (the pin) }, ... }, and whether something waits (a locked slot, or a swap after a move out of
-- the way).
local function Plan(r)
	local bags = Read()
	local pins = List()
	local pinned, met, used = {}, {}, {}
	for _, pin in ipairs(pins) do
		pinned[pin.key] = pin.id
		local b = bags[pin.bag]
		local entry = b and pin.slot <= b.size and b.slots[pin.slot]
		if entry and entry.id == pin.id then
			met[pin.key] = true
		end
	end
	local moves, waits = {}, false
	for _, pin in ipairs(pins) do
		local b = bags[pin.bag]
		if #moves >= PER_STEP then
			waits = true
			break
		end
		if not met[pin.key] and not r.skip[pin.key] and not used[pin.key] and b and pin.slot <= b.size then
			local target = b.slots[pin.slot]
			local source, locked = Source(bags, pin.id, met, used)
			if not source then
				waits = waits or locked
			elseif target and target.locked then
				waits = true
			elseif pin.bag ~= REAGENT_BAG and not Fits(pin.id, pin.bag, b.family) then
				r.skip[pin.key] = true
			elseif not target or Fits(target.id, source.bag, bags[source.bag].family) then
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

-- One move: pick up, check, put down. False when the step should stop.
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
	return true
end

-- Why a step waits, or nil: the cursor, a spell waiting for its target, Sell junk, Deposit or Take out, a trade, or a sort hold not its own.
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
	local trade = _G.TradeFrame
	if type(trade) == "table" and not ns.Forbidden(trade) then
		local okShown, shown = pcall(trade.IsShown, trade)
		if okShown and (ns.IsSecret(shown) or shown == true) then
			return "trade"
		end
	end
	if not r.own and type(B.Sorting) == "function" and B.Sorting("bags") then
		return "sorting"
	end
	return nil
end

-- A run that waits for the end of the fight, once; asked: the player asked for it, whatever Put pinned items back says.
local function AfterFight(asked)
	fightAsked = fightAsked or asked == true
	if afterFight then
		return
	end
	afterFight = true
	local function Again()
		afterFight = false
		local wanted = fightAsked
		fightAsked = false
		if wanted or MovesOn() then
			Part(Start, false, nil, false, wanted)
		end
	end
	local ok, lockdown = pcall(InCombatLockdown)
	if ok and lockdown == true and type(ns.OutOfCombat) == "function" then
		ns.OutOfCombat(Again)
	elseif not After(STEP_WAIT, Again) then
		afterFight = false
	end
end

local Step

-- Ends the run: the sort hold it extended ends, and a run that moved something is followed by one that looks again.
local function Finish()
	local r = run
	run = nil
	if not r then
		return
	end
	if type(r.done) == "function" then
		pcall(r.done)
	end
	if r.moved > 0 and not r.check then
		After(CHECK_AFTER, function()
			if not run and (r.asked or MovesOn()) then
				Part(Start, false, nil, true, r.asked)
			end
		end)
	end
end

-- The next step in seconds, unless a scan comes first (Pins.Scanned).
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
		return AfterFight(r.asked)
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

-- Starts a run. own: the sort hold's own extension; done: called when it ends; check: the run that looks again; asked: the player asked. A run
-- under way takes over own and done. True when a run goes on (done is called then, maybe at once); false when there is nothing to put back.
function Start(own, done, check, asked)
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
		run.own = run.own or own
		run.asked = run.asked or asked
		return true
	end
	local pins = List()
	if #pins == 0 or not On() then
		return false
	end
	run = { started = Now(), moves = 0, moved = 0, most = 2 * #pins + 4, fails = {}, skip = {}, done = done, own = own, check = check,
		asked = asked }
	Step()
	return true
end

-- Bags.lua: the sort hold of the bags is due to end after a clean up. True when the hold waits for done.
function Pins.AfterSort(done)
	if not MovesOn() or #List() == 0 or not On() then
		return false
	end
	if Fighting() then
		AfterFight(false)
		return false
	end
	-- B.Part gives no answer back, so the answer of Start is kept here.
	local going = false
	Part(function()
		going = Start(true, done, false, false) == true
	end)
	return going
end

-- BagsData.lua scanned the bags at BAG_UPDATE_DELAYED: a waiting step goes on, and a pinned item whose count rose while its pin waits starts a
-- run. The first scan of a session, and scans during a sort hold, only take the counts.
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
	if not before or run or soon or not MovesOn() or (type(B.Sorting) == "function" and B.Sorting("bags")) then
		return
	end
	for _, pin in ipairs(List()) do
		local was = before[pin.id]
		if was and (counts[pin.id] or 0) > was and Ask(Container("GetContainerItemID"), pin.bag, pin.slot) ~= pin.id then
			soon = true
			if not After(ARRIVAL, function()
				soon = false
				if Fighting() then
					AfterFight(false)
				else
					Part(Start, false, nil, false, false)
				end
			end) then
				soon = false
			end
			return
		end
	end
end

function Pins.Scanned()
	Part(Scanned)
end

-- Menu of Keep in place's title, and the row Pinned slots -------------------------------------------------------------------------------------

-- Put pinned items back now, whatever Put pinned items back says.
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

-- { { "bag:slot", "Backpack, slot 3: Hearthstone" }, ... }, with Unpin all first while there are two or more.
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
