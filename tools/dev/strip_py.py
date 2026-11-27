import ast
import io
import sys
import tokenize


def docstring_lines(tree):
    spans = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = node.body
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                spans.append((body[0].lineno, body[0].end_lineno, len(body) == 1, body[0].col_offset))
    return spans


def strip(src):
    lines = src.split('\n')
    cut = {}
    for tok in tokenize.generate_tokens(io.StringIO(src).readline):
        if tok.type == tokenize.COMMENT:
            row, col = tok.start
            if row == 1 and tok.string.startswith('#!'):
                continue
            cut[row - 1] = min(cut.get(row - 1, len(lines[row - 1])), col)
    drop = set()
    replace = {}
    for start, end, alone, col in docstring_lines(ast.parse(src)):
        for r in range(start - 1, end):
            drop.add(r)
        if alone:
            replace[start - 1] = ' ' * col + 'pass'
    out = []
    for i, line in enumerate(lines):
        if i in replace:
            out.append(replace[i])
            continue
        if i in drop:
            continue
        if i in cut:
            kept = line[:cut[i]].rstrip()
            if kept.strip() == '':
                continue
            out.append(kept)
            continue
        out.append(line.rstrip())
    res = []
    for line in out:
        if line == '' and len(res) >= 2 and res[-1] == '' and res[-2] == '':
            continue
        res.append(line)
    while res and res[-1] == '':
        res.pop()
    return '\n'.join(res) + '\n'


def without_docstrings(tree):
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = node.body
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str):
                node.body = body[1:] or [ast.Pass()]
    return ast.dump(tree, include_attributes=False)


if __name__ == '__main__':
    bad = 0
    for path in sys.argv[1:]:
        src = open(path, encoding='utf-8').read()
        new = strip(src)
        if without_docstrings(ast.parse(src)) != without_docstrings(ast.parse(new)):
            print('DIFFERS', path)
            bad = 1
            continue
        if new != src:
            open(path, 'w', encoding='utf-8', newline='\n').write(new)
    sys.exit(bad)
