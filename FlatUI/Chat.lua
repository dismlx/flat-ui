local _, ns = ...

-- The chat windows, the chat input box and the look of tooltips. The game fades the plates of a chat window with SetAlpha, so those are
-- hidden; art whose alpha the game leaves alone is made transparent. The flat boxes are textures of the addon's own. What the game sets again
-- is followed with hooksecurefunc on a global function of the game, with HookScript on GameTooltip, and with EventRegistry for the input box; no
-- method of a frame is hooked, and what runs inside a game call is done on the next frame. Tooltips are used by secure code: only texture calls are made on them, apart
-- from the lines the kind of a unit, an ID and a count add and what ChatTips.lua writes, and nothing is created on one in combat. The size of a tooltip, the height of its
-- health bar and the place of the input box are changed out of combat only. The fade of GameTooltip is seen as a fall of its alpha in a frame of the
-- addon's own (the game starts it in C++, GameTooltip:FadeOut in UnitFrame_OnLeave, Mainline/UnitFrame.lua:393 and the world cursor, GameTooltip.lua:1017);
-- Hide and SetAlpha are called from that frame, never inside a call of the game, and no method of GameTooltip is hooked.
-- ChatLinks.lua (called at the end of each refresh) also fills GameTooltip from a chat link under the mouse: SetOwner on a frame of its own,
-- SetHyperlink and Hide, never in a fight. ItemCompare.lua (called at the start of each refresh) writes the game's alwaysCompareItems.
-- ChatHistory.lua (called at the end of each refresh) keeps recent chat lines for this character and prints them after a reload.
-- Tooltips hidden by their kind, by hostility and place, and by the party and raid frames that own them follow the tooltip and the group frames of
-- EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoLTooltip/EnhanceQoLTooltip.lua:226-233, 973-977, 1420-1440, 1590-1594,
-- 1633-1636; EnhanceQoLUnitFrames/UF_GroupFrames.lua:6507-6536). They are hidden as the rows of Tooltips in combat are, with Hide on the tooltip
-- from the post call and from the OnShow of GameTooltip, so nothing more is hooked.

local KEY = "chat"

-- The alpha the game fades a chat window up to when the mouse is over it, whatever opacity the window has (FCF_FadeInChatFrame).
local HOVER_ALPHA = 0.25
-- Height of the box behind the label of a chat tab, in the units of the tab.
local PLATE_HEIGHT = 22
local COMPARE_PLATE = "tooltip-compare-label"
local BAR_FILE = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"

