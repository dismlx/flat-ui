#!/usr/bin/env python3
"""Reads the WoW: Forever client's spell rows into tools/dev/spelltips/client_spells.json (design 3.1).

Usage: python3 tools/dev/spelltips_import.py CAPTURE SQLITE

CAPTURE is wowsims/forever's capture of the Forever client's spell rows (assets/db_inputs/spell_store_inputs.json, plain or
gzipped): build 1.60.1.70938 with hotfix push 114122, every class (its Builds and Hotfixes keys; the hotfix push of the spell rows is
the largest of the class groups, as the items group has its own). SQLITE is GrunzForever's export of every client table
(wow_wowf_1.60.1.70888.sqlite: build 1.60.1.70888 with the hotfixes of its date); its build is the Version of its _ExtractionMetadata
table, else the 1.60.1.NNNNN of its file name, and the import stops when it finds neither. Every row comes from the capture; the export
gives only what the capture lacks: the rows of the few spells it holds no row of (Attack and the generic shots), the description
variables (SpellXDescriptionVariables, SpellDescriptionVariables), the description of 70888 of each spell that has variables (so
make_spelltips.py can see the text is the same in 70938) and the trait nodes of the talents (TraitNodeEntry, TraitNodeXTraitNodeEntry,
TraitNode).

The spells read are those the other inputs name (coef.json, threat.json, gear.json, curation.json beside client_spells.json): every
rank, every carrier row, the spells of the rules and their tooltips, the crit talents, the equip spells of the threat items and enchants,
Rockbiter Weapon's imbues, the rows curation.json's durations read a duration from, and one level down every spell their effects
trigger. Each spell gets one uniform record, with the item a caster must wear for it (equip: the item class and subclass mask of CAP
Equipped or SpellEquippedItems, null for none); each talent its definition, node, tree, rank count and curve per effect (CAP TraitNodes
and TraitPoints). The IDs taken from the export are printed. Python 3, standard library only; the output is sorted, so a new capture
shows as a plain diff.
"""
import gzip
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'spelltips')
OUT = os.path.join(DATA, 'client_spells.json')


def load(name):
    with open(os.path.join(DATA, name), encoding='utf-8') as handle:
        return json.load(handle)


def num(x):
    """A client number as JSON keeps it: float32 noise rounded off, whole numbers as integers."""
    if x is None:
        return None
    if isinstance(x, bool):
        return int(x)
    if isinstance(x, float):
        x = round(x, 6)
        if x == int(x):
            return int(x)
    return x


def as_list(x):
    if x is None:
        return []
    if isinstance(x, list):
        return x
    return [x]


def wanted():
    """The spell IDs and talent spell IDs the other inputs name."""
    ids, talents = set(), set()
    coef, threat, gear, cur = load('coef.json'), load('threat.json'), load('gear.json'), load('curation.json')
    for e in coef['spells']:
        for r in e['ranks']:
            ids.add(r['id'])
            ids.update(int(v) for v in (r.get('rows') or {}).values())
    for e in threat['spells']:
        for r in e['ranks']:
            ids.add(r['id'])
    for r in threat['rules']:
        for k in ('spell', 'talent'):
            if r.get(k):
                ids.add(r[k])
        ids.update(as_list(r.get('tip')))
        if r.get('talent'):
            talents.add(r['talent'])
    for c in gear['crit']:
        ids.add(c['spell'])
        if c.get('talent'):
            talents.add(c['talent'])
    for t in cur['tips'].values():
        ids.update(as_list(t['tip']))
    for group in ('items', 'enchants'):
        for it in cur['threat_items'][group]:
            ids.add(it['spell'])
    ids.update(cur['rockbiter']['spells'])
    ids.update(d['row'] for k, d in cur['durations'].items() if k not in ('why', 'source'))
    return ids, talents


# The capture ---------------------------------------------------------------------------------------------------------------------

def read_capture(path):
    opener = gzip.open if path.endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8') as handle:
        return json.load(handle)


