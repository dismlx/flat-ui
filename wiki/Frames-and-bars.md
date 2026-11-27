The **Frames and bars** group restyles the game's unit frames, cast bars, personal resource display and swing timers, and adds helpers to them, such as heal over time squares, interrupt readiness and a druid's mana in forms. Its pages are **Unit frames**, **Nameplates**, **Cast bars**, **Personal resource display** and **Swing timers**.

![Flat UI in play](https://raw.githubusercontent.com/dismlx/flat-ui/main/media/flatui-in-play.jpg)

Every page has a switch at the top. Turn it off to leave that part to the game's own look.

## Unit frames

The **Unit frames** page restyles the player, target, focus, pet, target of target, party, party pet, boss and raid frames and the totem frame. **Restyle unit frames** at the top turns all of it on or off.

The page has five tabs:

- **General**: which frames are restyled, their scale, portraits, the name row and level, and raid cells.
- **Per frame**: one tab for each frame. Pick the frame from the row of buttons under the tabs: **Player**, **Target**, **Focus**, **Pet**, **Target of target**, **Party**, **Boss** or **Raid**. Their full names are **Player frame**, **Target frame**, **Focus frame**, **Pet frame**, **Target of target frame**, **Party frames**, **Boss frames** and **Raid frames**.
- **Bars and pictures**, **Text** and **Icons and auras**: settings for every frame at once. Their full names are **All frames: bars and pictures**, **All frames: text** and **All frames: icons and auras**.

### Which frames, and how big

Under **Frames** on the **General** tab, untick a frame to leave it as the game draws it. **Raid frames** also covers the party frames while the game's raid-style party frames are on.

**Frame scale** sets the size of the player, target, focus, party, boss and raid frames, from 50% to 200%. Edit Mode can only enlarge frames; these rows can also shrink them. **Target frame scale** takes the target of target frame and the target's cast bar with it.

**Custom pet frame size**, under **Pet frame size**, sets the pet frame's size yourself. **Pet frame size is measured against** picks what 100% means: **Player frame size** (as large as the player frame) or **Normal size** (the pet frame at Edit Mode's Frame Size of 100%). While the row is off, Edit Mode's Frame Size for the pet is used.

To move a frame, type `/flatui move` and drag its box. See [Layout](Layout).

### Frame style

**Frame style**, at the top of the **Bars and pictures** tab, sets how each frame is put together:

- **Separate parts** (the default) gives the portrait, the name row and each bar a thin border and background of their own.
- **One frame** puts the portrait, the name row and the bars on one background inside one border, a few pixels apart.

The rows under it tune both styles:

- **Background** and **Border** sit behind and round the whole frame, or behind and round each bar in **Separate parts**.
- **Space between parts** (2 px at first, 0 to 4) is the gap between the portrait, the name row and the bars. In **Separate parts** it is only the gap between the two bars.
- **Corners** rounds the corners: **Square**, **Slightly soft** or **Soft** (the default). It also rounds the pet target frame and the druid mana bar.
- **Highlight under the mouse** (on at first) brightens the health bar of the frame under the mouse a little, so you see which frame a click hits. Raid frames and the pet target frame do it too.

For your own border and background colours on the unit frames, tick **Own border and background** at the bottom of the **General** tab. It gives you **Border colour**, **Background colour** and **Background opacity**. Otherwise the frames take the look of the **Flat UI** page: see [Look](Look).

### Portraits

**Flat UI portraits**, on the **Bars and pictures** tab, is on at first. Flat UI then draws each frame's portrait and its name row. Turn it off to keep the game's own portraits where the game puts them, with no name row. Most portrait and name row settings need it on.

Under **Portraits** on the **General** tab:

- **Portrait style** sets the picture for every frame: **Face** (the default), **3D head**, **Class icon** or **None**.
- **3D head framing** sets how close the camera sits on a 3D head: **Face**, **Head** or **Head and shoulders** (the default).
- **Portrait size** makes the portrait **As tall as the frame** (the default) or **As tall as the bars**. In **One frame**, **As tall as the bars** puts the name row over the portrait too.
- **Portrait border** is **Thin**, **Class or reaction colour** or **None**. In **One frame** it colours the whole frame's border.
- **Portrait shape** is **Square** or **Round**. It applies to every picture but a 3D head.
- **Portrait fades with the name row** fades the top of the picture like the name row, while **Name row colour** is **Class or reaction colour, fading upward**.
- **Player portrait**, **Target portrait** and the rows after them take the picture off one kind of frame while its **Picture** is **As Portrait style**.

