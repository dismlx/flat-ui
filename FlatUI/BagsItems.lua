local _, ns = ...

local KEY = "bags"
local PART = "items"

local B = ns.Bags
local Buttons = B.Buttons
local Data = B.Data
local Categories = B.Categories
local Search = B.Search
local Window = B.Window
local Bank = B.Bank
local ItemMarks = ns.ItemMarks

local TEMPLATE = "ContainerFrameItemButtonTemplate"
local LIVE_NAME = "FlatUIBag%dSlot%d"
local BANK_NAME = "FlatUIBankTab%dSlot%d"
local OFFLINE_NAME = "FlatUIBagsCached%d"
local STEP = 40
local BAGS = { 0, 1, 2, 3, 4, 5 }
local REAGENT_BAG = 5
local KEYRING = -1
local FIRST_TAB, LAST_TAB = 6, 14

local HOVER = { 1, 1, 1, 0.3 }
local SLOT_PRESSED = { 0.9, 0.8, 0.1, 0.3 }
local BROKEN = { 0.9, 0, 0 }
local WHITE = { 1, 1, 1 }
local DIM_TEXT = { 0.66, 0.68, 0.62 }
local FADED = 0.4
local GREY = 0.4
local PANEL = { 0.118, 0.118, 0.118 }
local CROP, CROP_MOST = 8, 15
local LEVEL_FONT, LEVEL_SIZE = "NumberFontNormal", 12
local CONTAINER_CLASS, QUIVER_CLASS = 1, 11
local FREE_FONT, FREE_COLOUR = "NumberFontNormalLarge", { 0.85, 0.85, 0.85 }
local MIN_QUALITY = { all = 0, uncommon = 2, rare = 3, epic = 4 }
local BIND_WORD, BIND_FONT, BIND_COLOUR = "BoE", "NumberFontNormalSmall", { 0.38, 0.82, 1 }
local TINT = { 1, 0.18, 0.18 }
local FEED_PET, FOOD_SIZE, FOOD_COLOUR = 6991, 14, { 0.45, 0.85, 0.3 }
local LEARN = { word = "+", font = "NumberFontNormal", size = 16, colour = { 0.3, 0.9, 0.3 } }
local JUNK_ATLAS = "bags-junkcoin"
local QUEST_BANG = { "TEXTURE_ITEM_QUEST_BANG", "Interface\\ContainerFrame\\UI-Icon-QuestBang" }
local QUEST_BORDER = { "TEXTURE_ITEM_QUEST_BORDER", "Interface\\ContainerFrame\\UI-Icon-QuestBorder" }
local QUEST_WIDTH, QUEST_HEIGHT = 37, 38
local UNKNOWN_ICON = 134400
local KIND_FILLS = {
	soul = { 0.45, 0.25, 0.55 },
	quiver = { 0.5, 0.38, 0.2 },
	herb = { 0.25, 0.45, 0.25 },
	enchanting = { 0.3, 0.3, 0.6 },
	engineering = { 0.5, 0.45, 0.3 },
	mining = { 0.42, 0.42, 0.42 },
	leather = { 0.45, 0.32, 0.22 },
	gem = { 0.28, 0.5, 0.55 },
	keyring = { 0.55, 0.5, 0.22 },
	reagent = { 0.28, 0.42, 0.52 },
}
local FILL_SHARE = 0.5
local CONTAINER, QUIVER = 1, 11
local SUBCLASS_FILLS = { [1] = "soul", [2] = "herb", [3] = "enchanting", [4] = "engineering", [5] = "gem", [6] = "mining", [7] = "leather",
	[11] = "reagent" }
local DEFAULTS = { itemLevel = true, quality = "all", marks = true, junkCoin = true, newGlow = true }
local SAY = {
	fight = "Bags: the bank's slots wait for the end of the fight.",
	closed = "Bags: the bank is not open.",
	refused = "Bags: the game refused its bag slot template, so the bag window cannot use your items. /reload tries again.",
}
local SAY_GAP = 2
local COUNT_LINE = "%d in this slot"
local SEEN = { today = "Last seen today", yesterday = "Last seen yesterday", days = "Last seen %d days ago" }
local DAY = 86400
local FADES = { "level", "bind", "tint", "food", "learn" }
local NONE = {}

local states = setmetatable({}, { __mode = "k" })
local holders = {}
local live = {}
local sizes = {}
local banks = {}
local pool = {}
local used = {}
local offlineMade = 0
local unwarmed = {}
local warming = nil
local pending, nextIndex, running = nil, 1, false
local queued, refused = false, false
local keyringShown = nil
local shelf = nil
local levels = {}
local foodIcon = nil
local said = {}

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function IsFrame(value)
	return Usable(value) and type(value.GetObjectType) == "function"
end

local function Plain(value)
	if ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Text(value)
	if ns.IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function Whole(value)
	return ns.Finite(value) and value % 1 == 0
end

local function IsBag(bag)
	return Whole(bag) and (bag == KEYRING or (bag >= 0 and bag <= REAGENT_BAG))
end

local function IsTab(bag)
	return Whole(bag) and bag >= FIRST_TAB and bag <= LAST_TAB
end

local function Field(frame, key)
	local value = frame[key]
	if Usable(value) then
		return value
	end
	return nil
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		return nil
	end
	return a, b
end

local function Part(fn, ...)
	local part = B.Part
	if type(part) == "function" then
		return part(PART, fn, ...)
	end
	return pcall(fn, ...)
end

local function On()
	return Ask(B.On) == true
end

local function Me()
	return (Ask(B.Me))
end

local function Opt(key)
	local value = Ask(B.Opt, key)
	if value == nil then
		value = DEFAULTS[key]
	end
	return value
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

