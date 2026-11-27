local ADDON_NAME, ns = ...

-- A window of the addon's own with every page of ns.PAGES, a search over all settings, and the profiles. It is made of frames,
-- textures and font strings of the addon's own and is built the first time it is opened. None of its frames is protected, so it
-- works in combat. It is only built out of combat, since UIParent is protected.
--
-- It fades in with the game's window sounds (Build). Its keys (BuildKeys, out of combat): Ctrl+F for Search, Ctrl+Z to put back the newest change of
-- Home's Recent changes (a whole Reset page in one press), Ctrl+Y or Ctrl+Shift+Z to make it again, each showing the row it changed on the tab shown
-- (its card opens, it scrolls into view and flashes) or naming the row's place in the strip (ui.ShowChange), Escape for the colour picker (Cancel), an open
-- list or a question before the window, Enter for the picker's Apply or a question's first button, but not for a careful question (Delete, Reset,
-- Copy from, Replace, setup's Start over); setup has the same Enter (ns.PanelKit.Enter). A long list's filter field has the cursor as it opens. The
-- question box fades in and grows with its question, its first button in the accent, or red with "Enter does not answer this." under a careful
-- question (Ask). A message of the strip holds for SAY_HOLD seconds whatever the mouse crosses, fading in, then the strip shows its count again (Say).
-- A press counts as a click only when it is let go over what it pressed, as with the game's buttons, and a button's label sinks 1 px while it is
-- held (Clickable, Button).
-- The title bar names the profile in use, which a click opens, with a second line in the accent for a profile that waits for the fight's end
-- (BuildProfileName), and the strip's Reload counts the changes that wait for a reload (BuildFoot). The strip's "3 changed on this tab" takes a
-- click, which goes to each changed row in turn (ui.NextChanged), and a tab holding changes has a dot (PanelTabs.lua), as a module of the sidebar
-- does (PanelNav.lua). The Search box has a cross that clears it while words are typed (BuildLeft), and /flatui with words that are no command opens
-- the window with them in it (ns.OpenPanelSearch). Reset profile and Delete profile have Bring back while what they took can come back, until a
-- reload (BuildProfiles; Core.lua, ns.BringBackProfile and ns.BringBackDeleted). Every switch plays the game's checkbox sound on a click and its
-- knob slides (SwitchClick, Slider).
-- The wheel scrolls a page over a slider too, and Shift and the wheel step the slider (AddNumber). A sound row plays a line once as it is picked and
-- has a Play button (AddChoice). Search lights the typed words in its results and counts them, and a Profiles
-- result opens its row (view.byLabel of BuildProfiles). Reset page says what it did, and is dimmed while nothing on the tab is changed.
-- It lies in the strata HIGH at level LEVEL, above the frames of the HUD in that strata, which are made at the level UIParent gives
-- them: the combat alerts (CombatCues.lua), the cooldown pulse (Pulse.lua) and the combat text, and the stand-ins of test mode, which
-- TestMode.lua keeps under it there. At the level UIParent gave it too, the samples of test mode drew inside it over its rows (0.5.32).
-- The welcome screen lies above it (SetupWelcome.lua), and its own lists and the colour picker above its rows.

local NAME = "FlatUIOptionsFrame"
local WIDTH, HEIGHT, LEVEL = 1040, 680, 500
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
-- How long the window takes to fade in as it opens, and the question box as it shows, in seconds.
local FADE_IN, CONFIRM_FADE = 0.12, 0.08
local Look = ns.PanelLook
local PROFILE_CALLS = { "Profile", "Profiles", "UseProfile" }

local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

-- The parts of the window, and what it is showing.
local ui = { views = {}, nav = {}, lines = {}, paints = {}, tip = "" }

local OpenList, CloseList, Ask, HideConfirm, ShowStrip, RefreshAll, ShowPage, Arrive

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

-- A frame that takes clicks: onClick runs when the left button goes down on it and is let go over it, as with a button of the game's. The game sends
-- the release to the frame the press began on, wherever the cursor is, so a press slid off before it is let go is not a click (DataPanels.lua and
-- Errands.lua keep the same rule); a client that will not say whether the cursor is over counts as over.
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

-- The click of a switch: the game's own checkbox sounds, a higher one for on and a lower one for off, as the game's Settings play them. Only a
-- click of the player plays it; a switch that changes by itself (a profile switch, Reset page, Ctrl+Z) slides with no sound (Slider).
local function SwitchClick(on)
	if type(PlaySound) == "function" and type(SOUNDKIT) == "table" then
		local sound = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
		if sound then
			pcall(PlaySound, sound)
		end
	end
end

-- The knob of a switch 32 wide, at the left of its track (2) while off and the right (18) while on. The function it gives, Place(on, instant), puts
-- the knob at its end: at once the first time, when told (a switch that now shows another setting) and while the switch is not on screen, else
-- sliding there over SLIDE seconds with an OnUpdate of `frame`, a frame of the switch that has none of its own.
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

-- A flat button. A primary button is in the accent. The third result, SetTone(tone), gives it another tone after it is made: "accent", "danger"
-- (red, for the first button of a careful question) or nil for the plain one; the label of a coloured one is in the colour that reads on the accent.
-- While the left button holds it down its label sinks 1 px and its fill goes back to the resting tone; the press counts only when it is let go over
-- the button (Clickable). The pressed look is hooked, so a caller's own scripts stay as they are, and a frame over the button that takes its mouse
-- (the secure /reload button of Reload.lua) gives it the look with ns.PanelKit.Press(button, down) (ui.presses).
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
	-- Red has no lighter token of its own, so under the mouse its fill lets a little of the card through.
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

-- A box to type in, with a thin border that takes the highlight colour while it has the cursor. onLost runs when it loses the cursor. With a hint,
-- a dim line says what goes in it while it is empty (the second result, to change it later); it follows every change of the text, a SetText("")
-- too, through a hook, so a caller's own OnTextChanged must be hooked as well.
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

-- True while something else takes a row over (overIf: the name of a function of ns that says so, as for Width of the experience bar while
-- block 1 of the Bar block page holds the bar at its width): the row is greyed, and a number row shows its overText in place of its value.
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

-- A message of the strip holds for SAY_HOLD seconds, whatever the mouse crosses on the options pages (a row's tip is a tooltip there), and then the
-- strip goes back to its tip or the count of changes (ShowStrip, and the window's OnUpdate). A new message fades in over SAY_FADE from SAY_FROM, so
-- a second Ctrl+Z reads as a new line; the same message said again only holds longer, so setup's fight line, said at each refresh, does not flicker.
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

-- A box that holds text to copy (Export): a click in it selects all of it again, and Ctrl+C there says in the strip that it was copied.
local function CopyField(box)
	box:HookScript("OnEditFocusGained", function(self)
		self:HighlightText()
		-- Once more on the next frame, after the click has put the cursor where it landed.
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
	-- Search lights the typed words in the label of a result. While the Profiles page is built, its rows are kept by their label (ui.collect), so a
	-- search result can open the row.
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
	-- Every control of the row shows the tip too, since the game gives the mouse to the control and not to the row. A control that already
	-- has a hover of its own, such as the fill of a button, keeps it: it runs first on the way in and last on the way out.
	function row.Hover(target, enter, leave)
		local ownEnter, ownLeave = target:GetScript("OnEnter"), target:GetScript("OnLeave")
		target:SetScript("OnEnter", function()
			if ownEnter then
				ownEnter(target)
			end
			hover:Show()
			-- Setup and the movers show the tip in the strip, in place of a message; the options pages show it in a tooltip and keep the message.
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
	-- A write of Reset page is noted with its batch (ui.batch), so Ctrl+Z puts the whole page back in one press (PanelHome.lua).
	if ns.PanelHome then
		ns.PanelHome.Noted(item, before, ns.Get(item.path), ui.batch)
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
	-- nil until the row first reads its value, where the knob is put at once; after that it slides to its end, and a click plays the game's
	-- checkbox sound (SwitchClick).
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
	-- A row something else takes over (overIf, as Width of the experience bar under the bar block) says so (overText) in place of its value and
	-- unit while it does, which greys the row (BuildRow).
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
	-- The wheel scrolls the page under the slider (the first ScrollFrame up its parents, Flat UI's own Scroller), so a page scrolled past a slider
	-- keeps scrolling. Shift and the wheel, or the wheel while the number box has the cursor, step the value.
	local function Wheel(_, delta)
		local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
		if shift or box:HasFocus() then
			if row.active then
				Write(item, Read(item) + (delta > 0 and 1 or -1) * item.step)
				-- A box with the cursor keeps what is typed (Show), so it takes the stepped value here, else Enter would write the old one back.
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

-- The sound kit of each line of a choice row whose lines are the names of ns.SOUNDS (IconRow.lua), by the line's value, or nil for a row of no
-- sound. Every sound row of Config.lua has those names, so a row is a sound row by its lines alone, three of them at least, so that one line that
-- happens to share a name makes no sound row; None has no kit.
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

-- A sound row plays a line once as it is picked, out of a fight (the changed handler of the combat cue sounds plays it too, and ns.PlayKit plays
-- once a second at most), and has a Play button for the sound it has now, dimmed at None. The same on the options pages, in setup and in the
-- tracker editor.
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

-- A dropdown that acts: the lines come from a function of ns each time it opens, and choosing one calls another with its id. A row of Flat UI
-- setup has an act of its own (Setup.lua, S.Item), which queues the line for Finish: then nothing is called now.
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
	-- Pointing at a row brackets the part of the preview that the setting changes. Setup sets its own.
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
		SetActive(row, unmet == nil and not Over(item))
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
			-- The minimum of what the tracker read last: arrows and bullets, or a thrown weapon (TrackerKinds.lua).
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
	-- It has the cursor as the list opens (OpenList), so the player can type at once; Enter picks the first line shown and Escape closes the list.
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
	-- The question has no height of its own, so it takes every line its words need (Ask measures it).
	local question = Label(confirm, "GameFontHighlight", "CENTER", 330, true)
	question:SetJustifyV("TOP")
	question:SetPoint("TOP", confirm, "TOP", 0, -18)
	-- The first button, which Enter presses too while the question shows (BuildKeys).
	function ui.AnswerYes()
		local run = ui.onYes
		HideConfirm()
		if run then
			run()
		end
	end
	-- The first button is in the accent, the one Enter presses; for a careful question it is red, and the note under the question says Enter does
	-- not answer it (Ask).
	local yes, yesText, yesTone = Button(confirm, "Yes", SMALL, ui.AnswerYes)
	yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 14)
	-- The note hangs just under the question's lines, and the box grows with the question (Ask).
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
	-- A long list's filter field takes the cursor, so typing filters at once.
	if search > 0 then
		ui.listSearch:SetFocus()
	end
end

-- The question box: onYes runs on the first button, onNo (when given) on the second. A click outside the box closes it and runs neither. The buttons
-- say yesText and noText when those are given, and Yes and No otherwise. Enter presses the first button (BuildKeys), but not for a careful question,
-- one whose first button takes a profile's settings away (Delete, Reset, Copy from, Replace; Bring back puts them back only until a reload, and
-- each such question says so): an Enter meant for chat must not answer it. The box grows
-- with the question, at least two lines of its 330 px column, so a long Delete or Copy from question is never cut short; the note and the buttons
-- move down with it.
function Ask(question, onYes, onNo, yesText, noText, careful)
	BuildPopups()
	CloseList()
	-- The question takes at least two lines' room, and every line its words need.
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
	-- It fades in over CONFIRM_FADE, as the colour picker does.
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

-- What Escape closes before the window: the colour picker (its Cancel puts the old colour back), else an open list, else a question; nil while
-- none of them shows. The options pages' keys (BuildKeys) and setup's (ns.PanelKit.Escape) both use it.
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
			-- A page of its own in the sidebar that holds rows of another module (an owner and no parent) is part of that module: it shows the
			-- module's switch in its header and its Off chip (the Flat UI page has none), and is not a module of its own on Home.
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

-- Profile in use picked in a fight (the Profiles page, Home's Profile card): the pick waits for the fight's end in ProfileSwitch.lua (Switch.Keep),
-- which /flatui profile Name uses too, and wins over a rule of Switch automatically that waits; the title bar shows either under the profile in use
-- ("Raid after the fight", BuildProfileName), and ProfileSwitch.lua switches a frame after the fight. A pick of the profile in use takes back
-- whatever waits, the rule's switch too.
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
		Say("Profiles change after combat.")
	end
	RefreshAll()
	return false
end

-- Runs a function of Core that changes a profile and shows the sentence it answers with. Profile in use in a fight waits for its end (KeepProfile).
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

-- The question of Delete profile: the name, how many other characters use it, and that Bring back puts it back until a reload (Core.lua,
-- ns.BringBackDeleted). They start as new characters at their next login (Core.lua, ns.DeleteProfile and OwnProfile), on Default.
function ui.DeleteQuestion(name)
	local back = "Bring back puts it back until you reload."
	local db, count = ns.Account(), 0
	local me = type(ns.CharacterKey) == "function" and ns.CharacterKey() or nil
	for key, used in pairs(type(db) == "table" and type(db.profileOf) == "table" and db.profileOf or {}) do
		if used == name and key ~= me then
			count = count + 1
		end
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
	-- Every row made from here on, here and in ProfileSwitch.lua and ProfileShare.lua, is kept by its label (NewRow), for search (view.byLabel).
	ui.collect = {}
	-- Each row of the page says what it does in its tip, over the label and over each of its controls.
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
		-- A copy of the profile in use, settings and positions: under the typed name, else the first of "<name> copy" and "<name> copy 2" to 9 that is free.
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
			-- The welcome screen's ready-made looks (SetupWelcome.lua, ns.OpenProfiles).
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
		-- The profile deleted this session comes back with its characters and rules, until a reload (Core.lua, ns.BringBackDeleted).
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
		-- The hint names the profile in use, which the new name replaces.
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
		-- What Reset profile, Copy from, an import that replaces or setup's Finish took from the profile in use comes back, until a reload (Core.lua,
		-- ns.BringBackProfile). A second press puts back what the first took.
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
				-- A text that can be read is imported with the choices under the paste field.
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

-- Home, and the pages the player goes to --------------------------------------------------------------

local function CurrentProfile()
	local name = Call("Profile")
	return IsText(name) and name or ""
end

-- Flips the switch of a module, in the header or on a tile of Home, with the click of a switch.
local function Toggle(item)
	Write(item, Read(item) ~= true)
	SwitchClick(Read(item) == true)
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
		-- A click on a recent change or a line of Needs a reload opens that setting's row, as a search result does.
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
local STEPS_GROUP, PROFILES_GROUP, ACTIONS_GROUP = "Flat UI setup", "Profiles", "Actions"

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

-- A result that opens a page or a step of setup, or runs an action of the window, instead of holding a control: the name and a button, which says
-- Open, or what hit.Button gives (Test mode's Turn on or Turn off).
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

-- Opens the tab of a setting, scrolls to its row and flashes it. Search, the preview and Home call it.
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

-- The row of a setting on the tab shown, which opens (its card too), comes into view and flashes: scrolled to as Arrive does with `always`, else
-- only when it lies outside the view. Returns true when the tab has the row.
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

-- After Ctrl+Z or Ctrl+Y (BuildKeys): the row of the change shows on the tab shown (ui.Reach); a change of another tab, or one made while a search
-- shows, names its place after the strip's words ("Undid Border colour: back to #000000 (Unit frames > Bars and pictures)."). Returns the words.
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

-- A click on the strip's count of changes on the tab (ui.stripHit, BuildBars): the next changed row after the last one it went to, in the order
-- of the tab, opens (its card too), comes into view and flashes; after the last it starts at the first again. A new tab starts at the first.
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

-- Fills the row of a setting in the accent at 10% while its part of the preview is pointed at.
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
				ui.search:ClearFocus()
				Go(ui.model.profiles)
				-- The row of the result, scrolled to and flashed as a setting's row is (Arrive); a name that is a part of another row opens that row.
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
				-- The options pages are back as they were when setup closes.
				ui.search:ClearFocus()
				ShowPage(ui.current)
				Call("OpenSetup", step.id)
			end }
		end
	end
	-- The window's own actions (PanelSearch.ACTIONS, ui.actions): each Open leaves the search field first.
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
	for _, group in ipairs({ profiles, steps, actions }) do
		if #group.hits > 0 then
			groups[#groups + 1] = group
		end
	end
	return ns.PanelSearch.Sort(groups)
end

-- A label with each typed word lit in the accent, wherever it is in the label, in the label's own letters.
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
				if row.label then
					row.label:SetText(Lit(hit.label, words))
				end
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
	local found = #view.shown
	ui.head.Set(nil, found == 0 and "No results" or found == 1 and "1 result" or ("%d results"):format(found))
	ui.tabs.Hide()
	ui.preview.Set(nil, 0)
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
		local status = false
		if not text then
			-- A message taken away before its fade in ends leaves the strip at full strength.
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
		-- The count of changes on the tab takes clicks (ui.NextChanged) over the width of its words, and only while it shows.
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
	-- A tab shows under the title of its module, and the module has the switch in the header.
	local top = ns.PanelNav.Top(ui.model, entry)
	ui.title:SetText(top.label)
	ui.head.Set(top, Subtitle(entry))
	local band = ui.tabs.Set(entry)
	-- The preview band is under the tabs, and the rows start under the band.
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
		-- The dots of the tabs that hold changes (PanelTabs.lua).
		if ui.tabs and ui.tabs.Marks then
			ui.tabs.Marks()
		end
		if ui.ShowReload then
			ui.ShowReload()
		end
		-- Reset page is dimmed while nothing on the tab is changed.
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

-- The window's own actions that Search finds (PanelSearch.ACTIONS), by id: what Open runs, its tip and, for Test mode, the word of its button. Test
-- mode is the switch of the title bar (BuildTestSwitch); in a fight it asks for test mode at the fight's end, or takes that back (TestToggle).
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
	if ui.Keys then
		ui.Keys()
	end
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
	-- Setup paints a draft and the samples of test mode the live profile, so a mode that takes the window ends test mode (TestMode.lua).
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

-- Gives the window back to the options pages from a mode, at the page they showed before it (Back from setup's first screen). The mode's Hidden runs
-- first, as when the window closes, so the mode keeps what it keeps then.
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

	-- The search field is in the title bar, so that it stays when the sidebar is a rail.
	local box = Field(window, 360, 40)
	box:SetHeight(22)
	box:SetPoint("TOPLEFT", window, "TOPLEFT", 256, -7)
	local hint = Dim(Label(box, "GameFontHighlight", "LEFT"))
	hint:SetPoint("LEFT", box, "LEFT", 8, 0)
	hint:SetText("Search")
	-- A cross at the right of the box while words are typed, two lines in the dim text, in the text colour under the mouse: a click clears the words,
	-- shows the page again (Search) and keeps the cursor in the box for the next search. The words keep clear of it (SetTextInsets).
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
	-- Escape clears the words and shows the page again.
	box:SetScript("OnEscapePressed", function(self)
		local typed = self:GetText()
		if IsText(typed) and typed ~= "" then
			self:SetText("")
		end
		self:ClearFocus()
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

-- Reset page, Reload and Done, at the right of the strip. Reset page sets every setting of the tab to its default after a question, and the strip
-- says how many went back; its writes are one batch of Home's record (ui.batch), so one Ctrl+Z puts the page back. With nothing changed on the tab
-- it is dimmed and a click only says so (RefreshAll dims it).
local function BuildFoot(window)
	local foot = Frame(ui.stripFrame)
	foot:SetAllPoints(ui.stripFrame)
	ui.optionParts[#ui.optionParts + 1] = foot
	local done = Button(foot, "Done", 88, function()
		window:Hide()
	end, true)
	done:SetPoint("RIGHT", foot, "RIGHT", -12, 0)
	-- While changes wait for a reload it reads "Reload (2)" in the accent (RefreshAll, ui.ShowReload), and pointing at it lists them as the reload
	-- notice does (Reload.lua, ns.ReloadTip); with none it is plain and its tip says so. The tone is its colour and not its alpha, which Reload.lua dims
	-- in a fight. Its hover scripts are wrapped with SetScript, since the secure button over it runs them through GetScript (Reload.lua's Cover),
	-- which leaves hooks out.
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
	ui.reset = Button(foot, "Reset page", 100, function()
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
				-- Every row it writes is noted in one batch, which Ctrl+Z puts back whole.
				ui.batch = { label = "Reset page on " .. place, what = "Reset page" }
				local ok, err = pcall(function()
					for _, item in ipairs(entry.page) do
						-- A row the game holds is not written: its default is the game's, not this page's.
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
	-- Its tip in the strip; the hover fill of the button stays (HookScript on a frame of Flat UI's own).
	ui.reset:HookScript("OnEnter", function()
		ui.message, ui.tip = nil, "Puts every setting of this tab back to its default. Settings the game holds keep their value."
		ShowStrip()
	end)
	ui.reset:HookScript("OnLeave", function()
		ui.tip = ""
		ShowStrip()
	end)
	ui.strip:SetWidth(WIDTH - 24 - 330)
end

-- A click of Test mode (the switch, or its Search result): out of a fight it turns test mode on or off with the switch's sound. In a fight TestMode
-- keeps the wish (TM.On), so the fight's end turns it on while the window is open, and a second click takes it back; the strip says which.
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

-- Test mode (TestMode.lua): a switch just left of Close, with the track and knob of the Bool rows, in the parts of the options pages so it hides
-- while Setup has the window. It reads the state again in RefreshAll; in a fight it is dim and reads After combat, and a click asks for test mode at
-- the fight's end, which shows as the knob on, dimmed, until it comes on or the window closes (TestToggle).
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
		word:SetText(fight and "After combat" or "Test mode")
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

-- The profile the changes go into, dim, left of the Test mode switch on every options page ("Profile: Raid"); a long name is cut short. Pointing at
-- it says how many characters use the profile, a click opens Profiles, and a change of profile while the window is open (Switch automatically, a
-- slash command) tints it in the accent for a second (PROFILE_FLASH). A profile that waits for the fight's end, picked in a fight (KeepProfile,
-- /flatui profile Name) or due by a rule of Switch automatically, shows on a second line under it in the accent ("Raid after the fight",
-- ProfileSwitch.lua's Switch.Wanted), in the same 160 units, so it never reaches the Search box. RefreshAll sets it; it is in the parts of the
-- options pages, so it hides while a mode has the window.
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
	-- What waits for the fight's end, and whether a rule of Switch automatically wants it.
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
		-- Refreshed every REFRESH while the window is open, so a change seen within two seconds of the last look is one made while it was open.
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
		-- What waits for the fight's end is a second line under the name, in the same width.
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
	frame:SetScript("OnEnter", function()
		local now = CurrentProfile()
		if now == "" then
			return
		end
		local count = ns.PanelHome and ns.PanelHome.UserCount and ns.PanelHome.UserCount(now) or 1
		ui.message = nil
		ui.tip = ("Changes here are saved in %s, used by %d character%s. Click for Profiles."):format(now, count, count == 1 and "" or "s")
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
	-- Ctrl and the wheel over the title bar set Window scale, 5% a step, between 80% and 150%, and the strip says the new scale. Pointing at the bar
	-- says so, with the scale now.
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
	-- Setup keeps the strip for its own words.
	bar:SetScript("OnEnter", function()
		if ui.mode then
			return
		end
		local scale = ns.Get("panel.scale")
		ui.message = nil
		ui.tip = ("Drag to move. Ctrl and the mouse wheel: Window scale, now %d%%."):format(Number(scale) and scale or 100)
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
	-- "3 changed on this tab. Click to go to each.": a frame over its words, shown by ShowStrip while the strip shows that count, lights them in the
	-- accent under the mouse, and a click goes to the next changed row (ui.NextChanged).
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

-- The keys of the options pages come through a frame of Flat UI's own that has the keyboard while the pages show, out of combat only
-- (EnableKeyboard and SetPropagateKeyboardInput are protected in a fight; Setup.lua's S.BuildKeys does the same for setup, whose window this frame
-- leaves to it): Ctrl+F puts the cursor in Search, Escape closes an open list or question and leaves the window open, and Enter answers a question
-- with its first button. Every other key goes on to the game, and Escape too when nothing is open, so it closes the window as before. A box with
-- the cursor takes the keys first.
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
	-- Ctrl+Z: the newest change of Home's Recent changes goes back, and the strip says what (PanelHome.lua, Home.UndoNewest). Ctrl+Y or
	-- Ctrl+Shift+Z makes again what it took back (Home.Redo). Either shows the row it changed, or names its place (ui.ShowChange).
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
			-- A key taken here lets the next keys through again from the next frame, so the release of a key held meanwhile, such as one that
			-- walks, still reaches the game.
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
	-- A fight takes the keyboard from it at its start, the last moment that may, and gives it back after while the pages show.
	keys:RegisterEvent("PLAYER_REGEN_DISABLED")
	keys:RegisterEvent("PLAYER_REGEN_ENABLED")
	keys:SetScript("OnEvent", function(_, event)
		ui.Keys(event ~= "PLAYER_REGEN_DISABLED")
	end)
	ui.keys = keys
	-- Shown while the options pages have the window (no mode) and out of combat; allowed false hides it, at the start of a fight. It shows letting
	-- keys through, so a key held as it shows (one that walks) is let go in the game too.
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
	-- The height of a row is read here, since the account is loaded by now.
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
	-- Set before its parts are made, so each is made above it.
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
	-- It fades in over FADE_IN (OnUpdate, below) with the game's sound of a window opening, and plays the sound of one closing as it hides; it hides at
	-- once, since Escape hides it through UISpecialFrames. Hidden and shown again by /flatui move (MoversMode's Holding), it plays neither.
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
		-- Under the setting that sends windows back when they close, the options window opens at its default place.
		if ns.Get("movers.keepSpots") == "reset" then
			Look.ClearPosition()
		end
		CloseList()
		HideConfirm()
		ui.search:ClearFocus()
		-- Test mode turned on here ends with the window, but not while /flatui move holds the window hidden (MoversMode.lua's Holding).
		local test, movers = ns.TestMode, ns.MoversMode
		if type(test) == "table" and not (type(movers) == "table" and movers.Holding()) then
			if test.Source() == "panel" then
				test.Off("panel")
			end
			-- A wish of a fight made here goes with the window too.
			test.Drop("panel")
		end
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
		-- A message of the strip fades in, and goes after SAY_HOLD (Say).
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
	-- From here on its showing and hiding play the game's window sounds (the hide just above was the build's own).
	ui.ready = true
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
	elseif key == "preview" then
		if ui.current and not ui.searching and not ui.mode then
			ShowPage(ui.current)
		end
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
				print("Flat UI: Options open after combat.")
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
	Bool = AddBool, SwitchClick = SwitchClick, Slider = Slider, CopyField = CopyField,
	-- The pressed look of a Button, for a frame of Flat UI's own over it that takes its mouse (Reload.lua's secure button).
	Press = function(button, down) local press = ui.presses and ui.presses[button] if press then press(down == true) end end,
	Window = function() return ui.window end,
	Inset = function(parent, inset) insets[parent] = inset end,
	Tip = function(text) ui.message, ui.tip = nil, text or "" ShowStrip() end, Refresh = function() RefreshAll() end,
	Hide = function() if ui.window then ui.window:Hide() end end,
	Leave = LeaveMode,
	-- Closes the colour picker, an open list or a question, the one on top; true when one was open.
	Escape = function() local action = ui.EscapeAction() if action then action() return true end return false end,
	-- Enter as on the options pages (BuildKeys): the colour picker's Apply, else a question's first button but not a careful question's; true when
	-- it did one.
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

-- Opens the window in a mode (see SetMode), or leaves it in that mode when it is in it already. In combat before the window was ever built the
-- mode opens after combat, and mode.waiting is what is said meanwhile. Returns true when the window shows the mode now.
function ns.OpenPanelMode(mode)
	if not ui.window then
		if InCombatLockdown() then
			if not ui.waiting then
				ui.waiting = true
				print(mode.waiting or "Flat UI: Options open after combat.")
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

-- Opens the window at a page by its key (/flatui hide), and leaves it open when it is open already. False when the window or the page is not there.
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

-- /flatui <words> (Core.lua): opens the window, or leaves it open, with the words in Search, so the results show lit as when they are typed there, the
-- first picked, and Enter opens it; a miss shows the closest pages. While setup has the window, or in a fight before the window was ever built
-- (ns.OpenPanel says it opens after combat), nothing is searched and the answer is false.
function ns.OpenPanelSearch(words)
	if ui.window and ui.window:IsShown() and ui.mode then
		print("Flat UI: setup has the options window. Search once it is closed.")
		return false
	end
	if not (ui.window and ui.window:IsShown()) then
		ns.OpenPanel()
	end
	if not (ui.window and ui.window:IsShown()) or ui.mode or not IsText(words) then
		return false
	end
	-- OnTextChanged searches (BuildLeft); the same words again would not fire it.
	if ui.search:GetText() == words then
		Search(words)
	else
		ui.search:SetText(words)
	end
	ui.search:SetFocus()
	pcall(ui.search.SetCursorPosition, ui.search, #words)
	return true
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
-- has a layoutIndex, so nothing of the game's menu is written. It follows each build of the menu's buttons through ns.Follow, which leaves the method
-- alone while taintLog is on (ns.HookMethod): the menu then works as the game has it, without the button, for that session.
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
