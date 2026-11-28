Every setting of the **Helpers** group of the options window, 101 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Helpers](Helpers).

Pages: [Errands](#errands) · [Drink and health macros](#drink-and-health-macros) · [Consumables bar](#consumables-bar) · [Mount key](#mount-key) · [World and cursor](#world-and-cursor)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.52.

## Errands

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Run errands** | On | Each errand below and on the Popups and invites and Quests and levelling tabs has its own row. Selling, repairs, Make room, Train all, summons, invites, new spell ranks and talent reminders wait for the end of a fight. |
| **Say what was done** | On | A line in chat after selling, repairing, training, deleting, accepting, declining and upranking, and when a quest is left to you. Also after Sell junk, Deposit and Take out of the Bags page, whatever the switch of Errands. |

**Merchant**

| Setting | Default | Notes |
| --- | --- | --- |
| **Sell grey items** | On | When a merchant opens. Hold Shift as it opens to keep them that time, and chat says how many it kept. /flatui sell and /flatui keep choose other items to sell or keep. |
| **Sell at most 12 at a time** | On | Grey items are sold in one go. Items of your sell list that are not grey come after them, at most 12 at a time, so the merchant's buyback still holds them; Sell next 12 sells the next ones. The Sell junk button of the Bags page follows it too, whatever the switch of Errands. Needs **Sell grey items** on. |
| **Items always sold** |  | /flatui sell and an item adds one. |
| **Items never sold** |  | /flatui keep and an item adds one. Make room never deletes them either. |
| **Repair** | With your gold | When a merchant who repairs opens. With items sold too, one chat line says both. Choices: Off, With your gold, Guild gold first. |
| **Guild gold where** | Everywhere | Elsewhere the repair is paid with your own gold. Choices: Everywhere, In a group or an instance, In dungeons, raids and battlegrounds, In raids. Needs **Repair** at Guild gold first. |
| **Buy in bulk** | Off | Shift-click an item at a merchant: beside the game's box, Stack buys a full stack and Most as many as your gold, the merchant's stock and your bags allow, a stack at a time. Both ask first, and the game's box stays open. Not for items bought with tokens. |
| **Buy with tokens without asking** | Off | Answers Yes when the game asks before it takes items or currency for a purchase. One that also costs 150 gold or more is left to you. |
| **Sell loot still tradeable without asking** | Off | Answers Okay when the game asks before you sell an item you could still trade to your group. |

**Loot and trainers**

| Setting | Default | Notes |
| --- | --- | --- |
| **Quick loot** | On | When the game loots by itself (Auto Loot, or its key held), every slot is taken at once. Rolls still ask. |
| **Make room in full bags** | On | A button under the loot window deletes the cheapest grey item while every bag is full. It names the item first, as Delete Broken Fang x3. |
| **Train all button** | On | On the trainer window: learns everything the trainer offers that you can pay for, and says how many, as Train all (4). A profession is left to Train, which asks first. /flatui train does the same. |

### Popups and invites

**Death and popups**

| Setting | Default | Notes |
| --- | --- | --- |
| **Hold a key to release** | In dungeons and raids | Release Spirit is covered until you hold the key, so a stray click does not send you to the graveyard. The game's own timer still releases you. Choices: Off, In dungeons and raids, Everywhere. |
| **Key to hold** | Shift | Choices: Shift, Ctrl, Alt. Needs **Hold a key to release** at In dungeons and raids or Everywhere. |
| **Release at once in battlegrounds** | Off | Half a second after you die in a battleground your spirit goes to the graveyard, in time for the spirit healer's next wave, and chat says so. Not while a soulstone, Reincarnation or another way back is offered, and never in an arena, the open world or a dungeon. Hold a key to release does not hold it back. |
| **Accept summons** | Off | When the game would let you take it: not in a fight, and not on a flight path. |
| **Accept resurrections** | On | Not while the one who offers it is in combat or dead, and only once the game lets you after recent deaths. |
| **Type DELETE for you** | On | Writes the word the game asks for before it deletes a good item. You still click Yes. |

**Other players**

| Setting | Default | Notes |
| --- | --- | --- |
| **Accept group invites from** | Friends and your guild | Battle.net friends count as friends. An invite that comes in a fight is accepted when the fight ends. One that asks for roles, or would take you out of a queue, is left to you. Choices: Nobody, Friends, Your guild, Friends and your guild. |
| **Decline duels** | Off | Every duel request is declined at once, also in a fight. |
| **Remember the last mail recipient** | On | After a letter goes, the To box keeps the name until the mailbox closes. |

### Quests and levelling

**Quests**

| Setting | Default | Notes |
| --- | --- | --- |
| **Accept quests** | On | When an NPC offers one, or your group shares one. A quest that would flag you for PvP, and an escort a group member starts, still ask you. |
| **Hand in finished quests** | On | Takes the reward when there is only one; with a choice, the window stays open for you. A quest that takes money, or an item of green quality or better, is left to you. |
| **Mark the reward worth most** | On | With a choice of rewards, a small gold coin on the item's icon marks the one a merchant pays most for as the window opens, and its tooltip says how much. You still choose. |
| **Low-level quests too** | Off | Off: a grey quest is left to you, so the places in your quest log go to quests worth the time. Needs **Accept quests** on. |
| **Repeatable quests too** | Off | Off: a quest you can do again and again, such as a cloth or reputation hand-in, is left to you, so nothing you may want to keep is given away. |
| **Key to do it yourself** | Shift | Hold it as you talk to an NPC, and that NPC's quests and gossip are left to you until you walk away. Choices: Shift, Ctrl, Alt. |
| **Skipped NPCs** |  | Their quests and gossip are always left to you. /flatui npc skips the NPC you talk to or target. |

**Gossip**

| Setting | Default | Notes |
| --- | --- | --- |
| **Gossip options** | Saved, quest and only options | Saved options are picked everywhere. In the open world, the one option marked (Quest), or an NPC's only option when it has no quest for you, is picked too. An option that casts a spell is never picked. Choices: Off, Saved options only, Saved, quest and only options. |
| **Saved gossip options** |  | /flatui gossip lists the options of the NPC you talk to, and /flatui gossip 2 saves the second one. |

**Spell ranks**

| Setting | Default | Notes |
| --- | --- | --- |
| **Put new ranks on your bars** | On | After training, a line at the top of the screen offers it. Its button reloads the interface in the same click, which keeps the game's bars clean. Macros, items, the ranks you keep and a lower rank beside a higher one of the same spell stay as they are. |
| **Keep a rank on your bars** |  | That rank stays where it is. The other ranks of the spell are still replaced. /flatui rank and a spell link does the same. Needs **Put new ranks on your bars** on. |
| **Stop keeping a rank** |  | Needs **Put new ranks on your bars** on. |
| **Uprank your bars now** |  | Shows the line and its button now. /flatui uprank does the same. Needs **Put new ranks on your bars** on. |
| **Lines about learned spells** | One line in their place | The game's lines that start with You have learned or You have unlearned. One line in their place names what was learned, a moment after the last; with Say what was done off, the game's lines stay. Choices: As the game has it, Hidden, One line in their place. |

**Reputation and talents**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the reputation you gain** | On | Flat UI's experience bar shows the faction you last gained reputation with. Exalted and inactive factions are passed over, and a faction you pick in the game's reputation window shows until your next gain. The faction the game watches is not changed. |
| **Remind you of talent points** | On | When you reach a level, or log in, with talent points to spend, a line in chat says how many, also with Say what was done off. A level reached in a fight is told when it ends. |

**Waypoints**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add the /way command** | On | /way 45 61 puts a pin on your map there and the game points you to it. /way Elwynn Forest 45 61, /way #1429 45 61 and /way clear work too. When another addon has /way it keeps it, and /flatui way does the same. |
| **Clear a waypoint as you reach it** | On | A pin /way set comes off as you arrive, with a chime and a line in chat. It needs In-game navigation, which tells Flat UI you are there. A pin you put on the map yourself stays. Needs **Add the /way command** on. |
| **In-game navigation** | On | A marker over the quest or map pin you track, with its distance, and an arrow at the edge of the screen while it is out of view, as the game's own option shows it in later expansions. Sets a game setting that Forever's options do not show. Turned off with /console showInGameNavigation 0, it stays off until you change this row. Turned off here, the game's own value is back. |

## Drink and health macros

| Setting | Default | Notes |
| --- | --- | --- |
| **Keep drink and health macros** | On | Two macros in your account's macro list, Flat UI Drink and Flat UI Health, written again out of combat when your bags or your level change. Put a macro on your cursor hands one to you for an action bar. Turned off, they are deleted, but one still on a bar stays until you drag it off. |
| **Say when a macro changes** | On | A line in chat when a macro moves to a better drink, food, potion or healthstone, or has none left. Not at login, and not for a row you change here. Also once when you are down to 5 drinks, or 5 foods while Flat UI Health eats, and again after you restock above 5. |
| **Put a macro on your cursor** |  | Picks up Flat UI Drink or Flat UI Health, so a click on an action button puts it there. Out of a fight. The game's macro window (/macro) has them too. |

**Drink**

| Setting | Default | Notes |
| --- | --- | --- |
| **Drink macro** | On | Flat UI Drink drinks the best drink in your bags that your level allows, conjured water first. A character without mana leaves it as it is. |
| **Mana potion in a fight** | On | In a fight, where you cannot drink, Flat UI Drink takes your best mana potion. Needs **Drink macro** on. |
| **Mana gem first in a fight** | On | For a mage: in a fight Flat UI Drink takes your best mana gem, then your best mana potion at the next press, and starts with the gem again after the fight. A gem still cooling waits behind a potion that is ready. Needs **Drink macro** on. |

**Health**

| Setting | Default | Notes |
| --- | --- | --- |
| **Health macro** | On | Flat UI Health takes a healthstone, then at the next press your best healing potion, and starts with the healthstone again after the fight. |
| **Eat out of combat** | On | Out of combat Flat UI Health eats the best food in your bags that your level allows, conjured food first. Needs **Health macro** on. |

## Consumables bar

| Setting | Default | Notes |
| --- | --- | --- |
| **Show the consumables bar** | Off | A bar of buttons for your consumables: a click uses the item from whichever bag holds it, also in a fight. Each shows how many you carry, its cooldown and its tooltip, with the time left while it cools down, and an elixir, flask or scroll whose buff is on you has a green border and its minutes left. The first six have keys under Flat UI in the game's Key Bindings. /flatui move places it. |

**Buttons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Buttons** | Every consumable in your bags | Every consumable in your bags: one button for each item, never from the bank, in the order of the Bags page at Each kind, then by name; Kinds in your bags leaves kinds out. Your list: only the items you chose, in your order. Your list, then the rest: your list first, then the other consumables of your bags. Choices: Every consumable in your bags, Your list, Your list, then the rest. |
| **An item of your list with none left** | Show it greyed with 0 | It stays on the bar, so its button keeps its place. A click on it says in chat that your bags hold none. Choices: Show it greyed with 0, Leave a gap. Needs **Buttons** at Your list or Your list, then the rest. |
| **Show count** | On | How many you carry across your bags. A stack of one shows no number, but on a button of your list; 3 or fewer shows amber, and none a red 0. |

**Your list**

| Setting | Default | Notes |
| --- | --- | --- |
| **Add an item** |  | The consumables in your bags that are not on your list, then the other items there with a use that you cannot wear, such as the Hearthstone. Or drop one on the bar out of a fight: on a button of your list it goes in that place, and while Buttons shows your list, a + at the end of the bar takes the item you hold. At most 24, kept for this character. |
| **Take an item off** |  | Shift+right-click on its button does the same. Shift+right-click on another button puts it on your list. |
| **Move an item left** |  | One place earlier on the bar: further left while it grows right. |
| **Move an item right** |  | One place later on the bar. |

**Kinds in your bags**

| Setting | Default | Notes |
| --- | --- | --- |
| **Food and drink** | On |  |
| **Potions** | On |  |
| **Elixirs and flasks** | On |  |
| **Scrolls** | On |  |
| **Bandages** | On |  |
| **Enhancements** | On | Oils, sharpening stones, weightstones and the like. A click puts an oil or a stone on your main hand, and a right-click on a weapon in your off hand. |
| **Explosives and devices** | On |  |
| **Other consumables** | On | Healthstones, mana gems and the rest. They come first on the bar. |

**Layout**

| Setting | Default | Notes |
| --- | --- | --- |
| **Button size** | 36 px |  |
| **Buttons per row** | 12 | Per column while the bar grows up or down. |
| **Spacing** | 2 px |  |
| **Grow** | Right | Which way the buttons go from the corner of the bar's box in /flatui move. Rows stack upward while it grows right or left; columns go right while it grows up or down. Choices: Right, Left, Up, Down. |
| **Fade out of a fight** | Off | Out of a fight the buttons stay at Faded opacity, full while the mouse is over the bar, also in the gaps between buttons, in a fight and while /flatui move or Edit Mode is open. They ease up in a tenth of a second and settle back over 0.3 s, and still take clicks and keys. |
| **Faded opacity** | 40% | Needs **Fade out of a fight** on. |

## Mount key

| Setting | Default | Notes |
| --- | --- | --- |
| **Mount key** | Off | Set its key in Key below, or bind one to Mount or travel form under Flat UI in the game's Key Bindings. It mounts a random mount you can ride; a druid takes Aquatic Form in water, and Travel Form in a fight, on the move or with no mount; a shaman takes Ghost Wolf in a fight or with no mount. Pressed again, it dismounts or leaves the form. |
| **Key** |  | Press a key to set it: the next key you press, with Shift, Ctrl or Alt if you hold one, becomes the Mount key; so does the middle or a side mouse button, or the wheel, over the box that asks. Escape or a left click cancels. A key that moves you, such as W or Space, or a turn of the wheel that zooms your camera, is taken only when you press or turn it a second time, a moment later. What that key did before comes back when Mount key is off or the key is cleared. The line and the box show the key in use now. Not in a fight. |
| **Favourite mounts first** | On | Picks among the mounts you marked as favourites in the mount journal (right-click a mount there), or among all of them while none of those can be used. |
| **Slow Fall or Levitate while falling** | Off | For a mage or a priest who knows it: pressed while you fall and are not mounted, the key casts Slow Fall or Levitate on you instead. Not in a fight. |

## World and cursor

**World**

| Setting | Default | Notes |
| --- | --- | --- |
| **Quest item sparkle** | On | Quest items in the world sparkle. Sets a game setting that the game's options do not show. Turned off, the game's own value is back from its next start. |
| **Sparkle strength** | Strongest | Thickens the sparkle by raising the game's Particle Density, and its Spell Density where the game has one, raid settings too: Strong to High and Reduced, Strongest to Ultra and Everything. A higher value of yours stays. More particles can cost frame rate in busy fights. As the game has it, or Quest item sparkle off, puts your own values back. Choices: As the game has it, Strong, Strongest. Needs **Quest item sparkle** on. |
| **Glow on the nearest object** | On | A pulsing glow, gold or by what it is, with twinkling stars on the herb, vein or quest object your Interact Key would use. It shows only while the game gives that object a nameplate: Enable Interact Key in the game's Controls options and Interact Key Icons at Show All in Accessibility. Turn on what the glow needs sets both. In a fight, a new object gets it once the fight ends. Needs **Quest item sparkle** on. |
| **Glow colour** | Gold | By what it is: herbs glow green, ore copper, quest objects gold, and loot and chests white, so you tell nodes apart at a glance. Picking one out of a fight, with nothing glowing near you, shows the glow for 3 seconds above the middle of the screen, By what it is stepping through the four colours. Choices: Gold, By what it is. Needs **Glow on the nearest object** on. |
| **Glow size** | 100% | Sizes the glow, its ring and its stars together, at once on an object that glows now. With nothing glowing near you, a change out of a fight shows the glow at its new size for 3 seconds above the middle of the screen. A change in a fight waits for its end. Needs **Glow on the nearest object** on. |
| **Glow sound** | None | Plays once as the glow lands on an object, out of a fight and at most once every 2 seconds, so a herb or vein that comes into reach rings softly. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Glow on the nearest object** on. |
| **Turn on what the glow needs** |  | Ticks the game's Enable Interact Key and sets its Interact Key Icons to Show All, out of a fight, so herbs, veins and quest objects get the nameplate the glow sits on. Show All also shows the key's icons over enemies. A line in chat says what changed. Needs **Glow on the nearest object** on. |
| **Maximum camera distance** | Off | The camera zooms out to 2.6, past the 2.0 that the game's Max Camera Distance allows, and glides out there as you tick it. A game setting, the same in every profile. Turned off, the distance you had is back. Ticked in a fight, it changes and glides out as the fight ends, and chat says so. |

**Cursor**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cursor ring** | Off | A ring around the mouse pointer, so you find it at a glance. It takes no clicks, hides while you turn the camera with the mouse, and in combat only fades in and out with the fight. When you shake the mouse shows no ring until you shake the pointer from side to side: then it fades in swollen, eases back to its size and fades out about a second later. Changing the ring here out of a fight shows it for a moment. Choices: Always, In combat only, When you shake the mouse, Off. |
| **Cursor ring size** | 32 | Needs **Cursor ring** at Always or In combat only or When you shake the mouse. |
| **Class colour** | Off | Paints the ring in your class colour in place of Cursor ring colour, which greys out while it is on. Needs **Cursor ring** at Always or In combat only or When you shake the mouse. |
| **Cursor ring colour** | #B991E4 | Needs **Class colour** at False. |
| **Grow when you shake the mouse** | On | A quick side-to-side shake of the mouse swells the ring to two and a half times its size, and it eases back over half a second, so you find the pointer at once. Needs **Cursor ring** at Always or In combat only. |
| **Cast progress on the ring** | On | Your cast or channel runs round the ring. Ticking it here out of a fight plays a sample cast. Needs **Cursor ring** at Always or In combat only. |
| **Cast progress colour** | #33B6E6 | Changing it here out of a fight plays a sample cast round the ring, with the global cooldown inside. Needs **Cast progress on the ring** on. |
| **Global cooldown on the ring** | On | Just inside the cast's ring. Needs **Cursor ring** at Always or In combat only. |
| **Global cooldown colour** | #FFFFFF | Changing it here out of a fight plays a sample global cooldown inside the ring, with a cast round it. Needs **Global cooldown on the ring** on. |

**Lava walking**

| Setting | Default | Notes |
| --- | --- | --- |
| **Lava tick timer** | In lava zones | After a lava tick, a bar counts down to the next one and marks when to be in the air. In lava zones: Molten Core, Blackrock Depths and Spire, Ragefire Chasm, Searing Gorge, Burning Steppes and Un'Goro Crater. It times the fire hits on you, an estimate, since the game does not tell add-ons that a hit is lava. Changing these rows out of a fight shows a sample bar for a few seconds. /flatui move places it, /flatui lava shows what it sees. Choices: In lava zones, Anywhere, Off. |
| **Lava bar width** | 160 px | Needs **Lava tick timer** at In lava zones or Anywhere. |
| **Lava bar height** | 14 px | Also the height of text. Needs **Lava tick timer** at In lava zones or Anywhere. |
| **Jump lead** | 400 ms | How long before the tick the bar says Jump. A jump keeps you in the air for about 0.8 s, so 400 puts the tick near its top. Needs **Lava tick timer** at In lava zones or Anywhere. |
| **Flash when it is time to jump** | On | Needs **Lava tick timer** at In lava zones or Anywhere. |
| **Jump sound** | None | Once a tick, as the bar says Jump. Picking one plays it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Lava tick timer** at In lava zones or Anywhere. |
| **Lava bar colour** | #E6732E | Needs **Lava tick timer** at In lava zones or Anywhere. |
| **Jump colour** | #33D959 | The fill in the jump window, the mark where it starts and the flash. Needs **Lava tick timer** at In lava zones or Anywhere. |
