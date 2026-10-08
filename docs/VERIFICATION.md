# Verification

What was actually executed, and what was not. The distinction matters: this
environment has no network access and no Flutter SDK, so some things could be
proven and others can only be checked statically.

---

## Verified by running it

### Backend pipeline

Executed against synthetic CSVs constructed to exercise both dataset layouts.

| Check | Result |
|---|---|
| WIDE layout detection (binary symptom columns + `prognosis`) | correct |
| LONG layout detection (`Disease` + `Symptom_1..N`) | correct |
| Duplicate row removal | correct |
| Never-occurring symptom columns dropped | correct |
| Disease→symptom support map | computed from measured counts |
| `train_model.py` end to end (12 synthetic classes) | trained, cross-validated, wrote a real metrics report |
| Prediction engine | ranked results, two separate scores, matched/unmatched split, explanations, urgency flagging |

Two real defects were found this way and fixed:

1. **`slugify` imported `bson`**, coupling the ML layer to the MongoDB driver —
   prediction crashed on any machine without pymongo installed. Fixed by
   extracting it to a dependency-free `backend/utils/text.py`.
2. **Prediction passed a bare NumPy array** to a model fitted on a named
   DataFrame, producing a scikit-learn warning on every single call. Fixed by
   constructing a properly named `pd.DataFrame`.

### Transliteration

The Unicode offset tables in `mobile/lib/utils/transliteration.dart` were ported
to Python and run before shipping. All cases matched:

