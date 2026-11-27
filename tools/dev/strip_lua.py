import re, sys

def strip(src):
    out = []
    i, n = 0, len(src)
    def long_close(j):
        m = re.match(r'\[(=*)\[', src[j:])
        return m
    while i < n:
        c = src[i]
        if c == '-' and src.startswith('--', i):
            m = long_close(i + 2)
            if m:
                close = ']' + m.group(1) + ']'
                end = src.find(close, i + 2 + len(m.group(0)))
                if end < 0:
                    raise ValueError('unclosed long comment at %d' % i)
                body = src[i:end + len(close)]
                out.append(' ' + '\n' * body.count('\n'))
                i = end + len(close)
            else:
                end = src.find('\n', i)
                if end < 0:
                    end = n
                i = end
            continue
        if c == '[':
            m = long_close(i)
            if m:
                close = ']' + m.group(1) + ']'
                end = src.find(close, i + len(m.group(0)))
                if end < 0:
                    raise ValueError('unclosed long string at %d' % i)
                out.append(src[i:end + len(close)])
                i = end + len(close)
                continue
        if c == '"' or c == "'":
            j = i + 1
            while j < n:
                d = src[j]
                if d == '\\':
                    j += 2
                    continue
                if d == c:
                    break
                if d == '\n':
                    raise ValueError('unfinished string at %d' % i)
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
            continue
        out.append(c)
        i += 1
    text = ''.join(out)
    orig_lines = src.split('\n')
    new_lines = text.split('\n')
    assert len(orig_lines) == len(new_lines)
    kept = []
    for o, l in zip(orig_lines, new_lines):
        r = l.rstrip()
        if r.strip() == '' and o.strip() != '':
            continue
        kept.append(r)
    res = []
    for l in kept:
        if l == '' and (not res or res[-1] == ''):
            continue
        res.append(l)
    while res and res[-1] == '':
        res.pop()
    return '\n'.join(res) + '\n'

if __name__ == '__main__':
    for p in sys.argv[1:]:
        src = open(p, encoding='utf-8').read()
        new = strip(src)
        if new != src:
            open(p, 'w', encoding='utf-8').write(new)
