local _, ns = ...

-- Movers put a frame where the player wants it. Each frame has a handle of the addon's own on
-- UIParent. Dragging the handle saves a point and offsets, and the game frame is placed with
-- ClearAllPoints and SetPoint to UIParent. The position is applied on events, after the panel
-- manager has placed a window, and by a check twice a second that runs on a frame of the addon's
-- own. A saved spot is never changed by the size of the screen: UIParent has another size under the
-- game's own scale and under a custom one, so a spot is cut to the screen only where it is used or dropped,
-- and a part of the frame stays on the screen.
-- An open window also has two frames of the addon's own, children of the window: a title bar two levels above
-- the window, and a grip in the bottom right corner. A press on the title bar, or on an empty part of the window
-- (the game reports every press, and a window is found from the frame under the cursor), places the window the
-- same way while the button is held. The grip sizes it, from 60% to 150%, with the top left corner fixed. The grip
-- is a drawing and takes no mouse once the game has reported a press: a game button or an item slot in the corner of
-- a window would lose its clicks to a frame of the addon's above it, so a press in the corner counts as the grip's
-- only where the frame under the cursor is not a control. The Map & Quest Log window has both while it is small; at full size and
-- in the gamepad interface the game keeps it, with the scale the game gave it.
-- A frame Edit Mode owns is placed with SetPointBase, ClearAllPointsBase and SetScaleBase, the engine's own
-- widget methods that Edit Mode keeps on the frame when it replaces SetPoint, ClearAllPoints and SetScale with
-- Lua. That Lua is never called by the addon. A frame that is protected (every action bar) is placed inside a SecureHandlerBaseTemplate
-- frame's snippet instead and never with a call of the addon's, out of combat only. Edit Mode lays its frames out again at
-- login, when a layout is applied or changed, on a specialisation change and when it closes, so they are
-- placed again on the next frame, and they are left to Edit Mode while it is open. A frame the player placed or
-- sized in Edit Mode keeps what Edit Mode gave it: its saved spot is dropped when Edit Mode closes. A frame a container lays
-- out and a bar of the action bars are placed again by the game's layout passes, at each edge of a fight among others. Nothing is
-- hooked on them and nothing is placed while a fight is on: the spot goes into the Edit Mode layout in use (LayoutSpots.lua), which
-- the game places the bar from, and on a layout that cannot be written the bar is placed out of combat by the check and the events
-- and goes back to the game's spot in a fight. A frame that hangs from another frame Edit Mode owns goes with that frame.
-- A handle can be put on the horizontal middle of the screen at the height it has: it snaps there while it is dragged, a button on it or Alt
-- and a click puts it there, and the handles that are ticked go together. The dragged handle follows the cursor a frame at a time, which lets
-- it snap. A window dragged by its title snaps there too, which is the way to centre a window that has no handle. A centred frame is saved by
-- the point in the middle column on its row with no offset across, so it stays in the middle at any UI scale (ns.MoverCentred gives that point
-- to the tooltip, which hangs from it at a fixed spot).
-- A module can hold system frames at spots of its own with ns.MoverHold: they are placed like a frame with a saved spot, have no box and keep the
-- saved spots they may also have.

local KEY = "movers"
local TOOLTIP = "FlatUITooltip"
local ROW = "FlatUICooldowns"
local KEEP_EVERY = 0.5
local HANDLES_EVERY = 0.25
local PICK_EVERY = 0.1
-- A frame this close to its saved spot is in place, in the units of the frame.
local TOLERANCE = 0.5
local MAX_CORRECTIONS = 10
local XP_NAME = "MainStatusTrackingBarContainer"
local CORRECTION_WINDOW = 60
local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 2, 0.05
-- The size of a handle for a frame that is smaller than MIN_SIZE or has no size to measure.
local NOMINAL_WIDTH, NOMINAL_HEIGHT = 200, 40
local MIN_SIZE = 16
-- A saved spot keeps at least this much of a frame on the screen, in the units of UIParent.
local KEEP_ON_SCREEN = 48
-- The frame levels a box can have: the smaller the box, the higher its level.
local BOX_LEVELS = 500
local MAX_DEPTH = 40
-- Reset all asks for a second click within this many seconds.
local RESET_ASK = 3
-- The size of the Movers panel.
local BAR_WIDTH, BAR_HEIGHT = 440, 156
-- The window drag and size, in one table so that the file keeps its locals. height and right: the title bar is this high and
-- stops this far short of the right edge of its window, which leaves the close button clear. level: how many levels above its
-- window the title bar lies. start: a press becomes a drag once the cursor has moved this far, in the units of UIParent.
-- corner: the side of the corner grip. min, max and step: the size of a window, in percent. hover: how often a corner
-- grip looks at the cursor. part: the part of the module that makes the grips, for /flatui status. margin: how far in from the
-- corner of a window the grip takes the mouse before the game has reported a press. controls: what keeps its clicks, by object type,
-- loose: the types among them that give a drag to a key the player holds, and scripts: what keeps clicks on a frame of any type,
-- which a held key overrules as well. A model turns with the mouse, and the model of the character window fills the left pane.
local WIN = { height = 22, right = 28, level = 2, start = 4, corner = 18, min = 60, max = 150, step = 5, hover = 0.1, part = "window titles",
	margin = 4, noMove = "This window cannot be moved in combat.", noSize = "This window cannot be sized in combat.",
	controls = { "Button", "EditBox", "Slider", "Model", "ModelScene", "ColorSelect", "SimpleHTML", "MessageFrame", "ScrollingMessageFrame", "MovieFrame", "Minimap" },
	loose = { Model = true, ModelScene = true },
	scripts = { "OnMouseDown", "OnMouseUp", "OnDragStart" } }
local HOW = "Every frame can be moved here. Drag a handle or a window's title. Ctrl and scroll changes size. Right-click puts it back."
-- A bag has a menu button on its portrait, and another over its title that opens the same menu. The title bar of a bag starts to the right
-- of the portrait, like the title bar of every window two levels above it, so the title drags the bag and the portrait still opens the menu.
local BAG_GRIP = { left = 44, level = 2 }
-- Centring a handle on the horizontal middle of the screen, in one table so that the file keeps its locals. snap: how close the middle of a
-- handle comes to the middle of the screen before it snaps there, in the units of UIParent. size: the side of the button and of the tick box
-- on a handle. rows: the point in the middle column on a row of the frame (its height from the bottom, as a fraction), which a centred frame is
-- saved by so that it stays in the middle at any UI scale. alpha: the middle line, and the line while a handle is snapped to it. ticked: the
-- handles ticked for Centre ticked, by name. drag: the handle that follows the cursor. button: the button of the Movers panel. line: the middle line.
local centre = { snap = 8, size = 14, alpha = 0.6, snapped = 1, ticked = {}, rows = { [0] = "BOTTOM", [0.5] = "CENTER", [1] = "TOP" } }

-- Addons that move frames too. Two movers on one frame fight each other.
local OTHER_MOVERS = { "MoveAny", "MoveAnything", "BlizzMove", "EditModeExpanded", "TweaksForever" }

-- Where a point of a frame is, as a fraction of its width and height from the bottom left.
local FRACTION = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

-- Frames offered without the picker. point is the point of the frame and of UIParent that the saved
-- offsets are measured from, so a frame that grows keeps growing the same way. A window gets a
-- handle only while it is open. An own frame is one of the addon's: it has no game frame to place,
-- and it places itself from its spot (ns.MoverSpot). row names the function of ns that gives the
-- frames the handle covers and the frame they hang from, and changed the one that is called when the
-- spot is set or put back. gate names the function of ns that says whether the spot has an effect: an own
-- frame with a gate has a handle only while it returns true. Windows have the names Windows.lua gives them.
-- noScale marks a frame whose scale does not reach what it holds. noBox marks a window with no handle: its
-- title bar moves it, and a handle would cover its buttons. grip sets where the title bar of a window
-- starts and how many levels above the window it lies, for a window with its own controls in the title. A
-- window in this list is placed even where the picker refuses its name.
-- layer names a child of a window whose strata its corner grip shares, for a window whose border and panes lie in a strata above it.
-- fills names a key of a window that is true while the game makes the window fill the screen: then the game sizes and places it, it
-- has no grips, and the addon puts no place and no size of its own on it. The same holds while the gamepad interface is on.
-- system marks a frame Edit Mode owns. While it is hidden and has no saved spot, it has a handle unless it is at the corner
-- Edit Mode starts every frame at or is a bar of the stacks.
-- keptHidden marks one that the game keeps hidden outside Edit Mode and that has its handle all the same.
-- stack marks a bar that Edit Mode's action bar passes place again. panel marks a system frame the panel
-- manager places as well. hideWith names a module that places the frame itself, which has no handle while
-- it is on. ownScale marks a frame whose scale is set elsewhere: a scale saved for it is not applied.
-- scaled names a function of ns that is called on the next frame after the scale of the frame is set or
-- put back, for a frame whose size another frame follows.
local LIST = {
	{ name = "AlertFrame", label = "Alerts", point = "BOTTOM", kind = "hud", noScale = true },
	{ name = "UIErrorsFrame", label = "Error text", point = "TOP", kind = "hud" },
	{ name = "UIWidgetTopCenterContainerFrame", label = "Top widgets", point = "TOP", kind = "hud" },
	{ name = "ZoneTextFrame", label = "Zone text", point = "TOP", kind = "hud" },
	-- The spot of the tooltip when its position is fixed. It starts where the game puts the tooltip.
	{ name = TOOLTIP, label = "Tooltip", point = "BOTTOMRIGHT", kind = "hud", own = true, noScale = true, width = 250, height = 150, x = -9, y = 85,
		gate = "TooltipSpotUsed" },
	-- The row of Cooldown icons. It has no spot until one is saved.
	{ name = ROW, label = "Cooldown icons", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0,
		row = "CooldownRow", changed = "CooldownsMoved" },
	-- Where the player's own combat text starts: the middle of its first number is the middle of the box. The default is left of and
	-- below the middle of the screen, where the character stands.
	{ name = "FlatUICombatSelf", label = "Combat text: you", point = "CENTER", kind = "hud", own = true, noScale = true, width = 160, height = 40, x = -170, y = -30,
		gate = "CombatOwnShown" },
	-- Where the Outgoing scroll area starts, to the right of the character. It has a handle while Where your hits show is not Over enemies.
	{ name = "FlatUICombatOut", label = "Combat text: your hits", point = "CENTER", kind = "hud", own = true, noScale = true, width = 160, height = 40, x = 170, y = -30,
		gate = "CombatOutShown" },
	-- The box of the action bar block: one box that moves every bar the Bar block page lines up. It starts where BarBlock.lua puts it.
	{ name = "FlatUIBarBlock", label = "Action bar block", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "BarBlockRow", changed = "BarBlockMoved" },
	-- Flat UI's own experience and reputation bar (XpBar.lua). Its box is the bar's own frame, wherever the bar is; with no spot saved it sits where XpBar.lua puts it.
	{ name = "FlatUIXpBar", label = "Experience bar", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "XpBarRow", changed = "XpBarMoved" },
	{ name = "FlatUITrackers", label = "Trackers", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "TrackerRow", changed = "TrackersMoved" },
	-- Where the row of Your buffs hangs with Place set to Own position: a few icons and the room under them for the time.
	{ name = "FlatUIOwnBuffs", label = "Your buffs", point = "CENTER", kind = "hud", own = true, noScale = true, width = 120, height = 42, x = 0, y = -150,
		gate = "OwnBuffsOwnShown", changed = "OwnBuffsMoved" },
	-- Where the row of Defensives on you hangs from with Place set to Own position: four icons and the room for the caster's name.
	{ name = "FlatUIDefensives", label = "Defensives on you", point = "CENTER", kind = "hud", own = true, noScale = true, width = 137, height = 48, x = 0, y = 180,
		gate = "DefensivesOwnShown", changed = "DefensivesMoved" },
	-- Where the party cooldown rows of a raid group stack: the player's own row and the subgroup's, each with the member's name to its left.
	{ name = "FlatUIPartyRaid", label = "Party cooldowns: raid group", point = "CENTER", kind = "hud", own = true, noScale = true, width = 220, height = 150, x = -420, y = 0,
		gate = "PartyRaidShown", changed = "PartyRaidMoved" },
	-- The bars of Enemy cooldowns above the target and focus frames: eight icons, the room of the box is fixed. A bar starts above its frame.
	{ name = "FlatUIEnemyTarget", label = "Enemy cooldowns: target", point = "CENTER", kind = "hud", own = true, noScale = true, width = 200, height = 30, x = 0, y = 220,
		gate = "EnemyTargetBarShown", changed = "EnemyBarsMoved" },
	{ name = "FlatUIEnemyFocus", label = "Enemy cooldowns: focus", point = "CENTER", kind = "hud", own = true, noScale = true, width = 200, height = 30, x = 0, y = 180,
		gate = "EnemyFocusBarShown", changed = "EnemyBarsMoved" },
	{ name = "PlayerFrame", label = "Player frame", kind = "hud", system = true, scaled = "PetFrameSize" },
	{ name = "TargetFrame", label = "Target frame", kind = "hud", system = true },
	{ name = "FocusFrame", label = "Focus frame", kind = "hud", system = true },
	{ name = "PetFrame", label = "Pet frame", kind = "hud", system = true, noScale = true, ownScale = true },
	{ name = "PartyFrame", label = "Party frames", kind = "hud", system = true },
	{ name = "CompactRaidFrameContainer", label = "Raid frames", kind = "hud", system = true },
	{ name = "BossTargetFrameContainer", label = "Boss frames", kind = "hud", system = true },
	{ name = "MainActionBar", label = "Main action bar", kind = "hud", system = true, stack = true },
	{ name = "MultiBarBottomLeft", label = "Action bar 2", kind = "hud", system = true, stack = true },
	{ name = "MultiBarBottomRight", label = "Action bar 3", kind = "hud", system = true, stack = true },
	{ name = "MultiBarRight", label = "Action bar 4", kind = "hud", system = true, stack = true },
	{ name = "MultiBarLeft", label = "Action bar 5", kind = "hud", system = true, stack = true },
	{ name = "MultiBar5", label = "Action bar 6", kind = "hud", system = true },
	{ name = "MultiBar6", label = "Action bar 7", kind = "hud", system = true },
	{ name = "MultiBar7", label = "Action bar 8", kind = "hud", system = true },
	{ name = "StanceBar", label = "Stance bar", kind = "hud", system = true, stack = true },
	{ name = "PetActionBar", label = "Pet bar", kind = "hud", system = true, stack = true },
	{ name = "PossessActionBar", label = "Possess bar", kind = "hud", system = true, stack = true },
	{ name = "MultiCastActionBarFrame", label = "Totem bar", kind = "hud", system = true },
	{ name = "MainMenuBarVehicleLeaveButton", label = "Leave vehicle button", kind = "hud", system = true, stack = true },
	{ name = "MainStatusTrackingBarContainer", label = "Game's experience bar", kind = "hud", system = true, stack = true },
	{ name = "SecondaryStatusTrackingBarContainer", label = "Game's second status bar", kind = "hud", system = true, stack = true },
	{ name = "MicroMenuContainer", label = "Micro menu", kind = "hud", system = true },
	{ name = "BagsBar", label = "Bag bar", kind = "hud", system = true },
	{ name = "MinimapCluster", label = "Minimap", kind = "hud", system = true },
	{ name = "QueueStatusButton", label = "Group finder", kind = "hud", system = true },
	{ name = "ChatFrame1", label = "Chat", kind = "hud", system = true, noScale = true },
	{ name = "BuffFrame", label = "Buffs", kind = "hud", system = true },
	{ name = "DebuffFrame", label = "Debuffs", kind = "hud", system = true },
	{ name = "ExternalDefensivesFrame", label = "External defensives", kind = "hud", system = true },
	{ name = "PlayerCastingBarFrame", label = "Cast bar", kind = "hud", system = true, scaled = "StackWidths" },
	{ name = "PersonalResourceDisplayFrame", label = "Personal resource display", kind = "hud", system = true, scaled = "StackWidths" },
	{ name = "SwingTimerMainHandFrame", label = "Main hand swing timer", kind = "hud", system = true, scaled = "StackWidths" },
	{ name = "SwingTimerOffHandFrame", label = "Off hand swing timer", kind = "hud", system = true, scaled = "StackWidths" },
	{ name = "SwingTimerRangedFrame", label = "Ranged swing timer", kind = "hud", system = true, scaled = "StackWidths" },
	{ name = "ObjectiveTrackerFrame", label = "Objective tracker", kind = "hud", system = true },
	{ name = "LootFrame", label = "Loot window", kind = "hud", system = true, panel = true },
	{ name = "GameTooltipDefaultContainer", label = "Tooltip", kind = "hud", system = true, noScale = true, hideWith = "tooltip", keptHidden = true },
	{ name = "EncounterBar", label = "Encounter bar", kind = "hud", system = true },
	{ name = "ExtraAbilityContainer", label = "Extra abilities", kind = "hud", system = true },
	{ name = "TalkingHeadFrame", label = "Talking head", kind = "hud", system = true },
	{ name = "DurabilityFrame", label = "Durability", kind = "hud", system = true },
	{ name = "MirrorTimerContainer", label = "Timer bars", kind = "hud", system = true },
	{ name = "VehicleSeatIndicator", label = "Vehicle seats", kind = "hud", system = true },
	{ name = "ArcheologyDigsiteProgressBar", label = "Archaeology bar", kind = "hud", system = true },
	{ name = "EssentialCooldownViewer", label = "Essential cooldowns", kind = "hud", system = true },
	{ name = "UtilityCooldownViewer", label = "Utility cooldowns", kind = "hud", system = true },
	{ name = "BuffIconCooldownViewer", label = "Tracked buffs", kind = "hud", system = true },
	{ name = "BuffBarCooldownViewer", label = "Tracked buff bars", kind = "hud", system = true },
	{ name = "DamageMeter", label = "Damage meter", kind = "hud", system = true },
	{ name = "RaidWarningFrame", label = "Raid warning", kind = "hud", system = true },
	{ name = "LossOfControlFrame", label = "Loss of control", kind = "hud", system = true },
	{ name = "CharacterFrame", label = "Character", point = "TOPLEFT", kind = "window" },
	{ name = "PlayerSpellsFrame", label = "Spellbook and talents", point = "TOPLEFT", kind = "window" },
	{ name = "QuestFrame", label = "Quest", point = "TOPLEFT", kind = "window" },
	{ name = "GossipFrame", label = "Gossip", point = "TOPLEFT", kind = "window" },
	{ name = "MerchantFrame", label = "Vendor", point = "TOPLEFT", kind = "window" },
	{ name = "MailFrame", label = "Mail", point = "TOPLEFT", kind = "window" },
	{ name = "BankFrame", label = "Bank", point = "TOPLEFT", kind = "window" },
	{ name = "ClassTrainerFrame", label = "Trainer", point = "TOPLEFT", kind = "window" },
	{ name = "AuctionHouseFrame", label = "Auction house", point = "TOPLEFT", kind = "window" },
	{ name = "FriendsFrame", label = "Friends", point = "TOPLEFT", kind = "window" },
	{ name = "CommunitiesFrame", label = "Guild", point = "TOPLEFT", kind = "window" },
	{ name = "DressUpFrame", label = "Dressing room", point = "TOPLEFT", kind = "window" },
	{ name = "TaxiFrame", label = "Flight paths", point = "TOPLEFT", kind = "window" },
	{ name = "TradeFrame", label = "Trade", point = "TOPLEFT", kind = "window" },
	{ name = "ProfessionsFrame", label = "Professions", point = "TOPLEFT", kind = "window" },
	{ name = "AddonList", label = "Addons", point = "TOPLEFT", kind = "window", noBox = true },
	{ name = "LFGParentFrame", label = "Looking For Group", point = "TOPLEFT", kind = "window" },
	{ name = "SocialUIFrame", label = "Social", point = "TOPLEFT", kind = "window" },
	{ name = "ChannelFrame", label = "Channels", point = "TOPLEFT", kind = "window" },
	{ name = "RaidParentFrame", label = "Raid", point = "TOPLEFT", kind = "window" },
	{ name = "OpenMailFrame", label = "Open Mail", point = "TOPLEFT", kind = "window" },
	{ name = "QuestLogPopupDetailFrame", label = "Quest Log", point = "TOPLEFT", kind = "window" },
	{ name = "WorldMapFrame", label = "Map & Quest Log", point = "TOPLEFT", kind = "window", noBox = true, layer = "BorderFrame", fills = "isMaximized" },
	{ name = "ItemTextFrame", label = "Book", point = "TOPLEFT", kind = "window" },
	{ name = "LegacySystemFrame", label = "Legacy", point = "TOPLEFT", kind = "window" },
	{ name = "GuildRegistrarFrame", label = "Guild registrar", point = "TOPLEFT", kind = "window" },
	{ name = "PetitionFrame", label = "Petition", point = "TOPLEFT", kind = "window" },
	{ name = "TabardFrame", label = "Tabard", point = "TOPLEFT", kind = "window" },
	{ name = "GuildBankFrame", label = "Guild bank", point = "TOPLEFT", kind = "window" },
	{ name = "InspectFrame", label = "Inspect", point = "TOPLEFT", kind = "window" },
	{ name = "MacroFrame", label = "Macros", point = "TOPLEFT", kind = "window" },
	{ name = "CollectionsJournal", label = "Collections", point = "TOPLEFT", kind = "window" },
	{ name = "PetStableFrame", label = "Stable", point = "TOPLEFT", kind = "window" },
	{ name = "ItemSocketingFrame", label = "Sockets", point = "TOPLEFT", kind = "window" },
	{ name = "ClickBindingFrame", label = "Click casting", point = "TOPLEFT", kind = "window" },
	{ name = "TimeManagerFrame", label = "Clock", point = "TOPLEFT", kind = "window" },
	{ name = "CooldownViewerSettings", label = "Cooldown manager", point = "TOPLEFT", kind = "window" },
	{ name = "GameMenuFrame", label = "Game menu", point = "TOPLEFT", kind = "window", noBox = true },
	{ name = "SettingsPanel", label = "Options", point = "TOPLEFT", kind = "window", noBox = true },
	{ name = "ContainerFrameCombinedBags", label = "Bags", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame1", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame2", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame3", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame4", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame5", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame6", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
	{ name = "ContainerFrame7", label = "Bag", point = "TOPLEFT", kind = "window", grip = BAG_GRIP },
}
local BY_NAME = {}
for _, info in ipairs(LIST) do
	BY_NAME[info.name] = info
end

-- Frames the picker never takes: placed by the tooltip module, laid out by a container or a manager,
-- or re-anchored by the game on every layout pass. A frame in LIST is taken whatever its name. The map is in LIST, so its
-- title bar and corner grip move and size it; the picker still refuses it.
local REFUSE = {}
for _, name in ipairs({
	"UIParent", "WorldFrame",
	"GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefTooltip",
	"BottomManagedFrameContainer", "RightManagedFrameContainer", "PlayerBottomManagedFrameContainer",
	"GroupLootContainer", "UIWidgetBelowMinimapContainerFrame", "TotemFrame",
	"UIWidgetPowerBarContainerFrame", "PlayerPowerBarAlt",
	"TargetFrameSpellBar", "FocusFrameSpellBar", "TargetFrameToT", "FocusFrameToT",
	"ContainerFrameCombinedBags", "GeneralDockManager",
	"WorldMapFrame", "SettingsPanel", "GameMenuFrame", "HelpFrame", "EditModeManagerFrame", "BarberShopFrame",
	"CompactRaidFrameManager", "EventToastManagerFrame",
}) do
	REFUSE[name] = true
end
local REFUSE_PATTERNS = { "^ContainerFrame%d+$", "^ChatFrame%d+$", "^StaticPopup%d+$", "^Boss%dTargetFrameSpellBar$" }

local EVERY_FRAME = "Every frame can be moved here. A grey box moves with the frame it hangs from. A hidden frame the game has not placed yet has no box."
-- What a box of a bar the game lays out says while its Edit Mode layout cannot hold the spot: the layout passes run when a fight starts and ends.
local BACK_IN_FIGHT = "moved back by the game in combat"

-- State. Per-frame state is kept in tables of the addon's own and never on a Blizzard frame.
local original = setmetatable({}, { __mode = "k" })
local handles, handleTexts, handleLooks = {}, {}, {}
-- Whether the game places a frame, by name, worked out when it is first asked and again after anything that could change it.
local placedBy = {}
local counted, queued, stopped, corrections, refused = {}, {}, {}, {}, {}
local clock = { keep = 0, handles = 0, pick = 0 }
local running, open, openedBy, conflict, dragging
local driver, bar, barMoved, resetPending
local pick = { steps = 0 }
local watched = false
-- Whether Reset all is under way, which frame Edit Mode owns it put back: "system", or "layout" for one the
-- game's layout passes place again, and whether a bar of the stacks was left where it is.
local resettingAll, systemReset, barsLeft = false, false, false
-- The state of the window drag and size, and the functions of the window section further down. grips and corners: the title bar
-- and the corner grip of each window, by the name of the window. art: the two lines of a corner grip. clocks: the time since a
-- corner grip looked at the cursor. levels: the frame levels of an open window and its two frames, for /flatui status. why: why a
-- window has no grips. resizes: how often the game set the size of a window again. heard: whether the game has reported a press
-- and the frame under the cursor. barUsed: whether a press on a title bar has been handled.
-- drag: the move or size under way. waiting: whether a grip waits for the end of combat. toldMove, toldSize: whether the player
-- has been told in this fight that a window cannot be moved or sized. toldHow: whether the player has been told how to move things.
-- last: the last press on a window that started no drag.
local win = { grips = {}, corners = {}, art = {}, clocks = {}, levels = {}, why = {}, resizes = {}, heard = false, barUsed = false }
-- Sizes by hooks. marked: the windows a hook has marked, sized on the next frame. wrote: the windows whose scale the game has written since they
-- were last sized. markers: the two functions hooked on a window, by name. scaleHooked and showHooked: the frames that have each hook. guards: the
-- scale calls of this addon, wrapped so that a hook can tell them from the game's. writing: how many of those are running. sizer: the one hidden
-- frame that sizes the marked windows.
win.marked, win.wrote, win.markers, win.fixQueued, win.writing = {}, {}, {}, {}, 0
win.scaleHooked, win.showHooked, win.guards = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
-- The system frames a module holds at spots of its own (ns.MoverHold). owners: the spots each module gave, by module. by: the spot of each held
-- frame, by name, with the first module in order winning. state: placed, waiting or refused, by name.
local hold = { owners = {}, by = {}, state = {}, order = { "barblock", "blocks" } }
-- The game's action bars, its two status bars and the frames its bottom bar layout hangs from (the micro menu and the bag bar, which the main bar is
-- anchored to: EditModePresetLayoutConstants.lua:5-8 and :46, and the leave vehicle button, EditModeUtil.lua:10-19). A click on an action button runs the game's own code on these frames and reads what the game
-- laid out in them; a call of this addon that placed, scaled or laid one out, or that ran inside the game's pass over them, left the click refused
-- (UseAction, ADDON_ACTION_FORBIDDEN, SecureTemplates.lua:357). While Leave the game's action bars alone is on, nothing here places, holds, puts back,
-- queues a layout spot for or offers a handle for one of them, and the game's bottom bar pass is not watched. Their saved spots stay in the profile and are not used.
hold.off = { MainActionBar = true, MultiBarBottomLeft = true, MultiBarBottomRight = true, MultiBarRight = true, MultiBarLeft = true, MultiBar5 = true,
	MultiBar6 = true, MultiBar7 = true, StanceBar = true, PetActionBar = true, PossessActionBar = true, MultiCastActionBarFrame = true,
	MainStatusTrackingBarContainer = true, SecondaryStatusTrackingBarContainer = true,
	MicroMenuContainer = true, BagsBar = true, MainMenuBarVehicleLeaveButton = true }
