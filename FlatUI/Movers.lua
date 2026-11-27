local _, ns = ...

local KEY = "movers"
local TOOLTIP = "FlatUITooltip"
local ROW = "FlatUICooldowns"
local KEEP_EVERY = 0.5
local HANDLES_EVERY = 0.25
local PICK_EVERY = 0.1
local TOLERANCE = 0.5
local MAX_CORRECTIONS = 10
local XP_NAME = "MainStatusTrackingBarContainer"
local CORRECTION_WINDOW = 60
local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 2, 0.05
local NOMINAL_WIDTH, NOMINAL_HEIGHT = 200, 40
local MIN_SIZE = 16
local KEEP_ON_SCREEN = 48
local BOX_LEVELS = 500
local MAX_DEPTH = 40
local RESET_ASK = 3
local BAR_WIDTH, BAR_HEIGHT = 440, 156
local WIN = { height = 22, right = 28, level = 2, start = 4, corner = 18, min = 60, max = 150, step = 5, hover = 0.1, part = "window titles",
	margin = 4, noMove = "This window cannot be moved in combat.", noSize = "This window cannot be sized in combat.",
	controls = { "Button", "EditBox", "Slider", "Model", "ModelScene", "ColorSelect", "SimpleHTML", "MessageFrame", "ScrollingMessageFrame", "MovieFrame", "Minimap" },
	loose = { Model = true, ModelScene = true },
	scripts = { "OnMouseDown", "OnMouseUp", "OnDragStart" },
	clear = { units = { "PlayerFrame", "TargetFrame" }, gap = 6, floor = 140 } }
local HOW = "Every frame can be moved here. Drag a handle or a window's title. Ctrl and scroll changes size. Right-click puts it back, Shift and right-click hides a HUD frame of the game. Drag the tab on a bar of a bar block to give it another place in the block, or to put it in another block."
local BAG_GRIP = { left = 44, level = 2 }
local centre = { snap = 8, size = 14, alpha = 0.6, snapped = 1, ticked = {}, rows = { [0] = "BOTTOM", [0.5] = "CENTER", [1] = "TOP" } }

local OTHER_MOVERS = { "MoveAny", "MoveAnything", "BlizzMove", "EditModeExpanded", "TweaksForever" }

