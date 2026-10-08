"""
Preprocessing pipeline for the symptom-disease dataset.

Nothing here hard-codes disease names, symptom names, or dataset dimensions.
Everything is derived from the CSV that is actually present on disk, so the
inspection report printed by `inspect_dataset()` reflects the real file.

Two common layouts of the Kaggle symptom-disease dataset are supported and
auto-detected:

  WIDE  - one binary column per symptom plus a target column.
          itching,skin_rash,...,prognosis
          1,0,...,Fungal infection

  LONG  - a target column plus Symptom_1..Symptom_N free-text columns.
          Disease,Symptom_1,Symptom_2,...
          Fungal infection, itching, skin_rash,...
"""
from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# Column names that are treated as the disease/target column when present.
TARGET_CANDIDATES = ("prognosis", "disease", "diseases", "target", "label", "condition")

_PUNCT = re.compile(r"[^\w\s]")
_SPACES = re.compile(r"\s+")


# --------------------------------------------------------------------------- #
# Symptom normalisation
# --------------------------------------------------------------------------- #
def normalize_symptom(raw: str) -> str:
    """
    Canonical form of a symptom string.

    Handles capitalisation, underscores, hyphens, stray punctuation, repeated
    and trailing whitespace. Purely lexical - it never merges two different
    strings into one concept. Meaning-level merging is the job of the alias
    map, which is a reviewed file rather than a guess.
    """
    if raw is None:
        return ""
    text = str(raw).replace("_", " ").replace("-", " ")
    text = _PUNCT.sub(" ", text)
    text = _SPACES.sub(" ", text).strip().lower()
    return text


def load_alias_map(path: Path) -> Dict[str, str]:
    """
    Load the reviewed alias map: {alias -> canonical dataset symptom}.

    Aliases are only applied when the target exists in the dataset vocabulary,
    so an out-of-date alias file can never introduce a symptom the model was
    not trained on.
    """
    if not path.exists():
        logger.warning("Alias map not found at %s - continuing without aliases.", path)
        return {}
    with path.open(encoding="utf-8") as fh:
        raw = json.load(fh)
    return {normalize_symptom(k): normalize_symptom(v) for k, v in raw.get("aliases", {}).items()}


def apply_aliases(symptom: str, aliases: Dict[str, str], vocabulary: set[str]) -> str:
    canonical = aliases.get(symptom, symptom)
    return canonical if canonical in vocabulary else symptom


# --------------------------------------------------------------------------- #
# Inspection
# --------------------------------------------------------------------------- #
@dataclass
class DatasetReport:
    """Facts measured from the CSV on disk. Never populated with assumptions."""
    path: str
    layout: str
    n_records: int
    n_columns: int
    target_column: str
    symptom_columns: List[str]
    n_unique_diseases: int
    n_unique_symptoms: int
    diseases: List[str]
    symptoms: List[str]
    missing_values_total: int
    columns_with_missing: Dict[str, int]
    duplicate_records: int
    empty_symptom_cells: int
    constant_columns: List[str]
    class_distribution: Dict[str, int]
    normalisation_collisions: Dict[str, List[str]] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {k: v for k, v in self.__dict__.items()}

    def summary(self) -> str:
        lines = [
            "=" * 62,
            "DATASET INSPECTION REPORT",
            "=" * 62,
            f"File                : {self.path}",
            f"Detected layout     : {self.layout}",
            f"Records             : {self.n_records}",
            f"Columns             : {self.n_columns}",
            f"Target column       : {self.target_column}",
            f"Symptom columns     : {len(self.symptom_columns)}",
            f"Unique diseases     : {self.n_unique_diseases}",
            f"Unique symptoms     : {self.n_unique_symptoms}",
            f"Missing values      : {self.missing_values_total}",
            f"Duplicate records   : {self.duplicate_records}",
            f"Empty symptom cells : {self.empty_symptom_cells}",
            f"Constant columns    : {len(self.constant_columns)} {self.constant_columns or ''}",
        ]
        if self.normalisation_collisions:
            lines.append("")
            lines.append("Raw symptom names that collapse to the same canonical form:")
            for canon, raws in self.normalisation_collisions.items():
                lines.append(f"  {canon}: {raws}")
        counts = list(self.class_distribution.values())
        if counts:
            lines.append("")
            lines.append(
                f"Records per disease : min={min(counts)} max={max(counts)} "
                f"mean={sum(counts) / len(counts):.1f}"
            )
        lines.append("=" * 62)
        return "\n".join(lines)


