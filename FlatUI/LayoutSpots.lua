local _, ns = ...

-- A bar the game lays out again (the action bars, and the frames a container places) is kept where the player put it by
-- writing the spot into the Edit Mode layout in use, which the game's own code then applies. Nothing is hooked and no bar is
-- placed from inside a call of the game.
--
-- The approach is EllesmereUI's. An Edit Mode frame is kept by writing anchorInfo and isInDefaultPosition false into the saved
-- layout in use through C_EditMode.SaveLayouts: never into a preset, never in combat, never while Edit Mode is open, and a reset puts
-- back Edit Mode's default (EllesmereUIChat/EllesmereUIChat.lua:1724-1734, 1900-1920, 1926-1958, 1960-1990). The payload is built with
-- the presets first, because SaveLayouts replaces the whole set and activeLayout counts from the presets (EllesmereUI_Uninstall.lua:427-455).
-- Only the data of C_EditMode is read, never a method of EditModeManagerFrame, and only EditModePresetLayoutManager's copy of the presets.
--
-- SaveLayouts is called once, in the click of the Reload button, and ReloadUI follows in the same handler. A save while the game runs makes
-- the game apply the whole layout again inside the caller, and the fields it writes then taint the layout pass at the next edge of a fight
-- (EditModeManager.lua:192-199, 1008-1035; ActionBar.lua:285-287, 339-365). EllesmereUI saves once and forces a reload for that reason
-- (EllesmereUICooldownManager/EUI_CDM_Blizzard.lua:170, 285-330). Until the reload a moved bar is placed by the check, out of combat, with
-- no hook.
--
-- Why it holds: the layout passes of the game place a bar only while its row is in the default position (EditModeManager.lua:684,
-- :693), and ApplySystemAnchor places a bar that is not from its anchorInfo (EditModeSystemTemplates.lua:350-382). A preset
-- cannot be written (EditModePresetLayoutsManager.lua:46-48, 70-74), so a bar on a preset layout is placed by the addon out of
-- combat and goes back to the game's spot in a fight.
--
-- A preset cannot be written, so with movers.presetLayout on "make" the Reload click makes a layout of the addon's own, named Flat UI,
-- from the preset: the layout goes into the saved list after the player's own, C_EditMode.SaveLayouts takes the list and
-- C_EditMode.SetActiveLayout makes it the one in use, and the interface reloads (EllesmereUI/EllesmereUI_Profiles.lua:4683-4745). The game's
-- own layout list is not touched otherwise. After the reload the first check says whether Edit Mode kept it: the layout in use is named Flat UI
-- and is no preset (the self-check of this feature), and when it did not, the status line says so and nothing is tried again.
--
-- ns.LayoutSpots.Kind says which frames this is for, Resolve reads the layout in use, Queue offers the spot of a frame, Apply is the
-- Reload button, Release offers to put a row back, Status gives the lines of /flatui status.

local LS = {}
ns.LayoutSpots = LS

-- Offsets that differ by less than this are the same spot.
local TOLERANCE = 0.1
-- How long the answer of Mode is kept, in seconds.
local MODE_FOR = 0.5

-- queue: the frames waiting for the next frame, by name. pending: the writes and releases that wait for the Reload button, by name. refused:
-- frames whose row did not take the spot. kept: the layout name a frame is kept in.
local queue, queued, waiting = {}, false, false
local pending, refused, kept = {}, {}, {}
local mode = { at = nil, value = nil, name = nil }
local preset = nil
-- The layout of the addon's own. want: the click makes it. state: nil, "kept", "refused" or "elsewhere". checked: the check after a reload is done.
-- recheck: a flush is asked for with no frame queued. presetName: the preset in use when state is "elsewhere". existing: a Flat UI layout is saved
-- already. refusedMode: the value of movers.presetLayout when Edit Mode refused the layout. A refusal is saved for the character
-- (flatLayout.refused and .mode), so no later session tries again until the layout in use is Flat UI or movers.presetLayout is changed. bars: the frames marked refused with the layout. seen: the last
-- spot queued for each frame, offered again when movers.presetLayout changes. setting: the value of movers.presetLayout at the last flush.
local FLAT = "Flat UI"
local flat = { want = false, state = nil, checked = false, recheck = false, presetName = nil, existing = false, refusedMode = nil, seen = {}, setting = nil, bars = {} }
-- The writers other builds add: list by id, wanted by id for the next click, refused, kept, and the ids to put back at the next click.
local wr = { list = {}, pending = {}, refused = {}, kept = {}, unwrite = {} }

local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

local function Plain(value)
	return not ns.IsSecret(value)
end

local function Copy(anchor)
	if type(anchor) ~= "table" then
		return nil
	end
	local copy = {}
	for key, value in pairs(anchor) do
		copy[key] = value
	end
	return copy
end

-- The frames this is for: a system frame of the list that the game's layout passes place again, or a bar of the action bar system, which
-- has the same passes (ActionBar.lua:285-287 and :373 run one at each edge of a fight). `passes` is the answer of Movers about the frame;
-- without it only a bar of the stacks counts.
function LS.Kind(info, frame, passes)
	if type(info) ~= "table" or not info.system or type(frame) ~= "table" then
		return nil
	end
	if passes == nil then
		passes = info.stack == true
	end
	if passes then
		return "layout"
	end
	local ok, system = pcall(function()
		return frame.system
	end)
	local enum = Enum and Enum.EditModeSystem
	if ok and Plain(system) and enum and enum.ActionBar ~= nil and system == enum.ActionBar then
		return "layout"
	end
	return nil
