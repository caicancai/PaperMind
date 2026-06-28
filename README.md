# PaperMind

PaperMind is a Chrome PDF reading assistant for papers. Open a PDF in the browser, click PaperMind, then translate selections, ask AI questions, and keep the discussion close to the text.

<p align="center">
  <a href="https://github.com/caicancai/PaperMind/releases"><img src="https://img.shields.io/badge/Release-GitHub-blue?logo=github" alt="Release" /></a>
  <a href="https://github.com/caicancai/PaperMind/issues"><img src="https://img.shields.io/badge/Feedback-Issues-orange?logo=github" alt="Issues" /></a>
  <img src="https://img.shields.io/badge/Chrome-Manifest%20V3-blue?logo=googlechrome" alt="Chrome Manifest V3" />
  <img src="https://img.shields.io/badge/TypeScript-Extension-blue?logo=typescript" alt="TypeScript" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License" /></a>
</p>

## What It Does

- Opens the current browser PDF in the same tab.
- Renders long PDFs lazily with PDF.js.
- Shows embedded or inferred outlines.
- Supports smooth selection translation, including cross-page selections.
- Keeps page headers, footers, and side metadata out of cross-page translation text.
- Provides formula explanation and streaming AI chat.
- Supports OpenAI, DeepSeek, and Kimi.

## Install Chrome Extension

```bash
git clone https://github.com/caicancai/PaperMind.git
cd PaperMind
cd extension
npm install
npm run build
```

Then open `chrome://extensions`, enable Developer Mode, and load `extension/dist`.

Browser-specific notes:

- Local `file://` PDFs require enabling "Allow access to file URLs" in the extension details page.
- The browser version does not include persisted chat history.

## AI Setup

Configure provider, model, and API keys in the extension settings. The supported providers are:

- OpenAI
- DeepSeek
- Kimi

API keys are stored in local extension settings. PaperMind reports missing provider configuration directly instead of silently falling back to mock responses.

## Development

```bash
cd extension
npm test
```

## Roadmap

- Improve PDF context extraction for better paper-level QA.
- Persist browser chat history.

## Feedback

Issues and feature suggestions are welcome: <https://github.com/caicancai/PaperMind/issues>

## License

MIT. See [LICENSE](./LICENSE).