-- The game's two status bars are left alone as well while Flat UI draws its own experience bar (XpBar.lua parks them), whatever the setting says.
hold.xp = { MainStatusTrackingBarContainer = true, SecondaryStatusTrackingBarContainer = true }
function hold.Off(name)
	return hold.off[name] == true and (ns.HandsOff() or (hold.xp[name] == true and ns.XpOwn ~= nil and ns.XpOwn()))
end

-- True when the named frame is a game bar that Flat UI leaves alone now.
function ns.MoverHandsOff(name)
	return hold.Off(name)
end

-- Helpers ---------------------------------------------------------------------------------------

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Runs fn on the next frame, or at once when the client has no timer.
local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

-- The game may place a frame differently after a layout, a setting or a hook, so what is known of it is worked out again.
local function ForgetPlaced()
	placedBy = {}
end

-- A key the client cannot report is not down.
local function KeyDown(fn)
	return type(fn) == "function" and fn() and true or false
end

-- The spots of the profile in use.
local function Saved()
	return ns.Spots()
end

local function GameFrame(name)
	local frame = _G[name]
	if type(frame) == "table" and not ns.IsSecret(frame) then
		return frame
	end
	return nil
end

local function Callable(value)
	return not ns.IsSecret(value) and type(value) == "function"
end

-- The engine's own SetPoint, ClearAllPoints and SetScale of a frame Edit Mode owns, which Edit Mode keeps under
-- these names when it replaces the three with Lua. Nothing for any other frame.
local function BaseCalls(frame)
	local ok, setPoint, clear, setScale = pcall(function()
		return frame.SetPointBase, frame.ClearAllPointsBase, frame.SetScaleBase
	end)
	if ok and Callable(setPoint) and Callable(clear) and Callable(setScale) then
		return setPoint, clear, setScale
	end
	return nil
end

-- True when the client says the frame is protected. A frame that will not say is not taken for protected here: it is still not placed in
-- combat (ns.MaybeProtected).
local function IsProtectedFrame(frame)
	local ok, protected = pcall(frame.IsProtected, frame)
	return ok and not ns.IsSecret(protected) and protected == true
end

-- A protected frame is never placed with a call of this addon's: SetPoint, ClearAllPoints, SetScale and their Base forms on it taint its
-- executions, and a protected call the frame makes after that is refused and blamed on this addon (the button of an action bar ends a click at
-- UseAction, SecureTemplates.lua:357). Each call runs inside a SecureHandlerBaseTemplate frame's snippet instead, where the frame handle is
-- the frame and the call is the engine's own. UIParent is the frame the positioner hangs from, so GetParent in the snippet is UIParent. Out of
-- combat only. The approach is EllesmereUI's (EllesmereUIQoL/EllesmereUIQoL_Shifter.lua:174-232).
local positioner
local SNIPPET_CLEAR = [[
	local f = self:GetFrameRef("f")
	if f then f:ClearAllPoints() end
]]
local SNIPPET_SCALE = [[
	local f = self:GetFrameRef("f")
	if f then f:SetScale(self:GetAttribute("s")) end
]]
local SNIPPET_POINT = [[
	local f = self:GetFrameRef("f")
	if not f then return end
	local r = self:GetAttribute("ur") and self:GetFrameRef("r") or self:GetParent()
	f:SetPoint(self:GetAttribute("p"), r, self:GetAttribute("rp"), self:GetAttribute("x"), self:GetAttribute("y"))
]]

local function Positioner()
	if positioner ~= nil then
		return positioner or nil
	end
	if InCombatLockdown() then
		return nil
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	if ok and type(frame) == "table" and not ns.IsSecret(frame) then
		positioner = frame
		ns.Own[frame] = true
	else
		positioner = false
	end
	return positioner or nil
end

-- Runs a snippet on a frame. False when it could not run: in combat, with no positioner, or when the client refused the call.
local function Secure(frame, snippet, attributes, relativeTo)
	if InCombatLockdown() then
		return false
	end
	local handler = Positioner()
	if not handler then
		return false
	end
	return pcall(function()
		handler:SetFrameRef("f", frame)
		local own = relativeTo ~= nil and relativeTo ~= UIParent
		handler:SetAttribute("ur", own or nil)
		if own then
			handler:SetFrameRef("r", relativeTo)
		end
		for name, value in pairs(attributes or {}) do
			handler:SetAttribute(name, value)
		end
		handler:Execute(snippet)
	end)
end

local function SecureClear(frame)
	return Secure(frame, SNIPPET_CLEAR)
end

local function SecureScale(frame, scale)
	return Secure(frame, SNIPPET_SCALE, { s = scale })
end

local function SecurePoint(frame, point, relativeTo, relativePoint, x, y)
	return Secure(frame, SNIPPET_POINT, { p = point, rp = relativePoint, x = x, y = y }, relativeTo)
end
ns.SecurePoint = SecurePoint

-- The calls that place a frame: a protected frame is placed in a secure snippet, a frame Edit Mode owns with the engine's own calls, any other
-- frame with its methods.
-- A scale this addon writes is wrapped, so that the SetScale hook of a window does not take it for a write of the game's.
function win.Guarded(call)
	local guard = win.guards[call]
	if not guard then
		guard = function(...)
			win.writing = win.writing + 1
			local ok, err = pcall(call, ...)
			win.writing = win.writing - 1
			if not ok then
				error(err, 0)
			end
		end
		win.guards[call] = guard
	end
	return guard
end

local function Calls(frame)
	if IsProtectedFrame(frame) then
		return SecurePoint, SecureClear, win.Guarded(SecureScale)
	end
	local setPoint, clear, setScale = BaseCalls(frame)
	if setPoint then
		return setPoint, clear, win.Guarded(setScale)
	end
	return frame.SetPoint, frame.ClearAllPoints, win.Guarded(frame.SetScale)
end

-- True for a frame Edit Mode owns that is left alone now: Edit Mode is open, or the player has turned the game's
-- own frames off.
local function LeftToEditMode(frame)
	return BaseCalls(frame) ~= nil and (ns.EditModeOpen() or not ns.Get("movers.systems"))
end

-- True when the client says the frame is shown, false when it says it is not, nil when it will not say. A bar
-- keeps the engine's IsShown as IsShownBase, because its IsShown is Lua.
local function IsShown(frame)
	local ok, shown = pcall(function()
		local call = frame.IsShownBase
		if not Callable(call) then
			call = frame.IsShown
		end
		return call(frame)
	end)
	if not ok or ns.IsSecret(shown) then
		return nil
	end
	return shown == true
end

-- A frame that is protected, or that will not say, cannot be placed in combat.
function ns.MaybeProtected(frame)
	local ok, protected = pcall(frame.IsProtected, frame)
	return not ok or ns.IsSecret(protected) or protected ~= false
end

local function EditModeActive(manager)
	return manager.editModeActive
end

function ns.EditModeOpen()
	local manager = EditModeManagerFrame
	if manager == nil or ns.Forbidden(manager) then
		return false
	end
	local ok, active = pcall(EditModeActive, manager)
	return ok and not ns.IsSecret(active) and active == true
end

local function ScreenSize()
	local ok, width, height = pcall(UIParent.GetSize, UIParent)
	if ok and Number(width) and Number(height) and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

