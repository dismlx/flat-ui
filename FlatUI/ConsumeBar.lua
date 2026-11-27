local _, ns = ...

local KEY = "consumebar"
local MOVER = "FlatUIConsumeBar"
local LABEL = "Consumables bar"
local BOX_W, BOX_H, BOX_X, BOX_Y = 226, 36, 20, 280
local MOST_LIST, MOST_BUTTONS, BOUND = 24, 40, 6
local BUTTON = "FlatUIConsumeButton"
local IsSecret, Finite = ns.IsSecret, ns.Finite

local K = {
	KEY_FONT = "GameFontHighlightSmall", COUNT_FONT = "NumberFontNormal", PLUS_FONT = "GameFontHighlightLarge",
	DIM = { 0.66, 0.68, 0.62 }, WARN = { 0.9, 0.72, 0.36 }, RED = { 1, 0.3, 0.25 },
	UNUSABLE = { 0.4, 0.4, 0.4 }, NO_MANA = { 0.5, 0.5, 1 }, WHITE = { 1, 1, 1 },
	EMPTY_ALPHA = 0.45, LIGHTER = 0.17, NONE_GAP = 5, RECENT = 0.5, SOON = 0.2, RISE = 0.1, FALL = 0.3, WATCH = 0.1, LONG = 3,
	SAMPLES = { { 118, 5 }, { 159, 12 }, { 4540, 0 }, { 1251, 3 } },
	QUESTION = 134400,
	WAIT_LINE = "Flat UI: the consumables bar lays out again when the fight ends.",
	FIGHT_DROP = "Flat UI: drop items on the consumables bar out of a fight.",
	NONE_LINE = "Flat UI: no %s in your bags.",
	LINE_WAITING = LABEL .. ": the buttons change when the fight ends.",
	LINE_BROKEN = LABEL .. ": the game made no secure button, so the bar stays hidden.",
	LINE_COUNT = LABEL .. ": %d buttons, %d of them from your list of %d.",
	BAGS_HINT = " It shows while Buttons is Your list or Your list, then the rest.",
	LOW = 3, LIT = 0.14, SUNK = 0.3, GCD = 1.5, TIP_EVERY = 1, BUFF_GAP = 0.5, BUFF_EVERY = 30,
	BUFF = { 0.3, 0.85, 0.4 }, READY = { 0.4, 0.85, 0.45 }, ACCENT = { 0.85, 0.85, 0.85 },
	MAIN = 16, OFF = 17, TEMPORARY = 15,
	HANDS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true },
	ONTO = {},
	WEAPON_ITEMS = {
		8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 10922, 10921, 10920, 10918, 9186, 6951, 5237, 3776, 3775,
		23122, 18262, 12404, 7964, 2871, 2863, 2862, 12643, 7965, 3241, 3240, 3239,
		23123, 20749, 20750, 20746, 20744, 20748, 20747, 20745, 3824, 3829,
	},
	MAIN_LINE = "Click: on your main hand.",
	BOTH_LINE = "Click: on your main hand. Right-click: on your off hand.",
}
for _, id in ipairs(K.WEAPON_ITEMS) do
	K.ONTO[id] = true
end

local KINDS = {
	{ key = "other", row = "kindOther" },
	{ key = "food", row = "kindFood" },
	{ key = "potion", row = "kindPotion" },
	{ key = "elixir", row = "kindElixir" },
	{ key = "scroll", row = "kindScroll" },
	{ key = "bandage", row = "kindBandage" },
	{ key = "enhance", row = "kindEnhance" },
	{ key = "explosive", row = "kindExplosive" },
}
local KIND_AT = {}
for index, kind in ipairs(KINDS) do
	KIND_AT[kind.key] = index
end
local CONSUMABLE, TRADEGOODS = 0, 7
local SUBS = {
	[CONSUMABLE] = { [1] = "potion", [2] = "elixir", [3] = "elixir", [4] = "scroll", [5] = "food", [6] = "enhance", [7] = "bandage", [14] = "explosive",
		[15] = "enhance" },
	[TRADEGOODS] = { [2] = "explosive", [3] = "explosive" },
}
local BAGS = { 0, 1, 2, 3, 4, 5 }
local CORNER = { right = "BOTTOMLEFT", left = "BOTTOMRIGHT", up = "BOTTOMLEFT", down = "TOPLEFT" }
local SHARE = { BOTTOMLEFT = { 0, 0 }, BOTTOMRIGHT = { 1, 0 }, TOPLEFT = { 0, 1 } }
local WHICH = { bags = true, list = true, both = true }

local C = {
	entries = {}, shown = {}, instant = {}, uses = {}, spells = {}, names = {}, pending = {}, none = {},
	queued = false, told = false, broken = false, fighting = false, cleaned = false,
}
ns.ConsumeBar = C

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Number(key, default)
	local value = Opt(key)
	return Finite(value) and value or default
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Api(space, name)
	local t = _G[space]
	local fn = type(t) == "table" and not IsSecret(t) and t[name] or nil
	return type(fn) == "function" and fn or nil
end

local function Whole(value)
	if Finite(value) and value > 0 and value == math.floor(value) then
		return value
	end
	return nil
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

local function Testing()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true
end

local function Now()
	local now = Ask(GetTime)
	return Finite(now) and now or 0
end

function C.Instant(id)
	local known = C.instant[id]
	if known ~= nil then
		return known
	end
	local call = Api("C_Item", "GetItemInfoInstant") or (type(GetItemInfoInstant) == "function" and GetItemInfoInstant or nil)
	if not call then
		return false
	end
	local ok, found, _, _, slot, icon, class, sub = pcall(call, id)
	if not ok or IsSecret(found) or found == nil then
		known = false
	else
		known = { icon = not IsSecret(icon) and icon or nil, class = Finite(class) and class or nil, sub = Finite(sub) and sub or nil,
			slot = not IsSecret(slot) and type(slot) == "string" and slot or nil }
	end
	C.instant[id] = known
	return known
end

function C.KindOf(id)
	local info = C.Instant(id)
	if not info then
		return nil
	elseif info.class == CONSUMABLE then
		return info.sub and SUBS[CONSUMABLE][info.sub] or "other"
	elseif info.class == TRADEGOODS then
		return info.sub and SUBS[TRADEGOODS][info.sub] or nil
	end
	return nil
end

