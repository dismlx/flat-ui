#!/usr/bin/env python3
"""Makes FlatUI/SpellData.lua, the spell data of the spell lines and the gear comparison (design 3).

Usage: python3 tools/dev/make_spelltips.py [--check]

Inputs, all in tools/dev/spelltips: coef.json (the shares of every spell, with the client effect that carries each part), threat.json
(threat of the spells with a rule of their own, and the threat rules), gear.json (the model's constants, the crit damage talents and
the item stat keys), curation.json (the hand-kept decisions, each with its reason) and client_spells.json (the client rows, made by
tools/dev/spelltips_import.py). Every value a client row holds is read from client_spells.json: base points, points a level and a combo
point, ticks and their period, the weapon percent, cast time, duration, levels, school, DefenseType, attributes, a coefficient the row
stores, a threat value, a talent's curve, a rule's multiplier. The slices give each part's kind, stat, basis and notes, and the values no
row holds (server rules and measured shares). Where a slice's value differs from the row, the row wins unless curation.json's
known_differences names it with a reason.

It prints the counts and the file's size, the spells left out of the comparison, the parts the text scan marked as counted by the game's
text, the probes per class, and every value of the slices that differs from its row with whether known_differences explains it.
--check writes nothing and exits 1 on a failed check; without it the file is written only when every check passes, and then luac5.4 -p
and tools/dev/lua51_check.py run on it when they are there. The checks: every rank ID once and every key once; every default resolves and
is a key, a list of keys or { needs, keys, else } (the one form GearLines.lua reads); each judgement's seal is an entry of its class with
as many ranks; a threat list has one value per rank; coefficients between 0 and 5; every basis c, m or e; every talent of the rules and
crit talents has a curve as long as its ranks, a node and a definition the capture's TraitNodes holds; every value a row holds equals the
slice's or is in known_differences; every field written is one the shapes of design 3.2 and its stub (3.2a) use, or an entry's seal, and
every field and comparison kind of the stub is written; every class with spell power has a probe; a description whose variables come from
build 70888 reads the same in 70938, else it says so. Python 3, standard library only; deterministic, so a diff shows real changes.
"""
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'spelltips')
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'FlatUI', 'SpellData.lua')
CLASSES = ('WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID')
SPELL_POWER_CLASSES = ('MAGE', 'WARLOCK', 'PRIEST', 'DRUID', 'SHAMAN', 'PALADIN')
CLASS_FAMILY = {'MAGE': 3, 'WARRIOR': 4, 'WARLOCK': 5, 'PRIEST': 6, 'DRUID': 7, 'ROGUE': 8, 'HUNTER': 9, 'PALADIN': 10, 'SHAMAN': 11}
SCHOOL_INDEX = {1: 1, 2: 2, 4: 3, 8: 4, 16: 5, 32: 6, 64: 7}
ROLL = {1: 'spell', 2: 'special', 3: 'ranged'}
CMP_KINDS = ('spell', 'dot', 'channel', 'heal', 'hot', 'strike', 'apstrike', 'finisher', 'auto', 'shot', 'wand', 'seal', 'proc', 'threat')
# The kinds of an item stat key (D.STATS): those GearModel.lua's spell model counts, none and note, and avoid (a rating index: 2 defense, 3 dodge,
# 4 parry, 5 block, Camelot/PaperDollFrame.lua:5-8) and armor, which only GearAvoid.lua counts; GearModel.lua passes over a kind it does not know.
STAT_KINDS = ('stat', 'school', 'rating', 'skill', 'vs', 'note', 'none', 'ap', 'rap', 'sp', 'spd', 'heal', 'wdmg', 'bv', 'dps', 'avoid', 'armor')
AVOID_RATINGS = (2, 3, 4, 5)

# The fields the shapes may hold: those of design 3.2, and of its stub (3.2a), which uses a part of them, and an entry's seal (a judgement's,
# whose rank SpellModel.lua's M.Highest gives the judgement), which the join of the parts added. Every field written must be one of these;
# the second set is reported, so a field the other parts may not read yet is seen. An entry's rule of 3.2 is not written: a rule names the
# spells of its tooltip itself (tip).
FIELDS = {
    'entry': {'key', 'pet', 'school', 'sch', 'cmp', 'roll', 'nb', 'nx', 'seal', 'parts', 'ranks', 'threat'},
    'part': {1, 2, 'n', 'p', 'per', 'max', 'j', 'cp', 'spd', 'h', 'sch', 'g', 'fs', 'o', 'two', 'note', 'b'},
    'rank': {1, 2, 'c', 'n', 'w', 'ct', 'du', 'bm', 'bl', 'lv', 'mx', 'cpb', 'sv'},
    'threat': {'k', 'v', 'b', 'ap', 'apb', 'pl', 'mx', 'split', 'forms', 'note'},
    'rule': {'id', 'class', 'form', 'm', 'b', 'name', 'tip', 'note', 'say', 'lowers', 'talent', 'node', 'def', 'r', 'shield', 'aura',
             'holy', 'holyB', 'twoHand', 'spells', 'always', 'schools', 'rockbiter', 'enchant', 'slot', 'item'},
    'crit': {'talent', 'node', 'def', 'r', 'spells', 'aura'},
}
STUB_FIELDS = {
    'entry': {'key', 'school', 'cmp', 'roll', 'nb', 'nx', 'parts', 'ranks', 'threat'},
    'part': {1, 2, 'spd', 'h', 'b', 'n', 'p', 'per', 'g', 'fs', 'o', 'two', 'note'},
    'rank': {1, 2, 'c', 'ct', 'du', 'bm', 'bl', 'mx', 'lv', 'cpb', 'sv'},
    'threat': {'k', 'v', 'b', 'split', 'ap', 'apb'},
    'rule': {'id', 'class', 'form', 'm', 'b', 'name', 'tip', 'note', 'say', 'lowers', 'talent', 'node', 'def', 'r', 'shield', 'aura',
             'holy', 'holyB', 'always'},
    'crit': {'talent', 'node', 'def', 'r', 'spells'},
}
# The stat tokens of the client's spell texts: which part stat each one counts.
TOKENS = {'apm': 'ap', 'ap': 'ap', 'AP': 'ap', 'RAP': 'rap', 'rap': 'rap', 'bh': 'heal', 'SP': 'sp', 'SPH': 'sp', 'SPFR': 'sp',
          'SPFI': 'sp', 'SPN': 'sp', 'SPS': 'sp', 'SPA': 'sp', 'SPI': 'spirit'}
TOKEN = re.compile(r'\$(apm|ap|AP|RAP|rap|bh|SPFR|SPFI|SPH|SPN|SPS|SPA|SPI|SP)(?![A-Za-z0-9])')
AURA_TYPES = {6, 27, 35, 65, 119, 128, 129, 143, 174}


class Problems:
    def __init__(self):
        self.failed = []
        self.notes = []
        self.explained = {}

    def fail(self, text):
        self.failed.append(text)

    def note(self, text):
        self.notes.append(text)


P = Problems()


def load(name):
    with open(os.path.join(DATA, name), encoding='utf-8') as handle:
        return json.load(handle)


def near(a, b, tol=1e-4):
    if a is None or b is None:
        return a is b
    return abs(a - b) <= tol * max(1.0, abs(a), abs(b))


def rnd(x, places=4):
    if x is None:
        return None
    x = round(float(x), places)
    if x == int(x):
        return int(x)
    return x


# The client rows ------------------------------------------------------------------------------------------------------------------

class Client:
    def __init__(self, data):
        self.data = data
        self.spells = {int(k): v for k, v in data['spells'].items()}
        self.talents = {int(k): v for k, v in data['talents'].items()}

    def row(self, sid):
        return self.spells.get(int(sid))

    def trigger(self, row, nth):
        found = [e['trigger'] for e in row['effects'] if e['trigger']]
        return found[nth] if len(found) > nth else None


