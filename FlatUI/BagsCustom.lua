local _, ns = ...

-- Bags: the sections the player makes and names (B.Custom), the + slot that ends each section of the player's own bag window, and the drops on a
-- section's slots. Bags.lua makes ns.Bags with B.Custom; this file only adds its fields, makes frames, textures and font strings of its own only
-- (ns.Own, ns.OwnText), owns no event of the module, and looks up the functions of the other parts when it calls them, never at load (Bags.lua:9-14).
-- BagsCategories.lua asks Is and Name when it files and names an item, BagsLayout.lua calls Begin, Place, Done, Holding, Arrived, Closed, Took,
-- AddClick, AddTip and DropNew as it lays a window out and takes a drop, and BagsOrder.lua asks Keys for the built-in order and MenuLines for a
-- title's menu. Its work runs as the part custom of the module (B.Part, Bags.lua:378-396), which is not critical, so a fault stops it alone and the
-- windows go on without + slots and catchers.
--
-- The sections: FlatUIDB.bags.custom, { { key = "custom1", name = "Raid" }, ... } in the order they were made, for the whole account beside the
-- placements, the order and the folds (ns.Account, Core.lua:3006-3008; a new layout of BagsData's record resets only its v and chars), and
-- FlatUIDB.bags.customNext, the number of the next key. A key is "custom" and digits, so it never meets a key of Flat UI's own (B.Categories.LIST,
-- "bag" of Bag by bag, "+add" of the title that makes one), and none is used twice: the next number is above every number saved in the list, the
-- placements, the folds and the order. At most MOST sections, a name of 1 to LONGEST letters, trimmed, with no bar, unique and none of Flat UI's
-- own section names, whatever the case. A section of the player's own holds only the items placed in it by hand (FlatUIDB.bags.placed, whose shape
-- stays { [itemID] = key }): Make, Rename and Delete change the list alone, and Delete also takes the section's placements (its items go back to
-- their own sections; their sell and keep lists stay), its fold and its place in the order away. Sweep, after the module's Start (ns.AddStart),
-- takes away every placement, fold and order key of a section the list does not have, saying nothing; until then BagsCategories skips them.
-- Read keeps what it read until a write or until the saved list changes, since Is is asked for every item at each layout.
--
-- The name box: one frame of Flat UI's own on UIParent, made the first time a name is asked, in the DIALOG strata as the bag menus are
-- (BagsLayout.lua:2013), clamped to the screen (SetClampedToScreen, WL/uiobjects.yaml:4581) and taking the mouse (EnableMouse, :7170), in the bag
-- window's look (the general backdrop at Window opacity, its outline named for the Bags page, as ChatLinks.lua:581-582 names its own), a title, an
-- EditBox of Flat UI's own (SetAutoFocus, :2976; SetMaxLetters, :3050; SetFocus, :3019; HighlightText, :2877; HasFocus, :2867) with the search box's
-- look, a note and Cancel and Make (or Rename) in the look of the footer's buttons. Enter (OnEnterPressed) makes or renames, Escape (OnEscapePressed)
-- cancels, and a refusal stays in the box in red with the text selected again. It goes above the frame that asked for it, else above the middle of
-- the screen, as ChatLinks.lua:631-643 does. It is not in Movers or test mode, as the bag menus and the copy box of ChatLinks are not: it is a
-- passing question. It never opens in a fight (it would hold the keyboard), and it closes as a fight starts (PLAYER_REGEN_DISABLED,
-- WL/events.yaml:7457, registered on its own frame only while it shows), and when the window that opened it closes.
--
-- The + slot: BagsLayout decides which sections end in one (Drop slot in each section, the player's own live bag window, Sections, an open
-- section whose title takes a drop) and gives Place where; this file draws it, a Button of Flat UI's own SLOT units square under the window's
-- content frame (whose scale is Slot size, so it lines up with the item buttons), as an empty slot of BagsItems.lua is drawn (BagsItems.lua:660-711:
-- the outline filled in Button and slot colour) with a + in FREE_COLOUR of BagsItems.lua:140. It reads Free slots' count (the free slots of the
-- general bags, the layout's st.free.count): with none left it dims, and it keeps its cell, so nothing moves while the window is open
-- (BagsLayout.lua:29-31). While the cursor holds an item that it takes, it is lit in the Highlight colour of the Windows page as the titles are.
-- The catcher: a plain Frame of Flat UI's own per section whose title takes a drop, in both windows, over the rectangle of the section's cells
-- (title left out), at the content frame's own level (SetFrameLevel, :4646), under the holders of the bags, the item buttons, the titles and the +
-- slots, and taking the mouse only while the cursor holds an item, so it never takes a click, a tooltip or a drag from a real slot; a drop on a
-- real slot is still the game's swap (Mainline/ContainerFrame.lua:1515-1540). Under the cursor it lights its section's gaps.
--
-- A drop on a + slot or a catcher (OnReceiveDrag, WL/scripttypes.yaml:52, or a click with an item on the cursor): the cursor is read with
-- GetCursorInfo (WL/apis.yaml:36258) and C_Cursor.GetCursorItem (:10071), whose ItemLocation's bagID, slotIndex and equipmentSlotIndex
-- (WL/structures.yaml:12645-12656) are read inside a pcall, every value through ns.Finite. No drop is taken in a fight (InCombatLockdown,
-- :39650, and UnitAffectingCombat, :42083, through Errands.Fighting): the item goes back (ClearCursor, :34956), with one line. An item of the
-- bags (Enum.BagIndex 0 to 5 and the keyring, WL/enums.yaml:544-572), one whose place the game does not say, and every drop in the bank window
-- go to BagsLayout's Layout.Take, the drop on the title: kept in that section (B.Categories.Drop), on Junk the sell list, on Keep in place a pin,
-- and the item goes back to its slot. An item from outside the bags (a bank slot, or worn gear: equipmentSlotIndex 0 to 19, INVSLOT_AMMO to
-- INVSLOT_TABARD, Blizzard_FrameXMLBase/Constants.lua:135-155) dropped in the player's own live bag window first goes into a free slot of the
-- bags: the first empty slot (C_Container.GetContainerItemID, :8603) of the backpack or a normal bag (family 0, the second answer of
-- C_Container.GetContainerNumFreeSlots, :8693; slots C_Container.GetContainerNumSlots, :8704) that is not pinned for another item (B.Pins.Get),
-- else of a special bag 1 to 4 it fits (BagsPins.lua's test: C_Item.GetItemInfoInstant, :16569, and C_Item.GetItemFamily, :16447), never the
-- reagent bag or the keyring; C_Container.PickupContainerItem (:8767, not protected) on that empty slot puts the item there, as the game's own slot
-- click does (ContainerFrame.lua:1535), and the item is kept in the section by its ID (B.Categories.File). A bag from the bag bar (a worn slot
-- past 19) is refused, as is an item for which the bags have no room, with a line in chat (items named by C_Item.GetItemNameByID, :16685). When
-- the moved item has arrived (BagsLayout's Layout.Update asks Arrived), the window is laid out afresh, so it shows in its section and not on the
-- top shelf. A drop on the + New section title (DropNew) gives the item back and asks for a name: the item is kept in the new section by its ID
-- where it lies. A cursor that holds no item (a merchant's item is "merchant", a spell or money is not an item) takes no drop.
--
-- The bells: the section that took an item flashes in the Highlight colour and says what happened at the right of its title for a moment
-- ("Kept: Linen Cloth", "Moved in: ...", "On your sell list", "Pinned", "Made", "Renamed"), on a frame of its own over the section; a section that
-- is not laid out within FLASH_WAIT of the drop shows nothing. Refusals keep their lines in chat. The tooltips are GameTooltip (SetOwner, SetText,
-- AddLine, Show, Hide). The row Custom sections (ns.BagsCustomLines, ns.BagsCustomPick) makes, renames and deletes a section with the page on or off,
-- and /flatui status counts them (ns.AddStatus).
--
-- It never writes a field of a frame or table of the game's, hooks nothing, calls no protected function, moves nothing in a fight, and never
-- touches StaticPopupDialogs, UISpecialFrames or the panel layout of UIParent.

local KEY = "bags"
local B = ns.Bags
local Custom = B.Custom

local PART, PREFIX, MOST, LONGEST = "custom", "custom", 20, 24
-- The game's item button in the content's units (BagsLayout.lua:106), and the + on it: two bars, long and thick.
local SLOT, PLUS_LONG, PLUS_THICK = 37, 13, 2
-- How strongly a + slot or a catcher that takes the item on the cursor is lit, the same under the mouse, and a + slot under the mouse with an empty
-- cursor (white) (BagsLayout.lua:132).
local LIT, LIT_HOVER, HOVER = 0.14, 0.3, 0.12
-- The text-dim of the windows, the + of a free slot (BagsItems.lua:140) at rest and dimmed while the bags are full, and the red of a refusal
-- (BagsWindow.lua:144).
local DIM = { 0.66, 0.68, 0.62 }
local PLUS, PLUS_ALPHA, PLUS_DIM = { 0.85, 0.85, 0.85 }, 0.85, 0.3
local RED = { 1, 0.35, 0.24 }
-- How long after a drop a click on the same frame is that drop (BagsLayout.lua:134).
local DROP_CLICK = 0.3
-- The bells, in seconds: how long a drop waits for its section to be laid out, the fade of the flash, how long the words stay and fade, how long a
-- moved item is waited for; the flash's frame level over the content (below BagsOrder's drop bar at 50, BagsOrder.lua:58), its opacity at the
-- start, and the least room the words need at the right of a title.
local FLASH_WAIT, FLASH_FADE, SAY_HOLD, SAY_FADE, ARRIVE_WAIT = 1.5, 0.6, 1.5, 0.5, 5
local FLASH_LEVEL, FLASH_ALPHA, SAY_LEAST = 40, 0.3, 30
-- The + slot's level over the content: above the catcher, which lies at the content's own.
local CELL_LEVEL = 2
local FIGHT_LINE = "Flat UI: Bags: an item is put in a section out of combat only."
-- The containers of the bags (Enum.BagIndex, WL/enums.yaml:544-572): the backpack, the four bags, the reagent bag and the keyring.
local BAG_IDS = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [-1] = true }
-- The last worn slot (INVSLOT_TABARD; INVSLOT_AMMO is 0), the bags a moved item may go in (the backpack and the four bags), and Forever's item
-- classes Container and Quiver (WL/enums.yaml, Enum.ItemClass).
local LAST_WORN, FIRST_BAG, LAST_BAG = 19, 0, 4
local CONTAINER, QUIVER = 1, 11
-- The name box: its size, the height of its field and the size of its buttons.
local BOX_W, BOX_H, FIELD_H, BUTTON_W, BUTTON_H = 260, 112, 20, 64, 18
-- How many sections /flatui status names.
local STATUS_NAMES = 5
local ADD_WORD, ADDED_WORD = "New section", "Added"
local SAY = {
	most = "You have 20 sections of your own, the most Flat UI keeps. Delete one first.",
	saved = "Sections can be made once your saved settings have loaded.",
	empty = "Type a name for the section.",
	bar = "A name cannot have a | in it.",
	long = "A name has 24 letters at most.",
	builtin = "%s is one of Flat UI's own sections. Choose another name.",
	taken = "You have a section called %s already.",
	gone = "That section is not there any more.",
	fight = "sections are named out of a fight.",
	deleted = "%s is deleted.",
	deletedOne = "%s is deleted. Its item goes back to its own section.",
	deletedMany = "%s is deleted. Its %d items go back to their own sections.",
	bagBar = "Put a bag in with the Bag slots row of the bag window.",
	noRoom = "Your bags have no free slot for %s.",
	notPut = "The game did not put %s in your bags.",
	full = "You have 20 sections, the most. Delete one to make another.",
}
local NOTES = { make = "Enter makes it, Escape cancels.", rename = "Enter renames it, Escape cancels." }
local TIPS = {
	idle = "Drop an item here, or click here with one on your cursor, to keep it in %s. An item from your bank or one you wear goes into a free "
		.. "slot of your bags first.",
	idleJunk = "Drop an item here, or click here with one on your cursor, to sell it at merchants from now on.",
	idleKeep = "Drop an item of your bags here, or click here with one on your cursor, to pin the slot it came from to it.",
	full = " Your bags are full: only an item already in them can be kept here.",
	noRoom = "Your bags have no free slot for it. Make room first.",
	bagBar = "A bag goes in with the Bag slots row of the bag window.",
	keepOutside = "Only an item of your bags can be pinned.",
	move = "%s to move it into your bags and keep it in %s.",
	junk = "%s to sell it at merchants from now on.",
	keep = "%s to pin the slot it came from to it.",
	kept = "%s to keep it in %s.",
	drop = "Drop it here",
	letGo = "Let go here",
	addHolding = "Drop the item here to make a new section for it and name it.",
	add = "Click to make a section of your own and name it, then drop items on its title or its + slot. Right-click for your sections.",
	addFull = " You have 20, the most Flat UI keeps.",
}
local FLASH = { junk = "On your sell list", keep = "Pinned", moved = "Moved in: %s", kept = "Kept: %s", made = "Made", renamed = "Renamed" }

-- Small helpers -------------------------------------------------------------------------------------------------------------------------------

local function Fn(tbl, name)
	local fn = type(tbl) == "table" and tbl[name] or nil
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Call(tbl, name, ...)
	local fn = Fn(tbl, name)
	if fn then
		return fn(...)
	end
	return nil
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Now()
	local ok, now = pcall(GetTime)
	return ok and ns.Finite(now) and now or 0
end

local function Say(text)
	print("Flat UI: " .. text)
end

local function Whole(value)
	if ns.Finite(value) and value == math.floor(value) then
		return value
	end
	return nil
end

-- Text that goes into a font string or chat as it is: a bar would start a code of the client's.
local function Plain(text)
	return (tostring(text):gsub("|", "||"))
end

-- In a fight: the lockdown, or the player in combat (Errands.Fighting, Errands.lua:325-327). A fault counts as a fight.
local function Fighting()
	local errands = ns.Errands
	local fighting = type(errands) == "table" and errands.Fighting or nil
	if type(fighting) ~= "function" then
		local ok, lockdown = pcall(InCombatLockdown)
		return not ok or ns.IsSecret(lockdown) or lockdown == true
	end
	local ok, fight = pcall(fighting)
	return not ok or fight == true
end

-- Asks Bags.lua for a pass of the windows on the next frame, for both windows (B.Request).
local function Request(flag)
	Call(B, "Request", flag)
end

-- Runs fn as this part of the module (B.Part), so a part that keeps failing stops alone.
local function Part(fn, ...)
	local part = Fn(B, "Part")
	if part then
		return part(PART, fn, ...)
	end
	return pcall(fn, ...)
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

-- A number of a widget call, or nil.
local function Number(frame, method, ...)
	local fn = type(frame) == "table" and frame[method] or nil
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, frame, ...)
	if ok and ns.Finite(value) then
		return value
	end
	return nil
