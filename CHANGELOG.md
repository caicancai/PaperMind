# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

## [v0.2.2] - 2026-06-28

### Changed
- Improved Chrome extension selection translation UX with a wider, more readable floating
  translation popover that stays within the viewport, scrolls long translations internally, and
  avoids covering the selected text when possible.
- Rebuilt Chrome extension selected-text extraction from PDF.js text-layer spans so cross-page
  selections preserve readable text while avoiding page chrome such as headers, footers, and
  rotated side metadata.

### Fixed
- Fixed Chrome extension PDF zoom controls, keyboard shortcuts, and Ctrl/Cmd-wheel zoom behavior.
- Fixed PDF.js text-layer scale synchronization so text selection hit areas match rendered PDF
  pages.
- Fixed cross-page selections failing to trigger translation.

## [v0.2.1] - 2026-06-28

### Added
- Added a Manifest V3 Chrome extension that takes over the current PDF tab without importing or
  opening a new window, with lazy PDF.js rendering, embedded/inferred outlines, selection
  translation, formula explanation, streaming AI chat, provider/thinking controls, and themes.
- Added real Chromium end-to-end tests with generated PDFs and mocked translation/AI streams.
- Reintroduced personal paper notes with PDF selection anchors, categories, search, editing, and highlight navigation.
- Added saving AI responses as anchored notes.
- Added chat controls for stopping generation, regenerating, copying responses, and starting a new conversation.

### Changed
- Improved Chrome extension translation with true AI-provider streaming when configured, Google
  fallback, tighter line spacing, PDF line-wrap cleanup, and hyphenated-word reconstruction.
- Redesigned the main window around a native macOS toolbar, library sidebar, PDF-first reading canvas, and collapsible inspector.
- Reworked the selection popup into a compact action bar with on-demand translation details.
- Rebuilt the AI composer with inline provider and Fast/Deep controls, selection attachments, and guided empty-state prompts.

### Fixed
- Preserved the core `Add Chat` flow when switching between AI and notes: it now opens the AI inspector, attaches the selection, and focuses the composer.

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