-- The border pieces of a bordered chat frame, after the name of the frame or of its button frame.
local BORDER = { "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
-- The art of a chat tab: the game shows and hides the selected pieces and tints the highlight, and sets the alpha of the tab alone.
local TAB_FADED = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight" }
local TAB_HIGHLIGHT = { "HighlightLeft", "HighlightMiddle", "HighlightRight" }
-- The art of the input box: three pieces the game never touches, and three it shows, hides and tints.
local BOX_ART = { "Left", "Mid", "Right" }
local BOX_FOCUS = { "focusLeft", "focusMid", "focusRight" }
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
-- The height of the health bar of a tooltip (GameTooltipStatusBar, 8 in the game's XML) and the opacity the game gives an idle input box
-- (ChatFrameEditBoxMixin:Deactivate, ChatFrameEditBox.lua:573).
local BAR_HEIGHT, IDLE_ALPHA = 8, 35
-- The font objects the game draws a tooltip with: the title line, and the other lines.
local TIP_TITLE, TIP_TEXT = { "GameTooltipHeaderText" }, { "GameTooltipText", "GameTooltipTextSmall" }
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
-- The colours of the tooltip background, red, green and blue from 0 to 1. Near black is the colour the general background has by default.
local TIP_COLOURS = {
	nearblack = { 15 / 255, 15 / 255, 15 / 255 },
	black = { 0, 0, 0 },
	darkblue = { 10 / 255, 20 / 255, 46 / 255 },
	darkbrown = { 32 / 255, 22 / 255, 14 / 255 },
}
-- The setup drawing of tooltips (SetupDrawChat.lua) paints with the same colours and shades.
ns.TipColours = TIP_COLOURS
-- A shaded tooltip goes from one colour at the top to another at the bottom. Lighter at the top is the chosen colour at the bottom and a
-- share (LIFT) of the way to white at the top. Darker at the bottom is the chosen colour at the top and a share (SINK) of it at the bottom.
-- A colour whose brightest channel is under DARK has too little to lose for that to show (Black, Near black), so its top gets a share (HINT)
-- of the way to white and the shade shows.
local LIFT, HINT, SINK, DARK = 0.12, 0.08, 0.3, 20 / 255
local SHADE_NOTE = "Chat and tooltips: the game cannot draw a gradient, so the tooltip background stays one colour."
-- The tooltips whose shade the client refused. The line for /flatui status stays while there is one.
local shadeRefused = setmetatable({}, { __mode = "k" })

-- Per chat frame: { outline, hovered, plates = true while the button plates are hidden }
local windows = setmetatable({}, { __mode = "k" })
-- Per chat tab: { outline, hover, selected }
local tabs = setmetatable({}, { __mode = "k" })
-- Per input box: { outline, parts, active = true while the game shows the focus art, r, g, b = the colour it tints it }
local boxes = setmetatable({}, { __mode = "k" })
-- Per tooltip: { outline, header = outline of the compare label, plate = its picture, byKind = true while the border has the colour of a unit,
-- kindData, kindLines = the data the kind line was added for and the number of lines after it }
local tips = setmetatable({}, { __mode = "k" })
local queued = setmetatable({}, { __mode = "k" })
-- Per input box: { points = the two points the game gave it, placed = true while it is above the window, idleSet = true while its idle opacity is set here }
-- Per tooltip: { base = the scale the game gave it }. Per font object of a tooltip: { base = its height, set = the height set here }.
-- Per tooltip: { data, lines } of the ID and count lines, and built = what its last build was: { owner = its owner then (true when it could not
-- be read), unit = true for the data of a unit, kind = "spell", "aura" or "item" (only with the owner read), hostile = whether you can attack the
-- unit (nil when the game will not say or no row asks), group = true when the owner is one of the game's party or raid frames }.
local X = { seats = setmetatable({}, { __mode = "k" }), scales = setmetatable({}, { __mode = "k" }), fonts = setmetatable({}, { __mode = "k" }),
	extras = setmetatable({}, { __mode = "k" }), built = setmetatable({}, { __mode = "k" }), bar = {} }
local hooked = {}
local postCall = false
local barOutline

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function On(part)
	return ns.Enabled(KEY) and Opt(part) == true
end

local function Usable(value)
	return value ~= nil and not ns.IsSecret(value) and type(value) == "table"
end

local function IsNumber(value)
	return not ns.IsSecret(value) and type(value) == "number"
end

-- A global frame or region.
local function Global(name)
	local value = _G[name]
	return Usable(value) and value or nil
end

local function IsShown(region)
	if not Usable(region) then
		return false
	end
	local ok, shown = pcall(region.IsShown, region)
	return ok and not ns.IsSecret(shown) and shown == true
end

-- Chat windows ------------------------------------------------------------------------------

-- The background and border pieces of a bordered frame. The game fades them with SetAlpha and never shows or hides them.
local function Plate(prefix, hidden)
	ns.SetHidden(Global(prefix .. "Background"), hidden)
	for _, part in ipairs(BORDER) do
		ns.SetHidden(Global(prefix .. part), hidden)
	end
end

-- The panel has the chosen opacity, and the game's rule for a window the mouse is over: never fainter than a quarter.
local function PaintWindow(record)
	local on = On("frames")
	local r, g, b = ns.Colour("general.backdrop")
	local alpha = Opt("opacity") / 100
	if record.hovered then
		alpha = math.max(alpha, HOVER_ALPHA)
	end
	ns.SetOutlineFill(record.outline, r, g, b, alpha)
	ns.SetOutlineEdges(record.outline, Opt("frameBorder") ~= false)
	ns.SetOutline(record.outline, on and alpha > 0, on and alpha > 0)
end

local function StyleWindow(frame, name)
	local frames, buttons = On("frames"), On("buttons")
	local record = windows[frame]
	if not record then
		if not (frames or buttons) then
			return
		end
		record = {}
		windows[frame] = record
	end
	if frames and not record.outline then
		local background = Global(name .. "Background")
		if background then
			record.outline = ns.Outline(frame, background)
			ns.Count(KEY)
		end
	end
	if record.outline then
		Plate(name, frames)
		PaintWindow(record)
	end
	if buttons or record.plates then
		Plate(name .. "ButtonFrame", buttons)
	end
	record.plates = buttons
end

local function Hover(frame, hovered)
	local record = Usable(frame) and windows[frame]
	if record and record.outline and On("frames") then
		record.hovered = hovered
		PaintWindow(record)
	end
end

-- Tabs --------------------------------------------------------------------------------------

-- A whisper tab has its own colour; the others take the highlight colour of the window skins.
local function SelectedColour(tab)
	local colours = tab.selectedColorTable
	if Usable(colours) then
		local r, g, b = colours.r, colours.g, colours.b
		if IsNumber(r) and IsNumber(g) and IsNumber(b) then
			return r, g, b
		end
	end
	return ns.Colour("windows.accent")
end

-- The alpha of a tab that is not selected, for each choice of Chat tab opacity. The game's own mouse-over value for a normal tab is 0.6
-- (Mainline/FloatingChatFrame.lua:19). The game's alpha for the tab, its stored pair and ChatFrameUtil.SetTabAlphas are left alone.
local TAB_OTHER = { clear = 0.6, full = 1 }

local function Bright(region, alpha)
	if region ~= nil and not ns.IsSecret(region) then
		local ignored = pcall(region.SetIgnoreParentAlpha, region, alpha ~= nil)
		if ignored or alpha == nil then
			pcall(region.SetAlpha, region, alpha or 1)
		end
	end
end

local function Alerting(tab)
	if type(ChatFrameUtil) ~= "table" or type(ChatFrameUtil.IsTabAlerting) ~= "function" then
		return false
	end
	local ok, alerting = pcall(ChatFrameUtil.IsTabAlerting, tab)
	return ok and not ns.IsSecret(alerting) and alerting == true
end

-- The label and the flat box (its edges and fill are textures of the tab) take their own alpha, so the game's 0.4 and 0.2 do not dim them.
local function BrightTab(tab, record, on)
	local other = on and TAB_OTHER[Opt("tabOpacity")]
	local alpha = other and ((record.selected or Alerting(tab)) and 1 or other) or nil
	if alpha == nil and not record.bright then
		return
	end
	record.bright = alpha ~= nil
	local ok, label = pcall(tab.GetFontString, tab)
	Bright(ok and label or nil, alpha)
	local outline = record.outline
	if outline then
		Bright(outline.backdrop, alpha)
		for _, edge in ipairs(outline.edges) do
			Bright(edge, alpha)
		end
	end
end

local function PaintTab(tab, record)
	local on = On("tabs")
	BrightTab(tab, record, on)
	for _, key in ipairs(TAB_FADED) do
		ns.SetFaded(tab[key], on)
	end
	for _, key in ipairs(TAB_HIGHLIGHT) do
		ns.SetHidden(tab[key], on)
	end
	ns.SetOutline(record.outline, on, on)
	local r, g, b
	if on and record.selected then
		r, g, b = SelectedColour(tab)
	end
	ns.SetOutlineColour(record.outline, r, g, b)
	local hr, hg, hb = ns.Colour("windows.accent")
	record.hover:SetColorTexture(hr, hg, hb, 0.25)
	record.hover:SetShown(on)
end

-- A tab is styled when the window is, and when the game colours it, which it does for a tab made later too.
local function StyleTab(tab, selected)
	if not Usable(tab) or ns.Forbidden(tab) then
		return
	end
	local record = tabs[tab]
	if not record then
		if not On("tabs") then
			return
		end
		local plate = CreateFrame("Frame", nil, tab)
		ns.Own[plate] = true
		plate:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
		plate:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
		plate:SetHeight(PLATE_HEIGHT)
		local hover = tab:CreateTexture(nil, "HIGHLIGHT", nil, 0)
		ns.Own[hover] = true
		hover:SetAllPoints(plate)
		record = { outline = ns.Outline(tab, plate, true), hover = hover }
		tabs[tab] = record
		ns.Count(KEY)
	end
	if selected ~= nil then
		record.selected = selected
	elseif record.selected == nil then
		record.selected = IsShown(tab.ActiveMiddle)
	end
	PaintTab(tab, record)
end

-- Input box ---------------------------------------------------------------------------------

local function PaintBox(record)
	local on = On("editbox")
	for _, part in ipairs(record.parts) do
		ns.SetFaded(part, on)
	end
	ns.SetOutline(record.outline, on, on)
	local r, g, b
	if on and record.active then
		local mode = Opt("inputFocus")
		if mode == "accent" then
			r, g, b = ns.Colour("windows.accent")
		elseif mode ~= "plain" then
			r, g, b = record.r, record.g, record.b
		end
	end
	ns.SetOutlineColour(record.outline, r, g, b)
end

-- The game shows the focus art and tints it by chat type. Its state is read from the art itself, so nothing follows the game's own calls:
-- the passes below run a frame after the box gains or loses the focus, is shown or hidden, or the tint may have changed.
-- Whether the input box has the keyboard focus, which the game gives it while it is open.
local function Typing(box)
	local ok, focus = pcall(box.HasFocus, box)
	return ok and not ns.IsSecret(focus) and focus == true
end

local typing = setmetatable({}, { __mode = "k" })
local Watch
local function ReadFocus(box)
	local record, art = boxes[box], box.focusLeft
	if not record or not Usable(art) then
		return
	end
	local ok, shown = pcall(art.IsShown, art)
	local active = ok and not ns.IsSecret(shown) and shown == true
	local r, g, b
	local got, gr, gg, gb = pcall(art.GetVertexColor, art)
	if got and IsNumber(gr) and IsNumber(gg) and IsNumber(gb) then
		r, g, b = gr, gg, gb
	end
	if record.active ~= active or record.r ~= r or record.g ~= g or record.b ~= b then
		record.active, record.r, record.g, record.b = active, r, g, b
		PaintBox(record)
	end
	if active and not typing[box] and Typing(box) then
		Watch(box, true)
	end
end

local function StyleBox(box, name)
	if not Usable(box) or ns.Forbidden(box) then
		return
	end
	local record = boxes[box]
	if not record then
		if not On("editbox") then
			return
		end
		record = { outline = ns.Outline(box, box, true), parts = {} }
		for _, suffix in ipairs(BOX_ART) do
			record.parts[#record.parts + 1] = Global(name .. "EditBox" .. suffix)
		end
		for _, key in ipairs(BOX_FOCUS) do
			if Usable(box[key]) then
				record.parts[#record.parts + 1] = box[key]
			end
		end
		boxes[box] = record
		ns.Count(KEY)
	end
	PaintBox(record)
	ReadFocus(box)
end

-- Runs one part of the module that calls the client on something the module did not make: fn(object, restore, ...). With the module off, or the
-- part stopped after enough refusals, the part is run to put the game's value back, and a refusal then is let go.
local function Part(part, fn, object, ...)
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, part) then
		ns.EachPart(KEY, part, fn, object, false, ...)
	else
		pcall(fn, object, true, ...)
	end
end

-- One anchor of the input box as the game gave it: { point, frame, point of the frame, x, y }.
local function ReadPoint(box, index)
	local ok, point, relative, relativePoint, x, y = pcall(box.GetPoint, box, index)
	if not ok or ns.IsSecret(point) or type(point) ~= "string" or not Usable(relative) or ns.IsSecret(relativePoint) or type(relativePoint) ~= "string"
		or not IsNumber(x) or not IsNumber(y) then
		error("GetPoint gave nothing for the input box", 0)
	end
	return { point, relative, relativePoint, x, y }
end

local function Anchors(box, points)
	box:ClearAllPoints()
	for _, point in ipairs(points) do
		box:SetPoint(point[1], point[2], point[3], point[4], point[5])
	end
end

-- The input box above its window: its left corner on the window's top left, and the point on its right the game gave it. Below puts the two
-- points the game gave it back. Nothing in Blizzard_ChatFrameBase anchors the box again.
local function PlaceBox(box, record, frame, above)
	if above and not record.placed then
		if record.points == nil then
			local ok, count = pcall(box.GetNumPoints, box)
			if not ok or not IsNumber(count) or count ~= 2 then
				error("the input box does not have two points", 0)
			end
			record.points = { ReadPoint(box, 1), ReadPoint(box, 2) }
		end
		local right
		for _, point in ipairs(record.points) do
			if point[1]:find("RIGHT", 1, true) then
				right = point
			end
		end
		if not right then
			error("the input box has no point on its right", 0)
		end
		local ok, err = pcall(Anchors, box, { { "BOTTOMLEFT", frame, "TOPLEFT", -5, 2 }, right })
		if not ok then
			pcall(Anchors, box, record.points)
			error(err, 0)
		end
		record.placed = true
	elseif not above and record.placed then
		record.placed = nil
		local ok, err = pcall(Anchors, box, record.points)
		if not ok then
			error(err, 0)
		end
	end
end

-- The game sets an idle box to 0.35 in Deactivate and to 1 when it opens. The row sets it on the frame after the box loses the focus or is hidden
-- (EventRegistry, below), and puts the game's value back when it goes back to the game's. A box with the focus keeps the opacity the game gave it.
local function IdleBox(box, record, on)
	local gm = box.isGM
	if ns.IsSecret(gm) or gm == true then
		return
	end
	local idle = Opt("inputIdle")
	local alpha
	if on and idle ~= IDLE_ALPHA then
		alpha, record.idleSet = idle / 100, true
	elseif record.idleSet then
		alpha, record.idleSet = IDLE_ALPHA / 100, nil
	end
	if alpha ~= nil and not Typing(box) and not pcall(box.SetAlpha, box, alpha) then
		error("SetAlpha refused for the input box", 0)
	end
end

local function Deactivated(box, restore, record)
	IdleBox(box, record, not restore)
end

local function SeatBox(box, restore, frame)
	if ns.Forbidden(box) then
		return
	end
	local record = X.seats[box]
	if not record then
		if restore or (Opt("inputPlace") == "below" and Opt("inputIdle") == IDLE_ALPHA) then
			return
		end
		record = {}
		X.seats[box] = record
	end
	PlaceBox(box, record, frame, not restore and Opt("inputPlace") == "above")
	IdleBox(box, record, not restore)
end

-- The passes of an input box. The game calls EventRegistry for the four moments a box changes (Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:389,
-- 394, 407, 415): the callbacks only queue a pass for the next frame, because Deactivate, ActivateChat and the tint run inside the game's own calls.
-- No method of an input box is hooked (EllesmereUIChat/EllesmereUIChat.lua:4410-4417, 4236-4260 and the same callbacks).
local settling = setmetatable({}, { __mode = "k" })
local watcher, watchWait

-- The game has closed a box when it is hidden or its focus art is hidden (Deactivate hides the art, ChatFrameEditBox.lua:586; ActivateChat shows
-- it, ChatFrameUtil.lua:554). An empty box is closed when it loses the focus; a box with text stays open, and keeps what the game gave it.
local function Closed(box)
	return not IsShown(box) or not IsShown(box.focusLeft)
end

-- The game calls Deactivate with no moment of its own in two places (Mainline/FloatingChatFrame.lua:270-271, ChatFrameUtil.lua:598-601), so every box with a
-- seat is settled on any moment.
local function Pass(box)
	settling[box] = nil
	if ns.IsStopped(KEY) then
		return
	end
	if boxes[box] then
		ns.Each(KEY, ReadFocus, box)
	end
	for seated, seat in pairs(X.seats) do
		if Usable(seated) and Closed(seated) then
			Part("input box opacity", Deactivated, seated, seat)
		end
	end
end

local function Settle(box)
	if settling[box] then
		return
	end
	settling[box] = true
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, function() Pass(box) end)) then
		Pass(box)
	end
end

-- The game tints the focus art again when the chat type changes while the box is open, with no moment of its own to follow, so the tint is read
-- about ten times a second while a box has the focus.
function Watch(box, on)
	typing[box] = on or nil
	if on and not watcher and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and Usable(frame) then
			ns.Own[frame] = true
			watcher, watchWait = frame, 0
			frame:SetScript("OnUpdate", function(_, elapsed)
				watchWait = watchWait + elapsed
				if watchWait < 0.1 then
					return
				end
				watchWait = 0
				for held in pairs(typing) do
					if Typing(held) then
						if not ns.IsStopped(KEY) then
							ns.Each(KEY, ReadFocus, held)
						end
					else
						typing[held] = nil
					end
				end
				if next(typing) == nil then
					frame:Hide()
				end
			end)
		end
	end
	if watcher then
		watcher:SetShown(next(typing) ~= nil)
	end
end

local function BoxMoment(gained)
	return function(_, box)
		if Usable(box) and (boxes[box] or X.seats[box]) then
			if gained ~= nil then
				Watch(box, gained)
			end
			Settle(box)
		end
	end
end

-- Every chat window the game has made, with its tab and input box.
local function Chat()
	if not Usable(CHAT_FRAMES) then
		return
	end
	for _, name in ipairs(CHAT_FRAMES) do
		local frame = type(name) == "string" and Global(name)
		if frame and not ns.Forbidden(frame) then
			ns.Each(KEY, StyleWindow, frame, name)
			local tab, box = Global(name .. "Tab"), Global(name .. "EditBox")
			if tab then
				ns.Each(KEY, StyleTab, tab)
			end
			if box then
				ns.Each(KEY, StyleBox, box, name)
				Part("input box place", SeatBox, box, frame)
			end
		end
	end
	if type(ns.ChatTextPass) == "function" then
		ns.ChatTextPass()
	end
end

-- Tooltips ----------------------------------------------------------------------------------

local function Pieces(tooltip, faded)
	local slice = tooltip.NineSlice
	if Usable(slice) then
		for _, piece in ipairs(PIECES) do
			ns.SetFaded(slice[piece], faded)
		end
	end
end

-- The colour at the top and the colour at the bottom of a shaded tooltip, or nothing for one colour.
function ns.TipShades(colour, shading)
	local r, g, b = colour[1], colour[2], colour[3]
	if shading == "lighter" then
		return { r + (1 - r) * LIFT, g + (1 - g) * LIFT, b + (1 - b) * LIFT }, { r, g, b }
	elseif shading == "darker" then
		local top = { r, g, b }
		if math.max(r, g, b) < DARK then
			top = { r + (1 - r) * HINT, g + (1 - g) * HINT, b + (1 - b) * HINT }
		end
		return top, { r * SINK, g * SINK, b * SINK }
	end
end

-- The background of a tooltip, or of the label above a comparison tooltip: the colour chosen at the opacity chosen, and for the tooltip
-- itself the shading chosen. Texture calls only, so it can change while a tooltip is up in combat. With the tooltips off the box is
-- hidden and the game's art is back, so there is nothing to paint. Returns false when the shading was refused.
local function PaintFill(outline, on, label)
	if not on then
		return nil
	end
	local colour = TIP_COLOURS[Opt("tipBackground")] or TIP_COLOURS.nearblack
	ns.SetOutlineFill(outline, colour[1], colour[2], colour[3], Opt("tipOpacity") / 100)
	local top, bottom = nil, nil
	if not label then
		top, bottom = ns.TipShades(colour, Opt("tipShading"))
	end
	return ns.SetOutlineShade(outline, top, bottom)
end

local function PaintTooltip(tooltip, record)
	local on = On("tooltips")
	Pieces(tooltip, on)
	ns.SetOutline(record.outline, on, on)
	shadeRefused[tooltip] = PaintFill(record.outline, on) == false or nil
	if next(shadeRefused) then
		ns.Note(KEY, SHADE_NOTE)
	else
		ns.ClearNote(KEY, SHADE_NOTE)
	end
	if record.header then
		ns.SetOutline(record.header, on, on)
		PaintFill(record.header, on, true)
		ns.SetFaded(record.plate, on)
	end
	local keep
	if record.byUnit then
		keep = Opt("unitBorder") ~= "plain"
	elseif record.byKind then
		keep = Opt("kindBorder")
	else
		keep = Opt("quality")
	end
	if not (on and keep) then
		ns.SetOutlineColour(record.outline, nil, nil, nil)
	end
end

-- Made out of combat, since it puts textures and a frame on a tooltip. The game's art stays until then.
local function BuildTooltip(tooltip)
	if tips[tooltip] or ns.Forbidden(tooltip) or not On("tooltips") or not Usable(tooltip.NineSlice) then
		return
	end
	local record = { outline = ns.Outline(tooltip, tooltip, true, "tip") }
	local header = tooltip.CompareHeader
	if Usable(header) and not ns.Forbidden(header) then
		record.header = ns.Outline(header, header, nil, "tip")
		record.plate = ns.RegionWithAtlas(header, COMPARE_PLATE)
		if not record.plate then
			ns.Note(KEY, "Chat and tooltips: the default label above a comparison tooltip was not found and is still shown.")
		end
	end
	tips[tooltip] = record
	ns.Count(KEY)
	PaintTooltip(tooltip, record)
end

local function Tooltip(tooltip)
	if ns.Forbidden(tooltip) then
		return
	end
	local record = tips[tooltip]
	if record then
		PaintTooltip(tooltip, record)
	elseif On("tooltips") and not queued[tooltip] then
		queued[tooltip] = true
		ns.OutOfCombat(function()
			queued[tooltip] = nil
			ns.Each(KEY, BuildTooltip, tooltip)
		end)
	end
end

-- The game draws its art again whenever it sets the backdrop style, and clears the style when a tooltip is hidden.
local function Backdrop(tooltip, style)
	local record = Usable(tooltip) and tips[tooltip]
	if record then
		Pieces(tooltip, On("tooltips"))
		if not ns.IsSecret(style) and style == nil then
			ns.SetOutlineColour(record.outline, nil, nil, nil)
		end
	end
end

-- Whether the data is of a kind of the game's tooltip data: "Item" or "Unit".
local function IsData(data, name)
	if not Usable(data) or type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" then
		return false
	end
	local kind = data.type
	return not ns.IsSecret(kind) and kind ~= nil and kind == Enum.TooltipDataType[name]
end

-- The game colours the name of an item by its quality and leaves the border alone. Grey and white names keep the plain border.
local function NameColour(tooltip)
	local line = tooltip.TextLeft1
	if not Usable(line) then
		return nil
	end
	local ok, r, g, b = pcall(line.GetTextColor, line)
	if not ok or not (IsNumber(r) and IsNumber(g) and IsNumber(b)) or (math.abs(r - g) < 0.01 and math.abs(g - b) < 0.01) then
		return nil
	end
	return r, g, b
end

-- The word and the colour of the kind of the unit in the data, found as the game finds the unit of a tooltip (TooltipUtil.GetDisplayedUnit):
-- the token of its guid. A token or classification the client withholds gives no kind.
local function UnitKind(data)
	local guid = data.guid
	if ns.IsSecret(guid) or type(guid) ~= "string" or type(UnitTokenFromGUID) ~= "function" then
		return nil
	end
	local kind = ns.UnitKind(UnitTokenFromGUID(guid))
	return kind and ns.KINDS[kind] or nil
end

-- The kind of the unit a unit tooltip shows. Nothing for any other data, for a unit that is not an elite, a rare or a boss, and when the
-- client withholds or refuses anything on the way.
local function TooltipKind(tooltip, data)
	if not IsData(data, "Unit") or ns.Forbidden(tooltip) then
		return nil
	end
	local ok, kind = pcall(UnitKind, data)
	return ok and kind or nil
end

-- The word goes at the end of the tooltip, once for each build of it. The game fetches new data for each build, and the post calls may run
-- more than once for one, so the same data with the lines of the first call still there is the same build.
local function AddKind(tooltip, record, data, kind)
	local ok, lines = pcall(tooltip.NumLines, tooltip)
	if not ok or not IsNumber(lines) or (record.kindData == data and lines >= record.kindLines) then
		return
	end
	if pcall(tooltip.AddLine, tooltip, kind.word, kind.colour[1], kind.colour[2], kind.colour[3]) then
		record.kindData, record.kindLines = data, lines + 1
	end
end

-- Called by the game after it has filled a tooltip from data, for every kind of tooltip.
local function Filled(tooltip, data)
	local record = Usable(tooltip) and tips[tooltip]
	if not (record and On("tooltips")) then
		return
	end
	local word, border = Opt("kindWord"), Opt("kindBorder")
	local r, g, b
	if Opt("quality") and IsData(data, "Item") then
		r, g, b = NameColour(tooltip)
	end
	local kind = (word or border) and TooltipKind(tooltip, data)
	local unit = record.unitColour
	if not IsData(data, "Unit") then
		unit, record.unitColour = nil, nil
	end
	record.byKind, record.byUnit = false, false
	if kind then
		if border then
			r, g, b = kind.colour[1], kind.colour[2], kind.colour[3]
			record.byKind = true
		end
		if word then
			AddKind(tooltip, record, data, kind)
		end
	end
	if unit and Opt("unitBorder") ~= "plain" then
		r, g, b = unit[1], unit[2], unit[3]
		record.byKind, record.byUnit = false, true
	end
	if border or Opt("quality") or record.byUnit then
		ns.SetOutlineColour(record.outline, r, g, b)
	end
end

-- Extra lines: the ID of an item or a spell, and how many of an item the player has, after the lines the game made. The same data with the
-- lines of the first call still there is the same build. A buff or debuff counts as a spell: the id of its data is the spell's, and the game
-- withholds it while it restricts auras (C_TooltipInfo.GetUnitAura is SecretWhenUnitAuraRestricted, TooltipInfoDocumentation.lua:1197-1216).
local function Extras(tooltip, data)
	if not ns.Enabled(KEY) or not (Opt("ids") or Opt("count")) or not Usable(tooltip) or ns.Forbidden(tooltip) then
		return
	end
	local item, spell = IsData(data, "Item"), IsData(data, "Spell") or IsData(data, "UnitAura")
	local id = (item or spell) and data.id
	if not IsNumber(id) then
		return
	end
	local lines = {}
	-- The ID lines, with Show IDs and the temporary enchant, come from ChatTips.lua.
	ns.ChatTipIds(lines, data, item, id)
	if item and Opt("count") and type(C_Item) == "table" and type(C_Item.GetItemCount) == "function" then
		local okBags, bags = pcall(C_Item.GetItemCount, id)
		local okAll, all = pcall(C_Item.GetItemCount, id, true)
		if okBags and okAll and IsNumber(bags) and IsNumber(all) then
			lines[#lines + 1] = all > bags and ("Count: %d in bags, %d with bank"):format(bags, all) or ("Count: %d in bags"):format(bags)
		end
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	local record = X.extras[tooltip]
	if #lines == 0 or not ok or not IsNumber(shown) or (record and record.data == data and shown >= record.lines) then
		return
	end
	for _, text in ipairs(lines) do
		if not pcall(tooltip.AddLine, tooltip, text, 0.8, 0.8, 0.8) then
			return
		end
		shown = shown + 1
	end
	X.extras[tooltip] = { data = data, lines = shown }
end

-- The colour of a unit tooltip's border and of the name on its first line. Called by the game for the name line of a unit, after it is added
-- (TooltipDataHandler.lua:329-334); the game set the line's colour before that (TooltipDataRules.lua:7-16). Reaction takes that colour, class
-- takes the class colour of a player and the reaction colour of any other unit, and a token or class the client withholds changes nothing.
local function UnitLine(tooltip, lineData)
	if not ns.Enabled(KEY) or not Usable(tooltip) or not Usable(lineData) then
		return
	end
	local record = tips[tooltip]
	if record then
		record.unitColour = nil
	end
	local mode, names = Opt("unitBorder"), Opt("nameClass") == true
	local token = lineData.unitToken
	if (mode == "plain" and not names) or ns.IsSecret(token) or type(token) ~= "string" or ns.Forbidden(tooltip) then
		return
	end
	local cr, cg, cb
	if mode == "class" or names then
		local ok, player = false, nil
		if type(UnitIsPlayer) == "function" then
			ok, player = pcall(UnitIsPlayer, token)
		end
		if ok and not ns.IsSecret(player) and player == true then
			cr, cg, cb = ns.ClassColourOf(token)
		end
	end
	local line = tooltip.TextLeft1
	if names and cr and Usable(line) then
		pcall(line.SetTextColor, line, cr, cg, cb)
	end
	if record and mode ~= "plain" then
		local r, g, b = cr, cg, cb
		if not (mode == "class" and r) then
			local colour = lineData.leftColor
			r, g, b = nil, nil, nil
			if Usable(colour) and IsNumber(colour.r) and IsNumber(colour.g) and IsNumber(colour.b) then
				r, g, b = colour.r, colour.g, colour.b
			end
		end
		if r then
			record.unitColour = { r, g, b }
		end
	end
end

-- True while the chosen key is down: Shift, Ctrl or Alt. A key the game does not say is down counts as up.
local function KeyDown(key)
	local down = key == "shift" and IsShiftKeyDown or key == "ctrl" and IsControlKeyDown or key == "alt" and IsAltKeyDown
	if type(down) ~= "function" then
		return false
	end
	local ok, pressed = pcall(down)
	return ok and not ns.IsSecret(pressed) and pressed == true
end

-- The owner of a tooltip, or nil when it cannot be read.
local function OwnerOf(tooltip)
	local ok, owner = pcall(tooltip.GetOwner, tooltip)
	if ok and Usable(owner) then
		return owner
	end
	return nil
end

-- True in a fight. An answer the game does not give counts as none, so nothing is hidden for it.
local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and not ns.IsSecret(fighting) and fighting == true
end

-- True in a dungeon or a raid: the game says the player is in an instance of the party or the raid kind (IsInInstance, InstanceDocumentation.lua:170-178).
local function InDungeon()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not ns.IsSecret(inside) and inside == true and not ns.IsSecret(kind) and (kind == "party" or kind == "raid")
end

-- The kinds of tooltip with a row of their own, by the type of the data (Enum.TooltipDataType: Spell 1, PetAction 11 and Macro 25 are spells, UnitAura 7
-- a buff or a debuff, Item 0 an item). A type the client withholds gives none (FOREVER.md, fact 24).
local KIND_OF = { Spell = "spell", PetAction = "spell", Macro = "spell", UnitAura = "aura", Item = "item" }
local KIND_ROW = { spell = "spellTips", aura = "auraTips", item = "itemTips" }

local function KindOf(data)
	for name, kind in pairs(KIND_OF) do
		if IsData(data, name) then
			return kind
		end
	end
	return nil
end

-- Whether you can attack the unit of a unit tooltip (UnitCanAttack, UnitDocumentation.lua:763-777): true or false, nil when the game will not say. The
-- token of the guid of the data comes first, as the game finds the unit of a tooltip (TooltipUtil.lua:34-42), since a tooltip of a frame need not be
-- the unit under the mouse; "mouseover" only when there is no such token.
local function Hostile(data)
	local token, guid = nil, nil
	if Usable(data) then
		guid = data.guid
	end
	if not ns.IsSecret(guid) and type(guid) == "string" and guid ~= "" and type(UnitTokenFromGUID) == "function" then
		local ok, found = pcall(UnitTokenFromGUID, guid)
		if ok and not ns.IsSecret(found) and type(found) == "string" and found ~= "" then
			token = found
		end
	end
	if not token then
		if type(UnitExists) ~= "function" then
			return nil
		end
		local ok, exists = pcall(UnitExists, "mouseover")
		if not ok or ns.IsSecret(exists) or exists ~= true then
			return nil
		end
		token = "mouseover"
	end
	if type(UnitCanAttack) ~= "function" then
		return nil
	end
	local ok, can = pcall(UnitCanAttack, "player", token)
	if not ok or ns.IsSecret(can) or type(can) ~= "boolean" then
		return nil
	end
	return can
end

-- True when the owner of a tooltip is one of the game's party or raid frames (UnitFrames.lua reads only their names and the pool of the party frame).
local function GroupOwned(owner)
	local extra = ns.UnitFrameExtra
	local test = type(extra) == "table" and extra.isGroupFrame or nil
	if owner == nil or type(test) ~= "function" then
		return false
	end
	local ok, yes = pcall(test, owner)
	return ok and yes == true
end

-- True while a row can hold a tooltip back. At the defaults none can, and a tooltip is never looked at.
local function Rules()
	return Opt("combat") ~= "show" or Opt("groupTips") ~= "other" or Opt("spellTips") ~= "show" or Opt("auraTips") ~= "show" or Opt("itemTips") ~= "show"
end

-- In this order: the row of the party and raid frames for a unit tooltip they own (Off, Out of combat only, Only with a key); then the key of Show
-- anyway while holding, which shows every other tooltip; then the row of the kind of a spell, aura or item tooltip (in combat, in dungeons and raids,
-- always); then Tooltips in combat, in combat and with Where also in a dungeon or a raid. A frame's tooltip the row of the group frames lets through,
-- its key held among them, still meets Tooltips in combat, as EnhanceQoL's group frames leave theirs to its tooltip rules (UF_GroupFrames.lua:6514-6536,
-- EnhanceQoLTooltip.lua:1420-1440). The rows of a kind and of the group frames are for GameTooltip, the tooltip of what is under the mouse: your own
-- buffs (Blizzard_BuffFrame/BuffFrame.lua:1211-1219) and those of the party and raid frames (Shared/PartyMemberFrame.lua:191-208,
-- Shared/CompactUnitFrame.lua:2056-2087) show there, while the target and focus frames show theirs in AuraButtonTooltip (Blizzard_AuraButton.lua:
-- 185-199), which is forbidden and out of the global names (Blizzard_AuraContainer/Mainline/Blizzard_AuraButtonTooltip.xml:3-4) and so is left as it
-- is. Hide unit tooltips holds back the tooltip of a unit's data, and one the game owns by the screen itself (a unit under the cursor), by Unit
-- tooltips hidden: every one, or only those of a unit you can attack (Enemies) or cannot (Friendly units). A unit the game will not say about is shown.
local function Withheld(tooltip)
	if not Rules() or not ns.Enabled(KEY) or ns.Forbidden(tooltip) then
		return false
	end
	local owner = OwnerOf(tooltip)
	local built = X.built[tooltip]
	if built ~= nil and built.owner ~= true and owner ~= nil and not rawequal(built.owner, owner) then
		-- Another owner has the tooltip since its build: what was built is not this tooltip. A nil owner is a hidden tooltip, not another owner.
		X.built[tooltip] = nil
		built = nil
	end
	local game = rawequal(tooltip, Global("GameTooltip"))
	local fighting = Fighting()
	if game and built ~= nil and built.group then
		local rule = Opt("groupTips")
		if rule == "off" or (rule == "ooc" and fighting) or (rule == "key" and not KeyDown(Opt("groupTipKey"))) then
			return true
		end
	end
	if KeyDown(Opt("combatKey")) then
		return false
	end
	local row = game and built ~= nil and built.kind and KIND_ROW[built.kind] or nil
	if row then
		local when = Opt(row)
		if when == "always" or (when == "combat" and fighting) or (when == "instance" and InDungeon()) then
			return true
		end
	end
	local mode = Opt("combat")
	if mode == "show" or not fighting or (Opt("combatWhere") == "instance" and not InDungeon()) then
		return false
	end
	if mode == "all" then
		return true
	end
	local unit = built ~= nil and built.unit == true
	if not (unit or rawequal(owner, UIParent)) then
		return false
	end
	local which = Opt("combatUnits")
	if which ~= "enemies" and which ~= "friends" then
		return true
	end
	local hostile
	if unit then
		hostile = built.hostile
	else
		-- A tooltip the game owns by the screen with no unit's data built for it: the unit under the cursor, if there is one.
		hostile = Hostile(nil)
	end
	if which == "enemies" then
		return hostile == true
	end
	return hostile == false
end

local function Shown(tooltip)
	if not ns.IsStopped(KEY) and Usable(tooltip) and Withheld(tooltip) then
		pcall(tooltip.Hide, tooltip)
	end
end

-- Notes what the data of a build is, then holds the tooltip back if it is to be. The owner is the owner of the build, or true when it cannot be
-- read: then any later tooltip is held back as a unit's, and no kind is noted, so a tooltip of a kind is shown.
local function Combat(tooltip, data)
	if Usable(tooltip) and not ns.Forbidden(tooltip) then
		local owner = OwnerOf(tooltip)
		local built = X.built[tooltip]
		if not built then
			built = {}
			X.built[tooltip] = built
		end
		built.owner, built.unit, built.kind, built.group, built.hostile = owner or true, IsData(data, "Unit"), nil, nil, nil
		if owner ~= nil then
			built.kind = KindOf(data)
		end
		if built.unit then
			if Opt("groupTips") ~= "other" then
				built.group = GroupOwned(owner)
			end
			if Opt("combat") == "units" and (Opt("combatUnits") == "enemies" or Opt("combatUnits") == "friends") then
				built.hostile = Hostile(data)
			end
		end
		if Rules() and IsShown(tooltip) then
			Shown(tooltip)
		end
	end
end

-- Fade out ----------------------------------------------------------------------------------
-- The game fades GameTooltip out when the mouse leaves a unit (UnitFrame_OnLeave, Mainline/UnitFrame.lua:393) or the world (GameTooltip.lua:1017): a call in C++
-- that lowers the alpha. EllesmereUI hooks the method (EllesmereUIBlizzardSkin.lua:2841); here the fall is seen in a frame of the addon's own while the
-- tooltip is up. Fast brings the alpha down in FADE_FAST seconds and hides the tooltip, At once hides it on the first frame of the fade. A tooltip built
-- again (the post calls) or shown again (OnShow) is not faded.
local FADE_FAST = 0.2
-- A fall of alpha this large is a fade.
local FADE_STEP = 0.02
local fadeDriver
-- The highest alpha seen on the tooltip while it was up, the seconds since a fade was seen (nil while there is none), and the owner the tooltip had when the fade was seen.
local fadeTop, fadeFor, fadeOwner

local function FadeEnd(tooltip, hide)
	if hide then
		pcall(tooltip.Hide, tooltip)
	end
	-- The alpha the addon lowered is put back, so the next tooltip starts as the game makes it.
	if fadeFor ~= nil and fadeTop ~= nil then
		pcall(tooltip.SetAlpha, tooltip, fadeTop)
	end
	fadeTop, fadeFor, fadeOwner = nil, nil, nil
end

-- True when the tooltip has an owner other than the one it had when the fade was seen. An owner that cannot be read is no change.
local function Reowned(tooltip)
	local now = OwnerOf(tooltip)
	return fadeOwner ~= nil and now ~= nil and not rawequal(now, fadeOwner)
end

local function FadeStep(elapsed)
	local tooltip = Global("GameTooltip")
	local mode = Opt("fadeOut")
	if mode == "game" or not tooltip then
		fadeTop, fadeFor = nil, nil
		return
	end
	local ok, alpha = pcall(tooltip.GetAlpha, tooltip)
	if not ok or ns.IsSecret(alpha) or type(alpha) ~= "number" or alpha ~= alpha then
		return
	end
	if fadeFor == nil then
		if fadeTop == nil or alpha > fadeTop then
			fadeTop = alpha
			return
		end
		if alpha >= fadeTop - FADE_STEP then
			return
		end
		fadeFor = 0
		fadeOwner = OwnerOf(tooltip)
	elseif alpha >= fadeTop - FADE_STEP then
		-- The game put the alpha back (a tooltip shown again): no fade is going on.
		FadeEnd(tooltip, false)
		return
	elseif Reowned(tooltip) then
		-- Another owner has the tooltip now (a tooltip of text shown over the fading one): the fade was the last tooltip's.
		FadeEnd(tooltip, false)
		return
	end
	fadeFor = fadeFor + (type(elapsed) == "number" and elapsed or 0)
	if mode == "now" or fadeFor >= FADE_FAST then
		FadeEnd(tooltip, true)
	else
		pcall(tooltip.SetAlpha, tooltip, math.min(fadeTop * (1 - fadeFor / FADE_FAST), fadeTop - 2 * FADE_STEP))
	end
end

-- The tooltip is shown or built again: a fade that was seen is over and the alpha goes back.
local function FadeCancel(tooltip)
	if fadeFor ~= nil and Usable(tooltip) and not ns.Forbidden(tooltip) then
		FadeEnd(tooltip, false)
	end
	fadeTop, fadeFor = nil, nil
end

-- The tooltip is shown: the alpha it starts with is the one a fade is measured from.
local function FadeShown(tooltip)
	FadeCancel(tooltip)
	if fadeDriver and Opt("fadeOut") ~= "game" then
		local ok, alpha = pcall(tooltip.GetAlpha, tooltip)
		if ok and not ns.IsSecret(alpha) and type(alpha) == "number" and alpha == alpha then
			fadeTop = alpha
		end
	end
end

-- The frame runs while GameTooltip is up and the row is not As the game has it.
local function FadeWatch()
	local tooltip = Global("GameTooltip")
	-- A forbidden GameTooltip stays forbidden, so it is tested here and never in a frame.
	if Opt("fadeOut") == "game" or not ns.Enabled(KEY) or not tooltip or ns.Forbidden(tooltip) then
		fadeTop, fadeFor = nil, nil
		if fadeDriver then
			fadeDriver:Hide()
		end
		return
	end
	if not fadeDriver then
		if type(CreateFrame) ~= "function" then
			return
		end
		fadeDriver = CreateFrame("Frame")
		ns.Own[fadeDriver] = true
		fadeDriver:SetScript("OnUpdate", function(_, elapsed)
			if not ns.IsStopped(KEY) then
				ns.Each(KEY, FadeStep, elapsed)
			end
		end)
		fadeDriver:Hide()
	end
	fadeDriver:SetShown(IsShown(tooltip))
end

local function FollowData()
	if postCall or type(TooltipDataProcessor) ~= "table" or type(TooltipDataProcessor.AddTooltipPostCall) ~= "function" or TooltipDataProcessor.AllTypes == nil then
		return
	end
	postCall = true
	TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
		if not ns.IsStopped(KEY) then
			-- ChatTips.lua: the target line, the class line and the icons, before the kind word so that it stays the last line.
			ns.Each(KEY, ns.ChatTipLines, tooltip, data)
			ns.Each(KEY, Filled, tooltip, data)
			ns.Each(KEY, Extras, tooltip, data)
			ns.Each(KEY, Combat, tooltip, data)
			ns.Each(KEY, FadeCancel, tooltip)
		end
	end)
	if type(TooltipDataProcessor.AddLinePostCall) == "function" and type(Enum) == "table" and type(Enum.TooltipDataLineType) == "table"
		and Enum.TooltipDataLineType.UnitName ~= nil then
		TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.UnitName, function(tooltip, lineData)
			if not ns.IsStopped(KEY) then
				ns.Each(KEY, UnitLine, tooltip, lineData)
			end
		end)
	end
