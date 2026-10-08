# Base44 independence audit

**Requirement:** the project must not use Base44 or any comparable no-code /
app-generator platform.

**Result: independent.** Every file is hand-written source in this repository.

## What was checked

`verify_project.py` at the repository root scans every file (146 at the time of
writing, excluding binaries and build output) for:

- the string `base44` in any casing or with separators (`base-44`, `base_44`)
- generated-app markers: `.jsx`/`.tsx` files, `package.json`, `vite.config.*`,
  `tailwind.config.*`, `postcss.config.js`
- React imports in any JavaScript or TypeScript file

Run it yourself:

```bash
python3 verify_project.py
```

## Findings

| Check | Result |
|---|---|
| Base44 SDK, import or API call | none |
| Base44 configuration or manifest | none |
| Base44 URL or endpoint | none |
| Generated-app scaffolding markers | none |
| Hard-coded secrets or API keys | none |

The only occurrences of the string "Base44" in the repository are in this
document and in `README.md`, both stating that the platform is not used.

## Why the result holds up

The absence is structural, not cosmetic:

- **The backend is plain FastAPI.** Routes, Pydantic schemas, Motor queries and
  the scikit-learn pipeline are all in `backend/`, readable end to end. There is
  no external orchestration layer.
- **The mobile app is a standard Flutter project.** `mobile/lib/` follows the
  ordinary structure — `main.dart` wires dependencies explicitly and passes them
  into providers; nothing is resolved through a hidden runtime.
- **Every dependency is declared.** `backend/requirements.txt` and
  `mobile/pubspec.yaml` list them; each is a well-known open-source package.
- **The model is trained by a script you run.** `backend/train_model.py` reads
  your `Training.csv` and writes `models/disease_model.joblib`. No model, index
  or dataset is fetched from a hosted platform.
- **Configuration is yours.** The backend reads `.env`; the app takes
  `--dart-define` values at build time. No platform account is involved.

## Scope

This audit covers vendor independence only. It does not assess clinical
validity — see the "Honest limits" section of `README.md`.
