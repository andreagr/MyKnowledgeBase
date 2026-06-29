# MyKB Flutter App

MyKB (My Knowledge Base) — a Flutter desktop/web app for local company document search and chat.

## Run the app

From the `app/` folder:

```bash
cd app
flutter pub get
dart run flutter_launcher_icons
flutter run -d chrome
```

For desktop builds, use:

```bash
flutter run -d windows
```

## Backend base URL

The app defaults to:

```text
http://127.0.0.1:8000
```

To override the backend host, pass a Dart define:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

## Features

- Health check and backend connection status
- Upload PDF documents to the local FastAPI backend
- Browse documents with page and chunk counts
- Chat with the indexed content using `POST /chat/query`
- View cited source chunks and open selected documents
- PDF preview panel using Syncfusion Flutter PDF Viewer

## Known limitations

- Chat sessions are stored in memory only
- Document selection does not filter chat queries yet
- Citation clicks open the selected document but do not jump to a page in the PDF viewer
- No authentication or persistent storage in the frontend
- The UI is optimized for desktop and web only
