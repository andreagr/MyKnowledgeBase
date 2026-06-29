"""SQLite persistence for application settings (LLM / intelligence config)."""

import json
import sqlite3
from datetime import datetime, timezone
from typing import Any, Literal

from paths import get_settings_db_path

import llm_providers

KeySource = Literal["custom"]
DEFAULT_KEY_SOURCE: KeySource = "custom"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_conn() -> sqlite3.Connection:
    db_path = get_settings_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def _mask_api_key(api_key: str) -> str:
    if not api_key:
        return ""
    if len(api_key) <= 8:
        return "••••••••"
    return f"{api_key[:3]}...{api_key[-4:]}"


def _migrate_schema(conn: sqlite3.Connection) -> None:
    columns = {row[1] for row in conn.execute("PRAGMA table_info(intelligence_settings)")}
    if "provider" not in columns:
        conn.execute(
            "ALTER TABLE intelligence_settings ADD COLUMN provider TEXT NOT NULL DEFAULT 'deepseek'"
        )
    if "custom_api_keys" not in columns:
        conn.execute(
            "ALTER TABLE intelligence_settings ADD COLUMN custom_api_keys TEXT NOT NULL DEFAULT '{}'"
        )
        row = conn.execute(
            "SELECT custom_api_key FROM intelligence_settings WHERE id = 1"
        ).fetchone()
        if row and row["custom_api_key"]:
            keys = json.dumps({"deepseek": row["custom_api_key"]})
            conn.execute(
                "UPDATE intelligence_settings SET custom_api_keys = ? WHERE id = 1",
                (keys,),
            )


def init_db() -> None:
    with _get_conn() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS intelligence_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                key_source TEXT NOT NULL DEFAULT 'custom',
                custom_api_key TEXT,
                custom_api_keys TEXT NOT NULL DEFAULT '{}',
                provider TEXT NOT NULL DEFAULT 'deepseek',
                model TEXT NOT NULL DEFAULT 'deepseek-chat',
                updated_at TEXT NOT NULL
            );
            """
        )
        _migrate_schema(conn)
        row = conn.execute("SELECT id FROM intelligence_settings WHERE id = 1").fetchone()
        if row is None:
            default_provider = llm_providers.DEFAULT_PROVIDER_ID
            default_model = llm_providers.get_provider(default_provider).default_model
            conn.execute(
                """
                INSERT INTO intelligence_settings (
                    id, key_source, custom_api_key, custom_api_keys, provider, model, updated_at
                )
                VALUES (1, ?, NULL, '{}', ?, ?, ?)
                """,
                (DEFAULT_KEY_SOURCE, default_provider, default_model, _utc_now()),
            )


def _load_custom_api_keys(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    return {str(k): str(v) for k, v in data.items() if v}


def _get_row() -> sqlite3.Row | None:
    with _get_conn() as conn:
        return conn.execute(
            """
            SELECT key_source, provider, model, custom_api_keys, updated_at
            FROM intelligence_settings WHERE id = 1
            """
        ).fetchone()


def get_intelligence_settings() -> dict[str, Any]:
    row = _get_row()
    provider_id = llm_providers.DEFAULT_PROVIDER_ID
    model = llm_providers.get_provider(provider_id).default_model
    key_source = DEFAULT_KEY_SOURCE
    updated_at = None
    custom_keys: dict[str, str] = {}

    if row is not None:
        provider_id = row["provider"] or llm_providers.DEFAULT_PROVIDER_ID
        key_source = row["key_source"] or DEFAULT_KEY_SOURCE
        model = row["model"] or llm_providers.get_provider(provider_id).default_model
        updated_at = row["updated_at"]
        custom_keys = _load_custom_api_keys(row["custom_api_keys"])

    if provider_id not in llm_providers.PROVIDERS:
        provider_id = llm_providers.DEFAULT_PROVIDER_ID
        model = llm_providers.get_provider(provider_id).default_model

    provider = llm_providers.get_provider(provider_id)
    if model not in provider.models:
        model = provider.default_model

    providers = llm_providers.list_providers(custom_keys)
    selected = next((p for p in providers if p["id"] == provider_id), None)
    custom_key = custom_keys.get(provider_id, "")
    return {
        "provider": provider_id,
        "provider_name": provider.name,
        "model": model,
        "has_custom_key": selected["has_custom_key"] if selected else bool(custom_key),
        "api_key_preview": selected["api_key_preview"] if selected else _mask_api_key(custom_key),
        "available_models": list(provider.models),
        "available_providers": providers,
        "updated_at": updated_at,
    }


def get_effective_api_key(provider_id: str | None = None) -> str:
    row = _get_row()
    provider = provider_id or (
        row["provider"] if row else llm_providers.DEFAULT_PROVIDER_ID
    )
    if row is None:
        return ""
    custom_keys = _load_custom_api_keys(row["custom_api_keys"])
    return custom_keys.get(provider, "").strip()


def get_effective_provider() -> str:
    row = _get_row()
    if row is None:
        return llm_providers.DEFAULT_PROVIDER_ID
    provider = row["provider"] or llm_providers.DEFAULT_PROVIDER_ID
    if provider not in llm_providers.PROVIDERS:
        return llm_providers.DEFAULT_PROVIDER_ID
    return provider


def get_effective_model() -> str:
    row = _get_row()
    provider_id = get_effective_provider()
    provider = llm_providers.get_provider(provider_id)
    if row is None:
        return provider.default_model
    model = row["model"] or provider.default_model
    if model not in provider.models:
        return provider.default_model
    return model


def update_intelligence_settings(
    *,
    provider: str,
    model: str,
    api_key: str | None = None,
) -> dict[str, Any]:
    if provider not in llm_providers.PROVIDERS:
        raise ValueError(f"provider must be one of: {', '.join(llm_providers.PROVIDERS)}")

    provider_info = llm_providers.get_provider(provider)
    if model not in provider_info.models:
        raise ValueError(f"model must be one of: {', '.join(provider_info.models)}")

    with _get_conn() as conn:
        row = conn.execute(
            "SELECT custom_api_keys FROM intelligence_settings WHERE id = 1"
        ).fetchone()
        custom_keys = _load_custom_api_keys(row["custom_api_keys"] if row else "{}")

        custom_key = (api_key or "").strip() or custom_keys.get(provider, "")
        if not custom_key:
            raise ValueError(f"A {provider_info.name} API key is required")

        custom_keys[provider] = custom_key

        conn.execute(
            """
            UPDATE intelligence_settings
            SET provider = ?, key_source = ?, custom_api_keys = ?, model = ?, updated_at = ?
            WHERE id = 1
            """,
            (
                provider,
                DEFAULT_KEY_SOURCE,
                json.dumps(custom_keys),
                model,
                _utc_now(),
            ),
        )

    return get_intelligence_settings()
