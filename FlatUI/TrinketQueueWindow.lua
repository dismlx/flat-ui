local _, ns = ...

local KEY, PART, NAME = "trinkets", "window", "FlatUITrinkets"
local SIZE, BOX = { W = 320, H = 404 }, { x = 680, y = -120 }
local L = { PAD = 8, BAR = 26, CLOSE = 18, SWITCH = 20, SLOT = 38, ICON = 32, HEAD = 14, ROW = 22, ROWS = 8, SMALL = 18, CELL = 22, CELL_GAP = 4,
	PER_LINE = 11, LINES = 2, FOOT = 18, DOT = 6, BOX = 12, STOP = 14, ARROW = 12 }
local Y = { SWITCH = 28, SLOT = 52, HEAD = 94, ROWS = 108, ADD_TITLE = 290, ADD = 306, RULE = 364, FOOT = 370 }
local X = { STRIPE = 8, ICON = 12, NAME = 34, NAME_END = 150, CD = 152, CD_END = 210, DELAY = 214, DELAY_END = 244, STOP = 248, UP = 266,
	DOWN = 280, CROSS = 296, THUMB = 312 }
local TICK, SAY_FOR, FADE_IN = 0.5, 8, 0.1
local SEPARATOR = 0.07
local FONT, TITLE_FONT = "GameFontHighlightSmall", "GameFontHighlight"
local DIM, PLAIN = { 0.66, 0.68, 0.62 }, { 1, 1, 1 }
local TONES = { off = { 0.45, 0.45, 0.45 }, wait = { 1, 0.67, 0.2 }, halt = { 0.9, 0.3, 0.3 } }
local T = {
	TITLE = "Trinket queue", PAUSE = "Pause all", PAUSED = "Paused", NOW = "Queue now", AUTO = "Auto queue",
	WORDS = { top = "Top trinket", bottom = "Bottom trinket" },
	HEADS = { "Priority", "Cooldown", "Delay", "Stop" },
	ADD = "In your bags: click to add, Shift-click to put it first",
	EMPTY = "No trinkets yet: click one under In your bags, or drop one here.",
	COPY = "Copy the %s list (%d)",
	NONE_CARRIED = "No other trinket in your bags.",
	FOOT_PAUSED = "Paused: nothing is swapped.",
	FOOT_FIGHT = "Swaps wait for the end of the fight. You can still change the lists.",
	FOOT = "Drop a trinket here to add it.",
	ONLY = "Only trinkets go in the queue.",
	EMPTY_SLOT = "Empty slot",
	NEXT = "Next: %s in %s",
	READY = "Ready", NO_USE = "No use", IN_USE = "In use", UNKNOWN = "?", NOT_CARRIED = "Not carried", BINDS = "Binds", LEVEL = "Level %d",
	SECONDS = "%d s", NO_DELAY = "-", MORE = "+%d",
	AFTER_FIGHT = "Flat UI: the trinket queue window opens after the fight.",
	OFF = "Flat UI: the trinket queue is off. Turn it on with Trinket queue (Character and gear).",
	STOPPED = "Flat UI: the trinket queue window stopped after an error. /flatui status says why.",
	REPORT = "Flat UI, Trinket queue window, %s: %s",
	LINES = { { 1, "Top trinket" }, { 2, "Bottom trinket" } },
	TIPS = {
		pause = { "Pause all", "Stops every swap of both slots until you press it again. Kept for this character; /flatui queue pause does the same." },
		auto = { "Auto queue", "Swaps this slot by its list, out of a fight: the best trinket you carry that is ready. Kept for this character, whatever profile is in use. Also on the Trinket queue page, and a right-click on the slot's square on the Character window." },
		now = { "Queue now", "Lets the queue act on this slot at once: it forgets a trinket you put on or took off yourself and a trinket the game refused, and leaves Stop and Delay aside this once." },
		delay = { "Delay", "Keeps this trinket on this long after you use it, so its buff runs out before it is swapped.", "Click: 5 s more. Right-click: 5 s less. Shift-click: none." },
		stop = { "Stop", "While you wear this trinket the queue does not take it off. Click to turn it on or off." },
		up = { "Move up", "Shift-click: to the top of the list." },
		down = { "Move down", "Shift-click: to the bottom of the list." },
		cross = { "Remove", "Takes this trinket out of the list." },
		copy = { "Copy the other list", "Puts the %s list here in the same order, with each Delay and Stop. /flatui queue copy %s does the same." },
		more = { "%d more", "Click for the next ones." },
		top = { "Top trinket", "The list of the top trinket slot." },
		bottom = { "Bottom trinket", "The list of the bottom trinket slot." },
	},
	ROW_ICON = "Click: put it on now. The slot keeps it until you use it or press Queue now. Shift-click with the chat box open: link it.",
	ADD_TIP = "Click: add it at the end of this list. Shift-click: put it first, or with the chat box open, link it.",
	LINK_TIP = "Shift-click with the chat box open: link it.",
	NOT_LOADED = "The game has not loaded that trinket yet: click again in a moment.",
	SOON_TIP = "Counts as ready: %d s or less left (Ready with this much left).",
	BINDS_TIP = "Binds when worn: put it on once yourself (click its icon).",
	DELAY_TIP = "Delay: keep it on %d s after you use it.",
	STOP_TIP = "Stop: the queue does not take it off while you wear it.",
	GONE_TIP = "Not in your bags.",
	LEVEL_TIP = "Needs level %d.",
	COPIED_FOOT = "Took %d from the %s list, with each Delay and Stop.",
	COPY_NONE_FOOT = "Nothing to copy: each of those trinkets is here already, or the list is full.",
	NOW_FOOT = "Queue now: the %s list looks again now.",
	NOW_FOOT_FIGHT = "Queue now: the %s list looks again as the fight ends.",
}

local W = { frame = nil, n = "top", offset = 0, addOffset = 0, version = -1, painted = nil, runs = 0, faults = {}, elapsed = 0, message = nil,
	messageAt = 0, rows = {}, cells = {}, owners = {}, rules = {}, strokes = {}, dims = {}, plains = {}, words = {}, panels = {}, icons = {},
	edges = {}, placed = nil, dropped = nil, moving = false, opening = false, queued = false, look = nil, fade = nil, held = nil, quiet = nil }
local U, Z = {}, {}

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

local function Fn(source, name)
	if type(source) ~= "table" or IsSecret(source) then
		return nil
	end
	local fn = source[name]
	return type(fn) == "function" and fn or nil