end

-- Red, green and blue of a colour row, or the colour given while it has none.
local function Colour(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and ns.Finite(cr) and ns.Finite(cg) and ns.Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

-- The Highlight colour of the Windows page, which Bags takes.
local function Accent()
	return Colour("windows.accent", 0.85, 0.85, 0.85)
end

-- Window opacity of the Windows page, 0 to 1 (BagsWindow.lua:272-278).
local function Opacity()
	local value = Call(B, "Look", "opacity")
	if not ns.Finite(value) then
		value = ns.Get("windows.opacity")
	end
	return ns.Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

-- The width a font string's text needs, whatever width it is given; 0 when the client does not say.
local function TextWidth(text)
	return Number(text, "GetUnboundedStringWidth") or Number(text, "GetStringWidth") or 0
end

local function Untip(frame)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, frame)
	if ok and owned == true then
		tip:Hide()
	end
end

-- An item by its name, or "item 123" while the client has not loaded it.
local function ItemName(id)
	local name = Ask(Item("GetItemNameByID"), id)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return ("item %d"):format(id)
end

-- The store ------------------------------------------------------------------------------------------------------------------------------------

-- FlatUIDB.bags, made with make; nil before the saved variables load, or when there is none and make is not set.
local function Bags(make)
	local db = ns.Account()
	if type(db) ~= "table" then
		return nil
	end
	local bags = db.bags
	if type(bags) ~= "table" then
		if not make then
			return nil
		end
		bags = {}
		db.bags = bags
	end
	return bags
