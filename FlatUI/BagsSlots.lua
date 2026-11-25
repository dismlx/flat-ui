local _, ns = ...

-- Bags: the row of bag slots over the bag window's footer (B.Slots, in the strip of Flat UI's own that BagsWindow.lua gives it), so a bag can be put
-- in or swapped while the game's bag bar is hidden (Hidden frames, Bag bar) or faded away. Bags.lua makes ns.Bags with B.Slots; this file only adds
-- its fields and makes frames, textures and animations of its own only. BagsData.lua lays the bag window out again at BAG_CONTAINER_UPDATE, and
-- every pass of the window asks for the row again (Row), which draws it from the game as it is then. The three events this file adds to the module
-- (ns.AddEvent, beside the other parts' handlers of the same events) are the ones the game's bag buttons hear (PaperDollFrame.lua:2002-2013,
-- 2068-2080; MainMenuBarBagButtons.lua:16, 44-49), and do something only while the row shows (IsVisible): CURSOR_CHANGED keeps the hover tint of
-- each slot whose inventory slot the cursor's item can go in lit (LockHighlight, from C_PaperDollInfo.CursorCanGoInSlot; never the backpack; the
-- keyring while the item is a key, Enum.ItemClass.Key), and with nothing on the cursor each empty bag slot a spare bag in the bags fits (below),
-- ITEM_LOCK_CHANGED with no slot (an inventory slot locked or freed) draws that bag's slot again, greyed (SetDesaturated, IsInventoryItemLocked)
-- while its bag is lifted, and ITEM_PUSH (bagSlot, iconFileID: the backpack's is 0) plays the item's icon on that bag's slot, from FLY_SCALE times
-- its size down into it while it fades, FLY_SECONDS long, on a texture and an animation group of the slot's own, so loot is seen going in.
--
-- The row shows while the bag window shows the player's own live bags and the row Bag slots on the Bags page is on: the backpack, the four bags and
-- the reagent bag (Enum.BagIndex 0 to 5), and a gap after them the keyring while the game shows one (C_ActionBar.ShouldShowKeyring, the test of
-- Bags.lua and BagsData.lua; KEYRING_CONTAINER, -1), each a button of Flat UI's own in the shape of BagsBank.lua's bank bag slots (SLOT units,
-- GAP apart, an outline in the Button and slot colour of the Windows page, the white tint under the cursor and the icon cropped by Icon crop).
-- A bag slot's inventory slot is C_Container.ContainerIDToInventoryID(bag), its icon GetInventoryItemTexture("player", slot) or, for an empty
-- slot, the art the game gives that slot (GetInventorySlotInfo, its second answer), and a bag whose inventory slot the client does not give (no
-- reagent bag) has no button. The backpack and the keyring are fixed: their icons are the game's own of its bag bar
-- (Camelot/MainMenuBarBagButtons.xml, bagIcon), and they take no drag. The backpack and every bag in a slot show their free slots
-- (C_Container.GetContainerNumFreeSlots) in the bottom right corner, in the game's font of item counts with an outline, white, gold at LOW (4) or
-- fewer and red once the bag is full, the colours of the footer's free slots (BagsWindow.lua); an empty slot shows none, and the keyring how many
-- keys it holds, in white.
-- BagsWindow.lua puts the row a little apart from the content under a thin line, so it does not read as more slots of the keyring or a bag.
-- Every answer goes through ns.IsSecret or ns.Finite.
--
-- The clicks are the game's own bag buttons' (Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua:68-95), out of combat only: a drop,
-- or a click with an item on the cursor (CursorHasItem), puts it in the slot with PutItemInBag(slot), and on the backpack with PutItemInBackpack; a
-- drag picks the bag up with PickupBagFromSlot(slot), as the game's bag button does (:88-90). On the keyring a drop or a click with an item puts it
-- in the first empty keyring slot (C_Container.PickupContainerItem, as the game's keyring button, Camelot/MainMenuBarBagButtons.lua:47-62, 177-200;
-- the game refuses anything that is not a key), a full keyring says so in one line, and a drag does nothing. A plain click on an empty bag slot
-- puts in a spare bag from the bags: the largest bag (INVTYPE_BAG, Enum.ItemClass.Container) in the backpack and bags, its size read once per
-- item from its tooltip (C_TooltipInfo.GetBagItem against the game's CONTAINER_SLOTS), a general bag first of two the same size, and for the
-- reagent bag slot a reagent bag (Enum.ItemContainerSubclass.Reagent) alone, the only kind it takes; it goes on the cursor
-- (C_Container.PickupContainerItem) and into the slot with PutItemInBag when C_PaperDollInfo.CursorCanGoInSlot says it can, else back to its place
-- (ClearCursor). The spares are looked for once a pass of the row, only while a slot is empty, and again at a click or a tooltip. None of them is
-- protected. In a fight they say so in one line and do nothing. A plain click on a slot that holds a bag (the keyring too) with nothing on the
-- cursor, where the game's button opens that bag, keeps that bag lit in the window
-- (B.Layout.Stick, BagsLayout.lua): every other slot dimmed as under the mouse, the search still applied, and the slot's edge in the Highlight
-- colour of the Windows page (SetOutlineColour); a click on it again, on another slot, or the window closing gives everything back. That touches
-- frames of Flat UI's own only, so it works in a fight too. A bag dragged out of its slot, or swapped for a bag dropped on it, lets that go,
-- so the next bag in that slot shows like any other. A right click with nothing on the cursor opens that bag's settings (B.Layout.BagMenuOf:
-- Assign To, Ignore Clean Up and Ignore Junk Selling, as on a label of Bag by bag), in either view and in a fight too, since those flags are not
-- protected; the keyring has none, as in the game. The tooltip is the game's of the bag (GameTooltip:SetInventoryItem) out of combat, plain lines
-- in a fight or for an empty slot (with the spare bag a click puts in, "Linen Bag (6 slots)"), a line of the bag's free and total slots
-- (C_Container.GetContainerNumFreeSlots and GetContainerNumSlots), what its settings say (B.Layout.BagFlags: what it is assigned to, and whether
-- clean up or junk selling leaves it alone) and what the clicks do; the keyring's says Keyring (KEYRING), how many keys, each key it holds with its
-- icon and link, by name (at most KEY_LINES, then how many more; "No keys yet." when it holds none), and what the clicks do. It
-- opens beside the bag window (B.Window.Get, a frame of Flat UI's own; SetOwner with ANCHOR_NONE, ClearAllPoints and SetPoint), left of it while
-- the window's middle is right of the screen's and right of it otherwise, its bottom at the window's, so it never covers the items the slot lights;
-- it is hidden when the cursor leaves the button that owns it (IsOwned). The mouse over a slot that holds a bag (the keyring too) lights that
-- bag's items in the window (B.Layout.Light, BagsLayout.lua), as the game's bag bar does with Bags (Bags.lua), and leaving it gives the window
-- back; an empty slot lights nothing.

local B = ns.Bags
if type(B) ~= "table" or type(B.Slots) ~= "table" then
	return
end
local Slots = B.Slots
local E = ns.Errands

local KEY, PART = "bags", "slots"
-- The bags of the row: the backpack, the four bags and the reagent bag (Enum.BagIndex), then the keyring while the game shows one
-- (Enum.BagIndex.Keyring, KEYRING_CONTAINER, -1 when the client does not say), a gap apart.
local FIRST, LAST = 0, 5
local KEYRING = ns.Finite(KEYRING_CONTAINER) and KEYRING_CONTAINER or -1
-- The size of a slot and the space between two, as the bank's bag slots (BagsBank.lua).
local SLOT, GAP = 28, 4
-- The game's icons of the backpack and the keyring on its bag bar, and the art of an empty bag slot when the client does not say.
local BACKPACK_ICON = "Interface\\Icons\\ui-hud-actionbar-bag"
local KEYRING_ICON = "Interface\\Icons\\ui-hud-actionbar-keyring"
local EMPTY_ART = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
-- The inventory slot names of the bags, for the art of an empty one (GetInventorySlotInfo).
local SLOT_NAMES = { [1] = "Bag0Slot", [2] = "Bag1Slot", [3] = "Bag2Slot", [4] = "Bag3Slot", [5] = "ReagentBag0Slot" }
-- The tint under the cursor, as on the slots of the windows (Windows.lua:59), and the colour of the plain lines of a tooltip.
local HOVER = { 1, 1, 1, 0.3 }
local DIM = { 0.8, 0.8, 0.8 }
-- The free count in a slot's corner: the game's font of item counts at a size of its own with an outline, white, gold at LOW free slots or fewer
-- and the red of a full bag's label in Bag by bag (BagsLayout.lua, FULL_HEX) when the bag has no room, the colours of the footer's free slots
-- (BagsWindow.lua, LOW_HEX and NONE_HEX).
local COUNT_FONT, COUNT_SIZE = "NumberFontNormal", 11
local ROOM, SHORT, FULL, LOW = { 1, 1, 1 }, { 1, 0.82, 0 }, { 1, 0.35, 0.24 }, 4
-- Item classes and the container subclass of the reagent bag (Enum.ItemClass, Enum.ItemContainerSubclass), the equip slot of a bag, and the game's
-- words of a bag's size in its tooltip ("6 Slot Bag", CONTAINER_SLOTS).
local CONTAINER, KEY_CLASS, REAGENT_SUB = 1, 13, 11
local BAG_EQUIP = "INVTYPE_BAG"
local SIZE_WORDS = "%d Slot %s"
-- The tooltip opens this far beside the window.
local TIP_GAP = 4
-- The crop of an icon when the Windows page does not say.
local CROP = 8
-- Loot going in (ITEM_PUSH): the size its icon starts at, as times the slot's, and how long it takes to shrink into the slot, fading after FLY_FADE.
local FLY_SCALE, FLY_SECONDS, FLY_FADE = 1.8, 0.45, 0.15
local FIGHT_LINE = "Flat UI: the bag slots of the bag window take no clicks in a fight."
-- The most keys the keyring's tooltip lists, and the size of their icons there (as a folded section's, BagsLayout.lua).
local KEY_LINES, KEY_ICON = 12, 14
local NO_ROOM_LINE = "Flat UI: your keyring is full."

-- The row, made by Slots.Row: { frame, parent, slots = { [bag] = slot }, spares = { bag, reagent } (Spares, worked out once a pass) }.
local row
-- The size of a bag by its item ID, read once from its tooltip; 0 when the tooltip never says.
local sizes = {}

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- Runs fn as the slots part of Bags (B.Part, Bags.lua): a failure stops this part alone.
local function Run(fn, ...)
	local part = B.Part
	if type(part) ~= "function" then
		return false
	end
	return part(PART, fn, ...)
end

-- A function of C_Container, or nil when the client has none.
local function Container(name)
	local api = C_Container
	if not Usable(api) then
		return nil
	end
	local fn = api[name]
	return type(fn) == "function" and fn or nil
end

-- A word of the game's global strings, or the English one when the client has none.
local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

-- A texture the client gave: a file ID or a path, else nil.
local function Texture(value)
	if ns.Finite(value) or (type(value) == "string" and not ns.IsSecret(value) and value ~= "") then
		return value
	end
	return nil
end

-- The inventory slot of a bag, or nil for the backpack and for a bag the client gives none.
local function InventorySlot(bag)
	if bag == 0 or bag == KEYRING then
		return nil
	end
	local slot = E.Ask(Container("ContainerIDToInventoryID"), bag)
	if ns.Finite(slot) and slot > 0 then
		return slot
	end
	return nil
end

-- The icon of the bag in a slot, or nil for an empty one.
local function BagIcon(bag)
	if bag == 0 then
		return BACKPACK_ICON
	elseif bag == KEYRING then
		return KEYRING_ICON
	end
	local slot = InventorySlot(bag)
	return slot and Texture(E.Ask(GetInventoryItemTexture, "player", slot)) or nil
end

-- The art the game gives an empty bag slot.
local function EmptyArt(bag)
	local name = SLOT_NAMES[bag]
	if name and type(GetInventorySlotInfo) == "function" then
		local ok, _, art = pcall(GetInventorySlotInfo, name)
		if ok and Texture(art) then
			return art
		end
	end
	return EMPTY_ART
end

-- The free and total slots of a bag of mine, or nil when the client does not say.
local function Room(bag)
	local free = E.Ask(Container("GetContainerNumFreeSlots"), bag)
	local total = E.Ask(Container("GetContainerNumSlots"), bag)
	if ns.Finite(free) and ns.Finite(total) and total > 0 then
		return math.max(0, math.floor(free)), math.floor(total)
	end
	return nil, nil
end

-- The keys on the keyring, its slots and its first empty slot, or nil when the client does not say. A slot the client does not answer for is never
-- taken as empty, so a key is never put on one that may hold a key already. With list, each key also goes in it as { link, icon, name }: its
-- hyperlink and icon as the client gives them (plain values only), for the keyring's tooltip.
local function Keys(list)
	local total = E.Ask(Container("GetContainerNumSlots"), KEYRING)
	local info = Container("GetContainerItemInfo")
	if not (info and ns.Finite(total) and total > 0) then
		return nil, nil, nil
	end
	local keys, empty = 0, nil
	for index = 1, math.floor(total) do
		local ok, item = pcall(info, KEYRING, index)
		if ok and not ns.IsSecret(item) and item == nil then
			empty = empty or index
		elseif ok and Usable(item) then
			keys = keys + 1
			local link = item.hyperlink
			if list and type(link) == "string" and not ns.IsSecret(link) and link:find("|H", 1, true) then
				list[#list + 1] = { link = link, icon = Texture(item.iconFileID), name = link:match("|h%[(.-)%]|h") or link }
			end
		end
	end
	return keys, math.floor(total), empty
end

-- The equip slot, class and subclass of an item (C_Item.GetItemInfoInstant), or nil.
local function Instant(id)
	local api = C_Item
	local fn = Usable(api) and api.GetItemInfoInstant or GetItemInfoInstant
	if type(fn) ~= "function" or not ns.Finite(id) then
		return nil
	end
	local ok, _, _, _, equip, _, class, sub = pcall(fn, id)
	if ok and type(equip) == "string" and not ns.IsSecret(equip) and ns.Finite(class) and ns.Finite(sub) then
		return equip, class, sub
	end
	return nil
end

-- The game's words of a bag's size ("6 Slot Bag", CONTAINER_SLOTS) as a pattern that gives the number, made the first time.
local sizePattern
local function SizePattern()
	if not sizePattern then
		local words = Word("CONTAINER_SLOTS", SIZE_WORDS)
		local text = words:gsub("%%%d*%$?d", "\1"):gsub("%%%d*%$?s", "\2")
		text = text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		sizePattern = "^" .. text:gsub("\1", "(%%d+)"):gsub("\2", ".+")
	end
	return sizePattern
end

-- The slots of a bag in the bags, read once per item ID from its tooltip (C_TooltipInfo.GetBagItem), 0 when it does not say. A tooltip that has
-- not loaded yet (one line) is read again next time.
local function BagSize(bag, slot, id)
	local known = sizes[id]
	if known then
		return known
	end
	local api = C_TooltipInfo
	local get = Usable(api) and api.GetBagItem or nil
	if type(get) ~= "function" then
		return 0
	end
	local ok, data = pcall(get, bag, slot)
	if not (ok and Usable(data) and Usable(data.lines)) then
		return 0
	end
	local pattern, size = SizePattern(), 0
	for _, line in ipairs(data.lines) do
		local text = Usable(line) and line.leftText or nil
		if type(text) == "string" and not ns.IsSecret(text) then
			local n = tonumber(text:match(pattern) or "")
			if n and n > 0 then
				size = math.floor(n)
				break
			end
		end
	end
	if size > 0 or #data.lines >= 2 then
		sizes[id] = size
	end
	return size
end

-- The largest spare bag in the backpack and bags, for a bag slot and for the reagent bag slot apart (the reagent bag slot takes reagent bags alone,
-- and a bag slot none): { bag, slot, size, id, link }, or nil. Of two the same size, a general bag (subclass 0) goes first. A locked item is skipped.
local function Spares()
	local count, info = Container("GetContainerNumSlots"), Container("GetContainerItemInfo")
	if not (count and info) then
		return nil, nil
	end
	local best = {}
	for bag = FIRST, LAST do
		local slots = E.Ask(count, bag)
		for slot = 1, ns.Finite(slots) and math.floor(slots) or 0 do
			local ok, item = pcall(info, bag, slot)
			local locked = ok and Usable(item) and item.isLocked
			local id = ok and Usable(item) and not ns.IsSecret(locked) and locked ~= true and item.itemID or nil
			local equip, class, sub = Instant(ns.Finite(id) and id or nil)
			if equip == BAG_EQUIP and class == CONTAINER then
				local reagent = sub == REAGENT_SUB
				local size, top = BagSize(bag, slot, id), best[reagent]
				if not top or size > top.size or (size == top.size and sub == 0 and top.sub ~= 0) then
					local link = item.hyperlink
					best[reagent] = { bag = bag, slot = slot, size = size, sub = sub, id = id,
						link = type(link) == "string" and not ns.IsSecret(link) and link or nil }
				end
			end
		end
	end
	return best[false], best[true]
end

-- A spare bag's name and size for its line: "Linen Bag (6 slots)".
local function SpareLabel(spare)
	local name = spare.link and spare.link:match("|h%[(.-)%]|h") or nil
	if not name then
		local api = C_Item
		name = Usable(api) and E.Ask(api.GetItemNameByID, spare.id) or nil
	end
	name = type(name) == "string" and name ~= "" and name or "a bag"
	if spare.size > 0 then
		return ("%s (%d slots)"):format(name, spare.size)
	end
	return name
end

-- The crop of the icons, from the Windows page (B.Look, Bags.lua), as a share of each edge.
local function Crop()
	local look = B.Look
	local crop = type(look) == "function" and look("crop") or nil
	crop = ns.Finite(crop) and crop or CROP
	return math.max(0, math.min(crop, 15)) / 100
end

local function Paint(box)
	if box then
		local r, g, b = ns.Colour("windows.panel")
		ns.SetOutlineFill(box, r, g, b, 1)
	end
end

local function TipGone(owner)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not ns.IsSecret(owned) and owned == true then
		tip:Hide()
	end
end

-- A function of the layout (B.Layout, BagsLayout.lua), or nil.
local function LayoutFn(name)
	local layout = B.Layout
	local fn = Usable(layout) and layout[name] or nil
	return type(fn) == "function" and fn or nil
end

-- The bag window lights the bag under the cursor, or gives itself back with nil.
local function Light(bag)
	local light = LayoutFn("Light")
	if light then
		B.Part("layout", light, "bags", bag)
	end
end

-- The bag a click keeps lit in the bag window, or nil.
local function Stuck()
	local stuck = LayoutFn("Stuck")
	if not stuck then
		return nil
	end
	local ok, bag = pcall(stuck, "bags")
	return ok and ns.Finite(bag) and bag or nil
end

-- True when the slot of bag holds a bag: the backpack and the keyring always.
local function Holds(bag)
	return bag == 0 or BagIcon(bag) ~= nil
end

-- The spare bag a click on an empty bag slot puts in: the reagent bag slot's own kind, else the largest bag; nil for a slot that holds a bag, the
-- backpack and the keyring. fresh: looked for now (a click, a tooltip), else as the row's last pass found them.
local function SpareFor(bag, fresh)
	if bag == 0 or bag == KEYRING or not row or not InventorySlot(bag) or Holds(bag) then
		return nil
	end
	local general, reagent
	if fresh then
		general, reagent = Spares()
	else
		general, reagent = row.general, row.reagent
	end
	if bag == LAST then
		return reagent
	end
	return general
end

-- An empty bag slot clicked with nothing on the cursor, out of combat: the spare bag goes on the cursor (C_Container.PickupContainerItem) and into
-- the slot with PutItemInBag when the game says it can go there (C_PaperDollInfo.CursorCanGoInSlot), else back to where it was (ClearCursor).
local function Fill(bag)
	local spare = SpareFor(bag, true)
	local inventory = InventorySlot(bag)
	if not (spare and inventory) then
		return
	end
	if E.Fighting() then
		print(FIGHT_LINE)
		return
	end
	if not E.Call(Container("PickupContainerItem"), spare.bag, spare.slot) or E.Ask(CursorHasItem) ~= true then
		return
	end
	local api = C_PaperDollInfo
	if E.Ask(Usable(api) and api.CursorCanGoInSlot or nil, inventory) == true then
		E.Call(PutItemInBag, inventory)
	else
		E.Call(ClearCursor)
	end
end

-- A key on the cursor goes into the first empty slot of the keyring (C_Container.PickupContainerItem), as the game's keyring button does
-- (Camelot/MainMenuBarBagButtons.lua:47-62); the game refuses anything that is not a key. A full keyring says so in one line.
local function PutKey()
	local _, _, empty = Keys()
	if empty then
		E.Call(Container("PickupContainerItem"), KEYRING, empty)
	else
		print(NO_ROOM_LINE)
	end
end

-- The centre of a frame across the screen, in screen units, or nil.
local function Middle(frame)
	local ok, left, right, scale = pcall(function()
		return frame:GetLeft(), frame:GetRight(), frame:GetEffectiveScale()
	end)
	if ok and ns.Finite(left) and ns.Finite(right) and ns.Finite(scale) and scale > 0 then
		return (left + right) / 2 * scale
	end
	return nil
end

-- The tooltip of a slot opens beside the bag window (B.Window.Get), on the side of the screen with room: left of a window right of the screen's
-- middle, else right of it, its bottom at the window's, so the window and the bag the slot lights stay in view. Above the slot when the window
-- does not say where it is.
local function Anchor(tip, button)
	local window
	local get = Usable(B.Window) and B.Window.Get or nil
	if type(get) == "function" then
		local ok, frame = pcall(get, "bags")
		window = ok and Usable(frame) and frame or nil
	end
	local at, screen = window and Middle(window), Middle(UIParent)
	if not (at and screen) then
		tip:SetOwner(button, "ANCHOR_TOP")
		return
	end
	tip:SetOwner(button, "ANCHOR_NONE")
	tip:ClearAllPoints()
	if at > screen then
		tip:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", -TIP_GAP, 0)
	else
		tip:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", TIP_GAP, 0)
	end
end

-- The edge of a slot: in the Highlight colour while a click keeps its bag lit, else the outline's own.
local function Edge(slot, bag)
	if Stuck() == bag and Holds(bag) then
		local r, g, b = ns.Colour("windows.accent")
		ns.SetOutlineColour(slot.box, r, g, b)
	else
		ns.SetOutlineColour(slot.box, nil, nil, nil)
	end
end

-- A plain click on a slot that holds a bag keeps that bag lit in the window, or, on the one lit already, gives every bag back.
local function Stick(bag)
	local stick = LayoutFn("Stick")
	if not stick or not Holds(bag) then
		return
	end
	B.Part("layout", stick, "bags", Stuck() ~= bag and bag or nil)
	for other, slot in pairs(row and row.slots or {}) do
		Edge(slot, other)
	end
end

-- A click, a drag or a drop (how) on the slot of bag. A click with nothing on the cursor keeps that bag lit, in a fight too, and on an empty slot
-- puts the spare bag in (Fill); else, out of combat only, an item on the cursor goes in on a click or a drop (a key on the keyring), and a drag
-- lifts the bag onto the cursor.
local function Use(bag, how)
	local holding = E.Ask(CursorHasItem) == true
	if not holding and how ~= "drag" then
		if how == "click" and Holds(bag) then
			Stick(bag)
		elseif how == "click" then
			Fill(bag)
		end
		return
	end
	-- The keyring takes a key and gives nothing to drag.
	if bag == KEYRING and not (holding and how ~= "drag") then
		return
	end
	if E.Fighting() then
		print(FIGHT_LINE)
		return
	end
	if bag == KEYRING then
		PutKey()
		return
	end
	if bag == 0 then
		if holding and how ~= "drag" then
			E.Call(PutItemInBackpack)
		end
		return
	end
	local slot = InventorySlot(bag)
	if not slot then
		return
	end
	if holding and how ~= "drag" then
		-- A bag on the cursor takes the place of the one a click keeps lit, which lets that go, so the new bag shows like any other.
		local kind, id = E.Ask(GetCursorInfo)
		if kind == "item" and Instant(id) == BAG_EQUIP and Stuck() == bag then
			Stick(bag)
		end
		E.Call(PutItemInBag, slot)
	elseif not holding and how == "drag" then
		-- The bag a click keeps lit lets that go as it is lifted out, its edge at once.
		if Stuck() == bag then
			Stick(bag)
		end
		E.Call(PickupBagFromSlot, slot)
	end
end

-- A click on a slot: the right button with nothing on the cursor opens the bag's settings under it (B.Layout.BagMenuOf; nothing on the keyring), any
-- other the click above.
local function Click(button, bag, mouse)
	if mouse == "RightButton" and E.Ask(CursorHasItem) ~= true then
		-- The keyring has no settings, as in the game (BagsLayout.lua, Layout.BagMenuOf).
		local menu = bag ~= KEYRING and LayoutFn("BagMenuOf") or nil
		if menu then
			B.Part("layout", menu, "bags", bag, button)
		end
		return
	end
	Use(bag, "click")
end

-- The settings of a held bag in its tooltip, from the bag menu's flags (B.Layout.BagFlags).
local function FlagLines(tip, bag)
	local flags = LayoutFn("BagFlags")
	if not flags then
		return
	end
	local ok, sortOff, junkOff, assigned = pcall(flags, bag)
	if not ok then
		return
	end
	if type(assigned) == "string" and assigned ~= "" then
		tip:AddLine(("Assigned to: %s"):format(assigned), 1, 1, 1, true)
	end
	if sortOff == true then
		tip:AddLine("Clean up leaves this bag alone.", DIM[1], DIM[2], DIM[3], true)
	end
	if junkOff == true then
		tip:AddLine("Sell junk leaves this bag alone.", DIM[1], DIM[2], DIM[3], true)
	end
end

-- The keyring's tooltip: its name, how many keys it holds, each key with its icon and its link (in its quality's colour), by name, at most
-- KEY_LINES and then how many more, as a folded section's tooltip lists its items (BagsLayout.lua, FoldedTip), or that it holds none yet; and
-- what the clicks do. Read live, as the row shows only for the player's own bags; plain lines, so in a fight too.
local function KeyTip(tip, button)
	Anchor(tip, button)
	tip:SetText(Word("KEYRING", "Keyring"), 1, 1, 1)
	local list = {}
	local keys = Keys(list)
	if keys == 0 then
		tip:AddLine("No keys yet.", DIM[1], DIM[2], DIM[3])
	elseif keys then
		tip:AddLine(keys == 1 and "1 key" or ("%d keys"):format(keys), 1, 1, 1)
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
		for index = 1, math.min(#list, KEY_LINES) do
			local key = list[index]
			local icon = key.icon and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t "):format(tostring(key.icon), KEY_ICON, KEY_ICON) or ""
			tip:AddLine(icon .. key.link, 1, 1, 1)
		end
		if #list > KEY_LINES then
			tip:AddLine(("and %d more"):format(#list - KEY_LINES), DIM[1], DIM[2], DIM[3])
		end
	end
	tip:AddLine("Drop a key here to put it on your keyring.", DIM[1], DIM[2], DIM[3], true)
	tip:AddLine(Stuck() == KEYRING and "Click again to show every bag." or "Click to show only your keyring.", DIM[1], DIM[2], DIM[3], true)
	tip:Show()
end

-- The game's tooltip of the bag out of combat, plain lines in a fight or for an empty slot (with the spare bag a click puts in); then the bag's
-- free and total slots, its settings and what the clicks do. It opens beside the window (Anchor).
local function SlotTip(button, bag)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	if bag == KEYRING then
		KeyTip(tip, button)
		return
	end
	local slot = InventorySlot(bag)
	local held = bag == 0 or BagIcon(bag) ~= nil
	Anchor(tip, button)
	local shown = false
	if held and slot and not E.Fighting() then
		local ok, has = pcall(tip.SetInventoryItem, tip, "player", slot)
		shown = ok and not ns.IsSecret(has) and has == true
		if not shown then
			-- The game hides the tooltip when it has nothing to show, so the owner is set again.
			Anchor(tip, button)
		end
	end
	if not shown then
		if bag == 0 then
			tip:SetText(Word("BAG_NAME_BACKPACK", "Backpack"))
		elseif held then
			local name = E.Ask(Container("GetBagName"), bag)
			tip:SetText(type(name) == "string" and name ~= "" and name or "Bag")
		else
			tip:SetText(bag == LAST and Word("EQUIP_CONTAINER_REAGENT", "Equip Reagent Bag") or Word("EQUIP_CONTAINER", "Equip Container"))
			local spare = SpareFor(bag, true)
			if spare then
				tip:AddLine(("Click to put in %s from your bags."):format(SpareLabel(spare)), 1, 1, 1, true)
				tip:AddLine("Or drag a bag from your bags here.", DIM[1], DIM[2], DIM[3], true)
			else
				tip:AddLine("Drag a bag from your bags here to put it in this slot.", DIM[1], DIM[2], DIM[3], true)
			end
		end
	end
	local free, total = Room(bag)
	if held and free then
		tip:AddLine(("%d of %d slots free"):format(free, total), 1, 1, 1)
	end
	if held then
		FlagLines(tip, bag)
		local click = Stuck() == bag and "Click again to show every bag" or "Click to show only this bag"
		if bag ~= 0 then
			click = click .. "; drag it to pick it up, or drop another bag on it to swap."
		else
			click = click .. "."
		end
		tip:AddLine(click, DIM[1], DIM[2], DIM[3], true)
		tip:AddLine("Right-click for this bag's settings.", DIM[1], DIM[2], DIM[3], true)
	end
	tip:Show()
end

-- The tooltip again after a click, which may have changed what it says, while this slot still owns it.
local function Retip(button, bag)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not ns.IsSecret(owned) and owned == true then
		SlotTip(button, bag)
	end
end

local function MakeSlot(bag)
	local button = CreateFrame("Button", nil, row.frame)
	ns.Own[button] = true
	button:SetSize(SLOT, SLOT)
	local slot = { button = button, box = ns.Outline(button, button) }
	slot.icon = button:CreateTexture(nil, "ARTWORK")
	ns.Own[slot.icon] = true
	slot.icon:SetAllPoints(button)
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	ns.Own[hover] = true
	hover:SetAllPoints(button)
	hover:SetColorTexture(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
	slot.count = ns.OwnText(button, "OVERLAY", COUNT_FONT)
	if slot.count then
		local ok, file = pcall(slot.count.GetFont, slot.count)
		if ok and type(file) == "string" and not ns.IsSecret(file) and file ~= "" then
			pcall(slot.count.SetFont, slot.count, file, COUNT_SIZE, "OUTLINE")
		end
		slot.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
		slot.count:SetJustifyH("RIGHT")
	end
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", function(self, mouse)
		Run(Click, self, bag, mouse)
		if mouse ~= "RightButton" then
			Run(Retip, self, bag)
		end
	end)
	button:SetScript("OnDragStart", function()
		Run(Use, bag, "drag")
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Use, bag, "drop")
	end)
	button:SetScript("OnEnter", function(self)
		Run(SlotTip, self, bag)
		-- An empty slot lights nothing, so the window does not dim whole.
		if Holds(bag) then
			Light(bag)
		end
	end)
	button:SetScript("OnLeave", function(self)
		Run(TipGone, self)
		Light(nil)
	end)
	button:SetScript("OnHide", function(self)
		Run(TipGone, self)
	end)
	row.slots[bag] = slot
	return slot
end

-- The free slots of a held bag in the slot's corner, gold at LOW or fewer and red when it is full; on the keyring how many keys it holds, in white;
-- nothing on an empty slot or when the client does not say.
local function DrawCount(slot, bag, held)
	local text = slot.count
	if not text then
		return
	end
	if bag == KEYRING then
		local keys = Keys()
		if keys then
			text:SetTextColor(ROOM[1], ROOM[2], ROOM[3], 1)
			text:SetText(tostring(keys))
			text:Show()
		else
			text:Hide()
		end
		return
	end
	local free = held and Room(bag) or nil
	if not free then
		text:Hide()
		return
	end
	local colour = free == 0 and FULL or free <= LOW and SHORT or ROOM
	text:SetTextColor(colour[1], colour[2], colour[3], 1)
	text:SetText(tostring(free))
	text:Show()
end

-- True while the game holds the bag of a slot lifted (on the cursor, or on its way to another slot); never the backpack.
local function Lifted(bag)
	local slot = InventorySlot(bag)
	return slot ~= nil and E.Ask(IsInventoryItemLocked, slot) == true
end

-- Draws a slot: the bag's icon, cropped, greyed while the bag is lifted, with its free slots in the corner, or the game's art of an empty slot,
-- faded; its edge in the Highlight colour while a click keeps its bag lit.
local function DrawSlot(slot, bag, crop)
	local icon = BagIcon(bag)
	if icon then
		slot.icon:SetTexture(icon)
		slot.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		slot.icon:SetAlpha(1)
		pcall(slot.icon.SetDesaturated, slot.icon, Lifted(bag))
	else
		slot.icon:SetTexture(EmptyArt(bag))
		slot.icon:SetTexCoord(0, 1, 0, 1)
		slot.icon:SetAlpha(0.5)
		pcall(slot.icon.SetDesaturated, slot.icon, false)
	end
	slot.icon:Show()
	DrawCount(slot, bag, icon ~= nil)
	Paint(slot.box)
	Edge(slot, bag)
end

-- True while the row shows: its frame and every parent up to the screen.
local function Showing()
	if not row then
		return false
	end
	local ok, visible = pcall(row.frame.IsVisible, row.frame)
	return ok and visible == true
end

-- True while the cursor holds a key (GetCursorInfo, Enum.ItemClass.Key).
local function KeyHeld()
	local kind, id = E.Ask(GetCursorInfo)
	if kind ~= "item" then
		return false
	end
	local _, class = Instant(id)
	return class == KEY_CLASS
end

-- Each slot whose bag slot the cursor's item can go in keeps its hover tint lit, as the game's bag buttons do (the keyring while a key is held);
-- the backpack never. With nothing on the cursor, each empty bag slot a spare bag in the bags fits stays lit (SpareFor), so it is seen.
local function Fits()
	local api = C_PaperDollInfo
	local can = Usable(api) and api.CursorCanGoInSlot or nil
	local holding = E.Ask(CursorHasItem) == true
	local key = holding and row.slots[KEYRING] ~= nil and KeyHeld()
	for bag, slot in pairs(row.slots) do
		local inventory = InventorySlot(bag)
		local lit
		if bag == KEYRING then
			lit = key
		elseif holding then
			lit = inventory ~= nil and E.Ask(can, inventory) == true
		else
			lit = SpareFor(bag) ~= nil
		end
		if lit then
			slot.button:LockHighlight()
		else
			slot.button:UnlockHighlight()
		end
	end
end

-- The icon of an item that came into a bag plays on its slot: from FLY_SCALE times the slot's size down into it while it fades. Made the first
-- time, and false when the client has no such animation.
local function Fly(slot, icon)
	if slot.fly == nil then
		local ok, fly, group = pcall(function()
			local texture = slot.button:CreateTexture(nil, "OVERLAY", nil, 7)
			ns.Own[texture] = true
			texture:SetAllPoints(slot.button)
			texture:Hide()
			local made = texture:CreateAnimationGroup()
			local scale = made:CreateAnimation("Scale")
			scale:SetScaleFrom(FLY_SCALE, FLY_SCALE)
			scale:SetScaleTo(1, 1)
			scale:SetOrigin("CENTER", 0, 0)
			scale:SetDuration(FLY_SECONDS)
			scale:SetSmoothing("IN")
			local alpha = made:CreateAnimation("Alpha")
			alpha:SetFromAlpha(1)
			alpha:SetToAlpha(0)
			alpha:SetStartDelay(FLY_FADE)
			alpha:SetDuration(FLY_SECONDS - FLY_FADE)
			made:SetScript("OnFinished", function()
				texture:Hide()
			end)
			made:SetScript("OnStop", function()
				texture:Hide()
			end)
			return texture, made
		end)
		slot.fly = ok and fly or false
		slot.flyGroup = ok and group or nil
	end
	if not slot.fly then
		return
	end
	local crop = Crop()
	slot.flyGroup:Stop()
	slot.fly:SetTexture(icon)
	slot.fly:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	slot.fly:Show()
	slot.flyGroup:Play()
end

-- Lays the row out: a slot for each bag that has an inventory slot, left to right. Returns the width and height it takes in its frame.
local function Update()
	local frame = row.frame
	local crop, x, empty = Crop(), 0, false
	for bag = FIRST, LAST do
		local slot = row.slots[bag]
		if bag == 0 or InventorySlot(bag) then
			slot = slot or MakeSlot(bag)
			slot.button:ClearAllPoints()
			slot.button:SetPoint("LEFT", frame, "LEFT", x, 0)
			DrawSlot(slot, bag, crop)
			slot.button:Show()
			x = x + SLOT + GAP
			empty = empty or not Holds(bag)
		elseif slot then
			slot.button:Hide()
		end
	end
	-- The keyring, a gap apart, while the game shows one (C_ActionBar.ShouldShowKeyring, as Bags.lua and BagsData.lua ask).
	local keyring = row.slots[KEYRING]
	if Usable(C_ActionBar) and E.Ask(C_ActionBar.ShouldShowKeyring) == true then
		keyring = keyring or MakeSlot(KEYRING)
		x = x + GAP
		keyring.button:ClearAllPoints()
		keyring.button:SetPoint("LEFT", frame, "LEFT", x, 0)
		DrawSlot(keyring, KEYRING, crop)
		keyring.button:Show()
		x = x + SLOT + GAP
	elseif keyring then
		keyring.button:Hide()
	end
	-- The spare bags an empty slot offers, looked for only while a slot is empty.
	if empty then
		row.general, row.reagent = Spares()
	else
		row.general, row.reagent = nil, nil
	end
	local width = math.max(x - GAP, 1)
	frame:SetSize(width, SLOT)
	frame:Show()
	Fits()
	return width, SLOT
end

-- The row of bag slots in a frame of Bags' own that the bag window gives (its strip over the footer), left-aligned and centred on its height, made
-- the first time and moved when another frame is given. Returns the width and height it takes there. BagsWindow.lua asks only while the window
-- shows the player's own live bags and Bag slots is on, and hides the strip otherwise.
function Slots.Row(frame)
	local width, height = 0, 0
	Run(function()
		if not Usable(frame) or ns.Forbidden(frame) then
			return
		end
		if not row then
			local holder = CreateFrame("Frame", nil, frame)
			ns.Own[holder] = true
			holder:SetSize(1, SLOT)
			row = { frame = holder, parent = frame, slots = {} }
		elseif row.parent ~= frame then
			row.frame:SetParent(frame)
			row.parent = frame
		end
		row.frame:ClearAllPoints()
		row.frame:SetPoint("LEFT", frame, "LEFT", 0, 0)
		width, height = Update()
	end)
	return width, height
end

-- Events -------------------------------------------------------------------------------------------------------------------------------------

-- The slot of a bag slot row whose inventory slot is that one (the backpack's is 0, as ITEM_PUSH gives it), with its bag.
local function SlotOf(inventory)
	for bag, slot in pairs(row.slots) do
		if (bag == 0 and inventory == 0) or (bag ~= 0 and InventorySlot(bag) == inventory) then
			return slot, bag
		end
	end
	return nil
end

ns.AddEvent(KEY, "CURSOR_CHANGED", function()
	if Showing() then
		Run(Fits)
	end
end)

-- An inventory slot locked or freed (no second argument): the bag's slot is drawn again, greyed while its bag is lifted.
ns.AddEvent(KEY, "ITEM_LOCK_CHANGED", function(inventory)
	if Showing() then
		Run(function()
			local slot, bag = SlotOf(inventory)
			if slot and slot.button:IsShown() then
				DrawSlot(slot, bag, Crop())
			end
		end)
	end
end, function(inventory, slot)
	return ns.Finite(inventory) and slot == nil
end)

-- An item came into a bag: its icon plays on that bag's slot.
ns.AddEvent(KEY, "ITEM_PUSH", function(inventory, icon)
	if Showing() then
		Run(function()
			local slot = SlotOf(inventory)
			icon = Texture(icon)
			if slot and icon and slot.button:IsShown() then
				Fly(slot, icon)
			end
		end)
	end
end, function(inventory)
	return ns.Finite(inventory)
end)
