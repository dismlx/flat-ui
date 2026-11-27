The **Combat** group holds what you watch in a fight: your own cooldowns, the buffs and items you must keep up, your procs, the shields and defensives on you, and the cooldowns of enemy players. Its pages are **Cooldowns**, **Trackers**, **Defensives on you**, **Absorb shields**, **Charges**, **Enemy cooldowns** and **Combat text**.

Every page has a switch at the top. Out of combat, most changes to a look show samples on screen for a few seconds, so you see the result as you set it. Test mode shows samples of every frame on these pages at once; see [Test mode](Test-mode). To move any of these frames, type `/flatui move` and drag its box; see [Layout](Layout).

## Cooldowns

The **Cooldowns** page puts a row of icons on screen for the spells, trinkets and items you pick, each with its cooldown sweep and time left. **Cooldown icons** at the top turns it on or off (on by default).

The row starts empty: you add what you want to watch. The list belongs to the character you play, so each character keeps its own.

The page has four tabs: **General**, **States and text**, **Rows 2 to 4** and **Cooldown pulse**.

### Adding spells and items

Use the rows under **Spells** on the **General** tab:

- **Add a spell** lists spells you can add. For a spell that is not listed, type `/flatui cooldown add` and its name, its spell ID or a shift-clicked spell. **Remove a spell** takes one off.
- **Add the spells of a bar** adds every spell with a cooldown on one action bar that the row does not have yet. Action bar 1 is the one the main bar shows now, such as a warrior's stance bar. Later changes to that bar are not followed. `/flatui cooldown import 1` does the same, and 2 to 8 for the other bars.
- **Equipped trinkets** (off) adds your two trinket slots after the spells.
- **On-use gear in other slots** (off) adds the gear you wear that has a use, such as engineering goggles or boots, after the trinkets.
- **Add a potion or healthstone** adds healing potions, mana potions or healthstones. Every rank shares one icon: the best one in your bags that your level allows, with how many you carry.
- **Add an item** adds an item in your bags that has a use, such as the Hearthstone, a mana gem or an engineering device, with how many you carry. For one that is not listed, type `/flatui cooldown add item` and its name.

Spells come first on the row. Trinkets, gear, potions and items keep their places after them.

### Changing the order

**Move a spell left** and **Move a spell right** move a picked spell one place earlier or later on its own row, past the next icon that really shows there. Its own ready sound and its row go with it.

- Both lists show each spell's place, as "2. Recklessness" or "1. Death Wish (row 2)".
- A spell the character has not learned yet reads "(not known)" with no number, and keeps its place.
- A line says what happened: "Recklessness is now number 1 of row 1.", or "Recklessness is first on its row already."
- The row lays out again at once out of a fight. In a fight it waits for the fight to end.

### Size, layout and when the row shows

The rows under **Icons** set the look of row 1:

- **Icon size** (48), **Spacing** (0) and **Icons per row** (12). After that many icons the row goes on in a new line, below or above as **Extra rows** says.
- **Row direction** sets where the row grows from: **From the middle**, **Left to right** or **Right to left**.
- **Icon crop** trims the edge of each icon. **Icon border** off also removes the dark background.
- **Time left** shows the seconds left on each cooldown.
- **Dim on cooldown** (off) darkens and greys out an icon while it cools down, as the **States and text** tab sets.
- **When the row shows**: **Always**, **In combat**, **Out of combat**, **In a group**, **In a dungeon or raid** or **Not mounted**.
- **Hide while mounted** and **Hide in cities and inns** (both off) hide every row while you ride or rest.
- **Tooltips on icons**: **Off** (the default), **Out of combat only** or **On**. With tooltips, the icons catch the mouse, but clicks still go through to the world.

The **Position** row, in the section of the same name, puts row 1 in the **Middle of the screen**, **Under the personal resource display**, **Under the player frame** or **Under the target frame**. Under a frame, **Left to right** starts at its left edge and **Right to left** ends at its right edge. **X offset** and **Y offset** move the row from there. You can also drag the **Cooldown icons** box in `/flatui move`.

### Ready sound

Under **Ready again**, **Sound** (**Raid warning** by default) plays as the cooldown of an icon ends. Pick **None** for silence.

**Sound of one icon** gives one icon a sound of its own: choose the icon, then open the list again for its sound. An icon without one plays **Sound**. In chat, `/flatui cooldown sound <spell> bell` does the same, and `row` gives the icon back the row's sound.

### Cooldown manager

**Cooldown manager icons** (on) gives the game's own cooldown manager square icons with a thin border.

### States and text tab

This tab sets how an icon looks in each state. Its rows apply to every row of icons.

Under **On cooldown**, **Grey out on cooldown** (on) and **Darkness on cooldown** (40%) apply while **Dim on cooldown** is on.

Under **Range and power**, both rows are on by default:

- **Tint when out of range** turns a spell **Out of range colour** (red) while your target is out of its range.
- **Tint without enough power** turns a spell **Not enough power colour** (blue) while you lack the mana, rage or energy for it.

Under **Opacity**, three rows fade icons on cooldown, ready icons or the whole row out of combat. **Opacity when ready** at 0% hides ready icons, and the row keeps its spacing.

**When one icon shows**, also under **Opacity**, gives one icon a rule of its own: as its row, only on cooldown, only when ready, or with a border while it cools down, in **Border on cooldown colour**. Choose the icon, then open the list again. A hidden icon keeps its place. This suits a long cooldown you only want to see once it is ready.

Under **Border**, these rows tell ready from cooling:

