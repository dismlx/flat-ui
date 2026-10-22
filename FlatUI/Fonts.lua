local _, ns = ...

-- Replaces the game's fonts. The game's text is drawn with Font objects: global tables whose GetObjectType is "Font", each with a file, a height,
-- flags and a shadow offset (SimpleFontAPIDocumentation.lua:33-46, 146-158, 199-211). They are walked once, out of combat, and what each held is
-- recorded in a table that does not keep them alive. An object whose file is the game's body face takes the Interface font, the one with the number
-- face takes the Number font, the one with the title face takes the Title font. The size, the outline, the shadow and the smallest height apply to
-- every object. Every row at the game's value, or the module off, sets the recorded values back.
-- The game sets some of these objects itself: TextSizeManagerBase:SetTextScale calls SetFontHeight on each user-scaled font
-- (Blizzard_AccessibilityTemplates/TextSizeManager.lua:52-61) and ObjectiveTrackerManager:SetTextSize points the two tracker fonts at others
-- (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerManager.lua:97-106). Both are followed by events, and an object whose font is no longer the one set here
-- takes the game's new font as the one to go back to.
-- Font objects are shared, so other addons' text that uses them changes too. The chat window fonts and the nameplate fonts are left alone.

local KEY = "fonts"
-- The game's faces by the file name in lower case, and the row that picks the face for the objects that use it.
local ROLE = { ["frizqt__.ttf"] = "body", ["arialn.ttf"] = "numbers", ["morpheus.ttf"] = "titles" }
-- The flags of each line of the outline row. "game" is not here: it keeps the flags the game gave.
local OUTLINE = { none = "", thin = "OUTLINE", thick = "THICKOUTLINE" }
-- Clients whose own fonts are Latin. A family-backed object may change only its roman member on another client, so faces are left alone there.
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true, ptPT = true }
local V = {
	-- Per Font object: { name, file, height, flags = what the game gave, sx, sy = its shadow offset, setFile, setHeight, setFlags = what was set
	-- here (nil while the game's own), shadowSet = true while the offset is set here }
	records = setmetatable({}, { __mode = "k" }),
	walked = false, queued = false, changed = 0, refused = 0,
}

-- The lines of the outline row and the flags of a line. Nil from OutlineFlags keeps the flags the game gave.
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

-- A name of a font object this module leaves alone: the chat fonts, the nameplate fonts and the addon's own.
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

-- The record of the Font object this one inherits from, when its current font is the one that object has now.
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

-- Records one global when it is a Font object not recorded yet.
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
		-- It shows what Flat UI set on its parent: it counts as set, so Off puts the game's back.
		record.setFile, record.setHeight, record.setFlags = file, height, flags
	end
	local okShadow, x, y = pcall(value.GetShadowOffset, value)
	if okShadow and Plain(x, "number") and Plain(y, "number") then
		record.sx, record.sy = x, y
	end
	V.records[value] = record
end

-- Records every Font object the first time it is asked for. Each global is read in a pcall: it may be any value.
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

-- True when every row is at the game's own value.
local function AtGame()
	return Opt("body") == "default" and Opt("numbers") == "default" and Opt("titles") == "default" and Opt("outline") == "game"
		and Opt("shadow") == true and Opt("size") == 100 and Opt("minimum") == 0
end

-- True on a client whose faces Flat UI may change. Shared with the setup drawing of the Fonts step.
function ns.FontsLatin()
	return type(GetLocale) ~= "function" or LATIN[GetLocale()] == true
end

-- The font an object is to have, from what the game gave it.
local function Wanted(record)
	local file = record.file
	local role = ROLE[(record.file:match("([^\\/]+)$") or ""):lower()]
	if role ~= nil and ns.FontsLatin() then
		file = ns.FontFile(Opt(role)) or file
	end
	local height = record.height * Opt("size") / 100
	if type(ns.TipTextShare) == "function" then
		-- The tooltip text size of the chat module is taken here, so the two never write the same object.
		height = height * ns.TipTextShare(record.name)
	end
	height = math.max(height, Opt("minimum"))
	local flags = ns.OutlineFlags(Opt("outline")) or record.flags
	return file, height, flags
end


-- Sets the font of one object, from the one the game gave it. A refused call raises, so the part counts it and stops after enough objects.
local function FontPart(object, record, restore)
	local file, height, flags = Read(object)
	if file == nil then
		error("GetFont gave nothing for " .. record.name, 0)
	end
	if record.setFile ~= nil and not Same(file, height, flags, record.setFile, record.setHeight, record.setFlags) then
		-- The game set it again. Only what differs from what was set is the game's: SetFontHeight, for one, changes the height alone.
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
			-- Already what Flat UI wants after the game changed the height alone: it still counts as set.
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

-- Takes the shadow off, or puts the game's back.
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

local function Pass()
	V.queued = false
	local restore = not ns.Enabled(KEY) or AtGame()
	if restore and not V.walked then
		return
	end
	Walk()
	local changed = 0
	for object, record in pairs(V.records) do
		if restore or ns.PartStopped(KEY, "font") then
			-- Off, at the game's values, or the part stopped: the font goes back whatever the rows say.
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
end

-- Runs the pass now, or when combat ends.
local function Queue()
	if V.queued then
		return
	end
	V.queued = true
	ns.OutOfCombat(function()
		Pass()
	end)
end

-- Whether this module sets the height of the object: on, a row off the game's values, the font part running, and the object recorded or not walked yet.
function ns.FontsHolds(object)
	return ns.Enabled(KEY) and not AtGame() and not ns.PartStopped(KEY, "font") and (V.records[object] ~= nil or not V.walked)
end

function ns.FontsQueue()
	Queue()
end

-- The game sets these objects again when the text size changes and when Edit Mode applies a layout. None of it is followed with a hook on
-- TextSizeManager or ObjectiveTrackerManager: the text scale is the userFontScale variable (TextSizeManager.lua:12-18, 70-72), which the
-- client announces on CVAR_UPDATE, and the tracker text size is a setting of the tracker's Edit Mode system
-- (EditModeSystemTemplates.lua:2405-2407), applied with the layout (EditModeManager.lua:193) and at the end of Edit Mode
-- (EditModeManager.lua:124). The pass waits a frame, so it never runs inside the game's own pass.
-- EllesmereUI hooks neither table (EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_WindowPacks.lua:11573-11576 re-applies its own sizes each pass).
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

-- The end of Edit Mode, triggered from inside the game's own exit.
local function Watch()
	if watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	watched = pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", Later, V)
end

local function Refresh()
	if ns.Enabled(KEY) then
		Watch()
	end
	Queue()
end

ns.Register(KEY, {
	label = "Fonts",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	events = {
		-- The text scale of the game's settings; the game sets every scaled font again after VARIABLES_LOADED too.
		CVAR_UPDATE = function(name)
			if not ns.IsSecret(name) and type(name) == "string" and name:lower():find("^userfontscale") ~= nil then
				Later()
			end
		end,
		VARIABLES_LOADED = Later,
		EDIT_MODE_LAYOUTS_UPDATED = Later,
		-- A specialization change applies that specialization's layout, and with it the tracker text size
		-- (EditModeManager.lua:63, 203-206, 1481-1485); neither the layouts event nor the end of Edit Mode follows it.
		PLAYER_SPECIALIZATION_CHANGED = function(unit)
			if not ns.IsSecret(unit) and unit == "player" then
				Later()
			end
		end,
		-- A game addon that loads later has fonts of its own.
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