local FRACTION = {
	TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local LIST = {
	{ name = "AlertFrame", label = "Alerts", point = "BOTTOM", kind = "hud", noScale = true },
	{ name = "UIErrorsFrame", label = "Error text", point = "TOP", kind = "hud" },
	{ name = "UIWidgetTopCenterContainerFrame", label = "Top widgets", point = "TOP", kind = "hud" },
	{ name = "ZoneTextFrame", label = "Zone text", point = "TOP", kind = "hud" },
	{ name = TOOLTIP, label = "Tooltip", point = "BOTTOMRIGHT", kind = "hud", own = true, noScale = true, width = 250, height = 150, x = -9, y = 85,
		gate = "TooltipSpotUsed" },
	{ name = ROW, label = "Cooldown icons", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0,
		row = "CooldownRow", changed = "CooldownsMoved" },
	{ name = "FlatUICooldowns2", label = "Cooldown icons: row 2", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0,
		row = "CooldownRow2", changed = "CooldownsMoved" },
	{ name = "FlatUICooldowns3", label = "Cooldown icons: row 3", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0,
		row = "CooldownRow3", changed = "CooldownsMoved" },
	{ name = "FlatUICooldowns4", label = "Cooldown icons: row 4", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0,
		row = "CooldownRow4", changed = "CooldownsMoved" },
	{ name = "FlatUIPulse", label = "Cooldown pulse", point = "CENTER", kind = "hud", own = true, noScale = true, width = 72, height = 72, x = 0, y = 0,
		gate = "PulseShown", changed = "PulseMoved" },
	{ name = "FlatUIPulse2", label = "Cooldown pulse, spot 2", point = "CENTER", kind = "hud", own = true, noScale = true, width = 72, height = 72, x = -120, y = 0,
		gate = "PulseShown2", changed = "PulseMoved" },
	{ name = "FlatUIPulse3", label = "Cooldown pulse, spot 3", point = "CENTER", kind = "hud", own = true, noScale = true, width = 72, height = 72, x = 120, y = 0,
		gate = "PulseShown3", changed = "PulseMoved" },
	{ name = "FlatUIProcArt", label = "Proc art", point = "CENTER", kind = "hud", own = true, noScale = true, width = 204.8, height = 204.8, x = 0, y = 0,
		gate = "ProcArtShown", changed = "ProcArtMoved" },
	{ name = "FlatUICombatSelf", label = "Combat text: you", point = "CENTER", kind = "hud", own = true, noScale = true, width = 160, height = 40, x = -170, y = -30,
		gate = "CombatOwnShown" },
	{ name = "FlatUICombatOut", label = "Combat text: your hits", point = "CENTER", kind = "hud", own = true, noScale = true, width = 160, height = 40, x = 170, y = -30,
		gate = "CombatOutShown" },
	{ name = "FlatUICombatCues", label = "Combat text: alerts", point = "CENTER", kind = "hud", own = true, noScale = true, width = 200, height = 170, x = 0, y = 100,
		gate = "CombatCuesShown", changed = "CombatCuesMoved" },
	{ name = "FlatUIBarBlock", label = "Action bar block", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "BarBlockRow", changed = "BarBlockMoved" },
	{ name = "FlatUIBarBlock2", label = "Action bar block 2", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "BarBlockRow2",
		changed = "BarBlockMoved2" },
	{ name = "FlatUIBarBlock3", label = "Action bar block 3", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "BarBlockRow3",
		changed = "BarBlockMoved3" },
	{ name = "FlatUIXpBar", label = "Experience bar", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "XpBarRow", changed = "XpBarMoved",
		follows = "XpBarFollows" },
	{ name = "FlatUITrackers", label = "Trackers", point = "CENTER", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "TrackerRow", changed = "TrackersMoved" },
	{ name = "FlatUIOwnBuffs", label = "Your buffs", point = "CENTER", kind = "hud", own = true, noScale = true, width = 120, height = 42, x = 0, y = -150,
		gate = "OwnBuffsOwnShown", changed = "OwnBuffsMoved" },
	{ name = "FlatUIDefensives", label = "Defensives on you", point = "CENTER", kind = "hud", own = true, noScale = true, width = 137, height = 48, x = 0, y = 180,
		gate = "DefensivesOwnShown", changed = "DefensivesMoved" },
	{ name = "FlatUIAbsorbs", label = "Absorb shields", point = "CENTER", kind = "hud", own = true, noScale = true, width = 180, height = 52, x = 0, y = -205,
		gate = "AbsorbsShown", changed = "AbsorbsMoved" },
	{ name = "FlatUIAbsorbsTarget", label = "Absorb shields: target", point = "CENTER", kind = "hud", own = true, noScale = true, width = 180, height = 16, x = 0, y = 140,
		gate = "AbsorbsTargetShown", changed = "AbsorbsMoved" },
	{ name = "FlatUICharges", label = "Charges", point = "CENTER", kind = "hud", own = true, noScale = true, width = 160, height = 90, x = 0, y = -100,
		gate = "ChargesShown", changed = "ChargesMoved" },
	{ name = "FlatUIPartyRaid", label = "Party cooldowns: raid group", point = "CENTER", kind = "hud", own = true, noScale = true, width = 220, height = 150, x = -420, y = 0,
		gate = "PartyRaidShown", changed = "PartyRaidMoved" },
	{ name = "FlatUIEnemyTarget", label = "Enemy cooldowns: target", point = "CENTER", kind = "hud", own = true, noScale = true, width = 200, height = 30, x = 0, y = 220,
		gate = "EnemyTargetBarShown", changed = "EnemyBarsMoved" },
	{ name = "FlatUIEnemyFocus", label = "Enemy cooldowns: focus", point = "CENTER", kind = "hud", own = true, noScale = true, width = 200, height = 30, x = 0, y = 180,
		gate = "EnemyFocusBarShown", changed = "EnemyBarsMoved" },
	{ name = "FlatUIGroupTools", label = "Group tools", point = "TOP", kind = "hud", own = true, noScale = true, width = 327, height = 24, x = 0, y = -100,
		gate = "GroupToolsShown", changed = "GroupToolsMoved" },
	{ name = "FlatUIPingBar", label = "Ping bar", point = "TOP", kind = "hud", own = true, noScale = true, width = 132, height = 24, x = 0, y = -130,
		gate = "PingBarShown", changed = "PingBarMoved" },
	{ name = "FlatUIConsumeBar", label = "Consumables bar", point = "BOTTOMLEFT", kind = "hud", own = true, noScale = true, width = 226, height = 36,
		x = 20, y = 280, gate = "ConsumeBarShown", changed = "ConsumeBarMoved" },
	{ name = "FlatUIReloadNotice", label = "Reload notice", point = "TOP", kind = "hud", own = true, noScale = true, width = 520, height = 52, x = 0, y = -40,
		gate = "ReloadNoticeShown", changed = "ReloadNoticeMoved" },
	{ name = "FlatUIUprankNotice", label = "New spell ranks line", point = "TOP", kind = "hud", own = true, noScale = true, width = 360, height = 30, x = 0, y = -186,
		gate = "ErrandsUprankShown", changed = "ErrandsUprankMoved" },
	{ name = "FlatUIThreat", label = "Threat list", point = "CENTER", kind = "hud", own = true, noScale = true, width = 188, height = 112, x = 420, y = 0,
		gate = "ThreatListShown", changed = "ThreatListMoved" },
	{ name = "FlatUIHealerMana", label = "Healer mana", point = "CENTER", kind = "hud", own = true, noScale = true, width = 158, height = 76, x = 420, y = -130,
		gate = "HealerManaShown", changed = "HealerManaMoved" },
	{ name = "FlatUILavaTimer", label = "Lava tick timer", point = "CENTER", kind = "hud", own = true, noScale = true, width = 160, height = 14, x = 0, y = -100,
		gate = "LavaTimerShown", changed = "LavaTimerMoved" },
	{ name = "FlatUILootRolls", label = "Loot rolls", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 277, height = 367, x = 0, y = 150,
		gate = "LootRollsShown", changed = "LootRollsMoved", start = "LootRollsStart" },
	{ name = "FlatUIBags", label = "Flat UI bags", point = "BOTTOMRIGHT", kind = "hud", own = true, noScale = true, width = 360, height = 260, x = -60, y = 110,
		gate = "BagsWindowShown", changed = "BagsWindowMoved", start = "BagsWindowStart" },
	{ name = "FlatUIBank", label = "Flat UI bank", point = "TOPLEFT", kind = "hud", own = true, noScale = true, width = 420, height = 300, x = 25, y = -110,
		gate = "BankWindowShown", changed = "BankWindowMoved" },
	{ name = "FlatUIPetTarget", label = "Pet target", point = "BOTTOM", kind = "hud", own = true, noScale = true, width = 120, height = 20, x = -246, y = 238,
		gate = "PetTargetShown", changed = "PetTargetMoved", widthOf = "PetTargetWidth", start = "PetTargetStart" },
	{ name = "FlatUIHitTable", label = "Hit table", point = "TOPLEFT", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "HitTableRow",
		changed = "HitTableMoved" },
	{ name = "FlatUIGear", label = "Gear comparison", point = "TOPLEFT", kind = "hud", own = true, noScale = true, width = 460, height = 420,
		sized = "gearWindow", minWidth = 380, minHeight = 220, x = 680, y = -120, gate = "GearWindowShown", changed = "GearWindowMoved" },
	{ name = "FlatUIGearSearch", label = "Item finder", point = "TOPLEFT", kind = "hud", own = true, noScale = true, width = 344, height = 540,
		sized = "gearFinder", x = 1144, y = -120, gate = "GearSearchShown", changed = "GearSearchMoved", start = "GearSearchStart" },
	{ name = "FlatUIGearButton", label = "Compare gear button", point = "TOPLEFT", kind = "hud", own = true, noScale = true, width = 112, height = 20,
		x = 485, y = -1, from = "CharacterFrame", gate = "GearButtonShown", changed = "GearButtonMoved", start = "GearButtonStart" },
	{ name = "FlatUITrinkets", label = "Trinket queue", point = "TOPLEFT", kind = "hud", own = true, noScale = true, width = 320, height = 404,
		x = 680, y = -120, gate = "TrinketWindowShown", changed = "TrinketWindowMoved", start = "TrinketWindowStart" },
	{ name = "FlatUIDataTop", label = "Top data panel", point = "TOP", kind = "hud", own = true, noScale = true, width = 0, height = 0, row = "DataPanelTopRow",
		changed = "DataPanelsMoved" },
	{ name = "FlatUIDataBottom", label = "Bottom data panel", point = "BOTTOMLEFT", kind = "hud", own = true, noScale = true, width = 0, height = 0,
		row = "DataPanelBottomRow", changed = "DataPanelsMoved" },
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
	{ name = "MultiCastActionBarFrame", label = "Totem bar", kind = "hud", system = true, stack = true },
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
local REFUSE_PATTERNS = { "^ContainerFrame%d+$", "^ChatFrame%d+$", "^StaticPopup%d+$", "^Boss%dTargetFrameSpellBar$", "^GroupLootFrame%d+$" }

local EVERY_FRAME = "Every frame can be moved here. A grey box moves with the frame it hangs from. A hidden frame the game has not placed yet has no box."
local BACK_IN_FIGHT = "moved back by the game in combat"

local original = setmetatable({}, { __mode = "k" })
local handles, handleTexts, handleLooks = {}, {}, {}
local placedBy = {}
local counted, queued, stopped, corrections, refused = {}, {}, {}, {}, {}
local clock = { keep = 0, handles = 0, pick = 0 }
local running, open, openedBy, conflict, dragging
local driver, bar, barMoved, resetPending
local pick = { steps = 0 }
local watched = false
local resettingAll, systemReset, barsLeft = false, false, false
local win = { grips = {}, corners = {}, art = {}, clocks = {}, levels = {}, why = {}, resizes = {}, heard = false, barUsed = false }
function win.Say(text)
	print("Flat UI: " .. tostring(text))
end
win.marked, win.wrote, win.markers, win.fixQueued, win.writing = {}, {}, {}, {}, 0
win.scaleHooked, win.showHooked, win.guards = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
win.bags = {}
for _, info in ipairs(LIST) do
	if info.grip == BAG_GRIP then
		win.bags[#win.bags + 1] = info.name
	end
end
local hold = { owners = {}, by = {}, state = {}, order = { "barblock", "blocks" } }
hold.off = { MainActionBar = true, MultiBarBottomLeft = true, MultiBarBottomRight = true, MultiBarRight = true, MultiBarLeft = true, MultiBar5 = true,
	MultiBar6 = true, MultiBar7 = true, StanceBar = true, PetActionBar = true, PossessActionBar = true, MultiCastActionBarFrame = true,
	MainStatusTrackingBarContainer = true, SecondaryStatusTrackingBarContainer = true,
	MicroMenuContainer = true, BagsBar = true, MainMenuBarVehicleLeaveButton = true }
hold.xp = { MainStatusTrackingBarContainer = true, SecondaryStatusTrackingBarContainer = true }
function hold.Off(name)
	if hold.off[name] ~= true then
		return false
	end
	if hold.xp[name] == true and ns.XpOwn ~= nil and ns.XpOwn() then
		return true
	end
	return ns.HandsOff() and not (ns.BarBlockHolds ~= nil and ns.BarBlockHolds(name) ~= nil)
end

function ns.MoverHandsOff(name)
	return hold.Off(name)
end

local function Number(value)
	return not ns.IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Soon(fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, fn)
	else
		fn()
	end
end

local function ForgetPlaced()
	placedBy = {}
end

local function KeyDown(fn)
	return type(fn) == "function" and fn() and true or false
end

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

local function BaseCalls(frame)
	local ok, setPoint, clear, setScale = pcall(function()
		return frame.SetPointBase, frame.ClearAllPointsBase, frame.SetScaleBase
	end)
	if ok and Callable(setPoint) and Callable(clear) and Callable(setScale) then
		return setPoint, clear, setScale
	end
	return nil
end

local function IsProtectedFrame(frame)
	local ok, protected = pcall(frame.IsProtected, frame)
	return ok and not ns.IsSecret(protected) and protected == true
end

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

local function LeftToEditMode(frame)
	return BaseCalls(frame) ~= nil and (ns.EditModeOpen() or not ns.Get("movers.systems"))
end

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

local function Parked(frame)
	local call = ns.BagsParked
	if type(call) ~= "function" then
		return false
	end
	local ok, parked = pcall(call, frame)
	return ok and parked == true
end

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

local function Ratio(frame)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if ok and okBase and Number(scale) and Number(base) and scale > 0 and base > 0 then
		return scale / base, base
	end
	return nil
end

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

local function Offsets(point, left, bottom, width, height)
	local sw, sh = ScreenSize()
	if not sw then
		return nil
	end
	local x, y = PointAt(point, left, bottom, width, height)
	local f = FRACTION[point]
	return x - sw * f[1], y - sh * f[2]
end

local function RectAt(point, x, y, width, height)
	local sw, sh = ScreenSize()
	if not sw then
		return nil
	end
	local f = FRACTION[point]
	return sw * f[1] + x - width * f[1], sh * f[2] + y - height * f[2], width, height
end

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

local function BoxSize(info)
	local width, height = info.width, info.height
	local widthOf = info.widthOf and ns[info.widthOf]
	if type(widthOf) == "function" then
		local ok, w = pcall(widthOf)
		if ok and Number(w) and w > 0 then
			width = w
		end
	end
	local character = info.sized and ns.Character and ns.Character()
	local kept = type(character) == "table" and character[info.sized] or nil
	if type(kept) ~= "table" or ns.IsSecret(kept) then
		return width, height
	end
	local w, h = kept.w or kept[1], kept.h or kept[2]
	if not (Number(w) and Number(h) and w > 0 and h > 0) then
		return width, height
	end
	local sw, sh = ScreenSize()
	if sw then
		w, h = math.min(w, sw), math.min(h, sh)
	end
	return math.max(info.minWidth or 0, w), math.max(info.minHeight or 0, h)
end

local function Size(frame)
	if frame then
		local _, _, width, height = Rect(frame)
		return width, height
	end
	return nil
end

function win.Carry(frame, point, x, y)
	local bag = false
	for _, name in ipairs(win.bags) do
		bag = bag or rawequal(GameFrame(name), frame)
	end
	local sw, sh = ScreenSize()
	local left, bottom, width, height = Rect(frame)
	local f = FRACTION[point]
	if not (bag and sw and left and f) then
		return x, y
	end
	local saved = Saved() or {}
	local carried, box, grew = { [frame] = true }, nil, true
	while grew do
		grew = false
		for _, name in ipairs(win.bags) do
			local other = GameFrame(name)
			if other and not carried[other] and not ns.Forbidden(other) and type(saved[name]) ~= "table" and hold.by[name] == nil
				and IsShown(other) == true then
				local ok, _, relativeTo = pcall(other.GetPoint, other, 1)
				if ok and not ns.IsSecret(relativeTo) and type(relativeTo) == "table" and carried[relativeTo] then
					carried[other], grew = true, true
					local l, b, w, h = Rect(other)
					if l then
						box = box or { l, b, l + w, b + h }
						box[1], box[2] = math.min(box[1], l), math.min(box[2], b)
						box[3], box[4] = math.max(box[3], l + w), math.max(box[4], b + h)
					end
				end
			end
		end
	end
	if not box then
		return x, y
	end
	local baseX, baseY = (sw - width) * f[1], (sh - height) * f[2]
	local fromLeft, toRight, fromBottom, toTop = box[1] - left, box[3] - left, box[2] - bottom, box[4] - bottom
	if toRight - fromLeft <= sw then
		x = math.max(-fromLeft - baseX, math.min(sw - toRight - baseX, x))
	end
	if toTop - fromBottom <= sh then
		y = math.max(-fromBottom - baseY, math.min(sh - toTop - baseY, y))
	end
	return OnScreen(point, x, y, width, height, frame)
end

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
ns.CleanSpot = Clean

local function Describe(name, entry)
	local listed = BY_NAME[name]
	if listed then
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

local function Origin(info)
	if not info.from then
		return 0, 0
	end
	local frame = GameFrame(info.from)
	local _, sh = ScreenSize()
	local left, bottom, _, height
	if frame and sh and not ns.Forbidden(frame) then
		left, bottom, _, height = Rect(frame)
	end
	if not left then
		return nil
	end
	return left, bottom + height - sh
end

local function StartsAt(info)
	local x, y = info.x, info.y
	local start = info.start and ns[info.start]
	if x and type(start) == "function" then
		local ok, sx, sy = pcall(start, x, y)
		if ok and Number(sx) and Number(sy) then
			x, y = sx, sy
		end
	end
	return info.point, x, y
end

function ns.MoverSpot(name, point)
	local info, f = BY_NAME[name], FRACTION[point]
	if not (info and info.own and f) then
		return nil
	end
	local saved = Saved()
	local entry = saved and Clean(saved[name])
	local left, bottom, width, height
	local boxWidth, boxHeight = BoxSize(info)
	local ox, oy = Origin(info)
	if not ox then
		return nil
	end
	if entry then
		local x, y = OnScreen(entry.point, entry.x + ox, entry.y + oy, boxWidth, boxHeight)
		left, bottom, width, height = RectAt(entry.point, x, y, boxWidth, boxHeight)
	elseif info.x then
		local from, x, y = StartsAt(info)
		left, bottom, width, height = RectAt(from, x + ox, y + oy, boxWidth, boxHeight)
	end
	if not left then
		return nil
	end
	return PointAt(point, left, bottom, width, height)
end

function ns.MoverSaved(name)
	local saved = Saved()
	return BY_NAME[name] ~= nil and saved ~= nil and Clean(saved[name]) ~= nil
end

function ns.MoverCentred(name, point)
	local info, f = BY_NAME[name], FRACTION[point]
	local saved = Saved()
	local entry = saved and Clean(saved[name])
	if info and info.own and f and entry and entry.x == 0 and FRACTION[entry.point][1] == 0.5 then
		return centre.rows[f[2]]
	end
	return nil
end

local Passes

local function AtPlaceholder(frame)
	local ok, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
	local okCount, count = pcall(frame.GetNumPoints, frame)
	return ok and okCount and Number(count) and count == 1 and not ns.IsSecret(point) and not ns.IsSecret(relativeTo) and not ns.IsSecret(relativePoint)
		and Number(x) and Number(y) and point == "TOPLEFT" and relativePoint == "TOPLEFT" and relativeTo == UIParent and x == 0 and y == 0
end

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
	if info and info.fills then
		local first = own.points[1]
		if #own.points ~= 1 or first[1] ~= "TOPLEFT" or first[2] ~= UIParent or first[3] ~= "TOPLEFT" then
			own.points = {}
		end
	end
	return own
end

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
	if not entry.held then
		local width, height = Size(frame)
		wantedX, wantedY = win.Carry(frame, entry.point, OnScreen(entry.point, entry.x, entry.y, width, height, frame))
	end
	return math.abs(x - wantedX / k) <= TOLERANCE and math.abs(y - wantedY / k) <= TOLERANCE
end

local function Move(name, frame, entry)
	local own = Capture(frame, BY_NAME[name])
	win.Rebase(name, frame, own)
	local setPoint, clear, setScale = Calls(frame)
	local info = BY_NAME[name]
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
			x, y = win.Carry(frame, entry.point, OnScreen(entry.point, entry.x, entry.y, width, height, frame))
		end
		clear(frame)
		setPoint(frame, entry.point, UIParent, entry.point, x / k, y / k)
	end
	if not counted[name] then
		counted[name] = true
		ns.Count(KEY)
	end
end

local function Restore(frame, own)
	local setPoint, clear = Calls(frame)
	if own.scaled and own.scale then
		win.GiveBack(frame, own.scale, #own.points == 0 and not win.Fills(frame))
	end
	original[frame] = nil
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
	local layout = KindOf(name, frame) == "layout"
	if (layout and InCombatLockdown()) or (not layout and (held and hold.Blocked(frame) or (not held and InCombatLockdown() and ns.MaybeProtected(frame)))) then
		if held then
			hold.state[name] = "waiting"
		end
		Queue(name)
		return
	end
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

local function RestoreFrame(name, letGo)
	local frame = GameFrame(name)
	local info = BY_NAME[name]
	if (hold.Off(name) and not letGo) or not (frame and not ns.Forbidden(frame)) then
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
		win.Say("Bars " .. BARS_STAY)
	end
end

local function Uncount(name)
	if counted[name] then
		counted[name] = nil
		ns.Count(KEY, -1)
	end
end

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
		win.Say("Bars " .. BARS_STAY)
	end
end

local function Correct(name, hooked)
	if win.drag and win.drag.name == name then
		return
	end
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
	local saved = Saved()
	if win.Wrong(name, saved and saved[name]) then
		win.resizes[name] = (win.resizes[name] or 0) + 1
	end
	ns.Each(KEY, ApplyEntry, name)
end

function hold.Scaled(name, frame, entry)
	local own, info = original[frame], BY_NAME[name]
	if entry.scale == nil or not own or not own.scale or (info and info.ownScale) or KindOf(name, frame) ~= "layout" then
		return false
	end
	local ok, current = pcall(frame.GetScale, frame)
	return ok and Number(current) and math.abs(current - own.scale * entry.scale) > 0.0005
end

function hold.Check(name, entry, hooked)
	local info = BY_NAME[name]
	if not stopped[name] and not (info and info.own) and not hold.Off(name) and type(entry) == "table" then
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and win.Fills(frame) then
			frame = nil
		end
		if frame and not ns.Forbidden(frame) and not LeftToEditMode(frame) and IsShown(frame) ~= false and (not InPlace(frame, entry) or hold.Scaled(name, frame, entry))
			and not Unmovable(name, frame) then
			if InCombatLockdown() and KindOf(name, frame) == "layout" then
				if entry.held then
					hold.state[name] = "waiting"
				end
			elseif hold.passing and info and info.stack then
				return
			elseif not (entry.held and hold.Blocked(frame) or (not entry.held and InCombatLockdown() and ns.MaybeProtected(frame))) then
				Correct(name, hooked)
			end
		end
	end
end

hold.eye = { name = "QueueStatusButton", hooked = false }

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
	ns.EachPart(KEY, WIN.part, win.ClearUnits)
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

local function Released(frame)
	local ok, over = pcall(frame.IsMouseOver, frame)
	return not ok or ns.IsSecret(over) or over ~= false
end

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

local function Offstage(name, info, frame)
	if not info.system or info.keptHidden then
		return false
	end
	local saved = Saved()
	return IsShown(frame) ~= true and not (saved and type(saved[name]) == "table") and (info.stack == true or AtPlaceholder(frame))
end

local function HandleRect(name, info)
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
		local point, x, y
		local width, height = BoxSize(info)
		local ox, oy = Origin(info)
		if not ox then
			return nil
		end
		if entry then
			point, x, y = entry.point, OnScreen(entry.point, entry.x + ox, entry.y + oy, width, height)
		else
			point, x, y = StartsAt(info)
			if x then
				x, y = x + ox, y + oy
			end
		end
		return RectAt(point, x, y, width, height)
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) then
		return nil
	end
	if info.kind == "window" and (IsShown(frame) ~= true or Parked(frame)) then
		return nil
	end
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
	if info.system then
		return nil
	end
	return RectAt(point, 0, 0, NOMINAL_WIDTH, NOMINAL_HEIGHT)
end

local function PlacedByGame(name, info)
	if info.follows then
		local call = ns[info.follows]
		local ok, what = false, nil
		if type(call) == "function" then
			ok, what = pcall(call)
		end
		if ok and type(what) == "string" and what ~= "" then
			return true, what
		end
		return false
	end
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

function hold.Blocked(frame)
	return InCombatLockdown() and ns.MaybeProtected(frame)
end

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
			if saved and type(saved[name]) == "table" and not hold.Off(name) then
				ns.Each(KEY, ApplyEntry, name)
			else
				local restored, released = RestoreFrame(name, true)
				if restored ~= nil and not released and BY_NAME[name].stack then
					left = true
				end
				Uncount(name)
			end
		end
	end
	if left then
		win.Say("Bars " .. BARS_STAY)
	end
	UpdateDriver()
end

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

function ns.MoverShown(frame)
	return IsShown(frame)
end

function ns.MoverLabel(name)
	local info = BY_NAME[name]
	return info and info.label or nil
end

function ns.MoverRect(frame)
	return Rect(frame)
end

function ns.MoverHoldGates()
	return ns.Enabled(KEY) and running == true, ns.Get("movers.systems") == true, ns.Get("movers.keep") == true
end

local function Changed(info)
	local call = info.own and info.changed and ns[info.changed]
	if type(call) == "function" then
		call()
	end
	ns.MoversMode.Changed(info.name)
end

local function Commit(name, info, left, bottom, width, height, centred)
	local saved = Saved()
	local ox, oy = Origin(info)
	if not (saved and ox) then
		return
	end
	if info.from then
		centred = nil
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
		local _, _, _, _, shiftX, shiftY = RowBox(info)
		if not shiftX then
			return
		end
		x, y = x + shiftX, y + shiftY
	else
		local frameWidth, frameHeight = Size(frame)
		x, y = OnScreen(point, x, y, frameWidth or width, frameHeight or height, frame)
	end
	x, y = x - ox, y - oy
	saved[name] = Clean({ point = point, x = x, y = y, scale = previous and previous.scale, kind = info.kind or "hud",
		label = not BY_NAME[name] and info.label or nil })
	ns.Each(KEY, ApplyEntry, name)
	Changed(info)
	return true
end

local function Ensure(name, info)
	local saved = Saved()
	if not saved then
		return nil
	end
	if type(saved[name]) ~= "table" and handles[name] then
		local left, bottom, width, height = Rect(handles[name])
		if left then
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
			local middle = centre.dropMiddle
			if middle == nil then
				middle = centre.Snaps(left, width) ~= nil
				left = centre.Snaps(left, width) or left
				left, bottom = ns.MoversSnap.Snap(name, left, bottom, width, height, middle)
			end
			centre.dropMiddle = nil
			ns.MoversMode.Drop(name, info, left, bottom, width, height, middle)
		end
	end
	dragging = nil
	ns.MoversSnap.Hide()
	centre.LineLook()
	ShowHandle(name)
end

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
	if not info or (scaling and info.noScale) then
		return
	end
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
		if info.kind == "window" then
			entry.scale = math.max(WIN.min / 100, math.min(WIN.max / 100, entry.scale))
		end
	else
		local step = ns.Pixels(UIParent, 1)
		local width, height = Size(handles[name])
		local ox, oy = Origin(info)
		if not ox then
			ShowHandle(name)
			return
		end
		local x, y = OnScreen(entry.point, entry.x + ox, entry.y + oy, width, height)
		if KeyDown(IsShiftKeyDown) then
			entry.x = OnScreen(entry.point, x + (delta > 0 and step or -step), y, width, height) - ox
		else
			entry.y = select(2, OnScreen(entry.point, x, y + (delta > 0 and step or -step), width, height)) - oy
		end
	end
	Clean(entry)
	ns.Each(KEY, ApplyEntry, name)
	Changed(info)
	if entry.scale ~= was then
		ns.ResizeAll()
		if scaling then
			ScaleRowMoved(name)
		end
	end
	ShowHandle(name)
end

function ns.MoverScale(def)
	local saved = Saved()
	local entry = saved and type(def) == "table" and saved[def.frame]
	local info = entry and Describe(def.frame)
	if not ns.Get("movers.enabled") or (info and info.system and not ns.Get("movers.systems")) then
		return 100
	end
	if type(entry) == "table" and Number(entry.scale) then
		return math.floor(entry.scale * 100 + 0.5)
	end
	return 100
end

function ns.SetMoverScale(def, percent)
	local name = type(def) == "table" and def.frame
	local info = name and Describe(name)
	if not info or info.noScale or not Number(percent) then
		return
	end
	local function Refuse(text)
		local now = GetTime and GetTime() or 0
		if not ns.moverTold or now - ns.moverTold >= 0.5 then
			win.Say(text)
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
	ns.MoversMode.Style(name, handle, outline, text)
	handle:SetScript("OnDragStart", function(self)
		if not InCombatLockdown() then
			dragging = name
			handleLooks[name].left = nil
			handleLooks[name].dragged = true
			ns.Try(KEY, ns.MoversMode.Lift, name)
			ns.Try(KEY, centre.Start, self)
		end
	end)
	handle:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		centre.Stop(self)
		if open and dragging == name then
			ns.Try(KEY, Dropped, name)
		end
	end)
	handle:SetScript("OnMouseWheel", function(_, delta)
		ns.Try(KEY, Wheel, name, delta)
	end)
	handle:SetScript("OnMouseDown", function(_, button)
		handleLooks[name].dragged = false
		handleLooks[name].right = button == "RightButton"
		ns.Try(KEY, ns.MoversMode.Press, name, button)
	end)
	handle:SetScript("OnMouseUp", function(self, mouseButton)
		local right = handleLooks[name].right
		handleLooks[name].right = false
		if mouseButton == "RightButton" and not (right and Released(self)) then
			return
		end
		local shift = mouseButton == "RightButton" and type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
		local hide = shift and ns.HideFrames and ns.HideFrames.Key(name)
		if hide then
			ns.Try(KEY, ns.HideFrames.Toggle, hide)
			ns.Try(KEY, ShowHandle, name)
			ns.Try(KEY, ns.MoversMode.Layout)
			ns.Try(KEY, ns.MoversMode.Refresh, true)
		elseif shift then
			local info = Describe(name)
			print(("Flat UI: %s cannot be hidden. The Hidden frames page has the game's HUD frames."):format(info and info.label or name))
		elseif mouseButton == "RightButton" then
			ns.Try(KEY, ResetFrame, name)
		elseif mouseButton == "LeftButton" then
			ns.Try(KEY, ns.MoversMode.Let, name, handleLooks[name].dragged)
			ns.Try(KEY, centre.Click, name)
		end
	end)
	return handle
end

function ShowHandle(name)
	local info = Describe(name)
	local handle = handles[name]
	if dragging == name or ns.MoversMode.Carried(name) then
		return
	end
	local left, bottom, width, height
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
	local placedByGame, follows = PlacedByGame(name, info)
	if look.placedByGame ~= placedByGame then
		look.placedByGame = placedByGame
		ns.MoversMode.Paint(name)
	end
	SetMouse(name)
	local text = info.label
	if follows then
		text = ("%s (follows %s)"):format(text, follows)
	elseif placedByGame then
		text = ("%s (placed by the game)"):format(text)
	else
		if percent then
			text = ("%s %d%%"):format(text, percent)
		end
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and KindOf(name, frame) == "layout" and ns.LayoutSpots.Mode() ~= "layout" then
			text = ("%s (%s)"):format(text, BACK_IN_FIGHT)
		end
	end
	local hidden = ns.HideFrames and ns.HideFrames.Key(name)
	local frameOf = ns.HideFrames and not (hidden and ns.HideFrames.Hidden(hidden)) and GameFrame(name)
	local by = frameOf and ns.HideFrames.HeldBy(frameOf)
	if hidden and ns.HideFrames.Hidden(hidden) then
		text = ("%s (hidden)"):format(text)
	elseif by == hidden and by then
		text = ("%s (hidden until a reload)"):format(text)
	elseif by then
		text = ("%s (hidden with %s)"):format(text, ns.HideFrames.Label(by))
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
	if ns.BarBlockGrips then
		ns.Try(KEY, ns.BarBlockGrips, true)
	end
end

function ns.MoverRelabel()
	ShowHandles()
end

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
	if frame and win.IsWindow(name) then
		ns.Each(KEY, win.SizeWindow, name, frame)
		PlaceWindowsLater()
	end
	if moved and released then
		if not resettingAll then
			win.Say(("%s goes back to Edit Mode's spot after a reload."):format(info.label))
		end
	elseif moved and info.stack and restored ~= nil then
		barsLeft = true
		if not resettingAll then
			win.Say(("%s stays where it is until the game places it again at its next layout or after /reload."):format(info.label))
		end
	elseif moved and restored == false and info.kind ~= "window" then
		win.Say(("%s goes back to its place after /reload."):format(info.label))
	elseif moved and restored and info.system then
		systemReset = laidOut and "layout" or systemReset or "system"
		if not resettingAll then
			win.Say(laidOut and ("%s is back where it was. The game places it again at the next layout or after /reload."):format(info.label)
				or ("%s is back where it was, and /reload gives it back to Edit Mode fully."):format(info.label))
		end
	end
	ShowHandle(name)
	UpdateDriver()
end

local function ResetAll(was)
	local saved = Saved()
	local names = {}
	for name in pairs(was or saved) do
		if not (was and saved[name]) and not hold.by[name] then
			names[#names + 1] = name
		end
	end
	resettingAll, systemReset, barsLeft = true, false, false
	if not was then
		ns.MoversMode.Group(true)
	end
	for _, name in ipairs(names) do
		ns.Each(KEY, ResetFrame, name, was and was[name])
	end
	resettingAll = false
	if not was then
		ns.MoversMode.Group(false)
		ns.Try(KEY, ns.MoversMode.Refresh, true)
	end
	if barsLeft then
		win.Say((was and "Bars " or "Moved frames are back where the game has them, but bars ") .. BARS_STAY)
	elseif not was then
		win.Say("Moved frames are back where the game has them.")
	end
	if systemReset == "layout" then
		win.Say("The game places the frames it lays out again at the next layout or after /reload.")
	elseif systemReset then
		win.Say("/reload gives the game's own frames back to Edit Mode fully.")
	end
end

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

function centre.Snaps(left, width)
	local wide = ScreenSize()
	if wide and centre.Snapping() and math.abs(left + width / 2 - wide / 2) <= centre.snap then
		return (wide - width) / 2
	end
	return nil
end

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
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	local r, g, b = ns.PanelLook.Colour("accent")
	texture:SetColorTexture(r, g, b, 1)
	centre.line = line
	return line
end

function centre.LineLook()
	local mode = ns.Get("movers.middleLine")
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
	left, bottom = ns.MoversMode.Carry(dragging, left, bottom)
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

function centre.Do(name)
	local info, look = Describe(name), handleLooks[name]
	local wide = ScreenSize()
	if not (info and look and look.shown and not look.placedByGame and wide and look.width) then
		return false
	end
	local done = Commit(name, info, (wide - look.width) / 2, look.bottom, look.width, look.height, true)
	ShowHandle(name)
	return done == true
end

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

function centre.Everything()
	local names = {}
	for name in pairs(centre.ticked) do
		names[#names + 1] = name
	end
	table.sort(names)
	if #names == 0 then
		win.Say("No handle is ticked. Tick the box on each handle, then press Centre ticked.")
		return
	end
	local done = 0
	ns.MoversMode.Group(true)
	for _, name in ipairs(names) do
		centre.ticked[name] = nil
		if ns.Try(KEY, centre.Do, name) == true then
			done = done + 1
		end
		ns.Try(KEY, centre.Look, name)
	end
	ns.MoversMode.Group(false)
	ns.Try(KEY, ns.MoversMode.Refresh, true)
	if done == 0 then
		win.Say("Nothing was centred: the ticked handles are hidden or placed by the game.")
	else
		win.Say(("%d %s centred."):format(done, done == 1 and "handle" or "handles"))
	end
end

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

function centre.Shift(look)
	local wide = ScreenSize()
	if not (wide and look.left) then
		return 0
	end
	local reach, middle = centre.size + 1, look.left + look.width / 2
	return math.max(0, reach - middle) - math.max(0, middle - (wide - reach))
end

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

function centre.Picture(square, width, height)
	local bar = square:CreateTexture(nil, "OVERLAY", nil, 0)
	ns.Own[bar] = true
	bar:SetColorTexture(1, 1, 1, 0.9)
	bar:SetSize(width, height)
	return bar
end

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

function centre.Mouse(look, wanted)
	if look.button then
		look.button:EnableMouse(wanted)
	end
	if look.box then
		look.box:EnableMouse(wanted)
	end
end

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

function centre.Refresh()
	centre.Panel()
	centre.LineLook()
	if open then
		ShowHandles()
	end
end

function centre.Closed()
	local drag = centre.drag
	if drag then
		centre.Stop(drag.handle)
	end
	centre.ticked = {}
	centre.Refresh()
end

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

local tag, tagText, box, boxOutline

local function Refused(name)
	if REFUSE[name] or hold.Off(name) then
		return true
	end
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

local function IsSystem(node)
	local ok, found = pcall(function()
		return node.system ~= nil or node.SetPointBase ~= nil
	end)
	return ok and found == true
end

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

local function SetUp(frame)
	local ok, flag = pcall(function()
		return frame.systemInfo.isInDefaultPosition
	end)
	return ok and not ns.IsSecret(flag) and type(flag) == "boolean"
end

function Passes(info, frame)
	return (info ~= nil and info.stack == true) or IsLaidOut(frame)
end

local function Placeable(info, frame)
	return BaseCalls(frame) ~= nil and SetUp(frame)
end

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
	local okProtected, _, explicit = pcall(node.IsProtected, node)
	if not (Answered(okProtected, explicit) or BaseCalls(node)) then
		return false
	end
	local okCount, count = pcall(node.GetNumPoints, node)
	return okCount and Number(count) and count == 1
end

local function SetMouseAll()
	for name in pairs(handles) do
		SetMouse(name)
	end
end

function pick.Label(on)
	local label = pick.label
	if not label then
		return
	end
	label:SetText(on and "Stop picking" or "Pick a frame")
	pcall(function()
		label:SetTextColor(ns.PanelLook.Colour(on and "accent" or "text"))
	end)
end

local function StopPick()
	pick.on = false
	pick.leaf, pick.cands, pick.edit, pick.chosen = nil, nil, nil, nil
	pick.Label(false)
	SetMouseAll()
	if tag then
		tag:Hide()
	end
	if box then
		box:Hide()
	end
end

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
	win.Say(("%s can be moved now."):format(name))
end

local keys = { shift = false, alt = false }

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
	pick.Label(true)
	SetMouseAll()
	keys.shift, keys.alt = KeyDown(IsShiftKeyDown), KeyDown(IsAltKeyDown)
	tag:Show()
	win.Say("Point at a frame and press Alt to take it. Shift picks the frame around it.")
end

local Grips

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

function win.Panels()
	local list = UIPanelWindows
	if not ns.IsSecret(list) and type(list) == "table" then
		return list
	end
	return nil
end

function win.Whole(attributes)
	return not ns.IsSecret(attributes) and type(attributes) == "table" and attributes.area == "full"
end

function win.IsWindow(name)
	local info = BY_NAME[name]
	if info then
		return info.kind == "window"
	end
	local list = win.Panels()
	local attributes = list and list[name]
	return attributes ~= nil and not win.Whole(attributes)
end

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

function win.Entry(name, entry)
	if type(entry) ~= "table" or entry.kind ~= "window" or not win.Shared() then
		return entry
	end
	local f = win.Factor(name, entry)
	return { point = entry.point, x = entry.x, y = entry.y, scale = f ~= 1 and f or nil }
end

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

function win.GiveBack(frame, scale, keepCorner)
	local name = keepCorner and NameOf(frame)
	local ok, current = pcall(frame.GetScale, frame)
	if not (name and win.IsWindow(name) and ok and Number(current) and win.Rescale(frame, current, scale)) then
		local _, _, setScale = Calls(frame)
		setScale(frame, scale)
	end
end

function win.Unscale(frame)
	local own = original[frame]
	if own and own.scaled then
		win.GiveBack(frame, own.scale or 1, true)
		own.scaled, own.applied = false, nil
	end
end

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

function win.Locked(frame, mode)
	if not (InCombatLockdown() and ns.MaybeProtected(frame)) then
		return false
	end
	if mode == "size" then
		if not win.toldSize then
			win.toldSize = true
			win.Say(WIN.noSize)
		end
	elseif not win.toldMove then
		win.toldMove = true
		win.Say(WIN.noMove)
	end
	return true
end

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

function win.Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return not ok or ns.IsSecret(kind) or kind ~= nil
end

function win.Busy()
	return pick.on == true or ns.EditModeOpen()
end

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

function win.MakeCorner(name, frame)
	local corner = CreateFrame("Frame", nil, frame)
	ns.Own[corner] = true
	win.corners[name] = corner
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

function win.Grip(name)
	if win.grips[name] then
		return
	end
	local frame = GameFrame(name)
	if not frame or ns.Forbidden(frame) then
		return
	end
	if IsShown(frame) ~= true or Parked(frame) then
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
	win.grips[name]:SetShown(win.DragOn())
	win.corners[name]:SetShown(win.SizeOn())
end

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

function Grips()
	local drag, size = win.DragOn(), win.SizeOn()
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
	if win.Fills(frame) then
		win.EndDrag()
		return
	end
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
	UpdateDriver()
end

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

function win.CornerDown(name, button)
	if button ~= "LeftButton" or not win.SizeOn() then
		return
	end
	local frame = GameFrame(name)
	if frame and not ns.Forbidden(frame) then
		win.Start(name, frame, "size")
	end
end

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

function win.Pressed(button)
	if not win.On() then
		return
	end
	local leaf = win.Leaf()
	if not leaf or ns.Own[leaf] then
		return
	end
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
	ns.EachPart(KEY, WIN.part, win.Grip, name)
	if not win.Gate(name, frame) then
		return
	end
	local x, y = win.Cursor()
	local zone = x and win.Zone(name, frame, x, y)
	if not zone then
		return
	end
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

function win.SizeWindow(name, frame)
	local saved = Saved()
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
		if own.applied and math.abs(current - own.applied) > 0.0005 then
			win.resizes[name] = (win.resizes[name] or 0) + 1
		end
		if not win.Rescale(frame, current, wanted) then
			return
		end
	end
	own.scaled, own.applied = f ~= 1, wanted
end

function win.SizeOpen()
	win.Each(function(name)
		local frame = GameFrame(name)
		if frame then
			ns.Each(KEY, win.Watch, name, frame, true)
			ns.Each(KEY, win.SizeWindow, name, frame)
		end
	end)
end

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

function win.Fitted(name)
	local list = win.Panels()
	local attributes = list and list[name]
	return type(attributes) == "table" and not ns.IsSecret(attributes) and attributes.checkFit == 1
end

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

function win.Mark(name)
	win.marked[name] = true
	if win.sizer then
		win.sizer:SetScript("OnUpdate", win.Drain)
	end
end

function win.Later(name, frame)
	if win.scaleHooked[frame] and win.showHooked[frame] and not win.fixQueued[name] then
		win.fixQueued[name] = true
		ns.OutOfCombat(function()
			win.fixQueued[name] = nil
			win.Mark(name)
		end)
	end
end

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

function win.Drain()
	win.sizer:SetScript("OnUpdate", nil)
	local names = win.marked
	win.marked = {}
	for name in pairs(names) do
		ns.Each(KEY, win.Marked, name)
	end
end

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
	win.Say("Windows are back at their default place and size.")
	if InCombatLockdown() then
		win.Say("Some windows go back after combat.")
	end
end

function win.Hung(frame)
	local okCount, count = pcall(frame.GetNumPoints, frame)
	if not (okCount and Number(count) and count == 1) then
		return false
	end
	local ok, point, relativeTo, relativePoint = pcall(frame.GetPoint, frame, 1)
	if not ok or ns.IsSecret(point) or ns.IsSecret(relativeTo) or ns.IsSecret(relativePoint) then
		return false
	end
	return (point == "TOPLEFT" or point == "TOP") and relativePoint == point and (relativeTo == nil or relativeTo == UIParent)
end

function win.Drawn(frame)
	local ok, visible = pcall(frame.IsVisible, frame)
	return ok and not ns.IsSecret(visible) and visible == true
end

function win.UnitsOver(left, right, top)
	local lowest
	for _, unit in ipairs(WIN.clear.units) do
		local frame = GameFrame(unit)
		local l, b, w, h
		if frame and not ns.Forbidden(frame) and win.Drawn(frame) then
			l, b, w, h = Rect(frame)
		end
		if l and w > 0 and h > 0 and l < right and l + w > left and b < top and b + h >= top then
			lowest = math.min(lowest or b, b)
		end
	end
	return lowest
end

function win.Hanging()
	local saved = Saved() or {}
	local list = {}
	win.Each(function(name)
		local frame = GameFrame(name)
		if frame and not ns.Forbidden(frame) and type(saved[name]) ~= "table" and hold.by[name] == nil and not (win.drag and win.drag.name == name)
			and IsShown(frame) == true and not Parked(frame) and not win.Fills(frame) and win.Hung(frame) then
			local left, bottom, width, height = Rect(frame)
			if left and width > 0 and height > 0 then
				list[#list + 1] = { frame = frame, left = left, bottom = bottom, width = width, top = bottom + height }
			end
		end
	end)
	return list
end

function win.ClearUnits()
	if not (win.On() and ns.Get("movers.clearUnits") == true) then
		return
	end
	local windows = win.Hanging()
	local line
	for _, rect in ipairs(windows) do
		local under = win.UnitsOver(rect.left, rect.left + rect.width, rect.top)
		if under then
			line = math.min(line or under, under)
		end
	end
	if line then
		for _, rect in ipairs(windows) do
			ns.Each(KEY, win.Lower, rect.frame, rect, line - WIN.clear.gap)
		end
	end
end

function win.Lower(frame, rect, line)
	local lowest = math.min(rect.bottom, WIN.clear.floor)
	local top = math.max(line, lowest + rect.top - rect.bottom)
	if top >= rect.top - TOLERANCE or (InCombatLockdown() and ns.MaybeProtected(frame)) then
		return
	end
	local k = Ratio(frame)
	local ok, point, _, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
	if not (k and ok and Number(x) and Number(y)) or ns.IsSecret(point) or ns.IsSecret(relativePoint) then
		return
	end
	local setPoint = Calls(frame)
	setPoint(frame, point, UIParent, relativePoint, x, y + (top - rect.top) / k)
end

local function BuildBar()
	bar = CreateFrame("Frame", nil, UIParent)
	ns.Own[bar] = true
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
	local MM = ns.MoversMode
	MM.Surface(bar, "card")
	local title = MM.Text(bar, "GameFontNormal", "text")
	title:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -10)
	title:SetText("Movers")
	local hint = MM.Text(bar, "GameFontHighlightSmall", "text-dim")
	hint:SetWidth(416)
	hint:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -30)
	hint:SetText("Drag to move. Scroll or Shift and scroll to nudge. Ctrl and scroll to scale. Right-click to reset, Shift and right-click to hide a HUD frame.")
	local edit = MM.Text(bar, "GameFontDisableSmall", "text-dim")
	edit:SetWidth(416)
	edit:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
	edit:SetText(EVERY_FRAME)
	centre.how = MM.Text(bar, "GameFontDisableSmall", "text-dim")
	centre.how:SetWidth(416)
	centre.how:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -6)
	local pickButton
	pickButton, pick.label = MM.Button(bar, "Pick a frame", 100, function()
		if pick.on then
			StopPick()
		else
			StartPick()
		end
	end, false, function()
		if pick.on then
			return "Stop picking", "Stops picking without taking a frame."
		end
		return "Pick a frame", "Point at any frame on the screen and press Alt to give it a box of its own; Shift picks the frame around it. "
			.. "Click again to stop."
	end)
	pickButton:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 12, 10)
	local resetButton, resetLabel
	resetButton, resetLabel = MM.Button(bar, "Reset all", 132, function()
		if resetPending or not (C_Timer and C_Timer.After) then
			resetPending = nil
			resetLabel:SetText("Reset all")
			ns.Try(KEY, ResetAll)
			return
		end
		local mine = {}
		resetPending = mine
		resetLabel:SetText("Click again to reset")
		C_Timer.After(RESET_ASK, function()
			if resetPending == mine then
				resetPending = nil
				resetLabel:SetText("Reset all")
			end
		end)
	end, false, function()
		return "Reset all", "Puts every moved frame back where the game has it. Click twice; Undo takes it back."
	end)
	resetButton:SetPoint("LEFT", pickButton, "RIGHT", 6, 0)
	centre.button = MM.Button(bar, "Centre ticked", 96, function()
		ns.Try(KEY, centre.Everything)
	end, false, function()
		return "Centre ticked", "Centres each handle whose box is ticked across the screen, at its height. Undo takes them all back at once."
	end)
	centre.button:SetPoint("LEFT", resetButton, "RIGHT", 6, 0)
	local doneButton = MM.Button(bar, "Done", 70, function()
		ns.Try(KEY, Close)
	end, true, function()
		return "Done", "Ends the session and keeps the changes. Escape asks first."
	end)
	doneButton:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -12, 10)
