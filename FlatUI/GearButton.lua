local _, ns = ...

local KEY, PART, ROW = "chat", "gear button", "chat.gearCharButton"
local NAME = "FlatUIGearButton"
local WORDS = "Compare gear"
local HEIGHT, WIDE, ICON_SIDE, GAP, ROOM, WORDS_WIDTH = 20, 112, 14, 5, 6, 76
local X, Y = -34, -1
local CLEAR = 6
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local LEVEL = 20
local EVERY = 0.25
local FONT = "GameFontHighlight"
local ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local HOVER = 0.18
local TITLE = "Gear comparison"
local TIPS = {
	"Click: open or close the Gear comparison window.",
	"With an item on the cursor, or dropped here: compare that item.",
	"Right-click: the item finder.",
	"Untick Button on the Character window (Gear comparison, Window and finder tab) to hide it.",
}
local DIM, PLAIN, WORD = { 0.66, 0.68, 0.62 }, { 1, 1, 1 }, { 0.9, 0.9, 0.88 }

local B = { button = nil, icon = nil, words = nil, hover = nil, outline = nil, anchored = nil, point = nil, x = nil, y = nil, folded = nil,
	scale = nil, strata = nil, level = nil, open = nil, over = false, driver = nil, clock = 0, shown = false, wanted = false, waiting = false }

local Start

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

local function Run(fn, ...)
	return ns.EachPart(KEY, PART, fn, ...)
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.IsStopped(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(ROW) == true
end

local function Fighting()
	local ok, fighting = pcall(InCombatLockdown)
	return not ok or IsSecret(fighting) or fighting == true
end

local function Blocked(frame)
	if not Fighting() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or IsSecret(protected) or protected == true
end

local function Character()
	local frame = _G.CharacterFrame
	if type(frame) ~= "table" or IsSecret(frame) or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

local function Shows(frame)
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and not IsSecret(shown) and shown == true
end

local function Field(frame, key)
	if type(frame) ~= "table" or IsSecret(frame) or ns.Forbidden(frame) then
		return nil
	end
	local value = rawget(frame, key)
	if type(value) ~= "table" or IsSecret(value) or ns.Forbidden(value) then
		return nil
	end
	return value
end

local function Ratio(object)
	local ok, scale = pcall(object.GetEffectiveScale, object)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okBase and Finite(scale) and Finite(base) and scale > 0 and base > 0) then
		return nil
	end
	return scale / base
end

local function Rect(object)
	local k = Ratio(object)
	local ok, left, bottom, width, height = pcall(object.GetRect, object)
	if not (k and ok and Finite(left) and Finite(bottom) and Finite(width) and Finite(height)) then
		return nil
	end
	return left * k, bottom * k, width * k, height * k
end

local function WindowOpen()
	local open = Fn(ns, "GearWindowOpen")
	if not open then
		return false
	end
	local ok, answer = pcall(open)
	return ok and answer == true
end

local function Call(name, ...)
	local fn = Fn(ns, name)
	if not fn then
		return false
	end
	local ok, done, message = pcall(fn, ...)
	if not ok then
		geterrorhandler()(done)
		return false
	end
	if type(message) == "string" and not IsSecret(message) and message ~= "" then
		print(message)
	end
	return done ~= false
end

local function RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Crop()
	local value = ns.Get("windows.crop")
	return (Finite(value) and math.max(0, math.min(15, value)) or 8) / 100
end

local function WordsWidth()
	local words = B.words
	local ok, width = false, nil
	if words then
		ok, width = pcall(words.GetStringWidth, words)
	end
	if ok and Finite(width) and width > 0 then
		return math.ceil(width)
	end
	return WORDS_WIDTH
end

local function WideWidth()
	return math.max(WIDE, ROOM + ICON_SIDE + GAP + WordsWidth() + ROOM)
end

local function PaintWords()
	if B.open == true then
		local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
		B.words:SetTextColor(ar, ag, ab, 1)
	else
		local colour = B.over and PLAIN or WORD
		B.words:SetTextColor(colour[1], colour[2], colour[3], 1)
	end
end

local function Paint()
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(B.outline, pr, pg, pb, 1)
	ns.SetOutline(B.outline, true, true)
	local crop = Crop()
	B.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	B.hover:SetColorTexture(ar, ag, ab, HOVER)
	PaintWords()
end

local function Tooltip()
	local tip = _G.GameTooltip
	if type(tip) ~= "table" or IsSecret(tip) or ns.Forbidden(tip) then
		return nil
	end
	return tip
end

local function Untip()
	local tip, button = Tooltip(), B.button
	if not (tip and button) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

