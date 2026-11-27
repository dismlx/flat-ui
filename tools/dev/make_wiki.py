import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ADDON = os.path.join(ROOT, 'FlatUI')
OUT = os.path.join(ROOT, 'wiki')
USAGE = 'Usage: python3 tools/dev/make_wiki.py [--check]'
PREFIX = 'Settings-'
FOOTER = '_Footer.md'
REPO = 'https://github.com/dismlx/flat-ui'
MAX_CHOICES = 12

GUIDES = {
    'Look': [('Look', 'Look')],
    'Frames and bars': [('Frames and bars', 'Frames-and-bars'), ('Nameplates', 'Nameplates')],
    'Action bars': [('Action bars', 'Action-bars')],
    'Combat': [('Combat', 'Combat'), ('Combat text', 'Combat-text')],
    'Group': [('Group', 'Group')],
    'Character and gear': [('Character and gear', 'Character-and-gear')],
    'HUD': [('HUD', 'HUD')],
    'Chat and windows': [('Chat and windows', 'Chat-and-windows')],
    'Bags and items': [('Bags and items', 'Bags-and-items')],
    'Helpers': [('Helpers', 'Helpers')],
    'Layout': [('Layout', 'Layout')],
}

DUMP = r'''
local ns = {}
assert(loadfile(arg[1]))("FlatUI", ns)
local function esc(s)
	return (tostring(s):gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end))
end
local function val(v)
	local t = type(v)
	if t == "string" then
		return '"' .. esc(v) .. '"'
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "null"
		end
		return string.format("%.10g", v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		local parts = {}
		for _, x in ipairs(v) do
			parts[#parts + 1] = val(x)
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	return "null"
end
local FIELDS = { "key", "kind", "label", "default", "tip", "needs", "unit", "reload", "cvar" }
local out = {}
for _, page in ipairs(ns.PAGES) do
	local head = {}
	for _, k in ipairs({ "key", "label", "parent" }) do
		if type(page[k]) == "string" then
			head[#head + 1] = '"' .. k .. '":' .. val(page[k])
		end
	end
	local rows = {}
	for _, row in ipairs(page) do
		if type(row) == "table" then
			local r = {}
			if type(row.section) == "string" then
				r[#r + 1] = '"section":' .. val(row.section)
			end
			if row.hidden then
				r[#r + 1] = '"hidden":true'
			end
			for _, k in ipairs(FIELDS) do
				local v = row[k]
				if v ~= nil and type(v) ~= "function" and type(v) ~= "table" then
					r[#r + 1] = '"' .. k .. '":' .. val(v)
				end
			end
			if type(row.needsIn) == "table" then
				r[#r + 1] = '"needsIn":' .. val(row.needsIn)
			end
			if type(row.choices) == "table" then
				local cs = {}
				for _, c in ipairs(row.choices) do
					if type(c) == "table" and c[1] ~= nil then
						cs[#cs + 1] = "[" .. val(c[1]) .. "," .. val(c[2] or c[1]) .. "]"
					end
				end
				r[#r + 1] = '"choices":[' .. table.concat(cs, ",") .. "]"
			end
			rows[#rows + 1] = "{" .. table.concat(r, ",") .. "}"
		end
	end
	head[#head + 1] = '"rows":[' .. table.concat(rows, ",") .. "]"
	out[#out + 1] = "{" .. table.concat(head, ",") .. "}"
end
io.write("[" .. table.concat(out, ",\n") .. "]\n")
'''


class Fail(Exception):
    pass


def read(path):
    if not os.path.isfile(path):
        raise Fail('no file at %s' % path)
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def lua():
    for name in ('lua5.4', 'lua'):
        found = shutil.which(name)
        if found:
            return found
    raise Fail('needs Lua 5.4 (lua5.4 on the path)')


def load_pages():
    config = os.path.join(ADDON, 'Config.lua')
    read(config)
    done = subprocess.run([lua(), '-', config], input=DUMP, capture_output=True, text=True)
    if done.returncode != 0:
        raise Fail('Config.lua did not load: %s' % done.stderr.strip())
    return json.loads(done.stdout)


def load_version():
    found = re.search(r'^## Version:\s*(\S+)', read(os.path.join(ADDON, 'FlatUI.toc')), re.M)
    if not found:
        raise Fail('no version in FlatUI.toc')
    return found.group(1)


