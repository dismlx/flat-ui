The **Character and gear** group helps you pick gear and read your own numbers. It holds four pages: **Gear comparison**, which shows in item tooltips how an item changes the spells you use; **Spell tooltips**, which adds what your stats give each spell; **Hit table**, your chances to hit your target; and **Trinket queue**, which swaps your trinkets for you.

Each page works behind a switch:

- **Gear comparison** and **Spell tooltips** need **Restyle chat and tooltips** on (the **Chat** page). See [Chat and windows](Chat-and-windows).
- **Hit table** needs **Restyle the minimap and HUD** on (the **Minimap** page). See [HUD](HUD). Its lines on enemy tooltips also need **Restyle chat and tooltips**.
- **Trinket queue** has its own switch at the top of its page.

The durability, thorns and stat lines on the Character window are on the **Item slots** page: see [Bags and items](Bags-and-items).

## Gear comparison

With **Your spells in item tooltips** on (as Flat UI comes), an item you could wear says in its tooltip how it changes the damage, healing or threat of the spells you chose, against what you wear in its slot. On the Character window, an item you wear says what it gives. The **Gear comparison** window shows every spell you chose at once.

The page has two tabs: **General**, for the tooltip lines, and **Window and finder**, for the window, its button and the item finder.

### When the lines show

**Show gear lines** sets when an item's lines show:

- **With the game's comparison** (the default): while the items you wear show beside the tooltip. With **Compare items only while holding Shift** on, on the **Combat and extra lines** tab of the **Tooltips** page, that is while you hold Shift. On the Character window, it is while you hold Shift.
- **Always**, **While holding Shift**, **While holding Ctrl** or **While holding Alt**.

An item link you click in chat shows the lines at every choice. The game opens that tooltip only for a plain click and never builds it again as a key goes down.

**Spells in an item tooltip** sets how many spells an item lists, from 1 to 8 (5 as Flat UI comes). The rest are counted in a last line, as "and 3 more: /flatui gear".

A few things to know:

- Shirts, tabards, relics, bags and quivers get no lines.
- An item you cannot wear yet says so, and its numbers are for you as you are now.
- An item with random stats says "Random stats not known".
- In a fight, an item shows the lines worked out before it. One not worked out yet says "Gear lines show out of combat."

### Reading the lines

The item lines and the spell lines share one look:

- A gold header sits over a block of more than one line.
- Each figure is on the right in white.
- A change is green when it is better for you and red when it is worse.
- A ~ before a figure marks an estimate.
- One dim line of notes ends each block. **Notes under the lines**, on the **Spell tooltips** page, chooses **Compact** (one line) or **Full** (every note).

The lines count your stats before the enemy's armour and resistances, and without talents and buffs your stats do not show, such as a talent that turns one stat into another or adds crit to one school. Procs, use effects and set bonuses are not counted.

Spell Piercing counts. A damage spell of a school of magic does the damage your piercing adds, so piercing on an item raises it. The piercing of one school, such as Fire Piercing, counts for that school's spells alone. Piercing that no spell you compare can use is named as not counted.

Every weapon counts at the full skill of its line for your level, with what your race and gear add, now and with the item alike. The comparison is between items, so a sword you have yet to train up is not marked down for it. Where your skill in a compared weapon is lower, a note says so, as in "Swords 230/275: until you raise it you miss more".

### The Overall line

With **Overall change** at **Weighted** (the default), an item's lines and the window open with one **Overall** line, as in "Overall Damage +2.4% · Threat +1.1% · Damage taken -2.1%". **Off** leaves it out.

It is the change in what the spells you chose do in a minute with the item:

- Your auto attack, Auto Shot, wand and seals count the whole minute.
- Each other spell counts as often as a minute of the rotation Flat UI holds for your class and spec uses it. That rotation is a three-minute boss fight with the usual build of your class and spec.
- Heroic Strike, Cleave, Maul and Raptor Strike count only what they add over the swing they take the place of.
- Each spell counts times its weight, 1 unless you set another in the window, from 0 to 5.
- Where avoidance shows, **Damage taken** is what an enemy's swing does to you, with the item against without it. Less is better.

