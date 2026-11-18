local _, ns = ...

-- The Gear comparison window (design 2.7): the part "gear window" of Chat and tooltips, a small window of Flat UI's own, FlatUIGear, with the whole
-- profile of the spells chosen for the gear comparison (ns.GearChosen, GearLines.lua), each now and with an item, as a cast, a second or threat. It is
-- the place to drop items and spells on, and it works with Your spells in item tooltips off: it is a tool of its own, and the list rows of the Spells
-- and gear tab serve both. /flatui gear and the tab's Gear comparison window row open and close it (ns.GearWindowToggle), /flatui gear <item> shows
-- that item in it (ns.GearWindowShow), and Escape closes it; the item and the switch are kept for the session.
-- A fight is InCombatLockdown's answer (WL/apis.yaml:39650), a withheld one counting as a fight; the time of a spell dropped is GetTime's (:39050).
-- Everything runs as the part "gear window" of the chat module (ns.EachPart, Core.lua:2168-2199), each run with a count of its own as its first
-- argument, so three faults stop the window alone with a line for /flatui status (design 4.4); the first fault also goes to the game's error handler
-- (geterrorhandler), as Bags' parts report theirs (Bags.lua:356-374), and a part that stopped closes the window. The files it reads, SpellModel.lua,
-- GearModel.lua and GearLines.lua, are looked up when called, since any of them may load after this one or fail; a fault of one of their functions
-- goes to the error handler once, and the window goes on with what the other lines give. M.Want("gear window") has SpellModel listen to the game's
-- events while the window shows and lets go when it hides; M.State and M.Stats first read what an event marked (design 4.3, 4.5).
-- The look is the Windows page's, as Bags' windows have it (BagsWindow.lua:499-552): the Background colour at Window opacity with a thin border in the
-- general border colour (ns.Outline, whose page is the Windows page, so the chat page's own border does not reach it, Core.lua:296), the icon's box in
-- Button and slot colour, the chosen word of the switch and the light under the cursor in the Highlight colour, the icon cut by Icon crop
-- (SetTexCoord), and the text of the windows (PanelLook.lua:27-28) in font strings of Flat UI's own (ns.OwnText), measured as they wrap
-- (GetUnboundedStringWidth, GetStringHeight, WL/uiobjects.yaml:3738, 3711) so the window is as tall as what it shows. ns.GearWindowSync, at the end of
-- each refresh of Chat.lua, closes the window while the module or the part is off and paints it again after a change of those rows, which refresh the
-- chat module (Core.lua, READERS).
-- Tooltips are GameTooltip, never in a fight, as Bags' item tooltips wait (Core.lua:146): SetOwner, AddLine for this window's lines, Show, and Hide only
-- while a frame of the window owns it (IsOwned); a line's own spell (SetSpellByID, Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:560) and the
-- item (SetHyperlink, :590) come from secure accessors of the game's tooltip data (:488-519), which answer true when they built one.
-- The numbers are GearModel's, so the window and the item tooltips agree, written as design 2.3 rounds them: a cast whole from 100 up and with one
-- decimal below, a second with one decimal, the change in green for a gain, red for a loss and grey for none, with its percent, and ~ first for an
-- estimate.
-- The item: its name in its quality colour from the link, which needs nothing loaded, else from C_Item.GetItemInfo (WL/apis.yaml:16525) and the
-- game's colour of its quality (ColorManager.GetColorDataForItemQuality, Blizzard_Colors/Mainline/ColorManager.lua:52-60, which has every quality,
-- else C_Item.GetItemQualityColor, WL/apis.yaml:16726); its icon from C_Item.GetItemInfoInstant (:16569), which never waits. An item the client has
-- not loaded is asked for once (C_Item.RequestLoadItemDataByID, :17160), as Bags asks (BagsData.lua:1649), and the next look finds it. What it would
-- take the place of is named from the worn items SpellModel read (S.state.links), else GetInventoryItemLink (:36977). The name of a line is
-- GearLines.lua's, else the game's (C_Spell.GetSpellName, :26753); the role is S.state's, else ns.PlayerRole's, and the level S.state's, else
-- UnitLevel's (:43168).
-- Working it out: with an item G.Compare (the slots it would take, each line now and with it), with none G.Expect of each line in the figure G.Figure
-- gives it for the switch (design 4.3), with the rows of the tab and G.Inputs. It is worked out again out of combat only, when SpellModel's version
-- (M.Version: the state, the stats, talents, gear, role and the rows of the tab), the version of the list (ns.GearListVersion), the switch or the item
-- changed, looked at every half second while it shows; in a fight it keeps its numbers and its foot says the stats are from before the fight. A drop,
-- the switch and a line taken off are worked out at once, also in a fight, where GearModel gives what it worked out before it (design 4.7).
-- Placing: the window hangs by its top left corner from its spot in the movers (ns.MoverSpot, Movers.lua:856-877), growing down as lines come.
-- Dragging its title bar moves it (StartMoving and StopMovingOrSizing, WL/uiobjects.yaml:4797, 4813, with SetUserPlaced, :4778, so the client keeps no
-- place of its own), and where it is let go is saved as its spot: the box of its entry in Movers.lua, its top left corner at the window's (GetRect and
-- GetEffectiveScale), goes to ns.MoverKit.Commit (Movers.lua:1713-1753). Movers asks ns.GearWindowShown whether it has a handle and calls
-- ns.GearWindowMoved when its spot is set or put back.
-- Drops: what the cursor holds is GetCursorInfo's (WL/apis.yaml:36258). A spell is added to the list (ns.GearAdd, which says what it did): its ID is
-- GetCursorInfo's fourth answer, the second being its slot (Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua:137;
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:1953-1955), and a macro's is the spell it casts (GetMacroSpell, WL/apis.yaml:37417), as
-- Cooldowns reads a macro's (Cooldowns.lua:2571-2579). The cursor keeps the spell: one dragged off an action bar has left its slot already, and
-- ClearCursor would take it off the bar. An item dropped or clicked on the window is compared, and ClearCursor (:34956, not protected) puts it back
-- where it came from, also in a fight, as Bags' sections give a dropped item back (BagsLayout.lua:1408-1425). A right click takes a line off the list
-- (ns.GearRemove). While the cursor holds an item or a spell, the part of the window that takes it is lit, looked at ten times a second, as Bags
-- lights the titles that take an item (BagsLayout.lua:40-45).
-- The frame: CreateFrame on UIParent, named FlatUIGear, made the first time it opens and only out of combat (an opening asked for in a fight before
-- that waits for its end, ns.OutOfCombat), in the MEDIUM strata among the game's windows, raised when clicked (SetToplevel, WL/uiobjects.yaml:4770),
-- kept on the screen (SetClampedToScreen) and placed by Flat UI alone (SetMovable, SetDontSavePosition, :4605). The mouse wheel scrolls its lines when
-- there are more than it holds (EnableMouseWheel, :7184). Its name goes once into UISpecialFrames, whose windows the game's CloseSpecialWindows hides
-- on Escape (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:21-27, 1104-1116). It adds a line to /flatui status while it is open with
-- an item (ns.AddStatus, design 4.12).
-- It registers no event: it looks on the OnUpdate of its own frame while it shows. Every frame, texture and font string here is Flat UI's own.

local KEY, PART = "chat", "gear window"
-- The owner M.Want knows the window by, and the window's name, which the movers and UISpecialFrames know it by.
local OWNER, NAME = "gear window", "FlatUIGear"
-- The box of the window's entry in Movers.lua, and where it starts while no spot is saved: its top left corner this far from the top left corner of
-- the screen, right of the Character window (design 5.1).
local BOX = { width = 420, height = 220, x = 380, y = -120 }
-- Units: the width of the window and its padding on each side; the title bar, its close cross, a word of the switch, the room around the text of one
-- and between two; the icon of the item and the space after it; the column heads and a line of the table (design 2.7: a row 18 high a line); the
-- space between two parts, between two dim lines and before a cell's neighbour; and a line of small text when the client does not say.
local L = { WIDTH = 420, PAD = 8, BAR = 26, CLOSE = 18, WORD = 18, WORD_ROOM = 10, WORD_GAP = 9, ICON = 30, ICON_GAP = 8, HEAD = 16, ROW = 18,
	GAP = 6, LINE_GAP = 2, CELL_GAP = 6, LINE = 12 }