-- Units of a frame for each unit of UIParent.
local function Ratio(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and okBase and Number(scale) and Number(base) and scale > 0 and base > 0 then
		return scale / base, base
	end
	return nil
end

-- Left, bottom, width and height of a frame in the units of UIParent.
local function Rect(frame)
	local k = Ratio(frame)
	if not k then
		return nil
	end
	local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
	if ok and Number(left) and Number(bottom) and Number(width) and Number(height) then
		return left * k, bottom * k, width * k, height * k
	end
	return nil
end

local function PointAt(point, left, bottom, width, height)
	local f = FRACTION[point]
	return left + width * f[1], bottom + height * f[2]
end

-- The offsets from the same point of UIParent to a point of a rectangle.
local function Offsets(point, left, bottom, width, height)
	local sw, sh = ScreenSize()
	if not sw then
		return nil
	end
	local x, y = PointAt(point, left, bottom, width, height)
	local f = FRACTION[point]
	return x - sw * f[1], y - sh * f[2]
end

-- The rectangle whose point is at the given offsets from the same point of UIParent.
local function RectAt(point, x, y, width, height)
	local sw, sh = ScreenSize()
	if not sw then
		return nil
	end
	local f = FRACTION[point]
	return sw * f[1] + x - width * f[1], sh * f[2] + y - height * f[2], width, height
end

-- The point of the screen third that holds a position, so a spot survives a change of resolution.
local function ThirdPoint(x, y)
	local sw, sh = ScreenSize()
	if not sw then
		return "CENTER"
	end
	local column = x < sw / 3 and "LEFT" or x > sw * 2 / 3 and "RIGHT" or ""
	local row = y < sh / 3 and "BOTTOM" or y > sh * 2 / 3 and "TOP" or ""
	if column == "" and row == "" then
		return "CENTER"
	end
	return row .. column
end

local function Snap(scale)
	return math.max(MIN_SCALE, math.min(MAX_SCALE, math.floor(scale / SCALE_STEP + 0.5) * SCALE_STEP))
end

-- The offsets of a saved spot cut to the screen as it is now, so a frame is never out of reach: KEEP_ON_SCREEN
-- units of a frame of the given size stay on the screen, or the point alone where the size is not known. The
-- saved numbers are not cut: a spot saved under a custom scale is past the edge of the screen under the game's
-- own, until the custom scale is set. A frame the game keeps on the screen (an Edit Mode system frame) is also cut to
-- the screen less its clamp insets, since the game draws it no nearer the edge than that (EditModeSystemTemplates.xml:4,
-- EditModeSystemTemplates.lua:174-186). The frame is the sixth argument and is left out for any other spot.
local function OnScreen(point, x, y, width, height, frame)
	local sw, sh = ScreenSize()
	if not sw then
		return x, y
	end
	local f = FRACTION[point]
	width, height = width or 0, height or 0
	local keepX, keepY = math.min(KEEP_ON_SCREEN, width), math.min(KEEP_ON_SCREEN, height)
	local minX, maxX = keepX - width * (1 - f[1]) - sw * f[1], sw * (1 - f[1]) - keepX + width * f[1]
	local minY, maxY = keepY - height * (1 - f[2]) - sh * f[2], sh * (1 - f[2]) - keepY + height * f[2]
	if type(frame) == "table" and not ns.Forbidden(frame) and width > 0 and height > 0 then
		local k = Ratio(frame)
		local okClamp, clamped = pcall(frame.IsClampedToScreen, frame)
		local ok, left, right, top, bottom = pcall(frame.GetClampRectInsets, frame)
		if k and okClamp and clamped == true and ok and Number(left) and Number(right) and Number(top) and Number(bottom) then
			-- The clamp box is the frame less the insets, which stays inside the screen: left + inset >= 0 and right + inset <= width.
			left, right, top, bottom = left * k, right * k, top * k, bottom * k
			local clampMinX, clampMaxX = -left - sw * f[1] + width * f[1], sw * (1 - f[1]) - right - width * (1 - f[1])
			local clampMinY, clampMaxY = -bottom - sh * f[2] + height * f[2], sh * (1 - f[2]) - top - height * (1 - f[2])
			if math.max(minX, clampMinX) <= math.min(maxX, clampMaxX) then
				minX, maxX = math.max(minX, clampMinX), math.min(maxX, clampMaxX)
			end
			if math.max(minY, clampMinY) <= math.min(maxY, clampMaxY) then
				minY, maxY = math.max(minY, clampMinY), math.min(maxY, clampMaxY)
			end
		end
	end
	return math.max(minX, math.min(maxX, x)), math.max(minY, math.min(maxY, y))
end

-- Width and height of a frame in the units of UIParent, or nothing when the client will not say.
local function Size(frame)
	if frame then
		local _, _, width, height = Rect(frame)
		return width, height
	end
	return nil
end

-- Makes a saved entry valid, or returns nil when it cannot be. The numbers of the spot are kept.
local function Clean(entry)
	if type(entry) ~= "table" or FRACTION[entry.point] == nil or not Number(entry.x) or not Number(entry.y) then
		return nil
	end
	if entry.scale ~= nil then
		entry.scale = Number(entry.scale) and Snap(entry.scale) or nil
	end
	entry.kind = entry.kind == "window" and "window" or "hud"
	if type(entry.label) ~= "string" then
		entry.label = nil
	end
	return entry
end
-- The profiles keep only spots that pass.
ns.CleanSpot = Clean

-- `entry` is the spot of a frame that has none in the profile in use.
local function Describe(name, entry)
	local listed = BY_NAME[name]
	if listed then
		-- A bar picked on the Bar blocks page has the name of its block.
		local own = ns.BlockLabel and ns.BlockLabel(name)
		if own and own ~= listed.label then
			local copy = {}
			for field, value in pairs(listed) do
				copy[field] = value
			end
			copy.label = own
			return copy
		end
		return listed
	end
	local saved = Saved()
	entry = entry or saved and saved[name]
	if type(entry) == "table" then
		return { name = name, label = entry.label or name, kind = entry.kind }
	end
	return nil
end

local function IsWindow(name)
	return type(UIPanelWindows) == "table" and UIPanelWindows[name] ~= nil
end

-- Where the named point of the handle of an own frame is, in the units of UIParent from the bottom left.
-- Nothing for a frame that has no spot and starts nowhere in particular.
function ns.MoverSpot(name, point)
	local info, f = BY_NAME[name], FRACTION[point]
	if not (info and info.own and f) then
		return nil
	end
	local saved = Saved()
	local entry = saved and Clean(saved[name])
	local left, bottom, width, height
	if entry then
		local x, y = OnScreen(entry.point, entry.x, entry.y, info.width, info.height)
		left, bottom, width, height = RectAt(entry.point, x, y, info.width, info.height)
	elseif info.x then
		left, bottom, width, height = RectAt(info.point, info.x, info.y, info.width, info.height)
	end
	if not left then
		return nil
	end
	return PointAt(point, left, bottom, width, height)
end

-- True when the named own frame has a spot saved that the list accepts.
function ns.MoverSaved(name)
	local saved = Saved()
	return BY_NAME[name] ~= nil and saved ~= nil and Clean(saved[name]) ~= nil
end

-- The point in the middle column on the row of `point`, when the spot of the named own frame has been centred: it is saved by a point in the
-- middle column with no offset across. A frame that hangs from that point is on the middle of the screen whatever its width is, which a
-- frame hung from a corner of the box is not. Nothing for a spot that is not centred.
function ns.MoverCentred(name, point)
	local info, f = BY_NAME[name], FRACTION[point]
	local saved = Saved()
	local entry = saved and Clean(saved[name])
	if info and info.own and f and entry and entry.x == 0 and FRACTION[entry.point][1] == 0.5 then
		return centre.rows[f[2]]
	end
	return nil
end

-- Placing a frame ------------------------------------------------------------------------------

local Passes

-- True when the frame has the one point Edit Mode gives a frame at a layout before it has placed it: TOPLEFT of
-- UIParent at 0, 0 (EditModeManager.lua, initSystemAnchor).
local function AtPlaceholder(frame)
	local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
	local okCount, count = pcall(frame.GetNumPoints, frame)
	return ok and okCount and Number(count) and count == 1 and not ns.IsSecret(point) and not ns.IsSecret(relativeTo) and not ns.IsSecret(relativePoint)
		and Number(x) and Number(y) and point == "TOPLEFT" and relativePoint == "TOPLEFT" and relativeTo == UIParent and x == 0 and y == 0
end

-- The points and scale the game gave a frame, taken before the first move of the session. No points are kept
-- for a bar of the stacks, which the game places again, for a frame Edit Mode has not placed yet, nor for a hidden
-- frame the game's layout passes place: where such a frame is now is not where the game will put it.
local function Capture(frame, info)
	local own = original[frame]
	if own then
		return own
	end
	own = { points = {} }
	original[frame] = own
	local ok, scale = pcall(frame.GetScale, frame)
	if ok and Number(scale) and scale > 0 then
		own.scale = scale
	end
	if info and info.stack or (BaseCalls(frame) and (AtPlaceholder(frame) or (Passes(info, frame) and IsShown(frame) ~= true))) then
		return own
	end
	local okCount, count = pcall(frame.GetNumPoints, frame)
	if not okCount or not Number(count) then
		return own
	end
	for index = 1, count do
		local okPoint, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
		if okPoint and type(point) == "string" and not ns.IsSecret(point) and not ns.IsSecret(relativeTo) and not ns.IsSecret(relativePoint)
			and Number(x) and Number(y) then
			own.points[#own.points + 1] = { point, relativeTo or UIParent, relativePoint or point, x, y }
		else
			own.points = {}
			break
		end
	end
	-- The panel manager anchors a small left panel with one TOPLEFT point on UIParent (UpdateUIPanelPositions). Any other point of a
	-- window that can fill the screen is the point of full size or of the way back from it.
	if info and info.fills then
		local first = own.points[1]
		if #own.points ~= 1 or first[1] ~= "TOPLEFT" or first[2] ~= UIParent or first[3] ~= "TOPLEFT" then
			own.points = {}
		end
	end
	return own
end

-- True when the frame has one point, the saved one on UIParent, within half a unit of its offsets.
local function InPlace(frame, entry)
	local okCount, count = pcall(frame.GetNumPoints, frame)
	if not okCount or not Number(count) or count ~= 1 then
		return false
	end
	local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
	if not ok or ns.IsSecret(point) or ns.IsSecret(relativeTo) or ns.IsSecret(relativePoint) or not Number(x) or not Number(y) then
		return false
	end
	local k = Ratio(frame)
	if not k or point ~= entry.point or relativePoint ~= entry.point or relativeTo ~= UIParent then
		return false
	end
	local wantedX, wantedY = entry.x, entry.y
	-- A held bar is where its module put it, not cut to the screen.
	if not entry.held then
		local width, height = Size(frame)
		wantedX, wantedY = OnScreen(entry.point, entry.x, entry.y, width, height, frame)
	end
	return math.abs(x - wantedX / k) <= TOLERANCE and math.abs(y - wantedY / k) <= TOLERANCE
end

local function Move(name, frame, entry)
	local own = Capture(frame, BY_NAME[name])
	win.Rebase(name, frame, own)
	local setPoint, clear, setScale = Calls(frame)
	local info = BY_NAME[name]
	-- A frame with a scale of its own keeps the one the game or its setting gave it, whatever scale an earlier build saved.
	if (entry.scale ~= nil or own.scaled) and not (info and info.ownScale) then
		local wanted = (own.scale or 1) * (entry.scale or 1)
		local ok, current = pcall(frame.GetScale, frame)
		if not (ok and Number(current)) or math.abs(current - wanted) > 0.0005 then
			setScale(frame, wanted)
			if info and info.scaled and Callable(ns[info.scaled]) then
				Soon(ns[info.scaled])
			end
		end
		own.scaled = entry.scale ~= nil
		own.applied = own.scaled and wanted or nil
	end
	local k = Ratio(frame)
	if not k then
		return
	end
	if not InPlace(frame, entry) then
		local x, y = entry.x, entry.y
		if not entry.held then
			local width, height = Size(frame)
			x, y = OnScreen(entry.point, entry.x, entry.y, width, height, frame)
		end
		clear(frame)
		setPoint(frame, entry.point, UIParent, entry.point, x / k, y / k)
	end
	if not counted[name] then
		counted[name] = true
		ns.Count(KEY)
	end
end

-- False when the points the game had were not readable, so the frame stays where it was put.
local function Restore(frame, own)
	local setPoint, clear = Calls(frame)
	-- A window with no point of the game's to go back to keeps its top left corner where it is, unless the game places it.
	if own.scaled and own.scale then
		win.GiveBack(frame, own.scale, #own.points == 0 and not win.Fills(frame))
	end
	original[frame] = nil
	-- A window that fills the screen keeps the point the game gave it there.
	if win.Fills(frame) then
		return false
	end
	if #own.points == 0 then
		return false
	end
	clear(frame)
	for _, p in ipairs(own.points) do
		setPoint(frame, p[1], p[2], p[3], p[4], p[5])
	end
	return true
end

local ApplyEntry, Unmovable, KindOf

-- A protected frame is not placed in combat. One entry waits for each frame.
local function Queue(name)
	if queued[name] then
		return
	end
	queued[name] = true
	ns.OutOfCombat(function()
		queued[name] = nil
		if running and ns.Enabled(KEY) then
			ns.Each(KEY, ApplyEntry, name)
		end
	end)
end

-- The spot of a frame as the Edit Mode layout takes it: the point and the offsets Move passes.
local function SpotOf(frame, entry)
	local k = Ratio(frame)
	if not (k and type(entry) == "table") then
		return nil
	end
	local x, y = entry.x, entry.y
	if not entry.held then
		local width, height = Size(frame)
		x, y = OnScreen(entry.point, entry.x, entry.y, width, height, frame)
	end
	return { point = entry.point, x = x / k, y = y / k }
end

-- Saves the spot of a frame the game lays out in the Edit Mode layout in use, on the next frame.
local function LayoutSpot(name, frame, entry)
	local spot = SpotOf(frame, entry)
	if spot then
		ns.LayoutSpots.Queue(name, frame, spot)
	end
end

function ApplyEntry(name)
	local saved = Saved()
	local held = hold.by[name]
	local entry = held or (saved and saved[name])
	local info = BY_NAME[name]
	if type(entry) ~= "table" or (info and info.own) or hold.Off(name) then
		return
	end
	-- A window being dragged is placed by the drag.
	if win.drag and win.drag.name == name then
		return
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) then
		return
	end
	if Unmovable(name, frame) then
		refused[name] = true
		if held then
			hold.state[name] = "refused"
		end
		return
	end
	refused[name] = nil
	if LeftToEditMode(frame) then
		return
	end
	-- A frame the game lays out again is neither placed nor written while a fight is on: each edge of one runs a layout pass.
	local layout = KindOf(name, frame) == "layout"
	if (layout and InCombatLockdown()) or (not layout and (held and hold.Blocked(frame) or (not held and InCombatLockdown() and ns.MaybeProtected(frame)))) then
		if held then
			hold.state[name] = "waiting"
		end
		Queue(name)
		return
	end
	-- A window that fills the screen is the game's: it gets the game's scale and is not placed.
	if win.Fills(frame) then
		win.Unscale(frame)
		return
	end
	local placed = win.Entry(name, entry)
	Move(name, frame, placed)
	if layout then
		LayoutSpot(name, frame, placed)
	end
	if held then
		hold.state[name] = "placed"
	end
end

local function ApplyAll()
	local saved = Saved()
	if not (running and saved) then
		return
	end
	ForgetPlaced()
	for name in pairs(saved) do
		ns.Each(KEY, ApplyEntry, name)
	end
	for name in pairs(hold.by) do
		ns.Each(KEY, ApplyEntry, name)
	end
end

-- Puts a frame the addon placed back where the game had it. Nil when the addon never moved it.
-- The second answer is true when the Edit Mode layout puts the frame back, because the spot was written into it.
local function RestoreFrame(name)
	local frame = GameFrame(name)
	local info = BY_NAME[name]
	if hold.Off(name) or not (frame and not ns.Forbidden(frame)) then
		return nil
	end
	local layout = KindOf(name, frame) == "layout"
	local released = false
	if layout then
		local saved = Saved()
		released = ns.LayoutSpots.Release(name, frame, SpotOf(frame, hold.by[name] or (saved and saved[name])))
	end
	local own = original[frame]
	if not own then
		return released and false or nil, released
	end
	if InCombatLockdown() and (layout or ns.MaybeProtected(frame)) then
		ns.OutOfCombat(function()
			if original[frame] == own then
				pcall(Restore, frame, own)
				if info and info.scaled and Callable(ns[info.scaled]) then
					Soon(ns[info.scaled])
				end
			end
		end)
		return true, released
	end
	local ok, restored = pcall(Restore, frame, own)
	if info and info.scaled and Callable(ns[info.scaled]) then
		Soon(ns[info.scaled])
	end
	return ok and restored, released
end

-- A bar of the stacks keeps no points to go back to, so it stays where it was put until the game places it again.
local BARS_STAY = "stay where they are until the game places them again at its next layout or after /reload."

local function RestoreAll()
	local left = false
	for name in pairs(hold.Names()) do
		local restored, released = RestoreFrame(name)
		if restored ~= nil and not released and BY_NAME[name] and BY_NAME[name].stack then
			left = true
		end
	end
	if left then
		print("Bars " .. BARS_STAY)
	end
end

-- Takes a frame off the count of moved frames.
local function Uncount(name)
	if counted[name] then
		counted[name] = nil
		ns.Count(KEY, -1)
	end
end

-- Puts back the frames Edit Mode owns, for when the player turns the game's own frames off. Their saved spots stay.
local function ReleaseSystems()
	local left = false
	for name in pairs(hold.Names()) do
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and BaseCalls(frame) then
			local restored, released = RestoreFrame(name)
			if restored ~= nil and not released and BY_NAME[name] and BY_NAME[name].stack then
				left = true
			end
			Uncount(name)
		end
	end
	if left then
		print("Bars " .. BARS_STAY)
	end
end

-- The check -----------------------------------------------------------------------------------

local function Correct(name, hooked)
	if win.drag and win.drag.name == name then
		return
	end
	-- A return the game's own call announced is not counted: it is the game asking for the frame again, not a fight over it.
	if not hooked then
		local now = type(GetTime) == "function" and GetTime() or 0
		local record = corrections[name]
		if not record or now - record.since > CORRECTION_WINDOW then
			record = { since = now, count = 0 }
			corrections[name] = record
		end
		record.count = record.count + 1
		if record.count > MAX_CORRECTIONS and not hold.by[name] then
			stopped[name] = true
			return
		end
	end
	-- A size the game wrote again is counted for /flatui status.
	local saved = Saved()
	if win.Wrong(name, saved and saved[name]) then
		win.resizes[name] = (win.resizes[name] or 0) + 1
	end
	ns.Each(KEY, ApplyEntry, name)
end

-- True when a frame the game lays out has another scale than the one saved for it: the game sets some bars to scale 1 in its layout passes
-- (EditModeManager.lua:619).
function hold.Scaled(name, frame, entry)
	local own, info = original[frame], BY_NAME[name]
	if entry.scale == nil or not own or not own.scale or (info and info.ownScale) or KindOf(name, frame) ~= "layout" then
		return false
	end
	local ok, current = pcall(frame.GetScale, frame)
	return ok and Number(current) and math.abs(current - own.scale * entry.scale) > 0.0005
end

-- A frame that is shown and not where it was put is placed again. hooked: the game's call that moves it has just been seen.
function hold.Check(name, entry, hooked)
	local info = BY_NAME[name]
	if not stopped[name] and not (info and info.own) and not hold.Off(name) and type(entry) == "table" then
		local frame = GameFrame(name)
		-- The game places a window that fills the screen.
		if frame and not ns.Forbidden(frame) and win.Fills(frame) then
			frame = nil
		end
		if frame and not ns.Forbidden(frame) and not LeftToEditMode(frame) and IsShown(frame) ~= false and (not InPlace(frame, entry) or hold.Scaled(name, frame, entry))
			and not Unmovable(name, frame) then
			if InCombatLockdown() and KindOf(name, frame) == "layout" then
				-- Nothing is placed in a fight: a held frame says that it waits.
				if entry.held then
					hold.state[name] = "waiting"
				end
			elseif hold.passing and info and info.stack then
				-- The game's bottom bar pass has just run: hold.PutBack places the bar on the next frame, and that return is not counted.
				return
			elseif not (entry.held and hold.Blocked(frame) or (not entry.held and InCombatLockdown() and ns.MaybeProtected(frame))) then
				Correct(name, hooked)
			end
		end
	end
end

-- The queue eye (QueueStatusButton) is put back by what moves it, not by the half-second check. The game places it in UpdateDefaultAnchor
-- (Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua:13-35), which Edit Mode calls when it lays the eye out and when the micro
-- menu changes (EditModeSystemTemplates.lua:2453, 2468, 2508, 3798) and the eye calls itself when the minimap scale changes, through a callback
-- that holds the function it had at load (QueueStatusFrame.lua:11-12), so a hook on the method does not see that path: the minimap's own
-- SetEditModeScale, which triggers it (Minimap.lua:374-382), is hooked too. A hook can run inside the game's pass over a layout, so it only
-- shows a hidden frame, and that frame puts the eye back in its next OnUpdate, which is still the same drawn frame.
hold.eye = { name = "QueueStatusButton", hooked = false }

-- True for a frame that a hook puts back, which the half-second check leaves alone.
function hold.Hooked(name)
	return hold.eye.hooked == true and name == hold.eye.name
end

function hold.EyeMark()
	local driver = hold.eye.driver
	if driver and running and ns.Enabled(KEY) then
		driver:Show()
	end
end

local function EyeStep(driver)
	driver:Hide()
	local saved = Saved()
	local entry = hold.by[hold.eye.name] or (saved and saved[hold.eye.name])
	if running and ns.Enabled(KEY) and ns.Get("movers.keep") and type(entry) == "table" then
		ns.Try(KEY, hold.Check, hold.eye.name, entry, true)
	end
end

-- Hooks the two calls and the eye's OnShow. The game moves the eye while no queue is up and it is hidden (leaving a vehicle bar resets the micro
-- menu, which calls UpdateDefaultAnchor: MainActionBar.lua:14-16, MicroMenuContainer.lua:234-243, EditModeSystemTemplates.lua:394, 2466-2468), and
-- a hidden frame is not placed, so showing it puts it back (QueueStatusFrame.lua:503-513 shows and hides it). Nothing is hooked, and the half-second
-- check keeps the eye, when the game does not have all three.
function hold.EyeHooks()
	local eye, cluster = GameFrame(hold.eye.name), GameFrame("MinimapCluster")
	if not (eye and cluster and Callable(eye.UpdateDefaultAnchor) and Callable(cluster.SetEditModeScale) and Callable(eye.HookScript) and Callable(hooksecurefunc)) then
		return
	end
	if not hold.eye.driver then
		hold.eye.driver = CreateFrame("Frame")
		ns.Own[hold.eye.driver] = true
		hold.eye.driver:Hide()
		hold.eye.driver:SetScript("OnUpdate", EyeStep)
	end
	hooksecurefunc(eye, "UpdateDefaultAnchor", hold.EyeMark)
	hooksecurefunc(cluster, "SetEditModeScale", hold.EyeMark)
	eye:HookScript("OnShow", hold.EyeMark)
	hold.eye.hooked = true
end

-- Every saved or held frame that is shown and not where it was put is placed again.
local function Check()
	local saved = Saved()
	if not saved then
		return
	end
	for name, entry in pairs(saved) do
		if not hold.by[name] and not hold.Hooked(name) then
			hold.Check(name, entry)
		end
	end
	for name, entry in pairs(hold.by) do
		if not hold.Hooked(name) then
			hold.Check(name, entry)
		end
	end
	win.CheckSizes()
end

-- Edit Mode's bottom bar pass puts every shown bar of the stack that is still flagged as in its default position back on its spot in the stack
-- (EditModeManager.lua:692-706), and a mover drop never clears that flag (EditModeSystemTemplates.lua:882-883). The pass runs at each edge of a fight
-- (ActionBar.lua:266-267, :285-287, :374), at each show, switch or fade of a status bar (StatusTrackingManager.lua:226-231), and when a layout is
-- applied. Nothing is hooked: the game announces the status bar passes through EventRegistry (StatusTrackingManager.lua:230,
-- EditModeManager.lua:64), and the fight ending is an event. The bar is placed on the next frame, out of combat, and these returns are not counted.
function hold.PutBack()
	hold.passing = false
	if not (running and ns.Enabled(KEY)) or InCombatLockdown() then
		return
	end
	local saved = Saved() or {}
	for name, info in pairs(BY_NAME) do
		local entry = hold.by[name] or saved[name]
		if info.stack and type(entry) == "table" and not stopped[name] and not info.own and not hold.Off(name) then
			local frame = GameFrame(name)
			if frame and not ns.Forbidden(frame) and not LeftToEditMode(frame) and IsShown(frame) ~= false and not win.Fills(frame)
				and not Unmovable(name, frame) and (not InPlace(frame, entry) or hold.Scaled(name, frame, entry)) then
				ns.Each(KEY, ApplyEntry, name)
			end
		end
	end
end

-- The game has run, or may have run, its bottom bar pass.
function hold.Pass()
	if not (running and ns.Enabled(KEY)) then
		return
	end
	hold.passing = true
	if not hold.laterOn then
		hold.laterOn = true
		Soon(function()
			hold.laterOn = false
			ns.Try(KEY, hold.PutBack)
		end)
	end
end

-- Windows are placed after the panel manager has placed them.
local windowsPending = false
local function PlaceWindows()
	local saved = Saved()
	if not (running and saved and ns.Enabled(KEY)) then
		return
	end
	for name, entry in pairs(saved) do
		if type(entry) == "table" and (entry.kind == "window" or (BY_NAME[name] and BY_NAME[name].panel)) then
			local frame = GameFrame(name)
			if frame and not ns.Forbidden(frame) and IsShown(frame) ~= false then
				ns.Each(KEY, ApplyEntry, name)
			end
		end
	end
	win.SizeOpen()
end

local function PlaceWindowsLater()
	if windowsPending then
		return
	end
	windowsPending = true
	Soon(function()
		windowsPending = false
		ns.Try(KEY, PlaceWindows)
	end)
end

local allPending = false
local function ApplyAllLater()
	if allPending then
		return
	end
	allPending = true
	Soon(function()
		allPending = false
		if running and ns.Enabled(KEY) then
			ns.Try(KEY, ApplyAll)
		end
	end)
end

-- Handles and the bar ----------------------------------------------------------------------------

local function Label(parent, font, width)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	if width then
		text:SetWidth(width)
	end
	text:SetJustifyH("LEFT")
	return text
end

local function MakeButton(parent, text, width, onClick)
	local button = CreateFrame("Frame", nil, parent)
	ns.Own[button] = true
	button:SetSize(width, 22)
	button:EnableMouse(true)
	local outline = ns.Outline(button, button, true)
	ns.KeepOutline(outline)
	ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	label:SetText(text)
	button:SetScript("OnEnter", function()
		ns.SetOutlineFill(outline, 0.3, 0.3, 0.3, 1)
	end)
	button:SetScript("OnLeave", function()
		ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	end)
	button:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			onClick(label)
		end
	end)
	return button
end

-- The box the icons of an own frame's row cover, and how far the middle of the frame they hang from is
-- from the middle of the box, in the units of UIParent. Nothing while the row has no icon.
local function RowBox(info)
	local call = ns[info.row]
	if type(call) ~= "function" then
		return nil
	end
	local frames, anchor = call()
	local left, bottom, right, top
	for _, frame in ipairs(frames) do
		local l, b, w, h = Rect(frame)
		if not l then
			return nil
		end
		left, bottom = math.min(left or l, l), math.min(bottom or b, b)
		right, top = math.max(right or l + w, l + w), math.max(top or b + h, b + h)
	end
	local al, ab, aw, ah
	if anchor then
		al, ab, aw, ah = Rect(anchor)
	end
	if not (left and al) then
		return nil
	end
	return left, bottom, right - left, top - bottom, al + aw / 2 - (left + right) / 2, ab + ah / 2 - (bottom + top) / 2
end