Flat UI holds a rotation for Fury, Arms and Protection warriors, Retribution and Protection paladins, hunters, Combat rogues, Shadow priests, Elemental and Enhancement shamans, Fire and Frost mages, warlocks with most points in Demonology or Destruction, Balance druids, and feral druids in Cat or Bear Form. Your spec is your druid form, else your tank spec while your role is tank, else the talent tree with the most points. For healers, for the other specs, and for healing, which the rotations have no spell for, the spells you chose share the minute's 40 global cooldowns evenly. The window's **Overall** tooltip names the rotation it counts.

### Against

The **Against** section sets the enemy the lines count against, in item tooltips and the window:

- **Against**: **A boss at level 60, else an enemy of your level** (the default), **An enemy of your level** or **A boss three levels above you**. Misses, dodges, parries, glancing blows and crits count as the hit table counts them against that enemy. The share an enemy above you resists for its levels is left out.
- **Where you stand**: **In front as a tank, else behind** (the default), **Behind** or **In front**. From the front an enemy also parries and blocks. Your role is read as for the hit table.
- **Hit cap against a boss**: **As on the Hit table page** (the default) follows that page's row, also while the hit table is off. The other choices are **9% melee, 16% spells (Classic tests)** and **8% melee, 17% spells (the game's tooltip)**. Which holds on WoW: Forever is not known yet.

### Avoidance for tanks

**Avoidance**, under **Tanking**, adds how an item changes an enemy's swing against you: how often it misses you, is dodged, parried or blocked, crits or crushes, and what your armour and block value take off. Lines read as "Dodged +0.80% (13.40%)" and "Critical hit -0.60% (1.20%)", with a dim note of the defence at which you are immune.

- **For tanks** (the default) shows it while your role reads tank. **Always** and **Off** hold whatever your role.
- The window gets an **Avoidance** view with the whole table, now and with the item.
- `/flatui status` says your table now.
- **Enemy hit for block value** (1500) is the size of an enemy's hit, before armour, that your block value is measured against. A blocked swing loses your block value, at most the whole hit. Set it near what the enemies you tank hit for. It is an estimate.

Damage taken shows once in an item's tooltip: in the **Overall** line, or in the avoidance lines while **Overall change** is off. The rules of misses, crits and crushing blows are the game's own. What a boss takes off your dodge, parry and block, and one roll for the whole table, are Classic's rules, marked with ~.

### Choosing the spells

Until you add or remove a spell, Flat UI compares your class's main spells for your role, and they follow your role and form. The **Spells counted** section changes the list, for item tooltips and the window alike:

- **Add a spell** lists your spells Flat UI can work out, and your auto attack, Auto Shot or wand.
- **Remove a spell** takes one off.
- **Add the spells of a bar** adds each spell on an action bar that Flat UI can work out, with the rank on the bar. That counts for a low rank you keep there. Action bar 1 is the one your main bar shows now.
- **Back to your class's spells** goes back to the main spells for your role.

In the window you can also drag a spell from your spell book onto it, and right-click a spell's row to take it off.

### The Gear comparison window

The window shows every spell you chose, now and with an item. Open it in any of these ways:

- `/flatui gear`, or the **Gear comparison window** key under **Flat UI** in the game's Key Bindings. Both open and close it.
- The **Compare gear** button on the Character window.
- **Gear comparison window** on the **Window and finder** tab.
- Alt-click an item link in chat, such as one someone posts in Trade or raid chat. The window opens, or comes up, with that item. In a fight, a window not yet opened this session opens when the fight ends.

To compare an item, drop it on the window, find one with **Find**, or Alt-click its link in chat.

**Views.** The switch at the top shows the spells as **A cast**, **A second** or **Threat**, and as **Avoidance** where **Avoidance** lets it show:

- **A cast**: what one cast does, its expected damage or healing, or its threat for a line that does no damage. Your auto attack, Auto Shot, wand and seals count a second of your swings or shots, so a slow weapon is never set against a fast one swing for swing.
- **A second**: a cast over its cast time (at least the global cooldown), a spell over time over its duration, your swings and shots over their speed.
- **Threat**: the threat of one cast, with your stance, form, Righteous Fury and talents.
- **Avoidance**: how an enemy's swing fares against you, now and with the item.

