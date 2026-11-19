local ADDON_NAME, ns = ...

-- Each area of the interface is a module with its own switch. A module only touches texture
-- regions of Blizzard frames (alpha, visibility, colour) and adds its own frames and textures.
-- It never writes a field on a Blizzard frame or calls one of its Lua methods, with one
-- exception: frame pools are read with EnumerateActive. Five things are re-anchored, all with
-- widget calls: the cooldowns on action buttons, the lower bars of the personal resource
-- display, the state textures of check boxes, item slots and sidebar tabs in windows,
-- UIParent's scale, and the icon art of the cooldown manager. On nameplates the game's nameplate driver is followed with hooksecurefunc
-- (UpdateNamePlateOptions), and on the next frame after it three more things are set with
-- widget calls and put back the same way: the font object, height and colour of the name, health
-- text and level, the fill of the health bar, and the height of the two bar containers. The clickable area of a nameplate is set with
-- C_NamePlateManager.SetNamePlateHitTestInsets and C_NamePlate.SetNamePlateSize, out of combat.
-- The fill of a status bar is made solid with SetColorFill, or is an image file of the addon's own set with
-- SetStatusBarTexture, and put back with SetStatusBarTexture. The size, face and flags of a label are set with SetFont, its colour with
-- SetTextColor and its shadow with SetShadowOffset, each remembered on first touch and put back. Any Blizzard method or global function may be
-- followed with hooksecurefunc through ns.Follow, ns.FollowGlobal and ns.FollowTable, which run after the game's call and never change what it returns.
-- BarBlock gives Movers the spots of the action bars. The one thing it writes on a Blizzard frame is the alpha of the bars of the block
-- (SetAlpha, only with Fade the block on), put back when the fade goes off. Fade does the same for the frames of the Fading page, the alpha only
-- (SetAlpha), read before the first write (and again when something else gives the frame another alpha after one) and put back when its page,
-- its row or the module goes off. With Hit numbers on player and pet
-- portraits off, Unit frames does the same for the frame that holds the player's hit number (HitIndicator), and hides the pet's (PetHitIndicator,
-- SetShown) each time CombatFeedback_OnCombatEvent has shown it; the game shows the next one again once the row is on.
-- Fade's frames include the game's DamageMeter, other addons' minimap buttons (LibDBIcon10_) and, while they show, the bag windows, the game's
-- (ContainerFrameCombinedBags, ContainerFrame1 to ContainerFrame7, BankFrame) and those of Bags, whose alpha it reads first and puts back the same way; its
-- Bag bar row writes the alpha of BagsBar alone, also while Leave the game's action bars alone is on, never of a bag button. Fade writes no alpha
-- on a frame Hidden frames holds (below) or one under it, and gives such a frame its own alpha back just before it goes under (ns.FadeLetGo).
-- Movers and Tooltip are the exceptions that move Blizzard frames, with ClearAllPoints, SetPoint
-- and SetScale only, and SetAnchorType and Hide on GameTooltip: Movers places the frames the player moves,
-- Tooltip places GameTooltip and hides it when the game fades it out while it follows the cursor. The cast
-- bar sizes set the width and height of four cast bars, the height of the player bar's spark, the size of
-- its mask and the anchor of its text. With Spell rank on the player bar on, the cast bars write the text of the player's two cast bars
-- (SetText): a frame after the game wrote the name of a cast, the same name with the rank of that spell after it, only while the text is
-- still that name, and the name alone again when the row goes off.
-- Minimap and buffs gathers other addons' minimap buttons beside or under the map with ClearAllPoints and SetPoint, unprotected ones only, and puts
-- a button back at the points it recorded when it is ticked in Leave in place or the row goes off. With Close the gap under the zone name on, it
-- hangs the game's zone name button (MinimapCluster.ZoneTextButton), and with it the clock, calendar and tracking button that hang from it, from
-- the minimap with ClearAllPoints and SetPoint, out of combat if the game protects it, no further out than the game's place, with a frame of its
-- own in the cluster at the button's place so the cluster keeps its size; the mail icon (MinimapCluster.IndicatorFrame) and the addon list button
-- (AddonCompartmentFrame) that the game hangs between the button and the map it hangs on the button's other side, inside the button's old place,
-- the same way, where they do not fit between. It gives each back the points it read (GetPoint) when the row goes off, while the game's ring
-- shows, while Edit Mode is open, and until Edit Mode has applied its layout (the manager's layoutInfo, read with rawget; EventRegistry's
-- EditMode.Enter and EditMode.Exit).
-- Hidden frames (Hide.lua; on, with nothing ticked, by default) puts each frame of the game the player ticks, of the HUD frames /flatui move moves
-- and the parts of the minimap, under a hidden frame of its own (a SecureHandlerBaseTemplate frame with its corners on UIParent's), out of combat
-- only: in a snippet of that frame (Execute; SetParent of the frame's handle), so the frame's OnHide runs in the game's secure code. A protected
-- frame goes back all in one snippet, never by a call of Flat UI's own: under the parent it had when that one is explicitly protected, else under a
-- second, shown frame of its own with UIParent's corners and scale, until a reload or until the game gives it a parent. Any other frame goes back
-- under the parent it had with the engine's own SetParent (the methods of GetFrameMetatable) while the snippet holds it hidden. Either way the
-- snippet hides it and shows it again (Hide and Show of the handle, shown again only if its own shown flag was), and its frame strata and level are
-- put back where the move changed them. It writes nothing else on the frame, and four times a second, out of combat, it puts a ticked frame the game
-- gave another parent under its own again. The Alerts row also puts each toast AlertFrame:AddAlertFrame shows (ns.Follow) under that frame by the
-- snippet, out of combat, as the toasts are only anchored to AlertFrame. A change in a fight waits for its end. While Leave the game's action bars
-- alone is on it hides none of the game's bars but the bag bar (BagsBar), which it hides either way.
-- With Loot rolls on, it gives the game's roll frames (GroupLootFrame1 to 4) Flat UI's look with widget calls only, each put back when the row goes
-- off: the alpha of the toast, its border and the ring round the icon (SetAlpha), the crop of the icon (SetTexCoord), the fill of the timer, the
-- timer across the foot of the frame and one level above it (ClearAllPoints, SetPoint, SetHeight, SetFrameLevel; the game sets that level again at
-- every roll), and the Need, Greed, Transmog and Pass buttons in a row (ClearAllPoints, SetPoint, SetSize), with outlines of its own round the
-- frame, the icon and the timer. The cards of the gamepad interface go through the same call and take the look, but keep the game's places for
-- their timer and buttons. Once the box Loot rolls has a spot in /flatui move (an own entry, FlatUILootRolls, with Movers on), an anchor frame
-- of Flat UI's own on UIParent lies over that box, and after each GroupLootContainer_Update (ns.FollowGlobal) every roll frame the game's container
-- holds (its rollFrames, read) is hung from it with ClearAllPoints and SetPoint, slot by slot with the game's 100 between them, up or down as Rolls
-- stack says; also in a fight, since none of them is protected and nothing protected hangs from them. While no spot is saved the game's layout is
-- left alone, and a reset of the box puts each moved frame back at the point the container's layout gives it. The container itself is never
-- touched, and keeps its room in the game's bottom stack.
-- With Questie's tracker on and the Questie addon loaded (QuestieSkin.lua), it lays Flat UI's own outlines on Questie's tracker (Questie_BaseFrame,
-- Questie_HeaderFrame, the lines linePool1 and on, the item buttons Questie_ItemButton1 and on), each a backdrop texture on Questie's frame and edges
-- on a frame of Flat UI's own, round the frame or round an anchor frame of Flat UI's own on a heading. It follows QuestieTracker.Update with
-- ns.FollowTable and each line's SetMode with ns.Follow, and writes only what it puts back: the alpha of the pieces of Questie's backdrop
-- (SetAlpha), the font of Questie's heading and of each line's label (SetFont and SetShadowOffset, through ns.TextStyle), the height of a zone
-- heading's label (SetHeight), the texture coordinates of the item icons (SetTexCoord) and, in a fight with Opacity in combat, the alpha of
-- Questie_BaseFrame (SetAlpha). After a change of that look it asks Questie to lay its lines out again (QuestieTracker:Update), out of combat;
-- it never writes Questie's saved settings.
-- Combat text is the one module that writes console variables: nine of the game's combat number variables and the switch of its
-- own text for the player (enableFloatingCombatText), each remembered in FlatUIDB.cvars before its first write and put back when
-- its page goes off. Its numbers are font strings on a frame of its own, in font objects it makes with CreateFont.
-- Windows writes one game setting: the direction of the game's clean up (C_Container.SetSortBagsRightToLeft), only while Items gather is
-- From the other end, remembered in FlatUICharDB.sortDirection before the first write and put back as the variables above are. While Backpack key
-- opens every bag is on, it gives each key the player has for Toggle Backpack an override binding to Open All Bags (SetOverrideBinding, on a frame
-- of its own, out of combat), so B opens the reagent bag too; ClearOverrideBindings takes them away when the row goes off, the player's bindings
-- are never written, and the overrides end with the session.
-- Maximum camera distance, on the Flat UI page, writes the game's cameraDistanceMaxZoomFactor only when the player ticks or unticks it, out of
-- combat: 2.6 when ticked, its text before that kept in FlatUIDB.cameraGame, and that text again (or the client's default) when unticked while
-- the variable is still 2.6 or more. The cursor ring is a frame of the addon's own on UIParent that takes no mouse.
-- Its cast and global cooldown progress are Cooldown frames of its own fed the game's duration objects.
-- Quest item sparkle, on the Flat UI page, writes the game's outlineModeShowLootEffectWhenDisabled (1), and Sparkle strength raises
-- graphicsParticleDensity, raidGraphicsParticleDensity, graphicsSpellDensity and raidGraphicsSpellDensity to its level, never below the game's own,
-- out of combat: at login, when a row or the profile changes, and a second after the game writes one of them or its graphics quality. The text
-- each had before is kept in FlatUIDB (sparkleGame, sparkleParticleGame, sparkleRaidParticleGame, sparkleSpellGame, sparkleRaidSpellGame) and
-- the text Flat UI wrote in FlatUIDB.sparkleWrote; the kept text is written back when the rows no longer need it, while the variable still holds
-- the text Flat UI wrote, and a value written since, also while Flat UI did not run, is the game's own. Glow on the nearest object is a frame of its
-- own that takes no mouse, put on the game's nameplate of the object the Interact Key would use (its soft-interact game object), only while the
-- game shows that plate, and parented, levelled and anchored there out of combat only; it writes no game setting.
-- In-game navigation, on the Levelling tab of Errands, writes the game's showInGameNavigation (1) while the row and Errands are on, out of combat:
-- at every login whatever the switch of Errands, when the row, the switch or the profile changes, and a second after the game or the player
-- writes it; a value already on is left as it is, and a 0 written another way after the variable was on while the row asked for it (/console,
-- another addon or the game) is the player's own, kept in FlatUIDB.navigationOn and navigationOff, and given no 1 again until the row changes.
-- The text it had before is kept in FlatUIDB.navigationGame and the text Flat UI wrote in FlatUIDB.navigationWrote; the kept text is written back
-- when the row, Errands or its part goes off or stops, while the variable still holds the text Flat UI wrote, and a value written since, also
-- while Flat UI did not run, is the game's own.
-- Nameplate threat follows CompactUnitFrame_UpdateAggroHighlight with hooksecurefunc and only reads threat, roles, stances, forms and auras; a
-- frame of its own hears UPDATE_SHAPESHIFT_FORM for a warrior or druid, and /flatui role sets Your role. With Fade enemies held for you, Nameplates
-- writes the alpha of the game's nameplate unit frame (SetAlpha), read first and put back when the plate loses its fade, leaves, or the row, page
-- or module goes off, and sets it again after CompactUnitFrame_UpdateCenterStatusIcon, which it follows with hooksecurefunc. The threat ring is an
-- outline of its own on a frame of its own on the health bar, made and anchored out of combat, and Mark gives the health bar border a threat colour
-- through ns.PlateThreatBorder. The threat value and the name of the enemy's target are font strings of its own on the plate, made and placed out
-- of combat on a plate that may be protected, written with SetText, SetFormattedText, SetTextColor and SetAlphaFromBoolean from the game's answers
-- as they are; with Threat colour on the name, the name takes the threat colour with SetVertexColor, as Name colour does, kept and put back the
-- same way.
-- With Health text in the name's colour, the game's health text takes that colour with SetTextColor, as Health text colour does, kept and put back
-- the same way.
-- Overpower on enemy nameplates (PlateOverpower.lua, a warrior's) puts Overpower's icon on a frame of its own, a child of the plate's unit frame,
-- above the name of the enemy that dodged the player, made, sized and anchored out of combat on a plate that may be protected; in a fight only its
-- alpha, texture, grey and glow change. A frame of its own hears UNIT_COMBAT, SPELL_UPDATE_USABLE, ACTION_USABLE_CHANGED, SPELL_UPDATE_COOLDOWN, the
-- player's casts and auto attack and NAME_PLATE_UNIT_REMOVED while the row is on, and SPELLS_CHANGED for a warrior, and only reads.
-- Errands (off by default) asks the game to do the player's chores: it sells with C_Container.UseContainerItem while a merchant is open,
-- also for the Sell junk button of the bags, whatever the switch of Errands, repairs with RepairAllItems, buys with BuyMerchantItem, sells the
-- cursor item with SellCursorItem, loots with LootSlot, learns with BuyTrainerService, deletes one grey item with DeleteCursorItem from a click
-- on its own button, and answers summons, resurrections, invites and duels with the game's calls for them. Of the game's popups it hides only
-- four, with StaticPopup_Hide and only while it is the one popup shown: the group invite's once the player is in the group and the summon's
-- once the game says no summon is open, since the game leaves both
-- up after an accept made by code (hiding the invite sooner declines it, and a stale summon cancels the next); the token purchase's question
-- just before it buys in its place (the game would leave it up, and its Yes would buy again); and the tradeable sale's right after it sells
-- (the game closes that one too, once the cursor is empty). For Buy in bulk it asks with a popup of its own (FLATUI_BULK_BUY, an entry of
-- StaticPopupDialogs shown with StaticPopup_Show, as Clean up bags' is) and calls nothing on the game's split box. It follows
-- StaticPopup_Show, StaticPopup_Hide, ClassTrainerFrame_Update, SendMailFrame_SendMail, SendMailFrame_Reset and
-- MerchantItemButton_OnModifiedClick with hooksecurefunc, writes DELETE in the box of the game's delete popup (SetText, then ClearFocus) and
-- the last recipient in the To box of the mail window (SetText), and lays frames of its own over the loot window, the trainer window and the
-- Release Spirit button of the death popup, a bar beside the game's split box (StackSplitFrame) and a Sell next 12 button under the merchant
-- window.
-- On its Levelling tab it accepts and hands in quests and picks gossip options with the game's calls for them (AcceptQuest, CompleteQuest,
-- GetQuestReward, the select calls of C_GossipInfo and of the quest greeting), and asks the game to load an offered quest
-- (C_QuestLog.RequestLoadQuestByID); it touches no frame of the quest or gossip windows. It puts a higher rank of a spell on the action
-- slots that hold a lower one (C_Spell.PickupSpell, PlaceAction, ClearCursor) only inside the click of its own Uprank and reload button,
-- whose secure /reload macro reloads the interface in the same click, and it adds a filter to the game's chat filters
-- (ChatFrameUtil.AddMessageEventFilter, CHAT_MSG_SYSTEM) that drops the game's lines about learned and unlearned spells.
-- It adds the slash command /way beside /flatui (SLASH_FLATUIWAY1 and SlashCmdList.FLATUIWAY) when no other addon has one, and sets a map
-- pin and its tracking (C_Map.SetUserWaypoint, C_SuperTrack.SetSuperTrackedUserWaypoint) only when the player types it. It never changes the
-- faction the game watches, and reads the list of factions without expanding it: Flat UI's own reputation bar shows the faction gained.
-- Bags (on by default) draws a bag window and a bank window of its own on UIParent and keeps the game's bag windows (ContainerFrame1 to
-- ContainerFrame7 and ContainerFrameCombinedBags), and with Flat UI's bank BankFrame, from showing by moving each under a hidden frame of its own
-- (SetParent), out of combat and only while the game has it closed. Each goes back to the parent it was read from (GetParent) when the page goes off,
-- the module or one of its parts follow, cache, window, layout or items stops, Bags stands down for another bag addon or the gamepad interface, or,
-- for BankFrame, the game's bank window is chosen: at once, also in a fight, when the game has it closed, and once the game closes it otherwise. Of
-- those windows it reads the shown flag (IsShown), and when its own bag window hides, and when it gives the windows back, it hides the bag windows it
-- moved that the game still has open (Hide, which runs no script under the hidden frame); it writes no field on them and calls none of their methods.
-- It follows ToggleBackpack, ToggleBag, ToggleAllBags, OpenAllBags, OpenAllBagsMatchingContext, OpenBag, OpenBackpack, CloseAllBags, CloseBag,
-- CloseBackpack, HideUIPanel, ContainerFrame_SetFullScreenFrame and ContainerFrame_ClearFullScreenFrame with hooksecurefunc, and calls none of the
-- game's bag functions: they build the game's list of bag windows the first time they are asked (Mainline/ContainerFrame.lua:2335-2373), and a list
-- built by Flat UI's code would be read by Escape. It asks C_GameRules.IsGameRuleActive whether the game shuts the bags and
-- C_ActionBar.ShouldShowKeyring whether it shows a keyring, and after ToggleBag it reads the game's showKeyring and combinedBags settings
-- (C_CVar.GetCVarBool) and the size of the bag named (C_Container.GetContainerNumSlots), so a toggle the game lets pass leaves its window alone. It
-- takes the game's new flag off the items of the bags (C_NewItems.RemoveNewItem), as the game's own close does, when its bag window hides, when it
-- gives the windows back and has hidden one of them, and, while New items at the top is on, when it has the game sort the bags and at a click on the
-- title of the top shelf of its bag window. With BankFrame hidden this way it ends the bank with C_Bank.CloseBankFrame, which the game's OnHide would
-- otherwise do, when its bank window closes or the game hides BankFrame, first hiding BankFrame if shown there (Hide): the game hides it in the call
-- (a synchronous event) with a HideUIPanel refused to Flat UI's code in a fight. A bank window hidden while the interface is hidden runs no OnHide,
-- so the call comes when Flat UI hides it, or when the interface shows again after the game closed it; and the call waits while a move of Deposit or
-- Take out of the last second has no answer (its slot locked; C_Timer.After), so the answer is read first. While it reads the bank, and when the page
-- comes up while BankFrame shows, it asks whether the player still deals with a banker (C_PlayerInteractionManager.IsInteractingWithNpcOfType). It
-- reads where the right action bars stand (IsVisible, GetLeft, GetRight and GetEffectiveScale of MultiBarRight and MultiBarLeft) and whether Edit
-- Mode has each in its place (the table Edit Mode keeps on the bar, systemInfo, and its isInDefaultPosition, read with rawget; no method of the bar
-- is called), so that its bag window starts left of those in their place, as the game's bags open. Its windows play the sounds of the game's bag
-- windows as they open and close (PlaySound, SOUNDKIT.IG_BACKPACK_OPEN and IG_BACKPACK_CLOSE).
-- Its bag slots are ItemButtons of its own from ContainerFrameItemButtonTemplate, made out of combat or as a fight starts
-- (PLAYER_REGEN_DISABLED), each with its bag as the ID of a frame of its own (SetID) and its slot as its own ID for the whole session, and shown
-- once inside its own window after they are made, for one frame, with the window (or, in an open window, the new buttons alone) standing off the
-- left edge of the screen. It never calls SetBagID or Initialize on them; of the template it calls only SetHasItem, SetReadable,
-- SetMatchesSearch, UpdateQuestItem and UpdateNewItem, and it draws counts and cooldowns on its own slots with the game's SetItemButtonCount and
-- CooldownFrame_Set. The one field it writes on them itself is hasStackSplit: before its code hides one of them that owns the game's split box
-- (StackSplitFrame), or a frame that holds one, and first in the OnHide of the bag window and of its title bar and footer buttons, it writes 0
-- there, as the game does when the box closes (Mainline/StackSplitFrame.lua:5, 293), so the template's OnHide
-- (Mainline/ContainerFrame.lua:1816-1822) leaves the box to the game, and it stays until the player presses Okay or Cancel. Its bank slots are
-- buttons of its own that pick up (C_Container.PickupContainerItem) and take out (C_Container.UseContainerItem with no bank type) on a click, out
-- of combat, and its bank bag slots are buttons of its own that pick up the bag (C_Container.PickupContainerItem(-2, n)) on any click, drag or
-- drop, out of combat, as the game's do; a modified click on a bank slot, or on a slot drawn from its records (another character's, or the bank
-- while its bank window is not the live one), links the item (HandleModifiedItemClick, and in a fight ChatFrameUtil.InsertLink only, never the
-- dressing room). Deposit and Take out move the items that match its search with C_Container.UseContainerItem (Enum.BankType.Character to
-- deposit) one at a time while its bank window is the live one, out of combat, and move nothing while a spell waits for its target
-- (SpellIsTargeting, SpellCanTargetItem, SpellCanTargetItemID), to which the same call would give the item. Its Buy button is a frame of its own
-- from the game's BankPanelPurchaseButtonScriptTemplate given the attribute overrideBankType out of combat; the game's own popup
-- (CONFIRM_BUY_BANK_TAB) buys, and when a visit with Flat UI's bank window ends, it hides that popup with StaticPopup_Hide (Errands.HideAlone),
-- only while it is the one popup shown, as the game's bank panel does when it hides. The menu of a bag's label sets the flags of the game's own
-- bag menu (C_Container.SetBagSlotFlag, SetBackpackAutosortDisabled, SetBackpackSellJunkDisabled). Its sort buttons clean up the bags, or the
-- bank while its bank window is the live one, through Clean up bags (C_Container.SortBags and SortBank, BagSort.lua), and its Sell junk button
-- sells through Errands (above). A dropped item goes back with ClearCursor, also in a fight; one dropped on Junk goes on Errands' sell list, and
-- an item of Junk (for a slot of the bags the test of that slot, else the two lists) dropped on another section comes off the sell list, and onto
-- the keep list when it is grey (FlatUIDB.errands), as /flatui sell and /flatui keep do. It writes the tooltips of its buttons, its gold and its
-- slots that hold no live item in GameTooltip (SetOwner, SetText, AddLine, AddDoubleLine, Show, Hide), those of the slots from the item
-- (SetHyperlink, SetBagItem) never in a fight, and inside the game's build of an item tooltip, through one post call of its own
-- (TooltipDataProcessor.AddTooltipPostCall), it adds lines naming the player's other characters on this realm and its connected realms that carry
-- the item (AddDoubleLine). The game is asked once to load each item its windows show that the client has not loaded yet
-- (C_Item.RequestLoadItemDataByID). It adds FlatUIBags and FlatUIBank to UISpecialFrames, and names the key binding of its bank button
-- (BINDING_NAME_CLICK FlatUIBankButton:LeftButton). What it keeps of each character (items, gold, level, class, faction, realm and the time) and
-- the sections items were placed in by hand are in FlatUIDB.bags, and none of it leaves the client.
-- Data panels (off by default) draws two panels of its own on UIParent and writes the lines of their tooltips in GameTooltip (SetOwner,
-- SetText, AddLine, AddDoubleLine, Show, Hide). It asks the server for the guild roster (C_GuildInfo.GuildRoster) while a slot shows the guild,
-- and the game for the memory of addons (UpdateAddOnMemoryUsage) when its frame rate tooltip opens out of combat. When another addon brought
-- LibDataBroker, it listens to that library and calls the functions of the feeds a slot shows (OnEnter, OnLeave, OnTooltipShow, OnClick).
-- Its Equipment set slot opens a menu of its own whose lines call C_EquipmentSet.UseEquipmentSet, never in a fight.
-- Threat list (off by default) is a window of its own on UIParent; it only reads threat (UnitDetailedThreatSituation) and changes nothing.
-- Hit table (Minimap and buffs; on by default for a tank or a damage dealer and off for a healer, by ns.PlayerRole below) is a frame of its own on
-- UIParent that takes no mouse, hung out of combat by SetPoint from a second frame of its own whose corners are set on the player frame's portrait
-- (or Flat UI's picture or body, else the health bar, else PlayerFrame) and on PlayerBottomManagedFrameContainer, or on PlayerCastingBarFrame while
-- Edit Mode locks the cast bar to the player frame (its field attachedToPlayerFrame, read only), else on PlayerFrame; it follows
-- PlayerFrame_AttachCastBar and PlayerFrame_DetachCastBar with hooksecurefunc.
-- Of the game's it only reads, and changes nothing: the place and size of those frames, of PetFrame, TargetFrame, FocusFrame, UIParent and Flat UI's own frames
-- under the player frame, and the font of the player cast bar's text; the player's level, class, form, power type, combat state, stats (Spell
-- Piercing among them, GetSpellPenetration; never the enemy's resistances), weapon skills and weapons; the target's level and kind, whether it
-- exists, can be attacked, is dead or is a player, and whether it attacks the player: the player's threat situation on it (UnitThreatSituation),
-- else whether its target is the player (UnitIsUnit); and, while its row is For tanks
-- and damage dealers, the player's role (ns.PlayerRole: the group role, a tank stance, form or aura, the points spent in each talent tree of the set
-- of talents in use, as last read while no pick waited unapplied on it in the talent window, the class), read again after each event the hud module
-- hears that can change it. Its lines on an enemy's tooltip (HitTableTip.lua, On enemy tooltips, by the role too by default) are added to
-- GameTooltip (AddDoubleLine, AddLine) from the chat module's post call while that module is on, for a unit the player can attack that is not
-- dead, and with Text size on enemy tooltips other than 100% sized (SetFont on their font strings, GameTooltipTextLeftN and GameTooltipTextRightN),
-- each put back in the font object and font it had at the next clear of GameTooltip (GameTooltip_ClearMoney, which its OnTooltipCleared calls,
-- followed with ns.FollowGlobal), so every later tooltip has the game's sizes. They read the tooltip's unit (GetUnit under pcall, else
-- UnitTokenFromGUID of the data's guid, else the mouseover by UnitGUID), its level and kind (C.Target with the unit), whether it attacks the player
-- (C.Front), the player's form and power type (GetShapeshiftForm, UnitPowerType),
-- the combat state (InCombatLockdown, UnitAffectingCombat, C_Secrets.ShouldUnitStatsBeSecret) and the stats the table reads (ns.HitTableCalc,
-- C.Inputs), those out of a fight only, at most every two seconds as GameTooltip is built whatever it shows, and worked out by C.Table; in a fight
-- they count the last plain read, from before it, and say so.
-- Healer mana (off by default) is a window of its own on UIParent; it only reads mana (UnitPowerPercent) and changes nothing. The dispel border, the
-- debuff type icon and the raid marker of the party and raid frames, the leader and assistant icons of the raid frames and the dispel border of the
-- player, target and focus frames, and the heal over time squares of the party and raid frames, are textures of Flat UI's own over the game's frames, and the outline of your target on the party frames is a
-- frame of Flat UI's own with an outline; all are made and anchored out of combat, and in a fight only their colour, opacity and visibility
-- change, and which raid marker shows, from the game's answers as they are.
-- With Pet target frame on (off by default), Unit frames makes one secure button of its own (SecureActionButtonTemplate, no global name, type1
-- target, unit pettarget, useOnKeyDown false), made, sized, placed and watched only out of combat; the game shows and hides it (RegisterUnitWatch,
-- taken back with UnregisterUnitWatch). With Druid mana in forms, a druid gets a bar of its own on a frame of its own under the player frame's power bar.
-- Drink and health macros (off by default) makes, writes and deletes two macros of its own (CreateMacro, EditMacro, DeleteMacro), named in
-- FlatUIDB.consumables, or of its names with a body Flat UI writes (made on another computer: macros are the account's), only out of combat and with
-- the game's macro window closed; it reads the game's action slots and the cursor first (GetActionInfo, C_ActionBar.GetActionText, GetCursorInfo) and
-- deletes no macro that one of them still holds.
-- Mount key (off by default) makes one secure button, FlatUIMountButton, once a key is bound to it in the game's Key Bindings (Bindings.xml names the
-- binding, BINDING_NAME_CLICK FlatUIMountButton:LeftButton), writes its type and macrotext only out of combat and takes them away when off; it writes
-- no binding or macro. With Slow Fall or Levitate while falling on, it sets a PreClick and a PostClick on the button, out of combat, that swap the
-- falling macro in and back around each press.
-- Trackers lays secure buttons of its own (SecureActionButtonTemplate) over its icons, given attributes only out of combat; each leaves its icon at
-- PLAYER_REGEN_DISABLED (Hide, ClearAllPoints, SetParent UIParent), and writes its tooltip in GameTooltip.
-- Those buttons also cast your own buffs, stances and forms on you, run a macro of Call Pet and Revive Pet, and set the pet's mode with the pet
-- action type, all given out of combat. Trackers draws the pet's health on frames of its own through UnitHealthPercent and a curve, read by widget
-- calls only.
-- Trackers registers the game's own sound for a tracked aura that ends, comes or stacks (C_UnitAuras.AddAuraSound, triggers Removed, Added and
-- ApplicationsIncreased; RemoveAuraSound), only out of combat and while aura values are open; a change that waits is heard on a frame of its own,
-- also with the page off, so the registrations are taken back once it can be made.
-- Group tools (off by default) lays secure buttons of its own over its icons, made, placed, shown and given attributes only out of combat: the game's
-- raidtarget action, /readycheck and /countdown. A plain button asks for a role poll, and it writes tooltips in GameTooltip.
-- Cooldown pulse (off by default) is up to three frames of its own on UIParent that take no mouse, told when cooldowns end by invisible Cooldown frames of
-- its own fed the game's duration objects; it changes nothing.
-- Cooldown icons, with Tooltips on icons, let their own icons hear the mouse and take no click (SetMouseMotionEnabled, SetMouseClickEnabled:
-- protected functions, called on its own icons only while InCombatLockdown() is false), and write GameTooltip (GameTooltip_SetDefaultAnchor or
-- SetOwner, SetSpellByID, SetItemByID, SetInventoryItem, Show, and Hide while an icon owns it). The game is asked once to load each item of Add an
-- item, and each worn item it checks for a use, that the client has not loaded yet (C_Item.RequestLoadItemDataByID). Add the spells of a bar only
-- reads action slots and the bar page.
-- Cooldown icons hangs a row from the game's PlayerFrame or TargetFrame by SetPoint on a frame of its own, out of combat, as Your buffs does, and
-- writes nothing on them; its glows and buff time are frames of its own, and it hears the player's UNIT_AURA on a frame of its own while Buff time on
-- icons is on.
-- With Clear the damage meter on (off by default), Minimap and buffs calls C_DamageMeter.ResetAllCombatSessions as the player enters a dungeon or
-- raid, after its own popup FLATUI_METER_CLEAR when it asks (an entry of StaticPopupDialogs with an OnAccept only, shown with StaticPopup_Show as Clean
-- up bags' is); it hides that popup with StaticPopup_Hide only while it is the one popup shown, once the player has left or the rows no longer ask.
-- The combat alerts of Combat text (No target, +Combat and -Combat; off by default) are font strings on a frame of its own; they change nothing.
-- Chat and tooltips adds a filter to the game's chat filters (ChatFrameUtil.AddMessageEventFilter, the chat events players write and
-- CHAT_MSG_SYSTEM) that writes a web address in the plain text of a line it may read as a link of the game's addon type (|Haddon:FlatUI:url:...|h);
-- a click on one comes through EventRegistry (SetItemRef) and opens a box of its own. While the mouse is over an item, spell or achievement
-- link in a chat window (EventRegistry: ChatFrame.OnHyperlinkEnter and ChatFrame.OnHyperlinkLeave) it fills GameTooltip from the link
-- (SetOwner on a frame of its own, SetHyperlink) and hides it when the mouse leaves (Hide), only while that frame owns it and never in a fight.
-- Inside the game's build of a tooltip, Chat and tooltips colours a player's class line (SetTextColor) and, with Item and spell icons, writes
-- the first line (SetText): the icon before the name, only while the line still holds that name. With Target of units, while the mouse stays on
-- a unit whose target changes, a frame of its own writes the target line again (SetText) and has the tooltip take its size (Show), only while the
-- line still holds the text it wrote. With Compare items only while holding Shift
-- (on by default) it writes the game's alwaysCompareItems, out of combat: 0, its text before that kept in FlatUIDB.compareGame, and that text
-- again when the row, its page or the module goes off while the variable is still 0.
-- Inside the game's build of a spell tooltip, through the same post call, Chat and tooltips adds lines with the share of spell damage, spell
-- healing or attack power the spell adds, what that is with the player's stats, and its threat (AddLine, AddDoubleLine), and inside the build of
-- an item tooltip lines with what wearing the item changes for the spells the player chose (AddLine, AddDoubleLine), each once for each build and
-- only on GameTooltip and ItemRefTooltip.
-- For them it reads the player's stats, talents (C_Traits), form, Righteous Fury and Shadowform (C_UnitAuras, and for one not found
-- C_Secrets.ShouldSpellAuraBeSecret), the temporary enchant of each weapon, whether the player uses ammunition (C_PaperDollInfo.AmmoNeeded,
-- UnitUsesAmmo) and the action slot of a macro, the item's stats (C_Item.GetItemStats) and the lines of the item and of the items the player wears
-- (the data of the build, else C_TooltipInfo.GetHyperlink, and C_TooltipInfo.GetInventoryItem), asks the game to load an item it has not loaded
-- yet (C_Item.RequestLoadItemDataByID), asks which worn items the game would compare an item with (C_TooltipComparison.GetItemComparisonInfo;
-- never the protected CompareItem), converts ratings and stats with the game's own calls (GetCombatRatingBonusForCombatRatingValue,
-- GetAttackPowerForStat and the others, only while the game gives stats plain), reads once a session the description of one spell
-- (C_Spell.GetSpellDescription) to see whether the game's texts count spell power, and reads the fields processingInfo, supportsItemComparison
-- and suppressAutomaticCompareItem the game keeps on a tooltip it builds (TooltipDataHandler.lua:281, TooltipDataRules.lua:168-176). The spells
-- chosen are kept in FlatUICharDB.gearSpells.
-- With Avoidance (for tanks by default) the item lines and the window also show an enemy's swing against the player now and with the item: in the
-- same plain moment as the other stats it reads the defense skill (UnitDefenseSkill), the chances to dodge, parry and block (GetDodgeChance,
-- GetParryChance, GetBlockChance), armor (UnitArmor), block value (GetShieldBlock), the dodge agility gives (GetDodgeChanceFromAttribute) and whether a
-- shield is worn (C_PaperDollInfo.OffhandHasShield), and asks what armor takes off against the enemy's level (C_PaperDollInfo.GetArmorEffectiveness).
-- Its Gear comparison window (/flatui gear) is a frame of its own on UIParent, named FlatUIGear in UISpecialFrames so Escape closes it, placed by
-- the movers. It takes an item dropped on it (GetCursorInfo) and gives one lifted from a bag, the bank or a worn slot back there with ClearCursor,
-- while C_Cursor.GetCursorItem names that slot and C_Item.IsLocked says the item is still locked in it; any other item, such as one dragged off an
-- action bar, stays on the cursor, and so does a spell dropped on it (GetCursorInfo, and GetMacroSpell for a macro). It writes GameTooltip for its
-- rows, its switch, its item, Against, Find, the weights, the grip and the Overall lines (SetOwner, SetSpellByID, SetHyperlink, AddLine, Show, and
-- Hide while IsOwned says one of its frames owns it), never in a fight.
-- With Total of a cast, a spell's tooltip also has its total with the player's stats and a dim line of what a cast does on average, a second and
-- a point of mana; the second is the spell's cast time (C_Spell.GetSpellInfo, castTime) and the mana the game's cost of the spell
-- (C_Spell.GetSpellPowerCost, mana only). The spell and item lines take their gold header and their green and red from the game's
-- NORMAL_FONT_COLOR, GREEN_FONT_COLOR and RED_FONT_COLOR, read once as SpellModel.lua loads. The window has a grip of its own at its bottom right
-- corner (SetResizable, SetResizeBounds, StartSizing and StopMovingOrSizing on its own frame), its size kept in FlatUICharDB.gearWindow, which the
-- movers' box of it follows; its text size is set on its own font strings (SetFont) in the face of the game's GameFontHighlightSmall and
-- GameFontHighlight (GetFont, read only); and it has a second item box, Against, that an item dropped on it or chosen in the finder fills. The
-- weight of each spell is kept with the spells in FlatUICharDB.gearSpells and set by a click on its Weight cell (IsShiftKeyDown for back to 1).
-- Its Find button and the Item finder row show the item finder, FlatUIGearSearch, a frame of its own on UIParent that shows only with the window
-- (FlatUIGear) and is hung at its right edge, or at its left edge while the screen has no room on the right (GetLeft and GetRight of the window,
-- GetWidth of UIParent), kept on the screen (SetClampedToScreen) and in the window's strata (GetFrameStrata, SetFrameStrata); its search and level
-- boxes are EditBoxes of its own. The movers place it too (its own entry, with a box only while it shows): a drag of its title bar (StartMoving,
-- StopMovingOrSizing, SetUserPlaced) or of its box saves its spot in the movers as for any frame, and Dock forgets that spot, so it hangs at the
-- window again; Minimize folds it to its title bar, kept in FlatUICharDB.gearFinder. The finder
-- searches Flat UI's own item index (ItemIndex.lua, made from the game's client data by tools/dev/make_itemindex.py) and the bags, bank and other
-- characters Bags records; for an item the index lacks and for Best for me it asks the game to load the item (C_Item.RequestLoadItemDataByID) and
-- reads it (C_Item.GetItemInfo,
-- C_Item.GetItemInfoInstant, C_Item.GetItemInventoryTypeByID), names the weapon types by C_Item.GetItemSubClassInfo and the qualities' colours by
-- C_Item.GetItemQualityColor, and reads the player's class and level (UnitClassBase, UnitLevel). A Shift-click on a result links the item in chat
-- (IsModifiedClick, ChatFrameUtil.InsertLink) and a Ctrl-click tries it on in the game's dressing room (DressUpItemLink), as a click on an item in
-- the game's windows does. Its filter menus close at a press anywhere else, heard as GLOBAL_MOUSE_DOWN on a frame of their own only while one is
-- open.
-- Its Compare gear button (GearButton.lua) is a frame of its own, FlatUIGearButton, on UIParent, anchored to the title bar of CharacterFrame or, at
-- a spot the movers keep measured from the window's top left corner, to that corner (SetPoint with the window as the frame it hangs from), and never
-- parented to it; of the window it reads only whether it shows, where it is and its scale (which the button takes), its strata (the button is one above it, so the window, which the game raises when clicked, never covers it), whether
-- the game protects it and the width of its title text (the fields TitleContainer and TitleText, read). It follows ShowUIPanel and HideUIPanel
-- with hooksecurefunc (ns.FollowGlobal), and a frame of its own looks four times a second, while the row and the module are on, whether the window
-- shows. With an item on the cursor it gives one lifted from a slot back with ClearCursor, as the window does, and its tooltip is GameTooltip,
-- never in a fight.
-- With Show recent chat after a reload (off by default), Chat and tooltips hears the chat events players write on a frame of its own, keeps the
-- lines it may read in FlatUICharDB.chatLog and prints those of the last hour with print() after a reload. It hides GameTooltip by the kind of
-- tooltip, the unit's hostility and place, and the party or raid frame that owns it (Hide, as Tooltips in combat does).
-- Minimap and buffs, with Hide error messages on (off by default), takes the game's red error messages from UIErrorsFrame: it reads with
-- IsEventRegistered that the frame listens, stops it hearing UI_ERROR_MESSAGE with UnregisterEvent and hears that event on a frame of its own,
-- puts each message of a kind it does not hide back in the frame with AddMessage (ResetMessageFadeByID for a repeat that still shows) with the
-- game's sound for it (PlaySound, C_Sound.PlayVocalErrorSound), and gives the event back with RegisterEvent when the row, its page or the module goes off. It follows the game's two commands for
-- the error text (SlashCmdList.UI_ERRORS_OFF and UI_ERRORS_ON) and RunScript with hooksecurefunc, so a macro or addon that turns the error
-- text off or on is honoured and a kind it hides stays hidden.
-- With Hide the zone name or Hide the subzone name it sets the alpha of the game's zone text strings (SetAlpha), read first and put back when the row
-- goes off, and once Hide the zone name has been on it follows SetZoneText with hooksecurefunc, to hide the zone's name in the smaller line; with
-- Hide the talking head it takes TALKINGHEAD_REQUESTED from TalkingHeadFrame (UnregisterEvent) and gives it back, as above.
-- Test mode (TestMode.lua) is a state of the session, never saved. While it is on, out of combat, the modules that register with it draw samples on
-- their own frames, and frames of Flat UI's own on UIParent that take no mouse (stand-ins) lie at the places of game frames that are hidden now,
-- painted with Flat UI's look by the setup drawings. Of such a game frame a stand-in reads only the place and size (ns.MoverRect), the effective
-- scale, strata, level and shown flag. Test mode writes no variable, binding, target, attribute or field, calls no other method of a game frame,
-- adds no hook and never opens Edit Mode or a game window; a fight pauses it inside PLAYER_REGEN_DISABLED. Its key binding is a click on a plain
-- button of its own (BINDING_NAME_CLICK FlatUITestButton:LeftButton).