end

local function Q()
	local q = ns.TrinketQueue
	return type(q) == "table" and q or nil
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return not ok or IsSecret(fighting) or fighting == true
end

local function Report(what, err)
	if W.faults[what] then
		return
	end
	W.faults[what] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, T.REPORT:format(tostring(what), tostring(err)))
	end
end

local function Step(_, fn, ...)
	return fn(...)
end

local function Run(fn, ...)
	W.runs = W.runs + 1
	local ok, err = ns.EachPart(KEY, PART, Step, W.runs, fn, ...)
	if not ok and err ~= nil then
		Report(PART, err)
		if ns.PartStopped(KEY, PART) then
			U.Close(true)
		end
	end
	return ok == true
end

local function Allowed()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.ModuleOn(KEY) and not ns.PartStopped(KEY, PART) and Q() ~= nil
end

local function Refusal()
	if type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.Enabled(KEY) and ns.PartStopped(KEY, PART) then
		return T.STOPPED
	end
	return T.OFF
end

function Z.RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

function Z.Opacity()
	local value = ns.Get("windows.opacity")
	return Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

function Z.Crop()
	local value = ns.Get("windows.crop")
	return (Finite(value) and math.max(0, math.min(15, value)) or 8) / 100
end

function Z.Signature()
	local r, g, b = Z.RGB("windows.accent", 0.85, 0.85, 0.85)
	local pr, pg, pb = Z.RGB("windows.panel", 0.12, 0.12, 0.12)
	return ("%.3f%.3f%.3f%.3f%.3f%.3f%.3f%.3f"):format(r, g, b, pr, pg, pb, Z.Opacity(), Z.Crop())
end

function U.Own(object)
	ns.Own[object] = true
	return object
end

function U.Label(parent, font, justify, width)
	local text = ns.OwnText(parent, "OVERLAY", font or FONT)
	if not text then
		error("no font string", 0)
	end
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(false)
	if width then
		text:SetWidth(width)
	end
	return text
end

