local _, ns = ...

local KEY = "chat"

local HOVER_ALPHA = 0.25
local PLATE_HEIGHT = 22
local COMPARE_PLATE = "tooltip-compare-label"
local BAR_FILE = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"

local BORDER = { "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
local TAB_FADED = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight" }
local TAB_HIGHLIGHT = { "HighlightLeft", "HighlightMiddle", "HighlightRight" }
local BOX_ART = { "Left", "Mid", "Right" }
local BOX_FOCUS = { "focusLeft", "focusMid", "focusRight" }
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local BAR_HEIGHT, IDLE_ALPHA = 8, 35
local TIP_TITLE, TIP_TEXT = { "GameTooltipHeaderText" }, { "GameTooltipText", "GameTooltipTextSmall" }
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }
local TIP_COLOURS = {
	nearblack = { 15 / 255, 15 / 255, 15 / 255 },
	black = { 0, 0, 0 },
	darkblue = { 10 / 255, 20 / 255, 46 / 255 },
	darkbrown = { 32 / 255, 22 / 255, 14 / 255 },
}
ns.TipColours = TIP_COLOURS
local LIFT, HINT, SINK, DARK = 0.12, 0.08, 0.3, 20 / 255
local SHADE_NOTE = "Chat and tooltips: the game cannot draw a gradient, so the tooltip background stays one colour."
local shadeRefused = setmetatable({}, { __mode = "k" })

local windows = setmetatable({}, { __mode = "k" })
local tabs = setmetatable({}, { __mode = "k" })
local boxes = setmetatable({}, { __mode = "k" })
local tips = setmetatable({}, { __mode = "k" })
local queued = setmetatable({}, { __mode = "k" })
local X = { seats = setmetatable({}, { __mode = "k" }), scales = setmetatable({}, { __mode = "k" }), fonts = setmetatable({}, { __mode = "k" }),
	extras = setmetatable({}, { __mode = "k" }), built = setmetatable({}, { __mode = "k" }), bar = {}, levels = setmetatable({}, { __mode = "k" }),
	arrows = setmetatable({}, { __mode = "k" }) }
local hooked = {}
local postCall = false
local barOutline
local BT = { PART = "tooltip health text", EVERY = 0.1, FORMATS = { curmax = "%s / %s", pct = "%.0f%%", curpct = "%s (%.0f%%)" },
	SIZE = { 70, 130 }, LEAST = 5 }

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

local function Plate(prefix, hidden)
	ns.SetHidden(Global(prefix .. "Background"), hidden)
	for _, part in ipairs(BORDER) do
		ns.SetHidden(Global(prefix .. part), hidden)
	end
end

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

local function BrightTab(tab, record, on)
	local other = on and TAB_OTHER[Opt("tabOpacity")]
	local alpha = other and ((record.selected or Alerting(tab)) and 1 or other) or nil
	if on and record.named then
		alpha = 1
	end
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

local NAMED = { HIGH = 0.45, LOW = 0.12, PULSE = 1.2, COUNT_X = -5, COUNT_Y = 0, MOST = 9 }

local function NamedWanted()
	return On("tabs") and Opt("mentions") == true and Opt("mentionTab") == true
end

local function NamedColour()
	local hex = Opt("mentionColour")
	if type(hex) == "string" and hex:find("^%x%x%x%x%x%x%x%x$") then
		return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
	end
	return 1, 0.6, 0.2
end

local function LabelColour(tab)
	local colours = tab.selectedColorTable
	if Usable(colours) and IsNumber(colours.r) and IsNumber(colours.g) and IsNumber(colours.b) then
		return colours.r, colours.g, colours.b
	end
	local normal = NORMAL_FONT_COLOR
	if Usable(normal) and IsNumber(normal.r) and IsNumber(normal.g) and IsNumber(normal.b) then
		return normal.r, normal.g, normal.b
	end
	return 1, 0.82, 0
end

