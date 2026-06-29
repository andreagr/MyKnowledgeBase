"""Packaged backend entry point started by the desktop app."""

import os

import paths
import uvicorn


def main() -> None:
    data_dir = paths.ensure_data_dirs()
    os.environ.setdefault("RAG_DATA_DIR", str(data_dir))

    host = os.environ.get("RAG_HOST", "127.0.0.1")
    port = int(os.environ.get("RAG_PORT", "8000"))

    uvicorn.run(
        "app:app",
        host=host,
        port=port,
        log_level="info",
        access_log=False,
    )


if __name__ == "__main__":
    main()
