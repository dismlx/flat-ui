Every setting of the **Action bars** group of the options window, 126 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Action bars](Action-bars).

Pages: [Action bars](#action-bars) · [Bar block](#bar-block) · [Class and item bars](#class-and-item-bars)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.51.

## Action bars

### General

**Buttons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Action buttons** | Flat UI's | Mouse clicks go to Flat UI's buttons, laid out like the game's bars. Applies after a reload. Choices: Flat UI's, The game's. A change takes full effect after a reload. |
| **Page arrows on the main bar** | On | Flat UI's buttons only. Point at an arrow for its key. Edit Mode's Hide bar scrolling hides them too. Needs **Action buttons** at Flat UI's. |
| **Restyle action bars** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Main bar buttons** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Extra bar buttons** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Pet bar buttons** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Stance bar buttons** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Button background** | On | A flat background behind each button, in the Flat UI page's background colour or the Background colour below while Own border and background is on. |
| **Icon crop** | 8% | Trims the edge of each icon. |
| **Square icons** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Flat highlights** | On | Flat tints on pressed, hovered and active buttons. Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Button border** | On | A thin border round each button, in the Flat UI page's border colour or the Border colour below. A proc or alert border still shows while it is off. |
| **Empty buttons** | Faint | How a button with nothing on it looks on the main bar and bars 2 to 8 while Edit Mode's Always show buttons is on, as it is at first. With that off, in Edit Mode or with Show empty buttons on the Bar block page, Flat UI's empty buttons hide, as the game's do. Every empty button is at full while a spell or item is on the cursor, so you can see where it goes. Choices: Normal, Faint, Hidden. |
| **Faint empty button opacity** | 50% | How faint an empty button of the main bar and bars 2 to 8 is while Empty buttons is Faint. Needs **Empty buttons** at Faint. |
| **Hide empty bars** | On | Flat UI's buttons only. Bars 2 to 8 hide while none of their buttons holds anything, and show again as soon as a spell or item is on the cursor, so you can fill them, and in /flatui move and Edit Mode. The main bar always shows. A bar hides or shows out of combat: in a fight it waits for the end. Needs **Action buttons** at Flat UI's. |

**Highlights**

| Setting | Default | Notes |
| --- | --- | --- |
| **Mouse over colour** | #FFFFFF | The tint over a button while the mouse is over it. Needs Flat highlights. Needs **Flat highlights** on. |
| **Pressed colour** | #FFFFFF | The tint over a button while its key or mouse button is held down. Needs Flat highlights. Needs **Flat highlights** on. |
| **Active colour** | #FFD100 | The tint on a button while its action is on: auto attack, Auto Shot, a stance or form, or the spell you are casting. Needs Flat highlights. Needs **Flat highlights** on. |

**Main bar art**

| Setting | Default | Notes |
| --- | --- | --- |
| **Hide bar frame** | On | Applies with the game's buttons. |
| **Hide end caps** | On | Applies with the game's buttons. |
| **Hide dividers** | On | Applies with the game's buttons. |

**Bar backgrounds**

| Setting | Default | Notes |
| --- | --- | --- |
| **Bar background** | Off | Bars in the bar block take Background panel from the Bar block page. |
| **Bar background colour** | #0F0F0F | The colour of the panel behind each bar. Its opacity is Bar background opacity. Needs **Bar background** on. |
| **Bar background opacity** | 60% | How solid the panel behind each bar is. Needs **Bar background** on. |

**Special bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Totem bar buttons** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Extra action button** | Off | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |

**Border and background**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own border and background** | Off | Gives the action buttons their own Border colour, Background colour and Background opacity below, in place of those of the Flat UI page. |
| **Border colour** | #000000 | The border round each button while Button border is on. Needs **Own border and background** on. |
| **Background colour** | #0F0F0F | The background behind each button while Button background is on. Its opacity is Background opacity. Needs **Own border and background** on. |
| **Background opacity** | 85% | How solid the background behind each button is. Needs **Own border and background** on. |

### Button text

**Hotkeys**

| Setting | Default | Notes |
| --- | --- | --- |
| **Hotkeys on** | All bars | The bars that show the key of each button. On the others the key is hidden and still works. Choices: All bars, Bars 2 to 8, Main bar, No bars. |
| **Hotkeys on empty buttons** | Off | Shows the key of a button with nothing on it. Off, an empty button of the main bar or bars 2 to 8 shows its key only while a spell or item is on the cursor, so you can see which key a slot has as you fill it. |
| **Hotkey text** | Short (M4, WU, N1, Sp) | Short also goes for Keybind on icons of the cooldown icons. Choices: As the game has it, Short (M4, WU, N1, Sp). |
| **Hotkey size** | 100% | The size of the key on each button, 100% as the game has it. The seconds left of a proc on a button take it too. |
| **Own hotkey colour** | Off | Out of range keeps the game's red. |
| **Hotkey colour** | #999999 | The colour of the key on each button while its target is in range. Needs **Own hotkey colour** on. |
| **Hotkey position** | Top right | Choices: Top right, Top left, Top, Centre, Bottom left, Bottom, Bottom right. |
| **Hotkey horizontal offset** | 0 px | Moves the key right from Hotkey position, or left below 0. Moves after the fight when changed in one. |
| **Hotkey vertical offset** | 0 px | Moves the key up from Hotkey position, or down below 0. Moves after the fight when changed in one. |

**Macro names and counts**

| Setting | Default | Notes |
| --- | --- | --- |
| **Macro names on** | All bars | The bars that show the name of a macro on its button. Choices: All bars, Bars 2 to 8, Main bar, No bars. |
| **Macro name size** | 100% | The size of a macro's name on its button, 100% as the game has it. |
| **Macro name colour** | #FFFFFF | The name of a macro on a button. |
| **Macro name position** | Bottom | Moves after the fight when changed in one. Choices: Bottom, Top, Centre. |
| **Count size** | 100% | The size of the count of reagents, arrows or stacks on a button, 100% as the game has it. |
| **Count colour** | #FFFFFF | The number of reagents, arrows or stacks on a button. |
| **Count position** | Bottom right | Moves after the fight when changed in one. Choices: Bottom right, Bottom left, Top left, Top right, Bottom. |
| **Button text outline** | `game` | The outline of the hotkey, macro name and count on each button, and of the seconds left of a proc. |

### Colours and cooldowns

**Usability**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own usability colours** | Off | Paints the icon in Not enough power colour while you lack the mana, rage or energy for it, and in Cannot use colour while it cannot be used, in place of the game's blue and grey. |
| **Not enough power colour** | #8080FF | The icon's tint while you lack the mana, rage or energy for its spell. Needs **Own usability colours** on. |
| **Cannot use colour** | #666666 | The icon's tint while its action cannot be used, such as Execute while the target's health is over 20%. Needs **Own usability colours** on. |
| **Tint icon when out of range** | On | The game only turns the hotkey red. |
| **Out of range colour** | #A32626 | The icon's tint while your target is out of its range. Needs **Tint icon when out of range** on. |

**Cooldowns**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cooldown sweep** | On | Also on the pet and stance bars. |
| **Own sweep opacity** | Off | Also on the pet and stance bars. |
| **Sweep colour** | #000000 | Its opacity is Sweep opacity. Needs **Own sweep opacity** on. |
| **Sweep opacity** | 65% | How dark the sweep over a cooling icon is. Also on the pet and stance bars. Needs **Own sweep opacity** on. |
| **Global cooldown sweep** | On | Off: a button that only waits for the global cooldown shows no sweep. Flat UI's buttons only. |
| **Edge line** | Off | A bright line along the edge of the sweep. Not on the pet and stance bars. |
| **Edge colour** | #FFFFFF | The colour of the line along the edge of the sweep. Needs **Edge line** on. |
| **Cooldown numbers** | Off | The game's Show numbers on cooldowns: the seconds left on every action button, Flat UI's and the game's, the pet and stance bars too. A game setting, the same in every profile. Changed in a fight, it is written when the fight ends. |
| **Cooldown number size** | As the game has it | Numbers show while Cooldown numbers is on. Also on the pet and stance bars. Choices: As the game has it, Small, Normal, Large, Huge. |
| **Cooldown number colour** | #FFFFFF | Also on the pet and stance bars. |
| **Tenths below** | 0 s | Under this many seconds the number shows tenths, as 2.4. 0 means never. Also on the pet and stance bars. |
| **Grey out icon on cooldown** | Off | Not for the global cooldown. |
| **Flash when ready** | Off | A quick flash in Flash colour over the icon as a cooldown ends. Not for the global cooldown. Flat UI's buttons only. |
| **Flash colour** | #FFFFFF | The colour of the flash over an icon as its cooldown ends. Needs **Flash when ready** on. |
| **Shortest cooldown that flashes** | 0 s | A shorter cooldown ends without a flash, after a stance, form or page change too. 0 flashes every cooldown longer than the global cooldown. Needs **Flash when ready** on. |
| **Sound when ready** | None | Plays as a cooldown that flashes ends, at most once a second. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Flash when ready** on. |

### Glows and animations

**Glows and animations**

| Setting | Default | Notes |
| --- | --- | --- |
| **Proc glow** | Game glow | On Flat UI's own buttons the game glow has the Glow style of the Trackers page. Choices: Game glow, Coloured border, None. |
| **Proc border colour** | #FFD100 | Needs **Proc glow** at Coloured border. |
| **Rotation helper highlight** | On | Shows on the game's buttons only. |
| **Cast fill animation** | On | On Flat UI's own buttons a flat fill in the cast bar's colour rises over the icon while you cast, and empties over a channel, also on macros and items that cast the spell. It follows pushback, and takes the class colour when the player cast bar does. |
| **Interrupt flash** | On | The button of a cast that is interrupted flashes in the cast bar's Interrupted colour, a macro or an item that cast it too. |
| **Aim highlight** | On | While a spell you place on the ground, such as Blizzard or Volley, waits for its spot or for a click on its target, its button on Flat UI's bars pulses in the cast bar's colour, also while Auto Shot or a wand keeps shooting. |

**Extra action button**

| Setting | Default | Notes |
| --- | --- | --- |
| **Extra button artwork** | On |  |

## Bar block

| Setting | Default | Notes |
| --- | --- | --- |
| **Group action bars into blocks** | Off | Lines up the bars of each block below, at first action bars 3 and 4, action bar 2 and the main bar in block 1, top to bottom, with Flat UI's experience bar under them at the block's width (Experience bar under the bar block). /flatui move shows one box for each block, Action bar block, Action bar block 2 and 3, that moves its bars, with a tab on each bar to drag it to another place in its block or into another block. A bar of a block that the game's options have off is turned on there, at login and when you add it. Also while Leave the game's action bars alone is on, which then leaves only the bars in no block alone. Applies out of combat. |

**Block 1**

| Setting | Default | Notes |
| --- | --- | --- |
| **Bars** |  | The bars of the block, first bar first. A bar can be in one block only. In /flatui move, drag the tab on a bar up or down to change its place, or onto another block's box. |
| **Add a bar** |  | The bar goes last in the block. A bar in another block leaves that one. |
| **Stack direction** | Upward from the first bar | Upward puts the first bar of the list at the bottom and the others above it; downward puts it at the top. Choices: Upward from the first bar, Downward from the first bar. |
| **Line up bars** | Centre | Lines up bars of different widths by their left edges, their centres or their right edges. Choices: Left, Centre, Right. |
| **Own gap between bars** | Off | Off: the gap between buttons is used. |
| **Gap between bars** | 2 px | The space between one bar of the block and the next. Needs **Own gap between bars** on. |

**Block 2**

| Setting | Default | Notes |
| --- | --- | --- |
| **Bars** |  | The bars of the block, first bar first. A bar can be in one block only. Off until it has a bar. In /flatui move, drag the tab on a bar up or down to change its place, or onto another block's box. |
| **Add a bar** |  | The bar goes last in the block. A bar in another block leaves that one. |
| **Stack direction** | Upward from the first bar | Upward puts the first bar of the list at the bottom and the others above it; downward puts it at the top. Choices: Upward from the first bar, Downward from the first bar. |
| **Line up bars** | Centre | Lines up bars of different widths by their left edges, their centres or their right edges. Choices: Left, Centre, Right. |
| **Own gap between bars** | Off | Off: the gap between buttons is used. |
| **Gap between bars** | 2 px | The space between one bar of the block and the next. Needs **Own gap between bars** on. |

**Block 3**

| Setting | Default | Notes |
| --- | --- | --- |
| **Bars** |  | The bars of the block, first bar first. A bar can be in one block only. Off until it has a bar. In /flatui move, drag the tab on a bar up or down to change its place, or onto another block's box. |
| **Add a bar** |  | The bar goes last in the block. A bar in another block leaves that one. |
| **Stack direction** | Upward from the first bar | Upward puts the first bar of the list at the bottom and the others above it; downward puts it at the top. Choices: Upward from the first bar, Downward from the first bar. |
| **Line up bars** | Centre | Lines up bars of different widths by their left edges, their centres or their right edges. Choices: Left, Centre, Right. |
| **Own gap between bars** | Off | Off: the gap between buttons is used. |
| **Gap between bars** | 2 px | The space between one bar of the block and the next. Needs **Own gap between bars** on. |

**Buttons**

| Setting | Default | Notes |
| --- | --- | --- |
| **One size and spacing for every bar** | On | Applies after a reload. Action bars 4 and 5 become horizontal, so action bar 4 lies in block 1 like the others. A change takes full effect after a reload. |
| **Button size** | 100% | 100% is 45 px. Needs **One size and spacing for every bar** on. |
| **Button spacing** | 2 px | Needs **One size and spacing for every bar** on. |
| **Buttons per row** | 12 | Choices: 12, 6, 4, 3. Needs **One size and spacing for every bar** on. |
| **Show empty buttons** | On | Edit Mode's Always show buttons. On, empty buttons look as Empty buttons on the Action bars page sets; off, they hide, on Flat UI's buttons too. Needs **One size and spacing for every bar** on. |

**Other bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Stance, pet and experience bars** | Above the block | Above the block: experience bars on top of block 1, stance bar left and pet bar right above them. Flat UI's experience bar goes under the block instead while Experience bar under the bar block is on. Not applied while Leave the game's action bars alone is on. Choices: Above the block, Left to the game. |

**Background**

| Setting | Default | Notes |
| --- | --- | --- |
| **Background panel** | Off | A flat panel behind the bars of the block. |
| **Background padding** | 4 px | The room between the bars and the edge of the panel. Needs **Background panel** on. |
| **Own panel colour** | Off | Off, the panel takes the background colour and opacity of the Flat UI page. Needs **Background panel** on. |
| **Panel colour** | #0F0F0F | Its opacity is Panel opacity. Needs **Own panel colour** on. |
| **Panel opacity** | 75% | The panel still fades with the block. Needs **Own panel colour** on. |

**Fade**

| Setting | Default | Notes |
| --- | --- | --- |
| **Fade the block** | Off | Faded bars still take clicks and are at full opacity while something is held on the cursor or a spell flyout is open, in Edit Mode and while /flatui move is open. |
| **Blocks that fade** | Every block | A block left out stays at full opacity, and the Fading page can fade its bars. Flat UI's experience bar under block 1 goes with block 1. Choices: Every block, Block 1 only, Blocks 2 and 3. Needs **Fade the block** on. |
| **Faded opacity** | 30% | How far the block fades. 0% hides it until it is wanted again, and its buttons still take clicks. Needs **Fade the block** on. |
| **Wait before fading** | 500 ms | How long the block stays at full opacity after the mouse leaves it or the fight ends, before it starts to fade. It comes back to full at once. Needs **Fade the block** on. |
| **Fade time** | 300 ms | How long the block takes to go down to Faded opacity. Needs **Fade the block** on. |
| **Full opacity in combat** | On | The block is at full opacity from the start of a fight to its end. Needs **Fade the block** on. |
| **Full opacity under the mouse** | On | The block is at full opacity while the mouse is over it, its panel and Flat UI's page arrows included. Needs **Fade the block** on. |
| **Full opacity with a target** | Off | For a pull with a ranged opener, or a buff on a friend, before the fight starts. Needs **Fade the block** on. |
| **Full opacity as you cast** | Off | Each spell or item you use brings the faded block back while you cast, for a moment after each instant spell or item, and for Wait before fading after. Needs **Fade the block** on. |
| **Full opacity while a proc is up** | On | A block that holds the spell of a proc alert of the Trackers page, such as Overpower, Revenge or Execute, is at full opacity while the proc is up. Needs **Fade the block** on. |
| **Full opacity until health and mana are full** | Off | The block stays at full while your health, or your mana if you have mana, is under full, so it is there while you eat and drink, then fades after Wait before fading. Not while you are dead. Needs **Fade the block** on. |

## Class and item bars

| Setting | Default | Notes |
| --- | --- | --- |
| **Class and item bars** | On | Nothing changes until a bar is picked below. Not applied while Leave the game's action bars alone is on. |

**Blocks**

| Setting | Default | Notes |
| --- | --- | --- |
| **Class spells** | None | Set the icons and rows of the bar in Edit Mode. Choices: None, Action bar 2, Action bar 3, Action bar 4, Action bar 5, Action bar 6, Action bar 7, Action bar 8. |
| **Buffs to apply** | None | Choices: None, Action bar 2, Action bar 3, Action bar 4, Action bar 5, Action bar 6, Action bar 7, Action bar 8. |
| **Consumables** | None | Choices: None, Action bar 2, Action bar 3, Action bar 4, Action bar 5, Action bar 6, Action bar 7, Action bar 8. |

**Position**

| Setting | Default | Notes |
| --- | --- | --- |
| **Blocks hang from** | Main action bar | Used when the Bar block page is off. Choices: Main action bar, Action bar 2, Action bar 3, Action bar 4, Action bar 5, Action bar 6, Action bar 7, Action bar 8. |
| **Class spells position** | Where its handle is | Blocks at the same position stack outward. Choices: Where its handle is, Above, left, Above, right, Below, left, Below, right, Left, bottom, Left, top, Right, bottom, Right, top. |
| **Buffs to apply position** | Where its handle is | Choices: Where its handle is, Above, left, Above, right, Below, left, Below, right, Left, bottom, Left, top, Right, bottom, Right, top. |
| **Consumables position** | Where its handle is | Choices: Where its handle is, Above, left, Above, right, Below, left, Below, right, Left, bottom, Left, top, Right, bottom, Right, top. |
| **Gap** | 4 px |  |

**Pet bar**

| Setting | Default | Notes |
| --- | --- | --- |
| **Pet bar position** | Where the game puts it | In Edit Mode press an arrow key once on the pet bar and save so the game stops stacking it. Choices: Where the game puts it, Above, right, Above, left. |
