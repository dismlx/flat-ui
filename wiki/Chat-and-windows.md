The **Chat and windows** group styles the chat windows, the tooltips and the game's windows. It also adds a few helpers to chat: web addresses you can copy, your name in colour when someone writes it, and a box to copy recent chat.

## Chat

**Restyle chat and tooltips** (on), at the top of the **Chat** page, is one switch for **Chat**, **Tooltips**, **Spell tooltips** and **Gear comparison**. The last two sit under **Character and gear**; see [Character and gear](Character-and-gear).

The **Chat** page has two tabs: **General** for the look of the chat windows and the input box, and **Chat text** for what the lines say.

### General tab

#### Chat windows

- **Chat window background** (on) gives each chat window a flat background, at **Chat window opacity** (60%). This replaces the opacity in the game's chat window settings. **Chat window border** (on) adds a thin border.
- **Chat tabs** (on) styles the tabs. **Chat tab opacity** sets how bright the tab names are: **Selected 100%, others 60%** (the default), **All 100%** or **As the game has it**.
- **Chat button background** (on) styles the buttons beside the chat.

#### Chat input

- **Chat input box** (on) styles the box you type in. **Input box position** is **Below the chat window** (the default) or **Above the chat window**, and **Input box opacity when idle** (35%) dims it while you are not typing.
- **Border while typing** colours the box's border as you type: **Chat type colour** (the default), **Highlight colour** or **Plain border**.
- **Letters left while typing** (on): once 50 or fewer letters are left in a line, a small dim number at the right of the box counts down what is left, amber at 20 and red at 0. A long raid call or trade post is then not cut off without warning. A link counts only its name.
- **Arrow keys without Alt** (on): while you type, the arrow keys move the cursor, and Up and Down bring back the lines you sent, as in any text box. Off, they turn and move your character as the game has it, and edit the text only with Alt held.

#### Border and background

**Own border and background** (off) gives the chat its own **Border colour**, **Background colour** and **Background opacity** (85%).

### Chat text tab

#### Game settings

**Timestamps** (**None** by default, or a time such as **15:27** or **03:27 PM**) and **Class colours in chat** (**Always** by default, or **Never** or **Per channel**) set the game's own settings, so you can change them here.

#### Font

**Chat font**, **Chat text outline** and **Chat text shadow** (on) set the look of the chat lines.

#### History and fading

- **Lines kept per window** (128, up to 2048) sets how far back you can scroll.
- **Fade old messages** (on) fades lines after **Fade after** (120 s).
- **Show recent chat after a reload** (off): each time you reload or log in, the lines of the last hour show again in your main chat window. That covers say, yell, emotes, party, raid, guild, officer and whispers. **Lines to show again** (50, 10 to 200) sets how many. They are kept in this character's saved settings. Lines the game withholds in fights and dungeons are not kept.
- **Numbered channels too** (off) adds General, Trade and the other numbered channels, both after a reload and in **Copy recent chat**. It works on its own, with **Show recent chat after a reload** off too.

#### Copy recent chat

**Copy recent chat** opens a tall box with the last lines Flat UI heard, ready to copy. Open it in any of three ways:

- Pick **The last 50 lines** or **The last 200 lines** in the **Copy recent chat** row.
- Type `/flatui copy`, or `/flatui copy 200` for up to 200 lines.
- Press a key of your own: bind **Copy recent chat** under **Flat UI** in the game's Key Bindings. The same key closes the box.

The box holds say, yell, emotes, party, raid, guild, officer and whispers, and with **Numbered channels too** the numbered channels. With **Show recent chat after a reload** on, it also holds lines from before your last reload. Each line reads as "[21:04] [Party] [Mara]: text", with links as their name in brackets and colours left out.

Every line is selected as the box opens, so Ctrl+C copies them all and the line over the box says "Copied 50 lines." To copy a part, drag over it, or use Shift and the arrows. After a click in the box, Ctrl+A (Cmd+A on a Mac) selects every line again. Escape closes the box. It never opens in a fight.

#### Channels