local function PaintNamed(tab, record, r, g, b)
	local glow = record.glow
	if record.named and not glow and record.plate then
		local texture = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
		ns.Own[texture] = true
		texture:SetAllPoints(record.plate)
		pcall(texture.SetIgnoreParentAlpha, texture, true)
		local group = texture:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(NAMED.LOW / NAMED.HIGH)
		fade:SetDuration(NAMED.PULSE)
		pcall(fade.SetSmoothing, fade, "IN_OUT")
		group:SetLooping("BOUNCE")
		glow = { texture = texture, group = group }
		record.glow = glow
	end
	local count = record.count
	if record.named and not count and record.plate then
		count = ns.OwnText(record.plate, "OVERLAY", "GameFontHighlightSmall")
		if count then
			count:SetPoint("CENTER", record.plate, "TOPRIGHT", NAMED.COUNT_X, NAMED.COUNT_Y)
			pcall(count.SetIgnoreParentAlpha, count, true)
			record.count = count
		end
	end
	local ok, label = pcall(tab.GetFontString, tab)
	label = ok and Usable(label) and label or nil
	if record.named and glow then
		glow.texture:SetColorTexture(r, g, b, NAMED.HIGH)
		glow.texture:Show()
		if not glow.group:IsPlaying() then
			glow.group:Play()
		end
		if label then
			pcall(label.SetTextColor, label, r, g, b)
			record.labelSet = true
		end
		if count then
			local lines = IsNumber(record.namedCount) and record.namedCount or 1
			count:SetText(lines > NAMED.MOST and (NAMED.MOST .. "+") or tostring(lines))
			count:SetTextColor(r, g, b)
			count:Show()
		end
		return
	end
	record.namedCount = nil
	if count then
		count:Hide()
	end
	if glow then
		glow.group:Stop()
		glow.texture:Hide()
	end
	if record.labelSet then
		record.labelSet = nil
		if label then
			pcall(label.SetTextColor, label, LabelColour(tab))
		end
	end
end

local function PaintTab(tab, record)
	local on = On("tabs")
	if record.named and (record.selected or not NamedWanted()) then
		record.named = nil
	end
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
	elseif on and record.named then
		r, g, b = NamedColour()
	end
	ns.SetOutlineColour(record.outline, r, g, b)
	local hr, hg, hb = ns.Colour("windows.accent")
	record.hover:SetColorTexture(hr, hg, hb, 0.25)
	record.hover:SetShown(on)
	PaintNamed(tab, record, r, g, b)
end

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
		record = { outline = ns.Outline(tab, plate, true), hover = hover, plate = plate }
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

local function Typing(box)
	local ok, focus = pcall(box.HasFocus, box)
	return ok and not ns.IsSecret(focus) and focus == true
end

local typing = setmetatable({}, { __mode = "k" })
local Watch
local LEFT = { SHOW = 50, AMBER = 20, LIMIT = 255, FONT = "GameFontDisableSmall", X = -8, GAP = 4,
	AMBER_COLOUR = { 1, 0.7, 0.2 }, RED_COLOUR = { 1, 0.3, 0.3 } }

function LEFT.Insets(box)
	local ok, l, r, t, b = pcall(box.GetTextInsets, box)
	if ok and ns.Finite(l) and ns.Finite(r) and ns.Finite(t) and ns.Finite(b) then
		return l, r, t, b
	end
end

function LEFT.Room(box, record, width)
	local l, r, t, b = LEFT.Insets(box)
	if not l then
		return
	end
	local inset = record.leftInset
	if inset and r ~= inset.set then
		inset = nil
	end
	local base = inset and inset.base or r
	local wanted = math.ceil(-LEFT.X + width + LEFT.GAP)
	if wanted <= base then
		if inset then
			pcall(box.SetTextInsets, box, l, base, t, b)
		end
		record.leftInset = nil
		return
	end
	if r ~= wanted and pcall(box.SetTextInsets, box, l, wanted, t, b) then
		record.leftInset = { base = base, set = wanted }
	elseif r == wanted then
		record.leftInset = { base = base, set = wanted }
	end
end

function LEFT.Hide(box)
	local record = boxes[box]
	local text = record and record.left
	if text then
		pcall(text.Hide, text)
	end
	local inset = record and record.leftInset
	if inset then
		record.leftInset = nil
		local l, r, t, b = LEFT.Insets(box)
		if l and r == inset.set then
			pcall(box.SetTextInsets, box, l, inset.base, t, b)
		end
	end
end

