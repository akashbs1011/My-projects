# Clinical AI

Multilingual, explainable clinical decision support. A Flutter mobile app talks
to a FastAPI backend that runs a Random Forest classifier over `Training.csv`
for symptom analysis.

This project is built entirely from its own source. It does not use Base44 or
any comparable no-code platform — see `docs/BASE44_AUDIT.md`.

---

## What this is, and what it is not

It ranks candidate conditions from selected symptoms and shows the evidence
behind each ranking. It does **not** diagnose. Every result carries two
separate scores, never combined:

| Score | Meaning |
|---|---|
| **Symptom match** | Share of the symptoms recorded for that condition in `Training.csv` that you selected |
| **Model confidence** | The classifier's raw probability for that class — not a medically validated probability |

A high confidence with poor symptom overlap means something quite different
from the reverse. Collapsing them into one number would hide that, so the app
never does.

---

## Architecture

```
Flutter (Dart)
     |
   FastAPI
     |
 Random Forest
     |
 Training.csv
```

One dataset, one job. `Training.csv` drives symptom→disease prediction. The
supplementary Kaggle CSVs supply the description, precautions and severity
shown on the disease page — no generated medical text anywhere.

| Layer | Technology |
|---|---|
| Mobile app | Flutter 3.22+ / Dart 3.4+ |
| State | `provider` |
| Routing | `go_router` (single auth guard) |
| Networking | `http` |
| Token storage | `flutter_secure_storage` (Keystore / Keychain) |
| Voice input | `speech_to_text` (platform recogniser) |
| Backend | FastAPI (Python 3.11+) |
| Database | MongoDB (Motor async driver) |
| Classifier | scikit-learn Random Forest |
| Auth | JWT (PyJWT) + bcrypt |

---

## Project layout

```
clinical-ai/
├── backend/            FastAPI application
│   ├── routes/         auth, users, symptoms, predictions, diseases, medical
│   ├── services/       preprocessing, prediction_engine, rag_service,
│   │                   translation_service, medical_entity_service, safety
│   ├── models/         MongoDB documents
│   ├── schemas/        Pydantic request/response models
│   ├── tests/
│   ├── train_model.py          trains the Random Forest from Training.csv
│   └── seed_reference_data.py  loads precautions and severity data
├── mobile/             Flutter application
│   ├── lib/
│   │   ├── app/            theme, router, root widget
│   │   ├── models/         API response types
│   │   ├── services/       api_client, auth, prediction, medical, history, speech
│   │   ├── providers/      auth, language, symptom, prediction, history
│   │   ├── screens/        splash, auth flow, home, results, disease,
│   │   │                   history, profile
│   │   ├── widgets/        result card, evidence strip, confidence bar, …
│   │   ├── localization/   6 languages
│   │   ├── utils/          config, validators, formatters, transliteration
│   │   └── main.dart
│   ├── android/        Gradle project
│   ├── ios/            Xcode Runner sources (see ios/README.md)
│   └── test/           Dart unit and widget tests
├── datasets/           you supply the Kaggle CSVs here
└── docs/
```

---

## Setup

### 1. Datasets

Neither dataset is redistributed here. Place them yourself:

```
datasets/Training.csv           Kaggle "Disease Symptom Prediction"
datasets/symptom_Description.csv   Disease, Description
datasets/symptom_precaution.csv    Disease, Precaution_1..4
datasets/Symptom-severity.csv      Symptom, weight
```

All four ship together in the same Kaggle download. `Training.csv` is the only
one strictly required — the app runs without the other three, and the disease
page then says the information is not in the dataset rather than inventing it.

`datasets/README.md` gives the sources and expected shapes. The preprocessing
layer auto-detects both common `Training.csv` layouts (binary symptom columns
with a `prognosis` column, or `Disease` + `Symptom_1..N`), so either works
without editing code.

### 2. Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp ../.env.example ../.env
# Set JWT_SECRET. The app refuses to start without it — by design.

# Run these from inside backend/ — they import `config` and `services`
# as top-level modules and resolve backend/data relative to themselves.
python train_model.py          # writes models/disease_model.joblib
python seed_reference_data.py  # loads precautions and severity data

uvicorn main:app --reload --port 8000
```

Interactive API docs at `http://localhost:8000/docs`.

### 3. Mobile app

