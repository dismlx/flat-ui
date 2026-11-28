When something in Flat UI looks wrong, start with `/flatui status`. This page explains what it tells you, what the error messages mean, why some changes wait for the end of a fight, and answers the questions players ask most.

## /flatui status

Type `/flatui status` to print a report in chat. It starts with:

- the version, as "Flat UI 0.5.47";
- the profile in use, as "Profile: Raid";
- your **Border thickness**.

Then each part of Flat UI has a line, in one of these forms:

| Line | What it means |
| --- | --- |
| "Unit frames: on, 12 styled" | The part runs and counts what it styled |
| "Bags: off" | Its switch is off |
| "Trackers: on, not started" | Its switch is on, but it has not started yet |
| "Nameplates: on, 40 styled, 2 failed." | It runs, but some frames failed. The first error follows. |
| "Chat and tooltips: stopped." | It hit an error and stopped. The error follows. |

Many parts add lines of their own under theirs, such as what they see or why they show nothing. Later lines cover test mode, the UI scale, the game settings Flat UI sets, setup's last result, and anything the game blocked.

`/flatui status` is the first thing to look at, and the first thing to share when you ask for help.

## Error messages

### A part stopped

If a part of Flat UI hits an error, it stops so it does no more harm, and chat says:

"Flat UI: Unit frames stopped. /flatui status shows why. Type /reload if the look is left half changed."

A `/reload` starts it again. A part that fails on five different frames stops in the same way. The line of that part in `/flatui status` says what went wrong.

### Blocked by the game

The game keeps some actions to itself, many of them only in a fight. If the game blocks an action of Flat UI, `/flatui status` lists it under "Blocked by the game:". For a blocked action, Flat UI also checks the click path of the action buttons for values an add-on changed, and `/flatui status` prints what it found, as "Tainted: ... by ..." lines, for the last three blocks.

`/flatui taint` runs the same check now, on the action button under the mouse if there is one.

### Other checks

| Command | What it does |
| --- | --- |
| `/flatui check` | Says what the game shows and hides from add-ons where you stand: buffs, cooldowns, casts and names |
| `/flatui check last` | Prints the last check again |
| `/flatui cvar` | Lists each game setting that Flat UI sets: its value, default and secure flag |
| `/flatui cvar check` | Tries whether each of those can be changed, out of combat |

## The taint log box

The game has a setting, taintLog, that writes a log of what add-ons change. While it is on, Flat UI leaves out the looks that follow the game's frames, and a box says so at login:

"taintLog is on. Flat UI leaves out the looks that follow game frames until it is off."

- **Turn off and reload** turns taintLog off and reloads, so Flat UI follows the game's frames again.
- **Ignore** closes the box until you next log in or reload.

Turning taintLog on during a session prints "Flat UI: taintLog is on. Turn it off with /console taintLog 0, then /reload." While it is on, the **Flat UI** button in the game menu does not show, and `/flatui status` counts the game methods Flat UI did not follow.

## The reload notice

Most settings apply at once. A few need a reload, and some need one only when you turn them off. When a change needs one, a small notice at the top of the screen says so, with **Reload**, **Undo** and **Later**:

- **Reload** works on WoW: Forever, where the game blocks reloads for add-ons, as long as you are out of a fight.
- **Undo** puts the changes back, so no reload is needed.
- **Later** hides the notice until your next change that needs a reload.

In a fight, every **Reload** button of Flat UI is dimmed, and a press says "Flat UI: Reload works here again after the fight. Type /reload to reload now." Typing `/reload` yourself always works.

Home's **Needs a reload** card lists the same changes, each with its own **Undo**. See [Getting started](Getting-started) for more.

## What waits for the end of a fight, and why

In a fight, the game protects many of its frames: the unit frames, the action buttons and their bars, nameplates and more. No add-on may move, show, hide or resize them then, and trying makes the game block the action. So Flat UI makes those changes as soon as the fight ends, and tells you so.

What waits:

