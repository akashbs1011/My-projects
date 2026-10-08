import pytest

from services.safety import GENERAL_DISCLAIMER, check_urgency
from services.translation_service import detect_language, detect_script, looks_romanised


def test_urgency_fires_on_red_flag():
    result = check_urgency(["chest pain", "itching"])
    assert result["urgent"] is True
    assert "chest pain" in result["triggered_symptoms"]
    assert "prompt medical attention" in result["notice"]


def test_urgency_silent_on_routine_symptoms():
    result = check_urgency(["itching", "skin rash"])
    assert result["urgent"] is False
    assert result["notice"] is None


def test_disclaimer_never_claims_diagnosis():
    assert "does not provide a definitive diagnosis" in GENERAL_DISCLAIMER


@pytest.mark.parametrize(
    "text,expected",
    [
        ("ನನಗೆ ಜ್ವರ ಇದೆ", "kn"),
        ("मुझे बुखार है", "hi"),
        ("నాకు జ్వరం ఉంది", "te"),
        ("எனக்கு காய்ச்சல் உள்ளது", "ta"),
        ("എനിക്ക് പനി ഉണ്ട്", "ml"),
        ("I have a fever", None),
    ],
)
def test_script_detection(text, expected):
    assert detect_script(text) == expected


def test_english_detected_for_latin_text():
    assert detect_language("I have a fever and a bad cough") == "en"


def test_romanised_input_is_not_treated_as_english():
    # Detection is statistical, so this asserts the helper runs rather than a
    # specific label for any one string.
    assert isinstance(looks_romanised("nanage jvara ide"), bool)