end

-- Size and text of tooltips ------------------------------------------------------------------

-- The scale of a tooltip: the row's share of 1, and the scale the game gave it back at 100.
local function SizeTooltip(tooltip, restore)
	if ns.Forbidden(tooltip) then
		return
	end
	local want = restore and 100 or Opt("tipScale")
	local record = X.scales[tooltip]
	if want == 100 and not record then
		return
	end
	local ok, scale = pcall(tooltip.GetScale, tooltip)
	if not ok or not IsNumber(scale) then
		error("GetScale gave nothing for a tooltip", 0)
	end
	record = record or { base = scale }
	local target = want == 100 and record.base or want / 100
	if math.abs(scale - target) > 0.001 and not pcall(tooltip.SetScale, tooltip, target) then
		error("SetScale refused for a tooltip", 0)
	end
	X.scales[tooltip] = want ~= 100 and record or nil
end

-- The height of a font object of the game: the row's share of the height it had, and that height back at 100. A height set by another
-- addon or by the game since is the height to go back to.
local function SizeFont(object, restore, percent)
	local ok, _, height = pcall(object.GetFont, object)
	if not ok or not IsNumber(height) or height <= 0 then
		error("GetFont gave nothing for a tooltip font", 0)
	end
	local record = X.fonts[object]
	if record and record.set ~= nil and math.abs(height - record.set) > 0.5 then
		record.set = nil
	end
	local want = restore and 100 or percent
	if not record then
		if want == 100 then
			return
		end
		record = {}
		X.fonts[object] = record
	end
	if record.set == nil then
		record.base = height
	end
	local target = want == 100 and record.base or record.base * want / 100
	if math.abs(height - target) > 0.01 and not pcall(object.SetFontHeight, object, target) then
		error("SetFontHeight refused for a tooltip font", 0)
	end
	record.set = math.abs(target - record.base) > 0.01 and target or nil