end

-- The saved layouts with the presets first, as SaveLayouts takes them, with the number of presets and the layout in use. Nothing when
-- the data cannot be read. Never a method of EditModeManagerFrame.
local function Load()
	if not (C_EditMode and type(C_EditMode.GetLayouts) == "function" and type(C_EditMode.SaveLayouts) == "function") then
		return nil
	end
	local manager = EditModePresetLayoutManager
	if type(manager) ~= "table" or type(manager.GetCopyOfPresetLayouts) ~= "function" then
		return nil
	end
	local okInfo, info = pcall(C_EditMode.GetLayouts)
	local okPresets, presets = pcall(manager.GetCopyOfPresetLayouts, manager)
	if not (okInfo and okPresets) or type(info) ~= "table" or type(info.layouts) ~= "table" or type(presets) ~= "table" or #presets == 0 then
		return nil
	end
	local count = #presets
	for index, layout in ipairs(info.layouts) do
		presets[count + index] = layout
	end
	info.layouts = presets
	if type(info.activeLayout) ~= "number" or type(info.layouts[info.activeLayout]) ~= "table" then
		return nil
	end
	return info, count, info.layouts[info.activeLayout]
end

local function Name(layout)
	return type(layout.layoutName) == "string" and layout.layoutName or "?"
end

local function Key(layout)
	return tostring(layout.layoutType) .. ":" .. Name(layout)
end

local function IsPreset(layout, index, count)
	local presetType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset
	return index <= count or (presetType ~= nil and layout.layoutType == presetType)
end

-- The layout in use and the payload to save, or nil and why: "combat", "editmode" (both pass), "unavailable" (the calls or the data are
-- missing), "preset" (the layout in use cannot be written, and its entry is the third answer). Reads data only.
function LS.Resolve()
	if InCombatLockdown() then
		return nil, "combat"
	end
	if ns.EditModeOpen() then
		return nil, "editmode"
	end
	local info, count, entry = Load()
	if not info then
		return nil, "unavailable"
	end
	if IsPreset(entry, info.activeLayout, count) then
		return nil, "preset", entry
	end
	return info, entry
end

-- "layout" when the layout in use takes a written spot, "preset" or "unavailable" when it does not, "pending" while a spot waits for the Reload
-- button, and the name of the layout. The answer holds for a moment, and again after anything that could change it.
function LS.Mode()
	if next(pending) ~= nil then
		return "pending"
	end
	local now = type(GetTime) == "function" and GetTime() or 0
	if mode.value and mode.at and now - mode.at < MODE_FOR then
		return mode.value, mode.name
	end
	local info, count, entry = Load()
	if not info then
		mode.value, mode.name = "unavailable", nil
	elseif IsPreset(entry, info.activeLayout, count) then
		mode.value, mode.name = "preset", Name(entry)
	else
		mode.value, mode.name = "layout", Name(entry)
	end
	mode.at = now
	return mode.value, mode.name
end

function LS.Invalidate()
	mode.value = nil
end

-- The row of a layout for a frame: the one whose system and index are the frame's.
function LS.Entry(layout, frame)
	local ok, system, index = pcall(function()
		return frame.system, frame.systemIndex
	end)
	if not ok or not Plain(system) or not Plain(index) or type(layout) ~= "table" or type(layout.systems) ~= "table" then
		return nil
	end
	for _, row in ipairs(layout.systems) do
		if type(row) == "table" and row.system == system and row.systemIndex == index then
			return row
		end
	end
	return nil
end

-- True when the row already holds the spot: its point on UIParent with the same point, offsets within 0.1, no second anchor and not in the
-- default position. spot is { point, x, y, relativePoint }, the offsets in the units of the layout.
function LS.Agrees(row, spot)
	local anchor = type(row) == "table" and row.anchorInfo
	if type(anchor) ~= "table" or row.anchorInfo2 ~= nil or row.isInDefaultPosition ~= false or type(spot) ~= "table" then
		return false
	end
	return anchor.point == spot.point and anchor.relativeTo == "UIParent" and anchor.relativePoint == (spot.relativePoint or spot.point)
		and type(anchor.offsetX) == "number" and type(anchor.offsetY) == "number"
		and math.abs(anchor.offsetX - spot.x) <= TOLERANCE and math.abs(anchor.offsetY - spot.y) <= TOLERANCE
end

-- The offsets saved for a spot: the offsets Move passes, which are in the units of the frame, times the scale of the frame, which is what the
-- game divides them by when it places the bar (EditModeSystemTemplates.lua:365-366).
local function Target(frame, spot)
	if type(spot) ~= "table" or type(spot.point) ~= "string" or type(spot.x) ~= "number" or type(spot.y) ~= "number" then
		return nil
	end
	local ok, scale = pcall(frame.GetScale, frame)
	if not ok or not Plain(scale) or type(scale) ~= "number" or scale <= 0 then
		return nil
	end
	return { point = spot.point, relativePoint = spot.point, x = spot.x * scale, y = spot.y * scale }
