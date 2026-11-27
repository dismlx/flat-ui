local _, ns = ...

local KEY = "windows"
local PART = "bag marks"
local KINDS = { "bind", "tint", "food" }
local ROWS = { bind = "windows.boeMark", tint = "windows.unusableTint", food = "windows.petFood" }
local BIND_ON_EQUIP = 2
local USAGE, EQUIP_SLOT, NESTED, LEARN = 43, 21, 19, 38
local RECIPE = 9
local RED_LEAST, OTHER_MOST = 0.9, 0.25
local BIND_WORD, BIND_FONT, BIND_COLOUR = "BoE", "NumberFontNormalSmall", { 0.38, 0.82, 1 }
local TINT = { 1, 0.18, 0.18 }
local FEED_PET, FOOD_SIZE, FOOD_COLOUR = 6991, 14, { 0.45, 0.85, 0.3 }
local LEVEL_WAIT = 2
local LABELS = { bind = "Mark bind on equip items", tint = "Tint items you cannot use", food = "Mark food your pet eats" }
local COUNTS = { bind = "%d bind on equip", tint = "%d you cannot use", food = "%d your pet eats" }
local MISSING = { bind = "binding of items", tint = "item tooltips", food = "diet of a pet" }

local marks = setmetatable({}, { __mode = "k" })
local binds, blocked, waiting, clear = {}, {}, {}, {}
local pet = { diet = nil, foods = nil, eats = {} }
local refused = {}
local foodIcon
local redrawQueued = false
local skillLines
local watchers, heard = {}, {}

local ItemMarks = { PART = PART }
ns.ItemMarks = ItemMarks

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

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

local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

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

local function EnumValue(group, name, fallback)
	local enum = _G.Enum
	local values = type(enum) == "table" and not ns.IsSecret(enum) and enum[group] or nil
	local value = type(values) == "table" and not ns.IsSecret(values) and values[name] or nil
	if ns.Finite(value) then
		return value
	end
	return fallback
end

local function Soon(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

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

local function NameAndBinding(call, item)
	local name, _, _, _, _, _, _, _, _, _, _, _, _, bind = call(item)
	return name, bind
end

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

local function Nested(lines)
	local nested = EnumValue("TooltipDataLineType", "NestedBlock", NESTED)
	local learn = EnumValue("TooltipDataLineType", "ItemSpellTriggerLearn", LEARN)
	local first, last, count = nil, nil, 0
	for index, line in ipairs(lines) do
		count = index
		local kind = Usable(line) and line.type or nil
		if ns.Finite(kind) then
			if first == nil then
				if kind == nested then
					first = index
				end
			elseif kind == learn then
				last = index - 1
			end
		end
	end
	if first == nil then
		return nil
	end
	return first, last or count, last ~= nil
end

local function Unusable(id, link, bag, slot)
	local known = blocked[id]
	if known ~= nil then
		return known
	end
	if Binding(id, link) == nil then
		return nil
	end
	local placed = ns.Finite(bag) and ns.Finite(slot)
	local call = Call("C_TooltipInfo", placed and "GetBagItem" or "GetHyperlink")
	if call == nil or not (placed or (not ns.IsSecret(link) and type(link) == "string")) then
		return nil
	end
	local ok, data
	if placed then
		ok, data = pcall(call, bag, slot)
	else
		ok, data = pcall(call, link)
	end
	if not ok or not Usable(data) then
		return nil
	end
	local of, lines = data.id, data.lines
	if (of ~= nil and not (ns.Finite(of) and of == id)) or not Usable(lines) then
		return nil
	end
	local answer = false
	local first, last, closed = Nested(lines)
	for index, line in ipairs(lines) do
		if not (first and index >= first and index <= last) and Usable(line) and Unmet(line) then
			answer = true
			break
		end
	end
	blocked[id] = answer
	clear[id] = first == nil or closed == true
	return answer
end

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

local function FewerSkills()
	local call = Call("C_SkillInfo", "GetNumSkillLines")
	if call == nil then
		return false
	end
	local ok, count = pcall(call)
	if not ok or not ns.Finite(count) then
		return false
	end
	local fewer = skillLines ~= nil and count < skillLines
	skillLines = count
	return fewer
end

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

local function Later(button, rec)
	if not rec.queued then
		rec.queued = true
		ns.OutOfCombat(function()
			rec.queued = nil
			ns.Items.Redress(button)
		end)
	end
end

function ItemMarks.Wanted()
	return Wanted("bind") or Wanted("tint") or Wanted("food")
end

function ItemMarks.Needs(button)
	return marks[button] ~= nil or ItemMarks.Wanted()
end

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

function ItemMarks.Apply()
	local all = FewerSkills()
	for id, answer in pairs(blocked) do
		if all or answer == true then
			blocked[id] = nil
		end
	end
	pet.diet = nil
end

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

local function Tell()
	for _, fn in ipairs(watchers) do
		pcall(fn)
	end
end

local function Redraw(windowsWants)
	Tell()
	if not windowsWants or redrawQueued then
		return
	end
	redrawQueued = true
	Soon(function()
		redrawQueued = false
		ns.Items.Redraw()
	end)
end

local function Forget(which)
	local dropped = false
	for id, answer in pairs(blocked) do
		if which ~= "unusable" or answer == true then
			blocked[id] = nil
			dropped = true
		end
	end
	if dropped then
		Redraw(Wanted("tint"))
	end
end

local function Listen(key)
	if heard[key] or type(ns.modules[key]) ~= "table" then
		return false
	end
	heard[key] = true
	local function ForgetUnusable()
		ns.EachPart(key, PART, Forget, "unusable")
	end
	local function ForgetAll()
		ns.EachPart(key, PART, Forget, "all")
	end
	ns.AddEvent(key, "UNIT_PET", function()
		pet.diet = nil
		Redraw(Wanted("food"))
	end, function(unit)
		return not ns.IsSecret(unit) and unit == "player"
	end)
	ns.AddEvent(key, "PLAYER_ENTERING_WORLD", function()
		pet.diet = nil
	end)
	ns.AddEvent(key, "UNIT_LEVEL", function()
		pet.diet = nil
		Redraw(Wanted("food"))
	end, function(unit)
		return not ns.IsSecret(unit) and unit == "pet"
	end)
	ns.AddEvent(key, "PLAYER_LEVEL_UP", function()
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(LEVEL_WAIT, ForgetUnusable)
		else
			ForgetUnusable()
		end
	end)
	ns.AddEvent(key, "SKILL_LINES_CHANGED", function()
		if FewerSkills() then
			ForgetAll()
		else
			ForgetUnusable()
		end
	end)
	ns.AddEvent(key, "UPDATE_FACTION", ForgetUnusable)
	for _, event in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "NEW_RECIPE_LEARNED", "PLAYER_PVP_RANK_CHANGED" }) do
		ns.AddEvent(key, event, ForgetAll)
	end
	ns.AddEvent(key, "GET_ITEM_INFO_RECEIVED", function(id, success)
		waiting[id] = nil
		if not ns.IsSecret(success) and success == true then
			Redraw(ItemMarks.Wanted())
		end
	end, function(id)
		return ns.Finite(id) and waiting[id] == true
	end)
	return true
