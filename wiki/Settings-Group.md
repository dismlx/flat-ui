Every setting of the **Group** group of the options window, 86 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Group](Group).

Pages: [Party cooldowns](#party-cooldowns) · [Threat list](#threat-list) · [Healer mana](#healer-mana) · [Group tools](#group-tools) · [Ping bar](#ping-bar)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.49.

## Party cooldowns

| Setting | Default | Notes |
| --- | --- | --- |
| **Party cooldowns** | On | Icons beside each party member's frame. |

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Party icons** | Right of each frame | Choices: Right of each frame, Left of each frame, Below each frame. |
| **Show** | Always, used ones dark | Choices: Only while on cooldown, Always, used ones dark. |
| **In a raid group** | Own position | Own position has a handle in /flatui move. Choices: Own position, Off. |
| **Rows stack** | Down | Up keeps the bottom of the raid group stack on the bottom of its box in /flatui move, so more rows grow upward: for a stack above your action bars. Choices: Down, Up. Needs **In a raid group** at Own position. |
| **Your own row** | Off | Shown while you are in a party. |
| **Icons for each member** | 6 |  |
| **Icon size** | 24 |  |
| **Icon border** | On | Off also removes the dark background. |
| **Border colour by kind** | On | Interrupts, defensives and the others each have a colour. Off, the border has the colour of the Flat UI page. Needs **Icon border** on. |
| **Time left** | On |  |
| **Countdown number size** | As the game has it | Choices: As the game has it, Small, Normal, Large, Huge. Needs **Time left** on. |
| **Icon tooltips** | On | Pointing at an icon names the ability and the member and says Ready or the time left. Clicks still go through to the party frame. Choices: On, Out of combat only, Off. |
| **Dim members out of range** | On | The row of a member too far from you for the game's range check shows faded, also in a fight. A dead or offline member's row fades further. |

**Ready again**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flash when ready** | Off | A white flash on the icon as its cooldown ends. |
| **Sound** | None | Plays as a party icon's cooldown ends, at most once a second. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Shortest cooldown that sounds** | 0 s | A cooldown shorter than this ends without the sound, so a short interrupt stays quiet. 0 sounds for every cooldown. |

**Abilities**

| Setting | Default | Notes |
| --- | --- | --- |
| **Interrupts** | On |  |
| **Defensives** | On |  |
| **Defensives cast on others** | On |  |
| **Crowd control breaks** | Off |  |
| **Group cooldowns** | Off |  |
| **Add an ability** |  | For a spell that is not listed, type /flatui party add, its spell ID and its cooldown in seconds. |
| **Hide an ability** |  |  |

**Sharing**

| Setting | Default | Notes |
| --- | --- | --- |
| **Share cooldowns with the party** | On | Sends your cooldowns to party members, and in a raid to your subgroup. |

## Threat list

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the threat list** | On | Your group by threat on the enemy you fight, highest first: 100% has aggro or takes it. While you are a tank the other enemies you are losing show under it, and List can show only the enemies you fight instead. /flatui move places the list, /flatui threat shows a sample. |

**When it shows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | In a group | Only in a fight, while your target, the target of your target or, with Follow your tank's target, your tank's target is an enemy, or while you are a tank, an enemy you are losing. Choices: In a group, In a dungeon or raid, In a group or alone. |
| **List** | Your target, then enemies you are losing | Your target, then enemies you are losing, the default, shows your group on your target, and while you are a tank (your group role, else your stance or form, or Your role of nameplate threat) adds under a thin line up to 4 small rows for the other enemies that are Lost or Slipping, the lost ones first; nothing more while none is. With no enemy as your target, your target's target or your tank's target, a tank's list shows the group on the enemy you are losing most, the title naming who holds a Lost one, the others still under it. Enemies you fight has a row for each enemy with a nameplate that fights you or your group instead, the ones you are losing first, in every role. Your group on your target shows the group alone. Choices: Your target, then enemies you are losing, Enemies you fight, Your group on your target. |
| **Follow your tank's target** | On | With no enemy as your target or your target's target, the list shows the enemy your group's tank fights (their tank role, the raid's main tank, or in a party their tank stance, form or aura), and the title names the tank: for a healer who heals without a target. |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Pets** | On | A bar for each pet, a shade darker than its owner's. |
| **Number of bars** | 5 | The highest threat first; in Enemies you fight the most urgent first, and a last line counts the rest. The small rows of the enemies you are losing under your target count apart, at most 4, and a last line counts the rest. |
| **Bars stack** | Down | Up keeps the bottom of the list on the bottom of its box in /flatui move, so more bars grow upward: for a list above your action bars. The enemies you are losing then show above the title, so the group bars stay put as they come and go. Choices: Down, Up. |
| **Bar width** | 180 px |  |
| **Bar height** | 16 px | Also the height of text. |
| **Bar texture** | `default` |  |
| **Mark your own bar** | On | A thin white outline round your bar. |
| **Always show your bar** | On | When you rank below the last bar, your bar takes the place of the last one, with your place before your name. |
| **Animate bars** | On | Bars slide to each new value over a fifth of a second, a row glides to its new place and flashes as it overtakes another, and the top bar has a faint sheen. Off, bars jump and stand still; the warnings still pulse. |

