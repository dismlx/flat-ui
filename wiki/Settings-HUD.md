Every setting of the **HUD** group of the options window, 165 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [HUD](HUD).

Pages: [Minimap](#minimap) · [Buffs and debuffs](#buffs-and-debuffs) · [Quests and loot](#quests-and-loot) · [Messages and timers](#messages-and-timers) · [Experience and menu bars](#experience-and-menu-bars) · [Data panels](#data-panels)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.52.

## Minimap

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle the minimap and HUD** | On | One switch for Minimap, Buffs and debuffs, Quests and loot, Messages and timers, Experience and menu bars and the Hit table. |

**Minimap**

| Setting | Default | Notes |
| --- | --- | --- |
| **Hide minimap ring and header** | On | A rotating minimap loses its north pointer. |
| **Minimap border** | On | Thin border around the map, the zone name and the buttons beside it. |
| **Minimap in cities** | Flat round cover | Inside some cities the game shows its own city map in the minimap. Choices: Game's ring while the city map shows, Flat round cover, Leave as is. |
| **Minimap shape** | Square | Square takes the ring and pointer off the map. Choices: Round, Square. |
| **Zoom out after** | 0 s | Zooms the minimap back out to its widest this long after you zoomed it, with the mouse off it, a step at a time. The mouse over the map stops it. 0 is off. |
| **Day and night icon** | On |  |

**Zone name**

| Setting | Default | Notes |
| --- | --- | --- |
| **Zone name** | On |  |
| **Zone name size** | 100% |  |
| **Close the gap under the zone name** | Off | Brings the zone name, with the clock, calendar and tracking button beside it, to the map, which stays where it is. The mail icon and the addon list button, which the game puts between the zone name and the map, go to the other side of the zone name where they do not fit there. Off, the zone name keeps the game's place, which leaves room for the game's ring. With Edit Mode's Header underneath it comes up to the map. While the game's ring shows, and while Edit Mode is open, it keeps the game's place. |
| **Gap under the zone name** | 0 px | 0 lays the zone name on the map's border. It goes no further from the map than the game's place. Text you put above the map keeps its room under the zone name while it fits there, and goes below the map otherwise. Needs **Close the gap under the zone name** on. |

**Buttons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Tracking button** | On |  |
| **Mail icon** | On |  |
| **Calendar button** | On |  |
| **Clock** | On |  |
| **Addon list button** | On |  |
| **Addon buttons** | Column beside the map | Round buttons that other addons put on the minimap. Choices: Where each addon puts them, Column beside the map, Row under the map. |
| **Leave in place** |  | A button you tick stays where its addon puts it. Needs **Addon buttons** at Column beside the map or Row under the map. |
| **Flat addon buttons** | On | Gives each gathered button a square dark plate with a thin border in place of its round gold ring, and a light square when you point at it. A button you tick in Leave in place keeps its own art. Needs **Addon buttons** at Column beside the map or Row under the map. |

**Text around the map**

| Setting | Default | Notes |
| --- | --- | --- |
| **Coordinates** | On | Your place on the zone map. Hidden in instances, where the game gives no position, and while the game's own coordinates show under the map (the game's Options, Interface, Coordinates), so you see one line; turn those off for this one. Point at it for the zone and subzone; a click opens the world map, in a fight as it ends, and Shift-click puts the zone and coordinates in the chat box. |
| **Coordinates place** | Below the map | On the map, at the bottom puts the line just inside the map's bottom edge, outlined so it reads over the ground, raised on a round map to stay inside the circle. A line there takes no room under the map, so the addon button row and the zone name keep their place. Choices: Above the map, Below the map, On the map, at the bottom. Needs **Coordinates** on. |
| **Coordinate decimals** | One (45.3, 62.1) | Choices: None (45, 62), One (45.3, 62.1), Two (45.31, 62.08). Needs **Coordinates** on. |
| **Coordinates on the world map** | On | A small line at the bottom of the world map: You 45.2, 61.8 while you are on the map shown, and Cursor 33.0, 12.5 while the pointer is over the map, with Coordinate decimals. Your part is hidden in instances. |
| **Name of who pings the map** | On | The name of a group member who pings the minimap, in their class colour, by the ping for about 3 seconds, at Text size. Your own pings show none. |
| **Durability** | On | Your most worn equipped item. Yellow at 50% or less, red at 20% or less. Point at it for each item you wear; a click opens the character window, in a fight as it ends. |
| **Durability place** | Below the map | On the map, at the bottom puts the line just inside the map's bottom edge, outlined so it reads over the ground, raised on a round map to stay inside the circle. A line there takes no room under the map, so the addon button row and the zone name keep their place. Choices: Above the map, Below the map, On the map, at the bottom. Needs **Durability** on. |
| **Durability shows** | Always | The line comes as an item wears to the mark, yellow at 50% or less and red at 20% or less, and goes after a repair. Choices: Always, At 50% or less, At 20% or less. Needs **Durability** on. |
| **Frame rate and latency** | Off | Frames per second, then your home and world latency in milliseconds. Point at it for both latencies and Flat UI's memory. |
| **Frame rate place** | Below the map | On the map, at the bottom puts the line just inside the map's bottom edge, outlined so it reads over the ground, raised on a round map to stay inside the circle. A line there takes no room under the map, so the addon button row and the zone name keep their place. Choices: Above the map, Below the map, On the map, at the bottom. Needs **Frame rate and latency** on. |
| **Show** | Frame rate and latency | What the line by the minimap shows. Choices: Frame rate and latency, Frame rate only, Latency only. Needs **Frame rate and latency** on. |
| **Latency** | Home and world | Home is chat and the auction house, world is combat and other players. Choices: Home and world, The higher one, Home only, World only. Needs **Show** at Frame rate and latency or Latency only. |
| **Colour by value** | On | Frame rate red under 30 and yellow under 60; latency yellow over 100 ms and red over 200 ms. Needs **Frame rate and latency** on. |
| **Time** | Off | Your local time or the realm's. Point at it for both and the time of this session; a click opens the stopwatch and alarm, Shift-click the calendar, in a fight as it ends. The game's clock beside the zone name has its own row, Clock, under Buttons. |
| **Time place** | Above the map | On the map, at the bottom puts the line just inside the map's bottom edge, outlined so it reads over the ground, raised on a round map to stay inside the circle. A line there takes no room under the map, so the addon button row and the zone name keep their place. Choices: Above the map, Below the map, On the map, at the bottom. Needs **Time** on. |
| **Local or realm time** | Local time | Choices: Local time, Realm time. Needs **Time** on. |
| **Time format** | 24 hours (14:05) | Choices: 24 hours (14:05), 12 hours (2:05 PM). Needs **Time** on. |
| **Text size** | 100% | The lines of text around the map: coordinates, durability, frame rate and time, and also the coordinates on the world map and the name of who pings. In test mode, a line with nothing to show shows a sample, so you can see where it sits. |