def load_groups():
    source = read(os.path.join(ADDON, 'PanelNav.lua'))
    block = re.search(r'Nav\.GROUPS = \{(.*?)\n\}', source, re.S)
    if not block:
        raise Fail('no Nav.GROUPS in PanelNav.lua')
    groups = []
    for line in re.findall(r'\{\s*label = "([^"]+)",([^}]*)\}', block.group(1)):
        groups.append((line[0], re.findall(r'"(\w+)"', line[1])))
    if not groups:
        raise Fail('Nav.GROUPS lists no groups')
    return groups


def load_tabs():
    source = read(os.path.join(ADDON, 'PanelTabs.lua'))

    def table(name):
        found = re.search(r'local ' + name + r' = \{(.*?)\}', source, re.S)
        return dict(re.findall(r'(\w+) = "([^"]+)"', found.group(1))) if found else {}

    return table('FRAME_LABEL'), table('NAMES')


def clean(text):
    text = str(text)
    text = re.sub(r'\|c[0-9a-fA-F]{8}', '', text)
    text = text.replace('|r', '').replace('|n', ' ').replace('||', '|')
    text = re.sub(r'\s+', ' ', text).strip()
    text = text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    return text.replace('|', '\\|')


def number(value):
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def choice_label(row, value):
    for pair in row.get('choices') or []:
        if str(pair[0]) == str(value):
            return clean(pair[1])
    return None


def show_default(row):
    kind, value = row.get('kind'), row.get('default')
    if value is None or kind == 'list':
        return ''
    if kind == 'bool':
        return 'On' if value else 'Off'
    if kind == 'choice':
        label = choice_label(row, value)
        return label if label is not None else '`%s`' % clean(value)
    if kind == 'colour' and isinstance(value, str) and re.fullmatch(r'[0-9a-fA-F]{8}', value):
        alpha = int(value[:2], 16)
        shown = '#' + value[2:].upper()
        return shown if alpha == 255 else '%s at %d%%' % (shown, round(alpha * 100 / 255))
    if kind == 'number' and isinstance(value, (int, float)):
        return clean(number(value) + (row.get('unit') or ''))
    if kind == 'text':
        return '`%s`' % clean(value) if value != '' else 'Empty'
    return clean(value)


def notes(row, rows_by_key):
    parts = []
    if row.get('tip'):
        tip = clean(row['tip'])
        parts.append(tip if tip.endswith(('.', '!', '?', ')')) else tip + '.')
    if row.get('kind') == 'choice' and row.get('choices'):
        names = [clean(c[1]) for c in row['choices']]
        if len(names) > MAX_CHOICES:
            names = names[:MAX_CHOICES] + ['and %d more' % (len(names) - MAX_CHOICES)]
        parts.append('Choices: %s.' % ', '.join(names))
    needed = rows_by_key.get(row.get('needs') or '')
    if needed is not None and needed.get('label'):
        name = '**%s**' % clean(needed['label'])
        wanted = [choice_label(needed, v) or clean(v) for v in row.get('needsIn') or []]
        if wanted:
            parts.append('Needs %s at %s.' % (name, ' or '.join(wanted)))
        elif needed.get('kind') == 'bool':
            parts.append('Needs %s on.' % name)
        else:
            parts.append('Needs %s.' % name)
    reload = row.get('reload')
    if reload == 'off':
        parts.append('Turning it off takes full effect after a reload.')
    elif reload == 'on':
        parts.append('Turning it on takes full effect after a reload.')
    elif reload:
        parts.append('A change takes full effect after a reload.')
    if row.get('cvar'):
        parts.append("Sets the game's `%s`." % row['cvar'])
    return ' '.join(parts)


def rows_block(page):
    lines, section, rows_by_key = [], None, {}
    for row in page['rows']:
        if row.get('key'):
            rows_by_key[row['key']] = row
    table_open = False
    for row in page['rows']:
        if 'section' in row and not row.get('key'):
            section = row['section']
            if table_open:
                lines.append('')
                table_open = False
            if section:
                lines.append('**%s**' % clean(section))
                lines.append('')
            continue
        if not row.get('key') or row.get('hidden') or not row.get('label'):
            continue
        if not table_open:
            lines.append('| Setting | Default | Notes |')
            lines.append('| --- | --- | --- |')
            table_open = True
        lines.append('| **%s** | %s | %s |' % (clean(row['label']), show_default(row), notes(row, rows_by_key)))
    if table_open:
        lines.append('')
    while lines and lines[-1] == '':
        lines.pop()
    return lines


