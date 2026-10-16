"""Convert a WebVTT subtitle file to deduplicated '[mm:ss] text' lines."""
import re
import sys

TIME = re.compile(r"^(\d+):(\d\d):(\d\d)\.\d+ -->|^(\d\d):(\d\d)\.\d+ -->")
TAG = re.compile(r"<[^>]+>")


def main(path):
    seen = set()
    stamp = "00:00"
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            m = TIME.match(line)
            if m:
                if m.group(1) is not None:
                    secs = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))
                else:
                    secs = int(m.group(4)) * 60 + int(m.group(5))
                stamp = f"{secs // 60:02d}:{secs % 60:02d}"
                continue
            if not line or line.startswith(("WEBVTT", "Kind:", "Language:", "NOTE")) or line.isdigit():
                continue
            text = TAG.sub("", line).strip()
            # Auto-captions repeat each line across cues; keep the first occurrence.
            if text and text not in seen:
                seen.add(text)
                print(f"[{stamp}] {text}")


if __name__ == "__main__":
    main(sys.argv[1])
