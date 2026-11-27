The **Look** group sets how Flat UI draws the whole interface: borders, backgrounds, bar fills, colours, the UI scale and the fonts. It holds two pages, **Flat UI** and **Fonts**, and what you choose here shows on every frame, bar and window that Flat UI styles.

![Flat UI in play](https://raw.githubusercontent.com/dismlx/flat-ui/main/media/flatui-in-play.jpg)

## Flat UI

The **Flat UI** page has three tabs: **General**, **Colours** and **Options and setup**. Like every other page, its settings belong to the profile in use, so a second profile can have its own borders, colours and scale. See [Profiles](Profiles).

### Borders and backgrounds

These rows are on the **General** tab.

- **Borderless** is on as Flat UI comes. Frames and bars have no outline, only their flat background. Borders that carry meaning still show in colour: threat, Elite and Rare, debuff type and item quality.
- Turn **Borderless** off for a thin border round each frame. **Border thickness** sets it, from 1 to 3 px, and **Border colour** sets its colour. The **Colours** tab can take the colour from your class or faction instead.
- **Background colour** and **Background opacity** set the flat fill behind frames and bars. Windows have their own opacity on the **Windows** page: see [Chat and windows](Chat-and-windows).

### Bar texture

**Bar texture**, under **Bars**, sets the fill of every bar that has a flat fill: health, power, cast and the rest. The choices are **Flat**, **Soft shade** (the default), **Shaded**, **Gloss**, **Stripes**, **Bottom edge**, **Side fade**, **Game status bar**, **Skills bar** and **Targeting bar**. The list shows a small sample beside each texture while **Samples in lists** is on, on the **Options and setup** tab.

### Leave the game's action bars alone

**Leave the game's action bars alone**, under **Game action bars**, is on as Flat UI comes. While it is on, Flat UI does not move, group or fade:

- the game's action bars that no block of the **Bar block** page holds,
- the stance and pet bars,
- the game's experience bar, while **Experience bar** on the **Experience and menu bars** page is **The game's**.

It also does not move the micro menu or the bag bar. The **Micro menu** and **Bag bar** rows of **Fading** still fade them, and the same rows of **Hidden frames** still hide them. A change to this row applies after a reload. See [Action bars](Action-bars) for Flat UI's own buttons and the **Bar block** page.

### UI scale

The **Scale** section sets the game's own UI scale for you, so the whole interface grows or shrinks together.

- **Custom UI scale** turns the section on. The scale changes out of combat. A change made in a fight waits for its end. While the options window is open, chat says so once a fight: "Flat UI: the UI scale changes when the fight ends."
- **Custom scale** picks a scale from 65% to 115%.
- **Pixel-perfect scale** works the scale out from your screen's height, so one interface unit becomes a whole number of screen pixels. **Pixels per unit** sets how many, from 1 to 4. It is used while that scale falls between 65% and 115%, or between 35% and 65% while **Scale below 65%** is on.
- **Scale below 65%** is on as Flat UI comes. It uses **Small scale**, from 35% to 64%, in place of **Custom scale**. At these sizes the game can refuse presses of its own action buttons. Turning this row off needs a `/reload`.

**Custom scale** is greyed and reads "not used now" while **Pixel-perfect scale** or **Scale below 65%** sets the scale, and **Small scale** does the same while **Pixel-perfect scale** sets it.

| Command | What it does |
| --- | --- |
| `/flatui scale 80` | From 65 to 115: uses **Custom scale** at that value and turns **Pixel-perfect scale** and **Scale below 65%** off. From 35 to 64: uses **Small scale** with **Scale below 65%** on. Chat says what came of it. |
| `/flatui scale off` | Turns **Custom UI scale** off, so the game's own scale comes back. Chat says when a `/reload` is needed to finish. |

### Colours tab

The **Colours** tab holds the colours that many pages share.

**Cast colours** set the fill of flat cast bars, those of the **Cast bars** page and those on nameplates:

- **Cast colour**, **Channel colour**, **Uninterruptible colour**, **Interrupted colour** (also shown when a cast fails) and **Crafting colour**.
- **Finish flash** is the glow as a cast or channel ends: **In the cast colour**, **The game's** (gold for a cast, green for a channel) or **Off**.
- **Interrupt readiness on enemy casts** is on as Flat UI comes. An enemy cast you can interrupt shows whether your class interrupt is ready, in **Interrupt ready colour**, still cooling, in **Interrupt on cooldown colour**, or ready but out of range, in **Interrupt out of range colour**. It shows on the fill of flat target, focus and nameplate cast bars. With **Flat fill** off on the **Cast bars** page, it shows on a thin strip along the bottom of the target and focus cast bars, as thick as **Interrupt strip height**. A cast that cannot be interrupted keeps its colour.

See [Frames and bars](Frames-and-bars) for the cast bars themselves.

**Borders** has one row, **Border colour source**: **Border colour on the Flat UI page**, **Your class colour** or **Your faction colour**.

**Reaction** colours the unit frames that colour by reaction, their name rows too. Tick **Custom reaction colours** to set your own **Hostile**, **Neutral**, **Friendly** and **Tapped by another player** colours. Off, the game's colours are used.

**Power** works the same way. Tick **Custom power colours** to set your own **Mana**, **Rage**, **Energy**, **Focus** and **Runic power** colours for the power bars Flat UI draws.

**Health left** holds three colours: **Colour at full health**, **Colour at half health** and **Colour at low health**. A health bar shades between them as health drops, wherever its page has the row turned on: **Colour health bars by health left** for unit frames and nameplates, and **Colour health by health left** for the personal resource display.

### Options and setup tab

This tab sets the look of the options window itself (accent colour, tone, density, sidebar and the movers grid), what setup and the welcome screen do on a new character, the Flat UI button in the game menu and the What's new window. See [Getting started](Getting-started) for each of its rows.

## Fonts

The **Fonts** page changes the typefaces and size of the game's text. It is off as Flat UI comes: tick **Replace the game's fonts** to use it. Other addons that use the game's fonts change with it. Turned off, every font is put back.

A preview band at the top of the page shows a title, a body line, a number line and small print in your chosen faces, outline, shadow and size, beside the game's pop-up text. It follows each change, and pointing at a line finds its row.

### Typefaces

- **Interface font** takes the place of the game's main typeface: windows, labels and most game text.
- **Number font** takes the place of the narrow typeface the game uses for numbers.
- **Title font** takes the place of the typeface the game uses for titles.

Each can be **Game font**, **Friz Quadrata**, **Arial Narrow**, **Morpheus** or **Skurri**, as far as the game can load them. The list shows a sample of each face while **Samples in lists** is on.

Chat text and nameplate text are left to their own pages: **Chat font** on the **Chat text** tab of **Chat** (see [Chat and windows](Chat-and-windows)), and **Text font** on the **Text** tab of **Nameplates** (see [Nameplates](Nameplates)).

The typefaces change only in a game client whose language uses the Latin alphabet. In other clients the game's own typefaces stay, and the rest of the page still applies.

### Style

- **Text outline**: **As the game has it**, **None**, **Thin** or **Thick**.
- **Text shadow** is on as Flat UI comes.
- **Text size** scales the game's text from 80% to 130%. Narrow frames can clip long names at the larger sizes.
- **Smallest text** raises any game text smaller than this size. At 0 it leaves sizes alone.

### Game setting

**Game text size** is the game's own text size for pop-ups, dialogs and settings, from 80% to 150%. Flat UI shows it here so you find it with the other font rows.

A change to the **Fonts** page made in a fight waits for the fight's end. While the options window is open, chat says once "Flat UI: fonts change when the fight ends."

Every setting of this group, with its default: [Settings: Look](Settings-Look).