end

local function Records()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.layoutBefore) ~= "table" then
		account.layoutBefore = {}
	end
	return account.layoutBefore
end

-- The note of a loop breaker: a spot saved before and still not held by its row is not offered again.
local function Tried()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.layoutTried) ~= "table" then
		account.layoutTried = {}
	end
	return account.layoutTried
end

local function IdOf(lkey, name, target)
	return lkey .. "|" .. ("%s|%s|%.3f|%.3f"):format(name, target.point, target.x, target.y)
end

-- Edit Mode refused the Flat UI layout: kept in this session and saved for the character.
local function SaveRefusal()
	flat.state, flat.refusedMode = "refused", ns.Get("movers.presetLayout")
	local char = ns.Character()
	if type(char) == "table" then
		char.flatLayout = { refused = true, mode = flat.refusedMode }
	end
end

local function ClearRefusal()
	flat.refusedMode = nil
	for name in pairs(flat.bars) do
		refused[name] = nil
	end
	flat.bars = {}
	local char = ns.Character()
	if type(char) == "table" and type(char.flatLayout) == "table" and char.flatLayout.refused then
		char.flatLayout.refused, char.flatLayout.mode = nil, nil
	end
end

function LS.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = LS.DeepCopy(item)
	end
	return copy
end

-- True when the layout data says it is for the gamepad interface (the field EditModeUtil.lua:6-9 reads), read from the data of C_EditMode only.
function LS.IsGamepad(layout)
	local enum = Enum and Enum.InputDeviceInterfaceType
	return type(layout) == "table" and enum ~= nil and enum.Gamepad ~= nil and layout.interfaceStyle == enum.Gamepad
end

function LS.IsCharacter(layout)
	local enum = Enum and Enum.EditModeLayoutType
	return enum ~= nil and layout.layoutType == enum.Character
end

-- The index of the saved layout named Flat UI of the character type, or nil.
function LS.FlatIndex(info, count)
	for index = count + 1, #info.layouts do
		local layout = info.layouts[index]
		if type(layout) == "table" and Name(layout) == FLAT and LS.IsCharacter(layout) then
			return index
		end
	end
	return nil
end

-- The state of the layout of the addon's own: nil, "kept", "refused" or "elsewhere".
function LS.FlatState()
	return flat.state
end

-- True when a check after a reload is waiting: a click made the layout, and no flush has looked at the layout in use since the reload.
function LS.CheckDue()
	local char = ns.Character()
	return not flat.checked and type(char) == "table" and type(char.flatLayout) == "table" and (char.flatLayout.tried == true or char.flatLayout.refused == true)
end