-- True for a frame Edit Mode owns that is not shown and has no saved spot, and is at the corner Edit Mode starts
-- every frame at or is a bar the game's stacks place again: where it is now is not where it will be, so it gets no
-- handle and no spot.
local function Offstage(name, info, frame)
	if not info.system or info.keptHidden then
		return false
	end
	local saved = Saved()
	return IsShown(frame) ~= true and not (saved and type(saved[name]) == "table") and (info.stack == true or AtPlaceholder(frame))
end

-- Where a handle goes: over the game frame, or at the saved spot when the frame has no size to measure.
local function HandleRect(name, info)
	-- A held bar has no box: its module places it. A game bar Flat UI leaves alone has none either.
	if hold.by[name] or hold.Off(name) then
		return nil
	end
	local saved = Saved()
	local entry = saved and Clean(saved[name])
	if info.noBox then
		return nil
	elseif info.row then
		return RowBox(info)
	elseif info.own then
		local gate = info.gate and ns[info.gate]
		if info.gate and not (type(gate) == "function" and gate()) then
			return nil
		end
		local point, x, y = info.point, info.x, info.y
		if entry then
			point, x, y = entry.point, OnScreen(entry.point, entry.x, entry.y, info.width, info.height)
		end
		return RectAt(point, x, y, info.width, info.height)
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) then
		return nil
	end
	if info.kind == "window" and IsShown(frame) ~= true then
		return nil
	end
	-- Edit Mode has boxes of its own while it is open, and a module that places the frame itself needs none.
	if info.system and (not ns.Get("movers.systems") or ns.EditModeOpen() or (info.hideWith and ns.Enabled(info.hideWith))) then
		return nil
	end
	if Offstage(name, info, frame) then
		return nil
	end
	local left, bottom, width, height = Rect(frame)
	if left and width >= MIN_SIZE and height >= MIN_SIZE then
		return left, bottom, width, height
	end
	if entry then
		local x, y = OnScreen(entry.point, entry.x, entry.y, NOMINAL_WIDTH, NOMINAL_HEIGHT)
		return RectAt(entry.point, x, y, NOMINAL_WIDTH, NOMINAL_HEIGHT)
	end
	local point = info.point or "CENTER"
	if left then
		local x, y = PointAt(point, left, bottom, width, height)
		local f = FRACTION[point]
		return x - NOMINAL_WIDTH * f[1], y - NOMINAL_HEIGHT * f[2], NOMINAL_WIDTH, NOMINAL_HEIGHT
	end
	-- A game frame that has no place yet would pile up its handle at the middle of the screen.
	if info.system then
		return nil
	end
	return RectAt(point, 0, 0, NOMINAL_WIDTH, NOMINAL_HEIGHT)
end

-- True for a system frame the game places itself, so a handle could not move it.
local function PlacedByGame(name, info)
	if not info.system then
		return false
	end
	local placed = placedBy[name]
	if placed == nil then
		local frame = GameFrame(name)
		placed = frame ~= nil and not ns.Forbidden(frame) and Unmovable(name, frame)
		placedBy[name] = placed
	end
	return placed
end

local ShowHandle, ResetFrame, Open, Close, UpdateDriver

-- Held frames -----------------------------------------------------------------------------------

-- Every frame with a saved or a held spot, by name.
function hold.Names()
	local names = {}
	for name in pairs(Saved() or {}) do
		names[name] = true
	end
	for name in pairs(hold.by) do
		names[name] = true
	end
	return names
end

-- True when a held frame cannot be placed now: in a fight a protected frame waits. The client's answer about protected functions is not
-- asked: a bar is never placed in a fight, whatever it says.
function hold.Blocked(frame)
	return InCombatLockdown() and ns.MaybeProtected(frame)
end

-- The spots of a module that Movers can hold: system frames of the list, at a BOTTOMLEFT spot with numbers.
function hold.Valid(spots)
	local clean = {}
	for name, spot in pairs(type(spots) == "table" and spots or {}) do
		local info = BY_NAME[name]
		if info and info.system and not hold.Off(name) and type(spot) == "table" and spot.point == "BOTTOMLEFT" and Number(spot.x) and Number(spot.y) then
			clean[name] = { point = "BOTTOMLEFT", x = spot.x, y = spot.y, kind = "hud", held = true }
		end
	end
	return clean
end

-- A module gives the spots of the system frames it holds, by frame name, or nil to let them go. One frame has one owner: the first of
-- hold.order that holds it. A frame whose spot is new or changed is placed on the next frame; one let go goes back to its saved spot, or to
-- the game.
function ns.MoverHold(owner, spots)
	local known = false
	for _, name in ipairs(hold.order) do
		known = known or name == owner
	end
	if not known then
		return
	end
	local before = hold.by
	hold.owners[owner] = spots ~= nil and hold.Valid(spots) or nil
	local by = {}
	for _, name in ipairs(hold.order) do
		for frame, entry in pairs(hold.owners[name] or {}) do
			by[frame] = by[frame] or entry
		end
	end
	hold.by = by
	local saved, left = Saved(), false
	for name, entry in pairs(by) do
		local was = before[name]
		if not (was and was.x == entry.x and was.y == entry.y) then
			Soon(function()
				if running and ns.Enabled(KEY) and hold.by[name] then
					ns.Each(KEY, ApplyEntry, name)
				end
			end)
		end
	end
	for name in pairs(before) do
		if not by[name] then
			hold.state[name] = nil
			if saved and type(saved[name]) == "table" then
				ns.Each(KEY, ApplyEntry, name)
			else
				local restored, released = RestoreFrame(name)
				if restored ~= nil and not released and BY_NAME[name].stack then
					left = true
				end
				Uncount(name)
			end
		end
	end
	if left then
		print("Bars " .. BARS_STAY)
	end
	UpdateDriver()
end

-- Whether a frame is held, how its placing stands (placed, waiting for the end of a fight, refused), and whether Edit Mode has it in its
-- default position (nil when the client will not say).
function ns.MoverHeld(name)
	local frame = GameFrame(name)
	local default
	if frame and not ns.Forbidden(frame) then
		local ok, flag = pcall(function()
			return frame.systemInfo.isInDefaultPosition
		end)
		if ok and not ns.IsSecret(flag) and type(flag) == "boolean" then
			default = flag
		end
	end
	return { held = hold.by[name] ~= nil, state = hold.state[name], default = default }
end

-- True when the client says the frame is shown, false when it says it is not, nil when it will not say.
function ns.MoverShown(frame)
	return IsShown(frame)
end

-- The name a frame of the list has on the pages and in /flatui status, nil for a frame not in the list.
function ns.MoverLabel(name)
	local info = BY_NAME[name]
	return info and info.label or nil
end

-- The left, bottom, width and height of a frame in the units of UIParent.
function ns.MoverRect(frame)
	return Rect(frame)
end

-- Whether Movers are on, whether they move the game's own frames and whether they keep moved frames in place: a held frame needs all three.
function ns.MoverHoldGates()
	return ns.Enabled(KEY) and running == true, ns.Get("movers.systems") == true, ns.Get("movers.keep") == true
end

-- An own frame places itself from its spot, so it is told when the spot is set or put back.
local function Changed(info)
	local call = info.own and info.changed and ns[info.changed]
	if type(call) == "function" then
		call()
	end
	ns.MoversMode.Changed(info.name)
end

-- Saves the spot a handle was dropped on, and moves the game frame there. A centred frame is on the middle of the screen whatever `left`
-- says: it is saved by the point in the middle column on the row of its point, with no offset across, so it stays there at any UI scale.
local function Commit(name, info, left, bottom, width, height, centred)
	local saved = Saved()
	if not saved then
		return
	end
	local frame = GameFrame(name)
	if frame and Offstage(name, info, frame) then
		return
	end
	local previous = type(saved[name]) == "table" and saved[name] or nil
	local point = info.point or ThirdPoint(left + width / 2, bottom + height / 2)
	if centred then
		point = centre.rows[FRACTION[point][2]]
	end
	local x, y = Offsets(point, left, bottom, width, height)
	if not x then
		return
	end
	if centred then
		x = 0
	end
	if info.row then
		-- The spot of a row is where it hangs from, which is not the middle of its box.
		local _, _, _, _, shiftX, shiftY = RowBox(info)
		if not shiftX then
			return
		end
		x, y = x + shiftX, y + shiftY
	else
		-- The clamp insets are those of the game frame's own box, not of the handle's.
		local frameWidth, frameHeight = Size(frame)
		x, y = OnScreen(point, x, y, frameWidth or width, frameHeight or height, frame)
	end
	saved[name] = Clean({ point = point, x = x, y = y, scale = previous and previous.scale, kind = info.kind or "hud",
		label = not BY_NAME[name] and info.label or nil })
	ns.Each(KEY, ApplyEntry, name)
	Changed(info)
	return true
end

-- The saved entry of a frame, made from where its handle is when it has none.
local function Ensure(name, info)
	local saved = Saved()
	if not saved then
		return nil
	end
	if type(saved[name]) ~= "table" and handles[name] then
		local left, bottom, width, height = Rect(handles[name])
		if left then
			-- The step for Undo is the change that follows, so one action is one step.
			ns.MoversMode.Mute(true)
			Commit(name, info, left, bottom, width, height)
			ns.MoversMode.Mute(false)
		end
	end
	return type(saved[name]) == "table" and saved[name] or nil
end

local function Dropped(name)
	local info, handle = Describe(name), handles[name]
	if info and handle then
		local left, bottom, width, height = Rect(handle)
		if left then
			-- A handle the engine moved is snapped here, and one that followed the cursor has been.
			local middle = centre.dropMiddle
			if middle == nil then
				middle = centre.Snaps(left, width) ~= nil
				left = centre.Snaps(left, width) or left
				left, bottom = ns.MoversSnap.Snap(name, left, bottom, width, height, middle)
			end
			centre.dropMiddle = nil
			Commit(name, info, left, bottom, width, height, middle)
		end
	end
	dragging = nil
	ns.MoversSnap.Hide()
	centre.LineLook()
	ShowHandle(name)
end

-- The frames whose scale is a row of the options, and the path of the row. The row follows Ctrl and scroll and the reset of a handle.
local SCALE_ROWS = { PlayerFrame = "unitframes.playerScale", TargetFrame = "unitframes.targetScale", FocusFrame = "unitframes.focusScale",
	PartyFrame = "unitframes.partyScale", BossTargetFrameContainer = "unitframes.bossScale", CompactRaidFrameContainer = "unitframes.raidScale" }

local function ScaleRowMoved(name)
	local path = SCALE_ROWS[name]
	if path and ns.NotifyOption then
		ns.NotifyOption(path)
	end
end

local function Wheel(name, delta)
	local info = Describe(name)
	local scaling = KeyDown(IsControlKeyDown)
	-- A frame that takes no scale gets no spot saved for Ctrl and scroll.
	if not info or (scaling and info.noScale) then
		return
	end
	-- Under Every window together a window has no size of its own, so Ctrl and scroll changes the size of every window.
	if scaling and info.kind == "window" and win.Shared() then
		ns.Set("movers.windowSize", ns.Get("movers.windowSize") + (delta > 0 and WIN.step or -WIN.step))
		ns.ResizeAll()
		ShowHandle(name)
		return
	end
	local entry = Ensure(name, info)
	if not entry then
		return
	end
	local was = entry.scale
	if scaling then
		entry.scale = Snap((entry.scale or 1) + (delta > 0 and SCALE_STEP or -SCALE_STEP))
		-- A window is sized from 60% to 150%, as the corner grip sizes it.
		if info.kind == "window" then
			entry.scale = math.max(WIN.min / 100, math.min(WIN.max / 100, entry.scale))
		end
	else
		-- A nudge starts from the frame as it is on the screen now, and moves it along one axis.
		local step = ns.Pixels(UIParent, 1)
		local width, height = Size(handles[name])
		local x, y = OnScreen(entry.point, entry.x, entry.y, width, height)
		if KeyDown(IsShiftKeyDown) then
			entry.x = OnScreen(entry.point, x + (delta > 0 and step or -step), y, width, height)
		else
			entry.y = select(2, OnScreen(entry.point, x, y + (delta > 0 and step or -step), width, height))
		end
	end
	Clean(entry)
	ns.Each(KEY, ApplyEntry, name)
	Changed(info)
	if entry.scale ~= was then
		-- Lengths worked out in the units of a frame, such as one-pixel borders, follow its scale.
		ns.ResizeAll()
		if scaling then
			ScaleRowMoved(name)
		end
	end
	ShowHandle(name)
end

-- The scale of a frame as a percent: the saved scale of its spot, or 100.
function ns.MoverScale(def)
	local saved = Saved()
	local entry = saved and type(def) == "table" and saved[def.frame]
	local info = entry and Describe(def.frame)
	if not ns.Get("movers.enabled") or (info and info.system and not ns.Get("movers.systems")) then
		-- Saved spots are not applied while the movers are off.
		return 100
	end
	if type(entry) == "table" and Number(entry.scale) then
		return math.floor(entry.scale * 100 + 0.5)
	end
	return 100
end

-- Sets the scale of a frame as Ctrl and scroll does: the spot is saved with it, and the frame takes both.
function ns.SetMoverScale(def, percent)
	local name = type(def) == "table" and def.frame
	local info = name and Describe(name)
	if not info or info.noScale or not Number(percent) then
		return
	end
	-- A dragged slider sends every step: one line per drag, then the row goes back to what is applied.
	local function Refuse(text)
		local now = GetTime and GetTime() or 0
		if not ns.moverTold or now - ns.moverTold >= 0.5 then
			print(text)
		end
		ns.moverTold = now
		if def.path and C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				ns.NotifyOption(def.path)
			end)
		end
	end
	if not ns.Get("movers.enabled") or (info.system and not ns.Get("movers.systems")) then
		Refuse("Turn on Move frames and Move the game's own frames on the Movers page to set a frame scale.")
		return
	end
	local percentNow = math.floor(percent + 0.5)
	local frame = GameFrame(name)
	local entry = Ensure(name, info)
	if not entry and frame and percentNow ~= 100 then
		-- No handle is open: the spot is taken from the frame as it is.
		local left, bottom, width, height = Rect(frame)
		if left and Commit(name, info, left, bottom, width, height) then
			entry = Saved()[name]
		end
	end
	if not entry then
		if percentNow ~= 100 then
			Refuse(("%s: no place saved yet. Show the frame, then set the scale again."):format(info.label))
		end
		return
	end
	local wanted = percentNow ~= 100 and Snap(percentNow / 100) or nil
	local resized = entry.scale ~= wanted
	entry.scale = wanted
	Clean(entry)
	ns.Each(KEY, ApplyEntry, name)
	if resized then
		ns.ResizeAll()
	end
	Changed(info)
	ShowHandle(name)
end

-- A box takes the mouse unless the game places its frame or a frame is being picked, so the picker sees what lies under it.
local function SetMouse(name)
	local handle, look = handles[name], handleLooks[name]
	if not handle then
		return
	end
	local wanted = not look.placedByGame and not pick.on
	if look.mouse ~= wanted then
		look.mouse = wanted
		handle:EnableMouse(wanted)
		handle:EnableMouseWheel(wanted)
		centre.Mouse(look, wanted)
	end
end

local function HideHandle(name)
	handleLooks[name].shown = false
	handles[name]:Hide()
end

-- The smaller a box, the higher its level, so of two boxes on one place the smaller takes the mouse.
local function LevelOf(width, height)
	local sw, sh = ScreenSize()
	if not sw then
		return 1
	end
	return 1 + math.floor((1 - math.min(1, math.sqrt(width * height / (sw * sh)))) * BOX_LEVELS)
end

local function MakeHandle(name)
	local handle = CreateFrame("Frame", nil, UIParent)
	ns.Own[handle] = true
	handle:SetFrameStrata("HIGH")
	handle:SetClampedToScreen(true)
	handle:SetMovable(true)
	handle:EnableMouse(true)
	handle:EnableMouseWheel(true)
	handle:RegisterForDrag("LeftButton")
	local outline = ns.Outline(handle, handle, true)
	handleLooks[name] = { outline = outline, placedByGame = false, mouse = true }
	local text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetAllPoints(handle)
	handleTexts[name] = text
	-- The look of a handle, and its hover and selection, are in MoversMode.lua.
	ns.MoversMode.Style(name, handle, outline, text)
	handle:SetScript("OnDragStart", function(self)
		if not InCombatLockdown() then
			dragging = name
			-- The box follows the cursor, so it is placed again after the drop even where the frame did not move.
			handleLooks[name].left = nil
			handleLooks[name].dragged = true
			ns.Try(KEY, centre.Start, self)
		end
	end)
	handle:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		centre.Stop(self)
		-- centre.Step may have ended the drag already, and a second stop for the same release does nothing.
		if open and dragging == name then
			ns.Try(KEY, Dropped, name)
		end
	end)
	handle:SetScript("OnMouseWheel", function(_, delta)
		ns.Try(KEY, Wheel, name, delta)
	end)
	handle:SetScript("OnMouseDown", function(_, button)
		handleLooks[name].dragged = false
		ns.Try(KEY, ns.MoversMode.Press, name, button)
	end)
	handle:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.Try(KEY, ResetFrame, name)
		elseif mouseButton == "LeftButton" then
			ns.Try(KEY, centre.Click, name)
		end
	end)
	return handle
end

function ShowHandle(name)
	local info = Describe(name)
	local handle = handles[name]
	if dragging == name then
		return
	end
	local left, bottom, width, height
	-- A handle exists only while the handles are open.
	if info and open and not ns.MoversMode.Hidden(name) then
		left, bottom, width, height = HandleRect(name, info)
	end
	if not left then
		if handle then
			HideHandle(name)
		end
		return
	end
	if not handle then
		handle = MakeHandle(name)
		handles[name] = handle
	end
	local look = handleLooks[name]
	-- A box that has not moved or changed size is left as it is.
	if look.left ~= left or look.bottom ~= bottom or look.width ~= width or look.height ~= height then
		look.left, look.bottom, look.width, look.height = left, bottom, width, height
		handle:ClearAllPoints()
		handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
		handle:SetSize(width, height)
		handle:SetFrameLevel(LevelOf(width, height))
	end
	local saved = Saved()
	local entry = saved and saved[name]
	local percent = type(entry) == "table" and entry.scale and Number(entry.scale) and math.floor(entry.scale * 100 + 0.5) or nil
	-- A box for a frame the game places is grey and takes no mouse.
	local placedByGame = PlacedByGame(name, info)
	if look.placedByGame ~= placedByGame then
		look.placedByGame = placedByGame
		ns.MoversMode.Paint(name)
	end
	SetMouse(name)
	local text = info.label
	if placedByGame then
		text = ("%s (placed by the game)"):format(text)
	else
		if percent then
			text = ("%s %d%%"):format(text, percent)
		end
		-- A frame the game lays out is moved back in a fight where its layout cannot hold the spot: a preset, or no layout to write.
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and KindOf(name, frame) == "layout" and ns.LayoutSpots.Mode() ~= "layout" then
			text = ("%s (%s)"):format(text, BACK_IN_FIGHT)
		end
	end
	if look.text ~= text then
		look.text = text
		handleTexts[name]:SetText(text)
	end
	if not look.shown then
		look.shown = true
		handle:Show()
	end
	centre.Look(name)
end

local function ShowHandles()
	if not open then
		return
	end
	for _, info in ipairs(LIST) do
		ns.Each(KEY, ShowHandle, info.name)
	end
	for name in pairs(Saved() or {}) do
		if not BY_NAME[name] then
			ns.Each(KEY, ShowHandle, name)
		end
	end
end

-- The open boxes take the names they have now, after a block picked a bar or let it go.
function ns.MoverRelabel()
	ShowHandles()
end

-- Puts one frame back where the game had it, and forgets its saved spot. `was` is the spot it had in the profile that
-- was in use, for a frame that has none in this one.
function ResetFrame(name, was)
	local saved = Saved()
	local info = Describe(name, was)
	if not (saved and info) or hold.by[name] then
		return
	end
	local moved = type(was or saved[name]) == "table" and not info.own
	local frame = GameFrame(name)
	local laidOut = frame ~= nil and not ns.Forbidden(frame) and KindOf(name, frame) == "layout"
	local restored, released = RestoreFrame(name)
	saved[name] = nil
	Changed(info)
	ScaleRowMoved(name)
	stopped[name], corrections[name], refused[name] = nil, nil, nil
	Uncount(name)
	-- Under Every window together a window with no spot has the one size of every window.
	if frame and win.IsWindow(name) then
		ns.Each(KEY, win.SizeWindow, name, frame)
	end
	-- The panel manager places a window again the next time it opens.
	if moved and released then
		if not resettingAll then
			print(("%s goes back to Edit Mode's spot after a reload."):format(info.label))
		end
	elseif moved and info.stack and restored ~= nil then
		barsLeft = true
		if not resettingAll then
			print(("%s stays where it is until the game places it again at its next layout or after /reload."):format(info.label))
		end
	elseif moved and restored == false and info.kind ~= "window" then
		print(("%s goes back to its place after /reload."):format(info.label))
	elseif moved and restored and info.system then
		systemReset = laidOut and "layout" or systemReset or "system"
		if not resettingAll then
			print(laidOut and ("%s is back where it was. The game places it again at the next layout or after /reload."):format(info.label)
				or ("%s is back where it was, and /reload gives it back to Edit Mode fully."):format(info.label))
		end
	end
	ShowHandle(name)
	UpdateDriver()
