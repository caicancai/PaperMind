# PaperMind

PaperMind is a paper-reading workspace for researchers who live in PDFs. It keeps reading, translation, notes, and AI discussion close to the selected text instead of forcing a copy-paste workflow.

<p align="center">
  <a href="https://github.com/caicancai/PaperMind/releases"><img src="https://img.shields.io/badge/Release-GitHub-blue?logo=github" alt="Release" /></a>
  <a href="https://github.com/caicancai/PaperMind/issues"><img src="https://img.shields.io/badge/Feedback-Issues-orange?logo=github" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.10%2B-orange" alt="Swift" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
</p>

## What It Does

PaperMind has two frontends:

| Surface | Best for | Status |
|---|---|---|
| macOS app | Local PDF library, anchored notes, translation, persistent reading workspace | Main app |
| Chrome extension | Quickly reading an online PDF in the current tab with translation and AI chat | Browser companion |

Core workflows:

- Read PDFs with outlines and a reading-first layout.
- Select text to translate, explain, attach to chat, or save as a note.
- Discuss the current paper with OpenAI, DeepSeek, or Kimi.
- Explain formula-like selections with a dedicated prompt.
- Keep notes anchored to PDF selections in the macOS app.

## Demo

Demo video: [`docs/demo.mp4`](docs/demo.mp4)
Media workflow: [`docs/README-media.md`](docs/README-media.md)

## Install

Download packaged builds from [GitHub Releases](https://github.com/caicancai/PaperMind/releases).

For local development:

```bash
git clone https://github.com/caicancai/PaperMind.git
cd PaperMind
swift build
open .build/debug/PaperMind
```

Requirements:

- macOS 13+
- Swift 5.10+

## Chrome Extension

The extension takes over the current PDF tab and reuses that tab. It supports lazy PDF.js rendering, embedded/inferred outlines, selection translation, cross-page selections, formula explanation, and streaming AI chat controls.

```bash
cd extension
npm install
npm run build
```

Then open `chrome://extensions`, enable Developer Mode, and load `extension/dist`.

Browser-specific notes:

- Local `file://` PDFs require enabling "Allow access to file URLs" in the extension details page.
- The browser version does not include notes or persisted chat history.
- Extension tests run with generated PDFs and mocked AI/translation streams:

```bash
cd extension
npm test
```

## AI Providers

Configure provider, model, and API keys in app settings. The supported providers are:

- OpenAI
- DeepSeek
- Kimi

API keys are stored in local app settings. The app reports missing provider configuration directly instead of silently falling back to mock responses.

## Packaging

Create a local DMG:

```bash
./scripts/package-dmg.sh
```

Create a signed and notarized release DMG:

```bash
./scripts/release-dmg.sh v0.2.2 \
  --identity "Developer ID Application: Your Name (TEAMID)" \
  --notary-profile "PaperMindNotary"
```

If signing or notarization is skipped, macOS may block opening the app.

## Roadmap

- Improve PDF context extraction for better paper-level QA.
- Persist browser chat history if the extension graduates beyond companion mode.

## Feedback

Issues and feature suggestions are welcome: <https://github.com/caicancai/PaperMind/issues>

## License

MIT. See [LICENSE](./LICENSE).
