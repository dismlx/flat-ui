Every setting of the **Chat and windows** group of the options window, 127 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Chat and windows](Chat-and-windows).

Pages: [Chat](#chat) · [Tooltips](#tooltips) · [Windows](#windows)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.51.

## Chat

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle chat and tooltips** | On | One switch for Chat, Tooltips, Spell tooltips and Gear comparison. |

**Chat windows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Chat window background** | On |  |
| **Chat window opacity** | 60% | Replaces the opacity in the chat window settings. Needs **Chat window background** on. |
| **Chat tabs** | On |  |
| **Chat tab opacity** | Selected 100%, others 60% | How bright the tab names are. Choices: As the game has it, Selected 100%, others 60%, All 100%. Needs **Chat tabs** on. |
| **Chat button background** | On |  |
| **Chat window border** | On | Needs **Chat window background** on. |

**Chat input**

| Setting | Default | Notes |
| --- | --- | --- |
| **Chat input box** | On |  |
| **Input box position** | Below the chat window | Choices: Below the chat window, Above the chat window. |
| **Input box opacity when idle** | 35% |  |
| **Border while typing** | Chat type colour | Choices: Chat type colour, Highlight colour, Plain border. Needs **Chat input box** on. |
| **Letters left while typing** | On | Once 50 or fewer letters are left in a chat line, a small count at the right of the input box shows how many, amber at 20 and red at 0. A link counts only its name, and the typed text stops short of the count while it shows. Needs **Chat input box** on. |
| **Arrow keys without Alt** | On | While you type, the arrow keys move the cursor and Up and Down bring back the lines you sent. Off, they turn and move your character as the game has it, and edit the text with Alt held. |

**Border and background**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own border and background** | Off |  |
| **Border colour** | #000000 | Needs **Own border and background** on. |
| **Background colour** | #0F0F0F | Needs **Own border and background** on. |
| **Background opacity** | 85% | Needs **Own border and background** on. |

### Chat text

**Game settings**

| Setting | Default | Notes |
| --- | --- | --- |
| **Timestamps** | None | Choices: None, 03:27, 03:27:32, 03:27 PM, 03:27:32 PM, 15:27, 15:27:32. Sets the game's `showTimestamps`. |
| **Class colours in chat** | Always | Choices: Always, Never, Per channel. Sets the game's `chatClassColorOverride`. |

**Font**

| Setting | Default | Notes |
| --- | --- | --- |
| **Chat font** | `default` |  |
| **Chat text outline** | `game` |  |
| **Chat text shadow** | On |  |

**History and fading**

| Setting | Default | Notes |
| --- | --- | --- |
| **Lines kept per window** | 128 lines |  |
| **Fade old messages** | On |  |
| **Fade after** | 120 s | Needs **Fade old messages** on. |
| **Show recent chat after a reload** | Off | Each time you reload or log in, the lines of the last hour show again in your main chat window: say, yell, emotes, party, raid, guild, officer and whispers. They are kept in Flat UI's saved settings of this character; lines the game withholds in fights and dungeons are not kept. |
| **Lines to show again** | 50 lines | None older than an hour, and no more than three quarters of Lines kept per window, so that the other lines of a login stay in the window. Needs **Show recent chat after a reload** on. |
| **Numbered channels too** | Off | General, Trade and the other numbered channels: in Copy recent chat, and after a reload with Show recent chat after a reload. |
| **Copy recent chat** |  | Opens a box with the last lines Flat UI heard, ready for Ctrl+C: say, yell, emotes, party, raid, guild, officer and whispers. Numbered channels too adds General, Trade and the other numbered channels. Each reads as [21:04] [Party] [Mara]: text, links as their name in brackets. Not in a fight. /flatui copy does the same. Ctrl+A selects every line again after a click in the box. A key for it is under Flat UI in the game's Key Bindings. |

**Channels**

| Setting | Default | Notes |
| --- | --- | --- |
| **Channel names** | Number and name ([2. Trade]) | The label before a line of General, Trade, LocalDefense and the other numbered channels. A click on it still opens the channel. Choices: As the game has it ([2. Trade - City]), Number and name ([2. Trade]). |

**Links**

| Setting | Default | Notes |
| --- | --- | --- |
| **Web addresses as links** | On | A web address in a chat line becomes a link. A click on it shows the address selected in a box, ready to copy; Ctrl+C there closes the box a moment later. Not in a fight: chat then says to click it again after. |
| **Tooltips of chat links** | On | While the mouse is over an item, spell, achievement or quest link in a chat window, its tooltip shows. Not in a fight. |

**Mentions**

| Setting | Default | Notes |
| --- | --- | --- |
| **Your name in chat** | On | Your name in what other players write in say, yell, emotes, party, raid, guild, officer and the numbered channels shows in a colour of its own. Not in whispers, and only the whole name. |
| **Your name colour** | #FF9933 | Needs **Your name in chat** on. |
| **Sound when you are named** | None | Once for each line that names you, at most once a second. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Your name in chat** on. |
| **Light the tab that names you** | On | When a line names you in a chat window whose tab is not chosen (a Trade, Guild or LFG tab), that tab's box and label take Your name colour with a slow pulse until you click the tab, and a small number at its top right corner counts the lines that named you there (up to 9+). Needs Chat tabs on the Chat page. Needs **Your name in chat** on. |
| **Flash the game's icon when you are named** | On | While the game is in the background, its icon on the taskbar or dock flashes for a line that names you, as it does for a whisper; at most once every 10 seconds. Needs **Your name in chat** on. |
| **Other words to colour** |  | Add a word... opens a box: type the word and press Enter. Up to 20 for all your characters: whole words, any case, in Your name colour and with Sound when you are named. Choose a word to stop colouring it. /flatui words add tank does the same. Needs **Your name in chat** on. |

## Tooltips

### General

**Tooltips**

| Setting | Default | Notes |
| --- | --- | --- |
| **Tooltip border and background** | On |  |
| **Tooltip background** | Near black | Choices: Near black, Black, Dark blue, Dark brown. Needs **Tooltip border and background** on. |
| **Tooltip opacity** | 70% | Needs **Tooltip border and background** on. |
| **Tooltip shading** | Flat | Choices: Flat, Lighter at the top, Darker at the bottom. Needs **Tooltip border and background** on. |
| **Item quality border** | On | Border takes the colour of the item name. Needs **Tooltip border and background** on. |
| **Elite and Rare on tooltips** | On | A line at the end of the tooltip: Elite, Rare, Rare Elite or Boss. Needs **Tooltip border and background** on. |
| **Elite and Rare tooltip border** | On | Gold for an Elite, silver for a Rare, red for a Boss. Needs **Tooltip border and background** on. |

**Tooltip panel**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own border colour** | Off |  |
| **Border colour** | #000000 | Needs **Own border colour** on. |

**Unit colours**

| Setting | Default | Notes |
| --- | --- | --- |
| **Unit tooltip border** | Plain | Choices: Plain, Reaction colour, Class colour for players. |
| **Class colour on player names** | On |  |
| **Raid marker on the name** | On | The skull, moon or other raid marker a unit carries shows as a small icon before its name on its tooltip. |
| **Away and busy after the name** | On | A player who is away or busy has a dim &lt;AFK&gt; or &lt;DND&gt; after their name on their tooltip. |
| **Class colour on the class line** | On | The line with the level, race and class of a player. |
| **Guild colour and rank** | On | The guild line of a player: green for your own guild, blue for another, with the member's rank after it. |

**Size and text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Tooltip size** | 100% |  |
| **Title size** | 100% |  |
| **Text size** | 100% |  |

**Tooltip health bar**

| Setting | Default | Notes |
| --- | --- | --- |
| **Health bar border and fill** | On |  |
| **Bar texture** | `default` | Needs **Health bar border and fill** on. |
| **Health bar colour** | Class colour for players, reaction for the rest | The colour of the health bar under a unit's tooltip, kept through every change of its health, also in a fight. Choices: Class colour for players, reaction for the rest, Green, as the game has it. Needs **Hide the health bar** at False. |
| **Hide the health bar** | Off |  |
| **Health bar height** | 8 px | Needs **Hide the health bar** at False. |
| **Health text on the bar** | Percent | The health of the unit in a small outlined text on the tooltip's health bar, kept up to date while you point at the unit, also in a fight. Its size follows Health bar height, and a bar under 5 px has none; a dead unit reads Dead. Choices: None, Percent, Current / max, Current and percent. Needs **Hide the health bar** at False. |

### Combat and extra lines

**Fade**

| Setting | Default | Notes |
| --- | --- | --- |
| **Fade out** | Fast | Choices: As the game has it, Fast, At once. |

**Combat**

| Setting | Default | Notes |
| --- | --- | --- |
| **Tooltips in combat** | Show as usual | Choices: Show as usual, Hide unit tooltips, Hide every tooltip. |
| **Show anyway while holding** | No key | Choices: No key, Shift, Ctrl, Alt. |
| **Unit tooltips hidden** | Every unit | A unit the game will not say about is shown. Choices: Every unit, Enemies, Friendly units. Needs **Tooltips in combat** at Hide unit tooltips. |
| **Where** | In combat | With In combat in dungeons and raids, tooltips show in fights in the open world. Choices: In combat, In combat in dungeons and raids. Needs **Tooltips in combat** at Hide unit tooltips or Hide every tooltip. |
| **Spell tooltips** | Show | Show anyway while holding still shows them. Choices: Show, Hide in combat, Hide in dungeons and raids, Hide always. |
| **Buff and debuff tooltips** | Show | Your own buffs and debuffs, and those on party and raid frames. The target and focus frames show theirs in a tooltip of the game's own that Flat UI cannot hide. Show anyway while holding still shows them. Choices: Show, Hide in combat, Hide in dungeons and raids, Hide always. |
| **Item tooltips** | Show | Show anyway while holding still shows them. Choices: Show, Hide in combat, Hide in dungeons and raids, Hide always. |
| **Party and raid frame tooltips** | As other units | The unit tooltips of the game's party and raid frames, whose clicks do not change. The box of buffs and debuffs that opens beside a party frame still shows. Choices: As other units, Out of combat only, Only with a key, Off. |
| **Key for party and raid frames** | Shift | Hold it as you point at one of these frames, and its tooltip shows, unless Tooltips in combat hides it. Choices: Shift, Ctrl, Alt. Needs **Party and raid frame tooltips** at Only with a key. |

**Extra lines**

| Setting | Default | Notes |
| --- | --- | --- |
| **Item, spell, quest and NPC IDs** | On | A grey line at the end of the tooltip: Item ID, Spell ID, Quest ID on a quest link, Currency ID on a currency, and on a creature NPC ID. |
| **Icon ID** | Off | The number of the icon file, after the ID line. Needs **Item, spell, quest and NPC IDs** on. |
| **Show IDs** | Always | The IDs show while the key is held: at once over bags, action bars and the Character window, and over a link once you point at it again. Choices: Always, While holding Shift, While holding Ctrl, While holding Alt. Needs **Item, spell, quest and NPC IDs** on. |
| **Temporary enchant ID** | On | On a weapon you wear: the ID of its poison, oil, stone or imbue. Needs **Item, spell, quest and NPC IDs** on. |
| **Item count in bags and bank** | On | How many you carry, and with your bank. When Counts in tooltips on the Bags page names this character, its line takes this one's place. |
| **Item level** | On | On armor and weapons, as Item level 63 in gold, also in the comparison beside them. |
| **Item and spell icons** | On | The icon before the name of an item, a spell, a buff or a debuff: not on the target and focus frames, whose buff tooltip is the game's own. |
| **Who cast a buff or debuff** | On | A grey line under a buff's or debuff's tooltip naming who cast it, in their class colour: You, your pet, a group member, a group member's pet (as Mara's pet (Imp)) or an enemy. On your own buffs and debuffs and those on party and raid frames. The target and focus frames use a tooltip of the game's own that Flat UI cannot add to. |
| **Target of units** | On | A line naming what a unit targets, in its class or reaction colour: You when it is you, in red while it is a unit you can attack. |
| **Who in your group targets it** | On | In a party or raid, a grey line under a unit's tooltip naming the members whose target it is, in their class colours: at most six, then +N. Kept up to date while you point at the unit, and it shows as soon as a first member takes it. |

