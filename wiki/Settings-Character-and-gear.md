Every setting of the **Character and gear** group of the options window, 55 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Character and gear](Character-and-gear).

Pages: [Gear comparison](#gear-comparison) · [Spell tooltips](#spell-tooltips) · [Hit table](#hit-table) · [Trinket queue](#trinket-queue)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.52.

## Gear comparison

### General

**Item tooltips**

| Setting | Default | Notes |
| --- | --- | --- |
| **Your spells in item tooltips** | On | An item you could wear says how it changes the damage, healing or threat of the spells you chose, against what you wear in its slot, before armor, resistances (a spell counts only the damage your Spell Piercing adds) and the talents and buffs your stats do not show, such as talents that turn one stat into another or add crit to one school. On the Character window an item says what it gives. The Gear comparison window shows all of them. |
| **Show gear lines** | With the game's comparison | With the game's comparison: while the items you wear show beside the tooltip, which is while you hold Shift with Compare items only while holding Shift on the Tooltips page (Combat and extra lines tab). On the Character window, while you hold Shift. An item link you click in chat shows them at every choice: the game opens its tooltip only for a plain click and never builds it again as a key goes down. Choices: With the game's comparison, Always, While holding Shift, While holding Ctrl, While holding Alt. Needs **Your spells in item tooltips** on. |
| **Spells in an item tooltip** | 5 spells | Needs **Your spells in item tooltips** on. |
| **Overall change** | Weighted | One line at the top of an item's lines and of the Gear comparison window with what the item does overall: the change in what the spells you chose do in a minute, in damage, healing and threat, your swings and shots for the whole minute and each other spell as often as a minute of WoWSims' rotation for your class uses it (Heroic Strike and Maul on the share of your swings it gives them), where Flat UI has one for your class and talents, else for an even share of the global cooldowns, each times its weight (1 unless you set another in the window, from 0 to 5), and Damage taken where avoidance shows. Green is better, red worse, and the best and the worst spell are named in the window, whose Overall tooltip says which rotation counts. Choices: Weighted, Off. |

**Against**

| Setting | Default | Notes |
| --- | --- | --- |
| **Against** | A boss at level 60, else an enemy of your level | Misses, dodges, parries, glancing blows and crits counted as the hit table counts them against this enemy, in item tooltips and the window. A damage spell also counts the damage your Spell Piercing adds (the piercing of one school, as Fire Piercing, for that school's spells), but not the share an enemy above you resists for its levels. Choices: A boss at level 60, else an enemy of your level, An enemy of your level, A boss three levels above you. |
| **Where you stand** | In front as a tank, else behind | From the front an enemy also parries and blocks. Your role is read as for the hit table. Choices: In front as a tank, else behind, Behind, In front. |
| **Hit cap against a boss** | As on the Hit table page | As on the Hit table page follows its Hit cap against a boss, also while the hit table is off. Which holds on WoW: Forever is not known yet. Choices: As on the Hit table page, 9% melee, 16% spells (Classic tests), 8% melee, 17% spells (the game's tooltip). |

**Tanking**

| Setting | Default | Notes |
| --- | --- | --- |
| **Avoidance** | For tanks | In item tooltips and the window's Avoidance view: how an item changes the chance that an enemy's swing misses you, is dodged, parried or blocked, crits or crushes, and what your armor and block value take off, against the enemy of Against. For tanks: while your role reads tank, as for the hit table. The rules of misses, crits and crushing blows are the game's; the rest are Classic's, marked ~. Choices: For tanks, Always, Off. |
| **Enemy hit for block value** | 1500 | Damage taken counts an enemy's swing after misses, dodges, parries, blocks, crits and crushing blows and after your armor. A blocked swing loses your block value, at most the whole hit: this is the size of that hit before armor. Set it near what the enemies you tank hit for. It is an estimate. Needs **Avoidance** at For tanks or Always. |

**Spells counted**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add a spell** |  | Your spells Flat UI can work out, and your auto attack, Auto Shot or wand. For one not listed, type /flatui gear add and its name; a shift-clicked spell keeps its rank. Until you add or remove one, your class's main spells for your role are used. The list serves item tooltips and the window. |
| **Remove a spell** |  |  |
| **Add the spells of a bar** |  | Each spell on that bar Flat UI can work out, with the rank on the bar, which counts for a low rank you keep there. Action bar 1 is the one the main bar shows now. |
| **Back to your class's spells** |  | Your class's main spells for your role, which follow your role and form until you add or remove one. |

### Window and finder

**Window**

| Setting | Default | Notes |
| --- | --- | --- |
| **Gear comparison window** |  | Every spell you chose, now and with an item you drop on it. /flatui gear opens it too, and so does an Alt-click on an item link in chat, with that item. Shift-click the item there to link it in chat, Ctrl-click to try it on, and Shift-click the Overall line to put the verdict in chat. Drag its bottom right corner to size it, and set each spell's weight for the Overall line there. A key for it is under Flat UI in the game's Key Bindings. |
| **Button on the Character window** | On | A Compare gear button on the title bar of the Character window, left of the close button, opens and closes the Gear comparison window; its words light up while the window is open. With an item on the cursor, or one dropped on it, the window compares that item. Right-click opens the item finder. Move it with /flatui move (Compare gear button): it keeps its place on the Character window. |
| **Window text size** | 12 | The size of the text in the Gear comparison window. |
| **Reset the window** |  | Puts the Gear comparison window back at its first size and place. A double-click on its title bar does the same. |

**Item finder**

| Setting | Default | Notes |
| --- | --- | --- |
| **Item finder** |  | Opens the Gear comparison window with the item finder beside it: find items by name, slot, armor or weapon type, level and quality, among the armor and weapons of the game, in your bags and bank, or on your other characters. Click one to compare it, right-click to compare against it, Shift-click to link it, Ctrl-click to try it on. The Find button of the window opens it too. |
| **Levels the finder starts with** | Near your level | Near your level starts the finder on items you need at most your level + 5 to wear. You can change the levels in the finder. Choices: Near your level, Any level. |
| **Only what you can wear** | On | The finder starts with only the armor and weapon types your class can learn, and items for your class. You can change it in the finder. |

## Spell tooltips

**Lines**

| Setting | Default | Notes |
| --- | --- | --- |
| **Spell power and attack power lines** | On | What share of your spell damage, spell healing or attack power a spell or ability adds: a cast, a tick or a target, and for weapon abilities their weapon damage and the share of attack power the weapon's speed gives. WoW: Forever's own values, from the game's spell data and tooltips and, where they do not say, from tests in the game (many by wowsims/forever), Blizzard's notes and a few rules of the wowsims/forever simulator. ~ marks an estimate. |
| **With your stats** | On | How much that share is with your stats now, and the threat your attack power adds. The game withholds your stats in fights: then the numbers are those from before the fight, and a line says so. |
| **Total of a cast** | On | What one cast does now with your stats, the rank's own base and what your stats add together, as in Total 973 a cast (556 + 417), or Shield Slam Rank 4 with 101 block value, Total 857 a hit (655 + 202). A spell over time says its total over its duration and a tick, a channel its whole channel, a heal its healing, and a weapon strike one hit with the weapon you wear. Needs **Spell power and attack power lines** on. |
| **Average and rates** | On | Dim lines under the total, each with its figure on the right: Expected, what that total does on average with crits, misses and, for a spell, the damage your Spell Piercing adds, against the enemy Against names under Gear comparison, so it is less than the total but for what crits add; Per second, of cast time (of the global cooldown for an instant); and for a spell that costs mana, Per mana, a point of mana, with how many casts a full bar of mana gives. Needs **Total of a cast** on. |
| **Less for low ranks (estimate)** | On | On WoW: Forever a rank far below your level gets less of your spell damage and healing. Blizzard gave no formula, so Flat UI uses an estimate from players' tests on heals up to level 30: in full for 17 levels after the rank is learned, then 5% less a level. Marked ~. |
| **Next rank** | On | On a spell with more ranks: the level of the next rank, as Next rank: Rank 6 at level 32, or in green that you can learn it now. A rank no trainer teaches, from the class books of Ahn'Qiraj, says it comes from a book. Not at the top rank or once you know a higher one, nor on talents, pet spells and judgements. |
| **Threat lines** | Where threat is special or changed | Where threat is special or changed: abilities with threat of their own, and spells whose threat your stance, form, Righteous Fury, talents or gear change; not a damage dealer's Battle Stance or Cat Form, nor heals at the usual half a point a point healed. With your stats the line gives the threat of one hit or cast, from the same total as Total of a cast, and under it how it is made and each multiplier, as Shield Slam in Defensive Stance with Defiance 3/3: ~2,401 a hit, (damage + ~255) x 2.16, Defensive Stance x1.8, Defiance 3/3 x1.2. A flat threat gives its number too, as Sunder Armor's 552 with 1,000 attack power; a taunt and a rule with no number a hit say their rule in words. Stances, forms and Righteous Fury say what their own text does not. A spell whose threat on WoW: Forever is not known, such as Whirlwind, Execute, Power Word: Shield and the absorbs, gets no line. Choices: Where threat is special or changed, On every spell, Off. |

**Showing**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show spell lines** | Always | With a key, the lines come as it goes down over action bars, and in the spell book and over a link once you point at it again. A spell link you click in chat shows them at every choice: the game opens its tooltip only for a plain click and never builds it again as a key goes down. Choices: Always, While holding Shift, While holding Ctrl, While holding Alt. |
| **Hint while the key is up** | On | While Show spell lines waits for a key, a spell Flat UI has lines for ends its tooltip with one dim line, as Shift: your numbers for this spell, which goes as you hold the key and the lines come. Only on spells that get lines with the options you chose. Needs **Show spell lines** at While holding Shift or While holding Ctrl or While holding Alt. |
| **Notes under the lines** | Compact | For spell and item tooltips alike. Compact keeps at most one dim line of notes under each block, its notes joined; Full shows every note, such as what a multiplier comes from or why a figure is an estimate. The rates under a spell's total and how its threat is made are short dim lines that show in both. Choices: Compact, Full. |

## Hit table

| Setting | Default | Notes |
| --- | --- | --- |
| **Hit table under the player frame** | For tanks and damage dealers | Your chances against your target to miss, be dodged, parried or blocked, glance, crit and hit, worked out again as your gear, buffs, weapon skill and target change. The game withholds your stats in a fight, so there the table shows the numbers it last gave out of one; a number it has not given out of a fight since you logged in or reloaded shows a light dash, and pointing at the table or /flatui status says why. Spells also get Resist: the share of a spell's damage resisted on average, with your Spell Piercing. Your target's own resistances are not known and count as none, so below 0 it is the damage a creature takes more from your piercing; a creature above you resists about 2% more a level, an estimate piercing does not lower, which a spell that also slows or roots pays with its higher miss instead. Piercing of one school, as Fire Piercing, counts in the gear comparison and a spell's Expected line. For tanks and damage dealers hides it while you count as a healer: by your group role, else a tank stance, form or aura, else the talent tree you put most points in, else your class (a priest heals), as Flat UI setup reads it. /flatui status says which you count as, and why. /flatui move places it; wherever it is, it steps down under the pet frame, or test mode's sample of it, where it would run into it. Choices: For tanks and damage dealers, Always, Off. |
| **On enemy tooltips** | For tanks and damage dealers | Adds your hit table to the tooltip of an enemy you can attack: a line for each attack, as in Swing M8 D6.5 G40 C12.1 H33.4 (M miss, D dodge, P parry, G glance, B block, C crit, H hit, in percent; on Spells, R a spell's damage resisted on average, as R-2.5 below 0 for the damage the enemy takes more from your Spell Piercing), against that enemy's level (a level shown as ??, or a boss of your level or above, counts as three levels above you). It counts Attacks, Special attacks, Where you stand (a tank counts in front) and Hit cap against a boss below, whatever Hit table under the player frame is set to. The game hides your stats in a fight, so there the numbers are from before it, and a line says so. For tanks and damage dealers leaves the lines out while you count as a healer. Needs Chat and tooltips on. Choices: For tanks and damage dealers, Always, Off. |
| **Only while Ctrl is held** | On | The hit table's lines show on an enemy's tooltip only with Ctrl: held as the tooltip shows, or pressing Ctrl adds the lines; they leave when the tooltip next changes, not as you let go (over a unit frame, whose tooltip the game sets again every 0.2 seconds, they go with the key). Off, they show whenever the tooltip does. Needs **On enemy tooltips** at For tanks and damage dealers or Always. |
| **Hint while Ctrl is up** | On | One dim line, Ctrl: your hit table against it, at the end of an enemy's tooltip while Ctrl is up, as items and spells have. Needs **Only while Ctrl is held** on. |

**What it shows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Attacks** | By your class and form | By your class and form: melee for a warrior or rogue, ranged for a hunter, melee and spells for a paladin or shaman, melee for a druid in Bear or Cat Form and, out of them, spells, with your swings too while you hold a weapon (no line for special attacks there), spells for the others. Ranged needs a bow, gun, crossbow, thrown weapon or wand. Choices: By your class and form, Melee, Ranged, Spells, Melee, ranged and spells. |
| **Special attacks** | On | A line for your abilities under your swings: they do not glance or take the dual wield miss. Their crit, as on ranged attacks and spells, is the chance on an attack that lands. |
| **Against** | Your target | With no enemy targeted, an enemy of your level. A target whose level shows as ?? counts as three levels above you. Choices: Your target, A boss three levels above you. Needs **Hit table under the player frame** at For tanks and damage dealers or Always. |
| **Where you stand** | Behind, in front while it attacks you | From the front an enemy can also parry and block. The game does not tell where you stand: the first choice counts you in front while you hold your target's threat, as a tank does. Choices: Behind, in front while it attacks you, Behind, In front. |
| **Hit cap against a boss** | 9% melee, 16% spells (Classic tests) | Tests of Classic found the first 1% of your hit lost against a boss and 1% of spells always missing. The hit tooltip of the character sheet leaves both out. Which holds on WoW: Forever is not known yet. Choices: 9% melee, 16% spells (Classic tests), 8% melee, 17% spells (the game's tooltip). |

**When it shows**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show** | With an enemy targeted | Choices: With an enemy targeted, In combat, Always. Needs **Hit table under the player frame** at For tanks and damage dealers or Always. |
| **Tooltip when you point at it** | On | Pointing at the table says what Cap and its dashes mean, and why a number is from before the fight or not given, as /flatui status does. While it shows, an enemy right behind the table then gets this tooltip in place of its own, in a fight too; once it fades out the mouse reaches the world behind it again, and clicks go through it to the world either way. Needs **Hit table under the player frame** at For tanks and damage dealers or Always. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Font** | Flat UI Sans | Flat UI Sans is IBM Plex Sans. A language it has no letters for keeps the game font. Choices: Flat UI Sans, Game font. Needs **Hit table under the player frame** at For tanks and damage dealers or Always. |
| **Text size** | 100% | 100% is 11 px. While the target frame stands right beside your player frame, the text gets smaller so the table ends before it. Choices: 70%, 80%, 90%, 100%, 110%, 125%, 150%, 175%, 200%. Needs **Hit table under the player frame** at For tanks and damage dealers or Always. |
| **Background and border** | On | A flat background with a thin border, in the colours of the Flat UI page, or of Own border and background on the Minimap page. It is see-through at Background opacity, so the bar of an enemy's nameplate far behind the table can show through it; Own border and background with a higher opacity makes it more solid. Needs **Hit table under the player frame** at For tanks and damage dealers or Always. |
| **Text size on enemy tooltips** | 100% | The hit table's lines on an enemy's tooltip, in a share of the size of the tooltip's text. The other lines, and every tooltip after it, keep the game's size. Choices: 70%, 80%, 90%, 100%, 110%, 125%, 150%, 175%, 200%. Needs **On enemy tooltips** at For tanks and damage dealers or Always. |

## Trinket queue

| Setting | Default | Notes |
| --- | --- | --- |
| **Trinket queue** | On | A list of your trinkets for each trinket slot, best first. With a slot's Auto queue on, whenever the trinket you wear is on cooldown Flat UI puts on the highest one of the list that you carry and that is ready, and goes back to a higher one as soon as it is ready again; only out of a fight, since the game changes no trinket in one. /flatui queue, the small square beside each trinket slot on the Character window or Trinket queue window opens the lists. The lists and each slot's Auto queue are kept for each character. |

**Auto queue**

| Setting | Default | Notes |
| --- | --- | --- |
| **Top trinket slot** | Off | Swaps the top trinket slot by its list. Also the Auto queue box in the window and a right-click on the slot's square. Kept for this character, whatever profile is in use. |
| **Bottom trinket slot** | Off | Swaps the bottom trinket slot by its list. Also the Auto queue box in the window and a right-click on the slot's square. Kept for this character, whatever profile is in use. |
| **Ready with this much left** | 30 s | A trinket whose cooldown has this many seconds or fewer left counts as ready: putting on a trinket with a use starts a 30 second cooldown on it anyway. At 0 only a trinket off cooldown counts. A trinket just put on is never swapped for a lower one in that 30 seconds. |
| **Trinket queue window** |  | Opens the window on that slot's list: add trinkets from your bags, put them in order, set a delay or Stop, and pause the queue. /flatui queue opens it too. A key for it is under Flat UI in the game's Key Bindings. |

**When it swaps**

| Setting | Default | Notes |
| --- | --- | --- |
| **Say each swap in chat** | On | One line with the trinket put on and the one it replaced, and why. |
| **Sound on a swap** | None | Plays once as the queue puts a trinket on. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Carrot on a Stick while riding** | Off | Getting on a mount puts Carrot on a Stick in that slot; getting off puts your trinket back: the best ready one of the slot's list while its Auto queue is on, else the one it replaced, also after a reload. Only out of a fight, and only a bound Carrot on a Stick in your bags. A trinket with a use put back on starts its 30 second cooldown, as with any swap. A trinket you change yourself while riding stays until your next mount. Choices: Off, Bottom trinket slot, Top trinket slot. |

**Character window**

| Setting | Default | Notes |
| --- | --- | --- |
| **Buttons by the trinket slots** | On | A small square right of each trinket slot: its colour says whether that slot's queue is on, waits for the end of a fight or for a delay, is held or paused, or is off; point at it for why; the tooltip follows each click and counts down. Click it for the window, Shift-click for Queue now on that slot, right-click to turn that slot's queue on or off, Shift-right-click to pause or resume every swap, drop a trinket on it to add it to that slot's list. |
| **Queue line on trinket tooltips** | On | A dim last line on a trinket's tooltip, in your bags or on the Character window, says where it stands in a list, as Trinket queue: 2nd of 4, top slot, with its Stop or delay and whether that slot's Auto queue is off. A trinket in both lists gets a line for each. Not on the rows of the Trinket queue window, which show the same. |
