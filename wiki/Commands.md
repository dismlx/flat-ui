Every Flat UI command starts with `/flatui`, apart from `/way`. The tables below group them by area, each with a link to the guide for that area. `/flatui help` (or `/flatui ?`) lists the commands in chat, and words that are no command open the options window with those words in **Search**.

Where a command takes a spell or an item, you can usually type its name or ID, or shift-click it into the chat box.

## Options, setup and help

Guide: [Getting started](Getting-started)

| Command | What it does |
| --- | --- |
| `/flatui` | Opens or closes the options window. In a fight, before the window was first opened, it opens as the fight ends. |
| `/flatui setup` | Walks round your screen in six short stops and saves what you pick. It continues a setup you left. |
| `/flatui welcome` | Opens the welcome screen |
| `/flatui new` (or `/flatui changes`) | Opens **What's new** on the newest version that has notes |
| `/flatui new 0.5.45` | Opens **What's new** on that version, if it is one of the newest six. The window's "<" and ">" buttons step through the others. |
| `/flatui options` | Opens Flat UI's page in the game's own options, which has one button that opens Flat UI. In a fight, after it. |
| `/flatui border colour` | Any other words open the options window with them in **Search**: the results show lit, Enter opens the first, and a miss shows the closest pages. US spellings and plurals work too, as `/flatui border color`. Typed in a fight before the window was first opened, the window opens as the fight ends with the search run. |
| `/flatui #changed` | Lists every setting of the profile in use that you changed. **Reset these** at the foot of the window resets all it lists as one step. |
| `/flatui #changed nameplate` | Lists the changed settings that match the other words, in their names, tips or choices |
| `/flatui help` (or `/flatui ?`) | Lists the commands |

While setup has the options window, a search from chat waits: chat says to search once setup is closed.

## Profiles

Guide: [Profiles](Profiles)

| Command | What it does |
| --- | --- |
| `/flatui profile` | Names the profile in use and the others: "Flat UI: profile Default. Others: Raid, Alt." |
| `/flatui profile Raid` | Puts Raid in use ("Flat UI: using Raid."). In a fight it switches as the fight ends. A name it does not know lists the profiles: "Flat UI: no profile named Raidd. Profiles: Default, Raid, Alt." |
| `/flatui profiles` | Shows the ready-made looks. A click puts one in use, and **Back to** on the card that follows puts the profile you had back in use. |

## Scale

Guide: [Look](Look)

| Command | What it does |
| --- | --- |
| `/flatui scale 80` | Sets the UI scale in percent, from 35 to 115. From 65 to 115 it uses **Custom scale** and turns **Pixel-perfect scale** and **Scale below 65%** off. From 35 to 64 it uses **Small scale** with **Scale below 65%** on. Chat says what came of it; in a fight it waits for the fight's end. |
| `/flatui scale off` | Gives the game its own UI scale back |

Turning **Scale below 65%** off needs a reload, so going from a small scale to 65 or more can show the reload notice.

## Test mode

Guide: [Test mode](Test-mode)

| Command | What it does |
| --- | --- |
| `/flatui test` | Turns test mode on or off |
| `/flatui test on`, `/flatui test off` | Turns test mode on, or off |
| `/flatui test icons` | Shows three sample icons for 8 seconds on **Defensives on you**, **Your buffs**, **Party cooldowns** and **Enemy cooldowns**. On the last two they flash and sound at their end, as each page's **Flash when ready** and **Sound** say. |

## Moving and hiding frames

Guide: [Layout](Layout)

| Command | What it does |
| --- | --- |
| `/flatui move` | Shows or hides a box for every frame. Drag a box to move its frame. In a fight it opens when the fight ends, and a second one in the same fight takes that back. |
| `/flatui move reset` | Puts every moved frame back where the game has it |
| `/flatui move reset windows` | Puts every window back to its default place and size |
| `/flatui grab` | Picks the frame under the mouse to move. In a fight it starts when the fight ends. |
| `/flatui hide` | Opens the **Hidden frames** page, where a tick hides a frame of the game |
| `/flatui hide tracker` | Hides that frame or shows it again, and says so: "Flat UI: Objective tracker is hidden. /flatui hide tracker shows it again." It takes a row's name or part of it, as `minimap`, `buffs` or `objective tracker`, and works from a macro. In a fight the change waits for its end. |
| `/flatui hide list` | Names the frames you have hidden, or says "Flat UI: no frame is hidden." |

The [Layout](Layout) guide covers the boxes, the toolbar, selecting several frames and the keys.

## Frames and bars

Guide: [Frames and bars](Frames-and-bars)

