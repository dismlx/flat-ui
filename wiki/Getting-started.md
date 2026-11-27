This page walks you through your first minutes with Flat UI: the welcome screen, the short setup, the options window and its Home page, the reload notice and the **What's new** window. It ends with the **Options and setup** tab, where you choose how the window and the setup behave.

![Flat UI in a fight: the player and target frames, the enemy's cast bar, combat numbers in front of the nameplate, proc art and the action bars](https://raw.githubusercontent.com/dismlx/flat-ui/main/media/flatui-in-play.jpg)

## The welcome screen

A new character with no profile of their own is greeted by the welcome screen. It shows a picture of their own frame as Flat UI draws it now, and three buttons:

- **Set up my screen** starts Flat UI setup, the short walk round your screen described below.
- **Ready-made looks** shows finished profiles side by side. A click puts one in use. See [Profiles](Profiles).
- **Keep this look** closes the screen and keeps the Default profile. With **Keep this look uses** at **The game's look**, the button reads **Use the game's look** instead, and it puts in use a profile named Game look with every Flat UI module off.

At the bottom, **Do not show on new characters** is a tick box. Tick it before you choose, and later new characters start on the Default profile without this screen.

Some things to know:

- **Close** at the top right closes the screen without choosing anything, as Escape does. `/flatui welcome` opens it again at any time.
- Drag the screen by its title row to move it. It opens at the top of the screen again next time.
- A fight hides the welcome screen, the ready-made looks and the card after setup. Chat says so, and they come back on the same view when the fight ends.
- **Welcome screen shows**, on the **Options and setup** tab, picks when it appears: **New character with no profile** (the default) or **First login on the account**.

## Flat UI setup

Setup walks round your screen in six short stops and saves what you pick. It takes about two minutes. Nothing changes until you press **Finish**, and every setting it touches stays in the options window afterwards.

Open it with `/flatui setup`, with **Flat UI setup** at the top of the options window's sidebar, or with **Set up my screen** on the welcome screen, on Home or on the **Profiles** page. Setup opens inside the options window.

### The six stops

| Stop | What you pick |
| --- | --- |
| Your character | Your frame (the frame you pick goes on every unit frame), its picture, and the borders and bars |
| Your target and party | What their health bars say: for damage, for tanking, for healing, or as the game has it |
| Your action bars | How the buttons look: flat, flat and quiet, round icons, or the game's buttons |
| Enemies' nameplates | How much the bars over enemies show: plain, taller with cast times, or small and quiet |
| Chat | How much the chat window stands out: dark, light, solid or no panel |
| Helpers | Ticks for class trackers, errands, data panels, the threat list, healer mana, group tools, the mount key and the drink and health macros |

Each stop draws its choices side by side as cards, and a small map shows where on the screen that part sits. A card marked **Now** matches what you have. A card marked **Suggested** fits your role, screen or level, for example **Errands** while you are levelling.

### Moving through setup

- **Next** goes to the next stop, and **Back** to the one before.
- **More settings** opens the pages of settings that belong to the stop, each with a drawing that follows your choices.
- **Skip the rest** jumps to the last screen.

### Your screen and Finish

The last screen, **Your screen**, sums up each stop and lists what else will happen: settings you changed under **More settings**, actions such as adding class trackers (each with its own **Undo**), game settings that are the same in every profile, and any change that needs a reload.

Where your choices go:

- On the Default profile, **Finish** makes a profile of your own under the **Profile name** you type. Default stays as it is for other characters.
- On another profile, **Finish** saves into that profile. Tick **Save as a new profile** to make a new one instead.

**Start over** drops every choice made in setup. It asks first, and its answer button is red and waits for a click, so Enter cannot answer it by mistake. **Finish** does nothing in a fight: press it after.

### After Finish

A card, "Your screen is set", says where your choices went. Its buttons depend on what happened:

- **Undo setup** puts the profile back as it was before setup, after a save into the profile in use. It works until you reload, as **Bring back** on the **Profiles** page does. Game settings that setup changed stay as they are.
- **Back to** puts the profile you had back in use, after a **Finish** that made a new profile.
- **Reload** shows when a choice needs a reload.
- **Move frames**, **Options** and **Done** open `/flatui move`, open the options window, or close the card.

**Setup result in chat**, on the **Options and setup** tab, decides whether chat gets one line saying which profile is in use when setup finishes.

### Leaving setup before the end

Closing setup asks whether to **Keep choices** or **Discard choices**. Kept choices wait for you: at login chat says "Flat UI setup is not finished. /flatui setup continues it.", and the **Setup** row of the **Profiles** page reads **Continue setup**.

## The options window

Type `/flatui` to open or close the options window. You can also use the **Flat UI** button in the game menu (see **Game menu** below), or the **Open Flat UI** button on Flat UI's page in the game's own options (`/flatui options` opens that page).

If you have not opened the window since you logged in, a `/flatui` typed in a fight opens it as the fight ends.

### The sidebar

The sidebar at the left lists **Home**, **Flat UI setup**, **Profiles** and **Move frames**, then the pages in eleven groups, by what they set:

| Group | Guide |
| --- | --- |
| **Look** | [Look](Look) |
| **Frames and bars** | [Frames and bars](Frames-and-bars), [Nameplates](Nameplates) |
| **Action bars** | [Action bars](Action-bars) |
| **Combat** | [Combat](Combat), [Combat text](Combat-text) |
| **Group** | [Group](Group) |
| **Character and gear** | [Character and gear](Character-and-gear) |
| **HUD** | [HUD](HUD) |
| **Chat and windows** | [Chat and windows](Chat-and-windows) |
| **Bags and items** | [Bags and items](Bags-and-items) |
| **Helpers** | [Helpers](Helpers) |
| **Layout** | [Layout](Layout) |

A page can have tabs across its top. Tabs that do not fit sit under **More**. A module's switch sits in its page header, and a page that holds part of a module shows that module's switch too.

A small dot in the accent colour marks what you changed:

- after a tab's name while that tab holds a setting off its default (under **More**, after its line in the list);
- after a module's name in the sidebar while any of its pages holds one, so you can see where your own settings are without opening each page.

The dot goes once the last of them is back at its default. The **Icon rail** sidebar shows no names, so it shows no dots.

### The title bar

- Drag the title bar to move the window. Double-click it to put the window back in the middle of the screen.
- Ctrl and the mouse wheel over the title bar set **Window scale**.
- "Profile: Raid", dim, names the profile your changes go into. Point at it to see how many characters use that profile, and click it for the **Profiles** page. It lights up for a second when the profile changes while the window is open. While a switch waits for the end of a fight, a second line in the accent says so, as "Raid after the fight".
- The **Test mode** switch shows your frames with sample content. See [Test mode](Test-mode).
- **Search** finds any setting. See below.

### The bottom of the window

- A strip shows messages, such as what Ctrl+Z undid, for about six seconds. Otherwise it counts the changes on the tab, as "3 changed on this tab. Click to go to each." Each click scrolls to the next changed row and flashes it.
- **Reset page** puts every setting of the tab back to its default. It is dimmed while nothing on the tab is changed. One Ctrl+Z puts the whole page back.
- **Reload** reads "Reload (2)" in the accent while changes wait for a reload. See [The reload notice](#the-reload-notice).
- **Done** closes the window.

### Search

Type in **Search** to find settings across every page.

- The words you typed are lit in each result, and the head counts the results.
- Each group of results, and each page chip, names its place, as "Nameplates > Colours" or "Unit frames > Per frame > Player".
- A module's name counts as a word of each of its tabs, so "nameplate cast colour" finds the colour rows of **Nameplates > Cast bar**.
- A click on a result opens its tab, scrolls to its row and flashes it.
- Search also finds the window's own actions, under **Actions**: **Test mode**, **Move frames**, **Welcome screen** and **Ready-made looks**.
- Rows of the **Profiles** page, such as **Import profile** or **In a raid**, open that page at the row.
- The small cross at the right of the box clears it and shows the page you were on.

Type `#changed` to list every setting of the profile in use that is off its default, grouped by page. Each row works as on its page, with its reset arrow. The head says how many, as "37 changed settings", or "Every setting is at its default." More words narrow the list, as `#changed nameplate`.

You can search from chat too: `/flatui border colour` opens the window with those words in **Search**.

### Changing settings

- The mouse wheel scrolls the page, also over a slider. Shift and the mouse wheel step a slider, as does the wheel while its number box has the cursor.
- A long dropdown, such as the fonts or bar textures, opens with the cursor in a filter field. Type to narrow it, press Enter for the first line, or Escape to close it.
- A sound dropdown plays each sound once as you pick it. The **Play** button beside it plays the one chosen now.
- Right-click a colour swatch for a short list: **Copy #D93A30** and, once a colour is copied, **Paste #D93A30**. Paste writes the colour at once, and Ctrl+Z puts the old one back.
- A changed row has a small reset arrow. Point at it to see the default it puts back, and click it to reset that row.
- A press on a button counts only when you let go over it, so sliding off before letting go changes your mind.

### Undo and redo

Out of a fight:

- Ctrl+Z puts back the newest change, on any page. Each press goes one change further back. The strip says what it did, as "Undid Border colour: back to #000000.", and the row flashes if it is on the tab shown.
- Ctrl+Y, or Ctrl+Shift+Z, makes again what Ctrl+Z or an **Undo** took back, until you make a new change.
- After **Reset page**, one Ctrl+Z puts the whole page back.

### Keys

| Key | What it does |
| --- | --- |
| Ctrl+F | Puts the cursor in **Search** |
| Ctrl+Z | Undoes the newest change |
| Ctrl+Y or Ctrl+Shift+Z | Makes again what was undone |
| Escape | Closes the colour picker (keeping the old colour), an open dropdown or a question, then the window on a second press |
| Enter | Applies the colour picker's colour, or answers a question with its first button, the one in the accent |

The Ctrl keys work out of a fight. Enter does not answer a question that takes a profile's settings away: **Delete**, **Reset**, **Copy** and **Replace** on the **Profiles** page, and setup's **Start over**. These are red, say "Enter does not answer this.", and wait for a click. In setup too, Escape closes a dropdown, question or colour picker before the window.

### Changes made in a fight

Most settings apply at once, in a fight too. A few wait for the end of the fight, because the game does not let an add-on change some frames while you fight. A change of the UI scale or of the **Fonts** page is one such change, and chat says so once a fight while the window shows, as "Flat UI: the UI scale changes when the fight ends." See [Troubleshooting](Troubleshooting) for the full list.

## Home

**Home** is the first page of the options window. It has:

- **Profile**: **Profile in use** to switch profile, how many characters use it, and **Set up my screen**, **Export** and **Ready-made**.
- **Accent and density**: the window's **Accent**, **Density** and **Corners**, the same rows as on the **Options and setup** tab.
- **Needs a reload**: each change that waits for a reload, with its own **Undo**, and a **Reload** button.
- **Recent changes**: your last changes, with **Every change** at its top right.
- **Modules**: a tile for each module, with its switch and how many of its settings you changed, as "3 changed". A click on a tile opens its page.
- **What's new in 0.5.47** at the bottom, which opens the **What's new** window.

### Recent changes

**Recent changes** keeps your last 50 changes.

- Each line says what changed, from the value before to the value now, as "Off to On" or "300 ms to 450 ms".
- A click on a line opens that setting's tab, scrolls to its row and flashes it.
- **Undo** on a line puts that value back. Point at it to see the value it puts back.
- A **Reset page**, or the reload notice's **Undo**, is one line with one **Undo** for all its settings.
- **Every change** opens **Search** on `#changed`, the list of every setting you changed.

Renaming the profile keeps its recent changes. A change that a reset, a copy, an import or setup's **Finish** took away leaves the list until its value comes back.

### Needs a reload

Each line of **Needs a reload** has a small **Undo** of its own. It puts that change alone back to its value at login, so it needs no reload, and you can keep one change while dropping another. Ctrl+Z, or the new line's **Undo** in **Recent changes**, makes the change again. These **Undo** buttons are dimmed in a fight.

## The reload notice

Most settings apply at once. A few need a reload, such as **Square icons**, **Side tabs** or **Leave the game's action bars alone**. Some need it only when you turn them off.

When a change needs a reload, wherever you made it, a small notice at the top of the screen says what needs it, as "2 changes need a reload: Square icons, Side tabs.". It has three buttons:

- **Reload** reloads the interface. It works on WoW: Forever, where the game blocks reloads for add-ons, as long as you are out of a fight.
- **Undo** sets all those changes back to what the game runs since login, so no reload is needed. Chat says how many it put back. It is dimmed in a fight and while setup has the options window: press it after.
- **Later** fades the notice out until your next change that needs a reload.

Point at the notice or any of its buttons for every change with its value now and at login, as "Square icons: Off now, On at login". The notice fades out by itself when you put a change back by hand.

In a fight, every **Reload** button of Flat UI is dimmed, and a press says "Flat UI: Reload works here again after the fight. Type /reload to reload now." Typing `/reload` yourself always works.

The notice stays clear of the options window's title bar, the `/flatui move` toolbar and the test mode bar. To move it, drag the **Reload notice** box in `/flatui move`. While test mode is on and nothing needs a reload, a dimmed sample notice shows at its place.

## What's new

After an update, the first login on the account shows **What's new**: a window with what changed in each version since the one you last played, newest first. Setting names are in the accent colour.

- **Open Flat UI's options** opens the options window, and **Close** (or Escape) closes What's new.
- It waits for the end of a fight, steps aside if one starts and comes back after it. You can drag it anywhere on screen.
- A line that names a setting lights up under the mouse. A click closes What's new and opens the options window at that setting, scrolled to its row and flashing.
- The **Filter** box keeps only the changes that mention every word you type, as "party" or "threat list". The line under the title counts them, as "12 of 121 changes mention "party".". Clearing the box brings everything back. Escape leaves the box, and a second Escape closes the window.
- Two small buttons at the top right, as "< 0.5.42" and "0.5.44 >", step to the version before and after, skipping versions with no notes.

Open it at any time with **What's new in 0.5.47** at the bottom of **Home**, or with `/flatui new`. Both open the newest version that has notes. `/flatui new 0.5.45` opens that version, if it is one of the newest six.

A new install shows nothing, since the welcome screen and setup walk you through Flat UI. A new character that the welcome screen greets gets a chat line instead of the window.

The full changelog is at https://github.com/dismlx/flat-ui/blob/main/CHANGELOG.md

## The Options and setup tab

The **Flat UI** page, first in the **Look** group, has an **Options and setup** tab. It holds four sections. The rows of **Options window** and **Setup** are the same for every character and profile on your account. The rows of **Game menu** and **Updates** belong to the profile in use.

### Options window

These rows change the options window itself, at once:

- **Accent colour** marks the chosen item, a switch that is on and the scroll bar. Pick **Indigo**, **Sage**, **Amber**, **Rose**, **Ice**, **Class colour** or **Custom**, which uses **Custom accent colour**.
- **Window tone** sets the window's colours: **Graphite**, **Ink**, or **Follow background colour**, which uses the **Background colour** of the **Flat UI** page. A light colour can make the window hard to read.
- **Borders** (**None** or **Hairline**), **Corners** (**Square**, **Soft** or **Round**) and **Density** (**Compact**, **Comfortable** or **Roomy**, the row height and text size) set the window's look.
- **Window font** and **Window scale** set its text and size. A window larger than the screen is made smaller to fit.
- **Sidebar** shows **Icons and names**, **Names only** or an **Icon rail**.
- **Sections** puts each section's rows on a **Cards** panel that folds, or under a heading with **Lines**.
- **Previews** shows, collapses or hides the drawing above a page's settings.
- **Movers grid** sets the lines behind the frames in `/flatui move`, and **Snap to other frames** shows a guide when a handle lines up with another.
- **Samples in lists** shows a small picture beside each bar texture, font and row direction in a list.

### Setup

- **Profile on a new character** is used once, on a character with no profile of their own. **Show the welcome screen** (the default) greets them. **Default profile** puts them on Default. **Suggested profile** picks a ready-made look from their class, role and screen. You can also name a ready-made look or one of your own profiles.
- **Welcome screen shows** picks **New character with no profile** or **First login on the account**. The second shows it only while no character has a profile.
- **Keep this look uses** decides what **Keep this look** on the welcome screen does: keep the **Default profile**, or use **The game's look**, a profile named Game look with every Flat UI module off.
- **Setup result in chat** gives **One line** in chat when setup finishes, or **None**.

### Game menu

- **Flat UI button in the game menu** adds a **Flat UI** button under **Options** in the game's menu. It does not work in combat, and it does not show while the game's taintLog setting is on.
- **Flat UI button opens** the **Options window** or **Flat UI setup**.

### Updates

- **What's new after an update** chooses **Show the window** (the default), **One line in chat** ("Flat UI updated to 0.5.47. /flatui new shows what changed.") or **Nothing**. It applies once on the account for each version.

## Commands for this page

| Command | What it does |
| --- | --- |
| `/flatui` | Opens or closes the options window |
| `/flatui setup` | Opens Flat UI setup, or continues it |
| `/flatui welcome` | Opens the welcome screen |
| `/flatui profiles` | Shows the ready-made looks |
| `/flatui new` | Opens **What's new**; `/flatui new 0.5.45` opens that version |
| `/flatui options` | Opens Flat UI's page in the game's own options |
| `/flatui border colour` | Opens the options window with those words in **Search** |
| `/flatui #changed` | Lists every setting you changed |

Every command is on the [Commands](Commands) page.

Every setting of the **Options and setup** tab, with its default: [Settings: Look](Settings-Look).
