local _, ns = ...

local KEY, PART = "chat", "hit table lines"
local IsSecret, Finite = ns.IsSecret, ns.Finite

local HT = {
	ROW = "hud.hitTableTip", LINES = "hud.hitTableLines", SPECIAL = "hud.hitTableSpecial", FACING = "hud.hitTableFacing", RULES = "hud.hitTableRules",
	DETAIL = "chat.tipDetail",
	SIZE = "hud.hitTableTipSize", FONT_STRING = "GameTooltipText%s%d",
	CTRL = "hud.hitTableTipCtrl", HINT = "hud.hitTableTipHint", HINT_TEXT = "Ctrl: your hit table against it",
	CTRL_KEYS = { LCTRL = true, RCTRL = true },
	UNIT = 2,
	KINDS = { melee = true, ranged = true, spell = true },
	AGAIN = 2,
	ABOVE = 3,
	PARTS = { { "miss", "M" }, { "dodge", "D" }, { "parry", "P" }, { "glance", "G" }, { "block", "B" }, { "crit", "C" }, { "hit", "H" },
		{ "resist", "R" } },
	SEPARATOR = " ",
	LABELS = { swing = "Swing", main = "Main hand", off = "Off hand", special = "Special", ranged = "Ranged", spell = "Spells" },
	HEADER = "Hit table",
	STYLE = { header = { 1, 0.82, 0 }, label = { 0.82, 0.82, 0.82 }, value = { 1, 1, 1 }, dim = { 0.66, 0.68, 0.62 } },
	OLD = "Your stats from before this fight",
	UNKNOWN = "Level ?? counted as %d",
	BOSS = "A boss counted as level %d",
	PLAYER = "A player's dodge, parry and block counted from 5%",
	ASSUMED = "Weapon skill counted as the most for your level",
	PIERCE = "R counts your Spell Piercing %d against resistances not known, counted as 0",
	LEVEL_RESIST = ", and ~%s for its levels above you, which piercing does not lower; a spell that also slows or roots pays for them with its higher miss instead",
	JOIN = "; ",
}

local added = setmetatable({}, { __mode = "k" })
local held = { version = 0, role = "damage", stale = false, fought = false }
local made = {}
local run = { reported = false }
local sizing = { sized = {} }
local waiting = {}

local function Index(t, key)
	return t[key]
end

local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
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

local function Text(value)
	if IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function Choice()
	local value = ns.Get(HT.ROW)
	if value == "on" or value == "off" then
		return value
	end
	return "role"
end

local function Style()
	local M = ns.SpellModel
	local fmt = type(M) == "table" and type(M.Fmt) == "table" and M.Fmt or nil
	local style = fmt and type(fmt.Style) == "table" and fmt.Style or nil
	if style and type(style.header) == "table" and type(style.label) == "table" and type(style.value) == "table" and type(style.dim) == "table" then
		return style
	end
	return HT.STYLE
end

local function UnitType()
	local types = type(Enum) == "table" and Field(Enum, "TooltipDataType") or nil
	local value = Field(types, "Unit")
	return Finite(value) and value or HT.UNIT
end

local function UnitOf(data)
	local guid = Text(Field(data, "guid"))
	if not guid then
		return nil
	end
	local unit = Text(Ask(UnitTokenFromGUID, guid))
	if not unit and Ask(UnitGUID, "mouseover") == guid then
		unit = "mouseover"
	end
	return unit, guid
end

local function Enemy(unit)
	if Ask(UnitCanAttack, "player", unit) ~= true or Ask(UnitIsDeadOrGhost, unit) == true or type(UnitLevel) ~= "function" then
		return false
	end
	local ok, level = pcall(UnitLevel, unit)
	return ok and Finite(level)
end

local function Role()
	local role
	if type(ns.PlayerRole) == "function" then
		local ok, found = pcall(ns.PlayerRole)
		role = ok and Text(found) or nil
	end
	return (role == "tank" or role == "healer") and role or "damage"