Each frame's own tab has a **Picture** row. At **As Portrait style** it follows **Portrait style**. Pick another to give that frame its own picture, such as **Game portrait**, which draws the game's portrait inside Flat UI's frame. On the target frame, **Class icon** applies to players, and other units keep their face.

### Name row and level

The name row is a strip with the name above the health bar of the player, target, focus and boss frames. **Name row**, on the **Bars and pictures** tab, turns it on or off.

- **Name row colour**: players take their class colour, other units their reaction colour. Pick **Class or reaction colour, fading upward** (the default), **Class or reaction colour**, or **Dark with a colour mark**.
- **Name row fade** (95%) sets how far the colour fades toward the top. 0 is one flat colour.
- **Name background brightness** (100%) can darken the row, so a name on a light colour stays easy to read.
- **Name row on small frames**, on the **General** tab, gives the pet, target of target, party and party pet frames a name row too.
- **Name room** at **Only what the texts need** (the default) gives the name the room the level and the PvP word leave. **Fixed space** keeps a set room for each.

Under **Level** on the **General** tab, **Level position** puts the level at the **End of the name row** (the default), **Before the name**, **On the portrait** or **Hidden**. The game's round level plate stays hidden. **Level colour** is **By difficulty** (the game's grey to red) at first, or **White** or **Same as the name**. **Level size** is **Same as the name**, **Smaller** or **Larger**.

An Elite, Rare or Boss shows in several ways, each with its own row:

- **Portrait border colour**, under **Elite and Rare** on the **Bars and pictures** tab: gold for an Elite, silver for a Rare, silver with a gold inner line for a Rare Elite, red for a Boss.
- **Mark after the level**, on the **Icons and auras** tab: + for an Elite, R for a Rare, R+ for a Rare Elite.
- **Elite or Rare word**: Elite, Rare, Rare Elite or Boss in the name row.
- **Line under the name row** (off at first): a thin coloured line between the name row and the health bar.

An enemy that another player has tapped, which gives you no experience or loot, turns grey, as the game's own frames grey it. This shows in the name row and in a **Health bar colour** or **Name colour** of Class or Reaction.

### Health and power bars

Under **Bars** on the **Bars and pictures** tab:

- **Flat bars** (on at first) gives the bars square ends and one plain colour, in the bar texture of the **Flat UI** page. **Health bar texture** and **Power bar texture** can pick their own.
- **Health colour** is the green of a health bar that is not coloured by class or reaction.
- **Mana bar colour** at **Sky blue next to a blue health bar** (the default) turns a mana bar sky blue when the frame's health bar is close to the same blue, so the two bars do not blend. **As the game has it** keeps the game's blue.
- **Power bar width**, in **Separate parts**, is **Same as the health bar** (the default) or **Game's width**, which can run past the health bar on the target, focus and target of target frames.
- **Hide empty power bar** (on) hides the power bar of a unit that has no power.
- **Colour health bars by health left** (off at first) turns the health bars from green through yellow to red as health drops, in the three **Health left** colours of the **Colours** tab of the **Flat UI** page. It works on raid cells, raid-style party frames and the pet target frame too, also in a fight.

Each frame's tab has a **Health bar colour** row: **Health colour**, **Class** or **Reaction**. The player, party and target of target frames start at **Class**; the others start at **Health colour**. On the target frame, **Class** applies to players, and other units take their reaction colour.

The **Looks** section of the **Text** tab changes every frame at once:

- **Health in class and reaction colour**: every health bar takes a player's class colour or another unit's reaction colour. A frame's own **Health bar colour** picks first.
- **Dark health bar, colour shows what is lost**: the bar turns dark and the lost part shows the colour, so the colour grows as health drops. It needs **Background**.
- **Muted colours** softens the health, power and name row colours toward grey.
- **Smaller, lighter bar text** draws bar text at 85% of its size with no outline, on every frame but the boss frames and raid cells.
- **No text on the power bar** hides the numbers on every power bar.
- **Soft shade on bars** uses the soft bar texture on unit frames, whatever the **Flat UI** page chooses.
- **Shadow behind each frame** adds a soft dark shadow round each frame, raid cells aside.

Under **Heal prediction and shields** on the **Bars and pictures** tab, **Incoming heals**, **Absorb shields** and **Heal absorbs** keep or hide the game's own bars for heals on their way, shields such as Power Word: Shield, and effects that eat the next heals. All three are on at first.

### Health and power text

Each frame's tab has a **Health text** and a **Power text** row. The formats are **As the game has it**, **Hidden**, **Current**, **Current / max**, **Percent**, **Current and percent** and **Missing**. The target frame starts at **Percent**; the others start at **As the game has it**.

