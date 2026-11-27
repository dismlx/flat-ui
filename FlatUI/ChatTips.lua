local _, ns = ...

local KEY, PART = "chat", "tooltip lines"
local GREY = { 0.8, 0.8, 0.8 }
local WEAPONS = { [16] = true, [17] = true, [18] = true }
local added = setmetatable({}, { __mode = "k" })
local byAdded = setmetatable({}, { __mode = "k" })
local casters = setmetatable({}, { __mode = "k" })
local BY_MOST, YOU_RED = 6, { 1, 0.25, 0.25 }
local GUILD_OWN, GUILD_OTHER = { 0.25, 1, 0.25 }, { 0.55, 0.75, 1 }

local IsSecret = ns.IsSecret

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

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

local function Call(space, name)
	if not Plain(space, "table") then
		return nil
	end
	local fn = space[name]
	return type(fn) == "function" and fn or nil
end

local function IsData(data, name)
	if type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" then
		return false
	end
	local kind = data.type
	return not IsSecret(kind) and kind ~= nil and kind == Enum.TooltipDataType[name]
end

local function LineType(name)
	local types = type(Enum) == "table" and Enum.TooltipDataLineType or nil
	local value = type(types) == "table" and types[name] or nil
	return Plain(value, "number") and value or nil
end

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

local function Hex(r, g, b)
	local function byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

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

local function IconNumber(id, item)
	local icon
	if item then
		icon = Ask(Call(C_Item, "GetItemIconByID"), id)
	else
		icon = Ask(Call(C_Spell, "GetSpellTexture"), id)
	end
	if Plain(icon, "number") and icon > 0 and icon == math.floor(icon) then
		return icon
	end
	return nil
end

