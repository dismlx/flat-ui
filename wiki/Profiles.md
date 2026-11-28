A profile holds every Flat UI setting and every frame position. Your profiles are shared by all the characters on your account, and each character uses one of them. This page covers the defaults, the ready-made looks, the **Profiles** page, switching by place and sharing a profile as text.

## How profiles work

- Every setting you change, and every frame you move, is saved in the profile in use. The title bar of the options window names it, as "Profile: Raid".
- Each character uses one profile. Several characters can use the same one, and a change made on one of them shows on all.
- A character with no profile of their own uses **Default**. Default cannot be deleted or renamed.
- A few things are the same for the whole account whatever profile is in use: the options window's own look and the setup rows on the **Options and setup** tab. Some rows set the game's own settings, which are the same in every profile; their tips say so.

## Jon Default and the defaults

Every setting starts at the settings of **Jon Default**, Flat UI's own look. A new install, and every new profile you make with **Create**, start with its frame positions too, fitted to your screen at the scale the profile gives. A profile you already have keeps its own positions.

So "the default" of a row, and **Reset page** or **Reset profile**, always mean Jon Default's value.

## Which profile a new character gets

**Profile on a new character**, on the **Options and setup** tab of the **Flat UI** page, is used once, on a character with no profile of their own:

- **Show the welcome screen** (the default): the character starts on Default and the welcome screen offers setup and the ready-made looks. See [Getting started](Getting-started).
- **Default profile**: the character uses Default.
- **Suggested profile**: Flat UI picks a ready-made look from the character's class, role and screen.
- A ready-made look, or one of your own profiles, by name.

## Ready-made looks

The ready-made looks are finished profiles. Open them with `/flatui profiles`, with **Ready-made looks** on the welcome screen or the **Profiles** page, or with **Ready-made** on Home's **Profile** card.

| Look | What it gives |
| --- | --- |
| **Standard** | Every setting at its default, as Jon Default has it |
| **Minimal** | Less on screen, and idle bars fade |
| **Damage** | Cast times and a low health border on nameplates |
| **Tank** | Health numbers and your defensives |
| **Healer** | Missing health, heal over time squares and a low health border on party frames |
| **Large** | Bigger text, bars and icons |
| **Jon Default** | Jon Default's own settings and frame positions |

How picking works:

- Each look is drawn as a small picture. A click puts it in use.
- The first pick makes a profile under the look's name, such as Healer. A later pick puts that same profile back in use, with any changes you made to it since.
- The look in use is marked **In use**, and the one that fits your character is marked **Suggested**.
- Tick **Same profile on new characters** before you pick, and new characters start with that look too.
- **Same as** puts in use the profile most of your characters use, leaving out Default and the profile in use, as "Same as Raid". It shows only when there is one.
- Looks cannot be picked in a fight ("In a fight. Pick a look after it.").

After a pick, a card says which profile is in use. **Back to** puts the profile you had back in use. **Change it** opens setup, so you can change the look further. **Move frames**, **Options** and **Done** open `/flatui move`, open the options window or close the card. **Reload** shows when the look needs a reload.

## The Profiles page

Open it with **Profiles** in the sidebar, or with a click on "Profile: Raid" in the title bar. A right-click on "Profile: Raid" opens the profile list right under it instead, to switch without leaving the page you are on. Point at any row to see what it does. It has three sections: **Profile**, **Switch automatically** and **Share**.

### Profile

- **Profile in use** switches this character to another profile at once. Home's **Profile** card has the same row. Its list shows how many characters use each profile, as "Raid  (3)", and a dim note beside it names them, as "Used by you, Bex and Ivo" ("and 2 more" past three; the realm is left out for characters on your own realm).
- **New profile**: type a name, then press **Create** or **Duplicate**. **Create** starts from the defaults and the frame positions a new profile starts with. **Duplicate** copies the profile in use with its frame positions, as "Raid copy" when no name is typed. The new profile is put in use.
- **Setup** has **Set up my screen** (it reads **Continue setup** while a setup waits) and **Ready-made looks**.
- **Copy from** replaces every setting and frame position of the profile in use with those of another profile. To keep both, use **Duplicate** instead.
- **Delete profile** deletes another profile. The question names the other characters that use it, up to three, as "Delete "Alt"? Bex and Ivo use it and start as new characters at their next login.", or says how many when there are more; they start as new characters at their next login. The profile in use and Default cannot be deleted.
- **Rename profile** gives the profile in use a new name. The characters that use it keep it, and its **Switch automatically** rules follow the new name.
- **Reset profile** puts every setting of the profile in use back to its default, and every moved frame back to its own place.

A name has 1 to 32 characters on one line, and two profiles cannot share a name.