- **Missing** writes what the unit lacks, as -12.3k, and nothing at full health.
- With a format chosen, a dead, released or offline unit reads Dead, Ghost or Offline.
- The **Health text** of the **Target of target frame** tab also covers the focus target. **As the game has it** shows none there, so pick a format to see one.

Under **Health and power text** on the **Text** tab:

- **Number style** writes **12.3k** (the default) or **12,345**.
- **Show** writes the numbers **Always** (the default), **Under the mouse**, or **While not full**. With **While not full**, the health text hides at full health and the power text at full mana or energy, or while rage is empty, so a party column stays clean until someone needs a heal. Dead, Ghost and Offline always show. **Show** works on a format chosen on a frame's tab, not on **As the game has it**.
- **Health text position** and **Power text position** are **Left**, **Centre** or **Right**.

The other rows of the **Text** tab set the fonts:

- **Names**: **Name font**, **Name size**, **Name outline** and **Name colour** (**As the game has it**, **White**, **Class**, **Reaction** or **Custom**). They reach the names on the raid frames too.
- **Bar text**: **Health text size** (100%), **Power text size** (85%) and **Small frame text size** (70%), for the names and bar text on the pet, target of target, focus target, party and party pet frames and the pet target frame. **Bar text font** and **Bar text outline** also reach the status text on raid frames. **Own bar text colour** gives the bar text a colour of your own.

### Status borders

Under **Status colours** on the **Bars and pictures** tab:

- **Resting and combat colour** (on) colours the border of the player and pet portraits, or the whole frame in **One frame**: yellow while you rest, red in a fight.
- **Threat border** (on) colours the health bar border, or the whole frame's border in **One frame**, while a unit has threat. **Threat border on tanks** at **Not shown** keeps a plain border on a tank who holds aggro as planned. A tank is a member with the tank role, or the Main Tank of a raid.

**Low health border** (off at first) turns the health bar border red, or the colour you pick in **Low health border colour**, while a unit is below **Low health below** (20% at first). It covers your own frame and your pet's, your party and their pets, and your raid, also in a fight, and never shows on a dead unit.

- **Pulse the low health border** (off) makes the border beat softly until the member is healed. Every border on screen beats in step.
- **Also on target, focus, boss and target of target frames** (off) puts the same border on those frames and the focus target, for Execute, Hammer of Wrath, or the tank you watch on the target of target. A unit you can attack uses **Enemies below** (20% at first). A unit you can assist keeps **Low health below**.

### Player frame

The **Player frame** tab has the usual **Picture**, **Name**, **Level**, **Health bar colour**, **Health text**, **Power text** and **Power bar** rows, and some of its own:

- **Resting animation**: the game's sleeping letters while you rest. At **Hidden with the resting colour** (the default) they hide while **Resting and combat colour** turns the portrait border yellow instead. **Shown** and **Hidden** are the other choices.
- **Combat icon** (on) keeps the game's crossed swords while you are in a fight.
- **Combat and resting icons** at **Above the portrait** (the default) puts the crossed swords and the sleeping letters just above the portrait's top right corner, clear of the picture, or above the whole frame in **One frame**. **Game's spot** puts them back where the game draws them. It changes out of combat.

#### Druid mana in forms

**Druid mana in forms** (on) gives a druid in Bear or Cat Form a thin mana bar under the player frame. It fades in as you shift and out as you shift back to caster form.

- **Mana text** shows the mana just right of the bar: **Percent** (the default), **Current** or **None**.
- **Mana bar height** is 4 px at first, from 2 to 12. It changes out of combat.
- **Mark the cost of a shift** (on) draws a thin line across the bar at the mana it costs to shift into the form you are in again. Fill past the line means a powershift is affordable.

#### Five-second rule

**Five-second rule** (off at first) shows when your mana starts to come back. Each time you cast a spell that costs mana, a thin bright spark crosses your mana bar from left to right over 5 seconds. When it reaches the end it flares, and Spirit is refilling your mana again. It works in a fight too, and a druid in Bear or Cat Form sees it on the druid mana bar.

#### Energy tick

**Energy tick** (off at first) is for a rogue or a druid in Cat Form. A thin spark crosses the energy bar every 2 seconds and reaches its right end as the next energy comes in, so you can time an opener or a finishing move. It finds the beat from the first tick it sees and keeps it in a fight. It hides in other forms and for other classes.

Turning **Five-second rule** or **Energy tick** on in a fight waits for the fight to end.

