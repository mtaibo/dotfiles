"""Second pass after clang-format on C files, for the layout rules
clang-format can't express. Reads the file on stdin, writes it to stdout.

- Includes, #defines and typedefs are hoisted to the top of the file (not out
  of #if blocks), each group a blank line apart:
  - includes from the shortest line to the longest;
  - #defines in their original order;
  - one-line typedefs in their original order;
  - multi-line typedefs and struct/union/enum definitions from the longest to
    the shortest, a blank line between each, always after the types they use.
- One blank line between top-level blocks, three around main.
"""
import re
import sys

IDENT = re.compile(r"[A-Za-z_]\w*")


def scan(lines):
    """Per line: whether it starts inside a block comment, its brace depth at
    the end, and its code with comments and string contents removed."""
    depth, in_comment, pp_cont = 0, False, False
    out = []
    for line in lines:
        starts_in_comment = in_comment
        is_pp = pp_cont or (not in_comment and line.lstrip().startswith("#"))
        pp_cont = is_pp and line.endswith("\\")
        code, quote, i = [], None, 0
        while i < len(line):
            c = line[i]
            if in_comment:
                if line.startswith("*/", i):
                    in_comment = False
                    i += 1
            elif quote:
                if c == "\\":
                    i += 1
                elif c == quote:
                    quote = None
                    code.append(c)
            elif line.startswith("/*", i):
                in_comment = True
                i += 1
            elif line.startswith("//", i):
                break
            else:
                code.append(c)
                if c in "\"'":
                    quote = c
                elif not is_pp and c == "{":
                    depth += 1
                elif not is_pp and c == "}":
                    depth -= 1
            i += 1
        out.append((starts_in_comment, max(depth, 0), "".join(code)))
    return out


class Unit:
    def __init__(self, kind, lines, code):
        self.kind = kind      # blank, comment, pp or code
        self.lines = lines
        self.code = code      # code without comments, lines joined by \n
        self.comments = []    # comment units right above it
        self.directive = ""
        if kind == "pp":
            m = re.match(r"\s*#\s*(\w+)", lines[0])
            self.directive = m.group(1) if m else ""


def split_units(lines):
    info = scan(lines)
    units, i, n = [], 0, len(lines)
    while i < n:
        in_comment, _, code = info[i]
        stripped = lines[i].strip()
        if not in_comment and not stripped:
            units.append(Unit("blank", [lines[i]], ""))
            i += 1
        elif not in_comment and stripped.startswith("#"):
            j = i
            while lines[j].endswith("\\") and j + 1 < n:
                j += 1
            units.append(Unit("pp", lines[i:j + 1], ""))
            i = j + 1
        elif in_comment or not code.strip():
            j = i
            while j < n and lines[j].strip() and (
                    info[j][0] or not info[j][2].strip()):
                j += 1
            units.append(Unit("comment", lines[i:j], ""))
            i = j
        else:
            j = i
            while j + 1 < n:
                _, depth, code = info[j]
                if depth == 0 and not info[j + 1][0] and \
                        code.rstrip().endswith((";", "}")):
                    break
                j += 1
            units.append(Unit("code", lines[i:j + 1],
                              "\n".join(c for _, _, c in info[i:j + 1])))
            i = j + 1
    return units


def outer(code):
    """The code outside braces (what's left of a struct when its body goes)."""
    out, depth = [], 0
    for c in code:
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        elif depth == 0:
            out.append(c)
    return "".join(out)


def is_typedef(u):
    return u.kind == "code" and re.match(r"\s*typedef\b", u.code)


def is_record(u):
    """A plain struct/union/enum definition, without a variable."""
    return (u.kind == "code"
            and re.match(r"\s*(struct|union|enum)\b[^;(=]*\{", u.code)
            and u.code[u.code.rindex("}") + 1:].strip() == ";")


def is_function(u):
    if u.kind != "code" or "{" not in u.code or is_typedef(u) or is_record(u):
        return False
    last = u.code.rstrip().splitlines()[-1].strip()
    return "(" in u.code[:u.code.index("{")] and last.startswith("}") \
        and not last.endswith(";")


def is_main(u):
    return is_function(u) and re.search(r"\bmain\s*\(",
                                        u.code[:u.code.index("{")])