def detect_target_column(df: pd.DataFrame) -> str:
    """Find the disease column by name, then by structure. Never guesses silently."""
    lowered = {c.lower().strip(): c for c in df.columns}
    for candidate in TARGET_CANDIDATES:
        if candidate in lowered:
            return lowered[candidate]

    # Structural fallback: the non-numeric column with the fewest unique values
    # that still has more than one class.
    object_cols = [c for c in df.columns if df[c].dtype == object]
    ranked = [(df[c].nunique(dropna=True), c) for c in object_cols if df[c].nunique(dropna=True) > 1]
    if ranked:
        ranked.sort()
        chosen = ranked[0][1]
        logger.warning("No conventional target column name found; using '%s'.", chosen)
        return chosen

    raise ValueError(
        "Could not identify a disease/target column. Expected one of "
        f"{TARGET_CANDIDATES} or a categorical text column."
    )


def detect_layout(df: pd.DataFrame, target: str) -> str:
    """WIDE if the non-target columns are binary indicators, otherwise LONG."""
    feature_cols = [c for c in df.columns if c != target]
    if not feature_cols:
        raise ValueError("Dataset contains a target column but no feature columns.")
    binary_like = 0
    for col in feature_cols:
        values = set(pd.unique(df[col].dropna()))
        if values <= {0, 1, 0.0, 1.0, "0", "1", True, False}:
            binary_like += 1
    return "WIDE" if binary_like >= max(1, int(0.8 * len(feature_cols))) else "LONG"


def inspect_dataset(csv_path: Path) -> Tuple[pd.DataFrame, DatasetReport]:
    """Load the CSV and measure its actual structure."""
    csv_path = Path(csv_path)
    if not csv_path.exists():
        raise FileNotFoundError(
            f"Dataset not found at {csv_path}. Place the Kaggle symptom-disease "
            "Training.csv there (see datasets/README.md)."
        )

    df = pd.read_csv(csv_path)
    df.columns = [str(c).strip() for c in df.columns]
    # Kaggle exports frequently carry a trailing unnamed index column.
    df = df.loc[:, ~df.columns.str.match(r"^Unnamed")]

    target = detect_target_column(df)
    layout = detect_layout(df, target)
    feature_cols = [c for c in df.columns if c != target]

    if layout == "WIDE":
        canonical: Dict[str, List[str]] = {}
        for col in feature_cols:
            canonical.setdefault(normalize_symptom(col), []).append(col)
        symptoms = sorted(canonical)
        empty_cells = int(df[feature_cols].isna().sum().sum())
        constant = [c for c in feature_cols if df[c].nunique(dropna=True) <= 1]
    else:
        canonical = {}
        for col in feature_cols:
            for value in df[col].dropna().unique():
                norm = normalize_symptom(value)
                if norm:
                    canonical.setdefault(norm, [])
                    if str(value) not in canonical[norm]:
                        canonical[norm].append(str(value))
        symptoms = sorted(canonical)
        empty_cells = int(df[feature_cols].isna().sum().sum())
        constant = []

    collisions = {k: v for k, v in canonical.items() if len(v) > 1}
    diseases = sorted({str(d).strip() for d in df[target].dropna().unique()})
    per_column_missing = {c: int(n) for c, n in df.isna().sum().items() if n > 0}

    report = DatasetReport(
        path=str(csv_path),
        layout=layout,
        n_records=int(len(df)),
        n_columns=int(df.shape[1]),
        target_column=target,
        symptom_columns=feature_cols,
        n_unique_diseases=len(diseases),
        n_unique_symptoms=len(symptoms),
        diseases=diseases,
        symptoms=symptoms,
        missing_values_total=int(df.isna().sum().sum()),
        columns_with_missing=per_column_missing,
        duplicate_records=int(df.duplicated().sum()),
        empty_symptom_cells=empty_cells,
        constant_columns=constant,
        class_distribution={str(k): int(v) for k, v in df[target].value_counts().items()},
        normalisation_collisions=collisions,
    )
    return df, report


# --------------------------------------------------------------------------- #
# Cleaning + feature matrix
# --------------------------------------------------------------------------- #
@dataclass
class ProcessedDataset:
    X: pd.DataFrame
    y: pd.Series
    feature_names: List[str]
    disease_names: List[str]
    disease_symptom_map: Dict[str, Dict[str, float]]   # disease -> {symptom: support}
    report: DatasetReport
    rows_dropped_duplicate: int
    rows_dropped_empty: int


