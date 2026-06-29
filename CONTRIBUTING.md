# Contributing to MyKnowledgeBase

Thanks for your interest in improving MyKnowledgeBase.

## Development setup

1. Clone the repository.
2. Install Python dependencies:
   - `pip install -r requirements.txt`
3. Start backend:
   - `python backend_main.py`
4. Start Flutter app from `app/`:
   - `flutter pub get`
   - `flutter run -d windows`

## Pull request guidelines

- Keep PRs focused and reasonably small.
- Include context: what changed and why.
- Add or update tests when applicable.
- Verify the app still starts and core flows (upload/search/chat) still work.

## Code style

- Follow existing style in each language.
- Prefer clear names and small functions over large monolithic changes.
- Avoid introducing secrets into source control.

## Reporting bugs

Please include:

- Steps to reproduce
- Expected behavior
- Actual behavior
- Logs or screenshots when available
- OS/environment details