end

-- Puts every frame that has a spot back where the game has it. With `was`, the spots that were in use before a change of
-- profile, it puts back the frames that had a spot there and have none now.
local function ResetAll(was)
	local saved = Saved()
	local names = {}
	for name in pairs(was or saved) do
		if not (was and saved[name]) and not hold.by[name] then
			names[#names + 1] = name
		end
	end
	resettingAll, systemReset, barsLeft = true, false, false
	for _, name in ipairs(names) do
		ns.Each(KEY, ResetFrame, name, was and was[name])
	end
	resettingAll = false
	if barsLeft then
		print((was and "Bars " or "Moved frames are back where the game has them, but bars ") .. BARS_STAY)
	elseif not was then
		print("Moved frames are back where the game has them.")
	end
	if systemReset == "layout" then
		print("The game places the frames it lays out again at the next layout or after /reload.")
	elseif systemReset then
		print("/reload gives the game's own frames back to Edit Mode fully.")
	end
end

-- Centring -----------------------------------------------------------------------------------------

function centre.Snapping()
	return ns.Get("movers.snap") == "middle"
end

function centre.ByButton()
	local how = ns.Get("movers.centreWith")
	return how == "button" or how == "both"
end

function centre.ByAlt()
	local how = ns.Get("movers.centreWith")
	return how == "alt" or how == "both"
end

function centre.Ticks()
	return ns.Get("movers.centreAll") == "button"
end

-- The left edge a handle of this width has with its middle on the middle of the screen, when snapping is on and its middle is within
-- centre.snap of the middle of the screen. Nothing otherwise.
function centre.Snaps(left, width)
	local wide = ScreenSize()
	if wide and centre.Snapping() and math.abs(left + width / 2 - wide / 2) <= centre.snap then
		return (wide - width) / 2
	end
	return nil
end

-- The middle line is a thin line down the screen at the middle of UIParent. It is shown while a handle or a window is dragged, or while the
-- handles are open, as the setting says, and is brighter while what is dragged is snapped to it. It takes no mouse.
function centre.MakeLine()
	local line = CreateFrame("Frame", nil, UIParent)
	ns.Own[line] = true
	line:SetFrameStrata("FULLSCREEN_DIALOG")
	line:SetFrameLevel(1)
	line:SetPoint("TOP", UIParent, "TOP", 0, 0)
	line:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
	local texture = line:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[texture] = true
	texture:SetAllPoints(line)
	-- As the edges of the outlines: a thin line is not pulled to a pixel.
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	local r, g, b = ns.PanelLook.Colour("accent")
	texture:SetColorTexture(r, g, b, 1)
	centre.line = line
	return line
end

function centre.LineLook()
	local mode = ns.Get("movers.middleLine")
	-- A window is being moved once its drag has placed it: only a move sets `snapped`, and a size does not.
	local moving = dragging ~= nil or (win.drag ~= nil and win.drag.snapped ~= nil)
	local wanted = (mode == "always" and open == true) or (mode == "dragging" and moving)
	local line = centre.line
	if not wanted then
		if line and centre.lineShown then
			centre.lineShown = false
			line:Hide()
		end
		return
	end
	line = line or centre.MakeLine()
	local width = ns.Pixels(line, 1)
	if centre.lineWidth ~= width then
		centre.lineWidth = width
		line:SetWidth(width)
	end
	local snapped = (centre.drag and centre.drag.snapped) or (win.drag and win.drag.snapped)
	local alpha = snapped and centre.snapped or centre.alpha
	if centre.lineAlpha ~= alpha then
		centre.lineAlpha = alpha
		line:SetAlpha(alpha)
	end
	if not centre.lineShown then
		centre.lineShown = true
		line:Show()
	end
end

-- A handle follows the cursor from where it was taken, a frame at a time, and snaps to the middle on the way. Where the cursor cannot be
-- read the engine moves it, and the drop snaps it.
function centre.Start(handle)
	local x, y = win.Cursor()
	local left, bottom, width, height = Rect(handle)
	if not (x and left) then
		centre.fallback = true
		centre.dropMiddle = nil
		handle:StartMoving()
	else
		centre.drag = { handle = handle, grabX = x - left, grabY = y - bottom, width = width, height = height }
		handle:SetScript("OnUpdate", centre.Step)
	end
	centre.LineLook()
end

function centre.Step(handle)
	local drag = centre.drag
	local x, y = win.Cursor()
	local screenW, screenH = ScreenSize()
	if not (drag and drag.handle == handle and x and screenW) then
		return
	end
	-- The button was let go of away from the handle, which the handle did not hear.
	if win.ButtonUp() then
		local stop = handle:GetScript("OnDragStop")
		if stop then
			stop(handle)
		end
		return
	end
	local left = math.max(0, math.min(x - drag.grabX, screenW - drag.width))
	local bottom = math.max(0, math.min(y - drag.grabY, screenH - drag.height))
	local middle = centre.Snaps(left, drag.width)
	drag.snapped = middle ~= nil
	left = middle or left
	left, bottom = ns.MoversSnap.Snap(dragging, left, bottom, drag.width, drag.height, middle ~= nil)
	if left ~= drag.left or bottom ~= drag.bottom then
		drag.left, drag.bottom = left, bottom
		handle:ClearAllPoints()
		handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	end
	centre.LineLook()
end

function centre.Stop(handle)
	local drag = centre.drag
	if drag and drag.handle == handle then
		centre.dropMiddle = drag.snapped == true
		centre.drag = nil
		handle:SetScript("OnUpdate", nil)
	end
end

-- Puts a handle and its frame on the horizontal middle of the screen at the height they have, saved as a move is. True when it was done.
-- A handle the game places is left, and so is one that is not shown.
function centre.Do(name)
	local info, look = Describe(name), handleLooks[name]
	-- The left edge is only there for Commit's signature: a centred frame is anchored by its middle.
	local wide = ScreenSize()
	if not (info and look and look.shown and not look.placedByGame and wide and look.width) then
		return false
	end
	-- The box is the frame's own, which the handle was put over. The handle is held on the screen, so a frame that hangs over the edge of it
	-- would lose height if the box were taken from the handle.
	local done = Commit(name, info, (wide - look.width) / 2, look.bottom, look.width, look.height, true)
	ShowHandle(name)
	return done == true
end

-- A click on a handle with Alt held centres it, unless the press was a drag.
function centre.Click(name)
	local look = handleLooks[name]
	local dragged = look.dragged
	look.dragged = false
	if not dragged and centre.ByAlt() and KeyDown(IsAltKeyDown) then
		centre.Do(name)
	end
end

function centre.Toggle(name)
	centre.ticked[name] = not centre.ticked[name] or nil
	centre.Look(name)
end

-- Centres the handles that are ticked and clears the ticks.
function centre.Everything()
	local names = {}
	for name in pairs(centre.ticked) do
		names[#names + 1] = name
	end
	table.sort(names)
	if #names == 0 then
		print("No handle is ticked. Tick the box on each handle, then press Centre ticked.")
		return
	end
	local done = 0
	for _, name in ipairs(names) do
		centre.ticked[name] = nil
		if centre.Do(name) then
			done = done + 1
		end
		centre.Look(name)
	end
	if done == 0 then
		print("Nothing was centred: the ticked handles are hidden or placed by the game.")
	else
		print(("%d %s centred."):format(done, done == 1 and "handle" or "handles"))
	end
end

-- Where the button and the tick box hang from a handle, each as its own point, the point of the handle it hangs from and the offsets: inside
-- it, in its top corners, or on a handle too small for them in a pair above it, the box left of the middle and the button right of it, and
-- below it where the screen ends above it, moved in from the edge of the screen where the handle is at it. A frame of the addon's is not cut off
-- by its parent, so the pair takes clicks outside the handle.
centre.anchors = {
	inside = { button = { "TOPRIGHT", "TOPRIGHT", -2, -2 }, box = { "TOPLEFT", "TOPLEFT", 2, -2 } },
	above = { button = { "BOTTOMLEFT", "TOP", 1, 2 }, box = { "BOTTOMRIGHT", "TOP", -1, 2 } },
	below = { button = { "TOPLEFT", "BOTTOM", 1, -2 }, box = { "TOPRIGHT", "BOTTOM", -1, -2 } },
}

function centre.Hang(handle, look)
	local anchors = centre.anchors[look.where]
	for _, part in ipairs({ "button", "box" }) do
		local square = look[part]
		if square then
			local at = anchors[part]
			square:ClearAllPoints()
			square:SetPoint(at[1], handle, at[2], at[3] + look.shift, at[4])
		end
	end
end

-- How far a pair hung outside a small handle is moved along, in units, so that it stays on the screen where the handle is at the left or the
-- right edge of it. The pair reaches one square and a gap from the middle of the handle on each side.
function centre.Shift(look)
	local wide = ScreenSize()
	if not (wide and look.left) then
		return 0
	end
	local reach, middle = centre.size + 1, look.left + look.width / 2
	return math.max(0, reach - middle) - math.max(0, middle - (wide - reach))
end

-- A small square of the addon's on a handle: a thin border on a dark fill, like the buttons of the Movers panel.
function centre.Square(handle, mouse, onClick)
	local square = CreateFrame("Frame", nil, handle)
	ns.Own[square] = true
	square:SetSize(centre.size, centre.size)
	square:EnableMouse(mouse)
	local outline = ns.Outline(square, square, true)
	ns.KeepOutline(outline)
	ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	square:SetScript("OnEnter", function()
		ns.SetOutlineFill(outline, 0.3, 0.3, 0.3, 1)
	end)
	square:SetScript("OnLeave", function()
		ns.SetOutlineFill(outline, 0.18, 0.18, 0.18, 1)
	end)
	square:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			onClick()
		end
	end)
	return square
end

-- A bar of the picture on a square.
function centre.Picture(square, width, height)
	local bar = square:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[bar] = true
	bar:SetColorTexture(1, 1, 1, 0.9)
	bar:SetSize(width, height)
	return bar
end

-- The button that centres a handle: a line down the middle with a short bar on each side of it.
function centre.MakeCentreButton(handle, name, mouse)
	local square = centre.Square(handle, mouse, function()
		ns.Try(KEY, centre.Do, name)
	end)
	local middle = centre.Picture(square, 2, 10)
	middle:SetPoint("CENTER", square, "CENTER", 0, 0)
	centre.Picture(square, 4, 2):SetPoint("RIGHT", middle, "LEFT", 0, 2)
	centre.Picture(square, 4, 2):SetPoint("LEFT", middle, "RIGHT", 0, -2)
	return square
end

-- The tick box of a handle: a square that shows a mark while the handle is ticked.
function centre.MakeTickBox(handle, name, mouse)
	local square = centre.Square(handle, mouse, function()
		ns.Try(KEY, centre.Toggle, name)
	end)
	local mark = centre.Picture(square, centre.size - 6, centre.size - 6)
	local r, g, b = ns.PanelLook.Colour("accent")
	mark:SetColorTexture(r, g, b, 1)
	mark:SetPoint("CENTER", square, "CENTER", 0, 0)
	mark:Hide()
	handleLooks[name].mark = mark
	return square
end

-- A handle that takes no mouse, for the picker, has a button and a box that take none.
function centre.Mouse(look, wanted)
	if look.button then
		look.button:EnableMouse(wanted)
	end
	if look.box then
		look.box:EnableMouse(wanted)
	end
end

-- The button and the tick box of a handle, as the settings ask. A handle the game places has neither. One too small for them has them
-- above it, or below it where the screen ends above it.
function centre.Look(name)
	local handle, look = handles[name], handleLooks[name]
	if not (handle and look) then
		return
	end
	local usable = look.shown and not look.placedByGame
	local button, box = usable and centre.ByButton(), usable and centre.Ticks()
	local count = (button and 1 or 0) + (box and 1 or 0)
	local where = "inside"
	if count > 0 and not (look.width >= (count + 1) * centre.size and look.height >= centre.size + 4) then
		local _, screenH = ScreenSize()
		where = screenH and look.bottom + look.height + centre.size + 2 > screenH and "below" or "above"
	end
	local shift = where ~= "inside" and centre.Shift(look) or 0
	local hang = look.where ~= where or look.shift ~= shift
	if button and not look.button then
		look.button, hang = centre.MakeCentreButton(handle, name, look.mouse), true
	end
	if box and not look.box then
		look.box, hang = centre.MakeTickBox(handle, name, look.mouse), true
	end
	look.where, look.shift = where, shift
	if hang then
		centre.Hang(handle, look)
	end
	if look.button and look.buttonOn ~= button then
		look.buttonOn = button
		look.button:SetShown(button)
	end
	if look.box then
		if look.boxOn ~= box then
			look.boxOn = box
			look.box:SetShown(box)
		end
		local ticked = centre.ticked[name] == true
		if look.ticked ~= ticked then
			look.ticked = ticked
			look.mark:SetShown(ticked)
		end
	end
end

-- The line of the Movers panel that says how to centre, as the settings ask.
function centre.Words()
	local how = ns.Get("movers.centreWith")
	local text = "Click the button on a handle to centre it."
	if how == "alt" then
		text = "Alt and click a handle to centre it."
	elseif how == "both" then
		text = "Click the button on a handle, or Alt and click it, to centre it."
	end
	if centre.Ticks() then
		text = text .. " Tick the box on each handle, then press Centre ticked."
	end
	return text
end

-- The button of the Movers panel is there while the setting asks for the tick boxes, and the line under the hint follows the settings.
function centre.Panel()
	if centre.button then
		centre.button:SetShown(open == true and centre.Ticks())
	end
	local text = centre.Words()
	if centre.how and centre.howText ~= text then
		centre.howText = text
		centre.how:SetText(text)
	end
end

-- The settings changed: the panel, the line and the handles follow.
function centre.Refresh()
	centre.Panel()
	centre.LineLook()
	if open then
		ShowHandles()
	end
end

-- The handles close: a drag ends, the ticks go, and the line and the button of the panel hide.
function centre.Closed()
	local drag = centre.drag
	if drag then
		centre.Stop(drag.handle)
	end
	centre.ticked = {}
	centre.Refresh()
end

-- Starting and stopping the driver -----------------------------------------------------------------

local function HasGameEntries()
	if win.Sizing() or next(hold.by) ~= nil then
		return true
	end
	for name in pairs(Saved() or {}) do
		local info = BY_NAME[name]
		if not (info and (info.own or (info.system and not ns.Get("movers.systems")))) and not hold.Off(name) and not hold.Hooked(name) then
			return true
		end
	end
	return false
end

local PickStep, PickShow

local function Drive(_, elapsed)
	clock.keep = clock.keep + elapsed
	if clock.keep >= KEEP_EVERY then
		clock.keep = 0
		if ns.Get("movers.keep") then
			ns.Try(KEY, Check)
		end
	end
	if open then
		clock.handles = clock.handles + elapsed
		if clock.handles >= HANDLES_EVERY then
			clock.handles = 0
			ns.Try(KEY, ShowHandles)
		end
		if pick.on then
			clock.pick = clock.pick + elapsed
			if clock.pick >= PICK_EVERY then
				clock.pick = 0
				ns.Try(KEY, PickStep)
			end
			ns.Try(KEY, PickShow)
		end
	end
end

-- The check runs only while a saved frame is there to keep, or the handles are open.
function UpdateDriver()
	local wanted = running and ns.Enabled(KEY) and (open or (ns.Get("movers.keep") and HasGameEntries()))
	if wanted and not driver then
		driver = CreateFrame("Frame")
		ns.Own[driver] = true
		driver:SetScript("OnUpdate", Drive)
	end
	if driver then
		driver:SetShown(wanted and true or false)
	end
end

-- The picker ------------------------------------------------------------------------------------

local tag, tagText, box, boxOutline

local function Refused(name)
	if REFUSE[name] or hold.Off(name) then
		return true
	end
	-- Edit Mode's frames are listed, and some have names that a pattern below would refuse.
	if BY_NAME[name] and BY_NAME[name].system then
		return false
	end
	for _, pattern in ipairs(REFUSE_PATTERNS) do
		if name:find(pattern) then
			return true
		end
	end
	return false
end

local function NameOf(node)
	local ok, name = pcall(node.GetName, node)
	if ok and type(name) == "string" and not ns.IsSecret(name) then
		return name
	end
	return nil
end

-- The frame and its parents up to UIParent. A frame the addon may not touch ends the walk with nothing.
local function ChainOf(leaf)
	local nodes = {}
	local node = leaf
	for _ = 1, MAX_DEPTH do
		if type(node) ~= "table" or ns.IsSecret(node) or ns.Forbidden(node) then
			return nil
		end
		nodes[#nodes + 1] = node
		if node == UIParent then
			return nodes
		end
		local ok, parent = pcall(node.GetParent, node)
		if not ok then
			return nil
		end
		node = parent
	end
	return nil
end

-- Edit Mode owns these.
local function IsSystem(node)
	local ok, found = pcall(function()
		return node.system ~= nil or node.SetPointBase ~= nil
	end)
	return ok and found == true
end

-- A frame a container or manager lays out is placed again by it on every layout pass. A frame the player has
-- moved in Edit Mode is taken out of its container, which sets this field.
local function IsLaidOut(node, parent)
	local ok, laid = pcall(function()
		if node.ignoreFramePositionManager == true then
			return false
		end
		return node.isManagedFrame ~= nil or node.layoutParent ~= nil
			or (node.layoutIndex ~= nil and parent ~= nil and parent.Layout ~= nil)
	end)
	return not ok or laid == true
end

-- True once Edit Mode has set the frame up.
local function SetUp(frame)
	local ok, flag = pcall(function()
		return frame.systemInfo.isInDefaultPosition
	end)
	return ok and not ns.IsSecret(flag) and type(flag) == "boolean"
end

-- True when the game's layout passes place a frame Edit Mode owns again: a bar of the action bar stacks, or a frame
-- a container lays out.
function Passes(info, frame)
	return (info ~= nil and info.stack == true) or IsLaidOut(frame)
end

-- A frame Edit Mode owns that the addon may place: Edit Mode has set it up.
local function Placeable(info, frame)
	return BaseCalls(frame) ~= nil and SetUp(frame)
end

-- "layout" for a frame the game's layout passes place again, which is kept in the Edit Mode layout; nil for any other frame.
function KindOf(name, frame)
	local info = BY_NAME[name]
	if info == nil then
		if not IsSystem(frame) then
			return nil
		end
		info = { system = true }
	end
	return ns.LayoutSpots.Kind(info, frame, Passes(BY_NAME[name], frame))
end

-- True when the game places the frame itself: it is on the refuse list, a frame Edit Mode owns is above it, Edit
-- Mode has not set it up, or a container lays out a frame that is not Edit Mode's.
-- A saved spot is applied only to a frame that passes. A frame in LIST passes the refuse list: the game places a
-- bag or a menu again on every layout pass, and the check puts it back.
function Unmovable(name, frame)
	if Refused(name) and not BY_NAME[name] then
		return true
	end
	local nodes = ChainOf(frame)
	if not nodes then
		return true
	end
	for _, node in ipairs(nodes) do
		if node ~= frame and IsSystem(node) then
			return true
		end
	end
	if IsSystem(frame) then
		return not Placeable(BY_NAME[name], frame)
	end
	return IsLaidOut(frame, nodes[2])
end

local function Answered(ok, value)
	return ok and not ns.IsSecret(value) and value == false
end

-- The tests a frame must pass before the picker offers it. They only read: GetName is a Lua method on a few
-- frames, a getter that runs in a pcall.
local function Pickable(node, parent)
	if ns.Own[node] then
		return false
	end
	local okFrame, isFrame = pcall(node.IsObjectType, node, "Frame")
	local name = NameOf(node)
	if not okFrame or ns.IsSecret(isFrame) or isFrame ~= true or not name or _G[name] ~= node or Refused(name) or (IsLaidOut(node, parent) and not IsSystem(node)) then
		return false
	end
	local okRestricted, restricted = pcall(node.IsAnchoringRestricted, node)
	local okSecret, secret = pcall(node.IsAnchoringSecret, node)
	if not (Answered(okRestricted, restricted) and Answered(okSecret, secret)) or not Rect(node) then
		return false
	end
	-- The second answer is whether the frame is protected itself and not through a child. A frame Edit Mode owns may
	-- be, since it is placed out of combat.
	local okProtected, _, explicit = pcall(node.IsProtected, node)
	if not (Answered(okProtected, explicit) or BaseCalls(node)) then
		return false
	end
	-- A frame stretched between two anchors loses its size when it has one.
	local okCount, count = pcall(node.GetNumPoints, node)
	return okCount and Number(count) and count == 1
end

-- Gives every box the mouse again, or takes it from them.
local function SetMouseAll()
	for name in pairs(handles) do
		SetMouse(name)
	end
end

local function StopPick()
	pick.on = false
	pick.leaf, pick.cands, pick.edit, pick.chosen = nil, nil, nil, nil
	SetMouseAll()
	if tag then
		tag:Hide()
	end
	if box then
		box:Hide()
	end
end

-- Takes the frame under the mouse: it is saved at its current spot and gets a handle.
local function Take(frame)
	local saved = Saved()
	local name = NameOf(frame)
	local left, bottom, width, height = Rect(frame)
	if not (saved and name and left) then
		return
	end
	local point = ThirdPoint(left + width / 2, bottom + height / 2)
	local x, y = Offsets(point, left, bottom, width, height)
	if not x then
		return
	end
	saved[name] = Clean({ point = point, x = x, y = y, kind = IsWindow(name) and "window" or "hud", label = name })
	ns.Each(KEY, ApplyEntry, name)
	ns.MoversMode.Changed(name)
	ShowHandle(name)
	UpdateDriver()
	print(("%s can be moved now."):format(name))
end

local keys = { shift = false, alt = false }

-- Reads the frame under the mouse ten times a second. Nothing is clicked.
function PickStep()
	local ok, foci = pcall(GetMouseFoci)
	local leaf = ok and type(foci) == "table" and foci[1] or nil
	if leaf == pick.leaf and pick.cands then
		return
	end
	pick.leaf, pick.steps, pick.edit = leaf, 0, nil
	pick.cands = {}
	local nodes = leaf and ChainOf(leaf)
	if not nodes then
		return
	end
	for index = 1, #nodes - 1 do
		local node = nodes[index]
		local name = NameOf(node)
		if Pickable(node, nodes[index + 1]) and not Unmovable(name, node) then
			pick.cands[#pick.cands + 1] = node
		elseif not pick.edit and IsSystem(node) then
			local listed = BY_NAME[name or ""]
			pick.edit = listed and listed.label or name or "This frame"
		end
	end
end

-- Follows the mouse, marks the chosen frame, and reads the keys that step to the next frame and take it.
function PickShow()
	local shift, alt = KeyDown(IsShiftKeyDown), KeyDown(IsAltKeyDown)
	local cands = pick.cands or {}
	if shift and not keys.shift then
		pick.steps = pick.steps + 1
	end
	if #cands > 0 then
		pick.chosen = cands[pick.steps % #cands + 1]
	else
		pick.chosen = nil
	end
	if alt and not keys.alt and pick.chosen then
		keys.shift, keys.alt = shift, alt
		local chosen = pick.chosen
		StopPick()
		Take(chosen)
		return
	end
	keys.shift, keys.alt = shift, alt
	local x, y
	if type(GetCursorPosition) == "function" then
		x, y = GetCursorPosition()
	end
	local _, scale = Ratio(UIParent)
	if Number(x) and Number(y) and scale then
		tag:ClearAllPoints()
		tag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 14, y / scale - 8)
	end
	if pick.chosen then
		tagText:SetText(NameOf(pick.chosen) or "")
		local left, bottom, width, height = Rect(pick.chosen)
		if left then
			box:ClearAllPoints()
			box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
			box:SetSize(width, height)
			box:Show()
		else
			box:Hide()
		end
	else
		box:Hide()
		tagText:SetText(pick.edit and ("%s is placed by the game."):format(pick.edit) or "")
	end
end

local function StartPick()
	if not tag then
		tag = CreateFrame("Frame", nil, UIParent)
		ns.Own[tag] = true
		tag:SetFrameStrata("TOOLTIP")
		tag:SetSize(1, 1)
		tagText = tag:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		tagText:SetPoint("TOPLEFT", tag, "TOPLEFT", 0, 0)
		tagText:SetJustifyH("LEFT")
		box = CreateFrame("Frame", nil, UIParent)
		ns.Own[box] = true
		box:SetFrameStrata("HIGH")
		boxOutline = ns.Outline(box, box, true)
		ns.SetOutline(boxOutline, true, false)
		ns.SetOutlineColour(boxOutline, ns.PanelLook.Colour("accent"))
		ns.SetOutlineThickness(boxOutline, 2)
	end
	pick.on, pick.leaf, pick.cands, pick.steps = true, nil, nil, 0
	SetMouseAll()
	keys.shift, keys.alt = KeyDown(IsShiftKeyDown), KeyDown(IsAltKeyDown)
	tag:Show()
	print("Point at a frame and press Alt to take it. Shift picks the frame around it.")
end

-- Windows ----------------------------------------------------------------------------------------

local Grips

-- Whether the window part of the module is on, whether windows can be dragged, whether they can be sized, whether one size
-- is shared by every window, and whether that size is not 100%.
function win.On()
	return running == true and ns.Enabled(KEY) and not ns.PartStopped(KEY, WIN.part)
end

function win.DragOn()
	return win.On() and ns.Get("movers.titles") == true
end

function win.SizeOn()
	return win.On() and ns.Get("movers.grip") ~= "off"
end

function win.Shared()
	return ns.Get("movers.sizeScope") == "all"
end

function win.Sizing()
	return win.On() and win.Shared() and ns.Get("movers.windowSize") ~= 100
end

-- The windows of the panel manager, by name.
function win.Panels()
	local list = UIPanelWindows
	if not ns.IsSecret(list) and type(list) == "table" then
		return list
	end
	return nil
end

-- The panel manager gives a window the whole screen when its area is full.
function win.Whole(attributes)
	return not ns.IsSecret(attributes) and type(attributes) == "table" and attributes.area == "full"
end

-- True for a listed window, and for a window of the panel manager that is not listed and does not take the whole screen.
function win.IsWindow(name)
	local info = BY_NAME[name]
	if info then
		return info.kind == "window"
	end
	local list = win.Panels()
	local attributes = list and list[name]
	return attributes ~= nil and not win.Whole(attributes)
end

-- Calls fn with the name of each window that may have grips: the listed windows, then the rest of the panel manager's.
function win.Each(fn)
	for _, info in ipairs(LIST) do
		if info.kind == "window" then
			fn(info.name)
		end
	end
	for name, attributes in pairs(win.Panels() or {}) do
		if type(name) == "string" and not BY_NAME[name] and not win.Whole(attributes) then
			fn(name)
		end
	end
end

-- The cursor in the units of UIParent, or nil when the client will not say.
function win.Cursor()
	if type(GetCursorPosition) ~= "function" then
		return nil
	end
	local ok, x, y = pcall(GetCursorPosition)
	local _, base = Ratio(UIParent)
	if ok and base and Number(x) and Number(y) then
		return x / base, y / base
	end
	return nil
end

function win.ButtonUp()
	if type(IsMouseButtonDown) ~= "function" then
		return false
	end
	local ok, down = pcall(IsMouseButtonDown, "LeftButton")
	return ok and not ns.IsSecret(down) and down == false
end

function win.Label(name)
	local info = Describe(name)
	return info and info.label or name
end

-- The size a window has now, as a factor of the size the game gives it: the one size of every window, or the size saved for
-- the window. 1 while the part is off.
function win.Factor(name, entry)
	if not win.On() then
		return 1
	elseif win.Shared() then
		return ns.Get("movers.windowSize") / 100
	elseif type(entry) == "table" and Number(entry.scale) then
		return entry.scale
	end
	return 1
end

-- The spot a window is placed at: under Every window together the size is the shared one, and the size saved in the spot stays saved.
function win.Entry(name, entry)
	if type(entry) ~= "table" or entry.kind ~= "window" or not win.Shared() then
		return entry
	end
	local f = win.Factor(name, entry)
	return { point = entry.point, x = entry.x, y = entry.y, scale = f ~= 1 and f or nil }
end

-- Why a window is the game's for now, or nil. The game sizes and places the map itself while it fills the screen (UpdateMaximizedSize,
-- MaximizeUIPanel), so the key the window's row names is read, and a key that is true, withheld or unreadable counts as full size. In the
-- gamepad interface the map reads the gamepad cursor in the units of UIParent, which a scale of its own would put off the map.
function win.Fills(frame)
	local info = BY_NAME[NameOf(frame) or ""]
	if not (info and info.fills) then
		return nil
	end
	local ok, full = pcall(function()
		return frame[info.fills]
	end)
	if not ok or ns.IsSecret(full) or full == true then
		return "it fills the screen"
	end
	local okStyle, gamepad = pcall(function()
		return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
	end)
	if okStyle and gamepad == true then
		return "the gamepad interface is on"
	end
	return nil
end

-- The child of a window that its row names as its layer, or nil.
function win.Layer(frame)
	local info = BY_NAME[NameOf(frame) or ""]
	if not (info and info.layer) then
		return nil
	end
	local ok, layer = pcall(function()
		return frame[info.layer]
	end)
	if ok and type(layer) == "table" and not ns.IsSecret(layer) and not ns.Forbidden(layer) then
		return layer
	end
	return nil
end

-- The strata of that child, or nil when the window has none or the client will not say.
function win.LayerStrata(frame)
	local layer = win.Layer(frame)
	if not layer then
		return nil
	end
	local ok, strata = pcall(layer.GetFrameStrata, layer)
	if ok and type(strata) == "string" and not ns.IsSecret(strata) then
		return strata
	end
	return nil
end

-- Sets the scale of a window and sets each of its points again with its offsets times the old scale over the new one, so the corner the
-- game anchored stays where it is (EditModeSystemMixin:SetScaleOverride does the same). False, with nothing changed, when a point cannot be read.
function win.Rescale(frame, current, wanted)
	local okCount, count = pcall(frame.GetNumPoints, frame)
	if not (okCount and Number(count)) then
		return false
	end
	local points = {}
	for index = 1, count do
		local okPoint, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
		if not (okPoint and type(point) == "string" and not ns.IsSecret(point) and not ns.IsSecret(relativeTo) and not ns.IsSecret(relativePoint)
			and Number(x) and Number(y)) then
			return false
		end
		points[#points + 1] = { point, relativeTo or UIParent, relativePoint or point, x, y }
	end
	local setPoint, clear, setScale = Calls(frame)
	setScale(frame, wanted)
	clear(frame)
	for _, p in ipairs(points) do
		setPoint(frame, p[1], p[2], p[3], p[4] * current / wanted, p[5] * current / wanted)
	end
	return true
end

-- Gives a window the scale the game gave it. With keepCorner a window keeps its top left corner where it is; any other frame gets the scale only.
function win.GiveBack(frame, scale, keepCorner)
	local name = keepCorner and NameOf(frame)
	local ok, current = pcall(frame.GetScale, frame)
	if not (name and win.IsWindow(name) and ok and Number(current) and win.Rescale(frame, current, scale)) then
		local _, _, setScale = Calls(frame)
		setScale(frame, scale)
	end
end

-- Gives a window the scale the game gave it. The corner it has stays; the game places the window itself at its next layout.
function win.Unscale(frame)
	local own = original[frame]
	if own and own.scaled then
		win.GiveBack(frame, own.scale or 1, true)
		own.scaled, own.applied = false, nil
	end
end

-- The level of a window that is open, that the addon may place and that an anchor may refer to, or nil and why not.
function win.Gate(name, frame)
	local okFrame, isFrame = pcall(frame.IsObjectType, frame, "Frame")
	if not okFrame or ns.IsSecret(isFrame) or isFrame ~= true then
		return nil, "it is not a frame"
	end
	if Refused(name) and not BY_NAME[name] then
		return nil, "it is left to the game"
	end
	if Unmovable(name, frame) then
		return nil, "the game places it"
	end
	local fills = win.Fills(frame)
	if fills then
		return nil, fills
	end
	local okRestricted, restricted = pcall(frame.IsAnchoringRestricted, frame)
	local okSecret, secret = pcall(frame.IsAnchoringSecret, frame)
	if not (Answered(okRestricted, restricted) and Answered(okSecret, secret)) then
		return nil, "its anchors are restricted"
	end
	local left, _, width = Rect(frame)
	if not left then
		return nil, "its size is not readable"
	end
	if width <= WIN.right + MIN_SIZE then
		return nil, "it is too narrow"
	end
	local okLevel, level = pcall(frame.GetFrameLevel, frame)
	if okLevel and Number(level) then
		return level
	end
	return nil, "its level is not readable"
end

-- The level one above the highest of a window and its direct children, so the corner grip lies over the border art.
function win.TopLevel(frame, level)
	local top = level
	pcall(function()
		for _, child in ipairs({ frame:GetChildren() }) do
			if not ns.Forbidden(child) and not ns.Own[child] then
				local ok, childLevel = pcall(child.GetFrameLevel, child)
				if ok and Number(childLevel) and childLevel > top then
					top = childLevel
				end
			end
		end
	end)
	return math.min(top + 1, 10000)
end

-- A protected window is not placed or sized in combat. The player is told once for each fight.
function win.Locked(frame, mode)
	if not (InCombatLockdown() and ns.MaybeProtected(frame)) then
		return false
	end
	if mode == "size" then
		if not win.toldSize then
			win.toldSize = true
			print(WIN.noSize)
		end
	elseif not win.toldMove then
		win.toldMove = true
		print(WIN.noMove)
	end
	return true
end

-- True when the key the player chose is held, or none was chosen. Otherwise false and what to say.
function win.KeyHeld()
	local key = ns.Get("movers.dragKey")
	if key == "shift" then
		return KeyDown(IsShiftKeyDown), "Shift not held"
	elseif key == "alt" then
		return KeyDown(IsAltKeyDown), "Alt not held"
	elseif key == "ctrl" then
		return KeyDown(IsControlKeyDown), "Ctrl not held"
	end
	return true
end

-- True while the cursor holds an item or anything else, or when the client will not say.
function win.Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return not ok or ns.IsSecret(kind) or kind ~= nil
end

-- True while the picker is on or Edit Mode is open.
function win.Busy()
	return pick.on == true or ns.EditModeOpen()
end

-- The frame under the cursor, as the game reports it, or nil.
function win.Leaf()
	if type(GetMouseFoci) ~= "function" then
		return nil
	end
	local ok, foci = pcall(GetMouseFoci)
	if not ok or type(foci) ~= "table" or ns.IsSecret(foci) then
		return nil
	end
	local leaf = foci[1]
	if type(leaf) ~= "table" or ns.IsSecret(leaf) or ns.Forbidden(leaf) then
		return nil
	end
	return leaf
end

-- Why a frame keeps its clicks, or nil when a drag may start from it: a control by its type, or a frame with a mouse script of its own.
-- With a key held (keyed) the player asks for the drag: a model and a frame with a script of its own give way to it, so the window
-- can be taken by the model that fills its pane, and a button, an edit box and a slider still keep their clicks.
function win.Control(node, keyed)
	for _, word in ipairs(WIN.controls) do
		local ok, found = pcall(node.IsObjectType, node, word)
		if not ok or ns.IsSecret(found) then
			return "unreadable"
		elseif found == true and not (keyed and WIN.loose[word]) then
			return word
		end
	end
	if keyed then
		return nil
	end
	for _, script in ipairs(WIN.scripts) do
		local ok, has = pcall(node.HasScript, node, script)
		if not ok or ns.IsSecret(has) then
			return "unreadable"
		elseif has == true then
			local okSet, set = pcall(node.GetScript, node, script)
			if not okSet or ns.IsSecret(set) then
				return "unreadable"
			elseif type(set) == "function" then
				return script
			end
		end
	end
	return nil
end

-- True when a drag may start from the frame under the cursor, which is nodes[1] and lies inside the window nodes[index]. Otherwise false and why.
-- keyed: the player holds the key chosen for dragging.
function win.Free(nodes, index, frame, keyed)
	local leaf = nodes[1]
	if leaf ~= frame then
		if type(leaf.IsMouseClickEnabled) == "function" then
			local ok, clicks = pcall(leaf.IsMouseClickEnabled, leaf)
			if not ok or ns.IsSecret(clicks) then
				return false, "on a control (unreadable)"
			elseif clicks == false then
				return false, "on a hover area"
			end
		end
		local okLeaf, strata = pcall(leaf.GetFrameStrata, leaf)
		local okWindow, wanted = pcall(frame.GetFrameStrata, frame)
		-- The border and the quest log of the map lie in a strata above the map; a press on them is a press on the window.
		if okLeaf and okWindow and not ns.IsSecret(strata) and not ns.IsSecret(wanted) and strata ~= wanted and strata == win.LayerStrata(frame) then
			wanted = strata
		end
		if not (okLeaf and okWindow) or ns.IsSecret(strata) or ns.IsSecret(wanted) or strata ~= wanted then
			return false, "on another layer"
		end
	end
	for i = 1, index - 1 do
		local word = win.Control(nodes[i], keyed)
		if word then
			return false, ("on a control (%s)"):format(NameOf(nodes[i]) or word)
		end
	end
	return true
end

-- Where in a window the cursor is: "title" over the title bar, "corner" over the square of the corner grip, "body" over the rest,
-- nil outside the window.
function win.Zone(name, frame, x, y)
	local left, bottom, width, height = Rect(frame)
	local k = Ratio(frame)
	if not (left and k) or x < left or x > left + width or y < bottom or y > bottom + height then
		return nil
	end
	local setup = BY_NAME[name] and BY_NAME[name].grip
	local inset = (setup and setup.left) or 0
	if bottom + height - y <= WIN.height * k and x >= left + inset * k and x <= left + width - WIN.right * k then
		return "title"
	elseif x >= left + width - WIN.corner * k and y <= bottom + WIN.corner * k then
		return "corner"
	end
	return "body"
end

-- The title bar: a frame of the addon's over the top of the window, from its left edge to the close button, two levels above
-- the window. The game puts its own controls in the title at the level of the window or one above it, so the title bar lies over
-- them, and a press on it is a press on the title.
function win.MakeGrip(name, frame, level)
	local setup = BY_NAME[name] and BY_NAME[name].grip
	local grip = CreateFrame("Frame", nil, frame)
	ns.Own[grip] = true
	win.grips[name] = grip
	grip:SetFrameLevel(level + ((setup and setup.level) or WIN.level))
	grip:SetPoint("TOPLEFT", frame, "TOPLEFT", setup and setup.left or 0, 0)
	grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -WIN.right, 0)
	grip:SetHeight(WIN.height)
	grip:EnableMouse(true)
	grip:SetScript("OnMouseDown", function(_, button)
		ns.EachPart(KEY, WIN.part, win.TitleDown, name, button)
	end)
	grip:SetScript("OnMouseUp", function(_, button)
		ns.EachPart(KEY, WIN.part, win.TitleUp, name, button)
	end)
	grip:SetScript("OnHide", function()
		if win.drag and win.drag.name == name then
			win.EndDrag()
		end
		ns.EachPart(KEY, WIN.part, win.Closed, name)
	end)
end

-- The two lines of a corner grip are shown as the setting says: always, or while the cursor is inside the window.
function win.Hover(name)
	local frame, art = GameFrame(name), win.art[name]
	if not (frame and art) then
		return
	end
	local alpha = 0
	if ns.Get("movers.grip") == "always" or (win.drag and win.drag.name == name) then
		alpha = 1
	else
		local x, y = win.Cursor()
		local left, bottom, width, height = Rect(frame)
		if x and left and x >= left and x <= left + width and y >= bottom and y <= bottom + height then
			alpha = 1
		end
	end
	for _, line in ipairs(art) do
		line:SetAlpha(alpha)
	end
end

-- The corner grip: a frame of the addon's at the bottom right corner of the window, above the border art of the window. A frame over a
-- game button takes its clicks, so the grip takes the mouse only until the game has reported a press, and then only in its last
-- WIN.margin units, where no control of the window lies. After that a press in the corner is found from the frame under the cursor.
function win.MakeCorner(name, frame)
	local corner = CreateFrame("Frame", nil, frame)
	ns.Own[corner] = true
	win.corners[name] = corner
	-- A window whose border and panes lie in a strata above it has its corner grip there, so the lines are drawn over them.
	local strata = win.LayerStrata(frame)
	if strata then
		corner:SetFrameStrata(strata)
	end
	corner:SetSize(WIN.corner, WIN.corner)
	corner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	corner:SetHitRectInsets(WIN.corner - WIN.margin, 0, WIN.corner - WIN.margin, 0)
	corner:EnableMouse(not win.heard)
	local art = {}
	for index, size in ipairs({ { 12, 2 }, { 2, 12 } }) do
		local line = corner:CreateTexture(nil, "OVERLAY", nil, 0)
		line:SetColorTexture(1, 1, 1, 0.7)
		line:SetSize(size[1], size[2])
		line:SetPoint("BOTTOMRIGHT", corner, "BOTTOMRIGHT", -3, 3)
		art[index] = line
	end
	win.art[name] = art
	corner:SetScript("OnMouseDown", function(_, button)
		ns.EachPart(KEY, WIN.part, win.CornerDown, name, button)
	end)
	corner:SetScript("OnMouseUp", function(_, button)
		ns.EachPart(KEY, WIN.part, win.CornerUp, name, button)
	end)
	corner:SetScript("OnUpdate", function(_, elapsed)
		local clock = (win.clocks[name] or 0) + elapsed
		if clock >= WIN.hover then
			clock = 0
			ns.EachPart(KEY, WIN.part, win.Hover, name)
		end
		win.clocks[name] = clock
	end)
	win.Hover(name)
end

-- The corner grips take the mouse until the game has reported a press, and none after it. A protected window waits for the end of combat.
function win.CornerMouse()
	for name, corner in pairs(win.corners) do
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) then
			if InCombatLockdown() and ns.MaybeProtected(frame) then
				win.waiting = true
			else
				corner:EnableMouse(not win.heard)
			end
		end
	end
end

-- Makes the grips of a window that is open. A protected window waits for the end of combat.
function win.Grip(name)
	if win.grips[name] then
		return
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) then
		return
	end
	if IsShown(frame) ~= true then
		win.why[name] = nil
		return
	end
	local level, reason = win.Gate(name, frame)
	if not level then
		win.why[name] = reason ~= "it is left to the game" and reason or nil
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(frame) then
		win.waiting = true
		win.why[name] = "it waits for the end of combat"
		return
	end
	win.why[name] = nil
	win.MakeGrip(name, frame, level)
	win.MakeCorner(name, frame)
	-- With dragging off the title bar is made hidden, and with the corner grip off the corner.
	win.grips[name]:SetShown(win.DragOn())
	win.corners[name]:SetShown(win.SizeOn())