function LEFT.Count(box, record)
	local text = record.left
	local okText, typed = false, nil
	if On("editbox") and Opt("inputLeft") == true and Typing(box) then
		okText, typed = pcall(box.GetText, box)
	end
	if not okText or ns.IsSecret(typed) or type(typed) ~= "string" then
		LEFT.Hide(box)
		return
	end
	local okLimit, limit = pcall(box.GetVisibleTextByteLimit, box)
	if not okLimit or not ns.Finite(limit) or limit <= 0 then
		limit = LEFT.LIMIT
	end
	local visible = typed:gsub("|cn[^:|]*:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
		:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	local left = limit - #visible
	if left > LEFT.SHOW then
		LEFT.Hide(box)
		return
	end
	if not text then
		text = ns.OwnText(box, "OVERLAY", LEFT.FONT)
		if not text then
			return
		end
		pcall(text.SetPoint, text, "RIGHT", box, "RIGHT", LEFT.X, 0)
		pcall(text.SetJustifyH, text, "RIGHT")
		local ok, r, g, b = pcall(text.GetTextColor, text)
		record.leftDim = ok and IsNumber(r) and IsNumber(g) and IsNumber(b) and { r, g, b } or { 0.5, 0.5, 0.5 }
		record.left = text
	end
	local colour = left <= 0 and LEFT.RED_COLOUR or left <= LEFT.AMBER and LEFT.AMBER_COLOUR or record.leftDim
	pcall(text.SetTextColor, text, colour[1], colour[2], colour[3])
	pcall(text.SetText, text, tostring(math.max(0, left)))
	pcall(text.Show, text)
	local okWidth, width = pcall(text.GetStringWidth, text)
	if okWidth and ns.Finite(width) then
		LEFT.Room(box, record, width)
	end
end

local function ReadFocus(box)
	local record, art = boxes[box], box.focusLeft
	if record then
		LEFT.Count(box, record)
	end
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

local function Part(part, fn, object, ...)
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, part) then
		ns.EachPart(KEY, part, fn, object, false, ...)
	else
		pcall(fn, object, true, ...)
	end
end

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

local function Arrows(box, restore)
	if ns.Forbidden(box) or type(box.SetAltArrowKeyMode) ~= "function" then
		return
	end
	if not restore and Opt("arrows") == true then
		if pcall(box.SetAltArrowKeyMode, box, false) then
			X.arrows[box] = true
		end
	elseif X.arrows[box] then
		if pcall(box.SetAltArrowKeyMode, box, true) then
			X.arrows[box] = nil
		end
	end
end

local settling = setmetatable({}, { __mode = "k" })
local watcher, watchWait

local function Closed(box)
	return not IsShown(box) or not IsShown(box.focusLeft)
end

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
						LEFT.Hide(held)
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
			if gained ~= true then
				LEFT.Hide(box)
			end
			Settle(box)
		end
	end
end

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
				Part("input arrows", Arrows, box)
			end
		end
	end
	if type(ns.ChatTextPass) == "function" then
		ns.ChatTextPass()
	end
end

local function Pieces(tooltip, faded)
	local slice = tooltip.NineSlice
	if Usable(slice) then
		for _, piece in ipairs(PIECES) do
			ns.SetFaded(slice[piece], faded)
		end
	end
end

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

local function Backdrop(tooltip, style)
	local record = Usable(tooltip) and tips[tooltip]
	if record then
		Pieces(tooltip, On("tooltips"))
		if not ns.IsSecret(style) and style == nil then
			ns.SetOutlineColour(record.outline, nil, nil, nil)
		end
	end
end

local function IsData(data, name)
	if not Usable(data) or type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" then
		return false
	end
	local kind = data.type
	return not ns.IsSecret(kind) and kind ~= nil and kind == Enum.TooltipDataType[name]
end

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

local function UnitKind(data)
	local guid = data.guid
	if ns.IsSecret(guid) or type(guid) ~= "string" or type(UnitTokenFromGUID) ~= "function" then
		return nil
	end
	local kind = ns.UnitKind(UnitTokenFromGUID(guid))
	return kind and ns.KINDS[kind] or nil
end

local function TooltipKind(tooltip, data)
	if not IsData(data, "Unit") or ns.Forbidden(tooltip) then
		return nil
	end
	local ok, kind = pcall(UnitKind, data)
	return ok and kind or nil
end

local function AddKind(tooltip, record, data, kind)
	local ok, lines = pcall(tooltip.NumLines, tooltip)
	if not ok or not IsNumber(lines) or (record.kindData == data and lines >= record.kindLines) then
		return
	end
	if pcall(tooltip.AddLine, tooltip, kind.word, kind.colour[1], kind.colour[2], kind.colour[3]) then
		record.kindData, record.kindLines = data, lines + 1
	end