L.INNER = L.WIDTH - 2 * L.PAD
-- The columns of the table (design 2.7), left to right: the cell, its head, its width and how its text is aligned, and for a change the slot of the
-- comparison it shows (%s in its head is that slot). The widths fill the room inside the padding, so the window keeps its width whichever columns
-- show: with no item the spell and what it does now; with an item that takes one slot, what it does with the item and the change; with an item that
-- can take either of two slots (rings, trinkets, a one-hand weapon of a dual wielder), the change in each and no With. The design's Change is 110
-- and its two changes 100 each; they are 114 and 92 here, so both tables are as wide as the window inside its padding.
local COLUMNS = {
	none = { { "name", "Spell", 150, "LEFT" }, { "now", "Now", 70, "RIGHT" } },
	one = { { "name", "Spell", 150, "LEFT" }, { "now", "Now", 70, "RIGHT" }, { "with", "With", 70, "RIGHT" }, { "change", "Change", 114, "RIGHT", 1 } },
	two = { { "name", "Spell", 150, "LEFT" }, { "now", "Now", 70, "RIGHT" }, { "change", "Change %s", 92, "RIGHT", 1 },
		{ "change", "Change %s", 92, "RIGHT", 2 } },
}
-- The three figures of the switch in the title bar (design 2.3), left to right, and what each says when pointed at.
local MODES = { { "cast", "A cast" }, { "second", "A second" }, { "threat", "Threat" } }
local WORD_TIPS = {
	cast = "What one cast does: its expected damage or healing, or its threat for a line that does no damage. Your auto attack, Auto Shot and wand count one swing or shot.",
	second = "What a second does: a cast over its cast time (at least the global cooldown), a spell over time over its duration, your swings and shots over their speed. A strike that takes the place of your next swing has none.",
	threat = "The threat of one cast, and of a second of your auto attack, with your stance, form, Righteous Fury and talents.",
}
-- Against at its first choice is a boss three levels above at the top level, else an enemy of the player's level (design 2.5, 4.9). The hit caps of
-- Hit cap against a boss and of the hit table's row of the same name (Config.lua, hud.hitTableRules).
local MAX_LEVEL = 60
local CAPS = { classic = "9% melee, 16% spells", game = "8% melee, 17% spells" }
-- The slots by their number (INVSLOT_AMMO to INVSLOT_TABARD), as the comparison names them (design 2.3, 2.4).
local SLOTS = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
	"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" }
