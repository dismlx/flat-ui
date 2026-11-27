Every setting of the **Layout** group of the options window, 122 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Layout](Layout).

Pages: [Movers](#movers) · [Fading](#fading) · [Hidden frames](#hidden-frames) · [Tooltip position](#tooltip-position)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.47.

## Movers

| Setting | Default | Notes |
| --- | --- | --- |
| **Move frames** | On | Type /flatui move to show the handles. |
| **Move the game's own frames** | On | Player frame, minimap and the rest. Edit Mode still works; a frame moved here stays where you put it. Action bars stay where the game puts them while Leave the game's action bars alone is on, but for the bars of a block of the Bar block page. |
| **Bars on a preset layout** | Copy into a Flat UI layout | A preset cannot hold moved bars. The Reload button can copy it into a layout named Flat UI. Choices: Copy into a Flat UI layout, Leave the preset. |
| **Edit Mode layout as text** |  |  |
| **Show handles in Edit Mode** | Off |  |
| **Keep moved frames in place** | On | Puts a frame back when the game moves it. |

**Centre**

| Setting | Default | Notes |
| --- | --- | --- |
| **Snap while dragging** | To the middle of the screen | A handle or a window snaps when its middle is within 8 units of the middle of the screen. Choices: To the middle of the screen, Off. |
| **Centre a handle with** | A button on the handle | The height stays as it is. Choices: A button on the handle, Alt and click, Both. |
| **Middle line** | Shown while dragging | Choices: Shown while dragging, Always shown with the handles, Off. |
| **Centre everything** | A button in the Movers panel | Tick the box on each handle, then press Centre ticked in the Movers panel. Choices: No such button, A button in the Movers panel. |

**Windows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Open windows under the unit frames** | On | A window the game would open over the player or target frame at the top of the screen opens just under them, with the windows beside it. A window you moved stays where you put it. |
| **Window dragging** | On | Right-click a title bar to put the window back. |
| **Drag from** | Anywhere on the window | Buttons, slots, lists and models keep their clicks. Choices: Anywhere on the window, Title bar. Needs **Window dragging** on. |
| **Key held while dragging** | None | With a key held, a drag also starts on models. Choices: None, Shift, Alt, Ctrl. Needs **Window dragging** on. |
| **Corner grip** | Shown on mouseover | Drag the corner to size a window, right-click it for 100%. Choices: Shown on mouseover, Always shown, Off. |
| **Positions and sizes** | Back to default when the window closes | Choices: Kept, Back to default when the window closes. |
| **Size applies to** | Each window | Choices: Each window, Every window together. |
| **Size of every window** | 100% | Used with Every window together. |
| **Reset windows** |  |  |

## Fading

| Setting | Default | Notes |
| --- | --- | --- |
| **Fade frames when idle** | On | A frame ticked on the Hidden frames page stays hidden: it is not faded, and fades again once it is back. Faded frames come back to full in Edit Mode and while /flatui move is open, so you see what you line up. |

**What fades**

| Setting | Default | Notes |
| --- | --- | --- |
| **Main action bar** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 2** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 3** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 4** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 5** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 6** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 7** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Action bar 8** | Off | With Flat UI's action buttons it fades Flat UI's bar, also while Leave the game's action bars alone is on. With the game's buttons it is not applied while that is on. |
| **Stance bar** | Off | Not applied while Leave the game's action bars alone is on. |
| **Pet bar** | Off | Not applied while Leave the game's action bars alone is on. |
| **Micro menu** | On | The micro menu's buttons fade together, the help ticket button too, and the mouse over any of them shows them all. Also while Leave the game's action bars alone is on. Micro menu faded opacity takes it down to 0%. |
| **Bag bar** | On | The backpack, the bag slots, the reagent bag and the keyring fade together, and the mouse over any of them shows them all. Also while Leave the game's action bars alone is on. Bag bar faded opacity takes it down to 0%. |
| **Bag windows** | Off | Your open bag and bank windows, Flat UI's or the game's, the keyring's and the reagent bag's too. A window shows in full as it opens, under the mouse, while an item is on the cursor, a stack is being split or you type in its search box. |
| **Player frame** | Off |  |
| **Pet frame** | Off |  |
| **Experience bar** | Off | Flat UI's experience and reputation bar, while it is the one in use (Experience bar on the Experience and menu bars page). A gain shows it in full while it rises. While block 1 of the Bar block page holds it with Fade the block on, it fades with the block. |
| **Minimap buttons** | Off | The game's and other addons' minimap buttons, shown while the mouse is over the minimap. |

**When shown**

| Setting | Default | Notes |
| --- | --- | --- |
| **Target frame** | Always | At other times it fades like the frames above, with its cast bar, combo points and target of target. Choices: Always, Only in combat, Only in a group, Only in an instance, Only outside an instance, Only when not mounted. |
| **Focus frame** | Always | At other times it fades like the frames above, with its cast bar and target of target. Choices: Always, Only in combat, Only in a group, Only in an instance, Only outside an instance, Only when not mounted. |
| **Buffs** | Always | Your buffs and weapon enchants, not your debuffs. At other times they fade like the frames above. Choices: Always, Only in combat, Only in a group, Only in an instance, Only outside an instance, Only when not mounted. |
| **Objective tracker** | Always | At other times it fades like the frames above. Only outside an instance with Faded opacity at 0% takes it away in dungeons and raids until the mouse is over it. In a fight, Opacity in combat of the tracker comes first while it is under 100%. Also Questie's tracker while Questie is loaded. Choices: Always, Only in combat, Only in a group, Only in an instance, Only outside an instance, Only when not mounted. |
| **Damage meter** | Always | At other times it fades like the frames above. The game's own Visibility in Edit Mode still applies. Choices: Always, Only in combat, Only in a group, Only in an instance, Only outside an instance, Only when not mounted. |

**Fade**

| Setting | Default | Notes |
| --- | --- | --- |
| **Faded opacity** | 90% | Faded buttons still work. |
| **Micro menu faded opacity** | As Faded opacity | How far the micro menu fades, the other rows keeping Faded opacity. At 0% it is gone until the mouse is over it, and its buttons still take clicks where they are. Choices: As Faded opacity, 0%, gone until the mouse is over it, 10%, 25%, 50%. Needs **Micro menu** on. |
| **Bag bar faded opacity** | As Faded opacity | How far the bag bar fades, the other rows keeping Faded opacity. At 0% it is gone until the mouse is over one of its buttons, and they still take clicks where they are. Choices: As Faded opacity, 0%, gone until the mouse is over it, 10%, 25%, 50%. Needs **Bag bar** on. |
| **Action bars faded opacity** | As Faded opacity | How far action bars 1 to 8, the stance bar and the pet bar fade, the other rows keeping Faded opacity. At 0% a bar is gone until the mouse is over it, and its buttons still take clicks. A bar in a block that fades takes the Faded opacity of the Bar block page. Choices: As Faded opacity, 0%, gone until the mouse is over it, 10%, 25%, 50%. |
| **Bars come back together** | Off | Pointing at any faded action bar, the stance bar, the pet bar or the page arrows brings all of them back to full, and they wait Wait before fading and fade again together. Bars in a block that fades follow the Bar block page. |
| **Wait before fading** | 100 ms |  |
| **Fade time** | 300 ms | How long a frame takes to fade. Under the mouse it is back to full in a tenth of a second. |

**Stay visible**

| Setting | Default | Notes |
| --- | --- | --- |
| **In combat** | Off |  |
| **With a target** | Off |  |
| **While casting** | Off | A spell or item you use brings faded frames back to full while you cast, for a moment after each instant spell or item, and for Wait before fading after. |
| **While a proc is up** | On | An action bar that holds the spell of a proc alert of the Trackers page, such as Overpower, Revenge or Execute, is at full opacity while the proc is up, and fades again after Wait before fading once it ends. |
| **Until health and mana are full** | Off | Faded frames stay at full while your health, or your mana if you have mana, is under full, so they are there while you eat and drink, then fade after Wait before fading. Not while you are dead. |
| **While a key is held** | None | Holding the key brings every faded frame back to full at once, so you can glance at a cooldown or your bags. They fade again after Wait before fading once you let go. Not while you type in a box. Choices: None, Shift, Ctrl, Alt. |

## Hidden frames

| Setting | Default | Notes |
| --- | --- | --- |
| **Hide the ticked frames** | On | A hidden frame stays hidden when the game shows it again, also after a reload, and comes back as it was when unticked. Fading leaves a hidden frame alone, and it comes back at its own opacity. In a fight a change waits for its end. In /flatui move, Shift and right-click a box, or Hide frame in the inspector; the list there shows hidden frames again. |

**Action bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Main action bar** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 2** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 3** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 4** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 5** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 6** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 7** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Action bar 8** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Stance bar** | Off | Its keys still change stance or form. Not applied while Leave the game's action bars alone is on. |
| **Pet bar** | Off | Its keys still give your pet orders. Not applied while Leave the game's action bars alone is on. |
| **Possess bar** | Off | The bar of a creature you control. Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Totem bar** | Off | Its keys still work. Not applied while Leave the game's action bars alone is on. |
| **Leave vehicle button** | Off | The button that gets you out of a vehicle. Not applied while Leave the game's action bars alone is on. |
| **Micro menu** | Off | Takes away the buttons for your character, spellbook, talents, quests, group finder and game menu, with the help ticket button. Their keys, such as C, P and L, and Escape still open the windows. The main bar and the frames above it keep their places. Also while Leave the game's action bars alone is on; after a vehicle in a fight it shows until the fight ends. |
| **Bag bar** | Off | Takes away the backpack, bag, reagent bag and keyring buttons. B and the bag keys still open the bags. Also while Leave the game's action bars alone is on. |
| **Game's experience bar** | Off | The game's experience or reputation bar, not Flat UI's own. Not applied while Leave the game's action bars alone is on. |
| **Game's second status bar** | Off | The game's second bar, for a reputation you watch. Not applied while Leave the game's action bars alone is on. |

**Unit frames**

| Setting | Default | Notes |
| --- | --- | --- |
| **Player frame** | Off | Your health and power. Your cast bar goes with it while Edit Mode locks it to the player frame, and so do the pet frame, the totems and the class resource bars while Edit Mode keeps them under it. |
| **Target frame** | Off | With its cast bar, combo points and target of target. You still target as before. |
| **Focus frame** | Off | With its cast bar and target of target. |
| **Pet frame** | Off | Your pet's health and power. It also goes with the Player frame while Edit Mode keeps it under that one. |
| **Party frames** | Off | The game's party frames. |
| **Raid frames** | Off | The game's raid frames. The raid manager at the left edge stays. |
| **Boss frames** | Off | The frames of a boss in a dungeon or raid. |

**Minimap**

| Setting | Default | Notes |
| --- | --- | --- |
| **Minimap** | Off | The whole minimap with its buttons and the zone name. |
| **Zone name on the minimap** | Off | The plate with the zone name over the map. |
| **Tracking button** | Off | The button that picks what the map tracks. |
| **Mail icon** | Off | The icon that says you have mail. |
| **Calendar button** | Off | The day and night button that opens the calendar. |
| **Clock** | Off | The clock by the map, which opens the stopwatch and alarm. |
| **Addon button** | Off | The button that lists your addons. |
| **Zoom buttons** | Off | The + and - that show while the mouse is over the map. |

**Buffs and debuffs**

| Setting | Default | Notes |
| --- | --- | --- |
| **Buffs** | Off | Your buffs and weapon enchants, with the right-click that cancels a buff. |
| **Debuffs** | Off | Your debuffs. |
| **External defensives** | Off | The defensive spells others cast on you. |

**Bars and timers**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cast bar** | Off | Your cast bar. While Edit Mode locks it to the player frame it also hides with that frame. |
| **Personal resource display** | Off | The health and power bars under your character. |
| **Main hand swing timer** | Off | The game's swing timer of your main hand. |
| **Off hand swing timer** | Off | The game's swing timer of your off hand. |
| **Ranged swing timer** | Off | The game's swing timer of your ranged weapon. |
| **Timer bars** | Off | The breath, fatigue and feign death bars. |
| **Encounter bar** | Off | The bar of a boss fight that has one. |
| **Durability** | Off | The armour figure that shows when your gear is damaged. |
| **Archaeology bar** | Off | The progress bar of a dig site. |

**Messages and alerts**

| Setting | Default | Notes |
| --- | --- | --- |
| **Alerts** | Off | The toasts for achievements, loot and the like: each one goes as it comes, and one that comes in a fight goes when the fight ends. |
| **Error text** | Off | The red error messages and the yellow quest progress in the middle of the screen. |
| **Zone text** | Off | The zone and subzone names in the middle of the screen as you enter them. |
| **Raid warning** | Off | Raid warnings in the middle of the screen. |
| **Loss of control** | Off | The alert while you are stunned, feared or silenced. |
| **Talking head** | Off | The portrait of a speaking character. Its voice still plays; Hide the talking head on the Messages and timers page stops both. |
| **Top widgets** | Off | Scores and objectives at the top of the screen in a battleground or an event. |

**Trackers and meters**

| Setting | Default | Notes |
| --- | --- | --- |
| **Objective tracker** | Off | Your quests and their item buttons. The quest log still has them. |
| **Damage meter** | Off | The game's damage meter and its windows. |
| **Group finder eye** | Off | The eye that shows while you queue for a group. The group finder window still shows your queue. |
| **Extra abilities** | Off | The extra action button of a quest or a fight. Its key still works. |
| **Vehicle seats** | Off | The seats of a vehicle with room for more than one. |
| **Essential cooldowns** | Off | A row of the game's cooldown manager. |
| **Utility cooldowns** | Off | A row of the game's cooldown manager. |
| **Tracked buffs** | Off | The buff icons of the game's cooldown manager. |
| **Tracked buff bars** | Off | The buff bars of the game's cooldown manager. |

## Tooltip position

| Setting | Default | Notes |
| --- | --- | --- |
| **Place the tooltip** | On |  |
| **Position** | At the cursor | The Tooltip handle shows with /flatui move while Fixed is chosen. Choices: At the cursor, Fixed. |
| **Tooltip point** | Bottom left | The corner of the tooltip placed at the cursor or the fixed spot. At the cursor, a tooltip that would pass the screen's edge goes to the cursor's other side, mirrored, so it never covers what you point at. Choices: Top left, Top, Top right, Left, Centre, Right, Bottom left, Bottom, Bottom right. |
| **X offset** | 69 | Positive moves the tooltip right when it follows the cursor. |
| **Y offset** | -48 | Positive moves the tooltip up when it follows the cursor. |
| **Applies to** | Every tooltip | Choices: Unit frames, action bars and the world, Every tooltip. |
