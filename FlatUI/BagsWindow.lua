local _, ns = ...

-- Bags, the two windows: FlatUIBags, all the bags in one, and FlatUIBank. Each is a frame of Flat UI's own on UIParent in the MEDIUM strata among
-- the game's windows, raised when clicked (SetToplevel, WL/uiobjects.yaml:4770) and kept on the screen (SetClampedToScreen), in the look of the
-- Windows page: the Background colour at Window opacity with a thin border (ns.Outline), and its buttons in Button and slot colour with the
-- Highlight colour, as Windows draws the game's windows and Clean up bags its button (Windows.lua:539-552, 815-855; BagSort.lua:433-446).
-- The title bar holds, left to right:
-- the character picker, the name of the character shown, in its class colour (RAID_CLASS_COLORS) and with its realm when that is not this
-- character's, with "as of" and the day of what is shown when it is not live (date and time, WL/apis.yaml:35306, 42024). A click opens a menu of
-- Flat UI's own (BagsLayout.lua) with every character Bags keeps, by realm, this realm first; while a search is typed each line says how many items
-- match there, the keyring's included, worked out one character a frame once the menu opens, never while the player types, from names the client
-- has loaded only;
-- the search box (B.Search.Box, BagsSearch.lua, told its window for its menu of quick searches), which B.Window.Focus gives the keyboard for the
-- bag search key; the view button, Sections or Bag by bag; the sort button, on live slots only: ns.BagSort.Run and
-- ns.BagSort.Sound (BagSort.lua:283-325), which looks busy and takes no click from the moment the game is asked to sort (BagSort tells its
-- watchers, ns.BagSort.Watch) until the window is laid out again once the items have stopped moving, six and a half seconds at most, and for as
-- long as the sort hold of Bags.lua lasts (B.Sorting), also when the window closed and opened again meanwhile; nothing arrives at the top shelf
-- then either; the bank button on the bag window (B.Bank.Toggle, BagsBank.lua); and the close button, a cross with no box, as Windows draws the
-- game's.
-- Dragging the title bar or the character picker moves the window (StartMoving and StopMovingOrSizing, :4797, 4813, with SetDontSavePosition and
-- SetUserPlaced, :4605, 4778, so the client keeps no place of its own); a drag that starts on the picker opens no menu. Where it is let go is saved
-- as its spot in the movers, also when the window closes during the drag: the box of its entry in Movers.lua, put with its corner at the window's,
-- goes to ns.MoverKit.Commit (Movers.lua:1713-1753, 4573-4575), and the window hangs from that spot (ns.MoverSpot, Movers.lua:856-877), the bag
-- window by its bottom right corner and the bank window by its top left, so each grows away from it, as the Threat list hangs from its spot
-- (Threat.lua:396-413). /flatui move shows the same box. With no spot saved, the bag window starts above the bottom right corner of the screen and
-- left of the right action bars that stand in their place there, as the game's bags open (ns.BagsWindowStart, which Movers.lua asks for the box
-- too): MultiBarRight and MultiBarLeft are read with widget calls only (IsVisible, GetLeft, GetRight, GetEffectiveScale), and whether Edit Mode
-- has each in its place from the field it keeps on the bar, systemInfo, and its isInDefaultPosition, read with rawget; each answer goes through
-- ns.IsSecret or ns.Finite.
-- The content scrolls in a scroll frame of Flat UI's own (SetScrollChild, SetVerticalScroll, :8020, 8028) once the window would be taller than 85%
-- of the screen, with a thin bar in the colours of Windows' scroll bars (Windows.lua:1191-1214), the wheel and the bar's thumb (GetCursorPosition,
-- WL/apis.yaml:36266). It is as wide as the layout (BagsLayout.lua) and its padding of 8 on each side, at least as wide as its title bar and its
-- footer need, and the bank window at least as wide as the row of BagsBank.lua over its footer. While a window is open, an update that does not
-- lay it out afresh never makes it shorter: the bag window hangs from its bottom right corner, so a shorter window would move everything above
-- what shrank (Free slots losing a row as its slots fill). It takes its exact height again at its next fresh layout and at its opening.
-- The bag window's footer has the gold of the character shown (Errands.Money, Errands.lua:65-85), whose tooltip lists the characters of this realm
-- and its connected realms, richest first, each with its realm when that is not this character's, with their total, and one line for those of
-- other realms, and while the window shows the player's own bags what this character made (in green) or spent (in red) since it logged in
-- (ns.SessionMoney, BagsData.lua; a /reload keeps the session, and nothing shows while it made and spent nothing); its free slots, those of the
-- general bags alone (B.Data.Free: the backpack and normal bags, family 0, the only room for any
-- item), whose tooltip names each special bag's free slots apart, uncounted (the reagent bag, a trade bag, a quiver, an ammo pouch, a soul bag
-- take only certain items), and leaves the keyring out, as its slots hold only keys; and, at a merchant, Sell junk (N): N is
-- ns.ErrandsJunkCount, what the next pass of Errands would sell, whose tooltip says what it brings (Errands.Money; "at least" while the price of
-- one has not loaded), and a click runs ns.ErrandsSellJunk, which sells as Errands sells and says why when it cannot. The bank window's footer has
-- the free slots of the bank, its general slots alone the same way, and, at the banker with a
-- search typed, Deposit (N) and Take out (N), the passes of BagsBank.lua (B.Bank.Deposit, B.Bank.TakeOut, B.Bank.Busy, whose per-click
-- fallback labels the button with what is left). These three buttons are this file's own, drawn as the title bar's are, and clicked as the
-- game's buttons are, by the left button let go over them, as Errands.Button's are (Errands.lua:127-201).
-- Between its gold and its free slots the bag window's footer has the currencies the Currency tab marks Show on Backpack, which are
-- BagsCurrency.lua's: Footer has B.Currency.Read read them for the character shown, and ArrangeFoot gives B.Currency.Fit the room the shortest
-- text of the free slots leaves after the gold, and hangs the frame it gives back after the gold, so they never reach either.
-- Each window keeps room in its least width for the buttons of its footer and the shortest text of its free slots, and the bag window for a gold
-- of the usual length too, whatever shows now, so it never changes width as a button comes or goes or the gold changes; the free slots are
-- written as fully as the room left allows, the word Free left out first.
-- The row above the bank window's footer, at the live bank only, is BagsBank.lua's (B.Bank.Slots), as high and as wide as that file says. A bank
-- never seen says how to keep one. The row above the bag window's footer, while it shows the player's own live bags and Bag slots is on, is the
-- bag slots of BagsSlots.lua (B.Slots.Row): the backpack, the four bags and the reagent bag, to put a bag in or swap one. Either row stands a
-- little apart from the content under a thin line of the separators' look, so its slots never read as one more row of the keyring or a bag.
-- Escape closes either window: both are named in UISpecialFrames, as the options window is (Panel.lua:2700-2708), whose windows the game's
-- CloseSpecialWindows hides (UIParentPanelManager.lua:21-27). Whatever hid a window (its close button, a key, Escape, the page going off), its
-- OnHide ends what is the window's own: a drag (where it was let go is kept), the keyboard of the search box, a menu and the busy sort button.
-- The bags tidy up in one place, Tidy of Bags.lua, which follows the hiding of a frame of that file's own inside the bag window: the game's bag
-- windows Bags parked hide (B.HideGameBags), every hold goes, New items lets go, the layout forgets its places, the search clears when the bank
-- window is not shown, and the window goes back to the logged-in character. The bank window's OnHide forgets its places, clears the search when
-- the bag window is not shown and goes back to the logged-in character; ending the visit to the banker when it hides is BagsBank.lua's. A window
-- hidden only with its parent (UIParent hidden by a movie, MovieFrame.lua:59-63, the report's screenshot mode or another addon; Alt+Z and
-- full-screen panels close the windows first, Bindings_Camelot.xml:1310-1317) keeps its own shown flag and is not closed meanwhile, as Bags.lua
-- and BagsBank.lua have it: its OnHide only ends a drag, the keyboard of the search box and a menu. As the interface comes back the game closes
-- every window (UIParent's OnShow runs CloseAllWindows, Blizzard_UIParent/UIParent.lua:5-7 and Blizzard_Game/Shared/Game.lua:91-93), which
-- hides both through CloseSpecialWindows and, during a visit with Flat UI's bank window, BankFrame through HideUIPanel, which ends the visit
-- (BagsBank.lua); Escape while the interface is hidden only brings it back (Game.lua:29-37). A window closed while the interface is hidden hears
-- no OnHide, so B.Window.Hide runs the steps of its closing itself then, with no sound, and for the bank window BagsBank's end of the visit
-- (B.Bank.Hidden), which its hook on the OnHide would run. The game closes the windows then too, with no code of Flat UI's running (its
-- CloseAllWindows at death, at a loss of control and on entering the world), and a window it hides as the interface comes back may hear no
-- OnHide, by the order the engine tells the frames in: a frame of this file's own on UIParent hears the interface come back (OnShow), and a
-- window that was open and is hidden now closes the same way then, the bag window with the bags' own closing (B.HideBags, Bags.lua).
-- An opening lays the window out afresh, which covers what was asked for it while it was closed, so it first has Bags.lua let that go
-- (B.LaidOut, looked up when called), and the pass after the opening does not draw every slot a second time. Opening and closing play the game's
-- own sounds of its bag windows (PlaySound with SOUNDKIT.IG_BACKPACK_OPEN and IG_BACKPACK_CLOSE, Mainline/ContainerFrame.lua:791, 819), once a
-- frame.
-- A slot of the bag window that owns the game's split box (StackSplitFrame) is left to the game: before this file hides the window or a slot, and
-- first in the OnHide of the window, of its title bar and of a footer button the window's hiding hides, B.Buttons.Unsplit (BagsItems.lua) writes
-- 0 in the slot's field hasStackSplit, so the template's OnHide (ContainerFrame.lua:1816-1822) does not hide the box in Flat UI's taint, whichever
-- of those frames the game tells first. The box then stays, anchored to the hidden slot, until the player presses Okay or Cancel.
-- Warm (B.Window.Warm): after BagsItems.lua made some of the game's item buttons, the hidden bag window shows for one frame off the left edge of the
-- screen (not clamped to it meanwhile) with every live button shown (B.Buttons.ShowAll) and hides on the next frame (C_Timer.After), doing none of
-- the work of an opening or a closing, so that no button is first shown in a fight; with the window open only the new buttons show that way
-- (B.Layout.Park), and the layout places them on the next frame. Nothing of it can be seen or reached by the mouse meanwhile, and none of it hides
-- a button by its alpha: the template's SetAlpha is a Lua method of the game that fades the icon and the count only
-- (Shared/ItemButtonTemplate.lua:239-245). Its end is queued whatever its steps did, and undoes its state as plain code with no part around it,
-- so a step that fails or a part that stops meanwhile never leaves the window warming, which would keep every opening waiting for that end.
-- Tooltips are GameTooltip (SetOwner, SetText, AddLine, AddDoubleLine, Show, Hide). Movers asks ns.BagsWindowShown and ns.BankWindowShown whether
-- the windows have a handle (while Bags is on) and ns.BagsWindowStart where the bag window starts, and calls ns.BagsWindowMoved and
-- ns.BankWindowMoved when their spots are set or put back.
-- Every frame, texture and font string here is Flat UI's own. This file owns no event of the module.

local B = ns.Bags
local Window = B.Window
local Layout = B.Layout
local Data = B.Data
local Search = B.Search
local Buttons = B.Buttons
local Bank = B.Bank
local Errands = ns.Errands

