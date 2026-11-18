## 0.5.24

- For WoW: Forever 1.60.1 build 70938. The interface number stays 16001.
- **Combat text**, scroll areas: in a fight the numbers of **Arc** (and **Straight**) now always start level with the handle of their area, on both sides, and follow the path of their style. Until now a number that came before the one in front of it had moved a line started a line further back, lower in **Outgoing** and higher in **Incoming**, and kept that place all the way. In a burst each number started further back than the one before, so the numbers sank down the screen. Now a number that comes while the one before is still near the start takes the next free lane beside it: the same path moved sideways by about the width of a number, first away from your character and then towards it, four lanes at most. A burst, such as **Whirlwind** on several enemies, **Sweeping Strikes** or a critical hit with its procs, shows side by side, four numbers at once. Only when all four lanes are still busy at the start does a number wait for the lane that frees first, 0.3 seconds at most after it comes or after the number ahead of it in that lane, and never more than 1.2 seconds, so every number of a burst of up to 20 shows clear of the others and a long flood of hits, such as **Blizzard** on many enemies, never falls more than 1.2 seconds behind. A lane is three times as wide as a number is high, so it grows with **Size** and **Size of your text**. Each area now holds 32 numbers at once, where it held 16 (**Outgoing**) and 12 (**Incoming**), so a large burst no longer takes its first numbers off before they are seen. `/flatui status` counts the numbers that waited for a lane, and the numbers taken off early because all 32 of an area's numbers were still on screen. **Horizontal** and **Static**: when every row is busy, the oldest number goes and the new one takes its row, where before the two lay on top of each other. Each number is centred again after its font is set, so its pop grows from its middle. The setup drawing of combat text shows the lanes.

## 0.5.23

- For WoW: Forever 1.60.1 build 70938. The interface number stays 16001.
- **Gear comparison**: the **Compare gear** button on the Character window could not be clicked. The game raises the Character window above everything in its layer each time it is clicked, which put the button under the window's background and gave its clicks to the window's title bar. The button is now one layer above the window, so it stays on top and clickable.
- **Gear comparison**: the **item finder**'s search box could not be clicked. Where the screen has no room for the finder right of the **Gear comparison** window, as at the game's own UI scale on a 16:9 screen, the finder opens on the window's left, over the Character window. The game puts the Character window in front of everything in its layer each time you click it and each time one of its windows opens or closes, so the Character window lay over the search box and took its clicks. The finder now lies one layer above the window, where the Character window and the game's other windows no longer cover it, and its search box and level boxes stay above the rest of the finder and above the **Compare gear** button, also on the title bar of a minimized finder, where the search box meets that button on the Character window's title bar. The **Gear comparison** window now comes to the front when it opens or is asked for again, so a game window it opened under no longer takes the clicks and drops meant for its item, **Against** and weights.

## 0.5.22

- For WoW: Forever 1.60.1 build 70938. The interface number stays 16001.
- **Gear comparison**: the button on the Character window (**Button on the Character window**, **Spells and gear** tab of **Chat and tooltips**) is now a labelled **Compare gear** button, Flat UI's gear icon and the words, 20 high in the look of the **Windows** page, on the Character window's title bar right of the title and left of the close button, clear of both and of the stats pane button. Its words light up while the **Gear comparison** window is open. It takes the size of the Character window when you size that window, so it stays clear of the close button at any size. Where the title would run into it, as a long name in the narrow Character window can, the words fold away and the gear icon stays. It now comes and goes with the Character window however the window opens, also when it was open as you logged in or reloaded: Flat UI looks a few times a second while the row and **Chat and tooltips** are on, and at once when the game opens or closes the window. New box **Compare gear button** in `/flatui move`, shown while the Character window is open: drag it anywhere and the button keeps that place on the Character window, moving with it, as your profile keeps every moved frame; a right-click on the box puts it back on the title bar. Clicks, the drop of an item and the tooltip are as before.
- **Minimap and buffs**, **Tracker, loot and alerts**, **Loot rolls** (on): a roll now has Flat UI's look all through: a flat background and thin border in place of the game's toast, the item's icon cropped (**Icon crop**) with a thin border in its quality colour, the name in that colour, a flat timer bar in your **Bar texture** with a thin border, across the foot of the roll, and **Need**, **Greed** (or **Transmog**) and **Pass** in a row at the right. Off gives the rolls the game's look back. The rolls also move: drag the new **Loot rolls** box in `/flatui move`, sized for four rolls and starting where the game stacks them. Until you move it the game places the rolls as before; once you have, they stack from there with the game's spacing, also in a fight, and new row **Rolls stack** (**Up**, as the game stacks them, or **Down**) says which way. A right-click on the box gives them back to the game.
- **Nameplates**, **Target and marks**, new row **Overpower on enemy nameplates** (on, warriors only): when an enemy dodges you, Overpower's icon shows above its name, centred, with Flat UI's thin border, at **Overpower icon size** (26). It glows with the calm proc glow of the action buttons while you can use Overpower now, and is grey, dim and still while you cannot: the wrong stance, too little rage, or its cooldown (the global cooldown does not count). It goes when you cast Overpower, when its 5 second window ends, or when the enemy dies or its nameplate goes, and a later dodge of yours moves it. The game does not say whose attack was dodged and the combat log is closed to addons, so a dodge counts as yours when that enemy is your target and you are in melee with it, or when Overpower turns usable within half a second of it (your target first, else the latest dodge). The icon is made on each enemy nameplate out of combat, so a nameplate first seen in a fight gets its icon when the fight ends; `/flatui status` counts those.

## 0.5.21

- For WoW: Forever 1.60.1 build 70938. The interface number stays 16001.
- **Gear comparison** window: the **item finder** now moves in `/flatui move`. Drag its box, or its title bar, and it stays where you let it go, a place your profile keeps as it keeps every moved frame; **Dock**, a right-click on its title or a right-click on its box hangs it on the window again, and **Undo** and **Reset all** know both. Its box shows only while the finder is open, so a closed finder is no longer in the way.
- **Hit table**, **On enemy tooltips**: the lines are shorter, a letter for each part and short labels, as in "Swing  M8 D6.5 P14 B5 G40 C12.1 H33.4" (M miss, D dodge, P parry, G glance, B block, C crit, H hit, in percent; a figure loses its .0).

## 0.5.20

- For WoW: Forever 1.60.1 build 70938. The interface number stays 16001.
- **Minimap and buffs**, **Tracker, loot and alerts**, new row **Questie's tracker** (on): with the Questie addon loaded, its quest tracker takes the look of the objective tracker. **Tracker background** puts Flat UI's background and thin border round it in place of Questie's own, **Tracker headers** a flat band with a thin border behind its **Questie Tracker** heading and each zone heading, **Heading size** sizes the zone headings, **Tracker item buttons** gives its quest item buttons a thin border and a cropped icon (**Icon crop**), and **Opacity in combat** fades it in a fight. While the **Fonts** page is on, its heading and lines take that page's **Interface font**, **Text outline** and **Text shadow**. Questie's own font sizes stay, as Questie lays its lines out by them, and it draws no bars, so **Tracker bars** has nothing to do there. Questie keeps its own look with the row off, and its settings are never changed. A Questie whose tracker Flat UI does not know is left alone, and `/flatui status` says so.
- **Chat and tooltips**, **Spells and gear**, new row **Total of a cast** (on): a spell's tooltip with power lines also says what one cast does now with your stats, base and bonus together, as in "Total 973 a cast (556 + 417)": a spell over time over its whole duration, with a tick, a channel its whole channel, a heal its healing, and a weapon strike one hit with the weapon you wear. New row **Average and rates** (on): a dim line under it with what a cast does on average with crits and misses (a heal with crits) against the enemy **Against** names, for a second of cast time (the global cooldown for an instant) and for a point of mana; none for rage and energy.
- **Spells and gear**: the spell and item lines have one look. A block of more than one line opens with a gold header; each figure has its label on the left in light grey and its value on the right in white; a change is green when it is better and red when it is worse, with its sign; ~ comes before an estimate. Numbers have thousands separated by commas, whole from 100 up and one decimal below, and percents one decimal (the avoidance table two). New row **Notes under the lines** (**Compact**): at most one dim line of notes under each block, its notes joined; **Full** shows every note.
- **Spells and gear**, new row **Overall change** (**Weighted**): an item's lines and the **Gear comparison** window open with one **Overall** line, as in "Overall Damage +2.4% · Threat +1.1% · Damage taken -2.1%", the change in damage, healing and threat over the spells you chose, each counted by its weight. Where avoidance shows, **Damage taken** says what the avoidance lines mean together: an enemy's swing after misses, dodges, parries, blocks, crits, crushing blows and your armor, with the item against without it. The block's header names what it compares against ("Instead of ..."). **Off** leaves the line out, and Damage taken then shows in the avoidance lines instead: it shows once either way.
- **Spells and gear**, new row **Enemy hit for block value** (1,500): the size of an enemy's hit before armor that your block value is measured against in **Damage taken**, an estimate.
- **Gear comparison** window: drag its bottom right corner to size it, from 380 by 220 to the size of the screen. The size is kept for each character, the name column takes what the number columns leave, the lines fill its height and the rest scrolls, and its box in the movers has its size. New rows **Window text size** (12) and **Reset the window**, which puts its size and place back. Each spell has a weight from 0 to 5, in steps of a half, set in the window or with `/flatui gear weight <spell> <0 to 5>`, which the **Overall** line counts it by (0 leaves it out), and the window names the best and the worst spell. A second item box, **Against**, empty by default, compares the item with the one you drop there, in the same slot, instead of with what you wear; item tooltips still compare with what you wear.
- **Gear comparison** window, new **Find** button and new row **Item finder**: a panel beside the window (on its left when the screen has no room on its right) finds armor and weapons by name (words in any order, or a pasted item link), slot, armor type, weapon type, required level and quality, among all the game's armor and weapons (an index of the client's items, about 11,500), the bags and bank Flat UI bags keeps, or your other characters. New row **Levels the finder starts with** (**Near your level**: up to your level + 5) and **Only what you can wear** (on: the armor and weapon types your class can learn). Results come 50 to a page, sorted by item level or, with **Best for me**, by the **Overall** change for you. Click one to compare it, right-click to compare against it, Shift-click to link it in chat and Ctrl-click to try it on. The finder has its own box in `/flatui move` (**Item finder**): it hangs on the window and moves with it until you drag its title bar or its box somewhere else, which each character keeps, and **Dock** on its title bar (or a right-click on the title) hangs it on the window again; **Minimize** folds it to its title bar with the search box, which each character keeps too, and its box gets that small.
- **Spells and gear**, new row **Button on the Character window** (on): a small button of Flat UI's own at the top right of the Character window opens and closes the **Gear comparison** window. With an item on the cursor, or one dropped on the button, the window opens on that item; an item lifted from your bags or gear goes back. A right-click opens the item finder. It hangs from the Character window without touching it, and shows only while that window does.
- **Hit table**, new row **On enemy tooltips** (**For tanks and damage dealers**; **Always**, **Off**): the tooltip of an enemy you can attack shows your hit table against it, a line for each attack, as in "Your swing  Miss 8.0 · Dodge 6.5 · Glance 40.0 · Crit 12.1 · Hit 33.4", with a **Hit table** header when there is more than one. It counts the enemy's level (a level shown as ??, or a boss of your level or above, three levels above you), parries and blocks only from the front (by **Where you stand**; a tank counts in front), and **Attacks**, **Special attacks** and **Hit cap against a boss**, whatever **Hit table under the player frame** is set to; those rows and **Where you stand** no longer grey out while it is **Off**. In a fight the game hides your stats: the numbers are then from before it, and a dim line says so, as it does for an estimate. Needs **Chat and tooltips** on.

## 0.5.19

- For WoW: Forever 1.60.1 build 70938. The interface number stays 16001.
- **Bags**: **Flat UI bags** is now on by default, for every character, so after the update your bags open in Flat UI's window unless you turned the row off before. A profile saved before with every Flat UI module that is on by default turned off, such as **Game look** of the welcome screen, keeps it off. It still stays off while another bag addon is loaded, and under the gamepad interface; chat says so only if you turned **Flat UI bags** on yourself, and `/flatui status` always does. While it stays off it still keeps its record of your characters' bags, bank and gold, so they are there if you use it later. Turned off, it gives you the game's bag windows back and stops keeping that record.
- **Minimap and buffs**, **Hit table**: **Hit table under the player frame** is now a choice, **For tanks and damage dealers** (the default), **Always** or **Off**. **For tanks and damage dealers** shows the table while you count as a tank or a damage dealer and hides it while you count as a healer, reading your role as Flat UI setup does: your group role, else a tank stance, form or aura as nameplate threat reads it (**Defensive Stance**, **Bear Form**, **Righteous Fury**, or **Your role** at **Tank** on the **Threat** tab of **Nameplates**), else the talent tree you put most points in, counted as the talent window counts the points over each tree but leaving out picks you have not applied yet, else your class (a priest heals). It follows a group role given or changed, talents spent or reset, a switch to your other talents with dual spec, a level gained and a change of form or aura. A profile where you ticked the row in 0.5.18 now has **Always**, one where you unticked it again has **Off**, and one where you never changed it has the new default, so the table now shows on your tanks and damage dealers; the other rows of the tab apply at **For tanks and damage dealers** and **Always**. `/flatui status` says which role you count as and why. Flat UI setup's suggestions read your talent trees the same way.
- **Chat and tooltips**, new tab **Spells and gear**, new row **Spell power and attack power lines** (on): a spell's tooltip says what share of your spell damage, spell healing or attack power it adds, a cast, a tick, a target, a hit or a combo point, and with **With your stats** (on) how much that is now, as in "81.4% of Frost spell damage +417", or that the game's own text counts it already, as Revenge's does. Weapon abilities say their weapon damage and the share of attack power the weapon's speed gives them, normalized where the game's data says so and at the form's swing in Cat and Bear Form, an off-hand strike (Shank, and the second line of Whirlwind and Mutilate) at the off-hand share the gear comparison counts, and Ghostly Strike and Hemorrhage at their higher percent with a dagger. The values are WoW: Forever's own, from the client data of build 1.60.1.70938 (hotfix push 114122): from the game's spell data and tooltips, and where the server does what the data does not say (Retribution Aura, Thorns, Seal of Righteousness, attack power on many abilities) from tests in the game, Blizzard's notes and a few rules of the wowsims/forever simulator; a value that is only an estimate starts with ~, as Power Word: Shield's share does. **Less for low ranks (estimate)** (on) gives a rank far below your level less spell power, by an estimate from players' tests on heals up to level 30 (in full for 17 levels after the rank is learned, then 5% less a level), marked ~. In a fight the game withholds your stats, so the numbers are those from before the fight, and a line says so. **Show spell lines** can wait for Shift, Ctrl or Alt; a spell link you click in chat shows them at once.
- **Spells and gear**, new row **Threat lines** (**Where threat is special or changed**): a spell's tooltip says its threat on WoW: Forever. It covers abilities with threat of their own (Sunder Armor, Heroic Strike, Revenge, Shield Slam, Cleave, Maul, Swipe, Lacerate, Mocking Blow, Faerie Fire in a bear form, Feint, Fade, Distracting Shot, Disengage and more), heals whose threat a talent or a paladin's Holy Light, Flash of Light and Holy Shock change (a quarter a point healed, where other heals make half a point, split between your enemies), and every spell whose threat your stance, form, Righteous Fury, talents or gear change, with each multiplier named, as in "206 + 5% of attack power; Defensive x1.8, Defiance 3/3 x1.2". A stance or form taken in a fight counts at once. Stances, forms and Righteous Fury say what their own tooltip does not. **On every spell** gives every spell a line, **Off** none. A spell whose threat on WoW: Forever is not known gets none: Whirlwind, Execute, Power Word: Shield and the absorbs of Ice Barrier, Frost Ward, Fire Ward, Shadow Ward and Mana Shield.
- **Spells and gear**, new row **Your spells in item tooltips** (on): while the game compares items (Shift, with **Compare items only while holding Shift**), and at once for an item link you click in chat, an item you could wear shows how it changes the expected damage, healing or threat a cast of the spells you chose, against what you wear in its slot, as in "Frostbolt +16.7 (+1.8%)"; an item you cannot wear yet says what it needs, a level or an armour or weapon type your class learns later ("Not wearable yet: Mail"). Your auto attack, Auto Shot and wand count a second, with the haste an item brings, and Shield Slam the block of a new shield. Ammunition counts in every ranged shot, Aimed Shot and Multi-Shot too, but only what your ranged weapon fires, arrows from a bow or crossbow and bullets from a gun: other ammunition says so, and a class that uses none gets no line. Each spell rolls on the attack table the game gives it (a hunter's shots and a paladin's judgements but Judgement of Command as ranged attacks, a wand and Thunder Clap as spells); an attack that cannot be dodged, parried or blocked only misses (Overpower, Counterattack, Ambush, Garrote, Ravage, Pounce and the judgements), and Shank never misses. Backstab, Ambush and Mutilate need a dagger in the main hand and Shield Slam, Shield Bash and Holy Shield a shield, so an item that takes it away leaves them nothing, threat included. Ghostly Strike and Hemorrhage count their higher percent with a dagger, Judgement of Command counts half against an enemy that is not stunned (~), a druid's Cat and Bear Form strikes count the form's paw also out of the form, and Penance and Holy Nova count their healing, as Holy Shock does. Rings and trinkets are counted against the one you would best replace, a two-hander against both hands, and on the Character window an item says what it gives. Misses, dodges, parries, glancing blows and crits count as on the hit table, against a boss at level 60 and an enemy of your level before (**Against**), from behind or, for a tank, in front (**Where you stand**), with the hit cap of the hit table or one of its own (**Hit cap against a boss**). Use and proc effects, set bonuses and every Equip line it cannot count are named as not counted. By default it compares your class's main spells for your role (a druid's for the form it is in; a priest's heals from level 1, with Lesser Heal until Heal is learned; a shaman's with Attack, and Stormstrike once learned); **Add a spell**, **Remove a spell**, **Add the spells of a bar** (with the ranks on the bar) and **Back to your class's spells** change them, and **Spells in an item tooltip** sets how many show (5).
- New command `/flatui gear` and row **Gear comparison window**: a **Gear comparison** window with every spell you chose, now and with an item you drop on it or give with `/flatui gear <item>`, a cast, a second or threat, both slots for rings, trinkets and, while you dual wield, one-hand weapons. An item dropped from your bags, bank or a worn slot goes back there, one dragged off an action bar stays on the cursor, and an item you can never wear says so and is not compared. Drag a spell from your spell book onto it to add it, right-click a line to take it off. The row opens the window, or brings it to the front above the options window; `/flatui move` places it; Escape closes it. `/flatui gear add`, `remove`, `bar` and `reset` change the spells, and `list` prints them. `/flatui status` says which spells it compares, against what, and when your stats were read.
- **Spells and gear**, new row **Avoidance** (**For tanks**): while you count as a tank, read as for the hit table, an item's tooltip also says how it changes an enemy's swing against you, after the spell lines and only where something changes: missed, dodged, parried and blocked, critical hits (with the defense at which you are immune), crushing blows, and what armor and block value take off, as in "Dodged +0.80% (13.40%)" and "Armor: 1.1% less damage (49.3%)", against the enemy of **Against**. Defense, dodge, parry and block ratings count by the game's own conversion, the item's armor (in Bear Form and Dire Bear Form with the 180% and 360% more those forms give it) and its agility by the armor and dodge they give, strength and block value by the block value, and a shield put on or taken off turns block on or off. On the Character window an item says what it gives. The **Gear comparison** window gets a fourth view, **Avoidance**, with the whole table now and with the item, both slots for rings and trinkets, and a tank's window starts on it; `/flatui status` says the table now, from before the fight while you fight. Misses, crits and crushing blows follow the game's own rules; what an enemy above your level takes off your dodge, parry and block, and the one roll that pushes crushing blows off a full table, are Classic's rules, marked ~. **Always** shows it for every role, **Off** never.