end

-- The health bar of GameTooltip: faded for Hide the health bar (the game shows and hides it), and the row's height in place of the 8 of the
-- game's XML.
local function SizeBar(bar, restore)
	local state = X.bar
	local hide = not restore and Opt("barHide") == true
	if hide ~= (state.hidden == true) then
		ns.SetFaded(bar, hide)
		state.hidden = hide or nil
	end
	local height = restore and BAR_HEIGHT or Opt("barHeight")
	if height == BAR_HEIGHT and state.base == nil then
		return
	end
	local ok, current = pcall(bar.GetHeight, bar)
	if not ok or not IsNumber(current) then
		error("GetHeight gave nothing for the tooltip health bar", 0)
	end
	if state.base == nil then
		state.base = current
	end
	local target = height == BAR_HEIGHT and state.base or height
	if math.abs(current - target) > 0.01 and not pcall(bar.SetHeight, bar, target) then
		error("SetHeight refused for the tooltip health bar", 0)
	end
	if height == BAR_HEIGHT then
		state.base = nil
	end
end

-- The share of the height of a tooltip font that this module's rows give: 1 with the module or the part off. Fonts.lua multiplies its height by it
-- while it holds the object, so one module writes each font object.
function ns.TipTextShare(name)
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, "tooltip text size") then
		return 1
	end
	local row = name == TIP_TITLE[1] and "tipTitleSize" or (name == TIP_TEXT[1] or name == TIP_TEXT[2]) and "tipTextSize"
	local percent = row and Opt(row)
	return IsNumber(percent) and percent / 100 or 1
