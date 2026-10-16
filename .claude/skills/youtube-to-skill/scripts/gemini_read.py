"""Ask Gemini to watch a YouTube URL and list the steps it shows (Read B).

Usage: GEMINI_API_KEY=... python3 gemini_read.py <youtube-url> [model]
"""
import json
import os
import sys
import urllib.request

PROMPT = (
    "Watch this video. List, as numbered steps with timestamps, exactly what the "
    "viewer must install, configure, type, and run to reproduce what it builds. "
    "Quote any commands, code, file names, URLs and settings shown on screen "
    "verbatim. State the inputs and outputs of the final result. Say \"unclear\" "
    "rather than guessing."
)


def main():
    url = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    key = os.environ["GEMINI_API_KEY"]
    body = {
        "contents": [{
            "parts": [
                {"file_data": {"file_uri": url}},
                {"text": PROMPT},
            ]
        }]
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.load(resp)
    parts = data["candidates"][0]["content"]["parts"]
    print("".join(p.get("text", "") for p in parts))


if __name__ == "__main__":
    main()
