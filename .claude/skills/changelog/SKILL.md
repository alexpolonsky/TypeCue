---
name: changelog
description: Update CHANGELOG.md when landing user-visible TypeCue changes - Keep a Changelog format, what belongs in it and what does not.
---

# Changelog maintenance

`CHANGELOG.md` at the repo root follows [Keep a Changelog](https://keepachangelog.com)
with semantic versions matching `MARKETING_VERSION` in `project.yml`.

## When to add an entry

Add a bullet under `[Unreleased]` in the same change when a commit alters something a
USER can observe: features, UI/copy changes, behavior changes, fixes, performance,
requirements (macOS version), permissions. Use the standard subsections:
`Added / Changed / Fixed / Removed`.

Do NOT log: refactors with no visible effect, test-only changes, doc edits, CI,
internal tooling.

## Style

- One line per change, written for a user, not a developer ("Settings no longer
  scrolls at the default window size", not "bump minHeight to 520").
- No em dashes (use hyphens). No commit hashes. Link issues/PRs once the repo is
  public if relevant.

## Cutting a release

Handled by the `release` skill: rename `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`,
add a fresh empty `[Unreleased]` above it, bump `MARKETING_VERSION`.
