local _, ns = ...

-- The Compare gear button on the Character window: the part "gear button" of Chat and tooltips, while Button on the Character window is on
-- (chat.gearCharButton, Spells and gear tab). It is a button of Flat UI's own, FlatUIGearButton, made on UIParent (CreateFrame,
-- WL/apis.yaml:35213): Flat UI's gear icon left of the words Compare gear, 20 high, in the Windows page look. It is never parented to the
-- Character window and writes nothing on it: of CharacterFrame it reads whether it shows (IsShown, WL/uiobjects.yaml:7680), where it is (GetRect
-- and GetEffectiveScale, :7307, :7223), its strata and level (GetFrameStrata, GetFrameLevel, :4217, :4209), whether the game protects it
-- (IsProtected, :7487), and the width of its title text (the fields TitleContainer and TitleText, read with rawget; GetStringWidth, :3716).
-- Where it hangs. By default from the window's top right (SetPoint with CharacterFrame as the frame it hangs from, :7586): on the title bar,
-- right-aligned 6 clear of the close cross. The window is a PortraitFrameBaseTemplate (Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml:403):
-- its title bar (TitleContainer) runs from 1 under its top for 20, from 58 in on the left to 24 in on the right, and its title text is centred
-- in it (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:600-614); the close cross is 28 by 28 at the window's top right, its top 3
-- above the window's (CharacterFrame.xml:405, Blizzard_SharedXML/Camelot/SharedUIPanelTemplates.lua:1-4); the stats pane toggle is 28 by 28 at
-- 6 left and 6 under the top right of the left pane, which starts 20 under the window's top (CharacterFrame.xml:407-411, 553-557), so it is under
-- the title bar: the button, 1 under the window's top and 20 high, ends 5 above it. The window is 631 wide with the stats pane and 398 without
-- (Camelot/CharacterFrameConstants.lua:4, 7); where the title text (the player's name with a PvP rank, CharacterFrame.lua:376-382) would come
-- within 6 of the button, as a long name in the narrow window can, the words fold away and the button is its icon alone, right-aligned the same.
-- The movers size windows from 60 to 150 (Movers.lua, WIN), so the button takes the window's scale against UIParent's (SetScale, :7702, on its
-- own frame): its offsets, height and room are in the window's units, and it stays on the title bar and clear of the close cross, the title text
-- and the pane toggle at any size of the window.
-- The movers place it too: the entry Compare gear button (Movers.lua) has a handle while the window shows and the button is wanted
-- (ns.GearButtonShown); its spot is measured from the window's top left corner (from), so a saved spot hangs the button from the window's top
-- left at that spot and it goes with the window. With no spot saved the handle's box is where the button hangs by default (ns.GearButtonStart),
-- and a spot saved or put back is told here (ns.GearButtonMoved).
-- It shows while the Character window shows. A driver of its own, a frame whose OnUpdate looks four times a second, reads whether the window
-- shows while the row and Chat and tooltips are on, so the button comes and goes with the window however it opened, also when it was open before
-- login ended or the interface was reloaded; while the row, the module or this part is off it hides the button and stops looking. The game opens
-- the window with ShowUIPanel and closes it with HideUIPanel (ToggleCharacter, Camelot/CharacterFrame.lua:3-30; the close cross,
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:152-161; Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:871, 905), which
-- this file follows (ns.FollowGlobal, hooksecurefunc) to start the driver at once, so the button comes and goes on the next frame, as do the row's
-- change (ns.GearButtonChanged, Config.lua), each refresh of Chat and tooltips (Chat.lua), which comes as the module goes on or off, and a change
-- of the spot. It registers no event.
-- A left click opens or closes the Gear comparison window (ns.GearWindowToggle, GearWindow.lua). With an item on the cursor (GetCursorInfo,
-- WL/apis.yaml:36258), or one dropped on the button (OnReceiveDrag), the window opens with that item (ns.GearWindowShow): the window opened from
-- here starts on the item the cursor holds and the slots it takes, else as it was. An item lifted from a bag, the bank or a worn slot, where it
-- stays locked while it rides the cursor (C_Cursor.GetCursorItem, :10071, and C_Item.IsLocked, :17097), goes back there (ClearCursor, :34956, not
-- protected), as the window gives a dropped item back; any other stays on the cursor. A right click opens the item finder beside the window
-- (ns.GearFindLines and ns.GearFindPick, GearSearch.lua), or closes it while it shows (ns.GearSearchShown, ns.GearSearchToggle). These are looked
-- up when called, since those files load after this one or may fail; a message they give back is printed.
-- Its tooltip is GameTooltip (SetOwner, AddLine, Show, and Hide only while IsOwned says the button owns it, WL/uiobjects.yaml:4942), never in a
-- fight, as the Gear comparison window's tooltips wait.
-- The look is the Windows page's, as the Gear comparison window has it: the Button and slot colour behind Flat UI's own icon (the TOC's
-- IconTexture, INV_Misc_Gear_01) cut by Icon crop (SetTexCoord) and the words in GameFontHighlight, a thin border in the general border colour
-- (ns.Outline, whose page is the Windows page), and the Highlight colour under the cursor. The words are light grey, white under the cursor, and
-- light up in the Highlight colour while the Gear comparison window is open. The button takes the window's strata and a level 520 above the
-- window's, above its title bar, close cross and pane toggle (510: SharedUIPanelTemplates.xml:134, 600; CharacterFrame.xml:553), looked at each
-- time.
-- A fight is InCombatLockdown's answer (WL/apis.yaml:39650), a withheld one counting as a fight. Camelot's CharacterFrame is not protected (it and
-- its template mark nothing protected, CharacterFrame.xml:403), so the button changes in a fight too. A frame anchored to a protected frame is
-- protected too, so while the game protects the window in a fight the button is made, anchored, sized, levelled, shown and hidden only after it
-- (ns.OutOfCombat), and meanwhile only its alpha changes (SetAlpha). The colours are painted each time the driver starts and as the Gear
-- comparison window opens or closes. Everything runs through ns.EachPart, so three faults stop the button alone with a line for /flatui status,
-- and the button hides then. Every frame, texture and font string here is Flat UI's own.

local KEY, PART, ROW = "chat", "gear button", "chat.gearCharButton"
local NAME = "FlatUIGearButton"
local WORDS = "Compare gear"
-- The button: its height and least width with its words (the width of its box in the movers), the icon's side, the gap between the icon and the
-- words, the room at each end, and the width of the words while the client will not say.
local HEIGHT, WIDE, ICON_SIDE, GAP, ROOM, WORDS_WIDTH = 20, 112, 14, 5, 6, 76
-- Its top right corner from the Character window's by default: 6 clear of the close cross (28 wide at the window's top right) and 1 under the
-- window's top, where the title bar starts.
local X, Y = -34, -1
-- The least room between the title text and the button before the words fold away.
local CLEAR = 6
-- Levels above the Character window's own, above its title bar, close cross and pane toggle (510), and the highest level a frame may have.
local ABOVE, TOP_LEVEL = 520, 9000
-- How often the driver looks.
local EVERY = 0.25
local FONT = "GameFontHighlight"
local ICON = "Interface\\Icons\\INV_Misc_Gear_01"
-- The alpha of the light under the cursor.
local HOVER = 0.18
local TITLE = "Gear comparison"
local TIPS = {
	"Click: open or close the Gear comparison window.",
	"With an item on the cursor, or dropped here: compare that item.",
	"Right-click: the item finder.",
	"Untick Button on the Character window (Chat and tooltips, Spells and gear tab) to hide it.",
}
local DIM, PLAIN, WORD = { 0.66, 0.68, 0.62 }, { 1, 1, 1 }, { 0.9, 0.9, 0.88 }