-- Puts a value into a field of a row: a setting number is the entry of row.settings with that setting, any other field is a field of the row.
function LS.SetField(row, field, value)
	if type(field) == "number" and type(row.settings) == "table" then
		for index, entry in ipairs(row.settings) do
			if type(entry) == "table" and entry.setting == field then
				if value == nil then
					table.remove(row.settings, index)
				else
					entry.value = value
				end
				return
			end
		end
		if value ~= nil then
			row.settings[#row.settings + 1] = { setting = field, value = value }
		end
		return
	end
	row[field] = value
end

-- note(frameName, row, field, before) of a writer: keeps the earlier value of a setting the first time only, in
-- records[layoutKey].settings[frameName][field], with who wrote it and which row it was.
function LS.Noter(records, lkey, id)
	return function(frameName, row, field, before)
		if type(frameName) ~= "string" or type(row) ~= "table" or field == nil then
			return
		end
		local list = records[lkey]
		if not list then
			list = {}
			records[lkey] = list
		end
		list.settings, list.by, list.rows = list.settings or {}, list.by or {}, list.rows or {}
		local settings = list.settings[frameName] or {}
		list.settings[frameName] = settings
		if settings[field] == nil then
			if before == nil then
				before = false
			end
			settings[field] = before
		end
		list.by[id] = list.by[id] or {}
		list.by[id][frameName] = list.by[id][frameName] or {}
		list.by[id][frameName][field] = true
		list.rows[frameName] = { system = row.system, systemIndex = row.systemIndex }
	end
end

-- True when a record of a setting this writer wrote is kept for any layout.
function LS.WroteAny(records, id)
	for _, list in pairs(records or {}) do
		if type(list) == "table" and type(list.by) == "table" and list.by[id] and next(list.by[id]) ~= nil then
			return true
		end
	end
	return false
end

-- Puts back every recorded setting of a writer in a layout, and drops the records. True when a setting was put back.
function LS.PutBack(records, layout, id)
	local list = records[Key(layout)]
	local owned = list and list.by and list.by[id]
	if not owned then
		return false
	end
	local did = false
	for frameName, fields in pairs(owned) do
		local at = list.rows and list.rows[frameName]
		local row
		for _, candidate in ipairs(layout.systems or {}) do
			if type(candidate) == "table" and at and candidate.system == at.system and candidate.systemIndex == at.systemIndex then
				row = candidate
				break
			end
		end
		for field in pairs(fields) do
			local before = list.settings and list.settings[frameName] and list.settings[frameName][field]
			if row and before ~= nil then
				LS.SetField(row, field, before ~= false and before or nil)
				did = true
			end
			if list.settings and list.settings[frameName] then
				list.settings[frameName][field] = nil
			end
		end
		if list.settings and list.settings[frameName] and next(list.settings[frameName]) == nil then
			list.settings[frameName] = nil
		end
		if list.rows then
			list.rows[frameName] = nil
		end
	end
	list.by[id] = nil
	for _, key in ipairs({ "by", "settings", "rows" }) do
		if type(list[key]) == "table" and next(list[key]) == nil then
			list[key] = nil
		end
	end
	if next(list) == nil then
		records[Key(layout)] = nil
	end
	return did
end

-- The line with the Reload button. The layout is saved when the button is pressed, and the interface reloads in the same click, so the game
-- applies the saved layout at its own load and not under this addon's call (EllesmereUI/EllesmereUICooldownManager/EUI_CDM_Blizzard.lua:170, 285-330).
local notice = nil

local function Click()
	-- On Forever the secure button saves and reloads in one click. A press that gets here saves nothing, because a saved layout with no reload
	-- after it would run the game's layout pass in this addon's call.
	if type(ns.ReloadIsForever) == "function" and ns.ReloadIsForever() then
		ns.Reload()
		return
	end
	if LS.Apply() then
		ns.Reload()
	end
end

-- What the line says depends on what waits for the click.
function LS.NoticeText()
	if flat.want then
		if flat.existing then
			return "Reload to keep moved bars in the Edit Mode layout named Flat UI."
		end
		return "Reload to keep moved bars in a new Edit Mode layout named Flat UI."
	end
	if next(pending) == nil and (next(wr.pending) ~= nil or next(wr.unwrite) ~= nil) then
		return "Reload to keep bar changes in the Edit Mode layout."
	end
	return "Reload to keep moved bars in the Edit Mode layout."
end

local function BuildNotice()
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok or type(frame) ~= "table" then
		return nil
	end
	ns.Own[frame] = true
	frame:SetSize(330, 30)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -90)
	frame:SetFrameStrata("DIALOG")
	local outline = ns.Outline(frame, frame, true)
	ns.SetOutlineFill(outline, 0.09, 0.09, 0.09, 0.95)
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", frame, "LEFT", 10, 0)
	text:SetText(LS.NoticeText())
	local okButton, button = pcall(CreateFrame, "Frame", nil, frame)
	if not okButton or type(button) ~= "table" then
		return nil
	end
	ns.Own[button] = true
	button:SetSize(64, 20)
	button:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
	local face = ns.Outline(button, button, true)
	ns.SetOutlineFill(face, 0.2, 0.2, 0.2, 1)
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText("Reload")
	button:EnableMouse(true)
	button:SetScript("OnMouseUp", function(_, which)
		if which == "LeftButton" then
			Click()
		end
	end)
	if type(ns.SecureReload) == "function" then
		ns.SecureReload(button, LS.Apply)
	end
	return { frame = frame, button = button, text = text }
end

local function ShowNotice()
	if InCombatLockdown() then
		ns.OutOfCombat(ShowNotice)
		return
	end
	local wanted = next(pending) ~= nil or next(wr.pending) ~= nil or next(wr.unwrite) ~= nil
	if wanted and not notice then
		notice = BuildNotice()
	end
	if notice then
		if notice.text then
			notice.text:SetText(LS.NoticeText())
			-- 330 wide, wider when the line needs it.
			local okWidth, width = pcall(notice.text.GetStringWidth, notice.text)
			if okWidth and Plain(width) and type(width) == "number" then
				notice.frame:SetWidth(math.max(330, math.ceil(width) + 90))
			end
		end
		notice.frame:SetShown(wanted or notice.saved == true)
	end
end

-- The Reload button of the line, for the test.
function LS.ReloadButton()
	return notice and notice.button or nil
end

local function Changed()
	LS.Invalidate()
	ShowNotice()
end

local function DropWrites()
	local any = false
	for name, item in pairs(pending) do
		if not item.release then
			pending[name] = nil
			any = true
		end
	end
	if next(wr.pending) ~= nil then
		wr.pending = {}
		any = true
	end
	if flat.want then
		flat.want = false
		any = true
	end
	if next(wr.unwrite) ~= nil then
		-- A preset holds nothing of a writer, so there is nothing to put back.
		wr.unwrite = {}
		any = true
	end
	if any then
		Changed()
	end
end

-- The bars Edit Mode did not keep: the ones queued in this batch that the layout in use does not hold, and every bar that was written into the
-- Flat UI layout (the batch can be empty when the check runs before the bars are queued).
local function MarkRefusedBars(entry, batch)
	for name, item in pairs(batch) do
		local row, target = LS.Entry(entry, item.frame), Target(item.frame, item.spot)
		if row and target and not LS.Agrees(row, target) then
			refused[name], flat.bars[name] = true, true
			kept[name] = nil
		end
	end
	local records = Records()
	local enum = Enum and Enum.EditModeLayoutType
	local list = records and enum and records[tostring(enum.Character) .. ":" .. FLAT]
	for name, record in pairs(list or {}) do
		if type(record) == "table" and type(record.wrote) == "table" then
			refused[name], flat.bars[name] = true, true
			kept[name] = nil
		end
	end