end

-- The number of a key of a section of the player's own ("custom12" is 12), or nil for any other key.
local function KeyNumber(key)
	if type(key) ~= "string" or ns.IsSecret(key) then
		return nil
	end
	local digits = key:match("^" .. PREFIX .. "(%d+)$")
	return digits and tonumber(digits) or nil
end

-- What Read last read, kept until a write (revision) or until the saved list or its length changes.
local revision, cache = 0, nil

local function Changed()
	revision = revision + 1
end

-- The sections as saved: { keys (in the order made), names = { [key] = name }, entries = { [key] = saved entry } }. An entry that is not a table
-- with a key of the player's own, not taken already, and a name that is a plain text, is skipped.
local function Read()
	local bags = Bags(false)
	local list = bags and bags.custom
	if type(list) ~= "table" then
		list = nil
	end
	local size = list and #list or 0
	if cache and cache.revision == revision and cache.list == list and cache.size == size then
		return cache
	end
	local keys, names, entries = {}, {}, {}
	for _, entry in ipairs(list or {}) do
		if type(entry) == "table" then
			local key, name = entry.key, entry.name
			if KeyNumber(key) and names[key] == nil and type(name) == "string" and not ns.IsSecret(name) and name ~= "" then
				keys[#keys + 1] = key
				names[key] = name
				entries[key] = entry
			end
		end
	end
	cache = { revision = revision, list = list, size = size, keys = keys, names = names, entries = entries }
	return cache
end

-- A new array of the keys, in the order made.
function Custom.Keys()
	local keys = {}
	for index, key in ipairs(Read().keys) do
		keys[index] = key
	end
	return keys
end

-- True for a section the player made. BagsCategories.lua asks it for every item at each layout, through PlacedIn.
function Custom.Is(key)
	return type(key) == "string" and Read().names[key] ~= nil
end

function Custom.Name(key)
	if type(key) ~= "string" then
		return nil
	end
	return Read().names[key]
end

-- How many items are placed in each section of the player's own: { [key] = count }.
local function Counts()
	local counts = {}
	local names = Read().names
	local bags = Bags(false)
	local placed = bags and bags.placed
	for id, key in pairs(type(placed) == "table" and placed or {}) do
		if Whole(id) and type(key) == "string" and names[key] then
			counts[key] = (counts[key] or 0) + 1
		end
	end
	return counts
end

function Custom.Count(key)
	return Counts()[key] or 0
end

-- The keys in the order the windows show them (B.Order.Ranks, then by name), and the names.
local function Sorted()
	local data = Read()
	local keys = {}
	for index, key in ipairs(data.keys) do
		keys[index] = key
	end
	local okRanks, ranks = pcall(Call, B.Order, "Ranks")
	ranks = okRanks and type(ranks) == "table" and ranks or {}
	local names = data.names
	table.sort(keys, function(a, b)
		local ra, rb = ranks[a] or math.huge, ranks[b] or math.huge
		if ra ~= rb then
			return ra < rb
		end
		local na, nb = names[a]:lower(), names[b]:lower()
		if na ~= nb then
			return na < nb
		end
		return a < b
	end)
	return keys, names
end

-- Whether a name is one of Flat UI's own sections, in lower case: every label of B.Categories.LIST, the bank's Added and New section.
local function BuiltIn(lower)
	if lower == ADDED_WORD:lower() or lower == ADD_WORD:lower() then
		return true
	end
	local list = B.Categories and B.Categories.LIST
	for _, entry in ipairs(type(list) == "table" and list or {}) do
		if type(entry) == "table" and type(entry.label) == "string" and entry.label:lower() == lower then
			return true
		end
	end
	return false
end

-- The clean name (spaces trimmed and run together), or nil and why it is refused. except: the key of the section being renamed.
local function Check(name, except)
	if type(name) ~= "string" or ns.IsSecret(name) then
		return nil, SAY.empty
	end
	local clean = (name:gsub("%s+", " ")):match("^%s*(.-)%s*$") or ""
	if clean == "" then
		return nil, SAY.empty
	end
	if clean:find("|", 1, true) then
		return nil, SAY.bar
	end
	-- Letters, not bytes: the bytes that continue a letter of UTF-8 are not counted.
	if #(clean:gsub("[\128-\191]", "")) > LONGEST then
		return nil, SAY.long
	end
	local lower = clean:lower()
	if BuiltIn(lower) then
		return nil, SAY.builtin:format(clean)
	end
	local data = Read()
	for _, key in ipairs(data.keys) do
		if key ~= except and data.names[key]:lower() == lower then
			return nil, SAY.taken:format(Plain(data.names[key]))
		end
	end
	return clean
end

-- Takes every placement, fold and order key that gone(key) is true for out of FlatUIDB.bags; an empty set of folds or order is not kept, as
-- BagsOrder.lua keeps them. Returns how many placements went.
local function Forget(bags, gone)
	local count = 0
	local placed = bags.placed
	if type(placed) == "table" then
		for id, key in pairs(placed) do
			if gone(key) then
				placed[id] = nil
				count = count + 1
			end
		end
	end
	local folded = bags.folded
	if type(folded) == "table" then
		for key in pairs(folded) do
			if gone(key) then
				folded[key] = nil
			end
		end
		if next(folded) == nil then
			bags.folded = nil
		end
	end
	local order = bags.order
	if type(order) == "table" then
		for index = #order, 1, -1 do
			if gone(order[index]) then
				table.remove(order, index)
			end
		end
		if #order == 0 then
			bags.order = nil
		end
	end
	return count
end

-- Makes a section: its key, or nil and why it is refused. It comes in the windows at once (B.Request).
function Custom.Make(name)
	if #Read().keys >= MOST then
		return nil, SAY.most
	end
	local bags = Bags(true)
	if not bags then
		return nil, SAY.saved
	end
	local clean, why = Check(name)
	if not clean then
		return nil, why
	end
	-- Above every number saved anywhere, so a counter that was lost never brings an old key back.
	local number = math.max(Whole(bags.customNext) or 1, 1)
	local function Above(key)
		local saved = KeyNumber(key)
		if saved and saved >= number then
			number = saved + 1
		end
	end
	for _, entry in ipairs(type(bags.custom) == "table" and bags.custom or {}) do
		if type(entry) == "table" then
			Above(entry.key)
		end
	end
	for _, key in pairs(type(bags.placed) == "table" and bags.placed or {}) do
		Above(key)
	end
	for key in pairs(type(bags.folded) == "table" and bags.folded or {}) do
		Above(key)
	end
	for _, key in ipairs(type(bags.order) == "table" and bags.order or {}) do
		Above(key)
	end
	if type(bags.custom) ~= "table" then
		bags.custom = {}
	end
	local key = PREFIX .. number
	bags.custom[#bags.custom + 1] = { key = key, name = clean }
	bags.customNext = number + 1
	Changed()
	Request("layout")
	return key
end

-- Renames a section: true, or false and why. The key stays, so its placements, its fold and its place in the order stay too.
function Custom.Rename(key, name)
	local entry = type(key) == "string" and Read().entries[key] or nil
	if not entry then
		return false, SAY.gone
	end
	local clean, why = Check(name, key)
	if not clean then
		return false, why
	end
	if entry.name ~= clean then
		entry.name = clean
		Changed()
		Request("layout")
	end
	return true
end

-- Deletes a section: true and the line to say, or false and why. Its items go back to their own sections.
function Custom.Delete(key)
	local data = Read()
	local name = type(key) == "string" and data.names[key] or nil
	local bags = Bags(false)
	if not name or not bags or type(bags.custom) ~= "table" then
		return false, "Flat UI: " .. SAY.gone
	end
	local list = bags.custom
	for index = #list, 1, -1 do
		local entry = list[index]
		if type(entry) == "table" and entry.key == key then
			table.remove(list, index)
		end
	end
	if #list == 0 then
		bags.custom = nil
	end
	local count = Forget(bags, function(value)
		return value == key
	end)
	Changed()
	if Custom.Asking(key) then
		Custom.Close()
	end
	Request("layout")
	local text
	if count == 1 then
		text = SAY.deletedOne:format(Plain(name))
	elseif count > 1 then
		text = SAY.deletedMany:format(Plain(name), count)
	else
		text = SAY.deleted:format(Plain(name))
	end
	return true, "Flat UI: " .. text
end

-- After the module's Start: every placement, fold and order key of a section the list does not have goes, saying nothing.
function Custom.Sweep()
	local bags = Bags(false)
	if not bags then
		return
	end
	local names = Read().names
	Forget(bags, function(key)
		return KeyNumber(key) ~= nil and names[key] == nil
	end)
end

-- The name box ---------------------------------------------------------------------------------------------------------------------------------

-- { frame, outline, title, edit, field, note, make, cancel, plates, opts }, made the first time a name is asked. opts: { mode, key, item, which }
-- while it shows.
local box

local function Focused()
	local ok, focus = pcall(box.edit.HasFocus, box.edit)
	return ok and not ns.IsSecret(focus) and focus == true
end

-- The bag window's look (BagsWindow.lua:554-557), the search box's field (BagsSearch.lua:878-892) and the footer's buttons (:545-552).
local function PaintBox()
	if not box then
		return
	end
	local r, g, b = Colour("general.backdrop", 0.05, 0.05, 0.05)
	ns.SetOutlineFill(box.outline, r, g, b, Opacity())
	ns.SetOutline(box.outline, true, true)
	local pr, pg, pb = Colour("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = Accent()
	ns.SetOutlineFill(box.field, pr, pg, pb, 1)
	if Focused() then
		ns.SetOutlineColour(box.field, ar, ag, ab)
	else
		ns.SetOutlineColour(box.field, nil, nil, nil)
	end
	for _, plate in ipairs(box.plates) do
		ns.SetOutlineFill(plate.outline, pr, pg, pb, 1)
		ns.SetOutline(plate.outline, true, true)
		plate.hover:SetColorTexture(ar, ag, ab, 0.25)
	end
end

-- The note under the field: what Enter and Escape do, or a refusal in red.
local function Note(refusal)
	local opts = box.opts
	if refusal then
		box.note:SetText(refusal)
		box.note:SetTextColor(RED[1], RED[2], RED[3], 1)
	else
		box.note:SetText(NOTES[opts and opts.mode == "rename" and "rename" or "make"])
		box.note:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
end

local function Select()
	pcall(box.edit.SetFocus, box.edit)
	pcall(box.edit.HighlightText, box.edit)
end

-- True while the box asks the name of that section (a rename).
function Custom.Asking(key)
	return box ~= nil and box.opts ~= nil and box.opts.key == key and box.frame:IsShown()
end

function Custom.Close()
	if box and box.frame:IsShown() then
		box.frame:Hide()
	end
end

-- Enter or Make: the section is made or renamed, and the box closes; a refusal stays in the box.
local function Commit()
	local opts = box and box.opts
	if not opts then
		Custom.Close()
		return
	end
	if Fighting() then
		Custom.Close()
		Say(SAY.fight)
		return
	end
	local text = box.edit:GetText()
	local which = opts.which or "bags"
	if opts.mode == "rename" then
		local done, why = Custom.Rename(opts.key, text)
		if not done then
			Note(why)
			Select()
			return
		end
		Custom.Close()
		Custom.Took(which, opts.key, nil, nil, FLASH.renamed)
		return
	end
	local key, why = Custom.Make(text)
	if not key then
		Note(why)
		Select()
		return
	end
	local item = opts.item
	Custom.Close()
	if type(item) == "table" and Whole(item.id) then
		-- The item of a drop on + New section: kept in the new section by its ID where it lies, and a pinned slot it came from unpinned, as a
		-- title's drop does (BagsLayout.lua).
		if Call(B.Categories, "File", item.id, key, item.link, item.bag, item.slot) == true then
			Call(B, "Part", "pins", Call, B.Pins, "Left", item.id, item.bag, item.slot)
			Custom.Took(which, key, item.id)
		end
	else
		Custom.Took(which, key, nil)
	end
end

-- A button of the box in the look of the footer's buttons (BagsWindow.lua:1305-1330).
local function Plate(parent, onClick)
	local button = Own(CreateFrame("Button", nil, parent))
	button:SetSize(BUTTON_W, BUTTON_H)
	button:RegisterForClicks("LeftButtonUp")
	local plate = { button = button }
	plate.outline = ns.SetOutlineArea(ns.Outline(button, button), KEY)
	plate.hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	plate.hover:SetAllPoints(button)
	plate.label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	plate.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	plate.label:SetWordWrap(false)
	button:SetScript("OnClick", function()
		Part(onClick)
	end)
	return plate
end

local function BuildBox()
	if box then
		return box
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetSize(BOX_W, BOX_H)
	frame:SetFrameStrata("DIALOG")
	pcall(frame.SetClampedToScreen, frame, true)
	frame:EnableMouse(true)
	frame:Hide()
	box = { frame = frame, plates = {} }
	-- Named for the Bags page, since a pick in the options builds it outside a part of the module.
	box.outline = ns.SetOutlineArea(ns.Outline(frame, frame, true), KEY)
	box.title = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	box.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
	box.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
	box.title:SetJustifyH("LEFT")
	box.title:SetWordWrap(false)
	local edit = Own(CreateFrame("EditBox", nil, frame))
	edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -26)
	edit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -26)
	edit:SetHeight(FIELD_H)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetTextInsets(6, 6, 0, 0)
	pcall(edit.SetMaxLetters, edit, LONGEST)
	box.edit = edit
	box.field = ns.SetOutlineArea(ns.Outline(edit, edit, true), KEY)
	box.note = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	box.note:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -52)
	box.note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -52)
	box.note:SetJustifyH("LEFT")
	box.make = Plate(frame, Commit)
	box.make.button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
	box.cancel = Plate(frame, Custom.Close)
	box.cancel.button:SetPoint("RIGHT", box.make.button, "LEFT", -6, 0)
	box.cancel.label:SetText("Cancel")
	box.plates = { box.make, box.cancel }
	edit:SetScript("OnEnterPressed", function()
		Part(Commit)
	end)
	edit:SetScript("OnEscapePressed", function()
		Part(Custom.Close)
	end)
	-- What the player types puts the note back; the box stays open when the field loses the keyboard, since a click on Make takes it first.
	edit:SetScript("OnTextChanged", function(_, typed)
		if typed and box.opts then
			Part(Note)
		end
	end)
	edit:SetScript("OnEditFocusGained", function()
		Part(PaintBox)
	end)
	edit:SetScript("OnEditFocusLost", function()
		Part(PaintBox)
	end)
	-- A click on the box gives the field the keyboard again.
	frame:SetScript("OnMouseDown", function()
		pcall(edit.SetFocus, edit)
	end)
	-- A fight starts: the keyboard goes back to the game.
	frame:SetScript("OnEvent", function()
		Part(Custom.Close)
	end)
	-- Hidden with its parent (the interface hidden), the box keeps its own shown flag: it is hidden for good, so it never comes back empty.
	frame:SetScript("OnHide", function()
		if frame:IsShown() then
			frame:Hide()
		end
		pcall(edit.ClearFocus, edit)
		pcall(frame.UnregisterEvent, frame, "PLAYER_REGEN_DISABLED")
		box.opts = nil
	end)
	return box
