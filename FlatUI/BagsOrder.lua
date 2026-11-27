local _, ns = ...

-- Bags: the order the sections are shown in, which the player sets by dragging a section's title or from its menu. Bags.lua makes ns.Bags with
-- B.Order; this file only adds its fields, makes frames and textures of its own only, and owns no event. The order is display alone: which section
-- an item is filed in (B.Categories.Of, BagsCategories.lua) never changes with it.
--
-- The order is one list of section keys for the whole account, in FlatUIDB.bags.order beside the placements by hand (a new layout of BagsData's
-- record resets only its v and chars, BagsData.lua:581-600), so the bag window, the bank window and every character's view show the same order.
-- Order.Ranks merges it with the built-in order (B.Categories.LIST): the saved keys in their saved order, unknown ones left out, then each built-in
-- key that is not saved right after the nearest key before it in LIST, so a section added later lands at its built-in place (the sections of a
-- group's Each kind right after their group's, where an order saved before them has it); with nothing saved the result is LIST. The sections the
-- player made and named (B.Custom.Keys, BagsCustom.lua) are part of the built-in order, right after Keep in place in the order they were made, so
-- a new one lands there even while an order is saved, and a deleted one leaves the saved order (BagsCustom takes it out). A move writes the whole
-- merged list, the sections of a group that its row does not show now and the hidden ones included, so they keep their places when that row
-- changes or they show again, and a list that equals LIST again is not kept. The top shelf (New items or Added) always comes first and Free slots
-- always last: they are shelves, not sections, and never move. BagsLayout.lua reads the ranks when it lays a window out.
--
-- The drag: each title is a button of Flat UI's own (BagsLayout.lua), whose OnDragStart and OnDragStop come here. A drag gives no click, so
-- BagsLayout registers for a drag with the left button (RegisterForDrag) only the titles that can move, and the click on the top shelf's title or
-- a bag's label stays a click. No drag starts while the cursor holds an item (that is a drop, GetCursorInfo), from the top shelf, Free
-- slots or a bag of Bag by bag, or outside the Sections view; any other section can be dragged, in both windows and for every character. While a
-- title is dragged it fades to half (SetAlpha on the title of Flat UI's own), and a frame of this file's own in the window's content reads the
-- cursor every 0.05 seconds (GetCursorPosition over the title's GetEffectiveScale, GetLeft, GetTop and GetWidth, and the section's height from the
-- layout): the section under the cursor, title and cells, is the target, and the drop goes before it when the cursor is left of its middle, else
-- after it. A bar 2 units wide in the Highlight colour of the Windows page marks the place in the gap beside it. Letting go there moves the section
-- and lays both windows out again (B.Request); letting go elsewhere, or the window hiding, changes nothing. The left button found up with no
-- OnDragStop heard (IsMouseButtonDown; the title was laid out away meanwhile) counts as letting go where the cursor is. The cursor counts only
-- while it is over the window's scroll area (IsMouseOver), so a section scrolled out of sight is never the target. There is no scrolling while
-- dragging; the wheel still scrolls.
--
-- The menu: a right click on a title that can be dragged, with no item on the cursor, opens a menu of BagsLayout's (Layout.Menu) with Move to the
-- top, Move up, Move down and Move to the bottom, among the sections that window shows, Fold or Unfold, Hide this section on every section of Flat
-- UI's own but Other, the lines of its group's row on a section of a group (below), and while an order is saved, a line that puts Flat UI's order
-- back, while a section that window shows is open, Fold every section, while a section that window shows is folded, Unfold every section (a fold
-- kept for a hidden section, or for a kind of a group its row does not show now, does not count), and while a section the rows show is hidden,
-- Show hidden sections (3), which opens the Hidden button's menu (below) under the title.
-- At the live bank (B.Bank.Live), while Deposit and Take out is on (the row that shows those buttons, B.Opt("bankButtons")), a section of the
-- player's own slots also has Put <section> in the bank in the bag window and Take <section> out in the bank window, which run the pass of Deposit
-- and Take out of BagsBank.lua with the section (B.Categories.Of) in place of the search, and its tooltip says so; not on Keep in place, whose
-- items stay pinned. A section with items placed in it by hand (B.Categories.PlacedCount, not Keep in place or Junk, which take none) has a line
-- that puts them back in their own sections (B.Categories.PutBack, one line in chat), "Put back the 3 items placed here", or on a section the
-- player made "Empty this section (3 items)"; the tooltip of one of Flat UI's own sections says how many are placed there. A put back asks
-- nothing, so until the next one or a reload the section's menu also has "Bring back the 3 items you put back" (B.Categories.LastPutBack and
-- Unput), which puts back each placement not changed since, says how many came back (3 of 4 when one is placed elsewhere now) and flashes the
-- section Back (B.Custom.Took). While a search is typed (B.Search.Active), a section that holds items placed by hand has "Place the 7 items that
-- match the search here": every item the window shows (st.cells, folded sections too) that the search finds (B.Search.Match) and that is in
-- another section, not in New items, Junk (so the sell list stays as it is) or Keep in place, is placed there at once (B.Categories.PlaceAll,
-- refused in a fight as a drop is), with one line in chat, the section flashing Placed 7, in both windows and for any character, since placements
-- are by item ID for the account. On Keep in place it also has BagsPins.lua's lines; on every section the Colour lines, and on a section the
-- player made Rename and Delete this section; and in the player's own bag window, New section
-- (B.Custom.MenuLines, BagsCustom.lua). + New section, the title after the last section that makes one, never
-- moves, folds or opens this menu. The row Section order on the Bags page does the same reset. Moving
-- sections works in a fight: it only lays the windows out, and their buttons are not protected (BagsLayout.lua).
--
-- Folds: a left click on a title that can be dragged, with no item on the cursor (BagsLayout.lua's TitleClick, after its check that the click is not
-- the end of a drop), folds the section to its title, or opens it again. With Shift held (IsShiftKeyDown) it opens that section alone and folds every
-- other the window shows (Order.FoldAll), and on a section that is open alone already it opens them all again (Order.UnfoldAll). The folded sections
-- are one set of section keys for the whole account, FlatUIDB.bags.folded = { [key] = true }, beside the order and kept the same way, so the bag
-- window, the bank window and every character's view fold the same sections; an empty set is not kept. BagsLayout lays a folded section out as its
-- title alone, as the empty Junk title is, with a + after its count, while its items keep their cells, so an item that changes in a folded section
-- stays there and does not go to the top shelf; while a search is typed the title says how many of its items match, and its tooltip lists what it
-- holds (BagsLayout.lua). The menu's Fold or Unfold, Fold every section, Unfold every section and the row Folded sections on the Bags page
-- (ns.BagsFoldLines, ns.BagsFoldPick) do the same. Folding works in a fight too, as a move does. A fold or an unfold clicked in the bag window (its
-- title, a Shift-click or its menu) keeps that window's height while the mouse stays on it (B.Window.KeepHeight), so the title clicked stays under
-- the mouse and its tooltip, drawn again by BagsLayout.lua, says what the next click does; the bank window, which hangs from its top left, shrinks.
--
-- Hiding: Hide this section hides the section in both windows and for every character (B.Categories.SetHidden, BagsCategories.lua, which keeps the
-- set in FlatUIDB.bags.hidden and files its items elsewhere), with one line in chat; a section of the player's own has Delete instead. Its place in
-- the order and its fold stay, so it comes back where it was. After the last section of the Sections view, in either window and for any character,
-- BagsLayout.lua draws Hidden (3), a dim title with no cell, while a section the rows show is hidden (Order.HiddenCount); a click on it opens a
-- menu of Layout.Menu (Order.HiddenMenu) with each hidden section, a click on one showing it again, after Show every hidden section while two or
-- more are hidden; either says in chat what shows again, and the section shown again flashes Shown (B.Custom.Took). Its tooltip names the hidden
-- sections (Order.HiddenLabels: "Potions, Rings and Junk", "and 3 more" after eight). It never moves, folds, takes a drop or fades while a search
-- is typed. The rows Hidden sections (ns.BagsHiddenLines, ns.BagsHiddenPick), which also lists a hidden section the rows do not show now marked
-- (not in use now), and Folded sections, which marks a folded one that is hidden, or one the rows do not show now (not in use now), are on the
-- Bags page. A hide or a show lays both windows out again and, from a window, draws the rows of an open options window again (ns.RefreshPanel).
-- Groups: on a section of a group (B.Categories.GroupRow: Equipment, Consumables or Trade goods), the menu writes that group's row of the Bags page
-- as the options window does (ns.Set, Core.lua, which refreshes the module and so lays both windows out again, then ns.RefreshPanel), and notes
-- the change as the options window does (ns.PanelHome.Noted), so Home's Recent changes lists it and Ctrl+Z takes it back: with two choices
-- (Trade goods) one line, Split by kind or Join into one section; with three, the row's label and each of its choices (ns.Choices of its row in
-- Config.lua), the one in use ticked.