def count(page):
    return sum(1 for r in page['rows'] if r.get('key') and not r.get('hidden') and r.get('label'))


def children_of(pages, top):
    by_key = {p['key']: p for p in pages}

    def top_of(page):
        for _ in range(8):
            up = by_key.get(page.get('parent') or '')
            if not up or up is page:
                break
            page = up
        return page

    return [p for p in pages if p is not top and top_of(p) is top]


def page_block(pages, page, frame_label, names):
    lines = ['## %s' % clean(page['label']), '']
    children = children_of(pages, page)
    if not children:
        body = rows_block(page)
        return lines + (body if body else ['Nothing to set on this page.'])
    own = rows_block(page)
    if own:
        lines += ['### General', ''] + own + ['']
    frames_open = False
    for child in children:
        if count(child) == 0:
            continue
        if child['key'] in frame_label:
            if not frames_open:
                lines += ['### Per frame', '']
                frames_open = True
            lines += ['#### %s' % clean(frame_label[child['key']]), ''] + rows_block(child) + ['']
        else:
            lines += ['### %s' % clean(names.get(child['key'], child['label'])), ''] + rows_block(child) + ['']
    while lines and lines[-1] == '':
        lines.pop()
    return lines


def slug(label):
    return PREFIX + re.sub(r'[^A-Za-z0-9]+', '-', label).strip('-')


def anchor(label):
    return re.sub(r'[^a-z0-9 -]', '', label.lower()).replace(' ', '-')


def group_page(version, label, keys, pages, frame_label, names):
    by_key = {p['key']: p for p in pages}
    present = [by_key[k] for k in keys if k in by_key]
    guides = GUIDES.get(label, [])
    total = sum(count(p) + sum(count(c) for c in children_of(pages, p)) for p in present)
    lines = []
    head = 'Every setting of the **%s** group of the options window, %d in all, with its default in a new profile, which is how **Jon Default** has it.' % (label, total)
    if guides:
        head += ' The guide is %s.' % ' and '.join('[%s](%s)' % g for g in guides)
    lines += [head, '']
    lines += ['Pages: ' + ' · '.join('[%s](#%s)' % (clean(p['label']), anchor(p['label'])) for p in present), '']
    lines += ['Made by `tools/dev/make_wiki.py` from Flat UI %s.' % version, '']
    for page in present:
        lines += page_block(pages, page, frame_label, names) + ['']
    while lines and lines[-1] == '':
        lines.pop()
    return '\n'.join(lines) + '\n'


def build():
    version, pages, groups = load_version(), load_pages(), load_groups()
    frame_label, names = load_tabs()
    files = {}
    for label, keys in groups:
        files[slug(label) + '.md'] = group_page(version, label, keys, pages, frame_label, names)
    files[FOOTER] = ('Flat UI %s for WoW: Forever · [Download](%s/releases/latest) · [Changelog](%s/blob/main/CHANGELOG.md)'
                     ' · [Source and licence](%s)\n') % (version, REPO, REPO, REPO)
    return files


def main(argv):
    check = False
    for word in argv:
        if word == '--check':
            check = True
        else:
            print(USAGE)
            return 2
    try:
        files = build()
    except Fail as error:
        print('make_wiki: %s' % error)
        return 1
    old = set(n for n in os.listdir(OUT) if n.startswith(PREFIX) and n.endswith('.md')) if os.path.isdir(OUT) else set()
    stale = sorted(old - set(files))
    changed = []
    for name, text in sorted(files.items()):
        path = os.path.join(OUT, name)
        current = read(path) if os.path.isfile(path) else None
        if current != text:
            changed.append(name)
    if check:
        for name in changed:
            print('make_wiki: %s is not what the options make' % name)
        for name in stale:
            print('make_wiki: %s is made by nothing' % name)
        if changed or stale:
            return 1
        print('make_wiki: the made pages match the options (%d files)' % len(files))
        return 0
    os.makedirs(OUT, exist_ok=True)
    for name in changed:
        with open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(files[name])
    for name in stale:
        os.remove(os.path.join(OUT, name))
    print('make_wiki: wrote %d of %d made pages, removed %d' % (len(changed), len(files), len(stale)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