| Command | What it does |
| --- | --- |
| `/flatui art` | Lists the textures shown on the player and target frames |
| `/flatui buffs check` | Says how the **Your buffs** row is drawn, its groups and where it hangs |

## Nameplates

Guide: [Nameplates](Nameplates)

| Command | What it does |
| --- | --- |
| `/flatui role` | Says whether nameplate threat reads you as a tank and why, as "Flat UI: nameplate threat reads you as a tank (Defensive Stance), so enemies you are losing are marked." |
| `/flatui role tank` | Sets the role nameplate threat reads you as. `damage`, `auto` and `toggle` work the same way. |

## Action bars

Guide: [Action bars](Action-bars)

| Command | What it does |
| --- | --- |
| `/flatui blocks` | Lists the bars used as blocks |
| `/flatui block facts` | Says what the game reports about the action bars and Edit Mode layouts |

## Combat

Guide: [Combat](Combat)

### Cooldown icons

| Command | What it does |
| --- | --- |
| `/flatui cooldown add 2094` | Puts a spell on the cooldown row: a spell ID, a name or a shift-clicked spell |
| `/flatui cooldown remove 2094` | Takes a spell off the row |
| `/flatui cooldown list` | Lists what the row shows |
| `/flatui cooldown add healthstone` | Puts your healthstones on the row, every rank as one icon. `healing` and `mana` do the same for potions, and `/flatui cooldown remove healthstone` takes them off. |
| `/flatui cooldown add item 6948` | Puts an item with a use, such as the Hearthstone, on the row: an ID, a link or a name. `/flatui cooldown remove item 6948` takes it off. |
| `/flatui cooldown import 1` | Adds the spells with a cooldown on action bar 1 (2 to 8 likewise) |
| `/flatui cooldown sound 2094 bell` | Gives one icon its own ready sound. `row` gives it back the row's sound, and `none` silences it. |

### Cooldown pulse

| Command | What it does |
| --- | --- |
| `/flatui pulse test` | Shows a pulse at each spot in use |
| `/flatui pulse ignore Frost Nova` | Leaves a spell or item out: a name, an ID or a shift-clicked link |
| `/flatui pulse watch Frost Nova` | Lets it pulse again |
| `/flatui pulse list` | Says what pulses, what is left out, the own sounds and spots, and **When it pulses** |
| `/flatui pulse sound Frost Nova bell` | Gives one its own pulse sound. `none` silences it, and `page` gives it the page's sound again. |
| `/flatui pulse spot Frost Nova 2` | Sends one to pulse spot 2 (1, 2 or 3). `1` puts it back. |

### Trackers

| Command | What it does |
| --- | --- |
| `/flatui tracker add Lightning Shield` | Tracks a buff on you, by name, spell ID or shift-clicked spell |
| `/flatui tracker add group` | Tracks your class buff on your group |
| `/flatui tracker add debuff Corruption` | Tracks your own debuff on your target |
| `/flatui tracker add weapon main` | Tracks the enchant on a weapon: `main`, `off` or `ranged` |
| `/flatui tracker add totem fire` | Tracks a totem slot: `fire`, `earth`, `water` or `air` |
| `/flatui tracker add pet` | Tracks your pet, red when it is gone or dead |
| `/flatui tracker add item Healing Potion` | Tracks an item in your bags |
| `/flatui tracker add ammo` | Tracks the ammunition you carry |
| `/flatui tracker add tracking` | Turns red when no minimap tracking is on |
| `/flatui tracker add form Bear Form` | Tracks a stance or form, red when you are in none of them |
| `/flatui tracker add durability` | Tracks your most worn item, red when one is broken |
| `/flatui tracker add proc Shadow Trance for Shadow Bolt` | Adds a proc alert: its buff, then the spell it is for |
| `/flatui tracker class` | Adds the usual trackers of your class |
| `/flatui tracker remove 1` | Removes a tracker, by its number in the list or by name |
| `/flatui tracker back` | Puts the tracker you last removed back, with its own settings, until you reload |
| `/flatui tracker list` | Lists your trackers |
| `/flatui tracker export`, `/flatui tracker import` | Opens **Share**, to copy every tracker as text or to paste trackers |
| `/flatui tracker use 2 Instant Poison` | Sets what weapon tracker 2 applies |
| `/flatui tracker set 1 low 2` | Gives one tracker its own value for a setting; `clear` uses the page's again |
| `/flatui tracker set 1 shape bar` | Draws one tracker as an `icon`, `bar` or `text` |
| `/flatui tracker set 1 health 40` | Shows pet tracker 1's health in red under 40% |
| `/flatui tracker set 3 kit bell` | Gives tracker 3 a sound of its own, as the **Sound** row of **Edit a tracker** does |
| `/flatui tracker proc colour 1 ffd100` | Sets one proc's colour; `proc time` and `proc trigger` set its time and trigger |
| `/flatui tracker proc colour Execute ff3030` | Gives a proc of your class its own colour, by its name or its number in **Remove a proc**; the art, border and glow take it at once |
| `/flatui tracker proc sound Overpower bell` | Gives a proc its own sound: `none`, `spell`, `chimes`, `bell`, `warhorn`, `raid`, `alarm` or `whisper`. `none` silences it |
| `/flatui tracker proc time Revenge 5` | Gives a proc its own time in seconds; `0` is no time limit |
| `/flatui tracker proc reset Execute` | Puts a proc's colour, sound and time back as the page has them |
| `/flatui tracker check` | Says what each tracker shows and why, what happened in the last fight, and which trackers have a sound the game does not play in a fight |
| `/flatui tracker test` | Shows each look for 3 seconds: fine, low, missing, then the game's own look |

