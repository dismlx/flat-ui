The **Helpers** group takes small chores off your hands: selling, repairs, quests and popups on **Errands**, drink and health macros, a bar of consumables, one key to mount, and the aids of **World and cursor**. Each of the first four pages has its own switch at the top, and each row of **World and cursor** turns its own aid on or off.

## Errands

The **Errands** page does the chores the game leaves to you. **Run errands** is on as Flat UI comes, and each errand has its own row on this tab and on the **Popups and invites** and **Quests and levelling** tabs. Selling, repairs, **Make room**, **Train all**, summons, invites, new spell ranks and talent reminders wait for the end of a fight.

**Say what was done** (on) writes a line in chat after selling, repairing, training, deleting, accepting, declining and upranking, and when a quest is left to you. It also covers **Sell junk**, **Deposit** and **Take out** on the **Bags** page.

The **General** tab holds the merchant, loot and trainer errands.

### Merchant

- **Sell grey items** (on) sells your grey items when a merchant opens. Hold Shift as the merchant opens to keep them that time; chat says how many it kept.
- **Sell at most 12 at a time**: grey items go in one go, then the items of your sell list that are not grey, at most 12 at a time, so the merchant's buyback still holds them. A **Sell next 12** button sells the next ones. The **Sell junk** button of the **Bags** page follows this row too.
- **Items always sold** and **Items never sold** list the items you added with `/flatui sell` and `/flatui keep`. Pick one there to take it off. **Make room** never deletes an item you keep.
- **Repair**: **Off**, **With your gold** (the default) or **Guild gold first**. With **Guild gold first**, **Guild gold where** chooses where the guild pays: **Everywhere**, **In a group or an instance**, **In dungeons, raids and battlegrounds** or **In raids**. Elsewhere your own gold pays. With items sold too, one chat line says both.
- **Buy in bulk** (off): Shift-click an item at a merchant, and beside the game's box **Stack** buys a full stack while **Most** buys as many as your gold, the merchant's stock and your bags allow, a stack at a time. Both ask first. Not for items bought with tokens.
- **Buy with tokens without asking** (off) answers Yes when the game asks before it takes items or currency for a purchase. One that also costs 150 gold or more is left to you.
- **Sell loot still tradeable without asking** (off) answers Okay when the game asks before you sell an item you could still trade to your group.

### Loot and trainers

- **Quick loot** (on): when the game loots by itself (Auto Loot, or its key held), every slot is taken at once. Rolls still ask.
- **Make room in full bags** (on): while every bag is full, a button under the loot window deletes the cheapest grey item. It names the item first, as "Delete Broken Fang x3".
- **Train all button** (on): a button on the trainer window learns everything the trainer offers that you can pay for, and says how many, as "Train all (4)". A profession trainer is left to the game's Train button, which asks first. `/flatui train` does the same while a trainer window is open.

### Popups and invites tab

**Death and popups**:

- **Hold a key to release** covers Release Spirit until you hold **Key to hold** (Shift as it comes), so a stray click does not send you to the graveyard. It works **In dungeons and raids** (the default), **Everywhere** or **Off**. The game's own timer still releases you.
- **Release at once in battlegrounds** (off): half a second after you die in a battleground, your spirit goes to the graveyard in time for the spirit healer's next wave, and chat says so. Not while a soulstone, Reincarnation or another way back is offered, and never in an arena, the open world or a dungeon.
- **Accept summons** (off) takes a summons when the game lets you: not in a fight and not on a flight path.
- **Accept resurrections** (on), but not while the one who offers it is in combat or dead.
- **Type DELETE for you** (on) writes the word the game asks for before it deletes a good item. You still click Yes.

**Other players**:

- **Accept group invites from**: **Nobody**, **Friends**, **Your guild** or **Friends and your guild** (the default). An invite that comes in a fight is accepted as the fight ends. One that asks for roles, or would take you out of a queue, is left to you.
- **Decline duels** (off) declines every duel request at once, also in a fight.
- **Remember the last mail recipient** (on) keeps the name in the To box after a letter goes, until the mailbox closes.

### Quests and levelling tab

**Quests**:

- **Accept quests** (on) takes a quest when an NPC offers one or your group shares one. A quest that would flag you for PvP, and an escort a group member starts, still ask you.
- **Low-level quests too** (off) also accepts grey quests. Off, they are left to you, so the places in your quest log go to quests worth the time.
- **Repeatable quests too** (off) also handles quests you can do again and again, such as cloth or reputation hand-ins. Off, they are left to you, so nothing you may want to keep is given away.
- **Hand in finished quests** (on) takes the reward when there is only one. With a choice, the window stays open for you. A quest that takes money, or an item of green quality or better, is left to you.
- **Mark the reward worth most** (on) puts a small gold coin on the reward a merchant pays most for as the window opens, and its tooltip says how much. You still choose.
- **Key to do it yourself** (Shift as it comes): hold it as you talk to an NPC, and that NPC's quests and gossip are left to you until you walk away.
- **Skipped NPCs** lists the NPCs whose quests and gossip are always left to you. `/flatui npc` adds the NPC you talk to or target. Pick one in the list to stop skipping it.

