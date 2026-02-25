# Espejo

**Tech Stack:** Flutter · Supabase · Mistral

## Voraussetzungen

**Flutter**
```bash
brew install --cask flutter
```

**Chrome** – [chrome](https://www.google.com/chrome) installieren (für Web-Preview)

**Xcode** – aus dem App Store installieren (für iOS), danach:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Installation prüfen:
```bash
flutter doctor
```

## Setup

Erstelle eine `.env` Datei und trage deine Keys ein – frag Philipp falls du sie nicht hast:

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
MISTRAL_API_KEY=...
```

Dann starten mit:

```bash
make run
```

Die App läuft dann auf http://localhost:8080 – im Terminal mit **Cmd + Klick** direkt öffnen.

## Projektstruktur

```
lib/
├── main.dart
├── app.dart
├── features/
│   ├── auth/
│   ├── entries/
│   └── reflection/
├── services/
│   ├── supabase_service.dart
│   └── mistral_service.dart
├── models/
│   ├── entry.dart
│   └── reflection.dart
└── state/
    └── entry_provider.dart
```