local MODULE_ORDER = { "nameplates", "combattext", "actionbars", "resource", "ownbuffs", "swing", "castbars", "cooldowns", "trackers", "defensives", "partycd", "enemycd", "windows", "bags", "unitframes", "hud", "chat", "movers", "barblock", "blocks", "tooltip", "errands", "datapanels", "threat", "pulse", "healermana", "consumables", "mount", "grouptools", "fonts", "fade", "hide" }
-- The switches version 0.1.0 saved. This list never grows.
local LEGACY_MODULES = { "nameplates", "actionbars", "resource", "swing", "castbars" }
-- A module that keeps failing is stopped.
local MAX_FAILURES = 5
-- A part of a module that keeps failing is stopped alone.
local MAX_PART_FAILURES = 3
local MAX_BLOCKED = 5
-- The version of the saved settings. Settings saved without it are older than the defaults of the settings below,
-- and settings saved before version 2 are not in profiles.
local SETTINGS_VERSION = 2
-- The profile every character starts on, which always exists.
local DEFAULT = "Default"
local MAX_NAME = 32
-- Settings whose saved choices are dropped once, so that the defaults of the unit frames apply. The list may name
-- a setting the addon no longer has: its value is dropped all the same.
local RESET_SETTINGS = { "unitframes.squarePortrait", "unitframes.badges", "unitframes.strip", "unitframes.elite", "unitframes.status", "unitframes.lossFlash" }
-- A slider or a colour picker changes a general setting on every step. The work that follows waits for the last step.
local SETTLE = 0.2
-- Modules that read a setting of another page, or a border or background row of their own page that only repaints the outlines (Changed), so a
-- change of it refreshes them too: one module key, or a list of them.
local READERS = {
	["castbars.castColour"] = "hud", ["castbars.channelColour"] = "hud", ["castbars.craftColour"] = "hud",
	-- The windows of Bags and the Gear comparison window of Chat and tooltips (GearWindow.lua) take the look of the Windows page: Window opacity,
	-- Button and slot colour, Highlight colour and Icon crop. The chat input box takes the Highlight colour as well (Border while typing). The
	-- Compare gear button on the Character window (GearButton.lua) takes it each time its driver starts, as that window opens and as Chat and
	-- tooltips refresh. The rows of the Spells and gear tab are read by Chat and tooltips alone, whose refresh they bring, and Button on the
	-- Character window by its own call (Config.lua, changed), so none of them is here.
	["windows.accent"] = { "chat", "bags" }, ["windows.panel"] = { "chat", "bags" }, ["windows.opacity"] = { "chat", "bags" },
	["windows.crop"] = { "chat", "bags" },
	-- The count on Sell junk (N) of Bags follows Sell at most 12 at a time of Errands (ns.ErrandsJunkCount).
	["errands.sellTwelve"] = "bags",
	-- A bar the bar block holds with its own Background panel has no panel from the Action bars page.
	["barblock.background"] = "actionbars",
	-- A tracker row below the display hangs under the Cooldown icons row, which these settings size and place.
	["cooldowns.place"] = "trackers", ["cooldowns.size"] = "trackers", ["cooldowns.spacing"] = "trackers", ["cooldowns.perRow"] = "trackers",
	["cooldowns.rows"] = "trackers",
	-- Your buffs leaves out what Your own defensives already shows. A change of the trackers reaches it through the layout of Trackers.lua.
	["defensives.own"] = "ownbuffs", ["defensives.enabled"] = "ownbuffs", ["defensives.place"] = "ownbuffs",
	-- The health text of a nameplate follows Number style of the unit frames.
	["unitframes.numberStyle"] = "nameplates",
	-- The hit table at For tanks and damage dealers follows the player's role, which Your role of nameplate threat can make a tank (ns.PlayerRole),
	-- and so do the spells the gear comparison of Chat and tooltips counts by default and where it counts the player standing (GearLines.lua).
	["nameplates.threatRole"] = { "hud", "chat" },
	-- The gear comparison counts the hit cap of the hit table at Hit cap against a boss: As on the Hit table tab (Config.lua, chat.gearRules).
	["hud.hitTableRules"] = "chat",
	-- The name row, the fade, the trough and the rounded lines of unit frames follow them.
	["unitframes.lookOwn"] = "unitframes", ["unitframes.lookBorder"] = "unitframes", ["unitframes.lookBack"] = "unitframes",
	["unitframes.lookBackAlpha"] = "unitframes",
}