- **Border colour by state** (off) colours the border by state: green while ready and red while cooling, at first. It needs **Icon border**.
- **Flash when ready** (on) flashes the icon as its cooldown ends.
- **Glow on your interrupt** (on) puts a gold border on the icon of your class interrupt while your target or focus casts something you can interrupt and the interrupt is ready.

Under **Glow and buff time**:

- **Glow when ready** (on) puts a pulsing border round an icon from the end of its cooldown until you use it again.
- **Glow on procs** (on) makes a spell's icon glow while a proc alert for it is up, in the **Glow style** of the **Proc alerts** tab (see Trackers below).
- **Buff time on icons** (on) shows how long the buff a spell or trinket gave you has left, in **Buff time colour**. Nothing shows for a buff the game hides in a fight.

Under **Numbers and sweep**, the rows set the countdown's size, colour and place, the sweep's colour and opacity, an optional **Edge line**, and the counts on an icon:

- **Tenths below** shows tenths of a second under that many seconds (0, never).
- **Show the global cooldown** (off) runs the sweep for the global cooldown too, while dimming, the flash and the ready sound still leave it out.
- **Reagent counts** (on) shows the count the game shows on an action button for a spell that uses a reagent, such as Vanish or Rebirth.
- With **Count corner** at **Top right**, the keybind moves to the top left.

Under **Keybind**, **Keybind on icons** (off) shows the key bound to the spell on your action bars. It reads short (M4, N1) while **Hotkey text** of the action bars is **Short (M4, WU, N1, Sp)**, as it is at first.

### Rows 2 to 4 tab

Up to three more rows can hold icons of their own, each with its own place, size and direction. Each row is off until you switch it on.

1. Turn on **Show row 2**, **Show row 3** or **Show row 4**.
2. In **Row of one icon**, choose an icon, then open the list again and pick its row. The icons of a row that is off stay on row 1.
3. Set the row's **When it shows**, **Position**, **X offset**, **Y offset**, **Icon size** (36) and **Row direction**.

Otherwise a row has the look of row 1. It can show only in combat, out of it, in a group, in a dungeon or raid or when not mounted, and can hang under the player or target frame. Each row has its own box in `/flatui move`: **Cooldown icons: row 2**, **Cooldown icons: row 3** and **Cooldown icons: row 4**.

### Seeing a new look

Out of combat, with the options window open and test mode off, changing a row of the look shows every row in the new look for 4 seconds. This covers **Icon size**, **Spacing**, **Icons per row**, **Row direction**, **Extra rows**, **Icon crop**, **Icon border**, **Time left**, **Dim on cooldown**, any row of **States and text**, and the **Position**, **Icon size** and **Row direction** of rows 2 to 4.

- The icons sweep for 6 to 15 seconds each. The first icon is ready, with its glow. A row with no icons gets three samples.
- The samples show what the **States and text** rows do, each while its row is on: the second icon is in **Out of range colour**, the third is in **Not enough power colour** with a count of 5, and the icons carry the keys 1, 2 and 3.
- On every row, the second icon carries a sample buff time (8 of 12 seconds left) while **Buff time on icons** is on, and the third glows while **Glow on procs** is on.
- A dragged slider keeps them up until 4 seconds after its last step. Then your real icons come back, with no flash and no ready sound.

In test mode every row shows, with sweeps that loop. An empty row gets three samples, one icon stays ready, and your interrupt is ringed in gold.

### Cooldown pulse tab

**Cooldown pulse** (on) fades in the icon of a spell, trinket or item in the middle of the screen as its cooldown ends, so you see it is ready without watching the row. It works for any spell of your spell book, a trinket you wear or an item you use, whether or not it is on the cooldown row.

**What pulses**

- **Shortest cooldown** (5 s): a shorter cooldown does not pulse, nor does the global cooldown.
- **Your pet's abilities** (off) pulses your pet's abilities too, such as Spell Lock, Seduction, Sacrifice or Dash. A pet casts some of these on its own, which then pulse each time; leave those out with **Leave out**.
- **Leave out** stops one spell or item from pulsing, a spell with all its ranks. **Put back** lets it pulse again.

**Look**

- **Icon size** (72) and **How long it shows** (1 s). Cooldowns that end together pulse one after another.
- **Opacity** (70%) sets how solid a pulse is at its brightest.
- **Sound** (**None** by default) plays with each pulse. **Sound of one spell or item** gives one a sound of its own.
- **Name under the icon** (on) shows the name as it fades. An item's name is in its quality's colour.
- **Grow as it fades** (off) swells the icon by a quarter as it fades out.

**Spots**

**Pulse spots** (**One**, **Two** or **Three**) lets pulses show at up to three places. Each spot has its own box in `/flatui move` (**Cooldown pulse**, **Cooldown pulse, spot 2** and **Cooldown pulse, spot 3**) and pulses on its own. **Icon size** is the size at spot 1, and **Icon size at spot 2** and **Icon size at spot 3** set the others. **Spot of one spell or item** sends one to a spot of its own; one without it pulses at spot 1.

Out of combat, changing **Icon size**, **How long it shows**, **Opacity**, **Sound**, **Name under the icon**, **Grow as it fades** or **Pulse spots** shows a test pulse at each spot in use, in the new look. A **Sound** you pick plays with it. With two or three spots, each spot's test pulse shows another of your watched spells, named as "Spot 2: Frost Nova", so you can tell the spots apart. A pick in **Sound of one spell or item** or **Spot of one spell or item** pulses that one's own icon at its spot, with its own sound.

### Cooldown commands