### Target, focus and boss frames

The **Target frame**, **Focus frame** and **Boss frames** tabs have the usual picture, name, level, health colour, text and power bar rows. The **Boss frames** tab also has **Long names**: **Cut with dots** (the default) or **Smaller text**, which shrinks a long name to 75% before cutting it.

On the **Icons and auras** tab, **Dead text** (on) keeps the game's Dead across the health bar of a dead target, focus, boss or target of target, and **Raid marker on target, focus, boss and pet target frames** (on) shows their raid markers.

### Target of target frame

The **Target of target frame** tab covers the target's target and the focus's target. **Long names** is **Smaller text** at first.

**Position** at **Beside the target frame** (the default) puts the frame just right of the target frame with their tops in line, and the focus target beside the focus frame, in either **Frame style**. It goes with the target frame wherever `/flatui move` puts it. **Game's spot** leaves it below and to the right, where the game puts it. It changes out of combat.

### Pet frame and pet target

The **Pet frame** tab adds **Long names** and **Happiness face** (on), the hunter's pet face beside the pet frame: green while the pet is happy, yellow while content, red while unhappy.

**Pet target frame** (off at first) adds a small frame for what your pet attacks:

- It shows the enemy's name and health in percent, and its raid marker just left of it. It turns grey with Dead once the unit dies.
- A click targets the unit and Shift-click sets it as your focus, also in a fight. A right-click opens its menu while it is also your target, or is a player.
- **Pet target width** is 120 px at first, from 60 to 240. A wider frame grows to the right.
- **Border while it is not your target** (on) turns its border **Not your target colour** (amber) while your pet attacks something other than your target, and back once you are both on the same unit, also in a fight.
- Its box in `/flatui move` is called **Pet target**.

Turning the frame on or off, or a new width, waits for the end of a fight.

### Party frames

The **Party frames** tab also covers the party pets: **Party pet picture**, and **Name** and **Long names** for both.

Under **Range**, **Dim members out of range** (off at first) darkens a member's picture, name row and bars while they are out of your range, to **Out of range opacity** (50%). Their pet's frame dims by its own range, and the debuff icons under the frame stay clear.

### Raid frames

The **Raid frames** tab works on the game's raid cells, also the party frames while raid-style party frames are on:

- **Out of range opacity** (50%) sets how see-through a cell is while that member is out of your range, also in a fight. At 50% the game's own fading stays.
- **Role icon**, **Name** and **Status text** (all on) keep or hide the role icon, the name and the words the game writes in a cell, such as Dead and Offline.

**Raid cell look**, under **Raid frames** on the **General** tab, makes the game's power bar thin, with a border, while Display Power Bars is on in the game's raid frame options, and greys the health of a dead or offline member.

### Party and raid frame marks

The **Party and raid frames** section of the **Icons and auras** tab holds the marks that help a group, most of them on at first.

**Debuffs you can dispel**

- **Border colour of a debuff you can dispel** (on) colours the health bar border in the colour of Magic, Curse, Disease or Poison while the member has one you can dispel.
- **Also on your player, target and focus frames** (on) does the same on your own frames. A target or focus you cannot assist shows none.
- **Debuff type icon on party frames** (on) puts the type's icon at the right end of the health bar. The game's raid frames show their own.
- **Blink as one lands** (on) blinks the border, and the icon, three times as the debuff lands, also in a fight. Nothing blinks at login, on zoning or on joining a group.
- **Sound for a debuff you can dispel** (None at first) plays a sound as a member gets one, at most once every 2 seconds. The sound plays once as you pick it.

**Markers, leaders and status**

- **Raid marker on raid frames** and **Raid marker on party frames** (on) show raid markers, which the game's frames do not. A new marker pops briefly as it lands.
- **Leader and assistant icons on raid frames** (on) shows who leads and who assists.
- **Resurrection icon on party frames** (on) shows the game's resurrection icon on a dead member's portrait while someone resurrects them, breathing softly so two healers do not resurrect the same one.
- **AFK on party frames** and **AFK on raid frames** (on) show a soft grey AFK on a member who has gone away, also in a fight. After the first minute it counts the time away, as "AFK 3m" and later "AFK 1h", from when Flat UI first saw them go. It hides while they are dead or offline.

**Your target and focus**

- **Border for your target** sets the border of your target's raid cell: **As the game has it** (the default), **Own colour** in **Target border colour**, or **Off**. With **Own colour** the party frames get the border too.
- **Border for your focus** (off at first) outlines the party frame or raid cell of the member you have as your focus in **Focus border colour** (orange), also in a fight. When your focus is also your target, the border for your target stays on top.

