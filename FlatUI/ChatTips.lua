local _, ns = ...

-- More on tooltips, for the Tooltips page of Chat and tooltips: a line naming what a unit targets, the class colour on the line with a player's
-- class, the icon of an item or a spell before its name, the ID of the temporary enchant on a weapon you wear, and Show IDs, the key the ID lines
-- wait for. This file adds to the chat module and has no switch of its own. Chat.lua calls ns.ChatTipLines from its post call of the game's tooltip
-- data (TooltipDataProcessor.AddTooltipPostCall, the one path its lines go through), before its own work so that the Elite and Rare word stays the
-- last line, and its extra lines ask ns.ChatTipIds for the ID lines. The game runs the post calls once it has added its lines and before it shows
-- the tooltip (TooltipDataHandler.lua:283-300), and sets the index of each line in the data as it adds it (TooltipDataHandler.lua:319-336).
-- What is written on a tooltip: the target line with AddLine, once for each build as Chat.lua adds its lines, and with SetText and Show when the
-- target of the unit changes while the mouse stays on it (The target line while the mouse stays on the unit); the colour of the class line with
-- SetTextColor; and with Item and spell icons the text of the first line with SetText: the icon of the item or the spell (C_Item.GetItemIconByID,
-- ItemDocumentation.lua:611-624; C_Spell.GetSpellTexture, SpellDocumentation.lua:595-612) before the name the game wrote, only when the first line of
-- the data is the first line of the tooltip and that line still holds the same text, so a second post call for one build adds none. A text the
-- game withholds is left as it is. The game writes every line again at its next build, so nothing is put back. A tooltip inside another one (the
-- reward of a quest, GameTooltip.xml:88-91) has its icon beside it and gets none. The lines of a tooltip are reached by GetLeftLine
-- (FrameAPITooltipDocumentation.lua:32-46) and its first by TextLeft1, both only read.
-- The target is the unit of the data, found as the game finds it (UnitTokenFromGUID, TooltipUtil.lua:34-42), and "target": You when the game says
-- it is you (UnitIsUnit), else its name (UnitName) in the class colour of a player or the reaction colour of any other unit. A target whose identity
-- the game withholds (C_Secrets.ShouldUnitIdentityBeSecret, SecretPredicateAPIDocumentation.lua:305-319), or a name or an answer it withholds, gives
-- no line. The class line is the line of the player's data that holds the name of the class (UnitClass): the level line when the game marks it
-- (Enum.TooltipDataLineType.UnitLevel), else the last such line other than the name.
-- The enchant: the game must say the item of the tooltip is in a weapon slot of yours (C_Item.GetItemLocation, ItemDocumentation.lua:786-799, read
-- by its field), and the enchant is what it says of that slot (C_PaperDollInfo.GetTemporaryEnchantmentInfo, PaperDollInfoDocumentation.lua:226-241,
-- 491-500). An item in a bag, or a link, has none.
-- Show IDs is read as the tooltip is built. The game builds the tooltips of bag slots, its own action buttons and the slots of the Character window
-- again every 0.2 seconds (UpdateTooltip, GameTooltip.lua:451-463; Mainline/ContainerFrame.lua:1655, ActionButton.lua:1126,
-- Camelot/PaperDollFrame.lua:1972), and OwnPaint.lua sets the tooltip of Flat UI's own action buttons (which have no UpdateTooltip) again when a
-- modifier key goes down or up, so there the IDs come as the key goes down. No tooltip is built again here: that would call a Lua method of GameTooltip.
-- These follow the tooltip of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLTooltip.lua:206-224, 493-534, 895-979,
-- 1118-1133, 1194-1200, 1485-1551). Left out: a choice of icon size (the icon is the height of the title), the realm of a target, and building
-- a tooltip again when the key goes down.

local KEY, PART = "chat", "tooltip lines"
-- The colour of the target line: the grey of the ID and count lines of Chat.lua.
local GREY = { 0.8, 0.8, 0.8 }
-- The inventory slots of the player's weapons: main hand, off hand and ranged (INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_RANGED).
local WEAPONS = { [16] = true, [17] = true, [18] = true }
-- Per tooltip: { data, lines, text } of the target line. lines is the index of the line, so that the post calls of one build add it once: the same
-- data with that line still there is the same build. text is what the line holds while it is kept current ("" while the unit targets nothing), nil
-- once it is not.
local added = setmetatable({}, { __mode = "k" })

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- The first answer of a call of the game, or nil when the call is missing, raises or withholds the answer.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok and not IsSecret(answer) then
		return answer
	end
	return nil
