#!/usr/bin/env python
"""
Seed the diseases and symptoms collections from the dataset files.

    python seed_reference_data.py

Descriptions, precautions and severity weights are read from the supplementary
CSVs that ship with the Kaggle symptom-disease dataset:

    symptom_Description.csv   Disease, Description
    symptom_precaution.csv    Disease, Precaution_1..4
    Symptom-severity.csv      Symptom, weight

If a file is absent the corresponding field is left empty and the API reports
"Information is not available in the current knowledge base." Nothing is
substituted or written from the application's own knowledge.
"""
from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import Dict

import pandas as pd

from config import get_settings
from database import close_database_connection, connect_to_database, get_database
from services.preprocessing import normalize_symptom
from utils.helpers import slugify, utcnow

logging.basicConfig(level=logging.INFO, format="%(levelname)-8s %(message)s")
logger = logging.getLogger("seed")


def _read(path: Path) -> pd.DataFrame | None:
    if not path.exists():
        logger.warning("Not found, skipping: %s", path.name)
        return None
    df = pd.read_csv(path)
    df.columns = [c.strip() for c in df.columns]
    return df


async def main() -> int:
    settings = get_settings()
    await connect_to_database()
    db = get_database()

    descriptions: Dict[str, str] = {}
    df = _read(settings.DESCRIPTION_CSV)
    if df is not None:
        key, value = df.columns[0], df.columns[1]
        descriptions = {
            str(r[key]).strip(): str(r[value]).strip()
            for _, r in df.iterrows()
            if pd.notna(r[value])
        }
        logger.info("Loaded %d disease descriptions", len(descriptions))

    precautions: Dict[str, list] = {}
    df = _read(settings.PRECAUTION_CSV)
    if df is not None:
        key = df.columns[0]
        cols = [c for c in df.columns[1:]]
        precautions = {
            str(r[key]).strip(): [str(r[c]).strip() for c in cols if pd.notna(r[c]) and str(r[c]).strip()]
            for _, r in df.iterrows()
        }
        logger.info("Loaded precautions for %d diseases", len(precautions))

    severity: Dict[str, int] = {}
    df = _read(settings.SEVERITY_CSV)
    if df is not None:
        key, value = df.columns[0], df.columns[1]
        severity = {
            normalize_symptom(r[key]): int(r[value])
            for _, r in df.iterrows()
            if pd.notna(r[value])
        }
        logger.info("Loaded severity weights for %d symptoms", len(severity))

    # Disease and symptom names come from the processed dataset only.
    import json

    processed = settings.PROCESSED_DIR
    diseases_file, symptoms_file = processed / "diseases.json", processed / "symptoms.json"
    if not diseases_file.exists():
        logger.error("Run `python train_model.py` first - processed artifacts are missing.")
        await close_database_connection()
        return 1

    disease_names = json.loads(diseases_file.read_text(encoding="utf-8"))
    symptom_names = json.loads(symptoms_file.read_text(encoding="utf-8"))
    disease_symptom_map = json.loads(
        (processed / "disease_symptom_map.json").read_text(encoding="utf-8")
    )

    written = 0
    for name in disease_names:
        supports = disease_symptom_map.get(name, {})
        weights = [severity[s] for s in supports if s in severity]
        await db.diseases.update_one(
            {"slug": slugify(name)},
            {
                "$set": {
                    "name": name,
                    "slug": slugify(name),
                    "overview": descriptions.get(name, ""),
                    "precautions": precautions.get(name, []),
                    "severity": (
                        {"mean_symptom_weight": round(sum(weights) / len(weights), 2),
                         "max_symptom_weight": max(weights),
                         "scale": "Symptom-severity.csv weights, 1-7"}
                        if weights else None
                    ),
                    "source": "Kaggle symptom-disease dataset",
                    "updated_at": utcnow(),
                }
            },
            upsert=True,
        )
        written += 1
    logger.info("Upserted %d diseases", written)

    for name in symptom_names:
        await db.symptoms.update_one(
            {"name": name},
            {"$set": {"name": name, "severity_weight": severity.get(name), "updated_at": utcnow()}},
            upsert=True,
        )
    logger.info("Upserted %d symptoms", len(symptom_names))

    missing = [d for d in disease_names if d not in descriptions]
    if missing:
        logger.warning(
            "%d diseases have no description in the supplementary files; the API "
            "will report them as not available in the knowledge base.", len(missing)
        )

    await close_database_connection()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
