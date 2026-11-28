local _, ns = ...

local B = ns.Bags
local Layout = B.Layout
local Window = B.Window
local Data = B.Data
local Categories = B.Categories
local Search = B.Search
local Buttons = B.Buttons
local Bank = B.Bank

local SLOT, PITCH, SPACE = 37, 40, 3
local GAP, TITLE, TITLE_ROOM = 12, 16, 6
local LEAST_TEXT, BASE_TEXT = 9, 10
local WINDOW_PAD, SCREEN_SHARE = 8, 0.95
local PARK = 200
local DEFAULTS = { view = "sections", columns = 12, bankColumns = 16, slotSize = 36, freeSlots = "kinds", bank = "flat", gear = "one",
	consumables = "one", tradeGoods = "one", newItems = true, addSlots = true }
local NEW, FREE, OTHER, JUNK, KEEP = "new", "free", "other", "junk", "keep"
local KEYRING = -1
local BANK_SLOTS = 6
local BACKPACK_ICON, KEYRING_ICON = "Interface\\Icons\\ui-hud-actionbar-bag", "Interface\\Icons\\ui-hud-actionbar-keyring"
local ADDED = "Added"
local LATE = 1000
local DIM = { 0.66, 0.68, 0.62 }
local RED = { 1, 0.35, 0.24 }
local COUNT_HEX = "|cff7d8078"
local FULL_HEX = "|cffff5a3d"
local LIT, LIT_HOVER, RULE_ALPHA, TITLE_FADED = 0.14, 0.3, 0.16, 0.4
local CURSOR_STEP, DROP_CLICK = 0.1, 0.3
local FOLD_LINES, FOLD_ICON = 12, 14
local ADD, ADD_LABEL = "+add", "New section"
local UNHIDE, UNHIDE_LABEL = "+hidden", "Deleted (%d)"
local UNHIDE_TIP = "Sections you deleted with Delete this section in a title's right-click menu, or with Delete a section on the Bags page. Click "
	.. "to bring one back. Deleted sections on the Bags page brings them back too."
local LOW, LOW_HEX = 4, "|cffffd100"
local FREE_TIPS = {
	bags = "The room left in your backpack and normal bags, which every + slot draws on: an item from your bank or one you wear takes one. Trade "
		.. "bags, quivers, ammo pouches, soul bags, the reagent bag and the keyring take only certain items, so they are not counted.",
	bank = "The room left in your bank's own slots and normal bank bags. Special bags are not counted.",
}
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

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

local state = {}

local function Own(object)
	ns.Own[object] = true
	return object
end

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

local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local function Plain(text)
	return (tostring(text):gsub("|", "||"))
end

local function LookRGB(key, r, g, b)
	local ok, cr, cg, cb = pcall(ns.WindowColour, "windows." .. key)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Fighting()
	local ok, fight = pcall(InCombatLockdown)
	return ok and not IsSecret(fight) and fight == true
end

local function Holding()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" or not Finite(id) then
		return nil
	end
	return id
end

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

local function InFight()
	local errands = ns.Errands
	local fighting = type(errands) == "table" and errands.Fighting or nil
	if type(fighting) == "function" then
		local ok, fight = pcall(fighting)
		return not ok or fight == true
	end
	return Fighting()
end

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

local function SlotKey(bag, slot)
	return (bag + 100) * 1000 + slot
end

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

function Layout.Fit()
	local ok, screen = pcall(UIParent.GetWidth, UIParent)
	if ok and Finite(screen) and screen > 0 then
		return math.max(1, math.floor(((screen * SCREEN_SHARE - 2 * WINDOW_PAD) / Scale() + SPACE) / PITCH))
	end
	return nil
end

local function Columns(which)
	local value = which == "bank" and Opt("bankColumns") or Opt("columns")
	if not Finite(value) then
		value = which == "bank" and DEFAULTS.bankColumns or DEFAULTS.columns
	end
	local columns = math.max(1, math.floor(value + 0.5))
	local fit = Layout.Fit()
	if fit then
		columns = math.min(columns, fit)
	end
	return columns
end

local function View()
	return Opt("view") == "bags" and "bags" or "sections"
end

