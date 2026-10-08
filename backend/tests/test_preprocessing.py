"""Preprocessing tests run on a synthetic frame, so they need no dataset download."""
import pandas as pd
import pytest

from services.preprocessing import (
    apply_aliases,
    build_disease_symptom_map,
    build_feature_matrix,
    detect_layout,
    detect_target_column,
    inspect_dataset,
    normalize_symptom,
)


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("  Skin_Rash ", "skin rash"),
        ("HIGH FEVER", "high fever"),
        ("joint-pain", "joint pain"),
        ("stomach   pain!", "stomach pain"),
        ("Itching", "itching"),
        (None, ""),
    ],
)
def test_normalize_symptom(raw, expected):
    assert normalize_symptom(raw) == expected


def test_aliases_only_apply_when_target_is_in_vocabulary():
    aliases = {"stomach pain": "abdominal pain", "ghost": "nonexistent symptom"}
    vocab = {"abdominal pain", "fever"}
    assert apply_aliases("stomach pain", aliases, vocab) == "abdominal pain"
    # Target not in vocabulary -> input is returned unchanged, never invented.
    assert apply_aliases("ghost", aliases, vocab) == "ghost"


def _wide_frame():
    return pd.DataFrame(
        {
            "itching": [1, 1, 0, 0],
            "high_fever": [0, 0, 1, 1],
            "cough": [0, 1, 1, 0],
            "never_seen": [0, 0, 0, 0],
            "prognosis": ["Fungal infection", "Fungal infection", "Influenza", "Influenza"],
        }
    )


def test_detect_target_and_layout():
    df = _wide_frame()
    target = detect_target_column(df)
    assert target == "prognosis"
    assert detect_layout(df, target) == "WIDE"


def test_long_layout_detected():
    df = pd.DataFrame(
        {
            "Disease": ["Influenza", "Migraine"],
            "Symptom_1": ["high_fever", "headache"],
            "Symptom_2": ["cough", None],
        }
    )
    assert detect_layout(df, "Disease") == "LONG"


def test_feature_matrix_drops_unused_columns(tmp_path):
    path = tmp_path / "Training.csv"
    _wide_frame().to_csv(path, index=False)
    df, report = inspect_dataset(path)

    assert report.n_records == 4
    assert report.n_unique_diseases == 2
    assert "never_seen" in report.symptoms

    processed = build_feature_matrix(df, report)
    # A symptom that never occurs carries no signal and is removed.
    assert "never seen" not in processed.feature_names
    assert set(processed.disease_names) == {"Fungal infection", "Influenza"}


def test_duplicates_are_removed(tmp_path):
    df = pd.concat([_wide_frame(), _wide_frame().head(1)])
    path = tmp_path / "Training.csv"
    df.to_csv(path, index=False)
    loaded, report = inspect_dataset(path)
    assert report.duplicate_records == 1
    processed = build_feature_matrix(loaded, report)
    assert processed.rows_dropped_duplicate == 1


def test_disease_symptom_map_is_measured_support():
    X = pd.DataFrame({"fever": [1, 1], "cough": [1, 0]})
    y = pd.Series(["Flu", "Flu"])
    mapping = build_disease_symptom_map(X, y)
    assert mapping["Flu"]["fever"] == 1.0
    assert mapping["Flu"]["cough"] == 0.5


def test_missing_dataset_raises_clear_error(tmp_path):
    with pytest.raises(FileNotFoundError, match="Training.csv"):
        inspect_dataset(tmp_path / "absent.csv")