function C.Name(id)
	local name = C.names[id]
	if name then
		return name
	end
	name = Ask(Api("C_Item", "GetItemNameByID"), id)
	if type(name) ~= "string" or name == "" then
		name = Ask(GetItemInfo, id)
	end
	if type(name) == "string" and name ~= "" then
		C.names[id] = name
		return name
	end
	if not C.pending[id] then
		C.pending[id] = true
		pcall(Api("C_Item", "RequestLoadItemDataByID") or function() end, id)
	end
	return nil
end

function C.Called(id)
	return C.Name(id) or ("item %d"):format(id)
end

function C.SpellOf(id)
	local known = C.spells[id]
	if known ~= nil then
		return known or nil
	end
	local call = Api("C_Item", "GetItemSpell") or (type(GetItemSpell) == "function" and GetItemSpell or nil)
	if not call then
		return nil
	end
	local ok, _, spell = pcall(call, id)
	spell = ok and not IsSecret(spell) and Whole(spell) or nil
	if spell then
		C.spells[id] = spell
	elseif C.Name(id) then
		C.spells[id] = false
	end
	return spell
end

function C.HasUse(id)
	local known = C.uses[id]
	if known ~= nil then
		return known
	end
	local call = Api("C_Item", "GetItemSpell") or (type(GetItemSpell) == "function" and GetItemSpell or nil)
	if not call then
		return true
	end
	local ok, name, spell = pcall(call, id)
	if ok and ((not IsSecret(name) and type(name) == "string" and name ~= "") or Whole(spell)) then
		C.uses[id] = true
		return true
	end
	if C.Name(id) then
		C.uses[id] = false
		return false
	end
	return nil
end

function C.Worn(id)
	if Ask(Api("C_Item", "IsEquippableItem"), id) == true then
		return true
	end
	local info = C.Instant(id)
	local slot = info and info.slot
	return slot ~= nil and slot ~= "" and slot ~= "INVTYPE_NON_EQUIP_IGNORE" and slot ~= "INVTYPE_NON_EQUIP"
end

function C.Count(id)
	local count = Ask(Api("C_Item", "GetItemCount") or GetItemCount, id, false, true)
	return Finite(count) and count or nil
end

function C.Icon(id)
	local info = C.Instant(id)
	return info and info.icon or K.QUESTION
end

function C.Cooldown(id)
	local call = Api("C_Container", "GetItemCooldown") or Api("C_Item", "GetItemCooldown")
	if not call then
		return nil
	end
	local ok, start, duration, enable = pcall(call, id)
	if not ok or IsSecret(start) or IsSecret(duration) or IsSecret(enable) or not (Finite(start) and Finite(duration)) then
		return nil
	end
	if duration > 0 and start > 0 and (enable == true or enable == nil or (Finite(enable) and enable ~= 0)) then
		return start, duration
	end
	return 0, 0
end

function C.Wait(entry)
	if entry.plus or entry.sample or not entry.id then
		return nil
	end
	local start, duration = C.Cooldown(entry.id)
	if not (start and duration > K.GCD) then
		return nil
	end
	local left = start + duration - Now()
	return left > 0 and left or nil
end

function C.Clock(seconds)
	local whole = math.max(0, math.ceil(seconds))
	if whole >= 3600 then
		return ("%d:%02d:%02d"):format(math.floor(whole / 3600), math.floor(whole % 3600 / 60), whole % 60)
	end
	return ("%d:%02d"):format(math.floor(whole / 60), whole % 60)
end

function C.Onto(id)
	if K.ONTO[id] == true then
		return true
	end
	local info = C.Instant(id)
	return type(info) == "table" and info.class == CONSUMABLE and info.sub == K.TEMPORARY
end

function C.OffWeapon()
	local id = Whole(Ask(GetInventoryItemID, "player", K.OFF))
	local info = id and C.Instant(id)
	return type(info) == "table" and info.slot ~= nil and K.HANDS[info.slot] == true
end

function C.BuffLeft(entry)
	if entry.sample or not entry.id then
		return "off"
	end
	local kind = C.KindOf(entry.id)
	if kind ~= "elixir" and kind ~= "scroll" then
		return "off"
	end
	local spell = C.SpellOf(entry.id)
	local get = spell and Api("C_UnitAuras", "GetPlayerAuraBySpellID")
	if not get then
		return "off"
	end
	local ok, aura = pcall(get, spell)
	if not ok or IsSecret(aura) then
		return "keep"
	elseif type(aura) ~= "table" then
		return "off"
	end
	local ends = aura.expirationTime
	if IsSecret(ends) then
		return "keep"
	end
	return "on", Finite(ends) and ends > 0 and ends or nil
end