### Heal over time squares

**Squares for your heals over time** (off at first) is for healers. Each heal over time of yours on a party or raid member shows as a small square of its own colour in a corner of their health bar. It covers Renew, Rejuvenation, Regrowth, Prayer of Mending, Power Word: Shield, Earth Shield and Sacred Shield, among others. A priest's Renew is green, Power Word: Shield white and Prayer of Mending yellow.

- **Square corner** is **Top right** at first. On party frames a right-hand corner starts the squares just left of the debuff type icon.
- **Square size** is 6 at first, from 4 to 14. On party frames a square is at most what fits inside the health bar.
- **Fade as one runs out** (on) fades a square over the last 3 seconds of its heal, so you see which one to cast again.
- A square that lights as your heal lands, or is refreshed, pops briefly, so you see which frame took the heal.

In a fight the game hides which of your buffs is which. A square read before the pull stays until its time runs out, while the member keeps at least as many of your buffs as then. A heal over time first cast in the fight shows its square once the fight ends.

### Auras, PvP and other icons

The rest of the **Icons and auras** tab:

- **Aura icons**: **Aura icon borders** (on) makes aura icons square, with a thin border. **Aura icon crop** (8%) trims the icon's edge. **Border colour by debuff type** (on) colours a debuff's border by its type, and a buff you can steal or purge in its own colour. **Stack number size** and **Countdown numbers on party and pet debuffs** (off) work on the party and pet debuffs.
- **PvP flag**: **Both** (the default), **Icon on the portrait**, **Word in the name row** or **Off**, on the player, target and focus frames. **Icon corner** places the icon, and **Time until the flag drops** (on) counts down beside it on your own frame.
- **Icons**: **Leader icon**, **Role icon on player and party frames**, **PvP icon** and the raid marker rows. **Role icons for** limits role icons to **Every role** (the default), **Tanks and healers**, or **Healers only**, on the player, party and raid frames. Main Tank and Main Assist keep theirs.
- **Hit numbers on player and pet portraits** (off at first) brings back the game's big damage and healing numbers over your portrait and your pet's.
- **Totems**: **Totem time left** and **Totem cooldown swipe** (on) show each totem's time under it and a dark sweep across it by the player frame. **Totem time size** is 80%.

### Changes made in a fight

The game protects unit frames in a fight, so some changes wait for its end. This covers the layout rows (**Frame style**, **Portrait size**, **Space between parts**, **Name room**, **Level position**, **Corners**, **Portrait shape**), **Shadow behind each frame**, **Custom pet frame size**, **Dim members out of range**, **Low health border**, the text formats, the party and raid marks and the heal over time squares. While the options window is open, chat says so once a fight, such as "Flat UI: unit frames take their new layout when the fight ends."

### Setup and test mode

The **Your character** stop of `/flatui setup` picks the frame style, the picture and the borders. **Your target and party** picks the health text. Its **For healing** card writes missing health on the party, and turns on **Squares for your heals over time**, **Low health border** and **Dim members out of range**. **More settings** at both stops shows these pages with drawings that follow your choices.

`/flatui test` draws sample party and raid frames, target, focus, pet, boss and totem frames, the pet target frame while its row is on, and a druid's mana bar, each while the real one is not showing. See [Test mode](Test-mode).

## Nameplates

The nameplates have a guide of their own: [Nameplates](Nameplates).

## Cast bars

The **Cast bars** page restyles four cast bars of the game: yours, your pet's, your target's and your focus's. **Restyle cast bars** turns all of it on or off. The page has three tabs: **General**, **Size**, and **Text and icon**. The cast bars on nameplates are set on the **Nameplates** page.

The colours that fill flat cast bars sit on the **Colours** tab of the **Flat UI** page: **Cast colour**, **Channel colour**, **Uninterruptible colour**, **Interrupted colour** and **Crafting colour**. See [Look](Look).

### Borders and fill

Under **Bars** on the **General** tab, **Player cast bar border**, **Pet cast bar border**, **Target cast bar border** and **Focus cast bar border** (all on) give each bar Flat UI's thin border in place of the game's frame art.

**Flat fill** is off at first, so the bars keep the game's gold and green fill inside Flat UI's border. Turn it on for a plain fill in the cast colours. It also unlocks:

- **Bar texture** for every cast bar.
- **Class colour on the player bar**: your class colour on your casts and channels, also on the cast fill of Flat UI's action buttons.
- **Own colours on target and focus bars**, with **Target and focus cast colour** and **Target and focus channel colour** for enemy casts.
- **Border takes the cast colour**: the border turns **Interrupted colour** as a cast is stopped, and **Uninterruptible colour** for a cast that cannot be interrupted.

