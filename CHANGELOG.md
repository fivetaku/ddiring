# Changelog

## 0.1.1 — 2026-08-23

Hardening hotfix (GPT-5.6 Sol Pro external review + reproduction-verified).

- **Fixed: osascript fallback broke on quotes/newlines** in folder names or prompts (AppleScript-layer injection surface). AppleScript source is now fixed code; user data passes via argv only.
- **Fixed: setup.sh could wipe `settings.json`** — if the file was corrupted or contained comments, the updater rewrote it as `{}` + hook, silently destroying all user settings. Now it refuses to write on parse failure and writes atomically (tmp + rename).
- Fixed: Notification-event messages bypassed the 70-char clip; now clipped with control-char stripping.
- Fixed: `last-prompt` fallback accepted records with no `sessionId` (comment said "exact match only"); now strict.
- Hardened: JSON type guards in hook-input parsing and transcript scanning (non-string/non-dict records no longer abort extraction); `terminal-notifier` args array-built with bundle-ID format check; `powershell.exe` existence check.
- Added: `DDIRING_HIDE_BODY=1` (hide prompt body — lock-screen/screen-share privacy), `DDIRING_DEBUG=1` (failure log at `${TMPDIR:-/tmp}/ddiring.log`).
- Docs (5 READMEs + SKILL + command): 200KB→2MB extraction wording, tmux/Zellij "aware"→pass-through, Windows "zero-dependency" scoped to the toast backend, click-to-focus conditions stated up front, update-notifier hook disclosed, `/ddiring test` described accurately, en README `볼륨`→`volume`.
- Known trade-off kept deliberately: prompts starting with `<` are treated as synthetic tags and skipped (documented in notify.sh).

## 0.1.0 — 2026-08-23

First public release.

- **Stop / Notification hooks** — every finished (✅) or waiting (⏸️) session fires a notification with three answers at a glance: **which project folder** (title), **which terminal/app** (subtitle), **what you asked it to do** (body — a 70-char summary of your last real prompt, extracted from the transcript tail with tool-result/system-tag/interrupt lines skipped).
- **Click to jump** (macOS) — with `terminal-notifier` installed, clicking the notification focuses the app the session lives in.
- **30+ app mappings**, research-verified (local `Info.plist`, Homebrew cask definitions, upstream repo configs — 2026-08-23):
  - Terminals/IDEs: Terminal, iTerm2, VS Code (+Insiders), VSCodium, Cursor (exact ToDesktop ID — the `com.todesktop.*` wildcard would misfire on other ToDesktop apps), Windsurf (Devin), Antigravity (old/new bundle-ID prefix), Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode.
  - Claude Code session managers: Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum.
  - tmux/Zellij sessions correctly show their host terminal (multiplexers have no app bundle).
- **Windows support (experimental)** — on Git Bash the hook fires a PowerShell 5.1 WinRT toast (zero dependencies; display-only, no click action). Terminal identified via env probing in innermost-first order (`TERM_PROGRAM=vscode` before `WT_SESSION` — inherited-variable false positives). Not yet verified on real Windows hardware.
- **Quiet by default** — completion chime at volume 0.2, configurable via `DDIRING_VOLUME` / `DDIRING_SILENT` / `DDIRING_SOUND`.
- `/ddiring` command + `ddiring-config` skill for status, test, volume/sound changes, and terminal-mapping fixes.