function U.Dim(text)
	W.dims[#W.dims + 1] = text
	return text
end

function U.Texture(parent, layer, sub)
	return U.Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

function U.Stroke(button, layer, x1, y1, x2, y2)
	local line = U.Own(button:CreateLine(nil, layer, nil, 2))
	line:SetThickness(1.5)
	line:SetStartPoint("TOPLEFT", button, x1, -y1)
	line:SetEndPoint("TOPLEFT", button, x2, -y2)
	return line
end

function U.Button(parent, x, y, width, height)
	local button = U.Own(CreateFrame("Button", nil, parent))
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	button:SetSize(width, height)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	W.owners[#W.owners + 1] = button
	return button
end

function U.Strokes(button, points)
	local group = { lines = {}, hover = {} }
	for _, p in ipairs(points) do
		group.lines[#group.lines + 1] = U.Stroke(button, "OVERLAY", p[1], p[2], p[3], p[4])
		group.hover[#group.hover + 1] = U.Stroke(button, "HIGHLIGHT", p[1], p[2], p[3], p[4])
	end
	W.strokes[#W.strokes + 1] = group
	return group
end

function U.Edges(frame)
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, nil },
		{ "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
		local edge = U.Texture(frame, "BORDER")
		edge:SetPoint(side[1], frame, side[1], 0, 0)
		edge:SetPoint(side[2], frame, side[2], 0, 0)
		if side[3] then
			edge:SetWidth(side[3])
		else
			edge:SetHeight(side[4])
		end
		W.edges[#W.edges + 1] = edge
	end
end

function U.Panel(parent, x, y, side)
	local panel = U.Texture(parent, "BACKGROUND", 1)
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	panel:SetSize(side, side)
	W.panels[#W.panels + 1] = panel
	return panel
end

function U.Icon(parent, x, y, side)
	local icon = U.Texture(parent, "ARTWORK")
	icon:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	icon:SetSize(side, side)
	W.icons[#W.icons + 1] = icon
	return icon
end

function Z.Colour(text, colour, alpha)
	text:SetTextColor(colour[1], colour[2], colour[3], alpha or 1)
end

function Z.Tone(tone)
	if tone == "on" then
		local r, g, b = Z.RGB("windows.accent", 0.85, 0.85, 0.85)
		return { r, g, b }
	end
	return TONES[tone] or TONES.off
end

function Z.PaintLook()
	if not W.frame then
		return
	end
	W.look = Z.Signature()
	local r, g, b = Z.RGB("general.backdrop", 0.06, 0.06, 0.06)
	ns.SetOutlineFill(W.outline, r, g, b, Z.Opacity())
	ns.SetOutline(W.outline, true, true)
	local pr, pg, pb = Z.RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = Z.RGB("windows.accent", 0.85, 0.85, 0.85)
	for _, panel in ipairs(W.panels) do
		panel:SetColorTexture(pr, pg, pb, 1)
	end
	local crop = Z.Crop()
	for _, icon in ipairs(W.icons) do
		icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	for _, rule in ipairs(W.rules) do
		rule:SetColorTexture(1, 1, 1, SEPARATOR)
	end
	for _, edge in ipairs(W.edges) do
		edge:SetColorTexture(1, 1, 1, 0.25)
	end
	for _, group in ipairs(W.strokes) do
		for _, line in ipairs(group.lines) do
			line:SetColorTexture(1, 1, 1, 0.6)
		end
		for _, line in ipairs(group.hover) do
			line:SetColorTexture(ar, ag, ab, 1)
		end
	end
	for _, row in ipairs(W.rows) do
		row.hover:SetColorTexture(ar, ag, ab, 0.08)
		row.stripe:SetColorTexture(ar, ag, ab, 1)
		row.stopFill:SetColorTexture(TONES.halt[1], TONES.halt[2], TONES.halt[3], 1)
	end
	for _, cell in ipairs(W.cells) do
		cell.hover:SetColorTexture(ar, ag, ab, 0.25)
	end
	W.autoTick:SetColorTexture(ar, ag, ab, 1)
	W.underline:SetColorTexture(ar, ag, ab, 1)
	W.thumb:SetColorTexture(ar, ag, ab, 0.5)
	Z.Colour(W.title, PLAIN)
	for _, text in ipairs(W.dims) do
		Z.Colour(text, DIM)
	end
	W.version = -1
end

function Z.Tooltip()
	local tip = _G.GameTooltip
	if type(tip) == "table" and not IsSecret(tip) and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

function Z.Untip(owner)
	local tip = Z.Tooltip()
	if not tip then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

function Z.AddDim(tip, lines)
	for _, line in ipairs(lines) do
		if type(line) == "string" and line ~= "" then
			pcall(tip.AddLine, tip, line, DIM[1], DIM[2], DIM[3], true)
		end
	end
end

function Z.Say(owner, title, lines)
	local tip = Z.Tooltip()
	if Fighting() or not tip or not pcall(tip.SetOwner, tip, owner, "ANCHOR_RIGHT") then
		return
	end
	pcall(tip.AddLine, tip, title, PLAIN[1], PLAIN[2], PLAIN[3])
	Z.AddDim(tip, lines)
	pcall(tip.Show, tip)
end

function Z.Built(ok, answer)
	return ok and not IsSecret(answer) and answer ~= false
end

function Z.ItemTip(owner, id, copy, wornIn, lines)
	local tip = Z.Tooltip()
	if Fighting() or not tip or not pcall(tip.SetOwner, tip, owner, "ANCHOR_RIGHT") then
		return
	end
	local built = false
	if wornIn then
		built = Z.Built(pcall(tip.SetInventoryItem, tip, "player", wornIn == "top" and 13 or 14))
	end
	if not built and copy then
		built = Z.Built(pcall(tip.SetBagItem, tip, copy.bag, copy.slot))
	end
	if not built and Finite(id) then
		built = Z.Built(pcall(tip.SetItemByID, tip, id))
	end
	Z.AddDim(tip, lines)
	pcall(tip.Show, tip)
end

function U.Tip(frame, fn)
	frame:SetScript("OnEnter", function()
		Run(fn, frame)
	end)
	frame:SetScript("OnLeave", function()
		Z.Untip(frame)
	end)
end

function U.Says(frame, key)
	U.Tip(frame, function()
		local tip = T.TIPS[key]
		Z.Say(frame, tip[1], { tip[2], tip[3] })
	end)
end

function U.Held()
	if type(GetCursorInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, link = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" then
		return nil
	end
	link = not IsSecret(link) and type(link) == "string" and link or nil
	return Finite(id) and id or nil, link
end

function U.Lifted()
	local get, locked = Fn(_G.C_Cursor, "GetCursorItem"), Fn(_G.C_Item, "IsLocked")
	if not (get and locked) then
		return false
	end
	local ok, place = pcall(get)
	if not ok or IsSecret(place) or type(place) ~= "table" then
		return false
	end
	local slotted = false
	for _, name in ipairs({ "IsBagAndSlot", "IsEquipmentSlot" }) do
		local is = Fn(place, name)
		if is then
			local okIs, answer = pcall(is, place)
			slotted = slotted or (okIs and not IsSecret(answer) and answer == true)
		end
	end
	local okLocked, held = false, nil
	if slotted then
		okLocked, held = pcall(locked, place)
	end
	return okLocked and not IsSecret(held) and held == true
end

function U.Drop()
	local id, link = U.Held()
	local q = Q()
	if not (id and q) then
		return false
	end
	local okKind, _, _, _, equip = pcall(C_Item.GetItemInfoInstant, id)
	if not okKind or equip ~= "INVTYPE_TRINKET" then
		W.message, W.messageAt = T.ONLY, GetTime()
		W.version = -1
		return true
	end
	local done, message = q.Add(W.n, link or id)
	if U.Lifted() and type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
	if not done then
		W.message, W.messageAt = message, GetTime()
	end
	W.version = -1
	return true
end

function U.Linked(id)
	local modified = Fn(_G, "IsModifiedClick")
	if not Finite(id) or not modified then
		return false
	end
	local okKey, key = pcall(modified, "CHATLINK")
	if not okKey or IsSecret(key) or key ~= true then
		return false
	end
	local active = Fn(_G.ChatFrameUtil, "GetActiveWindow") or Fn(_G, "ChatEdit_GetActiveWindow")
	local okBox, box = false, nil
	if active then
		okBox, box = pcall(active)
	end
	local insert = Fn(_G.ChatFrameUtil, "InsertLink") or Fn(_G, "ChatEdit_InsertLink")
	if not (okBox and box ~= nil and not IsSecret(box) and insert) then
		return false
	end
	local q = Q()
	local link = q and q.Info(id).link
	if type(link) == "string" and link:find("|H", 1, true) then
		pcall(insert, link)
	else
		W.message, W.messageAt = T.NOT_LOADED, GetTime()
	end
	return true
end

function U.Dropping()
	if U.Drop() then
		Z.Paint()
	end
end

function U.Drops(frame, clicks)
	frame:SetScript("OnReceiveDrag", function()
		Run(U.Dropping)
	end)
	if clicks then
		frame:SetScript("OnMouseUp", function()
			Run(U.Dropping)
		end)
	end
end

function U.Click(button, fn)
	button:SetScript("OnClick", function(_, mouse)
		Run(function()
			if not U.Drop() then
				fn(mouse)
			end
			Z.Paint()
		end)
	end)
	U.Drops(button)
end

function U.Word(parent, text, width)
	local button = U.Own(CreateFrame("Button", nil, parent))
	button:SetSize(width, 18)
	button:RegisterForClicks("LeftButtonUp")
	local label = U.Label(button, FONT, "CENTER", width)
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText(text)
	W.owners[#W.owners + 1] = button
	return button, label
end

function U.MakeBar(frame)
	local bar = U.Own(CreateFrame("Frame", nil, frame))
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(L.BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Run(U.DragStart)
	end)
	bar:SetScript("OnDragStop", function()
		Run(U.Dropped)
	end)
	bar:SetScript("OnHide", function()
		if W.moving then
			pcall(U.Dropped)
		end
	end)
	U.Drops(bar, true)
	W.title = U.Label(bar, TITLE_FONT)
	W.title:SetPoint("LEFT", bar, "LEFT", L.PAD, 0)
	W.title:SetText(T.TITLE)
	local close = U.Own(CreateFrame("Button", nil, bar))
	close:SetSize(L.CLOSE, L.CLOSE)
	close:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	close:RegisterForClicks("LeftButtonUp")
	U.Strokes(close, { { 5, 5, 13, 13 }, { 5, 13, 13, 5 } })
	close:SetScript("OnClick", function()
		U.Close()
	end)
	local pause, label = U.Word(bar, T.PAUSE, 64)
	pause:SetPoint("RIGHT", close, "LEFT", -4, 0)
	W.pause, W.pauseLabel = pause, label
	U.Click(pause, function()
		local q = Q()
		q.SetPaused(not q.Paused())
	end)
	U.Says(pause, "pause")
	local rule = U.Texture(frame, "ARTWORK")
	rule:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -L.BAR)
	rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, -L.BAR)
	rule:SetHeight(1)
	W.rules[#W.rules + 1] = rule
end

function U.MakeSwitch(frame)
	local x = 12
	for _, n in ipairs({ "top", "bottom" }) do
		local button = U.Button(frame, x, Y.SWITCH, 100, L.SWITCH)
		local text = U.Label(button, FONT)
		text:SetPoint("LEFT", button, "LEFT", 0, 0)
		text:SetText(T.WORDS[n])
		local dot = U.Texture(button, "OVERLAY")
		dot:SetSize(L.DOT, L.DOT)
		dot:SetPoint("LEFT", text, "RIGHT", 5, 0)
		W.words[n] = { button = button, text = text, dot = dot }
		U.Click(button, function()
			U.Show(n)
		end)
		U.Tip(button, function()
			local q = Q()
			Z.Say(button, T.TIPS[n][1], { T.TIPS[n][2], q and q.Sentence(n) or nil })
		end)
		x = x + 110
	end
	W.underline = U.Texture(frame, "OVERLAY")
	W.underline:SetHeight(2)
	local auto = U.Button(frame, 222, Y.SWITCH, 90, L.SWITCH)
	local box = U.Own(CreateFrame("Frame", nil, auto))
	box:SetSize(L.BOX, L.BOX)
	box:SetPoint("LEFT", auto, "LEFT", 0, 0)
	U.Edges(box)
	W.autoTick = U.Texture(box, "ARTWORK")
	W.autoTick:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
	W.autoTick:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	local words = U.Dim(U.Label(auto, FONT))
	words:SetPoint("LEFT", box, "RIGHT", 5, 0)
	words:SetText(T.AUTO)
	U.Click(auto, function()
		local q = Q()
		q.SetAuto(W.n, not q.Auto(W.n))
	end)
	U.Says(auto, "auto")
end

function U.MakeSlot(frame)
	U.Panel(frame, 12, Y.SLOT + 2, L.ICON + 2)
	local icon = U.Icon(frame, 13, Y.SLOT + 3, L.ICON)
	local button = U.Button(frame, 12, Y.SLOT + 2, L.ICON + 2, L.ICON + 2)
	U.Drops(button)
	U.Click(button, function()
		local state = Q().State(W.n)
		if state.worn then
			U.Linked(state.worn)
		end
	end)
	U.Tip(button, function()
		local q = Q()
		local state = q and q.State(W.n)
		if state and state.worn then
			Z.ItemTip(button, state.worn, nil, W.n, { q.Sentence(W.n, state), T.LINK_TIP })
		elseif q then
			Z.Say(button, T.EMPTY_SLOT, { q.Sentence(W.n, state) })
		end
	end)
	local name = U.Label(frame, TITLE_FONT, "LEFT", 256)
	name:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -Y.SLOT)
	local state = U.Dim(U.Label(frame, FONT, "LEFT", 256))
	state:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -(Y.SLOT + 15))
	pcall(state.SetMaxLines, state, 2)
	local nextLine = U.Dim(U.Label(frame, FONT, "LEFT", 256))
	nextLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -(Y.SLOT + 27))
	local now, label = U.Word(frame, T.NOW, 66)
	now:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -(Y.SLOT - 2))
	U.Click(now, function()
		local q = Q()
		q.Now(W.n)
		W.message, W.messageAt = (q.Fighting() and T.NOW_FOOT_FIGHT or T.NOW_FOOT):format(T.WORDS[W.n]), GetTime()
	end)
	U.Says(now, "now")
	W.slot = { icon = icon, name = name, state = state, next = nextLine, now = now, nowLabel = label }
	local rule = U.Texture(frame, "ARTWORK")
	rule:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -(Y.HEAD - 3))
	rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, -(Y.HEAD - 3))
	rule:SetHeight(1)
	W.rules[#W.rules + 1] = rule
end

function U.MakeHeads(frame)
	local spots = { { X.ICON, "LEFT", 120 }, { X.CD, "RIGHT", X.CD_END - X.CD }, { X.DELAY, "CENTER", X.DELAY_END - X.DELAY },
		{ X.STOP - 4, "CENTER", L.STOP + 8 } }
	for index, spot in ipairs(spots) do
		local head = U.Dim(U.Label(frame, FONT, spot[2], spot[3]))
		head:SetPoint("TOPLEFT", frame, "TOPLEFT", spot[1], -Y.HEAD)
		head:SetText(T.HEADS[index])
	end
end

function U.MakeRow(frame, index)
	local y = Y.ROWS + (index - 1) * L.ROW
	local row = { index = index }
	row.frame = U.Own(CreateFrame("Frame", nil, frame))
	row.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -y)
	row.frame:SetSize(SIZE.W - 2 * L.PAD - 4, L.ROW)
	row.frame:EnableMouse(true)
	W.owners[#W.owners + 1] = row.frame
	U.Drops(row.frame, true)
	row.hover = U.Texture(row.frame, "BACKGROUND", 2)
	row.hover:SetAllPoints(row.frame)
	row.hover:Hide()
	row.stripe = U.Texture(row.frame, "ARTWORK")
	row.stripe:SetPoint("TOPLEFT", row.frame, "TOPLEFT", X.STRIPE - L.PAD, -2)
	row.stripe:SetSize(2, L.ROW - 4)
	U.Panel(row.frame, X.ICON - L.PAD - 1, 1, L.SMALL + 2)
	row.icon = U.Icon(row.frame, X.ICON - L.PAD, 2, L.SMALL)
	row.iconButton = U.Button(row.frame, X.ICON - L.PAD - 1, 1, L.SMALL + 2, L.SMALL + 2)
	row.name = U.Label(row.frame, TITLE_FONT, "LEFT", X.NAME_END - X.NAME)
	row.name:SetPoint("LEFT", row.frame, "LEFT", X.NAME - L.PAD, 0)
	row.cd = U.Label(row.frame, FONT, "RIGHT", X.CD_END - X.CD)
	row.cd:SetPoint("LEFT", row.frame, "LEFT", X.CD - L.PAD, 0)
	row.delay = U.Button(row.frame, X.DELAY - L.PAD, 2, X.DELAY_END - X.DELAY, L.ROW - 4)
	row.delayText = U.Label(row.delay, FONT, "CENTER", X.DELAY_END - X.DELAY)
	row.delayText:SetPoint("CENTER", row.delay, "CENTER", 0, 0)
	row.stop = U.Button(row.frame, X.STOP - L.PAD, (L.ROW - L.STOP) / 2, L.STOP, L.STOP)
	U.Edges(row.stop)
	row.stopFill = U.Texture(row.stop, "ARTWORK")
	row.stopFill:SetPoint("TOPLEFT", row.stop, "TOPLEFT", 3, -3)
	row.stopFill:SetPoint("BOTTOMRIGHT", row.stop, "BOTTOMRIGHT", -3, 3)
	local top = (L.ROW - L.ARROW) / 2
	row.up = U.Button(row.frame, X.UP - L.PAD, top, L.ARROW, L.ARROW)
	U.Strokes(row.up, { { 3, 8, 6, 4 }, { 6, 4, 9, 8 } })
	row.down = U.Button(row.frame, X.DOWN - L.PAD, top, L.ARROW, L.ARROW)
	U.Strokes(row.down, { { 3, 4, 6, 8 }, { 6, 8, 9, 4 } })
	row.cross = U.Button(row.frame, X.CROSS - L.PAD, top, L.ARROW, L.ARROW)
	U.Strokes(row.cross, { { 3, 3, 9, 9 }, { 3, 9, 9, 3 } })
	U.RowScripts(row)
	W.rows[index] = row
	return row
end

function U.RowScripts(row)
	local function Index()
		return row.index + W.offset
	end
	local function Hover(on)
		row.hover:SetShown(on)
	end
	row.frame:SetScript("OnEnter", function()
		Hover(true)
		Run(Z.RowTip, row, row.frame, false)
	end)
	row.frame:SetScript("OnLeave", function()
		Hover(false)
		Z.Untip(row.frame)
	end)
	U.Click(row.iconButton, function()
		if row.entry and not U.Linked(row.entry.item) then
			Q().Wear(W.n, row.entry.item)
		end
	end)
	U.Tip(row.iconButton, function()
		Z.RowTip(row, row.iconButton, true)
	end)
	U.Click(row.delay, function(mouse)
		local entry = row.entry
		if not entry then
			return
		end
		local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
		Q().SetDelay(W.n, Index(), shift and 0 or entry.delay + (mouse == "RightButton" and -5 or 5))
	end)
	U.Says(row.delay, "delay")
	U.Click(row.stop, function()
		Q().ToggleStop(W.n, Index())
	end)
	U.Says(row.stop, "stop")
	for _, part in ipairs({ { row.up, -1, "up" }, { row.down, 1, "down" } }) do
		U.Click(part[1], function()
			local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
			Q().Move(W.n, Index(), shift and part[2] * math.huge or part[2])
		end)
		U.Says(part[1], part[3])
	end
	U.Click(row.cross, function()
		Q().Remove(W.n, Index())
	end)
	U.Says(row.cross, "cross")
	for _, part in ipairs({ row.iconButton, row.delay, row.stop, row.up, row.down, row.cross }) do
		part:HookScript("OnEnter", function()
			Hover(true)
		end)
		part:HookScript("OnLeave", function()
			Hover(false)
		end)
	end
end

function U.MakeAdd(frame)
	local title = U.Dim(U.Label(frame, FONT, "LEFT", SIZE.W - 24))
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -Y.ADD_TITLE)
	title:SetText(T.ADD)
	W.addTitle = title
	W.addNone = U.Dim(U.Label(frame, FONT, "LEFT", SIZE.W - 24))
	W.addNone:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(Y.ADD + 5))
	W.addNone:SetText(T.NONE_CARRIED)
	for line = 1, L.LINES do
		for k = 1, L.PER_LINE do
			local x = 12 + (k - 1) * (L.CELL + L.CELL_GAP)
			local y = Y.ADD + (line - 1) * (L.CELL + L.CELL_GAP)
			local cell = { panel = U.Panel(frame, x, y, L.CELL), icon = U.Icon(frame, x + 1, y + 1, L.CELL - 2) }
			cell.button = U.Button(frame, x, y, L.CELL, L.CELL)
			cell.hover = U.Texture(cell.button, "HIGHLIGHT")
			cell.hover:SetAllPoints(cell.button)
			cell.more = U.Label(cell.button, FONT, "CENTER", L.CELL)
			cell.more:SetPoint("CENTER", cell.button, "CENTER", 0, 0)
			U.Click(cell.button, function()
				U.AddClick(cell)
			end)
			U.Tip(cell.button, function()
				Z.CellTip(cell)
			end)
			W.cells[#W.cells + 1] = cell
		end
	end
end

function U.AddClick(cell)
	if cell.moreCount then
		W.addOffset = W.addOffset + #W.cells - 1
		return
	end
	if cell.id and U.Linked(cell.id) then
		return
	end
	if cell.id then
		local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown() == true
		local done, message = Q().Add(W.n, cell.id, shift)
		if not done then
			W.message, W.messageAt = message, GetTime()
		end
		Z.Untip(cell.button)
	end
end

function U.MakeFoot(frame)
	local rule = U.Texture(frame, "ARTWORK")
	rule:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD, -Y.RULE)
	rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.PAD, -Y.RULE)
	rule:SetHeight(1)
	W.rules[#W.rules + 1] = rule
	W.foot = U.Dim(U.Label(frame, FONT, "LEFT", SIZE.W - 24))
	W.foot:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(Y.FOOT + 3))
	W.empty = U.Dim(U.Label(frame, FONT, "CENTER", SIZE.W - 48))
	W.empty:SetWordWrap(true)
	W.empty:SetPoint("TOP", frame, "TOPLEFT", SIZE.W / 2, -(Y.ROWS + 3 * L.ROW))
	W.empty:SetText(T.EMPTY)
	W.copy, W.copyLabel = U.Word(frame, "", 220)
	W.copy:SetPoint("TOP", frame, "TOPLEFT", SIZE.W / 2, -(Y.ROWS + 5 * L.ROW))
	W.copy:Hide()
	U.Click(W.copy, function()
		local added = Q().Copy(W.n)
		local other = W.n == "top" and "bottom" or "top"
		W.message, W.messageAt = added > 0 and T.COPIED_FOOT:format(added, T.WORDS[other]) or T.COPY_NONE_FOOT, GetTime()
		Z.Untip(W.copy)
	end)
	U.Tip(W.copy, function()
		local tip = T.TIPS.copy
		Z.Say(W.copy, tip[1], { tip[2]:format(T.WORDS[W.n == "top" and "bottom" or "top"], W.n) })
	end)
	W.thumb = U.Texture(frame, "OVERLAY")
	W.thumb:SetWidth(2)
end

function U.Rect(frame)
	local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okScale and okBase and Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and Finite(scale) and Finite(base))
		or base <= 0 then
		return nil
	end
	local k = scale / base
	return left * k, bottom * k, width * k, height * k
