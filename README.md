# PaperMind

A Swift/macOS paper-reading assistant focused on three core workflows:
- Read papers (PDF)
- Selection-based translation (Google Translate by default)
- Discuss with AI in a right sidebar (including formula explanation)

## Current Features

- Paper Library
  - Import local PDF files
  - Switch and remove papers
  - Close current paper without deleting it
- Reading Experience
  - Reading-first center column layout
  - Floating popup appears after text selection
- Translation
  - Auto-translate selected text
  - Google Translate by default
  - Target language quick switch in floating popup (`zh/en/ja/ko`)
  - Long translation supports expand/collapse and auto-scroll
- AI Chat
  - Dedicated AI discussion sidebar
  - Selection-first flow with `Add Chat` (inject selection into draft, then ask)
  - Ask based on current selection with `Explain`
  - Free-form questions without selection are supported
  - Formula explanation quick action when formula-like text is detected
  - Supports `OpenAI`, `DeepSeek`, and `Kimi` providers
  - Per-question provider selection in chat panel (`Auto/OpenAI/DeepSeek/Kimi`)
  - Providers without configured API keys are disabled for sending
  - Reads and caches full-paper local context before first answer
  - Assistant messages are streamed token-by-token
  - Assistant messages are rendered as Markdown (post-stream)

## Requirements

- macOS 13+
- Swift 5.10+

## Quick Start

```bash
git clone https://github.com/caicancai/PaperMind.git
cd PaperMind
swift build
open .build/debug/PaperMind
```

## Demo

![PaperMind Demo](docs/demo.gif)

High-resolution video: [`docs/demo.mp4`](docs/demo.mp4)
Media workflow: [`docs/README-media.md`](docs/README-media.md)

## Configure AI Provider

Provider/model can now be configured directly in the app (`AI Settings`), and API keys are stored in local app settings.
You can open settings from the sidebar gear button or `Cmd + ,`.
Only in-app settings are used (no `.env.local` fallback).  
Kimi default model is `kimi-2.5`.
If provider or key is unavailable, the app reports configuration errors directly (no silent Mock fallback).

## Formula Explanation Flow

1. Select formula-like text in PDF (e.g. contains `=`, `^`, `\\`, `∑`)
2. Click `Explain Formula` from the floating popup or AI sidebar
3. AI explains the formula in natural language, including intuition, key symbols, and paper context when relevant.

## Known Limitations

- Test target is currently disabled (project currently maintained with `swift build` flow)
- Notes/comments are temporarily disabled in UI
 - API keys are stored locally in app settings (not encrypted by Keychain)

## License

MIT. See [LICENSE](./LICENSE).

## Roadmap (Short)

- More robust PDF context extraction (better QA quality)
- Persist chat history across app restarts

## Notes

Detailed design and iteration constraints are documented in [Agent.md](./Agent.md).