end

-- Puts the two frames of each open window at their levels, and keeps the levels for /flatui status.
function win.Looks()
	for name, grip in pairs(win.grips) do
		local frame = GameFrame(name)
		if not (frame and not ns.Forbidden(frame) and IsShown(frame) == true) then
			win.levels[name] = nil
		else
			local ok, level = pcall(frame.GetFrameLevel, frame)
			if ok and Number(level) then
				local setup = BY_NAME[name] and BY_NAME[name].grip
				local titleLevel = level + ((setup and setup.level) or WIN.level)
				local cornerLevel = win.TopLevel(frame, level)
				-- The corner grip lies in the strata of the layer, one level above the highest child of the layer.
				local layer = win.Layer(frame)
				local okLayer, layerLevel
				if layer then
					okLayer, layerLevel = pcall(layer.GetFrameLevel, layer)
				end
				if layer and okLayer and Number(layerLevel) then
					cornerLevel = math.max(cornerLevel, win.TopLevel(layer, layerLevel))
				end
				grip:SetFrameLevel(titleLevel)
				if win.corners[name] then
					win.corners[name]:SetFrameLevel(cornerLevel)
				end
				win.levels[name] = { level, titleLevel, cornerLevel }
			end
		end
	end
end

-- Makes the grips of the windows that are open, and shows or hides the grips there are as the settings say.
function Grips()
	local drag, size = win.DragOn(), win.SizeOn()
	-- A window that fills the screen has no grips for now, and says why. A window with grips has no other reason in win.why.
	for name, grip in pairs(win.grips) do
		local frame = GameFrame(name)
		local fills = frame and not ns.Forbidden(frame) and win.Fills(frame) or nil
		grip:SetShown(drag and not fills)
		win.why[name] = fills and IsShown(frame) == true and fills or nil
	end
	for name, corner in pairs(win.corners) do
		local frame = GameFrame(name)
		local fills = frame and not ns.Forbidden(frame) and win.Fills(frame) or nil
		corner:SetShown(size and not fills)
	end
	win.CornerMouse()
	if win.drag and ((win.drag.mode == "move" and not drag) or (win.drag.mode == "size" and not size)) then
		win.EndDrag()
	end
	if not win.On() then
		return
	end
	win.Each(function(name)
		ns.EachPart(KEY, WIN.part, win.Grip, name)
	end)
	win.Looks()