**Gossip**:

- **Gossip options**: **Off**, **Saved options only**, or **Saved, quest and only options** (the default). Saved options are picked everywhere. In the open world, the one option marked (Quest), or an NPC's only option when it has no quest for you, is picked too. An option that casts a spell is never picked.
- **Saved gossip options** lists the options you saved with `/flatui gossip`. Pick one to forget it.

**Spell ranks**:

- **Put new ranks on your bars** (on): after training, a line at the top of the screen offers the new ranks for your action bars. Its **Uprank and reload** button puts them on and reloads the interface in the same click; **Later** puts the line away. Macros, items, the ranks you keep and a lower rank beside a higher one of the same spell stay as they are. The **New spell ranks line** box of `/flatui move` places the line.
- **Keep a rank on your bars** keeps the rank you pick where it is, as `/flatui rank` does. **Stop keeping a rank** takes it off that list.
- **Uprank your bars now** shows the line at once, as `/flatui uprank` does.
- **Lines about learned spells** handles the game's lines that start with "You have learned" or "You have unlearned": **As the game has it**, **Hidden**, or **One line in their place** (the default), which names what was learned a moment after the last.

**Reputation and talents**:

- **Show the reputation you gain** (on): Flat UI's experience bar shows the faction you last gained reputation with. Exalted and inactive factions are passed over, and a faction you pick in the game's reputation window shows until your next gain. See [HUD](HUD) for the bar.
- **Remind you of talent points** (on): when you reach a level, or log in, with talent points to spend, a line in chat says how many.

**Waypoints**:

- **Add the /way command** (on): `/way 45 61` puts a pin on your map there and the game points you to it. `/way Elwynn Forest 45 61` and `/way #1429 45 61` (a map ID) work for another zone, and `/way clear` takes the pin off. Typed while the world map is open, the pin goes on as you close the map. When another addon already has `/way`, it keeps it, and `/flatui way` does the same.
- **Clear a waypoint as you reach it** (on): a pin `/way` set comes off as you arrive, with a soft chime and a line in chat. It needs **In-game navigation**. A pin you put on the map yourself stays.
- **In-game navigation** (on) turns on the game's marker over the quest or map pin you track, with its distance, and an arrow at the edge of the screen while it is out of view. The game has this setting but does not show it in its options. Turned off here, the game's own value comes back.

### Errands commands

| Command | What it does |
| --- | --- |
| `/flatui sell <item>` | Always sells the item at merchants (a link, an item ID or the name of an item in your bags). Type it again to stop. `/flatui sell` alone lists both lists. |
| `/flatui keep <item>` | Never sells the item, and **Make room** never deletes it. Type it again to sell it again. |
| `/flatui train` | Learns everything you can pay for at an open trainer, like **Train all**. |
| `/flatui npc` | Skips the NPC you talk to or target: its quests and gossip are left to you. Type it again to stop. |
| `/flatui gossip` | Lists the options of the NPC you talk to, or your saved options when no gossip is open. |
| `/flatui gossip 2` | Picks the second option for you from now on, or stops picking it. |
| `/flatui uprank` | Offers the new ranks of your spells for your bars now. |
| `/flatui rank <spell>` | Keeps that rank of the spell on your bars, or stops keeping it (a spell link or ID). |
| `/way 45 61` | Puts a pin on your map. `/way clear` takes it off. |
| `/flatui way 45 61` | The same, when another addon has `/way`. |

## Drink and health macros

The **Drink and health macros** page keeps two macros up to date with your bags and your level. **Keep drink and health macros** is on as Flat UI comes. The macros, **Flat UI Drink** and **Flat UI Health**, sit in your account's macro list and are written again out of combat when your bags or your level change. Turned off, they are deleted, but one still on an action bar stays until you drag it off.

To put one on a bar, pick it under **Put a macro on your cursor**, out of a fight, then click an action button. Chat says "Flat UI: Flat UI Drink is on your cursor: click an action button to put it there." The game's macro window (`/macro`) has them too.

**Say when a macro changes** (on) writes a line in chat when a macro moves to a better drink, food, potion or healthstone, or has none left, as "Flat UI: Flat UI Drink now drinks Morning Glory Dew." It stays quiet at login. It also tells you once when you are down to 5 drinks, or to 5 foods while **Flat UI Health** eats, and again only after you restock above 5.

