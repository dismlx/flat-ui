#!/usr/bin/env python3
"""Write extras/Provisions/Data.lua from the GrunzForever export of the WoW: Forever client.

The export (MIT) is a SQLite file of the client's own DB2 tables with their hotfixes applied. Every consumable is
classified from those tables, never by its name (a name is read only to drop the client's test items):

  heal     an on-use item whose spell heals the player at once (Effect HEAL on the caster); amount = the mean heal
           (the spell's base points: the variance is spread evenly on both sides of it)
  mana     the same with an ENERGIZE effect of mana; amount = mana restored
  stone    a heal item that is conjured (item flag), made by a spell (CREATE_ITEM) and restores no mana: the
           healthstones
  food     a seated aura of health regeneration (MOD_REGEN, broken by standing up); amount = health over its duration
  drink    a seated aura of mana regeneration (MOD_POWER_REGEN of mana); amount = mana over its duration
  both     an item that is food and drink: it is listed in both kinds
  bandage  a channelled heal over time on a friendly target (PERIODIC_HEAL on TARGET_UNIT_TARGET_ALLY) that needs a
           skill (First Aid, by the item's RequiredSkill); amount = healing over the channel, rank = the skill it needs
  buff     food or drink whose eating also gives a lasting buff (by a TRIGGER_SPELL, a PERIODIC_TRIGGER_SPELL or a
           PERIODIC_TRIGGER_SPELL_WITH_VALUE that hands its value to the buff); the buff's stat and amount are kept

Run:  python3 -I extras/tools/make_provisions_data.py [path/to/export.sqlite]
The output is the same for the same export: items are written in order of their ID.
"""

import collections
import json
import os
import re
import sqlite3
import sys

DEFAULT_DB = ("/tmp/claude-0/-workspace-flat-ui/1819971d-cb59-55bd-aea4-74e460d4a9fd/scratchpad/spelltips/"
              "dl_grunz_sqlite/wow_wowf_1.60.1.70888.sqlite")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Provisions", "Data.lua")

# Item.ClassID of consumables; ItemEffect.TriggerType of an on-use effect.
CLASS_CONSUMABLE = 0
TRIGGER_ON_USE = 0
# ItemSparse.Flags[0] bits.
ITEM_FLAG_CONJURED = 0x2
ITEM_FLAG_DEPRECATED = 0x10
# SpellEffect.Effect values.
EFFECT_SCHOOL_DAMAGE = 2
EFFECT_APPLY_AURA = 6
EFFECT_HEAL = 10
EFFECT_CREATE_ITEM = 24
EFFECT_ENERGIZE = 30
EFFECT_TRIGGER_SPELL = 64
# SpellEffect.EffectAura values.
AURA_PERIODIC_DAMAGE = 3
AURA_PERIODIC_HEAL = 8
AURA_PERIODIC_TRIGGER_SPELL = 23
AURA_MOD_REGEN = 84            # food: health per 5 seconds while seated
AURA_MOD_POWER_REGEN = 85      # drink: power (EffectMiscValue[0]) per 5 seconds while seated
AURA_PERIODIC_TRIGGER_SPELL_WITH_VALUE = 227
# ImplicitTarget[0] values.
TARGET_UNIT_CASTER = 1
TARGET_UNIT_TARGET_ALLY = 21
POWER_MANA = 0
# SpellInterrupts.AuraInterruptFlags[0] bit: the aura ends when the player stands up (food and drink).
AURA_INTERRUPT_STANDING = 0x40000
# A triggered aura that lasts at least this long is a buff, not part of the meal.
BUFF_MIN_MS = 60000

# The buff of a buff food, by the aura its spell applies: (aura, EffectMiscValue[0] or None) -> key.
STAT_BY_MISC = {0: "str", 1: "agi", 2: "sta", 3: "int", 4: "spi", -1: "stats"}
BUFF_AURAS = {
    29: "stat",     # MOD_STAT, the stat in EffectMiscValue[0]
    99: "ap",       # MOD_ATTACK_POWER
    124: "rap",     # MOD_RANGED_ATTACK_POWER
    13: "spell",    # MOD_DAMAGE_DONE (spell schools)
    135: "healing", # MOD_HEALING_DONE
    290: "crit",    # MOD_CRIT_PCT
    52: "crit",     # MOD_WEAPON_CRIT_PERCENT
    57: "spellcrit",  # MOD_SPELL_CRIT_CHANCE
    85: "mp5",      # MOD_POWER_REGEN (mana, outside a meal)
    161: "hp5",     # MOD_HEALTH_REGEN_IN_COMBAT
    84: "hp5",      # MOD_REGEN (outside a meal)
    22: "resist",   # MOD_RESISTANCE
    189: "rating",  # MOD_RATING
    24: "mp5",      # PERIODIC_ENERGIZE (mana, every few seconds)
    129: "speed",   # MOD_INCREASE_SPEED
    30: "skill",    # MOD_SKILL (a profession)
    465: "armor",   # MOD_BONUS_ARMOR
}
# Auras that are no buff (harm or nothing to show).
NOT_BUFF_AURAS = (AURA_PERIODIC_DAMAGE, 4)  # 4 = DUMMY

