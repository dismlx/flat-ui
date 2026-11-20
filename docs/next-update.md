# Notes for the next update push

Written by the Claude Code session on branch `claude/gracious-dijkstra-g7mb7h` (the session that drew the new CurseForge icon), 2026-11-20. Read this before your next update push. New notes for later pushes may be added to this file on the same branch, so fetch it again before each push.

## To do in the next update

1. **Take the new icon into the update.** Two files on this branch, both outside `FlatUI/`, so the addon itself does not change:
   - `media/logo.png`: the new icon, 1024 x 1024, replacing the old 512 x 512 logo.
   - `media/logo.svg`: its source (new file).

   From your release branch:

   ```bash
   git fetch origin claude/gracious-dijkstra-g7mb7h
   ```

   ```bash
   git checkout FETCH_HEAD -- media/logo.png media/logo.svg
   ```

   Commit them with the update. No CHANGELOG line is needed, since nothing in game changes. Nothing in the repository or the addon reads `media/logo.png`; it is only the file for the CurseForge page.

2. **Remind the user to set the CurseForge avatar.** The upload API (`/api/projects/1750813/upload-file`) only uploads addon files; nothing in it sets the project avatar. The user uploads `media/logo.png` themselves on authors.curseforge.com, in Flat UI's project settings. Skip this if the user says it is done.

3. **When the icon is in a release,** tell the user that this branch's pull request can be closed: it only carries these files and this note.

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
- Every edge is on a multiple of 32 units of the 1024 viewBox. That is 1 px at 32 px and 2 px at 64 px, the sizes CurseForge mostly shows, so the icon is pixel-exact there. Strokes are 3 grid cells wide and the margins are 4 cells. Keep any edit on that grid.
- How it was checked:
  - Two fresh readers who were not told the letters read "FUi" with high confidence at 32 and 64 px, next to a control they read correctly.
  - A critic tested changes to the dot gap, bar placement, counter width and a grey edge, and none was better at 32 to 64 px.
  - On CurseForge's dark theme the black square blends into the page (1.19:1 against #18181c); the letters and bars carry the icon there. The user chose black anyway.
- To render the PNG again after editing the SVG (Playwright, as preinstalled in Claude Code cloud sessions), run from the repository root:

  ```bash
  node -e "const { chromium } = require('playwright'); (async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1024, height: 1024 } }); await p.goto('file://' + process.cwd() + '/media/logo.svg'); await p.screenshot({ path: 'media/logo.png' }); await b.close(); })();"
  ```

  This reproduces the committed `media/logo.png` pixel for pixel.

## Not asked for

- The in-game AddOns list still shows a stock gear: `## IconTexture: Interface\Icons\INV_Misc_Gear_01` in `FlatUI/FlatUI.toc`. That list shows icons very small, where three letters may not read. The user has not asked to change it, so leave it unless they do.
