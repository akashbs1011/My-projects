#!/usr/bin/env python3
"""
Static verification for the Flutter/Dart source tree.

The `flutter` and `dart` binaries are not available in this environment, so
this cannot replace `flutter analyze`. What it does check, by parsing the
source directly:

  1. Every import resolves to a file that exists.
  2. Every project-defined class a file references is reachable from that
     file's imports (this is the check that catches a forgotten import,
     which is the most common way a Dart build breaks).
  3. Every localisation key passed to t()/tf() exists in the English table.
  4. Every route constant referenced is declared.

Exit code is non-zero if anything fails.
"""
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(ROOT, "lib")
TEST = os.path.join(ROOT, "test")
PACKAGE = "clinical_ai"

failures = []
warnings = []


def dart_files(*roots):
    for root in roots:
        for dirpath, _, filenames in os.walk(root):
            for name in filenames:
                if name.endswith(".dart"):
                    yield os.path.join(dirpath, name)


files = sorted(dart_files(LIB, TEST))
print(f"Scanning {len(files)} Dart files\n")

IMPORT_RE = re.compile(r"""^\s*import\s+['"]([^'"]+)['"]""", re.M)
DECL_RE = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)*"
    r"(?:class|mixin|enum|extension|typedef)\s+([A-Z]\w*)",
    re.M,
)
TOPLEVEL_CONST_RE = re.compile(r"^const\s+[\w<>,\s]+?\s+(\w+)\s*=", re.M)
FUNC_RE = re.compile(r"^(?:Future<[^>]*>|void|[A-Z]\w*|\w+)\s+(\w+)\s*\(", re.M)

sources = {}
imports = {}
declares = defaultdict(set)

for path in files:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    sources[path] = text
    imports[path] = IMPORT_RE.findall(text)
    for name in DECL_RE.findall(text):
        declares[path].add(name)
    for name in TOPLEVEL_CONST_RE.findall(text):
        declares[path].add(name)

# Map of every class/enum/const the project declares -> the file declaring it.
owner = {}
for path, names in declares.items():
    for name in names:
        owner.setdefault(name, path)


# ---------------------------------------------------------------- 1. imports
def resolve(path, spec):
    """Return the absolute path an import refers to, or None if external."""
    if spec.startswith("dart:"):
        return None
    if spec.startswith(f"package:{PACKAGE}/"):
        return os.path.join(LIB, spec[len(f"package:{PACKAGE}/"):])
    if spec.startswith("package:"):
        return None  # third-party, resolved by pub
    return os.path.normpath(os.path.join(os.path.dirname(path), spec))


print("[1] Import resolution")
unresolved = 0
for path in files:
    for spec in imports[path]:
        target = resolve(path, spec)
        if target is None:
            continue
        if not os.path.isfile(target):
            failures.append(
                f"{os.path.relpath(path, ROOT)} imports '{spec}' -> missing file"
            )
            unresolved += 1
if unresolved == 0:
    print(f"    OK  every local import resolves ({sum(len(v) for v in imports.values())} imports checked)")
else:
    print(f"    FAIL {unresolved} unresolved import(s)")

# ------------------------------------------------- 2. symbol reachability
print("\n[2] Project symbols reachable from imports")
missing_symbols = 0
IDENT_RE = re.compile(r"\b([A-Z]\w+)\b")

for path in files:
    text = sources[path]
    # Strip comments and string literals so words inside them are not
    # mistaken for code references.
    stripped = re.sub(r"//.*", "", text)
    stripped = re.sub(r"/\*.*?\*/", "", stripped, flags=re.S)
    stripped = re.sub(r"'''.*?'''", "''", stripped, flags=re.S)
    stripped = re.sub(r'""".*?"""', '""', stripped, flags=re.S)
    stripped = re.sub(r"'(?:[^'\\\n]|\\.)*'", "''", stripped)
    stripped = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', stripped)
    # Drop the import block itself.
    stripped = IMPORT_RE.sub("", stripped)

    reachable = set(declares[path])
    for spec in imports[path]:
        target = resolve(path, spec)
        if target and target in declares:
            reachable |= declares[target]

    for ident in set(IDENT_RE.findall(stripped)):
        if ident not in owner:
            continue  # not a project symbol; Flutter/Dart/third-party
        if ident in reachable:
            continue
        failures.append(
            f"{os.path.relpath(path, ROOT)} uses '{ident}' "
            f"(declared in {os.path.relpath(owner[ident], ROOT)}) without importing it"
        )
        missing_symbols += 1

if missing_symbols == 0:
    print(f"    OK  {len(owner)} project symbols, all references reachable")
else:
    print(f"    FAIL {missing_symbols} unreachable symbol reference(s)")

