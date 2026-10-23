local _, ns = ...

-- Movers mode: what the player sees while the handles of Movers.lua are open. A dim and a grid behind the frames, a toolbar at the top, a list of
-- the frames at the left and an inspector with the X and Y of the chosen frame at the right. The handles themselves are Movers.lua's; this file
-- gives them their look and keeps what was done in a session (the spots at the start, the steps for Undo, the handles hidden by the eye). The
-- options window is hidden while the session lasts and comes back with it. Movers.lua hands over through the calls it makes on ns.MoversMode and
-- is read through ns.MoverKit. Every colour and size is a token of PanelLook.lua.

local MM = {}
ns.MoversMode = MM

local KEY = "movers"
local GRID = 32
local GRID_ALPHA, CENTRE_ALPHA = { dim = 0.12, bright = 0.25 }, 0.4
local BAR_W, BAR_H = 560, 40
local LIST_W, LIST_H, ROW_H, LIST_TOP = 240, 400, 24, 66
local SIDE_W, SIDE_H = 224, 196
local STEPS_KEPT, SHIFT_STEP = 100, 10
local GROUPS = { "Unit frames", "Action bars", "Flat UI", "Windows", "Other" }
local UNITS = { PlayerFrame = true, TargetFrame = true, FocusFrame = true, PetFrame = true, PartyFrame = true, CompactRaidFrameContainer = true,
	BossTargetFrameContainer = true }
local BARS = { MainActionBar = true, MultiBarBottomLeft = true, MultiBarBottomRight = true, MultiBarRight = true, MultiBarLeft = true, MultiBar5 = true,
	MultiBar6 = true, MultiBar7 = true, StanceBar = true, PetActionBar = true, PossessActionBar = true, MultiCastActionBarFrame = true }
local ARROWS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 50, 200, 5
local WINDOW_MIN, WINDOW_MAX = 60, 150
local TRACK_W = 80

-- The session: spots at the start (snapshot), the last seen spot of each frame (last), the steps for Undo, the handles hidden by the eye,
-- the chosen frame and the handle under the cursor. paused: the session waits for the end of a fight. panel: the options window was open.
local S = { snapshot = {}, last = {}, undo = {}, hidden = {}, list = true, texts = {} }
-- The frames this file makes and what they show.
local ui = { lines = {}, paints = {}, rows = {} }

local function Kit()
	return ns.MoverKit
end

local function Look()
	return ns.PanelLook
end

local function Try(fn, ...)
	return ns.Try(KEY, fn, ...)
end

-- Spots ----------------------------------------------------------------------------------------------

local function Copy(entry)
	if type(entry) ~= "table" then
		return nil
	end
	return { point = entry.point, x = entry.x, y = entry.y, scale = entry.scale, kind = entry.kind, label = entry.label }
end

local function Same(a, b)
	if a == nil or b == nil then
		return a == b
	end
	return a.point == b.point and math.abs(a.x - b.x) < 0.001 and math.abs(a.y - b.y) < 0.001 and a.scale == b.scale
end

local function CopyAll(saved)
	local all = {}
	for name, entry in pairs(saved or {}) do
		all[name] = Copy(entry)
	end
	return all
end

