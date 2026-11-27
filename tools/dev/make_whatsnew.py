import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import strip_lua

ROOT = os.path.dirname(os.path.dirname(HERE))
SOURCE = os.path.join(ROOT, 'CHANGELOG.md')
OUT = os.path.join(ROOT, 'FlatUI', 'WhatsNewData.lua')
USAGE = 'Usage: python3 tools/dev/make_whatsnew.py [--check]'
SECTIONS = 6
MAX_BULLETS = 40
MAX_BYTES = 200000
HEADING = re.compile(r'^##\s+(\d+(?:\.\d+)+)\s*$')
BULLET = re.compile(r'^-\s+(.*)$')
SUB = re.compile(r'^\s+[-*]\s+(.*)$')
FOREVER = re.compile(r'^For WoW: Forever .*interface number stays', re.I)
BOLD_ON, BOLD_OFF = '\x01', '\x02'


class Fail(Exception):
    pass


def game_text(text):
    text = re.sub(r'!\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'<(https?://[^>]+)>', r'\1', text)
    text = re.sub(r'`+([^`]*)`+', r'\1', text)
    text = text.replace('`', '')
    text = re.sub(r'\*\*(.+?)\*\*', lambda m: BOLD_ON + m.group(1) + BOLD_OFF, text)
    text = re.sub(r'(?<![\w*])\*(?![\s*])([^*]+?)(?<![\s*])\*(?![\w*])', r'\1', text)
    text = text.replace('**', '')
    text = re.sub(r'\\([\\`*_{}\[\]()#+\-.!|<>])', r'\1', text)
    text = text.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    text = re.sub(r'\s+', ' ', text).strip()
    return text.replace('|', '||')


def read_sections(path):
    if not os.path.isfile(path):
        raise Fail('no changelog at %s' % path)
    with open(path, encoding='utf-8') as handle:
        source = handle.read()
    sections, current, bullet = [], None, None
    for raw in source.split('\n'):
        line = raw.rstrip()
        heading = HEADING.match(line)
        if heading:
            if len(sections) == SECTIONS:
                break
            current = {'version': heading.group(1), 'bullets': []}
            sections.append(current)
            bullet = None
            continue
        if current is None:
            continue
        if line.startswith('#'):
            bullet = None
            continue
        if not line.strip():
            bullet = None
            continue
        sub = SUB.match(line)
        if sub and bullet is not None:
            bullet['subs'].append(sub.group(1))
            continue
        top = BULLET.match(line)
        if top:
            bullet = {'text': top.group(1), 'subs': []}
            current['bullets'].append(bullet)
            continue
        if bullet is not None:
            if bullet['subs']:
                bullet['subs'][-1] += ' ' + line.strip()
            else:
                bullet['text'] += ' ' + line.strip()
            continue
        bullet = {'text': line.strip(), 'subs': []}
        current['bullets'].append(bullet)
    if not sections:
        raise Fail('the changelog has no version heading such as "## 0.5.43"')
    return sections


def section_lines(section):
    lines = []
    for bullet in section['bullets']:
        text = game_text(bullet['text'])
        if FOREVER.match(text):
            continue
        subs = [game_text(sub) for sub in bullet['subs']]
        subs = [sub for sub in subs if sub]
        if subs:
            text = '\n'.join([text] + ['- ' + sub for sub in subs])
        if text:
            lines.append(text)
    if len(lines) > MAX_BULLETS:
        left = len(lines) - MAX_BULLETS
        lines = lines[:MAX_BULLETS]
        lines.append('And %d more %s in the full changelog on CurseForge.' % (left, 'change' if left == 1 else 'changes'))
    return lines


def lua_string(text):
    out = ['"']
    for char in text:
        if char == '\\':
            out.append('\\\\')
        elif char == '"':
            out.append('\\"')
        elif char == '\n':
            out.append('\\n')
        elif char == BOLD_ON:
            out.append('\\001')
        elif char == BOLD_OFF:
            out.append('\\002')
        elif ord(char) < 32 or ord(char) == 127:
            out.append('\\%03d' % ord(char))
        else:
            out.append(char)
    out.append('"')
    return ''.join(out)


def lua_text(sections):
    out = ['local _, ns = ...\n', '\n', 'ns.WhatsNewData = {\n']
    for section in sections:
        out.append('\t{\n')
        out.append('\t\tversion = %s,\n' % lua_string(section['version']))
        lines = section_lines(section)
        if lines:
            out.append('\t\tlines = {\n')
            for line in lines:
                out.append('\t\t\t%s,\n' % lua_string(line))
            out.append('\t\t},\n')
        else:
            out.append('\t\tlines = {},\n')
        out.append('\t},\n')
    out.append('}\n')
    return strip_lua.strip(''.join(out))


def read_back(text, sections):
    versions = re.findall(r'^\t\tversion = "([^"]*)",$', text, re.M)
    if versions != [s['version'] for s in sections]:
        raise Fail('the versions read back are not those of the changelog')
    for marker in ('**', '`', ']('):
        if marker in text:
            raise Fail('markdown "%s" is left in the text' % marker)


def main():
    args = sys.argv[1:]
    check_only = '--check' in args
    if any(arg != '--check' for arg in args):
        print(USAGE)
        return 2
    try:
        sections = read_sections(SOURCE)
        text = lua_text(sections)
        read_back(text, sections)
        size = len(text.encode('utf-8'))
        if size >= MAX_BYTES:
            raise Fail('the file would be %d bytes, %d or more' % (size, MAX_BYTES))
    except Fail as err:
        print('FAILED: %s; nothing written.' % err)
        return 1
    summary = ', '.join('%s %d' % (s['version'], len(section_lines(s))) for s in sections)
    print('WhatsNewData.lua: %d versions (%s); %d bytes' % (len(sections), summary, size))
    current = None
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8', newline='') as handle:
            current = handle.read()
    name = os.path.relpath(OUT, ROOT)
    if check_only:
        if current != text:
            print('FAILED: %s is not what CHANGELOG.md makes; run without --check to write it.' % name)
            return 1
        print('--check: %s is what CHANGELOG.md makes; nothing written.' % name)
        return 0
    if current == text:
        print('%s is current; nothing to write.' % name)
        return 0
    with open(OUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(text)
    print('wrote %s' % name)
    return 0


if __name__ == '__main__':
    sys.exit(main())