- **Profile changes.** A profile picked in a fight, by hand or by **Switch automatically**, switches as the fight ends. Creating, copying, deleting, renaming, resetting and importing profiles say "Profiles change after the fight."
- **The UI scale and the Fonts page.** Chat says "Flat UI: the UI scale changes when the fight ends." or "Flat UI: fonts change when the fight ends."
- **Action buttons and bars.** A new button look, and bars that hide or show, wait. Chat says "Flat UI: action buttons take their new look when the fight ends."
- **Frame sizes and places**, such as the cast bar sizes and the pet frame's size.
- **The options window**, if you have not opened it since you logged in: it opens as the fight ends, with your search if you typed one.
- **`/flatui move`** opens when the fight ends. Boxes open before the fight pause and open again after it.
- **Test mode** waits to come on, and pauses if a fight starts. See [Test mode](Test-mode).
- **The welcome screen, the ready-made looks, setup's card and What's new** hide in a fight and come back after it. Setup's **Finish** waits for you to press it after the fight.
- **The reload notice's Undo** says "Flat UI: Undo after the fight.", and the **Undo** buttons of Home's **Needs a reload** are dimmed.
- **Edit a tracker** shows "Open this page after the fight."
- **Trinket swaps** of the **Trinket queue** wait: "Flat UI: trinkets change after the fight."
- **The Flat UI button** in the game menu does not work in combat.

Many other settings change at once in a fight too.

## Test mode limits

Test mode draws samples of your frames, but some things never show in it:

- The game's own unit frames are never shown or given a unit, and Flat UI never opens Edit Mode. Doing either from an add-on taints them and can block targeting.
- Real nameplates are not forced on screen, so threat colours show on the sample nameplate only.
- The game's windows are not opened for you. Open them yourself to see their look change.
- Chat and tooltips get no sample.

See [Test mode](Test-mode) for the full list.

## Questions

### My new character does not have my settings.

Each character uses one profile, and a new character starts on Default or on what **Profile on a new character** says. Pick your profile under **Profile in use**, on the **Profiles** page or Home's **Profile** card, or type `/flatui profile Raid`. See [Profiles](Profiles).

### I reset a page or a profile by mistake.

After **Reset page**, press Ctrl+Z in the options window: one press puts the whole page back. After **Reset profile**, **Copy from**, an import with **Replace** or setup's **Finish**, press **Bring back** on the **Reset profile** row. After **Delete profile**, press **Bring back** on the delete row. **Bring back** works until you reload.

### A frame is off the screen, or in the wrong place.

Type `/flatui move` and drag its box back. **Reset all** on the movers bar, or `/flatui move reset`, puts every moved frame back where the game has it. `/flatui move reset windows` does the same for windows. Frame positions belong to the profile, so another profile can have other places. See [Layout](Layout).

### A frame of the game has gone.

It may be ticked on the **Hidden frames** page: type `/flatui hide` and untick it. In `/flatui move`, Shift and right-click on the box of a HUD frame of the game hides it too. See [Layout](Layout).

### A setting seems to do nothing.

- The row may be dimmed because it needs another row that is off. Turn that row on first.
- The part may be off: check its switch at the top of its page or on its tile on Home.
- The change may need a reload. Look for the reload notice, or **Needs a reload** on Home.
- Some action bar rows are not applied while **Leave the game's action bars alone** is on. Their tips say so.
- **Custom scale** reads "not used now" while **Pixel-perfect scale** or **Scale below 65%** sets the scale.
- In a fight, the change may wait for its end. See above.

### My action buttons do not respond at a small UI scale.

The game can refuse presses of its own action buttons below 65%. Use `/flatui scale 65` or more, or `/flatui scale off` to give the game its own scale back. Turning **Scale below 65%** off needs a reload.

### The options window does not open in a fight.

The first time after you log in, the window can only open out of a fight. Chat says "Flat UI: the options window opens after the fight." and it opens as the fight ends.

### The Flat UI button is missing from the game menu.

Check **Flat UI button in the game menu** on the **Options and setup** tab of the **Flat UI** page. The button does not show while the game's taintLog setting is on.

### I want the game's own look back.

- To drop one part, turn its switch off.
- To try the game's look on one character, set **Keep this look uses** to **The game's look** and press **Use the game's look** on the welcome screen (`/flatui welcome`). It makes a profile named Game look with every Flat UI module off. Some parts, such as restyled action bars and windows, change after a `/reload`.
- To stop Flat UI loading, untick it in the game's **AddOns** list. See [Installing](Installing).

### What's new opens after every update, and I do not want it.

Set **What's new after an update**, on the **Options and setup** tab, to **One line in chat** or **Nothing**. `/flatui new` still opens it when you want.

### The welcome screen shows on every new character.

Tick **Do not show on new characters** on the welcome screen before you choose, or set **Profile on a new character** to another choice. **Welcome screen shows** at **First login on the account** shows it only while no character has a profile.

### Setup says the game kept a setting.

Some game settings are locked or kept by the game. Setup's card says "The game kept ..." for each, and `/flatui status` lists them under "Setup: the game kept ...". Flat UI cannot change those.

Every setting, with its default, is in the settings pages, such as [Settings: Look](Settings-Look) and [Settings: Layout](Settings-Layout).