end

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

function X.BagsNamesMe(tooltip, id)
	local bags = ns.Bags
	if not (rawequal(tooltip, GameTooltip) or rawequal(tooltip, ItemRefTooltip)) or not Usable(bags) or type(bags.On) ~= "function"
		or ns.Get("bags.altCounts") ~= true or ns.PartStopped("bags", "tooltips") then
		return false
	end
	local okOn, on = pcall(bags.On)
	local data = bags.Data
	if not okOn or on ~= true or not Usable(data) or type(data.Mine) ~= "function" then
		return false
	end
	local ok, _, bank = pcall(data.Mine, id)
	return ok and IsNumber(bank) and bank > 0
end

local function Extras(tooltip, data)
	if not ns.Enabled(KEY) or not (Opt("ids") or Opt("count")) or not Usable(tooltip) or ns.Forbidden(tooltip) then
		return
	end
	local item, spell = IsData(data, "Item"), IsData(data, "Spell") or IsData(data, "UnitAura")
	local id = (item or spell) and data.id
	local lines = {}
	if IsNumber(id) then
		ns.ChatTipIds(lines, data, item, id)
		if item and Opt("count") and type(C_Item) == "table" and type(C_Item.GetItemCount) == "function" then
			local okBags, bags = pcall(C_Item.GetItemCount, id)
			local okAll, all = pcall(C_Item.GetItemCount, id, true)
			if okBags and okAll and IsNumber(bags) and IsNumber(all) and not (all > bags and X.BagsNamesMe(tooltip, id)) then
				lines[#lines + 1] = all > bags and ("Count: %d in bags, %d with bank"):format(bags, all) or ("Count: %d in bags"):format(bags)
			end
		end
	elseif not (item or spell) and IsData(data, "Unit") and type(ns.ChatTipNpcId) == "function" then
		ns.ChatTipNpcId(lines, data)
	elseif not (item or spell) and type(ns.ChatTipOtherId) == "function" then
		local kind = (IsData(data, "Quest") and "Quest") or (IsData(data, "Currency") and "Currency") or nil
		if kind then
			ns.ChatTipOtherId(lines, data, kind)
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

local function HasLevelLine(data)
	local kinds, list = type(Enum) == "table" and Enum.TooltipDataLineType, data.lines
	local kind = Usable(kinds) and kinds.ItemLevel or nil
	if not IsNumber(kind) or not Usable(list) then
		return false
	end
	for _, line in ipairs(list) do
		if Usable(line) and IsNumber(line.type) and line.type == kind then
			return true
		end
	end
	return false
end

local function ItemLevelLine(tooltip, data)
	if not ns.Enabled(KEY) or Opt("itemLevel") ~= true or not IsData(data, "Item") or not Usable(tooltip) or ns.Forbidden(tooltip) then
		return
	end
	local items, link = ns.Items, data.hyperlink
	if ns.IsSecret(link) or type(link) ~= "string" or link == "" then
		link = data.id
	end
	if not Usable(items) or type(items.LevelOf) ~= "function" or not (IsNumber(link) or type(link) == "string") or HasLevelLine(data) then
		return
	end
	local okLevel, level = pcall(items.LevelOf, link)
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	local record = X.levels[tooltip]
	if not okLevel or not ns.Finite(level) or level <= 0 or not ok or not IsNumber(shown)
		or (record and record.data == data and shown >= record.lines) then
		return
	end
	if pcall(tooltip.AddLine, tooltip, ("Item level %d"):format(math.floor(level + 0.5)), 1, 0.82, 0) then
		X.levels[tooltip] = { data = data, lines = shown + 1 }
	end
end

local function Marks(line, token)
	local marker, away = Opt("raidMarker") == true, Opt("awayTag") == true
	if not (marker or away) or not Usable(line) then
		return
	end
	local ok, text = pcall(line.GetText, line)
	if not ok or ns.IsSecret(text) or type(text) ~= "string" or text == "" then
		return
	end
	local function Yes(fn)
		if type(fn) ~= "function" then
			return false
		end
		local done, value = pcall(fn, token)
		return done and not ns.IsSecret(value) and value == true
	end
	local changed = text
	if marker and type(GetRaidTargetIndex) == "function" and not text:find("UI-RaidTargetingIcon", 1, true) then
		local done, index = pcall(GetRaidTargetIndex, token)
		if done and ns.Finite(index) and index >= 1 and index <= 8 and index == math.floor(index) then
			changed = ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t %s"):format(index, changed)
		end
	end
	if away and Yes(UnitIsPlayer) then
		local tag
		if Yes(UnitIsAFK) then
			tag = type(CHAT_FLAG_AFK) == "string" and CHAT_FLAG_AFK or "<AFK>"
		elseif Yes(UnitIsDND) then
			tag = type(CHAT_FLAG_DND) == "string" and CHAT_FLAG_DND or "<DND>"
		end
		if tag and not ns.IsSecret(tag) and tag ~= "" and not changed:find(tag, 1, true) then
			changed = changed .. " |cff9a9a9a" .. tag .. "|r"
		end
	end
	if changed ~= text then
		pcall(line.SetText, line, changed)
	end
end

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
	if ns.IsSecret(token) or type(token) ~= "string" or ns.Forbidden(tooltip) then
		return
	end
	Marks(tooltip.TextLeft1, token)
	if mode == "plain" and not names then
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

local function KeyDown(key)
	local down = key == "shift" and IsShiftKeyDown or key == "ctrl" and IsControlKeyDown or key == "alt" and IsAltKeyDown
	if type(down) ~= "function" then
		return false
	end
	local ok, pressed = pcall(down)
	return ok and not ns.IsSecret(pressed) and pressed == true
end

local function OwnerOf(tooltip)
	local ok, owner = pcall(tooltip.GetOwner, tooltip)
	if ok and Usable(owner) then
		return owner
	end
	return nil
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and not ns.IsSecret(fighting) and fighting == true
end

local function InDungeon()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and not ns.IsSecret(inside) and inside == true and not ns.IsSecret(kind) and (kind == "party" or kind == "raid")
end

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

local function GroupOwned(owner)
	local extra = ns.UnitFrameExtra
	local test = type(extra) == "table" and extra.isGroupFrame or nil
	if owner == nil or type(test) ~= "function" then
		return false
	end
	local ok, yes = pcall(test, owner)
	return ok and yes == true
end

local function Rules()
	return Opt("combat") ~= "show" or Opt("groupTips") ~= "other" or Opt("spellTips") ~= "show" or Opt("auraTips") ~= "show" or Opt("itemTips") ~= "show"
end

local function Withheld(tooltip)
	if not Rules() or not ns.Enabled(KEY) or ns.Forbidden(tooltip) then
		return false
	end
	local owner = OwnerOf(tooltip)
	local built = X.built[tooltip]
	if built ~= nil and built.owner ~= true and owner ~= nil and not rawequal(built.owner, owner) then
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

local FADE_FAST = 0.2
local FADE_STEP = 0.02
local fadeDriver
local fadeTop, fadeFor, fadeOwner

local function FadeEnd(tooltip, hide)
	if hide then
		pcall(tooltip.Hide, tooltip)
	end
	if fadeFor ~= nil and fadeTop ~= nil then
		pcall(tooltip.SetAlpha, tooltip, fadeTop)
	end
	fadeTop, fadeFor, fadeOwner = nil, nil, nil
end

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
		FadeEnd(tooltip, false)
		return
	elseif Reowned(tooltip) then
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

local function FadeCancel(tooltip)
	if fadeFor ~= nil and Usable(tooltip) and not ns.Forbidden(tooltip) then
		FadeEnd(tooltip, false)
	end
	fadeTop, fadeFor = nil, nil
end

local function FadeShown(tooltip)
	FadeCancel(tooltip)
	if fadeDriver and Opt("fadeOut") ~= "game" then
		local ok, alpha = pcall(tooltip.GetAlpha, tooltip)
		if ok and not ns.IsSecret(alpha) and type(alpha) == "number" and alpha == alpha then
			fadeTop = alpha
		end
	end
end

local function FadeWatch()
	local tooltip = Global("GameTooltip")
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

X.hints = setmetatable({}, { __mode = "k" })
local HINT, HINT_SPELLS, HINT_COLOUR = "Shift: compare with what you wear", " and your spells", { 0.66, 0.68, 0.62 }
X.NO_HINT = { INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true }

local function CompareHint(tooltip, data)
	if not ns.Enabled(KEY) or Opt("compareHint") ~= true or Opt("compareShift") ~= true or not IsData(data, "Item") or not Usable(tooltip)
		or ns.Forbidden(tooltip) then
		return
	end
	local game = rawequal(tooltip, Global("GameTooltip"))
	if not (game or rawequal(tooltip, Global("ItemRefTooltip"))) or type(ns.ItemCompareHeld) ~= "function" or ns.ItemCompareHeld() ~= true
		or KeyDown("shift") then
		return
	end
	local items, id = C_Item, data.id
	if not Usable(items) or not IsNumber(id) or type(items.IsEquippableItem) ~= "function" then
		return
	end
	local okEquip, equippable = pcall(items.IsEquippableItem, id)
	if not okEquip or ns.IsSecret(equippable) or equippable ~= true then
		return
	end
	local loc
	if type(items.GetItemInfoInstant) == "function" then
		local okLoc, _, _, _, equipLoc = pcall(items.GetItemInfoInstant, id)
		loc = okLoc and not ns.IsSecret(equipLoc) and type(equipLoc) == "string" and equipLoc or nil
	end
	if loc and X.NO_HINT[loc] then
		return
	end
	local guid = data.guid
	if not ns.IsSecret(guid) and type(guid) == "string" and guid ~= "" and type(items.GetItemLocation) == "function" then
		local okWhere, where = pcall(items.GetItemLocation, guid)
		local slot = okWhere and Usable(where) and where.equipmentSlotIndex or nil
		if IsNumber(slot) then
			return
		end
	end
	local ok, shown = pcall(tooltip.NumLines, tooltip)
	local record = X.hints[tooltip]
	if not ok or not IsNumber(shown) or (record and record.data == data and shown >= record.lines) then
		return
	end
	local text = HINT
	if game and Opt("gear") == true and Opt("gearWhen") == "compare" and (type(ns.GearLinesFor) ~= "function" or ns.GearLinesFor(loc) == true) then
		text = text .. HINT_SPELLS
	end
	if pcall(tooltip.AddLine, tooltip, text, HINT_COLOUR[1], HINT_COLOUR[2], HINT_COLOUR[3]) then
		X.hints[tooltip] = { data = data, lines = shown + 1 }
	end
end

local function FollowData()
	if postCall or type(TooltipDataProcessor) ~= "table" or type(TooltipDataProcessor.AddTooltipPostCall) ~= "function" or TooltipDataProcessor.AllTypes == nil then
		return
	end
	postCall = true
	TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
		if not ns.IsStopped(KEY) then
			ns.Each(KEY, ns.ChatTipLines, tooltip, data)
			ns.Each(KEY, ItemLevelLine, tooltip, data)
			ns.Each(KEY, CompareHint, tooltip, data)
			if type(ns.SpellTipLines) == "function" then
				ns.Each(KEY, ns.SpellTipLines, tooltip, data)
			end
			if type(ns.GearTipLines) == "function" then
				ns.Each(KEY, ns.GearTipLines, tooltip, data)
			end
			if type(ns.HitTableTipLines) == "function" then
				ns.Each(KEY, ns.HitTableTipLines, tooltip, data)
			end
			ns.Each(KEY, Filled, tooltip, data)
			ns.Each(KEY, BT.Unit, tooltip, data)
			ns.Each(KEY, BT.Pick, tooltip, data)
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

local function PaintBar(bar)
	local on = On("health")
	local shown = on and not (X.bar.hidden == true)
	ns.SetOutline(barOutline, shown, shown)
	if on then
		local id = ns.Get(KEY .. ".barTexture")
		local file = nil
		if id ~= "default" then
			file = ns.BarTexture(id) or false
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

function BT.Mode()
	local mode, height = Opt("barText"), Opt("barHeight")
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, BT.PART) or Opt("barHide") == true or BT.FORMATS[mode] == nil
		or (IsNumber(height) and height < BT.LEAST) then
		return nil
	end
	return mode