The window names the spell on show that gains the most and the one that loses the most, in percent as their rows say (none under **Avoidance**).

**Weights.** The **Weight** column sets how much each spell counts in the **Overall** line. Click it for 0.5 more, right-click for 0.5 less, and Shift-click to put it back to 1. At 0 a spell is left out.

**Against.** The second item box, **Against**, compares the item with another of the same slot instead of what you wear. Drop an item there, or right-click one in the item finder. Right-click the **Against** box to compare with what you wear again.

**Clicks on the items.** With nothing on the cursor:

- Shift-click the item, or the one in **Against**, to put its link in the chat line, in a fight too.
- Ctrl-click it to try it on. In a fight, trying on waits for its end.
- Right-click the item to take it out of the window.
- Shift-click the **Overall** line to put the verdict in chat, as "[Lionheart Helm] Overall Damage +2.4% · Threat +1.1% vs [Helm of Valor]". The "vs" item is the one in **Against**, or else the one you wear in that slot. With no chat line open, one opens with the text.

**Size and place.** Drag the bottom right corner to size the window; each character keeps its size. **Window text size** sets its text, from 10 to 16 (12 as Flat UI comes). **Reset the window**, or a double-click on the title bar, puts its size and place back, and chat says so. The window also has a box in `/flatui move`, named **Gear comparison**.

### The Compare gear button

With **Button on the Character window** on (as Flat UI comes), a **Compare gear** button sits on the Character window's title bar, left of the close button.

- Click it to open and close the **Gear comparison** window. Its words light up while the window is open.
- With an item on the cursor, or one dropped on the button, the window compares that item.
- Right-click it to open the item finder.
- Where the title bar is crowded, as a long name can make it, the words fold away and the gear icon stays.

To move it, use its box in `/flatui move`, **Compare gear button**, which shows while the Character window is open. The button keeps that place on the Character window and moves with it. Right-click the box to put the button back on the title bar.

### The item finder

The item finder searches for gear to compare. Open it with **Find** on the window, a right-click on the **Compare gear** button, or **Item finder** on the **Window and finder** tab.

- Type a name in the search box, or paste a link.
- Narrow it by slot, armour type, weapon type, quality and required level. A right-click on the slot, armour or weapon filter sets it back to Any, and on the quality filter back to Poor and up.
- Choose where to look: **All items** (every weapon and piece of armour in the game), **Bags and bank**, and **Other characters**. Items bound to your other characters are left out.
- **Only what you can wear** leaves out what your class can never wear.
- **Best for me** works out the **Overall** change of each item on the page for you and sorts the page by it: healing for a healer, threat for a tank, damage for the rest. Click it again to sort by item level.

Two rows set how the finder starts. **Levels the finder starts with** is **Near your level** (items you need at most your level + 5 to wear) or **Any level**. **Only what you can wear** is on as Flat UI comes. You can change both in the finder.

Click a result to compare it, right-click to compare against it, Shift-click to link it, and Ctrl-click to try it on. As in the bag search, a cross at the right of the search box clears it, and Up and Down bring back the last five searches of the session.

**Placing it.** The finder hangs on the window's right, or on its left when the screen has no room. Drag its title bar, or its box in `/flatui move` (**Item finder**), to give it a place of its own, which your profile keeps. **Dock** on its title bar, a right-click on the title, or a right-click on its box hangs it on the window again. **Minimize** folds it to its title bar with the search box. Its box shows in `/flatui move` only while the finder is open.

### Commands

| Command | What it does |
| --- | --- |
| `/flatui gear` | Opens or closes the **Gear comparison** window |
| `/flatui gear <item>` | Compares a shift-clicked item in the window |
| `/flatui gear add <spell>` | Adds a spell to the comparison. A shift-clicked spell keeps its rank. |
| `/flatui gear remove <spell>` | Takes a spell off |
| `/flatui gear bar 1` | Adds the spells of action bar 1 (2 to 8 likewise) |
| `/flatui gear reset` | Goes back to your class's main spells for your role |
| `/flatui gear weight <spell> <0 to 5>` | Sets how much a spell counts in the **Overall** line, in steps of 0.5 |
| `/flatui gear list` | Prints the spells it compares |