# Names of the client's test and placeholder items (the only use of a name).
TEST_NAME = re.compile(r"\b(test|qa|dnt|deprecated|unused|ph|old)\b|\[|mcweaksauce", re.I)


def flags0(text):
    try:
        return int(json.loads(text)[0]) & 0xFFFFFFFF
    except (ValueError, TypeError, IndexError):
        return 0


def first(text):
    try:
        return int(json.loads(text)[0])
    except (ValueError, TypeError, IndexError):
        return 0


def main(argv):
    db = argv[1] if len(argv) > 1 else DEFAULT_DB
    con = sqlite3.connect("file:" + db + "?mode=ro", uri=True)
    meta = dict(con.execute("SELECT Key, Value FROM _ExtractionMetadata"))

    effects = collections.defaultdict(list)
    for row in con.execute(
            "SELECT SpellID, EffectIndex, Effect, EffectAura, EffectBasePointsF, EffectAuraPeriod, EffectTriggerSpell, "
            "EffectMiscValue, ImplicitTarget FROM SpellEffect WHERE DifficultyID = 0 ORDER BY SpellID, EffectIndex"):
        effects[row[0]].append({"index": row[1], "effect": row[2], "aura": row[3], "bp": row[4], "period": row[5],
                                "trigger": row[6], "misc": first(row[7]), "target": first(row[8])})
    duration = {}
    for spell, ms in con.execute(
            "SELECT m.SpellID, d.Duration FROM SpellMisc m JOIN SpellDuration d ON d.ID = m.DurationIndex "
            "WHERE m.DifficultyID = 0"):
        duration[spell] = ms or 0
    seated = set()
    for spell, flags in con.execute("SELECT SpellID, AuraInterruptFlags FROM SpellInterrupts WHERE DifficultyID = 0"):
        if first(flags) & AURA_INTERRUPT_STANDING:
            seated.add(spell)
    spell_category = dict(con.execute("SELECT SpellID, Category FROM SpellCategories WHERE DifficultyID = 0"))
    cast_time = dict(con.execute(
        "SELECT m.SpellID, t.Base FROM SpellMisc m JOIN SpellCastTimes t ON t.ID = m.CastingTimeIndex "
        "WHERE m.DifficultyID = 0"))
    spell_category_cd = dict(con.execute(
        "SELECT SpellID, CategoryRecoveryTime FROM SpellCooldowns WHERE DifficultyID = 0"))
    zone_spells = set(r[0] for r in con.execute(
        "SELECT SpellID FROM SpellCastingRequirements WHERE RequiredAreasID > 0"))
    created = set(r[0] for r in con.execute(
        "SELECT DISTINCT EffectItemType FROM SpellEffect WHERE Effect = ? AND EffectItemType > 0",
        (EFFECT_CREATE_ITEM,)))
    spell_name = dict(con.execute("SELECT ID, Name_lang FROM SpellName"))
    skill_parent = dict(con.execute("SELECT ID, ParentSkillLineID FROM SkillLine"))

    def chain(spell, depth=0):
        """The effects of a spell and of the spells it triggers at once (TRIGGER_SPELL), with their spell."""
        out = []
        for e in effects.get(spell, []):
            out.append((spell, e))
            if e["effect"] == EFFECT_TRIGGER_SPELL and e["trigger"] and depth < 3:
                out.extend(chain(e["trigger"], depth + 1))
        return out

    def buff_of(spell, value):
        """The stats and amounts of a buff spell, as {key: amount} (value: the amount its trigger hands over to it,
        PERIODIC_TRIGGER_SPELL_WITH_VALUE, taken as the size of each of its auras; None: its own base points)."""
        if duration.get(spell, 0) < BUFF_MIN_MS:
            return None
        got = {}
        for e in effects.get(spell, []):
            if e["effect"] != EFFECT_APPLY_AURA or e["aura"] in NOT_BUFF_AURAS:
                continue
            kind = BUFF_AURAS.get(e["aura"], "other")
            if kind == "stat":
                kind = STAT_BY_MISC.get(e["misc"], "other")
            if kind == "mp5" and e["misc"] != POWER_MANA:
                kind = "other"
            amount = value if value is not None else (e["bp"] or 0)
            if kind not in got:
                got[kind] = amount
        if "ap" in got and "rap" in got:
            del got["rap"]
        if len(got) > 1 and "other" in got:
            del got["other"]
        return got or None

    rows = con.execute(
        "SELECT i.ID, s.Display_lang, s.RequiredLevel, s.RequiredSkill, s.RequiredSkillRank, s.Flags, "
        "e.SpellID, e.SpellCategoryID, e.CategoryCoolDownMSec "
        "FROM Item i JOIN ItemSparse s ON s.ID = i.ID JOIN ItemXItemEffect x ON x.ItemID = i.ID "
        "JOIN ItemEffect e ON e.ID = x.ItemEffectID "
        "WHERE i.ClassID = ? AND e.TriggerType = ? ORDER BY i.ID, e.LegacySlotIndex, e.ID",
        (CLASS_CONSUMABLE, TRIGGER_ON_USE)).fetchall()

    by_item = collections.OrderedDict()
    for row in rows:
        by_item.setdefault(row[0], []).append(row)

    items = {}
    buff_spells = {}
    dropped_test = []
    for item_id, uses in by_item.items():
        name, level, skill, rank, flags = uses[0][1] or "", uses[0][2] or 0, uses[0][3] or 0, uses[0][4] or 0, \
            flags0(uses[0][5])
        if flags & ITEM_FLAG_DEPRECATED:
            continue
        heal = mana = food = drink = bandage = 0
        buff = None
        harmful = zone = False
        category = cooldown = 0
        for use in uses:
            spell = use[6]
            if not spell:
                continue
            item_cat = (use[7] or 0) & 0xFFFF
            cat = item_cat or spell_category.get(spell, 0)
            cd = use[8] if (use[8] or 0) > 0 else spell_category_cd.get(spell, 0)
            # The shared cooldown, kept only for an instant item: its use starts the category's cooldown before
            # the next line of the same macro press runs (Core.lua, Body).
            if cat and cd and cd > 0 and not category and cast_time.get(spell, 0) == 0:
                category, cooldown = cat, cd
            for sp, e in chain(spell):
                if sp in zone_spells:
                    zone = True
                eff, aura, bp, target = e["effect"], e["aura"], e["bp"] or 0, e["target"]
                if eff == EFFECT_SCHOOL_DAMAGE and target == TARGET_UNIT_CASTER:
                    harmful = True
                elif eff == EFFECT_HEAL and target == TARGET_UNIT_CASTER:
                    heal += bp
                elif eff == EFFECT_ENERGIZE and target == TARGET_UNIT_CASTER and e["misc"] == POWER_MANA:
                    mana += bp
                elif eff == EFFECT_APPLY_AURA:
                    ms = duration.get(sp, 0)
                    if aura == AURA_PERIODIC_DAMAGE and target == TARGET_UNIT_CASTER:
                        harmful = True
                    elif aura == AURA_MOD_REGEN and sp in seated and ms > 0:
                        food += bp * ms / 5000.0
                    elif aura == AURA_MOD_POWER_REGEN and sp in seated and ms > 0 and e["misc"] == POWER_MANA:
                        drink += bp * ms / 5000.0
                    elif aura == AURA_PERIODIC_HEAL and target == TARGET_UNIT_TARGET_ALLY and skill and e["period"]:
                        bandage += bp * ms / float(e["period"])
                    elif aura == AURA_PERIODIC_TRIGGER_SPELL_WITH_VALUE and e["trigger"]:
                        got = buff_of(e["trigger"], bp)
                        if got and not buff:
                            buff = (got, e["trigger"])
                    elif aura == AURA_PERIODIC_TRIGGER_SPELL and e["trigger"]:
                        got = buff_of(e["trigger"], None)
                        if got and not buff:
                            buff = (got, e["trigger"])
                if eff == EFFECT_TRIGGER_SPELL and e["trigger"]:
                    got = buff_of(e["trigger"], None)
                    if got and not buff:
                        buff = (got, e["trigger"])
        meal = food > 0 or drink > 0
        if not (meal or bandage or heal or mana) or harmful:
            continue
        if TEST_NAME.search(name):
            dropped_test.append((item_id, name))
            continue
        rec = {"name": name, "level": max(level, 1)}
        if flags & ITEM_FLAG_CONJURED:
            rec["conjured"] = True
        if zone:
            rec["zone"] = True
        if meal:
            if food:
                rec["food"] = int(round(food))
            if drink:
                rec["drink"] = int(round(drink))
            if buff:
                rec["buff"] = dict((k, int(round(v))) for k, v in buff[0].items())
                rec["buffSpell"] = buff[1]
                buff_spells[buff[1]] = (list(buff[0]), spell_name.get(buff[1], ""))
        elif bandage:
            rec["bandage"] = int(round(bandage))
            rec["skill"] = skill
            rec["firstAid"] = max(rank, 1)
        else:
            if heal:
                if flags & ITEM_FLAG_CONJURED and item_id in created and not mana:
                    rec["stone"] = int(round(heal))
                else:
                    rec["heal"] = int(round(heal))
            if mana:
                rec["mana"] = int(round(mana))
            if category:
                rec["cd"] = category
        items[item_id] = rec

    skills = set()
    for rec in items.values():
        if rec.get("skill"):
            skills.add(rec["skill"])
            if skill_parent.get(rec["skill"]):
                skills.add(skill_parent[rec["skill"]])

    counts = collections.Counter()
    for rec in items.values():
        if "buff" in rec:
            counts["buff"] += 1
            continue
        for k in ("heal", "mana", "stone", "food", "drink", "bandage"):
            if k in rec:
                counts[k] += 1
        if "food" in rec and "drink" in rec:
            counts["both"] += 1

    write(items, buff_spells, sorted(skills), meta, counts)
    print("items:", len(items), dict(sorted(counts.items())), "buff spells:", len(buff_spells),
          "dropped test items:", len(dropped_test))
    for item_id, name in dropped_test:
        print("  dropped", item_id, name)


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(items, buff_spells, skills, meta, counts):
    out = []
    out.append("-- Provisions data: every consumable a player can use, classified from the client's own tables.")
    out.append("-- Generated by extras/tools/make_provisions_data.py; do not edit by hand.")
    out.append("-- Source: the GrunzForever export of the WoW: Forever client (MIT), %s build %s (%s)."
               % (meta.get("Product", "?"), meta.get("Version", "?"), meta.get("BuildName", "?")))
    out.append("-- Tables read: Item, ItemSparse, ItemXItemEffect, ItemEffect, SpellEffect, SpellMisc, SpellDuration,")
    out.append("-- SpellInterrupts, SpellCategories, SpellCooldowns, SpellCastTimes, SpellCastingRequirements, SpellName,")
    out.append("-- SkillLine.")
    out.append("-- Counts: " + ", ".join("%s %d" % (k, counts[k]) for k in
                                         ("heal", "mana", "stone", "food", "drink", "both", "bandage", "buff")) + ".")
    out.append("--")
    out.append("-- Each item: heal/mana/stone = amount restored at once; food/drink = health/mana over the meal; both kinds")
    out.append("-- on one item = food and drink. bandage = healing over the channel, firstAid = the First Aid rank it")
    out.append("-- needs (skill = the skill line). buff = the stats of its buff and their amounts (buffSpell = the aura).")
    out.append("-- level = the level it needs; conjured = the item's conjured flag; zone = usable only in some areas")
    out.append("-- (checked with C_Item.IsUsableItem); cd = its shared cooldown category, when it has one and is instant.")
    out.append("")
    out.append("local _, ns = ...")
    out.append("")
    out.append("ns.FIRST_AID_SKILLS = { " + ", ".join(str(s) for s in skills) + " }")
    out.append("")
    out.append("-- The buffs of buff food, by the spell of the aura: the stats it raises, in the order of its effects.")
    out.append("ns.BUFF_SPELLS = {")
    for spell in sorted(buff_spells):
        stats, name = buff_spells[spell]
        out.append("\t[%d] = { %s }, -- %s" % (spell, ", ".join(lua_string(k) for k in stats), name))
    out.append("}")
    out.append("")
    out.append("ns.ITEMS = {")
    order = ("heal", "mana", "stone", "food", "drink", "bandage", "firstAid", "skill", "buff", "buffSpell", "level", "conjured", "zone", "cd")
    for item_id in sorted(items):
        rec = items[item_id]
        parts = []
        for k in order:
            if k not in rec:
                continue
            v = rec[k]
            if v is True:
                parts.append("%s = true" % k)
            elif isinstance(v, dict):
                parts.append("%s = { %s }" % (k, ", ".join("%s = %d" % (b, v[b]) for b in sorted(v))))
            elif isinstance(v, str):
                parts.append("%s = %s" % (k, lua_string(v)))
            else:
                parts.append("%s = %d" % (k, v))
        out.append("\t[%d] = { %s }, -- %s" % (item_id, ", ".join(parts), rec["name"].replace("\n", " ")))
    out.append("}")
    out.append("")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out))


if __name__ == "__main__":
    main(sys.argv)