**Border and background**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own border and background** | Off | For every page of Minimap and HUD. |
| **Border colour** | #000000 | Needs **Own border and background** on. |
| **Background colour** | #0F0F0F | Needs **Own border and background** on. |
| **Background opacity** | 85% | Needs **Own border and background** on. |

## Buffs and debuffs

| Setting | Default | Notes |
| --- | --- | --- |
| **Buff and debuff borders** | On | Square icons with a thin border. Debuffs take the colour of their type. |
| **Icon crop** | 8% | Buff, bag and loot icons. |

**Debuff colours**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border colour by debuff type** | On | Needs **Buff and debuff borders** on. |
| **Magic** | #3399FF | Needs **Border colour by debuff type** on. |
| **Curse** | #9900FF | Needs **Border colour by debuff type** on. |
| **Disease** | #996600 | Needs **Border colour by debuff type** on. |
| **Poison** | #009900 | Needs **Border colour by debuff type** on. |
| **Other debuffs** | #CC0000 | Bleeds and debuffs with no type. Needs **Buff and debuff borders** on. |

**Text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Duration size** | 100% |  |
| **Duration format** | No space (8m) | Also the totem times under the player frame. Minutes and seconds shows 28:41 under an hour and plain seconds in the last minute; an hour or more reads as hours and minutes, as 1h42, and a day or more keeps the short form. Choices: As the game has it (8 m), No space (8m), Minutes and seconds (28:41). |
| **Duration colour** | White | Also the totem times under the player frame. Choices: As the game has it (gold, white under 90 s), White, White, red near the end. |
| **Red under** | 10 s | The time turns red once this little is left. Also the totem times under the player frame. Needs **Duration colour** at White, red near the end. |
| **Tenths below** | 0 s | Under this many seconds the time on a buff or debuff shows tenths, as 4.3. 0 means never. The totem times stay in whole seconds, as the game gives them. |
| **Stack count size** | 100% |  |

