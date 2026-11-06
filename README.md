<div align="center">

# Rhythm

**Cross-platform schedule companion for Tula State University students**

[![Build Android APK](https://github.com/kyomufs/Rhythm/actions/workflows/android-build.yml/badge.svg)](https://github.com/kyomufs/Rhythm/actions/workflows/android-build.yml)
[![Build iOS IPA](https://github.com/kyomufs/Rhythm/actions/workflows/ios-build.yml/badge.svg)](https://github.com/kyomufs/Rhythm/actions/workflows/ios-build.yml)
[![Release](https://github.com/kyomufs/Rhythm/actions/workflows/release.yml/badge.svg)](https://github.com/kyomufs/Rhythm/actions/workflows/release.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.4-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Material Design 3](https://img.shields.io/badge/Material%20Design-3-6750A4)](https://m3.material.io)

</div>

Rhythm turns the open TulSU schedule API into a fast, local-first mobile
app: live schedule with a change journal, subject notes, grades and task
tracking — all wrapped in a Material You (MD3) UI with dynamic theming.

## Features

- 📅 **Schedule** — live timetable from the open TulSU API, weekly/day view,
  groups, teachers, and offline cache; built-in demo mode without a network
- 🔄 **Change journal** — field-level diff of schedule updates
  (what changed, when, and what it was before), grouped by day
- 📝 **Notes** — per-subject notebooks with subfolders and rich structure
- 🎯 **Tasks** — status, priority, due dates and grades per subject
- 📊 **Grades** — performance tracking with statistics
- 🎨 **Material You** — dynamic color from a seed color, light/dark themes,
  M3 components (NavigationBar, SegmentedButton, Fitted type scale)
- 🔔 **Notifications** — alerts for schedule changes
- 🚀 **Self-updater (Android)** — checks GitHub releases on launch and
  offers a one-tap update with a download progress bar
- 📴 **Local-first** — Hive storage, no account required

## Installation

### iOS — SideStore

Tap the link on a device with SideStore installed to add the source:

**[Add Rhythm to SideStore](sidestore://source?url=https://raw.githubusercontent.com/kyomufs/Rhythm/main/sidestore/source.json)**

Manual fallback (SideStore → Settings → Sources → `+` → paste):

```
https://raw.githubusercontent.com/kyomufs/Rhythm/main/sidestore/source.json
```

> `sidestore/source.json` updates itself: right after each release is
> published, `release.yml` rewrites `version`, `versionDate`,
> `downloadURL` and `size` and pushes the change back to `main` — no
> manual edits needed.

### Android

Grab `Rhythm-<tag>.apk` from
[Releases](https://github.com/kyomufs/Rhythm/releases), or install an
older build and let the in-app updater offer the new one.

## Platforms

| Android | iOS | Web | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ |

## Getting started

### Prerequisites

- Flutter **3.47.4** (or just [Nix](https://nixos.org/download/): the flake
  pins the whole toolchain)

### Run

```bash
cd rhythm
flutter pub get
flutter run            # or: flutter run -d chrome / windows / linux
```

With Nix the toolchain comes from the repo:

```bash
nix develop             # Flutter + JDK pinned by flake.lock
cd rhythm && flutter run
```

### Build releases locally

```bash
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release     # requires macOS + Xcode
```

### Ключ подписи Android

Android принимает обновление только от того же ключа, которым подписан
установленный APK. В релизном workflow ключ берётся из секретов репозитория;
без него APK подписывается debug-сертификатом, который в каждом прогоне CI
новый — и установка падает с «конфликтует с другим пакетом».

Ключ создаётся один раз (пароль и alias — свои, дальше они же в секретах):

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias rhythm
base64 -w0 upload-keystore.jks > keystore.b64   # содержимое → в секрет
```

Секреты в **Settings → Secrets and variables → Actions**:

| Секрет | Значение |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | вывод `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_ALIAS` | `rhythm` |
| `ANDROID_KEY_PASSWORD` | пароль ключа |

Локально те же четыре значения кладутся в `rhythm/android/key.properties`
(файл в `.gitignore`):

```properties
storeFile=upload-keystore.jks
storePassword=…
keyAlias=rhythm
keyPassword=…
```

## CI/CD

GitHub Actions builds both platforms on every push to `main`:

| Workflow | Trigger | Result |
|---|---|---|
| `android-build.yml` | push to `main`, PRs | tests + downloadable APK artifact |
| `ios-build.yml` | push to `main` | tests-free unsigned IPA artifact |
| `release.yml` | tag `v*` | **GitHub Release** with `Rhythm-<tag>.apk` and `Rhythm-<tag>.ipa` |

Cut a release:

```bash
git tag -a v1.1.0 -m "Rhythm v1.1.0"
git push origin v1.1.0
```

That is all — the release workflow also refreshes
`sidestore/source.json` for the new version automatically (see
Installation above).

## Project structure

```
rhythm/
├── lib/
│   ├── core/                 # theme, storage, notifications, models
│   ├── features/
│   │   ├── schedule/         # timetable + change journal
│   │   ├── notes/            # subjects, subfolders, tasks
│   │   ├── performance/      # grades & statistics
│   │   └── profile/          # settings, onboarding
│   └── app.dart              # shell + navigation
├── test/                     # unit & widget tests
├── android/  ios/  web/  windows/  linux/
└── pubspec.yaml
```

## Design

Rhythm follows [Material Design 3](https://m3.material.io):

- color roles come from `ColorScheme.fromSeed()` (no hard-coded surfaces)
- tonal surfaces instead of elevation shadows
- MD3 components (`NavigationBar`, `SegmentedButton`, cards, dialogs)