Other rows under **Look**:

- **Cast bar background** (on) puts a dark background behind each bar that has its border on.
- **Spell name background** (off at first) keeps the game's own background behind the spell name while it is on.
- **Spark** (on) keeps the bright line at the end of the fill on every cast bar.
- **Uninterruptible shield icon** (on) keeps the game's shield beside a target or focus bar whose cast cannot be interrupted.

**Finish flash**, on the **Colours** tab of the **Flat UI** page, is the glow as a cast or channel ends on flat cast bars and nameplate cast bars. **In the cast colour** (the default) flashes in the bar's own colour, so a class-coloured bar no longer finishes with a gold or green flash. **The game's** and **Off** are the other choices.

### Marks on your own cast bar

Three rows under **Look** help you time your next spell. Each works with or without **Flat fill**.

- **Channel ticks on the player bar** (on) draws a thin mark where each tick of a channel lands, such as Arcane Missiles, Blizzard, Mind Flay or Drain Life. Each mark fades as its tick lands, so the ticks left are plain to see, and the marks move with a pushback. **Channel tick colour** (white) can take a dark colour for a pale bar, such as a priest's class colour.
- **Latency zone on the player bar** (off) shades the end of the bar that your connection delay covers, in **Latency zone colour** (red). On a channel it is the left end, where the bar drains to. Queue the next spell as the zone starts.
- **Spell queue window on the player bar** (off) draws a thin line in **Spell queue window colour** (white) where the game starts taking your next spell press. That is the game's spell queue window before the end of the cast, 400 ms unless you changed it. It shows on casts, not channels.

### Interrupts

**Interrupt readiness on enemy casts**, on the **Colours** tab of the **Flat UI** page, is on at first. While your target or focus casts something you can interrupt, its cast bar shows the state of your class interrupt, such as Kick, Counterspell or Pummel:

- **Interrupt ready colour** (green) while it is ready and in range.
- **Interrupt on cooldown colour** (orange) while it cools down.
- **Interrupt out of range colour** (grey-blue) while it is ready but the caster is out of its range.

On flat nameplate cast bars, and on the target and focus bars with **Flat fill** on, the whole fill takes the colour. With **Flat fill** off, a thin strip along the bottom of the target and focus cast bars takes it. **Interrupt strip height** sets the strip from 1 to 6 screen pixels (2 at first). As your interrupt comes back, or you come into range during the cast, the strip blinks once as it turns to **Interrupt ready colour**. A cast that cannot be interrupted keeps its colour.

**Seconds until your interrupt is ready** (on), on the **Text and icon** tab, counts the seconds left on your interrupt inside the left end of the target or focus cast bar, so you see whether Kick is back before the cast lands. It works for a warlock's Felhunter's Spell Lock too. The number goes as the bar turns to **Interrupt ready colour**.

On the **States and text** tab of **Cooldowns**, **Glow on your interrupt** (on) rings your interrupt's icon on the cooldown row in gold while your target or focus casts something you can interrupt and the interrupt is ready. See [Combat](Combat).

#### Interrupt sounds

Four rows under **Sound** on the **General** tab play a sound of your choice. Each is None at first, with the same choices: **Spell alert**, **Chimes**, **Bell**, **Warhorn**, **Raid warning**, **Alarm** or **Whisper warning**. Picking a sound plays it once.

- **Sound when you are interrupted** plays as an enemy's Kick, Counterspell, Pummel, Earth Shock or stun stops your cast or channel, so you hear the lockout while you watch the boss. Moving, jumping or pressing Escape plays nothing.
- **Sound when your interrupt lands** plays as your interrupt, or your Felhunter's Spell Lock, stops an enemy's cast, at most once a second. A kick that missed, came late or came after another player's stays silent.
- **Sound when your focus casts** plays as the enemy you focus starts a cast or channel while your interrupt is ready and in range. It plays again, once a cast, as your interrupt comes back or you come into range during the cast. It needs **Interrupt readiness on enemy casts**.
- **Sound when your target casts** does the same for your target. When your target is also your focus, only the focus sound plays.

`/flatui status` counts the sounds played this session, as "Sound when your interrupt lands: 7 played."

### Size

The **Size** tab sets each bar's size.

