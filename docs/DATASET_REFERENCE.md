# Dataset reference

## Prediction dataset

**Kaggle symptom–disease dataset — `Training.csv`**

Used **only** for disease classification: symptom vocabulary, disease–symptom
support rates, the feature matrix, model training, and evaluation.

Every figure the application reports about this dataset — record count, column
count, unique diseases, unique symptoms, missing values, duplicates — is
measured at runtime by `inspect_dataset()` in
`backend/services/preprocessing.py`. None is written into the codebase.

**Important limitation.** The dataset is synthetically generated: each disease
is associated with a fixed symptom pattern repeated across records. Classifiers
reach near-perfect accuracy on it. That figure measures dataset separability,
not clinical accuracy. `train_model.py` emits this caveat automatically above
0.99 accuracy and repeats it in the saved classification report.

## Medical knowledge dataset

**MedQuAD** — 47,457 question–answer pairs from 12 NIH websites (NCI, NIDDK,
GARD, NHLBI, and others), released by Asma Ben Abacha and Dina Demner-Fushman.

Used for medical question answering and for citable references on disease
detail pages.

**MedQuAD is not used for disease classification and no part of this
application treats it as a classification source.**

Answers in four subsets (CancerGov, GARD, MPlusHerbs, MPlusDrugs) were removed
by the maintainers for licensing reasons. `build_vectorstore.py` reports the
number of passages actually extracted rather than assuming a corpus total.

## Why the separation matters

A structured symptom→disease matrix can rank candidates but carries no
explanatory text and no citable source. A free-text medical corpus carries both
but cannot be used as a classifier. Using each for what it can support is what
lets the application cite a real source for information while being explicit
that a ranking comes from a statistical model trained on synthetic data.

## Provenance of everything shown to a user

| Shown | Comes from |
|---|---|
| Symptom list | `Training.csv`, normalised |
| Ranked conditions | Random Forest trained on `Training.csv` |
| Symptom match score | Measured support rates in `Training.csv` |
| Model confidence | Classifier `predict_proba` output |
| Explanation | Template filled with observed counts |
| Common symptoms + support % | `Training.csv` co-occurrence rates |
| Disease overview | `symptom_Description.csv`, or reported unavailable |
| Precautions | `symptom_precaution.csv`, or reported unavailable |
| Severity | `Symptom-severity.csv`, or omitted |
| References | MedQuAD document metadata |
| RAG answers | MedQuAD passages, extractive or LLM-summarised from them |
| Red-flag urgency | `backend/data/red_flag_symptoms.json` (needs clinician review) |
| Symptom aliases | `backend/data/symptom_aliases.json` (needs clinician review) |

Nothing in the application writes medical content from its own knowledge.