**Channel names** is **Number and name ([2. Trade])** by default. The lines of General, Trade, LocalDefense and the other numbered channels then read "[2. Trade]" and "[1. General]" in place of "[2. Trade - City]" and "[1. General - Elwynn Forest]". A click on the label still opens the channel. **As the game has it ([2. Trade - City])** gives the long names back.

#### Links

- **Web addresses as links** (on): a web address in a chat line becomes a link. Click it for a box with the address selected, ready to copy. Ctrl+C there says "Copied." and closes the box a moment later, so your keys move your character again. Not in a fight: chat then says to click it again after.
- **Tooltips of chat links** (on): while the mouse is over an item, spell, achievement or quest link in a chat window, its tooltip shows. A quest's shows its level, text and objectives. Not in a fight.

#### Mentions

**Your name in chat** (on) colours your name where another player writes it in say, yell, an emote, party, raid, guild, officer or a numbered channel such as Trade. It shows in **Your name colour**, a bright orange. It matches the whole name only, in any case, never inside a link or a web address, and not in whispers or your own lines.

- **Sound when you are named** (**None** by default, or **Spell alert**, **Chimes**, **Bell**, **Warhorn**, **Raid warning**, **Alarm** or **Whisper warning**) plays once for each line that names you, at most once a second. Picking a sound plays it.
- **Light the tab that names you** (on) needs **Chat tabs** on the **General** tab. A chat tab you are not looking at, such as Trade, Guild or LFG, lights up in **Your name colour** with a slow, soft pulse when a line in it names you. A small number at its top right corner counts those lines, up to "9+". It goes back as you click the tab.

**Other words to colour** colours more words the same way, with the same sound: "tank", the name of your alt, or your guild's raid call word.

- Its first line, **Add a word...**, opens a small box. Type the word and press Enter, or press Escape to close it. A word it will not take says why.
- Pick a word in the list to stop colouring it.
- You can keep up to 20 words, for all your characters. Each is one word of 2 to 24 letters with no space. Only whole words match, in any case.
- `/flatui words add tank`, `/flatui words remove tank` and `/flatui words` do the same from chat.

## Tooltips

The **Tooltips** page has two tabs: **General** for the look of every tooltip, and **Combat and extra lines** for when tooltips show and what they add. Where the tooltip sits on screen is set on the **Tooltip position** page; see [Layout](Layout).

### General tab

#### Tooltips

- **Tooltip border and background** (on) gives tooltips a flat look. **Tooltip background** is **Near black** (the default), **Black**, **Dark blue** or **Dark brown**, at **Tooltip opacity** (70%). **Tooltip shading** is **Flat** (the default), **Lighter at the top** or **Darker at the bottom**.
- **Item quality border** (on) gives an item's tooltip a border in the colour of its name.
- **Elite and Rare on tooltips** (on) ends a creature's tooltip with a line: Elite, Rare, Rare Elite or Boss. **Elite and Rare tooltip border** (on) makes the border gold for an Elite, silver for a Rare and red for a Boss.
- **Own border colour** (off), under **Tooltip panel**, sets a **Border colour** of your own.

#### Unit colours

- **Unit tooltip border** is **Plain** (the default), **Reaction colour** or **Class colour for players**.
- **Class colour on player names** (on) and **Class colour on the class line** (on) colour a player's name and the line with their level, race and class.
- **Guild colour and rank** (on) colours a player's guild line green for your own guild and a soft blue for another, with their rank after the guild's name, as "Officer".

#### Size and text

**Tooltip size**, **Title size** and **Text size** (all 100%) size the tooltip, its first line and the rest.

#### Tooltip health bar

- **Health bar border and fill** (on) styles the health bar under a unit's tooltip, in **Bar texture**.
- **Health bar colour** is **Class colour for players, reaction for the rest** by default: a mage's bar in class blue, a hostile mob's in red and a neutral one's in yellow, kept through every change of health, in a fight too. **Green, as the game has it** gives the game's green back.
- **Hide the health bar** (off) takes the bar away. **Health bar height** is 8 px.
- **Health text on the bar** writes the unit's health on the bar in small outlined text, as 64% or 1.2k / 2k. It is **Percent** by default, or **Current / max**, **Current and percent** or **None**. It stays up to date while you point at the unit, also in a fight. Its size follows **Health bar height**, and a bar under 5 px has none. A dead unit reads Dead.

