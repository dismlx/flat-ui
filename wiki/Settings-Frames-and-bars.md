Every setting of the **Frames and bars** group of the options window, 532 in all, with its default in a new profile, which is how **Jon Default** has it. The guide is [Frames and bars](Frames-and-bars) and [Nameplates](Nameplates).

Pages: [Unit frames](#unit-frames) · [Nameplates](#nameplates) · [Cast bars](#cast-bars) · [Personal resource display](#personal-resource-display) · [Swing timers](#swing-timers)

Made by `tools/dev/make_wiki.py` from Flat UI 0.5.49.

## Unit frames

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle unit frames** | On |  |

**Frames**

| Setting | Default | Notes |
| --- | --- | --- |
| **Player frame** | On |  |
| **Target frame** | On |  |
| **Focus frame** | On |  |
| **Pet frame** | On |  |
| **Target of target frame** | On |  |
| **Party frames** | On |  |
| **Party pet frames** | On |  |
| **Boss frames** | On |  |
| **Raid frames** | On | Also the party frames when raid-style party frames are on. |
| **Totem frame** | On |  |

**Pet frame size**

| Setting | Default | Notes |
| --- | --- | --- |
| **Custom pet frame size** | Off | Set the size of the pet frame yourself. Edit Mode's pet Frame Size is used while this is off. |
| **Pet frame size is measured against** | Player frame size | Player frame size: 100% is as large as the player frame. Normal size: 100% is the pet frame at Edit Mode's Frame Size of 100%. Choices: Player frame size, Normal size. Needs **Custom pet frame size** on. |
| **Percent** | 100% | Needs **Custom pet frame size** on. |

**Frame scale**

| Setting | Default | Notes |
| --- | --- | --- |
| **Player frame scale** | 100% | Edit Mode only enlarges frames. This also shrinks them. |
| **Target frame scale** | 100% | The target of target frame and cast bar go with it. |
| **Focus frame scale** | 100% |  |
| **Party frame scale** | 100% |  |
| **Boss frame scale** | 100% |  |
| **Raid frame scale** | 100% |  |

**Portraits**

| Setting | Default | Notes |
| --- | --- | --- |
| **Portrait style** | Face | Sets every frame's Picture to As Portrait style. A frame's own Picture can then pick another. Choices: Face, 3D head, Class icon, None. |
| **3D head framing** | Head and shoulders | How close the camera sits on a 3D head picture: Face is the closest, Head and shoulders the widest. Choices: Face, Head, Head and shoulders. |
| **Portrait size** | As tall as the frame | In One frame, As tall as the bars puts the name row over the portrait too. Choices: As tall as the frame, As tall as the bars. |
| **Portrait border** | Thin | In One frame, the colour of the whole frame's border. Resting, combat and Elite colours still show with None. Choices: Thin, Class or reaction colour, None. |
| **Portrait shape** | Square | Every picture but a 3D head, Game portrait too. Choices: Square, Round. |
| **Portrait fades with the name row** | On | The top of the picture fades like the name row. Needs Name row colour set to Class or reaction colour, fading upward. |
| **Player portrait** | On |  |
| **Target portrait** | On |  |
| **Focus portrait** | On |  |
| **Pet portrait** | On |  |
| **Target of target portrait** | On |  |
| **Party portraits** | On |  |
| **Party pet portraits** | On |  |

**Name row**

| Setting | Default | Notes |
| --- | --- | --- |
| **Name row on small frames** | On | A row with the name above the bars on the pet, target of target, party and party pet frames. In One frame party pets have none. |
| **Name room** | Only what the texts need | The name gets the room the level and the PvP word leave. Fixed space keeps a set room for each. Choices: Only what the texts need, Fixed space. |
| **PvP word colour** | Same as the name | The colour of the PvP word in the name row. Choices: Same as the name, White, Red. |

**Level**

| Setting | Default | Notes |
| --- | --- | --- |
| **Level position** | End of the name row | The level number on the player, target, focus and boss frames. The game's round level plate stays hidden. On the portrait needs a picture. Choices: End of the name row, Before the name, On the portrait, Hidden. |
| **Level colour** | By difficulty | By difficulty is the game's own colour, from grey to red by how far the unit's level is above or below yours. Choices: By difficulty, White, Same as the name. Needs **Level position** at End of the name row or Before the name or On the portrait. |
| **Level size** | Same as the name | The level number beside the name: Smaller is 85% of the name's size, Larger 120%. Choices: Same as the name, Smaller, Larger. Needs **Level position** at End of the name row or Before the name or On the portrait. |

**Raid frames**

| Setting | Default | Notes |
| --- | --- | --- |
| **Raid cell look** | On | Makes the game's power bar thin, with a border, when Display Power Bars is on in the game's raid frame options. Health is grey when dead or offline. Needs **Raid frames** on. |

**Border and background**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own border and background** | Off |  |
| **Border colour** | #000000 | Needs **Own border and background** on. |
| **Background colour** | #0F0F0F | Needs **Own border and background** on. |
| **Background opacity** | 85% | Needs **Own border and background** on. |

### Per frame

#### Player

| Setting | Default | Notes |
| --- | --- | --- |
| **Picture** | As Portrait style | Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, 3D head, Game portrait, Class icon, None. |
| **Name** | On |  |
| **Level** | On |  |
| **Resting animation** | Hidden with the resting colour | The game's sleeping letters by your portrait while you rest. At first they hide while Resting and combat colour turns the portrait border yellow instead. Choices: Hidden with the resting colour, Shown, Hidden. |
| **Health bar colour** | Class | Class and Reaction replace Health colour and Health in class and reaction colour. Choices: Health colour, Class, Reaction. |
| **Health text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Combat icon** | On | The game's crossed swords on the player frame while you are in a fight. |
| **Combat and resting icons** | Above the portrait | Where the crossed swords of a fight and the sleeping letters of resting sit. Above the portrait keeps them clear of the picture, in either Frame style. Game's spot puts them back where the game draws them, the swords on the portrait's lower corner. Changed out of combat. Choices: Above the portrait, Game's spot. |
| **Power bar** | On |  |
| **Druid mana in forms** | On | For a druid in Bear or Cat Form: a thin mana bar under the player frame's bars. In the other forms the frame's own bar shows mana. |
| **Mana text** | Percent | The mana just right of the bar, in the bar text font at Power text size. It fades in and out with the bar. Choices: None, Percent, Current. Needs **Druid mana in forms** on. |
| **Mana bar height** | 4 px | Changed out of combat. Needs **Druid mana in forms** on. |
| **Mark the cost of a shift** | On | A thin line on the bar at the mana a shift into the form you are in costs, for a powershift: fill past it pays for one. Needs **Druid mana in forms** on. |
| **Five-second rule** | Off | After you spend mana, a spark crosses your mana bar over 5 seconds. Spirit refills your mana again once it reaches the end. A druid in Bear or Cat Form sees it on the druid mana bar. |
| **Energy tick** | Off | For a rogue, or a druid in Cat Form: a spark crosses your energy bar every 2 seconds and reaches its end as the next energy comes in, also in a fight. It finds the beat from the first tick it sees. |

#### Target

| Setting | Default | Notes |
| --- | --- | --- |
| **Picture** | As Portrait style | Class icon applies to players. Other units keep their face. Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, 3D head, Game portrait, Class icon, None. |
| **Name** | On |  |
| **Level** | On |  |
| **Health bar colour** | Health colour | Class applies to players. Other units take their reaction colour, grey on an enemy someone else has tapped. Choices: Health colour, Class, Reaction. |
| **Health text** | Percent | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power bar** | On |  |

#### Focus

| Setting | Default | Notes |
| --- | --- | --- |
| **Picture** | As Portrait style | Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, 3D head, Game portrait, Class icon, None. |
| **Name** | On |  |
| **Level** | On |  |
| **Health bar colour** | Health colour | Choices: Health colour, Class, Reaction. |
| **Health text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power bar** | On |  |

#### Pet

| Setting | Default | Notes |
| --- | --- | --- |
| **Picture** | As Portrait style | Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, 3D head, Game portrait, None. |
| **Name** | On |  |
| **Long names** | Cut with dots | Smaller text goes down to 75%, then cuts. Needs Name row on small frames. Choices: Cut with dots, Smaller text. Needs **Name** on. |
| **Health bar colour** | Health colour | Choices: Health colour, Class, Reaction. |
| **Health text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Happiness face** | On | The hunter's pet face beside the pet frame: green while the pet is happy, yellow while content, red while unhappy. |
| **Power bar** | On |  |
| **Pet target frame** | Off | A small frame for what your pet attacks, with its health and name. A click targets it, Shift-click sets it as your focus. /flatui move places it. |
| **Pet target width** | 120 px | Changed out of combat. Needs **Pet target frame** on. |
| **Border while it is not your target** | On | The frame's border turns this colour while your pet attacks something other than your target, and goes back once you are both on the same unit, also in a fight. Needs **Pet target frame** on. |
| **Not your target colour** | #FF9919 | Needs **Border while it is not your target** on. |

#### Target of target

| Setting | Default | Notes |
| --- | --- | --- |
| **Picture** | As Portrait style | Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, Game portrait, Class icon, None. |
| **Name** | On |  |
| **Long names** | Smaller text | Smaller text goes down to 75%, then cuts. Needs Name row on small frames. Choices: Cut with dots, Smaller text. Needs **Name** on. |
| **Health bar colour** | Class | Choices: Health colour, Class, Reaction. |
| **Health text** | As the game has it | On the target's and the focus's target. As the game has it shows none. Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power bar** | On |  |
| **Position** | Beside the target frame | Beside puts it just right of the target frame with their tops in line, and the focus target beside the focus frame, in either Frame style, while both frames are restyled. Game's spot leaves it below and to the right, where the game puts it. Changed out of combat. Choices: Beside the target frame, Game's spot. |

#### Party

| Setting | Default | Notes |
| --- | --- | --- |
| **Picture** | As Portrait style | Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, 3D head, Game portrait, Class icon, None. |
| **Party pet picture** | As Portrait style | Game portrait draws the game's portrait in the frame, square or round as Portrait shape says. Flat UI portraits off keeps the game's own portrait where the game puts it. Choices: As Portrait style, Face, 3D head, Game portrait, None. |
| **Name** | On | On party members and their pets. |
| **Long names** | Cut with dots | On party members and their pets. Smaller text goes down to 75%, then cuts. Needs Name row on small frames. Choices: Cut with dots, Smaller text. Needs **Name** on. |
| **Health bar colour** | Class | Choices: Health colour, Class, Reaction. |
| **Health text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power bar** | On |  |

**Range**

| Setting | Default | Notes |
| --- | --- | --- |
| **Dim members out of range** | Off | Darkens the member's picture, name and bars. Their pet's frame dims by its own range. Also dims a member whose range the game does not report. |
| **Out of range opacity** | 50% | Needs **Dim members out of range** on. |

#### Boss

| Setting | Default | Notes |
| --- | --- | --- |
| **Name** | On |  |
| **Long names** | Cut with dots | Smaller text goes down to 75%, then cuts. Needs Name row. Choices: Cut with dots, Smaller text. Needs **Name** on. |
| **Level** | On |  |
| **Health bar colour** | Health colour | Choices: Health colour, Class, Reaction. |
| **Health text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power text** | As the game has it | Choices: As the game has it, Hidden, Current, Current / max, Percent, Current and percent, Missing. |
| **Power bar** | On |  |

#### Raid

| Setting | Default | Notes |
| --- | --- | --- |
| **Out of range opacity** | 50% | How see-through a raid cell is while that member is out of your range, also in a fight. At 50% the game's own fading stays. |
| **Role icon** | On | The tank, healer or damage icon in the corner of each cell. Role icons for picks which roles keep one. |
| **Name** | On | The member's name in each cell. |
| **Status text** | On | The words the game writes in a cell: Dead, Offline and the health its Display Health Text option picks. |

### Bars and pictures

**Frame**

| Setting | Default | Notes |
| --- | --- | --- |
| **Frame style** | Separate parts | One frame puts the portrait, the name row and the bars in one border and one background. Separate parts gives each its own. Choices: One frame, Separate parts. |
| **Background** | On | Behind the whole frame. In Separate parts, behind each bar. |
| **Border** | On | Round the whole frame. In Separate parts, round each bar. |
| **Highlight under the mouse** | On | The health bar of the frame under the mouse brightens a little, so you see which frame a click hits. Also raid frames and the pet target frame. |
| **Space between parts** | 2 px | Between the portrait, the name row and the bars, and round them. In Separate parts, only between the two bars. |
| **Corners** | Soft | Rounds the corners of the frame. In Separate parts, of the name row, each bar and the portrait border. Also the pet target frame and the druid mana bar. Choices: Square, Slightly soft, Soft. |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flat bars** | On | Square ends and one plain colour, in the bar texture chosen on the Flat UI page. |
| **Health colour** | #2EB84D | Needs **Flat bars** on. |
| **Health bar texture** | `default` | Needs **Flat bars** on. |
| **Power bar texture** | `default` | Needs **Flat bars** on. |
| **Mana bar colour** | Sky blue next to a blue health bar | Custom power colours on the Colours page changes the blue this starts from. Choices: As the game has it, Sky blue next to a blue health bar. Needs **Flat bars** on. |
| **Power bar width** | Same as the health bar | Game's width can run past the health bar on the target, focus and target of target frames. Choices: Same as the health bar, Game's width. Needs **Frame style** at Separate parts. |
| **Hide empty power bar** | On | Hides the power bar of a unit that has no power. |
| **Colour health bars by health left** | Off | In the three colours of the Colours page, raid cells too. Needs **Flat bars** on. |

**Portraits**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flat UI portraits** | On | Portraits and the name row drawn by Flat UI. Off keeps the game's portraits where the game puts them, with no name row. |

**Name row**

| Setting | Default | Notes |
| --- | --- | --- |
| **Name row** | On | A row with the name above the health bar on the player, target, focus and boss frames. Needs **Flat UI portraits** on. |
| **Name row colour** | Class or reaction colour, fading upward | Players take their class colour and other units their reaction colour, grey on an enemy someone else has tapped. Choices: Class or reaction colour, fading upward, Class or reaction colour, Dark with a colour mark. Needs **Name row** on. |
| **Name row fade** | 95% | How far the colour fades toward the top of the name row. 0 is one flat colour. Needs **Name row** on. |
| **Name background brightness** | 100% | A light colour stays dark enough for the name to read. Needs **Name row** on. |

**Status colours**

| Setting | Default | Notes |
| --- | --- | --- |
| **Resting and combat colour** | On | Colours the border of the player and pet portraits, or of the whole frame in One frame: yellow while resting, red in combat. The game's glow stays hidden when this is off. Needs **Flat UI portraits** on. |
| **Threat border** | On | Colours the health bar border, or the whole frame's border in One frame, while a unit has threat. A party member's border takes the colour of their top debuff. |
| **Threat border on tanks** | Shown | A tank who holds aggro as planned keeps a plain border. A tank is a member with the tank role, or the Main Tank of a raid. Choices: Shown, Not shown. Needs **Threat border** on. |
| **Low health border** | Off | Your own frame and your pet's, your party's and their pets', and your raid's, and with the row below your target's, focus's, boss's and target of target's: the health bar border takes this colour while the unit is below the limit, also in a fight. Never on a dead unit. |
| **Low health below** | 20% | Needs **Low health border** on. |
| **Low health border colour** | #FF3333 | Needs **Low health border** on. |
| **Pulse the low health border** | Off | The border beats softly while the member is below the limit and stops as they heal. Every border on screen beats in step. Needs **Low health border** on. |
| **Also on target, focus, boss and target of target frames** | Off | For Execute and Hammer of Wrath, and the tank you watch on the target of target: the health bar border of the target, focus, boss, target of target and focus target frames too. One you can attack takes Enemies below, one you can assist Low health below. Needs **Low health border** on. |
| **Enemies below** | 20% | The limit on a target, focus, boss or target of target you can attack. One you can assist keeps Low health below. Needs **Also on target, focus, boss and target of target frames** on. |

**Elite and Rare**

| Setting | Default | Notes |
| --- | --- | --- |
| **Portrait border colour** | On | Gold for an Elite, silver for a Rare, silver with a gold inner line for a Rare Elite, red for a Boss. In One frame the whole frame's border shows it, without the inner line. Needs **Flat UI portraits** on. |

**Heal prediction and shields**

| Setting | Default | Notes |
| --- | --- | --- |
| **Incoming heals** | On | The game's green bar past the health for heals on their way, on the unit frames and raid cells. Off hides it. |
| **Absorb shields** | On | The game's white bar for a shield such as Power Word: Shield, and its glow past full health, on the unit frames and raid cells. Off hides them. |
| **Heal absorbs** | On | The game's dark red bar for an effect that eats the next heals, on the unit frames and raid cells. Off hides it. |

### Text

**Names**

| Setting | Default | Notes |
| --- | --- | --- |
| **Name font** | Game font | Also the names on raid frames, with Name size, Name outline and Name colour. Choices: Game font, Friz Quadrata, Arial Narrow, Morpheus, Skurri. |
| **Name size** | 100% | 100% is the game's own size. On small frames it is a share of Small frame text size. |
| **Name outline** | As the game has it | Choices: As the game has it, None, Thin, Thick. |
| **Name colour** | As the game has it | Class colours a player by class and other units by reaction. Class and Reaction turn grey on an enemy someone else has tapped. Choices: As the game has it, White, Class, Reaction, Custom. |
| **Custom name colour** | #FFD100 | Needs **Name colour** at Custom. |

**Bar text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Health text size** | 100% | 100% is the game's own size. |
| **Power text size** | 85% | 100% is the game's own size. |
| **Small frame text size** | 70% | Names and bar text on the pet, target of target, focus target, party and party pet frames, and the pet target frame. 100% is the game's own size. |
| **Bar text font** | Game font | Also the status text on raid frames, with Bar text outline. Choices: Game font, Friz Quadrata, Arial Narrow, Morpheus, Skurri. |
| **Bar text outline** | As the game has it | Replaces the outline that Smaller, lighter bar text removes. Choices: As the game has it, None, Thin, Thick. |
| **Own bar text colour** | Off |  |
| **Bar text colour** | #FFFFFF | Needs **Own bar text colour** on. |

**Looks**

| Setting | Default | Notes |
| --- | --- | --- |
| **Health in class and reaction colour** | Off | Every unit frame's health bar takes a player's class colour and another unit's reaction colour in place of Health colour. A frame's own Health bar colour picks first. |
| **Dark health bar, colour shows what is lost** | Off | The health bar turns dark and the part already lost shows the bar's colour, so the colour grows as health drops. Needs Background. |
| **Muted colours** | Off | Softens the health, power and name row colours of the unit frames toward grey, a little darker. |
| **Smaller, lighter bar text** | Off | Bar text at 85% of its size and with no outline, on every unit frame but the boss frames and raid cells. Bar text outline can give it an outline back. |
| **No text on the power bar** | Off | Hides the numbers on the power bar of every unit frame. |
| **Soft shade on bars** | Off | The soft bar texture on unit frames, whatever the Flat UI page chooses. |
| **Shadow behind each frame** | Off | A soft dark shadow round each unit frame, raid cells aside, to lift it off the world. Made out of combat. |

**Health and power text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Number style** | 12.3k | For a format chosen on a frame's page. Missing reads -12.3k or -12,345. Choices: 12.3k, 12,345. |
| **Show** | Always | With a Health text or Power text format chosen on a frame's page. While not full hides the health text at full health and the power text at full mana or energy, or while rage is empty. Dead, Ghost and Offline always show. Choices: Always, Under the mouse, While not full. |
| **Health text position** | Centre | Choices: Left, Centre, Right. |
| **Power text position** | Centre | Choices: Left, Centre, Right. |

### Icons and auras

**Aura icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Aura icon borders** | On | Square icons with a thin border. Debuffs take the colour of their type. |
| **Aura icon crop** | 8% | How much of each aura icon's edge is cut away inside its border, so the art fills the square. Needs **Aura icon borders** on. |
| **Border colour by debuff type** | On | A debuff's border takes the colour of its type, Magic, Curse, Disease or Poison, and a buff you can steal or purge its own. Off keeps every border plain. Needs **Aura icon borders** on. |
| **Stack number size** | 100% | On party and pet debuffs. 100% is the game's own size. |
| **Countdown numbers on party and pet debuffs** | Off | The game's time left in numbers over each debuff on the party and pet frames. |

**Elite and Rare**

| Setting | Default | Notes |
| --- | --- | --- |
| **Mark after the level** | On | + for an Elite, R for a Rare, R+ for a Rare Elite. |
| **Elite or Rare word** | On | Elite, Rare, Rare Elite or Boss in the name row, next to the level. |
| **Line under the name row** | Off | A thin line between the name row and the health bar: gold for an Elite, silver for a Rare, red for a Boss. |

**PvP flag**

| Setting | Default | Notes |
| --- | --- | --- |
| **PvP flag** | Both | On the player, target and focus frames while the unit is flagged. Off also hides the icon on party frames. Choices: Both, Icon on the portrait, Word in the name row, Off. |
| **Icon corner** | Bottom left | Choices: Top left, Top right, Bottom left, Bottom right. Needs **PvP flag** at Both or Icon on the portrait. |
| **Time until the flag drops** | On | On your own frame, beside the icon or the word. |

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Leader icon** | On | The game's crown on the frame of the group leader, on the player, target, focus and party frames. |
| **Role icon on player and party frames** | On | The tank, healer or damage icon the game puts on the player and party frames. Role icons for picks which roles keep one. |
| **Role icons for** | Every role | On player, party and raid frames. Main Tank and Main Assist keep their icon. Choices: Every role, Tanks and healers, Healers only. |
| **PvP icon** | On | The PvP icon on the player, target, focus and boss frames, the game's or the one PvP flag puts on the portrait. Off leaves the word in the name row. |
| **Raid marker on target, focus, boss and pet target frames** | On |  |
| **Dead text** | On | The game's Dead across the health bar of a dead target, focus, boss or target of target. |
| **Hit numbers on player and pet portraits** | Off | The game's big damage and healing numbers that flash over your portrait and your pet's. Off at first, so they do not cover the picture. |

**Totems**

| Setting | Default | Notes |
| --- | --- | --- |
| **Totem time left** | On | The time left under each of your totems by the player frame. |
| **Totem cooldown swipe** | On | The dark sweep across each of your totems by the player frame as its time runs out. |
| **Totem time size** | 80% | Needs **Totem time left** on. |

**Party and raid frames**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border colour of a debuff you can dispel** | On | The border of the health bar takes the colour of Magic, Curse, Disease or Poison while the member has a debuff of that type you can dispel. |
| **Also on your player, target and focus frames** | On | A target or focus you cannot assist shows none. Needs **Border colour of a debuff you can dispel** on. |
| **Debuff type icon on party frames** | On | The type of a debuff you can dispel, at the right end of the health bar. The game's raid frames show their own. |
| **Sound for a debuff you can dispel** | None | As a party or raid member gets one, also in a fight. At most once every 2 seconds. The sound plays once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. Needs **Border colour of a debuff you can dispel** on. |
| **Blink as one lands** | On | The border and its type icon blink three times as a party or raid member gets a debuff you can dispel, also in a fight. Needs **Border colour of a debuff you can dispel** on. |
| **Raid marker on raid frames** | On | The game's raid frames show none. |
| **Raid marker on party frames** | On | The game's party frames show none. |
| **Resurrection icon on party frames** | On | On the portrait of a dead member while someone resurrects them, also in a fight, breathing softly so two healers do not resurrect the same one. With Picture None it sits in the empty picture square, or in One frame at the left end of the health bar, clear of the Dead word. The game's party frames show a summon already, and its raid frames both. |
| **AFK on party frames** | On | A grey AFK at the bottom of the picture of a party member who is away, also of the empty picture square with Picture None, or in One frame at the left end of the health bar, also in a fight. It fades in, counts the time away from when Flat UI first saw the flag (AFK 3m, AFK 1h) and fades out as they come back. Hidden while they are dead or offline. The game's frames show none. |
| **AFK on raid frames** | On | A grey AFK at the bottom of a raid member's cell, where the game's status text sits, while they are away, also in a fight. It fades and counts as on party frames. Hidden while they are dead or offline. |
| **Leader and assistant icons on raid frames** | On | The game's raid frames show none. |
| **Border for your target** | As the game has it | On raid frames, the border of your target. With Own colour the game's party frames get one too. Choices: As the game has it, Own colour, Off. |
| **Target border colour** | #FFFFFF | Needs **Border for your target** at Own colour. |
| **Border for your focus** | Off | An outline round the party frame or raid cell of the member you have as your focus, also in a fight. The border for your target stays on top when they are the same member. |
| **Focus border colour** | #FF9900 | Needs **Border for your focus** on. |
| **Squares for your heals over time** | Off | A small square in a corner of a party or raid member's health bar for each heal over time of yours on them, such as Renew, Rejuvenation, Regrowth, Prayer of Mending, Power Word: Shield, Earth Shield or Sacred Shield, each in its own colour. In a fight, where the game hides which aura is which, a square read before the pull stays until its time runs out, while the member has at least as many of your buffs as then, and a new one waits for the end of the fight. |
| **Square corner** | Top right | The corner of the health bar the squares sit in. On party frames a right-hand corner starts them just left of the debuff type icon. Choices: Top left, Top right, Bottom left, Bottom right. Needs **Squares for your heals over time** on. |
| **Square size** | 6 | The side of each square. On party frames at most what fits inside the health bar, so 6 stays 6 there. Needs **Squares for your heals over time** on. |
| **Fade as one runs out** | On | A square fades over the last 3 seconds of its heal over time, so you see which to cast again. In a fight it fades by the end read before the pull. Needs **Squares for your heals over time** on. |

## Nameplates

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle nameplates** | On | Flat UI's look for nameplates and the parts on its tabs, from threat to quest marks. Off, nameplates keep the game's own look. |
| **Restyle friendly nameplates** | On | Off, friendly nameplates keep the game's own look and size while enemies keep Flat UI's. Click through friendly nameplates works either way. |

**Border and background**

| Setting | Default | Notes |
| --- | --- | --- |
| **Own border and background** | Off | Gives the nameplates' borders and backgrounds the colours and opacity below, in place of those of the Flat UI page. |
| **Border colour** | #000000 | The colour of the thin borders round nameplate bars. Needs **Own border and background** on. |
| **Background colour** | #0F0F0F | The colour behind nameplate bars, seen where a bar is empty. Needs **Own border and background** on. |
| **Background opacity** | 85% | How solid the background behind nameplate bars is; 0% leaves it clear. Needs **Own border and background** on. |

### Health bar

| Setting | Default | Notes |
| --- | --- | --- |
| **Health bar border** | On | Thin border in place of the default frame. |
| **Health bar background** | On | A dark background behind the health bar, so its empty part reads against the world. Needs **Health bar border** on. |
| **Flat health bar** | On | One plain colour in place of the default gloss. |
| **Health bar texture** | `default` | The fill of the flat health bar; Same as the Flat UI page takes its Bar texture. Needs **Flat health bar** on. |
| **Health bar height** | 125% | 100% is the game's own height. |
| **Bar width** | 100% | Narrows the health and cast bar together, from the game's own width at 100%. |
| **Dim other nameplates** | On | Darkens every nameplate that is not your target or focus. Needs **Health bar border** on. |
| **Dim strength** | 60% | How dark the nameplates that are not your target or focus go. Needs **Dim other nameplates** on. |

**Health bar art**

| Setting | Default | Notes |
| --- | --- | --- |
| **Incoming heals** | On | The game's fill of heals on their way, just past the health on the bar. Off hides it on nameplates. |
| **Absorb shields** | On | The game's light fill of a shield that soaks up damage, such as Power Word: Shield, past the health. Off hides it on nameplates. |
| **Heal absorbs** | On | The game's dark fill over the health that heals must undo before they count. Off hides it on nameplates. |

### Colours

**Reaction**

| Setting | Default | Notes |
| --- | --- | --- |
| **Reaction colours on health bars** | On | Hostile, neutral and friendly, in the colours of the Colours page. Tapped and dead units keep the game's grey unless Custom reaction colours is on. |
| **Players** | As the game has it | As the game has it keeps the class colours of Class colours on enemy players and on friendly players. Choices: As the game has it, By reaction. Needs **Reaction colours on health bars** on. |
| **Class colours on enemy players** | Off | The game colours an enemy player's health bar by class: a rogue yellow, a mage light blue. The game keeps it for your account, whatever the profile. Sets the game's `nameplateShowClassColor`. |
| **Class colours on friendly players** | Off | The game colours a friendly player's health bar by class. The game keeps it for your account, whatever the profile. Sets the game's `nameplateShowFriendlyClassColor`. |

**Target**

| Setting | Default | Notes |
| --- | --- | --- |
| **Colour the target's health bar** | Off | Your target's health bar takes Target health bar colour, ahead of threat and reaction colours. |
| **Target health bar colour** | #66B3FF | The colour of your target's health bar while Colour the target's health bar is on. Needs **Colour the target's health bar** on. |

**Mouseover**

| Setting | Default | Notes |
| --- | --- | --- |
| **Mouseover border** | On | A light border round the nameplate under the mouse. |
| **Mouseover colour** | #D9D9D9 | The colour of the border round the nameplate under the mouse. Needs **Mouseover border** on. |

**Health left**

| Setting | Default | Notes |
| --- | --- | --- |
| **Colour health bars by health left** | Off | In the three colours of the Colours page, from full to low as health drops. The target's colour, threat colours and reaction colours come first. |
| **Low health border** | On | A nameplate's health bar border lights in Low health border colour once its health drops below Low health below. |
| **Low health below** | 20% | The share of health under which the low health border lights, and where its line crosses enemy health bars. Needs **Low health border** on. |
| **Low health border colour** | #FF3333 | The colour of the low health border and of its line. Needs **Low health border** on. |
| **Line at Low health below** | On | A thin line in the Low health border colour across each enemy's health bar at Low health below, so you see how near an enemy is to it, such as Execute range at 20%. Needs **Low health border** on. |

### Threat

**Threat**

| Setting | Default | Notes |
| --- | --- | --- |
| **Threat on nameplates** | On | Shows your threat on each enemy with the parts below. |
| **Colour health bars by threat** | On | The target's own colour still wins while Colour the target's health bar is on. Needs **Threat on nameplates** on. |
| **Your role** | From your role, stance or form | From your role, stance or form takes the role your group gave you, else Defensive Stance, Bear Form or Righteous Fury make you a tank. Choices: From your role, stance or form, Tank, Damage or healer. Needs **Threat on nameplates** on. |

**Threat colours**

| Setting | Default | Notes |
| --- | --- | --- |
| **Threat you want** | #4DBF59 | As a tank an enemy you hold securely, as damage or healer one on someone else. Needs **Threat on nameplates** on. |
| **Threat changing hands** | #E6C133 | An enemy close to turning to you or away from you. Needs **Threat on nameplates** on. |
| **Threat you do not want** | #D94040 | As a tank an enemy on someone else, as damage or healer one on you. Needs **Threat on nameplates** on. |
| **Same colours for both roles** | On | Off, the three colours above are a tank's and the three below are for damage or healing. Needs **Threat on nameplates** on. |
| **Threat you want as damage or healer** | #4DBF59 | An enemy on someone else. Needs **Same colours for both roles** at False. |
| **Threat changing hands as damage or healer** | #E6C133 | An enemy close to turning to you or away from you. Needs **Same colours for both roles** at False. |
| **Threat you do not want as damage or healer** | #D94040 | An enemy on you. Needs **Same colours for both roles** at False. |
| **Enemies held by another tank** | On | As a tank, an enemy another tank of your group or your pet holds takes the colour below, so it is not taken for a loose one. Needs **Threat on nameplates** on. |
| **Another tank's colour** | #0FAAC8 | The colour of an enemy another tank of your group or your pet holds, while you count as a tank. Needs **Enemies held by another tank** on. |

**Whose threat**

| Setting | Default | Notes |
| --- | --- | --- |
| **Your pet's threat counts** | On | An enemy your pet holds shows as held for you before you hit it. Needs **Threat on nameplates** on. |
| **Early warning while tanking** | Off | As a tank, an enemy you hold securely shows as changing hands while someone else comes close to your threat. Needs **Threat on nameplates** on. |

**Which enemies**

| Setting | Default | Notes |
| --- | --- | --- |
| **Normal enemies** | On | Shows threat on ordinary enemies: not Elite, Rare, a boss or minor. Needs **Threat on nameplates** on. |
| **Elite and Rare enemies** | On | Shows threat on Elite, Rare and Rare Elite enemies. Needs **Threat on nameplates** on. |
| **Bosses** | On | Enemies whose level shows as a skull. Needs **Threat on nameplates** on. |
| **Minor enemies** | On | Totems and other units the game counts as minor or trivial. Needs **Threat on nameplates** on. |
| **Neutral enemies** | On | Units that do not attack until you do. Needs **Threat on nameplates** on. |
| **Enemies tapped by others** | On | Their health bar keeps the game's grey. Needs **Threat on nameplates** on. |
| **Only in dungeons and raids** | Off | Nameplates show threat only inside a dungeon or a raid, and none in the open world or a battleground. Needs **Threat on nameplates** on. |

**Glow and opacity**

| Setting | Default | Notes |
| --- | --- | --- |
| **Threat glow** | When the enemy needs you | A ring in the threat colour around the health bar; When the enemy needs you leaves out threat you want. Choices: Off, When the enemy needs you, Every threat state. Needs **Threat on nameplates** on. |
| **Flash the ring when threat goes wrong** | On | The ring flashes twice as an enemy turns to you, or away from you while you tank. Needs **Threat glow** at When the enemy needs you or Every threat state. |
| **Threat ring thickness** | 2 px | In screen pixels, so it keeps its thickness at any resolution. It grows outward, clear of an elite's border. Needs **Threat glow** at When the enemy needs you or Every threat state. |
| **Mark enemies you are losing** | On | While you count as a tank, an enemy changing hands or on someone else pulses with a soft glow in its threat colour, faster once it is lost, under a small arrow, so you see which to take back. Enemies you hold, and every enemy while you are not a tank, show none. Needs **Threat on nameplates** on. |
| **Magnified plate for enemies you are losing** | On | While you count as a tank, an enemy you are losing gets a magnified copy of its plate, drawn over it and above every other plate: its health bar in its threat colour, its name and its raid marker, carrying the glow and arrow, and the target or focus border while it is your target or focus. It starts at the plate's own size once another member reaches Slipping at of your threat (Threat list), grows as their share rises and reaches the size below once someone else holds the enemy, easing as the threat moves, then shrinks back and goes once you take the enemy back and their share falls under Slipping at. It takes no clicks, so a click still reaches the enemy's plate, and it works in a fight. Needs **Mark enemies you are losing** on. |
| **Size of an enemy you have lost** | 150% | How large the magnified plate of an enemy grows once someone else holds it. On the way there it grows with the threat another member has of yours, from the plate's own size at Slipping at; at 100% it stays the plate's size. Needs **Magnified plate for enemies you are losing** on. |
| **Flash as you take an enemy back** | On | While you count as a tank, the glow of an enemy someone else held flashes once in Threat you want as it turns back to you, so you see your taunt land. Needs **Mark enemies you are losing** on. |
| **Threat colour on the health bar border** | Off | Your target, focus and mouseover keep their border colour, and it needs Health bar border. Needs **Threat on nameplates** on. |
| **Health bar background in the threat colour** | Off | A dark shade of the threat colour behind the health bar while threat colours the bar, and it needs Health bar background. Needs **Colour health bars by threat** on. |
| **Fade enemies held for you** | On | Enemies whose threat you want fade so the ones that need you stand out, while your target and focus stay clear. Needs **Threat on nameplates** on. |
| **Opacity of enemies held for you** | 75% | How solid an enemy whose threat you want stays; lower fades it more, and 100% keeps it clear. Needs **Fade enemies held for you** on. |
| **Same opacity for both roles** | On | Off, the opacity above is a tank's and the one below is for damage or healing. Needs **Fade enemies held for you** on. |
| **Opacity as damage or healer** | 75% | For enemies held for you while you count as damage or healer. Needs **Same opacity for both roles** at False. |
| **Opacity of enemies changing hands** | 100% | At 100% they stay clear. Needs **Fade enemies held for you** on. |
| **Raid-marked enemies stay clear** | Off | An enemy with a raid marker never fades, like your target and focus, and keeps its colour, glow and threat value. Needs **Fade enemies held for you** on. |

**Threat text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Threat value** | Share of aggro | Next to the health bar, where 100% share of aggro is the point at which the enemy turns to you. Choices: Off, Share of aggro, Share of the tank's threat, Lead while tanking. Needs **Threat on nameplates** on. |
| **Show threat value** | In a group or with a pet | In a group or with a pet hides it while you play alone with no pet, when every enemy is on you anyway; Only in a group hides it with a pet too. Choices: Always, In a group or with a pet, Only in a group. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat value in the threat colour** | On | Off, the value takes Threat value colour. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat value colour** | #FFFFFF | The colour of the threat value while Threat value in the threat colour is off. Needs **Threat value in the threat colour** at False. |
| **Threat value size** | 100% | 100% is the size of the game's health text. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat value position** | Left | Outside the health bar; above it clears the name and the enemy's debuffs, and below it the cast bar and your target's combo points. Choices: Left, Right, Above, Below. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat value horizontal offset** | 0 | Moves the threat value left or right from its place. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat value vertical offset** | 0 | Moves the threat value up or down from its place. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat value outline** | As the game has it | The outline round the threat value; As the game has it takes that of the game's health text. Choices: As the game has it, None, Thin, Thick. Needs **Threat value** at Share of aggro or Share of the tank's threat or Lead while tanking. |
| **Threat colour on the name** | Off | While an enemy shows threat, its name takes the threat colour in place of Name colour. Needs **Threat on nameplates** on. |
| **Health text in the name's colour** | Off | While an enemy's name has the threat colour, its health text has it too. Needs **Threat colour on the name** on. |

**Enemy's target**

| Setting | Default | Notes |
| --- | --- | --- |
| **Name of the enemy's target** | Off | Who the enemy attacks, right of the health bar, in the class colour of a player. Needs **Threat on nameplates** on. |
| **Only in combat** | On | The enemy's target shows only while you are in a fight. Needs **Name of the enemy's target** on. |
| **Only on your target** | Off | The enemy's target shows on your target's nameplate alone. Needs **Name of the enemy's target** on. |
| **Not when it attacks you** | On | Leaves out your own name, so only an enemy that attacks someone else shows whom it attacks. Needs **Name of the enemy's target** on. |

### Text

**Font**

| Setting | Default | Notes |
| --- | --- | --- |
| **Text font** | Game font | For the name, the health text and the spell name. Choices: Game font, Friz Quadrata, Arial Narrow, Morpheus, Skurri. |

**Name**

| Setting | Default | Notes |
| --- | --- | --- |
| **Show name** | On | The unit's name on its nameplate. Off hides it, and the marks and icons over it move down to the bar or the debuffs. |
| **Name size** | 100% | 100% is the game's own size. |
| **Name outline** | As the game has it | The outline round the name; As the game has it keeps the game's own. Choices: As the game has it, None, Thin, Thick. |
| **Name colour** | As the game has it | Class gives players their class colour and others their reaction colour, Reaction gives every name hostile, neutral or friendly, and Custom takes Custom name colour. Choices: As the game has it, White, Class, Reaction, Custom. |
| **Custom name colour** | #FFFFFF | The colour of every name while Name colour is Custom. Needs **Name colour** at Custom. |

**Health text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Health text** | On | Untick to hide the health number the game shows. |
| **Health text size** | 80% | 100% is the game's own size. Needs **Health text** on. |
| **Health text outline** | As the game has it | The outline round the health text; As the game has it keeps the game's own. Choices: As the game has it, None, Thin, Thick. Needs **Health text** on. |
| **Health text colour** | #FFFFFF | The colour of the health text. Needs **Health text** on. |
| **Show health text** | Always | On the target and focus also keeps the health of your sheep, sap or shackle in sight on the focus's nameplate. Choices: Always, Only on the target, On the target and focus. Needs **Health text** on. |
| **Health text format** | As the game has it | Current is the health left, Current / max both numbers, Percent its share, Current and percent both, and Missing the health lost, blank while unhurt. Choices: As the game has it, Current, Current / max, Percent, Current and percent, Missing. Needs **Health text** on. |

**Level**

| Setting | Default | Notes |
| --- | --- | --- |
| **Level box** | Thin border | Text only removes the box and keeps the number. Choices: Thin border, Text only, Default, Hidden. |
| **Level box shape** | Square | Square is a box as tall as the health bar at its end, and the bar shortens to make room; Game width keeps the game's wider box past the end of the bar. Choices: Square, Game width. Needs **Level box** at Thin border or Text only. |
| **Level box gap** | 0 | Nameplate units between the health bar and a Square level box. Needs **Level box** at Thin border or Text only. |
| **Level number size** | 100% | 100% is the game's own size. Needs **Level box** at Thin border or Text only or Default. |

**Elite and Rare**

| Setting | Default | Notes |
| --- | --- | --- |
| **Mark after the level** | On | + for an Elite, R for a Rare, R+ for a Rare Elite. Needs **Level box** at Thin border or Text only or Default. |
| **Fading row behind the name** | Off | The friendly, neutral or hostile colour behind the name, fading upward. |

### Cast bar

| Setting | Default | Notes |
| --- | --- | --- |
| **Nameplate cast bar border** | On | A thin border round the nameplate cast bar in place of the game's frame. |
| **Nameplate cast bar background** | On | A dark background behind the nameplate cast bar. Needs **Nameplate cast bar border** on. |
| **Flat nameplate cast bar** | On | Uses the cast colours on the Colours page. |
| **Cast bar texture** | `default` | The fill of the flat nameplate cast bar; Same as the Flat UI page takes its Bar texture. Needs **Flat nameplate cast bar** on. |
| **Nameplate cast bar height** | 100% | 100% is the game's own height. |

**Spell name**

| Setting | Default | Notes |
| --- | --- | --- |
| **Spell name size** | 100% | 100% is the game's own size. |
| **Spell name outline** | As the game has it | The outline round the spell name; As the game has it keeps the game's own. Choices: As the game has it, None, Thin, Thick. |
| **Spell name colour** | #FFFFFF | The colour of the spell name on nameplate cast bars. |

**Parts**

| Setting | Default | Notes |
| --- | --- | --- |
| **Spell icon size** | 100% | 100% is the game's own size. |
| **Spark** | On | The game's bright spark at the moving end of the cast bar. Off hides it. |
| **Shield on uninterruptible casts** | On | The game's shield at the spell icon of a cast you cannot interrupt. Off hides it. |

**Cast time**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cast time** | On | Seconds left, at the right end of the bar, in the spell name's font and size; just past the end while the bar names the cast's target. |

### Marks and icons

**Target and focus**

| Setting | Default | Notes |
| --- | --- | --- |
| **Target and focus border** | On | Coloured border on your target and focus. |
| **Target colour** | #FFFFFF | The border colour of your target's nameplate. Needs **Target and focus border** on. |
| **Focus colour** | #FF9900 | The border colour of your focus's nameplate. Needs **Target and focus border** on. |
| **Target and focus border thickness** | 1 px | How thick the border of your target and focus is. Needs **Target and focus border** on. |
| **Flash as you change target** | On | The new target's border flashes once in Target colour and settles, and the focus's in Focus colour as you set it, so you see which nameplate Tab took. Needs **Target and focus border** on. |
| **Target mark** | On | A bright outline hugging your target's health bar and its level box in Target mark colour, clear of the threat ring, drawn above every nameplate round it, so your target reads at a glance in a pack. It follows the nameplate as Flat UI's own frame, so it shows at once, also on a nameplate the game first shows in a fight. |
| **Target mark colour** | #FFFFFF | The colour of the target mark, its glow and its arrows. Needs **Target mark** on. |
| **Soft glow round the mark** | On | A soft glow in Target mark colour fades out from the target mark, past the threat ring while that shows. Off leaves the bright outline alone. Needs **Target mark** on. |
| **Arrows at your target** | On | Two arrows in Target mark colour, edged in black so they read on bright ground, point in at your target's health bar from both sides, outside what sits beside it: its class icon, quest mark, level box, raid marker, elite icon, threat value and auras. They move out with the threat value as it grows in a fight. Needs **Target mark** on. |
| **Arrow size** | 100% | 100% makes each arrow about twice as tall as the health bar. Needs **Arrows at your target** on. |
| **Target nameplate size** | 120% | The game's own size of your target's nameplate against the others, so the nameplate Tab takes stands out; 120% is the game's own. The game keeps it for each character, so an alt has its own, whatever the profile. Sets the game's `nameplateSelectedScale`. |
| **Other nameplates' opacity** | 100% | While you have a target, the game fades every other nameplate to this, so your target stands out; 100% is no fade, as the game has it, and 80% a light one. The game keeps it on this computer, for every character, whatever the profile. Sets the game's `nameplateNotSelectedAlpha`. |

**Class icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Class icon on enemy players** | On | The icon of an enemy player's class at their nameplate, so a healer stands out before their colours do. |
| **Class icon on friendly players** | On | The icon of a friendly player's class at their nameplate. |
| **Class icon position** | Left | Left or right of the health bar, or above or below it. On a friendly player shown as a name only, it stands above the name. Choices: Left, Right, Above, Below. |
| **Class icon size** | Health bar height | Health bar height keeps the icon as tall as the bar, so it grows with Health bar height; Custom takes Custom class icon size. Choices: Health bar height, Custom. |
| **Custom class icon size** | 20 | The class icon's size while Class icon size is Custom. Needs **Class icon size** at Custom. |
| **Class icon gap** | 0 | Space between the health bar and the class icon. |
| **Class icon horizontal offset** | 0 | Moves the class icon left or right. |
| **Class icon vertical offset** | 0 | Moves the class icon up or down. |
| **Class icon shape** | Square | A square class icon, or a round one. Choices: Square, Round. |
| **Class icon border** | On | A thin border round the class icon. |

**Elite and Rare**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border colour for Elite and Rare** | On | Uses the Elite, Rare and Boss colours below. Your target and focus keep their own colour. |
| **Elite colour** | #FFD100 | The border colour of an Elite enemy's nameplate. Needs **Border colour for Elite and Rare** on. |
| **Rare colour** | #C7CCD6 | The border colour of a Rare or Rare Elite enemy's nameplate. Needs **Border colour for Elite and Rare** on. |
| **Boss colour** | #FF593D | The border colour of a boss's nameplate, an enemy whose level shows as a skull. Needs **Border colour for Elite and Rare** on. |

**Raid marker**

| Setting | Default | Notes |
| --- | --- | --- |
| **Raid marker** | On | The game's raid marker left of the health bar, at the size and offsets below. Off hides it on nameplates. |
| **Raid marker size** | 22 | The size of the raid marker on nameplates. |
| **Raid marker horizontal offset** | 0 | Moves the raid marker left or right. |
| **Raid marker vertical offset** | 0 | Moves the raid marker up or down. |
| **Arrow for nameplates behind you** | On | The game's arrow at the screen edge for nameplates behind you. Off hides it. |

**Overpower**

| Setting | Default | Notes |
| --- | --- | --- |
| **Overpower, Mongoose Bite or Riposte on enemy nameplates** | On | Warriors: when an enemy dodges you, Overpower shows over its nameplate for 5 seconds. Hunters: when Mongoose Bite becomes usable after you dodge, its icon shows over your target. Rogues: when Riposte becomes usable after you parry, its icon shows over your target. It glows while you can use it. |
| **Overpower icon size** | 34 | The size of the Overpower, Mongoose Bite or Riposte icon, and of its seconds with it. Needs **Overpower, Mongoose Bite or Riposte on enemy nameplates** on. |
| **Overpower icon horizontal offset** | 0 | Moves the icon left or right, and an Above quest mark with it. Needs **Overpower, Mongoose Bite or Riposte on enemy nameplates** on. |
| **Overpower icon vertical offset** | 0 | Moves the icon up or down, and an Above quest mark with it. Needs **Overpower, Mongoose Bite or Riposte on enemy nameplates** on. |
| **Time left on the Overpower icon** | On | A dark swipe drains over the icon for its 5 seconds, and starts again when a new dodge renews it. Needs **Overpower, Mongoose Bite or Riposte on enemy nameplates** on. |
| **Seconds on the Overpower icon** | On | The seconds left of its window, counting down in the middle of the icon, turning amber at 2 and red at its last second, dimmer while the icon is grey. Needs **Overpower, Mongoose Bite or Riposte on enemy nameplates** on. |

**Combo points**

| Setting | Default | Notes |
| --- | --- | --- |
| **Combo points on your target's nameplate** | On | Rogues and druids in Cat Form: five small squares under your target's nameplate light as you build points, and the newest pops as it lands. The row fades in with the first point and out as you spend them. |
| **Combo point colour** | #E8452E | The colour of a lit point; the points you do not have yet show in it faintly. Needs **Combo points on your target's nameplate** on. |
| **Full points stand out** | On | At your most points every square takes Full points colour and the row pops once. Needs **Combo points on your target's nameplate** on. |
| **Full points colour** | #FFD100 | The colour of every point while you sit at your most points. Needs **Full points stand out** on. |
| **Full points breathe** | On | While you sit at your most points the row breathes softly until you spend them. Needs **Full points stand out** on. |
| **Combo point size** | 7 | The size of each combo point square. Needs **Combo points on your target's nameplate** on. |
| **Combo points vertical offset** | 0 | Moves the row up or down, and a Below threat value with it. Needs **Combo points on your target's nameplate** on. |

**Quest**

| Setting | Default | Notes |
| --- | --- | --- |
| **Quest mark on enemies you need for a quest** | On | A small ! beside an enemy the game says belongs to a quest in your log, gone once that objective is done, and grey on an enemy someone else has tapped. |
| **Quest mark size** | 14 | The size of the quest mark, and of its kill count with it. Needs **Quest mark on enemies you need for a quest** on. |
| **Kill count beside the quest mark** | On | How many of that enemy you have slain and need, such as 3/8. It turns green at 8/8 as the objective completes, then the mark fades. Enemies that drop a quest item have no count. Needs **Quest mark on enemies you need for a quest** on. |
| **Quest mark position** | Left | Left goes past the threat value, the enemy's buffs, the raid marker and the elite or rare icon. Right goes past the threat texts and the enemy's crowd control icons. Above sits over the enemy's debuffs, an Above threat value and the Overpower icon. Choices: Left, Right, Above. Needs **Quest mark on enemies you need for a quest** on. |
| **Quest mark horizontal offset** | 0 | Moves the quest mark and its kill count left or right. Needs **Quest mark on enemies you need for a quest** on. |
| **Quest mark vertical offset** | 0 | Moves the quest mark and its kill count up or down. Needs **Quest mark on enemies you need for a quest** on. |
| **Leave quest marks to Questie** | On | While Questie draws its own icons on quest enemies, Flat UI's mark stays away. In dungeons, where Questie draws none on this game, and with Questie's nameplate icons off, Flat UI's marks show. Off, both show. Needs **Quest mark on enemies you need for a quest** on. |

### Auras

| Setting | Default | Notes |
| --- | --- | --- |
| **Aura icon border** | On | Square buff and debuff icons with a thin border. |
| **Aura icon crop** | 8% | How much of the edge of each aura icon is cut away, so the art fills the square. Needs **Aura icon border** on. |
| **Own aura border colour** | Off | Gives the borders of aura icons the colour below, in place of the usual border colour. Needs **Aura icon border** on. |
| **Aura border colour** | #000000 | The border colour of aura icons while Own aura border colour is on. Needs **Own aura border colour** on. |
| **Countdown numbers** | On | The game's countdown numbers on aura icons. Off hides them. |
| **Stack count** | On | The stack count on aura icons, such as 5 on Sunder Armor. Off hides it. |
| **Aura size** | 100% | The game's size of the buff and debuff icons on nameplates; 100% is its own. The game keeps it for your account, whatever the profile. Sets the game's `nameplateAuraScale`. |
| **Aura opacity** | 100% | How solid the buff and debuff icons on nameplates are; lower lets what is behind them show through. |
| **Show auras** | On every nameplate | On the target and focus also keeps your sheep, sap or shackle in sight on the focus's nameplate. Choices: On every nameplate, Only on the target, On the target and focus. |

### Size and clicks

**Clickable area**

| Setting | Default | Notes |
| --- | --- | --- |
| **Click through friendly nameplates** | Off | Works whether or not Restyle friendly nameplates is on. |
| **Where friendly nameplates are clicked through** | Everywhere | In dungeons and raids switches as you zone in and out, after the fight if you zone in one. Choices: Everywhere, In dungeons and raids. Needs **Click through friendly nameplates** on. |
| **Click through enemy nameplates** | Off | Target with Tab or a key binding. |
| **Extra clickable width** | 0 | Widens the part of a nameplate that takes a click on both sides, as far as the nameplate reaches; below 0 narrows it. |
| **Extra clickable height** | 0 | Heightens the part of a nameplate that takes a click above and below, as far as the nameplate reaches; below 0 makes it shorter. |

**Which show**

| Setting | Default | Notes |
| --- | --- | --- |
| **Enemy nameplates** | Off | The game's V key turns them on and off too. The game keeps it for your account, whatever the profile. Sets the game's `nameplateShowEnemies`. |
| **Friendly player nameplates** | Off | Shift+V in the game turns them on and off too. The game keeps it for your account, whatever the profile. Sets the game's `nameplateShowFriendlyPlayers`. |
| **Friendly NPC nameplates** | Off | Nameplates on friendly characters of the world, such as guards and vendors. The game keeps it for your account, whatever the profile. Sets the game's `nameplateShowFriendlyNpcs`. |
| **Always show nameplates** | On | Off, nameplates show only while you are in a fight. The game keeps it for your account, whatever the profile. Sets the game's `nameplateShowAll`. |
| **Cast bars on nameplates** | On | The game's cast bar under a nameplate while the unit casts. The game keeps it for each character, so an alt has its own, whatever the profile. Sets the game's `nameplateShowCastBars`. |
| **Nameplate distance** | 45 yd | How far away, in yards, nameplates still show. The game keeps it for each character, so an alt has its own, whatever the profile. Sets the game's `nameplateMaxDistance`. |
| **Nameplates on enemy pets and totems** | Off | Pets, totems and guardians of enemies. Off hides their nameplates, so a hunter's pet or a shaman's totems add no clutter. The game keeps it for your account, whatever the profile. Needs **Enemy nameplates** on. Sets the game's `nameplateShowEnemyMinions`. |
| **Nameplates on minor enemies** | Off | Weak enemies the game counts as minor. Minor enemies on the Threat tab says whether they show threat. The game keeps it for your account, whatever the profile. Needs **Enemy nameplates** on. Sets the game's `nameplateShowEnemyMinus`. |
| **Friendly players as names only** | Off | The game shows a friendly player's name without a health bar; with Class icon on friendly players the icon then stands above the name. The game keeps it for your account, whatever the profile. Needs **Friendly player nameplates** on. Sets the game's `nameplateShowOnlyNameForFriendlyPlayerUnits`. |

**Size and stacking**

| Setting | Default | Notes |
| --- | --- | --- |
| **Nameplate style** | Thin | Thin is a slim health bar and cast bar, Modern a taller health bar and level box, Block a tall health bar and a tall cast bar, and Cast focus a slim health bar with a tall cast bar. The game keeps it for your account, whatever the profile. Choices: Thin, Modern, Block, Cast focus. Sets the game's `nameplateStyle`. |
| **Nameplate size** | 1 | The percent sizes on the Nameplates pages work on top of the step chosen. The game keeps it for your account, whatever the profile. Sets the game's `nameplateSize`. |
| **Spread of enemy nameplates** | Overlap, as the game has it | Overlap leaves a pack's nameplates where the game puts them, over each other. A slight spread turns on the game's stacking for enemies with Vertical overlap at 70% and slows the plates' motion a little, so a pack still clusters but every nameplate shows. Stack them is the game's full stacking. It sets Stack enemy nameplates and Vertical overlap, and follows them as they change. The game keeps the stacking for your account and the overlap and motion on this computer, whatever the profile. Choices: Overlap, as the game has it, A slight spread, Stack them. |
| **Stack enemy nameplates** | Off | The game's stacking: enemy nameplates move apart up and down instead of covering each other, by Horizontal overlap and Vertical overlap. The game keeps it for your account, whatever the profile. |
| **Stack friendly nameplates** | Off | The same for friendly nameplates, so a crowd of players or guards stays readable. The game keeps it for your account, whatever the profile. |
| **Horizontal overlap** | 80% | While nameplates stack, lower keeps them further apart sideways. The game keeps it on this computer, for every character, whatever the profile. Sets the game's `nameplateOverlapH`. |
| **Vertical overlap** | 110% | While nameplates stack, how far apart they sit up and down: higher spreads them further, which makes room for taller bars, and lower lets them cluster. The game keeps it on this computer, for every character, whatever the profile. Sets the game's `nameplateOverlapV`. |
| **Nameplates at the unit's feet** | Off | The game puts other units' nameplates at their feet instead of over their heads. The game keeps it for your account, whatever the profile. Sets the game's `nameplateOtherAtBase`. |

**Scale and fade**

| Setting | Default | Notes |
| --- | --- | --- |
| **Far nameplate scale** | 80% | The size of nameplates at the far end of Nameplate distance; they grow to full size as units come near. The game keeps it for each character, so an alt has its own, whatever the profile. Sets the game's `nameplateMinScale`. |
| **Far nameplate opacity** | 60% | How solid nameplates at the far end of Nameplate distance are; they turn solid as units come near. The game keeps it for each character, so an alt has its own, whatever the profile. Sets the game's `nameplateMinAlpha`. |
| **Opacity behind obstacles** | 40% | How solid the nameplate of a unit behind a wall or another obstacle is; 0% hides it. The game keeps it for each character, so an alt has its own, whatever the profile. Sets the game's `nameplateOccludedAlphaMult`. |

## Cast bars

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle cast bars** | On |  |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Player cast bar border** | On | Flat UI's thin border on this bar in place of the game's frame art. |
| **Pet cast bar border** | On | Flat UI's thin border on this bar in place of the game's frame art. |
| **Target cast bar border** | On | Flat UI's thin border on this bar in place of the game's frame art. |
| **Focus cast bar border** | On | Flat UI's thin border on this bar in place of the game's frame art. |

**Look**

| Setting | Default | Notes |
| --- | --- | --- |
| **Cast bar background** | On | Flat UI's dark background behind each bar that has its border on. |
| **Spell name background** | Off | Keeps the game's own background behind the spell name. |
| **Spark** | On | The bright line at the end of the fill. Off hides it on every cast bar. |
| **Uninterruptible shield icon** | On | The game's shield beside a target or focus bar whose cast cannot be interrupted; off leaves Uninterruptible colour alone. |
| **Border takes the cast colour** | Off | The thin border takes the colour of the fill: Interrupted colour as a cast is stopped, Uninterruptible colour for a cast that cannot be interrupted. Needs **Flat fill** on. |
| **Latency zone on the player bar** | Off | The end of the bar your connection delay covers, in Latency zone colour: the right end of a cast, the left end of a channel, where it drains to. With or without Flat fill. |
| **Latency zone colour** | #FF0000 | Shown at 60% opacity, so the fill shows through. Red at first; pick another for a red bar or a class colour that hides it. Needs **Latency zone on the player bar** on. |
| **Spell queue window on the player bar** | Off | A thin line where the game starts taking your next spell press on each cast, its spell queue window (400 ms at first), so you see when to press the next Frostbolt. Casts only, not channels. With or without Flat fill. |
| **Spell queue window colour** | #FFFFFF | White at first; pick a dark one for a white or pale bar. Needs **Spell queue window on the player bar** on. |
| **Channel ticks on the player bar** | On | A thin mark where each tick of a channel lands, such as Arcane Missiles, Blizzard, Mind Flay or Drain Life. |
| **Channel tick colour** | #FFFFFF | At 60% opacity, fainter once its tick lands. White at first; pick a dark one for a white or pale bar, such as a priest's class colour. Needs **Channel ticks on the player bar** on. |

**Fill**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flat fill** | Off | A plain fill in the cast colours of the Colours page in place of the game's gold and green art. Needed for Bar texture, the class and own colours and Border takes the cast colour; the interrupt colours then fill the whole bar. |
| **Bar texture** | `default` | The texture of the Flat fill on every cast bar. Needs **Flat fill** on. |

**Colours**

| Setting | Default | Notes |
| --- | --- | --- |
| **Class colour on the player bar** | Off | Your class colour on your casts and channels, also on the cast fill of Flat UI's action buttons. Needs **Flat fill** on. |
| **Own colours on target and focus bars** | Off | Colours of their own for enemy casts on the target and focus bars, in place of Cast colour and Channel colour. The interrupt colours go before them while Interrupt readiness on enemy casts is on. Needs **Flat fill** on. |
| **Target and focus cast colour** | #E6B333 | The fill of an enemy's cast on the target and focus bars, in place of Cast colour. Needs **Own colours on target and focus bars** on. |
| **Target and focus channel colour** | #4DBF59 | The fill of an enemy's channel on the target and focus bars, in place of Channel colour. Needs **Own colours on target and focus bars** on. |

**Sound**

| Setting | Default | Notes |
| --- | --- | --- |
| **Sound when you are interrupted** | None | Plays as an enemy's Kick, Counterspell, Pummel, Earth Shock or stun stops your cast or channel. Moving, jumping or Escape plays nothing. Plays once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Sound when your interrupt lands** | None | Plays as your Kick, Counterspell, Pummel, Shield Bash, Earth Shock or your Felhunter's Spell Lock stops an enemy's cast, at most once a second. It plays when the game names you or your pet as the one who stopped the cast, on any enemy, a stun or silence of yours too, so a kick that missed, came late or came after another player's stays silent. When the game keeps that secret, it follows the target or focus bar turning Interrupted right after your interrupt. Plays once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Sound when your focus casts** | None | Plays as the enemy you focus starts a cast or channel while your interrupt is ready and in range, and again as your interrupt comes back or you come into range during the cast, once a cast and at most once a second, so you hear when to kick without watching the focus bar. Needs Interrupt readiness on enemy casts. A cast that cannot be interrupted may play it too, as the game does not always say. Plays once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |
| **Sound when your target casts** | None | Plays as the enemy you target starts a cast or channel while your interrupt is ready and in range, and again as your interrupt comes back or you come into range during the cast, once a cast and at most once a second. When your target is also your focus, only Sound when your focus casts plays. Needs Interrupt readiness on enemy casts. A cast that cannot be interrupted may play it too, as the game does not always say. Plays once as you pick it. Choices: None, Spell alert, Chimes, Bell, Warhorn, Raid warning, Alarm, Whisper warning. |

### Size

| Setting | Default | Notes |
| --- | --- | --- |
| **Player cast bar** | Width of the personal resource display | Width set below is the game's 208 while Custom player cast bar size is off. Choices: Width of the personal resource display, Width set below. |
| **Custom player cast bar size** | On | A change in a fight lands as it ends while the game protects the bar then, as under Edit Mode's Lock to player frame. |
| **Player cast bar width** | 266 | Needs **Custom player cast bar size** on. |
| **Player cast bar height** | 18 | Needs **Custom player cast bar size** on. |
| **Player cast bar text** | As the game has it | Where the spell name of your cast bar sits. As the game has it: inside the bar while Edit Mode's Lock to player frame is on, under it otherwise. Choices: As the game has it, Below the bar, Inside the bar. Needs **Custom player cast bar size** on. |
| **Custom pet cast bar size** | Off | A change in a fight lands as it ends while the game protects the bar then. |
| **Pet cast bar width** | 195 | Needs **Custom pet cast bar size** on. |
| **Pet cast bar height** | 13 | Needs **Custom pet cast bar size** on. |
| **Custom target cast bar size** | Off | A change in a fight lands as it ends. |
| **Target cast bar width** | 150 | Needs **Custom target cast bar size** on. |
| **Target cast bar height** | 10 | Needs **Custom target cast bar size** on. |
| **Custom focus cast bar size** | Off | A change in a fight lands as it ends. |
| **Focus cast bar width** | 150 | Needs **Custom focus cast bar size** on. |
| **Focus cast bar height** | 10 | Needs **Custom focus cast bar size** on. |

### Text and icon

**Text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Text size** | 100% | 100% is the game's own size. |
| **Text outline** | As the game has it | The outline of the spell name; the cast time, the target of the cast and the pushback beside it take it too. Choices: As the game has it, None, Thin, Thick. |
| **Spell name** | On | Off hides the spell name on every cast bar. Spell rank on the player bar needs it. |
| **Spell rank on the player bar** | Off | After the spell name, as Fireball (Rank 5): the rank you cast, not the highest you know. Also in a fight. Needs **Spell name** on. |
| **Spell name alignment** | As the game has it | Where the spell name sits along each cast bar, at any size and with Custom player cast bar size too: Left and Right put it at the bar's ends, on your own bar clear of Cast time on your bars. Choices: As the game has it, Left, Centre, Right. |
| **Own spell name colour** | Off | Spell name colour on the spell name of every cast bar, in place of the game's. On a Flat fill the seconds until your interrupt is ready take it too. |
| **Spell name colour** | #FFFFFF | Used while Own spell name colour is on. White at first. Needs **Own spell name colour** on. |
| **Cast time on target and focus bars** | On | Seconds left, at the right end of the bar, in the spell name's size and outline. |
| **Target of enemy casts** | On | Whom the cast on your target's or focus's bar is aimed at, as &gt; Bex, just past the bar's right end, so you see who is about to be hit or sheeped. The name takes the class colour of that player, as the game's nameplates colour it. It stays while the bar fades or holds Interrupted, so you still see whom a kicked cast was aimed at. |
| **Seconds until your interrupt is ready** | On | While an enemy you target or focus casts and your interrupt cools down, your own or your Felhunter's Spell Lock, its seconds left count down inside the left end of the bar, outlined, in Interrupt on cooldown colour, so you see whether Kick is back before the cast lands. On a Flat fill, which already takes that colour, the number is white, or Spell name colour with Own spell name colour. Works while Interrupt readiness on enemy casts is on. |
| **Cast time on your bars** | Off | Seconds left, inside the right end of your cast bar and your pet's; the game's own time from Edit Mode is hidden meanwhile. |
| **Total cast time too** | Off | Seconds left and the whole cast, as 1.2 / 2.5, on the bars of the two rows above. |
| **Pushback on your bar** | On | How far hits have set your cast back, as +0.5 in Pushback colour just past the right end of your cast bar, or after the game's own seconds from Edit Mode; a channel cut short shows -0.8. Each new delay makes it pop. It stays as the bar flashes or holds Interrupted, and fades with it. |
| **Pushback colour** | #FF4D4D | Needs **Pushback on your bar** on. |

**Icon**

| Setting | Default | Notes |
| --- | --- | --- |
| **Target and focus bar icon** | Left of the bar | A change in a fight lands as it ends. Choices: Left of the bar, Right of the bar, Hidden. |
| **Spell icon on player and pet bars** | Off | The icon of the spell left of your cast bar and your pet's, as tall as the bar. With or without Flat fill. It stays while the bar fades or holds Interrupted. The game's own small icon, which Edit Mode's Lock to player frame shows, gives way to it. |

## Personal resource display

### General

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle the personal resource display** | On |  |

**Bars**

| Setting | Default | Notes |
| --- | --- | --- |
| **Health border** | On |  |
| **Power border** | On |  |
| **Alternate power border** | On |  |
| **Resource bar background** | On |  |
| **Join bars** | On | Removes the space between the bars. |

**Fill**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flat fill** | On |  |
| **Bar texture** | `default` | Needs **Flat fill** on. |
| **Custom health colour** | On |  |
| **Health colour** | #2EB84D | Needs **Custom health colour** on. |
| **Class colour** | Off | Your class colour on the health bar, in place of the Health colour. |
| **Custom power colour** | Off | One colour for every power type. |
| **Power colour** | #3D7DD9 | Needs **Custom power colour** on. |
| **Colour health by health left** | Off | Needs **Flat fill** on. |

**Text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Text size** | 100% | 100% is the game's own size. |
| **Text outline** | As the game has it | Choices: As the game has it, None, Thin, Thick. |
| **Health and power numbers** | On |  |
| **Percentage text** | On | Needs **Health and power numbers** on. |
| **Value text** | On | Needs **Health and power numbers** on. |
| **Own text colour** | Off |  |
| **Text colour** | #FFFFFF | Needs **Own text colour** on. |

**Absorb shields**

| Setting | Default | Notes |
| --- | --- | --- |
| **Absorb shields on the health bar** | Bright layer over the health | Your shields as a bright layer that starts where your health ends. A shield bigger than your missing health runs on back over your health, so its full size shows, with a thin bright edge where it ends. Plain fill stops at the end of the bar. Works in a fight. Choices: Bright layer over the health, Plain fill after the health, Off. |
| **Shield colour** | #D8E8FF | Needs **Absorb shields on the health bar** at Bright layer over the health or Plain fill after the health. |
| **Shield opacity** | 60% | How strongly the shield covers the health under it. Needs **Absorb shields on the health bar** at Bright layer over the health or Plain fill after the health. |
| **Sheen** | On | A slow light sweeps across the shield every few seconds. Needs **Absorb shields on the health bar** at Bright layer over the health. |
| **Shield outline** | On | Frames the whole health bar in the shield colour while a shield is up. Needs **Absorb shields on the health bar** at Bright layer over the health. |
| **Shield amount** | Off | The amount of your shields beside the health text, inside the bar, as +1,234 12,345, in the shield colour. Needs **Absorb shields on the health bar** at Bright layer over the health or Plain fill after the health. |

### Your buffs

| Setting | Default | Notes |
| --- | --- | --- |
| **Your buffs** | On | Short buffs you cast, with their time left. |

**Buffs**

| Setting | Default | Notes |
| --- | --- | --- |
| **Buffs shown** | Both | Choices: Short buffs of your class, Every buff you cast, Both. |
| **Time limit** | 60 s | Buffs that last longer do not show. |
| **Buffs that have a tracker** | Show here too | Choices: Show here too, Leave out. |

**Icons**

| Setting | Default | Notes |
| --- | --- | --- |
| **Time left** | On the icon | Under or on the icon, the time turns amber in its last 5 seconds. Out of combat with none of these buffs up, a change of this or another row of the look shows samples in the new look for a few seconds. Choices: Under the icon, On the icon, Thin bar under the icon, Off. |
| **Icon size** | 40 | The numbers on the icon grow and shrink with it. |
| **Spacing** | 3 |  |
| **Icon border** | On |  |
| **Flash when one lands** | On | A quick white flash on the icon as one of these buffs comes, not when one that shows is cast again. Drawn by the game, so also in a fight. |
| **Sound when one ends** | None | Once as one of the short buffs of your class leaves you, such as Slice and Dice, also in a fight, since the game plays it. Also for your own defensives shown on Defensives on you, such as Ice Barrier or Shield Wall. A buff with a tracker is left out, since the tracker has its own sound, and so is one that lasts longer than Time limit. Out of combat, a pick plays it. Choices: None, Raid warning, Alarm, Whisper warning. |
| **Bar texture** | `default` | Needs **Time left** at Thin bar under the icon. |
| **Buff tooltips** | On | Settings on the Tooltips page do not change this tooltip. Choices: On, Out of combat only, Off. |

**Position**

| Setting | Default | Notes |
| --- | --- | --- |
| **Place** | Above the bars | Own position has a handle in /flatui move. Out of combat with none of these buffs up, a change of this or an offset shows the samples where the row now sits. Choices: Above the bars, Under the bars, Under the swing timer, Own position. |
| **X offset** | 0 |  |
| **Y offset** | 0 |  |

## Swing timers

| Setting | Default | Notes |
| --- | --- | --- |
| **Restyle swing timers** | On | Off leaves the game's swing timers as they are. |

**Timers**

| Setting | Default | Notes |
| --- | --- | --- |
| **Main hand border** | On | Flat UI's thin border on this timer in place of the game's frame art. |
| **Off hand border** | On | Flat UI's thin border on this timer in place of the game's frame art. |
| **Ranged border** | On | Flat UI's thin border on this timer in place of the game's frame art. |

**Size**

| Setting | Default | Notes |
| --- | --- | --- |
| **Width** | Width of the personal resource display | Width of the personal resource display keeps the timers as wide as that display, following it as it changes. Choices: Width of the personal resource display, Width set in Edit Mode. |

**Border**

| Setting | Default | Notes |
| --- | --- | --- |
| **Border around** | Bar only | Bar only frames the fill; Whole timer frames the name and time too. Choices: Bar only, Whole timer. |
| **Timer background** | On | Flat UI's dark background behind each timer that has its border on. |

**Fill**

| Setting | Default | Notes |
| --- | --- | --- |
| **Flat fill** | On | A plain fill in the three colours below, in place of the game's art. Needed for Bar texture, the colours, Class colour, Spark and Text shadow. |
| **Bar texture** | `default` | The texture of the Flat fill on all three timers. Needs **Flat fill** on. |
| **Main hand colour** | #D9A640 | The fill of the main hand timer, unless Class colour is on. Needs **Flat fill** on. |
| **Off hand colour** | #5C9FD6 | The fill of the off hand timer, unless Class colour is on. Needs **Flat fill** on. |
| **Ranged colour** | #73B85C | The fill of the ranged timer, unless Class colour is on. Needs **Flat fill** on. |
| **Class colour** | Off | Your class colour on all three timers, in place of the three colours above. Needs **Flat fill** on. |
| **Spark** | On | The bright line at the end of the fill. Needs **Flat fill** on. |
| **Text shadow** | Off | The dark band behind the timer's name. Needs **Flat fill** on. |
| **Fill from the right** | Off | The fill grows from the right end, and the Auto Shot window moves to the left end. |

**Auto Shot**

| Setting | Default | Notes |
| --- | --- | --- |
| **Auto Shot window** | On | Marks the last half second of the ranged timer. Moving or casting a spell then delays your next Auto Shot. |
| **Auto Shot window colour** | #E04848 | Needs **Auto Shot window** on. |

**Next melee ability**

| Setting | Default | Notes |
| --- | --- | --- |
| **Queued next melee ability** | On | Colours the main hand timer while Heroic Strike, Cleave, Maul or Raptor Strike waits for your next swing, and gives it its own colour back as the swing lands. |
| **Queued ability colour** | #E8802E | Needs **Queued next melee ability** on. |

**Out of range and idle**

| Setting | Default | Notes |
| --- | --- | --- |
| **Out of range opacity** | 40% | How see-through a timer is while your target is out of its reach. The game's own is 40%. |
| **Show the timer** | In combat | Works with Main hand border, Off hand border or Ranged border on. In combat and Only while swinging fade the timer and its border out over a quarter second as the fight ends or the swings stop. With Edit Mode's own Visibility at In combat, the game hides the timer itself, at once. Choices: Always, In combat, Only while swinging. |

**Text**

| Setting | Default | Notes |
| --- | --- | --- |
| **Text size** | 100% | 100% is the game's own size. |
| **Text outline** | As the game has it | Choices: As the game has it, None, Thin, Thick. |
| **Timer name** | On | The timer's name, as Main Hand, at its left end. |
| **Time left** | On | The seconds until the next swing or shot, at the right end. |
| **Own text colour** | Off |  |
| **Text colour** | #FFFFFF | Needs **Own text colour** on. |
| **Out of range text colour** | #FF1A1A | Needs **Own text colour** on. |
