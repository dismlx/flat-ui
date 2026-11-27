local ADDON_NAME, ns = ...

local NAME = "FlatUIOptionsFrame"
local WIDTH, HEIGHT, LEVEL = 1040, 680, 500
local TITLE = 36
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
local FADE_IN, CONFIRM_FADE = 0.12, 0.08
local Look = ns.PanelLook
local PROFILE_CALLS = { "Profile", "Profiles", "UseProfile" }

local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

local ui = { views = {}, nav = {}, lines = {}, paints = {}, tip = "" }

local OpenList, CloseList, Ask, HideConfirm, ShowStrip, RefreshAll, ShowPage, Arrive

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function Ratio(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and okBase and Number(scale) and Number(base) and scale > 0 and base > 0 then
		return scale / base, base
	end
	return nil
end

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

local function Shade(spec)
	return Look.Colour(spec)
end

local function Accent()
	return Look.Colour("accent")
end

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

local function Clickable(frame, onClick)
	local down = false
	frame:EnableMouse(true)
	frame:SetScript("OnMouseDown", function(_, button)
		down = button == "LeftButton"
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		local wanted = down and button == "LeftButton"
		down = false
		if not wanted then
			return
		end
		local ok, over = pcall(self.IsMouseOver, self)
		if not ok or ns.IsSecret(over) or over ~= false then
			onClick()
		end
	end)
end

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

local function SwitchClick(on)
	if type(PlaySound) == "function" and type(SOUNDKIT) == "table" then
		local sound = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
		if sound then
			pcall(PlaySound, sound)
		end
	end
end

local SLIDE = 0.08
local function Slider(knob, track, frame)
	local x, from, to, spent
	local function Put(at)
		knob:ClearAllPoints()
		knob:SetPoint("LEFT", track, "LEFT", at, 0)
	end
	local function Step(_, seconds)
		spent = spent + (Number(seconds) and seconds or SLIDE)
		local done = math.min(1, spent / SLIDE)
		x = from + (to - from) * done
		Put(x)
		if done >= 1 then
			frame:SetScript("OnUpdate", nil)
		end
	end
	return function(on, instant)
		local goal = on and 18 or 2
		if instant or x == nil or not frame:IsVisible() then
			x, to = goal, goal
			frame:SetScript("OnUpdate", nil)
			Put(goal)
		elseif goal ~= to then
			from, to, spent = x, goal, 0
			frame:SetScript("OnUpdate", Step)
		end
	end
end

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
	local hover, pressed = false, false
	local tone = primary and "accent" or nil
	local function Tone()
		local lit = hover and not pressed
		if tone == "accent" then
			return lit and "accent-hover" or "accent"
		elseif tone == "danger" then
			return "danger"
		end
		return lit and "hover" or "raised"
	end
	local function Paint()
		Backing(outline, Tone(), (tone == "danger" and hover and not pressed) and 0.85 or 1, "line-strong")
	end
	Painted(Paint)
	Clickable(button, onClick)
	local function Press(down)
		if down ~= pressed then
			pressed = down
			label:SetPoint("CENTER", button, "CENTER", 0, down and -1 or 0)
			Paint()
		end
	end
	ui.presses = ui.presses or setmetatable({}, { __mode = "k" })
	ui.presses[button] = Press
	button:HookScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			Press(true)
		end
	end)
	button:HookScript("OnMouseUp", function()
		Press(false)
	end)
	button:HookScript("OnHide", function()
		Press(false)
	end)
	button:SetScript("OnEnter", function()
		hover = true
		Paint()
	end)
	button:SetScript("OnLeave", function()
		hover = false
		Paint()
	end)
	local function SetTone(new)
		if new ~= tone then
			tone = new
			Tint(label, new and "on-accent" or "text")
			Paint()
		end
	end
	return button, label, SetTone
end

local function Field(parent, width, limit, onLost, hint)
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
	if not hint then
		return box
	end
	local note = Dim(Label(box, "GameFontHighlight", "LEFT", width - 16))
	note:SetPoint("LEFT", box, "LEFT", 8, 0)
	note:SetText(hint)
	local function Sync()
		local typed = box:GetText()
		note:SetShown(not (IsText(typed) and typed ~= ""))
	end
	box:HookScript("OnTextChanged", Sync)
	Sync()
	return box, note
end

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

local function Unmet(page, item)
	for _, needed in ipairs(Needed(page, item)) do
		if not ns.NeedMet(item, needed) then
			return needed
		end
	end
end

local function Over(item)
	local call = IsText(item.overIf) and ns[item.overIf]
	if type(call) ~= "function" then
		return false
	end
	local ok, over = pcall(call)
	return ok and over == true
end

local function IsOpen(page, item)
	return Unmet(page, item) == nil and not Over(item)
end

local SAY_HOLD, SAY_FADE, SAY_FROM = 6, 0.15, 0.4

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

local function Say(message)
	if IsText(message) and message ~= "" then
		local again = ui.message == message
		ui.message, ui.messageAt = message, Now()
		if not again and ui.strip then
			ui.sayFade = 0
			ui.strip:SetAlpha(SAY_FROM)
		end
		ShowStrip()
	end
end

local function CopyField(box)
	box:HookScript("OnEditFocusGained", function(self)
		self:HighlightText()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if self:HasFocus() then
					self:HighlightText()
				end
			end)
		end
	end)
	box:SetScript("OnKeyDown", function(self, key)
		local text = self:GetText()
		if key == "C" and type(IsControlKeyDown) == "function" and IsControlKeyDown() and IsText(text) and text ~= "" then
			Say("Copied. Paste it where you share it.")
		end
	end)
end

local insets = setmetatable({}, { __mode = "k" })

local function NewRow(parent, y, text, tip)
	local row = { active = true, tip = tip or "" }
	local inset = insets[parent] or PAD
	local frame = Frame(parent)
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
	row.label = label
	if ui.collect and IsText(text) and not ui.collect[text] then
		ui.collect[text] = row
	end
	function row.Place(top)
		row.top = top
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -top)
		frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -top)
	end
	function row.Changed()
		RefreshAll()
	end
	function row.Hover(target, enter, leave)
		local ownEnter, ownLeave = target:GetScript("OnEnter"), target:GetScript("OnLeave")
		target:SetScript("OnEnter", function()
			if ownEnter then
				ownEnter(target)
			end
			hover:Show()
			if ui.mode then
				ui.message = nil
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
			if ownLeave then
				ownLeave(target)
			end
		end)
	end
	row.Hover(frame)
	row.Place(y)
	return row
end

function ui.Block(row, active)
	if not row.block then
		local block = Frame(row.frame)
		block:SetAllPoints(row.frame)
		block:SetFrameLevel(row.frame:GetFrameLevel() + 8)
		Clickable(block, function()
			if ui.ToNeed then
				ui.ToNeed(row)
			end
		end)
		row.Hover(block)
		row.block = block
	end
	row.block:SetShown(not active)
end

local function SetActive(row, active)
	if row.active ~= active then
		row.active = active
		row.frame:SetAlpha(active and 1 or DIM)
	end
	if row.item and (row.block or not active) then
		ui.Block(row, active)
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

local function Dropdown(row, width, spec)
	local button = Frame(row.frame)
	button:SetSize(width, BUTTON)
	local outline = ns.Outline(button, button, true)
	local text = Label(button, "GameFontHighlight", "LEFT", width - 32)
	text:SetPoint("LEFT", button, "LEFT", 8, 0)
	Chevron(button)
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

local editor = {}

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
		ns.PanelHome.Noted(item, before, ns.Get(item.path), ui.batch)
	end
	return result
