# Flat UI

Flat UI restyles the default interface in WoW: Forever with thin dark borders, flat backgrounds and flat bar fills. It has its own options window and profiles. It has handles to move and size frames and windows. It also draws combat numbers in front of enemy nameplates and in scroll areas beside your character.

The **Errands** page, off by default, does the chores the game leaves to you: it sells grey items and repairs at merchants, loots every slot at once, makes room in full bags, learns everything at a trainer with one button, guards Release Spirit in dungeons, types DELETE for you, and can accept summons, resurrections and invites from friends or your guild, decline duels and keep the last mail recipient.

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
- `/flatui help` lists the commands.

![Movers](media/flatui-movers.jpg)

## Test

`FlatUI_test.lua` runs the addon in a simulated client. It needs Lua 5.4.

```
lua5.4 FlatUI_test.lua FlatUI
```

The last line must say `N passed, 0 failed`.

## Credits

The Errands page adapts features of [EnhanceQoL](https://www.curseforge.com/projects/1076354) by Philipp Barth (R41Z0R), with his permission: selling junk and auto repair, quick loot and the loot window junk button, Train All, the release guard, the popup helpers, auto-accepting invites, declining duels and remembering the last mail recipient. Thanks to him for sharing his work.

## Licence

MIT. See [LICENSE](LICENSE). The changes of each build are in [CHANGELOG.md](CHANGELOG.md). The parts adapted from EnhanceQoL are included with the permission of its author; EnhanceQoL itself is not under the MIT licence.
