local _, ns = ...

-- Show durability: the durability of all the gear you wear in one percent, on the character page of the Character window, under the left column
-- of slots (the lowest is the wrist, Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:779-818). It is white above 80%, the game's yellow for worn
-- gear above 50% and its red for broken gear at 50% and below (Blizzard_DurabilityFrame/DurabilityFrame.lua:14-16), after the game's word for it;
-- and since 0.5.35 red while any item is broken (0%, so it gives no stats) and at least yellow while any is at 20% or less, as the minimap's lowest
-- item line colours (MapText.lua), so one broken weapon among whole gear never reads white. Where the game rule RepairArmorDisabled is on (gear
-- does not wear out, C_GameRules.IsGameRuleActive) the line is hidden, as the minimap's and the game's own durability figure are.
-- The percent is the sum of what GetInventoryItemDurability gives for each worn slot over the sum of their most, the call the game's own repair
-- checks make (Camelot/PaperDollFrame.lua:1594-1602, Blizzard_FrameXML/Mainline/EquipmentManager.lua:234); a slot without durability counts
-- for nothing, and gear with none at all is 100%. A value the client withholds hides the text. The text is this addon's, on a frame of its own
-- made out of a fight on the item frame of the character page (PaperDollItemsFrame, PaperDollFrame.xml:777), so it shows only on that page. It is
-- read when the settings are applied, at each loading screen and on the events that say the durability or the worn gear changed:
-- UPDATE_INVENTORY_DURABILITY, UPDATE_INVENTORY_ALERTS and PLAYER_EQUIPMENT_CHANGED (PaperDollInfoDocumentation.lua:384-392, 436-446), as the game's
-- own durability figure is (DurabilityFrame.lua:20-29), so it is right whenever the page opens and nothing runs while nothing changes. Nothing of the
-- game's is written, and on a client without the call nothing is made. The frame is as wide as the words. Pointing at it lists in GameTooltip
-- (SetOwner, AddLine, AddDoubleLine, Show, and Hide only while IsOwned says the frame owns it), never in a fight, as Show thorns does, first a red
-- line with the number of broken items while there is one, then each worn item that wears out, lowest first, its icon (GetInventoryItemTexture)
-- and its name in its quality's colour without brackets (from GetInventoryItemLink) and its percent in white, yellow or red, then All
-- items and, where the worn items' tooltip data gives one (repairCost of C_TooltipInfo.GetInventoryItem, the figure the game's repair tooltip
-- shows, TooltipDataRules.lua:151-156), the sum of their repair costs; clicks go through to the page. This follows the durability of EnhanceQoL by
-- Philipp Barth (R41Z0R) on its Character frame, adapted with his permission. Not a module: the windows module calls ns.CharacterDurability.Apply
-- whenever it applies its settings.

local KEY, PART, ROW = "windows", "durability", "windows.durability"
-- The worn slots, head to tabard (INVSLOT_FIRST_EQUIPPED and INVSLOT_LAST_EQUIPPED, Blizzard_FrameXMLBase/Constants.lua:136, 154-155).
local FIRST_SLOT, LAST_SLOT = 1, 19
local WHITE, YELLOW, RED = { 1, 1, 1 }, { 1, 0.82, 0.18 }, { 0.93, 0.07, 0.07 }
local HIGH, LOW = 80, 50
-- An item at this percent or less turns the line at least yellow, as the minimap's lowest item line does (MapText.lua).
local WORN = 20
local FONT = "GameFontHighlightSmall"
-- The frame lies this far under the wrist slot, and where the slot is not found, this far from the bottom left of the page, beside the weapons.
local GAP, FALLBACK_X, FALLBACK_Y = -12, 24, 40
local WIDTH, HEIGHT = 120, 16
-- The name of each worn slot where its item gives no link (GlobalStrings).
local SLOT_WORDS = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "WRISTSLOT",
	"HANDSSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "BACKSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT",
	"TABARDSLOT" }
local DIM = { 0.66, 0.68, 0.62 }

local CharacterDurability = {}
ns.CharacterDurability = CharacterDurability

-- The frame and its text, made once. broken: the game refused one of them, and nothing is tried again. waiting: the making waits for the end of a
-- fight.
local state = { frame = nil, text = nil, broken = false, waiting = false }

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and not ns.PartStopped(KEY, PART)
end

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

-- True when the game would refuse a frame made on this one now.
local function Blocked(frame)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected == true
end

-- The durability of all worn gear in one percent, rounded, or nil when the client has no call, it raises or it withholds a value.
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

-- The game's word (DURABILITY, GlobalStrings), in English when the client has none, and the percent.
local function Words(percent)
	local word = _G.DURABILITY
	if ns.IsSecret(word) or type(word) ~= "string" or word == "" then
		word = "Durability"
	end
	return ("%s %d%%"):format(word, percent)
end

-- Each worn item that wears out: { slot, percent }, lowest first, or nil when the client has no call or withholds a value.
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

-- True where the game rule that keeps gear from wearing out is on (Enum.GameRule.RepairArmorDisabled, C_GameRules.IsGameRuleActive), as the
-- minimap's durability line reads it (MapText.lua; the game's own durability figure hides there too, DurabilityFrame.lua:51-55). An answer the game
-- withholds or does not give counts as off.
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

-- The colour of the line: red while any item is broken (at 0%, so it gives no stats), at least yellow while any is at WORN% or less, else the
-- colour of the percent of all items, so one broken weapon among whole gear is never white.
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

-- Reads the percent and shows it, or hides the text when it cannot be read or gear does not wear out here; the frame answers the mouse only while
-- the text shows, so no empty spot does. The frame takes the width of the words, so the mouse finds them.
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

-- The tooltip ---------------------------------------------------------------------------------------------------------------------------------

-- The item in a slot: its icon (GetInventoryItemTexture) and its name in its quality's colour without the brackets of a link, else its link as it
-- comes, else the slot's name.
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

-- The sum of the repair costs the worn items' tooltip data gives, or nil when none gives one.
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

-- An amount of copper as the game writes money, with its coins; plain gold, silver and copper where the client has no money string.
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

-- Each item with its percent, All items and the repair cost, and first, while any item is broken, a red line that says how many. Not in a fight.
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

-- Makes the frame and its text on the item frame of the character page. True when they are there.
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
	-- Over the line the mouse lists the items; clicks go through to the page.
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

-- Shows the frame while the row is on, or hides it.
function CharacterDurability.Apply()
	if ns.PartStopped(KEY, PART) and state.frame then
		pcall(state.frame.Hide, state.frame)
	end
	ns.EachPart(KEY, PART, Applied)
end

-- The durability or the gear changed.
local function Changed()
	if state.frame and Wanted() then
		ns.EachPart(KEY, PART, Update)
	end
end

ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", Changed)
ns.AddEvent(KEY, "UPDATE_INVENTORY_DURABILITY", Changed)
ns.AddEvent(KEY, "UPDATE_INVENTORY_ALERTS", Changed)
ns.AddEvent(KEY, "PLAYER_EQUIPMENT_CHANGED", Changed)
