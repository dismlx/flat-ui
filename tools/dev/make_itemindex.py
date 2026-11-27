#!/usr/bin/env python3
"""Makes FlatUI/ItemIndex.lua, the item index of the gear comparison's item finder (GearSearch.lua, its source All items).

Usage: python3 tools/dev/make_itemindex.py SQLITE [--check]

SQLITE is GrunzForever's export of every client table of WoW: Forever (github.com/10igma/GrunzForever, a tool under the MIT licence; the
file wow_wowf_1.60.1.70888.sqlite: build 1.60.1.70888 with the hotfixes of its date). Its build is the Version of its _ExtractionMetadata
table, else the 1.60.1.NNNNN of its file name, and the generator stops when it finds neither. Only the export is read: the Item table
(class, subclass, inventory type) and the ItemSparse table (English name, required level, item level, quality, allowable classes, flags).

The index holds every item a player can wear: weapons and armor (item class 2 and 4, ItemConstantsDocumentation.lua:269) with an inventory
type (Item.InventoryType, ItemConstantsDocumentation.lua:182), quality 0 to 5 (Poor to Legendary, ItemQualitiesDocumentation.lua:6), a
name, a required level of 60 or less (no player of Forever's classic content goes past 60) and a class of the nine classic classes allowed.
It leaves out the client's test and placeholder items: a name with Test or Testing, Monster, Deprecated, DEBUG, Placeholder, Unused,
Template, [PH], [TMP], PH, DND or DNT (do not delete, do not translate: the developers' marks), OLD in capitals (zzOLD, (OLD), OLDMonster),
QA (QAEnchant, QATest) or a level and quality first (90 Epic Warrior Gun), and every item whose ItemSparse flags carry the client's
deprecated mark (word 0, 0x10, ITEM_FLAG_DEPRECATED: the old vendor relics, bucklers and starter weapons, the Durability test set, the
PvP pieces the game replaced). A name is never changed: one with a tab, a line break or "]=]" stops the generator, as the Lua long strings
could not hold it.

The file: ns.ItemIndex = { BUILD, COUNT, FIELDS, DATA }, DATA a string an inventory type, one record a line, the fields of FIELDS
separated by tabs, the records of a type in item ID order. --check writes nothing and exits 1 on a failed check or when FlatUI/ItemIndex.lua
is not what this export makes; without it the file is written only when every check passes, and then luac5.4 -p and
tools/dev/lua51_check.py run on it when they are there. The checks: the export's build is found; every item ID once; every field a whole
number where it is one; every name one line with no tab and no "]=]"; every inventory type one a weapon or armor has (INVTYPES); the file
under 600,000 bytes; the strings, read back as Lua reads a long string, give the records. It prints the count a type, what it left out and
why, and the file's size. Python 3, standard library only; deterministic (sorted, no dates), so a new export shows as a plain diff.
"""
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import textwrap

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import strip_lua
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'FlatUI', 'ItemIndex.lua')
MAX_BYTES = 600000
MAX_LEVEL = 60
FIELDS = ('id', 'name', 'class', 'subclass', 'req', 'ilvl', 'quality', 'classes')
# The inventory types a weapon or armor can have, by the client's Item.InventoryType (ItemConstantsDocumentation.lua:182-224), with the
# words the file's header gives them. 18 (bag), 24 (ammo) and 27 (quiver) are not weapons or armor; 29 and up are not Forever's.
INVTYPES = {
    1: 'Head', 2: 'Neck', 3: 'Shoulder', 4: 'Shirt', 5: 'Chest', 6: 'Waist', 7: 'Legs', 8: 'Feet', 9: 'Wrist', 10: 'Hands',
    11: 'Finger', 12: 'Trinket', 13: 'One-hand', 14: 'Shield', 15: 'Ranged (bow)', 16: 'Back', 17: 'Two-hand', 19: 'Tabard',
    20: 'Chest (robe)', 21: 'Main hand', 22: 'Off hand', 23: 'Held in off hand', 25: 'Thrown', 26: 'Ranged (gun, crossbow, wand)',
    28: 'Relic',
}
# The class bits of the classic classes: bit (classID - 1) of the client's class IDs, 1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue, 5 Priest,
# 7 Shaman, 8 Mage, 9 Warlock, 11 Druid. A mask that has them all is any class (-1); the client's 0 and -1 are any class too.
CLASSIC_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
ITEM_FLAG_DEPRECATED = 0x10
# The developers' marks, case-insensitive: whole words for test and testing (so Testament and Contest stay), unused, template, DND and DNT.
MARKS = re.compile(r'\btest(?:ing)?\b|monster|deprecated|debug|placeholder|\bunused\b|\btemplate\b|\[ph\]|\[tmp\]|\bdn[dt]\b', re.I)
# The marks whose case counts: OLD in capitals (Old Blanchy's Blanket and Old Leather Belt are real), PH and QA as words or prefixes, and a
# level and a quality first, the stat test sets (90 Epic Warrior Gun, 63 Green Frost Boots).
MARKS_CASED = re.compile(r'(?<![A-Z])OLD|\bQA|\bPH\b|^\d+ (?:Epic|Green|Blue|Rare|White) ')
REASONS = ('no name', 'a test or placeholder name', 'the client\'s deprecated flag', 'quality not 0 to 5',
           'required level over 60', 'no classic class allowed')