## 0.5.18

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Minimap and buffs**, new tab **Hit table**, new row **Hit table under the player frame** (off): a small table under your player frame, below the pet frame, its buffs and the totems the game hangs there and any **Cooldown icons** row you hang under the frame, with your chances against your target to miss, be dodged, parried or blocked, glance, crit and hit, worked out again as your gear, buffs, weapon skill, form and target change. It has a line for your swings (one for each hand while you dual wield, which miss 19% more), your **Special attacks**, your ranged attacks and your spells, picked by your class and form under **Attacks**, and the crit cap of your swings, yellow once your crit is past it, since a swing's crit past the cap is lost. A target whose level shows as ?? counts as three levels above you, **Against** can count a boss three levels above you always, **Where you stand** counts parries and blocks, which come only from the front (by default while your target attacks you, as its threat tells, in dungeons and raids too), and **Hit cap against a boss** chooses between the 9% tests of Classic found and the 8% of the game's tooltip. **Show** (**With an enemy targeted**, **In combat** or **Always**), **Font**, **Text size** and **Background and border** do the rest; while the target frame stands right beside your player frame, as in Edit Mode's Classic layout, the text gets smaller so the table ends before it. `/flatui move` places it, and `/flatui status` says where it hangs and what the game withheld, which the table shows as ?.
- New page **Bags** (off): all your bags in one Flat UI window, in **Sections** (New items, Equipment sets, Equipment, Consumables, Quest items, Trade goods, Reagents, Recipes, Ammunition, Bags and quivers, Keys, Other, Junk and Free slots) or **Bag by bag**, with your gold and free slots in its footer. Nothing moves while the window is open: what you loot gathers at the top under **New items** (**Added** once anything else that comes into your bags meanwhile joins it), and the sections are laid out again when you next open it or click that title. B, the bag bar and every window that opens your bags open it, and Escape closes it; the game's bag windows stay hidden. It opens above the bottom right corner of the screen, left of the right action bars that stand in their place, and is never wider than the screen; drag its title bar or the character's name to move it. Drop an item on a section's title to keep it there; **Items placed by hand** puts one back. Drop one on **Junk**, whose title is always there in **Sections**, to sell it at merchants from then on, or a junk item on another section to stop selling it (a grey one goes on your keep list). A split box you opened on a slot stays until you press Okay or Cancel, also when the window closes. After a clean up, the sections are laid out again once your items have stopped moving. In **Bag by bag**, a click on a bag's name sets its filters, whether clean up skips it and whether junk selling leaves it alone, as the game's bag menu does. It stays off while another bag addon is loaded, and under the gamepad interface.
- **Bags**: the search box dims what does not match, in the bags, the bank and your other characters' bags. Words look in names, kinds, slots and section names (potion, cloth, mail, head, consumables); `#junk`, `#boe`, `#quest`, `#usable` and the other keywords, `q>=uncommon` and `ilvl:20-30` narrow it; a space or `&` is and, `|` is or, `!` is not, and brackets group. Point at the box for the list.
- **Bags**: a Flat UI bank window. At the banker it is live, in place of the game's: right-click takes an item out, **Deposit** and **Take out** move every item that matches the search, and you buy bank bag slots and put bags in them on its bottom row, which the window widens for. Anywhere else it shows your bank as you last left it. **At the banker** brings back the game's bank window, from your next visit; Flat UI's then shows your bank as last seen, also at the banker. `/flatui bank` opens it, and so does a key you bind to **Flat UI bank**.
- **Bags**: the name in a window's title picks another of your characters, to see their bags and bank as they last were, with the realm of a character of another realm; while you search, each says how many items match, and with many characters the list goes on in columns. **Counts in tooltips** names your other characters on your realm and its connected realms who carry an item. **Forget a character** takes one out.
- **Bags**: **Sell junk (N)** under the bag window at a merchant sells every item with the junk coin, grey items with a price and your sell list, the way Errands sells and with its checks, also with Errands off; N is what the next click sells, and Errands' **Sell at most 12 at a time** applies to it. It and **Deposit** and **Take out** take the **Button and slot colour** and **Highlight colour** of the Windows page. The sort button cleans up your bags, or the bank at the banker, with the game's clean up. Item levels, quality borders, the bind on equip, unusable and pet food marks, the junk coin and the game's new item glow show on the slots, each with its own row, and the bind on equip mark gives way to the junk coin in the corner they share; the junk coin stays while the game holds an item for a moment, as in a trade or on the cursor.
- **Windows**: the tab **Bags and items** is now **Item slots**.

## 0.5.17

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Windows**, **Bags and items**, new row **Backpack key opens every bag** (on): B, or your key for Toggle Backpack, opens the reagent bag with your other bags, and closes them all again, as **Open All Bags** (Shift+B) does. WoW: Forever binds B to Toggle Backpack, which with **Combine bags** on shows the combined bag alone: the reagent bag has a window and a key of its own. Flat UI gives your Toggle Backpack keys the game's own Open All Bags as an override binding, outside combat, and writes none of your key bindings; a key you bind again is followed. With separate bags the key opens all of them, not only the backpack. Turned off, B toggles the backpack again. `/flatui status` names the key.
- **Movers**, **Positions and sizes** at **Kept**: a bag window you moved near the edge of the screen no longer takes the bags the game hangs beside it off the screen. The game puts the reagent bag to the left of the combined bag, and with separate bags stacks the other bags above or beside the backpack, so a combined bag kept near the left edge, or a backpack kept near the top, put them out of sight. The moved bag window now stays far enough in for those bags to show whole while they are open, and goes back to your spot when they close.

## 0.5.16

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Combat text**: experience and the other text the game draws near you no longer grows when you join a party or raid. There, with **Numbers over enemies in a group** at **The game's own numbers** (the default), the game draws the numbers over enemies, and it sizes them and that text with one setting, which Flat UI set to **Size** (140%). It now keeps **Size of experience and other gains** in a group as well, so the text keeps the size it has while you are alone, and the game's numbers over enemies take that size there. **Same as numbers over enemies** gives both **Size** again, and **Flat UI numbers** keeps Flat UI's own numbers, at **Size**, in a group. `/flatui combat` says which size is in use.

## 0.5.15

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Trackers**, **Proc alerts**, **Glow on the action button**, new row **Glow style** (**Soft**): the glow is now a faint ring in the proc's colour that hugs the button's edge and breathes slowly, reaching only a few pixels past it, so it no longer lies over the buttons beside it, and it starts with no burst. **As the game has it** brings back the game's burst and loop, and the game's own pulse and fade-in of the art. The same style draws the glow of the game's proc on Flat UI's own buttons (**Proc glow**, **Game glow**) and **Glow on procs** on the cooldown icons. The setup drawing shows it.
- **Trackers**, **Proc alerts**, **Art beside the character**: the art is larger and fainter by default, **Art size** 150% (now up to 300%) and **Art opacity** 40%, with a slower, smaller pulse and a softer fade-in. A size or opacity you set yourself stays; 100% and 65% are the game's.
- **Trackers**, **Proc alerts**: a proc that comes again within 3 seconds of its end, such as **Overpower** after each dodge, **Revenge** or **Execute** as your rage refills, no longer plays its sound again, and its art and glow carry on without fading in or bursting again.
- **Errands**, **Levelling**, **Waypoints**, new row **In-game navigation** (on): the game's own marker shows over the quest or map pin you track, such as the pin of `/way`, with its distance, and waits at the edge of the screen with an arrow while the place is out of view. Later expansions have this row in the game's options, but WoW: Forever's options have no row for it, so Flat UI turns that game setting (`showInGameNavigation`) on, out of combat, at login and when the row changes. A value of yours that is already on stays as it is. If you turn it off yourself, with `/console showInGameNavigation 0` or another addon, Flat UI leaves it off, also after a reload, until you change the row. Turned off, or with **Run errands** off, your own value is back. `/flatui status` says whether Flat UI or the game turned it on, whether the game kept it off, and when Flat UI leaves it off for you.

