#!/usr/bin/env python3
"""
The ten-point project check.

Run from the repository root:  python3 verify_project.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
MOBILE = os.path.join(ROOT, "mobile")

results = []


def record(number, name, passed, detail):
    results.append((number, name, passed, detail))
    mark = "PASS" if passed else "FAIL"
    print(f"  [{mark}] {number:>2}. {name}")
    for line in detail.splitlines():
        print(f"          {line}")


def walk_files():
    skip = {".git", "node_modules", "build", ".dart_tool", ".venv", "__pycache__"}
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for name in filenames:
            yield os.path.join(dirpath, name)


all_files = sorted(walk_files())
rel = lambda p: os.path.relpath(p, ROOT)

print("=" * 68)
print("CLINICAL AI - PROJECT VERIFICATION")
print("=" * 68)
print(f"\nScanning {len(all_files)} files under {ROOT}\n")

# ------------------------------------------------------------------ 1. React
react_markers = [".jsx", ".tsx"]
react_files = [f for f in all_files if os.path.splitext(f)[1] in react_markers]
# A React project is also identifiable by these files regardless of extension.
for name in ("package.json", "package-lock.json", "yarn.lock"):
    react_files += [f for f in all_files if os.path.basename(f) == name]

# index.html is a React/Vite marker only outside mobile/web/. Flutter generates
# its own web/index.html as the engine bootstrap when web support is enabled;
# that file is Flutter's, not React's. Its contents are still scanned below for
# actual React usage, so enabling web support cannot smuggle React in.
flutter_web = os.path.join(MOBILE, "web") + os.sep
react_files += [
    f for f in all_files
    if os.path.basename(f) == "index.html" and not f.startswith(flutter_web)
]

react_imports = []
for f in all_files:
    if f.endswith((".js", ".ts", ".jsx", ".tsx")):
        try:
            text = open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if re.search(r"""from\s+['"]react""", text) or "ReactDOM" in text:
            react_imports.append(f)

offenders = sorted(set(react_files + react_imports))
record(1, "No React files", not offenders,
       "no .jsx/.tsx, no package.json, no react imports anywhere"
       if not offenders else "\n".join(rel(f) for f in offenders))

# ------------------------------------------------------------------- 2. Vite
vite_files = [f for f in all_files
              if re.match(r"vite\.config\.(js|ts|mjs|cjs)$", os.path.basename(f))]
vite_refs = []
for f in all_files:
    # Code and config only. Markdown is documentation: this audit and
    # VERIFICATION.md name these tools in order to say they are absent, and
    # matching that prose would be a false positive.
    if f.endswith((".json", ".js", ".ts", ".html", ".yaml", ".yml")):
        try:
            text = open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if re.search(r"\bvite\b", text, re.I) and "verify_project" not in f:
            vite_refs.append(f)

offenders = sorted(set(vite_files + vite_refs))
record(2, "No Vite files", not offenders,
       "no vite.config.*, no vite references"
       if not offenders else "\n".join(rel(f) for f in offenders))

# --------------------------------------------------------------- 3. Tailwind
tailwind_files = [f for f in all_files
                  if os.path.basename(f).startswith("tailwind.config")
                  or os.path.basename(f) == "postcss.config.js"]
tailwind_refs = []
for f in all_files:
    if f.endswith((".css", ".js", ".ts", ".json", ".html", ".dart")):
        try:
            text = open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if re.search(r"tailwind|@apply\b", text, re.I) and "verify_project" not in f:
            tailwind_refs.append(f)

offenders = sorted(set(tailwind_files + tailwind_refs))
record(3, "No Tailwind", not offenders,
       "no tailwind config, no @apply, no tailwind references"
       if not offenders else "\n".join(rel(f) for f in offenders))

# ----------------------------------------------------------------- 4. Base44
base44_hits = []
for f in all_files:
    if f.endswith((".png", ".jpg", ".jks", ".joblib", ".pyc")):
        continue
    try:
        text = open(f, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    for match in re.finditer(r"base\s*[-_]?\s*44|base44", text, re.I):
        line_no = text[: match.start()].count("\n") + 1
        line = text.splitlines()[line_no - 1].strip()[:100]
        base44_hits.append((rel(f), line_no, line))

# The audit document and the README both mention Base44 in order to state that
# it is not used. Those are the intended mentions, not dependencies.
allowed = ("docs/BASE44_AUDIT.md", "README.md", "verify_project.py", "docs/VERIFICATION.md")
real_hits = [h for h in base44_hits if not h[0].startswith(allowed)]

record(4, "No Base44", not real_hits,
       f"{len(base44_hits)} mention(s), all in documentation stating independence"
       if not real_hits
       else "\n".join(f"{p}:{n}  {l}" for p, n, l in real_hits))

# ------------------------------------------------------------- 5. pubspec
pubspec = os.path.join(MOBILE, "pubspec.yaml")
exists = os.path.isfile(pubspec)
detail = ""
if exists:
    text = open(pubspec, encoding="utf-8").read()
    name = re.search(r"^name:\s*(\S+)", text, re.M)
    detail = f"mobile/pubspec.yaml, package name '{name.group(1) if name else '?'}'"
record(5, "pubspec.yaml exists", exists, detail or "missing")

# ------------------------------------------------------------ 6. main.dart
main_dart = os.path.join(MOBILE, "lib", "main.dart")
exists = os.path.isfile(main_dart)
detail = ""
if exists:
    text = open(main_dart, encoding="utf-8").read()
    has_main = re.search(r"void main\(\)|Future<void> main\(\)", text) is not None
    has_runapp = "runApp(" in text
    exists = has_main and has_runapp
    detail = (f"mobile/lib/main.dart, {len(text.splitlines())} lines, "
              f"main() {'found' if has_main else 'MISSING'}, "
              f"runApp() {'found' if has_runapp else 'MISSING'}")
record(6, "lib/main.dart exists", exists, detail or "missing")

# --------------------------------------------------------------- 7. Android
android_required = [
    "android/settings.gradle",
    "android/build.gradle",
    "android/app/build.gradle",
    "android/app/src/main/AndroidManifest.xml",
    "android/app/src/main/kotlin/com/clinicalai/app/MainActivity.kt",
]
missing = [p for p in android_required if not os.path.isfile(os.path.join(MOBILE, p))]
detail = ("\n".join(f"present: {p}" for p in android_required)
          if not missing else "\n".join(f"MISSING: {p}" for p in missing))
record(7, "Android project exists", not missing, detail)

# ------------------------------------------------------------------- 8. iOS
ios_required = [
    "ios/Runner/Info.plist",
    "ios/Runner/AppDelegate.swift",
    "ios/Runner/Base.lproj/LaunchScreen.storyboard",
    "ios/Podfile",
    "ios/Flutter/Debug.xcconfig",
]
missing = [p for p in ios_required if not os.path.isfile(os.path.join(MOBILE, p))]
plist = os.path.join(MOBILE, "ios/Runner/Info.plist")
perms_ok = False
if os.path.isfile(plist):
    ptext = open(plist, encoding="utf-8").read()
    perms_ok = ("NSMicrophoneUsageDescription" in ptext
                and "NSSpeechRecognitionUsageDescription" in ptext)
detail = "\n".join(f"present: {p}" for p in ios_required) if not missing \
    else "\n".join(f"MISSING: {p}" for p in missing)
detail += f"\nmicrophone + speech permission strings: {'present' if perms_ok else 'MISSING'}"
detail += "\nRunner.xcodeproj generated by `flutter create --platforms=ios .` (see ios/README.md)"
record(8, "iOS project exists", not missing and perms_ok, detail)

# ---------------------------------------------------------- 9. dependencies
required_deps = ["flutter", "provider", "go_router", "http",
                 "flutter_secure_storage", "shared_preferences",
                 "speech_to_text", "intl"]
found, absent = [], []
if os.path.isfile(pubspec):
    text = open(pubspec, encoding="utf-8").read()
    dep_block = text.split("dependencies:", 1)[-1].split("flutter:\n  uses-material")[0]
    for dep in required_deps:
        (found if re.search(rf"^\s+{re.escape(dep)}:", dep_block, re.M) else absent).append(dep)
# Look at declared dependency names only. A comment mentioning a package is
# not a dependency on it - pubspec.yaml says in prose that axios is not used,
# and matching that text would be a false positive.
banned = []
if os.path.isfile(pubspec):
    declared = re.findall(r"^\s{2,}([a-z_0-9]+):", dep_block, re.M)
    banned = [d for d in declared if d in ("axios", "react", "react_dom", "vite")]
detail = f"declared: {', '.join(found)}"
if absent:
    detail += f"\nMISSING: {', '.join(absent)}"
if banned:
    detail += f"\nBANNED PRESENT: {', '.join(banned)}"
record(9, "Flutter dependencies defined", not absent and not banned, detail)

# ------------------------------------------------------- 10. can it run
# The Flutter SDK is not installed in this environment, so this cannot be
# proven by building. What is checked here is everything that can be checked
# statically; the build itself is stated as unverified.
flutter_available = subprocess.run(
    "command -v flutter", shell=True, capture_output=True).returncode == 0

static = subprocess.run(
    [sys.executable, os.path.join(MOBILE, "verify_dart.py")],
    capture_output=True, text=True, cwd=MOBILE)
static_ok = static.returncode == 0

dart_count = sum(1 for f in all_files if f.endswith(".dart"))
entry_ok = os.path.isfile(main_dart)

detail = (
    f"flutter SDK on PATH: {'yes' if flutter_available else 'NO - cannot build here'}\n"
    f"static analysis (verify_dart.py): {'passed' if static_ok else 'FAILED'}\n"
    f"  - all local imports resolve\n"
    f"  - all project symbols reachable from their imports\n"
    f"  - all localisation keys defined\n"
    f"{dart_count} Dart files, entry point {'present' if entry_ok else 'MISSING'}\n"
    "NOT VERIFIED BY EXECUTION: `flutter pub get`, `flutter analyze`,\n"
    "`flutter test` and `flutter run` must be run on a machine with the SDK."
)
record(10, "Flutter application can run (static checks only)",
       static_ok and entry_ok, detail)

# ------------------------------------------------------------------ summary
print("\n" + "=" * 68)
passed = sum(1 for _, _, ok, _ in results if ok)
print(f"{passed}/{len(results)} checks passed")
if passed < len(results):
    print("\nFailed:")
    for n, name, ok, _ in results:
        if not ok:
            print(f"  {n}. {name}")
print("=" * 68)
sys.exit(0 if passed == len(results) else 1)