end

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
		if ns.MoversMode.Resume() ~= nil then
			ns.MoversMode.Abandon()
			win.waitOpen, win.waitPick = nil, nil
			win.Say("/flatui move stays closed after the fight.")
			return
		end
		if win.waitOpen then
			win.waitOpen = nil
			win.Say("/flatui move will not open after the fight.")
		else
			win.waitOpen = source or "slash"
			win.Say("/flatui move opens when the fight ends.")
		end
		return
	end
	win.waitOpen = nil
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
	if ns.BarBlockGrips then
		ns.Try(KEY, ns.BarBlockGrips, false)
	end
	centre.Closed()
	ns.MoversMode.Closed()
	UpdateDriver()
end

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

local function ActiveLayout()
	local manager = EditModeManagerFrame
	local ok, active = pcall(function()
		return not ns.Forbidden(manager) and manager.layoutInfo.activeLayout
	end)
	return ok and Number(active) and active or nil
end

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
		win.Say(("Changed in Edit Mode, so the saved spot is dropped: %s."):format(table.concat(labels, ", ")))
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

local function PanelChanged()
	if running and ns.Enabled(KEY) then
		ns.Try(KEY, win.Sweep)
		ns.Try(KEY, Grips)
		ns.Try(KEY, PlaceWindows)
		PlaceWindowsLater()
	end
