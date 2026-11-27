Flat UI gives the game's nameplates a flat look and adds what you need in a pull: your threat on each enemy, a clear mark on your target, combo points, the Overpower window, quest marks and kill counts. Every row described here is on the **Nameplates** page, in the **Frames and bars** group of the options window.

![Flat UI in a fight: the player and target frames, the enemy's cast bar, combat numbers in front of the nameplate, proc art and the action bars](https://raw.githubusercontent.com/dismlx/flat-ui/main/media/flatui-in-play.jpg)

## General

The **Nameplates** page has nine tabs, in this order: **General**, **Health bar**, **Colours**, **Threat**, **Text**, **Cast bar**, **Marks and icons**, **Auras** and **Size and clicks**. Each section below covers one tab.

### Turning it on

- **Restyle nameplates** (on) gives nameplates Flat UI's look and every part on the other tabs, from threat to quest marks. Off, nameplates keep the game's own look.
- **Restyle friendly nameplates** (on) does the same for friendly nameplates. Off, friendly nameplates keep the game's look and size, while enemies keep Flat UI's. **Click through friendly nameplates** works either way.

### Border and background

Nameplate bars take the borders and backgrounds of the **Flat UI** page at first (see [Look](Look)). Turn on **Own border and background**, under **Border and background**, to give them their own:

- **Border colour**, for the thin borders round nameplate bars.
- **Background colour**, seen where a bar is empty.
- **Background opacity** (85%). At 0% the background is clear.

### Seeing your changes

- Every tab of **Nameplates** has a preview band at the top that draws a sample nameplate with that tab's rows. On the **Threat** tab it draws one sample for each threat state, with its ring, threat value, the enemy's target and its fade. Pointing at a threat row brackets the sample it changes.
- In **Test mode**, a sample nameplate sits in the middle of the screen. It is your target, with its mark, a cast, a quest mark and a kill count, and it takes each threat state in turn. See [Test mode](Test-mode).
- In **Flat UI setup**, the **Enemies' nameplates** stop offers three cards: **Plain plates**, **Taller, with cast times** and **Small and quiet**. Its **More settings** opens seven steps, each with a drawing that follows your choices: **Nameplate health bar**, **Nameplate text**, **Nameplate colours and threat**, **Nameplate cast bar**, **Nameplate auras**, **Marks and icons** and **Nameplate size, distance and clicks**. See [Getting started](Getting-started).

### In a fight

The game protects nameplates in a fight, so some changes wait for the fight to end:

- the size of a nameplate: **Restyle friendly nameplates**, **Health bar height**, **Nameplate cast bar height**, **Bar width**, **Level box shape**, **Raid marker size** and the class icon rows;
- the clickable area, from the rows under **Clickable area**;
- every game setting, from the rows under **Which show**, **Size and stacking** and **Scale and fade**, and **Target nameplate size**, **Other nameplates' opacity**, **Aura size** and the two class colour rows.

While the options window is open, chat says so once a fight: "Flat UI: nameplates take their new size when the fight ends.", "Flat UI: nameplate clicks change when the fight ends." or "Flat UI: nameplate game settings change when the fight ends."

On a nameplate the game first shows in a fight, a few marks also wait for the end of the fight. `/flatui status` counts the plates that waited.

## Health bar

These rows are on the **Health bar** tab.

### Look

- **Health bar border** (on) draws a thin border in place of the game's frame. Several rows need it: **Dim other nameplates**, **Mouseover border**, **Target and focus border**, **Border colour for Elite and Rare** and **Threat colour on the health bar border**.
- **Health bar background** (on) puts a dark background behind the bar, so its empty part reads against the world.
- **Flat health bar** (on) gives the bar one plain colour in place of the game's gloss. **Health bar texture** picks its fill. **Same as the Flat UI page**, the default, takes the **Bar texture** of the **Flat UI** page.

### Size

- **Health bar height** is 125% at first. 100% is the game's own height, and it goes from 50% to 200%.
- **Bar width** narrows the health bar and the cast bar together, from the game's own width at 100% down to 50%.

Both work on top of the game's **Nameplate style** and **Nameplate size**, on the **Size and clicks** tab.

### Dimming

**Dim other nameplates** (on) darkens every nameplate that is not your target or focus, so those two stand out. **Dim strength** (60%) sets how dark the others go.

### Health bar art

Under **Health bar art**, three rows keep the game's own fills on the bar. All three are on. Turn one off to hide that fill on nameplates.

- **Incoming heals**: heals on their way, just past the health.
- **Absorb shields**: the light fill of a shield that soaks up damage, such as Power Word: Shield.
- **Heal absorbs**: the dark fill over health that heals must undo before they count.

## Colours

These rows are on the **Colours** tab. When more than one colour could paint a health bar, **Colour the target's health bar** comes first, then the threat colours of the **Threat** tab, then reaction colours, then the colours of **Colour health bars by health left**.

### Reaction

- **Reaction colours on health bars** (on) paints hostile, neutral and friendly units in the reaction colours of the **Colours** tab of the **Flat UI** page. Units tapped by another player keep the game's grey unless **Custom reaction colours** is on there, and dead units keep the game's colour.
- **Players** chooses how players are painted. **As the game has it** (the default) leaves them to the two class colour rows below. **By reaction** gives them reaction colours like everyone else.
- **Class colours on enemy players** and **Class colours on friendly players** are the game's own settings. On, the game colours a player's health bar by class, a rogue yellow and a mage light blue, and nameplates repaint at once. Both show the game's own value, off as this game has them at first, and Flat UI writes nothing until you change them.

### Target

**Colour the target's health bar** (off) gives your target's health bar **Target health bar colour**, ahead of threat and reaction colours.

### Mouseover

**Mouseover border** (on) draws a light border round the nameplate under the mouse, in **Mouseover colour**.

### Health left

- **Colour health bars by health left** (off) paints bars in the three health colours of the **Colours** tab of the **Flat UI** page, from full to low as health drops. The target's colour, threat colours and reaction colours come first. With **Reaction colours on health bars** on, they cover most enemies, so turn that row off to see the health colours on them.
- **Low health border** (on) lights the health bar border in **Low health border colour** (red) once health drops below **Low health below** (20%, from 5% to 50%).
- **Line at Low health below** (on) draws a thin line in **Low health border colour** across the health bar of each enemy in a fight at **Low health below**. A warrior sees Execute range coming before the border lights. Enemies out of a fight, such as the mobs a player rides past while questing or a pack before the pull, show none, and the line comes as the fight starts. It moves at once with the slider, keeps its place as the bar changes size and stays one screen pixel wide on your target as the game enlarges it.

## Threat

These rows are on the **Threat** tab. Threat on nameplates is on at first. It shows on the enemies the game gives your threat for, which are the ones in a fight with you, or with your pet while **Your pet's threat counts** is on. Enemy players never show threat.

### How threat reads

**Threat on nameplates** (on) turns the whole tab on, and **Colour health bars by threat** (on) paints each enemy's health bar in its threat colour. Each enemy takes one of three states, and what counts as good depends on your role:

| State | While you tank | While you deal damage or heal |
| --- | --- | --- |
| **Threat you want** | An enemy you hold securely | An enemy on someone else |
| **Threat changing hands** | An enemy close to turning to you or away from you | An enemy close to turning to you or away from you |
| **Threat you do not want** | An enemy on someone else | An enemy on you |

The colour of **Colour the target's health bar** still wins on your target while that row is on.

### Your role

**Your role** decides which column you are in:

- **From your role, stance or form** (the default) takes the role your group gave you. Without one, Main Tank, a tank aura, Defensive Stance, Bear Form or Righteous Fury make you a tank. Otherwise you count as damage or healer.
- **Tank** or **Damage or healer** fixes your role.

`/flatui role` says how you are read and why, and can set it. The commands are at the end of this page.

### Threat colours

- **Threat you want** (green), **Threat changing hands** (yellow) and **Threat you do not want** (red) set the three colours.
- **Same colours for both roles** (on) uses those three for both roles. Turn it off, and they become a tank's colours. While you count as damage or healer, **Threat you want as damage or healer**, **Threat changing hands as damage or healer** and **Threat you do not want as damage or healer** take over.
- **Enemies held by another tank** (on): while you count as a tank, an enemy that another tank of your group or your pet holds takes **Another tank's colour**. It is not taken for a loose one.

### Whose threat

- **Your pet's threat counts** (on): an enemy your pet holds shows as held for you before you hit it. While you count as a tank with **Enemies held by another tank** on, it takes **Another tank's colour**.
- **Early warning while tanking** (off): as a tank, an enemy you hold securely shows as changing hands while someone else comes close to your threat.

### Which enemies

The rows under **Which enemies** pick the kinds of enemy that show threat. All of these are on:

- **Normal enemies**: ordinary enemies, not Elite, Rare, a boss or minor.
- **Elite and Rare enemies**: Elite, Rare and Rare Elite.
- **Bosses**: enemies whose level shows as a skull.
- **Minor enemies**: totems and other units the game counts as minor or trivial.
- **Neutral enemies**: units that do not attack until you do.
- **Enemies tapped by others**: their health bar keeps the game's grey.

**Only in dungeons and raids** (off) shows threat only inside a dungeon or a raid, and none in the open world or a battleground.

### The threat ring

These rows are under **Glow and opacity**.

- **Threat glow** draws a ring in the threat colour round the health bar. **When the enemy needs you** (the default) leaves out threat you want, so only the enemies you should act on are ringed. **Every threat state** rings every enemy, and **Off** draws none.
- The ring fades in over 0.15 seconds as it comes and out as it goes, so the rings of a big pull do not blink.
- **Threat ring thickness** is 2 px at first, from 1 to 6. It is in screen pixels, so it keeps its thickness at any resolution. Raise it on a large screen. It grows outward, clear of an elite's border.
- **Flash the ring when threat goes wrong** (on) flashes the ring twice as an enemy turns to you, or away from you while you tank.

### Fading enemies held for you

- **Fade enemies held for you** (on) fades the enemies whose threat you want, so the ones that need you stand out. Your target and focus never fade. Enemies ease to their new opacity over a fifth of a second as threat moves, so the pack does not blink.
- **Opacity of enemies held for you** (75%) sets how solid they stay. Lower fades them more, and 100% keeps them clear.
- **Same opacity for both roles** (on). Off, the opacity above is a tank's, and **Opacity as damage or healer** (75%) is used while you count as damage or healer.
- **Opacity of enemies changing hands** (100%) can fade those too. At 100% they stay clear.
- **Raid-marked enemies stay clear** (off): an enemy with a raid marker never fades, like your target and focus, and keeps its colour, glow and threat value.

### Threat on the border, background and name

These are all off at first.

- **Threat colour on the health bar border** puts the threat colour on the border. Your target, focus and mouseover keep their own border colour. It needs **Health bar border**.
- **Health bar background in the threat colour** puts a dark shade of the threat colour behind the bar while threat colours the bar. It needs **Health bar background**.
- **Threat colour on the name**, under **Threat text**, gives an enemy's name the threat colour in place of **Name colour**. **Health text in the name's colour** gives the health text that colour too.

### Enemies you are losing

These rows are for tanks. They work only while you count as a tank, and show nothing on enemies you hold.

- **Mark enemies you are losing** (on) puts a soft glow, in the threat colour, just outside the threat ring of each enemy changing hands or on someone else. It pulses slowly while the enemy slips and fast once it is lost. A small arrow above the plate points down at it, over the threat value, the debuffs, the Overpower icon and an **Above** quest mark when they show. The arrow is edged in black all round, as the arrows at your target are, so it reads on snow or lava, and its width follows the health bar's height, from 12 to 24 px.
- **Magnified plate for enemies you are losing** (on) gives an enemy you are losing a magnified copy of its plate. It is drawn over the plate and above every other plate, with its health bar in the threat colour, its name, its raid marker, the glow and the arrow. The magnified plate of your target or focus also carries the **Target and focus border** in **Target colour** or **Focus colour**, so the enemy you tab to stands out.
- The magnified plate also carries the threat value, outside its bar and raid marker on the side **Threat value position** sets, in the value's own colour and font at the magnified size, so a tank still reads "Mage 92%" on exactly the enemies they need to judge. It carries the health text inside its bar and the **Line at Low health below** too. The plate's own name, raid marker and threat value fade out under it over 0.15 seconds and come back as it shrinks away, so nothing shows twice.
- The magnified plate's arrow stands just over the highest of the plate's debuffs, its Overpower icon and an **Above** quest mark, and moves as they come and go, as the plate's own arrow does.
- While the enemy casts, the magnified plate's bottom edge eases up to the health bar's own, so it grows up and sideways and the cast bar stays clear for a Shield Bash. It grows about the centre again once the cast ends.
- On your target, the **Target mark**, its glow and its arrows hug the magnified bar and stay above every magnified plate, and **Flash as you change target** plays round the magnified bar. Test mode's sample does the same.
- The magnified plate grows with how far your threat has slipped. It starts at the plate's own size once another member reaches **Slipping at** of your threat (80% at first, on the **Threat list** page; see [Group](Group)). It reaches **Size of an enemy you have lost** (150%, from 100% to 200%) once they reach 110%, or once someone else holds the enemy.
- It shrinks back and goes once you take the enemy back and their share falls under **Slipping at**. Where the game withholds the threat, or you are not in a group, an enemy changing hands is drawn halfway and one on someone else at full size.
- The magnified plate takes no clicks, so a click still reaches the enemy's plate under it. It is made of Flat UI's own frames, so it works in a fight. The game's own plate is never resized or moved.
- **Flash as you take an enemy back** (on): as an enemy someone else held turns back to you, its glow flashes once in **Threat you want** and fades over about half a second, so you see your taunt land. An enemy that only changes hands and back, as **Early warning while tanking** shows, does not flash.

`/flatui status` counts the enemies marked lost and slipping and the plates shown magnified, or says the marks are off while you do not count as a tank.

### Threat value

The rows under **Threat text** put a number beside the health bar.

- **Threat value** picks the number:
  - **Share of aggro** (the default): 100% is the point at which the enemy turns to you.
  - **Share of the tank's threat**: your threat as a share of the tank's.
  - **Lead while tanking**: the game's own lead figure while you hold the enemy, and your share of the tank's threat otherwise.
  - **Off** shows no number.
- **Show threat value** picks when. **In a group or with a pet** (the default) hides it while you play alone with no pet, when every enemy is on you anyway. **Only in a group** hides it with a pet too, and **Always** shows it at all times.
- **Threat value in the threat colour** (on). Off, the value takes **Threat value colour** (white).
- **Threat value size** (100%) is a share of the game's health text size.
- **Threat value outline** (**As the game has it**) takes the outline of the game's health text.

The number fades in over 0.15 seconds as it comes and out as it goes, so it does not flicker over a whole pull.

### Where the threat value sits

**Threat value position** puts the number outside the health bar:

- **Left** (the default): left of the bar, past the raid marker, the elite or rare icon and the enemy's buffs. It moves as a marker comes or goes and as the number grows.
- **Right**: right of the bar, past the enemy's crowd control icons, such as a polymorph, a sap or a stun.
- **Above**: over the name and the enemy's debuffs, rising as their row wraps. An **Above** quest mark and the Overpower icon stand over it.
- **Below**: under the cast bar, and under your target's combo points while they show.

**Threat value horizontal offset** and **Threat value vertical offset** (-40 to 40) nudge it from there.

### The enemy's target

**Name of the enemy's target** (off), under **Enemy's target**, shows who the enemy attacks, right of the health bar, in the class colour of a player. It fades in and out as the threat value does. Three rows narrow it:

- **Only in combat** (on): only while you are in a fight.
- **Only on your target** (off): on your target's nameplate alone.
- **Not when it attacks you** (on): leaves out your own name, so only an enemy that attacks someone else shows whom it attacks.

## Text

These rows are on the **Text** tab.

### Font

**Text font** (**Game font**) sets the font of the name, the health text and the spell name.

### Name

- **Show name** (on). Off hides the name, and the marks and icons over it move down to the bar or to the debuffs.
- **Name size** (100%) and **Name outline** (**As the game has it**).
- **Name colour**: **As the game has it** (the default), **White**, **Class**, **Reaction** or **Custom**. **Class** gives players their class colour and others their reaction colour. **Reaction** gives every name hostile, neutral or friendly. **Custom** takes **Custom name colour**.

### Health text

- **Health text** (on). Untick it to hide the health number.
- **Health text size** (80%), **Health text outline** and **Health text colour** (white) set its look.
- **Show health text**: **Always** (the default), **Only on the target**, or **On the target and focus**. The last keeps the health of your sheep, sap or shackle in sight on your focus's nameplate as you tab to something else. At either of the last two, the number eases out on the old target and in on the new one over 0.15 seconds.
- **Health text format**: **As the game has it** (the default), **Current**, **Current / max**, **Percent**, **Current and percent** or **Missing**. **Missing** shows the health lost, as "1.2K", and leaves an unhurt enemy blank.

### Level

- **Level box**: **Thin border** (the default), **Text only** (the number without the box), **Default** (the game's box) or **Hidden**.
- **Level box shape**: **Square** (the default) is a box as tall as the health bar at its end, and the bar shortens to make room. **Game width** keeps the game's wider box past the end of the bar.
- **Level box gap** (0 to 6) puts space between the bar and a **Square** box.
- **Level number size** (100%).

With **Level box** at **Hidden**, the icons and texts right of the bar start right at its end.

### Elite and Rare

- **Mark after the level** (on) adds + for an Elite, R for a Rare and R+ for a Rare Elite.
- **Fading row behind the name** (off) puts the friendly, neutral or hostile colour behind the name, fading upward.

## Cast bar

These rows are on the **Cast bar** tab. They style the cast bar under a nameplate while the unit casts.

### Look and size

- **Nameplate cast bar border** (on) draws a thin border in place of the game's frame. **Nameplate cast bar background** (on) puts a dark background behind it.
- **Flat nameplate cast bar** (on) uses the cast colours of the **Colours** tab of the **Flat UI** page: **Cast colour**, **Channel colour**, **Uninterruptible colour** and **Interrupted colour**. **Cast bar texture** picks its fill.
- **Nameplate cast bar height** (100%) sets its height against the game's own.

### Spell name and parts

- **Spell name size** (100%), **Spell name outline** and **Spell name colour** (white) style the spell name.
- **Spell icon size** (100%) sets the size of the spell's icon.
- **Spark** (on) keeps the game's bright spark at the moving end of the bar.
- **Shield on uninterruptible casts** (on) keeps the game's shield at the icon of a cast you cannot interrupt.

### Cast time

**Cast time** (on) shows the seconds left at the right end of the bar, in the spell name's font, size and outline. While the bar names the cast's target, the seconds sit just past the end of the bar, clear of that name.

### Interrupt readiness

With **Flat nameplate cast bar** on, an enemy cast you can interrupt shows whether your class interrupt is ready:

- **Interrupt ready colour** (green) while it is ready and in range;
- **Interrupt on cooldown colour** (orange) while it cools down;
- **Interrupt out of range colour** (grey-blue) while it is ready but the caster stands out of its range.

A cast that cannot be interrupted keeps its colour. These rows, with **Interrupt readiness on enemy casts** (on), are on the **Colours** tab of the **Flat UI** page. So is **Finish flash**, the glow as a cast or channel ends, which takes the bar's own colour at first. The target and focus cast bars of the **Cast bars** page show your interrupt too: see [Frames and bars](Frames-and-bars).

## Marks and icons

These rows are on the **Marks and icons** tab.

### Target and focus

- **Target and focus border** (on) puts a coloured border on your target's and your focus's nameplates: **Target colour** (white) and **Focus colour** (orange). **Target and focus border thickness** is 1 px, up to 4.
- **Flash as you change target** (on): the nameplate you take as your target flashes once. A thicker outline in **Target colour** fades over about a third of a second and leaves the normal border behind, in a fight too. With Tab in a pack, you see at once which nameplate it took. Setting a focus flashes the focus's nameplate in **Focus colour**. It needs **Health bar border** and **Target and focus border**.
- **Target nameplate size** is the game's own size of your target's nameplate against the others, 120% as the game has it, up to 200%.
- **Other nameplates' opacity** is the game's own fade of every other nameplate while you have a target. 100% is no fade, and 80% is a light one.

Both game rows show the game's value, and Flat UI writes nothing until you move them.

### Target mark

**Target mark** (on) draws a bright outline round your target's health bar and its level box, in **Target mark colour** (white), clear of the threat ring. Your target reads at a glance in a pack.

- **Soft glow round the mark** (on) adds a glow in the same colour, fading out from the outline, or from past the threat ring while that shows.
- **Arrows at your target** (on) adds two arrows in the same colour, edged in black so they read on bright ground. They point in at the bar from both sides, outside whatever sits beside it: the class icon, quest mark, level box, raid marker, elite icon, threat value and auras. They move out as the threat value grows in a fight.
- **Arrow size** (100%, from 50% to 200%). At 100% each arrow is about twice as tall as the bar.
- **Arrows turn red in Low health** (on): once your target drops under **Low health below** (20%), the two arrows turn **Low health border colour**. A warrior, paladin or hunter sees Execute or Hammer of Wrath range on the brightest thing on screen. The arrows turn back as the target heals or you change target.
- **Arrows move** (on): on each new target the arrows slide in from 8 px further out over 0.15 seconds. While the target stays, they push in and out by 2 px about once a second, so the eye finds the target in a busy pull. Off keeps them still. Setup's **Marks and icons** drawing and test mode's sample move the same way.
- **Mark your focus too** (off) gives your focus its own outline, glow and arrows in **Focus colour**, so the enemy a mage or rogue keeps for Polymorph or Sap stays easy to find in a pack. They follow its nameplate in a fight too, and are left off while your focus is also your target. Your target's mark stays on top of it.

The mark is Flat UI's own frame over the screen, not a part of the nameplate. It follows the health bar every frame, so it shows at once, also on a nameplate the game first shows in a fight. It sits above every other nameplate and takes the nameplate's own fade, so it dims with a target behind a wall. **Flash as you change target** flashes just past the mark's outline. On an enemy shown magnified as one you are losing, the mark follows the magnified bar.

`/flatui status` counts the targets marked so far, and the focuses too while **Mark your focus too** is on.

### Class icons

- **Class icon on enemy players** (on) puts the icon of an enemy player's class at their nameplate, so a healer stands out before their colours do. **Class icon on friendly players** (on) does the same for friends.
- **Class icon position**: **Left** (the default), **Right**, **Above** or **Below**. On a friendly player shown as a name only, it stands above the name.
- **Class icon size**: **Health bar height** (the default) keeps the icon as tall as the bar. **Custom** takes **Custom class icon size** (20).
- **Class icon gap**, **Class icon horizontal offset** and **Class icon vertical offset** move it.
- **Class icon shape** (**Square** or **Round**) and **Class icon border** (on) set its look.

### Elite and Rare

**Border colour for Elite and Rare** (on) colours the border of these enemies' nameplates: **Elite colour** (gold), **Rare colour** (silver) for a Rare or Rare Elite, and **Boss colour** for an enemy whose level shows as a skull. A Rare Elite also gets a thin inner line in **Elite colour**. Your target and focus keep their own border colour.

### Raid marker

- **Raid marker** (on) keeps the game's raid marker left of the health bar. Off hides it on nameplates.
- **Raid marker size** (22) and **Raid marker horizontal offset** and **Raid marker vertical offset** (-40 to 40) set its size and place.
- **Arrow for nameplates behind you** (on) keeps the game's arrow at the edge of the screen for nameplates behind you.

### Overpower, Mongoose Bite and Riposte

**Overpower, Mongoose Bite or Riposte on enemy nameplates** (on) shows the window of a strike that follows a dodge or a parry, over the nameplate:

- For a warrior: when an enemy dodges you, the Overpower icon shows over that enemy's nameplate for 5 seconds. The game does not say whose attack was dodged, so a dodge counts as yours when that enemy is your target and you are in melee with it, or when Overpower turns usable at once after it.
- For a hunter: when Mongoose Bite turns usable after you dodge, its icon shows over your target for 5 seconds. It follows a change of target, since the bite can hit any enemy in melee. Targeting a friend hides it until you target an enemy again.
- For a rogue: when Riposte turns usable after you parry, its icon shows over your target for 5 seconds, and follows a change of target the same way.

You need to know the spell. How the icon behaves:

- It pops in as it comes, and pops again when a new dodge or parry renews it.
- It glows while you can use the spell now. It is grey and still while you cannot: the wrong stance, too little rage, the cooldown, or, for a hunter or rogue, only mana or energy short. A dodge or parry while energy or mana is short pops it at once, grey, and it lights up as the energy or mana comes in.
- **Time left on the Overpower icon** (on) drains a dark swipe over it for its 5 seconds.
- **Seconds on the Overpower icon** (on) counts down 5, 4, 3, 2, 1 in the middle of the icon, turning amber at 2 and red at the last second, so you know whether the next swing still makes it.
- It fades away when its 5 seconds run out or the game ends the window early. It goes at once when you cast the spell, or when the enemy dies or its nameplate goes.

It sits just over the enemy's debuffs, rising as their row wraps, or over the name while that row is empty or hidden. With **Threat value position** at **Above**, it stands over the value. **Overpower icon size** (34), **Overpower icon horizontal offset** and **Overpower icon vertical offset** (-40 to 40) set its size and place, and an **Above** quest mark moves with it.

### Combo points

A rogue, or a druid in Cat Form, sees their combo points under their target's nameplate with **Combo points on your target's nameplate** (on). Five small squares sit just under the cast bar of your target's nameplate:

- Points you have light in **Combo point colour** (a warm red), and the rest show faintly. The newest pops as it lands, in a fight too.
- **Full points stand out** (on): as the last point lands, every square turns **Full points colour** (gold) and they pop together, so "finish now" reads at a glance.
- **Full points breathe** (on): while you sit at full points, the gold row breathes softly until a finisher spends them.
- **Combo point size** (7, from 4 to 16) and **Combo points vertical offset** (-20 to 20) resize and move the row. A **Below** threat value moves with it.

The row fades in as the first point lands and out as a finisher spends the points. It moves to the new nameplate as you change target, and hides at 0 points. On an enemy player whose class icon is at **Below**, the row hangs just under the icon.

### Quest marks

**Quest mark on enemies you need for a quest** (on) puts a small ! beside the nameplate of each enemy the game says belongs to a quest in your log. It fades in as it comes and fades away once that objective is done.

- **Kill count beside the quest mark** (on): on an enemy you have to kill, a small gold count such as 3/8 sits beside the mark. It counts up with each kill and turns green at 8/8 as the objective completes. An enemy that only drops a quest item shows the mark alone.
- On an enemy someone else has tapped, the mark turns grey and faint, since killing it will not count.
- **Quest mark size** (14) sets the size of the mark and its count.
- **Quest mark position**: **Left** (the default) goes past the threat value, the enemy's buffs, the raid marker and the elite or rare icon. **Right** goes past the level box, the threat texts and the enemy's crowd control icons. **Above** sits over the debuffs, an **Above** threat value and the Overpower icon.
- **Quest mark horizontal offset** and **Quest mark vertical offset** (-40 to 40) nudge the mark and its count.
- **Leave quest marks to Questie** (on): while that addon draws its own icons on quest enemies, Flat UI's mark stays away. In dungeons, and while that addon's nameplate icons are off, Flat UI's marks show. Turn the row off to show both.

## Auras

These rows are on the **Auras** tab. They style the game's buff and debuff icons on nameplates.

### Icon look

- **Aura icon border** (on) makes the icons square with a thin border. **Aura icon crop** (8%) cuts away the edge of each icon, so the art fills the square.
- **Own aura border colour** (off) gives the icon borders **Aura border colour** in place of the usual border colour.
- **Countdown numbers** (on) and **Stack count** (on) keep the game's time and stack numbers on the icons.
- **Aura opacity** (100%). Lower lets what is behind the icons show through.

### Aura size

**Aura size** (100%, from 70% to 140%) is the game's own size of the buff and debuff icons on nameplates. Raise it for larger Rend, Sap or Rejuvenation icons. The Overpower icon, an **Above** threat value and an **Above** quest mark rise with the taller row.

### Which nameplates show auras

**Show auras** picks where auras show:

- **On every nameplate** (the default).
- **Only on the target**.
- **On the target and focus**, so a mage keeps the sheep in sight on the focus's nameplate, and a rogue the sap.

At either of the last two, each change of target or focus eases the old row out and the new one in over 0.15 seconds, so Tab does not make the debuff rows blink. The threat value, the quest mark and the Overpower icon that stand by the aura rows follow both nameplates.

## Size and clicks

These rows are on the **Size and clicks** tab. Apart from the rows under **Clickable area**, they are the game's own settings. Each shows the game's live value, and Flat UI writes nothing until you move it. A row whose setting the game locks or keeps read-only is not offered. On WoW: Forever that is **Cast bars on nameplates**.

### Clickable area

- **Click through friendly nameplates** (off) lets clicks pass through friendly nameplates to what is behind them, whether or not **Restyle friendly nameplates** is on. **Where friendly nameplates are clicked through** chooses **Everywhere** or **In dungeons and raids**, which switches as you zone in and out, after the fight if you zone in during one.
- **Click through enemy nameplates** (off) does the same for enemies. Target them with Tab or a key binding.
- **Extra clickable width** (-10 to 30) and **Extra clickable height** (-10 to 20) widen or heighten the part of a nameplate that takes a click, as far as the nameplate reaches. Below 0 they narrow it.

### Which show

- **Enemy nameplates**, **Friendly player nameplates** and **Friendly NPC nameplates** turn each kind on or off. The game's V key does the same for enemies, and Shift+V for friendly players, and the rows follow those keys. If your plates vanished after pressing V, or you want friendly plates in a battleground, turn them back on here.
- **Always show nameplates**. Off, nameplates show only while you are in a fight.
- **Nameplate distance**: how far away, in yards, nameplates still show, from 10 to 60.
- **Nameplates on enemy pets and totems**: off hides the plates of a hunter's pet or a shaman's totems. It needs **Enemy nameplates**.
- **Nameplates on minor enemies**: weak enemies the game counts as minor. It needs **Enemy nameplates**. **Minor enemies** on the **Threat** tab says whether they show threat.
- **Friendly players as names only**: the game shows a friendly player's name without a health bar. It needs **Friendly player nameplates**.

### Size and stacking

- **Nameplate style**: **Thin** is a slim health bar and cast bar, **Modern** a taller health bar and level box, **Block** a tall health bar and a tall cast bar, and **Cast focus** a slim health bar with a tall cast bar.
- **Nameplate size**: a step from 1 to 5. The percentages of the other tabs work on top of it.
- **Spread of enemy nameplates** picks one of three looks for a pack:
  - **Overlap, as the game has it**: the plates of a pack lie over each other.
  - **A slight spread**: the game's stacking for enemies with **Vertical overlap** at 70%, and the plates move a little slower. A pack still clusters, but every plate shows.
  - **Stack them**: the game's full stacking. It puts **Vertical overlap** back to 110% if it was below 90%.
- **Spread of enemy nameplates** sets **Stack enemy nameplates** and **Vertical overlap**, and follows them, so a change to either shows on it at once.
- **Stack enemy nameplates** and **Stack friendly nameplates** turn on the game's stacking. The plates of a pulled pack move apart up and down into a readable column instead of covering each other.
- **Horizontal overlap** and **Vertical overlap** set the spacing while plates stack. A higher **Vertical overlap** spreads them further apart, which makes room for taller bars, and a lower one lets them cluster. A lower **Horizontal overlap** keeps them further apart sideways.
- **Nameplates at the unit's feet** puts other units' nameplates at their feet instead of over their heads.

### Scale and fade

- **Far nameplate scale**: the size of nameplates at the far end of **Nameplate distance**, 80% as the game has it, from 50% to 100%. Raise it and distant plates keep more of their size.
- **Far nameplate opacity**: how solid far nameplates are. They turn solid as units come near.
- **Opacity behind obstacles**: how solid the nameplate of a unit behind a wall is. 0% hides it.

### Where the game keeps these settings

The game, not your profile, keeps these settings, so a change of profile leaves them as they are. Pointing at a row says where it is kept:

| Kept | Rows |
| --- | --- |
| For your account | **Enemy nameplates**, **Friendly player nameplates**, **Friendly NPC nameplates**, **Always show nameplates**, **Nameplates on enemy pets and totems**, **Nameplates on minor enemies**, **Friendly players as names only**, **Nameplate style**, **Nameplate size**, **Stack enemy nameplates**, **Stack friendly nameplates**, **Nameplates at the unit's feet**, **Class colours on enemy players**, **Class colours on friendly players** and **Aura size** |
| For each character, so an alt has its own | **Nameplate distance**, **Target nameplate size**, **Far nameplate scale**, **Far nameplate opacity** and **Opacity behind obstacles** |
| On this computer, for every character | **Horizontal overlap**, **Vertical overlap** and **Other nameplates' opacity** |

**Spread of enemy nameplates** sets the stacking for your account, and the overlap and the plates' motion on this computer.

## Commands

| Command | What it does |
| --- | --- |
| `/flatui role` | Says whether nameplate threat reads you as a tank, and why, as "Flat UI: nameplate threat reads you as a tank (Defensive Stance), so enemies you are losing are marked." or "Flat UI: nameplate threat reads you as damage or healer (no tank stance or form)." |
| `/flatui role tank` | Sets **Your role** to **Tank**. `damage` sets **Damage or healer**, `auto` sets **From your role, stance or form**, and `toggle` swaps between tank and damage. |
| `/flatui status` | Says what is styled, and any error. Its nameplate lines cover parts such as the target mark, the flash as you change target, the marks of enemies you are losing, combo points, the Overpower icon and quest marks. |
| `/flatui test` | Turns test mode on or off, with its sample nameplate |
| `/flatui setup` | Opens Flat UI setup, with its **Enemies' nameplates** stop |
| `/flatui cvar` | Lists each game setting row, nameplate rows among them: its value, default and secure flag |
| `/flatui cvar check` | Tries whether each of those can be changed, out of combat |
| `/flatui #changed nameplate` | Lists the settings you changed that match "nameplate" |

While **Restyle nameplates** or **Threat on nameplates** is off, `/flatui role` also says "Flat UI: no nameplate shows threat while Restyle nameplates or Threat on nameplates is off." Every command is on [Commands](Commands).

Every setting of this group, with its default: [Settings: Frames and bars](Settings-Frames-and-bars). The nameplate rows are under its [Nameplates](Settings-Frames-and-bars#nameplates) heading.
