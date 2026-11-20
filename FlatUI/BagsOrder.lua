local _, ns = ...

-- Bags: the order the sections are shown in, which the player sets by dragging a section's title or from its menu. Bags.lua makes ns.Bags with
-- B.Order; this file only adds its fields, makes frames and textures of its own only, and owns no event. The order is display alone: which section
-- an item is filed in (B.Categories.Of, BagsCategories.lua) never changes with it.
--
-- The order is one list of section keys for the whole account, in FlatUIDB.bags.order beside the placements by hand (a new layout of BagsData's
-- record resets only its v and chars, BagsData.lua:581-600), so the bag window, the bank window and every character's view show the same order.
-- Order.Ranks merges it with the built-in order (B.Categories.LIST): the saved keys in their saved order, unknown ones left out, then each built-in
-- key that is not saved right after the nearest key before it in LIST, so a section added later lands at its built-in place; with nothing saved
-- the result is LIST. A move writes the whole merged list, the sections of the Equipment family that the Equipment row hides included, so they
-- keep their places when that row changes, and a list that equals LIST again is not kept. The top shelf (New items or Added) always comes first
-- and Free slots always last: they are shelves, not sections, and never move. BagsLayout.lua reads the ranks when it lays a window out.
--
-- The drag: each title is a button of Flat UI's own (BagsLayout.lua), which BagsLayout registers for a drag with the left button
-- (RegisterForDrag) and whose OnDragStart and OnDragStop come here. A drag gives no click, so the drop of an item on a title and the click on
-- the top shelf's title stay as they are. No drag starts while the cursor holds an item (that is a drop, GetCursorInfo), from the top shelf, Free
-- slots or a bag of Bag by bag, or outside the Sections view; any other section can be dragged, in both windows and for every character. While a
-- title is dragged it fades to half (SetAlpha on the title of Flat UI's own), and a frame of this file's own in the window's content reads the
-- cursor every 0.05 seconds (GetCursorPosition over the title's GetEffectiveScale, GetLeft, GetTop and GetWidth, and the section's height from the
-- layout): the section under the cursor, title and cells, is the target, and the drop goes before it when the cursor is left of its middle, else
-- after it. A bar 2 units wide in the Highlight colour of the Windows page marks the place in the gap beside it. Letting go there moves the section
-- and lays both windows out again (B.Request); letting go elsewhere, the window hiding, or the left button found up with no drop heard
-- (IsMouseButtonDown) changes nothing. The cursor counts only while it is over the window's scroll area (IsMouseOver), so a section scrolled out
-- of sight is never the target. There is no scrolling while dragging; the wheel still scrolls.
--
-- The menu: a right click on a title that can be dragged, with no item on the cursor, opens a menu of BagsLayout's (Layout.Menu) with Move to the
-- top, Move up, Move down and Move to the bottom, among the sections that window shows, and while an order is saved, a line that puts Flat UI's
-- order back. On Keep in place it also has BagsPins.lua's lines. The row Section order on the Bags page does the same reset. Moving sections
-- works in a fight: it only lays the windows out, and their buttons are not protected (BagsLayout.lua).

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
	keep = "Your pinned slots, in the order of your bags: nothing here is sorted, and after a clean up Flat UI puts each item back in its slot. "
		.. "Ctrl+right-click an item to pin or unpin its slot. Drag the title to move this section, or right-click it for more.",
}

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

-- The built-in order of the sections that can move: the keys of B.Categories.LIST without the two shelves.
local function BuiltIn()
	local keys = {}
	local list = B.Categories and B.Categories.LIST
	for _, entry in ipairs(type(list) == "table" and list or {}) do
		local key = type(entry) == "table" and entry.key or nil
		if type(key) == "string" and not SHELVES[key] then
			keys[#keys + 1] = key
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

-- The drag -------------------------------------------------------------------------------------------------------------------------------------

-- True for a section of the Sections view whose title can be dragged.
local function Movable(st, sec)
	return type(st) == "table" and type(sec) == "table" and st.view == "sections" and st.content ~= nil and not sec.block and not sec.strip
		and type(sec.key) == "string" and not SHELVES[sec.key]
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

-- The menu and the tooltip ------------------------------------------------------------------------------------------------------------------------

-- The menu of a title (a right click with no item on the cursor), under anchor.
function Order.Menu(st, sec, anchor)
	if not Movable(st, sec) then
		return
	end
	local shown = {}
	for _, other in ipairs(st.sections or {}) do
		if Movable(st, other) then
			shown[#shown + 1] = other.key
		end
	end
	local key = sec.key
	local at = IndexOf(shown, key)
	local items = {}
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
	if Saved() then
		items[#items + 1] = { text = RESET_LINE, part = "order", pick = Order.Reset }
	end
	if key == "keep" then
		local more = Call(B.Pins, "MenuLines")
		for _, item in ipairs(type(more) == "table" and more or {}) do
			items[#items + 1] = item
		end
	end
	if #items == 0 then
		items[1] = { text = "Drag a title to move its section.", header = true }
	end
	local label = type(sec.label) == "string" and sec.label:gsub("|", "||") or key
	Call(B.Layout, "Menu", anchor, label, items, st.which)
end

-- The line of a title's tooltip while the cursor holds no item: how to move the section, or what Keep in place is. Nil for a title that cannot
-- be dragged.
function Order.Tip(st, sec)
	if not Movable(st, sec) then
		return nil
	end
	return sec.key == "keep" and TIPS.keep or TIPS.drag
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
