The **Bags and items** group holds two pages. **Bags** puts all your bags in one Flat UI window, with sections, a search and your gold, and gives your bank a window of its own. **Item slots** styles the item slots of the game's own windows, marks items in the game's bag windows, and adds durability, thorns and plain stat explanations to the Character window.

## Bags

**Flat UI bags**, at the top of the page, is on as Flat UI comes. While it is on:

- One window holds every bag you carry, and a second window holds your bank. The bank window also shows your bank away from the banker, as you last left it.
- The game's bag windows stay hidden, and so does its bank window while **At the banker** is Flat UI's.
- The name in either window's title picks another of your characters, to see their bags or bank.

Flat UI bags stays off while another bag addon is loaded, and under the gamepad interface. `/flatui status` says why it is off.

Open the bags with B, as with the game's bags, or with `/flatui bags`. Open the bank window with `/flatui bank` or the **Flat UI bank** key.

### The bag window

The title bar holds the name of the character whose bags you see, and buttons that switch between **Sections** and **Bag by bag**, clean up your bags and open the bank window. Drag the title to move the window. `/flatui move` also has a box for each window, **Flat UI bags** and **Flat UI bank**. See [Layout](Layout).

**Show items** sets how the window lays out your items:

- **Sections** (the default) groups items by kind, as **Sections** below explains.
- **Bag by bag** shows each bag in turn, as the game does, under its icon, name and free slots. Bags with the same name add their number, as "bag 3". Click or right-click a bag's label for its settings (Assign To, Ignore for Clean Up and Junk Selling).

**Size.** **Width in slots** is 12 (from 6 to 30), **Bank width in slots** is 16 (from 6 to 36), and **Slot size** is 36 px (from 24 to 48). You can also drag the small grip at a window's free corner, the bag window's bottom left or the bank window's bottom right, to make it wider or narrower one column at a time, up to what fits on your screen. Double-click the grip to put the width back to 12 (16 for the bank). A drag or a double-click is one change in **Recent changes** on the options window's **Home** page, so Ctrl+Z puts it back.

**Menus.** A section title's right-click menu groups its lines under faint thin lines: moving the section, this section's own lines, those for every section, the lists and your own sections' lines. Escape closes an open menu of either window first, such as a section title's menu, the Characters picker or a bag's settings, and the bags stay open; a second Escape closes them. In a fight the first Escape closes both.

**Nothing moves while the window is open.** What you loot gathers at the top under New items. Anything else that comes into your bags meanwhile, such as an item from the bank or gear you take off, gathers there too, under Added. Point at the New items or Added title for what came in, each item with its count, and what it is worth at a merchant.

### The footer

The footer shows your gold, your currencies and your free slots.

**Gold.** It lights faintly under the mouse. Point at it for every character's gold, the one you play marked with a small square in your accent colour. The tooltip also says what you made or spent this session and since when, as "since 14:05" on the game's clock, and after ten minutes how much that is an hour. Ctrl-click the gold to count the session from now. Every change floats up from it as a short "+38s 2c" in green or "-1g 4s" in red; a whole **Sell junk** pass adds up to one.

**Currencies in the footer** (on) shows each currency that the Currency tab of the Character window marks Show on Backpack, with its icon and count.

- Point at one for its tooltip, and click it to open the Currency tab (in a fight, once it ends).
- Shift-click one to link it in chat or, with no chat box open, to take it off the footer, as on the game's backpack.
- Another character's bags show its currencies as Flat UI last saw them.

**Free slots.** Only the backpack and normal bags count as free space. Trade bags, quivers, ammo pouches, soul bags, the reagent bag and the keyring take only certain items. The count pulses twice in red when your last free slot fills, or when the window opens full. In Sections, the Free slots title says how many are free, as "12 of 80", gold at 4 or fewer and red when none is left.

- **Free slots** (in Sections): **One per kind of bag** (the default) shows one slot with the number free in normal bags and, in your own bags, one for each kind of special bag with room. **Every free slot** shows them all. Drop an item on a free slot to put it there. The Free label in the footer lights faintly under the mouse, and in Sections a click on it switches between the two, as one change in **Recent changes** that Ctrl+Z undoes.
- **Say when your bags fill** (on): chat says once, also with the bag window closed, "Flat UI: your bags are full (0 of 80 free)." With junk in your bags it goes on to say how many slots that junk takes and what it is worth: "Junk takes 6 slots, worth 1g 4s: Sell junk at a merchant frees them." It says it again only after a slot frees up, and at most once in 10 seconds.
- **Sound when your bags fill**: **None** (the default), **Bell**, **Chimes**, **Alarm** or **Raid warning**, played with the line in chat.