### Combat and extra lines tab

#### Fade

**Fade out** sets how a tooltip goes once you stop pointing at it: **Fast** (the default) ends the game's fade early, **At once** hides it straight away, and **As the game has it** keeps the game's fade.

#### Combat

- **Tooltips in combat** is **Show as usual** by default. **Hide unit tooltips** hides the tooltips of units in a fight, and **Unit tooltips hidden** then picks **Every unit** (the default), **Enemies** or **Friendly units**. **Hide every tooltip** hides them all in a fight.
- **Where**, for either kind of hiding, is **In combat** (the default) or **In combat in dungeons and raids**. With the second, tooltips still show in fights in the open world.
- **Show anyway while holding** (**No key** by default, or **Shift**, **Ctrl** or **Alt**) shows a hidden tooltip while you hold that key.
- **Spell tooltips**, **Buff and debuff tooltips** and **Item tooltips** each pick **Show** (the default), **Hide in combat**, **Hide in dungeons and raids** or **Hide always**. **Show anyway while holding** still shows them. **Buff and debuff tooltips** covers your own buffs and debuffs and those on party and raid frames; the target and focus frames use a tooltip of the game's own that Flat UI cannot hide.
- **Party and raid frame tooltips** covers the unit tooltips of the game's party and raid frames: **As other units** (the default), **Out of combat only**, **Only with a key** or **Off**. With **Only with a key**, hold **Key for party and raid frames** (**Shift** by default) as you point at a frame. Clicks on the frames do not change, and the box of buffs and debuffs beside a party frame still shows.

#### Extra lines

- **Item, spell, quest and NPC IDs** (on) ends a tooltip with a grey ID line: Item ID, Spell ID, "Quest ID: 5149" on a quest link, Currency ID on a currency, and "NPC ID: 448" on a creature. Players get none.
  - **Icon ID** (off) adds the number of the icon file after it.
  - **Show IDs** is **Always** by default, or **While holding Shift**, **While holding Ctrl** or **While holding Alt**.
  - **Temporary enchant ID** (on) shows, on a weapon you wear, the ID of its poison, oil, stone or imbue.
- **Item count in bags and bank** (on) adds a grey line such as "Count: 5 in bags, 25 with bank". When **Counts in tooltips** on the **Bags** page names this character, its line takes this one's place, so the count is not said twice. See [Bags and items](Bags-and-items).
- **Item level** (on) writes a weapon's or a piece of armour's level under the game's own lines, as "Item level 63" in gold. It shows on a quest reward, a chat link and a loot roll item too, and in the comparison beside it, so the levels stand side by side.
- **Item and spell icons** (on) puts the icon before the name of an item, a spell, a buff or a debuff. Not on the target and focus frames, whose buff tooltip is the game's own.
- **Who cast a buff or debuff** (on) ends a buff's or debuff's tooltip with a grey line naming who cast it, in their class colour: "Cast by Eli", "Cast by You", "Cast by your pet (Wolf)", or "Cast by Mara's pet (Imp)" for a group member's pet. On a debuff on a party member it names the enemy that put it there. It works on your own buffs and debuffs and those on party and raid frames.
- **Target of units** (on) adds a line naming what a unit targets, in its class or reaction colour. When it targets you it reads "You", in red while it is a unit you can attack.
- **Who in your group targets it** (on): in a party or raid, a grey line names the members whose target the unit is, as "Targeted by: Mara, Eli, Ivo" in class colours, at most six then +N. It stays up to date while you point at the unit, and reads "Targeted by: no one" once no one has it.

#### Item comparison

- **Compare items only while holding Shift** (on): the items you wear show beside an item's tooltip only while you hold Shift. This sets a game setting that the game's options do not show; turned off, the game's own value is back.
- **Hint while Shift is up** (on): an item you could wear ends its tooltip with a dim line, "Shift: compare with what you wear", which goes as you hold Shift. It reads "and your spells" too while the gear lines wait for the comparison. Not on the items you wear.

## Windows

