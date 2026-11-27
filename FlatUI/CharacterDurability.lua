local _, ns = ...

local KEY, PART, ROW = "windows", "durability", "windows.durability"
local FIRST_SLOT, LAST_SLOT = 1, 19
local WHITE, YELLOW, RED = { 1, 1, 1 }, { 1, 0.82, 0.18 }, { 0.93, 0.07, 0.07 }
local HIGH, LOW = 80, 50
local WORN = 20
local FONT = "GameFontHighlightSmall"
local GAP, FALLBACK_X, FALLBACK_Y = -12, 24, 40
local WIDTH, HEIGHT = 120, 16
local SLOT_WORDS = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "WRISTSLOT",
	"HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT",
	"TABARDSLOT" }
local DIM = { 0.66, 0.68, 0.62 }

local CharacterDurability = {}
ns.CharacterDurability = CharacterDurability

local state = { frame = nil, text = nil, broken = false, waiting = false }

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

local function Percent()
	local call = _G.GetInventoryItemDurability
	if type(call) ~= "function" then
		return nil
	end
	local now, most = 0, 0
	for slot = FIRST_SLOT, LAST_SLOT do
		local ok, current, maximum = pcall(call, slot)
		if not ok or ns.IsSecret(current) or ns.IsSecret(maximum) then
			return nil
		end
		if ns.Finite(current) and ns.Finite(maximum) and maximum > 0 then
			now = now + math.max(0, math.min(current, maximum))
			most = most + maximum
		end
	end
	if most == 0 then
		return 100
	end
	return math.floor(now / most * 100 + 0.5)
end

local function Colour(percent)
	if percent > HIGH then
		return WHITE
	elseif percent > LOW then
		return YELLOW
	end
	return RED
end

local function Words(percent)
	local word = _G.DURABILITY
	if ns.IsSecret(word) or type(word) ~= "string" or word == "" then
		word = "Durability"
	end
	return ("%s %d%%"):format(word, percent)
end

local function Items()
	local call = _G.GetInventoryItemDurability
	if type(call) ~= "function" then
		return nil
	end
	local items = {}
	for slot = FIRST_SLOT, LAST_SLOT do
		local ok, current, maximum = pcall(call, slot)
		if not ok or ns.IsSecret(current) or ns.IsSecret(maximum) then
			return nil
		end
		if ns.Finite(current) and ns.Finite(maximum) and maximum > 0 then
			items[#items + 1] = { slot = slot, percent = math.max(0, math.min(current, maximum)) / maximum * 100 }
		end
	end
	table.sort(items, function(a, b)
		if a.percent ~= b.percent then
			return a.percent < b.percent
		end
		return a.slot < b.slot
	end)
	return items
end

local function NoWear()
	local rules, enum = _G.C_GameRules, _G.Enum
	local kinds = Usable(enum) and enum.GameRule or nil
	local rule = Usable(kinds) and kinds.RepairArmorDisabled or nil
	if not Usable(rules) or rule == nil or ns.IsSecret(rule) or type(rules.IsGameRuleActive) ~= "function" then
		return false
	end
	local ok, on = pcall(rules.IsGameRuleActive, rule)
	return ok and not ns.IsSecret(on) and on == true
end

local function LineColour(percent, items)
	local lowest = items and items[1] and items[1].percent or nil
	if lowest ~= nil and lowest <= 0 then
		return RED
	end
	local colour = Colour(percent)
	if lowest ~= nil and lowest <= WORN and colour == WHITE then
		return YELLOW
	end
	return colour
end

local function Update()
	local text, frame = state.text, state.frame
	if text == nil then
		return
	end
	local percent = Wanted() and not NoWear() and Percent() or nil
	if percent == nil then
		pcall(text.Hide, text)
		if frame then
			pcall(frame.EnableMouse, frame, false)
		end
		return
	end
	local colour = LineColour(percent, Items())
	pcall(text.SetTextColor, text, colour[1], colour[2], colour[3], 1)
	pcall(text.SetText, text, Words(percent))
	pcall(text.Show, text)
	if frame then
		pcall(frame.EnableMouse, frame, true)
		pcall(frame.SetMouseClickEnabled, frame, false)
	end
	local ok, width = pcall(text.GetStringWidth, text)
	if ok and ns.Finite(width) and width > 0 and frame then
		pcall(frame.SetWidth, frame, math.ceil(width))
	end
end

local function ItemName(slot)
	local ok, link = pcall(_G.GetInventoryItemLink, "player", slot)
	if ok and not ns.IsSecret(link) and type(link) == "string" and link ~= "" then
		local name = link:match("|h%[(.-)%]|h")
		if not name or name == "" then
			return link
		end
		local colour = link:match("^(|c%x%x%x%x%x%x%x%x)") or link:match("^(|cn[^:|]*:)") or ""
		local okIcon, icon = pcall(_G.GetInventoryItemTexture, "player", slot)
		local mark = ""
		if okIcon and not ns.IsSecret(icon) and (type(icon) == "number" or (type(icon) == "string" and icon ~= "")) then
			mark = ("|T%s:14|t "):format(tostring(icon))
		end
		return mark .. colour .. name .. (colour ~= "" and "|r" or "")
	end
	local word = _G[SLOT_WORDS[slot] or ""]
	return not ns.IsSecret(word) and type(word) == "string" and word ~= "" and word or ("Slot %d"):format(slot)
end

local function RepairCost(items)
	local info = _G.C_TooltipInfo
	local call = type(info) == "table" and not ns.IsSecret(info) and info.GetInventoryItem or nil
	if type(call) ~= "function" then
		return nil
	end
	local total = nil
	for _, item in ipairs(items) do
		if item.percent < 100 then
			local ok, data = pcall(call, "player", item.slot)
			local cost = ok and type(data) == "table" and not ns.IsSecret(data) and data.repairCost or nil
			if ns.Finite(cost) and cost > 0 then
				total = (total or 0) + cost
			end
		end
	end
	return total
end

local function Money(copper)
	copper = math.floor(copper)
	local errands = ns.Errands
	if type(errands) == "table" and type(errands.Money) == "function" then
		local ok, text = pcall(errands.Money, copper)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end
	return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function Tooltip()
	local tip = _G.GameTooltip
	if not Usable(tip) or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Untip()
	local tip, frame = Tooltip(), state.frame
	if not (tip and frame) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, frame)
	if ok and not ns.IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

