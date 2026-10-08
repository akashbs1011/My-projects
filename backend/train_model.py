#!/usr/bin/env python
"""
Train the disease prediction model from the real dataset on disk.

    python train_model.py
    python train_model.py --csv /path/to/Training.csv --model gradient_boosting

Every number this script prints or writes is computed from the dataset. If the
dataset is missing, it exits with an error rather than producing placeholders.
Evaluation artifacts are written to docs/model_evaluation/.
"""
from __future__ import annotations

import argparse
import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.naive_bayes import BernoulliNB

from config import get_settings
from services.preprocessing import run_pipeline, save_artifacts

logging.basicConfig(level=logging.INFO, format="%(levelname)-8s %(message)s")
logger = logging.getLogger("train")

MODELS = {
    "random_forest": lambda s: RandomForestClassifier(
        n_estimators=s.N_ESTIMATORS, random_state=s.RANDOM_STATE, n_jobs=-1,
        class_weight="balanced_subsample",
    ),
    "gradient_boosting": lambda s: GradientBoostingClassifier(random_state=s.RANDOM_STATE),
    "naive_bayes": lambda s: BernoulliNB(),
    "logistic_regression": lambda s: LogisticRegression(
        max_iter=2000, random_state=s.RANDOM_STATE
    ),
}