end

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
	local on
	local Place = Slider(knob, box, box)
	local function Knob()
		if on ~= nil then
			Place(on)
		end
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
			SwitchClick(Read(item) == true)
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
	local unit = Dim(Label(row.frame, "GameFontHighlightSmall", "LEFT", item.overText and 160 or 90))
	unit:SetPoint("LEFT", box, "RIGHT", 10, 0)
	local plain = ((item.unit or ""):gsub("^%s+", ""))
	unit:SetText(plain)
	local function Show()
		local value = Read(item)
		local fraction = Clamp((value - item.min) / (item.max - item.min), 0, 1)
		bar:SetWidth(math.max(1, fraction * TRACK))
		thumb:SetPoint("CENTER", track, "LEFT", fraction * TRACK, 0)
		local over = IsText(item.overText) and Over(item)
		if item.overText then
			unit:SetText(over and item.overText or plain)
		end
		if not box:HasFocus() then
			box:SetText(over and "" or ("%g"):format(value))
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
	local function Wheel(_, delta)
		local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
		if shift or box:HasFocus() then
			if row.active then
				Write(item, Read(item) + (delta > 0 and 1 or -1) * item.step)
				if box:HasFocus() then
					box:SetText(("%g"):format(Read(item)))
				end
				row.Changed()
			end
			return
		end
		local frame = track:GetParent()
		for _ = 1, 8 do
			if not frame then
				return
			end
			local ok, kind = pcall(frame.GetObjectType, frame)
			if ok and kind == "ScrollFrame" then
				local script = frame:GetScript("OnMouseWheel")
				if script then
					script(frame, delta)
				end
				return
			end
			frame = frame:GetParent()
		end
	end
	track:EnableMouseWheel(true)
	track:SetScript("OnMouseWheel", Wheel)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(("%g"):format(Read(item)))
		self:ClearFocus()
	end)
	box:EnableMouseWheel(true)
	box:SetScript("OnMouseWheel", Wheel)
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
	Clickable(swatch, function()
		if row.active and ns.PanelColour then
			ns.PanelColour.Open(Read(item), item.alpha == true, Set)
		end
	end)
	local menu = { frame = swatch }
	local function Pasted()
		local copied, now = ui.copiedColour, Read(item)
		if not (copied and IsText(now) and #now == 8) then
			return nil
		end
		local value = (item.alpha == true and copied.alpha) and copied.value or now:sub(1, 2) .. copied.value:sub(3)
		return value ~= now and value or nil
	end
	swatch:HookScript("OnMouseUp", function(self, button)
		if button ~= "RightButton" or not row.active then
			return
		end
		local ok, over = pcall(self.IsMouseOver, self)
		if ok and not ns.IsSecret(over) and over == false then
			return
		end
		OpenList(menu, {
			lines = function()
				local now, lines = Read(item), {}
				if IsText(now) and #now == 8 then
					lines[#lines + 1] = { "copy", "Copy #" .. now:sub(3):upper() }
				end
				local paste = Pasted()
				if paste then
					lines[#lines + 1] = { "paste", "Paste #" .. paste:sub(3):upper() }
				end
				return lines
			end,
			pick = function(id)
				local now = Read(item)
				if id == "copy" and IsText(now) and #now == 8 then
					ui.copiedColour = { value = now, alpha = item.alpha == true }
					if ns.PanelColour and ns.PanelColour.Remember then
						ns.PanelColour.Remember(now)
					end
					Say(("Copied #%s. Right-click another colour to paste it."):format(now:sub(3):upper()))
				elseif id == "paste" then
					local paste = Pasted()
					if paste then
						Set(paste)
						Say(("Pasted #%s into %s. Ctrl+Z puts it back."):format(paste:sub(3):upper(), IsText(item.label) and item.label or "this colour"))
					end
				end
			end,
		})
	end)
	row.Hover(swatch, function()
		local tip = (IsText(row.tip) and row.tip ~= "" and row.tip .. " " or "") .. "Right-click: copy or paste."
		if ui.mode then
			ui.tip = tip
			ShowStrip()
		elseif ns.PanelTrust then
			ns.PanelTrust.Show(swatch, tip, row.need)
		end
	end)
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

local soundKits
local function SoundKits(item)
	if not soundKits then
		soundKits = {}
		for _, sound in ipairs(type(ns.SOUNDS) == "table" and ns.SOUNDS or {}) do
			soundKits[sound[2]] = sound[1]
		end
	end
	local kits, count = {}, 0
	for _, line in ipairs(ns.Choices(item)) do
		local kit = soundKits[line[2]]
		if kit then
			kits[line[1]] = kit
			count = count + 1
		end
	end
	return count >= 3 and kits or nil
end

local function AddChoice(row, item)
	if item.segments and ns.PanelCards then
		return ns.PanelCards.Segments(row, item)
	end
	local kits = SoundKits(item)
	local function Play(value)
		if kits and kits[value] and type(ns.PlayKit) == "function" then
			ns.PlayKit(kits[value])
		end
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
			local shown = row.frame:IsVisible()
			Write(item, value)
			row.Changed()
			if shown and not InCombatLockdown() then
				Play(value)
			end
		end,
	})
	menu.frame:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	local play
	if kits then
		play = Button(row.frame, "Play", 52, function()
			if not row.active then
				return
			elseif kits[Read(item)] then
				Play(Read(item))
			else
				Say("None plays no sound.")
			end
		end)
		play:SetPoint("LEFT", row.frame, "LEFT", CONTROL + FIELD + 10, 0)
		row.Hover(play)
	end
	return function()
		menu.SetText(Chosen(ns.Choices(item), Read(item)) or "")
		menu.SetSample(Read(item))
		if play then
			play:SetAlpha(kits[Read(item)] and 1 or DIM)
		end
	end
end

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
			if type(item.act) == "function" then
				local ok, err = pcall(item.act, id)
				if not ok then
					geterrorhandler()(err)
				end
				row.Changed()
				return
			end
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

local function BuildRow(parent, page, item, y)
	local row = NewRow(parent, y, item.label, item.tip)
	row.item = item
	row.entered = function()
		if ui.preview then
			ui.preview.Mark(item.path)
		end
	end
	row.left = function()
		if ui.preview then
			ui.preview.Mark(nil)
		end
	end
	local ok, show = pcall(ADD[item.kind], row, item)
	if not ok then
		geterrorhandler()(show)
		row.frame:Hide()
		return nil
	end
	local mark = ns.PanelTrust and ns.PanelTrust.Attach(row, item)
	function row.Update()
		local unmet = Unmet(page, item)
		row.unmet, row.over = unmet, unmet == nil and Over(item)
		SetActive(row, unmet == nil and not row.over)
		show()
		if mark then
			mark(unmet)
		end
	end
	return row
end

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

function editor.Stepped(item, value)
	if item.kind == "number" and Number(value) and item.step and item.min and item.max then
		return Clamp(math.floor((value - item.min) / item.step + 0.5) * item.step + item.min, item.min, item.max)
	end
	return value
end

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
			return ns.Get(type(ns.TrackerAmmoRow) == "function" and ns.TrackerAmmoRow(block.current.id) or "trackers.ammoMin")
		elseif key == "low" and block.current and block.current.kind == "item" then
			return math.max(0, (ns.Get("trackers.itemMin") or 1) - 1)
		elseif key == "low" and block.current and block.current.kind == "durability" then
			return ns.Get("trackers.durabilityMin")
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
	ui.listSearch = Field(list, FIELD - 8, 40)
	ui.listSearch:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -2)
	local filterHint = Dim(Label(ui.listSearch, "GameFontHighlightSmall", "LEFT"))
	filterHint:SetPoint("LEFT", ui.listSearch, "LEFT", 8, 0)
	filterHint:SetText("Type to filter")
	ui.listSearch:SetScript("OnTextChanged", function(self)
		local typed = self:GetText()
		filterHint:SetShown(not (IsText(typed) and typed ~= ""))
		if ui.listOwner and ui.listSearch:IsShown() then
			ui.ShowLines(false)
		end
	end)
	ui.listSearch:SetScript("OnEnterPressed", function()
		local line = ui.lines[1]
		local pick = ui.listSpec and ui.listSpec.pick
		if line and line.live and pick and line.frame:IsShown() then
			local value = line.value
			CloseList()
			pick(value)
		end
	end)
	ui.listSearch:SetScript("OnEscapePressed", function()
		CloseList()
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
	function ui.AnswerYes()
		local run = ui.onYes
		HideConfirm()
		if run then
			run()
		end
	end
	local yes, yesText, yesTone = Button(confirm, "Yes", SMALL, ui.AnswerYes)
	yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 14)
	local note = Dim(Label(confirm, "GameFontHighlightSmall", "CENTER", 330))
	note:SetPoint("TOP", confirm, "TOP", 0, -68)
	note:SetText("Enter does not answer this.")
	note:Hide()
	ui.careNote, ui.yesTone = note, yesTone
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
	if search > 0 then
		ui.listSearch:SetFocus()
	end
end

function Ask(question, onYes, onNo, yesText, noText, careful)
	BuildPopups()
	CloseList()
	ui.question:SetText(question)
	local ok, tall = pcall(ui.question.GetStringHeight, ui.question)
	local qh = math.max(44, (ok and Number(tall)) and math.ceil(tall) or 44)
	ui.careNote:ClearAllPoints()
	ui.careNote:SetPoint("TOP", ui.confirm, "TOP", 0, -(18 + qh + 6))
	ui.onYes, ui.onNo, ui.careful = onYes, onNo, careful == true
	local wide = yesText ~= nil or noText ~= nil
	ui.yesText:SetText(yesText or "Yes")
	ui.noText:SetText(noText or "No")
	ui.yes:SetWidth(wide and 130 or SMALL)
	ui.no:SetWidth(wide and 130 or SMALL)
	ui.yesTone(ui.careful and "danger" or "accent")
	ui.careNote:SetShown(ui.careful)
	ui.confirm:SetHeight(110 + (qh - 44) + (ui.careful and 16 or 0))
	local waited = 0
	ui.confirm:SetAlpha(0)
	ui.confirm:SetScript("OnUpdate", function(self, elapsed)
		waited = waited + (Number(elapsed) and elapsed or CONFIRM_FADE)
		if waited >= CONFIRM_FADE then
			self:SetAlpha(1)
			self:SetScript("OnUpdate", nil)
		else
			self:SetAlpha(waited / CONFIRM_FADE)
		end
	end)
	ui.confirm:Show()
	SyncShade()
end

function HideConfirm()
	if ui.confirm and ui.confirm:IsShown() then
		ui.onYes, ui.onNo, ui.careful = nil, nil, nil
		ui.confirm:SetScript("OnUpdate", nil)
		ui.confirm:SetAlpha(1)
		ui.confirm:Hide()
		SyncShade()
	end
end

function ui.EscapeAction()
	if ns.PanelColour and ns.PanelColour.Shown() then
		return ns.PanelColour.Cancel
	elseif ui.listOwner then
		return CloseList
	elseif ui.confirm and ui.confirm:IsShown() then
		return HideConfirm
	end
	return nil
end