local function Say(text)
	local now = 0
	if type(GetTime) == "function" then
		local ok, stamp = pcall(GetTime)
		if ok and ns.Finite(stamp) then
			now = stamp
		end
	end
	local last = said[text]
	if last ~= nil and now - last < SAY_GAP and now >= last then
		return
	end
	said[text] = now
	print(text)
end

local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, fn) then
		return
	end
	fn()
end

local function BankLive()
	return Ask(Bank.Live) == true
end

local function Searching()
	return Ask(Search.Active) == true
end

local function Container(name)
	local api = C_Container
	if type(api) ~= "table" or ns.IsSecret(api) or type(api[name]) ~= "function" then
		return nil
	end
	return api[name]
end

local function SizeOf(bag)
	local call = Container("GetContainerNumSlots")
	if call == nil then
		return 0
	end
	local ok, count = pcall(call, bag)
	if ok and ns.Finite(count) and count > 0 then
		return math.floor(count)
	end
	return 0
end

local function Info(bag, slot)
	local call = Container("GetContainerItemInfo")
	if call == nil then
		return nil
	end
	local ok, info = pcall(call, bag, slot)
	if ok and Usable(info) then
		return info
	end
	return nil
end

local function Broken(bag, slot)
	local call = Container("GetContainerItemDurability")
	if call == nil then
		return false
	end
	local ok, current, most = pcall(call, bag, slot)
	return ok and ns.Finite(current) and ns.Finite(most) and most > 0 and current <= 0
end

local function KeyringShows()
	local api = C_ActionBar
	if type(api) ~= "table" or ns.IsSecret(api) or type(api.ShouldShowKeyring) ~= "function" then
		return false
	end
	local ok, shows = pcall(api.ShouldShowKeyring)
	return ok and not ns.IsSecret(shows) and shows == true
end

local function QualityColour(quality)
	if not ns.Finite(quality) then
		return nil
	end
	local manager = _G.ColorManager
	if not Usable(manager) or type(manager.GetColorDataForBagItemQuality) ~= "function" then
		return nil
	end
	local ok, colour = pcall(manager.GetColorDataForBagItemQuality, quality)
	if ok and Usable(colour) and ns.Finite(colour.r) and ns.Finite(colour.g) and ns.Finite(colour.b) then
		return colour.r, colour.g, colour.b
	end
	return nil
end

local function LevelOf(link)
	local known = levels[link]
	if known ~= nil then
		return known
	end
	local items = ns.Items
	local value = Usable(items) and Ask(items.LevelOf, link) or nil
	if ns.Finite(value) and value > 0 then
		levels[link] = value
		return value
	end
	return nil
end

local function FoodIcon()
	if foodIcon == nil then
		foodIcon = false
		local api = C_Spell
		if type(api) == "table" and not ns.IsSecret(api) and type(api.GetSpellTexture) == "function" then
			local ok, file = pcall(api.GetSpellTexture, FEED_PET)
			if ok and (ns.Finite(file) or Text(file)) then
				foodIcon = file
			end
		end
	end
	return foodIcon or nil
end

local function RecordOf(value)
	if Usable(value) and ns.Finite(value.id) then
		return value
	end
	return nil
end

local function IconOf(record)
	local icon = record.icon
	if ns.Finite(icon) or Text(icon) then
		return icon
	end
	return UNKNOWN_ICON
end

local function CountOf(record)
	local count = record.count
	if ns.Finite(count) and count >= 1 then
		return math.floor(count)
	end
	return 1
end

local function NameOf(record)
	local name = Text(record.name)
	if name then
		return name
	end
	local api = C_Item
	if type(api) == "table" and not ns.IsSecret(api) and type(api.GetItemNameByID) == "function" then
		local ok, found = pcall(api.GetItemNameByID, record.id)
		if ok and Text(found) then
			return found
		end
	end
	return "Item " .. tostring(math.floor(record.id))
end

local function KindFill(kind, bag)
	if bag == KEYRING then
		return KIND_FILLS.keyring
	elseif bag == REAGENT_BAG then
		return KIND_FILLS.reagent
	end
	if not Usable(kind) then
		return nil
	end
	local key = Plain(kind.key)
	if key == "keyring" or key == "reagent" then
		return KIND_FILLS[key]
	end
	local class, subclass = Plain(kind.class), Plain(kind.subclass)
	if class == QUIVER then
		return KIND_FILLS.quiver
	elseif class == CONTAINER and ns.Finite(subclass) then
		local name = SUBCLASS_FILLS[subclass]
		return name and KIND_FILLS[name] or nil
	end
	return nil
end

local function Shelf()
	if shelf == nil then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent)
		if not ok or not IsFrame(made) then
			return nil
		end
		ns.Own[made] = true
		pcall(made.Hide, made)
		shelf = made
	end
	return shelf
end

local function Home(which)
	local frame = Ask(Window.Get, which)
	if Usable(frame) then
		local content = rawget(frame, "content")
		if IsFrame(content) then
			return content
		elseif IsFrame(frame) then
			return frame
		end
	end
	return Shelf()
end

local function LevelOfFrame(frame)
	local ok, level = pcall(frame.GetFrameLevel, frame)
	if ok and ns.Finite(level) then
		return level
	end
	return nil
end

local function Above(frame, under)
	local mine, base = LevelOfFrame(frame), LevelOfFrame(under)
	if mine ~= nil and base ~= nil and mine <= base then
		pcall(frame.SetFrameLevel, frame, math.min(base + 1, 10000))
	end
end

local function Lift(button, state)
	if state.holder then
		Above(button, state.holder)
	end
	if state.cooldown then
		Above(state.cooldown, button)
	end
	local outline = state.outline
	if Usable(outline) and IsFrame(outline.holder) then
		Above(outline.holder, button)
	end
