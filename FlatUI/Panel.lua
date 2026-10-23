local ADDON_NAME, ns = ...

-- A window of the addon's own with every page of ns.PAGES, a search over all settings, and the profiles. It is made of frames,
-- textures and font strings of the addon's own and is built the first time it is opened. None of its frames is protected, so it
-- works in combat. It is only built out of combat, since UIParent is protected.

local NAME = "FlatUIOptionsFrame"
local WIDTH, HEIGHT = 1040, 680
local TITLE = 36
-- LEFT, HEADER and RIGHT_W are the measures Setup builds its pages for (ns.PanelKit). The options pages use SIDE and CW, which follow Sidebar, and
-- HEAD, the header with the line under the title and the module switch.
local LEFT = 210
local STRIP = 40
local HEADER = 48
local HEAD = 64
local SIDE, CW = 232, WIDTH - 232
local RIGHT_W, RIGHT_H = WIDTH - LEFT, HEIGHT - TITLE - STRIP - HEAD
local PAD = 16
local ROW = 36
local SECTION = 34
local ROW_W = RIGHT_W - 2 * PAD
local LABEL = 330
local CONTROL = 354
local FIELD = 230
local SMALL = 80
local BUTTON = 24
local LINE = 24
local LINES = 10
local WHEEL = 48
local TRACK = 176
local SEARCH = 28
local REFRESH = 0.5
local DIM = 0.4
local Look = ns.PanelLook
local PROFILE_CALLS = { "Profile", "Profiles", "UseProfile" }

local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

-- The parts of the window, and what it is showing.
local ui = { views = {}, nav = {}, lines = {}, paints = {}, tip = "" }

local OpenList, CloseList, Ask, HideConfirm, ShowStrip, RefreshAll, ShowPage

-- Helpers ---------------------------------------------------------------------------------------

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- Units of a frame for each unit of UIParent, and the scale of UIParent.
local function Ratio(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and okBase and Number(scale) and Number(base) and scale > 0 and base > 0 then
		return scale / base, base
	end
	return nil
end

-- Left, bottom, width and height of a frame in the units of UIParent.
local function Rect(frame)
	local k = Ratio(frame)
	if not k then
		return nil
	end
	local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
	if ok and Number(left) and Number(bottom) and Number(width) and Number(height) then
		return left * k, bottom * k, width * k, height * k
	end
	return nil
end

local function ScreenSize()
	local ok, width, height = pcall(UIParent.GetSize, UIParent)
	if ok and Number(width) and Number(height) and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

-- The cursor in the units of UIParent, or nil when the client will not say.
local function Cursor()
	if type(GetCursorPosition) ~= "function" then
		return nil
	end
	local ok, x, y = pcall(GetCursorPosition)
	local _, base = Ratio(UIParent)
	if ok and base and Number(x) and Number(y) then
		return x / base, y / base
	end
	return nil
end

local function ButtonUp()
	if type(IsMouseButtonDown) ~= "function" then
		return false
	end
	local ok, down = pcall(IsMouseButtonDown, "LeftButton")
	return ok and not ns.IsSecret(down) and down == false
end

-- Colours --------------------------------------------------------------------------------------

-- Every colour of the window is a token of PanelLook.lua: a name such as "card" or "text-dim", or a step of grey for the drawings of setup.
local function Shade(spec)
	return Look.Colour(spec)
end

local function Accent()
	return Look.Colour("accent")
end

-- Runs fn now and again when the look of the window changes.
local function Painted(fn)
	ui.paints[#ui.paints + 1] = fn
	fn()
end

local function Repaint()
	local key = Look.Key()
	if key ~= ui.paintKey then
		ui.paintKey = key
		for _, fn in ipairs(ui.paints) do
			fn()
		end
	end
end

local Solid, Backing = Look.Solid, Look.Backing

-- Frames, textures and text ----------------------------------------------------------------------

local function Frame(parent, kind)
	local frame = CreateFrame(kind or "Frame", nil, parent)
	ns.Own[frame] = true
	return frame
end

local function Fill(frame, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, 0)
	ns.Own[texture] = true
	return texture
end

-- The token each text takes: Label gives "text" and Dim "text-dim", and a change of tone sets them again.
local tints = setmetatable({}, { __mode = "k" })

local function Tint(text, token)
	tints[text] = token
	text:SetTextColor(Look.Colour(token))
	return text
end

local function Label(parent, font, justify, width, wrap)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	ns.Own[text] = true
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(wrap == true)
	if width then
		text:SetWidth(width)
	end
	Painted(function()
		text:SetTextColor(Look.Colour(tints[text] or "text"))
	end)
	local object = Look.Object(font)
	if object then
		text:SetFontObject(object)
	end
	return text
end

local function Dim(text)
	return Tint(text, "text-dim")
end

-- A frame that takes clicks: onClick runs when the left button goes down and comes up on it.
local function Clickable(frame, onClick)
	local down = false
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function(_, button)
		down = button == "LeftButton"
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		local wanted = down and button == "LeftButton"
		down = false
		if wanted then
			onClick()
		end
	end)
end

-- Calls follow on the press and on every frame until the left button is up.
local function Drag(frame, follow)
	local function Stop()
		frame:SetScript("OnUpdate", nil)
	end
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then
			follow()
			frame:SetScript("OnUpdate", function()
				if ButtonUp() then
					Stop()
				else
					follow()
				end
			end)
		end
	end)
	frame:SetScript("OnMouseUp", Stop)
end

-- Four short bars that make a triangle pointing down.
local function Chevron(parent)
	for index = 1, 4 do
		local bar = Fill(parent, "ARTWORK")
		bar:SetSize(10 - 2 * index, 1.5)
		bar:SetPoint("TOP", parent, "TOPRIGHT", -16, -(9 + (index - 1) * 1.5))
		Painted(function()
			bar:SetColorTexture(Look.Colour("text-dim"))
		end)
	end
end

-- A flat button. A primary button is in the accent.
local function Button(parent, text, width, onClick, primary)
	local button = Frame(parent)
	button:SetSize(width, BUTTON)
	local outline = ns.Outline(button, button, true)
	local label = Label(button, "GameFontHighlight", "CENTER")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText(text)
	if primary then
		Tint(label, "on-accent")
	end
	local hover = false
	local function Tone()
		if primary then
			return hover and "accent-hover" or "accent"
		end
		return hover and "hover" or "raised"
	end
	Painted(function()
		Backing(outline, Tone(), 1, "line-strong")
	end)
	Clickable(button, onClick)
	button:SetScript("OnEnter", function()
		hover = true
		Backing(outline, Tone(), 1, "line-strong")
	end)
	button:SetScript("OnLeave", function()
		hover = false
		Backing(outline, Tone(), 1, "line-strong")
	end)
	return button, label
end

-- A box to type in, with a thin border that takes the highlight colour while it has the cursor. onLost runs when it loses the cursor.
local function Field(parent, width, limit, onLost)
	local box = Frame(parent, "EditBox")
	box:SetSize(width, BUTTON)
	box:SetFontObject(Look.FontFor("GameFontHighlight"))
	box:SetAutoFocus(false)
	box:SetTextInsets(6, 6, 0, 0)
	box:SetMaxLetters(limit or 0)
	local outline = ns.Outline(box, box, true)
	local focused = false
	Painted(function()
		Backing(outline, "raised", 1, focused and "accent" or "line")
	end)
	box:SetScript("OnEditFocusGained", function()
		focused = true
		Backing(outline, "raised", 1, "accent")
	end)
	box:SetScript("OnEditFocusLost", function()
		focused = false
		Backing(outline, "raised", 1, "line")
		if onLost then
			onLost()
		end
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	return box
end

-- A scrolling area with a thin bar of its own. The content hangs from `child`.
local function Scroller(parent, width, height)
	local scroll = Frame(parent, "ScrollFrame")
	scroll:SetSize(width, height)
	local child = Frame(scroll)
	child:SetSize(width, height)
	scroll:SetScrollChild(child)
	scroll:EnableMouseWheel(true)
	local object = { frame = scroll, child = child, offset = 0, content = height, height = height }
	local bar = Frame(scroll)
	bar:SetSize(8, height)
	bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
	bar:SetFrameLevel(scroll:GetFrameLevel() + 20)
	local thumb = Fill(bar, "ARTWORK")
	thumb:SetWidth(4)
	Painted(function()
		Solid(thumb, "line-strong")
	end)
	local function Range()
		return math.max(0, object.content - object.height)
	end
	function object.Layout()
		local range = Range()
		object.offset = Clamp(object.offset, 0, range)
		scroll:SetVerticalScroll(object.offset)
		bar:SetShown(range > 0)
		if range > 0 then
			local size = math.max(24, object.height * object.height / object.content)
			thumb:SetHeight(size)
			thumb:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -(object.height - size) * object.offset / range)
		end
	end
	function object.Scroll(offset)
		object.offset = offset
		object.Layout()
	end
	function object.SetContent(size)
		object.content = size
		child:SetHeight(size)
		object.Layout()
	end
	function object.Resize(newWidth, newHeight)
		object.height = newHeight
		scroll:SetSize(newWidth, newHeight)
		bar:SetHeight(newHeight)
		child:SetWidth(newWidth)
		object.Layout()
	end
	scroll:SetScript("OnMouseWheel", function(_, delta)
		object.Scroll(object.offset - delta * WHEEL)
	end)
	Drag(bar, function()
		local _, y = Cursor()
		local _, bottom, _, tall = Rect(bar)
		if y and bottom and tall > 0 then
			object.Scroll(Clamp((bottom + tall - y) / tall, 0, 1) * Range())
		end
	end)
	object.Layout()
	return object
end

-- Rows -----------------------------------------------------------------------------------------