end

local owner = {}

local function Watch()
	if watched or type(EventRegistry) ~= "table" or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	local ok, err = pcall(function()
		EventRegistry:RegisterCallback("EditMode.Enter", EditModeEntered, owner)
		EventRegistry:RegisterCallback("EditMode.Exit", EditModeExited, owner)
		if not ns.HandsOff() then
			EventRegistry:RegisterCallback("EditModeManager.UpdateBottomActionBarPositions", hold.Pass, owner)
		end
		EventRegistry:RegisterCallback("UIParentPanelManager.ShowUIPanel", PanelChanged, owner)
		EventRegistry:RegisterCallback("UIParentPanelManager.HideUIPanel", PanelChanged, owner)
		EventRegistry:RegisterCallback("WorldMapMaximized", PanelChanged, owner)
		EventRegistry:RegisterCallback("WorldMapMinimized", PanelChanged, owner)
		if type(hooksecurefunc) == "function" and type(UpdateUIPanelPositions) == "function" then
			hooksecurefunc("UpdateUIPanelPositions", PanelChanged)
		end
		if type(hooksecurefunc) == "function" and type(UpdateContainerFrameAnchors) == "function" then
			hooksecurefunc("UpdateContainerFrameAnchors", PanelChanged)
		end
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
		win.Say(("Dropped the saved spot of %s: it was the top left corner of the screen."):format(table.concat(corner, ", ")))
	end
end

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
	ns.EachPart(KEY, WIN.part, win.ClearUnits)
	centre.Refresh()
	UpdateDriver()
end

local function Resized()
	if running and ns.Enabled(KEY) then
		ApplyAll()
		PlaceWindowsLater()
		ShowHandles()
		centre.LineLook()
		ns.MoversMode.Resized()
	end
end

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
	if win.DragOn() and win.barUsed and not win.heard then
		lines[#lines + 1] = "No mouse press reported by the game, so windows drag by the title bar only."
	end
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

function ns.WindowResetLines()
	return { { 1, "Every window to its default place and size" } }
end

function ns.WindowsReset(id)
	if id ~= 1 then
		return
	end
	local why = Unavailable()
	if why then
		win.Say(why)
	else
		ns.Try(KEY, win.Reset)
	end
end

ns.MoverKit = {
	LIST = LIST, BY_NAME = BY_NAME, handles = handles, looks = handleLooks, Saved = Saved, Describe = Describe, Rect = Rect, ScreenSize = ScreenSize,
	BoxSize = BoxSize,
	Commit = Commit, ShowHandle = function(name) ShowHandle(name) end, Cursor = function() return win.Cursor() end,
	IsOpen = function() return open == true end, Close = function() Close() end,
	Centre = function(name) return centre.Do(name) end,
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
		EDIT_MODE_LAYOUTS_UPDATED = function()
			ns.LayoutSpots.Updated()
			ApplyAllLater()
		end,
		PLAYER_SPECIALIZATION_CHANGED = ApplyAllLater,
		INPUT_DEVICE_INTERFACE_TRANSITION = PanelChanged,
		GLOBAL_MOUSE_DOWN = function(button)
			ns.EachPart(KEY, WIN.part, win.Pressed, button)
		end,
		GLOBAL_MOUSE_UP = function(button)
			ns.EachPart(KEY, WIN.part, win.Released, button)
		end,
		PLAYER_REGEN_DISABLED = function()
			win.toldMove, win.toldSize = false, false
			if open then
				ns.MoversMode.Pause()
				Close()
				win.Say("Movers pause for combat.")
			end
		end,
		PLAYER_REGEN_ENABLED = function()
			hold.Pass()
			local again = ns.MoversMode.Resume()
			if again and not open then
				Open(again)
			end
			local waited = win.waitOpen
			win.waitOpen = nil
			if waited and not open and not Unavailable() then
				Open(waited)
				if open and not win.toldHow then
					win.toldHow = true
					win.Say(HOW)
				end
			end
			if win.waitPick then
				win.waitPick = nil
				if not Unavailable() then
					Open("slash")
					if open and not pick.on then
						StartPick()
					end
				end
			end
			if win.waiting then
				win.waiting = false
				Grips()
			end
		end,
	},
	slash = {
		move = function(rest)
			rest = rest:match("^%s*(.-)%s*$"):gsub("%s+", " ")
			local why = Unavailable()
			if why then
				win.Say(why)
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
					win.Say(HOW)
				end
			end
		end,
		grab = function()
			local why = Unavailable()
			if why then
				win.Say(why)
				return
			end
			if InCombatLockdown() then
				if win.waitPick then
					win.waitPick = nil
					win.Say("/flatui grab will not start after the fight.")
				else
					win.waitPick = true
					win.Say("/flatui grab starts when the fight ends.")
				end
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