def main() -> int:
    settings = get_settings()
    parser = argparse.ArgumentParser(description="Train the Clinical-AI disease model.")
    parser.add_argument("--csv", type=Path, default=settings.TRAINING_CSV)
    parser.add_argument("--model", choices=sorted(MODELS), default="random_forest")
    parser.add_argument("--test-size", type=float, default=settings.TEST_SIZE)
    parser.add_argument("--cv-folds", type=int, default=5)
    parser.add_argument("--no-plot", action="store_true")
    args = parser.parse_args()

    if not args.csv.exists():
        logger.error(
            "Dataset not found: %s\n"
            "Download the Kaggle symptom-disease dataset and place Training.csv "
            "in datasets/ (see datasets/README.md). Training cannot proceed "
            "without the real data.", args.csv,
        )
        return 1

    # -- 1. Inspect + preprocess ------------------------------------------- #
    alias_path = Path(__file__).parent / "data" / "symptom_aliases.json"
    processed = run_pipeline(args.csv, alias_path)
    print(processed.report.summary())
    print(f"\nRows dropped as duplicates : {processed.rows_dropped_duplicate}")
    print(f"Rows dropped as empty      : {processed.rows_dropped_empty}")
    print(f"Final matrix               : {processed.X.shape[0]} rows x {processed.X.shape[1]} features")
    print(f"Classes                    : {len(processed.disease_names)}\n")

    save_artifacts(processed, settings.PROCESSED_DIR)

    X, y = processed.X, processed.y
    min_class = y.value_counts().min()
    stratify = y if min_class >= 2 else None
    if stratify is None:
        logger.warning("A class has fewer than 2 records; splitting without stratification.")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=args.test_size, random_state=settings.RANDOM_STATE, stratify=stratify
    )

    # -- 2. Train ----------------------------------------------------------- #
    logger.info("Training %s on %d records...", args.model, len(X_train))
    model = MODELS[args.model](settings)
    model.fit(X_train, y_train)

    # -- 3. Evaluate -------------------------------------------------------- #
    y_pred = model.predict(X_test)
    metrics = {
        "accuracy": float(accuracy_score(y_test, y_pred)),
        "precision_macro": float(precision_score(y_test, y_pred, average="macro", zero_division=0)),
        "recall_macro": float(recall_score(y_test, y_pred, average="macro", zero_division=0)),
        "f1_macro": float(f1_score(y_test, y_pred, average="macro", zero_division=0)),
        "precision_weighted": float(precision_score(y_test, y_pred, average="weighted", zero_division=0)),
        "recall_weighted": float(recall_score(y_test, y_pred, average="weighted", zero_division=0)),
        "f1_weighted": float(f1_score(y_test, y_pred, average="weighted", zero_division=0)),
    }

    folds = min(args.cv_folds, int(min_class))
    if folds >= 2:
        cv = StratifiedKFold(n_splits=folds, shuffle=True, random_state=settings.RANDOM_STATE)
        scores = cross_val_score(model, X, y, cv=cv, scoring="accuracy", n_jobs=-1)
        metrics["cv_folds"] = folds
        metrics["cv_accuracy_mean"] = float(scores.mean())
        metrics["cv_accuracy_std"] = float(scores.std())
    else:
        logger.warning("Too few records per class for cross-validation; skipping.")

    print("=" * 62)
    print("EVALUATION (held-out test set)")
    print("=" * 62)
    for key, value in metrics.items():
        print(f"{key:24s}: {value:.4f}" if isinstance(value, float) else f"{key:24s}: {value}")
    print()

    report_text = classification_report(y_test, y_pred, zero_division=0)
    print(report_text)

    labels = sorted(y.unique())
    matrix = confusion_matrix(y_test, y_pred, labels=labels)

    if metrics["accuracy"] > 0.99:
        note = (
            "NOTE: near-perfect accuracy on this dataset is expected. The public "
            "Kaggle symptom-disease dataset is synthetically generated with a "
            "fixed symptom pattern per disease, so classes are almost linearly "
            "separable. This score reflects the dataset's structure and should "
            "not be read as real-world clinical accuracy."
        )
        print("\n" + note + "\n")
    else:
        note = ""

    # -- 4. Write evaluation artifacts -------------------------------------- #
    eval_dir = settings.EVAL_DIR
    eval_dir.mkdir(parents=True, exist_ok=True)
    trained_at = datetime.now(timezone.utc).isoformat()

    (eval_dir / "metrics.json").write_text(
        json.dumps(
            {
                "generated_at": trained_at,
                "algorithm": args.model,
                "dataset": str(args.csv),
                "n_records_used": int(len(X)),
                "n_features": int(X.shape[1]),
                "n_classes": int(len(labels)),
                "test_size": args.test_size,
                "metrics": metrics,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    (eval_dir / "classification_report.txt").write_text(
        f"Generated: {trained_at}\nAlgorithm: {args.model}\nDataset: {args.csv}\n\n"
        f"{report_text}\n{note}\n",
        encoding="utf-8",
    )
    pd.DataFrame(matrix, index=labels, columns=labels).to_csv(eval_dir / "confusion_matrix.csv")

    if not args.no_plot:
        _plot_confusion(matrix, labels, eval_dir / "confusion_matrix.png")
        _plot_importances(model, list(X.columns), eval_dir / "feature_importances.png")

    # -- 5. Persist the model bundle ---------------------------------------- #
    bundle = {
        "model": model,
        "feature_names": list(X.columns),
        "disease_names": processed.disease_names,
        "disease_symptom_map": processed.disease_symptom_map,
        "metadata": {
            "algorithm": args.model,
            "trained_at": trained_at,
            "dataset": str(args.csv),
            "n_records": int(len(X)),
            "n_features": int(X.shape[1]),
            "n_classes": int(len(labels)),
            "accuracy": round(metrics["accuracy"], 4),
            "f1_macro": round(metrics["f1_macro"], 4),
        },
    }
    joblib.dump(bundle, settings.MODEL_PATH)
    print(f"Model saved to      : {settings.MODEL_PATH}")
    print(f"Evaluation saved to : {eval_dir}")
    return 0


def _plot_confusion(matrix: np.ndarray, labels: list, path: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    size = max(8, min(28, len(labels) * 0.4))
    fig, ax = plt.subplots(figsize=(size, size))
    ax.imshow(matrix, cmap="Blues")
    ax.set_xticks(range(len(labels)))
    ax.set_yticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=90, fontsize=6)
    ax.set_yticklabels(labels, fontsize=6)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    ax.set_title("Confusion matrix (held-out test set)")
    fig.tight_layout()
    fig.savefig(path, dpi=140)
    plt.close(fig)


def _plot_importances(model, features: list, path: Path, top: int = 30) -> None:
    if not hasattr(model, "feature_importances_"):
        return
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    order = np.argsort(model.feature_importances_)[::-1][:top]
    fig, ax = plt.subplots(figsize=(9, max(5, len(order) * 0.28)))
    ax.barh([features[i] for i in order][::-1],
            [model.feature_importances_[i] for i in order][::-1])
    ax.set_xlabel("Importance")
    ax.set_title(f"Top {len(order)} symptoms by model importance")
    fig.tight_layout()
    fig.savefig(path, dpi=140)
    plt.close(fig)


if __name__ == "__main__":
    raise SystemExit(main())
