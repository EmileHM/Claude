---
name: youtube-to-skill
description: Turn a YouTube tutorial into a working Claude Code skill. Reads the video twice from independent sources (frames + transcript locally, and a second read from Gemini), reconciles both into one spec where every line is labeled confirmed, single-source, or conflict, has the user resolve only the conflicts, then hands the spec to skill-creator to write the skill. Use when the user shares a YouTube link and asks to "make this a skill", "turn this tutorial into an agent", "build what this video shows", or similar.
---

# YouTube tutorial → Claude Code skill

Two independent reads of the same video catch each other's mistakes. Lines both
reads agree on are trusted; the user only reviews where they disagree.

## Step 1 — Read A: frames + transcript (local)

Run the helper (needs `yt-dlp` and `ffmpeg`; install yt-dlp with
`pip install yt-dlp` if missing):

```bash
.claude/skills/youtube-to-skill/scripts/fetch_video.sh "<youtube-url>" <workdir>
```

It writes to `<workdir>`:
- `meta.json` — title, channel, description, chapters, duration
- `transcript.txt` — subtitles (manual preferred, auto-generated fallback), deduplicated, with timestamps
- `frames/` — one JPEG every N seconds (default 10; set `FRAME_EVERY=5` for dense screen-recordings)

If the `claude-video` skill (bradautomates/claude-video) is already installed,
you may use it instead. Do not install it on your own — it is third-party code;
ask the user first.

Read the transcript and look at the frames (Read tool on the images) wherever
the narrator refers to something on screen ("click here", "paste this",
"like so"). Commands, code, file names and settings shown on screen usually
matter more than what is said.

Write **Read A** as a numbered list of concrete steps: what is installed, what
is configured, what is run, what input it takes, what output it produces. Give
each line its timestamp.

## Step 2 — Read B: Gemini (native video)

Gemini can watch YouTube URLs directly. Use whichever is available:

1. **API** — if `GEMINI_API_KEY` is set, run
   `python3 .claude/skills/youtube-to-skill/scripts/gemini_read.py "<youtube-url>" > <workdir>/gemini.md`.
   This sends only the public video URL and the prompt below to Google.
   Confirm with the user before the first call in a session.
2. **Manual** — otherwise give the user the prompt below to paste into Gemini
   (gemini.google.com) with the link, and ask them to paste back the answer.

Gemini prompt (also used by the script):

> Watch this video. List, as numbered steps with timestamps, exactly what the
> viewer must install, configure, type, and run to reproduce what it builds.
> Quote any commands, code, file names, URLs and settings shown on screen
> verbatim. State the inputs and outputs of the final result. Say "unclear"
> rather than guessing.

Do not let Read A influence Read B: never send Gemini your own summary.

## Step 3 — Reconcile into one spec

Merge both reads into `<workdir>/spec.md`. Every line gets exactly one label:

- `[confirmed]` — both reads agree (paraphrase is fine; commands must match exactly)
- `[single: A]` / `[single: B]` — only one read mentions it
- `[conflict]` — the reads disagree; show both versions and the timestamp

Structure:

```markdown
# <skill name> — spec from "<video title>" (<url>)
## Goal
## Trigger (when should the skill run?)
## Inputs / Outputs
## Prerequisites (tools, accounts, API keys)
## Steps
1. [confirmed] ...
2. [conflict] A: `npm i foo` (02:14) — B: `npm i foo-cli` (02:15)
## Open questions
```

Then show the user **only** the `[conflict]` lines (and any `[single]` line
that is a command, secret, or destructive action) and ask them to pick or
correct each one. To settle a conflict yourself first, re-check the frames
around its timestamp; mark it `[resolved: frame mm:ss]` if a frame shows the
answer plainly. Update the spec with the user's answers. Do not continue while
any `[conflict]` remains.

## Step 4 — Build the skill

Invoke the `skill-creator` skill and give it `spec.md` as the full
requirements. Tell it to:
- turn the Steps into the skill's instructions, keeping exact commands verbatim;
- add an approval checkpoint before anything that installs software, spends
  money, sends data to an external service, or deletes files;
- list the Prerequisites at the top of the new SKILL.md.

Save the result under `.claude/skills/<skill-name>/` in the current project
unless the user names another location.

## Step 5 — Verify and hand back

- Dry-run the new skill on the example from the video if possible, and report
  what happened honestly (including failures).
- Tell the user where the skill is, how to trigger it, and which lines of the
  spec were `[single]` (less certain) so they know what to watch.

## Notes

- If the video has no subtitles, Read A relies on frames plus the
  description; say so, and treat more lines as `[single: B]`.
- Tutorials often skip steps ("I already set this up"). Put those in
  Open questions instead of inventing them.
- Never copy API keys or tokens shown on screen into the skill.
