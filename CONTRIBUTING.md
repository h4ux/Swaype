# Contributing to Swaype

Thanks for your interest in improving Swaype! This document covers how to get
the project building locally, the conventions the codebase follows, and what a
good pull request looks like.

## Quick start

```bash
git clone https://github.com/<your-fork>/Swaype.git
cd Swaype
swift test          # run the converter unit tests
./Scripts/build.sh  # produces build/Swaype.app and build/Swaype.dmg
```

**Requirements**
- macOS 13 Ventura or later
- Full Xcode 15+ (Command Line Tools alone won't link against XCTest)
- If `swift test` complains about XCTest, run:
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## Project layout

```
Sources/
├── SwaypeCore/                  # pure, testable conversion engine — no AppKit
│   ├── LayoutConverter.swift
│   └── Mappings/
│       ├── LayoutPair.swift
│       └── EnglishHebrew.swift  # bundled fallback mapping
└── Swaype/                      # menu-bar app
    ├── SwaypeApp.swift          # @main, delegate adaptor
    ├── AppDelegate.swift        # status item, hotkey, action methods
    ├── AppState.swift           # observable state, owns the active converter
    ├── Preferences.swift        # UserDefaults-backed prefs
    ├── Services/
    │   ├── InputSourceService.swift     # Carbon TIS — enumerates installed keyboards
    │   ├── ClipboardService.swift
    │   ├── HotkeyService.swift          # KeyboardShortcuts.Name extension
    │   ├── PasteService.swift           # CGEvent ⌘C / ⌘V
    │   ├── SelectionConverter.swift     # the copy → convert → paste flow
    │   ├── AccessibilityService.swift
    │   └── LaunchAtLoginService.swift
    └── UI/
        ├── MenuBuilder.swift
        ├── SettingsWindowController.swift
        └── SettingsView.swift
Tests/
└── SwaypeCoreTests/
    └── LayoutConverterTests.swift
Scripts/
├── build.sh                 # full pipeline: build → icon → .app → DMG
├── MakeIcon.swift           # generates AppIcon.iconset
├── MakeMenuBarIcon.swift    # generates the colourful menu bar icon
└── MakeDMGBackground.swift  # generates the installer DMG background
```

The hard rule: **anything testable goes in `SwaypeCore`**. The `Swaype` target
imports AppKit and Carbon and can't be unit-tested in isolation. Keep that
boundary clean.

## Coding conventions

- Swift 5.9, targeting macOS 13. No Swift 6 concurrency strictness yet.
- `@MainActor` for everything that touches AppKit / NSStatusItem / NSPasteboard.
- Prefer Swift-style enums-as-namespaces for service singletons
  (e.g. `LaunchAtLoginService.setEnabled(...)`).
- One short doc comment per type / public function explaining *why* it exists,
  not what each line does. No multi-paragraph docstrings.
- No external dependencies unless absolutely necessary. The one we accept today
  is `KeyboardShortcuts` for global hotkey registration.
- Tests: black-box style with `XCTAssertEqual`. New layouts should ship with
  at least one happy-path test and an edge case (digits, emoji, etc.).

## Adding a new layout pair

Swaype auto-detects pairs from your installed keyboards via Carbon TIS — most
contributions don't need a new bundled mapping. But if you want to ship one
(e.g. for the "only one keyboard installed" fallback path), see
[README.md → Adding a layout pair](README.md#adding-a-bundled-layout-pair).

## Pull-request checklist

- [ ] `swift test` passes
- [ ] `./Scripts/build.sh` produces a working app + DMG
- [ ] Zero compiler warnings (we treat them as bugs)
- [ ] New behaviour is covered by a test, or the PR explains why it can't be
- [ ] No new third-party dependency was added without first opening an issue

## Reporting bugs

Open an issue with:
- macOS version
- A short reproduction (input text, the layout pair you've set in Settings,
  the expected vs. observed output)
- Screenshot of Settings if a layout pair is misbehaving

Security-sensitive reports → see [SECURITY.md](SECURITY.md).

## Releasing

CI auto-tags `main` pushes with a bumped patch version and creates a GitHub
Release with the DMG attached. To cut a major/minor release manually:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The workflow picks up the tag and publishes a release with that version
exactly (no auto-bump).
