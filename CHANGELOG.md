# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [v0.0.4] - 2026-03-08

### Fixed
- Restored paragraph boundaries from PDF selections before translation, so multi-paragraph selections no longer collapse into one block.
- Translated long passages paragraph-by-paragraph to preserve readable paragraph spacing in the floating card.
- Constrained the floating translation popup to the reader canvas to avoid overlapping the right AI sidebar.

## [v0.0.3] - 2026-03-04

### Changed
- Improved translation text handling and rendering for better readability:
  - Normalize selected PDF text before translation to reduce hard line-break noise.
  - Render floating-card translation as a continuous text block with expand/collapse.
- Strengthened sidebar layout behavior in narrow non-fullscreen windows:
  - Raised `NavigationSplitView` detail-column minimum width.
  - Added adaptive "思考模式" layout fallback for constrained widths.

### Fixed
- Fixed awkward multi-line translation display where content could appear fragmented.
- Fixed sidebar header artifacts in non-fullscreen mode caused by width compression.
- Replaced segmented pickers in key areas with stable custom segmented controls:
  - Sidebar "思考模式"
  - AI settings "默认 Provider"
- Normalized picker labeling and accessibility for menu-style selectors.

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
