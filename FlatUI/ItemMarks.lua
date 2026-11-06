local _, ns = ...

-- Bag marks: three marks of this addon's own on the item slots of the bags and the bank, each its own row in the Bags section of Bags and items,
-- all on by default. Not a module: Items.lua dresses a bag or bank slot and calls ItemMarks.Dress for it, in a part of its own (PART).
-- Mark bind on equip items: BoE at the top left of an item that binds when equipped and is not bound yet. The binding is the 14th answer of
-- C_Item.GetItemInfo (ItemDocumentation.lua:626-650; Enum.ItemBind.OnEquip is 2, ItemConstantsDocumentation.lua:249-266), kept per item ID as it
-- never changes, and the slot says whether its item is bound (isBound of C_Container.GetContainerItemInfo, ContainerDocumentation.lua:766-783).
-- That is when the game's tooltip says "Binds when equipped", and no tooltip is read for it.
-- Tint items you cannot use: red over the icon of an item whose tooltip shows a requirement in red: a line of the kind UsageRequirement (class, race,
-- level, skill, reputation, PvP rank, a recipe already known) or the slot line, of the kind EquipSlot, whose armour or weapon type is red or that
-- the game marks as not for this character (isValidItemType, isValidInvSlot). TooltipInfoSharedDocumentation.lua:27-86 has the kinds, and the game
-- reads the same fields in Blizzard_PerksProgram/Blizzard_PerksProgramElements.lua:898-927. The tooltip is C_TooltipInfo.GetBagItem
-- (TooltipInfoDocumentation.lua:137-152), read once per item ID once the game has loaded the item. A level, a skill and a reputation only rise for
-- a player levelling, so after PLAYER_LEVEL_UP (read LEVEL_WAIT seconds later, once the game counts the new level), SKILL_LINES_CHANGED and
-- UPDATE_FACTION only the items found unusable are read again; a learned spell or recipe can make an item unusable and a PvP rank can fall, so
-- after LEARNED_SPELL_IN_SKILL_LINE, NEW_RECIPE_LEARNED and PLAYER_PVP_RANK_CHANGED every item is read again (UnitDocumentation.lua:3832, 3877;
-- SkillInfoDocumentation.lua:105; PaperDollInfoDocumentation.lua:432; SpellBookDocumentation.lua:851; TradeSkillUIDocumentation.lua:1239). So are
-- the unusable ones whenever the windows module applies its settings, since it hears no event while it is off. The red is a texture with the MOD
-- blend just above the icon (the icon is in the BORDER layer, Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:17-21), so it darkens the icon as
-- the game's own red on an item does, under the stack count, the search overlay and the other marks.
-- Mark food your pet eats: the Feed Pet icon at the bottom left of food the pet that is out eats. The answer is C_PetInfo.CanPetEatItem, the call
-- of the game's own Feed Pet item context and of its gamepad Feed To Pet (Blizzard_FrameXMLUtil/ItemUtil.lua:235-236,
-- Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua:3287-3301), kept per item ID while the diet of the pet (C_PetInfo.GetPetFoodTypes,
-- PetInfoDocumentation.lua:10-33) is the same; Forever has no call for the food type of an item. The diet is read when first needed and again
-- after UNIT_PET for the player (UnitDocumentation.lua:4448-4457), UNIT_LEVEL for the pet and each loading screen; a pet with no diet, such as a
-- warlock's, marks nothing.
-- When an answer goes old, and when an item that had not loaded arrives (GET_ITEM_INFO_RECEIVED, ItemDocumentation.lua:1815-1822), the shown bag
-- and bank slots are dressed again on the next frame (Items.Redraw); a hidden one is dressed when its bag or the bank opens. Every answer the game
-- may withhold marks nothing and is not kept. Nothing of the game's is written: a mark is a text or a texture of this addon's own made on the slot,
-- out of a fight while the slot is protected. On a client without one of the calls its mark is never made, and /flatui status says so.
-- These follow the bind status, unusable item and Hunter pet food overlays of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission.

