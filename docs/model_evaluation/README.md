# Model evaluation

This directory is intentionally empty.

Evaluation artifacts are generated from your dataset when you run:

```bash
cd backend
python train_model.py
```

That writes:

| File | Contents |
|---|---|
| `metrics.json` | Accuracy, macro/weighted precision, recall, F1, and cross-validation scores |
| `classification_report.txt` | Per-class precision, recall, F1, and support |
| `confusion_matrix.csv` | Full confusion matrix with disease labels |
| `confusion_matrix.png` | Rendered confusion matrix |
| `feature_importances.png` | The 30 symptoms the model weights most heavily |

No metrics are committed to this repository. Every number in these files is
computed from the dataset present on disk at training time.

## Reading the accuracy figure honestly

The public Kaggle symptom-disease dataset is synthetically generated: each
disease is associated with a fixed symptom pattern, repeated across records.
Classifiers therefore reach near-perfect accuracy on it. That number describes
how separable the dataset is, **not** clinical accuracy on real patients.

`train_model.py` prints this caveat automatically whenever test accuracy
exceeds 0.99, and repeats it in `classification_report.txt`. Reproduce that
caveat anywhere you report the score.