local db
local charDB
-- The profile in use: its name, its table, and the options table inside it.
local current = DEFAULT
local profile
local values
-- The table ns.Get reads while a drawing of Flat UI setup paints (ns.Viewing), or nil. It holds draft values, falls to the start profile, and its field
-- spots is the table of positions ns.Spots gives meanwhile.
local viewing
-- "Name - Realm" of this character, or nil when the client did not say.
local characterKey
local defs = {}
local modules = {}
local status = {}
local outlines = setmetatable({}, { __mode = "k" })
-- The module key of the code running inside ns.Try, ns.Each or ns.EachPart, or nil. An outline made there belongs to that module's page.
local running
-- The pages whose rows can give their outlines a border and a background of their own, and the row prefixes (look: lookOwn, lookBorder, lookBack,
-- lookBackAlpha; tip: tipOwn, tipBorder, for the tooltips) a changed row must repaint the outlines for.
local AREAS = { nameplates = true, actionbars = true, unitframes = true, hud = true, chat = true }
local PREFIXES = { look = true, tip = true }
local SUFFIXES = { Own = true, Border = true, Back = true, BackAlpha = true }
-- Frames and textures this addon made, so a module that walks Blizzard's frames skips them.
local own = setmetatable({}, { __mode = "k" })
local afterCombat = {}
local blocked = {}
local blockedTotal, blockedLast = 0, nil
local loggedIn = false
local resizePending = false
local resetNotice = false
local settleCount = 0
local screenHeight

ns.MODULE_ORDER = MODULE_ORDER
ns.modules = modules
ns.Own = own

-- Every setting of ns.PAGES by its saved path. A row belongs to item.page, else to the owner of the page it is listed on, else to that page, so
-- a page listed under another keeps the saved paths of the rows that moved onto it. LoadSettings runs it again for rows added after this file.
local function Define()
	for path in pairs(defs) do
		defs[path] = nil
	end
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			if item.key then
				local owner = item.page or page.owner or page.key
				item.path = owner .. "." .. item.key
				item.needsPath = item.needs and (owner .. "." .. item.needs) or nil
				defs[item.path] = item
			end
		end
	end
end
Define()

-- True for a row that holds no value of its own in the profile: the game or another function of ns holds it.
local function Unsaved(def)
	return def.live == true or def.cvar ~= nil or def.get ~= nil or def.set ~= nil
end
ns.RowUnsaved = Unsaved

-- True for a row that acts at once and does not belong to a module: it is not greyed by the switch of its page and refreshes no module.
function ns.RowLive(item)
	return item.live == true or item.cvar ~= nil
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end
ns.IsSecret = IsSecret

-- True for a real number: not secret, not NaN, not infinite.
local function Finite(value)
	return not IsSecret(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
ns.Finite = Finite

-- True for a frame addons may not touch, and for anything that is not a frame.
local function Forbidden(frame)
	if frame == nil or IsSecret(frame) or type(frame) ~= "table" then
		return true
	end
	local ok, usable = pcall(function()
		local forbidden = frame:IsForbidden()
		return not IsSecret(forbidden) and forbidden == false
	end)
	return not (ok and usable)
end
ns.Forbidden = Forbidden

-- Elite, rare and boss ---------------------------------------------------------------------

local GOLD, SILVER, RED = { 1, 0.82, 0 }, { 0.78, 0.80, 0.84 }, { 1, 0.35, 0.24 }
-- What is shown for each kind of unit: its word, the mark after its level, the colour of its border, and for a Rare Elite a second
-- line of another colour inside it. A boss has the skull or ?? the game shows for its level and no mark.
ns.KINDS = {
	elite = { word = "Elite", mark = "+", colour = GOLD },
	rare = { word = "Rare", mark = "R", colour = SILVER },
	rareelite = { word = "Rare Elite", mark = "R+", colour = SILVER, inner = GOLD },
	boss = { word = "Boss", colour = RED },
}

-- The first answer of a call of the client, or nil when the client lacks it, the call raises, or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) == "function" then
		local ok, answer = pcall(fn, ...)
		if ok and not IsSecret(answer) then
			return answer
		end
	end
end

-- "boss", "rareelite", "rare" or "elite" for a unit, and nil for any other unit, for a unit token or a classification the client withholds,
-- and for a client without UnitClassification. A boss mob is a boss whatever its classification says.
function ns.UnitKind(unit)
	if IsSecret(unit) or type(unit) ~= "string" then
		return nil
	end
	local class = Ask(UnitClassification, unit)
	if type(class) ~= "string" then
		return nil
	end
	if Ask(UnitIsBossMob, unit) == true or class == "worldboss" then
		return "boss"
	end
	if class == "elite" or class == "rare" or class == "rareelite" then
		return class
	end
	return nil
end

-- The player's role ------------------------------------------------------------------------

-- The role of each talent tree of a class, in the game's order of its trees: the order Forever's talent window draws them in, left to right.
local ROLE_TREES = {
	WARRIOR = { "damage", "damage", "tank" }, PALADIN = { "healer", "tank", "damage" }, PRIEST = { "healer", "healer", "damage" },
	SHAMAN = { "damage", "damage", "healer" }, DRUID = { "damage", "damage", "healer" }, HUNTER = { "damage", "damage", "damage" },
	ROGUE = { "damage", "damage", "damage" }, MAGE = { "damage", "damage", "damage" }, WARLOCK = { "damage", "damage", "damage" },
}
-- The roles a group gives, by the word of UnitGroupRolesAssigned (UnitDocumentation.lua:1318-1332), which is NONE for none.
local ROLE_GIVEN = { TANK = "tank", HEALER = "healer", DAMAGER = "damage" }

-- True for a string the client did not withhold.
local function IsText(value)
	return not IsSecret(value) and type(value) == "string"
end

-- t[key], for pcall.
local function Index(t, key)
	return t[key]
end

-- A field of a table the client gave, or nil when the table or the field is withheld, or reading it raises.
local function Field(t, key)
	if IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(Index, t, key)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- A function of one of the client's tables (C_Traits and the others), or nil when the client has none.
local function Api(space, name)
	local fn = Field(_G[space], name)
	return type(fn) == "function" and fn or nil
end

-- The answer of MostPoints for each set of talents, by its config ID, from the last read that found one while no pick waited unapplied on the set:
-- { place, name }, or {} when no tree had a point then.
local unstaged = {}

-- The talent tree of the class with the most points spent in it: its place in the game's order of the trees and its name, or nil when no tree has a
-- point or the client does not say. On Forever a class has one specialization (the talent window keys its art by one specialization per class,
-- Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentUtil.lua:13-40), and the three trees of old are the node groups of its one tree of
-- C_Traits, which the talent window reads for the headers over its trees (Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua:82-109, 331-344): the
-- groups of the tree in the order the client gives them, drawn left to right (C_Traits.GetGroupDisplayInfoByTreeID,
-- SharedTraitsDocumentation.lua:297-310, with groupID and displayName, :1080-1091), and the points spent in each, the spent of the first currency of
-- its entry (C_Traits.GetGroupCurrencyInfo, :281-295, each entry naming its group by traitNodeGroupID, :972-979, :1188-1198). The tree is the first
-- of the treeIDs of the set of talents in use (C_Traits.GetConfigInfo, :201-215, :1013-1023), as the window takes it
-- (Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:1310-1324), and the set in use is the one the window shows as it opens
-- (ClassTalents/Blizzard_ClassTalentsFrame.lua:147-150, 883-902): C_ClassTalents.GetActiveConfigID (ClassTalentsDocumentation.lua:73-80), else, as
-- Forever's window falls back, the set of the active group of dual spec (C_SpecializationInfo.GetCombatConfigIDForSpecGroup of GetActiveSpecGroup,
-- SpecializationInfoDocumentation.lua:41-55, 90-103; Camelot:111-121). Only the talents applied count. The window stages the player's picks on that
-- same set until they are applied or undone (its Apply and Undo: Camelot/ClassTalents/Blizzard_ClassTalentsFrame.xml:441, 517; ClassTalents:90-92)
-- and keeps them when it hides (its OnHide calls no RollbackConfig: Blizzard_SharedTalentFrame.lua:300-308, ClassTalents:295-309, Camelot:50-55),
-- and its headers count them by all it shows: it draws them again with each pick (TRAIT_TREE_CURRENCY_INFO_UPDATED,
-- Blizzard_SharedTalentFrame.lua:338-342; ClassTalents:765-774) and after Undo (ClassTalents:1190-1195), it counts its own points with the picks
-- (excludeStagedChangesForCurrencies false, Blizzard_SharedTalentFrame.xml:43, .lua:1359), and C_Traits.GetGroupCurrencyInfo has no flag to leave
-- them out, as GetTreeCurrencyInfo has (:537-552). So while the client says a pick waits on the set (C_Traits.ConfigHasStagedChanges, :107-120, as
-- the window asks, ClassTalents:1256-1262), the answer is the last one found for that set while none waited (unstaged), or nil before one was found,
-- which leaves the role to the class. Each call is in apis.yaml of the client, and every answer passes ns.IsSecret or ns.Finite before it is
-- compared or used as a key. With another number of groups than the class has trees the order would tell nothing, so that gives nil too.
local function MostPoints(count)
	local config = Ask(Api("C_ClassTalents", "GetActiveConfigID"))
	if not Finite(config) then
		local group = Ask(Api("C_SpecializationInfo", "GetActiveSpecGroup"))
		config = Finite(group) and Ask(Api("C_SpecializationInfo", "GetCombatConfigIDForSpecGroup"), group) or nil
	end
	if not Finite(config) then
		return nil
	end
	-- A pick waits unapplied: the answer found before it.
	if Ask(Api("C_Traits", "ConfigHasStagedChanges"), config) == true then
		local found = unstaged[config]
		if found then
			return found[1], found[2]
		end
		return nil
	end
	local tree = Field(Field(Ask(Api("C_Traits", "GetConfigInfo"), config), "treeIDs"), 1)
	if not Finite(tree) then
		return nil
	end
	local shown = Ask(Api("C_Traits", "GetGroupDisplayInfoByTreeID"), tree)
	if Field(shown, count + 1) ~= nil then
		return nil
	end
	local ids, names = {}, {}
	for place = 1, count do
		local info = Field(shown, place)
		local id, name = Field(info, "groupID"), Field(info, "displayName")
		if not (Finite(id) and IsText(name)) then
			return nil
		end
		ids[place], names[place] = id, name
	end
	local spent = {}
	local entries = Ask(Api("C_Traits", "GetGroupCurrencyInfo"), config, ids)
	for place = 1, count do
		local entry = Field(entries, place)
		local id = Field(entry, "traitNodeGroupID")
		local points = Field(Field(Field(entry, "currencyInfos"), 1), "spent")
		if Finite(id) and Finite(points) then
			spent[id] = points
		end
	end
	local best, most = nil, 0
	for place = 1, count do
		local points = spent[ids[place]]
		if points and points > most then
			best, most = place, points
		end
	end
	local name = best and names[best] or nil
	unstaged[config] = { best, name }
	return best, name
end