-- The windows by their global names, the corner each hangs from, and the boxes of their entries in Movers.lua with where they are with no spot
-- saved (width, height, x, y from that corner of the screen; the bag window's x moves left of the right action bars, ns.BagsWindowStart).
local NAMES = { bags = "FlatUIBags", bank = "FlatUIBank" }
local CORNERS = { bags = "BOTTOMRIGHT", bank = "TOPLEFT" }
local BOXES = { bags = { 360, 260, -60, 110 }, bank = { 420, 300, 25, -110 } }
-- The game's right action bars, which Edit Mode stacks at the right edge of the screen 5 units apart, how far one may stand from that edge or from
-- the bar right of it and still count as stacked there, and the room the game's bags leave beside them (Mainline/ContainerFrame.lua:1320-1326).
local RIGHT_BARS = { "MultiBarRight", "MultiBarLeft" }
local BAR_SLACK, BAR_ROOM = 12, 10
-- Units: the padding on each side, the title bar, the footer, the space between them and the content, a button of the title bar and the space
-- between two, the close button, the least room of the picker and of the search box, and the row of BagsBank.lua before it sizes it, with the
-- space on each side of the thin line over that row, so it does not read as one more row of the content.
local PAD, BAR, FOOT, INNER = 8, 26, 22, 4
local ICON, ICON_GAP, CLOSE = 18, 3, 18
local PICKER_LEAST, PICKER_MOST, SEARCH_LEAST, SEARCH_HEIGHT = 64, 0.5, 70, 18
local STRIP, STRIP_GAP = 26, 6
-- How far off the left edge of the screen the window stands while the warm-up shows it.
local PARK = 200
-- The least height of the content, and of the room for a message; the share of the screen a window may take.
local LEAST_VIEW, MESSAGE_VIEW, MOST = 40, 64, 0.85
-- The scroll bar: its width, the least height of its thumb, and the rows one turn of the wheel scrolls.
local TRACK_W, THUMB_LEAST, WHEEL_ROWS = 4, 16, 2
-- The cell pitch and the button of BagsLayout.lua, for the rows the wheel scrolls.
local PITCH, SLOT = 40, 37
-- The buttons of the footer; the room the footer keeps for the gold (a few thousand gold with its coins), and for the shortest text of the free
-- slots ("12/80"), and the space between two of its texts.
local SELL_W, MOVE_W, FOOT_BUTTON = 108, 96, 18
local GOLD_ROOM, FREE_ROOM, FOOT_GAP = 96, 40, 12
-- How often the footer is read again while a pass runs; how long the sort button looks busy at most, and the least time after the sort before a
-- layout ends it; how many characters the gold tooltip names.
local POLL, BUSY_MOST, BUSY_LEAST, MOST_GOLD = 0.5, 6.5, 0.35, 15
local KEYRING = -1
-- The text-dim of the windows (Threat.lua), and colours for a free count that is low or nothing; the gold made and spent this session.
local DIM = { 0.66, 0.68, 0.62 }
local SESSION_GAIN, SESSION_LOSS = { 0.3, 0.85, 0.3 }, { 1, 0.35, 0.24 }
local DIM_HEX, WHITE_HEX, LOW_HEX, NONE_HEX = "|cffa8ad9e", "|cffffffff", "|cffffd100", "|cffff5a3d"
local LOW = 4
-- The separators under the title bar and over the footer, white at this opacity.
local SEPARATOR = 0.07
-- The glyphs of the title bar's buttons, in units of an 18 unit button: rectangles { x, y, width, height } from its top left corner, and strokes
-- { x1, y1, x2, y2 }. The sort glyph is Clean up bags' three bars (BagSort.lua:37-41).
local GLYPHS = {
	sections = { rects = { { 4, 4, 2, 2 }, { 8, 4, 6, 2 }, { 4, 8, 2, 2 }, { 8, 8, 6, 2 }, { 4, 12, 2, 2 }, { 8, 12, 6, 2 } } },
	bags = { rects = { { 4, 4, 2, 2 }, { 8, 4, 2, 2 }, { 12, 4, 2, 2 }, { 4, 8, 2, 2 }, { 8, 8, 2, 2 }, { 12, 8, 2, 2 }, { 4, 12, 2, 2 },
		{ 8, 12, 2, 2 }, { 12, 12, 2, 2 } } },
	sort = { rects = { { 4, 4, 10, 2 }, { 4, 8, 7, 2 }, { 4, 12, 4, 2 } } },
	bank = { rects = { { 4, 8, 10, 1 }, { 5, 10, 1.5, 3.5 }, { 8.25, 10, 1.5, 3.5 }, { 11.5, 10, 1.5, 3.5 }, { 3.5, 14, 11, 1.5 } },
		strokes = { { 3.5, 7.5, 9, 3.5 }, { 9, 3.5, 14.5, 7.5 } } },
}

-- ns.IsSecret and ns.Finite of Core.lua, looked up when called.
local function IsSecret(value)
	return ns.IsSecret(value)
end

local function Finite(value)
	return ns.Finite(value)
end

-- Per window ("bags", "bank"): which, frame, outline; bar and its controls (picker, search, icons, close); scroll, child (the scroll child) and
-- content (the frame BagsLayout.lua lays out in, scaled); track and thumb of the scroll bar; foot and its labels and buttons, with plates, the
-- drawing of each button; freeTexts, the texts of the free slots, longest first; strip (the bank's row of BagsBank.lua, or the bag slots of
-- BagsSlots.lua) and stripW, the width of that row; message. viewH, contentH, offset: the height shown, the height of the content and the scroll.
-- placed: the spot it hangs from now;
-- dropped: where it was let go when the movers could not keep it. mode: what the last layout showed. busy: when the sort began; pulsing: the sort
-- button pulses. warming: the warm-up shows it; parked: it stands off the screen for the warm-up; wantShow: an opening asked for meanwhile;
-- warmQueued: the end of a warm-up is queued; warmButtons: the new buttons a warm-up showed in the open window. open: shown for real.
local windows = {}
-- The sounds played this frame, and whether BagSort tells this file of a sort. The frame on UIParent that hears the interface come back (Missed).
local played, watching = {}, false
local watcher = nil

local function Own(object)
	ns.Own[object] = true
	return object
end

-- A function of another part, looked up when it is called and never kept at load.
local function Fn(tbl, name)
	local fn = type(tbl) == "table" and tbl[name] or nil
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Call(tbl, name, ...)
	local fn = Fn(tbl, name)
	if fn then
		return fn(...)
	end
	return nil
end

-- Runs fn as a part of the module (B.Part, Bags.lua), so a part that keeps failing stops alone.
local function Run(part, fn, ...)
	local run = Fn(B, "Part")
	if run then
		return run(part, fn, ...)
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
	return ok
end

local function Opt(key)
	return Call(B, "Opt", key)
end

local function On()
	return Call(B, "On") == true
end

local function Request(flag, which)
	Call(B, "Request", flag, which)
end

local function Now()
	local ok, now = pcall(GetTime)
	return ok and Finite(now) and now or 0
end

local function After(seconds, fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

-- A word of the game's global strings, or the English one when the client has none.
local function Word(name, fallback)
	local text = _G[name]
	if type(text) == "string" and not IsSecret(text) and text ~= "" then
		return text
	end
	return fallback
end

local function Plain(text)
	return (tostring(text):gsub("|", "||"))
end

local function Hex(r, g, b)
	local function Byte(value)
		return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

-- Red, green and blue of a colour row of the Windows page, the look Bags takes (B.Look).
local function LookRGB(key, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, "windows." .. key)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

-- Window opacity of the Windows page, 0 to 1.
local function Opacity()
	local value = Call(B, "Look", "opacity")
	if not Finite(value) then
		value = ns.Get("windows.opacity")
	end
	return Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

local function TextWidth(text)
	local ok, width = pcall(text.GetUnboundedStringWidth, text)
	if not (ok and Finite(width)) then
		ok, width = pcall(text.GetStringWidth, text)
	end
	return ok and Finite(width) and width or 0
end

local function Shown(w)
	return w ~= nil and not w.warming and w.frame:IsShown() == true
end

-- An amount of copper as the game writes money.
local function Money(copper)
	if type(Errands) == "table" and type(Errands.Money) == "function" then
		return Errands.Money(copper)
	end
	return ("%dg"):format(math.floor(copper / 10000))
end

-- Tooltips ---------------------------------------------------------------------------------------------------------------------------------------

local function Tip(owner)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return nil
	end
	tip:SetOwner(owner, "ANCHOR_TOP")
	return tip
end

local function Untip(owner)
	local tip = GameTooltip
	if type(tip) ~= "table" or ns.Forbidden(tip) then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and owned == true then
		tip:Hide()
	end
end

-- A tooltip of a title and lines in the dim colour.
local function Say(owner, title, ...)
	local tip = Tip(owner)
	if not tip then
		return
	end
	tip:SetText(title, 1, 1, 1)
	for index = 1, select("#", ...) do
		local line = select(index, ...)
		if line then
			tip:AddLine(line, DIM[1], DIM[2], DIM[3], true)
		end
	end
	tip:Show()
end

-- Characters -------------------------------------------------------------------------------------------------------------------------------------

local function Characters()
	local list = Call(Data, "Characters")
	return type(list) == "table" and list or {}
end

local function CharacterOf(key)
	if key == nil then
		return nil
	end
	for _, c in ipairs(Characters()) do
		if type(c) == "table" and c.key == key then
			return c
		end
	end
	return nil
end

local function NameOf(key, c)
	if c and type(c.name) == "string" and not IsSecret(c.name) and c.name ~= "" then
		return c.name
	end
	if type(key) == "string" and not IsSecret(key) then
		return key:match("^(.-) %- ") or key
	end
	local ok, name = pcall(UnitName, "player")
	if ok and type(name) == "string" and not IsSecret(name) and name ~= "" then
		return name
	end
	return "?"
end

-- The realm a character is listed under: the realm of its key, as the game writes it, else the one kept with it.
local function RealmOf(c)
	if type(c.key) == "string" and not IsSecret(c.key) then
		local realm = c.key:match(" %- (.+)$")
		if realm and realm ~= "" then
			return realm
		end
	end
	if type(c.realm) == "string" and not IsSecret(c.realm) and c.realm ~= "" then
		return c.realm
	end
	return "?"
end

-- How a character is named on its own (the window's title, the gold list, a message): its name, and its realm after it when that is not this
-- character's, as BagsTooltip.lua's counts and the gold of DataStreams.lua name one, since characters of connected realms may share a name.
local function Named(key, c)
	local name = NameOf(key, c)
	local me = Call(B, "Me")
	local mine = type(me) == "string" and not IsSecret(me) and me:match(" %- (.+)$") or nil
	local realm = type(c) == "table" and RealmOf(c) or nil
	if (realm == nil or realm == "?") and type(key) == "string" and not IsSecret(key) then
		realm = key:match(" %- (.+)$")
	end
	if mine and realm and realm ~= "?" and realm ~= mine then
		return name .. " - " .. realm
	end
	return name
end

local function ClassRGB(class)
	if type(class) ~= "string" or IsSecret(class) then
		return nil
	end
	local colours = RAID_CLASS_COLORS
	local colour = type(colours) == "table" and not IsSecret(colours) and colours[class] or nil
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if Finite(r) and Finite(g) and Finite(b) then
		return r, g, b
	end
	return nil
end

local function ClassHex(class)
	local r, g, b = ClassRGB(class)
	return r and Hex(r, g, b) or WHITE_HEX
end

-- When something was seen, as a day: today, yesterday or so many days ago, by the calendar of this computer (date and time).
local function AsOf(seen)
	if not Finite(seen) or seen <= 0 then
		return nil
	end
	local function Noon(t)
		local ok, day = pcall(date, "*t", t)
		if not ok or type(day) ~= "table" then
			return nil
		end
		local okTime, noon = pcall(time, { year = day.year, month = day.month, day = day.day, hour = 12 })
		return okTime and Finite(noon) and noon or nil
	end
	local okNow, now = pcall(time)
	local today, then_ = okNow and Finite(now) and Noon(now) or nil, Noon(seen)
	if not (today and then_) then
		return nil
	end
	local days = math.floor((today - then_) / 86400 + 0.5)
	if days <= 0 then
		return "as of today"
	elseif days == 1 then
		return "as of yesterday"
	end
	return ("as of %d days ago"):format(days)
end

-- How many items match the search among a character's slots of a window: for the character picker the stacks added up, the keyring's included,
-- since the window shows and lights it; for stacks false (Deposit and Take out) the slots without the keyring, which their passes never take from
-- (BagsBank.lua). Only names the client has loaded count; nothing is asked for (B.Search.Match gives nil for the others). A match that fails
-- counts as none, so a fault of the search never stops the window.
local function Matches(which, key, stacks)
	local match = Fn(Search, "Match")
	if not match then
		return 0
	end
	local count = 0
	local list = Call(Data, "Containers", which, key)
	for _, bag in ipairs(type(list) == "table" and list or {}) do
		if Finite(bag) and (stacks or bag ~= KEYRING) then
			local slots = Call(Data, "Size", key, bag)
			for slot = 1, Finite(slots) and slots or 0 do
				local record = Call(Data, "Item", key, bag, slot)
				if type(record) == "table" then
					local ok, matched = pcall(match, record)
					if ok and matched == true then
						local n = stacks and record.count or 1
						count = count + (Finite(n) and n > 0 and n or 1)
					end
				end
			end
		end
	end
	return math.floor(count)
end

-- Drawing ----------------------------------------------------------------------------------------------------------------------------------------

local function Rule(owner)
	local rule = Own(owner:CreateTexture(nil, "ARTWORK"))
	return rule
end

local function Bit(button, x, y, width, height)
	local bit = Own(button:CreateTexture(nil, "OVERLAY", nil, 2))
	bit:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
	bit:SetSize(width, height)
	return bit
end

local function Stroke(button, layer, x1, y1, x2, y2)
	local line = Own(button:CreateLine(nil, layer or "OVERLAY", nil, 2))
	line:SetThickness(1.5)
	line:SetStartPoint("TOPLEFT", button, x1, -y1)
	line:SetEndPoint("TOPLEFT", button, x2, -y2)
	return line
end

-- The regions of one glyph.
local function Glyph(button, spec)
	local parts = {}
	for _, r in ipairs(spec.rects or {}) do
		parts[#parts + 1] = Bit(button, r[1], r[2], r[3], r[4])
	end
	for _, s in ipairs(spec.strokes or {}) do
		parts[#parts + 1] = Stroke(button, "OVERLAY", s[1], s[2], s[3], s[4])
	end
	return parts
end

local function SetGlyph(parts, shown)
	for _, part in ipairs(parts) do
		part:SetShown(shown)
	end
end

-- The colours of a button of the title bar: the box in Button and slot colour, the glyph and the light under the cursor in the Highlight colour,
-- as Clean up bags' button has them (BagSort.lua:433-446).
local function PaintIcon(icon, alpha)
	local pr, pg, pb = LookRGB("panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(icon.outline, pr, pg, pb, 1)
	ns.SetOutline(icon.outline, true, true)
	icon.hover:SetColorTexture(ar, ag, ab, 0.25)
	for _, parts in pairs(icon.glyphs) do
		for _, part in ipairs(parts) do
			part:SetColorTexture(ar, ag, ab, alpha or 0.9)
		end
	end
end

-- The colours of a button of the footer, as PaintIcon gives the title bar's: the box in Button and slot colour and the light under the cursor in the
-- Highlight colour, none while the button takes no click, which also dims its label as Errands.Button does (Errands.lua:138-146).
local function PaintPlate(plate)
	local pr, pg, pb = LookRGB("panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	ns.SetOutlineFill(plate.outline, pr, pg, pb, 1)
	ns.SetOutline(plate.outline, true, true)
	plate.hover:SetColorTexture(ar, ag, ab, plate.usable and 0.25 or 0)
	plate.label:SetAlpha(plate.usable and 1 or 0.45)
end

local function PaintWindow(w)
	local r, g, b = ns.Colour("general.backdrop")
	ns.SetOutlineFill(w.outline, r, g, b, Opacity())
	ns.SetOutline(w.outline, true, true)
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	for _, icon in pairs(w.icons) do
		PaintIcon(icon)
	end
	for _, line in ipairs(w.close.lines) do
		line:SetColorTexture(1, 1, 1, 0.6)
	end
	for _, line in ipairs(w.close.hover) do
		line:SetColorTexture(ar, ag, ab, 1)
	end
	w.pickerLight:SetColorTexture(1, 1, 1, 0.06)
	for _, line in ipairs(w.chevron) do
		line:SetColorTexture(1, 1, 1, 0.6)
	end
	for _, rule in ipairs(w.rules) do
		rule:SetColorTexture(1, 1, 1, SEPARATOR)
	end
	w.trackBack:SetColorTexture(0, 0, 0, 0.3)
	w.thumbBack:SetColorTexture(ar, ag, ab, w.thumbOver and 0.5 or 0.25)
	w.message:SetTextColor(DIM[1], DIM[2], DIM[3], 1)
	for _, plate in ipairs(w.plates) do
		PaintPlate(plate)
	end
end

-- The window -------------------------------------------------------------------------------------------------------------------------------------

local Showing, Hiding, Missed, Footer, TitleLine, Resize, ArrangeBar, ArrangeFoot, SetOffset

-- What the window shows now, to tell whether an opening asked for while it is open needs a new layout.
local function Mode(which)
	local key, _, live = Layout.Viewed(which)
	return tostring(key) .. ":" .. tostring(live)
end

-- Escape closes the window: the game hides the windows named in this list (UIParentPanelManager.lua:21-27, 1104-1116).
local function Special(name)
	if type(UISpecialFrames) ~= "table" then
		return
	end
	for _, listed in ipairs(UISpecialFrames) do
		if listed == name then
			return
		end
	end
	table.insert(UISpecialFrames, name)
end

-- The game's own sounds of its bag windows, once a frame: at the banker the bank and the bags open together.
local function Sound(name)
	if type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" or IsSecret(SOUNDKIT) then
		return
	end
	local id = SOUNDKIT[name]
	if not Finite(id) then
		return
	end
	local now = Now()
	if played[name] == now then
		return
	end
	played[name] = now
	pcall(PlaySound, id)
end

-- Before this file hides the bag window, a slot of it or a frame that holds one, and first in the OnHide of the frames the window's hiding hides: a
-- live slot that owns the game's split box leaves it to the game (B.Buttons.Unsplit, BagsItems.lua), so the template's OnHide does not hide the
-- box in Flat UI's taint. With a button, that one; else every live slot. The bank window has none.
local function Unsplit(w, button)
	if w.which == "bags" then
		Call(Buttons, "Unsplit", button)
	end
end

-- The sort button ----------------------------------------------------------------------------------------------------------------------------------

local function PaintSort(w)
	local icon = w.icons.sort
	if icon then
		PaintIcon(icon)
	end
end

local function EndBusy(w)
	if w.busy then
		w.busy = nil
		PaintSort(w)
	end
end

-- True while a sort still moves the window's items: from BagSort's word until the window is laid out again (busy), and while Bags.lua holds
-- the window's places (B.Sorting), which a closing and opening during the hold does not end. Nothing arrives at the top shelf meanwhile, and the
-- sort button looks busy and takes no click.
local function Sorting(w)
	return w.busy ~= nil or Call(B, "Sorting", w.which) == true
end

-- BagSort asked the game to sort the bags or the bank: that window's sort button looks busy until the window is laid out again.
local function Sorted(which)
	local w = windows[which]
	if not w then
		return
	end
	local began = Now()
	w.busy = began
	After(BUSY_MOST, function()
		if w.busy == began then
			Run("window", EndBusy, w)
		end
	end)
end

-- Listens to BagSort's word that the game was asked to sort (ns.BagSort.Watch), once.
local function Watching()
	if watching then
		return
	end
	local sort = ns.BagSort
	local watch = type(sort) == "table" and sort.Watch or nil
	if type(watch) == "function" then
		watching = pcall(watch, function(which)
			Run("window", Sorted, which)
		end) == true
	end
end

local function Pulse(w)
	local icon = w.icons.sort
	if not icon then
		return
	end
	local alpha = 0.3 + 0.55 * math.abs(math.sin(Now() * 3))
	local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
	for _, part in ipairs(icon.glyphs.sort) do
		part:SetColorTexture(ar, ag, ab, alpha)
	end
end

-- The title bar ------------------------------------------------------------------------------------------------------------------------------------

local Clicks, Tips = {}, {}

-- A button of the title bar with the glyphs it may show.
local function Icon(w, kind, glyphs)
	local button = Own(CreateFrame("Button", nil, w.bar))
	button:SetSize(ICON, ICON)
	button:RegisterForClicks("LeftButtonUp")
	local icon = { kind = kind, button = button, glyphs = {} }
	icon.outline = ns.Outline(button, button)
	icon.hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	icon.hover:SetAllPoints(button)
	for _, name in ipairs(glyphs) do
		icon.glyphs[name] = Glyph(button, GLYPHS[name])
	end
	button:SetScript("OnClick", function()
		Run("window", Clicks[kind], w)
	end)
	button:SetScript("OnEnter", function()
		Run("window", Tips[kind], w, button)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	w.icons[kind] = icon
	return icon
end

local function MakeClose(w)
	local button = Own(CreateFrame("Button", nil, w.bar))
	button:SetSize(CLOSE, CLOSE)
	button:RegisterForClicks("LeftButtonUp")
	local close = { button = button }
	close.lines = { Stroke(button, "OVERLAY", 5, 5, 13, 13), Stroke(button, "OVERLAY", 5, 13, 13, 5) }
	close.hover = { Stroke(button, "HIGHLIGHT", 5, 5, 13, 13), Stroke(button, "HIGHLIGHT", 5, 13, 13, 5) }
	button:SetScript("OnClick", function()
		Window.Hide(w.which)
	end)
	w.close = close
end

-- A drag of the title bar: the window follows the cursor, and where it is let go becomes its spot.
local function DragStart(w)
	Layout.CloseMenu(w.which)
	w.frame:StartMoving()
	w.moving = true
end

-- Left, bottom, width and height of a frame in the units of UIParent.
local function RectOf(frame)
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

-- The window was let go: the box of its entry in the movers, put with its corner at the window's, is saved as its spot (ns.MoverKit.Commit), and
-- the window hangs from it (ns.BagsWindowMoved). Without the entry it stays where it was let go for this session.
local function Dropped(w)
	if not w.moving then
		return
	end
	w.moving = false
	local frame = w.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	w.placed = nil
	local which = w.which
	local left, bottom, width, height = RectOf(frame)
	if not left then
		Window.Place(which)
		return
	end
	local name, box = NAMES[which], BOXES[which]
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[name] or nil
	local boxW = info and Finite(info.width) and info.width > 0 and info.width or box[1]
	local boxH = info and Finite(info.height) and info.height > 0 and info.height or box[2]
	local boxLeft, boxBottom
	if CORNERS[which] == "BOTTOMRIGHT" then
		boxLeft, boxBottom = left + width - boxW, bottom
	else
		boxLeft, boxBottom = left, bottom + height - boxH
	end
	local saved = false
	if info and type(kit.Commit) == "function" then
		saved = kit.Commit(name, info, boxLeft, boxBottom, boxW, boxH) == true
	end
	if saved then
		w.dropped = nil
	elseif CORNERS[which] == "BOTTOMRIGHT" then
		w.dropped = { left + width, bottom }
	else
		w.dropped = { left, bottom + height }
	end
	w.placed = nil
	Window.Place(which)
end

local function MakePicker(w)
	local button = Own(CreateFrame("Button", nil, w.bar))
	button:SetHeight(ICON)
	button:RegisterForClicks("LeftButtonUp")
	w.pickerLight = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	w.pickerLight:SetAllPoints(button)
	local text = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", button, "LEFT", 4, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	w.picker, w.pickerText = button, text
	-- A small chevron at its right: it opens a list.
	w.chevron = {}
	for index, s in ipairs({ { -11, 1.5, -8, -1.5 }, { -8, -1.5, -5, 1.5 } }) do
		local line = Own(button:CreateLine(nil, "OVERLAY", nil, 2))
		line:SetThickness(1.5)
		line:SetStartPoint("RIGHT", button, s[1], s[2])
		line:SetEndPoint("RIGHT", button, s[3], s[4])
		w.chevron[index] = line
	end
	button:SetScript("OnClick", function()
		Run("window", Clicks.picker, w)
	end)
	button:SetScript("OnEnter", function()
		Run("window", Tips.picker, w, button)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	-- The picker covers much of the title bar, so a drag that starts on it moves the window as the bar's does; a drag gives no click, so it opens
	-- no menu.
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function()
		Run("window", DragStart, w)
	end)
	button:SetScript("OnDragStop", function()
		Run("window", Dropped, w)
	end)
end

local function MakeBar(w)
	local frame = w.frame
	local bar = Own(CreateFrame("Frame", nil, frame))
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Run("window", DragStart, w)
	end)
	bar:SetScript("OnDragStop", function()
		Run("window", Dropped, w)
	end)
	-- A drag that ends off the bar still ends. The bar may hear the window's hiding before the window does, so it leaves the game's split box to
	-- the game first (Unsplit).
	bar:SetScript("OnHide", function()
		Unsplit(w)
		if w.moving then
			Run("window", Dropped, w)
		end
	end)
	w.bar = bar
	MakeClose(w)
	MakePicker(w)
	Icon(w, "view", { "sections", "bags" })
	Icon(w, "sort", { "sort" })
	if w.which == "bags" then
		Icon(w, "bank", { "bank" })
	end
	local box = Call(Search, "Box", bar, w.which)
	if type(box) == "table" then
		w.search = box
		pcall(box.SetHeight, box, SEARCH_HEIGHT)
	end
	local rule = Rule(frame)
	rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -BAR)
	rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -BAR)
	w.rules[#w.rules + 1] = rule
	w.barRule = rule
end

-- Lays the title bar out: the close button at the right, the buttons the window shows now left of it, the picker at the left as wide as its text
-- allows, and the search box between them.
function ArrangeBar(w)
	local bar = w.bar
	local ok, width = pcall(w.frame.GetWidth, w.frame)
	width = ok and Finite(width) and width or BOXES[w.which][1]
	w.close.button:ClearAllPoints()
	w.close.button:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	local x = -(4 + CLOSE + 4)
	local _, _, live = Layout.Viewed(w.which)
	local shown = { bank = w.which == "bags", sort = live == true, view = true }
	for _, kind in ipairs({ "bank", "sort", "view" }) do
		local icon = w.icons[kind]
		if icon then
			icon.button:SetShown(shown[kind] == true)
			if shown[kind] then
				icon.button:ClearAllPoints()
				icon.button:SetPoint("RIGHT", bar, "RIGHT", x, 0)
				x = x - ICON - ICON_GAP
			end
		end
	end
	local view = Opt("view") == "bags" and "bags" or "sections"
	local icon = w.icons.view
	SetGlyph(icon.glyphs.sections, view == "sections")
	SetGlyph(icon.glyphs.bags, view == "bags")
	-- What is left between the padding and the buttons, for the picker and the search box.
	local right = width + x + ICON_GAP - 6
	local room = right - PAD
	local most = w.search and math.max(PICKER_LEAST, math.min(room * PICKER_MOST, room - SEARCH_LEAST - 6)) or room
	local picker = math.max(PICKER_LEAST, math.min(w.pickerNeed or PICKER_LEAST, most))
	w.picker:ClearAllPoints()
	w.picker:SetPoint("LEFT", bar, "LEFT", PAD - 4, 0)
	w.picker:SetWidth(picker)
	w.pickerText:SetWidth(math.max(1, picker - 20))
	if w.search then
		w.search:ClearAllPoints()
		w.search:SetPoint("LEFT", w.picker, "RIGHT", 6, 0)
		w.search:SetPoint("RIGHT", bar, "RIGHT", x + ICON_GAP - 6, 0)
	end
end

-- The name in the picker: the character shown in its class colour, with its realm when that is not this character's, then what is shown when it is
-- not live, dim.
function TitleLine(w)
	local which = w.which
	local key, _, live = Layout.Viewed(which)
	local c = CharacterOf(key)
	local text = ClassHex(c and c.class) .. Plain(Named(key, c)) .. "|r"
	local parts = {}
	if which == "bank" then
		parts[#parts + 1] = Word("BANK", "Bank")
	end
	if not live and c then
		local seen = c.seen
		if which == "bank" then
			seen = c.bankSeen
		end
		local asOf = AsOf(seen)
		if asOf then
			parts[#parts + 1] = asOf
		end
	end
	if #parts > 0 then
		text = text .. DIM_HEX .. "  ·  " .. table.concat(parts, "  ·  ") .. "|r"
	end
	w.pickerText:SetWidth(0)
	w.pickerText:SetText(text)
	w.pickerNeed = math.ceil(TextWidth(w.pickerText)) + 4 + 18
	ArrangeBar(w)
end

-- The content and its scroll bar --------------------------------------------------------------------------------------------------------------------

local function Range(w)
	return math.max(0, (w.contentH or 0) - (w.viewH or 0))
end

local function ScrollBar(w)
	local range = Range(w)
	if range <= 0 then
		w.track:Hide()
		return
	end
	local trackH = w.viewH or 0
	local thumbH = math.max(THUMB_LEAST, trackH * trackH / math.max(1, w.contentH))
	local y = (trackH - thumbH) * ((w.offset or 0) / range)
	w.thumb:ClearAllPoints()
	w.thumb:SetPoint("TOPLEFT", w.track, "TOPLEFT", 0, -y)
	w.thumb:SetPoint("TOPRIGHT", w.track, "TOPRIGHT", 0, -y)
	w.thumb:SetHeight(thumbH)
	w.track:Show()
end

function SetOffset(w, offset)
	offset = math.max(0, math.min(Range(w), offset or 0))
	w.offset = offset
	w.scroll:SetVerticalScroll(offset)
	ScrollBar(w)
end

-- The units of a row of the content in the window's own.
local function RowHeight()
	local size = Opt("slotSize")
	if not Finite(size) or size <= 0 then
		size = 36
	end
	return PITCH * size / SLOT
end

local function CursorY(w)
	local ok, _, y = pcall(GetCursorPosition)
	local okScale, scale = pcall(w.frame.GetEffectiveScale, w.frame)
	if ok and okScale and Finite(y) and Finite(scale) and scale > 0 then
		return y / scale
	end
	return nil
end

local function MakeView(w)
	local frame = w.frame
	local scroll = Own(CreateFrame("ScrollFrame", nil, frame))
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		if Finite(delta) then
			SetOffset(w, (w.offset or 0) - delta * WHEEL_ROWS * RowHeight())
		end
	end)
	-- The scroll child is not scaled, so the scroll is in the window's units; the content inside it takes Slot size (BagsLayout.lua).
	local child = Own(CreateFrame("Frame", nil, scroll))
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	local content = Own(CreateFrame("Frame", nil, child))
	content:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
	content:SetSize(1, 1)
	w.scroll, w.child, w.content = scroll, child, content
	-- BagsItems.lua and BagsLayout.lua find the content frame on the window.
	frame.content = content
	local track = Own(CreateFrame("Frame", nil, frame))
	track:SetWidth(TRACK_W)
	track:EnableMouse(true)
	track:Hide()
	w.trackBack = Own(track:CreateTexture(nil, "BACKGROUND"))
	w.trackBack:SetAllPoints(track)
	local thumb = Own(CreateFrame("Frame", nil, track))
	thumb:EnableMouse(true)
	w.thumbBack = Own(thumb:CreateTexture(nil, "ARTWORK"))
	w.thumbBack:SetAllPoints(thumb)
	w.track, w.thumb = track, thumb
	-- A press on the track above or below the thumb scrolls a page that way.
	track:SetScript("OnMouseDown", function()
		local y = CursorY(w)
		local ok, top = pcall(thumb.GetTop, thumb)
		if y and ok and Finite(top) then
			local page = (w.viewH or 0) * 0.9
			SetOffset(w, (w.offset or 0) + (y > top and -page or page))
		end
	end)
	thumb:SetScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			w.drag = { y = CursorY(w), offset = w.offset or 0 }
		end
	end)
	thumb:SetScript("OnMouseUp", function()
		w.drag = nil
	end)
	thumb:SetScript("OnEnter", function()
		w.thumbOver = true
		local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
		w.thumbBack:SetColorTexture(ar, ag, ab, 0.5)
	end)
	thumb:SetScript("OnLeave", function()
		w.thumbOver = false
		local ar, ag, ab = LookRGB("accent", 0.85, 0.85, 0.85)
		w.thumbBack:SetColorTexture(ar, ag, ab, 0.25)
	end)
	w.message = ns.OwnText(frame, "OVERLAY", "GameFontHighlightSmall")
	w.message:SetJustifyH("CENTER")
	w.message:SetPoint("TOP", frame, "TOP", 0, -(BAR + INNER + 14))
	w.message:Hide()
end

-- The drag of the scroll bar's thumb, every frame while it is held.
local function ThumbDrag(w)
	local drag = w.drag
	local y = CursorY(w)
	if not (drag and drag.y and y) then
		return
	end
	local range = Range(w)
	local trackH = w.viewH or 0
	local thumbH = math.max(THUMB_LEAST, trackH * trackH / math.max(1, w.contentH or 1))
	local free = trackH - thumbH
	if free > 0 then
		SetOffset(w, drag.offset + (drag.y - y) * range / free)
	end
end

-- The footer ---------------------------------------------------------------------------------------------------------------------------------------

-- A text of the footer that has a tooltip: a frame of Flat UI's own as wide as its text.
local function FootLabel(w, tip)
	local holder = Own(CreateFrame("Frame", nil, w.foot))
	holder:SetHeight(FOOT)
	holder:EnableMouse(true)
	local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
	text:SetAllPoints(holder)
	text:SetWordWrap(false)
	holder:SetScript("OnEnter", function()
		Run("window", tip, w, holder)
	end)
	holder:SetScript("OnLeave", function()
		Untip(holder)
	end)
	return { frame = holder, text = text }
end

local function GoldTip(w, owner)
	local tip = Tip(owner)
	if not tip then
		return
	end
	local near, total, other, others = {}, 0, 0, 0
	for _, c in ipairs(Characters()) do
		if type(c) == "table" and Finite(c.money) and c.money >= 0 then
			if c.near == true or c.me == true then
				near[#near + 1] = c
				total = total + c.money
			else
				other, others = other + c.money, others + 1
			end
		end
	end
	table.sort(near, function(a, b)
		if a.money ~= b.money then
			return a.money > b.money
		end
		return tostring(a.key) < tostring(b.key)
	end)
	tip:SetText("Gold", 1, 1, 1)
	for index, c in ipairs(near) do
		if index > MOST_GOLD then
			tip:AddLine(("and %d more"):format(#near - MOST_GOLD), DIM[1], DIM[2], DIM[3])
			break
		end
		local r, g, b = ClassRGB(c.class)
		tip:AddDoubleLine(Plain(Named(c.key, c)), Money(c.money), r or 1, g or 1, b or 1, 1, 1, 1)
	end
	if #near > 1 then
		tip:AddDoubleLine("Total", Money(total), DIM[1], DIM[2], DIM[3], 1, 1, 1)
	end
	if others > 0 then
		tip:AddDoubleLine(("Other realms (%d)"):format(others), Money(other), DIM[1], DIM[2], DIM[3], DIM[1], DIM[2], DIM[3])
	end
	if #near == 0 and others == 0 then
		tip:AddLine("Flat UI keeps the gold of each character that logs in with Flat UI bags on.", DIM[1], DIM[2], DIM[3], true)
	end
	-- What the character you play made or spent since it logged in (ns.SessionMoney, BagsData.lua), while the window shows your own bags.
	local _, mine = Layout.Viewed(w.which)
	local okSession, session = pcall(Call, ns, "SessionMoney")
	if mine and okSession and Finite(session) and session ~= 0 then
		tip:AddLine(" ")
		if session > 0 then
			tip:AddDoubleLine("This session", "+" .. Money(session), DIM[1], DIM[2], DIM[3], SESSION_GAIN[1], SESSION_GAIN[2], SESSION_GAIN[3])
		else
			tip:AddDoubleLine("This session", "-" .. Money(-session), DIM[1], DIM[2], DIM[3], SESSION_LOSS[1], SESSION_LOSS[2], SESSION_LOSS[3])
		end
	end
	tip:Show()
end

-- The kinds of bag with room: { label, free, total, general }, the general bags first (B.Data.Free), which take any item and alone count as free
-- space, then each special kind, which takes only certain items; never the keyring.
local function Kinds(w)
	local key = Layout.Viewed(w.which)
	local list = Call(Data, "Free", key, w.which)
	local out = {}
	for _, kind in ipairs(type(list) == "table" and list or {}) do
		if type(kind) == "table" and Finite(kind.free) and Finite(kind.total) and kind.total > 0 then
			local label = kind.label
			if type(label) ~= "string" or IsSecret(label) or label == "" then
				label = type(kind.kind) == "table" and type(kind.kind.label) == "string" and kind.kind.label or "Bags"
			end
			out[#out + 1] = { label = label, free = math.max(0, math.floor(kind.free)), total = math.floor(kind.total), general = kind.general == true }
		end
	end
	return out
end

local function FreeTip(w, owner)
	local tip = Tip(owner)
	if not tip then
		return
	end
	tip:SetText("Free slots", 1, 1, 1)
	local kinds, apart = Kinds(w), false
	for _, kind in ipairs(kinds) do
		if kind.general then
			tip:AddDoubleLine(Plain(kind.label), ("%d of %d"):format(kind.free, kind.total), DIM[1], DIM[2], DIM[3], 1, 1, 1)
		end
	end
	-- A special bag takes only certain items, so its free slots are not in the count: they are named apart, under a line that says so.
	for _, kind in ipairs(kinds) do
		if not kind.general then
			if not apart then
				apart = true
				tip:AddLine(" ")
				tip:AddLine("Not counted, for certain items only", DIM[1], DIM[2], DIM[3])
			end
			tip:AddDoubleLine(Plain(kind.label), ("%d of %d"):format(kind.free, kind.total), DIM[1], DIM[2], DIM[3], 1, 1, 1)
		end
	end
	tip:Show()
end

-- The free slots as the footer may write them, longest first, for ArrangeFoot to take the first that fits: those of the general bags, low in gold
-- and none in red, and the count alone, without the word Free. The special bags are not counted, as they take only certain items (the tooltip
-- names them apart).
local function FreeTexts(w)
	local main
	for _, kind in ipairs(Kinds(w)) do
		if kind.general then
			main = kind
			break
		end
	end
	if not main then
		return { "" }
	end
	local colour = main.free <= 0 and NONE_HEX or (main.free <= LOW and LOW_HEX) or WHITE_HEX
	local count = ("%s%d|r%s/%d|r"):format(colour, main.free, DIM_HEX, main.total)
	return { DIM_HEX .. "Free|r " .. count, count }
end

-- What Sell junk would sell now (ns.ErrandsJunkCount): how many items, how many of the sell list wait for the next click, what they are worth in
-- copper, and true when a price has not loaded, so the worth is at least that.
local function JunkCount()
	local count = ns.ErrandsJunkCount
	if type(count) ~= "function" then
		return 0, 0, 0, false
	end
	local ok, n, waits, value, unknown = pcall(count)
	if not ok then
		return 0, 0, 0, false
	end
	return Finite(n) and math.max(0, math.floor(n)) or 0, Finite(waits) and math.max(0, math.floor(waits)) or 0,
		Finite(value) and math.max(0, math.floor(value)) or 0, not IsSecret(unknown) and unknown == true
end

local function Selling()
	local selling = ns.ErrandsSelling
	if type(selling) ~= "function" then
		return false
	end
	local ok, on = pcall(selling)
	return ok and on == true
end

local function Plural(n, one, many)
	return n == 1 and one or many
end

-- The tooltip of Sell junk: how many items the click sells and what they bring ("for at least" while a price has not loaded; no amount at 0).
local function SellTip(w, owner)
	local n, waits, value = w.sellCount or 0, w.sellWaits or 0, w.sellValue or 0
	local worth = ""
	if value > 0 then
		worth = (w.sellUnknown and " for at least %s" or " for %s"):format(Money(value))
	end
	Say(owner, "Sell junk",
		("Sells %d %s%s, as Errands sells: grey items with a price and the items of your sell list, one at a time."):format(n, Plural(n, "item",
			"items"), worth),
		waits > 0 and ("%d more of your sell list %s for the next click."):format(waits, Plural(waits, "waits", "wait")) or nil)
end

local function SellClick(w)
	local sell = ns.ErrandsSellJunk
	if type(sell) ~= "function" then
		return
	end
	local ok, why = sell()
	if ok == false and type(why) == "string" and why ~= "" and why ~= "busy" then
		print(("Flat UI: Sold nothing: %s."):format(why))
	end
	Request("footer", "bags")
end

-- The pass of BagsBank.lua that runs now: "deposit", "takeout", true for one it does not name, or nil; then how many matching items it has left,
-- and true when each click moves the next one (the fallback of design 6) rather than stopping the pass.
local function Busy()
	local busy, left, perClick = Call(Bank, "Busy")
	left = Finite(left) and math.max(0, math.floor(left)) or 0
	if busy == "deposit" or busy == "takeout" then
		return busy, left, perClick == true
	end
	return busy and true or nil, left, perClick == true
end

local function MoveTip(w, owner, kind)
	local busy, left, perClick = Busy()
	if busy == true or busy == kind then
		if perClick then
			Say(owner, kind == "deposit" and "Deposit" or "Take out", ("Each click moves the next item: %d %s left."):format(left,
				Plural(left, "is", "are")))
		else
			Say(owner, kind == "deposit" and "Deposit" or "Take out", "A click stops it.")
		end
		return
	end
	local n = kind == "deposit" and (w.depositCount or 0) or (w.takeoutCount or 0)
	local items = Plural(n, "item", "items")
	if kind == "deposit" then
		Say(owner, "Deposit", ("Puts the %d %s of your bags that match the search in the bank, one at a time."):format(n, items))
	else
		Say(owner, "Take out", ("Takes the %d %s of the bank that match the search out to your bags, one at a time."):format(n, items))
	end
end

local function MoveClick(w, kind)
	Call(Bank, kind == "deposit" and "Deposit" or "TakeOut")
	Request("footer", "bank")
end

-- A button of the footer (Sell junk, Deposit, Take out): a plate of this file's own, drawn as the title bar's buttons are (PaintPlate), with a label.
-- It is clicked as a button of the game's is, by the left button let go over it, and takes no click while SetUsable says no; SetLabel writes its
-- label, and it hides itself once the question given to Keep, asked every frame while it shows, says it is no longer wanted, whatever missed the
-- end of a merchant or a pass, as Errands.Button's do (Errands.lua:127-201).
local function FootButton(w, text, width, onClick, onEnter)
	local button = Own(CreateFrame("Button", nil, w.foot))
	button:SetSize(width, FOOT_BUTTON)
	button:RegisterForClicks("LeftButtonUp")
	local plate = { button = button, usable = true }
	plate.outline = ns.Outline(button, button)
	plate.hover = Own(button:CreateTexture(nil, "HIGHLIGHT"))
	plate.hover:SetAllPoints(button)
	plate.label = ns.OwnText(button, "OVERLAY", "GameFontHighlightSmall")
	plate.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	plate.label:SetWordWrap(false)
	plate.label:SetText(text)
	button:SetScript("OnClick", function()
		if plate.usable then
			onClick(button)
		end
	end)
	button:SetScript("OnEnter", function()
		onEnter(button)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	-- Hidden under the cursor, it takes its tooltip with it. Hidden by the window's hiding, it may hear that before the window does, so the game's
	-- split box is left to the game first (Unsplit).
	button:SetScript("OnHide", function()
		if not w.frame:IsVisible() then
			Unsplit(w)
		end
		Untip(button)
	end)
	function button.Keep(wanted)
		button:SetScript("OnUpdate", function()
			local ok, keep = pcall(wanted)
			if not ok or not keep then
				button:Hide()
			end
		end)
	end
	function button.SetUsable(on)
		plate.usable = on == true
		PaintPlate(plate)
	end
	function button.SetLabel(words)
		plate.label:SetText(words)
	end
	w.plates[#w.plates + 1] = plate
	PaintPlate(plate)
	return button
end

local function MakeFoot(w)
	local frame = w.frame
	local foot = Own(CreateFrame("Frame", nil, frame))
	foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 0)
	foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 0)
	foot:SetHeight(FOOT)
	w.foot = foot
	local rule = Rule(frame)
	rule:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, FOOT)
	rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOT)
	w.rules[#w.rules + 1] = rule
	w.footRule = rule
	w.free = FootLabel(w, FreeTip)
	w.free.text:SetJustifyH(w.which == "bags" and "RIGHT" or "LEFT")
	-- The row above the footer: the bank bag slots and the Buy button of BagsBank.lua in the bank window, the bag slots of BagsSlots.lua in the bag
	-- window. Hidden until the row gives its height (Slots). A thin line over it, STRIP_GAP from it and from the content, shows and hides with it, so
	-- the bag slots do not read as one more row of the keyring or of the last bag.
	local strip = Own(CreateFrame("Frame", nil, frame))
	strip:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, INNER)
	strip:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, INNER)
	strip:SetHeight(STRIP)
	strip:Hide()
	w.strip = strip
	local stripRule = Rule(strip)
	stripRule:SetPoint("BOTTOMLEFT", strip, "TOPLEFT", 0, STRIP_GAP)
	stripRule:SetPoint("BOTTOMRIGHT", strip, "TOPRIGHT", 0, STRIP_GAP)
	w.rules[#w.rules + 1] = stripRule
	if w.which == "bags" then
		w.gold = FootLabel(w, GoldTip)
		w.gold.text:SetJustifyH("LEFT")
		local sell = FootButton(w, "Sell junk", SELL_W, function()
			Run("window", SellClick, w)
		end, function(button)
			Run("window", SellTip, w, button)
		end)
		sell:Hide()
		-- It hides itself once it is no longer wanted, whatever missed the merchant's closing.
		sell.Keep(function()
			return w.sellOn == true and B.atMerchant == true and Shown(w)
		end)
		w.sell = sell
	else
		for _, kind in ipairs({ "deposit", "takeout" }) do
			local button = FootButton(w, kind == "deposit" and "Deposit" or "Take out", MOVE_W, function()
				Run("window", MoveClick, w, kind)
			end, function(owner)
				Run("window", MoveTip, w, owner, kind)
			end)
			button:Hide()
			button.Keep(function()
				return w.moveOn == true and Call(Bank, "Live") == true and Shown(w)
			end)
			w[kind] = button
		end
	end
end

-- The width of the window, or its box's while the client does not say.
local function WindowWidth(w)
	local ok, width = pcall(w.frame.GetWidth, w.frame)
	return ok and Finite(width) and width or BOXES[w.which][1]
end

-- Writes the first text of the free slots (FreeTexts, kept by Footer) whose width fits in room, else the shortest, which the label cuts.
local function FitFree(w, room)
	local texts = w.freeTexts or { "" }
	for index, words in ipairs(texts) do
		w.free.text:SetText(words)
		if index == #texts or TextWidth(w.free.text) <= room then
			return
		end
	end
end

-- The footer's texts and buttons, left to right: the bag window has its gold at the left, its free slots at the right and Sell junk at the far
-- right; the bank window its free slots at the left and Deposit and Take out at the right. The free slots are written to fit what the others
-- leave (FitFree), also after Resize gives the window its width.
function ArrangeFoot(w)
	local foot = w.foot
	local room = WindowWidth(w) - 2 * PAD
	if w.which == "bags" then
		local gold = w.gold
		local right, gap = foot, 0
		if w.sell and w.sell:IsShown() then
			w.sell:ClearAllPoints()
			w.sell:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
			right, gap = w.sell, -8
			room = room - SELL_W - 8
		end
		local left = foot
		if gold then
			local goldW = math.max(1, math.ceil(TextWidth(gold.text)) + 2)
			gold.frame:ClearAllPoints()
			gold.frame:SetPoint("LEFT", foot, "LEFT", 0, 0)
			gold.frame:SetWidth(goldW)
			left = gold.frame
			room = room - goldW - FOOT_GAP
		end
		-- The currencies of BagsCurrency.lua come after the gold, in what the shortest text of the free slots leaves (B.Currency.Fit gives back its
		-- frame and width).
		local texts = w.freeTexts or { "" }
		w.free.text:SetText(texts[#texts])
		local least = math.max(FREE_ROOM, math.ceil(TextWidth(w.free.text)))
		local coins, coinsW = Call(B.Currency, "Fit", w, room - least - FOOT_GAP)
		if coins and Finite(coinsW) then
			coins:ClearAllPoints()
			coins:SetPoint("LEFT", left, left == foot and "LEFT" or "RIGHT", left == foot and 0 or FOOT_GAP, 0)
			left, room = coins, room - coinsW - FOOT_GAP
		end
		w.free.frame:ClearAllPoints()
		w.free.frame:SetPoint("LEFT", left, left == foot and "LEFT" or "RIGHT", left == foot and 0 or FOOT_GAP, 0)
		w.free.frame:SetPoint("RIGHT", right, right == foot and "RIGHT" or "LEFT", gap, 0)
	else
		local right = foot
		for _, kind in ipairs({ "takeout", "deposit" }) do
			local button = w[kind]
			if button and button:IsShown() then
				button:ClearAllPoints()
				button:SetPoint("RIGHT", right, right == foot and "RIGHT" or "LEFT", right == foot and 0 or -4, 0)
				room = room - MOVE_W - (right == foot and 8 or 4)
				right = button
			end
		end
		w.free.frame:ClearAllPoints()
		w.free.frame:SetPoint("LEFT", foot, "LEFT", 0, 0)
		w.free.frame:SetPoint("RIGHT", right, right == foot and "RIGHT" or "LEFT", right == foot and 0 or -8, 0)
	end
	FitFree(w, room)
end

-- The least width of the footer: room for the buttons the window may show and the gap before them (Sell junk, or Deposit and Take out), for the
-- gold, and for the shortest text of the free slots, whether they show now or not, so the window never changes width as they come and go.
local function FootLeast(w)
	if w.which == "bags" then
		return 2 * PAD + GOLD_ROOM + FOOT_GAP + FREE_ROOM + 8 + SELL_W
	end
	return 2 * PAD + FREE_ROOM + 8 + MOVE_W + 4 + MOVE_W
end

-- Reads the footer again: gold, free slots, and the buttons the window wants now.
function Footer(w)
	local which = w.which
	local key, mine, live = Layout.Viewed(which)
	w.freeTexts = FreeTexts(w)
	if which == "bags" then
		if w.gold then
			local money = Call(Data, "Money", key)
			w.gold.text:SetText(Finite(money) and money >= 0 and Money(money) or "")
		end
		-- The currencies shown on the backpack (BagsCurrency.lua): this character's as the game has them, another's as kept.
		Call(B.Currency, "Read", w, key, mine)
		if w.sell then
			local wanted = mine and live and B.atMerchant == true and Opt("sellButton") ~= false
			local n, waits, value, unknown, selling = 0, 0, 0, false, false
			if wanted then
				n, waits, value, unknown = JunkCount()
				selling = Selling()
			end
			w.sellCount, w.sellWaits, w.sellValue, w.sellUnknown = n, waits, value, unknown
			w.sellOn = wanted and (n > 0 or selling)
			if w.sellOn then
				w.sell.SetLabel(selling and "Selling..." or ("Sell junk (%d)"):format(n))
				w.sell.SetUsable(not selling)
				w.sell:Show()
			else
				w.sell:Hide()
			end
		end
	elseif w.deposit then
		-- A pass that runs keeps its button, to stop it, also once the search is cleared; in the per-click fallback its label counts down instead.
		local on = live and Opt("bankButtons") ~= false
		local busy, left, perClick = nil, 0, false
		if on then
			busy, left, perClick = Busy()
		end
		local wanted = on and Call(Search, "Active") == true
		if wanted then
			w.depositCount = Matches("bags", key, false)
			w.takeoutCount = Matches("bank", key, false)
		else
			w.depositCount, w.takeoutCount = 0, 0
		end
		w.moveOn = on and (wanted or busy ~= nil)
		for _, kind in ipairs({ "deposit", "takeout" }) do
			local button = w[kind]
			local count = kind == "deposit" and w.depositCount or w.takeoutCount
			local running = busy == true or busy == kind
			if on and (running or (wanted and count > 0)) then
				if running and perClick then
					button.SetLabel(("%s (%d)"):format(kind == "deposit" and "Deposit" or "Take out", left))
				elseif running then
					button.SetLabel("Stop")
				else
					button.SetLabel(("%s (%d)"):format(kind == "deposit" and "Deposit" or "Take out", count))
				end
				button:Show()
			else
				button:Hide()
			end
		end
	end
	ArrangeFoot(w)
end

-- How high the row over the footer is, as BagsBank.lua or BagsSlots.lua left it: nothing while it is hidden.
local function StripHeight(w)
	local strip = w.strip
	if not strip or not strip:IsShown() then
		return 0
	end
	local ok, height = pcall(strip.GetHeight, strip)
	if not ok or not Finite(height) or height < 1 then
		return 0
	end
	return height
end

-- What the window says in place of slots: a bank that was never seen.
local function Message(w)
	if w.which ~= "bank" then
		return nil
	end
	local key, mine, live = Layout.Viewed("bank")
	if live then
		return nil
	end
	local c = CharacterOf(key)
	if c and Finite(c.bankSeen) then
		return nil
	end
	if mine then
		return "Visit a banker once with Flat UI bags on, and your bank shows here wherever you are."
	end
	return ("%s has not visited a banker with Flat UI bags on."):format(Plain(Named(key, c)))
end

-- Sizes the window to its layout: as wide as the content and its padding (at least as wide as the title bar and the footer need, and as the bank's
-- row while it shows), as high as the title bar, the content, the bank's row and the footer, at most 85% of the screen, the content scrolling past
-- that. keep: an update of the open window that did not lay it out afresh, which leaves it no shorter than it is (Updating).
function Resize(w, keep)
	local which = w.which
	local cw, ch = Layout.Size(which)
	cw = Finite(cw) and math.max(0, cw) or 0
	ch = Finite(ch) and math.max(0, ch) or 0
	local least = 2 * PAD + PICKER_LEAST + (w.search and (SEARCH_LEAST + 12) or 6) + 3 * (ICON + ICON_GAP) + CLOSE + 8
	least = math.max(least, FootLeast(w))
	local strip = StripHeight(w)
	if strip > 0 then
		least = math.max(least, math.ceil((w.stripW or 0) + 2 * PAD))
	end
	local width = math.max(least, math.ceil(cw + 2 * PAD))
	local fixed = BAR + INNER + INNER + FOOT + (strip > 0 and (strip + 2 * STRIP_GAP) or 0)
	local okScreen, screen = pcall(UIParent.GetHeight, UIParent)
	screen = okScreen and Finite(screen) and screen > 0 and screen or 768
	local most = math.max(fixed + LEAST_VIEW, math.floor(screen * MOST))
	local message = ch <= 0 and Message(w) or nil
	local view
	if ch <= 0 then
		view = message and MESSAGE_VIEW or LEAST_VIEW
	else
		view = math.max(LEAST_VIEW, math.min(math.ceil(ch), most - fixed))
	end
	if keep and Finite(w.viewH) and w.viewH > view then
		-- No shorter than it is, and never past the share of the screen it may take.
		view = math.min(w.viewH, math.max(view, most - fixed))
	end
	w.frame:SetSize(width, fixed + view)
	local left = math.floor((width - cw) / 2 + 0.5)
	w.scroll:ClearAllPoints()
	w.scroll:SetPoint("TOPLEFT", w.frame, "TOPLEFT", left, -(BAR + INNER))
	w.scroll:SetSize(math.max(1, cw), view)
	w.child:SetSize(math.max(1, cw), math.max(1, ch))
	w.viewH, w.contentH = view, ch
	w.track:ClearAllPoints()
	w.track:SetPoint("TOPRIGHT", w.frame, "TOPRIGHT", -2, -(BAR + INNER))
	w.track:SetHeight(view)
	for _, rule in ipairs(w.rules) do
		rule:SetHeight(ns.Pixels(w.frame, 1))
	end
	if message then
		w.message:SetWidth(math.max(1, width - 4 * PAD))
		w.message:SetText(message)
		w.message:Show()
	else
		w.message:Hide()
	end
	SetOffset(w, w.offset)
	ArrangeBar(w)
	ArrangeFoot(w)
end

-- The row over the footer is laid out again in the strip this file gives it, which takes the height the row returns and hides when that is 0;
-- the width it returns is kept (stripW), so the window is never narrower than the row. In the bank window it is BagsBank.lua's row of bank bag
-- slots (B.Bank.Slots), which belongs to the live bank, so it is not asked for while the window shows a snapshot or another character; in the bag
-- window the bag slots of BagsSlots.lua (B.Slots.Row), only while it shows the player's own live bags and Bag slots is on.
local function Slots(w)
	local strip = w.strip
	if not strip then
		return
	end
	local width, height = 0, 0
	local _, mine, live = Layout.Viewed(w.which)
	if live then
		local wide, h
		if w.which == "bank" then
			wide, h = Call(Bank, "Slots", strip)
		elseif mine and Opt("bagSlots") ~= false then
			wide, h = Call(B.Slots, "Row", strip)
		end
		height = Finite(h) and h > 0 and h or 0
		width = Finite(wide) and wide > 0 and wide or 0
	end
	if height > 0 then
		w.stripW = width
		strip:SetHeight(height)
		strip:Show()
	else
		w.stripW = 0
		strip:Hide()
	end
end

-- Each frame while the window shows: the drag of the scroll bar's thumb, the busy sort button, and every half second whether a pass that runs
-- (Sell junk, Deposit, Take out) began or ended.
local function Tick(w, elapsed)
	if w.warming then
		return
	end
	if w.drag then
		Run("window", ThumbDrag, w)
	end
	if Sorting(w) then
		w.pulsing = true
		Run("window", Pulse, w)
	elseif w.pulsing then
		w.pulsing = nil
		Run("window", PaintSort, w)
	end
	w.wait = (w.wait or 0) - (Finite(elapsed) and elapsed or 0)
	if w.wait > 0 then
		return
	end
	w.wait = POLL
	local sign
	if w.which == "bags" then
		sign = w.sellOn and tostring(Selling()) or ""
	else
		sign = w.moveOn and tostring(Busy()) or ""
	end
	if sign ~= (w.sign or "") then
		w.sign = sign
		Run("window", Footer, w)
	end
end

-- Making a window --------------------------------------------------------------------------------------------------------------------------------

local function Make(which)
	local frame = Own(CreateFrame("Frame", NAMES[which], UIParent))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:SetSize(BOXES[which][1], BOXES[which][2])
	frame:Hide()
	local w = { which = which, frame = frame, icons = {}, rules = {}, plates = {}, offset = 0 }
	windows[which] = w
	w.outline = ns.Outline(frame, frame)
	MakeBar(w)
	MakeView(w)
	MakeFoot(w)
	frame:SetScript("OnShow", function()
		Run("window", Showing, w)
	end)
	frame:SetScript("OnHide", function()
		Run("window", Hiding, w)
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		Tick(w, elapsed)
	end)
	if not watcher then
		-- A frame of this file's own on UIParent that takes no mouse and shows nothing: its OnShow is the interface coming back (Missed).
		watcher = Own(CreateFrame("Frame", nil, UIParent))
		watcher:SetSize(1, 1)
		watcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
		watcher:SetScript("OnShow", function()
			Missed()
		end)
	end
	Special(NAMES[which])
	Watching()
	PaintWindow(w)
	TitleLine(w)
	Resize(w)
	Window.Place(which)
	return w
end

-- The work of an opening, also when the warm-up's frame turns into one: the open sound, the look, a fresh layout, the title, the footer, the size.
-- The fresh layout covers what the window was asked to draw while it was closed (items, layout, search, footer, its slots), so Bags.lua lets that
-- go first (B.LaidOut, looked up now and skipped when missing) and the pass after the opening does not draw every slot a second time; what is
-- asked from here on keeps its pass, and so does a change of look, since this paints neither the search boxes nor the buttons.
function Showing(w)
	if w.warming then
		return
	end
	w.open = true
	Run("window", Call, B, "LaidOut", w.which)
	Sound("IG_BACKPACK_OPEN")
	Watching()
	PaintWindow(w)
	Slots(w)
	Run("layout", Layout.Build, w.which)
	w.mode = Mode(w.which)
	w.offset = 0
	TitleLine(w)
	Footer(w)
	Resize(w)
	Window.Place(w.which)
end

-- The window's own part of its hiding, whatever hid it (its close button, a key, Escape, the page going off): a drag ends, the search box lets go of
-- the keyboard, a menu closes, the sort button stops looking busy, and the close sound plays. The bags tidy up in Tidy of Bags.lua, which follows
-- the hiding of a frame of that file's own inside the bag window (and B.HideBags and Release, when the window closed unseen), so this does none of
-- that. The bank window also forgets its places, clears the search when the bag window is not shown and goes back to the logged-in character; its
-- visit to the banker ends in BagsBank.lua. Each step runs alone, so one that fails leaves the others done. quiet: the window closed while the player
-- could not see it (Unseen), which plays no sound.
function Hiding(w, quiet)
	-- First, since the slots may hear the hiding after the window: a slot that owns the game's split box leaves it to the game.
	Unsplit(w)
	if w.warming then
		return
	end
	if w.frame:IsShown() then
		-- Hidden only with its parent (the interface hidden by a movie, the report's screenshot mode or another addon): the window keeps its own
		-- shown flag and is not closed yet, as Tidy of Bags.lua and BagsBank.lua have it, so nothing is tidied, no hold goes and no sound plays; the
		-- game closes it when the interface comes back. Only what cannot outlive the hiding ends: a drag (where it was let go is kept, as the bar's
		-- OnHide keeps it), the search's keyboard and a menu.
		w.drag = nil
		if w.moving then
			Dropped(w)
		end
		if w.search then
			pcall(w.search.ClearFocus, w.search)
		end
		Layout.CloseMenu(w.which)
		return
	end
	w.open, w.drag = false, nil
	if w.moving then
		-- A drag the closing cut short ends as one let go (Dropped): its place is kept and the window hangs from it again, whichever of the window
		-- and its title bar hears the hiding first.
		Run("window", Dropped, w)
	end
	if w.search then
		pcall(w.search.ClearFocus, w.search)
	end
	Layout.CloseMenu(w.which)
	EndBusy(w)
	if w.which == "bank" then
		Run("layout", Layout.Closed, "bank")
		if not Shown(windows.bags) then
			Run("window", Call, Search, "SetText", "")
		end
		Run("window", Call, B, "SetViewing", "bank", nil)
	end
	if not quiet then
		Sound("IG_BACKPACK_CLOSE")
	end
end

-- The closing of a window the player could not see (the interface hidden), which hears no OnHide: this file's own steps, quiet (Hiding), then for
-- the bank window the end of the visit it was the live bank of (B.Bank.Hidden, BagsBank.lua, looked up now and skipped when missing), which
-- BagsBank's hook on the window's OnHide would have run. That runs as plain code outside the parts, as the hook does, so a part that fails here
-- cannot leave the game's bank open behind Bags' hidden frame.
local function Unseen(w)
	Run("window", Hiding, w, true)
	if w.which == "bank" then
		local hidden = Fn(Bank, "Hidden")
		if hidden then
			pcall(hidden)
		end
	end
end

-- The interface came back (the OnShow of the watcher frame, Make). A window the game closed while the interface was hidden heard no OnHide and ran no
-- code of Flat UI's: the game's CloseAllWindows hides the windows of UISpecialFrames (CloseSpecialWindows, UIParentPanelManager.lua:1106-1116 and
-- 1168) also then, at death, at a loss of control and on entering the world (Blizzard_Game/Camelot/EventImplementation.lua:17-20,
-- Shared/EventImplementation.lua:168-174 and 306-307). It closes every window as the interface comes back too (UIParent's OnShow runs it,
-- Blizzard_UIParent/UIParent.lua:5-7 and Blizzard_Game/Shared/Game.lua:91-93), and whether a window it hides then hears its OnHide depends on the
-- order in which the engine tells the frames. A window that was open and is hidden now closes as an unseen one does (Unseen; where the game's
-- CloseAllWindows hid it, its HideUIPanel of BankFrame has ended a visit with Flat UI's bank window already), and the bag window's closing in
-- Bags.lua follows (B.HideBags, whose Tidy finds the bags still open). A window hidden only with its parent is still shown, and one whose OnHide was
-- heard is no longer open, so neither is touched. Escape while the interface is hidden only brings it back (Game.lua:29-37).
function Missed()
	for which, w in pairs(windows) do
		if w.open and not w.warming and not w.frame:IsShown() then
			Unseen(w)
			if which == "bags" then
				Run("window", Call, B, "HideBags")
			end
		end
	end
end

-- The contract (B.Window) -------------------------------------------------------------------------------------------------------------------------

-- The window, made the first time anything asks for it.
function Window.Get(which)
	if which ~= "bags" and which ~= "bank" then
		return nil
	end
	local w = windows[which] or Make(which)
	return w.frame
end

-- Puts the window at its spot in the movers: the bag window's bottom right corner, the bank window's top left. With no spot saved that is where the
-- entry starts, the bag window left of the right action bars (ns.BagsWindowStart). Not while it is dragged, nor while the warm-up keeps it off the
-- screen: the end of the warm-up forgets its place, and the next call here anchors it at its spot and clamps it to the screen again, which the
-- warm-up turned off (Park), only once it stands there, so the clamp never pulls a window that stands off the screen onto its edge.
function Window.Place(which)
	local w = windows[which]
	if not w or w.moving or w.parked then
		return
	end
	local corner = CORNERS[which]
	local x, y
	local anchor = "BOTTOMLEFT"
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(NAMES[which], corner)
	end
	if not (Finite(x) and Finite(y)) then
		x, y = nil, nil
		if w.dropped then
			x, y = w.dropped[1], w.dropped[2]
		end
	end
	if not (Finite(x) and Finite(y)) then
		-- No spot from the movers: the box's own start, from that corner of the screen.
		local box = BOXES[which]
		x, y, anchor = box[3], box[4], corner
		if which == "bags" then
			x, y = ns.BagsWindowStart(x, y)
		end
	end
	local key = ("%s:%.2f:%.2f"):format(anchor, x, y)
	if w.placed == key then
		return
	end
	w.placed = key
	local frame = w.frame
	frame:ClearAllPoints()
	frame:SetPoint(corner, UIParent, anchor, x, y)
	frame:SetClampedToScreen(true)
end

-- Shows the window, laid out afresh. An opening asked for while it is open lays it out again only when it would show something else now (the
-- bank turning live at the banker), so nothing moves for an opening of the game's that finds the bags open.
function Window.Show(which)
	if not On() then
		return
	end
	Window.Get(which)
	local w = windows[which]
	if not w then
		return
	end
	if w.warming then
		w.wantShow = true
		return
	end
	if w.frame:IsShown() then
		if w.mode ~= Mode(which) then
			Request("layout", which)
		end
		return
	end
	Window.Place(which)
	w.frame:Show()
end

-- Gives the search box of a window that shows the keyboard (SetFocus), so the player can type at once; with toggle, a box that has it gives it back
-- (ClearFocus). The bag search key of BagsSearch.lua. True when the window shows.
function Window.Focus(which, toggle)
	local w = windows[which]
	if not (Shown(w) and w.search) then
		return false
	end
	local box = w.search
	local ok, focus = pcall(box.HasFocus, box)
	if toggle and ok and not IsSecret(focus) and focus == true then
		box:ClearFocus()
	else
		box:SetFocus()
	end
	return true
end

-- Hides the window, once a slot that owns the game's split box has left it to the game. A window the player cannot see (the interface hidden) hears
-- no OnHide when it hides, so the steps of its closing run here then, with no sound, and for the bank window the end of its visit (Unseen).
function Window.Hide(which)
	local w = windows[which]
	if not w then
		return
	end
	if w.warming then
		w.wantShow = false
		return
	end
	if w.frame:IsShown() then
		Unsplit(w)
		local visible = w.frame:IsVisible() == true
		w.frame:Hide()
		if not visible then
			Unseen(w)
		end
	end
end

-- What changed for an open window, once a frame (B.Request, Bags.lua): flags is { layout, items, search, footer, look = true }, changed the slots
-- that changed, { [bag] = { [slot] = true } }, or nil for every slot. A hidden window does nothing: it is laid out afresh when it opens, and what
-- was asked for it meanwhile goes then (Showing). Only a fresh layout, asked for or one BagsLayout.lua made itself (B.Layout.Builds counts them),
-- makes the window shorter: the bag window hangs from its bottom right corner, so a shorter window after an update would move everything above
-- what shrank, such as a row of Free slots filled by what arrives (Resize, keep). The bank's row (Slots) is measured again at every update, not
-- only at a layout: it can grow without one, as when BagsBank.lua makes the Buy button at the end of a fight and asks for the footer.
local function Updating(w, flags, changed)
	local which = w.which
	local builds = Call(Layout, "Builds", which)
	if flags.look then
		PaintWindow(w)
		-- The search boxes, and the buttons this layout does not show, take the look of the Windows page too.
		Run("search", Call, Search, "Paint")
		Call(Buttons, "Paint")
	end
	-- The row over the footer first (the bank's bag slots, or the bag slots of the bag window), so its height and width go into the size below.
	Slots(w)
	if flags.layout then
		Run("layout", Layout.Build, which)
		w.mode = Mode(which)
		if w.busy and Now() - w.busy >= BUSY_LEAST then
			EndBusy(w)
		end
		TitleLine(w)
	else
		if flags.items then
			-- While a sort still moves items the window keeps every place: what fills a slot that had no cell waits for the layout after it.
			Run("layout", Layout.Update, which, changed, Sorting(w))
		end
		if flags.search then
			Run("layout", Layout.Dim, which)
		end
		if flags.look then
			Run("layout", Layout.Render, which)
		end
	end
	Footer(w)
	Resize(w, not flags.layout and Call(Layout, "Builds", which) == builds)
	Window.Place(which)
end

function Window.Update(which, flags, changed)
	local w = windows[which]
	if not Shown(w) then
		return
	end
	if type(flags) == "string" then
		flags = { [flags] = true }
	elseif type(flags) ~= "table" then
		flags = { layout = true }
	end
	Run("window", Updating, w, flags, changed)
end

-- The look of the Windows page changed: both windows, their layouts, the search boxes and the buttons take it. (B.Request("look") does the same for
-- the windows that show.)
function Window.Paint()
	for which, w in pairs(windows) do
		PaintWindow(w)
		if Shown(w) then
			Run("layout", Layout.Render, which)
		end
	end
	Run("search", Call, Search, "Paint")
	Call(Buttons, "Paint")
end

-- The warm-up's window stands off the left edge of the screen and is not clamped to it meanwhile, so nothing of it can be seen or reached by the
-- mouse. The end of the warm-up forgets that place, and Window.Place anchors the window at its spot again and clamps it again.
local function Park(w)
	w.parked = true
	w.frame:SetClampedToScreen(false)
	w.frame:ClearAllPoints()
	w.frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -PARK, 0)
end

-- The rest of the end of the warm-up, as the window part. The new buttons the open window showed off the screen: each its layout does not show
-- hides again. Their places were forgotten when they were parked (B.Layout.Park), so the layout's next pass anchors each in its cell. Also when the
-- window closed and warms up again meanwhile. After a warm-up of the hidden window the live buttons go back to the shown flags they had, the
-- window back to its spot, clamped again (Window.Place), and an opening asked for meanwhile turns the shown window into it (Showing).
local function WarmDone(w, warmed, opening, new)
	if new then
		for button in pairs(new) do
			if not Layout.Placed(w.which, button) then
				Unsplit(w, button)
				button:Hide()
			end
		end
	end
	if warmed then
		Call(Buttons, "ShowAll", false)
		Window.Place(w.which)
		if opening then
			Showing(w)
		end
	elseif Shown(w) then
		Run("layout", Layout.Render, w.which)
	end
end

-- The end of the warm-up, on the next frame, as plain code with no part around it: a part that stopped meanwhile (and Release then hid the window
-- itself) or a step that failed must not leave the window warming, since every opening would wait for this end (Window.Show) while the game's
-- bags stay hidden. Unless an opening came for a window the warm-up did show, the window hides first, while it is still marked as warming, so its
-- OnHide does none of a closing's work; then the warm-up's state and its place go, so the next Window.Place anchors the window at its spot; the
-- rest runs as the window part (WarmDone).
local function WarmEnd(w)
	w.warmQueued = false
	local warmed = w.warming == true
	local opening = false
	if warmed and w.wantShow == true and w.frame:IsShown() then
		local ok, on = pcall(On)
		opening = ok and on == true
	end
	if warmed and not opening then
		pcall(Unsplit, w)
		pcall(w.frame.Hide, w.frame)
	end
	w.warming, w.wantShow = false, false
	if w.parked then
		w.parked, w.placed = nil, nil
	end
	local new = w.warmButtons
	w.warmButtons = nil
	Run("window", WarmDone, w, warmed, opening, new)
end

-- The live buttons of the bag window that its layout does not show.
local function Unplaced(w)
	local list = {}
	local key = Layout.Viewed("bags")
	local bags = Call(Data, "Containers", "bags", key)
	for _, bag in ipairs(type(bags) == "table" and bags or {}) do
		local slots = Call(Data, "Size", key, bag)
		for slot = 1, Finite(slots) and slots or 0 do
			local button = Call(Buttons, "Live", bag, slot)
			if type(button) == "table" and not Layout.Placed("bags", button) then
				list[#list + 1] = button
			end
		end
	end
	return list
end

-- The steps of a warm-up that show things.
local function WarmStart(w, buttons)
	if w.warming then
		-- A warm-up is under way: the buttons made since show with it.
		Call(Buttons, "ShowAll", true)
		return
	end
	if not w.frame:IsShown() then
		w.warming, w.wantShow = true, false
		Park(w)
		Layout.Adopt("bags")
		w.frame:Show()
		Call(Buttons, "ShowAll", true)
	else
		w.warmButtons = w.warmButtons or {}
		Layout.Adopt("bags")
		for _, button in ipairs(type(buttons) == "table" and buttons or Unplaced(w)) do
			if type(button) == "table" and not Layout.Placed("bags", button) then
				Layout.Park(button)
				button:Show()
				w.warmButtons[button] = true
			end
		end
	end
end

-- A warm-up: its steps run protected, and its end is queued after them whatever they did, so a step that fails still has the warm-up end on the
-- next frame (WarmEnd); the failure is raised again once the end is queued, so it still counts toward stopping the window part.
local function Warming(w, buttons)
	local ok, err = pcall(WarmStart, w, buttons)
	if not w.warmQueued then
		w.warmQueued = true
		After(0, function()
			WarmEnd(w)
		end)
	end
	if not ok then
		error(err, 0)
	end
end

-- After BagsItems.lua made some of the game's item buttons: each shows once inside the bag window before any fight can need it. The game's source
-- shows no need for it, so it is a precaution, for the potion a fight needs most. Only the bag window has such buttons, and nothing shows while
-- Bags is off, stopped or stood down (BagsItems keeps the buttons for the next warm-up then).
function Window.Warm(which, buttons)
	if which ~= "bags" or not On() then
		return
	end
	Window.Get("bags")
	Run("window", Warming, windows.bags, buttons)
end

-- Movers ------------------------------------------------------------------------------------------------------------------------------------------

-- The left and right edges of a game frame while it shows, in UIParent's units, read with widget calls only (IsVisible, GetLeft, GetRight,
-- GetEffectiveScale), each answer through ns.IsSecret or ns.Finite; nil for a frame that is missing, forbidden or hidden, or does not say.
local function BarEdges(name)
	local frame = _G[name]
	if ns.Forbidden(frame) then
		return nil
	end
	local okShown, shown = pcall(frame.IsVisible, frame)
	if not okShown or IsSecret(shown) or shown ~= true then
		return nil
	end
	local okLeft, left = pcall(frame.GetLeft, frame)
	local okRight, right = pcall(frame.GetRight, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okLeft and okRight and okScale and okBase and Finite(left) and Finite(right) and Finite(scale) and Finite(base)) or base <= 0 then
		return nil
	end
	local k = scale / base
	return left * k, right * k
end

-- Whether Edit Mode has a bar in its place: the table it keeps on the bar, systemInfo, and its isInDefaultPosition, which the game reads for the
-- same purpose (IsInitialized and IsInDefaultPosition, Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:428-430, 882-884), read here as fields
-- with rawget, with no method of the bar's called, each through ns.IsSecret. Only a flag that is plainly false says no: a bar the player dragged or
-- nudged in Edit Mode (EditModeManager.lua:316-375).
local function InPlace(name)
	local frame = _G[name]
	if ns.Forbidden(frame) then
		return false
	end
	local okInfo, info = pcall(rawget, frame, "systemInfo")
	if not okInfo or IsSecret(info) or type(info) ~= "table" then
		return true
	end
	local okFlag, flag = pcall(rawget, info, "isInDefaultPosition")
	return not (okFlag and not IsSecret(flag) and flag == false)
end

-- How far in from the right edge of the screen the right action bars reach, in UIParent's units, or 0. A bar counts while it shows and Edit Mode has
-- it in its place (InPlace), as the game counts only those (GetBarsLayoutSize, Blizzard_EditMode/Shared/EditModeUtil.lua:39-69), and while its
-- right edge stands at the edge of the screen, or at the left edge of a bar that counts, give or take BAR_SLACK, as Edit Mode stacks them there
-- (EditModeManager.lua:598-636). So a bar the player moved in Edit Mode does not count, also when it stands along the right edge, nor one something
-- else moved away from that edge.
local function RightBarsRoom()
	local ok, screen = pcall(UIParent.GetRight, UIParent)
	if not ok or not Finite(screen) then
		return 0
	end
	local bars = {}
	for _, name in ipairs(RIGHT_BARS) do
		local left, right = BarEdges(name)
		if left and right > left and InPlace(name) then
			bars[#bars + 1] = { left = left, right = right }
		end
	end
	table.sort(bars, function(a, b)
		return a.right > b.right
	end)
	local edge = screen
	for _, bar in ipairs(bars) do
		if math.abs(bar.right - edge) <= BAR_SLACK then
			edge = math.min(edge, bar.left)
		end
	end
	return math.max(0, screen - edge)
end

-- Where the bag window starts while no spot is saved for it, from the x and y of its entry in Movers.lua, which asks (start = "BagsWindowStart") for
-- the window and its box alike: as the game's bags open, BAR_ROOM left of the right action bars that show in their place
-- (GetInitialContainerFrameOffsetX, Mainline/ContainerFrame.lua:1320-1326, with EditModeUtil:GetRightActionBarWidth,
-- Blizzard_EditMode/Shared/EditModeUtil.lua:65-69), and never nearer the edge of the screen than the entry's x. The window follows a change of the
-- bars when it is next placed (Window.Place).
function ns.BagsWindowStart(x, y)
	if not Finite(x) then
		return x, y
	end
	local room = RightBarsRoom()
	if room > 0 then
		x = math.min(x, -(room + BAR_ROOM))
	end
	return x, y
end

-- The windows have a handle in the movers while Bags is on, open or not, as the other frames of Flat UI's own have one while their page is on.
function ns.BagsWindowShown()
	return On()
end

function ns.BankWindowShown()
	return On()
end

-- The movers set or put back a spot: the window hangs from it now.
function ns.BagsWindowMoved()
	local w = windows.bags
	if w then
		w.placed, w.dropped = nil, nil
		Run("window", Window.Place, "bags")
	end
end

function ns.BankWindowMoved()
	local w = windows.bank
	if w then
		w.placed, w.dropped = nil, nil
		Run("window", Window.Place, "bank")
	end
end

-- The buttons of the title bar ------------------------------------------------------------------------------------------------------------------

-- The character picker: every character Bags keeps, by realm, this realm and the connected ones first; the one shown is ticked. While a search is
-- typed, the menu's title names it and each line fills in how many items match there, one character a frame.
function Clicks.picker(w)
	local which = w.which
	local viewed = Layout.Viewed(which)
	local me = Call(B, "Me")
	local groups, order, myRealm = {}, {}, nil
	for _, c in ipairs(Characters()) do
		if type(c) == "table" and type(c.key) == "string" and not IsSecret(c.key) then
			local realm = RealmOf(c)
			if c.me == true or c.key == me then
				myRealm = realm
			end
			local group = groups[realm]
			if not group then
				group = { realm = realm, near = false, list = {} }
				groups[realm] = group
				order[#order + 1] = group
			end
			group.near = group.near or c.near == true or c.me == true
			group.list[#group.list + 1] = c
		end
	end
	table.sort(order, function(a, b)
		if (a.realm == myRealm) ~= (b.realm == myRealm) then
			return a.realm == myRealm
		end
		if a.near ~= b.near then
			return a.near
		end
		return a.realm < b.realm
	end)
	local items, jobs = {}, {}
	for _, group in ipairs(order) do
		table.sort(group.list, function(a, b)
			local am, bm = a.key == me, b.key == me
			if am ~= bm then
				return am
			end
			return NameOf(a.key, a) < NameOf(b.key, b)
		end)
		items[#items + 1] = { text = Plain(group.realm), header = true }
		for _, c in ipairs(group.list) do
			local level = Finite(c.level) and ("  " .. DIM_HEX .. math.floor(c.level) .. "|r") or ""
			local key = c.key
			items[#items + 1] = { text = ClassHex(c.class) .. Plain(NameOf(key, c)) .. "|r" .. level, tick = key == viewed, part = "window",
				pick = function()
					Call(B, "SetViewing", which, key ~= me and key or nil)
					Request("layout", which)
					TitleLine(w)
				end }
			jobs[#jobs + 1] = { index = #items, key = key }
		end
	end
	if #jobs == 0 then
		return
	end
	local searching = Call(Search, "Active") == true
	local title = "Characters"
	if searching then
		local text = Call(Search, "Text")
		text = type(text) == "string" and not IsSecret(text) and text or ""
		-- The search keeps a typed bar as "||" (BagsSearch.lua): the bar the player typed is cut and then written once, as Plain writes any bar.
		text = (text:gsub("||", "|"))
		if #text > 24 then
			-- Cut before a whole character: a byte from 128 to 191 continues the one before it.
			local cut = 24
			while cut > 1 and text:byte(cut) >= 128 and text:byte(cut) < 192 do
				cut = cut - 1
			end
			text = text:sub(1, cut - 1) .. "..."
		end
		title = ("Items matching %s"):format(Plain(text))
	end
	local menu = Layout.Menu(w.picker, title, items, which)
	if not (menu and searching) then
		return
	end
	for _, job in ipairs(jobs) do
		Layout.MenuRight(job.index, "...")
	end
	local step = 1
	menu.tick = function()
		local job = jobs[step]
		if not job then
			menu.tick = nil
			return
		end
		step = step + 1
		local n = Matches(which, job.key, true)
		Layout.MenuRight(job.index, n > 0 and (WHITE_HEX .. n .. "|r") or "0")
	end
end

function Tips.picker(w, owner)
	if Layout.MenuOn(owner) then
		return
	end
	if w.which == "bank" then
		Say(owner, "Characters", "Choose a character to see their bank, as it was last seen.")
	else
		Say(owner, "Characters", "Choose a character to see their bags, as they were last seen.")
	end
end

function Clicks.view(w)
	local view = Opt("view") == "bags" and "sections" or "bags"
	ns.Set("bags.view", view)
	Request("layout", nil)
	ArrangeBar(w)
end

function Tips.view(w, owner)
	if Opt("view") == "bags" then
		Say(owner, "Bag by bag", "Each bag in turn, as the game shows them.", "Click for Sections.")
	else
		Say(owner, "Sections", "Items grouped by kind.", "Click for Bag by bag.")
	end
end

-- The sort button: the game's clean up, through BagSort, with its sound. It takes no click while the last sort is still moving items.
function Clicks.sort(w)
	if Sorting(w) then
		return
	end
	local sort = ns.BagSort
	local run = type(sort) == "table" and sort.Run or nil
	if type(run) ~= "function" then
		return
	end
	if run(w.which) then
		local sound = sort.Sound
		if type(sound) == "function" then
			sound()
		end
		if not watching and w.which == "bags" then
			Sorted("bags")
		end
	end
end

function Tips.sort(w, owner)
	local title = w.which == "bank" and Word("BAG_CLEANUP_BANK", "Clean Up Bank") or Word("BAG_CLEANUP_BAGS", "Clean Up Bags")
	if Sorting(w) then
		Say(owner, title, "Sorting: the window is laid out again once your items have stopped moving.")
	else
		Say(owner, title)
	end
end

-- The bank button: the bank of the character the bag window shows (B.Bank.Toggle), live at the banker while Flat UI's bank window is the live
-- bank of the visit (B.Bank.Live), and as last seen anywhere else, and also at the banker with the game's bank window, which is the live one then.
function Clicks.bank(w)
	local key, mine = Layout.Viewed("bags")
	Call(Bank, "Toggle", (not mine) and key or nil)
end

-- Which bank window is the live one at the banker: during a visit the one it started with (B.Bank.Live, which a change of At the banker meanwhile
-- does not change), else the one At the banker names.
function Tips.bank(w, owner)
	local key, mine = Layout.Viewed("bags")
	local game
	if Call(Bank, "Visiting") == true then
		game = Call(Bank, "Live") ~= true
	else
		game = Opt("bank") == "game"
	end
	if mine and game then
		Say(owner, Word("BANK", "Bank"), "Your bank as you last left it. At the banker the game's bank window is the live one.")
	elseif mine then
		Say(owner, Word("BANK", "Bank"), "Your bank: live at the banker, and as you last left it anywhere else.")
	else
		Say(owner, Word("BANK", "Bank"), ("The bank of %s, as it was last seen."):format(Plain(Named(key, CharacterOf(key)))))
	end
end