end

function BT.Size(text)
	local height = Opt("barHeight")
	if not IsNumber(height) then
		height = BAR_HEIGHT
	end
	ns.TextStyle(text, { percent = math.max(BT.SIZE[1], math.min(BT.SIZE[2], (height + 1) * 10)), flags = "OUTLINE" })
end

function BT.Token(data)
	local token
	for _, field in ipairs({ "healthGUID", "guid" }) do
		local guid = data[field]
		if not token and not ns.IsSecret(guid) and type(guid) == "string" and guid ~= "" and type(UnitTokenFromGUID) == "function" then
			local ok, found = pcall(UnitTokenFromGUID, guid)
			if ok and not ns.IsSecret(found) and type(found) == "string" and found ~= "" then
				token = found
			end
		end
	end
	if not token and type(UnitExists) == "function" then
		local ok, exists = pcall(UnitExists, "mouseover")
		if ok and not ns.IsSecret(exists) and exists == true then
			token = "mouseover"
		end
	end
	return token
end

function BT.Unit(tooltip, data)
	if not rawequal(tooltip, Global("GameTooltip")) then
		return
	end
	X.barUnit = nil
	if BT.Mode() == nil or not IsData(data, "Unit") then
		return
	end
	X.barUnit = BT.Token(data)
	if X.barText then
		X.barText.wait = BT.EVERY
	end
