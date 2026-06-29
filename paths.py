"""Resolve persistent data directories for dev and packaged installs."""

import os
import sys
from pathlib import Path


def get_data_dir() -> Path:
    """Return the root folder for SQLite, Qdrant, uploads, and models."""
    override = os.environ.get("RAG_DATA_DIR")
    if override:
        return Path(override)

    if getattr(sys, "frozen", False):
        local_app_data = os.environ.get("LOCALAPPDATA")
        base = Path(local_app_data) if local_app_data else Path.home() / "AppData" / "Local"
        return base / "MyKB" / "data"

    return Path("./data")


def get_docs_dir() -> Path:
    return get_data_dir() / "docs"


def get_qdrant_path() -> str:
    return str(get_data_dir() / "qdrant")


def get_connections_db_path() -> Path:
    return get_data_dir() / "connections.db"


def get_settings_db_path() -> Path:
    return get_data_dir() / "settings.db"


def get_models_dir() -> Path:
    return get_data_dir() / "models"


def ensure_data_dirs() -> Path:
    data_dir = get_data_dir()
    get_docs_dir().mkdir(parents=True, exist_ok=True)
    (data_dir / "qdrant").mkdir(parents=True, exist_ok=True)
    get_models_dir().mkdir(parents=True, exist_ok=True)
    return data_dir