end

-- The check after a reload, done once at the first flush. When a click made the Flat UI layout, the layout in use is that layout and no preset, or
-- Edit Mode did not keep it, and the refusal is saved. A saved refusal comes back as the state "refused" until the layout in use is Flat UI or
-- movers.presetLayout is not what it was.
function LS.CheckAfterReload(entry, isPreset, batch)
	flat.checked = true
	local char = ns.Character()
	local saved = type(char) == "table" and type(char.flatLayout) == "table" and char.flatLayout or nil
	if not saved then
		return
	end
	local inFlat = not isPreset and Name(entry) == FLAT
	if saved.tried == true then
		saved.tried = nil
		if inFlat then
			flat.state = "kept"
			return
		end
		SaveRefusal()
		MarkRefusedBars(entry, batch)
		return
	end
	if saved.refused == true then
		if inFlat then
			flat.state = "kept"
			ClearRefusal()
		elseif saved.mode ~= ns.Get("movers.presetLayout") then
			ClearRefusal()
		elseif isPreset then
			flat.state, flat.refusedMode = "refused", saved.mode
			MarkRefusedBars(entry, batch)
		end
	end
end

-- Evaluates the frames that were queued: a row that does not hold the spot becomes a pending write, to be saved by the Reload button. Nothing is
-- saved here and no field of the layout is changed. A flush with no frame queued is for the writers and for the check after a reload.
local function Flush()
	queued = false
	local again = flat.recheck
	if next(queue) == nil and not again and not LS.CheckDue() then
		return
	end
	if InCombatLockdown() then
		if not waiting then
			waiting = true
			if next(queue) == nil then
				flat.recheck = true
			end
			ns.OutOfCombat(function()
				waiting = false
				if (next(queue) ~= nil or flat.recheck or LS.CheckDue()) and not queued then
					queued = true
					Soon(Flush)
				end
			end)
		end
		return
	end
	flat.recheck = false
	local batch = queue
	queue = {}
	LS.Invalidate()
	if ns.EditModeOpen() then
		flat.recheck = flat.recheck or again
		return
	end
	local info, count, entry = Load()
	if not info then
		preset = nil
		DropWrites()
		return
	end
	local isPreset = IsPreset(entry, info.activeLayout, count)
	local setting = ns.Get("movers.presetLayout")
	if flat.setting ~= nil and flat.setting ~= setting then
		-- The player changed what a preset gets: every frame is looked at again.
		for name, item in pairs(flat.seen) do
			batch[name] = batch[name] or item
		end
	end
	flat.setting = setting
	if not flat.checked then
		LS.CheckAfterReload(entry, isPreset, batch)
	end
	if flat.state == "refused" and flat.refusedMode ~= ns.Get("movers.presetLayout") then
		flat.state = nil
		ClearRefusal()
	end
	local copyNow = false
	if isPreset then
		flat.presetName = Name(entry)
		flat.existing = LS.FlatIndex(info, count) ~= nil
		if flat.existing and flat.state ~= "refused" then
			flat.state = "elsewhere"
		end
		copyNow = ns.Get("movers.presetLayout") == "make" and flat.state ~= "refused" and not LS.IsGamepad(entry)
		if not copyNow then
			preset = Name(entry)
			DropWrites()
			return
		end
	elseif Name(entry) == FLAT and (flat.state == "refused" or flat.state == "elsewhere") then
		flat.state = "kept"
		ClearRefusal()
	elseif flat.state == "elsewhere" then
		flat.state = nil
	end
	preset = nil
	local tried = Tried()
	local lkey, layoutName = Key(entry), Name(entry)
	local wasWant, changed = flat.want, false
	for name, item in pairs(batch) do
		local frame = item.frame
		local row = LS.Entry(entry, frame)
		local target = Target(frame, item.spot)
		if row and target and not refused[name] then
			local id = IdOf(lkey, name, target)
			if LS.Agrees(row, target) then
				kept[name] = layoutName
				if tried then
					tried[id] = nil
				end
				if pending[name] and not pending[name].release then
					pending[name] = nil
					changed = true
				end
			elseif tried and tried[id] then
				-- Saved and reloaded before, and the row is still not the spot: Edit Mode does not take it.
				refused[name] = true
				kept[name] = nil
			else
				pending[name] = { frame = frame, spot = item.spot }
				changed = true
			end
		end
	end
	-- The writers: one that still wants a write on the layout where it was written has been refused.
	local ids = {}
	for id in pairs(wr.list) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local ok, wanted = pcall(wr.list[id].Wanted, entry)
		local mark = "writer|" .. id .. "|" .. lkey
		if ok and wanted == true then
			if tried and tried[mark] then
				wr.refused[id], wr.kept[id] = true, nil
				if wr.pending[id] then
					wr.pending[id] = nil
					changed = true
				end
			elseif not wr.pending[id] and not wr.unwrite[id] then
				wr.pending[id], wr.refused[id], wr.kept[id] = true, nil, nil
				changed = true
			end
		else
			if tried and tried[mark] then
				tried[mark] = nil
				wr.kept[id] = true
			end
			wr.refused[id] = nil
			if wr.pending[id] then
				wr.pending[id] = nil
				changed = true
			end
		end
	end
	local any = next(wr.pending) ~= nil
	for _, item in pairs(pending) do
		any = any or not item.release
	end
	if copyNow and next(wr.unwrite) ~= nil then
		if flat.existing then
			-- The click puts the settings back in the Flat UI layout that holds them.
			any = true
		else
			wr.unwrite = {}
			changed = true
		end
	end
	flat.want = copyNow and any
	if changed or flat.want ~= wasWant then
		Changed()
	end
