local _, ns = ...

-- Bags: the row of bag slots over the bag window's footer (B.Slots, in the strip of Flat UI's own that BagsWindow.lua gives it), so a bag can be put
-- in or swapped while the game's bag bar is hidden (Hidden frames, Bag bar) or faded away. Bags.lua makes ns.Bags with B.Slots; this file only adds
-- its fields and makes frames, textures and animations of its own only. BagsData.lua lays the bag window out again at BAG_CONTAINER_UPDATE, and
-- every pass of the window asks for the row again (Row), which draws it from the game as it is then. The three events this file adds to the module
-- (ns.AddEvent, beside the other parts' handlers of the same events) are the ones the game's bag buttons hear (PaperDollFrame.lua:2002-2013,
-- 2068-2080; MainMenuBarBagButtons.lua:16, 44-49), and do something only while the row shows (IsVisible): CURSOR_CHANGED keeps the hover tint of
-- each slot whose inventory slot the cursor's item can go in lit (LockHighlight, from C_PaperDollInfo.CursorCanGoInSlot; never the backpack),
-- ITEM_LOCK_CHANGED with no slot (an inventory slot locked or freed) draws that bag's slot again, greyed (SetDesaturated, IsInventoryItemLocked)
-- while its bag is lifted, and ITEM_PUSH (bagSlot, iconFileID: the backpack's is 0) plays the item's icon on that bag's slot, from FLY_SCALE times
-- its size down into it while it fades, FLY_SECONDS long, on a texture and an animation group of the slot's own, so loot is seen going in.
--
-- The row shows while the bag window shows the player's own live bags and the row Bag slots on the Bags page is on: the backpack, the four bags and
-- the reagent bag (Enum.BagIndex 0 to 5), each a button of Flat UI's own in the shape of BagsBank.lua's bank bag slots (SLOT units, GAP apart, an
-- outline in the Button and slot colour of the Windows page, the white tint under the cursor and the icon cropped by Icon crop). A bag slot's
-- inventory slot is C_Container.ContainerIDToInventoryID(bag), its icon GetInventoryItemTexture("player", slot) or, for an empty slot, the art the
-- game gives that slot (GetInventorySlotInfo, its second answer), and a bag whose inventory slot the client does not give (no reagent bag) has no
-- button. The backpack is fixed: its icon is the game's own of its bag bar (Camelot/MainMenuBarBagButtons.xml, bagIcon), and it takes no drag.
-- The backpack and every bag in a slot show their free slots (C_Container.GetContainerNumFreeSlots) in the bottom right corner, in the game's
-- font of item counts with an outline, white, and red once the bag is full, as a full bag's label is in Bag by bag; an empty slot shows none.
-- BagsWindow.lua puts the row a little apart from the content under a thin line, so it does not read as more slots of the keyring or a bag.
-- Every answer goes through ns.IsSecret or ns.Finite.
--
-- The clicks are the game's own bag buttons' (Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua:68-95), out of combat only: a drop,
-- or a click with an item on the cursor (CursorHasItem), puts it in the slot with PutItemInBag(slot), and on the backpack with PutItemInBackpack; a
-- drag picks the bag up with PickupBagFromSlot(slot), as the game's bag button does (:88-90). None of them is protected. In a fight they say so in
-- one line and do nothing. A plain click with nothing on the cursor, where the game's button opens that bag, keeps that bag lit in the window
-- (B.Layout.Stick, BagsLayout.lua): every other slot dimmed as under the mouse, the search still applied, and the slot's edge in the Highlight
-- colour of the Windows page (SetOutlineColour); a click on it again, on another slot, or the window closing gives everything back. That touches
-- frames of Flat UI's own only, so it works in a fight too. A right click with nothing on the cursor opens that bag's settings (B.Layout.BagMenuOf:
-- Assign To, Ignore Clean Up and Ignore Junk Selling, as on a label of Bag by bag), in either view and in a fight too, since those flags are not
-- protected. The tooltip is the game's of the bag (GameTooltip:SetInventoryItem) out of combat, plain lines in a fight or for an empty slot, a
-- line of the bag's free and total slots (C_Container.GetContainerNumFreeSlots and GetContainerNumSlots), what its settings say (B.Layout.BagFlags:
-- what it is assigned to, and whether clean up or junk selling leaves it alone) and what the clicks do; it is hidden when the cursor leaves the
-- button that owns it (IsOwned). The mouse over a slot that holds a bag lights that bag's items in the window (B.Layout.Light, BagsLayout.lua), as
-- the game's bag bar does with Bags (Bags.lua), and leaving it gives the window back; an empty slot lights nothing.

local B = ns.Bags
if type(B) ~= "table" or type(B.Slots) ~= "table" then
	return
end
local Slots = B.Slots
local E = ns.Errands

local KEY, PART = "bags", "slots"
-- The bags of the row: the backpack, the four bags and the reagent bag (Enum.BagIndex).
local FIRST, LAST = 0, 5
-- The size of a slot and the space between two, as the bank's bag slots (BagsBank.lua).
local SLOT, GAP = 28, 4
-- The game's icon of the backpack on its bag bar, and the art of an empty bag slot when the client does not say.
local BACKPACK_ICON = "Interface\\Icons\\ui-hud-actionbar-bag"
local EMPTY_ART = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
-- The inventory slot names of the bags, for the art of an empty one (GetInventorySlotInfo).
local SLOT_NAMES = { [1] = "Bag0Slot", [2] = "Bag1Slot", [3] = "Bag2Slot", [4] = "Bag3Slot", [5] = "ReagentBag0Slot" }
-- The tint under the cursor, as on the slots of the windows (Windows.lua:59), and the colour of the plain lines of a tooltip.
local HOVER = { 1, 1, 1, 0.3 }
local DIM = { 0.8, 0.8, 0.8 }
-- The free count in a slot's corner: the game's font of item counts at a size of its own with an outline, white, and the red of a full bag's label
-- in Bag by bag (BagsLayout.lua, FULL_HEX) when the bag has no room.
local COUNT_FONT, COUNT_SIZE = "NumberFontNormal", 11
local ROOM, FULL = { 1, 1, 1 }, { 1, 0.35, 0.24 }
-- The crop of an icon when the Windows page does not say.
local CROP = 8
-- Loot going in (ITEM_PUSH): the size its icon starts at, as times the slot's, and how long it takes to shrink into the slot, fading after FLY_FADE.
local FLY_SCALE, FLY_SECONDS, FLY_FADE = 1.8, 0.45, 0.15
local FIGHT_LINE = "Flat UI: the bag slots of the bag window take no clicks in a fight."

-- The row, made by Slots.Row: { frame, parent, slots = { [bag] = slot } }.
local row

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
	if bag == 0 then
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

-- True when the slot of bag holds a bag: the backpack always.
local function Holds(bag)
	return bag == 0 or BagIcon(bag) ~= nil
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

-- A click, a drag or a drop (how) on the slot of bag. A click with nothing on the cursor keeps that bag lit, in a fight too; else, out of combat
-- only, an item on the cursor goes in on a click or a drop, and a drag lifts the bag onto the cursor.
local function Use(bag, how)
	local holding = E.Ask(CursorHasItem) == true
	if not holding and how ~= "drag" then
		if how == "click" then
			Stick(bag)
		end
		return
	end
	if E.Fighting() then
		print(FIGHT_LINE)
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
		E.Call(PutItemInBag, slot)
	elseif not holding and how == "drag" then
		E.Call(PickupBagFromSlot, slot)
	end
end

-- A click on a slot: the right button with nothing on the cursor opens the bag's settings under it (B.Layout.BagMenuOf), any other the click above.
local function Click(button, bag, mouse)
	if mouse == "RightButton" and E.Ask(CursorHasItem) ~= true then
		local menu = LayoutFn("BagMenuOf")
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

-- The game's tooltip of the bag out of combat, plain lines in a fight or for an empty slot; then the bag's free and total slots, its settings and
-- what the clicks do.
local function SlotTip(button, bag)
	local tip = GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return
	end
	local slot = InventorySlot(bag)
	local held = bag == 0 or BagIcon(bag) ~= nil
	tip:SetOwner(button, "ANCHOR_TOP")
	local shown = false
	if held and slot and not E.Fighting() then
		local ok, has = pcall(tip.SetInventoryItem, tip, "player", slot)
		shown = ok and not ns.IsSecret(has) and has == true
		if not shown then
			-- The game hides the tooltip when it has nothing to show, so the owner is set again.
			tip:SetOwner(button, "ANCHOR_TOP")
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
			tip:AddLine("Drag a bag from your bags here to put it in this slot.", DIM[1], DIM[2], DIM[3], true)
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

-- The free slots of a held bag in the slot's corner, red when it is full; nothing on an empty slot or when the client does not say.
local function DrawCount(slot, bag, held)
	local text = slot.count
	if not text then
		return
	end
	local free = held and Room(bag) or nil
	if not free then
		text:Hide()
		return
	end
	local colour = free == 0 and FULL or ROOM
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

-- Each slot whose bag slot the cursor's item can go in keeps its hover tint lit, as the game's bag buttons do; the backpack never.
local function Fits()
	local api = C_PaperDollInfo
	local can = Usable(api) and api.CursorCanGoInSlot or nil
	for bag, slot in pairs(row.slots) do
		local inventory = InventorySlot(bag)
		if inventory and E.Ask(can, inventory) == true then
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
	local crop, x = Crop(), 0
	for bag = FIRST, LAST do
		local slot = row.slots[bag]
		if bag == 0 or InventorySlot(bag) then
			slot = slot or MakeSlot(bag)
			slot.button:ClearAllPoints()
			slot.button:SetPoint("LEFT", frame, "LEFT", x, 0)
			DrawSlot(slot, bag, crop)
			slot.button:Show()
			x = x + SLOT + GAP
		elseif slot then
			slot.button:Hide()
		end
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
