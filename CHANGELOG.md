# Changelog

All notable changes to this project are documented in this file.

## [v0.0.2] - 2026-03-02

### Added
- Reader outline fallback extraction for PDFs without embedded bookmarks.
- Outline source badge in reader panel (`内置目录` / `推断目录`).
- Resizable outline panel in the reader to protect center reading space on small screens.
- Automated app icon generation pipeline (`SVG -> AppIcon.icns`) integrated into DMG packaging scripts.
- New anime-style app icon source and generated `AppIcon.icns`.

### Changed
- Improved split layout sizing/min width behavior for 13-inch displays.
- Refined formula explanation chat UX:
  - Use a hidden internal prompt for model quality.
  - Show a cleaner user-facing prompt in chat history.
- Refreshed demo assets (`docs/demo.gif`, `docs/demo.mp4`).

### Fixed
- Fixed outline extraction compatibility issue in `PDFActionGoTo.destination` handling.
- Fixed embedded-outline jump reliability:
  - Prefer precise outline destination over page-only jump.
  - Avoid jump conflicts between page-level and outline-level navigation.
  - Improved same-page section jump behavior (e.g. `4.2` vs `4.3`).
- Fixed confusing outline active-state behavior by prioritizing the clicked outline item in UI highlight.

## [v0.0.1] - 2026-02-28

### Added
- Initial public release of PaperMind macOS app.
- Three-column reading workflow: Library | Reader | AI Sidebar.
- PDF import, selection popup actions, and reading-first layout.
- Selection-based translation flow (Google Translate by default).
- AI chat with provider routing (`OpenAI`, `DeepSeek`, `Kimi`) and Markdown-rendered responses.
- Selection-first chat flow (`Add Chat`) and formula explanation entry.
- DMG packaging scripts and signed/notarized release workflow scripts.
- Project documentation, setup guide, and demo media.

### Changed
- Chat panel UX improvements and streaming auto-follow behavior.