**Restyle windows** (on), at the top of the **Windows** page, gives the game's windows a dark, flat look. It is also the switch for the **Which windows** tab and the **Item slots** page (under **Bags and items**; see [Bags and items](Bags-and-items)). Turning it off takes full effect after `/reload`.

The **Windows** page has two tabs: **General** for the look, and **Which windows** to choose the windows it styles.

### General tab

#### Look

- **Window opacity** (80%) sets how solid the windows are.
- **Button and slot colour** and **Highlight colour** colour the buttons, slots and highlights.
- **Icon crop** (9%) trims the edge of each icon.
- **Show portrait** (off) brings back the round picture at the top left of a window.

#### Controls

- **Buttons**, **Tabs**, **Scroll bars**, **Text boxes and dropdowns** and **Progress bars** (all on) style each kind of control.
- **Side tabs** (on) styles the icon tabs of the Character, Inspect, Collections, Looking For Group, bank and Professions windows. **Square side tab icons** (on) makes them square, and **Side tab size** is **Small** by default, or **Medium**, **Large** or **Game's size**.
- **Check boxes** (on) styles check boxes.

**Side tabs** and **Check boxes** take full effect after `/reload` when you turn them off.

#### Menus, lists and toasts

**Right-click and dropdown menus**, **Chat name completion list**, **Battle.net toasts** and **List rows and headers** (all on) style each of these. **List rows and headers** takes full effect after `/reload` when you turn it off.

#### Window art

These rows choose which of the game's pictures and page art the restyled windows keep. Each needs its window ticked on the **Which windows** tab.

- **Race background on the Character window** (off): the picture behind your character.
- **Spellbook parchment** (off): as Flat UI comes, the Spellbook has dark flat pages with light text. Spell names are white, the lines under them grey, and headers and the page number gold. Tick this row for the game's parchment pages and their dark text.
- **Dark quest, gossip and book pages** (on): the quest giver, gossip, book and letter pages and the quest log details are dark with light text. This sets the game's own Quest Text Contrast to Dark for your account, and the game draws the dark page itself. Off, the parchment and the contrast you had before come back. A page already open changes the next time it opens. `/flatui status` says when the game kept its own value.
- **Talent window backdrop** (off): the class picture behind the talents and the Legacy pages.
- **Looking For Group eye** (off) and **Looking For Group role backgrounds** (off).

#### Title

**Title size** (100%) sizes the window titles. **Own title colour** (off) colours them in **Title colour**, a gold.

### Which windows tab

Each row styles one family of the game's windows, and all are on:

- **Character**
- **Looking For Group**
- **Friends, channels and raid**
- **Vendor, mail, quest, trade and trainer**
- **Bags and bank**
- **Spellbook, talents, professions and legacy**
- **Game menu, options and pop-ups**
- **Auction house**
- **Guild, communities and guild bank**
- **Inspect and dressing room**
- **Macros and help**
- **World map and flight map**
- **Collections, stable, sockets and other windows**

Untick a row to leave those windows as the game draws them. Turning a row off takes full effect after `/reload`.

### Where windows open

Where a window opens, how you drag it and its size are set in the **Windows** section of the **Movers** page, under **Layout**. With **Open windows under the unit frames** (on), a window the game would open with its title over the player or target frame at the top of the screen, as it does with the Character window, the Spellbook, the map and Professions, opens just under them. A window beside it opens at the same height. A window you drag by its title stays where you put it. See [Layout](Layout).

## Commands

| Command | What it does |
| --- | --- |
| `/flatui copy` | Opens a box with the last 50 chat lines Flat UI heard, ready to copy. Not in a fight. |
| `/flatui copy 200` | The same with up to 200 lines. |
| `/flatui words` | Lists the other words coloured in chat as your name is. |
| `/flatui words add tank` | Colours a word in other players' lines as your name is, with the same sound. |
| `/flatui words remove tank` | Stops colouring it. |
| `/flatui status` | Says what is styled, with notes such as whether the game kept its own Quest Text Contrast. |

See [Commands](Commands) for every command.

Every setting of this group, with its default: [Settings: Chat and windows](Settings-Chat-and-windows).
