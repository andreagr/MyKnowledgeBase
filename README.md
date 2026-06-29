# MyKnowledgeBase (MyKB)

Local-first knowledge base for company documents: upload PDFs, index content with embeddings, and chat over your data from a desktop app.

## What this project includes

- Flutter desktop frontend (`app/`) for document management and chat UX.
- FastAPI backend (repo root) for ingestion, indexing, retrieval, and generation.
- Local vector store (Qdrant), SQLite metadata stores, and local data persistence.
- Windows packaging scripts (`packaging/`) for non-technical end users.

## Repository structure

- `app/` - Flutter application.
- `app.py` - Main FastAPI API routes.
- `backend_main.py` - Backend entrypoint used by the desktop app.
- `connections_store.py`, `settings_store.py` - SQLite persistence layers.
- `local_llm/` - Local LLM compatibility and catalog utilities.
- `packaging/` - Runtime setup, release build, and installer scripts.
- `docs/` - Design and planning documentation.

## Quick start (developer mode)

### 1) Backend

Use your preferred Python environment and install dependencies:

```bash
pip install -r requirements.txt
```

Start the backend:

```bash
python backend_main.py
```

The API will run on `http://127.0.0.1:8000` by default.

### 2) Flutter app

From `app/`:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run -d windows
```

When run from IDE/dev mode, the Flutter app expects the backend to already be running.

## Build for Windows distribution

From repo root:

```powershell
.\build-release.ps1
```

To also generate an installer:

```powershell
.\build-release.ps1 -CreateInstaller
```

See `packaging/README.md` for packaging details.

## Security and secrets

- Do not commit API keys or private credentials.
- Use `.env.example` as template for local setup.
- Runtime user data lives under `%LOCALAPPDATA%\MyKB\data`.

## Contributing

Contributions are welcome. Please open an issue for substantial changes first.

1. Fork the repo.
2. Create a feature branch.
3. Add/adjust tests where possible.
4. Submit a pull request with a clear description.

## License

This project is licensed under the MIT License. See `LICENSE`.