local KEY = "windows"
local PART = "bag marks"
local KINDS = { "bind", "tint", "food" }
local ROWS = { bind = "windows.boeMark", tint = "windows.unusableTint", food = "windows.petFood" }
-- Enum.ItemBind.OnEquip, and Enum.TooltipDataLineType.UsageRequirement and EquipSlot, for a client whose Enum does not say.
local BIND_ON_EQUIP = 2
local USAGE, EQUIP_SLOT = 43, 21
-- The game's red for a requirement not met is 1, 0.125, 0.125 (RED_FONT_COLOR); any colour this close to it counts.
local RED_LEAST, OTHER_MOST = 0.9, 0.25
local BIND_WORD, BIND_FONT, BIND_COLOUR = "BoE", "NumberFontNormalSmall", { 0.38, 0.82, 1 }
local TINT = { 1, 0.18, 0.18 }
-- Feed Pet (ContainerFrame.lua:3287), whose icon marks food; a client that gives no icon gets a flat square of FOOD_COLOUR.
local FEED_PET, FOOD_SIZE, FOOD_COLOUR = 6991, 14, { 0.45, 0.85, 0.3 }
local LEVEL_WAIT = 2
local LABELS = { bind = "Mark bind on equip items", tint = "Tint items you cannot use", food = "Mark food your pet eats" }
local COUNTS = { bind = "%d bind on equip", tint = "%d you cannot use", food = "%d your pet eats" }
local MISSING = { bind = "binding of items", tint = "item tooltips", food = "diet of a pet" }

-- Per slot: { bind = the BoE text, tint = the red texture, food = the food texture, bindOn, tintOn, foodOn = true while shown, queued = true while a
-- fight keeps a mark from being made }.
local marks = setmetatable({}, { __mode = "k" })
-- Per item ID: its binding; true when it cannot be used, false when it can; true while its information has not loaded.
local binds, blocked, waiting = {}, {}, {}
-- The pet: diet is nil until read, false with no pet out or one that eats nothing, else its food types in one text; foods the list of them, and
-- eats the answer for each item ID.
local pet = { diet = nil, foods = nil, eats = {} }
-- Marks the game refused: the mark is off and says so on /flatui status.
local refused = {}
local foodIcon
local redrawQueued = false

local ItemMarks = { PART = PART }
ns.ItemMarks = ItemMarks

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- A frame or region held in a field of a frame that may not be touched or withheld.
local function Held(frame, key)
	if ns.Forbidden(frame) then
		return nil
	end
	local value = frame[key]
	if Usable(value) then
		return value
	end
	return nil
end

-- True when the game would refuse to make a texture or text on the frame now.
local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

-- The function called name in the client's namespace called space, or nil when the client has none.
local function Call(space, name)
	local namespace = _G[space]
	if type(namespace) ~= "table" or ns.IsSecret(namespace) then
		return nil
	end
	local fn = namespace[name]
	if type(fn) == "function" then
		return fn
	end
	return nil
end

-- A value of the client's Enum, or the fallback when it has none.
local function EnumValue(group, name, fallback)
	local enum = _G.Enum
	local values = type(enum) == "table" and not ns.IsSecret(enum) and enum[group] or nil
	local value = type(values) == "table" and not ns.IsSecret(values) and values[name] or nil
	if ns.Finite(value) then
		return value
	end
	return fallback
end

-- Runs fn on the next frame.
local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

-- True when the client has every call a mark needs.
local function Can(kind)
	if kind == "bind" then
		return Call("C_Item", "GetItemInfo") ~= nil
	elseif kind == "tint" then
		return Call("C_Item", "GetItemInfo") ~= nil and Call("C_TooltipInfo", "GetBagItem") ~= nil
	end
	return Call("C_PetInfo", "GetPetFoodTypes") ~= nil and Call("C_PetInfo", "CanPetEatItem") ~= nil
end

local function Wanted(kind)
	return ns.Enabled(KEY) and ns.Get(ROWS[kind]) == true and not refused[kind] and not ns.PartStopped(KEY, PART) and Can(kind)
end

local function Refuse(kind, what)
	refused[kind] = true
	ns.Note(KEY, ("Windows: %s stopped, the game refused %s on an item slot."):format(LABELS[kind], what))
end

-- Reading -------------------------------------------------------------------------------------

local function NameAndBinding(call, item)
	local name, _, _, _, _, _, _, _, _, _, _, _, _, bind = call(item)
	return name, bind
end

-- The binding of an item, or nil while the game has not loaded it: GetItemInfo then asks for it, and the item waits for GET_ITEM_INFO_RECEIVED.
local function Binding(id, link)
	local known = binds[id]
	if known ~= nil then
		return known
	end
	local call = Call("C_Item", "GetItemInfo")
	if call == nil then
		return nil
	end
	local ok, name, bind = pcall(NameAndBinding, call, link or id)
	if not ok or ns.IsSecret(name) then
		return nil
	elseif name == nil then
		waiting[id] = true
		return nil
	elseif not ns.Finite(bind) then
		return nil
	end
	binds[id] = bind
	return bind
