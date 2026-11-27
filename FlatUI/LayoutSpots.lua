local _, ns = ...

local LS = {}
ns.LayoutSpots = LS

local TOLERANCE = 0.1
local MODE_FOR = 0.5

local queue, queued, waiting = {}, false, false
local pending, refused, kept = {}, {}, {}
local mode = { at = nil, value = nil, name = nil }
local preset = nil
local FLAT = "Flat UI"
local flat = { want = false, state = nil, checked = false, recheck = false, presetName = nil, existing = false, refusedMode = nil, seen = {}, setting = nil, bars = {} }
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

function LS.Agrees(row, spot)
	local anchor = type(row) == "table" and row.anchorInfo
	if type(anchor) ~= "table" or row.anchorInfo2 ~= nil or row.isInDefaultPosition ~= false or type(spot) ~= "table" then
		return false
	end
	return anchor.point == spot.point and anchor.relativeTo == "UIParent" and anchor.relativePoint == (spot.relativePoint or spot.point)
		and type(anchor.offsetX) == "number" and type(anchor.offsetY) == "number"
		and math.abs(anchor.offsetX - spot.x) <= TOLERANCE and math.abs(anchor.offsetY - spot.y) <= TOLERANCE
end

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

function LS.IsGamepad(layout)
	local enum = Enum and Enum.InputDeviceInterfaceType
	return type(layout) == "table" and enum ~= nil and enum.Gamepad ~= nil and layout.interfaceStyle == enum.Gamepad
end

function LS.IsCharacter(layout)
	local enum = Enum and Enum.EditModeLayoutType
	return enum ~= nil and layout.layoutType == enum.Character
end

function LS.FlatIndex(info, count)
	for index = count + 1, #info.layouts do
		local layout = info.layouts[index]
		if type(layout) == "table" and Name(layout) == FLAT and LS.IsCharacter(layout) then
			return index
		end
	end
	return nil
end

function LS.FlatState()
	return flat.state
end

function LS.CheckDue()
	local char = ns.Character()
	return not flat.checked and type(char) == "table" and type(char.flatLayout) == "table" and (char.flatLayout.tried == true or char.flatLayout.refused == true)
end

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

function LS.WroteAny(records, id)
	for _, list in pairs(records or {}) do
		if type(list) == "table" and type(list.by) == "table" and list.by[id] and next(list.by[id]) ~= nil then
			return true
		end
	end
	return false
end

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

local notice = nil

local function Click()
	if type(ns.ReloadIsForever) == "function" and ns.ReloadIsForever() then
		ns.Reload()
		return
	end
	if LS.Apply() then
		ns.Reload()
	end
end

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
			local okWidth, width = pcall(notice.text.GetStringWidth, notice.text)
			if okWidth and Plain(width) and type(width) == "number" then
				notice.frame:SetWidth(math.max(330, math.ceil(width) + 90))
			end
		end
		notice.frame:SetShown(wanted or notice.saved == true)
	end
end

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
		wr.unwrite = {}
		any = true
	end
	if any then
		Changed()
	end
end

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
				refused[name] = true
				kept[name] = nil
			else
				pending[name] = { frame = frame, spot = item.spot }
				changed = true
			end
		end
	end
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

function LS.Queue(name, frame, spot)
	queue[name] = { frame = frame, spot = spot }
	flat.seen[name] = queue[name]
	if not queued then
		queued = true
		Soon(Flush)
	end
end

function LS.Updated()
	LS.Invalidate()
	if LS.CheckDue() and not queued then
		queued = true
		Soon(Flush)
	end
end

function LS.AddWriter(id, writer)
	if type(id) ~= "string" or type(writer) ~= "table" or type(writer.Wanted) ~= "function" or type(writer.Write) ~= "function" then
		return false
	end
	wr.list[id] = writer
	LS.Recheck()
	return true
end

function LS.Recheck()
	flat.recheck = true
	if not queued then
		queued = true
		Soon(Flush)
	end
end

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

function LS.Written(name)
	local records = Records()
	for _, list in pairs(records or {}) do
		if type(list) == "table" and list[name] then
			return true
		end
	end
	return false
end

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

function LS.Release(name, frame, spot)
	local had = LS.Written(name)
	refused[name], kept[name], queue[name], pending[name], flat.seen[name] = nil, nil, nil, nil, nil
	local did = false
	local info, count = Load()
	if info then
		did = Put(info, count, name, frame, spot, false)
		if not did and had then
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
