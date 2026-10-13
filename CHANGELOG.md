# Changelog

## 0.2.1 — 2026-10-13
- **Routed through gptaku-core.** Declares `gptaku-core` as a dependency and adds `routing.json`, so requests that match this plugin's skills are pointed to them before Claude handles the work itself or reaches for native tools. Existing users: run `/reload-plugins` after updating, or reinstall the plugin, so gptaku-core gets installed. Opt out with `GPTAKU_ROUTER=off`.

## 0.2.0 — 2026-08-27

Self-check that verifies **display**, not just delivery (found by reproducing a live sound-only failure).

- **Added: `/ddiring 진단` (`doctor`)** — `setup/doctor.sh` fires one test notification and then reads the OS's own evidence to decide whether macOS actually *showed* it, and if not, why. Three evidence layers, each falling back to the next: `donotdisturbd`'s resolution log (`outcome`/`reason` — the OS's own verdict), the notification center DB's `presented` flag, then settings state (Focus assertions, "DND while mirroring/sharing"). Emits language-neutral `key=value` lines plus one `verdict=`; the skill maps each verdict to a fix in the user's language.
- **Added: first-run self-check.** The first `/ddiring` run now performs the diagnosis once (~4s) and surfaces `DDIRING_DOCTOR <verdict>` only when something is wrong; the result is kept at `~/.gptaku-setup/ddiring.doctor.txt`. Later runs skip it entirely.
- **Why this exists:** v0.1.2 fixed the sound-only failure whose cause was inside the plugin (PATH-dependent `terminal-notifier` lookup). The remaining sound-only failures are *outside* it — macOS suppresses every app's banner while the display is shared or mirrored (`reason: display shared`), during Focus, or without notification permission. `notify.sh` exits 0 in all of those cases, so no plugin-side log can tell them apart; the diagnosis reads the OS instead of guessing.
- Distinguishes "never had permission" from "permission fine, environment is suppressing" via whether the notifier app has *ever* been presented — the two need opposite fixes.
- Two portability traps caught while testing the diagnosis itself, both of which would have produced confident wrong answers: `timeout` does not exist on stock macOS (only with coreutils), so under a hook's minimal PATH the log query failed silently and the verdict degraded to "no evidence" — replaced with a dependency-free bounded run; and the notification center records `com.apple.scripteditor2` in lowercase while the OS log writes `com.apple.ScriptEditor2`, so the case-sensitive lookup reported "never presented" for every user without `terminal-notifier` — i.e. a false "permission denied" verdict. Both paths are now verified under `PATH=/usr/bin:/bin:/usr/sbin:/sbin`.

## 0.1.2 — 2026-08-24

Silent-failure root fix (reproduction-verified with a homebrew-less PATH).

- **Fixed: sound-only "half notification" in daemon/GUI-launched sessions.** Hooks in sessions started outside a login shell run with a minimal PATH, so `terminal-notifier` was never found and the script fell back to `osascript` — which exits 0 yet silently drops the banner when it lacks notification permission. `terminal-notifier` is now resolved PATH-independently (`command -v` → `/opt/homebrew/bin` → `/usr/local/bin`), so the banner+click-to-jump path works in every launch context.
- **Added: always-on last-notify status line** at `~/.cache/ddiring/last-notify` (fixed size, one line) recording which path fired (`tn ok` / `tn FAILED` / `fallback-osascript`) — makes silent failures diagnosable after the fact without enabling debug mode.
- Documented: the osascript fallback can still drop banners without permission; the status line now marks that case explicitly.

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
