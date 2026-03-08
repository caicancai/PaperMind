# PaperMind

A Swift/macOS paper-reading assistant focused on three core workflows:
- Read papers (PDF)
- Selection-based translation (Google Translate by default)
- Discuss with AI in a right sidebar (including formula explanation)

<p align="center">
  <a href="https://github.com/caicancai/PaperMind/releases"><img src="https://img.shields.io/badge/Release-GitHub-blue?logo=github" alt="Release" /></a>
  <a href="https://github.com/caicancai/PaperMind/releases/latest"><img src="https://img.shields.io/badge/Downloads-Latest%20Assets-2ea44f?logo=github" alt="Downloads" /></a>
  <a href="https://github.com/caicancai/PaperMind/issues"><img src="https://img.shields.io/badge/Feedback-Issues-orange?logo=github" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.10%2B-orange" alt="Swift" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
</p>

## Quick Links

| Release | Downloads | Feedback |
|---|---|---|
| [GitHub Releases](https://github.com/caicancai/PaperMind/releases) | [Latest Release Assets](https://github.com/caicancai/PaperMind/releases/latest) | [Open an Issue](https://github.com/caicancai/PaperMind/issues) |

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
  - Preserve paragraph structure from PDF selection when possible
  - Long translation supports expand/collapse and improved paragraph readability
  - Floating translation popup stays within the reader area instead of overlapping the right sidebar
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

## Package DMG

```bash
./scripts/package-dmg.sh
```

Generated file:

```text
release/PaperMind-<version>.dmg
```

Options:

- `--version <vX.Y.Z>` set package version
- `--debug` package debug build
- `--skip-build` package from existing binary without rebuilding

## Signed + Notarized Release DMG

Prerequisites:
- Developer ID Application certificate in Keychain
- notarytool profile (recommended):

```bash
xcrun notarytool store-credentials "PaperMindNotary" \
  --apple-id "<apple-id>" \
  --team-id "<team-id>" \
  --password "<app-specific-password>"
```

Build, sign, notarize and staple:

```bash
./scripts/release-dmg.sh v0.0.4 \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --notary-profile "PaperMindNotary"
```

If you skip signing/notarization, macOS may report the app as damaged or block opening.

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

## Feedback

Issues and feedback are welcome. If you encounter bugs or have feature suggestions, please open an issue:

- https://github.com/caicancai/PaperMind/issues

## License

MIT. See [LICENSE](./LICENSE).

## Roadmap (Short)

- More robust PDF context extraction (better QA quality)
- Persist chat history across app restarts

## Notes

Detailed design and iteration constraints are documented in [Agent.md](./Agent.md).