-- The names whose spot is not what it was when the session began.
local function Differing()
	local saved, names = Kit().Saved() or {}, {}
	for name, entry in pairs(saved) do
		if not Same(Copy(entry), S.snapshot[name]) then
			names[#names + 1] = name
		end
	end
	for name in pairs(S.snapshot) do
		if saved[name] == nil then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- A step for Undo is added when the spot of a frame is not the one last seen. Movers.lua calls this from every place that changes a spot.
function MM.Changed(name)
	if not (S.session and not S.undoing and not S.muted and name) then
		return
	end
	local now = Copy((Kit().Saved() or {})[name])
	if not Same(now, S.last[name]) then
		S.undo[#S.undo + 1] = { name, S.last[name] or false }
		if #S.undo > STEPS_KEPT then
			table.remove(S.undo, 1)
		end
		S.last[name] = now
	end
end

-- Movers.lua mutes the spot it saves for Ctrl and scroll on a frame with none, so that action is one step for Undo.
function MM.Mute(on)
	S.muted = on == true
end

-- The saved spot of a frame was dropped by the game (an Edit Mode change): there is no step to undo, and the last seen spot is gone.
function MM.Forget(name)
	S.last[name] = nil
end

-- The profile in use changed: the session starts again from the spots of the new one.
function MM.ProfileChanged()
	if not S.session then
		return
	end
	local saved = Kit().Saved()
	S.snapshot, S.last, S.undo = CopyAll(saved), CopyAll(saved), {}
	if ui.list then
		MM.Layout()
		MM.Refresh(true)
	end
end

function MM.Undo()
	local step = table.remove(S.undo)
	if not step then
		return
	end
	S.undoing = true
	Kit().Restore(step[1], step[2] or nil)
	S.undoing = false
	S.last[step[1]] = Copy((Kit().Saved() or {})[step[1]])
	MM.Select(step[1])
	MM.Refresh(true)
end

-- Puts every spot back as it was when the session began.
function MM.Discard()
	S.undoing = true
	for _, name in ipairs(Differing()) do
		Kit().Restore(name, S.snapshot[name])
	end
	S.undoing = false
	S.undo, S.last = {}, CopyAll(Kit().Saved())
end

-- Drawing helpers -------------------------------------------------------------------------------------

local function Make(kind, parent)
	local frame = CreateFrame(kind, nil, parent or UIParent)
	ns.Own[frame] = true
	return frame
end

-- Runs when the screen is shown again, so a change of tone or accent shows.
local function Painted(fn)
	ui.paints[#ui.paints + 1] = fn
	fn()
end

local function Fill(frame, layer, token, alpha)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, 0)
	ns.Own[texture] = true
	if token then
		Painted(function()
			Look().Solid(texture, token, alpha)
		end)
	end
	return texture
end

-- A frame with a fill and, when the Borders setting says so, a hairline.
local function Surface(frame, token, edge)
	local outline = ns.Outline(frame, frame, true)
	Painted(function()
		Look().Backing(outline, token, 1, edge or "line")
	end)
	return outline
end

local function Text(parent, font, token, justify)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	local object = Look().Object(font)
	if object then
		text:SetFontObject(object)
	end
	text:SetJustifyH(justify or "LEFT")
	Painted(function()
		text:SetTextColor(Look().Colour(token or "text"))
	end)
	return text
end

local function Button(parent, text, width, onClick, primary)
	local button = Make("Frame", parent)
	button:SetSize(width, 28)
	button:EnableMouse(true)
	local outline = ns.Outline(button, button, true)
	local label = Text(button, "GameFontHighlight", primary and "on-accent" or "text", "CENTER")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText(text)
	local over, down = false, false
	local function Paint()
		local fill = primary and (down and "accent-pressed" or over and "accent-hover" or "accent") or (down and "card" or over and "hover" or "raised")
		Look().Backing(outline, fill, 1, "line-strong")
	end
	Painted(Paint)
	button:SetScript("OnEnter", function()
		over = true
		Paint()
	end)
	button:SetScript("OnLeave", function()
		over, down = false, false
		Paint()
	end)
	button:SetScript("OnMouseDown", function()
		down = true
		Paint()
	end)
	button:SetScript("OnMouseUp", function(_, mouseButton)
		down = false
		Paint()
		if mouseButton == "LeftButton" then
			Try(onClick)
		end
	end)
	return button, label
end

local function Field(parent, width, onEnter)
	local box = Make("EditBox", parent)
	box:SetSize(width, 24)
	box:SetAutoFocus(false)
	box:SetTextInsets(6, 6, 0, 0)
	box:SetMaxLetters(24)
	box:SetFontObject(Look().FontFor("GameFontHighlight"))
	local outline = ns.Outline(box, box, true)
	local focused = false
	local function Paint()
		Look().Backing(outline, "raised", 1, focused and "accent" or "line")
	end
	Painted(function()
		box:SetTextColor(Look().Colour("text"))
		Paint()
	end)
	box:SetScript("OnEditFocusGained", function()
		focused = true
		Paint()
	end)
	box:SetScript("OnEditFocusLost", function()
		focused = false
		Paint()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	if onEnter then
		box:SetScript("OnEnterPressed", function(self)
			Try(onEnter, self:GetText())
			self:ClearFocus()
		end)
	end
	return box
end

-- The grid and the dim ---------------------------------------------------------------------------------

function MM.DrawGrid()
	if not ui.screen then
		return
	end
	local width, height = Kit().ScreenSize()
	local mode = Look().Get("grid")
	local r, g, b = Look().Colour("accent")
	local key = table.concat({ tostring(width), tostring(height), mode, r, g, b }, "|")
	if ui.gridKey == key then
		return
	end
	ui.gridKey = key
	local used = 0
	if width and mode ~= "off" then
		local function Line(vertical, k)
			used = used + 1
			local line = ui.lines[used]
			if not line then
				line = ui.screen:CreateTexture(nil, "BACKGROUND", nil, 1)
				ns.Own[line] = true
				ui.lines[used] = line
			end
			line:ClearAllPoints()
			line:SetColorTexture(r, g, b, k == 0 and CENTRE_ALPHA or GRID_ALPHA[mode])
			if vertical then
				line:SetSize(1, height)
				line:SetPoint("CENTER", UIParent, "CENTER", k * GRID, 0)
			else
				line:SetSize(width, 1)
				line:SetPoint("CENTER", UIParent, "CENTER", 0, k * GRID)
			end
			line:Show()
		end
		for k = -math.floor(width / 2 / GRID), math.floor(width / 2 / GRID) do
			Line(true, k)
		end
		for k = -math.floor(height / 2 / GRID), math.floor(height / 2 / GRID) do
			Line(false, k)
		end
	end
	for index = used + 1, #ui.lines do
		ui.lines[index]:Hide()
	end
end

function MM.Resized()
	MM.DrawGrid()
end

-- Handles -----------------------------------------------------------------------------------------------

-- Colours the handle of a frame for what it is now: chosen, under the cursor, placed by the game or none of these.
function MM.Paint(name)
	local look = Kit().looks[name]
	if not look then
		return
	end
	local L = Look()
	local outline = look.outline
	local text = S.texts[name]
	if S.selected == name then
		ns.SetOutlineColour(outline, L.Colour("accent"))
		ns.SetOutlineAlpha(outline, 1)
		local r, g, b = L.Colour("accent")
		ns.SetOutlineFill(outline, r, g, b, 0.18)
	elseif look.placedByGame then
		ns.SetOutlineColour(outline, L.Colour("text-faint"))
		ns.SetOutlineAlpha(outline, 0.6)
		local r, g, b = L.Colour("window")
		ns.SetOutlineFill(outline, r, g, b, 0.25)
	else
		ns.SetOutlineColour(outline, L.Colour("text-dim"))
		ns.SetOutlineAlpha(outline, S.hover == name and 1 or 0.6)
		local r, g, b = L.Colour("window")
		ns.SetOutlineFill(outline, r, g, b, 0.45)
	end
	if text then
		text:SetTextColor(L.Colour("text"))
	end
end

-- Called when Movers.lua makes the handle of a frame.
function MM.Style(name, handle, outline, text)
	S.texts[name] = text
	local object = Look().Object("GameFontHighlightSmall")
	if object then
		text:SetFontObject(object)
	end
	ns.SetOutlineThickness(outline, 1)
	handle:SetScript("OnEnter", function()
		S.hover = name
		MM.Paint(name)
	end)
	handle:SetScript("OnLeave", function()
		if S.hover == name then
			S.hover = nil
		end
		MM.Paint(name)
	end)
	MM.Paint(name)
end

function MM.Hidden(name)
	return S.hidden[name] == true
end

function MM.Select(name)
	if S.selected == name then
		return
	end
	local was = S.selected
	S.selected = name
	if was then
		MM.Paint(was)
	end
	if name then
		MM.Paint(name)
	end
	MM.Layout()
	MM.Refresh(true)
end

-- Moves the chosen frame by whole units. True when it moved.
local function Nudge(dx, dy)
	local name = S.selected
	local kit = Kit()
	local look = name and kit.looks[name]
	local handle = name and kit.handles[name]
	local info = name and kit.Describe(name)
	if not (look and look.shown and not look.placedByGame and handle and info) then
		return false
	end
	local left, bottom, width, height = kit.Rect(handle)
	if not left then
		return false
	end
	kit.Commit(name, info, left + dx, bottom + dy, width, height)
	kit.ShowHandle(name)
	MM.Refresh(true)
	return true
end

-- The inspector -----------------------------------------------------------------------------------------

-- The middle of the chosen handle, from the middle of the screen.
local function Centre(name)
	local kit = Kit()
	local look = kit.looks[name]
	local handle = kit.handles[name]
	if not (look and look.shown and handle) then
		return nil
	end
	local left, bottom, width, height = kit.Rect(handle)
	local sw, sh = kit.ScreenSize()
	if not (left and sw) then
		return nil
	end
	return left + width / 2 - sw / 2, bottom + height / 2 - sh / 2
end

local function Rounded(value)
	return math.floor(value + 0.5)
end

-- Puts the middle of the chosen frame at x, y from the middle of the screen. nil keeps that axis.
local function Place(x, y)
	local name = S.selected
	local kit = Kit()
	local handle = name and kit.handles[name]
	local info = name and kit.Describe(name)
	local sw, sh = kit.ScreenSize()
	if not (handle and info and sw and kit.Readable(name) and not (kit.looks[name] or {}).placedByGame) then
		return
	end
	local left, bottom, width, height = kit.Rect(handle)
	if not left then
		return
	end
	if x then
		left = sw / 2 + x - width / 2
	end
	if y then
		bottom = sh / 2 + y - height / 2
	end
	kit.Commit(name, info, left, bottom, width, height)
	kit.ShowHandle(name)
	MM.Refresh(true)
end

local function ScaleOf(name)
	local entry = (Kit().Saved() or {})[name]
	return type(entry) == "table" and entry.scale and Rounded(entry.scale * 100) or 100
end

local function SetScale(percent)
	local name = S.selected
	local info = name and Kit().Describe(name)
	percent = tonumber(percent)
	if not (info and percent) or info.noScale then
		MM.Refresh(true)
		return
	end
	local low, high = SCALE_MIN, SCALE_MAX
	if info.kind == "window" then
		low, high = WINDOW_MIN, WINDOW_MAX
	end
	percent = math.max(low, math.min(high, Rounded(percent / SCALE_STEP) * SCALE_STEP))
	ns.SetMoverScale({ frame = name }, percent)
	MM.Refresh(true)
end

local function BuildInspector()
	local panel = Make("Frame")
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetFrameLevel(20)
	panel:SetSize(SIDE_W, SIDE_H)
	panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -64)
	panel:EnableMouse(true)
	Surface(panel, "card")
	ui.side = panel
	ui.sideTitle = Text(panel, "GameFontNormal", "text")
	ui.sideTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
	ui.sideTitle:SetWidth(SIDE_W - 24)
	ui.sideNone = Text(panel, "GameFontHighlightSmall", "text-dim")
	ui.sideNone:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -38)
	ui.sideNone:SetText("Select a frame.")
	local body = Make("Frame", panel)
	body:SetAllPoints(panel)
	ui.sideBody = body
	local function Label(text, x, y)
		local label = Text(body, "GameFontHighlightSmall", "text-dim")
		label:SetPoint("TOPLEFT", body, "TOPLEFT", x, y)
		label:SetText(text)
		return label
	end
	Label("X", 12, -36)
	ui.x = Field(body, 64, function(text)
		local value = tonumber(text)
		if value then
			Place(value, nil)
		end
	end)
	ui.x:SetPoint("TOPLEFT", body, "TOPLEFT", 34, -32)
	Label("Y", 112, -36)
	ui.y = Field(body, 64, function(text)
		local value = tonumber(text)
		if value then
			Place(nil, value)
		end
	end)
	ui.y:SetPoint("TOPLEFT", body, "TOPLEFT", 134, -32)
	Label("Scale", 12, -70)
	-- The track takes a press anywhere on it and follows the cursor while the button is held.
	local track = Make("Frame", body)
	track:SetSize(TRACK_W, 20)
	track:SetPoint("TOPLEFT", body, "TOPLEFT", 76, -68)
	track:EnableMouse(true)
	local groove = Fill(track, "BACKGROUND", "raised")
	groove:SetPoint("LEFT", track, "LEFT", 0, 0)
	groove:SetSize(TRACK_W, 4)
	local bar = Fill(track, "ARTWORK", "accent")
	bar:SetPoint("LEFT", track, "LEFT", 0, 0)
	bar:SetSize(1, 4)
	ui.track, ui.trackBar = track, bar
	local function FromCursor()
		local x = Kit().Cursor()
		local left = Kit().Rect(track)
		if x and left then
			SetScale(SCALE_MIN + math.max(0, math.min(1, (x - left) / TRACK_W)) * (SCALE_MAX - SCALE_MIN))
		end
	end
	local function Stop()
		ui.sliding = false
		track:SetScript("OnUpdate", nil)
	end
	track:SetScript("OnMouseDown", function()
		ui.sliding = true
		Try(FromCursor)
		track:SetScript("OnUpdate", function()
			if ui.sliding then
				Try(FromCursor)
			end
		end)
	end)
	track:SetScript("OnMouseUp", Stop)
	track:SetScript("OnHide", Stop)
	ui.scale = Field(body, 48, function(text)
		SetScale((text:gsub("%%", "")))
	end)
	ui.scale:SetPoint("TOPLEFT", body, "TOPLEFT", 164, -66)
	local centre = Button(body, "Centre", 96, function()
		if S.selected and Kit().Centre(S.selected) then
			MM.Refresh(true)
		end
	end)
	centre:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -152)
	local reset = Button(body, "Reset", 96, function()
		local name = S.selected
		if name and (Kit().Saved() or {})[name] then
			Kit().Restore(name, nil)
			MM.Refresh(true)
		end
	end)
	reset:SetPoint("TOPLEFT", body, "TOPLEFT", 116, -152)