-- The ticks a setting needs before its control works: the settings named by "needs", and the switch of the owner of the page it is shown on.
-- A row that acts at once has no switch.
local function Needed(page, item)
	local list = {}
	local owner = page.owner or page.switch or page.key
	local switch = ns.RowLive(item) and "" or owner
	local path = item.needsPath
	if not path and switch ~= "" and owner ~= "general" and item.key ~= "enabled" then
		path = switch .. ".enabled"
	end
	while path do
		local needed = path
		list[#list + 1] = needed
		path = ns.Needs(needed)
		if not path and switch ~= "" and owner ~= "general" and needed ~= switch .. ".enabled" then
			path = switch .. ".enabled"
		end
	end
	return list
end

-- The first setting a row needs that is off, or nil.
local function Unmet(page, item)
	for _, needed in ipairs(Needed(page, item)) do
		if not ns.NeedMet(item, needed) then
			return needed
		end
	end
end

local function IsOpen(page, item)
	return Unmet(page, item) == nil
end

local function Say(message)
	if IsText(message) and message ~= "" then
		ui.message = message
		ShowStrip()
	end
end

-- How far the rows hung from a parent stand in from its edges: a page of cards sets it, any other parent has the margin PAD.
local insets = setmetatable({}, { __mode = "k" })

-- A row: the label on the left, room for a control on the right. The tip shows in the strip while the mouse is over it.
local function NewRow(parent, y, text, tip)
	local row = { active = true, tip = tip or "" }
	local inset = insets[parent] or PAD
	local frame = Frame(parent)
	-- Its width is the width of what it hangs from, less the two margins: the options pages and setup have different columns.
	frame:SetHeight(ROW)
	frame:EnableMouse(true)
	row.frame = frame
	local hover = Fill(frame, "BACKGROUND")
	hover:SetAllPoints(frame)
	hover:Hide()
	Painted(function()
		Solid(hover, inset == PAD and "card" or "hover")
	end)
	local line = Fill(frame, "BORDER")
	line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	line:SetHeight(1)
	Painted(function()
		Solid(line, "line-faint")
	end)
	local label = Label(frame, "GameFontHighlight", "LEFT", LABEL)
	label:SetPoint("LEFT", frame, "LEFT", 0, 0)
	label:SetText(text)
	function row.Place(top)
		row.top = top
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -top)
		frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -top)
	end
	function row.Changed()
		RefreshAll()
	end
	-- Every control of the row shows the tip too, since the game gives the mouse to the control and not to the row.
	function row.Hover(target, enter, leave)
		target:SetScript("OnEnter", function()
			hover:Show()
			ui.message = nil
			-- Setup and the movers show the tip in the strip; the options pages show it in a tooltip.
			if ui.mode then
				ui.tip = row.tip
			elseif ns.PanelTrust then
				ui.tip = ""
				ns.PanelTrust.Show(target, row.tip, row.need)
			end
			ShowStrip()
			if row.entered then
				row.entered()
			end
			if enter then
				enter()
			end
		end)
		target:SetScript("OnLeave", function()
			if leave then
				leave()
			end
			if row.left then
				row.left()
			end
			hover:Hide()
			if ns.PanelTrust then
				ns.PanelTrust.Hide()
			end
			ui.tip = ""
			ShowStrip()
		end)
	end
	row.Hover(frame)
	row.Place(y)
	return row
end

local function SetActive(row, active)
	if row.active ~= active then
		row.active = active
		row.frame:SetAlpha(active and 1 or DIM)
	end
end

local function Chosen(lines, value)
	for _, line in ipairs(lines) do
		if line[1] == value then
			return line[2]
		end
	end
	return nil
end

-- A button that opens a list. spec.lines() gives { { value, text }, ... }, spec.selected() the value to mark, and spec.pick(value) runs
-- when a line is chosen.
local function Dropdown(row, width, spec)
	local button = Frame(row.frame)
	button:SetSize(width, BUTTON)
	local outline = ns.Outline(button, button, true)
	local text = Label(button, "GameFontHighlight", "LEFT", width - 32)
	text:SetPoint("LEFT", button, "LEFT", 8, 0)
	Chevron(button)
	-- A list with samples (spec.sample is the kind) shows the one of the chosen line at the left of the button.
	local Samples = ns.PanelSamples
	local picture = spec.sample and Samples and Samples.New(button) or nil
	local function Lay()
		local shown = picture ~= nil and Samples.On()
		local shift = shown and Samples.WIDTH + Samples.GAP or 0
		text:ClearAllPoints()
		text:SetPoint("LEFT", button, "LEFT", 8 + shift, 0)
		text:SetWidth(width - 32 - shift)
		if picture then
			picture.frame:ClearAllPoints()
			picture.frame:SetPoint("LEFT", button, "LEFT", 8, 0)
			picture.frame:SetShown(shown)
		end
	end
	Lay()
	local hover = false
	Painted(function()
		Backing(outline, hover and "hover" or "raised", 1, "line")
	end)
	local object = { frame = button }
	function object.SetText(value)
		text:SetText(value)
	end
	function object.SetSample(id)
		if picture then
			picture.Set(spec.sample, id)
			Lay()
		end
	end
	Clickable(button, function()
		if row.active then
			OpenList(object, spec)
		end
	end)
	row.Hover(button, function()
		hover = true
		Backing(outline, "hover", 1, "line")
	end, function()
		hover = false
		Backing(outline, "raised", 1, "line")
	end)
	return object
end

-- The editor of one tracker (the Tracker page) keeps its functions in this table, and its rows have a read and a write of their own and no saved path.
local editor = {}

-- The value of a row and a change to it.
local function Read(item)
	if item.read then
		return item.read()
	end
	return ns.Get(item.path)
end

local function Write(item, value)
	if item.write then
		return item.write(value)
	end
	local before = ns.Get(item.path)
	local result = ns.Set(item.path, value)
	if ns.PanelHome then
		ns.PanelHome.Noted(item, before, ns.Get(item.path))
	end
	return result
end

-- A switch: a track of 32 by 16 with a knob. The track is in the accent while the setting is on.
local function AddBool(row, item)
	local box = Frame(row.frame)
	box:SetSize(32, 16)
	box:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	local outline = ns.Outline(box, box, true)
	local mark = Fill(box, "ARTWORK")
	mark:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
	mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
	local knob = Fill(box, "OVERLAY")
	knob:SetSize(12, 12)
	local on = false
	local function Knob()
		knob:SetPoint("LEFT", box, "LEFT", on and 18 or 2, 0)
		knob:SetColorTexture(Look.Colour(on and "on-accent" or "text-dim"))
	end
	local hovered = false
	local function Edge()
		Backing(outline, "line", 1, hovered and "text-faint" or "line-strong")
	end
	Painted(function()
		Edge()
		mark:SetColorTexture(Accent())
		Knob()
	end)
	local function Toggle()
		if row.active then
			Write(item, Read(item) ~= true)
			row.Changed()
		end
	end
	Clickable(box, Toggle)
	Clickable(row.frame, Toggle)
	row.Hover(box, function()
		hovered = true
		Edge()
	end, function()
		hovered = false
		Edge()
	end)
	return function()
		on = Read(item) == true
		mark:SetShown(on)
		Knob()
	end
end

local function AddNumber(row, item)
	local track = Frame(row.frame)
	track:SetSize(TRACK, 18)
	track:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	local groove = Fill(track, "BACKGROUND")
	groove:SetPoint("LEFT", track, "LEFT", 0, 0)
	groove:SetPoint("RIGHT", track, "RIGHT", 0, 0)
	groove:SetHeight(4)
	local bar = Fill(track, "ARTWORK")
	bar:SetPoint("LEFT", track, "LEFT", 0, 0)
	bar:SetHeight(4)
	local thumb = Fill(track, "OVERLAY")
	thumb:SetSize(10, 16)
	-- A mark at the default value, when the row has one.
	local tick = Fill(track, "ARTWORK")
	tick:SetSize(1, 8)
	if Number(item.default) and Number(item.min) and Number(item.max) and item.max > item.min then
		tick:SetPoint("LEFT", track, "LEFT", Clamp((item.default - item.min) / (item.max - item.min), 0, 1) * TRACK, 0)
	else
		tick:Hide()
	end
	Painted(function()
		Solid(groove, "raised")
		bar:SetColorTexture(Accent())
		thumb:SetColorTexture(Accent())
		Solid(tick, "text-faint")
	end)
	local box
	-- A typed value is applied when the player presses Enter or leaves the box.
	local function Commit()
		local typed = box:GetText()
		local number = IsText(typed) and tonumber(typed)
		if row.active and number and number ~= Read(item) then
			Write(item, number)
		end
		row.Changed()
	end
	box = Field(row.frame, 54, 8, Commit)
	box:SetPoint("LEFT", row.frame, "LEFT", CONTROL + TRACK + 12, 0)
	box:SetJustifyH("CENTER")
	local unit = Dim(Label(row.frame, "GameFontHighlightSmall", "LEFT", 90))
	unit:SetPoint("LEFT", box, "RIGHT", 10, 0)
	unit:SetText(((item.unit or ""):gsub("^%s+", "")))
	local function Show()
		local value = Read(item)
		local fraction = Clamp((value - item.min) / (item.max - item.min), 0, 1)
		bar:SetWidth(math.max(1, fraction * TRACK))
		thumb:SetPoint("CENTER", track, "LEFT", fraction * TRACK, 0)
		if not box:HasFocus() then
			box:SetText(("%g"):format(value))
		end
	end
	Drag(track, function()
		local x = Cursor()
		local left, _, width = Rect(track)
		if row.active and x and left and width > 0 then
			Write(item, item.min + Clamp((x - left) / width, 0, 1) * (item.max - item.min))
			row.Changed()
		end
	end)
	track:EnableMouseWheel(true)
	track:SetScript("OnMouseWheel", function(_, delta)
		if row.active then
			Write(item, Read(item) + (delta > 0 and 1 or -1) * item.step)
			row.Changed()
		end
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(("%g"):format(Read(item)))
		self:ClearFocus()
	end)
	box:EnableMouseWheel(true)
	box:SetScript("OnMouseWheel", track:GetScript("OnMouseWheel"))
	row.Hover(track)
	row.Hover(box)
	return Show
end

local function AddColour(row, item)
	local swatch = Frame(row.frame)
	swatch:SetSize(40, 18)
	swatch:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	local outline = ns.Outline(swatch, swatch, true)
	local colour = Fill(swatch, "ARTWORK")
	colour:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
	colour:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)
	Painted(function()
		Backing(outline, "raised", 1, "line-strong")
	end)
	local hex = Dim(Label(row.frame, "GameFontHighlightSmall", "LEFT", 90))
	hex:SetPoint("LEFT", swatch, "RIGHT", 12, 0)
	local function Set(value)
		if value ~= Read(item) then
			Write(item, value)
			row.Changed()
		end
	end
	-- The picker is the one of PanelColour.lua: it changes the colour as the player drags in it, and Cancel puts the old colour back.
	Clickable(swatch, function()
		if row.active and ns.PanelColour then
			ns.PanelColour.Open(Read(item), item.alpha == true, Set)
		end
	end)
	row.Hover(swatch)
	return function()
		local value = Read(item)
		if item.path then
			colour:SetColorTexture(ns.Colour(item.path))
		else
			colour:SetColorTexture((tonumber(value:sub(3, 4), 16) or 0) / 255, (tonumber(value:sub(5, 6), 16) or 0) / 255, (tonumber(value:sub(7, 8), 16) or 0) / 255)
		end
		hex:SetText("#" .. value:sub(3):upper())
	end
end

local function AddChoice(row, item)
	if item.segments and ns.PanelCards then
		return ns.PanelCards.Segments(row, item)
	end
	local menu = Dropdown(row, FIELD, {
		lines = function()
			return ns.Choices(item)
		end,
		selected = function()
			return Read(item)
		end,
		sample = ns.PanelSamples and ns.PanelSamples.Kind(item) or nil,
		pick = function(value)
			Write(item, value)
			row.Changed()
		end,
	})
	menu.frame:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	return function()
		menu.SetText(Chosen(ns.Choices(item), Read(item)) or "")
		menu.SetSample(Read(item))
	end
end