local B = ns.Bags
local Order = B.Order

-- The two shelves, which never move.
local SHELVES = { new = true, free = true }
-- How often the cursor is read while a title is dragged, in seconds; the width of the drop bar, and how far it lies from a section's edge, in the
-- content's units (the middle of BagsLayout's gap of 12 between sections); the opacity of the dragged title.
local DRAG_STEP, BAR_WIDTH, BAR_OFF, DRAG_ALPHA = 0.05, 2, 6, 0.5
-- The levels above the content frame the drop bar's frame lies at, over the item buttons.
local BAR_LEVEL = 50
local RESET_LINE = "Put the sections back in Flat UI's order"
local TIPS = {
	drag = "Drag the title to move this section. Right-click it to move it, or to put Flat UI's order back.",
	-- A section of Flat UI's own that can be hidden, and one of a group (B.Categories.GroupRow).
	dragHide = "Drag the title to move this section. Right-click it to move, hide or colour it, or to put Flat UI's order back.",
	dragGroup = "Drag the title to move this section. Right-click it to move, hide or colour it, to split its group by kind or join it into one, "
		.. "or to put Flat UI's order back.",
	keep = "Your pinned slots, in the order of your bags: nothing here is sorted, and after a clean up Flat UI puts each item back in its slot. "
		.. "Ctrl+right-click an item to pin or unpin its slot. Drag the title to move this section, or right-click it for more.",
	-- While Put pinned items back is off (BagsPins.lua).
	keepStill = "Your pinned slots, in the order of your bags: nothing here is sorted. Put pinned items back is off, so after a clean up "
		.. "right-click this title to put them back. Ctrl+right-click an item to pin or unpin its slot. Drag the title to move this section.",
	-- After each of them: what a click on the title does.
	fold = "Click to fold it.",
	unfold = "Folded: click to open it.",
	-- After those, on a section the player made (BagsCustom.lua).
	own = "Right-click it to rename, colour or delete this section of yours.",
}
local UNFOLD_ALL, FOLD_ALL = "Unfold every section", "Fold every section"
-- What a title's menu says in chat once it put back the items placed in its section, and once it brought them back (B.Categories.Unput).
local PUT_BACK = {
	one = "Flat UI: 1 item goes back to its own section. Right-click the title to bring it back.",
	many = "Flat UI: %d items go back to their own sections. Right-click the title to bring them back.",
	undo = "Bring back the %d items you put back",
	undoOne = "Bring back the item you put back",
	back = "Flat UI: %d items are back in %s.",
	backOne = "Flat UI: 1 item is back in %s.",
	backSome = "Flat UI: %d of the %d items are back in %s; the others are placed in another section now.",
	none = "Flat UI: nothing to bring back.",
	flash = "Back",
}
-- The line of a title's menu that places there every item the search finds (B.Categories.PlaceAll), what it says and how its section flashes.
local PLACE_ALL = {
	one = "Place the item that matches the search here",
	many = "Place the %d items that match the search here",
	sayOne = "Flat UI: 1 item is placed in %s.",
	say = "Flat UI: %d items are placed in %s.",
	flash = "Placed %d",
}
-- The sections an item the search finds is not placed from: the top shelf, Junk (so the sell list stays as it is) and Keep in place (its pins).
local PLACE_SKIP = { new = true, junk = true, keep = true }
-- After a title's tip, while items are placed in its section by hand.
local PLACED_TIP = { one = "1 item is placed here by hand.", many = "%d items are placed here by hand." }
-- After the tip of a click: what a Shift-click does, on a section among others open and on the one open alone.
local SHIFT_TIPS = { only = "Shift-click to open only this one.", all = "Shift-click to open every section again." }
-- The lines of a section's menu at the live bank, and what its tooltip says of them.
local BANK_LINES = {
	put = "Put %s in the bank",
	take = "Take %s out",
	putTip = "Right-click it to put it in the bank.",
	takeTip = "Right-click it to take it out of the bank.",
}
local FOLD_NONE = "No section is folded. Click a section's title in the bag window to fold it."
local FOLD_SAY = {
	all = "Flat UI: every bag section is open again.",
	one = "Flat UI: %s is open again.",
	none = "Flat UI: no bag section is folded.",
}
-- Hidden sections: the line of a title's menu, the title and first line of the menu that shows them again (the Hidden button after the last
-- section, BagsLayout.lua, and Show hidden sections), what the rows Folded sections and Hidden sections add after a label, and what is said.
local HIDE_LINE, SHOW_HIDDEN, SHOW_TITLE, SHOW_ALL = "Hide this section", "Show hidden sections (%d)", "Show again", "Show every hidden section"
local HIDDEN_MARK, UNUSED_MARK = " (hidden)", " (not in use now)"
local HIDDEN_NONE = "No section is hidden. Right-click a section's title in the bag window and choose Hide this section."
local HIDE_SAY = {
	hidden = "Flat UI: %s is hidden in both windows, and its items go to the sections that take them. Click Hidden after the last section to "
		.. "show it again.",
	all = "Flat UI: every hidden bag section shows again.",
	one = "Flat UI: %s shows again.",
	none = "Flat UI: no bag section is hidden.",
}
-- The words a section shown again flashes (B.Custom.Took), and how many hidden sections the tooltip of the Hidden button names before "and 3 more".
local SHOWN_FLASH, HIDDEN_NAMES = "Shown", 8
-- The lines of a title's menu that split a group of sections by kind or join it, for a row of two choices (Trade goods); a row of three (Equipment,
-- Consumables) lists its choices under its label, the one in use ticked.
local SPLIT_LINE, JOIN_LINE = "Split by kind", "Join into one section"