## Spell tooltips

The **Spell tooltips** page adds lines to your spells' tooltips: what your stats add to each spell, its total, its threat and its next rank. They show over your action bars, in the spell book and on spell links.

The values are WoW: Forever's own, from the game's spell data and tooltips and, where those do not say, from tests in the game. A ~ marks an estimate. In a fight the game withholds your stats, so the numbers are those from before it, while stances and forms count at once.

### Spell power and attack power

**Spell power and attack power lines** (on) says what share of your spell damage, spell healing or attack power a spell or ability adds: a cast, a tick or a target.

- With **With your stats** (on), the line also says how much that is now, as "81.4% of Frost spell damage +417".
- Weapon abilities show their weapon damage and the share of attack power their weapon's speed gives them.
- Where the game's own text already counts your stats, as Revenge's does, the line says so.
- **Less for low ranks (estimate)** (on): on WoW: Forever, a rank far below your level gets less of your spell damage and healing. Flat UI counts it in full for 17 levels after the rank is learned, then 5% less a level. This is an estimate from players' tests, marked with ~.

### Total, average and rates

**Total of a cast** (on) gives what one cast does with your stats, the rank's own base and what your stats add together. It reads "Total 973 a cast (556 + 417)", or for Shield Slam Rank 4 with 101 block value "Total 857 a hit (655 + 202)".

- A spell over time gives its total over its duration, with a tick.
- A channel gives the whole channel, and a heal its healing.
- A weapon strike gives one hit with the weapon you wear.

**Average and rates** (on) adds short dim lines under the total, each with its figure on the right:

- **Expected**: what the total does on average with crits, misses and, for a spell, the damage your Spell Piercing adds, against the enemy **Against** names on the **Gear comparison** page.
- **Per second**: of cast time, or of the global cooldown for an instant.
- **Per mana**: for a spell that costs mana, what a point of mana gives, with how many casts a full bar of mana gives, as "2.9, 23 casts from full mana".

So two ranks of Frostbolt, or Flash Heal and Heal, compare at a glance.

### Next rank

With **Next rank** (on), a spell with more ranks ends with the level of its next rank, as "Next rank: Rank 6 at level 32", or in green "Rank 6: you can learn it now" once you reach that level.

- A rank no trainer teaches, one of the class books of Ahn'Qiraj such as Frostbolt Rank 11, reads "Rank 11 comes from a book, not a trainer".
- Nothing shows at the top rank, once you know a higher rank, or on talents, pet spells and judgements.

### Threat lines

**Threat lines** names the threat of a spell:

- **Where threat is special or changed** (the default): abilities with threat of their own, and spells whose threat your stance, form, Righteous Fury, talents or gear change. Not a damage dealer's Battle Stance or Cat Form, nor heals at the usual half a point a point healed.
- **On every spell**, or **Off**.

With your stats, the line gives the threat of one hit or cast, from the same total as **Total of a cast**. Under it, short dim lines say how it is made and each multiplier. Shield Slam Rank 4 in Defensive Stance with Defiance 3/3 and 101 block value reads "Threat ~2,401 a hit", then "(damage + ~255) x 2.16" and "Defensive Stance x1.8, Defiance 3/3 x1.2". A flat threat gives its number too: Sunder Armor reads 552 with 1,000 attack power.

A taunt, and a rule with no number a hit, say their rule in words, as does every spell while **With your stats** is off. A spell whose threat on WoW: Forever is not known, such as Whirlwind, Execute, Power Word: Shield and the absorbs, gets no line.

### Showing

- **Show spell lines**: **Always** (the default), **While holding Shift**, **While holding Ctrl** or **While holding Alt**. With a key, the lines come as it goes down over your action bars, and in the spell book or over a link once you point at it again. A spell link you click in chat shows them at every choice.
- **Hint while the key is up** (on): while the lines wait for a key, a spell Flat UI has lines for ends its tooltip with one dim line, as "Shift: your numbers for this spell". It goes as you hold the key. A spell that would get no line with the options you chose gets no hint either.
- **Notes under the lines**: **Compact** (the default) keeps at most one dim line of notes under each block. **Full** shows every note, such as what a multiplier comes from or why a figure is an estimate. This row serves item tooltips too.

