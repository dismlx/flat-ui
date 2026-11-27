#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import strip_lua
DATA = os.path.join(HERE, 'rotations', 'data.json')
ROOT = os.path.dirname(os.path.dirname(HERE))
SPELLDATA = os.path.join(ROOT, 'FlatUI', 'SpellData.lua')
OUT = os.path.join(ROOT, 'FlatUI', 'RotationData.lua')
CLASSES = ('WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID')

SPECS = {
    'warrior.arms': ('WARRIOR', 'arms', 'Arms warrior'),
    'warrior.fury': ('WARRIOR', 'fury', 'Fury warrior'),
    'warrior.protection': ('WARRIOR', 'protection', 'Protection warrior'),
    'paladin.protection': ('PALADIN', 'protection', 'Protection paladin'),
    'paladin.retribution': ('PALADIN', 'retribution', 'Retribution paladin'),
    'hunter.marksmanship': ('HUNTER', 'marksmanship', 'Marksmanship hunter'),
    'rogue.combat': ('ROGUE', 'combat', 'Combat rogue'),
    'priest.shadow': ('PRIEST', 'shadow', 'Shadow priest'),
    'shaman.elemental': ('SHAMAN', 'elemental', 'Elemental shaman'),
    'shaman.enhancement': ('SHAMAN', 'enhancement', 'Enhancement shaman'),
    'mage.fire': ('MAGE', 'fire', 'Fire mage'),
    'mage.frost': ('MAGE', 'frost', 'Frost mage'),
    'warlock.destruction': ('WARLOCK', 'destruction', 'Destruction warlock'),
    'druid.balance': ('DRUID', 'balance', 'Balance druid'),
    'druid.feral_cat': ('DRUID', 'cat', 'Feral druid in Cat Form'),
    'druid.feral_bear': ('DRUID', 'bear', 'Feral druid in Bear Form'),
}

PICKS = {
    'WARRIOR': {'trees': {1: 'arms', 2: 'fury', 3: 'protection'}, 'tank': 'protection'},
    'PALADIN': {'trees': {2: 'protection', 3: 'retribution'}, 'tank': 'protection'},
    'HUNTER': {'trees': {1: 'marksmanship', 2: 'marksmanship', 3: 'marksmanship'},
               'stand': {1: 'every hunter shoots the same Auto Shot, Multi-Shot and Serpent Sting; Aimed Shot is the one shot of a tree',
                         3: 'every hunter shoots the same Auto Shot, Multi-Shot and Serpent Sting; Aimed Shot is the one shot of a tree'}},
    'ROGUE': {'trees': {2: 'combat'}},
    'PRIEST': {'trees': {3: 'shadow'}},
    'SHAMAN': {'trees': {1: 'elemental', 2: 'enhancement'}},
    'MAGE': {'trees': {2: 'fire', 3: 'frost'}},
    'WARLOCK': {'trees': {2: 'destruction', 3: 'destruction'}, 'tied': {3: 'the run reads as tree 2, the first of a 21/21 tie'}},
    'DRUID': {'trees': {1: 'balance', 2: 'cat'}, 'tank': 'bear', 'forms': {1: 'cat', 5: 'bear', 8: 'bear'}},
}

ALIASES = {
    'main hand': 'attack', 'off hand': 'attack', 'extra attacks': 'attack',
    'seal of command (on-hit)': 'seal of command', 'seal of righteousness (on-hit)': 'seal of righteousness',
    'holy shield (block damage)': 'holy shield', 'windfury weapon (proc)': 'windfury weapon', 'searing totem (attack)': 'searing totem',
    'deadly poison v': 'deadly poison', 'instant poison vi': 'instant poison',
}

LEAVE = {
    'deep wounds': "a talent's bleed after a crit: no spell the player casts, and SpellData.lua has no entry",
    'ignite': "a talent's burn after a fire crit: no spell the player casts, and SpellData.lua has no entry",
    'dragonbreath chili': "a food's proc",
    'fireball (sulfuras proc)': "a weapon's proc",
    'blessing of sanctuary (block damage)': 'a blessing on the player, not a spell the comparison counts',
}