end

-- True for an item that binds when equipped and that the slot says is not bound.
local function Unbound(id, link, info)
	local bound = info.isBound
	if ns.IsSecret(bound) or bound ~= false then
		return false
	end
	return Binding(id, link) == EnumValue("ItemBind", "OnEquip", BIND_ON_EQUIP)
end

local function Red(colour)
	if not Usable(colour) then
		return false
	end
	local r, g, b = colour.r, colour.g, colour.b
	return ns.Finite(r) and ns.Finite(g) and ns.Finite(b) and r >= RED_LEAST and g <= OTHER_MOST and b <= OTHER_MOST
end

local function IsFalse(value)
	return not ns.IsSecret(value) and value == false
end

-- True for a line of a tooltip that says in red that the character cannot use the item.
local function Unmet(line)
	local kind = line.type
	if not ns.Finite(kind) then
		return false
	end
	if kind == EnumValue("TooltipDataLineType", "UsageRequirement", USAGE) then
		return Red(line.leftColor)
	elseif kind == EnumValue("TooltipDataLineType", "EquipSlot", EQUIP_SLOT) then
		return IsFalse(line.isValidItemType) or IsFalse(line.isValidInvSlot) or Red(line.rightColor) or Red(line.leftColor)
	end
	return false
end

-- True when the item in this slot cannot be used, false when it can, nil when the game has not said yet. A tooltip of another item than the slot
-- had a moment ago is not kept.
local function Unusable(id, link, bag, slot)
	local known = blocked[id]
	if known ~= nil then
		return known
	end
	if Binding(id, link) == nil then
		return nil
	end
	local call = Call("C_TooltipInfo", "GetBagItem")
	if call == nil then
		return nil
	end
	local ok, data = pcall(call, bag, slot)
	if not ok or not Usable(data) then
		return nil
	end
	local of, lines = data.id, data.lines
	if (of ~= nil and not (ns.Finite(of) and of == id)) or not Usable(lines) then
		return nil
	end
	local answer = false
	for _, line in ipairs(lines) do
		if Usable(line) and Unmet(line) then
			answer = true
			break
		end
	end
	blocked[id] = answer
	return answer
end