function ns.ChatTipIds(lines, data, item, id)
	if Opt("ids") ~= true or not KeyHeld(Opt("idsWhen")) then
		return
	end
	lines[#lines + 1] = (item and "Item ID: " or "Spell ID: ") .. id
	local icon = Opt("iconId") == true and IconNumber(id, item)
	if icon then
		lines[#lines + 1] = ("Icon ID: %d"):format(icon)
	end
	local enchant = item and Opt("enchantId") == true and EnchantId(data)
	if enchant then
		lines[#lines + 1] = "Temporary enchant ID: " .. enchant
	end
end

function ns.ChatTipNpcId(lines, data)
	if Opt("ids") ~= true or not KeyHeld(Opt("idsWhen")) then
		return
	end
	local guid = data.guid
	if not Plain(guid, "string") then
		return
	end
	local kind = guid:match("^(%a+)%-")
	local id = tonumber(guid:match("^%a+%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)%-"))
	if (kind == "Creature" or kind == "Vehicle") and id and id > 0 then
		lines[#lines + 1] = ("NPC ID: %d"):format(id)
	end
end

function ns.ChatTipOtherId(lines, data, kind)
	if Opt("ids") ~= true or not KeyHeld(Opt("idsWhen")) then
		return
	end
	local id = data.id
	if not Plain(id, "number") or id <= 0 or id ~= math.floor(id) then
		return
	end
	if kind == "Quest" then
		lines[#lines + 1] = ("Quest ID: %d"):format(id)
	elseif kind == "Currency" then
		lines[#lines + 1] = ("Currency ID: %d"):format(id)
	end
end

local function UnitOf(data)
	local guid = data.guid
	if not Plain(guid, "string") or guid == "" then
		return nil
	end
	local token = Ask(UnitTokenFromGUID, guid)
	return Plain(token, "string") and token ~= "" and token or nil
end

local function Hidden(unit)
	local ask = Call(C_Secrets, "ShouldUnitIdentityBeSecret")
	if not ask then
		return false
	end
	local ok, hidden = pcall(ask, unit)
	return not ok or IsSecret(hidden) or hidden == true
end

local function TargetText(unit)
	local target = unit .. "target"
	if Ask(UnitExists, target) ~= true or Hidden(target) then
		return nil
	end
	local name, r, g, b
	if Ask(UnitIsUnit, target, "player") == true then
		name = "You"
		if Ask(UnitCanAttack, "player", unit) == true then
			r, g, b = YOU_RED[1], YOU_RED[2], YOU_RED[3]
		else
			r, g, b = ns.ClassColourOf("player")
		end
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

local KEEP_EVERY = 0.2
local keeper, keepWait = nil, 0
local KeepBy

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
	for tooltip, record in pairs(byAdded) do
		if record.text ~= nil then
			if ns.IsStopped(KEY) or not ns.EachPart(KEY, PART, KeepBy, tooltip, record) then
				record.text = nil
			end
			kept = kept or record.text ~= nil
		end
	end
	if not kept then
		frame:Hide()
	end
end

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

local function TargetedBy(unit)
	if Hidden(unit) then
		return nil
	end
	local raid = Ask(IsInRaid) == true
	local count = raid and Ask(GetNumGroupMembers) or Ask(GetNumSubgroupMembers)
	if not Plain(count, "number") or count <= 0 then
		return nil
	end
	local names, more = {}, 0
	for index = 1, math.min(count, raid and 40 or 4) do
		local member = (raid and "raid" or "party") .. index
		if Ask(UnitIsUnit, member, "player") ~= true and Ask(UnitIsUnit, member .. "target", unit) == true then
			local name = Ask(UnitName, member)
			if Plain(name, "string") and name ~= "" then
				if #names < BY_MOST then
					local r, g, b = ns.ClassColourOf(member)
					names[#names + 1] = r and (Hex(r, g, b) .. name .. "|r") or name
				else
					more = more + 1
				end
			end
		end
	end
	if #names == 0 then
		return nil, true
	end
	return "Targeted by: " .. table.concat(names, ", ") .. (more > 0 and (" +%d"):format(more) or ""), true
end

local NO_ONE = "Targeted by: no one"

local function AddBy(tooltip, data, text)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Plain(shown, "number") then
		return
	end
	local record = byAdded[tooltip]
	if record and rawequal(record.data, data) and shown >= (record.lines or record.at) then
		return
	end
	if text == nil then
		byAdded[tooltip] = { data = data, at = shown, text = "" }
		Watch()
	elseif pcall(tooltip.AddLine, tooltip, text, GREY[1], GREY[2], GREY[3]) then
		byAdded[tooltip] = { data = data, at = shown, lines = shown + 1, text = text }
		Watch()
	end
end

function KeepBy(tooltip, record)
	local text = record.text
	record.text = nil
	if not text or not ns.Enabled(KEY) or Opt("targetedBy") ~= true or ns.Forbidden(tooltip) then
		return
	end
	local okShown, shown = pcall(tooltip.IsShown, tooltip)
	local okCount, count = pcall(tooltip.NumLines, tooltip)
	if not okShown or IsSecret(shown) or shown ~= true or not okCount or not Plain(count, "number") or count < (record.lines or record.at) then
		return
	end
	local line
	if record.lines then
		line = LeftLine(tooltip, record.lines)
		local okText, now = false, nil
		if line then
			okText, now = pcall(line.GetText, line)
		end
		if not okText or IsSecret(now) or (now or "") ~= text then
			return
		end
	end
	local unit = UnitOf(record.data)
	if not unit or Ask(UnitIsUnit, unit, "mouseover") ~= true then
		return
	end
	local by = TargetedBy(unit)
	local new = by or (line and NO_ONE or "")
	if new == text then
		record.text = text
	elseif line then
		if pcall(line.SetText, line, new) then
			pcall(tooltip.Show, tooltip)
			record.text = new
		end
	elseif pcall(tooltip.AddLine, tooltip, new, GREY[1], GREY[2], GREY[3]) then
		record.lines = count + 1
		pcall(tooltip.Show, tooltip)
		record.text = new
	end
end

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

local function GuildIndex(data, guild)
	local lines = data.lines
	if not Plain(lines, "table") then
		return nil
	end
	local nameType, bracketed = LineType("UnitName"), "<" .. guild .. ">"
	local found, words
	pcall(function()
		for _, line in ipairs(lines) do
			if Plain(line, "table") then
				local kind, text, index = line.type, line.leftText, line.lineIndex
				if Plain(text, "string") and Plain(index, "number") and not IsSecret(kind) and (nameType == nil or kind ~= nameType)
					and (text == guild or text:sub(1, #bracketed) == bracketed) then
					found, words = index, text
					return
				end
			end
		end
	end)
	return found, words
end

local function GuildLine(tooltip, data, unit)
	if Ask(UnitIsPlayer, unit) ~= true or type(GetGuildInfo) ~= "function" then
		return
	end
	local ok, guild, rank = pcall(GetGuildInfo, unit)
	if not ok or not Plain(guild, "string") or guild == "" then
		return
	end
	local index, words = GuildIndex(data, guild)
	local line = index and LeftLine(tooltip, index)
	if not line then
		return
	end
	local colour = Ask(GetGuildInfo, "player") == guild and GUILD_OWN or GUILD_OTHER
	pcall(line.SetTextColor, line, colour[1], colour[2], colour[3])
	if Plain(rank, "string") and rank ~= "" then
		local okText, text = pcall(line.GetText, line)
		if okText and Plain(text, "string") and text == words then
			pcall(line.SetText, line, text .. "  " .. rank)
		end
	end
end

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
	local ok, text = pcall(line.GetText, line)
	if not ok or not Plain(text, "string") or text ~= name or text:find("|T", 1, true) then
		return
	end
	pcall(line.SetText, line, ("|T%s:0|t %s"):format(icon, text))
end

local AURA_GETTERS = {
	GetUnitAura = "HELPFUL", GetUnitBuff = "HELPFUL", GetUnitDebuff = "HARMFUL",
	GetUnitAuraByAuraInstanceID = true, GetUnitBuffByAuraInstanceID = true, GetUnitDebuffByAuraInstanceID = true,
}

local function Field(t, key)
	if not Plain(t, "table") then
		return nil
	end
	local ok, value = pcall(function() return t[key] end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function AuraOf(tooltip, data)
	local info = Field(tooltip, "processingInfo")
	if not rawequal(Field(info, "tooltipData"), data) then
		local first = Field(Field(tooltip, "infoList"), 1)
		if rawequal(Field(first, "tooltipData"), data) or info == nil then
			info = first
		end
	end
	local getter, args = Field(info, "getterName"), Field(info, "getterArgs")
	local base = Plain(getter, "string") and AURA_GETTERS[getter]
	local unit, which = Field(args, 1), Field(args, 2)
	if not base or not Plain(unit, "string") or unit == "" or not Plain(which, "number") then
		return nil
	end
	if base == true then
		return Ask(Call(C_UnitAuras, "GetAuraDataByAuraInstanceID"), unit, which)
	end
	local filter = Field(args, 3)
	if not Plain(filter, "string") or filter == "" then
		filter = base
	elseif getter ~= "GetUnitAura" and not filter:find(base, 1, true) then
		filter = base .. "|" .. filter
	end
	return Ask(Call(C_UnitAuras, "GetAuraDataByIndex"), unit, which, filter)
end

local function CasterName(src)
	local function Known(unit)
		local said = Ask(UnitName, unit)
		if not Plain(said, "string") or said == "" or (Plain(UNKNOWNOBJECT, "string") and said == UNKNOWNOBJECT) then
			return nil
		end
		return said
	end
	local function Coloured(unit, text)
		local cr, cg, cb = ns.ClassColourOf(unit)
		if Plain(cr, "number") and Plain(cg, "number") and Plain(cb, "number") then
			return Hex(cr, cg, cb) .. text .. "|r"
		end
		return text
	end
	local name = Known(src)
	local r, g, b
	if Ask(UnitIsUnit, src, "player") == true then
		name = "You"
		r, g, b = ns.ClassColourOf("player")
	elseif Ask(UnitIsUnit, src, "pet") == true then
		local mine = Coloured("player", "your pet")
		return name and (mine .. " (" .. name .. ")") or mine
	elseif not name then
		return nil
	else
		local group, number = src:match("^(party)pet(%d+)$")
		if not group then
			group, number = src:match("^(raid)pet(%d+)$")
		end
		local owner = group and group .. number
		local ownerName = owner and not Hidden(owner) and Known(owner)
		if ownerName then
			return Coloured(owner, ownerName) .. "'s pet (" .. name .. ")"
		elseif Ask(UnitIsPlayer, src) == true then
			r, g, b = ns.ClassColourOf(src)
		end
	end
	if not r and name ~= "You" then
		r, g, b = ns.ReactionColour(src)
	end
	if r and not (IsSecret(r) or IsSecret(g) or IsSecret(b)) then
		return Hex(r, g, b) .. name .. "|r"
	end
	return name
end

local function CasterLine(tooltip, data)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Plain(shown, "number") then
		return
	end
	local record = casters[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local id = data.id
	local aura = Plain(id, "number") and AuraOf(tooltip, data)
	if not Plain(aura, "table") then
		return
	end
	local spell, src = Field(aura, "spellId"), Field(aura, "sourceUnit")
	if not Plain(spell, "number") or spell ~= id or not Plain(src, "string") or src == "" or Hidden(src) then
		return
	end
	local name = CasterName(src)
	if name and pcall(tooltip.AddLine, tooltip, "Cast by " .. name, GREY[1], GREY[2], GREY[3]) then
		casters[tooltip] = { data = data, lines = shown + 1 }
	end
end

local function Lines(tooltip, data)
	if not Plain(tooltip, "table") or not Plain(data, "table") or ns.Forbidden(tooltip) then
		return
	end
	local by = byAdded[tooltip]
	if by and not rawequal(by.data, data) then
		by.text = nil
	end
	if IsData(data, "Unit") then
		local unit = (Opt("classLine") == true or Opt("guildLine") == true or Opt("targetLine") == true or Opt("targetedBy") == true)
			and UnitOf(data)
		if not unit then
			return
		end
		if Opt("classLine") == true then
			ClassLine(tooltip, data, unit)
		end
		if Opt("guildLine") == true then
			GuildLine(tooltip, data, unit)
		end
		local text = Opt("targetLine") == true and TargetText(unit)
		if text then
			AddOnce(tooltip, data, text)
		end
		if Opt("targetedBy") == true then
			local who, grouped = TargetedBy(unit)
			if grouped then
				AddBy(tooltip, data, who)
			end
		end
	else
		local item, aura = IsData(data, "Item"), IsData(data, "UnitAura")
		if Opt("icons") == true and (item or aura or IsData(data, "Spell")) then
			Icon(tooltip, data, item)
		end
		if aura and Opt("auraCaster") == true then
			CasterLine(tooltip, data)
		end
	end
end

function ns.ChatTipLines(tooltip, data)
	if ns.Enabled(KEY) then
		ns.EachPart(KEY, PART, Lines, tooltip, data)
	end
end

local function Word(path)
	local def, value = ns.Def(path), ns.Get(path)
	for _, choice in ipairs(def and ns.Choices(def) or {}) do
		if choice[1] == value then
			return choice[2]
		end
	end
	return tostring(value)
end

ns.AddStatus(KEY, function()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) or Opt("ids") ~= true then
		return {}
	end
	return { "Tooltip IDs: " .. Word(KEY .. ".idsWhen") }
end)
