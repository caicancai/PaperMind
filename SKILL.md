---
name: papermind-swift-app
description: Use this skill when working on PaperMind, a macOS SwiftUI paper-reading app with PDF selection translation and AI chat. Apply for architecture-aware edits, provider/model settings, chat interaction updates, and code reviews focused on async state safety.
---

# PaperMind Repo Skill

Apply this skill for tasks in this repository.

## Build and Run

This project is Swift Package Manager based.

```bash
swift build
open .build/debug/PaperMind
```

For release build:

```bash
swift build -c release
```

## Stack and Constraints

- Swift 5.10+, SwiftUI, PDFKit
- macOS desktop app (`Package.swift` currently targets macOS 13+)
- MVVM + Service + Repository
- Async workflows with `URLSession` and structured concurrency

## Core Architecture

Primary flow:

1. User imports/selects a PDF in library
2. Reader emits selection and page-anchor context
3. Selection triggers translation and optional AI actions
4. Chat panel streams AI response with paper/selection context
5. Settings control provider/model/API key locally

Critical files:

- `Sources/PaperMind/App/AppViewModel.swift`
- `Sources/PaperMind/App/AppDependencies.swift`
- `Sources/PaperMind/Features/Reader/ReaderPaneView.swift`
- `Sources/PaperMind/Features/Chat/ChatPanelView.swift`
- `Sources/PaperMind/Features/Settings/AISettingsFormView.swift`
- `Sources/PaperMind/Services/LLM/OpenAILLMService.swift`

## Current Interaction Rules

- In-reader floating card should remain the primary selection workflow.
- Selection actions include `Translate`, `Add Chat`, `Explain Formula`.
- `Add Chat` should prefill chat draft from current selection, then user asks.
- Chat supports per-question provider selection (`Auto/OpenAI/DeepSeek/Kimi`).
- Providers without configured API keys are not selectable for send.
- AI provider/model/key are configured in-app; no `.env.local` fallback.

## Provider and Model Notes

- Supported providers: OpenAI / DeepSeek / Kimi
- DeepSeek endpoint: `https://api.deepseek.com/v1/chat/completions`
- Kimi default model: `kimi-2.5`

## Editing Rules

- Keep `AppViewModel` as the single coordination point for async UI state.
- Prevent stale async tasks from overriding latest UI state (request-id or equivalent guard).
- Preserve cancellation behavior for translation and chat flows.
- Do not silently fallback to mock AI when provider/key is unavailable.
- Keep provider wiring in dependencies/services, not SwiftUI views.

## Code Review Focus

Prioritize findings in this order:

1. Async state races and stale-response overwrite risks
2. Behavioral regressions in selection -> translate/chat interaction
3. Provider routing and API error handling correctness
4. UI consistency in reader floating card and chat panel
5. Local settings persistence and migration safety

## Release Notes

- Follow SemVer (`vMAJOR.MINOR.PATCH`)
- During `0.x`, bump MINOR for new feature releases