## Quests and loot

**Objective tracker**

| Setting | Default | Notes |
| --- | --- | --- |
| **Tracker headers** | On | A flat band with a thin border behind each heading. |
| **Quest count** | On | Your quests and the most the log holds, as 12/20, at the right of the Quests heading. Red while the log is full, amber with one free slot while Warn as the log fills is on. Point at it for the quests ready to hand in; a click opens the quest log, in a fight as it ends. |
| **Warn as the log fills** | On | Amber with one free slot, and a pulse and a line in chat when the log becomes full. Needs **Quest count** on. |
| **Quests ready in the count** | On | After the count, how many quests in your log are ready to hand in, as 3 ready in the Quest colour of the experience bar, and the count pulses once as another becomes ready. Needs **Quest count** on. |
| **Tracker bars** | On | Thin border and flat fill on progress and timer bars. |
| **Tracker item buttons** | On | Square quest item buttons with a thin border. |
| **Tracker bar texture** | `default` | Needs **Tracker bars** on. |
| **Tracker background** | Off |  |
| **Heading size** | 100% |  |
| **Opacity in combat** | 100% | The objective tracker, and Questie's, eases to this opacity as a fight starts and back as it ends. Under the mouse it comes back to full. |
| **Questie's tracker** | On | Gives the quest tracker of the Questie addon the look of the rows above: background, headings, Heading size on its zone headings, item buttons and Opacity in combat, and the fonts of the Fonts page while that page is on. Needs Questie: without it this row does nothing. Off gives Questie its own look back. |

**Loot**

| Setting | Default | Notes |
| --- | --- | --- |
| **Loot window** | On | Flat window with thin borders on the window, the cards and the item slots. |
| **Loot rolls** | On | Flat background and thin border on each roll, the icon cropped with a border in the item's quality colour, a flat timer bar, and Need, Greed and Pass in a row. Off gives the rolls the game's look back. /flatui move moves the rolls, on or off. |
| **Seconds left on rolls** | On | The seconds left to roll, at the right end of the timer, in red with the bar under 10 seconds. Needs **Loot rolls** on. |
| **Sound before a roll ends** | None | Plays once when a roll you have not rolled on has 5 seconds left. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Seconds left on rolls** on. |
| **Rolls stack** | Up | Which way more rolls stack from the spot you gave Loot rolls in /flatui move: Up, as the game stacks them, or Down. Until you move them the game places the rolls. Choices: Up, Down. |
| **Quality word on loot** | On | Needs **Loot window** on. |

**Alerts**

| Setting | Default | Notes |
| --- | --- | --- |
| **Loot, money and honour alerts** | On | Flat background with a thin border. |

## Messages and timers

**Error messages**

| Setting | Default | Notes |
| --- | --- | --- |
| **Hide error messages** | On | Only the kinds below that are on, with their sound and voice. Other red errors and the yellow quest messages show as usual, even while a macro or addon turns the game's error text off with UIErrorsFrame:UnregisterEvent. |
| **When** | Always | Only in a fight shows every message out of combat, so you still learn why a mailbox or a cast on a mob failed. Choices: Always, Only in a fight. Needs **Hide error messages** on. |
| **Error text size** | 100% | The red error lines and the yellow quest lines in the middle of the screen, also while Hide error messages is off. 100% is the game's size. With the options window open, a change shows a sample Not enough mana there. |
| **Not enough mana** | On | Needs **Hide error messages** on. |
| **Not enough rage or energy** | On | Also not enough focus for a hunter's pet, and no combo points for a finishing move. Needs **Hide error messages** on. |
| **Out of range** | On | Also too far away to attack, too close for a ranged attack, and your pet out of range. Needs **Hide error messages** on. |
| **Facing the wrong way** | On | Also the target not in front of you or not behind it, and your pet not behind its target. Needs **Hide error messages** on. |
| **Not ready yet** | On | Spells, abilities, items and potions still cooling down. Needs **Hide error messages** on. |
| **No target or invalid target** | On | Also nothing to attack, and a dead target. Needs **Hide error messages** on. |
| **Not while moving** | On | A cast or an action that needs you to stand still. Needs **Hide error messages** on. |
| **Not in line of sight** | Off | Your target is behind a wall, a tree or a pillar. Needs **Hide error messages** on. |
| **While stunned, silenced or feared** | Off | Also pacified, confused or charmed: the messages of a key you press while you cannot act. Needs **Hide error messages** on. |
| **Wrong stance or form** | Off | Must be in Battle Stance, Can't use items while shapeshifted and the like: a key of a stance or form you are not in. Talking to an NPC while shapeshifted still says why it will not talk. Needs **Hide error messages** on. |

