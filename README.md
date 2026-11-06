# Flat UI

Flat UI restyles the default interface in WoW: Forever with thin dark borders, flat backgrounds and flat bar fills. It has its own options window and profiles. It has handles to move and size frames and windows. It also draws combat numbers in front of enemy nameplates and in scroll areas beside your character.

The **Errands** page, off by default, does the chores the game leaves to you: it sells grey items and repairs at merchants, loots every slot at once, makes room in full bags, learns everything at a trainer with one button, guards Release Spirit in dungeons, types DELETE for you, and can accept summons, resurrections and invites from friends or your guild, decline duels and keep the last mail recipient. Its **Levelling** tab accepts and hands in quests, picks gossip options, offers the new ranks of your spells for your action bars, shows the reputation you gain, reminds you of talent points and adds /way.

The **Data panels** page, off by default, adds a top and a bottom panel with bag space, gold across your characters, durability, your hearthstone, coordinates, frame rate and latency, and friends and guild online.

In the chat windows, a web address becomes a link that opens a box to copy it, and an item, spell or achievement link shows its tooltip while the mouse is over it. The **Tooltips** tab names what a unit targets, colours a player's class line and puts icons before item and spell names; with IDs on it shows the ID of the poison, oil or stone on your weapon, and **Show IDs** can wait for Shift, Ctrl or Alt.

![Flat UI in play](media/flatui-in-play.jpg)

## Install

1. Download the newest file from [CurseForge](https://www.curseforge.com/projects/1750813) or from the releases of this repository.
2. Put the `FlatUI` folder in the `Interface\AddOns` folder of your WoW: Forever install.
3. Start the game and type `/flatui`.

## Commands

- `/flatui` opens the settings window.
- `/flatui setup` sets up a new profile step by step.
- `/flatui move` shows a box for every frame. Drag a box to move its frame.
- `/flatui status` says what is styled, and any error.
- `/flatui sell <item>` always sells an item at merchants (an item link or ID). Type it again to stop. `/flatui sell` alone lists the items.
- `/flatui keep <item>` never sells a grey item, and Make room never deletes it.
- `/flatui train` learns everything you can pay for at an open trainer, like the Train all button.
- `/flatui npc` skips the NPC you talk to or target: its quests and gossip are left to you. Type it again to stop.
- `/flatui gossip` lists the options of the NPC you talk to. `/flatui gossip 2` picks the second option for you from now on.
- `/flatui uprank` offers the new ranks of your spells for your action bars.
- `/flatui rank <spell>` keeps that rank where it is on your bars (a spell link or ID).
- `/way 45 61` puts a pin on your map and the game points you to it; `/way Elwynn Forest 45 61` for another zone, `/way clear` to take it off. `/flatui way` does the same when another addon has `/way`.
- `/flatui xp` says your experience per hour, time to level and kills and quests to level. `/flatui xp reset` starts counting again.
- `/flatui help` lists the commands.

![Movers](media/flatui-movers.jpg)

## Test

`FlatUI_test.lua` runs the addon in a simulated client. It needs Lua 5.4.

```
lua5.4 FlatUI_test.lua FlatUI
```

The last line must say `N passed, 0 failed`.

## Credits

The Errands page, the levelling stats of the experience bar, the cast bar's spell rank, the ammunition and durability checks, the text around the minimap, the data panels, the character and inspect overlays, the links in chat and the tooltip extras adapt features of [EnhanceQoL](https://www.curseforge.com/projects/1076354) by Philipp Barth (R41Z0R), with his permission: selling junk and auto repair, quick loot and the loot window junk button, Train All, the release guard, the popup helpers, auto-accepting invites, declining duels, remembering the last mail recipient, accepting and handing in quests, gossip options, the NPC exclude list, the quest count on the tracker, the spell rank upgrade, the learned-spell chat filter, watching the reputation you gain (on Flat UI's own bar), the /way command, the unspent talent reminder, the experience bar's quest stretch, experience per hour and time to level, the spell rank on the cast bar, the thrown weapons and the fitting ammunition of the ammunition tracker, the coordinates, durability, frame rate and time around the minimap, the durability tracker, the data panels, the item levels of the equipment flyout and the Inspect window with the inspected player's average, the durability on the Character window, the clickable web addresses with their copy box and the tooltips of links in the chat windows, and the tooltip's target line, class line colour, icons, temporary enchant ID and IDs on a key. Thanks to him for sharing his work.

## Licence

MIT. See [LICENSE](LICENSE). The changes of each build are in [CHANGELOG.md](CHANGELOG.md). The parts adapted from EnhanceQoL are included with the permission of its author; EnhanceQoL itself is not under the MIT licence.
