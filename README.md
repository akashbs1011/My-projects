# Clinical AI

Multilingual, explainable clinical decision support. A Flutter mobile app talks to a FastAPI backend that runs a Random Forest classifier over `Training.csv` for symptom analysis.

This project is built entirely from its own source. It does not use Base44 or any comparable no-code platform.

---

## What this is, and what it is not

It ranks candidate conditions from selected symptoms and shows the evidence behind each ranking. It does **not** diagnose.

| Score | Meaning |
|---|---|
| **Symptom match** | Share of the symptoms recorded for that condition in `Training.csv` that you selected |
| **Model confidence** | The classifier's raw probability for that class — not a medically validated probability |

---

## Architecture

```text
Flutter (Dart)
      |
   FastAPI
      |
Random Forest
      |
Training.csv