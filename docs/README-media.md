# README Media Guide

Use this guide to refresh lightweight demo media for GitHub README.

## Recommended Files

- `docs/demo.mp4`: high-quality full video
- `docs/demo.gif`: optional inline preview if generated from the same recording

## Current Recording TODO

The current README links directly to `docs/demo.mp4`. If the workflow changes again, keep the next
recording short, around 60-90 seconds:

1. macOS app: import/open a PDF, select text, translate, attach to chat, and save a note.
2. Chrome extension: open an online PDF, click PaperMind, use cross-page selection translation, zoom, and AI chat.
3. End on the two-surface story: app for local workspace, extension for browser PDFs.

## Record on macOS

1. Press `Shift + Command + 5`
2. Choose `Record Selected Portion`
3. Record a 16:10 or 16:9 region, ideally 1440px wide or narrower
4. Save as `demo.mp4` (or convert from `.mov` to `.mp4`)

## Convert MP4 to GIF (ffmpeg)

```bash
# Install ffmpeg once
brew install ffmpeg

# Convert and compress for README preview
ffmpeg -i docs/demo.mp4 -vf "fps=12,scale=1280:-1:flags=lanczos" -loop 0 docs/demo.gif
```

## Optional: Further Compression

```bash
ffmpeg -i raw-demo.mov -vcodec libx264 -crf 28 -preset slow docs/demo.mp4
```

## README Snippet

```md
## Demo

Demo video: [`docs/demo.mp4`](docs/demo.mp4)
```
