local _, ns = ...

-- Show durability: the durability of all the gear you wear in one percent, on the character page of the Character window, under the left column
-- of slots (the lowest is the wrist, Blizzard_UIPanels_Game/Camelot/PaperDollFrame.xml:779-818). It is white above 80%, the game's yellow for worn
-- gear above 50% and its red for broken gear at 50% and below (Blizzard_DurabilityFrame/DurabilityFrame.lua:14-16), after the game's word for it.
-- The percent is the sum of what GetInventoryItemDurability gives for each worn slot over the sum of their most, the call the game's own repair
-- checks make (Camelot/PaperDollFrame.lua:1594-1602, Blizzard_FrameXML/Mainline/EquipmentManager.lua:234); a slot without durability counts
-- for nothing, and gear with none at all is 100%. A value the client withholds hides the text. The text is this addon's, on a frame of its own
-- made out of a fight on the item frame of the character page (PaperDollItemsFrame, PaperDollFrame.xml:777), so it shows only on that page. It is
-- read when the settings are applied, at each loading screen and on the events that say the durability or the worn gear changed:
-- UPDATE_INVENTORY_DURABILITY, UPDATE_INVENTORY_ALERTS and PLAYER_EQUIPMENT_CHANGED (PaperDollInfoDocumentation.lua:384-392, 436-446), as the game's
-- own durability figure is (DurabilityFrame.lua:20-29), so it is right whenever the page opens and nothing runs while nothing changes. Nothing of the
-- game's is written, and on a client without the call nothing is made. This follows the durability of EnhanceQoL by Philipp Barth (R41Z0R) on its
-- Character frame, adapted with his permission. Not a module: the windows module calls ns.CharacterDurability.Apply whenever it applies its settings.

local KEY, PART, ROW = "windows", "durability", "windows.durability"
-- The worn slots, head to tabard (INVSLOT_FIRST_EQUIPPED and INVSLOT_LAST_EQUIPPED, Blizzard_FrameXMLBase/Constants.lua:136, 154-155).
local FIRST_SLOT, LAST_SLOT = 1, 19
local WHITE, YELLOW, RED = { 1, 1, 1 }, { 1, 0.82, 0.18 }, { 0.93, 0.07, 0.07 }
local HIGH, LOW = 80, 50
local FONT = "GameFontHighlightSmall"
-- The frame lies this far under the wrist slot, and where the slot is not found, this far from the bottom left of the page, beside the weapons.
local GAP, FALLBACK_X, FALLBACK_Y = -12, 24, 40
local WIDTH, HEIGHT = 120, 16

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

-- Reads the percent and shows it, or hides the text when it cannot be read.
local function Update()
	local text = state.text
	if text == nil then
		return
	end
	local percent = Wanted() and Percent() or nil
	if percent == nil then
		pcall(text.Hide, text)
		return
	end
	local colour = Colour(percent)
	pcall(text.SetTextColor, text, colour[1], colour[2], colour[3], 1)
	pcall(text.SetText, text, Words(percent))
	pcall(text.Show, text)
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