end

local function Fonts()
	local queue = false
	for _, list in ipairs({ TIP_TITLE, TIP_TEXT }) do
		local row = list == TIP_TITLE and "tipTitleSize" or "tipTextSize"
		for _, name in ipairs(list) do
			local object = Global(name)
			if object then
				if type(ns.FontsHolds) == "function" and ns.FontsHolds(object) then
					-- Fonts.lua sets this height. A height set here before goes back first, and Fonts.lua takes the game's from the object.
					if X.fonts[object] then
						pcall(SizeFont, object, true, 100)
						X.fonts[object] = nil
					end
					queue = true
				else
					Part("tooltip text size", SizeFont, object, Opt(row))
				end
			end
		end
	end
	if queue then
		ns.FontsQueue()
	end
end

-- Health bar --------------------------------------------------------------------------------

local function PaintBar(bar)
	local on = On("health")
	local shown = on and not (X.bar.hidden == true)
	ns.SetOutline(barOutline, shown, shown)
	if on then
		local id = ns.Get(KEY .. ".barTexture")
		local file = nil
		if id ~= "default" then
			file = ns.BarTexture(id) or false -- Flat has no file: false is a solid fill, nil the texture of the Flat UI page
		end
		local flat, refused = ns.FlatFill(bar, 1, 1, 1, BAR_FILE, true, file)
		if flat == false then
			ns.Note(KEY, refused and "Chat and tooltips: the game refused a flat fill on the tooltip health bar, which keeps its default fill."
				or "Chat and tooltips: the default fill of the tooltip health bar could not be read and is still shown.")
		end
	elseif ns.RestoreFill(bar) == false then
		ns.Note(KEY, "Chat and tooltips: the game refused to put back the default fill of the tooltip health bar.")
	end
