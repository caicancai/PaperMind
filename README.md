# PaperMind

A Swift/macOS paper-reading assistant focused on three core workflows:
- Read papers (PDF)
- Selection-based translation (Google Translate by default)
- Discuss with AI in a right sidebar (including formula explanation)

## Current Features

- Paper Library
  - Import local PDF files
  - Switch and remove papers
- Reading Experience
  - Reading-first center column layout
  - Floating popup appears after text selection
- Translation
  - Auto-translate selected text
  - Google Translate by default, with automatic fallback to Mock
- AI Chat
  - Dedicated AI discussion sidebar
  - Ask based on current selection with `Explain` / `Summarize`
  - Formula explanation quick action when formula-like text is detected

## Requirements

- macOS 13+
- Swift 5.10+

## Quick Start

```bash
cd /Users/cc.cai/magic/PaperMind
swift build
swift run
```

## Configure AI Provider

Provider selection is currently environment-variable based:

- `OPENAI_API_KEY` is set: use OpenAI (with automatic fallback to Mock on failure)
- `OPENAI_API_KEY` is not set: use Mock

Example:

```bash
export OPENAI_API_KEY=your_api_key
cd /Users/cc.cai/magic/PaperMind
swift run
```

## Formula Explanation Flow

1. Select formula-like text in PDF (e.g. contains `=`, `^`, `\\`, `∑`)
2. Click `Explain Formula` from the floating popup or AI sidebar
3. AI responds with a fixed structure:
- One-sentence intuition
- Symbol mapping table
- Role of the formula in the paper
- A simple numeric example

## Project Structure

```text
PaperMind/
  Agent.md
  Package.swift
  Sources/PaperMind/
    App/
    Core/
    Features/
    Services/
```

## Known Limitations

- Test target is currently disabled (project maintained with `swift build` / `swift run` flow)
- Notes/comments are temporarily disabled in UI
- API key is currently read from environment variables (Keychain integration pending)

## Roadmap (Short)

- Provider/model switcher UI (instead of env vars only)
- More robust PDF context extraction (better QA quality)
- Keychain-based API key management

## Notes

Detailed design and iteration constraints are documented in [Agent.md](./Agent.md).
