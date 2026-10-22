## 0.4.94

- **Options window**: the window is 1040 by 680 and starts with no borders. Ctrl and the mouse wheel over the title bar change **Window scale**.
- **Flat UI** page: new section **Options window** with **Accent colour**, **Custom accent colour**, **Window tone**, **Borders**, **Corners**, **Density**, **Window font** and **Window scale**. Every profile uses the same values.

## 0.4.93

- **Cast bars** and **Swing timers**: the player cast bar and the swing timers now have the width of the personal resource display. Set **Bar width** of the display in Edit Mode to size all three. A saved **Player cast bar width** is not used while **Player cast bar** is **Width of the personal resource display**. Pick **Width set below** or **Width set in Edit Mode** to keep the old widths.

## 0.4.92

- **Minimap**: new **Addon buttons** for the round buttons other addons put on the map. By default they stand in a column beside the map. **Row under the map** and **Where each addon puts them** are the other choices.

## 0.4.91

- **Buffs and debuffs**: new **Duration format** and **Duration colour** under **Duration size**. By default the time shows 8m in white. Both also cover the totem times under the player frame. New **Totem time size** on **All frames: icons and auras**, which starts at 80%.

## 0.4.90

- **Button text**: new **Hotkey text**. Mouse buttons, the mouse wheel, the number pad, Page Up and Page Down show short by default, such as M4, WU, N1 and s-M4. The hotkey no longer ends in dots.

## 0.4.89

- **Target of target frame**: new **Long names**. A name wider than the row is now set in smaller text, down to 75%. A longer name is still cut with dots.
- **Swing timers**: **While not swinging** is now **Show the timer**, with **Always**, **In combat** and **Only while swinging**. It starts as **In combat**, so the empty bar and its 0.0 no longer show out of combat.

## 0.4.87

- **Unit frames**: new **Mana bar colour** on **All frames: bars and pictures**. A mana bar next to a health bar in a blue class colour is now sky blue. **Custom power colours** on the **Colours** page now colours the power bars of the unit frames.

## 0.4.86

- **Chat tabs**: new **Chat tab opacity**. The default is **Selected 100%, others 60%**. The game uses 40% and 20%.

## 0.4.85

- **Class icon shape**: Square or Round, on the **Class icons** section of the **Target and marks** page and on the **Portraits** section of the **Unit frames** page. A round icon has a round border of **Border thickness**. Faces stay square.

## 0.4.84

- **Game menu**: new **Flat UI** button, right below the gap under **Options**. It opens **Flat UI setup**, or the options window when **Flat UI button opens** is **Options window**. It does not work in combat. Untick **Flat UI button in the game menu** on the **Flat UI** page, **Game menu** section, to remove it.

## 0.4.83

- New ready-made profile **Jon Default** in **Flat UI setup**, with the author's own settings and frame positions.

## 0.4.82

- **Combat text**: Outgoing and Incoming numbers curve out to each side of your character by default (**Outgoing style**, **Incoming style** and **Arc width**). Your hits in the Outgoing area and the heals you cast on yourself show the icon of the spell, swing or shot (**Spell icons**). Misses show in parentheses, such as (Dodge) (**Miss words**). Maul, Heroic Strike, Cleave and Raptor Strike no longer show a Miss for the swing they replace. **Next melee ability names** can show their name. Hits of your spells and special attacks show in yellow, and swings, extra attacks and shots in white (**Colour by school of magic** and **Physical ability hits**). `/flatui combat trace` prints each hit report in chat.

## 0.4.81

- **Movement**: new choice **Burst**, now the default. A critical hit over an enemy starts at up to 2.2 times its size, settles in 0.2 seconds, then rises and falls. Other numbers rise and fall as before. With **Plainly** on **How a number appears**, a critical hit starts at its normal size and rises and falls.

## 0.4.80

- Nameplates: the level box is now a square the height of the health bar. The class icon now starts on the left at the same height. The raid marker moves out past the icon. New **Level box shape** and **Level box gap** on the **Level** section of the **Text** page. New **Class icon size** and **Class icon gap** on the **Class icons** section of the **Target and marks** page. **Class icon position** now starts as **Left**. A saved class icon size applies again after you pick **Custom** in **Class icon size**.

## 0.4.79

- **Combat text**: new Outgoing and Incoming scroll areas, with **Where your hits show**, **Outgoing style**, **Incoming style**, **Speed** and **Partial effects**. **Kind of hit in parentheses**, **Smaller glancing hits and words** and **Movement of your text** are gone: **Partial effects** and **Incoming style** replace them. Your own text now starts 170 units left of and 30 below the middle of the screen and moves sideways by default (**Incoming style** Horizontal).

## 0.4.78

- Character window: the side tabs now keep their **Side tab size** when the right pane closes or opens. Their icons no longer grow past the tab and lie over each other.

## 0.4.77

- Windows and the Flat UI options window now return to their default place and size when they close. Choose **Kept** on **Positions and sizes** in the **Windows** section of the **Movers** page to keep them.

## 0.4.76

- **Extra attacks**: a row under **In front of nameplates**. With **Extra attack**, the default, an extra swing such as Windfury shows over the enemy in orange with (Extra attack) after the number. **Off** leaves it out, as before. It shows with **One hit for each of yours**. It does not show with a pet out or in a group. It does not show while a bleed or debuff of yours is on the enemy or the game withholds the aura list. An extra swing shows no Glancing, Block, Resist or Absorb word.

## 0.4.75

- Your buffs: the game's tooltip now shows when the mouse is over a buff, in a fight too, and clicks still reach the world. New **Buff tooltips** on the **Icons** section of the **Your buffs** page, with **On** (default), **Out of combat only** and **Off**

## 0.4.74

- Player, target, focus, target of target, pet, party and boss frames: a power bar of a unit with no power is now hidden. New **Hide empty power bar** on the **Bars** section of the **All frames: bars and pictures** page, On by default
- Target of target frame: **Health bar colour** now starts as **Class**. The bar takes the class colour of a player and the reaction colour of a creature, like the target frame. Choose **Health colour** on the **Target of target frame** page for the flat colour.
- Player, target and focus frames: the PvP word now takes the colour of the name. New **PvP word colour** on the **Name row** section of the **Unit frames** page, with **Same as the name** (default), **White** and **Red**
- Target, focus, target of target and pet frames: the power bar now starts below the health bar with a space. New **Space between bars** on the **Bars** section of the **All frames: bars and pictures** page, 2 px by default and 0 px for none
- Player, target, focus and boss frames: the name now has the room the level and the PvP word leave. New **Name room** on the **Name row** section of the **Unit frames** page, with **Only what the texts need** (default) and **Fixed space**. A unit that is not flagged gives no room to the PvP word
- Target and focus frames: the PvP icon now moves with its plate to the corner set in **Icon corner**. It no longer stays over the world beside the picture
- Target, focus, target of target and pet frames: the power bar now has the width of the health bar. New **Power bar width** on the **Bars** section of the **All frames: bars and pictures** page, with **Same as the health bar** (default) and **Game's width**

## 0.4.73

- **Whose hits** has three choices: **One hit for each of yours**, **Every hit while you attack** and **Everyone's**. The default is **One hit for each of yours**.
- **One hit for each of yours** lets one hit through for each cast, swing, shot and harmful aura of yours. It leaves out:
  - The second and later hits of a spell that hits more than once
  - Ticks of an aura that come sooner than 2.4 seconds after the last one shown
  - Extra melee swings inside 0.8 of the weapon speed, such as Windfury
  - Hits from your own area spells on enemies you do not target
  - Critical aura ticks on enemies you do not target
  - Melee hits of your pet
- The game names no source for a hit, so a hit by another player can take the place of one of yours.
- **Numbers over enemies in a group**: a row under **In front of nameplates**. With **The game's own numbers**, the default, a party or raid shows the game's numbers over enemies, behind the nameplate. Flat UI draws none. **Flat UI numbers** draws them, filtered by **Whose hits**.
- **Size** sets the size of the game's numbers in a group when **Numbers over enemies in a group** is **The game's own numbers**. **Size of experience and other gains** does not apply there.
- When you join a group in combat and the game refuses the change, Flat UI numbers show until combat ends.
- `/flatui combat` names the slot behind a shown hit: cast slot, swing slot, shot slot or aura slot. A hit with no free slot reads "left out (slot taken)".

## 0.4.72

- **Your buffs**: a new page under **Personal resource display**. A row of icons at the personal resource display shows the short buffs you cast, such as seals and shields. Each icon has its time left. The row is on at the start
- **Row in a fight**: the game draws the row, so it works in a fight. When the game makes no icon row, the icons show out of combat only, and `/flatui buffs check` says so
- **Buffs shown**: **Short buffs of your class**, **Every buff you cast** or **Both**. **Time limit** hides buffs that last longer, 60 s at the start
- **Time left**: **Under the icon**, **On the icon**, **Thin bar under the icon** or **Off**. **Icon size** is 28
- **Place**: **Above the bars**, **Under the bars**, **Under the swing timer** or **Own position**, with a **Your buffs** handle in `/flatui move`
- **Buffs that have a tracker**: **Show here too** shows a seal in the row and in its tracker. **Leave out** hides it in the row
- **Trackers**, **Cooldown icons** and **Defensives on you** hang from the row when its place is **Above the bars** or **Under the bars**
- `/flatui buffs check` says how the row is drawn. `/flatui test` shows three sample icons in the row, or says the row is off

## 0.4.71

- Setup: the **Finished** screen is a report that scrolls. It says how many settings you chose and how many came from the profile you started from. It also counts the game settings that setup wrote, and names each one the game kept at another value
- Setup: **Review** and the **Finished** screen list every setting that needs a reload. They list **Action buttons**, **Leave the game's action bars alone** and **One size and spacing for every bar** when you change them. They list switches that take full effect after a reload when you turn them off
- **Setup result in chat**: a new setting in the **Setup** section of the **Flat UI** page and at the foot of **New profile**. **One line** tells you in chat which profile is in use, with the counts, when setup finishes. **None** says nothing. The default is **One line**
- `/flatui status` has a **Setup** line with the profile that setup made, the profile it started from and the counts. It also has a line for each game setting that the game still keeps at another value

