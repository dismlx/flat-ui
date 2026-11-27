local _, ns = ...

local B = ns.Bags
local Order = B.Order

local SHELVES = { new = true, free = true }
local DRAG_STEP, BAR_WIDTH, BAR_OFF, DRAG_ALPHA = 0.05, 2, 6, 0.5
local BAR_LEVEL = 50
local RESET_LINE = "Put the sections back in Flat UI's order"
local TIPS = {
	drag = "Drag the title to move this section. Right-click it to move it, or to put Flat UI's order back.",
	dragHide = "Drag the title to move this section. Right-click it to move, colour or delete it, or to put Flat UI's order back.",
	dragGroup = "Drag the title to move this section. Right-click it to move, colour or delete it, to split its group by kind or join it into one, "
		.. "or to put Flat UI's order back.",
	keep = "Your pinned slots, in the order of your bags: nothing here is sorted, and after a clean up Flat UI puts each item back in its slot. "
		.. "Ctrl+right-click an item to pin or unpin its slot. Drag the title to move this section, or right-click it for more.",
	keepStill = "Your pinned slots, in the order of your bags: nothing here is sorted. Put pinned items back is off, so after a clean up "
		.. "right-click this title to put them back. Ctrl+right-click an item to pin or unpin its slot. Drag the title to move this section.",
	fold = "Click to fold it.",
	unfold = "Folded: click to open it.",
	own = "Right-click it to rename, colour or delete this section of yours, or, with a search typed, to keep what the search finds here.",
}
local UNFOLD_ALL, FOLD_ALL = "Unfold every section", "Fold every section"
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
local PLACE_ALL = {
	one = "Place the item that matches the search here",
	many = "Place the %d items that match the search here",
	sayOne = "Flat UI: 1 item is placed in %s.",
	say = "Flat UI: %d items are placed in %s.",
	flash = "Placed %d",
}
local PLACE_SKIP = { junk = true, keep = true }
local PLACED_TIP = { one = "1 item is placed here by hand.", many = "%d items are placed here by hand." }
local SHIFT_TIPS = { only = "Shift-click to open only this one.", all = "Shift-click to open every section again." }
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
local HIDE_LINE, SHOW_HIDDEN, SHOW_TITLE = "Delete this section", "Bring back deleted sections (%d)", "Bring back"
local SHOW_ALL = "Bring back every deleted section"
local HIDDEN_MARK, UNUSED_MARK = " (deleted)", " (not in use now)"
local HIDDEN_NONE = "No section is deleted. Choose one in Delete a section, or right-click a section's title in the bag window and choose Delete "
	.. "this section."
local HIDE_SAY = {
	hidden = "Flat UI: deleted %s from the bags, in both windows; its items go to the sections that take them. Click Deleted after the last "
		.. "section to bring it back.",
	all = "Flat UI: every deleted bag section is back.",
	one = "Flat UI: %s is back in the bags.",
	none = "Flat UI: no bag section is deleted.",
}
local REMOVE = {
	mine = " (yours)",
	minePlaced = " (yours, %d placed)",
	rest = " (the rest)",
	both = "%s: both kinds",
	all = "%s: all %d kinds",
	none = "Every section that can be deleted is deleted. Deleted sections brings one back.",
	one = "Flat UI: deleted %s from the bags. Deleted sections on the Bags page brings it back.",
	group = "Flat UI: deleted %s from the bags, %d sections in all. Deleted sections on the Bags page brings them back.",
	gone = "Flat UI: that section is deleted already, or not in use now.",
}
local SHOWN_FLASH, HIDDEN_NAMES = "Back", 8
local SPLIT_LINE, JOIN_LINE = "Split by kind", "Join into one section"
local LISTS = {
	{ fn = "ErrandsSellLines", pick = "ErrandsSellPick", line = "Your sell list (%d)", title = "Your sell list: click one to take it off" },
	{ fn = "ErrandsKeepLines", pick = "ErrandsKeepPick", line = "Never sold (%d)", title = "Never sold: click one to take it off" },
	none = "Nothing on your lists. Alt+right-click an item to sell it from now on.",
}

local drag = nil
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

local function Request()
	Call(B, "Request", "layout")
end

local function Keep(st)
	if type(st) == "table" then
		Call(B.Window, "KeepHeight", st.which)
	end
end

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

local function Holding()
	local ok, kind = pcall(GetCursorInfo)
	return ok and not ns.IsSecret(kind) and kind == "item"
end

local function Accent()
	local ok, r, g, b = pcall(ns.Colour, "windows.accent")
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return 0.85, 0.85, 0.85
end