-- The diet of the pet that is out, in one text, or false.
local function Diet()
	if pet.diet ~= nil then
		return pet.diet
	end
	pet.diet, pet.foods, pet.eats = false, nil, {}
	if type(UnitExists) ~= "function" then
		return false
	end
	local ok, out = pcall(UnitExists, "pet")
	local call = Call("C_PetInfo", "GetPetFoodTypes")
	if not ok or ns.IsSecret(out) or not out or call == nil then
		return false
	end
	local okTypes, types = pcall(call)
	if not okTypes or not Usable(types) then
		return false
	end
	local foods = {}
	for _, food in ipairs(types) do
		if not ns.IsSecret(food) and type(food) == "string" and food ~= "" then
			foods[#foods + 1] = food
		end
	end
	if #foods > 0 then
		pet.diet, pet.foods = table.concat(foods, ","), foods
	end
	return pet.diet
end

-- True when the pet that is out eats the item.
local function Eats(id)
	if not Diet() then
		return false
	end
	local known = pet.eats[id]
	if known ~= nil then
		return known
	end
	local call = Call("C_PetInfo", "CanPetEatItem")
	if call == nil then
		return false
	end
	local ok, answer = pcall(call, id)
	if not ok or ns.IsSecret(answer) then
		return false
	end
	pet.eats[id] = answer == true
	return pet.eats[id]
end

-- Drawing ---------------------------------------------------------------------------------------

-- The icon of Feed Pet, read once, or nil.
local function FoodIcon()
	if foodIcon == nil then
		foodIcon = false
		local call = Call("C_Spell", "GetSpellTexture")
		if call then
			local ok, file = pcall(call, FEED_PET)
			if ok and (ns.Finite(file) or (not ns.IsSecret(file) and type(file) == "string" and file ~= "")) then
				foodIcon = file
			end
		end
	end
	return foodIcon or nil
end

-- Each of these shows or hides one mark of a slot, and makes it the first time it shows. False when a fight keeps it from being made now.
local function Bind(button, rec, want)
	local text = rec.bind
	rec.bindOn = nil
	if not want then
		if text then
			pcall(text.Hide, text)
		end
		return true
	end
	if text == nil then
		if Blocked(button) then
			return false
		end
		text = ns.OwnText(button, "OVERLAY", BIND_FONT)
		if text == nil then
			Refuse("bind", "a text")
			return true
		end
		pcall(text.SetPoint, text, "TOPLEFT", button, "TOPLEFT", 2, -2)
		pcall(text.SetTextColor, text, BIND_COLOUR[1], BIND_COLOUR[2], BIND_COLOUR[3], 1)
		pcall(text.SetText, text, BIND_WORD)
		rec.bind = text
	end
	pcall(text.Show, text)
	rec.bindOn = true
	return true
end

-- A texture of this addon's own on the slot, or nil when the game refuses it.
local function Made(button, kind, layer, sublevel)
	local ok, made = pcall(button.CreateTexture, button, nil, layer, nil, sublevel)
	if not ok or not Usable(made) then
		Refuse(kind, "a texture")
		return nil
	end
	ns.Own[made] = true
	return made
end

local function Tint(button, rec, want)
	local texture = rec.tint
	rec.tintOn = nil
	if not want then
		if texture then
			pcall(texture.Hide, texture)
		end
		return true
	end
	if texture == nil then
		if Blocked(button) then
			return false
		end
		texture = Made(button, "tint", "BORDER", 7)
		if texture == nil then
			return true
		end
		pcall(texture.SetColorTexture, texture, TINT[1], TINT[2], TINT[3], 1)
		pcall(texture.SetBlendMode, texture, "MOD")
		pcall(texture.SetAllPoints, texture, Held(button, "icon") or Held(button, "Icon") or button)
		rec.tint = texture
	end
	pcall(texture.Show, texture)
	rec.tintOn = true
	return true
end

local function Food(button, rec, want)
	local texture = rec.food
	rec.foodOn = nil
	if not want then
		if texture then
			pcall(texture.Hide, texture)
		end
		return true
	end
	if texture == nil then
		if Blocked(button) then
			return false
		end
		texture = Made(button, "food", "OVERLAY", 2)
		if texture == nil then
			return true
		end
		local icon = FoodIcon()
		if not (icon and pcall(texture.SetTexture, texture, icon) and pcall(texture.SetTexCoord, texture, 0.08, 0.92, 0.08, 0.92)) then
			pcall(texture.SetColorTexture, texture, FOOD_COLOUR[1], FOOD_COLOUR[2], FOOD_COLOUR[3], 1)
		end
		pcall(texture.SetSize, texture, FOOD_SIZE, FOOD_SIZE)
		pcall(texture.SetPoint, texture, "BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
		rec.food = texture
	end
	pcall(texture.Show, texture)
	rec.foodOn = true
	return true
end

-- Takes up the slot again once the fight that kept a mark from being made is over.
local function Later(button, rec)
	if not rec.queued then
		rec.queued = true
		ns.OutOfCombat(function()
			rec.queued = nil
			ns.Items.Redress(button)
		end)
	end
end

-- True while one of the rows wants a mark the client can make.
function ItemMarks.Wanted()
	return Wanted("bind") or Wanted("tint") or Wanted("food")
end

-- True when the slot has to be read: a mark is wanted, or the slot has marks that may need hiding.
function ItemMarks.Needs(button)
	return marks[button] ~= nil or ItemMarks.Wanted()
end

-- Shows the marks a bag or bank slot wants and hides the others. live is false while the item details of Items.lua are off or stopped; info, bag
-- and slot are what Items.lua read for the slot.
function ItemMarks.Dress(button, live, info, bag, slot)
	local rec = marks[button]
	local wantBind = live and Wanted("bind")
	local wantTint = live and Wanted("tint")
	local wantFood = live and Wanted("food")
	if rec == nil then
		if not (wantBind or wantTint or wantFood) then
			return
		end
		rec = {}
		marks[button] = rec
	end
	local id = Usable(info) and info.itemID or nil
	if not ns.Finite(id) then
		id = nil
	end
	local link = id and info.hyperlink or nil
	if ns.IsSecret(link) or type(link) ~= "string" then
		link = nil
	end
	local placed = ns.Finite(bag) and ns.Finite(slot)
	local bind = wantBind and id ~= nil and Unbound(id, link, info) or false
	local tint = wantTint and id ~= nil and placed and Unusable(id, link, bag, slot) == true or false
	local food = wantFood and id ~= nil and Eats(id) or false
	local later = not Bind(button, rec, bind)
	later = not Tint(button, rec, tint) or later
	later = not Food(button, rec, food) or later
	if later then
		Later(button, rec)
	end
end

-- Called when the windows module applies its settings, before the slots are dressed: the module heard no event while it was off, so the answers a
-- change of the character can turn are read again, and so is the pet.
function ItemMarks.Apply()
	for id, answer in pairs(blocked) do
		if answer == true then
			blocked[id] = nil
		end
	end
	pet.diet = nil
end

-- The part stopped: every mark is hidden.
function ItemMarks.Release()
	for _, rec in pairs(marks) do
		for _, kind in ipairs(KINDS) do
			local region = rec[kind]
			if region then
				pcall(region.Hide, region)
			end
			rec[kind .. "On"] = nil
		end
	end
end

-- Answers that went old ----------------------------------------------------------------------

-- Dresses the shown bag and bank slots again on the next frame, once for a run of changes.
local function Redraw()
	if redrawQueued then
		return
	end
	redrawQueued = true
	Soon(function()
		redrawQueued = false
		ns.Items.Redraw()
	end)
end

-- Drops the answers of Tint items you cannot use: every one, or with only "unusable" those that said an item cannot be used.
local function Forget(which)
	local dropped = false
	for id, answer in pairs(blocked) do
		if which ~= "unusable" or answer == true then
			blocked[id] = nil
			dropped = true
		end
	end
	if dropped and Wanted("tint") then
		Redraw()
	end
end

local function ForgetUnusable()
	ns.EachPart(KEY, PART, Forget, "unusable")
end

local function ForgetAll()
	ns.EachPart(KEY, PART, Forget, "all")
end

ns.AddEvent(KEY, "UNIT_PET", function()
	pet.diet = nil
	if Wanted("food") then
		Redraw()
	end
end, function(unit)
	return not ns.IsSecret(unit) and unit == "player"
end)
ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", function()
	pet.diet = nil
end)
-- A pet that gains a level may take food it left before.
ns.AddEvent(KEY, "UNIT_LEVEL", function()
	pet.diet = nil
	if Wanted("food") then
		Redraw()
	end
end, function(unit)
	return not ns.IsSecret(unit) and unit == "pet"
end)
ns.AddEvent(KEY, "PLAYER_LEVEL_UP", function()
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(LEVEL_WAIT, ForgetUnusable)
	else
		ForgetUnusable()
	end
end)
for _, event in ipairs({ "SKILL_LINES_CHANGED", "UPDATE_FACTION" }) do
	ns.AddEvent(KEY, event, ForgetUnusable)
end
for _, event in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "NEW_RECIPE_LEARNED", "PLAYER_PVP_RANK_CHANGED" }) do
	ns.AddEvent(KEY, event, ForgetAll)