end

function U.OwnShown(name)
	local frame = _G[name]
	if type(frame) ~= "table" or IsSecret(frame) or not ns.Own[frame] then
		return nil
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown == true and frame or nil
end

local START = { GAP = 6, STEP = 28, DOCKED = 12 }
function U.Start(x, y)
	local okW, screen = pcall(UIParent.GetWidth, UIParent)
	local okH, tall = pcall(UIParent.GetHeight, UIParent)
	if not (okW and okH and Finite(screen) and Finite(tall)) then
		return x, y
	end
	local left, top, right
	local gear = U.OwnShown("FlatUIGear")
	if gear then
		local gl, gb, gw, gh = U.Rect(gear)
		if gl then
			left, top, right = gl, gb + gh, gl + gw
			local finder = U.OwnShown("FlatUIGearSearch")
			local fl, _, fw = nil, nil, nil
			if finder then
				fl, _, fw = U.Rect(finder)
			end
			if fl and fl >= right - 1 and fl <= right + START.DOCKED then
				right = fl + fw
			end
		end
	else
		local kit = ns.MoverKit
		local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME.FlatUIGear or nil
		local open = info and type(kit.IsOpen) == "function" and kit.IsOpen() == true
		if open and type(kit.BoxSize) == "function" and type(ns.MoverSpot) == "function" then
			local ok, gx, gy = pcall(ns.MoverSpot, "FlatUIGear", "TOPLEFT")
			local okSize, gw = pcall(kit.BoxSize, info)
			if ok and okSize and Finite(gx) and Finite(gy) and Finite(gw) then
				left, top, right = gx, gy, gx + gw
			end
		end
	end
	if not left then
		return x, y
	end
	if right + START.GAP + SIZE.W <= screen then
		return right + START.GAP, top - tall
	end
	return left + START.STEP, top - START.STEP - tall