def build_feature_matrix(
    df: pd.DataFrame,
    report: DatasetReport,
    alias_map: Optional[Dict[str, str]] = None,
) -> ProcessedDataset:
    """Clean the frame and return a binary symptom-presence matrix."""
    alias_map = alias_map or {}
    target = report.target_column
    before = len(df)

    df = df.drop_duplicates().reset_index(drop=True)
    dropped_dupes = before - len(df)

    df = df[df[target].notna()]
    df = df[df[target].astype(str).str.strip() != ""].reset_index(drop=True)
    df[target] = df[target].astype(str).str.strip()

    vocabulary = set(report.symptoms)
    feature_names = sorted(vocabulary)
    index = {name: i for i, name in enumerate(feature_names)}
    matrix = np.zeros((len(df), len(feature_names)), dtype=np.int8)

    if report.layout == "WIDE":
        for col in report.symptom_columns:
            canon = apply_aliases(normalize_symptom(col), alias_map, vocabulary)
            if canon not in index:
                continue
            values = pd.to_numeric(df[col], errors="coerce").fillna(0).astype(int).to_numpy()
            # Columns that collapse to the same canonical symptom are OR-ed together.
            matrix[:, index[canon]] |= (values > 0).astype(np.int8)
    else:
        for row_i, (_, row) in enumerate(df.iterrows()):
            for col in report.symptom_columns:
                canon = apply_aliases(normalize_symptom(row[col]), alias_map, vocabulary)
                if canon and canon in index:
                    matrix[row_i, index[canon]] = 1

    X = pd.DataFrame(matrix, columns=feature_names)
    y = df[target].reset_index(drop=True)

    # Drop rows where no symptom at all is recorded - they carry no signal.
    non_empty = X.sum(axis=1) > 0
    dropped_empty = int((~non_empty).sum())
    X, y = X[non_empty].reset_index(drop=True), y[non_empty].reset_index(drop=True)

    # Drop symptom columns that never occur - they cannot inform any prediction.
    used = X.columns[X.sum(axis=0) > 0].tolist()
    X = X[used]

    disease_symptom_map = build_disease_symptom_map(X, y)

    return ProcessedDataset(
        X=X,
        y=y,
        feature_names=used,
        disease_names=sorted(y.unique().tolist()),
        disease_symptom_map=disease_symptom_map,
        report=report,
        rows_dropped_duplicate=dropped_dupes,
        rows_dropped_empty=dropped_empty,
    )


def build_disease_symptom_map(X: pd.DataFrame, y: pd.Series) -> Dict[str, Dict[str, float]]:
    """
    disease -> {symptom: support}, where support is the fraction of that
    disease's training records in which the symptom is present.

    This is a measured co-occurrence rate from the dataset, not a clinical
    claim about which symptoms a disease causes.
    """
    mapping: Dict[str, Dict[str, float]] = {}
    frame = X.copy()
    frame["__y"] = y.values
    for disease, group in frame.groupby("__y"):
        rates = group.drop(columns="__y").mean(axis=0)
        mapping[str(disease)] = {s: round(float(r), 4) for s, r in rates.items() if r > 0}
    return mapping


def run_pipeline(csv_path: Path, alias_path: Optional[Path] = None) -> ProcessedDataset:
    """Training.csv -> clean -> normalise -> dedupe -> map -> feature matrix."""
    df, report = inspect_dataset(csv_path)
    aliases = load_alias_map(alias_path) if alias_path else {}
    return build_feature_matrix(df, report, aliases)


def save_artifacts(processed: ProcessedDataset, out_dir: Path) -> None:
    """Persist the vocabulary and mappings the API serves at runtime."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "symptoms.json").write_text(
        json.dumps(processed.feature_names, indent=2), encoding="utf-8"
    )
    (out_dir / "diseases.json").write_text(
        json.dumps(processed.disease_names, indent=2), encoding="utf-8"
    )
    (out_dir / "disease_symptom_map.json").write_text(
        json.dumps(processed.disease_symptom_map, indent=2), encoding="utf-8"
    )
    (out_dir / "dataset_report.json").write_text(
        json.dumps(processed.report.to_dict(), indent=2), encoding="utf-8"
    )
    logger.info("Wrote processed artifacts to %s", out_dir)