end

-- The spot of a frame is looked at on the next frame, with every other frame queued in this one. spot is { point, x, y }: the offsets Move
-- passes, in the units of the frame.
function LS.Queue(name, frame, spot)
	queue[name] = { frame = frame, spot = spot }
	flat.seen[name] = queue[name]
	if not queued then
		queued = true
		Soon(Flush)
	end
end

-- EDIT_MODE_LAYOUTS_UPDATED. After a reload that follows a click the check is due, and it needs a flush even when no frame is queued.
function LS.Updated()
	LS.Invalidate()
	if LS.CheckDue() and not queued then
		queued = true
		Soon(Flush)
	end
end

-- A writer is added by another part of the addon: writer = { label, Wanted(layout) -> boolean, Write(layout, note) -> boolean }. Wanted only reads
-- the layout; Write changes rows of layout.systems in place, only in the click of the Reload button, and calls note(frameName, row, field, before)
-- for each setting it changes. Write returns true when it changed something, and should return true whenever Wanted is true: a Write that returns
-- false is marked tried like one that was refused, so it is not offered again after every click. An Unwrite on a preset is done only into an
-- existing Flat UI layout, and dropped otherwise. True when the writer is taken.
function LS.AddWriter(id, writer)
	if type(id) ~= "string" or type(writer) ~= "table" or type(writer.Wanted) ~= "function" or type(writer.Write) ~= "function" then
		return false
	end
	wr.list[id] = writer
	LS.Recheck()
	return true
end

-- A flush on the next frame, as Queue does, for the writers.
function LS.Recheck()
	flat.recheck = true
	if not queued then
		queued = true
		Soon(Flush)
	end
end

-- The settings a writer wrote are put back in the layout in use at the next click. True when something was written.
function LS.Unwrite(id)
	local records = Records()
	if not wr.list[id] and not LS.WroteAny(records, id) then
		return false
	end
	wr.pending[id], wr.refused[id], wr.kept[id] = nil, nil, nil
	if not LS.WroteAny(records, id) then
		return false
	end
	wr.unwrite[id] = true
	Changed()
	LS.Recheck()
	return true
end

-- "pending" while the next click writes it, "kept" once the layout holds it, "refused" when Edit Mode did not take it, nil otherwise.
function LS.WriterState(id)
	if wr.pending[id] or wr.unwrite[id] then
		return "pending"
	end
	if wr.refused[id] then
		return "refused"
	end
	if wr.kept[id] then
		return "kept"
	end
	return nil
end

-- True when a record of a write of this frame is kept for any layout.
function LS.Written(name)
	local records = Records()
	for _, list in pairs(records or {}) do
		if type(list) == "table" and list[name] then
			return true
		end
	end
	return false
end

-- Writes the spot into the row of a frame, with the record of what the row was.
local function WriteRow(records, lkey, row, name, target)
	local layoutRecords = records[lkey]
	if not layoutRecords then
		layoutRecords = {}
		records[lkey] = layoutRecords
	end
	local record = layoutRecords[name]
	if not record then
		record = { anchor = Copy(row.anchorInfo), anchor2 = Copy(row.anchorInfo2) or false, default = row.isInDefaultPosition == true }
		layoutRecords[name] = record
	end
	record.wrote = { point = target.point, relativePoint = target.point, x = target.x, y = target.y }
	row.anchorInfo = { point = target.point, relativeTo = "UIParent", relativePoint = target.point, offsetX = target.x, offsetY = target.y }
	row.anchorInfo2 = nil
	row.isInDefaultPosition = false
end

-- Puts the row of a frame back as it was before the addon wrote it, in every saved layout, when the row is still the one the addon wrote. With
-- commit false nothing of the records is dropped: it only says whether a row would change. True when a row is (or would be) put back.
local function Put(info, count, name, frame, spot, commit)
	local records = Records()
	local manager = EditModePresetLayoutManager
	local did = false
	for index = count + 1, #info.layouts do
		local layout = info.layouts[index]
		if not IsPreset(layout, index, count) then
			local lkey = Key(layout)
			local list = records and records[lkey]
			local record = list and list[name]
			local row = LS.Entry(layout, frame)
			if row then
				local ours = false
				if record and type(record.wrote) == "table" then
					ours = LS.Agrees(row, record.wrote)
				elseif not record and spot and index == info.activeLayout then
					local target = Target(frame, spot)
					ours = target ~= nil and LS.Agrees(row, target)
				end
				if ours then
					if record then
						row.anchorInfo = Copy(record.anchor)
						row.anchorInfo2 = record.anchor2 or nil
						row.isInDefaultPosition = record.default == true
						did = true
					else
						local ok, default = pcall(manager.GetDefaultSystemAnchorInfo, manager, row.system, row.systemIndex)
						if ok and type(default) == "table" then
							row.anchorInfo = default
							row.anchorInfo2 = nil
							row.isInDefaultPosition = true
							did = true
						end
					end
				end
			end
			if commit and record then
				list[name] = nil
				if next(list) == nil then
					records[lkey] = nil
				end
			end
		end
	end
	return did