local function BuildModel()
	local model = { pages = {}, byKey = {} }
	for index, page in ipairs(ns.PAGES) do
		if index == 1 or ns.PageHasRows(page, true) then
			local entry = { key = page.key, label = page.label, parent = page.parent, page = page, sections = {} }
			for _, item in ipairs(page) do
				if item.section then
					entry.sections[#entry.sections + 1] = item.section
				elseif item.key == "enabled" and item.kind == "bool" and not item.page and not entry.switchItem then
					entry.switchItem = item
				end
			end
			local from = page.owner or page.switch
			if not page.parent and not entry.switchItem and from and from ~= page.key then
				entry.partOf = from
				local switch = from ~= "general" and ns.Def(from .. ".enabled") or nil
				if switch and switch.kind == "bool" then
					entry.switchItem = switch
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
		elseif item.kind == "entries" then
			y = y + editor.Add(scroller.child, entry.page, item, y, view)
			if cards then
				cards.Static()
			end
		elseif cards and cards.chipped[item] then
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

local function KeepProfile(pick)
	local current = Call("Profile")
	current = IsText(current) and current or ""
	local switch = ns.ProfileSwitch
	local keeps = type(switch) == "table" and type(switch.Keep) == "function" and type(switch.Wanted) == "function"
	if not IsText(pick) or pick == current then
		local had = keeps and switch.Wanted() ~= nil
		if keeps then
			switch.Keep(nil)
		end
		Say(had and ("Stays on %s."):format(current) or ("Using %s."):format(current))
	elseif keeps then
		switch.Keep(pick)
		Say(("Switches to %s when the fight ends."):format(pick))
	else
		Say("Profiles change after the fight.")
	end
	RefreshAll()
	return false
end

local function Act(name, ...)
	if name == "UseProfile" and InCombatLockdown() then
		return KeepProfile(...)
	end
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

function ui.DeleteQuestion(name)
	local back = "Bring back puts it back until you reload."
	local db, count = ns.Account(), 0
	local me = type(ns.CharacterKey) == "function" and ns.CharacterKey() or nil
	for key, used in pairs(type(db) == "table" and type(db.profileOf) == "table" and db.profileOf or {}) do
		if used == name and key ~= me then
			count = count + 1
		end
	end
	local names = ns.PanelHome and ns.PanelHome.UserNames and ns.PanelHome.UserNames(name)
	if type(names) == "table" and #names == count and count >= 1 and count <= 3 then
		local who = count == 1 and names[1] or ("%s and %s"):format(table.concat(names, ", ", 1, count - 1), names[count])
		return ('Delete "%s"? %s %s it and start%s as %s at their next login. %s'):format(name, who, count == 1 and "uses" or "use",
			count == 1 and "s" or "", count == 1 and "a new character" or "new characters", back)
	end
	if count == 0 then
		return ('Delete "%s"? No other character uses it. %s'):format(name, back)
	elseif count == 1 then
		return ('Delete "%s"? 1 other character uses it and starts as a new character at its next login. %s'):format(name, back)
	end
	return ('Delete "%s"? %d other characters use it and start as new characters at their next login. %s'):format(name, count, back)
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
	ui.collect = {}
	local function Row(text, tip)
		local row = NewRow(child, y, text, tip)
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
		row.Hover(button)
		return button
	end
	local function Current()
		local name = Call("Profile")
		return IsText(name) and name or ""
	end

	view.sections[1] = y
	y = Header(child, "Profile", y)
	local row = Row("Profile in use", "The profile this character uses. Pick another to switch to it at once; picked in a fight, it switches as the "
		.. "fight ends.")
	local Home = ns.PanelHome
	local used = Menu(row, {
		lines = function()
			local lines = ProfileNames(function() return true end)
			for _, line in ipairs(lines) do
				local count = Home and Home.UserCount and Home.UserCount(line[1]) or 0
				if count > 0 then
					line[2] = ("%s  (%d)"):format(line[1], count)
				end
			end
			return lines
		end,
		selected = Current,
		pick = function(name)
			Act("UseProfile", name)
		end,
	})
	local users = Dim(Label(row.frame, "GameFontHighlightSmall", "LEFT", ROW_W - CONTROL - FIELD - 10))
	users:SetPoint("LEFT", row.frame, "LEFT", CONTROL + FIELD + 10, 0)
	updates[#updates + 1] = function()
		local now = Current()
		used.SetText(now)
		users:SetText(now ~= "" and Home and Home.UsedBy and Home.UsedBy(now) or "")
	end

	if type(ns.NewProfile) == "function" then
		row = Row("New profile", "Type a name. Create starts from the defaults and the frame positions a new profile starts with. Duplicate copies the "
			.. "profile in use, its frame positions too, as \"<name> copy\" when no name is typed. The new profile is put in use.")
		local name = Field(row.frame, FIELD, 32, nil, "Name of the new profile")
		name:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		local function Typed()
			local typed = name:GetText()
			typed = IsText(typed) and typed or ""
			return (typed:match("^%s*(.-)%s*$"))
		end
		local function Create()
			if Act("NewProfile", Typed()) then
				name:SetText("")
			end
		end
		local function Duplicate()
			local from, typed = Current(), Typed()
			if typed == "" then
				for number = 1, 9 do
					local candidate = number == 1 and ("%s copy"):format(from) or ("%s copy %d"):format(from, number)
					if Call("ProfileNameCheck", candidate) then
						typed = candidate
						break
					end
				end
			end
			if typed == "" then
				Say("Type a name for the copy.")
			elseif Act("NewProfile", typed, from) then
				name:SetText("")
			end
		end
		name:SetScript("OnEnterPressed", Create)
		row.Hover(name)
		Beside(row, "Create", Create)
		local copy = Button(row.frame, "Duplicate", SMALL, Duplicate)
		copy:SetPoint("LEFT", row.frame, "LEFT", CONTROL + FIELD + 10 + SMALL + 8, 0)
		row.Hover(copy)
		if type(ns.OpenSetup) == "function" then
			row = Row("Setup", "Set up my screen walks round your screen in six short stops and saves what you pick. Ready-made looks shows finished "
				.. "profiles; a click puts one in use.")
			local start, text = Button(row.frame, "Set up my screen", 170, function()
				Call("OpenSetup")
			end)
			start:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
			row.Hover(start)
			updates[#updates + 1] = function()
				text:SetText(Call("SetupHasDraft") and "Continue setup" or "Set up my screen")
			end
			local ready = Button(row.frame, "Ready-made looks", 170, function()
				Call("OpenProfiles")
			end)
			ready:SetPoint("LEFT", start, "RIGHT", 8, 0)
			row.Hover(ready)
		end
	end

	if type(ns.CopyProfile) == "function" then
		row = Row("Copy from", "Replaces every setting and frame position of the profile in use with those of another profile. Bring back puts them back until you reload; to keep both, use Duplicate.")
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
				Ask(('Replace "%s" with a copy of "%s"? Bring back puts it back until you reload.'):format(Current(), from), function()
					Act("CopyProfile", from)
				end, nil, "Replace", "Keep", true)
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
		row = Row("Delete profile", "Deletes another profile; Bring back puts it back until you reload. The profile in use and Default cannot be deleted.")
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
				Ask(ui.DeleteQuestion(doomed), function()
					Act("DeleteProfile", doomed)
				end, nil, "Delete", "Keep", true)
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
		if type(ns.BringBackDeleted) == "function" and type(ns.DeletedProfile) == "function" then
			local back = Button(row.frame, "Bring back", SMALL + 10, function()
				Act("BringBackDeleted")
			end)
			back:SetPoint("LEFT", row.frame, "LEFT", CONTROL + FIELD + 10 + SMALL + 8, 0)
			row.Hover(back, function()
				local gone = Call("DeletedProfile")
				if IsText(gone) and ns.PanelTrust then
					ns.PanelTrust.Show(back, ("Brings back %s as it was when you deleted it, with the characters that used it and its Switch "
						.. "automatically rules. Until you reload."):format(gone))
				end
			end)
			updates[#updates + 1] = function()
				back:SetShown(IsText(Call("DeletedProfile")))
			end
		end
	end

	if type(ns.RenameProfile) == "function" then
		row = Row("Rename profile", "Gives the profile in use a new name; the characters that use it keep it. Default cannot be renamed.")
		local name, hint = Field(row.frame, FIELD, 32, nil, "New name")
		name:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		updates[#updates + 1] = function()
			local now = Current()
			hint:SetText(now ~= "" and ("New name for %s"):format(now) or "New name")
		end
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
		row = Row("Reset profile", "Every setting of the profile in use goes back to its default, and every frame you moved goes back to its own place. Bring back puts them back until you reload.")
		local reset = Button(row.frame, "Reset", SMALL, function()
			Ask(('Reset "%s"? Every setting and every frame position goes back to its default. Bring back puts them back until you reload.'):format(Current()), function()
				Act("ResetProfile")
			end, nil, "Reset", "Keep", true)
		end)
		reset:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		row.Hover(reset)
		if type(ns.BringBackProfile) == "function" and type(ns.LostProfile) == "function" then
			local back = Button(row.frame, "Bring back", SMALL + 10, function()
				Act("BringBackProfile")
			end)
			back:SetPoint("LEFT", row.frame, "LEFT", CONTROL + SMALL + 8, 0)
			row.Hover(back, function()
				local lost = Call("LostProfile")
				if type(lost) == "table" and ns.PanelTrust then
					local counts = ("%d setting%s"):format(lost.settings, lost.settings == 1 and "" or "s")
					if lost.spots then
						counts = counts .. (", %d frame position%s"):format(lost.spots, lost.spots == 1 and "" or "s")
					end
					local at = IsText(lost.at) and lost.at ~= "" and (" at " .. lost.at) or ""
					ns.PanelTrust.Show(back, ("Puts %s back as it was before %s%s: %s."):format(lost.name, lost.what, at, counts))
				end
			end)
			updates[#updates + 1] = function()
				local lost = Call("LostProfile")
				back:SetShown(type(lost) == "table" and lost.inUse == true)
			end
		end
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
		row = Row("Export profile", "Export writes the profile in use, settings and frame positions, as one line of text to copy and share.")
		local out = Field(row.frame, FIELD, 0, nil, "Press Export, then Ctrl+C")
		out:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		CopyField(out)
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
		row = Row("Export trackers", "Export writes your trackers as one line of text to copy and share.")
		local out = Field(row.frame, FIELD, 0, nil, "Press Export, then Ctrl+C")
		out:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		CopyField(out)
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
		row = Row("Import trackers", "Paste trackers someone exported, then press Import to add them.")
		local into = Field(row.frame, FIELD, 0, nil, "Paste trackers here")
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
		row = Row("Import profile", "Paste a profile someone exported. What it holds shows under the field, with what to import and where.")
		local into = Field(row.frame, FIELD, 0, nil, "Paste a profile here (Ctrl+V)")
		into:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
		row.Hover(into)
		if ns.ProfileShare then
			ns.ProfileShare.Watch(into)
		end
		Beside(row, "Import", function()
			local text = into:GetText()
			if IsText(text) and text:find("%S") then
				if ns.ProfileShare and ns.ProfileShare.Import(text) then
					return
				end
				Ask(('Replace "%s" with the pasted settings? Bring back puts them back until you reload.'):format(Current()), function()
					if Act("ImportProfile", text) then
						into:SetText("")
					end
				end, nil, "Replace", "Keep", true)
			else
				Say("Paste the settings first.")
			end
		end)
	end

	if ns.ProfileShare and type(ns.ExportProfile) == "function" and type(ns.ImportProfile) == "function" then
		y = ns.ProfileShare.Build(ns.PanelKit, child, y, updates, scroller, row)
	end
	view.byLabel, ui.collect = ui.collect, nil

	scroller.SetContent(y + PAD)
	function view.Update()
		for _, update in ipairs(updates) do
			update()
		end
	end
	return view
end

local function CurrentProfile()
	local name = Call("Profile")
	return IsText(name) and name or ""
end

local function Toggle(item)
	Write(item, Read(item) ~= true)
	SwitchClick(Read(item) == true)
	RefreshAll()
end

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
		Arrive = function(entry, item)
			Arrive(entry, item)
		end,
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

local function Subtitle(entry)
	if entry.home then
		return ns.PanelHome.Subtitle(ui.model)
	elseif entry.profiles then
		local name = CurrentProfile()
		return name ~= "" and ("Profile in use: " .. name) or ""
	end
	return ""
end

local function LayoutNav()
	if ui.side then
		ui.side.Layout()
	end
end

local FLASH, FLASH_ALPHA = 0.8, 0.24
local CHIP_H = 28
local STEPS_GROUP, PROFILES_GROUP, ACTIONS_GROUP, CHANGED_WORD = "Flat UI setup", "Profiles", "Actions", "#changed"

local function PlaceOf(entry)
	local home = ns.PanelHome
	return home and home.Place and ui.model and home.Place(ui.model, entry) or entry.label or ""
end

local function Module(entry)
	local module = entry and entry.page and entry.page.moduleLabel
	return type(module) == "string" and module or ""
end

local function BuildChips(parent)
	local block = { frame = Frame(parent), chips = {} }
	local holder = Frame(block.frame)
	holder:SetSize(120, 16)
	holder:SetPoint("TOPLEFT", block.frame, "TOPLEFT", 0, 0)
	block.title = Dim(Label(holder, "GameFontHighlightSmall", "LEFT", 120))
	block.title:SetPoint("LEFT", holder, "LEFT", 0, 0)
	block.title:SetText("Pages")
	block.frame:Hide()
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
				chip, label = Button(block.frame, PlaceOf(entry), 100, function()
					Go(block.chips[index].go)
				end)
				chip.text = label
				block.chips[index] = chip
			end
			local place = PlaceOf(entry)
			chip.text:SetText(place)
			chip.go = entry
			local ok, measured = pcall(chip.text.GetStringWidth, chip.text)
			if not (ok and Number(measured) and measured > 0) then
				measured = 7.2 * #place
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
		if not (ui.searching and view.only and ui.view == view) then
			return
		end
		local count = 0
		for _, row in ipairs(view.shown) do
			if row.item then
				local changed = ns.PanelTrust.Changed(row.item) == true
				if changed then
					count = count + 1
				end
				row.frame:SetAlpha((row.active == false and DIM or 1) * (changed and 1 or 0.5))
			end
		end
		if count ~= view.count then
			view.count = count
			ui.head.Set(nil, ui.ChangedHead(count, view.said or view.rest, true))
			ui.ResetMode(count)
		end
	end
	return view
end

local function BuildLink(view, hit, y)
	local row = NewRow(view.scroller.child, y, hit.label, hit.tip or "")
	local open, text = Button(row.frame, "Open", SMALL, function()
		hit.Open()
	end)
	open:SetPoint("LEFT", row.frame, "LEFT", CONTROL, 0)
	row.Hover(open)
	function row.Update()
		if hit.Button then
			text:SetText(hit.Button())
		end
	end
	return row
end

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

function Arrive(entry, item)
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

function ui.Reach(entry, item, always)
	local view = entry and ui.views[entry]
	if not view or type(item) ~= "table" then
		return false
	end
	if view.RevealItem then
		view.RevealItem(item)
	end
	for _, row in ipairs(view.rows or {}) do
		if row.item == item then
			local scroller, top = view.scroller, row.top or 0
			if always or top < scroller.offset or top + ROW > scroller.offset + scroller.height then
				scroller.Scroll(math.max(0, top - 2 * ROW))
			end
			Flash(row)
			return true
		end
	end
	return false
end

function ui.ToNeed(row)
	local item, path = row and row.item, row and row.unmet
	if type(item) ~= "table" then
		return
	end
	local Trust = ns.PanelTrust
	if not IsText(path) then
		if row.over then
			local over = IsText(item.overText) and item.overText ~= "" and item.overText or "not used now"
			local tip = IsText(item.tip) and #item.tip <= 140 and (" " .. item.tip) or ""
			Say(("%s: %s now.%s"):format(IsText(item.label) and item.label or "This setting", (over:gsub("%s*now$", "")), tip))
		end
		return
	end
	local line = Trust and Trust.Prompt and Trust.Prompt(path, item) or ("Turn on %s first."):format(path)
	if ui.mode or not ui.model then
		Say(line)
		return
	end
	local entry, need = ns.PanelHome.RowOf(ui.model, path)
	local owner
	for _, each in ipairs(ui.model.pages) do
		if not owner and not each.parent and each.switchItem and each.switchItem.path == path then
			owner = each
		end
	end
	if owner and (not entry or need == owner.switchItem) then
		if ui.searching or not ui.current or ns.PanelNav.Top(ui.model, ui.current) ~= owner then
			ui.search:ClearFocus()
			Go(owner)
		end
		Say((line:gsub("%.$", "")) .. ": the switch at the top of its page.")
		return
	end
	if not entry then
		Say(line)
		return
	end
	if entry == ui.current and not ui.searching then
		ui.Reach(entry, need, true)
	else
		Arrive(entry, need)
	end
	Say(line)
end

function ui.ShowChange(text, entry)
	if not IsText(text) or type(entry) ~= "table" or type(entry.item) ~= "table" or ui.mode then
		return text
	end
	if not ui.searching and ui.Reach(ui.current, entry.item) then
		return text
	end
	local home = ns.PanelHome
	local crumb = home and home.Crumb and ui.model and home.Crumb(ui.model, entry.item) or ""
	if IsText(crumb) and crumb ~= "" then
		return (text:gsub("%.$", "")) .. " (" .. crumb .. ")."
	end
	return text
end

function ui.NextChanged()
	local entry = ui.current
	local view = entry and ui.views[entry]
	if not view or not ns.PanelTrust or ui.searching or ui.mode then
		return
	end
	local first, pick
	for index, row in ipairs(view.rows or {}) do
		if row.item and ns.PanelTrust.Changed(row.item) then
			first = first or index
			if not pick and index > (ui.changedAt or 0) then
				pick = index
			end
		end
	end
	pick = pick or first
	if pick then
		ui.changedAt = pick
		ui.Reach(entry, view.rows[pick].item, true)
	end
end

local function PartFill(path, on, shown)
	for _, row in ipairs((shown or ui.view or {}).rows or {}) do
		if row.item and row.item.path == path then
			if on and not row.partFill then
				row.partFill = Fill(row.frame, "BORDER")
				row.partFill:SetAllPoints(row.frame)
			end
			if row.partFill then
				if on then
					Solid(row.partFill, "accent", 0.1)
				end
				row.partFill:SetShown(on)
			end
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

local function Changing(words)
	local changed, rest = false, {}
	for _, word in ipairs(words) do
		if word == CHANGED_WORD then
			changed = true
		else
			rest[#rest + 1] = word
		end
	end
	return changed, rest
end

function ui.ChangedHead(count, rest, now)
	local typed = rest and #rest > 0 and table.concat(rest, " ") or nil
	if count == 0 then
		if typed then
			return ('No changed settings for "%s"'):format(typed)
		end
		return now and "Every setting is at its default now" or "No changed settings"
	end
	local head = count == 1 and "1 changed setting" or ("%d changed settings"):format(count)
	return typed and ('%s for "%s"'):format(head, typed) or head
end

ui.choiceWords = setmetatable({}, { __mode = "k" })

function ui.ChoiceWords(item)
	if item.kind ~= "choice" then
		return ""
	end
	local text = ui.choiceWords[item]
	if not text then
		local parts = {}
		local ok, list = pcall(ns.Choices, item)
		if ok and type(list) == "table" then
			for _, each in ipairs(list) do
				local label = type(each) == "table" and each[2]
				if type(label) == "string" and label ~= "" then
					parts[#parts + 1] = label
				end
			end
		end
		text = table.concat(parts, "\n")
		ui.choiceWords[item] = text
	end
	return text
end

local function Collect(words)
	local groups = {}
	local only, rest = Changing(words)
	for _, entry in ipairs(ui.model.pages) do
		local section, group, place, named = "", nil, nil, nil
		for _, item in ipairs(entry.page) do
			if item.section then
				section = item.section
			elseif item.key and ns.RowShown(item.path) then
				if not place then
					place = PlaceOf(entry)
					local top = ns.PanelNav.Top(ui.model, entry)
					named = table.concat({ place, entry.label or "", Module(entry), Module(top) }, " ")
				end
				local tier
				if only then
					tier = ns.PanelTrust.Changed(item) and (#rest == 0 and 1 or ns.PanelSearch.Tier(rest, item.label, item.tip, section, named .. "\n" .. ui.ChoiceWords(item))) or nil
				else
					tier = ns.PanelSearch.Tier(words, item.label, item.tip, section, named .. "\n" .. ui.ChoiceWords(item))
				end
				if tier then
					if not group then
						group = { label = place, entry = entry, hits = {} }
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
	for _, record in ipairs(ns.PanelSearch.PROFILE_ROWS) do
		local label = record.label
		local tier = ns.PanelSearch.Tier(words, label, record.tip, record.section, PROFILES_GROUP)
		if tier then
			profiles.hits[#profiles.hits + 1] = { tier = tier, label = label, link = true, key = PROFILES_GROUP .. "/" .. label, Open = function()
				ui.search:ClearFocus()
				Go(ui.model.profiles)
				local view = ui.views[ui.model.profiles]
				local row = view and view.byLabel and view.byLabel[ns.PanelSearch.ALIAS[label] or label]
				if row and row.frame:IsShown() then
					view.scroller.Scroll(math.max(0, (row.top or 0) - 2 * ROW))
					Flash(row)
				end
			end }
		end
	end
	local steps = { label = STEPS_GROUP, hits = {} }
	for _, step in ipairs(type(ns.SETUP_STEPS) == "table" and ns.SETUP_STEPS or {}) do
		local tier = step.built and ns.PanelSearch.Tier(words, step.title, "", step.area, STEPS_GROUP)
		if tier then
			steps.hits[#steps.hits + 1] = { tier = tier, label = step.title, link = true, key = STEPS_GROUP .. "/" .. step.id, Open = function()
				ui.search:ClearFocus()
				ShowPage(ui.current)
				Call("OpenSetup", step.id)
			end }
		end
	end
	local actions = { label = ACTIONS_GROUP, hits = {} }
	for _, action in ipairs(ns.PanelSearch.ACTIONS or {}) do
		local does = ui.actions and ui.actions[action.id]
		local tier = does and ns.PanelSearch.Tier(words, action.label, action.tip, ACTIONS_GROUP, ACTIONS_GROUP)
		if tier then
			actions.hits[#actions.hits + 1] = { tier = tier, label = action.label, link = true, key = ACTIONS_GROUP .. "/" .. action.id, tip = does.tip,
				Button = does.Button, Open = function()
					ui.search:ClearFocus()
					does.Run()
				end }
		end
	end
	if only then
		return #rest == 0 and groups or ns.PanelSearch.Sort(groups)
	end
	for _, group in ipairs({ profiles, steps, actions }) do
		if #group.hits > 0 then
			groups[#groups + 1] = group
		end
	end
	return ns.PanelSearch.Sort(groups)
end

local function Lit(label, words)
	if not IsText(label) or label == "" then
		return label or ""
	end
	local lower, lit = label:lower(), {}
	for _, word in ipairs(words) do
		local from = 1
		while #word > 0 do
			local first, last = lower:find(word, from, true)
			if not first then
				break
			end
			for at = first, last do
				lit[at] = true
			end
			from = last + 1
		end
	end
	local r, g, b = Accent()
	local open = ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
	local parts, at = {}, 1
	while at <= #label do
		local stop = at
		while stop < #label and (lit[stop + 1] == true) == (lit[at] == true) do
			stop = stop + 1
		end
		local run = label:sub(at, stop)
		parts[#parts + 1] = lit[at] and (open .. run .. "|r") or run
		at = stop + 1
	end
	return table.concat(parts)
end

local function Search(typed)
	local words, raw = ns.PanelSearch.Words(typed)
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
	local only, rest = Changing(words)
	view.only, view.rest, view.count = only, rest, nil
	view.said = select(2, Changing(raw))
	local lit = only and rest or words
	local y = 8
	local chips = {}
	if not only then
		chips = ns.PanelSearch.Pages(words, ui.model)
		if #groups == 0 then
			chips = ns.PanelSearch.Closest(words, ui.model)
		end
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
				if row.item then
					row.frame:SetAlpha(row.active == false and DIM or 1)
				end
				if row.label then
					row.label:SetText(Lit(hit.label, lit))
				end
				view.shown[#view.shown + 1] = row
				view.picks[#view.picks + 1] = { row = row, Open = hit.Open }
				y = y + ROW
			end
		end
	end
	view.empty:SetText(only and (#rest == 0 and "Every setting is at its default." or "No changed setting matches.") or "No settings match.")
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
	local found = #view.shown
	if only then
		view.count = found
		ui.head.Set(nil, ui.ChangedHead(found, view.said))
	else
		ui.head.Set(nil, found == 0 and "No results" or found == 1 and "1 result" or ("%d results"):format(found))
	end
	ui.tabs.Hide()
	ui.preview.Set(nil, 0)
	if only then
		ui.ResetMode(found)
	else
		ui.reset:Hide()
	end
	ui.tip, ui.message = "", nil
	ShowStrip()
	LayoutNav()
end

function ui.ResetMode(count)
	if not ui.reset then
		return
	end
	if ui.resetLabel then
		ui.resetLabel:SetText(count and ("Reset these (%d)"):format(count) or "Reset page")
	end
	ui.reset:SetWidth(count and 124 or 100)
	if ui.strip and not ui.mode then
		ui.strip:SetWidth(WIDTH - 24 - 330 - (count and 24 or 0))
	end
	if count then
		ui.reset:SetAlpha(1)
		ui.reset:SetShown(count > 0)
	end
end

function ui.ResetListed()
	local view = ui.searchView
	if not (ui.searching and view and view.only) then
		return
	end
	local Trust, list = ns.PanelTrust, {}
	for _, row in ipairs(view.shown or {}) do
		if row.item and Trust.Changed(row.item) then
			list[#list + 1] = row.item
		end
	end
	local count = #list
	if count == 0 then
		Say("Nothing to reset: every setting listed is at its default now.")
		return
	end
	local typed = view.said and #view.said > 0 and (" " .. table.concat(view.said, " ")) or ""
	local them = count == 1 and "it" or "them"
	Ask(("Reset the %d changed setting%s listed? Ctrl+Z puts %s back."):format(count, count == 1 and "" or "s", them), function()
		ui.batch = { label = "Reset of " .. CHANGED_WORD .. typed, what = "Reset these" }
		local done = 0
		local ok, err = pcall(function()
			for _, item in ipairs(list) do
				local target = item.shows and Trust.Partner(item) or item
				if target and not ns.RowLive(target) and Trust.Changed(item) then
					Write(target, target.default)
					done = done + 1
				end
			end
		end)
		ui.batch = nil
		if not ok then
			geterrorhandler()(err)
		end
		RefreshAll()
		Say(("Reset %d setting%s. Ctrl+Z puts %s back."):format(done, done == 1 and "" or "s", done == 1 and "it" or "them"))
	end, nil, "Reset", "Keep", true)
end

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

function ShowStrip()
	if ui.strip then
		local text = ui.message
		local status = false
		if not text then
			if ui.sayFade then
				ui.sayFade = nil
				ui.strip:SetAlpha(1)
			end
			text = ui.tip or ""
			if text == "" and not ui.searching and not ui.mode and ns.PanelTrust then
				text = ns.PanelTrust.Status(ui.current)
				status = text ~= ""
			end
		end
		ui.strip:SetText(text)
		local hit = ui.stripHit
		if hit then
			if status then
				local ok, width = pcall(ui.strip.GetStringWidth, ui.strip)
				hit:SetWidth(Number(width) and width > 0 and math.min(width, WIDTH - 24) or 7 * #text)
			elseif hit.lit then
				hit.lit = false
				Tint(ui.strip, "text")
			end
			hit:SetShown(status)
		end
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
	ui.changedAt = nil
	local view = ui.views[entry]
	if not view then
		view = entry.home and BuildHome() or entry.profiles and BuildProfiles() or BuildView(entry)
		ui.views[entry] = view
	end
	Show(view)
	local top = ns.PanelNav.Top(ui.model, entry)
	ui.title:SetText(top.label)
	ui.head.Set(top, Subtitle(entry))
	local band = ui.tabs.Set(entry)
	if view.module then
		local lift = ui.preview.Set(entry, HEAD + ns.PanelTabs.TAB_H)
		ui.tabs.Shift(lift)
		band = band + lift
	else
		ui.preview.Set(nil, 0)
	end
	if view.module and view.band ~= band then
		view.band = band
		view.scroller.frame:ClearAllPoints()
		view.scroller.frame:SetPoint("TOPLEFT", ui.right, "TOPLEFT", 0, -(HEAD + band))
		view.scroller.Resize(CW, RIGHT_H - band)
	end
	ui.ResetMode(nil)
	ui.reset:SetShown(not entry.profiles and not entry.home)
	if not entry.profiles and not entry.home and ns.PanelTrust then
		ui.reset:SetAlpha(ns.PanelTrust.Count(entry) == 0 and DIM or 1)
	end
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
		if ui.preview and not ui.searching then
			ui.preview.Update()
		end
		if ui.testSwitch then
			ui.testSwitch.Update()
		end
		if ui.barProfile then
			ui.barProfile.Update()
		end
		if ui.tabs and ui.tabs.Marks then
			ui.tabs.Marks()
		end
		if ui.ShowReload then
			ui.ShowReload()
		end
		local entry = ui.current
		if ui.reset and entry and not entry.home and not entry.profiles and ns.PanelTrust then
			ui.reset:SetAlpha(ns.PanelTrust.Count(entry) == 0 and DIM or 1)
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

local function OnScreen()
	local left, bottom, width, height = Rect(ui.window)
	local screenWidth, screenHeight = ScreenSize()
	if not (left and screenWidth) then
		return true
	end
	return left + 120 <= screenWidth and left + width - 120 >= 0 and bottom + height <= screenHeight + 20 and bottom + height - TITLE >= 0
end

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

local TestToggle
ui.actions = {
	test = {
		tip = "Shows your frames on screen with sample content while you change options. The switch at the top right does the same.",
		Run = function()
			TestToggle()
			RefreshAll()
		end,
		Button = function()
			return type(ns.TestMode) == "table" and ns.TestMode.Source() ~= nil and "Turn off" or "Turn on"
		end,
	},
	move = { tip = "Shows a box on each frame to drag it to its place, as /flatui move does.", Run = ToggleMovers },
	welcome = { tip = "The welcome screen, with its ready-made looks and setup.", Run = function() Call("OpenWelcome") end },
	looks = { tip = "The ready-made looks of the welcome screen. Nothing changes until you pick one.", Run = function() Call("OpenProfiles") end },
}

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
	ui.strip:SetWidth(mode and WIDTH - 24 or WIDTH - 24 - 330)
	if ui.Keys then
		ui.Keys()
	end
end

local function SetMode(mode)
	CloseList()
	HideConfirm()
	ui.search:ClearFocus()
	if mode and not mode.root then
		mode.root = mode.Build(ui.window)
	end
	if mode and type(ns.TestMode) == "table" then
		ns.TestMode.Off("setup")
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

local function LeaveMode()
	local mode = ui.mode
	if not (ui.window and mode) then
		return
	end
	mode.Hidden()
	if ui.mode == mode then
		SetMode(nil)
	end
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

	local box = Field(window, 360, 40)
	box:SetHeight(22)
	box:SetPoint("TOPLEFT", window, "TOPLEFT", 256, -7)
	local hint = Dim(Label(box, "GameFontHighlight", "LEFT"))
	hint:SetPoint("LEFT", box, "LEFT", 8, 0)
	hint:SetText("Search")
	local clear = Frame(box)
	clear:SetSize(16, 16)
	clear:SetPoint("RIGHT", box, "RIGHT", -4, 0)
	clear:Hide()
	clear.lines = {}
	for _, ends in ipairs({ { -3.5, 3.5, 3.5, -3.5 }, { -3.5, -3.5, 3.5, 3.5 } }) do
		local ok, line = pcall(clear.CreateLine, clear, nil, "OVERLAY", nil, 2)
		if ok and type(line) == "table" then
			ns.Own[line] = true
			line:SetThickness(1.5)
			line:SetStartPoint("CENTER", clear, ends[1], ends[2])
			line:SetEndPoint("CENTER", clear, ends[3], ends[4])
			clear.lines[#clear.lines + 1] = line
		end
	end
	function clear.Paint()
		for _, line in ipairs(clear.lines) do
			line:SetColorTexture(Look.Colour(clear.hover and "text" or "text-dim"))
		end
	end
	Painted(clear.Paint)
	Clickable(clear, function()
		box:SetText("")
		box:SetFocus()
	end)
	clear:SetScript("OnEnter", function()
		clear.hover = true
		clear.Paint()
		ui.message, ui.tip = nil, "Clears the search."
		ShowStrip()
	end)
	clear:SetScript("OnLeave", function()
		clear.hover = false
		clear.Paint()
		ui.tip = ""
		ShowStrip()
	end)
	clear:SetScript("OnHide", function()
		if clear.hover then
			clear.hover = false
			clear.Paint()
			ui.tip = ""
			ShowStrip()
		end
	end)
	ui.searchClear = clear
	box:SetScript("OnTextChanged", function(self)
		local typed = self:GetText()
		local words = IsText(typed) and typed ~= ""
		hint:SetShown(not words)
		clear:SetShown(words)
		self:SetTextInsets(6, words and 22 or 6, 0, 0)
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
	box:SetScript("OnEscapePressed", function(self)
		local typed = self:GetText()
		if IsText(typed) and typed ~= "" then
			self:SetText("")
		end
		self:ClearFocus()
	end)
	box:SetScript("OnEnter", function()
		if not ui.mode then
			ui.message, ui.tip = nil, "Words of a setting, its tip or its page. " .. CHANGED_WORD .. " lists every setting you changed; " .. CHANGED_WORD .. " nameplate narrows it. Ctrl+F from any page."
			ShowStrip()
		end
	end)
	box:SetScript("OnLeave", function()
		if not ui.mode then
			ui.tip = ""
			ShowStrip()
		end
	end)
	ui.search = box

	ui.optionParts = { left, box, ui.testSwitch.frame, ui.barProfile.frame }
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
	ui.preview = ns.PanelPreview.Build(right, {
		Model = function()
			return ui.model
		end,
		Arrive = Arrive,
		Show = Go,
		Fill = PartFill,
		View = function()
			return ui.view
		end,
		Relayout = function()
			if ui.current and not ui.searching and not ui.mode then
				ShowPage(ui.current)
			end
		end,
	})
end

local function BuildFoot(window)
	local foot = Frame(ui.stripFrame)
	foot:SetAllPoints(ui.stripFrame)
	ui.optionParts[#ui.optionParts + 1] = foot
	local done = Button(foot, "Done", 88, function()
		window:Hide()
	end, true)
	done:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
	local reload, reloadLabel, reloadTone = Button(foot, "Reload", 88, ns.Reload)
	reload:SetPoint("RIGHT", done, "LEFT", -8, 0)
	local waiting = 0
	function ui.ShowReload()
		local ok, lines = pcall(ns.ReloadLines)
		local count = ok and type(lines) == "table" and #lines or 0
		if count ~= waiting then
			waiting = count
			reloadLabel:SetText(count > 0 and ("Reload (%d)"):format(count) or "Reload")
			reloadTone(count > 0 and "accent" or nil)
		end
	end
	local ownEnter, ownLeave = reload:GetScript("OnEnter"), reload:GetScript("OnLeave")
	reload:SetScript("OnEnter", function(self, ...)
		if ownEnter then
			ownEnter(self, ...)
		end
		if waiting > 0 and ns.ReloadTip then
			ns.ReloadTip(self)
		else
			ui.message, ui.tip = nil, "Nothing needs a reload."
			ShowStrip()
		end
	end)
	reload:SetScript("OnLeave", function(self, ...)
		if ownLeave then
			ownLeave(self, ...)
		end
		if ns.ReloadUntip then
			ns.ReloadUntip(self)
		end
		ui.tip = ""
		ShowStrip()
	end)
	ns.SecureReload(reload)
	ui.ShowReload()
	ui.reset, ui.resetLabel = Button(foot, "Reset page", 100, function()
		if ui.searching then
			ui.ResetListed()
			return
		end
		local entry = ui.current
		if entry and not entry.profiles and not entry.home then
			local count = ns.PanelTrust.Count(entry)
			if count == 0 then
				Say("Nothing to reset: every setting on this tab is at its default.")
				return
			end
			local name = ns.PanelTabs.Label(ui.model, entry) or entry.label
			local top = ns.PanelNav.Top(ui.model, entry)
			local place = top ~= entry and ("%s > %s"):format(top.label, name) or name
			Ask(ns.PanelTrust.Question(entry, name), function()
				local before = ns.PanelTrust.Count(entry)
				ui.batch = { label = "Reset page on " .. place, what = "Reset page" }
				local ok, err = pcall(function()
					for _, item in ipairs(entry.page) do
						if item.key and item.kind ~= "list" and item.kind ~= "entries" and not ns.RowLive(item) then
							Write(item, item.default)
						end
					end
				end)
				ui.batch = nil
				if not ok then
					geterrorhandler()(err)
				end
				RefreshAll()
				local done = before - ns.PanelTrust.Count(entry)
				Say(("Reset %d setting%s on %s. Ctrl+Z puts %s back."):format(done, done == 1 and "" or "s", place, done == 1 and "it" or "them"))
			end)
		end
	end)
	ui.reset:SetPoint("RIGHT", reload, "LEFT", -8, 0)
	ui.reset:HookScript("OnEnter", function()
		ui.message, ui.tip = nil, ui.searching and "Puts every changed setting listed back to its default, as one step Ctrl+Z takes back."
			or "Puts every setting of this tab back to its default. Settings the game holds keep their value."
		ShowStrip()
	end)
	ui.reset:HookScript("OnLeave", function()
		ui.tip = ""
		ShowStrip()
	end)
	ui.strip:SetWidth(WIDTH - 24 - 330)
end

function TestToggle()
	local mode = ns.TestMode
	if type(mode) ~= "table" then
		return
	end
	if InCombatLockdown() then
		local was = mode.Source() ~= nil
		mode.Toggle("panel")
		Say(was and "Test mode is off." or mode.Wanted() == "panel" and "Test mode comes on when the fight ends." or "Test mode stays off.")
		return
	end
	mode.Toggle("panel")
	SwitchClick(mode.Source() ~= nil)
end

local function BuildTestSwitch(bar, close)
	local tip = "Shows your frames on screen with sample content while you change options. Ends when you close the options or turn it off; "
		.. "pauses in a fight."
	local test = Frame(bar)
	test:SetSize(160, BUTTON)
	test:SetPoint("RIGHT", close, "LEFT", -16, 0)
	local track = Frame(test)
	track:SetSize(32, 16)
	track:SetPoint("RIGHT", test, "RIGHT", 0, 0)
	local outline = ns.Outline(track, track, true)
	local mark = Fill(track, "ARTWORK")
	mark:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
	mark:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 1)
	local knob = Fill(track, "OVERLAY")
	knob:SetSize(12, 12)
	local Place = Slider(knob, track, track)
	local word = Label(test, "GameFontHighlightSmall", "RIGHT")
	word:SetPoint("RIGHT", track, "LEFT", -8, 0)
	local switch = { frame = test, hovered = false }
	function switch.Update()
		local mode = ns.TestMode
		local on = type(mode) == "table" and (mode.Source() ~= nil or mode.Wanted() == "panel")
		local fight = InCombatLockdown() == true
		mark:SetShown(on)
		Place(on)
		knob:SetColorTexture(Look.Colour(on and "on-accent" or "text-dim"))
		Backing(outline, "line", 1, switch.hovered and "text-faint" or "line-strong")
		word:SetText(fight and "After the fight" or "Test mode")
		test:SetAlpha(fight and DIM or 1)
	end
	Painted(function()
		mark:SetColorTexture(Accent())
		switch.Update()
	end)
	Clickable(test, function()
		TestToggle()
		switch.Update()
	end)
	test:SetScript("OnEnter", function()
		switch.hovered = true
		switch.Update()
		ui.message, ui.tip = nil, tip
		ShowStrip()
	end)
	test:SetScript("OnLeave", function()
		switch.hovered = false
		switch.Update()
		ui.tip = ""
		ShowStrip()
	end)
	return switch
end

local PROFILE_FLASH, PROFILE_HOLD = 1, 0.4
local function BuildProfileName(bar)
	local frame = Frame(bar)
	frame:SetSize(160, BUTTON)
	frame:SetPoint("RIGHT", ui.testSwitch.frame, "LEFT", -12, 0)
	local text = Dim(Label(frame, "GameFontHighlightSmall", "RIGHT", 160))
	text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	local after = Tint(Label(frame, "GameFontHighlightSmall", "RIGHT", 160), "accent")
	after:SetPoint("RIGHT", frame, "RIGHT", 0, -7)
	after:Hide()
	local shown, seenAt, flash
	local function Glow(_, seconds)
		flash = flash + (Number(seconds) and seconds or 0)
		local t = Clamp((flash - PROFILE_HOLD) / (PROFILE_FLASH - PROFILE_HOLD), 0, 1)
		local r1, g1, b1 = Accent()
		local r2, g2, b2 = Look.Colour("text-dim")
		text:SetTextColor(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
		if t >= 1 then
			frame:SetScript("OnUpdate", nil)
		end
	end
	local name = { frame = frame, text = text }
	local shownWant, shownRule
	local function Waiting()
		local switch = ns.ProfileSwitch
		if type(switch) == "table" and type(switch.Wanted) == "function" then
			local want, rule = switch.Wanted()
			if IsText(want) then
				return want, rule == true
			end
		end
		return nil, false
	end
	function name.Update()
		local now = CurrentProfile()
		local at = Now()
		local open = ui.window and ui.window:IsShown() and seenAt ~= nil and at - seenAt < 2
		if ui.window and ui.window:IsShown() then
			seenAt = at
		end
		local want, rule = Waiting()
		if want == now then
			want = nil
		end
		if now == shown and want == shownWant and rule == shownRule then
			return
		end
		local first, moved = shown == nil, now ~= shown
		shown, shownWant, shownRule = now, want, rule
		text:SetText(now ~= "" and ("Profile: " .. now) or "")
		text:ClearAllPoints()
		text:SetPoint("RIGHT", frame, "RIGHT", 0, want and 6 or 0)
		after:SetText(want and ("%s after the fight"):format(want) or "")
		after:SetShown(want ~= nil)
		if not moved then
			return
		end
		if not first and open and now ~= "" then
			flash = 0
			Glow(nil, 0)
			frame:SetScript("OnUpdate", Glow)
		end
	end
	Clickable(frame, function()
		if ui.model and ui.model.profiles and not ui.mode then
			Go(ui.model.profiles)
		end
	end)
	frame:HookScript("OnMouseUp", function(_, button)
		if button ~= "RightButton" or ui.mode or not ui.model or CurrentProfile() == "" then
			return
		end
		OpenList(name, {
			lines = function()
				return ProfileNames(function() return true end)
			end,
			selected = CurrentProfile,
			pick = function(pick)
				Act("UseProfile", pick)
			end,
			right = true,
		})
	end)
	frame:SetScript("OnEnter", function()
		local now = CurrentProfile()
		if now == "" then
			return
		end
		local count = ns.PanelHome and ns.PanelHome.UserCount and ns.PanelHome.UserCount(now) or 1
		ui.message = nil
		ui.tip = ("Changes here are saved in %s, used by %d character%s. Click for Profiles; right-click to switch."):format(now, count, count == 1 and "" or "s")
		local want, rule = Waiting()
		if want and want ~= now then
			ui.tip = ui.tip .. (" Switches to %s when the fight ends%s."):format(want, rule and " (Switch automatically)" or "")
		end
		ShowStrip()
	end)
	frame:SetScript("OnLeave", function()
		ui.tip = ""
		ShowStrip()
	end)
	ui.barProfile = name
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
	local clicked
	bar:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" or type(GetTime) ~= "function" then
			return
		end
		local now = GetTime()
		if clicked and Number(now) and now - clicked <= 0.3 then
			clicked = nil
			window:ClearAllPoints()
			window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			Look.ClearPosition()
			Say("The window is back in the middle.")
		else
			clicked = Number(now) and now or nil
		end
	end)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(_, delta)
		local ok, held = pcall(IsControlKeyDown)
		local scale = ns.Get("panel.scale")
		if ok and held == true and type(delta) == "number" and not ns.IsSecret(delta) and type(scale) == "number" then
			ns.Set("panel.scale", math.max(80, math.min(150, scale + (delta > 0 and 5 or -5))))
			local now = ns.Get("panel.scale")
			if Number(now) then
				Say(("Window scale %d%%"):format(now))
			end
		end
	end)
	bar:SetScript("OnEnter", function()
		if ui.mode then
			return
		end
		local scale = ns.Get("panel.scale")
		ui.message = nil
		ui.tip = ("Drag to move, double-click to put it in the middle. Ctrl and the mouse wheel: Window scale, now %d%%."):format(Number(scale) and scale or 100)
		ShowStrip()
	end)
	bar:SetScript("OnLeave", function()
		if not ui.mode then
			ui.tip = ""
			ShowStrip()
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
	local counter = Dim(Label(bar, "GameFontHighlightSmall", "LEFT"))
	counter:SetPoint("LEFT", title, "RIGHT", 8, -1)
	counter:Hide()
	ui.barCounter = counter
	local close = Button(bar, "Close", 60, function()
		if ui.mode and ui.mode.Close then
			ui.mode.Close()
		else
			window:Hide()
		end
	end)
	close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
	ui.testSwitch = BuildTestSwitch(bar, close)
	BuildProfileName(bar)

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
	local hit = Frame(strip)
	hit:SetHeight(STRIP - 8)
	hit:SetPoint("LEFT", strip, "LEFT", 12, 0)
	hit:Hide()
	Clickable(hit, function()
		ui.NextChanged()
	end)
	hit:SetScript("OnEnter", function()
		hit.lit = true
		Tint(text, "accent")
	end)
	hit:SetScript("OnLeave", function()
		hit.lit = false
		Tint(text, "text")
	end)
	ui.stripHit = hit
end

local function BuildKeys(window)
	local keys = Frame(window)
	keys:SetAllPoints(window)
	keys:Hide()
	local ok, err = pcall(keys.EnableKeyboard, keys, true)
	if not ok then
		geterrorhandler()(err)
		return
	end
	local function Find()
		ui.search:SetFocus()
	end
	local function Undo()
		local text, entry = ns.PanelHome.UndoNewest()
		RefreshAll()
		Say(ui.ShowChange(text, entry))
	end
	local function Redo()
		local text, entry = ns.PanelHome.Redo()
		RefreshAll()
		Say(ui.ShowChange(text, entry))
	end
	keys:SetScript("OnKeyDown", function(self, key)
		local asking = ui.confirm ~= nil and ui.confirm:IsShown() == true
		local picker = ns.PanelColour and ns.PanelColour.Shown() and ns.PanelColour or nil
		local action
		if key == "ESCAPE" then
			action = ui.EscapeAction()
		elseif key == "ENTER" or key == "NUMPADENTER" then
			action = (picker and picker.Apply) or (asking and not ui.careful and ui.AnswerYes) or nil
		elseif key == "F" and type(IsControlKeyDown) == "function" and IsControlKeyDown() and ui.search:IsVisible() then
			action = Find
		elseif (key == "Y" or key == "Z") and type(IsControlKeyDown) == "function" and IsControlKeyDown() and ns.PanelHome and not ui.EscapeAction() then
			local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
			action = (key == "Y" or shift) and Redo or Undo
		end
		if not InCombatLockdown() then
			local done, failed = pcall(self.SetPropagateKeyboardInput, self, action == nil)
			if not done then
				geterrorhandler()(failed)
			end
			if action and done and C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if not InCombatLockdown() then
						pcall(self.SetPropagateKeyboardInput, self, true)
					end
				end)
			end
		end
		if action then
			action()
		end
	end)
	keys:RegisterEvent("PLAYER_REGEN_DISABLED")
	keys:RegisterEvent("PLAYER_REGEN_ENABLED")
	keys:SetScript("OnEvent", function(_, event)
		ui.Keys(event ~= "PLAYER_REGEN_DISABLED")
	end)
	ui.keys = keys
	function ui.Keys(allowed)
		local shown = allowed ~= false and ui.mode == nil and not InCombatLockdown()
		if shown then
			pcall(keys.SetPropagateKeyboardInput, keys, true)
		end
		keys:SetShown(shown)
	end
	ui.Keys()
end

local function Build()
	ROW = Look.RowHeight()
	ns.PanelKit.ROW = ROW
	ui.shape = Look.Get("density") .. "/" .. Look.Get("sidebar") .. "/" .. Look.Get("sections")
	SIDE = Look.SideWidth()
	CW = WIDTH - SIDE
	ui.model = BuildModel()
	local window = CreateFrame("Frame", NAME, UIParent)
	ns.Own[window] = true
	ui.window = window
	window:SetSize(WIDTH, HEIGHT)
	window:SetFrameStrata("HIGH")
	window:SetFrameLevel(LEVEL)
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
	BuildKeys(window)
	window:SetScript("OnShow", function()
		RefreshAll()
		ui.fade = 0
		window:SetAlpha(0)
		if ui.held then
			ui.held = nil
		elseif ui.ready and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_MAINMENU_OPEN then
			pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN)
		end
	end)
	window:SetScript("OnHide", function()
		local holding = type(ns.MoversMode) == "table" and ns.MoversMode.Holding() == true
		ui.held = holding or nil
		ui.fade = nil
		if ui.ready and not holding and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_MAINMENU_CLOSE then
			pcall(PlaySound, SOUNDKIT.IG_MAINMENU_CLOSE)
		end
		if ns.Get("movers.keepSpots") == "reset" then
			Look.ClearPosition()
		end
		CloseList()
		HideConfirm()
		ui.search:ClearFocus()
		local test, movers = ns.TestMode, ns.MoversMode
		if type(test) == "table" and not (type(movers) == "table" and movers.Holding()) then
			if test.Source() == "panel" then
				test.Off("panel")
			end
			test.Drop("panel")
		end
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
		if ui.fade then
			ui.fade = math.min(1, ui.fade + (Number(seconds) and seconds or 0) / FADE_IN)
			window:SetAlpha(ui.fade)
			if ui.fade >= 1 then
				ui.fade = nil
			end
		end
		if ui.mode and ui.mode.Frame then
			ui.mode.Frame(seconds)
		end
		if ui.flash then
			Fade(seconds)
		end
		if ui.sayFade then
			ui.sayFade = ui.sayFade + (Number(seconds) and seconds or 0)
			local t = math.min(1, ui.sayFade / SAY_FADE)
			ui.strip:SetAlpha(SAY_FROM + (1 - SAY_FROM) * t)
			if t >= 1 then
				ui.sayFade = nil
			end
		end
		if ui.message and ui.messageAt and Now() - ui.messageAt > SAY_HOLD then
			ui.message, ui.messageAt = nil, nil
			ShowStrip()
		end
		elapsed = elapsed + seconds
		if elapsed >= REFRESH then
			elapsed = 0
			RefreshAll()
		end
	end)
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
	ui.ready = true
	local key = Look.Page()
	ShowPage((key == "profiles" and ui.model.profiles) or ui.model.byKey[key] or ui.model.home)
end

local function Rebuild()
	ROW = Look.RowHeight()
	ns.PanelKit.ROW = ROW
	for _, view in pairs(ui.views) do
		view.scroller.frame:Hide()
	end
	ui.sets = ui.sets or {}
	ui.sets[ui.shape] = ui.views
	ui.shape = Look.Get("density") .. "/" .. Look.Get("sidebar") .. "/" .. Look.Get("sections")
	SIDE = Look.SideWidth()
	CW = WIDTH - SIDE
	ui.left:SetWidth(SIDE)
	ui.right:SetWidth(CW)
	ui.views, ui.view = ui.sets[ui.shape] or {}, nil
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
	elseif key == "preview" then
		if ui.current and not ui.searching and not ui.mode then
			ShowPage(ui.current)
		end
	elseif key == "samples" then
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
				print(ui.pendingSearch and "Flat UI: the options window opens after the fight, with your search." or "Flat UI: the options window opens after the fight.")
				ns.OutOfCombat(function()
					ui.waiting = false
					if not ui.window then
						Build()
						Place()
					end
					local words = ui.pendingSearch
					ui.pendingSearch = nil
					if words then
						ns.OpenPanelSearch(words)
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

ns.PanelKit = {
	Frame = Frame, Fill = Fill, Label = Label, Dim = Dim, Tint = Tint, Clickable = Clickable, Button = Button, Field = Field,
	Scroller = Scroller, Dropdown = Dropdown, NewRow = NewRow, BuildRow = BuildRow, IsOpen = IsOpen, Unmet = Unmet, Header = Header, Painted = Painted,
	Solid = Solid, Backing = Backing, Accent = Accent, Shade = Shade, Clamp = Clamp, Rect = Rect, IsText = IsText, Cursor = Cursor, Drag = Drag,
	Say = Say, Ask = Ask, CloseList = CloseList, OpenList = OpenList, Read = Read, Write = Write,
	Bool = AddBool, SwitchClick = SwitchClick, Slider = Slider, CopyField = CopyField,
	Press = function(button, down) local press = ui.presses and ui.presses[button] if press then press(down == true) end end,
	Window = function() return ui.window end,
	Inset = function(parent, inset) insets[parent] = inset end,
	Tip = function(text) ui.message, ui.tip = nil, text or "" ShowStrip() end, Refresh = function() RefreshAll() end,
	Hide = function() if ui.window then ui.window:Hide() end end,
	Leave = LeaveMode,
	Escape = function() local action = ui.EscapeAction() if action then action() return true end return false end,
	Enter = function()
		local picker = ns.PanelColour
		if picker and picker.Shown() then
			picker.Apply()
			return true
		end
		if ui.confirm and ui.confirm:IsShown() and not ui.careful then
			ui.AnswerYes()
			return true
		end
		return false
	end,
	SetCounter = function(text) if ui.barCounter then ui.barCounter:SetText(text or "") end end,
	WIDTH = WIDTH, HEIGHT = HEIGHT, TITLE = TITLE, LEFT = LEFT, STRIP = STRIP, HEADER = HEADER, RIGHT_W = RIGHT_W, PAD = PAD, ROW = ROW,
	ROW_W = ROW_W, SECTION = SECTION, LABEL = LABEL, CONTROL = CONTROL, FIELD = FIELD, SMALL = SMALL, BUTTON = BUTTON,
}

function ns.OpenPanelMode(mode)
	if not ui.window then
		if InCombatLockdown() then
			if not ui.waiting then
				ui.waiting = true
				print(mode.waiting or "Flat UI: the options window opens after the fight.")
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

function ns.OpenPanelPage(key)
	if not (ui.window and ui.window:IsShown()) then
		ns.OpenPanel()
	end
	local entry = ui.model and ui.model.byKey[key]
	if not (ui.window and ui.window:IsShown() and entry) then
		return false
	end
	Go(entry)
	return true
end

function ns.OpenPanelSearch(words)
	if ui.window and ui.window:IsShown() and ui.mode then
		print("Flat UI: setup has the options window. Search once it is closed.")
		return false
	end
	if not ui.window and InCombatLockdown() and IsText(words) then
		ui.pendingSearch = words
	end
	if not (ui.window and ui.window:IsShown()) then
		ns.OpenPanel()
	end
	if not (ui.window and ui.window:IsShown()) or ui.mode or not IsText(words) then
		return false
	end
	if ui.search:GetText() == words then
		Search(words)
	else
		ui.search:SetText(words)
	end
	ui.search:SetFocus()
	pcall(ui.search.SetCursorPosition, ui.search, #words)
	return true
end

function ns.OpenPanelRow(path)
	if ui.window and ui.window:IsShown() and ui.mode then
		print("Flat UI: setup has the options window. Open the setting once it is closed.")
		return false
	end
	if not (ui.window and ui.window:IsShown()) then
		ns.OpenPanel()
	end
	if not (ui.window and ui.window:IsShown()) or ui.mode or not IsText(path) or not ui.model then
		return false
	end
	local entry, item = ns.PanelHome.RowOf(ui.model, path)
	if not entry then
		return false
	end
	Arrive(entry, item)
	return true
end

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

function ns.PanelInMode()
	return ui.mode ~= nil
end

function ns.PanelMode()
	return ui.mode
end

function ns.RefreshPanel()
	if ui.window and ui.window:IsShown() then
		RefreshAll()
	end
end

function FlatUI_OnAddonCompartmentClick()
	ns.OpenPanel()
end

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
		ns.Follow(menu, "InitButtons", Place)
	end
end