end

Listen(KEY)

local function LinkOf(id, link)
	if not ns.IsSecret(link) and type(link) == "string" and (link:find("|H", 1, true) or link:find("^item:")) then
		return link
	end
	return "item:" .. id
end

function ItemMarks.BoE(id, link, bound)
	if not ns.Finite(id) then
		return false
	end
	return Unbound(id, LinkOf(id, link), { isBound = bound })
end

function ItemMarks.Unusable(id, link, bag, slot)
	if not ns.Finite(id) then
		return nil
	end
	return Unusable(id, LinkOf(id, link), bag, slot)
end

function ItemMarks.Learnable(id, link, bag, slot)
	if not ns.Finite(id) then
		return nil
	end
	local call = Call("C_Item", "GetItemInfoInstant")
	if call == nil then
		return false
	end
	local ok, _, _, _, _, _, class = pcall(call, id)
	if not ok or not ns.Finite(class) then
		return nil
	end
	if class ~= EnumValue("ItemClass", "Recipe", RECIPE) then
		return false
	end
	local answer = Unusable(id, LinkOf(id, link), bag, slot)
	if answer == nil then
		return nil
	end
	return answer == false and clear[id] == true
end

function ItemMarks.Eats(id)
	if not ns.Finite(id) then
		return false
	end
	return Eats(id)
end

function ItemMarks.Watch(fn)
	if type(fn) ~= "function" then
		return false
	end
	for _, known in ipairs(watchers) do
		if known == fn then
			return true
		end
	end
	watchers[#watchers + 1] = fn
	return true
end

function ItemMarks.Hear(key)
	if type(key) ~= "string" then
		return false
	end
	return Listen(key)
end

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return {}
	end
	local counts = { bind = 0, tint = 0, food = 0 }
	for button, rec in pairs(marks) do
		local ok, visible = pcall(button.IsVisible, button)
		if ok and not ns.IsSecret(visible) and visible == true then
			for _, kind in ipairs(KINDS) do
				if rec[kind .. "On"] then
					counts[kind] = counts[kind] + 1
				end
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
		lines[#lines + 1] = ("Bag marks on screen: %s."):format(table.concat(said, ", "))
	end
	if #missing > 0 then
		local list = table.concat(missing, ", ", 1, #missing - 1)
		list = #missing > 1 and (list .. " or " .. missing[#missing]) or missing[1]
		lines[#lines + 1] = ("Bag marks: the game has no %s here, so those marks show nothing."):format(list)
	end
	return lines
end)
