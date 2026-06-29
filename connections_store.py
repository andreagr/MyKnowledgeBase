"""SQLite persistence for email connections and indexed message tracking."""

import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from paths import get_connections_db_path


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_conn() -> sqlite3.Connection:
    db_path = get_connections_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with _get_conn() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS connections (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                host TEXT NOT NULL,
                port INTEGER NOT NULL DEFAULT 993,
                username TEXT NOT NULL,
                password TEXT NOT NULL,
                folder TEXT NOT NULL DEFAULT 'INBOX',
                enabled INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                last_sync_at TEXT,
                last_sync_status TEXT,
                last_sync_message TEXT,
                indexed_count INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS indexed_messages (
                connection_id TEXT NOT NULL,
                message_id TEXT NOT NULL,
                document_id TEXT NOT NULL,
                indexed_at TEXT NOT NULL,
                PRIMARY KEY (connection_id, message_id),
                FOREIGN KEY (connection_id) REFERENCES connections(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS watched_folders (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                path TEXT NOT NULL UNIQUE,
                recursive INTEGER NOT NULL DEFAULT 1,
                enabled INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                last_scan_at TEXT,
                last_scan_status TEXT,
                last_scan_message TEXT,
                indexed_count INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS indexed_files (
                file_path TEXT PRIMARY KEY,
                document_id TEXT NOT NULL,
                folder_id TEXT,
                file_mtime REAL NOT NULL,
                file_size INTEGER NOT NULL,
                filename TEXT NOT NULL,
                indexed_at TEXT NOT NULL,
                FOREIGN KEY (folder_id) REFERENCES watched_folders(id) ON DELETE SET NULL
            );
            """
        )


def _row_to_dict(row: sqlite3.Row, include_password: bool = False) -> dict[str, Any]:
    data = {
        "id": row["id"],
        "name": row["name"],
        "host": row["host"],
        "port": row["port"],
        "username": row["username"],
        "folder": row["folder"],
        "enabled": bool(row["enabled"]),
        "created_at": row["created_at"],
        "last_sync_at": row["last_sync_at"],
        "last_sync_status": row["last_sync_status"],
        "last_sync_message": row["last_sync_message"],
        "indexed_count": row["indexed_count"],
    }
    if include_password:
        data["password"] = row["password"]
    return data


def create_connection(
    name: str,
    host: str,
    port: int,
    username: str,
    password: str,
    folder: str = "INBOX",
) -> dict[str, Any]:
    connection_id = str(uuid.uuid4())
    with _get_conn() as conn:
        conn.execute(
            """
            INSERT INTO connections
                (id, name, host, port, username, password, folder, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (connection_id, name, host, port, username, password, folder, _utc_now()),
        )
        row = conn.execute(
            "SELECT * FROM connections WHERE id = ?", (connection_id,)
        ).fetchone()
    return _row_to_dict(row)


def list_connections() -> list[dict[str, Any]]:
    with _get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM connections ORDER BY created_at DESC"
        ).fetchall()
    return [_row_to_dict(row) for row in rows]


def get_connection(connection_id: str, include_password: bool = False) -> dict[str, Any] | None:
    with _get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM connections WHERE id = ?", (connection_id,)
        ).fetchone()
    if row is None:
        return None
    return _row_to_dict(row, include_password=include_password)


def update_connection(connection_id: str, **fields: Any) -> dict[str, Any] | None:
    allowed = {"name", "host", "port", "username", "password", "folder", "enabled"}
    updates = {k: v for k, v in fields.items() if k in allowed and v is not None}
    if not updates:
        return get_connection(connection_id)

    if "enabled" in updates:
        updates["enabled"] = int(bool(updates["enabled"]))

    set_clause = ", ".join(f"{key} = ?" for key in updates)
    values = list(updates.values()) + [connection_id]

    with _get_conn() as conn:
        conn.execute(
            f"UPDATE connections SET {set_clause} WHERE id = ?", values
        )
        row = conn.execute(
            "SELECT * FROM connections WHERE id = ?", (connection_id,)
        ).fetchone()
    return _row_to_dict(row) if row else None


def delete_connection(connection_id: str) -> bool:
    with _get_conn() as conn:
        cursor = conn.execute(
            "DELETE FROM connections WHERE id = ?", (connection_id,)
        )
    return cursor.rowcount > 0


def update_sync_status(
    connection_id: str,
    status: str,
    message: str,
    new_messages: int = 0,
) -> None:
    with _get_conn() as conn:
        if new_messages > 0:
            conn.execute(
                """
                UPDATE connections
                SET last_sync_at = ?, last_sync_status = ?, last_sync_message = ?,
                    indexed_count = indexed_count + ?
                WHERE id = ?
                """,
                (_utc_now(), status, message, new_messages, connection_id),
            )
        else:
            conn.execute(
                """
                UPDATE connections
                SET last_sync_at = ?, last_sync_status = ?, last_sync_message = ?
                WHERE id = ?
                """,
                (_utc_now(), status, message, connection_id),
            )


def is_message_indexed(connection_id: str, message_id: str) -> bool:
    with _get_conn() as conn:
        row = conn.execute(
            """
            SELECT 1 FROM indexed_messages
            WHERE connection_id = ? AND message_id = ?
            """,
            (connection_id, message_id),
        ).fetchone()
    return row is not None


def mark_message_indexed(
    connection_id: str, message_id: str, document_id: str
) -> None:
    with _get_conn() as conn:
        conn.execute(
            """
            INSERT OR IGNORE INTO indexed_messages
                (connection_id, message_id, document_id, indexed_at)
            VALUES (?, ?, ?, ?)
            """,
            (connection_id, message_id, document_id, _utc_now()),
        )


def get_indexed_document_ids(connection_id: str) -> list[str]:
    with _get_conn() as conn:
        rows = conn.execute(
            "SELECT document_id FROM indexed_messages WHERE connection_id = ?",
            (connection_id,),
        ).fetchall()
    return [row["document_id"] for row in rows]


# -------------------------------------------------------------------
# Watched folders
# -------------------------------------------------------------------


def _folder_row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "name": row["name"],
        "path": row["path"],
        "recursive": bool(row["recursive"]),
        "enabled": bool(row["enabled"]),
        "created_at": row["created_at"],
        "last_scan_at": row["last_scan_at"],
        "last_scan_status": row["last_scan_status"],
        "last_scan_message": row["last_scan_message"],
        "indexed_count": row["indexed_count"],
    }


def create_watched_folder(name: str, path: str, recursive: bool = True) -> dict[str, Any]:
    folder_id = str(uuid.uuid4())
    resolved = str(Path(path).resolve())
    with _get_conn() as conn:
        conn.execute(
            """
            INSERT INTO watched_folders (id, name, path, recursive, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (folder_id, name, resolved, int(recursive), _utc_now()),
        )
        row = conn.execute(
            "SELECT * FROM watched_folders WHERE id = ?", (folder_id,)
        ).fetchone()
    return _folder_row_to_dict(row)


def list_watched_folders() -> list[dict[str, Any]]:
    with _get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM watched_folders ORDER BY created_at DESC"
        ).fetchall()
    return [_folder_row_to_dict(row) for row in rows]


def get_watched_folder(folder_id: str) -> dict[str, Any] | None:
    with _get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM watched_folders WHERE id = ?", (folder_id,)
        ).fetchone()
    return _folder_row_to_dict(row) if row else None


def delete_watched_folder(folder_id: str) -> bool:
    with _get_conn() as conn:
        cursor = conn.execute(
            "DELETE FROM watched_folders WHERE id = ?", (folder_id,)
        )
    return cursor.rowcount > 0


def update_watched_folder(folder_id: str, **fields: Any) -> dict[str, Any] | None:
    allowed = {"name", "recursive", "enabled"}
    updates = {k: v for k, v in fields.items() if k in allowed and v is not None}
    if not updates:
        return get_watched_folder(folder_id)

    if "recursive" in updates:
        updates["recursive"] = int(bool(updates["recursive"]))
    if "enabled" in updates:
        updates["enabled"] = int(bool(updates["enabled"]))

    set_clause = ", ".join(f"{key} = ?" for key in updates)
    values = list(updates.values()) + [folder_id]

    with _get_conn() as conn:
        conn.execute(
            f"UPDATE watched_folders SET {set_clause} WHERE id = ?", values
        )
        row = conn.execute(
            "SELECT * FROM watched_folders WHERE id = ?", (folder_id,)
        ).fetchone()
    return _folder_row_to_dict(row) if row else None


def update_folder_scan_status(
    folder_id: str,
    status: str,
    message: str,
    new_files: int = 0,
) -> None:
    with _get_conn() as conn:
        if new_files > 0:
            conn.execute(
                """
                UPDATE watched_folders
                SET last_scan_at = ?, last_scan_status = ?, last_scan_message = ?,
                    indexed_count = indexed_count + ?
                WHERE id = ?
                """,
                (_utc_now(), status, message, new_files, folder_id),
            )
        else:
            conn.execute(
                """
                UPDATE watched_folders
                SET last_scan_at = ?, last_scan_status = ?, last_scan_message = ?
                WHERE id = ?
                """,
                (_utc_now(), status, message, folder_id),
            )


def get_indexed_file(file_path: str) -> dict[str, Any] | None:
    resolved = str(Path(file_path).resolve())
    with _get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM indexed_files WHERE file_path = ?", (resolved,)
        ).fetchone()
    if row is None:
        return None
    return {
        "file_path": row["file_path"],
        "document_id": row["document_id"],
        "folder_id": row["folder_id"],
        "file_mtime": row["file_mtime"],
        "file_size": row["file_size"],
        "filename": row["filename"],
        "indexed_at": row["indexed_at"],
    }


def mark_file_indexed(
    file_path: str,
    document_id: str,
    filename: str,
    file_mtime: float,
    file_size: int,
    folder_id: str | None = None,
) -> None:
    resolved = str(Path(file_path).resolve())
    with _get_conn() as conn:
        conn.execute(
            """
            INSERT INTO indexed_files
                (file_path, document_id, folder_id, file_mtime, file_size, filename, indexed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(file_path) DO UPDATE SET
                document_id = excluded.document_id,
                folder_id = excluded.folder_id,
                file_mtime = excluded.file_mtime,
                file_size = excluded.file_size,
                filename = excluded.filename,
                indexed_at = excluded.indexed_at
            """,
            (resolved, document_id, folder_id, file_mtime, file_size, filename, _utc_now()),
        )


def list_all_indexed_files() -> list[dict[str, Any]]:
    with _get_conn() as conn:
        rows = conn.execute("SELECT * FROM indexed_files ORDER BY indexed_at DESC").fetchall()
    return [
        {
            "file_path": row["file_path"],
            "document_id": row["document_id"],
            "folder_id": row["folder_id"],
            "file_mtime": row["file_mtime"],
            "file_size": row["file_size"],
            "filename": row["filename"],
            "indexed_at": row["indexed_at"],
        }
        for row in rows
    ]


def get_indexed_file_by_document_id(document_id: str) -> dict[str, Any] | None:
    with _get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM indexed_files WHERE document_id = ?", (document_id,)
        ).fetchone()
    if row is None:
        return None
    return {
        "file_path": row["file_path"],
        "document_id": row["document_id"],
        "folder_id": row["folder_id"],
        "file_mtime": row["file_mtime"],
        "file_size": row["file_size"],
        "filename": row["filename"],
        "indexed_at": row["indexed_at"],
    }


def delete_indexed_file_by_document_id(document_id: str) -> bool:
    with _get_conn() as conn:
        cursor = conn.execute(
            "DELETE FROM indexed_files WHERE document_id = ?", (document_id,)
        )
    return cursor.rowcount > 0


def delete_indexed_message_by_document_id(document_id: str) -> bool:
    with _get_conn() as conn:
        cursor = conn.execute(
            "DELETE FROM indexed_messages WHERE document_id = ?", (document_id,)
        )
    return cursor.rowcount > 0


def get_indexed_message_by_document_id(document_id: str) -> dict[str, Any] | None:
    with _get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM indexed_messages WHERE document_id = ?", (document_id,)
        ).fetchone()
    if row is None:
        return None
    return {
        "connection_id": row["connection_id"],
        "message_id": row["message_id"],
        "document_id": row["document_id"],
        "indexed_at": row["indexed_at"],
    }


def list_all_indexed_messages() -> list[dict[str, Any]]:
    with _get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM indexed_messages ORDER BY indexed_at DESC"
        ).fetchall()
    return [
        {
            "connection_id": row["connection_id"],
            "message_id": row["message_id"],
            "document_id": row["document_id"],
            "indexed_at": row["indexed_at"],
        }
        for row in rows
    ]


def get_document_indexed_at(document_id: str) -> str | None:
    with _get_conn() as conn:
        row = conn.execute(
            "SELECT indexed_at FROM indexed_files WHERE document_id = ?",
            (document_id,),
        ).fetchone()
        if row:
            return row["indexed_at"]
        row = conn.execute(
            "SELECT indexed_at FROM indexed_messages WHERE document_id = ?",
            (document_id,),
        ).fetchone()
        if row:
            return row["indexed_at"]
    return None