# ------------------------------------------------- 2b. structural balance
# Import resolution and symbol reachability both pass on a file whose braces
# are unbalanced, because neither parses structure. A regex edit that deleted
# one brace too many therefore slipped through once and only surfaced at
# `flutter run`. This closes that gap.
print("\n[2b] Brace and paren balance")
unbalanced = 0
for path in files:
    t = sources[path]
    t = re.sub(r"//.*", "", t)
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    t = re.sub(r"'''.*?'''", "''", t, flags=re.S)
    t = re.sub(r'""".*?"""', '""', t, flags=re.S)
    t = re.sub(r"'(?:[^'\\\n]|\\.)*'", "''", t)
    t = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', t)
    for opener, closer, label in (("{", "}", "braces"),
                                  ("(", ")", "parens"),
                                  ("[", "]", "brackets")):
        diff = t.count(opener) - t.count(closer)
        if diff != 0:
            failures.append(
                f"{os.path.relpath(path, ROOT)}: {label} unbalanced by {diff:+d}"
            )
            unbalanced += 1
if unbalanced == 0:
    print(f"    OK  {len(files)} files, all delimiters balanced")
else:
    print(f"    FAIL {unbalanced} imbalance(s)")

# ------------------------------------------------- 3. localisation keys
print("\n[3] Localisation keys")
en_path = os.path.join(LIB, "localization", "strings_en.dart")
en_keys = set(re.findall(r"^\s*'([\w]+)':", sources[en_path], re.M))

KEY_USE_RE = re.compile(r"\.t\(\s*'([\w]+)'\s*\)|\.tf\(\s*'([\w]+)'\s*,")
used = set()
for path in files:
    # Only application code. localization_test.dart deliberately looks up a
    # key that does not exist, to prove the fallback returns the key itself
    # rather than blank space - counting it here would be a false positive.
    if not path.startswith(LIB):
        continue
    for a, b in KEY_USE_RE.findall(sources[path]):
        used.add(a or b)

undefined = sorted(k for k in used if k not in en_keys)
if undefined:
    for key in undefined:
        failures.append(f"localisation key '{key}' is used but missing from strings_en.dart")
    print(f"    FAIL {len(undefined)} undefined key(s): {', '.join(undefined)}")
else:
    print(f"    OK  {len(used)} keys used, all defined in the English table")

unused = sorted(en_keys - used)
if unused:
    warnings.append(f"{len(unused)} English keys are defined but never used")
    print(f"    note {len(unused)} defined-but-unused key(s)")

# Per-language coverage.
print("\n    Coverage against the English reference table:")
for code in ["hi", "kn", "te", "ta", "ml"]:
    p = os.path.join(LIB, "localization", f"strings_{code}.dart")
    keys = set(re.findall(r"^\s*'([\w]+)':", sources[p], re.M))
    covered = len(keys & en_keys)
    pct = 100 * covered / len(en_keys)
    gap = sorted(en_keys - keys)
    note = f" (falls back to English: {', '.join(gap)})" if gap else ""
    print(f"      {code}: {covered}/{len(en_keys)} ({pct:.0f}%){note}")

# ------------------------------------------------- 4. route constants
print("\n[4] Route constants")
const_path = os.path.join(LIB, "utils", "constants.dart")
declared_routes = set(re.findall(r"static const String (route\w+)", sources[const_path]))
used_routes = set()
for path in files:
    used_routes |= set(re.findall(r"AppConstants\.(route\w+)", sources[path]))

bad_routes = sorted(used_routes - declared_routes)
if bad_routes:
    for r in bad_routes:
        failures.append(f"AppConstants.{r} is referenced but not declared")
    print(f"    FAIL undeclared: {', '.join(bad_routes)}")
else:
    print(f"    OK  {len(used_routes)} route constants referenced, all declared")

# ------------------------------------------------- 5. structure sanity
print("\n[5] Required structure")
required = [
    "pubspec.yaml",
    "lib/main.dart",
    "lib/app",
    "lib/models",
    "lib/services",
    "lib/providers",
    "lib/screens",
    "lib/widgets",
    "lib/utils",
    "lib/localization",
    "android",
    "ios",
    "test",
]
for item in required:
    full = os.path.join(ROOT, item)
    if os.path.exists(full):
        print(f"    OK  {item}")
    else:
        failures.append(f"required path missing: {item}")
        print(f"    FAIL {item}")

# ------------------------------------------------- summary
print("\n" + "=" * 62)
if failures:
    print(f"FAILED with {len(failures)} problem(s):\n")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print("PASSED - no unresolved imports, unreachable symbols, or undefined keys")
if warnings:
    print("\nNotes:")
    for w in warnings:
        print(f"  - {w}")
sys.exit(0)