**Zone titles and talking head**

| Setting | Default | Notes |
| --- | --- | --- |
| **Hide the zone title** | Off | The big name that fades in near the top of the screen as you enter a zone, and its PvP line. The zone name on the minimap has its own row. |
| **Hide the subzone title** | Off | The smaller name of a part of a zone, such as a town, that fades in under it. |
| **Zone title size** | 100% | The zone and subzone names that fade in near the top of the screen, and their PvP lines. With the options window open, a change shows a sample at their place for 3 seconds. Hidden ones stay hidden; 100% is the game's size. |
| **Hide the talking head** | Off | The portrait that speaks at the bottom of the screen, and its voice. One that already shows plays to its end. |

**Timers**

| Setting | Default | Notes |
| --- | --- | --- |
| **Breath and fatigue timers** | On | Thin border and flat fill in the cast colours. |
| **Seconds on the timers** | On | Time left on the breath, fatigue and feign death bars, at the right under the bar, red under 10 seconds while it runs out. Needs **Breath and fatigue timers** on. |
| **Countdown timers** | On | Thin border and flat fill on pull and start timers. |

**Damage meter**

| Setting | Default | Notes |
| --- | --- | --- |
| **Damage meter header** | On | A flat band with a thin border in place of the default header. |
| **Clear the damage meter** | Off | Not again for the same instance within an hour, so a reload or a run back after a wipe keeps the numbers. Choices: Off, When you enter a dungeon or raid, Ask when you enter one. |
| **At each raid boss** | Off | Clears as a raid boss fight starts, without asking. Needs **Clear the damage meter** at When you enter a dungeon or raid or Ask when you enter one. |

**Queue and zone bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Queue status panel** | On | Thin border in place of the default frame. |
| **Zone event bars** | On | Thin border on score and progress bars. |

## Experience and menu bars

