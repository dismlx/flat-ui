# Provisions

One button for each kind of consumable, whatever its rank or name: healing potion, mana potion, healthstone,
food, drink, bandage and buff food. Each button always uses the best item in your bags. For WoW: Forever
(client 1.60.1).

## Install

Unzip `Provisions-1.0.0.zip` into the `Interface/AddOns` folder of your WoW: Forever client, so that you have
`Interface/AddOns/Provisions/Provisions.toc`. Restart the game or type `/reload`.

## Use

- Type `/prov` (or `/provisions`), or open Settings > AddOns > Provisions.
- Drag an icon from the panel to an action bar (or click it to pick it up). Each icon is a macro of your
  character: Prov Heal, Prov Mana, Prov Stone, Prov Food, Prov Drink, Prov Bandage, Prov Buff Food.
- Or bind keys without using a bar slot: Key Bindings (Esc > Options > Keybindings), section Provisions.
- Tick or untick a row to turn that kind on or off. Mana potion and Drink start off for warriors and rogues.
  A kind that is off has no macro (Provisions deletes its own macro, but only once it is off your bars; until
  then a press only says that the kind is off).
- With nothing of a kind in your bags the button shows a question mark, and a press says
  "No healing potion in your bags." (or food, and so on) in chat.

## The kinds

| Button | Uses | Best is the one that |
| --- | --- | --- |
| Healing potion | potions and other items that heal you at once | heals the most (mean heal) |
| Mana potion | potions and mana gems that restore mana at once | restores the most mana |
| Healthstone | healthstones | heals the most |
| Food | food (health while seated); never buff food | restores the most health |
| Drink | drinks (mana while seated); never buff drinks | restores the most mana |
| Bandage | First Aid bandages your First Aid rank allows | heals the most |
| Buff food | food and drink that give a lasting buff | gives the most of the buff you chose |

An item that is both food and drink counts as both. An item counts only when it is in your bags and you can use
it now: your level, your First Aid rank for bandages, and for battleground rations and bandages the game's own
"usable here" answer.

How the best is chosen, in order:

1. Conjured first (option, on by default): conjured water, food and mana gems are free and vanish, so they go
   before bought ones. Not for healing potions: a conjured one (a Perishable potion, Lily Root) shares the
   two-minute potion cooldown, so a weak one first would spend that cooldown on a small heal in a fight; healing
   potions are always strongest first. Mana gems have a cooldown of their own, apart from the potions'.
2. Then the one that restores the most.
3. Then the lowest item ID. Ties are settled by the item, not by how many you carry, so the button never flips
   between two equal items as your stacks go up and down.

The healing potion, mana potion and healthstone macros also hold `/use` lines for your next items of the same
shared cooldown, so a press in a fight still works when the best runs out before the macro can be rewritten. This
is safe: those items share one cooldown, so once one is used the next line finds it "not ready" and uses nothing.

Bandages go on your mouseover or friendly target, else on you (option: only on you).

## Buff food

Buff food is worth more for its buff than for its health, so:

- The Food and Drink buttons never eat buff food. An option (off by default) lets them eat it when your bags hold
  no plain food or drink, so you are never stuck without something to eat.
- The Buff Food button eats the best buff food of the buff you chose, per character:
  - **Auto** (default): the stats your class wants first. Warrior: Stamina, Strength, Attack power, Agility,
    Critical strike, Armor. Paladin: Stamina, Strength, Intellect, Healing power, Spirit, Mana regeneration. Hunter:
    Agility, Attack power, Ranged attack power, Critical strike, Intellect. Rogue: Agility, Attack power,
    Critical strike, Strength. Priest: Intellect, Spirit, Mana regeneration, Healing power, Spell damage. Shaman:
    Intellect, Mana regeneration, Spirit, Healing power, Spell damage, Agility. Mage: Intellect, Spirit, Mana
    regeneration, Spell damage, Spell critical strike. Warlock: Intellect, Spirit, Mana regeneration, Spell
    damage, Stamina. Druid: Intellect, Spirit, Mana regeneration, Healing power, Stamina, Agility. Then Stamina,
    then the strongest of any.
  - **A stat or effect** of your choice (only those some food gives are offered).
  - **Any**: the strongest buff. Buffs of different stats are weighed by a rough worth per point (one point of a
    primary stat = 1, attack power 0.5, spell damage 0.86, healing 0.45, 1% critical strike 14, mana or health
    regeneration 2.5, and so on); movement speed and profession skill buffs count for nothing here.
  - When none of the chosen buff is in your bags it falls back to Any, and its line in the panel says so.
- A food buff does not stack on another: eating replaces the one you have. The macro cannot know your buffs in a
  fight, so it is the same with or without one, but the panel shows the food buff on you and its time left, and
  says when eating would replace it, and with something weaker. Provisions reads your buffs out of combat only;
  when the game does not say, the panel says "unknown".

## What it does not do

- It cannot change anything in a fight: the game forbids addons to change macros or secure buttons then. Every
  change waits for the fight to end. The healing potion, mana potion and healthstone buttons carry your next items
  so they still work.
- It never touches a macro it did not make. If you already have a character macro named like one of its own, it
  leaves it alone and says so once. If your character's macro list (30) is full, it says so once and makes its
  macros when you free a slot.
- It never writes while the game's macro window is open (that window reloads the text you are editing).
- It does not pick between potions by price: a rejuvenation potion that heals more than your healing potion comes
  first on the Healing potion button.

## Credits

Item data: the GrunzForever export of the WoW: Forever client (MIT), build 1.60.1.70888. `Data.lua` is generated
from it by `extras/tools/make_provisions_data.py`, which classifies every consumable from the client's own tables
(Item, ItemSparse, ItemEffect, SpellEffect and others), not by name.
