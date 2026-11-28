# Flat UI

Flat UI restyles the default interface of WoW: Forever with flat backgrounds and softly shaded bar fills, borderless by default or with thin dark borders. It has its own options window and profiles, handles to move and size every frame and window, combat numbers in front of enemy nameplates, and helpers for fights, groups, gear and bags.

![Flat UI in a fight: the player and target frames, the enemy's cast bar, combat numbers in front of the nameplate, proc art beside the character and the action bars](media/flatui-in-play.jpg)

**[Download on CurseForge](https://www.curseforge.com/projects/1750813)** · **[Wiki](https://github.com/dismlx/flat-ui/wiki)** · **[Releases](https://github.com/dismlx/flat-ui/releases)** · **[Changelog](CHANGELOG.md)**

For WoW: Forever 1.60.1 (interface 16001).

## What it does

The options window groups its pages the same way as the list below; each group has a guide on the wiki and a page that lists every setting with its default.

- **[Look](https://github.com/dismlx/flat-ui/wiki/Look)**: borders, backgrounds, bar textures, colours, the UI scale and fonts for everything Flat UI styles.
- **[Frames and bars](https://github.com/dismlx/flat-ui/wiki/Frames-and-bars)**: unit frames with portraits, party and raid frames, cast bars with interrupt readiness, the personal resource display and swing timers.
- **[Nameplates](https://github.com/dismlx/flat-ui/wiki/Nameplates)**: flat nameplates with your threat on each enemy, a clear mark on your target, combo points, quest marks and the Overpower window.
- **[Action bars](https://github.com/dismlx/flat-ui/wiki/Action-bars)**: styled buttons, cooldown numbers, proc glows, and bar blocks that line your bars up in one place.
- **[Combat](https://github.com/dismlx/flat-ui/wiki/Combat)**: cooldown icons and pulse, trackers for the buffs and items you must keep up, proc alerts, defensives and absorb shields on you, charges, and enemy cooldowns.
- **[Combat text](https://github.com/dismlx/flat-ui/wiki/Combat-text)**: the game's numbers in front of nameplates and in columns beside your character, warnings, and announcing what you avoid while you tank.
- **[Group](https://github.com/dismlx/flat-ui/wiki/Group)**: party cooldowns, a threat list, your healers' mana, group tools and a ping bar.
- **[Character and gear](https://github.com/dismlx/flat-ui/wiki/Character-and-gear)**: gear comparison with an Overall line, spell tooltips with what your stats give, a hit table and a trinket queue.
- **[HUD](https://github.com/dismlx/flat-ui/wiki/HUD)**: the minimap, buffs and debuffs, quests and loot, messages and timers, experience and reputation bars, and data panels.
- **[Chat and windows](https://github.com/dismlx/flat-ui/wiki/Chat-and-windows)**: chat, tooltips and the game's windows in Flat UI's look, with links to copy and your name in colour.
- **[Bags and items](https://github.com/dismlx/flat-ui/wiki/Bags-and-items)**: one bag window with sections and a search, your bank and other characters away from the banker, and item slots that show more.
- **[Helpers](https://github.com/dismlx/flat-ui/wiki/Helpers)**: errands such as selling, repairs and quests, drink and health macros, a consumables bar, a mount key and aids in the world.
- **[Layout](https://github.com/dismlx/flat-ui/wiki/Layout)**: move and size any frame with `/flatui move`, fading, hidden frames and the tooltip's place.

## Install

1. Download the newest file from [CurseForge](https://www.curseforge.com/projects/1750813) or from the releases of this repository.
2. Put the `FlatUI` folder in the `Interface\AddOns` folder of your WoW: Forever install.
3. Start the game and type `/flatui`.

The [wiki](https://github.com/dismlx/flat-ui/wiki) has a guide to each group of the options window and a list of every setting with its default.

## Getting started

Every setting starts at **Jon Default**, the author's own profile, and a new character is welcomed with a short setup that walks round the screen. These commands get you going; the wiki lists [every command](https://github.com/dismlx/flat-ui/wiki/Commands).

| Command | What it does |
| --- | --- |
| `/flatui` | Opens the options window. |
| `/flatui setup` | Walks round your screen in six short stops and saves what you pick. |
| `/flatui profiles` | Shows the ready-made looks. |
| `/flatui move` | Shows a box for every frame, to move and size it. |
| `/flatui test` | Turns test mode on or off: sample frames while you change options. |
| `/flatui new` | Shows what changed in this version. |
| `/flatui help` | Lists the commands. |

The wiki also covers [getting started](https://github.com/dismlx/flat-ui/wiki/Getting-started), [profiles](https://github.com/dismlx/flat-ui/wiki/Profiles), [test mode](https://github.com/dismlx/flat-ui/wiki/Test-mode) and [troubleshooting](https://github.com/dismlx/flat-ui/wiki/Troubleshooting).

## Development

| Path | What it holds |
| --- | --- |
| `FlatUI/` | The addon: plain Lua 5.1, no libraries. |
| `wiki/` | The wiki, published from `main`. |
| `tools/test/` | `FlatUI_test.lua`, which runs the addon in a simulated client. |
| `tools/dev/` | The code map and the scripts that make the data files and the wiki's settings pages. |
| `extras/Provisions/` | Provisions, a small separate addon of consumable buttons. |
| `media/` | Pictures for this page and CurseForge. |
| `.github/workflows/` | The release and wiki workflows. |

### Run the addon outside the game

`tools/test/FlatUI_test.lua` runs the addon in a simulated client, from the top folder of the repository. It needs Lua 5.4.

```
lua5.4 tools/test/FlatUI_test.lua FlatUI
```

The last line must say `N passed, 0 failed`.

### Code map

`tools/dev/flatui_map.py` builds the code map of Flat UI as one page: each file with its functions, its settings, its calls to other files, and the game's frames, functions, events and CVars it uses. It needs Python 3, Lua 5.4 and git.

```
python3 tools/dev/flatui_map.py --fetch
```

`--fetch` clones Forever's interface source and the client lists of [wowless](https://github.com/wowless/wowless), which name the game's functions, into `tools/dev/sources`, or brings them up to date. The page is `tools/dev/out/flat-ui-map.html`, with its data beside it.

### Spell data

`FlatUI/SpellData.lua` holds the spell values of the spell lines and the gear comparison. `tools/dev/make_spelltips.py` makes it from the inputs in `tools/dev/spelltips`. After a client build or a hotfix, read the client's spell rows again from a new capture of wowsims/forever (`assets/db_inputs/spell_store_inputs.json`, with GrunzForever's export for the few rows it lacks), then make the file:

```
python3 tools/dev/spelltips_import.py spell_store_inputs.json.gz wow_wowf_1.60.1.70888.sqlite
python3 tools/dev/make_spelltips.py
```

It needs Python 3. `make_spelltips.py --check` writes nothing; it lists every value of the inputs the new rows contradict.

### Rotation data

`FlatUI/RotationData.lua` holds the WoWSims rotations the gear comparison's **Overall** line counts: each ability's uses a minute and its share of the damage and threat, for each class and spec, and the share of the main hand's swings Heroic Strike and Maul take. `tools/dev/make_rotations.py` makes it from `tools/dev/rotations/data.json`, the results of the WoWSims Classic simulator's command line run with each spec's presets, and `FlatUI/SpellData.lua`, whose keys it matches the abilities to:

```
python3 tools/dev/make_rotations.py
```

It needs Python 3. `--check` writes nothing; it says whether the file is what the data makes.

### Item index

`FlatUI/ItemIndex.lua` holds the armor and weapons the item finder searches: each item's ID, English name, class and subclass, required level, item level, quality and the classes that may wear it, one string a slot, read only when the finder first searches that slot. `tools/dev/make_itemindex.py` makes it from GrunzForever's export of the client tables (`wow_wowf_1.60.1.70888.sqlite`), leaving out the client's test and placeholder items:

```
python3 tools/dev/make_itemindex.py wow_wowf_1.60.1.70888.sqlite
```

It needs Python 3. `--check` writes nothing; it says whether the file is what the export makes.

### What's new data

`FlatUI/WhatsNewData.lua` holds the newest six versions of `CHANGELOG.md` for the **What's new** window. The newest three versions with notes keep every line; each older one is cut after 40 lines, with a last line that says how many more are in the full changelog. Should the file come to 200000 bytes or more, the oldest versions are cut further first (to 40, then 20, then 10 lines), and the script stops without writing if even that is too much. `tools/dev/make_whatsnew.py` makes it from `CHANGELOG.md`; run it after each change to the changelog:

```
python3 tools/dev/make_whatsnew.py
```

It needs Python 3. `--check` writes nothing; it says whether the file is what `CHANGELOG.md` makes.

### Wiki

The [wiki](https://github.com/dismlx/flat-ui/wiki) is made from the `wiki` folder: a guide for each group of the options window, written by hand, and a settings page for each group that lists every setting with its default. `tools/dev/make_wiki.py` makes the settings pages (`wiki/Settings-*.md`) and the footer from `FlatUI/Config.lua`, `FlatUI/PanelNav.lua`, `FlatUI/PanelTabs.lua` and `FlatUI/FlatUI.toc`; run it after each change to the options:

```
python3 tools/dev/make_wiki.py
```

It needs Python 3 and Lua 5.4. `--check` writes nothing; it says whether the pages are what the options make. A push to `main` that changes the `wiki` folder publishes it to the wiki with `.github/workflows/wiki.yml`, which replaces the whole wiki with the folder.

### Releases

A tag such as `v0.5.49` pushed to the repository, or the **Release** workflow run by hand with a tag and a commit, builds `FlatUI-<version>.zip` from the `FlatUI` folder and publishes a GitHub release with that version's notes from `CHANGELOG.md` (`.github/workflows/release.yml`). The version in `FlatUI/FlatUI.toc` must match the tag.

## Credits

The art of the proc alerts follows what [SpellActivationOverlay](https://github.com/ennvina/spellactivationoverlay) by ennvina shows on WoW: Forever. Each proc has the same piece of the game's own spell alert art in the same place and colour, larger and fainter by default, and art from the side is turned a quarter across the top the same way. SpellActivationOverlay is under the MIT licence, Copyright (c) 2022-2026 ennvina. None of its files are in Flat UI, which draws the game's own art.

The spell power, attack power and threat values of the spell lines and the gear comparison are WoW: Forever's own. They come from the game's client data: the spell rows of build 1.60.1.70938 as [wowsims/forever](https://github.com/wowsims/forever) captured them from the game (MIT licence, Copyright (c) 2022 wowsims team), and a few rows of build 1.60.1.70888 from the client tables exported by [GrunzForever](https://github.com/10igma/GrunzForever) (a tool under the MIT licence). Where the server does what the data does not say, they come from Blizzard's development notes and hotfix posts for WoW: Forever, the in-game measurements of wowsims/forever and, where nothing was measured, the rules of its simulator, the downranking estimate of ForeverChanges, the Forever hunter wiki, gunba's notes on Ice Lance and, for a few spells unmeasured on Forever, Warcraft Tavern's Classic threat guide and Classic's rule for Power Word: Shield as Icy Veins and Wowhead Classic give it. The stat keys and rating sizes were checked against data from Efficient Games (https://efficient.games), licensed under CC BY 4.0. Flat UI holds these facts in a file of its own, made from the game's data; none of these projects' code is in it.

The rotations of the gear comparison's Overall line come from [WoWSims](https://github.com/wowsims/classic), the Classic Era simulator by the wowsims team (MIT licence, Copyright (c) 2024 wowsims team): what its command line gives for each spec's own presets in a three-minute boss fight, the bear's from its Season of Discovery sim ([wowsims/sod](https://github.com/wowsims/sod), the same licence) with no runes and Classic Era items. Flat UI holds those numbers in a file of its own, made from the simulator's results, with WoWSims' licences beside the data in `tools/dev/rotations`; none of WoWSims' code is in it.

The item finder's index of armor and weapons comes from the client tables of build 1.60.1.70888 as [GrunzForever](https://github.com/10igma/GrunzForever) (a tool under the MIT licence) exports them. Flat UI holds the items in a file of its own, made from that export; none of GrunzForever's code is in it.

The threat feedback of the nameplates follows what [Threat Plates](https://www.curseforge.com/wow/addons/tidy-plates-threat-plates) by Suicidal Katt and Blacksalsify does: its threat colours and role detection, its warning glow, border colour and threat transparency, its threat value and its target of the enemy. Threat Plates is under the GNU GPL, so none of its code is in Flat UI; Flat UI does the same things in code of its own.

**Questie's tracker** styles the tracker of [Questie](https://github.com/Questie/Questie), the quest helper by Aero, Logon, Muehe, TheCrux (BreakBB), Drejjmit, Dyaxler, Cheeq, TechnoHunter, Yttrium and its other authors. Questie's team offers it under the GNU GPL 3 (its LICENSE.md): it was read only to learn the names of its tracker's frames and when it draws them again, and when it draws icons on nameplates (not while its nameplate icons are off, nor inside an instance on this game), and none of its code is in Flat UI.

The Bags page follows the way well-known bag addons work: one window with sections and a search, the bank and your other characters away from the banker, and quick handling of junk, the bank and clean up. It is code of Flat UI's own, and no other addon's code is in it.

## Licence

MIT. See [LICENSE](LICENSE). The changes of each build are in [CHANGELOG.md](CHANGELOG.md).