end

-- A function of a namespace of the game, such as C_Item.GetItemIconByID, or nil.
local function Call(space, name)
	if not Plain(space, "table") then
		return nil
	end
	local fn = space[name]
	return type(fn) == "function" and fn or nil
end

-- Whether the data is of a kind of the game's tooltip data, as Chat.lua tells them: "Item", "Spell" or "Unit".
local function IsData(data, name)
	if type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" then
		return false
	end
	local kind = data.type
	return not IsSecret(kind) and kind ~= nil and kind == Enum.TooltipDataType[name]
end

-- A value of Enum.TooltipDataLineType, or nil on a client without it.
local function LineType(name)
	local types = type(Enum) == "table" and Enum.TooltipDataLineType or nil
	local value = type(types) == "table" and types[name] or nil
	return Plain(value, "number") and value or nil
end

-- True while Show IDs lets the ID lines show: Always, or its key is down. A key the game does not say is down counts as up.
local function KeyHeld(choice)
	local down
	if choice == "shift" then
		down = IsShiftKeyDown
	elseif choice == "ctrl" then
		down = IsControlKeyDown
	elseif choice == "alt" then
		down = IsAltKeyDown
	else
		return true
	end
	return Ask(down) == true
end

-- The left text of a line of the tooltip, or nil.
local function LeftLine(tooltip, index)
	if index == 1 then
		local first = tooltip.TextLeft1
		if Plain(first, "table") then
			return first
		end
	end
	local ok, line = pcall(tooltip.GetLeftLine, tooltip, index)
	if ok and Plain(line, "table") then
		return line
	end
	return nil
end

-- "|cffrrggbb" for a colour of three numbers from 0 to 1.
local function Hex(r, g, b)
	local function byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The temporary enchant -------------------------------------------------------------------------------------------------------

-- The ID of the temporary enchant on the weapon of an item tooltip, while the game says you wear it, or nil.
local function EnchantId(data)
	local guid = data.guid
	if not Plain(guid, "string") or guid == "" then
		return nil
	end
	local location = Ask(Call(C_Item, "GetItemLocation"), guid)
	if not Plain(location, "table") then
		return nil
	end
	local okSlot, slot = pcall(function() return location.equipmentSlotIndex end)
	if not okSlot or not Plain(slot, "number") or not WEAPONS[slot] then
		return nil
	end
	local info = Ask(Call(C_PaperDollInfo, "GetTemporaryEnchantmentInfo"), slot)
	if not Plain(info, "table") then
		return nil
	end
	local okId, id = pcall(function() return info.enchantID end)
	if okId and Plain(id, "number") and id > 0 and id == math.floor(id) then
		return id
	end
	return nil
end