## 0.4.70

- **Size of experience and other gains**: a new choice on the **Combat text** page under **Your character**. It sets the size of text the game draws near you, such as experience, while Flat UI draws the numbers over enemies. The default is **Same as your text**
- Before, that text took **Size**, the size of the numbers over enemies, which is 140% by default
- **Smaller than your text** is three quarters of **Size of your text**. **The game's own size** is 100%. **Same as numbers over enemies** follows **Size**, as before
- The choice also sets the size of the game's healing numbers over your target when **Healing over friendly units** is **Healing you do**
- The row shows when **Numbers over enemies** is **In front of nameplates**. With **As the game has them**, **Size** sets the size, as before
- `/flatui combat` names the choice in use under the `WorldTextScale_v2` line

## 0.4.69

- **Tooltips in combat**: the ready-made profiles **Minimal**, **Damage**, **Tank** and **Healer** no longer set it to **Hide unit tooltips**. A profile you made from one of them keeps its value. Change it on the **Tooltips** page under **Combat**
- **Hide unit tooltips**: after you point at a unit in combat, other tooltips now show, such as the experience bar tooltip. Tooltips of the game world stay hidden
- `/flatui status` has a **Tooltips in combat** line with the choice in use
- **Action buttons** at **Flat UI's**: when the game withholds the place of the game's tooltip box, the button's tooltip now shows to the right of the button
- **Fade out** at **Fast**: when you point at something else while a tooltip fades, such as the experience bar right after a unit, the new tooltip stays up
- **Place the tooltip** with **Every tooltip**: when the game withholds the tooltip's scale or the cursor, a tooltip beside its owner now stays where the game puts it

## 0.4.68

- Player frame: the power bar no longer overlaps the bottom of the health bar. The gap between them is 1 unit, or wider where the borders need it. When the game lays the frame out again in combat, the bar moves back under the health bar after combat ends
- Target frame: a right-click on the target frame opens its menu at the cursor, as on the player and focus frames, instead of beside the frame. In combat the menu opens where the game puts it
- `/flatui status` has a **Player bars** line with the gap between the player's health and power bars

## 0.4.67

- **Nameplates**, **Cast bar**: **Cast bar texture** now sets the texture of nameplate cast bars. **Same as the Flat UI page** keeps the texture of the **Flat UI** page

## 0.4.66

- Windows: with **Every window together**, windows now take the shared size on the next frame after the game resizes or opens them, instead of within half a second
- Windows: Legacy and other panels the game shrinks to fit the screen keep following the game's fit, so the shared size stays a percentage of the fit when the UI scale or screen changes

## 0.4.65

- When a window moved the group finder eye, or the minimap changed size, the eye now goes back to the spot you set in the same moment instead of up to half a second later
- The queue eye (group finder eye) now returns to its saved spot when a queue appears, even if the game moved it while it was hidden, for example after leaving a vehicle or override bar
- With **Show the eye** off in the **Looking For Group** window, the eye is now fully invisible, including its animations, and no longer reacts to the mouse

## 0.4.64

- Square portraits: the game's round mask is taken off the game's own portrait while the square picture shows, and again if the game puts it back, so a portrait that shows through stays square

## 0.4.63

- `/flatui combat` now uses plain words: "Your hits ... Casts and swings seen ... Last hit", "Nameplates the game hides from interface mods", "Hit amounts the game would not tell", "Nameplate layer", "Font size made at", "Game world height" and the like. The facts each line reports are unchanged

## 0.4.62

- Fixed: the **Uninterruptible** cast bar in the setup drawing now shows the game's own fill art instead of grey


## 0.4.61

- **Experience bar**: new first row of **Experience and reputation bars**, **Flat UI's** by default. Flat UI draws its own bar, any width from 10% to 130% of the game's full width (35% by default) and 2 to 24 px high (8 by default). The game's bar stays in place and is not drawn. **The game's** gives it back
- **Width**, **Height**, **Bars shown**, **Top bar**, **Space between bars**, **Dividers**, **Experience colour**, **Rested experience**, **Rested colour**, **Reputation fill**, **Reputation colour**, **Bar text shows**, **Bar text place** and **Tooltip** are new rows for the bar. **Bar text** has a **Hidden** choice
- The bar shows experience, with a stretch for how far rested experience reaches, and the faction you watch, coloured by standing (renown and paragon in blue). Both hide at the maximum level or with nothing watched
- **Bar border**, **Bar text**, **Bar text size** and **Bar texture** apply to both bars. **Flat fill** and **Hide bar dividers** are for the game's bar
- The bar has a handle in Movers named **Experience bar** and starts centred over action bar 1. The game's two handles are named **Game's experience bar** and **Game's second status bar**
- With **Group action bars into a block** on and **Stance, pet and experience bars** above, the bar sits in the block's experience rows
- **Leave the game's action bars alone** leaves the game's experience bar alone only while **Experience bar** is **The game's**
- The **Experience bar, bags and micro menu** step of setup has the new rows and a drawing of the bar
- **Rested colour** and **Reputation colour** are now greyed correctly when the choice they depend on is off
- `/flatui status` says when the bar is Flat UI's and how often the game put its alpha or mouse back
- A switch to the game's bar and back inside one fight no longer leaves the bar stuck until a reload. Status wording is clearer, with a singular form

## 0.4.60