end

-- Why a preset cannot be copied into the Flat UI layout, or nil when it can: the lines Apply prints.
function LS.CopyRefusal(info, count, entry, existing)
	if LS.IsGamepad(entry) then
		return "A gamepad layout is not copied."
	end
	if not (C_EditMode and type(C_EditMode.SetActiveLayout) == "function" and type(C_EditMode.IsValidLayoutName) == "function") then
		return "Edit Mode cannot make a layout here."
	end
	if existing then
		return nil
	end
	local ok, valid = pcall(C_EditMode.IsValidLayoutName, FLAT)
	if not ok or valid ~= true then
		return "Edit Mode cannot make a layout here."
	end
	local characters = 0
	for index = count + 1, #info.layouts do
		if type(info.layouts[index]) == "table" and LS.IsCharacter(info.layouts[index]) then
			characters = characters + 1
		end
	end
	if characters >= 5 then
		return "Edit Mode has five character layouts. Delete one to make the Flat UI layout."
	end
	return nil
end

-- The press of the Reload button: saves every pending write and release in one SaveLayouts call, on the layout in use as it is now. The only call of
-- SaveLayouts in the addon. On a preset with the Flat UI layout wanted it saves a layout of the addon's own made from the preset (or the one made
-- before) and makes it the layout in use. True when the interface can be reloaded: the layout was saved, or nothing was waiting.
function LS.Apply()
	if next(pending) == nil and next(wr.pending) == nil and next(wr.unwrite) == nil then
		return true
	end
	if InCombatLockdown() then
		print("Reload is for after the fight.")
		return false
	end
	if ns.EditModeOpen() then
		print("Close Edit Mode first.")
		return false
	end
	local info, count, entry = Load()
	local records = Records()
	if not info or not records then
		return false
	end
	local presetLayout = IsPreset(entry, info.activeLayout, count)
	local makeFlat = presetLayout and flat.want
	local existing = makeFlat and LS.FlatIndex(info, count) or nil
	if makeFlat then
		local why = LS.CopyRefusal(info, count, entry, existing)
		if why then
			print(why)
			return false
		end
	end
	local list, wlist, ulist = pending, wr.pending, wr.unwrite
	pending, wr.pending, wr.unwrite = {}, {}, {}
	local layout, index = entry, info.activeLayout
	if makeFlat then
		if existing then
			layout, index = info.layouts[existing], existing
		else
			layout = LS.DeepCopy(entry)
			layout.layoutName, layout.layoutType = FLAT, Enum.EditModeLayoutType.Character
			index = #info.layouts + 1
			info.layouts[index] = layout
		end
	end
	local lkey, layoutName = Key(layout), Name(layout)
	local writable = makeFlat or not presetLayout
	local changed, wrote, wroteBy, noWrite = makeFlat, {}, {}, {}
	for name, item in pairs(list) do
		if item.release then
			if Put(info, count, name, item.frame, item.spot, true) then
				changed = true
			end
		elseif writable then
			local row = LS.Entry(layout, item.frame)
			local target = Target(item.frame, item.spot)
			if row and target and not LS.Agrees(row, target) then
				WriteRow(records, lkey, row, name, target)
				changed = true
				wrote[name] = target
			end
		end
	end
	local ids = {}
	for id in pairs(wlist) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	if writable then
		for _, id in ipairs(ids) do
			local writer = wr.list[id]
			if writer then
				local ok, did = pcall(writer.Write, layout, LS.Noter(records, lkey, id))
				if ok and did == true then
					changed = true
					wroteBy[id] = true
				else
					noWrite[id] = true
				end
			end
		end
		for id in pairs(ulist) do
			if LS.PutBack(records, layout, id) then
				changed = true
			end
		end
	end
	local triedNow = Tried()
	for id in pairs(noWrite) do
		if triedNow then
			triedNow["writer|" .. id .. "|" .. lkey] = true
		end
	end
	if not changed then
		Changed()
		return true
	end
	flat.checked = true
	if makeFlat then
		info.activeLayout = index
	end
	local ok = pcall(C_EditMode.SaveLayouts, info)
	if not ok then
		if makeFlat then
			if not existing then
				records[lkey] = nil
			end
			SaveRefusal()
			flat.want = false
			print("Edit Mode did not take the Flat UI layout.")
		else
			for name in pairs(wrote) do
				refused[name] = true
				kept[name] = nil
			end
			for id in pairs(wroteBy) do
				wr.refused[id] = true
			end
			print("Edit Mode did not take the saved bar positions.")
		end
		Changed()
		return false
	end
	if makeFlat then
		pcall(C_EditMode.SetActiveLayout, index)
		flat.want = false
		local char = ns.Character()
		if type(char) == "table" then
			char.flatLayout = { tried = true }
		end
	end
	local tried = Tried()
	for name, target in pairs(wrote) do
		kept[name] = layoutName
		if tried then
			tried[IdOf(lkey, name, target)] = true
		end
	end
	for id in pairs(wroteBy) do
		wr.kept[id] = nil
		if tried then
			tried["writer|" .. id .. "|" .. lkey] = true
		end
	end
	if notice then
		notice.saved = true
	end
	Changed()
	return true