**Warning**

| Setting | Default | Notes |
| --- | --- | --- |
| **Warn near aggro** | On | For damage dealers and healers: your bar pulses red while you are not tanking and your share passes Warn at, and keeps it red while you hold the enemy's aggro. Not on bosses, where the game hides threat. |
| **Warn at** | 90% | The share of Warn near aggro, and for a tank of Show who is near your aggro. |
| **Warn when you lose aggro** | On | While you are a tank (your group role, else your stance or form): your bar pulses red for up to 2 seconds, until you take it back, and Warning sound plays once when an enemy you held turns to someone else, and the bar of whoever took it pulses red with yours while the title names them in red; once another tank holds it, with Calm when another tank takes it, the red stops at once. As your taunt lands, your bar flashes once in a light shade of Threat you want. Not on bosses, where the game hides threat. |
| **Show who is near your aggro** | On | While you are a tank: the bar of a member at Warn at or above who is not tanking turns amber, with no sound, so you see who is about to pull. Not on bosses, where the game hides threat. |
| **Calm when another tank takes it** | On | While you are a tank: an enemy another tank of the group takes (their tank role, the raid's main tank, or in a party their tank stance, form or aura) plays no warning, and their bar never turns amber. |
| **Warning sound** | Raid warning | Plays once for each enemy as Warn near aggro starts, and once each time you lose aggro. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

**Enemies**

| Setting | Default | Notes |
| --- | --- | --- |
| **Slipping at** | 80% | In the enemies under your target and in Enemies you fight, an enemy you hold turns amber and pulses slowly once another member's threat passes this share of yours, with their name and share; it turns red and pulses fast once someone else holds it, and flashes once in a light shade of Threat you want as you take it back. Under your target, where only lost and slipping enemies are listed, the flash shows while it is still slipping, as it is right after a taunt. Needs **List** at Your target, then enemies you are losing or Enemies you fight. |
| **Sound when you lose an enemy** | Warning sound | Plays once as an enemy you held turns to someone else, as its row flashes: any enemy in Enemies you fight, or one of the enemies under your target, where your target itself has Warn when you lose aggro. Warning sound, the default, plays the sound of Warning sound while Warn when you lose aggro is on. Picking one plays it. Choices: Warning sound, None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **List** at Your target, then enemies you are losing or Enemies you fight. |

## Healer mana

| Setting | Default | Notes |
| --- | --- | --- |
| **Show healer mana** | On | The mana of the healers in your group, by their role. While nobody has the healer role, a member with no role counts by class, unless they are plainly no healer: you with damage or tank talents, anyone in their tank stance, form or aura. /flatui move places the list, /flatui healers shows a sample. |

**When it shows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | In a dungeon or raid | While your group has a healer. Choices: In a dungeon or raid, In a group. |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Number of bars** | 5 | In the order of your group. A last line counts the rest with the lowest mana among them (+3 more, lowest 22%), red under Low mana at; the average and ready count them too. |
| **Bars stack** | Down | Up keeps the bottom of the list on the bottom of its box in /flatui move, so more bars grow upward: for a list above your action bars. Choices: Down, Up. |
| **Bar width** | 150 px |  |
| **Bar height** | 16 px | Also the height of text. |
| **Bar texture** | `default` |  |
| **Your own bar** | On | Off leaves you out of the list, its average and ready, so a healer sees only the other healers; with no other healer the list stays hidden. |
| **Low mana at** | 30% | 0 means never. A bar turns red below it, also in a fight, where the game hides the number. |
| **Show who is drinking** | On | Out of combat, a cup and the seconds left on the drink show on the bar of a healer who drinks, so you know when to pull. |
| **Dim healers out of range** | On | A healer too far from you for the game's range check shows faded, also in a fight. |

**Ready to pull**

| Setting | Default | Notes |
| --- | --- | --- |
| **Ready at** | 90% | 0 means never. Out of combat, once every healer has at least this much mana, also those past Number of bars, the title turns green and reads ready. |
| **Sound when ready** | None | Plays once as the healers turn ready, and again only after one of them dropped under Ready at; quiet at login, on zoning and in a fight. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

## Group tools

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the group tools** | On | A row of buttons: the eight raid markers and a clear for your target, a ready check, a role poll and a pull countdown. /flatui move places it. |

**When it shows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | In a group | A button you cannot use now is greyed, and its tooltip says why. Choices: In a group, As the leader or an assistant, In a group or alone. |

**Buttons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Raid markers** | On | Left-click puts a marker on your target or takes it off, right-click takes it off. Shift-click marks yourself and Ctrl-click your focus, also in a fight; Shift- or Ctrl-right-click takes theirs off. The marker your target wears lights up in its colour. In a raid only the leader and assistants can mark. |
| **Ready check** | On | Only the leader or an assistant can start one. During a check it shows how many are ready, and flashes as the last one answers ready; its tooltip names who is not, in class colours. The result stays 8 seconds. |
| **Sound when all are ready** | None | Plays once as the last member answers ready, with the tick's flash. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Ready check** on. |
| **Role poll** | On | Asks everyone to pick a role. Only the leader or an assistant can start one. Once anyone in the group has picked a role, an amber number in its corner counts the members with no role, grey while you cannot start a poll. Its tooltip lists who has which role in class colours, who has none, and in a party a missing tank or healer. |
| **Pull countdown** | On | Left-click counts down for the group, right-click stops it. Only the leader or an assistant can start one. While a countdown runs, it counts the seconds left, the last three in red, and flashes at 0. |
| **Countdown length** | 10 s | The mouse wheel over the pull button changes it too, out of combat. Needs **Pull countdown** on. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Button size** | 24 |  |
| **Spacing** | 3 |  |
| **Layout** | In a row | Choices: In a row, Markers above the rest, In a column. |
| **Borders in the marker's colour** | On | Star yellow, circle orange, diamond purple, triangle green, moon silver-blue, square blue, cross red and skull white, as in the game's menu. |
| **Fade until you point at it** | Off | The buttons stay faint until the mouse comes over one, and fade again a second after it leaves; they still take clicks. Full during a ready check or a countdown, also in a fight. |

## Ping bar

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the ping bar** | On | A button for each ping of the game: Ping, Attack, Warning, On My Way and Assist. Click one, then click where to ping, also in a fight: the button lights up while its ping waits. Click another to switch to it; click it again, right-click or Esc to cancel. A waiting ping gives up after 10 seconds, or as the fight ends. Shift-click pings your target at once. Each has a key under Flat UI in the game's Key Bindings that pings what is under the mouse at once: hover the spot, press the key. /flatui move places it. |

**When it shows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | In a group | Hidden while pings are off in the game's options or your group lets only some members ping and you are not one; the tooltip of a button says why while a fight keeps it shown. Choices: In a group, Always, Never, only its keys. |

**Pings**

| Setting | Default | Notes |
| --- | --- | --- |
| **Ping** | On | The button that lets the game pick the kind of ping. A ping turned off here keeps its key under Key Bindings. |
| **Attack** | On |  |
| **Warning** | On |  |
| **On My Way** | On |  |
| **Assist** | On |  |
| **Cooldown swipe** | On | The game lets you ping only so often: after a ping from the bar the buttons show when you can ping again. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Button size** | 24 |  |
| **Spacing** | 3 |  |
| **Layout** | Horizontal | Choices: Horizontal, Vertical. |
| **Borders in the ping's colour** | On |  |
| **Keys on the buttons** | On | The key you bound under Flat UI in the game's Key Bindings, short, in the corner of each button. |
| **Fade until you point at it** | Off | The buttons stay faint until the mouse comes over one, and fade again a second after it leaves; they still take clicks and keys. Full while a ping waits, also in a fight. |