**Item comparison**

| Setting | Default | Notes |
| --- | --- | --- |
| **Compare items only while holding Shift** | On | The items you wear show beside the tooltip of an item only while you hold Shift. Sets a game setting that the game's options do not show. Turned off, the game's own value is back. |
| **Hint while Shift is up** | On | An item you could wear ends its tooltip with a dim line, Shift: compare with what you wear, and your spells while the gear lines wait for the comparison. It goes once you hold Shift; not on the items you wear. Needs **Compare items only while holding Shift** on. |

## Windows

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle windows** | On | Also Which windows and Item slots. Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Theme** | Flat | Dark side gives the game's windows, Flat UI's own windows (bags and bank, gear comparison, item finder, trinket queue, What's new, copy boxes) and the options window near-black backgrounds and deep red borders, with titles, the chosen tab, highlights and ticked check boxes in a deep red, and a faint red glow round each window that brightens a little while you point at it. Your colours below and the options window's accent stay as you set them, for Flat. Choices: Flat, Dark side. |
| **Window opacity** | 80% |  |
| **Button and slot colour** | #1E1E1E |  |
| **Highlight colour** | #D9D9D9 |  |
| **Icon crop** | 9% | Trims the edge of each icon. |
| **Show portrait** | Off | The round picture at the top left of a window. |

**Controls**

| Setting | Default | Notes |
| --- | --- | --- |
| **Buttons** | On |  |
| **Tabs** | On |  |
| **Side tabs** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Square side tab icons** | On | Needs **Side tabs** on. |
| **Side tab size** | Small | The icon tabs of the Character, Inspect, Collections, Looking For Group, bank and Professions windows. Choices: Game's size, Large, Medium, Small. Needs **Side tabs** on. |
| **Scroll bars** | On |  |
| **Check boxes** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Text boxes and dropdowns** | On |  |
| **Progress bars** | On |  |

**Menus, lists and toasts**

| Setting | Default | Notes |
| --- | --- | --- |
| **Right-click and dropdown menus** | On |  |
| **Chat name completion list** | On |  |
| **Battle.net toasts** | On |  |
| **List rows and headers** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |

**Window art**

| Setting | Default | Notes |
| --- | --- | --- |
| **Race background on the Character window** | Off | The picture behind your character. |
| **Spellbook parchment** | Off | The game's parchment pages with their dark text. Off, the pages are dark with light text. |
| **Dark quest, gossip and book pages** | On | The game's Quest Text Contrast at Dark: quest, gossip, book and quest log pages dark with light text, for the whole account. Off, the parchment and the contrast you had. A page already open changes the next time it opens. |
| **Talent window backdrop** | Off | The class picture behind the talents and the Legacy pages. |
| **Looking For Group eye** | Off |  |
| **Looking For Group role backgrounds** | Off |  |

**Title**

| Setting | Default | Notes |
| --- | --- | --- |
| **Title size** | 100% |  |
| **Own title colour** | Off |  |
| **Title colour** | #FFD100 | Needs **Own title colour** on. |

**Other addons**

| Setting | Default | Notes |
| --- | --- | --- |
| **RestedXP's windows** | On | While that guide addon is loaded: its guide window and the steps in it, its arrow, its item and target buttons, its menus and its other windows take Flat UI's flat backdrop, thin border, bar texture and the fonts of the Fonts page, in the colours of Theme. Without it this row does nothing, and its own settings are never changed. Off gives it its own look back, in full after /reload. |

### Which windows

| Setting | Default | Notes |
| --- | --- | --- |
| **Character** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Looking For Group** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Friends, channels and raid** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Vendor, mail, quest, trade and trainer** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Bags and bank** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Spellbook, talents, professions and legacy** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Game menu, options and pop-ups** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Auction house** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Guild, communities and guild bank** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Inspect and dressing room** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Macros and help** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **World map and flight map** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
| **Collections, stable, sockets and other windows** | On | Turning this off takes full effect after /reload. Turning it off takes full effect after a reload. |