## Hit table

The **Hit table** page shows your chances to hit your target: under your player frame, and on the tooltip of an enemy you point at.

### Under the player frame

**Hit table under the player frame** shows your chances against your target to miss, be dodged, parried or blocked, glance, crit and hit. It works them out again as your gear, buffs, weapon skill, form and target change.

- **For tanks and damage dealers** (the default) shows it while you count as a tank or a damage dealer, and hides it while you count as a healer.
- **Always** and **Off** hold whatever your role.

Your role is read as **Flat UI setup** reads it: your group role, else a tank stance, form or aura, else the talent tree you put most points in, else your class (a priest heals). It follows a new group role, your talents, a switch of dual spec, your level and a change of form or aura. `/flatui status` says which role you count as, and why.

**What you see:**

- A line each for your swings (each hand while you dual wield), your special attacks, your ranged attacks and your spells, as **Attacks** picks them.
- Columns for Miss, Dodge, Parry, Glance, Block, Crit and Hit, in percent.
- Cap: the most your swings can crit, after misses, dodges, parries, glances and blocks. It turns yellow once your crit is past it.
- The title names your target's level, as "Target level 6". A target whose level shows as ?? counts as three levels above you.

**In a fight** the game withholds your stats. The table then shows the numbers the game last gave out of one, in the stance or form you are in where it has them.

- A light dash is a number the game has not given out of a fight since you logged in or reloaded, as after a reload in a fight.
- A dark dash marks a part the attack cannot have, as a parry from behind.

**Resist.** Your spells also get Resist, which is not part of the roll: the share of a spell's damage resisted on average, with your Spell Piercing. The enemy's own resistances are not known and count as none. With piercing it goes below 0, in green, for the extra damage a creature takes. A creature above you resists about 2% more a level, Classic's rule and an estimate here, which piercing does not lower. The piercing of one school, such as Fire Piercing, counts in the gear comparison and in a spell's **Expected** line, not here. `/flatui status` says what Resist counts.

### What it shows