end

local function BuildBar(bar)
	if barOutline or ns.Forbidden(bar) or not On("health") then
		return
	end
	barOutline = ns.Outline(bar, bar)
	ns.Count(KEY)
	PaintBar(bar)
end

local function HealthBar()
	local tooltip = Global("GameTooltip")
	local bar = tooltip and not ns.Forbidden(tooltip) and tooltip.StatusBar
	if not Usable(bar) then
		return
	end
	if barOutline then
		PaintBar(bar)
	elseif On("health") and not queued[bar] then
		queued[bar] = true
		ns.OutOfCombat(function()
			queued[bar] = nil
			ns.Each(KEY, BuildBar, bar)
		end)
	end
end

-- Done out of combat: a tooltip and its bar are frames the game uses in secure code.
local function Sizes()
	X.queued = nil
	for _, name in ipairs(TOOLTIPS) do
		local tooltip = Global(name)
		if tooltip then
			Part("tooltip size", SizeTooltip, tooltip)
		end
	end
	local game = Global("GameTooltip")
	local bar = game and not ns.Forbidden(game) and game.StatusBar
	if Usable(bar) then
		Part("tooltip health bar size", SizeBar, bar)
		if barOutline then
			ns.Each(KEY, PaintBar, bar)
		end
	end
end