class Fail(Exception):
    pass


def export_build(db, path):
    try:
        row = db.execute("SELECT Value FROM _ExtractionMetadata WHERE Key = 'Version'").fetchone()
    except sqlite3.Error:
        row = None
    if row and re.fullmatch(r'\d+\.\d+\.\d+\.\d+', str(row[0])):
        return str(row[0])
    found = re.search(r'(1\.60\.1\.\d+)', os.path.basename(path))
    if found:
        return found.group(1)
    raise Fail('the export names no build (no _ExtractionMetadata Version, no 1.60.1.NNNNN in its file name)')


def class_mask(raw):
    """The allowable classes as the index keeps them: -1 for any, else the classic class bits; None when no classic class may wear it."""
    if raw is None or raw == 0 or raw == -1:
        return -1
    mask = (int(raw) & 0xFFFFFFFF) & CLASSIC_CLASSES
    if mask == CLASSIC_CLASSES:
        return -1
    return mask or None


def first_flags(text):
    """Word 0 of an ItemSparse Flags value (the export keeps the words as a JSON list)."""
    if text is None:
        return 0
    try:
        words = json.loads(text)
    except (TypeError, ValueError):
        raise Fail('an ItemSparse Flags value is not a JSON list: %r' % (text,))
    if isinstance(words, list):
        return int(words[0]) if words else 0
    return int(words)


def whole(value, what, item):
    if isinstance(value, bool) or not isinstance(value, int):
        raise Fail('item %s: %s is not a whole number: %r' % (item, what, value))
    return value