| Input | Script | Output |
|---|---|---|
| `ನನಗೆ ಜ್ವರ ಇದೆ` | Kannada | `nanage jvara ide` (the specification's example) |
| `ಕ` / `ಕ್` | Kannada | `ka` / `k` (inherent vowel, then cancelled by virama) |
| `ಕಿ` / `ಕಾ` | Kannada | `ki` / `kā` (vowel sign replaces the inherent vowel) |
| `क` / `ക` / `క` | Devanagari / Malayalam / Telugu | `ka` in all three, from one shared table |
| `ಜ್ವರ 39.5` | mixed | `jvara 39.5` (non-Indic characters pass through) |
| `fever` | Latin | `null` — the Roman line is hidden rather than duplicated |

### Dart static analysis

`mobile/verify_dart.py` parses the source directly (no SDK needed):

```
63 Dart files scanned
[1] Import resolution ......... 290 imports, all resolve
[2] Symbol reachability ....... 68 project symbols, all references reachable
[3] Localisation keys ......... all keys used are defined
[4] Route constants ........... 11 referenced, all declared
[5] Required structure ........ all present
```

Check [2] is the important one: it confirms every project class a file uses is
reachable through that file's imports, which is how a forgotten import — the
most common way a Dart build breaks — would be caught.

Localisation coverage against the English reference table:

| Language | Coverage |
|---|---|
| Hindi | 103/103 |
| Kannada | 103/103 |
| Telugu | 102/103 |
| Tamil | 102/103 |
| Malayalam | 102/103 |

The single gap in each is one long caption, which falls back to English rather
than rendering blank.

## Verified against the REAL dataset

The Kaggle files are now present, so the pipeline was run on actual data rather
than the synthetic CSVs used earlier.

| Stage | Result |
|---|---|
| Layout auto-detection | LONG correctly identified (Disease + Symptom_1..17) |
| Dataset inspection | 4,920 records, 41 diseases, 131 symptoms, 4,616 duplicates, 0 constant columns |
| Deduplication | 4,920 -> 304 unique rows |
| Feature matrix | 304 x 128, 41 classes |
| Support map | computed from counts, e.g. Fungal infection: itching 0.80, skin rash 0.80 |
| Training (RandomForest, 300 trees) | test accuracy 1.0000, weighted F1 1.0000 |
| 5-fold cross-validation | 1.0000 (+/- 0.0000) |

**The perfect score is a property of the data, not evidence of a good model.**
See `datasets/README.md`.

Prediction was then exercised end to end through `prediction_engine`:

| Input | Top result | Symptom match | Model confidence |
|---|---|---|---|
| itching, skin_rash, nodal_skin_eruptions, dischromic_patches | Fungal infection | 1.00 | 0.99 |
| headache, vomiting | Paralysis (brain hemorrhage) | 0.50 | 0.51 |
| itching, skin_rash, chest_pain | Fungal infection | 0.50 | 0.41 |

The third case is the one worth reading closely: `chest pain` is correctly
reported in `unmatched_symptoms`, the symptom match drops to 0.50, and Heart
attack appears second on the strength of that single symptom. A single blended
score would have hidden all of that.

Two caveats on how this was run. `train_model.py` could not be executed
directly in the verification environment because `pydantic` is not installed
there and `config.py` imports it; the pipeline and training were driven by
calling `run_pipeline()` and scikit-learn directly, and the engine was loaded
with a stubbed settings object. The pipeline, model and engine code paths are
the real ones. The trained `.joblib` was deleted rather than shipped, because a
model pickled by one scikit-learn version may not load under another.

### API contract, app against backend

The seam most likely to break when a frontend is rebuilt is the set of URLs it
calls. Every `_api.get/post/patch/delete` call in `mobile/lib/services/` was
extracted and matched against the route table parsed from `backend/routes/*.py`
and `backend/main.py`.

**17 calls, 17 matched** (re-verified after the Q&A removal). Path parameters were normalised so that the Dart
`'/diseases/$slug'` and the FastAPI `/diseases/{slug}` compare as equal.

Backend routes the app does not currently call, all intentional:
`GET /diseases` (list — the app reaches diseases from a result),
`GET /users/profile` (the app reads the profile from `/auth/me`), and
`POST /users/change-password` (not surfaced in the UI yet).

### Ten-point project check

`python3 verify_project.py` — 10/10. See the section below on check 10.

---

## NOT verified — you must run these

The sandbox has no network access and no Flutter SDK, so none of the following
could be executed here:

```bash
cd mobile
flutter pub get        # resolve dependencies
flutter analyze        # the real static analyser
flutter test           # 6 test files
flutter run            # launch on a device or emulator

cd ../backend
pip install -r requirements.txt
pytest
```

Also unverified because they need the real data or a device:

- **Behaviour against the actual `Training.csv` and the supplementary Kaggle CSVs.** Neither dataset
  is attached. Everything is computed from the dataset at runtime rather than
  hard-coded, precisely so that no fabricated statistic could survive contact
  with the real file.
- **Speech recognition.** Availability depends on the device, OS version and
  installed language packs. It does not work in the iOS simulator.
- **Android and iOS builds.** No Android SDK, Gradle, Xcode or CocoaPods here.
- **The iOS Xcode project.** `Runner.xcodeproj/project.pbxproj` is deliberately
  not committed — it is machine-generated, and a hand-written one is the top
  cause of an iOS project that will not open. Run
  `flutter create --platforms=ios .` from `mobile/`. See `mobile/ios/README.md`.

### About check 10, "Flutter application can run"

This cannot honestly be reported as proven. What the check actually confirms is
that the entry point exists with `main()` and `runApp()`, and that static
analysis passes. The script says so in its own output rather than claiming a
successful build. Treat a green check 10 as "nothing statically detectable
would stop it", not "it ran".

---

## Frontend behaviour checklist

To be walked through once the app is on a device or emulator.

**Startup and session**
- [ ] Splash shows while the stored session is checked; a returning user goes
      straight to Home without the sign-in screen flashing
- [ ] Dev builds show the API URL on the splash screen
- [ ] Signing out returns to Login and clears the selected symptoms

**Authentication**
- [ ] Register enforces the same password rule as the backend, before any
      network call
- [ ] Login errors appear as readable text, never a status code
- [ ] Forgot password shows the debug reset token only when the backend has
      `DEBUG=true`
- [ ] Reset password accepts a token from the deep link and from manual entry
- [ ] A token rejected mid-session ends the session once, not per screen

**Symptoms and analysis**
- [ ] The symptom list comes from the backend, never a hard-coded list
- [ ] Search debounces, and falls back to local filtering if a request fails
- [ ] Selection cap at 40 is enforced with an explanatory message
- [ ] Voice input adds only symptoms the backend recognised, and reports the
      count added
- [ ] When speech is unavailable the app says to type instead

**Results**
- [ ] Symptom match and model confidence appear side by side, never merged
- [ ] Neither percentage ever renders without its caption
- [ ] The evidence strip shows one segment per selected symptom, hollow for
      unmatched
- [ ] Unrecognised symptoms are listed as excluded, not silently dropped
- [ ] The urgency notice appears above the results, not below

**Disease detail**
- [ ] Missing description or precautions show the not-in-dataset message, not invented content
- [ ] Symptoms you selected are highlighted in the condition's symptom list
- [ ] Support percentages are labelled as dataset frequencies

**Language**
- [ ] All six languages switch the interface immediately
- [ ] Changing language refetches symptom labels
- [ ] Roman transliteration toggle appears only for non-English
- [ ] Indic scripts render correctly (system fonts; no font assets shipped)
- [ ] Missing translations fall back to English, never blank

**Layout**
- [ ] Score rows stack below 380px width instead of truncating
- [ ] Large system font sizes do not break the score rows (scaling is clamped
      to 1.4)
- [ ] The bottom navigation never covers content