### Defensives, absorbs and enemy cooldowns

| Command | What it does |
| --- | --- |
| `/flatui defensives add 10060` | Adds a buff to **Defensives on you**: a spell ID or a shift-clicked spell |
| `/flatui defensives remove 17` | Removes one, by spell ID or name |
| `/flatui defensives list` | Lists them |
| `/flatui absorbs test` | Shows sample bars of **Absorb shields** for a few seconds |
| `/flatui absorbs check` | Says the amount, time and secrecy of each shield on you |
| `/flatui absorbs add 17`, `remove 17`, `list` | Adds, removes or lists the shields it follows |
| `/flatui charges` | Shows a sample of **Charges** in its look for 8 seconds, out of combat and while none of its buffs is on you: Lightning Shield losing its charges, or Maelstrom Weapon gaining stacks with **Spell art** |
| `/flatui charges add Lightning Shield`, `remove`, `list` | Adds a buff with charges or stacks by name, spell ID or shift-clicked spell, takes one off, or lists them |
| `/flatui enemy add Blink 15` | Adds an enemy ability and its cooldown in seconds |
| `/flatui enemy hide 2139` | Hides an ability, by name or spell ID |
| `/flatui enemy list` | Lists the abilities shown and whether their use can be seen here |
| `/flatui enemy clear` | Forgets the running timers of enemies |
| `/flatui enemy reset` | Puts the abilities back as Flat UI ships them, undoing every add, hide and typed cooldown |

## Combat text

Guide: [Combat text](Combat-text)

| Command | What it does |
| --- | --- |
| `/flatui combat` | Lists the game's combat number settings: now, default and wanted |
| `/flatui combat test` | Shows sample numbers for you, over your target and over friendly units, and one round of the combat alerts |
| `/flatui combat reset` | Puts the game's combat number settings back to their defaults, and turns **Place combat numbers** off |
| `/flatui combat trace` | Prints each hit report and signal of yours in chat, until you type it again |
| `/flatui announce` | Says where **Announce blocks, dodges and parries** sends its lines now, or why it sends nothing |
| `/flatui announce test` | Writes sample lines in your own chat window only, never sent to the group |

## Group

Guide: [Group](Group)

| Command | What it does |
| --- | --- |
| `/flatui threat` | Shows sample bars of the threat list for a few seconds, out of combat: with **Your target, then enemies you are losing** two sample enemies under them, with **Enemies you fight** four sample enemies instead |
| `/flatui healers` | Shows sample bars of the healer mana list for a few seconds, out of combat |
| `/flatui party add Pummel 12` | Adds an ability to **Party cooldowns** with its cooldown in seconds |
| `/flatui party hide 6552` | Hides an ability, by name or spell ID |
| `/flatui party list` | Lists the abilities shown and who shares cooldowns, also your subgroup's in a raid |
| `/flatui party reset` | Puts the abilities back as Flat UI ships them, undoing every add, hide and typed cooldown |

## Character and gear

Guide: [Character and gear](Character-and-gear)

| Command | What it does |
| --- | --- |
| `/flatui gear` | Opens or closes the **Gear comparison** window. Its **Find** button opens the item finder. |
| `/flatui gear <item>` | Compares a shift-clicked item there, as an Alt-click on an item link in chat does |
| `/flatui gear add <spell>`, `remove <spell>` | Changes the spells it compares. A shift-clicked spell keeps its rank. |
| `/flatui gear bar 1` | Compares the spells of action bar 1 (2 to 8 likewise) |
| `/flatui gear reset` | Goes back to your class's main spells for your role |
| `/flatui gear weight <spell> <0 to 5>` | Sets how much a spell counts in the **Overall** line, in steps of 0.5 |
| `/flatui gear list` | Prints the spells it compares |
| `/flatui queue` (or `/flatui trinkets`) | Opens or closes the **Trinket queue** window |
| `/flatui queue top`, `/flatui queue bottom` | Opens it on that slot's list |
| `/flatui queue pause` | Pauses or resumes every swap |
| `/flatui queue now` | Lets the queue act at once on a slot you changed by hand |
| `/flatui queue list` | Prints both lists |
| `/flatui queue copy bottom` | Fills the Bottom list from the Top one; `copy top` the other way |
| `/flatui queue clear top` | Empties the Top list; `clear bottom` the Bottom one |