end

function U.Place()
	local frame = W.frame
	if not frame or W.moving then
		return
	end
	local x, y, anchor
	if type(ns.MoverSpot) == "function" then
		local ok, sx, sy = pcall(ns.MoverSpot, NAME, "TOPLEFT")
		if ok and Finite(sx) and Finite(sy) then
			x, y, anchor = sx, sy, "BOTTOMLEFT"
		end
	end
	if not x and W.dropped then
		x, y, anchor = W.dropped[1], W.dropped[2], "BOTTOMLEFT"
	end
	if not x then
		x, y = U.Start(BOX.x, BOX.y)
		anchor = "TOPLEFT"
	end
	local key = ("%s:%.2f:%.2f"):format(anchor, x, y)
	if W.placed == key then
		return
	end
	W.placed = key
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, anchor, x, y)
end

function U.DragStart()
	W.frame:StartMoving()
	W.moving = true
end

function U.Dropped()
	if not W.moving then
		return
	end
	W.moving = false
	local frame = W.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	W.placed = nil
	local left, bottom, width, height = U.Rect(frame)
	if not left then
		U.Place()
		return
	end
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	local saved = false
	if info and type(kit.Commit) == "function" then
		saved = kit.Commit(NAME, info, left, bottom, width, height) == true
	end
	W.dropped = not saved and { left, bottom + height } or nil
	W.placed = nil
	U.Place()