end

-- A frame is put back as it was before the addon wrote it, after the next reload, when the row is still the row the addon wrote: with no record it
-- goes back to Edit Mode's default for the frame. The record is dropped when the layout is saved. True when the layout puts the frame back (after a
-- reload), false when nothing of it was written.
function LS.Release(name, frame, spot)
	local had = LS.Written(name)
	refused[name], kept[name], queue[name], pending[name], flat.seen[name] = nil, nil, nil, nil, nil
	local did = false
	local info, count = Load()
	if info then
		did = Put(info, count, name, frame, spot, false)
		if not did and had then
			-- No row of the layout is the one that was written: only the record is dropped.
			Put(info, count, name, frame, spot, true)
		end
	elseif had then
		LS.Forget(name)
	end
	if did then
		pending[name] = { frame = frame, spot = spot, release = true }
	end
	Changed()
	return had or did
end

-- A frame whose spot was changed in Edit Mode: its record is dropped for the layout in use and nothing is written over what the player did.
function LS.Forget(name)
	kept[name], queue[name], pending[name], flat.seen[name] = nil, nil, nil, nil
	Changed()
	local records = Records()
	if not records then
		return
	end
	local info, _, entry = Load()
	if info then
		local list = records[Key(entry)]
		if list then
			list[name] = nil
			if next(list) == nil then
				records[Key(entry)] = nil
			end
		end
		return
	end
	for lkey, list in pairs(records) do
		if type(list) == "table" then
			list[name] = nil
			if next(list) == nil then
				records[lkey] = nil
			end
		end
	end
end

-- Lines for /flatui status.
function LS.Status()
	local lines = {}
	local byLayout = {}
	for name, layoutName in pairs(kept) do
		if not refused[name] then
			local list = byLayout[layoutName] or {}
			byLayout[layoutName] = list
			list[#list + 1] = ns.MoverLabel(name) or name
		end
	end
	local later = {}
	for name, item in pairs(pending) do
		if not item.release then
			later[#later + 1] = ns.MoverLabel(name) or name
		end
	end
	if #later > 0 then
		table.sort(later)
		lines[#lines + 1] = ("Kept in the Edit Mode layout after a reload: %s."):format(table.concat(later, ", "))
	end
	for layoutName, labels in pairs(byLayout) do
		table.sort(labels)
		lines[#lines + 1] = ("Kept in the Edit Mode layout %s: %s."):format(layoutName, table.concat(labels, ", "))
	end
	if flat.state == "refused" then
		lines[#lines + 1] = "Edit Mode did not keep the Flat UI layout, so moved bars go back to the game's spot in a fight."
		if type(ns.LayoutTextShow) == "function" then
			lines[#lines + 1] = "The layout is offered as import text under Movers, Edit Mode layout as text."
		end
	elseif flat.state == "elsewhere" and not preset and flat.presetName and ns.Get("movers.presetLayout") == "make" then
		lines[#lines + 1] = ("Edit Mode layout %s is a preset. Choose Flat UI in Edit Mode to keep moved bars in a fight."):format(flat.presetName)
	end
	if preset and flat.state ~= "refused" then
		lines[#lines + 1] = ("Edit Mode layout %s is a preset: moved bars go back to the game's spot in a fight. Copy the layout in Edit Mode to keep them."):format(preset)
	end
	for id in pairs(wr.refused) do
		local writer = wr.list[id]
		lines[#lines + 1] = ("%s: Edit Mode did not take it."):format(writer and writer.label or id)
	end
	for name in pairs(refused) do
		lines[#lines + 1] = ("%s: Edit Mode did not take the saved spot, so it goes back to the game's spot in a fight."):format(ns.MoverLabel(name) or name)
	end
	table.sort(lines)
	return lines
end

-- The layout the Reload click would save as Flat UI: a copy of the Flat UI layout when there is one, else of the layout in use, with the pending
-- rows and the writers applied to the copy. Nothing is saved and nothing of the game's data is changed. Nil and why: "combat", "editmode",
-- "unavailable" (the data is missing, or the layout is for the gamepad interface).
function LS.FlatEntry()
	local _, why = LS.Resolve()
	if why == "combat" or why == "editmode" then
		return nil, why
	end
	local info, count, entry = Load()
	if not info or LS.IsGamepad(entry) then
		return nil, "unavailable"
	end
	local index = LS.FlatIndex(info, count)
	local copy = LS.DeepCopy(index and info.layouts[index] or entry)
	copy.layoutName = FLAT
	copy.layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character or copy.layoutType
	local scratch = {}
	local lkey = Key(copy)
	for name, item in pairs(pending) do
		if not item.release then
			local row, target = LS.Entry(copy, item.frame), Target(item.frame, item.spot)
			if row and target then
				WriteRow(scratch, lkey, row, name, target)
			end
		end
	end
	local ids = {}
	for id in pairs(wr.pending) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		if wr.list[id] then
			pcall(wr.list[id].Write, copy, LS.Noter(scratch, lkey, id))
		end
	end
	return copy
end