end

local function LiftBag(bag)
	for _, button in pairs(live[bag] or NONE) do
		local state = states[button]
		if state then
			Lift(button, state)
		end
	end
end

local function Rehome(frame, which, fill)
	if shelf == nil then
		return false
	end
	local ok, parent = pcall(frame.GetParent, frame)
	if not ok or ns.IsSecret(parent) or not rawequal(parent, shelf) then
		return false
	end
	local home = Home(which)
	if home == nil or rawequal(home, shelf) then
		return false
	end
	pcall(frame.SetParent, frame, home)
	if fill then
		pcall(frame.ClearAllPoints, frame)
		pcall(frame.SetAllPoints, frame, home)
	end
	return true
end

local function RehomeAll()
	if shelf == nil then
		return
	end
	for bag, holder in pairs(holders) do
		if Rehome(holder, "bags", true) then
			LiftBag(bag)
		end
	end
	for _, list in pairs(banks) do
		for _, button in pairs(list) do
			Rehome(button, "bank", false)
		end
	end
end

local function Keep(button, state)
	local holder = state.holder
	local ok, parent = pcall(button.GetParent, button)
	if not ok or ns.IsSecret(parent) or rawequal(parent, holder) then
		return
	end
	if IsFrame(parent) then
		pcall(holder.SetParent, holder, parent)
		pcall(holder.ClearAllPoints, holder)
		pcall(holder.SetAllPoints, holder, parent)
	end
	pcall(button.SetParent, button, holder)
	LiftBag(state.bag)
end

local function CropShare()
	local crop = Ask(B.Look, "crop")
	if not ns.Finite(crop) then
		crop = ns.Get("windows.crop")
	end
	if not ns.Finite(crop) then
		crop = CROP
	end
	return math.max(0, math.min(CROP_MOST, crop)) / 100
end

local function PanelColour()
	local ok, r, g, b = pcall(ns.Colour, "windows.panel")
	if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return PANEL[1], PANEL[2], PANEL[3]
end

local function FillColour(state)
	local r, g, b = PanelColour()
	local kind = state.fill
	if kind then
		r = r + (kind[1] - r) * FILL_SHARE
		g = g + (kind[2] - g) * FILL_SHARE
		b = b + (kind[3] - b) * FILL_SHARE
	end
	return r, g, b
end

local function EdgeColour(state)
	if state.broken then
		return BROKEN[1], BROKEN[2], BROKEN[3]
	end
	local record = state.record
	local least = MIN_QUALITY[Opt("quality")]
	if record == nil or least == nil or not ns.Finite(record.quality) or record.quality < least then
		return nil
	end
	return QualityColour(record.quality)
end

local function Crop(state)
	local icon = state.icon
	if icon then
		local share = CropShare()
		pcall(icon.SetTexCoord, icon, share, 1 - share, share, 1 - share)
	end
end

local function PaintOne(state)
	Crop(state)
	local outline = state.outline
	if outline then
		local r, g, b = FillColour(state)
		ns.SetOutlineFill(outline, r, g, b, 1)
		ns.SetOutlineColour(outline, EdgeColour(state))
	end
end

local function Retint(texture, button, colour)
	if not Usable(texture) then
		return
	end
	pcall(texture.SetColorTexture, texture, colour[1], colour[2], colour[3], colour[4])
	pcall(texture.ClearAllPoints, texture)
	pcall(texture.SetAllPoints, texture, button)
end

local function Style(button, state)
	local icon = Field(button, "icon") or Field(button, "Icon")
	local mask = Field(button, "Mask")
	state.icon = icon
	state.cooldown = Field(button, "Cooldown")
	local okNormal, normal = pcall(button.GetNormalTexture, button)
	if okNormal and Usable(normal) then
		pcall(normal.SetAlpha, normal, 0)
	end
	if icon and mask then
		pcall(icon.RemoveMaskTexture, icon, mask)
	end
	local okHighlight, highlight = pcall(button.GetHighlightTexture, button)
	if okHighlight then
		Retint(highlight, button, HOVER)
	end
	local okPushed, pushed = pcall(button.GetPushedTexture, button)
	if okPushed and Usable(pushed) then
		if mask then
			pcall(pushed.RemoveMaskTexture, pushed, mask)
		end
		Retint(pushed, button, SLOT_PRESSED)
	end
	local battlepay = Field(button, "BattlepayItemTexture")
	if battlepay then
		pcall(battlepay.Hide, battlepay)
	end
	local ok, outline = pcall(ns.Outline, button, button)
	state.outline = ok and outline or nil
	PaintOne(state)
end

local function Made(button, layer, sublevel)
	local ok, texture = pcall(button.CreateTexture, button, nil, layer, nil, sublevel)
	if not ok or not Usable(texture) then
		return nil
	end
	ns.Own[texture] = true
	return texture
end

