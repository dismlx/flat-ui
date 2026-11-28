local _, ns = ...

local KEY = "fonts"
local ROLE = { ["frizqt__.ttf"] = "body", ["arialn.ttf"] = "numbers", ["morpheus.ttf"] = "titles" }
local OUTLINE = { none = "", thin = "OUTLINE", thick = "THICKOUTLINE" }
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true, ptPT = true }
local V = {
	records = setmetatable({}, { __mode = "k" }),
	walked = false, queued = false, changed = 0, refused = 0,
}

function ns.OutlineChoices()
	return ns.OUTLINE_CHOICES
end

function ns.OutlineFlags(id)
	return OUTLINE[id]
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Skipped(name)
	return name:find("^ChatFont") ~= nil or name:find("^SystemFont_NamePlate") ~= nil or name:find("^FlatUI") ~= nil
end

local function Same(file, height, flags, otherFile, otherHeight, otherFlags)
	return file == otherFile and flags == otherFlags and math.abs(height - otherHeight) < 0.01
end

local function Read(object)
	local ok, file, height, flags = pcall(object.GetFont, object)
	if ok and Plain(file, "string") and file ~= "" and Plain(height, "number") and height > 0 and Plain(flags, "string") then
		return file, height, flags
	end
	return nil
end

local function ParentBase(value, file, height, flags)
	local okParent, parent = pcall(value.GetFontObject, value)
	if not okParent or type(parent) ~= "table" or ns.IsSecret(parent) then
		return nil
	end
	local record = V.records[parent]
	if record == nil then
		return nil
	end
	local nowFile, nowHeight, nowFlags = record.file, record.height, record.flags
	if record.setFile ~= nil then
		nowFile, nowHeight, nowFlags = record.setFile, record.setHeight, record.setFlags
	end
	if Same(file, height, flags, nowFile, nowHeight, nowFlags) then
		return record.file, record.height, record.flags
	end
	return nil
end

local function Visit(name, value)
	if type(name) ~= "string" or type(value) ~= "table" or Skipped(name) or V.records[value] ~= nil or ns.IsSecret(value) then
		return
	end
	local ok, kind = pcall(value.GetObjectType, value)
	if not ok or kind ~= "Font" then
		return
	end
	local file, height, flags = Read(value)
	if file == nil then
		return
	end
	local baseFile, baseHeight, baseFlags = ParentBase(value, file, height, flags)
	local record = { name = name, file = baseFile or file, height = baseHeight or height, flags = baseFlags or flags }
	if baseFile ~= nil and not Same(file, height, flags, baseFile, baseHeight, baseFlags) then
		record.setFile, record.setHeight, record.setFlags = file, height, flags
	end
	local okShadow, x, y = pcall(value.GetShadowOffset, value)
	if okShadow and Plain(x, "number") and Plain(y, "number") then
		record.sx, record.sy = x, y
	end
	V.records[value] = record
end