```bash
cd mobile
flutter pub get

# iOS only, once: generates the Xcode project wrapper around the committed
# sources without overwriting them. See ios/README.md.
flutter create --platforms=ios .
cd ios && pod install && cd ..
```

---

## Running

Configuration is passed at build time with `--dart-define`, so one source tree
produces both a development and a production build with no code change.

**Android emulator** — `10.0.2.2` is the emulator's alias for your machine:

```bash
flutter run --dart-define=API_BASE_URL=http://10.15.231.92:8000/api```

**iOS simulator** — shares the host network:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

**Physical device** — use your machine's LAN address, and bind the backend to
all interfaces (`uvicorn main:app --host 0.0.0.0 --port 8000`):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000/api
```

Development builds show the API URL on the splash screen and surface the
password-reset token the backend returns while `DEBUG=true`, so the reset flow
can be completed without an email provider configured.

---

## Release builds

```bash
# Android APK (direct distribution)
flutter build apk --release \
  --dart-define=ENVIRONMENT=prod \
  --dart-define=API_BASE_URL=https://your-api.example.com/api

# Android App Bundle (Play Store)
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=prod \
  --dart-define=API_BASE_URL=https://your-api.example.com/api

# iOS archive
flutter build ipa --release \
  --dart-define=ENVIRONMENT=prod \
  --dart-define=API_BASE_URL=https://your-api.example.com/api
```

**Android signing.** Create `mobile/android/key.properties` (gitignored):

```properties
storePassword=…
keyPassword=…
keyAlias=…
storeFile=/absolute/path/to/keystore.jks
```

Without it the release build falls back to the debug key and prints a warning
rather than failing — convenient locally, but such a build cannot be uploaded
to Play.

**HTTPS is required in production.** Android's network security config permits
cleartext only for `10.0.2.2`, `localhost` and `127.0.0.1`; iOS App Transport
Security blocks plain HTTP outright. A production build pointed at an `http://`
backend will fail to connect, which is the intended behaviour.

---

## Languages

English, Hindi, Kannada, Telugu, Tamil, Malayalam.

Interface strings live in `mobile/lib/localization/`. Any key missing from a
language falls back to English rather than rendering blank. Telugu, Tamil and
Malayalam are complete apart from one long caption, which falls back — the
per-language coverage is printed by `mobile/verify_dart.py`. All six tables
should be reviewed by a native speaker before release.

Medical content — disease names, explanations, precautions, RAG answers — is
translated server-side by the configured provider, never from the UI string
tables, so a gap in a UI translation can never alter medical wording.

**Roman transliteration** (`mobile/lib/utils/transliteration.dart`) converts
Indic script to Latin using the shared Unicode block layout of Devanagari,
Kannada, Telugu, Tamil and Malayalam. It is a writing-system conversion, not a
translation. Its limits are documented in the source: Tamil is approximate by
nature, Hindi schwa deletion is not modelled, and nasal assimilation is not
applied.

**Translation providers.** With `TRANSLATION_PROVIDER=none` (the default) the
backend returns English medical text and says so in a `translation_note`,
rather than silently serving English while claiming to have translated.

---

## Verification

```bash
cd mobile && python3 verify_dart.py    # imports, symbol reachability, l10n keys
cd mobile && flutter analyze
cd mobile && flutter test
cd backend && pytest
```

`verify_dart.py` parses the source directly and does not need the Flutter SDK.
It complements `flutter analyze` rather than replacing it.

---

## Honest limits

- **Dataset accuracy is not clinical accuracy.** The Kaggle symptom dataset is
  synthetically generated, so cross-validation scores near 1.0 are expected and
  measure the generator's regularity, not diagnostic performance.
  `train_model.py` prints this caveat above 0.99 and repeats it in the saved
  report.
- **No dataset statistics are hard-coded anywhere.** Symptom counts, disease
  counts and support rates are measured from your actual `Training.csv` at
  preprocessing time.
- **Two files need clinician review before real use:**
  `backend/data/red_flag_symptoms.json` and
  `backend/data/symptom_aliases.json`. Both carry a review notice.
- **Voice input availability varies** by device, OS version and installed
  language packs. The app checks at runtime and tells the person to type
  instead, rather than showing a button that does nothing. It does not work in
  the iOS simulator.
- **This is not a medical device** and has not been clinically validated.
