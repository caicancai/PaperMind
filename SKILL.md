---
name: moepeek-swift-app
description: Use this skill when working on the MoePeek macOS SwiftUI+AppKit codebase, including build/run steps, architecture-aware edits, translation flow changes, and code reviews focused on Swift concurrency, UI state, and memory-leak risks.
---

# MoePeek Repo Skill

Apply this skill for tasks in the MoePeek repository.

## Build and Run

This project uses Tuist + Swift Package Manager.

```bash
tuist install && tuist generate
xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug build
open MoePeek.xcworkspace
```

Regenerate project files after `Project.swift` or `Package.swift` changes:

```bash
tuist generate
```

## Stack and Constraints

- Swift 6+, strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- macOS 14+ menu bar app (`LSUIElement`)
- SwiftUI + AppKit hybrid (SwiftUI views, AppKit window/panel lifecycle)
- Dependencies: `KeyboardShortcuts`, `Defaults`

## Core Architecture

Primary flow:

1. User triggers translation (shortcut, selection, OCR)
2. `TranslationCoordinator` drives state: `idle -> grabbing -> translating -> streaming -> completed/error`
3. Text grab fallback: `AccessibilityGrabber -> AppleScriptGrabber -> ClipboardGrabber`
4. Language detection and target adjustment
5. Translation provider streams output
6. `PopupPanelController` presents floating panel near cursor

Critical files:

- `Sources/Core/TranslationCoordinator.swift`
- `Sources/App/AppDelegate.swift`
- `Sources/Core/TextSelectionManager.swift`
- `Sources/UI/Popup/PopupPanelController.swift`
- `Sources/Utilities/Constants.swift`

## Editing Rules

- Keep UI-related controllers and coordinators `@MainActor` aligned.
- Do not break non-activating `NSPanel` behavior (must not steal focus).
- Preserve callback wiring style in `AppDelegate.setupSelectionMonitor()` with weak captures for stored/system callbacks.
- For `@Observable` types, avoid writable computed properties that proxy external state. Prefer stored property + `didSet` sync.

## Permissions Model

App depends on:

- Accessibility (AX grabbing)
- Screen Recording (OCR)

`PermissionManager` polls permissions periodically; keep polling stop conditions correct.

## Translation Provider Work

When adding or changing providers:

1. Implement provider protocol with streaming API (`AsyncThrowingStream`)
2. Register provider in registry
3. Ensure settings view integration remains self-contained in provider

## Localization

- Use `Resources/Localizable.xcstrings` for localizable strings.
- SwiftUI text: localized key literals.
- Runtime strings: `String(localized:)`.
- Keep API labels / provider IDs / brand terms non-localized where intended.

## Code Review Focus

Prioritize findings in this order:

1. Concurrency safety (actor isolation, Sendable, task lifetime)
2. Behavioral regressions in translation state machine and popup lifecycle
3. Memory leaks in long-running menu bar process
4. UI-state correctness (`@Observable`, bindings, panel ownership)

Memory checks:

- Stored closures and long-lived callbacks: use `[weak self]`
- Timers: `invalidate()` and nil-out in stop/dismiss paths
- Event monitors: always remove on stop and deinit
- `AsyncThrowingStream`: cancel backing task in `onTermination`
- `NSWindow/NSPanel` with retained lifecycle: release `contentView` and references on dismiss

## Release Notes

- Follow SemVer (`vMAJOR.MINOR.PATCH`)
- During `0.x`, bump MINOR for new feature releases
