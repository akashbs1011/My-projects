"""
Language detection, translation, and Roman transliteration.

Detection is not keyword-based. It runs in two stages:

  1. Unicode script identification. Devanagari, Kannada, Telugu, Tamil and
     Malayalam each occupy distinct code-point blocks, so a text written in
     one of them is identified by the writing system itself.
  2. For Latin-script input, the `langdetect` statistical n-gram model.

Translation is delegated to a configured provider. No provider is bundled by
default: when TRANSLATION_PROVIDER=none the service returns the source text
unchanged and marks the result as untranslated, so the interface can tell the
user rather than silently presenting English as if it were their language.
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from functools import lru_cache
from typing import Dict, Optional

from config import get_settings

logger = logging.getLogger(__name__)

LANGUAGE_NAMES: Dict[str, str] = {
    "en": "English",
    "hi": "हिन्दी (Hindi)",
    "kn": "ಕನ್ನಡ (Kannada)",
    "te": "తెలుగు (Telugu)",
    "ta": "தமிழ் (Tamil)",
    "ml": "മലയാളം (Malayalam)",
}

# Unicode blocks for the supported Indic scripts.
SCRIPT_RANGES = {
    "hi": (0x0900, 0x097F),   # Devanagari
    "te": (0x0C00, 0x0C7F),   # Telugu
    "kn": (0x0C80, 0x0CFF),   # Kannada
    "ml": (0x0D00, 0x0D7F),   # Malayalam
    "ta": (0x0B80, 0x0BFF),   # Tamil
}

# indic-transliteration scheme names, keyed by our language codes.
_ITRANS_SCHEMES = {
    "hi": "devanagari",
    "kn": "kannada",
    "te": "telugu",
    "ta": "tamil",
    "ml": "malayalam",
}


@dataclass
class TranslationResult:
    text: str
    source_language: str
    target_language: str
    translated: bool
    provider: str
    note: Optional[str] = None


# --------------------------------------------------------------------------- #
# Detection
# --------------------------------------------------------------------------- #
def detect_script(text: str) -> Optional[str]:
    """Identify language by writing system. Returns None for Latin/other."""
    counts: Dict[str, int] = {}
    for char in text:
        code = ord(char)
        for lang, (low, high) in SCRIPT_RANGES.items():
            if low <= code <= high:
                counts[lang] = counts.get(lang, 0) + 1
                break
    if not counts:
        return None
    return max(counts, key=counts.get)


def detect_language(text: str, fallback: str = "en") -> str:
    """Two-stage detection: script first, then statistical model."""
    if not text or not text.strip():
        return fallback

    script = detect_script(text)
    if script:
        return script

    try:
        from langdetect import DetectorFactory, detect

        DetectorFactory.seed = 0
        code = detect(text)
        base = code.split("-")[0]
        supported = get_settings().SUPPORTED_LANGUAGES
        return base if base in supported else fallback
    except Exception:
        logger.debug("langdetect unavailable or failed; falling back to %s", fallback)
        return fallback


# --------------------------------------------------------------------------- #
# Transliteration
# --------------------------------------------------------------------------- #
def to_roman(text: str, language: str) -> Optional[str]:
    """
    Romanise Indic-script text using ISO 15919 via `indic-transliteration`.

    Transliteration converts the writing system only - the words, including
    medical terms, are preserved. It is not a translation.
    """
    scheme = _ITRANS_SCHEMES.get(language)
    if not scheme:
        return None
    try:
        from indic_transliteration import sanscript
        from indic_transliteration.sanscript import transliterate

        return transliterate(text, getattr(sanscript, scheme.upper()), sanscript.ISO)
    except Exception:
        logger.debug("Transliteration unavailable for %s", language)
        return None


def from_roman(text: str, language: str) -> Optional[str]:
    """Convert Roman input back into the native script (ISO 15919 -> script)."""
    scheme = _ITRANS_SCHEMES.get(language)
    if not scheme:
        return None
    try:
        from indic_transliteration import sanscript
        from indic_transliteration.sanscript import transliterate

        return transliterate(text, sanscript.ISO, getattr(sanscript, scheme.upper()))
    except Exception:
        return None


def looks_romanised(text: str) -> bool:
    """Latin characters only, but not recognisable as English by the detector."""
    if not re.fullmatch(r"[A-Za-z0-9\s\.,'\-\?!]+", text or ""):
        return False
    return detect_language(text, fallback="en") != "en"


# --------------------------------------------------------------------------- #
# Translation providers
# --------------------------------------------------------------------------- #
class TranslationService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.provider = self.settings.TRANSLATION_PROVIDER.lower()

    def translate(self, text: str, target: str, source: Optional[str] = None) -> TranslationResult:
        source = source or detect_language(text)

        if not text.strip() or source == target:
            return TranslationResult(text, source, target, False, self.provider)

        if self.provider == "none":
            return TranslationResult(
                text, source, target, False, "none",
                note=(
                    "Translation is not configured on this deployment, so this text "
                    "is shown in its original language."
                ),
            )

        try:
            translated = self._dispatch(text, source, target)
            return TranslationResult(translated, source, target, True, self.provider)
        except Exception as exc:
            logger.warning("Translation failed (%s): %s", self.provider, exc)
            return TranslationResult(
                text, source, target, False, self.provider,
                note="Translation is temporarily unavailable; showing the original text.",
            )

    def _dispatch(self, text: str, source: str, target: str) -> str:
        if self.provider == "google":
            return self._google(text, source, target)
        if self.provider == "azure":
            return self._azure(text, source, target)
        if self.provider == "indictrans2":
            return self._indictrans2(text, source, target)
        raise ValueError(f"Unknown translation provider: {self.provider}")

    # -- Google Cloud Translation ------------------------------------------ #
    def _google(self, text: str, source: str, target: str) -> str:
        from google.cloud import translate_v2 as translate

        client = translate.Client()
        result = client.translate(text, source_language=source, target_language=target)
        return result["translatedText"]

    # -- Azure AI Translator ------------------------------------------------ #
    def _azure(self, text: str, source: str, target: str) -> str:
        import httpx

        endpoint = "https://api.cognitive.microsofttranslator.com/translate"
        response = httpx.post(
            endpoint,
            params={"api-version": "3.0", "from": source, "to": target},
            headers={
                "Ocp-Apim-Subscription-Key": self.settings.TRANSLATION_API_KEY,
                "Ocp-Apim-Subscription-Region": self.settings.TRANSLATION_REGION,
                "Content-Type": "application/json",
            },
            json=[{"text": text}],
            timeout=20.0,
        )
        response.raise_for_status()
        return response.json()[0]["translations"][0]["text"]

    # -- AI4Bharat IndicTrans2 (self-hosted, no external API) --------------- #
    def _indictrans2(self, text: str, source: str, target: str) -> str:
        model, tokenizer = _load_indictrans2(source, target)
        batch = tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=256)
        generated = model.generate(**batch, max_length=256, num_beams=5)
        return tokenizer.batch_decode(generated, skip_special_tokens=True)[0]


@lru_cache(maxsize=4)
def _load_indictrans2(source: str, target: str):
    """Lazily load IndicTrans2 weights; cached so the load cost is paid once."""
    from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

    direction = "en-indic" if source == "en" else "indic-en"
    name = f"ai4bharat/indictrans2-{direction}-dist-200M"
    tokenizer = AutoTokenizer.from_pretrained(name, trust_remote_code=True)
    model = AutoModelForSeq2SeqLM.from_pretrained(name, trust_remote_code=True)
    return model, tokenizer


_service: Optional[TranslationService] = None


def get_translation_service() -> TranslationService:
    global _service
    if _service is None:
        _service = TranslationService()
    return _service


def to_english(text: str) -> tuple[str, str]:
    """Normalise arbitrary input to English for medical processing."""
    service = get_translation_service()
    source = detect_language(text)
    if source == "en":
        return text, "en"
    result = service.translate(text, target="en", source=source)
    return result.text, source


def from_english(text: str, target: str) -> TranslationResult:
    return get_translation_service().translate(text, target=target, source="en")
