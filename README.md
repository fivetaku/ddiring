English | [한국어](README.ko.md) | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md)

# ddiring

<p align="center">
  <img src="assets/ddiring-hero-01.png" alt="ddiring" width="320">
</p>

> Completion notifications that actually tell you **which** session finished.

Running 5–10 Claude Code sessions across iTerm, Cursor, and a session manager? A bare "task complete" banner is useless — you still have to hunt through every window. ddiring ("띠링" — the Korean *ding!*) makes each notification answer three questions at a glance: **which project folder** (title), **which terminal or app** the session lives in (subtitle), and **what you asked it to do** (body — a 70-char summary of your last prompt). Click it to jump straight to that app.

[Quick Start](#quick-start) • [Why ddiring?](#why-ddiring) • [How it works](#how-it-works) • [Features](#features) • [Commands](#commands) • [Requirements](#requirements)

---

## Quick Start

### 1. Add the marketplace

```
/plugin marketplace add https://github.com/fivetaku/gptaku_plugins.git
```

### 2. Install

```
/plugin install ddiring
```

### 3. Restart Claude Code

(Hooks and commands only register after a restart.)

### 4. Use it

Nothing to do — every session now rings when it finishes:

- **✅ my-app** / *iTerm* / "fix the flaky auth test and rerun CI" — done, in iTerm
- **⏸️ blog** / *Cursor* / "waiting for permission" — a session needs you
- Click the notification (macOS + `terminal-notifier`) to focus that app

Optional, for click-to-focus:

```bash
brew install terminal-notifier
```

## Why ddiring?

Multi-session work has one recurring micro-pain: *something* finished, but the stock notification won't say what or where. Session IDs don't help either — you can't map `a3f9c2` to "the refactor I kicked off in Warp". ddiring shows the three things you actually recognize: the folder name, the app name, and your own last prompt.

## How it works

A `Stop` hook fires when a session finishes responding (plus a `Notification` hook for permission/input waits, shown with ⏸️). The script:

1. reads the transcript tail (last 200KB) to extract your last **real** prompt — tool results, system tags, and interrupt markers are skipped;
2. identifies the host app from the process environment — `__CFBundleIdentifier` on macOS, env probing (`TERM_PROGRAM` → `WT_SESSION` → `ConEmuPID`, innermost-first to dodge inherited-variable false positives) on Windows;
3. fires the notification: `terminal-notifier` (clickable) or `osascript` on macOS, a PowerShell 5.1 WinRT toast on Windows.

Because hooks run the script from a file, mapping fixes apply to **already-running sessions** immediately — no restart needed.

## Features

- **30+ app mappings, research-verified** (local `Info.plist`, Homebrew cask definitions, upstream repo configs): Terminal, iTerm2, VS Code (+Insiders), VSCodium, Cursor, Windsurf (Devin), Antigravity, Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode — plus Claude Code session managers: Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum.
- **tmux/Zellij aware** — multiplexer sessions correctly show their host terminal.
- **Quiet by default** — soft chime at volume 0.2; mute or retune via env vars.
- **Windows support (experimental)** — zero-dependency PowerShell toast from the Git Bash hook path (display-only; not yet verified on real hardware — reports welcome).
- **Unknown apps degrade gracefully** — falls back to `TERM_PROGRAM` or the raw bundle ID; one-line fix to add a mapping.

## Commands

| Command | What it does |
|---|---|
| `/ddiring` | show current status (env config, `terminal-notifier` presence, detected terminal) |
| `/ddiring test` | fire a test notification from this session's transcript |
| `/ddiring 볼륨 0.1` / `mute` | change volume / mute |

### Configuration

Set in the `"env"` block of your Claude settings file (applies to newly started sessions):

| Variable | Default | Meaning |
|---|---|---|
| `DDIRING_SILENT` | `0` | `1` = banner only, no sound (macOS) |
| `DDIRING_VOLUME` | `0.2` | 0.0–1.0 (macOS) |
| `DDIRING_SOUND` | `Glass.aiff` | any `/System/Library/Sounds/*.aiff` (macOS) |

## Requirements

- macOS (full support) or Windows + Git Bash (experimental); silently no-ops elsewhere
- `python3` (ships with macOS) — used for transcript parsing
- Optional: `terminal-notifier` for click-to-focus (macOS)

## License

[MIT](./LICENSE) — see also [DISCLAIMER.md](./DISCLAIMER.md).
