Flat UI is plain Lua 5.1 for the WoW: Forever client 1.60.1 (interface 16001), with no libraries. The source is at https://github.com/dismlx/flat-ui. This page covers the files made from data, the code map, releases and this wiki. The data sources and their licences are in the README: https://github.com/dismlx/flat-ui/blob/main/README.md.

## Running the addon outside the game

`tools/test/FlatUI_test.lua` runs the addon in a simulated client, from the top folder of the repository. It needs Lua 5.4.

```
lua5.4 tools/test/FlatUI_test.lua FlatUI
```

The last line must say `N passed, 0 failed`.

## Code map

`tools/dev/flatui_map.py` builds the code map of Flat UI as one page: each file with its functions, its settings, its calls to other files, and the game's frames, functions, events and CVars it uses. It needs Python 3, Lua 5.4 and git.

```
python3 tools/dev/flatui_map.py --fetch
```

`--fetch` clones the game's interface source and the client lists that name the game's functions into `tools/dev/sources`, or brings them up to date. The page is `tools/dev/out/flat-ui-map.html`, with its data beside it.

## Files made from data

Each of these files is made by a script in `tools/dev`, and each script takes `--check`, which writes nothing and says whether the file is what its inputs make. They need Python 3.

| File | Script | Made from |
| --- | --- | --- |
| `FlatUI/SpellData.lua` | `make_spelltips.py` | The client's spell rows in `tools/dev/spelltips`, read again with `spelltips_import.py` after a client build or a hotfix. `--check` lists every value the new rows contradict. |
| `FlatUI/RotationData.lua` | `make_rotations.py` | The simulated rotations in `tools/dev/rotations/data.json` and the keys of `FlatUI/SpellData.lua`. The gear comparison's **Overall** line counts them. |
| `FlatUI/ItemIndex.lua` | `make_itemindex.py` | An export of the client's item tables. The item finder searches it. |
| `FlatUI/WhatsNewData.lua` | `make_whatsnew.py` | The newest six versions of `CHANGELOG.md`, for the **What's new** window. Run it after each change to the changelog. |

```
python3 tools/dev/spelltips_import.py spell_store_inputs.json.gz wow_wowf_1.60.1.70888.sqlite
python3 tools/dev/make_spelltips.py
python3 tools/dev/make_rotations.py
python3 tools/dev/make_itemindex.py wow_wowf_1.60.1.70888.sqlite
python3 tools/dev/make_whatsnew.py
```

## This wiki

The wiki is made from the `wiki` folder of the repository. The guide pages are written by hand. The settings pages (`wiki/Settings-*.md`) and the footer are made by `tools/dev/make_wiki.py` from `FlatUI/Config.lua`, `FlatUI/PanelNav.lua`, `FlatUI/PanelTabs.lua` and `FlatUI/FlatUI.toc`. Run it after each change to the options. It needs Python 3 and Lua 5.4.

```
python3 tools/dev/make_wiki.py
```

`--check` writes nothing; it says whether the pages are what the options make. A push to `main` that changes the `wiki` folder publishes it to the wiki (`.github/workflows/wiki.yml`), and the workflow can also be run by hand from the Actions tab. Each publish replaces the whole wiki with the folder, so change pages in the repository: an edit made on the wiki itself is gone at the next publish.

## Releases

A tag such as `v0.5.47` pushed to the repository, or the **Release** workflow run by hand with a tag and a commit, builds `FlatUI-<version>.zip` from the `FlatUI` folder and publishes a GitHub release with that version's notes from `CHANGELOG.md` (`.github/workflows/release.yml`). The version in `FlatUI/FlatUI.toc` must match the tag.

Every setting, with its default: start at [Settings: Look](Settings-Look), or see the full list on [Home](Home).
