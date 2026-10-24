# Gnomy Phenomenon Notebook

A personal, local-first Flutter web notebook for exploring an inner or social phenomenon—such as “Why can a question feel like blame?”—and developing the exploration into reflection and a linked Gnomy fairy tale. It is a writing and reflection aid, not a diagnostic tool or a source-verification system.

## Features

- Create, rename, open, and delete phenomenon workspaces.
- Capture quick notes and add structured reflection entries with separate fields for observations, feelings, interpretations, uncertainty, and possible explanations.
- Draft paired reflection and Gnomy fairy-tale documents, with paragraph-level symbol annotations.
- Create, edit, and remove symbols; attach symbols to diary entries or paragraphs.
- Add source references manually and link them to writing paragraphs. The app does not verify sources or claim they prove a passage.
- Link related workspaces in a simple phenomenon map.
- Save and reopen work in the same browser profile; export and import a notebook as JSON.

The first workspace, notes, symbols, and writing are clearly labeled **DEMO**. They are generic examples, not personal records or research sources. No citations are prefilled.

## Project structure

This is a minimal, web-first Flutter project. Its main application code is in `lib/`, web entry point is `web/index.html`, and dependencies and SDK constraints are in `pubspec.yaml`. Android and iOS platform folders are not included because this version is intended for Flutter Web and FlutLab's web target.

```text
.
├── lib/
│   ├── app.dart       # Screens, navigation, and writing workflow
│   ├── main.dart      # App startup
│   ├── models.dart    # Notebook data models and demo content
│   └── store.dart     # Local persistence and notebook operations
├── web/
│   └── index.html     # Flutter Web entry point
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## Requirements and local setup

Install Flutter with Dart satisfying the SDK constraint in `pubspec.yaml` (`>=3.3.0 <4.0.0`), then run from the project root:

```bash
flutter pub get
dart format lib
flutter analyze
flutter build web
```

To run in Chrome locally:

```bash
flutter run -d chrome
```

`flutter pub get` creates `pubspec.lock`. Commit that lockfile for this application so dependency versions stay consistent between local development and FlutLab.

## Import into FlutLab

Push this project to a GitHub repository, then use FlutLab's GitHub/repository import flow to import the repository. Select the web target and run dependency resolution/build in FlutLab. Confirm that the Flutter and Dart SDK available in FlutLab satisfy `pubspec.yaml`; dependency resolution and a successful web build have not been verified here.

## Privacy and local storage

The app stores the notebook as one JSON data bundle using `shared_preferences`. In the web build, that data is browser-managed storage associated with the current browser profile and site origin. It is not encrypted, is not synced to another device, and can be removed when browser data is cleared. Browser storage is not a durable backup; use **Settings → View JSON export** and keep a backup somewhere private. Importing JSON replaces the notebook currently in that browser. The export contains the notebook's writing and references, so protect it accordingly.

This version has no accounts, cloud sync, analytics, generative AI, external API calls, or API keys. The app does not diagnose users or automatically generate scientific claims or citations.

## Files to keep out of the repository

Do not commit:

- Generated output such as `build/`, `.dart_tool/`, `.pub/`, coverage reports, plugin-generated files, or local ZIP archives.
- Secrets and machine-specific settings: `.env` files, API keys, passwords, access tokens, signing keys/keystores, service-account files, and local tool configuration.
- Personal notebook JSON exports, screenshots, or other material containing private reflections or identifying details.

The `.gitignore` covers common Flutter build output, local configuration, and credential file patterns. Review `git status` before committing; ignore rules cannot identify private content embedded in a source file or a renamed export.

## Tests

No automated test suite is included yet.