-- The button and its parts, made once; the frame it hangs from and how (point, x, y, folded, scale); the strata and level it has; whether the
-- Gear comparison window was open at the last paint; whether the cursor is over it; the driver and its clock; whether the window shows and
-- whether the button is wanted at the last look; whether a change waits for the end of a fight.
local B = { button = nil, icon = nil, words = nil, hover = nil, outline = nil, anchored = nil, point = nil, x = nil, y = nil, folded = nil,
	scale = nil, strata = nil, level = nil, open = nil, over = false, driver = nil, clock = 0, shown = false, wanted = false, waiting = false }

local Start

local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

-- A function of a table, or nil.
local function Fn(source, name)
	if type(source) ~= "table" or IsSecret(source) then
		return nil
	end
	local fn = source[name]
	return type(fn) == "function" and fn or nil
end

-- Runs fn as this part (ns.EachPart, Core.lua): true when it ran without a fault.
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

-- True when the game would refuse a change to this frame now: in a fight, one it protects, or one that will not say.
local function Blocked(frame)
	if not Fighting() then
		return false
	end
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or IsSecret(protected) or protected == true
end

-- The Character window, once the game has made it, while addons may read it.
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

-- A frame or region held in a field of a frame, read with rawget and never written, or nil.
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

-- Units of UIParent for each unit of a frame or region, or nil.
local function Ratio(object)
	local ok, scale = pcall(object.GetEffectiveScale, object)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okBase and Finite(scale) and Finite(base) and scale > 0 and base > 0) then
		return nil
	end
	return scale / base
