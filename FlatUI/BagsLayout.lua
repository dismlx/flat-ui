local _, ns = ...

-- Bags, the layout of a bag window: where every slot the window shows goes, in that window's content frame (BagsWindow.lua). The content frame
-- is scaled by Slot size over the 37 units of the game's item button (ContainerFrameItemButtonTemplate, Mainline/ContainerFrame.xml:77-78), so
-- everything here is in the units of that button: a cell is 40 of them, a button and a space of 3. Frames of Flat UI's own take that scale too,
-- and the game's art on its item buttons stays in proportion. Two views, as Show items says.
-- Sections files every item with B.Categories.Of and sorts each section with B.Categories.Compare (BagsCategories.lua). A section lies under its
-- title, as many cells wide as it has items, at least as wide as its title needs and at most as wide as the window. The title's width is measured
-- once per layout with GetUnboundedStringWidth on Flat UI's own font string (WL/uiobjects.yaml:3738), and a title wider than the window is cut to
-- it with an ellipsis (SetWidth and SetWordWrap, :3857). Sections go left to right on a shelf while they fit, and one that does not fit starts the
-- next shelf, 12 units below. New items is a full-width shelf at the top and Free slots the last: one counted slot for each kind of bag (the live
-- button of the first free slot of that kind, so a drop on it puts the item there) or every free slot, as Free slots says. A title's text keeps an
-- on-screen size of at least 9 units, so a small Slot size never makes it unreadable.
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
-- its kind, with the kind after a special bag's name, and the number of its free slots. A click on the label of one of the player's own bags opens a
-- menu of Flat UI's own with what the game's bag menu sets, which is out of reach while Bags keeps the game's bag windows hidden (Mainline/
-- ContainerFrame.lua:643-711, 765-776): Assign To on bags 1 to 4 that are not special bags, with the six filters of the game's list (:2383-2390;
-- C_Container.GetBagSlotFlag and SetBagSlotFlag, WL/apis.yaml:8538, 8800; Enum.BagSlotFlags, WL/enums.yaml:579-590), and Ignore for clean up and
-- for junk selling, on the backpack through C_Container.GetBackpackAutosortDisabled, SetBackpackAutosortDisabled, GetBackpackSellJunkDisabled and
-- SetBackpackSellJunkDisabled (WL/apis.yaml:8520, 8781, 8525, 8786) and on the other bags through the flags DisableAutoSort and ExcludeJunkSell,
-- as the game's menu does it. Its words are the game's own global strings (BAG_FILTER_ASSIGN_TO, BAG_FILTER_IGNORE, BAG_FILTER_CLEANUP,
-- SELL_ALL_JUNK_ITEMS_EXCLUDE_FLAG and the six BAG_FILTER labels, ContainerFrame.lua:46-53, 648, 667, 686, 708), in English when the client has
-- none. A change asks for the junk coin and the Sell junk count again, since Errands follows these flags.
-- The title of a section takes a drop. An item on the cursor (GetCursorInfo, WL/apis.yaml:36258) let go or clicked on it goes to
-- B.Categories.Drop, which keeps it in that section or puts it on Errands' sell or keep list, and goes back to its slot (ClearCursor, :34956). That
-- happens out of combat only, with one line in a fight, and never on New items or Free slots, whose titles only give the item back. While the
-- cursor holds an item the titles that take one are lit, read every tenth of a second while the window shows. A click on the top shelf's title
-- puts its items away (B.Categories.New.Clear in the bag window) and lays the window out again.
-- The buttons are BagsItems.lua's: the game's item buttons for the player's own bags, buttons of Flat UI's own for the live bank and for
-- everything else. They are drawn with B.Buttons.Draw, dimmed with B.Buttons.Dim and placed here (ClearAllPoints, SetPoint, Show, Hide). A holder
-- of a bag's buttons (the frame whose ID is the bag, ContainerFrame.lua:1845-1851), or a button of Flat UI's own, that is not under the window's
-- content frame is put under it (SetParent, on frames of Flat UI's own only), so it takes the content's scale and scrolls with it.
-- The menus are frames of Flat UI's own on UIParent in the DIALOG strata, as the menu of Data panels is (DataPanels.lua:1306-1474): a press
-- anywhere else closes one (GLOBAL_MOUSE_DOWN, WL/events.yaml:5249, heard on a frame of its own only while a menu is open). Tooltips are
-- GameTooltip (SetOwner, SetText, AddLine, Show, Hide). This file owns no event of the module.

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
-- The defaults of the rows this file reads, for a value the options do not give.
local DEFAULTS = { view = "sections", columns = 12, bankColumns = 16, slotSize = 36, freeSlots = "kinds", bank = "flat", gear = "one",
	newItems = true }
local NEW, FREE, OTHER, JUNK = "new", "free", "other", "junk"
local KEYRING = -1
-- The bank's own slots, its first tab (Camelot/BankFrame.lua:301-327).
local BANK_SLOTS = 6
-- The top shelf of the bank window: what was put in while it is open.
local ADDED = "Added"
-- A section the order does not know comes after the ones it does.
local LATE = 1000
-- The text-dim of the windows (Threat.lua) for titles, a darker one for their counts, and a red for a bag with no room.
local DIM = { 0.66, 0.68, 0.62 }
local COUNT_HEX = "|cff7d8078"
local FULL_HEX = "|cffff5a3d"
-- How strongly a title that takes a drop is lit, and the same under the cursor; the faint line after a title's text.
local LIT, LIT_HOVER, RULE_ALPHA = 0.14, 0.3, 0.16
-- How often the cursor is read while a window shows, and how long after a drop a click on the same title is the same action.
local CURSOR_STEP, DROP_CLICK = 0.1, 0.3
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
-- used: how many the last pass used. ruler: the font string titles are measured on. holding: the cursor held an item at the last reading.
-- built: a layout stands.
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

-- The item ID on the cursor, or nil when it holds no item.
local function Holding()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" or not Finite(id) then
		return nil
	end
	return id
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
-- while it is open with Flat UI's bank window at the banker (BagsBank.lua).
function Layout.Viewed(which)
	local me = Call(B, "Me")
	local key = Call(B, "Viewing", which)
	if key == nil or key == me then
		key = me
	end
	local mine = key == me
	local live = mine
	if which == "bank" then
		live = mine and Call(Bank, "Live") == true and Opt("bank") ~= "game"
	end
	return key, mine, live
end

local function Columns(which)
	local value = which == "bank" and Opt("bankColumns") or Opt("columns")
	if not Finite(value) then
		value = which == "bank" and DEFAULTS.bankColumns or DEFAULTS.columns
	end
	return math.max(1, math.floor(value + 0.5))
end

local function Scale()
	local size = Opt("slotSize")
	if not Finite(size) or size <= 0 then
		size = DEFAULTS.slotSize
	end
	return size / SLOT
end

local function View()
	return Opt("view") == "bags" and "bags" or "sections"
end

-- What else a layout depends on: a change of any of these is a change of row, and lays the window out afresh.
local function Sign()
	return ("%s:%s:%s"):format(tostring(Opt("freeSlots")), tostring(Opt("gear")), tostring(Opt("newItems")))
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

-- A kind's name for matching two kinds: BagsData's key, which groups the free slots of B.Data.Free ("bag" for every normal bag, the backpack and
-- the bank's own slots included, "reagent", "keyring", and one for each kind of special bag); else its id, else its label.
local function KindId(kind)
	if type(kind) == "table" then
		return KindField(kind, "key") or KindField(kind, "id") or KindField(kind, "label")
	end
	return kind
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

-- The display order of the sections, from the built-in list (B.Categories.LIST).
local function Orders()
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

-- Sorts the cells of a section by B.Categories.Compare; when it raises, by bag and slot, so equal items never swap.
local function SortEntries(st, entries)
	local compare = Fn(Categories, "Compare")
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

local function SetSize(text, size)
	if text.flatSize == size then
		return
	end
	local ok, file, _, flags = pcall(text.GetFont, text)
	if ok and type(file) == "string" and not IsSecret(file) then
		if pcall(text.SetFont, text, file, size, type(flags) == "string" and flags or "") then
			text.flatSize = size
		end
	end
end

-- True for a section whose title takes a drop: in the sections of the player's own bags or bank, every section but the top shelf and Free slots.
local function Takes(st, sec)
	return st.view == "sections" and st.mine and not sec.block and not sec.strip and sec.key ~= FREE
end

local function PaintTitle(title)
	local st, sec = title.st, title.sec
	if not (st and sec) then
		return
	end
	local r, g, b = LookRGB("accent", 0.85, 0.85, 0.85)
	if sec.strip then
		title.text:SetTextColor(r, g, b, 1)
	else
		title.text:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	end
	title.rule:SetColorTexture(DIM[1], DIM[2], DIM[3], RULE_ALPHA)
	if st.holding and Takes(st, sec) then
		title.back:SetColorTexture(r, g, b, title.over and LIT_HOVER or LIT)
		title.back:Show()
	elseif title.over and title.clickable then
		title.back:SetColorTexture(r, g, b, LIT)
		title.back:Show()
	else
		title.back:Hide()
	end
end

local function TitleTip(title)
	local st, sec = title.st, title.sec
	local tip = GameTooltip
	if not (st and sec) or type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local head, line
	if sec.block then
		if not title.clickable then
			return
		end
		head, line = sec.name, "Click for this bag's settings, as the game's bag menu has them."
	elseif st.holding and Takes(st, sec) then
		head = sec.label
		if sec.key == JUNK then
			line = "Drop the item here to sell it at merchants from now on."
		else
			line = ("Drop the item here to keep it in %s."):format(sec.label)
		end
	elseif sec.strip and not st.holding then
		head, line = sec.label, "Click to put these items away now."
	else
		return
	end
	tip:SetOwner(title.frame, "ANCHOR_TOP")
	tip:SetText(head, 1, 1, 1)
	tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
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

-- The text of a title: a section's label and how many items it holds, or a bag's name and how many of its slots are free, the count darker.
local function TitleText(sec)
	if sec.block then
		local count = sec.full and (FULL_HEX .. "full|r") or (COUNT_HEX .. (sec.freeCount or 0) .. " free|r")
		return Plain(sec.name) .. "  " .. count
	end
	return Plain(sec.label) .. "  " .. COUNT_HEX .. (sec.count or #sec.entries) .. "|r"
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
	local ok, alpha = pcall(button.GetAlpha, button)
	if ok and Finite(alpha) and alpha < 1 then
		button:SetAlpha(1)
	end
end

local function Draw(st, entry, button)
	if entry.dirty or entry.drawnOn ~= button then
		Call(Buttons, "Draw", button, entry.record, DrawOpts(st, entry))
		entry.dirty, entry.drawnOn = false, button
	end
end

local function PlaceTitle(st, title, sec, x, y, width)
	title.st, title.sec = st, sec
	if sec.block then
		title.clickable = st.mine and st.live and st.which == "bags" and sec.bag ~= KEYRING
	else
		title.clickable = sec.strip == true
	end
	SetSize(title.text, st.textSize)
	title.text:SetText(TitleText(sec))
	title.text:SetWidth(math.max(1, width - 1))
	local frame = title.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", st.content, "TOPLEFT", x, y)
	frame:SetSize(width, st.titleH)
	local textWidth = TextWidth(title.text)
	if textWidth <= 0 then
		textWidth = sec.titleWidth or width
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
	PaintTitle(title)
	frame:Show()
end

-- The height of a section of n cells, w wide, under its title.
local function Height(st, n, w)
	return st.titleH + math.max(1, math.ceil(n / w)) * PITCH - SPACE
end

-- Places one section: its title at x, y and its cells in rows of w below it.
local function PlaceSection(st, sec, x, y)
	st.used = st.used + 1
	PlaceTitle(st, Title(st, st.used), sec, x, y, sec.w * PITCH - SPACE)
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

-- Free slots as they are now: one counted slot per kind of bag (B.Data.Free), or every free slot that has no cell, in the order of the bags. A slot
-- shown the same way as before keeps its drawing.
local function MakeFree(st)
	if st.view ~= "sections" then
		st.free = nil
		return
	end
	local sec = { key = FREE, label = Label(FREE), entries = {}, count = 0 }
	if Opt("freeSlots") == "all" then
		for _, bag in ipairs(st.containers) do
			for slot = 1, st.sizes[bag] do
				if not st.cells[SlotKey(bag, slot)] and not Item(st.key, bag, slot) then
					local entry = Entry(bag, slot, nil)
					entry.freeSlot, entry.kindTable = true, st.kinds[bag]
					sec.entries[#sec.entries + 1] = entry
				end
			end
		end
		sec.count = #sec.entries
	else
		local list = Call(Data, "Free", st.key, st.which)
		for _, kind in ipairs(type(list) == "table" and list or {}) do
			local free = type(kind) == "table" and kind.free or nil
			if Finite(free) and free > 0 then
				sec.count = sec.count + math.floor(free)
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
	if #sec.entries == 0 then
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
		local n = #sec.entries
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

local function BuildSections(st)
	local orders = Orders()
	local byKey, list = {}, {}
	local strip = NewStrip(st)
	for _, bag in ipairs(st.containers) do
		for slot = 1, st.sizes[bag] do
			local record = Item(st.key, bag, slot)
			if record then
				local entry = Entry(bag, slot, record)
				local key = SectionOf(record)
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
	table.sort(list, function(a, b)
		local oa, ob = orders[a.key] or LATE, orders[b.key] or LATE
		if oa ~= ob then
			return oa < ob
		end
		return a.key < b.key
	end)
	for _, sec in ipairs(list) do
		SortEntries(st, sec.entries)
		for _, entry in ipairs(sec.entries) do
			st.cells[entry.sk] = entry
		end
		sec.titleWidth = Measure(st, TitleText(sec))
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

-- Counts what a section holds, for its title: the free slots of a bag, the items of a section.
local function Recount(sec)
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
	end
end

local function BuildBlocks(st)
	local blocks = {}
	for _, bag in ipairs(st.containers) do
		local slots = st.sizes[bag]
		if slots > 0 then
			local kind = st.kinds[bag]
			local block = { key = "bag", block = true, bag = bag, kind = kind, entries = {}, name = BagName(st, bag, kind) }
			for slot = 1, slots do
				local record = Item(st.key, bag, slot)
				local entry = Entry(bag, slot, record)
				block.entries[slot] = entry
				st.cells[entry.sk] = entry
				if record then
					ShownNew(record)
				end
			end
			Recount(block)
			block.titleWidth = Measure(st, TitleText(block))
			blocks[#blocks + 1] = block
		end
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
	local top, bottom = 0, 0
	local strip = st.strip
	if strip then
		Recount(strip)
		strip.x, strip.w = 0, st.columns
		strip.height = Height(st, #strip.entries, strip.w)
		PlaceSection(st, strip, 0, 0)
		top, bottom = -(strip.height + GAP), -strip.height
	end
	for _, sec in ipairs(st.sections) do
		Recount(sec)
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
	st.height = -bottom
	for button in pairs(was) do
		if not st.placed[button] then
			button:Hide()
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
				button:Hide()
			end
		end
	end
end

-- The cursor, read every tenth of a second while the window shows: the titles that take a drop are lit while it holds an item.
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
		local holding = Holding() ~= nil
		if holding ~= (st.holding == true) then
			st.holding = holding
			for index = 1, st.used do
				local title = st.titles[index]
				if title then
					Run("layout", PaintTitle, title)
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
	for button, entry in pairs(st.placed) do
		local matched = true
		if active and entry.record and match then
			local ok, answer = pcall(match, entry.record)
			if ok then
				matched = answer
			else
				matched = nil
			end
		end
		dim(button, matched)
	end
end

-- Lays a window out afresh for the character it shows.
function Layout.Build(which)
	local st = State(which)
	if not st.content then
		return
	end
	if st.built then
		-- The pooled buttons of the last layout go back first.
		Call(Buttons, "Release", st.content)
	end
	st.key, st.mine, st.live = Layout.Viewed(which)
	st.view, st.columns, st.scale, st.sign = View(), Columns(which), Scale(), Sign()
	st.width = st.columns * PITCH - SPACE
	st.textSize = TextSize(st.scale)
	st.titleH = math.max(TITLE, math.ceil(st.textSize + 6))
	st.content:SetScale(st.scale)
	st.cells, st.where, st.sections, st.strip, st.free = {}, {}, {}, nil, nil
	Gather(st)
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
-- BagsWindow.lua shows them inside the window at no opacity and nowhere else.
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

-- True when the last layout of a window shows this button.
function Layout.Placed(which, button)
	local st = state[which]
	return st ~= nil and st.built == true and st.placed[button] ~= nil
end

-- The window closed: the next opening lays it out afresh, and the pooled buttons go back.
function Layout.Closed(which)
	Layout.CloseMenu(which)
	local st = state[which]
	if not st then
		return
	end
	st.built = false
	for button in pairs(st.placed) do
		button:Hide()
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

-- An item let go or clicked on a section's title: kept in that section, or put on Errands' sell or keep list by B.Categories.Drop, and given back to
-- its slot. Out of combat only; the top shelf and Free slots only give it back.
function Drop(title)
	local st, sec = title.st, title.sec
	local id = Holding()
	if not (st and sec and id) or sec.block or not st.mine or st.view ~= "sections" then
		return
	end
	if Fighting() then
		print(FIGHT_LINE)
		return
	end
	title.dropped = GetTime()
	local takes = Takes(st, sec)
	if takes then
		Call(Categories, "Drop", id, sec.key)
	end
	pcall(ClearCursor)
	if takes then
		Request("layout", nil)
	end
end

function TitleClick(title, mouse)
	local st, sec = title.st, title.sec
	if not (st and sec) then
		return
	end
	if Holding() then
		Drop(title)
		return
	end
	-- The click that ends a drop on the same title is that drop.
	local dropped = title.dropped
	if dropped and GetTime() - dropped < DROP_CLICK then
		return
	end
	if mouse ~= "LeftButton" then
		return
	end
	if sec.block then
		if title.clickable then
			Layout.BagMenu(st, sec, title.frame)
		end
	elseif sec.strip then
		if st.which == "bags" then
			Call(Categories.New, "Clear")
		end
		Request("layout", st.which)
	end
end

-- Menus -------------------------------------------------------------------------------------------------------------------------------------------

-- A menu of Flat UI's own, in the way of Data panels' menu: a title and a column of lines, each { text, right = text at the right edge, tick = true
-- or false for a line with a box (nil for none), header = true for a dim line that does nothing, pick = function run on a click, part = the part it
-- runs as }. A click on a line closes the menu and runs its pick. A press anywhere else, a second click on what opened it, and its window closing
-- close it. Its tick, when set, runs every frame while it shows: the character picker counts with it.
local MENU_X, MENU_Y, MENU_LINE, MENU_BOX, MENU_GAP = 8, 5, 16, 10, 14
local menu

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and not IsSecret(over) and over == true
end

local function Fit()
	local width = menu.title:IsShown() and TextWidth(menu.title) or 0
	for index = 1, menu.count do
		local line = menu.lines[index]
		local w = TextWidth(line.text) + (line.item.tick ~= nil and (MENU_BOX + 6) or 0)
		local right = TextWidth(line.right)
		if right > 0 then
			w = w + MENU_GAP + right
		end
		width = math.max(width, w)
	end
	menu.frame:SetWidth(math.ceil(width) + 2 * MENU_X)
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
	frame:SetScript("OnHide", function()
		pcall(menu.listener.UnregisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
		menu.anchor, menu.owner, menu.tick = nil, nil, nil
	end)
	return menu
end

-- True while a menu is open on that frame.
function Layout.MenuOn(anchor)
	return menu ~= nil and menu.anchor ~= nil and menu.anchor == anchor
end

-- Closes the menu, or only one opened from that window ("bags", "bank").
function Layout.CloseMenu(owner)
	if menu and menu.anchor and (owner == nil or menu.owner == owner) then
		menu.frame:Hide()
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
	local y = MENU_Y
	if title then
		menu.title:SetText(title)
		menu.title:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
		menu.title:Show()
		y = y + MENU_LINE + 2
	else
		menu.title:SetText("")
		menu.title:Hide()
	end
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
		line.frame:ClearAllPoints()
		line.frame:SetPoint("TOPLEFT", menu.frame, "TOPLEFT", 0, -y)
		line.frame:SetPoint("TOPRIGHT", menu.frame, "TOPRIGHT", 0, -y)
		line.frame:SetHeight(MENU_LINE)
		line.frame:Show()
		y = y + MENU_LINE
	end
	menu.count = #items
	for index = #items + 1, #menu.lines do
		menu.lines[index].item = nil
		menu.lines[index].frame:Hide()
	end
	menu.frame:SetHeight(y + MENU_Y)
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

-- Writes the text at the right edge of line number index of the open menu, and widens the menu for it.
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
