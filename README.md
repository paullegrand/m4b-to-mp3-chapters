# Audiobook Chapter Splitter

Split DRM-free .m4b audiobooks into MP3 chapters using ffmpeg.

## Prerequisites

- macOS with Homebrew
- ffmpeg installed: `brew install ffmpeg`
- DRM-free .m4b files

## Usage

Generate simple chapter file:

```zsh
./m4b_to_mp3.sh
# Prompts for .m4b path, creates chapters.txt and chapter_001.mp3, etc chapters
```