### Bag slots

With **Bag slots** on (as Flat UI comes), a row over the bag window's footer holds your backpack, bags and reagent bag, and your keyring at its end while the game shows one. It works also while the game's bag bar is hidden or faded away.

- Each bag shows its free slots in its corner: gold at 4 or fewer, red when it is full. The keyring shows how many keys it holds; point at it to see them by name.
- Point at a bag there, or on the game's bag bar, to light its items in the window. The tooltip opens beside the window, so the lit items stay in view.
- Drag a bag from your bags onto a slot to put it in or swap it, and drag a slot to take its bag out. A slot glows while the bag on your cursor fits it.
- While a spare bag sits in your bags, each empty slot it fits stays lit, and a click there puts it in, largest first.
- Drop a key on the keyring, or click it with a key on your cursor, to put the key on your keyring.
- Click a bag to show only that bag, its edge lit, until you click it again. Right-click it for its settings (Assign To, Ignore for Clean Up and Junk Selling).
- Loot pops on the slot of the bag it goes into.

Putting bags and keys in and out waits for the end of a fight.

### Sections

In **Sections**, items are grouped in sections, in this order until you change it: New items, Keep in place, your own sections, Equipment sets, Equipment, Consumables, Quest items, Trade goods, Reagents, Recipes, Ammunition, Bags and quivers, Keys, Other, Junk and Free slots.

**New items at the top** (on): items the game marks as new stay at the top until you close the bags after seeing them. A click on the title, or a clean up, puts them away now. With this row off, everything that comes in while the bags are open waits there, under Added.

Three rows split a section by kind:

- **Equipment**: **One section** (the default), **Weapons, armour and jewellery**, or **Each kind**: Weapons, Shields and off-hands, Armour, Rings, Necklaces, Trinkets, Relics, and Shirts and tabards, with Equipment for anything else you can equip.
- **Consumables**: **One section** (the default), **Food, potions and the rest** (Food and drink, Potions and elixirs, Consumables), or **Each kind**: Food and drink, Potions, Elixirs and flasks, Scrolls, Bandages, Enhancements, and Explosives and devices, with Consumables for the rest.
- **Trade goods**: **One section** (the default) or **Each kind**: Cloth, Leather, Metal and stone, Herbs, Elemental, Enchanting, Meat and Parts, with Trade goods for the rest, such as gems.

The split sections fold, move, take drops and can be deleted like any other. Right-click one of their titles to split or join them, which changes the row too.

**Order in a section** lines up the items of each section, in both windows and for all your characters:

- **By kind** (the default): gear by slot and item level, the rest by kind, then quality, name and stack size.
- **Best quality first**, **By name** or **Highest item level first**.

Keep in place always keeps the order of your bags. Right-click a section's title for **Order: By kind** to change it there too, in both windows at once, as one change in **Recent changes** that Ctrl+Z undoes.

### Folding, moving and colouring sections

- **Fold.** Click a section's title to fold it to one line, and again to open it. Shift-click it to open only that section and fold the others, and Shift-click again to open them all. Point at a folded title to see what it holds. **Folded sections** on the page opens one folded section, or all of them.
- **Move.** Drag a section's title to put the sections in your own order, or right-click it to move it up, down, to the top or to the bottom. **Section order** puts Flat UI's own order back. New items stays at the top and Free slots at the bottom.
- **Colour.** Right-click a section's title to give it a colour, which its title and its + slot take.

Folds, order and colours are the same in both windows and for all your characters.

### Deleting a section

You can delete any of Flat UI's own sections but New items, Free slots and Other. Right-click its title and choose **Delete this section**, or choose it in **Delete a section** on the page. While Equipment, Consumables or Trade goods shows its kinds apart, a line in **Delete a section** deletes the whole group at once, as "Equipment: all 8 kinds".

Nothing is lost. A deleted section's items go to the next section that takes them, and Other takes whatever is left. A deleted kind goes to the rest of its group while that shows, so a deleted Potions goes to Consumables.

- Deleting Junk only moves your junk into other sections. **Sell junk**, the junk coin and your sell list stay.
- Deleting Keep in place leaves your pins as they are.
- Items you placed by hand in a deleted section come back with it, and so do its place and its fold.