- **Attacks**: **By your class and form** (the default) gives melee for a warrior or rogue, ranged for a hunter, melee and spells for a paladin or shaman, and spells for the others. As a druid you get melee in Bear or Cat Form. Out of them you get spells, and your swings too while you hold a weapon, but no line for special attacks. You can also pick **Melee**, **Ranged**, **Spells** or **Melee, ranged and spells**. Ranged needs a bow, gun, crossbow, thrown weapon or wand.
- **Special attacks** (on): a line for your abilities under your swings. They do not glance or take the dual wield miss.
- **Against**: **Your target** (the default) or **A boss three levels above you**. With no enemy targeted, the table counts an enemy of your level.
- **Where you stand**: **Behind, in front while it attacks you** (the default), **Behind** or **In front**. From the front an enemy can also parry and block. The game does not say where you stand, so the first choice counts you in front while you hold your target's threat, as a tank does.
- **Hit cap against a boss**: **9% melee, 16% spells (Classic tests)** (the default) or **8% melee, 17% spells (the game's tooltip)**. Tests of Classic found the first 1% of your hit lost against a boss and 1% of spells always missing. The hit tooltip of the character sheet leaves both out. Which holds on WoW: Forever is not known yet.

### When it shows

- **Show**: **With an enemy targeted** (the default), **In combat** or **Always**. Where it hides, it fades in over 0.15 seconds and out over 0.35 seconds, and an enemy targeted again during the fade brings it back at once.
- **Tooltip when you point at it** (on): pointing at the table says what Cap and the dashes mean, and why a number is from before the fight or not given, as `/flatui status` does. While the table shows, an enemy right behind it gets this tooltip in place of its own. Clicks go through the table to the world either way.

### Look

- **Font**: **Flat UI Sans** (the default) or **Game font**.
- **Text size**: from 70% to 200% (100%, which is 11 px). While the target frame stands right beside your player frame, the text gets smaller so the table ends before it.
- **Background and border** (on): a flat background with a thin border, in the colours of the **Flat UI** page, or of **Own border and background** on the **Minimap** page. It is see-through at **Background opacity**, so the bar of an enemy's nameplate far behind the table can show through it. **Own border and background** with a higher opacity makes it more solid.

### Placing it

The table hangs under the player frame, and under the pet frame, the totems and a cast bar that Edit Mode locks there. `/flatui move` gives it a spot of its own, in its box named **Hit table**. Wherever it is, it steps down under your pet frame where it would run into it, and back up when the pet goes.

In [test mode](Test-mode) the table shows at all times, whatever **Show** says, as long as it is on for your role. With no enemy targeted, it counts against a boss three levels above you, so you can see where it sits.

### On enemy tooltips

**On enemy tooltips** adds your hit table to the tooltip of an enemy you can attack, also **For tanks and damage dealers** by default. Each attack gets a line, as in "Swing  M8 D6.5 G40 C12.1 H33.4":

| Letter | Means |
| --- | --- |
| M | Miss |
| D | Dodge |
| P | Parry |
| G | Glance |
| B | Block |
| C | Crit |
| H | Hit |
| R | On the Spells line: its Resist, as R-2.5 |

The numbers are in percent, against that enemy's level. A level shown as ??, or a boss of your level or above, counts as three levels above you. Parries and blocks count only from the front, and a tank counts in front. The lines follow **Attacks**, **Special attacks**, **Where you stand** and **Hit cap against a boss**, whatever **Hit table under the player frame** is set to. In a fight the numbers are from before it, and a dim line says so.

- **Only while Ctrl is held** (on): the lines show only with Ctrl, held as the tooltip shows, or pressed while it shows. They leave when the tooltip next changes, not as you let go.
- **Hint while Ctrl is up** (on): while Ctrl is up, an enemy's tooltip ends with one dim line, "Ctrl: your hit table against it". It becomes the header of the lines as you press Ctrl.
- **Text size on enemy tooltips**: from 70% to 200% (100%), a share of the size of the tooltip's text. The tooltip's other lines, and every tooltip after it, keep the game's size.

## Trinket queue

The **Trinket queue** page swaps your trinkets for you. **Trinket queue**, at the top, is on as Flat UI comes, but it swaps nothing until you turn on a slot's **Auto queue**.

### How the queue works

Each trinket slot has its own list, best first. Whenever the trinket you wear is on cooldown, Flat UI puts on the highest trinket of that list you carry that is ready. It goes back to a higher one as soon as that one is ready again.

1. Open the **Trinket queue** window, with `/flatui queue` or the small square beside a trinket slot on the Character window.
2. Add your trinkets to the list of each slot, best first.
3. Tick **Top trinket slot** or **Bottom trinket slot** under **Auto queue** on the page, or the **Auto queue** box in the window. Both are off until you do.

Some rules:

- **Ready with this much left** (30 s, from 0 to 60): a trinket with that much of its cooldown left, or less, counts as ready. Putting on a trinket with a use starts a 30 second cooldown on it anyway. A trinket just put on is never swapped for a lower one in that time. At 0, only a trinket off cooldown counts.
- A trinket with no use can be in the list too. It is worn while nothing above it is ready.
- The game changes no trinket in a fight, so a swap waits for its end. It also waits while you cast, are dead, hold an item on the cursor, or your bags are busy.
- A trinket you put on yourself, or with an equipment set, stays until you use it or press **Queue now**.
- A slot you empty yourself stays empty until you put a trinket in it or press **Queue now**.
- A trinket that would bind when worn is left for you to put on once.
- A trinket whose cooldown Flat UI cannot read stays on. One the game will not let you wear is left out until you press **Queue now**.

The lists, each slot's **Auto queue** and **Pause all** are kept for each character, whatever profile is in use. A profile that switches by itself in a dungeon or a raid never turns the queue off. See [Profiles](Profiles).

### The Trinket queue window

Open it with `/flatui queue`, the **Trinket queue window** key under **Flat UI** in the game's Key Bindings (which opens and closes it), the square beside a trinket slot, or **Trinket queue window** on the page, which opens it on the slot you choose.

- Switch between **Top trinket** and **Bottom trinket** at the top.
- Click a trinket under **In your bags** to add it at the end of the list, or Shift-click it to put it first. You can also drop a trinket on the window.
- Fill an empty list with **Copy the Top trinket list** (or Bottom). It puts the other slot's trinkets there in the same order, with each **Delay** and **Stop**, and the window's foot says how many it took.
- Move a trinket with the arrows. Shift-click an arrow to move it to the top or the bottom.
- **Delay** keeps a trinket on that long after you use it, so its buff runs out first. Click it for 5 seconds more, right-click for 5 less, and Shift-click for none.
- **Stop** keeps a trinket on while you wear it.
- The cross takes a trinket out of the list.
- Click a trinket's icon to wear it now. A copy already bound to you goes on first, so a spare that binds when worn stays unbound.
- With the chat box open, Shift-click a trinket's icon, the worn one's or one under **In your bags**, to link it, in a fight too.

A cooldown inside **Ready with this much left** shows in the Ready colour, since the queue already counts that trinket as ready.

- **Queue now** lets the queue act on that slot at once. It forgets a trinket you put on or took off yourself, and one the game refused, and leaves **Stop** and **Delay** aside this once. The foot says the slot looks again now, or as the fight ends.
- **Pause all** stops every swap of both slots until you press it again.

**Placing it.** The window has its own box in `/flatui move`, **Trinket queue**. Until you give it a place, it opens right of the **Gear comparison** window while that is open, so neither hides the other. A double-click on its title bar puts it back at that first place.

### The squares on the Character window

With **Buttons by the trinket slots** on (as Flat UI comes), a small square sits right of each trinket slot on the Character window. Its colour says how that slot's queue stands:

- Your accent colour while it is on.
- Orange while it waits, such as for the end of a fight, your cast or a delay.
- Red while it is held (you put on or took off a trinket yourself), kept on by **Stop**, paused, or the game refused a trinket.
- Grey while it is off.

Point at it for why. Its tooltip changes as soon as you click and counts a cooldown down while you point at it.

| On the square | What it does |
| --- | --- |
| Click | Opens the window |
| Shift-click | **Queue now** for that slot, which clears a red square |
| Right-click | Turns that slot's queue on or off |
| Shift-right-click | Pauses or resumes every swap |
| Drop a trinket | Adds it to that slot's list |

### When it swaps

- **Say each swap in chat** (on): one line with the trinket put on, the one it replaced, and why.
- **Sound on a swap**: **None** (the default), or one of seven sounds. Picking one plays it.
- **Queue line on trinket tooltips** (on): a trinket's tooltip, in your bags or on the Character window, ends with a dim line saying where it stands, as "Trinket queue: 2nd of 4, top slot". It adds " · Stop" or " · kept 20 s" from its entry, and " · Auto queue off" while that slot's queue is off. A trinket in both lists gets a line for each.

### Carrot on a Stick while riding

**Carrot on a Stick while riding** is **Off** as Flat UI comes. Set it to **Bottom trinket slot** or **Top trinket slot**, and as you get on a mount Flat UI puts Carrot on a Stick in that slot for its mount speed. As you get off, it puts your trinket back: the best ready one of the slot's list while its **Auto queue** is on, else the one it replaced.

- It needs a bound Carrot on a Stick in your bags, and waits for the end of a fight as every swap does.
- Chat and the swap sound name each swap ("riding", "off the mount"), and the slot's square says "Riding: Carrot on a Stick until you get off".
- A trinket you change yourself while riding stays until your next mount.

### Commands

| Command | What it does |
| --- | --- |
| `/flatui queue` (or `/flatui trinkets`) | Opens or closes the **Trinket queue** window |
| `/flatui queue top`, `/flatui queue bottom` | Opens it on that slot's list |
| `/flatui queue pause` | Pauses or resumes every swap |
| `/flatui queue now` | Lets the queue look again at once, also at a trinket you put on or took off yourself |
| `/flatui queue list` | Prints both lists |
| `/flatui queue copy bottom` | Fills the Bottom list from the Top one; `copy top` the other way |
| `/flatui queue clear top` | Empties the Top list; `clear bottom` the Bottom one |

`/flatui status` says what each slot waits for.

Every setting of this group, with its default: [Settings: Character and gear](Settings-Character-and-gear).
