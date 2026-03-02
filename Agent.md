# Agent.md

## Project Name
PaperMind (Swift Paper Reading Assistant)

## Goal
Build a Swift/macOS paper-reading app with these core capabilities:
1. Import and read papers (PDF-first).
2. Selection-based translation.
3. Chat with LLMs about paper content (Q&A, explanation).
4. Structured notes/comments (planned for future iterations).

## MVP Scope
1. Paper library: local import, list, switch.
2. Reader: PDF display with text-selection events.
3. Translation: translate selected text and display result.
4. AI chat: ask with paper context (selection optional).
5. Local persistence: paper metadata and app data persisted locally.

## Out of Scope (Current Stage)
1. Cloud sync / cross-device realtime sync.
2. OCR for scanned PDFs as a core workflow.
3. Team collaboration and sharing.
4. Deep citation manager integration.

## Tech Stack
1. Swift 5.10+, SwiftUI, PDFKit.
2. MVVM + Service Layer + Repository.
3. Local storage with JSON (future migration possible).
4. Networking via URLSession.
5. Provider abstraction for LLM/translation.

## Suggested Structure
```text
PaperMind/
  App/
    PaperMindApp.swift
    RootView.swift
  Features/
    Library/
    Reader/
    Translate/
    Chat/
  Core/
    Models/
    Protocols/
    Utils/
  Services/
    LLM/
    Translation/
    Storage/
    Parsing/
```

## Domain Models (Minimal)
1. `Paper`
- `id: UUID`
- `title: String`
- `authors: [String]`
- `fileURL: URL`
- `tags: [String]`
- `createdAt: Date`
- `lastOpenedAt: Date?`

2. `TextSelection`
- `paperID: UUID`
- `pageIndex: Int`
- `selectedText: String`
- `contextBefore: String?`
- `contextAfter: String?`

3. `TranslationRecord`
- `id: UUID`
- `selection: TextSelection`
- `sourceLang: String`
- `targetLang: String`
- `translatedText: String`
- `createdAt: Date`

4. `ChatMessage`
- `id: UUID`
- `sessionID: UUID`
- `role: user | assistant | system`
- `content: String`
- `createdAt: Date`

## Core Protocols
```swift
protocol TranslationService {
    func translate(text: String, source: String?, target: String) async throws -> String
}

protocol LLMService {
    func chat(messages: [ChatMessage], context: PaperContext?) async throws -> String
}

protocol PaperRepository {
    func listPapers() async throws -> [Paper]
    func addPaper(fileURL: URL) async throws -> Paper
    func removePaper(id: UUID) async throws
}
```

## UI Requirements
1. Three-column layout: Library | Reader | AI Sidebar.
2. Selection popup in reader should provide:
- `Translate`
- `Add Chat`
- `Ask AI`
- `Explain Formula`
3. Selection popup should minimize context switching.
4. All async actions should expose clear `loading/success/error` states.

## Prompt Rules
1. Answers should use paper context first.
2. When uncertain, state missing evidence clearly.
3. Current quick mode is `Explain`.

## Security & Privacy
1. Keep data local by default.
2. Do not upload full paper by default; send necessary context only.
3. API keys are currently persisted in local app settings (not Keychain).

## Current Status (2026-03-02)
1. Implemented: three-column UI, PDF reading, selection events, translation popup, AI sidebar.
2. Implemented: Google translation by default.
3. Implemented: LLM providers OpenAI / DeepSeek / Kimi.
4. Implemented: strict AI mode (no silent fallback to Mock when provider is missing/unavailable).
5. Implemented: paper context pre-read and cache before/around answering.
6. Implemented: assistant responses stream token-by-token, then render as Markdown.
7. Implemented: Thinking mode selector (`Fast` default, `Deep` optional).
8. Implemented: AI settings UI with provider/model/API key editing (sidebar popover + Settings window).
9. Implemented: settings entry via `Cmd + ,`.
10. Implemented: translation popup target-language switch (`zh/en/ja/ko`) with per-language cache.
11. Implemented: translation result card with expand/collapse and auto-scroll for long content.
12. Implemented: selection-first `Add Chat` flow (inject selected text into chat draft, then user asks).
13. Implemented: per-question provider selection in chat panel (`Auto/OpenAI/DeepSeek/Kimi`), providers without configured key are disabled.
14. Implemented: DeepSeek endpoint fixed to `/v1/chat/completions`.
15. Implemented: Kimi default model updated to `kimi-2.5`.
16. Implemented: app now uses in-app settings only for provider/model/key (no `.env.local` fallback).
17. Disabled in UI: notes/comments flow (kept out of main workflow for now).
18. Tests are currently not enabled in package targets.
19. Implemented: Reader outline extraction and click-to-jump from PDF embedded bookmarks.
20. Implemented: fallback inferred outline detection for PDFs without embedded bookmarks.
21. Implemented: outline source badge (`内置目录` / `推断目录`) in reader panel.
22. Implemented: reader outline panel is now resizable by drag handle to protect center reading area.
23. Implemented: split layout min-width tuning for better 13-inch screen behavior.
24. Implemented: packaging scripts now generate and embed app icon (`AppIcon.icns`) automatically.
25. Updated demo media: refreshed README assets are `docs/demo.gif` and `docs/demo.mp4`.

## Key Interaction Decisions
1. Reading-first layout and behavior take priority.
2. In-reader floating popup is preferred over moving users to side panels.
3. AI workflow should support both with-selection and free-form questions.

## Must-Follow Engineering Notes
1. Do not degrade reading area significantly.
2. Use cancellation/debounce for selection-triggered async tasks.
3. Provide actionable AI/network error messages.
4. Keep provider-specific logic out of views.
5. Preserve privacy boundaries for paper content.

## Next Priorities
1. Chat persistence by paper/session (restore history after restart).
2. Comments/notes feature redesign and reintroduction.
3. Better context extraction quality and prompt control.
4. Optional encrypted local secret store (if passwordless UX remains a requirement).
5. Translation popup editing mode (edit source text before re-translate).

## Collaboration Rules
1. Keep changes scoped and explicit.
2. Prefer protocol-first abstractions.
3. Justify new dependencies before adding.
4. Handle timeout/cancel/error for all async paths.
5. Add/restore tests when test environment is available.