-- The player's role, "tank", "healer" or "damage", the sentence that says why as Flat UI setup suggests from it, and what it was read from, as a
-- short phrase for /flatui status (the hit table's line; as nameplate threat names its own reason, PlateThreat.lua), from the first that answers:
-- the role the group gave, a tank stance, form or aura as nameplate threat reads it (ns.PlateThreat.Role, PlateThreat.lua, looked up when asked; its
-- reason "your group role" is passed over, as the role the group gives now is read here first), the talent tree with the most points of the talents
-- applied (MostPoints, above), the class, where a priest heals. The sentence and the phrase are nil when the client gives none of them. Flat UI
-- setup suggests from it (SetupWalk.lua, Walk.Role) and the hit table shows by it (HitTable.lua), so the two always agree. It only reads, and a
-- withheld answer counts as none.
function ns.PlayerRole()
	local given = Ask(UnitGroupRolesAssigned, "player")
	if IsText(given) and ROLE_GIVEN[given] then
		return ROLE_GIVEN[given], "Suggested from your group role.", "your group role"
	end
	local threat = ns.PlateThreat
	if type(threat) == "table" and type(threat.Role) == "function" then
		local ok, kind, reason = pcall(threat.Role)
		if ok and IsText(kind) and kind == "tank" and IsText(reason) and reason ~= "your group role" then
			if reason == "your choice" then
				return "tank", "Suggested from your role.", "Your role of nameplate threat"
			end
			return "tank", ("Suggested from %s."):format(reason), reason
		end
	end
	local class = Ask(UnitClassBase, "player")
	class = IsText(class) and class or nil
	local trees = class and ROLE_TREES[class]
	if trees then
		local best, name = MostPoints(#trees)
		if best then
			return trees[best], ("Suggested from your talents: most points in %s."):format(name), ("most points in %s"):format(name)
		end
	end
	if class then
		local word = class:lower()
		return class == "PRIEST" and "healer" or "damage", ("Suggested for a %s."):format(word), ("your class, %s"):format(word)
	end
	return "damage", nil, nil
end

-- Options ---------------------------------------------------------------------------------

-- The lines of a choice row: its list, or what the function of ns it names returns when asked now.
function ns.Choices(def)
	local choices = def.choices
	if type(choices) == "string" then
		local call = ns[choices]
		local ok, list = false, nil
		if type(call) == "function" then
			ok, list = pcall(call, def)
		end
		return ok and type(list) == "table" and list or {}
	end
	return choices or {}
end

local function Normalise(def, value)
	if def.kind == "bool" then
		if type(value) == "boolean" then
			return value
		end
	elseif def.kind == "number" then
		if type(value) == "number" then
			local stepped = math.floor((value - def.min) / def.step + 0.5) * def.step + def.min
			return math.max(def.min, math.min(def.max, stepped))
		end
	elseif def.kind == "colour" then
		if type(value) == "string" and value:find("^%x%x%x%x%x%x%x%x$") then
			return value:lower()
		end
	elseif def.kind == "choice" then
		for _, choice in ipairs(ns.Choices(def)) do
			if choice[1] == value then
				return value
			end
		end
	end
	return nil
end

-- Choice ids that were renamed, by saved path: a saved value of the old id is the new one. The text outline rows had "outline" for Thin, and
-- Whose hits had Every hit while you attack, which Yours took in.
local RENAMED = { ["trackers.grow"] = { middle = "center" }, ["partycd.show"] = { used = "cooling" }, ["combattext.whose"] = { mine = "one" } }
for _, path in ipairs({ "fonts.outline", "chat.outline", "actionbars.textOutline" }) do
	RENAMED[path] = { outline = "thin" }
end
-- Text size of the hit table was a slider of 50 to 200% until 0.5.26 and is a choice of sizes, ids in text, since: a saved number, or the text of
-- one, that is no choice reads as the nearest choice, a tie as the larger.
RENAMED["hud.hitTableSize"] = "nearest"

local function Renamed(path, value)
	local map = RENAMED[path]
	if map == "nearest" then
		local number, def = tonumber(value), defs[path]
		if number == nil or def == nil or Normalise(def, value) ~= nil then
			return value
		end
		local best, gap = value, nil
		for _, choice in ipairs(ns.Choices(def)) do
			local id = tonumber(choice[1])
			if id and (gap == nil or math.abs(id - number) <= gap) then
				best, gap = choice[1], math.abs(id - number)
			end
		end
		return best
	end
	return map and type(value) == "string" and map[value] or value
end

-- A value as a setting of this path would hold it (clamped to its range and step, a colour in lower case, a choice that exists), or nil when the
-- path is no setting or the value does not fit it. Nothing is written.
function ns.Normalised(path, value)
	local def = defs[path]
	if def == nil then
		return nil
	end
	return Normalise(def, Renamed(path, value))
end

-- The setting that must be on for this one to apply, if any.
function ns.Needs(path)
	local def = defs[path]
	return def and def.needsPath or nil
end

-- The row that holds a setting, or nil for a path that is no setting.
function ns.Def(path)
	return defs[path]
end

-- True while the setting a control needs is on. A control that lists values in needsIn needs that setting to have one of them instead. A link
-- of the chain further from the control is judged by the needsIn of the row that names it, so a bool row that needs a choice row is met only
-- while that choice has one of the values the bool row lists.
function ns.NeedMet(item, path)
	local value = ns.Get(path)
	local row = item
	for _ = 1, 8 do
		if row == nil then
			break
		end
		if row.needsPath == path then
			if row.needsIn ~= nil then
				for _, allowed in ipairs(row.needsIn) do
					if value == allowed then
						return true
					end
				end
				return false
			end
			break
		end
		row = row.needsPath and defs[row.needsPath] or nil
	end
	return value == true
end

-- True when the player has chosen a value for this setting.
function ns.IsSet(path)
	return values ~= nil and values[path] ~= nil
end

-- Rows that hold a game setting ----------------------------------------------------------

-- The text of a CVar, or nil when the client lacks it, withholds it or has no such CVar. C_CVar.GetCVar takes a name and nothing else.
local function CVarText(name)
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" or type(name) ~= "string" then
		return nil
	end
	local ok, raw = pcall(C_CVar.GetCVar, name)
	if ok and not IsSecret(raw) and type(raw) == "string" then
		return raw
	end
	return nil
end

-- The value a CVar row shows: a bool is "1" or not, a number is the CVar times def.scale, a choice is the id whose def.values text it is.
function ns.CVarGet(def)
	local raw = CVarText(def.cvar)
	if raw == nil then
		return nil
	end
	if def.kind == "bool" then
		return raw == "1"
	elseif def.kind == "number" then
		local number = tonumber(raw)
		if number == nil then
			return nil
		end
		-- A CVar that reads below zero where the game means "not used" shows as def.negative.
		if number < 0 and def.negative ~= nil then
			return def.negative
		end
		-- Rounded to a millionth, so 1.1 times 100 is 110 and not 110.00000000000001.
		return math.floor(number * (def.scale or 1) * 1e6 + 0.5) / 1e6
	elseif def.kind == "choice" and type(def.values) == "table" then
		for id, text in pairs(def.values) do
			if text == raw then
				return id
			end
		end
	end
	return nil
end

-- The text a CVar row writes for a value, the reverse of ns.CVarGet.
local function CVarWrite(def, value)
	if def.kind == "bool" then
		return value and "1" or "0"
	elseif def.kind == "number" then
		if def.negative ~= nil and value == def.negative then
			return "-1"
		end
		return ("%.6g"):format(value / (def.scale or 1))
	elseif def.kind == "choice" and type(def.values) == "table" then
		return def.values[value]
	end
	return nil
end

-- True when the value a CVar row reads now is the one asked for.
local function Same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= 1e-6 * math.max(1, math.abs(b))
	end
	return a == b
end
ns.CVarSame = Same

-- The CVars the game kept at another value after a write of this addon, by name.
local refused = {}
function ns.CVarRefused(name)
	return refused[name] == true
end
function ns.CVarMarkRefused(name, state)
	refused[name] = state or nil
end

-- The words for a value the game kept: "on", the text of a choice, or "at 45 yd".
function ns.CVarShown(def, now)
	if def.kind == "bool" and type(now) == "boolean" then
		return now and "on" or "off"
	elseif def.kind == "choice" and now ~= nil then
		local shown = tostring(now)
		for _, line in ipairs(ns.Choices(def)) do
			if line.id == now and line.text then
				shown = line.text
			end
		end
		return shown
	elseif now ~= nil then
		return "at " .. (type(now) == "number" and ("%.6g"):format(now) or tostring(now)) .. (def.unit or "")
	end
	return "its own value"
end

-- Writes the CVar out of combat, reads it back, and says so in one line when the game kept another value; quiet leaves the line to the caller. Returns
-- false when nothing was written, else true and the value read back (nil when the write waits for the end of a fight or the game does not say).
function ns.CVarSet(def, value, quiet)
	local text = CVarWrite(def, value)
	if text == nil or type(C_CVar) ~= "table" or type(C_CVar.SetCVar) ~= "function" or CVarText(def.cvar) == nil then
		return false
	end
	local kept
	ns.OutOfCombat(function()
		pcall(C_CVar.SetCVar, def.cvar, text)
		local now = ns.CVarGet(def)
		kept = now
		refused[def.cvar] = not Same(now, value) or nil
		if not Same(now, value) and not quiet then
			print(("Flat UI: the game kept %s %s."):format(def.label or def.cvar, ns.CVarShown(def, now)))
		end
	end)
	return true, kept
end

-- False for a CVar row whose CVar this client does not have: it is left off the window and the game's options.
function ns.RowShown(path)
	local def = defs[path]
	if def and def.cvar then
		return CVarText(def.cvar) ~= nil
	end
	return true
end

-- True when a page has a setting to show: a page with none is left out of the window and of the game's options. With panel true, a block of
-- the window's own (kind entries) counts as well.
function ns.PageHasRows(page, panel)
	for _, item in ipairs(page) do
		if (item.key and (item.path == nil or ns.RowShown(item.path))) or (panel == true and item.kind == "entries") then
			return true
		end
	end
	return false
end

-- The value a row holds outside the profile, or nil when there is none to read.
local function Routed(def)
	local value
	if def.get then
		local call = ns[def.get]
		if type(call) == "function" then
			local ok, got = pcall(call, def)
			if ok then
				value = got
			end
		end
	elseif def.cvar then
		value = ns.CVarGet(def)
	end
	return value
end

function ns.Get(path)
	local def = defs[path]
	if not def then
		return nil
	end
	if Unsaved(def) then
		-- A draft of Flat UI setup holds a game setting too, until Finish writes it.
		local drafted = viewing and viewing[path]
		if drafted ~= nil then
			return drafted
		end
		local value = Routed(def)
		if value == nil then
			return def.default
		end
		return value
	end
	local value = values and values[path]
	if value == nil then
		return def.default
	end
	return value
end

-- What Viewing leaves behind: the view and the values in use before it, whatever fn did. Returns what pcall gave.
local function ViewDone(was, wasValues, ...)
	viewing, values = was, wasValues
	return ...
end

-- Runs fn(...) with ns.Get reading `view` in place of the profile in use, and puts the profile back, also when fn raises. Views stack: a view run
-- inside another is left for the first. Returns pcall's answer: true and what fn returned, or false and the error. Nothing is written to a profile.
function ns.Viewing(view, fn, ...)
	local was, wasValues = viewing, values
	viewing, values = view, view
	return ViewDone(was, wasValues, pcall(fn, ...))
end

-- A view (ns.Viewing) of the profile in use, read when asked: the previews of the options window draw under it, so they show a change at once.
ns.LiveView = setmetatable({}, { __index = function(_, key)
	if key == "spots" then
		return profile and profile.movers
	end
	return profile and profile.options and profile.options[key]
end })

-- Red, green and blue of a colour option, 0 to 1.
function ns.Colour(path)
	local hex = ns.Get(path)
	return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
end

function ns.Enabled(key)
	return db ~= nil and ns.Get(key .. ".enabled") == true and not status[key].error
end

-- True while Leave the game's action bars alone is on (the default). Flat UI then makes no call that places, groups, fades or restyles the game's
-- stance, pet or status bars, and none that places, sizes, fades or writes a field on the micro menu, or that places, sizes or writes a field on the
-- bag bar (their pictures and buttons get the Flat UI look, Fading's Bag bar row writes the alpha of the bag bar, Fade.lua, and Hidden frames' Bag
-- bar row puts it under a hidden frame in a secure snippet, Hide.lua), and registers no setting of its own in the game's settings registry. The game's eight action bars
-- (bars 1 to 8) are covered by Action buttons (actionbars.own): with Flat UI's buttons they are parked by alpha and mouse only, with the game's
-- buttons Flat UI leaves them alone. A click on an action button reads the bar, the button and the settings registry, and a call of this addon that
-- touched one of them leaves the click refused (UseAction, ADDON_ACTION_FORBIDDEN).
function ns.HandsOff()
	return ns.Get("general.handsOff") == true
end

-- The row changed: say once in chat that a reload applies it.
function ns.HandsOffChanged()
	if type(print) == "function" then
		print("Flat UI: Leave the game's action bars alone applies after /reload.")
	end
end

-- The row Action buttons changed: say once in chat that a reload applies it.
function ns.OwnChanged()
	if type(print) == "function" then
		print("Flat UI: Action buttons applies after /reload.")
	end
end

-- A module that can still change something the click path reads says so here: fn returns a line for /flatui status, or nil. HandsOff on is the
-- state in which none does.
local clickReporters = {}
function ns.ClickPathReporter(fn)
	clickReporters[#clickReporters + 1] = fn
end

-- The lines of /flatui status about what Flat UI changed on the game's bars, buttons and settings registry.
function ns.ClickPathLines()
	local lines = {}
	for _, fn in ipairs(clickReporters) do
		local ok, line = pcall(fn)
		if ok and type(line) == "string" then
			lines[#lines + 1] = line
		end
	end
	return lines
end

-- One line of /flatui status about Flat UI's own action buttons each: OwnBars.lua answers ns.OwnStatus(id) with the line or nil, and nothing is
-- said before that file has run. The first line also says so when the game's buttons are set.
local OWN_STATUS = { "buttons", "waiting", "page", "keys", "flyoutkeys", "parked", "leave", "taint", "totem" }
for _, id in ipairs(OWN_STATUS) do
	ns.ClickPathReporter(function()
		local line = ns.OwnStatus and ns.OwnStatus(id)
		if line == nil and id == "buttons" and ns.Get("actionbars.own") == "game" then
			line = "Action buttons: the game's."
		end
		return line
	end)
end

-- Blizzard art -----------------------------------------------------------------------------

-- Blizzard shows and hides most of its border art itself, so the art is made transparent
-- and left in place.
function ns.SetFaded(region, faded)
	if region ~= nil and not IsSecret(region) then
		pcall(region.SetAlpha, region, faded and 0 or 1)
	end
end

-- For art whose alpha Blizzard sets and whose visibility it leaves alone.
function ns.SetHidden(region, hidden)
	if region ~= nil and not IsSecret(region) then
		pcall(region.SetShown, region, not hidden)
	end
end

-- The region of a frame that draws the named atlas, for art that has no key.
function ns.RegionWithAtlas(frame, atlas)
	if Forbidden(frame) or not frame.GetRegions then
		return nil
	end
	local wanted = atlas:lower()
	for _, region in ipairs({ frame:GetRegions() }) do
		if not IsSecret(region) and region.GetAtlas then
			local ok, name = pcall(region.GetAtlas, region)
			if ok and not IsSecret(name) and type(name) == "string" and name:lower() == wanted then
				return region
			end
		end
	end
	return nil
end

-- Status bar fills -------------------------------------------------------------------------

-- Per status bar: { atlas = what the game drew, flat = true while the fill is the addon's, r, g, b = its colour,
-- texture = the image file when the fill is one, coloured = true while the addon has set the colour of the bar }
local fills = setmetatable({}, { __mode = "k" })

-- The image file of each bar texture. Flat has none: it is a solid colour.
local BAR_FILES = {
	soft = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Soft.tga",
	shaded = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Shaded.tga",
	gloss = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Gloss.tga",
	stripes = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Stripes.tga",
	edge = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Edge.tga",
	fade = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fade.tga",
	-- Files the game ships: the status bar, the skills bar and the targeting frame fill.
	game = "Interface\\TargetingFrame\\UI-StatusBar",
	skills = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
	targeting = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
}
-- The bar textures a row offers, in order.
local BAR_CHOICES = ns.BAR_CHOICES

-- The image file of a bar texture by the id a row saved, or nil for a solid colour. No id, or "default", is the texture chosen on the Flat UI page.
function ns.BarTexture(id)
	if id == nil or id == "default" then
		id = ns.Get("general.barTexture")
	end
	return BAR_FILES[id]
end

-- The lines of a bar texture row. A row that names it is called with the row as its argument; true as the argument puts a first line
-- "default" (the Flat UI page's texture) before the others.
function ns.BarChoices(withDefault)
	local list = {}
	if withDefault == true then
		list[1] = { "default", "Same as the Flat UI page" }
	end
	for _, choice in ipairs(BAR_CHOICES) do
		list[#list + 1] = { choice[1], choice[2] }
	end
	return list
end

-- The same lines with the first, for rows that may follow the Flat UI page.
function ns.BarChoicesDefault()
	return ns.BarChoices(true)
end

-- The image file of one bar texture by its id (soft, shaded, gloss, stripes, edge, fade, game, skills, targeting), or nil.
function ns.BarFile(id)
	return BAR_FILES[id]
end

-- The region that draws the fill of a status bar, or nil.
function ns.FillRegion(bar)
	if Forbidden(bar) then
		return nil
	end
	local ok, region = pcall(bar.GetStatusBarTexture, bar)
	if not ok or region == nil or IsSecret(region) or type(region) ~= "table" then
		return nil
	end
	return region
end

-- The atlas a texture draws, or nil for none. The second value is true when the texture could
-- not be asked or the answer is withheld.
local function AtlasOf(region)
	local ok, atlas = pcall(region.GetAtlas, region)
	if not ok or IsSecret(atlas) or (atlas ~= nil and type(atlas) ~= "string") then
		return nil, true
	end
	if atlas == "" then
		atlas = nil
	end
	return atlas, false
end

-- True when a call that says whether it worked did not raise and did not say no.
local function Accepted(ok, done)
	return ok and (IsSecret(done) or done ~= false)
end

-- Puts a texture on the fill of a status bar. False when the game refused.
local function SetFillTexture(bar, asset)
	return Accepted(pcall(bar.SetStatusBarTexture, bar, asset))
end

-- An image file as the fill of a status bar, with the colour as the colour of the bar. The tint stays
-- white when the game colours the bar itself.
local function ImageFill(bar, record, texture, r, g, b, gameColour)
	if not (record.flat and record.texture == texture) then
		if not SetFillTexture(bar, texture) then
			return false, true
		end
		record.flat, record.texture = true, texture
	end
	if not gameColour then
		if not pcall(bar.SetStatusBarColor, bar, r, g, b, 1) then
			ns.RestoreFill(bar)
			return false, true
		end
		record.coloured = true
	end
	record.r, record.g, record.b = r, g, b
	return true
end

-- Makes the fill of a status bar a solid colour, or the image file of the chosen bar texture in that
-- colour. The region stays, and with it everything the game anchored to it. fallbackAtlas is put back by
-- RestoreFill when the region does not say which atlas it draws. gameColour is true for a bar the game
-- colours itself, which a file takes the colour from. Returns true while the fill is in place, false when
-- the game's fill is left alone (true as a second value when the game refused the call, nothing when there
-- is no atlas to put back), nil when the bar has no fill region. file is an image file that takes the place of the chosen bar texture for
-- this call, or false for a solid colour whatever the bar texture is.
function ns.FlatFill(bar, r, g, b, fallbackAtlas, gameColour, file)
	local region = ns.FillRegion(bar)
	if not region then
		return nil
	end
	local record = fills[bar]
	if not record then
		record = {}
		fills[bar] = record
	end
	local atlas, unreadable = AtlasOf(region)
	if record.flat and (atlas or unreadable) then
		-- A name on the region means the game drew its fill again.
		record.flat = nil
	end
	if not record.flat then
		record.atlas = atlas or record.atlas or fallbackAtlas
		if not record.atlas then
			return false
		end
	end
	local texture = file
	if texture == nil then
		texture = ns.BarTexture()
	elseif texture == false then
		texture = nil
	end
	if record.flat and record.texture == texture and record.r == r and record.g == g and record.b == b then
		return true
	end
	if texture then
		return ImageFill(bar, record, texture, r, g, b, gameColour)
	end
	if record.coloured then
		-- The tint of an image fill would multiply the solid colour.
		if not pcall(bar.SetStatusBarColor, bar, 1, 1, 1, 1) then
			return false, true
		end
		record.coloured = nil
	end
	if not pcall(bar.SetColorFill, bar, r, g, b, 1) then
		return false, true
	end
	record.flat, record.r, record.g, record.b = true, r, g, b
	record.texture = nil
	return true
end

-- Puts back the fill FlatFill replaced. Returns false when the game refused.
function ns.RestoreFill(bar)
	local record = fills[bar]
	if not (record and record.flat) then
		return true
	end
	if Forbidden(bar) then
		return false
	end
	if not SetFillTexture(bar, record.atlas) then
		return false
	end
	-- The game never colours a bar it leaves white, so the tint set here goes back to white.
	if record.coloured and not pcall(bar.SetStatusBarColor, bar, 1, 1, 1, 1) then
		return false
	end
	record.flat, record.r, record.g, record.b = nil, nil, nil, nil
	record.texture, record.coloured = nil, nil
	return true
end

-- Red, green and blue of the player's class colour, or nil.
function ns.ClassColour()
	return ns.ClassColourOf("player")
end

-- Red, green and blue of the class colour of a unit, or nil when the unit is not a player or the client withholds its class (UnitClass is
-- withheld while unit identity is restricted).
function ns.ClassColourOf(unit)
	if unit == nil or UnitClass == nil or RAID_CLASS_COLORS == nil then
		return nil
	end
	local ok, _, class = pcall(UnitClass, unit)
	if not ok or IsSecret(class) or type(class) ~= "string" then
		return nil
	end
	local colour = RAID_CLASS_COLORS[class]
	if colour == nil or IsSecret(colour) or type(colour) ~= "table" then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return r, g, b
end

-- A value from a unit call that is neither secret nor missing, or nil.
local function Plain(value)
	if value == nil or IsSecret(value) then
		return nil
	end
	return value
end

-- Red, green and blue the game gives a unit by how it stands to the player (a tapped unit is grey), or nil. With Custom reaction colours on, a
-- unit another player tapped has the tapped colour and the rest the hostile, neutral or friendly colour (UnitReaction 3 and below, 4, 5 and above).
function ns.ReactionColour(unit)
	if unit == nil then
		return nil
	end
	if ns.Get("general.reactionOwn") == true and UnitReaction ~= nil then
		if UnitIsTapDenied ~= nil and UnitPlayerControlled ~= nil then
			local ok, denied = pcall(UnitIsTapDenied, unit)
			if ok and Plain(denied) == true then
				local okControl, controlled = pcall(UnitPlayerControlled, unit)
				if okControl and Plain(controlled) == false then
					return ns.Colour("general.reactionTapped")
				end
			end
		end
		local okReaction, reaction = pcall(UnitReaction, unit, "player")
		reaction = okReaction and Plain(reaction) or nil
		if type(reaction) == "number" and reaction == reaction then
			return ns.Colour(reaction <= 3 and "general.reactionHostile" or reaction == 4 and "general.reactionNeutral" or "general.reactionFriendly")
		end
	end
	if UnitSelectionColor == nil then
		return nil
	end
	local ok, r, g, b = pcall(UnitSelectionColor, unit)
	if not ok or IsSecret(r) or IsSecret(g) or IsSecret(b) then
		return nil
	end
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	return r, g, b
end

-- The rows of the custom power colours.
local POWER_ROWS = { MANA = "powerMana", RAGE = "powerRage", ENERGY = "powerEnergy", FOCUS = "powerFocus", RUNIC_POWER = "powerRunic" }

-- Red, green and blue of a power token (MANA, RAGE, ENERGY, FOCUS, RUNIC_POWER, or any other the game colours): the colour of its row with
-- Custom power colours on, else the game's own (PowerBarColor), or nil.
function ns.PowerColour(token)
	if type(token) ~= "string" or IsSecret(token) then
		return nil
	end
	local row = POWER_ROWS[token]
	if row and ns.Get("general.powerOwn") == true then
		return ns.Colour("general." .. row)
	end
	local colours = PowerBarColor
	local colour = type(colours) == "table" and colours[token] or nil
	if type(colour) ~= "table" or IsSecret(colour) then
		return nil
	end
	local r, g, b = colour.r, colour.g, colour.b
	if not (Finite(r) and Finite(g) and Finite(b)) then
		return nil
	end
	return r, g, b
end

-- The atlas names the game has for a class icon.
local CLASS_ART = { "classicon-%s", "groupfinder-icon-class-%s" }
local classAtlas = {}
-- The classes the game has no icon art for, for /flatui status.
local noArt = {}

local function AtlasExists(name)
	local api = C_Texture
	if type(api) == "table" and not IsSecret(api) then
		if type(api.GetAtlasExists) == "function" then
			local ok, exists = pcall(api.GetAtlasExists, name)
			return ok and not IsSecret(exists) and exists == true
		elseif type(api.GetAtlasInfo) == "function" then
			local ok, info = pcall(api.GetAtlasInfo, name)
			return ok and info ~= nil
		end
	end
	return false
end

-- The atlas of a class token, or nil when the client has no art for that class. /flatui status names a class without art.
function ns.ClassAtlas(token)
	if type(token) ~= "string" or IsSecret(token) then
		return nil
	end
	local atlas = classAtlas[token]
	if atlas == nil then
		atlas = false
		for _, pattern in ipairs(CLASS_ART) do
			local name = pattern:format(token:lower())
			if AtlasExists(name) then
				atlas = name
				break
			end
		end
		classAtlas[token] = atlas
		if not atlas then
			noArt[#noArt + 1] = token
		end
	end
	return atlas or nil
end

-- The colour of each faction of the player.
local FACTION_COLOURS = { Alliance = { 0.29, 0.33, 0.91 }, Horde = { 0.90, 0.05, 0.07 } }

-- Red, green and blue of the borders that follow the Border colour source: the Border colour of the Flat UI page, the class colour of the
-- player, or the faction colour. When the class or the faction is not known the Border colour is used.
function ns.BorderRGB()
	local mode = ns.Get("general.borderMode")
	if mode == "class" then
		local r, g, b = ns.ClassColour()
		if r then
			return r, g, b
		end
	elseif mode == "faction" and UnitFactionGroup ~= nil then
		local ok, faction = pcall(UnitFactionGroup, "player")
		local colour = ok and not IsSecret(faction) and type(faction) == "string" and FACTION_COLOURS[faction] or nil
		if colour then
			return colour[1], colour[2], colour[3]
		end
	end
	return ns.Colour("general.border")
end

-- Text sizes -------------------------------------------------------------------------------

-- Per font string: { file, size, flags = the font the game gave it, set = the size set here (nil at the game's size), flagsSet = the flags
-- set here, faceSet = the file set here, colour = the colour the game gave it, colourSet = the colour set here, shadow = the shadow offset the
-- game gave it, shadowSet = true while the offset is set here }
local fonts = setmetatable({}, { __mode = "k" })

-- Sets the look of a font string. spec has any of: percent (of the size the game gave it; 100 or none is that size), flags (nil keeps the
-- game's font flags, a string, the empty string for none, replaces them), face (a font file; nil keeps the game's), r, g, b and a (the text
-- colour; no r puts the game's back) and shadow (true sets the shadow offset to 0, 0; anything else puts the game's back). A part passed as
-- nil goes back to what the game gave. A font more than half a unit away from the size set here, or with another file or flags than set here,
-- is one the game set again, and its size is the new base: the client may round the height it is given. Returns false when the font could
-- not be read or the game raised an error setting it (or answered false to a face), and nothing for a value that is no font string. An answer
-- of false from SetFont without a face is not a refusal: only a raise is.
function ns.TextStyle(fontString, spec)
	if fontString == nil or IsSecret(fontString) or type(fontString) ~= "table" then
		return nil
	end
	spec = type(spec) == "table" and spec or {}
	local percent, flags, face = spec.percent or 100, spec.flags, spec.face
	local colour = spec.r ~= nil and spec.g ~= nil and spec.b ~= nil
	local shadow = spec.shadow == true
	local record = fonts[fontString]
	if record == nil and percent == 100 and flags == nil and face == nil and not colour and not shadow then
		return true
	end
	local ok, file, size, current = pcall(fontString.GetFont, fontString)
	if not ok or IsSecret(file) or IsSecret(size) or IsSecret(current) or type(file) ~= "string" or type(size) ~= "number" or size <= 0
		or (current ~= nil and type(current) ~= "string") then
		return false
	end
	if record == nil then
		record = {}
		fonts[fontString] = record
	end
	-- The game's colour and shadow are read before anything is set.
	if colour and record.colour == nil then
		local okColour, r, g, b, a = pcall(fontString.GetTextColor, fontString)
		if not okColour or not (Finite(r) and Finite(g) and Finite(b)) then
			return false
		end
		record.colour = { r, g, b, Finite(a) and a or 1 }
	end
	if shadow and record.shadow == nil then
		local okShadow, x, y = pcall(fontString.GetShadowOffset, fontString)
		if not okShadow or not (Finite(x) and Finite(y)) then
			return false
		end
		record.shadow = { x, y }
	end
	local ours = (record.set ~= nil or record.flagsSet ~= nil or record.faceSet ~= nil) and math.abs((record.set or record.size) - size) <= 0.5
		and (record.flagsSet == nil or (current or "") == record.flagsSet) and (record.faceSet == nil or file == record.faceSet)
	if not ours then
		record.file, record.size, record.flags, record.set, record.flagsSet, record.faceSet = file, size, current, nil, nil, nil
	end
	local wanted = record.size * percent / 100
	if not (math.abs((record.set or record.size) - wanted) < 0.01 and record.flagsSet == flags and record.faceSet == face) then
		local okSet, result = pcall(fontString.SetFont, fontString, face or record.file, wanted, flags ~= nil and flags or record.flags)
		if not okSet or (face ~= nil and result == false) then
			return false
		end
		record.set = percent ~= 100 and wanted or nil
		record.flagsSet, record.faceSet = flags, face
	end
	if colour then
		local key = ("%s,%s,%s,%s"):format(spec.r, spec.g, spec.b, spec.a or 1)
		if record.colourSet ~= key then
			if not pcall(fontString.SetTextColor, fontString, spec.r, spec.g, spec.b, spec.a or 1) then
				return false
			end
			record.colourSet = key
		end
	elseif record.colourSet then
		local back = record.colour
		if not pcall(fontString.SetTextColor, fontString, back[1], back[2], back[3], back[4]) then
			return false
		end
		record.colourSet, record.colour = nil, nil
	end
	if shadow then
		if not record.shadowSet then
			if not pcall(fontString.SetShadowOffset, fontString, 0, 0) then
				return false
			end
			record.shadowSet = true
		end
	elseif record.shadowSet then
		local back = record.shadow
		if not pcall(fontString.SetShadowOffset, fontString, back[1], back[2]) then
			return false
		end
		record.shadowSet, record.shadow = nil, nil
	end
	return true
end

-- Sets a font string to a percent of the size the game gave it. 100 puts that size back. flags is nil to keep the game's font flags, or a
-- string, the empty string for none, that replaces them; nil after a string puts the game's flags back. See ns.TextStyle for the returns.
function ns.TextSize(fontString, percent, flags)
	return ns.TextStyle(fontString, { percent = percent, flags = flags })
end

-- The faces the addon can offer: id, file and the name a row shows. The files are named in Blizzard_Fonts_Shared (Mainline/Fonts.xml:5, 119, 381;
-- Shared/GameFonts.xml:506).
local FONT_FACES = { { "friz", "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, { "arial", "Fonts\\ARIALN.TTF", "Arial Narrow" },
	{ "morpheus", "Fonts\\MORPHEUS.TTF", "Morpheus" }, { "skurri", "Fonts\\SKURRI.TTF", "Skurri" } }
-- Which of them the client loads, found once by SetFont on a font string of the addon that is never shown.
local fontsOffered

local function FontsOffered()
	if fontsOffered == nil then
		fontsOffered = {}
		local made, probe = pcall(function()
			local probeFrame = CreateFrame("Frame")
			own[probeFrame] = true
			return probeFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		end)
		if made and type(probe) == "table" then
			own[probe] = true
			for _, face in ipairs(FONT_FACES) do
				local ok, loaded = pcall(probe.SetFont, probe, face[2], 12, "")
				fontsOffered[face[1]] = ok and loaded == true
			end
		end
	end
	return fontsOffered
end

-- The font file of a face id, or nil for "default", an id it does not know, or a face the client does not load.
function ns.FontFile(id)
	if not FontsOffered()[id] then
		return nil
	end
	for _, face in ipairs(FONT_FACES) do
		if face[1] == id then
			return face[2]
		end
	end
	return nil
end

-- The lines of a font row: "default" (the game's own font) and the faces the client loads.
function ns.FontChoices()
	local offered = FontsOffered()
	local list = { { "default", "Game font" } }
	for _, face in ipairs(FONT_FACES) do
		if offered[face[1]] then
			list[#list + 1] = { face[1], face[3] }
		end
	end
	return list
end

-- A font string of the addon's own on a frame, in a font object. Nil for a frame the addon may not touch.
function ns.OwnText(parent, layer, fontObject)
	if Forbidden(parent) then
		return nil
	end
	local ok, text = pcall(parent.CreateFontString, parent, nil, layer or "OVERLAY", fontObject)
	if not ok or type(text) ~= "table" or IsSecret(text) then
		return nil
	end
	own[text] = true
	return text
end

-- Hooks ------------------------------------------------------------------------------------

-- Per frame or table, per method, and per global name: the functions that follow it. Each is hooked once, whatever number of functions follow it.
local followed = setmetatable({}, { __mode = "k" })
local followedGlobal = {}

-- Adds fn to the functions run after the call that bucket[key] stands for, hooking the call the first time. False for a function that is no
-- function, without hooksecurefunc at the first hook, or when the game refuses the hook.
local function FollowOnce(bucket, key, hook, fn)
	if type(fn) ~= "function" then
		return false
	end
	local entry = bucket[key]
	if entry == nil then
		if type(hooksecurefunc) ~= "function" then
			return false
		end
		entry = { fns = {} }
		local function dispatch(...)
			for _, call in ipairs(entry.fns) do
				local ok, err = pcall(call, ...)
				if not ok then
					geterrorhandler()(err)
				end
			end
		end
		if not pcall(hook, dispatch) then
			return false
		end
		bucket[key] = entry
	end
	for _, existing in ipairs(entry.fns) do
		if existing == fn then
			return true
		end
	end
	entry.fns[#entry.fns + 1] = fn
	return true
end

-- True while the game's taintLog variable is on. Read each time, so a change made in the game counts at once. A client without the variable,
-- an error and a withheld value all count as off.
function ns.TaintLogging()
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" then
		return false
	end
	local ok, value = pcall(C_CVar.GetCVar, "taintLog")
	return ok and not IsSecret(value) and type(value) == "string" and value ~= "0"
end

-- With taintLog on, every call of a frame method that an addon hooked fails in the client's hook wrapper (1.60.1; see the Forevermore
-- notes), so a log taken that way is not a log of normal play. The hooks on global functions go on working, and a hook on a method is
-- an ordinary field write on the frame (EllesmereUIChat/EllesmereUIChat.lua:4411 and 4493, the instance hooksecurefunc on a chat frame), which is why only
-- methods are held back. Each frame and method is counted once.
local skipped, skippedCount = setmetatable({}, { __mode = "k" }), 0

-- hooksecurefunc(object, method, fn) for a method of a frame or a table. Nothing is hooked, and false comes back, while taintLog is on.
function ns.HookMethod(object, method, fn)
	if ns.TaintLogging() then
		local seen = skipped[object]
		if seen == nil and type(object) == "table" and not IsSecret(object) then
			seen = {}
			skipped[object] = seen
		end
		if seen == nil then
			skippedCount = skippedCount + 1
		elseif not seen[method] then
			seen[method] = true
			skippedCount = skippedCount + 1
		end
		return false
	end
	return (pcall(hooksecurefunc, object, method, fn))
end

-- How many game methods were left unfollowed because taintLog was on.
function ns.TaintSkipped()
	return skippedCount
end

-- fn runs after every call of frame[method], with the arguments of the call. A failure of fn goes to the error handler and nothing else.
-- Returns true when fn follows the call, false when it cannot, nil when the frame is not one addons may touch or has no such method.
function ns.Follow(frame, method, fn)
	if Forbidden(frame) or type(method) ~= "string" or type(frame[method]) ~= "function" then
		return nil
	end
	local bucket = followed[frame]
	if bucket == nil then
		bucket = {}
		followed[frame] = bucket
	end
	return FollowOnce(bucket, method, function(dispatch)
		assert(ns.HookMethod(frame, method, dispatch))
	end, fn)
end

-- The same for a global function by name. Nil when there is no such function.
function ns.FollowGlobal(name, fn)
	if type(name) ~= "string" or type(_G[name]) ~= "function" then
		return nil
	end
	return FollowOnce(followedGlobal, name, function(dispatch)
		hooksecurefunc(name, dispatch)
	end, fn)
end

-- The same for a function in a table (a mixin or a namespace such as C_Container). Nil when the table has no such function.
function ns.FollowTable(source, method, fn)
	if type(source) ~= "table" or IsSecret(source) or type(method) ~= "string" or type(source[method]) ~= "function" then
		return nil
	end
	local bucket = followed[source]
	if bucket == nil then
		bucket = {}
		followed[source] = bucket
	end
	return FollowOnce(bucket, method, function(dispatch)
		assert(ns.HookMethod(source, method, dispatch))
	end, fn)
end

-- Outlines ---------------------------------------------------------------------------------

-- UI units per screen pixel at scale 1.
local function PixelFactor()
	local _, height = GetPhysicalScreenSize()
	if Finite(height) and height > 0 then
		screenHeight = height
	end
	return screenHeight and 768 / screenHeight or 1
end

-- A length in screen pixels, in the units of a frame.
function ns.Pixels(frame, px)
	local ok, scale = pcall(frame.GetEffectiveScale, frame)
	if not ok or not Finite(scale) or scale <= 0 then
		scale = 1
	end
	return px * PixelFactor() / scale
end

-- Each SetPoint replaces the point of the same name, so the points are never cleared: if the
-- game refuses a call, the edge keeps the anchor it had.
local function PlaceEdgesNow(outline)
	local t = outline.px or ns.Get("general.thickness")
	if not outline.pixels then
		-- Edges drawn on the outlined frame itself are in that frame's units.
		t = ns.Pixels(outline.anchor, t)
	end
	local anchor, top, bottom, left, right = outline.anchor, outline.top, outline.bottom, outline.left, outline.right
	top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -t, 0)
	top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", t, 0)
	top:SetHeight(t)
	bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -t, 0)
	bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", t, 0)
	bottom:SetHeight(t)
	left:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, 0)
	left:SetWidth(t)
	right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(t)
	-- A round outline is a disc one border thickness larger than the target on every side, in the units the edges use: on a plate that scales,
	-- the disc is on a frame that ignores the scale of its parent, as the edges are.
	local round = outline.round
	if round then
		local to = round.ring or outline.target
		round.disc:SetPoint("TOPLEFT", to, "TOPLEFT", -t, t)
		round.disc:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", t, -t)
	end
end

-- An outline of a drawing of Flat UI setup has a view (ns.SetOutlineView): it is laid out and painted from that view, never from the profile in use.
local function PlaceEdges(outline)
	if outline.view then
		local ok, err = ns.Viewing(outline.view, PlaceEdgesNow, outline)
		if not ok then
			error(err, 0)
		end
	else
		PlaceEdgesNow(outline)
	end
end

local function Resize(outline)
	if outline.pixels then
		-- One unit of the holder is one screen pixel, whatever scale its parents have.
		outline.holder:SetScale(PixelFactor())
		if outline.round and outline.round.ring then
			outline.round.ring:SetScale(PixelFactor())
		end
	end
	PlaceEdges(outline)
end

-- True when the player wants no borders. Edges in the general border colour are then not drawn. A colour of its own says
-- something, so those edges stay.
function ns.Borderless()
	return ns.Get("general.borderless")
end

-- A vertical gradient on a texture, from the colour at the bottom to the colour at the top, both at opacity `a`. SetGradient takes two colour
-- objects (SimpleTextureBaseAPIDocumentation.lua:439) and the game's own nameplate code gives the lower colour first (Blizzard_NamePlates.lua:657).
-- The game's own XML puts a vertical gradient on a white colour texture, with the lower colour as MinColor (Blizzard_HelpPlate.xml:134-138,
-- Blizzard_GroupFinder/Shared/RaidFinder.xml:27-31), which is what this does.
-- False when the client has no CreateColor or SetGradient, or refuses them.
local function Gradient(texture, top, bottom, a)
	return pcall(function()
		texture:SetColorTexture(1, 1, 1, 1)
		texture:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], a), CreateColor(top[1], top[2], top[3], a))
	end)
end

-- The backdrop of an outline: its shade when it has one, else one colour. The documentation does not say whether SetColorTexture clears a
-- gradient (SimpleTextureBaseAPIDocumentation.lua:403), so a backdrop that has had one is made one colour by a gradient of one colour.
-- When that fails too, the colour is set after a plain white vertex colour. The documentation does not say what a vertex colour does to a
-- gradient, so the game decides.
-- outline.shadeDrawn is true when the shade is drawn and false when the client could not draw it, and is read only after a shade is given.
local function PaintBackdrop(outline, r, g, b, a)
	local texture, shade = outline.backdrop, outline.shade
	if shade then
		outline.shadeDrawn = Gradient(texture, shade.top, shade.bottom, a)
		if outline.shadeDrawn then
			outline.graded = true
			return
		end
	elseif outline.graded and Gradient(texture, { r, g, b }, { r, g, b }, a) then
		return
	end
	if outline.graded then
		texture:SetVertexColor(1, 1, 1, 1)
	end
	texture:SetColorTexture(r, g, b, a)
end

-- The page and row prefix whose own border and background an outline takes, or nil. An outline made outside ns.Try, ns.Each and ns.EachPart has
-- no page unless the module gave it one with ns.SetOutlineArea, and follows the Flat UI page.
local function AreaOf(outline)
	local area = outline.area
	if area and AREAS[area] and ns.Get(area .. "." .. outline.prefix .. "Own") == true then
		return area, outline.prefix
	end
	return nil
end

-- The opacity of the backdrop of an outline before anything sets its own: the Look row of its area when that is on, else the general one.
function ns.OutlineBackdropAlpha(outline)
	local area, prefix = AreaOf(outline)
	local a = area and ns.Get(area .. "." .. prefix .. "BackAlpha") or ns.Get("general.backdropAlpha")
	return (type(a) == "number" and a or 100) / 100
end

-- Colours and visibility. These are texture calls, which are allowed in combat.
local function PaintNow(outline)
	local r, g, b = outline.r, outline.g, outline.b
	local shown = outline.shown
	local area, prefix = AreaOf(outline)
	if r == nil then
		shown = shown and (outline.kept or not ns.Borderless())
		if area then
			r, g, b = ns.Colour(area .. "." .. prefix .. "Border")
		else
			r, g, b = ns.BorderRGB()
		end
	end
	if outline.bare or outline.edgesOff then
		shown = false
	end
	-- While round, the disc has the colour and the visibility the edges would have, and the edges and the backdrop are hidden.
	local round, discShown = outline.roundOn, shown
	if round then
		shown = false
		outline.round.disc:SetColorTexture(r, g, b, outline.edgeAlpha or 1)
		outline.round.disc:SetShown(discShown)
	end
	for _, edge in ipairs(outline.edges) do
		edge:SetColorTexture(r, g, b, outline.edgeAlpha or 1)
		edge:SetShown(shown)
	end
	local br, bg, bb, ba
	if outline.fr ~= nil then
		br, bg, bb, ba = outline.fr, outline.fg, outline.fb, outline.fa
	elseif area and ns.Get(area .. "." .. prefix .. "Back") ~= nil then
		br, bg, bb = ns.Colour(area .. "." .. prefix .. "Back")
		ba = outline.backAlpha or ns.Get(area .. "." .. prefix .. "BackAlpha") / 100
	else
		br, bg, bb = ns.Colour("general.backdrop")
		ba = outline.backAlpha or ns.Get("general.backdropAlpha") / 100
	end
	PaintBackdrop(outline, br, bg, bb, ba)
	outline.backdrop:SetShown(outline.shown and outline.backdropOn)
	if round then
		outline.backdrop:Hide()
	end
end

-- Red, green and blue of the edges of an outline, as PaintNow gives them: its own colour, else the border colour of its page while that page has a
-- border and background of its own, else the general border colour. For a line a module draws in place of the edges, such as the rounded line of a
-- unit frame, so that it takes the same colour.
function ns.OutlineEdgeRGB(outline)
	if outline == nil then
		return ns.BorderRGB()
	end
	if outline.r ~= nil then
		return outline.r, outline.g, outline.b
	end
	local area, prefix = AreaOf(outline)
	if area then
		return ns.Colour(area .. "." .. prefix .. "Border")
	end
	return ns.BorderRGB()
end

local function Paint(outline)
	if outline.view then
		local ok, err = ns.Viewing(outline.view, PaintNow, outline)
		if not ok then
			error(err, 0)
		end
	else
		PaintNow(outline)
	end
end

local function Edge(owner)
	local edge = owner:CreateTexture(nil, "OVERLAY", nil, 7)
	own[edge] = true
	-- Snapping moves a thin edge by a pixel as its frame moves.
	if edge.SetSnapToPixelGrid then
		pcall(edge.SetSnapToPixelGrid, edge, false)
	end
	if edge.SetTexelSnappingBias then
		pcall(edge.SetTexelSnappingBias, edge, 0)
	end
	return edge
end

-- Four thin edges just outside `target` and a backdrop behind it.
-- owner: the Blizzard frame the outline belongs to, so it shows, hides and fades with it.
-- direct: draw the edges on the owner itself instead of on a frame of the addon's own.
-- prefix: the row prefix of the page's own border and background, look when none is given.
-- The outline belongs to the page of the module whose code makes it (ns.Try, ns.Each, ns.EachPart); ns.SetOutlineArea names it where
-- the code runs outside those.
function ns.Outline(owner, target, direct, prefix)
	local outline = outlines[target]
	if outline then
		return outline
	end
	if Forbidden(owner) then
		return nil
	end
	outline = { shown = true, backdropOn = true, area = running, prefix = prefix or "look" }
	outline.owner, outline.target = owner, target
	outline.backdrop = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
	own[outline.backdrop] = true
	outline.backdrop:SetAllPoints(target)
	local edgeOwner = owner
	if direct then
		outline.anchor = target
	else
		local holder = CreateFrame("Frame", nil, owner)
		own[holder] = true
		holder:SetAllPoints(target)
		outline.holder = holder
		outline.pixels = pcall(holder.SetIgnoreParentScale, holder, true)
		edgeOwner = holder
		outline.anchor = holder
	end
	outline.top, outline.bottom = Edge(edgeOwner), Edge(edgeOwner)
	outline.left, outline.right = Edge(edgeOwner), Edge(edgeOwner)
	outline.edges = { outline.top, outline.bottom, outline.left, outline.right }
	Resize(outline)
	Paint(outline)
	outlines[target] = outline
	return outline
end

-- Makes an outline follow a view (see ns.Viewing) in place of the profile in use, so a drawing of Flat UI setup shows the draft and PaintAll and
-- ResizeAll leave it as it is. No view puts it back.
function ns.SetOutlineView(outline, view)
	if outline and outline.view ~= view then
		outline.view = view
		Resize(outline)
		Paint(outline)
	end
end

-- Lays an outline out and paints it again: for a drawing of Flat UI setup, after its view changed.
function ns.RepaintOutline(outline)
	if outline then
		Resize(outline)
		Paint(outline)
	end
end

-- Names the page an outline belongs to, for an outline made outside ns.Try, ns.Each and ns.EachPart. Returns the outline.
function ns.SetOutlineArea(outline, key)
	if outline and outline.area ~= key then
		outline.area = key
		Paint(outline)
	end
	return outline
end

-- Shows or hides an outline, with or without its backdrop.
function ns.SetOutline(outline, shown, backdropOn)
	if not outline then
		return
	end
	shown, backdropOn = shown and true or false, backdropOn and true or false
	if outline.shown ~= shown or outline.backdropOn ~= backdropOn then
		outline.shown, outline.backdropOn = shown, backdropOn
		Paint(outline)
	end
end

-- Draws an outline as its backdrop alone, with no edges, or with its edges again.
function ns.SetOutlineBare(outline, bare)
	if outline and (outline.bare or false) ~= (bare or false) then
		outline.bare = bare or nil
		Paint(outline)
	end
end

-- Shows or hides the four edges of an outline alone; its backdrop follows ns.SetOutline.
function ns.SetOutlineEdges(outline, shown)
	if outline and (outline.edgesOff or false) ~= (shown == false) then
		outline.edgesOff = shown == false or nil
		Paint(outline)
	end
end

-- An opacity, 0 to 1, for the edges of one outline and for its backdrop when it has no fill of its own. None means full edges and the
-- general background opacity.
function ns.SetOutlineAlpha(outline, alpha, backdropAlpha)
	if outline and (outline.edgeAlpha ~= alpha or outline.backAlpha ~= backdropAlpha) then
		outline.edgeAlpha, outline.backAlpha = alpha, backdropAlpha
		Paint(outline)
	end
end

-- A fill of its own for one outline. No fill means the general background colour and opacity.
function ns.SetOutlineFill(outline, r, g, b, a)
	if outline and (outline.fr ~= r or outline.fg ~= g or outline.fb ~= b or outline.fa ~= a) then
		outline.fr, outline.fg, outline.fb, outline.fa = r, g, b, a
		Paint(outline)
	end
end

-- A shade for the fill of one outline: a vertical gradient from the colour at the bottom to the colour at the top, at the opacity of the fill.
-- Colours are { r, g, b }; none means one colour. Returns nil without a shade, true when the shade is drawn and false when the client cannot
-- draw it, in which case the fill is one colour.
function ns.SetOutlineShade(outline, top, bottom)
	if not outline then
		return nil
	end
	if top == nil then
		if outline.shade then
			outline.shade = nil
			Paint(outline)
		end
		return nil
	end
	outline.shade = { top = top, bottom = bottom }
	Paint(outline)
	return outline.shadeDrawn
end

-- A colour of its own for one outline. No colour means the general border colour.
function ns.SetOutlineColour(outline, r, g, b)
	if outline and (outline.r ~= r or outline.g ~= g or outline.b ~= b) then
		outline.r, outline.g, outline.b = r, g, b
		Paint(outline)
	end
end

-- For the outline of a tool and not of the look: its edges are drawn without borders too.
function ns.KeepOutline(outline)
	if outline and not outline.kept then
		outline.kept = true
		Paint(outline)
	end
end

-- A thickness of its own for one outline, in screen pixels. None means the general thickness.
function ns.SetOutlineThickness(outline, px)
	if outline and outline.px ~= px then
		outline.px = px
		PlaceEdges(outline)
	end
end

-- The circle the client cuts its own class icons with (RES/AtlasInfo.lua:17528-17529).
local ROUND_MASK = "CircleMaskScalable"

-- A texture of an outline that is not moved a pixel as its frame moves, as the edges are not.
local function Unsnap(texture)
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	return texture
end

-- A circle mask over all points of `to`. Everything outside the mask file is cut.
local function CircleMask(owner, to)
	local mask = Unsnap(owner:CreateMaskTexture())
	own[mask] = true
	mask:SetAllPoints(to)
	mask:SetAtlas(ROUND_MASK, false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	return mask
end

-- Draws an outline as a ring: a disc in the border colour, one border thickness larger than the outline on every side and cut to a circle, with
-- the picture `art` (and `extra`, a texture over it) cut to a circle of its own size. The square edges and the square background go off while it is
-- round. A client without masks or without the circle keeps the square outline, and ns.roundMissing says so. Nothing is made in combat: the first
-- round outline waits for its end. Adding and removing a mask that exists is a texture call.
function ns.SetOutlineRound(outline, art, on, extra)
	if not outline then
		return
	end
	on = on and true or false
	outline.roundWant = on
	local round = outline.round
	if on and not round then
		local owner = outline.owner
		if type(owner.CreateMaskTexture) ~= "function" or not AtlasExists(ROUND_MASK) then
			ns.roundMissing = true
			return
		end
		local fighting = InCombatLockdown()
		if fighting then
			if not outline.roundQueued then
				outline.roundQueued = true
				ns.OutOfCombat(function()
					outline.roundQueued = nil
					ns.SetOutlineRound(outline, art, outline.roundWant, extra)
				end)
			end
			return
		end
		local made, parts = pcall(function()
			-- Under the picture: the frame of the disc has a lower level than the frame of the picture.
			local ring
			if outline.holder and outline.pixels then
				ring = CreateFrame("Frame", nil, owner)
				own[ring] = true
				ring:SetIgnoreParentScale(true)
				ring:SetScale(PixelFactor())
				ring:SetAllPoints(outline.target)
				-- A level the game withholds leaves the ring at 0, under the picture.
				local got, level = pcall(owner.GetFrameLevel, owner)
				ring:SetFrameLevel(got and type(level) == "number" and not ns.IsSecret(level) and math.max(0, level - 1) or 0)
			end
			local host = ring or owner
			local d = Unsnap(host:CreateTexture(nil, "BACKGROUND", nil, -7))
			own[d] = true
			d:Hide()
			local discMask = CircleMask(host, d)
			d:AddMaskTexture(discMask)
			return { disc = d, ring = ring, discMask = discMask, artMask = CircleMask(owner, art) }
		end)
		if not made then
			ns.roundMissing = true
			return
		end
		round = parts
		round.art, round.extra = art, extra
		outline.round = round
		Unsnap(art)
	end
	if round and (outline.roundOn or false) ~= on then
		outline.roundOn = on or nil
		local method = on and "AddMaskTexture" or "RemoveMaskTexture"
		pcall(round.art[method], round.art, round.artMask)
		if round.extra then
			pcall(round.extra[method], round.extra, round.artMask)
		end
		if not on then
			round.disc:Hide()
		end
		PlaceEdges(outline)
		Paint(outline)
	end
end

-- Runs fn now, or when combat ends: nothing is laid out on action buttons in combat.
function ns.OutOfCombat(fn)
	if InCombatLockdown() then
		afterCombat[#afterCombat + 1] = fn
	else
		fn()
	end
end

function ns.ResizeAll()
	if resizePending then
		return
	end
	resizePending = true
	ns.OutOfCombat(function()
		resizePending = false
		for _, outline in pairs(outlines) do
			pcall(Resize, outline)
		end
		-- Lengths a module works out in screen pixels.
		for _, key in ipairs(MODULE_ORDER) do
			if modules[key] and modules[key].Resized and status[key].started then
				ns.Try(key, modules[key].Resized)
			end
		end
	end)
end

local function PaintAll()
	for _, outline in pairs(outlines) do
		pcall(Paint, outline)
	end
end

-- Modules ----------------------------------------------------------------------------------

-- A stopped module counts as off, so one last Refresh puts Blizzard's art back. Switching its page off and on starts it again.
local function Stop(key, err)
	local state = status[key]
	if state.error then
		return
	end
	state.error = tostring(err)
	print(("Flat UI: %s stopped. /flatui status shows why. Type /reload if the look is left half changed."):format(modules[key].label))
	if state.started and modules[key].Refresh then
		state.restoring = true
		pcall(modules[key].Refresh)
		state.restoring = nil
	end
end

-- pcall that has the module's key as the running one while fn runs, and puts back the one before.
local function RunDone(before, ...)
	running = before
	return ...
end

local function Run(key, fn, ...)
	local before = running
	running = key
	return RunDone(before, pcall(fn, ...))
end

-- Runs a module's code. An error stops that module and is kept for /flatui status.
function ns.Try(key, fn, ...)
	local state = status[key]
	if state.restoring then
		return (Run(key, fn, ...))
	elseif state.error then
		return false
	end
	local ok, err = Run(key, fn, ...)
	if not ok then
		Stop(key, err)
	end
	return ok
end

-- Runs a module's code for one frame, given first after the function. An error skips that
-- frame. A frame that fails is counted once however often it is tried, and the module stops
-- when enough different frames have failed.
function ns.Each(key, fn, ...)
	local state = status[key]
	if state.restoring then
		return (Run(key, fn, ...))
	elseif state.error then
		return false
	end
	local ok, err = Run(key, fn, ...)
	if not ok then
		local id = (...) or fn
		state.failedFrames = state.failedFrames or setmetatable({}, { __mode = "k" })
		if not state.failedFrames[id] then
			state.failedFrames[id] = true
			state.failed = (state.failed or 0) + 1
			state.firstFailure = state.firstFailure or tostring(err)
			if state.failed >= MAX_FAILURES then
				Stop(key, state.firstFailure)
			end
		end
	end
	return ok
end

-- Like ns.Each, for a module that visits hundreds of frames and whose parts fail separately.
-- A part that fails on enough different frames is stopped alone, with a line for /flatui status,
-- and the module goes on. The module puts that part's art back itself. An error comes back as
-- the second value.
function ns.EachPart(key, part, fn, ...)
	local state = status[key]
	if state.restoring then
		return (Run(key, fn, ...))
	elseif state.error or (state.partsStopped and state.partsStopped[part]) then
		return false
	end
	local ok, err = Run(key, fn, ...)
	if not ok then
		err = tostring(err)
		local id = (...) or fn
		state.partFailures = state.partFailures or {}
		local record = state.partFailures[part]
		if not record then
			record = { count = 0, frames = setmetatable({}, { __mode = "k" }), first = err }
			state.partFailures[part] = record
		end
		if not record.frames[id] then
			record.frames[id] = true
			record.count = record.count + 1
			if record.count >= MAX_PART_FAILURES then
				state.partsStopped = state.partsStopped or {}
				state.partsStopped[part] = true
				record.note = ("%s: %s stopped. %s"):format(modules[key].label, part, record.first)
				ns.Note(key, record.note)
				print(("Flat UI: %s stopped in %s. /flatui status shows why."):format(part, modules[key].label))
			end
		end
		return false, err
	end
	return true
end

function ns.PartStopped(key, part)
	local stopped = status[key].partsStopped
	return stopped ~= nil and stopped[part] == true
end

function ns.IsStopped(key)
	return status[key].error ~= nil
end

function ns.Count(key, n)
	status[key].count = (status[key].count or 0) + (n or 1)
end

-- A line for /flatui status about one part of a module, such as a part that was switched off
-- after an error.
function ns.Note(key, text)
	local state = status[key]
	state.notes = state.notes or {}
	for _, note in ipairs(state.notes) do
		if note == text then
			return
		end
	end
	state.notes[#state.notes + 1] = text
end

-- Takes a line back once what it says is no longer so.
function ns.ClearNote(key, text)
	local notes = status[key].notes or {}
	for index = #notes, 1, -1 do
		if notes[index] == text then
			table.remove(notes, index)
		end
	end
end

-- module: {
--   label = the name /flatui status shows,
--   Start = function, run once when the module is on at login or switched on later,
--   Refresh = function,
--   Resized = function, run when the screen, the UI scale or a length in screen pixels changes,
--   events = { name = handler }, run while the module is on,
--   filters = { name = function(...) returning true when the handler is to run },
--   slash = { word = function(rest) }, help = { lines for /flatui help },
--   counted = the noun /flatui status counts ("styled" when missing), or false to count nothing,
--   Status = function returning more lines for /flatui status }
-- Refresh applies the current options to everything the module has styled, and is also what
-- puts Blizzard's art back when the module or one of its parts is turned off.
function ns.Register(key, module)
	modules[key] = module
	status[key] = {}
end

-- Per module: the handlers added to each of its events by ns.AddEvent.
local addedEvents = setmetatable({}, { __mode = "k" })

-- Adds a handler for an event to a module registered by another file, run while that module is on, after the handlers it has. filter is
-- a function returning true when the handler is to run. Every handler runs even when one before it fails, and the first failure is raised
-- after them, so the module is stopped as for its own error. Call it while the files load: the events are listened for when the addon loads.
-- Returns false for a module that is not registered.
function ns.AddEvent(key, event, fn, filter)
	local module = modules[key]
	if type(module) ~= "table" or type(event) ~= "string" or type(fn) ~= "function" then
		return false
	end
	module.events = module.events or {}
	module.filters = module.filters or {}
	addedEvents[module] = addedEvents[module] or {}
	local list = addedEvents[module][event]
	if list == nil then
		list = {}
		addedEvents[module][event] = list
		if module.events[event] then
			list[1] = { fn = module.events[event], filter = module.filters[event] }
		end
		module.events[event] = function(...)
			local failed, first = false, nil
			for _, entry in ipairs(list) do
				if not entry.filter or entry.filter(...) then
					local ok, err = pcall(entry.fn, ...)
					if not ok and not failed then
						failed, first = true, err
					end
				end
			end
			if failed then
				error(first, 0)
			end
		end
		module.filters[event] = function(...)
			for _, entry in ipairs(list) do
				if not entry.filter then
					return true
				end
				local ok, pass = pcall(entry.filter, ...)
				if ok and pass then
					return true
				end
			end
			return false
		end
	end
	list[#list + 1] = { fn = fn, filter = filter }
	return true
end

-- Adds lines to /flatui status under a module registered by another file: fn returns a list of lines, and they come after the module's own. Call
-- it while the files load. Returns false for a module that is not registered.
function ns.AddStatus(key, fn)
	local module = modules[key]
	if type(module) ~= "table" or type(fn) ~= "function" then
		return false
	end
	local status = module.Status
	module.Status = function(...)
		local lines = {}
		for _, line in ipairs(type(status) == "function" and status(...) or {}) do
			lines[#lines + 1] = line
		end
		local ok, more = pcall(fn)
		if ok and type(more) == "table" then
			for _, line in ipairs(more) do
				lines[#lines + 1] = line
			end
		end
		return lines
	end
	return true
end

-- Adds a word of /flatui to a module registered by another file, and the lines it gives /flatui help. Call it while the files load. Returns false
-- for a module that is not registered or a word it has already.
function ns.AddSlash(key, word, fn, help)
	local module = modules[key]
	if type(module) ~= "table" or type(word) ~= "string" or type(fn) ~= "function" then
		return false
	end
	module.slash = module.slash or {}
	if module.slash[word] then
		return false
	end
	module.slash[word] = fn
	module.help = module.help or {}
	for _, line in ipairs(help or {}) do
		module.help[#module.help + 1] = line
	end
	return true
end

-- Runs fn after the Start of a module registered by another file, which is also what turning its page on runs. Call it while the files load.
-- Returns false for a module with no Start.
function ns.AddStart(key, fn)
	local module = modules[key]
	if type(module) ~= "table" or type(module.Start) ~= "function" or type(fn) ~= "function" then
		return false
	end
	local start = module.Start
	module.Start = function(...)
		start(...)
		fn(...)
	end
	return true
end

-- True while a module runs: started, not stopped by an error, and its page on. Test mode (TestMode.lua) runs a module's samples only then.
function ns.ModuleOn(key)
	local state = type(key) == "string" and status[key] or nil
	return state ~= nil and state.started == true and not state.error and ns.Enabled(key)
end

-- Runs a module's Refresh while it runs (ns.ModuleOn), through ns.Try. False when it did not run or failed.
function ns.RefreshModule(key)
	if ns.ModuleOn(key) and modules[key].Refresh then
		return ns.Try(key, modules[key].Refresh)
	end
	return false
end

-- Test mode hears every change after the module's own (TestMode.lua): its samples and stand-ins are drawn again from it.
local function TestChanged(path)
	local test = ns.TestMode
	if type(test) == "table" and type(test.Changed) == "function" then
		local ok, err = pcall(test.Changed, path)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

local function StartModule(key)
	local module, state = modules[key], status[key]
	if state.started or not ns.Enabled(key) then
		return
	end
	state.started = true
	if module.Start and not ns.Try(key, module.Start) then
		state.startFailed = true
	end
end

-- Forgets what stopped a module or a part of it, so that switching its page on starts it again.
local function Rearm(key)
	local state = status[key]
	for _, record in pairs(state.partFailures or {}) do
		if record.note then
			ns.ClearNote(key, record.note)
		end
	end
	state.error, state.failed, state.failedFrames, state.firstFailure = nil, nil, nil, nil
	state.partFailures, state.partsStopped = nil, nil
	if state.startFailed then
		-- A module that stopped in Start has not been set up.
		state.started, state.startFailed = nil, nil
	end
end

-- What a general setting changes beyond the colours of the outlines: their sizes, and the lengths that modules
-- work out from the border thickness.
local function Settle()
	-- A module whose Resized is its Refresh has been refreshed by a resize that runs now.
	local resized = not (InCombatLockdown() or resizePending)
	ns.ResizeAll()
	for _, key in ipairs(MODULE_ORDER) do
		local module = modules[key]
		if module and status[key].started and module.Refresh and not (resized and module.Resized == module.Refresh) then
			ns.Try(key, module.Refresh)
		end
	end
end

-- Refreshes a module that reads a setting of another page (READERS), once it has started.
local function Reread(key)
	if loggedIn and modules[key] and status[key].started and modules[key].Refresh then
		ns.Try(key, modules[key].Refresh)
	end
end

local function Changed(path)
	local page = path:match("^(%w+)%.")
	local def = defs[path]
	local prefix, suffix = path:match("^%w+%.(%l+)(%u%a*)$")
	if prefix and PREFIXES[prefix] and SUFFIXES[suffix] and AREAS[page] then
		-- A border or background row of a page repaints the outlines, and the module is not refreshed.
		PaintAll()
	elseif def and def.changed then
		local call = ns[def.changed]
		if type(call) == "function" and loggedIn then
			local ok, err = pcall(call, path)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif page == "general" then
		PaintAll()
		settleCount = settleCount + 1
		local mine = settleCount
		if C_Timer and C_Timer.After then
			C_Timer.After(SETTLE, function()
				if mine == settleCount then
					Settle()
				end
			end)
		else
			-- Without a timer every step is applied.
			Settle()
		end
	elseif modules[page] and loggedIn then
		local state = status[page]
		if path == page .. ".enabled" and ns.Get(path) then
			Rearm(page)
		end
		if not state.started then
			StartModule(page)
		elseif modules[page].Refresh then
			ns.Try(page, modules[page].Refresh)
		end
	end
	local readers = READERS[path]
	if type(readers) == "table" then
		for _, reader in ipairs(readers) do
			Reread(reader)
		end
	elseif readers then
		Reread(readers)
	end
end

function ns.Set(path, value, quiet)
	local def = defs[path]
	if not (db and def) then
		return
	end
	value = Normalise(def, value)
	if value == nil then
		return
	end
	if Unsaved(def) then
		-- The game or a function of ns holds this value, so nothing goes into the profile. A row that acts at once refreshes no module.
		if Same(ns.Get(path), value) then
			return
		end
		if def.set then
			local call = ns[def.set]
			if type(call) == "function" then
				local ok, err = pcall(call, def, value)
				if not ok then
					geterrorhandler()(err)
				end
			end
		elseif def.cvar then
			ns.CVarSet(def, value, quiet)
		end
		if def.changed or not ns.RowLive(def) then
			Changed(path)
		end
		-- Also for a row that acts at once, such as partyScale and raidScale, which refresh no module.
		TestChanged(path)
		return
	end
	-- A value equal to the default is still saved: it is the player's choice from then on.
	local changed = ns.Get(path) ~= value
	values[path] = value
	if changed then
		Changed(path)
		TestChanged(path)
	end
end

-- The version in the TOC, or nil when the game does not say.
local function Version()
	if type(C_AddOns) ~= "table" or type(C_AddOns.GetAddOnMetadata) ~= "function" then
		return nil
	end
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
	if ok and not IsSecret(version) and type(version) == "string" and version ~= "" then
		return version
	end
	return nil
end

function ns.StatusLines()
	local version = Version()
	local lines = { version and ("Flat UI %s"):format(version) or "Flat UI", ("Profile: %s"):format(current),
		("Border thickness: %d px"):format(ns.Get("general.thickness")) }
	if ns.TaintLogging() then
		lines[#lines + 1] = ("taintLog is on: %d game methods not followed. Turn it off and reload to follow them."):format(skippedCount)
	end
	for _, key in ipairs(MODULE_ORDER) do
		local module, state = modules[key], status[key]
		if module then
			local line
			if state.error then
				line = ("%s: stopped. %s"):format(module.label, state.error)
			elseif not ns.Get(key .. ".enabled") then
				line = ("%s: off"):format(module.label)
			elseif not state.started then
				line = ("%s: on, not started"):format(module.label)
			else
				-- A module says what it counts, or false when it counts nothing.
				local noun = module.counted == nil and "styled" or module.counted
				line = noun and ("%s: on, %d %s"):format(module.label, state.count or 0, noun) or ("%s: on"):format(module.label)
				if state.failed then
					line = ("%s, %d failed. %s"):format(line, state.failed, state.firstFailure)
				end
			end
			lines[#lines + 1] = line
			for _, note in ipairs(state.notes or {}) do
				lines[#lines + 1] = note
			end
			for _, extra in ipairs(module.Status and module.Status() or {}) do
				lines[#lines + 1] = extra
			end
		end
	end
	local test = ns.TestMode and ns.TestMode.Status()
	if test then
		lines[#lines + 1] = test
	end
	-- The faces are tried the first time a row asks for them.
	if fontsOffered ~= nil then
		local offered = {}
		for _, face in ipairs(FONT_FACES) do
			if fontsOffered[face[1]] then
				offered[#offered + 1] = face[1]
			end
		end
		lines[#lines + 1] = "Fonts offered: " .. (#offered > 0 and table.concat(offered, ", ") or "none")
	end
	if #noArt > 0 then
		lines[#lines + 1] = "Class icons: no class art for " .. table.concat(noArt, ", ") .. "."
	end
	if ns.roundMissing then
		lines[#lines + 1] = "Round class icons: this client has no circle mask, so they show square."
	end
	local borderMode = ns.Get("general.borderMode")
	if borderMode == "class" or borderMode == "faction" then
		local br, bg, bb = ns.BorderRGB()
		local dr, dg, db = ns.Colour("general.border")
		if br == dr and bg == dg and bb == db then
			lines[#lines + 1] = ("Borders: no %s from the game, Border colour used."):format(borderMode)
		end
	end
	for _, line in ipairs(ns.GameSettingsStatus and ns.GameSettingsStatus() or {}) do
		lines[#lines + 1] = line
	end
	local scale = ns.ScaleStatus and ns.ScaleStatus()
	if scale then
		lines[#lines + 1] = scale
	end
	local sparkle = ns.SparkleStatus and ns.SparkleStatus()
	if sparkle then
		lines[#lines + 1] = sparkle
	end
	local glow = ns.SparkleGlowStatus and ns.SparkleGlowStatus()
	if glow then
		lines[#lines + 1] = glow
	end
	local camera = ns.CameraZoomStatus and ns.CameraZoomStatus()
	if camera then
		lines[#lines + 1] = camera
	end
	local ring = ns.CursorRingStatus and ns.CursorRingStatus()
	if ring then
		lines[#lines + 1] = ring
	end
	for _, line in ipairs(ns.SetupStatus and ns.SetupStatus() or {}) do
		lines[#lines + 1] = line
	end
	for _, line in ipairs(ns.PanelLookStatus and ns.PanelLookStatus() or {}) do
		lines[#lines + 1] = line
	end
	if #blocked > 0 then
		lines[#lines + 1] = "Blocked by the game: " .. table.concat(blocked, ", ")
	end
	for _, line in ipairs(ns.ClickPathLines()) do
		lines[#lines + 1] = line
	end
	for _, line in ipairs(ns.TaintLines and ns.TaintLines() or {}) do
		lines[#lines + 1] = line
	end
	if ns.ReloadIsSecure and ns.ReloadIsSecure() then
		lines[#lines + 1] = "Reload: secure button."
	end
	return lines
end

-- How many calls of this addon the game blocked, and the text of the last one.
function ns.BlockedTotal()
	return blockedTotal
end

function ns.BlockedLast()
	return blockedLast
end

-- What is saved for this character alone. FlatUIDB is shared by the account.
function ns.Character()
	return charDB
end

-- What is saved for the whole account, outside every profile.
function ns.Account()
	return db
end

-- Profiles ---------------------------------------------------------------------------------

-- "Name - Realm" of this character, or nil when the client does not say.
local function ReadCharacter()
	if type(UnitName) ~= "function" or type(GetRealmName) ~= "function" then
		return nil
	end
	local okName, name = pcall(UnitName, "player")
	local okRealm, realm = pcall(GetRealmName)
	if not (okName and okRealm) or IsSecret(name) or IsSecret(realm) or type(name) ~= "string" or type(realm) ~= "string"
		or name == "" or realm == "" or name == UNKNOWNOBJECT then
		return nil
	end
	return name .. " - " .. realm
end

-- Rows of an older build read as the rows that replaced them: the three nameplate outline rows were ticks (on is As the game has it, off is None), Hit
-- table under the player frame was a tick in 0.5.18 (on is Always, off is Off), and White names is Name colour White on the unit frames unless a Name
-- colour is chosen. `old` holds the values the older rows were saved with, as booleans; `options` takes the new ones (the same table for a saved profile).
-- It runs for each saved profile as the settings load, for a profile text as it is read, and for a draft of Flat UI setup as it is read (Setup.lua);
-- a value it gave is a choice from then on, so each tick moves once.
local OLD_PLATE_OUTLINES = { "nameplates.nameOutline", "nameplates.healthTextOutline", "nameplates.castTextOutline" }
function ns.MigrateText(old, options)
	for _, path in ipairs(OLD_PLATE_OUTLINES) do
		if type(old[path]) == "boolean" then
			options[path] = old[path] and "game" or "none"
		end
	end
	if type(old["hud.hitTable"]) == "boolean" then
		options["hud.hitTable"] = old["hud.hitTable"] and "on" or "off"
	end
	if old["unitframes.lookWhiteNames"] == true and (options["unitframes.nameColour"] == nil or options["unitframes.nameColour"] == "game") then
		options["unitframes.nameColour"] = "white"
	end
end

-- Bags came in 0.5.18, off by default, and is on by default from 0.5.19. A profile saved before 0.5.19 with every module that is on by default
-- saved off, as Game look of the welcome screen makes one (SetupWelcome.lua, W.GameLook), and nothing saved for Bags keeps Bags off: it left the
-- look to the game, and the modules that are off by default (Errands, Data panels and the others), which it may have turned on, are not read
-- here. Run once, for the profiles saved before (LoadSettings, while FlatUIDB.bagsMigrated is not set, as soundsMigrated marks the move of the
-- sound rows). A Game look made since saves Bags off itself.
local function KeepBagsOff(options)
	if options["bags.enabled"] ~= nil then
		return
	end
	local any = false
	for path, def in pairs(defs) do
		if def.key == "enabled" and def.kind == "bool" and def.default == true and path ~= "bags.enabled" then
			if options[path] ~= false then
				return
			end
			any = true
		end
	end
	if any then
		options["bags.enabled"] = false
	end
end

-- Drops what is not a setting of this build, and what a setting cannot hold.
local function NormaliseValues(options)
	for path, value in pairs(options) do
		local def = defs[path]
		if def and not Unsaved(def) then
			options[path] = Normalise(def, Renamed(path, value))
		else
			options[path] = nil
		end
	end
end

-- Drops the positions that cannot be used.
local function NormaliseSpots(spots)
	for name, entry in pairs(spots) do
		if type(name) ~= "string" or not ns.CleanSpot(entry) then
			spots[name] = nil
		end
	end
end

-- The settings and positions saved before there were profiles, as the profile Default.
local function FromOlder(version)
	local options = type(db.options) == "table" and db.options or {}
	-- Settings saved by version 0.1.0.
	for _, key in ipairs(LEGACY_MODULES) do
		if type(db[key]) == "boolean" then
			options[key .. ".enabled"] = db[key]
		end
		db[key] = nil
	end
	if type(db.thickness) == "number" then
		options["general.thickness"] = db.thickness
	end
	db.thickness = nil
	-- Choices saved before settings had a version, for settings whose defaults have changed since.
	if version < 1 then
		for _, path in ipairs(RESET_SETTINGS) do
			local def, was = defs[path], options[path]
			if was ~= nil then
				options[path] = nil
				resetNotice = resetNotice or (def ~= nil and was ~= def.default)
			end
		end
	end
	return { options = options, movers = type(db.movers) == "table" and db.movers or {} }
end

local function LoadSettings()
	Define()
	if type(FlatUICharDB) ~= "table" then
		FlatUICharDB = {}
	end
	charDB = FlatUICharDB
	FlatUIDB = FlatUIDB or {}
	db = FlatUIDB
	local version = tonumber(db.settingsVersion) or 0
	if type(db.profiles) ~= "table" then
		db.profiles = { [DEFAULT] = FromOlder(version) }
	end
	db.options, db.movers = nil, nil
	for name, saved in pairs(db.profiles) do
		if type(name) ~= "string" or type(saved) ~= "table" then
			db.profiles[name] = nil
		else
			saved.options = type(saved.options) == "table" and saved.options or {}
			-- A custom scale under the game's own 65% moves to Small scale. Scale below 65% is off, so nothing is applied until it is turned on.
			local old = saved.options["general.scale"]
			if type(old) == "number" and old == old and old < 65 then
				saved.options["general.scaleSmall"] = math.floor(old + 0.5)
				saved.options["general.scale"] = 65
				if saved.options["general.scaleOn"] == true then
					saved.options["general.scaleOn"] = false
					ns.scaleMoved = ns.scaleMoved or {}
					ns.scaleMoved[name] = saved.options["general.scaleSmall"]
				end
			end
			-- Combat text rows of an older build: Kind of hit in parentheses off is Partial effects off, Smaller glancing hits and words goes, and
			-- Movement of your text is Incoming style, with Up and Down as Straight.
			local ct = saved.options
			if ct["combattext.word"] == false and ct["combattext.partial"] == nil then
				ct["combattext.partial"] = "off"
			end
			if ct["combattext.ownMove"] ~= nil and ct["combattext.inStyle"] == nil then
				ct["combattext.inStyle"] = ct["combattext.ownMove"] == "arc" and "arc" or "straight"
			end
			-- Out of range dimming on party frames is Out of range opacity, on the scale of the raid frames: the old value is 100 minus the new one.
			local dimmed = ct["unitframes.partyRangeAlpha"]
			if type(dimmed) == "number" and dimmed == dimmed and ct["unitframes.partyRangeOpacity"] == nil then
				ct["unitframes.partyRangeOpacity"] = 100 - dimmed
			end
			-- Sound rows of an older build: one list of sounds.
			if ns.MigrateSounds then
				ns.MigrateSounds(saved.options, not db.soundsMigrated)
			end
			-- The positions of the frames the player moved, by frame name.
			saved.movers = type(saved.movers) == "table" and saved.movers or {}
			ns.MigrateText(saved.options, saved.options)
			NormaliseValues(saved.options)
			-- A profile saved before 0.5.19 with every module that is on by default off keeps Bags off (KeepBagsOff), once.
			if not db.bagsMigrated then
				KeepBagsOff(saved.options)
			end
			NormaliseSpots(saved.movers)
		end
	end
	-- The drafts of setup hold their picks in the same form, and a Sound saved without the old row goes the same way.
	for _, draft in pairs(type(db.setup) == "table" and type(db.setup.drafts) == "table" and db.setup.drafts or {}) do
		if ns.MigrateSounds and type(draft) == "table" and type(draft.values) == "table" then
			ns.MigrateSounds(draft.values, not db.soundsMigrated)
		end
	end
	db.soundsMigrated = true
	db.bagsMigrated = true
	if db.profiles[DEFAULT] == nil then
		db.profiles[DEFAULT] = { options = {}, movers = {} }
	end
	-- The profile of each character, by "Name - Realm". A character with none uses Default.
	if type(db.profileOf) ~= "table" then
		db.profileOf = {}
	end
	for key, name in pairs(db.profileOf) do
		if type(key) ~= "string" or db.profiles[name] == nil then
			db.profileOf[key] = nil
		end
	end
	characterKey = ReadCharacter()
	current = characterKey and db.profileOf[characterKey] or DEFAULT
	profile = db.profiles[current]
	values = profile.options
	if version < SETTINGS_VERSION then
		db.settingsVersion = SETTINGS_VERSION
	end
end

-- The positions of the frames the player moved in the profile in use, by frame name. Nothing before the settings
-- are loaded.
function ns.Spots()
	if viewing then
		return viewing.spots
	end
	return profile and profile.movers
end

-- The name of the profile in use.
function ns.Profile()
	return current
end

-- Every profile name, sorted without regard to case.
function ns.Profiles()
	local names = {}
	for name in pairs(db and db.profiles or { [DEFAULT] = true }) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		local lowerA, lowerB = a:lower(), b:lower()
		if lowerA ~= lowerB then
			return lowerA < lowerB
		end
		return a < b
	end)
	return names
end

-- The stored name of a profile that was asked for by name, exactly or without regard to case.
local function Find(name)
	if type(name) ~= "string" or IsSecret(name) then
		return nil
	end
	if db.profiles[name] then
		return name
	end
	local lower = name:lower()
	for _, stored in ipairs(ns.Profiles()) do
		if stored:lower() == lower then
			return stored
		end
	end
	return nil
end

-- The name as it is stored, or nil and why not.
local function CleanName(name)
	if type(name) == "string" and not IsSecret(name) then
		name = name:match("^%s*(.-)%s*$")
		-- Characters, not bytes: a continuation byte of UTF-8 belongs to the character before it.
		local length = #(name:gsub("[\128-\191]", ""))
		if length >= 1 and length <= MAX_NAME and not name:find("[\r\n]") then
			return name
		end
	end
	return nil, ("Use 1 to %d characters on one line."):format(MAX_NAME)
end

-- The name as a new profile would have it, or nil and the sentence why not: the rule of ns.NewProfile, which is also what the name field of Flat UI setup
-- shows while the player types.
function ns.ProfileNameCheck(name)
	local clean, why = CleanName(name)
	if not clean then
		return nil, why
	end
	if db and Find(clean) then
		return nil, "That name is taken."
	end
	return clean
end

-- "Name - Realm" of this character, or nil when the client does not say.
function ns.CharacterKey()
	return characterKey or ReadCharacter()
end

-- Why a change of profile cannot be made now, or nil.
local function Refusal()
	if not db then
		return "Profiles are not ready yet."
	end
	return InCombatLockdown() and "Profiles change after combat." or nil
end

-- The settings or the positions in force are not those that were: every setting is applied, every module follows,
-- and the movers put each frame at its place in the new profile. `wasSpots` is the table of positions that was in use.
local function Apply(wasSpots)
	if ns.SpotsChanged then
		ns.SpotsChanged(wasSpots)
	end
	for _, key in ipairs(MODULE_ORDER) do
		if loggedIn and modules[key] and ns.Get(key .. ".enabled") then
			local state = status[key]
			if state.error or state.partsStopped then
				Rearm(key)
			end
			StartModule(key)
		end
	end
	PaintAll()
	Settle()
	if loggedIn and ns.ScaleChanged then
		ns.ScaleChanged("general.scale")
	end
	if loggedIn and ns.SparkleChanged then
		ns.SparkleChanged("general.questSparkle")
	end
	if loggedIn and ns.CursorRingChanged then
		ns.CursorRingChanged("general.cursorRing")
	end
	if ns.NotifyOption then
		for path in pairs(defs) do
			ns.NotifyOption(path)
		end
	end
	if type(ns.RefreshPanel) == "function" then
		local ok, err = pcall(ns.RefreshPanel)
		if not ok then
			geterrorhandler()(err)
		end
	end
	-- Every setting may have changed: test mode draws its samples and stand-ins again.
	TestChanged("*")
end

-- Makes another profile the one in use.
local function Enter(name)
	local was = profile.movers
	current = name
	profile = db.profiles[name]
	values = profile.options
	characterKey = characterKey or ReadCharacter()
	if characterKey then
		db.profileOf[characterKey] = name
	end
	Apply(was)
end

-- Gives the profile in use other settings and positions.
local function Replace(options, movers)
	local was = profile.movers
	profile.options, profile.movers = options, movers
	values = options
	Apply(was)
end

local function CopyOf(source)
	local copy = { options = {}, movers = {} }
	for path, value in pairs(source.options) do
		copy.options[path] = value
	end
	for name, entry in pairs(source.movers) do
		local spot = {}
		for field, value in pairs(entry) do
			spot[field] = value
		end
		copy.movers[name] = spot
	end
	return copy
end

function ns.UseProfile(name)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local found = Find(name)
	if not found then
		return false, "No such profile."
	end
	if found ~= current then
		Enter(found)
	end
	return true, ("Using %s."):format(found)
end

-- Copies `spots`, a table of frame name to spot, into the positions of a new profile. A spot that is not valid is left out.
local function PutSpots(made, spots)
	for frameName, spot in pairs(type(spots) == "table" and spots or {}) do
		local copy = {}
		for field, value in pairs(type(spot) == "table" and spot or {}) do
			copy[field] = value
		end
		if type(frameName) == "string" and ns.CleanSpot(copy) then
			made.movers[frameName] = copy
		end
	end
end

-- A profile made from the settings and positions of another, or from the defaults when copyFrom is nil. It is
-- put in use. `picks`, a table of saved path to value, is written into the new profile before it is put in use, each value as Normalise
-- gives it; a path that is no setting, or that the game or a function holds (never a profile), is left out. `spots`, a table of frame name to
-- spot, is written over the positions of the new profile.
function ns.NewProfile(name, copyFrom, picks, spots)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local clean, why = CleanName(name)
	if not clean then
		return false, why
	end
	if Find(clean) then
		return false, "That name is taken."
	end
	local source
	if copyFrom ~= nil then
		source = Find(copyFrom)
		if not source then
			return false, "No such profile."
		end
	end
	local made = source and CopyOf(db.profiles[source]) or { options = {}, movers = {} }
	if type(picks) == "table" then
		for path, value in pairs(picks) do
			local def = defs[path]
			if def and not Unsaved(def) then
				local fitted = Normalise(def, value)
				if fitted ~= nil then
					made.options[path] = fitted
				end
			end
		end
	end
	PutSpots(made, spots)
	db.profiles[clean] = made
	Enter(clean)
	return true, ("Made %s."):format(clean)
end

-- True once the modules have started, which is when the lists of the choice rows are complete.
function ns.Started()
	return loggedIn
end

-- Puts a profile in use for this character at login, before the modules start, so that they start once with it. The profile of that name when there
-- is one, as it is; else a new one made from `picks` (a table of saved path to value, written as ns.NewProfile writes it). Nothing is applied. Returns
-- true, or false when the modules have started, the settings are not loaded, the character is not known or the name cannot be a profile; nothing is written then.
-- `spots` is written as ns.NewProfile writes it.
function ns.AssignProfile(name, picks, spots)
	if loggedIn or not db or type(name) ~= "string" then
		return false
	end
	characterKey = characterKey or ReadCharacter()
	if not characterKey then
		return false
	end
	local found = Find(name)
	if not found then
		local clean = CleanName(name)
		if not clean then
			return false
		end
		local made = { options = {}, movers = {} }
		if type(picks) == "table" then
			for path, value in pairs(picks) do
				local def = defs[path]
				if def and not Unsaved(def) then
					local fitted = Normalise(def, value)
					if fitted ~= nil then
						made.options[path] = fitted
					end
				end
			end
		end
		PutSpots(made, spots)
		db.profiles[clean] = made
		found = clean
	end
	db.profileOf[characterKey] = found
	current, profile = found, db.profiles[found]
	values = profile.options
	return true
end

-- The settings and positions of the profile in use become a copy of those of another.
function ns.CopyProfile(from)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local source = Find(from)
	if not source then
		return false, "No such profile."
	elseif source == current then
		return false, "That is the profile in use."
	end
	local copy = CopyOf(db.profiles[source])
	Replace(copy.options, copy.movers)
	return true, ("Copied %s."):format(source)
end

-- The profile in use takes `picks`, a table of saved path to value, and is applied once. Each value is written as Normalise gives it; a value equal to
-- the setting's default takes the path out, so the default applies; a path that is no setting, or that the game or a function holds, is left out. The
-- positions stay. Returns true and a line, or false and why (in combat nothing changes). Flat UI setup's Finish calls it.
function ns.ChangeProfile(picks)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local copy = CopyOf(profile)
	for path, value in pairs(type(picks) == "table" and picks or {}) do
		local def = defs[path]
		if def and not Unsaved(def) then
			local fitted = Normalise(def, value)
			if fitted ~= nil then
				if fitted == def.default then
					copy.options[path] = nil
				else
					copy.options[path] = fitted
				end
			end
		end
	end
	Replace(copy.options, profile.movers)
	return true, ("Saved %s."):format(current)
end

-- A profile takes another name. The rules of Switch automatically and the profile of every character follow it.
function ns.RenameProfile(from, to)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	if not db then
		return false, "Profiles are not ready yet."
	end
	local found = Find(from)
	if not found then
		return false, "No such profile."
	elseif found == DEFAULT then
		return false, "Default cannot be renamed."
	end
	local clean, why = CleanName(to)
	if not clean then
		return false, why
	end
	local other = Find(clean)
	if other and other ~= found then
		return false, "That name is taken."
	end
	if clean ~= found then
		db.profiles[clean], db.profiles[found] = db.profiles[found], nil
		for key, used in pairs(db.profileOf) do
			if used == found then
				db.profileOf[key] = clean
			end
		end
		if current == found then
			current = clean
		end
		if ns.scaleMoved and ns.scaleMoved[found] ~= nil then
			ns.scaleMoved[clean], ns.scaleMoved[found] = ns.scaleMoved[found], nil
		end
		-- A saved draft of Flat UI setup that starts from this profile follows the name.
		for _, draft in pairs(type(db.setup) == "table" and type(db.setup.drafts) == "table" and db.setup.drafts or {}) do
			if type(draft) == "table" and draft.from == found then
				draft.from = clean
			end
		end
		if ns.ProfileSwitch then
			ns.ProfileSwitch.Renamed(found, clean)
		end
		if type(ns.RefreshPanel) == "function" then
			local ok, err = pcall(ns.RefreshPanel)
			if not ok then
				geterrorhandler()(err)
			end
		end
	end
	return true, ("Renamed %s to %s."):format(found, clean)
end

function ns.DeleteProfile(name)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local found = Find(name)
	if not found then
		return false, "No such profile."
	elseif found == DEFAULT then
		return false, "Default cannot be deleted."
	elseif found == current then
		return false, "The profile in use cannot be deleted."
	end
	db.profiles[found] = nil
	if ns.ProfileSwitch then
		ns.ProfileSwitch.Deleted(found)
	end
	for key, used in pairs(db.profileOf) do
		if used == found then
			db.profileOf[key] = nil
		end
	end
	return true, ("Deleted %s."):format(found)
end

-- Every setting of the profile in use goes back to its default and every moved frame goes back.
function ns.ResetProfile()
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	Replace({}, {})
	return true, ("Reset %s."):format(current)
end

-- Text form of a profile ---------------------------------------------------------------------
-- "FlatUI1:" and then the settings that differ from their defaults and the positions, one record to a line, as letters,
-- digits, "-" and "_" in groups of three bytes to four characters, and six characters of check value at the end.

local PREFIX = "FlatUI1:"
local DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VALUE_OF = {}
for index = 1, #DIGITS do
	VALUE_OF[DIGITS:sub(index, index)] = index - 1
end
local CHECK_LENGTH = 6

local function Digit(value)
	return DIGITS:sub(value + 1, value + 1)
end

local function Encode(data)
	local out = {}
	for at = 1, #data, 3 do
		local a, b, c = data:byte(at, at + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local chars = Digit(math.floor(n / 262144)) .. Digit(math.floor(n / 4096) % 64)
		if b then
			chars = chars .. Digit(math.floor(n / 64) % 64)
		end
		if c then
			chars = chars .. Digit(n % 64)
		end
		out[#out + 1] = chars
	end
	return table.concat(out)
end

-- The bytes a text of letters, digits, "-" and "_" holds, or nil when its length cannot come from Encode.
local function Decode(text)
	if #text % 4 == 1 then
		return nil
	end
	local out = {}
	for at = 1, #text, 4 do
		local group = text:sub(at, at + 3)
		local n = 0
		for index = 1, 4 do
			n = n * 64 + (VALUE_OF[group:sub(index, index)] or 0)
		end
		out[#out + 1] = string.char(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256):sub(1, #group - 1)
	end
	return table.concat(out)
end

-- Six characters that change when any character of the text changes or the text is cut short.
local function Check(text)
	local sum = 0
	for index = 1, #text do
		sum = (sum * 65599 + text:byte(index)) % 4294967291
	end
	local chars = {}
	for place = CHECK_LENGTH - 1, 0, -1 do
		chars[#chars + 1] = Digit(math.floor(sum / 64 ^ place) % 64)
	end
	return table.concat(chars)
end

-- A field of a record: the separator, the escape and line breaks are written as % and two hex digits.
local function Escape(text)
	return (text:gsub("[%%|\r\n]", function(char)
		return ("%%%02X"):format(char:byte())
	end))
end

local function Unescape(text)
	return (text:gsub("%%(%x%x)", function(code)
		return string.char(tonumber(code, 16))
	end))
end

local function Parse(def, text)
	if def.kind == "bool" then
		if text == "1" then
			return true
		elseif text == "0" then
			return false
		end
		return nil
	elseif def.kind == "number" then
		return tonumber(text)
	end
	return text
end

-- The first line of a text that names its profile: the name, the build, the screen size in pixels and the UI scale it was made on.
local function HeaderLine()
	local width, height, scale = 0, 0, 0
	if type(GetPhysicalScreenSize) == "function" then
		local ok, w, h = pcall(GetPhysicalScreenSize)
		if ok and type(w) == "number" and type(h) == "number" and not IsSecret(w) and not IsSecret(h) and w > 0 and w < 1e6 and h > 0 and h < 1e6 then
			width, height = math.floor(w + 0.5), math.floor(h + 0.5)
		end
	end
	if type(UIParent) == "table" and type(UIParent.GetScale) == "function" then
		local ok, value = pcall(UIParent.GetScale, UIParent)
		if ok and type(value) == "number" and not IsSecret(value) and value == value and value < 1e6 then
			scale = value
		end
	end
	return table.concat({ "h", Escape(current or ""), Escape(Version() or ""), ("%d"):format(width), ("%d"):format(height), ("%.4g"):format(scale) }, "|")
end

-- One line of text that holds the profile in use. With `opts` the text starts with the line of HeaderLine, `opts.modules` (a set of module keys, the
-- part of a saved path before the dot) limits the settings to those modules, and `opts.spots` false leaves the frame positions out.
function ns.ExportProfile(opts)
	if not profile then
		return ""
	end
	opts = type(opts) == "table" and opts or nil
	local modules = opts and type(opts.modules) == "table" and opts.modules or nil
	local lines, paths, names = {}, {}, {}
	for path, value in pairs(values) do
		if defs[path] and value ~= defs[path].default and (not modules or modules[path:match("^[^.]*")]) then
			paths[#paths + 1] = path
		end
	end
	-- A sound line always comes with its flash line, so an older text with a sound alone is told from this one (ImportProfile).
	local listed = {}
	for _, path in ipairs(paths) do
		listed[path] = true
	end
	if listed["enemycd.sound"] and not listed["enemycd.flash"] and defs["enemycd.flash"] then
		paths[#paths + 1] = "enemycd.flash"
	end
	table.sort(paths)
	for _, path in ipairs(paths) do
		local kind, value = defs[path].kind, values[path]
		if kind == "bool" then
			value = value and "1" or "0"
		elseif kind == "number" then
			value = ("%.17g"):format(value)
		end
		lines[#lines + 1] = table.concat({ "o", Escape(path), Escape(value) }, "|")
	end
	for name in pairs(opts and opts.spots == false and {} or profile.movers) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local spot = profile.movers[name]
		lines[#lines + 1] = table.concat({ "m", Escape(name), spot.point, ("%.17g"):format(spot.x), ("%.17g"):format(spot.y),
			spot.scale and ("%.17g"):format(spot.scale) or "", spot.kind, Escape(spot.label or "") }, "|")
	end
	if opts then
		table.insert(lines, 1, HeaderLine())
	end
	return ns.PackText(PREFIX, lines)
end

-- One line of text from the lines of records: the prefix, the lines in the packing and the check value.
function ns.PackText(prefix, lines)
	local body = Encode(table.concat(lines, "\n"))
	return prefix .. body .. Check(body)
end

-- The lines of a text from PackText with that prefix, blanks around the text ignored. Nil and "prefix" when the text does not start with
-- the prefix or has other characters, nil and "incomplete" when the check value or the length is wrong.
function ns.UnpackText(prefix, text)
	text = type(text) == "string" and not IsSecret(text) and text:match("^%s*(.-)%s*$") or ""
	if text:sub(1, #prefix) ~= prefix or text:find("[^A-Za-z0-9_%-]", #prefix + 1) then
		return nil, "prefix"
	end
	local rest = text:sub(#prefix + 1)
	local body = rest:sub(1, #rest - CHECK_LENGTH)
	local data = #rest >= CHECK_LENGTH and rest:sub(-CHECK_LENGTH) == Check(body) and Decode(body)
	if not data then
		return nil, "incomplete"
	end
	local lines = {}
	for line in (data .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

-- What a text from ExportProfile holds: the settings by saved path, the positions by frame name, the fields of its first line (nil for a text of an
-- older build, which has none) and the Small scale that a custom scale under 65% moved to (nil when none did). Nil and the sentence why not for a
-- text that cannot be read.
local function ReadProfile(text)
	local lines, why = ns.UnpackText(PREFIX, text)
	if not lines then
		return nil, why == "prefix" and "That is not a Flat UI profile." or "The text is incomplete."
	end
	local header, moved
	local options, spots, rawScale, oldWord, oldMove, oldDim, oldText, oldSound = {}, {}, nil, nil, nil, nil, {}, {}
	for _, line in ipairs(lines) do
		local fields = {}
		for field in (line .. "|"):gmatch("([^|]*)|") do
			fields[#fields + 1] = Unescape(field)
		end
		-- Sound rows of an older build (LoadSettings): the bool of Sound when ready is "1" or "0".
		if fields[1] == "o" and (fields[2] == "cooldowns.readySound" or fields[2] == "enemycd.ready" or fields[2] == "enemycd.sound"
			or fields[2] == "enemycd.flash") then
			oldSound[fields[2]] = fields[3] == "1" and true or fields[3] == "0" and false or fields[3]
		end
		local def = fields[1] == "o" and defs[fields[2]]
		-- A tick of an older build in a row that is a choice now.
		if fields[1] == "o" and (fields[3] == "1" or fields[3] == "0") then
			oldText[fields[2]] = fields[3] == "1"
		end
		if def and not Unsaved(def) then
			if fields[2] == "general.scale" then
				rawScale = Parse(def, fields[3])
			end
			options[fields[2]] = Normalise(def, Renamed(fields[2], Parse(def, fields[3])))
		elseif fields[1] == "h" then
			header = { name = fields[2], version = fields[3], width = tonumber(fields[4]) or 0, height = tonumber(fields[5]) or 0, scale = tonumber(fields[6]) or 0 }
		elseif fields[1] == "o" and fields[2] == "combattext.word" then
			oldWord = fields[3]
		elseif fields[1] == "o" and fields[2] == "combattext.ownMove" then
			oldMove = fields[3]
		elseif fields[1] == "o" and fields[2] == "unitframes.partyRangeAlpha" then
			oldDim = tonumber(fields[3])
		elseif fields[1] == "m" and fields[2] ~= "" then
			spots[fields[2]] = ns.CleanSpot({ point = fields[3], x = tonumber(fields[4]), y = tonumber(fields[5]), scale = tonumber(fields[6]),
				kind = fields[7], label = fields[8] ~= "" and fields[8] or nil })
		end
	end
	if ns.MigrateSounds then
		oldSound["trackers.kit"] = options["trackers.kit"]
		-- A sound line with no flash line and no ready line is an older text, whose default sound was none.
		ns.MigrateSounds(oldSound, oldSound["enemycd.sound"] ~= nil and oldSound["enemycd.flash"] == nil)
		for _, path in ipairs({ "cooldowns.readySound", "enemycd.flash", "enemycd.sound" }) do
			if oldSound[path] ~= nil and defs[path] then
				options[path] = Normalise(defs[path], oldSound[path])
			end
		end
	end
	-- Combat text rows of an older build, as for a saved profile (LoadSettings).
	if oldWord == "0" and options["combattext.partial"] == nil and defs["combattext.partial"] then
		options["combattext.partial"] = "off"
	end
	if oldMove and options["combattext.inStyle"] == nil and defs["combattext.inStyle"] then
		options["combattext.inStyle"] = oldMove == "arc" and "arc" or "straight"
	end
	-- Out of range dimming on party frames is Out of range opacity, as for a saved profile (LoadSettings).
	if oldDim and oldDim == oldDim and options["unitframes.partyRangeOpacity"] == nil and defs["unitframes.partyRangeOpacity"] then
		options["unitframes.partyRangeOpacity"] = Normalise(defs["unitframes.partyRangeOpacity"], 100 - oldDim)
	end
	ns.MigrateText(oldText, options)
	-- A custom scale under the game's own 65% moves to Small scale, as for a saved profile (LoadSettings).
	if type(rawScale) == "number" and rawScale == rawScale and rawScale < 65 and defs["general.scaleSmall"] then
		options["general.scaleSmall"] = Normalise(defs["general.scaleSmall"], math.floor(rawScale + 0.5))
		options["general.scale"] = 65
		if options["general.scaleOn"] == true then
			options["general.scaleOn"] = false
			moved = options["general.scaleSmall"]
		end
	end
	return options, spots, header, moved
end

-- What a text holds, for a preview before it is imported: the name and build it was made with, the screen it was made on, and how many settings
-- and positions it has. Nil and the sentence why not for a text that cannot be read.
function ns.ProfilePreview(text)
	local options, spots, header = ReadProfile(text)
	if not options then
		return nil, spots
	end
	local settings, positions = 0, 0
	for _ in pairs(options) do
		settings = settings + 1
	end
	for _ in pairs(spots) do
		positions = positions + 1
	end
	header = header or { name = "", version = "", width = 0, height = 0, scale = 0 }
	return { name = header.name, version = header.version, width = header.width, height = header.height, scale = header.scale, settings = settings,
		spots = positions }
end

-- The settings and positions of the profile in use are replaced by what a text from ExportProfile holds. A setting
-- the text does not name goes back to its default; a setting this build does not have is ignored. With `opts`, `opts.settings` false keeps the
-- settings in use, `opts.spots` false keeps the positions in use, and `opts.newName` puts what is left in a new profile, which is then the profile in use.
function ns.ImportProfile(text, opts)
	local refusal = Refusal()
	if refusal then
		return false, refusal
	end
	local options, spots, _, moved = ReadProfile(text)
	if not options then
		return false, spots
	end
	opts = type(opts) == "table" and opts or {}
	if opts.settings == false then
		options = nil
	end
	if opts.spots == false then
		spots = nil
	end
	if opts.newName ~= nil then
		local done, message = ns.NewProfile(opts.newName, nil, options or {}, spots or {})
		if not done then
			return false, message
		end
	else
		local kept = CopyOf(profile)
		Replace(options or kept.options, spots or kept.movers)
	end
	if moved and options then
		ns.scaleMoved = ns.scaleMoved or {}
		ns.scaleMoved[current] = moved
	end
	return true, ("Imported into %s."):format(current)
end

local frame = CreateFrame("Frame")
local moduleEvents = {}

local function Listen(event)
	return pcall(frame.RegisterEvent, frame, event)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
Listen("UI_SCALE_CHANGED")
Listen("DISPLAY_SIZE_CHANGED")
Listen("EDIT_MODE_LAYOUTS_UPDATED")
Listen("ADDON_ACTION_BLOCKED")
Listen("ADDON_ACTION_FORBIDDEN")
Listen("CVAR_UPDATE")
local taintNoticed = false

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == ADDON_NAME then
			LoadSettings()
			for key, module in pairs(modules) do
				for name in pairs(module.events or {}) do
					if not moduleEvents[name] then
						moduleEvents[name] = Listen(name) and {} or nil
					end
					if moduleEvents[name] then
						moduleEvents[name][key] = true
					end
				end
			end
			if ns.RegisterOptions then
				local ok, err = pcall(ns.RegisterOptions)
				if not ok then
					geterrorhandler()(err)
				end
			end
			return
		end
		-- Another addon's ADDON_LOADED goes on to the modules that listen for it.
	end
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		-- A call the game refused raises no Lua error, so it is kept here for /flatui status.
		local addon, call = ...
		if addon == ADDON_NAME then
			blockedTotal = blockedTotal + 1
			blockedLast = tostring(call)
			if #blocked < MAX_BLOCKED then
				-- The kind is kept: a forbidden call is one the game never allows an add-on, a blocked one is refused here and now.
				blocked[#blocked + 1] = ("%s (%s)"):format(blockedLast, event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked")
			end
			-- The values the click path reads are checked for the add-on that changed them, and the result is kept for /flatui status.
			if ns.TaintRecord then
				pcall(ns.TaintRecord, event, call)
			end
		end
		return
	end
	if event == "CVAR_UPDATE" then
		-- taintLog turned on after login: said once a session (ConsoleDocumentation.lua:174-183 gives the name and the new value).
		local name, value = ...
		if loggedIn and not taintNoticed and type(name) == "string" and name:lower() == "taintlog" and not IsSecret(value) and type(value) == "string"
			and value ~= "0" then
			taintNoticed = true
			print("Flat UI: taintLog is on. Turn it off with /console taintLog 0, then /reload.")
		end
	end
	if not db then
		return
	end
	if event == "PLAYER_LOGIN" then
		-- First, so that a profile chosen for a new character is in use before any module starts (ns.AssignProfile refuses once loggedIn is set).
		if ns.SetupAuto then
			local ok, err = pcall(ns.SetupAuto)
			if not ok then
				geterrorhandler()(err)
			end
		end
		loggedIn = true
		if resetNotice then
			resetNotice = false
			print("Flat UI: Unit frames portrait settings are back at their defaults.")
		end
		for _, key in ipairs(MODULE_ORDER) do
			if modules[key] then
				StartModule(key)
			end
		end
		if ns.TaintReminder and ns.TaintLogging() then
			ns.TaintReminder()
		end
		if ns.SetupLogin then
			local ok, err = pcall(ns.SetupLogin)
			if not ok then
				geterrorhandler()(err)
			end
		end
		-- Quest item sparkle and Sparkle strength are written at every login, and Glow on the nearest object starts (Sparkle.lua).
		if ns.SparkleChanged then
			local ok, err = pcall(ns.SparkleChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
		-- The cursor ring shows from the login (CursorRing.lua).
		if ns.CursorRingChanged then
			local ok, err = pcall(ns.CursorRingChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
		-- Compare items only while holding Shift is written at every login, whatever the switch of Chat and tooltips (ItemCompare.lua).
		if ns.ItemCompareSync then
			local ok, err = pcall(ns.ItemCompareSync)
			if not ok then
				geterrorhandler()(err)
			end
		end
		-- In-game navigation is written at every login, whatever the switch of Errands (ErrandsNavigation.lua).
		if ns.ErrandsNavigationChanged then
			local ok, err = pcall(ns.ErrandsNavigationChanged)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif event == "CVAR_UPDATE" then
		-- A graphics preset puts the quest item sparkle variable and the graphics variables of Sparkle strength back (Sparkle.lua).
		if loggedIn and ns.SparkleCVar then
			local ok, err = pcall(ns.SparkleCVar, ...)
			if not ok then
				geterrorhandler()(err)
			end
		end
		-- The game or the player wrote showInGameNavigation (ErrandsNavigation.lua).
		if loggedIn and ns.ErrandsNavigationCVar then
			local ok, err = pcall(ns.ErrandsNavigationCVar, ...)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		local queued = afterCombat
		afterCombat = {}
		for _, fn in ipairs(queued) do
			local ok, err = pcall(fn)
			if not ok then
				geterrorhandler()(err)
			end
		end
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
		ns.ResizeAll()
	end
	local listeners = moduleEvents[event]
	if listeners then
		for key in pairs(listeners) do
			local filter = modules[key].filters and modules[key].filters[event]
			if status[key].started and ns.Enabled(key) and (not filter or filter(...)) then
				ns.Try(key, modules[key].events[event], ...)
			end
		end
	end
end)

SLASH_FLATUI1 = "/flatui"
SlashCmdList["FLATUI"] = function(msg)
	if not db then
		return
	end
	local typed = (msg or ""):match("^%s*(.-)%s*$")
	local text = typed:lower()
	-- Test mode's words come before the modules' (Defensives has the word test, for test icons): test toggles, test on and test off.
	local test = text:gsub("%s+", " ")
	if (test == "test" or test == "test on" or test == "test off") and ns.TestMode then
		local call = test == "test" and ns.TestMode.Toggle or test == "test on" and ns.TestMode.On or ns.TestMode.Off
		local ok, err = pcall(call, test == "test off" and "toggle" or "slash")
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	-- A module's own commands: the first word picks the command, the rest goes to it as typed.
	local verb, rest = typed:match("^(%S+)%s*(.-)$")
	if verb then
		for _, key in ipairs(MODULE_ORDER) do
			local command = modules[key] and modules[key].slash and modules[key].slash[verb:lower()]
			if command then
				local ok, err = pcall(command, rest)
				if not ok then
					geterrorhandler()(err)
				end
				return
			end
		end
	end
	if verb and verb:lower() == "cvar" and type(ns.CVarCommand) == "function" then
		local ok, err = pcall(ns.CVarCommand, rest)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if text == "taint" and type(ns.TaintCommand) == "function" then
		local ok, err = pcall(ns.TaintCommand)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "setup" and rest == "" and type(ns.OpenSetup) == "function" then
		local ok, err = pcall(ns.OpenSetup)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "welcome" and rest == "" and type(ns.OpenWelcome) == "function" then
		local ok, err = pcall(ns.OpenWelcome)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if verb and verb:lower() == "profiles" and rest == "" and type(ns.OpenProfiles) == "function" then
		local ok, err = pcall(ns.OpenProfiles)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if text == "" and type(ns.OpenPanel) == "function" then
		local ok, err = pcall(ns.OpenPanel)
		if ok then
			return
		end
		geterrorhandler()(err)
	end
	if text == "" or text == "options" then
		local opened, reason = false, nil
		if ns.OpenOptions then
			opened, reason = ns.OpenOptions()
		end
		if reason == "combat" then
			print("Options open after combat.")
		elseif not opened then
			for _, line in ipairs(ns.StatusLines()) do
				print(line)
			end
		end
	elseif text == "status" then
		for _, line in ipairs(ns.StatusLines()) do
			print(line)
		end
	elseif text == "profile" then
		local others = {}
		for _, name in ipairs(ns.Profiles()) do
			if name ~= current then
				others[#others + 1] = name
			end
		end
		print(("Profile: %s"):format(current))
		print(#others > 0 and ("Other profiles: %s"):format(table.concat(others, ", ")) or "No other profiles.")
	elseif verb and verb:lower() == "profile" then
		print((select(2, ns.UseProfile(rest))))
	elseif text == "scale off" then
		ns.Set("general.scaleOn", false)
		print("Custom UI scale: off")
	elseif text:find("^scale%s+%d+$") then
		local percent = tonumber(text:match("%d+"))
		if percent >= 65 and percent <= 115 then
			ns.Set("general.scale", percent)
			ns.Set("general.scaleOn", true)
			print(("Custom UI scale: %d%%"):format(percent))
		else
			print("/flatui scale takes 65 to 115.")
		end
	else
		print("/flatui - the settings window")
		print("/flatui options - the page in the game's options")
		print("/flatui status - what is styled, and any error")
		print("/flatui profile - the profile in use and the others")
		print("/flatui profile Name - switch to a profile")
		print("/flatui setup - walk round your screen in six short stops")
		print("/flatui profiles - the ready-made looks; a click puts one in use")
		print("/flatui welcome - the welcome screen")
		print("/flatui scale 70 - custom UI scale in percent, 65 to 115")
		print("/flatui scale off - the game's own UI scale")
		print("/flatui test - samples of your hidden frames on screen until you turn it off")
		print("/flatui taint - the action button click path, checked for values an add-on changed")
		print("/flatui cvar - each game setting row: value, default, secure flag")
		print("/flatui cvar check - whether each of those can be changed, out of combat")
		for _, key in ipairs(MODULE_ORDER) do
			for _, line in ipairs(modules[key] and modules[key].help or {}) do
				print(line)
			end
		end
	end
end