function C.Scan()
	if C.scanned then
		return C.scanned
	end
	local slots, item = Api("C_Container", "GetContainerNumSlots"), Api("C_Container", "GetContainerItemID")
	local ids, seen = {}, {}
	if slots and item then
		for _, bag in ipairs(BAGS) do
			local size = Ask(slots, bag)
			for slot = 1, Whole(size) or 0 do
				local id = Whole(Ask(item, bag, slot))
				if id and not seen[id] then
					seen[id] = true
					if C.KindOf(id) and not C.Worn(id) and C.HasUse(id) == true then
						ids[#ids + 1] = id
					end
				end
			end
		end
	end
	C.scanned = C.Sorted(ids)
	return C.scanned
end

function C.Others()
	local slots, item = Api("C_Container", "GetContainerNumSlots"), Api("C_Container", "GetContainerItemID")
	local ids, seen = {}, {}
	if slots and item then
		for _, bag in ipairs(BAGS) do
			for slot = 1, Whole(Ask(slots, bag)) or 0 do
				local id = Whole(Ask(item, bag, slot))
				if id and not seen[id] then
					seen[id] = true
					if not C.KindOf(id) and not C.Worn(id) and C.HasUse(id) == true then
						ids[#ids + 1] = id
					end
				end
			end
		end
	end
	return C.Sorted(ids)
end

function C.Sorted(ids)
	local keys = {}
	for _, id in ipairs(ids) do
		local name = C.Name(id)
		keys[id] = { KIND_AT[C.KindOf(id) or "other"] or 1, name and name:lower() or nil }
	end
	table.sort(ids, function(a, b)
		local ka, kb = keys[a], keys[b]
		if ka[1] ~= kb[1] then
			return ka[1] < kb[1]
		elseif ka[2] ~= kb[2] then
			if ka[2] == nil or kb[2] == nil then
				return kb[2] == nil
			end
			return ka[2] < kb[2]
		end
		return a < b
	end)
	return ids
end

function C.KindOn(kind)
	local at = KIND_AT[kind or "other"]
	return at ~= nil and Opt(KINDS[at].row) ~= false
end

function C.List(make)
	local char = ns.Character()
	if type(char) ~= "table" then
		return {}
	end
	local list = char.consumeBar
	if type(list) ~= "table" then
		if not make then
			return {}
		end
		list = {}
		char.consumeBar = list
	end
	if not C.cleaned then
		C.cleaned = true
		local clean, seen = {}, {}
		for _, id in ipairs(list) do
			id = Whole(id)
			if id and not seen[id] and #clean < MOST_LIST then
				seen[id] = true
				clean[#clean + 1] = id
			end
		end
		for index = #list, 1, -1 do
			list[index] = nil
		end
		for index, id in ipairs(clean) do
			list[index] = id
		end
	end
	return list
end

function C.Listed(id)
	for index, each in ipairs(C.List()) do
		if each == id then
			return index
		end
	end
	return nil
end

function C.Refused(id)
	local name = C.Called(id)
	if not C.Instant(id) then
		return ('No item found for "%s".'):format(tostring(id))
	elseif C.Worn(id) then
		return ("%s is worn, not used up: it belongs on your action bars."):format(name)
	elseif not C.KindOf(id) and C.HasUse(id) ~= true then
		return ("%s has no use the game names yet."):format(name)
	elseif C.HasUse(id) == false then
		return ("%s has no use."):format(name)
	end
	return nil
end

function C.Insert(id, at)
	id = Whole(id)
	if not id then
		return false, "No such item."
	end
	local refused = C.Refused(id)
	if refused then
		return false, refused
	end
	local name, list = C.Called(id), C.List(true)
	local was = C.Listed(id)
	if was then
		if not at or at == was or at == was + 1 then
			return false, ("%s is on your list already."):format(name)
		end
		table.remove(list, was)
		if at > was then
			at = at - 1
		end
	elseif #list >= MOST_LIST then
		return false, ("Your list holds %d items at most."):format(MOST_LIST)
	end
	if not (Whole(at) and at <= #list + 1) then
		at = #list + 1
	end
	table.insert(list, at, id)
	C.ListChanged()
	local line = was and ("%s is now number %d of your list."):format(name, at) or ("%s is on your list of the consumables bar."):format(name)
	return true, line .. (C.Mode() == "bags" and K.BAGS_HINT or "")
end

function C.Remove(id)
	local at = Whole(id) and C.Listed(id)
	if not at then
		return false, ("%s is not on your list."):format(Whole(id) and C.Called(id) or tostring(id))
	end
	table.remove(C.List(true), at)
	C.ListChanged()
	return true, ("%s is off your list."):format(C.Called(id))
end

function C.Move(id, step)
	local at = Whole(id) and C.Listed(id)
	if not at then
		return false, ("%s is not on your list."):format(Whole(id) and C.Called(id) or tostring(id))
	end
	local list, to = C.List(true), at + step
	if to < 1 then
		return false, ("%s is first already."):format(C.Called(id))
	elseif to > #list then
		return false, ("%s is last already."):format(C.Called(id))
	end
	list[at], list[to] = list[to], list[at]
	C.ListChanged()
	return true, ("%s is now number %d of your list."):format(C.Called(id), to)
end

function C.ListChanged()
	if ns.Enabled(KEY) then
		ns.Try(KEY, C.Apply, true)
	end
end

function C.Mode()
	local mode = Opt("which")
	return WHICH[mode] and mode or "bags"
end

function C.CursorItem()
	local ok, kind, id = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" or IsSecret(id) then
		return nil
	end
	return Whole(id)
end

function C.Wanted()
	local mode, wanted, seen = C.Mode(), {}, {}
	if mode ~= "bags" then
		for place, id in ipairs(C.List()) do
			wanted[#wanted + 1] = { id = id, list = true, place = place }
			seen[id] = true
		end
	end
	if mode ~= "list" then
		for _, id in ipairs(C.Scan()) do
			if #wanted >= MOST_BUTTONS then
				break
			end
			if not seen[id] and C.KindOn(C.KindOf(id)) and (C.Count(id) or 0) > 0 then
				wanted[#wanted + 1] = { id = id }
			end
		end
	end
	if #wanted == 0 and Testing() then
		for _, sample in ipairs(K.SAMPLES) do
			wanted[#wanted + 1] = { id = sample[1], sample = true, count = sample[2] }
		end
	end
	if mode ~= "bags" and not C.fighting and #wanted < MOST_BUTTONS then
		local held = C.CursorItem()
		wanted.plus = held ~= nil and C.Refused(held) == nil
	end
	return wanted
end

function C.Look()
	local size = math.max(16, math.min(80, Number("size", 36)))
	local spacing = math.max(0, math.min(40, Number("spacing", 2)))
	local per = math.max(1, math.min(MOST_BUTTONS, math.floor(Number("perRow", 12))))
	local grow = Opt("grow")
	return size, spacing, per, CORNER[grow] and grow or "right"
end

function C.LayoutKey(wanted)
	local size, spacing, per, grow = C.Look()
	local parts = { size, spacing, per, grow, wanted.plus and "+" or "" }
	for _, want in ipairs(wanted) do
		parts[#parts + 1] = (want.sample and "s" or want.list and "l" or "b") .. want.id
	end
	return table.concat(parts, ",")
end

function C.Build()
	if C.panel then
		return true
	end
	local holder = Own(CreateFrame("Frame", nil, UIParent))
	if type(RegisterStateDriver) == "function" then
		pcall(RegisterStateDriver, holder, "visibility", "[petbattle] hide; show")
	end
	local panel = Own(CreateFrame("Frame", nil, holder))
	panel:SetFrameStrata("LOW")
	panel:SetSize(BOX_W, BOX_H)
	panel:Hide()
	C.holder, C.panel = holder, panel
	return true
end

local function Text(parent, font, point, x, y)
	local text = ns.OwnText(parent, "OVERLAY", font)
	if text then
		text:SetPoint(point, parent, point, x, y)
		text:SetWordWrap(false)
		pcall(text.SetShadowOffset, text, 1, -1)
		pcall(text.SetShadowColor, text, 0, 0, 0, 1)
	end
	return text
end

local function Wash(parent, sublevel, r, g, b, a, blend)
	local texture = Own(parent:CreateTexture(nil, "OVERLAY", nil, sublevel))
	texture:SetAllPoints(parent)
	texture:SetColorTexture(r, g, b, a)
	if blend then
		texture:SetBlendMode(blend)
	end
	texture:Hide()
	return texture
end

local function Accent()
	local look = ns.PanelLook
	if type(look) == "table" and type(look.Colour) == "function" then
		local ok, r, g, b = pcall(look.Colour, "accent")
		if ok and Finite(r) and Finite(g) and Finite(b) then
			return r, g, b
		end
	end
	return K.ACCENT[1], K.ACCENT[2], K.ACCENT[3]
end

function C.Entry(index)
	local entry = C.entries[index]
	if entry then
		return entry
	elseif C.broken or index > MOST_BUTTONS then
		return nil
	end
	local icon = ns.IconNew(C.panel)
	if not icon then
		return nil
	end
	ns.SetOutline(icon.outline, true, true)
	local top = Own(CreateFrame("Frame", nil, icon.frame))
	top:SetAllPoints(icon.frame)
	top:SetFrameLevel(icon.frame:GetFrameLevel() + 3)
	entry = { index = index, icon = icon, frame = icon.frame, texture = icon.texture, cooldown = icon.cooldown, outline = icon.outline, top = top }
	icon.onDone = function()
		if entry.long then
			entry.long, entry.ends = false, nil
			C.Ready(entry)
		end
	end
	entry.lit = Wash(top, -2, 1, 1, 1, K.LIT, "ADD")
	entry.sunk = Wash(top, -1, 0, 0, 0, K.SUNK)
	entry.countText = Text(top, K.COUNT_FONT, "BOTTOMRIGHT", -1, 2)
	entry.keyText = Text(top, K.KEY_FONT, "TOPLEFT", 2, -2)
	entry.buffText = Text(top, K.KEY_FONT, "TOPRIGHT", -2, -2)
	if entry.buffText then
		entry.buffText:SetTextColor(K.BUFF[1], K.BUFF[2], K.BUFF[3], 1)
	end
	entry.cover = C.Cover(entry)
	if not entry.cover then
		C.broken = true
		icon.frame:Hide()
		return nil
	end
	C.entries[index] = entry
	return entry
end

function C.Cover(entry)
	local name = entry.index <= BOUND and (BUTTON .. entry.index) or nil
	local made, cover = pcall(CreateFrame, "Button", name, C.panel, "SecureActionButtonTemplate")
	if not made or type(cover) ~= "table" then
		return nil
	end
	Own(cover)
	local done = pcall(function()
		cover:SetFrameLevel(entry.frame:GetFrameLevel() + 5)
		cover:EnableMouse(true)
		cover:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
		cover:SetScript("PreClick", function(_, button, down)
			ns.Try(KEY, C.PreClick, entry, button, down)
		end)
		cover:SetScript("PostClick", function(_, button, down)
			ns.Try(KEY, C.PostClick, entry, button, down)
		end)
		cover:SetScript("OnReceiveDrag", function()
			ns.Try(KEY, C.Drop, entry)
		end)
		cover:SetScript("OnEnter", function()
			ns.Try(KEY, C.Enter, entry)
		end)
		cover:SetScript("OnLeave", function()
			ns.Try(KEY, C.Leave, entry)
		end)
		cover:Hide()
	end)
	if not done then
		pcall(cover.Hide, cover)
		return nil
	end
	return cover
end

function C.Plus()
	if C.plus then
		return C.plus
	end
	local button = Own(CreateFrame("Button", nil, C.panel))
	button:RegisterForClicks("LeftButtonUp")
	local plus = { frame = button, plus = true }
	plus.outline = ns.Outline(button, button)
	ns.SetOutline(plus.outline, true, true)
	plus.text = Text(button, K.PLUS_FONT, "CENTER", 0, 0)
	if plus.text then
		plus.text:SetText("+")
	end
	button:SetScript("OnReceiveDrag", function()
		ns.Try(KEY, C.Drop, plus)
	end)
	button:SetScript("OnClick", function()
		ns.Try(KEY, C.Drop, plus)
	end)
	button:SetScript("OnEnter", function()
		ns.Try(KEY, C.Enter, plus)
	end)
	button:SetScript("OnLeave", function()
		ns.Try(KEY, C.Leave, plus)
	end)
	button:Hide()
	C.plus = plus
	return plus
end

function C.Arm(entry)
	local item = (entry.id and not entry.sample) and ("item:" .. entry.id) or nil
	local onto = item ~= nil and C.Onto(entry.id)
	local off = onto and C.OffWeapon()
	local armed = item and (onto and (off and item .. ":both" or item .. ":main") or item) or nil
	if entry.armed == armed then
		return
	end
	local cover = entry.cover
	local done = pcall(function()
		cover:SetAttribute("item", item)
		cover:SetAttribute("*type1", item and "item" or nil)
		cover:SetAttribute("*target-slot1", onto and K.MAIN or nil)
		cover:SetAttribute("*type2", off and "item" or nil)
		cover:SetAttribute("*target-slot2", off and K.OFF or nil)
		cover:SetAttribute("shift-type2", off and "stop" or nil)
	end)
	if done then
		entry.armed, entry.onto, entry.off = armed, onto, off
	end
end

function C.Press(entry, down)
	if entry.plus then
		return
	end
	local sunk = down == true and entry.id ~= nil
	if (entry.pressed or false) == sunk then
		return
	end
	entry.pressed = sunk
	if entry.sunk then
		entry.sunk:SetShown(sunk)
	end
	local texture, frame = entry.texture, entry.frame
	texture:ClearAllPoints()
	if sunk then
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	else
		texture:SetAllPoints(frame)
	end
end

function C.Park(entry)
	if entry.hover then
		C.Leave(entry)
	end
	C.Press(entry, false)
	entry.id, entry.list, entry.place, entry.sample, entry.sampleCount = nil, nil, nil, nil, nil
	entry.cd, entry.shownIcon, entry.lastCount, entry.empty, entry.buffed = nil, nil, nil, nil, nil
	entry.long, entry.ends = false, nil
	if entry.buffText then
		entry.buffText:SetText("")
	end
	C.Shade(entry)
	pcall(entry.cooldown.Clear, entry.cooldown)
	entry.frame:Hide()
	entry.cover:Hide()
	C.Arm(entry)
end

function C.Offset(index, per, step, grow)
	local along, across = (index - 1) % per, math.floor((index - 1) / per)
	if grow == "left" then
		return -along * step, across * step
	elseif grow == "up" then
		return across * step, along * step
	elseif grow == "down" then
		return across * step, -along * step
	end
	return along * step, across * step
end

local function Put(frame, corner, x, y, size)
	frame:ClearAllPoints()
	frame:SetPoint(corner, C.panel, corner, x, y)
	frame:SetSize(size, size)
	frame:Show()
end

function C.Layout(wanted)
	local shown = {}
	for index, want in ipairs(wanted) do
		local entry = C.Entry(index)
		if not entry then
			break
		end
		if entry.id ~= want.id or entry.sample ~= (want.sample == true) then
			entry.cd, entry.shownIcon, entry.lastCount = nil, nil, nil
			entry.long, entry.ends = false, nil
			pcall(entry.cooldown.Clear, entry.cooldown)
		end
		entry.id, entry.list, entry.place, entry.sample, entry.sampleCount = want.id, want.list == true, want.place, want.sample == true, want.count
		C.Arm(entry)
		shown[#shown + 1] = entry
	end
	for index = #shown + 1, #C.entries do
		if C.entries[index].id or C.entries[index].frame:IsShown() then
			C.Park(C.entries[index])
		end
	end
	C.shown = shown
	local plus = wanted.plus and C.Plus() or C.plus
	local key = C.LayoutKey(wanted)
	if C.laid == key then
		return
	end
	C.laid = key
	local size, spacing, per, grow = C.Look()
	local corner, step = CORNER[grow], size + spacing
	for index, entry in ipairs(shown) do
		local x, y = C.Offset(index, per, step, grow)
		Put(entry.frame, corner, x, y, size)
		Put(entry.cover, corner, x, y, size)
		ns.IconCountdownHeight(entry.icon, size, BOX_H)
		if entry.countText then
			entry.countText:SetTextHeight(math.max(8, math.floor(size * 0.36 + 0.5)))
		end
		if entry.keyText then
			entry.keyText:SetTextHeight(math.max(7, math.floor(size * 0.28 + 0.5)))
		end
		if entry.buffText then
			entry.buffText:SetTextHeight(math.max(7, math.floor(size * 0.28 + 0.5)))
		end
	end
	local count = #shown
	if plus then
		if wanted.plus then
			count = count + 1
			local x, y = C.Offset(count, per, step, grow)
			Put(plus.frame, corner, x, y, size)
		else
			plus.frame:Hide()
		end
	end
	local long, lines = math.min(math.max(count, 1), per), math.max(1, math.ceil(count / per))
	local across, along = lines * size + (lines - 1) * spacing, long * size + (long - 1) * spacing
	if grow == "up" or grow == "down" then
		C.panel:SetSize(across, along)
	else
		C.panel:SetSize(along, across)
	end
end

function C.Place()
	local _, _, _, grow = C.Look()
	local corner = CORNER[grow]
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(MOVER, corner)
	end
	if not (Finite(x) and Finite(y)) then
		local share = SHARE[corner]
		x, y = BOX_X + BOX_W * share[1], BOX_Y + BOX_H * share[2]
	end
	local key = ("%s:%.2f:%.2f"):format(corner, x, y)
	if C.placed == key then
		return
	end
	C.placed = key
	C.panel:ClearAllPoints()
	C.panel:SetPoint(corner, UIParent, "BOTTOMLEFT", x, y)
end

function C.Retire(why)
	for _, entry in ipairs(C.entries) do
		if entry.id or entry.armed or entry.frame:IsShown() then
			C.Park(entry)
		end
	end
	if C.plus then
		C.plus.frame:Hide()
	end
	C.shown = {}
	C.laid = why
	if C.panel then
		C.panel:Hide()
	end
end

function C.Lay()
	if not ns.Enabled(KEY) then
		C.Retire("off")
		return
	end
	local wanted = C.Wanted()
	if (#wanted == 0 and not wanted.plus) or not C.Build() or C.broken then
		C.Retire("empty")
		return
	end
	C.Layout(wanted)
	if C.broken or (#C.shown == 0 and not wanted.plus) then
		C.Retire("empty")
		return
	end
	C.Place()
	local hidden = not C.panel:IsShown()
	C.panel:Show()
	if hidden then
		C.Fade(true)
	end
end

function C.Queue()
	if C.queued then
		return
	end
	C.queued = true
	ns.OutOfCombat(function()
		if Fighting() then
			return
		end
		C.queued = false
		if ns.IsStopped(KEY) then
			pcall(C.Retire, "off")
		else
			ns.Try(KEY, C.Apply)
		end
	end)
end

function C.WouldChange()
	if not ns.Enabled(KEY) then
		return C.laid ~= "off" and C.panel ~= nil and C.panel:IsShown()
	end
	return C.placed == nil or C.laid ~= C.LayoutKey(C.Wanted())
end

function C.Apply(tell)
	if Fighting() then
		if tell and not C.told and C.WouldChange() then
			C.told = true
			print(K.WAIT_LINE)
		end
		C.Queue()
	else
		C.Lay()
	end
	C.Paint()
end

function C.Shade(entry)
	if entry.hover then
		local r, g, b = ns.Colour("general.backdrop")
		ns.SetOutlineFill(entry.outline, math.min(1, r + K.LIGHTER), math.min(1, g + K.LIGHTER), math.min(1, b + K.LIGHTER), 1)
	else
		ns.SetOutlineFill(entry.outline, nil, nil, nil, nil)
	end
	if entry.plus then
		return
	end
	if entry.lit then
		entry.lit:SetShown(entry.hover == true)
	end
	if entry.hover then
		ns.SetOutlineColour(entry.outline, Accent())
	elseif entry.buffed then
		ns.SetOutlineColour(entry.outline, K.BUFF[1], K.BUFF[2], K.BUFF[3])
	else
		ns.SetOutlineColour(entry.outline, nil, nil, nil)
	end
end

function C.PaintBuff(entry)
	local state, ends = C.BuffLeft(entry)
	if state == "keep" then
		return entry.buffed == true
	end
	local on = state == "on"
	local text = entry.buffText
	if text then
		local words = ""
		if on and ends then
			local minutes = math.max(1, math.ceil((ends - Now()) / 60))
			words = minutes > 99 and ("%dh"):format(math.floor(minutes / 60 + 0.5)) or ("%dm"):format(minutes)
		end
		text:SetText(words)
	end
	entry.buffed = on
	return on
end

function C.Buffs()
	local any = false
	for _, entry in ipairs(C.shown) do
		if entry.id then
			if C.PaintBuff(entry) then
				any = true
			end
			C.Shade(entry)
		end
	end
	C.BuffClock(any)
end

function C.BuffClock(any)
	if not any or C.buffClock then
		return
	end
	C.buffClock = true
	if not After(K.BUFF_EVERY, function()
		C.buffClock = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, C.Buffs)
		end
	end) then
		C.buffClock = false
	end
end

function C.AuraChanged()
	if C.buffSoon then
		return
	end
	C.buffSoon = true
	if not After(K.BUFF_GAP, function()
		C.buffSoon = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, C.Buffs)
		end
	end) then
		C.buffSoon = false
		C.Buffs()
	end
end

function C.Sweep(entry)
	if entry.sample or not entry.id then
		return
	end
	local start, duration = C.Cooldown(entry.id)
	if start == nil then
		return
	end
	local key = duration > 0 and ("%.3f:%.3f"):format(start, duration) or "none"
	if entry.cd == key then
		return
	end
	entry.cd = key
	if duration > 0 then
		entry.long, entry.ends = duration >= K.LONG, start + duration
		pcall(entry.cooldown.SetCooldown, entry.cooldown, start, duration)
	else
		local ended = entry.long and entry.ends ~= nil and Now() >= entry.ends - K.SOON
		entry.long, entry.ends = false, nil
		pcall(entry.cooldown.Clear, entry.cooldown)
		if ended then
			C.Ready(entry)
		end
	end
end

function C.Ready(entry)
	if entry.id and not entry.sample and entry.frame:IsVisible() then
		ns.IconFlash(entry.icon)
	end
end

function C.Tint(entry)
	local colour
	if not entry.sample and not entry.empty and entry.id then
		local ok, usable, noMana = pcall(Api("C_Item", "IsUsableItem") or IsUsableItem, entry.id)
		if ok and not IsSecret(usable) and not IsSecret(noMana) and usable == false then
			colour = noMana == true and K.NO_MANA or K.UNUSABLE
		end
	end
	colour = colour or K.WHITE
	entry.texture:SetVertexColor(colour[1], colour[2], colour[3])
end

function C.KeyOf(index)
	if index > BOUND then
		return nil
	end
	local key = Ask(GetBindingKey, ("CLICK %s%d:LeftButton"):format(BUTTON, index))
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local text = Ask(GetBindingText, key, 1)
	text = type(text) == "string" and text ~= "" and text or key
	return type(ns.HotkeyText) == "function" and ns.HotkeyText(text) or text
end

function C.PaintEntry(entry)
	local id = entry.id
	if not id then
		return
	end
	local count
	if entry.sample then
		count = entry.sampleCount or 0
	else
		count = C.Count(id) or entry.lastCount or 0
	end
	entry.lastCount = count
	local empty = count <= 0
	entry.empty = empty
	entry.frame:SetShown(not (empty and entry.list and Opt("empty") == "hide"))
	local icon = C.Icon(id)
	if entry.shownIcon ~= icon then
		entry.shownIcon = icon
		entry.texture:SetTexture(icon)
	end
	entry.texture:SetDesaturated(empty)
	entry.texture:SetAlpha(empty and K.EMPTY_ALPHA or 1)
	C.Tint(entry)
	local text = entry.countText
	if text then
		if Opt("count") ~= false and (count > 1 or empty or entry.list or entry.sample) then
			local colour = empty and K.RED or (not entry.sample and count <= K.LOW and K.WARN) or K.WHITE
			text:SetText(tostring(math.floor(count)))
			text:SetTextColor(colour[1], colour[2], colour[3], 1)
		else
			text:SetText("")
		end
	end
	if entry.keyText then
		entry.keyText:SetText(C.KeyOf(entry.index) or "")
	end
	C.Sweep(entry)
	C.BuffClock(C.PaintBuff(entry))
	C.Shade(entry)
	if entry.hover and C.Owned(entry) then
		C.Tip(entry)
	end
end

function C.Paint()
	for _, entry in ipairs(C.shown) do
		C.PaintEntry(entry)
	end
	if C.plus then
		C.Shade(C.plus)
	end
	C.Fade()
end

function C.Sweeps()
	for _, entry in ipairs(C.shown) do
		C.Sweep(entry)
	end
	local entry = C.hover
	if entry and not entry.plus and entry.cooling ~= true and C.Wait(entry) and C.Owned(entry) then
		C.Tip(entry)
	end
end

function C.Tints()
	for _, entry in ipairs(C.shown) do
		C.Tint(entry)
	end
end

function C.Lining()
	local kit = ns.MoverKit
	if type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true then
		return true
	end
	return type(ns.EditModeOpen) == "function" and ns.EditModeOpen() == true
end

function C.Hovered()
	if C.hover then
		return true
	end
	local panel = C.panel
	if not (panel and panel:IsShown()) then
		return false
	end
	local ok, over = pcall(panel.IsMouseOver, panel)
	return ok and (IsSecret(over) or over == true)
end

function C.Rest()
	if Opt("fade") == true and not C.fighting and not C.Hovered() and not C.Lining() then
		return math.max(0, math.min(100, Number("fadeAlpha", 40))) / 100
	end
	return 1
end

function C.SetAlpha(alpha)
	C.alpha = alpha
	for _, entry in ipairs(C.shown) do
		entry.frame:SetAlpha(alpha)
	end
	if C.plus then
		C.plus.frame:SetAlpha(alpha)
	end
end

function C.StopEase()
	C.ease = nil
	if C.easer then
		C.easer:SetScript("OnUpdate", nil)
	end
end

function C.Ease()
	local ease = C.ease
	if not ease then
		C.StopEase()
		return
	end
	local share = ease.duration > 0 and (Now() - ease.start) / ease.duration or 1
	if not Finite(share) or share >= 1 then
		C.StopEase()
		C.SetAlpha(ease.to)
		return
	end
	share = math.max(0, share)
	C.SetAlpha(ease.from + (ease.to - ease.from) * (1 - (1 - share) * (1 - share)))
end

function C.Fade(snap)
	local to = C.Rest()
	if snap or C.alpha == nil or not (C.panel and C.panel:IsShown()) then
		C.StopEase()
		C.SetAlpha(to)
	elseif not (C.ease and C.ease.to == to) then
		if C.alpha == to then
			C.StopEase()
			C.SetAlpha(to)
		else
			if not C.easer then
				C.easer = Own(CreateFrame("Frame"))
				C.easeStep = function()
					if not ns.Try(KEY, C.Ease) then
						C.StopEase()
					end
				end
			end
			local from = C.alpha
			C.ease = { from = from, to = to, start = Now(), duration = (to > from and K.RISE or K.FALL) * math.abs(to - from) }
			C.easer:SetScript("OnUpdate", C.easeStep)
		end
	end
	C.Watch()
end

function C.StopWatch()
	local ticker = C.ticker
	C.ticker = nil
	if type(ticker) == "table" and type(ticker.Cancel) == "function" then
		pcall(ticker.Cancel, ticker)
	end
end

function C.Watch()
	local want = Opt("fade") == true and not C.fighting and C.panel ~= nil and C.panel:IsShown() and ns.Enabled(KEY)
	if want and not C.ticker then
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, K.WATCH, function()
				if not ns.Try(KEY, C.Fade) then
					C.StopWatch()
				end
			end)
			C.ticker = ok and ticker or nil
		end
	elseif not want and C.ticker then
		C.StopWatch()
	end
end

function C.Tooltip()
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Owner(entry)
	return entry.plus and entry.frame or entry.cover
end

function C.Owned(entry)
	local tip = C.Tooltip()
	if not tip then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, Owner(entry))
	return ok and not IsSecret(owned) and owned == true
end

function C.Anchor()
	local ok, _, y = pcall(C.panel.GetCenter, C.panel)
	local okHeight, height = pcall(UIParent.GetHeight, UIParent)
	if ok and okHeight and Finite(y) and Finite(height) and y < height / 2 then
		return "ANCHOR_TOP"
	end
	return "ANCHOR_BOTTOM"
end

function C.Lines(entry)
	local lines, warm = {}, {}
	if entry.plus then
		return "Drop a consumable here", { "It goes at the end of your list of the consumables bar." }, warm
	end
	if entry.sample then
		lines[1] = "Sample: your consumables show here while test mode is on."
		return nil, lines, warm
	end
	local left = C.Wait(entry)
	if left then
		lines[1] = "Ready in " .. C.Clock(left)
		warm[1] = true
		entry.cooling = true
	elseif entry.cooling == true then
		lines[1] = "Ready"
		warm[1] = K.READY
		entry.cooling = false
	end
	if entry.empty then
		lines[#lines + 1] = "None in your bags."
		warm[#lines] = true
	end
	if entry.list then
		lines[#lines + 1] = ("Number %d of your list. Shift+right-click: off your list."):format(entry.place or 0)
		lines[#lines + 1] = "Drop a consumable here to put it in this place."
	else
		lines[#lines + 1] = "Shift+right-click: onto your list."
	end
	if entry.onto then
		lines[#lines + 1] = entry.off and K.BOTH_LINE or K.MAIN_LINE
	end
	local key = C.KeyOf(entry.index)
	if key then
		lines[#lines + 1] = "Key: " .. key
	end
	return nil, lines, warm
end

function C.Tip(entry)
	local tip = C.Tooltip()
	if not tip then
		return
	end
	local title, lines, warm = C.Lines(entry)
	pcall(function()
		tip:SetOwner(Owner(entry), C.Anchor())
		if title then
			tip:SetText(title, 1, 1, 1)
		elseif entry.id then
			tip:SetItemByID(entry.id)
		end
		for index, line in ipairs(lines) do
			local colour = warm[index] == true and K.WARN or warm[index] or K.DIM
			tip:AddLine(line, colour[1], colour[2], colour[3], true)
		end
		tip:Show()
	end)
	C.TipWatch()
end

function C.StopTip()
	local ticker = C.tipTicker
	C.tipTicker = nil
	if type(ticker) == "table" and type(ticker.Cancel) == "function" then
		pcall(ticker.Cancel, ticker)
	end
end

function C.TipWatch()
	local entry = C.hover
	local want = entry ~= nil and entry.hover == true and entry.cooling == true
	if want and not C.tipTicker then
		if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
			local ok, ticker = pcall(C_Timer.NewTicker, K.TIP_EVERY, function()
				if not ns.Try(KEY, C.TipTick) then
					C.StopTip()
				end
			end)
			C.tipTicker = ok and ticker or nil
		end
	elseif not want and C.tipTicker then
		C.StopTip()
	end
end

function C.TipTick()
	local entry = C.hover
	if entry and entry.cooling == true and C.Owned(entry) then
		C.Tip(entry)
	else
		C.StopTip()
	end
end

function C.Enter(entry)
	entry.hover = true
	entry.cooling = nil
	C.hover = entry
	C.Fade()
	C.Shade(entry)
	C.Tip(entry)
end

function C.Leave(entry)
	if not entry.hover then
		return
	end
	entry.hover = false
	entry.cooling = nil
	C.Press(entry, false)
	if C.hover == entry then
		C.hover = nil
	end
	C.TipWatch()
	C.Fade()
	C.Shade(entry)
	if C.Owned(entry) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

function C.Recent(entry)
	local recent = C.recent
	return recent ~= nil and recent.entry == entry and Now() - recent.at < K.RECENT
end

function C.PreClick(entry, button, down)
	C.Press(entry, down)
	entry.held = nil
	local attribute = (button == "LeftButton" and "*type1") or (button == "RightButton" and entry.off and "*type2") or nil
	if not attribute or not entry.armed or Fighting() then
		return
	end
	if C.CursorItem() or C.Recent(entry) then
		if pcall(entry.cover.SetAttribute, entry.cover, attribute, nil) then
			entry.held = attribute
		end
	end
end

function C.PostClick(entry, button, down)
	if down ~= true then
		C.Press(entry, false)
	end
	if entry.held then
		local attribute = entry.held
		entry.held = nil
		if Fighting() or not pcall(entry.cover.SetAttribute, entry.cover, attribute, "item") then
			entry.armed = nil
			C.Queue()
		end
	end
	if button == "RightButton" then
		if not down and Ask(IsShiftKeyDown) == true and entry.id and not entry.sample then
			local _, line
			if entry.list then
				_, line = C.Remove(entry.id)
			else
				_, line = C.Insert(entry.id)
			end
			print("Flat UI: " .. line)
		end
		return
	end
	if C.CursorItem() then
		local ok, over = pcall(entry.cover.IsMouseOver, entry.cover)
		if not down and ok and (IsSecret(over) or over == true) then
			C.Drop(entry)
		end
	elseif not C.Recent(entry) and entry.id and not entry.sample and entry.empty then
		C.SayNone(entry.id)
	end
end

function C.SayNone(id)
	local now, last = Now(), C.none[id]
	if last and now - last < K.NONE_GAP and now >= last then
		return
	end
	C.none[id] = now
	print(K.NONE_LINE:format(C.Called(id)))
end

function C.Drop(entry)
	local id = C.CursorItem()
	if not id or C.Recent(entry) then
		return
	end
	if Fighting() then
		if not C.saidDrop then
			C.saidDrop = true
			print(K.FIGHT_DROP)
		end
		return
	end
	C.recent = { entry = entry, at = Now() }
	local at = entry.list and entry.place or (entry.plus and #C.List() + 1) or nil
	local ok, line = C.Insert(id, at)
	if ok then
		pcall(ClearCursor)
	end
	print("Flat UI: " .. line)
end

function C.Refresh()
	C.fighting = Fighting()
	C.Apply(true)
end

function C.Start()
	C.fighting = Fighting()
	C.placed = nil
	C.Apply(false)
end

function C.BagsChanged()
	C.scanned = nil
	C.Apply(false)
end

function C.Received(id)
	C.pending[id] = nil
	if C.soon then
		return
	end
	C.soon = true
	if not After(K.SOON, function()
		C.soon = false
		if ns.Enabled(KEY) then
			ns.Try(KEY, C.BagsChanged)
		end
	end) then
		C.soon = false
		C.BagsChanged()
	end
end

function C.CursorChanged()
	if not Fighting() then
		C.Apply(false)
	end
end

function C.Equipped()
	if C.panel and #C.shown > 0 then
		C.Apply(false)
	end
end

function C.FightStarts()
	C.fighting = true
	if C.plus and C.plus.frame:IsShown() then
		C.plus.frame:Hide()
		C.laid = nil
	end
	C.Fade()
end

function C.AfterFight()
	C.fighting, C.told, C.saidDrop = false, false, false
	C.queued = false
	C.Apply(false)
end

function C.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if C.broken then
		lines[#lines + 1] = K.LINE_BROKEN
	end
	if C.queued then
		lines[#lines + 1] = K.LINE_WAITING
	end
	local listed = 0
	for _, entry in ipairs(C.shown) do
		if entry.list then
			listed = listed + 1
		end
	end
	lines[#lines + 1] = K.LINE_COUNT:format(#C.shown, listed, #C.List())
	return lines
end

function ns.ConsumeBarCandidates()
	if not ns.ModuleOn(KEY) then
		C.scanned = nil
	end
	local rows = {}
	for _, id in ipairs(C.Scan()) do
		if not C.Listed(id) then
			rows[#rows + 1] = { id, ("%s (%d)"):format(C.Called(id), C.Count(id) or 0) }
		end
	end
	for _, id in ipairs(C.Others()) do
		if not C.Listed(id) then
			rows[#rows + 1] = { id, ("%s (%d)"):format(C.Called(id), C.Count(id) or 0) }
		end
	end
	return rows
end

function ns.ConsumeBarListed()
	local rows = {}
	for index, id in ipairs(C.List()) do
		rows[#rows + 1] = { id, ("%d. %s"):format(index, C.Called(id)) }
	end
	return rows
end

function ns.ConsumeBarAdd(id)
	return C.Insert(id)
end

function ns.ConsumeBarRemove(id)
	return C.Remove(id)
end

function ns.ConsumeBarLeft(id)
	return C.Move(id, -1)
end

function ns.ConsumeBarRight(id)
	return C.Move(id, 1)
end

function ns.ConsumeBarShown()
	return ns.Enabled(KEY)
end

function ns.ConsumeBarMoved()
	C.placed = nil
	if C.panel and ns.Enabled(KEY) then
		ns.Try(KEY, C.Apply, true)
	end
end

for index = 1, BOUND do
	_G[("BINDING_NAME_CLICK %s%d:LeftButton"):format(BUTTON, index)] = ("Consumables bar button %d"):format(index)
end

ns.Register(KEY, {
	label = LABEL,
	counted = false,
	Start = C.Start,
	Refresh = C.Refresh,
	Resized = C.Start,
	Status = C.Status,
	events = {
		BAG_UPDATE_DELAYED = C.BagsChanged,
		PLAYER_ENTERING_WORLD = C.BagsChanged,
		BAG_UPDATE_COOLDOWN = C.Sweeps,
		SPELL_UPDATE_USABLE = C.Tints,
		PLAYER_LEVEL_UP = C.Tints,
		GET_ITEM_INFO_RECEIVED = C.Received,
		CURSOR_CHANGED = C.CursorChanged,
		UNIT_AURA = C.AuraChanged,
		PLAYER_EQUIPMENT_CHANGED = C.Equipped,
		UPDATE_BINDINGS = C.Paint,
		PLAYER_REGEN_DISABLED = C.FightStarts,
		PLAYER_REGEN_ENABLED = C.AfterFight,
	},
	filters = {
		GET_ITEM_INFO_RECEIVED = function(id)
			return not IsSecret(id) and C.pending[id] == true
		end,
		CURSOR_CHANGED = function()
			return C.Mode() ~= "bags"
		end,
		UNIT_AURA = function(unit)
			return not IsSecret(unit) and unit == "player" and #C.shown > 0
		end,
		PLAYER_EQUIPMENT_CHANGED = function(slot)
			return not IsSecret(slot) and (slot == K.MAIN or slot == K.OFF)
		end,
	},
})

if ns.TestMode then
	ns.TestMode.Register(KEY, { module = KEY, label = LABEL, refresh = true })
end