- The micro menu and the bag bar keep the Flat UI look (thin dark borders, flat fills, the game's frame art hidden) while **Leave the game's action bars alone** is on, including the frame of an open bag. **Micro menu buttons** and **Bag bar buttons** apply again
- The portrait button of the micro menu loses its shadow, and the help button is styled with the others
- Changing **Leave the game's action bars alone** no longer leaves the dividers of the bag bar invisible until a reload

## 0.4.59

- The game's page arrows beside the main bar no longer stay clickable (invisible) when Flat UI's own action buttons are on
- A pet battle now hides Flat UI's action bars and shows them again afterwards
- If Flat UI's action buttons fail to build, `/flatui status` names the part that failed, and the game's bars are put back
- A failed build takes Flat UI's bars down and clears their key bindings and drivers, so only the game's bars are left
- The build is also checked through the key routing of bar 8
- Keys routed to Flat UI's buttons (flyout slots) are now cleared properly when the slot changes
- Switching back to the game's buttons restores the game's bars through Flat UI's secure header
- Flat UI's hooks on the game's range and cooldown code are no longer installed in a session that uses its own buttons, including when the build waits for the end of combat. After a failed build the game's buttons get their range and cooldown hooks again

## 0.4.58

- **Action buttons**: new first row on the **Action bars** page, **Flat UI's** by default. Mouse clicks on action bars 1 to 8 go to Flat UI's own buttons, laid out where Edit Mode puts the game's bars and wearing the same look. Key presses still go through the game's buttons. A reload applies it
- With **Flat UI's** buttons the game's eight action bars stay in place and are not drawn. **The game's** gives the buttons back as before
- **Hide bar frame**, **Hide end caps** and **Hide dividers** apply with **The game's** buttons. **Rotation helper highlight**, **Cast fill animation** and **Interrupt flash** show on the game's buttons only
- Edit Mode still places bars 1 to 8. The totem and extra action buttons are still the game's
- **Leave the game's action bars alone** covers the micro menu, bag bar, stance, pet and experience bars. Bars 1 to 8 follow **Action buttons**
- `/flatui status` shows the state of **Action buttons**, the main bar page, the keys sent to Flat UI's buttons and the parked bars
- The **Action buttons** step of setup has the new row

## 0.4.57

- **Leave the game's action bars alone**: new row on the **Flat UI** page, on by default. Flat UI does not move, group or fade the game's action bars, and does not move or restyle the status bars, micro menu, bag bar or leave vehicle button. The action buttons keep their Flat UI look. A reload applies it
- **Group action bars into a block**, **Bar blocks**, the action bar, micro menu and bag bar rows of **Fade frames when idle**, **Micro menu buttons** and the experience bar rows of **Bars, bags and micro menu** do nothing while it is on. Each row says so. Saved bar spots stay in the profile
- The game's **Options** page has one **Flat UI** entry with an **Open Flat UI** button. Every setting is in Flat UI's own window
- Range, cooldown and proc glow hooks on the action buttons are made only while **Restyle action bars** is on or **Leave the game's action bars alone** is off
- `/flatui status` shows a **Click path** line when Flat UI changed a game bar or put settings in the game's registry

## 0.4.56

- **Use on New profile** is dimmed while you are in combat, and clicking it in combat no longer leaves an **Unfinished setup** behind
- On **Review**, **Every step** now sits next to **Finish** with no empty gap
- The cards on **New profile** keep their grey edge when **Minimal** or another borderless look is selected
- A profile name you typed, such as "Tank 7" or "Healer", is no longer replaced when you click a profile card
- A font or bar texture in a ready-made profile is no longer dropped because the lists were not complete at login
- Setup window: the profile name filled by a tile follows the next tile even after the setup window is reopened or the game reloads. The **Keep Default** button of the profiles panel no longer takes over the **Skip this area** button of the setup window

## 0.4.55

- **Setup window**: **New profile** shows the six ready-made profiles as cards, with the recommended one selected. Click a card to start from it, or press **Use Healer** (the button names the selected card) to make the profile at once
- **Every step** walks the steps from the card. **Review** lists what the card sets, each line with **Undo**
- **Start from** lists only your saved profiles
- The finished screen and **Review** show a picture of the profile you made

## 0.4.54

- **Profile on a new character**: new row in the **Setup** section of the **Flat UI** page, in place of **Offer setup on a new character**. Choices: **Show profiles** (the panel, as before), **Default profile**, **Recommended profile**, the six ready-made profiles, or any profile you saved. A character with no profile of its own gets the chosen profile at login, with no window and one line in chat. An older setting of off becomes **Default profile**
- **Same profile on new characters**: a switch on the profiles panel. It sets **Profile on a new character** from the next tile or **Same as** click
- **Recommended profile** picks by the character's class, the UI scale, the experience preset and the screen. Role and tank aura are mostly not known yet at login

## 0.4.53

- **Ready-made profiles**: a new character gets a panel with six pictures to click: **Standard**, **Minimal**, **Damage**, **Tank**, **Healer** and **Large**. One click puts the profile in use
- The panel marks the profile that suits the character: a tank or healer role, large game text or scale, the Classic experience, a small screen, or a class that only deals damage. **Same as** and the name of a profile uses the profile most of your characters use
- `/flatui profiles` opens the panel again at any time, and the **Profiles** page has a **Ready-made profiles** button
- No ready-made profile changes the UI scale, a game setting or a frame scale

## 0.4.52

- **Custom UI scale**: the scale now goes through the game's own UI scale setting, so action buttons stay clickable. Turning **Custom UI scale** off puts back the scale the game had before, also after a `/reload` or a profile switch. A change to the scale says "/reload to finish." in the status. **Custom scale** runs from 65% to 115%. New rows **Scale below 65%** and **Small scale** (35 to 64%) call the older route under the game's slider and say that the game can refuse presses at those sizes. A scale under 65% in an imported profile moves to **Small scale**

## 0.4.51

- **Taint scan**: when the game refuses a protected call from Flat UI (for example `UseAction()` on a click), or on `/flatui taint`, the scan now covers every global the refused click reads, `Settings.GetValue`, `C_ActionBar.IsAutoCastPetAction` and every key of the button under the cursor. An empty result says "No tainted value found." Each scan carries its date and time and runs on the next frame. `/flatui status` lists the last results under **Blocked by the game:**
- Nothing else changes on screen

## 0.4.50

- **Combat text**: Size over enemies, friendly units and your own text now goes up to 400%. New **Spread width** setting (50 to 300%, with **Spread** on **Loose**) widens where numbers start. New **Overlapping numbers** setting: **Keep apart** starts a number in a free lane, or higher up, so numbers stop covering each other; **Stay in turn** keeps the old placement. New **Rows** setting (1 to 6) limits how many rows a number may start up. Above 160% the numbers rise, fall and spread in proportion to their size. Critical hits swell at most to 128 units. With the game's own numbers, **Size** and **Spread width** go to the game's variables
- **Combat text**: new **Style** row: **Flat UI** or **Classic**. Classic is the game's old floating text. Numbers climb straight up at a steady speed and last 1.9 seconds. They stack in a column and go to the side past **Rows**. A critical hit pops, then stays in place. A new Classic section has 7 rows: **Colours** (**White and yellow**, or **Red and purple**), **Plus and minus signs over enemies**, **Smaller glancing hits and words**, **Rise distance**, **Time on screen**, **Stacking** (**Older numbers move up**, or **New numbers start lower**) and **Critical hits stay in place**. **How a number appears** and **Movement** apply to **Flat UI** only. The setup picture of combat text shows the Classic look. Numbers over friendly units take the style too
- **Combat text**: new **Whose hits** row, **Yours and your pet's** (the default) or **Everyone's**. Other players' damage no longer shows as combat text unless you choose **Everyone's**. Hits before your first cast or swing are left out. If 10 hits are reported in combat and none of your casts or swings has been heard, the game's own numbers come back. Where the game offers no cast event, the game's own numbers show

## 0.4.49

- Action bars moved with Flat UI are placed through the game's secure frame calls
- **Reload** uses the game's own /reload on Forever
- The proc glow hangs beside the button instead of on it
- Nothing changes on screen

## 0.4.48

- **Flat UI layout**: when Edit Mode does not keep the Flat UI layout, that is remembered for the character and the Reload line does not come back. It is tried again only after you switch to the Flat UI layout in Edit Mode or change **Bars on a preset layout**. The line says "the Edit Mode layout named Flat UI" when that layout already exists. Changing the setting offers the layout again without a reload
- **Movers** page: new row **Edit Mode layout as text**. Choose **Show as import text** to open a window with the Flat UI layout as Edit Mode import text. Copy it, open Edit Mode, choose Import in the layout list, paste it and name it Flat UI. It says so in one line when the game cannot make the text, in a fight, or while Edit Mode is open
- **Bar block button size**: turning it off now always puts the earlier values back at the next Reload, in any later session. The check that Edit Mode applied the button size runs only after the game has loaded the layout, and only when the layout in use holds the values; presets and layouts without them no longer give a false line. A failed check also takes the values out of the layout. Status line wording: "did not keep them."
- **Bar background panels** now follow their bar: they hide with the pet and stance bars when the game hides them, and they fade with a bar that **Fade** has faded. Faint empty buttons no longer have a darker backdrop than filled ones. The totem element ring and the extra action button art are flat with the rest. `/flatui status` says when a panel could not be made or when the game does not say which buttons are empty
- **Button text**: with **Restyle action bars** off, or a bar group off, that bar's hotkeys, macro names and counts go back to the game's text, size, colour and position. A profile change or reset applies the **Button text** values and the hotkey position at once. A pet bar no longer causes repeated passes over every action button, and its hotkeys keep your colour while range changes. The range note in `/flatui status` shows only while **Own hotkey colour** is on. The hotkey offsets show their unit, px
- **Grey out icon on cooldown** now takes the grey off when the game withholds the cooldown in a fight. Colours and cooldowns do no work when **Restyle action bars** is off
- **Rotation helper highlight** off now also hides the highlight on the next suggested spell. **Coloured border** no longer draws on the game's rotation glow. The error line is clearer and clears itself
- **Bar block**: **Group action bars into a block** turned off or on again refreshes the block as before, and then the button size and spacing
- **Setup**: 55 steps

## 0.4.47

- **Sound when it drops** on buff and debuff trackers now uses the game's own sound for the aura ending, so the sound plays in a fight where the buff is hidden. Where the game refuses it, the tracker keeps its own sound for drops it can read, and `/flatui tracker check` says so. `/flatui tracker check` lists **Game's sound for a buff ending**
- Trackers set to **Only when low or missing**: in a fight they no longer reappear while mounted, resting in a city or inn, or dead. Trackers with **Low at (seconds left)** stay shown as before
- Proc art on the game's own icon: a proc ending in a fight no longer leaves its pieces behind. The art line says off when **Art beside the character** is off, and not made when the art was never built

## 0.4.46

- **3D head**: the head now draws below the leader, PvP and raid target icons, level text and ready check
- A unit out of view or an offline party member shows the picture
- The head no longer reloads on every portrait update
- Tint changes reach the head at once, and a later fade of the frame fades it
- The **3D head framing** row is no longer greyed when only a frame's own **Picture** row is set to **3D head**
- **Enemy cooldowns**: in an arena, the target and focus bars show one more icon, the crowd control break of that opponent, with its sweep
- New setting **Crowd control break in arenas** (on by default) on the **Enemy cooldowns** page, also in the setup wizard
- **/flatui check** says whether you are in an arena and whether the crowd control break is shown

## 0.4.45

- **Tooltips page**: new **Fade out** choice (As the game has it, Fast, At once). Fast is the default and takes about 0.2 seconds from full to hidden. It works with the **Tooltip** page off and at any tooltip position. It is also in the setup wizard's **Tooltips** step

## 0.4.44

- **Fixed**: the **Experience bar** and the second status bar no longer fall back to their stacked spot at fights and status bar changes. After the game's bottom bar pass they are put back on the next frame (out of combat), and these returns no longer count toward giving the bar up
- Preset layouts: **/flatui status** says the game puts the Experience bar back in fights, and to copy the layout in Edit Mode to keep it
- Stance, pet, possess and Leave vehicle bars get the same return

## 0.4.43

- **Setup**: all 52 steps are in, each with its drawing. The steps are grouped by area: Look, Nameplates, Action bars, Unit frames, Cast bars and timers, Minimap and buffs, Windows, Chat and tooltips, Trackers, Cooldowns, Party and enemy cooldowns, Combat text, Bar blocks, Fading and Positions
- Every setting of the options window is in exactly one step, and each drawing changes as you pick. Unit health and power in the drawings use sample numbers, since the game withholds a unit's own
- **Choices in each step** (**Main choices** or **Every choice**) on the **Flat UI** page decides how many rows each step lists
- Nothing reaches a profile, a game setting or a list before **Finish**, as in the earlier builds

## 0.4.42

- **Fonts**: the tracker text size is followed after a specialization change
- **Experience and reputation bars**: text you set stays after a subzone change
- **Weapon enchants**: the border follows the right button after an enchant is applied or removed
- **Proc glow**: the glow on an action button follows the game's own spell alert with taintLog on, and answers it on the next frame
- **Swing timer**: **Out of range opacity** and **Own text colour** follow combat start and end and attack speed changes, so they no longer fall back to the game's look until the next swing
- **Alternate power bar and class frame container**: followed only after the display's setup has run
- **Chat**: **Input box opacity when idle** works with **Chat input box** off. A tooltip held back in combat is hidden as the game shows it. Clicking away from a half-typed message leaves the box as it was. The border colour follows the chat type for a box that was already focused
- **Side tabs**: follow the checked state when you switch tabs on the character, bank, collections, inspect and professions windows
- **Bags**: slots are redressed (item levels, dimming) after items are moved, looted or sold with a bag open
- **Pet frame**: size is restored after a specialization change
- **Target and focus frames**: styling is restored after a specialization change. In Edit Mode, **Use larger frame** and **Buffs on top** for the focus frame are restyled when the editor closes
- **Player frame**: the PvP timer word is redrawn only when the timer text changes

## 0.4.41

- **Nameplates**: **Extra clickable width** and **Extra clickable height** no longer change the size of the plates or their bars, they only change where a click lands
- **Click through friendly nameplates** also covers friendly plates that show only a name
- **Taint log**: while the game's taintLog setting is on, the nameplate click area, tooltip placing and experience bar fill still work
- **Experience bar**: the flat fill is put back after a long gain animation as well

## 0.4.40

- **Setup**: a new way to make a profile, first part. `/flatui setup`, or **Set up a new profile** on **Profiles** (**Continue setup** while this character has choices kept), opens a setup mode of the Flat UI window. Each step has a drawing that changes as you pick
- Two steps are in this build: **Borders and backgrounds** and **Bar texture and colours**. The drawings use sample numbers, since the game withholds a unit's health and power. The other steps are not in yet
- Nothing reaches a profile, a game setting or a list before **Finish**. **Close** asks **Keep choices** or **Discard choices**. **Review** lists the changes, each with **Undo**
- **Finish** makes the profile and starts it. Finish is refused in combat and says **In combat. Finish after combat.**
- After **Finish**, the screen lists the switches whose turning off needs a reload, one line each ("Turning off ... takes full effect after /reload."), and the **Reload** button shows a tip, **Reloads the interface.**
- A character with no profile of its own is offered setup once, a second after login. A new section, **Setup**, on the **Flat UI** page has **Offer setup on a new character** (on) and **Choices in each step** (**Main choices** or **Every choice**)
- Setup hooks no game frame

## 0.4.39

- **Combat text**: numbers over friendly units. A new **Friendly units** section on the page has **Where friendly numbers show** (**Off**, **Party and raid frames**, **Friendly nameplates** or **Both**, **Both** by default), **Friendly units**, **Damage friendly units take**, **Healing over friendly units**, **Your pet**, **Misses and dodges over friendly units**, **Plus and minus signs**, **Friendly damage colour**, **Friendly healing colour**, **Size over friendly units** and **Height above frames**
- Numbers over party, raid and pet frames draw above the frame without changing the layering of the numbers over enemies
- **Healing over friendly units** shows the healing a unit takes from anyone. The game's own healing row is set to 0 only while Flat UI draws friendly numbers, and `/flatui combat` explains it only then
- `/flatui combat` counts the friendly nameplates the game keeps from interface mods once per unit and skips enemies, as **Forbidden plates**
- The page's sections **Position and size** and **Spread and movement** no longer say "over enemies". **Height above the enemy** also sets the height over friendly nameplates

## 0.4.38

- **Movers**: a moved action bar is kept in your own Edit Mode layout. After you move a bar a line with a **Reload** button appears. Pressing it saves the layout and reloads the interface in the same click. Until then Flat UI places the bar out of combat and the game puts it back at the start of a fight
- On a preset layout nothing is saved. Copy the layout in Edit Mode to keep moved bars
- **Reset** on a bar, **Reset all** and turning off **Move the game's own frames** put the layout rows back the same way, after a reload
- Flat UI hooks no bar or button, places nothing in combat and saves nothing outside the **Reload** click
- Removing Flat UI without **Reset all** and a reload leaves the saved spots in your layout
- **Action bars**: the button art is restyled after a talent change as well
- **Taint log**: while the game's taintLog setting is on, Flat UI no longer follows game frames, so the errors that showed up with it on (experience bar, tooltips, nameplate click area) no longer appear
- A small box, **Taint log**, appears once per session when taintLog is on. **Turn off and reload** sets it back to 0 and reloads. **Ignore** hides it until the next reload. It hides when a fight starts and returns when it ends
- `/flatui status` shows when taintLog is on and how many game frames are left unfollowed, and whether a call the game refused was "forbidden" or "blocked", for example UseAction (forbidden)
- Turning taintLog on during play prints one line telling you to turn it off and reload
- With taintLog off, nothing changes

## 0.4.37

- **Trackers**, **Proc alerts**: procs now work where the game hides the buff in a fight. Three triggers: your cast of the proc's spell (Fel Domination, Amplify Curse), a cast time that has become instant or much shorter (Shadow Trance, Decimation), and an ability that has become usable (Mongoose Bite, Counterattack, Overpower, Revenge, Riposte)
- **Add a proc** shows the trigger after the proc's name. `/flatui tracker proc trigger` changes it and `/flatui tracker check` names it. A proc whose spell is instant at rest is refused
- **Unit frames**, **All frames: text**: **Name font**, **Name size**, **Name outline**, **Name colour** (**As the game has it**, **Class**, **Reaction**, **Custom**) with a custom colour, **Bar text font**, **Bar text outline** and an own **Bar text colour**. A **Name** switch on the **Player**, **Target**, **Focus**, **Pet**, **Target of target**, **Party** and **Boss** frame pages. Every row at its default leaves the game as it is
- **Unit frames**: **Health text** and **Power text** on each frame's page show the health or power of that bar as **Current**, **Current / max**, **Percent**, **Current and percent** or **Missing**, or hide the game's text. **All frames: text** has **Number style** (12.3k or 12,345), **Show** (always or under the mouse) and the position of each text. A row left on **As the game has it** changes nothing
- **Unit frames**: switches for the leader icon, the role icon on party frames, the PvP icon, the raid marker on target, focus and boss frames, the dead text, the combat icon and the pet's happiness face
- **Power bar** switch on the player, target, focus, pet, target of target, party and boss frame pages
- **Party frames**: **Dim members out of range**, with **Out of range dimming**
- New **Raid frames** page: **Out of range opacity**, **Role icon**, **Name** and **Status text**
- **Incoming heals**, **Absorb shields** and **Heal absorbs** on **All frames: bars and pictures**
- **Totem time left** and **Totem cooldown swipe** on **All frames: icons and auras**
- **Fonts**: **Replace the game's fonts**, **Interface font**, **Number font**, **Title font**, **Text outline**, **Text shadow**, **Text size** and **Smallest text**. Off until switched on. Other addons that use the game's fonts change too, and off puts every font back. **Game text size** is on the same page
- **Tooltips**: their own border colour, a border by unit (plain, reaction or class colour), class colour on player names, size, title size and text size, a hidden or thinner health bar, hiding in combat with a key to show anyway, item and spell IDs, and item counts in bags and bank
- **Chat**: a border, an input box above or below the window, a lower idle opacity and a choice of border while typing. A **Chat text** page sets the chat font, outline and shadow, lines kept per window, and whether and when old messages fade
- **Minimap**: **Minimap shape** (round or square, with no ring or pointer under **Square**), **Zoom out after**, **Day and night icon**, **Zone name** and **Zone name size**, and switches for the **Tracking**, **Mail**, **Calendar**, **Clock** and **Addon list** buttons
- **Buffs and debuffs**: **Icon crop**, a colour for each debuff type, **Border colour by debuff type**, **Duration size** and **Stack count size**
- **Bars**: **Bar text**, **Bar text size** and **Bar texture** for experience and reputation bars
- **Tracker and loot**: **Tracker bar texture**, **Tracker background**, **Heading size**, **Opacity in combat** and **Quality word on loot**
- **Cooldowns**: **Icon crop** (0 to 15 percent), **Icon border**, and **Equipped trinkets**, which adds your two trinket slots after the picked spells with their own sweep. Where the game withholds trinket cooldowns, the trinket icon shows no sweep and `/flatui status` says so
- **Cooldowns**, **States and text** (new page):
  - **On cooldown**: **Grey out on cooldown**, **Darkness on cooldown**
  - **Opacity**: **Opacity on cooldown**, **Opacity when ready** (0 hides ready icons and keeps their place), **Row opacity out of combat**
  - **Border**: **Border colour by state** with a ready and an on cooldown colour, **Flash when ready**
  - **Numbers and sweep**: **Countdown number size**, **Cooldown sweep**, **Sweep opacity**, **Charge count size**
  - **Keybind**: **Keybind on icons** shows the key bound to the spell on your action bars, with **Keybind size**
- **Colours**: **Colour at full health**, **Colour at half health** and **Colour at low health**, under **Health left**
- **Unit frames**, **Nameplates** and **Personal resource display**: **Colour health bars by health left**, in the three colours of the **Colours** page. Not raid frames
- **Nameplates**: **Low health border**, with **Low health below** and **Low health border colour**
- **Nameplates** and **Cast bars**: **Cast time** on nameplates, and **Cast time on target and focus bars**, in seconds at the right end of the bar
- Each of these switches itself off if the client refuses it. `/flatui status` says whether the health curve and the cast time work

## 0.4.36

- **Trackers**: new page **Tracker** under **Trackers**. Choose a tracker, change its name and its rows (**On**, **Spell IDs**, **Shape**, **Place**, **Show**, **Low at**, **When missing**, **Sound when it drops**, **Colour**, **Icon size**, **X offset**, **Y offset**, **Mark action buttons**). A row shows the page's value until the tracker has its own, and the first change gives it one
- **Clear own settings**, **Move up**, **Move down** and **Remove** act on the chosen tracker. **Remove** asks first
- Opened in a fight, the page says to open it after the fight
- **Trackers**: new row **Add a debuff on the target**, and `/flatui tracker add debuff Corruption`. A debuff tracker shows your own debuff on your current target with its stacks and time left, goes red when it is not on the target, and is hidden when there is no target you can attack. In fights the game's own icon, bar or text draws it where the game hides it
- **Trackers**, **Action buttons**: new switch **Mark action buttons** (off by default). When it is on, the action button that casts the missing buff or uses the missing item gets a red border until the tracker is fine again. It needs **Restyle action bars** and only marks a button the game has the spell or item on. Buffs are marked out of a fight. `/flatui tracker check` shows a Marks line for each tracker, and `/flatui status` counts the marked buttons
- **Trackers**, **Proc alerts**: **Add a proc** lists the procs of your class that you know a spell for, and **Remove a proc** takes one off. A proc shows nothing until its buff is up, then its icon with a coloured border, the time left and one sound. It ends when the buff ends, when you cast the spell it is for, or when its time is up
- Procs sit after the other trackers in the row, so an empty place never moves the others
- In a fight where the game hides the buff, the game's own icon for the buff shows the proc. Where the game gives no icon, nothing shows
- **Colour** (ffd100) is the border of a proc. **Sound** (**Spell alert**) is **None**, **Spell alert**, **Chimes**, **Bell**, **Warhorn**, **Raid warning**, **Alarm** or **Whisper warning**
- `/flatui tracker add proc Shadow Trance for Shadow Bolt` adds any other proc: its buff, then the spell it is for. `/flatui tracker proc colour 1 ffd100`, `/flatui tracker proc time 1 10` (0 to 120 seconds, 0 for the buff's own time) and `/flatui tracker proc trigger 1 overlay` set one proc
- The game's overlay events and glow are a second way to know a proc is up where the buff is hidden. A proc on the **overlay** trigger uses them and needs a time. The game is not expected to send any on this client
- `/flatui tracker test` shows each proc's icon and plays its sound for 5 seconds. `/flatui tracker check` says for each proc how hidden the game keeps its buff, whether it is up, the overlay signals seen, the personal resource display and the sound
- **Trackers**, **Proc alerts**: art beside the character while a proc is up. The large side pieces (and top, outside and corner pieces where the game's table gives them) fade in, pulse slowly and fade out, in the proc's colour. New rows **Art beside the character** (on), **Art size** (100%), **Art opacity** (65%) and **Art height** (0). A proc with no art of its own gets a plain arc
- **Trackers**, **Proc alerts**: new row **Glow on the action button** (on by default). While a proc is up, the action button that casts the spell the proc is for gets the proc's border colour and the game's glow animation. A button the game already glows is left alone. Where the game hides the buff in a fight, the glow follows only the other triggers. It needs **Restyle action bars** for the border. `/flatui tracker check` prints a Glow line for a proc
- **Profiles**, **Share**: new rows **Export trackers** and **Import trackers**. `/flatui tracker export` prints text for all trackers, or one by number (`/flatui tracker export 2`). `/flatui tracker import <text>` adds the trackers in the text after the ones you have and never replaces them. The text starts with `FlatUIT1:`. A profile text is refused by tracker import and a tracker text by profile import. Import stops at 40 trackers and says so, and is refused in combat
- **Enemy cooldowns**: **Show** is **Only while on cooldown** or **Always, ready ones bright**. In **Always, ready ones bright** the abilities of the enemy's class and race whose use can be seen are bright, and used ones are dark with the sweep
- **When it is ready again**: **Nothing**, **Flash** or **Flash and sound**. The sound plays for your target and focus only, at most once a second
- **Ready sound**: **Spell alert**, **Chimes**, **Bell**, **Warhorn** or **Raid warning**
- **Add an ability** and **Hide an ability** on the **Enemy cooldowns** page change which abilities the icons show. An added ability shows whatever its kind, and a hidden one stays hidden with its switch on
- `/flatui enemy add` (an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds), `/flatui enemy hide`, `/flatui enemy list` and `/flatui enemy clear`
- **Nameplates**, **Colours and threat** (new page): **Reaction colours on health bars** (hostile, neutral, friendly and tapped, in the colours of the **Colours** page) with **Players**: **As the game has it** keeps class colours, or **By reaction**
- **Colour the target's health bar**, with **Target health bar colour**
- **Threat colours**: **Your role** (**From your group role**, **Tank**, **Damage or healer**), **Threat you want**, **Threat changing hands**, **Threat you do not want**
- **Mouseover border** with **Mouseover colour**. The target and focus borders come first
- **Nameplates**, **Target and marks**: **Border colour for Elite and Rare** with **Elite colour**, **Rare colour** and **Boss colour** for the border of Elite, Rare and Boss units
- **Nameplates**, **Text**: **Show name**, **Name colour** (**As the game has it**, **White**, **By reaction**, **Custom**) and **Custom name colour**. **Health text colour**, **Show health text** (**Always** or **Only on the target**) and **Health text format** (**As the game has it**, **Percent**, **Health**, **Health and percent**, **Health missing**)
- **Nameplates**, **Cast bar**: **Spell name size**, **Spell name outline**, **Spell name colour**, **Spell icon size**, **Spark** and **Shield on uninterruptible casts**
- **Nameplates**: **Click through friendly nameplates**, **Click through enemy nameplates**, **Extra clickable width** and **Extra clickable height**. Where the game withholds a health value or refuses a change to a plate, that part stops and says so in `/flatui status`

## 0.4.35

- **Trackers**: new row **Add class trackers** on the **Trackers** page, named for your class (for example **Add Shaman trackers**), with **All** and one line for each starting tracker of the class. `/flatui tracker class` adds them all
- A buff, stance, form or totem is added only when you know its spell, an item only when it is in your bags. Weapon, pet and ammunition trackers are added for every character of the class. A tracker already on the list is not added again
- A Shaman gets one **Shield** tracker for Lightning Shield or Water Shield, **Weapon imbue**, the four totems (off until switched on, shown only in combat) and **Ankh**
- **Add a buff** and `/flatui tracker add` take every rank of a spell from the class data
- **Enemy cooldowns**: two bars of up to eight icons above the target and focus frames, showing that player's tracked cooldowns. Each bar has a handle in `/flatui move`, **Enemy cooldowns: target** and **Enemy cooldowns: focus**
- New choice **Place** on the **Enemy cooldowns** page: **Both**, **On enemy nameplates** or **Bars for target and focus**. `/flatui test` draws the bars too
- **Game settings**: sixteen of the game's own settings now sit beside the Flat UI settings they go with. The game saves them. Each row shows the game's current value. A row the game refuses to change prints one line and keeps showing the game's value
- **Nameplates**, **Game settings**: **Cast bars on nameplates**, **Nameplate distance**, **Nameplate style**, **Nameplate size**, **Horizontal overlap**, **Vertical overlap**, **Nameplates at the unit's feet**, **Target nameplate scale**, **Far nameplate scale**, **Far nameplate opacity**, **Opacity behind obstacles** and **Opacity of other nameplates with a target**
- **Chat and tooltips**, **Chat text**: **Timestamps** and **Class colours in chat**. **Fonts**: **Game text size**. **Bags and items**: **Combine bags**
- **Reset page** and the game's **Defaults** button do not write these rows. `/flatui cvar` lists each CVar with its value, the game's default and whether the game flags it secure. `/flatui cvar check`, out of combat, tells which of them Flat UI may change. `/flatui status` says how many of the 16 rows can be changed
- **Nameplates**, **Health bar**: **Health bar texture**, **Bar width** (narrows the health and cast bar together), **Dim strength**, and switches for **Incoming heals**, **Absorb shields** and **Heal absorbs**
- **Nameplates**, **Target and marks**: **Raid marker** with size and offsets, and a switch for the arrow for nameplates behind you
- **Restyle friendly nameplates**: off leaves friendly plates as the game draws them
- **Nameplates**, **Auras**: **Aura icon crop**, **Own aura border colour** with **Aura border colour**, **Countdown numbers**, **Stack count**, **Aura opacity**, and **Show auras** on every nameplate or only on the target
- **Cast bars**: **Spark**, **Uninterruptible shield icon** and **Latency zone** on the player bar can be switched off or on. **Border** takes the cast colour. **Bar texture** of its own. **Class colour on the player bar**. Own cast and channel colours on target and focus bars
- **Cast bars**, **Text and icon**: **Spell name** shown or hidden, aligned left, centre or right, in an own colour. The target and focus bar icon sits on the right or is hidden. A spell icon on the player and pet bars
- **Personal resource display**: **Bar texture**, **Percentage text**, **Value text** and an own text colour
- **Swing timers**: **Bar texture**, **Fill from the right**, **Out of range opacity**, **While not swinging** (show or hide the bar) and own text colours in and out of range
- **Unit frames**: new pages **Player frame**, **Target frame**, **Focus frame**, **Pet frame**, **Target of target frame**, **Party frames** and **Boss frames**
- **Picture**: **As Square portraits**, **Square picture**, **Game portrait**, **Class icon** or **None** for each frame. The party pet picture is its own row
- **Level** on or off for the player, target, focus and boss frames. **Resting animation**: **Hidden with the resting colour**, **Shown** or **Hidden** on the player frame
- **Health bar colour**: **Health colour**, **Class** or **Reaction** for each frame
- **All frames: bars and pictures**: **Health bar texture**, **Power bar texture** and **Name background brightness**. **All frames: icons and auras**: **Aura icon crop**, **Border colour by debuff type**, **Stack number size** and **Countdown numbers on party and pet debuffs**
- **Frame scale**: **Player frame scale**, **Target frame scale**, **Focus frame scale**, **Party frame scale**, **Boss frame scale** and **Raid frame scale** sliders (50% to 200%) on the **Unit frames** page. They follow Ctrl and scroll on a frame's handle and need **Move frames** and **Move the game's own frames** on
- **Pixel-perfect scale** and **Pixels per unit** on the **Flat UI** page: one interface unit becomes a whole number of screen pixels. A scale outside 35% to 115% is not applied
- **Border and background** for each area: on the **Nameplates**, **Action bars**, **Unit frames**, **Minimap and buffs** and **Chat and tooltips** pages, a new section with **Own border and background**, **Border colour**, **Background colour** and **Background opacity**. With **Own border and background** on, that page's borders and backgrounds use these colours and this opacity in place of the **Flat UI** page's
- Colours the addon sets for a reason (target, threat, debuff type, item quality) and the opacity of windows and chat stay as they are. **Border thickness** stays on the **Flat UI** page
- **Windows**: **Title size** (70% to 200%), **Own title colour** and **Title colour** set the size and colour of window titles
- **Bags and items**: **Quality border from** draws the quality colour on slots from the chosen quality up: **Every item**, **Green and better**, **Blue and better** or **Epic and better**. **Stack count size** (60% to 200%) sets the size of stack counts on item slots
- **Item level in bags and bank** shows the item level of weapons and armour on their slots. **Item level on equipped gear** shows it on the character window. **Item level size** (8 to 18) and **Item level colour** (**Item quality colour**, **White** or **Gold**)
- **New item glow** off hides the glow and flash on new items in the bags. **Dim grey items** darkens poor items that have a vendor price. The dividers of the **Character** window follow the border colour source

## 0.4.34

- **Trackers**: new kind item. **Add an item** on the **Trackers** page lists the items in your bags. An item tracker shows the item's icon with the count in your bags. It shows missing at 0, is low under **Item minimum**, and shows the item's cooldown as a sweep
- New kind Ammunition: the ammunition you carry, low at **Ammunition minimum** or under. A character that uses no ammunition shows fine
- New kind Tracking: fine while any minimap tracking is on, missing when none is
- New kind stance or form: **Add a stance or form** lists the forms you have. Fine in a listed stance or form, missing in none
- **Add a check** now has **Ammunition** and **Tracking**
- New settings: **Item minimum** (1), **Ammunition minimum** (200), **Hide while mounted** (on) and **Hide in cities and inns** (off). The last two apply to trackers set to **Only when low or missing**
- `/flatui tracker add item` (a name, item ID or shift-clicked item), `/flatui tracker add ammo`, `/flatui tracker add tracking` and `/flatui tracker add form`. `/flatui tracker set 1 low` goes up to 1000 for an item and 2000 for ammunition
- Item, ammunition, tracking and form trackers keep working in fights
- **Party cooldowns** now show on raid-style party frames and in a raid group
- Raid-style party frames: each member's row hangs from that member's frame, and your own row hangs from your own frame
- Raid group: your own row and your subgroup's rows stack in one place, each with the member's name. Move them with the handle **Party cooldowns: raid group** in `/flatui move`. **In a raid group** on the **Party cooldowns** page is **Own position** (the default) or **Off**
- **Add an ability** and **Hide an ability** on the **Party cooldowns** page change which abilities the rows show
- `/flatui party add` (an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds), `/flatui party hide` and `/flatui party list`, which also says which members share cooldowns
- The lines "off in a raid group" and "icons show on the standard party frames only" are gone
- **Colours** page: **Border colour source** is **Border colour on the Flat UI page**, **Your class colour** or **Your faction colour**
- **Custom reaction colours**: **Hostile**, **Neutral**, **Friendly** and **Tapped by another player**
- **Custom power colours**: **Mana**, **Rage**, **Energy**, **Focus** and **Runic power**
- The border source applies to every border now. The reaction and power colours take effect where later builds read them
- **Flat UI** page: **Bar texture** has three more choices, **Game status bar**, **Skills bar** and **Targeting bar**
- **Fading**: new page. **Fade frames when idle** fades the action bars (main bar and bars 2 to 8), the stance bar, the pet bar, the micro menu, the bag bar, the player frame, the pet frame and the minimap buttons, one switch each
- **Faded opacity** (25%), **Wait before fading** (500 ms) and **Fade time** (300 ms) set the look. **In combat** (on) and **With a target** (off) keep the frames at full opacity
- Frames are also at full opacity under the mouse, while something is on the cursor, while a spell flyout is open and in Edit Mode. Faded buttons still work. A bar in an active Bar block fades with that block's **Fade the block**

## 0.4.33

- **Trackers** can follow totems and your pet. **Add a check** lists **Fire totem**, **Earth totem**, **Water totem**, **Air totem** and **Pet**. `/flatui tracker add totem fire` and `/flatui tracker add pet` do the same
- A totem tracker shows the totem's icon with the time left. It goes red when the slot is empty and is low under **Low at (seconds left)**. The sound plays when a totem ends
- In a fight where the game hides a totem, the tracker is drawn with the game's own timer calls. If the game refuses one, that part is left out and `/flatui tracker check` says which
- A pet tracker goes red when you have no pet or it is dead. `/flatui tracker set 1 happy on` makes a hunter's pet tracker low while the pet is unhappy
- **Enemy cooldowns**: new page. Up to four icons under the nameplate of each enemy player, with the time left. Kinds: **Interrupts**, **Defensives**, **Crowd control breaks** and **Wards and immunities** are on; **Mobility** and **Offensive cooldowns** are off
- A kick that stops your own cast starts that player's kick timer. A timer that has started keeps counting and follows the player from plate to plate
- Casts and buffs of enemies are used where the game does not hide them. Where it does, `/flatui status` says so in one line
- **Border colour by kind**: interrupts orange, defensives blue, wards and immunities white, crowd control breaks violet, mobility green, offensive cooldowns red. **Seconds on the icon** and **Icon size** (16 to 40) are settings
- `/flatui test` also draws sample icons on enemy plates. `/flatui check` has two new lines: Enemy casts seen and Enemy buffs read

## 0.4.32

- **Party cooldowns**: a party member who also runs Flat UI sends his cooldowns, so his interrupts and defensives show used and ready on his row wherever the game lets addon messages through. Where that is, is not known yet. New setting **Share cooldowns with the party** (on)
- When the game blocks addon messages, `/flatui status` says: Party cooldowns: the game blocks addon messages here, so cooldowns are not shared
- Settings pages: the long pages are split into pages under them. **Colours** is under **Flat UI**. **Health bar**, **Text**, **Cast bar**, **Target and marks** and **Auras** are under **Nameplates**. **Size** and **Text and icon** are under **Cast bars**. **Which windows** and **Bags and items** are under **Windows**. **All frames: bars and pictures**, **All frames: text** and **All frames: icons and auras** are under **Unit frames**. **Minimap**, **Buffs and debuffs**, **Bars, bags and micro menu** and **Tracker, loot and alerts** are under **Minimap and buffs**. **Tooltips** is under **Chat and tooltips**. The **Looks** section of **Unit frames** is on **All frames: text**
- Every setting keeps its name, value and saved place, so profiles and exported text work as before. A page with no settings is not listed

## 0.4.31

- **Trackers**: a **Bar** tracker in a fight shows the game's own bar for the buff, filled by the time left, or by the charges when **Bar fill** is **Charges**. A **Text** tracker shows the game's own count and time left
- **Low at (charges)** and **Low at (seconds left)** turn the digit and the time red as they do on an icon. `/flatui tracker check` lists the bar parts and says whether the game took the timer. If the game refuses the bar, the tracker shows the last known fill in fights
- **Add a check** on the **Trackers** page now has **Main hand enchant**, **Off hand enchant** and **Ranged enchant**. A weapon tracker shows the enchant's icon with the time left and charges, goes red and shows Missing when the weapon has no enchant, and is low under **Low at**. Shaman imbues, rogue poisons, sharpening stones and oils all count
- `/flatui tracker add weapon main` (or `off`, `ranged`) adds one. Weapon trackers keep working in fights, battlegrounds and arenas

## 0.4.30

- **Unit frames** page, new section **Looks**, with eight switches, all off: **Health in class and reaction colour**, **Dark health bar, colour shows what is lost**, **Muted colours**, **White names** (frames with a name row), **Smaller, lighter bar text**, **No text on the power bar**, **Soft shade on bars** and **Shadow behind each frame**. With all eight off the frames look as before. `/flatui status` shows a Looks line only when a look could not apply
- New page **Party cooldowns**: icons beside each party member's frame, ready cooldowns bright, used ones dark with the time left. **Interrupts**, **Defensives** and **Defensives cast on others** are on. **Crowd control breaks** and **Group cooldowns** are off
- A member's use of an ability is seen when the game shows his cast, and a defensive is seen when its buff can be read
- **Your own row** shows your own icons above the first member's, off by default. Settings: **Party icons** (right, left or below each frame), **Show**, **Icons for each member** (3 to 8), **Icon size**, and a switch for each kind
- Party cooldowns are off in a raid group and with raid-style party frames, with one line in `/flatui status`. `/flatui test` also shows sample icons on each party row. `/flatui check` has three new lines: party casts seen, party buffs read, and the caster of a party buff

## 0.4.29

- **Defensives on you**: new switch **Your own defensives** (off by default) shows the defensives you cast on yourself, such as Shield Wall and Ice Barrier, in a group of up to 4 icons
- New lists **Add a spell** and **Remove a spell** on the **Defensives on you** page change which buffs the row shows. `/flatui defensives add` (a spell ID or a shift-clicked spell), `/flatui defensives remove` (a spell ID or a name) and `/flatui defensives list` do the same from chat. Up to 40 spells can be added. The lists are kept for the account
- Where the game makes no icon row, **Your own defensives** is off and `/flatui status` says so in one line

## 0.4.28

- **Unit frames** page, under **Raid frames**: new setting **Raid cell look** (on by default). Raid frames, and party frames in raid style, get a thin power bar with its own thin border, and the health bar turns grey when the unit is dead or offline, a dead player included. The thin power bar shows only when **Display Power Bars** is on in the game's raid frame options, which is off by default. **Raid cell look** off puts the game's power bar and health colour back

## 0.4.27

- **Unit frames** page, section **Name row**: the pet, target of target, party and party pet frames have a row with the name above their bars, in the colour of the class or reaction of the unit. The picture grows to start at the top of the row
- Boss frames have the same row with the level at its end and no picture. **Level position** now covers the boss frames
- **Name row on small frames** (on by default) turns the row off on the pet, target of target, party and party pet frames. **Name row** still turns off every row
- `/flatui status` says the name, picture, row size and row colour for the target of target, boss 1 and the first party frame. Where the game withholds a unit's class, the row colour is dark and the status says so

## 0.4.26

- **Trackers** can be drawn as a **Bar** or as **Text**. On **Tracker look**, **Shape** chooses **Icon** (the default), **Bar** or **Text**, with **Bar width** (140), **Bar height** (14), **Bar fill** (**Charges** or **Time left**), **Colour**, **Charges** and **Name**
- A bar shows the name, the charges and the time left over a flat fill; **Text** shows them on a dark plate. Low and missing turn the bar fill or the text red, and the missing word and pulse work on bars and text
- A tracker can have its own shape and colour: `/flatui tracker set 1 shape bar`, `/flatui tracker set 1 colour 4d99e6`. `/flatui tracker test` draws each look in the tracker's own shape, and `/flatui tracker check` names the shape
- In a fight, a bar or text tracker for a buff the game hides keeps its last fill and name, with ? for the charges, or is hidden, as **In fights without the game's icon** says. An icon tracker keeps the game's icon
- **Bar width** and **Bar height** are the same for every tracker, and a tracker's own size changes only the icon. A change of **Bar texture** reaches existing bars after `/reload`

## 0.4.25

- **Cooldowns** page, section **Icons**: **Sound when ready** (off by default) plays a sound once when a spell on the Cooldown icons row is ready again. The global cooldown plays nothing. The sound is the **Sound** chosen on the **Low and missing** page of **Trackers**
- In a fight, where the game withholds a spell's cooldown, that spell's sound is skipped. `/flatui status` names the blocked call, and says "Cooldown icons: the game played no sound, so Sound when ready is silent." when the game plays none

## 0.4.24

- **Unit frames** page, new section **Level** after **Name row**. **Level position** is **End of the name row** (the default), **Before the name**, **On the portrait** or **Hidden**. **On the portrait** puts the level at the bottom right of the picture, with the Elite or Rare mark, and needs a picture
- **Level colour** is **By difficulty** (the default), **White** or **Same as the name**. **Level size** is **Same as the name** (the default), **Smaller** or **Larger**
- The game's round level plate, number and skull stay hidden in every position
- **Level position** replaces **Level in the name row**. A saved value of the old switch is dropped, so a player who had it off now sees the level at the end of the name row
- `/flatui status` adds a level line for each frame with a name row
- **Bar blocks**: a new page after **Bar block**. **Class spells**, **Buffs to apply** and **Consumables** each pick one of the game's bars, **Action bar 2** to **Action bar 8** (**None** by default). The bar's box in `/flatui move` has the block's name
- Each block has a position: **Where its handle is** (the default), **Above, left**, **Above, right**, **Below, left**, **Below, right**, **Left, bottom**, **Left, top**, **Right, bottom** or **Right, top**, with **Gap** from 0 to 40 px (4 by default). Blocks hang from the **Action bar block**, or from the bar in **Blocks hang from** (**Main action bar** by default) when the **Bar block** page is off. Blocks at one position stack outward
- **Pet bar position**: **Where the game puts it** (the default), **Above, right** or **Above, left**. When **Stance, pet and experience bars** is **Above the block**, the **Bar block** page places the pet bar and this setting does nothing
- With the **Bar block** page off and blocks hung from the main bar, **Above** positions and the pet bar can overlap the game's experience bars, **Action bar 3**, **Action bar 2** and the stance bar
- Casting, keys, cooldowns and counts are the game's own and work in combat. Icons, rows and visibility of each bar are set in Edit Mode
- New command `/flatui blocks` lists each block, its bar and its position. `/flatui status` says when a picked bar is off in the game's options, and names a pet bar or **Action bar 2** to **Action bar 5** the game still stacks in a fight
- With **Background panel** and **Fade the block** on, the panel and the fade do not cover the bars of **Bar blocks**

## 0.4.23

- New page **Defensives on you**: a row of icons for the shields, wards and protections other players cast on you, each with its time left, its charges and the caster's name. The game draws them, so they should show in fights, dungeons, raids and battlegrounds. That is not seen yet: `/flatui check` says "Defensives on you: the game's own icon row." when the game made the row
- Where the game will not make its icon row, the same icons show out of combat only, and `/flatui status` says so
- The page has **Defensives on you**, **Place** and **Caster's name**. **Place**: **Above the player frame**, **At the personal resource display**, **Own position** (drag the handle **Defensives on you** in `/flatui move`) or **Off**
- New command `/flatui test` shows three sample icons for 8 seconds and says whether the sweep ended on each and whether the sound played
- New command `/flatui check` prints whether the names and classes of the target and party1 can be read, whether addon messages pass, and whether the game shows who interrupted your last cast. `/flatui check last` prints the last check

## 0.4.22

- **Bar block** page, section **Background**: **Background panel** (off by default) draws a flat panel behind the block in the general background colour, with **Background padding** from 0 to 24 px (4 by default)
- Section **Fade**: **Fade the block** (off by default) fades the bars to **Faded opacity** (0 to 100 percent, 30 by default). **Full opacity in combat** and **Full opacity under the mouse** are on by default. The bars are also at full opacity while something is held on the cursor or a spell flyout is open. Faded bars still take clicks

## 0.4.21

- **Trackers** has two pages under it. **Tracker look** has **Icon size**, **Time left**, **Row direction**, **Spacing**, **Place**, **Side of the personal resource display**, **X offset** and **Y offset**. **Low and missing** has **Low at (charges)**, **Low at (seconds left)**, **When missing**, **Sound when it drops** and **Sound**. **Trackers** keeps the list, **Show** and **Game's own icon in fights**
- New settings: **Row direction** (**From the middle**, **Left to right**, **Right to left**), **Spacing**, **Side of the personal resource display** (**Above**, **Below**), **Sound** (**Raid warning**, **Alarm**, **Whisper warning**) and **In fights without the game's icon** (**Last known**, **Hidden**)
- With **Below**, the row goes under the Cooldown icons row when that row is under the personal resource display
- Trackers with different places make one row each
- New command `/flatui tracker set 1 low 2` gives one tracker its own value for place, show, low, lowtime, missing, sound, kit, size, x, y, name or on. `clear` as the value takes it back, and `/flatui tracker set 1 clear` takes back all of them. An own `x` or `y` replaces the page's **X offset** or **Y offset** for that tracker; it is not added to it
- `/flatui tracker check` shows each tracker's place and own settings. `/flatui tracker list` shows the place and the number of own settings of a tracker that has them

## 0.4.20

- **Unit frames** page, section **Portraits**: **Portrait style** is **Picture** (the default), **Class icon** or **None**. **Class icon** shows the class of a player. Other units keep their face. **None** leaves the space empty
- **Portrait size** is **As tall as the frame** (the default) or **As tall as the bars**
- **Portrait border** is **Thin** (the default), **Class or reaction colour** or **None**. **None** draws no edges. Resting, combat and Elite colours still show
- **Portrait fades with the name row** is on by default and changes how the player, target and focus pictures look: the top of the picture fades into the background beside a name row that fades upward. It is an overlay in the background colour, not true transparency, so it matches only where the world behind is dark
- Switches **Player portrait**, **Target portrait**, **Focus portrait**, **Pet portrait**, **Target of target portrait**, **Party portraits** and **Party pet portraits**, all on by default
- `/flatui status` names the picture of the player, target and pet frames and says whether the client withholds the unit's identity

## 0.4.19

- **Bar block**: new setting **Stance, pet and experience bars** (**Above the block**, **Left to the game**). With **Above the block**, the experience bars are on top of the block, the stance bar on the left and the pet bar on the right above them, and the possess bar above those, instead of over the block's second row. The Leave vehicle button stays where the game puts it
- `/flatui status` names the bars the game still stacks in a fight and how to keep them (arrow key once in Edit Mode, save)
- New command `/flatui block facts` prints what the game says about the bars and Edit Mode layouts

## 0.4.18

- **Bar block**: a new page after **Movers**. **Group action bars into a block** (off at first) lines up **Main action bar**, **Action bar 2** and **Action bar 3** where the main bar is now, with the same gap as between the buttons
- `/flatui move` shows one box, **Action bar block**, that moves every bar in the block. Right-click on it puts the block back: the main bar at the left of the micro menu, or the bottom middle of the screen when another bar is first
- **First bar** to **Sixth bar** pick the bar in each row, **Stack direction** and **Line up bars** set the order and the alignment, **Own gap between bars** and **Gap between bars** set the space
- The block is placed out of combat. In a fight Action bars 6 to 8 and any bar you have placed in Edit Mode stay in the block; the other bars go back into the game's stack until the fight ends
- `/flatui status` says when the **Movers** page, **Move the game's own frames** or **Keep moved frames in place** is off and the bars are not placed, and names a bar the game places itself

## 0.4.17

- `/flatui tracker check`: the first two lines say whether the game has hidden values and which kinds are hidden now: auras, cooldowns, your casts and a group member's casts
- After a fight the same words are given for the last fight, with the first tracker's buff and its level
- The weapon enchant line lists the main hand, off hand and ranged slots, each with its enchant's type (Permanent, Temporary or Imbue)
- In a fight the game's own icon shows its time text without the red colour when the game refuses the colour

## 0.4.16

- Pet frame size: **Unit frames** page, section **Pet frame size**. **Custom pet frame size** sets the pet frame to a percent of the player frame or of the normal size, and keeps that size when the game lays its frames out again and after Edit Mode closes. While it is on, Edit Mode's pet Frame Size is not used
- **Pet frame size is measured against** is **Player frame size** (the default) or **Normal size**. **Percent** goes from 50% to 200%, 100% by default. The setting is off by default
- Ctrl and the wheel on the pet frame handle in `/flatui move` no longer scale it
- Out of combat only: a change made in combat shows when combat ends
- `/flatui status` shows the size and how many times it was put back

## 0.4.15

- **Windows** page, new section **Clean up bags**: **Clean up bags button** (**In the title bar**, **Under the slots**, **None**), **Also on the bank** and **Items gather** (**As the game sorts**, **From the other end**)
- A small button with three bars at the right end of the title bar of the combined bag, each separate bag and the bank sorts your items with the game's own clean up and plays its sound. **Under the slots** puts it below the lowest bag of a stack instead, and inside the bottom left corner of the bank
- On the bank the button asks first while the game's bank question is on, then sorts the bank that is shown. Its tooltip says **Clean Up Bags**, **Clean Up Bank** or **Clean Up Account Bank**
- `/flatui sort` cleans up the bags and `/flatui sort bank` cleans up the bank that is open. When nothing happens a line says why: an item on the cursor, no bank open, no bags bought on that bank
- **From the other end** makes the game's clean up, its own button included, fill your bags from the other end. The game's own direction comes back when you choose **As the game sorts**, turn the page off or log out
- With the gamepad interface style there is no button, and it goes or comes back as soon as the style changes
- The game's own clean up buttons on the backpack, the combined bag and the bank stay

## 0.4.14

- **Trackers**: a new page after **Cooldowns**. A tracker shows a buff on your character as an icon with its charges and time left, a red rim at **Low at (charges)** or **Low at (seconds left)**, and a red icon when the buff is missing. **Sound when it drops** plays a sound when the buff ends
- Add a buff from **Add a buff**, or by name or spell ID with `/flatui tracker add`. **Remove a tracker** takes one off
- The row sits above the personal resource display, beside the character, or at a spot you drag (the **Trackers** handle in `/flatui move`). **Place** sets which
- When the game hides buff charges and time left in a fight, the tracker shows the game's own icon in the same place (**Game's own icon in fights**)
- `/flatui tracker check` says what each tracker shows and why. `/flatui tracker test` shows each look for 3 seconds
- With 15 pages, the left column of the options window scrolls to reach **Profiles**

## 0.4.13

- **Unit frames**: the class icon on the player, target and focus frames shows one icon, not a crop of the whole icon sheet
- The **Reload** button in the options window reloads the interface. If the game blocks it for add-ons, the first press says so in one line and the button reloads on the next press. `/flatui status` then has a line **Reload: secure button.**
- Text sizes on bars and cast bars stay on when the game answers false for a font that loaded
- Combat numbers: a number that fails while it is drawn no longer takes its font string out of use
- `/flatui combat reset` names each row the game refused. The last line says the defaults are back only when they are, and names **Scrolling Combat Text for Self** when it stays as you have it
- `/flatui combat` prints the outline flags in quotes
- Movers: a spot near the screen edge is kept inside the limit the game sets for its own frames

## 0.4.12

- **Movers**, section **Centre**: new **Snap while dragging** (**To the middle of the screen**, **Off**), **Centre a handle with** (**A button on the handle**, **Alt and click**, **Both**), **Middle line** (**Shown while dragging**, **Always shown with the handles**, **Off**) and **Centre everything** (**No such button**, **A button in the Movers panel**)
- While you drag a handle or a window, a thin gold line shows down the middle of the screen. The handle or window snaps onto it when its middle is within 8 units
- Each handle has a small button in its top right corner that puts it on the middle at the height it has, and a tick box in its top left corner. A handle too small for them has them above it. **Centre ticked** in the **Movers** panel centres every ticked handle. Grey handles of frames the game places have neither
- With **Centre a handle with** set to **Alt and click** or **Both**, Alt and click on a handle centres it
- A window with no handle is centred by dragging it across the middle
- With **Place the tooltip** on and **Position** set to **Fixed**, a centred **Tooltip** handle puts the tooltip in the middle at any width

## 0.4.11

- **Side tab size** in the section **Controls** of the **Windows** page: **Game's size** (50), **Large** (42), **Medium** (36) or **Small** (30). **Small** is the default. The tab is the icon plus 5 units and the gaps between tabs are unchanged, so the column is shorter. It sizes the tabs beside the Character, Inspect, Collections, Looking For Group, bank, Professions and Legacy windows and needs **Side tabs**.

## 0.4.10

- **Chat and tooltips**, section **Tooltips**: new **Tooltip background** (Near black, Black, Dark blue, Dark brown), **Tooltip opacity** (40% to 100%) and **Tooltip shading** (**Flat**, **Lighter at the top**, **Darker at the bottom**). They apply to every tooltip and to the label above a comparison tooltip, which is always flat
- The tooltip box no longer follows **Background colour** and **Background opacity**. It starts as Near black at 70%, Flat (the general background gave 85%)
- With **Tooltip border and background** off the three rows are greyed and the game's own art is back
- If the game refuses a gradient the tooltip stays one colour and `/flatui status` says so

## 0.4.9

- **Map & Quest Log**: the small window has a title bar that drags it and a corner grip that sizes it from 60% to 150%, under the existing **Windows** settings on **Movers**. Its place and size are saved in the profile in use
- At full size and in the gamepad interface the game keeps the window, and `/flatui status` says why it cannot be dragged. The small place and size come back when the map is made small again
- A protected map is not moved or sized in combat; if it goes to full size in combat it keeps the addon's scale until combat ends

## 0.4.8

- **Minimap and buffs**, section **Minimap**: new **Minimap in cities** for the city map the game shows in the minimap inside some cities
- **Game's ring while the city map shows** brings the game's ring back only while the city map is up
- **Flat round cover** (the default) covers the square corners of the city map in the background colour and draws the thin border round the circle. It follows **Border colour**, **Background colour**, **Border thickness**, **Borderless** and **Minimap border**, and goes with the minimap when you hide it
- **Leave as is** leaves the city map as the game draws it
- `/flatui status` has a line **Minimap in cities**: whether the game asks for the city map here, whether it is loaded and shown, where the game draws it, whether the game's mask is set on it, whether the cover is shown and whether it is visible

## 0.4.7

- **Combat text**, section **Look**: **Font** (Friz Quadrata, Arial Narrow, Skurri, Morpheus), **Outline** (Thick, Thin, None), **Shadow** and **How a number appears** (**With a pop, larger for critical hits** or **Plainly**). They apply to the numbers in front of nameplates and to your own text. The defaults are Friz Quadrata, no outline, no shadow and a pop
- With a pop, a number swells for a fifth of a second. A critical hit starts a fifth larger than other numbers and swells to twice that size. A critical or crushing hit over an enemy is now a fifth larger than other numbers, with or without the pop (it was one and a half times)
- **Combat text**, section **Your character**: **Combat text for you** draws the damage and healing you take, as -412 in red (purple for magic) and +300 in green. **Also misses, dodges and gains** adds Miss, Dodge, Parry, Block, Resist, Absorb and the like, and gains such as +20. **Movement of your text** (Up, Down, In an arc) and **Size of your text** (60% to 160%)
- The handle **Combat text: you** in `/flatui move` places where your text starts. It starts above and left of your character
- While your text shows, the game's **Scrolling Combat Text for Self** is off and its other messages do not show. It is put back when you choose **Off**, switch **Place combat numbers** off, type `/flatui combat reset` or log out
- When the game refuses a font, the numbers show in Friz Quadrata with the same outline and shadow, or in the game's combat font, and `/flatui status` says which
- The sections for numbers over enemies are now **Position and size over enemies** and **Spread and movement over enemies**
- `/flatui combat test` shows samples for you and over your target. `/flatui combat` also shows the font in use, the outline flags the game gives, the hits seen for you, where your text starts and the height of WorldFrame

## 0.4.6

- Target and focus frames: a unit with no Elite or Rare kind gives up no room in the name row, so its name is as long as the player's
- **Unit frames**: a setting that changes the room of the texts in the name row, changed in combat, is laid out when combat ends. The PvP word waits for its place and does not overlap the name
- **Word in the name row** in the section **Elite and Rare** is now **Elite or Rare word**, so it differs from the **PvP flag** choice of the same name
- The tip of **Line under the name row** names the colours: gold for an Elite, silver for a Rare, red for a Boss

## 0.4.5

- **Unit frames**, section **Elite and Rare**, for the target and focus frames: **Mark after the level** (+ for an Elite, R for a Rare, R+ for a Rare Elite), **Word in the name row**, **Portrait border colour** (gold for an Elite, silver for a Rare, silver with a gold inner line for a Rare Elite, red for a Boss) and **Line under the name row**
- Name row order from the right: mark, level, word of the kind, PvP word with its time, name

## 0.4.4

- **Unit frames**, section **PvP flag**: **PvP flag** as an icon on the portrait, a word in the name row, both or off, on the player, target and focus frames; **Icon corner**; **Time until the flag drops** on your own frame
- The game's level text stays hidden after a level gain
- Shorter lines for the unit frames in `/flatui status`

## 0.4.3

- Window dragging and sizing, in a **Windows** section on the **Movers** page with eight settings. A window drags from any empty part or from its title bar, with an optional held key (**Shift**, **Alt** or **Ctrl**)
- A **Corner grip** at the bottom right sizes a window from 60% to 150%. Places and sizes are kept in the profile, or put back when the window closes. **Size applies to** each window or every window together
- **Reset windows** and `/flatui move reset windows` put every window back to its default place and size
- `/flatui status` lists windows that cannot be dragged, with the reason

## 0.4.2

- New **Combat text** page with 10 settings: damage and healing numbers over enemies, drawn in front of their nameplates with the kind of hit in parentheses after the amount, as in 412 (Glancing)
- Height, size, spread and movement of the numbers, an option to colour hits by school of magic, and a choice of every enemy with a nameplate or the target only
- Sets nine of the game's combat number settings and puts them back when **Place combat numbers** goes off
- `/flatui combat` shows the settings and the hits seen, `/flatui combat test` shows sample numbers over your target, and `/flatui combat reset` puts the game's defaults back

## 0.4.1

- Name row: the name on the player, target and focus frames is drawn at full opacity
- **Square portraits** show on the player, target and pet frames, each sized to the height of its bars
- **Corners** on **Soft** or **Slightly soft** round the border of each picture and leave the picture itself square
- The pet frame's name follows **Small frame text size**
- `/flatui status` has lines for the player, target and pet frames: where the name comes from, the picture's size, the pet name's size and the pet frame's scale

## 0.4.0

- Thin dark borders, flat backgrounds and flat bar fills on nameplates, unit frames, action bars, cast bars, swing timers, the personal resource display, chat, tooltips, the minimap and game windows
- Options window with 13 pages, 229 settings, a search box and a switch on every page but **Flat UI**. The same pages are under Options > AddOns > Flat UI
- **Profiles** with copy, reset, export and import as one line of text
- **Movers** for frames and windows: `/flatui move`, `/flatui grab` and drag by window title
- **Custom UI scale** from 35% to 115%
- Seven bar textures and five cast colours
- Nameplates: marks for Elite, Rare and Rare Elite, border colours for Elite, Rare and Boss, target and focus borders, class icons
- Unit frames: square portraits, name row, threat and Elite borders
- **Cooldown icons** row for picked spells, and restyled cooldown manager icons
- Tooltip placement at the cursor or at a fixed spot
- `/flatui status` shows what is styled and any error. A page that keeps failing stops on its own.
