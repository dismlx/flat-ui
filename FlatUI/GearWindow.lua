local _, ns = ...

-- The Gear comparison window (design 2.7): the part "gear window" of Chat and tooltips, a small window of Flat UI's own, FlatUIGear, with the whole
-- profile of the spells chosen for the gear comparison (ns.GearChosen, GearLines.lua), each now and with an item, as a cast, a second or threat. It is
-- the place to drop items and spells on, and it works with Your spells in item tooltips off: it is a tool of its own, and the list rows of the Spells
-- and gear tab serve both. /flatui gear opens and closes it (ns.GearWindowToggle); the tab's Gear comparison window row opens it, or raises it when it
-- is open, and /flatui gear <item> shows that item in it (ns.GearWindowShow); Escape closes it; the item and the switch are kept for the session.
-- While avoidance shows (Avoidance of the Spells and gear tab, GearAvoid.lua's A.Wanted) the switch has a fourth word, Avoidance: the attack table
-- of an enemy's swing, armor and block value now and with the item, in the rows and words GearAvoid.lua writes (A.Window), which this file draws in
-- the same columns; a tank's window starts on it, and its lines have no spell, so they have no tooltip and a right click takes nothing off.
-- A fight is InCombatLockdown's answer (WL/apis.yaml:39650), a withheld one counting as a fight; the time of a drop is GetTime's (:39050).
-- Everything runs as the part "gear window" of the chat module (ns.EachPart, Core.lua:2193-2224), each run with a count of its own as its first
-- argument, so three faults stop the window alone with a line for /flatui status (design 4.4); the first fault also goes to the game's error handler
-- (geterrorhandler), as Bags' parts report theirs (Bags.lua:356-374), and a part that stopped closes the window. The files it reads, SpellModel.lua,
-- GearModel.lua and GearLines.lua, are looked up when called, since any of them may load after this one or fail; a fault of one of their functions
-- goes to the error handler once, and the window goes on with what the other lines give. M.Want("gear window") has SpellModel listen to the game's
-- events while the window shows and lets go when it hides; M.State and M.Stats first read what an event marked (design 4.3, 4.5).
-- The look is the Windows page's, as Bags' windows have it (BagsWindow.lua:499-552): the Background colour at Window opacity with a thin border in the
-- general border colour (ns.Outline, whose page is the Windows page, so the chat page's own border does not reach it, Core.lua:321), the icon's box in
-- Button and slot colour, the chosen word of the switch and the light under the cursor in the Highlight colour, the icon cut by Icon crop
-- (SetTexCoord), and the text of the windows (PanelLook.lua:27-28) in font strings of Flat UI's own (ns.OwnText), measured as they wrap
-- (GetUnboundedStringWidth, GetStringHeight, WL/uiobjects.yaml:3738, 3711) so each part is as tall as what it shows. ns.GearWindowSync, at the
-- end of each refresh of Chat.lua, closes the window while the module or the part is off and paints it again after a change of those rows, which
-- refresh the chat module (Core.lua, READERS).
-- Tooltips are GameTooltip, never in a fight, as Bags' item tooltips wait (Core.lua:146): SetOwner, AddLine for this window's lines, Show, and Hide only
-- while a frame of the window owns it (IsOwned); a line's own spell (SetSpellByID, Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua:560) and the
-- item (SetHyperlink, :590) come from secure accessors of the game's tooltip data (:488-519), which answer true when they built one.
-- The numbers are GearModel's, so the window and the item tooltips agree, written as design 2.3 rounds them with SpellModel's M.Fmt, as the item
-- tooltips write them (Figure, Change, Percent): a cast whole from 100 up and with one decimal below, a second (row.perSecond: dps, a second, or the
-- threat of what rides on the swings) with one decimal, the change in green for a gain, red for a loss and grey for none, with its percent, and ~
-- first for an estimate (the threat's own for a threat figure).
-- The item: its name in its quality colour from the link, which needs nothing loaded, else from C_Item.GetItemInfo (WL/apis.yaml:16525) and the
-- game's colour of its quality (ColorManager.GetColorDataForItemQuality, Blizzard_Colors/Mainline/ColorManager.lua:52-60, which has every quality,
-- else C_Item.GetItemQualityColor, WL/apis.yaml:16726); its icon from C_Item.GetItemInfoInstant (:16569), which never waits. An item the client has
-- not loaded is asked for once (C_Item.RequestLoadItemDataByID, :17160), as Bags asks (BagsData.lua:1649), and the next look finds it. What it would
-- take the place of is named from the worn items SpellModel read (S.state.links), else GetInventoryItemLink (:36977). The name of a line is
-- GearLines.lua's, else the game's (C_Spell.GetSpellName, :26753); the role is S.state's, else ns.PlayerRole's, and the level S.state's, else
-- UnitLevel's (:43168).
-- Working it out: with an item G.Compare (the slots it would take, each line now and with it), with none G.Expect of each line in the figure G.Figure
-- gives it for the switch (design 4.3), with the rows of the tab and G.Inputs. An item is first put to the test of the item tooltips
-- (ns.GearWearable, GearLines.lua, on the lines C_TooltipInfo.GetHyperlink gives for it): one the player can never wear (its type, class or race) is
-- not compared, and the place line says so over the lines as with no item; for one the player cannot wear yet, "Not wearable yet:" says what it
-- needs, G.Compare's notYet else the test's (a type the player has yet to learn). It is worked out again out of combat only, when SpellModel's version
-- (M.Version: the state, the stats, talents, gear, role and the rows of the tab), the version of the list (ns.GearListVersion), the switch or the item
-- changed, looked at every half second while it shows; in a fight it keeps its numbers and its foot says the stats are from before the fight. A drop,
-- the switch and a line taken off are worked out at once, also in a fight, where GearModel gives what it worked out before it (design 4.7).
-- Placing: the window hangs by its top left corner from its spot in the movers (ns.MoverSpot, Movers.lua:856-877), at the size below.
-- Dragging its title bar moves it (StartMoving and StopMovingOrSizing, WL/uiobjects.yaml:4797, 4813, with SetUserPlaced, :4778, so the client keeps no
-- place of its own), and where it is let go is saved as its spot: a box the window's size, its top left corner at the window's (GetRect and
-- GetEffectiveScale), goes to ns.MoverKit.Commit (Movers.lua:1721-1759). Movers asks ns.GearWindowShown whether it has a handle and calls
-- ns.GearWindowMoved when its spot is set or put back.
-- Size (0.5.20, the owner: "need to be able to resize window for comparison"): a grip at the bottom right corner sizes the window (SetResizable,
-- SetResizeBounds, StartSizing and StopMovingOrSizing, WL/uiobjects.yaml:4741, 4749, 4803, 4813) between 380 x 220 (wider when its title bar needs
-- more) and the size of UIParent (GetWidth, GetHeight, :7373, 7230), in whose units it is sized; where it is let go is kept for the character
-- (FlatUICharDB.gearWindow = { w, h }, ns.Character, Core.lua:2653-2656), which the window's box in the movers follows, and the handle is drawn again
-- (ns.MoverKit.ShowHandle). The columns share the width: each number column is as wide as its widest text and the name column takes what they
-- leave; the lines fill the height between the column heads and the notes and foot, the rest scrolls with the mouse wheel, and a thin bar at the
-- right edge and the name column's head say where. Its text has a size of its own (Text size of the window, chat.gearWinFont, 10 to 16), set on Flat
-- UI's own font strings with SetFont in the face and outline of GameFontHighlightSmall and GameFontHighlight (GetFont, SetFont, :3421, 3503), and
-- every unit of the window follows it. Reset the window (chat.gearWinReset: ns.GearWindowResetLines, ns.GearWindowResetPick) forgets the size and
-- saves the start of its entry as its spot (ns.MoverKit.Commit). At Detail of the lines' Compact (chat.tipDetail) the item's notes are one wrapped
-- line, joined with "; ", and so is the foot; at Full each is a line. While they leave fewer than three lines of the table room, the foot goes, then
-- the notes.
-- Overall (0.5.20, chat.gearTotals at Weighted; "totals for threat/avoidance/etc need to be made more easily understood for the total impact of an
-- item over another"): under the item, a line for each slot of the comparison with what the item does overall: GearModel's weighted means of the
-- lines' percent changes (G.Totals) for damage and healing, from the comparison at A cast, or A second while the switch says it, and for threat,
-- from the comparison at Threat for a tank or while the switch says Threat; and, while avoidance shows, GearAvoid's damage taken (A.Totals: what an
-- enemy's swing does after the attack table, armor and block value, as a share of a plain hit), whose change is better when it is less. A figure is
-- green when it is better for the player, red when worse, and grey under 0.05%, with its sign and ~ before an estimate, so colour is never all
-- that says it; a second line names the best and the worst line of them (each total's best and worst). Pointed at, it says how each is worked
-- out. Its Weight column sets how much a line counts (ns.GearSetWeight, GearLines.lua: 0 to 5 in steps of 0.5): a left click adds 0.5, a right
-- click takes 0.5 off, and a Shift-click (IsShiftKeyDown, WL/apis.yaml:40162) gives 1. The colours are those of the lines' style (M.Fmt.Style of
-- SpellModel.lua: label, good, bad), else the window's own, as the item tooltips' Overall line has them.
-- Against (0.5.20): a second, smaller item box under the item, empty for what the player wears. An item dropped on it, or Compare against in the item
-- finder (ns.GearWindowAgainst), is what the item is compared with instead: G.Compare and A.Compare take it as opts.base, and the place line says
-- "instead of" it when the comparison echoes it (result.base), else a note says it was not used. One that does not go in the item's slots (their
-- inventory types, C_Item.GetItemInfoInstant's fourth answer, WL/apis.yaml:16569, by the slot each type takes, GearModel.lua's K.EQUIP) is not
-- passed, and its box says so. Find on the title bar opens and closes the item finder beside the window (ns.GearSearchToggle, GearSearch.lua), is lit
-- while it shows (ns.GearSearchShown, looked at with the cursor), and the finder closes with the window.
-- Drops: what the cursor holds is GetCursorInfo's (WL/apis.yaml:36258). A spell is added to the list (ns.GearAdd, which says what it did): its ID is
-- GetCursorInfo's fourth answer, the second being its slot (Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua:137;
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:1953-1955), and a macro's is the spell it casts (GetMacroSpell, WL/apis.yaml:37417), as
-- Cooldowns reads a macro's (Cooldowns.lua:2571-2579). The cursor keeps the spell: one dragged off an action bar has left its slot already, and
-- ClearCursor would take it off the bar. An item dropped or clicked on the window is compared. One lifted from a bag, the bank or a worn slot, where
-- it stays locked while it rides the cursor (C_Cursor.GetCursorItem, :10071, a bag slot or a worn slot by its ItemLocationMixin, and C_Item.IsLocked,
-- :17097), goes back there with ClearCursor (:34956, not protected), also in a fight, as Bags' sections give a dropped item back
-- (BagsLayout.lua:1408-1425); any other, such as one dragged off an action bar (PickupAction takes it off the bar, Blizzard_ActionBar/Shared/
-- ActionButton.lua:1429-1437), stays on the cursor, as a spell does. The click that ends a drag on the window brings the same thing again, which
-- counts as that drop. A right click takes a line off the list (ns.GearRemove). While the cursor holds an item or a spell, the part of the window
-- that takes it is lit, looked at ten times a second, as Bags lights the titles that take an item (BagsLayout.lua:40-45).
-- The frame: CreateFrame on UIParent, named FlatUIGear, made the first time it opens and only out of combat (an opening asked for in a fight before
-- that waits for its end, ns.OutOfCombat), in the MEDIUM strata among the game's windows, or DIALOG when it shows while the options window does
-- (HIGH, Panel.lua:2654; ns.PanelShown), so the window its row there opens shows above it, as the Edit Mode layout text does (LayoutText.lua:38);
-- raised when clicked (SetToplevel, WL/uiobjects.yaml:4770),
-- kept on the screen (SetClampedToScreen) and placed by Flat UI alone (SetMovable, SetDontSavePosition, :4605). The mouse wheel scrolls its lines when
-- there are more than it holds (EnableMouseWheel, :7184). Its name goes once into UISpecialFrames, whose windows the game's CloseSpecialWindows hides
-- on Escape (Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:21-27, 1104-1116). It adds a line to /flatui status while it is open with
-- an item (ns.AddStatus, design 4.12), and tells GearLines.lua whether it is open (ns.GearWindowOpen), whose status lines show then too.
-- It registers no event: it looks on the OnUpdate of its own frame while it shows. Every frame, texture and font string here is Flat UI's own.

local KEY, PART = "chat", "gear window"
-- The owner M.Want knows the window by, and the window's name, which the movers and UISpecialFrames know it by.
local OWNER, NAME = "gear window", "FlatUIGear"
-- The box of the window's entry in Movers.lua, and where it starts while no spot is saved: its top left corner this far from the top left corner of
-- the screen, right of the Character window (design 5.1). That window is 631 wide on this client (CHARACTER_FRAME_WIDTH, its stats pane open, as
-- characterFrameCollapsed 0 has it: Blizzard_UIPanels_Game/Camelot/CharacterFrameConstants.lua:4, 7) at the left panel's spot, 16 from the left
-- and 116 down (Blizzard_UIParentPanelManager/Shared/UIPanelLayoutFrame.lua:3-4), and the game leaves 32 between panels (:8): 16 + 631 + 32.
local BOX = { width = 460, height = 420, x = 680, y = -120 }
-- The window's size: at least 380 x 220 (owner, 0.5.20), at most the screen, and 460 x 420 until the player sizes it, room for the item, Against,
-- the Overall lines and about ten lines of the table at the first text size.
local SIZE = { MIN_W = 380, MIN_H = 220, W = 460, H = 420 }
-- Units: the padding on each side; the close cross, the room around the text of a word of the switch and between two; the space after the icon of
-- an item, between two parts, between two dim lines and before a cell's neighbour; the side of the grip, the width of the scroll bar and its least
-- height. The rest follow the text size (Units).
local L = { PAD = 8, CLOSE = 18, WORD_ROOM = 10, WORD_GAP = 9, ICON_GAP = 8, GAP = 6, LINE_GAP = 2, CELL_GAP = 6, GRIP = 14, THUMB = 2,
	THUMB_LEAST = 8 }
-- At a text size: the title bar, a word of the switch, the icons of the item and of Against, the column heads and a line of the table (design 2.7:
-- 16 and 18 at the size 12 the design's units are for), a line of text when the client does not say, and the least width of the name column.
local function Units(size)
	L.SIZE = size
	L.BAR, L.WORD, L.ICON, L.SMALL_ICON = size + 14, size + 6, math.floor(size * 2.5 + 0.5), size + 8
	L.HEAD, L.ROW, L.LINE, L.NAME = size + 4, size + 6, size, size * 6
end
Units(12)
-- Text size of the window (chat.gearWinFont): 10 to 16, 12 at first. The title and the item's name are a size larger.
local FONT_SIZE = { MIN = 10, MAX = 16, FIRST = 12 }
-- The columns of the table (design 2.7), left to right: the cell, its head and, for a change, the slot of the comparison it shows (%s in its head is
-- that slot): with no item the spell and what it does now; with an item that takes one slot, what it does with the item and the change; with an item
-- that can take either of two slots (rings, trinkets, a one-hand weapon of a dual wielder), the change in each and no With. Weight comes last while
-- Overall counts the lines. The first is aligned left and takes the width the others leave; each other is as wide as its widest text (Layout).
local COLUMNS = {
	none = { { "name", "Spell" }, { "now", "Now" } },
	one = { { "name", "Spell" }, { "now", "Now" }, { "with", "With" }, { "change", "Change", 1 } },
	two = { { "name", "Spell" }, { "now", "Now" }, { "change", "Change %s", 1 }, { "change", "Change %s", 2 } },
}
local WEIGHT_COLUMN = { "weight", "Weight" }
-- A line's weight in Overall (ns.GearSetWeight, GearLines.lua): 0 to 5 in steps of 0.5, 1 when the list has none.
local WEIGHT = { MIN = 0, MAX = 5, STEP = 0.5, FIRST = 1 }
-- The figures of the Overall line, in order: the key in G.Totals' or A.Totals' answer, its word, and whether more is better (1) or less (-1).
local FIGURES = { { "damage", "Damage", 1 }, { "healing", "Healing", 1 }, { "threat", "Threat", 1 }, { "taken", "Damage taken", -1 } }
-- The inventory types an item of Against must share with the item, by the slots each takes (GearModel.lua's K.EQUIP): a weapon or what is held in
-- a hand against any other, a ring against a ring.
local GROUPS = {
	INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_BODY = "shirt", INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest",
	INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands", INVTYPE_FINGER = "finger",
	INVTYPE_TRINKET = "trinket", INVTYPE_CLOAK = "back", INVTYPE_WEAPON = "hand", INVTYPE_2HWEAPON = "hand", INVTYPE_WEAPONMAINHAND = "hand",
	INVTYPE_WEAPONOFFHAND = "hand", INVTYPE_SHIELD = "hand", INVTYPE_HOLDABLE = "hand", INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged",
	INVTYPE_THROWN = "ranged", INVTYPE_RELIC = "ranged", INVTYPE_AMMO = "ammo", INVTYPE_TABARD = "tabard",
}
-- The three figures of the switch in the title bar (design 2.3), left to right, and what each says when pointed at; and Avoidance, the attack table of
-- an enemy's swing (GearAvoid.lua), which shows while avoidance shows (A.Wanted).
local MODES = { { "cast", "A cast" }, { "second", "A second" }, { "threat", "Threat" }, { "avoid", "Avoidance" } }
local WORD_TIPS = {
	cast = "What one cast does: its expected damage or healing, or its threat for a line that does no damage. Your auto attack, Auto Shot and wand count one swing or shot.",
	second = "What a second does: a cast over its cast time (at least the global cooldown), a spell over time over its duration, your swings and shots over their speed. A strike that takes the place of your next swing has none.",
	threat = "The threat of one cast, and of a second of what rides on your swings and shots (your auto attack, Auto Shot, wand and seals), with your stance, form, Righteous Fury and talents.",
	avoid = "How often an enemy's swing misses you, is dodged, parried or blocked, crits or crushes, and what your armor and block value take off: now, and with the item in each slot it can take. Avoidance on the Spells and gear tab chooses when it shows.",
}
-- Against at its first choice is a boss three levels above at the top level, else an enemy of the player's level (design 2.5, 4.9). The hit caps of
-- Hit cap against a boss and of the hit table's row of the same name (Config.lua, hud.hitTableRules).
local MAX_LEVEL = 60
local CAPS = { classic = "9% melee, 16% spells", game = "8% melee, 17% spells" }
-- The slots by their number (INVSLOT_AMMO to INVSLOT_TABARD), as the comparison names them (design 2.3, 2.4).
local SLOTS = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
	"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" }
-- What a cast is for the comparison kinds whose cast is no spell cast (design 2.3; GearModel.lua's G.Figure): a swing of Attack, a shot of Auto
-- Shot and of Shoot with a wand, a hit of a seal and one proc of a proc, as the name of a line says it at A cast.
local CASTS = { auto = "a swing", shot = "a shot", wand = "a shot", seal = "a hit", proc = "a proc" }
-- The forms whose swing a weapon ability counts its attack power at (GetShapeshiftFormID: Cat Form 1, Bear Form 5, Dire Bear Form 8, as D.RULES has
-- them), the slot of each hand of a weapon part (design 3.2), and the normalized and form speeds when the data gives none (D.MODEL, SpellData.lua).
local FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }
local HANDS = { main = 16, off = 17, both = 16, ranged = 18 }
local NORM, SWING = { one = 2.4, dagger = 1.7, two = 3.3, ranged = 2.8 }, { cat = 1.0, bear = 2.5 }
-- Seconds between two looks at what the window was worked out from, and at the cursor; how soon the same item or spell again counts as the same drop
-- (the click that ends a drag on the window).
local TICK, LOOK, DROP_AGAIN = 0.5, 0.1, 0.3
-- The dim lines the window holds under its table (the item's notes) and in its foot, the lines of Overall, the most lines of the table it makes,
-- the lines the notes and the foot give way for, and the separators' opacity.
local NOTES, FOOT, OVERALL, MOST_ROWS, LEAST_ROWS = 10, 7, 4, 80, 3
local SEPARATOR = 0.07
local FONT, TITLE_FONT = "GameFontHighlightSmall", "GameFontHighlight"
-- The text of the windows (PanelLook.lua:27-28: text-dim and text-faint of graphite, as the Threat list and the hit table have them) and white; the
-- grey of Flat UI's extra tooltip lines (Chat.lua:801) for no change, and the green and red Flat UI's combat numbers give a gain and a loss
-- (CombatText.lua:889-894), as the item tooltips colour a change (design 2.3).
local DIM, FAINT, PLAIN = { 0.66, 0.68, 0.62 }, { 0.48, 0.50, 0.45 }, { 1, 1, 1 }
local TONES = { gain = { 0.1, 1, 0.1 }, loss = { 1, 0.1, 0.1 }, none = { 0.8, 0.8, 0.8 } }
-- The label grey of the lines' style, while SpellModel.lua's M.Fmt.Style is not there.
local LABEL = { 0.82, 0.82, 0.82 }
-- The words of the window. Flat UI's lines are English, as its other extra lines (design 6.22).
local T = {
	TITLE = "Gear comparison",
	DROP = "Drop an item here, find one with Find, or type /flatui gear and shift-click an item into the chat line.",
	EMPTY = "Drag a spell from your spell book onto this window.",
	NO_MODEL = "The spell data of Chat and tooltips is not running, so there is nothing to work out. /flatui status says why.",
	NO_LIST = "The list of spells of Chat and tooltips is not running, so there is nothing to show. /flatui status says why.",
	NO_ADD = "Gear comparison: the list of spells is not running, so the spell was not added.",
	LOADING = "The game has not loaded this item yet.",
	NOT_COMPARED = "This item is not compared with what you wear.",
	NEVER = "You cannot wear this item.",
	NOT_YET = "Not wearable yet.",
	NOT_YET_LINE = "Not wearable yet: ",
	NOT_COUNTED_LINE = "Not counted: ",
	NO_CHANGE = "No change to your chosen spells; stamina, armor, avoidance and mana are not counted.",
	RANDOM = "Random stats not known.",
	IN_PLACE = "instead of %s (%s)",
	IN_PLACE_OFF = "instead of %s, off hand empty",
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
	SCROLLED = "%d to %d of %d",
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
	CLEAR = "Right-click to take the item out of the window.",
	OFF = "Gear comparison: turn on Restyle chat and tooltips on the Chat and tooltips page first.",
	MODULE_STOPPED = "Gear comparison: Chat and tooltips stopped after an error. /flatui status says why.",
	STOPPED = "Gear comparison: the window stopped after an error. /flatui status says why.",
	AFTER_FIGHT = "Gear comparison: the window opens when the fight ends.",
	STATUS = "Gear comparison window: open, comparing %s.",
	STATUS_AGAINST = "Gear comparison window: open, comparing %s against %s.",
	FIND = "Find",
	FIND_LINES = { "Opens and closes the item finder beside this window: every item by name, slot, armor and weapon type, or what is in your bags, your bank and on your other characters.",
		"Click an item there to compare it here; right-click it to compare against it." },
	NO_FIND = "Gear comparison: the item finder is not there.",
	AGAINST = "Against",
	AGAINST_LABEL = "Against: ",
	AGAINST_HINT = "what you wear. Drop an item here to compare with that one instead.",
	AGAINST_OTHER = "not for this slot, so compared with what you wear",
	AGAINST_UNUSED = "The item of Against was not used; the numbers are against what you wear.",
	AGAINST_TIP = { "Empty, the item is compared with what you wear in its slot.",
		"Drop an item here, or right-click one in the item finder, to compare with that one instead." },
	AGAINST_CLEAR = "Right-click to compare with what you wear again.",
	OVERALL = "Overall",
	OVERALL_SLOT = "Overall, %s",
	BEST = "Best",
	WORST = "Worst",
	OVERALL_LINES = {
		"Damage, Healing and Threat: the mean of the percent changes of your lines with the item, each line counted as often as its weight (the Weight column; 0 leaves it out). Damage and healing are at A cast, or A second while the switch says it; threat at Threat.",
		"Damage taken: what an enemy's swing does to you after misses, dodges, parries, blocks, crits, crushing blows and armor, as a share of a plain hit, so less is better. Block value counts against an enemy hit of %s before armor (Enemy hit for block value, an estimate).",
		"Green is better for you and red worse; ~ marks an estimate.",
	},
	WEIGHT_TIP = "Weight %s",
	WEIGHT_LINES = { "How much this line counts in the Overall line: 0 leaves it out, 5 counts it five times.",
		"Left-click: +0.5. Right-click: -0.5. Shift-click: back to 1." },
	NO_WEIGHT = "Gear comparison: the list of spells is not running, so the weight was not changed.",
	GRIP = "Size",
	GRIP_LINES = { "Drag to size the window; its size is kept for this character.",
		"Reset the window on the Spells and gear tab puts its size and place back." },
	RESET_LINE = "Put its size and place back",
	RESET_DONE = "Gear comparison: the window is back at its first size and place.",
	RESET_FAILED = "Gear comparison: the window could not be put back. /flatui status says why.",
	REPORT = "Flat UI, Gear comparison window, %s: %s",
}
-- The noun of each kind of weapon a normalized part counts as (design 2.5: dagger 1.7, other one-hand 2.4, two-hand 3.3, ranged 2.8).
local WEAPONS = { one = "one-hand weapon", dagger = "dagger", two = "two-hand weapon", ranged = "ranged weapon" }

local IsSecret = ns.IsSecret

-- The state of the window. frame: FlatUIGear, made the first time it opens, and outline its background and border. bar, title, words (the switch),
-- seps, close, find (Find: button, text, width); item: the area of the item (button, box, outline, icon, name, place, hint, hover, light); against:
-- the box of Against (button, box, outline, icon, text, hover, light); overallBox and overall, the Overall lines; headRow and heads; rows, each {
-- button, hover, cells, weight = { button, text, hover }, row }, made as the height needs them; message; notes and foot, the pools of dim lines;
-- rules; tableLight; thumb, the scroll bar; grip; measure, a hidden text that measures the columns; texts, every font string with whether it is a
-- title, for SetFont; owners: the frames whose tooltip the window writes. fontSize: the text size the window is drawn at; barNeed: the least width
-- its title bar takes. mode: the figure of the switch; chosen: the player picked it, so it is kept for the session. link: the item compared and
-- base the item of Against, both kept for the session; used: base while it goes in the item's slots, which the comparison is given. view: what
-- Compute worked out and Paint draws; drawn: the key it was worked out for; fight: it was drawn in a fight; dirty: a row of the chat module
-- changed. offset: the first line shown, shown: how many lines of the table show now. wanted: M.Want has the window. opening, queued: an opening
-- asked for in a fight before the frame was made waits for the fight's end. moving, sizing, placed, dropped: a drag of the title bar or of the
-- grip, the spot the window was put at, and where it was let go while the movers could not keep it; relayout: its size changed, so it is drawn
-- again at the next frame. runs: the count of the part's runs. faults: what went to the error handler already. requested: the items the client
-- was asked to load. elapsed, looked: the time since the last look at the view and at the cursor. held, heldAt: the last item or spell dropped,
-- and when. searching: the item finder showed at the last look.
local W = { mode = "cast", chosen = false, offset = 0, shown = 0, runs = 0, faults = {}, requested = {}, elapsed = 0, looked = 0, words = {},
	rows = {}, notes = {}, foot = {}, overall = {}, rules = {}, owners = {}, texts = {} }

local Refresh, Paint, PaintLook, Close, Drop, Place, Dropped, MakeRow

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
-- for each first argument and stops the part at the third (Core.lua:2203, 2210-2219). A part that stopped closes the window.
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

-- The text size of the window (Text size of the window), whole and between 10 and 16.
local function FontSize()
	local size = Opt("gearWinFont")
	if not Finite(size) then
		return FONT_SIZE.FIRST
	end
	return math.max(FONT_SIZE.MIN, math.min(FONT_SIZE.MAX, math.floor(size + 0.5)))
end

-- The face and outline of one of the game's font objects (GetFont), which the window's own size is set in; nil while the client does not say.
local function Face(object)
	local font = _G[object]
	if type(font) ~= "table" or IsSecret(font) then
		return nil
	end
	local ok, file, _, flags = pcall(font.GetFont, font)
	if not (ok and Text(file)) then
		return nil
	end
	return file, (not IsSecret(flags) and type(flags) == "string") and flags or ""
end

-- Sets a font string of the window at the text size, a title a size larger, in the face of its font object; one the client refuses keeps the
-- font object's own size.
local function Sized(text, big)
	local file, flags = Face(big and TITLE_FONT or FONT)
	if file then
		pcall(text.SetFont, text, file, (W.fontSize or FONT_SIZE.FIRST) + (big and 1 or 0), flags)
	end
end

local function Label(parent, font, wrap)
	local text = ns.OwnText(parent, "OVERLAY", font or FONT)
	if not text then
		error("no font string", 0)
	end
	text:SetJustifyH("LEFT")
	text:SetWordWrap(wrap == true)
	local big = font == TITLE_FONT
	W.texts[#W.texts + 1] = { text, big }
	Sized(text, big)
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
	return #(words or "") * L.SIZE / 2
end

-- The height of a text as it wraps now, else the height of one line, as Flat UI setup measures its own (SetupWelcome.lua:34-41).
local function Height(text)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and Finite(height) and height > 0 and height < 2000 then
		return math.ceil(height)
	end
	return L.LINE
end

local function Colour(text, colour)
	text:SetTextColor(colour[1], colour[2], colour[3], 1)
end

-- A colour of the lines' style (SpellModel.lua's M.Fmt.Style: header, label, value, good, bad, dim), else the window's own.
local function Styled(name, fallback)
	local fmt = type(ns.SpellModel) == "table" and ns.SpellModel.Fmt or nil
	local style = type(fmt) == "table" and not IsSecret(fmt) and fmt.Style or nil
	local colour = type(style) == "table" and style[name] or nil
	if type(colour) == "table" and Finite(colour[1]) and Finite(colour[2]) and Finite(colour[3]) then
		return colour
	end
	return fallback
end

-- The colour of a change's tone: green for a gain, red for a loss (the style's good and bad), grey for none.
local function ToneColour(tone)
	if tone == "gain" then
		return Styled("good", TONES.gain)
	elseif tone == "loss" then
		return Styled("bad", TONES.loss)
	end
	return TONES.none
end

local function HexOf(colour)
	return Hex(colour[1], colour[2], colour[3])
end

-- True while the item finder (GearSearch.lua) shows.
local function Searching()
	return Ask(ns, "GearSearchShown") == true
end

-- The switch and Find: the chosen word and Find while the finder shows in the Highlight colour, the one under the mouse white, the others dim
-- (design 2.7).
local function PaintWords()
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	local words = { W.find }
	for _, word in ipairs(W.words) do
		words[#words + 1] = word
	end
	for _, word in ipairs(words) do
		local chosen = word.mode == nil and Searching() or (word.mode ~= nil and word.mode == W.mode)
		if chosen then
			word.text:SetTextColor(ar, ag, ab, 1)
		elseif word.over then
			Colour(word.text, PLAIN)
		else
			Colour(word.text, DIM)
		end
	end
end

-- True while the Avoidance view shows (GearAvoid.lua, A.Wanted: Avoidance of the Spells and gear tab).
local function Avoiding()
	return Ask(ns.GearAvoid, "Wanted") == true
end

-- A word of the switch or Find as wide as its text and its room, as tall as a word.
local function SizeWord(word)
	word.width = math.ceil(TextWidth(word.text, word.label)) + L.WORD_ROOM
	word.button:SetSize(word.width, L.WORD)
end

-- The title bar from the right: the close cross, the words of the switch, each with the separator on its left (Avoidance, the last, only while it
-- shows); and from the left the title, cut to the room left, and Find after it.
local function PlaceBar(width)
	local x, bar = -(4 + L.CLOSE + L.WORD_GAP), W.bar
	for index = #W.words, 1, -1 do
		local word = W.words[index]
		local shown = word.mode ~= "avoid" or Avoiding()
		word.button:SetShown(shown)
		if word.sep then
			word.sep:SetShown(shown)
		end
		if shown then
			word.button:ClearAllPoints()
			word.button:SetPoint("RIGHT", bar, "RIGHT", x, 0)
			x = x - word.width
			if word.sep then
				word.sep:ClearAllPoints()
				word.sep:SetPoint("CENTER", bar, "RIGHT", x - L.WORD_GAP / 2, 0)
				x = x - L.WORD_GAP
			end
		end
	end
	local find, title = W.find, W.title
	local room = width + x - L.WORD_GAP - L.PAD - find.width - L.WORD_GAP
	local titled = room >= 3 * L.SIZE
	local titleWidth = titled and math.min(math.ceil(TextWidth(title, T.TITLE)), room) or 0
	title:SetShown(titled)
	title:SetWidth(math.max(1, titleWidth))
	find.button:ClearAllPoints()
	find.button:SetPoint("LEFT", bar, "LEFT", L.PAD + (titled and titleWidth + L.WORD_GAP or 0), 0)
end

-- The parts whose size follows the text size: the title bar, its words and Find, the boxes of the item and of Against; and the least width the
-- title bar takes, with Avoidance shown.
local function SizeParts()
	W.bar:SetHeight(L.BAR)
	local need = L.PAD + L.WORD_GAP + L.WORD_GAP + 4 + L.CLOSE + L.WORD_GAP
	for index, word in ipairs(W.words) do
		SizeWord(word)
		need = need + word.width + (index > 1 and L.WORD_GAP or 0)
	end
	SizeWord(W.find)
	W.barNeed = math.ceil(need + W.find.width)
	W.item.box:SetSize(L.ICON, L.ICON)
	W.against.box:SetSize(L.SMALL_ICON, L.SMALL_ICON)
end

-- The colours of a line of the table: its light under the mouse and that of its weight.
local function RowLook(slot, ar, ag, ab)
	slot.hover:SetColorTexture(ar, ag, ab, 0.12)
	slot.weight.hover:SetColorTexture(ar, ag, ab, 0.18)
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
	for _, area in ipairs({ W.item, W.against }) do
		ns.SetOutlineFill(area.outline, pr, pg, pb, 1)
		ns.SetOutline(area.outline, true, true)
		area.hover:SetColorTexture(ar, ag, ab, 0.08)
		area.light:SetColorTexture(ar, ag, ab, 0.14)
	end
	W.tableLight:SetColorTexture(ar, ag, ab, 0.08)
	W.thumb:SetColorTexture(ar, ag, ab, 0.5)
	for _, rule in ipairs(W.rules) do
		rule:SetColorTexture(1, 1, 1, SEPARATOR)
	end
	for _, sep in ipairs(W.seps) do
		sep:SetColorTexture(1, 1, 1, 0.2)
	end
	for _, group in ipairs({ W.close, W.grip }) do
		for _, line in ipairs(group.lines) do
			line:SetColorTexture(1, 1, 1, group == W.grip and 0.35 or 0.6)
		end
		for _, line in ipairs(group.hover) do
			line:SetColorTexture(ar, ag, ab, 1)
		end
	end
	for _, slot in ipairs(W.rows) do
		RowLook(slot, ar, ag, ab)
	end
	Colour(W.title, PLAIN)
	for _, text in ipairs({ W.item.place, W.item.hint, W.message }) do
		Colour(text, DIM)
	end
	Colour(W.against.text, PLAIN)
	for _, text in ipairs(W.heads) do
		Colour(text, DIM)
	end
	for _, pool in ipairs({ W.notes, W.foot }) do
		for _, text in ipairs(pool) do
			Colour(text, DIM)
		end
	end
	for _, text in ipairs(W.overall) do
		Colour(text, PLAIN)
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

-- The rounding of design 2.3, SpellModel.lua's (M.Fmt), which the item tooltips write their numbers with too, or nil.
local function Fmt(name)
	local fmt = type(ns.SpellModel) == "table" and ns.SpellModel.Fmt or nil
	return Fn(fmt, name)
end

-- A figure now or with the item (M.Fmt.Figure: a second with one decimal, any other whole from 100 up and with one decimal below): - when the line
-- has none in this figure, ~ first for an estimate.
local function Value(value, second, estimate)
	if not Finite(value) then
		return "-"
	end
	local figure = Fmt("Figure")
	return (estimate and "~" or "") .. (figure and figure(value, second) or ("%.1f"):format(value))
end

-- The change from now to with, signed (M.Fmt.Change), with the percent of the figure now (M.Fmt.Percent: one decimal and its sign, (0%) under
-- 0.05%, none when the figure now is 0), and its tone: gain, loss or none (design 2.3). An estimate starts with ~ and keeps the tone of its
-- direction.
local function Change(now, with, second, estimate)
	if not (Finite(now) and Finite(with)) then
		return "-", "none"
	end
	local delta = with - now
	local change, percent = Fmt("Change"), Fmt("Percent")
	local text = change and change(delta, second) or ("%+.1f"):format(delta)
	local tone = "none"
	if math.abs(delta) >= 0.05 then
		tone = delta > 0 and "gain" or "loss"
	end
	if now ~= 0 then
		local share = delta / math.abs(now)
		text = text .. " (" .. (percent and percent(share) or ("%+.1f%%"):format(share * 100)) .. ")"
	end
	return (estimate and "~" or "") .. text, tone
end

-- A share as a signed percent with one decimal, 0% under 0.05% (M.Fmt.Percent).
local function Share(share)
	local percent = Fmt("Percent")
	return percent and percent(share) or ("%+.1f%%"):format(share * 100)
end

-- The tone of a share for the player: gain when it is better (more, or less where less is better), loss when worse, none under 0.05%.
local function ShareTone(share, better)
	if math.abs(share) < 0.0005 then
		return "none"
	end
	return share * (better or 1) > 0 and "gain" or "loss"
end

-- A line's weight in Overall (its record's weight, GearLines.lua), 1 while it has none.
local function WeightOf(line)
	local weight = type(line) == "table" and line.weight or nil
	if Finite(weight) then
		return math.max(WEIGHT.MIN, math.min(WEIGHT.MAX, weight))
	end
	return WEIGHT.FIRST
end

-- A weight as the Weight column writes it: 1, 2.5, 0.
local function WeightText(weight)
	return (("%.1f"):format(weight):gsub("%.0$", ""))
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

-- An item as the window shows it: { id, name, text (the name in its quality colour), icon, equip (its inventory type), loaded }. The name and colour come from the link first,
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
		local ok, _, _, _, equip, icon = pcall(instant, link)
		if ok and not IsSecret(icon) and (Finite(icon) or Text(icon)) then
			look.icon = icon
		end
		look.equip = ok and Text(equip) or nil
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

-- False when the item of Against does not go in the item's slots (their inventory types, GROUPS), true when it does, nil while either type is not
-- known: then it is passed and the comparison decides.
local function SameSlot(link, base)
	local one, other = ItemLook(link).equip, ItemLook(base).equip
	local a, b = one and GROUPS[one], other and GROUPS[other]
	if not (a and b) then
		return nil
	end
	return a == b
end

-- What the item would take the place of, one phrase for each slot of the comparison (design 2.4): the worn items with the slot, a two-hander whose
-- off hand a one-hander leaves empty (offEmpty), or the empty slot, as GearModel.lua's header of a candidate words it; with an item of Against the
-- comparison used (base), that item in each slot.
local function PlaceLine(cands, state, base)
	local phrases = {}
	for _, c in ipairs(cands) do
		local where, names = Where(c), {}
		if base then
			names[1] = ItemLook(base).text
		elseif not c.empty then
			for _, slot in ipairs(type(c.slots) == "table" and c.slots or {}) do
				local link = Finite(slot) and Worn(state, slot) or nil
				if link then
					names[#names + 1] = ItemLook(link).text
				end
			end
		end
		if #names > 0 and c.offEmpty == true and not base then
			phrases[#phrases + 1] = T.IN_PLACE_OFF:format(table.concat(names, " and "))
		elseif #names > 0 then
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

-- The number of G.Expect's answer a figure shows (design 2.3): a cast, a second, or threat, which GearModel gives a second for what rides on the
-- swings or shots (perSecond: Attack, Auto Shot, Shoot, the seals) and a cast for the rest.
local function Pick(e, figure)
	if type(e) ~= "table" or not figure then
		return nil
	end
	if figure == "cast" then
		return e.cast
	elseif figure == "second" or figure == "dps" then
		return e.second
	elseif figure == "threat" then
		return e.threat
	end
	return nil
end

-- What a line counts when it is not what the switch says (design 2.3): a swing, shot, hit or proc for A cast, threat for a line that does no damage,
-- a second for threat that rides on the swings (row.perSecond), and none at A second for a strike that takes the place of the next swing (G.Figure
-- gives it no figure there). Nil when the switch says it.
local function Counts(mode, row)
	local entry = EntryOf(row.line)
	local cmp, figure = entry and entry.cmp or nil, row.figure
	if not figure then
		return entry and entry.nx and mode == "second" and T.SWING_NONE or nil
	elseif figure == "threat" then
		if row.perSecond then
			return mode == "threat" and "a second" or "threat a second"
		end
		return mode ~= "threat" and "threat" or nil
	elseif figure == "cast" and CASTS[cmp] then
		return CASTS[cmp]
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

-- What the comparison counts with: the switch, the version of the list, the rows of the tab (design 4.9), the hit table inputs GearModel read at
-- the last plain read of the stats (G.Inputs) and the item of Against while it goes in the item's slots (base).
local function Options(mode)
	return {
		mode = mode, listVersion = Ask(ns, "GearListVersion"), against = Opt("gearAgainst"), facing = Opt("gearFacing"), rules = Opt("gearRules"),
		lowRank = Opt("spellLowRank") ~= false, inputs = Ask(ns.GearModel, "Inputs"), base = W.used,
	}
end

-- Working it out ---------------------------------------------------------------------------------------------------------------------------------

-- With no item, or one that cannot be compared: what each line does now, from G.Expect with the player's state and stats, in the figure G.Figure
-- gives it for the switch, with that figure's basis, whether it is a second and why it has none.
local function Profile(view, lines, state, stats)
	local model = ns.GearModel
	local opts = Options(view.mode)
	for _, line in ipairs(lines) do
		if type(line) == "table" then
			local row = { line = line, figure = Text(Ask(model, "Figure", line, view.role, view.mode)) }
			if row.figure then
				local e = Ask(model, "Expect", line, state, stats, opts)
				if type(e) == "table" then
					-- A threat figure takes the threat's basis, and is a second for what rides on the swings (GearModel.lua's header); with no
					-- figure it takes threatWhy, which says the threat is not known on Forever (Whirlwind's), as G.Compare's rows do.
					local threat = row.figure == "threat"
					row.now = Pick(e, row.figure)
					row.basis = Text(threat and e.threatBasis or e.basis)
					row.why = Text(e.why) or (threat and Text(e.threatWhy)) or nil
					row.estimate = row.basis == "e"
					row.perSecond = row.figure == "second" or row.figure == "dps" or (threat and e.perSecond == true)
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

-- The rows of an item compared (G.Compare's candidates, the first two): each line now, with the item in each slot, its figure, whether it is an
-- estimate or a second, its basis and why it has none. False when the item has no slot to compare with.
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
					row.perSecond = row.perSecond or found.perSecond == true
					row.basis = row.basis or Text(found.basis)
					row.why = row.why or Text(found.why)
					row.with[which] = found.with
				end
			end
			view.rows[#view.rows + 1] = row
		end
	end
	view.place = PlaceLine(cands, state, W.used and Text(result.base) or nil)
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
-- stats, and why it was not compared when the place line does not say it already. later is what the test of the item tooltips found the item needs
-- (Wearing), which says it when G.Compare's notYet does not, as for a type the player has yet to learn.
local function Notes(view, result, later)
	local notes = view.notes
	if result.notYet == true then
		Note(notes, T.NOT_YET)
	else
		Note(notes, Text(result.notYet) or later, T.NOT_YET_LINE)
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
	-- An item of Against the comparison did not echo was not used, so the numbers are against what is worn.
	if W.used and #view.cands > 0 and not Text(result.base) then
		Note(notes, T.AGAINST_UNUSED)
	end
end

-- Whether the player can wear the item: the test of the item tooltips (ns.GearWearable, GearLines.lua) on the lines of its link. True when the
-- player can never wear it (its type, class or race), else false and what it needs first, or nil; false when that file is not there or fails.
local function Wearing(link)
	local wearable = Fn(ns, "GearWearable")
	if not wearable then
		return false, nil
	end
	local ok, never, later = pcall(wearable, link)
	if not ok then
		Report("GearWearable", never)
		return false, nil
	end
	return not IsSecret(never) and never == true, Text(later)
end

-- The Avoidance view (GearAvoid.lua's A.Window): the attack table of an enemy's swing now, or with the item in each slot it can take (the first two),
-- its rows' texts and tones as that file writes them, its notes and its foot; what the item would take the place of as for the spells. Nil while
-- avoidance does not show.
local function AvoidView()
	if not Avoiding() then
		return nil
	end
	-- An item the player can never wear is not compared here either, as in the spell view: the table shows as now.
	local never = W.link ~= nil and (Wearing(W.link)) == true
	local got = Ask(ns.GearAvoid, "Window", not never and W.link or nil, W.used)
	if type(got) ~= "table" or type(got.rows) ~= "table" or not COLUMNS[got.layout] then
		return nil
	end
	local state, stats = Touch()
	local view = { mode = "avoid", layout = got.layout, rows = got.rows, notes = got.notes or {}, cands = got.cands or {}, heads = got.heads,
		foot = got.foot, noStats = type(stats) ~= "table", old = type(stats) == "table" and stats.old == true, never = never, role = Role(state) }
	if W.link then
		view.item = ItemLook(W.link)
		-- The item of Against the table was worked out with: the view's echo of it, else its candidates'.
		local first = view.cands[1]
		local base = W.used and (Text(got.base) or (type(first) == "table" and Text(first.base))) or nil
		if never then
			view.place = T.NEVER
		elseif #view.cands > 0 then
			view.place = PlaceLine(view.cands, state, base)
			if W.used and not base then
				Note(view.notes, T.AGAINST_UNUSED)
			end
		else
			view.place = Text(got.why)
			if not view.place then
				Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
			end
		end
	elseif #view.rows == 0 then
		view.message = Text(got.why) or T.NO_STATS
	end
	return view
end

-- The Overall lines' functions, in a table of their own to keep the file under the client's count of locals.
local O = {}

-- The first two candidates of a comparison, as the window shows them.
function O.Firsts(result)
	local list = {}
	for _, c in ipairs(type(result) == "table" and type(result.candidates) == "table" and result.candidates or {}) do
		if type(c) == "table" and #list < 2 then
			list[#list + 1] = c
		end
	end
	return list
end

-- The candidate of another comparison of the same item for the same slots as c (its first slot), or nil.
function O.Matching(result, c)
	local slots = type(c.slots) == "table" and c.slots or {}
	local slot = slots[1]
	for _, other in ipairs(O.Firsts(result)) do
		local theirs = type(other.slots) == "table" and other.slots or {}
		if Finite(slot) and theirs[1] == slot then
			return other
		end
	end
	return nil
end

-- G.Totals of the candidate of a comparison for the slots of c, or nil.
function O.Totals(result, c, lines, mode)
	local own = result and O.Matching(result, c)
	if not own then
		return nil
	end
	local got = Ask(ns.GearModel, "Totals", own, lines, Options(mode))
	return type(got) == "table" and not IsSecret(got) and got or nil
end

-- Damage taken with the item in the slots of c (A.Totals, else what A.Compare's candidate carries), or nil.
function O.Taken(result, c)
	local own = result and O.Matching(result, c)
	if not own then
		return nil
	end
	local got = Ask(ns.GearAvoid, "Totals", own)
	local taken = type(got) == "table" and got.taken or own.taken
	if type(taken) == "table" and Finite(taken.pct) then
		return taken
	end
	return nil
end

-- A figure of the Overall line: its word in the label grey, then its change as a signed percent, ~ first for an estimate, in green when it is
-- better for the player and red when worse, grey under 0.05%.
function O.FigureText(word, pct, estimate, better)
	return HexOf(Styled("label", LABEL)) .. word .. "|r " .. HexOf(ToneColour(ShareTone(pct, better))) .. (estimate and "~" or "") .. Share(pct) .. "|r"
end

-- Keeps the best and the worst line of a total's figures (each figure's best and worst, G.Totals), with the slot when there are two.
function O.Extremes(acc, figures, where)
	for _, key in ipairs({ "damage", "healing", "threat" }) do
		local figure = figures[key]
		if type(figure) == "table" then
			local best, worst = figure.best, figure.worst
			if type(best) == "table" and Text(best.name) and Finite(best.pct) and (not acc.best or best.pct > acc.best.pct) then
				acc.best = { name = best.name, pct = best.pct, where = where }
			end
			if type(worst) == "table" and Text(worst.name) and Finite(worst.pct) and (not acc.worst or worst.pct < acc.worst.pct) then
				acc.worst = { name = worst.name, pct = worst.pct, where = where }
			end
		end
	end
end

-- A line of the best or the worst: its word, the line's name, the slot when there are two, and its change.
function O.Extreme(word, held)
	local name = held.name .. (held.where and (" (" .. held.where .. ")") or "")
	return HexOf(Styled("label", LABEL)) .. word .. "|r " .. name .. " " .. HexOf(ToneColour(ShareTone(held.pct, 1))) .. Share(held.pct) .. "|r"
end

-- The Overall lines of an item (design item 3, chat.gearTotals): for each slot of the comparison its damage, healing and threat (G.Totals: the
-- weighted means of the lines' percent changes; damage and healing at A cast, or A second while the switch says it, threat at Threat for a tank or
-- while the switch says Threat) and, while avoidance shows, damage taken (A.Totals); then the best and the worst line. Nil when there is nothing
-- to say, the row is Off, or the item is not compared.
function O.Overall(view, lines)
	if not W.link or view.never or Opt("gearTotals") == "off" then
		return nil
	end
	local gear = ns.GearModel
	local damage = W.mode == "second" and "second" or "cast"
	local main, threat, avoid
	if Fn(gear, "Totals") and lines then
		main = (view.mode == damage and view.result) or Ask(gear, "Compare", W.link, lines, Options(damage))
		if view.role == "tank" or W.mode == "threat" then
			threat = (view.mode == "threat" and view.result) or Ask(gear, "Compare", W.link, lines, Options("threat"))
		end
	end
	if Avoiding() then
		avoid = Ask(ns.GearAvoid, "Compare", W.link, { base = W.used })
	end
	local cands = O.Firsts(main)
	if #cands == 0 then
		cands = O.Firsts(avoid)
	end
	local texts, acc, sep = {}, {}, "  " .. FAINT_HEX .. "\194\183|r  "
	for _, c in ipairs(cands) do
		local where = #cands > 1 and Where(c) or nil
		local totals = O.Totals(main, c, lines, damage) or {}
		local threatTotals = threat and O.Totals(threat, c, lines, "threat") or {}
		local figures = { damage = totals.damage, healing = totals.healing, threat = threatTotals.threat or totals.threat,
			taken = avoid and O.Taken(avoid, c) or nil }
		local parts = {}
		for _, figure in ipairs(FIGURES) do
			local held = figures[figure[1]]
			if type(held) == "table" and Finite(held.pct) and not (Finite(held.n) and held.n <= 0) then
				parts[#parts + 1] = O.FigureText(figure[2], held.pct, held.estimate == true, figure[3])
			end
		end
		if #parts > 0 then
			local head = where and T.OVERALL_SLOT:format(where) or T.OVERALL
			texts[#texts + 1] = HexOf(Styled("label", LABEL)) .. head .. "|r  " .. table.concat(parts, sep)
			O.Extremes(acc, figures, where)
		end
	end
	if acc.best then
		local line = O.Extreme(T.BEST, acc.best)
		local worst = acc.worst
		if worst and not (worst.name == acc.best.name and worst.where == acc.best.where) then
			line = line .. sep .. O.Extreme(T.WORST, worst)
		end
		texts[#texts + 1] = line
	end
	return #texts > 0 and texts or nil
end

-- The spell lines' view: the lines, now and with the item, in the figure of the switch, with the item's notes. An item the player can never wear is
-- not compared: the place line says so, and the lines show as with no item.
local function SpellView()
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
	view.lines = lines
	local state, stats = Touch()
	view.role, view.level = Role(state), Level(state)
	view.noStats = type(stats) ~= "table"
	view.old = type(stats) == "table" and stats.old == true
	if W.link then
		view.item = ItemLook(W.link)
		local never, later = Wearing(W.link)
		view.never = never
		local result = not never and Ask(gear, "Compare", W.link, lines, Options(view.mode)) or nil
		if never then
			view.place = T.NEVER
		elseif type(result) == "table" then
			view.result = result
			-- With no slot to compare with, why goes where the slots would be named; the header is the item tooltip's and names a unit.
			if not Compared(view, result, lines, state) then
				view.place = Text(result.why)
				if not view.place then
					Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
				end
			end
			Notes(view, result, later)
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
	-- The Weight column while Overall counts the lines and the list can keep a weight.
	view.weights = #view.rows > 0 and Opt("gearTotals") ~= "off" and Fn(ns, "GearSetWeight") ~= nil
	return view
end

-- What the window shows now, the view Paint draws: the Avoidance view while the switch says it and avoidance shows, else the spell lines'; and the
-- Overall lines of the item. The item of Against is given to the comparison while it goes in the item's slots. Avoidance that no longer shows
-- gives the switch back its first figure for the role.
local function Compute()
	W.used = nil
	if W.link and W.base and SameSlot(W.link, W.base) ~= false then
		W.used = W.base
	end
	local view
	if W.mode == "avoid" then
		view = AvoidView()
		if not view then
			W.mode = Role((Touch())) == "tank" and "threat" or "cast"
		end
	end
	view = view or SpellView()
	view.overall = O.Overall(view, view.lines or Chosen())
	view.baseOther = W.link ~= nil and W.base ~= nil and not W.used
	return view
end

-- What the view was worked out from: SpellModel's version, the version of the list (which a weight changes too), the switch, the item and whether
-- the client has loaded it, the item of Against and whether the client has loaded that, and GearAvoid's stamp.
local function Key()
	local look = W.link and ItemLook(W.link) or nil
	local base = W.base and ItemLook(W.base) or nil
	return table.concat({ tostring(Ask(ns.SpellModel, "Version")), tostring(Ask(ns, "GearListVersion")), W.mode, W.link or "",
		look and look.loaded and "loaded" or "", W.base or "", base and base.loaded and "loaded" or "", tostring(Ask(ns.GearAvoid, "Stamp")) }, "\n")
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

-- The size of the window now, else the one it is to have.
local function Dims()
	local frame = W.frame
	local okW, width = pcall(frame.GetWidth, frame)
	local okH, height = pcall(frame.GetHeight, frame)
	width = okW and Finite(width) and width > 0 and width or SIZE.W
	height = okH and Finite(height) and height > 0 and height or SIZE.H
	return width, height
end

-- A cell in its column of a line: a name from the column's left edge, a number up to its right edge, each short of the next column.
local function SetCell(text, line, column)
	text:ClearAllPoints()
	if column.justify == "LEFT" then
		text:SetPoint("LEFT", line, "LEFT", column.x, 0)
	else
		text:SetPoint("RIGHT", line, "LEFT", column.x + column.width, 0)
	end
	text:SetWidth(math.max(1, column.width - L.CELL_GAP))
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
local function HangText(text, y, inner)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
	text:SetWidth(inner)
end

-- A separator across the window at y.
local function PaintRule(rule, y)
	Hang(rule, y, ns.Pixels(W.frame, 1))
	rule:Show()
end

-- The item: its icon, its name in its quality colour and what it would take the place of, or how to give the window one.
local function PaintItem(view, y, inner)
	local item, look = W.item, view.item
	local room = inner - L.ICON - L.ICON_GAP
	for _, text in ipairs({ item.name, item.place, item.hint }) do
		text:SetWidth(room)
	end
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
		local need = Height(item.hint)
		item.hint:ClearAllPoints()
		item.hint:SetPoint("TOPLEFT", item.box, "TOPRIGHT", L.ICON_GAP, -math.max(0, math.floor((L.ICON - need) / 2)))
		item.hint:Show()
		height = math.max(L.ICON, need)
	end
	Hang(item.button, y, height)
	return y + height + L.GAP
end

-- Against: its icon and the item the item is compared with, said not used when it does not go in the item's slots, or how to give it one.
local function PaintAgainst(view, y, inner)
	local area = W.against
	local look = W.base and ItemLook(W.base) or nil
	local label = HexOf(Styled("label", LABEL)) .. T.AGAINST_LABEL .. "|r"
	local text
	if look then
		if look.icon and pcall(area.icon.SetTexture, area.icon, look.icon) then
			local cut = Crop()
			area.icon:SetTexCoord(cut, 1 - cut, cut, 1 - cut)
			area.icon:Show()
		else
			area.icon:Hide()
		end
		text = label .. look.text
		if view.baseOther then
			text = text .. DIM_HEX .. ", " .. T.AGAINST_OTHER .. "|r"
		end
	else
		area.icon:Hide()
		text = label .. DIM_HEX .. T.AGAINST_HINT .. "|r"
	end
	area.text:SetWidth(inner - L.SMALL_ICON - L.ICON_GAP)
	area.text:SetText(text)
	local need = Height(area.text)
	area.text:ClearAllPoints()
	area.text:SetPoint("TOPLEFT", area.box, "TOPRIGHT", L.ICON_GAP, -math.max(0, math.floor((L.SMALL_ICON - need) / 2)))
	local height = math.max(L.SMALL_ICON, need)
	Hang(area.button, y, height)
	return y + height + L.GAP
end

-- The Overall lines (Overall), each wrapping at the width inside the padding, in a frame that says how they are worked out when pointed at.
local function PaintOverall(view, y, inner)
	local texts, box = view.overall or {}, W.overallBox
	if #texts == 0 then
		box:Hide()
		return y
	end
	local at = 0
	for index, label in ipairs(W.overall) do
		local text = texts[index]
		if text then
			label:ClearAllPoints()
			label:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -at)
			label:SetWidth(inner)
			label:SetText(text)
			label:Show()
			at = at + Height(label) + L.LINE_GAP
		else
			label:Hide()
		end
	end
	Hang(box, y, at)
	box:Show()
	return y + at - L.LINE_GAP + L.GAP
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
	local counts = Counts(mode, row)
	if counts then
		name = name .. "  " .. DIM_HEX .. counts .. "|r"
	end
	if line.known == false then
		name = name .. "  " .. FAINT_HEX .. T.NOT_KNOWN .. "|r"
	end
	return name
end

-- The text of a cell and its colour, as the item tooltips colour them (design 2.3): a line of the Avoidance view by GearAvoid.lua's texts and tones,
-- a change by the slot of its column; the name, now, with, a change with its percent, and the weight.
local function CellText(view, row, column)
	if type(row.texts) == "table" then
		local key = column.slot and ("change" .. column.slot) or column.key
		local text = Text(row.texts[key]) or "-"
		local tones = type(row.tones) == "table" and row.tones or {}
		return text, text == "-" and FAINT or (column.slot and ToneColour(tones[key])) or PLAIN
	end
	local key, second = column.key, row.perSecond == true
	if key == "name" then
		return RowName(row, view.mode), row.line.known == false and FAINT or PLAIN
	elseif key == "now" then
		return Value(row.now, second, row.estimate), Finite(row.now) and PLAIN or FAINT
	elseif key == "with" then
		local with = row.with and row.with[1]
		return Value(with, second, row.estimate), Finite(with) and PLAIN or FAINT
	elseif key == "weight" then
		local weight = WeightOf(row.line)
		return WeightText(weight), weight == 0 and FAINT or (weight == WEIGHT.FIRST and DIM) or PLAIN
	end
	local text, tone = Change(row.now, row.with and row.with[column.slot], second, row.estimate)
	return text, text == "-" and FAINT or ToneColour(tone)
end

-- The width a column's widest text takes, its head's included, measured once a view and text size with a hidden text of the window.
local function Widest(view, column)
	view.widest = view.widest or {}
	local key = column.key .. ":" .. tostring(column.slot) .. ":" .. tostring(W.fontSize)
	if view.widest[key] then
		return view.widest[key]
	end
	local measure = W.measure
	measure:SetText(column.head)
	local widest = TextWidth(measure, column.head)
	for _, row in ipairs(view.rows) do
		local text = CellText(view, row, column)
		measure:SetText(text)
		widest = math.max(widest, TextWidth(measure, text))
	end
	widest = math.ceil(widest)
	view.widest[key] = widest
	return widest
end

-- The columns of the view, each { key, head, slot, justify, width, x }: a number column as wide as its widest text, the name column the rest of the
-- width inside the padding, at least L.NAME, the number columns narrowed alike when they leave less.
local function Layout(view, inner)
	local list = {}
	for _, def in ipairs(COLUMNS[view.layout] or COLUMNS.none) do
		list[#list + 1] = def
	end
	if view.weights then
		list[#list + 1] = WEIGHT_COLUMN
	end
	local columns, numbers = {}, 0
	for index, def in ipairs(list) do
		local column = { key = def[1], slot = def[3], justify = index == 1 and "LEFT" or "RIGHT" }
		local head = type(view.heads) == "table" and Text(view.heads[column.key]) or def[2]
		column.head = column.slot and head:format(Where(view.cands[column.slot])) or head
		if index > 1 then
			column.width = Widest(view, column) + L.CELL_GAP
			numbers = numbers + column.width
		end
		columns[index] = column
	end
	local name = inner - numbers
	if name < L.NAME and numbers > 0 then
		local share = math.max(0, inner - L.NAME) / numbers
		for index = 2, #columns do
			columns[index].width = math.floor(columns[index].width * share)
		end
		name = math.min(inner, L.NAME)
	end
	columns[1].width = math.max(1, name)
	local x = 0
	for _, column in ipairs(columns) do
		column.x = x
		x = x + column.width
	end
	return columns
end

-- The column heads of the table, while it has a line; the name column's says which lines show while some are scrolled out of sight.
local function PaintHeads(view, columns, y, count)
	local total, shown = #view.rows, #view.rows > 0
	Hang(W.headRow, y, L.HEAD)
	for index, head in ipairs(W.heads) do
		local column = shown and columns[index] or nil
		if column then
			local text = column.head
			if index == 1 and total > count then
				text = text .. "  " .. FAINT_HEX .. T.SCROLLED:format(W.offset + 1, W.offset + count, total) .. "|r"
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
		return
	end
	PaintRule(W.headRule, y + L.HEAD)
end

-- One line of the table: its cells in the columns of the view, the weight in its own button.
local function PaintRow(slot, row, view, columns, y)
	local cell, weight = 0, slot.weight
	weight.button:Hide()
	for _, column in ipairs(columns) do
		local text, colour = CellText(view, row, column)
		if column.key == "weight" then
			weight.button:ClearAllPoints()
			weight.button:SetPoint("TOPLEFT", slot.button, "TOPLEFT", column.x, 0)
			weight.button:SetSize(math.max(1, column.width), L.ROW)
			weight.text:SetWidth(math.max(1, column.width - L.CELL_GAP))
			weight.text:SetText(text)
			Colour(weight.text, colour)
			weight.button:Show()
		else
			cell = cell + 1
			local label = slot.cells[cell]
			SetCell(label, slot.button, column)
			label:SetText(text)
			Colour(label, colour)
			label:Show()
		end
	end
	for index = cell + 1, #slot.cells do
		slot.cells[index]:Hide()
	end
	slot.row = row
	Hang(slot.button, y, L.ROW)
	slot.button:Show()
end

-- The lines of the table that show: made as the height needs them, up to MOST_ROWS.
local function Pool(count)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	while #W.rows < math.min(count, MOST_ROWS) do
		local slot = MakeRow(W.frame)
		RowLook(slot, ar, ag, ab)
		W.rows[#W.rows + 1] = slot
	end
end

-- count lines of the table from the first one scrolled to, from y down.
local function PaintRows(view, columns, y, count)
	local total = #view.rows
	count = math.min(count, MOST_ROWS)
	W.offset = math.max(0, math.min(W.offset, total - count))
	W.shown = count
	Pool(count)
	for index, slot in ipairs(W.rows) do
		local row = index <= count and view.rows[W.offset + index] or nil
		if row then
			PaintRow(slot, row, view, columns, y)
			y = y + L.ROW
		else
			slot.row = nil
			slot.button:Hide()
		end
	end
	return y
end

-- The scroll bar at the right edge of the lines while some are out of sight: as long a share of them as shows, as far down as the first shown.
local function PaintThumb(top, count, total)
	local thumb = W.thumb
	if count <= 0 or total <= count then
		thumb:Hide()
		return
	end
	local track = count * L.ROW
	local height = math.max(L.THUMB_LEAST, math.floor(track * count / total))
	local y = top + math.floor((track - height) * W.offset / (total - count))
	thumb:ClearAllPoints()
	thumb:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -math.floor((L.PAD - L.THUMB) / 2), -y)
	thumb:SetSize(L.THUMB, height)
	thumb:Show()
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

-- The foot (design 2.7): against what, what the numbers leave out, the mark of an estimate and the stats of before the fight.
local function FootLines(view)
	local texts = {}
	for _, text in ipairs(type(view.foot) == "table" and view.foot or { Against(view), T.BEFORE, T.NOT_COUNTED, T.ESTIMATE }) do
		texts[#texts + 1] = text
	end
	if view.noStats then
		texts[#texts + 1] = T.NO_STATS
	elseif view.old or Fighting() then
		texts[#texts + 1] = T.OLD
	end
	return texts
end

-- The functions of the notes and the foot, in a table of their own to keep the file under the client's count of locals.
local B = {}

-- The dim lines of a part at Detail of the lines (chat.tipDetail): at Full a line each, at Compact one wrapped line of them all, joined with "; "
-- (design item 2).
function B.Joined(texts, full)
	if full or #texts < 2 then
		return texts
	end
	local parts = {}
	for _, text in ipairs(texts) do
		parts[#parts + 1] = (text:gsub("[%.%s]+$", ""))
	end
	return { table.concat(parts, "; ") .. "." }
end

-- Puts texts on the dim lines of a pool, each wrapping at the width inside the padding, the last saying how many more there are when they do not
-- fit; the height they take, and the height of each.
function B.Fill(pool, texts, inner)
	local heights, total, count = {}, 0, #texts
	for index, label in ipairs(pool) do
		local text = texts[index]
		if text and index == #pool and count > #pool then
			text = T.MORE:format(count - #pool + 1)
		end
		if text then
			label:SetWidth(inner)
			label:SetText(text)
			heights[index] = Height(label)
			total = total + heights[index] + L.LINE_GAP
		else
			label:Hide()
		end
	end
	return total, heights
end

-- Hangs the filled lines of a pool from y down and shows them; where the last ends.
function B.Lay(pool, heights, y)
	for index, label in ipairs(pool) do
		if heights[index] then
			label:ClearAllPoints()
			label:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
			label:Show()
			y = y + heights[index] + L.LINE_GAP
		end
	end
	return y
end

-- The item's notes and the foot, filled at Detail's choice, then Compact, then without the foot, then without the notes, the first that leaves the
-- table room for want; the height they take under it, and the heights of each.
function B.FitBottom(view, inner, room, want)
	local tries = Opt("tipDetail") == "full" and { "full", "compact", "notes", "none" } or { "compact", "notes", "none" }
	local notesH, notesHeights, footH, footHeights, below
	for _, try in ipairs(tries) do
		local full = try == "full"
		notesH, notesHeights = B.Fill(W.notes, try ~= "none" and B.Joined(view.notes, full) or {}, inner)
		footH, footHeights = B.Fill(W.foot, (full or try == "compact") and B.Joined(FootLines(view), full) or {}, inner)
		below = (notesH > 0 and L.GAP + notesH or 0) + (footH > 0 and 2 * L.GAP + footH or 0)
		if room - below >= want then
			break
		end
	end
	return below, notesH, notesHeights, footH, footHeights
end

-- Draws a view at the window's size: from the top down the title bar, the item, Against, Overall and the column heads; from the bottom up the foot
-- and the item's notes; and between them as many lines of the table as fit, the rest scrolled.
function Paint(view)
	local frame = W.frame
	if not frame or type(view) ~= "table" then
		return
	end
	PaintLook()
	local width, height = Dims()
	local inner = width - 2 * L.PAD
	PlaceBar(width)
	PaintRule(W.barRule, L.BAR)
	local y = PaintItem(view, L.BAR + L.GAP, inner)
	y = PaintAgainst(view, y, inner)
	y = PaintOverall(view, y, inner)
	local top, total = y, #view.rows
	local columns = Layout(view, inner)
	local headH = total > 0 and L.HEAD + 3 or 0
	local messageH = 0
	if view.message then
		HangText(W.message, 0, inner)
		W.message:SetText(view.message)
		messageH = Height(W.message) + L.LINE_GAP
	end
	-- The bottom of the window, where the foot's last line ends, and what the table leaves the notes and the foot.
	local bottom = height - L.PAD + L.LINE_GAP
	local room = bottom - (y + headH + messageH)
	local below, notesH, notesHeights, footH, footHeights = B.FitBottom(view, inner, room, math.min(total, LEAST_ROWS) * L.ROW)
	local count = math.max(0, math.floor((room - below) / L.ROW))
	if total > 0 then
		count = math.max(1, math.min(total, count))
	end
	local rowsTop = y + headH
	y = PaintRows(view, columns, rowsTop, count)
	PaintHeads(view, columns, top, W.shown)
	PaintThumb(rowsTop, W.shown, total)
	if view.message then
		HangText(W.message, y, inner)
		W.message:Show()
		y = y + messageH
	else
		W.message:Hide()
	end
	W.tableLight:ClearAllPoints()
	W.tableLight:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD - 3, -top + 2)
	W.tableLight:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -L.PAD + 3, -math.max(y, top + L.ROW))
	-- The notes under the table, then the foot under a separator, as far from it as the separator is from what is above it.
	local at = bottom - below
	if notesH > 0 then
		at = B.Lay(W.notes, notesHeights, at + L.GAP)
	end
	if footH > 0 then
		PaintRule(W.footRule, at + L.GAP)
		B.Lay(W.foot, footHeights, at + 2 * L.GAP)
	else
		W.footRule:Hide()
	end
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
-- Not while it is dragged or sized.
function Place()
	local frame = W.frame
	if not frame or W.moving or W.sizing then
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

-- The window was let go: a box the window's size, its top left corner at the window's, is saved as its spot (ns.MoverKit.Commit), and the window
-- hangs from it (ns.GearWindowMoved). Without the entry it stays where it was let go for this session.
function Dropped()
	if not W.moving then
		return
	end
	W.moving = false
	local frame = W.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	W.placed = nil
	local left, bottom, width, height = RectOf(frame)
	if not left then
		Place()
		return
	end
	local top = bottom + height
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	local saved = false
	if info and type(kit.Commit) == "function" then
		saved = kit.Commit(NAME, info, left, bottom, width, height) == true
	end
	W.dropped = not saved and { left, top } or nil
	W.placed = nil
	Place()
end

-- Sizing ------------------------------------------------------------------------------------------------------------------------------------------

-- The sizing functions, in a table of their own to keep the file under the client's count of locals.
local Z = {}

-- The size kept for the character (FlatUICharDB.gearWindow), or nil.
function Z.SavedSize()
	local char = ns.Character()
	local saved = type(char) == "table" and char.gearWindow or nil
	if type(saved) == "table" and Finite(saved.w) and Finite(saved.h) then
		return saved.w, saved.h
	end
	return nil
end

-- The size of UIParent, in whose units the window is sized: the most it takes.
function Z.Screen()
	local okW, width = pcall(UIParent.GetWidth, UIParent)
	local okH, height = pcall(UIParent.GetHeight, UIParent)
	if okW and okH and Finite(width) and Finite(height) and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

-- A size between the least the window takes (380 x 220, wider while its title bar needs more) and the screen, in whole units.
function Z.Clamp(width, height)
	local least = math.max(SIZE.MIN_W, W.barNeed or 0)
	width, height = math.max(least, width), math.max(SIZE.MIN_H, height)
	local sw, sh = Z.Screen()
	if sw then
		width, height = math.min(width, math.max(least, sw)), math.min(height, math.max(SIZE.MIN_H, sh))
	end
	return math.floor(width + 0.5), math.floor(height + 0.5)
end

-- The handle of the window in the movers drawn again, so its box has the window's size.
function Z.Handle()
	local kit = ns.MoverKit
	local show = type(kit) == "table" and kit.ShowHandle or nil
	if type(show) == "function" then
		pcall(show, NAME)
	end
end

-- Gives the window the size kept, else the first, cut to the screen, and the bounds a drag of the grip keeps to.
function Z.ApplySize()
	local frame = W.frame
	if not frame then
		return
	end
	local width, height = Z.SavedSize()
	width, height = Z.Clamp(width or SIZE.W, height or SIZE.H)
	local maxW, maxH = Z.Clamp(100000, 100000)
	pcall(frame.SetResizeBounds, frame, math.max(SIZE.MIN_W, W.barNeed or 0), SIZE.MIN_H, maxW, maxH)
	frame:SetSize(width, height)
end

function Z.SizeStart()
	if W.moving or W.sizing then
		return
	end
	W.frame:StartSizing("BOTTOMRIGHT")
	W.sizing = true
end

-- The grip was let go: the size, cut to its bounds, is kept for the character, the window hangs from its spot again and is drawn at it.
function Z.SizeStop()
	if not W.sizing then
		return
	end
	W.sizing = false
	local frame = W.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	local width, height = Z.Clamp(Dims())
	local char = ns.Character()
	if type(char) == "table" then
		char.gearWindow = { w = width, h = height }
	end
	frame:SetSize(width, height)
	W.placed = nil
	Place()
	Z.Handle()
	Paint(W.view)
end

-- Reset the window: the size is forgotten, and the start of its entry in the movers is saved as its spot (its top left corner that far from the
-- screen's), so it hangs there at the first size.
function Z.Reset()
	local char = ns.Character()
	if type(char) == "table" then
		char.gearWindow = nil
	end
	W.dropped = nil
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	local _, screenH = Z.Screen()
	if info and type(kit.Commit) == "function" and screenH then
		local width, height = Z.Clamp(SIZE.W, SIZE.H)
		local x = Finite(info.x) and info.x or BOX.x
		local y = Finite(info.y) and info.y or BOX.y
		kit.Commit(NAME, info, x, screenH + y - height, width, height)
	end
	if W.frame then
		Z.ApplySize()
		W.placed = nil
		Place()
		Z.Handle()
		Paint(W.view)
	end
	return true, T.RESET_DONE
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

-- True when the item on the cursor was lifted from a bag, the bank or a worn slot, so ClearCursor puts it back there (header): the place
-- C_Cursor.GetCursorItem gives is a bag slot or a worn slot, and the item there is locked, as it is while it rides the cursor. An item with no such
-- place, such as one dragged off an action bar, is not, and neither is one whose place the client does not say.
local function Lifted()
	local get = Fn(_G.C_Cursor, "GetCursorItem")
	local locked = Fn(C_Item, "IsLocked")
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
		local okIs, answer = false, nil
		if is then
			okIs, answer = pcall(is, place)
		end
		if okIs and not IsSecret(answer) and answer == true then
			slotted = true
		end
	end
	if not slotted then
		return false
	end
	local okLocked, held = pcall(locked, place)
	return okLocked and not IsSecret(held) and held == true
end

-- Takes what the cursor holds. An item is compared, or on Against (target "against") is what the item is compared with, and, lifted from a bag, the
-- bank or a worn slot, goes back there; any other item and a spell stay on the cursor, and a spell goes on the list (header). The click that ends
-- a drag on the window brings the same thing again, which counts as that drop. True when it took something.
function Drop(target)
	local kind, value = Held()
	if not kind then
		return false
	end
	local now = Now()
	if W.held == value and now - (W.heldAt or 0) < DROP_AGAIN then
		return true
	end
	W.held, W.heldAt = value, now
	if kind == "item" then
		if Lifted() then
			pcall(ClearCursor)
		end
		if target == "against" then
			W.base = value
		else
			W.link, W.offset = value, 0
		end
		Refresh()
	else
		Add(value)
	end
	return true
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

-- The lit parts while the cursor holds what they take: the item's area and Against for an item, the table for a spell; and Find while the item
-- finder shows.
local function Lights()
	local kind = Held()
	W.item.light:SetShown(kind == "item")
	W.against.light:SetShown(kind == "item")
	W.tableLight:SetShown(kind == "spell")
	local searching = Searching()
	if searching ~= W.searching then
		W.searching = searching
		PaintWords()
	end
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
	local most = math.max(0, #view.rows - W.shown)
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
			local threat = row.figure == "threat"
			basis = Text(threat and e.threatBasis or e.basis)
			why = Text(e.why) or (threat and Text(e.threatWhy)) or nil
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
	if not row or row.texts or Fighting() then
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

-- The handlers and makers of Against, the weights, Find, Overall and the grip, in a table of their own to keep the file under the client's count of
-- locals.
local U = {}

-- Against's tooltip, out of combat: its item's own with how to take it away, else what the box is for.
function U.AgainstTip()
	local button = W.against.button
	if Fighting() then
		return
	end
	if not W.base then
		Say(button, T.AGAINST, T.AGAINST_TIP)
		return
	end
	local tip = Tooltip()
	if not tip or not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	if not Built(pcall(tip.SetHyperlink, tip, W.base)) then
		Untip(button)
		return
	end
	local lines = {}
	if type(W.view) == "table" and W.view.baseOther then
		lines[1] = T.AGAINST_OTHER:sub(1, 1):upper() .. T.AGAINST_OTHER:sub(2) .. "."
	end
	lines[#lines + 1] = T.AGAINST_CLEAR
	AddDim(tip, lines)
	pcall(tip.Show, tip)
end

-- A weight's tooltip: the weight and how to change it.
function U.WeightTip(slot)
	local row = slot.row
	if not row or row.texts then
		return
	end
	Say(slot.weight.button, T.WEIGHT_TIP:format(WeightText(WeightOf(row.line))), T.WEIGHT_LINES)
end

-- Overall's tooltip: how each figure is worked out, damage taken while avoidance shows, with the enemy hit block value counts against (Enemy hit
-- for block value, chat.gearSwing).
function U.OverallTip()
	local lines = { T.OVERALL_LINES[1] }
	if Avoiding() then
		local swing, figure = Opt("gearSwing"), Fmt("Figure")
		swing = Finite(swing) and swing or 1500
		lines[#lines + 1] = T.OVERALL_LINES[2]:format(figure and figure(swing) or tostring(math.floor(swing)))
	end
	lines[#lines + 1] = T.OVERALL_LINES[3]
	Say(W.overallBox, T.OVERALL, lines)
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
	if mouse == "RightButton" and slot.row and not slot.row.texts then
		Untip(slot.button)
		Remove(slot.row)
	end
end

-- A left click with something on the cursor is a drop on Against; a right click takes its item away, so the item is compared with what is worn.
function U.AgainstClick(mouse)
	if mouse == "LeftButton" and Drop("against") then
		return
	end
	if mouse == "RightButton" and W.base then
		W.base = nil
		Untip(W.against.button)
		Refresh()
	end
end

-- True while Shift is held (IsShiftKeyDown).
function U.Shift()
	if type(IsShiftKeyDown) ~= "function" then
		return false
	end
	local ok, down = pcall(IsShiftKeyDown)
	return ok and not IsSecret(down) and down == true
end

-- The weight of a line set through the list (ns.GearSetWeight, by the spell of the line as ns.GearRemove takes it), which says why when it refuses.
function U.SetWeight(row, weight)
	local set, id = Fn(ns, "GearSetWeight"), SpellOf(row.line)
	if not set then
		print(T.NO_WEIGHT)
		return
	end
	if not id then
		return
	end
	local ok, done, message = pcall(set, id, weight)
	if not ok then
		Report("GearSetWeight", done)
		return
	end
	if done ~= true and Text(message) then
		print(message)
	end
	Refresh()
end

-- A click on a weight: a drop with something on the cursor; else a Shift-click gives 1, a left click adds 0.5 and a right click takes 0.5 off, from
-- 0 to 5; its tooltip then says the new weight.
function U.WeightClick(slot, mouse)
	if mouse == "LeftButton" and Drop() then
		return
	end
	local row = slot.row
	if not row or row.texts then
		return
	end
	local now, weight = WeightOf(row.line), nil
	if U.Shift() then
		weight = WEIGHT.FIRST
	elseif mouse == "RightButton" then
		weight = math.max(WEIGHT.MIN, now - WEIGHT.STEP)
	else
		weight = math.min(WEIGHT.MAX, now + WEIGHT.STEP)
	end
	if weight ~= now then
		U.SetWeight(row, weight)
		U.WeightTip(slot)
	end
end

-- Find: a drop with something on the cursor; else the item finder opens or closes (ns.GearSearchToggle, GearSearch.lua).
function U.FindClick()
	if Drop() then
		return
	end
	local toggle = Fn(ns, "GearSearchToggle")
	if not toggle then
		print(T.NO_FIND)
		return
	end
	local ok, err = pcall(toggle)
	if not ok then
		Report("GearSearchToggle", err)
	end
	W.searching = Searching()
	PaintWords()
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

-- A frame of the window takes what is dropped on it, and a frame that is no button takes a click with something on the cursor too; target says what
-- a dropped item is for (Drop).
local function Drops(frame, clicks, target)
	frame:SetScript("OnReceiveDrag", function()
		Run(Drop, target)
	end)
	if clicks then
		frame:SetScript("OnMouseUp", function()
			Run(Drop, target)
		end)
	end
end

-- A word of the switch or Find under the mouse: white, with its tooltip; dim again when the mouse leaves.
local function Hover(word, title, lines)
	word.button:SetScript("OnEnter", function()
		word.over = true
		Run(PaintWords)
		Run(Say, word.button, title, lines)
	end)
	word.button:SetScript("OnLeave", function()
		word.over = false
		Run(PaintWords)
		Untip(word.button)
	end)
end

-- The words of the switch, each with a separator on its left but the first; PlaceBar places them and SizeParts sizes them.
local function MakeSwitch(bar)
	W.seps = {}
	for index = #MODES, 1, -1 do
		local mode = MODES[index]
		local button = Own(CreateFrame("Button", nil, bar))
		button:RegisterForClicks("LeftButtonUp")
		local text = Label(button)
		text:SetPoint("CENTER", button, "CENTER", 0, 0)
		text:SetText(mode[2])
		local word = { mode = mode[1], label = mode[2], button = button, text = text, width = 0 }
		button:SetScript("OnClick", function()
			Run(Choose, word)
		end)
		Hover(word, word.label, { WORD_TIPS[word.mode] })
		Drops(button)
		W.words[index] = word
		W.owners[#W.owners + 1] = button
		if index > 1 then
			local sep = Texture(bar, "ARTWORK")
			sep:SetSize(1, 10)
			W.seps[#W.seps + 1] = sep
			word.sep = sep
		end
	end
end

-- Find, after the title: it opens and closes the item finder.
function U.MakeFind(bar)
	local button = Own(CreateFrame("Button", nil, bar))
	button:RegisterForClicks("LeftButtonUp")
	local text = Label(button)
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	text:SetText(T.FIND)
	local find = { label = T.FIND, button = button, text = text, width = 0 }
	button:SetScript("OnClick", function()
		Run(U.FindClick)
	end)
	Hover(find, T.FIND, T.FIND_LINES)
	Drops(button)
	W.find = find
	W.owners[#W.owners + 1] = button
end

-- The title bar: the title, Find, the switch and the close cross, as the bag window draws its cross; a drag of it moves the window.
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
	U.MakeFind(bar)
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
	box:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	item.box = box
	item.outline = ns.SetOutlineArea(ns.Outline(box, box), "windows")
	item.icon = Texture(box, "ARTWORK")
	item.icon:SetAllPoints(box)
	item.icon:Hide()
	item.name = Label(button, TITLE_FONT)
	item.name:SetPoint("TOPLEFT", box, "TOPRIGHT", L.ICON_GAP, -1)
	item.place = Label(button, FONT, true)
	item.place:SetPoint("TOPLEFT", item.name, "BOTTOMLEFT", 0, -L.LINE_GAP)
	pcall(item.place.SetMaxLines, item.place, 2)
	item.hint = Label(button, FONT, true)
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

-- Against: a smaller box under the item's, with its icon and a line that names its item or says what it is for. What is dropped on it is its item.
function U.MakeAgainst(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local area = { button = button }
	area.hover = Texture(button, "HIGHLIGHT")
	area.hover:SetAllPoints(button)
	area.light = Texture(button, "BACKGROUND", 1)
	area.light:SetAllPoints(button)
	area.light:Hide()
	local box = Own(CreateFrame("Frame", nil, button))
	box:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	area.box = box
	area.outline = ns.SetOutlineArea(ns.Outline(box, box), "windows")
	area.icon = Texture(box, "ARTWORK")
	area.icon:SetAllPoints(box)
	area.icon:Hide()
	area.text = Label(button, FONT, true)
	pcall(area.text.SetMaxLines, area.text, 2)
	button:SetScript("OnClick", function(_, mouse)
		Run(U.AgainstClick, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(U.AgainstTip)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	Drops(button, false, "against")
	W.against = area
	W.owners[#W.owners + 1] = button
end

-- The Overall lines in a frame of their own, which says how they are worked out when pointed at and takes a drop as the window does.
function U.MakeOverall(frame)
	local box = Own(CreateFrame("Frame", nil, frame))
	box:EnableMouse(true)
	for index = 1, OVERALL do
		W.overall[index] = Label(box, FONT, true)
	end
	box:SetScript("OnEnter", function()
		Run(U.OverallTip)
	end)
	box:SetScript("OnLeave", function()
		Untip(box)
	end)
	Drops(box, true)
	box:Hide()
	W.overallBox = box
	W.owners[#W.owners + 1] = box
end

-- One line of the table: a button that takes a right click, a drop and the wheel, its light under the mouse, its four cells, and a button of its
-- weight that takes a left and a right click.
function MakeRow(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:EnableMouseWheel(true)
	local slot = { button = button, cells = {} }
	slot.hover = Texture(button, "HIGHLIGHT")
	slot.hover:SetAllPoints(button)
	for index = 1, 4 do
		slot.cells[index] = Label(button)
	end
	local weight = Own(CreateFrame("Button", nil, button))
	weight:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	weight:EnableMouseWheel(true)
	local hover = Texture(weight, "HIGHLIGHT")
	hover:SetAllPoints(weight)
	local text = Label(weight)
	text:SetPoint("RIGHT", weight, "RIGHT", 0, 0)
	text:SetJustifyH("RIGHT")
	slot.weight = { button = weight, text = text, hover = hover }
	button:SetScript("OnClick", function(_, mouse)
		Run(RowClick, slot, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(RowTip, slot)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	weight:SetScript("OnClick", function(_, mouse)
		Run(U.WeightClick, slot, mouse)
	end)
	weight:SetScript("OnEnter", function()
		Run(U.WeightTip, slot)
	end)
	weight:SetScript("OnLeave", function()
		Untip(weight)
	end)
	for _, region in ipairs({ button, weight }) do
		region:SetScript("OnMouseWheel", function(_, delta)
			Run(Scroll, delta)
		end)
		Drops(region)
	end
	weight:Hide()
	button:Hide()
	W.owners[#W.owners + 1] = button
	W.owners[#W.owners + 1] = weight
	return slot
end

-- The heads, the message in the place of the lines, the item's notes and the foot, the scroll bar and the hidden text that measures the columns; the
-- lines themselves are made as the height needs them (Pool).
local function MakeTable(frame)
	W.tableLight = Texture(frame, "BACKGROUND", 1)
	W.tableLight:Hide()
	W.headRow = Own(CreateFrame("Frame", nil, frame))
	W.heads = {}
	for index = 1, 5 do
		W.heads[index] = Label(W.headRow)
	end
	W.headRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.headRule
	W.message = Label(frame, FONT, true)
	for index = 1, NOTES do
		W.notes[index] = Label(frame, FONT, true)
	end
	W.footRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.footRule
	for index = 1, FOOT do
		W.foot[index] = Label(frame, FONT, true)
	end
	W.thumb = Texture(frame, "OVERLAY")
	W.thumb:Hide()
	W.measure = Label(frame)
	W.measure:Hide()
end

-- The grip at the bottom right corner: three strokes, lit under the mouse; a drag of it sizes the window (Z.SizeStart, Z.SizeStop).
function U.MakeGrip(frame)
	local grip = Own(CreateFrame("Button", nil, frame))
	grip:SetSize(L.GRIP, L.GRIP)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(frame:GetFrameLevel() + 5)
	local lines, hover = {}, {}
	for index, at in ipairs({ 3, 7, 11 }) do
		lines[index] = Stroke(grip, "OVERLAY", L.GRIP - 1, at, at, L.GRIP - 1)
		hover[index] = Stroke(grip, "HIGHLIGHT", L.GRIP - 1, at, at, L.GRIP - 1)
	end
	grip:SetScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			Untip(grip)
			Run(Z.SizeStart)
		end
	end)
	grip:SetScript("OnMouseUp", function()
		Run(Z.SizeStop)
	end)
	-- A drag that the window's hiding cut short ends where it was let go.
	grip:SetScript("OnHide", function()
		if W.sizing then
			pcall(Z.SizeStop)
		end
	end)
	grip:SetScript("OnEnter", function()
		if not W.sizing then
			Run(Say, grip, T.GRIP, T.GRIP_LINES)
		end
	end)
	grip:SetScript("OnLeave", function()
		Untip(grip)
	end)
	W.grip = { button = grip, lines = lines, hover = hover }
	W.owners[#W.owners + 1] = grip
end

-- Text size of the window changed: every font string of the window takes it, the units follow, the parts that follow them are sized again, the
-- window is at least as wide as its title bar needs, and it is drawn again at the next frame. Texts and sizes of Flat UI's own frames only.
function U.ApplyFont()
	local size = FontSize()
	if not W.frame or W.fontSize == size then
		return
	end
	W.fontSize = size
	Units(size)
	for _, held in ipairs(W.texts) do
		Sized(held[1], held[2])
	end
	SizeParts()
	Z.ApplySize()
	W.relayout = true
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

-- The strata of the window: MEDIUM among the game's windows (design 2.7), or DIALOG while the options window shows (HIGH, Panel.lua:2654), so a
-- window its Gear comparison window row opens shows above it, as the Edit Mode layout text does (LayoutText.lua:38).
local function Raise()
	local over = false
	if type(ns.PanelShown) == "function" then
		local ok, shown = pcall(ns.PanelShown)
		over = ok and shown == true
	end
	W.frame:SetFrameStrata(over and "DIALOG" or "MEDIUM")
end

-- The window's part of its showing: SpellModel listens, the switch starts on Threat for a tank (on Avoidance while it shows) and on A cast for the
-- others until the player picks one (design 2.7), the strata suits the options window, the text size and the size are those of the rows and of
-- the character, cut to the screen, and the window is placed and worked out afresh.
local function Showing()
	Want(true)
	Raise()
	if not W.chosen then
		W.mode = Role((Touch())) == "tank" and (Avoiding() and "avoid" or "threat") or "cast"
	end
	W.elapsed, W.looked = 0, 0
	U.ApplyFont()
	Z.ApplySize()
	Place()
	Refresh()
end

-- Whatever hid the window (its cross, Escape, the module or the part going off): SpellModel may stop listening, a drag of the title bar or of the
-- grip ends where it was let go, a tooltip of the window goes, and the item finder beside it closes (ns.GearSearchToggle while ns.GearSearchShown).
-- Plain code, so it also runs once the part has stopped.
local function Hiding()
	Want(false)
	if W.moving then
		pcall(Dropped)
	end
	if W.sizing then
		pcall(Z.SizeStop)
	end
	for _, owner in ipairs(W.owners) do
		Untip(owner)
	end
	if W.item then
		W.item.light:Hide()
		W.against.light:Hide()
		W.tableLight:Hide()
	end
	local shown, toggle = Fn(ns, "GearSearchShown"), Fn(ns, "GearSearchToggle")
	if shown and toggle then
		local ok, open = pcall(shown)
		if ok and open == true then
			local done, err = pcall(toggle)
			if not done then
				Report("GearSearchToggle", err)
			end
		end
	end
end

-- The frame and everything in it, once, out of combat (design 4.7), at the text size of its row and the size kept for the character.
local function Make()
	W.fontSize = FontSize()
	Units(W.fontSize)
	local frame = Own(CreateFrame("Frame", NAME, UIParent))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:SetSize(SIZE.W, SIZE.H)
	frame:Hide()
	W.frame = frame
	W.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "windows")
	MakeBar(frame)
	MakeItem(frame)
	U.MakeAgainst(frame)
	U.MakeOverall(frame)
	MakeTable(frame)
	U.MakeGrip(frame)
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
	-- A change of size, a drag of the grip's included, draws the window again at the next frame.
	frame:SetScript("OnSizeChanged", function()
		W.relayout = true
	end)
	-- The looks of the window while it shows. It closes once the module or the part is off, also when no refresh of the module said so
	-- (ns.GearWindowSync), and when the module stopped, whose parts run nothing more: that test is plain code.
	frame:SetScript("OnUpdate", function(_, elapsed)
		local step = Finite(elapsed) and elapsed or 0
		W.elapsed, W.looked = W.elapsed + step, W.looked + step
		if W.relayout then
			W.relayout = false
			Run(Paint, W.view)
		end
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
	SizeParts()
	Z.ApplySize()
	Special()
	PaintLook()
	Place()
end

-- Opens the window, with an item when one is given, and with an item of Against when one is given (false takes it away). An opening asked for in a
-- fight before the window was made waits for the fight's end, once.
local function Open(link, base)
	if link then
		W.link, W.offset = link, 0
	end
	if base == false then
		W.base = nil
	elseif base then
		W.base = base
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
		Raise()
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

-- Opens or closes the window (/flatui gear). True when it opened, closed or waits for the end of the fight; false, with a line that says why, when
-- Chat and tooltips or this part is off.
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

-- Opens the window with an item (/flatui gear <item>, a click in the item finder): a link, an item string or an item ID; with none (the tab's Gear
-- comparison window row) it opens with the item it had. base, the item of Against: nil keeps it, false takes it away, an item sets it. An open
-- window is raised (Raise) and worked out afresh, never closed.
function ns.GearWindowShow(link, base)
	if not Allowed() then
		print(Refusal())
		return false
	end
	if base ~= false then
		base = AsItem(base)
	end
	return Run(Open, AsItem(link), base)
end

-- Sets the item of Against (Compare against in the item finder), opening the window, or with nil takes it away, so the item is compared with what
-- is worn. False, with a line that says why, when Chat and tooltips or this part is off.
function ns.GearWindowAgainst(link)
	if not Allowed() then
		print(Refusal())
		return false
	end
	local base = AsItem(link)
	if base then
		return Run(Open, nil, base)
	end
	W.base = nil
	if ns.GearWindowOpen() then
		return Run(Refresh)
	end
	return true
end

-- The line of Reset the window (chat.gearWinReset) and what choosing it does: the size forgotten and the spot back at its start (Z.Reset), also
-- while Chat and tooltips is off. It answers as a pick does: done, and the line that says what it did.
function ns.GearWindowResetLines()
	return { { 1, T.RESET_LINE } }
end

function ns.GearWindowResetPick(id)
	if id ~= 1 then
		return false, nil
	end
	local ok, done, message = pcall(Z.Reset)
	if not ok then
		Report("reset", done)
		return false, T.RESET_FAILED
	end
	return done, message
end

-- The window has a handle in the movers while it may show, open or not, as Bags' windows have one while Bags is on (BagsWindow.lua:2162-2169).
function ns.GearWindowShown()
	return Allowed()
end

-- True while the window is open: GearLines.lua's /flatui status lines show then too, whatever Your spells in item tooltips says.
function ns.GearWindowOpen()
	local frame = W.frame
	if not frame then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown == true
end

-- The movers set or put back the window's spot: it hangs from it now.
function ns.GearWindowMoved()
	W.placed, W.dropped = nil, nil
	if W.frame then
		Run(Place)
	end
end

-- Called at the end of each refresh of Chat.lua: the window closes while the module or this part is off, and takes the look of the Windows page and
-- Text size of the window again after a change of them; a row of the tab worked out again comes with the next look (Tick).
function ns.GearWindowSync()
	if not Allowed() then
		Close()
		return
	end
	if W.frame then
		W.dirty = true
		Run(U.ApplyFont)
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
		name = name or (look and look.name) or "an item"
		if W.used then
			local _, base = LinkParts(W.used)
			return { T.STATUS_AGAINST:format(name, base or ItemLook(W.used).name) }
		end
		return { T.STATUS:format(name) }
	end)
end