local function Sign()
	local hidden = Call(Categories, "HiddenSign")
	return ("%s:%s:%s:%s:%s:%s:%s:%s"):format(tostring(Opt("freeSlots")), tostring(Opt("gear")), tostring(Opt("consumables")),
		tostring(Opt("tradeGoods")), tostring(Opt("newItems")), tostring(Opt("addSlots")), type(hidden) == "string" and hidden or "",
		tostring(Opt("itemOrder")))
end

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

local function KindId(kind)
	if type(kind) == "table" then
		return KindField(kind, "key") or KindField(kind, "id") or KindField(kind, "label")
	end
	return kind
end

local function General(kind)
	return KindField(kind, "key") == "bag"
end

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

local function ShownNew(record)
	if Call(Categories.New, "Is", record) == true then
		Call(Categories.New, "Shown", record)
	end
end

local function ShownPlaced(record)
	if record and Call(Categories.New, "Is", record) == true and SectionOf(record) ~= NEW then
		Call(Categories.New, "Shown", record)
	end
end

local function SortEntries(st, entries, plain)
	local compare = not plain and Fn(Categories, "Compare")
	if compare then
		pcall(Call, Categories, "SortMode", Opt("itemOrder"))
	end
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

local Drop, TitleClick

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

local function Takes(st, sec)
	return st.view == "sections" and st.mine and not sec.block and not sec.strip and sec.key ~= FREE and not sec.add and not sec.unhide
end

local function Plus(st, sec)
	return Opt("addSlots") ~= false and st.which == "bags" and st.mine and st.live and not sec.add and not sec.folded and Takes(st, sec)
end

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

local function Money(copper)
	local errands = ns.Errands
	if type(errands) == "table" and type(errands.Money) == "function" then
		return errands.Money(copper)
	end
	return ("%dg"):format(math.floor(copper / 10000))
end

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

local function ItemPrice(record)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return nil
	end
	local item = (type(record.link) == "string" and not IsSecret(record.link)) and record.link or record.id
	if not item then
		return nil
	end
	local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(C_Item.GetItemInfo, item)
	if ok and not IsSecret(name) and name ~= nil and Finite(price) and price >= 0 then
		return price
	end
	return nil
end