local function Say()
	local tip, frame = Tooltip(), state.frame
	local items = Wanted() and not NoWear() and Items() or nil
	if InCombatLockdown() or not (tip and frame and items) or not pcall(tip.SetOwner, tip, frame, "ANCHOR_RIGHT") then
		return
	end
	local word = _G.DURABILITY
	if ns.IsSecret(word) or type(word) ~= "string" or word == "" then
		word = "Durability"
	end
	pcall(tip.AddLine, tip, word, 1, 1, 1)
	local broken = 0
	for _, item in ipairs(items) do
		broken = broken + (item.percent <= 0 and 1 or 0)
	end
	if broken > 0 then
		pcall(tip.AddLine, tip, ("%d %s broken: no stats until repaired"):format(broken, broken == 1 and "item" or "items"), RED[1], RED[2], RED[3],
			true)
	end
	if #items == 0 then
		pcall(tip.AddLine, tip, "Nothing you wear wears out.", DIM[1], DIM[2], DIM[3], true)
	else
		for _, item in ipairs(items) do
			local colour = Colour(item.percent)
			pcall(tip.AddDoubleLine, tip, ItemName(item.slot), ("%d%%"):format(math.floor(item.percent + 0.5)), 1, 1, 1,
				colour[1], colour[2], colour[3])
		end
		local percent = Percent()
		if percent then
			local colour = Colour(percent)
			pcall(tip.AddDoubleLine, tip, "All items", ("%d%%"):format(percent), DIM[1], DIM[2], DIM[3], colour[1], colour[2], colour[3])
		end
		local cost = RepairCost(items)
		if cost then
			pcall(tip.AddDoubleLine, tip, "Repair about", Money(cost), DIM[1], DIM[2], DIM[3], 1, 1, 1)
		end
	end
	pcall(tip.Show, tip)
end

local function Refuse(text)
	state.broken = true
	ns.Note(KEY, text)
end

local function Make(page)
	local ok, frame = pcall(CreateFrame, "Frame", nil, page)
	if not ok or not Usable(frame) then
		Refuse("Windows: Show durability stopped, the game refused a frame on the Character window.")
		return false
	end
	ns.Own[frame] = true
	local text = ns.OwnText(frame, "OVERLAY", FONT)
	if text == nil then
		pcall(frame.Hide, frame)
		Refuse("Windows: Show durability stopped, the game refused a text on the Character window.")
		return false
	end
	state.frame, state.text = frame, text
	pcall(frame.SetSize, frame, WIDTH, HEIGHT)
	local wrist = _G.CharacterWristSlot
	if not (Usable(wrist) and not ns.Forbidden(wrist) and pcall(frame.SetPoint, frame, "TOPLEFT", wrist, "BOTTOMLEFT", 0, GAP)) then
		pcall(frame.SetPoint, frame, "BOTTOMLEFT", page, "BOTTOMLEFT", FALLBACK_X, FALLBACK_Y)
	end
	pcall(text.SetPoint, text, "LEFT", frame, "LEFT", 0, 0)
	pcall(text.SetWordWrap, text, false)
	pcall(frame.EnableMouse, frame, true)
	pcall(frame.SetMouseClickEnabled, frame, false)
	pcall(frame.SetScript, frame, "OnEnter", function()
		ns.EachPart(KEY, PART, Say)
	end)
	pcall(frame.SetScript, frame, "OnLeave", Untip)
	pcall(frame.SetScript, frame, "OnHide", Untip)
	return true
end

local function Applied()
	if not Wanted() then
		if state.frame then
			pcall(state.frame.Hide, state.frame)
		end
		return
	end
	if state.frame == nil then
		local page = _G.PaperDollItemsFrame
		if state.broken or type(_G.GetInventoryItemDurability) ~= "function" or not Usable(page) or ns.Forbidden(page) then
			return
		end
		if Blocked(page) then
			if not state.waiting then
				state.waiting = true
				ns.OutOfCombat(function()
					state.waiting = false
					CharacterDurability.Apply()
				end)
			end
			return
		end
		if not Make(page) then
			return
		end
	end
	pcall(state.frame.Show, state.frame)
	Update()
end

function CharacterDurability.Apply()
	if ns.PartStopped(KEY, PART) and state.frame then
		pcall(state.frame.Hide, state.frame)
	end
	ns.EachPart(KEY, PART, Applied)
end

local function Changed()
	if state.frame and Wanted() then
		ns.EachPart(KEY, PART, Update)
	end
end

ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", Changed)
ns.AddEvent(KEY, "UPDATE_INVENTORY_DURABILITY", Changed)
ns.AddEvent(KEY, "UPDATE_INVENTORY_ALERTS", Changed)
ns.AddEvent(KEY, "PLAYER_EQUIPMENT_CHANGED", Changed)