def matches(find, e):
    t, a = e['type'], e['aura']
    if find == 'damage':
        return t in (2, 9)
    if find == 'heal':
        return t in (10, 67)
    if find == 'pdamage':
        return t in AURA_TYPES and a in (3, 53, 89)
    if find == 'pheal':
        return t in AURA_TYPES and a == 8
    if find == 'absorb':
        return t in AURA_TYPES and a in (69, 97)
    if find == 'shield':
        return t in AURA_TYPES and a in (15, 43)
    if find == 'weapon':
        return t in (17, 58, 121, 31)
    if find == 'dummy':
        return t == 3 or (t in AURA_TYPES and a == 4)
    if find == 'burn':
        return t == 62
    if find == 'threat':
        return t == 63 or (t in AURA_TYPES and a == 103)
    raise SystemExit('unknown find %s' % find)


def periodic_aura(row):
    """The period of the periodic aura of a rank row (a channel's or ground effect's pulse)."""
    for e in row['effects']:
        if e['type'] in AURA_TYPES and e['aura'] in (3, 8, 23, 53, 64, 226) and e['period']:
            return e['period']
    return None


def channel(row):
    return bool(row['attr1'] & 0x44)


# Entries --------------------------------------------------------------------------------------------------------------------------

class Entry:
    def __init__(self, key, cls):
        self.key = key
        self.cls = cls
        self.pet = False
        self.school = None
        self.school_override = None
        self.sch = None
        self.cmp = None
        self.roll = None
        self.nb = False
        self.nx = False
        self.seal = None
        self.parts = []
        self.ranks = []
        self.threat = None
        self.base_ok = True


def resolve(client, rank, part, index):
    """The row and effect that carry a part on a rank, and the ticks of a periodic part."""
    rid = rank['id']
    rank_row = client.row(rid)
    if rank_row is None:
        return None, None, None, 'no row for %d' % rid
    carrier = (rank.get('rows') or {}).get(str(index))
    if carrier:
        row = client.row(carrier)
        if row is None:
            return None, None, None, 'no row for carrier %s' % carrier
        row_id = int(carrier)
    elif part.get('carrier') in ('trigger', 'trigger2'):
        t = client.trigger(rank_row, 0 if part['carrier'] == 'trigger' else 1)
        row = client.row(t) if t else None
        if row is None:
            return None, None, None, 'no %s of %d' % (part['carrier'], rid)
        row_id = t
    else:
        row, row_id = rank_row, rid
    if part['find'] == 'none':
        return row_id, None, None, None
    found = [e for e in row['effects'] if matches(part['find'], e)]
    if part['find'] == 'weapon':
        main = [e for e in found if e['type'] != 31]
        found = main or found
    nth = part.get('nth', 0)
    if len(found) <= nth:
        return row_id, None, None, 'no %s effect on %d' % (part['find'], row_id)
    effect = found[nth]
    ticks = part.get('ticks')
    n = None
    if ticks == 'row':
        if effect['period'] and row['dur'] and row['dur'] > 0:
            n = int(round(row['dur'] / effect['period']))
        else:
            return row_id, effect, None, 'no ticks on %d' % row_id
    elif ticks == 'rank':
        period = periodic_aura(rank_row)
        if period and rank_row['dur'] and rank_row['dur'] > 0:
            n = int(round(rank_row['dur'] / period))
        else:
            return row_id, effect, None, 'no pulse on %d' % rid
    elif isinstance(ticks, (int, float)):
        n = int(ticks)
    return row_id, effect, n, None


def weapon_percent(row):
    for e in row['effects']:
        if e['type'] == 31:
            return e['bp'] / 100.0
    return 1.0


def period_of(client, rank, part, effect):
    if effect is not None and effect['period']:
        return effect['period'] / 1000.0
    if part.get('ticks') == 'rank':
        p = periodic_aura(client.row(rank['id']))
        return p / 1000.0 if p else None
    return part.get('p')


def build_entries(client, coef, cur):
    entries, order = {}, []
    known = cur['known_differences']
    for ce in coef['spells']:
        key = ce['key']
        e = Entry(key, ce['class'])
        diffs = known.get(key)
        for i, sp in enumerate(ce['parts']):
            e.parts.append({'stat': sp['stat'], 'slice': sp, 'b': sp['basis']})
        for rank in ce['ranks']:
            row = client.row(rank['id'])
            if row is None:
                P.fail('%s: no client row for rank %d' % (key, rank['id']))
                continue
            level = row['level'] or cur['levels']['keys'].get(key)
            if not level:
                P.fail('%s: rank %d has no level row and no level in curation' % (key, rank['id']))
            if rank.get('level') is not None and row['level'] is not None and rank['level'] != row['level']:
                P.note('%s: rank %d is learned at %d on Forever (the research had %s)' % (key, rank['id'], row['level'], rank['level']))
            out = {'id': rank['id'], 'level': level or 1, 'row': row, 'parts': [], 'index': len(e.ranks)}
            used = set()
            for i, sp in enumerate(ce['parts']):
                row_id, effect, n, why = resolve(client, rank, sp, i)
                info = {'row_id': row_id, 'effect': effect, 'n': n}
                if why:
                    P.fail('%s: rank %d part %d: %s' % (key, rank['id'], i + 1, why))
                    e.base_ok = False
                info['p'] = period_of(client, rank, sp, effect) if n is not None else None
                prow = client.row(row_id) if row_id else None
                info['prow'] = prow
                shared = effect is not None and (row_id, effect['i']) in used
                if effect is not None:
                    used.add((row_id, effect['i']))
                info['shared'] = shared
                out['parts'].append(info)
            e.ranks.append(out)
        # The shipped values and the check of every row-held value against the slice.
        for i, sp in enumerate(ce['parts']):
            for r, rank in zip(e.ranks, ce['ranks']):
                info = r['parts'][i]
                eff, prow = info['effect'], info['prow']
                slice_c = (rank.get('c') or [None] * len(ce['parts']))[i] if rank.get('c') else None
                slice_c = sp['coef'] if slice_c is None else slice_c
                slice_n = (rank.get('n') or [None] * len(ce['parts']))[i] if rank.get('n') else None
                slice_n = sp.get('n') if slice_n is None else slice_n
                info['c'] = value_of(key, i, sp, r, info, slice_c, diffs)
                if slice_n is not None and info['n'] is not None and slice_n != info['n']:
                    P.fail('%s: rank %d part %d: %d ticks in the row, %d in the slice' % (key, r['id'], i + 1, info['n'], slice_n))
                if eff is not None and sp.get('j') is not None and not near(eff['amp'], sp['j']):
                    P.fail('%s: part %d: chain amplitude %s in the row, %s in the slice' % (key, i + 1, eff['amp'], sp['j']))
                for field, rowfield in (('bp', 'bp'), ('ppl', 'ppl')):
                    want = (rank.get(field) or [None] * len(ce['parts']))[i] if rank.get(field) else None
                    if want is not None and eff is not None and not near(eff[rowfield], want, 1e-3):
                        P.fail('%s: rank %d part %d: %s %s in the row, %s in the slice' % (key, r['id'], i + 1, field, eff[rowfield],
                                                                                        want))
                if rank.get('def') is not None and i == 0 and (r['row']['def'] or 0) != rank['def']:
                    P.fail('%s: rank %d: DefenseType %s in the row, %s in the slice' % (key, r['id'], r['row']['def'], rank['def']))
        entries[key] = e
        order.append((ce, e))
    return entries, order


def value_of(key, i, sp, r, info, slice_c, diffs):
    """The share a part ships on a rank: the row's where the row holds one, else the slice's; known_differences keeps the slice's.

    A row holds the coefficient of a spell power or healing part on a spell that is not Physical (EffectBonusCoefficient, times the
    ticks of a periodic part), the attack power share where BonusCoefficientFromAP is set, and the weapon multiple of a weapon part
    (effect 31, else 1). Every other share is the slice's: a measured or estimated value no row holds."""
    eff, n, prow = info['effect'], info['n'], info['prow']
    stat = sp['stat']
    known = diffs if diffs and diffs.get('part') == i else None
    row_c, what = None, 'coefficient'
    if stat in ('sp', 'heal') and eff is not None and prow is not None and prow['school'] != 1:
        row_c = eff['sp'] * (n or 1)
    elif stat in ('ap', 'rap') and eff is not None and eff['ap']:
        row_c, what = eff['ap'] * (n or 1), 'attack power share'
    elif stat == 'wpn' and eff is not None and prow is not None:
        row_c, what = weapon_percent(prow), 'weapon multiple'
    if row_c is None:
        if known is not None:
            P.fail('%s part %d: known_differences names a value no row holds' % (key, i + 1))
        if stat in ('ap', 'rap') and sp.get('tick') is not None and n is not None:
            return sp['tick'] * n
        return slice_c
    if near(row_c, slice_c):
        return row_c
    if known is not None:
        want = known_value(known, r)
        if not near(want, slice_c):
            P.fail('%s rank %d part %d: known_differences gives %s, the slice %s' % (key, r['id'], i + 1, want, slice_c))
        x = P.explained.setdefault((key, i), {'what': what, 'row': set(), 'shipped': set(), 'ranks': 0, 'why': known['why']})
        x['row'].add(rnd(row_c))
        x['shipped'].add(rnd(want))
        x['ranks'] += 1
        return want
    P.fail('differs, not explained: %s rank %d part %d: %s %s in the row, %s in the slice' % (
        key, r['id'], i + 1, what, rnd(row_c), rnd(slice_c)))
    return row_c