To bring one back, click the dim **Deleted (3)** after the last section, or choose it in **Deleted sections** on the page. Chat says so and the section flashes Back.

### Placing items by hand

Drop an item on a section's title, on its + slot or anywhere among its slots, to keep it there. From then on every stack of it shows in that section, in both windows and for all your characters, also when you loot it again (it still glows while it is new). It stays there until you place it elsewhere or put it back.

- With **Drop slot in each section** on (as Flat UI comes), each section ends in an empty slot with a +. Click it with an item on your cursor, or drop the item on it.
- An item from your bank, or one you wear, goes into a free slot of your bags first. A merchant's item is bought into one, unless the game asks before it buys it.
- While an item is on your cursor, every + slot and title that would take it lights in your Highlight colour. One that would not stays unlit and says why in red in its tooltip, as Junk does for a quest item. Nothing lights in a fight.
- A drop on the section the item would go to anyway keeps it there too, so changing **Equipment**, **Consumables** or **Trade goods** never moves it.
- An item's tooltip in these windows says when it is placed by hand in its section.

**Items placed by hand** on the page lists them. Choose one to put it back in its own section, or the first line to put them all back. A section title's right-click menu also puts back the items placed there. Until the next put back or a reload, the same menu, or the first line of **Items placed by hand**, brings them back again, also a single item you chose there. At most 2000 items are placed by hand.

**Placing a whole search.** With a search typed, a section title's right-click menu has **Place the 7 items that match the search here**. It places every item the search finds in other sections there at once, New items too but not those of Junk or Keep in place. So `#boe q>=uncommon` fills an Auction section of your own in one click.

### Your own sections

Click **+ New section** after the last section to make a section of your own, type its name (up to 24 letters) and press Enter. Escape cancels. Drop an item on **+ New section** to make one for that item, its kind (such as Mail) already typed in. You can have up to 20.

- Right-click its title to rename it, give it a colour, empty it or delete it. Its items go back to their own sections.
- Until the next delete or a reload, **Bring back** at the top of **+ New section**'s right-click menu restores the last one deleted, with its items, fold and place.
- Your sections come after Keep in place, are the same in both windows and for all your characters, and the search finds them by name.

**A section that fills itself.** With a search typed, choose **Keep what the search finds here** in your section's title menu. From then on every item that search finds goes there by itself, also what you loot later. An Auction section can keep what `#boe q>=uncommon` finds. The title's tooltip names the search, and the same menu stops it, searches for it again, or keeps another search instead.

**Custom sections** on the page lists your sections and does the same: make, rename, colour, empty, delete, bring back, and stop keeping a search.

### Searching your bags

Type in the search box at the top of the bag window. What does not match dims, and the box shows how many items match, in red at none. While you search, each section's title says how many of its items match, as "3 of 24", and a section with no match fades. Point at the empty box, out of a fight, for the list of search words.

**Words** look in each item's name, kind and slot, and in the name of its section: potion, cloth, mail, head, consumables.

**Joining words:**

- A space or `&` means and.
- A bar means or, as in `(cloth | leather) #gear`.
- `!` means not, as in `!#junk mail`.
- Brackets group, and `"quoted text"` is one word.

**Search words** start with #:

| Word | Finds |
| --- | --- |
| `#new` | New items |
| `#junk` | What Sell junk would sell |
| `#quest` | Quest items |
| `#boe` | Items that bind when equipped and are not bound yet |
| `#bound` | Bound items |
| `#set` | Items of an equipment set |
| `#usable`, `#unusable` | What you can, or cannot, use |
| `#learnable` | Recipes you can learn now |
| `#openable` | Items you can open, such as a clam, a satchel or a picked lockbox |
| `#gear`, `#weapon`, `#armour` | Weapons and armour, weapons alone, armour alone |
| `#consumable`, `#potion`, `#elixir`, `#flask`, `#food`, `#bandage`, `#scroll` | Consumables, and each kind |
| `#trade`, `#reagent`, `#recipe`, `#ammo`, `#bag`, `#key` | The items of that section |
| `#poor`, `#common`, `#uncommon`, `#rare`, `#epic`, `#legendary` | Items of that quality |
| `#placed` | What you placed in a section by hand |
| `#pinned` | What sits in its pinned slot |

**Quality and item level:** `q:rare`, `q>=uncommon` or `q<3` for quality, and `ilvl:20-30` or `ilvl>40` for item level.