| Command | What it does |
| --- | --- |
| `/flatui cooldown add <spell>` | Adds a spell to the row: a spell ID, a name or a shift-clicked spell |
| `/flatui cooldown remove <spell>` | Takes a spell off the row |
| `/flatui cooldown add healthstone` | Adds your healthstones, every rank as one icon. `healing` and `mana` do the same for potions |
| `/flatui cooldown add item <item>` | Adds an item with a use (an ID, a link or a name). `remove item` takes it off |
| `/flatui cooldown import 1` | Adds the spells with a cooldown on action bar 1 (2 to 8 likewise) |
| `/flatui cooldown sound <spell> bell` | Gives one icon its own ready sound: `none`, `spell`, `chimes`, `bell`, `warhorn`, `raid`, `alarm` or `whisper`. `row` gives back the row's sound |
| `/flatui cooldown list` | Lists what is on the row |
| `/flatui pulse test` | Shows a pulse at each spot in use |
| `/flatui pulse ignore <spell or item>` | Leaves one out. `/flatui pulse watch` puts it back |
| `/flatui pulse sound <spell or item> bell` | Gives one its own pulse sound. `none` silences it, and `page` gives it the page's sound again |
| `/flatui pulse spot <spell or item> 2` | Sends one to pulse spot 2. `1` puts it back |
| `/flatui pulse list` | Says what pulses, what is left out, and the own sounds and spots |

## Trackers

The **Trackers** page shows small icons, bars or text for what you must keep up: buffs on you, your debuffs on the target, weapon enchants, totems, your pet, items, ammunition, minimap tracking, your stance or form, durability and your class buff on the group. **Trackers** at the top turns them on or off (on by default).

By default a tracker shows only when it is low or missing. A low tracker is amber: its rim, count, countdown and bar. A missing one is red. So "renew soon" reads apart from "gone".

The list belongs to the character, and holds up to 40 trackers. The page has five tabs: **General**, **Look and position**, **Low and missing**, **Proc alerts** and **Edit a tracker**.

### Adding trackers

Use the rows under **List** on the **General** tab:

- **Add a buff** adds a buff on you. For one that is not listed, type `/flatui tracker add` and its name, spell ID or a shift-clicked spell.
- **Add a debuff on the target** adds your own debuff on your current target. For one that is not listed, type `/flatui tracker add debuff` and its name.
- **Add an item** adds an item in your bags. For an item you have none of, type `/flatui tracker add item` and its name.
- **Add a check** lists the other kinds: the enchant on your main hand, off hand or ranged weapon (a shaman's imbue, a rogue's poison, a sharpening stone or an oil), a fire, earth, water or air totem, your pet, ammunition, minimap tracking, durability, and each group buff you know.
- **Add a stance or form** adds a stance or form.
- **Add class trackers** (it names your class, as Add Warrior trackers) adds the usual trackers of your class, one at a time or all at once. A buff, stance, form or totem is added only when you know its spell, and an item only when it is in your bags. `/flatui tracker class` adds them all.

Adding a tracker out of combat shows the whole row as samples for 4 seconds, with the new tracker in its place.

### What each kind watches

- A buff, debuff or weapon enchant tracker is low by its charges or time left, as the **Low and missing** tab sets, and red when it is gone.
- A pet tracker is red while your pet is gone or dead. It shows the pet's health in red while it is under **Pet health minimum**, and is low while your pet is set to Passive, as **Pet on passive counts as low** says.
- A group buff tracker counts who in your group lacks your class buff, as 2/5 on its icon. `/flatui tracker add group` adds it.
- The ammunition tracker is low at **Ammunition minimum** arrows or bullets, or **Thrown weapon minimum** for a thrown weapon. A thrown weapon that wears out is low at a fifth of its durability.
- The tracking tracker is red while no minimap tracking is on.
- A stance or form tracker is red while you are in none of them.
- The durability tracker follows your most worn item. It is low at **Durability minimum** and red while an item is broken.
- A totem tracker watches one totem slot.

### When trackers show

**Show**, under **When shown**, sets when a tracker shows: **Always**, **Only when low or missing** (the default) or **Only in combat**. A tracker set to show only when low or missing fades in and out.

These rows apply to the trackers set to **Only when low or missing**:

- **Hide while mounted or flying** (on) hides them while you ride, and on a flight path until you land.
- **Hide in cities and inns** (off) hides them while you rest.
- **Hide in combat** (off) shows a low or missing tracker only between fights.
- **Hide outside dungeons and raids** (off) keeps them empty in the open world. They come up as you zone into a dungeon or raid.

### Ready checks and pull countdowns

**Show at a ready check or pull countdown** (on) brings up every low or missing tracker while a ready check is open, or from a player's pull countdown until the pull (30 seconds at most). They show even while mounted, in a city, outside dungeons and raids or with **Only in combat**. At a ready check they stay up until it finishes or times out, and for 12 seconds at least, so an all-ready still leaves time to fix things.

A moment later, one chat line names them:

- "Flat UI: for the ready check, Arcane Brilliance is missing on 2 of 5 (Eli, Mara) and Durability is low (35%)."
- "Flat UI: before Ivo's pull, Mana Gem is low."

A group buff says how many lack it, and who, in class colours, when 3 or fewer do. Durability shows its percentage, and also counts as low at 40% or less until the pull. With every tracker fine there is no line. A cancelled countdown hides the trackers again, and the pull hands them back to their usual rules at once.

### In fights

The game hides your buffs in a fight. With **Game's own icon in fights** on, a tracker uses the game's own icon in a fight. While it is off, as it is at first, a tracker's charges and time left stop updating in a fight. **In fights without the game's icon** sets what a tracker shows then: **Last known** (the default) or **Hidden**.

A tracker you fix, by casting the buff, restocking or putting a poison back on, flashes green for a moment and stays up that long before it fades. This works out of combat, and in fights for weapon enchants, items and ammunition.