local function Say()
	local tip = Tooltip()
	if Fighting() or not tip or not pcall(tip.SetOwner, tip, B.button, "ANCHOR_BOTTOMLEFT") then
		return
	end
	pcall(tip.AddLine, tip, TITLE, PLAIN[1], PLAIN[2], PLAIN[3])
	for _, line in ipairs(TIPS) do
		pcall(tip.AddLine, tip, line, DIM[1], DIM[2], DIM[3], true)
	end
	pcall(tip.Show, tip)
end

local function Held()
	if type(GetCursorInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, link = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) or kind ~= "item" then
		return nil
	end
	if not IsSecret(link) and type(link) == "string" and link:find("|Hitem:", 1, true) then
		return link
	end
	if Finite(id) and id > 0 then
		return ("item:%d"):format(id)
	end
	return nil
end

local function Lifted()
	local get = Fn(_G.C_Cursor, "GetCursorItem")
	local locked = Fn(_G.C_Item, "IsLocked")
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
	if not slotted then
		return false
	end
	local okLocked, held = pcall(locked, place)
	return okLocked and not IsSecret(held) and held == true
end

local function Compare()
	local item = Held()
	if not item then
		return false
	end
	if Lifted() and type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
	Call("GearWindowShow", item)
	return true
end

local function Finder()
	local shown = Fn(ns, "GearSearchShown")
	local okShown, open = false, false
	if shown then
		okShown, open = pcall(shown)
	end
	if okShown and open == true and WindowOpen() then
		Call("GearSearchToggle")
		return
	end
	local lines = Fn(ns, "GearFindLines")
	local ok, rows = false, nil
	if lines then
		ok, rows = pcall(lines)
	end
	local first = ok and type(rows) == "table" and type(rows[1]) == "table" and rows[1][1] or nil
	if first ~= nil then
		Call("GearFindPick", first)
	else
		Call("GearSearchToggle")
	end
end

local function Click(mouse)
	if not Compare() then
		if mouse == "RightButton" then
			Finder()
		elseif Fn(ns, "GearWindowToggle") then
			Call("GearWindowToggle")
		else
			Call("GearWindowShow")
		end
	end
	Start()
end

local function Drop()
	Compare()
	Start()
end

local function Texture(parent, layer)
	local texture = parent:CreateTexture(nil, layer)
	ns.Own[texture] = true
	return texture
end

local function Make()
	local button = CreateFrame("Button", NAME, UIParent)
	ns.Own[button] = true
	button:Hide()
	button:SetSize(WIDE, HEIGHT)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local icon = Texture(button, "ARTWORK")
	icon:SetSize(ICON_SIDE, ICON_SIDE)
	icon:SetTexture(ICON)
	local words = ns.OwnText(button, "OVERLAY", FONT)
	if not words then
		error("no font string", 0)
	end
	words:SetJustifyH("LEFT")
	words:SetWordWrap(false)
	words:SetText(WORDS)
	local hover = Texture(button, "HIGHLIGHT")
	hover:SetAllPoints(button)
	B.button, B.icon, B.words, B.hover = button, icon, words, hover
	B.outline = ns.SetOutlineArea(ns.Outline(button, button), "windows")
	button:SetScript("OnClick", function(_, mouse)
		Run(Click, mouse)
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Drop)
	end)
	button:SetScript("OnEnter", function()
		B.over = true
		Run(PaintWords)
		Run(Say)
	end)
	button:SetScript("OnLeave", function()
		B.over = false
		Untip()
		Run(PaintWords)
	end)
	button:SetScript("OnHide", function()
		B.over = false
		Untip()
	end)
	Paint()
end

local function Layout(folded)
	local button, icon, words = B.button, B.icon, B.words
	icon:ClearAllPoints()
	words:ClearAllPoints()
	if folded then
		button:SetSize(HEIGHT, HEIGHT)
		icon:SetPoint("CENTER", button, "CENTER", 0, 0)
		words:Hide()
		return
	end
	local width, text = WideWidth(), WordsWidth()
	button:SetSize(width, HEIGHT)
	icon:SetPoint("LEFT", button, "LEFT", math.floor((width - ICON_SIDE - GAP - text) / 2 + 0.5), 0)
	words:SetPoint("LEFT", icon, "RIGHT", GAP, 0)
	words:Show()
end

local function TitleRight(frame)
	local text = Field(Field(frame, "TitleContainer"), "TitleText")
	if not text then
		return nil
	end
	local left, _, width = Rect(text)
	local k = Ratio(text)
	local ok, wide = pcall(text.GetStringWidth, text)
	if not (left and k and ok and Finite(wide)) then
		return nil
	end
	return left + width / 2 + math.min(wide * k, width) / 2
end

local function Saved(left, top)
	local saved, spot = Fn(ns, "MoverSaved"), Fn(ns, "MoverSpot")
	if not (saved and spot) then
		return nil
	end
	local okSaved, isSaved = pcall(saved, NAME)
	if not (okSaved and isSaved == true) then
		return nil
	end
	local ok, x, y = pcall(spot, NAME, "TOPLEFT")
	if not (ok and Finite(x) and Finite(y)) then
		return nil
	end
	return x - left, y - top
