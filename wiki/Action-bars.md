The **Action bars** group styles your action buttons and lays out the bars they sit on. Its pages are **Action bars**, **Bar block** and **Class and item bars**.

![Flat UI in a fight, with flat, square action buttons along the bottom of the screen](https://raw.githubusercontent.com/dismlx/flat-ui/main/media/flatui-in-play.jpg)

For a quick start, the **Your action bars** stop of setup (`/flatui setup`) picks a look in one click: **Flat buttons**, **Flat and quiet**, **Round icons** or **The game's buttons**. See [Getting started](Getting-started). The pages below tune each part of that look.

## Action bars

The **Action bars** page has four tabs: **General**, **Button text**, **Colours and cooldowns** and **Glows and animations**.

### Flat UI's buttons or the game's

**Action buttons**, at the top of the **General** tab, picks whose buttons you press:

- **Flat UI's** (the default): Flat UI draws its own buttons over the game's bars. They sit where the game's bars are and copy their size and number of icons, so Edit Mode still places the bars. Mouse clicks go to Flat UI's buttons.
- **The game's**: you keep the game's own buttons, and Flat UI restyles them.

A change of **Action buttons** applies after a reload.

Some rows work only with Flat UI's buttons: **Page arrows on the main bar**, **Hide empty bars**, **Global cooldown sweep**, **Flash when ready**, **Cast fill animation** and **Aim highlight**. Their tips say so. **Rotation helper highlight** is the other way round: it shows on the game's buttons only.

With Flat UI's buttons, the game's Quick Keybind Mode still works. While it is open, the game's buttons show so you can bind keys as usual, and chat says so once. Opened in a fight, they show when the fight ends.

### Which bars are restyled

**Restyle action bars** turns the whole restyle on or off. Under it, **Main bar buttons**, **Extra bar buttons** (action bars 2 to 8), **Pet bar buttons** and **Stance bar buttons** pick the bars one by one. Under **Special bars**, **Totem bar buttons** is on and **Extra action button** is off. Turning any of these off takes full effect after a reload.

### How a button looks

- **Square icons** (on) gives square icons. Turn it off to keep the game's round icons; that takes full effect after a reload.
- **Icon crop** (8%) trims the edge of each icon.
- **Button background** and **Button border** draw a flat background and a thin border round each button, in the background and border colours of the **Flat UI** page. A proc or alert border still shows while **Button border** is off.
- **Own border and background**, under **Border and background**, gives the buttons their own **Border colour**, **Background colour** and **Background opacity** (85%) in place of those of the **Flat UI** page.
- **Flat highlights** (on) puts flat tints on buttons: **Mouse over colour** while the mouse is over one, **Pressed colour** while its key or mouse button is held down, and **Active colour** (gold) while its action is on, such as auto attack, Auto Shot, a stance or form, or the spell you are casting. Turning it off takes full effect after a reload.
- **Bar background** (off) puts a panel behind each bar, in **Bar background colour** at **Bar background opacity** (60%). Bars in a bar block take **Background panel** from the **Bar block** page instead.
- **Hide bar frame**, **Hide end caps** and **Hide dividers**, under **Main bar art**, apply with the game's buttons.

A change of **Button background**, **Icon crop**, **Button border**, **Empty buttons**, **Faint empty button opacity**, **Mouse over colour**, **Pressed colour** or **Active colour** made in a fight lands when it ends. With the options window open, chat says once: "Flat UI: action buttons take their new look when the fight ends."

### Empty buttons and empty bars

**Empty buttons** (**Faint** by default) sets how a button with nothing on it looks on the main bar and bars 2 to 8:

- **Normal** shows it like any other button.
- **Faint** shows it at **Faint empty button opacity** (50%).
- **Hidden** hides it.

This holds while Edit Mode's **Always show buttons** is on, as it is at first. With that off, Flat UI's empty buttons hide, as the game's do. You can turn it off in Edit Mode, or, while the **Bar block** page is on, with its **Show empty buttons** row.

An empty button shows no key, so a bar that is half full is not a row of key names. **Hotkeys on empty buttons**, on the **Button text** tab, shows them again.

While a spell or item is on the cursor, every empty button is at full and shows its key. You can see where the spell can go and which key that slot has. Faint empty buttons rise to full over about a tenth of a second as you pick a spell up, and settle back over a fifth of a second as you drop it, so the bars do not flicker.

**Hide empty bars** (on, under **Buttons**) hides bars 2 to 8 while none of their buttons holds anything. They show again:

- as soon as a spell or item is on the cursor, so you can fill them,
- in `/flatui move`,
- in Edit Mode.

The main bar always shows. A bar hides or shows out of combat only: a bar that empties in a fight, or a drag in a fight, waits for the end. Turning the row on or off in a fight with the options window open says so in chat.

The first time bars hide for being empty, chat says so once for the character, as "Flat UI: action bar 3 holds nothing, so it hides until a spell or item is on the cursor. Turn off Hide empty bars on the Action bars page to keep empty bars." Bars that hide together are named in one line. `/flatui status` lists them while they hide, as "Hidden for being empty: action bars 3 and 4."

With the **Bar block** page on, a block closes up round a bar hidden for being empty. It stacks only the bars that show, and its background panel, Flat UI's experience bar and the stance and pet bars sit tight round them, so a half-filled character sees no blank rows. The empty space no longer brings a faded block back under the mouse. As a spell or item is picked up, the empty bars come back in their places.

### Page arrows on the main bar

**Page arrows on the main bar** (on, under **Buttons**) puts the page number with an up and a down arrow left of the main bar, where the game has them.

- The number follows the page as you change it with Shift and the wheel or a key. It pops each time it changes, in a fight too, so a stray page change catches your eye.
- Click an arrow to page the bar, in a fight too. Point at an arrow to see **Next page** or **Previous page**, the page you are on and its key.
- Click the page number to go straight back to page 1. Pointing at it says the page, as "Page 4". On page 1 a click does nothing, and the number stays gold under the mouse.
- With the mouse over an arrow or the number, roll the wheel up for the next page and down for the previous one. Away from them, the wheel zooms the camera as before.

The arrows move, hide and fade with the main bar. Edit Mode's **Hide bar scrolling** hides them too. Pointing at them counts as pointing at the main bar, so a main bar or bar block faded on the **Fading** or **Bar block** page comes back to full before you click.

Ticking or clearing the row in a fight with the options window open says in chat that the arrows show or go when the fight ends.

### Finding a spell on your bars

Point at a spell in the spellbook, or at a talent, and each of Flat UI's buttons that holds it pulses with the game's highlight, in a fight too. With **Flat highlights** on, the highlight is a flat gold over the icon. This shows where a spell sits, or that it is on no bar.

### Button text tab

The **Button text** tab sets the hotkey, macro name and count on Flat UI's buttons and on the restyled game buttons.

#### Hotkeys

- **Hotkeys on** picks the bars that show the key of each button: **All bars** (the default), **Bars 2 to 8**, **Main bar** or **No bars**. A hidden key still works.
- **Hotkeys on empty buttons** (off) shows the key of a button with nothing on it.
- **Hotkey text** is **Short (M4, WU, N1, Sp)** by default, or **As the game has it**. Short also goes for **Keybind on icons** of the cooldown icons.
- **Hotkey size**, **Own hotkey colour** with its **Hotkey colour** (grey), and **Hotkey position** (**Top right** by default) set its look and place. **Hotkey horizontal offset** and **Hotkey vertical offset** nudge it from there. Out of range, the key keeps the game's red.

#### Macro names and counts

- **Macro names on** picks the bars that show a macro's name, with the same four choices.
- **Macro name size**, **Macro name colour** (white) and **Macro name position** (**Bottom**, **Top** or **Centre**) set the name. Put a long name at the top, clear of a count at the bottom.
- **Count size**, **Count colour** (white) and **Count position** (**Bottom right**, **Bottom left**, **Top left**, **Top right** or **Bottom**) set the count of reagents, arrows or stacks. Move it clear of a hotkey or macro name in the bottom right.
- **Button text outline** outlines the hotkey, macro name and count, and the seconds left of a proc on a button.

Colours apply at once, in a fight too. A new position made in a fight waits for its end. The first such change in a fight, with the options window open, says in chat: "Flat UI: hotkeys, macro names and counts move when the fight ends."

### Colours and cooldowns tab

#### Usability

- **Tint icon when out of range** (on) tints the icon in **Out of range colour** (red) while your target is out of its range. The game only turns the hotkey red.
- **Own usability colours** (off) paints the icon in **Not enough power colour** while you lack the mana, rage or energy for it, and in **Cannot use colour** while it cannot be used, such as Execute while the target's health is over 20%. These replace the game's blue and grey.

#### Cooldown sweep

- **Cooldown sweep** (on) draws the dark sweep over a cooling icon, on the pet and stance bars too.
- **Own sweep opacity** (off) gives the sweep your own **Sweep colour** (black) and **Sweep opacity** (65%).
- **Global cooldown sweep** (on). Turn it off and a button of Flat UI's that only waits for the global cooldown shows no sweep, so the bars stay calm between presses and only real cooldowns sweep. A spell whose own cooldown ends under the global cooldown keeps its sweep to the end, so it never looks ready before it is.
- **Edge line** (off) draws a bright line in **Edge colour** along the edge of the sweep, on the main and extra bars.
- **Grey out icon on cooldown** (off) greys the icon while its cooldown runs. The global cooldown does not count.

#### Cooldown numbers

**Cooldown numbers** is the game's own **Show numbers on cooldowns**. It is a game setting, the same in every profile. Ticked, it puts the seconds left on every action button: Flat UI's, the game's, and the pet and stance bars. Ticked in a fight, it is written when the fight ends, and with the options window open chat says so: "Flat UI: cooldown numbers show when the fight ends."

While the numbers show, three rows style them on every bar:

- **Cooldown number size**: **As the game has it** (the default), **Small**, **Normal**, **Large** or **Huge**.
- **Cooldown number colour** (white).
- **Tenths below** (0 s, which means never): under that many seconds the number shows tenths, as 2.4.

Each change applies at once, with no reload.

#### Flash when ready

**Flash when ready** (off) flashes the icon in **Flash colour** (white) as a cooldown ends. It works on Flat UI's buttons, only on a button that shows, and not for the global cooldown.

- **Shortest cooldown that flashes** (0 s) lets shorter cooldowns end quietly. At 0 every cooldown longer than the global cooldown flashes. Set it to 30 s and a 6 second Mortal Strike stops flashing all fight, while a long cooldown still stands out. A cooldown that was already running when a button first shows it, after a stance, form, Stealth or page change or a reload, is measured from when you used it, so a warrior can stance-dance and still see only the long ones flash.
- **Sound when ready** (**None** by default) plays as a cooldown that flashes ends, at most once a second. The choices are **Spell alert**, **Chimes**, **Bell**, **Warhorn**, **Raid warning**, **Alarm** and **Whisper warning**. Picking one plays it.

#### Trying a change

With the options window open and test mode off, a change of the sweep rows, the cooldown numbers, **Flash when ready** or **Flash colour** plays a 4 second sample sweep in the new look on the first sample button. That is the first button of Flat UI's main bar that holds something, else of bars 2 to 8. It ends with the flash. A change of a usability colour paints the icon of that button in the row's colour for 2 seconds.

### Glows and animations tab

- **Proc glow** marks a button whose proc is up: **Game glow** (the default), **Coloured border** in **Proc border colour** (gold), or **None**. On Flat UI's own buttons, the game glow follows **Glow style** on the **Proc alerts** tab of **Trackers**. See [Combat](Combat).
- **Rotation helper highlight** (on) shows on the game's buttons only.
- **Cast fill animation** (on): on Flat UI's own buttons, a flat fill in the cast bar's colour rises over the icon while you cast, and empties over a channel. It works on macros and items that cast the spell, follows pushback, and takes your class colour when the player cast bar does.
- **Interrupt flash** (on): the button of a cast that is interrupted flashes in the cast bar's **Interrupted colour**, from the **Colours** tab of the **Flat UI** page. The button and the cast bar say "interrupted" in one colour.
- **Aim highlight** (on): while a spell you place on the ground, such as Blizzard, Rain of Fire, Flamestrike, Hurricane or Volley, waits for its spot, its button on Flat UI's bars pulses softly in the cast bar's **Cast colour**. It also pulses while a spell waits for a click on its target. It keeps pulsing through an Auto Shot or a wand shot, until you place, cast or cancel the spell. While **Class colour on the player bar** paints your cast bar, the pulse takes your class colour.
- **Extra button artwork** (on), under **Extra action button**, keeps the game's art round the extra action button. Turn it off to hide that art.

These effects light only buttons you can see. With the options window open and test mode off, turning **Cast fill animation**, **Interrupt flash** or **Aim highlight** on plays it once on the first sample button. A change of **Proc glow** (other than to **None**) or **Proc border colour** lights that button's proc glow for 3 seconds.

[Test mode](Test-mode) plays these effects on up to four buttons of your bars every 5 seconds: a cast fill, an interrupt flash followed by the proc glow, an aim pulse, and a sample sweep that ends with the flash.

## Bar block

The **Bar block** page lines several action bars up into one block, with one box to move them all. It is off as Flat UI comes. Turn on **Group action bars into blocks** to use it.

### What the block does

Block 1 holds, from the top: action bar 3, action bar 4, action bar 2 and the main bar. It has one box in `/flatui move`, **Action bar block**, that moves all its bars together. See [Layout](Layout).

- The page works even while **Leave the game's action bars alone** is on (on the **Flat UI** page). That row then leaves only the bars in no block to the game.
- If a bar of a block is off in the game's options, Flat UI turns it on, at login and when you add it, and says so in chat.
- Flat UI's experience bar sits right under block 1, exactly as wide as the block, and follows it. This is **Experience bar under the bar block**, on by default on the **Experience and menu bars** page. With that row off, or with this page off, the experience bar has its own box in `/flatui move` and its own **Width**. See [HUD](HUD).
- **Stance, pet and experience bars** (under **Other bars**): **Above the block** (the default) puts the experience bars on top of block 1, and the stance bar left and the pet bar right above them. Flat UI's experience bar goes under the block instead while **Experience bar under the bar block** is on. **Left to the game** leaves them where the game puts them. This row is not applied while **Leave the game's action bars alone** is on.

The block changes its layout only out of combat. A change of a block's bars, **Stack direction**, **Line up bars** or gap made in a fight waits for its end, and the first one says: "Flat UI: the bar block lays out again when the fight ends."

### Choosing the bars of a block

There are up to three blocks, each with a section of its own: **Block 1**, **Block 2** and **Block 3**. Blocks 2 and 3 are off until you give them a bar. They start beside block 1, with their own boxes in `/flatui move`: **Action bar block 2** and **Action bar block 3**.

You can set the bars of a block in two ways. Both change the same order.

On the page:

- **Bars** lists the bars of the block, first bar first. Pick a line to move a bar up or down, or to take it out.
- **Add a bar** adds the main bar or one of bars 2 to 8. It goes last in the block. A bar can be in one block only, so a bar in another block leaves that one.

In `/flatui move`:

- Each bar of a block has a tab inside the block's box. Drag the tab up or down and let go, and the bar takes that place in its block. A line across the block shows where it will go.
- Drop the tab on another block's box to put the bar in that block.
- Press Escape, or let go outside every box, to leave the bars as they were.

When a block's bars differ from its start, its **Bars** row shows the changed dot and the reset arrow. Resetting block 1 puts back the main bar and bars 2, 4 and 3.

### Laying out a block

Each block has its own layout rows:

- **Stack direction**: **Upward from the first bar** (the default) puts the first bar of the list at the bottom and the others above it. **Downward from the first bar** puts it at the top.
- **Line up bars**: bars of different widths line up by their **Left** edges, their **Centre** (the default) or their **Right** edges.
- **Own gap between bars** (off) sets **Gap between bars** (2 px) yourself. While it is off, the gap between buttons is used.

### Buttons

**One size and spacing for every bar** (on) gives the bars of the blocks one button size and row length while the page is on. It also lays action bars 4 and 5 flat like the others, so action bar 4 lies in block 1 like the rest. It applies after a reload. Under it:

- **Button size** (100%, which is 45 px; 50% to 200%).
- **Button spacing** (2 px).
- **Buttons per row**: **12**, **6**, **4** or **3**.
- **Show empty buttons** (on) is Edit Mode's **Always show buttons**. On, empty buttons look as **Empty buttons** on the **Action bars** page sets. Off, they hide, on Flat UI's buttons too.

### Background panel

**Background panel** (off) puts a flat panel behind each block. It takes the background colour and opacity of the **Flat UI** page. Turn on **Own panel colour** to give it its own **Panel colour** at **Panel opacity** (75%), so it can be fainter than the frames or match the action bars' **Bar background**. **Background padding** (4 px) is the room between the bars and the edge of the panel.

While a block holds the main bar, its panel widens to take in Flat UI's page arrows and page number left of it. The panel fades with the block.

### Fading the block

**Fade the block** (off) eases the bars down to **Faded opacity** (30%) once nothing needs them. Faded bars still take clicks. At 0% the block is gone until it is wanted again.

- **Blocks that fade**: **Every block** (the default), **Block 1 only** or **Blocks 2 and 3**. A block left out stays at full, and you can fade its bars on the **Fading** page instead. Flat UI's experience bar under block 1 goes with block 1.
- **Wait before fading** (500 ms) is how long the block stays at full after the mouse leaves it or the fight ends. A mouse passing over the bars on its way across the screen does not make them flicker.
- **Fade time** (300 ms) is how long the fade takes. The block comes back to full at once.

The block comes back to full:

- in a fight, with **Full opacity in combat** (on),
- under the mouse, with **Full opacity under the mouse** (on), its panel and Flat UI's page arrows included,
- while you have a target, with **Full opacity with a target** (off), for a ranged opener or a buff on a friend before the fight,
- as you cast, with **Full opacity as you cast** (off): while you cast, for a moment after each instant spell or item, and for **Wait before fading** after,
- while a proc is up, with **Full opacity while a proc is up** (on), for a block that holds the spell of a proc alert of the **Trackers** page, such as Overpower, Revenge, Execute or Clearcasting,
- until your health and mana are full, with **Full opacity until health and mana are full** (off), so the bars are there while you eat and drink. Not while you are dead.
- while you hold the key of **While a key is held** on the **Fading** page, its panel and Flat UI's experience bar under it included. Once you let go, it fades again after **Wait before fading**.

The block is also at full while something is on the cursor or a spell flyout is open, in Edit Mode, and while `/flatui move` is open, so you can see the bars you line up. After **Done**, it waits **Wait before fading** and fades again.

### Commands and checks

`/flatui status` says whether each block is placed, and why not, such as **Move frames** or **Keep moved frames in place** being off on the **Movers** page. `/flatui block facts` says what the game reports about the action bars and Edit Mode layouts, which helps when a bar will not go where you expect.

## Class and item bars

The **Class and item bars** page names three of the game's action bars as your **Class spells**, **Buffs to apply** and **Consumables** bars, and hangs them beside your main bar or bar block.

**Class and item bars** is on as Flat UI comes, but nothing changes until you pick a bar. The page is not applied while **Leave the game's action bars alone** is on, as it is at first, so turn that row off on the **Flat UI** page first (it applies after a reload). See [Look](Look).

### Picking the bars

Under **Blocks**, **Class spells**, **Buffs to apply** and **Consumables** each pick **None** or one of **Action bar 2** to **Action bar 8**. Set the icons and rows of each bar in Edit Mode. A bar that is already in a block of the **Bar block** page stays with that page.

### Where they hang

- **Blocks hang from** picks the bar they hang from: **Main action bar** (the default) or one of bars 2 to 8. It is used while the **Bar block** page is off. While that page is on, they hang from block 1.
- **Class spells position**, **Buffs to apply position** and **Consumables position** each pick a side: **Above, left**, **Above, right**, **Below, left**, **Below, right**, **Left, bottom**, **Left, top**, **Right, bottom** or **Right, top**. **Where its handle is** (the default) leaves the bar where you put it.
- Bars at the same position stack outward, **Gap** (4 px) apart.

**Pet bar position** can put the pet bar **Above, right** or **Above, left**, or leave it **Where the game puts it** (the default). In Edit Mode, press an arrow key once on the pet bar and save, so the game stops stacking it. While the **Bar block** page places the stance and pet bars above the block, it places the pet bar.

Flat UI places these bars with its movers, so they need **Move frames**, **Move the game's own frames** and **Keep moved frames in place** on the **Movers** page, all on as Flat UI comes. `/flatui status` says when one is off, when two rows pick the same bar, or when a bar is off in the game's options.

## Commands for this group

| Command | What it does |
| --- | --- |
| `/flatui blocks` | Lists the bars picked on the **Class and item bars** page and where each hangs, and the pet bar's place |
| `/flatui block facts` | Says what the game reports about the action bars and Edit Mode layouts |
| `/flatui move` | Shows the boxes that move frames, with **Action bar block** to **Action bar block 3** and the tabs on their bars |
| `/flatui status` | Says what is styled and placed, and why something is not |
| `/flatui test` | Turns test mode on or off; it plays the button effects on your bars |

See [Commands](Commands) for every command.

Every setting of this group, with its default: [Settings: Action bars](Settings-Action-bars).