-- Hooks -------------------------------------------------------------------------------------

-- A hook on a global function of the game, put on once and only when the function exists.
local function Follow(name, fn)
	if hooked[name] or type(hooksecurefunc) ~= "function" or type(_G[name]) ~= "function" then
		return
	end
	hooked[name] = true
	hooksecurefunc(name, function(...)
		if not ns.IsStopped(KEY) then
			ns.Each(KEY, fn, ...)
		end
	end)
end

-- The game colours a tab with the state it is in: true for the selected tab.
local function TabColours(tab, selected)
	local state
	if not ns.IsSecret(selected) then
		state = selected and true or false
	end
	StyleTab(tab, state)
end

-- The game starts and stops the flash of a tab with the chat frame as the argument; the tab is the frame's name and Tab.
local function TabAlert(frame)
	local ok, name = false, nil
	if Usable(frame) and not ns.Forbidden(frame) then
		ok, name = pcall(frame.GetName, frame)
	end
	local tab = ok and not ns.IsSecret(name) and type(name) == "string" and Global(name .. "Tab") or nil
	if tab and tabs[tab] then
		StyleTab(tab)
	end
end

-- The game opens a temporary window (a whisper, a pet battle log) inside its own call, so the window is styled on the frame after.
local pendingChat = false
local function ChatLater()
	if pendingChat then
		return
	end
	pendingChat = true
	local function run()
		pendingChat = false
		if not ns.IsStopped(KEY) then
			ns.Each(KEY, Chat)
		end
	end
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, run)) then
		run()
	end