local function Saved()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local order = type(bags) == "table" and bags.order or nil
	if type(order) == "table" and #order > 0 then
		return order
	end
	return nil
end

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

function Order.Ranks()
	local list = Order.List()
	local ranks = { new = 0 }
	for index, key in ipairs(list) do
		ranks[key] = index
	end
	ranks.free = #list + 1
	return ranks
end

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

function Order.Reset()
	if not Saved() then
		return false
	end
	Write(nil)
	Request()
	return true
end

local function Folds()
	local db = ns.Account()
	local bags = type(db) == "table" and db.bags or nil
	local folded = type(bags) == "table" and bags.folded or nil
	if type(folded) == "table" and next(folded) ~= nil then
		return folded
	end
	return nil
end

function Order.Folded(key)
	local folded = Folds()
	return folded ~= nil and type(key) == "string" and folded[key] == true
end

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

local function Movable(st, sec)
	return type(st) == "table" and type(sec) == "table" and st.view == "sections" and st.content ~= nil and not sec.block and not sec.strip
		and type(sec.key) == "string" and not SHELVES[sec.key] and not sec.add and not sec.unhide
end

local function InView(content)
	local ok, child = pcall(content.GetParent, content)
	local scroll = ok and type(child) == "table" and not ns.IsSecret(child) and select(2, pcall(child.GetParent, child)) or nil
	if type(scroll) ~= "table" or ns.IsSecret(scroll) or type(scroll.IsMouseOver) ~= "function" then
		return true
	end
	local okOver, over = pcall(scroll.IsMouseOver, scroll)
	return okOver and not ns.IsSecret(over) and over == true
end

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
		x = (ns.Finite(sec.x) and ns.Finite(st.width) and sec.x + width >= st.width - 1) and -BAR_WIDTH or (BAR_OFF - BAR_WIDTH / 2)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", title.frame, "TOPRIGHT", x, 0)
	else
		x = (ns.Finite(sec.x) and sec.x <= 0) and BAR_WIDTH or -(BAR_OFF - BAR_WIDTH / 2)
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", title.frame, "TOPLEFT", x, 0)
	end
	bar:SetSize(BAR_WIDTH, math.max(1, ns.Finite(sec.height) and sec.height or (st.titleH or 16)))
	bar:SetColorTexture(Accent())
	bar:Show()
end

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
			Call(B, "Part", "order", Finish, true)
			return
		end
		Call(B, "Part", "order", function()
			ShowBar(Target())
		end)
	end)
	box:SetScript("OnHide", function()
		if drag and drag.parts == made then
			Call(B, "Part", "order", Finish, false)
		end
	end)
	parts[content] = made
	return made
end

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

function Order.DragStop()
	Finish(true)
end

function Order.Cancel(which)
	if drag and (which == nil or drag.st.which == which) then
		Finish(false)
	end
end

local function SectionLabel(key)
	local ok, label = pcall(Call, B.Categories, "Label", key)
	if ok and type(label) == "string" and not ns.IsSecret(label) and label ~= "" then
		return label
	end
	return key
end

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

local function HiddenNow(now)
	local ok, keys = pcall(Call, B.Categories, "HiddenKeys", now)
	return ByRank(ok and type(keys) == "table" and keys or {})
end

local function Repaint()
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
end

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

function Order.HiddenCount()
	return #HiddenNow(true)
end

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

local function OrderLine(st, key, items, anchor)
	if key == "keep" then
		return
	end
	local path = "bags.itemOrder"
	local def = type(ns.Def) == "function" and ns.Def(path) or nil
	local choices = def and type(ns.Choices) == "function" and ns.Choices(def) or {}
	if #choices < 2 then
		return
	end
	local value, shown = ns.Get(path), nil
	local sub = {}
	for _, choice in ipairs(choices) do
		local id, text = choice[1], tostring(choice[2])
		if value == id then
			shown = text
		end
		sub[#sub + 1] = { text = text, tick = value == id, part = "order", pick = function()
			SetRow(path, id)
		end }
	end
	local title = type(def.label) == "string" and def.label or "Order in a section"
	items[#items + 1] = { text = "Order: " .. (shown or tostring(choices[1][2])), part = "order", pick = function()
		Call(B.Layout, "Menu", anchor, title, sub, st.which)
	end }
end

local function Banking(st, sec)
	if not (st.mine and st.live) or sec.key == "keep" then
		return false
	end
	local okRow, buttons = pcall(Call, B, "Opt", "bankButtons")
	if okRow and buttons == false then
		return false
	end
	local ok, live = pcall(Call, B.Bank, "Live")
	return ok and live == true
end

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

local function Toggle(st, sec)
	if not Movable(st, sec) or not SetFold(sec.key, not Order.Folded(sec.key)) then
		return false
	end
	Keep(st)
	Request()
	return true
