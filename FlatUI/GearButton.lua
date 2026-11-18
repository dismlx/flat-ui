local _, ns = ...

-- The Gear comparison button on the Character window: the part "gear button" of Chat and tooltips, while Button on the Character window is on
-- (chat.gearCharButton, Spells and gear tab). It is a small button of Flat UI's own, FlatUIGearButton, made on UIParent (CreateFrame,
-- WL/apis.yaml:35213) and anchored to the top right of CharacterFrame, left of the window's close cross, which is 28 wide at its top right
-- (SetPoint with CharacterFrame as the frame it hangs from, WL/uiobjects.yaml:7586; Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml:403-405,
-- Blizzard_SharedXML/Camelot/SharedUIPanelTemplates.lua:1-4). It is never parented to the Character window and writes nothing on it: of
-- CharacterFrame it reads only whether it shows (IsShown, WL/uiobjects.yaml:7680), its strata and level (GetFrameStrata, GetFrameLevel, :4217,
-- :4209), which the button takes, above the window's own buttons (its pane toggle is at level 510, CharacterFrame.xml:553), and whether the game
-- protects it (IsProtected, :7487).
-- It shows while the Character window shows. The game opens that window with ShowUIPanel (ToggleCharacter, Camelot/CharacterFrame.lua:3-30;
-- Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:871), which this file follows (ns.FollowGlobal, hooksecurefunc) to start a driver
-- of its own: a frame whose OnUpdate looks ten times a second whether the window still shows and stops once it is closed, so nothing runs while
-- the window is closed. The row's change (ns.GearButtonChanged, Config.lua) starts it too; the driver hides the button while the row, Chat and
-- tooltips or this part is off. It registers no event.
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
-- IconTexture, INV_Misc_Gear_01) cut by Icon crop (SetTexCoord), a thin border in the general border colour (ns.Outline, whose page is the Windows
-- page), and the Highlight colour under the cursor and in a strip along the bottom while the window is open.
-- A fight is InCombatLockdown's answer (WL/apis.yaml:39650), a withheld one counting as a fight. A frame anchored to a protected frame is
-- protected too, so while the game protects the Character window in a fight the button is made, anchored, levelled, shown and hidden only after
-- it (ns.OutOfCombat), and meanwhile only its alpha changes (SetAlpha); with the window not protected, as Camelot's CharacterFrame is not
-- (CharacterFrame.xml:403, Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:566), it also changes in a fight. The colours are painted
-- each time the Character window opens and as the Gear comparison window opens or closes. Everything runs through ns.EachPart, so three faults
-- stop the button alone with a line for /flatui status, and the button hides then. Every frame and texture here is Flat UI's own.

local KEY, PART, ROW = "chat", "gear button", "chat.gearCharButton"
local NAME = "FlatUIGearButton"
-- The side of the button, and its top right corner from the Character window's: left of the close cross (28 wide, its top 3 above the window's).
local SIDE, X, Y = 18, -32, -3
-- Levels above the Character window's own, above its pane toggle (510), and the highest level a frame may have.
local ABOVE, TOP_LEVEL = 520, 9000
-- How often the driver looks, and how long it waits after ShowUIPanel for the window to show before it stops.
local EVERY, GRACE = 0.1, 1
local ICON = "Interface\\Icons\\INV_Misc_Gear_01"
-- The height of the strip that says the window is open, and the alpha of the light under the cursor.
local STRIP, HOVER = 2, 0.18
local TITLE = "Gear comparison"
local TIPS = {
	"Click: open or close the Gear comparison window.",
	"With an item on the cursor, or dropped here: compare that item.",
	"Right-click: the item finder.",
	"Untick Button on the Character window (Chat and tooltips, Spells and gear tab) to hide it.",
}
local DIM, PLAIN = { 0.66, 0.68, 0.62 }, { 1, 1, 1 }

-- The button and its textures, made once; the frame it hangs from; the strata and level it has; whether the window was open at the last look; the
-- driver and its clock; whether a change waits for the end of a fight.
local B = { button = nil, icon = nil, hover = nil, strip = nil, outline = nil, anchored = nil, strata = nil, level = nil, open = nil,
	driver = nil, clock = 0, grace = 0, shown = false, waiting = false }

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

local function Paint()
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(B.outline, pr, pg, pb, 1)
	ns.SetOutline(B.outline, true, true)
	local crop = Crop()
	B.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	B.hover:SetColorTexture(ar, ag, ab, HOVER)
	B.strip:SetColorTexture(ar, ag, ab, 1)
	B.strip:SetShown(B.open == true)
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

local function Click(mouse)
	if Compare() then
		return
	end
	if mouse == "RightButton" then
		Finder()
	elseif Fn(ns, "GearWindowToggle") then
		Call("GearWindowToggle")
	else
		Call("GearWindowShow")
	end
	B.open = nil
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
	button:SetSize(SIDE, SIDE)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local icon = Texture(button, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexture(ICON)
	local hover = Texture(button, "HIGHLIGHT")
	hover:SetAllPoints(button)
	local strip = Texture(button, "OVERLAY")
	strip:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	strip:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	strip:SetHeight(STRIP)
	B.button, B.icon, B.hover, B.strip = button, icon, hover, strip
	B.outline = ns.SetOutlineArea(ns.Outline(button, button), "windows")
	button:SetScript("OnClick", function(_, mouse)
		Run(Click, mouse)
	end)
	button:SetScript("OnReceiveDrag", function()
		Run(Compare)
	end)
	button:SetScript("OnEnter", function()
		Run(Say)
	end)
	button:SetScript("OnLeave", function()
		Untip()
	end)
	button:SetScript("OnHide", function()
		Untip()
	end)
	Paint()
end

-- Hangs the button from the window, once: false while the game would refuse it.
local function Anchor(frame)
	if rawequal(B.anchored, frame) then
		return true
	end
	if Blocked(frame) or Blocked(B.button) then
		return false
	end
	B.button:ClearAllPoints()
	B.button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", X, Y)
	B.anchored = frame
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

-- One look of the driver: B.shown says whether the Character window shows.
local function Look()
	local frame = Character()
	B.shown = frame ~= nil and Shows(frame)
	local wanted = B.shown and Wanted()
	if wanted and not B.button then
		Make()
	end
	if not B.button then
		return
	end
	if not (wanted and Anchor(frame)) then
		if not wanted then
			Shown(false)
		else
			Later()
		end
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

-- Hides the button at once, whatever the state of the part, as the part stops or the module goes off.
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
	B.grace = B.grace - B.clock
	B.clock = 0
	if not Run(Look) then
		Off()
		Stop()
	elseif not B.shown and B.grace <= 0 then
		Stop()
	end
end

-- Starts the driver, which looks on the next frame and then ten times a second while the Character window shows.
function Start()
	if not B.driver then
		B.driver = CreateFrame("Frame")
		ns.Own[B.driver] = true
		B.driver:SetScript("OnUpdate", Drive)
	end
	B.grace, B.clock = GRACE, EVERY
	B.open = nil
	B.driver:Show()
end

-- ShowUIPanel ran: when it opens the Character window, the driver looks, and the first look paints the button in the Windows page's colours of now.
-- With the row off and no button made, nothing starts: the row's change starts the driver.
local function Panel(frame)
	if frame ~= nil and not IsSecret(frame) and rawequal(frame, _G.CharacterFrame) and (B.button ~= nil or ns.Get(ROW) == true) then
		Start()
	end
end

-- Button on the Character window changed (its row's changed, Config.lua): the driver looks at once.
function ns.GearButtonChanged()
	Start()
end

ns.FollowGlobal("ShowUIPanel", Panel)