end

-- Drag and size ------------------------------------------------------------------------------------

-- Starts a move or a size of a window at the cursor.
function win.Start(name, frame, mode)
	local x, y = win.Cursor()
	local left, bottom, width, height = Rect(frame)
	if not (x and left) then
		return
	end
	win.EndDrag()
	local info = BY_NAME[name] or { name = name, label = win.Label(name), kind = "window", point = "TOPLEFT" }
	local saved = Saved()
	local entry = saved and type(saved[name]) == "table" and saved[name] or nil
	local f = win.Factor(name, entry)
	win.drag = { name = name, info = info, mode = mode, x = x, y = y, from = { left = left, bottom = bottom }, left = left, bottom = bottom,
		width = width, height = height, factor = f, percent = math.floor(f * 100 + 0.5), top = bottom + height, w1 = width / f, h1 = height / f,
		grabX = x - (left + width), grabY = y - bottom, moved = false }
	if not win.carrier then
		win.carrier = CreateFrame("Frame")
		ns.Own[win.carrier] = true
	end
	win.carrier:SetScript("OnUpdate", win.Update)
end

-- Places the window where the cursor has taken it, or sizes it, a frame at a time. The spot is saved when the drag ends.
function win.Step()
	local drag = win.drag
	if not drag then
		return
	end
	local frame = GameFrame(drag.name)
	local x, y = win.Cursor()
	if not frame or ns.Forbidden(frame) or not x or win.ButtonUp() or IsShown(frame) ~= true then
		win.EndDrag()
		return
	end
	-- A window that goes to full size under the cursor is the game's: the drag ends and keeps the last small place.
	if win.Fills(frame) then
		win.EndDrag()
		return
	end
	-- A press that is not followed by a move is a click, for a size as for a move.
	local dx, dy = x - drag.x, y - drag.y
	if not drag.moved and math.abs(dx) < WIN.start and math.abs(dy) < WIN.start then
		return
	end
	if drag.mode == "move" then
		if win.Locked(frame, "move") then
			win.EndDrag()
			return
		end
		drag.moved = true
		drag.left, drag.bottom = drag.from.left + dx, drag.from.bottom + dy
		-- A window whose middle comes close to the middle of the screen snaps there, like a handle.
		local middle = centre.Snaps(drag.left, drag.width)
		drag.snapped = middle ~= nil
		drag.left = middle or drag.left
		local offsetX, offsetY = Offsets("TOPLEFT", drag.left, drag.bottom, drag.width, drag.height)
		if offsetX then
			Move(drag.name, frame, { point = "TOPLEFT", x = offsetX, y = offsetY, scale = drag.factor ~= 1 and drag.factor or nil })
		end
		centre.LineLook()
		return
	end
	-- The corner of the window follows the cursor along the diagonal, so the size is how far the corner is from the top left
	-- corner, across and down, as a share of the width and height at 100%.
	local cornerX, cornerY = x - drag.grabX, y - drag.grabY
	local raw = ((cornerX - drag.left) + (drag.top - cornerY)) / (drag.w1 + drag.h1)
	local percent = math.max(WIN.min, math.min(WIN.max, math.floor(raw * 100 / WIN.step + 0.5) * WIN.step))
	if percent == drag.percent then
		return
	end
	if win.Locked(frame, "size") then
		win.EndDrag()
		return
	end
	drag.percent, drag.moved = percent, true
	drag.width, drag.height = drag.w1 * percent / 100, drag.h1 * percent / 100
	drag.bottom = drag.top - drag.height
	local offsetX, offsetY = Offsets("TOPLEFT", drag.left, drag.bottom, drag.width, drag.height)
	if offsetX then
		Move(drag.name, frame, { point = "TOPLEFT", x = offsetX, y = offsetY, scale = percent / 100 })
	end
end

function win.Update()
	if not ns.EachPart(KEY, WIN.part, win.Step) then
		win.EndDrag()
	end
end

-- Ends the drag and saves the spot the window was left at, as the drop of a handle does. A size is saved in the spot or, under Every
-- window together, in the setting.
function win.EndDrag()
	local drag = win.drag
	if not drag then
		return
	end
	win.drag = nil
	if win.carrier then
		win.carrier:SetScript("OnUpdate", nil)
	end
	centre.LineLook()
	if not drag.moved then
		return
	end
	Commit(drag.name, drag.info, drag.left, drag.bottom, drag.width, drag.height, drag.snapped)
	if drag.mode == "size" then
		if win.Shared() then
			ns.Set("movers.windowSize", drag.percent)
		else
			local saved = Saved()
			local entry = saved and saved[drag.name]
			if type(entry) == "table" then
				entry.scale = drag.percent ~= 100 and drag.percent / 100 or nil
				Clean(entry)
				ns.Each(KEY, ApplyEntry, drag.name)
			end
		end
		ns.ResizeAll()
	end
	-- The first saved spot starts the check that keeps it.
	UpdateDriver()
end

-- A press on the title bar.
function win.TitleDown(name, button)
	if button ~= "LeftButton" then
		return
	end
	win.barUsed = true
	if not win.DragOn() then
		Grips()
		return
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) or win.Busy() or not win.KeyHeld() or win.Holding() then
		return
	end
	win.Start(name, frame, "move")
end

-- Letting go of the title bar ends the drag, and a right click puts the window back.
function win.TitleUp(name, button)
	if button == "LeftButton" then
		if win.drag and win.drag.name == name then
			win.EndDrag()
		end
	elseif button == "RightButton" and win.DragOn() then
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and not win.Locked(frame, "move") then
			ResetFrame(name)
		end
	end
end

-- A press on the corner grip.
function win.CornerDown(name, button)
	if button ~= "LeftButton" or not win.SizeOn() then
		return
	end
	local frame = GameFrame(name)
	if frame and not ns.Forbidden(frame) then
		win.Start(name, frame, "size")
	end
end

-- Puts a window back at 100%: its own size under Each window, the one size of every window under Every window together.
function win.Unsize(name)
	if win.Shared() then
		ns.Set("movers.windowSize", 100)
	else
		local saved = Saved()
		local entry = saved and saved[name]
		if type(entry) == "table" and entry.scale ~= nil then
			entry.scale = nil
			ns.Each(KEY, ApplyEntry, name)
		end
	end
	ns.ResizeAll()
end

function win.CornerUp(name, button)
	if button == "LeftButton" then
		if win.drag and win.drag.name == name then
			win.EndDrag()
		end
	elseif button == "RightButton" and win.SizeOn() then
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and not win.Locked(frame, "size") then
			win.Unsize(name)
		end
	end
end

-- A press the game reports. The window under the cursor is found from the frame the game says takes the click, and dragged when the
-- settings allow it and the press is on an empty part of the window. A press on a frame of the addon's is left to that frame's script.
-- A press in the corner of the window sizes it, and a right click there puts it at 100%, where the frame under the cursor is not a control.
function win.Pressed(button)
	if not win.On() then
		return
	end
	local leaf = win.Leaf()
	if not leaf or ns.Own[leaf] then
		return
	end
	-- The game says which frame takes a press, so the corner grips need no mouse of their own from here on.
	if not win.heard then
		win.heard = true
		win.CornerMouse()
	end
	if (button ~= "LeftButton" and button ~= "RightButton") or win.drag or win.Busy() or not (win.DragOn() or win.SizeOn()) then
		return
	end
	local nodes = ChainOf(leaf)
	if not nodes then
		return
	end
	local index, name, frame
	for i, node in ipairs(nodes) do
		local n = NameOf(node)
		if n and win.IsWindow(n) and GameFrame(n) == node then
			index, name, frame = i, n, node
			break
		end
	end
	if not frame then
		return
	end
	-- A window shown without an announcement has no grips yet.
	ns.EachPart(KEY, WIN.part, win.Grip, name)
	if not win.Gate(name, frame) then
		return
	end
	local x, y = win.Cursor()
	local zone = x and win.Zone(name, frame, x, y)
	if not zone then
		return
	end
	-- The grip is drawn where the player can see it, so a model or a frame with a script of its own under it gives way, as it does to a held key.
	if zone == "corner" and win.SizeOn() then
		local free, because = win.Free(nodes, index, frame, true)
		if not free then
			if button == "LeftButton" then
				win.last = { label = win.Label(name), reason = because }
			end
		elseif button == "LeftButton" then
			win.last = nil
			win.CornerDown(name, button)
		else
			win.CornerUp(name, button)
		end
		return
	elseif zone == "corner" then
		zone = "body"
	end
	if button ~= "LeftButton" or not win.DragOn() then
		return
	end
	local reason
	if zone == "body" and ns.Get("movers.dragFrom") ~= "anywhere" then
		reason = "outside the title bar"
	else
		local held, why = win.KeyHeld()
		if not held then
			reason = why
		elseif win.Holding() then
			reason = "the cursor holds something"
		else
			local free, because = win.Free(nodes, index, frame, ns.Get("movers.dragKey") ~= "none")
			if not free then
				reason = because
			end
		end
	end
	if reason then
		win.last = { label = win.Label(name), reason = reason }
		return
	end
	win.last = nil
	win.Start(name, frame, "move")
end

function win.Released(button)
	if button == "LeftButton" and win.drag then
		win.EndDrag()
	end
end

-- Sizes ------------------------------------------------------------------------------------------

-- Gives a window with no spot the one size of every window, or gives it back the size the game gave it. The scale changes and each
-- point is set again with its offsets times the old scale over the new one, so the corner the game anchored stays where it is
-- (EditModeSystemMixin:SetScaleOverride does the same). No spot is saved.
function win.SizeWindow(name, frame)
	local saved = Saved()
	-- A window being dragged is sized by the drag.
	if ns.Forbidden(frame) or (saved and type(saved[name]) == "table") or (win.drag and win.drag.name == name) then
		return
	end
	local own = original[frame]
	if own then
		win.Rebase(name, frame, own)
	end
	local f = win.Factor(name)
	if IsShown(frame) ~= true and not (own and own.scaled) then
		return
	end
	if f == 1 and not (own and own.scaled) then
		return
	end
	-- A window that fills the screen has the game's scale. A protected one keeps the size until combat ends.
	if win.Fills(frame) then
		if InCombatLockdown() and ns.MaybeProtected(frame) then
			win.Later(name, frame)
		else
			win.Unscale(frame)
		end
		return
	end
	if not win.Gate(name, frame) then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(frame) then
		if not win.sizeQueued then
			win.sizeQueued = true
			ns.OutOfCombat(function()
				win.sizeQueued = nil
				ns.Try(KEY, win.SizeOpen)
			end)
		end
		return
	end
	own = own or Capture(frame, BY_NAME[name])
	local wanted = (own.scale or 1) * f
	local okScale, current = pcall(frame.GetScale, frame)
	if not (okScale and Number(current)) then
		return
	end
	if math.abs(current - wanted) > 0.0005 then
		-- A scale other than the one set last was written by the game.
		if own.applied and math.abs(current - own.applied) > 0.0005 then
			win.resizes[name] = (win.resizes[name] or 0) + 1
		end
		if not win.Rescale(frame, current, wanted) then
			return
		end
	end
	own.scaled, own.applied = f ~= 1, wanted
end

-- Sizes every window the module knows: the shared size, or none.
function win.SizeOpen()
	win.Each(function(name)
		local frame = GameFrame(name)
		if frame then
			ns.Each(KEY, win.Watch, name, frame, true)
			ns.Each(KEY, win.SizeWindow, name, frame)
		end
	end)
end

-- True when a window with a spot has another scale than its spot and the size setting give it.
function win.Wrong(name, entry)
	local frame = GameFrame(name)
	if type(entry) ~= "table" or entry.kind ~= "window" or not frame or ns.Forbidden(frame) then
		return false
	end
	local own = original[frame]
	local ok, current = pcall(frame.GetScale, frame)
	return own ~= nil and (win.Factor(name, entry) ~= 1 or own.scaled == true) and ok and Number(current)
		and math.abs(current - (own.scale or 1) * win.Factor(name, entry)) > 0.0005
end

-- A window the panel manager fits to the screen: the game gives it scale 1 and then the scale that fits, when it opens, when its layout is
-- worked out again and when the UI scale changes (FrameUtil.lua:169-179, UIParentPanelManager.lua:245, :624, :148, :769-771). Legacy is one (checkFit,
-- Blizzard_LegacySystemRegistration.lua:8).
function win.Fitted(name)
	local list = win.Panels()
	local attributes = list and list[name]
	return type(attributes) == "table" and not ns.IsSecret(attributes) and attributes.checkFit == 1
end

-- The scale a fitted window is sized from is the one the game gave it last, so the size of every window is a factor of the fit and not of the
-- fit the window had when it was first seen (the fit depends on the size of UIParent, which changes). The game's scale is taken when a hook says the
-- game wrote it, or, for a window with no hook, when it is not the one set last. Any other window keeps the scale it had at first.
function win.Rebase(name, frame, own)
	local wrote = win.wrote[name]
	win.wrote[name] = nil
	if not (own and win.Fitted(name)) then
		return
	end
	local ok, current = pcall(frame.GetScale, frame)
	if not (ok and Number(current) and current > 0) then
		return
	end
	if wrote or (own.applied and math.abs(current - own.applied) > 0.0005) then
		if own.scaled then
			win.resizes[name] = (win.resizes[name] or 0) + 1
		end
		own.scale, own.scaled, own.applied = current, false, nil
	end
end

-- A window a hook has marked is sized on the next frame.
function win.Mark(name)
	win.marked[name] = true
	if win.sizer then
		win.sizer:SetScript("OnUpdate", win.Drain)
	end
end

-- A window with both hooks that is not sized in a fight is marked again when the fight is over. A window with no hooks is tried again by the
-- check at its next pass, so nothing is queued for it.
function win.Later(name, frame)
	if win.scaleHooked[frame] and win.showHooked[frame] and not win.fixQueued[name] then
		win.fixQueued[name] = true
		ns.OutOfCombat(function()
			win.fixQueued[name] = nil
			win.Mark(name)
		end)
	end
end

-- A window with a spot is put at the scale of its spot again when the game has sized it, not in a fight when it is protected.
function win.Fix(name, entry)
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) or win.Fills(frame) or IsShown(frame) ~= true then
		return
	end
	if InCombatLockdown() and ns.MaybeProtected(frame) then
		win.Later(name, frame)
		return
	end
	local own = original[frame]
	if own then
		win.Rebase(name, frame, own)
	end
	if win.Wrong(name, entry) then
		Correct(name)
	end
end

-- Sizes a window a hook has marked: the shared size, or the scale of its spot.
function win.Marked(name)
	if not (running and ns.Enabled(KEY)) then
		return
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) then
		return
	end
	local saved = Saved()
	local entry = saved and saved[name]
	if type(entry) == "table" and entry.kind == "window" then
		if ns.Get("movers.keep") and not stopped[name] then
			win.Fix(name, entry)
		end
	else
		win.SizeWindow(name, frame)
	end
end

-- The one hidden frame that sizes the windows the hooks have marked, on the frame after the mark. It runs only while a window is marked.
function win.Drain()
	win.sizer:SetScript("OnUpdate", nil)
	local names = win.marked
	win.marked = {}
	for name in pairs(names) do
		ns.Each(KEY, win.Marked, name)
	end
end

-- Hooks a window with SetScale, which marks it when the game writes its scale, and with OnShow, which marks it when it opens. SetWidth and SetSize are
-- never hooked: a hook on a size setter tainted the panel manager (EllesmereUI). The hooks only mark. True when the window has both and the hooks
-- will see what happens to it, false when it has not (it does not need them, they are refused while taintLog is on, or the client has no hooksecurefunc), and
-- then the half-second check covers it. A window that gets its hooks here is marked, with quiet it is not.
function win.Watch(name, frame, quiet)
	if not win.Sizing() then
		return false
	end
	if win.scaleHooked[frame] and win.showHooked[frame] then
		return true
	end
	if ns.Forbidden(frame) then
		return false
	end
	if not win.sizer then
		win.sizer = CreateFrame("Frame")
		ns.Own[win.sizer] = true
	end
	local fns = win.markers[name]
	if not fns then
		fns = {
			scale = function()
				if win.writing == 0 then
					win.wrote[name] = true
					win.Mark(name)
				end
			end,
			show = function()
				win.Mark(name)
			end,
		}
		win.markers[name] = fns
	end
	if not win.scaleHooked[frame] and ns.Follow(frame, "SetScale", fns.scale) == true then
		win.scaleHooked[frame] = true
	end
	if not win.showHooked[frame] and type(frame.HookScript) == "function" and pcall(frame.HookScript, frame, "OnShow", fns.show) then
		win.showHooked[frame] = true
	end
	if win.scaleHooked[frame] and win.showHooked[frame] then
		if not quiet then
			win.Mark(name)
		end
		return true
	end
	return false
end

-- The half-second check. A window with both hooks is sized by the frame that sizes what the hooks mark. The check hooks a window that has come into
-- being since (a window of a load-on-demand addon), and does the sizing of a window that has no hooks: one the hooks are refused on (taintLog on, no
-- hooksecurefunc), and any window whose frame does not exist yet. The hooks see a SetScale call and the opening of a window; a scale the game
-- changes by another call, such as SetScaleBase, or on a frame the addon may not hook, is only seen here.
function win.CheckSizes()
	if win.Sizing() then
		win.Each(function(name)
			local frame = GameFrame(name)
			if frame and not ns.Forbidden(frame) and not win.Watch(name, frame) then
				ns.Each(KEY, win.SizeWindow, name, frame)
			end
		end)
	end
	for name, entry in pairs(Saved() or {}) do
		if type(entry) == "table" and entry.kind == "window" and not stopped[name] then
			local frame = GameFrame(name)
			if frame and not ns.Forbidden(frame) and not win.Watch(name, frame) then
				win.Fix(name, entry)
			end
		end
	end
end

-- Closing a window drops its spot while the setting says so. The window may be closed by the panel manager or by a plain Hide.
function win.Closed(name)
	if not (win.On() and ns.Get("movers.keepSpots") == "reset") then
		return
	end
	local frame = GameFrame(name)
	if frame and IsShown(frame) ~= false then
		return
	end
	local saved = Saved()
	local entry = saved and saved[name]
	if type(entry) == "table" and entry.kind == "window" then
		ResetFrame(name)
	end
end