end

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

local function PlacedHere(key)
	if key == "keep" or key == "junk" then
		return 0
	end
	local ok, count = pcall(Call, B.Categories, "PlacedCount", key)
	return ok and ns.Finite(count) and count or 0
end

local function PutBackText(key, count)
	local okOwn, own = pcall(Call, B.Custom, "Is", key)
	if okOwn and own == true then
		return ("Empty this section (%d %s)"):format(count, count == 1 and "item" or "items")
	end
	return count == 1 and "Put back the item placed here" or ("Put back the %d items placed here"):format(count)
end

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

local function ListLook(id, name)
	local text = type(name) == "string" and not ns.IsSecret(name) and name:gsub(" %(%d+%)$", "") or tostring(id)
	text = text:gsub("|", "||")
	local item, icon = type(C_Item) == "table" and C_Item or nil, nil
	if item and type(item.GetItemIconByID) == "function" then
		local ok, file = pcall(item.GetItemIconByID, id)
		if ok and (ns.Finite(file) or (type(file) == "string" and not ns.IsSecret(file) and file ~= "")) then
			icon = file
		end
	end
	if item and type(item.GetItemQualityByID) == "function" and type(item.GetItemQualityColor) == "function" then
		local ok, quality = pcall(item.GetItemQualityByID, id)
		local okColour, r, g, b = false, nil, nil, nil
		if ok and ns.Finite(quality) then
			okColour, r, g, b = pcall(item.GetItemQualityColor, quality)
		end
		if okColour and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
			local function Hex(v)
				return math.max(0, math.min(255, math.floor(v * 255 + 0.5)))
			end
			text = ("|cff%02x%02x%02x%s|r"):format(Hex(r), Hex(g), Hex(b), text)
		end
	end
	return text, icon
end