end

function U.Special()
	local list = _G.UISpecialFrames
	if type(list) ~= "table" or IsSecret(list) then
		return
	end
	for _, listed in ipairs(list) do
		if listed == NAME then
			return
		end
	end
	table.insert(list, NAME)
end

function U.Raise()
	local over = false
	if type(ns.PanelShown) == "function" then
		local ok, shown = pcall(ns.PanelShown)
		over = ok and shown == true
	end
	W.frame:SetFrameStrata(over and "DIALOG" or "MEDIUM")
	pcall(W.frame.Raise, W.frame)
end

function Z.Quality(quality)
	local fn = Fn(_G.C_Item, "GetItemQualityColor")
	if fn and Finite(quality) then
		local ok, r, g, b = pcall(fn, quality)
		if ok and Finite(r) and Finite(g) and Finite(b) then
			return { r, g, b }
		end
	end
	return PLAIN
end

function Z.CooldownText(info)
	local q = Q()
	if info.carried == 0 and not info.wornIn then
		return T.NOT_CARRIED, DIM
	elseif info.tooHigh then
		return T.LEVEL:format(info.level), TONES.halt
	elseif not info.wornIn and not info.bound then
		return T.BINDS, DIM
	elseif info.left == false then
		return T.NO_USE, DIM
	elseif info.left == "held" then
		return T.IN_USE, PLAIN
	elseif not Finite(info.left) then
		return T.UNKNOWN, DIM
	elseif info.left <= 0 then
		return T.READY, Z.Tone("on")
	elseif Z.Soon(info) then
		return q.Clock(info.left), Z.Tone("on")
	end
	return q.Clock(info.left), PLAIN
end

function Z.Soon(info)
	local q = Q()
	local most = q and q.Threshold()
	if Finite(info.left) and info.left > 0 and Finite(most) and info.left <= most then
		return most
	end
	return nil
end

