# Packaging for end users



This folder contains scripts to build a **one-click Windows install** for non-technical users. The Flutter app automatically starts and stops the Python backend (Qdrant + SQLite) — no terminals, servers, or manual setup.



## What gets bundled



| Component | How it runs |

|-----------|-------------|

| Flutter UI | `mykb.exe` |

| FastAPI backend | Started automatically from `backend/` on app launch |

| Qdrant (embedded) | Inside the backend process |

| SQLite databases | `%LOCALAPPDATA%\MyKB\data\` |

| Uploaded PDFs | Same data folder |



## Build requirements (your machine only)



- Flutter SDK with Windows desktop enabled

- Internet access for the first backend runtime build (downloads embeddable Python 3.12 + pip packages)

- (Optional) [Inno Setup](https://jrsoftware.org/isinfo.php) for a `.exe` installer

The installer bundles a **portable embeddable Python** next to `mykb.exe`. End users do **not** need Python installed. Do not ship a developer `venv` — it contains absolute paths to your machine in `pyvenv.cfg`.



## Build steps



From the repository root in PowerShell:



```powershell

# Full rebuild (backend runtime + Flutter app + release folder)

.\build-release.ps1



# Faster rebuild when you only changed Flutter/UI (skips pip reinstall)

.\build-release.ps1 -Fast



# Optional: create MyKB-Setup.exe (Inno Setup — PATH not required)

.\build-installer.ps1

```



Equivalent direct script: `.\packaging\build-windows.ps1`



Output:



- **Portable folder:** `packaging\release\MyKB\`

- **Installer:** `packaging\installer\MyKB-Setup.exe`



## Give to users



**Option A — Installer (recommended):** Send `MyKB-Setup.exe`. They run it, click through the wizard, launch from Start Menu.



**Option B — Zip folder:** Zip `packaging\release\MyKB\` and tell users to extract and run `mykb.exe`.



## Install size



The packaged build targets **~300–450 MB** (down from ~1.1 GB) by using **FastEmbed + ONNX** instead of PyTorch for document embeddings. The embedding model (~80 MB) downloads on first use into `%LOCALAPPDATA%\\MyKB\\data\\models\\`.



## First launch



The first startup may take 1–3 minutes while the embedding model downloads and loads. A startup screen is shown automatically. After that, the app works offline for document search; an LLM API key can be configured in **Intelligence** settings.



## Development mode



When running `flutter run` without a `backend/` folder next to the executable, the app expects an already-running backend:



```powershell

uvicorn app:app --host 127.0.0.1 --port 8000

```