end

local function Scale(frame)
	local k = Ratio(frame)
	return k and math.floor(k * 1000 + 0.5) / 1000 or nil
end

local function Spot(frame)
	local left, bottom, width, height = Rect(frame)
	local k = Scale(frame)
	if not (left and k and k > 0) then
		return nil
	end
	local x, y = Saved(left, bottom + height)
	if x then
		return "TOPLEFT", x / k, y / k, false, k
	end
	local title = TitleRight(frame)
	return "TOPRIGHT", X, Y, title ~= nil and title + CLEAR * k > left + width + (X - WideWidth()) * k, k
end

local function Place(frame)
	local point, x, y, folded, k = Spot(frame)
	if not point then
		return false
	end
	x, y = math.floor(x * 100 + 0.5) / 100, math.floor(y * 100 + 0.5) / 100
	if rawequal(B.anchored, frame) and B.point == point and B.x == x and B.y == y and B.folded == folded and B.scale == k then
		return true
	end
	if Blocked(frame) or Blocked(B.button) then
		return false
	end
	if B.scale ~= k then
		B.button:SetScale(k)
		B.scale = k
	end
	Layout(folded)
	B.button:ClearAllPoints()
	B.button:SetPoint(point, frame, point, x, y)
	B.anchored, B.point, B.x, B.y, B.folded = frame, point, x, y, folded
	return true
end

local function Level(frame)
	if Blocked(B.button) then
		return
	end
	local okStrata, strata = pcall(frame.GetFrameStrata, frame)
	local level
	strata = okStrata and not IsSecret(strata) and type(strata) == "string" and strata or "MEDIUM"
	local above = STRATA[#STRATA]
	for i, name in ipairs(STRATA) do
		if name == strata then
			above = STRATA[math.min(i + 1, #STRATA)]
			break
		end
	end
	strata, level = above, LEVEL
	if B.strata ~= strata then
		B.button:SetFrameStrata(strata)
		B.strata = strata
	end
	if B.level ~= level then
		B.button:SetFrameLevel(level)
		B.level = level
	end
end

local function Later()
	if not B.waiting then
		B.waiting = true
		ns.OutOfCombat(function()
			B.waiting = false
			Start()
		end)
	end
end

local function Shown(shown)
	local button = B.button
	if not button then
		return
	end
	if Blocked(button) then
		button:SetAlpha(shown and 1 or 0)
		Later()
		return
	end
	button:SetAlpha(1)
	local ok, now = pcall(button.IsShown, button)
	if not (ok and now == shown) then
		button:SetShown(shown)
	end
	if not shown then
		Untip()
	end
end

local function Look()
	local frame = Character()
	B.wanted = Wanted()
	B.shown = frame ~= nil and Shows(frame)
	if not B.wanted then
		Shown(false)
		return
	end
	if B.shown and not B.button then
		Make()
	end
	if not B.button then
		return
	end
	if not B.shown then
		Shown(false)
		return
	end
	if not Place(frame) then
		Later()
		return
	end
	Level(frame)
	local open = WindowOpen()
	if open ~= B.open then
		B.open = open
		Paint()
	end
	Shown(true)
end

local function Off()
	if B.button then
		pcall(Shown, false)
	end
end

local function Stop()
	if B.driver then
		B.driver:Hide()
	end
end

local function Drive(_, elapsed)
	B.clock = B.clock + elapsed
	if B.clock < EVERY then
		return
	end
	B.clock = 0
	if not Run(Look) then
		Off()
		Stop()
	elseif not B.wanted then
		Stop()
	end
end

function Start()
	if not B.driver then
		B.driver = CreateFrame("Frame")
		ns.Own[B.driver] = true
		B.driver:SetScript("OnUpdate", Drive)
	end
	B.clock = EVERY
	B.open, B.anchored = nil, nil
	B.driver:Show()
end

local function Panel(frame)
	if frame ~= nil and not IsSecret(frame) and rawequal(frame, _G.CharacterFrame) then
		Start()
	end
end

function ns.GearButtonChanged()
	Start()
end

function ns.GearButtonShown()
	local frame = Character()
	return frame ~= nil and Wanted() and Shows(frame)
end

function ns.GearButtonStart(x, y)
	local frame = Character()
	if not frame then
		return x, y
	end
	local _, _, width = Rect(frame)
	local k = Scale(frame)
	if not (width and k) then
		return x, y
	end
	return width + (X - WideWidth()) * k, Y * k
end

function ns.GearButtonMoved()
	Start()
end

ns.FollowGlobal("ShowUIPanel", Panel)
ns.FollowGlobal("HideUIPanel", Panel)