PROC_KINDS = ('proc', 'seal')


class Problems:
    def __init__(self):
        self.failed = []
        self.notes = []

    def fail(self, text):
        self.failed.append(text)

    def note(self, text):
        self.notes.append(text)


P = Problems()


def rnd(x, places=4):
    x = round(float(x), places)
    if x == int(x):
        return int(x)
    return x


def closing(text, at):
    depth = 0
    for i in range(at, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return i + 1
    raise ValueError('unbalanced braces at %d' % at)


def spell_entries():
    with open(SPELLDATA, encoding='utf-8') as handle:
        text = handle.read()
    out = {}
    for m in re.finditer(r'^D\.CLASS\.(\w+) = function\(\)\n', text, re.M):
        cls = m.group(1)
        end = text.index('\nend\n', m.end())
        body = text[m.end():end]
        found = {}
        for e in re.finditer(r'\{ key = "([^"]+)"', body):
            stop = closing(body, e.start())
            chunk = body[e.start():stop]
            head = chunk.split('\n', 1)[0]
            ids = set()
            r = chunk.find('ranks = {')
            if r >= 0:
                start = r + len('ranks = ')
                ranks = chunk[start:closing(chunk, start)]
                ids = {int(x) for x in re.findall(r'\{ (\d+), \d+', ranks)}
            cmp = re.search(r'cmp = "(\w+)"', head)
            found[e.group(1)] = {'ids': ids, 'cmp': cmp.group(1) if cmp else None, 'nx': 'nx = true' in head}
        out[cls] = found
    return out


def spell_id(action):
    m = re.match(r'^spell:(\d+)', action)
    return int(m.group(1)) if m else None


def match(name, row, own, every):
    for action in row['ids']:
        sid = spell_id(action)
        if sid is None:
            continue
        for entries in (own, every):
            for key, e in entries.items():
                if sid in e['ids']:
                    return key
    low = name.lower()
    if low in ALIASES:
        return ALIASES[low]
    if low in own or low in every:
        return low
    return None


def most_points(talents):
    sums = [sum(int(c) for c in part) for part in talents.split('-')]
    best, most = None, 0
    for place, points in enumerate(sums, 1):
        if points > most:
            best, most = place, points
    return best, sums


def build_spec(run_key, run, cls, entries):
    own, every = entries.get(cls, {}), entries.get('ALL', {})
    grouped, left = {}, []
    for name, row in run['abilities'].items():
        if row.get('resource') or name.endswith('(queue)'):
            continue
        if all(a.startswith('item:') for a in row['ids']):
            left.append((name, row, 'an item'))
            continue
        key = match(name, row, own, every)
        if key is None:
            left.append((name, row, None))
            continue
        grouped.setdefault(key, []).append((name, row))
    abilities = {}
    for key, rows in sorted(grouped.items()):
        entry = own.get(key) or every.get(key)
        if entry is None:
            P.fail('%s: %s is no entry of %s' % (run_key, key, cls))
            continue
        d = sum(r['damageShare'] or 0 for _, r in rows)
        threats = [r['threatShare'] for _, r in rows if r['threatShare'] is not None]
        procs = [r for _, r in rows if r.get('triggered') or r.get('hitsPerMinute') is not None]
        casts = [r for _, r in rows if not (r.get('triggered') or r.get('hitsPerMinute') is not None)]
        proc = False
        if key == 'attack':
            m = sum(r['casts'] for _, r in rows)
        elif entry['cmp'] in PROC_KINDS and procs:
            m, proc = sum(r['hitsPerMinute'] or 0 for r in procs), True
        elif casts:
            m = sum(r['casts'] for r in casts)
        else:
            m, proc = sum(r['hitsPerMinute'] or 0 for r in procs), True
        one = {'m': rnd(m, 3), 'd': rnd(d)}
        if threats:
            one['t'] = rnd(sum(threats))
        if proc:
            one['p'] = True
        abilities[key] = one
        if not 0 <= d <= 1 or any(not 0 <= t <= 1 for t in threats) or m < 0:
            P.fail('%s %s: a share or a use a minute out of range (d %s, m %s)' % (run_key, key, d, m))
        names = ', '.join(n for n, _ in rows)
        if len(rows) > 1:
            P.note('%s: %s are one entry, %s (uses a minute: %s)' % (run_key, names, key, 'the hits' if proc else 'the casts'))
    for name, row, why in left:
        big = (row['damageShare'] or 0) >= 0.01 or (row['threatShare'] or 0) >= 0.01
        if big and why is None and name.lower() not in LEAVE:
            P.fail('%s: %s deals %.1f%% and is no entry; name it in ALIASES or LEAVE' % (run_key, name, 100 * (row['damageShare'] or 0)))
    total = sum(r['damageShare'] or 0 for n, r in run['abilities'].items())
    if abs(total - 1) > 0.02:
        P.fail('%s: the damage shares sum to %.3f' % (run_key, total))
    sw = run.get('swings') or {}
    swings = {}
    for field, name in (('mh', 'mainHand'), ('oh', 'offHand'), ('extra', 'extraAttacks')):
        x = (sw.get(name) or {}).get('perMinute')
        if x:
            swings[field] = rnd(x, 3)
    timer = sw.get('mainHandSwingTimerTotal')
    replaced = sw.get('replacedByNextSwingStrikes') or {}
    if timer:
        swings['timer'] = rnd(timer, 3)
    nxt = {}
    for name, per in sorted(replaced.items()):
        key = match(name, {'ids': []}, own, every)
        entry = key and (own.get(key) or every.get(key))
        if not entry or not entry['nx']:
            P.fail('%s: %s replaces swings but is no next-swing entry' % (run_key, name))
            continue
        share = per / timer if timer else 0
        if not 0 < share <= 1:
            P.fail('%s: %s takes a share %s of the swings' % (run_key, name, share))
            continue
        nxt[key] = rnd(share)
    if nxt:
        swings['next'] = nxt
    return abilities, swings, [n for n, _, _ in left]


def build(data, entries):
    specs = data['specs']
    classes = {}
    used = {}
    for run_key, (cls, spec, label) in sorted(SPECS.items()):
        run = specs.get(run_key)
        if run is None:
            P.fail('%s is not in data.json' % run_key)
            continue
        if cls not in entries:
            P.fail('%s: SpellData.lua has no class %s' % (run_key, cls))
            continue
        abilities, swings, left = build_spec(run_key, run, cls, entries)
        if not abilities:
            P.fail('%s: no ability is an entry' % run_key)
        one = {'label': label, 'from': run_key, 'dps': rnd(run['dps'], 1)}
        if run.get('tps') is not None:
            one['tps'] = rnd(run['tps'], 1)
        one['abilities'] = abilities
        one['swings'] = swings
        classes.setdefault(cls, {'specs': {}})['specs'][spec] = one
        used[(cls, spec)] = run
        if left:
            P.note('%s: left out (no entry or an item): %s' % (run_key, ', '.join(left)))
    for cls, pick in sorted(PICKS.items()):
        if cls not in CLASSES:
            P.fail('PICKS: %s is no class' % cls)
            continue
        out = classes.setdefault(cls, {'specs': {}})
        named = list(pick['trees'].values()) + [pick.get('tank')] + list((pick.get('forms') or {}).values())
        for spec in named:
            if spec is not None and (cls, spec) not in used:
                P.fail('PICKS %s names %s, which has no run' % (cls, spec))
        for place, spec in sorted(pick['trees'].items()):
            run = used.get((cls, spec))
            if not run or place in (pick.get('stand') or {}):
                continue
            best, sums = most_points(run['run']['talents'])
            if best != place and place not in (pick.get('tied') or {}):
                P.fail('PICKS %s: tree %d is %s, whose talents %s read as tree %s' % (cls, place, spec, sums, best))
            elif best != place:
                P.note('PICKS %s: tree %d is %s, whose talents %s read as tree %s (%s)' % (cls, place, spec, sums, best,
                                                                                       pick['tied'][place]))
        out['trees'] = dict(pick['trees'])
        if pick.get('stand'):
            out['stand'] = {k: True for k in pick['stand']}
        if pick.get('tank'):
            out['tank'] = pick['tank']
        if pick.get('forms'):
            out['forms'] = dict(pick['forms'])
    for alias, key in sorted(ALIASES.items()):
        if not any(key in entries.get(c, {}) for c in list(CLASSES) + ['ALL']):
            P.fail('ALIASES: %s names %s, no entry' % (alias, key))
    return classes


LUA_WORDS = {'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
             'return', 'then', 'true', 'until', 'while'}


def lua(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(v, dict):
        return '{ ' + ', '.join(field(k, x) for k, x in v.items()) + ' }' if v else '{}'
    raise TypeError(v)


def field(k, v):
    if isinstance(k, int):
        return '[%d] = %s' % (k, lua(v))
    if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', k) and k not in LUA_WORDS:
        return '%s = %s' % (k, lua(v))
    return '[%s] = %s' % (lua(k), lua(v))


HEAD = """Generated by tools/dev/make_rotations.py from tools/dev/rotations/data.json. Do not edit by hand: change the input or the \
generator's tables and run it again; make_rotations.py --check says whether this file is what the input makes.

What the WoWSims Classic simulator (https://github.com/wowsims/classic, commit %(commit)s, MIT licence, Copyright (c) 2024 wowsims team) \
does with each spec's own defaults (gear, talents, rotation, consumables and buffs of its presets) in a fight of %(fight)d seconds against a \
level 63 boss with 3731 armor, %(iterations)d iterations; the bear's run is from https://github.com/wowsims/sod (commit %(sod)s, the same \
licence), with no runes and Classic Era items, as the Classic sim has no bear. Classic Era is level 60 with vanilla talents and ranks, as \
WoW: Forever's content. Only these numbers are taken, none of WoWSims' code; each run's own changes from its presets are in \
tools/dev/rotations/data.json (run.deviations), and the licences beside it.

GearModel.lua's Minute counts each chosen spell of the Overall line as often as its class's run uses it a minute (m), and a next-swing \
strike on the share of the main hand's swings its run gives it (swings.next). R.CLASS[class] = { trees, stand, tank, forms, specs }: trees \
the spec of the talent tree with the most points (Core.lua's ns.PlayerTree), stand the trees with no run of their own that take another's, \
tank the spec of a tank, forms the spec of a druid form (GetShapeshiftFormID), specs[spec] = { label, from, dps, tps, abilities, swings }. \
abilities[key] (a SpellData.lua entry's key) = { m, d, t, p }: m uses a minute (casts; with p a proc's hits), d its share of the damage and \
t of the threat (tanks). swings = { mh, oh, extra, timer, next }: white swings a minute of the main hand and the off hand and extra \
attacks, timer the main hand's swings a minute with those a next-swing strike took, next[key] the share of them that strike took."""

WIDTH = 150


def comment(text, indent=''):
    out = []
    for para in text.split('\n\n'):
        width = WIDTH - 4 * len(indent) - 3
        out.extend(indent + '-- ' + line for line in textwrap.wrap(para, width, break_long_words=False, break_on_hyphens=False))
        out.append(indent + '--')
    return '\n'.join(out[:-1]) + '\n'


def write_lua(data, classes):
    src = data['source']
    settings = src.get('settings') or {}
    head = HEAD % {'commit': src['commit'], 'sod': src['secondaryRepo']['commit'], 'fight': settings['fightLengthSeconds'],
                   'iterations': settings['iterations']}
    text = ['local _, ns = ...\n\n', comment(head), '\nlocal R = {}\nns.RotationData = R\n\n',
            'R.SOURCE, R.LINK, R.FIGHT = "WoWSims Classic", "https://github.com/wowsims/classic", %d\n' % settings['fightLengthSeconds']]
    text.append('R.CLASS = {\n')
    for cls in CLASSES:
        if cls not in classes:
            continue
        c = classes[cls]
        text.append('\t%s = {\n' % cls)
        for name in ('trees', 'stand', 'tank', 'forms'):
            if name in c:
                text.append('\t\t%s,\n' % field(name, c[name]))
        text.append('\t\tspecs = {\n')
        for spec in sorted(c['specs']):
            s = c['specs'][spec]
            run = data['specs'][s['from']]['run']
            _, sums = most_points(run['talents'])
            sums = (sums + [0, 0, 0])[:3]
            text.append(comment('%s: %s; %s; talents %s (%s)%s.' % (
                s['from'], run['gear'], run['apl'], '/'.join(str(x) for x in sums), run['talentsLabel'],
                '; changed: ' + '; '.join(run['deviations']) if run['deviations'] else ''), '\t\t\t'))
            top = {k: s[k] for k in ('label', 'from', 'dps', 'tps') if k in s}
            text.append('\t\t\t%s = { %s,\n' % (spec, ', '.join(field(k, v) for k, v in top.items())))
            text.append('\t\t\t\tabilities = {\n')
            for key in sorted(s['abilities']):
                text.append('\t\t\t\t\t%s,\n' % field(key, s['abilities'][key]))
            text.append('\t\t\t\t},\n')
            text.append('\t\t\t\t%s },\n' % field('swings', s['swings']))
        text.append('\t\t},\n')
        text.append('\t},\n')
    text.append('}\n')
    return ''.join(text)


def run_checks(path):
    status = 0
    if shutil.which('luac5.4'):
        r = subprocess.run(['luac5.4', '-p', path], capture_output=True, text=True)
        print('luac5.4 -p: %s' % ('clean' if r.returncode == 0 else r.stderr.strip()))
        status |= r.returncode
    check = os.path.join(HERE, 'lua51_check.py')
    if os.path.exists(check):
        r = subprocess.run([sys.executable, check, path], capture_output=True, text=True)
        print('lua51_check.py: %s' % ('clean' if r.returncode == 0 else r.stdout.strip()))
        status |= r.returncode
    return status


def main():
    check_only = '--check' in sys.argv[1:]
    with open(DATA, encoding='utf-8') as handle:
        data = json.load(handle)
    entries = spell_entries()
    for cls in CLASSES + ('ALL',):
        if not entries.get(cls):
            P.fail('SpellData.lua: no entries for %s' % cls)
    classes = build(data, entries)
    text = strip_lua.strip(write_lua(data, classes))
    for cls in CLASSES:
        c = classes.get(cls) or {}
        print('%s: %s' % (cls, ', '.join('%s (%d abilities%s)' % (
            spec, len(s['abilities']), ', next swing: ' + ', '.join('%s %.0f%%' % (k, 100 * v) for k, v in sorted(s['swings']['next'].items()))
            if s['swings'].get('next') else '') for spec, s in sorted(c.get('specs', {}).items())) or 'none'))
    print('RotationData.lua: %d runs, %d bytes' % (sum(len(c['specs']) for c in classes.values()), len(text.encode('utf-8'))))
    for n in P.notes:
        print('note: ' + n)
    for f in P.failed:
        print('FAILED: ' + f)
    if P.failed:
        print('%d checks failed; nothing written.' % len(P.failed))
        return 1
    if check_only:
        try:
            with open(OUT, encoding='utf-8') as handle:
                same = handle.read() == text
        except OSError:
            same = False
        print('--check: every check passed; %s; nothing written.' % (
            'FlatUI/RotationData.lua is what the input makes' if same else 'FlatUI/RotationData.lua is NOT what the input makes'))
        return 0 if same else 1
    with open(OUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(text)
    print('wrote %s' % os.path.relpath(OUT, ROOT))
    return 1 if run_checks(OUT) else 0


if __name__ == '__main__':
    sys.exit(main())
