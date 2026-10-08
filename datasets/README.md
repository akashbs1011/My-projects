# Datasets

## What is here

The Kaggle **Disease Symptom Prediction** dataset (itachi9604), four files:

| File | Shape | Purpose |
|---|---|---|
| `Training.csv` | 4,920 x 18 | Disease + `Symptom_1..17` — trains the classifier |
| `symptom_Description.csv` | 41 x 2 | Disease, Description — the overview on the disease page |
| `symptom_precaution.csv` | 41 x 5 | Disease, `Precaution_1..4` — the precautions list |
| `Symptom-severity.csv` | 133 x 2 | Symptom, weight (1–7) — the severity badge |

Source: https://www.kaggle.com/datasets/itachi9604/disease-symptom-description-dataset

`Training.csv` is the Kaggle file `dataset.csv`, renamed to match `TRAINING_CSV`
in `backend/config.py`. Nothing inside it was altered.

## Measured properties

These numbers were produced by running `inspect_dataset()` on the actual file,
not copied from a dataset description:

```
layout                LONG  (Disease + Symptom_1..17, auto-detected)
records               4,920
unique diseases       41
unique symptoms       131
duplicate records     4,616   <-- 94% of the file
empty symptom cells   46,992  (expected: rows use as few as 3 of 17 columns)
constant columns      none
```

After the pipeline drops duplicates: **304 unique rows, 128 symptom features,
41 classes.** Between 5 and 10 unique rows per disease (median 7), which is
enough for stratified 5-fold cross-validation.

Three of the 131 symptoms do not survive into the feature matrix — they are
merged by alias normalisation or never co-occur usefully. That reduction is
performed by the pipeline and reported, not hard-coded.

## An important caveat about accuracy

A Random Forest trained on this data scores **1.0000 test accuracy and 1.0000
on 5-fold cross-validation.** That is not a good result — it is a property of
the data.

The dataset is synthetically generated: each disease is expanded from a fixed
symptom set, which is why 94% of the rows are duplicates and why the 41 classes
are almost perfectly separable. The score measures the generator's regularity.
It says nothing about diagnostic accuracy on real patients, and must never be
presented as a clinical figure. `train_model.py` prints this warning itself
whenever accuracy exceeds 0.99.

## Regenerating the artifacts

```bash
cd backend
python train_model.py          # writes models/disease_model.joblib
python seed_reference_data.py  # loads descriptions, precautions, severity
```

The trained model is deliberately **not** committed. A joblib pickled by one
scikit-learn version can fail to load under another, so it is built on the
machine that will run it.