end

local showHooked, hideHooked, registered = false, false, false

local function Hooks()
	Follow("FCF_FadeInChatFrame", function(frame) Hover(frame, true) end)
	Follow("FCF_FadeOutChatFrame", function(frame) Hover(frame, false) end)
	Follow("FCFTab_UpdateColors", TabColours)
	Follow("FCF_StartAlertFlash", TabAlert)
	Follow("FCF_StopAlertFlash", TabAlert)
	Follow("FCF_OpenTemporaryWindow", ChatLater)
	Follow("SharedTooltip_SetBackdropStyle", Backdrop)
	ns.Each(KEY, FollowData)
	local game = Global("GameTooltip")
	if game and ns.Enabled(KEY) and not showHooked and not ns.Forbidden(game) and type(game.HookScript) == "function" then
		showHooked = pcall(game.HookScript, game, "OnShow", function(tooltip)
			ns.Each(KEY, Shown, tooltip)
			ns.Each(KEY, FadeWatch)
			ns.Each(KEY, FadeShown, tooltip)
		end)
	end
	if game and ns.Enabled(KEY) and not hideHooked and not ns.Forbidden(game) and type(game.HookScript) == "function" then
		hideHooked = pcall(game.HookScript, game, "OnHide", function() ns.Each(KEY, FadeWatch) end)
	end
	if not registered and type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
		registered = pcall(function()
			EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", BoxMoment(true), "FlatUI.chat.focus")
			EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", BoxMoment(false), "FlatUI.chat.lost")
			EventRegistry:RegisterCallback("ChatFrame.OnEditBoxShow", BoxMoment(nil), "FlatUI.chat.show")
			EventRegistry:RegisterCallback("ChatFrame.OnEditBoxHide", BoxMoment(nil), "FlatUI.chat.hide")
		end)
	end
end

local function Refresh()
	-- First: it touches no frame, so a failure further on does not keep the game's own value from coming back when the module stops.
	if type(ns.ItemCompareSync) == "function" then
		ns.ItemCompareSync()
	end
	Hooks()
	Chat()
	for _, name in ipairs(TOOLTIPS) do
		local tooltip = Global(name)
		if tooltip then
			ns.Each(KEY, Tooltip, tooltip)
		end
	end
	Fonts()
	ns.Each(KEY, FadeWatch)
	if not X.queued then
		X.queued = true
		ns.OutOfCombat(Sizes)
	end
	ns.Each(KEY, HealthBar)
	if type(ns.ChatLinksSync) == "function" then
		ns.ChatLinksSync()
	end
	if type(ns.ChatHistorySync) == "function" then
		ns.ChatHistorySync()
	end
end

-- The words of the choice a row holds, as the page shows them.
local function Word(path)
	local def, value = ns.Def(path), ns.Get(path)
	for _, choice in ipairs(def and ns.Choices(def) or {}) do
		if choice[1] == value then
			return choice[2]
		end
	end
	return tostring(value)
end

-- What a row of a kind of tooltip says when it hides them.
local HIDDEN = { combat = "hidden in combat", instance = "hidden in dungeons and raids", always = "always hidden" }

-- The lines of /flatui status: what Tooltips in combat holds, the units it hides and where, and the key that shows them anyway; the kinds of
-- tooltip hidden and when; and the rule of the party and raid frames.
local function Status()
	if not ns.Enabled(KEY) or ns.IsStopped(KEY) then
		return {}
	end
	local mode, key = Opt("combat"), Opt("combatKey")
	local line = "Tooltips in combat: " .. Word(KEY .. ".combat")
	if mode == "units" and Opt("combatUnits") ~= "all" then
		line = line .. " (" .. Word(KEY .. ".combatUnits") .. ")"
	end
	if mode ~= "show" and Opt("combatWhere") == "instance" then
		line = line .. ", only in dungeons and raids"
	end
	if mode ~= "show" and key ~= "none" then
		line = line .. ", shown while you hold " .. Word(KEY .. ".combatKey")
	end
	local lines = { line }
	local kinds = {}
	-- The buffs and debuffs of the target and focus frames are in a tooltip of the game's own, which stays (see Withheld).
	for _, kind in ipairs({ { "spellTips", "spell" }, { "auraTips", "buff and debuff", " (not on the target and focus frames)" }, { "itemTips", "item" } }) do
		local phrase = HIDDEN[Opt(kind[1])]
		if phrase then
			kinds[#kinds + 1] = kind[2] .. " tooltips " .. phrase .. (kind[3] or "")
		end
	end
	if #kinds > 0 then
		local text = "Tooltips by kind: " .. table.concat(kinds, ", ")
		if key ~= "none" then
			text = text .. ", shown while you hold " .. Word(KEY .. ".combatKey")
		end
		lines[#lines + 1] = text
	end
	local group = Opt("groupTips")
	if group == "key" then
		lines[#lines + 1] = "Party and raid frame tooltips: only while you hold " .. Word(KEY .. ".groupTipKey")
	elseif group ~= "other" then
		lines[#lines + 1] = "Party and raid frame tooltips: " .. Word(KEY .. ".groupTips")
	end
	return lines
end

ns.Register(KEY, { label = "Chat and tooltips", Start = Refresh, Refresh = Refresh, Status = Status })