def cap_effect(e):
    flags = e.get('ClassFlags') or {}
    return {'i': e['Index'], 'type': e['Type'], 'aura': e['Aura'], 'bp': num(e['BasePoints']), 'var': num(e['Variance']),
            'ppl': num(e['PPL']), 'ppr': num(e['PointsPerResource']), 'period': num(e['PeriodMs']), 'sp': num(e['SPCoef']),
            'ap': num(e['APCoef']), 'trigger': e['TriggerID'], 'chain': e['ChainTargets'], 'amp': num(e['ChainAmp']),
            'misc': e['Misc'], 'misc2': e['Misc2'], 'family': flags.get('Family', 0), 'mask': list(flags.get('Mask') or [0, 0, 0, 0])}


def equip_of(item_class, subclass):
    """The item a caster must wear for a spell: [class, subclass mask], or None for none (a class below 0 or no row)."""
    if item_class is None or item_class < 0:
        return None
    return [item_class, subclass or 0]


def cap_spell(cap, sid, build):
    k = str(sid)
    misc = cap['Misc'].get(k)
    effects = cap['Effects'].get(k)
    if misc is None and effects is None:
        return None
    lv = cap['Levels'].get(k) or {}
    cat = cap['Categories'].get(k) or {}
    cls = cap['ClassOptions'].get(k) or {}
    misc = misc or {}
    attr = misc.get('Attr') or [0, 0]
    equip = cap['Equipped'].get(k) or {}
    return {'build': build, 'name': cap['Names'].get(k), 'rank': cap['Subtexts'].get(k), 'desc': cap['Descriptions'].get(k) or '',
            'level': lv.get('SpellLevel'), 'base': lv.get('BaseLevel'), 'max': lv.get('MaxLevel'),
            'cast': misc.get('CastTimeMs'), 'dur': misc.get('DurationMs'), 'school': misc.get('School'),
            'def': cat.get('DefenseType'), 'attr0': attr[0], 'attr1': attr[1] if len(attr) > 1 else 0,
            'equip': equip_of(equip.get('Class'), equip.get('Subclass')),
            'family': cls.get('Family', 0), 'mask': list(cls.get('Mask') or [0, 0, 0, 0]),
            'effects': sorted((cap_effect(e) for e in effects or []), key=lambda e: e['i'])}


# The export ----------------------------------------------------------------------------------------------------------------------

def one(db, sql, *args):
    row = db.execute(sql, args).fetchone()
    return row


def jlist(text, size):
    try:
        out = json.loads(text) if text else []
    except ValueError:
        out = []
    return (list(out) + [0] * size)[:size]


