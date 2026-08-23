# Changelog

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