end

-- Above the frame that asked (its top left corner, read once, so a layout that moves that frame leaves the box where it is), else above the middle of
-- the screen.
local function PlaceBox(anchor)
	local frame = box.frame
	frame:ClearAllPoints()
	local x, y
	if type(anchor) == "table" and not ns.Forbidden(anchor) then
		local okShown, shown = pcall(anchor.IsVisible, anchor)
		local left, top = Number(anchor, "GetLeft"), Number(anchor, "GetTop")
		local scale, ui = Number(anchor, "GetEffectiveScale"), Number(UIParent, "GetEffectiveScale")
		if okShown and shown == true and left and top and scale and ui and scale > 0 and ui > 0 then
			x, y = left * scale / ui, top * scale / ui
		end
	end
	if x then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y + 4)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end

-- Opens the name box. opts: mode ("make" or "rename"), key (a rename's section), item ({ id, link, bag, slot }: a new section for that item),
-- anchor (the frame it goes above) and which (the window that opened it, "bags" or "bank"; nil from the options). A second ask replaces the
-- first. True when the box is open.
function Custom.Ask(opts)
	opts = type(opts) == "table" and opts or {}
	if Fighting() then
		Say(SAY.fight)
		return false
	end
	local mode = opts.mode == "rename" and "rename" or "make"
	if mode == "make" and #Read().keys >= MOST then
		Say(SAY.most)
		return false
	end
	if type(ns.Account()) ~= "table" then
		Say(SAY.saved)
		return false
	end
	local current
	if mode == "rename" then
		current = Custom.Name(opts.key)
		if not current then
			Say(SAY.gone)
			return false
		end
	end
	BuildBox()
	Custom.Close()
	local item = type(opts.item) == "table" and Whole(opts.item.id) and opts.item or nil
	box.opts = { mode = mode, key = opts.key, item = item, which = opts.which }
	if mode == "rename" then
		box.title:SetText("Rename " .. Plain(current))
		box.make.label:SetText("Rename")
	else
		box.title:SetText(item and ("New section for " .. Plain(ItemName(item.id))) or ADD_WORD)
		box.make.label:SetText("Make")
	end
	Note()
	box.edit:SetText(current or "")
	PlaceBox(opts.anchor)
	box.frame:Show()
	pcall(box.frame.RegisterEvent, box.frame, "PLAYER_REGEN_DISABLED")
	Select()
	PaintBox()
	-- The box is only up while it can take the keyboard, so Enter or Escape can close it (ChatLinks.lua:653-659).
	if not Focused() then
		Custom.Close()
		return false
	end
	return true
end

-- Menus and the + New section title ------------------------------------------------------------------------------------------------------------

local function Announce(_, text)
	if type(text) == "string" then
		print(text)
	end
end

-- The lines BagsOrder.lua adds to a title's menu: Rename and Delete this section on a section of the player's own, and New section in the
-- player's own bag window.
function Custom.MenuLines(st, sec, anchor)
	local items = {}
	if type(st) ~= "table" or type(sec) ~= "table" then
		return items
	end
	local which, key = st.which, sec.key
	if Custom.Is(key) then
		items[#items + 1] = { text = "Rename", part = PART, pick = function()
			Custom.Ask({ mode = "rename", key = key, anchor = anchor, which = which })
		end }
		items[#items + 1] = { text = "Delete this section", part = PART, pick = function()
			Announce(Custom.Delete(key))
		end }
	end
	if which == "bags" and st.mine then
		items[#items + 1] = { text = ADD_WORD, part = PART, pick = function()
			Custom.Ask({ mode = "make", anchor = anchor, which = which })
		end }
	end
	return items
end

-- The menu of + New section: New section, then each section of the player's own under its name (with how many items it holds) with Rename and
-- Delete.
local function YourLines(st, anchor)
	local which = st.which
	local items = { { text = ADD_WORD, part = PART, pick = function()
		Custom.Ask({ mode = "make", anchor = anchor, which = which })
	end } }
	local keys, names = Sorted()
	if #keys == 0 then
		items[#items + 1] = { text = "No section of your own yet", header = true }
	end
	local counts = Counts()
	for _, key in ipairs(keys) do
		local count = counts[key] or 0
		items[#items + 1] = { text = Plain(names[key]), right = count > 0 and tostring(count) or nil, header = true }
		items[#items + 1] = { text = "Rename", part = PART, pick = function()
			Custom.Ask({ mode = "rename", key = key, anchor = anchor, which = which })
		end }
		items[#items + 1] = { text = "Delete", part = PART, pick = function()
			Announce(Custom.Delete(key))
		end }
	end
	return items
end

-- A click on + New section with no item on the cursor: the left button asks for a name, the right one opens the menu of the player's sections.
function Custom.AddClick(st, mouse, anchor)
	if type(st) ~= "table" then
		return
	end
	if mouse == "RightButton" then
		Call(B.Layout, "Menu", anchor, "Your sections", YourLines(st, anchor), st.which)
	elseif mouse == "LeftButton" then
		Custom.Ask({ mode = "make", anchor = anchor, which = st.which })
	end
end

-- The line of + New section's tooltip.
function Custom.AddTip(st)
	if type(st) == "table" and st.holding then
		return TIPS.addHolding
	end
	if #Read().keys >= MOST then
		return TIPS.add .. TIPS.addFull
	end
	return TIPS.add
end

-- Drops ---------------------------------------------------------------------------------------------------------------------------------------

-- An item from outside the bags: worn gear, or a container that is not one of the bags (the bank's tabs, 6 to 14, and its bag slots, -2). An item
-- whose place the game does not say counts as one of the bags, so it is handled as a title handles it.
local function Outside(bag, worn)
	if worn ~= nil then
		return true
	end
	if bag ~= nil then
		return not BAG_IDS[bag]
	end
	return false
end

-- The item on the cursor: { id, link, bag, slot, worn, outside }, or nil when it holds no item.
local function Cursor()
	local ok, kind, id, link = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) or kind ~= "item" then
		return nil
	end
	id = Whole(id)
	if not id or id <= 0 then
		return nil
	end
	local held = { id = id, link = (type(link) == "string" and not ns.IsSecret(link) and link ~= "") and link or nil }
	local getItem = type(C_Cursor) == "table" and C_Cursor.GetCursorItem or nil
	if type(getItem) == "function" then
		local okItem, location = pcall(getItem)
		if okItem and not ns.IsSecret(location) and type(location) == "table" then
			local okSlot, bag, slot, worn = pcall(function()
				return location.bagID, location.slotIndex, location.equipmentSlotIndex
			end)
			if okSlot then
				held.bag, held.slot, held.worn = Whole(bag), Whole(slot), Whole(worn)
			end
		end
	end
	held.outside = Outside(held.bag, held.worn)
	held.bagBar = held.worn ~= nil and held.worn > LAST_WORN
	return held
end

local function HasItem()
	local ok, kind = pcall(GetCursorInfo)
	return ok and not ns.IsSecret(kind) and kind == "item"
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

-- Whether an item fits a special bag: not a container or a quiver, and its family meets the bag's (BagsPins.lua:662-679).
local function Fits(id, family)
	if not Whole(family) or family == 0 then
		return false
	end
	local instant = Item("GetItemInfoInstant")
	if type(instant) == "function" then
		local ok, _, _, _, _, _, class = pcall(instant, id)
		if not ok or ns.IsSecret(class) or class == CONTAINER or class == QUIVER then
			return false
		end
	end
	local itemFamily = Whole(Ask(Item("GetItemFamily"), id))
	return itemFamily ~= nil and type(bit) == "table" and type(bit.band) == "function" and bit.band(itemFamily, family) ~= 0
end

-- The empty slot an item from outside the bags goes in, read anew: the first of the backpack or a normal bag that is not pinned for another item,
-- else the first such slot of a special bag that fits it; never the reagent bag or the keyring. Nil when there is none.
local function FreeFor(id)
	local numSlots, numFree, itemOf = Container("GetContainerNumSlots"), Container("GetContainerNumFreeSlots"), Container("GetContainerItemID")
	if type(numSlots) ~= "function" or type(numFree) ~= "function" or type(itemOf) ~= "function" then
		return nil
	end
	local pinned = Fn(B.Pins, "Get")
	local spareBag, spareSlot
	for bag = FIRST_BAG, LAST_BAG do
		local okFree, _, family = pcall(numFree, bag)
		family = okFree and Whole(family) or nil
		local general = family == 0
		if general or (family ~= nil and not spareBag and bag > 0 and Fits(id, family)) then
			for slot = 1, Whole(Ask(numSlots, bag)) or 0 do
				local okItem, inSlot = pcall(itemOf, bag, slot)
				if okItem and not ns.IsSecret(inSlot) and inSlot == nil then
					local pin = nil
					if pinned then
						local okPin, pinId = pcall(pinned, bag, slot)
						pin = okPin and Whole(pinId) or nil
					end
					if pin == nil or pin == id then
						if general then
							return bag, slot
						end
						spareBag, spareSlot = bag, slot
						break
					end
				end
			end
		end
	end
	return spareBag, spareSlot
end

-- The cursor as the frames of a window last read it: what Holding read as the cursor came to hold an item, and whether it would go in.
local function ReadHeld()
	local held = Cursor()
	if held and held.outside and not held.bagBar then
		held.fits = FreeFor(held.id) ~= nil
	end
	return held
end

-- True when a drop of the held item in that window moves it into the bags first: from outside the bags, in the player's own live bag window.
local function Moves(st, held)
	return held.outside and st.which == "bags" and st.mine == true and st.live == true
end

-- Whether a + slot or a catcher takes the held item.
local function Accepts(st, sec, held)
	if not held then
		return false
	end
	if held.outside and sec.key == "keep" then
		return false
	end
	if Moves(st, held) then
		return not held.bagBar and held.fits == true
	end
	return true
end

-- Whether the bags have a free slot of the general bags, as Free slots counts them (BagsLayout.lua, st.free.count).
local function Room(st)
	local free = st.free
	return type(free) == "table" and ns.Finite(free.count) and free.count > 0
end

local function Recent(target)
	local dropped = target.dropped
	return dropped ~= nil and Now() - dropped < DROP_CLICK
end

-- The item on the cursor let go or clicked on a + slot or a catcher (see the top of the file).
local function Drop(target)
	local st, sec = target.st, target.sec
	if not (st and sec) then
		return
	end
	local held = Cursor()
	if not held then
		return
	end
	target.dropped = Now()
	if Fighting() then
		Clear()
		print(FIGHT_LINE)
		return
	end
	if Moves(st, held) and sec.key ~= "keep" then
		local name = Plain(ItemName(held.id))
		if held.bagBar then
			Clear()
			Say(SAY.bagBar)
			return
		end
		local toBag, toSlot = FreeFor(held.id)
		local pickup = Container("PickupContainerItem")
		if not toBag or type(pickup) ~= "function" then
			Clear()
			Say(SAY.noRoom:format(name))
			return
		end
		pcall(pickup, toBag, toSlot)
		if CursorHeld() then
			Clear()
			Say(SAY.notPut:format(name))
			return
		end
		-- The slot of BagsData is not read yet, so the item is judged by its ID; once it arrives the window is laid out afresh (Arrived).
		if Call(B.Categories, "File", held.id, sec.key, held.link, toBag, toSlot) == true then
			Custom.Arriving(st.which, toBag, toSlot, held.id)
			Custom.Took(st.which, sec.key, held.id, true)
		end
		return
	end
	if Call(B.Layout, "Take", st, sec) == true then
		Custom.Took(st.which, sec.key, held.id)
	end
end

-- The + New section title took a drop: the item goes back where it was, and the box asks for the name of a section for it.
function Custom.DropNew(st, anchor)
	if type(st) ~= "table" then
		return
	end
	if Fighting() then
		Clear()
		print(FIGHT_LINE)
		return
	end
	local held = Cursor()
	Clear()
	if not held then
		return
	end
	Custom.Ask({ mode = "make", item = { id = held.id, link = held.link, bag = held.bag, slot = held.slot }, anchor = anchor, which = st.which })
end

-- The layout's frames --------------------------------------------------------------------------------------------------------------------------

-- Per layout state of a window (BagsLayout.lua): { st, cells, catchers, cellsUsed, catchersUsed, held, flash }. byWhich: the state of each
-- window, for Closed. arrivals: { which, bag, slot, id, at } of the items a drop put in a free slot of the bags. waiting: the drop whose section
-- flashes at its next placing, { which, key, at, text }.
local pools = setmetatable({}, { __mode = "k" })
local byWhich = {}
local arrivals = {}
local waiting = nil

local function Pool(st)
	local pool = pools[st]
	if not pool then
		pool = { st = st, cells = {}, catchers = {}, cellsUsed = 0, catchersUsed = 0 }
		pools[st] = pool
	end
	return pool
end

-- Paints a + slot: lit while the cursor holds an item it takes, white under the mouse with an empty cursor, and its + dimmed while the bags are full.
local function Paint(cell)
	local st, sec, pool = cell.st, cell.sec, cell.pool
	if not (st and sec) then
		return
	end
	local ar, ag, ab = Accent()
	local pr, pg, pb = Colour("windows.panel", 0.12, 0.12, 0.12)
	ns.SetOutlineFill(cell.outline, pr, pg, pb, 1)
	if st.holding and Accepts(st, sec, pool.held) then
		ns.SetOutlineColour(cell.outline, ar, ag, ab)
		for _, line in ipairs(cell.lines) do
			line:SetColorTexture(ar, ag, ab, 1)
		end
		cell.light:SetColorTexture(ar, ag, ab, cell.over and LIT_HOVER or LIT)
		cell.light:Show()
		return
	end
	ns.SetOutlineColour(cell.outline, nil, nil, nil)
	local alpha = Room(st) and PLUS_ALPHA or PLUS_DIM
	for _, line in ipairs(cell.lines) do
		line:SetColorTexture(PLUS[1], PLUS[2], PLUS[3], alpha)
	end
	if cell.over and not st.holding then
		cell.light:SetColorTexture(1, 1, 1, HOVER)
		cell.light:Show()
	else
		cell.light:Hide()
	end
end

-- The tooltip of a + slot, and of a catcher while the cursor holds an item.
local function Tip(target)
	local tip = GameTooltip
	local st, sec = target.st, target.sec
	if not (st and sec) or type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local label = Plain(sec.label or sec.key)
	local held = st.holding and target.pool.held or nil
	local verb = target.catcher and TIPS.letGo or TIPS.drop
	local line
	if held then
		if held.outside and sec.key == "keep" then
			line = TIPS.keepOutside
		elseif Moves(st, held) and held.bagBar then
			line = TIPS.bagBar
		elseif Moves(st, held) and not held.fits then
			line = TIPS.noRoom
		elseif Moves(st, held) then
			line = TIPS.move:format(verb, label)
		elseif sec.key == "junk" then
			line = TIPS.junk:format(verb)
		elseif sec.key == "keep" then
			line = TIPS.keep:format(verb)
		else
			line = TIPS.kept:format(verb, label)
		end
	elseif target.catcher then
		return
	elseif sec.key == "junk" then
		line = TIPS.idleJunk
	elseif sec.key == "keep" then
		line = TIPS.idleKeep
	else
		line = TIPS.idle:format(label) .. (Room(st) and "" or TIPS.full)
	end
	tip:SetOwner(target.frame, "ANCHOR_TOP")
	tip:SetText(label, 1, 1, 1)
	tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
	tip:Show()
end

-- The mouse comes over a + slot or a catcher: what the cursor holds is read again, since a click may have swapped it.
local function Enter(target)
	local st = target.st
	if not st then
		return
	end
	target.over = true
	local pool = target.pool
	if st.holding then
		pool.held = ReadHeld()
	end
	if target.catcher then
		if st.holding and Accepts(st, target.sec, pool.held) then
			local r, g, b = Accent()
			target.light:SetColorTexture(r, g, b, LIT)
			target.light:Show()
		else
			target.light:Hide()
		end
		if st.holding then
			Tip(target)
		end
		return
	end
	Paint(target)
	Tip(target)
end

local function Leave(target)
	target.over = false
	if target.catcher then
		target.light:Hide()
	else
		Paint(target)
	end
	Untip(target.frame)
end

-- The + slot number index of a window, made the first time a layout needs it: an empty slot's box with a + and a light.
local function Cell(pool, index)
	local cell = pool.cells[index]
	if cell then
		return cell
	end
	local button = Own(CreateFrame("Button", nil, pool.st.content))
	button:SetSize(SLOT, SLOT)
	button:RegisterForClicks("LeftButtonUp")
	cell = { frame = button, pool = pool, lines = {} }
	cell.outline = ns.SetOutlineArea(ns.Outline(button, button), KEY)
	for _, size in ipairs({ { PLUS_LONG, PLUS_THICK }, { PLUS_THICK, PLUS_LONG } }) do
		local line = Own(button:CreateTexture(nil, "ARTWORK"))
		line:SetSize(size[1], size[2])
		line:SetPoint("CENTER", button, "CENTER", 0, 0)
		cell.lines[#cell.lines + 1] = line
	end
	cell.light = Own(button:CreateTexture(nil, "OVERLAY"))
	cell.light:SetAllPoints(button)
	cell.light:Hide()
	button:SetScript("OnReceiveDrag", function()
		Part(Drop, cell)
	end)
	button:SetScript("OnClick", function()
		if HasItem() and not Recent(cell) then
			Part(Drop, cell)
		end
	end)
	button:SetScript("OnEnter", function()
		Part(Enter, cell)
	end)
	button:SetScript("OnLeave", function()
		Part(Leave, cell)
	end)
	pool.cells[index] = cell
	return cell
end

-- The catcher number index of a window: a frame of its own with a light under the buttons, which takes the mouse only while the cursor holds an item.
local function Catcher(pool, index)
	local catcher = pool.catchers[index]
	if catcher then
		return catcher
	end
	local frame = Own(CreateFrame("Frame", nil, pool.st.content))
	frame:EnableMouse(false)
	catcher = { frame = frame, pool = pool, catcher = true }
	catcher.light = Own(frame:CreateTexture(nil, "BACKGROUND"))
	catcher.light:SetAllPoints(frame)
	catcher.light:Hide()
	frame:SetScript("OnReceiveDrag", function()
		Part(Drop, catcher)
	end)
	-- An item picked up with a click and let go here with another.
	frame:SetScript("OnMouseUp", function(_, mouse)
		if mouse == "LeftButton" and HasItem() and not Recent(catcher) then
			Part(Drop, catcher)
		end
	end)
	frame:SetScript("OnEnter", function()
		Part(Enter, catcher)
	end)
	frame:SetScript("OnLeave", function()
		Part(Leave, catcher)
	end)
	pool.catchers[index] = catcher
	return catcher
end

-- A + slot or catcher the pass did not use: hidden, with no mouse and no tooltip.
local function Retire(target)
	target.sec, target.over = nil, false
	Untip(target.frame)
	if target.catcher then
		target.frame:EnableMouse(false)
		target.light:Hide()
	end
	target.frame:Hide()
end

-- The flash ------------------------------------------------------------------------------------------------------------------------------------

local function StopFlash(pool)
	local flash = pool.flash
	if flash then
		flash.started, flash.key = nil, nil
		flash.frame:Hide()
	end
end

-- Both fades of the flash, every frame while it shows: the light from FLASH_ALPHA to nothing over FLASH_FADE, the words for SAY_HOLD and then over
-- SAY_FADE.
local function Tick(pool)
	local flash = pool.flash
	if not (flash and flash.started) then
		return
	end
	local age = Now() - flash.started
	local light = FLASH_ALPHA * (1 - age / FLASH_FADE)
	local words = age <= SAY_HOLD and 1 or (1 - (age - SAY_HOLD) / SAY_FADE)
	if light <= 0 and words <= 0 then
		StopFlash(pool)
		return
	end
	flash.fill:SetColorTexture(flash.r, flash.g, flash.b, math.max(0, light))
	flash.say:SetAlpha(math.max(0, words))
end

local function FlashFrame(pool)
	if pool.flash then
		return pool.flash
	end
	local frame = Own(CreateFrame("Frame", nil, pool.st.content))
	frame:EnableMouse(false)
	frame:Hide()
	local flash = { frame = frame }
	flash.fill = Own(frame:CreateTexture(nil, "ARTWORK"))
	flash.fill:SetAllPoints(frame)
	flash.say = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	flash.say:SetJustifyH("RIGHT")
	flash.say:SetWordWrap(false)
	frame:SetScript("OnUpdate", function()
		Part(Tick, pool)
	end)
	pool.flash = flash
	return flash
end

-- Puts the flash over a section's title and cells (ah: the height of its cells, nil for a title alone), and its words at the right of the title in
-- the title's font, where they fit; title frames are pooled by index, so each placing anchors it again.
local function Anchor(pool, title, ah)
	local flash = pool.flash
	local frame, say = flash.frame, flash.say
	local width = Number(title.frame, "GetWidth") or 0
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", title.frame, "TOPLEFT", -2, 2)
	frame:SetSize(math.max(1, width + 4), math.max(1, (Number(title.frame, "GetHeight") or 16) + (ah or 0) + 4))
	local okFont, file, size, flags = pcall(title.text.GetFont, title.text)
	if okFont and type(file) == "string" and not ns.IsSecret(file) and ns.Finite(size) then
		pcall(say.SetFont, say, file, size, type(flags) == "string" and not ns.IsSecret(flags) and flags or "")
	end
	local room = width - TextWidth(title.text) - 12
	if flash.text and room >= SAY_LEAST then
		say:ClearAllPoints()
		say:SetPoint("RIGHT", title.frame, "RIGHT", -2, 0)
		say:SetWidth(room)
		say:SetText(flash.text)
		say:SetTextColor(flash.r, flash.g, flash.b, 1)
		say:Show()
	else
		say:Hide()
	end
	flash.placed = true
end

local function StartFlash(pool, title, ah, key, text)
	local flash = FlashFrame(pool)
	flash.key, flash.text, flash.started = key, text, Now()
	flash.r, flash.g, flash.b = Accent()
	flash.frame:SetFrameLevel((Number(pool.st.content, "GetFrameLevel") or 0) + FLASH_LEVEL)
	flash.fill:SetColorTexture(flash.r, flash.g, flash.b, FLASH_ALPHA)
	flash.say:SetAlpha(1)
	Anchor(pool, title, ah)
	flash.frame:Show()
end

-- A section took an item (or was made or renamed): it flashes at its next placing in that window, within FLASH_WAIT. id: the item, nil for a new
-- empty section; moved: the item was moved into the bags first; text: the words to say in place of the ones the section gives.
function Custom.Took(which, key, id, moved, text)
	if type(key) ~= "string" then
		return
	end
	if not text then
		if key == "junk" then
			text = FLASH.junk
		elseif key == "keep" then
			text = FLASH.keep
		elseif not Whole(id) then
			text = FLASH.made
		else
			text = (moved and FLASH.moved or FLASH.kept):format(Plain(ItemName(id)))
		end
	end
	waiting = { which = which or "bags", key = key, at = Now(), text = text }
end

-- An item a drop put in a free slot of the bags, waited for (Arrived).
function Custom.Arriving(which, bag, slot, id)
	arrivals[#arrivals + 1] = { which = which, bag = bag, slot = slot, id = id, at = Now() }
end

-- True when an item a drop moved into the bags is in its slot now (BagsData's record, B.Data.Item): it is waited for no longer. Arrivals older than
-- ARRIVE_WAIT go too.
local function Landed(st)
	if #arrivals == 0 or type(st) ~= "table" then
		return false
	end
	local read = Fn(B.Data, "Item")
	local now, arrived = Now(), false
	for index = #arrivals, 1, -1 do
		local arrival = arrivals[index]
		if now - arrival.at > ARRIVE_WAIT then
			table.remove(arrivals, index)
		elseif arrival.which == st.which and read then
			local okRecord, record = pcall(read, st.key, arrival.bag, arrival.slot)
			if okRecord and type(record) == "table" and Whole(record.id) == arrival.id then
				table.remove(arrivals, index)
				arrived = true
			end
		end
	end
	return arrived
end

-- The layout hooks ------------------------------------------------------------------------------------------------------------------------------

-- A pass of a window starts (BagsLayout's Render): no + slot or catcher is used yet.
function Custom.Begin(st)
	if type(st) ~= "table" or not st.content then
		return
	end
	local pool = Pool(st)
	pool.cellsUsed, pool.catchersUsed = 0, 0
	if pool.flash then
		pool.flash.placed = false
	end
	byWhich[st.which] = st
	-- A pass of a fresh layout (B.Layout.Builds counts them) files every item where it belongs, so an item that arrived before it is waited for no
	-- longer, and its next change of slots lays nothing out again.
	local builds = Call(B.Layout, "Builds", st.which)
	if builds ~= pool.builds then
		pool.builds = builds
		Landed(st)
	end
	if st.holding then
		pool.held = pool.held or ReadHeld()
	else
		pool.held = nil
	end
	if waiting and Now() - waiting.at > FLASH_WAIT then
		waiting = nil
	end
end

-- A section is placed (BagsLayout's PlaceSection): its title, the place of its + slot (px, py) and the rectangle of its cells for the catcher
-- (ax, ay, aw, ah), in the content's units, each nil when it has none; and the flash, when this section took the last drop.
function Custom.Place(st, sec, title, px, py, ax, ay, aw, ah)
	if type(st) ~= "table" or type(sec) ~= "table" or not st.content then
		return
	end
	local pool = Pool(st)
	local level = Number(st.content, "GetFrameLevel") or 0
	if ns.Finite(px) and ns.Finite(py) then
		pool.cellsUsed = pool.cellsUsed + 1
		local cell = Cell(pool, pool.cellsUsed)
		cell.st, cell.sec = st, sec
		local frame = cell.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", st.content, "TOPLEFT", px, py)
		frame:SetFrameLevel(level + CELL_LEVEL)
		Paint(cell)
		frame:Show()
	end
	if ns.Finite(ax) and ns.Finite(ay) and ns.Finite(aw) and ns.Finite(ah) and aw > 0 and ah > 0 then
		pool.catchersUsed = pool.catchersUsed + 1
		local catcher = Catcher(pool, pool.catchersUsed)
		catcher.st, catcher.sec = st, sec
		local frame = catcher.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", st.content, "TOPLEFT", ax, ay)
		frame:SetSize(aw, ah)
		-- At the content's own level, under the holders of the bags, the item buttons, the titles and the + slots.
		frame:SetFrameLevel(level)
		frame:EnableMouse(st.holding == true)
		if not st.holding then
			catcher.light:Hide()
		end
		frame:Show()
	else
		ah = nil
	end
	if type(title) ~= "table" or type(title.frame) ~= "table" then
		return
	end
	if waiting and waiting.which == st.which and waiting.key == sec.key then
		local drop = waiting
		waiting = nil
		if Now() - drop.at <= FLASH_WAIT then
			StartFlash(pool, title, ah, sec.key, drop.text)
		end
	elseif pool.flash and pool.flash.started and pool.flash.key == sec.key then
		Anchor(pool, title, ah)
	end
end

-- The pass ends: the + slots and catchers it did not use hide, and the flash of a section it did not place stops.
function Custom.Done(st)
	local pool = type(st) == "table" and pools[st] or nil
	if not pool then
		return
	end
	for index = pool.cellsUsed + 1, #pool.cells do
		if pool.cells[index].frame:IsShown() then
			Retire(pool.cells[index])
		end
	end
	for index = pool.catchersUsed + 1, #pool.catchers do
		if pool.catchers[index].frame:IsShown() then
			Retire(pool.catchers[index])
		end
	end
	if pool.flash and pool.flash.started and not pool.flash.placed then
		StopFlash(pool)
	end
end

-- The cursor came to hold an item, or let it go (BagsLayout's Watch): it is read once, the + slots are painted again, and the catchers take the
-- mouse while it holds one.
function Custom.Holding(st)
	local pool = type(st) == "table" and pools[st] or nil
	if not pool then
		return
	end
	pool.held = st.holding and ReadHeld() or nil
	for index = 1, pool.cellsUsed do
		Paint(pool.cells[index])
	end
	for index = 1, pool.catchersUsed do
		local catcher = pool.catchers[index]
		catcher.frame:EnableMouse(st.holding == true)
		if not st.holding then
			catcher.light:Hide()
			Untip(catcher.frame)
		end
	end
end

-- The open window's slots changed (BagsLayout's Layout.Update): true when an item a drop moved into the bags has arrived in its slot, so the window
-- is laid out afresh and the item shows in its section. held: a sort still moves items, and the layout after it shows the item. Arrivals older than
-- ARRIVE_WAIT go.
function Custom.Arrived(st, changed, held)
	return Landed(st) and not held
end

-- A window closed (BagsLayout's Layout.Closed): its + slots, catchers and flash hide, what waited for it goes, and the name box it opened closes.
function Custom.Closed(which)
	local st = byWhich[which]
	local pool = st and pools[st]
	if pool then
		for _, cell in ipairs(pool.cells) do
			Retire(cell)
		end
		for _, catcher in ipairs(pool.catchers) do
			Retire(catcher)
		end
		pool.cellsUsed, pool.catchersUsed, pool.held = 0, 0, nil
		StopFlash(pool)
	end
	if waiting and waiting.which == which then
		waiting = nil
	end
	for index = #arrivals, 1, -1 do
		if arrivals[index].which == which then
			table.remove(arrivals, index)
		end
	end
	if box and box.opts and box.opts.which == which then
		Custom.Close()
	end
end

-- The row Custom sections ------------------------------------------------------------------------------------------------------------------------

-- Make a new section (or, at MOST, why not), then Rename and Delete for each section in the order the windows show them, as the lines of Section
-- order and Items placed by hand are given (BagsOrder.lua:692-705, BagsCategories.lua:909-949).
function ns.BagsCustomLines()
	local lines = {}
	local keys, names = Sorted()
	if #keys < MOST then
		lines[1] = { "new", "Make a new section" }
	else
		lines[1] = { "full", SAY.full }
	end
	local counts = Counts()
	for _, key in ipairs(keys) do
		local name, count = Plain(names[key]), counts[key] or 0
		lines[#lines + 1] = { "rename:" .. key, "Rename " .. name }
		lines[#lines + 1] = { "delete:" .. key, ("Delete %s%s"):format(name, count > 0 and (" (%d placed)"):format(count) or "") }
	end
	return lines
end

-- What the Panel prints of a pick is the second answer (Panel.lua:885-920); the name box says its own refusals.
function ns.BagsCustomPick(id)
	if id == "new" then
		if Fighting() then
			return false, "Flat UI: " .. SAY.fight
		end
		Custom.Ask({ mode = "make" })
		return true
	elseif id == "full" then
		return false, "Flat UI: " .. SAY.full
	end
	local key = type(id) == "string" and id:match("^rename:(.+)$") or nil
	if key then
		Custom.Ask({ mode = "rename", key = key })
		return true
	end
	key = type(id) == "string" and id:match("^delete:(.+)$") or nil
	if key then
		return Custom.Delete(key)
	end
	return false
end

-- /flatui status: how many sections of the player's own, named (at most STATUS_NAMES), and how many items are placed in them.
ns.AddStatus(KEY, function()
	local keys, names = Sorted()
	if #keys == 0 then
		return {}
	end
	local shown = {}
	for index = 1, math.min(#keys, STATUS_NAMES) do
		shown[index] = Plain(names[keys[index]])
	end
	local list = table.concat(shown, ", ")
	if #keys > STATUS_NAMES then
		list = ("%s and %d more"):format(list, #keys - STATUS_NAMES)
	end
	local placed = 0
	for _, count in pairs(Counts()) do
		placed = placed + count
	end
	return { ("Bags: %d %s of your own (%s), %d %s placed in them."):format(#keys, #keys == 1 and "section" or "sections", list, placed,
		placed == 1 and "item" or "items") }
end)

ns.AddStart(KEY, function()
	Part(Custom.Sweep)
end)