-- A dropdown that acts: the lines come from a function of ns each time it opens, and choosing one calls another with its id.
local function AddList(row, item)
	local menu = Dropdown(row, FIELD, {
		lines = function()
			local call = ns[item.items]
			local ok, lines = false, nil
			if type(call) == "function" then
				ok, lines = pcall(call)
			end
			return ok and type(lines) == "table" and lines or {}
		end,
		pick = function(id)
			local call = ns[item.pick]
			if type(call) ~= "function" then
				return
			end
			local ok, done, message = pcall(call, id)
			if not ok then
				geterrorhandler()(done)
			elseif IsText(message) then
				print(message)
			end
			row.Changed()
		end,
	})
	menu.frame:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	return function()
		menu.SetText(item.none or "")
	end
end

-- A box to type a text in, applied when the player presses Enter or leaves the box.
function editor.Text(row, item)
	local box
	local function Commit()
		local typed = box:GetText()
		if row.active and IsText(typed) and typed ~= (Read(item) or "") then
			Write(item, typed)
		end
		row.Changed()
	end
	box = Field(row.frame, FIELD, 480, Commit)
	box:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(Read(item) or "")
		self:ClearFocus()
	end)
	row.Hover(box)
	return function()
		if not box:HasFocus() then
			box:SetText(Read(item) or "")
		end
	end
end

local ADD = { bool = AddBool, number = AddNumber, colour = AddColour, choice = AddChoice, list = AddList, text = editor.Text }

-- The row of a setting. Returns nil when the client cannot build its control.
local function BuildRow(parent, page, item, y)
	local row = NewRow(parent, y, item.label, item.tip)
	row.item = item
	local ok, show = pcall(ADD[item.kind], row, item)
	if not ok then
		geterrorhandler()(show)
		row.frame:Hide()
		return nil
	end
	local mark = ns.PanelTrust and ns.PanelTrust.Attach(row, item)
	function row.Update()
		local unmet = Unmet(page, item)
		SetActive(row, unmet == nil)
		show()
		if mark then
			mark(unmet)
		end
	end
	return row
end

-- The row of the Trackers page with this saved key.
function editor.PageRow(key)
	for _, page in ipairs(ns.PAGES) do
		for _, row in ipairs(page) do
			if row.path == "trackers." .. key then
				return row
			end
		end
	end
	return nil
end

-- The rows of the editor: the template of the page item, then the rows other files added.
function editor.Specs(item)
	local specs = {}
	for _, spec in ipairs(item.rows or {}) do
		specs[#specs + 1] = spec
	end
	local extra = type(ns.TrackerEditorRows) == "function" and ns.TrackerEditorRows() or {}
	for _, spec in ipairs(type(extra) == "table" and extra or {}) do
		specs[#specs + 1] = spec
	end
	return specs
end

-- Runs a function of ns that changes a tracker and shows the sentence it answers with. True when it worked.
function editor.Do(name, ...)
	local call = ns[name]
	if type(call) ~= "function" then
		return false
	end
	local ok, done, message = pcall(call, ...)
	if not ok then
		geterrorhandler()(done)
		return false
	end
	Say(message)
	return done == true
end

-- A number a row was given, rounded to the step of its row and held in its range.
function editor.Stepped(item, value)
	if item.kind == "number" and Number(value) and item.step and item.min and item.max then
		return Clamp(math.floor((value - item.min) / item.step + 0.5) * item.step + item.min, item.min, item.max)
	end
	return value
end

-- The row of one own value: it shows the tracker's own value, else the value of the Trackers page, and a change gives the tracker a value of its own.
function editor.Row(block, parent, page, spec, y)
	local key, base = spec.key, spec.key and editor.PageRow(spec.key)
	local kind = spec.kind or (base and base.kind)
	if not kind then
		return nil
	end
	local copy = { key = key, kind = kind, label = spec.label or (base and base.label) or key, tip = spec.tip or (base and base.tip), choices = base and base.choices,
		min = base and base.min, max = base and base.max, step = base and base.step, unit = base and base.unit }
	local follows = key ~= "on" and key ~= "spells"
	function copy.read()
		local own = block.index and ns.TrackerOwn(block.index, key)
		if key == "on" then
			return own ~= false
		elseif key == "spells" then
			return type(own) == "table" and table.concat(own, ", ") or ""
		elseif own ~= nil then
			return own
		elseif key == "low" and block.current and block.current.kind == "ammo" then
			return ns.Get("trackers.ammoMin")
		elseif key == "low" and block.current and block.current.kind == "item" then
			return math.max(0, (ns.Get("trackers.itemMin") or 1) - 1)
		elseif base then
			return ns.Get(base.path)
		end
		return kind == "bool" and false or kind == "number" and (copy.min or 0) or kind == "colour" and "ff000000" or ""
	end
	function copy.write(value)
		if block.index then
			editor.Do("TrackerSetOwn", block.index, key, editor.Stepped(copy, value))
		end
	end
	local row = BuildRow(parent, page, copy, y)
	if not row then
		return nil
	end
	local update = row.Update
	function row.Update()
		if key == "low" and block.current then
			copy.max = block.current.lowMax
		end
		update()
		if row.active then
			row.frame:SetAlpha((not block.index or (follows and ns.TrackerOwn(block.index, key) == nil)) and DIM or 1)
		end
	end
	return row
end

-- The editor of one tracker, for the item of kind entries: a list to choose the tracker from, its name, a row for each value it can have of its
-- own and four buttons. It is built out of combat; in a fight a line says so and the block is built on the next look. Adds its parts to
-- view.rows and returns its height.
function editor.Add(parent, page, item, y, view)
	local specs = editor.Specs(item)
	local height = (5 + #specs) * ROW
	local block, parts = { lines = {} }, {}
	local built, waiting = false, nil
	local function Refresh()
		local lines, at = {}, nil
		local call = ns.TrackerEditorLines
		if type(call) == "function" then
			local ok, list = pcall(call)
			lines = ok and type(list) == "table" and list or {}
		end
		for index, line in ipairs(lines) do
			if line.id == block.id then
				at = index
			end
		end
		if not at and #lines > 0 then
			at = Clamp(block.index or 1, 1, #lines)
		end
		block.lines, block.index, block.current = lines, at, at and lines[at] or nil
		block.id = block.current and block.current.id or nil
	end
	local function Build()
		built = true
		local top = y
		local function Next()
			top = top + ROW
			return top - ROW
		end
		local row = NewRow(parent, Next(), "Tracker")
		local menu = Dropdown(row, FIELD, {
			lines = function()
				local list = {}
				for index, line in ipairs(block.lines) do
					list[index] = { line.id, line.text }
				end
				return list
			end,
			selected = function()
				return block.id
			end,
			pick = function(id)
				block.id = id
				Refresh()
				row.Changed()
			end,
		})
		menu.frame:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		parts[#parts + 1] = {
			Update = function()
				SetActive(row, IsOpen(page, item))
				menu.SetText(block.current and block.current.text or "No trackers")
			end,
		}
		local nameRow = NewRow(parent, Next(), "Name")
		local box
		box = Field(nameRow.frame, FIELD, 40, function()
			local typed = box:GetText()
			if nameRow.active and block.current and IsText(typed) and typed ~= block.current.name then
				editor.Do("TrackerSetOwn", block.index, "name", typed)
			end
			nameRow.Changed()
		end)
		box:SetPoint("LEFT", nameRow.frame, "LEFT", CONTROL, 0)
		box:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
		end)
		box:SetScript("OnEscapePressed", function(self)
			self:SetText(block.current and block.current.name or "")
			self:ClearFocus()
		end)
		nameRow.Hover(box)
		parts[#parts + 1] = {
			Update = function()
				SetActive(nameRow, IsOpen(page, item))
				if not box:HasFocus() then
					box:SetText(block.current and block.current.name or "")
				end
			end,
		}
		for _, spec in ipairs(specs) do
			local line = editor.Row(block, parent, page, spec, top)
			if line then
				top = top + ROW
				parts[#parts + 1] = line
			end
		end
		local function Buttons(label, list)
			local line = NewRow(parent, Next(), label)
			local x = CONTROL
			for _, entry in ipairs(list) do
				local button = Button(line.frame, entry[1], entry[2], function()
					if line.active and block.index then
						entry[3]()
						line.Changed()
					end
				end)
				button:SetPoint("LEFT", line.frame, "LEFT", x, 0)
				line.Hover(button)
				x = x + entry[2] + 8
			end
			parts[#parts + 1] = {
				Update = function()
					SetActive(line, IsOpen(page, item))
				end,
			}
		end
		Buttons("Order", {
			{ "Move up", 100, function()
				editor.Do("TrackerMove", block.index, -1)
			end },
			{ "Move down", 110, function()
				editor.Do("TrackerMove", block.index, 1)
			end },
		})
		Buttons("Own settings", {
			{ "Clear own settings", 160, function()
				editor.Do("TrackerClear", block.index)
			end },
		})
		Buttons("Remove this tracker", {
			{ "Remove", 100, function()
				local id, name = block.id, block.current.name
				Ask(("Remove %s?"):format(name), function()
					local lines = ns.TrackerEditorLines and ns.TrackerEditorLines() or {}
					for index, line in ipairs(lines) do
						if line.id == id then
							editor.Do("TrackerRemove", index)
							break
						end
					end
					RefreshAll()
				end)
			end },
		})
	end
	if InCombatLockdown() then
		waiting = Label(parent, "GameFontHighlight", "LEFT", ROW_W)
		waiting:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -(y + 8))
		waiting:SetText("Open this page after the fight.")
	else
		Build()
	end
	view.rows[#view.rows + 1] = {
		Update = function()
			if not built then
				if InCombatLockdown() then
					return
				end
				Build()
				waiting:Hide()
			end
			Refresh()
			for _, part in ipairs(parts) do
				part.Update()
			end
		end,
	}
	return height
end

-- A section header: a mark, the text, and a line under it. Returns the top of the first row under it and the header, which
-- can be placed at another y and hidden.
local function Header(parent, text, y, big)
	local label = Label(parent, big and "GameFontNormalLarge" or "GameFontNormal", "LEFT", ROW_W - 12)
	label:SetText(text)
	local line = Fill(parent, "BORDER")
	line:SetHeight(1)
	local mark = Fill(parent, "ARTWORK")
	mark:SetSize(3, big and 16 or 12)
	Painted(function()
		Solid(line, "line")
		Solid(mark, "line-strong")
	end)
	local header = { label = label }
	function header.Place(top)
		label:ClearAllPoints()
		label:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", PAD + 12, -(top + SECTION - 8))
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -(top + SECTION - 4))
		line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, -(top + SECTION - 4))
		mark:ClearAllPoints()
		mark:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", PAD, -(top + SECTION - 7))
	end
	function header.SetShown(shown)
		label:SetShown(shown)
		line:SetShown(shown)
		mark:SetShown(shown)
	end
	header.Place(y)
	return y + SECTION, header
end

-- Popups ----------------------------------------------------------------------------------------

local function SyncShade()
	local list = ui.listOwner ~= nil
	local confirm = ui.confirm:IsShown() == true
	ui.shade:SetShown(list or confirm)
	ui.dim:SetShown(confirm)
end

local function BuildPopups()
	if ui.shade then
		return
	end
	local window = ui.window
	local base = window:GetFrameLevel()
	-- Under the list and the question, over everything else: a click on it closes them, and the wheel does nothing behind them.
	local shade = Frame(window)
	shade:SetAllPoints(window)
	shade:SetFrameLevel(base + 40)
	shade:EnableMouse(true)
	shade:EnableMouseWheel(true)
	shade:SetScript("OnMouseDown", function()
		CloseList()
		HideConfirm()
	end)
	local dim = Fill(shade, "BACKGROUND")
	dim:SetAllPoints(shade)
	dim:SetColorTexture(0, 0, 0, 0.55)
	shade:Hide()
	ui.shade, ui.dim = shade, dim

	local list = Frame(window)
	list:SetFrameLevel(base + 41)
	list:EnableMouse(true)
	local outline = ns.Outline(list, list, true)
	Painted(function()
		Backing(outline, "card", 1, "line-strong")
	end)
	list:Hide()
	ui.list = list
	ui.listScroller = Scroller(list, FIELD, LINE)
	ui.listScroller.frame:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
	-- A list of more than LINES lines has a field that keeps the lines holding what is typed.
	ui.listSearch = Field(list, FIELD - 8, 40)
	ui.listSearch:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -2)
	ui.listSearch:SetScript("OnTextChanged", function()
		if ui.listOwner and ui.listSearch:IsShown() then
			ui.ShowLines(false)
		end
	end)
	ui.listSearch:Hide()

	local confirm = Frame(window)
	confirm:SetSize(360, 110)
	confirm:SetPoint("CENTER", window, "CENTER", 0, 20)
	confirm:SetFrameLevel(base + 45)
	confirm:EnableMouse(true)
	local box = ns.Outline(confirm, confirm, true)
	Painted(function()
		Backing(box, "card", 1, "line-strong")
	end)
	local question = Label(confirm, "GameFontHighlight", "CENTER", 330, true)
	question:SetJustifyV("TOP")
	question:SetPoint("TOP", confirm, "TOP", 0, -18)
	question:SetHeight(44)
	local yes, yesText = Button(confirm, "Yes", SMALL, function()
		local run = ui.onYes
		HideConfirm()
		if run then
			run()
		end
	end)
	yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 14)
	local no, noText = Button(confirm, "No", SMALL, function()
		local run = ui.onNo
		HideConfirm()
		if run then
			run()
		end
	end)
	no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 14)
	confirm:Hide()
	ui.confirm, ui.question = confirm, question
	ui.yes, ui.yesText, ui.no, ui.noText = yes, yesText, no, noText