end

-- Left, bottom, width and height of a frame or region in the units of UIParent, or nil.
local function Rect(object)
	local k = Ratio(object)
	local ok, left, bottom, width, height = pcall(object.GetRect, object)
	if not (k and ok and Finite(left) and Finite(bottom) and Finite(width) and Finite(height)) then
		return nil
	end
	return left * k, bottom * k, width * k, height * k
end

-- The Gear comparison window is open (ns.GearWindowOpen, GearWindow.lua).
local function WindowOpen()
	local open = Fn(ns, "GearWindowOpen")
	if not open then
		return false
	end
	local ok, answer = pcall(open)
	return ok and answer == true
end

-- Calls a function of another file by its name, and prints the message it gives back, as the options window prints a list's (Panel.lua:784-789).
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

-- Looks ----------------------------------------------------------------------------------------------------------------------------------------

local function RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

-- Icon crop of the Windows page: the share of the icon's side cut from each edge.
local function Crop()
	local value = ns.Get("windows.crop")
	return (Finite(value) and math.max(0, math.min(15, value)) or 8) / 100
end

-- The width the words take in their font now, or WORDS_WIDTH while the client will not say.
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

-- The width of the button with its words: the icon, the gap and the words with room at each end, at least WIDE.
local function WideWidth()
	return math.max(WIDE, ROOM + ICON_SIDE + GAP + WordsWidth() + ROOM)
end

-- The words: in the Highlight colour while the Gear comparison window is open, white under the cursor, else light grey.
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

-- The tooltip ----------------------------------------------------------------------------------------------------------------------------------

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

-- A title and dim lines, never in a fight. SetOwner leaves the tooltip empty, as the game's own tooltips start with AddLine after it.
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

-- Clicks and drops -----------------------------------------------------------------------------------------------------------------------------

-- The item on the cursor: its link, else its item string, or nil.
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

-- True when the item on the cursor was lifted from a bag, the bank or a worn slot, so ClearCursor puts it back there (header): the place
-- C_Cursor.GetCursorItem gives is a bag slot or a worn slot, and the item there is locked, as it is while it rides the cursor.
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

-- The window opens with the item on the cursor, which goes back to its slot when it was lifted from one. False when the cursor holds no item.
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

-- The item finder: closed while it shows beside the open window, else opened with the window as its row opens it (its first line).
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