function Layout.ListTip(tip, entries, opts)
	local worth = type(opts) == "table" and opts.worth == true
	local byId, list = {}, {}
	for _, entry in ipairs(type(entries) == "table" and entries or {}) do
		local record = entry.record
		local id = record and record.id
		if Finite(id) then
			local item = byId[id]
			if not item then
				local link, name = record.link, record.name
				item = { id = id, count = 0, icon = record.icon, quality = record.quality,
					link = type(link) == "string" and not IsSecret(link) and link:find("|H", 1, true) and link or nil,
					name = type(name) == "string" and not IsSecret(name) and name ~= "" and name or nil,
					price = worth and ItemPrice(record) or nil }
				byId[id] = item
				list[#list + 1] = item
			end
			local count = record.count
			item.count = item.count + ((Finite(count) and count >= 1) and math.floor(count) or 1)
		end
	end
	table.sort(list, function(a, b)
		if worth then
			local brings, other = (a.price or -1) * a.count, (b.price or -1) * b.count
			if brings ~= other then
				return brings > other
			end
		elseif a.count ~= b.count then
			return a.count > b.count
		end
		if (a.name or "") ~= (b.name or "") then
			return (a.name or "") < (b.name or "")
		end
		return a.id < b.id
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
		local times = item.count > 1 and ("x" .. item.count) or nil
		if worth then
			local right = item.price and item.price > 0 and Money(item.price * item.count) or (item.price == nil and "?" or " ")
			local shade = item.price == nil and DIM or nil
			tip:AddDoubleLine(icon .. name .. (times and (" " .. times) or ""), right, r, g, b, shade and shade[1] or 1, shade and shade[2] or 1,
				shade and shade[3] or 1)
		else
			tip:AddDoubleLine(icon .. name, times or " ", r, g, b, DIM[1], DIM[2], DIM[3])
		end
	end
	if #list > FOLD_LINES then
		tip:AddLine(("and %d more"):format(#list - FOLD_LINES), DIM[1], DIM[2], DIM[3])
	end
end

local function FoldedTip(tip, sec)
	Layout.ListTip(tip, sec.entries)
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
		local ok, text, no = pcall(Call, B.Custom, "AddTip", st)
		if not (ok and type(text) == "string") then
			return
		end
		head, line, refused = sec.label, text, no == true
	elseif sec.unhide and not st.holding then
		head, line = sec.label, UNHIDE_TIP
		local okNames, names = pcall(Call, B.Order, "HiddenLabels")
		worth = okNames and type(names) == "string" and not IsSecret(names) and Plain(names) or nil
	elseif sec.key == FREE and not st.holding then
		head, line = sec.label, FREE_TIPS[st.which] or FREE_TIPS.bags
	elseif st.holding and Takes(st, sec) then
		head = sec.label
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
		folded = #sec.entries > 0
		if folded then
			local value, unknown = Worth(sec)
			if value > 0 then
				worth = (unknown and "Worth at least %s at a merchant." or "Worth %s at a merchant."):format(Money(value))
			end
		end
	elseif not st.holding then
		local tipOf = Fn(B.Order, "Tip")
		local ok, text = false, nil
		if tipOf then
			ok, text = pcall(tipOf, st, sec)
		end
		if not (ok and type(text) == "string") then
			return
		end
		head, line = sec.label, text
		folded = (sec.folded or sec.key == JUNK) and #sec.entries > 0
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
	if worth and not sec.strip then
		tip:AddLine(worth, 1, 1, 1, true)
	end
	if folded and sec.key == JUNK and not sec.strip then
		Layout.ListTip(tip, sec.entries, { worth = true })
	elseif folded then
		FoldedTip(tip, sec)
	end
	if worth and sec.strip then
		tip:AddLine(worth, 1, 1, 1, true)
	end
	local colour = refused and RED or DIM
	tip:AddLine(line, colour[1], colour[2], colour[3], true)
	tip:Show()
end

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

local function AccentHex()
	local r, g, b = LookRGB("accent", 0.85, 0.85, 0.85)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

local function TitleText(sec, widest, short)
	if sec.block then
		local count = sec.full and (FULL_HEX .. "full|r") or (COUNT_HEX .. (sec.freeCount or 0) .. " free|r")
		return (sec.icon or "") .. Plain(sec.name) .. "  " .. count
	end
	if sec.add then
		return AccentHex() .. "+|r " .. Plain(sec.label)
	end
	if sec.unhide then
		return COUNT_HEX .. Plain(sec.label) .. "|r"
	end
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

local function Measure(st, text)
	local ruler = st.ruler
	if not ruler then
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

local function Entry(bag, slot, record)
	return { bag = bag, slot = slot, sk = SlotKey(bag, slot), record = record, dirty = true }
end

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

local function DrawOpts(st, entry)
	if entry.free then
		return { free = entry.free, kind = entry.kindTable }
	elseif entry.record then
		return nil
	elseif entry.ghost then
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
	local drags = st.view == "sections" and not sec.block and not sec.strip and sec.key ~= FREE and sec.key ~= NEW and not sec.add
		and not sec.unhide
	if sec.block then
		title.clickable = st.mine and st.live and st.which == "bags" and sec.bag ~= KEYRING
	else
		title.clickable = sec.strip == true or sec.add == true or sec.unhide == true or drags
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
	if title.over and type(GameTooltip) == "table" and not ns.Forbidden(GameTooltip) then
		local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, frame)
		if ok and not ns.IsSecret(owned) and owned == true then
			Run("layout", TitleTip, title)
		end
	end
end

local function Height(st, n, w)
	if n <= 0 then
		return st.titleH
	end
	return st.titleH + math.ceil(n / w) * PITCH - SPACE
end

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

local function Pack(st)
	local width = st.columns * PITCH - SPACE
	local x, y, shelf = 0, 0, 0
	for _, sec in ipairs(st.sections) do
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

local function Hid(key)
	local ok, hidden = pcall(Call, Categories, "Hidden", key)
	return ok and hidden == true
end

local function BuildSections(st)
	local orders = Orders()
	local byKey, list = {}, {}
	local strip = NewStrip(st)
	local keepShown = not Hid(KEEP)
	local pinned = st.which == "bags" and st.live and Fn(B.Pins, "Get") or nil
	for _, bag in ipairs(st.containers) do
		for slot = 1, st.sizes[bag] do
			local record = Item(st.key, bag, slot)
			local ghost = nil
			if not record and pinned and keepShown then
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
					if record then
						ShownNew(record)
					end
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
	if st.which == "bags" and st.mine and not byKey[JUNK] and not Hid(JUNK) then
		local junk = { key = JUNK, label = Label(JUNK), entries = {} }
		byKey[JUNK] = junk
		list[#list + 1] = junk
	end
	local okAny, anyPin = pcall(Call, B.Pins, "Any")
	if pinned and keepShown and st.mine and not byKey[KEEP] and okAny and anyPin == true then
		local keep = { key = KEEP, label = Label(KEEP), entries = {} }
		byKey[KEEP] = keep
		list[#list + 1] = keep
	end
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
	if st.which == "bags" and st.mine then
		local okBack, count, key = pcall(Call, Categories, "LastPutBack")
		if okBack and Finite(count) and count > 0 and type(key) == "string" and not IsSecret(key) and key ~= NEW and key ~= FREE and key ~= KEEP
			and not byKey[key] and not Hid(key) then
			local okExists, exists = pcall(Call, Categories, "Exists", key)
			if okExists and exists == true then
				local back = { key = key, label = Label(key), entries = {} }
				byKey[key] = back
				list[#list + 1] = back
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
		SortEntries(st, sec.entries, sec.key == KEEP)
		for _, entry in ipairs(sec.entries) do
			st.cells[entry.sk] = entry
		end
		local okFold, folded = pcall(Call, B.Order, "Folded", sec.key)
		sec.folded = okFold and folded == true or nil
		sec.plus = Plus(st, sec) or nil
		sec.titleWidth = Measure(st, TitleText(sec, true))
	end
	if st.which == "bags" and st.mine then
		local add = { key = ADD, add = true, label = ADD_LABEL, entries = {} }
		add.titleWidth = Measure(st, TitleText(add))
		list[#list + 1] = add
	end
	local okCount, hidden = pcall(Call, B.Order, "HiddenCount")
	if okCount and Finite(hidden) and hidden > 0 then
		local unhide = { key = UNHIDE, unhide = true, label = UNHIDE_LABEL:format(hidden), entries = {} }
		unhide.titleWidth = Measure(st, TitleText(unhide))
		list[#list + 1] = unhide
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

local function BagNumber(st, bag)
	if bag == 0 or bag == KEYRING or bag == BANK_SLOTS or not Finite(bag) then
		return nil
	end
	if st.which == "bank" then
		return bag > BANK_SLOTS and bag - BANK_SLOTS or nil
	end
	return bag > 0 and bag or nil
end

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
	local lit = st.mine and st.live and (st.lit ~= nil and st.lit or st.stuck) or nil
	if lit ~= nil and not ((st.sizes and st.sizes[lit] or 0) > 0) then
		lit = nil
	end
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
		if type(st.test) == "function" then
			local okTest, hit = false, nil
			if entry.record ~= nil then
				okTest, hit = pcall(st.test, entry.record)
			end
			dim(button, okTest and hit == true and matched ~= false, true)
		elseif lit ~= nil then
			dim(button, entry.bag == lit and matched, true)
		else
			dim(button, matched)
		end
	end
	for index = 1, st.used do
		local title = st.titles[index]
		local sec = title and title.sec
		if sec then
			local matches = nil
			if active and match and not sec.strip and sec.key ~= FREE and not sec.add and not sec.unhide then
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
			if type(st.test) == "function" and not sec.strip and sec.key ~= FREE and not sec.add and not sec.unhide then
				local any = false
				for _, entry in ipairs(sec.entries) do
					if entry.record ~= nil then
						local okTest, hit = pcall(st.test, entry.record)
						if okTest and hit == true then
							any = true
							break
						end
					end
				end
				if not any then
					alpha = TITLE_FADED
				end
			end
			title.text:SetAlpha(alpha)
			title.rule:SetAlpha(alpha)
		end
	end
end

function Layout.Entries(which)
	local st = state[which]
	local list = {}
	if not (st and st.built) then
		return list
	end
	for _, entry in pairs(st.cells) do
		if type(entry.record) == "table" and entry.record.live == true then
			list[#list + 1] = entry
		end
	end
	return list
end

function Layout.LightWith(which, test)
	local st = state[which]
	if not st then
		return
	end
	if type(test) ~= "function" then
		test = nil
	end
	if st.test == test then
		return
	end
	st.test = test
	if st.built then
		Layout.Dim(which)
	end
end

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

function Layout.Stuck(which)
	local st = state[which]
	return st and st.stuck or nil
end

function Layout.Build(which)
	local st = State(which)
	if not st.content then
		return
	end
	st.builds = (st.builds or 0) + 1
	if st.built then
		Call(Buttons, "Release", st.content)
	end
	st.key, st.mine, st.live = Layout.Viewed(which)
	if not (st.mine and st.live) then
		st.stuck = nil
	end
	st.view, st.columns, st.scale, st.sign = View(), Columns(which), Scale(), Sign()
	st.width = st.columns * PITCH - SPACE
	st.textSize = TextSize(st.scale)
	st.titleH = math.max(TITLE, math.ceil(st.textSize + 6))
	st.content:SetScale(st.scale)
	st.cells, st.where, st.sections, st.strip, st.free = {}, {}, {}, nil, nil
	Gather(st)
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

local function Current(st)
	if not st.built then
		return false
	end
	local key, mine, live = Layout.Viewed(st.which)
	return st.key == key and st.mine == mine and st.live == live and st.view == View() and st.columns == Columns(st.which) and st.scale == Scale()
		and st.sign == Sign()
end

local function Arrive(st, entry)
	local record = entry.record
	local ok, key = pcall(Call, Categories, "PlacedKey", record)
	if not ok or type(key) ~= "string" or IsSecret(key) or key == NEW or SectionOf(record) ~= key then
		return false
	end
	local sec
	for _, other in ipairs(st.sections) do
		if other.key == key and not (other.block or other.add or other.unhide) then
			sec = other
			break
		end
	end
	if not sec then
		sec = { key = key, label = Label(key), entries = {} }
		local okFold, folded = pcall(Call, B.Order, "Folded", key)
		sec.folded = okFold and folded == true or nil
		local orders = Orders()
		local rank, at = orders[key] or LATE, #st.sections + 1
		for index, other in ipairs(st.sections) do
			local was = orders[other.key] or LATE
			if other.add or other.unhide or was > rank or (was == rank and other.key > key) then
				at = index
				break
			end
		end
		table.insert(st.sections, at, sec)
	end
	sec.entries[#sec.entries + 1] = entry
	sec.plus = Plus(st, sec) or nil
	Recount(st, sec)
	sec.titleWidth = Measure(st, TitleText(sec, true))
	return true
end

local function Visit(st, bag, slot, held)
	local sk = SlotKey(bag, slot)
	local record = Item(st.key, bag, slot)
	local entry = st.cells[sk]
	if entry then
		entry.record, entry.dirty = record, true
		ShownPlaced(record)
		return false
	end
	if not record or held then
		return false
	end
	entry = Entry(bag, slot, record)
	st.cells[sk] = entry
	ShownNew(record)
	if Arrive(st, entry) then
		return true
	end
	if not st.strip then
		st.strip = NewStrip(st)
	end
	st.strip.entries[#st.strip.entries + 1] = entry
	return false
end

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

function Layout.Update(which, changed, held)
	local st = state[which]
	if not (st and Current(st)) then
		return Layout.Build(which)
	end
	local all = type(changed) ~= "table"
	if not all then
		for bag in pairs(changed) do
			if not st.rank[bag] then
				return Layout.Build(which)
			end
		end
	end
	if st.view == "bags" then
		if st.rank[KEYRING] and (all or changed[KEYRING]) and KeyringShown(st.key, (Size(st.key, KEYRING))) ~= st.sizes[KEYRING] then
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
		local okArrived, arrived = pcall(Call, B.Custom, "Arrived", st, changed, held)
		if okArrived and arrived == true then
			return Layout.Build(which)
		end
		local hadStrip, grew = st.strip ~= nil, false
		if all then
			for _, bag in ipairs(st.containers) do
				for slot = 1, st.sizes[bag] do
					grew = Visit(st, bag, slot, held) or grew
				end
			end
		else
			for _, spot in ipairs(InOrder(st, changed)) do
				grew = Visit(st, spot[1], spot[2], held) or grew
			end
		end
		if st.strip and not hadStrip then
			st.strip.titleWidth = Measure(st, TitleText(st.strip))
		end
		if grew then
			Pack(st)
		end
		MakeFree(st)
	end
	Render(st)
	Layout.Dim(which)
end

function Layout.Render(which)
	local st = state[which]
	if st and st.built then
		Render(st)
		HideUnplaced(st)
		Layout.Dim(which)
	end
end

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

function Layout.Builds(which)
	local st = state[which]
	return st and st.builds or 0
end

function Layout.Placed(which, button)
	local st = state[which]
	return st ~= nil and st.built == true and st.placed[button] ~= nil
end

function Layout.EntryOf(which, button)
	local st = state[which]
	local entry = st and st.built == true and type(button) == "table" and st.placed[button] or nil
	if type(entry) ~= "table" or type(entry.record) ~= "table" then
		return nil
	end
	return entry.bag, entry.slot, entry.record, which == "bags" and st.mine == true and st.live == true
end

function Layout.Park(button)
	for _, st in pairs(state) do
		st.where[button] = nil
	end
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -PARK, 0)
end

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

function Layout.Size(which)
	local st = state[which]
	if not (st and st.built) then
		return 0, 0
	end
	return st.width * st.scale, (st.height or 0) * st.scale
end

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
		Run("pins", function()
			taken = Call(B.Pins, "Drop") == true
		end)
	elseif takes then
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
	local kind = CursorKind()
	if kind == "item" or kind == "merchant" then
		Drop(title)
		return
	elseif kind ~= nil then
		return
	end
	local dropped = title.dropped
	if dropped and GetTime() - dropped < DROP_CLICK then
		return
	end
	if sec.add then
		Run("custom", Call, B.Custom, "AddClick", st, mouse, title.frame)
		return
	end
	if sec.unhide then
		Run("order", Call, B.Order, "HiddenMenu", st, title.frame)
		return
	end
	if mouse == "RightButton" and sec.block then
		if title.clickable then
			Layout.BagMenu(st, sec, title.frame)
		end
		return
	end
	if mouse == "RightButton" and not sec.block and not sec.strip then
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
		Run("order", Call, B.Order, "Fold", st, sec)
	elseif sec.strip then
		if st.which == "bags" then
			if Opt("newItems") ~= false then
				Call(B, "ClearNew")
			end
			Call(Categories.New, "Clear")
		end
		Request("layout", st.which)
	end
end

local MENU_X, MENU_Y, MENU_LINE, MENU_BOX, MENU_GAP = 8, 5, 16, 10, 14
local MENU_MOST, MENU_LEAST = 0.9, 4
local menu

local function Over(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and not IsSecret(over) and over == true
end

local function Gone()
	pcall(menu.listener.UnregisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	for _, line in ipairs(menu.lines) do
		Untip(line.frame)
	end
	if not InCombatLockdown() then
		pcall(menu.frame.EnableKeyboard, menu.frame, false)
	end
	menu.anchor, menu.owner, menu.tick = nil, nil, nil
end

local function Fit()
	local columns = menu.columns or 1
	local widths = {}
	for column = 1, columns do
		widths[column] = 0
	end
	for index = 1, menu.count do
		local line = menu.lines[index]
		local need = TextWidth(line.text) + (line.item.tick ~= nil and (MENU_BOX + 6) or 0) + (line.iconed and 16 or 0)
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
	local r, g, b = ns.WindowColour("general.backdrop")
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
	line.icon = Own(frame:CreateTexture(nil, "ARTWORK"))
	line.icon:SetSize(12, 12)
	line.icon:SetPoint("LEFT", frame, "LEFT", MENU_X, 0)
	line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	line.icon:Hide()
	line.rule = Own(frame:CreateTexture(nil, "ARTWORK"))
	line.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", MENU_X, 0)
	line.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MENU_X, 0)
	line.rule:SetHeight(1)
	line.rule:SetColorTexture(1, 1, 1, 0.12)
	line.rule:Hide()
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
		local tip = GameTooltip
		if item and Finite(item.id) and item.id > 0 and type(tip) == "table" and not ns.Forbidden(tip) then
			pcall(tip.SetOwner, tip, frame, "ANCHOR_RIGHT")
			if pcall(tip.SetItemByID, tip, item.id) then
				pcall(tip.Show, tip)
			else
				pcall(tip.Hide, tip)
			end
		end
	end)
	frame:SetScript("OnLeave", function()
		line.light:Hide()
		Untip(frame)
	end)
	frame:SetScript("OnClick", function()
		local item = line.item
		if not item or item.header then
			return
		end
		Untip(frame)
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
	frame:EnableMouse(true)
	pcall(frame.SetClampedToScreen, frame, true)
	pcall(frame.EnableKeyboard, frame, false)
	frame:SetScript("OnKeyDown", function(self, key)
		local escape = key == "ESCAPE" and menu.anchor ~= nil
		if not InCombatLockdown() then
			pcall(self.SetPropagateKeyboardInput, self, not escape)
		end
		if escape then
			Run("window", Layout.CloseMenu)
		end
	end)
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
		if menu.frame:IsShown() then
			menu.frame:Hide()
		end
		Gone()
	end)
	return menu
end

function Layout.MenuOn(anchor)
	return menu ~= nil and menu.anchor ~= nil and menu.anchor == anchor
end

function Layout.MenuOf(owner)
	return menu ~= nil and menu.anchor ~= nil and menu.owner == owner
end

function Layout.CloseMenu(owner)
	if menu and menu.anchor and (owner == nil or menu.owner == owner) then
		menu.frame:Hide()
		Gone()
	end
end

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
	local okScreen, screen = pcall(UIParent.GetHeight, UIParent)
	screen = okScreen and Finite(screen) and screen > 0 and screen or 768
	local most = math.max(MENU_LEAST, math.floor((screen * MENU_MOST - top - MENU_Y) / MENU_LINE))
	local column, row, rows = 1, 0, 0
	local thin = ns.Pixels(menu.frame, 1)
	for index, item in ipairs(items) do
		local line = MenuLine(index)
		line.item = item
		line.text:SetText(item.text or "")
		line.right:SetText(item.right or "")
		line.text:ClearAllPoints()
		local icon = item.tick == nil and item.icon or nil
		line.iconed = Finite(icon) or (type(icon) == "string" and not IsSecret(icon) and icon ~= "")
		if line.iconed then
			line.icon:SetTexture(icon)
			line.icon:Show()
		else
			line.icon:Hide()
		end
		if item.tick ~= nil then
			line.text:SetPoint("LEFT", line.edge, "RIGHT", 6, 0)
			line.edge:Show()
			line.box:Show()
			line.mark:SetShown(item.tick == true)
		else
			if line.iconed then
				line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
			else
				line.text:SetPoint("LEFT", line.frame, "LEFT", MENU_X, 0)
			end
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
		line.rule:SetHeight(thin)
		line.rule:SetShown(item.rule == true and row > 0)
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
	if not InCombatLockdown() then
		pcall(menu.frame.EnableKeyboard, menu.frame, true)
		pcall(menu.frame.SetPropagateKeyboardInput, menu.frame, true)
	end
	pcall(menu.listener.RegisterEvent, menu.listener, "GLOBAL_MOUSE_DOWN")
	Untip(anchor)
	return menu
end

function Layout.MenuRight(index, text)
	local line = menu and menu.anchor and menu.lines[index]
	if line and line.item then
		line.right:SetText(text or "")
		Fit()
	end
end

local function FlagValue(name, fallback)
	local enum = type(Enum) == "table" and not IsSecret(Enum) and Enum.BagSlotFlags or nil
	local value = type(enum) == "table" and not IsSecret(enum) and enum[name] or nil
	return Finite(value) and value or fallback
end

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