def names(u):
    """The names a typedef or definition introduces."""
    found = set()
    m = re.match(r"\s*(?:typedef\s+)?(?:struct|union|enum)\s+([A-Za-z_]\w*)",
                 u.code)
    if m:
        found.add(m.group(1))
    if re.match(r"\s*(?:typedef\s+)?enum\b", u.code) and "{" in u.code:
        body = u.code[u.code.index("{") + 1:u.code.rindex("}")]
        found |= set(re.findall(r"(?:^|,)\s*([A-Za-z_]\w*)", body))
    if is_typedef(u):
        rest = outer(u.code)
        if "{" in u.code:
            rest = u.code[u.code.rindex("}") + 1:]
        pointers = re.findall(r"\(\s*\*\s*([A-Za-z_]\w*)", rest)
        if pointers:
            found |= set(pointers)
        else:
            for decl in re.sub(r"\[[^\]]*\]", "", rest).rstrip(" ;\n").split(","):
                idents = IDENT.findall(decl)
                if idents:
                    found.add(idents[-1])
    return found


def sort_types(singles, multis):
    """One-liners first; then the rest longest first, each after what it uses.
    A one-liner that needs a multi-line type goes down with them."""
    items = singles + multis
    own = {id(u): names(u) for u in items}
    uses = {id(u): set(IDENT.findall(u.code)) - own[id(u)] for u in items}

    def deps(u, pool):
        return [v for v in pool if v is not u and own[id(v)] & uses[id(u)]]

    down = list(multis)
    changed = True
    while changed:
        changed = False
        for u in singles:
            if u not in down and deps(u, down):
                down.append(u)
                changed = True
    top = [u for u in singles if u not in down]
    order = {id(u): k for k, u in enumerate(items)}
    placed, left = [], sorted(down, key=lambda u: order[id(u)])
    while left:
        ready = [u for u in left if not deps(u, left)] or left[:1]
        pick = max(ready, key=lambda u: (len(u.lines), -order[id(u)]))
        placed.append(pick)
        left.remove(pick)
    return top, placed


def lines_of(u):
    return [l for c in u.comments for l in c.lines] + u.lines


def format_c(text):
    units = split_units(text.split("\n"))

    # Comments directly above a unit travel with it.
    merged = []
    for u in units:
        if u.kind != "blank" and u.kind != "comment" and merged \
                and merged[-1].kind == "comment":
            u.comments = [merged.pop()]
        merged.append(u)
    units = merged

    header, guard = [], []
    k = 0
    while k < len(units) and units[k].kind in ("comment", "blank"):
        if units[k].kind == "comment":
            header.append(units[k])
        k += 1
    if k < len(units) and units[k].kind == "pp":
        u = units[k]
        if u.directive == "pragma" and "once" in u.lines[0]:
            guard, k = [u], k + 1
        elif u.directive == "ifndef" and k + 1 < len(units):
            v = units[k + 1]
            name = u.lines[0].split()[-1]
            if v.kind == "pp" and v.directive == "define" \
                    and v.lines[0].split()[1:2] == [name]:
                guard, k = [u, v], k + 2

    includes, defines, singles, multis = [], [], [], []
    rest = []  # (unit, blank line before it)
    cond, undef, blank = 0, False, False
    for u in units[k:]:
        if u.kind == "blank":
            blank = True
            continue
        hoist = cond == 0
        if u.kind == "pp":
            if u.directive in ("if", "ifdef", "ifndef"):
                cond += 1
            elif u.directive == "endif":
                cond -= 1
            elif u.directive == "undef":
                undef = True
            if hoist and not undef and u.directive == "include":
                includes.append(u)
            elif hoist and not undef and u.directive == "define":
                defines.append(u)
            else:
                rest.append((u, blank))
        elif hoist and is_typedef(u) and len(u.lines) == 1:
            singles.append(u)
        elif hoist and (is_typedef(u) or is_record(u)):
            multis.append(u)
        else:
            rest.append((u, blank))
        blank = False

    def key(u):
        line = u.lines[0].split("//")[0].split("/*")[0].rstrip()
        return (len(line), line)

    top, placed = sort_types(singles, multis)
    blocks = [[l for u in header for l in u.lines],
              [l for u in guard for l in lines_of(u)],
              [l for u in sorted(includes, key=key) for l in lines_of(u)],
              [l for u in defines for l in lines_of(u)],
              [l for u in top for l in lines_of(u)]]
    blocks += [lines_of(u) for u in placed]
    chunks = [(b, False) for b in blocks if b]
    preamble = len(chunks)

    # The rest, in blank-separated chunks.
    for u, blank_before in rest:
        if blank_before or len(chunks) == preamble:
            chunks.append(([], False))
        lines, has_main = chunks[-1]
        chunks[-1] = (lines + lines_of(u), has_main or bool(is_main(u)))

    out = []
    for n, (lines, has_main) in enumerate(chunks):
        if n:
            out += [""] * (3 if has_main or chunks[n - 1][1] else 1)
        out += lines
    return "\n".join(out).rstrip("\n") + "\n"


if __name__ == "__main__":
    sys.stdout.write(format_c(sys.stdin.read()))
