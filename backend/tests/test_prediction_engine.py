from services.prediction_engine import PredictionEngine


def test_explanation_reports_counts_without_clinical_claims():
    text = PredictionEngine._explain(3, 4, 6)
    assert "3 of your 4 selected symptoms" in text
    assert "prediction dataset" in text
    for forbidden in ("you have", "diagnosis", "diagnosed"):
        assert forbidden not in text.lower()


def test_explanation_when_nothing_matches():
    text = PredictionEngine._explain(0, 3, 5)
    assert "None of the selected symptoms" in text


def test_explanation_when_dataset_has_no_characteristic_symptoms():
    text = PredictionEngine._explain(0, 2, 0)
    assert "no symptom overlap" in text


def test_singular_grammar():
    assert "1 of your 2 selected symptom matches" in PredictionEngine._explain(1, 2, 4)


def test_unloaded_engine_reports_not_ready():
    engine = PredictionEngine()
    assert engine.is_ready is False
    assert engine.symptom_vocabulary() == []