### Marking action buttons

**Mark action buttons** (off), under **Action buttons**, puts a border on the action button that fixes a tracker: amber while it is low, red while it is missing. A button that two trackers share stays marked while either is low or missing, and red while either is missing. It needs **Restyle action bars**.

### Clicks that fix a tracker

**Click to apply**, under **Clicks**, lets a click on a tracker fix it, out of combat only. At **Buffs, forms, pet, conjuring and tracking** (the default), a click:

- casts your buff, stance or form
- calls your pet, revives it or sets it to fight
- casts a group buff on a member who lacks it
- conjures a missing or low mana gem, water, food, Healthstone or Soulstone with the best spell you know for it
- casts the minimap tracking you last had on, such as Find Herbs or Track Beasts.

The tooltip says what a click does ("A click casts Conjure Mana Ruby."), or that you lack the reagent. An item no spell makes, such as an Ankh, takes no click.

**Buffs, forms, pet, conjuring, tracking and weapons** also puts a poison, stone or oil on a weapon, or casts a shaman's weapon imbue. **Item a click puts on a weapon** sets what goes on each weapon: choose a weapon tracker, then open the list again. **Off** turns clicks off.

### Tracker tooltips

**Tracker tooltips** sets when the mouse over a tracker shows a tooltip: **On**, **Out of combat only** (the default) or **Off**. The tooltip shows:

- the tracker's name, and whether it is up, low or missing, in green, amber or red
- its time left and charges
- a dim line with what counts as low, such as "Low at 2 charges or fewer or under 5:00 left", "Low under 5 in your bags" or "Low at 200 or fewer"
- for a group buff, who lacks it, in class colours.

A click still goes through to the world, except on a tracker that a click can fix. A tracker you cannot see has no tooltip and lets the mouse through. Settings on the **Tooltips** page do not change this tooltip.

### Look and position tab

**Shape**

- **Shape** draws each tracker as an **Icon** (the default), a **Bar** or **Text**. Icons take **Icon size**; bars and text take **Bar width** and **Bar height**, in **Colour**.
- **Bar fill** fills a bar by **Charges** or **Time left**. A buff without charges fills by time left.
- **Charges**, **Name** (on bars and text) and **Time left** choose what each tracker shows.
- **Row direction** lays the trackers out **From the middle**, **Left to right**, **Right to left**, **Column, downward** or **Column, upward**. A column stacks them under each other, left-aligned, as timer bars usually are.
- **Close up the gaps** (off) lets a hidden tracker take no room, so the ones that show sit together, centred or from the start as **Row direction** says. In a fight nothing moves: the row keeps the places it had when the fight began, and a tracker that shows there takes a place after them.

**Position**

- **Place**: **Personal resource display**, **Beside the character** or **Own position** (the default). For **Own position**, drag the **Trackers** box in `/flatui move`.
- **Side of the personal resource display**: **Above** or **Below**.
- **X offset** and **Y offset** move the trackers from their place.

Out of combat, changing a row of this tab shows every tracker that is on, at full opacity, as its sample (20 charges, 10:00) in the new look, until 4 seconds after the last change. A slider drag keeps them up. The procs of your class show in the preview too, at the end of the row.

### Low and missing tab

Under **Amounts**, 0 means never for each row:

- **Item minimum** (1): an item tracker is low when the bags hold fewer.
- **Ammunition minimum** (200) and **Thrown weapon minimum** (20) set when ammunition is low. Set to **Only when low or missing**, a low count waits for the end of a fight.
- **Durability minimum** (20%): durability is low when an item you wear is at this much of its durability or less.

Under **Pet**:

- **Pet health minimum** (30%) shows your pet's health in red while it is under this.
- **Pet on passive counts as low** (on) marks your pet low while it is out and set to Passive, when it does not fight for you.
- **Pet on defensive counts as low** (off) does the same for Defensive. With it on, a click sets your pet to Assist.

Under **Low**:

- **Low at (charges)** and **Low at (seconds left)** (both 0, never) set when a buff counts as low. Seconds go up to 30 minutes, so you can be warned well ahead of a long buff or poison.
- **Low in dungeons and raids (seconds left)** (120 s) warns earlier in a dungeon or raid. It applies to a buff or weapon enchant that lasts 10 minutes or more, and uses the larger of this and **Low at (seconds left)**. In a fight, a tracker set to **Only when low or missing** still hides while its buff is up, so the warning shows between pulls.

Under **Missing**:

- **When missing**: **Red icon** (the default), **Red icon that pulses** or **Red icon and the word Missing**. Out of combat, a change shows every tracker as missing for a few seconds.
- **Sound when it drops** (on) plays as a tracked buff ends.
- **Sound when it comes** and **Sound when it stacks** (both off) play as a buff or debuff comes back or gains a stack.
- **Sound when it turns low** (off) plays once as a tracker goes from fine to low. The game hides buffs in a fight, so a buff turns low by sound between fights.
- **Sound** (**Raid warning** by default) is the sound they all use. Out of combat, a pick plays it once.

### Proc alerts tab

Proc alerts show the moment a proc of yours is up, such as Overpower after a dodge, Revenge or Execute. You get the game's own spell alert art beside your character and, if you like, a glow on the action button. Proc alerts belong to the trackers, so they need **Trackers** on.

