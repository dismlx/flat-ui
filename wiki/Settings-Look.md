Every setting of the **Look** group of the options window, 69 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Look](Look).

Pages: [Flat UI](#flat-ui) · [Fonts](#fonts)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.47.

## Flat UI

### General

**Borders and backgrounds**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border thickness** | 1 px | Settings and frame positions belong to the profile in use. Profiles are in the options window. |
| **Border colour** | #000000 |  |
| **Borderless** | On | Coloured borders stay: threat, Elite and Rare, debuff type, item quality. |
| **Background colour** | #0F0F0F |  |
| **Background opacity** | 75% | Windows have their own opacity on the Windows page. |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Bar texture** | Soft shade | Used on every bar that has a flat fill. Choices: Flat, Soft shade, Shaded, Gloss, Stripes, Bottom edge, Side fade, Game status bar, Skills bar, Targeting bar. |

**Game action bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Leave the game's action bars alone** | On | Flat UI does not move, group or fade the game's action bars that no block of the Bar block page holds, its stance and pet bars, or the game's experience bar while Experience bar is The game's, and does not move the micro menu or the bag bar (Fading's Micro menu and Bag bar rows still fade them, and Hidden frames' Micro menu and Bag bar rows still hide them). The game's Options page has one button that opens Flat UI. Applies after a reload. A change takes full effect after a reload. |

**Scale**

| Setting | Default | Notes |
| --- | --- | --- |
| **Custom UI scale** | On | Sets the game's own UI scale. Applies out of combat. |
| **Custom scale** | 65% | Not used while Pixel-perfect scale or Scale below 65% is on: they set the scale then. Needs **Custom UI scale** on. |
| **Pixel-perfect scale** | Off | One interface unit becomes a whole number of screen pixels. Applied only between 65% and 115%. Needs **Custom UI scale** on. |
| **Pixels per unit** | 1 px | Needs **Pixel-perfect scale** on. |
| **Scale below 65%** | On | The game can refuse presses of its own action buttons at these sizes. /reload after turning it off. Needs **Custom UI scale** on. Turning it off takes full effect after a reload. |
| **Small scale** | 60% | Used instead of Custom scale. Not used while Pixel-perfect scale is on: it sets the scale then. Needs **Scale below 65%** on. |

### Colours

**Cast colours**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cast colour** | #E6B333 |  |
| **Channel colour** | #4DBF59 |  |
| **Uninterruptible colour** | #9A9A9A |  |
| **Interrupted colour** | #D94040 | Also shown when a cast fails. |
| **Crafting colour** | #4D99E6 |  |
| **Finish flash** | In the cast colour | The glow as a cast or channel ends, on flat cast bars and nameplate cast bars. The game's is gold for a cast and green for a channel. Choices: In the cast colour, The game's, Off. |
| **Interrupt readiness on enemy casts** | On | An enemy cast you can interrupt shows whether your class interrupt is ready: on the fill of flat target, focus and nameplate cast bars, and with Flat fill off on a thin strip along the bottom of the target and focus bars. A cast that cannot be interrupted keeps its colour. |
| **Interrupt ready colour** | #33D959 | Needs **Interrupt readiness on enemy casts** on. |
| **Interrupt on cooldown colour** | #D9732E | Needs **Interrupt readiness on enemy casts** on. |
| **Interrupt out of range colour** | #7F8FA6 | While your interrupt is ready but the caster is out of its range. Needs **Interrupt readiness on enemy casts** on. |
| **Interrupt strip height** | 2 px | With Flat fill off: how thick the strip along the bottom of the target and focus cast bars is, in screen pixels. Needs **Interrupt readiness on enemy casts** on. |

**Borders**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border colour source** | Border colour on the Flat UI page | Choices: Border colour on the Flat UI page, Your class colour, Your faction colour. |

**Reaction**

| Setting | Default | Notes |
| --- | --- | --- |
| **Custom reaction colours** | Off | Used by unit frames that colour by reaction, name rows too. |
| **Hostile** | #FF0000 | Needs **Custom reaction colours** on. |
| **Neutral** | #FFFF00 | Needs **Custom reaction colours** on. |
| **Friendly** | #00FF00 | Needs **Custom reaction colours** on. |
| **Tapped by another player** | #808080 | Needs **Custom reaction colours** on. |

**Power**

| Setting | Default | Notes |
| --- | --- | --- |
| **Custom power colours** | Off |  |
| **Mana** | #0000FF | Needs **Custom power colours** on. |
| **Rage** | #FF0000 | Needs **Custom power colours** on. |
| **Energy** | #FFFF00 | Needs **Custom power colours** on. |
| **Focus** | #FF8040 | Needs **Custom power colours** on. |
| **Runic power** | #00D1FF | Needs **Custom power colours** on. |

**Health left**

| Setting | Default | Notes |
| --- | --- | --- |
| **Colour at full health** | #2EB84D |  |
| **Colour at half health** | #E6C12E |  |
| **Colour at low health** | #D93A30 |  |

### Options and setup

**Options window**

| Setting | Default | Notes |
| --- | --- | --- |
| **Accent colour** | Indigo | Marks the chosen item, a switch that is on and the scroll bar in the options window. Choices: Indigo, Sage, Amber, Rose, Ice, Class colour, Custom. |
| **Custom accent colour** | #9A9CF0 | Needs **Accent colour** at Custom. |
| **Window tone** | Graphite | Follow background colour uses the Background colour of the General tab. A light colour can make the window hard to read. Choices: Graphite, Ink, Follow background colour. |
| **Borders** | None | Hairline draws a thin line around the window, the buttons and the controls. Row dividers stay either way. Choices: None, Hairline. |
| **Corners** | Square | Choices: Square, Soft, Round. |
| **Density** | Comfortable | The height of a row and the size of the text. Choices: Compact, Comfortable, Roomy. |
| **Window font** | Flat UI Sans | Flat UI Sans is IBM Plex Sans. If the game cannot load it, the window uses the game font. Choices: Flat UI Sans, Game font, Arial Narrow. |
| **Window scale** | 100% | A window larger than the screen is made smaller to fit. Ctrl and the mouse wheel over the title bar of the window change it too. |
| **Sidebar** | Icons and names | The list of pages at the left of the options window. Choices: Icons and names, Names only, Icon rail. |
| **Sections** | Cards | Cards put the rows of a section on a panel that folds. Lines show a heading with a line under it. Choices: Cards, Lines. |
| **Previews** | On | A drawing above the settings of a page. Collapsed leaves a bar to open it. Choices: On, Collapsed, Off. |
| **Movers grid** | Dim | Lines every 32 units behind the frames while you move them. Choices: Off, Dim, Bright. |
| **Samples in lists** | On | A small picture beside each bar texture, font and row direction in a list. Choices: On, Off. |
| **Snap to other frames** | On | A guide shows when an edge or the middle of a handle lines up with another handle within 5 units. Choices: On, Off. |

**Setup**

| Setting | Default | Notes |
| --- | --- | --- |
| **Profile on a new character** | `ask` | Used once, on a character with no profile of its own. |
| **Welcome screen shows** | New character with no profile | First login on the account shows it only while no character has a profile. Choices: New character with no profile, First login on the account. |
| **Keep this look uses** | Default profile | The game's look uses a profile named Game look, with every Flat UI module off. Choices: Default profile, The game's look. |
| **Setup result in chat** | One line | One line says in chat which profile is in use when setup finishes. Choices: One line, None. |

**Game menu**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flat UI button in the game menu** | On | A Flat UI button under Options. It does not work in combat, and it does not show while the game's taintLog is on. |
| **Flat UI button opens** | Options window | Choices: Options window, Flat UI setup. Needs **Flat UI button in the game menu** on. |

**Updates**

| Setting | Default | Notes |
| --- | --- | --- |
| **What's new after an update** | Show the window | What shows at the first login after Flat UI updates, once on the account for each version. /flatui new opens the What's new window at any time. Choices: Show the window, One line in chat, Nothing. |

## Fonts

| Setting | Default | Notes |
| --- | --- | --- |
| **Replace the game's fonts** | Off | Other addons that use the game's fonts change too, and off puts every font back. |

**Typefaces**

| Setting | Default | Notes |
| --- | --- | --- |
| **Interface font** | `default` | Windows, labels and most game text. |
| **Number font** | `default` |  |
| **Title font** | `default` |  |

**Style**

| Setting | Default | Notes |
| --- | --- | --- |
| **Text outline** | `game` |  |
| **Text shadow** | On |  |
| **Text size** | 100% | Narrow frames can clip long names. |
| **Smallest text** | 0 | Raises any game text smaller than this. 0 leaves sizes alone. |

**Game setting**

| Setting | Default | Notes |
| --- | --- | --- |
| **Game text size** | 100% | The game's own text size for pop-ups, dialogs and settings. Sets the game's `userFontScale`. |