**Inside the tooltip:** `tip:stamina` or `tip:"fire resistance"` looks inside each item's tooltip, and combines with the rest, as `tip:agility #boe`.

**Quick and recent searches.** Right-click the search box for quick searches: New items, Junk, Bind on equip, Quest items, Cannot use, Recipes you can learn, Can be opened, Consumables, Trade goods, Placed by hand, Green and better, and Epic and better. Under Recent it lists your last five searches of two letters or more, kept between sessions. Up and Down in the box bring them back too. Enter or Escape leaves the box, and the cross clears it.

The **Flat UI bags: search** key, under **Flat UI** in the game's Key Bindings, opens the bags with the search box ready to type in.

### Slot marks

The **Slots** section sets what each slot shows:

- **Item level** (on): on weapons and armour, the item level in the colour of its quality. On a bag or quiver, how many slots it has, in grey.
- **Quality border**: **Every item** (the default), **Green and better**, **Blue and better**, **Epic and better** or **Off**.
- **Item marks** (on): BoE at the top left of an item that binds when equipped; red over an item you cannot use; the Feed Pet icon on food your pet eats; a small green plus at the bottom left of a recipe you can learn now; and a small gold "open" at the bottom left of an item you can open, such as a clam, a quest reward satchel or a lockbox the moment it is picked.
- **Junk coin** (on): the game's coin at the top left of what **Sell junk** would sell.
- **New item glow** (on): the game's glow on a new item, until you point at it.

Item levels and bag sizes show in both windows, also for your other characters.

### Junk and selling

**Sell junk button** (on) puts a **Sell junk** button under the bag window at a merchant. It sells every item with the junk coin, as Errands sells, also with Errands off: grey items with a price, except in a bag you leave out of junk selling, and the items of your sell list.

- Its tooltip lists what it will sell, the item that brings the most first, each with its icon, count and what it brings (12 lines, then "and 3 more").
- While you point at it, every other item in the bag window dims, and so do the titles of sections with nothing to sell, so you can check before you click.
- While it sells, its label and tooltip count down what is left, as "Selling: 5 items left."
- The Junk title's tooltip, open or folded, says what your junk is worth and lists it the same way.

**Your sell list.** To sell an item at merchants from now on:

- Drop it on the Junk title (Junk is always there to drop on unless you delete it), or
- Alt+right-click it in the bag window. Alt+right-click it again to take it off; a grey one then goes on your keep list.
- Type `/flatui sell` and the item.

Quest items, items with no sell price and pinned items stay off the list. Right-click the Junk title for **Your sell list (5)** and **Never sold (2)**, each a small menu of its items, also of those no longer in your bags, each with its icon and its name in its quality's colour. Point at one for the item's tooltip. A click takes one off, and the menu opens again without it until the list is empty.

Two rows of the **Errands** page apply here too: **Sell at most 12 at a time**, so the items of your sell list that are not grey go 12 a click, and **Say what was done**, for the line in chat after a sale. They change only while Errands is on. See [Helpers](Helpers).

### Pinned slots

Ctrl+right-click an item in your bags to pin its slot to it, and again to unpin it. Ctrl+left-click stays the dressing room.

- A pinned slot has a small square at its top right, and its item's tooltip says it is pinned.
- In Sections, pinned items show in Keep in place, in the order of your bags and never sorted. An empty pinned slot shows faded.
- Drop an item on Keep in place's title to pin its slot, or a pinned item on another section to unpin it.
- If Ctrl is your Auto Loot Key, Ctrl+right-click opens an item that holds loot instead, so drop that one on Keep in place.
- A pinned item comes off your sell list, and a grey one goes on your keep list, so it is never sold as junk.

With **Put pinned items back** on (as Flat UI comes), Flat UI puts each pinned item back in its slot after a clean up of your bags, and when that item comes back into your bags, out of combat. Right-click Keep in place's title to put them back now.

**Pinned slots** lists this character's pins by bag and slot; choose one to unpin it. Pins are kept per character, at most 100, in your bags only: not the keyring, the bank or another character's bags.

### Cleaning up

The clean up button in the bag window's title cleans up your bags with the game's sound. So does `/flatui sort`, and the **Flat UI bags: clean up** key under **Flat UI** in Key Bindings. The key works also while **Restyle windows** is off, as long as **Flat UI bags** is on. If a clean up still runs, the key waits and chat says so. The tooltips of the clean up button, the bank button and the search box name the keys you bound.