end
ns.AddEvent(KEY, "GET_ITEM_INFO_RECEIVED", function(id, success)
	waiting[id] = nil
	if not ns.IsSecret(success) and success == true and ItemMarks.Wanted() then
		Redraw()
	end
end, function(id)
	return ns.Finite(id) and waiting[id] == true
end)

-- /flatui status: how many slots each mark shows, the diet of the pet, and the marks the client cannot make. A stopped part has its note.
ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return {}
	end
	local counts = { bind = 0, tint = 0, food = 0 }
	for _, rec in pairs(marks) do
		for _, kind in ipairs(KINDS) do
			if rec[kind .. "On"] then
				counts[kind] = counts[kind] + 1
			end
		end
	end
	local said, missing = {}, {}
	for _, kind in ipairs(KINDS) do
		if ns.Get(ROWS[kind]) == true and not refused[kind] then
			if not Can(kind) then
				missing[#missing + 1] = MISSING[kind]
			elseif kind ~= "food" then
				said[#said + 1] = COUNTS[kind]:format(counts[kind])
			elseif Diet() then
				said[#said + 1] = ("%s (%s)"):format(COUNTS.food:format(counts.food), table.concat(pet.foods, ", "))
			end
		end
	end
	local lines = {}
	if #said > 0 then
		lines[#lines + 1] = ("Bag marks: %s."):format(table.concat(said, ", "))
	end
	if #missing > 0 then
		local list = table.concat(missing, ", ", 1, #missing - 1)
		list = #missing > 1 and (list .. " or " .. missing[#missing]) or missing[1]
		lines[#lines + 1] = ("Bag marks: the game has no %s here, so those marks show nothing."):format(list)
	end
	return lines
end)
