Every setting of the **Combat** group of the options window, 358 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Combat](Combat) and [Combat text](Combat-text).

Pages: [Cooldowns](#cooldowns) · [Trackers](#trackers) · [Defensives on you](#defensives-on-you) · [Absorb shields](#absorb-shields) · [Charges](#charges) · [Enemy cooldowns](#enemy-cooldowns) · [Combat text](#combat-text)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.50.

## Cooldowns

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Cooldown icons** | On |  |

**Spells**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add a spell** |  | For a spell that is not listed, type /flatui cooldown add and its name. |
| **Remove a spell** |  |  |
| **Move a spell left** |  | One place earlier on its own row, past the next icon shown there; spells on other rows and spells not known yet keep their places. The list shows each spell's place, as 2. Recklessness or 1. Death Wish (row 2). Trinkets, gear, potions and items keep their places after the spells. |
| **Move a spell right** |  | One place later on its own row, past the next icon shown there. Its own ready sound and row go with it. |
| **Equipped trinkets** | Off | Adds your two trinket slots after the picked spells. |
| **On-use gear in other slots** | Off | Adds the items you wear in other slots that have a use, such as engineering goggles or boots, after the trinkets. |
| **Add a potion or healthstone** |  | Every rank shares one icon: the best one in your bags that your level allows, with how many you carry. It comes after the spells and trinkets. |
| **Remove a potion or healthstone** |  |  |
| **Add an item** |  | An item in your bags that has a use, such as the Hearthstone, a mana gem or an engineering device, with how many you carry. For one that is not listed, type /flatui cooldown add item and its name. Potions and healthstones have their own row. |
| **Remove an item** |  | Its own ready sound goes with it. |
| **Add the spells of a bar** |  | Adds each spell with a cooldown on that bar that the row does not have yet. Action bar 1 is the one the main bar shows now, such as a warrior's stance bar. Later changes to the bar are not followed. /flatui cooldown import 1 does the same. |

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Icon size** | 48 | The size of the icons of row 1. Rows 2 to 4 have their own. |
| **Spacing** | 0 | The space between icons, on every row. |
| **Icons per row** | 12 | After this many icons a row goes on in a new line, below or above as Extra rows says. |
| **Row direction** | From the middle | Where row 1 grows from as icons are added: its middle, its left end or its right end. Rows 2 to 4 have their own. Choices: From the middle, Left to right, Right to left. |
| **Extra rows** | Below | Where the new lines of a row with more icons than Icons per row go. Choices: Below, Above. |
| **Icon crop** | 8% | Trims the edge of each icon. |
| **Icon border** | On | Off also removes the dark background. |
| **Time left** | On | The seconds left on each icon's cooldown, and on the buff time of Buff time on icons. |
| **Dim on cooldown** | Off | Darkens and greys out an icon while it cools down, as Grey out on cooldown and Darkness on cooldown of the States and text tab say. |
| **Hide while mounted** | Off | Every row is hidden while you ride, and back as you get off. |
| **Hide in cities and inns** | Off | Every row is hidden while you are resting in a city or an inn. |
| **When the row shows** | Always | Row 1, the row of this page. Rows 2 to 4 have their own on the Rows 2 to 4 tab. Hide while mounted, Hide in cities and inns and Row opacity out of combat still apply. Choices: Always, In combat, Out of combat, In a group, In a dungeon or raid, Not mounted. |
| **Tooltips on icons** | Off | With tooltips the icons catch the mouse, but clicks still go through to the world. Choices: Off, Out of combat only, On. |

**Ready again**

| Setting | Default | Notes |
| --- | --- | --- |
| **Sound** | Raid warning | Plays as the cooldown of an icon ends. Sound of one icon gives an icon a sound of its own. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Sound of one icon** |  | Choose an icon, then open the list again for its own sound. An icon without one plays Sound. |

**Position**

| Setting | Default | Notes |
| --- | --- | --- |
| **Position** | Middle of the screen | Under a frame, Left to right starts at its left edge and Right to left ends at its right edge. /flatui move places the row anywhere. Choices: Middle of the screen, Under the personal resource display, Under the player frame, Under the target frame. |
| **X offset** | 0 | Moves row 1 right from its Position, or left below 0. |
| **Y offset** | 0 | Moves row 1 up from its Position, or down below 0. |

**Cooldown manager**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cooldown manager icons** | On | Square icons with a thin border on the game's own cooldown manager. |

### States and text

**On cooldown**

| Setting | Default | Notes |
| --- | --- | --- |
| **Grey out on cooldown** | On |  |
| **Darkness on cooldown** | 40% |  |

**Range and power**

| Setting | Default | Notes |
| --- | --- | --- |
| **Tint when out of range** | On | A spell your target is out of range of, as the game's cooldown manager shows it. |
| **Out of range colour** | #A32626 | Needs **Tint when out of range** on. |
| **Tint without enough power** | On | A spell you lack the mana, rage or energy for. |
| **Not enough power colour** | #8080FF | Needs **Tint without enough power** on. |

**Opacity**

| Setting | Default | Notes |
| --- | --- | --- |
| **Opacity on cooldown** | 100% |  |
| **Opacity when ready** | 100% | 0 hides ready icons. The row keeps its spacing. |
| **Row opacity out of combat** | 100% |  |
| **When one icon shows** |  | Choose an icon, then open the list again: as its row, only on cooldown, only when ready, or with a border while it cools down. A hidden icon keeps its place. |
| **Border on cooldown colour** | #D94040 | For the icons set to Border on cooldown in When one icon shows. |

**Border**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border colour by state** | Off |  |
| **Ready border colour** | #4DBF59 | Needs **Border colour by state** on. |
| **On cooldown border colour** | #D94040 | Needs **Border colour by state** on. |
| **Flash when ready** | On |  |
| **Glow on your interrupt** | On | A gold border on the icon of your class interrupt while your target or focus casts something you can interrupt and the interrupt is ready. |

**Glow and buff time**

| Setting | Default | Notes |
| --- | --- | --- |
| **Glow when ready** | On | A pulsing border round an icon from the end of its cooldown until you use it again. |
| **Ready glow colour** | #FFD133 | Needs **Glow when ready** on. |
| **Glow on procs** | On | A glow on the icon of a spell while a proc alert of the Trackers page for it is up, in the Glow style of that page. |
| **Buff time on icons** | On | While the buff a spell or trinket gives is on you, its icon shows the time the buff has left. Nothing shows for a buff the game hides in a fight. |
| **Buff time colour** | #FFDB40 | Needs **Buff time on icons** on. |

**Numbers and sweep**

| Setting | Default | Notes |
| --- | --- | --- |
| **Countdown number size** | As the game has it | Choices: As the game has it, Small, Normal, Large, Huge. |
| **Cooldown sweep** | On |  |
| **Sweep opacity** | 70% | Needs **Cooldown sweep** on. |
| **Sweep colour** | #000000 | Its opacity is Sweep opacity. Needs **Cooldown sweep** on. |
| **Edge line** | Off | A bright line along the edge of the sweep. |
| **Edge colour** | #FFFFFF | Needs **Edge line** on. |
| **Show the global cooldown** | Off | The sweep also runs for the global cooldown. Dimming, Flash when ready and the ready sound still leave it out. |
| **Countdown colour** | #FFFFFF |  |
| **Countdown place** | Middle | Where the time left sits on the icon. Choices: Middle, Top, Bottom. |
| **Tenths below** | 0 s | Under this many seconds the countdown shows tenths. 0 means never. |
| **Charge count size** | 100% |  |
| **Reagent counts** | On | The count the game shows on an action button for a spell that uses a reagent, such as Vanish or Rebirth. |
| **Count colour** | #FFFFFF | Charges, items carried and reagent counts. |
| **Count corner** | Bottom right | With Top right the keybind moves to the top left. Choices: Bottom right, Bottom left, Top left, Top right. |

**Keybind**

| Setting | Default | Notes |
| --- | --- | --- |
| **Keybind on icons** | Off | The key bound to the spell on your action bars, short (M4, N1) while Hotkey text of the action bars is Short. |
| **Keybind size** | 100% | Needs **Keybind on icons** on. |

### Rows 2 to 4

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Row of one icon** |  | Choose an icon, then open the list again for its row. The icons of a row that is off are on row 1. /flatui move places each row. |

**Row 2**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show row 2** | Off | Its icons come from Row of one icon. It has the looks of row 1, and its own place, size, direction and rule below. |
| **When it shows** | Always | Choices: Always, In combat, Out of combat, In a group, In a dungeon or raid, Not mounted. Needs **Show row 2** on. |
| **Position** | Middle of the screen | Choices: Middle of the screen, Under the personal resource display, Under the player frame, Under the target frame. Needs **Show row 2** on. |
| **X offset** | 0 | Needs **Show row 2** on. |
| **Y offset** | -50 | Needs **Show row 2** on. |
| **Icon size** | 36 | Needs **Show row 2** on. |
| **Row direction** | From the middle | Choices: From the middle, Left to right, Right to left. Needs **Show row 2** on. |

**Row 3**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show row 3** | Off | Its icons come from Row of one icon. It has the looks of row 1, and its own place, size, direction and rule below. |
| **When it shows** | Always | Choices: Always, In combat, Out of combat, In a group, In a dungeon or raid, Not mounted. Needs **Show row 3** on. |
| **Position** | Middle of the screen | Choices: Middle of the screen, Under the personal resource display, Under the player frame, Under the target frame. Needs **Show row 3** on. |
| **X offset** | 0 | Needs **Show row 3** on. |
| **Y offset** | -100 | Needs **Show row 3** on. |
| **Icon size** | 36 | Needs **Show row 3** on. |
| **Row direction** | From the middle | Choices: From the middle, Left to right, Right to left. Needs **Show row 3** on. |

**Row 4**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show row 4** | Off | Its icons come from Row of one icon. It has the looks of row 1, and its own place, size, direction and rule below. |
| **When it shows** | Always | Choices: Always, In combat, Out of combat, In a group, In a dungeon or raid, Not mounted. Needs **Show row 4** on. |
| **Position** | Middle of the screen | Choices: Middle of the screen, Under the personal resource display, Under the player frame, Under the target frame. Needs **Show row 4** on. |
| **X offset** | 0 | Needs **Show row 4** on. |
| **Y offset** | -150 | Needs **Show row 4** on. |
| **Icon size** | 36 | Needs **Show row 4** on. |
| **Row direction** | From the middle | Choices: From the middle, Left to right, Right to left. Needs **Show row 4** on. |

### Cooldown pulse

| Setting | Default | Notes |
| --- | --- | --- |
| **Cooldown pulse** | On | When a spell of your spell book, a trinket you wear or an item you use is ready again, its icon fades in and out in the middle of the screen. /flatui move places it. |

**What pulses**

| Setting | Default | Notes |
| --- | --- | --- |
| **Shortest cooldown** | 5 s | A shorter cooldown does not pulse, nor does the global cooldown. |
| **When it pulses** | Always | In combat only keeps the pulse quiet between fights. Not while mounted or in a city keeps it quiet on a mount, on a flight path and where the game rests you, in a city or an inn. A cooldown that ends while it is quiet does not pulse later. /flatui pulse test and the samples of the look still show. Choices: Always, In combat only, Not while mounted or in a city. |
| **Your pet's abilities** | Off | Spell Lock, Seduction, Sacrifice, Dash and the like pulse as they come back, as your own spells do. A pet casts some of its abilities on its own, which then pulse each time: Leave out takes one away. |
| **Leave out** |  | A spell is left out with all its ranks. For one that is not listed, type /flatui pulse ignore and its name. |
| **Put back** |  |  |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Icon size** | 72 | Out of combat, a change of this or another row of the look shows a test pulse in the new look. |
| **How long it shows** | 1 s | Cooldowns that end together pulse one after another. /flatui pulse test shows one. |
| **Opacity** | 70% | How solid the pulse is at its brightest. |
| **Sound** | None | Out of combat, a pick plays it with a test pulse. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Sound of one spell or item** |  | Choose one, then open the list again for its own sound. One without it plays Sound. Out of combat, a pick shows it. |
| **Name under the icon** | On | The spell or item that is ready again, fading with the icon. An item's name is in its quality's colour. |
| **Grow as it fades** | Off | The icon swells by a quarter as it fades out. |
| **Burst as it shows** | On | The game's star flash, the one its own cooldowns show as they end, bursts once over the icon as it comes in: white for a spell, in the item's quality colour for an item. |

**Spots**

| Setting | Default | Notes |
| --- | --- | --- |
| **Pulse spots** | One | Each spot has its own handle in /flatui move and pulses on its own. Icon size is the size at spot 1. Out of combat, a change shows a test pulse at each spot in use. Choices: One, Two, Three. |
| **Icon size at spot 2** | 72 | Needs **Pulse spots** at Two or Three. |
| **Icon size at spot 3** | 72 | Needs **Pulse spots** at Three. |
| **Spot of one spell or item** |  | Choose one, then open the list again for its spot. One without it pulses at spot 1. Out of combat, a pick shows it. Needs **Pulse spots** at Two or Three. |

## Trackers

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Trackers** | On |  |

**List**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add a buff** |  | For a buff that is not listed, type /flatui tracker add and its name. |
| **Add a debuff on the target** |  | Your own debuff on your current target. For one that is not listed, type /flatui tracker add debuff and its name. |
| **Add an item** |  | Only items in your bags. For an item you have none of, type /flatui tracker add item and its name. |
| **Add a check** |  | A shaman's imbue, a rogue's poison, a sharpening stone or an oil on a weapon. |
| **Add a stance or form** |  |  |
| **Add class trackers** |  | A buff, stance, form or totem is added only when you know its spell, an item only when it is in your bags. /flatui tracker class adds them all. |
| **Remove a tracker** |  | Out of combat the row shows as samples for 4 seconds without it. Bring back a tracker puts it back until you reload. |
| **Bring back a tracker** |  | Trackers removed since you logged in or reloaded, the last five, back in their old place with their own settings. /flatui tracker back brings the last one back. |

**When shown**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | Only when low or missing | Choices: Always, Only when low or missing, Only in combat. |
| **Hide while mounted or flying** | On | Applies to trackers set to Only when low or missing, also on a flight path. |
| **Hide in cities and inns** | Off | Applies to trackers set to Only when low or missing. |
| **Hide in combat** | Off | Applies to trackers set to Only when low or missing: a low or missing tracker shows only between fights. |
| **Hide outside dungeons and raids** | Off | Applies to trackers set to Only when low or missing: they show only in a dungeon or raid, and at a ready check or pull countdown. |
| **Show at a ready check or pull countdown** | On | While a ready check is open (12 seconds at least, so an all-ready still leaves time to fix things), or until the pull of a player's countdown (30 seconds at most), every tracker that is low or missing shows, also while mounted, in a city, outside dungeons and raids or with Only in combat, and one chat line names them, with who lacks a group buff when 3 or fewer do. A cancelled countdown hides them again, and the pull ends it. |

**In fights**

| Setting | Default | Notes |
| --- | --- | --- |
| **Game's own icon in fights** | Off | Off: charges and time left stop updating in a fight. |
| **In fights without the game's icon** | Last known | Choices: Last known, Hidden. |

**Action buttons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Mark action buttons** | Off | A border on the action button that fixes a tracker: amber while it is low, red while it is missing. A button shared by trackers is red while any tracker on it is missing. Needs Restyle action bars. |

**Clicks**

| Setting | Default | Notes |
| --- | --- | --- |
| **Click to apply** | Buffs, forms, pet, conjuring and tracking | Out of combat, a click on a tracker that needs it fixes it: your buff, stance or form is cast, your pet is called, revived or set to fight, a group buff is cast on a member who lacks it, a missing mana gem, water, food, Healthstone or Soulstone is conjured with the best spell you know for it, and the minimap tracking you last had on is cast again; with weapons, a poison, stone or oil goes on the weapon too. An item with no spell that makes it, such as an Ankh, takes no click. /flatui tracker use 1 and an item sets what a weapon tracker uses. Choices: Off, Buffs, forms, pet, conjuring and tracking, Buffs, forms, pet, conjuring, tracking and weapons. |
| **Item a click puts on a weapon** |  | Choose a weapon tracker, then open the list again for what a click puts on that weapon. /flatui tracker use does the same. Needs **Click to apply** at Buffs, forms, pet, conjuring, tracking and weapons. |
| **Tracker tooltips** | Out of combat only | The mouse over a tracker on screen shows its name, whether it is up, low or missing, its time left and charges, what counts as low, and for a group buff who lacks it. A click goes through to the world, but on a tracker a click fixes. Settings on the Tooltips page do not change this tooltip. Choices: On, Out of combat only, Off. |

### Look and position

**Shape**

| Setting | Default | Notes |
| --- | --- | --- |
| **Shape** | Icon | Out of combat, a change of this or another row of the look shows every tracker for a few seconds in the new look. Choices: Icon, Bar, Text. |
| **Icon size** | 36 |  |
| **Bar width** | 140 |  |
| **Bar height** | 14 | Also the height of text. |
| **Bar fill** | Charges | A buff without charges fills by time left. Choices: Charges, Time left. |
| **Colour** | #4D99E6 | Bar fill and text. |
| **Bar texture** | `default` | A bar the game draws in a fight changes once the game shows your buffs again. |
| **Icon border** | On | Off also removes the dark background. |
| **Charges** | On |  |
| **Name** | On | On bars and text. |
| **Time left** | On |  |
| **Countdown number size** | As the game has it | Choices: As the game has it, Small, Normal, Large, Huge. Needs **Time left** on. |
| **Row direction** | From the middle | A column stacks the trackers under each other, left-aligned, as timer bars usually are. Flat UI setup draws a column as a row. Choices: From the middle, Left to right, Right to left, Column, downward, Column, upward. |
| **Spacing** | 3 |  |
| **Close up the gaps** | Off | Hidden trackers take no room, so the ones that show stay together, centred or from the start as Row direction says. In a fight the row keeps the places it had when the fight began. |

**Position**

| Setting | Default | Notes |
| --- | --- | --- |
| **Place** | Own position | Own position: drag the Trackers handle in /flatui move. Choices: Personal resource display, Beside the character, Own position. |
| **Side of the personal resource display** | Above | Choices: Above, Below. |
| **X offset** | 0 |  |
| **Y offset** | 0 |  |

### Low and missing

**Amounts**

| Setting | Default | Notes |
| --- | --- | --- |
| **Item minimum** | 1 | An item tracker is low when the bags hold fewer. /flatui tracker set 1 low 5 sets one tracker to be low at 5 or fewer. |
| **Ammunition minimum** | 200 | With a bow, crossbow or gun, the ammunition tracker is low at this many arrows or bullets or fewer. 0 means never. Set to Only when low or missing, a low count waits for the end of a fight. |
| **Thrown weapon minimum** | 20 | With a thrown weapon, the ammunition tracker is low at this many or fewer. 0 means never. One that wears out is low at a fifth of its durability. |
| **Durability minimum** | 20% | The durability tracker is low when an item you wear is at this much of its durability or less, and red when one is broken. 0 means never. At a ready check or pull countdown, until the pull, it is also low at 40% or less, and shows when low or broken, whatever Show says, while Show at a ready check or pull countdown is on. |

**Pet**

| Setting | Default | Notes |
| --- | --- | --- |
| **Pet health minimum** | 30% | A Pet or Demon tracker shows your pet's health in red while it is under this. 0 means never. /flatui tracker set 1 health 40 sets one tracker's own. |
| **Pet on passive counts as low** | On | A Pet or Demon tracker is low while your pet is out and set to Passive, when it does not fight for you. |
| **Pet on defensive counts as low** | Off | Defensive is a usual choice on classic content. On, a click sets your pet to Assist. |

**Low**

| Setting | Default | Notes |
| --- | --- | --- |
| **Low at (charges)** | 0 | 0 means never. |
| **Low at (seconds left)** | 0 s | 0 means never. Up to 30 minutes, for long buffs and poisons. |
| **Low in dungeons and raids (seconds left)** | 120 s | For a buff or weapon enchant that lasts 10 minutes or more, in a dungeon or raid: the larger of this and Low at. 0 means the same as elsewhere. In a fight, a tracker set to Only when low or missing still hides while its buff is up, so the warning shows between pulls. |

**Missing**

| Setting | Default | Notes |
| --- | --- | --- |
| **When missing** | Red icon | Out of combat, a change shows every tracker as missing for a few seconds. Choices: Red icon, Red icon that pulses, Red icon and the word Missing. |
| **Sound when it drops** | On |  |
| **Sound when it comes** | Off | For a buff or debuff tracker, in the kit of Sound. |
| **Sound when it stacks** | Off | For a buff or debuff tracker, in the kit of Sound. |
| **Sound when it turns low** | Off | Once as a tracker goes from fine to low, by its Low at rows, Item minimum, Ammunition minimum or the pet rows, in the kit of Sound. The game hides buffs in a fight, so a buff turns low by sound between fights. |
| **Sound** | Raid warning | Out of combat, a pick plays it once. Edit a tracker gives one tracker a sound of its own. Raid warning, Alarm and Whisper warning also play for a buff in a fight, since the game plays them. The others play only while the game shows your buffs, so a buff that drops in a fight is silent with them. Choices: Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

### Proc alerts

**Which procs**

| Setting | Default | Notes |
| --- | --- | --- |
| **Procs of your class** | On | Shows every proc of your class whose spell you know, such as Overpower after a dodge, Revenge and Execute, without adding it: the art beside your character and the glow on the button, as the game shows them in later expansions. Remove a proc turns one off. |
| **Add a proc** |  | For another spell, type /flatui tracker add proc and its name. A proc you add keeps its own colour, time and sound. |
| **Remove a proc** |  | Also lists the procs of your class. One you remove stays off for this character. |
| **Bring back a proc** |  | A proc of your class you removed shows again without being added. Needs **Procs of your class** on. |
| **Colour** | #FFD100 | The border of a proc alert, and the plain arc of a proc with no art of its own. /flatui tracker proc colour sets one proc's colour, which also tints its art, and works on the procs of your class too, by name: /flatui tracker proc colour Execute ff3030. proc sound Overpower bell, proc time Revenge 5 and proc reset Execute set a proc's sound and time or put them back. |
| **Sound** | Spell alert | Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

**Art beside the character**

| Setting | Default | Notes |
| --- | --- | --- |
| **Art beside the character** | On | The game's own art beside the character while a proc is up, larger and fainter than the game draws it by default. Glow style sets how it fades in and pulses. Place it with the Proc art box in /flatui move. |
| **Art size** | 150% | 100% is the game's size. Needs **Art beside the character** on. |
| **Art opacity** | 40% | 65% is the game's. The game's Spell Alert Opacity has no effect here. Needs **Art beside the character** on. |
| **Art height** | 0 | Positive moves the art up from its Proc art box in /flatui move. Needs **Art beside the character** on. |
| **Stacks build the art** | On | Maelstrom Weapon fills its art a fifth per stack from a faint outline, with the count on it. At 5 stacks it is full and pulses, the proc sound plays and, with Glow on the action button, Lightning Bolt glows. In a fight the game draws the fill and the number. Off, the art shows at 5 stacks alone and the stacks show on Charges. Needs **Art beside the character** on. |
| **Seconds left on the art** | On | The seconds a proc with a time has left, such as Overpower or Revenge, as a large number on its art in its colour, white and a little larger for the last 2 seconds. It fades out with the art. Execute and other procs with no time show none. Needs **Art beside the character** on. |

**Glow**

| Setting | Default | Notes |
| --- | --- | --- |
| **Glow on the action button** | Off | A glow on the button that casts the spell the proc is for, and a border in the proc's colour, which needs Restyle action bars. With Glow style Soft the glow takes the proc's colour too. |
| **Glow style** | Soft | Soft: a faint glow that hugs the button's edge and breathes slowly, and a slow, gentle pulse of the art. As the game has it: the game's burst and loop, which lie over the buttons beside it, and the game's own pulse and fade-in of the art; with Art size 100% and Art opacity 65% it is the game's whole look. The art, Glow on procs of the cooldown icons and Game glow on Flat UI's own buttons follow it too, with or without Glow on the action button. Choices: Soft, As the game has it. |
| **Seconds left on the button** | On | While a proc with a time, such as Overpower or Revenge, is up, its button counts down the seconds left in the proc's colour, at Hotkey size and Button text outline, in a corner clear of the hotkey, macro name and count. It turns white and grows a little for the last 2 seconds. Execute and other procs with no time show none. With Glow on the action button off, the number shows alone, with no glow and no border. |

## Defensives on you

| Setting | Default | Notes |
| --- | --- | --- |
| **Defensives on you** | On | Defensives other players cast on you, each with its time left. |

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Place** | At the personal resource display | Own position has a handle in /flatui move. Out of combat with no defensive on you, a change shows the samples where the row now sits. Choices: Above the player frame, At the personal resource display, Own position, Off. |
| **X offset** | 0 | Moves the row left or right of where Place puts it. Out of combat with no defensive on you, the samples show the new spot as you drag. Needs **Place** at Above the player frame or At the personal resource display. |
| **Y offset** | 0 | Moves the row up or down from where Place puts it. Needs **Place** at Above the player frame or At the personal resource display. |
| **Icon size** | 32 | Out of combat with no defensive on you, a change of this or another row of the look shows samples in the new look for a few seconds. The time left turns amber in its last 5 seconds. The numbers on the icon grow and shrink with it. |
| **Time left** | On the icon | A thin bar under the icon runs down with the time left, in the Bar texture of Your buffs, open there while this row is the bar and Your buffs is on, and the caster's name moves under it. The bars the game draws in a fight change once the game shows your buffs again. Choices: On the icon, Thin bar under the icon, Off. |
| **Spacing** | 3 |  |
| **Caster's name** | On |  |
| **Icon border** | On |  |
| **Buff tooltips** | On | Settings on the Tooltips page do not change this tooltip. A click still goes through to the world. Choices: On, Out of combat only, Off. |
| **Your own defensives** | On | Shield Wall, Ice Barrier and the like that you cast on yourself. |
| **Sound when one lands** | None | Once as a listed defensive comes on you. Played by the game, so also in a fight. Spells you know yourself are left out. Out of combat, a pick plays it and shows the samples landing. Choices: None, Raid warning, Alarm, Whisper warning. |
| **Sound when one ends** | None | Once as a listed defensive from someone else leaves you, also in a fight, since the game plays it. Spells you know yourself are left out. Choices: None, Raid warning, Alarm, Whisper warning. |
| **Flash when one lands** | On | A quick white flash on the icon as a defensive lands. Drawn by the game, so also in a fight. |

**Spells**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add a spell** |  | For a buff that is not listed, type /flatui defensives add and its spell ID. |
| **Remove a spell** |  |  |

## Absorb shields

| Setting | Default | Notes |
| --- | --- | --- |
| **Absorb shields** | On | Bars for the shields on you, such as Power Word: Shield, Ice Barrier, the wards and protection potions: how much each has left and for how long, and the total of every absorb. Nothing shows while no shield is up. /flatui move places them, /flatui absorbs test shows a sample. |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | The total and each shield | In a fight, while the game hides your buffs, the total is the one live amount; each shield then shows its time, filling by it. Choices: The total and each shield, The total only, Each shield only. |
| **Total bar is full at** | Your shields | Your shields: the size of the shields on you, as far as Flat UI knows it, and your health while it knows none. Your health: the shield as a share of your health, as the game's frames show it. Choices: Your shields, Your health. Needs **Show** at The total and each shield or The total only. |
| **Bar width** | 180 px | With the icon. Out of combat with no shield up, a change of this or another row of the look shows samples in the new look for a few seconds. |
| **Bar height** | 16 px | Also the size of the icon and the text. The bars the game draws in a fight change once the game shows your buffs again. |
| **Spacing** | 2 px |  |
| **Bars grow** | Down | From the top or the bottom of their box in /flatui move. Choices: Down, Up. |
| **Bar texture** | `default` |  |
| **Time strip** | Off | A thin bar along the foot of each shield that runs down with its time. |

**Text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Amount** | Amount left | The size of a shield is the most it held as Flat UI read it, or for your own shield what Flat UI works out from your spell power. Choices: Amount left, Amount left and size, None. |
| **Time left** | On | Amber in its last 5 seconds. |
| **Spell name** | Off |  |
| **Bar tooltips** | On | The game's tooltip of a shield over its bar, with what it has left, and over the total bar each shield on you with its amount and time left. A click still goes through to the world. Settings on the Tooltips page do not change this tooltip. Choices: On, Out of combat only, Off. |

**Colour**

| Setting | Default | Notes |
| --- | --- | --- |
| **Colour by school** | On | A shield that takes one school in its colour: Fire Ward orange, Frost Ward light blue, Shadow Ward violet, Mana Shield grey. One that takes every school is in Shield colour. |
| **Shield colour** | #FFE08A | Shields that take every school, and the total. |
| **Shield stripes** | On | The striped shield pattern over each bar's fill, as the game draws absorbs on its later frames, with a soft bright edge where the fill ends. Also on the bars the game draws in a fight. |

**Shields**

| Setting | Default | Notes |
| --- | --- | --- |
| **Priest shields** | On | Power Word: Shield and Contingency Plan. |
| **Mage shields** | On | Ice Barrier, Mana Shield, Fire Ward and Frost Ward, also those a mage casts on you. |
| **Warlock shields** | On | Shadow Ward and a voidwalker's Sacrifice. |
| **Protection potions** | On | Fire, Frost, Nature, Shadow, Holy and Arcane Protection, and the greater ones. |
| **Items** | On | Items whose use absorbs damage, such as the Gnomish Harm Prevention Belt. |
| **Add a spell** |  | For a shield that is not listed, type /flatui absorbs add and its spell ID. Every absorb counts in the total all the same. |
| **Remove a spell** |  |  |

**When a shield breaks**

| Setting | Default | Notes |
| --- | --- | --- |
| **Sound** | None | Plays when a shield goes before its time is up, and the bars flash red. Only while the game shows your buffs: in a fight it may hide them. Out of combat, a pick plays it once and the bars shown flash. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

**Your target**

| Setting | Default | Notes |
| --- | --- | --- |
| **Your target's total** | Off | A bar with the total of every absorb on your target. /flatui move places it. Out of combat, turning it on shows sample bars for a few seconds. |

## Charges

| Setting | Default | Notes |
| --- | --- | --- |
| **Charges** | On | Your buffs with charges, such as Lightning Shield, Water Shield, Earth Shield, Inner Fire, Shadowguard and Holy Shield, and the stacks of Maelstrom Weapon while the Proc alerts art does not build them, as a row of glowing gems like the game's own class resources, under the bars of the personal resource display: lit gems are the charges left, empty sockets the ones used, with the spell's name, the charges left and the time left. It shows while the buff is up. /flatui charges shows a sample. |

**Spells**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add a spell** |  | Spells of your class you took off, and the buffs on you now with more than one charge. For another, type /flatui charges add and its name or spell ID while it is on you. |
| **Take a spell off** |  | /flatui charges remove and its name or spell ID does the same. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Orb style** | Resource bar | Resource bar: a row of gems in sockets, drawn with the game's own class resource art. Spell art: the game's own spell alert art for the buff, brighter with each charge, with the count and time under it; a buff without such art, such as Lightning Shield, shows the resource bar. Maelstrom Weapon has such art, but while Art beside the character and Stacks build the art of Proc alerts are on, its stacks show on that art and not here. Out of combat with no buff with charges on you, a change of this or another row of the look shows a sample for a few seconds. Choices: Resource bar, Spell art, Ring round the icon, Arc over the icon, Row under the icon. |
| **Fill the width** | On | Under or above the personal resource display, the gems spread out from end to end of its bars, each keeping its shape. Off, the gems sit 3 px apart in the middle, as they do at the row's own spot. With Spell art, the art takes the width of the bars, at most 240 px. Needs **Orb style** at Resource bar or Spell art. |
| **Gem size** | 20 px | The size of each gem and its socket. The name, count and time grow and shrink with it. With Spell art, it sets only the size of the text under the art. Needs **Orb style** at Resource bar or Spell art. |
| **Spell icon** | Off | The round spell icon in the middle of the orbs. Off, the orbs ring the count alone. Needs **Orb style** at Ring round the icon or Arc over the icon or Row under the icon. |
| **Spin** | Slow | The ring of orbs turns round the icon. On an arc or a row the orbs sway gently instead. Choices: Still, Slow, Fast. Needs **Orb style** at Ring round the icon or Arc over the icon or Row under the icon. |
| **Icon size** | 40 px | The round spell icon in the middle, and the ring the orbs sit on, close round it. The text grows and shrinks with it. Needs **Orb style** at Ring round the icon or Arc over the icon or Row under the icon. |
| **Orb size** | 12 px | Each orb, without its soft glow. Needs **Orb style** at Ring round the icon or Arc over the icon or Row under the icon. |
| **Colour** | Spell's own colour | Spell's own colour: Lightning Shield electric blue, Water Shield sea green, Earth Shield earthy green, Maelstrom Weapon electric blue white, Inner Fire gold, Shadowguard violet and Holy Shield warm gold, each with the game's resource art that suits it; a spell you added has your class colour. Class colour and One colour tint the gems. Choices: Spell's own colour, Class colour, One colour. |
| **Orb colour** | #59B8FF | Needs **Colour** at One colour. |
| **Show used charges** | On | Each charge used stays as an empty socket, or a faint ring round the icon, so you see how many are gone. Off, only the charges left show. |
| **Burst as a charge goes** | On | The gem plays the game's fade of a spent resource, or flashes white, swells and fades, as its charge goes. Only while the game shows your buffs: in a fight it may hide them, and the gems then go out without it. |
| **Name** | On | The spell's name, small, above the left end of the row, beside the count under the art, or above the ring, arc or row of orbs. |
| **Count** | On | The charges left as a large number at the right end of the row, or under the art or in the middle of the orbs. Off, the number shows only past 10 charges. |
| **Time left** | On | Above the right end of the row, or after the count where the row is too short for the name and the time side by side; beside the count under the art, or under the orbs. Amber in its last 10 seconds. |

**Position**

| Setting | Default | Notes |
| --- | --- | --- |
| **Place** | Under the personal resource display | Under or above, the row sits just clear of the bars of the personal resource display, the width of the bars, and follows them, past a Your buffs row on that side; Defensives on you, a Cooldowns row and Trackers placed at that display sit past it in turn. With that display off or hidden, it goes to its own spot. Own spot has a handle in /flatui move. Choices: Under the personal resource display, Above the personal resource display, Own spot. |

**When shown**

| Setting | Default | Notes |
| --- | --- | --- |
| **Only in combat** | Off | Out of a fight the orbs stay hidden and the rows past them close up; test mode and the samples still show them. |
| **Hide while mounted** | Off | Hidden while you ride, the rows past it closing up, and back as you get off. |

**Sound**

| Setting | Default | Notes |
| --- | --- | --- |
| **Sound when the last charge goes** | None | Plays as a buff leaves you on its last charge before its time is up. Only while the game shows your buffs: in a fight it may hide them. Out of combat, a pick plays it once. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

## Enemy cooldowns

| Setting | Default | Notes |
| --- | --- | --- |
| **Enemy cooldowns** | On | Icons beside the nameplates of enemy players. |

**Abilities**

| Setting | Default | Notes |
| --- | --- | --- |
| **Interrupts** | On |  |
| **Defensives** | On |  |
| **Crowd control breaks** | On |  |
| **Wards and immunities** | On |  |
| **Mobility** | Off |  |
| **Offensive cooldowns** | On |  |
| **Crowd control break in arenas** | Off | On the target and focus bars. |
| **Add an ability** |  | For a spell that is not listed, type /flatui enemy add, its spell ID and its cooldown in seconds. |
| **Hide an ability** |  |  |

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Place** | On enemy nameplates | The two bars have handles in /flatui move. Choices: Both, On enemy nameplates, Bars for target and focus. |
| **Place on nameplates** | Right of the health bar | Beside the health bar or above the name, the icons leave room for the game's own icons and stay off the enemy's character. Below the health bar they cover the enemy's character. Choices: Right of the health bar, Left of the health bar, Above the name, Below the health bar. Needs **Place** at Both or On enemy nameplates. |
| **Show** | Always, used ones dark | With Always, an icon is bright only while a use of its ability would be seen. The game hides enemy casts, and their buffs in a fight, so the others are dim with a question mark, and after a fight one seen by its buff stays so for its cooldown. Choices: Only while on cooldown, Always, used ones dark. |
| **Icon size** | 24 |  |
| **Icon border** | On | Off also removes the dark background. |
| **Border colour by kind** | On | Interrupts, defensives and the others each have a colour. Off, the border has the colour of the Flat UI page. Needs **Icon border** on. |
| **Time left** | On |  |
| **Countdown number size** | As the game has it | Choices: As the game has it, Small, Normal, Large, Huge. Needs **Time left** on. |
| **Icon tooltips** | On | On the target and focus bars; icons on nameplates take no mouse. Pointing at an icon names the ability and the enemy and says Ready or the time left. Choices: On, Out of combat only, Off. |

**Ready again**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flash when ready** | On | A white flash on the icon as its cooldown ends. |
| **Sound** | Bell | The sound plays for your target and focus only. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Shortest cooldown that sounds** | 0 s | A cooldown shorter than this ends without the sound, so a Kick or a Pummel on your target stays quiet; the flash still shows. 0 sounds for every cooldown. |

## Combat text

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Place combat numbers** | On |  |
| **Numbers over enemies** | In front of nameplates | As the game has them shows only your and your pet's hits, behind the nameplate. Choices: In front of nameplates, As the game has them. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Style** | Classic | Classic is the game's old floating text: straight up at a steady speed. Choices: Flat UI, Classic. |
| **Font** | Arial Narrow | For numbers in front of nameplates, the Outgoing scroll area and your own text. Choices: Friz Quadrata (the game's damage font), Arial Narrow, Skurri, Morpheus. |
| **Outline** | None | Choices: Thick, Thin, None. |
| **Shadow** | Off |  |
| **How a number appears** | With a pop, larger for critical hits | Also the pop of the scroll areas. Classic keeps its own look over enemies. Choices: With a pop, larger for critical hits, Plainly. |
| **Partial effects** | Word after the number | Glancing, Crushing, Block, Resist and Absorb. Choices: Word after the number, Smaller number only, Off. |
| **Miss words** | Bare word | Miss, Dodge, Parry, Immune and the other words: Dodge as a bare word, or (Dodge) in parentheses. Choices: In parentheses, Bare word. |
| **Size of miss words** | Three quarters of the numbers | Miss, Dodge, Parry and the other words against the numbers they show with: over enemies, over friendly units and in both scroll areas. Choices: Three quarters of the numbers, Same as the numbers. |

**Position and size**

| Setting | Default | Notes |
| --- | --- | --- |
| **Height above the enemy** | 60 | With As the game has them, 40 is the game's own height. Also the height over friendly nameplates. |
| **Critical hits** | Higher | Higher starts a critical hit over an enemy above the other numbers. Choices: Same height, Higher. |
| **Size** | 170% | 100% is the game's own size. Both scroll areas follow it by default. In a group with The game's own numbers, those take Size of experience and other gains. |

**Spread and movement**

| Setting | Default | Notes |
| --- | --- | --- |
| **Spread** | Loose | Tight starts the numbers over an enemy on one spot; Loose spreads them to the sides, as far as Spread width. Choices: Tight, Loose. |
| **Spread width** | 160% | How far Loose spreads the numbers to the sides; 100% is the game's own spread. Needs **Spread** at Loose. |
| **Movement** | Burst | With a pop, Burst starts a critical hit over an enemy large. Every other number rises and falls. Choices: Rise and fall, Straight up, Burst. Needs **Style** at Flat UI. |
| **Overlapping numbers** | Keep apart | Keep apart starts a number in a free lane, or higher up. Choices: Keep apart, Stay in turn. Needs **Style** at Flat UI. |
| **Rows** | 4 | Most numbers stacked one above another. |

### Scroll areas

**Scroll areas**

| Setting | Default | Notes |
| --- | --- | --- |
| **Where your hits show** | Over enemies | Over enemies keeps each hit over the enemy it hit. Scroll area shows hits on your target only, in the Outgoing area beside your character. Both shows the numbers over each enemy and also scrolls the hits on every enemy with a nameplate in the Outgoing area. Choices: Scroll area, Over enemies, Both. |
| **Outgoing style** | Arc | Straight rises in a line, Arc curves out to the side (Arc width), Horizontal slides sideways, Static stays put and fades, stacking rows. Choices: Straight, Arc, Horizontal, Static. Needs **Where your hits show** at Scroll area or Both. |
| **Size of the Outgoing area** | Same as numbers over enemies | The size of your hits in the Outgoing area. Big numbers over enemies can go with a calmer column beside you. Choices: Same as numbers over enemies, Same as your text, Smaller than numbers over enemies. Needs **Where your hits show** at Scroll area or Both. |
| **Incoming style** | Straight | Straight rises in a line, Arc curves out to the side (Arc width), Horizontal slides sideways, Static stays put and fades, stacking rows. Choices: Straight, Arc, Horizontal, Static. |
| **Size of the Incoming area** | Same as numbers over enemies | The size of the numbers on you in the Incoming area. Same as numbers over enemies follows Size, so the hits on you read as large as your own. Choices: Same as numbers over enemies, Same as your text, Smaller than numbers over enemies. |
| **Outgoing direction** | Up | Which way your hits move in the Outgoing area. Horizontal and Static numbers stack their rows this way. Choices: Up, Down. Needs **Where your hits show** at Scroll area or Both. |
| **Incoming direction** | Down | Which way the numbers on you move in the Incoming area. Horizontal and Static numbers stack their rows this way. Choices: Up, Down. |
| **Arc width** | Wide | How far an arc number curves out to the side. Choices: Narrow, Wide. |
| **Spell icons** | All | Shows the icon of your spell, swing or shot in the Outgoing area, while Where your hits show is Scroll area or Both, and of your own heals on you in the Incoming area. Numbers over enemies and damage on you show none. Choices: All, Spells only, Off. |
| **Speed** | Slow | How long a number stays in the scroll areas. Choices: Fast, Normal, Slow. |
| **Your interrupts** | Off | Interrupted with the icon of your Kick, Counterspell, Pummel or your pet's Spell Lock pops up in Interrupt ready colour each time it stops an enemy's cast, so you see each kick land without looking up. It shows in the Outgoing area while Where your hits show is Scroll area or Both, and otherwise over the nameplate of the enemy you stopped, at the size of the miss words (this needs Numbers over enemies at In front of nameplates). It shows when the game names you or your pet as the one who stopped the cast; when the game keeps that secret, it follows the target or focus bar turning Interrupted right after your interrupt. |
| **Also kicks that stop nothing** | On | Not interrupted with your interrupt's icon, in Interrupt on cooldown colour, when your interrupt went off while your target or focus was casting and the cast went on; Too late when another player's interrupt stopped it first. It only judges once the game has named who stopped a cast this session, so it never guesses while the game keeps that secret. A cast that cannot be interrupted counts as neither. Needs **Your interrupts** on. |

**Classic**

| Setting | Default | Notes |
| --- | --- | --- |
| **Colours** | White and yellow | Colour by school of magic, when on, takes their place. Choices: White and yellow, Red and purple. |
| **Plus and minus signs over enemies** | Off |  |
| **Rise distance** | 175 |  |
| **Time on screen** | 100% | 100% is the game's own 1.9 seconds. |
| **Stacking** | Older numbers move up | As numbers come fast, Older numbers move up pushes the earlier ones higher, and New numbers start lower starts each new one under the last. Choices: Older numbers move up, New numbers start lower. |
| **Critical hits stay in place** | On | A critical hit pops in larger where it starts and fades there, while the other numbers rise. |

### Hits and colours

**In front of nameplates**

| Setting | Default | Notes |
| --- | --- | --- |
| **Whose hits** | Yours | The game names no source for a hit. Yours shows every hit on an enemy only you and your pet are fighting, alone or in a party; otherwise it shows one hit for each of your casts, swings, shots, auras and pet swings. Choices: Yours, Everyone's. |
| **Extra attacks** | Extra attack | An extra swing, such as Windfury or Hand of Justice, shows in white with (Extra attack) after it. In a group or with a pet out, only when the game reports it as a swing of yours. Choices: Extra attack, Off. Needs **Whose hits** at Yours. |
| **Numbers over enemies in a group** | The game's own numbers | The game's own numbers show every hit of yours and your pet's, behind the nameplate. Flat UI numbers show in front of it, but can miss a proc that casts nothing. The game's own numbers take Size of experience and other gains, as the game has one size for both. Choices: The game's own numbers, Flat UI numbers. |
| **Enemies** | Every enemy with a nameplate | Which enemies show your numbers in front of their nameplates. Choices: Every enemy with a nameplate, Target only. |
| **Colour by school of magic** | Off | Off shows hits of your spells in yellow, and swings and shots in white. Special attacks are yellow unless Physical ability hits is White. On colours each hit by its school, also spells that hit you in the Incoming area. |
| **Physical ability hits** | Yellow | Maul, Heroic Strike and other special attacks: Yellow shows them as spells and White as swings. Choices: Yellow, White. Needs **Whose hits** at Yours. |
| **Spell names** | Next melee abilities | After the number: Maul, Heroic Strike, Cleave and Raptor Strike, or every spell of yours, as 1,234 Fireball, over enemies and in the Outgoing area. Swings and shots stay bare. Choices: Off, Next melee abilities, After every spell. Needs **Whose hits** at Yours. |

### Friendly units

**Friendly units**

| Setting | Default | Notes |
| --- | --- | --- |
| **Where friendly numbers show** | Both | Party and raid frames show numbers where friendly nameplates are not available. Choices: Off, Party and raid frames, Friendly nameplates, Both. |
| **Friendly units** | Every friendly unit | Choices: Every friendly unit, Target only. Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Damage friendly units take** | On | Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Healing over friendly units** | Healing you do | Healing you do is the game's own number, on your target only and behind the nameplate. Choices: Healing they take from anyone, Healing you do, Off. Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Your pet** | On | Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Misses and dodges over friendly units** | Off | Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Plus and minus signs** | On | Heals show + and damage shows -. Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Friendly damage colour** | #FF1A1A | Colour by school of magic, when on, takes its place. Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Friendly healing colour** | #1AFF1A | Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Size over friendly units** | 100% | 100% is the game's own size. Needs **Where friendly numbers show** at Party and raid frames or Friendly nameplates or Both. |
| **Height above frames** | 10 | Party and raid frames only. Needs **Where friendly numbers show** at Party and raid frames or Both. |

### You and warnings

**Your character**

| Setting | Default | Notes |
| --- | --- | --- |
| **Combat text for you** | Also misses, dodges and gains | While your text shows, Scrolling Combat Text for Self in the game's options is off and its other messages do not show. Choices: Damage and healing you take, Also misses, dodges and gains, Off. |
| **Size of your text** | 90% | 100% is the game's own size. The Incoming area takes it while Size of the Incoming area is Same as your text. Needs **Combat text for you** at Damage and healing you take or Also misses, dodges and gains. |
| **Healing on you** | On | Off shows only what hurts you in the Incoming area, so heals from many healers do not hide the hits. Needs **Combat text for you** at Damage and healing you take or Also misses, dodges and gains. |
| **Damage on you colour** | #FF1A1A | Colour by school of magic, when on, takes its place for spells. Needs **Combat text for you** at Damage and healing you take or Also misses, dodges and gains. |
| **Healing on you colour** | #1AFF1A | Needs **Healing on you** on. |
| **Size of experience and other gains** | Same as your text | Text the game draws near you, such as experience, alone and in a group. In a group with The game's own numbers over enemies, those take this size too. Choices: Same as your text, Smaller than your text, The game's own size, Same as numbers over enemies. |

**Warnings**

| Setting | Default | Notes |
| --- | --- | --- |
| **No target warning** | On | In a fight with no target, or with a dead or friendly one, No target shows in the middle of the screen after a second. |
| **Warn with a friendly target** | On | Off for healing in a group: a friendly target then keeps the warning away. A healer (group role or talents) is never warned for a friendly target. Needs **No target warning** on. |
| **Name the key to target an enemy** | On | No target names the key bound to Target Nearest Enemy, as No target (Tab). Nothing is added with no key bound, or while you heal. Needs **No target warning** on. |
| **No target sound** | None | At most once every 3 seconds. Plays once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **No target warning** on. |
| **No target colour** | #C41E3A | Needs **No target warning** on. |
| **Size of No target** | 100% | 100% is the size of the game's own combat messages. Low health and Low mana take this size too. Needs **No target warning** on. |
| **Low health and mana warning** | On | Low health in the middle of the screen while your health is under Low health below, and Low mana while your mana is under Low mana below, as the game's own combat text had them at 20%. |
| **Only in a fight** | On | Off also shows them out of a fight, as while you eat or drink. Needs **Low health and mana warning** on. |
| **Low health below** | 20% | Low health shows while your health is under this share, as 30% for a tank. Needs **Low health and mana warning** on. |
| **Low mana below** | 20% | Low mana shows while your mana is under this share, as 35% for a healer. Needs **Low health and mana warning** on. |
| **Low health colour** | #FF6633 | Needs **Low health and mana warning** on. |
| **Low mana colour** | #4D9CFF | Needs **Low health and mana warning** on. |
| **Share on Low health and Low mana** | On | As Low health 14%, read as your health or mana changes, in a fight too. Needs **Low health and mana warning** on. |
| **Glow at the screen's edges** | Off | A soft glow in Low health colour along the four edges of the screen while your health is under Low health below, so you notice it while you watch the boss. It breathes and fades with the Low health line, in a fight too. Needs **Low health and mana warning** on. |
| **Entering and leaving combat** | On | +Combat and -Combat in the middle of the screen for a moment as a fight starts and ends. |
| **Entering combat colour** | #FF1A1A | Needs **Entering and leaving combat** on. |
| **Leaving combat colour** | #1AFF1A | Needs **Entering and leaving combat** on. |
| **Size of +Combat and -Combat** | 100% | 100% is the size of the game's own combat messages. Needs **Entering and leaving combat** on. |
| **Fight length on -Combat** | On | -Combat says how long the fight lasted, as -Combat 1:24. Needs **Entering and leaving combat** on. |
| **Entering combat sound** | None | Plays as +Combat shows, and once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Entering and leaving combat** on. |
| **Leaving combat sound** | None | Plays as -Combat shows, and once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Entering and leaving combat** on. |

**Announce to your group**

| Setting | Default | Notes |
| --- | --- | --- |
| **Announce blocks, dodges and parries** | Off | While you count as a tank (your group role, a tank stance or form, Your role on the Threat tab of Nameplates, or most talent points in a tank tree) in a party or raid, each attack on you that you block, dodge or parry, or that misses you, sends a short line to the chat Send to names: Dodged, Parried, Missed me, Blocked 245 when the game gives the amount, or Blocked 120 of a hit when a hit gets through your shield, 120 being your block value. Nothing is sent alone, in a battleground or arena, outside a dungeon or raid while Only in dungeons and raids is on, while you do not count as a tank, or while the game closes addon chat. Off at first; /flatui announce test shows sample lines in your own chat window only. |
| **Send to** | Your group's chat | Your group's chat sends to instance chat in an instance group, else raid chat in a raid and party chat in a party. Party chat only uses party chat, which in a raid reaches the members of your raid group, and instance chat in an instance party. Raid chat only sends nothing outside a raid. Only me writes the lines in your own chat window and sends nothing to anyone. Choices: Your group's chat, Party chat only, Raid chat only, Only me. Needs **Announce blocks, dodges and parries** on. |
| **Only in dungeons and raids** | On | Sends the lines only while you are in a dungeon or raid, so a party out in the world, questing with a friend, gets none. It holds for every line on this part of the page, Announce your interrupts too. Turn it off to send them in any party or raid. |
| **How often** | Each one | Each one sends a line as it happens, at most one a second; the ones within that second go into the next line, as Dodged x3 or Dodged, Parried x2. A summary every few seconds sends one line as Last 5 s: 3 dodges, 2 parries, 4 blocks. One line when the fight ends sends Fight: 12 dodges, 8 parries, 15 blocks, 3 misses as you leave combat. Never more than one line a second. Choices: Each one, A summary every few seconds, One line when the fight ends. Needs **Announce blocks, dodges and parries** on. |
| **Seconds of a summary** | 5 s | A summary counts this long from the first block, dodge, parry or miss it holds, then sends one line. Needs **How often** at A summary every few seconds. |
| **Announce blocks** | On | Blocked for an attack your shield stops whole, Blocked 245 when the game gives the amount, and Blocked 120 of a hit when a hit gets through, 120 being your block value as last read (Blocked part of a hit while the game has not given it). Needs **Announce blocks, dodges and parries** on. |
| **Announce dodges** | On | Dodged. Needs **Announce blocks, dodges and parries** on. |
| **Announce parries** | On | Parried. Needs **Announce blocks, dodges and parries** on. |
| **Announce misses** | On | Missed me, for an attack that misses you. Needs **Announce blocks, dodges and parries** on. |
| **Announce resists** | Off | Resisted, for a spell you resist whole; a spell partly resisted sends nothing. Off at first. Needs **Announce blocks, dodges and parries** on. |
| **Announce immunities** | Off | Immune, for an attack or spell you are immune to. Off at first. Needs **Announce blocks, dodges and parries** on. |
| **Announce absorbs** | Off | Absorbed, for an attack an absorb on you, such as Power Word: Shield, takes whole; part of a hit absorbed sends nothing. Off at first. Needs **Announce blocks, dodges and parries** on. |
| **Announce your defensives** | Off | Shield Wall up (12 s) or Last Stand up (20 s) as you use a defensive with a cooldown of a minute or more, such as Shield Wall, Last Stand, Barkskin or Divine Protection, so your healers know. It goes to Send to's chat while you count as a tank, at most one line a second. Off at first. Needs **Announce blocks, dodges and parries** on. |
| **Announce your interrupts** | Off | Interrupted Shadow Bolt each time the game names you or your pet as the one who stopped an enemy's cast, sent to the chat this names, at most one line a second. It works in any role, never claims another player's interrupt, and sends nothing while the game keeps the name secret, alone, in a battleground or arena, outside a dungeon or raid while Only in dungeons and raids is on, or while the game closes addon chat. Your group's chat, Party chat only and Raid chat only work as in Send to; Only me writes the line in your own chat window. Off at first. Choices: Off, Your group's chat, Party chat only, Raid chat only, Only me. |