### Bring back

None of **Reset profile**, **Copy from**, **Delete profile**, an import with **Replace** or setup's **Finish** is for good until you reload:

- After **Reset profile**, **Copy from**, an import with **Replace** or setup's **Finish**, the **Reset profile** row has **Bring back** beside **Reset**. It puts the profile in use back as it was. Point at it to see what it puts back, as "Puts Raid back as it was before Reset profile at 21:04: 124 settings, 9 frame positions." A second press puts back what the first took.
- After **Delete profile**, the delete row has **Bring back**. It puts the deleted profile back, with the characters that used it and its **Switch automatically** rules.

**Delete**, **Reset**, **Copy** and **Replace** ask first. Their answer buttons are red, and Enter does not answer them: they wait for a click.

## Switching profile in a fight

The game does not let Flat UI change profile in a fight, so a switch waits for its end:

- Pick a profile under **Profile in use**, from the right-click list of the title bar, or type `/flatui profile Raid`, in a fight. The strip, or chat, says "Switches to Raid when the fight ends.", and the title bar shows "Raid after the fight" in the accent.
- As the fight ends the profile switches, and chat says "Flat UI: using Raid.".
- Picking the profile in use again in the same fight drops whatever waits, a switch of **Switch automatically** too, and says "Stays on Default.".
- A profile you pick wins over a **Switch automatically** switch that waits for the same fight.

Creating, copying, deleting, renaming, resetting and importing profiles do not work in a fight ("Profiles change after the fight.").

## Switch automatically

**Switch automatically** gives this character a profile for each kind of place:

- **In a dungeon**
- **In a raid**
- **In a battleground or arena**
- **Everywhere else**

Each row holds a profile, or **No change**, which keeps the profile in use. The rules belong to the character, so each character can have their own.

How it switches:

- On entering such a place, the character switches to its profile. Chat says why, as "Flat UI: switched to Raid, the profile for raids (Profiles > Switch automatically).", and so does the strip while the options window is open.
- A switch that would come in a fight waits until the fight ends.
- Picking a profile for the kind of place you are in now asks first, as "You are in a raid now. Switch to Raid now?", with **Switch now** and **Later**. With **Later**, the switch waits until you next enter such a place.
- The first login of a session applies the rules for where the character stands. A character who logged out in a raid and logs in outside it goes to the profile of **Everywhere else**. A `/reload` keeps the profile in use.
- Deleting a profile takes it off every rule; **Bring back** puts those rules back.

## Sharing profiles

The **Share** section turns a profile into one line of text that you can keep or give to a friend, who pastes it into their own Flat UI.

### Export a profile

**Export profile** writes the profile in use, settings and frame positions. Press **Export**: the text is selected in the box, ready for Ctrl+C. A click in the box selects it all again, and Ctrl+C there says "Copied. Paste it where you share it."

**Export trackers** does the same for your trackers alone, and **Import trackers** adds trackers someone exported: paste them, then press **Import**.

### Export by module

**Export by module** writes only the parts you choose:

1. Press **Modules** to open the list of what an export holds (the button reads **Hide list** while it is open).
2. Tick the modules you want. **All** and **None** tick or clear every module, so **None** and one tick export a single module. **Frame positions** puts the positions in the export too.
3. Press **Export chosen**, then Ctrl+C. With no module ticked and **Frame positions** off, it says "Tick a module first."

### Import a profile

Paste a profile into **Import profile** (Ctrl+V). What it holds shows under the field:

- **Pasted profile** names it, with the Flat UI version it came from and how many settings and positions it holds.
- **Screen** shows when it was made on a screen of another size. **Fit positions to this screen** (on) scales each position to your screen, so a frame keeps its share of the screen and none lands off the edge. Turn it off to keep the positions as the text has them.
- **Settings** and **Frame positions** choose what to import. With **Frame positions** off, no position is imported.
- **Import as** puts the import in a **New profile**, under the name beside it, or replaces the profile in use (**Replace Raid**). Replace asks first, and **Bring back** puts the old profile back until you reload.

Then press **Import**, or **Import selected** on the **Import now** row.

## Commands

| Command | What it does |
| --- | --- |
| `/flatui profile` | Names the profile in use and the others, as "Flat UI: profile Default. Others: Raid, Alt." |
| `/flatui profile Raid` | Puts Raid in use ("Flat UI: using Raid."); in a fight, as the fight ends. A name it does not know lists the profiles. |
| `/flatui profiles` | Shows the ready-made looks |
| `/flatui setup` | Opens Flat UI setup, or continues it |

Every command is on the [Commands](Commands) page.

The rows that pick a new character's profile, with their defaults, are on the **Options and setup** tab: [Settings: Look](Settings-Look).