def known_value(known, r):
    c = known['c']
    return c[r['index']] if isinstance(c, list) else c


# Text scan, notes, comparison kinds ---------------------------------------------------------------------------------------------

def variables(row):
    out = {}
    for line in (row.get('vars') or '').split('\n'):
        m = re.match(r'\s*\$(\w+)\s*=\s*(.*)$', line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def expanded(row):
    """A rank's description with its $<name> variables written out, to any depth."""
    text = row.get('desc') or ''
    names = variables(row)
    for _ in range(12):
        new = re.sub(r'\$<(\w+)>', lambda m: '(' + names.get(m.group(1), '') + ')', text)
        if new == text:
            break
        text = new
    return text


def text_stats(row):
    return {TOKENS[m.group(1)] for m in TOKEN.finditer(expanded(row))}


def scan_texts(order, client):
    marked = []
    for ce, e in order:
        stats_by_rank = [text_stats(r['row']) for r in e.ranks]
        top = stats_by_rank[-1] if stats_by_rank else set()
        for i, part in enumerate(e.parts):
            if part['stat'] in top:
                part['g'] = True
                marked.append('%s part %d (%s)' % (e.key, i + 1, part['stat']))
                lower = [r['id'] for r, s in zip(e.ranks, stats_by_rank) if part['stat'] not in s]
                if lower:
                    P.note('text scan: %s part %d: the texts of ranks %s do not read the stat' % (e.key, i + 1, lower))
        for r in e.ranks:
            row = r['row']
            if row.get('vars') and row['build'] == client.data['build']:
                if row.get('desc70888') and row['desc70888'].replace('\r\n', '\n') != row['desc'].replace('\r\n', '\n'):
                    P.note('text: %s rank %d: its variables come from 70888 and its description differs in 70938' % (e.key, r['id']))
    return marked


def apply_curation(entries, cur):
    for key, t in cur['texts'].items():
        e = need(entries, key, 'texts')
        part = e.parts[t['part']]
        if 'o' in t:
            part.pop('g', None)
            part['o'] = True
            part['two'] = t['two']
        if 'fs' in t:
            part['fs'] = t['fs']
            part['g'] = True
    for key, n in cur['notes'].items():
        e = need(entries, key, 'notes')
        part = e.parts[n['part']]
        for f in ('note', 'per', 'max'):
            if f in n:
                part[f] = n[f]
    for key, s in cur['schools'].items():
        e = need(entries, key, 'schools')
        if 'sch' in s:
            e.sch = s['sch']
            for part in e.parts:
                if part['stat'] == 'sp':
                    part['sch'] = s['sch']
        if 'school' in s:
            e.school_override = s['school']
    for key in cur['nb']['keys']:
        need(entries, key, 'nb').nb = True


def apply_judgements(entries, cur):
    """Each judgement names its seal (curation judgements): the two of a class, with as many ranks, so the judgement's rank of a place is the
    seal's rank of that place."""
    for key, j in cur['judgements'].items():
        if key == 'about':
            continue
        judgement, seal = need(entries, key, 'judgements'), need(entries, j['seal'], 'judgements')
        if judgement.cls != seal.cls:
            P.fail('judgements: %s is %s, its seal %s %s' % (key, judgement.cls, j['seal'], seal.cls))
        elif len(judgement.ranks) != len(seal.ranks):
            P.fail('judgements: %s has %d ranks, its seal %s %d' % (key, len(judgement.ranks), j['seal'], len(seal.ranks)))
        else:
            judgement.seal = j['seal']


def need(entries, key, where):
    if key not in entries:
        P.fail('curation %s names %r, which no entry has' % (where, key))
        return Entry(key, 'NONE')
    return entries[key]


def entry_rows(e):
    """The row that carries the entry's damage or healing: the first part's, else the top rank's."""
    if not e.ranks:
        return None
    top = e.ranks[-1]
    for info in top['parts']:
        if info['prow'] is not None and info['effect'] is not None:
            return info['prow']
    return top['row']


def decide(entries, order, cur):
    kinds, none = cur['compare']['kinds'], set(cur['compare']['none'])
    for key in list(kinds) + list(none):
        need(entries, key, 'compare')
    left = []
    for ce, e in order:
        row = entry_rows(e)
        if row is not None:
            mask = row['school']
            if e.school_override:
                e.school = e.school_override
            elif mask in SCHOOL_INDEX:
                e.school = SCHOOL_INDEX[mask]
            elif e.sch is None:
                P.fail('%s: school mask %s and no schools in curation' % (e.key, mask))
            if ce.get('school') is not None and mask != ce['school'] and not e.school_override:
                P.fail('%s: school mask %s in the row, %s in the slice' % (e.key, mask, ce['school']))
            e.roll = ROLL.get(row['def'])
        top = e.ranks[-1]['row'] if e.ranks else None
        if top is not None and top['attr0'] & 0x4:
            e.nx = True
        e.cmp = compare_kind(e, ce, kinds, none)
        if e.cmp is None and e.key not in none and e.parts:
            left.append(e.key)
    for key, e in entries.items():
        if not e.parts and key in kinds:
            e.cmp = kinds[key]
    for key, r in cur['rolls'].items():
        need(entries, key, 'rolls').roll = r['roll']
    if 'attack' in entries:
        entries['attack'].roll = 'swing'
    return left


def compare_kind(e, ce, kinds, none):
    if e.key in kinds:
        return kinds[e.key]
    if e.key in none or not e.parts:
        return None
    if e.key == 'attack':
        return 'auto'
    if e.key == 'shoot':
        return 'wand'
    if e.key in ('auto shot', 'shoot bow', 'shoot gun', 'shoot crossbow', 'throw'):
        return 'shot'
    if not e.base_ok or any(p['slice']['find'] == 'none' for p in e.parts):
        return None
    if any(p['slice']['find'] == 'absorb' for p in e.parts):
        return None
    stats = {p['stat'] for p in e.parts}
    top = e.ranks[-1]['row']
    periodic = all(p['slice'].get('ticks') is not None for p in e.parts)
    if 'wpn' in stats:
        return 'strike'
    if any(p['slice'].get('per') == 'cp' for p in e.parts):
        return 'finisher'
    # A spell that only heals is a heal or a HoT, a channelled one too (Tranquility): it cannot miss and makes heal threat, and a HoT's
    # figures are a channel's (the total, and a second of the effect, design 2.3).
    if stats <= {'heal'}:
        return 'hot' if periodic or channel(top) else 'heal'
    if channel(top):
        return 'channel'
    if stats <= {'sp'} or stats == {'sp', 'heal'}:
        return 'dot' if periodic else 'spell'
    return 'dot' if periodic else 'apstrike'


# Threat -----------------------------------------------------------------------------------------------------------------------------

def make_threat_entries(entries, client, threat):
    """An entry with no parts for each threat spell the coefficient slice does not hold."""
    made = []
    for t in threat['spells']:
        key = t['key']
        e = entries.get(key)
        if e is None:
            e = Entry(key, t['class'])
            e.pet = bool(t.get('pet'))
            for r in t['ranks']:
                row = client.row(r['id'])
                if row is None:
                    P.fail('%s: no client row for rank %d' % (key, r['id']))
                    continue
                e.ranks.append({'id': r['id'], 'level': row['level'] or r['level'] or 1, 'row': row, 'parts': []})
                if row['level'] is not None and r.get('level') is not None and row['level'] != r['level']:
                    P.note('%s: rank %d is learned at %d on Forever (the research had %s)' % (key, r['id'], row['level'], r['level']))
            top = e.ranks[-1]['row'] if e.ranks else None
            if top is not None:
                e.school = SCHOOL_INDEX.get(top['school'])
                e.roll = ROLL.get(top['def'])
            entries[key] = e
            made.append(key)
    return made


def build_threat(entries, client, threat, cur):
    basis = cur['threat_basis']
    heal = threat['heal_threat']['value']
    leave = set(cur['leave_out']['threat']['keys'])
    for key in leave:
        if key not in entries:
            P.fail('curation leave_out.threat names %r, which no entry has' % key)
    for t in threat['spells']:
        key = t['key']
        e = entries[key]
        ids = [r['id'] for r in e.ranks]
        tids = [r['id'] for r in t['ranks']]
        if ids != tids:
            P.fail('%s: the threat ranks %s are not the entry\'s %s' % (key, tids, ids))
            continue
        out = {'k': t['k']}
        b = []
        cb = basis.get(key)
        for r in t['ranks']:
            letter = r.get('b')
            if cb and (not cb.get('ranks') or r['id'] in cb['ranks']):
                if letter and letter != cb['b']:
                    P.fail('%s: curation threat_basis %s against the slice\'s %s on %d' % (key, cb['b'], letter, r['id']))
                letter = letter or cb['b']
            if letter not in ('c', 'm', 'e'):
                P.fail('%s: rank %d has no threat basis' % (key, r['id']))
                letter = 'e'
            b.append(letter)
        if t.get('find') == 'threat':
            vals, pls, mxs = [], [], []
            for r, er in zip(t['ranks'], e.ranks):
                row = er['row']
                found = [x for x in row['effects'] if matches('threat', x)]
                if not found:
                    P.fail('%s: rank %d holds no threat effect' % (key, r['id']))
                    continue
                x = found[0]
                if r.get('v') is not None and not near(x['bp'], r['v']):
                    P.fail('differs, not explained: %s rank %d: threat %s in the row, %s in the slice' % (key, r['id'], x['bp'], r['v']))
                if r.get('pl') is not None and not near(x['ppl'], r['pl']):
                    P.fail('differs, not explained: %s rank %d: threat a level %s in the row, %s in the slice' % (
                        key, r['id'], x['ppl'], r['pl']))
                vals.append(rnd(x['bp'], 2))
                pls.append(rnd(x['ppl'], 3))
                mxs.append(row['max'] or 0)
            out['v'] = vals
            if any(pls):
                out['pl'] = pls[0] if len(set(pls)) == 1 else pls
                out['mx'] = mxs
        elif 'v' in t:
            out['v'] = t['v']
        elif any('v' in r for r in t['ranks']):
            out['v'] = [r['v'] for r in t['ranks']]
        if 'v' in out and isinstance(out['v'], list):
            if len(out['v']) != len(e.ranks):
                P.fail('%s: %d threat values for %d ranks' % (key, len(out['v']), len(e.ranks)))
            elif len(set(out['v'])) == 1 and t['k'] not in ('flat', 'bonus', 'drop', 'temp'):
                out['v'] = out['v'][0]
        if t['k'] in ('none', 'taunt', 'force', 'wipe', 'resist'):
            out.pop('v', None)
        out['b'] = b[0] if len(set(b)) == 1 else ''.join(b)
        for f in ('ap', 'apb', 'forms', 'note'):
            if t.get(f) is not None:
                out[f] = t[f]
        if t.get('split'):
            out['split'] = True
        e.threat = out
    # Heals make heal threat: 0.5 a point healed, split, a quarter for the paladin's three (measured, EV-0045, EV-0057, EV-0058).
    for key, e in entries.items():
        if e.threat is None and e.cmp in ('heal', 'hot') and key not in leave:
            e.threat = {'k': 'heal', 'v': heal.get(key, 0.5), 'b': 'm', 'split': True}
    for key in heal:
        if key not in entries:
            P.fail('heal_threat names %r, which no entry has' % key)
    for key in leave:
        if key in entries:
            entries[key].threat = None


# Rules and crit talents -----------------------------------------------------------------------------------------------------------

def scope_spells(entries, cls, family, mask):
    out = []
    for key, e in entries.items():
        if e.cls != cls or not e.parts or e.pet:
            continue
        hit = False
        for r in e.ranks:
            rows = [r['row']] + [info['prow'] for info in r['parts'] if info['prow'] is not None]
            for row in rows:
                if row['family'] == family and any(a & b for a, b in zip(row['mask'], mask)):
                    hit = True
        if hit:
            out.append(key)
    return sorted(out)


def schools_of(mask):
    if mask == 127:
        return None
    return [SCHOOL_INDEX[1 << b] for b in range(7) if mask & (1 << b)]


def talent_ranks(client, sid, effect, scale):
    t = client.talents.get(sid)
    row = client.row(sid)
    if t is None:
        P.fail('talent %d: no trait node in the capture' % sid)
        return None, None
    curve = t['curve'].get(str(effect))
    if curve is None and t['ranks'] == 1 and row is not None:
        x = [e for e in row['effects'] if e['i'] == effect]
        curve = [x[0]['bp']] if x else None
        P.note('talent %d (%s): one rank and no curve, so the row\'s value %s' % (sid, row['name'], curve))
    if curve is None or len(curve) != t['ranks']:
        P.fail('talent %d: a curve of %s for %d ranks' % (sid, curve, t['ranks']))
        return t, None
    if not t.get('node'):
        P.fail('talent %d: no node' % sid)
    return t, [rnd(scale(v), 4) for v in curve]


def build_rules(entries, client, threat, cur):
    rules = []
    tips = cur['tips']
    for r in threat['rules']:
        out = {'id': r['id'], 'class': r['class']}
        if 'form' in r:
            out['form'] = r['form']
        if r.get('talent'):
            t, ranks = talent_ranks(client, r['talent'], r['effect'], lambda v: 1 + v / 100.0)
            row = client.row(r['talent'])
            out.update(talent=r['talent'], node=t and t['node'], **({'def': t['def']} if t else {}), r=ranks)
            effect = [e for e in row['effects'] if e['i'] == r['effect']][0] if row else None
            scope(out, entries, r['class'], row, effect)
        elif r.get('spell'):
            row = client.row(r['spell'])
            effect = [e for e in row['effects'] if e['i'] == r['effect']][0] if row else None
            if effect is None or effect['aura'] != 10:
                P.fail('rule %s: effect %s of %s is no threat aura' % (r['id'], r['effect'], r['spell']))
                continue
            out['m'] = rnd(1 + effect['bp'] / 100.0, 4)
            scope(out, entries, r['class'], row, effect)
            if r.get('holyEffect') is not None:
                holy = [e for e in row['effects'] if e['i'] == r['holyEffect']][0]
                if holy['aura'] != 10 or holy['misc'] != 2:
                    P.fail('rule %s: effect %s is no Holy threat aura' % (r['id'], r['holyEffect']))
                out['holy'] = rnd(1 + holy['bp'] / 100.0, 4)
                out.pop('schools', None)
        if r.get('aura'):
            out['aura'] = r['aura']
        out['b'] = 'c'
        if r.get('holyB'):
            out['holyB'] = r['holyB']
        out['name'] = r['name']
        tip = tips.get(r['id'])
        if tip:
            out['tip'] = tip['tip']
            text = ' '.join((client.row(x) or {}).get('desc', '') for x in (tip['tip'] if isinstance(tip['tip'], list) else [tip['tip']]))
            if not re.search(r'threat', text, re.I):
                out['say'] = True
            if tip.get('note'):
                out['note'] = tip['note']
        if r.get('shield'):
            out['shield'] = True
        if r.get('twoHand'):
            out['twoHand'] = True
        if r.get('always'):
            out['always'] = True
        if 'form' in out and out.get('m') is not None and out['m'] < 1:
            out['lowers'] = True
        if r.get('rockbiterEffect') is not None:
            row = client.row(r['talent'])
            x = [e for e in row['effects'] if e['i'] == r['rockbiterEffect']][0]
            if x['aura'] != 107:
                P.fail('rule %s: effect %s is no flat modifier' % (r['id'], r['rockbiterEffect']))
            if out.get('r'):
                out['rockbiter'] = rnd((1 + x['bp'] / 100.0) * out['r'][0], 4)
        rules.append(out)
    for key in tips:
        if key not in [r['id'] for r in threat['rules']]:
            P.fail('curation tips names rule %r, which threat.json has not' % key)
    ti = cur['threat_items']
    for it in ti['items']:
        row = client.row(it['spell'])
        x = [e for e in row['effects'] if e['aura'] == 10 and e['misc'] == 127] if row else []
        if not x:
            P.fail('threat item %s: its equip spell %s holds no threat aura' % (it['id'], it['spell']))
            continue
        rules.append({'id': it['id'], 'class': 'ALL', 'item': it['item'], 'm': rnd(1 + x[0]['bp'] / 100.0, 4), 'b': 'c',
                      'name': it['name']})
    for it in ti['enchants']:
        row = client.row(it['spell'])
        x = [e for e in row['effects'] if e['aura'] == 10 and e['misc'] == 127] if row else []
        if not x:
            P.fail('threat enchant %s: its spell %s holds no threat aura' % (it['id'], it['spell']))
            continue
        rules.append({'id': it['id'], 'class': 'ALL', 'enchant': it['enchant'], 'slot': it['slot'],
                      'm': rnd(1 + x[0]['bp'] / 100.0, 4), 'b': 'c', 'name': it['name']})
    return rules


def scope(out, entries, cls, row, effect):
    """What a threat rule covers: a school mask (MOD_THREAT) or the class's spells of a threat modifier's class mask."""
    if effect is None or row is None:
        return
    if effect['aura'] == 10:
        s = schools_of(effect['misc'])
        if s:
            out['schools'] = s
    elif effect['aura'] in (107, 108) and effect['misc'] == 2:
        family = effect['family'] or row['family']
        out['spells'] = scope_spells(entries, cls, family, effect['mask'])
        if not out['spells']:
            P.fail('rule %s: its class mask covers no spell of the data' % out['id'])
    else:
        P.fail('rule %s: effect %d of %s is no threat effect (aura %d)' % (out['id'], effect['i'], row['name'], effect['aura']))


def build_crit(entries, client, gear):
    out = []
    for c in gear['crit']:
        row = client.row(c['spell'])
        effect = [e for e in row['effects'] if e['i'] == c['effect']][0]
        if effect['aura'] != 108 or effect['misc'] != 15:
            P.fail('crit %s: effect %d is no crit damage modifier' % (c['name'], c['effect']))
        cls = [k for k, v in CLASS_FAMILY.items() if v == row['family']]
        if not cls:
            P.fail('crit %s: no class family' % c['name'])
            continue
        spells = scope_spells(entries, cls[0], effect['family'] or row['family'], effect['mask'])
        rec = {}
        if c.get('talent'):
            t, ranks = talent_ranks(client, c['talent'], c['effect'], lambda v: v / 100.0)
            rec.update(talent=c['talent'], node=t and t['node'], **({'def': t['def']} if t else {}), r=ranks)
        else:
            rec.update(aura=c['aura'], r=[rnd(effect['bp'] / 100.0, 4)])
        rec['spells'] = spells
        if not spells:
            P.fail('crit %s covers no spell of the data' % c['name'])
        out.append(rec)
    return out


# Probes, defaults, Rockbiter -------------------------------------------------------------------------------------------------------

KNOWN_KEYS = set()


def build_probes(entries):
    probes = {}
    for cls in SPELL_POWER_CLASSES:
        found = []
        for key in sorted(entries):
            e = entries[key]
            if e.cls != cls or not e.parts or e.pet:
                continue
            part = e.parts[0]
            if part['stat'] not in ('sp', 'heal') or part['slice']['find'] not in ('damage', 'heal') or part.get('g') or part.get('o') \
                    or part['b'] != 'c' or e.key in KNOWN_KEYS:
                continue
            for r in reversed(e.ranks):
                info = r['parts'][0]
                if info['effect'] is None or info['row_id'] != r['id'] or info['c'] is None or info['c'] <= 0:
                    continue
                desc = r['row'].get('desc') or ''
                m = re.search(r'\$', desc)
                first = re.match(r'\$([smM])(\d)(?![0-9])', desc[m.start():]) if m else None
                if first and int(first.group(2)) == info['effect']['i'] + 1:
                    found.append(r['id'])
        probes[cls] = found
        if not found:
            P.fail('no probe for %s' % cls)
    return probes


def build_defaults(entries, cur):
    """The default lines of design 2.1, in the one form GearLines.lua reads: a line is a key; a list of keys is the first of them known
    (Greater Heal, else Heal); { needs, keys, else } is each of its keys while needs is known, else each of else, written as the Lua table
    { key, key ..., needs = key, ["else"] = { key ... } }. Every key must be an entry of the class or of every class."""
    out = {}

    def resolve(cls, role, key):
        e = entries.get(key) if isinstance(key, str) else None
        if e is None or e.cls not in (cls, 'ALL'):
            P.fail('default %s %s: %r does not resolve' % (cls, role, key))

    def keys_of(cls, role, value, what):
        if not isinstance(value, list) or not value:
            P.fail('default %s %s: %s is no list of keys' % (cls, role, what))
            return []
        for key in value:
            resolve(cls, role, key)
        return list(value)

    for cls, roles in cur['defaults'].items():
        if cls in ('why', 'source'):
            continue
        out[cls] = {}
        for role, items in roles.items():
            lines = []
            for item in items:
                if isinstance(item, str):
                    resolve(cls, role, item)
                    lines.append(item)
                elif isinstance(item, list):
                    lines.append(keys_of(cls, role, item, 'a choice'))
                elif isinstance(item, dict):
                    extra = set(item) - {'needs', 'keys', 'else'}
                    if extra or not isinstance(item.get('needs'), str):
                        P.fail('default %s %s: %r is not { needs, keys, else }' % (cls, role, item))
                        continue
                    resolve(cls, role, item['needs'])
                    group = {i + 1: key for i, key in enumerate(keys_of(cls, role, item.get('keys'), 'keys'))}
                    group['needs'] = item['needs']
                    if 'else' in item:
                        group['else'] = keys_of(cls, role, item['else'], 'else')
                    lines.append(group)
                else:
                    P.fail('default %s %s: %r is no line' % (cls, role, item))
            out[cls][role] = lines
    return out


def build_rockbiter(client, cur):
    out = []
    for sid in cur['rockbiter']['spells']:
        row = client.row(sid)
        x = [e for e in row['effects'] if e['type'] == 360] if row else []
        if not x:
            P.fail('Rockbiter %d: no enchant effect' % sid)
            continue
        out.append(x[0]['misc'])
    return sorted(out)


# Lua --------------------------------------------------------------------------------------------------------------------------------

def lua_num(x):
    if isinstance(x, bool):
        return 'true' if x else 'false'
    if isinstance(x, int):
        return str(x)
    x = round(x, 4)
    if x == int(x):
        return str(int(x))
    text = repr(x)
    if 'e' in text:
        text = '%.6f' % x
        text = text.rstrip('0').rstrip('.')
    return text


def lua(v):
    if v is None:
        return 'nil'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return lua_num(v)
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(v, list):
        items = list(v)
        while items and items[-1] is None:
            items.pop()
        return '{ ' + ', '.join(lua(x) for x in items) + ' }' if items else '{}'
    if isinstance(v, dict):
        return '{ ' + ', '.join(field(k, x) for k, x in v.items()) + ' }'
    raise TypeError(v)


# Lua's reserved words, which a table constructor can only take as ["word"] = ...
LUA_WORDS = {'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
             'return', 'then', 'true', 'until', 'while'}


def field(k, v):
    if isinstance(k, int):
        return lua(v)
    if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', k) and k not in LUA_WORDS:
        return '%s = %s' % (k, lua(v))
    return '[%s] = %s' % (lua(k), lua(v))


class Writer:
    def __init__(self):
        self.lines = []
        self.used = {k: set() for k in FIELDS}

    def mark(self, kind, keys):
        for k in keys:
            if k not in FIELDS[kind]:
                P.fail('a %s field %r that design 3.2 does not name' % (kind, k))
            self.used[kind].add(k)


def part_fields(part, info_top):
    f = {1: part['stat'], 2: rnd(info_top['c'], 4) if info_top['c'] is not None else 0}
    s = part['slice']
    if info_top.get('n') is not None and info_top['n'] > 1:
        f['n'] = info_top['n']
        if info_top.get('p'):
            f['p'] = rnd(info_top['p'], 3)
    for k in ('per', 'max', 'j', 'cp', 'spd', 'h'):
        v = part.get(k, s.get(k))
        if v is not None:
            f[k] = v if k != 'j' else rnd(info_top['effect']['amp'], 4) if info_top['effect'] else v
    for k in ('sch', 'g', 'fs', 'o', 'two', 'note'):
        if part.get(k) is not None:
            f[k] = part[k]
    if s.get('per') == 'cp' and s.get('cp'):
        f['cp'] = s['cp']
    f['b'] = part['b']
    return f


SEALS = {}


def seal_values(entries, client, cur):
    """The seal value of each rank of a seal, from the dummy effect of the judgement of the same rank."""
    for key, s in cur['seal_values'].items():
        seal, judgement = need(entries, key, 'seal_values'), need(entries, s['from'], 'seal_values')
        if len(seal.ranks) != len(judgement.ranks):
            P.fail('%s: %d ranks, its judgement %d' % (key, len(seal.ranks), len(judgement.ranks)))
            continue
        for sr, jr in zip(seal.ranks, judgement.ranks):
            x = [e for e in jr['row']['effects'] if matches(s['effect'], e) and e['type'] == 3]
            if not x:
                P.fail('%s: judgement rank %d holds no dummy' % (key, jr['id']))
                continue
            own = [e for e in sr['row']['effects'] if matches('dummy', e)]
            if own and (not near(own[0]['bp'], x[0]['bp']) or not near(own[0]['ppl'], x[0]['ppl'])):
                P.note('%s rank %d: the seal\'s own value %s (+%s) and its judgement\'s %s (+%s); the judgement\'s stands' % (
                    key, sr['id'], own[0]['bp'], own[0]['ppl'], x[0]['bp'], x[0]['ppl']))
            SEALS[sr['id']] = (x[0], jr['row'])


def rank_fields(e, r, parts_top, caster):
    f = {1: r['id'], 2: r['level']}
    row = r['row']
    c, n, w, bm, bl, lv, mx = [], [], [], [], [], [], []
    cpb = sv = None
    periodic = False
    for i, (part, info) in enumerate(zip(e.parts, r['parts'])):
        top = parts_top[i]
        val = info['c']
        if part['stat'] == 'wpn':
            w.append(rnd(val, 4) if val is not None and not near(val, top[2]) else None)
            c.append(None)
        else:
            c.append(rnd(val, 4) if val is not None and not near(val, top[2]) else None)
            w.append(None)
        ticks = info['n'] if info['n'] is not None and info['n'] > 1 else None
        n.append(ticks if ticks != top.get('n') else None)
        eff, prow = info['effect'], info['prow']
        if info['n'] is not None:
            periodic = True
        mean = gain = None
        if eff is not None and not info['shared']:
            k = info['n'] or 1
            if part['slice'].get('base') == 'sv':
                if r['id'] in SEALS:
                    eff, prow = SEALS[r['id']]
                sv = rnd(eff['bp'], 2)
                gain = eff['ppl']
            elif part['stat'] == 'wpn' and eff['type'] == 31:
                mean = gain = None
            else:
                mean = eff['bp'] * k
                # A gain a level counts from a base mean: with none (a dummy of base 0 the server works out, Riptide's direct heal) there
                # is no base to gain, so bl, lv and mx stay off that part, as bm does.
                gain = eff['ppl'] * k if mean else None
                if part['slice'].get('per') == 'cp' and eff['ppr']:
                    cpb = rnd(eff['ppr'] * k, 2)
        bm.append(rnd(mean, 2) if mean else None)
        bl.append(rnd(gain, 3) if gain else None)
        carrier_level = prow['level'] if prow is not None and prow['level'] else r['level']
        lv.append(carrier_level if gain and carrier_level != r['level'] else None)
        mx.append(prow['max'] if gain and prow is not None and prow['max'] else None)
    for name, vals in (('c', c), ('n', n), ('w', w)):
        if any(v is not None for v in vals):
            f[name] = vals
    # The cast of a rank: -1 a channel; the caster kinds always (0 instant); others only a real cast (Slam, Aimed Shot). An auto
    # attack's or a shot's pace is its weapon's speed, and a ranged ability's negative cast (-1000000, "the ranged weapon's") is none.
    cast = row['cast'] if row['cast'] and row['cast'] > 0 else 0
    if channel(row):
        f['ct'] = -1
    elif e.cmp in ('auto', 'shot', 'wand'):
        pass
    elif caster or cast:
        f['ct'] = cast
    dur = row['dur']
    for info in r['parts']:
        if info['n'] is not None and info['prow'] is not None and info['effect'] is not None and info['effect']['period'] \
                and info['prow'] is not row and info['prow']['dur'] and info['prow']['dur'] > 0:
            dur = info['prow']['dur']
            break
    # The duration of a periodic, channelled, seal or proc rank, and of one whose threat lasts: a taunt's, a forced attack's and Fade's
    # (SpellModel.lua words "3 sec", "forces attacks 6 sec" and "for 10 sec" from it, design 1.2).
    lasting = e.threat is not None and e.threat.get('k') in ('taunt', 'force', 'more', 'temp')
    if (periodic or channel(row) or e.cmp in ('seal', 'proc') or lasting) and dur and dur > 0:
        f['du'] = dur
    for name, vals in (('bm', bm), ('bl', bl), ('lv', lv), ('mx', mx)):
        if any(v is not None for v in vals):
            f[name] = vals
    if cpb:
        f['cpb'] = cpb
    if sv is not None:
        f['sv'] = sv
    return f


def entry_lua(w, e):
    caster = e.cmp in ('spell', 'dot', 'channel', 'heal', 'hot')
    head = {'key': e.key}
    if e.pet:
        head['pet'] = True
    if e.sch:
        head['sch'] = e.sch
    elif e.school:
        head['school'] = e.school
    if e.cmp:
        head['cmp'] = e.cmp
    if e.roll:
        head['roll'] = e.roll
    if e.nb:
        head['nb'] = True
    if e.nx:
        head['nx'] = True
    if e.seal:
        head['seal'] = e.seal
    parts_top = []
    for i, part in enumerate(e.parts):
        info = e.ranks[-1]['parts'][i]
        pf = part_fields(part, info)
        parts_top.append(pf)
        w.mark('part', pf.keys())
    w.mark('entry', list(head.keys()) + ['parts', 'ranks'] + (['threat'] if e.threat else []))
    lines = ['\t\t{ ' + ', '.join(field(k, v) for k, v in head.items()) + ',']
    lines.append('\t\t\tparts = ' + ('{ ' + ', '.join(lua(pf) for pf in parts_top) + ' },' if parts_top else '{},'))
    ranks = []
    for r in e.ranks:
        rf = rank_fields(e, r, parts_top, caster)
        w.mark('rank', rf.keys())
        ranks.append(lua(rf))
    if len(ranks) <= 1 and sum(len(x) for x in ranks) < 90:
        lines.append('\t\t\tranks = { ' + ', '.join(ranks) + ' }' + (',' if e.threat else ' },'))
    else:
        lines.append('\t\t\tranks = {')
        for x in ranks:
            lines.append('\t\t\t\t' + x + ',')
        lines.append('\t\t\t}' + (',' if e.threat else ' },'))
    if e.threat:
        w.mark('threat', e.threat.keys())
        lines.append('\t\t\tthreat = ' + lua(e.threat) + ' },')
    return lines


HEADER = '''local _, ns = ...

-- Generated by tools/dev/make_spelltips.py from tools/dev/spelltips/*.json. Do not edit by hand: change the inputs (README, Spell data)
-- and run it again; make_spelltips.py --check holds every field to the shapes below and every value a client row holds to the row.
--
-- The values are WoW: Forever's own. Every client row is from build %(build)s with hotfix push %(hotfix)s, as wowsims/forever
-- (github.com/wowsims/forever, MIT licence, Copyright (c) 2022 wowsims team) captured the game's spell rows; the rows of Attack and the
-- generic shots, the description variables and the talent nodes are from the client tables of build %(fallback)s exported by
-- GrunzForever (github.com/10igma/GrunzForever, a tool under the MIT licence). Where the server does what the rows do not say, the
-- values come from the in-game measurements of wowsims/forever (docs/evidence), Blizzard's development notes and hotfix posts, the
-- downranking estimate of ForeverChanges (foreverchanges.pro), the Forever hunter wiki (classic-hunter/forever-hunter), gunba's notes on
-- Ice Lance (wow-forever-sim, docs/uncertainties.md) and, for a few spells unmeasured on Forever, Warcraft Tavern's Classic threat guide.
-- The stat keys and rating sizes were checked against data from Efficient Games (https://efficient.games), licensed under CC BY 4.0.
-- No addon's code or data table is used; the values are facts of the game's client and of measurements.
--
-- Basis of a value (b): c client data (a row, a curve or the game's text), m measured on Forever, e estimate (shown with ~ before it).
-- An entry (one spell, every rank): key (English name, lower case; " (pet)" for a pet's spell), pet, school (Lua school index 1-7) or
--   sch (several, of which the lower counts), cmp (the comparison kind, nil when the comparison cannot work it out), roll (the attack
--   table line of the row's DefenseType: spell, special, ranged, or swing for Attack), nb (cannot be blocked), nx (replaces the next
--   swing), seal (a judgement: the key of its seal, whose highest rank known gives the judgement's of the same place), parts, ranks,
--   threat.
-- A part: [1] the stat (sp, heal, ap, rap, wpn: weapon damage with the coefficient its multiple, bv: block value), [2] the coefficient of
--   the top rank (a periodic part's total over its ticks), n ticks and p seconds a tick, per (target, first with max targets, jump with j
--   the share kept each jump, hit, block, stack, proc, missile, cp with cp the shares at 1 to 5 combo points, self), spd (actual, norm,
--   nranged, cat, bear) and h (main, off, both, ranged) for a weapon part, sch, g (the game's text counts this stat at this share
--   already), fs = { form, share } (the share the text counts in that form), o (the text counts the stat otherwise) with two (the share
--   with a two-hander), note, b.
-- A rank: [1] the spell ID, [2] its level (learned), then by part where the rank differs: c coefficient, n ticks, w weapon multiple;
--   ct cast ms (0 instant, -1 channel), du duration ms, bm the base mean at lv and bl its gain a level (a periodic part's total over its
--   ticks; a weapon part's flat bonus), lv the level the gain counts from and mx the level it stops (0 none), both from the row that
--   carries the part (lv is the rank's level when absent), cpb points a combo point, sv the seal value.
-- A threat: k (mult, bonus, flat, more, drop, temp, taunt, force, none, heal, wipe, resist, caster, rage), v (one number or one a rank),
--   b (one letter or one a rank), ap and apb (the share of attack power added and its basis), pl the gain a level (one or one a rank)
--   with mx the level it stops a rank, split, forms, note.
'''


def write_lua(entries, rules, crit, gear, cur, threat, probes, defaults, rockbiter, client):
    w = Writer()
    model = {k: v['value'] for k, v in gear['model'].items()}
    model['downrank'] = {'grace': cur['downrank']['grace'], 'step': cur['downrank']['step']}
    out = [HEADER % {'build': client.data['build'], 'hotfix': client.data['hotfix'], 'fallback': client.data['fallback']}]
    out.append('local D = {}')
    out.append('ns.SpellData = D')
    out.append('')
    out.append('D.BUILD, D.HOTFIX, D.FALLBACK = %s, %s, %s' % (lua(client.data['build']), lua(client.data['hotfix']),
                                                           lua(client.data['fallback'])))
    out.append('-- The number of spells of every class and ALL, for /flatui status, so no other class\'s constructor runs to count them.')
    out.append('D.SPELLS = %d' % len(entries))
    out.append('')
    out.append('-- Constants of the gear model: crit multiplier by attack table line (STAT_CRIT_BONUS), attack power a point of DPS, the')
    out.append('-- global cooldown, the off hand, heal threat a point, the normalized speeds and the forms\' swings, glancing blows, the')
    out.append('-- rating sizes for 1% (used only without the game\'s conversion) and the downranking estimate.')
    out.append('D.MODEL = {')
    for k in ('crit', 'apPerDps', 'gcd', 'offHand', 'healThreat', 'norm', 'form', 'glance', 'ratings', 'downrank'):
        out.append('\t%s = %s,' % (k, lua(model[k])))
    out.append('}')
    out.append('D.SCHOOL_NAMES = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }')
    out.append('')
    out.append('-- One constructor a class, and ALL for the spells of every class; SpellModel.lua runs the player\'s class and ALL once, on')
    out.append('-- first use. A hunter\'s and a warlock\'s hold their pets\' entries too. Constructors use no locals.')
    out.append('D.CLASS = {}')
    for cls in ('ALL',) + CLASSES:
        group = sorted((e for e in entries.values() if e.cls == cls), key=lambda e: (e.pet, e.key))
        out.append('')
        out.append('D.CLASS.%s = function()' % cls)
        out.append('\treturn {')
        for e in group:
            out.extend(entry_lua(w, e))
        out.append('\t}')
        out.append('end')
    out.append('')
    out.append('-- Threat multipliers. A talent carries its trait node and definition, read with C_Traits.GetNodeInfo, and r its multiplier')
    out.append('-- a rank; schools, spells, form, shield, twoHand, item, enchant and slot say where a rule applies; say: the tip spell\'s')
    out.append('-- own text says nothing of threat, so its tooltip gets the multiplier; lowers: a threat-lowering stance or form, background')
    out.append('-- for a damage dealer; always: it always applies; rockbiter: the multiplier with Rockbiter Weapon on the main hand.')
    out.append('D.RULES = {')
    for r in rules:
        w.mark('rule', r.keys())
        out.append('\t' + lua(r) + ',')
    out.append('}')
    out.append('-- Heal threat a point healed of the paladin\'s three heals (measured), where other heals make D.MODEL.healThreat.')
    out.append('D.HEAL_THREAT = ' + lua({k: v for k, v in sorted(threat['heal_threat']['value'].items())}))
    out.append('-- Crit damage talents and auras: m = 1 + (base - 1) x (1 + r) on the spells they name (their class mask).')
    out.append('D.CRIT = {')
    for c in crit:
        w.mark('crit', c.keys())
        out.append('\t' + lua(c) + ',')
    out.append('}')
    out.append('-- Every item stat key of the client; t: its "Equip:" sentence, for the keys that have one. none: known, not in the model;')
    out.append('-- note: not in the model, and named when an item has it; avoid (with its rating index) and armor: counted by GearAvoid.lua only.')
    out.append('D.STATS = {')
    for s in sorted(gear['stats'], key=lambda s: s['key']):
        out.append('\t%s = %s,' % (s['key'], lua(stat_value(s))))
    out.append('}')
    out.append('-- Two stats in one sentence: the line explains both.')
    pairs = [dict([(i + 1, k) for i, k in enumerate(p['keys'])] + [('t', p['t'])]) for p in gear['pairs']]
    out.append('D.STAT_PAIRS = ' + lua(pairs))
    out.append('-- The default lines by class and role (ns.PlayerRole: damage, tank, healer; cat: a druid in Cat Form), each if known: a key;')
    out.append('-- a list of keys, the first of them known; { key, key ..., needs = key, ["else"] = { key ... } }, each of its keys while needs')
    out.append('-- is known, else each of else (design 2.1; GearLines.lua reads them).')
    out.append('D.DEFAULTS = {')
    for cls in sorted(defaults):
        out.append('\t%s = %s,' % (cls, lua({role: defaults[cls][role] for role in sorted(defaults[cls])})))
    out.append('}')
    out.append('-- Ranks whose text starts with the plain amount of the part, for the check of SpellModel.lua whether the game\'s texts')
    out.append('-- count spell power; the highest rank of each spell first.')
    out.append('D.PROBES = {')
    for cls in sorted(probes):
        out.append('\t%s = %s,' % (cls, lua(probes[cls])))
    out.append('}')
    out.append('-- The temporary enchants of Rockbiter Weapon, from its imbue spells (effect 360, misc value).')
    out.append('D.ROCKBITER = { ' + ', '.join('[%d] = true' % x for x in rockbiter) + ' }')
    out.append('')
    return '\n'.join(out), w


def stat_value(s):
    kind = s['kind']
    v = {1: kind}
    if kind in ('stat', 'school'):
        v[2] = s['index']
    elif kind == 'rating':
        v[2] = s['ratings']
        v[3] = s['size']
    elif kind == 'skill':
        v[2] = s['line']
    elif kind == 'vs':
        v[2] = s['type']
        v[3] = s['stat']
    elif kind == 'note':
        v[2] = s['what']
    elif kind == 'avoid':
        v[2] = s['rating']
    if s.get('t'):
        v['t'] = s['t']
    return v


# The checks that need the whole --------------------------------------------------------------------------------------------------

def level_rows(entries):
    out = set()
    for key, e in entries.items():
        for r in e.ranks:
            for info in r['parts']:
                row, eff = info['prow'], info['effect']
                if row is not None and eff is not None and eff['ppl'] and row['base'] is not None and row['level'] is not None \
                        and row['base'] != row['level']:
                    out.add('%s %d (base %s, spell %s)' % (key, info['row_id'], row['base'], row['level']))
    return sorted(out)


def check_whole(entries, rules, crit, w, client, coef, threat, gear):
    ids = {}
    for key, e in entries.items():
        for r in e.ranks:
            ids.setdefault(r['id'], []).append(key)
    for sid, keys in ids.items():
        if len(keys) > 1:
            P.fail('rank %d in %s' % (sid, keys))
    keys = [e['key'] for e in coef['spells']] + [t['key'] for t in threat['spells'] if t['key'] not in
                                                  {e['key'] for e in coef['spells']}]
    if len(keys) != len(set(keys)):
        P.fail('a key twice')
    for key, e in entries.items():
        for i, part in enumerate(e.parts):
            if part['b'] not in ('c', 'm', 'e'):
                P.fail('%s part %d: basis %r' % (key, i + 1, part['b']))
            for r in e.ranks:
                c = r['parts'][i]['c']
                if c is not None and part['stat'] != 'wpn' and not 0 <= c <= 5:
                    P.fail('%s rank %d part %d: coefficient %s' % (key, r['id'], i + 1, c))
                if c is not None and part['stat'] == 'wpn' and not 0 < c <= 5:
                    P.fail('%s rank %d part %d: weapon multiple %s' % (key, r['id'], i + 1, c))
    capdefs = {t['def'] for t in client.talents.values()}
    for x in rules + crit:
        if x.get('talent'):
            if not x.get('r') or x.get('node') is None or x.get('def') not in capdefs:
                P.fail('talent %s: curve %s, node %s, definition %s' % (x['talent'], x.get('r'), x.get('node'), x.get('def')))
    stat_keys = [s['key'] for s in gear['stats']]
    if len(stat_keys) != len(set(stat_keys)):
        P.fail('an item stat key twice')
    for s in gear['stats']:
        if s['kind'] not in STAT_KINDS:
            P.fail('item stat %s: kind %r' % (s['key'], s['kind']))
        if (s['kind'] == 'avoid') != (s.get('rating') is not None) or (s['kind'] == 'avoid' and s['rating'] not in AVOID_RATINGS):
            P.fail('item stat %s: rating %r' % (s['key'], s.get('rating')))
    written = {e.cmp for e in entries.values() if e.cmp}
    for k in CMP_KINDS:
        if k not in written:
            P.fail('no entry of the comparison kind %r' % k)
    for kind in FIELDS:
        extra = sorted(str(k) for k in w.used[kind] - STUB_FIELDS[kind])
        if extra:
            P.note('fields of design 3.2 the stub (3.2a) does not use, in %s: %s' % (kind, ', '.join(extra)))
        unwritten = sorted(str(k) for k in STUB_FIELDS[kind] - w.used[kind])
        if unwritten:
            P.fail('fields the stub uses that no %s holds: %s' % (kind, ', '.join(unwritten)))


# Main ------------------------------------------------------------------------------------------------------------------------------

def main():
    check_only = '--check' in sys.argv[1:]
    coef, threat, gear, cur = load('coef.json'), load('threat.json'), load('gear.json'), load('curation.json')
    client = Client(load('client_spells.json'))
    entries, order = build_entries(client, coef, cur)
    marked = scan_texts(order, client)
    apply_curation(entries, cur)
    apply_judgements(entries, cur)
    made = make_threat_entries(entries, client, threat)
    left = decide(entries, order, cur)
    build_threat(entries, client, threat, cur)
    for key in cur['leave_out']['spells']['keys']:
        if key in entries:
            P.fail('%s is left out by curation but has an entry' % key)
    rules = build_rules(entries, client, threat, cur)
    crit = build_crit(entries, client, gear)
    KNOWN_KEYS.update(k for k, v in cur['known_differences'].items() if v.get('part') == 0)
    probes = build_probes(entries)
    defaults = build_defaults(entries, cur)
    rockbiter = build_rockbiter(client, cur)
    seal_values(entries, client, cur)
    text, w = write_lua(entries, rules, crit, gear, cur, threat, probes, defaults, rockbiter, client)
    check_whole(entries, rules, crit, w, client, coef, threat, gear)
    ranks = sum(len(e.ranks) for e in entries.values())
    with_threat = sum(1 for e in entries.values() if e.threat)
    print('SpellData.lua: %d spells, %d ranks, %d threat entries, %d rules, %d crit talents, %d stat keys; %d bytes' % (
        len(entries), ranks, with_threat, len(rules), len(crit), len(gear['stats']), len(text.encode('utf-8'))))
    print('comparison kinds: ' + ', '.join('%s %d' % (k, sum(1 for e in entries.values() if e.cmp == k)) for k in CMP_KINDS))
    print('left out of the comparison, no base value found: %s' % (', '.join(sorted(left)) or 'none'))
    print('left out of the comparison by curation: %s' % ', '.join(sorted(cur['compare']['none'])))
    print('threat-only entries: %s' % ', '.join(sorted(made)))
    print('parts the text scan marked as counted by the game\'s text (g): %s' % ', '.join(marked))
    for cls in sorted(probes):
        print('probes %s: %s' % (cls, ', '.join(str(x) for x in probes[cls])))
    print('rows with a gain a level whose base level and spell level differ: %s' % (', '.join(level_rows(entries)) or 'none'))
    nx = sorted(e.key for e in entries.values() if e.nx)
    print('next swing (attribute word 0 bit 0x4): %s' % ', '.join(nx))
    for (key, i), x in sorted(P.explained.items()):
        print('differs, explained by known_differences: %s part %d, %d ranks: %s %s in the row, %s shipped (%s)' % (
            key, i + 1, x['ranks'], x['what'], '/'.join(str(v) for v in sorted(x['row'])),
            '/'.join(str(v) for v in sorted(x['shipped'])), x['why'].split('. ')[0]))
    for n in P.notes:
        print('note: ' + n)
    for f in P.failed:
        print('FAILED: ' + f)
    if P.failed:
        print('%d checks failed; nothing written.' % len(P.failed))
        return 1
    if check_only:
        print('--check: every check passed; nothing written.')
        return 0
    with open(OUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(text)
    print('wrote %s' % os.path.relpath(OUT, ROOT))
    status = 0
    if shutil.which('luac5.4'):
        r = subprocess.run(['luac5.4', '-p', OUT], capture_output=True, text=True)
        print('luac5.4 -p: %s' % ('clean' if r.returncode == 0 else r.stderr.strip()))
        status |= r.returncode
    check = os.path.join(HERE, 'lua51_check.py')
    if os.path.exists(check):
        r = subprocess.run([sys.executable, check, OUT], capture_output=True, text=True)
        print('lua51_check.py: %s' % ('clean' if r.returncode == 0 else r.stdout.strip()))
        status |= r.returncode
    return 1 if status else 0


if __name__ == '__main__':
    sys.exit(main())