end

-- The numbers of the chosen frame, the chip over its handle and the buttons that depend on it. force writes a field that has the cursor too.
function MM.Refresh(force)
	if not (ui.side and S.session) then
		return
	end
	local kit = Kit()
	local name = S.selected
	local info = name and kit.Describe(name)
	local look = name and kit.looks[name]
	ui.sideBody:SetShown(info ~= nil)
	ui.sideNone:SetShown(info == nil)
	ui.sideTitle:SetText(info and info.label or "Inspector")
	local readable = info ~= nil and kit.Readable(name) and look ~= nil and look.shown == true and not look.placedByGame
	local x, y
	if readable then
		x, y = Centre(name)
	end
	if info then
		ui.x:EnableMouse(readable)
		ui.y:EnableMouse(readable)
		if readable and x then
			if force or not ui.x:HasFocus() then
				ui.x:SetText(tostring(Rounded(x)))
			end
			if force or not ui.y:HasFocus() then
				ui.y:SetText(tostring(Rounded(y)))
			end
		else
			ui.x:SetText("Not available")
			ui.y:SetText("Not available")
		end
		local percent = ScaleOf(name)
		if force or not ui.scale:HasFocus() then
			ui.scale:SetText(percent .. "%")
		end
		ui.trackBar:SetWidth(math.max(1, TRACK_W * (percent - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)))
		ui.track:EnableMouse(not info.noScale)
		ui.trackBar:SetShown(not info.noScale)
	end
	-- The chip over the chosen handle says where it is.
	local handle = info and kit.handles[name]
	if handle and readable and x then
		ui.chipText:SetText(("X %d  Y %d"):format(Rounded(x), Rounded(y)))
		ui.chip:SetWidth(ui.chipText:GetStringWidth() + 16)
		ui.chip:ClearAllPoints()
		ui.chip:SetPoint("BOTTOM", handle, "TOP", 0, 4)
		ui.chip:Show()
	else
		ui.chip:Hide()
	end
	ui.undoLabel:SetAlpha(#S.undo > 0 and 1 or 0.4)
end

-- The frame list ----------------------------------------------------------------------------------------

local function GroupOf(info)
	if info.kind == "window" then
		return "Windows"
	elseif info.name == "FlatUIBarBlock" then
		return "Action bars"
	elseif info.own then
		return "Flat UI"
	elseif UNITS[info.name] then
		return "Unit frames"
	elseif BARS[info.name] then
		return "Action bars"
	end
	return "Other"
end

-- The rows of the list: a header for each group that has a frame, then the frames. Every listed frame is here, with or without a handle now.
local function Entries()
	local kit = Kit()
	local filter = (ui.search and ui.search:GetText() or ""):lower()
	local names = {}
	for _, info in ipairs(kit.LIST) do
		names[#names + 1] = info.name
	end
	local extra = {}
	for name in pairs(kit.Saved() or {}) do
		if not kit.BY_NAME[name] then
			extra[#extra + 1] = name
		end
	end
	table.sort(extra)
	for _, name in ipairs(extra) do
		names[#names + 1] = name
	end
	local groups = {}
	for _, group in ipairs(GROUPS) do
		groups[group] = {}
	end
	for _, name in ipairs(names) do
		local info = kit.Describe(name)
		if info and (filter == "" or info.label:lower():find(filter, 1, true)) then
			local list = groups[GroupOf(info)]
			list[#list + 1] = { name = name, label = info.label }
		end
	end
	local entries = {}
	for _, group in ipairs(GROUPS) do
		if #groups[group] > 0 then
			entries[#entries + 1] = { head = group }
			for _, entry in ipairs(groups[group]) do
				entries[#entries + 1] = entry
			end
		end
	end
	return entries
end

local function RowCount()
	return math.floor((LIST_H - LIST_TOP - 6) / ROW_H)
end

local function BuildRow(index)
	local row = Make("Frame", ui.list)
	row:SetSize(LIST_W - 12, ROW_H)
	row:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 6, -(LIST_TOP + (index - 1) * ROW_H))
	row:EnableMouse(true)
	row:EnableMouseWheel(true)
	row.back = Fill(row, "BACKGROUND")
	row.back:SetAllPoints(row)
	row.label = Text(row, "GameFontHighlight", "text-dim")
	row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.label:SetWidth(LIST_W - 12 - 44)
	row.eye = Make("Frame", row)
	row.eye:SetSize(14, 14)
	row.eye:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.eye:EnableMouse(true)
	row.icon = row.eye:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[row.icon] = true
	row.icon:SetAllPoints(row.eye)
	ns.PanelNav.Cell(row.icon, "eye")
	row:SetScript("OnEnter", function()
		row.over = true
		MM.Layout()
	end)
	row:SetScript("OnLeave", function()
		row.over = false
		MM.Layout()
	end)
	row:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" and row.entry and row.entry.name then
			Try(MM.Select, row.entry.name)
		end
	end)
	row.eye:SetScript("OnMouseUp", function(_, mouseButton)
		local name = row.entry and row.entry.name
		if mouseButton == "LeftButton" and name then
			S.hidden[name] = not S.hidden[name] or nil
			Try(Kit().ShowHandle, name)
			MM.Layout()
			MM.Refresh(true)
		end
	end)
	row:SetScript("OnMouseWheel", function(_, delta)
		MM.Scroll(delta > 0 and -3 or 3)
	end)
	ui.rows[index] = row
	return row
end

function MM.Scroll(by)
	S.offset = (S.offset or 0) + by
	MM.Layout()
end

-- Shows the visible part of the list.
function MM.Layout()
	if not ui.list then
		return
	end
	ui.entries = Entries()
	local count = RowCount()
	S.offset = math.max(0, math.min(math.max(0, #ui.entries - count), S.offset or 0))
	local L = Look()
	for index = 1, count do
		local row = ui.rows[index] or BuildRow(index)
		local entry = ui.entries[S.offset + index]
		row.entry = entry
		row:SetShown(entry ~= nil)
		if entry then
			row.label:SetText(entry.head or entry.label)
			if entry.head then
				row.back:SetColorTexture(0, 0, 0, 0)
				row.label:SetTextColor(L.Colour("text-faint"))
			else
				local chosen = S.selected == entry.name
				local fill = chosen and "raised" or row.over and "hover" or nil
				if fill then
					L.Solid(row.back, fill)
				else
					row.back:SetColorTexture(0, 0, 0, 0)
				end
				row.label:SetTextColor(L.Colour(chosen and "text" or "text-dim"))
				row.icon:SetVertexColor(L.Colour("text-dim"))
				row.icon:SetAlpha(S.hidden[entry.name] and 0.35 or 1)
			end
			row.eye:SetShown(entry.name ~= nil)
		end
	end
	ui.empty:SetShown(#ui.entries == 0)
end

local function BuildList()
	local panel = Make("Frame")
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetFrameLevel(20)
	panel:SetSize(LIST_W, LIST_H)
	panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -64)
	panel:EnableMouse(true)
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta)
		MM.Scroll(delta > 0 and -3 or 3)
	end)
	Surface(panel, "card")
	ui.list = panel
	local title = Text(panel, "GameFontNormal", "text")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
	title:SetText("Frames")
	ui.search = Field(panel, LIST_W - 24, nil)
	ui.search:SetHeight(22)
	ui.search:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -34)
	ui.search:SetScript("OnTextChanged", function()
		S.offset = 0
		MM.Layout()
	end)
	ui.hint = Text(panel, "GameFontHighlightSmall", "text-faint")
	ui.hint:SetPoint("TOPLEFT", ui.search, "TOPLEFT", 8, -5)
	ui.hint:SetText("Find a frame")
	ui.search:SetScript("OnEditFocusGained", function()
		ui.hint:Hide()
	end)
	ui.search:SetScript("OnEditFocusLost", function(self)
		ui.hint:SetShown(self:GetText() == "")
	end)
	ui.empty = Text(panel, "GameFontHighlightSmall", "text-dim")
	ui.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -(LIST_TOP + 6))
	ui.empty:SetText("No frames.")
end

-- The toolbar -------------------------------------------------------------------------------------------

local GRID_CHOICES = { { "off", "Off" }, { "dim", "Dim" }, { "bright", "Bright" } }

local function PaintSegments()
	local L = Look()
	for _, segment in ipairs(ui.segments or {}) do
		local chosen = L.Get("grid") == segment.id
		L.Backing(segment.outline, chosen and "accent" or "card", chosen and 0.18 or 1, chosen and "accent" or "line")
		segment.label:SetTextColor(L.Colour(chosen and "text" or "text-dim"))
	end
end

local function PaintToggle()
	local on = ns.Get("movers.snap") == "middle"
	local L = Look()
	L.Solid(ui.trackBack, on and "accent" or "raised")
	L.Solid(ui.knob, on and "on-accent" or "text-dim")
	ui.knob:ClearAllPoints()
	ui.knob:SetPoint("LEFT", ui.toggle, "LEFT", on and 18 or 2, 0)
end

local function BuildToolbar()
	local bar = Make("Frame")
	bar:SetFrameStrata("FULLSCREEN_DIALOG")
	bar:SetFrameLevel(20)
	bar:SetSize(BAR_W, BAR_H)
	bar:SetPoint("TOP", UIParent, "TOP", 0, -8)
	bar:EnableMouse(true)
	Surface(bar, "card")
	ui.bar = bar
	local title = Text(bar, "GameFontNormal", "text")
	title:SetPoint("LEFT", bar, "LEFT", 12, 0)
	title:SetText("Movers")
	-- Grid: Off, Dim or Bright, kept for the account.
	local group = Make("Frame", bar)
	group:SetSize(150, 24)
	group:SetPoint("LEFT", bar, "LEFT", 76, 0)
	ui.segments = {}
	for index, choice in ipairs(GRID_CHOICES) do
		local segment = Make("Frame", group)
		segment:SetSize(50, 24)
		segment:SetPoint("LEFT", group, "LEFT", (index - 1) * 50, 0)
		segment:EnableMouse(true)
		local entry = { id = choice[1], outline = ns.Outline(segment, segment, true) }
		entry.label = Text(segment, "GameFontHighlight", "text-dim", "CENTER")
		entry.label:SetPoint("CENTER", segment, "CENTER", 0, 0)
		entry.label:SetText(choice[2])
		segment:SetScript("OnMouseUp", function(_, mouseButton)
			if mouseButton == "LeftButton" then
				Try(ns.Set, "panel.grid", choice[1])
				MM.DrawGrid()
				PaintSegments()
			end
		end)
		ui.segments[index] = entry
	end
	Painted(PaintSegments)
	local snap = Text(bar, "GameFontHighlightSmall", "text-dim")
	snap:SetPoint("LEFT", bar, "LEFT", 238, 0)
	snap:SetText("Snap")
	-- Snap: a handle or a window snaps to the middle of the screen (Snap while dragging on the Movers page).
	local toggle = Make("Frame", bar)
	toggle:SetSize(32, 16)
	toggle:SetPoint("LEFT", bar, "LEFT", 274, 0)
	toggle:EnableMouse(true)
	ui.toggle = toggle
	ui.trackBack = Fill(toggle, "BACKGROUND")
	ui.trackBack:SetAllPoints(toggle)
	ui.knob = Fill(toggle, "ARTWORK")
	ui.knob:SetSize(12, 12)
	toggle:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			Try(ns.Set, "movers.snap", ns.Get("movers.snap") == "middle" and "off" or "middle")
			PaintToggle()
		end
	end)
	Painted(PaintToggle)
	local listButton = Button(bar, "Frame list", 80, function()
		S.list = not S.list
		ui.list:SetShown(S.list)
		if S.list then
			MM.Layout()
		end
	end)
	listButton:SetPoint("LEFT", bar, "LEFT", 318, 0)
	ui.undo, ui.undoLabel = Button(bar, "Undo", 64, MM.Undo)
	ui.undo:SetPoint("LEFT", bar, "LEFT", 406, 0)
	local done = Button(bar, "Done", 70, function()
		Kit().Close()
	end, true)
	done:SetPoint("LEFT", bar, "LEFT", 478, 0)
end

-- The question when a close would leave changes ----------------------------------------------------------

local function BuildAsk()
	local shade = Make("Frame")
	shade:SetFrameStrata("FULLSCREEN_DIALOG")
	shade:SetFrameLevel(40)
	shade:SetAllPoints(UIParent)
	shade:EnableMouse(true)
	local back = shade:CreateTexture(nil, "BACKGROUND", nil, 0)
	ns.Own[back] = true
	back:SetAllPoints(shade)
	back:SetColorTexture(0, 0, 0, 0.5)
	shade:Hide()
	local box = Make("Frame", shade)
	box:SetFrameLevel(50)
	box:SetSize(400, 140)
	box:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	box:EnableMouse(true)
	Surface(box, "card", "line-strong")
	local title = Text(box, "GameFontNormal", "text")
	title:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -20)
	title:SetText("Keep your changes?")
	ui.askText = Text(box, "GameFontHighlight", "text-dim")
	ui.askText:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -48)
	ui.askText:SetWidth(360)
	local keepMoving = Button(box, "Keep moving", 100, function()
		shade:Hide()
	end)
	keepMoving:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 20, 20)
	local discard = Button(box, "Discard", 88, function()
		shade:Hide()
		MM.Discard()
		Kit().Close()
	end)
	discard:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -116, 20)
	local keep = Button(box, "Keep", 88, function()
		shade:Hide()
		Kit().Close()
	end, true)
	keep:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -20, 20)
	ui.ask = shade