-- After a click or a drop the driver looks on the next frame, so the words light up or go out as the window opens or closes.
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

-- Making and placing ---------------------------------------------------------------------------------------------------------------------------

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

-- Sizes the button and lays out its icon and words: with the words, the icon and the words together in the middle of the button; folded, the
-- icon alone in a square.
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

-- The right edge of the window's title text, in the units of UIParent from the screen's left, or nil while it cannot be read: the title text
-- spans the title bar and its words are centred in it (header).
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

-- The spot saved in the movers, as offsets of the button's top left corner from the window's top left corner (left, top), in the units of
-- UIParent, which the button on UIParent has; nil while none is saved. ns.MoverSpot gives that corner on the screen, measured from the window
-- (Movers.lua, from).
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

-- The window's scale against UIParent's, to a thousandth, which the button takes (header), or nil.
local function Scale(frame)
	local k = Ratio(frame)
	return k and math.floor(k * 1000 + 0.5) / 1000 or nil
end

-- Where the button hangs from the window: the point of both, the offsets in the window's units, whether the words fold away and the scale the
-- button takes; nil while the window has no place.
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

-- Hangs the button from the window as Spot says, when that changed: false while the game would refuse it or the window has no place.
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

-- The window's strata, and a level above its own buttons; the game raises a window it is told to (toplevel), so this is looked at each time.
local function Level(frame)
	if Blocked(B.button) then
		return
	end
	local okStrata, strata = pcall(frame.GetFrameStrata, frame)
	local okLevel, level = pcall(frame.GetFrameLevel, frame)
	strata = okStrata and not IsSecret(strata) and type(strata) == "string" and strata or "MEDIUM"
	level = math.min(TOP_LEVEL, (okLevel and Finite(level) and level or 1) + ABOVE)
	if B.strata ~= strata then
		B.button:SetFrameStrata(strata)
		B.strata = strata
	end
	if B.level ~= level then
		B.button:SetFrameLevel(level)
		B.level = level
	end
end

-- After a fight the driver looks again, so a change the fight held back is made (once, however many waited).
local function Later()
	if not B.waiting then
		B.waiting = true
		ns.OutOfCombat(function()
			B.waiting = false
			Start()
		end)
	end
end

-- Shows or hides the button; while the game would refuse it, only its alpha changes until the fight ends.
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

-- One look of the driver: B.wanted says whether the button is wanted at all (else the driver stops), B.shown whether the Character window shows.
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

-- Hides the button at once, whatever the state of the part, as the part stops.
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

-- Starts the driver, which looks on the next frame and then four times a second while the button is wanted; the first look lays the button out
-- and hangs it again, and paints it in the Windows page's colours of now.
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

-- ShowUIPanel or HideUIPanel ran on the Character window: the driver starts at once, so the button comes or goes on the next frame.
local function Panel(frame)
	if frame ~= nil and not IsSecret(frame) and rawequal(frame, _G.CharacterFrame) then
		Start()
	end
end

-- Button on the Character window changed (its row's changed, Config.lua), or Chat and tooltips refreshed (Chat.lua): the driver looks at once.
function ns.GearButtonChanged()
	Start()
end

-- The gate of the movers' entry Compare gear button (Movers.lua): true while the Character window shows and the button is wanted.
function ns.GearButtonShown()
	local frame = Character()
	return frame ~= nil and Wanted() and Shows(frame)
end

-- Where the button starts while the movers keep no spot of it (start): the offsets of its top left corner, with its words, from the window's top
-- left corner in the units of UIParent, right-aligned left of the close cross on the window as wide and as large as it is now; else the entry's
-- x and y.
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

-- The movers saved or forgot the button's spot (changed): it hangs from the spot now, or on the title bar again.
function ns.GearButtonMoved()
	Start()
end

ns.FollowGlobal("ShowUIPanel", Panel)
ns.FollowGlobal("HideUIPanel", Panel)