**Experience and reputation bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Experience bar** | Flat UI's | The game's bar stays in place and is not drawn. Choices: Flat UI's, The game's. |
| **Experience bar under the bar block** | On | While the Bar block page is on: right under block 1, exactly as wide as the block, and it moves with the block. With that page off, as it is by default, or this row off, the bar keeps its own place in /flatui move and the Width below. Needs **Experience bar** at Flat UI's. |
| **Width** | 42% | 100% is the game's bar at full width. While block 1 of the Bar block page holds the bar under it, the bar is as wide as the block. Needs **Experience bar** at Flat UI's. |
| **Height** | 8 px | Needs **Experience bar** at Flat UI's. |
| **Bars shown** | Experience and reputation | Reputation shows for the faction you watch. Choices: Experience and reputation, Experience only, Reputation only. Needs **Experience bar** at Flat UI's. |
| **Top bar** | Experience | Choices: Experience, Reputation. Needs **Experience bar** at Flat UI's. |
| **Space between bars** | 2 px | Needs **Experience bar** at Flat UI's. |
| **Bar border** | On | Thin border around the bar, so its empty part reads as a bar. On Flat UI's bar it is drawn with Borderless on too. On the game's bar, not applied while Leave the game's action bars alone is on. |
| **Bar background** | On | Needs **Experience bar** at Flat UI's. |
| **Dividers** | None | Choices: None, 4, 10, 20. Needs **Experience bar** at Flat UI's. |
| **Experience colour** | #94008C | With Rested experience on, the fill takes Rested colour while you are rested, as the game's bar turns blue. Needs **Experience bar** at Flat UI's. |
| **Rested experience** | On | Shows how far rested experience reaches, and colours the fill in Rested colour while you are rested. Off, the fill is always Experience colour. Needs **Experience bar** at Flat UI's. |
| **Rested colour** | #0063E0 | The rested stretch, and the fill while you are rested. Needs **Rested experience** on. |
| **Reputation fill** | By standing | Choices: By standing, One colour. Needs **Experience bar** at Flat UI's. |
| **Reputation colour** | #00991A | Needs **Reputation fill** at One colour. |
| **Bar text** | As the game has it | On the game's bar, not applied while Leave the game's action bars alone is on. Choices: As the game has it, Percent, Value and percent, Amount to go, Hidden. |
| **Rested share in the text** | On | With Bar text at Percent or Value and percent, the share of the level your rested experience covers follows in Rested colour, as +30%, while you are rested. On Flat UI's own bar. Needs **Rested experience** on. |
| **Bar text shows** | On mouse-over | As the game has it adds the game's experience bar text setting and the character window. Choices: On mouse-over, Always, As the game has it. Needs **Experience bar** at Flat UI's. |
| **Bar text place** | On the bar | Choices: On the bar, Above the bar, Right of the bar. Needs **Experience bar** at Flat UI's. |
| **Bar text size** | 105% | On the game's bar, not applied while Leave the game's action bars alone is on. |
| **Bar texture** | `soft` | On the game's bar it needs Flat fill and is not applied while Leave the game's action bars alone is on. |
| **Bar art** | Flat fill | The game's modern art fills Flat UI's experience bar in the game's purple, blue while you are rested, and the reputation bar in its standing's red, orange, yellow, green or blue, on the game's dark bar background. Bar texture, Experience colour and the standing colours give way to it; Bar background off leaves out the dark background. The tooltip, the quest stretch, the gains and the text work as before. Choices: Flat fill, The game's modern art. Needs **Experience bar** at Flat UI's. |
| **Tooltip** | On | Experience, rested and standing on mouse-over, and what is left to level or to the next standing, and a hunter's pet's experience while it is still levelling. Needs **Experience bar** at Flat UI's. |
| **Clicks on the bar** | On | Shift-click puts your progress in the chat box, ready to send. Ctrl-click counts the session's levelling and reputation numbers from now. A click on the reputation bar opens your reputations, in a fight as it ends. Needs **Experience bar** at Flat UI's. |
| **Animate gains** | On | The fill slides up to its new value and the part you just gained glows for a moment. A new level flashes the bar gold, and a new standing in its colour; another faction or a lower standing shows at once. A quest that becomes ready to hand in lights the part it adds to the quest stretch. Needs **Experience bar** at Flat UI's. |
| **Gains over the bar** | On | Each gain rises from the end of the fill as +1,240 and fades; reputation in its standing's colour, and a reputation loss as -250 in red. A new level rises as Level 35 in gold, and a new standing as its name in its colour, also with Animate gains off. It reads over the action buttons, and test mode plays a sample every 4 seconds. Needs **Experience bar** at Flat UI's. |
| **Flat fill** | On | One plain colour in place of the default gloss. Not applied while Leave the game's action bars alone is on. Needs **Experience bar** at The game's. |
| **Hide bar dividers** | On | Not applied while Leave the game's action bars alone is on. Needs **Experience bar** at The game's. |

**Levelling**

| Setting | Default | Notes |
| --- | --- | --- |
| **Quests ready to hand in** | On | A stretch after the fill shows the experience of the finished quests in your log. The tooltip counts them and the whole log. Needs **Experience bar** at Flat UI's. |
| **Quest colour** | #4DE64D | Needs **Quests ready to hand in** on. |
| **Levelling text** | Time to level | After the text of the experience bar, or alone while Bar text is Hidden. The pace is your last 30 minutes of play, without time away, and shows after 5 minutes. Choices: None, Time to level, Experience per hour, Time to level and per hour, Kills to level. Needs **Experience bar** at Flat UI's. |
| **Reputation text** | None | After the text of the reputation bar, or alone while Bar text is Hidden. The pace is your last 30 minutes of play, without time away, and shows after 5 minutes. Choices: None, Time to next standing, Reputation per hour, Both. Needs **Experience bar** at Flat UI's. |
| **Levelling in the tooltip** | On | Experience this session and per hour, the time to level, about how many kills and quests that takes, and the time at this level after /played. On the reputation bar, the reputation this session and per hour and the time to the next standing. Needs **Tooltip** on. |
| **Level up line in chat** | On | At each new level one line in chat says how long the level you finished took, and your play this session. The time of a level shows once you levelled in this session or typed /played. Needs **Experience bar** at Flat UI's. |
| **Line when your quests are enough to level** | On | Once a level, a line in chat says when the quests ready to hand in hold enough experience for the next level, as the last of them is done or as you log in. A /reload does not say it again. Needs **Quests ready to hand in** on. |