def read_items(db):
    rows = db.execute(
        'SELECT i.ID, s.Display_lang, i.ClassID, i.SubclassID, i.InventoryType, s.RequiredLevel, s.ItemLevel, s.OverallQualityID, '
        's.AllowableClass, s.Flags FROM Item i JOIN ItemSparse s ON s.ID = i.ID '
        'WHERE i.ClassID IN (2, 4) AND i.InventoryType > 0 ORDER BY i.ID').fetchall()
    kept, left, seen = {}, {r: [] for r in REASONS}, set()
    for item, name, cls, sub, inv, req, ilvl, quality, allowed, flags in rows:
        item = whole(item, 'the ID', item)
        if item in seen:
            raise Fail('item %d is in the export twice' % item)
        seen.add(item)
        name = name if isinstance(name, str) else ''
        if not name.strip():
            left['no name'].append(item)
            continue
        if MARKS.search(name) or MARKS_CASED.search(name):
            left['a test or placeholder name'].append(item)
            continue
        if first_flags(flags) & ITEM_FLAG_DEPRECATED:
            left['the client\'s deprecated flag'].append(item)
            continue
        quality = whole(quality, 'the quality', item)
        if not 0 <= quality <= 5:
            left['quality not 0 to 5'].append(item)
            continue
        req = whole(req, 'the required level', item)
        if req > MAX_LEVEL:
            left['required level over 60'].append(item)
            continue
        mask = class_mask(allowed)
        if mask is None:
            left['no classic class allowed'].append(item)
            continue
        if name != name.strip() or re.search(r'[\t\r\n]', name) or ']=]' in name:
            raise Fail('item %d: the name %r has a tab, a line break, "]=]" or blanks at an end' % (item, name))
        inv = whole(inv, 'the inventory type', item)
        if inv not in INVTYPES:
            raise Fail('item %d (%s): inventory type %d is not one of INVTYPES' % (item, name, inv))
        record = (item, name, whole(cls, 'the class', item), whole(sub, 'the subclass', item), req,
                  whole(ilvl, 'the item level', item), quality, mask)
        if req < 0 or record[5] < 0 or record[3] < 0:
            raise Fail('item %d (%s): a negative subclass, level or item level' % (item, name))
        kept.setdefault(inv, []).append(record)
    return kept, left


def lua_text(build, kept):
    count = sum(len(v) for v in kept.values())
    out = []
    w = out.append
    w('local _, ns = ...\n')
    w('\n')
    w('-- Generated by tools/dev/make_itemindex.py from the client tables of WoW: Forever build %s (Item and ItemSparse), as GrunzForever\n' % build)
    w('-- (github.com/10igma/GrunzForever, a tool under the MIT licence) exported them. Do not edit by hand: run the generator on a new export\n')
    w('-- (its header gives the usage); make_itemindex.py --check says whether this file is what the export makes.\n')
    w('--\n')
    w('-- Game calls, events and frames: none. This file only builds the table of strings below; GearSearch.lua (the item finder, source\n')
    w('-- All items) parses a type\'s string the first time it searches that type, so nothing is split or read at load.\n')
    w('--\n')
    w('-- Every item a player can wear: weapons and armor (item class 2 and 4; the files named below are the game\'s, in\n')
    w('-- Blizzard_APIDocumentationGenerated: ItemConstantsDocumentation.lua:269) with an inventory type, quality 0 to 5\n')
    w('-- (ItemQualitiesDocumentation.lua:6), a name and a required level of 60 or less, leaving out the client\'s test and placeholder items\n')
    w('-- (names with Test, Monster, Deprecated, DEBUG, [PH], DNT, OLD in capitals, QA and the like, and the items the client flags deprecated:\n')
    w('-- ItemSparse flags word 0, 0x10). The names are the client\'s English names, unchanged.\n')
    w('--\n')
    types = 'DATA: one string an inventory type, keyed by the client\'s Item.InventoryType (ItemConstantsDocumentation.lua:182): %s.' % (
        ', '.join('%d %s' % (k, INVTYPES[k]) for k in sorted(kept)))
    for line in textwrap.wrap(types, 137):
        w('-- %s\n' % line)
    w('-- A string holds one record a line, each ending with "\\n", in item ID order; the fields, separated by tabs, are those of FIELDS:\n')
    w('--   id: the item ID; name: the English name (no tab, line break or "]=]"); class: the item class ID (2 weapon, 4 armor); subclass: the\n')
    w('--   subclass ID (armor, ItemConstantsDocumentation.lua:227: 0 generic, 1 cloth, 2 leather, 3 mail, 4 plate, 5 cosmetic, 6 shield, 7 libram,\n')
    w('--   8 idol, 9 totem; weapon, ItemConstantsDocumentation.lua:618: 0 one-handed axe, 1 two-handed axe, 2 bow, 3 gun, 4 one-handed mace,\n')
    w('--   5 two-handed mace, 6 polearm, 7 one-handed sword, 8 two-handed sword, 10 staff, 13 fist weapon, 14 miscellaneous, 15 dagger,\n')
    w('--   16 thrown, 18 crossbow, 19 wand, 20 fishing pole); req: the required level (0 for none); ilvl: the item level; quality: the\n')
    w('--   OverallQualityID (0 poor to 5 legendary); classes: the classes that may wear it, -1 for any, else bit (classID - 1) of each\n')
    w('--   (1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue, 5 Priest, 7 Shaman, 8 Mage, 9 Warlock, 11 Druid).\n')
    w('-- The levels and qualities are those of the client tables of this build; a hotfix the server sends later can differ from them.\n')
    w('ns.ItemIndex = {\n')
    w('\tBUILD = "%s",\n' % build)
    w('\tCOUNT = %d,\n' % count)
    w('\tFIELDS = "%s",\n' % '\\t'.join(FIELDS))
    w('\tDATA = {\n')
    for inv in sorted(kept):
        w('\t\t[%d] = [=[\n' % inv)
        for record in kept[inv]:
            w('\t'.join(str(x) for x in record) + '\n')
        w(']=],\n')
    w('\t},\n')
    w('}\n')
    return ''.join(out), count