end

local function Fighting()
	if Ask(InCombatLockdown) == true or Ask(UnitAffectingCombat, "player") == true then
		return true
	end
	local api = type(C_Secrets) == "table" and C_Secrets or nil
	local ask = api and Field(api, "ShouldUnitStatsBeSecret") or nil
	if type(ask) ~= "function" then
		return false
	end
	local ok, secret = pcall(ask)
	return not ok or IsSecret(secret) or secret ~= false
end

local function Plain(inputs)
	if type(inputs) ~= "table" or not Finite(inputs.level) then
		return false
	end
	for _, why in pairs(type(inputs.gaps) == "table" and inputs.gaps or {}) do
		if why == "withheld" then
			return false
		end
	end
	return true
end

local function Look(C)
	local fighting = Fighting()
	local now = Ask(GetTime)
	now = Finite(now) and now or 0
	local form = Ask(GetShapeshiftForm)
	if held.at == nil or now - held.at >= HT.AGAIN or now < held.at or (held.fought and not fighting)
		or (not fighting and form ~= held.form) then
		held.at, held.fought, held.role, held.form = now, fighting, Role(), form
		if not fighting and not (Choice() == "role" and held.role == "healer") then
			local inputs = C.Inputs({ kinds = HT.KINDS, against = "level" })
			held.stale = not Plain(inputs)
			if not held.stale then
				held.inputs, held.version = inputs, held.version + 1
			end
		end
	end
	return fighting or held.stale
end

local function Against(C, inputs, unit, guid)
	local key = guid .. "|" .. held.version
	if made.targetKey ~= key then
		local target = C.Target(nil, inputs.level, unit)
		if type(target) ~= "table" or not target.enemy or not Finite(target.level) then
			return nil
		elseif target.kind == "boss" and target.level >= inputs.level and target.level < inputs.level + HT.ABOVE then
			target.level, target.raised = inputs.level + HT.ABOVE, true
		end
		made.targetKey, made.target = key, target
	end
	if made.target then
		made.target.unit = unit
	end
	return made.target
end

local function Front(C, target)
	local facing = ns.Get(HT.FACING)
	if facing == "front" then
		return true
	elseif facing == "behind" then
		return false
	end
	return C.Front("auto", target) == true or held.role == "tank"
end

local function Short(value)
	if math.abs(value) < 0.05 then
		value = 0
	end
	local text = ("%.1f"):format(value)
	text = text:gsub("%.0$", "")
	return text
end