-- Drops the spot of every closed window while the setting says so.
function win.Sweep()
	if not (win.On() and ns.Get("movers.keepSpots") == "reset") then
		return
	end
	local names = {}
	for name, entry in pairs(Saved() or {}) do
		if type(entry) == "table" and entry.kind == "window" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		ns.Each(KEY, win.Closed, name)
	end
end

-- Puts every window back at its default place and size.
function win.Reset()
	local names = {}
	for name, entry in pairs(Saved() or {}) do
		if type(entry) == "table" and entry.kind == "window" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		ns.Each(KEY, ResetFrame, name)
	end
	ns.Set("movers.windowSize", 100)
	win.SizeOpen()
	ns.ResizeAll()
	print("Windows are back at their default place and size.")
	if InCombatLockdown() then
		print("Some windows go back after combat.")
	end
end

-- Opening and closing ----------------------------------------------------------------------------

local function BuildBar()
	bar = CreateFrame("Frame", nil, UIParent)
	ns.Own[bar] = true
	-- Above every handle, including the ones of windows that are at DIALOG and FULLSCREEN.
	bar:SetFrameStrata("FULLSCREEN_DIALOG")
	bar:SetFrameLevel(10)
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	bar:EnableMouse(true)
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		barMoved = true
	end)
	ns.KeepOutline(ns.Outline(bar, bar, true))
	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -10)
	title:SetText("Movers")
	local hint = Label(bar, "GameFontHighlightSmall", 416)
	hint:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -30)
	hint:SetText("Drag to move. Scroll or Shift and scroll to nudge. Ctrl and scroll to scale. Right-click to reset.")
	local edit = Label(bar, "GameFontDisableSmall", 416)
	edit:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
	edit:SetText(EVERY_FRAME)
	-- How to centre a handle, which follows the settings.
	centre.how = Label(bar, "GameFontDisableSmall", 416)
	centre.how:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -6)
	local pickButton = MakeButton(bar, "Pick a frame", 110, function()
		if pick.on then
			StopPick()
		else
			StartPick()
		end
	end)
	pickButton:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 12, 10)
	-- Reset all forgets every saved spot, so it asks for a second click.
	local resetButton = MakeButton(bar, "Reset all", 130, function(label)
		-- Without a timer the question could not end by itself, so the first click resets.
		if resetPending or not (C_Timer and C_Timer.After) then
			resetPending = nil
			label:SetText("Reset all")
			ns.Try(KEY, ResetAll)
			return
		end
		local mine = {}
		resetPending = mine
		label:SetText("Click again to reset")
		C_Timer.After(RESET_ASK, function()
			if resetPending == mine then
				resetPending = nil
				label:SetText("Reset all")
			end
		end)
	end)
	resetButton:SetPoint("LEFT", pickButton, "RIGHT", 8, 0)
	-- Centres the handles that are ticked. It is shown while the setting asks for the tick boxes.
	centre.button = MakeButton(bar, "Centre ticked", 82, function()
		ns.Try(KEY, centre.Everything)
	end)
	centre.button:SetPoint("LEFT", resetButton, "RIGHT", 8, 0)
	local doneButton = MakeButton(bar, "Done", 70, function()
		ns.Try(KEY, Close)
	end)
	doneButton:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -12, 10)
end

-- Edit Mode's own panel is at the top of the screen. The bar opens beside it when Edit Mode opens it and the
-- bar fits there, and at the bottom of the screen otherwise, until the player moves the bar.
local function PlaceBar(source)
	if barMoved then
		return
	end
	local manager = EditModeManagerFrame
	local left, bottom, width, height
	if source == "editmode" and manager ~= nil and not ns.Forbidden(manager) then
		left, bottom, width, height = Rect(manager)
	end
	local x = left and left + width + 10
	local screen = ScreenSize()
	bar:ClearAllPoints()
	if x and screen and x + BAR_WIDTH <= screen then
		bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, bottom + height)
	else
		bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 220)
	end
end

function Open(source)
	if open then
		return
	end
	if InCombatLockdown() then
		print("Movers open out of combat.")
		return
	end
	if not bar then
		BuildBar()
	end
	open, openedBy = true, source
	ForgetPlaced()
	ns.MoversMode.Opened(source)
	PlaceBar(source)
	bar:Show()
	ShowHandles()
	ns.MoversMode.Ready()
	centre.Panel()
	centre.LineLook()
	UpdateDriver()
end

function Close()
	if not open then
		return
	end
	-- A move that is under way ends here, so no handle or bar follows the mouse when it is shown again.
	if dragging and handles[dragging] then
		handles[dragging]:StopMovingOrSizing()
	end
	open, openedBy, dragging = false, nil, nil
	StopPick()
	if bar then
		bar:StopMovingOrSizing()
		bar:Hide()
	end
	for name in pairs(handles) do
		HideHandle(name)
	end
	centre.Closed()
	ns.MoversMode.Closed()
	UpdateDriver()
end

-- Callbacks of the game ----------------------------------------------------------------------------

-- What Edit Mode holds for a frame, as two texts: the place it gives it and its other settings. Nothing when the client will not say.
local function Layout(frame)
	local ok, place, settings = pcall(function()
		local info = frame.systemInfo
		local anchor = info.anchorInfo
		local list = info.settings
		if ns.IsSecret(info) or ns.IsSecret(anchor) or ns.IsSecret(list) or not Number(anchor.offsetX) or not Number(anchor.offsetY) then
			return nil
		end
		local parts = {}
		for _, setting in ipairs(list) do
			parts[#parts + 1] = ("%s=%s"):format(tostring(setting.setting), tostring(setting.value))
		end
		return table.concat({ tostring(info.isInDefaultPosition), tostring(anchor.point), tostring(anchor.relativeTo), tostring(anchor.relativePoint),
			("%.1f %.1f"):format(anchor.offsetX, anchor.offsetY) }, " "), table.concat(parts, " ")
	end)
	if ok and type(place) == "string" and type(settings) == "string" then
		return place, settings
	end
	return nil
end

-- The number of the layout Edit Mode has applied.
local function ActiveLayout()
	local manager = EditModeManagerFrame
	local ok, active = pcall(function()
		return not ns.Forbidden(manager) and manager.layoutInfo.activeLayout
	end)
	return ok and Number(active) and active or nil
end

-- What Edit Mode held for each frame with a saved spot when it opened, and which layout it had applied.
local entered

local function NoteLayouts()
	entered = nil
	if not (running and ns.Enabled(KEY)) then
		return
	end
	entered = { layout = ActiveLayout(), frames = {} }
	for name in pairs(Saved() or {}) do
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and BaseCalls(frame) and not hold.by[name] then
			local place, settings = Layout(frame)
			entered.frames[name] = place and { place = place, settings = settings } or nil
		end
	end
end

-- Edit Mode applies the layout again when it closes. A frame the player placed there keeps the place Edit Mode gives it, so its
-- saved spot is dropped. A frame whose other settings changed, such as its size, keeps the spot and takes the points and scale
-- the game gives it again. Another layout changes every frame, which says nothing about one.
local function KeepEditModeChanges()
	local was = entered
	entered = nil
	local saved = Saved()
	if not (was and saved and ns.Enabled(KEY)) or was.layout == nil or ActiveLayout() ~= was.layout then
		return
	end
	local labels = {}
	for name, before in pairs(was.frames) do
		local frame = GameFrame(name)
		local place, settings
		if frame and not ns.Forbidden(frame) then
			place, settings = Layout(frame)
		end
		if type(saved[name]) == "table" and place then
			if place ~= before.place then
				labels[#labels + 1] = Describe(name).label
				original[frame] = nil
				saved[name] = nil
				ns.MoversMode.Forget(name)
				ns.LayoutSpots.Forget(name)
				refused[name], stopped[name], corrections[name] = nil, nil, nil
				Uncount(name)
			elseif settings ~= before.settings then
				original[frame] = nil
			end
		end
	end
	if #labels > 0 then
		table.sort(labels)
		print(("Changed in Edit Mode, so the saved spot is dropped: %s."):format(table.concat(labels, ", ")))
		UpdateDriver()
	end
end

local function EditModeEntered()
	ForgetPlaced()
	ns.Try(KEY, NoteLayouts)
	if running and ns.Enabled(KEY) and ns.Get("movers.editMode") then
		ns.Try(KEY, Open, "editmode")
	end
end

local function EditModeExited()
	if not running then
		return
	end
	if openedBy == "editmode" then
		ns.Try(KEY, Close)
	end
	ns.Try(KEY, KeepEditModeChanges)
	ApplyAllLater()
end

-- The panel manager has finished when it announces a window, so the window is placed at once and never drawn in
-- the game's slot. Placed again next frame in case the game is not done. A window that has just opened gets its grips, and a
-- window that has closed loses its spot where the setting says so.
local function PanelChanged()
	if running and ns.Enabled(KEY) then
		ns.Try(KEY, win.Sweep)
		ns.Try(KEY, Grips)
		ns.Try(KEY, PlaceWindows)
		PlaceWindowsLater()
	end
end

-- Callbacks run when the game calls EventRegistry:TriggerEvent. The owner is the first argument.
local owner = {}

local function Watch()
	if watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	local ok, err = pcall(function()
		EventRegistry:RegisterCallback("EditMode.Enter", EditModeEntered, owner)
		EventRegistry:RegisterCallback("EditMode.Exit", EditModeExited, owner)
		-- The game's bottom bar pass is not watched while Flat UI leaves the bars alone: a callback there runs inside the game's own pass.
		if not ns.HandsOff() then
			EventRegistry:RegisterCallback("EditModeManager.UpdateBottomActionBarPositions", hold.Pass, owner)
		end
		EventRegistry:RegisterCallback("UIParentPanelManager.ShowUIPanel", PanelChanged, owner)
		EventRegistry:RegisterCallback("UIParentPanelManager.HideUIPanel", PanelChanged, owner)
		-- The map says it goes to full size or back before the game sizes and places it.
		EventRegistry:RegisterCallback("WorldMapMaximized", PanelChanged, owner)
		EventRegistry:RegisterCallback("WorldMapMinimized", PanelChanged, owner)
		-- Some windows are laid out again without an announcement, such as the right pane of the character window.
		if type(hooksecurefunc) == "function" and type(UpdateUIPanelPositions) == "function" then
			hooksecurefunc("UpdateUIPanelPositions", PanelChanged)
		end
		-- Bags are not panels: the game places them when one opens or closes.
		if type(hooksecurefunc) == "function" and type(UpdateContainerFrameAnchors) == "function" then
			hooksecurefunc("UpdateContainerFrameAnchors", PanelChanged)
		end
		-- The queue eye is put back by the calls that move it.
		hold.EyeHooks()
	end)
	if ok then
		watched = true
	else
		ns.Note(KEY, "Movers: Edit Mode and the window panels could not be watched. " .. tostring(err))
	end
end

local function OtherMover()
	for _, addon in ipairs(OTHER_MOVERS) do
		local loaded
		if C_AddOns and C_AddOns.IsAddOnLoaded then
			loaded = C_AddOns.IsAddOnLoaded(addon)
		elseif IsAddOnLoaded then
			loaded = IsAddOnLoaded(addon)
		end
		if loaded == true then
			return addon
		end
	end
	return nil
end

-- The module ---------------------------------------------------------------------------------------

-- Edit Mode starts a bar of the stacks at the top left corner. A spot saved there did not come from the player.
local function DropCorners()
	local saved = Saved()
	local corner = {}
	for name, entry in pairs(saved) do
		local info = BY_NAME[name]
		if info and info.stack and entry.point == "TOPLEFT" and math.abs(entry.x) <= TOLERANCE and math.abs(entry.y) <= TOLERANCE then
			corner[#corner + 1] = info.label
			saved[name] = nil
		end
	end
	if #corner > 0 then
		table.sort(corner)
		print(("Dropped the saved spot of %s: it was the top left corner of the screen."):format(table.concat(corner, ", ")))
	end
end

-- The profile in use has other spots. The frames that have a spot in it are placed by the refresh that follows.
function ns.SpotsChanged(was)
	if running then
		DropCorners()
		ns.Try(KEY, ResetAll, was)
		ns.MoversMode.ProfileChanged()
	end
end

local function Start()
	conflict = OtherMover()
	if conflict then
		ns.Note(KEY, ("Movers: %s is loaded, so frames are not moved."):format(conflict))
		return
	end
	DropCorners()
	running = true
	Watch()
	ApplyAll()
	UpdateDriver()
end

local function Refresh()
	if not running then
		return
	end
	if ns.Enabled(KEY) then
		if not ns.Get("movers.systems") then
			ReleaseSystems()
		end
		ApplyAll()
		ns.LayoutSpots.Recheck()
	else
		ns.MoversMode.Abandon()
		Close()
		RestoreAll()
	end
	Grips()
	win.Sweep()
	win.SizeOpen()
	centre.Refresh()
	UpdateDriver()
end

local function Resized()
	if running and ns.Enabled(KEY) then
		ApplyAll()
		ShowHandles()
		centre.LineLook()
		ns.MoversMode.Resized()
	end
end

-- Lines for /flatui status about the frames the check gave up on and the saved spots that are not used.
local function Status()
	local lines = {}
	if not (running and ns.Enabled(KEY)) then
		return lines
	end
	for name in pairs(stopped) do
		local info = Describe(name)
		lines[#lines + 1] = ("%s is moved by the game again and again, so it is left where the game puts it."):format(info and info.label or name)
	end
	for name in pairs(refused) do
		local info = Describe(name)
		if not hold.by[name] then
			lines[#lines + 1] = ("%s is placed by the game, so its saved spot is not used."):format(info and info.label or name)
		end
	end
	table.sort(lines)
	local unused = {}
	for name in pairs(Saved() or {}) do
		if hold.Off(name) then
			unused[#unused + 1] = Describe(name).label
		end
	end
	if #unused > 0 then
		table.sort(unused)
		lines[#lines + 1] = "Saved spots not used while Leave the game's action bars alone is on: " .. table.concat(unused, ", ")
	end
	local names = {}
	for name in pairs(win.why) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		lines[#lines + 1] = ("%s cannot be dragged: %s."):format(win.Label(name), win.why[name])
	end
	-- A title bar was pressed and the game has reported no press and no frame under the cursor, so the rest of the window cannot be found.
	if win.DragOn() and win.barUsed and not win.heard then
		lines[#lines + 1] = "No mouse press reported by the game, so windows drag by the title bar only."
	end
	-- The levels of the open windows go with the last click that started no drag, to show what lay over the window.
	if win.last then
		lines[#lines + 1] = ("Last click on %s started no drag: %s."):format(win.last.label, win.last.reason)
		names = {}
		for name in pairs(win.levels) do
			names[#names + 1] = name
		end
		if #names > 0 then
			table.sort(names)
			local parts = {}
			for _, name in ipairs(names) do
				local level = win.levels[name]
				parts[#parts + 1] = ("%s %d, title bar %d, corner %d"):format(win.Label(name), level[1], level[2], level[3])
			end
			lines[#lines + 1] = "Window levels: " .. table.concat(parts, "; ")
		end
	end
	if centre.fallback then
		lines[#lines + 1] = "Handles are moved by the game: the cursor was not readable." .. (centre.Snapping() and " A drop still snaps to the middle." or "")
	end
	names = {}
	for name, times in pairs(win.resizes) do
		if times >= MAX_CORRECTIONS then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		lines[#lines + 1] = ("%s: the game set its size again %d times."):format(win.Label(name), win.resizes[name])
	end
	for _, line in ipairs(ns.LayoutSpots.Status()) do
		lines[#lines + 1] = line
	end
	local savedSpots = Saved()
	if savedSpots and savedSpots[XP_NAME] and not hold.by[XP_NAME] and not (ns.XpOwn and ns.XpOwn()) and ns.LayoutSpots.Mode() == "preset" then
		lines[#lines + 1] = "Experience bar is put back by the game in fights. Copy the layout in Edit Mode to keep it."
	end
	return lines
end

-- Says why a command does nothing, or nil when the movers are on.
local function Unavailable()
	if conflict then
		return ("Movers are off while %s is loaded. A fixed tooltip stays at the bottom right."):format(conflict)
	elseif ns.IsStopped(KEY) then
		return "Movers stopped. /flatui status shows why."
	elseif not running or not ns.Enabled(KEY) then
		if ns.Enabled("tooltip") and ns.Get("tooltip.mode") == "fixed" then
			return "Movers are off in the options. A fixed tooltip stays at the bottom right."
		end
		return "Movers are off in the options."
	end
	return nil
end

-- The line of the Reset windows row and what choosing it does.
function ns.WindowResetLines()
	return { { 1, "Every window to its default place and size" } }
end

function ns.WindowsReset(id)
	if id ~= 1 then
		return
	end
	local why = Unavailable()
	if why then
		print(why)
	else
		ns.Try(KEY, win.Reset)
	end
end

-- What MoversMode.lua draws its toolbar, lists and inspector from. It holds no state of its own.
ns.MoverKit = {
	LIST = LIST, BY_NAME = BY_NAME, handles = handles, looks = handleLooks, Saved = Saved, Describe = Describe, Rect = Rect, ScreenSize = ScreenSize,
	Commit = Commit, ShowHandle = function(name) ShowHandle(name) end, Cursor = function() return win.Cursor() end,
	IsOpen = function() return open == true end, Close = function() Close() end,
	Centre = function(name) return centre.Do(name) end,
	-- The game's own frame, for a spot that is only known from the frame (a secret anchor makes its rectangle unreadable).
	Readable = function(name)
		local info = Describe(name)
		if not info then
			return false
		end
		if info.own then
			return true
		end
		local frame = GameFrame(name)
		return frame ~= nil and not ns.Forbidden(frame) and Rect(frame) ~= nil
	end,
	-- Puts the saved spot of a frame back as it was: nil forgets the spot.
	Restore = function(name, entry)
		local info = Describe(name, entry)
		local saved = Saved()
		if not (info and saved) then
			return
		end
		if entry == nil then
			if saved[name] ~= nil then
				ns.Each(KEY, ResetFrame, name)
			end
			return
		end
		local was = type(saved[name]) == "table" and saved[name].scale or nil
		saved[name] = Clean(entry)
		ns.Each(KEY, ApplyEntry, name)
		if was ~= entry.scale then
			ns.ResizeAll()
			ScaleRowMoved(name)
		end
		Changed(info)
		ShowHandle(name)
	end,
}

ns.Register(KEY, {
	label = "Movers",
	counted = "moved",
	Start = Start,
	Refresh = Refresh,
	Resized = Resized,
	Status = Status,
	events = {
		PLAYER_ENTERING_WORLD = ApplyAllLater,
		ADDON_LOADED = ApplyAllLater,
		-- Edit Mode lays its frames out again on these, so they are placed again once it is done.
		EDIT_MODE_LAYOUTS_UPDATED = function()
			ns.LayoutSpots.Updated()
			ApplyAllLater()
		end,
		PLAYER_SPECIALIZATION_CHANGED = ApplyAllLater,
		-- The map is the game's in the gamepad interface and is placed again when the player leaves it.
		INPUT_DEVICE_INTERFACE_TRANSITION = PanelChanged,
		-- The game reports every press of a mouse button; a window is found from the frame under the cursor.
		GLOBAL_MOUSE_DOWN = function(button)
			ns.EachPart(KEY, WIN.part, win.Pressed, button)
		end,
		GLOBAL_MOUSE_UP = function(button)
			ns.EachPart(KEY, WIN.part, win.Released, button)
		end,
		PLAYER_REGEN_DISABLED = function()
			win.toldMove, win.toldSize = false, false
			if open then
				-- The movers wait for the end of the fight and open again then, with what was done in them.
				ns.MoversMode.Pause()
				Close()
				print("Movers pause for combat.")
			end
		end,
		PLAYER_REGEN_ENABLED = function()
			hold.Pass()
			local again = ns.MoversMode.Resume()
			if again and not open then
				Open(again)
			end
			if win.waiting then
				win.waiting = false
				Grips()
			end
		end,
	},
	slash = {
		move = function(rest)
			-- The words may be separated by more than one space.
			rest = rest:match("^%s*(.-)%s*$"):gsub("%s+", " ")
			local why = Unavailable()
			if why then
				print(why)
			elseif rest:lower() == "reset windows" then
				win.Reset()
			elseif rest:lower() == "reset" then
				ResetAll()
			elseif open then
				Close()
			else
				Open("slash")
				if open and not win.toldHow then
					win.toldHow = true
					print(HOW)
				end
			end
		end,
		grab = function()
			local why = Unavailable()
			if why then
				print(why)
				return
			end
			Open("slash")
			if open and not pick.on then
				StartPick()
			end
		end,
	},
	help = {
		"/flatui move - show or hide the handles that move frames",
		"/flatui move reset - put every moved frame back where the game has it",
		"/flatui move reset windows - put every window back to its default place and size",
		"/flatui grab - pick the frame under the mouse and move it",
	},
})

-- /flatui status names a game bar this addon placed in this session, which a click on one of its buttons can be refused after.
ns.ClickPathReporter(function()
	local placed = {}
	for name in pairs(hold.off) do
		if counted[name] then
			placed[#placed + 1] = Describe(name).label
		end
	end
	if #placed > 0 then
		table.sort(placed)
		return "Click path: Flat UI placed " .. table.concat(placed, ", ") .. "."
	end
	return nil
end)