function Z.RowLines(info, entry)
	local lines = {}
	if info.carried == 0 and not info.wornIn then
		lines[#lines + 1] = T.GONE_TIP
	elseif not info.wornIn and not info.bound then
		lines[#lines + 1] = T.BINDS_TIP
	end
	if info.tooHigh then
		lines[#lines + 1] = T.LEVEL_TIP:format(info.level)
	end
	local soon = Z.Soon(info)
	if soon and not info.tooHigh and (info.wornIn or (info.carried > 0 and info.bound)) then
		lines[#lines + 1] = T.SOON_TIP:format(soon)
	end
	if entry and entry.delay > 0 then
		lines[#lines + 1] = T.DELAY_TIP:format(entry.delay)
	end
	if entry and entry.stop then
		lines[#lines + 1] = T.STOP_TIP
	end
	return lines
end

function Z.RowTip(row, owner, icon)
	local info = row.info
	if not (row.entry and info) then
		return
	end
	local lines = Z.RowLines(info, row.entry)
	if icon then
		table.insert(lines, 1, T.ROW_ICON)
	end
	Z.ItemTip(owner, info.id, info.copy, info.wornIn, lines)
end

function Z.CellTip(cell)
	if cell.moreCount then
		Z.Say(cell.button, T.TIPS.more[1]:format(cell.moreCount), { T.TIPS.more[2] })
	elseif cell.id then
		local lines = { T.ADD_TIP }
		local info = Q().Info(cell.id)
		if not info.wornIn and not info.bound then
			lines[#lines + 1] = T.BINDS_TIP
		end
		Z.ItemTip(cell.button, cell.id, cell.copy, cell.worn, lines)
	end
end

function Z.Row(row, entry, wornHere)
	row.entry = entry
	if not entry then
		row.info = nil
		row.frame:Hide()
		return
	end
	local info = Q().Info(entry.item)
	row.info = info
	row.icon:SetTexture(info.icon)
	row.name:SetText(info.name)
	Z.Colour(row.name, Z.Quality(info.quality))
	local text, colour = Z.CooldownText(info)
	row.cd:SetText(text)
	Z.Colour(row.cd, colour)
	row.delayText:SetText(entry.delay > 0 and T.SECONDS:format(entry.delay) or T.NO_DELAY)
	Z.Colour(row.delayText, entry.delay > 0 and PLAIN or DIM)
	row.stopFill:SetShown(entry.stop == true)
	row.stripe:SetShown(wornHere == entry.item)
	row.frame:Show()
end

function Z.Cooldowns()
	for _, row in ipairs(W.rows) do
		if row.entry then
			row.info = Q().Info(row.entry.item)
			local text, colour = Z.CooldownText(row.info)
			row.cd:SetText(text)
			Z.Colour(row.cd, colour)
		end
	end
end

function Z.Slot()
	local q = Q()
	local state = q.State(W.n)
	local slot = W.slot
	if state.worn then
		local info = q.Info(state.worn)
		slot.icon:SetTexture(info.icon)
		slot.icon:Show()
		slot.name:SetText(info.name)
		Z.Colour(slot.name, Z.Quality(info.quality))
	else
		slot.icon:Hide()
		slot.name:SetText(T.EMPTY_SLOT)
		Z.Colour(slot.name, DIM)
	end
	local tone = q.Tone(W.n, state)
	local hasNext = state.next ~= nil and state.nextAt ~= nil
	slot.state:SetWordWrap(not hasNext)
	slot.state:SetText(q.Sentence(W.n, state))
	Z.Colour(slot.state, (tone == "wait" or tone == "halt") and TONES[tone] or DIM)
	if hasNext then
		slot.next:SetText(T.NEXT:format(q.Info(state.next).name, q.Clock(state.nextAt - GetTime())))
		slot.next:Show()
	else
		slot.next:Hide()
	end
	local now = state.held ~= nil or state.refused or state.why == "stop"
	slot.now:SetShown(now)
	slot.name:SetWidth(now and 186 or 256)
	Z.Colour(slot.nowLabel, Z.Tone("on"))
	for _, n in ipairs({ "top", "bottom" }) do
		local word = W.words[n]
		local colour = Z.Tone(q.Tone(n))
		word.dot:SetColorTexture(colour[1], colour[2], colour[3], 1)
		Z.Colour(word.text, n == W.n and Z.Tone("on") or DIM)
	end
	local chosen = W.words[W.n].text
	W.underline:ClearAllPoints()
	W.underline:SetPoint("TOPLEFT", chosen, "BOTTOMLEFT", 0, -2)
	W.underline:SetPoint("TOPRIGHT", chosen, "BOTTOMRIGHT", 0, -2)
	W.autoTick:SetShown(q.Auto(W.n))
	local paused = q.Paused()
	W.pauseLabel:SetText(paused and T.PAUSED or T.PAUSE)
	Z.Colour(W.pauseLabel, paused and TONES.halt or DIM)
	return state
end

function Z.Add(list)
	local q = Q()
	local shown = {}
	for _, candidate in ipairs(q.Candidates()) do
		if not q.Find(list, candidate.id) then
			shown[#shown + 1] = candidate
		end
	end
	local room = #W.cells
	if W.addOffset >= #shown then
		W.addOffset = 0
	end
	local left = #shown - W.addOffset
	for index, cell in ipairs(W.cells) do
		local candidate = shown[W.addOffset + index]
		cell.moreCount = nil
		if index == room and left > room then
			cell.id, cell.copy, cell.worn = nil, nil, nil
			cell.icon:Hide()
			cell.more:SetText(T.MORE:format(left - room + 1))
			cell.moreCount = left - room + 1
			cell.button:Show()
		elseif candidate then
			cell.id, cell.copy, cell.worn = candidate.id, candidate.copy, candidate.worn
			cell.icon:SetTexture(q.Info(candidate.id).icon)
			cell.icon:Show()
			cell.more:SetText("")
			cell.button:Show()
		else
			cell.id, cell.copy, cell.worn = nil, nil, nil
			cell.icon:Hide()
			cell.more:SetText("")
			cell.button:Hide()
		end
		cell.panel:SetShown(cell.button:IsShown())
	end
	W.addNone:SetShown(#shown == 0)
end

function Z.Foot()
	local q = Q()
	local text = T.FOOT
	if q.Paused() then
		text = T.FOOT_PAUSED
	elseif W.message and GetTime() - W.messageAt < SAY_FOR then
		text = W.message
	elseif q.Fighting() then
		text = T.FOOT_FIGHT
	end
	W.foot:SetText(text)
end

function Z.Thumb(count)
	if count <= L.ROWS then
		W.thumb:Hide()
		return
	end
	local track = L.ROWS * L.ROW
	local height = math.max(8, track * L.ROWS / count)
	local top = (track - height) * W.offset / (count - L.ROWS)
	W.thumb:ClearAllPoints()
	W.thumb:SetPoint("TOPLEFT", W.frame, "TOPLEFT", X.THUMB, -(Y.ROWS + top))
	W.thumb:SetHeight(height)
	W.thumb:Show()
end

function Z.Paint()
	local q = Q()
	if not (q and W.frame) then
		return
	end
	W.version, W.painted = q.Version(), W.n
	local list = q.List(W.n)
	W.offset = math.max(0, math.min(W.offset, #list - L.ROWS))
	local state = Z.Slot()
	for index, row in ipairs(W.rows) do
		Z.Row(row, list[W.offset + index], state.worn)
	end
	W.empty:SetShown(#list == 0)
	local other = W.n == "top" and "bottom" or "top"
	local others = #list == 0 and #q.List(other) or 0
	if others > 0 then
		W.copyLabel:SetText(T.COPY:format(T.WORDS[other], others))
		Z.Colour(W.copyLabel, Z.Tone("on"))
	end
	W.copy:SetShown(others > 0)
	Z.Thumb(#list)
	Z.Add(list)
	Z.Foot()
end

function Z.Tick()
	if W.look ~= Z.Signature() then
		Z.PaintLook()
	end
	local q = Q()
	if not q then
		return
	end
	if W.version ~= q.Version() or W.painted ~= W.n then
		Z.Paint()
		return
	end
	Z.Slot()
	Z.Cooldowns()
	Z.Foot()
end

function Z.Scroll(delta)
	local q = Q()
	if not (q and Finite(delta)) then
		return
	end
	local count = #q.List(W.n)
	local offset = math.max(0, math.min(math.max(0, count - L.ROWS), W.offset - (delta > 0 and 1 or -1)))
	if offset ~= W.offset then
		W.offset = offset
		W.version = -1
		Z.Paint()
	end
end

function U.Make()
	local frame = U.Own(CreateFrame("Frame", NAME, UIParent))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:SetSize(SIZE.W, SIZE.H)
	frame:Hide()
	W.frame = frame
	W.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "windows")
	U.MakeBar(frame)
	U.MakeSwitch(frame)
	U.MakeSlot(frame)
	U.MakeHeads(frame)
	for index = 1, L.ROWS do
		U.MakeRow(frame, index)
	end
	U.MakeAdd(frame)
	U.MakeFoot(frame)
	U.Drops(frame, true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		Run(Z.Scroll, delta)
	end)
	frame:SetScript("OnShow", function()
		W.fade = 0
		frame:SetAlpha(0)
		if W.held then
			W.held = nil
		elseif type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_CHARACTER_INFO_OPEN then
			pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		end
		Run(U.Showing)
	end)
	frame:SetScript("OnHide", function()
		local holding = type(ns.MoversMode) == "table" and type(ns.MoversMode.Holding) == "function" and ns.MoversMode.Holding() == true
		W.held, W.fade = holding or nil, nil
		if not holding and not W.quiet and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then
			pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
		end
		U.Hiding()
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		local step = Finite(elapsed) and elapsed or 0
		if W.fade then
			W.fade = W.fade + step
			if W.fade >= FADE_IN then
				W.fade = nil
				frame:SetAlpha(1)
			else
				frame:SetAlpha(W.fade / FADE_IN)
			end
		end
		W.elapsed = W.elapsed + step
		if W.elapsed < TICK then
			return
		end
		W.elapsed = 0
		if Allowed() then
			Run(Z.Tick)
		else
			U.Close(true)
		end
	end)
	U.Special()
	Z.PaintLook()
	U.Place()
end

function U.Showing()
	U.Raise()
	W.elapsed = 0
	Z.PaintLook()
	U.Place()
	Z.Paint()
end

function U.Hiding()
	if W.moving then
		pcall(U.Dropped)
	end
	for _, owner in ipairs(W.owners) do
		Z.Untip(owner)
	end
end

function U.Show(n)
	if n ~= W.n then
		W.n, W.offset, W.addOffset = n, 0, 0
		W.version = -1
	end
end

function U.Open(n)
	if n == "top" or n == "bottom" then
		U.Show(n)
	end
	if not W.frame then
		if Fighting() then
			W.opening = true
			if not W.queued then
				W.queued = true
				print(T.AFTER_FIGHT)
				ns.OutOfCombat(function()
					W.queued = false
					if W.opening and Allowed() then
						W.opening = false
						Run(U.Open)
					end
				end)
			end
			return
		end
		U.Make()
	end
	if W.frame:IsShown() then
		U.Raise()
		Z.Paint()
	else
		U.Place()
		W.frame:Show()
	end
end

function U.Close(quiet)
	W.opening = false
	if W.frame then
		W.quiet = quiet == true or nil
		pcall(W.frame.Hide, W.frame)
		W.quiet = nil
	end
end

function U.IsOpen()
	if not W.frame then
		return false
	end
	local ok, shown = pcall(W.frame.IsShown, W.frame)
	return ok and shown == true
end

function ns.TrinketWindowToggle(n)
	if n ~= "top" and n ~= "bottom" then
		n = nil
	end
	if W.opening then
		W.opening = false
		return true
	end
	if U.IsOpen() and (n == nil or n == W.n) then
		U.Close()
		return true
	end
	if not Allowed() then
		print(Refusal())
		return false
	end
	return Run(U.Open, n)
end

function ns.TrinketWindowOpen(n)
	if not Allowed() then
		print(Refusal())
		return false
	end
	return Run(U.Open, n)
end

function ns.TrinketWindowSlot()
	return U.IsOpen() and W.n or nil
end

function ns.TrinketWindowLines()
	return T.LINES
end

function ns.TrinketWindowPick(id)
	local n = id == 1 and "top" or id == 2 and "bottom" or nil
	if not n then
		return false, nil
	end
	if not Allowed() then
		return false, Refusal()
	end
	return Run(U.Open, n), nil
end

function ns.TrinketWindowShown()
	return Allowed()
end

function ns.TrinketWindowStart(x, y)
	local ok, sx, sy = pcall(U.Start, x, y)
	if ok and Finite(sx) and Finite(sy) then
		return sx, sy
	end
	return x, y
end

function ns.TrinketWindowMoved()
	W.placed, W.dropped = nil, nil
	if W.frame then
		Run(U.Place)
	end
end

function ns.TrinketWindowSync()
	if not Allowed() then
		U.Close(true)
		return
	end
	if W.frame then
		Run(Z.PaintLook)
	end
end