def db_spell(db, sid, build):
    name = one(db, 'SELECT Name_lang FROM SpellName WHERE ID = ?', sid)
    misc = one(db, 'SELECT Attributes, CastingTimeIndex, DurationIndex, SchoolMask FROM SpellMisc WHERE SpellID = ? AND DifficultyID = 0',
               sid)
    effects = db.execute('SELECT EffectIndex, Effect, EffectAura, EffectBasePointsF, Variance, EffectRealPointsPerLevel, '
                         'EffectPointsPerResource, EffectAuraPeriod, EffectBonusCoefficient, BonusCoefficientFromAP, '
                         'EffectTriggerSpell, EffectChainTargets, EffectChainAmplitude, EffectMiscValue, EffectSpellClassMask '
                         'FROM SpellEffect WHERE SpellID = ? AND DifficultyID = 0 ORDER BY EffectIndex', (sid,)).fetchall()
    if name is None and misc is None and not effects:
        return None
    text = one(db, 'SELECT NameSubtext_lang, Description_lang FROM Spell WHERE ID = ?', sid) or ('', '')
    lv = one(db, 'SELECT SpellLevel, BaseLevel, MaxLevel FROM SpellLevels WHERE SpellID = ? AND DifficultyID = 0', sid)
    cat = one(db, 'SELECT DefenseType FROM SpellCategories WHERE SpellID = ? AND DifficultyID = 0', sid)
    cls = one(db, 'SELECT SpellClassSet, SpellClassMask FROM SpellClassOptions WHERE SpellID = ?', sid)
    equip = one(db, 'SELECT EquippedItemClass, EquippedItemSubclass FROM SpellEquippedItems WHERE SpellID = ?', sid)
    attr = jlist(misc[0], 2) if misc else [0, 0]
    cast = dur = None
    if misc:
        row = one(db, 'SELECT Base FROM SpellCastTimes WHERE ID = ?', misc[1])
        cast = row[0] if row else 0
        row = one(db, 'SELECT Duration FROM SpellDuration WHERE ID = ?', misc[2])
        dur = row[0] if row else 0
    out = []
    for e in effects:
        misc_values = jlist(e[13], 2)
        out.append({'i': e[0], 'type': e[1], 'aura': e[2], 'bp': num(e[3]), 'var': num(e[4]), 'ppl': num(e[5]), 'ppr': num(e[6]),
                    'period': num(e[7]), 'sp': num(e[8]), 'ap': num(e[9]), 'trigger': e[10], 'chain': e[11], 'amp': num(e[12]),
                    'misc': misc_values[0], 'misc2': misc_values[1], 'family': 0, 'mask': jlist(e[14], 4)})
    return {'build': build, 'name': name[0] if name else None, 'rank': text[0] or None, 'desc': text[1] or '',
            'level': lv[0] if lv else None, 'base': lv[1] if lv else None, 'max': lv[2] if lv else None,
            'cast': cast, 'dur': dur, 'school': misc[3] if misc else None, 'def': cat[0] if cat else None,
            'attr0': attr[0], 'attr1': attr[1], 'equip': equip_of(*equip) if equip else None,
            'family': cls[0] if cls else 0, 'mask': jlist(cls[1], 4) if cls else [0, 0, 0, 0], 'effects': out}


def db_variables(db, sid):
    row = one(db, 'SELECT v.Variables FROM SpellXDescriptionVariables x JOIN SpellDescriptionVariables v '
                  'ON v.ID = x.SpellDescriptionVariablesID WHERE x.SpellID = ?', sid)
    return row[0].replace('\r\n', '\n').replace('\r', '\n') if row and row[0] else ''


def db_description(db, sid):
    row = one(db, 'SELECT Description_lang FROM Spell WHERE ID = ?', sid)
    return row[0] if row and row[0] else ''


def db_node(db, definition, tree):
    nodes = db.execute('SELECT x.TraitNodeID, n.TraitTreeID FROM TraitNodeEntry e JOIN TraitNodeXTraitNodeEntry x '
                       'ON x.TraitNodeEntryID = e.ID JOIN TraitNode n ON n.ID = x.TraitNodeID WHERE e.TraitDefinitionID = ?',
                       (definition,)).fetchall()
    live = sorted(n for n, t in nodes if t == tree)
    return live[0] if live else None


def db_build(db, path):
    """The build of the export: the Version of its _ExtractionMetadata table, else the 1.60.1.NNNNN of its file name."""
    try:
        row = one(db, "SELECT Value FROM _ExtractionMetadata WHERE Key = 'Version'")
    except sqlite3.Error:
        row = None
    if row and row[0] and re.match(r'^\d+\.\d+\.\d+\.\d+$', row[0]):
        return row[0]
    m = re.search(r'(\d+\.\d+\.\d+\.\d+)', os.path.basename(path))
    if m:
        return m.group(1)
    raise SystemExit('the build of the export %s is in neither its _ExtractionMetadata nor its file name' % path)


# The whole ------------------------------------------------------------------------------------------------------------------------

