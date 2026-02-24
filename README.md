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
  - Google Translate by default
- AI Chat
  - Dedicated AI discussion sidebar
  - Ask based on current selection with `Explain`
  - Free-form questions without selection are supported
  - Formula explanation quick action when formula-like text is detected
  - Supports `OpenAI`, `DeepSeek`, and `Kimi` providers
  - Reads and caches full-paper local context before first answer
  - Assistant messages are rendered as Markdown

## Requirements

- macOS 13+
- Swift 5.10+

## Quick Start

```bash
cd /Users/cc.cai/magic/PaperMind
swift build
open .build/debug/PaperMind
```

## Configure AI Provider

Provider selection is environment-variable based.

### Provider switch

- `AI_PROVIDER=openai`
- `AI_PROVIDER=deepseek`
- `AI_PROVIDER=kimi`
- `AI_PROVIDER=auto` (default, tries OpenAI -> DeepSeek -> Kimi if corresponding keys exist)

You can set vars in `.env.local` (project root). The app loads this file automatically.

### Credentials and optional models

- OpenAI
  - `OPENAI_API_KEY`
  - optional: `OPENAI_MODEL` (default: `gpt-4o-mini`)
- DeepSeek
  - `DEEPSEEK_API_KEY`
  - optional: `DEEPSEEK_MODEL` (default: `deepseek-chat`)
- Kimi (Moonshot)
  - `KIMI_API_KEY`
  - optional: `KIMI_MODEL` (default: `moonshot-v1-8k`)

### Examples

Use OpenAI:

```bash
export AI_PROVIDER=openai
export OPENAI_API_KEY=your_openai_key
cd /Users/cc.cai/magic/PaperMind
open .build/debug/PaperMind
```

Use DeepSeek:

```bash
export AI_PROVIDER=deepseek
export DEEPSEEK_API_KEY=your_deepseek_key
cd /Users/cc.cai/magic/PaperMind
open .build/debug/PaperMind
```

Use Kimi:

```bash
export AI_PROVIDER=kimi
export KIMI_API_KEY=your_kimi_key
cd /Users/cc.cai/magic/PaperMind
open .build/debug/PaperMind
```

If provider or key is unavailable, the app reports `AI not connected` style errors (no silent Mock fallback).

## Formula Explanation Flow

1. Select formula-like text in PDF (e.g. contains `=`, `^`, `\\`, `∑`)
2. Click `Explain Formula` from the floating popup or AI sidebar
3. AI responds with a fixed structure:
- One-sentence intuition
- Symbol mapping table
- Role of the formula in the paper
- A simple numeric example

## Known Limitations

- Test target is currently disabled (project currently maintained with `swift build` flow)
- Notes/comments are temporarily disabled in UI
- API keys are currently read from environment variables / `.env.local` (Keychain integration pending)

## License

MIT. See [LICENSE](./LICENSE).

## Roadmap (Short)

- Provider/model switcher UI (instead of env vars only)
- More robust PDF context extraction (better QA quality)
- Keychain-based API key management

## Notes

Detailed design and iteration constraints are documented in [Agent.md](./Agent.md).