end

-- A close that is not Done (the Escape key). Without changes it closes; with changes it asks once.
function MM.Request()
	local names = Differing()
	if #names == 0 then
		Kit().Close()
		return
	end
	if not ui.ask then
		BuildAsk()
	end
	ui.askText:SetText(#names == 1 and "1 frame moved." or ("%d frames moved."):format(#names))
	ui.ask:Show()
end

-- Keys: the arrows move the chosen frame, Escape asks or closes. Every other key goes on to the game.
local function BuildKeys()
	local keys = Make("Frame")
	keys:SetFrameStrata("FULLSCREEN_DIALOG")
	keys:SetFrameLevel(1)
	keys:SetScript("OnKeyDown", function(self, key)
		local handled = false
		if key == "ESCAPE" then
			handled = true
			if ui.ask and ui.ask:IsShown() then
				ui.ask:Hide()
			else
				Try(MM.Request)
			end
		elseif ARROWS[key] and S.selected and not (ui.ask and ui.ask:IsShown()) then
			local step = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and SHIFT_STEP or 1
			Try(function()
				handled = Nudge(ARROWS[key][1] * step, ARROWS[key][2] * step)
			end)
		end
		self:SetPropagateKeyboardInput(not handled)
	end)
	ui.keys = keys
end

-- The session ------------------------------------------------------------------------------------------

local function BuildChip()
	local chip = Make("Frame")
	chip:SetFrameStrata("FULLSCREEN_DIALOG")
	chip:SetFrameLevel(5)
	chip:SetSize(100, 18)
	local outline = ns.Outline(chip, chip, true)
	Painted(function()
		Look().Backing(outline, "accent", 0.18, "accent")
	end)
	ui.chip = chip
	ui.chipText = Text(chip, "GameFontHighlightSmall", "text", "CENTER")
	ui.chipText:SetPoint("CENTER", chip, "CENTER", 0, 0)
	chip:Hide()
end

local function Build()
	ui.screen = Make("Frame")
	ui.screen:SetFrameStrata("BACKGROUND")
	ui.screen:SetAllPoints(UIParent)
	local dim = ui.screen:CreateTexture(nil, "BACKGROUND", nil, 0)
	ns.Own[dim] = true
	dim:SetAllPoints(ui.screen)
	dim:SetColorTexture(0, 0, 0, 0.4)
	BuildToolbar()
	BuildList()
	BuildInspector()
	BuildChip()
	BuildKeys()
end

local function Tick(_, elapsed)
	ui.clock = (ui.clock or 0) + elapsed
	if ui.clock < 0.1 then
		return
	end
	ui.clock = 0
	Try(MM.Refresh, false)
	ui.listClock = (ui.listClock or 0) + 1
	if ui.listClock >= 3 and S.list then
		ui.listClock = 0
		Try(MM.Layout)
	end
end

local function Show()
	if not ui.screen then
		Build()
	end
	for _, fn in ipairs(ui.paints) do
		fn()
	end
	ui.gridKey = nil
	MM.DrawGrid()
	ui.screen:Show()
	ui.bar:Show()
	ui.list:SetShown(S.list)
	ui.side:Show()
	ui.keys:EnableKeyboard(true)
	ui.keys:Show()
	ui.bar:SetScript("OnUpdate", Tick)
	MM.Layout()
	MM.Refresh(true)
end

local function HideAll()
	if not ui.screen then
		return
	end
	ui.bar:SetScript("OnUpdate", nil)
	ui.sliding = false
	ui.keys:EnableKeyboard(false)
	for _, name in ipairs({ "screen", "bar", "list", "side", "chip", "keys", "ask" }) do
		if ui[name] then
			ui[name]:Hide()
		end
	end
end

-- Called when the handles open. A session that was paused for a fight goes on with what it had.
function MM.Opened(source)
	local kit = Kit()
	S.source = source
	if not (S.paused and S.session) then
		S.session = true
		S.snapshot = CopyAll(kit.Saved())
		S.last = CopyAll(kit.Saved())
		S.undo, S.hidden, S.selected, S.hover, S.offset = {}, {}, nil, nil, 0
		S.panel = false
	end
	-- The options window opened during a fight goes away again when the handles do.
	if type(ns.PanelShown) == "function" and ns.PanelShown() then
		S.panel = true
		-- The setup report is a mode of the window: it comes back with it.
		S.panelMode = type(ns.PanelMode) == "function" and ns.PanelMode() or nil
		ns.PanelKit.Hide()
	end
	S.paused = nil
	Show()
end

-- Called when the handles have been placed: the list and the inspector read them.
function MM.Ready()
	MM.Layout()
	MM.Refresh(true)
end

-- Called when the handles close: for good, or for a fight when Pause was called first.
function MM.Closed()
	HideAll()
	if S.paused then
		return
	end
	S.session = false
	S.snapshot, S.last, S.undo, S.hidden, S.selected, S.hover = {}, {}, {}, {}, nil, nil
	if S.panel then
		S.panel = false
		local mode = S.panelMode
		S.panelMode = nil
		if type(ns.PanelShown) == "function" and not ns.PanelShown() then
			if mode and ns.OpenPanelMode then
				ns.OpenPanelMode(mode)
			else
				ns.OpenPanel()
			end
		end
	end
end

function MM.Pause()
	if S.session then
		S.paused = true
	end
end

-- Movers.lua turned them off while the session waited for a fight: the session ends and the options window comes back.
function MM.Abandon()
	if S.paused then
		S.paused = nil
		MM.Closed()
	end
end

-- True while the options window is hidden by the session.
function MM.Holding()
	return S.session == true and S.panel == true
end

-- The way the handles were opened when a fight stopped them, or nil when there is nothing to open again. Edit Mode is closed by then.
function MM.Resume()
	if not (S.paused and S.session) then
		return nil
	end
	return S.source == "editmode" and "slash" or S.source or "slash"
end

-- What the tests read.
function MM.State()
	return S, ui
end