def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__.split('\n\n')[1])
    cap = read_capture(sys.argv[1])
    db = sqlite3.connect('file:%s?mode=ro' % sys.argv[2], uri=True)
    builds = sorted(set(cap['Builds'].values()))
    if len(builds) != 1:
        raise SystemExit('the capture holds several builds: %s' % builds)
    build = builds[0]
    # The spell rows' hotfix push: the largest of the class groups; the items group has a push of its own.
    hotfix = max(cap['Hotfixes'][k] for k in cap['Hotfixes'] if k != 'items')
    fallback = db_build(db, sys.argv[2])
    ids, talents = wanted()
    spells, fallen, missing = {}, [], []
    todo, seen = sorted(ids), set()
    depth = {sid: 0 for sid in ids}
    while todo:
        sid = todo.pop(0)
        if sid in seen:
            continue
        seen.add(sid)
        rec = cap_spell(cap, sid, build)
        if rec is None:
            rec = db_spell(db, sid, fallback)
            if rec is not None:
                fallen.append(sid)
        if rec is None:
            missing.append(sid)
            continue
        variables = db_variables(db, sid)
        rec['vars'] = variables
        rec['desc70888'] = db_description(db, sid) if variables and rec['build'] == build else ''
        spells[sid] = rec
        if depth[sid] < 1:
            for e in rec['effects']:
                t = e['trigger']
                if t and t not in depth:
                    depth[t] = depth[sid] + 1
                    todo.append(t)
    trait = {}
    by_spell = {}
    for node in cap['TraitNodes']:
        by_spell.setdefault(node['SpellID'], []).append(node)
    for sid in sorted(talents):
        found = by_spell.get(sid) or []
        if len(found) != 1:
            missing.append(sid)
            continue
        node = found[0]
        curve = {}
        for effect, points in sorted((cap['TraitPoints'].get(str(node['DefinitionID'])) or {}).items()):
            curve[effect] = [num(points[str(r)]) for r in range(1, node['MaxRanks'] + 1) if str(r) in points]
        trait[sid] = {'def': node['DefinitionID'], 'node': db_node(db, node['DefinitionID'], node['TreeID']), 'tree': node['TreeID'],
                      'ranks': node['MaxRanks'], 'class': node['Class'].upper(), 'curve': curve}
    out = {'about': 'The WoW: Forever client rows the spell data needs, read by tools/dev/spelltips_import.py: every row from the '
                    'capture of build %s (hotfix push %s) by wowsims/forever, and from GrunzForever\'s export of build %s only the rows '
                    'the capture lacks (build says which), the description variables (vars), the 70888 description of a spell with '
                    'variables (desc70888) and the trait nodes. Effects: i index, type, aura, bp base points (the mean), var variance, '
                    'ppl points a level, ppr points a combo point, period ms, sp and ap the bonus coefficients, trigger, chain targets '
                    'and amp amplitude, misc, misc2, and the class family and mask the effect modifies. equip: the item class and '
                    'subclass mask a caster must wear (null for none).' % (build, hotfix, fallback),
           'build': build, 'hotfix': hotfix, 'fallback': fallback,
           'spells': {str(k): spells[k] for k in sorted(spells)}, 'talents': {str(k): trait[k] for k in sorted(trait)}}
    with open(OUT, 'w', encoding='utf-8') as handle:
        handle.write('{\n')
        keys = [k for k in sorted(out) if k not in ('spells', 'talents')]
        for k in keys:
            handle.write(' %s: %s,\n' % (json.dumps(k), json.dumps(out[k], ensure_ascii=False)))
        for group in ('spells', 'talents'):
            handle.write(' %s: {\n' % json.dumps(group))
            items = list(out[group].items())
            for n, (k, v) in enumerate(items):
                handle.write('  %s: %s%s\n' % (json.dumps(k), json.dumps(v, ensure_ascii=False, sort_keys=True),
                                               ',' if n < len(items) - 1 else ''))
            handle.write(' }%s\n' % (',' if group == 'spells' else ''))
        handle.write('}\n')
    print('client_spells.json: %d spells (%d named by the inputs, %d triggered), %d talents; build %s, hotfix push %s' % (
        len(spells), len(ids & set(spells)), len(set(spells) - ids), len(trait), build, out['hotfix']))
    print('taken from the export (%s): %s' % (fallback, ', '.join(str(x) for x in sorted(fallen)) or 'none'))
    if missing:
        print('in neither input: %s' % ', '.join(str(x) for x in sorted(set(missing))))


if __name__ == '__main__':
    main()