![Flat UI in play](https://raw.githubusercontent.com/dismlx/flat-ui/main/media/flatui-in-play.jpg)

**Which procs**

- **Procs of your class** (on) shows every proc of your class whose spell you know, without adding it.
- **Add a proc** adds another one. For a spell that is not listed, type `/flatui tracker add proc`, the buff, `for` and the spell it is for, as `/flatui tracker add proc Shadow Trance for Shadow Bolt`. A proc you add keeps its own colour, time and sound.
- **Remove a proc** also lists the procs of your class. One you remove stays off for this character. **Bring back a proc** shows it again.
- **Colour** (gold) is the border of a proc alert, and the plain arc of a proc with no art of its own. `/flatui tracker proc colour 1 ffd100` gives a proc you added, here number 1 in `/flatui tracker list`, its own colour, which also tints its art.
- **Sound** (**Spell alert** by default) plays as a proc comes up.

**Art beside the character**

- **Art beside the character** (on) draws the game's own art beside your character while a proc is up, larger and fainter than the game draws it by default.
- **Art size** (150%) sets its size; 100% is the game's size.
- **Art opacity** (40%) sets how solid it is; 65% is the game's. The game's Spell Alert Opacity has no effect here.
- **Art height** (0) raises or lowers it.
- The **Proc art** box in `/flatui move` puts the art anywhere. It sits in the middle of the screen until you move it.

**Glow**

- **Glow on the action button** (off) puts a glow on the button that casts the spell the proc is for, and a border in the proc's colour, which needs **Restyle action bars**. The glow eases out over about 0.2 seconds as the proc is used or runs out.
- **Glow style**: **Soft** (the default) is a faint glow that hugs the button's edge and breathes slowly, with a slow, gentle pulse of the art. **As the game has it** is the game's burst and loop, which lie over the buttons beside it, and the game's own pulse and fade-in of the art. With **Art size** at 100% and **Art opacity** at 65%, it is the game's whole look. The art and **Glow on procs** of the cooldown icons follow this row, with or without **Glow on the action button**.
- **Seconds left on the button** (on, with **Glow on the action button**) counts down the seconds left of a proc with a time, such as Overpower, Revenge, Riposte or Mongoose Bite, in a small number on its glowing button in the proc's colour. It takes the **Hotkey size** and **Button text outline** of the **Button text** page, and sits in a corner the hotkey, macro name and count leave free. For its last 2 seconds the number turns white and grows a little. Execute and other procs with no time show none.

With the options window open, out of a fight and test mode off, a change of **Art beside the character**, **Art size**, **Art opacity**, **Art height**, **Glow on the action button**, **Glow style**, **Seconds left on the button** or **Colour** shows your class's first proc for 4 seconds in the new look, with no sound.

The **Fading** page can bring a faded action bar back to full while a proc is up for one of its buttons; see [Layout](Layout).

### Edit a tracker tab

Choose a tracker in **Tracker**, then give it a **Name** and settings of its own. The rows are those of the other tabs, for this tracker only: **On**, **Spell IDs** (a buff tracker only), **Shape**, **Place**, **Show**, **Low at (charges)**, **Low at (seconds left)**, **When missing**, the four sound rows, **Sound**, **Colour**, **Icon size**, **X offset**, **Y offset** and **Mark action buttons**. A row is dimmed while it follows the page.

- **Move up** and **Move down** change the tracker's place in the row.
- **Clear own settings** makes it follow the pages again.
- **Remove** takes it off, after asking.

Out of combat, a change of **Shape**, **Icon size**, **Colour**, **Place**, **X offset**, **Y offset** or **When missing** shows that one tracker as a sample.

### Removing, bringing back and sharing

**Remove a tracker**, on the **General** tab, takes one off. Out of combat, the row shows as samples for 4 seconds without it.

**Bring back a tracker** puts back one of the last five trackers you removed since you logged in or reloaded, in its old place with its own settings. `/flatui tracker back` brings back the last one.

To share trackers, use **Export trackers** and **Import trackers** under **Share** on the **Profiles** page. `/flatui tracker export` and `/flatui tracker import` open it. See [Profiles](Profiles).

### Checking your trackers

- Test mode steps each tracker through fine, low and missing, whatever its **Show** rule, and shows your class's first proc alert with its art and glow.
- `/flatui tracker test` shows each look for 3 seconds: fine, low, missing, then the game's own look. A pull ends it at once, with the line "Trackers: the pull ended the test."
- Over a sample, the tooltip says what the sample shows, such as "Sample: Low, 0:18 left, 2 charges".
- `/flatui tracker check` says what each tracker shows and why, and what happened in the last fight.

### Tracker commands

| Command | What it does |
| --- | --- |
| `/flatui tracker add <buff>` | A buff on you, by name, spell ID or shift-clicked spell |
| `/flatui tracker add debuff <spell>` | Your own debuff on your target |
| `/flatui tracker add item <item>` | An item in your bags, by name, item ID or shift-clicked item |
| `/flatui tracker add weapon main` | The enchant on a weapon: `main`, `off` or `ranged` |
| `/flatui tracker add totem fire` | A totem slot: `fire`, `earth`, `water` or `air` |
| `/flatui tracker add pet` | Your pet, red when it is gone or dead |
| `/flatui tracker add ammo` | The ammunition you carry |
| `/flatui tracker add tracking` | Red when no minimap tracking is on |
| `/flatui tracker add form <stance or form>` | Red when you are in none of them |
| `/flatui tracker add durability` | Your most worn item, red when one is broken |
| `/flatui tracker add group` | Your class buff on your group |
| `/flatui tracker add proc <buff> for <spell>` | A proc alert: its buff, then the spell it is for |
| `/flatui tracker class` | Adds the usual trackers of your class |
| `/flatui tracker remove 1` | Removes a tracker, by its number in the list or its name |
| `/flatui tracker back` | Puts the tracker you last removed back, with its own settings |
| `/flatui tracker list` | Lists your trackers with their numbers |
| `/flatui tracker set 1 low 2` | Gives tracker 1 its own value for a setting. `clear` makes it follow the page |
| `/flatui tracker set 1 shape bar` | `icon`, `bar` or `text`, and `colour 4d99e6` for a bar or text |
| `/flatui tracker set 3 kit bell` | Gives tracker 3 a sound of its own |
| `/flatui tracker set 1 health 40` | A pet tracker shows your pet's health in red under 40% |
| `/flatui tracker set 1 happy on` | A pet tracker is low while a hunter's pet is not happy |
| `/flatui tracker use 2 <item>` | Sets what weapon tracker 2 puts on its weapon with a click |
| `/flatui tracker proc colour 1 ffd100` | One added proc's colour. `proc time 1 10` sets its time |
| `/flatui tracker export` | Opens **Share**, to copy every tracker as text. `import` opens it to paste trackers |
| `/flatui tracker test` | Each look for 3 seconds: fine, low, missing, then the game's own look |
| `/flatui tracker check` | What each tracker shows and why, and what happened in the last fight |

## Defensives on you

The **Defensives on you** page (on by default) shows a row of icons for the shields, wards and protections other players cast on you, such as Pain Suppression, Blessing of Protection or Power Word: Shield. Each icon has its time left and the caster's name in their class colour. The time left turns amber in its last 5 seconds.

### Where the row sits

- **Place**: **Above the player frame**, **At the personal resource display** (the default), **Own position** or **Off**. **Own position** has its own box, **Defensives on you**, in `/flatui move`.
- **X offset** and **Y offset** (0) move the row from where **Place** puts it, above the player frame or at the personal resource display.

### Look

- **Icon size** (32). The time left and the charges on an icon grow and shrink with it.
- **Spacing** (3), **Caster's name** (on) and **Icon border** (on).
- **Buff tooltips** shows the game's own tooltip over each icon: **On** (the default), **Out of combat only** or **Off**. A click still goes through to the world. Settings on the **Tooltips** page do not change this tooltip.
- **Your own defensives** (on) also shows the ones you cast on yourself, such as Shield Wall or Ice Barrier.

### Sounds and flash

- **Sound when one lands** (**None** by default; **Raid warning**, **Alarm** or **Whisper warning**) plays once as a listed defensive from someone else comes on you.
- **Sound when one ends** (**None** by default, the same three sounds) plays once as one leaves you, so you hear Blessing of Protection or Pain Suppression drop.
- The game plays both sounds, so they work in a fight too. Spells you know yourself are left out, so a priest's own Power Word: Shield stays silent.
- **Flash when one lands** (on) gives each icon a quick white flash as it lands. The game draws it, so it works in a fight too.

### Which spells

**Add a spell** and **Remove a spell**, under **Spells**, change the list. For a buff that is not listed, type `/flatui defensives add` and its spell ID.

### Seeing it

Out of combat with no defensive on you, changing **Place**, **X offset**, **Y offset**, **Icon size**, **Spacing**, **Caster's name**, **Icon border** or **Flash when one lands** shows sample icons where the row now sits, for about 4 seconds. Picking a sound plays it and shows the samples landing.

`/flatui test icons` shows three sample icons for 8 seconds, out of combat only. They flash as they appear, play **Sound when one lands**, and **Sound when one ends** as they go. A chat line names each sound and whether the game played it: "Sound when one lands: Raid warning, played." A pull ends the samples at once: "Defensives on you: the pull ended the test."

### Defensives commands

| Command | What it does |
| --- | --- |
| `/flatui test icons` | Three sample icons for 8 seconds on **Defensives on you**, **Your buffs**, **Party cooldowns** and **Enemy cooldowns** |
| `/flatui defensives add 10060` | Adds a buff, by spell ID or shift-clicked spell |
| `/flatui defensives remove <spell>` | Removes one, by spell ID or name |
| `/flatui defensives list` | Lists the listed defensives with their spell IDs |

**Your buffs** is a tab of the **Personal resource display** page; see [Frames and bars](Frames-and-bars). **Party cooldowns** is in the **Group** group; see [Group](Group).

## Absorb shields

The **Absorb shields** page (on by default) shows the shields on you as bars. You get the total of every absorb on you, and a bar for each Power Word: Shield, Ice Barrier, Mana Shield, Fire, Frost or Shadow Ward, Sacrifice, protection potion or item. Each bar has the shield's icon, the amount it has left, its time left and the colour of the school it takes. Nothing shows while no shield is up.

As damage eats a shield, its bar and the total bar glide down over about a quarter of a second, so you see each hit take it. In a fight, while the game hides your buffs, the total keeps its live amount and each shield shows its time, filling by it.

### Bars

- **Show**: **The total and each shield** (the default), **The total only** or **Each shield only**.
- **Total bar is full at**: **Your shields** (the default: the size of the shields on you, as far as Flat UI knows it) or **Your health** (the shield as a share of your health).
- **Bar height** is also the size of the icon and the text. **Bars grow** sets whether the bars stack **Down** or **Up** from the top or the bottom of the **Absorb shields** box in `/flatui move`.
- **Time strip** (off) adds a thin bar along the foot of each shield that runs down with its time.

### Text

- **Amount** shows **Amount left** (the default), **Amount left and size** or **None**. The size of a shield is the most it held as Flat UI read it, or for your own shield what Flat UI works out from your spell power.
- **Time left** (on) turns amber in its last 5 seconds. **Spell name** (off) adds the shield's name.
- **Bar tooltips** (**On** by default) shows, over a shield's bar, the game's tooltip of its buff with what it has left, and over the total bar, each shield on you with its amount and time left. A click still goes through to the world.

### Colour

**Colour by school** (on) draws a shield that takes one school in its colour: Fire Ward orange, Frost Ward light blue, Shadow Ward violet and Mana Shield grey. A shield that takes every school, and the total, are in **Shield colour**.

### Which shields

**Priest shields**, **Mage shields**, **Warlock shields**, **Protection potions** and **Items** are all on:

- **Priest shields**: Power Word: Shield and Contingency Plan.
- **Mage shields**: Ice Barrier, Mana Shield, Fire Ward and Frost Ward, also those a mage casts on you.
- **Warlock shields**: Shadow Ward and a voidwalker's Sacrifice.
- **Protection potions**: Fire, Frost, Nature, Shadow, Holy and Arcane Protection, and the greater ones.
- **Items**: items whose use absorbs damage, such as the Gnomish Harm Prevention Belt.

**Add a spell** and **Remove a spell** change the list. For a shield that is not listed, type `/flatui absorbs add` and its spell ID. Every absorb counts in the total all the same.

### When a shield breaks

Under **When a shield breaks**, **Sound** (**None** by default) plays when a shield goes before its time is up, and the bars flash red. It works only while the game shows your buffs; in a fight it may hide them. Out of combat, a pick plays it once and flashes the bars, so you know the warning before a shield breaks.

### Your target

**Your target's total** (off) adds a bar with the total of every absorb on your target. It has its own box, **Absorb shields: target**, in `/flatui move`. Out of combat, turning it on shows sample bars for a few seconds, so you see where it sits with nothing targeted.

### Seeing it

Out of combat with no shield up, changing a row of the look shows sample bars in the new look for about 4 seconds. Picking a sound with no shield up shows them and flashes them red.

`/flatui absorbs test` shows sample bars for a few seconds, out of combat only. The samples include your target's bar (640 of 2400) while **Your target's total** is on. A pull takes any sample away at once, so your real shields show. Test mode shows a Power Word: Shield and a Fire Ward whose times loop, and their total.

The **Personal resource display** page can also lay your shields over its health bar; see [Frames and bars](Frames-and-bars).

### Absorb commands

| Command | What it does |
| --- | --- |
| `/flatui absorbs test` | Sample bars for a few seconds, out of combat |
| `/flatui absorbs check` | The amount, time and secrecy of each shield on you |
| `/flatui absorbs add 17` | Adds a shield, by spell ID or shift-clicked spell |
| `/flatui absorbs remove 17` | Removes one, by spell ID or name |
| `/flatui absorbs list` | Lists the listed shields with their spell IDs |

## Charges

The **Charges** page (on by default) shows your own buffs that have charges as a row of glowing gems, like the game's own class resources: combo points, arcane charges, chi or holy power. Each charge is a gem in a socket: lit gems are the charges left, and empty sockets the ones used. The spell's name sits small above the left end of the row, the charges left as a large number at its right end, and the time left small above its right end, all outlined. The row sits just under the bars of the personal resource display, the width of the bars, stays while the buff is up and fades out as it leaves you.

It covers Lightning Shield, Water Shield, Earth Shield, Inner Fire, Shadowguard and Holy Shield, the stacks of a shaman's Maelstrom Weapon, and any buff with more than one charge that you add yourself.

### The gems of each spell

Each spell has the game's resource art that suits it, in its own colour:

- Lightning Shield: the blue charged combo points, electric blue.
- Water Shield: the chi orbs, tinted sea green.
- Earth Shield: the druid's combo points, tinted earthy green.
- Maelstrom Weapon: the arcane charges, tinted electric blue white.
- Inner Fire: the druid's combo points, tinted gold.
- Shadowguard: the arcane charges, violet.
- Holy Shield: the holy power runes, warm gold.
- A spell you added: the charged combo points in your class colour.

Where the game lacks a piece of that art, the next set fills in for it, and then Flat UI's own soft glow and ring, so the row always draws.

### How the gems move

- As a charge goes, its gem plays the game's fade of a spent resource with a quick white flash, with **Burst as a charge goes** (on).
- As you cast the buff again, or it gains charges or stacks, the gems light in turn, each with a short glow.
- On the last charge, the last gem pulses.
- There are as many gems as the most charges the buff has had since you cast it, at most 10. Maelstrom Weapon keeps as many as the most stacks it has had, at most 10, and lights one more with each stack.
- With **Show used charges** (on), each charge you use stays as an empty socket. Off, only the charges left show.
- Two buffs at once, such as a shaman's Lightning Shield and Maelstrom Weapon, sit one above the other.

### Look

- **Orb style**: **Resource bar** (the default), **Spell art**, **Ring round the icon**, **Arc over the icon** or **Row under the icon**.
- **Spell art** shows the game's own spell alert art for the buff, Maelstrom Weapon's for now, fainter on one charge and brighter with each one, with the count, time and name under it. A buff without such art, such as Lightning Shield, shows the resource bar.
- **Fill the width** (on) stretches the sockets to share the width of the bars; the gems keep their shape. Off, square gems sit centred. At its own spot the row keeps square gems.
- **Gem size** (20 px) sets the height of each gem, 3 px apart. The text grows and shrinks with it.
- **Name**, **Count** and **Time left** (all on) choose the text. The time turns amber in its last 10 seconds. With **Count** off, the number shows only past 10 charges.
- **Colour**: the **Spell's own colour** (the default, as listed above), your **Class colour**, or **One colour**, set with **Orb colour**. Class colour and One colour tint the gems.

The ring, arc and row of orbs round the icon stay as choices. Their orbs sit close round the middle, and **Spell icon** (off) shows the round spell icon there; without it the orbs ring the count. **Spin** (**Slow** by default, or **Still** or **Fast**) turns the ring, or sways the orbs of an arc or a row, and **Icon size** (40 px) and **Orb size** (12 px) set their sizes.

### Where it sits

**Place** puts the row **Under the personal resource display** (the default), **Above the personal resource display**, or at its **Own spot**. Under or above, it sits just clear of the bars, past a **Your buffs** row on that side, and follows them. While that display is off or hidden, the row goes to its own spot, the **Charges** box of `/flatui move`, under the middle of the screen until you move it.

### When it shows

**Only in combat** and **Hide while mounted** (both off) hide it at those times. **Sound when the last charge goes** (**None** by default) plays as such a buff leaves you on its last charge before its time is up; Maelstrom Weapon, which you spend on purpose, plays none.

In a fight, while the game hides your buffs, the game itself lights the gems and writes the count and time left. The glows, fades and pulse come back once it shows your buffs again.

### Which spells

**Add a spell** offers the buffs on you now with more than one charge, and the class spells you took off. **Take a spell off** removes one. You can also type `/flatui charges add` and a name, spell ID or shift-clicked spell.

### Seeing it

Test mode, a change of its look out of combat, and `/flatui charges` show a sample in the look you chose: Lightning Shield with 3 charges, one used every 2 seconds, then cast again, or with **Spell art**, Maelstrom Weapon gaining a stack each second up to 5.

### Charges commands

| Command | What it does |
| --- | --- |
| `/flatui charges` | A sample for 8 seconds in the look you chose, out of combat and while none of its buffs is on you |
| `/flatui charges add Lightning Shield` | Adds a buff with charges, by name, spell ID or shift-clicked spell |
| `/flatui charges remove Lightning Shield` | Takes one off |
| `/flatui charges list` | Lists the buffs it shows |

## Enemy cooldowns

The **Enemy cooldowns** page (on by default) puts icons for the cooldowns of enemy players beside their nameplates, so you see when an enemy has used Ice Block, Divine Shield or Kick, and when it will be back. It can also show bars for your target and focus.

### What Flat UI can see

The game hides enemy casts, and their buffs in a fight. Abilities that give a buff are tracked while you are out of combat, and timers already running stay. With **Show** at **Always, used ones dark**, an icon is bright only while a use of its ability would be seen. The others are dim with a question mark, not shown as ready. `/flatui enemy list` lists the abilities shown and whether their use can be seen where you are.

### Which abilities

- **Interrupts**, **Defensives**, **Crowd control breaks**, **Wards and immunities** and **Offensive cooldowns** are on. **Mobility** is off.
- **Add an ability** adds another one. For a spell that is not listed, type `/flatui enemy add`, the ability and its cooldown in seconds, as `/flatui enemy add Blink 15`.
- **Hide an ability** hides one you do not want.
- **Crowd control break in arenas** (off) shows an enemy's crowd control break on the target and focus bars in an arena, so it needs **Place** at **Both** or **Bars for target and focus**.

### Where the icons show

- **Place**: **On enemy nameplates** (the default), **Bars for target and focus** or **Both**. The bars have their own boxes in `/flatui move`: **Enemy cooldowns: target** and **Enemy cooldowns: focus**.
- **Place on nameplates**: **Right of the health bar** (the default), **Left of the health bar**, **Above the name** or **Below the health bar**. Beside the health bar or above the name, the icons leave room for the game's own icons and stay off the enemy's character. Below the health bar they cover the enemy's character.

### Look

- **Show** sets whether an icon shows **Only while on cooldown** or **Always, used ones dark** (the default).
- **Border colour by kind** (on) gives interrupts, defensives and the others each a border colour of their own. Off, the border has the colour of the **Flat UI** page.
- **Icon tooltips** (**On** by default) work on the target and focus bars; icons on nameplates take no mouse. Pointing at an icon names the ability and the enemy and says Ready or the time left.

### Ready again

- **Flash when ready** (on) flashes the icon white as its cooldown ends.
- **Sound** (**Bell** by default) plays as a cooldown ends, for your target and focus only. Picking one plays it.
- **Shortest cooldown that sounds** (0 s, every cooldown) keeps short cooldowns quiet. At 30 s, a Kick or a Pummel on your target ends without the sound, while Divine Shield, Ice Block or a trinket still ring. The flash still shows for all of them.

### Seeing it

Test mode puts a Kick, an Ice Block and a Divine Shield on the target and focus bars, named in their tooltips, and plays **Sound** once. With **Show** at **Always, used ones dark**, the Kick stays bright and ready, the Ice Block sweeps dark and the Divine Shield is dim with the question mark of a use the game hides.

`/flatui test icons` shows three sample icons that flash and sound at their end, as **Flash when ready** and **Sound** say.

### Enemy cooldown commands

| Command | What it does |
| --- | --- |
| `/flatui enemy add Blink 15` | Adds an ability (a name, a spell ID or a shift-clicked spell) and its cooldown in seconds |
| `/flatui enemy hide 2139` | Hides an ability, by name or spell ID |
| `/flatui enemy list` | The abilities shown, and whether their use can be seen here |
| `/flatui enemy clear` | Forgets the running timers of enemies |
| `/flatui test icons` | Three sample icons on **Enemy cooldowns**, among other pages |

## Combat text

The **Combat text** page places your combat numbers in front of enemy nameplates and sets the scroll areas, colours, friendly units and warnings of combat text. It has its own guide: [Combat text](Combat-text).

Every setting of this group, with its default: [Settings: Combat](Settings-Combat).