**Bag bar and micro menu**

| Setting | Default | Notes |
| --- | --- | --- |
| **Bag bar buttons** | On | Square icons with a thin border, without the bar frame. |
| **Micro menu buttons** | On | Thin border in place of the default button frames. |

## Data panels

| Setting | Default | Notes |
| --- | --- | --- |
| **Show data panels** | On | Panels of text across the screen: bag space, gold, durability and more. Point at a slot for its tooltip. /flatui move places the panels. |

**Top panel**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the top panel** | Off | At the top of the screen, under the game's battleground scores, until you move it. |
| **First slot** | `bags` | A slot with nothing to show takes no room; the right-click menu of a slot dims what shows nothing for this character, as Soul shards for a warrior. Feeds of other addons are listed when one of them brings LibDataBroker. Needs **Show the top panel** on. |
| **Second slot** | `gold` | Needs **Show the top panel** on. |
| **Third slot** | `durability` | Needs **Show the top panel** on. |
| **Fourth slot** | `hearth` | Needs **Show the top panel** on. |
| **Fifth slot** | `coords` | Needs **Show the top panel** on. |
| **Sixth slot** | `fps` | Needs **Show the top panel** on. |
| **Panel width** | 0 px | 0 fits the slots. Needs **Show the top panel** on. |

**Bottom panel**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the bottom panel** | Off | In the bottom left corner of the screen until you move it. |
| **First slot** | `friends` | Needs **Show the bottom panel** on. |
| **Second slot** | `guild` | Needs **Show the bottom panel** on. |
| **Third slot** | `none` | Needs **Show the bottom panel** on. |
| **Fourth slot** | `none` | Needs **Show the bottom panel** on. |
| **Fifth slot** | `none` | Needs **Show the bottom panel** on. |
| **Sixth slot** | `none` | Needs **Show the bottom panel** on. |
| **Panel width** | 0 px | 0 fits the slots. Needs **Show the bottom panel** on. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Font** | Flat UI Sans | Flat UI Sans is IBM Plex Sans. A language it has no letters for keeps the game font. Choices: Flat UI Sans, Game font. |
| **Text size** | 120% | 100% is 12 px. |
| **Background and border** | On | A flat background with a thin border and a line between two slots, in the colours of the Flat UI page. |
| **Tooltips** | On | Off: Gold and Frame rate let clicks through; the slots a click does something on (Bag space, Equipment set, Hearthstone, Time, Coordinates, Zone, Quest log, Experience, Reputation, Friends, Guild, Durability) and another addon's feed keep their own clicks. Right-click a slot (Alt-right-click on another addon's feed) to choose what it shows, from a menu under it whose last line opens this page; Move left and Move right there swap it with the next shown slot, and while the panel has a slot set to None, Add a slot puts a new one right beside it. |
| **Text outline** | None | An outline makes a slot a little wider. Choices: None, Thin, Thick. |
| **Text shadow** | On |  |
| **Text colour** | White | A slot's own colours stay, such as red for worn gear. Choices: White, Class colour, Own colour. |
| **Own text colour** | #FFFFFF | Needs **Text colour** at Own colour. |
| **Colour frame rate and latency** | On | As by the minimap: frame rate red under 30, latency red over 200 ms. |
| **Opacity in combat** | 100% | Under the mouse a panel rises to full opacity in a tenth of a second, and settles back as the mouse leaves. A fight eases it here. While /flatui move or Edit Mode is open, the panels show at full opacity. |
| **Opacity out of combat** | 100% | Under the mouse a panel rises to full opacity in a tenth of a second, and settles back as the mouse leaves. While /flatui move or Edit Mode is open, the panels show at full opacity, so you can see what you line up. |
| **Layer** | Under the game's windows | Over the game's windows, a panel can cover your bags and the map. Choices: Under the game's windows, Over the unit frames and the minimap, Over the game's windows. |

**Gold**

| Setting | Default | Notes |
| --- | --- | --- |
| **Forget a character's gold** |  | The gold tooltip lists each character of the account that logged in with data panels on. |
