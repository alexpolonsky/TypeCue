---
name: typecue
description: Create, edit, pace, and activate TypeCue scripts for the user. Use when asked to write or edit a TypeCue demo script, add pacing to a script, prepare a demo typing script, or control the TypeCue macOS app. Covers the scripts.json schema, the typecue:// commands, and direction rules for pacing markers.
---

# TypeCue scripts

TypeCue is a macOS menu bar app that types scripted text blocks into the focused
field, one block per hotkey press. This skill lets you author its scripts and drive
the app.

## Where scripts live

`~/Library/Application Support/TypeCue/scripts.json` - same path on every Mac
(the app is not sandboxed). Plain JSON array:

```json
[
  {
    "id": "UUID-UPPERCASE",
    "name": "My demo",
    "blocks": [
      { "id": "UUID-UPPERCASE", "text": "Block text with [0.6] inline markers." }
    ]
  }
]
```

Rules when editing:
- Keep existing `id`s stable; generate fresh UUIDs (uppercase) only for NEW scripts/blocks.
- Validate the JSON before writing, and copy the current file aside first
  (e.g. `scripts.json.bak`) so a bad write is recoverable.
- After editing, tell the running app to pick it up: `open "typecue://reload"`.

## Controlling the app

```bash
open "typecue://activate-script?name=My%20demo"   # or ?id=<UUID> if names repeat
open "typecue://reset-session"                     # re-arm at block 1
open "typecue://reload"                            # re-read scripts.json
```

Observe state (the app rewrites this on every change):
`~/Library/Application Support/TypeCue/state.json` - status (`idle|armed|complete`),
active script id/name, `nextBlockIndex`, `totalBlocks`, `isTyping`.

## Inline markers

- `[0.5]` / `[2]` - pause that many seconds
- `[speed:40]` - 40 ms/character from here on; `[speed:default]` restores the user's set speed
- `[enter]` - press Return (submits in chat apps). Plain line breaks inside a block are
  typed as Shift+Return by default, so multi-line blocks don't self-submit.
- Unrecognized brackets (`array[0]`) are typed literally.

## Directing a script (pacing rules)

A TypeCue script is typed content - prompts, commands, chat messages, code - not
spoken lines, and it has no target duration. Pacing is about how the typing lands on
screen, not about filling time. One block = one hotkey press = one beat of the demo;
split blocks at the moments the presenter wants to trigger separately.

Speed tiers (ms/char):
- **Default 60-90** - confident human typing; leave the user's app-level default alone
  unless a section needs contrast.
- **Deliberate 100-140** - the one phrase that must land (a product name, the key flag);
  use for at most a phrase, not a paragraph.
- **Brisk 35-55** - boilerplate, paths, repeated syntax the viewer pattern-matches.
- Always return with `[speed:default]` immediately after a scoped burst.

Pauses:
- Sentence-end beat mid-block: `[0.5]`-`[0.8]`.
- Anticipation before a reveal or an important line: `[0.8]`-`[1.5]`.
- After `[enter]` in a chat-app demo: end the block there; the response appearing IS
  the pause. If more typing follows in the same block, give it `[1.5]`-`[2.5]` so
  viewers see the response begin.
- Don't pepper commas with pauses - typing rhythm already carries small beats.

Content heuristics:
- Questions and punchlines: deliberate speed + a pre-pause.
- Long explanatory paragraphs: default speed, one sentence-end pause in the middle.
- Commands/code: brisk, but slow down for the one argument that matters.
- First block of a demo: start a touch slower (viewers are orienting), or open with `[0.8]`.
