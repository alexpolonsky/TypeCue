# Manual Regression Checklist

Automated tests cover the engine, session, store, and app UI. This checklist covers what
can only be verified by a human on a real machine: that synthetic typing actually lands
correctly in third-party apps we don't control. Run it before each release.

Prerequisite: build and run TypeCue, grant Accessibility, and confirm the onboarding
Test Pad shows "Verified".

## Core

- [ ] Menu bar icon appears; no Dock icon; app not in Cmd-Tab switcher.
- [ ] Create a script with 3+ blocks; set it active from the menu.
- [ ] Global shortcut (default Ctrl+Option+T) types block 1 into a focused TextEdit field.
- [ ] Each subsequent press types the next block, in order, with no characters merged or
      reordered.
- [ ] After the last block, further presses do nothing (sequence stops). Menu shows the
      complete state.
- [ ] Pressing the shortcut again while a block is typing stops it mid-block.
- [ ] "Reset" re-arms at block 1.
- [ ] Rebinding the shortcut in Settings works and the new binding takes effect; the menu's
      "Type Next Block" item shows the current shortcut.

## Typing fidelity in real target apps

For each app, focus a text field and type a block containing: lowercase, UPPERCASE,
digits, punctuation (`. , ! ? ' " ( ) : ; / - _ @ #`), a newline, and a leading/trailing
space.

- [ ] Browser (address bar and a web text field, e.g. a search box)
- [ ] Cursor (editor and the AI prompt field)
- [ ] Claude desktop / web (prompt field)
- [ ] TextEdit or Notes (baseline sanity)

For each: text matches exactly, no dropped or duplicated characters, newline behaves as
expected (does not prematurely submit unless intended).

- [ ] With line breaks set to "Insert a line break" (default), a multi-line block in a chat
      app (Claude/Cursor/Slack) does NOT submit at the newline.
- [ ] Switching to "Press Return" submits at the newline.
- [ ] A block ending in `[enter]` submits in a chat app.

## Pacing and markers

- [ ] Changing "Typing speed" visibly changes typing speed.
- [ ] Toggling "Natural rhythm" on/off changes the feel (on = uneven, human; noticeable
      pauses after periods/commas/spaces).
- [ ] `[speed:20]…[speed:default]` in a block visibly speeds up then restores the pace.
- [ ] `[0.5]` / `[2]` in a block pause for the stated time.
- [ ] Unrecognized brackets (e.g. `array[0]`) are typed literally.
- [ ] The bundled "TypeCue tour" sample demonstrates all of the above end to end.

## Edge cases

- [ ] Empty block (no text): press advances the cursor without typing anything, no hang.
- [ ] Very long block (e.g. a 1000-character paragraph): types fully without dropping the
      tail.
- [ ] Emoji / accented characters in a block: appear correctly (Unicode fallback path).
- [ ] Non-Latin block (e.g. Hebrew) with a Latin layout active: types correctly via the
      Unicode fallback; same block with the Hebrew layout active types via real keystrokes.
- [ ] Mixed-direction block (Hebrew + English in one sentence) into a bidi-aware field
      (Notes, WhatsApp): characters arrive in logical order and render correctly RTL/LTR.
- [ ] Switch the input source while the app is running, then type: no wrong-character
      mapping (the resolver rebuilds its layout cache on switch).
- [ ] Focus a password field, press the shortcut: TypeCue shows the "secure field" warning
      and does NOT consume the block (cursor does not advance).
- [ ] Two rapid presses: the second is ignored while the first block is still typing; no
      interleaving.

## Floating panel / multi-monitor / Spaces

- [ ] "Show Floating Panel" opens a panel that stays above other apps without stealing
      focus (the app you're typing into remains frontmost).
- [ ] Panel shows the active script, position, and upcoming blocks; the next block is
      highlighted and advances as you press the shortcut.
- [ ] Drag the panel to a second monitor; it stays there.
- [ ] Switch Spaces / enter a full-screen app; the panel remains visible.
- [ ] "Hide Floating Panel" hides it.

## Import / export

- [ ] Export (editor toolbar) writes the selected script to a `.json` file.
- [ ] Import (editor toolbar) reads it back as a new script (with a fresh id, no collision)
      and it appears in the list.
- [ ] A script exported by an older build (with `speedOverride`/`delayBefore` fields) imports
      correctly, with those settings folded into inline markers.