- **Player cast bar** at **Width of the personal resource display** (the default) keeps your cast bar as wide as that display, except while Edit Mode's Lock to player frame is on. **Width set below** uses **Player cast bar width**, or the game's 208 while **Custom player cast bar size** is off.
- **Custom player cast bar size** (on at first) sets **Player cast bar width** (266) and **Player cast bar height** (18).
- **Player cast bar text** places the spell name: **As the game has it** (inside the bar while Edit Mode's Lock to player frame is on, under it otherwise), **Below the bar** or **Inside the bar**.
- **Custom pet cast bar size**, **Custom target cast bar size** and **Custom focus cast bar size** (off at first) each give a bar its own width and height.

A size change in a fight lands as the fight ends.

### Text and icon

The **Text and icon** tab sets what the bars write:

- **Text size** and **Text outline** set the spell name. The cast time, the target of the cast and the pushback take the same outline.
- **Spell name** (on) shows the spell name on every cast bar. **Spell rank on the player bar** (off) writes the rank you cast after it, as "Fireball (Rank 5)".
- **Spell name alignment** is **As the game has it**, **Left**, **Centre** or **Right**.
- **Own spell name colour** paints every spell name in **Spell name colour** (white).

The time and the targets of casts:

- **Cast time on target and focus bars** (on) writes the seconds left at the right end of those bars.
- **Cast time on your bars** (off) does the same inside your own and your pet's bars, and hides the game's own time from Edit Mode meanwhile.
- **Total cast time too** (off) adds the whole cast after the seconds left, as "1.2 / 2.5", on the bars of the two rows above.
- **Target of enemy casts** (on) names whom the cast on your target's or focus's bar is aimed at, as "> Bex", just past the bar's right end, in that player's class colour. You see at a glance whether the Shadow Bolt is going at the tank or at a cloth wearer. The name stays while the bar fades or shows Interrupted.
- **Pushback on your bar** (on) adds up how far hits have set your cast back, as "+0.5" in **Pushback colour** (red), just past the right end of your cast bar. A channel cut short shows "-0.8". It pops at each new delay and clears as the next cast starts.

Under **Icon**:

- **Target and focus bar icon** is **Left of the bar** (the default), **Right of the bar** or **Hidden**.
- **Spell icon on player and pet bars** (off) puts the spell's icon left of your cast bar and your pet's, as tall as the bar. It stays while the bar fades or shows Interrupted, so you still see which spell was kicked.

## Personal resource display

The **Personal resource display** page restyles the game's health and power bars under your character. **Restyle the personal resource display** turns it on or off. The page has two tabs: **General** and **Your buffs**.

### Bars, fill and text

On the **General** tab:

- **Bars**: **Health border**, **Power border**, **Alternate power border** and **Resource bar background** (all on) frame each bar and put a background behind it. **Join bars** (on) removes the space between the bars.
- **Fill**: **Flat fill** (on) gives the bars a plain fill, in **Bar texture**. **Custom health colour** (on) fills the health bar in **Health colour**, and **Class colour** (off) uses your class colour instead. **Custom power colour** (off) gives every power type one **Power colour**. **Colour health by health left** (off) shades the health bar from green to red as it drops.
- **Text**: **Text size**, **Text outline**, **Health and power numbers** with **Percentage text** and **Value text**, and **Own text colour**.

### Absorb shields on the health bar

**Absorb shields on the health bar** shows your shields, such as Power Word: Shield or Ice Barrier, on the display's health bar. It works in a fight.

- **Bright layer over the health** (the default) lays a silvery layer that starts where your health ends, with a thin bright edge where the shield ends. A shield bigger than your missing health runs on back over your health, so its full size still shows. As hits eat the shield, the layer glides down.
- **Plain fill after the health** stops the shield at the end of the bar.
- **Off** shows no shield.

**Shield colour** and **Shield opacity** (60%) set the layer. With the bright layer, **Sheen** (on) sweeps a slow light across it every few seconds, and **Shield outline** (on) frames the health bar in the shield colour while a shield is up. **Shield amount** (off) writes the amount beside the health number, inside the bar, as "+1,234".

`/flatui test` lays a sample shield over the display.

### Your buffs

The **Your buffs** tab shows a row of the short buffs you cast, each with its time left, by the personal resource display. **Your buffs** at the top turns it on or off.

What it shows:

- **Buffs shown** picks **Short buffs of your class** (such as Slice and Dice, Shield Block or Ice Barrier), **Every buff you cast**, or **Both** (the default).
- **Time limit** (60 s, from 10 to 600) leaves out buffs that last longer.
- **Buffs that have a tracker** at **Show here too** (the default) keeps buffs that a tracker also watches. **Leave out** drops them. Trackers are on the **Trackers** page: see [Combat](Combat).
- Your own defensives, such as Shield Wall or Ice Barrier, are left out while **Defensives on you** shows them.

How the icons look:

- **Time left** is **On the icon** at first, or **Under the icon**, **Thin bar under the icon** or **Off**. The time turns amber in its last 5 seconds.
- **Icon size** (40), **Spacing** (3) and **Icon border** (on) set the icons. The numbers grow and shrink with the icon.
- **Flash when one lands** (on) gives an icon a quick white flash as its buff comes, also in a fight, though not when you cast a buff again while it shows.
- **Sound when one ends** (None at first, or **Raid warning**, **Alarm** or **Whisper warning**) plays once as one of your class's short buffs leaves you, also in a fight. A buff with a tracker is left out, since the tracker has its own sound.
- **Buff tooltips** shows the game's tooltip over an icon **On**, **Out of combat only** or **Off**. A click still goes through to the world.

Where it sits:

- **Place** is **Above the bars** (the default), **Under the bars**, **Under the swing timer** (under the bars while there is no swing timer) or **Own position**. **Own position** gives the row a handle in `/flatui move`.
- **X offset** and **Y offset** move the row from where **Place** puts it.
- If the personal resource display has no position, the row sits above the player frame.

Out of combat, with none of these buffs up, a change to the look or the place shows sample icons for a few seconds. `/flatui test icons` shows three samples of your own class's buffs for 8 seconds, and `/flatui buffs check` says how the row is drawn and where it hangs.

## Swing timers

The **Swing timers** page restyles the game's main hand, off hand and ranged swing timers. They show while the game's Enable Swing Timer option is on and their Edit Mode Visibility is not Hidden. The off hand and ranged timers need such a weapon. **Restyle swing timers** turns the page on or off; off leaves the timers as the game draws them.

### Look

- **Timers**: **Main hand border**, **Off hand border** and **Ranged border** (all on) give each timer Flat UI's thin border in place of the game's frame art.
- **Width** at **Width of the personal resource display** (the default) keeps the timers as wide as that display. **Width set in Edit Mode** uses the game's width.
- **Border around** frames the **Bar only** (the default) or the **Whole timer**, with its name and time. **Timer background** (on) puts a dark background behind each timer.
- **Fill**: **Flat fill** (on) gives a plain fill in **Main hand colour**, **Off hand colour** and **Ranged colour**, or in your class colour with **Class colour**. **Bar texture**, **Spark** (on) and **Text shadow** (off) need it. **Fill from the right** (off) grows the fill from the right end.
- **Text**: **Text size**, **Text outline**, **Timer name** and **Time left** (on), and **Own text colour** with **Text colour** and **Out of range text colour**.

### Auto Shot and the next melee ability

**Auto Shot window** (on) marks the last half second of the ranged timer in **Auto Shot window colour**. Moving or casting a spell then delays your next Auto Shot.

**Queued next melee ability** (on), under **Next melee ability**, is for a warrior, druid or hunter. The main hand timer turns **Queued ability colour** (orange) while Heroic Strike, Cleave, Maul or Raptor Strike waits for your next swing, and takes its own colour back as the swing lands. A late or forgotten queue shows at a glance.

### When the timers show

- **Out of range opacity** (40%, the game's own) sets how see-through a timer is while your target is out of its reach.
- **Show the timer** is **Always**, **In combat** (the default) or **Only while swinging**. **In combat** and **Only while swinging** fade the timer and its border out over a quarter second as the fight ends or the swings stop. It works while the timer's border is on. With Edit Mode's own Visibility at In combat, the game hides the timer itself, at once.

`/flatui test` shows the swing timers while the game would show them.

## Commands for this page

| Command | What it does |
| --- | --- |
| `/flatui move` | Shows or hides a box for every frame. Drag a box to move its frame. The target of target frame moves with the target frame. |
| `/flatui test` | Turns test mode on or off: sample unit frames, cast bars, swing timers and a sample shield on the personal resource display |
| `/flatui test icons` | Shows three sample icons for 8 seconds on **Your buffs** and the other icon rows |
| `/flatui buffs check` | Says how the **Your buffs** row is drawn, its groups and where it hangs |
| `/flatui art` | Lists the textures shown on the player and target frames |
| `/flatui status` | Says what is styled, and any error. It also counts the interrupt sounds played this session. |
| `/flatui setup` | Walks through setup, where **Your character** and **Your target and party** set up the unit frames |

Every setting of this group, with its default: [Settings: Frames and bars](Settings-Frames-and-bars).