end

function BT.Fill(_)
	local own, mode, unit = X.barText, BT.Mode(), X.barUnit
	if not (own and mode) then
		return
	end
	if not unit then
		own.text:SetText("")
		return
	end
	local ok, exists = false, nil
	if type(UnitExists) == "function" then
		ok, exists = pcall(UnitExists, unit)
	end
	if not (ok and not ns.IsSecret(exists) and exists == true) then
		return
	end
	local okDead, dead = false, nil
	if type(UnitIsDeadOrGhost) == "function" then
		okDead, dead = pcall(UnitIsDeadOrGhost, unit)
	end
	if okDead and not ns.IsSecret(dead) and dead == true then
		local word = DEAD
		own.text:SetText(not ns.IsSecret(word) and type(word) == "string" and word ~= "" and word or "Dead")
		return
	end
	if mode == "curmax" then
		own.text:SetFormattedText(BT.FORMATS.curmax, AbbreviateNumbers(UnitHealth(unit)), AbbreviateNumbers(UnitHealthMax(unit)))
	elseif mode == "curpct" then
		own.text:SetFormattedText(BT.FORMATS.curpct, AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
	else
		own.text:SetFormattedText(BT.FORMATS.pct, UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
	end
end

function BT.Build(bar)
	if X.barText or ns.Forbidden(bar) or BT.Mode() == nil then
		return
	end
	local frame = CreateFrame("Frame", nil, bar)
	ns.Own[frame] = true
	frame:SetAllPoints(bar)
	local okLevel, level = pcall(bar.GetFrameLevel, bar)
	if okLevel and IsNumber(level) then
		frame:SetFrameLevel(level + 2)
	end
	local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	if text == nil then
		frame:Hide()
		return
	end
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	BT.Size(text)
	local own = { frame = frame, text = text, wait = 0 }
	X.barText = own
	frame:SetScript("OnUpdate", function(_, elapsed)
		own.wait = own.wait + (IsNumber(elapsed) and elapsed or 0)
		if own.wait < BT.EVERY or ns.IsStopped(KEY) then
			return
		end
		own.wait = 0
		if not ns.EachPart(KEY, BT.PART, BT.Fill, {}) and ns.PartStopped(KEY, BT.PART) then
			pcall(text.SetText, text, "")
			pcall(frame.Hide, frame)
		end
	end)
	frame:SetScript("OnHide", function()
		X.barUnit = nil
		pcall(text.SetText, text, "")
	end)
	BT.Show(bar)
end

function BT.Show(bar)
	local own, mode = X.barText, BT.Mode()
	if own then
		if mode == nil then
			pcall(own.text.SetText, own.text, "")
		else
			BT.Size(own.text)
		end
		pcall(own.frame.SetShown, own.frame, mode ~= nil)
	elseif mode ~= nil and not X.barTextQueued then
		X.barTextQueued = true
		ns.OutOfCombat(function()
			X.barTextQueued = nil
			ns.Each(KEY, BT.Build, bar)
		end)
	end
end

function BT.Tinted()
	return ns.Enabled(KEY) and Opt("barColour") == "class" and Opt("barHide") ~= true
end

function BT.Bar()
	local tooltip = Global("GameTooltip")
	local bar = tooltip and not ns.Forbidden(tooltip) and tooltip.StatusBar
	if Usable(bar) and not ns.Forbidden(bar) then
		return bar
	end
	return nil
end

function BT.Tint()
	local bar, colour = BT.Bar(), X.barColour
	if not bar then
		return
	end
	if colour then
		pcall(bar.SetStatusBarColor, bar, colour[1], colour[2], colour[3])
	elseif X.barTinted then
		pcall(bar.SetStatusBarColor, bar, 0, 1, 0)
	end
	X.barTinted = colour ~= nil
end

function BT.Pick(tooltip, data)
	if not rawequal(tooltip, Global("GameTooltip")) then
		return
	end
	X.barColour = nil
	local token = BT.Tinted() and IsData(data, "Unit") and BT.Token(data)
	if token then
		local r, g, b
		local ok, player = false, nil
		if type(UnitIsPlayer) == "function" then
			ok, player = pcall(UnitIsPlayer, token)
		end
		if ok and not ns.IsSecret(player) and player == true then
			r, g, b = ns.ClassColourOf(token)
		end
		if not r then
			r, g, b = ns.ReactionColour(token)
		end
		if IsNumber(r) and IsNumber(g) and IsNumber(b) then
			X.barColour = { r, g, b }
		end
	end
	BT.Tint()
end

function BT.Hook(bar)
	if X.barHooked or not BT.Tinted() or type(bar.HookScript) ~= "function" then
		return
	end
	X.barHooked = pcall(bar.HookScript, bar, "OnValueChanged", function(self)
		local colour = X.barColour
		if colour and not ns.IsStopped(KEY) then
			pcall(self.SetStatusBarColor, self, colour[1], colour[2], colour[3])
		end
	end)
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
	BT.Show(bar)
	BT.Hook(bar)
	if not BT.Tinted() then
		X.barColour = nil
	end
	BT.Tint()
end

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

local function Follow(name, fn)
	if hooked[name] or type(_G[name]) ~= "function" then
		return
	end
	if ns.FollowGlobal(name, function(...)
		if not ns.IsStopped(KEY) then
			ns.Each(KEY, fn, ...)
		end
	end) then
		hooked[name] = true
	end
end

local function TabColours(tab, selected)
	local state
	if not ns.IsSecret(selected) then
		state = selected and true or false
	end
	StyleTab(tab, state)
end

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

local namedQueue = {}
function ns.ChatTabNamed(frame)
	if not NamedWanted() or not Usable(frame) or ns.Forbidden(frame) then
		return
	end
	local okShown, shown = pcall(frame.IsVisible, frame)
	if not okShown or ns.IsSecret(shown) or shown ~= false then
		return
	end
	local ok, name = pcall(frame.GetName, frame)
	local tab = ok and not ns.IsSecret(name) and type(name) == "string" and Global(name .. "Tab") or nil
	local record = tab and tabs[tab]
	if not record or record.selected then
		return
	end
	if record.named then
		record.namedCount = (IsNumber(record.namedCount) and record.namedCount or 1) + 1
	else
		record.named, record.namedCount = true, 1
	end
	if next(namedQueue) ~= nil then
		namedQueue[tab] = true
		return
	end
	namedQueue[tab] = true
	local function run()
		local list = namedQueue
		namedQueue = {}
		for queued in pairs(list) do
			if not ns.IsStopped(KEY) then
				ns.Each(KEY, StyleTab, queued)
			end
		end
	end
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, run)) then
		run()
	end
end

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
	if type(ns.SpellLinesSync) == "function" then
		ns.Each(KEY, ns.SpellLinesSync)
	end
	if type(ns.GearLinesSync) == "function" then
		ns.Each(KEY, ns.GearLinesSync)
	end
	if type(ns.GearWindowSync) == "function" then
		ns.Each(KEY, ns.GearWindowSync)
	end
	if type(ns.GearButtonChanged) == "function" then
		ns.Each(KEY, ns.GearButtonChanged)
	end
end

local function Word(path)
	local def, value = ns.Def(path), ns.Get(path)
	for _, choice in ipairs(def and ns.Choices(def) or {}) do
		if choice[1] == value then
			return choice[2]
		end
	end
	return tostring(value)
end

local HIDDEN = { combat = "hidden in combat", instance = "hidden in dungeons and raids", always = "always hidden" }

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
