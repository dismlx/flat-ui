# Notes for the next update push

Written by the Claude Code session on branch `claude/gracious-dijkstra-g7mb7h` (the session that drew the new CurseForge icon), 2026-11-20, for the session that makes Flat UI's release pull requests. Read this before your next update push.

Read it from the branch, fetched fresh each time, since notes for later pushes may be added here:

```bash
git fetch origin claude/gracious-dijkstra-g7mb7h
```

```bash
git show FETCH_HEAD:docs/next-update.md
```

The branch was rewritten on 2026-11-20. It once held the 0.5.4 work, merged long ago as pull request #1. A copy fetched before then has the old logo and no `docs/next-update.md`, so always fetch first and read through `FETCH_HEAD`.

## To do in the next update

1. **Take the new icon into the update.** Two files on this branch, both outside `FlatUI/`:
   - `media/logo.png`: the new icon, 1024 x 1024, replacing the old 512 x 512 logo.
   - `media/logo.svg`: its source (new file).

   Right after the fetch above, from your release branch:

   ```bash
   git checkout FETCH_HEAD -- media/logo.png media/logo.svg
   ```

   This always takes the branch's latest version of both files; a later note here will say if they change again.
   - Only those two paths should change. Commit them on their own, for example "Media: the new CurseForge icon", with your usual attribution lines.
   - Add no CHANGELOG line and no version change, since nothing in game changes (as when 0.5.16 replaced `media/flatui-in-play.jpg`).
   - One line in the release pull request's description is enough, for example "carries the new CurseForge icon (repository only)".
   - Nothing in the repository or the addon reads `media/logo.png`, and `media/` is not part of the addon file. Build the CurseForge upload from `FlatUI/` as usual.

2. **Remind the user to set the CurseForge avatar.** The upload API (`/api/projects/1750813/upload-file`) only uploads addon files; nothing in it sets the project avatar. The user uploads `media/logo.png` themselves on authors.curseforge.com, in Flat UI's project settings. Skip this if the user says it is done.

3. **Once the release pull request carrying the icon is merged into main,** tell the user that [dismlx/flat-ui#30](https://github.com/dismlx/flat-ui/pull/30) can be closed without merging. That is "Media: the new CurseForge icon, and notes for the next update", from this branch, not the old #1 from the same branch name. It only carries these files and this note.

## The icon

- It shows **FUi**: white capital F and U and a small i, on black, over a green health bar (87.5% full) and a blue mana bar (50% full) on grey tracks.
- The user chose each part over several rounds of changes in that session:
  1. the letters FUI instead of a lone F;
  2. a lowercase i;
  3. a black background with white letters;
  4. a smaller i.

  Keep those choices if you touch it.
- Colours:
  - background `#000000`;
  - letters `#ffffff`;
  - health `#2eb84d`, the addon's default health colour (`FlatUI/Config.lua`, `healthColour`);
  - mana `#3f8cf5`;
  - tracks `#3a3d46`.
- Every edge is on a multiple of 32 units of the 1024 viewBox: 1 px at 32 px and 2 px at 64 px, the sizes CurseForge mostly shows. So an area-average shrink to those sizes stays sharp, with only the image's 5 colours; smoother filters soften the edges a little. Strokes are 3 grid cells wide and the margins are 4 cells. Keep any edit on that grid.
- How it was checked:
  - Two fresh readers who were not told the letters read "FUi" with high confidence at 32 and 64 px, next to a control they read correctly.
  - A critic tested changes to the dot gap, bar placement, counter width and a grey edge, and none was better at 32 to 64 px.
  - On a dark page such as #18181c the black square blends in (1.19:1); the letters and bars carry the icon there. The user chose black anyway.
- To render the PNG again after editing the SVG (Playwright, as preinstalled in Claude Code cloud sessions), run from the repository root:

  ```bash
  node -e "const { chromium } = require('playwright'); (async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1024, height: 1024 } }); await p.goto('file://' + process.cwd() + '/media/logo.svg'); await p.screenshot({ path: 'media/logo.png' }); await b.close(); })();"
  ```

  This reproduces the committed image pixel for pixel. The committed file was then re-saved with Pillow's `optimize=True`:

  ```bash
  python3 -c "from PIL import Image; Image.open('media/logo.png').convert('RGB').save('media/logo.png', optimize=True)"
  ```

  With both commands the file comes out byte for byte the same as the committed one.

## Not asked for

- The in-game AddOns list still shows a stock gear: `## IconTexture: Interface\Icons\INV_Misc_Gear_01` in `FlatUI/FlatUI.toc`. That list shows icons very small, where three letters may not read. The user has not asked to change it, so leave it unless they do.
- If they do ask, the same gear is also the Compare gear button's icon (`FlatUI/GearButton.lua:74`, `ICON`), which may well stay a gear. The TOC check in `FlatUI_test.lua` (line 63751, "toc: Panel.lua loads after Reload.lua and Options.lua, with the add-on compartment and icon lines") expects the gear and would need the new path.