end

-- A line of a dropdown's list.
local function ListLine(index)
	local line = ui.lines[index]
	if line then
		return line
	end
	local frame = Frame(ui.listScroller.child)
	frame:SetSize(FIELD, LINE)
	frame:SetPoint("TOPLEFT", ui.listScroller.child, "TOPLEFT", 0, -(2 + (index - 1) * LINE))
	local hover = Fill(frame, "BACKGROUND")
	hover:SetAllPoints(frame)
	hover:Hide()
	local mark = Fill(frame, "ARTWORK")
	mark:SetSize(3, 12)
	mark:SetPoint("LEFT", frame, "LEFT", 4, 0)
	Painted(function()
		Solid(hover, "hover")
		mark:SetColorTexture(Accent())
	end)
	local text = Label(frame, "GameFontHighlight", "LEFT", FIELD - 28)
	text:SetPoint("LEFT", frame, "LEFT", 14, 0)
	line = { frame = frame, text = text, mark = mark }
	Clickable(frame, function()
		local pick = ui.listSpec and ui.listSpec.pick
		local value = line.value
		if line.live and pick then
			CloseList()
			pick(value)
		end
	end)
	frame:SetScript("OnEnter", function()
		if line.live then
			hover:Show()
		end
	end)
	frame:SetScript("OnLeave", function()
		hover:Hide()
	end)
	ui.lines[index] = line
	return line
end

function CloseList()
	if ui.listOwner then
		ui.listOwner, ui.listSpec = nil, nil
		ui.listSearch:ClearFocus()
		ui.list:Hide()
		SyncShade()
	end
end