local function LevelText(button)
	local text = ns.OwnText(button, "OVERLAY", LEVEL_FONT)
	if text == nil then
		return nil
	end
	local ok, file = pcall(text.GetFont, text)
	if ok and Text(file) then
		pcall(text.SetFont, text, file, LEVEL_SIZE, "OUTLINE")
	end
	pcall(text.SetPoint, text, "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	return text
end

local function BindText(button)
	local text = ns.OwnText(button, "OVERLAY", BIND_FONT)
	if text == nil then
		return nil
	end
	pcall(text.SetPoint, text, "TOPLEFT", button, "TOPLEFT", 2, -2)
	pcall(text.SetTextColor, text, BIND_COLOUR[1], BIND_COLOUR[2], BIND_COLOUR[3], 1)
	pcall(text.SetText, text, BIND_WORD)
	return text
end

local function LearnText(button)
	local text = ns.OwnText(button, "OVERLAY", LEARN.font)
	if text == nil then
		return nil
	end
	local ok, file = pcall(text.GetFont, text)
	if ok and Text(file) then
		pcall(text.SetFont, text, file, LEARN.size, "OUTLINE")
	end
	pcall(text.SetPoint, text, "BOTTOMLEFT", button, "BOTTOMLEFT", 3, 1)
	pcall(text.SetTextColor, text, LEARN.colour[1], LEARN.colour[2], LEARN.colour[3], 1)
	pcall(text.SetText, text, LEARN.word)
	return text
end

local function TintTexture(button, state)
	local texture = Made(button, "BORDER", 7)
	if texture == nil then
		return nil
	end
	pcall(texture.SetColorTexture, texture, TINT[1], TINT[2], TINT[3], 1)
	pcall(texture.SetBlendMode, texture, "MOD")
	pcall(texture.SetAllPoints, texture, state.icon or button)
	return texture
end

local function FoodTexture(button)
	local texture = Made(button, "OVERLAY", 2)
	if texture == nil then
		return nil
	end
	local icon = FoodIcon()
	if not (icon and pcall(texture.SetTexture, texture, icon) and pcall(texture.SetTexCoord, texture, 0.08, 0.92, 0.08, 0.92)) then
		pcall(texture.SetColorTexture, texture, FOOD_COLOUR[1], FOOD_COLOUR[2], FOOD_COLOUR[3], 1)
	end
	pcall(texture.SetSize, texture, FOOD_SIZE, FOOD_SIZE)
	pcall(texture.SetPoint, texture, "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	return texture
end

local function JunkTexture(button)
	local texture = Made(button, "OVERLAY", 5)
	if texture == nil then
		return nil
	end
	pcall(texture.SetAtlas, texture, JUNK_ATLAS, true)
	pcall(texture.SetPoint, texture, "TOPLEFT", button, "TOPLEFT", 1, 0)
	return texture
end

local function QuestTexture(button)
	local texture = Made(button, "OVERLAY", 2)
	if texture == nil then
		return nil
	end
	pcall(texture.SetSize, texture, QUEST_WIDTH, QUEST_HEIGHT)
	pcall(texture.SetPoint, texture, "TOP", button, "TOP", 0, 0)
	return texture
end

local function FreeText(button)
	local text = ns.OwnText(button, "OVERLAY", FREE_FONT)
	if text == nil then
		return nil
	end
	pcall(text.SetPoint, text, "CENTER", button, "CENTER", 0, 0)
	pcall(text.SetTextColor, text, FREE_COLOUR[1], FREE_COLOUR[2], FREE_COLOUR[3], 1)
	return text
end

local function Region(button, state, key, want, make)
	local region = state[key]
	if want and region == nil then
		region = make(button, state) or false
		state[key] = region
	end
	return region or nil
end

local function Mark(button, state, key, want, make)
	local region = Region(button, state, key, want, make)
	if region then
		pcall(region.SetShown, region, want)
	end
	return region
end

local function SetIcon(state, icon)
	local texture = state.icon
	if texture == nil then
		return
	end
	if icon ~= nil then
		pcall(texture.SetTexture, texture, icon)
		Crop(state)
		pcall(texture.Show, texture)
	else
		pcall(texture.SetTexture, texture, nil)
		pcall(texture.Hide, texture)
	end
end

local function SetLocked(state, locked)
	local icon = state.icon
	if icon then
		pcall(icon.SetDesaturated, icon, locked == true)
	end
end

local function Cooldown(state)
	local frame = state.cooldown
	if frame == nil then
		return
	end
	local grey = false
	local record = state.record
	if record ~= nil and record.live == true then
		local call = Container("GetContainerItemCooldown")
		local ok, start, duration, enable = false, nil, nil, nil
		if call then
			ok, start, duration, enable = pcall(call, state.bag, state.slot)
		end
		if not (ok and ns.Finite(start) and ns.Finite(duration) and ns.Finite(enable)) then
			start, duration, enable = 0, 0, 0
		end
		if type(CooldownFrame_Set) == "function" then
			pcall(CooldownFrame_Set, frame, start, duration, enable)
		end
		grey = duration > 0 and enable == 0
	else
		pcall(frame.Hide, frame)
	end
	local icon = state.icon
	if icon then
		local shade = grey and GREY or 1
		pcall(icon.SetVertexColor, icon, shade, shade, shade)
	end
end

local function Glow(button, record)
	if record ~= nil and Opt("newGlow") ~= false then
		pcall(button.UpdateNewItem, button, ns.Finite(record.quality) and record.quality or nil)
		return
	end
	for _, key in ipairs({ "NewItemTexture", "BattlepayItemTexture" }) do
		local texture = Field(button, key)
		if texture then
			pcall(texture.Hide, texture)
		end
	end
	for _, key in ipairs({ "flashAnim", "newitemglowAnim" }) do
		local anim = Field(button, key)
		if anim then
			pcall(anim.Stop, anim)
		end
	end
end

local function OwnQuest(button, state, record)
	local bang = record ~= nil and record.questStart == true
	local border = record ~= nil and record.quest == true
	local texture = Mark(button, state, "quest", bang or border, QuestTexture)
	if texture and (bang or border) then
		local art = bang and QUEST_BANG or QUEST_BORDER
		pcall(texture.SetTexture, texture, Text(_G[art[1]]) or art[2])
	end
end

local function SlotsOf(state, record, link)
	local class = Ask(Categories.Kind, record)
	if class ~= CONTAINER_CLASS and class ~= QUIVER_CLASS then
		return nil
	end
	local live = record.live == true and state.kind ~= "offline"
	local size = Ask(B.Slots and B.Slots.SizeOf, record.id, link, live and record.bag or nil, live and record.slot or nil)
	if ns.Finite(size) and size > 0 then
		return math.floor(size)
	end
	return nil
end

local function Level(button, state, record, link)
	local value, size = nil, nil
	if record ~= nil and Opt("itemLevel") ~= false then
		value = link ~= nil and LevelOf(link) or nil
		if value ~= nil and record.level == nil then
			record.level = value
		end
		if value == nil then
			size = SlotsOf(state, record, link)
		end
	end
	local text = Mark(button, state, "level", value ~= nil or size ~= nil, LevelText)
	if text and value ~= nil then
		local r, g, b = QualityColour(record.quality)
		if r == nil then
			r, g, b = WHITE[1], WHITE[2], WHITE[3]
		end
		pcall(text.SetTextColor, text, r, g, b, 1)
		pcall(text.SetText, text, tostring(math.floor(value + 0.5)))
	elseif text and size ~= nil then
		pcall(text.SetTextColor, text, DIM_TEXT[1], DIM_TEXT[2], DIM_TEXT[3], 1)
		pcall(text.SetText, text, tostring(size))
	end
end

local function JunkShown(record)
	return record ~= nil and Opt("junkCoin") ~= false and Ask(Categories.IsJunk, record) == true
end

local function Marks(button, state, record, link, junk)
	local bind, tint, food, learn = false, false, false, false
	if record ~= nil and Opt("marks") ~= false and Usable(ItemMarks) then
		bind = not junk and Ask(ItemMarks.BoE, record.id, link, record.bound == true) == true
		if record.key == Me() then
			local bag, slot = nil, nil
			if record.live == true then
				bag, slot = record.bag, record.slot
			end
			tint = Ask(ItemMarks.Unusable, record.id, link, bag, slot) == true
			learn = not tint and Ask(ItemMarks.Learnable, record.id, link, bag, slot) == true
			food = Ask(ItemMarks.Eats, record.id) == true
		end
	end
	Mark(button, state, "bind", bind, BindText)
	Mark(button, state, "tint", tint, TintTexture)
	Mark(button, state, "food", food, FoodTexture)
	Mark(button, state, "learn", learn, LearnText)
end

local function Junk(button, state, show)
	if state.kind == "live" then
		local coin = Field(button, "JunkIcon")
		if coin then
			pcall(coin.SetShown, coin, show)
		end
	else
		Mark(button, state, "junk", show, JunkTexture)
	end
end

local function FreeCount(button, state, count)
	local want = ns.Finite(count) and count >= 0
	local text = Mark(button, state, "freeText", want, FreeText)
	if text and want then
		pcall(text.SetText, text, tostring(math.floor(count)))
	end
end

function Buttons.Dim(button, matched, lit)
	local state = states[button]
	if state == nil then
		return
	end
	local dim
	if lit then
		dim = matched ~= true
	else
		dim = state.record ~= nil and matched ~= true and Searching()
	end
	pcall(button.SetMatchesSearch, button, not dim)
	local alpha = dim and FADED or 1
	for _, key in ipairs(FADES) do
		local region = state[key]
		if region then
			pcall(region.SetAlpha, region, alpha)
		end
	end
end

function Buttons.Draw(button, record, opts)
	local state = states[button]
	if state == nil then
		return
	end
	if not Usable(opts) then
		opts = NONE
	end
	record = RecordOf(record)
	if state.kind == "live" then
		Keep(button, state)
	end
	if record ~= nil and (state.kind == "live" or state.kind == "bank") and not (record.bag == state.bag and record.slot == state.slot) then
		record = RecordOf(Ask(Data.Item, Me(), state.bag, state.slot))
	end
	state.record, state.opts = record, opts
	local empty = record == nil and opts.hold ~= true
	local link = record and Text(record.link) or nil
	local icon = record and IconOf(record) or nil
	local reading = record ~= nil and record.live == true and state.kind ~= "offline"
	local info = reading and Info(state.bag, state.slot) or nil
	SetIcon(state, icon)
	if type(SetItemButtonCount) == "function" then
		pcall(SetItemButtonCount, button, record and CountOf(record) or 0)
	end
	if info ~= nil then
		SetLocked(state, Plain(info.isLocked) == true)
	else
		SetLocked(state, record ~= nil and record.locked == true)
	end
	if state.kind == "live" then
		pcall(button.SetHasItem, button, icon)
		pcall(button.SetReadable, button, info ~= nil and Plain(info.isReadable) == true or nil)
		Cooldown(state)
		pcall(button.UpdateQuestItem, button, record ~= nil and record.quest == true, record ~= nil and record.questStart == true or nil, false)
		Glow(button, record)
	else
		OwnQuest(button, state, record)
	end
	state.broken = reading and Broken(state.bag, state.slot) or false
	state.fill = empty and opts.kind ~= nil and KindFill(opts.kind, state.bag) or nil
	PaintOne(state)
	Level(button, state, record, link)
	local junk = JunkShown(record)
	Marks(button, state, record, link, junk)
	Junk(button, state, junk)
	if state.kind == "live" then
		Ask(B.Pins.Mark, button, state.kind, state.bag, state.slot, record)
	end
	FreeCount(button, state, empty and opts.free or nil)
	if record ~= nil and record.name == nil then
		Ask(Data.Want, record.id)
	end
	local matched = true
	if record ~= nil and Searching() then
		matched = Ask(Search.Match, record)
	end
	Buttons.Dim(button, matched)
end

local function Tooltip()
	local tip = _G.GameTooltip
	if Usable(tip) and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

local function HideTip(button)
	local tip = Tooltip()
	if tip == nil then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not ns.IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

local function Built(ok, answer)
	return ok and not ns.IsSecret(answer) and answer == true
end

local function NoonOf(stamp)
	local ok, parts = pcall(date, "*t", stamp)
	if not ok or not Usable(parts) then
		return nil
	end
	local okNoon, noon = pcall(time, { year = parts.year, month = parts.month, day = parts.day, hour = 12 })
	if not okNoon or not ns.Finite(noon) then
		return nil
	end
	return noon
end

local function SeenPhrase(stamp)
	if not ns.Finite(stamp) then
		return nil
	end
	local okNow, now = pcall(time)
	if not okNow or not ns.Finite(now) then
		return nil
	end
	local today, seen = NoonOf(now), NoonOf(stamp)
	if today == nil or seen == nil then
		return nil
	end
	local days = math.floor((today - seen) / DAY + 0.5)
	if days <= 0 then
		return SEEN.today
	elseif days == 1 then
		return SEEN.yesterday
	end
	return SEEN.days:format(days)
end

local function SeenLine(record)
	if record.live == true then
		return nil
	end
	local list = Ask(Data.Characters)
	if not Usable(list) then
		return nil
	end
	for _, entry in ipairs(list) do
		if Usable(entry) and entry.key == record.key then
			return SeenPhrase(IsTab(record.bag) and entry.bankSeen or entry.seen)
		end
	end
	return nil
end

local function PlainTip(tip, state)
	local record = state.record
	if record == nil then
		return false
	end
	local r, g, b = QualityColour(record.quality)
	if r == nil then
		r, g, b = WHITE[1], WHITE[2], WHITE[3]
	end
	if not pcall(tip.SetText, tip, NameOf(record), r, g, b) then
		return false
	end
	local count = CountOf(record)
	if count > 1 then
		pcall(tip.AddLine, tip, COUNT_LINE:format(count), WHITE[1], WHITE[2], WHITE[3])
	end
	return true
end

local function Entered(button)
	local state = states[button]
	local tip = Tooltip()
	if state == nil or tip == nil then
		return
	end
	local record = state.record
	if record == nil then
		HideTip(button)
		return
	end
	if not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	local shown = false
	if not Fighting() then
		if state.kind == "bank" and record.live == true and BankLive() then
			shown = Built(pcall(tip.SetBagItem, tip, state.bag, state.slot))
		else
			local link = Text(record.link)
			if link ~= nil then
				shown = Built(pcall(tip.SetHyperlink, tip, link))
			end
		end
	end
	if not shown then
		pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT")
		shown = PlainTip(tip, state)
	end
	local seen = record ~= nil and state.kind == "offline" and SeenLine(record) or nil
	if shown and seen ~= nil then
		pcall(tip.AddLine, tip, seen, DIM_TEXT[1], DIM_TEXT[2], DIM_TEXT[3])
	end
	if shown then
		pcall(tip.Show, tip)
	else
		HideTip(button)
	end
end

local function Modified(kind)
	if type(IsModifiedClick) ~= "function" then
		return false
	end
	local ok, held
	if kind then
		ok, held = pcall(IsModifiedClick, kind)
	else
		ok, held = pcall(IsModifiedClick)
	end
	return ok and not ns.IsSecret(held) and held == true
end

local function WholeLink(state)
	local link = nil
	if state.kind == "bank" and BankLive() then
		local call = Container("GetContainerItemLink")
		if call then
			local ok, found = pcall(call, state.bag, state.slot)
			link = ok and Text(found) or nil
		end
	end
	if link == nil and state.record ~= nil then
		link = Text(state.record.link)
	end
	if link == nil then
		return nil
	end
	if link:find("|H", 1, true) then
		return link
	end
	local api = C_Item
	if type(api) == "table" and not ns.IsSecret(api) and type(api.GetItemInfo) == "function" then
		local ok, _, whole = pcall(api.GetItemInfo, link)
		if ok and Text(whole) and whole:find("|H", 1, true) then
			return whole
		end
	end
	return nil
end

local function Linked(state)
	local link = WholeLink(state)
	if link == nil then
		return
	end
	if Fighting() then
		local util = _G.ChatFrameUtil
		if Modified("CHATLINK") and Usable(util) and type(util.InsertLink) == "function" then
			pcall(util.InsertLink, link)
		end
		return
	end
	if type(HandleModifiedItemClick) == "function" then
		pcall(HandleModifiedItemClick, link)
	end
end

local function Use(state, mouse)
	if Fighting() then
		Say(SAY.fight)
		return
	end
	if not BankLive() then
		Say(SAY.closed)
		return
	end
	if mouse == "RightButton" then
		local use = Container("UseContainerItem")
		if use then
			pcall(use, state.bag, state.slot)
		end
	else
		local pickup = Container("PickupContainerItem")
		if pickup then
			pcall(pickup, state.bag, state.slot)
		end
	end
end

local function Clicked(button, mouse)
	local state = states[button]
	if state == nil then
		return
	end
	if Modified(nil) then
		Linked(state)
	elseif state.kind ~= "offline" then
		Use(state, mouse)
	end
end

local function Dragged(button)
	local state = states[button]
	if state ~= nil and state.kind ~= "offline" then
		Use(state, "LeftButton")
	end
end

local function OnClick(button, mouse)
	Part(Clicked, button, mouse)
end

local function OnDrag(button)
	Part(Dragged, button)
end

local function OnEnter(button)
	Part(Entered, button)
end

local function OnLeave(button)
	pcall(HideTip, button)
end

local function Scripts(button, state)
	pcall(button.RegisterForClicks, button, "LeftButtonUp", "RightButtonUp")
	pcall(button.SetScript, button, "OnClick", OnClick)
	pcall(button.SetScript, button, "OnEnter", OnEnter)
	pcall(button.SetScript, button, "OnLeave", OnLeave)
	if state.kind ~= "offline" then
		pcall(button.RegisterForDrag, button, "LeftButton")
		pcall(button.SetScript, button, "OnDragStart", OnDrag)
		pcall(button.SetScript, button, "OnReceiveDrag", OnDrag)
	end
end

local function Holder(bag)
	local holder = holders[bag]
	if holder ~= nil then
		return holder
	end
	local home = Home("bags")
	local ok, made = pcall(CreateFrame, "Frame", nil, home)
	if not ok or not IsFrame(made) then
		return nil
	end
	ns.Own[made] = true
	pcall(made.SetID, made, bag)
	if home then
		pcall(made.SetAllPoints, made, home)
	end
	if bag == KEYRING then
		pcall(made.SetShown, made, keyringShown == true)
	end
	holders[bag] = made
	return made
end

local function Make(bag, slot, warm)
	local list = live[bag]
	if list == nil then
		list = {}
		live[bag] = list
	end
	if list[slot] ~= nil then
		return list[slot]
	end
	if refused or Fighting() then
		return nil
	end
	local holder = Holder(bag)
	if holder == nil then
		return nil
	end
	local ok, button = pcall(CreateFrame, "ItemButton", LIVE_NAME:format(bag + 10, slot), holder, TEMPLATE)
	if not ok or not IsFrame(button) then
		refused = true
		ns.Note(KEY, SAY.refused)
		return nil
	end
	ns.Own[button] = true
	pcall(button.SetID, button, slot)
	local state = { kind = "live", bag = bag, slot = slot, holder = holder }
	states[button] = state
	Style(button, state)
	Lift(button, state)
	Ask(B.Pins.Hook, button, bag, slot)
	list[slot] = button
	if warm then
		unwarmed[#unwarmed + 1] = button
	end
	return button
end

local function MakeOwn(name, parent, kind, bag, slot)
	local ok, button = pcall(CreateFrame, "ItemButton", name, parent)
	if not ok or not IsFrame(button) then
		return nil
	end
	ns.Own[button] = true
	pcall(button.Hide, button)
	local state = { kind = kind, bag = bag, slot = slot }
	states[button] = state
	Style(button, state)
	Scripts(button, state)
	return button
end

function Buttons.Live(bag, slot)
	if not IsBag(bag) or not Whole(slot) or slot < 1 then
		return nil
	end
	if bag == KEYRING then
		if keyringShown == nil then
			keyringShown = KeyringShows()
		end
		if not keyringShown then
			return nil
		end
	end
	if sizes[bag] == nil or slot > sizes[bag] then
		sizes[bag] = SizeOf(bag)
	end
	if slot > sizes[bag] then
		return nil
	end
	local list = live[bag]
	local button = list and list[slot] or nil
	if button == nil then
		button = Make(bag, slot, false)
		if button == nil then
			return nil
		end
	end
	local state = states[button]
	Keep(button, state)
	if Rehome(state.holder, "bags", true) then
		LiftBag(bag)
	end
	return button
end

function Buttons.Bank(tab, slot)
	if not Whole(slot) or slot < 1 or not IsTab(tab) then
		return nil
	end
	local list = banks[tab]
	if list == nil then
		list = {}
		banks[tab] = list
	end
	local button = list[slot]
	if button ~= nil then
		Rehome(button, "bank", false)
		return button
	end
	button = MakeOwn(BANK_NAME:format(tab, slot), Home("bank"), "bank", tab, slot)
	list[slot] = button
	return button
end

local function ParentFor(owner)
	if IsFrame(owner) then
		return owner
	elseif owner == "bank" then
		return Home("bank")
	end
	return Home("bags")
end

function Buttons.Offline(owner)
	local key = owner
	if key == nil then
		key = "bags"
	end
	local parent = ParentFor(owner)
	local button = table.remove(pool)
	if button == nil then
		offlineMade = offlineMade + 1
		button = MakeOwn(OFFLINE_NAME:format(offlineMade), parent, "offline")
		if button == nil then
			return nil
		end
	else
		local ok, current = pcall(button.GetParent, button)
		if parent ~= nil and not (ok and not ns.IsSecret(current) and rawequal(current, parent)) then
			pcall(button.SetParent, button, parent)
		end
	end
	states[button].owner = key
	local list = used[key]
	if list == nil then
		list = {}
		used[key] = list
	end
	list[#list + 1] = button
	return button
end

local function Return(button)
	pcall(button.Hide, button)
	HideTip(button)
	local state = states[button]
	if state then
		state.record, state.opts, state.owner = nil, nil, nil
	end
	pool[#pool + 1] = button
end

function Buttons.Release(owner)
	if owner == nil then
		for key, list in pairs(used) do
			used[key] = nil
			for _, button in ipairs(list) do
				Return(button)
			end
		end
		return
	end
	local list = used[owner]
	if list == nil then
		return
	end
	used[owner] = nil
	for _, button in ipairs(list) do
		Return(button)
	end
end

local function Unsplit(button)
	local ok, value = pcall(rawget, button, "hasStackSplit")
	if ok and not ns.IsSecret(value) and value == 1 then
		button.hasStackSplit = 0
	end
end

function Buttons.Unsplit(button)
	if button ~= nil then
		local state = states[button]
		if state ~= nil and state.kind == "live" then
			Unsplit(button)
		end
		return
	end
	for _, list in pairs(live) do
		for _, made in pairs(list) do
			Unsplit(made)
		end
	end
end

function Buttons.ShowAll(on)
	if not on then
		local was = warming
		warming = nil
		if was == nil then
			return
		end
		for button, shown in pairs(was) do
			if not shown then
				Unsplit(button)
				pcall(button.Hide, button)
			end
		end
		return
	end
	RehomeAll()
	warming = warming or {}
	for bag, list in pairs(live) do
		local holder = holders[bag]
		local okShown, shows = false, false
		if holder then
			okShown, shows = pcall(holder.IsShown, holder)
		end
		if okShown and not ns.IsSecret(shows) and shows == true then
			local size = sizes[bag] or 0
			for slot, button in pairs(list) do
				if slot <= size then
					Keep(button, states[button])
					if warming[button] == nil then
						local ok, shown = pcall(button.IsShown, button)
						warming[button] = ok and not ns.IsSecret(shown) and shown == true
					end
					pcall(button.Show, button)
				end
			end
		end
	end
end

local function Wanted(containers)
	keyringShown = KeyringShows()
	local keyring = holders[KEYRING]
	if keyring then
		if not keyringShown then
			for _, button in pairs(live[KEYRING] or NONE) do
				Unsplit(button)
			end
		end
		pcall(keyring.SetShown, keyring, keyringShown)
	end
	local list, taken = {}, {}
	local function Take(bag)
		if IsBag(bag) and not taken[bag] and (bag ~= KEYRING or keyringShown) then
			taken[bag] = true
			list[#list + 1] = bag
		end
	end
	if Usable(containers) then
		for _, bag in ipairs(containers) do
			Take(bag)
		end
	end
	for _, bag in ipairs(BAGS) do
		Take(bag)
	end
	Take(KEYRING)
	if not keyringShown then
		sizes[KEYRING] = 0
	end
	for _, bag in ipairs(list) do
		local size = SizeOf(bag)
		sizes[bag] = size
		for slot, button in pairs(live[bag] or NONE) do
			if slot > size then
				Unsplit(button)
				pcall(button.Hide, button)
			end
		end
	end
	return list
end

local function Missing(list)
	local missing = {}
	for _, bag in ipairs(list) do
		local made = live[bag]
		for slot = 1, sizes[bag] or 0 do
			if not (made and made[slot]) then
				missing[#missing + 1] = { bag, slot }
			end
		end
	end
	return missing
end

local function Finish()
	if #unwarmed == 0 or not On() then
		return
	end
	local list = unwarmed
	unwarmed = {}
	RehomeAll()
	Ask(Window.Warm, "bags", list)
end

local Queue

local function Step()
	if pending == nil then
		running = false
		return
	end
	if Fighting() then
		pending, running = nil, false
		Queue()
		return
	end
	local count = 0
	while pending ~= nil and nextIndex <= #pending and count < STEP do
		local entry = pending[nextIndex]
		nextIndex = nextIndex + 1
		count = count + 1
		Make(entry[1], entry[2], true)
		if refused then
			pending = nil
		end
	end
	if pending ~= nil and nextIndex <= #pending then
		Soon(function()
			Part(Step)
		end)
		return
	end
	pending, running = nil, false
	Finish()
end

local function Prepare(containers)
	local list = Wanted(containers)
	if Fighting() then
		Queue()
		return
	end
	local missing = Missing(list)
	if #missing == 0 then
		if not running then
			pending = nil
			Finish()
		end
		return
	end
	pending, nextIndex = missing, 1
	if not running then
		running = true
		Step()
	end
end

function Queue()
	if queued then
		return
	end
	queued = true
	ns.OutOfCombat(function()
		queued = false
		if On() then
			Buttons.Prepare(nil)
		end
	end)
end

function Buttons.Prepare(containers)
	Part(Prepare, containers)
end

local function TopUp()
	if not On() then
		return
	end
	local list = Wanted(nil)
	for _, entry in ipairs(Missing(list)) do
		Make(entry[1], entry[2], true)
	end
	pending, running = nil, false
	Finish()
end

function Buttons.Lock(bag, slot)
	if not Whole(bag) or not Whole(slot) then
		return
	end
	local list
	if IsBag(bag) then
		list = live[bag]
	elseif IsTab(bag) then
		list = banks[bag]
	end
	local button = list and list[slot] or nil
	local state = button and states[button] or nil
	if state == nil or state.record == nil or state.record.live ~= true then
		return
	end
	local info = Info(bag, slot)
	SetLocked(state, info ~= nil and Plain(info.isLocked) == true)
end

function Buttons.Cooldowns()
	local shown = false
	for _, holder in pairs(holders) do
		local ok, visible = pcall(holder.IsVisible, holder)
		if ok and not ns.IsSecret(visible) and visible == true then
			shown = true
			break
		end
	end
	if not shown then
		return
	end
	for _, list in pairs(live) do
		for _, button in pairs(list) do
			local state = states[button]
			if state and state.record ~= nil then
				local ok, visible = pcall(button.IsVisible, button)
				if ok and not ns.IsSecret(visible) and visible == true then
					Cooldown(state)
				end
			end
		end
	end
end

function Buttons.Paint()
	for _, state in pairs(states) do
		PaintOne(state)
	end
end

ns.AddEvent(KEY, "ITEM_LOCK_CHANGED", function(bag, slot)
	if On() then
		Part(Buttons.Lock, bag, slot)
	end
end, function(bag, slot)
	return ns.Finite(bag) and ns.Finite(slot)
end)

ns.AddEvent(KEY, "BAG_UPDATE_COOLDOWN", function()
	if On() then
		Part(Buttons.Cooldowns)
	end
end)

ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", function()
	Part(TopUp)
end)