local function ListRows(list)
	local ok, rows = pcall(Call, ns, list.fn)
	local out = {}
	for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do
		local id = type(row) == "table" and row[1] or nil
		if type(id) == "number" then
			out[#out + 1] = row
		end
	end
	return out
end

local function ListMenu(st, list, anchor)
	local sub = {}
	for _, row in ipairs(ListRows(list)) do
		local id = row[1]
		local text, icon = ListLook(id, row[2])
		sub[#sub + 1] = { text = text, icon = icon, id = id, part = "order", pick = function()
			local okPick, done, said = pcall(Call, ns, list.pick, id)
			if okPick and done == true and type(said) == "string" then
				print(said)
			end
			if okPick and done == true and anchor and anchor:IsVisible() then
				ListMenu(st, list, anchor)
			end
		end }
	end
	if #sub > 0 then
		Call(B.Layout, "Menu", anchor, list.title, sub, st.which)
	end
end

local function ListLines(st, items, anchor)
	local any = false
	for _, list in ipairs(LISTS) do
		local count = #ListRows(list)
		if count > 0 then
			any = true
			items[#items + 1] = { text = list.line:format(count), part = "order", pick = function()
				ListMenu(st, list, anchor)
			end }
		end
	end
	if not any and Fn(ns, LISTS[1].fn) then
		items[#items + 1] = { text = LISTS.none, header = true }
	end
end

local function Rule(items, mark)
	if mark > 1 and items[mark] then
		items[mark].rule = true
	end
end

function Order.Menu(st, sec, anchor)
	if not Movable(st, sec) then
		return
	end
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
	local mark = #items + 1
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
	local okHide, hideable = pcall(Call, B.Categories, "Hideable", key)
	if okHide and hideable == true then
		items[#items + 1] = { text = HIDE_LINE, part = "order", pick = function()
			if SetHidden(key, true) then
				print(HIDE_SAY.hidden:format(SectionLabel(key)))
			end
		end }
	end
	GroupLines(key, items)
	OrderLine(st, key, items, anchor)
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
	Rule(items, mark)
	mark = #items + 1
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
	local hidden = #HiddenNow(true)
	if hidden > 0 then
		items[#items + 1] = { text = SHOW_HIDDEN:format(hidden), part = "order", pick = function()
			Order.HiddenMenu(st, anchor)
		end }
	end
	Rule(items, mark)
	mark = #items + 1
	if key == "junk" then
		ListLines(st, items, anchor)
	end
	if key == "keep" then
		local more = Call(B.Pins, "MenuLines")
		for _, item in ipairs(type(more) == "table" and more or {}) do
			items[#items + 1] = item
		end
	end
	Rule(items, mark)
	mark = #items + 1
	local okOwn, own = pcall(Call, B.Custom, "MenuLines", st, sec, anchor)
	for _, item in ipairs(okOwn and type(own) == "table" and own or {}) do
		items[#items + 1] = item
	end
	Rule(items, mark)
	Call(B.Layout, "Menu", anchor, label, items, st.which)
end

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
			local okRule, rule = pcall(Call, B.Custom, "Rule", sec.key)
			if okRule and type(rule) == "string" and not ns.IsSecret(rule) then
				click = click .. " " .. ("Keeps what %s finds."):format(rule)
			end
		end
		local placed = (okOwn and own == true) and 0 or PlacedHere(sec.key)
		if placed > 0 then
			click = click .. " " .. (placed == 1 and PLACED_TIP.one or PLACED_TIP.many:format(placed))
		end
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

local function IsHidden(key)
	local ok, hidden = pcall(Call, B.Categories, "Hidden", key)
	return ok and hidden == true
end

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

local function IsMine(key)
	local ok, mine = pcall(Call, B.Custom, "Is", key)
	return ok and mine == true
end

local function Deletable(key)
	local okHide, hideable = pcall(Call, B.Categories, "Hideable", key)
	if not (okHide and hideable == true) or IsHidden(key) then
		return false
	end
	local okExists, exists = pcall(Call, B.Categories, "Exists", key)
	return okExists and exists == true
end

local function SplitBase(key)
	local ok, base, split = pcall(Call, B.Categories, "GroupBase", key)
	if ok and type(base) == "string" and split == true then
		return base
	end
	return nil
end

local function SplitSections(list)
	local groups = {}
	for _, key in ipairs(list) do
		local base = SplitBase(key)
		if base and Deletable(key) then
			local keys = groups[base] or {}
			keys[#keys + 1] = key
			groups[base] = keys
		end
	end
	return groups
end

local function KindCount(base, keys)
	local count = 0
	for _, key in ipairs(keys) do
		if key ~= base then
			count = count + 1
		end
	end
	return count
end

function ns.BagsRemoveLines()
	local list = Order.List()
	local groups = SplitSections(list)
	local lines = {}
	for _, key in ipairs(list) do
		if IsMine(key) then
			local okCount, count = pcall(Call, B.Custom, "Count", key)
			count = okCount and ns.Finite(count) and count or 0
			local mark = count > 0 and REMOVE.minePlaced:format(count) or REMOVE.mine
			lines[#lines + 1] = { "mine:" .. key, (SectionLabel(key):gsub("|", "||")) .. mark }
		else
			local base = SplitBase(key)
			local keys = base and groups[base] or nil
			if keys then
				if key == keys[1] then
					local kinds = KindCount(base, keys)
					if kinds >= 2 then
						lines[#lines + 1] = { "group:" .. base, (kinds == 2 and REMOVE.both or REMOVE.all):format(SectionLabel(base), kinds) }
					end
					for _, kind in ipairs(keys) do
						lines[#lines + 1] = { "section:" .. kind, SectionLabel(kind) .. (kind == base and REMOVE.rest or "") }
					end
				end
			elseif not base and Deletable(key) then
				lines[#lines + 1] = { "section:" .. key, SectionLabel(key) }
			end
		end
	end
	if #lines == 0 then
		return { { "none", REMOVE.none } }
	end
	return lines
end

function ns.BagsRemovePick(id)
	if type(id) ~= "string" then
		return false
	end
	local mine = id:match("^mine:(.+)$")
	if mine then
		local delete = Fn(B.Custom, "Delete")
		if not delete then
			return false, REMOVE.gone
		end
		return delete(mine)
	end
	local key = id:match("^section:(.+)$")
	if key then
		if not SetHidden(key, true, true) then
			return false, REMOVE.gone
		end
		return true, REMOVE.one:format(SectionLabel(key))
	end
	local base = id:match("^group:(.+)$")
	if not base then
		return false
	end
	local changed, count = 0, 0
	for _, section in ipairs(Order.List()) do
		local okBase, of = pcall(Call, B.Categories, "GroupBase", section)
		if okBase and of == base then
			local okExists, exists = pcall(Call, B.Categories, "Exists", section)
			if SetHidden(section, true, true) then
				changed = changed + 1
				if okExists and exists == true then
					count = count + 1
				end
			end
		end
	end
	if changed == 0 then
		return false, REMOVE.gone
	end
	if count < 2 then
		return true, REMOVE.one:format(SectionLabel(base))
	end
	return true, REMOVE.group:format(SectionLabel(base), count)
end

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
	Call(B, "Part", "custom", Call, B.Custom, "Took", "bags", key, nil, nil, SHOWN_FLASH)
	return true, HIDE_SAY.one:format(SectionLabel(key))
end
