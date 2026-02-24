# README Media Guide

Use this guide to create lightweight demo media for GitHub README.

## Recommended Files

- `docs/demo.gif`: inline preview in README
- `docs/demo.mp4`: high-quality full video

## Record on macOS

1. Press `Shift + Command + 5`
2. Choose `Record Selected Portion`
3. Save as `demo.mp4` (or convert from `.mov` to `.mp4`)

## Convert MP4 to GIF (ffmpeg)

```bash
# Install ffmpeg once
brew install ffmpeg

# Convert and compress for README
ffmpeg -i demo.mp4 -vf "fps=12,scale=1280:-1:flags=lanczos" -loop 0 docs/demo.gif
```

## Optional: Further Compression

```bash
ffmpeg -i demo.mp4 -vcodec libx264 -crf 28 -preset slow docs/demo.mp4
```

## README Snippet

```md
## Demo

![PaperMind Demo](docs/demo.gif)

High-resolution video: [`docs/demo.mp4`](docs/demo.mp4)
```