local function Walk()
	if V.walked then
		return
	end
	local names = {}
	pcall(function()
		for name in pairs(_G) do
			names[#names + 1] = name
		end
	end)
	table.sort(names, function(left, right) return tostring(left) < tostring(right) end)
	for _, name in ipairs(names) do
		local okValue, value = pcall(function() return _G[name] end)
		if okValue then
			pcall(Visit, name, value)
		end
	end
	V.walked = true
end

local function AtGame()
	return Opt("body") == "default" and Opt("numbers") == "default" and Opt("titles") == "default" and Opt("outline") == "game"
		and Opt("shadow") == true and Opt("size") == 100 and Opt("minimum") == 0
end

function ns.FontsLatin()
	return type(GetLocale) ~= "function" or LATIN[GetLocale()] == true
end

local function Wanted(record)
	local file = record.file
	local role = ROLE[(record.file:match("([^\\/]+)$") or ""):lower()]
	if role ~= nil and ns.FontsLatin() then
		file = ns.FontFile(Opt(role)) or file
	end
	local height = record.height * Opt("size") / 100
	if type(ns.TipTextShare) == "function" then
		height = height * ns.TipTextShare(record.name)
	end
	height = math.max(height, Opt("minimum"))
	local flags = ns.OutlineFlags(Opt("outline")) or record.flags
	return file, height, flags
end

local function FontPart(object, record, restore)
	local file, height, flags = Read(object)
	if file == nil then
		error("GetFont gave nothing for " .. record.name, 0)
	end
	if record.setFile ~= nil and not Same(file, height, flags, record.setFile, record.setHeight, record.setFlags) then
		if file ~= record.setFile then record.file = file end
		if flags ~= record.setFlags then record.flags = flags end
		if math.abs(height - record.setHeight) >= 0.01 then record.height = height end
		record.setFile, record.setHeight, record.setFlags = nil, nil, nil
	elseif record.setFile == nil then
		record.file, record.height, record.flags = file, height, flags
	end
	local wantFile, wantHeight, wantFlags = record.file, record.height, record.flags
	if not restore then
		wantFile, wantHeight, wantFlags = Wanted(record)
	end
	if Same(file, height, flags, wantFile, wantHeight, wantFlags) then
		if not Same(wantFile, wantHeight, wantFlags, record.file, record.height, record.flags) then
			record.setFile, record.setHeight, record.setFlags = wantFile, wantHeight, wantFlags
		end
		return
	end
	local ok, result = pcall(object.SetFont, object, wantFile, wantHeight, wantFlags)
	if not ok or result == false then
		V.refused = V.refused + 1
		error("SetFont refused for " .. record.name, 0)
	end
	if Same(wantFile, wantHeight, wantFlags, record.file, record.height, record.flags) then
		record.setFile, record.setHeight, record.setFlags = nil, nil, nil
	else
		record.setFile, record.setHeight, record.setFlags = wantFile, wantHeight, wantFlags
	end
end

local function ShadowPart(object, record, restore)
	if record.sx == nil then
		return
	end
	local off = not restore and Opt("shadow") == false
	if off and not record.shadowSet then
		if not pcall(object.SetShadowOffset, object, 0, 0) then
			error("SetShadowOffset refused for " .. record.name, 0)
		end
		record.shadowSet = true
	elseif not off and record.shadowSet then
		if not pcall(object.SetShadowOffset, object, record.sx, record.sy) then
			error("SetShadowOffset refused for " .. record.name, 0)
		end
		record.shadowSet = nil
	end
end

local function Rows()
	return table.concat({ tostring(ns.Enabled(KEY)), tostring(Opt("body")), tostring(Opt("numbers")), tostring(Opt("titles")), tostring(Opt("outline")),
		tostring(Opt("shadow")), tostring(Opt("size")), tostring(Opt("minimum")) }, "|")
end

local function Pass()
	V.queued = false
	local was = V.applied
	V.applied = Rows()
	local restore = not ns.Enabled(KEY) or AtGame()
	if restore and not V.walked then
		return
	end
	Walk()
	local changed = 0
	for object, record in pairs(V.records) do
		if restore or ns.PartStopped(KEY, "font") then
			if record.setFile ~= nil then
				pcall(FontPart, object, record, true)
			end
		else
			ns.EachPart(KEY, "font", FontPart, object, record, false)
		end
		if restore or ns.PartStopped(KEY, "shadow") then
			if record.shadowSet then
				pcall(ShadowPart, object, record, true)
			end
		else
			ns.EachPart(KEY, "shadow", ShadowPart, object, record, false)
		end
		if record.setFile ~= nil or record.shadowSet then
			changed = changed + 1
		end
	end
	if not restore and ns.PartStopped(KEY, "font") then
		for object, record in pairs(V.records) do
			if record.setFile ~= nil then
				pcall(FontPart, object, record, true)
			end
		end
		changed = 0
		for _, record in pairs(V.records) do
			if record.setFile ~= nil or record.shadowSet then
				changed = changed + 1
			end
		end
	end
	V.changed = changed
	if was ~= V.applied then
		if ns.ErrorTextRefont ~= nil then
			pcall(ns.ErrorTextRefont)
		end
		if ns.ZoneTitleRefont ~= nil then
			pcall(ns.ZoneTitleRefont)
		end
	end
end

local function Queue(changed)
	if changed and not V.told and InCombatLockdown() and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
		V.told = true
		print("Flat UI: fonts change when the fight ends.")
	end
	if V.queued then
		return
	end
	V.queued = true
	ns.OutOfCombat(function()
		V.told = false
		Pass()
	end)
end

function ns.FontsHolds(object)
	return ns.Enabled(KEY) and not AtGame() and not ns.PartStopped(KEY, "font") and (V.records[object] ~= nil or not V.walked)
end

function ns.FontsQueue()
	Queue()
end

local later = false

local function Later()
	if later then
		return
	end
	later = true
	local function run()
		later = false
		if ns.Enabled(KEY) then
			Queue()
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end

local watched = false

local function Watch()
	if watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	watched = pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", Later, V)
end

local function Refresh(changed)
	if ns.Enabled(KEY) then
		Watch()
	end
	Queue(changed == true)
end

local function Changed()
	Refresh(V.applied ~= Rows())
end

ns.Register(KEY, {
	label = "Fonts",
	counted = false,
	Start = Changed,
	Refresh = Changed,
	events = {
		CVAR_UPDATE = function(name)
			if not ns.IsSecret(name) and type(name) == "string" and name:lower():find("^userfontscale") ~= nil then
				Later()
			end
		end,
		VARIABLES_LOADED = Later,
		EDIT_MODE_LAYOUTS_UPDATED = Later,
		PLAYER_SPECIALIZATION_CHANGED = function(unit)
			if not ns.IsSecret(unit) and unit == "player" then
				Later()
			end
		end,
		ADDON_LOADED = function(name)
			if ns.IsSecret(name) or type(name) ~= "string" or name:find("^Blizzard_") == nil then
				return
			end
			V.walked = false
			Refresh()
		end,
	},
	Status = function()
		local lines = {}
		if V.changed > 0 then
			lines[#lines + 1] = ("Fonts: %d font objects changed."):format(V.changed)
		end
		if not ns.FontsLatin() then
			lines[#lines + 1] = "Fonts: faces stay the game's on a client whose language is not Latin."
		end
		return lines
	end,
})
