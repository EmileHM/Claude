#!/usr/bin/env bash
# Fetch metadata, transcript and sampled frames for a YouTube video.
# Usage: fetch_video.sh <youtube-url> <workdir>   (env: FRAME_EVERY=seconds, default 10)
set -euo pipefail

url="${1:?usage: fetch_video.sh <youtube-url> <workdir>}"
out="${2:?usage: fetch_video.sh <youtube-url> <workdir>}"
every="${FRAME_EVERY:-10}"
here="$(cd "$(dirname "$0")" && pwd)"

command -v yt-dlp >/dev/null || { echo "yt-dlp not found: pip install yt-dlp" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg not found" >&2; exit 1; }

mkdir -p "$out/frames"

yt-dlp --skip-download --dump-json "$url" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); json.dump({k:d.get(k) for k in ("title","channel","upload_date","duration","description","chapters","webpage_url")}, sys.stdout, indent=2)' \
  > "$out/meta.json"

# Subtitles: manual first, auto-generated as fallback.
yt-dlp --skip-download --write-subs --write-auto-subs --sub-langs "en,en-US,en-GB,en-orig" \
  --sub-format vtt -o "$out/subs.%(ext)s" "$url" >/dev/null || true
vtt="$(ls "$out"/subs*.vtt 2>/dev/null | head -n1 || true)"
if [[ -n "$vtt" ]]; then
  python3 "$here/vtt_to_text.py" "$vtt" > "$out/transcript.txt"
else
  echo "(no subtitles available)" > "$out/transcript.txt"
fi

# Low-res video, just enough to read on-screen text. YouTube sometimes blocks
# downloads (e.g. from cloud IPs); continue with transcript + metadata only.
if yt-dlp -f "bv*[height<=720][ext=mp4]/bv*[height<=720]/b[height<=720]/b" \
     -o "$out/video.%(ext)s" "$url" >/dev/null; then
  video="$(ls "$out"/video.* | head -n1)"
  ffmpeg -loglevel error -i "$video" -vf "fps=1/$every" -q:v 3 "$out/frames/%04d.jpg"
  # Rename frames to their timestamp (mm-ss) so they line up with the transcript.
  i=0
  for f in "$out"/frames/[0-9][0-9][0-9][0-9].jpg; do
    t=$(( i * every )); i=$(( i + 1 ))
    mv "$f" "$out/frames/$(printf '%02d-%02d' $((t/60)) $((t%60))).jpg"
  done
  rm -f "$video"
else
  echo "WARNING: video download failed; no frames. Read A is transcript + description only." >&2
fi

echo "meta:       $out/meta.json"
echo "transcript: $out/transcript.txt ($(wc -l < "$out/transcript.txt") lines)"
echo "frames:     $out/frames ($(ls "$out/frames" | wc -l) every ${every}s)"