**Items gather**, on the **Item slots** page, sets which end of your bags the items gather at.

### The bank

**At the banker** chooses the window you use there:

- **Flat UI's bank window** (the default) is live at the banker, and shows your bank anywhere else as you last left it. While it is open, windows that open on the left, such as the Character window, open one place further right.
- **The game's bank window** keeps the game's window at the banker. Flat UI's then shows your bank as last seen, with no clicks, Deposit or Take out.

A change counts from your next visit to a banker.

With Flat UI's bank window:

- **Open the bags at the banker** (on) opens your bags with it.
- **Deposit and Take out** (on) adds two buttons. **Deposit** puts the items of your bags that match the search in the bank, one at a time, out of combat. **Take out** does the same the other way. While one runs, its button reads "Stop (12)" and counts down; click it to stop. At the banker, a section's right-click menu also puts the whole section in the bank, or takes it out in the bank window, with no search.
- Point at a bank bag slot to light that bag's items and see how full it is. Each bank bag shows its free slots in its corner. Click one to show only that bag until you click it again, and drag it to pick it up.

### Other characters

Pick another of your characters in a window's title to see their bags and bank, each listed with their gold as last seen. `/flatui bags` or `/flatui bank` with a name does the same.

- **Counts in tooltips** (on): an item's tooltip names who else on your realm and its connected realms carries it, in their bags, bank or gear, as Flat UI last saw them. When this character's bank holds some, or it wears one, a first line in your class colour says how many you have in your bags, your bank and your gear, and In all adds everyone up.
- **Forget a character** takes a character's bags, bank and gold out of Flat UI's records. It is kept again when it logs in with Flat UI bags on.

### Trade

**Open the bags for a trade** (on) opens your bags when a trade window opens.

### Keys and commands

These keys are under **Flat UI** in the game's Key Bindings:

| Key | What it does |
| --- | --- |
| **Flat UI bags: search** | Opens the bags with the search box ready to type in |
| **Flat UI bags: clean up** | Cleans up your bags |
| **Flat UI bank** | Opens or closes Flat UI's bank window |

| Command | What it does |
| --- | --- |
| `/flatui bags` | Opens or closes the bag window |
| `/flatui bags <name>` | Shows another of your characters' bags, as Flat UI last saw them |
| `/flatui bank` | Opens or closes your bank window: live at the banker with Flat UI's bank window, else as you last left it |
| `/flatui bank <name>` | Shows another character's bank |
| `/flatui sort` | Cleans up your bags |
| `/flatui sort bank` | Cleans up the bank that is open |
| `/flatui sell <item>` | Always sells an item at merchants (an item link, an item ID or the name of an item in your bags). Type it again to stop. |
| `/flatui keep <item>` | Never sells the item, such as a grey one you want to keep, and **Make room in full bags** never deletes it. Type it again to sell it again. |
| `/flatui sell` | Lists the items always sold and never sold |

## Item slots

The **Item slots** page works on the game's own windows and the Character window. All its rows but **Combine bags**, which is the game's own setting, need **Restyle windows** on (the **Windows** page). See [Chat and windows](Chat-and-windows).

### Item slots

- **Flat item slots** (on) draws the item slots of the game's windows flat, with a thin outline. It applies after a reload.
- **Quality colour** (on) colours a slot's border by the item's quality. **Quality border from** sets from which quality: **Every item** (the default), **Green and better**, **Blue and better** or **Epic and better**.
- **Flat highlights** (on) gives a slot a flat tint under the mouse and as you press it, in place of the game's glow. It applies after a reload.
- **Stack count size** sets the size of the stack count, from 50% to 250% (115%).

### Item level

- **Item level in bags and bank** (on): in the game's bag and bank windows. The **Bags** page has its own **Item level** row.
- **Item level on equipped gear** (on): on the slots of the Character window, and your average item level under your level, in **Item level colour** (gold at Gold, white otherwise), to set beside the one the Inspect window shows. It follows your gear as you change it.
- **Item level in the equipment flyout** (on): on the bag items that fit a slot, shown while you hold Alt over the slot.
- **Item level on the Inspect window** (on): on each slot, and the player's average item level under their level.
- **Item level corner on gear**: **Bottom left** (the default), **Bottom right**, **Top left** or **Top right**, on the Character and Inspect windows. Bags and the flyout keep the bottom left.
- **Item level size** (15, from 8 to 18) and **Item level colour** (**Item quality colour**, **White** or **Gold**).

