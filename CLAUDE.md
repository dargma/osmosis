# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Osmosis is a **Claude Code plugin** — a team-shared work journal that flows through git. There is no server, DB, or daemon; the only dependencies are `bash` + `git`. Two mechanics:

1. **Record** — `/handoff` (see `skills/handoff/SKILL.md`) has Claude summarize the session into markdown under a target repo's `.osmosis/journal/{author}/` and regenerate `.osmosis/STATUS.md`. A read-only `/catchup` skill (`skills/catchup/SKILL.md`) re-shows status mid-session.
2. **Inject** — the `SessionStart` hook (`hooks/session-start.sh`) prints `STATUS.md` plus module-collision warnings at the start of every session, so a teammate's Claude reads it automatically.

Journals are shared purely by `git push`/`pull`. **This repo is the plugin source itself** — the `.osmosis/` directory that end users get lives in *their* repos, not here (except `memory/STATUS.md`, the seed template).

## Two ways it's installed

- **Plugin** (primary): `plugin.json` → `hooks/hooks.json` wires the `SessionStart` hook via `${CLAUDE_PLUGIN_ROOT}`. `marketplace.json` makes it installable with `/plugin install osmosis@osmosis`.
- **Manual** (`install.sh`): copies files into a target repo's `.claude/`, and merges the hook into `.claude/settings.json` with a python3 snippet that **preserves existing settings** and is idempotent (dedupes by command string). `uninstall.sh` reverses it (`--purge` also deletes `.osmosis/`); `update.sh` is a no-op when `.osmosis/VERSION` already matches `VERSION`.

Keep these two paths in sync: the plugin hook path is `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh`, the manual install copies it to `.claude/hooks/osmosis-session-start.sh`.

## Key invariants — do not break these

- **The hook must never block a session.** `session-start.sh` uses `set -u` (not `-e`), guards every command, `exit 0` on any missing prerequisite, and wraps `git fetch` in `timeout 3`. Any change here must preserve "fail silent, session continues."
- **STATUS.md ≤ 2KB, always.** It's injected every session (the hook prints `head -n 60`). Token budget is the whole point. When it overflows, drop oldest *completed* items — the source of truth is the journal.
- **`verified` ≠ "I did it".** Only mark `status: verified` with a real `verified_by` (test path or commit hash). Everything unconfirmed is `unverified`. This distinction is the product.
- **One task = one file.** Journal entries are separate files (`{YYYYMMDD-HHMM}-{slug}.md`) specifically to avoid merge conflicts. `STATUS.md` carries `merge=union` in `.gitattributes` for the same reason.
- **Frontmatter is a stable schema** (`id`/`module`/`status`/`verified_by`/`author`/`branch`/`supersedes`/`refs`). The collision scanner parses it with awk; the design intends forward-compat toward a future vector-DB. Don't rename fields casually.

## Collision detection (the non-obvious part)

`session-start.sh` warns about *other authors'* open (`unverified`/`failed`) entries touching a module, scanning **two sources**: (1) the current working tree's journal, and (2) **remote branches** via `git for-each-ref refs/remotes/origin` + `git show`. Source 2 exists so a teammate's still-unmerged feature-branch work is visible before PR merge — removing it reintroduces the "branch blind spot." Both sources are filtered to the last 30 days and exclude the current user (`ME`, derived from `git config user.name`, lowercased/hyphenated).

## Testing changes

No test suite. To validate the hook, run it inside a git repo that has a `.osmosis/` dir:

```bash
bash hooks/session-start.sh          # from a target repo root
```

It prints the injected block and a `⚡ Nms` timing footer. Verify a broken/missing `.osmosis/` exits cleanly (code 0, no session-breaking output). The UI/docs strings are Korean — keep that voice when editing `skills/handoff/SKILL.md` and the echo strings.

## Releasing

Bump `VERSION`, `plugin.json`, and `marketplace.json` together — `update.sh` compares `.osmosis/VERSION` against `VERSION` to decide whether to re-run `install.sh`.