## 0.5.14

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Enemy cooldowns**, **Icons**, new **Place on nameplates** (**Right of the health bar**): the icons of an enemy player no longer lie over his character. **Left of the health bar**, **Above the name** and **Below the health bar** (where they were) are the other places. Beside the bar the row starts past the level box, a class icon and the room the game keeps there for two crowd control or buff icons, and above the name past a row of debuffs, so it covers none of them. The setup drawing shows the row there too.
- **Enemy cooldowns**, **Show** at **Always, used ones dark**: the game hides an enemy player's casts, and his buffs while you fight, so most of his uses cannot be seen, yet the icons showed those abilities ready, and a use never darkened them. An icon is now bright only while a use of its ability would be seen; the others are dim with a question mark, ready or used not known, and after a fight an ability seen by its buff stays dim for its cooldown, since a use during the fight was hidden. A buff he casts on another player, an ability of his pet and the aura a crowd control ability leaves on its target do not count as seeing a use. A kick of your own cast still darkens his interrupt with its time left. `/flatui status` says so, and `/flatui enemy list` says which uses can be seen where you are.
- **Enemy cooldowns**: a buff that came during a fight and still runs when it ends now starts its timer then, not at the enemy's next change of buffs. Grounding Totem no longer counts as seen by its buff, which belongs to the totem's area and has no time. A kick of your own cast also starts the timer on a plate whose player the game names only by his plate.
- **Flat UI**, **World**: new **Sparkle strength** (**Strongest**) is for a thicker sparkle of **Quest item sparkle** on quest objects and gathering nodes: **Strong** raises the game's **Particle Density** to **High** and its **Spell Density**, where the game has one, to **Reduced**; **Strongest** raises them to **Ultra** and **Everything**; their raid settings follow. A higher value of yours stays, a graphics preset is followed a second later, and **As the game has it**, or **Quest item sparkle** off, puts your own values back. More particles can cost frame rate in busy fights. New **Glow on the nearest object** (on) puts a pulsing golden glow with twinkling stars on the herb, vein or quest object your Interact Key would use, while the game gives that object a nameplate: with **Enable Interact Key** on in the game's Controls options and **Interact Key Icons** at **Show All** in Accessibility, which Flat UI leaves to you. `/flatui status` names the strength, any value the game kept, and what the glow waits for.
- **Trackers**, **Proc alerts**, new row **Procs of your class** (on): every proc and reactive ability of your class whose spell you know shows without being added, with the art beside your character, the glow on its button and its sound, as the game shows them in later expansions. Each also shows its icon with the time left past the end of the tracker row, which stays where it was. **Remove a proc** lists them too and turns one off for that character, and a proc of your class you remove from the list stays off as well; the new row **Bring back a proc** turns one on again. One you add by hand takes the place of the automatic one, with its own colour, time and sound. `/flatui tracker check` lists them after your trackers, and `/flatui tracker test` shows them.
- **Trackers**, **Proc alerts**: a warrior's **Overpower** (after a dodge or from Bloodthrill), **Revenge** and **Victory Rush**, a hunter's **Mongoose Bite** and **Counterattack** and a rogue's **Riposte** now light up whenever the game makes them usable, in a fight or out of it, also when the game gives them no buff to read; one that came while you were short of rage starts once you have it. New: a warrior's **Execute** on a target at low health, with the Sudden Death art for 5 seconds and the glow for as long as it can be used (casting it does not end it), and a paladin's **Hammer of Wrath**, with the glow alone. Each asks the game about the highest rank you know, and also follows your power, stance or form, your target and its health.
- **Trackers**, **Proc alerts**, **Art beside the character**: each proc has the game's own art in the game's place, size and colour: **Overpower** and **Riposte** across the top, turned (Bandit's Guile), **Revenge** at both sides (Sword and Board), **Victory Rush** in red at the top (Serendipity), the arcs of **Clearcasting** further out and still, **Fingers of Frost** at both sides (was at the top), **Infusion of Light** (Daybreak), **Holy Purpose** (Hand of Light), **Decimation** (Impact), **Rapid Killing** and **Remorseless** (Raging Blow) and **Cutthroat** (White Tiger). The game's art is now white, as the game draws it; **Colour** tints only the plain arc of a proc with no art of its own, and a proc's own colour still tints its art.
- **Trackers**, **Proc alerts**, **Glow on the action button**: the glow starts with the game's burst before its loop, the first proc of a fight glows at once, and it also shows on Flat UI's buttons and the game's while **Restyle action bars** is off, without the border. **Clearcasting** shown by **Procs of your class** lights no button, since any spell uses it; one you add by hand still does.
- **Combat text**: **Heroic Strike**, **Cleave**, **Maul** and **Raptor Strike** show their damage again, with the name after it when **Next melee ability names** is **After the number**, over the enemy and in the Outgoing scroll area. The game reports the swing they replace as a hit of 0 that cannot be told from the hit; when that 0 came first it took the ability's name and icon and showed them with no number, and the real hit after it was left out when it came late or when a hit on that enemy had been left out in the last 10 seconds. Both reports now go to the ability, the two show as one number, and a 0 shows nothing at all: no name, icon or **(Extra attack)** either. **Cleave** also shows its hit on the second enemy.
- **Combat text**, **Whose hits**: **One hit for each of yours** is now **Yours**. While you are alone with no pet out, every hit on an enemy you are fighting that no one else has tapped shows, so the spin of **The Ravager**, the hits of **Sweeping Strikes** and **Retaliation**, the fire or shadow of a weapon, a critical tick and an extra swing show as well; your casts, swings, shots and auras then only give a hit its icon and colour. In a party the same holds for an enemy no other member or member's pet is fighting. **Every hit while you attack** is gone, and a profile that chose it now has **Yours**.
- **Combat text**, in a group or on an enemy someone else is fighting: one hit still shows for each cast, swing, shot and aura of yours, and each swing is now the swing the game reports, so another player's hit no longer takes the place of yours between your swings. A hit of yours shows on every enemy under **Blizzard**, **Hurricane**, **Rain of Fire**, **Volley** and **Hellfire**, a harmful spell Flat UI does not know lets in hits on the enemies around as an area spell does, **Sweeping Strikes** lets in a hit on another enemy with each of your swings and strikes while it lasts, and **The Ravager**'s spin shows with its icon when the game tells Flat UI of it (`/flatui combat trace` lists what it hears). A proc that casts nothing and your pet's swings can still be missed there; the game's own numbers, which **Numbers over enemies in a group** keeps by default, show them, and `/flatui status` says so in a group with **Flat UI numbers**.
- **Combat text**: a hit waits for the next frame before Flat UI decides whose it is, so a cast, a swing and its hit that the game sends together count in any order.

## 0.5.13

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Unit frames**, **All frames: bars and pictures**, **Frame style**: **Separate parts** is the default again, so the portrait and each bar of a frame have their own border and background, as in 0.5.11. A profile that never chose a frame style on that row shows separate parts after the update, and one that chose **One frame** there keeps it.
- **Unit frames**: **Game portrait** is drawn by Flat UI in the frame's own picture, in both frame styles, as **Face** draws it, and takes **Portrait shape** like every other picture, square or round. The level **On the portrait**, the PvP flag, the Elite and Rare colours, the resting and combat colours and the portrait's fade now show on it. The game's own portrait, where the game puts it, shows only with **Flat UI portraits** off.
- **Unit frames**: choosing a **Portrait style** sets every frame's **Picture** to **As Portrait style**, so the new style shows on every frame; a frame's own **Picture** can then pick another. Switching to, importing or making a profile keeps each frame's **Picture** as the profile has it.
- **Jon Default**: no longer sets **Portrait shape**, so its portraits and the party's class icons are square, as **Portrait shape** is by default.
- **Flat UI setup**: **Your character** offers **Square portrait** (suggested), **Round portrait**, **Class icon** and **No portrait**, each in separate parts, and **One frame**.
- **Unit frames**, party frames: in **Separate parts** a party pet's name row lay over the first two debuff icons of its owner, so they could not be seen while the mouse there still showed their tooltip; the icons are now drawn over the row, and over the border of the pet's health bar, which crossed them too. **Tooltip**, **Every tooltip**: the tooltip of a buff or debuff icon on a party frame, under a party pet or in the box of buffs and debuffs that opens over a party frame stays beside its icon, as the game puts it, instead of going to the cursor, where it lay over the icons next to it and seemed to be theirs.

## 0.5.12

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Unit frames**, **All frames: bars and pictures**, new section **Frame**: **Frame style** (**One frame**) puts each frame's portrait, name row and bars in one frame, with one border and one background and the same space between every part and round them; **Separate parts** gives each part its own border and background, as in 0.5.11. Every profile shows one frame after the update. **Background**, **Border**, **Space between parts** and **Corners** (were **Bar background**, **Bar border** and **Space between bars**) move under **Frame** and are for the whole frame. In one frame the portrait is as tall as the frame, an empty bar is a slightly lighter strip, and resting, combat, threat, Elite and Rare and **Portrait border** colour the frame's border; **Game portrait** draws the face round, in the frame, and the game's own portrait shows only with **Separate parts**. Raid frames do not change.
- **Unit frames**: **Portrait shape** (was **Class icon shape**) also rounds faces, on every frame and unit, so a target no longer changes shape with the unit; a 3D head stays square. **Square portraits** is now **Flat UI portraits**, and **Picture** (**Portrait style**) and **Square picture** (each frame's **Picture**) are now **Face**.
- **Unit frames**: the name rows of the target, focus and boss frames take a player's class colour and any other unit's reaction colour, **Custom reaction colours** too, and a light row is kept dark enough for the name to read. **Own border and background** now also colours rounded borders, the dark name row and the portrait's fade, and **Portrait border** **None** no longer draws a rounded line. The level **On the portrait** shows at the end of the name row while a frame shows no Flat UI picture. The shadow behind the target and focus frames is no longer inside out. **Space between parts** reaches the boss frames, and in one frame a druid's mana bar hangs under the whole frame.
- **Flat UI setup**: the unit frame drawings show the frame style, round portraits, the game's portrait where the game puts it, the target's portrait on the right, your class's power at rest (a warrior's rage empty) and a ground behind the frames, so see-through backgrounds look as they do in the world.
- **Jon Default**: **Portrait shape** is **Round**, so the party's class icons match the round portraits.
- **Flat UI setup** is a short walk round your screen: **Your character**, **Your target and party**, **Your action bars**, **Enemies' nameplates**, **Chat** and **Helpers**, then **Your screen**. Each stop shows its choices drawn with your own name and class, marks what you have **Now** and what is **Suggested** (from your group role, stance or form, talents or class), and **Next** keeps the one picked; **Your character** offers the frame styles with **Borders and bars**. **More settings** opens that part's pages and **Every setting** lists them all; a list picked there now waits for Finish. Finish saves into the profile in use, or makes a profile of your own while you are on Default, then closes the window so you see the result, with **Reload** when one is needed. The welcome screen draws your frame and offers **Set up my screen**, **Ready-made looks** and **Keep this look**; **Ready-made** on Home, **Ready-made looks** on the Profiles page and `/flatui profiles` open the same looks, and the separate profile panel is gone. **Welcome screen layout**, **Welcome screen size**, **Do not show tick** and **Choices in each step** are gone, and **Skip keeps** is now **Keep this look uses**.
- **Unit frames**: in one frame a party pet has no name row, so its frame no longer runs over its owner's. **Fading**'s **Player frame** now also fades the frame's background, its name row and its shadow.
- **Flat UI setup**: **Ready-made looks** offers **Reload** on the card that follows when the look changes a setting that applies only after a reload; opened from Home, the Profiles page or `/flatui profiles`, its **Back** reads **Close**. The lists that pick in two steps (**Sound of one icon**, **When one icon shows**, **Row of one icon**, the pulse's sound and spot, **Item a click puts on a weapon**) and **Show as import text** are left to the options window, where they act at once.

## 0.5.11

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Nameplates**, **Threat**, **Threat glow**: the ring round an enemy's health bar no longer turns into a large red box around the plate. Its gap from the bar was worked out in the plate's units once, when the ring was made, so when the game scaled the plate up afterwards (by distance or as your target) the gap grew with it. The ring's frame now ignores the plate's scale, as Flat UI's outlines do, so the gap stays a few pixels, and a ring far larger than its bar is anchored again, or hidden in a fight until it can be.
- **Cooldown pulse**, new section **Spots**: **Pulse spots** (**One**, **Two** or **Three**) with **Icon size at spot 2** and **Icon size at spot 3** (72): each spot has its own handle in `/flatui move` and pulses on its own; spot 1 keeps **Icon size**. **Spot of one spell or item** and `/flatui pulse spot` choose where one pulses; one without a spot of its own, or whose spot is not in use, pulses at spot 1. Follows EnhanceQoL's Cooldown Pulse notification groups.
- **Unit frames**, **All frames: icons and auras**, **Party and raid frames**, **Squares for your heals over time** (off), with **Square corner** (**Top right**) and **Square size** (6): a square on a member's health bar for each heal over time of yours, each in its own colour: Renew green; Rejuvenation purple, Regrowth green, Lifebloom yellow, Wild Growth teal; Riptide blue. Where the game keeps your auras from addons in a fight, a square waits for the end of it. Follows EnhanceQoL's square indicators on group frames.
- **Nameplates**, **Threat**, **Threat colours**: **Same colours for both roles** (on); off, the three colours are a tank's, and **Threat you want as damage or healer**, **Threat changing hands as damage or healer** and **Threat you do not want as damage or healer** are for damage or healing. Follows Threat Plates' tank and DPS/healing colours.
- **Nameplates**, **Threat**, **Glow and opacity**: **Health bar background in the threat colour** (off); **Same opacity for both roles** (on) with **Opacity as damage or healer** (75%); **Opacity of enemies changing hands** (100%); **Raid-marked enemies stay clear** (off): a marked enemy never fades. Follows Threat Plates' threat transparency, marked-unit exemption and background in the bar's colour.
- **Nameplates**, **Threat**, **Threat text**: **Threat value position** (**Left**, **Right**, **Above** or **Below**), **Threat value horizontal offset**, **Threat value vertical offset**, **Threat value outline** and **Threat value colour**; **Health text in the name's colour** (off). Follows Threat Plates' threat value layout and custom colour, and its status text in the name's colour.
- **Cooldowns**, **More rows** (a new tab): **Show row 2**, **3** and **4** (off), each with **When it shows**, **Position**, offsets, **Icon size**, **Row direction** and its own `/flatui move` spot; **Row of one icon** puts an icon on one (on row 1 while that row is off). **When the row shows** (**Always**) adds **In combat**, **Out of combat**, **In a group**, **In a dungeon or raid** and **Not mounted** for row 1, and **Position** adds **Under the player frame** and **Under the target frame**. **States and text**: **When one icon shows** (only on cooldown, only when ready, or with **Border on cooldown colour**), **Glow when ready**, **Glow on procs** and **Buff time on icons** (all off). Follows EnhanceQoL's Cooldown Panels.

## 0.5.10

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Combat text**, **Whose hits** at **One hit for each of yours**: the game names no spell for a hit (only its school), so Flat UI still matches each hit to one of your casts, now by school and kind from a table of the class spells. A cast that does no damage (Hunter's Mark, Sunder Armor, Faerie Fire, a curse that only weakens, a shout, Polymorph, a totem, a heal) no longer gives the next hit its icon. Damage over time opens no slot when cast and gives its icon to its ticks; a tick of a poison or proc still shows, without an icon. A spell that flies keeps its slot for 3 seconds, an area spell takes up to 10 hits of its school, a channel takes only hits of its school, and a direct hit is no longer taken for a tick. `/flatui combat trace` names each hit's school and spell.

## 0.5.9

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Minimap**, **Text around the map**: **Show** picks **Frame rate and latency** (as before), **Frame rate only** or **Latency only**, and **Latency** picks **Home and world** (as before), **The higher one**, **Home only** or **World only**. **Colour by value**, on: a number is green, yellow when the frame rate is under 60 or the latency over 100 ms, and red under 30 or over 200 ms; fps, ms and the slashes stay white. Follows EnhanceQoL's minimap stats.
- **Data panels**: **Panel width** for each panel (0 fits the slots; wider shares the spare room between them). Under **Look**: **Text outline** (none), **Text shadow** (on), **Text colour** (white, your class colour or **Own text colour**; a slot's own colours, such as red for worn gear, stay), **Colour frame rate and latency** (on, in the steps used by the minimap), **Opacity in combat** and **Opacity out of combat** (100%; a panel is at full opacity under the mouse and while its menu is open) and **Layer** (**Under the game's windows**, **Over the unit frames and the minimap** or **Over the game's windows**). Follows EnhanceQoL's data panels.
- **Bars, bags and micro menu**, **Levelling**, **Reputation text** (**None**): **Time to next standing**, **Reputation per hour** or **Both** on Flat UI's reputation bar, after its text or alone while **Bar text** is **Hidden**. The pace is your last 30 minutes of play without time away and shows after 5 minutes; it starts again for another faction or a fall of standing, and shows nothing at the top standing. **Levelling in the tooltip** and `/flatui xp` give it too, and `/flatui xp reset` starts it again. Follows EnhanceQoL's reputation bar.
- **Unit frames**, **Player frame**, **Druid mana in forms**, on: in Bear, Dire Bear or Cat Form a thin mana bar shows under the player frame's power bar; in the other forms the frame's own bar shows mana. Follows EnhanceQoL's fixed druid mana.
- **Unit frames**, **Pet frame**, **Pet target frame**, off, with **Pet target width** (120 px): what your pet attacks, with its health and name; a click targets it. The game shows it only while there is one, in a fight too. `/flatui move` places it. Follows EnhanceQoL's pet target frame.
- **Mount key**, **Slow Fall or Levitate while falling**, off: for a mage or priest, pressed while you fall and are not mounted, the key casts it on you (it takes a Light Feather). Not in a fight. `/flatui status` says whether it is armed.
- **Fading**, **When shown**: every row can be **Only outside an instance**; with **Faded opacity** at 0% that takes the objective tracker away in dungeons and raids until the mouse is over it. New row **Damage meter** (**Always**): the mouse over any of its windows, even one moved away from the meter, or over a window's breakdown brings it back, and the game's own **Visibility** in Edit Mode still applies. **Minimap buttons** fades other addons' minimap buttons too. Follows EnhanceQoL's visibility rules.
- **Minimap**, **Buttons**, **Leave in place**: a button you tick stays where its addon puts it, out of the column or row, and goes back there at once. Follows EnhanceQoL's Button Sink exclusion list.
- **Tracker, loot and alerts**, **Queue, damage meter and zone bars**, **Clear the damage meter** (**Off**, **When you enter a dungeon or raid** or **Ask when you enter one**) with **At each raid boss** (off): not again for the same instance within an hour, so a reload or a run back after a wipe keeps the numbers; `/flatui status` names the last clear. Follows EnhanceQoL's automatic data clear.
- **Flat UI**, **Cursor**: **Cast progress on the ring** (on) and **Global cooldown on the ring** (off), each with its colour: your cast or channel runs round the cursor ring, and the global cooldown just inside it. Follows EnhanceQoL's cursor ring.
- **Errands**, **Sell at most 12 at a time** (on): grey items go first, all of them, then at most 12 items of your sell list, so the merchant's buyback still holds them; **Sell next 12** under the merchant window sells the next ones, and under the gamepad interface they wait until you next open a merchant. A grey item in a bag the game's bag menu leaves out of junk selling now stays; `/flatui status` names those bags. **Items always sold** and **Items never sold** list both lists; a pick takes one off. Follows EnhanceQoL's vendor.
- **Errands**, **Guild gold where** (**Everywhere**): elsewhere your own gold pays, and chat says why. Follows EnhanceQoL's auto repair.
- **Errands**, **Buy in bulk** (off): Shift-click an item at a merchant; beside the game's box, **Stack** buys a full stack and **Most** as many as your gold, the merchant's stock and your bags allow. Both ask first, and the game's box stays open. Follows EnhanceQoL's bulk buy.
- **Errands**, **Buy with tokens without asking** and **Sell loot still tradeable without asking** (off); a purchase that also costs 150 gold or more still asks. Follows EnhanceQoL's popup helpers.
- **Unit frames**, **All frames: bars and pictures**, **Threat border on tanks** (**Shown**): with **Not shown** a tank (the tank role or the raid's Main Tank) keeps a plain border while holding aggro; a party member's top debuff still colours it, and a member with no known role keeps the threat colour. `/flatui status` counts the tanks. Follows EnhanceQoL's aggro highlight for non-tanks.
- **Unit frames**, **All frames: icons and auras**: **Role icons for** (**Every role**, **Tanks and healers** or **Healers only**) on the player, party and raid frames; Main Tank and Main Assist keep theirs. **Party and raid frames** adds **Also on your player, target and focus frames** (the dispel border, without the type icon, and only on a target or focus you can help), **Raid marker on party frames**, **Leader and assistant icons on raid frames** (all on) and **Border for your target** (**As the game has it**; **Own colour** with **Target border colour**, which also outlines your target's party frame; or **Off**). Follows EnhanceQoL's role filter, raid icon, leader icons, target highlight and dispel tint.
- **Chat and tooltips**, **Chat text**, **History and fading**, **Show recent chat after a reload** (off), with **Lines to show again** (50) and **Numbered channels too**: after a reload or a login, the chat of the last hour comes back dimmed in your main window, no more than three quarters of what **Lines kept per window** keeps. Up to 200 lines are kept for this character, and lines the game withholds are not kept; `/flatui status` counts both. Follows EnhanceQoL's chat history.
- **Tooltips**, **Combat**: **Unit tooltips hidden**, **Where**, **Spell tooltips**, **Buff and debuff tooltips**, **Item tooltips**, and **Party and raid frame tooltips** with its key. The buff tooltips of the target and focus frames are the game's own and stay. **Icon ID** (off); your buffs and debuffs and those on party and raid frames now show their Spell ID and icon. Follows EnhanceQoL's tooltip and group frames.
- **Trackers**, **Click to apply**: the default, now **Buffs, forms and the pet**, also clicks your own buffs, forms and pet out of combat: your buff (the one last seen, never a group version or Aspect of the Cheetah or the Pack, and not while you lack the rage or mana for it), stance or form; Revive Pet, Call Pet, a warlock's last demon, and a pet on Passive to Defensive (to Assist with **Pet on defensive counts as low**). **Buffs, forms, the pet and weapons** adds weapons. Follows EnhanceQoL's Class Buff Reminder.
- **Trackers**, new section **Pet**: **Pet health minimum** (30%), **Pet on passive counts as low** (on) and **Pet on defensive counts as low** (off). Under the minimum a Pet or Demon tracker shows your pet's health in red, drawn by the game, which Flat UI cannot read; `/flatui tracker set 1 health 40` sets one tracker's own. A pet away on a flight path or in a vehicle counts as fine. Follows EnhanceQoL's pet reminders and Pet Tracker stream.
- **Trackers**: a rogue gets **Off hand poison** (**Add class trackers**), shown while the off hand holds a weapon; **Item a click puts on a weapon** picks each hand's poison, stone, oil or imbue, and `/flatui tracker check` names it. Follows EnhanceQoL's poison reminder.
- **Trackers**, **When shown**, **Hide in combat** (off): a tracker set to **Only when low or missing** shows only between fights. Follows EnhanceQoL's tracking filters.
- **Trackers**, **Low and missing**: **Low at (seconds left)** goes up to 30 minutes, and the new **Low in dungeons and raids (seconds left)** (120 s) warns earlier there for buffs and weapon enchants that last 10 minutes or more. `/flatui tracker check` says which applies. Follows EnhanceQoL's expiration warnings.
- **Trackers**: **Sound when it comes** and **Sound when it stacks** (off) for a buff or debuff tracker, in the kit of **Sound**; the game plays Raid warning, Alarm and Whisper itself, also in fights, and `/flatui status` counts them. Follows EnhanceQoL's aura sounds.
- **Cooldown pulse**: **Sound of one spell or item** and `/flatui pulse sound` give a spell or item a pulse sound of its own, or none. Follows EnhanceQoL's Cooldown Pulse.
- **Cooldowns**: **On-use gear in other slots** (off) adds the gear you wear with a use, beyond the trinkets; **Add an item** and **Remove an item** put any bag item with a use on the row, with a count when it stacks, grey at 0; **Add the spells of a bar** adds the spells with a cooldown of one action bar (bar 1 is the one the main bar shows); **Tooltips on icons** (**Off**; clicks still reach the world behind the row); **Reagent counts** (on). New looks: **Sweep colour**, **Edge line** with **Edge colour**, **Show the global cooldown**, **Countdown colour**, **Countdown place**, **Tenths below**, **Count colour** and **Count corner**. Trinkets, gear and items take ready sounds of their own. `/flatui cooldown add item`, `remove item` and `import 1` do the same from chat. Follows EnhanceQoL's Cooldown Panels.
- **Nameplates**, **Threat** (a new tab; **Colours and threat** is now **Colours**): **Threat on nameplates** (was **Threat colours**) is now on by default, with **Colour health bars by threat**. A tank's first warning now shows as changing hands. **Your role** reads your group role, Main Tank, the tank aura, Defensive Stance, Bear Form or Righteous Fury; `/flatui role` says which and sets it. **Enemies held by another tank** (on, **Another tank's colour**), **Your pet's threat counts** (on), **Early warning while tanking** (off) and **Which enemies**: normal, elite and rare, bosses, minor, neutral and tapped enemies, and **Only in dungeons and raids** (off). An enemy tapped by others keeps the game's grey. Follows Threat Plates' threat colours, role detection and threat toggles.
- **Nameplates**, **Threat**, **Glow and opacity**: **Threat glow** (**When the enemy needs you**, or **Every threat state**) rings the health bar in the threat colour; a nameplate first used in a fight gets its ring when the fight ends. **Threat colour on the health bar border** (off) colours the border below your target, focus and mouseover, while **Health bar border** is on. **Fade enemies held for you** (on; **Opacity of enemies held for you** 75%) fades an enemy whose threat you want or another tank holds, never your target or focus. Follows Threat Plates' warning glow, border colour and threat transparency; the fade stands in for its threat scale, which the game does not allow here.
- **Nameplates**, **Threat**, **Threat text**: **Threat value** (**Share of aggro**; also **Share of the tank's threat**, or **Lead while tanking**, the game's own figure) left of the health bar, with **Show threat value** (**In a group or with a pet**), **Threat value in the threat colour** (on) and **Threat value size** (100% of the game's health text); a value the game withholds on a boss still shows. **Threat colour on the name** (off). **Enemy's target**: **Name of the enemy's target** (off), right of the bar in a player's class colour, with **Only in combat** (on), **Only on your target** (off) and **Not when it attacks you** (on). Follows Threat Plates' threat value, its name colour by threat and its target of the enemy.

## 0.5.8

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Unit frames**, **All frames: icons and auras**, new section **Party and raid frames**: **Border colour of a debuff you can dispel**, **Debuff type icon on party frames** and **Raid marker on raid frames**, all on. A party or raid member's health bar gets a border just inside it in the colour of Magic, Curse, Disease or Poison while they have a debuff of that type you can dispel (the client's own filter for what you can dispel), so the bar's own border keeps showing threat and, on raid frames, your target. Party frames show the debuff's type just inside that border at the right end of the health bar, as the game's raid frames already do, and raid frames show the member's raid marker, which the game's lack. When the game withholds a debuff's type in a fight, the border is white, or is not shown when the game would not say which debuffs a member has. It takes the debuff's colour, with its type icon on a party frame, as soon as the fight ends, or once an encounter or PvP match that outlasts the fight is over, without waiting for the member's auras to change, and `/flatui status` stops saying so. Follows EnhanceQoL's dispel indicator and raid marker.
- **Healer mana** is a new page in the **Combat** group, off by default: the mana of your group's healers, by their role, or by class for a member with no role while nobody in the group has the healer role, one bar each in class colours. **Show** (**In a dungeon or raid**, or **In a group**), **Number of bars** (5, up to 40), **Bar width** (150 px) and **Bar height** (16 px). `/flatui move` places it, and `/flatui healers` shows a sample. Follows EnhanceQoL's Healer Mana indicator.
- **Data panels**: a slot can show **Equipment set**, the set you wear with its icon. Its tooltip lists your sets, the one you wear in green and one with an item missing in red, and a click opens a menu to put one on, not in a fight; the slot keeps its click with **Tooltips** off. Follows EnhanceQoL's Equipment Sets stream.
- **Tracker, loot and alerts**, new section **Zone name and talking head**: **Hide the zone name**, **Hide the subzone name** and **Hide the talking head** (with its voice), all off. **Hide the zone name** also hides the zone's name when the game shows it in the smaller line, as it does each time you leave a town, a mine or another named part of a zone; the names of those parts still show unless **Hide the subzone name** is on. Each comes back as soon as its row is turned off, without /reload. Follows EnhanceQoL's options for the zone text and the talking head.
- **Drink and health macros** is a new page in **Interface**, off by default: **Flat UI Drink** and **Flat UI Health** in your account's macro list, written again out of combat when your bags or level change. **Flat UI Drink** drinks your best drink, conjured water first when it is as good, and takes your best mana potion in a fight (**Mana potion in a fight**). **Flat UI Health** takes a healthstone, then a healing potion, starting with the one that will be ready first, and eats your best food out of combat (**Eat out of combat**), conjured food first when it is as good. Macros Flat UI made on another computer, or before the WTF folder was deleted, are kept up to date too, as the game keeps your macros with your account; a macro of those names that you wrote yourself is left alone, and chat says so once. Turned off, they are deleted once no action bar holds them: one still on a bar stays until you drag it off, and chat and `/flatui status` say so. Follows EnhanceQoL's drink and health macros.
- **Mount key** is a new page in the **Action bars** group, off by default, with **Favourite mounts first** (on). Bind **Mount or travel form** under **Flat UI** in Key Bindings: a random usable mount, a new one each mount-up; a druid takes **Aquatic Form** in water and **Travel Form** in a fight, on the move or with no mount; a shaman **Ghost Wolf**. Pressed again, it dismounts or leaves the form. `/flatui status` names the next mount, or, when the game lets you use none of your mounts here and now, says so and points you to the tooltip of the Mount button in the mount journal for the reason. Follows EnhanceQoL's random mount key.
- **Trackers**: a group buff tracker, members lacking your class buff as 2/5, read out of combat, where a member's change reads only that member again and one out of sight leaves the count within 5 seconds. For a paladin, a member who has another of your blessings counts as having it, since you can keep only one of your blessings on each member. A warrior gets no group check, since Battle Shout costs rage and is cast in fights; the warrior's own **Battle Shout** tracker (**Add class trackers**) follows the shout. Drawn as a **Bar**, a group tracker fills by the time left on the buff that ends first, also with **Bar fill** on **Charges**, and `/flatui tracker check` says how many of the members who count lack it and the time left. New section **Clicks**, **Click to apply** (**Group buffs**): out of combat a click casts the buff on one who lacks it, never over another of your blessings. **Group buffs and weapons** also puts a poison, stone or oil on the weapon, a sharpening stone only on an axe, sword, polearm or dagger and a weightstone only on a mace, staff or fist weapon, or casts a shaman's weapon imbue, the one last put on that weapon. A click on an item tracker such as **Healthstone** or **Mana gem** does nothing, since using it would only spend what the tracker counts. Follows EnhanceQoL's Class Buff Reminder.
- **Trackers**: when the page is turned off during a fight, or stops on an error in one, and is turned on again after the fight, trackers set to **Only in combat** hide and clicks work again at once, not only after the next fight ends, and an ammunition tracker set to **Only when low or missing** shows a low count again.
- **Group tools** is a new page in the **Combat** group, off by default: the eight raid markers and a clear for your target, **Ready check**, **Role poll** and **Pull countdown** (10 s; right-click stops it). A button you cannot use is greyed and says why. **Show**, **Icon size**, **Spacing**, **Layout**. `/flatui move` places it. Follows EnhanceQoL's Mark Bar and Group Tools.

## 0.5.7

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Flat UI**, **Colours**, **Cast colours**, **Interrupt readiness on enemy casts**, on, with **Interrupt ready colour** (green) and **Interrupt on cooldown colour** (orange): on the flat target, focus and nameplate cast bars, an enemy cast you can interrupt shows whether your class interrupt is ready; a cast that cannot be interrupted keeps its colour. The interrupt is your class's, every rank: Pummel and Shield Bash, Kick, Earth Shock, Counterspell, Silence, Feral Charge, or your Felhunter's Spell Lock. It counts only while the game says you can cast it, so Pummel out of Berserker Stance and Shield Bash without a shield do not, and the global cooldown alone counts as ready. **Cooldowns**, **Glow on your interrupt**, on: the interrupt's icon on the cooldown row gets a gold border while your target or focus casts something you can interrupt and it is ready. With either row on, `/flatui status` names your interrupt and says whether it is ready, on cooldown or not usable now, ready as soon as the cooldown is over. Follows EnhanceQoL's interrupt colours and interrupt glow.
- **Cooldowns**: a spell of your pet's, added with `/flatui cooldown add` and its ID or a link shift-clicked in the pet's spell book, now shows on the row while your pet knows it, and `/flatui cooldown list` and **Remove a spell** no longer call it not known. So **Glow on your interrupt** borders a Felhunter's Spell Lock too.
- **Cooldowns**, new section **Range and power**: **Tint when out of range** and **Tint without enough power**, on, with **Out of range colour** and **Not enough power colour**: a spell icon turns red while your target is out of its range and blue while you lack the mana, rage or energy for it, as the game's cooldown manager tints its own. Where the game withholds the answer the icon takes no tint. **Add a potion or healthstone** and **Remove a potion or healthstone**: healing potions, mana potions or healthstones as one icon after the spells and trinkets, the best rank your level lets you use with how many you carry, and their shared cooldown; with none you can use, the icon is grey at 0 and stays quiet. When you reach the level of a rank you carry, the icon takes it at once, in a fight too. **Sound of one icon** gives an icon a ready sound of its own; one without it plays **Sound**. `/flatui cooldown sound` finds a spell on the row by its name or by a link of any of its ranks, so a spell you picked before you trained a higher rank still takes its own sound. `/flatui cooldown add healthstone` (or `healing`, `mana`) and `/flatui cooldown sound <icon> <sound>` do the same by command. Follows EnhanceQoL's Cooldown Panels.
- **Cooldowns**, **Sound** and **Sound of one icon** play on the game's **Gameplay Sound Effects**, where the game's own cooldown manager plays its ready sounds: they follow that switch and its volume in the game's sound options, and are heard with **Sound Effects** off.
- **Cooldowns** has a new tab, **Cooldown pulse**, a module of its own and off by default: when a spell of your spell book, a trinket you wear or an item you use is ready again, its icon fades in and out in the middle of the screen, one after another when several end together. **Shortest cooldown** (20 s; the global cooldown never pulses), **Leave out** and **Put back** (a spell with all its ranks), **Icon size** (72), **How long it shows** (1 s) and **Sound** (none). It works in a fight without reading what the game withholds there. Potions, mana gems and healthstones, which share one cooldown, pulse once for the one you used, and one you left out sets off no pulse; items keep pulsing however many different ones you use in a session. `/flatui move` places it; `/flatui pulse test`, `ignore`, `watch` and `list` do the rest by command. Follows EnhanceQoL's Cooldown Pulse.
- **Combat text**, **Your character**, **No target warning** and **Entering and leaving combat**, both off: **No target** in the middle of the screen a second into a fight with no target, or with a dead or friendly one (**Warn with a friendly target**, on, can be turned off for healing), with **No target sound**, **No target colour** and **Size of No target**; and **+Combat** and **-Combat** for a moment as a fight starts and ends, in the game's words and fading like the game's own, with **Entering combat colour**, **Leaving combat colour** and **Size of +Combat and -Combat**. A group member who has released and runs back as a ghost counts as dead. When another Flat UI sound has just played, such as the **Sound** of **Cooldown pulse**, the warning's sound comes a second later while **No target** still shows; when the game plays no sound, for instance with sound effects off, `/flatui status` says so until one plays again. Nothing shows while the interface is hidden. `/flatui move` places both with the **Combat text: alerts** box. Follows EnhanceQoL's No Target Indicator and combat text.
- **Threat list** is a new page in the **Combat** group, off by default: your group by threat on the enemy you fight, highest first, one bar each in class colours, with pets a shade darker; 100% has aggro or takes it. It shows only in a fight, while your target or its target is an enemy, as **Show** says: **In a group** (the default), **In a dungeon or raid**, or **In a group or alone**. **Pets** (on), **Number of bars** (5), **Bar width** (180 px) and **Bar height** (16 px). `/flatui move` places it, and `/flatui threat` shows sample bars. With a friend as your target, such as a healer on the tank, the list of the enemy that friend targets shows within a second of the pull, also in the middle of a fight with enemy nameplates off. Where the game withholds the threat (on some bosses) the bars keep the order of the group with the pets after all the members, so the five bars of the default show every member of a party, and `/flatui status` says so. Follows the threat meter of EnhanceQoL's damage meter.

## 0.5.6

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Chat and tooltips**, **Chat text**, new section **Links**. **Web addresses as links**, on: a web address in a chat line (http:// or https://, www., or a name with a path such as discord.gg/abc) becomes a link, and a click on it opens a small box at the mouse with the address selected, ready to copy with Ctrl+C; Enter or Escape closes it, and so does a fight; in a fight a click opens none, so your keys keep working. Only the plain text of a line the game lets an addon read is changed: other links, names and icons stay as they are, and a click on any other link does what the game does. **Tooltips of chat links**, on: while the mouse is over an item, spell or achievement link in a chat window, its tooltip shows, and it goes when the mouse leaves; not in a fight. `/flatui status` says how many lines had an address made a link. An address already made a link still opens the box after **Web addresses as links** or **Restyle chat and tooltips** is switched off, or after Chat and tooltips or its web links stop on an error. These follow EnhanceQoL's chat links.
- **Chat and tooltips**, **Tooltips**, **Target of units**, on: a line naming what a unit targets, in its class or reaction colour, **You** when it is you; a withheld identity gives none. While the mouse stays on the unit the line follows a new target, also over a unit in the world, whose tooltip the game builds only once; it goes blank when the unit stops targeting, and a unit that had no target when the mouse came onto it gets the line the next time you point at it. Follows EnhanceQoL's tooltip.
- **Tooltips**, **Class colour on the class line** and **Item and spell icons**, on: a player's level, race and class line in their class colour, and the icon before the name of an item or spell.
- **Tooltips**, under **Item and spell IDs**: **Show IDs** (**Always**, or while holding Shift, Ctrl or Alt) and **Temporary enchant ID**, on: the ID of the poison, oil, stone or imbue on a weapon you wear. `/flatui status` names the key. Over Flat UI's own action buttons the tooltip is set again when a modifier key goes down or up, so the IDs, an item's comparison and a macro's `[mod]` choice follow the key there too.
- **Chat and tooltips**, **Tooltips**, new section **Item comparison**, **Compare items only while holding Shift**, on: the items you wear show beside the tooltip of an item only while you hold Shift, not as soon as the mouse is over it. WoW: Forever compares at once by default and its options have no row for it, so Flat UI turns that game setting (alwaysCompareItems) off, out of combat, at login and when the row changes, and puts the game's own value back when the row or **Restyle chat and tooltips** goes off. `/flatui status` says which applies.
- **Fading**, new section **When shown**: **Target frame**, **Focus frame**, **Buffs** and **Objective tracker**, each **Always** (the default), **Only in combat**, **Only in a group**, **Only in an instance** or **Only when not mounted** (a druid's travel forms count as mounted). At other times the frame fades like the frames above and comes back under the mouse, in Edit Mode and as **Stay visible** says. Only the opacity changes, also in a fight. Cast bars, target of target and combo points fade with their frame; debuffs stay. In a fight the tracker's **Opacity in combat** comes first while under 100%. When the fight ends the tracker fades on from that opacity instead of showing at full for a moment. The tracker comes back only with the mouse over its drawn part, not over the empty column under it. **With a target** does not hold the target frame, which the game shows only while there is a target, so its rule still fades it. Follows EnhanceQoL's frame visibility rules.
- **Fading**: when something else gives a faded frame another opacity, the frame takes it as its own and fades again from it. The objective tracker, which the game puts back to full opacity each time the interface is shown again (after Alt+Z or a cinematic), no longer stays at full until the mouse passes over it or a fight starts. At **Faded opacity** 0% a frame no longer stays invisible until /reload, under the mouse and with Fading off too, after a fade whose last step the game rounded to nothing.
- **Bags and items**, **Mark bind on equip items**, on: BoE on bag and bank items that bind when equipped and are not bound yet.
- **Bags and items**, **Tint items you cannot use**, on: red over items whose tooltip shows a requirement in red: class, race, level, skill, reputation, armour or weapon type, or a recipe you already know. A recipe is judged by its own lines, not by the item it makes, so a pattern for armour your class cannot wear is not tinted while you can learn it. Abandoning a profession tints the items that need it straight away.
- **Bags and items**, **Mark food your pet eats**, on: for hunters, the Feed Pet icon on the food your pet eats while it is out. The three marks show whatever the look of the slots, at the bank too with **Item slots** or **Bags and bank** off. A closed bag is marked when it opens, so nothing is read for it in a fight. `/flatui status` says how many slots on screen show each mark; a closed bag or bank counts none. These follow EnhanceQoL's bag overlays.
- **Item level in bags and bank** and **Dim grey items** reach the bank slots too when **Item slots** or **Bags and bank** is off.
- **Tracker, loot and alerts**, new section **Error messages**, with **Hide error messages**, off: the red error messages in the middle of the screen of the kinds you choose are not shown and make no sound or voice. Each kind has its own row, on: **Not enough mana**, **Not enough rage or energy** (also a hunter pet's focus and combo points), **Out of range** (also too far away to attack or to use an object, and too close for a ranged attack), **Facing the wrong way** (also in front of or behind the target), **Not ready yet**, **No target or invalid target** and **Not while moving**, and a spell that fails for one of these reasons counts too. Other red errors, the yellow quest messages and their sounds stay as the game shows them, except that a repeated message no longer flashes. Flat UI takes the game's error event from its error text while the row is on, and gives it back when the row, its page or the module goes off; when another addon or the game's own command has the error text off, Flat UI leaves it so. `/flatui status` says how many messages were hidden. Follows EnhanceQoL's error message filter. The game's own errors-off and the usual error macro (`/run UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")` around a cast) still work, and a kind you hide stays hidden through them.
- **Maximum camera distance** is new on the **Flat UI** page, under **World**, and off: ticked, the camera zooms out to 2.6, past the 2.0 of the game's own **Max Camera Distance**. The row shows the game's setting, so it is the same in every profile and shows a change made with the game's slider. Ticking it keeps the distance you had, and unticking it puts that distance back while the camera is still at 2.6; a distance of 2.6 or more is never lowered. Nothing is written in combat: in a fight the switch shows your choice at once, a second click takes it back, and the change waits for the end of the fight. A value the game does not keep is said in one line, and `/flatui status` says it too. **Reset page** and the game's **Defaults** button leave it as it is, as they do the rows that show the game's settings. Follows EnhanceQoL's maximum camera zoom.
- **Flat UI**, new section **Cursor**, **Cursor ring**: **Always**, **In combat only** or **Off** (the default), with **Cursor ring size** (48) and **Cursor ring colour** (white). A ring of Flat UI's own around the mouse pointer, so you find it at a glance. It takes no clicks, hides with the interface, and nothing runs while it is hidden. Follows EnhanceQoL's cursor ring, without its centre dot and its cast and cooldown progress.
- **Unit frames**, **All frames: icons and auras**, **Hit numbers on player and pet portraits**, on: turned off, the damage and healing numbers the game flashes over your portrait and your pet's no longer show, in combat too, also on a player or pet frame that keeps the game's look (**Player frame** or **Pet frame** off), so switching a frame off no longer brings them back. Follows EnhanceQoL's option for the game's hit indicators.

## 0.5.5

- For WoW: Forever 1.60.1 build 70790. The interface number stays 16001.
- **Errands** is a new page in the **Interface** group, off by default, with **Run errands**. It does chores the game leaves to you, each with its own row, and `/flatui status` has a line for each part that is on. Several errands follow EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission.
- **Errands**, **Sell grey items**, on: when a merchant opens, grey items are sold one after another, out of combat. A quest item, an item the game gives no value and a locked item stay. Hold Shift as the merchant opens to keep them that time; the repair is still made. A merchant opened in a fight waits for its end, a fight pauses the selling until it ends, and the closed window or a trade window stops it. Before each sale the merchant window must still be open and no trade window, since the same call uses or equips an item anywhere else, or puts it in the trade. One line in chat says what was sold and for how much.
- **Errands**: `/flatui sell <item>` puts an item of any quality on the list of items always sold, and `/flatui keep <item>` puts a grey item on the list of items never sold or deleted. Both take an item link, an item ID or the name of an item in your bags, and the same command again takes it off. `/flatui sell` alone lists both. The lists belong to the account.
- **Errands**, **Repair**: **With your gold** (the default), **Guild gold first** or **Off**. When a merchant who repairs opens, everything is repaired and the cost is said. Guild gold is used while the guild lets you take that much, and a guild bank that does not pay is followed by your own gold. A bill your gold cannot pay waits for the money of the grey items sold; then too little gold repairs nothing and says what it costs.
- **Errands**, **Quick loot**, on: when the game loots by itself (Auto Loot, or its key held), every slot of the loot window is taken at once. A slot being rolled for and, under master loot, an item at or above the threshold are left, and an item that asks before it binds still asks. `/flatui status` says when the game's Auto Loot is off.
- **Errands**, **Make room in full bags**, on: while the loot window is open and every ordinary bag is full, a button under it deletes the grey stack worth least at a vendor. Its tooltip names the item and its worth, and it deletes only the item it showed, never a quest item or one on the keep list. After a delete it waits for the bags to update, so a quick second click deletes nothing more. Not in combat, and not under the gamepad interface.
- **Errands**, **Train all button**, on: a **Train all** button beside the **Train** button of the trainer window learns everything the trainer marks available that you can pay for, in the order of the list. A profession is left to **Train**, which asks before it uses one of your two places. Its tooltip says what a click learns and why anything is left, and a second click before the trainer answers asks nothing. `/flatui train` does the same, also under the gamepad interface, where there is no button. While EnhanceQoL's own Train All button shows, Flat UI's stands aside.
- **Errands**, **Hold a key to release**: **In dungeons and raids** (the default), **Everywhere** or **Off**, with **Key to hold** (Shift, Ctrl or Alt). A cover of Flat UI's own lies over the **Release Spirit** button of the death popup and takes the click until the key is held. The game's button is not changed, its timer still releases you, the cover asks for the key every frame, so a key let go while the game was not looking still counts, and it takes itself away whenever it is no longer over the death popup. There is no cover under the gamepad interface, or when the game does not say whether the key is held.
- **Errands**, **Type DELETE for you**, on: the word the game asks for before it deletes a good item is written in its empty box, never over what you typed. A click on **Yes** deletes; a stray Enter does not.
- **Errands**, **Accept summons** and **Accept resurrections**, off: a summon is accepted when the game's own popup would let you, not in a fight and not on a flight path, tried again each second while it is open. A resurrection is accepted unless the one who offers it is in combat or dead, once the game's wait after recent deaths is over. The summon popup is closed once the game says the summon is over, while it is the one popup up, since a stale one would cancel the next summon; the resurrection popups are left to the game. A summon or resurrection still open after a /reload is tried again.
- **Errands**, **Accept group invites from**: **Friends** (the default; Battle.net friends count), **Your guild**, **Friends and your guild** or **Nobody**. An invite that comes in a fight is accepted when the fight ends, while its popup is still open. An invite that asks for roles, a quest-session invite, one that would take you out of a queue (the game warns about that on its popup), one that comes while you are in a group, and anyone else's are left to you. The game's invite popup closes once you are in the group, never before, since closing it sooner declines the invite, and only while it is the one popup up. `/flatui status` names the last invite accepted.
- **Errands**, **Decline duels**, off: every duel request is declined at once, also in a fight. The game closes its own popup. One line in chat per player a minute.
- **Errands**, **Remember the last mail recipient**, on: after a letter goes, the To box keeps the name while the mailbox is open. Closing the mailbox forgets it.
- **Errands**, **Say what was done**, on: a line in chat after selling, repairing, training, deleting, accepting, declining and upranking, and when a quest is left to you.
- **Errands** has a new tab, **Levelling**, for a character on its way up. Its rows follow **Run errands**, as the rest of the page does.
- **Errands**, **Accept quests**, on: the quest an NPC offers, or your group shares, is accepted out of combat. A quest that would flag you for PvP, a quest an item starts, an escort a group member starts and any quest while your log is full are left to you, and so are grey and repeatable quests unless **Low-level quests too** or **Repeatable quests too** is ticked. Hold **Shift** (**Key to do it yourself**) as you talk to an NPC and the rest of that talk is yours.
- **Errands**, **Hand in finished quests**, on: a finished quest is completed and its one reward taken; with a choice of rewards the window stays open for you. A quest that takes money, a currency or an item of green quality or better is left to you, and chat says why.
- **Errands**, **Gossip options**: **Saved, quest and only options** (the default), **Saved options only** or **Off**. `/flatui gossip` lists the options of the NPC you talk to, and `/flatui gossip 2` saves the second one. In the open world the one **(Quest)** option, or an NPC's only option when it has no quest for you, is picked too. An option that casts a spell is never picked, and nothing but saved options is picked in dungeons, raids, battlegrounds and arenas.
- **Errands**: `/flatui npc` skips the NPC you talk to or target, so its quests and gossip are left to you. **Skipped NPCs** and **Saved gossip options** list them, and choosing one takes it off. Both lists belong to the account. While EnhanceQoL's own quest or gossip automation is on, Flat UI leaves that to it.
- **Errands**, Levelling tab, **Put new ranks on your bars**, on: after training, a line at the top of the screen names the buttons that hold a lower rank of a spell you now know. Its **Uprank and reload** button puts the new ranks on them and reloads the interface in the same click, so the game's action bars are left clean. Only the highest rank of a spell on your bars moves up, so a lower rank you keep beside it, such as Frostbolt Rank 1 for its slow, stays; each stance or form page is judged on its own, so a copy left behind on another stance still moves up. Never in a fight, never while the cursor holds something or a game popup waits for an answer, and never on macros, items, the pet bar or the stance bar. **Later** holds the offer until something new is learned. **Keep a rank on your bars** (or `/flatui rank` and a spell link) keeps one rank where it is, and `/flatui uprank` brings the line back at any time.
- **Errands**, **Lines about learned spells**: **One line in their place** (the default), **Hidden** or **As the game has it**. The game's "You have learned" and "You have unlearned" lines are dropped, and by default one line names what was learned a moment after the last; with **Say what was done** off, the game's lines stay.
- **Errands**, Levelling tab, **Show the reputation you gain**, on: Flat UI's experience bar shows the faction you last gained reputation with, half a second after the gain. Of gains that come together the largest wins, so a Booty Bay quest shows Booty Bay, not the towns that gain with it. A loss is never followed, and a faction you are exalted with or have moved to Inactive is passed over. A faction you pick in the game's reputation window shows until your next gain, and unticking **Show as Experience Bar** takes it off until then. The faction the game watches is not changed, so the game's bar and window stay as you set them. The tooltip names the faction as the last one you gained with, and each character keeps its own.
- **Errands**, **Remind you of talent points**, on: when you reach a level, or log in, with talent points to spend, a line in chat says how many and the key that opens your talents. A level reached in a fight is told a second after it ends. `/flatui status` says how many points wait.
- **Errands**, **Add the /way command**, on: `/way 45.2 61.8` puts a pin on your map in the zone you are in, or the zone around the cave or building you are in, and the game points you to it. `/way Elwynn Forest 45 61`, `/way elwynn 45 61`, `/way #1429 45 61` and decimal commas work, words after the numbers are said back as a note, `/way clear` takes the pin off and `/way` alone says where you are. Also in a fight, while the world map is closed. When another addon has `/way`, Flat UI leaves it to that addon; `/flatui way` does the same in every case.
- **Cast bars**, **Text and icon**, **Spell rank on the player bar**, off: after the spell name on your cast bar, as Fireball (Rank 5), the rank of the spell you cast, read from the cast itself. Written into the game's own spell name a moment after the game writes it, only while it is still that name, so Failed and Interrupted stay as they are; in a fight only while the player bar is not protected. A rank text with no number is not shown, and a name that would not fit the bar with its rank keeps the game's text. Off puts the name back. `/flatui status` names the last one shown. Follows EnhanceQoL's cast bar.
- **Trackers**, the **Ammunition** check now follows the weapon in your ranged slot: with a bow or crossbow it counts your arrows, with a gun your bullets, in all your bags and quivers; nothing in the ammunition slot, or ammunition the weapon cannot fire, is missing, unless the game says the character needs no ammunition. A thrown weapon counts the stack in the ranged slot, low at the new **Thrown weapon minimum** (20); one that wears out goes by its durability, low at a fifth; a low stack that runs out shows missing. Set to **Only when low or missing**, a low count now waits for the end of a fight (missing still shows at once), and every tracker already hides while you are dead. `/flatui tracker check` says what it read. Follows EnhanceQoL's low-ammunition reminder.
- **Minimap**, new section **Text around the map**: coordinates (on), durability (on, yellow at 50%, red at 20%), frame rate and latency, and local or realm time, each above or below the map. A line the game withholds, such as the coordinates in an instance, is hidden, and `/flatui status` says why. These follow EnhanceQoL's minimap stats.
- **Trackers**, **Add a check**, **Durability**: your most worn item, low at the new **Durability minimum** (20%), red when an item is broken, shown only when low or missing; for 12 seconds after a ready check it is low at 40% or less and shows whatever **Show** says. `/flatui tracker add durability` adds it too. Follows EnhanceQoL's low durability warning.
- **Data panels** is a new page in the **Interface** group, off by default. A top and a bottom panel of Flat UI's own, placed with `/flatui move`; until you move it, the top one hangs under the game's battleground scores and other top-centre widgets. Each has six slots: bag space, gold (its tooltip lists the gold of your characters), durability (all your gear together, then in red how many items are at 50% or less), hearthstone (where it is bound and its cooldown), coordinates, frame rate and latency, friends online and guild online, and the LibDataBroker feeds of other addons when one of them ships that library. **Forget a character's gold** takes one off the list. Nothing in a panel casts or uses anything. Follows EnhanceQoL's data panels.
- **Bags and items**, **Item level in the equipment flyout**, on: the bag items that fit a slot of the Character window show their item level.
- **Bags and items**, **Item level on the Inspect window**, on: each slot of the player you inspect, and their average item level under their level. Flat UI never asks the game to inspect; it reads what the game's window asked for.
- **Bags and items**, **Item level corner on gear**: where the item level sits on the slots of the Character and Inspect windows.
- **Bags and items**, new section **Character window**, **Show durability**, on: the durability of all the gear you wear, under the left column of slots: white above 80%, yellow above 50%, red at 50% and below. These follow EnhanceQoL's character and inspect overlays.
- **Bags and items**, **Item level on equipped gear** shows on the Character window again: its slots were taken for bag slots, since every item button answers as a bag slot would.
- **Tracker, loot and alerts**, **Quest count**, on: your quests and the most the log holds, as 12/20, at the right of the **Quests** heading of the objective tracker, red while the log is full.
- **Bars, bags and micro menu**, new section **Levelling**, for Flat UI's own experience bar (**Experience bar** at **Flat UI's**). **Quests ready to hand in**, on: the experience of the finished quests in your log is drawn as a stretch over the bar, in **Quest colour**. **Levelling text**: **Time to level** (the default), **Experience per hour**, both, **Kills to level** or **None**, after the bar text. **Levelling in the tooltip**, on: the quests ready, this session, the experience per hour of your last 30 minutes of play, the time to level with and without the quests handed in, about how many kills and quests are left, and the time at this level when the game has said it. Time flagged away is not play, and the session goes on over a reload. `/flatui xp` says the numbers in chat and `/flatui xp reset` starts the session again. These follow EnhanceQoL's experience bar.
- **Options window**: the sidebar lists **Errands** with a pouch icon. `Panel.tga` has four more rows for icons.

## 0.5.4

- For WoW: Forever 1.60.1 build 70790, released 2026-11-04. The interface number stays 16001.
- **Quest item sparkle** is new on the **Flat UI** page, under **World**, and on by default: quest items in the world sparkle. It sets the game's `outlineModeShowLootEffectWhenDisabled`, which Forever's options do not show, at login and again a second after a graphics preset puts it back. Nothing is written in combat. Turned off, the game's own value is back from the next game start. `/flatui status` says whether the game kept it.
- **Combat text**: from build 70755 the game no longer tells addons the amount of a hit. The game now writes each number itself, so a full absorb or resist shows only its word, a full block shows **Block**, and a hit, heal or gain of nothing shows no number, as before. Numbers of a thousand or more have no thousands separator, because the game gives no grouped text for an amount it keeps hidden. A miss that comes as a hit of nothing with no kind shows nothing.
- `/flatui status` no longer counts hit amounts the game would not tell: it now withholds every one.
- **Combat text**, **Whose hits** at **One hit for each of yours**: a next melee ability (Maul, Heroic Strike, Cleave, Raptor Strike) no longer shows as 0. The game reports the swing it replaced as a hit of 0 that can no longer be told from the hit, and it can come first: both now take the ability's slot, the hit shows its number and the 0 shows nothing.
- **Swing timers**: new **Auto Shot window**, on by default. A band over the last half second of the ranged timer shows when moving or casting a spell would delay your next Auto Shot. Its width follows each shot, so it stays right with haste, and it sits at the end the bar fills to, also with **Fill from the right**. **Auto Shot window colour** sets its colour.
- **Combat text**, **Extra attacks**: a hit of another player right after your swing no longer shows as your **(Extra attack)** when you are not in a group. A physical hit that is not yours marks its enemy as hit by others, and the extra attack slot stays closed on that enemy for 10 seconds.
- **Colour health by health left** and **Low health border** work again. On build 70790 Flat UI's start-up test of the health colour failed on every character, so `/flatui status` said "Health curve: refused": colouring by health left did nothing on the unit frames, the personal resource display and nameplates, and nameplates had no low health border. The game now gives that colour only as a hidden value, and the test bar had no texture to take it.
- **Nameplates**, **Fading row behind the name**: with **Colour health bars by health left** also on, the row no longer disappears. The game hides a bar's colour once it is tinted by health left, so the row takes the unit's friendly, neutral or hostile colour while it cannot read it.
- **Nameplates**: on the 70790 client the square **Level box** is the height of the health bar again, not 5 taller. Turning it to **Default** or **Game width** no longer narrows the bar or pushes the crowd control icons out. A class icon set to **Right** now goes after the game's level box instead of over it.
- **Nameplates**: the preview shows the game's elite and rare icon, which the game's own **Rarity icon** nameplate option turns off.
- **Swing timers**: **Out of range opacity** and **Own text colour** now wait for a swing to finish, as the game does, and come back by themselves when a swing ends or your gear changes.
- **Unit frames**: **PvP flag** with **Icon on the portrait** or **Both** puts the faction icon on the chosen **Icon corner** of the picture again on the player, target and focus frames. It had stayed at the game's spot beside the picture since the 1.60.1 frames lost the round plate under it. `/flatui status` now says whether the icon is on the picture.
- **Unit frames**: with **Square portraits** on, the picture of the target and focus frames lines up with the health and power bars again, one border thickness from them and level with their top and bottom.
- **Minimap**: **Hide minimap ring and header** hides the plate behind the zone name again, along with its glow under the mouse. Since build 70425 the zone name sits on a new button whose plate stayed drawn.
- **Minimap**: **Minimap border** draws its thin border and background round the zone name again, and the tracking button's border now goes round the whole button instead of sitting inside it. The Flat UI setup preview keeps the tracking button's plate, which the game now draws its icon on.
- **Windows**: on the **Character** window the shading over the race picture no longer comes back over the flat background when you change tabs and return, and the dark box over the model in the Inspect window stays hidden when you switch to PvP and back. With **Show race background** on, the shading keeps the strength the game gives the race.
- **Windows**, **Character**: the rock strip across the top of the character page, behind your level, is now flat too.
- **Windows**, **Collections, stable, sockets and other windows**: the stable's header and footer bands, the border across the bottom and the two dividers are gone again. The coin box under it still has its game border.
- **Windows**, **Collections, stable, sockets and other windows**: the battleground scoreboard and match results no longer show a stone band behind their column headers.
- **Windows**, **Progress bars**: the box around the reputation, skill and pet experience bars fits the fill again. The game now draws the fill 6 units inside the bar, which left an empty strip at each end.
- **Movers**: with **Leave the game's action bars alone** off, a moved Totem bar now stays where you put it. Since build 70425 the game stacks the totem bar over the main bar at the start and end of every fight and whenever it shows or hides. Flat UI now puts it back at once without counting those moves, so it no longer lets the bar go after a run of pulls, and the **Reload** button keeps its spot in the Edit Mode layout so the game leaves it there in fights too.
- **Movers**: like the other bars the game stacks, a Totem bar hidden in a vehicle with no saved spot has no handle in `/flatui move`, and its handle says it is moved back by the game in combat until the **Reload** button keeps its spot.
- **Bar block**: with **Stance, pet and experience bars** on **Above the block**, a Shaman's totem bar gets a row of its own over the possess bar. The game no longer stacks it across the block's second row, and `/flatui block facts` lists it.
- **Bar block**: a Shaman's totem bar held over the block fades with **Fade the block**. The block stays at full opacity while the totem flyout is open, as it does for a spell flyout, and the arrow that opens the flyout counts as under the mouse for **Full opacity under the mouse**, so the bar no longer fades while you pick a totem.
- **Bags**: with **Item slots** on, a bag slot that held the empty-slot picture no longer shows the wrong part of an item icon when its quality colour changes. Item slots and **Bag bar buttons** are square again on build 70790, which gave every item button a rounded mask.
- **Action bars**: turning **Own sweep opacity** off gives the cooldown sweep the game's own opacity back (64 percent) instead of a fully black sweep.

## 0.5.3

- **Options window**: **Nameplates**, **Unit frames**, **Cast bars**, **Action bars** and **Swing timers** have a preview above their settings. Point at a part to outline it and fill its row, click it to open the row, or point at a row to bracket its part. A click on a frame in the **Unit frames** preview picks it in **Per frame**. New **Previews** setting: **On**, **Collapsed** or **Off**.

## 0.5.2

- **Options window**: each section is a card that folds and counts its changed settings. New **Sections** setting: **Cards** or **Lines**. Switches replace tick boxes and a few choices are segments. **What fades** is a set of chips, sliders mark their default, and long dropdowns have a search field.
- **Options window**: a changed setting has a dot and a reset button, a setting that is off says which setting it needs, tips show beside the control, and **Reset page** names how many settings it resets.
- **Options window**: search lists the best match first, shows **Pages** chips, finds the rows of **Profiles** and the steps of **Flat UI setup**, and takes Up, Down, Enter and Escape out of combat. Enter opens the tab and flashes the row.
- **Options window**: lists of bar textures, fonts and row directions show a sample beside each line. New **Samples in lists** setting: **On** or **Off**.
- **Options window**: rarely changed settings of a card are behind **More choices (N)** at the end of the card. Search opens them.
- **Options window**: a colour swatch opens a colour picker of Flat UI's own with a square, a hue bar, a hex field and the last ten colours applied. A change shows at once and **Cancel** puts the old colour back.
- **Options window**: **Profiles** has **Rename profile**, and its switch rules follow the new name. An export starts with the profile name, the Flat UI version and the screen size. A pasted profile shows what it holds and warns about another screen size. **Import as** makes a new profile or replaces the one in use, and **Export by module** limits a code to the modules chosen.
- In **Move frames**, a handle snaps to the edges and middle of other handles within 5 units and shows a guide. **Snap** on the toolbar turns it on and off, and the **Snap to other frames** setting does the same. Ctrl and click picks handles, and **Space across** or **Space down** evens the gaps between three or more.

## 0.5.1

- A new character sees **Welcome to Flat UI** at login, and /flatui welcome opens it. Five settings under **Setup** change its layout, size and what **Skip** keeps.
- **Switch automatically** on **Profiles** puts a profile in use for each character in a dungeon, a raid, a battleground or arena, and everywhere else. Each starts at **No change**.
- **Move frames** dims the screen and draws a grid. It has a toolbar (**Grid**, **Snap**, **Frame list**, **Undo**, **Done**), a list of frames and an inspector with **X**, **Y** and **Scale**. The options window returns on **Done**. New **Movers grid** setting: **Off**, **Dim** or **Bright**. Arrow keys move the chosen frame 1 unit, and Shift moves it 10. **Escape** asks about changes before it closes. A fight pauses the movers, and they open again after it.

## 0.5.0

- The **Flat UI** button in the game menu opens the **Options window**. **Flat UI button opens** still offers **Flat UI setup**. **Jon Default** sets **Custom UI scale** with **Scale below 65%** at a **Small scale** of 60%.

## 0.4.99

- **Options window**: the pages of a module are tabs under its title, with a breadcrumb of group, module and tab, and the sidebar lists modules only. **Unit frames** has one **Per frame** tab with a chooser for its eight frames. Tabs that do not fit go into **More**.

## 0.4.98

- **Bar texture** is new on **Trackers**, on the bar of **Your buffs** and on the tooltip health bar under **Chat and tooltips**. **Icon border** is new on **Trackers**, **Your buffs**, **Defensives on you**, **Party cooldowns** and **Enemy cooldowns**.
- **Bar border** is new on **Unit frames**. **Bar background** is new on the experience bar. **Class colour** is new on the health bar of the **Personal resource display**.
- Cast bars on the player, pet, target and focus are 80 to 400 wide and 6 to 40 high.
- **Faded opacity** on **Bar block** stops at 90, so a saved 100 now fades the block to 90%. **Aura opacity**, **Opacity in combat** and **Nameplate cast bar height** move in steps of 5.

## 0.4.97

- New **Icon size** and **Spacing** on **Defensives on you**. New **Hide while mounted** and **Hide in cities and inns** on **Cooldowns**. New **Countdown number size** on **Trackers**, **Party cooldowns** and **Enemy cooldowns**, and **Time left** on **Party cooldowns**. **Icon size** goes to 64 on every icon row.
- **Sound** on **Cooldowns**, **Trackers** and **Enemy cooldowns** offers the same sounds, **Spell alert** to **Whisper warning**. **Enemy cooldowns** has **Flash when ready** and **Sound** as two settings. Saved choices stay as they were.
- **Text outline**: new on **Personal resource display**, **Swing timers** and **Cast bars**. The first choice on every text outline row is now **As the game has it**.
- Text sizes of cast bars, swing timers, the resource display, window titles, the zone name, experience bar text, tooltips and the tracker heading go down to 50%. Stack counts go up to 250%.

## 0.4.96

- **Options window**: the sidebar has **Home**, **Flat UI setup**, **Profiles**, **Move frames** and six groups of modules with icons. The switch of a module is in the page header. **Home** shows the profile, the accent, recent changes with **Undo**, the modules and what needs a reload. New **Sidebar** setting.

## 0.4.95

- **Nameplates**: **Name outline**, **Health text outline** and **Spell name outline** now offer **None**, **Thin** and **Thick**. There is a new **Text font**. **Name colour** has **Class**, and **By reaction** is now **Reaction**. **Health text format** has **Current / max**. **Level box** can be **Hidden**. Health text now follows **Number style** of the unit frames. **Health text format** choices are now **Current**, **Current and percent** and **Missing**.
- **Unit frames**: new **Power text** on **Boss frames**. New **Long names** on **Pet frame**, **Party frames** and **Boss frames**, starting as **Cut with dots**. **Role icon on player and party frames** now covers the player. **Party pet picture** has **3D head**. **Out of range opacity** on **Party frames** runs 10 to 100 like **Raid frames**, and a saved dimming of 70 becomes 30. **As Square portraits** is now **As Portrait style**. With **Portrait style** at **3D head**, party pets on **As Portrait style** now show a 3D head. **White names** is now **Name colour** with the choice **White**, and it applies to name rows only. **Health text size**, **Power text size** and **Small frame text size** go from 50% to 200%.

## 0.4.94

- **Options window**: the window is 1040 by 680 and starts with no borders. Ctrl and the mouse wheel over the title bar change **Window scale**.
- **Flat UI** page: new section **Options window** with **Accent colour**, **Custom accent colour**, **Window tone**, **Borders**, **Corners**, **Density**, **Window font** and **Window scale**. Every profile uses the same values.

## 0.4.93

- **Cast bars** and **Swing timers**: the player cast bar and the swing timers now have the width of the personal resource display. Set **Bar width** of the display in Edit Mode to size all three. A saved **Player cast bar width** is not used while **Player cast bar** is **Width of the personal resource display**. Pick **Width set below** or **Width set in Edit Mode** to keep the old widths.

## 0.4.92

- **Minimap**: new **Addon buttons** for the round buttons other addons put on the map. By default they stand in a column beside the map. **Row under the map** and **Where each addon puts them** are the other choices.

## 0.4.91

- **Buffs and debuffs**: new **Duration format** and **Duration colour** under **Duration size**. By default the time shows 8m in white. Both also cover the totem times under the player frame. New **Totem time size** on **All frames: icons and auras**, which starts at 80%.

## 0.4.90

- **Button text**: new **Hotkey text**. Mouse buttons, the mouse wheel, the number pad, Page Up and Page Down show short by default, such as M4, WU, N1 and s-M4. The hotkey no longer ends in dots.

## 0.4.89

- **Target of target frame**: new **Long names**. A name wider than the row is now set in smaller text, down to 75%. A longer name is still cut with dots.
- **Swing timers**: **While not swinging** is now **Show the timer**, with **Always**, **In combat** and **Only while swinging**. It starts as **In combat**, so the empty bar and its 0.0 no longer show out of combat.

## 0.4.87

- **Unit frames**: new **Mana bar colour** on **All frames: bars and pictures**. A mana bar next to a health bar in a blue class colour is now sky blue. **Custom power colours** on the **Colours** page now colours the power bars of the unit frames.

## 0.4.86

- **Chat tabs**: new **Chat tab opacity**. The default is **Selected 100%, others 60%**. The game uses 40% and 20%.

## 0.4.85

- **Class icon shape**: Square or Round, on the **Class icons** section of the **Target and marks** page and on the **Portraits** section of the **Unit frames** page. A round icon has a round border of **Border thickness**. Faces stay square.

## 0.4.84

- **Game menu**: new **Flat UI** button, right below the gap under **Options**. It opens **Flat UI setup**, or the options window when **Flat UI button opens** is **Options window**. It does not work in combat. Untick **Flat UI button in the game menu** on the **Flat UI** page, **Game menu** section, to remove it.

## 0.4.83

- New ready-made profile **Jon Default** in **Flat UI setup**, with the author's own settings and frame positions.

## 0.4.82

- **Combat text**: Outgoing and Incoming numbers curve out to each side of your character by default (**Outgoing style**, **Incoming style** and **Arc width**). Your hits in the Outgoing area and the heals you cast on yourself show the icon of the spell, swing or shot (**Spell icons**). Misses show in parentheses, such as (Dodge) (**Miss words**). Maul, Heroic Strike, Cleave and Raptor Strike no longer show a Miss for the swing they replace. **Next melee ability names** can show their name. Hits of your spells and special attacks show in yellow, and swings, extra attacks and shots in white (**Colour by school of magic** and **Physical ability hits**). `/flatui combat trace` prints each hit report in chat.

## 0.4.81

- **Movement**: new choice **Burst**, now the default. A critical hit over an enemy starts at up to 2.2 times its size, settles in 0.2 seconds, then rises and falls. Other numbers rise and fall as before. With **Plainly** on **How a number appears**, a critical hit starts at its normal size and rises and falls.

## 0.4.80

- Nameplates: the level box is now a square the height of the health bar. The class icon now starts on the left at the same height. The raid marker moves out past the icon. New **Level box shape** and **Level box gap** on the **Level** section of the **Text** page. New **Class icon size** and **Class icon gap** on the **Class icons** section of the **Target and marks** page. **Class icon position** now starts as **Left**. A saved class icon size applies again after you pick **Custom** in **Class icon size**.

## 0.4.79

- **Combat text**: new Outgoing and Incoming scroll areas, with **Where your hits show**, **Outgoing style**, **Incoming style**, **Speed** and **Partial effects**. **Kind of hit in parentheses**, **Smaller glancing hits and words** and **Movement of your text** are gone: **Partial effects** and **Incoming style** replace them. Your own text now starts 170 units left of and 30 below the middle of the screen and moves sideways by default (**Incoming style** Horizontal).

## 0.4.78

- Character window: the side tabs now keep their **Side tab size** when the right pane closes or opens. Their icons no longer grow past the tab and lie over each other.

## 0.4.77

- Windows and the Flat UI options window now return to their default place and size when they close. Choose **Kept** on **Positions and sizes** in the **Windows** section of the **Movers** page to keep them.

## 0.4.76

- **Extra attacks**: a row under **In front of nameplates**. With **Extra attack**, the default, an extra swing such as Windfury shows over the enemy in orange with (Extra attack) after the number. **Off** leaves it out, as before. It shows with **One hit for each of yours**. It does not show with a pet out or in a group. It does not show while a bleed or debuff of yours is on the enemy or the game withholds the aura list. An extra swing shows no Glancing, Block, Resist or Absorb word.

## 0.4.75

- Your buffs: the game's tooltip now shows when the mouse is over a buff, in a fight too, and clicks still reach the world. New **Buff tooltips** on the **Icons** section of the **Your buffs** page, with **On** (default), **Out of combat only** and **Off**

## 0.4.74

- Player, target, focus, target of target, pet, party and boss frames: a power bar of a unit with no power is now hidden. New **Hide empty power bar** on the **Bars** section of the **All frames: bars and pictures** page, On by default
- Target of target frame: **Health bar colour** now starts as **Class**. The bar takes the class colour of a player and the reaction colour of a creature, like the target frame. Choose **Health colour** on the **Target of target frame** page for the flat colour.
- Player, target and focus frames: the PvP word now takes the colour of the name. New **PvP word colour** on the **Name row** section of the **Unit frames** page, with **Same as the name** (default), **White** and **Red**
- Target, focus, target of target and pet frames: the power bar now starts below the health bar with a space. New **Space between bars** on the **Bars** section of the **All frames: bars and pictures** page, 2 px by default and 0 px for none
- Player, target, focus and boss frames: the name now has the room the level and the PvP word leave. New **Name room** on the **Name row** section of the **Unit frames** page, with **Only what the texts need** (default) and **Fixed space**. A unit that is not flagged gives no room to the PvP word
- Target and focus frames: the PvP icon now moves with its plate to the corner set in **Icon corner**. It no longer stays over the world beside the picture
- Target, focus, target of target and pet frames: the power bar now has the width of the health bar. New **Power bar width** on the **Bars** section of the **All frames: bars and pictures** page, with **Same as the health bar** (default) and **Game's width**

## 0.4.73

- **Whose hits** has three choices: **One hit for each of yours**, **Every hit while you attack** and **Everyone's**. The default is **One hit for each of yours**.
- **One hit for each of yours** lets one hit through for each cast, swing, shot and harmful aura of yours. It leaves out:
  - The second and later hits of a spell that hits more than once
  - Ticks of an aura that come sooner than 2.4 seconds after the last one shown
  - Extra melee swings inside 0.8 of the weapon speed, such as Windfury
  - Hits from your own area spells on enemies you do not target
  - Critical aura ticks on enemies you do not target
  - Melee hits of your pet
- The game names no source for a hit, so a hit by another player can take the place of one of yours.
- **Numbers over enemies in a group**: a row under **In front of nameplates**. With **The game's own numbers**, the default, a party or raid shows the game's numbers over enemies, behind the nameplate. Flat UI draws none. **Flat UI numbers** draws them, filtered by **Whose hits**.
- **Size** sets the size of the game's numbers in a group when **Numbers over enemies in a group** is **The game's own numbers**. **Size of experience and other gains** does not apply there.
- When you join a group in combat and the game refuses the change, Flat UI numbers show until combat ends.
- `/flatui combat` names the slot behind a shown hit: cast slot, swing slot, shot slot or aura slot. A hit with no free slot reads "left out (slot taken)".

## 0.4.72

- **Your buffs**: a new page under **Personal resource display**. A row of icons at the personal resource display shows the short buffs you cast, such as seals and shields. Each icon has its time left. The row is on at the start
- **Row in a fight**: the game draws the row, so it works in a fight. When the game makes no icon row, the icons show out of combat only, and `/flatui buffs check` says so
- **Buffs shown**: **Short buffs of your class**, **Every buff you cast** or **Both**. **Time limit** hides buffs that last longer, 60 s at the start
- **Time left**: **Under the icon**, **On the icon**, **Thin bar under the icon** or **Off**. **Icon size** is 28
- **Place**: **Above the bars**, **Under the bars**, **Under the swing timer** or **Own position**, with a **Your buffs** handle in `/flatui move`
- **Buffs that have a tracker**: **Show here too** shows a seal in the row and in its tracker. **Leave out** hides it in the row
- **Trackers**, **Cooldown icons** and **Defensives on you** hang from the row when its place is **Above the bars** or **Under the bars**
- `/flatui buffs check` says how the row is drawn. `/flatui test` shows three sample icons in the row, or says the row is off

## 0.4.71

- Setup: the **Finished** screen is a report that scrolls. It says how many settings you chose and how many came from the profile you started from. It also counts the game settings that setup wrote, and names each one the game kept at another value
- Setup: **Review** and the **Finished** screen list every setting that needs a reload. They list **Action buttons**, **Leave the game's action bars alone** and **One size and spacing for every bar** when you change them. They list switches that take full effect after a reload when you turn them off
- **Setup result in chat**: a new setting in the **Setup** section of the **Flat UI** page and at the foot of **New profile**. **One line** tells you in chat which profile is in use, with the counts, when setup finishes. **None** says nothing. The default is **One line**
- `/flatui status` has a **Setup** line with the profile that setup made, the profile it started from and the counts. It also has a line for each game setting that the game still keeps at another value

## 0.4.70

- **Size of experience and other gains**: a new choice on the **Combat text** page under **Your character**. It sets the size of text the game draws near you, such as experience, while Flat UI draws the numbers over enemies. The default is **Same as your text**
- Before, that text took **Size**, the size of the numbers over enemies, which is 140% by default
- **Smaller than your text** is three quarters of **Size of your text**. **The game's own size** is 100%. **Same as numbers over enemies** follows **Size**, as before
- The choice also sets the size of the game's healing numbers over your target when **Healing over friendly units** is **Healing you do**
- The row shows when **Numbers over enemies** is **In front of nameplates**. With **As the game has them**, **Size** sets the size, as before
- `/flatui combat` names the choice in use under the `WorldTextScale_v2` line

## 0.4.69

- **Tooltips in combat**: the ready-made profiles **Minimal**, **Damage**, **Tank** and **Healer** no longer set it to **Hide unit tooltips**. A profile you made from one of them keeps its value. Change it on the **Tooltips** page under **Combat**
- **Hide unit tooltips**: after you point at a unit in combat, other tooltips now show, such as the experience bar tooltip. Tooltips of the game world stay hidden
- `/flatui status` has a **Tooltips in combat** line with the choice in use
- **Action buttons** at **Flat UI's**: when the game withholds the place of the game's tooltip box, the button's tooltip now shows to the right of the button
- **Fade out** at **Fast**: when you point at something else while a tooltip fades, such as the experience bar right after a unit, the new tooltip stays up
- **Place the tooltip** with **Every tooltip**: when the game withholds the tooltip's scale or the cursor, a tooltip beside its owner now stays where the game puts it

## 0.4.68

- Player frame: the power bar no longer overlaps the bottom of the health bar. The gap between them is 1 unit, or wider where the borders need it. When the game lays the frame out again in combat, the bar moves back under the health bar after combat ends
- Target frame: a right-click on the target frame opens its menu at the cursor, as on the player and focus frames, instead of beside the frame. In combat the menu opens where the game puts it
- `/flatui status` has a **Player bars** line with the gap between the player's health and power bars

## 0.4.67

- **Nameplates**, **Cast bar**: **Cast bar texture** now sets the texture of nameplate cast bars. **Same as the Flat UI page** keeps the texture of the **Flat UI** page

## 0.4.66

- Windows: with **Every window together**, windows now take the shared size on the next frame after the game resizes or opens them, instead of within half a second
- Windows: Legacy and other panels the game shrinks to fit the screen keep following the game's fit, so the shared size stays a percentage of the fit when the UI scale or screen changes

## 0.4.65

- When a window moved the group finder eye, or the minimap changed size, the eye now goes back to the spot you set in the same moment instead of up to half a second later
- The queue eye (group finder eye) now returns to its saved spot when a queue appears, even if the game moved it while it was hidden, for example after leaving a vehicle or override bar
- With **Show the eye** off in the **Looking For Group** window, the eye is now fully invisible, including its animations, and no longer reacts to the mouse

## 0.4.64

- Square portraits: the game's round mask is taken off the game's own portrait while the square picture shows, and again if the game puts it back, so a portrait that shows through stays square

## 0.4.63

- `/flatui combat` now uses plain words: "Your hits ... Casts and swings seen ... Last hit", "Nameplates the game hides from interface mods", "Hit amounts the game would not tell", "Nameplate layer", "Font size made at", "Game world height" and the like. The facts each line reports are unchanged

## 0.4.62

- Fixed: the **Uninterruptible** cast bar in the setup drawing now shows the game's own fill art instead of grey


## 0.4.61

- **Experience bar**: new first row of **Experience and reputation bars**, **Flat UI's** by default. Flat UI draws its own bar, any width from 10% to 130% of the game's full width (35% by default) and 2 to 24 px high (8 by default). The game's bar stays in place and is not drawn. **The game's** gives it back
- **Width**, **Height**, **Bars shown**, **Top bar**, **Space between bars**, **Dividers**, **Experience colour**, **Rested experience**, **Rested colour**, **Reputation fill**, **Reputation colour**, **Bar text shows**, **Bar text place** and **Tooltip** are new rows for the bar. **Bar text** has a **Hidden** choice
- The bar shows experience, with a stretch for how far rested experience reaches, and the faction you watch, coloured by standing (renown and paragon in blue). Both hide at the maximum level or with nothing watched
- **Bar border**, **Bar text**, **Bar text size** and **Bar texture** apply to both bars. **Flat fill** and **Hide bar dividers** are for the game's bar
- The bar has a handle in Movers named **Experience bar** and starts centred over action bar 1. The game's two handles are named **Game's experience bar** and **Game's second status bar**
- With **Group action bars into a block** on and **Stance, pet and experience bars** above, the bar sits in the block's experience rows
- **Leave the game's action bars alone** leaves the game's experience bar alone only while **Experience bar** is **The game's**
- The **Experience bar, bags and micro menu** step of setup has the new rows and a drawing of the bar
- **Rested colour** and **Reputation colour** are now greyed correctly when the choice they depend on is off
- `/flatui status` says when the bar is Flat UI's and how often the game put its alpha or mouse back
- A switch to the game's bar and back inside one fight no longer leaves the bar stuck until a reload. Status wording is clearer, with a singular form

## 0.4.60

- The micro menu and the bag bar keep the Flat UI look (thin dark borders, flat fills, the game's frame art hidden) while **Leave the game's action bars alone** is on, including the frame of an open bag. **Micro menu buttons** and **Bag bar buttons** apply again
- The portrait button of the micro menu loses its shadow, and the help button is styled with the others
- Changing **Leave the game's action bars alone** no longer leaves the dividers of the bag bar invisible until a reload

## 0.4.59

- The game's page arrows beside the main bar no longer stay clickable (invisible) when Flat UI's own action buttons are on
- A pet battle now hides Flat UI's action bars and shows them again afterwards
- If Flat UI's action buttons fail to build, `/flatui status` names the part that failed, and the game's bars are put back
- A failed build takes Flat UI's bars down and clears their key bindings and drivers, so only the game's bars are left
- The build is also checked through the key routing of bar 8
- Keys routed to Flat UI's buttons (flyout slots) are now cleared properly when the slot changes
- Switching back to the game's buttons restores the game's bars through Flat UI's secure header
- Flat UI's hooks on the game's range and cooldown code are no longer installed in a session that uses its own buttons, including when the build waits for the end of combat. After a failed build the game's buttons get their range and cooldown hooks again

## 0.4.58

- **Action buttons**: new first row on the **Action bars** page, **Flat UI's** by default. Mouse clicks on action bars 1 to 8 go to Flat UI's own buttons, laid out where Edit Mode puts the game's bars and wearing the same look. Key presses still go through the game's buttons. A reload applies it
- With **Flat UI's** buttons the game's eight action bars stay in place and are not drawn. **The game's** gives the buttons back as before
- **Hide bar frame**, **Hide end caps** and **Hide dividers** apply with **The game's** buttons. **Rotation helper highlight**, **Cast fill animation** and **Interrupt flash** show on the game's buttons only
- Edit Mode still places bars 1 to 8. The totem and extra action buttons are still the game's
- **Leave the game's action bars alone** covers the micro menu, bag bar, stance, pet and experience bars. Bars 1 to 8 follow **Action buttons**
- `/flatui status` shows the state of **Action buttons**, the main bar page, the keys sent to Flat UI's buttons and the parked bars
- The **Action buttons** step of setup has the new row

## 0.4.57

- **Leave the game's action bars alone**: new row on the **Flat UI** page, on by default. Flat UI does not move, group or fade the game's action bars, and does not move or restyle the status bars, micro menu, bag bar or leave vehicle button. The action buttons keep their Flat UI look. A reload applies it
- **Group action bars into a block**, **Bar blocks**, the action bar, micro menu and bag bar rows of **Fade frames when idle**, **Micro menu buttons** and the experience bar rows of **Bars, bags and micro menu** do nothing while it is on. Each row says so. Saved bar spots stay in the profile
- The game's **Options** page has one **Flat UI** entry with an **Open Flat UI** button. Every setting is in Flat UI's own window
- Range, cooldown and proc glow hooks on the action buttons are made only while **Restyle action bars** is on or **Leave the game's action bars alone** is off
- `/flatui status` shows a **Click path** line when Flat UI changed a game bar or put settings in the game's registry

## 0.4.56

- **Use on New profile** is dimmed while you are in combat, and clicking it in combat no longer leaves an **Unfinished setup** behind
- On **Review**, **Every step** now sits next to **Finish** with no empty gap
- The cards on **New profile** keep their grey edge when **Minimal** or another borderless look is selected
- A profile name you typed, such as "Tank 7" or "Healer", is no longer replaced when you click a profile card
- A font or bar texture in a ready-made profile is no longer dropped because the lists were not complete at login
- Setup window: the profile name filled by a tile follows the next tile even after the setup window is reopened or the game reloads. The **Keep Default** button of the profiles panel no longer takes over the **Skip this area** button of the setup window

## 0.4.55

- **Setup window**: **New profile** shows the six ready-made profiles as cards, with the recommended one selected. Click a card to start from it, or press **Use Healer** (the button names the selected card) to make the profile at once
- **Every step** walks the steps from the card. **Review** lists what the card sets, each line with **Undo**
- **Start from** lists only your saved profiles
- The finished screen and **Review** show a picture of the profile you made

## 0.4.54

- **Profile on a new character**: new row in the **Setup** section of the **Flat UI** page, in place of **Offer setup on a new character**. Choices: **Show profiles** (the panel, as before), **Default profile**, **Recommended profile**, the six ready-made profiles, or any profile you saved. A character with no profile of its own gets the chosen profile at login, with no window and one line in chat. An older setting of off becomes **Default profile**
- **Same profile on new characters**: a switch on the profiles panel. It sets **Profile on a new character** from the next tile or **Same as** click
- **Recommended profile** picks by the character's class, the UI scale, the experience preset and the screen. Role and tank aura are mostly not known yet at login

## 0.4.53

- **Ready-made profiles**: a new character gets a panel with six pictures to click: **Standard**, **Minimal**, **Damage**, **Tank**, **Healer** and **Large**. One click puts the profile in use
- The panel marks the profile that suits the character: a tank or healer role, large game text or scale, the Classic experience, a small screen, or a class that only deals damage. **Same as** and the name of a profile uses the profile most of your characters use
- `/flatui profiles` opens the panel again at any time, and the **Profiles** page has a **Ready-made profiles** button
- No ready-made profile changes the UI scale, a game setting or a frame scale

## 0.4.52

- **Custom UI scale**: the scale now goes through the game's own UI scale setting, so action buttons stay clickable. Turning **Custom UI scale** off puts back the scale the game had before, also after a `/reload` or a profile switch. A change to the scale says "/reload to finish." in the status. **Custom scale** runs from 65% to 115%. New rows **Scale below 65%** and **Small scale** (35 to 64%) call the older route under the game's slider and say that the game can refuse presses at those sizes. A scale under 65% in an imported profile moves to **Small scale**

## 0.4.51

- **Taint scan**: when the game refuses a protected call from Flat UI (for example `UseAction()` on a click), or on `/flatui taint`, the scan now covers every global the refused click reads, `Settings.GetValue`, `C_ActionBar.IsAutoCastPetAction` and every key of the button under the cursor. An empty result says "No tainted value found." Each scan carries its date and time and runs on the next frame. `/flatui status` lists the last results under **Blocked by the game:**
- Nothing else changes on screen

## 0.4.50

- **Combat text**: Size over enemies, friendly units and your own text now goes up to 400%. New **Spread width** setting (50 to 300%, with **Spread** on **Loose**) widens where numbers start. New **Overlapping numbers** setting: **Keep apart** starts a number in a free lane, or higher up, so numbers stop covering each other; **Stay in turn** keeps the old placement. New **Rows** setting (1 to 6) limits how many rows a number may start up. Above 160% the numbers rise, fall and spread in proportion to their size. Critical hits swell at most to 128 units. With the game's own numbers, **Size** and **Spread width** go to the game's variables
- **Combat text**: new **Style** row: **Flat UI** or **Classic**. Classic is the game's old floating text. Numbers climb straight up at a steady speed and last 1.9 seconds. They stack in a column and go to the side past **Rows**. A critical hit pops, then stays in place. A new Classic section has 7 rows: **Colours** (**White and yellow**, or **Red and purple**), **Plus and minus signs over enemies**, **Smaller glancing hits and words**, **Rise distance**, **Time on screen**, **Stacking** (**Older numbers move up**, or **New numbers start lower**) and **Critical hits stay in place**. **How a number appears** and **Movement** apply to **Flat UI** only. The setup picture of combat text shows the Classic look. Numbers over friendly units take the style too
- **Combat text**: new **Whose hits** row, **Yours and your pet's** (the default) or **Everyone's**. Other players' damage no longer shows as combat text unless you choose **Everyone's**. Hits before your first cast or swing are left out. If 10 hits are reported in combat and none of your casts or swings has been heard, the game's own numbers come back. Where the game offers no cast event, the game's own numbers show

## 0.4.49

- Action bars moved with Flat UI are placed through the game's secure frame calls
- **Reload** uses the game's own /reload on Forever
- The proc glow hangs beside the button instead of on it
- Nothing changes on screen

## 0.4.48

- **Flat UI layout**: when Edit Mode does not keep the Flat UI layout, that is remembered for the character and the Reload line does not come back. It is tried again only after you switch to the Flat UI layout in Edit Mode or change **Bars on a preset layout**. The line says "the Edit Mode layout named Flat UI" when that layout already exists. Changing the setting offers the layout again without a reload
- **Movers** page: new row **Edit Mode layout as text**. Choose **Show as import text** to open a window with the Flat UI layout as Edit Mode import text. Copy it, open Edit Mode, choose Import in the layout list, paste it and name it Flat UI. It says so in one line when the game cannot make the text, in a fight, or while Edit Mode is open
- **Bar block button size**: turning it off now always puts the earlier values back at the next Reload, in any later session. The check that Edit Mode applied the button size runs only after the game has loaded the layout, and only when the layout in use holds the values; presets and layouts without them no longer give a false line. A failed check also takes the values out of the layout. Status line wording: "did not keep them."
- **Bar background panels** now follow their bar: they hide with the pet and stance bars when the game hides them, and they fade with a bar that **Fade** has faded. Faint empty buttons no longer have a darker backdrop than filled ones. The totem element ring and the extra action button art are flat with the rest. `/flatui status` says when a panel could not be made or when the game does not say which buttons are empty
- **Button text**: with **Restyle action bars** off, or a bar group off, that bar's hotkeys, macro names and counts go back to the game's text, size, colour and position. A profile change or reset applies the **Button text** values and the hotkey position at once. A pet bar no longer causes repeated passes over every action button, and its hotkeys keep your colour while range changes. The range note in `/flatui status` shows only while **Own hotkey colour** is on. The hotkey offsets show their unit, px
- **Grey out icon on cooldown** now takes the grey off when the game withholds the cooldown in a fight. Colours and cooldowns do no work when **Restyle action bars** is off
- **Rotation helper highlight** off now also hides the highlight on the next suggested spell. **Coloured border** no longer draws on the game's rotation glow. The error line is clearer and clears itself
- **Bar block**: **Group action bars into a block** turned off or on again refreshes the block as before, and then the button size and spacing
- **Setup**: 55 steps

## 0.4.47

- **Sound when it drops** on buff and debuff trackers now uses the game's own sound for the aura ending, so the sound plays in a fight where the buff is hidden. Where the game refuses it, the tracker keeps its own sound for drops it can read, and `/flatui tracker check` says so. `/flatui tracker check` lists **Game's sound for a buff ending**
- Trackers set to **Only when low or missing**: in a fight they no longer reappear while mounted, resting in a city or inn, or dead. Trackers with **Low at (seconds left)** stay shown as before
- Proc art on the game's own icon: a proc ending in a fight no longer leaves its pieces behind. The art line says off when **Art beside the character** is off, and not made when the art was never built

## 0.4.46

- **3D head**: the head now draws below the leader, PvP and raid target icons, level text and ready check
- A unit out of view or an offline party member shows the picture
- The head no longer reloads on every portrait update
- Tint changes reach the head at once, and a later fade of the frame fades it
- The **3D head framing** row is no longer greyed when only a frame's own **Picture** row is set to **3D head**
- **Enemy cooldowns**: in an arena, the target and focus bars show one more icon, the crowd control break of that opponent, with its sweep
- New setting **Crowd control break in arenas** (on by default) on the **Enemy cooldowns** page, also in the setup wizard
- **/flatui check** says whether you are in an arena and whether the crowd control break is shown

## 0.4.45

- **Tooltips page**: new **Fade out** choice (As the game has it, Fast, At once). Fast is the default and takes about 0.2 seconds from full to hidden. It works with the **Tooltip** page off and at any tooltip position. It is also in the setup wizard's **Tooltips** step

## 0.4.44

- **Fixed**: the **Experience bar** and the second status bar no longer fall back to their stacked spot at fights and status bar changes. After the game's bottom bar pass they are put back on the next frame (out of combat), and these returns no longer count toward giving the bar up
- Preset layouts: **/flatui status** says the game puts the Experience bar back in fights, and to copy the layout in Edit Mode to keep it
- Stance, pet, possess and Leave vehicle bars get the same return

## 0.4.43

- **Setup**: all 52 steps are in, each with its drawing. The steps are grouped by area: Look, Nameplates, Action bars, Unit frames, Cast bars and timers, Minimap and buffs, Windows, Chat and tooltips, Trackers, Cooldowns, Party and enemy cooldowns, Combat text, Bar blocks, Fading and Positions
- Every setting of the options window is in exactly one step, and each drawing changes as you pick. Unit health and power in the drawings use sample numbers, since the game withholds a unit's own
- **Choices in each step** (**Main choices** or **Every choice**) on the **Flat UI** page decides how many rows each step lists
- Nothing reaches a profile, a game setting or a list before **Finish**, as in the earlier builds

## 0.4.42

- **Fonts**: the tracker text size is followed after a specialization change
- **Experience and reputation bars**: text you set stays after a subzone change
- **Weapon enchants**: the border follows the right button after an enchant is applied or removed
- **Proc glow**: the glow on an action button follows the game's own spell alert with taintLog on, and answers it on the next frame
- **Swing timer**: **Out of range opacity** and **Own text colour** follow combat start and end and attack speed changes, so they no longer fall back to the game's look until the next swing
- **Alternate power bar and class frame container**: followed only after the display's setup has run
- **Chat**: **Input box opacity when idle** works with **Chat input box** off. A tooltip held back in combat is hidden as the game shows it. Clicking away from a half-typed message leaves the box as it was. The border colour follows the chat type for a box that was already focused
- **Side tabs**: follow the checked state when you switch tabs on the character, bank, collections, inspect and professions windows
- **Bags**: slots are redressed (item levels, dimming) after items are moved, looted or sold with a bag open
- **Pet frame**: size is restored after a specialization change
- **Target and focus frames**: styling is restored after a specialization change. In Edit Mode, **Use larger frame** and **Buffs on top** for the focus frame are restyled when the editor closes
- **Player frame**: the PvP timer word is redrawn only when the timer text changes

## 0.4.41

- **Nameplates**: **Extra clickable width** and **Extra clickable height** no longer change the size of the plates or their bars, they only change where a click lands
- **Click through friendly nameplates** also covers friendly plates that show only a name
- **Taint log**: while the game's taintLog setting is on, the nameplate click area, tooltip placing and experience bar fill still work
- **Experience bar**: the flat fill is put back after a long gain animation as well

## 0.4.40

- **Setup**: a new way to make a profile, first part. `/flatui setup`, or **Set up a new profile** on **Profiles** (**Continue setup** while this character has choices kept), opens a setup mode of the Flat UI window. Each step has a drawing that changes as you pick
- Two steps are in this build: **Borders and backgrounds** and **Bar texture and colours**. The drawings use sample numbers, since the game withholds a unit's health and power. The other steps are not in yet
- Nothing reaches a profile, a game setting or a list before **Finish**. **Close** asks **Keep choices** or **Discard choices**. **Review** lists the changes, each with **Undo**
- **Finish** makes the profile and starts it. Finish is refused in combat and says **In combat. Finish after combat.**
- After **Finish**, the screen lists the switches whose turning off needs a reload, one line each ("Turning off ... takes full effect after /reload."), and the **Reload** button shows a tip, **Reloads the interface.**
- A character with no profile of its own is offered setup once, a second after login. A new section, **Setup**, on the **Flat UI** page has **Offer setup on a new character** (on) and **Choices in each step** (**Main choices** or **Every choice**)
- Setup hooks no game frame

## 0.4.39

- **Combat text**: numbers over friendly units. A new **Friendly units** section on the page has **Where friendly numbers show** (**Off**, **Party and raid frames**, **Friendly nameplates** or **Both**, **Both** by default), **Friendly units**, **Damage friendly units take**, **Healing over friendly units**, **Your pet**, **Misses and dodges over friendly units**, **Plus and minus signs**, **Friendly damage colour**, **Friendly healing colour**, **Size over friendly units** and **Height above frames**
- Numbers over party, raid and pet frames draw above the frame without changing the layering of the numbers over enemies
- **Healing over friendly units** shows the healing a unit takes from anyone. The game's own healing row is set to 0 only while Flat UI draws friendly numbers, and `/flatui combat` explains it only then
- `/flatui combat` counts the friendly nameplates the game keeps from interface mods once per unit and skips enemies, as **Forbidden plates**
- The page's sections **Position and size** and **Spread and movement** no longer say "over enemies". **Height above the enemy** also sets the height over friendly nameplates

## 0.4.38

- **Movers**: a moved action bar is kept in your own Edit Mode layout. After you move a bar a line with a **Reload** button appears. Pressing it saves the layout and reloads the interface in the same click. Until then Flat UI places the bar out of combat and the game puts it back at the start of a fight
- On a preset layout nothing is saved. Copy the layout in Edit Mode to keep moved bars
- **Reset** on a bar, **Reset all** and turning off **Move the game's own frames** put the layout rows back the same way, after a reload
- Flat UI hooks no bar or button, places nothing in combat and saves nothing outside the **Reload** click
- Removing Flat UI without **Reset all** and a reload leaves the saved spots in your layout
- **Action bars**: the button art is restyled after a talent change as well
- **Taint log**: while the game's taintLog setting is on, Flat UI no longer follows game frames, so the errors that showed up with it on (experience bar, tooltips, nameplate click area) no longer appear
- A small box, **Taint log**, appears once per session when taintLog is on. **Turn off and reload** sets it back to 0 and reloads. **Ignore** hides it until the next reload. It hides when a fight starts and returns when it ends
- `/flatui status` shows when taintLog is on and how many game frames are left unfollowed, and whether a call the game refused was "forbidden" or "blocked", for example UseAction (forbidden)
- Turning taintLog on during play prints one line telling you to turn it off and reload
- With taintLog off, nothing changes

## 0.4.37

- **Trackers**, **Proc alerts**: procs now work where the game hides the buff in a fight. Three triggers: your cast of the proc's spell (Fel Domination, Amplify Curse), a cast time that has become instant or much shorter (Shadow Trance, Decimation), and an ability that has become usable (Mongoose Bite, Counterattack, Overpower, Revenge, Riposte)
- **Add a proc** shows the trigger after the proc's name. `/flatui tracker proc trigger` changes it and `/flatui tracker check` names it. A proc whose spell is instant at rest is refused
- **Unit frames**, **All frames: text**: **Name font**, **Name size**, **Name outline**, **Name colour** (**As the game has it**, **Class**, **Reaction**, **Custom**) with a custom colour, **Bar text font**, **Bar text outline** and an own **Bar text colour**. A **Name** switch on the **Player**, **Target**, **Focus**, **Pet**, **Target of target**, **Party** and **Boss** frame pages. Every row at its default leaves the game as it is
- **Unit frames**: **Health text** and **Power text** on each frame's page show the health or power of that bar as **Current**, **Current / max**, **Percent**, **Current and percent** or **Missing**, or hide the game's text. **All frames: text** has **Number style** (12.3k or 12,345), **Show** (always or under the mouse) and the position of each text. A row left on **As the game has it** changes nothing
- **Unit frames**: switches for the leader icon, the role icon on party frames, the PvP icon, the raid marker on target, focus and boss frames, the dead text, the combat icon and the pet's happiness face
- **Power bar** switch on the player, target, focus, pet, target of target, party and boss frame pages
- **Party frames**: **Dim members out of range**, with **Out of range dimming**
- New **Raid frames** page: **Out of range opacity**, **Role icon**, **Name** and **Status text**
- **Incoming heals**, **Absorb shields** and **Heal absorbs** on **All frames: bars and pictures**
- **Totem time left** and **Totem cooldown swipe** on **All frames: icons and auras**
- **Fonts**: **Replace the game's fonts**, **Interface font**, **Number font**, **Title font**, **Text outline**, **Text shadow**, **Text size** and **Smallest text**. Off until switched on. Other addons that use the game's fonts change too, and off puts every font back. **Game text size** is on the same page
- **Tooltips**: their own border colour, a border by unit (plain, reaction or class colour), class colour on player names, size, title size and text size, a hidden or thinner health bar, hiding in combat with a key to show anyway, item and spell IDs, and item counts in bags and bank
- **Chat**: a border, an input box above or below the window, a lower idle opacity and a choice of border while typing. A **Chat text** page sets the chat font, outline and shadow, lines kept per window, and whether and when old messages fade
- **Minimap**: **Minimap shape** (round or square, with no ring or pointer under **Square**), **Zoom out after**, **Day and night icon**, **Zone name** and **Zone name size**, and switches for the **Tracking**, **Mail**, **Calendar**, **Clock** and **Addon list** buttons
- **Buffs and debuffs**: **Icon crop**, a colour for each debuff type, **Border colour by debuff type**, **Duration size** and **Stack count size**
- **Bars**: **Bar text**, **Bar text size** and **Bar texture** for experience and reputation bars
- **Tracker and loot**: **Tracker bar texture**, **Tracker background**, **Heading size**, **Opacity in combat** and **Quality word on loot**
- **Cooldowns**: **Icon crop** (0 to 15 percent), **Icon border**, and **Equipped trinkets**, which adds your two trinket slots after the picked spells with their own sweep. Where the game withholds trinket cooldowns, the trinket icon shows no sweep and `/flatui status` says so
- **Cooldowns**, **States and text** (new page):
  - **On cooldown**: **Grey out on cooldown**, **Darkness on cooldown**
  - **Opacity**: **Opacity on cooldown**, **Opacity when ready** (0 hides ready icons and keeps their place), **Row opacity out of combat**
  - **Border**: **Border colour by state** with a ready and an on cooldown colour, **Flash when ready**
  - **Numbers and sweep**: **Countdown number size**, **Cooldown sweep**, **Sweep opacity**, **Charge count size**
  - **Keybind**: **Keybind on icons** shows the key bound to the spell on your action bars, with **Keybind size**
- **Colours**: **Colour at full health**, **Colour at half health** and **Colour at low health**, under **Health left**
- **Unit frames**, **Nameplates** and **Personal resource display**: **Colour health bars by health left**, in the three colours of the **Colours** page. Not raid frames
- **Nameplates**: **Low health border**, with **Low health below** and **Low health border colour**
- **Nameplates** and **Cast bars**: **Cast time** on nameplates, and **Cast time on target and focus bars**, in seconds at the right end of the bar
- Each of these switches itself off if the client refuses it. `/flatui status` says whether the health curve and the cast time work

## 0.4.36

- **Trackers**: new page **Tracker** under **Trackers**. Choose a tracker, change its name and its rows (**On**, **Spell IDs**, **Shape**, **Place**, **Show**, **Low at**, **When missing**, **Sound when it drops**, **Colour**, **Icon size**, **X offset**, **Y offset**, **Mark action buttons**). A row shows the page's value until the tracker has its own, and the first change gives it one
- **Clear own settings**, **Move up**, **Move down** and **Remove** act on the chosen tracker. **Remove** asks first
- Opened in a fight, the page says to open it after the fight
- **Trackers**: new row **Add a debuff on the target**, and `/flatui tracker add debuff Corruption`. A debuff tracker shows your own debuff on your current target with its stacks and time left, goes red when it is not on the target, and is hidden when there is no target you can attack. In fights the game's own icon, bar or text draws it where the game hides it
- **Trackers**, **Action buttons**: new switch **Mark action buttons** (off by default). When it is on, the action button that casts the missing buff or uses the missing item gets a red border until the tracker is fine again. It needs **Restyle action bars** and only marks a button the game has the spell or item on. Buffs are marked out of a fight. `/flatui tracker check` shows a Marks line for each tracker, and `/flatui status` counts the marked buttons
- **Trackers**, **Proc alerts**: **Add a proc** lists the procs of your class that you know a spell for, and **Remove a proc** takes one off. A proc shows nothing until its buff is up, then its icon with a coloured border, the time left and one sound. It ends when the buff ends, when you cast the spell it is for, or when its time is up
- Procs sit after the other trackers in the row, so an empty place never moves the others
- In a fight where the game hides the buff, the game's own icon for the buff shows the proc. Where the game gives no icon, nothing shows
- **Colour** (ffd100) is the border of a proc. **Sound** (**Spell alert**) is **None**, **Spell alert**, **Chimes**, **Bell**, **Warhorn**, **Raid warning**, **Alarm** or **Whisper warning**
- `/flatui tracker add proc Shadow Trance for Shadow Bolt` adds any other proc: its buff, then the spell it is for. `/flatui tracker proc colour 1 ffd100`, `/flatui tracker proc time 1 10` (0 to 120 seconds, 0 for the buff's own time) and `/flatui tracker proc trigger 1 overlay` set one proc
- The game's overlay events and glow are a second way to know a proc is up where the buff is hidden. A proc on the **overlay** trigger uses them and needs a time. The game is not expected to send any on this client
- `/flatui tracker test` shows each proc's icon and plays its sound for 5 seconds. `/flatui tracker check` says for each proc how hidden the game keeps its buff, whether it is up, the overlay signals seen, the personal resource display and the sound
- **Trackers**, **Proc alerts**: art beside the character while a proc is up. The large side pieces (and top, outside and corner pieces where the game's table gives them) fade in, pulse slowly and fade out, in the proc's colour. New rows **Art beside the character** (on), **Art size** (100%), **Art opacity** (65%) and **Art height** (0). A proc with no art of its own gets a plain arc
- **Trackers**, **Proc alerts**: new row **Glow on the action button** (on by default). While a proc is up, the action button that casts the spell the proc is for gets the proc's border colour and the game's glow animation. A button the game already glows is left alone. Where the game hides the buff in a fight, the glow follows only the other triggers. It needs **Restyle action bars** for the border. `/flatui tracker check` prints a Glow line for a proc
- **Profiles**, **Share**: new rows **Export trackers** and **Import trackers**. `/flatui tracker export` prints text for all trackers, or one by number (`/flatui tracker export 2`). `/flatui tracker import <text>` adds the trackers in the text after the ones you have and never replaces them. The text starts with `FlatUIT1:`. A profile text is refused by tracker import and a tracker text by profile import. Import stops at 40 trackers and says so, and is refused in combat
- **Enemy cooldowns**: **Show** is **Only while on cooldown** or **Always, ready ones bright**. In **Always, ready ones bright** the abilities of the enemy's class and race whose use can be seen are bright, and used ones are dark with the sweep
- **When it is ready again**: **Nothing**, **Flash** or **Flash and sound**. The sound plays for your target and focus only, at most once a second
- **Ready sound**: **Spell alert**, **Chimes**, **Bell**, **Warhorn** or **Raid warning**
- **Add an ability** and **Hide an ability** on the **Enemy cooldowns** page change which abilities the icons show. An added ability shows whatever its kind, and a hidden one stays hidden with its switch on
- `/flatui enemy add` (an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds), `/flatui enemy hide`, `/flatui enemy list` and `/flatui enemy clear`
- **Nameplates**, **Colours and threat** (new page): **Reaction colours on health bars** (hostile, neutral, friendly and tapped, in the colours of the **Colours** page) with **Players**: **As the game has it** keeps class colours, or **By reaction**
- **Colour the target's health bar**, with **Target health bar colour**
- **Threat colours**: **Your role** (**From your group role**, **Tank**, **Damage or healer**), **Threat you want**, **Threat changing hands**, **Threat you do not want**
- **Mouseover border** with **Mouseover colour**. The target and focus borders come first
- **Nameplates**, **Target and marks**: **Border colour for Elite and Rare** with **Elite colour**, **Rare colour** and **Boss colour** for the border of Elite, Rare and Boss units
- **Nameplates**, **Text**: **Show name**, **Name colour** (**As the game has it**, **White**, **By reaction**, **Custom**) and **Custom name colour**. **Health text colour**, **Show health text** (**Always** or **Only on the target**) and **Health text format** (**As the game has it**, **Percent**, **Health**, **Health and percent**, **Health missing**)
- **Nameplates**, **Cast bar**: **Spell name size**, **Spell name outline**, **Spell name colour**, **Spell icon size**, **Spark** and **Shield on uninterruptible casts**
- **Nameplates**: **Click through friendly nameplates**, **Click through enemy nameplates**, **Extra clickable width** and **Extra clickable height**. Where the game withholds a health value or refuses a change to a plate, that part stops and says so in `/flatui status`

## 0.4.35

- **Trackers**: new row **Add class trackers** on the **Trackers** page, named for your class (for example **Add Shaman trackers**), with **All** and one line for each starting tracker of the class. `/flatui tracker class` adds them all
- A buff, stance, form or totem is added only when you know its spell, an item only when it is in your bags. Weapon, pet and ammunition trackers are added for every character of the class. A tracker already on the list is not added again
- A Shaman gets one **Shield** tracker for Lightning Shield or Water Shield, **Weapon imbue**, the four totems (off until switched on, shown only in combat) and **Ankh**
- **Add a buff** and `/flatui tracker add` take every rank of a spell from the class data
- **Enemy cooldowns**: two bars of up to eight icons above the target and focus frames, showing that player's tracked cooldowns. Each bar has a handle in `/flatui move`, **Enemy cooldowns: target** and **Enemy cooldowns: focus**
- New choice **Place** on the **Enemy cooldowns** page: **Both**, **On enemy nameplates** or **Bars for target and focus**. `/flatui test` draws the bars too
- **Game settings**: sixteen of the game's own settings now sit beside the Flat UI settings they go with. The game saves them. Each row shows the game's current value. A row the game refuses to change prints one line and keeps showing the game's value
- **Nameplates**, **Game settings**: **Cast bars on nameplates**, **Nameplate distance**, **Nameplate style**, **Nameplate size**, **Horizontal overlap**, **Vertical overlap**, **Nameplates at the unit's feet**, **Target nameplate scale**, **Far nameplate scale**, **Far nameplate opacity**, **Opacity behind obstacles** and **Opacity of other nameplates with a target**
- **Chat and tooltips**, **Chat text**: **Timestamps** and **Class colours in chat**. **Fonts**: **Game text size**. **Bags and items**: **Combine bags**
- **Reset page** and the game's **Defaults** button do not write these rows. `/flatui cvar` lists each CVar with its value, the game's default and whether the game flags it secure. `/flatui cvar check`, out of combat, tells which of them Flat UI may change. `/flatui status` says how many of the 16 rows can be changed
- **Nameplates**, **Health bar**: **Health bar texture**, **Bar width** (narrows the health and cast bar together), **Dim strength**, and switches for **Incoming heals**, **Absorb shields** and **Heal absorbs**
- **Nameplates**, **Target and marks**: **Raid marker** with size and offsets, and a switch for the arrow for nameplates behind you
- **Restyle friendly nameplates**: off leaves friendly plates as the game draws them
- **Nameplates**, **Auras**: **Aura icon crop**, **Own aura border colour** with **Aura border colour**, **Countdown numbers**, **Stack count**, **Aura opacity**, and **Show auras** on every nameplate or only on the target
- **Cast bars**: **Spark**, **Uninterruptible shield icon** and **Latency zone** on the player bar can be switched off or on. **Border** takes the cast colour. **Bar texture** of its own. **Class colour on the player bar**. Own cast and channel colours on target and focus bars
- **Cast bars**, **Text and icon**: **Spell name** shown or hidden, aligned left, centre or right, in an own colour. The target and focus bar icon sits on the right or is hidden. A spell icon on the player and pet bars
- **Personal resource display**: **Bar texture**, **Percentage text**, **Value text** and an own text colour
- **Swing timers**: **Bar texture**, **Fill from the right**, **Out of range opacity**, **While not swinging** (show or hide the bar) and own text colours in and out of range
- **Unit frames**: new pages **Player frame**, **Target frame**, **Focus frame**, **Pet frame**, **Target of target frame**, **Party frames** and **Boss frames**
- **Picture**: **As Square portraits**, **Square picture**, **Game portrait**, **Class icon** or **None** for each frame. The party pet picture is its own row
- **Level** on or off for the player, target, focus and boss frames. **Resting animation**: **Hidden with the resting colour**, **Shown** or **Hidden** on the player frame
- **Health bar colour**: **Health colour**, **Class** or **Reaction** for each frame
- **All frames: bars and pictures**: **Health bar texture**, **Power bar texture** and **Name background brightness**. **All frames: icons and auras**: **Aura icon crop**, **Border colour by debuff type**, **Stack number size** and **Countdown numbers on party and pet debuffs**
- **Frame scale**: **Player frame scale**, **Target frame scale**, **Focus frame scale**, **Party frame scale**, **Boss frame scale** and **Raid frame scale** sliders (50% to 200%) on the **Unit frames** page. They follow Ctrl and scroll on a frame's handle and need **Move frames** and **Move the game's own frames** on
- **Pixel-perfect scale** and **Pixels per unit** on the **Flat UI** page: one interface unit becomes a whole number of screen pixels. A scale outside 35% to 115% is not applied
- **Border and background** for each area: on the **Nameplates**, **Action bars**, **Unit frames**, **Minimap and buffs** and **Chat and tooltips** pages, a new section with **Own border and background**, **Border colour**, **Background colour** and **Background opacity**. With **Own border and background** on, that page's borders and backgrounds use these colours and this opacity in place of the **Flat UI** page's
- Colours the addon sets for a reason (target, threat, debuff type, item quality) and the opacity of windows and chat stay as they are. **Border thickness** stays on the **Flat UI** page
- **Windows**: **Title size** (70% to 200%), **Own title colour** and **Title colour** set the size and colour of window titles
- **Bags and items**: **Quality border from** draws the quality colour on slots from the chosen quality up: **Every item**, **Green and better**, **Blue and better** or **Epic and better**. **Stack count size** (60% to 200%) sets the size of stack counts on item slots
- **Item level in bags and bank** shows the item level of weapons and armour on their slots. **Item level on equipped gear** shows it on the character window. **Item level size** (8 to 18) and **Item level colour** (**Item quality colour**, **White** or **Gold**)
- **New item glow** off hides the glow and flash on new items in the bags. **Dim grey items** darkens poor items that have a vendor price. The dividers of the **Character** window follow the border colour source

## 0.4.34

- **Trackers**: new kind item. **Add an item** on the **Trackers** page lists the items in your bags. An item tracker shows the item's icon with the count in your bags. It shows missing at 0, is low under **Item minimum**, and shows the item's cooldown as a sweep
- New kind Ammunition: the ammunition you carry, low at **Ammunition minimum** or under. A character that uses no ammunition shows fine
- New kind Tracking: fine while any minimap tracking is on, missing when none is
- New kind stance or form: **Add a stance or form** lists the forms you have. Fine in a listed stance or form, missing in none
- **Add a check** now has **Ammunition** and **Tracking**
- New settings: **Item minimum** (1), **Ammunition minimum** (200), **Hide while mounted** (on) and **Hide in cities and inns** (off). The last two apply to trackers set to **Only when low or missing**
- `/flatui tracker add item` (a name, item ID or shift-clicked item), `/flatui tracker add ammo`, `/flatui tracker add tracking` and `/flatui tracker add form`. `/flatui tracker set 1 low` goes up to 1000 for an item and 2000 for ammunition
- Item, ammunition, tracking and form trackers keep working in fights
- **Party cooldowns** now show on raid-style party frames and in a raid group
- Raid-style party frames: each member's row hangs from that member's frame, and your own row hangs from your own frame
- Raid group: your own row and your subgroup's rows stack in one place, each with the member's name. Move them with the handle **Party cooldowns: raid group** in `/flatui move`. **In a raid group** on the **Party cooldowns** page is **Own position** (the default) or **Off**
- **Add an ability** and **Hide an ability** on the **Party cooldowns** page change which abilities the rows show
- `/flatui party add` (an ability, a spell ID or a shift-clicked spell, and its cooldown in seconds), `/flatui party hide` and `/flatui party list`, which also says which members share cooldowns
- The lines "off in a raid group" and "icons show on the standard party frames only" are gone
- **Colours** page: **Border colour source** is **Border colour on the Flat UI page**, **Your class colour** or **Your faction colour**
- **Custom reaction colours**: **Hostile**, **Neutral**, **Friendly** and **Tapped by another player**
- **Custom power colours**: **Mana**, **Rage**, **Energy**, **Focus** and **Runic power**
- The border source applies to every border now. The reaction and power colours take effect where later builds read them
- **Flat UI** page: **Bar texture** has three more choices, **Game status bar**, **Skills bar** and **Targeting bar**
- **Fading**: new page. **Fade frames when idle** fades the action bars (main bar and bars 2 to 8), the stance bar, the pet bar, the micro menu, the bag bar, the player frame, the pet frame and the minimap buttons, one switch each
- **Faded opacity** (25%), **Wait before fading** (500 ms) and **Fade time** (300 ms) set the look. **In combat** (on) and **With a target** (off) keep the frames at full opacity
- Frames are also at full opacity under the mouse, while something is on the cursor, while a spell flyout is open and in Edit Mode. Faded buttons still work. A bar in an active Bar block fades with that block's **Fade the block**

## 0.4.33

- **Trackers** can follow totems and your pet. **Add a check** lists **Fire totem**, **Earth totem**, **Water totem**, **Air totem** and **Pet**. `/flatui tracker add totem fire` and `/flatui tracker add pet` do the same
- A totem tracker shows the totem's icon with the time left. It goes red when the slot is empty and is low under **Low at (seconds left)**. The sound plays when a totem ends
- In a fight where the game hides a totem, the tracker is drawn with the game's own timer calls. If the game refuses one, that part is left out and `/flatui tracker check` says which
- A pet tracker goes red when you have no pet or it is dead. `/flatui tracker set 1 happy on` makes a hunter's pet tracker low while the pet is unhappy
- **Enemy cooldowns**: new page. Up to four icons under the nameplate of each enemy player, with the time left. Kinds: **Interrupts**, **Defensives**, **Crowd control breaks** and **Wards and immunities** are on; **Mobility** and **Offensive cooldowns** are off
- A kick that stops your own cast starts that player's kick timer. A timer that has started keeps counting and follows the player from plate to plate
- Casts and buffs of enemies are used where the game does not hide them. Where it does, `/flatui status` says so in one line
- **Border colour by kind**: interrupts orange, defensives blue, wards and immunities white, crowd control breaks violet, mobility green, offensive cooldowns red. **Seconds on the icon** and **Icon size** (16 to 40) are settings
- `/flatui test` also draws sample icons on enemy plates. `/flatui check` has two new lines: Enemy casts seen and Enemy buffs read

## 0.4.32

- **Party cooldowns**: a party member who also runs Flat UI sends his cooldowns, so his interrupts and defensives show used and ready on his row wherever the game lets addon messages through. Where that is, is not known yet. New setting **Share cooldowns with the party** (on)
- When the game blocks addon messages, `/flatui status` says: Party cooldowns: the game blocks addon messages here, so cooldowns are not shared
- Settings pages: the long pages are split into pages under them. **Colours** is under **Flat UI**. **Health bar**, **Text**, **Cast bar**, **Target and marks** and **Auras** are under **Nameplates**. **Size** and **Text and icon** are under **Cast bars**. **Which windows** and **Bags and items** are under **Windows**. **All frames: bars and pictures**, **All frames: text** and **All frames: icons and auras** are under **Unit frames**. **Minimap**, **Buffs and debuffs**, **Bars, bags and micro menu** and **Tracker, loot and alerts** are under **Minimap and buffs**. **Tooltips** is under **Chat and tooltips**. The **Looks** section of **Unit frames** is on **All frames: text**
- Every setting keeps its name, value and saved place, so profiles and exported text work as before. A page with no settings is not listed

## 0.4.31

- **Trackers**: a **Bar** tracker in a fight shows the game's own bar for the buff, filled by the time left, or by the charges when **Bar fill** is **Charges**. A **Text** tracker shows the game's own count and time left
- **Low at (charges)** and **Low at (seconds left)** turn the digit and the time red as they do on an icon. `/flatui tracker check` lists the bar parts and says whether the game took the timer. If the game refuses the bar, the tracker shows the last known fill in fights
- **Add a check** on the **Trackers** page now has **Main hand enchant**, **Off hand enchant** and **Ranged enchant**. A weapon tracker shows the enchant's icon with the time left and charges, goes red and shows Missing when the weapon has no enchant, and is low under **Low at**. Shaman imbues, rogue poisons, sharpening stones and oils all count
- `/flatui tracker add weapon main` (or `off`, `ranged`) adds one. Weapon trackers keep working in fights, battlegrounds and arenas

## 0.4.30

- **Unit frames** page, new section **Looks**, with eight switches, all off: **Health in class and reaction colour**, **Dark health bar, colour shows what is lost**, **Muted colours**, **White names** (frames with a name row), **Smaller, lighter bar text**, **No text on the power bar**, **Soft shade on bars** and **Shadow behind each frame**. With all eight off the frames look as before. `/flatui status` shows a Looks line only when a look could not apply
- New page **Party cooldowns**: icons beside each party member's frame, ready cooldowns bright, used ones dark with the time left. **Interrupts**, **Defensives** and **Defensives cast on others** are on. **Crowd control breaks** and **Group cooldowns** are off
- A member's use of an ability is seen when the game shows his cast, and a defensive is seen when its buff can be read
- **Your own row** shows your own icons above the first member's, off by default. Settings: **Party icons** (right, left or below each frame), **Show**, **Icons for each member** (3 to 8), **Icon size**, and a switch for each kind
- Party cooldowns are off in a raid group and with raid-style party frames, with one line in `/flatui status`. `/flatui test` also shows sample icons on each party row. `/flatui check` has three new lines: party casts seen, party buffs read, and the caster of a party buff

## 0.4.29

- **Defensives on you**: new switch **Your own defensives** (off by default) shows the defensives you cast on yourself, such as Shield Wall and Ice Barrier, in a group of up to 4 icons
- New lists **Add a spell** and **Remove a spell** on the **Defensives on you** page change which buffs the row shows. `/flatui defensives add` (a spell ID or a shift-clicked spell), `/flatui defensives remove` (a spell ID or a name) and `/flatui defensives list` do the same from chat. Up to 40 spells can be added. The lists are kept for the account
- Where the game makes no icon row, **Your own defensives** is off and `/flatui status` says so in one line

## 0.4.28

- **Unit frames** page, under **Raid frames**: new setting **Raid cell look** (on by default). Raid frames, and party frames in raid style, get a thin power bar with its own thin border, and the health bar turns grey when the unit is dead or offline, a dead player included. The thin power bar shows only when **Display Power Bars** is on in the game's raid frame options, which is off by default. **Raid cell look** off puts the game's power bar and health colour back

## 0.4.27

- **Unit frames** page, section **Name row**: the pet, target of target, party and party pet frames have a row with the name above their bars, in the colour of the class or reaction of the unit. The picture grows to start at the top of the row
- Boss frames have the same row with the level at its end and no picture. **Level position** now covers the boss frames
- **Name row on small frames** (on by default) turns the row off on the pet, target of target, party and party pet frames. **Name row** still turns off every row
- `/flatui status` says the name, picture, row size and row colour for the target of target, boss 1 and the first party frame. Where the game withholds a unit's class, the row colour is dark and the status says so

## 0.4.26

- **Trackers** can be drawn as a **Bar** or as **Text**. On **Tracker look**, **Shape** chooses **Icon** (the default), **Bar** or **Text**, with **Bar width** (140), **Bar height** (14), **Bar fill** (**Charges** or **Time left**), **Colour**, **Charges** and **Name**
- A bar shows the name, the charges and the time left over a flat fill; **Text** shows them on a dark plate. Low and missing turn the bar fill or the text red, and the missing word and pulse work on bars and text
- A tracker can have its own shape and colour: `/flatui tracker set 1 shape bar`, `/flatui tracker set 1 colour 4d99e6`. `/flatui tracker test` draws each look in the tracker's own shape, and `/flatui tracker check` names the shape
- In a fight, a bar or text tracker for a buff the game hides keeps its last fill and name, with ? for the charges, or is hidden, as **In fights without the game's icon** says. An icon tracker keeps the game's icon
- **Bar width** and **Bar height** are the same for every tracker, and a tracker's own size changes only the icon. A change of **Bar texture** reaches existing bars after `/reload`

## 0.4.25

- **Cooldowns** page, section **Icons**: **Sound when ready** (off by default) plays a sound once when a spell on the Cooldown icons row is ready again. The global cooldown plays nothing. The sound is the **Sound** chosen on the **Low and missing** page of **Trackers**
- In a fight, where the game withholds a spell's cooldown, that spell's sound is skipped. `/flatui status` names the blocked call, and says "Cooldown icons: the game played no sound, so Sound when ready is silent." when the game plays none

## 0.4.24

- **Unit frames** page, new section **Level** after **Name row**. **Level position** is **End of the name row** (the default), **Before the name**, **On the portrait** or **Hidden**. **On the portrait** puts the level at the bottom right of the picture, with the Elite or Rare mark, and needs a picture
- **Level colour** is **By difficulty** (the default), **White** or **Same as the name**. **Level size** is **Same as the name** (the default), **Smaller** or **Larger**
- The game's round level plate, number and skull stay hidden in every position
- **Level position** replaces **Level in the name row**. A saved value of the old switch is dropped, so a player who had it off now sees the level at the end of the name row
- `/flatui status` adds a level line for each frame with a name row
- **Bar blocks**: a new page after **Bar block**. **Class spells**, **Buffs to apply** and **Consumables** each pick one of the game's bars, **Action bar 2** to **Action bar 8** (**None** by default). The bar's box in `/flatui move` has the block's name
- Each block has a position: **Where its handle is** (the default), **Above, left**, **Above, right**, **Below, left**, **Below, right**, **Left, bottom**, **Left, top**, **Right, bottom** or **Right, top**, with **Gap** from 0 to 40 px (4 by default). Blocks hang from the **Action bar block**, or from the bar in **Blocks hang from** (**Main action bar** by default) when the **Bar block** page is off. Blocks at one position stack outward
- **Pet bar position**: **Where the game puts it** (the default), **Above, right** or **Above, left**. When **Stance, pet and experience bars** is **Above the block**, the **Bar block** page places the pet bar and this setting does nothing
- With the **Bar block** page off and blocks hung from the main bar, **Above** positions and the pet bar can overlap the game's experience bars, **Action bar 3**, **Action bar 2** and the stance bar
- Casting, keys, cooldowns and counts are the game's own and work in combat. Icons, rows and visibility of each bar are set in Edit Mode
- New command `/flatui blocks` lists each block, its bar and its position. `/flatui status` says when a picked bar is off in the game's options, and names a pet bar or **Action bar 2** to **Action bar 5** the game still stacks in a fight
- With **Background panel** and **Fade the block** on, the panel and the fade do not cover the bars of **Bar blocks**

## 0.4.23

- New page **Defensives on you**: a row of icons for the shields, wards and protections other players cast on you, each with its time left, its charges and the caster's name. The game draws them, so they should show in fights, dungeons, raids and battlegrounds. That is not seen yet: `/flatui check` says "Defensives on you: the game's own icon row." when the game made the row
- Where the game will not make its icon row, the same icons show out of combat only, and `/flatui status` says so
- The page has **Defensives on you**, **Place** and **Caster's name**. **Place**: **Above the player frame**, **At the personal resource display**, **Own position** (drag the handle **Defensives on you** in `/flatui move`) or **Off**
- New command `/flatui test` shows three sample icons for 8 seconds and says whether the sweep ended on each and whether the sound played
- New command `/flatui check` prints whether the names and classes of the target and party1 can be read, whether addon messages pass, and whether the game shows who interrupted your last cast. `/flatui check last` prints the last check

## 0.4.22

- **Bar block** page, section **Background**: **Background panel** (off by default) draws a flat panel behind the block in the general background colour, with **Background padding** from 0 to 24 px (4 by default)
- Section **Fade**: **Fade the block** (off by default) fades the bars to **Faded opacity** (0 to 100 percent, 30 by default). **Full opacity in combat** and **Full opacity under the mouse** are on by default. The bars are also at full opacity while something is held on the cursor or a spell flyout is open. Faded bars still take clicks

## 0.4.21

- **Trackers** has two pages under it. **Tracker look** has **Icon size**, **Time left**, **Row direction**, **Spacing**, **Place**, **Side of the personal resource display**, **X offset** and **Y offset**. **Low and missing** has **Low at (charges)**, **Low at (seconds left)**, **When missing**, **Sound when it drops** and **Sound**. **Trackers** keeps the list, **Show** and **Game's own icon in fights**
- New settings: **Row direction** (**From the middle**, **Left to right**, **Right to left**), **Spacing**, **Side of the personal resource display** (**Above**, **Below**), **Sound** (**Raid warning**, **Alarm**, **Whisper warning**) and **In fights without the game's icon** (**Last known**, **Hidden**)
- With **Below**, the row goes under the Cooldown icons row when that row is under the personal resource display
- Trackers with different places make one row each
- New command `/flatui tracker set 1 low 2` gives one tracker its own value for place, show, low, lowtime, missing, sound, kit, size, x, y, name or on. `clear` as the value takes it back, and `/flatui tracker set 1 clear` takes back all of them. An own `x` or `y` replaces the page's **X offset** or **Y offset** for that tracker; it is not added to it
- `/flatui tracker check` shows each tracker's place and own settings. `/flatui tracker list` shows the place and the number of own settings of a tracker that has them

## 0.4.20

- **Unit frames** page, section **Portraits**: **Portrait style** is **Picture** (the default), **Class icon** or **None**. **Class icon** shows the class of a player. Other units keep their face. **None** leaves the space empty
- **Portrait size** is **As tall as the frame** (the default) or **As tall as the bars**
- **Portrait border** is **Thin** (the default), **Class or reaction colour** or **None**. **None** draws no edges. Resting, combat and Elite colours still show
- **Portrait fades with the name row** is on by default and changes how the player, target and focus pictures look: the top of the picture fades into the background beside a name row that fades upward. It is an overlay in the background colour, not true transparency, so it matches only where the world behind is dark
- Switches **Player portrait**, **Target portrait**, **Focus portrait**, **Pet portrait**, **Target of target portrait**, **Party portraits** and **Party pet portraits**, all on by default
- `/flatui status` names the picture of the player, target and pet frames and says whether the client withholds the unit's identity

## 0.4.19

- **Bar block**: new setting **Stance, pet and experience bars** (**Above the block**, **Left to the game**). With **Above the block**, the experience bars are on top of the block, the stance bar on the left and the pet bar on the right above them, and the possess bar above those, instead of over the block's second row. The Leave vehicle button stays where the game puts it
- `/flatui status` names the bars the game still stacks in a fight and how to keep them (arrow key once in Edit Mode, save)
- New command `/flatui block facts` prints what the game says about the bars and Edit Mode layouts

## 0.4.18

- **Bar block**: a new page after **Movers**. **Group action bars into a block** (off at first) lines up **Main action bar**, **Action bar 2** and **Action bar 3** where the main bar is now, with the same gap as between the buttons
- `/flatui move` shows one box, **Action bar block**, that moves every bar in the block. Right-click on it puts the block back: the main bar at the left of the micro menu, or the bottom middle of the screen when another bar is first
- **First bar** to **Sixth bar** pick the bar in each row, **Stack direction** and **Line up bars** set the order and the alignment, **Own gap between bars** and **Gap between bars** set the space
- The block is placed out of combat. In a fight Action bars 6 to 8 and any bar you have placed in Edit Mode stay in the block; the other bars go back into the game's stack until the fight ends
- `/flatui status` says when the **Movers** page, **Move the game's own frames** or **Keep moved frames in place** is off and the bars are not placed, and names a bar the game places itself

## 0.4.17

- `/flatui tracker check`: the first two lines say whether the game has hidden values and which kinds are hidden now: auras, cooldowns, your casts and a group member's casts
- After a fight the same words are given for the last fight, with the first tracker's buff and its level
- The weapon enchant line lists the main hand, off hand and ranged slots, each with its enchant's type (Permanent, Temporary or Imbue)
- In a fight the game's own icon shows its time text without the red colour when the game refuses the colour

## 0.4.16

- Pet frame size: **Unit frames** page, section **Pet frame size**. **Custom pet frame size** sets the pet frame to a percent of the player frame or of the normal size, and keeps that size when the game lays its frames out again and after Edit Mode closes. While it is on, Edit Mode's pet Frame Size is not used
- **Pet frame size is measured against** is **Player frame size** (the default) or **Normal size**. **Percent** goes from 50% to 200%, 100% by default. The setting is off by default
- Ctrl and the wheel on the pet frame handle in `/flatui move` no longer scale it
- Out of combat only: a change made in combat shows when combat ends
- `/flatui status` shows the size and how many times it was put back

## 0.4.15

- **Windows** page, new section **Clean up bags**: **Clean up bags button** (**In the title bar**, **Under the slots**, **None**), **Also on the bank** and **Items gather** (**As the game sorts**, **From the other end**)
- A small button with three bars at the right end of the title bar of the combined bag, each separate bag and the bank sorts your items with the game's own clean up and plays its sound. **Under the slots** puts it below the lowest bag of a stack instead, and inside the bottom left corner of the bank
- On the bank the button asks first while the game's bank question is on, then sorts the bank that is shown. Its tooltip says **Clean Up Bags**, **Clean Up Bank** or **Clean Up Account Bank**
- `/flatui sort` cleans up the bags and `/flatui sort bank` cleans up the bank that is open. When nothing happens a line says why: an item on the cursor, no bank open, no bags bought on that bank
- **From the other end** makes the game's clean up, its own button included, fill your bags from the other end. The game's own direction comes back when you choose **As the game sorts**, turn the page off or log out
- With the gamepad interface style there is no button, and it goes or comes back as soon as the style changes
- The game's own clean up buttons on the backpack, the combined bag and the bank stay

## 0.4.14

- **Trackers**: a new page after **Cooldowns**. A tracker shows a buff on your character as an icon with its charges and time left, a red rim at **Low at (charges)** or **Low at (seconds left)**, and a red icon when the buff is missing. **Sound when it drops** plays a sound when the buff ends
- Add a buff from **Add a buff**, or by name or spell ID with `/flatui tracker add`. **Remove a tracker** takes one off
- The row sits above the personal resource display, beside the character, or at a spot you drag (the **Trackers** handle in `/flatui move`). **Place** sets which
- When the game hides buff charges and time left in a fight, the tracker shows the game's own icon in the same place (**Game's own icon in fights**)
- `/flatui tracker check` says what each tracker shows and why. `/flatui tracker test` shows each look for 3 seconds
- With 15 pages, the left column of the options window scrolls to reach **Profiles**

## 0.4.13

- **Unit frames**: the class icon on the player, target and focus frames shows one icon, not a crop of the whole icon sheet
- The **Reload** button in the options window reloads the interface. If the game blocks it for add-ons, the first press says so in one line and the button reloads on the next press. `/flatui status` then has a line **Reload: secure button.**
- Text sizes on bars and cast bars stay on when the game answers false for a font that loaded
- Combat numbers: a number that fails while it is drawn no longer takes its font string out of use
- `/flatui combat reset` names each row the game refused. The last line says the defaults are back only when they are, and names **Scrolling Combat Text for Self** when it stays as you have it
- `/flatui combat` prints the outline flags in quotes
- Movers: a spot near the screen edge is kept inside the limit the game sets for its own frames

## 0.4.12

- **Movers**, section **Centre**: new **Snap while dragging** (**To the middle of the screen**, **Off**), **Centre a handle with** (**A button on the handle**, **Alt and click**, **Both**), **Middle line** (**Shown while dragging**, **Always shown with the handles**, **Off**) and **Centre everything** (**No such button**, **A button in the Movers panel**)
- While you drag a handle or a window, a thin gold line shows down the middle of the screen. The handle or window snaps onto it when its middle is within 8 units
- Each handle has a small button in its top right corner that puts it on the middle at the height it has, and a tick box in its top left corner. A handle too small for them has them above it. **Centre ticked** in the **Movers** panel centres every ticked handle. Grey handles of frames the game places have neither
- With **Centre a handle with** set to **Alt and click** or **Both**, Alt and click on a handle centres it
- A window with no handle is centred by dragging it across the middle
- With **Place the tooltip** on and **Position** set to **Fixed**, a centred **Tooltip** handle puts the tooltip in the middle at any width

## 0.4.11

- **Side tab size** in the section **Controls** of the **Windows** page: **Game's size** (50), **Large** (42), **Medium** (36) or **Small** (30). **Small** is the default. The tab is the icon plus 5 units and the gaps between tabs are unchanged, so the column is shorter. It sizes the tabs beside the Character, Inspect, Collections, Looking For Group, bank, Professions and Legacy windows and needs **Side tabs**.

## 0.4.10

- **Chat and tooltips**, section **Tooltips**: new **Tooltip background** (Near black, Black, Dark blue, Dark brown), **Tooltip opacity** (40% to 100%) and **Tooltip shading** (**Flat**, **Lighter at the top**, **Darker at the bottom**). They apply to every tooltip and to the label above a comparison tooltip, which is always flat
- The tooltip box no longer follows **Background colour** and **Background opacity**. It starts as Near black at 70%, Flat (the general background gave 85%)
- With **Tooltip border and background** off the three rows are greyed and the game's own art is back
- If the game refuses a gradient the tooltip stays one colour and `/flatui status` says so

## 0.4.9

- **Map & Quest Log**: the small window has a title bar that drags it and a corner grip that sizes it from 60% to 150%, under the existing **Windows** settings on **Movers**. Its place and size are saved in the profile in use
- At full size and in the gamepad interface the game keeps the window, and `/flatui status` says why it cannot be dragged. The small place and size come back when the map is made small again
- A protected map is not moved or sized in combat; if it goes to full size in combat it keeps the addon's scale until combat ends

## 0.4.8

- **Minimap and buffs**, section **Minimap**: new **Minimap in cities** for the city map the game shows in the minimap inside some cities
- **Game's ring while the city map shows** brings the game's ring back only while the city map is up
- **Flat round cover** (the default) covers the square corners of the city map in the background colour and draws the thin border round the circle. It follows **Border colour**, **Background colour**, **Border thickness**, **Borderless** and **Minimap border**, and goes with the minimap when you hide it
- **Leave as is** leaves the city map as the game draws it
- `/flatui status` has a line **Minimap in cities**: whether the game asks for the city map here, whether it is loaded and shown, where the game draws it, whether the game's mask is set on it, whether the cover is shown and whether it is visible

## 0.4.7

- **Combat text**, section **Look**: **Font** (Friz Quadrata, Arial Narrow, Skurri, Morpheus), **Outline** (Thick, Thin, None), **Shadow** and **How a number appears** (**With a pop, larger for critical hits** or **Plainly**). They apply to the numbers in front of nameplates and to your own text. The defaults are Friz Quadrata, no outline, no shadow and a pop
- With a pop, a number swells for a fifth of a second. A critical hit starts a fifth larger than other numbers and swells to twice that size. A critical or crushing hit over an enemy is now a fifth larger than other numbers, with or without the pop (it was one and a half times)
- **Combat text**, section **Your character**: **Combat text for you** draws the damage and healing you take, as -412 in red (purple for magic) and +300 in green. **Also misses, dodges and gains** adds Miss, Dodge, Parry, Block, Resist, Absorb and the like, and gains such as +20. **Movement of your text** (Up, Down, In an arc) and **Size of your text** (60% to 160%)
- The handle **Combat text: you** in `/flatui move` places where your text starts. It starts above and left of your character
- While your text shows, the game's **Scrolling Combat Text for Self** is off and its other messages do not show. It is put back when you choose **Off**, switch **Place combat numbers** off, type `/flatui combat reset` or log out
- When the game refuses a font, the numbers show in Friz Quadrata with the same outline and shadow, or in the game's combat font, and `/flatui status` says which
- The sections for numbers over enemies are now **Position and size over enemies** and **Spread and movement over enemies**
- `/flatui combat test` shows samples for you and over your target. `/flatui combat` also shows the font in use, the outline flags the game gives, the hits seen for you, where your text starts and the height of WorldFrame

## 0.4.6

- Target and focus frames: a unit with no Elite or Rare kind gives up no room in the name row, so its name is as long as the player's
- **Unit frames**: a setting that changes the room of the texts in the name row, changed in combat, is laid out when combat ends. The PvP word waits for its place and does not overlap the name
- **Word in the name row** in the section **Elite and Rare** is now **Elite or Rare word**, so it differs from the **PvP flag** choice of the same name
- The tip of **Line under the name row** names the colours: gold for an Elite, silver for a Rare, red for a Boss

## 0.4.5

- **Unit frames**, section **Elite and Rare**, for the target and focus frames: **Mark after the level** (+ for an Elite, R for a Rare, R+ for a Rare Elite), **Word in the name row**, **Portrait border colour** (gold for an Elite, silver for a Rare, silver with a gold inner line for a Rare Elite, red for a Boss) and **Line under the name row**
- Name row order from the right: mark, level, word of the kind, PvP word with its time, name

## 0.4.4

- **Unit frames**, section **PvP flag**: **PvP flag** as an icon on the portrait, a word in the name row, both or off, on the player, target and focus frames; **Icon corner**; **Time until the flag drops** on your own frame
- The game's level text stays hidden after a level gain
- Shorter lines for the unit frames in `/flatui status`

## 0.4.3

- Window dragging and sizing, in a **Windows** section on the **Movers** page with eight settings. A window drags from any empty part or from its title bar, with an optional held key (**Shift**, **Alt** or **Ctrl**)
- A **Corner grip** at the bottom right sizes a window from 60% to 150%. Places and sizes are kept in the profile, or put back when the window closes. **Size applies to** each window or every window together
- **Reset windows** and `/flatui move reset windows` put every window back to its default place and size
- `/flatui status` lists windows that cannot be dragged, with the reason

## 0.4.2

- New **Combat text** page with 10 settings: damage and healing numbers over enemies, drawn in front of their nameplates with the kind of hit in parentheses after the amount, as in 412 (Glancing)
- Height, size, spread and movement of the numbers, an option to colour hits by school of magic, and a choice of every enemy with a nameplate or the target only
- Sets nine of the game's combat number settings and puts them back when **Place combat numbers** goes off
- `/flatui combat` shows the settings and the hits seen, `/flatui combat test` shows sample numbers over your target, and `/flatui combat reset` puts the game's defaults back

## 0.4.1

- Name row: the name on the player, target and focus frames is drawn at full opacity
- **Square portraits** show on the player, target and pet frames, each sized to the height of its bars
- **Corners** on **Soft** or **Slightly soft** round the border of each picture and leave the picture itself square
- The pet frame's name follows **Small frame text size**
- `/flatui status` has lines for the player, target and pet frames: where the name comes from, the picture's size, the pet name's size and the pet frame's scale

## 0.4.0

- Thin dark borders, flat backgrounds and flat bar fills on nameplates, unit frames, action bars, cast bars, swing timers, the personal resource display, chat, tooltips, the minimap and game windows
- Options window with 13 pages, 229 settings, a search box and a switch on every page but **Flat UI**. The same pages are under Options > AddOns > Flat UI
- **Profiles** with copy, reset, export and import as one line of text
- **Movers** for frames and windows: `/flatui move`, `/flatui grab` and drag by window title
- **Custom UI scale** from 35% to 115%
- Seven bar textures and five cast colours
- Nameplates: marks for Elite, Rare and Rare Elite, border colours for Elite, Rare and Boss, target and focus borders, class icons
- Unit frames: square portraits, name row, threat and Elite borders
- **Cooldown icons** row for picked spells, and restyled cooldown manager icons
- Tooltip placement at the cursor or at a fixed spot
- `/flatui status` shows what is styled and any error. A page that keeps failing stops on its own.