### The game's bag windows

These rows work in the game's bag and bank windows. The **Bags** page has its own glow and marks.

- **New item glow** (on).
- **Dim grey items** (on) darkens poor items that have a vendor price.
- **Mark bind on equip items** (on) puts BoE at the top left of an item that binds when equipped and is not bound yet.
- **Tint items you cannot use** (on) puts red over an item whose tooltip has a requirement in red: class, race, level, skill, reputation, armour or weapon type, or a recipe you already know.
- **Mark food your pet eats** (on), for hunters: the Feed Pet icon at the bottom left of food your pet eats, while it is out.
- **Combine bags** (off) is the game's own setting for one combined bag window.

**Backpack key opens every bag** (on) makes B, or your key for Toggle Backpack, open the reagent bag with your other bags and close them all again, as Open All Bags (Shift+B) does. WoW: Forever binds B to Toggle Backpack, which with **Combine bags** leaves the reagent bag shut. With separate bags it opens all of them, not only the backpack.

### Clean up bags

- **Clean up bags button**: **In the title bar** (the default), **Under the slots** or **None**, on the game's bag windows. Under the slots, only the lowest bag of a stack has a button.
- **Also on the bank** (on) adds the button to the game's bank window.
- **Items gather**: **From the other end** (the default) or **As the game sorts**. It also applies to the game's own clean up.

### Character window

These rows add lines to the Character window.

**Show durability** (on) puts the durability of all the gear you wear under the left column of slots, as "Durability 62%":

- White above 80%, yellow above 50%, and red at 50% and below.
- Red while any item is broken (0%, so it gives no stats), and at least yellow while any is at 20% or less.
- Point at it for each item that wears out, lowest first, with its icon, name and percent, then all items together and, where the game gives it, about what a repair costs. A broken item puts a red "1 item broken: no stats until repaired" at the top.
- Where the game keeps gear from wearing out, the line is gone.

**Durability on each slot** writes each worn item's own percent in the top corner of its slot, as a red "12%" on the chest and a yellow "45%" on the boots. It is red at 20% or less and when broken.

- **At 50% or less** (the default), **Always under 100%** or **Off**.
- The corner moves to the top left while **Item level corner on gear** is **Top right**.

**Show thorns** (on) puts the damage an attacker takes each time it strikes you in melee under the right column of slots, as one total a hit: "Thorns 45".

- It counts Thorns, Retribution Aura and Fire Shield on you, other buffs whose text deals damage to attackers, and items you wear that inflict damage on an attacker when struck, an enchantment or a set bonus included.
- A shield spike, which strikes only on a block, follows the total where it fits, as "Thorns 45, +20-30 on block".
- Point at the line for each source with its school, and the total of each school.
- In a fight, the line keeps the buffs read before it. Lightning Shield's charges are not counted.
- The line shows only while something deals damage to attackers. **Also at 0** (off) keeps a grey "Thorns 0" for characters with none.

**Explain the stats** (on) adds a few plain lines under the game's own to the tooltip of each stat on the Character window, in your numbers now:

- What the stat does for you against an enemy of your level and, from level 60 or with **Against** set to a boss on the **Gear comparison** page, against a boss three levels above. The heads read as "Level 60  ·  Boss 63".
- Defense shows what happens to 100 melee swings: how many miss you, are dodged, parried or blocked, crit or crush, and how many hit normally. It also gives the two marks a tank aims for: 440 defence, at which a raid boss can no longer crit you, and 100% of a boss's swings avoided or blocked, at which it lands no crushing blows.
- Dodge, Parry and Block say how many of 100 swings each stops. Block also says how much one block stops and where that comes from.
- Armour says the share of physical damage it takes off, and what 100 more would add. Each resistance says the share of that school's damage it resists on average, and what 10 more would add.
- Strength, Agility and Intellect say what one point gives your class, as "1% crit takes 20 Agility".
- Stamina, Spirit, mana and energy, movement speed, weapon damage, haste, attack power, hit, crit and expertise each say what they do for you now.
- In a fight the game hides your stats, so the lines keep the numbers from before it and say so.

See [Character and gear](Character-and-gear) for the gear comparison, spell tooltips and hit table, which use the same numbers.

Every setting of this group, with its default: [Settings: Bags and items](Settings-Bags-and-items).