-- Asked by the extra lines of Chat.lua for an item or a spell: the ID line while Item and spell IDs is on and Show IDs lets it show, and after it
-- the ID of the temporary enchant of a weapon you wear. lines is the list Chat.lua adds after the game's lines; id is a plain number.
function ns.ChatTipIds(lines, data, item, id)
	if Opt("ids") ~= true or not KeyHeld(Opt("idsWhen")) then
		return
	end
	lines[#lines + 1] = (item and "Item ID: " or "Spell ID: ") .. id
	local enchant = item and Opt("enchantId") == true and EnchantId(data)
	if enchant then
		lines[#lines + 1] = "Temporary enchant ID: " .. enchant
	end
end

-- Units -----------------------------------------------------------------------------------------------------------------------

-- The token of the unit of the data, or nil when there is none or the game withholds it.
local function UnitOf(data)
	local guid = data.guid
	if not Plain(guid, "string") or guid == "" then
		return nil
	end
	local token = Ask(UnitTokenFromGUID, guid)
	return Plain(token, "string") and token ~= "" and token or nil
end

-- True when the game withholds who a unit is, or will not say.
local function Hidden(unit)
	local ask = Call(C_Secrets, "ShouldUnitIdentityBeSecret")
	if not ask then
		return false
	end
	local ok, hidden = pcall(ask, unit)
	return not ok or IsSecret(hidden) or hidden == true
end

-- "Target: " and what the unit targets: You, or the name in the class colour of a player or the reaction colour of any other unit. Nil when it
-- targets nothing or the game withholds who it is.
local function TargetText(unit)
	local target = unit .. "target"
	if Ask(UnitExists, target) ~= true or Hidden(target) then
		return nil
	end
	local name, r, g, b
	if Ask(UnitIsUnit, target, "player") == true then
		name = "You"
		r, g, b = ns.ClassColourOf("player")
	else
		name = Ask(UnitName, target)
		if not Plain(name, "string") or name == "" or (Plain(UNKNOWNOBJECT, "string") and name == UNKNOWNOBJECT) then
			return nil
		end
		if Ask(UnitIsPlayer, target) == true then
			r, g, b = ns.ClassColourOf(target)
		end
		if not r then
			r, g, b = ns.ReactionColour(target)
		end
	end
	if r then
		name = Hex(r, g, b) .. name .. "|r"
	end
	return "Target: " .. name
end

-- The target line while the mouse stays on the unit ----------------------------------------------------------------------------
-- The game builds the tooltip of a unit in the world once, as the mouse comes onto it (WORLD_CURSOR_TOOLTIP_UPDATE, CursorDocumentation.lua:50-59,
-- Mainline/EventImplementation.lua:889-891, GameTooltip.lua:978-1022), and again only for the UpdateTooltip of its owner or a TOOLTIP_DATA_UPDATE,
-- a lookup of its data that has resolved (GameTooltip.lua:451-463, 969-976; TooltipInfoDocumentation.lua:1391-1400): a new target is neither. So
-- while a tooltip holds the target line and its unit is still under the mouse, a frame of the addon's own reads the target again every 0.2
-- seconds, as often as the game builds the tooltip of a unit frame again (TOOLTIP_UPDATE_TIME, SharedConstants.lua:145;
-- Mainline/UnitFrame.lua:396-407). A new target is written on the line with SetText, and Show gives the tooltip the size of the new text as the
-- game does after its own lines (Mainline/UnitFrame.lua:400-402). While the unit targets nothing the line is empty, and the next target it takes
-- is written there. The line is written only while it still holds the text written here: a tooltip that is hidden, has fewer lines or other text
-- there, or whose unit has left the mouse (the game fades it then, GameTooltip.lua:1012-1020) is left alone until a new build adds the line again.
-- A unit with no target at its build gets no line until then.
local KEEP_EVERY = 0.2
local keeper, keepWait = nil, 0

-- Writes the target line of a tooltip again when the target of its unit changed. The record stays current only while this gives it its text back.
local function Keep(tooltip, record)
	local text = record.text
	record.text = nil
	if not text or not ns.Enabled(KEY) or Opt("targetLine") ~= true or ns.Forbidden(tooltip) then
		return
	end
	local okShown, shown = pcall(tooltip.IsShown, tooltip)
	local okCount, count = pcall(tooltip.NumLines, tooltip)
	if not okShown or IsSecret(shown) or shown ~= true or not okCount or not Plain(count, "number") or count < record.lines then
		return
	end
	local line = LeftLine(tooltip, record.lines)
	local okText, now = false, nil
	if line then
		okText, now = pcall(line.GetText, line)
	end
	-- A line emptied here may read back as nil.
	if not okText or IsSecret(now) or (now or "") ~= text then
		return
	end
	local unit = UnitOf(record.data)
	if not unit or Ask(UnitIsUnit, unit, "mouseover") ~= true then
		return
	end
	local new = TargetText(unit) or ""
	if new == text then
		record.text = text
	elseif pcall(line.SetText, line, new) then
		pcall(tooltip.Show, tooltip)
		record.text = new
	end
end

-- Runs every 0.2 seconds while a line is kept current, and stops once none is.
local function KeepAll(frame, elapsed)
	keepWait = keepWait + (Plain(elapsed, "number") and elapsed or 0)
	if keepWait < KEEP_EVERY then
		return
	end
	keepWait = 0
	local kept = false
	for tooltip, record in pairs(added) do
		if record.text ~= nil then
			if ns.IsStopped(KEY) or not ns.EachPart(KEY, PART, Keep, tooltip, record) then
				record.text = nil
			end
			kept = kept or record.text ~= nil
		end
	end
	if not kept then
		frame:Hide()
	end
end

-- Starts the frame that keeps the target lines current.
local function Watch()
	if not keeper and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and Plain(frame, "table") then
			ns.Own[frame] = true
			keeper = frame
			frame:SetScript("OnUpdate", KeepAll)
		end
	end
	if keeper then
		keepWait = 0
		keeper:Show()
	end
end

-- Adds the line once for each build of the tooltip, and keeps it current.
local function AddOnce(tooltip, data, text)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Plain(shown, "number") then
		return
	end
	local record = added[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	if pcall(tooltip.AddLine, tooltip, text, GREY[1], GREY[2], GREY[3]) then
		added[tooltip] = { data = data, lines = shown + 1, text = text }
		Watch()
	end
end

-- The index of the line of a player's data that holds the name of the class: the level line when the game marks it, else the last such line other
-- than the name. Nil when no line does, or the lines cannot be read.
local function ClassIndex(data, className)
	local lines = data.lines
	if not Plain(lines, "table") then
		return nil
	end
	local nameType, levelType = LineType("UnitName"), LineType("UnitLevel")
	local found
	local ok = pcall(function()
		for _, line in ipairs(lines) do
			if Plain(line, "table") then
				local kind, text, index = line.type, line.leftText, line.lineIndex
				if Plain(text, "string") and Plain(index, "number") and not IsSecret(kind) and (nameType == nil or kind ~= nameType)
					and text:find(className, 1, true) then
					found = index
					if levelType ~= nil and kind == levelType then
						return
					end
				end
			end
		end
	end)
	return ok and found or nil
end

-- The line with the class of a player, in the class colour.
local function ClassLine(tooltip, data, unit)
	if Ask(UnitIsPlayer, unit) ~= true then
		return
	end
	local className = Ask(UnitClass, unit)
	if not Plain(className, "string") or className == "" then
		return
	end
	local r, g, b = ns.ClassColourOf(unit)
	local index = r and ClassIndex(data, className)
	local line = index and LeftLine(tooltip, index)
	if line then
		pcall(line.SetTextColor, line, r, g, b)
	end
end

-- Icons -----------------------------------------------------------------------------------------------------------------------

-- The icon of the item or the spell of the data, or nil.
local function IconOf(data, item)
	local id = data.id
	if not Plain(id, "number") then
		return nil
	end
	local icon
	if item then
		icon = Ask(Call(C_Item, "GetItemIconByID"), id)
	else
		icon = Ask(Call(C_Spell, "GetSpellTexture"), id)
	end
	if (Plain(icon, "number") and icon > 0) or (Plain(icon, "string") and icon ~= "") then
		return icon
	end
	return nil
end

-- The icon before the name on the first line, the height of its text.
local function Icon(tooltip, data, item)
	local embedded = tooltip.IsEmbedded
	if IsSecret(embedded) or embedded == true then
		return
	end
	local lines = data.lines
	local first = Plain(lines, "table") and lines[1] or nil
	if not Plain(first, "table") then
		return
	end
	local index, name = first.lineIndex, first.leftText
	if not Plain(index, "number") or index ~= 1 or not Plain(name, "string") or name == "" then
		return
	end
	local icon = IconOf(data, item)
	local line = icon and LeftLine(tooltip, 1)
	if not line then
		return
	end
	-- The first line still holds the name the game wrote from this data, and no icon.
	local ok, text = pcall(line.GetText, line)
	if not ok or not Plain(text, "string") or text ~= name or text:find("|T", 1, true) then
		return
	end
	pcall(line.SetText, line, ("|T%s:0|t %s"):format(icon, text))
end

-- The post call ---------------------------------------------------------------------------------------------------------------

local function Lines(tooltip, data)
	if not Plain(tooltip, "table") or not Plain(data, "table") or ns.Forbidden(tooltip) then
		return
	end
	if IsData(data, "Unit") then
		local unit = (Opt("classLine") == true or Opt("targetLine") == true) and UnitOf(data)
		if not unit then
			return
		end
		if Opt("classLine") == true then
			ClassLine(tooltip, data, unit)
		end
		local text = Opt("targetLine") == true and TargetText(unit)
		if text then
			AddOnce(tooltip, data, text)
		end
	elseif Opt("icons") == true then
		local item = IsData(data, "Item")
		if item or IsData(data, "Spell") then
			Icon(tooltip, data, item)
		end
	end
end

-- Called by the post call of Chat.lua for every build of a tooltip, before its own work. A fault stops this part alone, with a line for /flatui status.
function ns.ChatTipLines(tooltip, data)
	if ns.Enabled(KEY) then
		ns.EachPart(KEY, PART, Lines, tooltip, data)
	end
end

-- The words of the choice a row holds, as the page shows them.
local function Word(path)
	local def, value = ns.Def(path), ns.Get(path)
	for _, choice in ipairs(def and ns.Choices(def) or {}) do
		if choice[1] == value then
			return choice[2]
		end
	end
	return tostring(value)
end

-- The line of /flatui status while Item and spell IDs is on: Always, or the key the IDs wait for.
ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) or Opt("ids") ~= true then
		return {}
	end
	return { "Tooltip IDs: " .. Word(KEY .. ".idsWhen") }
end)