### Drink

- **Drink macro** (on): **Flat UI Drink** drinks the best drink in your bags that your level allows, conjured water first. A character without mana leaves it as it is.
- **Mana potion in a fight** (on): in a fight, where you cannot drink, it takes your best mana potion.
- **Mana gem first in a fight** (on): for a mage, in a fight it takes your best mana gem, then your best mana potion at the next press, and starts with the gem again after the fight. A gem still cooling waits behind a potion that is ready.

### Health

- **Health macro** (on): **Flat UI Health** takes a healthstone, then at the next press your best healing potion, and starts with the healthstone again after the fight.
- **Eat out of combat** (on): out of combat it eats the best food in your bags that your level allows, conjured food first.

## Consumables bar

The **Consumables bar** page puts a bar of buttons on screen for your consumables. It is off as Flat UI comes: tick **Show the consumables bar**. A click uses the item from whichever bag holds it, also in a fight. Each button shows the item's icon, how many you carry, its cooldown sweep and its tooltip, and flashes white once as a cooldown ends (never after a global cooldown).

The first six buttons have keys of their own under **Flat UI** in the game's Key Bindings: **Consumables bar button 1** to **6**. A key uses the item as you press it, as the game's action bars do, and a mouse click acts as you let go. `/flatui move` places the bar, with the **Consumables bar** box, above the chat window at first.

### Buttons

- **Buttons** chooses what the bar holds:
  - **Every consumable in your bags** (the default): one button for each item, never from the bank, in the order of the **Bags** page, then by name. The **Kinds in your bags** chips leave kinds out.
  - **Your list**: only the items you chose, in your order.
  - **Your list, then the rest**: your list first, then the other consumables in your bags.
- **An item of your list with none left** stays on the bar so its button keeps its place: **Show it greyed with 0** (the default) or **Leave a gap**. A click on it says in chat that your bags hold none.
- **Show count** (on) shows how many you carry across your bags. A stack of one shows no number, except on a button of your list.

### Your list

Your list is kept for each character and holds at most 24 items. It takes any item with a use that you cannot wear, such as the Hearthstone, not only consumables.

- **Add an item** offers the consumables in your bags that are not on your list, then the other usable items there.
- Or drop an item on the bar out of a fight. On a button of your list it goes in that place. While **Buttons** shows your list, a + at the end of the bar takes the item you hold.
- Shift and right-click a button of your list to take it off, or another button to put it on.
- **Take an item off**, **Move an item left** and **Move an item right** do the same from the page.

A key of the bar pressed while you hold an item on the cursor uses nothing and leaves the item there.

### Kinds in your bags

Untick a kind to leave it off the bar: **Food and drink**, **Potions**, **Elixirs and flasks**, **Scrolls**, **Bandages**, **Enhancements** (oils, sharpening stones, weightstones and the like), **Explosives and devices** and **Other consumables** (healthstones, mana gems and the rest, which come first on the bar).

### Layout

- **Button size**, **Buttons per row** and **Spacing** set the size of the bar.
- **Grow** sets which way the buttons go from the corner of the bar's box in `/flatui move`: **Right** (the default), **Left**, **Up** or **Down**. Rows stack upward while it grows right or left; columns go right while it grows up or down.
- **Fade out of a fight** (off) keeps the buttons at **Faded opacity** out of a fight. They come to full while the mouse is anywhere over the bar, in a fight and while `/flatui move` or Edit Mode is open, and they still take clicks and keys.

A change that needs a new layout in a fight waits for its end, and chat says so once. Counts, greying and cooldowns keep up in the fight. In test mode, an empty bar shows a few sample buttons where it sits.

## Mount key

The **Mount key** page gives you one key that mounts a random mount you can ride. It is off as Flat UI comes: tick **Mount key**. Press the key again to dismount or leave the form.

- A druid takes Aquatic Form in water, and Travel Form in a fight, on the move or with no mount.
- A shaman takes Ghost Wolf in a fight or with no mount.
- **Favourite mounts first** (on) picks among the mounts you marked as favourites in the mount journal (right-click a mount there), or among all of them while none of those can be used.
- **Slow Fall or Levitate while falling** (off): for a mage or a priest who knows it, a press while you fall, out of a fight and not mounted, casts Slow Fall or Levitate on you instead.

### Setting the key

Pick **Press a key to set it** under **Key**, out of a fight. The next key you press becomes the Mount key, with Shift, Ctrl or Alt if you hold one. The middle or a side mouse button, or a turn of the wheel over the box that asks, works too. Escape or a left click cancels.