def read_back(text, kept, count):
    """Reads the strings back as Lua reads a long string (the line break after [=[ dropped) and checks each holds its records."""
    blocks = re.findall(r'\t\t\[(\d+)\] = \[=\[\n(.*?)\]=\]', text, re.S)
    if [int(k) for k, _ in blocks] != sorted(kept):
        raise Fail('the strings read back are not one an inventory type')
    total = 0
    for key, body in blocks:
        lines = body.split('\n')
        if lines[-1] != '':
            raise Fail('the string of type %s does not end with a line break' % key)
        records = [tuple(line.split('\t')) for line in lines[:-1]]
        made = [tuple(str(x) for x in r) for r in kept[int(key)]]
        if records != made or any(len(r) != len(FIELDS) for r in records):
            raise Fail('the string of type %s does not read back as its records' % key)
        total += len(records)
    if total != count:
        raise Fail('%d records read back, COUNT is %d' % (total, count))


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
    args = [a for a in sys.argv[1:] if a != '--check']
    check_only = len(args) != len(sys.argv) - 1
    if len(args) != 1:
        print(__doc__.split('\n\n')[1])
        return 2
    path = args[0]
    if not os.path.isfile(path):
        print('FAILED: no export at %s' % path)
        return 1
    db = sqlite3.connect('file:%s?mode=ro' % path, uri=True)
    try:
        build = export_build(db, path)
        kept, left = read_items(db)
        text, count = lua_text(build, kept)
        text = strip_lua.strip(text)
        read_back(text, kept, count)
        size = len(text.encode('utf-8'))
        if size >= MAX_BYTES:
            raise Fail('the file would be %d bytes, %d or more' % (size, MAX_BYTES))
    except Fail as err:
        print('FAILED: %s; nothing written.' % err)
        return 1
    finally:
        db.close()
    print('ItemIndex.lua: build %s, %d items in %d inventory types; %d bytes' % (build, count, len(kept), size))
    print('by type: ' + ', '.join('%d %s %d' % (k, INVTYPES[k], len(kept[k])) for k in sorted(kept)))
    for reason in REASONS:
        ids = left[reason]
        print('left out, %s: %d%s' % (reason, len(ids), (' (%s)' % ', '.join(str(i) for i in ids)) if 0 < len(ids) <= 40 else ''))
    current = None
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8', newline='') as handle:
            current = handle.read()
    if check_only:
        if current != text:
            print('FAILED: %s is not what this export makes; run without --check to write it.' % os.path.relpath(OUT, ROOT))
            return 1
        print('--check: every check passed and %s is current; nothing written.' % os.path.relpath(OUT, ROOT))
        return 0
    if current == text:
        print('%s is current; nothing to write.' % os.path.relpath(OUT, ROOT))
    else:
        with open(OUT, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(text)
        print('wrote %s' % os.path.relpath(OUT, ROOT))
    return 1 if run_checks(OUT) else 0


if __name__ == '__main__':
    sys.exit(main())