-- The drag under way: { key, title, st, parts }, or nil.
local drag = nil
-- Per content frame of a window: { box (a frame of this file's own that reads the cursor), bar (the drop bar) }.
local parts = setmetatable({}, { __mode = "k" })

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

-- Both windows are laid out again on the next pass.
local function Request()
	Call(B, "Request", "layout")
end

-- The window the player clicked a fold in keeps its height at that layout (B.Window.KeepHeight, BagsWindow.lua), so the title stays under the mouse:
-- the bag window hangs from its bottom right corner and would otherwise move the title by the height of the rows that folded. BagsWindow.lua keeps
-- it for the bag window alone, until the mouse leaves it. Asked before the layout only when the folds changed.
local function Keep(st)
	if type(st) == "table" then
		Call(B.Window, "KeepHeight", st.which)
	end
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

-- The item on the cursor, or nil.
local function Holding()
	local ok, kind = pcall(GetCursorInfo)
	return ok and not ns.IsSecret(kind) and kind == "item"
end

-- Red, green and blue of Highlight colour on the Windows page, which Bags takes.
local function Accent()
	local ok, r, g, b = pcall(ns.Colour, "windows.accent")
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return 0.85, 0.85, 0.85
end

-- The order -----------------------------------------------------------------------------------------------------------------------------------

-- FlatUIDB.bags.order, or nil when nothing is saved or the saved variables have not loaded.
local function Saved()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local order = type(bags) == "table" and bags.order or nil
	if type(order) == "table" and #order > 0 then
		return order
	end
	return nil
end

-- The built-in order of the sections that can move: the keys of B.Categories.LIST without the two shelves, with the sections the player made
-- (B.Custom.Keys, BagsCustom.lua) right after Keep in place, in the order they were made.
local function BuiltIn()
	local keys = {}
	local list = B.Categories and B.Categories.LIST
	local okMine, mine = pcall(Call, B.Custom, "Keys")
	mine = okMine and type(mine) == "table" and mine or {}
	local placed = false
	for _, entry in ipairs(type(list) == "table" and list or {}) do
		local key = type(entry) == "table" and entry.key or nil
		if type(key) == "string" and not SHELVES[key] then
			keys[#keys + 1] = key
			if key == "keep" then
				for _, own in ipairs(mine) do
					keys[#keys + 1] = own
				end
				placed = true
			end
		end
	end
	if not placed then
		for _, own in ipairs(mine) do
			keys[#keys + 1] = own
		end
	end
	return keys
end

local function IndexOf(list, key)
	for index, value in ipairs(list) do
		if value == key then
			return index
		end
	end
	return nil
end

-- The order in force: the saved keys merged with the built-in ones (see the top of the file). A new table each call.
function Order.List()
	local builtIn = BuiltIn()
	local saved = Saved()
	if not saved then
		return builtIn
	end
	local known = {}
	for _, key in ipairs(builtIn) do
		known[key] = true
	end
	local list, has = {}, {}
	for _, key in ipairs(saved) do
		if type(key) == "string" and known[key] and not has[key] then
			list[#list + 1] = key
			has[key] = true
		end
	end
	for index, key in ipairs(builtIn) do
		if not has[key] then
			local at = 0
			for before = index - 1, 1, -1 do
				local found = has[builtIn[before]] and IndexOf(list, builtIn[before])
				if found then
					at = found
					break
				end
			end
			table.insert(list, at + 1, key)
			has[key] = true
		end
	end
	return list
end

-- { [key] = rank } for BagsLayout.lua: the top shelf 0, the sections 1 on, Free slots after them.
function Order.Ranks()
	local list = Order.List()
	local ranks = { new = 0 }
	for index, key in ipairs(list) do
		ranks[key] = index
	end
	ranks.free = #list + 1
	return ranks
end

-- Writes the order, or takes it away when it is the built-in one. False before the saved variables load.
local function Write(list)
	local db = ns.Account()
	if type(db) ~= "table" then
		return false
	end
	local builtIn = BuiltIn()
	local same = list == nil or #list == #builtIn
	if list ~= nil and same then
		for index, key in ipairs(builtIn) do
			if list[index] ~= key then
				same = false
				break
			end
		end
	end
	if same then
		if type(db.bags) == "table" then
			db.bags.order = nil
		end
		return true
	end
	if type(db.bags) ~= "table" then
		db.bags = {}
	end
	db.bags.order = list
	return true
end

-- Puts the section key just before or just after the section target. True when the order changed.
function Order.Move(key, target, after)
	if type(key) ~= "string" or type(target) ~= "string" or key == target or SHELVES[key] or SHELVES[target] then
		return false
	end
	local list = Order.List()
	local from = IndexOf(list, key)
	if not from then
		return false
	end
	local was = table.concat(list, ",")
	table.remove(list, from)
	local to = IndexOf(list, target)
	if not to then
		return false
	end
	table.insert(list, after and to + 1 or to, key)
	if table.concat(list, ",") == was then
		return false
	end
	return Write(list)
end

-- Puts Flat UI's own order back. True when one was saved.
function Order.Reset()
	if not Saved() then
		return false
	end
	Write(nil)
	Request()
	return true
end

-- The folds ---------------------------------------------------------------------------------------------------------------------------------

-- FlatUIDB.bags.folded, or nil when no section is folded or the saved variables have not loaded.
local function Folds()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local folded = type(bags) == "table" and bags.folded or nil
	if type(folded) == "table" and next(folded) ~= nil then
		return folded
	end
	return nil
end

-- True when the section key is folded.
function Order.Folded(key)
	local folded = Folds()
	return folded ~= nil and type(key) == "string" and folded[key] == true
end

-- Folds the section key, or opens it with on false; an empty set is not kept. True when the folds changed; false before the saved variables load.
local function SetFold(key, on)
	local db = ns.Account()
	if type(db) ~= "table" or type(key) ~= "string" or SHELVES[key] then
		return false
	end
	if on then
		if type(db.bags) ~= "table" then
			db.bags = {}
		end
		if type(db.bags.folded) ~= "table" then
			db.bags.folded = {}
		end
		if db.bags.folded[key] == true then
			return false
		end
		db.bags.folded[key] = true
		return true
	end
	local folded = Folds()
	if not folded or folded[key] ~= true then
		return false
	end
	folded[key] = nil
	if next(folded) == nil then
		db.bags.folded = nil
	end
	return true
end

-- Opens every folded section. True when one was folded.
-- st: the window's layout when the player asked it there (a Shift-click or its menu), which keeps that window's height (Keep); nil from the row.
function Order.UnfoldAll(st)
	local db = ns.Account()
	if not Folds() or type(db) ~= "table" or type(db.bags) ~= "table" then
		return false
	end
	db.bags.folded = nil
	Keep(st)
	Request()
	return true
end

-- The drag -------------------------------------------------------------------------------------------------------------------------------------

-- True for a section of the Sections view whose title can be dragged.
local function Movable(st, sec)
	return type(st) == "table" and type(sec) == "table" and st.view == "sections" and st.content ~= nil and not sec.block and not sec.strip
		and type(sec.key) == "string" and not SHELVES[sec.key] and not sec.add and not sec.unhide
end

-- Whether the cursor is over the part of the window that shows the content (its scroll frame, the parent of the content's parent).
local function InView(content)
	local ok, child = pcall(content.GetParent, content)
	local scroll = ok and type(child) == "table" and not ns.IsSecret(child) and select(2, pcall(child.GetParent, child)) or nil
	if type(scroll) ~= "table" or ns.IsSecret(scroll) or type(scroll.IsMouseOver) ~= "function" then
		return true
	end
	local okOver, over = pcall(scroll.IsMouseOver, scroll)
	return okOver and not ns.IsSecret(over) and over == true
end

-- The section under the cursor while a title is dragged, its title, and whether the drop goes after it; nil when there is none.
local function Target()
	local st = drag and drag.st
	if not st or not InView(st.content) then
		return nil
	end
	local okCursor, cx, cy = pcall(GetCursorPosition)
	if not (okCursor and ns.Finite(cx) and ns.Finite(cy)) then
		return nil
	end
	for index = 1, st.used or 0 do
		local title = st.titles[index]
		local sec = title and title.sec
		if sec and sec.key ~= drag.key and Movable(st, sec) then
			local frame = title.frame
			local scale = Number(frame, "GetEffectiveScale")
			local left, top, width = Number(frame, "GetLeft"), Number(frame, "GetTop"), Number(frame, "GetWidth")
			if scale and scale > 0 and left and top and width then
				local x, y = cx / scale, cy / scale
				local bottom = top - (ns.Finite(sec.height) and sec.height or (Number(frame, "GetHeight") or 0))
				if x >= left - BAR_OFF and x <= left + width + BAR_OFF and y <= top and y >= bottom then
					return title, x > left + width / 2
				end
			end
		end
	end
	return nil
end

-- The drop bar beside the target, or hidden.
local function ShowBar(title, after)
	local bar = drag.parts.bar
	if not title then
		bar:Hide()
		return
	end
	local st, sec = drag.st, title.sec
	local width = Number(title.frame, "GetWidth") or 0
	local x
	if after then
		-- A section that ends at the window's right edge has its bar just inside it.
		x = (ns.Finite(sec.x) and ns.Finite(st.width) and sec.x + width >= st.width - 1) and -BAR_WIDTH or (BAR_OFF - BAR_WIDTH / 2)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", title.frame, "TOPRIGHT", x, 0)
	else
		-- A section at the window's left edge has its bar just inside it.
		x = (ns.Finite(sec.x) and sec.x <= 0) and BAR_WIDTH or -(BAR_OFF - BAR_WIDTH / 2)
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", title.frame, "TOPLEFT", x, 0)
	end
	bar:SetSize(BAR_WIDTH, math.max(1, ns.Finite(sec.height) and sec.height or (st.titleH or 16)))
	bar:SetColorTexture(Accent())
	bar:Show()
end

-- Ends the drag; with move, the section goes where the cursor is now.
local function Finish(move)
	local was = drag
	if not was then
		return
	end
	local title, after
	if move then
		title, after = Target()
	end
	drag = nil
	pcall(was.title.frame.SetAlpha, was.title.frame, 1)
	was.parts.bar:Hide()
	if was.parts.box:IsShown() then
		was.parts.box:Hide()
	end
	if title and title.sec and Order.Move(was.key, title.sec.key, after) then
		Request()
	end
end

-- The frames of a window's content frame, made the first time a title of it is dragged.
local function Parts(content)
	local made = parts[content]
	if made then
		return made
	end
	local box = Own(CreateFrame("Frame", nil, content))
	box:SetSize(1, 1)
	box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	local level = Number(content, "GetFrameLevel") or 0
	box:SetFrameLevel(level + BAR_LEVEL)
	box:Hide()
	local bar = Own(box:CreateTexture(nil, "OVERLAY"))
	bar:Hide()
	made = { box = box, bar = bar }
	local wait = 0
	box:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - (ns.Finite(elapsed) and elapsed or 0)
		if wait > 0 or not drag or drag.parts ~= made then
			return
		end
		wait = DRAG_STEP
		local okDown, down = pcall(IsMouseButtonDown, "LeftButton")
		if okDown and not ns.IsSecret(down) and not down then
			-- Let go with no OnDragStop heard (the title hid meanwhile): the drop counts where the cursor is.
			Call(B, "Part", "order", Finish, true)
			return
		end
		Call(B, "Part", "order", function()
			ShowBar(Target())
		end)
	end)
	-- The window hiding ends the drag with no move.
	box:SetScript("OnHide", function()
		if drag and drag.parts == made then
			Call(B, "Part", "order", Finish, false)
		end
	end)
	parts[content] = made
	return made
end

-- OnDragStart of a title (BagsLayout.lua).
function Order.DragStart(title)
	local st, sec = title and title.st, title and title.sec
	if drag or not Movable(st, sec) or Holding() then
		return
	end
	local made = Parts(st.content)
	drag = { key = sec.key, title = title, st = st, parts = made }
	pcall(title.frame.SetAlpha, title.frame, DRAG_ALPHA)
	made.bar:Hide()
	made.box:Show()
end

-- OnDragStop of a title: the section goes where the cursor is.
function Order.DragStop()
	Finish(true)
end

-- Ends a drag in that window ("bags", "bank"; nil for either) with no move: the window closed.
function Order.Cancel(which)
	if drag and (which == nil or drag.st.which == which) then
		Finish(false)
	end
end

-- Hidden sections and groups ---------------------------------------------------------------------------------------------------------------------

-- The label of a section key (B.Categories.Label), else the key.
local function SectionLabel(key)
	local ok, label = pcall(Call, B.Categories, "Label", key)
	if ok and type(label) == "string" and not ns.IsSecret(label) and label ~= "" then
		return label
	end
	return key
end

-- Sorts section keys in the order the windows show them (Order.Ranks), else by key.
local function ByRank(keys)
	if #keys < 2 then
		return keys
	end
	local ranks = Order.Ranks()
	table.sort(keys, function(a, b)
		local ra, rb = ranks[a] or math.huge, ranks[b] or math.huge
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return keys
end

-- The hidden sections (B.Categories.HiddenKeys), in the order the windows show them; with now, only those the rows of the Sections part show now.
local function HiddenNow(now)
	local ok, keys = pcall(Call, B.Categories, "HiddenKeys", now)
	return ByRank(ok and type(keys) == "table" and keys or {})
end

-- The options window shows the rows again (ns.RefreshPanel, Panel.lua), when it is open.
local function Repaint()
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
end

-- Hides a section, or shows it again with on false (B.Categories.SetHidden lays both windows out again), and shows the options window's rows again
-- unless the row Hidden sections asked (row), which the options window draws again itself. True when it changed.
local function SetHidden(key, on, row)
	local ok, changed = pcall(Call, B.Categories, "SetHidden", key, on)
	if ok and changed == true then
		if not row then
			Repaint()
		end
		return true
	end
	return false
end

local function ShowAll(row)
	local ok, changed = pcall(Call, B.Categories, "ShowAll")
	if ok and changed == true then
		if row ~= true then
			Repaint()
		end
		return true
	end
	return false
end

-- The menu of the Hidden button after the last section (BagsLayout.lua), and of Show hidden sections in a title's menu: each hidden section the
-- rows show now, which a click shows again, after a line that shows them all while two or more are hidden. Under anchor, for st's window.
-- A pick says in chat what shows again, as Hide this section says what hid, and the section shown again flashes Shown at its next placing in that
-- window (B.Custom.Took), as a section brought back flashes Back.
function Order.HiddenMenu(st, anchor)
	local keys = HiddenNow(true)
	local which = type(st) == "table" and st.which or nil
	local items = {}
	if #keys >= 2 then
		items[1] = { text = SHOW_ALL, part = "order", pick = function()
			if ShowAll() then
				print(HIDE_SAY.all)
			end
		end }
	end
	for _, key in ipairs(keys) do
		items[#items + 1] = { text = (SectionLabel(key):gsub("|", "||")), part = "order", pick = function()
			if SetHidden(key, false) then
				print(HIDE_SAY.one:format((SectionLabel(key):gsub("|", "||"))))
				Call(B, "Part", "custom", Call, B.Custom, "Took", which, key, nil, nil, SHOWN_FLASH)
			end
		end }
	end
	Call(B.Layout, "Menu", anchor, SHOW_TITLE, items, which)
end

-- How many hidden sections the rows show now, for the Hidden button's title (BagsLayout.lua).
function Order.HiddenCount()
	return #HiddenNow(true)
end

-- The hidden sections the rows show now by their labels, in the order the windows show them, as one text ("Potions, Rings and Junk"; after
-- HIDDEN_NAMES of them "and 3 more"), for the tooltip of the Hidden button (BagsLayout.lua); nil while none is hidden.
function Order.HiddenLabels()
	local keys = HiddenNow(true)
	local labels = {}
	for index = 1, math.min(#keys, HIDDEN_NAMES) do
		labels[index] = SectionLabel(keys[index])
	end
	if #labels == 0 then
		return nil
	end
	local more = #keys - #labels
	if more > 0 then
		return ("%s and %d more"):format(table.concat(labels, ", "), more)
	end
	if #labels == 1 then
		return labels[1]
	end
	return ("%s and %s"):format(table.concat(labels, ", ", 1, #labels - 1), labels[#labels])
end

-- Writes a row of the Bags page from a title's menu as the options window writes it (ns.Set), which refreshes the module and so lays both windows
-- out again, notes the change as the options window notes one (ns.PanelHome.Noted with the row of Config.lua, ns.Def), so Home's Recent changes
-- lists it with its Undo and Ctrl+Z takes it back, then shows the options window's rows again.
local function SetRow(path, value)
	local before = ns.Get(path)
	if before == value then
		return
	end
	ns.Set(path, value)
	local home = ns.PanelHome
	local def = type(ns.Def) == "function" and ns.Def(path) or nil
	if type(home) == "table" and type(home.Noted) == "function" and type(def) == "table" then
		pcall(home.Noted, def, before, ns.Get(path))
	end
	Repaint()
	Request()
end

-- The lines of a title's menu for the row that shows its section's group as one or apart (B.Categories.GroupRow): with two choices, Split by kind
-- or Join into one section; with more, the row's label and each of its choices (ns.Choices of its row, Config.lua), the one in use ticked.
local function GroupLines(key, items)
	local okRow, row = pcall(Call, B.Categories, "GroupRow", key)
	if not okRow or type(row) ~= "string" then
		return
	end
	local path = "bags." .. row
	local def = type(ns.Def) == "function" and ns.Def(path) or nil
	local choices = def and type(ns.Choices) == "function" and ns.Choices(def) or {}
	local value = ns.Get(path)
	if #choices == 2 then
		local one = value == choices[1][1]
		items[#items + 1] = { text = one and SPLIT_LINE or JOIN_LINE, part = "order", pick = function()
			SetRow(path, one and choices[2][1] or choices[1][1])
		end }
		return
	end
	if #choices < 2 then
		return
	end
	items[#items + 1] = { text = type(def.label) == "string" and def.label or row, header = true }
	for _, choice in ipairs(choices) do
		local id = choice[1]
		items[#items + 1] = { text = tostring(choice[2]), tick = value == id, part = "order", pick = function()
			SetRow(path, id)
		end }
	end
end

-- The menu and the tooltip ------------------------------------------------------------------------------------------------------------------------

-- True when a section's menu can move its items at the bank: Flat UI's bank window is the live bank (B.Bank.Live), the window shows the player's
-- own live slots, and the section is not Keep in place.
local function Banking(st, sec)
	if not (st.mine and st.live) or sec.key == "keep" then
		return false
	end
	-- Deposit and Take out off leaves the section's lines out too, as that row says.
	local okRow, buttons = pcall(Call, B, "Opt", "bankButtons")
	if okRow and buttons == false then
		return false
	end
	local ok, live = pcall(Call, B.Bank, "Live")
	return ok and live == true
end

-- Folds every section the window shows but the one keyed except (nil for none), which opens. True when the folds changed.
function Order.FoldAll(st, except)
	local changed = false
	for _, sec in ipairs(type(st) == "table" and st.sections or {}) do
		if Movable(st, sec) and SetFold(sec.key, sec.key ~= except) then
			changed = true
		end
	end
	if changed then
		Keep(st)
		Request()
	end
	return changed
end

-- True when the section is open and every other the window shows is folded.
local function Alone(st, sec)
	if Order.Folded(sec.key) then
		return false
	end
	for _, other in ipairs(st.sections or {}) do
		if other ~= sec and Movable(st, other) and not Order.Folded(other.key) then
			return false
		end
	end
	return true
end

local function Shifted()
	local ok, down = pcall(IsShiftKeyDown)
	return ok and not ns.IsSecret(down) and down == true
end

-- Folds the section, or opens it, alone. True when it changed.
local function Toggle(st, sec)
	if not Movable(st, sec) or not SetFold(sec.key, not Order.Folded(sec.key)) then
		return false
	end
	Keep(st)
	Request()
	return true
end

-- A left click on a title that can be dragged, with no item on the cursor (BagsLayout.lua's TitleClick): the section folds to its title, or opens
-- again, in both windows. With Shift it opens alone, every other section the window shows folded, or, open alone already, opens them all. True
-- when it changed.
function Order.Fold(st, sec)
	if not Movable(st, sec) then
		return false
	end
	if Shifted() then
		if Alone(st, sec) then
			return Order.UnfoldAll(st)
		end
		return Order.FoldAll(st, sec.key)
	end
	return Toggle(st, sec)
end

-- How many items are placed by hand in a section as the windows show it (B.Categories.PlacedCount), 0 for Keep in place and Junk, which take no
-- placement.
local function PlacedHere(key)
	if key == "keep" or key == "junk" then
		return 0
	end
	local ok, count = pcall(Call, B.Categories, "PlacedCount", key)
	return ok and ns.Finite(count) and count or 0
end

-- The line of a title's menu that puts back the items placed in it: "Put back the 3 items placed here", or on a section of the player's own,
-- which holds nothing else, "Empty this section (3 items)".
local function PutBackText(key, count)
	local okOwn, own = pcall(Call, B.Custom, "Is", key)
	if okOwn and own == true then
		return ("Empty this section (%d %s)"):format(count, count == 1 and "item" or "items")
	end
	return count == 1 and "Put back the item placed here" or ("Put back the %d items placed here"):format(count)
end

-- The line of a title's menu that brings back what the last put back of its section took away (B.Categories.LastPutBack, Unput), until the next put
-- back or a reload: one line in chat, n of m when some are placed in another section since, and the section flashes Back.
local function BackLines(st, key, items, label)
	local okLast, count, lastKey = pcall(Call, B.Categories, "LastPutBack")
	if not (okLast and ns.Finite(count) and count > 0 and lastKey == key) then
		return
	end
	items[#items + 1] = { text = count == 1 and PUT_BACK.undoOne or PUT_BACK.undo:format(count), part = "order", pick = function()
		local back, total = Call(B.Categories, "Unput")
		if not (ns.Finite(back) and back > 0) then
			print(PUT_BACK.none)
			return
		end
		if ns.Finite(total) and back < total then
			print(PUT_BACK.backSome:format(back, total, label))
		else
			print(back == 1 and PUT_BACK.backOne:format(label) or PUT_BACK.back:format(back, label))
		end
		Call(B, "Part", "custom", Call, B.Custom, "Took", st.which, key, nil, nil, PUT_BACK.flash)
	end }
end

-- While a search is typed (B.Search.Active), the line of a title's menu that places in its section every item the window shows that the search
-- finds (B.Search.Match) and that is in another section, but not in New items, Junk or Keep in place (PLACE_SKIP), by B.Categories.PlaceAll: on a
-- section that holds items placed by hand (B.Categories.Placeable: not Keep in place or Junk). The cells of the layout (st.cells) hold every item
-- the window shows, the items of a folded section too. Placements are by item ID for the account, so it works in the bank window and for another
-- character as well. One line in chat, and the section flashes Placed 7.
local function PlaceLines(st, key, items, label)
	if Call(B.Search, "Active") ~= true or PLACE_SKIP[key] then
		return
	end
	local okPlace, placeable = pcall(Call, B.Categories, "Placeable", key)
	if not (okPlace and placeable == true) or type(st.cells) ~= "table" then
		return
	end
	local records, seen = {}, {}
	for _, entry in pairs(st.cells) do
		local record = type(entry) == "table" and entry.record or nil
		local id = type(record) == "table" and record.id or nil
		if ns.Finite(id) and not seen[id] then
			local okMatch, match = pcall(Call, B.Search, "Match", record)
			if okMatch and match == true then
				local okOf, of = pcall(Call, B.Categories, "Of", record)
				if okOf and type(of) == "string" and of ~= key and not PLACE_SKIP[of] then
					seen[id] = true
					records[#records + 1] = record
				end
			end
		end
	end
	local n = #records
	if n == 0 then
		return
	end
	items[#items + 1] = { text = n == 1 and PLACE_ALL.one or PLACE_ALL.many:format(n), part = "order", pick = function()
		local count = Call(B.Categories, "PlaceAll", key, records)
		if not (ns.Finite(count) and count > 0) then
			return
		end
		print(count == 1 and PLACE_ALL.sayOne:format(label) or PLACE_ALL.say:format(count, label))
		Call(B, "Part", "custom", Call, B.Custom, "Took", st.which, key, nil, nil, PLACE_ALL.flash:format(count))
	end }
end

-- The menu of a title (a right click with no item on the cursor), under anchor.
function Order.Menu(st, sec, anchor)
	if not Movable(st, sec) then
		return
	end
	-- folded: a section the window shows is folded, so Unfold every section changes what it shows (a fold of a hidden section, or of a kind of a
	-- group its row does not show now, is kept and shows nothing).
	local shown, open, folded = {}, false, false
	for _, other in ipairs(st.sections or {}) do
		if Movable(st, other) then
			shown[#shown + 1] = other.key
			local isFolded = Order.Folded(other.key)
			open = open or not isFolded
			folded = folded or isFolded
		end
	end
	local key = sec.key
	local at = IndexOf(shown, key)
	local items = {}
	local label = type(sec.label) == "string" and sec.label:gsub("|", "||") or key
	local function Line(text, target, after)
		items[#items + 1] = { text = text, part = "order", pick = function()
			if Order.Move(key, target, after) then
				Request()
			end
		end }
	end
	if at and at > 1 then
		Line("Move to the top", shown[1], false)
		Line("Move up", shown[at - 1], false)
	end
	if at and at < #shown then
		Line("Move down", shown[at + 1], true)
		Line("Move to the bottom", shown[#shown], true)
	end
	-- The items placed here by hand go back to their own sections (B.Categories.PutBack); on a section of the player's own that empties it.
	local placed = PlacedHere(key)
	if placed > 0 then
		items[#items + 1] = { text = PutBackText(key, placed), part = "order", pick = function()
			local count = Call(B.Categories, "PutBack", key)
			if ns.Finite(count) and count > 0 then
				print(count == 1 and PUT_BACK.one or PUT_BACK.many:format(count))
			end
		end }
	end
	BackLines(st, key, items, label)
	PlaceLines(st, key, items, label)
	items[#items + 1] = { text = Order.Folded(key) and "Unfold" or "Fold", part = "order", pick = function()
		Toggle(st, sec)
	end }
	-- A section of Flat UI's own but Other hides, in both windows (B.Categories.SetHidden); a section of the player's own has Delete instead.
	local okHide, hideable = pcall(Call, B.Categories, "Hideable", key)
	if okHide and hideable == true then
		items[#items + 1] = { text = HIDE_LINE, part = "order", pick = function()
			if SetHidden(key, true) then
				print(HIDE_SAY.hidden:format(SectionLabel(key)))
			end
		end }
	end
	-- The row that shows the section's group as one section or apart (Equipment, Consumables, Trade goods).
	GroupLines(key, items)
	-- At the live bank, the section's items go into the bank from the bag window, or out of it from the bank window, by the pass of Deposit and Take
	-- out (BagsBank.lua) with the section in place of the search. Not Keep in place, whose items stay in their pinned slots.
	if Banking(st, sec) then
		local function Mine(record)
			return Call(B.Categories, "Of", record) == key
		end
		if st.which == "bags" then
			items[#items + 1] = { text = BANK_LINES.put:format(label), part = "bank", pick = function()
				Call(B.Bank, "Deposit", Mine)
				Call(B, "Request", "footer")
			end }
		else
			items[#items + 1] = { text = BANK_LINES.take:format(label), part = "bank", pick = function()
				Call(B.Bank, "TakeOut", Mine)
				Call(B, "Request", "footer")
			end }
		end
	end
	if Saved() then
		items[#items + 1] = { text = RESET_LINE, part = "order", pick = Order.Reset }
	end
	if open then
		items[#items + 1] = { text = FOLD_ALL, part = "order", pick = function()
			Order.FoldAll(st)
		end }
	end
	if folded then
		items[#items + 1] = { text = UNFOLD_ALL, part = "order", pick = function()
			Order.UnfoldAll(st)
		end }
	end
	-- While a section the rows show is hidden, the menu of the Hidden button opens from here too.
	local hidden = #HiddenNow(true)
	if hidden > 0 then
		items[#items + 1] = { text = SHOW_HIDDEN:format(hidden), part = "order", pick = function()
			Order.HiddenMenu(st, anchor)
		end }
	end
	if key == "keep" then
		local more = Call(B.Pins, "MenuLines")
		for _, item in ipairs(type(more) == "table" and more or {}) do
			items[#items + 1] = item
		end
	end
	-- Rename and Delete this section on a section the player made, and New section in the player's own bag window (BagsCustom.lua).
	local okOwn, own = pcall(Call, B.Custom, "MenuLines", st, sec, anchor)
	for _, item in ipairs(okOwn and type(own) == "table" and own or {}) do
		items[#items + 1] = item
	end
	Call(B.Layout, "Menu", anchor, label, items, st.which)
end

-- The line of a title's tooltip while the cursor holds no item: how to move the section, or what Keep in place is, as Put pinned items back
-- says, then what a click on it does (fold it, or open it while it is folded). Nil for a title that cannot be dragged.
function Order.Tip(st, sec)
	if not Movable(st, sec) then
		return nil
	end
	local click = (Order.Folded(sec.key) and TIPS.unfold or TIPS.fold) .. " " .. (Alone(st, sec) and SHIFT_TIPS.all or SHIFT_TIPS.only)
	if Banking(st, sec) then
		click = click .. " " .. (st.which == "bags" and BANK_LINES.putTip or BANK_LINES.takeTip)
	end
	if sec.key ~= "keep" then
		local okOwn, own = pcall(Call, B.Custom, "Is", sec.key)
		if okOwn and own == true then
			click = click .. " " .. TIPS.own
		end
		-- A section of the player's own holds only what was placed in it, so only Flat UI's own say it.
		local placed = (okOwn and own == true) and 0 or PlacedHere(sec.key)
		if placed > 0 then
			click = click .. " " .. (placed == 1 and PLACED_TIP.one or PLACED_TIP.many:format(placed))
		end
		-- What the menu does besides moving: hide a section of Flat UI's own, and split or join its group.
		local drag = TIPS.drag
		local okHide, hideable = pcall(Call, B.Categories, "Hideable", sec.key)
		if okHide and hideable == true then
			local okRow, row = pcall(Call, B.Categories, "GroupRow", sec.key)
			drag = (okRow and type(row) == "string") and TIPS.dragGroup or TIPS.dragHide
		end
		return drag .. " " .. click
	end
	local ok, moves = pcall(Call, B, "Opt", "pinMoves")
	return ((ok and moves == false) and TIPS.keepStill or TIPS.keep) .. " " .. click
end

-- The row Section order -----------------------------------------------------------------------------------------------------------------------

function ns.BagsOrderLines()
	if Saved() then
		return { { "reset", RESET_LINE } }
	end
	return { { "none", "The sections are in Flat UI's order. Drag a section's title in the bag window to move it." } }
end

function ns.BagsOrderPick(id)
	if id ~= "reset" or not Order.Reset() then
		return false, "Flat UI: the bag sections are in Flat UI's order already."
	end
	return true, "Flat UI: the bag sections are back in Flat UI's order."
end

-- The row Folded sections ---------------------------------------------------------------------------------------------------------------------

-- True for a section the player hid (B.Categories.Hidden), which the rows mark.
local function IsHidden(key)
	local ok, hidden = pcall(Call, B.Categories, "Hidden", key)
	return ok and hidden == true
end

-- Every folded section by its label, in the order the windows show them, a hidden one marked so (it keeps its fold while hidden), and one the rows
-- do not show now (Rings with Equipment at One section, B.Categories.Exists) marked (not in use now), as Hidden sections marks it.
function ns.BagsFoldLines()
	local folded = Folds()
	if not folded then
		return { { "none", FOLD_NONE } }
	end
	local keys = {}
	for key in pairs(folded) do
		if type(key) == "string" then
			keys[#keys + 1] = key
		end
	end
	ByRank(keys)
	local lines = {}
	if #keys >= 2 then
		lines[1] = { "all", UNFOLD_ALL }
	end
	for _, key in ipairs(keys) do
		local okExists, exists = pcall(Call, B.Categories, "Exists", key)
		local okOwn, own = pcall(Call, B.Custom, "Is", key)
		local unused = okExists and exists == false and not (okOwn and own == true)
		lines[#lines + 1] = { "fold:" .. key, SectionLabel(key) .. (IsHidden(key) and HIDDEN_MARK or "") .. (unused and UNUSED_MARK or "") }
	end
	return lines
end

function ns.BagsFoldPick(id)
	if id == "all" then
		if Order.UnfoldAll() then
			return true, FOLD_SAY.all
		end
		return false, FOLD_SAY.none
	end
	local key = type(id) == "string" and id:match("^fold:(.+)$") or nil
	if not key or not SetFold(key, false) then
		return false, FOLD_SAY.none
	end
	Request()
	return true, FOLD_SAY.one:format(SectionLabel(key))
end

-- The row Hidden sections ---------------------------------------------------------------------------------------------------------------------

-- Every hidden section by its label, in the order the windows show them, one the rows do not show now (Jewellery with Equipment at Each kind)
-- marked so, after a line that shows them all while two or more are hidden; with none, one line that says how to hide one.
function ns.BagsHiddenLines()
	local keys = HiddenNow(false)
	if #keys == 0 then
		return { { "none", HIDDEN_NONE } }
	end
	local lines = {}
	if #keys >= 2 then
		lines[1] = { "all", SHOW_ALL }
	end
	for _, key in ipairs(keys) do
		local ok, exists = pcall(Call, B.Categories, "Exists", key)
		lines[#lines + 1] = { "hidden:" .. key, SectionLabel(key) .. ((ok and exists == false) and UNUSED_MARK or "") }
	end
	return lines
end

-- Shows one hidden section again, or every one ("all"), with the page on or off; a window that shows is laid out again.
function ns.BagsHiddenPick(id)
	if id == "all" then
		if ShowAll(true) then
			return true, HIDE_SAY.all
		end
		return false, HIDE_SAY.none
	end
	local key = type(id) == "string" and id:match("^hidden:(.+)$") or nil
	if not key or not SetHidden(key, false, true) then
		return false, HIDE_SAY.none
	end
	return true, HIDE_SAY.one:format(SectionLabel(key))
end