-- The comparison kinds whose cast is a swing or a shot (design 2.3): Attack, Auto Shot and Shoot with a wand.
local SWINGS = { auto = "a swing", shot = "a shot", wand = "a shot" }
-- The forms whose swing a weapon ability counts its attack power at (GetShapeshiftFormID: Cat Form 1, Bear Form 5, Dire Bear Form 8, as D.RULES has
-- them), the slot of each hand of a weapon part (design 3.2), and the normalized and form speeds when the data gives none (D.MODEL, SpellData.lua).
local FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }
local HANDS = { main = 16, off = 17, both = 16, ranged = 18 }
local NORM, SWING = { one = 2.4, dagger = 1.7, two = 3.3, ranged = 2.8 }, { cat = 1.0, bear = 2.5 }
-- Seconds between two looks at what the window was worked out from, and at the cursor; how soon the same spell again counts as the same drop (the
-- click that ends a drag on the window).
local TICK, LOOK, DROP_AGAIN = 0.5, 0.1, 0.3
-- The dim lines the window holds under its table (the item's notes) and in its foot, the most lines it shows at once, and the separators' opacity.
local NOTES, FOOT, MOST_ROWS = 10, 7, 16
local SEPARATOR = 0.07
local FONT, TITLE_FONT = "GameFontHighlightSmall", "GameFontHighlight"
-- The text of the windows (PanelLook.lua:27-28: text-dim and text-faint of graphite, as the Threat list and the hit table have them) and white; the
-- grey of Flat UI's extra tooltip lines (Chat.lua:793) for no change, and the green and red Flat UI's combat numbers give a gain and a loss
-- (CombatText.lua:889-894), as the item tooltips colour a change (design 2.3).
local DIM, FAINT, PLAIN = { 0.66, 0.68, 0.62 }, { 0.48, 0.50, 0.45 }, { 1, 1, 1 }
local TONES = { gain = { 0.1, 1, 0.1 }, loss = { 1, 0.1, 0.1 }, none = { 0.8, 0.8, 0.8 } }
-- The words of the window. Flat UI's lines are English, as its other extra lines (design 6.22).
local T = {
	TITLE = "Gear comparison",
	DROP = "Drop an item here, or type /flatui gear and shift-click an item into the chat line.",
	EMPTY = "Drag a spell from your spell book onto this window.",
	NO_MODEL = "The spell data of Chat and tooltips is not running, so there is nothing to work out. /flatui status says why.",
	NO_LIST = "The list of spells of Chat and tooltips is not running, so there is nothing to show. /flatui status says why.",
	NO_ADD = "Gear comparison: the list of spells is not running, so the spell was not added.",
	LOADING = "The game has not loaded this item yet.",
	NOT_COMPARED = "This item is not compared with what you wear.",
	NOT_YET = "Not wearable yet.",
	NOT_YET_LINE = "Not wearable yet: ",
	NOT_COUNTED_LINE = "Not counted: ",
	NO_CHANGE = "No change to your chosen spells; stamina, armor, avoidance and mana are not counted.",
	RANDOM = "Random stats not known.",
	IN_PLACE = "in place of %s (%s)",
	IN_EMPTY = "in your empty %s slot",
	EMPTY_HANDS = "in your empty hands",
	BOTH = "both hands",
	SLOT = "its slot",
	AGAINST_BOSS = "Against a boss three levels above you, %s; hit cap: %s.",
	AGAINST_LEVEL = "Against an enemy of your level, %s.",
	FRONT = "from the front",
	BEHIND = "from behind",
	BEFORE = "Before armor, resistances, and talents and buffs your stats do not show: talents that turn one stat into another or add crit to one school too.",
	NOT_COUNTED = "Not counted: procs, use effects, set bonuses; enchants as the game's item stats count them.",
	ESTIMATE = "~ marks an estimate.",
	OLD = "Your stats from before the fight.",
	NO_STATS = "The game has not given your stats yet, so the numbers wait for them.",
	SCROLL = "Lines %d to %d of %d; the mouse wheel scrolls them.",
	MORE = "And %d more.",
	RANK = "%s Rank %d",
	NOT_KNOWN = "not known",
	SWING_NONE = "takes a swing's place",
	SPEED_FORM = "%s at %s's %.1f sec swing.",
	SPEED_NORM = "%s as a %.1f sec %s.",
	SPEED_OWN = "%s at your weapon's own speed, %.2f sec.",
	SPEED_ANY = "%s at your weapon's own speed.",
	CAT = "Cat Form",
	BEAR = "Bear Form",
	POWER = "Attack power",
	RANGED_POWER = "Ranged attack power",
	MEASURED = "Measured in the game.",
	ESTIMATED = "~ An estimate.",
	NEXT_SWING = "It takes the place of your next swing, so it has no second of its own.",
	UNKNOWN = "You do not know this spell now.",
	REMOVE = "Right-click to take it off the comparison.",
	CLEAR = "Right-click to compare no item.",
	OFF = "Gear comparison: turn on Restyle chat and tooltips on the Chat and tooltips page first.",
	MODULE_STOPPED = "Gear comparison: Chat and tooltips stopped after an error. /flatui status says why.",
	STOPPED = "Gear comparison: the window stopped after an error. /flatui status says why.",
	AFTER_FIGHT = "Gear comparison: the window opens when the fight ends.",
	STATUS = "Gear comparison window: open, comparing %s.",
	REPORT = "Flat UI, Gear comparison window, %s: %s",
}
-- The noun of each kind of weapon a normalized part counts as (design 2.5: dagger 1.7, other one-hand 2.4, two-hand 3.3, ranged 2.8).
local WEAPONS = { one = "one-hand weapon", dagger = "dagger", two = "two-hand weapon", ranged = "ranged weapon" }

local IsSecret = ns.IsSecret

-- The state of the window. frame: FlatUIGear, made the first time it opens, and outline its background and border. bar, title, words (the switch),
-- seps, close; item: the area of the item (button, box, outline, icon, name, place, hint, hover, light); headRow and heads; rows, each { button,
-- hover, cells, row }; message; notes and foot, the pools of dim lines; rules; tableLight; owners: the frames whose tooltip the window writes.
-- mode: the figure of the switch; chosen: the player picked it, so it is kept for the session. link: the item compared, kept for the session.
-- view: what Compute worked out and Paint draws; drawn: the key it was worked out for; fight: it was drawn in a fight; dirty: a row of the chat
-- module changed. offset: the first line shown when there are more than MOST_ROWS. wanted: M.Want has the window. opening, queued: an opening
-- asked for in a fight before the frame was made waits for the fight's end. moving, placed, dropped: a drag of the title bar, the spot the window
-- was put at, and where it was let go while the movers could not keep it. runs: the count of the part's runs. faults: what went to the error handler
-- already. requested: the items the client was asked to load. elapsed, looked: the time since the last look at the view and at the cursor.
-- spell, spellAt: the last spell dropped, and when.
local W = { mode = "cast", chosen = false, offset = 0, runs = 0, faults = {}, requested = {}, elapsed = 0, looked = 0, words = {}, rows = {},
	notes = {}, foot = {}, rules = {}, owners = {} }

local Refresh, Paint, PaintLook, Close, Drop, Place, Dropped

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Finite(value)
	return ns.Finite(value)
end

-- A plain string with something in it, or nil.
local function Text(value)
	if not IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function Byte(value)
	return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
end

local function Hex(r, g, b)
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

local DIM_HEX, FAINT_HEX = Hex(DIM[1], DIM[2], DIM[3]), Hex(FAINT[1], FAINT[2], FAINT[3])

local function Now()
	if type(GetTime) ~= "function" then
		return 0
	end
	local ok, now = pcall(GetTime)
	return ok and Finite(now) and now or 0
end

-- True in a fight: InCombatLockdown's answer, a withheld one counting as a fight.
local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

-- The part ---------------------------------------------------------------------------------------------------------------------------------------

-- A fault goes to the game's error handler once for each thing that failed, so it is seen and does not fill the screen.
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

-- Runs fn as the part of the chat module (design 4.4): each run is counted by a number of its own, given first, since ns.EachPart counts a fault once
-- for each first argument and stops the part at the third (Core.lua:2178, 2185-2194). A part that stopped closes the window.
local function Run(fn, ...)
	W.runs = W.runs + 1
	local ok, err = ns.EachPart(KEY, PART, Step, W.runs, fn, ...)
	if not ok and err ~= nil then
		Report("window", err)
		if ns.PartStopped(KEY, PART) then
			Close()
		end
	end
	return ok == true
end

-- True while the window may show: the chat module registered, on and running, and this part not stopped.
local function Allowed()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.Enabled(KEY) and not ns.PartStopped(KEY, PART)
end

local function Refusal()
	if type(ns.modules) == "table" and ns.modules[KEY] ~= nil then
		if ns.IsStopped(KEY) then
			return T.MODULE_STOPPED
		elseif ns.PartStopped(KEY, PART) then
			return T.STOPPED
		end
	end
	return T.OFF
end

-- A function of a table of another part, looked up when it is called and never kept: that part's file may load after this one or fail.
local function Fn(tbl, name)
	if type(tbl) ~= "table" or IsSecret(tbl) then
		return nil
	end
	local fn = tbl[name]
	if type(fn) == "function" then
		return fn
	end
	return nil
end

-- The first answer of a function of another part, or nil when it is missing or raises; its fault goes to the error handler once.
local function Ask(tbl, name, ...)
	local fn = Fn(tbl, name)
	if not fn then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok then
		return answer
	end
	Report(name, answer)
	return nil
end

-- SpellModel listens to the game's events only while an owner wants them (M.Want, design 4.3, 4.5): the window while it shows. Plain code, so the
-- window also lets go once its part has stopped.
local function Want(on)
	on = on == true
	if (W.wanted == true) == on then
		return
	end
	local want = Fn(ns.SpellModel, "Want")
	if want and pcall(want, OWNER, on) then
		W.wanted = on
	elseif not on then
		W.wanted = false
	end
end

-- The player's state and stats as SpellModel has them, after it read what an event marked (M.State, M.Stats, design 4.3).
local function Touch()
	local model = ns.SpellModel
	return Ask(model, "State"), Ask(model, "Stats")
end

-- The look ----------------------------------------------------------------------------------------------------------------------------------------

-- Red, green and blue of a colour row, else the fallback while the row is missing or does not read.
local function RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

-- Window opacity of the Windows page, 0 to 1.
local function Opacity()
	local value = ns.Get("windows.opacity")
	return Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

-- Icon crop of the Windows page: the share of the icon's side cut from each edge.
local function Crop()
	local value = ns.Get("windows.crop")
	return (Finite(value) and math.max(0, math.min(15, value)) or 8) / 100
end

local function Label(parent, font, wrap)
	local text = ns.OwnText(parent, "OVERLAY", font or FONT)
	if not text then
		error("no font string", 0)
	end
	text:SetJustifyH("LEFT")
	text:SetWordWrap(wrap == true)
	return text
end

local function Texture(parent, layer, sub)
	return Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

-- A stroke of the close cross, in units from the button's top left corner, as the bag window draws its cross (BagsWindow.lua:473-479, 696-707).
local function Stroke(button, layer, x1, y1, x2, y2)
	local line = Own(button:CreateLine(nil, layer, nil, 2))
	line:SetThickness(1.5)
	line:SetStartPoint("TOPLEFT", button, x1, -y1)
	line:SetEndPoint("TOPLEFT", button, x2, -y2)
	return line
end

-- The width a font string's text needs, whatever width it is given; a guess from its length when the client does not say.
local function TextWidth(text, words)
	local ok, width = pcall(text.GetUnboundedStringWidth, text)
	if not (ok and Finite(width) and width > 0) then
		ok, width = pcall(text.GetStringWidth, text)
	end
	if ok and Finite(width) and width > 0 then
		return width
	end
	return #(words or "") * 6
end

-- The height of a text as it wraps now, else the height of one line, as Flat UI setup measures its own (SetupWelcome.lua:34-41).
local function Height(text)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and Finite(height) and height > 0 and height < 1000 then
		return math.ceil(height)
	end
	return L.LINE
end

local function Colour(text, colour)
	text:SetTextColor(colour[1], colour[2], colour[3], 1)
end

-- The switch: the chosen word in the Highlight colour, the one under the mouse white, the others dim (design 2.7).
local function PaintWords()
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	for _, word in ipairs(W.words) do
		if word.mode == W.mode then
			word.text:SetTextColor(ar, ag, ab, 1)
		elseif word.over then
			Colour(word.text, PLAIN)
		else
			Colour(word.text, DIM)
		end
	end
end

-- Everything the rows of the Windows page and the general backdrop colour decide; texture and colour calls only.
function PaintLook()
	if not W.frame then
		return
	end
	local r, g, b = RGB("general.backdrop", 0.06, 0.06, 0.06)
	ns.SetOutlineFill(W.outline, r, g, b, Opacity())
	ns.SetOutline(W.outline, true, true)
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	local item = W.item
	ns.SetOutlineFill(item.outline, pr, pg, pb, 1)
	ns.SetOutline(item.outline, true, true)
	item.hover:SetColorTexture(ar, ag, ab, 0.08)
	item.light:SetColorTexture(ar, ag, ab, 0.14)
	W.tableLight:SetColorTexture(ar, ag, ab, 0.08)
	for _, rule in ipairs(W.rules) do
		rule:SetColorTexture(1, 1, 1, SEPARATOR)
	end
	for _, sep in ipairs(W.seps) do
		sep:SetColorTexture(1, 1, 1, 0.2)
	end
	for _, line in ipairs(W.close.lines) do
		line:SetColorTexture(1, 1, 1, 0.6)
	end
	for _, line in ipairs(W.close.hover) do
		line:SetColorTexture(ar, ag, ab, 1)
	end
	for _, slot in ipairs(W.rows) do
		slot.hover:SetColorTexture(ar, ag, ab, 0.12)
	end
	Colour(W.title, PLAIN)
	for _, text in ipairs({ item.place, item.hint, W.message }) do
		Colour(text, DIM)
	end
	for _, text in ipairs(W.heads) do
		Colour(text, DIM)
	end
	for _, pool in ipairs({ W.notes, W.foot }) do
		for _, text in ipairs(pool) do
			Colour(text, DIM)
		end
	end
	PaintWords()
end

-- Tooltips ---------------------------------------------------------------------------------------------------------------------------------------

local function Tooltip()
	local tip = GameTooltip
	if type(tip) == "table" and not IsSecret(tip) and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

-- Hides the tooltip only while that frame of the window owns it.
local function Untip(owner)
	local tip = Tooltip()
	if not tip then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

-- True when a tooltip accessor of the game built a tooltip (TooltipDataHandler.lua:245-307).
local function Built(ok, answer)
	return ok and not IsSecret(answer) and answer == true
end

-- Dim lines at the end of a tooltip, which wrap at its width.
local function AddDim(tip, lines)
	for _, line in ipairs(lines) do
		pcall(tip.AddLine, tip, line, DIM[1], DIM[2], DIM[3], true)
	end
end

-- A tooltip of a title and dim lines, never in a fight. SetOwner leaves it empty, as the game's own tooltips start with AddLine after it
-- (Blizzard_MacroUI/Blizzard_MacroUI.lua:242-243).
local function Say(owner, title, lines)
	if Fighting() then
		return
	end
	local tip = Tooltip()
	if not tip or not pcall(tip.SetOwner, tip, owner, "ANCHOR_BOTTOM") then
		return
	end
	pcall(tip.AddLine, tip, title, PLAIN[1], PLAIN[2], PLAIN[3])
	AddDim(tip, lines)
	pcall(tip.Show, tip)
end

-- Numbers ----------------------------------------------------------------------------------------------------------------------------------------

-- A whole number with its thousands set apart by commas, as Flat UI's English lines write them.
local function Group(whole)
	local digits = ("%d"):format(whole)
	return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- An amount, no sign, as the comparison writes it (design 2.3): a second with one decimal; any other figure whole from 100 up and with one decimal
-- below, a trailing .0 dropped.
local function Amount(size, second)
	if second then
		local whole, tenth = ("%.1f"):format(size):match("^(%d+)%.(%d)$")
		if whole then
			return Group(tonumber(whole)) .. "." .. tenth
		end
		return ("%.1f"):format(size)
	end
	if size >= 100 then
		return Group(math.floor(size + 0.5))
	end
	return (("%.1f"):format(size):gsub("%.0$", ""))
end

-- A figure now or with the item: - when the line has none in this figure, ~ first for an estimate.
local function Value(value, second, estimate)
	if not Finite(value) then
		return "-"
	end
	local text = Amount(math.abs(value), second)
	if value < 0 and text ~= "0" then
		text = "-" .. text
	end
	return (estimate and "~" or "") .. text
end

-- The change from now to with, signed, with the percent of the figure now (one decimal and its sign, (0%) under 0.05%, none when the figure now is
-- 0), and its tone: gain, loss or none (design 2.3). An estimate starts with ~ and keeps the tone of its direction.
local function Change(now, with, second, estimate)
	if not (Finite(now) and Finite(with)) then
		return "-", "none"
	end
	local delta = with - now
	local text, tone = "0", "none"
	if math.abs(delta) >= 0.05 then
		local amount = Amount(math.abs(delta), second)
		if amount ~= "0" then
			text, tone = (delta > 0 and "+" or "-") .. amount, delta > 0 and "gain" or "loss"
		end
	end
	if now ~= 0 then
		local share = delta / math.abs(now) * 100
		if math.abs(share) < 0.05 then
			text = text .. " (0%)"
		else
			text = text .. (" (%s%.1f%%)"):format(share > 0 and "+" or "-", math.abs(share))
		end
	end
	return (estimate and "~" or "") .. text, tone
end

-- Items ------------------------------------------------------------------------------------------------------------------------------------------

local function ItemID(link)
	local id = Text(link) and link:match("item:(%d+)") or nil
	return id and tonumber(id) or nil
end

-- What the window takes as an item: a link, an item string ("item:19379") or an item ID.
local function AsItem(value)
	if Finite(value) and value > 0 then
		return ("item:%d"):format(math.floor(value))
	end
	local text = Text(value)
	if text and text:find("item:%d") then
		return text
	end
	return nil
end

-- The colour code and the name in a link, as the game writes one: |c...|Hitem:...|h[name]|h|r.
local function LinkParts(link)
	local text = Text(link)
	if not text then
		return nil, nil
	end
	local colour, name = text:match("^(|c.-)|H.-|h%[(.-)%]|h")
	if not name then
		name = text:match("|h%[(.-)%]|h")
	end
	return colour, Text(name)
end

-- The colour code of an item quality: the game's own colour of it, which every quality has, poor items too, else C_Item.GetItemQualityColor's.
local function QualityHex(quality)
	if not Finite(quality) then
		return nil
	end
	local get = Fn(_G.ColorManager, "GetColorDataForItemQuality")
	if get then
		local ok, colour = pcall(get, quality)
		if ok and type(colour) == "table" and not IsSecret(colour) and Finite(colour.r) and Finite(colour.g) and Finite(colour.b) then
			return Hex(colour.r, colour.g, colour.b)
		end
	end
	local quality2 = Fn(C_Item, "GetItemQualityColor")
	if quality2 then
		local ok, r, g, b = pcall(quality2, quality)
		if ok and Finite(r) and Finite(g) and Finite(b) then
			return Hex(r, g, b)
		end
	end
	return nil
end

-- An item as the window shows it: { id, name, text (the name in its quality colour), icon, loaded }. The name and colour come from the link first,
-- which needs nothing loaded; an item the client has not loaded is asked for once.
local function ItemLook(link)
	local colour, name = LinkParts(link)
	local look = { id = ItemID(link) }
	local info = Fn(C_Item, "GetItemInfo")
	if info then
		-- The first answer is nil while the client has not loaded the item.
		local ok, itemName, _, quality = pcall(info, link)
		if ok and Text(itemName) then
			look.loaded = true
			name = name or itemName
			colour = colour or QualityHex(quality)
		end
	end
	local instant = Fn(C_Item, "GetItemInfoInstant")
	if instant then
		local ok, _, _, _, _, icon = pcall(instant, link)
		if ok and not IsSecret(icon) and (Finite(icon) or Text(icon)) then
			look.icon = icon
		end
	end
	if not look.loaded and look.id and not W.requested[look.id] then
		W.requested[look.id] = true
		local request = Fn(C_Item, "RequestLoadItemDataByID")
		if request then
			pcall(request, look.id)
		end
	end
	look.name = name or (look.id and ("item %d"):format(look.id)) or "an item"
	look.text = (colour or Hex(PLAIN[1], PLAIN[2], PLAIN[3])) .. look.name .. "|r"
	return look
end

-- The item worn in a slot: the link SpellModel read with the state (S.state.links), else the game's.
local function Worn(state, slot)
	local links = type(state) == "table" and state.links or nil
	local link = type(links) == "table" and Text(links[slot]) or nil
	if link then
		return link
	end
	if type(GetInventoryItemLink) == "function" then
		local ok, worn = pcall(GetInventoryItemLink, "player", slot)
		if ok then
			return Text(worn)
		end
	end
	return nil
end

local function Has(list, value)
	for _, held in ipairs(list) do
		if Finite(held) and held == value then
			return true
		end
	end
	return false
end

-- What a slot of the comparison takes the place of: both hands for the main and off hand together, else its first slot, else its own label.
local function Where(candidate)
	local slots = type(candidate) == "table" and type(candidate.slots) == "table" and candidate.slots or {}
	if Has(slots, 16) and Has(slots, 17) then
		return T.BOTH
	end
	local first = slots[1]
	return (Finite(first) and SLOTS[first]) or (type(candidate) == "table" and Text(candidate.label)) or T.SLOT
end

-- What the item would take the place of, one phrase for each slot of the comparison (design 2.4): the worn items with the slot, or the empty slot.
local function PlaceLine(cands, state)
	local phrases = {}
	for _, c in ipairs(cands) do
		local where, names = Where(c), {}
		if not c.empty then
			for _, slot in ipairs(type(c.slots) == "table" and c.slots or {}) do
				local link = Finite(slot) and Worn(state, slot) or nil
				if link then
					names[#names + 1] = ItemLook(link).text
				end
			end
		end
		if #names > 0 then
			phrases[#phrases + 1] = T.IN_PLACE:format(table.concat(names, " and "), where)
		elseif where == T.BOTH then
			phrases[#phrases + 1] = T.EMPTY_HANDS
		else
			phrases[#phrases + 1] = T.IN_EMPTY:format(where)
		end
	end
	if #phrases == 0 then
		return nil
	end
	local line = table.concat(phrases, ", or ")
	return line:sub(1, 1):upper() .. line:sub(2)
end

-- Lines ------------------------------------------------------------------------------------------------------------------------------------------

-- The spells chosen for the comparison (ns.GearChosen, GearLines.lua: { entry, rank, id, name, kept, known } each), the list as that file gives it,
-- since G.Compare takes it so; nil while it gives none.
local function Chosen()
	local list = Ask(ns, "GearChosen")
	if type(list) ~= "table" or IsSecret(list) then
		return nil
	end
	return list
end

-- The entry of a line in the data (SpellData.lua), or nil.
local function EntryOf(line)
	local entry = type(line) == "table" and line.entry or nil
	return type(entry) == "table" and entry or nil
end

-- The rank number of a line: its index in the entry's ranks, which are in Forever's rank order (design 3.2).
local function RankOf(line)
	local rank, entry = line.rank, EntryOf(line)
	if Finite(rank) then
		return math.floor(rank)
	end
	if entry and type(entry.ranks) == "table" and type(rank) == "table" then
		for index, held in ipairs(entry.ranks) do
			if rawequal(held, rank) then
				return index
			end
		end
	end
	return nil
end

-- The spell of a line: the rank it counts, else the highest rank of its entry in the data.
local function SpellOf(line)
	if type(line) ~= "table" then
		return nil
	end
	if Finite(line.id) and line.id > 0 then
		return line.id
	end
	local entry = EntryOf(line)
	local ranks = entry and type(entry.ranks) == "table" and entry.ranks or nil
	local last = ranks and ranks[#ranks] or nil
	if type(last) == "table" and Finite(last[1]) then
		return last[1]
	end
	return nil
end

-- The name of a line: GearLines.lua's, else the game's, else the data's key with capitals.
local function NameOf(line)
	local name = Text(line.name)
	if not name then
		local id, get = SpellOf(line), Fn(C_Spell, "GetSpellName")
		if id and get then
			local ok, got = pcall(get, id)
			name = ok and Text(got) or nil
		end
	end
	local entry = EntryOf(line)
	if not name and entry and Text(entry.key) then
		name = entry.key:gsub("(%a)(%w*)", function(first, rest)
			return first:upper() .. rest
		end)
	end
	return name or "?"
end

-- The number of G.Expect's answer a figure shows (design 2.3): threat a cast, or a second for the auto attack, Auto Shot and the wand.
local function Pick(e, figure, entry)
	if type(e) ~= "table" or not figure then
		return nil
	end
	local cmp = entry and entry.cmp or nil
	if figure == "cast" then
		return e.cast
	elseif figure == "second" or figure == "dps" then
		return e.second
	elseif figure == "threat" then
		if SWINGS[cmp] then
			return e.threatSecond
		end
		return e.threat
	end
	return nil
end

-- What a line counts when it is not what the switch says (design 2.3): a swing or a shot for A cast, threat for a line that does no damage, a second
-- for the threat of the auto attack, and none at A second for a strike that takes the place of the next swing (G.Figure gives it no figure there).
-- Nil when the switch says it.
local function Counts(mode, figure, entry)
	local cmp = entry and entry.cmp or nil
	if not figure then
		return entry and entry.nx and mode == "second" and T.SWING_NONE or nil
	elseif figure == "threat" then
		if SWINGS[cmp] then
			return mode == "threat" and "a second" or "threat a second"
		end
		return mode ~= "threat" and "threat" or nil
	elseif figure == "cast" and SWINGS[cmp] then
		return SWINGS[cmp]
	end
	return nil
end

-- The player's role (S.state.role, ns.PlayerRole's first answer), which decides what a line counts and where the player stands.
local function Role(state)
	local role = type(state) == "table" and Text(state.role) or nil
	if role then
		return role
	end
	if type(ns.PlayerRole) == "function" then
		local ok, answer = pcall(ns.PlayerRole)
		if ok then
			return Text(answer)
		end
	end
	return nil
end

local function Level(state)
	if type(state) == "table" and Finite(state.level) then
		return state.level
	end
	if type(UnitLevel) == "function" then
		local ok, level = pcall(UnitLevel, "player")
		if ok and Finite(level) then
			return level
		end
	end
	return nil
end

-- What the comparison counts with: the switch, the version of the list, the rows of the tab (design 4.9) and the hit table inputs GearModel read at
-- the last plain read of the stats (G.Inputs).
local function Options(mode)
	return {
		mode = mode, listVersion = Ask(ns, "GearListVersion"), against = Opt("gearAgainst"), facing = Opt("gearFacing"), rules = Opt("gearRules"),
		lowRank = Opt("spellLowRank") ~= false, inputs = Ask(ns.GearModel, "Inputs"),
	}
end

-- Working it out ---------------------------------------------------------------------------------------------------------------------------------

-- With no item, or one that cannot be compared: what each line does now, from G.Expect with the player's state and stats, in the figure G.Figure
-- gives it for the switch.
local function Profile(view, lines, state, stats)
	local model = ns.GearModel
	local opts = Options(view.mode)
	for _, line in ipairs(lines) do
		if type(line) == "table" then
			local row = { line = line, figure = Text(Ask(model, "Figure", line, view.role, view.mode)) }
			if row.figure then
				local e = Ask(model, "Expect", line, state, stats, opts)
				if type(e) == "table" then
					row.now = Pick(e, row.figure, EntryOf(line))
					row.basis, row.why = Text(e.basis), Text(e.why)
					row.estimate = row.basis == "e"
				end
			end
			view.rows[#view.rows + 1] = row
		end
	end
end

-- The row of a slot of the comparison that counts a line: the one at the same place when it holds that line, else the one that holds it, else the
-- one of the same spell.
local function RowOf(rows, line, index)
	local at = rows[index]
	if type(at) == "table" and rawequal(at.line, line) then
		return at
	end
	for _, row in ipairs(rows) do
		if type(row) == "table" and rawequal(row.line, line) then
			return row
		end
	end
	local id = SpellOf(line)
	for _, row in ipairs(rows) do
		if type(row) == "table" and id and SpellOf(row.line) == id then
			return row
		end
	end
	return nil
end

-- The rows of an item compared (G.Compare's candidates, the first two): each line now, with the item in each slot, its figure and whether it is an
-- estimate. False when the item has no slot to compare with.
local function Compared(view, result, lines, state)
	local cands = {}
	for _, c in ipairs(type(result.candidates) == "table" and result.candidates or {}) do
		if type(c) == "table" and type(c.rows) == "table" and #cands < 2 then
			cands[#cands + 1] = c
		end
	end
	view.cands = cands
	if #cands == 0 then
		return false
	end
	view.layout = #cands == 2 and "two" or "one"
	for index, line in ipairs(lines) do
		if type(line) == "table" then
			local row = { line = line, with = {} }
			for which, c in ipairs(cands) do
				local found = RowOf(c.rows, line, index)
				if found then
					if row.now == nil then
						row.now = found.now
					end
					row.figure = row.figure or Text(found.figure)
					row.estimate = row.estimate or found.estimate == true
					row.with[which] = found.with
				end
			end
			view.rows[#view.rows + 1] = row
		end
	end
	view.place = PlaceLine(cands, state)
	return true
end

local function Note(notes, text, prefix)
	text = Text(text)
	if text then
		if prefix and text:sub(1, #prefix) ~= prefix then
			text = prefix .. text
		end
		notes[#notes + 1] = text
	end
end

-- The dim lines of an item compared (design 2.6): not wearable yet, no change, each line not counted, the bonuses against a kind of creature, random
-- stats, and why it was not compared when the place line does not say it already.
local function Notes(view, result)
	local notes = view.notes
	if result.notYet == true then
		Note(notes, T.NOT_YET)
	else
		Note(notes, result.notYet, T.NOT_YET_LINE)
	end
	if result.noChange == true then
		Note(notes, T.NO_CHANGE)
	end
	for _, text in ipairs(type(result.notCounted) == "table" and result.notCounted or {}) do
		Note(notes, text, T.NOT_COUNTED_LINE)
	end
	for _, text in ipairs(type(result.vs) == "table" and result.vs or {}) do
		Note(notes, text)
	end
	if result.random == true then
		Note(notes, T.RANDOM)
	else
		Note(notes, result.random)
	end
	local why = Text(result.why)
	if why and why ~= view.place then
		Note(notes, why)
	end
end

-- What the window shows now, the view Paint draws: the lines, now and with the item, in the figure of the switch, with the item's notes.
local function Compute()
	local view = { mode = W.mode, layout = "none", rows = {}, notes = {}, cands = {} }
	local model, gear = ns.SpellModel, ns.GearModel
	if not (Fn(model, "State") and Fn(gear, "Expect") and Fn(gear, "Figure")) then
		view.message = T.NO_MODEL
		return view
	end
	local lines = Chosen()
	if not lines then
		view.message = T.NO_LIST
		return view
	end
	local state, stats = Touch()
	view.role, view.level = Role(state), Level(state)
	view.noStats = type(stats) ~= "table"
	view.old = type(stats) == "table" and stats.old == true
	if W.link then
		view.item = ItemLook(W.link)
		local result = Ask(gear, "Compare", W.link, lines, Options(view.mode))
		if type(result) == "table" then
			-- With no slot to compare with, why goes where the slots would be named; the header is the item tooltip's and names a unit.
			if not Compared(view, result, lines, state) then
				view.place = Text(result.why)
				if not view.place then
					Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
				end
			end
			Notes(view, result)
		else
			Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
		end
	end
	if view.layout == "none" then
		Profile(view, lines, state, stats)
	end
	if #view.rows == 0 then
		view.message = T.EMPTY
	end
	return view
end

-- What the view was worked out from: SpellModel's version, the version of the list, the switch, the item and whether the client has loaded it.
local function Key()
	local look = W.link and ItemLook(W.link) or nil
	return table.concat({ tostring(Ask(ns.SpellModel, "Version")), tostring(Ask(ns, "GearListVersion")), W.mode, W.link or "",
		look and look.loaded and "loaded" or "" }, "\n")
end

-- Works the view out again and draws it. SpellModel reads what an event marked first, so the key is that of what the view is worked out from; a
-- key taken just now (Tick) is given.
function Refresh(key)
	if not W.frame then
		return
	end
	if not key then
		Touch()
		key = Key()
	end
	W.drawn = key
	W.fight = Fighting()
	W.dirty = false
	W.view = Compute()
	Paint(W.view)
end

-- Drawing ----------------------------------------------------------------------------------------------------------------------------------------

-- The columns of each table with their x from the left edge of a line, worked out once.
local COLS = {}
for layout, list in pairs(COLUMNS) do
	local columns, x = {}, 0
	for index, column in ipairs(list) do
		columns[index] = { key = column[1], head = column[2], width = column[3], justify = column[4], slot = column[5], x = x }
		x = x + column[3]
	end
	COLS[layout] = columns
end

-- A cell in its column of a line: a name from the column's left edge, a number up to its right edge, each short of the next column.
local function SetCell(text, line, column)
	text:ClearAllPoints()
	if column.justify == "LEFT" then
		text:SetPoint("LEFT", line, "LEFT", column.x, 0)
	else
		text:SetPoint("RIGHT", line, "LEFT", column.x + column.width, 0)
	end
	text:SetWidth(column.width - L.CELL_GAP)
	text:SetJustifyH(column.justify)
end

-- A frame of the window from y down, inside the padding.
local function Hang(region, y, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
	region:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -L.PAD, -y)
	if height then
		region:SetHeight(height)
	end
end

-- A text of the window from y down, given the width inside the padding itself, so it wraps there and the height read after SetText is the height it
-- wraps to, as the options window's tooltip beside a row sizes its texts (PanelTrust.lua:113-126).
local function HangText(text, y)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
	text:SetWidth(L.INNER)
end

-- A separator across the window at y.
local function PaintRule(rule, y)
	Hang(rule, y, ns.Pixels(W.frame, 1))
	rule:Show()
end

-- The item: its icon, its name in its quality colour and what it would take the place of, or how to give the window one.
local function PaintItem(view, y)
	local item, look = W.item, view.item
	local height = L.ICON
	if look then
		if look.icon and pcall(item.icon.SetTexture, item.icon, look.icon) then
			local cut = Crop()
			item.icon:SetTexCoord(cut, 1 - cut, cut, 1 - cut)
			item.icon:Show()
		else
			item.icon:Hide()
		end
		item.name:SetText(look.text)
		item.name:Show()
		item.hint:Hide()
		local need = Height(item.name)
		if view.place then
			item.place:SetText(view.place)
			item.place:Show()
			need = need + L.LINE_GAP + Height(item.place)
		else
			item.place:Hide()
		end
		height = math.max(L.ICON, need)
	else
		item.icon:Hide()
		item.name:Hide()
		item.place:Hide()
		item.hint:Show()
	end
	Hang(item.button, y, height)
	return y + height + L.GAP
end

-- The column heads of the table, while it has a line.
local function PaintHeads(view, y)
	local columns, shown = COLS[view.layout], #view.rows > 0
	Hang(W.headRow, y, L.HEAD)
	for index, head in ipairs(W.heads) do
		local column = shown and columns[index] or nil
		if column then
			local text = column.head
			if column.slot then
				text = text:format(Where(view.cands[column.slot]))
			end
			SetCell(head, W.headRow, column)
			head:SetText(text)
			head:Show()
		else
			head:Hide()
		end
	end
	if not shown then
		W.headRule:Hide()
		return y
	end
	PaintRule(W.headRule, y + L.HEAD)
	return y + L.HEAD + 3
end

-- The name of a row: the spell, "Rank 4" after a rank the list keeps (design 2.7), dim what it counts when the switch does not say it, and faint
-- "not known" for a spell the character does not know now.
local function RowName(row, mode)
	local line, entry = row.line, EntryOf(row.line)
	local name = NameOf(line)
	if line.kept then
		local rank = RankOf(line)
		if rank and not name:find("Rank %d") then
			name = T.RANK:format(name, rank)
		end
	end
	local counts = Counts(mode, row.figure, entry)
	if counts then
		name = name .. "  " .. DIM_HEX .. counts .. "|r"
	end
	if line.known == false then
		name = name .. "  " .. FAINT_HEX .. T.NOT_KNOWN .. "|r"
	end
	return name
end

-- One line of the table: its cells in the columns of the layout, coloured as the item tooltips colour them (design 2.3).
local function PaintRow(slot, row, view, columns, y)
	local second = row.figure == "second" or row.figure == "dps"
	for index, cell in ipairs(slot.cells) do
		local column = columns[index]
		if column then
			SetCell(cell, slot.button, column)
			if column.key == "name" then
				cell:SetText(RowName(row, view.mode))
				Colour(cell, row.line.known == false and FAINT or PLAIN)
			elseif column.key == "now" then
				cell:SetText(Value(row.now, second, row.estimate))
				Colour(cell, Finite(row.now) and PLAIN or FAINT)
			elseif column.key == "with" then
				local with = row.with and row.with[1]
				cell:SetText(Value(with, second, row.estimate))
				Colour(cell, Finite(with) and PLAIN or FAINT)
			else
				local text, tone = Change(row.now, row.with and row.with[column.slot], second, row.estimate)
				cell:SetText(text)
				Colour(cell, text == "-" and FAINT or TONES[tone] or TONES.none)
			end
			cell:Show()
		else
			cell:Hide()
		end
	end
	slot.row = row
	Hang(slot.button, y, L.ROW)
	slot.button:Show()
end

-- The lines of the table, as many as the window holds from the first one scrolled to, or how to give the window one.
local function PaintRows(view, y)
	local columns, count = COLS[view.layout], #view.rows
	W.offset = math.max(0, math.min(W.offset, count - #W.rows))
	for index, slot in ipairs(W.rows) do
		local row = view.rows[W.offset + index]
		if row and index <= count then
			PaintRow(slot, row, view, columns, y)
			y = y + L.ROW
		else
			slot.row = nil
			slot.button:Hide()
		end
	end
	if view.message then
		HangText(W.message, y)
		W.message:SetText(view.message)
		W.message:Show()
		y = y + Height(W.message) + L.LINE_GAP
	else
		W.message:Hide()
	end
	return y
end

-- Dim lines from the pool, from y down, each wrapping at the width inside the padding; the last of the pool says how many more there are when they
-- do not fit.
local function PaintLines(pool, texts, y)
	local count = #texts
	for index, label in ipairs(pool) do
		local text = texts[index]
		if text and index == #pool and count > #pool then
			text = T.MORE:format(count - #pool + 1)
		end
		if text then
			HangText(label, y)
			label:SetText(text)
			label:Show()
			y = y + Height(label) + L.LINE_GAP
		else
			label:Hide()
		end
	end
	return y
end

-- The enemy and the hit cap the comparison counts against, as the rows of the tab say (design 2.5, 4.9): a boss at the top level at Against's first
-- choice, in front for a tank at Where you stand's first choice, and the hit table's own hit cap at Hit cap against a boss's first choice.
local function Against(view)
	local against = Opt("gearAgainst") or "auto"
	local boss = against == "boss" or (against == "auto" and Finite(view.level) and view.level >= MAX_LEVEL)
	local facing = Opt("gearFacing") or "role"
	local front = facing == "front" or (facing == "role" and view.role == "tank")
	local where = front and T.FRONT or T.BEHIND
	if not boss then
		return T.AGAINST_LEVEL:format(where)
	end
	local rules = Opt("gearRules") or "hittable"
	if rules == "hittable" then
		rules = ns.Get("hud.hitTableRules")
	end
	return T.AGAINST_BOSS:format(where, CAPS[rules] or CAPS.classic)
end

-- The foot (design 2.7): against what, what the numbers leave out, the mark of an estimate, the stats of before the fight, and the scroll.
local function FootLines(view)
	local texts = { Against(view), T.BEFORE, T.NOT_COUNTED, T.ESTIMATE }
	if view.noStats then
		texts[#texts + 1] = T.NO_STATS
	elseif view.old or Fighting() then
		texts[#texts + 1] = T.OLD
	end
	local count, most = #view.rows, #W.rows
	if count > most then
		texts[#texts + 1] = T.SCROLL:format(W.offset + 1, W.offset + most, count)
	end
	return texts
end

-- Draws a view: from the top down, the item, the table, the item's notes and the foot, and the window as tall as they are.
function Paint(view)
	local frame = W.frame
	if not frame or type(view) ~= "table" then
		return
	end
	PaintLook()
	PaintRule(W.barRule, L.BAR)
	local y = PaintItem(view, L.BAR + L.GAP)
	local top = y
	y = PaintRows(view, PaintHeads(view, y))
	W.tableLight:ClearAllPoints()
	W.tableLight:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD - 3, -top + 2)
	W.tableLight:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -L.PAD + 3, -y)
	if #view.notes > 0 then
		y = PaintLines(W.notes, view.notes, y + L.GAP)
	else
		PaintLines(W.notes, {}, y)
	end
	-- The foot under a separator, as far from it as the separator is from what is above it.
	PaintRule(W.footRule, y + L.GAP)
	y = PaintLines(W.foot, FootLines(view), y + 2 * L.GAP)
	frame:SetHeight(math.ceil(y - L.LINE_GAP + L.PAD))
end

-- Placing ----------------------------------------------------------------------------------------------------------------------------------------

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

-- Puts the window at its spot in the movers, its top left corner at the box's, else where it was let go this session, else where its entry starts.
-- Not while it is dragged.
function Place()
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
		x, y, anchor = BOX.x, BOX.y, "TOPLEFT"
	end
	local key = ("%s:%.2f:%.2f"):format(anchor, x, y)
	if W.placed == key then
		return
	end
	W.placed = key
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, anchor, x, y)
end

local function DragStart()
	W.frame:StartMoving()
	W.moving = true
end

-- The window was let go: the box of its entry in the movers, its top left corner at the window's, is saved as its spot (ns.MoverKit.Commit), and the
-- window hangs from it (ns.GearWindowMoved). Without the entry it stays where it was let go for this session.
function Dropped()
	if not W.moving then
		return
	end
	W.moving = false
	local frame = W.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	W.placed = nil
	local left, bottom, _, height = RectOf(frame)
	if not left then
		Place()
		return
	end
	local top = bottom + height
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	local boxW = info and Finite(info.width) and info.width > 0 and info.width or BOX.width
	local boxH = info and Finite(info.height) and info.height > 0 and info.height or BOX.height
	local saved = false
	if info and type(kit.Commit) == "function" then
		saved = kit.Commit(NAME, info, left, top - boxH, boxW, boxH) == true
	end
	W.dropped = not saved and { left, top } or nil
	W.placed = nil
	Place()
end

-- Drops ------------------------------------------------------------------------------------------------------------------------------------------

-- What the cursor holds: "item" and the item's link, or "spell" and the spell's ID (a macro's: the spell it casts), or nothing.
local function Held()
	if type(GetCursorInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, link, spell = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) then
		return nil
	end
	if kind == "item" then
		local item = AsItem(Text(link)) or AsItem(id)
		return item and "item" or nil, item
	elseif kind == "spell" then
		return Finite(spell) and spell > 0 and "spell" or nil, spell
	elseif kind == "macro" and Finite(id) and type(GetMacroSpell) == "function" then
		local okSpell, cast = pcall(GetMacroSpell, id)
		return okSpell and Finite(cast) and cast > 0 and "spell" or nil, cast
	end
	return nil
end

-- A spell for the list: ns.GearAdd answers whether it took it and what to say, as the Add a spell row's pick does (design 4.3; Panel.lua:762-791).
local function Add(spell)
	local add = Fn(ns, "GearAdd")
	if not add then
		print(T.NO_ADD)
		return
	end
	local ok, done, message = pcall(add, spell)
	if not ok then
		Report("GearAdd", done)
		return
	end
	if Text(message) then
		print(message)
	end
	if done then
		Refresh()
	end
end

-- Takes what the cursor holds. An item is compared and goes back where it came from; a spell goes on the list and stays on the cursor (header). The
-- click that ends a drag on the window brings the same spell again, which counts as that drop. True when it took something.
function Drop()
	local kind, value = Held()
	if kind == "item" then
		pcall(ClearCursor)
		W.link, W.offset = value, 0
		Refresh()
		return true
	elseif kind == "spell" then
		local now = Now()
		if W.spell ~= value or now - (W.spellAt or 0) >= DROP_AGAIN then
			W.spell, W.spellAt = value, now
			Add(value)
		end
		return true
	end
	return false
end

-- Takes a line off the list (ns.GearRemove, by the spell of the line), which says what it did.
local function Remove(row)
	local remove, id = Fn(ns, "GearRemove"), row and SpellOf(row.line)
	if not (remove and id) then
		return
	end
	local ok, done, message = pcall(remove, id)
	if not ok then
		Report("GearRemove", done)
		return
	end
	if Text(message) then
		print(message)
	end
	Refresh()
end

-- The lit parts while the cursor holds what they take: the item's area for an item, the table for a spell.
local function Lights()
	local kind = Held()
	W.item.light:SetShown(kind == "item")
	W.tableLight:SetShown(kind == "spell")
end

-- Every half second while the window shows: out of combat it is worked out again when what it was worked out from changed; in a fight it keeps its
-- numbers, and its foot says once that the stats are from before the fight (design 2.7).
local function Tick()
	if Fighting() then
		if not W.fight then
			W.fight = true
			Paint(W.view)
		end
		return
	end
	Touch()
	local key = Key()
	if W.dirty or W.fight or key ~= W.drawn then
		Refresh(key)
	end
end

local function Scroll(delta)
	local view = W.view
	if type(view) ~= "table" or not Finite(delta) or delta == 0 then
		return
	end
	local most = math.max(0, #view.rows - #W.rows)
	local offset = math.max(0, math.min(most, W.offset + (delta > 0 and -1 or 1)))
	if offset ~= W.offset then
		W.offset = offset
		Paint(view)
	end
end

-- The tooltips of the window -----------------------------------------------------------------------------------------------------------------------

-- For a weapon ability, the speed its attack power counts at (design 1.3, 2.5, 2.7): the form's swing in Cat or Bear Form, a normalized part the speed
-- of the kind of weapon worn, else the weapon's own speed; the speeds are the data's (D.MODEL, SpellData.lua).
local function Speed(entry, state)
	if entry.cmp == "wand" then
		return nil
	end
	local part
	for _, held in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(held) == "table" and held[1] == "wpn" then
			part = held
			break
		end
	end
	if not part then
		return nil
	end
	local data = type(ns.SpellData) == "table" and ns.SpellData.MODEL or nil
	local norm = type(data) == "table" and type(data.norm) == "table" and data.norm or NORM
	local swing = type(data) == "table" and type(data.form) == "table" and data.form or SWING
	local power = part.h == "ranged" and T.RANGED_POWER or T.POWER
	local form = type(state) == "table" and Finite(state.form) and FORMS[state.form] or nil
	local kind = (part.spd == "cat" or part.spd == "bear") and part.spd or form
	if kind and Finite(swing[kind]) then
		return T.SPEED_FORM:format(power, kind == "cat" and T.CAT or T.BEAR, swing[kind])
	end
	local weapons = type(state) == "table" and type(state.weapons) == "table" and state.weapons or {}
	local hand = HANDS[part.h] or 16
	local weapon = type(weapons[hand]) == "table" and weapons[hand] or {}
	if part.spd == "norm" or part.spd == "nranged" then
		local which = "one"
		if part.spd == "nranged" or hand == 18 then
			which = "ranged"
		elseif weapon.dagger == true then
			which = "dagger"
		elseif weapon.twoHand == true then
			which = "two"
		end
		return Finite(norm[which]) and T.SPEED_NORM:format(power, norm[which], WEAPONS[which]) or nil
	end
	if Finite(weapon.speed) and weapon.speed > 0 then
		return T.SPEED_OWN:format(power, weapon.speed)
	end
	return T.SPEED_ANY:format(power)
end

-- True when what a line shows was measured in the game (basis m, design 3.2, 3.5): for threat the letter of its rank in the threat's basis, which is
-- one letter or one a rank, or the basis of its attack power share; else a share of the entry.
local function Measured(entry, line, figure)
	local threat = entry.threat
	local b = type(threat) == "table" and Text(threat.b) or nil
	if figure == "threat" and b then
		local letter = b
		if #b > 1 then
			local at = RankOf(line) or #b
			letter = b:sub(at, at)
		end
		return letter == "m" or threat.apb == "m"
	end
	for _, part in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(part) == "table" and part.b == "m" then
			return true
		end
	end
	return false
end

-- The window's lines under a line's spell tooltip: the speed its attack power counts at, whether its numbers were measured or are an estimate and
-- why, a strike that takes the place of the next swing, a spell not known now, and how to take it off.
local function RowLines(row)
	local lines, line = {}, row.line
	local entry = EntryOf(line)
	local state, stats = Touch()
	local speed = entry and Speed(entry, state) or nil
	if speed then
		lines[#lines + 1] = speed
	end
	local basis, why = row.basis, row.why
	if basis == nil then
		local e = Ask(ns.GearModel, "Expect", line, state, stats, Options(W.mode))
		if type(e) == "table" then
			basis, why = Text(e.basis), Text(e.why)
		end
	end
	if basis == "m" or (basis == nil and entry and Measured(entry, line, row.figure)) then
		lines[#lines + 1] = T.MEASURED
	end
	if row.estimate or basis == "e" then
		lines[#lines + 1] = T.ESTIMATED
	end
	if why then
		lines[#lines + 1] = why
	end
	if entry and entry.nx and W.mode == "second" then
		lines[#lines + 1] = T.NEXT_SWING
	end
	if line.known == false then
		lines[#lines + 1] = T.UNKNOWN
	end
	lines[#lines + 1] = T.REMOVE
	return lines
end

-- The spell's own tooltip with the window's lines under it, out of combat. A spell the game builds no tooltip for gets its name.
local function RowTip(slot)
	local row = slot.row
	if not row or Fighting() then
		return
	end
	local tip, button = Tooltip(), slot.button
	if not tip or not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	local id = SpellOf(row.line)
	if not (id and Built(pcall(tip.SetSpellByID, tip, id))) then
		-- A tooltip the game could not build hid itself and let go of its owner (TooltipDataHandler.lua:264-269).
		if not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
			return
		end
		pcall(tip.AddLine, tip, NameOf(row.line), PLAIN[1], PLAIN[2], PLAIN[3])
	end
	AddDim(tip, RowLines(row))
	pcall(tip.Show, tip)
end

-- The item's own tooltip, out of combat, with how to take it away.
local function ItemTip()
	local button = W.item.button
	if not W.link or Fighting() then
		return
	end
	local tip = Tooltip()
	if not tip or not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	if not Built(pcall(tip.SetHyperlink, tip, W.link)) then
		Untip(button)
		return
	end
	AddDim(tip, { T.CLEAR })
	pcall(tip.Show, tip)
end

-- Clicks -----------------------------------------------------------------------------------------------------------------------------------------

-- A left click with something on the cursor is a drop; a right click on the item takes it away.
local function ItemClick(mouse)
	if mouse == "LeftButton" and Drop() then
		return
	end
	if mouse == "RightButton" and W.link then
		W.link, W.offset = nil, 0
		Untip(W.item.button)
		Refresh()
	end
end

-- A left click with something on the cursor is a drop; a right click takes the line off the list.
local function RowClick(slot, mouse)
	if mouse == "LeftButton" and Drop() then
		return
	end
	if mouse == "RightButton" and slot.row then
		Untip(slot.button)
		Remove(slot.row)
	end
end

-- A word of the switch: its figure, kept for the session.
local function Choose(word)
	if Drop() then
		return
	end
	W.chosen = true
	if W.mode ~= word.mode then
		W.mode, W.offset = word.mode, 0
		Refresh()
	end
end

-- Making the window ------------------------------------------------------------------------------------------------------------------------------

-- A frame of the window takes what is dropped on it, and a frame that is no button takes a click with something on the cursor too.
local function Drops(frame, clicks)
	frame:SetScript("OnReceiveDrag", function()
		Run(Drop)
	end)
	if clicks then
		frame:SetScript("OnMouseUp", function()
			Run(Drop)
		end)
	end
end

local function MakeSwitch(bar)
	local x = -(4 + L.CLOSE + L.WORD_GAP)
	W.seps = {}
	for index = #MODES, 1, -1 do
		local mode = MODES[index]
		local button = Own(CreateFrame("Button", nil, bar))
		button:SetHeight(L.WORD)
		button:RegisterForClicks("LeftButtonUp")
		local text = Label(button)
		text:SetPoint("CENTER", button, "CENTER", 0, 0)
		text:SetText(mode[2])
		local width = math.ceil(TextWidth(text, mode[2])) + L.WORD_ROOM
		button:SetWidth(width)
		button:SetPoint("RIGHT", bar, "RIGHT", x, 0)
		local word = { mode = mode[1], label = mode[2], button = button, text = text }
		button:SetScript("OnClick", function()
			Run(Choose, word)
		end)
		button:SetScript("OnEnter", function()
			word.over = true
			Run(PaintWords)
			Run(Say, button, word.label, { WORD_TIPS[word.mode] })
		end)
		button:SetScript("OnLeave", function()
			word.over = false
			Run(PaintWords)
			Untip(button)
		end)
		Drops(button)
		W.words[index] = word
		W.owners[#W.owners + 1] = button
		x = x - width
		if index > 1 then
			local sep = Texture(bar, "ARTWORK")
			sep:SetSize(1, 10)
			sep:SetPoint("CENTER", bar, "RIGHT", x - L.WORD_GAP / 2, 0)
			W.seps[#W.seps + 1] = sep
			x = x - L.WORD_GAP
		end
	end
end

-- The title bar: the title, the switch and the close cross, as the bag window draws its cross; a drag of it moves the window.
local function MakeBar(frame)
	local bar = Own(CreateFrame("Frame", nil, frame))
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(L.BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Run(DragStart)
	end)
	bar:SetScript("OnDragStop", function()
		Run(Dropped)
	end)
	-- A drag that the window's hiding cut short ends where it was let go.
	bar:SetScript("OnHide", function()
		if W.moving then
			pcall(Dropped)
		end
	end)
	Drops(bar, true)
	W.bar = bar
	W.title = Label(bar, TITLE_FONT)
	W.title:SetPoint("LEFT", bar, "LEFT", L.PAD, 0)
	W.title:SetText(T.TITLE)
	local close = Own(CreateFrame("Button", nil, bar))
	close:SetSize(L.CLOSE, L.CLOSE)
	close:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	close:RegisterForClicks("LeftButtonUp")
	W.close = { button = close,
		lines = { Stroke(close, "OVERLAY", 5, 5, 13, 13), Stroke(close, "OVERLAY", 5, 13, 13, 5) },
		hover = { Stroke(close, "HIGHLIGHT", 5, 5, 13, 13), Stroke(close, "HIGHLIGHT", 5, 13, 13, 5) } }
	close:SetScript("OnClick", function()
		Close()
	end)
	Drops(close)
	MakeSwitch(bar)
	W.barRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.barRule
end

-- The area of the item: the icon in a box of its own, the name, what it would take the place of, and how to give the window one.
local function MakeItem(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local item = { button = button }
	item.hover = Texture(button, "HIGHLIGHT")
	item.hover:SetAllPoints(button)
	item.light = Texture(button, "BACKGROUND", 1)
	item.light:SetAllPoints(button)
	item.light:Hide()
	local box = Own(CreateFrame("Frame", nil, button))
	box:SetSize(L.ICON, L.ICON)
	box:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	item.outline = ns.SetOutlineArea(ns.Outline(box, box), "windows")
	item.icon = Texture(box, "ARTWORK")
	item.icon:SetAllPoints(box)
	item.icon:Hide()
	local room = L.INNER - L.ICON - L.ICON_GAP
	item.name = Label(button, TITLE_FONT)
	item.name:SetPoint("TOPLEFT", box, "TOPRIGHT", L.ICON_GAP, -1)
	item.name:SetWidth(room)
	item.place = Label(button, FONT, true)
	item.place:SetPoint("TOPLEFT", item.name, "BOTTOMLEFT", 0, -L.LINE_GAP)
	item.place:SetWidth(room)
	pcall(item.place.SetMaxLines, item.place, 2)
	item.hint = Label(button, FONT, true)
	item.hint:SetPoint("LEFT", box, "RIGHT", L.ICON_GAP, 0)
	item.hint:SetWidth(room)
	item.hint:SetText(T.DROP)
	button:SetScript("OnClick", function(_, mouse)
		Run(ItemClick, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(ItemTip)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	Drops(button)
	W.item = item
	W.owners[#W.owners + 1] = button
end

-- One line of the table: a button that takes a right click, a drop and the wheel, its light under the mouse, and its four cells.
local function MakeRow(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:EnableMouseWheel(true)
	local slot = { button = button, cells = {} }
	slot.hover = Texture(button, "HIGHLIGHT")
	slot.hover:SetAllPoints(button)
	for index = 1, 4 do
		slot.cells[index] = Label(button)
	end
	button:SetScript("OnClick", function(_, mouse)
		Run(RowClick, slot, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(RowTip, slot)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	button:SetScript("OnMouseWheel", function(_, delta)
		Run(Scroll, delta)
	end)
	Drops(button)
	button:Hide()
	W.owners[#W.owners + 1] = button
	return slot
end

-- The heads, the lines, the message in their place, the item's notes and the foot, all made now so nothing is made later, in a fight or not.
local function MakeTable(frame)
	W.tableLight = Texture(frame, "BACKGROUND", 1)
	W.tableLight:Hide()
	W.headRow = Own(CreateFrame("Frame", nil, frame))
	W.heads = {}
	for index = 1, 4 do
		W.heads[index] = Label(W.headRow)
	end
	W.headRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.headRule
	for index = 1, MOST_ROWS do
		W.rows[index] = MakeRow(frame)
	end
	W.message = Label(frame, FONT, true)
	for index = 1, NOTES do
		W.notes[index] = Label(frame, FONT, true)
	end
	W.footRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.footRule
	for index = 1, FOOT do
		W.foot[index] = Label(frame, FONT, true)
	end
end

-- Escape closes the window: its name goes once into the game's list of windows CloseSpecialWindows hides (header).
local function Special()
	local list = UISpecialFrames
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

-- The window's part of its showing: SpellModel listens, the switch starts on Threat for a tank and on A cast for the others until the player picks
-- one (design 2.7), and the window is placed and worked out afresh.
local function Showing()
	Want(true)
	if not W.chosen then
		W.mode = Role((Touch())) == "tank" and "threat" or "cast"
	end
	W.elapsed, W.looked = 0, 0
	Place()
	Refresh()
end

-- Whatever hid the window (its cross, Escape, the module or the part going off): SpellModel may stop listening, a drag ends where it was let go, and a
-- tooltip of the window goes. Plain code, so it also runs once the part has stopped.
local function Hiding()
	Want(false)
	if W.moving then
		pcall(Dropped)
	end
	for _, owner in ipairs(W.owners) do
		Untip(owner)
	end
	if W.item then
		W.item.light:Hide()
		W.tableLight:Hide()
	end
end

-- The frame and everything in it, once, out of combat (design 4.7).
local function Make()
	local frame = Own(CreateFrame("Frame", NAME, UIParent))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:SetSize(L.WIDTH, BOX.height)
	frame:Hide()
	W.frame = frame
	W.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "windows")
	MakeBar(frame)
	MakeItem(frame)
	MakeTable(frame)
	Drops(frame, true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		Run(Scroll, delta)
	end)
	frame:SetScript("OnShow", function()
		Run(Showing)
	end)
	frame:SetScript("OnHide", function()
		Hiding()
	end)
	-- The looks of the window while it shows. It closes once the module or the part is off, also when no refresh of the module said so
	-- (ns.GearWindowSync), and when the module stopped, whose parts run nothing more: that test is plain code.
	frame:SetScript("OnUpdate", function(_, elapsed)
		local step = Finite(elapsed) and elapsed or 0
		W.elapsed, W.looked = W.elapsed + step, W.looked + step
		if W.looked >= LOOK then
			W.looked = 0
			Run(Lights)
		end
		if W.elapsed >= TICK then
			W.elapsed = 0
			if Allowed() then
				Run(Tick)
			else
				Close()
			end
		end
	end)
	Special()
	PaintLook()
	Place()
end

-- Opens the window, with an item when one is given. An opening asked for in a fight before the window was made waits for the fight's end, once.
local function Open(link)
	if link then
		W.link, W.offset = link, 0
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
						Run(function()
							Open()
						end)
					end
				end)
			end
			return
		end
		Make()
	end
	if W.frame:IsShown() then
		Refresh()
	else
		Place()
		W.frame:Show()
	end
end

-- Closes the window. Plain code, so it also works once the part has stopped.
function Close()
	W.opening = false
	if W.frame then
		pcall(W.frame.Hide, W.frame)
	end
	Want(false)
end

-- The contract (design 4.3) ----------------------------------------------------------------------------------------------------------------------

-- Opens or closes the window (/flatui gear, the tab's Gear comparison window row). True when it opened, closed or waits for the end of the fight;
-- false, with a line that says why, when Chat and tooltips or this part is off.
function ns.GearWindowToggle()
	if W.opening then
		W.opening = false
		return true
	end
	if W.frame and W.frame:IsShown() then
		Close()
		return true
	end
	if not Allowed() then
		print(Refusal())
		return false
	end
	return Run(Open)
end

-- Opens the window with an item (/flatui gear <item>): a link, an item string or an item ID; with none it opens with the item it had.
function ns.GearWindowShow(link)
	if not Allowed() then
		print(Refusal())
		return false
	end
	return Run(Open, AsItem(link))
end

-- The window has a handle in the movers while it may show, open or not, as Bags' windows have one while Bags is on (BagsWindow.lua:2162-2169).
function ns.GearWindowShown()
	return Allowed()
end

-- The movers set or put back the window's spot: it hangs from it now.
function ns.GearWindowMoved()
	W.placed, W.dropped = nil, nil
	if W.frame then
		Run(Place)
	end
end

-- Called at the end of each refresh of Chat.lua: the window closes while the module or this part is off, and takes the look of the Windows page again
-- after a change of it; a row of the tab worked out again comes with the next look (Tick).
function ns.GearWindowSync()
	if not Allowed() then
		Close()
		return
	end
	if W.frame then
		W.dirty = true
		Run(PaintLook)
	end
end

-- The line of /flatui status, only while the window is open with an item (design 4.12).
if type(ns.AddStatus) == "function" then
	ns.AddStatus(KEY, function()
		local frame = W.frame
		if not (frame and W.link and Allowed()) then
			return {}
		end
		local ok, shown = pcall(frame.IsShown, frame)
		if not ok or shown ~= true then
			return {}
		end
		local _, name = LinkParts(W.link)
		local look = W.view and W.view.item or nil
		return { T.STATUS:format(name or (look and look.name) or "an item") }
	end)
end
