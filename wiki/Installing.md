Flat UI is an add-on for WoW: Forever, client 1.60.1 (build 70938, interface number 16001). This page shows how to get it, put it in place, update it and take it out again.

## What you need

- WoW: Forever on client 1.60.1. Flat UI's interface number is 16001, the number this client uses.
- Nothing else. Flat UI needs no other add-on and no libraries.

## Download

You can get Flat UI from two places. Both hold the same files.

### CurseForge

Download the newest file from Flat UI's CurseForge page: https://www.curseforge.com/projects/1750813

### GitHub releases

Each version is on the releases page: https://github.com/dismlx/flat-ui/releases

Under Assets, download the zip named after the version, such as `FlatUI-0.5.47.zip`. Do not take the "Source code" zip: it holds the whole project, not the add-on folder on its own.

## Put it in place

Do this with the game closed.

1. Open the zip. It holds one folder, `FlatUI`.
2. Copy that folder into the `Interface\AddOns` folder of your WoW: Forever install.
3. Check the path. It must end in `Interface\AddOns\FlatUI`, with `FlatUI.toc` straight inside that folder. A folder named `FlatUI-0.5.47`, or a `FlatUI` folder inside another `FlatUI` folder, does not load.
4. Start the game. At the character list, the **AddOns** button lists **Flat UI**. Make sure it is ticked.
5. Log in and type `/flatui`. The options window opens.

## Your first login

- A new character with no profile is greeted by the welcome screen, with a picture of their own frame and a short setup. See [Getting started](Getting-started).
- A new install does not show **What's new**, since the welcome screen and setup walk you through Flat UI.
- Every setting starts at the settings of the **Jon Default** look, with its frame positions fitted to your screen. See [Profiles](Profiles).

## Updating

1. Close the game.
2. Delete the old `FlatUI` folder from `Interface\AddOns`.
3. Put the new `FlatUI` folder in its place, as above.

Your settings stay. The game saves them outside the add-on folder, so deleting or replacing the folder does not touch them.

After an update, the first login on the account shows **What's new**: what changed in each version since the one you last played. **What's new after an update**, on the **Options and setup** tab of the **Flat UI** page, can make that one line in chat, or nothing. `/flatui new` opens the window at any time.

The full list of changes is in the changelog: https://github.com/dismlx/flat-ui/blob/main/CHANGELOG.md

## Turning it off or taking it out

- To try the game without Flat UI, untick **Flat UI** in the **AddOns** list at the character list.
- To take it out for good, delete the `FlatUI` folder from `Interface\AddOns`.
- To keep Flat UI but drop a part of it, turn that part's switch off in the options window. Each module has its own switch, at the top of its page and on its tile on **Home**.

## Check that it works

Type `/flatui status`. The first lines name the version and the profile in use, as "Flat UI 0.5.47" and "Profile: Default", and a line follows for each part of Flat UI. If something looks wrong, see [Troubleshooting](Troubleshooting).

Next: [Getting started](Getting-started). Every setting, with its default, starts at [Settings: Look](Settings-Look).
