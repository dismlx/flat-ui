local _, ns = ...

-- Bags, the layout of a bag window: where every slot the window shows goes, in that window's content frame (BagsWindow.lua). The content frame
-- is scaled by Slot size over the 37 units of the game's item button (ContainerFrameItemButtonTemplate, Mainline/ContainerFrame.xml:77-78), so
-- everything here is in the units of that button: a cell is 40 of them, a button and a space of 3. Frames of Flat UI's own take that scale too,
-- and the game's art on its item buttons stays in proportion. A window is as many cells wide as Width in slots (or Bank width in slots) says, and
-- no wider than 95% of the screen (UIParent's width) with its padding. Two views, as Show items says.
-- Sections files every item with B.Categories.Of and sorts each section with B.Categories.Compare (BagsCategories.lua), but for Keep in place,
-- whose cells go in the order of the bags and their slots, so it mirrors the bags and never reshuffles; in the player's own bag window an empty
-- pinned slot (B.Pins.Get, BagsPins.lua) gets a cell there too, its live empty button, so an item dropped on it goes in the slot, and Free slots,
-- which skips every slot that has a cell, shows another. Like any cell, it shows what fills its slot while the window is open, also loot the
-- game puts there, with the pin's hollow mark, until the next layout. While this character has a pin, the bag window always has the title of
-- Keep in place, as it has Junk's (B.Pins.Any). The sections go in the player's order (B.Order.Ranks, BagsOrder.lua), else in the order
-- of B.Categories.LIST. A section lies under its
-- title, as many cells wide as it has items, at least as wide as its title needs and at most as wide as the window. The title's width is measured
-- once per layout with GetUnboundedStringWidth on Flat UI's own font string (WL/uiobjects.yaml:3738), and a title wider than the window is cut to
-- it with an ellipsis (SetWidth and SetWordWrap, :3857). Titles and that font string take the face and outline the game's small font
-- (GameFontNormalSmall, GetFont) has when they are drawn, which Flat UI's Fonts page changes while the game runs, at their own size (SetFont).
-- Sections go left to right on a shelf while they fit, and one that does not fit starts the next shelf, 12 units below. The player's own bag
-- window always has a Junk title, a title with no cell while nothing is junk, so there is always somewhere to drop an item for the sell list. The
-- top shelf is as wide as the window, titled New items in the bag window while New items at the top is on and everything on it is new, else
-- Added, as in the bank window; New items is told of everything the shelf shows (B.Categories.New.Shown), so it leaves when the window closes.
-- Free slots is the last, and its title counts the free slots of the general bags alone (the backpack, normal bags and the bank's own slots,
-- family 0), the only room for any item: with One per kind of bag one counted slot for the general bags (the live button of their first free
-- slot, so a drop on it puts the item there), and, in the player's own live bags or bank only, where a drop puts an item in, one counted slot
-- for each kind of special bag with room (the reagent bag, a trade bag, a quiver, an ammo pouch, a soul bag), its own number on it but not in
-- the title's; with Every free slot each free slot of the general bags alone. The keyring's slots show in neither, as it holds only keys. A
-- special bag's own free slots are on its label in Bag by bag. A title's text keeps an on-screen size of at least 9 units, so a small Slot size
-- never makes it unreadable.
-- The player's own bag window also always has the titles of the sections the player made (B.Custom.Keys, BagsCustom.lua), and after the last
-- section + New section, a title with no cell that makes one (never moved or folded). With Drop slot in each section on, each open section whose
-- title takes a drop ends in a + slot there, one cell more, so the empty Junk title and an empty section of the player's own have one cell. Free
-- slots says "12 of 80": the free slots of the general bags of all their slots, the count in gold at 4 or fewer and the whole title red with none
-- left (the footer's colours, BagsWindow.lua:145-146, 1212), and it stays, as its title alone, while the bags are full.
-- While the window is open nothing moves but what arrives. A slot that keeps an item is drawn again where it is, whatever it holds now. A slot that
-- empties keeps its cell as a blank slot (B.Buttons.Draw with hold), Free slots is drawn again below everything, and an item in a slot that had no
-- cell goes to the end of the top shelf, which moves what is below it only when it needs a new row (the first time, a row and its title). While a
-- sort still moves items nothing goes to the top shelf: the window keeps every place, and each live button is drawn again in its cell. Everything
-- is laid out afresh when the window opens, and when the window asks for it after a change of view, row or character, and after a sort once the
-- items have stopped moving (Bags.lua).
-- Placing the buttons works in a fight: they are the game's item buttons, which are not protected (ContainerFrame.xml:77), or Flat UI's own.
-- Bag by bag lays out each bag in turn under a label, every slot in its place, so nothing ever moves. The keyring shows as many slots as the game's
-- own keyring window would (GetKeyRingSize, Blizzard_MainMenuBarBagButtons/Camelot/MainMenuBarBagButtons.lua:64-92: the last filled slot rounded
-- up to four, and four more once every slot up to it is filled), worked out here from the records, since the game's function reads the logged-in
-- character's keyring only. A bag's label is its name (C_Container.GetBagName, WL/apis.yaml:8530) for the player's own live bags, else the label of
-- its kind, with the kind after a special bag's name, and the number of its free slots, after the bag's icon: the item's (C_Item.GetItemIconByID)
-- for a bag, the game's own for the backpack and the keyring, none for the bank's own slots. Two or more bags of a window with the same name each
-- have their number after it ("Journeyman's Backpack · bag 3": bags 1 to 4 and the reagent bag 5, bank bags 1 to 8), so they can be told apart;
-- the backpack, the keyring and the bank's own slots keep their names. A click or a right click on the label of one of the player's own bags,
-- or a right click on its slot in the bag slot row (BagsSlots.lua, Layout.BagMenuOf) in either view, opens a
-- menu of Flat UI's own with what the game's bag menu sets, which is out of reach while Bags keeps the game's bag windows hidden (Mainline/
-- ContainerFrame.lua:643-711, 765-776): Assign To on bags 1 to 4 that are not special bags, with the six filters of the game's list (:2383-2390;
-- C_Container.GetBagSlotFlag and SetBagSlotFlag, WL/apis.yaml:8538, 8800; Enum.BagSlotFlags, WL/enums.yaml:579-590), and Ignore for clean up and
-- for junk selling, on the backpack through C_Container.GetBackpackAutosortDisabled, SetBackpackAutosortDisabled, GetBackpackSellJunkDisabled and
-- SetBackpackSellJunkDisabled (WL/apis.yaml:8520, 8781, 8525, 8786) and on the other bags through the flags DisableAutoSort and ExcludeJunkSell,
-- as the game's menu does it. Its words are the game's own global strings (BAG_FILTER_ASSIGN_TO, BAG_FILTER_IGNORE, BAG_FILTER_CLEANUP,
-- SELL_ALL_JUNK_ITEMS_EXCLUDE_FLAG and the six BAG_FILTER labels, ContainerFrame.lua:46-53, 648, 667, 686, 708), in English when the client has
-- none. A change asks for the junk coin and the Sell junk count again, since Errands follows these flags. Layout.BagFlags reads the same flags
-- for the tooltip of a bag's slot in that row.
-- The title of a section takes a drop. An item or a merchant's item on the cursor (GetCursorInfo, WL/apis.yaml:36258) let go or clicked on it is
-- the drop of that section's + slot (B.Custom.DropOn, BagsCustom.lua): an item of the bank or worn gear goes into a free slot of the bags and a
-- merchant's item is bought into one in the player's own live bag window, and a refusal says why in chat; an item of the bags (and every item in
-- the bank window) goes to B.Categories.Drop (Take), which keeps it in that section, puts it on Errands' sell list (on Junk), or takes a junk item
-- off that list and a grey one onto the keep list (on another section), and asks for the layout when it took the drop; either way the item goes
-- back to its slot (ClearCursor, :34956, which is not protected). While the part custom is stopped, Take alone takes an item and a merchant's item
-- goes back. Anything else on the cursor (a spell, a macro, money) makes a click on a title do nothing: no fold, menu or name box. That happens
-- out of combat only: in a fight the item only goes back, with one line. The
-- tooltip of the Junk title, in any window and for any character, also says what its items bring at a merchant: the sell price of each
-- (C_Item.GetItemInfo) times its count, "at least" while a price has not loaded. The top
-- shelf and Free slots take no drop, and their titles only give the item back. While the cursor holds an item the titles that would take it are
-- lit, and while it holds a merchant's item those that would buy it, read every tenth of a second while the window shows (Watch, also when the
-- item is swapped for another or a fight starts): B.Custom.Accepts says which, as the + slots light, so Junk stays unlit for a quest item, nothing
-- lights in a fight, and the tooltip of a title says why in red (B.Custom.HeldLine). A section of the player's own with a colour (B.Custom.Colour)
-- has its title's text and rule in it, its count still dim. A click on the top shelf's title puts its items away and lays the window out
-- again: in the bag window, while New items at the top is on, B.ClearNew (Bags.lua) first takes the game's new flags off the items of the bags,
-- as the window's close does, then B.Categories.New.Clear lets New items go.
-- A drop on Keep in place goes to B.Pins.Drop instead, which pins the slot the item came from; a drop on any other section that takes one reads
-- the item's slot first (B.Pins.Held) and, once B.Categories.Drop took it, calls B.Pins.Left, which unpins that slot when it was pinned for the
-- item. Each title of the Sections view but the top shelf's and Free slots' is registered for a drag with the left button when it is placed
-- (RegisterForDrag; every other title for none, so its clicks stay clicks), and its OnDragStart and OnDragStop go to B.Order (BagsOrder.lua), which
-- moves the section; a right click on such a title with no item on the cursor opens B.Order's menu of it, and its tooltip says how. A left click
-- on it with no item on the cursor, and not the end of a drop, folds the section or opens it again (B.Order.Fold, one set for the account, in both
-- windows), and such a title is lit under the cursor as a title that takes a click is. A folded section is laid out as its title alone, as the
-- empty Junk title is, with a + after its count; its items keep their cells, so a slot of it that changes while the window is open stays in it
-- and does not go to the top shelf, but no button is placed for them, so its title's tooltip lists them from their records (FoldedTip): each
-- item once with its icon, its name in its quality's colour and its stacks counted together, the most first, at most FOLD_LINES. While a search
-- is typed, Layout.Dim writes on every section's title, open or folded, how many of its items match ("3 of 24") in the Highlight colour, and its
-- count alone again once the search is cleared, with no layout: a folded title is measured for the widest of those texts, and an open one keeps
-- the width of its plain count and says the matches alone ("3") where "3 of 24" would not fit. A section with no match, or a bag's label in Bag
-- by bag, fades to 40% meanwhile (SetAlpha of its text and rule); the top shelf and Free slots keep theirs. A title still under the mouse after a
-- layout (a fold clicked, which keeps the window's height, BagsWindow.lua) draws its tooltip again, so it says what the next click does. A window
-- that closes ends a drag in it (B.Order.Cancel). These run as the parts order and pins of the module, so a fault of theirs stops them alone.
-- The + slot, the catcher and the flash are BagsCustom.lua's, as the part custom: each pass starts and ends them (B.Custom.Begin, Done) and places
-- them with each section (B.Custom.Place: the + slot's cell, and the rectangle of the section's cells for its catcher, a frame under the buttons
-- that takes the mouse only while the cursor holds an item or a merchant's item, in both windows); Watch tells it when the cursor comes to hold one,
-- swaps it or lets it go (B.Custom.Holding). A drop on either, or on a title, is Layout.Take unless BagsCustom first puts an item of the bank, worn
-- gear or a merchant in a free slot of the bags; when that item arrives Layout.Update lays the window out afresh (B.Custom.Arrived), so it shows in
-- its section. A section that took a drop flashes (B.Custom.Took). + New section takes a drop (B.Custom.DropNew), a click (B.Custom.AddClick, a
-- name box or the menu of the player's sections) and gives its tooltip line (B.Custom.AddTip, a refusal in red); the tooltip of Free slots says
-- what it counts. Layout.EntryOf gives the slot and record a button shows, for the line of an item's tooltip that says it is placed by hand or
-- pinned (BagsTooltip.lua).
-- The buttons are BagsItems.lua's: the game's item buttons for the player's own bags, buttons of Flat UI's own for the live bank and for
-- everything else. They are drawn with B.Buttons.Draw, dimmed with B.Buttons.Dim and placed here (ClearAllPoints, SetPoint, Show, Hide). While the
-- mouse points at a bag on the game's bag bar (Bags.lua) or in the bag slot row (BagsSlots.lua), Layout.Light dims every slot of the bag window
-- that is not in that bag, as the game's combined bag marks a bag's items, in the player's own live bags only, and a bank bag slot of the bank
-- window's row (BagsBank.lua) does the same in the live bank; an empty bag slot dims nothing. A click on a slot of the bag slot row keeps its bag
-- lit so (Layout.Stick) until it is clicked again, another is clicked, the bag leaves its slot (the next layout drops a stuck bag with no slots,
-- Layout.Build) or the window closes. A holder
-- of a bag's buttons (the frame whose ID is the bag, ContainerFrame.lua:1845-1851), or a button of Flat UI's own, that is not under the window's
-- content frame is put under it (SetParent, on frames of Flat UI's own only), so it takes the content's scale and scrolls with it. Before a live
-- button hides here, B.Buttons.Unsplit leaves the game's split box it may own to the game (BagsItems.lua), so the template's OnHide does not hide
-- the box in Flat UI's taint. Layout.Park puts a button the warm-up of BagsWindow.lua shows in an open window off the left of the screen for that
-- frame, and the next pass that shows it anchors it in its cell again.
-- The menus are frames of Flat UI's own on UIParent in the DIALOG strata, as the menu of Data panels is (DataPanels.lua:1306-1474): a press
-- anywhere else closes one (GLOBAL_MOUSE_DOWN, WL/events.yaml:5249, heard on a frame of its own only while a menu is open). A menu's lines go on in
-- further columns past 90% of the screen's height. Tooltips are GameTooltip (SetOwner, SetText, AddLine, Show, Hide). This file owns no event of
-- the module.

local B = ns.Bags
local Layout = B.Layout
local Window = B.Window
local Data = B.Data
local Categories = B.Categories
local Search = B.Search
local Buttons = B.Buttons
local Bank = B.Bank

-- The units of the content frame: the game's item button, the pitch of a cell and the space between two buttons; the gap between two sections, the
-- height of a title, and the room a title keeps after its text.
local SLOT, PITCH, SPACE = 37, 40, 3
local GAP, TITLE, TITLE_ROOM = 12, 16, 6
-- The smallest on-screen size of a title's text, and the size of the font the titles start from when the client does not say.
local LEAST_TEXT, BASE_TEXT = 9, 10
-- The padding of BagsWindow.lua on each side of the content, in the window's units, and the share of the screen's width a window may take.
local WINDOW_PAD, SCREEN_SHARE = 8, 0.95
-- How far off the left edge of the screen the warm-up of BagsWindow.lua puts a button it shows in an open window (Layout.Park).
local PARK = 200
-- The defaults of the rows this file reads, for a value the options do not give.
local DEFAULTS = { view = "sections", columns = 12, bankColumns = 16, slotSize = 36, freeSlots = "kinds", bank = "flat", gear = "one",
	consumables = "one", newItems = true, addSlots = true }
local NEW, FREE, OTHER, JUNK, KEEP = "new", "free", "other", "junk", "keep"
local KEYRING = -1
-- The bank's own slots, its first tab (Camelot/BankFrame.lua:301-327).
local BANK_SLOTS = 6
-- The icons of the backpack and the keyring on the game's bag bar (Camelot/MainMenuBarBagButtons.xml, bagIcon), for the labels of Bag by bag.
local BACKPACK_ICON, KEYRING_ICON = "Interface\\Icons\\ui-hud-actionbar-bag", "Interface\\Icons\\ui-hud-actionbar-keyring"
-- The top shelf of the bank window: what was put in while it is open.
local ADDED = "Added"
-- A section the order does not know comes after the ones it does.
local LATE = 1000
-- The text-dim of the windows (Threat.lua) for titles, a darker one for their counts, and a red for a bag with no room.
local DIM = { 0.66, 0.68, 0.62 }
-- The red of a refusal in a title's tooltip (BagsCustom.lua's).
local RED = { 1, 0.35, 0.24 }
local COUNT_HEX = "|cff7d8078"
local FULL_HEX = "|cffff5a3d"
-- How strongly a title that takes a drop is lit, and the same under the cursor; the faint line after a title's text; a title with no match of the
-- search (Layout.Dim).
local LIT, LIT_HOVER, RULE_ALPHA, TITLE_FADED = 0.14, 0.3, 0.16, 0.4
-- How often the cursor is read while a window shows, and how long after a drop a click on the same title is the same action.
local CURSOR_STEP, DROP_CLICK = 0.1, 0.3
-- The most items the tooltip of a folded title lists, and the size of their icons there.
local FOLD_LINES, FOLD_ICON = 12, 14
-- The key and the label of the title after the last section of the player's own bag window, which makes a section of the player's own
-- (BagsCustom.lua); and the free count Free slots writes in gold, as the footer does (BagsWindow.lua:145-146).
local ADD, ADD_LABEL = "+add", "New section"
local LOW, LOW_HEX = 4, "|cffffd100"
-- The tooltip of the Free slots title while the cursor holds no item.
local FREE_TIPS = {
	bags = "The room left in your backpack and normal bags, which every + slot draws on: an item from your bank or one you wear takes one. Trade "
		.. "bags, quivers, ammo pouches, soul bags, the reagent bag and the keyring take only certain items, so they are not counted.",
	bank = "The room left in your bank's own slots and normal bank bags. Special bags are not counted.",
}
-- The six filters of the game's bag menu, in its order (ContainerFrame.lua:2383-2390), with the flag's value in this client
-- (WL/enums.yaml:579-590), the game's word for it and the English one; and the two flags of Ignore.
local FILTERS = {
	{ "ClassEquipment", 2, "BAG_FILTER_EQUIPMENT", "Equipment" },
	{ "ClassConsumables", 4, "BAG_FILTER_CONSUMABLES", "Consumables" },
	{ "ClassProfessionGoods", 8, "BAG_FILTER_PROFESSION_GOODS", "Trade Goods" },
	{ "ClassJunk", 16, "BAG_FILTER_JUNK", "Junk" },
	{ "ClassQuestItems", 32, "BAG_FILTER_QUEST_ITEMS", "Quest Items" },
	{ "ClassReagents", 128, "BAG_FILTER_REAGENTS", "Reagents" },
}
local DISABLE_AUTO_SORT, EXCLUDE_JUNK_SELL = 1, 64
local FIGHT_LINE = "Flat UI: Bags: an item is put in a section out of combat only."

-- ns.IsSecret and ns.Finite of Core.lua, looked up when called.
local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

-- Per window ("bags", "bank"): what the last layout put where.
-- which, content: the window and its content frame. key, mine, live: the character shown, whether it is the logged-in one, and whether its slots
-- are live. view, columns, scale, sign: what the layout was made with. width, height: the content in its own units. textSize, titleH: the size of a
-- title's text and the height of a title. containers, rank, sizes, kinds: the containers shown, their order, their slots shown and their kinds.
-- sections: the sections or bag blocks in order; strip: the top shelf; free: Free slots. cells: the cell of each slot that has one, by slot key.
-- placed: the cell or free slot each button placed by the last pass shows, by button. where: where each button was put. titles: the title frames,
-- used: how many the last pass used. ruler: the font string titles are measured on. holding: the cursor held an item or a merchant's item at the
-- last reading; merchant: the second; heldId: its item ID or merchant index; fight: a fight was on then.
-- built: a layout stands; builds: how many times the window was laid out afresh (Layout.Builds). lit, stuck: the bag the mouse lights
-- (Layout.Light) and the one a click on its slot keeps lit (Layout.Stick).
local state = {}

local function Own(object)
	ns.Own[object] = true
	return object
end

-- A function of another part, looked up when it is called and never kept at load (the parts load in the order of the TOC).
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

-- Runs fn as a part of the module (B.Part, Bags.lua), so a part that keeps failing stops alone.
local function Run(part, fn, ...)
	local run = Fn(B, "Part")
	if run then
		return run(part, fn, ...)
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
	return ok
end

local function Opt(key)
	local value = Call(B, "Opt", key)
	if value == nil then
		return DEFAULTS[key]
	end
	return value
end

local function Request(flag, which)
	Call(B, "Request", flag, which)
end

-- A word of the game's global strings, or the English one when the client has none.
local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

-- Text that goes into a font string as it is: a bar would start a code of the client's.
local function Plain(text)
	return (tostring(text):gsub("|", "||"))
end

-- Red, green and blue of a colour row of the Windows page, the look Bags takes (B.Look).
local function LookRGB(key, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, "windows." .. key)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Fighting()
	local ok, fight = pcall(InCombatLockdown)
	return ok and not IsSecret(fight) and fight == true
end

-- The item ID on the cursor, or nil when it holds no item (a merchant's item too, whose index is not an item ID).
local function Holding()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" or not Finite(id) then
		return nil
	end
	return id
end

-- What the cursor holds, as GetCursorInfo names it ("item", "merchant", "spell", "macro", "money" and others), and the item ID or the merchant's
-- index that comes with it; "unknown" for a kind the client withholds, and nil for an empty cursor.
local function CursorKind()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok then
		return nil
	end
	if IsSecret(kind) then
		return "unknown"
	end
	if type(kind) ~= "string" then
		return nil
	end
	return kind, Finite(id) and id or nil
end

-- In a fight as BagsCustom.lua tells it (Errands.Fighting: the lockdown, or the player in combat), else the lockdown alone.
local function InFight()
	local errands = ns.Errands
	local fighting = type(errands) == "table" and errands.Fighting or nil
	if type(fighting) == "function" then
		local ok, fight = pcall(fighting)
		return not ok or fight == true
	end
	return Fighting()
end

-- The width a font string's text needs, whatever width it is given; 0 when the client does not say.
local function TextWidth(text)
	local ok, width = pcall(text.GetUnboundedStringWidth, text)
	if not (ok and Finite(width)) then
		ok, width = pcall(text.GetStringWidth, text)
	end
	return ok and Finite(width) and width or 0
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

-- Where a slot is kept in the tables of a layout: one number for a container and a slot.
local function SlotKey(bag, slot)
	return (bag + 100) * 1000 + slot
end

-- What a window shows ------------------------------------------------------------------------------------------------------------------------

-- The character a window shows, whether it is the logged-in one, and whether its slots are live: the player's own bags always are, and the bank is
-- while Flat UI's bank window is the live bank of a visit (B.Bank.Live, BagsBank.lua, the one test of it). That is decided as the visit starts, so
-- At the banker changed during a visit counts from the next one: a window that is live stays so until the visit ends.
function Layout.Viewed(which)
	local me = Call(B, "Me")
	local key = Call(B, "Viewing", which)
	if key == nil or key == me then
		key = me
	end
	local mine = key == me
	local live = mine
	if which == "bank" then
		live = mine and Call(Bank, "Live") == true
	end
	return key, mine, live
end

local function Scale()
	local size = Opt("slotSize")
	if not Finite(size) or size <= 0 then
		size = DEFAULTS.slotSize
	end
	return size / SLOT
end

-- The cells of a row: Width in slots (or Bank width in slots), but no more than fit in SCREEN_SHARE of the screen's width with the window's padding,
-- since a window wider than the screen would put its close button and its last cells out of reach. A change of the screen or of the UI scale lays
-- the windows out afresh (Bags.lua).
local function Columns(which)
	local value = which == "bank" and Opt("bankColumns") or Opt("columns")
	if not Finite(value) then
		value = which == "bank" and DEFAULTS.bankColumns or DEFAULTS.columns
	end
	local columns = math.max(1, math.floor(value + 0.5))
	local ok, screen = pcall(UIParent.GetWidth, UIParent)
	if ok and Finite(screen) and screen > 0 then
		local fit = math.floor(((screen * SCREEN_SHARE - 2 * WINDOW_PAD) / Scale() + SPACE) / PITCH)
		columns = math.min(columns, math.max(1, fit))
	end
	return columns
end

local function View()
	return Opt("view") == "bags" and "bags" or "sections"
end

-- What else a layout depends on: a change of any of these is a change of row, and lays the window out afresh.
local function Sign()
	return ("%s:%s:%s:%s:%s"):format(tostring(Opt("freeSlots")), tostring(Opt("gear")), tostring(Opt("consumables")), tostring(Opt("newItems")), tostring(Opt("addSlots")))
end

-- The containers of a window for a character, in order, as BagsData.lua gives them.
local function Containers(which, key)
	local list = Call(Data, "Containers", which, key)
	local out = {}
	if type(list) == "table" then
		for _, bag in ipairs(list) do
			if Finite(bag) then
				out[#out + 1] = bag
			end
		end
	end
	return out
end

-- The slots of a container and its kind ({ id, label, family, class, subclass, key, name }, BagsData.lua); 0 and nil when they are not known.
local function Size(key, bag)
	local slots, kind = Call(Data, "Size", key, bag)
	if not Finite(slots) or slots < 0 then
		slots = 0
	end
	return math.floor(slots), type(kind) == "table" and kind or nil
end

local function Item(key, bag, slot)
	local record = Call(Data, "Item", key, bag, slot)
	return type(record) == "table" and record or nil
end

local function KindField(kind, field)
	local value = type(kind) == "table" and kind[field] or nil
	if IsSecret(value) then
		return nil
	end
	return value
end

-- A kind's name for matching two kinds: BagsData's key, which groups the free slots of B.Data.Free ("bag" for every general bag, the backpack and
-- the bank's own slots included, "reagent", and one for each kind of special bag; "keyring" too, whose slots B.Data.Free leaves out); else its id,
-- else its label.
local function KindId(kind)
	if type(kind) == "table" then
		return KindField(kind, "key") or KindField(kind, "id") or KindField(kind, "label")
	end
	return kind
end

-- Whether a kind is of the general bags, which take any item and alone count as free space: BagsData's key "bag" (family 0). The keyring, the
-- reagent bag and the special bags take only certain items.
local function General(kind)
	return KindField(kind, "key") == "bag"
end

-- How many keyring slots the game's own keyring window would show: the last filled slot rounded up to four, and four more once every slot up to it
-- is filled, never more than the keyring has (GetKeyRingSize, Camelot/MainMenuBarBagButtons.lua:64-92).
local function KeyringShown(key, slots)
	local last, items = 0, 0
	for slot = 1, slots do
		if Item(key, KEYRING, slot) then
			last, items = slot, items + 1
		end
	end
	local modulo = last % 4
	local size
	if modulo == 0 and items < last then
		size = last
	else
		size = last + (4 - modulo)
	end
	return math.min(size, slots)
end

-- The display order of the sections: the player's (B.Order.Ranks, BagsOrder.lua), else the built-in list (B.Categories.LIST).
local function Orders()
	local ranks = Fn(B.Order, "Ranks")
	if ranks then
		local ok, map = pcall(ranks)
		if ok and type(map) == "table" then
			return map
		end
	end
	local map = {}
	local list = Categories.LIST
	if type(list) == "table" then
		for index, entry in ipairs(list) do
			if type(entry) == "table" and type(entry.key) == "string" then
				map[entry.key] = Finite(entry.order) and entry.order or index
			end
		end
	end
	return map
end

local function Label(key)
	local label = Call(Categories, "Label", key)
	if type(label) ~= "string" or IsSecret(label) or label == "" then
		return key
	end
	return label
end

local function SectionOf(record)
	local key = Call(Categories, "Of", record)
	if type(key) ~= "string" or IsSecret(key) then
		return OTHER
	end
	return key
end

-- New items is told which of its items this opening showed, so they leave when the window closes (B.Categories.New).
local function ShownNew(record)
	if Call(Categories.New, "Is", record) == true then
		Call(Categories.New, "Shown", record)
	end
end

-- Sorts the cells of a section by B.Categories.Compare; when it raises, and with plain (Keep in place), by bag and slot, so equal items never swap.
local function SortEntries(st, entries, plain)
	local compare = not plain and Fn(Categories, "Compare")
	if compare and pcall(table.sort, entries, function(a, b)
		return compare(a.record, b.record) == true
	end) then
		return
	end
	table.sort(entries, function(a, b)
		local ra, rb = st.rank[a.bag] or 0, st.rank[b.bag] or 0
		if ra ~= rb then
			return ra < rb
		end
		return a.slot < b.slot
	end)
end

-- Titles ------------------------------------------------------------------------------------------------------------------------------------------

local Drop, TitleClick

-- The size of the text of a title in the content's units: the size of the game's small font, or more where Slot size would put it under
-- LEAST_TEXT on the screen.
local function TextSize(scale)
	local base = BASE_TEXT
	local font = _G.GameFontNormalSmall
	if type(font) == "table" and not IsSecret(font) then
		local ok, _, size = pcall(font.GetFont, font)
		if ok and Finite(size) and size > 0 then
			base = size
		end
	end
	return math.max(base, LEAST_TEXT / scale)
end

-- The face and outline of the game's small font as they are now, or nil while the client does not say.
local function SmallFont()
	local font = _G.GameFontNormalSmall
	if type(font) ~= "table" or IsSecret(font) then
		return nil
	end
	local ok, file, _, flags = pcall(font.GetFont, font)
	if not ok or type(file) ~= "string" or IsSecret(file) or file == "" then
		return nil
	end
	return file, (type(flags) == "string" and not IsSecret(flags)) and flags or ""
end

-- Gives a title's text, or the ruler, the face and outline the game's small font has now at size, once for each change of any of the three: a font
-- string given a font of its own no longer follows its font object, so a change that Flat UI's Fonts page makes to GameFontNormalSmall reaches it
-- only through this, at its next drawing. While the client does not say the small font's face, the font string keeps its own.
local function SetSize(text, size)
	local file, flags = SmallFont()
	if not file then
		local ok, own, _, ownFlags = pcall(text.GetFont, text)
		if not ok or type(own) ~= "string" or IsSecret(own) then
			return
		end
		file, flags = own, (type(ownFlags) == "string" and not IsSecret(ownFlags)) and ownFlags or ""
	end
	local key = file .. "|" .. flags .. "|" .. size
	if text.flatKey == key then
		return
	end
	if pcall(text.SetFont, text, file, size, flags) then
		text.flatKey = key
	end
end

-- True for a section whose title takes a drop: in the sections of the player's own bags or bank, every section but the top shelf and Free slots
-- (and + New section, whose drop makes a section, BagsCustom.lua).
local function Takes(st, sec)
	return st.view == "sections" and st.mine and not sec.block and not sec.strip and sec.key ~= FREE and not sec.add
end

-- True for a section that ends in a + slot (BagsCustom.lua): with Drop slot in each section on, in the player's own live bag window, every open
-- section whose title takes a drop.
local function Plus(st, sec)
	return Opt("addSlots") ~= false and st.which == "bags" and st.mine and st.live and not sec.add and not sec.folded and Takes(st, sec)
end

-- True while a title is lit for what the cursor holds: one that takes a drop, or + New section, when BagsCustom says it takes the item
-- (B.Custom.Accepts: only what that section would take, as its + slot, and nothing in a fight). A merchant's item lights only where it says so;
-- while it cannot tell (its part stopped) an item lights every such title.
local function Lit(st, sec)
	if not st.holding or not (Takes(st, sec) or sec.add) then
		return false
	end
	local ok, accepts = pcall(Call, B.Custom, "Accepts", st, sec)
	if not ok then
		accepts = nil
	end
	if st.merchant then
		return accepts == true
	end
	return accepts ~= false
end

-- The colour a section of the player's own was given from its title's menu (B.Custom.Colour), or nil.
local function OwnColour(sec)
	if sec.block or sec.add or sec.strip then
		return nil
	end
	local ok, r, g, b = pcall(Call, B.Custom, "Colour", sec.key)
	if ok and Finite(r) and Finite(g) and Finite(b) then
		return r, g, b
	end
	return nil
end

local function PaintTitle(title)
	local st, sec = title.st, title.sec
	if not (st and sec) then
		return
	end
	local r, g, b = LookRGB("accent", 0.85, 0.85, 0.85)
	local cr, cg, cb = OwnColour(sec)
	if sec.strip then
		title.text:SetTextColor(r, g, b, 1)
	elseif cr then
		-- The label in its colour; the count keeps its own darker code (TitleText).
		title.text:SetTextColor(cr, cg, cb, 1)
	else
		title.text:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
	if cr then
		title.rule:SetColorTexture(cr, cg, cb, RULE_ALPHA)
	else
		title.rule:SetColorTexture(DIM[1], DIM[2], DIM[3], RULE_ALPHA)
	end
	if Lit(st, sec) then
		title.back:SetColorTexture(r, g, b, title.over and LIT_HOVER or LIT)
		title.back:Show()
	elseif title.over and title.clickable then
		title.back:SetColorTexture(r, g, b, LIT)
		title.back:Show()
	else
		title.back:Hide()
	end
end

-- An amount of copper as the game writes money (Errands.Money), else in gold alone.
local function Money(copper)
	local errands = ns.Errands
	if type(errands) == "table" and type(errands.Money) == "function" then
		return errands.Money(copper)
	end
	return ("%dg"):format(math.floor(copper / 10000))
end

-- What the items of a section bring at a merchant, in copper: the sell price C_Item.GetItemInfo gives each (its 11th answer) times its count; and
-- true when the price of one has not loaded, so the worth is at least that.
local function Worth(sec)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return 0, true
	end
	local value, unknown = 0, false
	for _, entry in ipairs(sec.entries) do
		local record = entry.record
		local item = record and ((type(record.link) == "string" and not IsSecret(record.link)) and record.link or record.id)
		if item then
			local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, item)
			local count = Finite(record.count) and record.count > 0 and record.count or 1
			if ok and not IsSecret(name) and name ~= nil and Finite(price) and price >= 0 then
				value = value + price * count
			else
				unknown = true
			end
		end
	end
	return value, unknown
end

-- What a folded section holds, under its title's tooltip: one line per item, its icon and its name (the record's link, in its quality's colour,
-- else its name in that colour), and the counts of its stacks added up at the right, the most first, then by name; at most FOLD_LINES, then how
-- many more. From the records alone, so in either window, for any character and in a fight.
local function FoldedTip(tip, sec)
	local byId, list = {}, {}
	for _, entry in ipairs(sec.entries) do
		local record = entry.record
		local id = record and record.id
		if Finite(id) then
			local item = byId[id]
			if not item then
				local link, name = record.link, record.name
				item = { id = id, count = 0, icon = record.icon, quality = record.quality,
					link = type(link) == "string" and not IsSecret(link) and link:find("|H", 1, true) and link or nil,
					name = type(name) == "string" and not IsSecret(name) and name ~= "" and name or nil }
				byId[id] = item
				list[#list + 1] = item
			end
			local count = record.count
			item.count = item.count + ((Finite(count) and count >= 1) and math.floor(count) or 1)
		end
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return (a.name or "") < (b.name or "")
	end)
	local colour = type(C_Item) == "table" and C_Item.GetItemQualityColor or nil
	for index = 1, math.min(#list, FOLD_LINES) do
		local item = list[index]
		local icon = item.icon
		icon = (Finite(icon) or (type(icon) == "string" and not IsSecret(icon) and icon ~= ""))
			and ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t "):format(tostring(icon), FOLD_ICON, FOLD_ICON) or ""
		local r, g, b = 1, 1, 1
		if not item.link and Finite(item.quality) and type(colour) == "function" then
			local ok, qr, qg, qb = pcall(colour, item.quality)
			if ok and Finite(qr) and Finite(qg) and Finite(qb) then
				r, g, b = qr, qg, qb
			end
		end
		local name = item.link or Plain(item.name or ("Item %d"):format(item.id))
		tip:AddDoubleLine(icon .. name, item.count > 1 and ("x" .. item.count) or " ", r, g, b, DIM[1], DIM[2], DIM[3])
	end
	if #list > FOLD_LINES then
		tip:AddLine(("and %d more"):format(#list - FOLD_LINES), DIM[1], DIM[2], DIM[3])
	end
end

local function TitleTip(title)
	local st, sec = title.st, title.sec
	local tip = GameTooltip
	if not (st and sec) or type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local head, line, worth, folded, refused
	if sec.block then
		if not title.clickable then
			return
		end
		head, line = sec.name, "Click or right-click for this bag's settings, as the game's bag menu has them."
	elseif sec.add then
		-- + New section (BagsCustom.lua), its refusal in red.
		local ok, text, no = pcall(Call, B.Custom, "AddTip", st)
		if not (ok and type(text) == "string") then
			return
		end
		head, line, refused = sec.label, text, no == true
	elseif sec.key == FREE and not st.holding then
		head, line = sec.label, FREE_TIPS[st.which] or FREE_TIPS.bags
	elseif st.holding and Takes(st, sec) then
		head = sec.label
		-- What the section's + slot says of the item (BagsCustom.lua): moved in, bought, kept, or why not, in red; these lines while it cannot tell.
		local ok, text, no = pcall(Call, B.Custom, "HeldLine", st, sec)
		if ok and type(text) == "string" then
			line, refused = text, no == true
		elseif st.merchant then
			line, refused = "Buy the item into your bags first, then drop it here.", true
		elseif sec.key == JUNK then
			line = "Drop the item here to sell it at merchants from now on."
		elseif sec.key == KEEP then
			line = "Drop the item here to pin the slot it came from to it."
		else
			line = ("Drop the item here to keep it in %s."):format(sec.label)
		end
	elseif sec.key == JUNK and #sec.entries == 0 and Takes(st, sec) then
		head, line = sec.label, "Nothing to sell. Drop an item here to sell it at merchants from now on."
	elseif sec.strip and not st.holding then
		head, line = sec.label, "Click to put these items away now."
	elseif not st.holding then
		-- How to move the section, or what Keep in place is (BagsOrder.lua).
		local tipOf = Fn(B.Order, "Tip")
		local ok, text = false, nil
		if tipOf then
			ok, text = pcall(tipOf, st, sec)
		end
		if not (ok and type(text) == "string") then
			return
		end
		head, line = sec.label, text
		-- A folded section lists what it holds, since none of it shows.
		folded = sec.folded and #sec.entries > 0
		-- What the junk brings, in any window and for any character, though only the player's own bags can sell it.
		if sec.key == JUNK and #sec.entries > 0 then
			local value, unknown = Worth(sec)
			if value > 0 then
				worth = (unknown and "Worth at least %s at a merchant." or "Worth %s at a merchant."):format(Money(value))
			end
		end
	else
		return
	end
	tip:SetOwner(title.frame, "ANCHOR_TOP")
	tip:SetText(head, 1, 1, 1)
	if worth then
		tip:AddLine(worth, 1, 1, 1, true)
	end
	if folded then
		FoldedTip(tip, sec)
	end
	local colour = refused and RED or DIM
	tip:AddLine(line, colour[1], colour[2], colour[3], true)
	tip:Show()
end

-- Title number index of a window, made the first time a layout needs it: a button of Flat UI's own with the text, a faint line after it, and the
-- light it takes while it can take a drop.
local function Title(st, index)
	local title = st.titles[index]
	if title then
		return title
	end
	local frame = Own(CreateFrame("Button", nil, st.content))
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	title = { frame = frame }
	title.back = Own(frame:CreateTexture(nil, "BACKGROUND"))
	title.back:SetAllPoints(frame)
	title.back:Hide()
	title.text = ns.OwnText(frame, "OVERLAY", "GameFontNormalSmall")
	title.text:SetPoint("LEFT", frame, "LEFT", 1, 0)
	title.text:SetJustifyH("LEFT")
	title.text:SetWordWrap(false)
	title.rule = Own(frame:CreateTexture(nil, "ARTWORK"))
	title.rule:Hide()
	frame:SetScript("OnClick", function(_, mouse)
		Run("layout", TitleClick, title, mouse)
	end)
	frame:SetScript("OnReceiveDrag", function()
		Run("layout", Drop, title)
	end)
	-- A drag of the title moves its section (BagsOrder.lua). PlaceTitle registers for a drag only a title whose section can move, since a drag
	-- gives no click: a click on any other title that moves a little stays a click.
	frame:SetScript("OnDragStart", function()
		Run("order", Call, B.Order, "DragStart", title)
	end)
	frame:SetScript("OnDragStop", function()
		Run("order", Call, B.Order, "DragStop", title)
	end)
	frame:SetScript("OnEnter", function()
		title.over = true
		Run("layout", PaintTitle, title)
		Run("layout", TitleTip, title)
	end)
	frame:SetScript("OnLeave", function()
		title.over = false
		Run("layout", PaintTitle, title)
		Untip(frame)
	end)
	st.titles[index] = title
	return title
end

-- The Highlight colour of the Windows page as a colour code of the client's.
local function AccentHex()
	local r, g, b = LookRGB("accent", 0.85, 0.85, 0.85)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

-- The text of a title: a section's label and how many items it holds, or a bag's name (after its icon, BagIcon) and how many of its slots are
-- free, the count darker. A folded section has a + after its count. While a search is typed (sec.matches, Layout.Dim) a section's title says how
-- many of its items match, "3 of 24", in the Highlight colour, open or folded; with short, an open one says "3" alone (WriteTitle, where the
-- longer text would not fit). With widest, a folded title's text as wide as it can get with that count ("24 of 24"), which it is measured by, so
-- the text that the search writes later fits its title; an open title is measured by its plain count, so its section keeps its width.
local function TitleText(sec, widest, short)
	if sec.block then
		local count = sec.full and (FULL_HEX .. "full|r") or (COUNT_HEX .. (sec.freeCount or 0) .. " free|r")
		return (sec.icon or "") .. Plain(sec.name) .. "  " .. count
	end
	if sec.add then
		return AccentHex() .. "+|r " .. Plain(sec.label)
	end
	-- Free slots: how many of the general bags' slots are free of how many, gold at LOW or fewer, and the whole title red with none left.
	if sec.key == FREE then
		local free, total = sec.count or 0, sec.total or 0
		if total <= 0 then
			return Plain(sec.label) .. "  " .. COUNT_HEX .. free .. "|r"
		end
		if free <= 0 then
			return ("%s%s  0 of %d|r"):format(FULL_HEX, Plain(sec.label), total)
		end
		return ("%s  %s%d of %d|r"):format(Plain(sec.label), free <= LOW and LOW_HEX or COUNT_HEX, free, total)
	end
	local count = sec.count or #sec.entries
	if not sec.folded then
		if not widest and Finite(sec.matches) then
			if short then
				return ("%s  %s%d|r"):format(Plain(sec.label), AccentHex(), sec.matches)
			end
			return ("%s  %s%d of %d|r"):format(Plain(sec.label), AccentHex(), sec.matches, count)
		end
		return Plain(sec.label) .. "  " .. COUNT_HEX .. count .. "|r"
	end
	local matches = widest and count or sec.matches
	if Finite(matches) then
		return ("%s  %s%d of %d|r  %s+|r"):format(Plain(sec.label), AccentHex(), matches, count, COUNT_HEX)
	end
	return ("%s  %s%d|r  %s+|r"):format(Plain(sec.label), COUNT_HEX, count, COUNT_HEX)
end

-- The width a title's text needs, in the content's units: measured on a font string of Flat UI's own in the titles' font, else guessed from its
-- length.
local function Measure(st, text)
	local ruler = st.ruler
	if not ruler then
		-- Shown at no opacity rather than hidden, so the client lays its text out.
		ruler = ns.OwnText(st.content, "OVERLAY", "GameFontNormalSmall")
		ruler:SetPoint("TOPLEFT", st.content, "TOPLEFT", 0, 0)
		ruler:SetWordWrap(false)
		ruler:SetAlpha(0)
		st.ruler = ruler
	end
	SetSize(ruler, st.textSize)
	ruler:SetText(text)
	local width = TextWidth(ruler)
	if width > 0 then
		return width
	end
	return #text * st.textSize * 0.5
end

-- Cells and buttons -------------------------------------------------------------------------------------------------------------------------------

local function Entry(bag, slot, record)
	return { bag = bag, slot = slot, sk = SlotKey(bag, slot), record = record, dirty = true }
end

-- True when frame is of, or one of the frames that hold of: such a frame never goes under it.
local function Holds(frame, of)
	local current, depth = of, 0
	while type(current) == "table" and not IsSecret(current) and depth < 12 do
		if current == frame then
			return true
		end
		local ok, up = pcall(current.GetParent, current)
		if not ok then
			return false
		end
		current, depth = up, depth + 1
	end
	return false
end

local function Ours(frame)
	return type(frame) == "table" and not IsSecret(frame) and ns.Own[frame] == true
end

-- Puts a button under the content frame, so it takes the content's scale and scrolls with it. A live button stays in its holder, which gives the
-- game's template its bag (ContainerFrame.lua:1845-1851): the holder goes under the content. Only frames of Flat UI's own are moved.
local function Adopt(st, button, kind, bag)
	local ok, parent = pcall(button.GetParent, button)
	if not ok or IsSecret(parent) or parent == st.content then
		return
	end
	if kind ~= "offline" and Ours(parent) and not Holds(parent, st.content) then
		local okId, id = pcall(parent.GetID, parent)
		if okId and not IsSecret(id) and id == bag then
			local okUp, up = pcall(parent.GetParent, parent)
			if okUp and not IsSecret(up) and up ~= st.content then
				parent:SetParent(st.content)
			end
			if not parent:IsShown() then
				parent:Show()
			end
			return
		end
	end
	if Ours(button) and kind ~= "live" then
		button:SetParent(st.content)
	end
end

-- The button a cell shows. Live bags: the game's item button of that slot (or, in the rare fight that found it missing, a button of Flat UI's own
-- until the fight ends). Live bank: Flat UI's bank button of that slot. Anything else: a pooled button of Flat UI's own for this window.
local function Resolve(st, entry)
	local button, kind
	if st.live and st.which == "bags" then
		button, kind = Call(Buttons, "Live", entry.bag, entry.slot), "live"
	elseif st.live then
		button, kind = Call(Buttons, "Bank", entry.bag, entry.slot), "bank"
	end
	if type(button) ~= "table" then
		button = entry.offline
		if not button then
			button = Call(Buttons, "Offline", st.content)
			if type(button) ~= "table" then
				return nil
			end
			entry.offline = button
		end
		kind = "offline"
	elseif entry.offline then
		-- The button that stood in for a live one goes back to the pool with the window's others.
		entry.offline:Hide()
		entry.offline = nil
	end
	if entry.kind ~= kind or entry.button ~= button then
		entry.kind, entry.button = kind, button
		entry.dirty = true
		Adopt(st, button, kind, entry.bag)
	end
	return button
end

-- What B.Buttons.Draw is told besides the record: a counted free slot, a free slot and its kind, an empty slot of a bag (its kind tints it), or a
-- slot that emptied while the window is open and keeps its cell.
local function DrawOpts(st, entry)
	if entry.free then
		return { free = entry.free, kind = entry.kindTable }
	elseif entry.record then
		return nil
	elseif entry.ghost then
		-- An empty pinned slot in Keep in place: blank, and B.Pins.Mark draws the pinned item's icon faded.
		return { hold = true, kind = st.kinds[entry.bag] }
	elseif entry.freeSlot then
		return { kind = entry.kindTable }
	elseif st.view == "bags" then
		return { kind = st.kinds[entry.bag] }
	end
	return { hold = true }
end

local function Place(st, button, x, y)
	local spot = st.where[button]
	if not spot or spot[1] ~= x or spot[2] ~= y then
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", st.content, "TOPLEFT", x, y)
		st.where[button] = { x, y }
	end
	if not button:IsShown() then
		button:Show()
	end
end

-- Hides a button the layout shows no longer. A live button that owns the game's split box leaves it to the game first (B.Buttons.Unsplit,
-- BagsItems.lua), so the template's OnHide does not hide the box in this addon's taint.
local function Hide(button)
	Call(Buttons, "Unsplit", button)
	button:Hide()
end

local function Draw(st, entry, button)
	if entry.dirty or entry.drawnOn ~= button then
		Call(Buttons, "Draw", button, entry.record, DrawOpts(st, entry))
		entry.dirty, entry.drawnOn = false, button
	end
end

-- The faint rule after a title's text, in the room the text leaves of the title's width, or none where too little is left.
local function PlaceRule(title, width)
	local frame = title.frame
	local textWidth = TextWidth(title.text)
	if textWidth <= 0 then
		textWidth = title.sec and title.sec.titleWidth or width
	end
	textWidth = math.min(textWidth, width)
	local room = width - textWidth - 6
	if room >= 8 then
		title.rule:ClearAllPoints()
		title.rule:SetPoint("LEFT", frame, "LEFT", textWidth + 5, 0)
		title.rule:SetSize(room - 1, ns.Pixels(frame, 1))
		title.rule:Show()
	else
		title.rule:Hide()
	end
end

-- Writes a title's text (TitleText) and places its rule. An open section's "3 of 24" that would not fit the width its title has (measured for
-- its plain count) says "3" alone, so nothing is laid out again.
local function WriteTitle(title, sec)
	local width = title.width or 0
	title.text:SetText(TitleText(sec))
	if not sec.block and not sec.folded and Finite(sec.matches) and TextWidth(title.text) > width - TITLE_ROOM then
		title.text:SetText(TitleText(sec, false, true))
	end
	PlaceRule(title, width)
end

local function PlaceTitle(st, title, sec, x, y, width)
	title.st, title.sec, title.width = st, sec, width
	-- The left button drags the title of a section of the Sections view that can move (BagsOrder.lua): not the top shelf, Free slots or a bag. A
	-- click on such a title folds its section or opens it, so it is lit under the cursor as the top shelf's title and a bag's label are.
	local drags = st.view == "sections" and not sec.block and not sec.strip and sec.key ~= FREE and sec.key ~= NEW and not sec.add
	if sec.block then
		title.clickable = st.mine and st.live and st.which == "bags" and sec.bag ~= KEYRING
	else
		title.clickable = sec.strip == true or sec.add == true or drags
	end
	SetSize(title.text, st.textSize)
	title.text:SetWidth(math.max(1, width - 1))
	local frame = title.frame
	if title.drags ~= drags then
		title.drags = drags
		if drags then
			pcall(frame.RegisterForDrag, frame, "LeftButton")
		else
			pcall(frame.RegisterForDrag, frame)
		end
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", st.content, "TOPLEFT", x, y)
	frame:SetSize(width, st.titleH)
	WriteTitle(title, sec)
	PaintTitle(title)
	frame:Show()
	-- The title under the mouse after a fold or an unfold, or any other layout, keeps its tooltip, drawn again with what it says now ("Folded: click
	-- to open it." and what the section holds).
	if title.over and type(GameTooltip) == "table" and not ns.Forbidden(GameTooltip) then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, frame)
		if ok and not ns.IsSecret(owned) and owned == true then
			Run("layout", TitleTip, title)
		end
	end
end

-- The height of a section of n cells, w wide, under its title; a section of no cell (the empty Junk of the bag window with Drop slot in each
-- section off, a folded section, + New section) is its title alone.
local function Height(st, n, w)
	if n <= 0 then
		return st.titleH
	end
	return st.titleH + math.ceil(n / w) * PITCH - SPACE
end

-- Places one section: its title at x, y and its cells in rows of w below it. A folded section is its title alone: its cells stay in the layout's
-- cells, so a slot of it that changes keeps its place there, but no button is placed for them, and the pass hides the ones it showed. A section
-- that ends in a + slot (sec.plus) has it in the cell after its last, and a section whose title takes a drop has a catcher over its cells; both
-- are BagsCustom.lua's (B.Custom.Place), which also flashes the section that took the last drop.
local function PlaceSection(st, sec, x, y)
	st.used = st.used + 1
	local title = Title(st, st.used)
	PlaceTitle(st, title, sec, x, y, sec.w * PITCH - SPACE)
	if sec.folded then
		if not sec.block then
			Run("custom", Call, B.Custom, "Place", st, sec, title)
		end
		return
	end
	local w = sec.w
	for index, entry in ipairs(sec.entries) do
		local button = Resolve(st, entry)
		if button then
			local col, row = (index - 1) % w, math.floor((index - 1) / w)
			Place(st, button, x + col * PITCH, y - st.titleH - row * PITCH)
			Draw(st, entry, button)
			st.placed[button] = entry
		end
	end
	if sec.block then
		return
	end
	local n = #sec.entries
	local px, py
	if sec.plus then
		px, py = x + (n % w) * PITCH, y - st.titleH - math.floor(n / w) * PITCH
		n = n + 1
	end
	if n > 0 and Takes(st, sec) then
		Run("custom", Call, B.Custom, "Place", st, sec, title, px, py, x, y - st.titleH, w * PITCH - SPACE, math.ceil(n / w) * PITCH - SPACE)
	else
		Run("custom", Call, B.Custom, "Place", st, sec, title)
	end
end

-- Free slots ------------------------------------------------------------------------------------------------------------------------------------

-- A free slot of a kind that has no cell, for the counted slot of that kind when its first free slot is a cell kept blank.
local function Unheld(st, kind)
	local id = KindId(kind)
	for _, bag in ipairs(st.containers) do
		if KindId(st.kinds[bag]) == id then
			for slot = 1, st.sizes[bag] do
				if not st.cells[SlotKey(bag, slot)] and not Item(st.key, bag, slot) then
					return bag, slot
				end
			end
		end
	end
	return nil
end

-- Free slots as they are now: one counted slot per kind of bag (B.Data.Free), a special kind's only in the player's own live bags or bank, where a
-- drop on it puts the item there; or every free slot of the general bags that has no cell, in the order of the bags. The title counts the
-- general bags' free slots alone, of all their slots (count and total, the general row of B.Data.Free, in either choice), and the keyring's slots
-- show in neither; the + slots read that count (BagsCustom.lua). With bags that are full, Free slots is its title alone. A slot shown the same
-- way as before keeps its drawing.
local function MakeFree(st)
	if st.view ~= "sections" then
		st.free = nil
		return
	end
	local sec = { key = FREE, label = Label(FREE), entries = {}, count = 0, total = 0 }
	local list = Call(Data, "Free", st.key, st.which)
	list = type(list) == "table" and list or {}
	for _, kind in ipairs(list) do
		if type(kind) == "table" and kind.general == true then
			sec.count = Finite(kind.free) and math.max(0, math.floor(kind.free)) or 0
			sec.total = Finite(kind.total) and math.max(0, math.floor(kind.total)) or 0
			break
		end
	end
	if Opt("freeSlots") == "all" then
		for _, bag in ipairs(st.containers) do
			for slot = 1, General(st.kinds[bag]) and st.sizes[bag] or 0 do
				if not st.cells[SlotKey(bag, slot)] and not Item(st.key, bag, slot) then
					local entry = Entry(bag, slot, nil)
					entry.freeSlot, entry.kindTable = true, st.kinds[bag]
					sec.entries[#sec.entries + 1] = entry
				end
			end
		end
	else
		for _, kind in ipairs(list) do
			local free = type(kind) == "table" and kind.free or nil
			local general = type(kind) == "table" and kind.general == true
			if Finite(free) and free > 0 and (general or (st.mine and st.live)) then
				local bag, slot = kind.bag, kind.slot
				if not (Finite(bag) and Finite(slot) and st.sizes[bag] and slot >= 1 and slot <= st.sizes[bag]) or st.cells[SlotKey(bag, slot)] then
					bag, slot = Unheld(st, kind.kind)
				end
				if bag and slot then
					local entry = Entry(bag, slot, nil)
					entry.free = math.floor(free)
					entry.kindTable = type(kind.kind) == "table" and kind.kind or st.kinds[bag]
					sec.entries[#sec.entries + 1] = entry
				end
			end
		end
	end
	local old = st.free
	if old then
		local before = {}
		for _, entry in ipairs(old.entries) do
			before[entry.sk] = entry
		end
		for index, entry in ipairs(sec.entries) do
			local was = before[entry.sk]
			if was and was.free == entry.free and was.freeSlot == entry.freeSlot then
				sec.entries[index] = was
			end
		end
	end
	if #sec.entries == 0 and sec.total <= 0 then
		st.free = nil
		return
	end
	sec.titleWidth = Measure(st, TitleText(sec))
	st.free = sec
end

-- Building a layout -------------------------------------------------------------------------------------------------------------------------------

local function State(which)
	local st = state[which]
	if not st then
		st = { which = which, titles = {}, where = {}, placed = {}, cells = {}, sections = {}, used = 0 }
		state[which] = st
	end
	if not st.content then
		local frame = Call(Window, "Get", which)
		st.content = type(frame) == "table" and frame.content or nil
	end
	return st
end

-- Reads the containers of the character shown, with the slots each shows and its kind.
local function Gather(st)
	st.containers = Containers(st.which, st.key)
	st.rank, st.sizes, st.kinds = {}, {}, {}
	for index, bag in ipairs(st.containers) do
		st.rank[bag] = index
		local slots, kind = Size(st.key, bag)
		if bag == KEYRING then
			slots = KeyringShown(st.key, slots)
		end
		st.sizes[bag], st.kinds[bag] = slots, kind
	end
end

-- Shelf packing, the same for sections and bag blocks: each is w cells wide, between as many cells as it has (or its title needs) and the width of
-- the window, and they go left to right while they fit.
local function Pack(st)
	local width = st.columns * PITCH - SPACE
	local x, y, shelf = 0, 0, 0
	for _, sec in ipairs(st.sections) do
		-- A folded section is as wide as its title and no taller (BagsOrder.lua).
		local n = sec.folded and 0 or (#sec.entries + (sec.plus and 1 or 0))
		local need = math.ceil(((sec.titleWidth or 0) + TITLE_ROOM) / PITCH)
		local w = math.min(st.columns, math.max(n, need, 1))
		local size = w * PITCH - SPACE
		if x > 0 and x + size > width then
			y = y - shelf - GAP
			x, shelf = 0, 0
		end
		sec.x, sec.y, sec.w = x, y, w
		sec.height = Height(st, n, w)
		shelf = math.max(shelf, sec.height)
		x = x + size + GAP
	end
end

local function NewStrip(st)
	return { key = NEW, label = st.which == "bank" and ADDED or Label(NEW), entries = {}, strip = true }
end

-- The title of the top shelf: New items in the bag window while New items at the top is on and every item on the shelf is new
-- (B.Categories.New.Is), else Added, as the bank window's always is. What fills a slot that had no cell while the window is open goes there, new or
-- not: an item taken out of the bank, gear taken off, an item put in a free slot, and with the row off everything.
local function StripLabel(st, sec)
	local new = st.which == "bags" and Opt("newItems") ~= false
	if new then
		for _, entry in ipairs(sec.entries) do
			if entry.record and Call(Categories.New, "Is", entry.record) ~= true then
				new = false
				break
			end
		end
	end
	return new and Label(NEW) or ADDED
end

local function BuildSections(st)
	local orders = Orders()
	local byKey, list = {}, {}
	local strip = NewStrip(st)
	-- The pins of the player's own live bags (B.Pins.Get, BagsPins.lua): an empty pinned slot keeps a cell in Keep in place.
	local pinned = st.which == "bags" and st.live and Fn(B.Pins, "Get") or nil
	for _, bag in ipairs(st.containers) do
		for slot = 1, st.sizes[bag] do
			local record = Item(st.key, bag, slot)
			local ghost = nil
			if not record and pinned then
				local ok, id = pcall(pinned, bag, slot)
				ghost = ok and Finite(id) and id or nil
			end
			if record or ghost then
				local entry = Entry(bag, slot, record)
				entry.ghost = ghost
				local key = record and SectionOf(record) or KEEP
				local sec
				if key == NEW then
					sec = strip
				else
					sec = byKey[key]
					if not sec then
						sec = { key = key, label = Label(key), entries = {} }
						byKey[key] = sec
						list[#list + 1] = sec
					end
				end
				sec.entries[#sec.entries + 1] = entry
			end
		end
	end
	-- The player's own bag window always has a Junk title, with no cell while nothing is junk, so an item can be dropped on it to go on Errands'
	-- sell list also right after the junk was sold. It comes in the order of B.Categories.LIST, just before Free slots.
	if st.which == "bags" and st.mine and not byKey[JUNK] then
		local junk = { key = JUNK, label = Label(JUNK), entries = {} }
		byKey[JUNK] = junk
		list[#list + 1] = junk
	end
	-- While this character has a pin (B.Pins.Any), its live bag window always has the title of Keep in place too, with no cell while no pinned
	-- slot holds its item, so its menu (Put pinned items back now, Unpin all) and its drop stay in reach.
	local okAny, anyPin = pcall(Call, B.Pins, "Any")
	if pinned and st.mine and not byKey[KEEP] and okAny and anyPin == true then
		local keep = { key = KEEP, label = Label(KEEP), entries = {} }
		byKey[KEEP] = keep
		list[#list + 1] = keep
	end
	-- The player's own bag window always has the titles of the sections the player made (BagsCustom.lua), with no cell but the + slot while one
	-- holds nothing, so an item can be dropped there; the bank window shows one only while it holds bank items.
	if st.which == "bags" and st.mine then
		local okKeys, keys = pcall(Call, B.Custom, "Keys")
		for _, key in ipairs(okKeys and type(keys) == "table" and keys or {}) do
			if type(key) == "string" and not byKey[key] then
				local own = { key = key, label = Label(key), entries = {} }
				byKey[key] = own
				list[#list + 1] = own
			end
		end
	end
	table.sort(list, function(a, b)
		local oa, ob = orders[a.key] or LATE, orders[b.key] or LATE
		if oa ~= ob then
			return oa < ob
		end
		return a.key < b.key
	end)
	for _, sec in ipairs(list) do
		-- Keep in place is not sorted: its cells go in the order of the bags and their slots.
		SortEntries(st, sec.entries, sec.key == KEEP)
		for _, entry in ipairs(sec.entries) do
			st.cells[entry.sk] = entry
		end
		-- A folded section keeps its cells, for Visit, and shows its title alone (BagsOrder.lua).
		local okFold, folded = pcall(Call, B.Order, "Folded", sec.key)
		sec.folded = okFold and folded == true or nil
		sec.plus = Plus(st, sec) or nil
		sec.titleWidth = Measure(st, TitleText(sec, true))
	end
	-- + New section after the last section of the player's own bag window: a title with no cell, which makes a section of the player's own
	-- (BagsCustom.lua). It comes after the sort, so it is always last, and never moves or folds (BagsOrder.lua).
	if st.which == "bags" and st.mine then
		local add = { key = ADD, add = true, label = ADD_LABEL, entries = {} }
		add.titleWidth = Measure(st, TitleText(add))
		list[#list + 1] = add
	end
	SortEntries(st, strip.entries)
	for _, entry in ipairs(strip.entries) do
		st.cells[entry.sk] = entry
		ShownNew(entry.record)
	end
	st.sections = list
	if #strip.entries > 0 then
		strip.titleWidth = Measure(st, TitleText(strip))
		st.strip = strip
	end
	MakeFree(st)
end

-- The name a bag block shows: the bag's own name for the player's own live bags, else a fixed name or the label of its kind; a special bag's kind
-- after it.
local function BagName(st, bag, kind)
	local name
	if st.mine and st.live and type(C_Container) == "table" and type(C_Container.GetBagName) == "function" then
		local ok, text = pcall(C_Container.GetBagName, bag)
		if ok and type(text) == "string" and not IsSecret(text) and text ~= "" then
			name = text
		end
	end
	if not name then
		if bag == 0 then
			name = Word("BAG_NAME_BACKPACK", "Backpack")
		elseif bag == KEYRING then
			name = Word("KEYRING", "Keyring")
		elseif bag == BANK_SLOTS then
			name = Word("BANK", "Bank")
		end
	end
	local label = KindField(kind, "label")
	label = type(label) == "string" and label ~= "" and label or nil
	if not name then
		name = label or ("Bag %d"):format(bag)
	end
	local family = KindField(kind, "family")
	if Finite(family) and family ~= 0 and label and label ~= name then
		name = name .. " · " .. label
	end
	return name
end

-- Counts what a section holds, for its title: the free slots of a bag, the items of a section; and names the top shelf by what is on it now.
local function Recount(st, sec)
	if sec.block then
		local free = 0
		for _, entry in ipairs(sec.entries) do
			if not entry.record then
				free = free + 1
			end
		end
		sec.freeCount, sec.full = free, free == 0
	elseif sec.key ~= FREE then
		local count = 0
		for _, entry in ipairs(sec.entries) do
			if entry.record then
				count = count + 1
			end
		end
		sec.count = count
		if sec.strip then
			local label = StripLabel(st, sec)
			if label ~= sec.label then
				sec.label = label
				sec.titleWidth = Measure(st, TitleText(sec))
			end
		end
	end
end

-- The icon a bag block's label starts with, as a texture code of the client's at the size of the title's text, cropped as the slots are: the
-- game's own backpack and keyring icons of its bag bar (Blizzard_MainMenuBarBagButtons/Camelot/MainMenuBarBagButtons.xml, their bagIcon), and for
-- a bag, the bag in a bag slot or in a bank bag slot, its item's icon (C_Item.GetItemIconByID of the kind's id, BagsData.lua), for the player's
-- own bags and for another character's alike. The bank's own slots have none.
local function BagIcon(st, bag, kind)
	local icon
	if bag == 0 then
		icon = BACKPACK_ICON
	elseif bag == KEYRING then
		icon = KEYRING_ICON
	elseif bag ~= BANK_SLOTS then
		local id = KindField(kind, "id")
		if Finite(id) and id > 0 and type(C_Item) == "table" and type(C_Item.GetItemIconByID) == "function" then
			local ok, file = pcall(C_Item.GetItemIconByID, id)
			if ok and (Finite(file) or (type(file) == "string" and not IsSecret(file) and file ~= "")) then
				icon = file
			end
		end
	end
	if not icon then
		return nil
	end
	local size = math.floor(st.textSize + 2)
	return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t "):format(tostring(icon), size, size)
end

-- The number of a bag in its window, as the game counts its bag slots: bags 1 to 4 and the reagent bag 5 of the player's bags, and bank bags 1 to
-- 8 after the bank's own slots; none for the backpack, the keyring and the bank's own slots, whose names are their own.
local function BagNumber(st, bag)
	if bag == 0 or bag == KEYRING or bag == BANK_SLOTS or not Finite(bag) then
		return nil
	end
	if st.which == "bank" then
		return bag > BANK_SLOTS and bag - BANK_SLOTS or nil
	end
	return bag > 0 and bag or nil
end

-- Bags with the same name (three Journeyman's Backpacks, or another character's bags, each named by its kind) tell themselves apart by their
-- number after the name: "Journeyman's Backpack · bag 3".
local function NumberSameNames(st, blocks)
	local seen = {}
	for _, block in ipairs(blocks) do
		seen[block.name] = (seen[block.name] or 0) + 1
	end
	for _, block in ipairs(blocks) do
		local number = seen[block.name] > 1 and BagNumber(st, block.bag)
		if number then
			block.name = ("%s · bag %d"):format(block.name, number)
		end
	end
end

local function BuildBlocks(st)
	local blocks = {}
	for _, bag in ipairs(st.containers) do
		local slots = st.sizes[bag]
		if slots > 0 then
			local kind = st.kinds[bag]
			local block = { key = "bag", block = true, bag = bag, kind = kind, entries = {}, name = BagName(st, bag, kind),
				icon = BagIcon(st, bag, kind) }
			for slot = 1, slots do
				local record = Item(st.key, bag, slot)
				local entry = Entry(bag, slot, record)
				block.entries[slot] = entry
				st.cells[entry.sk] = entry
				if record then
					ShownNew(record)
				end
			end
			Recount(st, block)
			blocks[#blocks + 1] = block
		end
	end
	NumberSameNames(st, blocks)
	for _, block in ipairs(blocks) do
		block.titleWidth = Measure(st, TitleText(block))
	end
	st.sections, st.strip, st.free = blocks, nil, nil
end

-- Places everything of a layout where its sections are, draws what changed, hides what it shows no longer and sizes the content frame.
local function Render(st)
	if not (st.built and st.content) then
		return
	end
	local was = st.placed
	st.placed, st.used = {}, 0
	Run("custom", Call, B.Custom, "Begin", st)
	local top, bottom = 0, 0
	local strip = st.strip
	if strip then
		Recount(st, strip)
		-- Everything the top shelf shows counts as shown in New items, so it leaves when the window closes (New.Close): also an item that filled a
		-- cell the shelf had already, or whose new flag came after it arrived (B.Categories.New asks the item first).
		for _, entry in ipairs(strip.entries) do
			if entry.record then
				ShownNew(entry.record)
			end
		end
		strip.x, strip.w = 0, st.columns
		strip.height = Height(st, #strip.entries, strip.w)
		PlaceSection(st, strip, 0, 0)
		top, bottom = -(strip.height + GAP), -strip.height
	end
	for _, sec in ipairs(st.sections) do
		Recount(st, sec)
		PlaceSection(st, sec, sec.x, top + sec.y)
		bottom = math.min(bottom, top + sec.y - sec.height)
	end
	local free = st.free
	if free then
		local y = bottom < 0 and (bottom - GAP) or 0
		local need = math.ceil(((free.titleWidth or 0) + TITLE_ROOM) / PITCH)
		free.w = math.min(st.columns, math.max(#free.entries, need, 1))
		free.height = Height(st, #free.entries, free.w)
		PlaceSection(st, free, 0, y)
		bottom = y - free.height
	end
	Run("custom", Call, B.Custom, "Done", st)
	st.height = -bottom
	for button in pairs(was) do
		if not st.placed[button] then
			Hide(button)
		end
	end
	for index = st.used + 1, #st.titles do
		local title = st.titles[index]
		title.sec = nil
		title.frame:Hide()
	end
	st.content:SetSize(math.max(1, st.width), math.max(1, st.height))
end

-- Hides every live button of the window's containers that the layout does not show: the warm-up and the pool may have left some shown.
local function HideUnplaced(st)
	if not st.live then
		return
	end
	local get = st.which == "bags" and "Live" or "Bank"
	for _, bag in ipairs(st.containers) do
		local slots = Size(st.key, bag)
		for slot = 1, slots do
			local button = Call(Buttons, get, bag, slot)
			if type(button) == "table" and not st.placed[button] and button:IsShown() then
				Hide(button)
			end
		end
	end
end

-- The cursor, read every tenth of a second while the window shows: the titles that take a drop are lit while it holds an item or a merchant's item
-- (st.holding; st.merchant for the second) that they take. A change of what it holds (an item swapped by a click on another slot, st.heldId) or of
-- the fight (st.fight) while it holds one reads it again too. A title under the mouse draws its tooltip again.
local function Watch(st)
	if st.watcher or not st.content then
		return
	end
	local frame = Own(CreateFrame("Frame", nil, st.content))
	local wait = 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - elapsed
		if wait > 0 then
			return
		end
		wait = CURSOR_STEP
		local kind, id = CursorKind()
		local merchant = kind == "merchant"
		local holding = kind == "item" or merchant
		local heldId = holding and id or nil
		local fight = holding and InFight() or false
		if holding ~= (st.holding == true) or merchant ~= (st.merchant == true) or heldId ~= st.heldId or fight ~= (st.fight == true) then
			st.holding, st.merchant, st.heldId, st.fight = holding, merchant, heldId, fight
			-- The + slots light, and the catchers take the mouse, while the cursor holds an item (BagsCustom.lua); read first, so the titles light by
			-- what it read (Lit).
			Run("custom", Call, B.Custom, "Holding", st)
			local tip = GameTooltip
			for index = 1, st.used do
				local title = st.titles[index]
				if title then
					Run("layout", PaintTitle, title)
					if title.over and type(tip) == "table" and not ns.Forbidden(tip) then
						local ok, owned = pcall(tip.IsOwned, tip, title.frame)
						if ok and not IsSecret(owned) and owned == true then
							Run("layout", TitleTip, title)
						end
					end
				end
			end
		end
	end)
	st.watcher = frame
end

-- The search: each button shown is lit when its item matches, and dimmed when it does not or is not loaded yet (B.Search.Match gives nil then). An
-- empty slot is never dimmed (B.Buttons.Dim), so free slots stay readable. A match that fails counts as unknown, so a fault of the search dims
-- and never stops the layout, as B.Buttons.Draw has it.
function Layout.Dim(which)
	local st = state[which]
	if not (st and st.built) then
		return
	end
	local dim = Fn(Buttons, "Dim")
	if not dim then
		return
	end
	local active = Call(Search, "Active") == true
	local match = Fn(Search, "Match")
	-- The bag the mouse points at on the bag bar or in a row of bag slots (Layout.Light), else the one a click on its slot keeps lit (Layout.Stick),
	-- in the player's own live bags or bank only, and only while that bag has slots in the window, so an empty bag slot dims nothing.
	local lit = st.mine and st.live and (st.lit ~= nil and st.lit or st.stuck) or nil
	if lit ~= nil and not ((st.sizes and st.sizes[lit] or 0) > 0) then
		lit = nil
	end
	-- What the search gave each placed cell, so the titles below count them without asking again.
	local seen = {}
	for button, entry in pairs(st.placed) do
		local matched = true
		if active and entry.record and match then
			local ok, answer = pcall(match, entry.record)
			if ok then
				matched = answer
			else
				matched = nil
			end
			seen[entry] = matched == true
		end
		if lit ~= nil then
			dim(button, entry.bag == lit and matched, true)
		else
			dim(button, matched)
		end
	end
	-- While a search is typed every section's title says how many of its items match ("3 of 24", TitleText; a folded one shows no button, so its
	-- title is all it has), and its count alone again once the search is cleared; a section, or a bag's label in Bag by bag (which keeps its
	-- free count), with no match fades to TITLE_FADED. The top shelf and Free slots keep their titles. Nothing is laid out: a folded title was
	-- measured for that text, and an open one too narrow for it says the matches alone (WriteTitle).
	for index = 1, st.used do
		local title = st.titles[index]
		local sec = title and title.sec
		if sec then
			local matches = nil
			if active and match and not sec.strip and sec.key ~= FREE then
				matches = 0
				for _, entry in ipairs(sec.entries) do
					local record = entry.record
					if record then
						local hit = seen[entry]
						if hit == nil then
							local ok, answer = pcall(match, record)
							hit = ok and answer == true
						end
						if hit then
							matches = matches + 1
						end
					end
				end
			end
			if sec.matches ~= matches then
				sec.matches = matches
				if not sec.block then
					WriteTitle(title, sec)
				end
			end
			local alpha = matches == 0 and TITLE_FADED or 1
			title.text:SetAlpha(alpha)
			title.rule:SetAlpha(alpha)
		end
	end
end

-- The mouse points at a bag's button on the game's bag bar (Bags.lua) or in the bag slot row of the bag window (BagsSlots.lua), or at a bank bag
-- slot in the bank window's row (BagsBank.lua, which passes that bag's container): while the window shows the player's own live bags or bank,
-- every slot it shows that is not in that bag is dimmed, empty ones too, and what the search dims stays dimmed; bag nil gives the window back as
-- the search has it, or to the bag a click keeps lit (Layout.Stick). A bag with no slots in the window, an empty bag slot, lights nothing, so the
-- window does not dim whole. The bag is kept (st.lit) through the passes that draw again until the mouse leaves, and the window closing forgets
-- it. Nothing is laid out.
function Layout.Light(which, bag)
	local st = state[which]
	if not st then
		return
	end
	if bag ~= nil and not Finite(bag) then
		bag = nil
	end
	if st.built and bag ~= nil and not ((st.sizes and st.sizes[bag] or 0) > 0) then
		bag = nil
	end
	if st.lit == bag then
		return
	end
	st.lit = bag
	if st.built then
		Layout.Dim(which)
	end
end

-- A click on a bag's slot in the bag slot row (BagsSlots.lua) keeps that bag lit as Layout.Light lights it, until a click on it again (bag nil), a
-- click on another slot, the bag leaving its slot (picked up there, or gone at the next layout, Layout.Build), or the window closing or showing
-- another character or a snapshot; the mouse over another bag still lights that one while it points there. Nothing is laid out.
function Layout.Stick(which, bag)
	local st = state[which]
	if not st then
		return
	end
	if bag ~= nil and not Finite(bag) then
		bag = nil
	end
	if st.stuck == bag then
		return
	end
	st.stuck = bag
	if st.built then
		Layout.Dim(which)
	end
end

-- The bag a click keeps lit in a window, or nil.
function Layout.Stuck(which)
	local st = state[which]
	return st and st.stuck or nil
end

-- Lays a window out afresh for the character it shows.
function Layout.Build(which)
	local st = State(which)
	if not st.content then
		return
	end
	st.builds = (st.builds or 0) + 1
	if st.built then
		-- The pooled buttons of the last layout go back first.
		Call(Buttons, "Release", st.content)
	end
	st.key, st.mine, st.live = Layout.Viewed(which)
	if not (st.mine and st.live) then
		-- Another character or a snapshot has no bag slot row, so nothing keeps a bag lit.
		st.stuck = nil
	end
	st.view, st.columns, st.scale, st.sign = View(), Columns(which), Scale(), Sign()
	st.width = st.columns * PITCH - SPACE
	st.textSize = TextSize(st.scale)
	st.titleH = math.max(TITLE, math.ceil(st.textSize + 6))
	st.content:SetScale(st.scale)
	st.cells, st.where, st.sections, st.strip, st.free = {}, {}, {}, nil, nil
	Gather(st)
	-- A bag a click kept lit that has left its slot lets that go, so a bag put in that slot later shows like any other (taking a bag out lays the
	-- window out again, BagsData.lua).
	if st.stuck ~= nil and not ((st.sizes[st.stuck] or 0) > 0) then
		st.stuck = nil
	end
	if st.view == "bags" then
		BuildBlocks(st)
	else
		BuildSections(st)
	end
	Pack(st)
	st.built = true
	Render(st)
	HideUnplaced(st)
	Layout.Dim(which)
	Watch(st)
end

-- True when the layout of a window was made with what it would be made with now.
local function Current(st)
	if not st.built then
		return false
	end
	local key, mine, live = Layout.Viewed(st.which)
	return st.key == key and st.mine == mine and st.live == live and st.view == View() and st.columns == Columns(st.which) and st.scale == Scale()
		and st.sign == Sign()
end

-- One slot of the sections while the window is open: a cell keeps its slot whatever it holds now; an item in a slot that has no cell arrives at the
-- end of the top shelf, except while a sort still moves items (held), when it waits for the layout after the sort.
local function Visit(st, bag, slot, held)
	local sk = SlotKey(bag, slot)
	local record = Item(st.key, bag, slot)
	local entry = st.cells[sk]
	if entry then
		entry.record, entry.dirty = record, true
		return
	end
	if not record or held then
		return
	end
	if not st.strip then
		st.strip = NewStrip(st)
	end
	entry = Entry(bag, slot, record)
	st.strip.entries[#st.strip.entries + 1] = entry
	st.cells[sk] = entry
	ShownNew(record)
end

-- The slots of changed in the order of the bags: { { bag, slot } ... }.
local function InOrder(st, changed)
	local list = {}
	for bag, slots in pairs(changed) do
		if st.rank[bag] and type(slots) == "table" then
			for slot in pairs(slots) do
				if Finite(slot) and slot >= 1 then
					list[#list + 1] = { bag, slot }
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a[1] ~= b[1] then
			return st.rank[a[1]] < st.rank[b[1]]
		end
		return a[2] < b[2]
	end)
	return list
end

-- The window is open and its slots changed: changed is { [bag] = { [slot] = true } } from BagsData.lua, or nil to look at every slot. held: a sort
-- still moves items (BagsWindow.lua), so nothing arrives at the top shelf.
function Layout.Update(which, changed, held)
	local st = state[which]
	if not (st and Current(st)) then
		return Layout.Build(which)
	end
	local all = type(changed) ~= "table"
	if not all then
		for bag in pairs(changed) do
			if not st.rank[bag] then
				-- A container the layout does not have: the bags themselves changed.
				return Layout.Build(which)
			end
		end
	end
	if st.view == "bags" then
		if st.rank[KEYRING] and (all or changed[KEYRING]) and KeyringShown(st.key, (Size(st.key, KEYRING))) ~= st.sizes[KEYRING] then
			-- The keyring needs more or fewer slots; it is the last block, so nothing above it moves.
			return Layout.Build(which)
		end
		for _, block in ipairs(st.sections) do
			local slots = not all and changed[block.bag]
			if all or type(slots) == "table" then
				for slot, entry in ipairs(block.entries) do
					if all or slots[slot] then
						entry.record, entry.dirty = Item(st.key, block.bag, slot), true
						if entry.record then
							ShownNew(entry.record)
						end
					end
				end
			end
		end
	else
		-- An item a drop on a + slot or a section's slots put in a free slot of the bags has arrived: laid out afresh, so it shows in that section and
		-- not at the end of the top shelf (BagsCustom.lua).
		local okArrived, arrived = pcall(Call, B.Custom, "Arrived", st, changed, held)
		if okArrived and arrived == true then
			return Layout.Build(which)
		end
		local hadStrip = st.strip ~= nil
		if all then
			for _, bag in ipairs(st.containers) do
				for slot = 1, st.sizes[bag] do
					Visit(st, bag, slot, held)
				end
			end
		else
			for _, spot in ipairs(InOrder(st, changed)) do
				Visit(st, spot[1], spot[2], held)
			end
		end
		if st.strip and not hadStrip then
			st.strip.titleWidth = Measure(st, TitleText(st.strip))
		end
		MakeFree(st)
	end
	Render(st)
	Layout.Dim(which)
end

-- Draws again where it stands and places buttons made since: the end of the warm-up of BagsWindow.lua.
function Layout.Render(which)
	local st = state[which]
	if st and st.built then
		Render(st)
		HideUnplaced(st)
		Layout.Dim(which)
	end
end

-- Puts the holders of the player's own live buttons under the bag window's content frame, whoever the window shows, so the warm-up of
-- BagsWindow.lua shows them inside the window, which it puts off the screen meanwhile, and nowhere else.
function Layout.Adopt(which)
	local st = State(which)
	if not st.content or which ~= "bags" then
		return
	end
	local me = Call(B, "Me")
	for _, bag in ipairs(Containers("bags", me)) do
		local slots = Size(me, bag)
		for slot = 1, slots do
			local button = Call(Buttons, "Live", bag, slot)
			if type(button) == "table" then
				Adopt(st, button, "live", bag)
			end
		end
	end
end

-- How many times a window was laid out afresh (Layout.Build), also from inside Layout.Update, so BagsWindow.lua can tell an update that laid it out
-- afresh from one that drew it again where it stands.
function Layout.Builds(which)
	local st = state[which]
	return st and st.builds or 0
end

-- True when the last layout of a window shows this button.
function Layout.Placed(which, button)
	local st = state[which]
	return st ~= nil and st.built == true and st.placed[button] ~= nil
end

-- The bag, slot and record of the cell the last layout of a window shows this button in, and true while that is the player's own live bag window;
-- nil for a button it does not show. The record is the cell's, so the caller checks it is the item it means.
function Layout.EntryOf(which, button)
	local st = state[which]
	local entry = st and st.built == true and type(button) == "table" and st.placed[button] or nil
	if type(entry) ~= "table" or type(entry.record) ~= "table" then
		return nil
	end
	return entry.bag, entry.slot, entry.record, which == "bags" and st.mine == true and st.live == true
end

-- Where the warm-up of BagsWindow.lua puts a button it shows in an open window for one frame: off the left edge of the screen, out of sight and
-- out of reach of the mouse (not by its alpha: the template's SetAlpha fades its icon and count only). Every layout forgets where it put the
-- button, so the next pass that shows it anchors it in its cell again.
function Layout.Park(button)
	for _, st in pairs(state) do
		st.where[button] = nil
	end
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -PARK, 0)
end

-- The window closed: the next opening lays it out afresh, and the pooled buttons go back.
function Layout.Closed(which)
	Layout.CloseMenu(which)
	Run("order", Call, B.Order, "Cancel", which)
	Run("custom", Call, B.Custom, "Closed", which)
	local st = state[which]
	if not st then
		return
	end
	st.built, st.lit, st.stuck = false, nil, nil
	for button in pairs(st.placed) do
		Hide(button)
	end
	st.placed, st.cells, st.where, st.sections, st.strip, st.free = {}, {}, {}, {}, nil, nil
	if st.content then
		Call(Buttons, "Release", st.content)
	end
end

-- The size of the content of a window, in the window's own units.
function Layout.Size(which)
	local st = state[which]
	if not (st and st.built) then
		return 0, 0
	end
	return st.width * st.scale, (st.height or 0) * st.scale
end

-- Drops and clicks on titles ----------------------------------------------------------------------------------------------------------------------

-- The item on the cursor taken by a section, as a drop on its title takes it: kept in that section, or put on Errands' sell or keep list by
-- B.Categories.Drop, which asks for the layout itself when it took the drop, so a drop it refused moves nothing; either way the item goes back to
-- its slot. Out of combat only: in a fight the item only goes back, with one line. The top shelf and Free slots only give it back. True when the
-- section took it. Layout.Take is the same for a drop on a + slot or on a section's slots (BagsCustom.lua).
local function Take(st, sec)
	local id = Holding()
	if not (st and sec and id) or sec.block or sec.add or not st.mine or st.view ~= "sections" then
		return false
	end
	local takes = Takes(st, sec)
	if takes and Fighting() then
		pcall(ClearCursor)
		print(FIGHT_LINE)
		return false
	end
	local taken = false
	if takes and sec.key == KEEP then
		-- Keep in place pins the slot the item came from (BagsPins.lua). Run gives back no result of its function, so the pin's answer is read
		-- inside it.
		Run("pins", function()
			taken = Call(B.Pins, "Drop") == true
		end)
	elseif takes then
		-- An item from a pinned slot dropped on another section unpins that slot once the section took it. Where it came from is read first,
		-- since the drop gives the item back; a drop refused leaves the pin.
		local okFrom, fromId, fromBag, fromSlot = pcall(Call, B.Pins, "Held")
		taken = Call(Categories, "Drop", id, sec.key) == true
		if taken and okFrom and fromId then
			Run("pins", Call, B.Pins, "Left", fromId, fromBag, fromSlot)
		end
	end
	pcall(ClearCursor)
	return taken
end

function Layout.Take(st, sec)
	return Take(st, sec)
end

-- An item or a merchant's item let go or clicked on a section's title. The time of the drop is kept first, so the click that ends it on the same
-- title is that drop (TitleClick), in a fight too. A drop on + New section asks for the name of a section for the item (B.Custom.DropNew). On a title
-- that takes a drop it is the drop of that section's + slot (B.Custom.DropOn): an item of the bank or worn gear goes into a free slot of the bags
-- first, a merchant's item is bought into one, an item of the bags is Take's, and a refusal says why; the section that took it flashes
-- (B.Custom.Took). While BagsCustom does not take it (its part stopped), an item is Take's alone and a merchant's item goes back.
function Drop(title)
	local st, sec = title.st, title.sec
	local kind = CursorKind()
	if not (st and sec) or (kind ~= "item" and kind ~= "merchant") or sec.block or not st.mine or st.view ~= "sections" then
		return
	end
	title.dropped = GetTime()
	if sec.add then
		Run("custom", Call, B.Custom, "DropNew", st, title.frame)
		return
	end
	local handled = false
	if Takes(st, sec) then
		-- Run gives back no result of its function, so the answer is read inside it.
		Run("custom", function()
			handled = Call(B.Custom, "DropOn", st, sec) == true
		end)
	end
	if handled then
		return
	end
	local id = Holding()
	if not id then
		pcall(ClearCursor)
		return
	end
	if Take(st, sec) then
		Run("custom", Call, B.Custom, "Took", st.which, sec.key, id)
	end
end

function TitleClick(title, mouse)
	local st, sec = title.st, title.sec
	if not (st and sec) then
		return
	end
	-- An item or a merchant's item on the cursor is a drop; anything else on it (a spell, a macro, money) makes the click do nothing, so it never folds
	-- a section or opens a menu or the name box.
	local kind = CursorKind()
	if kind == "item" or kind == "merchant" then
		Drop(title)
		return
	elseif kind ~= nil then
		return
	end
	-- The click that ends a drop on the same title is that drop.
	local dropped = title.dropped
	if dropped and GetTime() - dropped < DROP_CLICK then
		return
	end
	if sec.add then
		-- + New section: a left click names a new section, a right click opens the menu of the player's sections (BagsCustom.lua).
		Run("custom", Call, B.Custom, "AddClick", st, mouse, title.frame)
		return
	end
	if mouse == "RightButton" and sec.block then
		-- A right click on a bag's label opens its settings too, as the left one does.
		if title.clickable then
			Layout.BagMenu(st, sec, title.frame)
		end
		return
	end
	if mouse == "RightButton" and not sec.block and not sec.strip then
		-- The menu that moves the section (BagsOrder.lua), with the lines of Keep in place on its own.
		Run("order", Call, B.Order, "Menu", st, sec, title.frame)
		return
	end
	if mouse ~= "LeftButton" then
		return
	end
	if sec.block then
		if title.clickable then
			Layout.BagMenu(st, sec, title.frame)
		end
	elseif not sec.strip and sec.key ~= FREE then
		-- A section that can move folds to its title, or opens again, in both windows (BagsOrder.lua).
		Run("order", Call, B.Order, "Fold", st, sec)
	elseif sec.strip then
		if st.which == "bags" then
			-- While New items at the top is on, the game's new flags come off the items of the bags first, as the window's close takes them
			-- (B.ClearNew, Bags.lua), so a slot that changes later does not bring its item back as new. With the row off nothing is kept as new,
			-- and the flags stay until the bags close, as a sort leaves them.
			if Opt("newItems") ~= false then
				Call(B, "ClearNew")
			end
			Call(Categories.New, "Clear")
		end
		Request("layout", st.which)
	end
end

-- Menus -------------------------------------------------------------------------------------------------------------------------------------------

-- A menu of Flat UI's own, in the way of Data panels' menu: a title and lines, each { text, right = text at the right edge, tick = true or false for
-- a line with a box (nil for none), header = true for a dim line that does nothing, pick = function run on a click, part = the part it runs as }.
-- The lines go down a column and on in the next column to the right once a column would be taller than MENU_MOST of the screen, a header never last
-- in a column, so every line stays on the screen however many characters Bags keeps. A click on a line closes the menu and runs its pick. A press
-- anywhere else, a second click on what opened it and its window closing close it; so does the interface hiding, for good, since nothing could
-- close a menu that came back with it. Its tick, when set, runs every frame while it shows: the character picker counts with it.
local MENU_X, MENU_Y, MENU_LINE, MENU_BOX, MENU_GAP = 8, 5, 16, 10, 14
-- The share of the screen's height a column of lines may take, and the fewest lines a column holds.
local MENU_MOST, MENU_LEAST = 0.9, 4
local menu

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and not IsSecret(over) and over == true
end

-- The menu closed: nothing listens for a press any more, and it belongs to no frame.
local function Gone()
	pcall(menu.listener.UnregisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	menu.anchor, menu.owner, menu.tick = nil, nil, nil
end

-- Makes each column as wide as its widest line (a title wider than all of them widens the last one), and puts every line at its column and row.
local function Fit()
	local columns = menu.columns or 1
	local widths = {}
	for column = 1, columns do
		widths[column] = 0
	end
	for index = 1, menu.count do
		local line = menu.lines[index]
		local need = TextWidth(line.text) + (line.item.tick ~= nil and (MENU_BOX + 6) or 0)
		local right = TextWidth(line.right)
		if right > 0 then
			need = need + MENU_GAP + right
		end
		local column = line.column or 1
		widths[column] = math.max(widths[column] or 0, need)
	end
	local total = 0
	for column = 1, columns do
		widths[column] = math.ceil(widths[column]) + 2 * MENU_X
		total = total + widths[column]
	end
	local title = menu.title:IsShown() and (math.ceil(TextWidth(menu.title)) + 2 * MENU_X) or 0
	if title > total then
		widths[columns] = widths[columns] + title - total
		total = title
	end
	local lefts, x = {}, 0
	for column = 1, columns do
		lefts[column] = x
		x = x + widths[column]
	end
	for index = 1, menu.count do
		local line = menu.lines[index]
		local column = line.column or 1
		local left, width = lefts[column], widths[column]
		if line.left ~= left or line.width ~= width then
			line.left, line.width = left, width
			line.frame:ClearAllPoints()
			line.frame:SetPoint("TOPLEFT", menu.frame, "TOPLEFT", left, -(line.y or 0))
			line.frame:SetSize(width, MENU_LINE)
		end
	end
	menu.frame:SetWidth(total)
end

local function MenuPaint()
	local r, g, b = ns.Colour("general.backdrop")
	-- A menu lies over other windows, so its fill does not follow Window opacity (Windows.lua:539-552).
	ns.SetOutlineFill(menu.outline, r, g, b, 0.95)
	ns.SetOutline(menu.outline, true, true)
	local pr, pg, pb = LookRGB("panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	for _, line in ipairs(menu.lines) do
		line.edge:SetColorTexture(1, 1, 1, 0.3)
		line.box:SetColorTexture(pr, pg, pb, 1)
		line.mark:SetColorTexture(ar, ag, ab, 1)
	end
end

local function MenuLine(index)
	local line = menu.lines[index]
	if line then
		return line
	end
	local frame = Own(CreateFrame("Button", nil, menu.frame))
	frame:RegisterForClicks("LeftButtonUp")
	line = { frame = frame }
	line.light = Own(frame:CreateTexture(nil, "BACKGROUND"))
	line.light:SetAllPoints(frame)
	line.light:SetColorTexture(1, 1, 1, 0.08)
	line.light:Hide()
	line.edge = Own(frame:CreateTexture(nil, "ARTWORK", nil, 1))
	line.edge:SetSize(MENU_BOX, MENU_BOX)
	line.edge:SetPoint("LEFT", frame, "LEFT", MENU_X, 0)
	line.box = Own(frame:CreateTexture(nil, "ARTWORK", nil, 2))
	line.box:SetPoint("TOPLEFT", line.edge, "TOPLEFT", 1, -1)
	line.box:SetPoint("BOTTOMRIGHT", line.edge, "BOTTOMRIGHT", -1, 1)
	line.mark = Own(frame:CreateTexture(nil, "ARTWORK", nil, 3))
	line.mark:SetPoint("TOPLEFT", line.edge, "TOPLEFT", 3, -3)
	line.mark:SetPoint("BOTTOMRIGHT", line.edge, "BOTTOMRIGHT", -3, 3)
	line.text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	line.text:SetJustifyH("LEFT")
	line.text:SetWordWrap(false)
	line.right = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	line.right:SetPoint("RIGHT", frame, "RIGHT", -MENU_X, 0)
	line.right:SetJustifyH("RIGHT")
	line.right:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	frame:SetScript("OnEnter", function()
		local item = line.item
		line.light:SetShown(item ~= nil and not item.header)
	end)
	frame:SetScript("OnLeave", function()
		line.light:Hide()
	end)
	frame:SetScript("OnClick", function()
		local item = line.item
		if not item or item.header then
			return
		end
		Layout.CloseMenu()
		if type(item.pick) == "function" then
			Run(item.part or "window", item.pick)
		end
	end)
	menu.lines[index] = line
	return line
end

local function MenuFrame()
	if menu then
		return menu
	end
	local frame = Own(CreateFrame("Frame", nil, UIParent))
	frame:SetFrameStrata("DIALOG")
	frame:SetSize(1, 1)
	-- A click on the edge of the menu stays on it.
	frame:EnableMouse(true)
	pcall(frame.SetClampedToScreen, frame, true)
	frame:Hide()
	menu = { frame = frame, lines = {}, count = 0 }
	menu.outline = ns.Outline(frame, frame)
	menu.title = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	menu.title:SetPoint("TOPLEFT", frame, "TOPLEFT", MENU_X, -(MENU_Y + 2))
	menu.title:SetJustifyH("LEFT")
	menu.title:SetWordWrap(false)
	menu.listener = Own(CreateFrame("Frame"))
	menu.listener:SetScript("OnEvent", function()
		if menu.anchor and not Over(menu.frame) and not Over(menu.anchor) then
			Layout.CloseMenu()
		end
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		if menu.tick then
			Run("window", menu.tick, elapsed)
		end
	end)
	-- Hidden with its parent (the interface hidden), the menu keeps its own shown flag: it is hidden for good, which runs no second OnHide.
	frame:SetScript("OnHide", function()
		if menu.frame:IsShown() then
			menu.frame:Hide()
		end
		Gone()
	end)
	return menu
end

-- True while a menu is open on that frame.
function Layout.MenuOn(anchor)
	return menu ~= nil and menu.anchor ~= nil and menu.anchor == anchor
end

-- True while a menu of that window ("bags", "bank") is open: the window keeps a height kept taller meanwhile (BagsWindow.lua, Unslack).
function Layout.MenuOf(owner)
	return menu ~= nil and menu.anchor ~= nil and menu.owner == owner
end

-- Closes the menu, or only one opened from that window ("bags", "bank"). It is closed here too, since a menu hidden already (with its parent)
-- hears no second OnHide.
function Layout.CloseMenu(owner)
	if menu and menu.anchor and (owner == nil or menu.owner == owner) then
		menu.frame:Hide()
		Gone()
	end
end

-- Opens a menu under the frame that asks for it, or closes it when it is open there already. owner: the window it belongs to. Returns the menu,
-- whose tick may then be set, or nil.
function Layout.Menu(anchor, title, items, owner)
	if Layout.MenuOn(anchor) then
		Layout.CloseMenu()
		return nil
	end
	if type(items) ~= "table" or #items == 0 then
		return nil
	end
	MenuFrame()
	Layout.CloseMenu()
	local top = MENU_Y
	if title then
		menu.title:SetText(title)
		menu.title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
		menu.title:Show()
		top = top + MENU_LINE + 2
	else
		menu.title:SetText("")
		menu.title:Hide()
	end
	-- As many lines in a column as MENU_MOST of the screen holds; a header that would be the last line of a column starts the next one.
	local okScreen, screen = pcall(UIParent.GetHeight, UIParent)
	screen = okScreen and Finite(screen) and screen > 0 and screen or 768
	local most = math.max(MENU_LEAST, math.floor((screen * MENU_MOST - top - MENU_Y) / MENU_LINE))
	local column, row, rows = 1, 0, 0
	for index, item in ipairs(items) do
		local line = MenuLine(index)
		line.item = item
		line.text:SetText(item.text or "")
		line.right:SetText(item.right or "")
		line.text:ClearAllPoints()
		if item.tick ~= nil then
			line.text:SetPoint("LEFT", line.edge, "RIGHT", 6, 0)
			line.edge:Show()
			line.box:Show()
			line.mark:SetShown(item.tick == true)
		else
			line.text:SetPoint("LEFT", line.frame, "LEFT", MENU_X, 0)
			line.edge:Hide()
			line.box:Hide()
			line.mark:Hide()
		end
		if item.header then
			line.text:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
		else
			line.text:SetTextColor(1, 1, 1, 1)
		end
		line.light:Hide()
		if row > 0 and (row >= most or (item.header and row >= most - 1)) then
			column, row = column + 1, 0
		end
		-- Fit anchors the line at its column's left edge, as wide as the column.
		line.column, line.y, line.left, line.width = column, top + row * MENU_LINE, nil, nil
		line.frame:Show()
		row = row + 1
		rows = math.max(rows, row)
	end
	menu.count, menu.columns = #items, column
	for index = #items + 1, #menu.lines do
		menu.lines[index].item = nil
		menu.lines[index].frame:Hide()
	end
	menu.frame:SetHeight(top + rows * MENU_LINE + MENU_Y)
	Fit()
	MenuPaint()
	menu.frame:ClearAllPoints()
	menu.frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu.anchor, menu.owner, menu.tick = anchor, owner, nil
	menu.frame:Show()
	pcall(menu.listener.RegisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	Untip(anchor)
	return menu
end

-- Writes the text at the right edge of line number index of the open menu, and widens its column for it.
function Layout.MenuRight(index, text)
	local line = menu and menu.anchor and menu.lines[index]
	if line and line.item then
		line.right:SetText(text or "")
		Fit()
	end
end

-- The bag menu ------------------------------------------------------------------------------------------------------------------------------------

local function FlagValue(name, fallback)
	local enum = type(Enum) == "table" and not IsSecret(Enum) and Enum.BagSlotFlags or nil
	local value = type(enum) == "table" and not IsSecret(enum) and enum[name] or nil
	return Finite(value) and value or fallback
end

-- Whether a flag of a bag is set; only a plain true counts.
local function SlotFlag(bag, flag)
	if type(C_Container) ~= "table" or type(C_Container.GetBagSlotFlag) ~= "function" then
		return false
	end
	local ok, on = pcall(C_Container.GetBagSlotFlag, bag, flag)
	return ok and not IsSecret(on) and on == true
end

local function Backpack(name)
	if type(C_Container) ~= "table" or type(C_Container[name]) ~= "function" then
		return false
	end
	local ok, on = pcall(C_Container[name])
	return ok and not IsSecret(on) and on == true
end

-- Sets or clears a flag, on the backpack through its own pair of calls, as the game's menu does (ContainerFrame.lua:666-710). The junk coin and the
-- Sell junk count follow these flags, so they are asked for again.
local function Toggle(bag, flag, backpackGet, backpackSet)
	if bag == 0 and backpackGet then
		if type(C_Container) == "table" and type(C_Container[backpackSet]) == "function" then
			pcall(C_Container[backpackSet], not Backpack(backpackGet))
		end
	elseif type(C_Container) == "table" and type(C_Container.SetBagSlotFlag) == "function" then
		pcall(C_Container.SetBagSlotFlag, bag, flag, not SlotFlag(bag, flag))
	end
	Request("items", "bags")
	Request("footer", "bags")
end

-- The menu of one of the player's own bags: what the game's bag menu holds (ContainerFrame.lua:643-711). Assign To only on bags 1 to 4 that are not
-- special bags, as the game offers it on bags 1 to 4 that are not profession bags (:108-118); the keyring has no menu, as in the game (:769-771).
function Layout.BagMenu(st, block, anchor)
	local bag = block.bag
	if not (st.mine and st.live and st.which == "bags") or bag == KEYRING then
		return
	end
	local items = {}
	local family = KindField(block.kind, "family")
	if bag >= 1 and bag <= 4 and (family == nil or family == 0) then
		items[#items + 1] = { text = Word("BAG_FILTER_ASSIGN_TO", "Assign To:"), header = true }
		for _, filter in ipairs(FILTERS) do
			local flag = FlagValue(filter[1], filter[2])
			items[#items + 1] = { text = Word(filter[3], filter[4]), tick = SlotFlag(bag, flag), part = "layout", pick = function()
				Toggle(bag, flag)
			end }
		end
	end
	local sortFlag = FlagValue("DisableAutoSort", DISABLE_AUTO_SORT)
	local junkFlag = FlagValue("ExcludeJunkSell", EXCLUDE_JUNK_SELL)
	local sortOff, junkOff
	if bag == 0 then
		sortOff, junkOff = Backpack("GetBackpackAutosortDisabled"), Backpack("GetBackpackSellJunkDisabled")
	else
		sortOff, junkOff = SlotFlag(bag, sortFlag), SlotFlag(bag, junkFlag)
	end
	items[#items + 1] = { text = Word("BAG_FILTER_IGNORE", "Ignore"), header = true }
	items[#items + 1] = { text = Word("BAG_FILTER_CLEANUP", "Clean Up"), tick = sortOff, part = "layout", pick = function()
		Toggle(bag, sortFlag, "GetBackpackAutosortDisabled", "SetBackpackAutosortDisabled")
	end }
	items[#items + 1] = { text = Word("SELL_ALL_JUNK_ITEMS_EXCLUDE_FLAG", "Junk Selling"), tick = junkOff, part = "layout", pick = function()
		Toggle(bag, junkFlag, "GetBackpackSellJunkDisabled", "SetBackpackSellJunkDisabled")
	end }
	Layout.Menu(anchor, Plain(block.name), items, st.which)
end

-- What the bag menu has set on one of the player's own bags, for the tooltip of its slot in the bag slot row (BagsSlots.lua): whether clean up
-- and junk selling leave it alone, and the labels of what it is assigned to (bags 1 to 4 only, as the menu offers it), or nil for none.
function Layout.BagFlags(bag)
	if not Finite(bag) or bag == KEYRING then
		return false, false, nil
	end
	local sortOff, junkOff
	if bag == 0 then
		sortOff, junkOff = Backpack("GetBackpackAutosortDisabled"), Backpack("GetBackpackSellJunkDisabled")
	else
		sortOff = SlotFlag(bag, FlagValue("DisableAutoSort", DISABLE_AUTO_SORT))
		junkOff = SlotFlag(bag, FlagValue("ExcludeJunkSell", EXCLUDE_JUNK_SELL))
	end
	local assigned
	if bag >= 1 and bag <= 4 then
		for _, filter in ipairs(FILTERS) do
			if SlotFlag(bag, FlagValue(filter[1], filter[2])) then
				local word = Word(filter[3], filter[4])
				assigned = assigned and (assigned .. ", " .. word) or word
			end
		end
	end
	return sortOff, junkOff, assigned
end

-- The bag menu of one of the player's own bags from outside the layout: a right click on its slot in the bag slot row (BagsSlots.lua), in either
-- view, under anchor. Only while the window shows the player's own live bags and that bag has slots; the menu itself then asks the rest.
function Layout.BagMenuOf(which, bag, anchor)
	local st = state[which]
	if not (st and st.built and st.mine and st.live and Finite(bag) and st.sizes and st.kinds) then
		return
	end
	if not ((st.sizes[bag] or 0) > 0) then
		return
	end
	local kind = st.kinds[bag]
	Layout.BagMenu(st, { bag = bag, kind = kind, name = BagName(st, bag, kind) }, anchor)
end