## HUD

Guide: [HUD](HUD)

| Command | What it does |
| --- | --- |
| `/flatui xp` | Says your experience per hour, time to level, and kills and quests to level, and your reputation per hour and time to the next standing with the faction on Flat UI's bar |
| `/flatui xp reset` | Starts counting again, as a Ctrl-click on the bar does |

## Chat and windows

Guide: [Chat and windows](Chat-and-windows)

| Command | What it does |
| --- | --- |
| `/flatui words add <word>` | Colours a word in other players' chat lines as your name is |
| `/flatui words remove <word>` | Stops colouring it |
| `/flatui words` | Lists the words |
| `/flatui copy` | Opens a box with the last 50 chat lines heard, ready to copy |
| `/flatui copy 200` | The same with up to 200 lines |
| `/flatui windows` | Lists each window and whether it is styled |

## Bags and items

Guide: [Bags and items](Bags-and-items)

| Command | What it does |
| --- | --- |
| `/flatui bags` | Opens or closes the Flat UI bag window |
| `/flatui bags <name>` | Shows another of your characters' bags, as Flat UI last saw them |
| `/flatui bank` | Opens or closes your bank window: live at the banker with Flat UI's bank window, else as you last left it |
| `/flatui bank <name>` | Shows another character's bank |
| `/flatui sort` | Cleans up your bags |
| `/flatui sort bank` | Cleans up the bank that is open |

## Helpers

Guide: [Helpers](Helpers)

### Errands

| Command | What it does |
| --- | --- |
| `/flatui sell <item>` | Always sells an item at merchants (an item link or ID). Type it again to stop. **Items always sold** on the **Errands** page takes one off. |
| `/flatui sell` | Lists the items always sold and never sold |
| `/flatui keep <item>` | Never sells a grey item, and **Make room in full bags** never deletes it. **Items never sold** takes one off. |
| `/flatui train` | At an open trainer, learns everything you can pay for, as the Train all button does |
| `/flatui npc` | Skips the NPC you talk to or target: its quests and gossip are left to you. Type it again to stop. With no NPC, it lists the skipped ones. |
| `/flatui gossip` | Lists the options of the NPC you talk to |
| `/flatui gossip 2` | Picks the second option for you from now on. Type it again to stop. |
| `/flatui gossip forget <ID>` | Stops picking a saved gossip option |
| `/flatui uprank` | Offers the new ranks of your spells for your action bars |
| `/flatui rank <spell>` | Keeps that rank where it is on your bars (a spell link or ID). Type it again to stop. |

### Map pins

| Command | What it does |
| --- | --- |
| `/way 45 61` | Puts a pin on your map, and the game points you to it. It comes off by itself as you reach it. |
| `/way Elwynn Forest 45 61` | The same in another zone |
| `/way clear` | Takes the pin off |
| `/flatui way 45 61` | The same as `/way`, for when another add-on has taken `/way` |

Typed while the world map is open, `/way` waits and goes on, or comes off, as you close the map.

### Lava tick timer

| Command | What it does |
| --- | --- |
| `/flatui lava` | Says what the lava tick timer sees: the place and its IDs, the ticks seen and dodged, the last hit on you and the gaps between ticks |
| `/flatui lava test` | Shows a sample for 8 seconds |
| `/flatui lava trace` | Prints a line for each hit on you, to check in lava that the game reports its ticks. Type it again to stop. |

## Checks and troubleshooting

Guide: [Troubleshooting](Troubleshooting)

| Command | What it does |
| --- | --- |
| `/flatui status` | Says what is styled, and any error |
| `/flatui check` | Says what the game shows and hides from add-ons where you stand |
| `/flatui check last` | Prints the lines of the last check again |
| `/flatui taint` | Checks the click path of the action buttons for values an add-on changed |
| `/flatui cvar` | Lists each game setting row: its value, default and secure flag |
| `/flatui cvar check` | Tries whether each of those can be changed, out of combat |

Every setting, with its default, is in the settings pages, starting at [Settings: Look](Settings-Look).