local function Parts(line)
	local parts, known = {}, false
	for _, part in ipairs(HT.PARTS) do
		local value = line.parts[part[1]]
		if value ~= false then
			known = known or Finite(value)
			parts[#parts + 1] = part[2] .. (Finite(value) and Short(value) or "?")
		end
	end
	return known and table.concat(parts, HT.SEPARATOR) or nil
end

local function ResistNote(notes, read, target)
	local spell
	for _, line in ipairs(type(read.lines) == "table" and read.lines or {}) do
		if line.id == "spell" then
			spell = line
		end
	end
	local resist = spell and type(spell.parts) == "table" and spell.parts.resist
	if not Finite(resist) or math.abs(resist) < 0.05 or not Finite(spell.pen) then
		return
	end
	local note = HT.PIERCE:format(math.floor(spell.pen + 0.5))
	local C = ns.HitTableCalc
	local level = spell.levelResist and type(C) == "table" and type(C.Resist) == "function" and C.Resist(read.level, target.level, false, 0) or nil
	if Finite(level) and level >= 0.05 then
		note = note .. HT.LEVEL_RESIST:format(Short(level) .. "%")
	end
	notes[#notes + 1] = note
end

local function Notes(read, target, old)
	local notes = {}
	if old then
		notes[#notes + 1] = HT.OLD
	end
	if target.unknown then
		notes[#notes + 1] = HT.UNKNOWN:format(target.level)
	elseif target.raised then
		notes[#notes + 1] = HT.BOSS:format(target.level)
	end
	if target.player then
		notes[#notes + 1] = HT.PLAYER
	end
	if type(read.assumed) == "table" and #read.assumed > 0 then
		notes[#notes + 1] = HT.ASSUMED
	end
	ResistNote(notes, read, target)
	return notes
end

local function Shape(read, target, old)
	local style, figures = Style(), {}
	for _, line in ipairs(type(read.lines) == "table" and read.lines or {}) do
		local right = type(line.parts) == "table" and Parts(line) or nil
		if right then
			figures[#figures + 1] = { left = HT.LABELS[line.id] or line.label, right = right, colour = style.label,
				rightColour = old and style.label or style.value }
		end
	end
	local lines = {}
	if #figures == 0 then
		return lines
	elseif #figures > 1 then
		lines[1] = { left = HT.HEADER, colour = style.header, wrap = false, header = true }
	end
	for _, line in ipairs(figures) do
		lines[#lines + 1] = line
	end
	local notes = Notes(read, target, old)
	if #notes > 0 and ns.Get(HT.DETAIL) == "full" then
		for _, note in ipairs(notes) do
			lines[#lines + 1] = { left = note .. ".", colour = style.dim, wrap = true }
		end
	elseif #notes > 0 then
		lines[#lines + 1] = { left = table.concat(notes, HT.JOIN) .. ".", colour = style.dim, wrap = true }
	end
	return lines
end

local function LinesFor(C, unit, guid, old)
	local inputs = held.inputs
	local target = Against(C, inputs, unit, guid)
	if not target then
		return nil
	end
	local front = Front(C, target)
	local power = Ask(UnitPowerType, "player")
	if not Finite(power) then
		power = inputs.power
	end
	local key = table.concat({ guid, held.version, tostring(front), tostring(old), tostring(power), tostring(ns.Get(HT.LINES)),
		tostring(ns.Get(HT.SPECIAL)), tostring(ns.Get(HT.RULES)), tostring(ns.Get(HT.DETAIL)) }, "|")
	if made.key == key then
		return made.lines
	end
	local copy = {}
	for field, value in pairs(inputs) do
		copy[field] = value
	end
	copy.target, copy.front, copy.facingUnsure = target, front, false
	local kinds = C.Kinds(ns.Get(HT.LINES), inputs.class, power)
	if type(kinds) == "table" then
		copy.melee = kinds.melee and inputs.melee or nil
		copy.ranged = kinds.ranged and inputs.ranged or nil
		copy.spell = kinds.spell and inputs.spell or nil
	end
	local assumed = {}
	for _, hand in ipairs(type(inputs.assumed) == "table" and inputs.assumed or {}) do
		if (hand == "ranged weapon" and copy.ranged) or (hand ~= "ranged weapon" and copy.melee) then
			assumed[#assumed + 1] = hand
		end
	end
	copy.assumed = assumed
	local read = C.Table({ special = ns.Get(HT.SPECIAL) ~= false, rules = ns.Get(HT.RULES) }, copy)
	made.key, made.lines = key, type(read) == "table" and Shape(read, target, old) or {}
	return made.lines
end

local function SizeOf(font)
	local ok, _, size = pcall(font.GetFont, font)
	return ok and Finite(size) and size or nil
end

local function Unsize()
	local sized = sizing.sized
	for index = #sized, 1, -1 do
		local entry = sized[index]
		sized[index] = nil
		local fs, object = entry.fs, entry.object
		local back = object ~= nil and pcall(fs.SetFontObject, fs, object)
		if back then
			local want, have = SizeOf(object), SizeOf(fs)
			back = want ~= nil and have ~= nil and math.abs(want - have) < 0.5
		end
		if not back then
			pcall(fs.SetFont, fs, entry.file, entry.size, entry.flags)
		end
	end
end

local function Cleared(tooltip)
	if #sizing.sized > 0 and rawequal(tooltip, GameTooltip) then
		Unsize()
	end
end

local function Percent()
	local value = tonumber(ns.Get(HT.SIZE))
	return Finite(value) and value > 0 and value or 100
end

local function Size(index, pair, percent)
	if sizing.follow == nil then
		sizing.follow = ns.FollowGlobal("GameTooltip_ClearMoney", Cleared) == true
	end
	if not sizing.follow then
		return
	end
	for side = 1, pair and 2 or 1 do
		local fs = _G[HT.FONT_STRING:format(side == 1 and "Left" or "Right", index)]
		local ok, file, size, flags = false, nil, nil, nil
		if not ns.Forbidden(fs) then
			ok, file, size, flags = pcall(fs.GetFont, fs)
		end
		if ok and Text(file) and Finite(size) and size > 0 and not IsSecret(flags) then
			local found, object = pcall(fs.GetFontObject, fs)
			object = found and not IsSecret(object) and type(object) == "table" and object or nil
			flags = type(flags) == "string" and flags or ""
			if pcall(fs.SetFont, fs, file, size * percent / 100, flags) then
				local sized = sizing.sized
				sized[#sized + 1] = { fs = fs, object = object, file = file, size = size, flags = flags }
			end
		end
	end
end

local function Calc()
	local C = ns.HitTableCalc
	if type(C) ~= "table" or type(C.Inputs) ~= "function" or type(C.Table) ~= "function" or type(C.Target) ~= "function"
		or type(C.Front) ~= "function" or type(C.Kinds) ~= "function" then
		return nil
	end
	return C
end

local function Put(tooltip, line)
	local left, right = line.colour, line.rightColour
	if line.right then
		return (pcall(tooltip.AddDoubleLine, tooltip, line.left, line.right, left[1], left[2], left[3], right[1], right[2], right[3]))
	end
	return (pcall(tooltip.AddLine, tooltip, line.left, left[1], left[2], left[3], line.wrap == true))
end

local function Add(tooltip, lines, shown, first)
	local percent = Percent()
	for index = first, #lines do
		local line = lines[index]
		if not Put(tooltip, line) then
			break
		end
		shown = shown + 1
		if percent ~= 100 then
			Size(shown, line.right ~= nil, percent)
		end
	end
	return shown
end

local function Report(ok, err)
	if ok or err == nil or run.reported then
		return
	end
	run.reported = true
	local found, handler = false, nil
	if type(geterrorhandler) == "function" then
		found, handler = pcall(geterrorhandler)
	end
	if found and type(handler) == "function" then
		pcall(handler, ("Flat UI Chat and tooltips, %s: %s"):format(PART, tostring(err)))
	end
end

local function CtrlDown()
	return Ask(IsControlKeyDown) == true
end

local function OwnerOf(tooltip)
	local ok, owner = pcall(tooltip.GetOwner, tooltip)
	if ok and not IsSecret(owner) then
		return owner
	end
	return nil
end

local function FirstInfo(tooltip)
	return Field(Field(tooltip, "infoList"), 1)
end

local function Unwait()
	waiting.data, waiting.owner = nil, nil
	if waiting.frame then
		pcall(waiting.frame.UnregisterEvent, waiting.frame, "MODIFIER_STATE_CHANGED")
	end
end

local function HintString(index, shown)
	if not Finite(index) or index > shown then
		return nil
	end
	local fs = _G[HT.FONT_STRING:format("Left", index)]
	if ns.Forbidden(fs) then
		return nil
	end
	local ok, text = pcall(fs.GetText, fs)
	if ok and not IsSecret(text) and text == HT.HINT_TEXT then
		return fs
	end
	return nil
end

local function Pressed(data, tooltip)
	Unwait()
	local C = Calc()
	if not C then
		return
	end
	local old = Look(C)
	if (Choice() == "role" and held.role == "healer") or not held.inputs then
		return
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local unit, guid = UnitOf(data)
	if not unit or not Enemy(unit) then
		return
	end
	local lines = LinesFor(C, unit, guid, old)
	if not lines or #lines == 0 then
		return
	end
	local record, first = added[tooltip], 1
	local fs = record and rawequal(record.data, data) and HintString(record.hint, shown) or nil
	if fs and pcall(fs.SetText, fs, HT.HEADER) then
		local colour = Style().header
		pcall(fs.SetTextColor, fs, colour[1], colour[2], colour[3])
		first = lines[1].header and 2 or 1
	end
	shown = Add(tooltip, lines, shown, first)
	added[tooltip] = { data = data, lines = shown }
	pcall(tooltip.Show, tooltip)
end

local function KeyChanged(_, _, key)
	if IsSecret(key) or not HT.CTRL_KEYS[key] or waiting.data == nil or not CtrlDown() then
		return
	end
	local tip, data = GameTooltip, waiting.data
	if ns.Get(HT.CTRL) ~= true or Choice() == "off" or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART)
		or type(tip) ~= "table" or ns.Forbidden(tip) then
		Unwait()
		return
	end
	if Ask(tip.IsShown, tip) ~= true or not rawequal(Field(FirstInfo(tip), "tooltipData"), data)
		or not rawequal(OwnerOf(tip), waiting.owner) then
		Unwait()
		return
	end
	if type(Field(waiting.owner, "UpdateTooltip")) == "function" or type(Field(tip, "UpdateTooltip")) == "function" then
		return
	end
	Report(ns.EachPart(KEY, PART, Pressed, data, tip))
end

local function Wait(tooltip, data)
	if not waiting.frame and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and not IsSecret(frame) and type(frame) == "table" then
			ns.Own[frame] = true
			frame:SetScript("OnEvent", KeyChanged)
			waiting.frame = frame
		end
	end
	if not waiting.frame then
		return
	end
	waiting.data, waiting.owner = data, OwnerOf(tooltip)
	pcall(waiting.frame.RegisterEvent, waiting.frame, "MODIFIER_STATE_CHANGED")
end

local function Work(data, tooltip)
	if not rawequal(tooltip, GameTooltip) or ns.Forbidden(tooltip) then
		return
	end
	local readable, embedded = pcall(Index, tooltip, "IsEmbedded")
	if not readable or IsSecret(embedded) or embedded == true then
		return
	end
	if waiting.data ~= nil and not rawequal(waiting.data, data) then
		Unwait()
	end
	local C = Calc()
	if not C then
		return
	end
	local old = Look(C)
	if Field(data, "type") ~= UnitType() or (Choice() == "role" and held.role == "healer") or not held.inputs then
		return
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	if not ok or not Finite(shown) then
		return
	end
	local record = added[tooltip]
	if record and rawequal(record.data, data) and shown >= record.lines then
		return
	end
	local unit, guid = UnitOf(data)
	if not unit or not Enemy(unit) then
		return
	end
	local hint = ns.Get(HT.CTRL) == true and not CtrlDown()
	if hint then
		Wait(tooltip, data)
		if ns.Get(HT.HINT) ~= true then
			return
		end
	end
	local lines = LinesFor(C, unit, guid, old)
	if not lines or #lines == 0 then
		return
	elseif hint then
		lines = { { left = HT.HINT_TEXT, colour = Style().dim, wrap = false } }
	end
	if #sizing.sized > 0 then
		Unsize()
	end
	local before = shown
	shown = Add(tooltip, lines, shown, 1)
	added[tooltip] = { data = data, lines = shown, hint = hint and shown > before and shown or nil }
end

function ns.HitTableTipLines(tooltip, data)
	if Choice() == "off" or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return
	end
	if IsSecret(tooltip) or IsSecret(data) or type(data) ~= "table" then
		return
	end
	Report(ns.EachPart(KEY, PART, Work, data, tooltip))
end
