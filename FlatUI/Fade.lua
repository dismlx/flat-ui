local _, ns = ...

-- Fading: the action bars, the stance and pet bars, the micro menu, the bag bar, the open bag windows, the player and pet frames, Flat UI's
-- experience bar and the minimap buttons, the game's and other addons', go to a low opacity while nothing asks for them, and back to full when
-- something does. The one thing written on a frame is its alpha
-- (SetAlpha, which the documentation leaves open to addons and does not mark protected:
-- Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1133-1142). The alpha a frame had is read before the first write and put
-- back when the module, the row or the part goes off. A faded frame still takes clicks and shows tooltips, since alpha does not touch the mouse.
--
-- One frame of the addon's own runs every 0.05 s while the module is on. A row is at full opacity while the mouse is over the row's hover frame
-- (the Main action bar row's includes Flat UI's page arrows, FlatUIBar1PageUp and FlatUIBar1PageDown, left of its bar),
-- in a fight (with In combat ticked), with a target (With a target ticked; not the Target frame row, see When shown), while you cast or channel
-- and for a moment after an instant spell or an item use (While casting ticked: UNIT_SPELLCAST_START, CHANNEL_START and SUCCEEDED of the player
-- heard on the module's own frame, and UnitCastingInfo and UnitChannelInfo), while the cursor holds something, while the spell flyout is open,
-- in Edit Mode and while /flatui move is open (ns.MoverKit.IsOpen), so a frame at 0% is not a box over nothing while it is lined up.
-- Otherwise it stays where it is until Wait before fading has passed, then eases to Faded opacity over Fade time. Back to full it comes in a tenth
-- of a second (RETURN_TIME), or over Fade time where that is shorter, as the bar block does. A frame is written only when its value changes.
-- A frame whose alpha something else holds at 0 (the hidden minimap buttons) is left alone, and a frame the action bar block fades is left to that fade.
-- An alpha something else gives a frame after a write is taken as the frame's own, the one put back, and the frame eases again from it.
-- The frames are the game's own, but for Flat UI's bag and bank windows and, while Flat UI's buttons are in use, Flat UI's own bars in the rows of the
-- main bar and bars 2 to 8, which then fade Flat UI's bar alone, whatever Leave the game's action bars alone says, and never write the game's parked bar. The game's frames: MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7, StanceBar,
-- PetActionBar, MicroMenuContainer, BagsBar, PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContent (parentKeys of PlayerFrame with no global name: Blizzard_UnitFrame/Mainline/PlayerFrame.xml:23 and :68; the pet frame, totems and cast bar stay as they are),
-- PetFrame, and under MinimapCluster the Tracking and IndicatorFrame frames, GameTimeFrame, TimeManagerClockButton and AddonCompartmentFrame
-- (Blizzard_Minimap/Mainline/Minimap.xml:3, 25 and 46, GameTime.xml:3, Camelot/AddonCompartment.xml:3, Blizzard_TimeManager/Mainline/Blizzard_TimeManager.xml:178).
-- The Experience bar row fades FlatUIXpBar, Flat UI's own experience and reputation bar (XpBar.lua), while it is the one in use (ns.XpOwn); the
-- bar itself is the hover area, and a gain, the fill sliding up or a level or standing flash on it holds it at full while it runs (busy,
-- ns.XpBarLively). While block 1 of the Bar block page holds it with Fade the block on, the block's fade takes it over by its name
-- (ns.BarBlockFades), as it does the action bars; with the game's bar in use the row has nothing to fade and gives the bar its alpha back.
-- The Player frame row also fades the frames of Flat UI's own that Unit frames puts on PlayerFrame itself, outside its container and its content: the
-- body, the name row and the shadow (ns.UnitFrameExtra.pieces, UnitFrames.lua), so the plate and its border fade with the bars and the portrait. The
-- picture, the level on it and the bars' borders of Unit frames are inside the container and the content, and fade once, with them.
-- Other addons' minimap buttons join the Minimap buttons row: the shown, unprotected LibDBIcon10_ frames on the map that MapButtons.lua finds
-- (ns.MapAddonButtons), whatever Addon buttons says, asked for again at each pass so that a button made later joins, and a button that leaves the
-- list gets its alpha back at once. In the column or row beside the map they lie outside MinimapCluster, so the mouse over any of them counts as
-- over the map. An addon that fades its own buttons (LibDBIcon's own fade) gives them an alpha that is taken as theirs, as above, so the two do not fight.
-- ExtraActionBarFrame, the swing timers and the resource display are left out because the game or Edit Mode sets their alpha.
--
-- The bag bar: on Forever every bag button hangs from BagsBar. The backpack (MainMenuBarBackpackButton) and the keyring (KeyRingButton) are its
-- children, and the expand arrow (BagBarExpandToggle), the four bag slots (CharacterBag0Slot to CharacterBag3Slot) and the reagent bag
-- (CharacterReagentBag0Slot) are children of BagSlotCluster, its child (Blizzard_MainMenuBarBagButtons/Camelot/MainMenuBarBagButtons.xml:51-97,
-- Mainline/MainMenuBarBagButtonTemplates.xml:61-131). The game parents none of them elsewhere and sets the alpha of none of them, only of the
-- highlight picture of each (Camelot/MainMenuBarBagButtons.lua:37); Hud.lua styles their pictures and Movers places and scales the bar, never a
-- button. So the alpha of BagsBar fades every one of them together, and no button is written on its own: the template's SetAlpha is a Lua method
-- of the game that fades the icon and count only (Blizzard_ItemButton/Shared/ItemButtonTemplate.lua:239-245). The mouse over the bar, or over any
-- of the buttons that shows, wherever it lies, holds them all at full. What made the row miss them was Leave the game's action bars alone, on by
-- default: the row was one of the action bar rows, which do nothing while it is on. It no longer is: its alpha places, scales and lays out
-- nothing, and the bag buttons' clicks run none of the game's secure code (ToggleBag, PutItemInBag), so the row fades the bar either way. A bag
-- button another addon takes into a bar of its own no longer hangs from BagsBar and is left to that addon.
-- The micro menu the same way: its buttons (CharacterMicroButton to MainMenuMicroButton, Camelot/MicroMenuContainerOverrides.lua:1-20) are
-- children of MicroMenu (MicroMenuContainer.lua:101-109), a child of MicroMenuContainer (Camelot/MainMenuBarMicroMenu.xml:3), and the help
-- ticket button is a child of CharacterMicroButton, 25 above or under an end of the menu, outside its rectangle (HelpFrame.xml:143,
-- MicroMenuContainer.lua:148-168). So the alpha of MicroMenuContainer fades all of them together and no button is written; the mouse over any
-- of them that shows counts as over the menu. The game sets the alpha of neither frame. The main bar hangs from the container on Forever
-- (Camelot/EditModePresetLayoutConstants.lua:5-8), but an alpha reaches only the frame and its children, never a frame anchored to it, and
-- places, scales and lays out nothing, so the row fades the menu also while Leave the game's action bars alone is on. Where the game lends
-- the menu to a vehicle's bar or a full screen frame (OverrideActionBar.lua:141, Mainline/MainMenuBarMicroButtons.lua:185-195) it is no
-- longer under the container and shows there, at its own alpha, until the game gives it back. The queue eye is not the menu's on Forever: it
-- hangs from the minimap (Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua:13-35) and does not fade with it.
-- Faded opacity of the micro menu and of the bag bar: each row has its own (Micro menu faded opacity, Bag bar faded opacity), the page's
-- Faded opacity by default, or a percent of its own down to 0%, where the frame is gone until the mouse comes over it and still takes clicks.
-- The bag windows: Flat UI's bag and bank windows (FlatUIBags and FlatUIBank, BagsWindow.lua) and the game's, the combined window
-- (ContainerFrameCombinedBags), ContainerFrame1 to ContainerFrame7, the reagent bag's and the keyring's among them, and the bank (BankFrame)
-- (Blizzard_UIPanels_Game/Mainline/ContainerFrame.xml:298-313, ContainerFrame.lua:1-12, Camelot/BankFrame.xml:59), whose alpha the game never
-- sets. Only the windows that show are faded, asked for at each pass: with Bags on the game's windows are kept under a hidden frame
-- (ns.BagsParked) and do not show, BankFrame too while Flat UI's bank window is the one used, and with it off Flat UI's do not. A window that closes gets its alpha back at once, so it opens at its own alpha, and the row is at full opacity
-- the pass a window opens, then waits Wait before fading as after the mouse leaves. A window in use is never faded: the mouse over any of
-- them, an item on the cursor (as for every row), the game's split box (StackSplitFrame) open, or the keyboard in a box of one of them (the
-- search box of Flat UI's bag window, GetCurrentKeyBoardFocus) holds them all at full.
-- Hidden frames (Hide.lua) wins over this module. A frame it holds under its hidden frame, or one under such a frame (the player frame's container
-- and content under a hidden PlayerFrame, the minimap's buttons under a hidden MinimapCluster, the bag bar under its hidden frame), gets no write:
-- just before it goes under, Hidden frames asks this module to give it, and every frame under it that it fades, the alpha it had (ns.FadeLetGo),
-- written while it still shows, and to forget them. A frame held so is passed by each step with no write (Gone), and does not count as under the
-- mouse. When Hidden frames gives it back with its own alpha, as it came, this module takes it up from that alpha, as a frame it had never
-- written: nothing is put back over it. The bag bar hidden while its row here is on is so: the row fades nothing while it is hidden, and fades
-- the bar again once it is back. The micro menu hidden is held otherwise: Hidden frames holds MicroMenu, the container's child, so this row
-- goes on writing the alpha of the container, empty while the menu is held, and the menu comes back under it at the container's alpha. The bag
-- windows are not on the Hidden frames page.
--
-- When shown: the target and focus frames, the buffs, the objective tracker and the damage meter each have a rule. Always (the default) leaves the
-- frame alone. Only in combat, Only in a group, Only in an instance, Only outside an instance and Only when not mounted give it full opacity while that
-- holds; at other times it fades as the rows above do, under the mouse, the Stay visible rows and Edit Mode included, With a target aside for the target frame: the game shows that frame only
-- while there is a target (Blizzard_UnitFrame/Shared/TargetFrame.lua:1-15, Mainline/TargetFrame.lua:130-136), so With a target would hold it at full
-- whenever it shows and its rule would never fade it. The frames: TargetFrame and FocusFrame, secure unit buttons of
-- TargetFrameTemplate (Blizzard_UnitFrame/Mainline/TargetFrame.xml:52, 549 and 572) whose cast bar and target of target are their children and fade
-- with them (Mainline/TargetFrame.lua:711-718 and 738-740), as do the combo points on Forever (Camelot/ComboFrame.lua:16); BuffFrame, the buffs and
-- weapon enchants (Blizzard_BuffFrame/BuffFrame.xml:6; the debuffs are DebuffFrame and stay); ObjectiveTrackerFrame
-- (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTracker.xml:3), and with it Questie_BaseFrame, the tracker the Questie addon draws in its place,
-- while Questie is loaded (QuestieSkin.lua), the mouse over either counting for both; and DamageMeter, the game's damage meter (Blizzard_DamageMeter/DamageMeter.xml:11, loaded
-- at start on the standard and camelot clients: Blizzard_DamageMeter.toc:2). The game sets the alpha of none of the five but the tracker: of the target
-- frame's portrait and icons (Mainline/TargetFrame.lua:156, 160 and 624), of the buff buttons (BuffFrame.lua:1268 and 1357) and of the meter's session
-- windows (Blizzard_DamageMeter/DamageMeter.lua:298 and 556), never of DamageMeter itself. The windows are children of the meter (DamageMeter.lua:285),
-- so they fade with it and keep the game's Transparency, and the meter's Visibility in Edit Mode (Always, In combat, In group, Hidden:
-- DamageMeter.lua:166-193) still shows and hides it. The second and third windows are anchored to UIParent and may be moved anywhere
-- (DamageMeter.lua:312-330; three at most, :4), and a window's breakdown opens beside it (DamageMeterSourceWindow.lua:280-327), so the mouse over any
-- of them that shows, looked up by name at each pass, counts as over the meter, and a window placed apart comes back under the mouse. The tracker is a managed
-- frame of the right column while Edit Mode has it in its default place (Blizzard_ObjectiveTrackerContainer.lua:34-37,
-- Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua:57-77), and each time the interface is shown again, after Alt+Z or a cinematic, the game
-- gives it full opacity (ManagedFrameSystem.lua:79-87, 130-134 and 160; Blizzard_UIParent/UIParent.lua:5-7); Ease takes that up and fades it again.
-- Edit Mode's Opacity sets the alpha of an aura frame only where the layout has that setting, which on Forever is the external defensives frame alone
-- (Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:2141-2144, 2158-2175; Mainline/EditModePresetLayouts.lua:434-479), and the tracker's Opacity
-- is the alpha of its background (Blizzard_ObjectiveTrackerManager.lua:86-91, Blizzard_ObjectiveTrackerContainer.lua:187-189). As on the pet frame,
-- the alpha is written in a fight too, since SetAlpha is not protected; nothing is shown, hidden or moved. While the tracker's Opacity in combat
-- (Hud.lua) holds the tracker in a fight, Fading forgets the tracker with no write (ns.TrackerFades); that row reads the alpha the tracker had before
-- Fading from ns.FadeGiven, and after the fight gives the tracker back with it (ns.FadeTakesBack): the ease goes on from the alpha of the fight, so
-- the tracker does not show at full for a moment. Questie's tracker is handed over the same way while QuestieSkin.lua's Opacity in combat holds it
-- (ns.QuestieFades). The rules: in combat as for In combat below; in a group, IsInGroup, as the game's own group headers
-- ask (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua:268); in an instance, IsInInstance (InstanceDocumentation.lua:170-178); outside
-- an instance, unless IsInInstance plainly says the player is in a dungeon, a raid, a battleground or an arena; mounted,
-- IsMounted (PlayerScriptDocumentation.lua:1399-1406) or a druid's travel, aquatic or flight form, by GetShapeshiftFormID as the game asks it
-- (Blizzard_SharedXMLBase/ModelSceneUtil.lua:23) and the form IDs 3, 4 and 27 (Blizzard_FrameXMLBase/Constants.lua:329-333). None of them marks a
-- return secret; a withheld answer counts as the rule holding, so the frame stays shown, and a call that fails as the rule not holding, but for
-- outside an instance, where a failed call holds too, as nothing then says the player is in one. Only outside an instance is meant for the objective
-- tracker: with Faded opacity at 0% the tracker is gone in dungeons and raids, comes back under the mouse over the part it draws and in Edit Mode,
-- and shows again outside, and its Opacity in combat still comes first in a fight. The step asks every rule again, so no event is needed. The
-- skyriding, flying and Mythic+ rules are left out, as EnhanceQoL leaves them out on Forever, and so are its difficulty scopes for the tracker
-- (Mythic+, delves, timewalking: Forever has only normal dungeons and raids) and its Hide and OnShow hooks on the tracker's modules, since Fading
-- writes only the alpha (EnhanceQoLDungeonRaid/ObjectiveTracker.lua:1-145).
-- These rules follow the frame visibility rules of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission, and so do the damage meter's
-- row (EnhanceQoLDamageMeter/DamageMeter.lua:640-727) and the fade of other addons' minimap buttons (EnhanceQoL/EnhanceQoL.lua:5740-5800).

local KEY = "fade"
local PART = "fade"
local EVERY = 0.05
-- The most seconds a faded frame takes to come back to full, whatever Fade time says.
local RETURN_TIME = 0.1
-- An alpha at or under this is a frame something else holds hidden.
local HIDDEN = 0.001

-- row: the setting that switches it. frames: names in the game, a dotted name reaching down from a global. hover: the frame whose rectangle
-- counts as under the mouse (the frames themselves when it is left out). rule: a row of When shown, whose setting is a rule (RULES) and not a switch.
-- targeted: frames the game shows only while there is a target, which With a target does not hold at full. more: the function, or the name of the
-- function of ns, that gives the frames of other addons or of Flat UI's own the row fades too, each { frame = frame }, asked at each pass, each also
-- under the mouse. beside: frames by name that count as under the mouse while they show, whether or not the row fades them. opens: the row is at
-- full the pass a frame joins its more. busy: the function that gives true while the frames of its more (the list of { frame, name } of this
-- pass) are in use. alpha: the setting of the row's own faded opacity, a percent as text or "page" for the page's Faded opacity.
-- The meter's session windows (DamageMeterSessionWindow1 to 3, DamageMeter.lua:285) and the breakdown of each, a parentKey with no global name
-- (DamageMeterSessionWindow.lua:119-128, DamageMeterSessionWindow.xml:84 and 129).
local METER_PARTS = {}
for index = 1, 3 do
	METER_PARTS[#METER_PARTS + 1] = "DamageMeterSessionWindow" .. index
	METER_PARTS[#METER_PARTS + 1] = "DamageMeterSessionWindow" .. index .. ".MinimizeContainer.SourceWindow"
end
-- The frames of Flat UI's own that Unit frames puts on PlayerFrame itself, outside its container and its content, which the Player frame row fades with
-- them: the body, the name row and the shadow (ns.UnitFrameExtra.pieces, UnitFrames.lua). None while that file gives none.
local function PlayerPieces()
	local extra = ns.UnitFrameExtra
	if type(extra) == "table" and type(extra.pieces) == "function" then
		return extra.pieces("player")
	end
	return nil
end
-- The micro buttons and the help ticket button, which fade with MicroMenuContainer and each count as under the mouse while it shows.
local MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "HelpMicroButton",
	"StoreMicroButton", "MainMenuMicroButton", "HelpOpenWebTicketButton" }
-- The bag buttons, which fade with BagsBar and each count as under the mouse while it shows.
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "BagBarExpandToggle", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
	"CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }
-- Flat UI's own experience and reputation bar (XpBar.lua), while it is the one in use, under its name, so Fade the block takes it over while block 1
-- holds it (ns.BarBlockFades). None while the game's bar is in use or the bar is not made yet.
local XP_BAR = "FlatUIXpBar"
local function XpBarFrames()
	if type(ns.XpOwn) ~= "function" or type(ns.XpBarFrame) ~= "function" or not ns.XpOwn() then
		return nil
	end
	local frame = ns.XpBarFrame()
	return frame ~= nil and { { frame = frame, name = XP_BAR } } or nil
end
-- A gain rising over the bar, its fill sliding up or a level or standing flash holds the bar at full while it runs (ns.XpBarLively).
local function XpBarBusy()
	return type(ns.XpBarLively) == "function" and ns.XpBarLively() == true
end
-- Questie's tracker, which takes the place of the objective tracker while the Questie addon is loaded (QuestieSkin.lua). None without it.
local QUESTIE = "Questie_BaseFrame"
local function QuestieFrame()
	local base = rawget(_G, QUESTIE)
	if type(base) ~= "table" or ns.IsSecret(base) or ns.Forbidden(base) then
		return nil
	end
	return base
end
local function QuestieTracker()
	local base = QuestieFrame()
	return base ~= nil and { { frame = base, name = QUESTIE } } or nil
end
-- The bag windows, Flat UI's and the game's.
local BAG_WINDOWS = { "FlatUIBags", "FlatUIBank", "ContainerFrameCombinedBags", "BankFrame" }
for index = 1, 7 do
	BAG_WINDOWS[#BAG_WINDOWS + 1] = "ContainerFrame" .. index
end
-- The row of the bag windows, whose more and busy are given below, once the functions they call are made.
local WINDOWS_ROW = { row = "bagWindows", label = "Bag windows", frames = {}, opens = true }
local ENTRIES = {
	-- Flat UI's page arrows lie left of its main bar (OwnBars.lua); with the game's buttons the names are not there.
	{ bar = true, row = "main", label = "Main action bar", frames = { "MainActionBar" }, beside = { "FlatUIBar1PageUp", "FlatUIBar1PageDown" } },
	{ bar = true, row = "bar2", label = "Action bar 2", frames = { "MultiBarBottomLeft" } },
	{ bar = true, row = "bar3", label = "Action bar 3", frames = { "MultiBarBottomRight" } },
	{ bar = true, row = "bar4", label = "Action bar 4", frames = { "MultiBarRight" } },
	{ bar = true, row = "bar5", label = "Action bar 5", frames = { "MultiBarLeft" } },
	{ bar = true, row = "bar6", label = "Action bar 6", frames = { "MultiBar5" } },
	{ bar = true, row = "bar7", label = "Action bar 7", frames = { "MultiBar6" } },
	{ bar = true, row = "bar8", label = "Action bar 8", frames = { "MultiBar7" } },
	{ bar = true, row = "stance", label = "Stance bar", frames = { "StanceBar" } },
	{ bar = true, row = "pet", label = "Pet bar", frames = { "PetActionBar" } },
	{ row = "micro", label = "Micro menu", frames = { "MicroMenuContainer" }, beside = MICRO_BUTTONS, alpha = "microAlpha" },
	{ row = "bags", label = "Bag bar", frames = { "BagsBar" }, beside = BAG_BUTTONS, alpha = "bagsAlpha" },
	WINDOWS_ROW,
	{ row = "playerFrame", label = "Player frame", frames = { "PlayerFrame.PlayerFrameContainer", "PlayerFrame.PlayerFrameContent" }, hover = "PlayerFrame",
		more = PlayerPieces },
	{ row = "petFrame", label = "Pet frame", frames = { "PetFrame" } },
	{ row = "xpBar", label = "Experience bar", frames = {}, more = XpBarFrames, busy = XpBarBusy },
	{ row = "minimapButtons", label = "Minimap buttons", hover = "MinimapCluster", more = "MapAddonButtons",
		frames = { "MinimapCluster.Tracking", "MinimapCluster.IndicatorFrame", "GameTimeFrame", "TimeManagerClockButton", "AddonCompartmentFrame" } },
	{ rule = true, targeted = true, row = "targetFrame", label = "Target frame", frames = { "TargetFrame" } },
	{ rule = true, row = "focusFrame", label = "Focus frame", frames = { "FocusFrame" } },
	{ rule = true, row = "buffs", label = "Buffs", frames = { "BuffFrame" } },
	-- The tracker's own frame runs down to the foot of the right column whatever it lists (Blizzard_ObjectiveTrackerContainer.lua:207-228,
	-- UIParentPanelManager.lua:822-829); its NineSlice runs from its top to under the last module (Blizzard_ObjectiveTrackerContainer.lua:117-119).
	{ rule = true, row = "objectiveTracker", label = "Objective tracker", frames = { "ObjectiveTrackerFrame" }, hover = "ObjectiveTrackerFrame.NineSlice",
		more = QuestieTracker },
	{ rule = true, row = "damageMeter", label = "Damage meter", frames = { "DamageMeter" }, beside = METER_PARTS },
}
-- The forms of a druid that count as mounted, by GetShapeshiftFormID: travel, aquatic and flight form (Blizzard_FrameXMLBase/Constants.lua:329-333).
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true }

-- bar: a game action bar. While Leave the game's action bars alone is on the row does nothing, and a bar this module faded is given its alpha back,
-- but for the main bar and bars 2 to 8 while Flat UI's buttons are in use, which fade Flat UI's own bar either way (OwnRow).
-- orig: the alpha a frame had before the first write. sent: the last alpha written. value: where the ease is. idle: seconds a row has had nothing to keep it
-- at full. found: the frames reached by name. clock: seconds since the last step. added: per frame of another addon a row fades (more), that row.
local weak = { __mode = "k" }
local state = { orig = setmetatable({}, weak), sent = setmetatable({}, weak), value = setmetatable({}, weak), idle = {}, found = {}, clock = 0,
	added = setmetatable({}, weak) }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- True for a row of the main bar or bars 2 to 8 (those with a more, given below) while Flat UI's buttons are in use: the row fades Flat UI's own
-- bar, a frame of the addon's, whatever Leave the game's action bars alone says, and never the game's parked bar, which Quick Keybind Mode shows
-- at full for a time (OwnBars.lua).
local function OwnRow(entry)
	if entry.bar ~= true or type(entry.more) ~= "function" or type(ns.OwnOn) ~= "function" then
		return false
	end
	local ok, on = pcall(ns.OwnOn)
	return ok and on == true
end

-- True for a row of a game action bar that is left alone now.
local function Left(entry)
	return entry.bar == true and ns.HandsOff() and not OwnRow(entry)
end

-- The frame behind a name, or nil while the game has not made it or it cannot be touched.
local function Resolve(name)
	local frame = state.found[name]
	if frame then
		return frame
	end
	local first, rest = name:match("^([^.]+)%.?(.*)$")
	local at = _G[first]
	for key in rest:gmatch("[^.]+") do
		if type(at) ~= "table" or ns.IsSecret(at) then
			return nil
		end
		local ok, child = pcall(function()
			return at[key]
		end)
		at = ok and child or nil
	end
	if type(at) == "table" and not ns.IsSecret(at) and not ns.Forbidden(at) and type(at.SetAlpha) == "function" then
		state.found[name] = at
		return at
	end
	return nil
end

-- The alpha of a frame, and true when the client gave a real number; 1 and false when it did not.
local function Alpha(frame)
	local ok, alpha = pcall(frame.GetAlpha, frame)
	if ok and ns.Finite(alpha) then
		return alpha, true
	end
	return 1, false
end

-- A withheld answer counts as the frame being under the mouse, so that it stays shown. A frame Hidden frames holds is not (Gone, below).
local Gone
local function Over(frame)
	if Gone(frame) then
		return false
	end
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and (ns.IsSecret(over) or over == true)
end

local function Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and (ns.IsSecret(kind) or kind ~= nil)
end

local function FlyoutOpen()
	local flyout = _G.SpellFlyout
	if type(flyout) ~= "table" or ns.IsSecret(flyout) or ns.Forbidden(flyout) then
		return false
	end
	local ok, shown = pcall(flyout.IsShown, flyout)
	return ok and (ns.IsSecret(shown) or shown == true)
end

local function Fighting()
	if InCombatLockdown() then
		return true
	end
	if type(UnitAffectingCombat) ~= "function" then
		return false
	end
	local ok, fighting = pcall(UnitAffectingCombat, "player")
	return ok and (ns.IsSecret(fighting) or fighting == true)
end

local function HasTarget()
	if type(UnitExists) ~= "function" then
		return false
	end
	local ok, exists = pcall(UnitExists, "target")
	return ok and (ns.IsSecret(exists) or exists == true)
end

-- While casting: true while the player casts or channels, or for CAST_HOLD seconds after a spell or an item was used (state.castAt, heard on the
-- driver's own frame), so an instant spell counts too. A withheld name counts as no cast.
local CAST_HOLD = 0.15
local CAST_READS = { "UnitCastingInfo", "UnitChannelInfo" }
local function Casting()
	if state.castAt and GetTime() - state.castAt < CAST_HOLD then
		return true
	end
	for _, name in ipairs(CAST_READS) do
		local read = _G[name]
		if type(read) == "function" then
			local ok, spell = pcall(read, "player")
			if ok and not ns.IsSecret(spell) and type(spell) == "string" then
				return true
			end
		end
	end
	return false
end

-- While /flatui move is open (Movers.lua), so a faded frame is seen whole as its box is lined up.
local function MoversOpen()
	local kit = ns.MoverKit
	return type(kit) == "table" and type(kit.IsOpen) == "function" and kit.IsOpen() == true
end

-- What keeps every row at full opacity, whatever the mouse does. With a target is asked apart (Step), as it does not hold a targeted row.
local function Wanted()
	return (Opt("combat") and Fighting()) or Holding() or FlyoutOpen() or ns.EditModeOpen() or MoversOpen()
		or (Opt("cast") == true and Casting())
end

-- In a party or a raid.
local function Grouped()
	if type(IsInGroup) ~= "function" then
		return false
	end
	local ok, grouped = pcall(IsInGroup)
	return ok and (ns.IsSecret(grouped) or grouped == true)
end

-- In a dungeon, a raid, a battleground or an arena.
local function Inside()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside = pcall(IsInInstance)
	return ok and (ns.IsSecret(inside) or inside == true)
end

-- Outside every dungeon, raid, battleground and arena: true unless the game plainly says the player is in one, so that a withheld answer and a
-- call that fails both leave the frame shown.
local function Outside()
	if type(IsInInstance) ~= "function" then
		return true
	end
	local ok, inside = pcall(IsInInstance)
	return not (ok and not ns.IsSecret(inside) and inside == true)
end

-- Neither on a mount nor in a druid's travel form. A withheld answer counts as not mounted.
local function Unmounted()
	if type(IsMounted) == "function" then
		local ok, mounted = pcall(IsMounted)
		if ok and not ns.IsSecret(mounted) and mounted == true then
			return false
		end
	end
	if type(GetShapeshiftFormID) == "function" then
		local ok, form = pcall(GetShapeshiftFormID)
		if ok and ns.Finite(form) and TRAVEL_FORMS[form] then
			return false
		end
	end
	return true
end

-- The rules of When shown, each true while its frame is to be at full opacity. Always is not one: that row leaves its frame alone.
local RULES = { combat = Fighting, group = Grouped, instance = Inside, outside = Outside, unmounted = Unmounted }
-- The answers of one step, so a rule is asked at most once a step.
local asked = {}

local function Holds(rule)
	local answer = asked[rule]
	if answer == nil then
		answer = RULES[rule]() == true
		asked[rule] = answer
	end
	return answer
end

-- True for a row that fades its frames: a switch that is on, or a rule of When shown other than Always.
local function Active(entry)
	local value = Opt(entry.row)
	if entry.rule then
		return RULES[value] ~= nil
	end
	return value == true
end

-- True for a frame another part of Flat UI holds the alpha of now: a bar the action bar block fades, or the objective tracker or Questie's while
-- Opacity in combat has it in a fight.
local function Elsewhere(frame, name)
	return (name ~= nil and ns.BarBlockFades and ns.BarBlockFades(name)) or (ns.TrackerFades and ns.TrackerFades(frame))
		or (ns.QuestieFades and ns.QuestieFades(frame)) or false
end

-- True for a frame Hidden frames (Hide.lua) has under its hidden frame, or one under such a frame: no alpha is written on it.
function Gone(frame)
	local hide = ns.HideFrames
	return type(hide) == "table" and type(hide.Holds) == "function" and hide.Holds(frame) == true
end

-- The write. It raises when the game refuses, which ns.EachPart counts for the part.
local function Put(frame, alpha)
	if state.sent[frame] ~= alpha then
		frame:SetAlpha(alpha)
		state.sent[frame] = alpha
	end
	state.value[frame] = alpha
end

-- A frame goes back to the alpha it had, unless something else has set its own since, or Hidden frames holds it (no write then).
local function Release(frame)
	local alpha = state.orig[frame]
	if alpha == nil then
		return
	end
	local sent = state.sent[frame]
	state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
	if sent ~= nil and not Gone(frame) and math.abs(Alpha(frame) - sent) < 0.01 then
		pcall(frame.SetAlpha, frame, alpha)
	end
end

local function ReleaseAll()
	for frame in pairs(state.orig) do
		Release(frame)
	end
	state.added = setmetatable({}, weak)
end

-- True when a frame is root or hangs from it, looked up through its parents.
local function Under(frame, root)
	local at = frame
	for _ = 1, 20 do
		if at == root then
			return true
		elseif type(at) ~= "table" or ns.IsSecret(at) or ns.Forbidden(at) then
			return false
		end
		local ok, parent = pcall(at.GetParent, at)
		if not ok then
			return false
		end
		at = parent
	end
	return false
end

-- Hidden frames (Hide.lua) is about to put root under its hidden frame: root, and every frame under it this module fades, get the alpha they had
-- now, while they still show, and are forgotten, so they come back at their own alpha and nothing is put back over it then.
function ns.FadeLetGo(root)
	if root == nil then
		return
	end
	for frame in pairs(state.orig) do
		if Under(frame, root) then
			Release(frame)
		end
	end
end

-- The frames of other addons, or of Flat UI's own, that a row faded get their alpha back: those the row no longer lists, or with keep left out all of
-- them.
local function Forget(row, keep)
	for frame, owner in pairs(state.added) do
		if owner == row and not (keep and keep[frame]) then
			state.added[frame] = nil
			Release(frame)
		end
	end
end

-- The frames of other addons, or of Flat UI's own, that a row fades this pass (entry.more, a function or the name of one of ns), each { frame, name }. A
-- frame the row no longer lists gets its alpha back. The second answer is true when a frame joined the row in this pass.
local function Added(entry)
	local list, listed, fresh = {}, {}, false
	local fn = entry.more
	if type(fn) ~= "function" then
		fn = ns[fn]
	end
	if type(fn) == "function" then
		local ok, found = pcall(fn)
		if ok and type(found) == "table" then
			for _, each in ipairs(found) do
				local frame = type(each) == "table" and each.frame or nil
				if frame ~= nil and not listed[frame] and not ns.Forbidden(frame) and type(frame.SetAlpha) == "function" then
					listed[frame] = true
					list[#list + 1] = { frame, each.name }
				end
			end
		end
	end
	Forget(entry.row, listed)
	for frame in pairs(listed) do
		fresh = fresh or state.added[frame] ~= entry.row
		state.added[frame] = entry.row
	end
	return list, fresh
end

-- True while a frame shows. A withheld answer counts as shown.
local function Shown(frame)
	local ok, shown = pcall(frame.IsVisible, frame)
	return ok and (ns.IsSecret(shown) or shown == true)
end

-- The bag windows that show, Flat UI's and the game's, each { frame, name }: the more of the row of the bag windows.
local function BagWindows()
	local list = {}
	for _, name in ipairs(BAG_WINDOWS) do
		local frame = Resolve(name)
		if frame and Shown(frame) then
			list[#list + 1] = { frame = frame, name = name }
		end
	end
	return list
end

-- True while the bag windows are in use beyond the mouse: the game's split box shows, or the keyboard is in a box of one of the windows that
-- show (added, the list of { frame, name } of this pass), looked up through the parents of the frame that has it. A withheld answer counts as in use.
local function WindowsBusy(added)
	local split = Resolve("StackSplitFrame")
	if split and Shown(split) then
		return true
	end
	if type(GetCurrentKeyBoardFocus) ~= "function" or added == nil or #added == 0 then
		return false
	end
	local ok, at = pcall(GetCurrentKeyBoardFocus)
	if not ok or at == nil then
		return false
	elseif ns.IsSecret(at) then
		return true
	end
	local windows = {}
	for _, held in ipairs(added) do
		windows[held[1]] = true
	end
	for _ = 1, 20 do
		if ns.Forbidden(at) then
			return false
		elseif windows[at] then
			return true
		end
		local okParent, parent = pcall(at.GetParent, at)
		if not okParent then
			return false
		end
		at = parent
	end
	return false
end
WINDOWS_ROW.more, WINDOWS_ROW.busy = BagWindows, WindowsBusy

-- While Flat UI's buttons are in use, the game's main bar and bars 2 to 8 are parked at alpha 0, which this module leaves alone, so each of those
-- rows fades Flat UI's own bar in their place (ns.OwnBarOf, OwnBars.lua), under the game bar's name so Fade the block still takes it over.
for _, entry in ipairs(ENTRIES) do
	local game = entry.bar and entry.row ~= "stance" and entry.row ~= "pet" and entry.frames[1] or nil
	if game then
		entry.more = function()
			if type(ns.OwnOn) ~= "function" or type(ns.OwnBarOf) ~= "function" then
				return nil
			end
			local okOn, on = pcall(ns.OwnOn)
			if not (okOn and on == true) then
				return nil
			end
			local okBar, own = pcall(ns.OwnBarOf, game)
			if okBar and own then
				return { { frame = own, name = game } }
			end
			return nil
		end
	end
end

-- True while the mouse is over one of the frames that count as a row's (entry.beside) and that shows. A withheld answer counts as shown.
local function Beside(names)
	for _, name in ipairs(names) do
		local frame = Resolve(name)
		if frame then
			local ok, shown = pcall(frame.IsVisible, frame)
			if ok and (ns.IsSecret(shown) or shown == true) and Over(frame) then
				return true
			end
		end
	end
	return false
end

-- The alpha a frame had before this module wrote on it, for the action bar block, which takes over the bars it holds, and for the minimap buttons
-- and the tracker's Opacity in combat (Hud.lua), which take a frame over for a time.
function ns.FadeGiven(frame)
	return state.orig[frame]
end

-- The tracker's Opacity in combat (Hud.lua) gives the tracker back here when it lets it go (the fight is over, or that row or its page changed), while
-- the tracker's row of When shown fades it, and QuestieSkin.lua gives Questie's tracker back the same way. alpha, the one it had before Fading, is
-- kept to be put back, and the ease goes on from the alpha the tracker has now, so it does not go to full and fade again. False when this module
-- does not take the tracker, or alpha is one something else held hidden, which this module leaves alone (Ease): that row then puts alpha back itself.
function ns.FadeTakesBack(frame, alpha)
	if frame == nil or not ns.Finite(alpha) or alpha <= HIDDEN or not ns.Enabled(KEY) or ns.PartStopped(KEY, PART)
		or RULES[Opt("objectiveTracker")] == nil then
		return false
	end
	local questie = frame == QuestieFrame()
	if not questie and frame ~= Resolve("ObjectiveTrackerFrame") then
		return false
	end
	local current = Alpha(frame)
	state.orig[frame], state.value[frame], state.sent[frame] = alpha, current, current
	-- Questie's tracker is one of the row's more frames, given back with the row (Forget).
	if questie then
		state.added[frame] = "objectiveTracker"
	end
	return true
end

-- One frame toward the wanted alpha. A target of nil holds the frame where it is.
local function Ease(frame, target, step, name)
	-- Hidden frames holds it, or a frame it hangs from, off the screen: no write. Its alpha went back as it went (ns.FadeLetGo); anything still
	-- kept is forgotten, so it is taken up from the alpha it comes back with.
	if Gone(frame) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	-- A button the minimap page switches off stays off whatever Fading says, and the objective tracker and Questie's are left to their Opacity in
	-- combat while that holds them in a fight: that has written its own alpha, so nothing is put back.
	if (ns.MapButtonOff and ns.MapButtonOff(frame)) or (ns.TrackerFades and ns.TrackerFades(frame)) or (ns.QuestieFades and ns.QuestieFades(frame)) then
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	end
	if ns.BarBlockFades and ns.BarBlockFades(name) then
		Release(frame)
		return
	end
	local current, known = Alpha(frame)
	if state.orig[frame] == nil then
		if current <= HIDDEN then
			return
		end
		state.orig[frame], state.value[frame] = current, current
	elseif current <= HIDDEN and (state.sent[frame] == nil or state.sent[frame] >= 0.01) then
		-- Something else hides it now. The game keeps an alpha in steps of 1/255, so a write of this module's own below 0.01 can read back as 0.
		state.orig[frame], state.sent[frame], state.value[frame] = nil, nil, nil
		return
	elseif known and state.sent[frame] ~= nil and math.abs(current - state.sent[frame]) >= 0.01 then
		-- Something else has given it another alpha since the last write, as the game gives the tracker full opacity when the interface is shown
		-- again: that is its alpha now, the one put back, and the ease starts from it.
		state.orig[frame], state.value[frame], state.sent[frame] = current, current, nil
	end
	local value = state.value[frame]
	if target == nil then
		return
	elseif value < target then
		value = math.min(target, value + step)
	elseif value > target then
		value = math.max(target, value - step)
	end
	if value ~= (state.sent[frame] or state.orig[frame]) then
		ns.EachPart(KEY, PART, Put, frame, value)
	end
end

-- The faded opacity of a row, from 0 to 1: its own (entry.alpha) where it has one set to a percent, else the page's (floor).
local function RowFloor(entry, floor)
	local own = entry.alpha and tonumber(Opt(entry.alpha))
	if ns.Finite(own) then
		return math.min(math.max(own, 0), 100) / 100
	end
	return floor
end

local function Step(dt)
	if ns.PartStopped(KEY, PART) then
		ReleaseAll()
		return
	end
	local floor, delay, seconds = Opt("alpha") / 100, Opt("delay") / 1000, math.max(Opt("time") / 1000, 0.05)
	-- Down over Fade time; back to full in a tenth of a second at most, as the bar block does.
	local step = dt / seconds
	local up = dt / math.min(seconds, RETURN_TIME)
	local always, targeted = Wanted(), Opt("target") and HasTarget()
	for rule in pairs(asked) do
		asked[rule] = nil
	end
	for _, entry in ipairs(ENTRIES) do
		local frames = entry.cache
		if OwnRow(entry) then
			-- Flat UI's bar only, through Added: the game's bar gets back any alpha this module gave it before the switch.
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame and state.orig[frame] ~= nil then
					Release(frame)
				end
			end
		elseif not frames and Left(entry) then
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame then
					frames[#frames + 1] = { frame, name }
				end
			end
		elseif not frames then
			frames = {}
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame then
					frames[#frames + 1] = { frame, name }
				end
			end
			if #frames == #entry.frames then
				entry.cache = frames
			end
		end
		if Left(entry) or not Active(entry) then
			for _, held in ipairs(frames) do
				Release(held[1])
			end
			if entry.more then
				Forget(entry.row)
			end
			state.idle[entry.row] = nil
		elseif #frames > 0 or entry.more then
			local added, fresh = nil, false
			if entry.more then
				added, fresh = Added(entry)
			end
			-- A bag window that opened this pass, or one in use, holds its row at full.
			local full = always or (targeted and not entry.targeted) or (entry.rule == true and Holds(Opt(entry.row)))
				or (entry.opens == true and fresh) or (entry.busy ~= nil and entry.busy(added) == true)
			if not full then
				local hover = entry.hover and Resolve(entry.hover)
				if hover then
					full = Over(hover)
				else
					for _, held in ipairs(frames) do
						if Over(held[1]) then
							full = true
							break
						end
					end
				end
				-- Another addon's button beside the map, a frame of Flat UI's own on the player frame, a bag window, a bag button wherever it lies, or a
				-- window of the meter placed apart, counts as the row's own under the mouse.
				for _, held in ipairs(not full and added or {}) do
					if Over(held[1]) then
						full = true
						break
					end
				end
				if not full and entry.beside then
					full = Beside(entry.beside)
				end
			end
			local idle = full and 0 or (state.idle[entry.row] or 0) + dt
			state.idle[entry.row] = idle
			local target = full and 1 or (idle >= delay and RowFloor(entry, floor) or nil)
			local by = target == 1 and up or step
			for _, held in ipairs(frames) do
				Ease(held[1], target, by, held[2])
			end
			for _, held in ipairs(added or {}) do
				Ease(held[1], target, by, held[2])
			end
		end
	end
end

-- The fight starts: every row with In combat ticked, and every row of When shown at Only in combat, is at full opacity now, not after the ease.
-- With In combat off a fight raises nothing else. A frame Hidden frames holds is not written (Gone).
local function FightStarts()
	if ns.PartStopped(KEY, PART) then
		return
	end
	local combat = Opt("combat") == true
	for _, entry in ipairs(ENTRIES) do
		if Active(entry) and not Left(entry) and (combat or (entry.rule and Opt(entry.row) == "combat")) then
			state.idle[entry.row] = 0
			for _, name in ipairs(entry.frames) do
				local frame = Resolve(name)
				if frame and state.orig[frame] ~= nil and state.value[frame] < 1 and not Elsewhere(frame, name) and not Gone(frame) then
					ns.EachPart(KEY, PART, Put, frame, 1)
				end
			end
			for frame, owner in pairs(state.added) do
				if owner == entry.row and state.orig[frame] ~= nil and state.value[frame] < 1 and not Elsewhere(frame) and not Gone(frame) then
					ns.EachPart(KEY, PART, Put, frame, 1)
				end
			end
		end
	end
end

local driver

local function Tick(_, elapsed)
	state.clock = state.clock + elapsed
	if state.clock < EVERY then
		return
	end
	local dt = state.clock
	state.clock = 0
	ns.Try(KEY, Step, dt)
end

local function Refresh()
	if ns.Enabled(KEY) then
		if not driver then
			driver = CreateFrame("Frame")
			ns.Own[driver] = true
			driver:SetScript("OnUpdate", Tick)
			-- While casting: the time of the player's last spell or item use. An event reaches a hidden frame too.
			for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED" }) do
				pcall(driver.RegisterUnitEvent, driver, event, "player")
			end
			driver:SetScript("OnEvent", function()
				state.castAt = GetTime()
			end)
		end
		driver:Show()
		Step(0)
	else
		if driver then
			driver:Hide()
		end
		ReleaseAll()
		state.idle = {}
	end
end

-- The lines of /flatui status: how many frames the module holds and fades, and the rows the game has no frame for (not the bag windows, which
-- are faded only while they show).
local function Status()
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, PART) then
		return {}
	end
	local held, faded = 0, 0
	for frame, original in pairs(state.orig) do
		held = held + 1
		if (state.sent[frame] or original) < original - 0.001 then
			faded = faded + 1
		end
	end
	local lines = { ("Fading: %d %s, %d faded"):format(held, held == 1 and "frame" or "frames", faded) }
	local missing = {}
	for _, entry in ipairs(ENTRIES) do
		if Active(entry) and not Left(entry) and #entry.frames > 0 then
			local any = false
			for _, name in ipairs(entry.frames) do
				any = any or Resolve(name) ~= nil
			end
			if not any then
				missing[#missing + 1] = entry.label
			end
		end
	end
	if #missing > 0 then
		lines[#lines + 1] = "Fading: no frame found for " .. table.concat(missing, ", ")
	end
	return lines
end

ns.Register(KEY, {
	label = "Fading",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	Status = Status,
	events = { PLAYER_REGEN_DISABLED = FightStarts },
})

-- /flatui status names a game action bar this module has faded in this session.
ns.ClickPathReporter(function()
	local names = {}
	for _, entry in ipairs(ENTRIES) do
		if entry.bar then
			for _, name in ipairs(entry.frames) do
				local frame = state.found[name]
				if frame ~= nil and state.orig[frame] ~= nil then
					names[#names + 1] = entry.label
				end
			end
		end
	end
	if #names > 0 then
		return "Click path: Flat UI faded " .. table.concat(names, ", ") .. "."
	end
	return nil
end)