-- Fills the lines of the open list with the ones that hold what is typed in its field. With first, the list opens scrolled to the chosen line.
function ui.ShowLines(first)
	local lines = ui.listLines
	local selected = ui.listSpec.selected and ui.listSpec.selected()
	local typed = ui.listSearch:IsShown() and ui.listSearch:GetText()
	if IsText(typed) and typed ~= "" then
		local found, want = {}, typed:lower()
		for _, entry in ipairs(lines) do
			if tostring(entry[2]):lower():find(want, 1, true) then
				found[#found + 1] = entry
			end
		end
		lines = found
	end
	local count = math.max(1, #lines)
	local width = ui.listWidth
	local kind = ui.listSpec.sample
	kind = kind and ns.PanelSamples and ns.PanelSamples.On() and kind or nil
	ui.listScroller.SetContent(count * LINE + 4)
	local at = 1
	for index = 1, math.max(count, #ui.lines) do
		local entry = lines[index]
		if index <= count then
			local line = ListLine(index)
			line.frame:SetWidth(width)
			line.live = entry ~= nil
			line.value = entry and entry[1]
			line.text:SetText(entry and entry[2] or "None")
			local picture = kind and entry and (line.picture or ns.PanelSamples.New(line.frame)) or nil
			line.picture = picture or line.picture
			local shift = picture and ns.PanelSamples.WIDTH + ns.PanelSamples.GAP or 0
			if line.picture then
				line.picture.frame:SetShown(picture ~= nil)
			end
			if picture then
				picture.frame:ClearAllPoints()
				picture.frame:SetPoint("LEFT", line.frame, "LEFT", 14, 0)
				picture.Set(kind, entry[1])
			end
			line.text:ClearAllPoints()
			line.text:SetPoint("LEFT", line.frame, "LEFT", 14 + shift, 0)
			line.text:SetWidth(width - 28 - shift)
			if entry then
				Tint(line.text, "text")
			else
				Dim(line.text)
			end
			local chosen = entry ~= nil and selected ~= nil and entry[1] == selected
			line.mark:SetShown(chosen)
			if chosen then
				at = index
			end
			line.frame:Show()
		elseif ui.lines[index] then
			ui.lines[index].frame:Hide()
		end
	end
	ui.listScroller.Scroll(first and at > LINES and (at - 1) * LINE or 0)
end

function OpenList(owner, spec)
	BuildPopups()
	if ui.listOwner == owner then
		CloseList()
		return
	end
	CloseList()
	HideConfirm()
	local lines = spec.lines()
	local width = math.max(FIELD, select(3, Rect(owner.frame)) or 0)
	local shown = math.min(math.max(1, #lines), LINES)
	local search = #lines > LINES and SEARCH or 0
	local height = search + shown * LINE + 4
	ui.listOwner, ui.listSpec, ui.listLines, ui.listWidth = owner, spec, lines, width
	ui.list:SetSize(width, height)
	ui.listScroller.Resize(width, shown * LINE + 4)
	ui.listScroller.frame:ClearAllPoints()
	ui.listScroller.frame:SetPoint("TOPLEFT", ui.list, "TOPLEFT", 0, -search)
	ui.listSearch:SetWidth(width - 8)
	ui.listSearch:SetShown(search > 0)
	if search > 0 then
		ui.listSearch:SetText("")
	end
	ui.ShowLines(true)
	ui.list:ClearAllPoints()
	local _, bottom = Rect(owner.frame)
	local _, floor = Rect(ui.window)
	if not (bottom and floor) or bottom - height - 2 >= floor + STRIP then
		ui.list:SetPoint(spec.right and "TOPRIGHT" or "TOPLEFT", owner.frame, spec.right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -2)
	else
		ui.list:SetPoint(spec.right and "BOTTOMRIGHT" or "BOTTOMLEFT", owner.frame, spec.right and "TOPRIGHT" or "TOPLEFT", 0, 2)
	end
	ui.list:Show()
	SyncShade()
end

-- The question box: onYes runs on the first button, onNo (when given) on the second. A click outside the box closes it and runs neither. The buttons
-- say yesText and noText when those are given, and Yes and No otherwise.
function Ask(question, onYes, onNo, yesText, noText)
	BuildPopups()
	CloseList()
	ui.question:SetText(question)
	ui.onYes, ui.onNo = onYes, onNo
	local wide = yesText ~= nil or noText ~= nil
	ui.yesText:SetText(yesText or "Yes")
	ui.noText:SetText(noText or "No")
	ui.yes:SetWidth(wide and 130 or SMALL)
	ui.no:SetWidth(wide and 130 or SMALL)
	ui.confirm:Show()
	SyncShade()
end

function HideConfirm()
	if ui.confirm and ui.confirm:IsShown() then
		ui.onYes, ui.onNo = nil, nil
		ui.confirm:Hide()
		SyncShade()
	end
end

-- Pages ----------------------------------------------------------------------------------------

local function BuildModel()
	local model = { pages = {}, byKey = {} }
	for index, page in ipairs(ns.PAGES) do
		if index == 1 or ns.PageHasRows(page, true) then
			local entry = { key = page.key, label = page.label, parent = page.parent, page = page, sections = {} }
			for _, item in ipairs(page) do
				if item.section then
					entry.sections[#entry.sections + 1] = item.section
				elseif item.key == "enabled" and item.kind == "bool" and not item.page and not entry.switchItem then
					-- The switch of the module is shown in the header of the page, and not as a row.
					entry.switchItem = item
				end
			end
			model.pages[#model.pages + 1] = entry
			model.byKey[page.key] = entry
		end
	end
	model.profiles = { key = "profiles", label = "Profiles", profiles = true, sections = { "Profile", "Switch automatically", "Share" } }
	model.home = { key = "home", label = "Home", home = true, sections = {} }
	return model
end

local function BuildView(entry)
	local scroller = Scroller(ui.right, CW, RIGHT_H)
	scroller.frame:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 0, -HEAD)
	local view = { scroller = scroller, rows = {}, sections = {}, module = true }
	-- With Sections at Cards, the rows of a section stand on a card; Lines keep the heading with a line under it.
	local cards = ns.PanelCards and ns.PanelCards.On() and ns.PanelCards.New(entry, view, scroller, CW) or nil
	local y = 8
	for index, item in ipairs(entry.page) do
		if item.section then
			view.sections[#view.sections + 1] = y
			if cards then
				y = cards.Section(item, y, entry.page, index)
			else
				y = Header(scroller.child, item.section, y)
			end
		elseif item == entry.switchItem and not entry.parent then
			-- It is the switch in the header. A tab with a switch of its own (Your buffs) shows it as its first row.
		elseif item.kind == "entries" then
			y = y + editor.Add(scroller.child, entry.page, item, y, view)
			if cards then
				cards.Static()
			end
		elseif cards and cards.chipped[item] then
			-- It is a chip in the block under the heading of its section.
		elseif ns.RowShown(item.path) then
			local row = BuildRow(scroller.child, entry.page, item, y)
			if row then
				view.rows[#view.rows + 1] = row
				if cards then
					cards.Row(row, item, y)
				end
			end
			y = y + ROW
		end
	end
	if cards then
		y = cards.Finish(y)
	end
	scroller.SetContent(y + PAD)
	function view.Update()
		for _, row in ipairs(view.rows) do
			row.Update()
		end
	end
	return view
end

-- Profiles ---------------------------------------------------------------------------------------

local function Call(name, ...)
	local call = ns[name]
	if type(call) ~= "function" then
		return nil
	end
	local ok, first, second = pcall(call, ...)
	if not ok then
		geterrorhandler()(first)
		return nil
	end
	return first, second
end

-- Runs a function of Core that changes a profile and shows the sentence it answers with.
local function Act(name, ...)
	local done, message = Call(name, ...)
	Say(IsText(message) and message or (done == nil and "That did not work." or nil))
	RefreshAll()
	return done
end

local function ProfileNames(keep)
	local names = Call("Profiles")
	local current = Call("Profile")
	local lines = {}
	for _, name in ipairs(type(names) == "table" and names or {}) do
		if IsText(name) and keep(name, current) then
			lines[#lines + 1] = { name, name }
		end
	end
	return lines
end

local function Others(name, current)
	return name ~= current
end

local function Removable(name, current)
	return name ~= current and name ~= "Default"
end

local function BuildProfiles()
	local scroller = Scroller(ui.right, CW, RIGHT_H)
	scroller.frame:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 0, -HEAD)
	local child = scroller.child
	local view = { scroller = scroller, rows = {}, sections = {} }
	for _, name in ipairs(PROFILE_CALLS) do
		if type(ns[name]) ~= "function" then
			local text = Label(child, "GameFontHighlight", "LEFT", ROW_W)
			text:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -PAD)
			text:SetText("Profiles are not available.")
			function view.Update() end
			return view
		end
	end
	local updates = {}
	local y = 8
	local function Row(text)
		local row = NewRow(child, y, text)
		y = y + ROW
		return row
	end
	local function Menu(row, spec)
		local menu = Dropdown(row, FIELD, spec)
		menu.frame:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		return menu
	end
	local function Beside(row, text, onClick)
		local button = Button(row.frame, text, SMALL, onClick)
		button:SetPoint("LEFT", row.frame, "LEFT", CONTROL + FIELD + 10, 0)
		return button
	end
	local function Current()
		local name = Call("Profile")
		return IsText(name) and name or ""
	end

	view.sections[1] = y
	y = Header(child, "Profile", y)
	local row = Row("Profile in use")
	local used = Menu(row, {
		lines = function()
			return ProfileNames(function() return true end)
		end,
		selected = Current,
		pick = function(name)
			Act("UseProfile", name)
		end,
	})
	updates[#updates + 1] = function()
		used.SetText(Current())
	end

	if type(ns.NewProfile) == "function" then
		row = Row("New profile")
		local name = Field(row.frame, FIELD, 32)
		name:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		local function Create()
			local typed = name:GetText()
			typed = IsText(typed) and typed or ""
			if Act("NewProfile", (typed:match("^%s*(.-)%s*$"))) then
				name:SetText("")
			end
		end
		name:SetScript("OnEnterPressed", Create)
		row.Hover(name)
		Beside(row, "Create", Create)
		if type(ns.OpenSetup) == "function" then
			row = Row("Setup")
			local start, text = Button(row.frame, "Set up a new profile", 170, function()
				Call("OpenSetup")
			end)
			start:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
			row.Hover(start)
			updates[#updates + 1] = function()
				text:SetText(Call("SetupHasDraft") and "Continue setup" or "Set up a new profile")
			end
			local ready = Button(row.frame, "Ready-made profiles", 170, function()
				Call("OpenProfiles")
			end)
			ready:SetPoint("LEFT", start, "RIGHT", 8, 0)
			row.Hover(ready)
		end
	end

	if type(ns.CopyProfile) == "function" then
		row = Row("Copy from")
		local from
		local menu = Menu(row, {
			lines = function()
				return ProfileNames(Others)
			end,
			selected = function()
				return from
			end,
			pick = function(name)
				from = name
				RefreshAll()
			end,
		})
		Beside(row, "Copy", function()
			if from then
				Ask(('Replace "%s" with a copy of "%s"?'):format(Current(), from), function()
					Act("CopyProfile", from)
				end)
			else
				Say("Choose a profile to copy.")
			end
		end)
		updates[#updates + 1] = function()
			if from and not Chosen(ProfileNames(Others), from) then
				from = nil
			end
			menu.SetText(from or "Choose a profile")
		end
	end

	if type(ns.DeleteProfile) == "function" then
		row = Row("Delete profile")
		local doomed
		local menu = Menu(row, {
			lines = function()
				return ProfileNames(Removable)
			end,
			selected = function()
				return doomed
			end,
			pick = function(name)
				doomed = name
				RefreshAll()
			end,
		})
		Beside(row, "Delete", function()
			if doomed then
				Ask(('Delete the profile "%s"?'):format(doomed), function()
					Act("DeleteProfile", doomed)
				end)
			else
				Say("Choose a profile to delete.")
			end
		end)
		updates[#updates + 1] = function()
			if doomed and not Chosen(ProfileNames(Removable), doomed) then
				doomed = nil
			end
			menu.SetText(doomed or "Choose a profile")
		end
	end

	if type(ns.RenameProfile) == "function" then
		row = Row("Rename profile")
		local name = Field(row.frame, FIELD, 32)
		name:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		local function Rename()
			local typed = name:GetText()
			typed = IsText(typed) and typed or ""
			if Act("RenameProfile", Current(), (typed:match("^%s*(.-)%s*$"))) then
				name:SetText("")
			end
		end
		name:SetScript("OnEnterPressed", Rename)
		row.Hover(name)
		Beside(row, "Rename", Rename)
	end

	if type(ns.ResetProfile) == "function" then
		row = Row("Reset profile")
		local reset = Button(row.frame, "Reset", SMALL, function()
			Ask(('Reset every setting in "%s" to its default?'):format(Current()), function()
				Act("ResetProfile")
			end)
		end)
		reset:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	end

	if ns.ProfileSwitch then
		view.sections[2] = y
		y = ns.ProfileSwitch.Build(ns.PanelKit, child, y, updates)
	end

	if type(ns.ExportProfile) == "function" or type(ns.ImportProfile) == "function" or type(ns.TrackerExportText) == "function" or type(ns.TrackerImport) == "function" then
		view.sections[3] = y
		y = Header(child, "Share", y)
	end

	if type(ns.ExportProfile) == "function" then
		row = Row("Export profile")
		local out = Field(row.frame, FIELD, 0)
		out:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		row.Hover(out)
		Beside(row, "Export", function()
			local text = Call("ExportProfile", {})
			if IsText(text) then
				out:SetText(text)
				out:SetFocus()
				out:HighlightText()
				Say("Press Ctrl+C to copy.")
			else
				Say("That did not work.")
			end
		end)
	end

	if type(ns.TrackerExportText) == "function" then
		row = Row("Export trackers")
		local out = Field(row.frame, FIELD, 0)
		out:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		row.Hover(out)
		Beside(row, "Export", function()
			local text, message = Call("TrackerExportText")
			if IsText(text) then
				out:SetText(text)
				out:SetFocus()
				out:HighlightText()
				Say("Press Ctrl+C to copy.")
			else
				Say(IsText(message) and message or "That did not work.")
			end
		end)
	end

	if type(ns.TrackerImport) == "function" then
		row = Row("Import trackers")
		local into = Field(row.frame, FIELD, 0)
		into:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		row.Hover(into)
		Beside(row, "Import", function()
			local text = into:GetText()
			if IsText(text) and text:find("%S") then
				if Act("TrackerImport", text) then
					into:SetText("")
				end
			else
				Say("Paste the trackers first.")
			end
		end)
	end

	if type(ns.ImportProfile) == "function" then
		row = Row("Import profile")
		local into = Field(row.frame, FIELD, 0)
		into:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		row.Hover(into)
		if ns.ProfileShare then
			ns.ProfileShare.Watch(into)
		end
		Beside(row, "Import", function()
			local text = into:GetText()
			if IsText(text) and text:find("%S") then
				-- A text that can be read is imported with the choices under the paste field.
				if ns.ProfileShare and ns.ProfileShare.Import(text) then
					return
				end
				Ask(('Replace "%s" with the pasted settings?'):format(Current()), function()
					if Act("ImportProfile", text) then
						into:SetText("")
					end
				end)
			else
				Say("Paste the settings first.")
			end
		end)
	end

	if ns.ProfileShare and type(ns.ExportProfile) == "function" and type(ns.ImportProfile) == "function" then
		y = ns.ProfileShare.Build(ns.PanelKit, child, y, updates, scroller, row)
	end

	scroller.SetContent(y + PAD)
	function view.Update()
		for _, update in ipairs(updates) do
			update()
		end
	end
	return view
end

-- Home, and the pages the player goes to --------------------------------------------------------------

local function CurrentProfile()
	local name = Call("Profile")
	return IsText(name) and name or ""
end

-- Flips the switch of a module, in the header or on a tile of Home.
local function Toggle(item)
	Write(item, Read(item) ~= true)
	RefreshAll()
end

-- A page the player chose: opened, with its group open in the sidebar, and kept as the page the window opens on the next time.
local function Go(entry)
	if ui.side then
		ui.side.Reveal(entry)
	end
	ShowPage(entry)
	Look.SetPage(entry.key)
end

local function BuildHome()
	return ns.PanelHome.Build({
		Model = function()
			return ui.model
		end,
		right = ui.right, width = CW, top = HEAD, height = RIGHT_H,
		Show = Go,
		Setup = function()
			Call("OpenSetup")
		end,
		Call = Call,
		Act = Act,
		ProfileLines = function()
			return ProfileNames(function()
				return true
			end)
		end,
		Profile = CurrentProfile,
		Toggle = Toggle,
	})
end

-- The line under the title of Home and Profiles: how many modules are on, the profile in use. A module page has the breadcrumb of PanelTabs.lua there.
local function Subtitle(entry)
	if entry.home then
		return ns.PanelHome.Subtitle(ui.model)
	elseif entry.profiles then
		local name = CurrentProfile()
		return name ~= "" and ("Profile in use: " .. name) or ""
	end
	return ""
end

-- Draws the sidebar again (PanelNav.lua).
local function LayoutNav()
	if ui.side then
		ui.side.Layout()
	end
end

-- Search ------------------------------------------------------------------------------------------

local FLASH, FLASH_ALPHA = 0.8, 0.24
local CHIP_H = 28
local STEPS_GROUP, PROFILES_GROUP = "Flat UI setup", "Profiles"

-- The pages whose names match, as chips under a small heading. The frames of the block hold their own text, so that the block is not a row of the results.
local function BuildChips(parent)
	local block = { frame = Frame(parent), chips = {} }
	local holder = Frame(block.frame)
	holder:SetSize(120, 16)
	holder:SetPoint("TOPLEFT", block.frame, "TOPLEFT", 0, 0)
	block.title = Dim(Label(holder, "GameFontHighlightSmall", "LEFT", 120))
	block.title:SetPoint("LEFT", holder, "LEFT", 0, 0)
	block.title:SetText("Pages")
	block.frame:Hide()
	-- Shows a chip for each entry, wrapped inside the column. Returns the height of the block, 0 for none.
	function block.Set(entries, y)
		for _, chip in ipairs(block.chips) do
			chip:Hide()
		end
		if #entries == 0 then
			block.frame:Hide()
			return 0
		end
		local x, line = 0, 0
		for index, entry in ipairs(entries) do
			local chip = block.chips[index]
			if not chip then
				local label
				chip, label = Button(block.frame, entry.label, 100, function()
					Go(block.chips[index].go)
				end)
				chip.text = label
				block.chips[index] = chip
			end
			chip.text:SetText(entry.label)
			chip.go = entry
			local ok, measured = pcall(chip.text.GetStringWidth, chip.text)
			if not (ok and Number(measured) and measured > 0) then
				measured = 7.2 * #entry.label
			end
			local width = math.ceil(measured) + 24
			if x > 0 and x + width > ROW_W then
				x, line = 0, line + 1
			end
			chip:SetWidth(width)
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", block.frame, "TOPLEFT", x, -(20 + line * CHIP_H))
			chip:Show()
			x = x + width + 8
		end
		local height = 20 + (line + 1) * CHIP_H + 4
		block.frame:SetSize(ROW_W, height)
		block.frame:ClearAllPoints()
		block.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -y)
		block.frame:Show()
		return height
	end
	return block
end

local function BuildSearchView()
	local scroller = Scroller(ui.right, CW, RIGHT_H)
	scroller.frame:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 0, -HEAD)
	scroller.frame:Hide()
	local empty = Label(scroller.child, "GameFontHighlight", "LEFT", ROW_W)
	empty:SetPoint("TOPLEFT", scroller.child, "TOPLEFT", PAD, -PAD)
	empty:SetText("No settings match.")
	local view = { scroller = scroller, cache = {}, headers = {}, empty = empty, shown = {}, picks = {}, at = 0, chips = BuildChips(scroller.child) }
	function view.Update()
		for _, row in ipairs(view.shown) do
			row.Update()
		end
	end
	return view
end

-- A result that opens a page or a step of setup instead of holding a control: the name and a button.
local function BuildLink(view, hit, y)
	local row = NewRow(view.scroller.child, y, hit.label, "")
	local open = Button(row.frame, "Open", SMALL, function()
		hit.Open()
	end)
	open:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	row.Hover(open)
	function row.Update() end
	return row
end

-- The fill of the result the keys are on.
local function Pick(view, at)
	local old = view.picks[view.at]
	if old and old.row.pick then
		old.row.pick:Hide()
	end
	view.at = at
	local hit = view.picks[at]
	if not hit then
		return
	end
	local row = hit.row
	if not row.pick then
		row.pick = Fill(row.frame, "BACKGROUND")
		row.pick:SetAllPoints(row.frame)
		Painted(function()
			Solid(row.pick, "accent", 0.14)
		end)
	end
	row.pick:Show()
	local scroller = view.scroller
	if row.top and row.top < scroller.offset then
		scroller.Scroll(row.top - 8)
	elseif row.top and row.top + ROW > scroller.offset + scroller.height then
		scroller.Scroll(row.top + ROW - scroller.height + 8)
	end
end

-- The row that was opened glows for a moment: a fill in the accent that fades.
local function Flash(row)
	if not row.flash then
		row.flash = Fill(row.frame, "ARTWORK")
		row.flash:SetAllPoints(row.frame)
	end
	if ui.flash and ui.flash.row ~= row then
		ui.flash.row.flash:Hide()
	end
	ui.flash = { row = row, left = FLASH }
	Solid(row.flash, "accent", FLASH_ALPHA)
	row.flash:Show()
end

local function Fade(seconds)
	local flash = ui.flash
	flash.left = flash.left - seconds
	if flash.left <= 0 then
		flash.row.flash:Hide()
		ui.flash = nil
	else
		Solid(flash.row.flash, "accent", FLASH_ALPHA * flash.left / FLASH)
	end
end

-- Opens the tab of a setting, scrolls to its row and flashes it.
local function Arrive(entry, item)
	ui.search:ClearFocus()
	Go(entry)
	local view = ui.views[entry]
	if not view then
		return
	end
	if view.RevealItem then
		view.RevealItem(item)
	end
	for _, row in ipairs(view.rows) do
		if row.item == item then
			view.scroller.Scroll(math.max(0, (row.top or 0) - 2 * ROW))
			Flash(row)
			return
		end
	end
end

local function Show(view)
	if ui.view and ui.view ~= view then
		ui.view.scroller.frame:Hide()
	end
	ui.view = view
	view.scroller.frame:Show()
end

-- The groups the words find: the rows of the options pages, then Profiles and the steps of setup, each in its order of match.
local function Collect(words)
	local groups = {}
	for _, entry in ipairs(ui.model.pages) do
		local section, group = "", nil
		for _, item in ipairs(entry.page) do
			if item.section then
				section = item.section
			elseif item.key and ns.RowShown(item.path) then
				local tier = ns.PanelSearch.Tier(words, item.label, item.tip, section, entry.label)
				if tier then
					if not group then
						group = { label = entry.label, entry = entry, hits = {} }
						groups[#groups + 1] = group
					end
					group.hits[#group.hits + 1] = { tier = tier, label = item.label or "", item = item, key = item, Open = function()
						Arrive(entry, item)
					end }
				end
			end
		end
	end
	local profiles = { label = PROFILES_GROUP, hits = {} }
	for _, label in ipairs(ns.PanelSearch.PROFILE_ROWS) do
		local tier = ns.PanelSearch.Tier(words, label, "", PROFILES_GROUP, PROFILES_GROUP)
		if tier then
			profiles.hits[#profiles.hits + 1] = { tier = tier, label = label, link = true, key = PROFILES_GROUP .. "/" .. label, Open = function()
				Go(ui.model.profiles)
			end }
		end
	end
	local steps = { label = STEPS_GROUP, hits = {} }
	for _, step in ipairs(type(ns.SETUP_STEPS) == "table" and ns.SETUP_STEPS or {}) do
		local tier = step.built and ns.PanelSearch.Tier(words, step.title, "", step.area, STEPS_GROUP)
		if tier then
			steps.hits[#steps.hits + 1] = { tier = tier, label = step.title, link = true, key = STEPS_GROUP .. "/" .. step.id, Open = function()
				-- The options pages are back as they were when setup closes.
				ui.search:ClearFocus()
				ShowPage(ui.current)
				Call("OpenSetup", step.id)
			end }
		end
	end
	for _, group in ipairs({ profiles, steps }) do
		if #group.hits > 0 then
			groups[#groups + 1] = group
		end
	end
	return ns.PanelSearch.Sort(groups)
end

local function Search(typed)
	local words = ns.PanelSearch.Words(typed)
	if #words == 0 then
		if ui.searching then
			ui.searching = false
			ShowPage(ui.current)
		end
		return
	end
	CloseList()
	HideConfirm()
	ui.searching = true
	local view = ui.searchView
	if not view then
		view = BuildSearchView()
		ui.searchView = view
		ui.searchBase = Look.Get("density") .. "/" .. Look.Get("sidebar")
	end
	for _, row in pairs(view.cache) do
		row.frame:Hide()
		if row.pick then
			row.pick:Hide()
		end
	end
	for _, header in ipairs(view.headers) do
		header.SetShown(false)
	end
	view.shown, view.picks = {}, {}
	local groups = Collect(words)
	local y = 8
	local chips = ns.PanelSearch.Pages(words, ui.model)
	if #groups == 0 then
		chips = ns.PanelSearch.Closest(words, ui.model)
	end
	y = y + view.chips.Set(chips, y)
	for number, group in ipairs(groups) do
		local header = view.headers[number]
		if not header then
			header = select(2, Header(view.scroller.child, group.label, y, true))
			view.headers[number] = header
		end
		header.label:SetText(group.label)
		header.Place(y)
		header.SetShown(true)
		y = y + SECTION
		for _, hit in ipairs(group.hits) do
			local row = view.cache[hit.key]
			if row == nil then
				if hit.link then
					row = BuildLink(view, hit, y)
				else
					row = BuildRow(view.scroller.child, group.entry.page, hit.item, y) or false
				end
				view.cache[hit.key] = row
			end
			if row then
				row.Place(y)
				row.frame:Show()
				row.Update()
				view.shown[#view.shown + 1] = row
				view.picks[#view.picks + 1] = { row = row, Open = hit.Open }
				y = y + ROW
			end
		end
	end
	view.empty:SetShown(#view.shown == 0)
	if #view.shown == 0 then
		view.empty:ClearAllPoints()
		view.empty:SetPoint("TOPLEFT", view.scroller.child, "TOPLEFT", PAD, -y)
		y = y + 24
	end
	view.scroller.SetContent(math.max(y + PAD, 1))
	view.scroller.Scroll(0)
	Pick(view, #view.picks > 0 and 1 or 0)
	Show(view)
	ui.title:SetText("Search")
	ui.head.Set(nil, "")
	ui.tabs.Hide()
	ui.reset:Hide()
	ui.tip, ui.message = "", nil
	ShowStrip()
	LayoutNav()
end

-- Up and Down move the selection of the results, Enter opens it. Out of combat only.
local function SearchKey(key)
	local view = ui.searchView
	if not (ui.searching and view and #view.picks > 0) or InCombatLockdown() then
		return
	end
	if key == "ENTER" then
		view.picks[math.max(view.at, 1)].Open()
	elseif key == "DOWN" then
		Pick(view, math.min(view.at + 1, #view.picks))
	elseif key == "UP" then
		Pick(view, math.max(view.at - 1, 1))
	end
end

-- The window ---------------------------------------------------------------------------------------

function ShowStrip()
	if ui.strip then
		local text = ui.message
		if not text then
			text = ui.tip or ""
			if text == "" and not ui.searching and not ui.mode and ns.PanelTrust then
				text = ns.PanelTrust.Status(ui.current)
			end
		end
		ui.strip:SetText(text)
	end
end

function ShowPage(entry)
	if not entry then
		return
	end
	CloseList()
	HideConfirm()
	ui.searching = false
	ui.quiet = true
	ui.search:SetText("")
	ui.quiet = false
	ui.current = entry
	local view = ui.views[entry]
	if not view then
		view = entry.home and BuildHome() or entry.profiles and BuildProfiles() or BuildView(entry)
		ui.views[entry] = view
	end
	Show(view)
	-- A tab shows under the title of its module, and the module has the switch in the header.
	local top = ns.PanelNav.Top(ui.model, entry)
	ui.title:SetText(top.label)
	ui.head.Set(top, Subtitle(entry))
	local band = ui.tabs.Set(entry)
	if view.module and view.band ~= band then
		view.band = band
		view.scroller.frame:ClearAllPoints()
		view.scroller.frame:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 0, -(HEAD + band))
		view.scroller.Resize(CW, RIGHT_H - band)
	end
	ui.reset:SetShown(not entry.profiles and not entry.home)
	ui.tip, ui.message = "", nil
	ShowStrip()
	LayoutNav()
	view.Update()
end

function RefreshAll()
	if not ui.window then
		return
	end
	Repaint()
	if ui.mode then
		ui.mode.Update()
	else
		if ui.side and ui.head then
			ui.side.Update()
			ui.head.Update()
			if ui.current and not ui.searching and (ui.current.home or ui.current.profiles) then
				ui.head.sub:SetText(Subtitle(ui.current))
			end
		end
		if ui.view then
			ui.view.Update()
		end
		ShowStrip()
	end
end

local function SavePosition()
	local db = FlatUIDB
	if type(db) ~= "table" then
		return
	end
	local ok, point, relativeTo, relativePoint, x, y = pcall(ui.window.GetPoint, ui.window, 1)
	if ok and relativeTo == UIParent and POINTS[point] and POINTS[relativePoint] and Number(x) and Number(y) then
		Look.SavePosition(point, relativePoint ~= point and relativePoint or nil, x, y)
	end
end

-- True while enough of the window is on the screen to reach its title bar.
local function OnScreen()
	local left, bottom, width, height = Rect(ui.window)
	local screenWidth, screenHeight = ScreenSize()
	if not (left and screenWidth) then
		return true
	end
	return left + 120 <= screenWidth and left + width - 120 >= 0 and bottom + height <= screenHeight + 20 and bottom + height - TITLE >= 0
end

-- The scale of the window: Window scale, or less when the screen is too small for the window.
local function ApplyScale()
	local screenWidth, screenHeight = ScreenSize()
	local fit = screenWidth and math.min((screenWidth - 40) / WIDTH, (screenHeight - 40) / HEIGHT) or math.huge
	ui.window:SetScale(math.min(Look.Scale(), fit))
end

local function Place()
	local window = ui.window
	local saved = type(FlatUIDB) == "table" and FlatUIDB.panel or nil
	local point, relative, x, y = "CENTER", "CENTER", 0, 0
	if type(saved) == "table" and POINTS[saved.point] and Number(saved.x) and Number(saved.y) then
		point, x, y = saved.point, saved.x, saved.y
		relative = POINTS[saved.relative] and saved.relative or point
	end
	-- A screen too small for the window gets a smaller window.
	ApplyScale()
	window:ClearAllPoints()
	window:SetPoint(point, UIParent, relative, x, y)
	window:Show()
	if not OnScreen() then
		window:ClearAllPoints()
		window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		Look.ClearPosition()
	end
end

local function Version()
	if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
		return nil
	end
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
	if ok and IsText(version) and version ~= "" then
		return version
	end
	return nil
end

-- Toggles the handles through the command the player types.
local function ToggleMovers()
	local module = ns.modules and ns.modules.movers
	local command = module and module.slash and module.slash.move
	if type(command) == "function" then
		local ok, err = pcall(command, "")
		if not ok then
			geterrorhandler()(err)
		end
	end
end

-- Shows the parts of the options pages, or the root of the mode that has the window, and the title of whichever it is.
local function SetParts()
	local mode = ui.mode
	for _, part in ipairs(ui.optionParts or {}) do
		part:SetShown(mode == nil)
	end
	if ui.modeRoot and ui.modeRoot ~= (mode and mode.root) then
		ui.modeRoot:Hide()
	end
	ui.modeRoot = mode and mode.root or nil
	if ui.modeRoot then
		ui.modeRoot:Show()
	end
	ui.barTitle:SetText(mode and mode.title or "Flat UI")
	if ui.barVersion then
		ui.barVersion:SetShown(mode == nil)
	end
	ui.barCounter:SetShown(mode ~= nil)
	-- The buttons of the options pages are at the right of the strip; a mode has the whole width.
	ui.strip:SetWidth(mode and WIDTH - 24 or WIDTH - 24 - 330)
end

-- Gives the window to a mode (a table with title, Build(window) that returns its root frame, Enter, Update, Frame(seconds), Hidden and Close), or back
-- to the options pages with nil. The mode builds its root the first time it has the window.
local function SetMode(mode)
	CloseList()
	HideConfirm()
	ui.search:ClearFocus()
	if mode and not mode.root then
		mode.root = mode.Build(ui.window)
	end
	ui.mode = mode
	SetParts()
	ui.tip, ui.message = "", nil
	ShowStrip()
	if mode then
		mode.Enter()
	end
	RefreshAll()
end

local function BuildLeft(window)
	local left = Frame(window)
	left:SetSize(SIDE, HEIGHT - TITLE - STRIP)
	left:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -TITLE)
	ui.left = left
	local back = Fill(left, "BACKGROUND")
	back:SetAllPoints(left)
	local divider = Fill(left, "BORDER")
	divider:SetWidth(1)
	divider:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, 0)
	divider:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)
	Painted(function()
		Solid(back, "sidebar")
		Solid(divider, "line")
	end)

	-- The search field is in the title bar, so that it stays when the sidebar is a rail.
	local box = Field(window, 360, 40)
	box:SetHeight(22)
	box:SetPoint("TOPLEFT", window, "TOPLEFT", 256, -7)
	local hint = Dim(Label(box, "GameFontHighlight", "LEFT"))
	hint:SetPoint("LEFT", box, "LEFT", 8, 0)
	hint:SetText("Search")
	box:SetScript("OnTextChanged", function(self)
		local typed = self:GetText()
		hint:SetShown(not (IsText(typed) and typed ~= ""))
		if not ui.quiet and IsText(typed) then
			Search(typed)
		end
	end)
	box:SetScript("OnArrowPressed", function(_, key)
		SearchKey(key)
	end)
	box:SetScript("OnEnterPressed", function()
		SearchKey("ENTER")
	end)
	-- Escape clears the words and shows the page again.
	box:SetScript("OnEscapePressed", function(self)
		local typed = self:GetText()
		if IsText(typed) and typed ~= "" then
			self:SetText("")
		end
		self:ClearFocus()
	end)
	ui.search = box

	ui.optionParts = { left, box }
	ui.side = ns.PanelNav.Sidebar(left, {
		height = HEIGHT - TITLE - STRIP,
		Model = function()
			return ui.model
		end,
		Current = function()
			return not ui.searching and ui.current or nil
		end,
		Show = Go,
		Setup = function()
			Call("OpenSetup")
		end,
		Movers = ToggleMovers,
		Sections = function(entry)
			local view, list = ui.views[entry], {}
			for number, name in ipairs(entry.sections or {}) do
				if view and view.sections[number] then
					list[#list + 1] = { name = name, number = number }
				end
			end
			return list
		end,
		Scroll = function(entry, number)
			local view = ui.views[entry]
			if view and view.Reveal then
				view.Reveal(number)
			end
			local at = view and view.sections[number]
			if at then
				view.scroller.Scroll(at - 4)
			end
		end,
	})
end

local function BuildRight(window)
	local right = Frame(window)
	right:SetSize(CW, HEIGHT - TITLE - STRIP)
	right:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -TITLE)
	ui.right = right
	ui.optionParts[#ui.optionParts + 1] = right
	local title = Label(right, "GameFontNormalLarge", "LEFT", 420)
	title:SetPoint("TOPLEFT", right, "TOPLEFT", PAD, -14)
	ui.title = title
	local line = Fill(right, "BORDER")
	line:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(HEAD - 1))
	line:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -(HEAD - 1))
	line:SetHeight(1)
	Painted(function()
		Solid(line, "line-faint")
	end)
	ui.head = ns.PanelNav.Header(right, { Toggle = Toggle })
	ui.tabs = ns.PanelTabs.Build(right, {
		top = HEAD,
		Model = function()
			return ui.model
		end,
		Width = function()
			return CW
		end,
		Show = Go,
	})
end

-- Reset page, Reload and Done, at the right of the strip. Reset page sets every setting of the page to its default after a question.
local function BuildFoot(window)
	local foot = Frame(ui.stripFrame)
	foot:SetAllPoints(ui.stripFrame)
	ui.optionParts[#ui.optionParts + 1] = foot
	local done = Button(foot, "Done", 88, function()
		window:Hide()
	end, true)
	done:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
	local reload = Button(foot, "Reload", 88, ns.Reload)
	reload:SetPoint("RIGHT", done, "LEFT", -8, 0)
	ns.SecureReload(reload)
	ui.reset = Button(foot, "Reset page", 100, function()
		local entry = ui.current
		if entry and not entry.profiles and not entry.home then
			local name = ns.PanelTabs.Label(ui.model, entry) or entry.label
			Ask(ns.PanelTrust.Question(entry, name), function()
				for _, item in ipairs(entry.page) do
					-- A row the game holds is not written: its default is the game's, not this page's.
					if item.key and item.kind ~= "list" and item.kind ~= "entries" and not ns.RowLive(item) then
						Write(item, item.default)
					end
				end
				RefreshAll()
			end)
		end
	end)
	ui.reset:SetPoint("RIGHT", reload, "LEFT", -8, 0)
	ui.strip:SetWidth(WIDTH - 24 - 330)
end

local function BuildBars(window)
	local bar = Frame(window)
	bar:SetSize(WIDTH, TITLE)
	bar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
	bar:RegisterForDrag("LeftButton")
	bar:EnableMouse(true)
	bar:SetScript("OnDragStart", function()
		window:StartMoving()
	end)
	bar:SetScript("OnDragStop", function()
		window:StopMovingOrSizing()
		SavePosition()
	end)
	-- Ctrl and the wheel over the title bar set Window scale, 5% a step, between 80% and 150%.
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(_, delta)
		local ok, held = pcall(IsControlKeyDown)
		local scale = ns.Get("panel.scale")
		if ok and held == true and type(delta) == "number" and not ns.IsSecret(delta) and type(scale) == "number" then
			ns.Set("panel.scale", math.max(80, math.min(150, scale + (delta > 0 and 5 or -5))))
		end
	end)
	local back = Fill(bar, "BACKGROUND")
	back:SetAllPoints(bar)
	local line = Fill(bar, "BORDER")
	line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	line:SetHeight(1)
	Painted(function()
		Solid(back, "window")
		Solid(line, "line")
	end)
	local title = Label(bar, "GameFontNormal", "LEFT")
	title:SetPoint("LEFT", bar, "LEFT", PAD, 0)
	title:SetText("Flat UI")
	ui.barTitle = title
	local version = Version()
	if version then
		local number = Dim(Label(bar, "GameFontHighlightSmall", "LEFT"))
		number:SetPoint("LEFT", title, "RIGHT", 8, -1)
		number:SetText(version)
		ui.barVersion = number
	end
	-- What a mode says beside its title, such as the step it is at.
	local counter = Dim(Label(bar, "GameFontHighlightSmall", "LEFT"))
	counter:SetPoint("LEFT", title, "RIGHT", 8, -1)
	counter:Hide()
	ui.barCounter = counter
	-- A mode takes the Close button: it may ask before it closes.
	local close = Button(bar, "Close", 60, function()
		if ui.mode and ui.mode.Close then
			ui.mode.Close()
		else
			window:Hide()
		end
	end)
	close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)

	local strip = Frame(window)
	strip:SetSize(WIDTH, STRIP)
	strip:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
	ui.stripFrame = strip
	local back2 = Fill(strip, "BACKGROUND")
	back2:SetAllPoints(strip)
	local line2 = Fill(strip, "BORDER")
	line2:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
	line2:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
	line2:SetHeight(1)
	Painted(function()
		Solid(back2, "window")
		Solid(line2, "line")
	end)
	local text = Label(strip, "GameFontHighlightSmall", "LEFT", WIDTH - 24, true)
	text:SetJustifyV("MIDDLE")
	text:SetPoint("TOPLEFT", strip, "TOPLEFT", 12, -4)
	text:SetHeight(STRIP - 8)
	ui.strip = text
end

local function Build()
	-- The height of a row is read here, since the account is loaded by now.
	ROW = Look.RowHeight()
	ns.PanelKit.ROW = ROW
	ui.shape = Look.Get("density") .. "/" .. Look.Get("sidebar") .. "/" .. Look.Get("sections")
	SIDE = Look.SideWidth()
	CW = WIDTH - SIDE
	ui.model = BuildModel()
	ns.PanelHome.Start()
	local window = CreateFrame("Frame", NAME, UIParent)
	ns.Own[window] = true
	ui.window = window
	window:SetSize(WIDTH, HEIGHT)
	window:SetFrameStrata("HIGH")
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	local outline = ns.Outline(window, window, true)
	Painted(function()
		Backing(outline, "window", 0.98, "line")
	end)
	ui.paintKey = Look.Key()
	BuildBars(window)
	BuildLeft(window)
	BuildRight(window)
	BuildFoot(window)
	window:SetScript("OnShow", RefreshAll)
	window:SetScript("OnHide", function()
		-- Under the setting that sends windows back when they close, the options window opens at its default place.
		if ns.Get("movers.keepSpots") == "reset" then
			Look.ClearPosition()
		end
		CloseList()
		HideConfirm()
		ui.search:ClearFocus()
		-- Any hide ends a mode; the mode keeps what it needs to open again where it was.
		if ui.mode then
			local mode = ui.mode
			ui.mode.Hidden()
			if ui.mode == mode then
				ui.mode = nil
				SetParts()
			end
		end
	end)
	local elapsed = 0
	window:SetScript("OnUpdate", function(_, seconds)
		if ui.mode and ui.mode.Frame then
			ui.mode.Frame(seconds)
		end
		if ui.flash then
			Fade(seconds)
		end
		elapsed = elapsed + seconds
		if elapsed >= REFRESH then
			elapsed = 0
			RefreshAll()
		end
	end)
	-- Escape closes it, as it closes the windows the game lists here.
	if type(UISpecialFrames) == "table" then
		local listed = false
		for _, name in ipairs(UISpecialFrames) do
			listed = listed or name == NAME
		end
		if not listed then
			table.insert(UISpecialFrames, NAME)
		end
	end
	window:Hide()
	-- The first time it opens on Home; after that on the page it was left on.
	local key = Look.Page()
	ShowPage((key == "profiles" and ui.model.profiles) or ui.model.byKey[key] or ui.model.home)
end

-- A change of the look while the window exists. Colours, borders and corners are painted again, a font is set again, and a Density or a Sidebar
-- builds the rows again, since a row is built at its height and a page at the width of its column. A pair seen before has its pages already.
local function Rebuild()
	ROW = Look.RowHeight()
	ns.PanelKit.ROW = ROW
	for _, view in pairs(ui.views) do
		view.scroller.frame:Hide()
	end
	-- The pages built for a density and a sidebar are kept and shown again when they come back.
	ui.sets = ui.sets or {}
	ui.sets[ui.shape] = ui.views
	ui.shape = Look.Get("density") .. "/" .. Look.Get("sidebar") .. "/" .. Look.Get("sections")
	SIDE = Look.SideWidth()
	CW = WIDTH - SIDE
	ui.left:SetWidth(SIDE)
	ui.right:SetWidth(CW)
	ui.views, ui.view = ui.sets[ui.shape] or {}, nil
	-- The search view has no cards, so a change of Sections keeps it.
	local base = Look.Get("density") .. "/" .. Look.Get("sidebar")
	if ui.searchView and ui.searchBase ~= base then
		ui.searchView.scroller.frame:Hide()
		ui.searchView = nil
	end
	local typed = ui.search:GetText()
	if ui.searching and IsText(typed) and typed ~= "" then
		Search(typed)
	else
		ShowPage(ui.current)
	end
end

function Look.onChange(key)
	if not ui.window then
		return
	end
	if key == "scale" then
		ApplyScale()
		-- A larger window grows from its corner and may reach past the screen: it goes back to the middle.
		if ui.window:IsShown() and not OnScreen() then
			ui.window:ClearAllPoints()
			ui.window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			Look.ClearPosition()
		end
	elseif key == "font" then
		Look.ApplyFonts()
		if ui.current and ui.tabs and not ui.searching and not ui.mode then
			ui.tabs.Set(ui.current)
		end
	elseif key == "density" or key == "sidebar" then
		Look.ApplyFonts()
		Rebuild()
	elseif key == "sections" then
		Rebuild()
	elseif key == "samples" then
		-- Each dropdown places its sample again when its row is refreshed.
		RefreshAll()
	else
		ui.paintKey = nil
		Repaint()
	end
end

function ns.OpenPanel()
	if not ui.window then
		if InCombatLockdown() then
			if not ui.waiting then
				ui.waiting = true
				print("Options open after combat.")
				ns.OutOfCombat(function()
					ui.waiting = false
					if not ui.window then
						Build()
						Place()
					end
				end)
			end
			return false
		end
		Build()
	end
	if ui.window:IsShown() then
		ui.window:Hide()
	else
		Place()
	end
	return ui.window:IsShown() == true
end

-- The widgets and measures of the window, for a mode that has the window (Setup.lua). Each is the one the options pages use.
ns.PanelKit = {
	Frame = Frame, Fill = Fill, Label = Label, Dim = Dim, Tint = Tint, Clickable = Clickable, Button = Button, Field = Field,
	Scroller = Scroller, Dropdown = Dropdown, NewRow = NewRow, BuildRow = BuildRow, IsOpen = IsOpen, Unmet = Unmet, Header = Header, Painted = Painted,
	Solid = Solid, Backing = Backing, Accent = Accent, Shade = Shade, Clamp = Clamp, Rect = Rect, IsText = IsText, Cursor = Cursor, Drag = Drag,
	Say = Say, Ask = Ask, CloseList = CloseList, OpenList = OpenList, Read = Read, Write = Write,
	Bool = AddBool,
	Window = function() return ui.window end,
	Inset = function(parent, inset) insets[parent] = inset end,
	Tip = function(text) ui.message, ui.tip = nil, text or "" ShowStrip() end, Refresh = function() RefreshAll() end,
	Hide = function() if ui.window then ui.window:Hide() end end,
	SetCounter = function(text) if ui.barCounter then ui.barCounter:SetText(text or "") end end,
	WIDTH = WIDTH, HEIGHT = HEIGHT, TITLE = TITLE, LEFT = LEFT, STRIP = STRIP, HEADER = HEADER, RIGHT_W = RIGHT_W, PAD = PAD, ROW = ROW,
	ROW_W = ROW_W, SECTION = SECTION, LABEL = LABEL, CONTROL = CONTROL, FIELD = FIELD, SMALL = SMALL, BUTTON = BUTTON,
}

-- Opens the window in a mode (see SetMode), or leaves it in that mode when it is in it already. In combat before the window was ever built the
-- mode opens after combat, and mode.waiting is what is said meanwhile. Returns true when the window shows the mode now.
function ns.OpenPanelMode(mode)
	if not ui.window then
		if InCombatLockdown() then
			if not ui.waiting then
				ui.waiting = true
				print(mode.waiting or "Options open after combat.")
				ns.OutOfCombat(function()
					ui.waiting = false
					if not ui.window then
						Build()
						SetMode(mode)
						Place()
					end
				end)
			end
			return false
		end
		Build()
	end
	if ui.mode ~= mode then
		SetMode(mode)
	end
	if not ui.window:IsShown() then
		Place()
	end
	return ui.window:IsShown() == true
end

-- Opens the window at the Share section of Profiles, and leaves it open when it is open already.
function ns.OpenPanelShare()
	if not (ui.window and ui.window:IsShown()) then
		ns.OpenPanel()
	end
	if not (ui.window and ui.window:IsShown()) then
		return false
	end
	ShowPage(ui.model.profiles)
	local view = ui.views[ui.model.profiles]
	local at = view and view.sections[3]
	if at then
		view.scroller.Scroll(at - 4)
	end
	return true
end

function ns.PanelShown()
	return ui.window ~= nil and ui.window:IsShown() == true
end

-- True while a mode (setup) has the window.
function ns.PanelInMode()
	return ui.mode ~= nil
end

-- The mode that has the window now (Setup.lua), or nil for the options pages.
function ns.PanelMode()
	return ui.mode
end

-- Reads every control on screen again.
function ns.RefreshPanel()
	if ui.window and ui.window:IsShown() then
		RefreshAll()
	end
end

-- The game calls this from the add-on compartment in the minimap.
function FlatUI_OnAddonCompartmentClick()
	ns.OpenPanel()
end

-- A Flat UI button in the game menu, right below the gap under Options. It is a frame of its own: the menu's layout places any shown child that
-- has a layoutIndex, so nothing of the game's menu is written. The hook runs after each build of the menu's buttons.
do
	local button
	local function OpenOptions()
		if ns.PanelInMode() then
			ns.PanelKit.Hide()
		end
		if not ns.PanelShown() then
			ns.OpenPanel()
		end
	end
	local function Click()
		if InCombatLockdown() then
			return
		end
		if type(PlaySound) == "function" and type(SOUNDKIT) == "table" then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		end
		HideUIPanel(GameMenuFrame)
		local ok, err = pcall(ns.Get("general.menuOpens") == "options" and OpenOptions or ns.OpenSetup)
		if not ok then
			geterrorhandler()(err)
		end
	end
	local function Place(menu)
		if not button then
			button = CreateFrame("Button", nil, menu, "MainMenuFrameButtonTemplate")
			button:SetText("Flat UI")
			button:SetScript("OnClick", Click)
			button:RegisterEvent("PLAYER_REGEN_DISABLED")
			button:RegisterEvent("PLAYER_REGEN_ENABLED")
			button:SetScript("OnEvent", function(self, event) self:SetEnabled(event == "PLAYER_REGEN_ENABLED") end)
		end
		local anchor, seen
		if ns.Get("general.menuButton") then
			for _, each in ipairs(menu.buttons or {}) do
				if seen and each.topPadding and each.layoutIndex then
					anchor = each
					break
				end
				seen = seen or each:GetText() == GAMEMENU_OPTIONS
			end
		end
		if anchor then
			button.layoutIndex, button.topPadding, button.bottomPadding = anchor.layoutIndex - 0.5, anchor.topPadding, -anchor.topPadding
			button:SetEnabled(not InCombatLockdown())
			button:Show()
		else
			button.layoutIndex = nil
			button:Hide()
		end
	end
	local menu = GameMenuFrame
	if menu and type(menu.InitButtons) == "function" then
		hooksecurefunc(menu, "InitButtons", Place)
	end
end