- Chat names the key, and what it did before. That comes back when **Mount key** is off or you pick **Clear Flat UI's key**.
- A key that moves you, such as W or Space, or a turn of the wheel that zooms your camera, is taken only when you press or turn it a second time, a moment later. The box says so first.
- The list line and the box show the key in use now.
- Flat UI keeps the key for your whole account.

You can also bind a key to **Mount or travel form** under **Flat UI** in the game's Key Bindings.

A press that has nothing to use, indoors, in a dungeon or on a character with no mount, says why in chat, at most once every 10 seconds.

## World and cursor

The **World and cursor** page holds aids for the world around you: a glow on herbs, veins and quest objects, a farther camera, a ring round the mouse pointer and a timer for walking through lava.

### World

- **Quest item sparkle** (on) makes quest items in the world sparkle. It sets a game setting that the game's options do not show. Turned off, the game's own value is back from its next start.
- **Sparkle strength** thickens the sparkle by raising the game's particle settings: **As the game has it**, **Strong** or **Strongest** (the default). A higher value of yours stays. More particles can cost frame rate in busy fights.
- **Glow on the nearest object** (on) puts a pulsing glow with twinkling stars on the herb, vein or quest object your Interact Key would use. **Glow colour** is **Gold** (the default) or **By what it is**: herbs green, ore copper, quest objects gold, and loot and chests white. **Glow size** sizes the glow, its ring and its stars together, from 50% to 200%. **Glow sound** plays once as the glow lands on an object, out of a fight; picking one plays it.
- The glow shows only while the game gives that object a nameplate. That needs Enable Interact Key in the game's Controls options and Interact Key Icons at Show All in its Accessibility options. **Turn on what the glow needs** sets both for you, out of a fight, and chat says what changed. Show All also shows the key's icons over enemies.
- **Maximum camera distance** (off) lets the camera zoom out past the farthest the game's own Max Camera Distance allows, and glides it out as you tick it. It is a game setting, the same in every profile. Turned off, the distance you had comes back.

### Cursor

**Cursor ring** draws a ring round the mouse pointer, so you find it at a glance. It is **Off** as Flat UI comes. The choices:

- **Always**.
- **In combat only**: the ring fades in and out with the fight.
- **When you shake the mouse**: no ring until you shake the pointer from side to side. Then it fades in swollen, eases back to its size and fades out about a second later.

The ring takes no clicks and hides while you turn the camera with the mouse. Set its look with **Cursor ring size** and **Cursor ring colour**, or tick **Class colour** to paint it in your class colour.

With **Always** or **In combat only**:

- **Grow when you shake the mouse** (on): a quick side-to-side shake swells the ring for a moment.
- **Cast progress on the ring** (on): your cast or channel runs round the ring, in **Cast progress colour**.
- **Global cooldown on the ring** (on): the global cooldown runs just inside the cast's ring, in **Global cooldown colour**.

Changing these rows out of a fight shows the ring for a moment, and the cast and cooldown rows play a sample cast round it.

### Lava walking

**Lava tick timer** helps you walk or swim through lava. Lava burns you every 2 seconds, and a jump timed so you are in the air as the tick lands takes no damage.

- **In lava zones** (the default) works in Molten Core, Blackrock Depths and Spire, Ragefire Chasm, Searing Gorge, Burning Steppes and Un'Goro Crater. **Anywhere** works everywhere, and **Off** turns it off.
- After a lava tick, a bar under your character counts down to the next one. It turns to **Jump** in **Jump colour** for the last **Jump lead** (400 ms as it comes), with a flash while **Flash when it is time to jump** is on, and a **Jump sound** if you pick one.
- Each tick says **Hit**, and a tick you were in the air for says **Dodged**, then **Dodged x2**, **x3** as the dodges in a row build. From 3 on, a dodge that beats your best of the session reads **Best x7** in gold. The bar goes 5 seconds after the last tick.
- **Lava bar width**, **Lava bar height** and **Lava bar colour** set its look. `/flatui move` places it with the **Lava tick timer** box.

It is an estimate. The game tells addons that fire hit you, not that it was lava, so in a fight it counts only fire hits that keep the 2-second rhythm, and the first tick of each visit always lands. Changing one of its rows out of a fight shows a sample bar for a few seconds.

| Command | What it does |
| --- | --- |
| `/flatui lava` | Says what the timer sees: the place, the ticks seen and dodged, your best streak this session, the last hit on you and the gaps between ticks. |
| `/flatui lava test` | Shows a sample bar for 8 seconds, while **Lava tick timer** is not **Off**. |
| `/flatui lava trace` | Prints a line for each hit on you, so you can check in lava that the game reports its ticks. Type it again to stop. |

Every setting of this group, with its default: [Settings: Helpers](Settings-Helpers).
